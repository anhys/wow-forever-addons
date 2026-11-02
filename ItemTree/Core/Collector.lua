-- Records what the client legitimately shows the player and feeds it back into the graph
-- as verified edges. Pure Lua, no WoW API: the UI event handlers do the watching and call
-- Record with a plain table.
--
-- Everything passes through Core/Privacy.lua before it is stored, so player and character
-- identity never reaches saved variables, with the one exception brief E79 sanctions (below).
-- There is no network access and no automation.
--
-- The one client read is the realm id (Collector.ReadRealmId, under the divider at the foot of
-- the file): a number, read once a session, stamped on each discovery record so one made on
-- another realm the player plays on can be told apart. Never the realm's name.
--
-- Brief E79 is the one owner sanctioned exception to the privacy rule: a discovery record also
-- carries the name of the character that first saw the item (field c, Collector.ReadCharacterName,
-- read once at login), so the Discoveries tab can say "Thrallgar" rather than "You". Its limits:
-- it is written to the account's saved variables only while the Discoveries tab is on (brief R3),
-- and drawn on the Discoveries row and its tooltip, and nowhere else. Never in /itemtree debug,
-- /itemtree report, the trace ring, a chat line or any error text; C:Counts and the discovery
-- store's size, the readers the debug command has, never touch it.
local _, ItemTree = ...

local Edges = ItemTree.Edges
local Graph = ItemTree.Graph
local Privacy = ItemTree.Privacy
local Confidence = ItemTree.Confidence
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local T = Edges.Types
local EMPTY = {}

local Collector = {}
ItemTree.Collector = Collector

-- Bumped every time a record is written, pruned or cleared, whichever collector did it. A
-- caller that caches something worked out from collected edges reads it to tell that its
-- answer is stale; Core/ViewModel.lua's direction counts do.
Collector.generation = 1

-- Bumped only when the set of quest requirement rows can have changed: a quest_requires write, an
-- eviction that took one, Clear and a full reset (C:_Invalidate). UI/CollectorHooks.lua's quest
-- objective set keys on it, so an ordinary loot or merchant write leaves that set standing.
Collector.requiresGeneration = 1

local C = {}
C.__index = C

-- What the collector is allowed to record. Anything else is refused.
--
-- "discovery" is the odd one out and has a store of its own: it is not a sighting of a source,
-- it is the note that the client answered at all for an item this build withholds. See
-- C:RecordDiscovery.
-- "quest_requires" is what a quest ASKS FOR, as against "quest_reward", which is what it hands
-- back. No build states either (both live on the server), so the only way the addon learns that
-- ten Prideclaw Pelts are for "The Problem With Prideclaws" is watching this client say so: the
-- turn in window names the required items exactly, and the quest log names them by name.
-- Brief SK1 (owner ruling 2026-10-15, "I wouldn't want them in the drops table"): "skin" and
-- "pickpocket" are what the player's own Skinning and Pick Pocket casts took off a creature
-- (UI/CollectorHooks.lua CREATURE_LOOT_SPELLS), which used to be filed as drops.
Collector.KINDS = {
  drop = true,
  vendor = true,
  quest_reward = true,
  quest_objective = true,
  quest_requires = true,
  gather = true,
  disenchant = true,
  container = true,
  fish = true,
  discovery = true,
  skin = true,
  pickpocket = true,
}

-- forward: the edge from the recorded item to its source.
-- reverse: the edge from the source back to the recorded item, for the kinds where the source
-- is itself a node the player can open: an item, or the quest an objective belongs to.
local SPECS = {
  drop = { forward = { edge = T.DROPPED_BY, group = L["Drops from"] } },
  vendor = { forward = { edge = T.SOLD_BY, group = L["Sold by"] } },
  quest_reward = { forward = { edge = T.QUEST_REWARD, group = L["Quests"] } },
  quest_objective = { forward = { edge = T.QUEST_OBJECTIVE, group = L["Quests"] } },
  -- Both sides of one fact. On the item: "Quests", under Used by, because handing the pelt in
  -- is what the pelt is for. On the quest: "Requires", one AND group exactly like a recipe's
  -- reagents, which is the side Core/Quests.lua draws for the 28 curated quests.
  -- stated: the number on these two edges is the count the client stated, carried as a
  -- quantity, and never the tally every other collected edge draws. See the note in EdgesFor.
  quest_requires = {
    forward = { edge = T.QUEST_OBJECTIVE, group = L["Quests"], stated = true },
    reverse = { edge = T.QUEST_REQUIRES, group = L["Requires"], stated = true },
  },
  gather = { forward = { edge = T.GATHERED_FROM, group = L["Gathered from"] } },
  fish = { forward = { edge = T.FISHED_FROM, group = L["Fished from"] } },
  container = {
    forward = { edge = T.CONTAINED_IN, group = L["Contained in"] },
    reverse = { edge = T.CONTAINS, group = L["Contains"] },
  },
  disenchant = {
    forward = { edge = T.DISENCHANTED_FROM, group = L["Disenchanted from"] },
    reverse = { edge = T.DISENCHANTS_INTO, group = L["Disenchants into"] },
  },
  -- Brief SK1: as the Classic Era table files the same two (Core/EraSources.lua PLACES). A pocket
  -- is filed under DROPPED_BY like a drop but marked, so Core/Graph.lua never folds it into a drop
  -- of the same creature, and it shadows a Classic Era pocket row of that name, not a drop row.
  skin = { forward = { edge = T.SKINNED_FROM, group = L["Skinned from"] } },
  pickpocket = { forward = { edge = T.DROPPED_BY, group = L["Pickpocketed from"], pocket = true } },
}

-- Brief BQ25b (owner QA 2026-10-10 item 69): opening a chest is a gather interaction in the client,
-- so the player's own records of Battered Chest and Dented Chest were filed under "Gathered from"
-- with the kind "Gather". A gather record whose object's name carries one of these words (the
-- pipeline's CONTAINER_WORDS) is a container and files under "Found in", as the Classic Era chests
-- do (Core/EraSources.lua, LOOTED_FROM).
Collector.CONTAINER_WORDS = {
  "chest",
  "crate",
  "barrel",
  "footlocker",
  "strongbox",
  "cache",
  "lockbox",
  "coffer",
  "trunk",
}
local FOUND_IN = { edge = T.LOOTED_FROM, group = L["Found in"] }

--- Whether an object's name says it is a container: one of Collector.CONTAINER_WORDS as a whole
--- word, any case ("Battered Chest", "Dented Chest", "Waterlogged Footlocker"). Pure.
function Collector.IsContainerName(name)
  if type(name) ~= "string" or name == "" then
    return false
  end
  local lower = " " .. name:lower():gsub("[^%a]", " ") .. " "
  for _, word in ipairs(Collector.CONTAINER_WORDS) do
    if lower:find(" " .. word .. " ", 1, true) or lower:find(" " .. word .. "s ", 1, true) then
      return true
    end
  end
  return false
end

-- Kinds whose source key is a node the player can re-root to.
local SOURCE_KINDS = { npc = true, object = true, quest = true, item = true, zone = true }

-- Brief N2: the other end of a drop and a vendor record, which is what an NPC's own page lists.
-- An NPC is a node the player can open, so a record of either kind that names one answers for it
-- too: the items it dropped under Loot and the items it sold under Sells, with the tally and the
-- price the record holds.
local NPC_SPECS = {
  drop = { edge = T.CREATURE_DROPS, group = L["Drops"] },
  vendor = { edge = T.SELLS, group = L["Sells"] },
  -- Brief SK1: what the player skinned or pickpocketed off it, under its Loot tab beside its drops,
  -- in the Classic Era table's words (Core/EraSources.lua CREATURE_LOOT).
  skin = { edge = T.CREATURE_SKINNED, group = L["Skinned"] },
  pickpocket = { edge = T.CREATURE_POCKETED, group = L["Pickpocketed"] },
}

-- Brief Z1: the kinds of record a zone's own page lists, which are the ones that name a source out in
-- the world and the zone it was seen in.
local ZONE_KINDS = { drop = true, vendor = true, gather = true, fish = true }

-- A name as the by-NPC index files it: lower cased, so "Supply Officer" and "supply officer" are
-- one NPC, the way Core/Graph.lua matches a Classic Era row's name against a live one.
local function npcName(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return name:lower()
end

-- Who found a discovered item, which is the one thing a discovery record says beyond what the
-- item is. Stored as a single short field, h, and nothing else: the privacy rule is unchanged.
--
--   self   the player obtained the item. The client said so in its own words, so this is a
--          fact and not an inference.
--   realm  the client could name the item and the player only saw it named. Somebody else on
--          the realm found it and the server has released the details.
--
-- A record written before this field existed reads as "realm", because nothing can now say
-- otherwise, and that is the weaker of the two claims.
Collector.SOURCE_SELF = "self"
Collector.SOURCE_REALM = "realm"

-- How an item was met, and what each way of meeting one proves. The vocabulary is the caller's
-- (UI/CollectorHooks.lua names the path it was on); this is the one place it becomes a claim.
--
-- Only the ways that prove the player has the item are "self". A loot window, a merchant's
-- stock and a quest's reward list are all things the player is looking at rather than holding,
-- so they are "realm": the item is named on this client, which is what the realm having found
-- it means, and nothing more.
Collector.DISCOVERY_HOW = {
  loot = Collector.SOURCE_SELF,
  quest = Collector.SOURCE_SELF,
  vendor = Collector.SOURCE_SELF,
  craft = Collector.SOURCE_SELF,
  mail = Collector.SOURCE_SELF,
  trade = Collector.SOURCE_SELF,
  tooltip = Collector.SOURCE_REALM,
  lootwindow = Collector.SOURCE_REALM,
  merchant = Collector.SOURCE_REALM,
  questoffer = Collector.SOURCE_REALM,
  seen = Collector.SOURCE_REALM,
}

-- What one way of meeting an item proves, as the field that is stored. Anything this table does
-- not name proves the weaker of the two, which is what an unknown way of meeting one is. Pure.
function Collector.DiscoverySource(how)
  return Collector.DISCOVERY_HOW[how] or Collector.SOURCE_REALM
end

-- A character's name as a discovery record may hold it (brief E79): a plain name of 2 to 24
-- characters with no realm part, no spaces and no control characters, or nil for anything else,
-- the client's "Unknown" placeholder included. Pure.
Collector.UNKNOWN_NAMES = { Unknown = true, UNKNOWNOBJECT = true }

function Collector.CharacterName(value)
  if type(value) ~= "string" then
    return nil
  end
  if #value < 2 or #value > 24 or value:find("[%s%c%-%d%p]") then
    return nil
  end
  if Collector.UNKNOWN_NAMES[value] then
    return nil
  end
  return value
end

-- The client's realm id as a record may hold it: a positive whole number, or nil for anything
-- else, which is what an absent or silent client answers. Pure.
function Collector.RealmId(value)
  if Privacy.IsRealmId(value) then
    return value
  end
  return nil
end

-- Tags every discovery record that carries no realm id with the one given, and answers how many
-- it tagged. A record from before the field existed was made on the realm the player is on when
-- it is first read with an id known, which is the owner's ruling: it counts as the current realm
-- once and is then tagged. Nothing is tagged while the id is unknown. Pure. A packed record
-- (brief R3, Collector.PackDiscovery) is packed again with the id; an old shaped one is written.
function Collector.TagRealm(discoveries, realm)
  realm = Collector.RealmId(realm)
  if not realm or type(discoveries) ~= "table" then
    return 0
  end
  local tagged = 0
  for itemId, held in pairs(discoveries) do
    if type(held) == "table" and not Privacy.IsRealmId(held.realm) then
      held.realm = realm
      tagged = tagged + 1
    elseif type(held) == "string" then
      local h, day, minute, build, quality, heldRealm, character, name = Collector.DiscoveryFields(held)
      if h and not heldRealm then
        discoveries[itemId] = Collector.PackDiscovery(h, day, minute, build, quality, realm, character, name)
        tagged = tagged + 1
      end
    end
  end
  return tagged
end

local function timestamp()
  local wowTime = rawget(_G, "time")
  if type(wowTime) == "function" then
    return wowTime()
  end
  local os_ = rawget(_G, "os")
  if os_ and type(os_.time) == "function" then
    return os_.time()
  end
  return 0
end

-- Brief QN1: the server's clock in whole seconds (GetServerTime, pcalled), or nil where the client
-- has none or answers nothing usable. The one read a quest give record's accept time costs.
local function serverTime()
  local read = rawget(_G, "GetServerTime")
  if type(read) ~= "function" then
    return nil
  end
  local ok, value = pcall(read)
  value = ok and tonumber(value) or nil
  if not value or value <= 0 or value ~= value then
    return nil
  end
  return math.floor(value)
end

-- Looks like "Thrall-Frostmourne": a character name with a realm. Defence in depth, the
-- sanitiser has already dropped the keys and GUIDs that normally carry identity. Core/Privacy.lua.
local looksLikeCharacter = Privacy.LooksLikeCharacter
-- Brief R9: the same check, for the hooks that write other stores (a trainer's place).
Collector.LooksLikeCharacter = looksLikeCharacter

-- How many of an item a quest asks for, as a whole number, or nil.
--
-- This is the one number on a record that is restated rather than added up. `count` is a tally:
-- the collector adds every sighting to it, so ninety kills read as ninety of what a kill drops.
-- A quest asking for ten pelts is a fact about the quest and never a tally, so watching the same
-- quest twice must leave it at ten, which is why it has a field of its own.
local function needOf(value)
  if type(value) ~= "number" or value < 1 then
    return nil
  end
  return math.floor(value)
end

-- A whole number above nought, or nil.
local function positiveWhole(value)
  if type(value) ~= "number" or value < 1 or value ~= value or value == math.huge then
    return nil
  end
  return math.floor(value)
end

-- { [id] = amount } with every id and amount a whole number above nought, or nil when none is.
local function amounts(value)
  if type(value) ~= "table" then
    return nil
  end
  local out, any = {}, false
  for id, amount in pairs(value) do
    id, amount = positiveWhole(id), positiveWhole(amount)
    if id and amount then
      out[id] = amount
      any = true
    end
  end
  return any and out or nil
end

-- What a vendor asks for an item, as a record keeps it (brief M2), or nil for anything that
-- states no price at all:
--
--   { copper = 50000, currency = { [3402] = 200 }, items = { [1234] = 3 } }
--
-- Ids and amounts only, each part left out where the merchant window said nothing for it. The
-- currency is named when it is drawn (Core/Sources.lua CostText), never stored. Pure.
function Collector.Cost(value)
  if type(value) ~= "table" then
    return nil
  end
  local cost = {
    copper = positiveWhole(value.copper),
    currency = amounts(value.currency),
    items = amounts(value.items),
  }
  if not cost.copper and not cost.currency and not cost.items then
    return nil
  end
  return cost
end

-- ids of a { [id] = amount } table, lowest first, so a line reads the same every time.
local function sortedIds(map)
  local ids = {}
  for id in pairs(map or EMPTY) do
    ids[#ids + 1] = id
  end
  table.sort(ids)
  return ids
end

-- A stored cost as the debug report writes it, ids and amounts only:
-- "copper 50000, currency 3402 x200, item 1234 x3". nil for no cost. Pure.
function Collector.CostLine(value)
  local cost = Collector.Cost(value)
  if not cost then
    return nil
  end
  local parts = {}
  if cost.copper then
    parts[#parts + 1] = "copper " .. cost.copper
  end
  for _, id in ipairs(sortedIds(cost.currency)) do
    parts[#parts + 1] = string.format("currency %d x%d", id, cost.currency[id])
  end
  for _, id in ipairs(sortedIds(cost.items)) do
    parts[#parts + 1] = string.format("item %d x%d", id, cost.items[id])
  end
  return table.concat(parts, ", ")
end

-- Where the player stood when a vendor window opened, as a vendor record keeps it (brief M3), or
-- nil for anything else:
--
--   { map = 1433, x = 10.4, y = 71.4 }
--
-- map is the client's uiMap id and x, y the position on that map in PERCENT, rounded to a tenth
-- of a percent. It is the player's own position, kept only as that vendor's rough coordinates:
-- never sent anywhere, never printed (the debug report counts records that have one) and never
-- stored with a character or a realm. Nought on both axes is what a client answers where it has
-- no position to give, so it reads as none. Pure.
function Collector.Position(value)
  if type(value) ~= "table" then
    return nil
  end
  local map, x, y = positiveWhole(value.map), tonumber(value.x), tonumber(value.y)
  if not map or not x or not y or x ~= x or y ~= y then
    return nil
  end
  if x < 0 or x > 100 or y < 0 or y > 100 or (x == 0 and y == 0) then
    return nil
  end
  return { map = map, x = math.floor(x * 10 + 0.5) / 10, y = math.floor(y * 10 + 0.5) / 10 }
end

--------------------------------------------------------------------------------
-- The record shape (brief R15)
--------------------------------------------------------------------------------

-- collector.records holds one compact row per kind, item and source. The key names the fact,
-- "d:2589:n:117" (a kind code, the item id, a source code and the source id, 0 for none), and the
-- row holds what was seen, each field one letter and left out where it says nothing:
--
--   n  the source's name, as the client showed it
--   m  the zone's uiMap id, kept only where the map's own name is the zone text the client gave
--   z  the zone text, only where there is no m
--   s  how many times the fact was seen, absent for once
--   c  the tally (how many came), absent where it is s
--   l  the day it was last seen, whole days since the epoch (Collector.Day)
--   f  the day it was first seen, absent where it is l
--   b  the data build, an index into collector.builds, absent for the first
--   q  the item's quality, only for an item the installed data does not know
--   w  how many a quest asks for (quest_requires): stated by the client, never a tally
--   p  where the player stood at a vendor's window: x and y in tenths of a percent, packed as
--      x * 10000 + y; P the map that point is on, only where it is not m
--   x  what a vendor asked (Collector.Cost), only where the ledger's vendor table (Core/Ledger.lua)
--      does not hold it: a price in a currency or in items, or money the ledger disagrees with
--   side  brief QN1, a vendor row only: the side of the player at the window, 1 Alliance or 2
--      Horde (Collector.Side), the newest window's; absent where the client said none. The
--      pipeline's mine reads the same key (ItemTree-Data brief P1). One small integer per row.
--   o  brief QH1, a loot row only (Collector.LOOT_QUEST_KINDS): the quest id the item was an
--      objective of when it was looted, where exactly one quest in the log asked for it
--      (UI/CollectorHooks.lua CurrentObjectiveQuests), the newest window's. One integer per row.
--
-- collector.shape is 2 once every row is in this shape (Collector.Migrate). Collector.View turns
-- a row back into the long record every reader has always taken, so nothing past this file
-- sees the stored shape.
Collector.SHAPE = 2

local DAY = 86400

-- Brief QH1: the loot kinds a row's o (the quest the item was an objective of) may ride on: what a
-- loot window files. A vendor, a quest's own rows and a disenchant never carry one.
Collector.LOOT_QUEST_KINDS = {
  drop = true,
  gather = true,
  container = true,
  fish = true,
  skin = true,
  pickpocket = true,
}

-- Brief QH1: a loot row's quest as the row keeps it, or nil: a whole quest id on a loot kind. Pure.
function Collector.LootQuest(kind, value)
  if not Collector.LOOT_QUEST_KINDS[kind] or type(value) ~= "number" then
    return nil
  end
  if value < 1 or value >= 2 ^ 31 or value ~= math.floor(value) then
    return nil
  end
  return value
end

-- Brief QN1: a side as a vendor row keeps it, 1 Alliance or 2 Horde, out of the number itself or
-- UnitFactionGroup's own word, or nil for anything else (a neutral Pandaren, no answer). Pure.
function Collector.Side(value)
  if value == 1 or value == "Alliance" then
    return 1
  end
  if value == 2 or value == "Horde" then
    return 2
  end
  return nil
end

local KIND_CODES = {
  drop = "d",
  vendor = "v",
  quest_reward = "r",
  quest_objective = "o",
  quest_requires = "q",
  gather = "g",
  disenchant = "e",
  container = "c",
  fish = "f",
  -- Brief SK1: a share format change, read by ItemTree-Data's mine in the same release.
  skin = "k",
  pickpocket = "p",
}
local SOURCE_CODES = { npc = "n", object = "o", quest = "q", item = "i", zone = "z" }

local function invert(map)
  local out = {}
  for long, short in pairs(map) do
    out[short] = long
  end
  return out
end
local KIND_NAMES = invert(KIND_CODES)
local SOURCE_NAMES = invert(SOURCE_CODES)

-- Brief C20: the largest source id a key may carry, one past the last. Every id the client
-- hands the collector for a creature, an object, a quest, an item or a map is a whole number
-- well below 2^31. A number past it is not an id at all: v0.1.4 to v0.1.6 filed a container
-- opened from the bags under the spawn part of its Item GUID (Privacy.ParseGuid reads that hex
-- field with tonumber, which takes "4000000001234E05" as 4.000000001234e17), and wrote 18 and
-- 19 digit keys no reader can trust.
Collector.MAX_SOURCE_ID = 2 ^ 31

-- Whether a source id can go into a key: none (nil), or a whole number from 0 up to but not
-- including Collector.MAX_SOURCE_ID. Pure.
function Collector.ValidSourceId(sourceId)
  if sourceId == nil then
    return true
  end
  return type(sourceId) == "number"
    and sourceId == sourceId
    and sourceId >= 0
    and sourceId < Collector.MAX_SOURCE_ID
    and sourceId == math.floor(sourceId)
end

-- The store key for one fact, or nil where a part cannot be written into one (a source id
-- Collector.ValidSourceId refuses among them). Pure.
function Collector.Key(kind, itemId, sourceKind, sourceId)
  local code = KIND_CODES[kind]
  if not code or type(itemId) ~= "number" or type(sourceKind) ~= "string" or sourceKind == "" then
    return nil
  end
  if not Collector.ValidSourceId(sourceId) then
    return nil
  end
  if sourceKind:find(":", 1, true) then
    return nil
  end
  local source = SOURCE_CODES[sourceKind] or sourceKind
  return table.concat({ code, tostring(itemId), source, tostring(sourceId or 0) }, ":")
end

-- kind, itemId, sourceKind, sourceId out of a store key, or nil for a key that is not one. A
-- source id of 0 is none, and one Collector.ValidSourceId refuses makes the key not one. Pure.
function Collector.ParseKey(key)
  if type(key) ~= "string" then
    return nil
  end
  local code, itemId, source, sourceId = key:match("^([^:]+):(%d+):([^:]+):(%d+)$")
  local kind = KIND_NAMES[code]
  if not kind then
    return nil
  end
  sourceId = tonumber(sourceId)
  if not Collector.ValidSourceId(sourceId) then
    return nil
  end
  if sourceId == 0 then
    sourceId = nil
  end
  return kind, tonumber(itemId), SOURCE_NAMES[source] or source, sourceId
end

-- The key the store used before brief R15, "drop:2589:npc:117", for a record of the old shape.
local function oldKey(kind, itemId, sourceKind, sourceId)
  return table.concat({ kind, tostring(itemId), tostring(sourceKind), tostring(sourceId or 0) }, ":")
end

-- Whether a row is in the shape the store used before brief R15 (every field spelt out). Pure.
function Collector.IsOldShape(row)
  return type(row) == "table" and type(row.kind) == "string"
end

-- A position (Collector.Position) as the number p keeps: x and y in tenths, x * 10000 + y. Pure.
function Collector.PackPosition(pos)
  pos = Collector.Position(pos)
  if not pos then
    return nil
  end
  return math.floor(pos.x * 10 + 0.5) * 10000 + math.floor(pos.y * 10 + 0.5)
end

-- p and the map it is on back into { map, x, y }, or nil. Pure.
function Collector.UnpackPosition(packed, map)
  packed = tonumber(packed)
  if not packed or packed < 0 then
    return nil
  end
  local x = math.floor(packed / 10000)
  local y = packed - x * 10000
  return Collector.Position({ map = map, x = x / 10, y = y / 10 })
end

-- The index of a data build in the store's shared list, added the first time it is met, or nil
-- for no build. store is the collector's saved table.
function Collector.BuildIndex(store, build)
  if type(build) ~= "string" and type(build) ~= "number" then
    return nil
  end
  if type(store.builds) ~= "table" then
    store.builds = {}
  end
  for index, held in ipairs(store.builds) do
    if held == build then
      return index
    end
  end
  store.builds[#store.builds + 1] = build
  return #store.builds
end

-- The zone as a row keeps it: m, z. The map id alone where the client's name for that map is the
-- zone text itself, so the page reads the same words; the text alone otherwise (no map id, or a
-- map whose name is another place's, such as a sub zone's). Nothing for no zone. The map's name
-- is Collector.MapName, a client read.
function Collector.Place(zone, mapId)
  if type(zone) ~= "string" or zone == "" then
    return nil, nil
  end
  mapId = positiveWhole(mapId)
  if mapId and Collector.MapName(mapId) == zone then
    return mapId, nil
  end
  return nil, zone
end

-- The money price the ledger's vendor table holds for one item at one npc, or nil. ledger is
-- ItemTreeDB.ledger. Pure.
function Collector.LedgerPrice(ledger, sourceKind, sourceId, itemId)
  if sourceKind ~= "npc" or type(ledger) ~= "table" or type(ledger.vendor) ~= "table" then
    return nil
  end
  local vendor = ledger.vendor[sourceId]
  local prices = type(vendor) == "table" and vendor.i or nil
  local price = type(prices) == "table" and prices[itemId] or nil
  return type(price) == "number" and price or nil
end

-- Whether a vendor's cost can be left to the ledger: a money price and nothing else, which the
-- ledger holds for the same npc and item to the copper. A price in a currency or in items never
-- can: the ledger keeps the currency's id and not how many. Pure.
function Collector.LedgerHolds(ledger, sourceKind, sourceId, itemId, cost)
  cost = Collector.Cost(cost)
  if not cost or not cost.copper or cost.currency or cost.items then
    return false
  end
  return Collector.LedgerPrice(ledger, sourceKind, sourceId, itemId) == cost.copper
end

-- Whether the installed data knows an item well enough to answer its quality at draw time: the
-- core set's Summary names it (Data:Glance, never a load), or, with no Summary, a row the data
-- already holds says it (Data:PeekItem, never a load). A Classic Era row counts only as long as
-- a setting shows it, so it does not count.
function Collector.DataKnows(itemId)
  local data = ItemTree.Data
  if type(data) ~= "table" or type(itemId) ~= "number" then
    return false
  end
  if type(data.Glance) == "function" then
    local ok, glance = pcall(data.Glance, data, itemId)
    if ok and type(glance) == "table" then
      return glance.named == true and not glance.era
    end
  end
  if type(data.PeekItem) == "function" then
    local ok, item = pcall(data.PeekItem, data, itemId)
    return ok and type(item) == "table" and type(item.q) == "number"
  end
  return false
end

-- An item's quality out of the data already held (Data:PeekItem, never a load), or nil.
function Collector.DataQuality(itemId)
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.PeekItem) ~= "function" then
    return nil
  end
  local ok, item = pcall(data.PeekItem, data, itemId)
  if ok and type(item) == "table" and type(item.q) == "number" then
    return item.q
  end
  return nil
end

-- A view's quality where its row keeps none: the data's, read when a caller asks for it.
local VIEW_META = {
  __index = function(view, field)
    if field == "quality" then
      return Collector.DataQuality(rawget(view, "itemId"))
    end
    return nil
  end,
}

-- One row as the long record every reader takes:
--
--   { kind, itemId, sourceKind, sourceId, sourceName, zone, mapId, quality, count, seen, need,
--     cost, pos, first, last, day, build, side, quest }
--
-- first and last are the days in seconds (the start of the day), day the last day itself. zone
-- is z, or the name of m out of the client (Collector.MapName). cost is x, or for a vendor row the
-- ledger's money price. quality is q, or the data's (read on demand). A row still in the old
-- shape is its own view. builds is collector.builds and ledger ItemTreeDB.ledger. A new table
-- that the caller must not write to the store. nil for a row that is not one.
function Collector.View(key, row, builds, ledger)
  if type(row) ~= "table" then
    return nil
  end
  if Collector.IsOldShape(row) then
    return row
  end
  local kind, itemId, sourceKind, sourceId = Collector.ParseKey(key)
  if not kind then
    return nil
  end
  local seen = positiveWhole(row.s) or 1
  local last = tonumber(row.l) or 0
  local first = tonumber(row.f) or last
  local mapId = positiveWhole(row.m)
  local zone = type(row.z) == "string" and row.z ~= "" and row.z or nil
  if not zone and mapId then
    zone = Collector.MapName(mapId)
  end
  local cost = Collector.Cost(row.x)
  if not cost and kind == "vendor" then
    local price = positiveWhole(Collector.LedgerPrice(ledger, sourceKind, sourceId, itemId))
    if price then
      cost = { copper = price }
    end
  end
  local view = {
    kind = kind,
    itemId = itemId,
    sourceKind = sourceKind,
    sourceId = sourceId,
    sourceName = type(row.n) == "string" and row.n or nil,
    zone = zone,
    mapId = mapId,
    quality = type(row.q) == "number" and row.q or nil,
    count = tonumber(row.c) or seen,
    seen = seen,
    need = needOf(row.w),
    cost = cost,
    pos = Collector.UnpackPosition(row.p, positiveWhole(row.P) or mapId),
    first = first * DAY,
    last = last * DAY,
    day = last,
    build = type(builds) == "table" and builds[positiveWhole(row.b) or 1] or nil,
    side = kind == "vendor" and Collector.Side(row.side) or nil,
    -- Brief QH1: the quest the item was an objective of when it was looted (a loot row only).
    quest = Collector.LootQuest(kind, row.o),
  }
  return setmetatable(view, VIEW_META)
end

-- One old shaped record as a row of the new shape, and its key: key, row, or nil for a record
-- that cannot be one (it is then left as it is). zoneMaps is { [zone text] = map id } for the
-- texts a map id is known for (Collector.Migrate). Nothing the record says is lost: the item,
-- the source, the kind and the ids go into the key, the rest into the row.
function Collector.Compact(record, store, ledger, zoneMaps)
  if not Collector.IsOldShape(record) then
    return nil
  end
  local kind, itemId, sourceKind = record.kind, record.itemId, record.sourceKind
  local sourceId = type(record.sourceId) == "number" and record.sourceId or nil
  local key = Collector.Key(kind, itemId, sourceKind, sourceId)
  if not key then
    return nil
  end
  local row = {}
  row.n = type(record.sourceName) == "string" and record.sourceName or nil
  local zone = type(record.zone) == "string" and record.zone ~= "" and record.zone or nil
  local candidate = positiveWhole(record.mapId) or (zone and type(zoneMaps) == "table" and zoneMaps[zone]) or nil
  row.m, row.z = Collector.Place(zone, candidate)
  local seen = positiveWhole(record.seen) or 1
  local tally = tonumber(record.count) or seen
  if seen ~= 1 then
    row.s = seen
  end
  if tally ~= seen then
    row.c = tally
  end
  local lastSeconds = tonumber(record.last) or tonumber(record.first) or 0
  local last = Collector.Day(lastSeconds)
  local first = Collector.Day(tonumber(record.first) or lastSeconds)
  row.l = last
  if first ~= last then
    row.f = first
  end
  local build = Collector.BuildIndex(store, record.build)
  if build and build ~= 1 then
    row.b = build
  end
  if type(record.quality) == "number" and not Collector.DataKnows(itemId) then
    row.q = record.quality
  end
  row.w = needOf(record.need)
  local pos = Collector.Position(record.pos)
  if pos then
    row.p = Collector.PackPosition(pos)
    if pos.map ~= row.m then
      row.P = pos.map
    end
  end
  local cost = Collector.Cost(record.cost)
  if cost and not (kind == "vendor" and Collector.LedgerHolds(ledger, sourceKind, sourceId, itemId, cost)) then
    row.x = cost
  end
  if kind == "vendor" then
    row.side = Collector.Side(record.side)
  end
  row.o = Collector.LootQuest(kind, record.quest)
  return key, row
end

-- Two rows of one fact as one, into held: the sightings and tallies added, the first day the
-- earlier and the last the later, and every field held lacks taken from add. Pure.
function Collector.MergeRows(held, add)
  local heldSeen, addSeen = positiveWhole(held.s) or 1, positiveWhole(add.s) or 1
  local tally = (tonumber(held.c) or heldSeen) + (tonumber(add.c) or addSeen)
  local seen = heldSeen + addSeen
  held.s = seen
  held.c = nil
  if tally ~= seen then
    held.c = tally
  end
  local heldLast, addLast = tonumber(held.l) or 0, tonumber(add.l) or 0
  local first = math.min(tonumber(held.f) or heldLast, tonumber(add.f) or addLast)
  local last = math.max(heldLast, addLast)
  held.l = last
  held.f = nil
  if first ~= last then
    held.f = first
  end
  for _, field in ipairs({ "n", "m", "z", "b", "q", "w", "p", "P", "x", "side", "o" }) do
    if held[field] == nil then
      held[field] = add[field]
    end
  end
  if held.m and held.z then
    held.z = nil
  end
  return held
end

-- { [zone text] = map id } for every text whose map the store already knows: a vendor record's
-- position names the map the player stood on, and a quest NPC's names the map at its window. A
-- text counts only where the client's name for that map is the text itself (Collector.MapName).
local function zoneMapsOf(store)
  local out = {}
  local function learn(zone, mapId)
    mapId = positiveWhole(mapId)
    if type(zone) == "string" and zone ~= "" and mapId and out[zone] == nil and Collector.MapName(mapId) == zone then
      out[zone] = mapId
    end
  end
  for _, record in pairs(store.records) do
    if Collector.IsOldShape(record) and type(record.pos) == "table" then
      learn(record.zone, record.pos.map)
    end
  end
  return out
end

-- Takes every vendor row's cost off the row where the ledger now holds the very same money price
-- (a window the ledger had not yet counted when the row was written). Answers how many.
function Collector.TidyCosts(store, ledger)
  local tidied = 0
  for key, row in pairs(type(store) == "table" and type(store.records) == "table" and store.records or EMPTY) do
    if type(row) == "table" and row.x ~= nil and not Collector.IsOldShape(row) then
      local kind, itemId, sourceKind, sourceId = Collector.ParseKey(key)
      if kind == "vendor" and Collector.LedgerHolds(ledger, sourceKind, sourceId, itemId, row.x) then
        row.x = nil
        tidied = tidied + 1
      end
    end
  end
  return tidied
end

-- Brings every record in the store to the shape above, once, at load (Core/Init.lua, before the
-- collector is made). Old rows are converted one by one and the marker (store.shape = 2) is set
-- when all are done; a store that stopped half way (a crash mid way) still has old rows, and the
-- next load converts the rest, since every row is checked on every load and a converted row is
-- left alone. Nothing is dropped: a record that cannot be converted stays as it is, and a new row
-- already there for the same fact takes the old one's sightings (Collector.MergeRows). Then the
-- vendor prices the ledger now holds come off their rows (Collector.TidyCosts).
--
-- Brief C20: the one exception to "nothing is dropped" is a row whose source id is not an id
-- (Collector.ValidSourceId): a new shaped row whose key Collector.ParseKey cannot read, or an old
-- shaped one whose sourceId Collector.Key refuses. Such a row is removed, so an old store heals
-- on load, and each one is counted once, into the answer's dropped and the store's running
-- dropped total (what /itemtree debug's collector line shows). Removed, it is never counted again.
--
-- Answers { converted, merged, kept, tidied, dropped, before, after }, before and after being the
-- store's bytes (Collector.Size) either side, measured only when a row was converted. opts.ledger
-- is ItemTreeDB.ledger.
function Collector.Migrate(store, opts)
  opts = opts or EMPTY
  local result = { converted = 0, merged = 0, kept = 0, tidied = 0, dropped = 0 }
  if type(store) ~= "table" or type(store.records) ~= "table" then
    return result
  end
  local records = store.records
  local old, unreadable = {}, {}
  for key, row in pairs(records) do
    if Collector.IsOldShape(row) then
      if type(row.sourceId) == "number" and not Collector.ValidSourceId(row.sourceId) then
        unreadable[#unreadable + 1] = key
      else
        old[#old + 1] = key
      end
    elseif not Collector.ParseKey(key) then
      unreadable[#unreadable + 1] = key
    end
  end
  for _, key in ipairs(unreadable) do
    records[key] = nil
  end
  if #unreadable > 0 then
    result.dropped = #unreadable
    store.dropped = (tonumber(store.dropped) or 0) + #unreadable
  end
  if #old > 0 then
    result.before = Collector.Size(store).bytes
    table.sort(old, function(a, b)
      return tostring(a) < tostring(b)
    end)
    local zoneMaps = zoneMapsOf(store)
    for _, from in ipairs(old) do
      local record = records[from]
      local key, row = Collector.Compact(record, store, opts.ledger, zoneMaps)
      if key then
        local held = records[key]
        if key ~= from and type(held) == "table" and not Collector.IsOldShape(held) then
          Collector.MergeRows(held, row)
          result.merged = result.merged + 1
        else
          records[key] = row
        end
        if key ~= from then
          records[from] = nil
        end
        result.converted = result.converted + 1
      else
        result.kept = result.kept + 1
      end
    end
  end
  result.tidied = Collector.TidyCosts(store, opts.ledger)
  if result.kept == 0 then
    store.shape = Collector.SHAPE
  end
  if result.before then
    result.after = Collector.Size(store).bytes
  end
  return result
end

-- The debug report's line for the load's migration, or nil where nothing was converted. result
-- is Collector.Migrate's answer.
function Collector.MigrationLine(result)
  if type(result) ~= "table" or (tonumber(result.converted) or 0) == 0 then
    return nil
  end
  return string.format(
    "Collector records converted to the compact shape at login: %d (%.1f KB before, %.1f KB after)",
    tonumber(result.converted) or 0,
    (tonumber(result.before) or 0) / 1024,
    (tonumber(result.after) or 0) / 1024
  )
end

-- Brief R15: whether the installed data already ships this record's fact with player provenance
-- (a row the shared finds pipeline tagged "player", briefs R11 to R14), in which case the record
-- is the first to go when the store is over budget. The reader is ItemTree.PlayerSources, a
-- data module with Provenance(kind, itemId, sourceKind, sourceId) answering the row's tag (brief
-- PS1, Core/PlayerSources.lua, which reads only a module already built and so never loads one).
-- A build with no PlayerSources module answers false. Never raises.
Collector.PLAYER_PROVENANCE = "player"

function Collector.ShipsAsPlayer(kind, itemId, sourceKind, sourceId)
  local reader = ItemTree.PlayerSources
  if type(reader) ~= "table" or type(reader.Provenance) ~= "function" then
    return false
  end
  local ok, tag = pcall(reader.Provenance, kind, itemId, sourceKind, sourceId)
  return ok and tag == Collector.PLAYER_PROVENANCE
end

-- store is the saved variables table (ItemTree.db.collector) with .records and .counts.
function Collector.New(store, opts)
  opts = opts or EMPTY
  local collector = setmetatable({}, C)
  store = store or {}
  store.records = store.records or {}
  store.counts = store.counts or {}
  -- itemId -> one packed string (brief R3, Collector.PackDiscovery): who found it, the day, the
  -- data build, the quality, the realm id, the character that first saw it (brief E79) and the
  -- name. Written only by RecordDiscovery and UpgradeDiscovery, tagged by C:RealmId, capped by
  -- C:PruneDiscoveries, and read only through Collector.ViewDiscovery.
  store.discoveries = store.discoveries or {}
  -- Brief Q8: questId -> { give = record, ["end"] = record }, who gave each quest and who took it
  -- back, one record per quest per kind (Collector.QuestNpcRecord), and since brief R9 the quest's
  -- title once as .title (Collector.QuestTitle). Written only by RecordQuestNpc.
  store.questNpcs = store.questNpcs or {}
  -- Brief BL14: boss index entry -> { npcId, name, mapId, level, when }, the creature the player
  -- has seen for a boss the index knows by name alone (no creature id: a new Forever encounter).
  -- One record per entry, updated in place. Written only by RecordSeenBoss.
  store.seenBosses = store.seenBosses or {}
  -- Brief QF1: questId -> one compact record of what the client stated about the quest at accept
  -- and at the turn in (Collector.QuestFactsRecord). Not made here: the key appears on the first
  -- write, so an older saved file loads unchanged. Written only by RecordQuestFacts and
  -- SetQuestGoalCreature, capped by Collector.QUEST_FACTS_MAX_BYTES.
  -- Brief DM2: creatureId -> { i, d, b }, the display ids the client confirmed a creature page's
  -- model with (Collector.DisplaysRecord). Not made here either: the key appears on the first
  -- write. Written only by RecordDisplay, capped by Collector.DISPLAYS_MAX_BYTES.
  -- Brief TW1: creatureId -> { record, ... }, what a trainer's window listed, one record per class
  -- and build (Collector.TrainerListRecord). Not made here: the key appears on the first write.
  -- Written only by RecordTrainerList, capped by Collector.TRAINERS_MAX_BYTES.
  collector.store = store
  collector.build = opts.build
  -- Brief R15: the ledger whose vendor table holds the money prices vendor rows leave out. A
  -- caller may state it (a spec does); otherwise ItemTreeDB.ledger, read when it is needed.
  collector.ledger = type(opts.ledger) == "table" and opts.ledger or nil
  -- Brief R12: the Classic Era reader the node names come from (a spec states one, an object with
  -- Table() or the shipped table itself) and the places store node sightings are counted in;
  -- otherwise ItemTree.eraSources and ItemTree.db.places, read when they are needed.
  collector.era = opts.era
  collector.places = type(opts.places) == "table" and opts.places or nil
  collector.now = type(opts.now) == "function" and opts.now or timestamp
  -- Brief QN1: the server clock a quest give record's accept time is read from (a spec states one).
  collector.serverNow = type(opts.serverNow) == "function" and opts.serverNow or serverTime
  collector.provider = nil
  collector.byItem = nil
  -- opts.realm, where a caller states it (a spec does), is the realm id and the client is never
  -- asked; false states that it is unknown. Otherwise the client is asked, see C:RealmId.
  collector.realm = nil
  collector.realmStated = opts.realm ~= nil
  if collector.realmStated then
    collector.realm = Collector.RealmId(opts.realm)
  end
  collector.realmAsked = false
  collector.realmTagged = false
  -- Brief R3: the moment each discovery this session wrote was made, to the second. The store
  -- keeps the day alone; this is never saved, so the tab's NEW! tags and its bubble stay exact
  -- for what arrives while the player is on.
  collector.discoveryTimes = {}
  collector:RealmId()
  -- opts.character, where a caller states it (a spec does), is the character's name and the
  -- client is never asked; false states that it is unknown. Otherwise see C:Character.
  collector.character = nil
  collector.characterStated = opts.character ~= nil
  if collector.characterStated then
    collector.character = Collector.CharacterName(opts.character)
  end
  collector.characterAsked = false
  collector:Character()
  return collector
end

-- The name of the character this session is on, or nil while the client will not say. Asked of
-- the client at login (Collector.New) and again only while it has answered nothing usable: a
-- client with no UnitName at all is asked once. Held here and written on new discovery records
-- (field c) and nowhere else; brief E79 is the one exception to the privacy rule, and this is
-- the whole of it.
function C:Character()
  if not self.character and not self.characterStated and not self.characterAsked then
    local name, present = Collector.ReadCharacterName()
    self.character = name
    self.characterAsked = not present
  end
  return self.character
end

-- The realm id this session is on, or nil while nothing will say. Asked of the client the first
-- time and again only while it has answered nothing: a client that does not have the call at all
-- is asked once. The first time an id is known, every record without one is tagged with it
-- (Collector.TagRealm). The id is held here and on the records and is never printed.
function C:RealmId()
  if not self.realm and not self.realmStated and not self.realmAsked then
    local realm, present = Collector.ReadRealmId()
    self.realm = realm
    self.realmAsked = not present
  end
  if self.realm and not self.realmTagged then
    self.realmTagged = true
    if Collector.TagRealm(self.store.discoveries, self.realm) > 0 then
      -- The records grew by the id, so the running size is worked out afresh on the next ask.
      self.discBytes, self.discRecords = nil, nil
      self:_Touch()
    end
  end
  return self.realm
end

-- The ledger this collector reads vendor prices from, or nil (C:Record, Collector.View).
function C:_Ledger()
  if self.ledger then
    return self.ledger
  end
  local db = ItemTree.db
  return type(db) == "table" and type(db.ledger) == "table" and db.ledger or nil
end

-- Whether a vendor view's cost is read out of the ledger rather than the row (Collector.View): a
-- row of an npc that keeps no price of its own.
local function costFromLedger(view, row)
  return view.kind == "vendor" and view.sourceKind == "npc" and (row.x == nil or Collector.Cost(row.x) == nil)
end

-- Every record as the long view readers take (Collector.View), keyed by the store's key, built
-- once. Read only: the views are new tables, so a write to one never reaches the store.
--
-- A write only marks the row it added, changed or let go of (C:_Touch), and the next read brings
-- that row's view and its index buckets up to date in place (C:_Refresh), together with everything
-- a rebuild would have read afresh from outside the store: the ledger's prices on vendor views and
-- a map name the client could not give before. So what a reader gets is always what a build over
-- the store as it stands would give, without the rebuild that used to follow every write.
function C:Records()
  local views = self.views
  if views and self.stale then
    self:_Refresh()
    views = self.views
  end
  if views then
    return views
  end
  local store = self.store
  local builds, ledger = store.builds, self:_Ledger()
  local zoneMisses, ledgerViews = {}, {}
  views = {}
  for key, row in pairs(store.records) do
    local view = Collector.View(key, row, builds, ledger)
    if view then
      views[key] = view
      -- An old shaped row is its own view, so it never goes stale.
      if view ~= row then
        if view.mapId and view.zone == nil then
          zoneMisses[key] = view
        end
        if costFromLedger(view, row) then
          ledgerViews[key] = view
        end
      end
    end
  end
  self.views = views
  self.zoneMisses, self.ledgerViews = zoneMisses, ledgerViews
  self.viewsRecords, self.viewsBuilds = store.records, builds
  self.viewsBuildCount = type(builds) == "table" and #builds or 0
  return views
end

-- Brings the views up to date after writes (C:_Touch): every row written, added or let go of since
-- is viewed again, and its view refilled in place, made, or taken away, with the index buckets
-- that hold it (C:_IndexAdd, C:_IndexRemove), so the views and the index are what a build over
-- the store as it now stands would make. A row's kind, item and source are its key, so a refilled
-- view keeps its place in a bucket unless its source's name or its zone moved, and then it is
-- taken out and put back. Where the store's table or its build list changed under every view, the
-- views are dropped and the read builds them afresh. Never bumps the generation: this is a read.
function C:_Refresh()
  self.stale = nil
  local views, store = self.views, self.store
  local builds = store.builds
  if
    store.records ~= self.viewsRecords
    or builds ~= self.viewsBuilds
    or (type(builds) == "table" and #builds or 0) ~= self.viewsBuildCount
  then
    return self:_Forget()
  end
  local pending = self.pending or {}
  self.pending = nil
  -- A map the client could not name when its views were made, and now can, moves their zone.
  for key, view in pairs(self.zoneMisses) do
    if Collector.MapName(view.mapId) ~= nil then
      pending[key] = true
    end
  end
  local ledger = self:_Ledger()
  local records, zoneMisses, ledgerViews = store.records, self.zoneMisses, self.ledgerViews
  for key in pairs(pending) do
    local row, held = records[key], views[key]
    local view = row ~= nil and Collector.View(key, row, builds, ledger) or nil
    if view ~= nil and view == row then
      -- An old shaped row: never written in place, so the views are built again.
      return self:_Forget()
    end
    if held and not view then
      self:_IndexRemove(held)
      views[key] = nil
    elseif view and not held then
      views[key] = view
      self:_IndexAdd(view)
      held = view
    elseif held and view then
      local moved = held.zone ~= view.zone or held.sourceName ~= view.sourceName
      if moved then
        self:_IndexRemove(held)
      elseif self.byItem then
        self:_Tally(held, -1)
      end
      for field in pairs(held) do
        held[field] = nil
      end
      for field, value in pairs(view) do
        held[field] = value
      end
      if moved then
        self:_IndexAdd(held)
      elseif self.byItem then
        self:_Tally(held, 1)
      end
    end
    if held and view and held.mapId and held.zone == nil then
      zoneMisses[key] = held
    else
      zoneMisses[key] = nil
    end
    if held and view and costFromLedger(held, row) then
      ledgerViews[key] = held
    else
      ledgerViews[key] = nil
    end
  end
  -- The ledger may have learned, changed or let go of a price since the views were made (a
  -- merchant window, or the ledger's own cap): Collector.View's read, inline, for every vendor
  -- view whose price is the ledger's.
  local vendors = type(ledger) == "table" and type(ledger.vendor) == "table" and ledger.vendor or nil
  local kindOf, raw, floor, huge = type, rawget, math.floor, math.huge
  for _, view in pairs(ledgerViews) do
    local price = nil
    local vendor = vendors and vendors[view.sourceId]
    if vendor ~= nil and kindOf(vendor) == "table" then
      local prices = vendor.i
      price = kindOf(prices) == "table" and prices[view.itemId] or nil
      if price ~= nil then
        if kindOf(price) ~= "number" or price < 1 or price ~= price or price == huge then
          price = nil
        else
          price = floor(price)
        end
      end
    end
    local cost = raw(view, "cost")
    if price then
      if not (cost and cost.copper == price) then
        view.cost = { copper = price }
      end
    elseif cost ~= nil then
      view.cost = nil
    end
  end
end

-- Lets go of the views and everything built from them, so the next read builds them afresh. No
-- generation bump: C:_Refresh calls it from a read.
function C:_Forget()
  self.views = nil
  self.byItem = nil
  self.byNpc = nil
  self.byNpcName = nil
  self.byZone = nil
  self.bySourceItem = nil
  self.bySourceQuest = nil
  self.disenchantTotals = nil
  self.dropsBySource = nil
  self.npcNames = nil
  self.npcNameChains, self.npcNameOrder, self.npcNameEmpty = nil, nil, nil
  self.namesStale, self.disenchantRecords = nil, nil
  self.pending, self.stale = nil, nil
  self.zoneMisses, self.ledgerViews = nil, nil
  self.viewsRecords, self.viewsBuilds, self.viewsBuildCount = nil, nil, nil
end

-- Every write: the generation moves, and the next read refreshes the views (C:_Refresh) and puts
-- the npc names back on the graph (C:_Index), which is what the rebuild a write used to cause did.
-- key, where given, is a row of the store this write added, changed or let go of. The lists built
-- for the search box and the Boss loot tab are let go, as before.
function C:_Touch(key)
  if self.views then
    self.stale = true
    if key ~= nil then
      self.pending = self.pending or {}
      self.pending[key] = true
    end
  end
  self.namesStale = true
  -- Built only for a pane or the search box, and built again from the views, as before.
  self.npcNames = nil
  self.dropsBySource = nil
  self.discoveredEntries = nil
  Collector.generation = Collector.generation + 1
end

-- Everything this collector worked out from its store goes. What Clear does, what a write the
-- views cannot follow does (an old shaped row adopted), and what a caller that changed the store
-- by hand calls.
function C:_Invalidate()
  self:_Forget()
  self.discoveredEntries = nil
  Collector.generation = Collector.generation + 1
  self.gatheredNodeNames = nil
  self.discQueue = nil
  Collector.requiresGeneration = Collector.requiresGeneration + 1
end

-- Brief R15: an old shaped record of the same fact, in a store not yet migrated (a spec's, or a
-- load that stopped half way), is converted into key before a write updates it, so one fact
-- never has two rows. Answers whether one was.
function C:_AdoptOld(kind, itemId, sourceKind, sourceId, key)
  local records = self.store.records
  local from = oldKey(kind, itemId, sourceKind, sourceId)
  local record = records[from]
  if from == key or not Collector.IsOldShape(record) then
    return false
  end
  local _, row = Collector.Compact(record, self.store, self:_Ledger())
  records[from] = nil
  if type(records[key]) == "table" and not Collector.IsOldShape(records[key]) then
    Collector.MergeRows(records[key], row)
  else
    records[key] = row
  end
  -- The running size is worked out afresh on the next ask.
  self.sizeBytes, self.sizeRecords = nil, nil
  return true
end

-- The build index new rows carry (Collector.BuildIndex), worked out once.
function C:_BuildIndex()
  if self.buildIndex == nil or self.store.builds == nil or self.store.builds[self.buildIndex] ~= self.build then
    self.buildIndex = Collector.BuildIndex(self.store, self.build) or false
  end
  return self.buildIndex or nil
end

-- Stores one sighting. Returns true when it was accepted.
function C:Record(kind, record)
  if not Collector.KINDS[kind] or type(record) ~= "table" then
    return false
  end
  -- A discovery names no source, so it never reaches the sighting store or the source index.
  if kind == "discovery" then
    return self:RecordDiscovery(record.itemId, record.name, record.quality, record.how)
  end
  if type(record.itemId) ~= "number" or type(record.sourceKind) ~= "string" then
    return false
  end

  local clean = Privacy.Sanitise(record)
  if type(clean.itemId) ~= "number" or type(clean.sourceKind) ~= "string" then
    return false
  end
  if looksLikeCharacter(clean.sourceName) then
    clean.sourceName = nil
  end

  local sourceId = type(clean.sourceId) == "number" and clean.sourceId or nil
  -- Brief C20: a source id that is not an id (Collector.ValidSourceId) is refused and counted,
  -- never written. The count is what /itemtree debug's collector line shows (C:Counts).
  if not Collector.ValidSourceId(sourceId) then
    self.store.refused = (tonumber(self.store.refused) or 0) + 1
    return false
  end
  local key = Collector.Key(kind, clean.itemId, clean.sourceKind, sourceId)
  if not key then
    return false
  end
  local adopted = self:_AdoptOld(kind, clean.itemId, clean.sourceKind, sourceId, key)
  local records = self.store.records
  local day = Collector.Day(self.now())
  local count = type(clean.count) == "number" and clean.count or 1
  local need = needOf(clean.need)
  local cost = Collector.Cost(clean.cost)
  -- Brief R15: a money price the ledger holds for this npc and item is not kept twice.
  if
    cost
    and kind == "vendor"
    and Collector.LedgerHolds(self:_Ledger(), clean.sourceKind, sourceId, clean.itemId, cost)
  then
    cost = false
  end
  -- Brief M3: only a vendor record carries where the player stood when its window opened.
  local pos, side = nil, nil
  if kind == "vendor" then
    pos = Collector.Position(clean.pos)
    -- Brief QN1: the side of the player at the window, the newest window's.
    side = Collector.Side(clean.side)
  end
  local mapId, zone = Collector.Place(clean.zone, clean.mapId)
  local build = self:_BuildIndex()
  local row = records[key]
  local existing = row ~= nil
  -- An old shaped row is its own view, and a node's name is in the object name set (NodeCategory).
  local oldShape = existing and Collector.IsOldShape(row)
  local heldName = existing and row.n or nil
  -- Brief R1: what the record took before this write, for the running size (C:Size).
  local before = 0
  if existing and self.sizeBytes then
    before = Collector.EntryBytes(key, row)
  end
  if existing then
    local seen = (positiveWhole(row.s) or 1) + 1
    local tally = (tonumber(row.c) or positiveWhole(row.s) or 1) + count
    local first = tonumber(row.f) or tonumber(row.l) or day
    row.s = seen
    row.c = nil
    if tally ~= seen then
      row.c = tally
    end
    row.l = day
    row.f = nil
    if first ~= day then
      row.f = first
    end
    if build then
      row.b = nil
      if build ~= 1 then
        row.b = build
      end
    end
    -- Restated rather than added to: see needOf. The client's latest word wins.
    if need then
      row.w = need
    end
    -- The newest window wins for the price: a vendor that has changed what it asks says so the
    -- next time it is opened. A window that stated no price leaves the last one standing, and one
    -- whose price the ledger holds takes it off the row.
    if cost then
      row.x = cost
    elseif cost == false then
      row.x = nil
    end
    if clean.sourceName and not row.n then
      row.n = clean.sourceName
    end
    -- The first zone stays; a text the client now gives the map of becomes the map.
    if not row.m and not row.z then
      row.m, row.z = mapId, zone
    elseif row.z and not row.m and mapId and Collector.MapName(mapId) == row.z then
      row.m, row.z = mapId, nil
    end
  else
    row = { n = clean.sourceName, m = mapId, z = zone, l = day, w = need }
    if count ~= 1 then
      row.c = count
    end
    if build and build ~= 1 then
      row.b = build
    end
    if cost then
      row.x = cost
    end
    records[key] = row
    self.store.counts[kind] = (self.store.counts[kind] or 0) + 1
  end
  -- Brief R15: the quality is the data's, and kept here only for an item the data does not know.
  if row.q == nil and type(clean.quality) == "number" and not Collector.DataKnows(clean.itemId) then
    row.q = clean.quality
  end
  if side then
    row.side = side
  end
  -- Brief QH1: the quest the looted item was an objective of, the newest window's. A window that
  -- names none leaves the last one standing: the quest may have left the log since.
  local lootQuest = Collector.LootQuest(kind, clean.quest)
  if lootQuest then
    row.o = lootQuest
  end
  -- The same for the position: the newest window wins.
  if pos then
    row.p = Collector.PackPosition(pos)
    row.P = pos.map
  end
  if row.P and row.P == row.m then
    row.P = nil
  end
  self:_Resize(key, before, not existing)
  if adopted or oldShape then
    self:_Invalidate()
  else
    -- The next read views this one row again (C:_Refresh) rather than every row.
    self:_Touch(key)
  end
  if Collector.OBJECT_RECORD_KINDS[kind] and clean.sourceKind == "object" and row.n ~= heldName then
    self.gatheredNodeNames = nil
  end
  if kind == "quest_requires" then
    Collector.requiresGeneration = Collector.requiresGeneration + 1
  end
  -- Brief R1: the store stays under its byte budget, and the record just written always stays.
  self:Prune(Collector.MAX_BYTES, key)
  return true
end

--------------------------------------------------------------------------------
-- The discovery store's packed shape (brief R3)
--
-- collector.discoveries maps an item id to one short string rather than a table: a table costs
-- about 420 bytes of heap whatever it holds, and the store is read at every login. Eight fields,
-- in this order, joined by "|" (Collector.DISCOVERY_SEP), each left empty where it says nothing:
--
--   h  who found it: "s" the player obtained it, "r" the realm found it (Collector.SOURCE_*)
--   d  the day it was first noted, whole days since the epoch (Collector.Day, UTC)
--   m  the minute of that day, 0 to 1439 (UTC), empty where the moment was not known: enough
--      for a find to read back, after a reload, as later than a look at the tab earlier the
--      same day (the unread count on the tab), and to order the finds of one day
--   b  the data build it was noted against, an index into collector.builds (the list the
--      compact records of brief R15 share)
--   q  the item's quality
--   r  the client's realm id (brief E66)
--   c  the name of the character that first saw it (brief E79), written only while the
--      Discoveries tab is on
--   n  the item's name, left out where the installed data build names the item itself
--      (Collector.DataNames), and last, so nothing a name holds can move a field
--
-- for example "s|20361|600|1|4|5123|Thrallgar|Hidden Relic" or "r|20361|0|1|3|5123||". "|" is the
-- client's own escape character, so an item's name never carries it as text and a character's
-- name never carries any punctuation at all; and the name is last, so even a name holding every
-- one of them reads back whole. collector.discoveriesShape is Collector.DISCOVERIES_SHAPE once
-- every record is packed (Collector.MigrateDiscoveries). Collector.ViewDiscovery turns a record
-- back into the table every reader has always taken, so nothing past this file sees the string.
--------------------------------------------------------------------------------

Collector.DISCOVERIES_SHAPE = 1
Collector.DISCOVERY_SEP = "|"

local DISCOVERY_PATTERN = "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$"
local MINUTES_A_DAY = 1440
local WHO_CODES = { self = "s", realm = "r" }
local WHO_NAMES = { s = "self", r = "realm" }

-- A quality as a record keeps it: a whole number from nought up, or nil. Pure.
local function qualityOf(value)
  if type(value) ~= "number" or value < 0 or value ~= value or value == math.huge or value % 1 ~= 0 then
    return nil
  end
  return value
end

-- A minute of the day as a record keeps it: a whole number from 0 to 1439, or nil. Pure.
local function minuteOf(value)
  value = tonumber(value)
  if not value or value < 0 or value >= MINUTES_A_DAY or value % 1 ~= 0 then
    return nil
  end
  return value
end

--- The UTC day and the minute of that day for a moment in seconds, or nil, nil. Pure.
function Collector.DayMinute(seconds)
  seconds = tonumber(seconds)
  if not seconds or seconds ~= seconds or seconds == math.huge or seconds == -math.huge then
    return nil, nil
  end
  local day = Collector.Day(seconds)
  return day, math.floor((seconds - day * DAY) / 60)
end

-- One field of a packed record as text: the number, or empty for none.
local function field(value)
  if value == nil then
    return ""
  end
  return tostring(value)
end

--- One discovery as its packed string. h is "self" or "realm" (anything else reads as realm),
--- day whole days, minute the minute of that day (0 to 1439, anything else left out), build an
--- index into collector.builds, quality, realm the realm id, character a name
--- Collector.CharacterName accepts (anything else is left out) and name the item's name or nil
--- where the data build names it. Pure.
function Collector.PackDiscovery(h, day, minute, build, quality, realm, character, name)
  local parts = {
    WHO_CODES[h] or WHO_CODES.realm,
    field(tonumber(day) and math.floor(tonumber(day)) or nil),
    field(minuteOf(minute)),
    field(positiveWhole(build)),
    field(qualityOf(quality)),
    field(Collector.RealmId(realm)),
    Collector.CharacterName(character) or "",
    type(name) == "string" and name or "",
  }
  return table.concat(parts, Collector.DISCOVERY_SEP)
end

--- A packed record's eight fields: h ("self" or "realm"), day, minute, build index, quality, realm id,
--- character and name, each nil where the record leaves it empty. Nothing for anything that is
--- not a packed record. No table is made. Pure.
function Collector.DiscoveryFields(value)
  if type(value) ~= "string" then
    return nil
  end
  local h, day, minute, build, quality, realm, character, name = value:match(DISCOVERY_PATTERN)
  if not h then
    return nil
  end
  if character == "" then
    character = nil
  end
  if name == "" then
    name = nil
  end
  return WHO_NAMES[h] or Collector.SOURCE_REALM,
    tonumber(day),
    minuteOf(minute),
    tonumber(build),
    tonumber(quality),
    tonumber(realm),
    character,
    name
end

--- Whether the installed data build names an item itself, so its discovery record need not: the
--- core set's Summary lists it among the named ids (Data:ShipsName, never a load), and where the
--- build's name table is already loaded, that name is the very one given. False, never nil.
function Collector.DataNames(itemId, name)
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.ShipsName) ~= "function" or type(itemId) ~= "number" then
    return false
  end
  local ok, ships = pcall(data.ShipsName, data, itemId)
  if not ok or ships ~= true then
    return false
  end
  if type(name) == "string" and type(data.ShippedName) == "function" then
    local okName, shipped = pcall(data.ShippedName, data, itemId, false)
    if okName and type(shipped) == "string" and shipped ~= name then
      return false
    end
  end
  return true
end

--- The name the installed data build gives an item, or nil (Data:ShippedName). load says whether
--- the data addon may be loaded to answer; without it, only a name already in hand is read.
function Collector.DataName(itemId, load)
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.ShippedName) ~= "function" then
    return nil
  end
  local ok, name = pcall(data.ShippedName, data, itemId, load == true)
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

--- One record as the table every reader takes: { n, q, b, t, h, realm, c }, with b the build
--- string out of builds (collector.builds), t the moment in seconds (at, where the caller has
--- the exact one, otherwise day * 86400 + minute * 60, the minute 0 where it is not known) and
--- n the data build's name where the record leaves it out (Collector.DataName, load as there).
--- A record still in the old shape is its own view. A new table the caller must not write to the
--- store; nil for anything that is not a record.
function Collector.ViewDiscovery(itemId, value, builds, at, load)
  if type(value) == "table" then
    return value
  end
  local h, day, minute, build, quality, realm, character, name = Collector.DiscoveryFields(value)
  if not h then
    return nil
  end
  local t = tonumber(at)
  if not t and day then
    t = day * DAY + (minute or 0) * 60
  end
  return {
    n = name or Collector.DataName(itemId, load),
    q = quality,
    b = type(builds) == "table" and build and builds[build] or nil,
    t = t,
    h = h,
    realm = realm,
    c = character,
  }
end

--- One old shaped record as its packed string, or nil for anything that is not one. store is the
--- collector's saved table, whose build list the build string joins (Collector.BuildIndex).
function Collector.PackRecord(itemId, record, store)
  if type(record) ~= "table" then
    return nil
  end
  local name = type(record.n) == "string" and record.n ~= "" and record.n or nil
  if name and Collector.DataNames(itemId, name) then
    name = nil
  end
  -- The old record's time is to the second: its day and its minute are kept.
  local day, minute = nil, nil
  if type(record.t) == "number" then
    day, minute = Collector.DayMinute(record.t)
  end
  local h = record.h == Collector.SOURCE_SELF and Collector.SOURCE_SELF or Collector.SOURCE_REALM
  local build = Collector.BuildIndex(store, record.b)
  return Collector.PackDiscovery(h, day, minute, build, record.q, record.realm, record.c, name)
end

-- Who found a record and on which realm, out of either shape, with no table made.
local function whoOf(value)
  if type(value) == "table" then
    return value.h, value.realm
  end
  local h, _, _, _, _, realm = Collector.DiscoveryFields(value)
  return h, realm
end

--- Who found a record ("self", "realm" or nil) and its realm id, out of either shape, with no
--- table made: the one read Core/Discoveries.lua's cache key makes of every record. Pure.
function Collector.DiscoveryWho(value)
  return whoOf(value)
end

--- Whether the Discoveries tab is on (settings.showDiscoveries). A record written while it is off
--- carries no character name (brief R3): only the tab ever reads one. Read guarded, so a spec or a
--- half loaded client with no saved settings counts as on.
function Collector.TabShown()
  local db = ItemTree.db
  local settings = type(db) == "table" and db.settings or nil
  if type(settings) ~= "table" then
    return true
  end
  return settings.showDiscoveries == true
end

-- One item the realm has discovered: this build withholds its details, and the client answered
-- with a name anyway, which means somebody on the realm has found it. Written once per item and
-- never overwritten, so the first name the client gave is the one that is kept.
--
-- What is stored is the item id, the item's name, its quality, the data build the note was taken
-- against and one short field saying how it was met (Collector.DISCOVERY_HOW: "self" or
-- "realm"), plus the client's numeric realm id where it answers one (C:RealmId), so a record made
-- on another realm the player plays on can be told apart. An item name is not personal data and
-- the realm id is a bare number. The one exception is c, the name of the character that first
-- saw the item (brief E79, C:Character), added after the sanitiser, drawn on the Discoveries
-- tab alone, and written only while that tab is on (brief R3). Nothing about the realm's name or
-- the account, which is the rule for every store in this addon (Core/Privacy.lua, which the rest
-- of the record still goes through). There is no source here and no sighting: a discovery is a
-- fact about the build, not about the player.
--
-- Brief R3: the record is packed (Collector.PackDiscovery), the moment is kept as a day, the name
-- is left out where the data build names the item, and the store is held to its byte budget
-- (C:PruneDiscoveries), never evicting the record just written.
--
-- The name is handed to the graph as it is written, so a withheld item keeps the name across a
-- session where the client has forgotten it, and Data:SearchItems finds it.
--
-- how names the path the caller was on when it met the item. Written once and never overwritten,
-- the way the name is; the one thing a later meeting can still teach the record is that the
-- player has since obtained the item, which is C:UpgradeDiscovery.
function C:RecordDiscovery(itemId, name, quality, how)
  if type(itemId) ~= "number" or type(name) ~= "string" or name == "" then
    return false
  end
  local clean = Privacy.Sanitise({ itemId = itemId, name = name, quality = quality })
  if type(clean.itemId) ~= "number" or type(clean.name) ~= "string" or clean.name == "" then
    return false
  end
  if looksLikeCharacter(clean.name) then
    return false
  end
  Graph.SetName(Graph.Key("item", clean.itemId), clean.name)
  local id = clean.itemId
  if self.store.discoveries[id] ~= nil then
    return false
  end
  local now = self.now()
  local stored = clean.name
  if Collector.DataNames(id, stored) then
    stored = nil
  end
  -- After the sanitiser on purpose: the one field brief E79 allows, see C:Character, and only
  -- while the tab that draws it is on.
  local character = nil
  if Collector.TabShown() then
    character = self:Character()
  end
  local day, minute = Collector.DayMinute(now)
  self.store.discoveries[id] = Collector.PackDiscovery(
    Collector.DiscoverySource(how),
    day,
    minute,
    self:_BuildIndex(),
    type(clean.quality) == "number" and clean.quality or nil,
    self:RealmId(),
    character,
    stored
  )
  self.discoveryTimes[id] = tonumber(now)
  self:_DiscoveryResize(id, 0, true)
  self:_QueueDiscovery(id)
  self:_Touch()
  self:PruneDiscoveries(nil, id)
  return true
end

-- Promotes a record from "someone on the realm found this" to "you obtained this", keeping the
-- moment it was first noted: the discovery happened when it happened, and the player getting
-- hold of the item later does not move it.
--
-- One direction only. A record already marked "self" is never weakened by a later sighting, and
-- a record with no h at all is from before the field existed, so it can be promoted like any
-- other.
--
-- It is also the one place a record moves realm. The caller comes here for every later meeting
-- with an item already noted, so an item first noted on another realm and now met on this one is
-- stamped with this realm's id: it is here now, and the pane says so. The name and the moment
-- stay as they were. Returns true when something changed, which is what tells the pane to redraw.
function C:UpgradeDiscovery(itemId, how)
  local id = tonumber(itemId)
  local held = id and self.store.discoveries[id] or nil
  local realm = self:RealmId()
  local promote = Collector.DiscoverySource(how) == Collector.SOURCE_SELF
  if type(held) == "table" then
    local changed = false
    if realm and held.realm ~= realm then
      held.realm = realm
      changed = true
    end
    if held.h ~= Collector.SOURCE_SELF and promote then
      held.h = Collector.SOURCE_SELF
      changed = true
    end
    if changed then
      self:_DiscoveryResize(id, nil, false)
      self:_Touch()
    end
    return changed
  end
  local h, day, minute, build, quality, heldRealm, character, name = Collector.DiscoveryFields(held)
  if not h then
    return false
  end
  local changed = false
  if realm and heldRealm ~= realm then
    heldRealm = realm
    changed = true
  end
  if h ~= Collector.SOURCE_SELF and promote then
    h = Collector.SOURCE_SELF
    changed = true
  end
  if changed then
    local before = Collector.EntryBytes(id, held)
    self.store.discoveries[id] = Collector.PackDiscovery(h, day, minute, build, quality, heldRealm, character, name)
    self:_DiscoveryResize(id, before, false)
    self:_Touch()
  end
  return changed
end

-- Who found one discovered item, or nil for an id this store has never noted. A record written
-- before the field existed reads as "realm": nothing can now say otherwise.
function C:DiscoverySource(itemId)
  local held = self.store.discoveries[itemId]
  if held == nil then
    return nil
  end
  local h = whoOf(held)
  if h == nil and type(held) ~= "table" then
    return nil
  end
  return h == Collector.SOURCE_SELF and Collector.SOURCE_SELF or Collector.SOURCE_REALM
end

-- What this client has watched the realm discover, keyed by item id. The store's own table, in
-- its packed shape: read each record through C:DiscoveryView (or Collector.ViewDiscovery), never
-- change it.
function C:Discoveries()
  return self.store.discoveries
end

-- One record as the table readers take (Collector.ViewDiscovery), with the build list and this
-- session's exact moment filled in. value is the record where the caller already holds it
-- (a walk of C:Discoveries), otherwise it is looked up. load as for Collector.DataName. nil for an
-- id never noted.
function C:DiscoveryView(itemId, value, load)
  if value == nil then
    value = self.store.discoveries[itemId]
  end
  if value == nil then
    return nil
  end
  local times = self.discoveryTimes or EMPTY
  return Collector.ViewDiscovery(itemId, value, self.store.builds, times[itemId], load)
end

-- Whether this store holds a record for an item, whatever the record says. The question
-- UI/CollectorHooks.lua and Data:ClientNames ask: a record whose name the data build carries
-- still counts before that name is loaded.
function C:HasDiscovery(itemId)
  local held = self.store.discoveries[itemId]
  return type(held) == "table" or type(held) == "string"
end

-- The name of the character that first saw one discovered item, or nil for an id never noted
-- or a record written without one (brief E79). Only the Discoveries tab reads it.
function C:DiscoveryCharacter(itemId)
  local held = self.store.discoveries[itemId]
  if type(held) == "table" then
    return Collector.CharacterName(held.c)
  end
  local _, _, _, _, _, _, character = Collector.DiscoveryFields(held)
  return Collector.CharacterName(character)
end

-- One discovered item's name, or nil. The reader Core/Graph.lua's item naming falls back to
-- after the client itself (Graph.SetItemNameSource, set by C:Install), so a name survives a
-- session where the client answers nothing. A record the data build names answers the data's
-- name where it is already loaded, and nil before: the data addon is never loaded for this.
function C:DiscoveredName(itemId)
  local held = self.store.discoveries[itemId]
  if type(held) == "table" then
    return held.n
  end
  if held == nil then
    return nil
  end
  local _, _, _, _, _, _, _, name = Collector.DiscoveryFields(held)
  return name or Collector.DataName(itemId, false)
end

-- The discoveries the search box walks after the name index (Data:SearchItems), sorted by name,
-- built once and dropped whenever anything is recorded. Columns rather than a table per item
-- (brief R3): { id = {...}, name = {...}, lower = {...}, quality = {...} }, one position per
-- item. A record the data build names is left out while the build's own index lists it, which
-- is every time but one: with "Show items found on the beta" off, the index hides a harvested
-- item and the record is the only thing that finds it, so it stays, named from the data.
function C:DiscoveredEntries()
  if self.discoveredEntries then
    return self.discoveredEntries
  end
  local found = {}
  local data = ItemTree.Data
  local masked = type(data) == "table" and type(data.HarvestMasked) == "function"
  for itemId, held in pairs(self.store.discoveries) do
    local name
    if type(held) == "table" then
      name = held.n
    else
      local _, _, _, _, _, _, _, stored = Collector.DiscoveryFields(held)
      name = stored
      if not name and masked and type(itemId) == "number" then
        local ok, hidden = pcall(data.HarvestMasked, data, itemId)
        if ok and hidden == true then
          name = Collector.DataName(itemId, true)
        end
      end
    end
    if type(itemId) == "number" and type(name) == "string" and name ~= "" then
      found[#found + 1] = { itemId, name }
    end
  end
  table.sort(found, function(a, b)
    if a[2] ~= b[2] then
      return a[2] < b[2]
    end
    return a[1] < b[1]
  end)
  local columns = { id = {}, name = {}, lower = {}, quality = {} }
  for pos, pair in ipairs(found) do
    local itemId, name = pair[1], pair[2]
    local held = self.store.discoveries[itemId]
    local quality
    if type(held) == "table" then
      quality = held.q
    else
      local _, _, _, _, stored = Collector.DiscoveryFields(held)
      quality = stored
    end
    columns.id[pos], columns.name[pos], columns.lower[pos] = itemId, name, name:lower()
    columns.quality[pos] = quality
  end
  self.discoveredEntries = columns
  return columns
end

local function push(index, id, record)
  if id == nil then
    return
  end
  index[id] = index[id] or {}
  local bucket = index[id]
  bucket[#bucket + 1] = record
end

-- The order every bucket is kept in: kind, then the source id, then the item id. All three come
-- from the record's key, so a record's place in a bucket never moves when it is seen again.
local function bucketOrder(a, b)
  if a.kind ~= b.kind then
    return a.kind < b.kind
  end
  if (a.sourceId or 0) ~= (b.sourceId or 0) then
    return (a.sourceId or 0) < (b.sourceId or 0)
  end
  return a.itemId < b.itemId
end

local function sortBucket(bucket)
  table.sort(bucket, bucketOrder)
end

-- One record into a bucket that is already in order, after any record it ties with.
local function insert(index, id, record)
  if id == nil then
    return
  end
  local bucket = index[id]
  if not bucket then
    index[id] = { record }
    return
  end
  local low, high = 1, #bucket
  while low <= high do
    local mid = math.floor((low + high) / 2)
    if bucketOrder(record, bucket[mid]) then
      high = mid - 1
    else
      low = mid + 1
    end
  end
  table.insert(bucket, low, record)
end

-- One record out of its bucket, the bucket going with its last record, as a build without it
-- would have none.
local function remove(index, id, record)
  local bucket = id ~= nil and index[id] or nil
  if not bucket then
    return
  end
  local low, high = 1, #bucket
  while low <= high do
    local mid = math.floor((low + high) / 2)
    if bucketOrder(bucket[mid], record) then
      low = mid + 1
    else
      high = mid - 1
    end
  end
  local at = nil
  for pos = low, #bucket do
    if bucket[pos] == record then
      at = pos
      break
    end
    if bucketOrder(record, bucket[pos]) then
      break
    end
  end
  if not at then
    for pos = 1, #bucket do
      if bucket[pos] == record then
        at = pos
        break
      end
    end
  end
  if at then
    table.remove(bucket, at)
    if bucket[1] == nil then
      index[id] = nil
    end
  end
end

-- Every bucket of the index one record is filed in, each handed to op(index, id, record): push
-- while the index is built, insert and remove as single records come and go (C:_Refresh).
function C:_Slots(record, op)
  op(self.byItem, record.itemId, record)
  -- Brief Z1: the drop, vendor, gathering and fishing records, by their zone text lower cased.
  if ZONE_KINDS[record.kind] and type(record.zone) == "string" and record.zone ~= "" then
    op(self.byZone, record.zone:lower(), record)
  end
  -- Brief N2: the drop and vendor records that name an NPC, by its id and by its name.
  if record.sourceKind == "npc" and NPC_SPECS[record.kind] and type(record.sourceId) == "number" then
    op(self.byNpc, record.sourceId, record)
    op(self.byNpcName, npcName(record.sourceName), record)
  end
  if record.sourceKind == "item" then
    op(self.bySourceItem, record.sourceId, record)
  elseif record.sourceKind == "quest" then
    -- Every quest sourced record is filed here and the spec's `reverse` decides at emit time
    -- whether the quest has anything to say back: a reward does not, a requirement does.
    op(self.bySourceQuest, record.sourceId, record)
  end
end

-- The disenchant totals (C:_Percent) with one record added (sign 1) or taken away (sign -1). A
-- source with no disenchant record left has no total, as a build without it would have none.
function C:_Tally(record, sign)
  if record.kind ~= "disenchant" or not record.sourceId then
    return
  end
  local id = record.sourceId
  local totals, held = self.disenchantTotals, self.disenchantRecords
  held[id] = (held[id] or 0) + sign
  if held[id] <= 0 then
    totals[id], held[id] = nil, nil
  else
    totals[id] = (totals[id] or 0) + sign * (record.count or 1)
  end
end

-- The NPC's name on the graph, so its page and the Classic Era name it joins can be found from its
-- key alone. Every record that names an NPC by id is noted under that NPC's graph key, in the
-- order the index met them (npcNameChains, { [npc key] = { record, ... } }): a build sets each one's
-- name in that order, so the last record noted under a key is the name the graph is left with,
-- and after a write the next read puts exactly those names back (C:_Index). Answers the key.
local function npcNameKey(record)
  if
    record.sourceKind == "npc"
    and NPC_SPECS[record.kind]
    and type(record.sourceId) == "number"
    and type(record.sourceName) == "string"
  then
    return Graph.Key("npc", record.sourceId)
  end
  return nil
end

-- Each chain also sits in npcNameOrder, a list the next read walks (a list is walked faster than
-- a map); a chain emptied stays in the list until the list is half empty chains, then the list is
-- made again from the map.
function C:_NoteNpcName(record)
  local npcKey = npcNameKey(record)
  if npcKey then
    local chains = self.npcNameChains
    local chain = chains[npcKey]
    if not chain then
      chain = { key = npcKey }
      chains[npcKey] = chain
      local order = self.npcNameOrder
      order[#order + 1] = chain
    end
    chain[#chain + 1] = record
  end
  return npcKey
end

function C:_ForgetNpcName(record)
  local npcKey = npcNameKey(record)
  local chains = self.npcNameChains
  local chain = npcKey and chains[npcKey] or nil
  if not chain then
    return
  end
  for at = #chain, 1, -1 do
    if chain[at] == record then
      table.remove(chain, at)
      break
    end
  end
  if chain[1] == nil then
    chains[npcKey] = nil
    self.npcNameEmpty = (self.npcNameEmpty or 0) + 1
    if self.npcNameEmpty * 2 > #self.npcNameOrder then
      local order = {}
      for _, held in pairs(chains) do
        order[#order + 1] = held
      end
      self.npcNameOrder, self.npcNameEmpty = order, 0
    end
  end
end

-- One record into the index already built, or out of it (C:_Refresh).
function C:_IndexAdd(record)
  if self.byItem then
    self:_Slots(record, insert)
    self:_Tally(record, 1)
    self:_NoteNpcName(record)
  end
end

function C:_IndexRemove(record)
  if self.byItem then
    self:_Slots(record, remove)
    self:_Tally(record, -1)
    self:_ForgetNpcName(record)
  end
end

function C:_Index()
  local views = self:Records()
  if self.byItem then
    -- A write since the index was built put every npc name back on the graph the next time it
    -- was read; so does this, with no rebuild (C:_Touch): the name each key was left with. One
    -- the graph already holds is not set again, which changes nothing.
    if self.namesStale then
      self.namesStale = nil
      local held, order = Graph.names, self.npcNameOrder
      for at = 1, #order do
        local chain = order[at]
        local count = #chain
        if count > 0 then
          local npcKey, name = chain.key, chain[count].sourceName
          if held[npcKey] ~= name then
            Graph.SetName(npcKey, name)
            held = Graph.names
          end
        end
      end
    end
    return
  end
  self.namesStale = nil
  self.byItem, self.bySourceItem, self.bySourceQuest, self.disenchantTotals = {}, {}, {}, {}
  self.disenchantRecords = {}
  self.byNpc, self.byNpcName = {}, {}
  self.byZone = {}
  self.npcNameChains, self.npcNameOrder, self.npcNameEmpty = {}, {}, 0
  for _, record in pairs(views) do
    self:_Slots(record, push)
    local npcKey = self:_NoteNpcName(record)
    if npcKey then
      Graph.SetName(npcKey, record.sourceName)
    end
    if record.kind == "disenchant" and record.sourceId then
      self.disenchantTotals[record.sourceId] = (self.disenchantTotals[record.sourceId] or 0) + (record.count or 1)
      self.disenchantRecords[record.sourceId] = (self.disenchantRecords[record.sourceId] or 0) + 1
    end
  end
  for _, bucket in pairs(self.byItem) do
    sortBucket(bucket)
  end
  for _, bucket in pairs(self.bySourceItem) do
    sortBucket(bucket)
  end
  for _, bucket in pairs(self.bySourceQuest) do
    sortBucket(bucket)
  end
  for _, bucket in pairs(self.byNpc) do
    sortBucket(bucket)
  end
  for _, bucket in pairs(self.byNpcName) do
    sortBucket(bucket)
  end
  for _, bucket in pairs(self.byZone) do
    sortBucket(bucket)
  end
end

-- Every drop and vendor record one npc key stands for (brief N2), sorted the way every other
-- bucket is. The join is by name: an NPC the player met under one id and another of the same name
-- (two spawns of one Supply Officer, or a Classic Era vendor node of that name) are one page, so a
-- key the graph can name reads every record of that name, and a key it cannot name reads the
-- records of its own id. The list is new and the caller's own.
function C:NpcRecords(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "npc" or type(id) ~= "number" then
    return {}
  end
  self:_Index()
  local out, held = {}, {}
  local function take(bucket)
    for _, record in ipairs(bucket or EMPTY) do
      if not held[record] then
        held[record] = true
        out[#out + 1] = record
      end
    end
  end
  local name = npcName(Graph.Name(key))
  if id > 0 then
    take(self.byNpc[id])
    -- The name its own records carry, for a key the graph has not been told about yet.
    for _, record in ipairs(self.byNpc[id] or EMPTY) do
      if not name then
        name = npcName(record.sourceName)
      end
    end
  end
  if name then
    take(self.byNpcName[name])
  end
  sortBucket(out)
  return out
end

-- Brief Z1: the records one zone's page lists, read only: every drop, vendor, gathering and fishing
-- record whose zone text is the area's name (matched without regard to case), one entry per kind,
-- item and source name, with the tallies of two spawns of one name added together, the most seen
-- first. Each entry is { kind, itemId, name, count }, new and the caller's own. Ids, names and zones
-- of things in the world only; the index is built with the others and dropped by _Invalidate.
--
-- Brief N1: an entry whose records name an npc by its id also carries npcId (the lowest such id
-- among the records it merges), the npc page its source name opens on the zone's Here tab.
--
-- Brief PS2: an entry also carries shipped = true where the installed data ships the fact of any
-- record it merges as a player sourced row (Collector.ShipsAsPlayer, which reads a PlayerSources
-- module already built and never loads one).
function C:ZoneRecords(areaName)
  if type(areaName) ~= "string" or areaName == "" then
    return {}
  end
  self:_Index()
  local merged, out = {}, {}
  for _, record in ipairs(self.byZone[areaName:lower()] or EMPTY) do
    if type(record.itemId) == "number" then
      local name = type(record.sourceName) == "string" and record.sourceName or ""
      local slot = record.kind .. "\0" .. tostring(record.itemId) .. "\0" .. name:lower()
      local held = merged[slot]
      local count = tonumber(record.count) or 1
      if held then
        held.count = held.count + count
      else
        held = { kind = record.kind, itemId = record.itemId, count = count }
        if name ~= "" then
          held.name = name
        end
        merged[slot] = held
        out[#out + 1] = held
      end
      local npcId = record.sourceKind == "npc" and positiveWhole(record.sourceId) or nil
      if npcId and (not held.npcId or npcId < held.npcId) then
        held.npcId = npcId
      end
      -- Brief PS2: the installed data ships this fact as a player sourced row, so the zone's row
      -- wears no verified check, as on the item's page (shippedTier, below).
      if
        not held.shipped and Collector.ShipsAsPlayer(record.kind, record.itemId, record.sourceKind, record.sourceId)
      then
        held.shipped = true
      end
    end
  end
  table.sort(out, function(a, b)
    if a.count ~= b.count then
      return a.count > b.count
    end
    if a.itemId ~= b.itemId then
      return a.itemId < b.itemId
    end
    if (a.name or "") ~= (b.name or "") then
      return (a.name or "") < (b.name or "")
    end
    return a.kind < b.kind
  end)
  return out
end

-- What the collector holds about one npc key, for the page's tabs and its header, or nil where it
-- holds nothing: how many items it dropped and sold, the name it was seen under and the zone of the
-- record seen most recently. Ids, names and zones of things in the world only: nothing about the
-- player.
function C:NpcFacts(key)
  local records = self:NpcRecords(key)
  if #records == 0 then
    return nil
  end
  local facts = { drops = 0, sells = 0 }
  local latest, placed = nil, nil
  for _, record in ipairs(records) do
    -- Brief M3: where the player stood the last time they opened this vendor's window.
    if type(record.pos) == "table" and (not placed or (record.last or 0) > (placed.last or 0)) then
      placed = record
    end
    -- Brief SK1: what was skinned or pickpocketed off it is loot on its page too.
    if record.kind == "drop" or record.kind == "skin" or record.kind == "pickpocket" then
      facts.drops = facts.drops + 1
    elseif record.kind == "vendor" then
      facts.sells = facts.sells + 1
    end
    if not facts.name and type(record.sourceName) == "string" then
      facts.name = record.sourceName
    end
    if type(record.zone) == "string" and record.zone ~= "" then
      if not latest or (record.last or 0) > (latest.last or 0) then
        latest = record
      end
    end
  end
  facts.zone = latest and latest.zone or nil
  facts.pos = placed and Collector.Position(placed.pos) or nil
  return facts
end

-- Brief BL2: the drop records the Boss loot tab reads, by where they dropped. One pass over the
-- store the first time it is asked, kept until the next write (C:_Invalidate):
--
--   { byId = { [creatureId] = { record, ... } },
--     byName = { [lower name .. "\0" .. lower zone] = { record, ... } } }
--
-- Only kind "drop" with sourceKind "npc" counts. byId is keyed by the creature id the record's
-- sourceId holds; byName by the target's name and the zone text together, trimmed and in lower
-- case, for a boss the data knows no creature id for. Read only: the records are the store's own,
-- so a caller never writes to them, and nothing about what is stored changes.
-- npcName's lower case, trimmed as well, because a zone text can carry the client's spaces.
local function foldKey(text)
  local lowered = npcName(text)
  if not lowered then
    return nil
  end
  local folded = lowered:match("^%s*(.-)%s*$")
  if folded == "" then
    return nil
  end
  return folded
end

-- The buckets of C:DropsBySource one record is filed in, each handed to op(index, id, record).
function C:_DropSlots(drops, record, op)
  if type(record) == "table" and record.kind == "drop" and record.sourceKind == "npc" then
    if type(record.sourceId) == "number" then
      op(drops.byId, record.sourceId, record)
    end
    local name, zone = foldKey(record.sourceName), foldKey(record.zone)
    if name and zone then
      op(drops.byName, name .. "\0" .. zone, record)
    end
  end
end

function C:DropsBySource()
  local views = self:Records()
  if self.dropsBySource then
    return self.dropsBySource
  end
  local byId, byName = {}, {}
  local drops = { byId = byId, byName = byName }
  for _, record in pairs(views) do
    self:_DropSlots(drops, record, push)
  end
  for _, bucket in pairs(byId) do
    sortBucket(bucket)
  end
  for _, bucket in pairs(byName) do
    sortBucket(bucket)
  end
  self.dropsBySource = drops
  return drops
end

-- Brief M3: every vendor record of one item, the list Core/Sources.lua Favour matches its shipped
-- rows against. The index's own records: read them, never change them. Empty for none.
function C:VendorRecords(itemId)
  self:_Index()
  local out = {}
  for _, record in ipairs(self.byItem[itemId] or EMPTY) do
    if record.kind == "vendor" then
      out[#out + 1] = record
    end
  end
  return out
end

-- Brief V1: the name the player's own records give one npc id, or nil. A vendor record comes first,
-- because a visit to the vendor's window is where the client stated the name of the very npc the
-- client's vendor tables list; any other record naming that id (a drop off the same npc) is next.
-- Among records of one kind the most recently seen wins. records is any list of records; nothing
-- is guessed and nothing but a record's own sourceName is read. Pure.
function Collector.VendorName(npcId, records)
  if type(npcId) ~= "number" then
    return nil
  end
  local vendor, other = nil, nil
  for _, record in ipairs(type(records) == "table" and records or EMPTY) do
    if
      type(record) == "table"
      and record.sourceId == npcId
      and (record.sourceKind == nil or record.sourceKind == "npc")
      and type(record.sourceName) == "string"
      and record.sourceName ~= ""
    then
      if record.kind == "vendor" then
        if not vendor or (record.last or 0) > (vendor.last or 0) then
          vendor = record
        end
      elseif not other or (record.last or 0) > (other.last or 0) then
        other = record
      end
    end
  end
  local best = vendor or other
  return best and best.sourceName or nil
end

-- Brief V1: Collector.VendorName over this store's records of one npc id (the by-NPC index).
function C:VendorName(npcId)
  if type(npcId) ~= "number" then
    return nil
  end
  self:_Index()
  return Collector.VendorName(npcId, self.byNpc[npcId])
end

-- Brief V1: whether the player's own vendor records name this npc id: a visit to its window stored
-- the client's name for it. What /itemtree debug counts the client's vendors by.
function C:VisitedVendor(npcId)
  if type(npcId) ~= "number" then
    return false
  end
  self:_Index()
  for _, record in ipairs(self.byNpc[npcId] or EMPTY) do
    if record.kind == "vendor" and type(record.sourceName) == "string" and record.sourceName ~= "" then
      return true
    end
  end
  return false
end

-- Brief M3: the id the player's own records hold for an NPC of this name (any case) in this zone,
-- the most recently seen where there are several, or nil. A zone of nil matches any zone. What a
-- shipped vendor the file gives no id adopts, so its rows and the collected ones are one page.
function C:NpcIdByName(name, zone)
  local wanted = npcName(name)
  if not wanted then
    return nil
  end
  self:_Index()
  local best = nil
  for _, record in ipairs(self.byNpcName[wanted] or EMPTY) do
    if type(record.sourceId) == "number" and (zone == nil or record.zone == nil or record.zone == zone) then
      if not best or (record.last or 0) > (best.last or 0) then
        best = record
      end
    end
  end
  return best and best.sourceId or nil
end

-- Brief N1: every NPC the player's own records name by its id, for the search box, as
--
--   { [npcId] = { name = "Zerril Softbreeze", vendor = true, dropped = nil, quest = nil } }
--
-- out of the drop and vendor records that name an npc id (the name Collector.VendorName gives, a
-- vendor visit's first) and the quest NPC records that carry both an id and a name (brief Q8).
-- vendor is set where a vendor record names the id, dropped where a drop record does and quest
-- where a "give" record does; each is true or nil. Built once and kept until the next write
-- (C:_Invalidate). Ids and names of things in the world only: nothing about the player, and the
-- caller reads the table, never writes it.
function C:NpcNames()
  if self.npcNames then
    return self.npcNames
  end
  self:_Index()
  local out = {}
  for npcId, bucket in pairs(self.byNpc) do
    local name = Collector.VendorName(npcId, bucket)
    if name then
      local held = { name = name }
      for _, record in ipairs(bucket) do
        if record.kind == "vendor" then
          held.vendor = true
        elseif record.kind == "drop" then
          held.dropped = true
        end
      end
      out[npcId] = held
    end
  end
  local quests = type(self.store.questNpcs) == "table" and self.store.questNpcs or EMPTY
  for _, byQuest in pairs(quests) do
    for kind, record in pairs(type(byQuest) == "table" and byQuest or EMPTY) do
      local npcId = type(record) == "table" and positiveWhole(record.npcId) or nil
      if npcId then
        local held = out[npcId]
        if not held and type(record.name) == "string" and record.name ~= "" then
          held = { name = record.name }
          out[npcId] = held
        end
        if held and kind == "give" then
          held.quest = true
        end
      end
    end
  end
  self.npcNames = out
  return out
end

-- Brief M3: how many vendor records carry a position, for the debug report. A count only: the
-- coordinates themselves are never printed.
function C:PositionCount()
  local count = 0
  for _, record in pairs(self:Records()) do
    if record.kind == "vendor" and type(record.pos) == "table" then
      count = count + 1
    end
  end
  return count
end

-- Brief Q8: the two ends of a quest the player met in person. "give" is the NPC that offered it
-- (QUEST_DETAIL, then QUEST_ACCEPTED for the same quest) and "end" the one it was handed in to
-- (QUEST_COMPLETE). Anything else is refused.
Collector.QUEST_NPC_KINDS = { give = true, ["end"] = true }

-- One quest NPC record as the store keeps it, or nil for anything that is not one:
--
--   { questId = 92517, kind = "give", npcId = 261410, name = "Captain Vale", mapId = 1436,
--     x = 45.2, y = 61.0, when = 1790000000 }
--
-- fields is { npcId, objectId, name, pos = { map, x, y } } (pos in percent, Collector.Position).
-- The NPC is named by at least one of its id and its name; a record with neither says nothing.
-- Brief QH1: a world object that gives or takes a quest (a wanted poster, a chest, a sign) is kept
-- by its object id (objectId, the GameObject GUID's id, Privacy.SanitiseGuid) the way a creature is
-- kept by npcId; a record holds one of the two, never both (a creature id wins). The
-- name is the one the client showed over the NPC, which is game data, and a name shaped like a
-- character's ("Thrall-Frostmourne") is dropped the way Record drops one. The position is where
-- the player stood when the window opened, kept as the NPC's rough place exactly as a vendor
-- visit keeps one (brief M3): never printed, never sent. Pure.
function Collector.QuestNpcRecord(questId, kind, fields, when)
  questId = positiveWhole(questId)
  if not questId or not Collector.QUEST_NPC_KINDS[kind] or type(fields) ~= "table" then
    return nil
  end
  local npcId = positiveWhole(fields.npcId)
  local objectId = not npcId and positiveWhole(fields.objectId) or nil
  local name = fields.name
  if type(name) ~= "string" or name == "" or looksLikeCharacter(name) then
    name = nil
  end
  if not npcId and not objectId and not name then
    return nil
  end
  local pos = Collector.Position(fields.pos)
  return {
    questId = questId,
    kind = kind,
    npcId = npcId,
    objectId = objectId,
    name = name,
    mapId = pos and pos.map or nil,
    x = pos and pos.x or nil,
    y = pos and pos.y or nil,
    when = type(when) == "number" and when or nil,
  }
end

-- Brief R9: a quest's title as the store keeps it, or nil: the text the client showed, 1 to 255
-- bytes, no control characters, and nothing shaped like a character's name. Game data. Pure.
Collector.MAX_TITLE = 255

function Collector.QuestTitle(value)
  if type(value) ~= "string" or value == "" or #value > Collector.MAX_TITLE then
    return nil
  end
  if value:find("%c") or looksLikeCharacter(value) then
    return nil
  end
  return value
end

-- Brief Q8: stores who gave or took back one quest, updated in place: one record per quest per
-- kind, so taking the same quest twice (an abandon and a retake) leaves one record, the newest.
-- A later window that states less than the stored one (no position, say) keeps what was known.
-- Brief R9: fields.title, the quest's title as the window showed it, is kept once per quest, as
-- questNpcs[questId].title beside the two records, and the newest window's title wins.
-- Brief QN1: a give record also keeps at, the server time in whole seconds when it was FIRST
-- recorded (GetServerTime), and keeps it through every later window, whoever gave it then (a
-- record written before QN1 never gains one): one integer, which the pipeline compares with quest
-- id order to number same titled quests.
-- Returns true when it was accepted.
function C:RecordQuestNpc(questId, kind, fields)
  local record = Collector.QuestNpcRecord(questId, kind, fields, self.now())
  if not record then
    return false
  end
  local byQuest = self.store.questNpcs[record.questId]
  if type(byQuest) ~= "table" then
    byQuest = {}
    self.store.questNpcs[record.questId] = byQuest
  end
  local existing = byQuest[kind]
  -- A give record written before brief QN1 keeps having none: its first accept is long past, and
  -- a retake's time would put it out of order.
  if kind == "give" then
    if type(existing) == "table" then
      record.at = positiveWhole(existing.at)
    else
      local ok, now = pcall(self.serverNow)
      record.at = ok and positiveWhole(now) or nil
    end
  end
  if type(existing) == "table" and existing.npcId == record.npcId and existing.objectId == record.objectId then
    record.name = record.name or existing.name
    if not record.mapId then
      record.mapId, record.x, record.y = existing.mapId, existing.x, existing.y
    end
  end
  byQuest[kind] = record
  if record.npcId and record.name then
    Graph.SetName(Graph.Key("npc", record.npcId), record.name)
  elseif record.objectId and record.name then
    -- Brief QH1: a Forever object's own page (object:<id>) is named by the record, as an npc is.
    Graph.SetName(Graph.Key("object", record.objectId), record.name)
  end
  local title = Collector.QuestTitle(fields.title)
  if title then
    byQuest.title = title
    Graph.SetName(Graph.Key("quest", record.questId), title)
  end
  self:_Touch()
  return true
end

-- Brief Q8: what the store holds for one quest, { give = record, ["end"] = record } with either
-- absent, or nil where it holds neither. The store's own records: read them, never change them.
function C:QuestNpcs(questId)
  if type(questId) ~= "number" then
    return nil
  end
  local byQuest = self.store.questNpcs[questId]
  if type(byQuest) ~= "table" or (byQuest.give == nil and byQuest["end"] == nil) then
    return nil
  end
  return byQuest
end

-- Brief CS1: where the player's own records place one npc id: every quest it gave or took back whose
-- record kept a position, and where they last stood at its vendor window (C:NpcFacts' pos), each
-- { map, x, y } in map percent (Collector.Position). A new list, the caller's own; empty for none.
-- Positions in the world only, never printed: UI/Map.lua confirms a hand kept spot near one.
function C:NpcPlaces(npcId)
  local out = {}
  npcId = positiveWhole(npcId)
  if not npcId then
    return out
  end
  for _, byQuest in pairs(type(self.store.questNpcs) == "table" and self.store.questNpcs or EMPTY) do
    for kind in pairs(Collector.QUEST_NPC_KINDS) do
      local record = type(byQuest) == "table" and byQuest[kind] or nil
      if type(record) == "table" and record.npcId == npcId then
        local pos = Collector.Position({ map = record.mapId, x = record.x, y = record.y })
        if pos then
          out[#out + 1] = pos
        end
      end
    end
  end
  local facts = self:NpcFacts(Graph.Key("npc", npcId))
  if type(facts) == "table" and type(facts.pos) == "table" then
    out[#out + 1] = facts.pos
  end
  return out
end

-- Brief Q8: how many quests the store holds a giver or a turn in for, for the debug report. A
-- count only: never a name or a place.
function C:QuestNpcCount()
  local count = 0
  for _, byQuest in pairs(self.store.questNpcs) do
    if type(byQuest) == "table" and (byQuest.give ~= nil or byQuest["end"] ~= nil) then
      count = count + 1
    end
  end
  return count
end

-- Brief Q9: the same store split by kind, how many quests hold a "give" record and how many an
-- "end" one, so the debug report shows the giver path working after one accept. Counts only.
function C:QuestNpcKindCounts()
  local give, finish = 0, 0
  for _, byQuest in pairs(self.store.questNpcs) do
    if type(byQuest) == "table" then
      if byQuest.give ~= nil then
        give = give + 1
      end
      if byQuest["end"] ~= nil then
        finish = finish + 1
      end
    end
  end
  return give, finish
end

--------------------------------------------------------------------------------------------------
-- Quest facts (brief QF1)
--------------------------------------------------------------------------------------------------

-- collector.questFacts[questId]: what the client states about one quest when the player takes it
-- and when they hand it in, ids and numbers only, each field one letter and left out where it says
-- nothing:
--
--   l  the quest's level (C_QuestLog.GetInfo's level for the quest's log entry), at accept
--   s  the sides the quest was taken or handed in on, as bits: 1 Alliance, 2 Horde, 3 both
--      (UnitFactionGroup("player"), Collector.Side), the evidence the quest is open to that side
--   i  the item that started the quest (QUEST_DETAIL's questStartItemID), where one did
--   o  the goals, in the client's order: { { t = type, n = how many, c = creature id } }. t is
--      the objective's type word (Collector.GOAL_TYPES), n its numRequired, and c only on a kill
--      goal whose creature was proven (UI/CollectorHooks.lua: one creature of that name in the
--      installed data, or the ledger's kill that moved the count). No objective text, ever: an item
--      goal's item is the quest_requires record the turn in window writes, never repeated here.
--   m  the money reward in copper (GetRewardMoney), at the turn in window
--   x  the XP reward by the player's level at the turn in, { [player level] = xp }: XP falls as the
--      player outlevels the quest, so one value per level and never one across levels
--   d  the first day the quest was written, whole days since the epoch (Collector.Day)
--   b  the build, an index into collector.builds as a record's b is (absent for the first)
--   h  brief QH1, the items the quest handed the player, in the order first seen, at most
--      Collector.MAX_HANDOVERS: { { i = item id, n = how many, w = when (1 at the accept, 2 from an
--      NPC while the quest was being worked, 3 at the turn in, Collector.HANDOVER_WHEN), g = the
--      creature id that handed it over (w 2 only) } }. One entry per item and when; a later
--      hand-over of the same item at the same moment restates its count.
--   k  brief QH1 (owner's "A", 2026-10-22), for each item h holds from the accept or mid quest:
--      { [item id] = 1 } taken by the hand-in, 2 left with the player (a tool such as a Soul Gem),
--      3 gone before the hand-in (used during the quest or thrown away). Brief IW1 (the owner's "2B",
--      the bag check, UI/CollectorHooks.lua NoteHandinWindow and SettleHandin): listed by the turn in
--      window (QUEST_PROGRESS) is 1; else the item's count (bags and bank) at the window and just
--      after QUEST_TURNED_IN decides: none held at the window 3, held and gone after 1, still held
--      after 2. A quest whose turn in shows no window uses the counts alone (the reward window's,
--      then the one after). Absent where nothing was seen.
--
-- One record per quest, updated in place. The store has a byte budget of its own,
-- Collector.QUEST_FACTS_MAX_BYTES, on top of every other cap; the oldest first day goes first and
-- the quest just written never does. The key is created on the first write, so a saved file from
-- before brief QF1 loads with nothing added.

-- The store's byte budget (owner ruling 2026-10-14: its own 128 KB, not inside another cap).
Collector.QUEST_FACTS_MAX_BYTES = 128 * 1024

-- The objective type words the client's QuestObjectiveInfo.type answers
-- (QuestLogDocumentation.lua QuestObjectiveInfo). Anything else is not stored.
Collector.GOAL_TYPES = {
  monster = true,
  item = true,
  object = true,
  event = true,
  reputation = true,
  log = true,
  player = true,
  money = true,
  progressbar = true,
  spell = true,
  currency = true,
  areatrigger = true,
}

-- The type word of a kill goal.
Collector.GOAL_KILL = "monster"

-- The highest level a quest or a player may have, and the most a goal may ask for.
Collector.MAX_QUEST_LEVEL = 255
Collector.MAX_GOAL_COUNT = 10000
-- Side bits (Collector.Side's 1 and 2), and both.
Collector.SIDE_BOTH = 3

local MAX_FACT = 2147483647

-- A whole number from low to high, or nil. Pure.
local function wholeIn(value, low, high)
  if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or value < low or value > high then
    return nil
  end
  return value
end

--- One goal as the store keeps it, or nil: goal is { type, numRequired, creatureId } (the client's
--- QuestObjectiveInfo fields, plus the creature the hooks proved). A creature id is kept on a kill
--- goal only. Pure.
function Collector.QuestGoal(goal)
  if type(goal) ~= "table" then
    return nil
  end
  local kind = goal.type
  if type(kind) ~= "string" or not Collector.GOAL_TYPES[kind] then
    return nil
  end
  local out = { t = kind }
  out.n = wholeIn(goal.numRequired, 1, Collector.MAX_GOAL_COUNT)
  if kind == Collector.GOAL_KILL then
    out.c = wholeIn(goal.creatureId, 1, MAX_FACT)
  end
  return out
end

-- Brief QH1: when an item was handed over, as h's w keeps it, and the words a reader is given.
Collector.HANDOVER_WHEN = { accept = 1, quest = 2, turnin = 3 }
Collector.HANDOVER_WORDS = { [1] = "accept", [2] = "quest", [3] = "turnin" }
-- The most hand-overs one quest keeps (Classic quests hand over one item, a few two).
Collector.MAX_HANDOVERS = 8
-- k's words: the hand-in took the item, or the item stayed with the player; brief IW1 (the owner's "2B" of
-- 2026-10-22, the bag check): or it was gone before the hand-in (used during the quest, or thrown away).
Collector.TAKEN, Collector.LEFT, Collector.GONE = 1, 2, 3
Collector.TAKE_MARKS = { [1] = true, [2] = true, [3] = true }

--- One hand-over as h keeps it, or nil: entry is { item, count, when (a HANDOVER_WHEN word or its
--- number), giver (a creature id, kept for a mid quest hand-over only) }. Pure.
function Collector.QuestHandover(entry)
  if type(entry) ~= "table" then
    return nil
  end
  local item = wholeIn(entry.item, 1, MAX_FACT)
  local when = Collector.HANDOVER_WHEN[entry.when] or wholeIn(entry.when, 1, 3)
  if not item or not when then
    return nil
  end
  local out = { i = item, n = wholeIn(entry.count, 1, Collector.MAX_GOAL_COUNT) or 1, w = when }
  if when == Collector.HANDOVER_WHEN.quest then
    out.g = wholeIn(entry.giver, 1, MAX_FACT)
  end
  return out
end

-- h after one hand-over: a new list, the entry of the same item and when restated in place, else
-- appended while there is room. Answers the list and whether anything changed. Pure.
local function withHandover(list, entry)
  local out, changed, found = {}, false, false
  for _, held in ipairs(type(list) == "table" and list or EMPTY) do
    if type(held) == "table" and held.i == entry.i and held.w == entry.w then
      found = true
      if held.n ~= entry.n or held.g ~= entry.g then
        changed = true
      end
      out[#out + 1] = entry
    else
      out[#out + 1] = held
    end
  end
  if not found and #out < Collector.MAX_HANDOVERS then
    out[#out + 1] = entry
    changed = true
  end
  return out, changed
end

-- Brief IW1 (the owner's "2B", the bag check): k after the hand-in's marks, marks being { [item id] =
-- Collector.TAKEN, LEFT or GONE } for the items the bag check decided. Only an item h holds from the
-- accept or mid quest takes a mark; an item a mark does not name keeps the one it had. Answers the new
-- map, or nil where nothing changed. Pure.
local function withMarks(held, handovers, marks)
  local out, changed = {}, false
  for key, value in pairs(type(held) == "table" and held or EMPTY) do
    out[key] = value
  end
  for _, entry in ipairs(type(handovers) == "table" and handovers or EMPTY) do
    local item = type(entry) == "table" and entry.w ~= Collector.HANDOVER_WHEN.turnin and wholeIn(entry.i, 1, MAX_FACT)
      or nil
    local mark = item and marks[item] or nil
    if mark and Collector.TAKE_MARKS[mark] and out[item] ~= mark then
      out[item], changed = mark, true
    end
  end
  return changed and out or nil
end

--- The goals list as the store keeps it, or nil for none. A goal the store cannot keep (an odd
--- type) makes the whole list nothing: goals are kept in the client's order, so a gap would move
--- every one after it. Pure.
function Collector.QuestGoals(list)
  if type(list) ~= "table" or #list == 0 then
    return nil
  end
  local out = {}
  for index, goal in ipairs(list) do
    local kept = Collector.QuestGoal(goal)
    if not kept then
      return nil
    end
    out[index] = kept
  end
  return out
end

--- Whether two goals lists are the same goals (types and counts in order), creature ids aside. Pure.
function Collector.SameGoals(a, b)
  if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then
    return false
  end
  for index, goal in ipairs(a) do
    local other = b[index]
    if type(goal) ~= "table" or type(other) ~= "table" or goal.t ~= other.t or goal.n ~= other.n then
      return false
    end
  end
  return true
end

--- One quest's record after a write, made from the held one (or none) and what the window
--- stated. fields: { level, side (1 or 2), item, goals (Collector.QuestGoals' input), money,
--- xp, playerLevel, handover (Collector.QuestHandover's input, brief QH1), marks ({ [item id] =
--- Collector.TAKEN, LEFT or GONE }, the hand-in's bag check, brief IW1) }. day is today's whole day and
--- build the build index (nil for the first).
--- Every field states what it was told and keeps what it was not; a new goals list replaces the
--- held one and keeps each held creature id the new one does not prove, where the goals are the
--- same. Answers the record, or nil where fields states nothing at all. Pure.
function Collector.QuestFactsRecord(held, fields, day, build)
  if type(fields) ~= "table" then
    return nil
  end
  held = type(held) == "table" and held or nil
  local out = {}
  if held then
    for key, value in pairs(held) do
      out[key] = value
    end
  end
  local stated = false
  local level = wholeIn(fields.level, 1, Collector.MAX_QUEST_LEVEL)
  if level then
    out.l, stated = level, true
  end
  local side = Collector.Side(fields.side)
  if side then
    local bits = wholeIn(out.s, 1, Collector.SIDE_BOTH) or 0
    if bits % (side * 2) < side then
      bits = bits + side
    end
    out.s, stated = bits, true
  end
  local item = wholeIn(fields.item, 1, MAX_FACT)
  if item then
    out.i, stated = item, true
  end
  local goals = Collector.QuestGoals(fields.goals)
  if goals then
    if held and Collector.SameGoals(held.o, goals) then
      for index, goal in ipairs(goals) do
        local before = held.o[index]
        if goal.c == nil and type(before) == "table" then
          goal.c = wholeIn(before.c, 1, MAX_FACT)
        end
      end
    end
    out.o, stated = goals, true
  end
  local money = wholeIn(fields.money, 1, MAX_FACT)
  if money then
    out.m, stated = money, true
  end
  local xp = wholeIn(fields.xp, 1, MAX_FACT)
  local playerLevel = wholeIn(fields.playerLevel, 1, Collector.MAX_QUEST_LEVEL)
  if xp and playerLevel then
    local byLevel = {}
    for key, value in pairs(type(out.x) == "table" and out.x or EMPTY) do
      byLevel[key] = value
    end
    byLevel[playerLevel] = xp
    out.x, stated = byLevel, true
  end
  -- Brief QH1: an item the quest handed over, and the turn in window's word on each held one.
  local handover = Collector.QuestHandover(fields.handover)
  if handover then
    local list, changed = withHandover(out.h, handover)
    out.h = list
    stated = stated or changed
  end
  -- Brief IW1: the bag check's marks, item by item.
  if type(fields.marks) == "table" and type(out.h) == "table" then
    local takes = withMarks(out.k, out.h, fields.marks)
    if takes then
      out.k, stated = takes, true
    end
  end
  if not stated then
    return nil
  end
  if wholeIn(out.d, 0, MAX_FACT) == nil then
    out.d = wholeIn(day, 0, MAX_FACT)
  end
  if build ~= nil and build ~= 1 then
    out.b = build
  else
    out.b = nil
  end
  return out
end

-- The store's own line, `["questFacts"] = {\n` and the closing "},\n", around the records.
local QUEST_FACTS_BYTES = #ItemTree.Util.KeyText("questFacts") + 3 + 3 + 2

--- { records, bytes, kb } for collector.questFacts in the saved file, measured the way
--- Collector.Size measures the records, kb to one decimal place. Pure.
function Collector.QuestFactsSize(store)
  local held = type(store) == "table" and type(store.questFacts) == "table" and store.questFacts or EMPTY
  local count, bytes = 0, QUEST_FACTS_BYTES
  for questId, record in pairs(held) do
    count = count + 1
    bytes = bytes + Collector.EntryBytes(questId, record)
  end
  -- Brief RF375 fix 7: the dropped pushed lines' audit log counts inside the same budget.
  if type(store) == "table" then
    bytes = bytes + Collector.PushDropsBytes(store.pushDrops)
  end
  return { records = count, bytes = bytes, kb = math.floor(bytes / 1024 * 10 + 0.5) / 10 }
end

-- Oldest first day first, then the lower quest id; a record with no day goes first of all.
local function questFactsFirst(a, b)
  if a.d ~= b.d then
    return a.d < b.d
  end
  local aNumber, bNumber = type(a.id) == "number", type(b.id) == "number"
  if aNumber and bNumber then
    return a.id < b.id
  end
  if aNumber ~= bNumber then
    return aNumber
  end
  return tostring(a.id) < tostring(b.id)
end

--- Lets quest facts go until the store is at or under budget bytes
--- (Collector.QUEST_FACTS_MAX_BYTES by default), oldest first day first, never keep (the quest just
--- written). size is the caller's running { bytes, records }, updated in place, or nil to measure.
--- Answers how many went and the bytes left. Pure.
function Collector.EvictQuestFacts(store, budget, keep, size)
  budget = tonumber(budget) or Collector.QUEST_FACTS_MAX_BYTES
  if type(store) ~= "table" or type(store.questFacts) ~= "table" then
    return 0, 0
  end
  size = size or Collector.QuestFactsSize(store)
  if size.bytes <= budget then
    return 0, size.bytes
  end
  local held = store.questFacts
  local queue = {}
  for questId, record in pairs(held) do
    if questId ~= keep then
      local day = type(record) == "table" and wholeIn(record.d, 0, MAX_FACT) or nil
      queue[#queue + 1] = { id = questId, d = day or -1 }
    end
  end
  table.sort(queue, questFactsFirst)
  local evicted = 0
  for _, entry in ipairs(queue) do
    if size.bytes <= budget then
      break
    end
    size.bytes = size.bytes - Collector.EntryBytes(entry.id, held[entry.id])
    size.records = (size.records or 1) - 1
    held[entry.id] = nil
    evicted = evicted + 1
  end
  return evicted, size.bytes
end

--- The debug report's line: "Quest facts: <n> KB of <cap> KB, <n> quests". info is
--- C:QuestFactsStoreSize's answer. Counts only, never a quest's facts. Pure.
function Collector.QuestFactsSizeLine(info)
  info = type(info) == "table" and info or EMPTY
  return string.format(
    "Quest facts: %.1f KB of %d KB, %d quests",
    tonumber(info.kb) or 0,
    math.floor((tonumber(info.budget) or Collector.QUEST_FACTS_MAX_BYTES) / 1024),
    tonumber(info.records) or 0
  )
end

--- Brief QF1: stores what a quest window stated (Collector.QuestFactsRecord's fields), updated in
--- place, then holds the store to its budget without ever evicting this quest. Answers true when
--- something was written.
function C:RecordQuestFacts(questId, fields)
  questId = wholeIn(questId, 1, MAX_FACT)
  if not questId then
    return false
  end
  local held = type(self.store.questFacts) == "table" and self.store.questFacts[questId] or nil
  local record = Collector.QuestFactsRecord(held, fields, Collector.Day(self.now()), self:_BuildIndex())
  if not record then
    return false
  end
  if type(self.store.questFacts) ~= "table" then
    self.store.questFacts = {}
  end
  -- The running size is measured before the write, so the record replaced is counted out of it.
  self:QuestFactsSize()
  local before = held and Collector.EntryBytes(questId, held) or 0
  self.store.questFacts[questId] = record
  -- Brief IW1: the hand-over item index is built again on the next ask (handoverIndex).
  self.handoverIndex = nil
  self.qfBytes = self.qfBytes - before + Collector.EntryBytes(questId, record)
  if not held then
    self.qfRecords = self.qfRecords + 1
  end
  local size = { bytes = self.qfBytes, records = self.qfRecords }
  local evicted = Collector.EvictQuestFacts(self.store, Collector.QUEST_FACTS_MAX_BYTES, questId, size)
  self.qfBytes, self.qfRecords = size.bytes, size.records
  self.qfPruned = (self.qfPruned or 0) + evicted
  return true
end

--- Brief QF1: a kill goal's creature, proven after the goal was written (the ledger rule). Only a
--- kill goal that names no creature yet takes one. Answers true when it was written.
function C:SetQuestGoalCreature(questId, index, creatureId)
  local held = type(self.store.questFacts) == "table" and self.store.questFacts[questId] or nil
  local goal = type(held) == "table" and type(held.o) == "table" and held.o[index] or nil
  creatureId = wholeIn(creatureId, 1, MAX_FACT)
  if type(goal) ~= "table" or goal.t ~= Collector.GOAL_KILL or goal.c ~= nil or not creatureId then
    return false
  end
  local before = Collector.EntryBytes(questId, held)
  goal.c = creatureId
  if self.qfBytes then
    self.qfBytes = self.qfBytes - before + Collector.EntryBytes(questId, held)
  end
  return true
end

--- What the store holds for one quest, or nil. The store's own record: read it, never change it.
function C:QuestFacts(questId)
  local held = type(self.store.questFacts) == "table" and self.store.questFacts[questId] or nil
  return type(held) == "table" and held or nil
end

--- Brief QH1: an item the quest handed the player ({ item, count, when, giver }, Collector.QuestHandover),
--- into the quest's facts record, under the store's budget. Answers true when something was written.
function C:RecordQuestHandover(questId, entry)
  if not Collector.QuestHandover(entry) then
    return false
  end
  return self:RecordQuestFacts(questId, { handover = entry })
end

--- Brief IW1 (the owner's "2B", the bag check): the hand-in's marks for one quest ({ [item id] =
--- Collector.TAKEN, LEFT or GONE }), each on an item the quest handed over at the accept or mid quest.
--- Answers true when a mark was written (a quest with no hand-over writes nothing).
function C:MarkQuestHandins(questId, marks)
  if type(marks) ~= "table" then
    return false
  end
  local held = self:QuestFacts(wholeIn(questId, 1, MAX_FACT))
  if not held or type(held.h) ~= "table" then
    return false
  end
  return self:RecordQuestFacts(questId, { marks = marks })
end

--------------------------------------------------------------------------------
-- Brief RF375 fix 7 (the owner's "A" of 2026-10-22): the pushed lines the hand-over rule dropped inside
-- a hand-over window (UI/CollectorHooks.lua FlushHandovers: an accept, a turn in or a gossip window),
-- kept as a small rolling log for a later hand-over audit, never for anything else:
--
--   collector.pushDrops = { { i, q, w, r, d }, ... }, oldest first, at most Collector.PUSH_DROPS_MAX
--     i  the item id; q the quest id the window named (absent where none: a gossip window where no one
--        quest in the log asks for the item); w the moment, Collector.HANDOVER_WHEN's codes (1 accept,
--        2 quest, 3 turnin); r the reason, Collector.PUSH_DROP_REASON's codes; d the day (Collector.Day)
--
-- Ids, codes and a day only: no name, no text, no character. Not made here: the key appears on the first
-- write. It counts inside the quest facts budget (Collector.QuestFactsSize, QUEST_FACTS_MAX_BYTES), and
-- it feeds no verdict, page or share (Core/Share.lua never puts it, so no other player sends it); the
-- pipeline banks it as the owner's audit evidence alone (ItemTree-Data mine.py, `pushdropped` facts).
--------------------------------------------------------------------------------

Collector.PUSH_DROPS_MAX = 50
-- The reasons: 1 neither quest class nor bound and not named by the quest's facts (the screen, brief
-- RF375 M3); 2 two quests (or a reward) in the window; 3 a merchant window open; 4 a reward the turn in
-- window listed; 5 a gossip window where no one quest in the log asks for the item.
Collector.PUSH_DROP_REASON = { screen = 1, ambiguous = 2, merchant = 3, reward = 4, noquest = 5 }
Collector.PUSH_DROP_WORDS = { [1] = "screen", [2] = "ambiguous", [3] = "merchant", [4] = "reward", [5] = "noquest" }

--- One log entry as the store keeps it, { i, q, w, r, d }, from { item, quest, when (a word or a code),
--- reason (a word or a code) } and the day, or nil where the item, the moment or the reason does not
--- read. Pure.
function Collector.PushDrop(entry, day)
  if type(entry) ~= "table" then
    return nil
  end
  local item = wholeIn(entry.item, 1, MAX_FACT)
  local when = entry.when
  if type(when) == "string" then
    when = Collector.HANDOVER_WHEN[when]
  end
  when = Collector.HANDOVER_WORDS[when] and when or nil
  local reason = entry.reason
  if type(reason) == "string" then
    reason = Collector.PUSH_DROP_REASON[reason]
  end
  reason = Collector.PUSH_DROP_WORDS[reason] and reason or nil
  if not item or not when or not reason then
    return nil
  end
  return { i = item, q = wholeIn(entry.quest, 1, MAX_FACT), w = when, r = reason, d = wholeIn(day, 0, MAX_FACT) }
end

-- The store's own line, `["pushDrops"] = {\n` and the closing "},\n", around the entries.
local PUSH_DROPS_BYTES = #ItemTree.Util.KeyText("pushDrops") + 3 + 3 + 2

--- The bytes collector.pushDrops takes in the saved file (0 for none), measured as Collector.Size
--- measures a record. Pure.
function Collector.PushDropsBytes(list)
  if type(list) ~= "table" or #list == 0 then
    return 0
  end
  local bytes = PUSH_DROPS_BYTES
  for index, entry in ipairs(list) do
    bytes = bytes + Collector.EntryBytes(index, entry)
  end
  return bytes
end

--- Brief RF375 fix 7: one dropped pushed line into the rolling log ({ item, quest, when, reason }), the
--- oldest let go past Collector.PUSH_DROPS_MAX, inside the quest facts budget. Answers true when it was
--- written.
function C:RecordPushDrop(entry)
  local kept = Collector.PushDrop(entry, Collector.Day(self.now()))
  if not kept then
    return false
  end
  self:QuestFactsSize()
  local list = type(self.store.pushDrops) == "table" and self.store.pushDrops or {}
  local before = Collector.PushDropsBytes(list)
  list[#list + 1] = kept
  while #list > Collector.PUSH_DROPS_MAX do
    table.remove(list, 1)
  end
  self.store.pushDrops = list
  local size = { bytes = self.qfBytes - before + Collector.PushDropsBytes(list), records = self.qfRecords }
  local evicted = Collector.EvictQuestFacts(self.store, Collector.QUEST_FACTS_MAX_BYTES, nil, size)
  self.qfBytes, self.qfRecords = size.bytes, size.records
  self.qfPruned = (self.qfPruned or 0) + evicted
  return true
end

--- Brief RF375 fix 7: the log as a reader takes it, oldest first: { { itemId, questId, when (a word),
--- reason (a word), day } }, a new list. For the specs and the debug report; nothing else reads it.
function C:PushDrops()
  local out = {}
  for _, entry in ipairs(type(self.store.pushDrops) == "table" and self.store.pushDrops or EMPTY) do
    if type(entry) == "table" then
      out[#out + 1] = {
        itemId = entry.i,
        questId = entry.q,
        when = Collector.HANDOVER_WORDS[entry.w],
        reason = Collector.PUSH_DROP_WORDS[entry.r],
        day = entry.d,
      }
    end
  end
  return out
end

-- One h entry as a reader takes it, with the turn in window's word k states for its item.
local function handoverView(entry, takes)
  local item = type(entry) == "table" and wholeIn(entry.i, 1, MAX_FACT) or nil
  local when = item and Collector.HANDOVER_WORDS[entry.w] or nil
  if not when then
    return nil
  end
  local mark = type(takes) == "table" and takes[item] or nil
  local taken = nil
  if mark == Collector.TAKEN then
    taken = true
  elseif mark == Collector.LEFT then
    taken = false
  end
  return {
    itemId = item,
    count = wholeIn(entry.n, 1, Collector.MAX_GOAL_COUNT) or 1,
    when = when,
    giverNpcId = wholeIn(entry.g, 1, MAX_FACT),
    taken = taken,
    -- Brief IW1: gone before the hand-in (k's 3), taken then nil.
    gone = mark == Collector.GONE or nil,
  }
end

--- Brief QH1: what the player's own records say one quest handed over, a new list in the order first
--- seen: { { itemId, count, when ("accept", "quest" or "turnin"), giverNpcId, taken } }, taken true
--- where the turn in window listed the item, false where it did not, nil where none was seen.
function C:QuestHandovers(questId)
  local out = {}
  local held = self:QuestFacts(questId)
  for _, entry in ipairs(held and type(held.h) == "table" and held.h or EMPTY) do
    local view = handoverView(entry, held.k)
    if view then
      out[#out + 1] = view
    end
  end
  return out
end

-- Brief IW1: item id -> the quest ids whose hand-overs (h) name it, out of the player's own quest facts
-- store, built on the first ask and kept with the store it was built from; C:RecordQuestFacts (every
-- write, its evictions among them) and C:Clear drop it. C:ItemHandovers reads it, so Core/Keep.lua
-- asking for each scored item (brief IW1: a provided item of a quest in the log keeps) costs a lookup,
-- never a walk of the store. Only which items each quest's h names is kept: the entries themselves, and
-- k's marks, are read from the store at every ask.
local function handoverIndex(self)
  local store = type(self.store.questFacts) == "table" and self.store.questFacts or nil
  if not store then
    return nil
  end
  if self.handoverIndex and self.handoverIndexOf == store then
    return self.handoverIndex
  end
  local index = {}
  for questId, held in pairs(store) do
    if type(questId) == "number" and type(held) == "table" and type(held.h) == "table" then
      for _, entry in ipairs(held.h) do
        local item = type(entry) == "table" and wholeIn(entry.i, 1, MAX_FACT) or nil
        if item then
          local list = index[item]
          if not list then
            list = {}
            index[item] = list
          end
          if list[#list] ~= questId then
            list[#list + 1] = questId
          end
        end
      end
    end
  end
  self.handoverIndex, self.handoverIndexOf = index, store
  return index
end

--- Brief QH1: every quest the player's own records say handed over one item, a new list by quest id:
--- { { questId, count, when, giverNpcId, taken } }. Out of the player's own quest facts store (local
--- saved data, never a client call), through brief IW1's item index (handoverIndex).
function C:ItemHandovers(itemId)
  local out = {}
  itemId = wholeIn(itemId, 1, MAX_FACT)
  local store = type(self.store.questFacts) == "table" and self.store.questFacts or nil
  if not itemId or not store then
    return out
  end
  local index = handoverIndex(self)
  for _, questId in ipairs(index and index[itemId] or EMPTY) do
    local held = store[questId]
    if type(held) == "table" and type(held.h) == "table" then
      for _, entry in ipairs(held.h) do
        local view = type(entry) == "table" and entry.i == itemId and handoverView(entry, held.k) or nil
        if view then
          view.questId = questId
          out[#out + 1] = view
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.questId ~= b.questId then
      return a.questId < b.questId
    end
    return a.when < b.when
  end)
  return out
end

--- The running size of the quest facts store, measured once and kept up to date by every write.
function C:QuestFactsSize()
  if not self.qfBytes then
    local size = Collector.QuestFactsSize(self.store)
    self.qfBytes, self.qfRecords = size.bytes, size.records
  end
  return {
    records = self.qfRecords,
    bytes = self.qfBytes,
    kb = math.floor(self.qfBytes / 1024 * 10 + 0.5) / 10,
  }
end

--- What the debug report says about the quest facts store: its size, budget and evictions.
function C:QuestFactsStoreSize()
  local size = self:QuestFactsSize()
  size.budget = Collector.QUEST_FACTS_MAX_BYTES
  size.pruned = self.qfPruned or 0
  return size
end

--------------------------------------------------------------------------------------------------
-- Creature displays (brief DM2, owner QA 2026-10-17 item 192)
--------------------------------------------------------------------------------------------------

-- collector.displays[creatureId]: the display ids the client confirmed a creature page's own model
-- with (UI/InfoPanel.lua ConfirmModel, a SetCreature draw by creature id, through KeepLiveDisplay
-- and Core/CreatureLookup.lua SaveDisplay), ids and numbers only, each field one letter:
--
--   i  the display ids, 1 to Collector.MAX_DISPLAYS whole numbers above nought, in the order they
--      were first confirmed, each once; a fifth is not kept
--   d  the first day the creature was written, whole days since the epoch (Collector.Day)
--   b  the build, an index into collector.builds as a record's b is (absent for the first),
--      written on every write that adds a display id, as quest facts write theirs
--
-- QI1 kept the display id for the session only, so Owen Thadd 211022's portrait was gone again
-- after a /reload until his model drew. Kept here it survives the reload
-- (CreatureLookup.SeenDisplay falls back to it), and the owner's mine banks it, so the pipeline can
-- ship display ids for creatures no cache of ours holds. One record per creature, updated in place.
-- The store has a byte budget of its own, Collector.DISPLAYS_MAX_BYTES, on top of every other cap;
-- the oldest first day goes first and the creature just written never does. The key is created on
-- the first write, so a saved file from before brief DM2 loads with nothing added.

-- The store's byte budget: a record is about 60 bytes, so 16 KB holds about 250 creatures.
Collector.DISPLAYS_MAX_BYTES = 16 * 1024
-- The most display ids one creature keeps (a creature may wear several models).
Collector.MAX_DISPLAYS = 4

--- One creature's record after a confirmed display, made from the held one (or none): the display
--- id appended where it is new and there is room. day is today's whole day and build the build
--- index (nil for the first). Answers the record, or nil where nothing changes (an odd display id,
--- one already held, or a fifth). The held record is never changed. Pure.
function Collector.DisplaysRecord(held, display, day, build)
  display = wholeIn(display, 1, MAX_FACT)
  if not display then
    return nil
  end
  held = type(held) == "table" and held or nil
  local ids = {}
  for _, id in ipairs(held and type(held.i) == "table" and held.i or EMPTY) do
    id = wholeIn(id, 1, MAX_FACT)
    if id == display then
      return nil
    end
    if id and #ids < Collector.MAX_DISPLAYS then
      ids[#ids + 1] = id
    end
  end
  if #ids >= Collector.MAX_DISPLAYS then
    return nil
  end
  ids[#ids + 1] = display
  local out = { i = ids }
  out.d = held and wholeIn(held.d, 0, MAX_FACT) or nil
  if out.d == nil then
    out.d = wholeIn(day, 0, MAX_FACT)
  end
  if build ~= nil and build ~= 1 then
    out.b = build
  end
  return out
end

--- The first display id a held record names, or nil. Pure.
function Collector.FirstDisplay(record)
  local ids = type(record) == "table" and type(record.i) == "table" and record.i or EMPTY
  return wholeIn(ids[1], 1, MAX_FACT)
end

-- The store's own line, `["displays"] = {\n` and the closing "},\n", around the records.
local DISPLAYS_BYTES = #ItemTree.Util.KeyText("displays") + 3 + 3 + 2

--- { records, bytes, kb } for collector.displays in the saved file, measured the way
--- Collector.Size measures the records, kb to one decimal place. Pure.
function Collector.DisplaysSize(store)
  local held = type(store) == "table" and type(store.displays) == "table" and store.displays or EMPTY
  local count, bytes = 0, DISPLAYS_BYTES
  for creatureId, record in pairs(held) do
    count = count + 1
    bytes = bytes + Collector.EntryBytes(creatureId, record)
  end
  return { records = count, bytes = bytes, kb = math.floor(bytes / 1024 * 10 + 0.5) / 10 }
end

--- Lets creature displays go until the store is at or under budget bytes
--- (Collector.DISPLAYS_MAX_BYTES by default), oldest first day first, then the lower creature id,
--- never keep (the creature just written). size is the caller's running { bytes, records },
--- updated in place, or nil to measure. Answers how many went and the bytes left. Pure.
function Collector.EvictDisplays(store, budget, keep, size)
  budget = tonumber(budget) or Collector.DISPLAYS_MAX_BYTES
  if type(store) ~= "table" or type(store.displays) ~= "table" then
    return 0, 0
  end
  size = size or Collector.DisplaysSize(store)
  if size.bytes <= budget then
    return 0, size.bytes
  end
  local held = store.displays
  local queue = {}
  for creatureId, record in pairs(held) do
    if creatureId ~= keep then
      local day = type(record) == "table" and wholeIn(record.d, 0, MAX_FACT) or nil
      queue[#queue + 1] = { id = creatureId, d = day or -1 }
    end
  end
  -- The quest facts' order: the oldest first day, then the lower id.
  table.sort(queue, questFactsFirst)
  local evicted = 0
  for _, entry in ipairs(queue) do
    if size.bytes <= budget then
      break
    end
    size.bytes = size.bytes - Collector.EntryBytes(entry.id, held[entry.id])
    size.records = (size.records or 1) - 1
    held[entry.id] = nil
    evicted = evicted + 1
  end
  return evicted, size.bytes
end

--- The debug report's line: "Creature displays: <n> KB of <cap> KB, <n> creatures". info is
--- C:DisplaysStoreSize's answer. Counts only, never a creature or a display id. Pure.
function Collector.DisplaysSizeLine(info)
  info = type(info) == "table" and info or EMPTY
  return string.format(
    "Creature displays: %.1f KB of %d KB, %d creatures",
    tonumber(info.kb) or 0,
    math.floor((tonumber(info.budget) or Collector.DISPLAYS_MAX_BYTES) / 1024),
    tonumber(info.records) or 0
  )
end

--- Brief DM2: keeps a display id the client confirmed for a creature page's own model
--- (Collector.DisplaysRecord), then holds the store to its budget without ever evicting this
--- creature. Answers true when something was written.
function C:RecordDisplay(creatureId, display)
  creatureId = wholeIn(creatureId, 1, MAX_FACT)
  if not creatureId then
    return false
  end
  local held = type(self.store.displays) == "table" and self.store.displays[creatureId] or nil
  local record = Collector.DisplaysRecord(held, display, Collector.Day(self.now()), self:_BuildIndex())
  if not record then
    return false
  end
  if type(self.store.displays) ~= "table" then
    self.store.displays = {}
  end
  -- The running size is measured before the write, so the record replaced is counted out of it.
  self:DisplaysSize()
  local before = held and Collector.EntryBytes(creatureId, held) or 0
  self.store.displays[creatureId] = record
  self.dpBytes = self.dpBytes - before + Collector.EntryBytes(creatureId, record)
  if not held then
    self.dpRecords = self.dpRecords + 1
  end
  local size = { bytes = self.dpBytes, records = self.dpRecords }
  local evicted = Collector.EvictDisplays(self.store, Collector.DISPLAYS_MAX_BYTES, creatureId, size)
  self.dpBytes, self.dpRecords = size.bytes, size.records
  self.dpPruned = (self.dpPruned or 0) + evicted
  return true
end

--- What the store holds for one creature, or nil. The store's own record: read it, never change it.
function C:Displays(creatureId)
  local held = type(self.store.displays) == "table" and self.store.displays[creatureId] or nil
  return type(held) == "table" and held or nil
end

--- The first display id the store keeps for a creature, or nil. A table read.
function C:SavedDisplay(creatureId)
  return Collector.FirstDisplay(self:Displays(creatureId))
end

--- The running size of the creature displays store, measured once and kept up to date by every
--- write.
function C:DisplaysSize()
  if not self.dpBytes then
    local size = Collector.DisplaysSize(self.store)
    self.dpBytes, self.dpRecords = size.bytes, size.records
  end
  return {
    records = self.dpRecords,
    bytes = self.dpBytes,
    kb = math.floor(self.dpBytes / 1024 * 10 + 0.5) / 10,
  }
end

--- What the debug report says about the creature displays store: its size, budget and evictions.
function C:DisplaysStoreSize()
  local size = self:DisplaysSize()
  size.budget = Collector.DISPLAYS_MAX_BYTES
  size.pruned = self.dpPruned or 0
  return size
end

--------------------------------------------------------------------------------------------------
-- Trainer lists (brief TW1, owner QA 2026-10-18 item 242)
--------------------------------------------------------------------------------------------------

-- collector.trainers[creatureId] = { record, ... }: what one trainer's window listed, read row by
-- row by UI/CollectorHooks.lua (through the developer probe's own reads) and kept as
-- ids and numbers only, never a name: names change with the client's language, ids do not. One
-- record per player class and build; a later visit adds the rows it shows and keeps the rest, so a
-- record is the union of every row seen. Each field one letter:
--
--   c  the player's class id (UnitClass's third answer): a class trainer lists that class alone
--   b  the build, an index into collector.builds as a record's b is (absent for the first)
--   t  the trainer's type, C_Trainer.GetTrainerType (0 general, 2 professions, 3 pets), absent
--      where the client did not say
--   k  the skill line the window's first row names (GetTrainerServiceSkillLine), as our Skills
--      table's id, absent where it names none we know
--   d  the first day, l the last day a read wrote, whole days since the epoch (Collector.Day)
--   f  every filter that was on at a read, as bits: 1 available, 2 unavailable, 4 used. A row
--      missing under a filter is no proof the trainer lacks it
--   a  1 once one read with all three filters on read every row the window listed: a full list
--   s  { [spellId] = "level,rank,skill,skillRank,cost,type,reaction" }, seven whole numbers each, 0
--      for none: the level the row asks, the spell's own rank, the skill line and rank the row asks,
--      the price in copper as the window showed it, the row's type (1 available, 2 unavailable,
--      3 used) and the trainer's reaction to the player at that read (UnitReaction, 1 hated to 8
--      exalted: Honoured and above cut a trainer's price, which the pipeline leaves out)
--
-- Who records is UI/CollectorHooks.lua's one switch (CollectorHooks.TRAINER_LISTS): a developer
-- checkout alone, the owner's ruling of 2026-10-18. The store has a byte budget of its own,
-- Collector.TRAINERS_MAX_BYTES: the trainer last read longest ago goes first, never the one just
-- written. No share carries it (Core/Share.lua names the stores it carries), and the owner's mine
-- reads it (ItemTree-Data mine.py, `collector.trainers`).

-- The store's byte budget. A row is about 32 bytes in the saved file, so a hunter trainer's whole
-- list (120 rows on the Classic Era tables) is about 4 KB and a druid's (180) about 6 KB: this
-- holds every class and profession trainer of the three Alliance capitals, about 40 lists.
Collector.TRAINERS_MAX_BYTES = 192 * 1024
-- The most rows one record keeps, and the most records (classes and builds) one trainer keeps.
Collector.TRAINER_MAX_ROWS = 400
Collector.TRAINER_MAX_RECORDS = 12
-- A row's type, as GetTrainerServiceInfo words it (Blizzard_TrainerUI.lua:634), and the filters'
-- bits, as GetTrainerServiceTypeFilter names them (:243).
Collector.TRAINER_ROW_TYPES = { available = 1, unavailable = 2, used = 3 }
Collector.TRAINER_FILTER_BITS = { available = 1, unavailable = 2, used = 4 }
Collector.TRAINER_ALL_FILTERS = 7

local TRAINER_ROW_FIELDS = 7
local TRAINER_ROW_PATTERN = "^(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)$"
-- Each field's highest value: a level, a rank, a skill line, a skill rank, a price, a type and a
-- reaction.
local TRAINER_ROW_MAX = { 255, 255, 65535, 65535, MAX_FACT, 3, 8 }

-- Whether a bit set holds one bit (Lua 5.1 has no bit operators).
local function hasFilterBit(bits, bit)
  bits = tonumber(bits) or 0
  return math.floor(bits / bit) % 2 == 1
end

--- The filters two bit sets hold between them. Pure.
function Collector.TrainerFilters(a, b)
  local out = 0
  for _, bit in ipairs({ 1, 2, 4 }) do
    if hasFilterBit(a, bit) or hasFilterBit(b, bit) then
      out = out + bit
    end
  end
  return out
end

--- One row as the store keeps it, "level,rank,skill,skillRank,cost,type,reaction", or nil: row is
--- { level, rank, skill, skillRank, cost, type, reaction }, nil read as 0, each a whole number in
--- range, and the type 1 to 3. Pure.
function Collector.PackTrainerRow(row)
  if type(row) ~= "table" then
    return nil
  end
  local parts = {}
  for index = 1, TRAINER_ROW_FIELDS do
    local value = row[index]
    if value == nil then
      value = 0
    end
    value = wholeIn(value, 0, TRAINER_ROW_MAX[index])
    if not value then
      return nil
    end
    parts[index] = tostring(value)
  end
  if parts[6] == "0" then
    return nil
  end
  return table.concat(parts, ",")
end

--- A kept row read back, { level, rank, skill, skillRank, cost, type, reaction }, or nil for text
--- that is not one. Pure.
function Collector.UnpackTrainerRow(text)
  if type(text) ~= "string" then
    return nil
  end
  local fields = { text:match(TRAINER_ROW_PATTERN) }
  if #fields ~= TRAINER_ROW_FIELDS then
    return nil
  end
  local row = {}
  for index = 1, TRAINER_ROW_FIELDS do
    row[index] = wholeIn(tonumber(fields[index]), 0, TRAINER_ROW_MAX[index])
    if row[index] == nil then
      return nil
    end
  end
  if row[6] == 0 then
    return nil
  end
  return row
end

-- The spell ids of a map, ascending, the whole numbers alone.
local function spellIds(map)
  local out = {}
  for spellId in pairs(type(map) == "table" and map or EMPTY) do
    if wholeIn(spellId, 1, MAX_FACT) then
      out[#out + 1] = spellId
    end
  end
  table.sort(out)
  return out
end

--- One trainer's record after one read of its window, made from the held one for the same class
--- and build (or none). read is { classId, kind, skillLine, filters, full, rows = { [spellId] =
--- { level, rank, skill, skillRank, cost, type, reaction } } }: the rows it holds replace the held
--- rows of the same spell and the rest are kept (the union of every row seen), at most
--- Collector.TRAINER_MAX_ROWS by spell id; the filters join the held ones; a full read (full true:
--- every filter on and every row read) marks the record full for good. day is today's whole day
--- and build the build index (nil for the first). Answers the record, or nil where the read names
--- no class or holds no row and nothing is held. The held record is never changed. Pure.
function Collector.TrainerListRecord(held, read, day, build)
  if type(read) ~= "table" then
    return nil
  end
  local classId = wholeIn(read.classId, 1, 255)
  if not classId then
    return nil
  end
  held = type(held) == "table" and held or nil
  local rows = {}
  for _, spellId in ipairs(spellIds(read.rows)) do
    local text = Collector.PackTrainerRow(read.rows[spellId])
    if text then
      rows[spellId] = text
    end
  end
  if not held and next(rows) == nil then
    return nil
  end
  local out = { c = classId, s = {} }
  local kept = 0
  for _, spellId in ipairs(spellIds(held and held.s)) do
    if kept < Collector.TRAINER_MAX_ROWS and Collector.UnpackTrainerRow(held.s[spellId]) then
      out.s[spellId] = rows[spellId] or held.s[spellId]
      kept = kept + 1
    end
  end
  for _, spellId in ipairs(spellIds(rows)) do
    if out.s[spellId] == nil and kept < Collector.TRAINER_MAX_ROWS then
      out.s[spellId] = rows[spellId]
      kept = kept + 1
    end
  end
  if build ~= nil and build ~= 1 then
    out.b = build
  end
  out.t = wholeIn(read.kind, 0, 255) or (held and wholeIn(held.t, 0, 255)) or nil
  out.k = wholeIn(read.skillLine, 1, 65535) or (held and wholeIn(held.k, 1, 65535)) or nil
  out.d = (held and wholeIn(held.d, 0, MAX_FACT)) or wholeIn(day, 0, MAX_FACT)
  out.l = wholeIn(day, 0, MAX_FACT) or (held and wholeIn(held.l, 0, MAX_FACT)) or out.d
  local filters = Collector.TrainerFilters(held and held.f, read.filters)
  if filters > 0 then
    out.f = filters
  end
  if read.full == true or (held and held.a == 1) then
    out.a = 1
  end
  return out
end

-- The store's own line, `["trainers"] = {\n` and the closing "},\n", around the trainers.
local TRAINERS_BYTES = #ItemTree.Util.KeyText("trainers") + 3 + 3 + 2

--- { records, lists, rows, full, bytes, kb } for collector.trainers in the saved file: records is
--- the trainers held, lists their records (one per class and build), rows every list's rows and
--- full the lists a full read wrote. Measured the way Collector.Size measures the records, kb to
--- one decimal place. Pure.
function Collector.TrainersSize(store)
  local held = type(store) == "table" and type(store.trainers) == "table" and store.trainers or EMPTY
  local count, lists, rows, full, bytes = 0, 0, 0, 0, TRAINERS_BYTES
  for creatureId, list in pairs(held) do
    count = count + 1
    bytes = bytes + Collector.EntryBytes(creatureId, list)
    for _, record in ipairs(type(list) == "table" and list or EMPTY) do
      if type(record) == "table" then
        lists = lists + 1
        if record.a == 1 then
          full = full + 1
        end
        for _ in pairs(type(record.s) == "table" and record.s or EMPTY) do
          rows = rows + 1
        end
      end
    end
  end
  return {
    records = count,
    lists = lists,
    rows = rows,
    full = full,
    bytes = bytes,
    kb = math.floor(bytes / 1024 * 10 + 0.5) / 10,
  }
end

-- The last day any of one trainer's records was written, or -1.
local function trainerLastDay(list)
  local last = -1
  for _, record in ipairs(type(list) == "table" and list or EMPTY) do
    local day = type(record) == "table" and wholeIn(record.l or record.d, 0, MAX_FACT) or nil
    if day and day > last then
      last = day
    end
  end
  return last
end

--- Lets trainers go until the store is at or under budget bytes (Collector.TRAINERS_MAX_BYTES by
--- default), the one read longest ago first, then the lower creature id, never keep (the trainer
--- just written). size is the caller's running { bytes, records }, updated in place, or nil to
--- measure. Answers how many went and the bytes left. Pure.
function Collector.EvictTrainers(store, budget, keep, size)
  budget = tonumber(budget) or Collector.TRAINERS_MAX_BYTES
  if type(store) ~= "table" or type(store.trainers) ~= "table" then
    return 0, 0
  end
  size = size or Collector.TrainersSize(store)
  if size.bytes <= budget then
    return 0, size.bytes
  end
  local held = store.trainers
  local queue = {}
  for creatureId, list in pairs(held) do
    if creatureId ~= keep then
      queue[#queue + 1] = { id = creatureId, d = trainerLastDay(list) }
    end
  end
  -- The quest facts' order: the oldest day, then the lower id.
  table.sort(queue, questFactsFirst)
  local evicted = 0
  for _, entry in ipairs(queue) do
    if size.bytes <= budget then
      break
    end
    size.bytes = size.bytes - Collector.EntryBytes(entry.id, held[entry.id])
    size.records = (size.records or 1) - 1
    held[entry.id] = nil
    evicted = evicted + 1
  end
  return evicted, size.bytes
end

--- The debug report's line: "Trainer lists: <n> KB of <cap> KB, <n> trainers, <n> lists (<n> full),
--- <n> rows". info is C:TrainersStoreSize's answer. Counts only, never a trainer or a spell. Pure.
function Collector.TrainersSizeLine(info)
  info = type(info) == "table" and info or EMPTY
  return string.format(
    "Trainer lists: %.1f KB of %d KB, %d trainers, %d lists (%d full), %d rows",
    tonumber(info.kb) or 0,
    math.floor((tonumber(info.budget) or Collector.TRAINERS_MAX_BYTES) / 1024),
    tonumber(info.records) or 0,
    tonumber(info.lists) or 0,
    tonumber(info.full) or 0,
    tonumber(info.rows) or 0
  )
end

--- Brief TW1: keeps one read of a trainer's window (Collector.TrainerListRecord) in the record for
--- the read's class and this build, a new one where there is none (at most
--- Collector.TRAINER_MAX_RECORDS a trainer, the one written longest ago going first), then holds
--- the store to its budget without ever evicting this trainer. Answers true when something was
--- written.
function C:RecordTrainerList(creatureId, read)
  creatureId = wholeIn(creatureId, 1, MAX_FACT)
  if not creatureId or type(read) ~= "table" then
    return false
  end
  local build = self:_BuildIndex()
  local trainers = type(self.store.trainers) == "table" and self.store.trainers or nil
  local list = trainers and type(trainers[creatureId]) == "table" and trainers[creatureId] or nil
  local at, held = nil, nil
  for index, record in ipairs(list or EMPTY) do
    if type(record) == "table" and record.c == read.classId and (record.b or 1) == (build or 1) then
      at, held = index, record
      break
    end
  end
  local record = Collector.TrainerListRecord(held, read, Collector.Day(self.now()), build)
  if not record then
    return false
  end
  if not trainers then
    trainers = {}
    self.store.trainers = trainers
  end
  -- The running size is measured before the write, so the list replaced is counted out of it.
  self:TrainersSize()
  local before = list and Collector.EntryBytes(creatureId, list) or 0
  local copy = {}
  for index, existing in ipairs(list or EMPTY) do
    copy[index] = existing
  end
  if at then
    copy[at] = record
  else
    if #copy >= Collector.TRAINER_MAX_RECORDS then
      local oldest = 1
      for index, existing in ipairs(copy) do
        if trainerLastDay({ existing }) < trainerLastDay({ copy[oldest] }) then
          oldest = index
        end
      end
      table.remove(copy, oldest)
    end
    copy[#copy + 1] = record
  end
  trainers[creatureId] = copy
  self.tlBytes = self.tlBytes - before + Collector.EntryBytes(creatureId, copy)
  if not list then
    self.tlRecords = self.tlRecords + 1
  end
  local size = { bytes = self.tlBytes, records = self.tlRecords }
  local evicted = Collector.EvictTrainers(self.store, Collector.TRAINERS_MAX_BYTES, creatureId, size)
  self.tlBytes, self.tlRecords = size.bytes, size.records
  self.tlPruned = (self.tlPruned or 0) + evicted
  return true
end

--- What the store holds for one trainer, { record, ... }, or nil. The store's own list: read it,
--- never change it.
function C:TrainerLists(creatureId)
  local held = type(self.store.trainers) == "table" and self.store.trainers[creatureId] or nil
  return type(held) == "table" and held or nil
end

--- The running size of the trainer lists store, { records, bytes, kb }, measured once and kept up
--- to date by every write.
function C:TrainersSize()
  if not self.tlBytes then
    local size = Collector.TrainersSize(self.store)
    self.tlBytes, self.tlRecords = size.bytes, size.records
  end
  return {
    records = self.tlRecords,
    bytes = self.tlBytes,
    kb = math.floor(self.tlBytes / 1024 * 10 + 0.5) / 10,
  }
end

--- What the debug report says about the trainer lists store: its whole measure (lists, rows and
--- full lists counted afresh), budget and evictions.
function C:TrainersStoreSize()
  local size = Collector.TrainersSize(self.store)
  size.budget = Collector.TRAINERS_MAX_BYTES
  size.pruned = self.tlPruned or 0
  return size
end

--------------------------------------------------------------------------------------------------
-- Seen bosses (brief BL14)
--------------------------------------------------------------------------------------------------

-- A name as the seen boss lookup keys it: lower case, trimmed, or nil.
local function bossFold(text)
  if type(text) ~= "string" then
    return nil
  end
  local folded = text:lower():match("^%s*(.-)%s*$")
  if folded == "" then
    return nil
  end
  return folded
end

-- Whether a boss index entry has no creature id (c): a Forever encounter no client table names
-- the creature of, which is what a seen boss record is for. A chest (r 4) is never one. Pure.
function Collector.IsNamedOnly(entry)
  if type(entry) ~= "table" or tonumber(entry.r) == 4 then
    return false
  end
  return not (type(entry.c) == "table" and entry.c[1] ~= nil)
end

-- The boss index's entries with no creature id, by folded name: { [name] = entry index }, and
-- how many such entries there are. index is the BossLoot module's table (s the strings, b the
-- entries). Where two entries share a name the first is kept. Pure: a table read and nothing
-- more, never a decode.
function Collector.SeenBossNames(index)
  local names, total = {}, 0
  if type(index) ~= "table" or type(index.b) ~= "table" or type(index.s) ~= "table" then
    return names, total
  end
  for id, entry in ipairs(index.b) do
    if Collector.IsNamedOnly(entry) then
      total = total + 1
      local name = bossFold(index.s[entry.n])
      if name and names[name] == nil then
        names[name] = id
      end
    end
  end
  return names, total
end

-- The boss index entry a creature's name matches in that lookup, or nil. Pure.
function Collector.SeenBossFor(names, name)
  local folded = bossFold(name)
  if type(names) ~= "table" or not folded then
    return nil
  end
  return names[folded]
end

-- One seen boss record, or nil where it says nothing usable. fields is { npcId, name, mapId,
-- level } as the client showed the unit: the creature id out of its GUID (required), its name
-- (dropped where it is shaped like a character's), the instance's map id and its level, each
-- kept only where it is a whole number above nought (a boss's level reads -1). Pure.
function Collector.SeenBossRecord(bossIndex, fields, when)
  if not positiveWhole(bossIndex) or type(fields) ~= "table" then
    return nil
  end
  local npcId = positiveWhole(fields.npcId)
  if not npcId then
    return nil
  end
  local name = fields.name
  if type(name) ~= "string" or name == "" or looksLikeCharacter(name) then
    name = nil
  end
  return {
    npcId = npcId,
    name = name,
    mapId = positiveWhole(fields.mapId),
    level = positiveWhole(fields.level),
    when = type(when) == "number" and when or nil,
  }
end

-- Stores the creature seen for one boss index entry, updated in place: one record per entry, the
-- newest, keeping a map id or a level the older one had where the newer states none. It adds no
-- edge, so the graph's caches are left alone. Returns true when it was accepted.
function C:RecordSeenBoss(bossIndex, fields)
  local record = Collector.SeenBossRecord(bossIndex, fields, self.now())
  if not record then
    return false
  end
  bossIndex = positiveWhole(bossIndex)
  local existing = self.store.seenBosses[bossIndex]
  if type(existing) == "table" and existing.npcId == record.npcId then
    record.name = record.name or existing.name
    record.mapId = record.mapId or existing.mapId
    record.level = record.level or existing.level
  end
  -- Brief BL17: the display id the Boss loot tab's model loader confirmed (displayId, for the
  -- creature displayCreatureId) stays while the sighting names that same creature, and goes when
  -- it names another.
  if type(existing) == "table" and existing.displayId ~= nil and existing.displayCreatureId == record.npcId then
    record.displayId = existing.displayId
    record.displayCreatureId = existing.displayCreatureId
  end
  self.store.seenBosses[bossIndex] = record
  return true
end

-- The seen boss record for one boss index entry, or nil. The store's own record: read it, never
-- change it.
function C:SeenBoss(bossIndex)
  local record = type(bossIndex) == "number" and self.store.seenBosses[bossIndex] or nil
  if type(record) ~= "table" or not positiveWhole(record.npcId) then
    return nil
  end
  return record
end

-- How many boss index entries have a seen boss record, for the debug report. A count only.
function C:SeenBossCount()
  local count = 0
  for _, record in pairs(self.store.seenBosses) do
    if type(record) == "table" and positiveWhole(record.npcId) then
      count = count + 1
    end
  end
  return count
end

local function metaFor(record)
  local parts = {}
  if record.sourceName then
    parts[#parts + 1] = record.sourceName
  end
  if record.zone then
    parts[#parts + 1] = record.zone
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts, ", ")
end

-- Brief M3: the shipped Favour offer and vendor one vendor record is the player's sighting of
-- (Core/Sources.lua Favour.ShippedOffer), or nil. Read through the namespace at call time, since
-- Core/Sources.lua may load after this file, and pcall'd: a shipped table that cannot be read
-- costs the fill and nothing else.
local function shippedOffer(record)
  local sources = ItemTree.Sources
  local favour = type(sources) == "table" and sources.Favour or nil
  if type(favour) ~= "table" or type(favour.ShippedOffer) ~= "function" then
    return nil
  end
  local ok, offer, vendor = pcall(favour.ShippedOffer, record.itemId, record)
  if not ok or type(offer) ~= "table" or type(vendor) ~= "table" then
    return nil
  end
  return offer, vendor
end

local function shippedCost(offer)
  local favour = ItemTree.Sources.Favour
  return Collector.Cost(favour.OfferCost(offer))
end

function C:_Percent(record, reverse)
  if record.kind ~= "disenchant" or not reverse then
    return nil
  end
  local total = self.disenchantTotals[record.sourceId] or 0
  if total <= 0 then
    return nil
  end
  return (record.count or 1) / total * 100
end

-- Brief PS1 (owner ruling 2026-10-02): a record whose fact the installed data already ships as a
-- player sourced row (Core/PlayerSources.lua) is drawn as that plain row: the "mined" tier, which
-- wears no verified check, with the provenance "player" ("Reported by players"), keeping every
-- detail the record holds. Core/PlayerSources.lua draws nothing for such a fact, so it is one row.
-- Every other record stays "verified". Answers the tier and the provenance (nil for none).
local function shippedTier(record, kind)
  if Collector.ShipsAsPlayer(kind or record.kind, record.itemId, record.sourceKind, record.sourceId) then
    return Confidence.MINED, Collector.PLAYER_PROVENANCE
  end
  return Confidence.VERIFIED, nil
end

-- Brief SK1 (owner ruling 2026-10-15, "I wouldn't want them in the drops table"): the kind a record
-- is drawn as. Before SK1 the recorder filed every loot window of a creature as a drop, skinning and
-- pickpocketing included, and those records are still in players' saved variables. A drop record
-- of a creature whose item and creature the installed data ships as skinned or pickpocketed and not
-- as a drop (ItemTree-Data's cleanup, which moves a drop row the Classic Era table lists only under
-- Skinned from or Pickpocketed from: Core/PlayerSources.lua PlayerSources.Refiled) is that same
-- loot, so it is drawn as that kind. The record itself is never changed. Every other record is
-- drawn as its own kind. Reads a module already built only (Refiled never loads one). Pure apart
-- from that read.
function Collector.ShownKind(record)
  if type(record) ~= "table" then
    return nil
  end
  if record.kind ~= "drop" or record.sourceKind ~= "npc" or type(record.sourceId) ~= "number" then
    return record.kind
  end
  local reader = ItemTree.PlayerSources
  if type(reader) ~= "table" or type(reader.Refiled) ~= "function" then
    return record.kind
  end
  local ok, kind = pcall(reader.Refiled, record.itemId, record.sourceId)
  if ok and (kind == "skin" or kind == "pickpocket") then
    return kind
  end
  return record.kind
end

-- Edges for Graph.RegisterProvider. Everything the collector saw is "verified": it came
-- off this client on this build, apart from a fact the data ships as a player row (above).
--
-- The number on the edge is `seen`, a tally of everything this client has watched, and never
-- `quantity`: a quantity is how many come at once ("x10" off one kill), and adding sightings up
-- would make ninety kills read as ninety of the item a kill. Core/Sources.lua and
-- Core/ViewModel.lua still read a tally out of `quantity` on a verified edge, because a store
-- written before the tally had a name of its own is still in someone's saved variables.
--
-- The one exception is a quest requirement, whose spec is marked `stated`. A quest asking for
-- ten pelts is not a sighting: the count came off the client as a fact about the quest, and a
-- tally of how often the player has looked at a pelt in its place would be a lie with a number
-- on it. Those edges carry the stated count in `quantity`, the way the curated quests do, and
-- no tally at all.
function C:EdgesFor(key, direction)
  local out = {}
  local kind, id = Graph.Parse(key)
  if kind == "npc" then
    return self:_NpcEdges(key, direction)
  end
  if kind ~= "item" and kind ~= "quest" then
    return out
  end
  self:_Index()

  local function emit(record, spec, target, reverse, shownKind)
    if not spec or not spec.edge or spec.edge.dir ~= direction or not target then
      return
    end
    local seen, quantity = record.count, nil
    if spec.stated then
      seen, quantity = nil, record.need
    end
    -- What the vendor asked when the player last opened its window (brief M2): the money part
    -- as the edge's price, the way a provider states one, and the currency and item parts as
    -- the edge's cost. Only a forward vendor edge has either.
    local price, costParts = nil, nil
    local cost = not reverse and Collector.Cost(record.cost) or nil
    local zone = record.zone
    -- Brief M3: a record of a vendor the curated tier ships beats the shipped row field by field,
    -- and where the record lacks a field (a record made before prices were read) the shipped row
    -- fills it.
    if not reverse and record.kind == "vendor" and (not cost or not zone) then
      local offer, vendor = shippedOffer(record)
      if offer then
        cost = cost or shippedCost(offer)
        zone = zone or vendor.zone
      end
    end
    if cost then
      price = cost.copper
      if cost.currency or cost.items then
        costParts = { currency = cost.currency, items = cost.items }
      end
    end
    local confidence, provenance = shippedTier(record, shownKind)
    out[#out + 1] = {
      type = spec.edge,
      target = target,
      seen = seen,
      quantity = quantity,
      percent = self:_Percent(record, reverse),
      confidence = confidence,
      provenance = provenance,
      -- Brief SK1: a pickpocket row, which Core/Graph.lua keeps apart from a drop of the creature.
      pocket = spec.pocket,
      meta = metaFor(record),
      -- The same zone the meta line ends with, on the edge in its own right: Core/Sources.lua
      -- draws the zone column from it rather than matching the name off the front of the line.
      zone = zone,
      price = price,
      cost = costParts,
      group = spec.group,
    }
  end

  -- A quest the collector learned about, answering for itself: the items it asks for, with the
  -- count the client stated. The curated table answers the same way for the 28 quests it names
  -- (Core/Quests.lua), and Core/Graph.lua merges the two, keeping the more trusted claim.
  if kind == "quest" then
    for _, record in ipairs(self.bySourceQuest[id] or EMPTY) do
      local spec = SPECS[record.kind]
      if spec then
        emit(record, spec.reverse, Graph.Key("item", record.itemId), true)
      end
    end
    return out
  end

  for _, record in ipairs(self.byItem[id] or EMPTY) do
    -- Brief SK1: an older drop record the installed data refiles as skinned or pickpocketed.
    local shownKind = Collector.ShownKind(record)
    local spec = SPECS[shownKind]
    if spec and record.sourceId and SOURCE_KINDS[record.sourceKind] then
      local target = Graph.Key(record.sourceKind, record.sourceId)
      if record.sourceName then
        Graph.SetName(target, record.sourceName)
      end
      local forward = spec.forward
      if
        record.kind == "gather"
        and record.sourceKind == "object"
        and Collector.IsContainerName(record.sourceName or Graph.Name(target))
      then
        forward = FOUND_IN
      end
      emit(record, forward, target, false, shownKind)
    end
  end
  for _, record in ipairs(self.bySourceItem[id] or EMPTY) do
    local spec = SPECS[record.kind]
    if spec then
      emit(record, spec.reverse, Graph.Key("item", record.itemId), true)
    end
  end
  return out
end

-- Brief N2: an NPC's own edges, walking down: CREATURE_DROPS for every item it dropped and SELLS
-- for every item it sold, each with the record's tally in seen, its zone, and for a sale the price
-- and cost the merchant window last stated (brief M2), in the same fields a Sold by edge carries
-- them. One edge per item and type: two records of one name (two spawns) are added together.
function C:_NpcEdges(key, direction)
  local out = {}
  if direction ~= Edges.DOWN then
    return out
  end
  local byTarget = {}
  for _, record in ipairs(self:NpcRecords(key)) do
    -- Brief SK1: an older drop record the installed data refiles as skinned or pickpocketed.
    local shownKind = Collector.ShownKind(record)
    local spec = NPC_SPECS[shownKind]
    if spec and type(record.itemId) == "number" then
      local target = Graph.Key("item", record.itemId)
      local slot = spec.edge.name .. "\0" .. target
      local edge = byTarget[slot]
      if edge then
        edge.seen = (edge.seen or 0) + (record.count or 0)
        if record.zone and not edge.zone then
          edge.zone = record.zone
        end
      else
        local confidence, provenance = shippedTier(record, shownKind)
        edge = {
          type = spec.edge,
          target = target,
          seen = record.count,
          confidence = confidence,
          provenance = provenance,
          zone = record.zone,
          group = spec.group,
        }
        local cost = record.kind == "vendor" and Collector.Cost(record.cost) or nil
        -- Brief M3: the shipped row fills a price the record lacks, as on the item's own row.
        if not cost and record.kind == "vendor" then
          local offer = shippedOffer(record)
          cost = offer and shippedCost(offer) or nil
        end
        if cost then
          edge.price = cost.copper
          if cost.currency or cost.items then
            edge.cost = { currency = cost.currency, items = cost.items }
          end
        end
        byTarget[slot] = edge
        out[#out + 1] = edge
      end
    end
  end
  return out
end

-- Brief PS1: whether the player's own records state one fact (kind, item, source kind and id),
-- in either key shape. Core/PlayerSources.lua asks it so a fact both state is drawn once. False,
-- never nil.
function C:HasFact(kind, itemId, sourceKind, sourceId)
  local records = self:Records()
  local key = Collector.Key(kind, itemId, sourceKind, sourceId)
  if key and records[key] ~= nil then
    return true
  end
  local old = key and oldKey(kind, itemId, sourceKind, sourceId) or nil
  return old ~= nil and records[old] ~= nil
end

-- What the store holds and whether it reaches the graph, for the debug command. total is
-- records, byKind is records per kind (and is what is written back to saved variables), items
-- is how many distinct items have a record, and installed says whether this collector's
-- provider is registered right now: a store full of records that is not installed draws exactly
-- the same empty tree as an empty one, so the two faults have to be told apart.
function C:Counts()
  local byKind, total = {}, 0
  for kind in pairs(Collector.KINDS) do
    byKind[kind] = 0
  end
  local items, seen = 0, {}
  for _, record in pairs(self:Records()) do
    byKind[record.kind] = (byKind[record.kind] or 0) + 1
    total = total + 1
    if record.itemId and not seen[record.itemId] then
      seen[record.itemId] = true
      items = items + 1
    end
  end
  -- Discoveries live in a store of their own and are counted on their own: they are not
  -- sightings, so they are not in total, and the kind line still says how many there are.
  local discoveries = 0
  for itemId, held in pairs(self.store.discoveries) do
    if type(held) == "table" or type(held) == "string" then
      discoveries = discoveries + 1
      if not seen[itemId] then
        seen[itemId] = true
        items = items + 1
      end
    end
  end
  byKind.discovery = discoveries
  self.store.counts = byKind
  -- Brief Q9: the quest NPC split rides on a copy of byKind, so the debug report's "by kind" line
  -- shows it ("questgive 1, questend 1") while the saved counts stay record kinds only.
  local questGive, questEnd = self:QuestNpcKindCounts()
  local shown = {}
  for kind, count in pairs(byKind) do
    shown[kind] = count
  end
  shown.questgive, shown.questend = questGive, questEnd
  -- Brief R12: node sightings in the places store ride on the same copy, so the debug report's
  -- "by kind" line says (brief R14) "nodes 5 gathered, 12 hovered"; the saved counts stay record
  -- kinds only.
  local places = self.places or (ItemTree.db and ItemTree.db.places) or nil
  local nodeNames, nodeSightings, nodeGathered, nodeHovered, nodeOlder = Collector.NodeSightings(places)
  shown.nodes = Collector.NodeCountText(nodeGathered, nodeHovered, nodeOlder)
  return {
    total = total,
    byKind = shown,
    items = items,
    discoveries = discoveries,
    -- Brief Q8: quests with a giver or a turn in recorded, a count and nothing else.
    questNpcs = self:QuestNpcCount(),
    -- Brief Q9: and the same split by kind.
    questNpcGive = questGive,
    questNpcEnd = questEnd,
    -- Brief BL14: boss index entries with a seen boss record, a count and nothing else.
    seenBosses = self:SeenBossCount(),
    -- Brief R12: gathering nodes seen on hover, names and sightings, counts and nothing else.
    nodeNames = nodeNames,
    nodeSightings = nodeSightings,
    -- Brief R14: the sightings split, gathered, hovered and older (an R12 or R13 file's cells).
    nodeGathered = nodeGathered,
    nodeHovered = nodeHovered,
    nodeOlder = nodeOlder,
    -- Brief C20: sightings refused for a source id that is not an id, and stored rows the load's
    -- migration dropped for one, both running totals kept in the store.
    refused = tonumber(self.store.refused) or 0,
    dropped = tonumber(self.store.dropped) or 0,
    installed = self:Installed(),
  }
end

--------------------------------------------------------------------------------
-- Brief R12: gathering node names, for a node seen on hover. Widened by brief R13 to every
-- named world object the Era table knows (owner ask 2026-10-04).
--------------------------------------------------------------------------------

-- The record kinds whose object source is one the player gathered, fished or opened, and the
-- category word each answers for a name the Era table does not file.
Collector.OBJECT_RECORD_KINDS = { gather = "gather", fish = "fish", container = "container" }

-- The known world object names, lower cased, each to its category: every name the Era table's ok
-- files under any category (source.s holds the names, source.ok the category number per name
-- index: 8 herb, 9 vein, 10 fishing pool, 11 a chest, a quest object, a book or another looted
-- object, and any number a later table adds), then every object name the player's own gather,
-- fish and container records carry (sourceName, brief R9), answering the record kind ("gather",
-- "fish" or "container") where Era files no number for it. Either may be nil. A closed list, so
-- no NPC, player or free text is in it. Pure.
function Collector.NodeNames(source, records, into)
  local names = into or {}
  local strings = type(source) == "table" and source.s or nil
  local kinds = type(source) == "table" and source.ok or nil
  if type(strings) == "table" and type(kinds) == "table" then
    for nameIndex, number in pairs(kinds) do
      local name = type(number) == "number" and strings[nameIndex] or nil
      if type(name) == "string" and name ~= "" then
        names[name:lower()] = number
      end
    end
  end
  for _, record in pairs(type(records) == "table" and records or EMPTY) do
    local word = type(record) == "table" and Collector.OBJECT_RECORD_KINDS[record.kind] or nil
    if word and record.sourceKind == "object" and type(record.sourceName) == "string" and record.sourceName ~= "" then
      local key = record.sourceName:lower()
      if names[key] == nil then
        names[key] = word
      end
    end
  end
  return names
end

-- The kind codes of the object record kinds, as the first letter of a store key (Collector.Key).
local OBJECT_KEY_CODES = {}
for kind in pairs(Collector.OBJECT_RECORD_KINDS) do
  OBJECT_KEY_CODES[KIND_CODES[kind]:byte(1)] = true
end
local COLON = (":"):byte(1)

-- The object names the player's own records carry, the second half of Collector.NodeNames, read
-- straight off the store's rows (collector.records) with no view made: { [lower name] = "gather",
-- "fish" or "container" } for every gather, fish and container row whose source is an object and
-- names it. Where rows of two kinds name one object, the row with the lower store key answers, so
-- the set is the same whatever order the store is walked in. Pure.
function Collector.GatheredNodeNames(records)
  local names, from = {}, {}
  for key, row in pairs(type(records) == "table" and records or EMPTY) do
    local kind, sourceKind, name = nil, nil, nil
    if Collector.IsOldShape(row) then
      kind, sourceKind, name = row.kind, row.sourceKind, row.sourceName
    elseif
      type(row) == "table"
      and type(row.n) == "string"
      and type(key) == "string"
      and OBJECT_KEY_CODES[key:byte(1)]
      and key:byte(2) == COLON
    then
      local _
      kind, _, sourceKind = Collector.ParseKey(key)
      name = row.n
    end
    local word = kind and Collector.OBJECT_RECORD_KINDS[kind] or nil
    if word and sourceKind == "object" and type(name) == "string" and name ~= "" then
      local lower = name:lower()
      local held = from[lower]
      if held == nil or tostring(key) < held then
        names[lower] = word
        from[lower] = tostring(key)
      end
    end
  end
  return names
end

-- The shipped Era table: opts.era where a caller stated one (a reader with Table, or the table
-- itself), otherwise ItemTree.eraSources. nil where this build ships none.
function C:_EraTable()
  local era = self.era
  if era == nil then
    era = ItemTree.eraSources
  end
  if type(era) ~= "table" then
    return nil
  end
  if type(era.Table) ~= "function" then
    return era
  end
  local ok, source = pcall(era.Table, era)
  if ok and type(source) == "table" then
    return source
  end
  return nil
end

-- The category of name (the first line of a tooltip) where it is a known world object, or nil:
-- the Era category number (8 herb, 9 vein, 10 fishing pool, 11 a chest or another object) first,
-- else the record kind word ("gather", "fish", "container") for a name only the player's own
-- records carry. The Era names are built once a session from the loaded Era module (built again
-- only while there was none to read), the player's names straight from the store's rows
-- (Collector.GatheredNodeNames) again only after a gather, fish or container row's name is written
-- or such a row goes. One table lookup a call.
function C:NodeCategory(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  local key = name:lower()
  if not self.eraNodeNames then
    local source = self:_EraTable()
    if source then
      self.eraNodeNames = Collector.NodeNames(source, nil)
    end
  end
  if self.eraNodeNames and self.eraNodeNames[key] ~= nil then
    return self.eraNodeNames[key]
  end
  if not self.gatheredNodeNames then
    self.gatheredNodeNames = Collector.GatheredNodeNames(self.store.records)
  end
  return self.gatheredNodeNames[key]
end

-- Whether name is a known world object (C:NodeCategory answers one).
function C:IsNodeName(name)
  return self:NodeCategory(name) ~= nil
end

-- The sum of the counts in maps ({ [uiMap] = { [cell] = count } }), or 0.
local function nodeCellTotal(maps)
  local total = 0
  for mapId, cells in pairs(type(maps) == "table" and maps or EMPTY) do
    if type(mapId) == "number" and type(cells) == "table" then
      for _, count in pairs(cells) do
        total = total + (tonumber(count) or 0)
      end
    end
  end
  return total
end

-- The places store's node kind (brief R12): how many node names it holds and how many sightings
-- they add up to, then (brief R14) those sightings split: gathered (the entry's g layer), hovered
-- (its h layer) and older (the plain maps an R12 or R13 file wrote, kind unknown). places is
-- ItemTreeDB.places, or nil. Pure.
function Collector.NodeSightings(places)
  local nodes = type(places) == "table" and places.n or nil
  local names, gathered, hovered, older = 0, 0, 0, 0
  for _, entry in pairs(type(nodes) == "table" and nodes or EMPTY) do
    if type(entry) == "table" then
      names = names + 1
      older = older + nodeCellTotal(entry)
      gathered = gathered + nodeCellTotal(entry.g)
      hovered = hovered + nodeCellTotal(entry.h)
    end
  end
  return names, gathered + hovered + older, gathered, hovered, older
end

-- Brief R14: the node part of the debug report's "by kind" line, "5 gathered, 12 hovered", with
-- ", 3 older" where an R12 or R13 file's cells are left. Diagnostic, so not translated. Pure.
function Collector.NodeCountText(gathered, hovered, older)
  local text = string.format("%d gathered, %d hovered", tonumber(gathered) or 0, tonumber(hovered) or 0)
  if (tonumber(older) or 0) > 0 then
    text = string.format("%s, %d older", text, older)
  end
  return text
end

-- The vendor records that carry a price, for the debug command: how many vendor records there
-- are, how many of them are priced, and one line per priced record, "item 262765 from npc
-- 256730: copper 50000, currency 3402 x200", sorted so it reads the same every time. Ids and
-- amounts only: never a vendor's name, a zone or anything about the player.
function C:VendorCosts()
  local total, lines = 0, {}
  for _, record in pairs(self:Records()) do
    if record.kind == "vendor" then
      total = total + 1
      local line = Collector.CostLine(record.cost)
      if line then
        lines[#lines + 1] = string.format(
          "item %s from %s %s: %s",
          tostring(record.itemId),
          tostring(record.sourceKind),
          tostring(record.sourceId or "?"),
          line
        )
      end
    end
  end
  table.sort(lines)
  return { vendor = total, priced = #lines, lines = lines }
end

--------------------------------------------------------------------------------
-- Size and the byte budget (brief R1)
--------------------------------------------------------------------------------

-- The most collector.records may take in the saved file, measured by Collector.Size. Past it,
-- C:Prune evicts the least recently seen records until the store is back under. Discoveries,
-- quest NPCs, seen bosses and the counts table are not part of this store and are never pruned
-- by it.
Collector.MAX_BYTES = 512 * 1024

-- Whole days since the epoch for a time in seconds, the way Core/Ledger.lua counts days.
function Collector.Day(seconds)
  return math.floor((tonumber(seconds) or 0) / DAY)
end

local sizeKey = ItemTree.Util.KeyText
local sizeValue = ItemTree.Util.ValueText

-- The bytes a value takes the way the Forever client writes saved variables, which is with no
-- indentation at all (measured on the owner's file, recording-audit.md section 0): a table is
-- "{\n", then one `["key"] = value,\n` line a field, then "}". The same shape as Ledger.Bytes
-- with the tabs taken out.
function Collector.Bytes(value)
  if type(value) ~= "table" then
    return #sizeValue(value)
  end
  local total = 3 -- "{\n" and "}"
  for key, inner in pairs(value) do
    total = total + #sizeKey(key) + 3 + Collector.Bytes(inner) + 2
  end
  return total
end

-- One record as it sits in the file: its key, " = ", its table and the ",\n" after it.
function Collector.EntryBytes(key, record)
  return #sizeKey(key) + 3 + Collector.Bytes(record) + 2
end

-- The store's own line, `["records"] = {\n` and the closing "},\n", around the records.
local RECORDS_BYTES = #sizeKey("records") + 3 + 3 + 2

-- { records, bytes, kb } for collector.records in the saved file: kb to one decimal place. store is
-- the collector's saved table (ItemTree.db.collector). Visits every record, so the collector keeps
-- a running total (C:Size) and calls this only to start one.
function Collector.Size(store)
  local records = type(store) == "table" and type(store.records) == "table" and store.records or EMPTY
  local count, bytes = 0, RECORDS_BYTES
  for key, record in pairs(records) do
    count = count + 1
    bytes = bytes + Collector.EntryBytes(key, record)
  end
  return { records = count, bytes = bytes, kb = math.floor(bytes / 1024 * 10 + 0.5) / 10 }
end

-- The debug report's line for the store: its size, the budget and how many records pruning has
-- evicted since login. info is C:StoreSize's answer.
function Collector.SizeLine(info)
  info = type(info) == "table" and info or EMPTY
  return string.format(
    "Collector store: %.1f KB of %d KB budget, %d records pruned since login",
    tonumber(info.kb) or 0,
    math.floor((tonumber(info.budget) or Collector.MAX_BYTES) / 1024),
    tonumber(info.pruned) or 0
  )
end

-- The running size of this collector's records, worked out from scratch the first time it is
-- asked and kept up to date by Record, Prune and Clear after that.
function C:Size()
  if not self.sizeBytes then
    local size = Collector.Size(self.store)
    self.sizeBytes, self.sizeRecords = size.bytes, size.records
  end
  return {
    records = self.sizeRecords,
    bytes = self.sizeBytes,
    kb = math.floor(self.sizeBytes / 1024 * 10 + 0.5) / 10,
  }
end

-- What the debug report says about the store: C:Size plus the budget and the records evicted since
-- login (this collector was made at login).
function C:StoreSize()
  local size = self:Size()
  size.budget = Collector.MAX_BYTES
  size.pruned = self.pruned or 0
  return size
end

-- Folds one record's change into the running size. before is the bytes the record took before the
-- write (0 for a new one).
function C:_Resize(key, before, added)
  if not self.sizeBytes then
    return
  end
  self.sizeBytes = self.sizeBytes - before + Collector.EntryBytes(key, self.store.records[key])
  if added then
    self.sizeRecords = self.sizeRecords + 1
  end
end

-- Which rows go first among records last seen on the same day: a vendor row, whose price the
-- ledger holds as well (Core/Ledger.lua), before any other.
local EVICT_RANK = { vendor = 0 }

-- What a row says about when it was last seen: the day, a time to order rows of one day by (the
-- second for an old shaped row, the start of the day for a new one) and a stamp that changes
-- whenever the row is seen again, which is how a kept queue tells a row seen since. Pure.
local function lastSeen(row)
  if Collector.IsOldShape(row) then
    local last = tonumber(row.last) or 0
    return Collector.Day(last), last, tostring(last)
  end
  local day = tonumber(row.l) or 0
  return day, day * DAY, day .. "/" .. tostring(row.s or 1)
end

-- The kind, item and source a row is about, out of the row (old shape) or its key.
local function factOf(key, row)
  if Collector.IsOldShape(row) then
    return row.kind, row.itemId, row.sourceKind, row.sourceId
  end
  return Collector.ParseKey(key)
end

local function evictsBefore(a, b)
  -- Brief R15: a record whose fact the installed data already ships with player provenance goes
  -- before any the data does not, however recently it was seen.
  if a.shipped ~= b.shipped then
    return a.shipped
  end
  if a.day ~= b.day then
    return a.day < b.day
  end
  if a.rank ~= b.rank then
    return a.rank < b.rank
  end
  if a.last ~= b.last then
    return a.last < b.last
  end
  return a.key < b.key
end

-- The records that may go today, in the order they go: a record the data already ships with
-- player provenance first (Collector.ShipsAsPlayer), then least recently seen (by day, then a
-- vendor row before any other, then by the time), never one seen today.
function C:_EvictionQueue(today)
  local queue = {}
  for key, record in pairs(self.store.records) do
    self.pruneVisited = self.pruneVisited + 1
    if type(record) == "table" then
      local day, last, stamp = lastSeen(record)
      if day < today then
        local kind, itemId, sourceKind, sourceId = factOf(key, record)
        queue[#queue + 1] = {
          key = key,
          last = last,
          stamp = stamp,
          day = day,
          rank = EVICT_RANK[kind or ""] or 1,
          shipped = Collector.ShipsAsPlayer(kind, itemId, sourceKind, sourceId),
        }
      end
    end
  end
  table.sort(queue, evictsBefore)
  return queue
end

-- Evicts records until the store is at or under budget bytes (Collector.MAX_BYTES by default) and
-- answers how many went. Called after every record write and once at login (Core/Init.lua).
--
-- Least recently seen first, a vendor row before any other at equal age, never keep (the key of
-- the record just written) and never a record seen today, so a store that is over budget with
-- nothing older than today stays over until the day turns. Stops as soon as the store is under.
-- Discoveries, quest NPCs, seen bosses and the counts table are left alone.
--
-- Cost: under budget, nothing is visited (the size is a running total). Over budget, the first
-- call of a day visits every record once and sorts the ones that may go (n log n, a few hundred
-- records at the budget); that sorted queue is kept, and every later call the same day takes the
-- next records off it, one visit each, skipping any seen again since. A day's queue that has run
-- out is not rebuilt until the day turns, since nothing new can become old enough before then.
-- self.pruneVisited is the records the last call visited.
function C:Prune(budget, keep)
  budget = tonumber(budget) or Collector.MAX_BYTES
  self.pruneVisited = 0
  if self:Size().bytes <= budget then
    return 0
  end
  local today = Collector.Day(self.now())
  if not self.pruneQueue or self.pruneDay ~= today then
    self.pruneQueue = self:_EvictionQueue(today)
    self.pruneCursor = 1
    self.pruneDay = today
  end
  local records = self.store.records
  local evicted = 0
  local nodes, requires = false, false
  while self.sizeBytes > budget do
    local entry = self.pruneQueue[self.pruneCursor]
    if not entry then
      break
    end
    self.pruneCursor = self.pruneCursor + 1
    self.pruneVisited = self.pruneVisited + 1
    local record = records[entry.key]
    -- A record seen again since the queue was made has a newer last and is skipped.
    if type(record) == "table" and entry.key ~= keep and select(3, lastSeen(record)) == entry.stamp then
      local kind, _, sourceKind = factOf(entry.key, record)
      if kind == "quest_requires" then
        requires = true
      elseif Collector.OBJECT_RECORD_KINDS[kind or ""] and sourceKind == "object" then
        nodes = true
      end
      self.sizeBytes = self.sizeBytes - Collector.EntryBytes(entry.key, record)
      self.sizeRecords = self.sizeRecords - 1
      records[entry.key] = nil
      evicted = evicted + 1
      if self.views then
        self.pending = self.pending or {}
        self.pending[entry.key] = true
      end
    end
  end
  if evicted > 0 then
    self.pruned = (self.pruned or 0) + evicted
    self:_Touch()
    if nodes then
      self.gatheredNodeNames = nil
    end
    if requires then
      Collector.requiresGeneration = Collector.requiresGeneration + 1
    end
  end
  return evicted
end

--------------------------------------------------------------------------------
-- The discovery store's size, its cap and its migration (brief R3)
--------------------------------------------------------------------------------

-- The most collector.discoveries may take in the saved file, measured by
-- Collector.DiscoveriesSize the way Collector.Size measures the records. Past it,
-- Collector.EvictDiscoveries lets the oldest go in the order below.
Collector.DISCOVERIES_MAX_BYTES = 96 * 1024

-- The store's own line, `["discoveries"] = {\n` and the closing "},\n", around the records.
local DISCOVERIES_BYTES = #sizeKey("discoveries") + 3 + 3 + 2

--- { records, bytes, kb } for collector.discoveries in the saved file, kb to one decimal place.
--- store is the collector's saved table. Visits every record; the collector keeps a running
--- total (C:DiscoveriesSize) and calls this only to start one. Pure.
function Collector.DiscoveriesSize(store)
  local held = type(store) == "table" and type(store.discoveries) == "table" and store.discoveries or EMPTY
  local count, bytes = 0, DISCOVERIES_BYTES
  for itemId, value in pairs(held) do
    count = count + 1
    bytes = bytes + Collector.EntryBytes(itemId, value)
  end
  return { records = count, bytes = bytes, kb = math.floor(bytes / 1024 * 10 + 0.5) / 10 }
end

-- Which step of the eviction order a record is in, and its moment in minutes since the epoch (the
-- day and its minute, 0 for a moment not known):
--   1  a realm find the installed data build already names (its name is left out, or the data
--      names it: Collector.DataNames), which the player loses least by
--   2  any other realm find, this realm's or another's
--   3  the player's own find
local function evictionOf(itemId, value)
  local h, day, minute, name
  if type(value) == "table" then
    h, name = value.h, value.n
    if type(value.t) == "number" then
      day, minute = Collector.DayMinute(value.t)
    end
  else
    local _
    h, day, minute, _, _, _, _, name = Collector.DiscoveryFields(value)
  end
  local at = (day or 0) * MINUTES_A_DAY + (minute or 0)
  if h == Collector.SOURCE_SELF then
    return 3, at
  end
  if type(value) == "string" and name == nil then
    return 1, at
  end
  if type(itemId) == "number" and Collector.DataNames(itemId, name) then
    return 1, at
  end
  return 2, at
end

-- Step first, then the oldest moment (day, then minute), then the lower item id, so two records
-- of one moment always go in the same order; a key that is not a number goes after every id that
-- is, in text order.
local function evictsFirst(a, b)
  if a.step ~= b.step then
    return a.step < b.step
  end
  if a.at ~= b.at then
    return a.at < b.at
  end
  local aNumber, bNumber = type(a.id) == "number", type(b.id) == "number"
  if aNumber and bNumber then
    return a.id < b.id
  end
  if aNumber ~= bNumber then
    return aNumber
  end
  return tostring(a.id) < tostring(b.id)
end

--- Lets discovery records go until the store is at or under budget bytes
--- (Collector.DISCOVERIES_MAX_BYTES by default), never keep (the id just written), and answers
--- how many went and the bytes left. The order: realm finds the installed data build names,
--- then other realm finds, then the player's own, oldest first within each (by day, then the
--- minute of the day, then the lower item id).
--- size is the store's size where the caller keeps a running one, { bytes, records }, and is
--- updated in place. Sorts once per call and only when over budget.
function Collector.EvictDiscoveries(store, budget, keep, size)
  budget = tonumber(budget) or Collector.DISCOVERIES_MAX_BYTES
  if type(store) ~= "table" or type(store.discoveries) ~= "table" then
    return 0, 0
  end
  size = size or Collector.DiscoveriesSize(store)
  if size.bytes <= budget then
    return 0, size.bytes
  end
  local held = store.discoveries
  local queue = {}
  for itemId, value in pairs(held) do
    if itemId ~= keep then
      local step, at = evictionOf(itemId, value)
      queue[#queue + 1] = { id = itemId, step = step, at = at }
    end
  end
  table.sort(queue, evictsFirst)
  local evicted = 0
  for _, entry in ipairs(queue) do
    if size.bytes <= budget then
      break
    end
    size.bytes = size.bytes - Collector.EntryBytes(entry.id, held[entry.id])
    size.records = (size.records or 1) - 1
    held[entry.id] = nil
    evicted = evicted + 1
  end
  return evicted, size.bytes
end

--- Packs every old shaped discovery record (a table) once, at load (Core/Init.lua, before the
--- collector is made), and then holds the store to its budget (Collector.EvictDiscoveries): the
--- cap is the one thing that may drop a record here. A record that cannot be packed stays as it
--- is and the marker (store.discoveriesShape) is then not set, so the next load tries again.
---
--- Answers { packed, kept, capped, before, after }: before and after are the store's bytes
--- (Collector.DiscoveriesSize) either side, measured only when a record was packed or capped.
--- opts.budget overrides the cap (a spec's).
function Collector.MigrateDiscoveries(store, opts)
  opts = opts or EMPTY
  local result = { packed = 0, kept = 0, capped = 0 }
  if type(store) ~= "table" or type(store.discoveries) ~= "table" then
    return result
  end
  local held = store.discoveries
  local old = {}
  for itemId, value in pairs(held) do
    if type(value) ~= "string" then
      old[#old + 1] = itemId
    end
  end
  local before = Collector.DiscoveriesSize(store)
  if #old > 0 then
    result.before = before.bytes
    table.sort(old, function(a, b)
      return tostring(a) < tostring(b)
    end)
    for _, itemId in ipairs(old) do
      local packed = nil
      if type(itemId) == "number" then
        packed = Collector.PackRecord(itemId, held[itemId], store)
      end
      if packed then
        held[itemId] = packed
        result.packed = result.packed + 1
      else
        result.kept = result.kept + 1
      end
    end
    before = Collector.DiscoveriesSize(store)
  end
  if result.kept == 0 then
    store.discoveriesShape = Collector.DISCOVERIES_SHAPE
  end
  local startBytes = before.bytes
  result.capped = Collector.EvictDiscoveries(store, opts.budget, nil, before)
  if result.capped > 0 and not result.before then
    result.before = startBytes
  end
  if result.before then
    result.after = Collector.DiscoveriesSize(store).bytes
  end
  return result
end

--- The debug report's line for the load's discovery migration, or nil where nothing was packed or
--- capped. result is Collector.MigrateDiscoveries's answer.
function Collector.DiscoveriesMigrationLine(result)
  if type(result) ~= "table" then
    return nil
  end
  local packed, capped = tonumber(result.packed) or 0, tonumber(result.capped) or 0
  if packed == 0 and capped == 0 then
    return nil
  end
  return string.format(
    "Discoveries packed at login: %d (%.1f KB before, %.1f KB after), %d dropped by the cap",
    packed,
    (tonumber(result.before) or 0) / 1024,
    (tonumber(result.after) or 0) / 1024,
    capped
  )
end

--- The debug report's line for the discovery store: its size, the budget, how many records it
--- holds and how many the cap has let go since login. info is C:DiscoveriesStoreSize's answer.
function Collector.DiscoveriesSizeLine(info)
  info = type(info) == "table" and info or EMPTY
  return string.format(
    "Discoveries store: %.1f KB of %d KB budget, %d records, %d pruned since login",
    tonumber(info.kb) or 0,
    math.floor((tonumber(info.budget) or Collector.DISCOVERIES_MAX_BYTES) / 1024),
    tonumber(info.records) or 0,
    tonumber(info.pruned) or 0
  )
end

--- The running size of this collector's discoveries, worked out from scratch the first time it is
--- asked and kept up to date by every discovery write and prune after that.
function C:DiscoveriesSize()
  if not self.discBytes then
    local size = Collector.DiscoveriesSize(self.store)
    self.discBytes, self.discRecords = size.bytes, size.records
  end
  return {
    records = self.discRecords,
    bytes = self.discBytes,
    kb = math.floor(self.discBytes / 1024 * 10 + 0.5) / 10,
  }
end

--- What the debug report says about the discovery store: C:DiscoveriesSize plus the budget and the
--- records the cap has let go since login (the login's migration included).
function C:DiscoveriesStoreSize()
  local size = self:DiscoveriesSize()
  size.budget = Collector.DISCOVERIES_MAX_BYTES
  size.pruned = self.discPruned or 0
  return size
end

-- Folds one discovery write into the running size. before is the bytes the record took before
-- the write (0 for a new one), or nil to have the size worked out afresh on the next ask.
function C:_DiscoveryResize(itemId, before, added)
  if not self.discBytes then
    return
  end
  if before == nil then
    self.discBytes, self.discRecords = nil, nil
    return
  end
  self.discBytes = self.discBytes - before + Collector.EntryBytes(itemId, self.store.discoveries[itemId])
  if added then
    self.discRecords = self.discRecords + 1
  end
end

-- A binary heap of eviction entries, smallest first by less. A sorted array is one already.
local function heapPush(heap, entry, less)
  local at = #heap + 1
  heap[at] = entry
  while at > 1 do
    local parent = math.floor(at / 2)
    if not less(heap[at], heap[parent]) then
      break
    end
    heap[at], heap[parent] = heap[parent], heap[at]
    at = parent
  end
end

local function heapPop(heap, less)
  local count = #heap
  if count == 0 then
    return nil
  end
  local top = heap[1]
  heap[1] = heap[count]
  heap[count] = nil
  count = count - 1
  local at = 1
  while true do
    local left, right, least = at * 2, at * 2 + 1, at
    if left <= count and less(heap[left], heap[least]) then
      least = left
    end
    if right <= count and less(heap[right], heap[least]) then
      least = right
    end
    if least == at then
      break
    end
    heap[at], heap[least] = heap[least], heap[at]
    at = least
  end
  return top
end

-- What the discovery eviction queue was built against: the store's table, and the data layer and
-- its generation (a record's step reads whether the data names the item, Collector.DataNames).
local function dataStamp()
  local data = ItemTree.Data
  return data, type(data) == "table" and data.generation or nil
end

-- The discovery store's eviction queue (Collector.EvictDiscoveries' order) as a heap, built once
-- and kept: a new record joins it as it is written (C:_QueueDiscovery), and an entry whose record
-- has since moved later in the order (a realm find the player then obtained) is put back where it
-- now goes when it comes up (C:PruneDiscoveries). Built afresh for another store or a data reload.
function C:_DiscoveryQueue()
  local data, generation = dataStamp()
  local held = self.store.discoveries
  local queue = self.discQueue
  if queue and self.discQueueHeld == held and self.discQueueData == data and self.discQueueGeneration == generation then
    return queue
  end
  queue = {}
  for itemId, value in pairs(held) do
    local step, at = evictionOf(itemId, value)
    queue[#queue + 1] = { id = itemId, step = step, at = at }
  end
  table.sort(queue, evictsFirst)
  self.discQueue, self.discQueueHeld = queue, held
  self.discQueueData, self.discQueueGeneration = data, generation
  return queue
end

-- A record just written joins the kept queue, where there is one.
function C:_QueueDiscovery(itemId)
  local queue = self.discQueue
  local value = self.store.discoveries[itemId]
  if queue and value ~= nil then
    local step, at = evictionOf(itemId, value)
    heapPush(queue, { id = itemId, step = step, at = at }, evictsFirst)
  end
end

--- Holds the discovery store to budget bytes (Collector.DISCOVERIES_MAX_BYTES by default), never
--- evicting keep, the id just written (Collector.EvictDiscoveries has the order). Called after
--- every discovery written and, through Collector.MigrateDiscoveries, once at login. Under budget
--- nothing is visited: the size is a running total. Answers how many went.
---
--- The records that go, and their order, are Collector.EvictDiscoveries' over the store as it
--- stands; the order is kept in a queue (C:_DiscoveryQueue) rather than sorted again on every
--- write, so a store at its cap costs a heap step a discovery rather than a sort of every record.
--- A queue entry is checked against its record when it comes up: a record gone is skipped, one
--- that now goes later is put back in its place, and one that would now go earlier (only a data
--- change can do that) has the queue built afresh.
function C:PruneDiscoveries(budget, keep)
  budget = tonumber(budget) or Collector.DISCOVERIES_MAX_BYTES
  local size = self:DiscoveriesSize()
  if size.bytes <= budget then
    return 0
  end
  local held = self.store.discoveries
  local queue = self:_DiscoveryQueue()
  local evicted, aside = 0, nil
  while self.discBytes > budget do
    local entry = heapPop(queue, evictsFirst)
    if not entry then
      break
    end
    local value = held[entry.id]
    if value ~= nil then
      local step, at = evictionOf(entry.id, value)
      if step ~= entry.step or at ~= entry.at then
        local now = { id = entry.id, step = step, at = at }
        if evictsFirst(now, entry) then
          self.discQueue = nil
          queue = self:_DiscoveryQueue()
          aside = nil
        else
          heapPush(queue, now, evictsFirst)
        end
      elseif entry.id == keep then
        aside = entry
      else
        self.discBytes = self.discBytes - Collector.EntryBytes(entry.id, value)
        self.discRecords = (self.discRecords or 1) - 1
        held[entry.id] = nil
        evicted = evicted + 1
      end
    end
  end
  if aside then
    heapPush(queue, aside, evictsFirst)
  end
  if evicted > 0 then
    self.discPruned = (self.discPruned or 0) + evicted
    self:_Touch()
  end
  return evicted
end

function C:Clear()
  self.store.records = {}
  self.store.counts = {}
  self.store.discoveries = {}
  self.store.discoveriesShape = Collector.DISCOVERIES_SHAPE
  self.discoveryTimes = {}
  self.discBytes, self.discRecords = nil, nil
  self.store.questNpcs = {}
  self.store.questFacts = nil
  -- Brief RF375 fix 7: and the dropped pushed lines' audit log, counted in the same budget.
  self.store.pushDrops = nil
  self.qfBytes, self.qfRecords = nil, nil
  self.handoverIndex = nil
  -- Brief DM2: the creature displays go with the rest.
  self.store.displays = nil
  self.dpBytes, self.dpRecords = nil, nil
  -- Brief TW1: and the trainer lists.
  self.store.trainers = nil
  self.tlBytes, self.tlRecords = nil, nil
  self.store.seenBosses = {}
  self.store.builds = nil
  self.store.shape = Collector.SHAPE
  self.buildIndex = nil
  self.sizeBytes, self.sizeRecords = nil, nil
  self.pruneQueue, self.pruneCursor, self.pruneDay = nil, nil, nil
  self:_Invalidate()
end

-- Registers EdgesFor with the graph. Safe to call twice: the previous registration is
-- replaced rather than stacked.
function C:Install()
  if self.provider then
    Graph.UnregisterProvider(self.provider)
  end
  self.provider = function(key, direction)
    return self:EdgesFor(key, direction)
  end
  Graph.RegisterProvider(self.provider)
  -- Names the realm has already discovered, read by the graph from this store when it is asked
  -- for one, so a withheld item that was named in an earlier session still draws its name rather
  -- than its slot. Brief R3: read through, not copied into Graph.names at login, so the names are
  -- held once.
  if type(Graph.SetItemNameSource) == "function" then
    self.nameSource = function(itemId)
      return self:DiscoveredName(itemId)
    end
    Graph.SetItemNameSource(self.nameSource)
  else
    for itemId in pairs(self.store.discoveries) do
      Graph.SetName(Graph.Key("item", itemId), self:DiscoveredName(itemId))
    end
  end
  self:SetNames()
  return self.provider
end

-- Every quest title this store has learned, keyed by quest id. Only quests: an npc or an object
-- names itself on the edge that points at it, and a quest has to be openable by its key alone.
function C:LearnedQuests()
  local out = {}
  for _, record in pairs(self:Records()) do
    if record.sourceKind == "quest" and type(record.sourceId) == "number" and type(record.sourceName) == "string" then
      out[record.sourceId] = record.sourceName
    end
  end
  -- Brief R9: and the titles the quest NPC store keeps, for a quest that rewarded no item.
  for questId, byQuest in pairs(type(self.store.questNpcs) == "table" and self.store.questNpcs or EMPTY) do
    local title = type(byQuest) == "table" and Collector.QuestTitle(byQuest.title) or nil
    if type(questId) == "number" and title and not out[questId] then
      out[questId] = title
    end
  end
  return out
end

-- Puts every learned quest's title on the graph now rather than on the first edge asked for.
--
-- A quest the curated table has never heard of is drawn from Graph.names alone, so without this
-- a row reached from the recently viewed list, or a quest key opened by a command, would read
-- "Quest 92842" until something asked the item side for its edges. Core/Quests.lua's SetNames
-- does exactly this for the curated quests; Install calls this one straight after registering.
function C:SetNames()
  for questId, title in pairs(self:LearnedQuests()) do
    Graph.SetName(Graph.Key("quest", questId), title)
  end
  -- Brief N2: an NPC the player looted or bought from has a page of its own, which can be opened
  -- by its key alone (the recently viewed list after a reload), so its name goes on the graph too.
  for _, record in pairs(self:Records()) do
    if
      record.sourceKind == "npc"
      and NPC_SPECS[record.kind]
      and type(record.sourceId) == "number"
      and type(record.sourceName) == "string"
    then
      Graph.SetName(Graph.Key("npc", record.sourceId), record.sourceName)
    end
  end
  -- Brief Q8: and the NPCs that gave or took back a quest, whose rows open their pages.
  for _, byQuest in pairs(self.store.questNpcs) do
    for kind in pairs(Collector.QUEST_NPC_KINDS) do
      local held = type(byQuest) == "table" and byQuest[kind] or nil
      if type(held) == "table" and type(held.npcId) == "number" and type(held.name) == "string" then
        Graph.SetName(Graph.Key("npc", held.npcId), held.name)
      end
    end
  end
  return self
end

-- Whether this collector's provider is registered with the graph right now. Install answers
-- nothing about whether it landed, and every collected source travels through that one
-- registration, so it is worth being able to ask.
function C:Installed()
  return self.provider ~= nil and Graph.HasProvider(self.provider) == true
end

function C:Uninstall()
  if self.provider then
    Graph.UnregisterProvider(self.provider)
    self.provider = nil
  end
  if self.nameSource and type(Graph.ItemNameSource) == "function" and Graph.ItemNameSource() == self.nameSource then
    Graph.SetItemNameSource(nil)
  end
  self.nameSource = nil
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

-- The client's numeric realm id, and whether the client has the call at all. rawget, so a
-- client without GetRealmID costs one table read, and pcall, so one that raises answers nil.
-- Only a positive whole number is kept. The realm's name is never read (not GetRealmName, not
-- GetNormalizedRealmName, not UnitFullName): the name identifies a realm and the number alone
-- does not.
function Collector.ReadRealmId()
  local read = rawget(_G, "GetRealmID")
  if type(read) ~= "function" then
    return nil, false
  end
  local ok, value = pcall(read)
  if not ok then
    return nil, true
  end
  return Collector.RealmId(value), true
end

-- The name of the character this session is on, and whether the client has the call at all.
-- UnitName("player") alone: the name without its realm, pcalled, and kept only where it is a
-- plain name (Collector.CharacterName). The global UNKNOWNOBJECT, where the client has it, is the
-- placeholder the client answers before it knows, and reads as no answer.
function Collector.ReadCharacterName()
  local read = rawget(_G, "UnitName")
  if type(read) ~= "function" then
    return nil, false
  end
  local ok, value = pcall(read, "player")
  if not ok then
    return nil, true
  end
  local unknown = rawget(_G, "UNKNOWNOBJECT")
  if type(unknown) == "string" and value == unknown then
    return nil, true
  end
  return Collector.CharacterName(value), true
end

-- Brief R15: a uiMap's own name out of the client (C_Map.GetMapInfo(mapId).name), or nil. rawget
-- and pcall, so a client without the call, or one that raises, answers nil. A name is kept for
-- the session once read (a map's name does not change while the client runs); a miss is not
-- kept, so a map the client could not name yet is asked again.
Collector.mapNames = {}

function Collector.MapName(mapId)
  mapId = positiveWhole(mapId)
  if not mapId then
    return nil
  end
  local held = Collector.mapNames[mapId]
  if held then
    return held
  end
  local api = rawget(_G, "C_Map")
  if type(api) ~= "table" or type(api.GetMapInfo) ~= "function" then
    return nil
  end
  local ok, info = pcall(api.GetMapInfo, mapId)
  if not ok or type(info) ~= "table" or type(info.name) ~= "string" or info.name == "" then
    return nil
  end
  Collector.mapNames[mapId] = info.name
  return info.name
end

return Collector
