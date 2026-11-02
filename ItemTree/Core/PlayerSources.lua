-- Player sourced rows: the shipped PlayerSources module (brief PS1), what players recorded in game
-- and the shared finds pipeline decided may ship, read one item or one npc at a time and turned
-- into ordinary source rows. Pure Lua; the one client read (a map's name) goes through
-- Core/Collector.lua's guarded Collector.MapName. Loaded as: local _, ItemTree = ...
--
-- The contract is ItemTree-Data docs/mining.md, "Shipped player sources":
--
--   { meta = { schema = 2, build, generated, rules, rates, counts },
--     r = { [itemId] = { { section, sourceKind, sourceId, seen }, ... } },
--     v = { [itemId] = { { npcId, seen, copper, stock, uiMap, costIndex, s }, ... } },
--     c = { { c = { [currencyId] = amount }, i = { [itemId] = count } }, ... },
--     n = { [npcId] = name }, o = { [objectId] = name },
--     p = { [npcId] = { { uiMap, cell, count, cell, count, ... }, ... } },
--     q = { [questId] = { t = title, r = { itemId, ... }, n = { itemId, count, ... }, o = { itemId, ... },
--                         g = { npcId, uiMap, ... }, e = { npcId, uiMap, ... }, c, cl, cs,
--                         og = { objectId, uiMap, ... }, oe = { objectId, uiMap, ... },
--                         h = { itemId, count, when, taken, npcId, ... } } },
--     k = { [npcId] = roles }, w = { [npcId] = trains } }
--
-- Brief QH1 (still schema 2: a reader that does not know a q field skips it): og and oe are a
-- quest's givers and enders that are world objects (a wanted poster, a chest), by object id and the
-- uiMap each was met on, named in o; h is what the quest handed the player, five numbers an item:
-- the item, how many, when (1 at the accept, 2 from an NPC while the quest was worked, 3 at the turn
-- in), whether the hand-in took it (1 taken, 2 left with the player, 3 gone before the hand-in (brief
-- IW1's bag check), 0 not known) and the creature
-- that handed it over (a mid quest hand-over only, else 0). PlayerSources.QuestHandovers and
-- PlayerSources.ItemHandovers read h beside the player's own records, own first.
--
-- Brief PS5 (schema 2, the second cut): q is each quest's title (only where no shipped table names
-- it), the items it hands over (r), asks for with their counts (n) and names as objectives (o), and
-- its givers (g) and enders (e) with the uiMap each was met on (0 unknown). p holds every NPC's spot
-- now, a vendor's, a quest giver's or ender's, a trainer's or a stable master's, one per uiMap with
-- every role's cells summed. k is an NPC's roles as bits (1 vendor, 2 quest giver, 4 quest ender,
-- 8 trainer, 16 stable master) and w what a trainer trains. A schema 1 module (no q, k or w; p for
-- vendors alone) is still read: its roles are worked out from v and p.
--
-- Brief QN1: a quest one giver gives beside same titled quests carries c (its 1 based place in
-- that group), cl (the group's size) and cs (where the order came from: "id" quest id order, "at"
-- the accept times players recorded). A vendor row's s is the side of the players who recorded it
-- (1 Alliance, 2 Horde, 3 both), absent where no record stated one. A side seen is not a side
-- served (the owner, 2026-10-03): Zephras Isle's starting area is shared, so an Alliance record of
-- a vendor there says nothing about Horde. See PlayerSources.SaleSide for what s is allowed to say.
-- Brief TS1 (the owner's ruling "A", 2026-10-23): the island itself serves both sides, so a vendor
-- met there is both sides' by its place (PlayerSources.SIDE_PLACES), whatever s says.
--
-- section 1 drop, 2 gathered, 3 contained (the source item is the container), 4 disenchant (the
-- source item disenchants into this one), 5 found in a chest, 6 mined from a vein, and (brief SK1)
-- 7 skinned from and 8 pickpocketed from a creature; sourceKind 1 npc, 2 object, 3 item. Trailing
-- zeros are left off a row. No rate ships yet (owner ruling 2026-10-02), so nothing here draws one.
--
-- How the rows are drawn (owner rulings of 2026-10-02):
--   * Plain data: the "mined" tier, which wears no badge (no Predicted mark, no verified check),
--     and the provenance "player", which Core/Sources.lua words as one muted tooltip line,
--     "Reported by players". The confidence sits below the player's own verified records and
--     above Predicted and the guesses.
--   * One row per fact. Where the player's own record states the same fact (same item, same source
--     kind and id), this provider leaves it to the collector, whose row keeps every detail it holds
--     (the tally, the price the window showed, the zone) and drops its verified check for this tier
--     (Core/Collector.lua, Collector.ShipsAsPlayer). Anything the module does not state stays the
--     player's own row, check and all.
--   * Every vendor row ships and is drawn, one per npc: several vendors of one item are several rows.
--   * A real row of a family replaces a guess of it: Core/Graph.lua's own rules
--     (Graph.DropGuessEdges) read these rows as real, so nothing here has to.
--
-- The provider answers:
--   item:<id>  up    DROPPED_BY, GATHERED_FROM, CONTAINED_IN, DISENCHANTED_FROM, SOLD_BY
--   item:<id>  down  CONTAINS, DISENCHANTS_INTO (the item as the container or the disenchanted item)
--   npc:<id>   down  CREATURE_DROPS, SELLS (its page's Loot and Sells tabs), and (brief PS5)
--                    GIVES_QUEST and TAKES_QUEST (its Quests tab)
--   item:<id>  up    QUEST_REWARD (brief PS5: the quests that hand it over)
--   item:<id>  up    QUEST_PROVIDED (brief IW1: the quests the records say hand it over at the accept
--                    or mid quest, h and the player's own hand-overs: "Provided by quest")
--   item:<id>  down  QUEST_OBJECTIVE (brief PS5: the quests that ask for it, with the count)
--   quest:<id> up    QUEST_REQUIRES (brief PS5: what the quest asks for, with the count)
--   quest:<id> down  QUEST_REWARDS (brief SD1: what the quest hands over, so Used by reads it)
-- A quest's title, givers, enders and rewards reach its page through PlayerSources.QuestFacts
-- (Core/ViewModel.lua ViewModel.Quest), and its title through the namer.
--
-- Brief PS2: a zone's Here tab lists the rows the module places on the zone's map
-- (PlayerSources.MapRows, read by Core/ViewModel.lua ViewModel.PlayerZoneEdges), and the search box
-- finds the npcs its name table names (Core/Data.lua Data:ForeverCreatureIndex).
--
-- Load on demand. The module is built on the first ask from a view (Data:Get, which loads
-- ItemTree_Data if it must), never at login and never for a tooltip: the provider is registered
-- where Graph.Summary skips it, like Core/ForeverVendors.lua. PlayerSources.Provenance, which the
-- collector's prune asks at login, and the namer read a module already built and never load one.
-- With no module (every build before PS1) every answer is empty and nothing changes.
local _, ItemTree = ...

local Data = ItemTree.Data
local Edges = ItemTree.Edges
local Graph = ItemTree.Graph
local Confidence = ItemTree.Confidence
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local T = Edges.Types
local EMPTY = {}

local PlayerSources = {}
ItemTree.PlayerSources = PlayerSources

PlayerSources.MODULE = "PlayerSources"
-- The newest schema this reader knows, and every schema it reads (brief PS5: 2, and still 1).
PlayerSources.SCHEMA = 2
PlayerSources.SCHEMAS = { [1] = true, [2] = true }
-- The provenance every edge carries (Core/Sources.lua words it) and Provenance answers. The same
-- word Core/Collector.lua's ShipsAsPlayer compares with.
PlayerSources.PROVENANCE = "player"

-- The source kinds, by code, in the collector's own words.
PlayerSources.KINDS = { [1] = "npc", [2] = "object", [3] = "item" }

-- The sections, by code: the collector's record kind for the same fact, the edge on the item, and
-- the edge on the source (a container or disenchanted item walking down, or an npc's page).
PlayerSources.SECTIONS = {
  [1] = {
    kind = "drop",
    up = { edge = T.DROPPED_BY, group = L["Drops from"] },
    npc = { edge = T.CREATURE_DROPS, group = L["Drops"] },
  },
  [2] = { kind = "gather", up = { edge = T.GATHERED_FROM, group = L["Gathered from"] } },
  [3] = {
    kind = "container",
    up = { edge = T.CONTAINED_IN, group = L["Contained in"] },
    down = { edge = T.CONTAINS, group = L["Contains"] },
  },
  [4] = {
    kind = "disenchant",
    up = { edge = T.DISENCHANTED_FROM, group = L["Disenchanted from"] },
    down = { edge = T.DISENCHANTS_INTO, group = L["Disenchants into"] },
  },
  -- Brief BQ5 (owner QA 2026-10-10: Battered Chest and Dented Chest under "Gathered from"): a
  -- gathered row whose object the pipeline files by its kind (ItemTree-Data player_sources.py
  -- OBJECT_SECTIONS, the Classic Era table's categories): a chest is found in, as a Classic Era
  -- chest row is, and a vein is mined from. The collector's own record kind is still a gather.
  [5] = { kind = "gather", up = { edge = T.LOOTED_FROM, group = L["Found in"] } },
  [6] = { kind = "gather", up = { edge = T.GATHERED_FROM, group = L["Mined from"] } },
  -- Brief SK1 (owner ruling 2026-10-15, "I wouldn't want them in the drops table"): what players
  -- skinned and pickpocketed off a creature, recorded as such since SK1 (Core/Collector.lua kinds
  -- "skin" and "pickpocket") or a drop row the pipeline moved here because the Classic Era table
  -- lists it only under Skinned from or Pickpocketed from (ItemTree-Data player_sources.py). Filed
  -- as the Classic Era table files the same two (Core/EraSources.lua PLACES and CREATURE_LOOT); a
  -- pocket is a marked DROPPED_BY, which Core/Graph.lua never folds into a drop of the creature.
  [7] = {
    kind = "skin",
    up = { edge = T.SKINNED_FROM, group = L["Skinned from"] },
    npc = { edge = T.CREATURE_SKINNED, group = L["Skinned"] },
  },
  [8] = {
    kind = "pickpocket",
    up = { edge = T.DROPPED_BY, group = L["Pickpocketed from"], pocket = true },
    npc = { edge = T.CREATURE_POCKETED, group = L["Pickpocketed"] },
  },
}
PlayerSources.VENDOR_KIND = "vendor"

-- Brief PS5: an NPC's roles, as the bits of k (ItemTree-Data player_sources.py ROLE_*), and their
-- order on a page and in NpcsWithRole's answers.
PlayerSources.ROLES = { vendor = 1, giver = 2, ender = 4, trainer = 8, stable = 16 }
PlayerSources.ROLE_ORDER = { "vendor", "giver", "ender", "trainer", "stable" }

-- Brief PS5: the collector's quest record kinds (source kind "quest"), by the q field that states
-- each. An objective is stated by o, or by n where the quest's count already names the item.
PlayerSources.QUEST_KINDS = { quest_reward = { "r" }, quest_requires = { "n" }, quest_objective = { "o", "n" } }

-- How many times the reverse index was built, for the spec that pins it to pages that need it.
PlayerSources.reverseBuilds = 0

--------------------------------------------------------------------------------
-- The module
--------------------------------------------------------------------------------

--- Why a module cannot be read (no module, another schema, no rows), or nil when it can. Pure.
function PlayerSources.Refusal(source)
  if type(source) ~= "table" then
    return "no module"
  end
  local meta = source.meta
  if type(meta) ~= "table" then
    return "no meta"
  end
  if not PlayerSources.SCHEMAS[meta.schema] then
    return string.format("schema %s, this reader knows 1 to %d", tostring(meta.schema), PlayerSources.SCHEMA)
  end
  if type(source.r) ~= "table" or type(source.v) ~= "table" then
    return "no rows"
  end
  return nil
end

local function readable(source)
  if PlayerSources.Refusal(source) then
    return nil
  end
  return source
end

--- The module table, built on this first ask (Data:Get loads ItemTree_Data if it must), or nil for
--- a build that ships none or one this reader refuses. PlayerSources.source states one for a spec.
function PlayerSources.Table()
  if PlayerSources.source ~= nil then
    return readable(PlayerSources.source)
  end
  if type(Data) ~= "table" or type(Data.Get) ~= "function" then
    return nil
  end
  local ok, table_ = pcall(Data.Get, Data, PlayerSources.MODULE)
  if ok then
    return readable(table_)
  end
  return nil
end

--- The module table only where it is already built, or nil: what Provenance and the namer read, so
--- asking never loads anything.
function PlayerSources.Loaded()
  if PlayerSources.source ~= nil then
    return readable(PlayerSources.source)
  end
  local cache = type(Data) == "table" and Data.cache or nil
  return readable(type(cache) == "table" and cache[PlayerSources.MODULE] or nil)
end

-- A whole number at least 0 out of a row field, 0 where it states none.
local function field(row, index)
  local value = tonumber(row[index])
  if not value or value < 0 or value ~= math.floor(value) then
    return 0
  end
  return value
end

--- One item's rows decoded: { { section, kind, sourceKind, sourceId, seen }, ... } in the module's
--- order, every row it states that this reader knows. Pure.
function PlayerSources.Rows(source, itemId)
  local out = {}
  local list = type(source) == "table" and type(source.r) == "table" and source.r[itemId] or nil
  for _, row in ipairs(type(list) == "table" and list or EMPTY) do
    local section = type(row) == "table" and PlayerSources.SECTIONS[row[1]] or nil
    local sourceKind = section and PlayerSources.KINDS[row[2]] or nil
    local sourceId = sourceKind and field(row, 3) or 0
    if sourceKind and sourceId > 0 then
      out[#out + 1] = {
        section = row[1],
        kind = section.kind,
        sourceKind = sourceKind,
        sourceId = sourceId,
        seen = field(row, 4),
      }
    end
  end
  return out
end

-- A cost shape out of c, as Core/Graph.lua's cost field takes it, or nil.
local function costAt(source, index)
  local list = type(source) == "table" and source.c or nil
  local shape = type(list) == "table" and index > 0 and list[index] or nil
  if type(shape) ~= "table" then
    return nil
  end
  local currency = type(shape.c) == "table" and next(shape.c) ~= nil and shape.c or nil
  local items = type(shape.i) == "table" and next(shape.i) ~= nil and shape.i or nil
  if not currency and not items then
    return nil
  end
  return { currency = currency, items = items }
end

--------------------------------------------------------------------------------
-- A vendor's side (brief QN1)
--------------------------------------------------------------------------------

-- The values a vendor row's s may hold: 1 Alliance players recorded it, 2 Horde players, 3 both.
PlayerSources.SIDES_SEEN = { [1] = true, [2] = true, [3] = true }

-- The places that prove a side by themselves (the owner, 2026-10-03): a vendor met in one of the
-- faction cities or the classic starting zones serves the side the place belongs to, so a sighting
-- there may say "Alliance only" as a Classic Era vendor's row does. Classic uiMap ids, checked
-- against the shipped Classic Era table's zm on 2026-10-03. 1 Alliance, 2 Horde, and (brief TS1)
-- 3 both.
--
-- Brief TS1 (the owner's ruling "A", 2026-10-23, QA item 405 after the TL1 trainer audit): Zephras
-- Isle (uiMap 2521, AreaTable zone 16593), Forever's starting island, serves BOTH sides. The
-- client's AreaTable gives every Zephras Isle area FactionGroupMask 0 (no side owns it), and every
-- stored Zephras NPC page states react [1,1] (friendly to the Alliance and the Horde alike). So an
-- NPC met there is neutral, as a Classic Era cf 3 NPC is: its row wears the neutral mark and "Hide
-- other faction data" never hides it.
PlayerSources.BOTH_SIDES = 3
PlayerSources.SIDE_PLACES = {
  [1453] = 1, -- Stormwind City
  [1455] = 1, -- Ironforge
  [1457] = 1, -- Darnassus
  [1429] = 1, -- Elwynn Forest
  [1426] = 1, -- Dun Morogh
  [1438] = 1, -- Teldrassil
  [1454] = 2, -- Orgrimmar
  [1456] = 2, -- Thunder Bluff
  [1458] = 2, -- Undercity
  [1411] = 2, -- Durotar
  [1412] = 2, -- Mulgore
  [1420] = 2, -- Tirisfal Glades
  [2521] = 3, -- Zephras Isle (both sides, brief TS1 above)
}

--- What one decoded sale (PlayerSources.Sales) may say about its vendor's side:
---
---   faction    1 or 2, where the place proves the side (PlayerSources.SIDE_PLACES) and the
---              players who recorded it were of that side: the edge's faction, as an Era vendor's.
---              Brief TS1: 3 (both) for every sale met in a place that serves both sides (Zephras
---              Isle), whoever recorded it, since no side seen there can disagree with it
---   seen       1 or 2, where only players of one side recorded it anywhere else: a tooltip line
---              ("Seen by Alliance players") and never a faction, because a side seen is not a
---              side served
---   disagrees  true where the recorded side is not the side of the place it was met in (a Horde
---              sighting in Stormwind): neither words nor faction, counted by the debug line
---
--- Every answer is nil for a sale with no side or with both sides (3), outside a place that serves
--- both. Pure.
function PlayerSources.SaleSide(sale)
  if type(sale) ~= "table" then
    return nil, nil, nil
  end
  if PlayerSources.SIDE_PLACES[sale.uiMap] == PlayerSources.BOTH_SIDES then
    return PlayerSources.BOTH_SIDES, nil, nil
  end
  local side = sale.side
  if side ~= 1 and side ~= 2 then
    return nil, nil, nil
  end
  local place = PlayerSources.SIDE_PLACES[sale.uiMap]
  if place == nil then
    return nil, side, nil
  end
  if place == side then
    return side, nil, nil
  end
  return nil, nil, true
end

--- Brief QN1: how the module's vendor rows state a side, for /itemtree debug: { rows, alliance,
--- horde, both, place, disagrees }: every vendor row, those seen by one side or both, those whose
--- place proves the side and those whose side disagrees with their place. Pure.
function PlayerSources.SideCounts(source)
  local out = { rows = 0, alliance = 0, horde = 0, both = 0, place = 0, disagrees = 0 }
  for itemId in pairs(type(source) == "table" and type(source.v) == "table" and source.v or EMPTY) do
    if type(itemId) == "number" then
      for _, sale in ipairs(PlayerSources.Sales(source, itemId)) do
        out.rows = out.rows + 1
        if sale.side == 1 then
          out.alliance = out.alliance + 1
        elseif sale.side == 2 then
          out.horde = out.horde + 1
        elseif sale.side == 3 then
          out.both = out.both + 1
        end
        local faction, _, disagrees = PlayerSources.SaleSide(sale)
        if faction then
          out.place = out.place + 1
        elseif disagrees then
          out.disagrees = out.disagrees + 1
        end
      end
    end
  end
  return out
end

--- Brief QN1: the player sources line /itemtree debug prints, counts only, over a module already
--- built (it never loads one).
function PlayerSources.DebugLine()
  local source = PlayerSources.Loaded()
  if not source then
    return "Player sources: not built"
  end
  local counts = PlayerSources.SideCounts(source)
  return string.format(
    "Player sources: %d vendor rows, side seen %d Alliance, %d Horde, %d both, %d proved by place, "
      .. "%d side disagrees with place",
    counts.rows,
    counts.alliance,
    counts.horde,
    counts.both,
    counts.place,
    counts.disagrees
  )
end

--- One item's vendor rows decoded: { { npcId, seen, copper, stock, uiMap, cost, side }, ... },
--- copper, stock and uiMap nil where the row states none, cost the currencies and items it asks or
--- nil, side (brief QN1) the players' side the row's s states, 1, 2 or 3, or nil. Every vendor the
--- module names for the item, one entry each. Pure.
function PlayerSources.Sales(source, itemId)
  local out = {}
  local list = type(source) == "table" and type(source.v) == "table" and source.v[itemId] or nil
  for _, row in ipairs(type(list) == "table" and list or EMPTY) do
    local npcId = type(row) == "table" and field(row, 1) or 0
    if npcId > 0 then
      local copper, stock, uiMap = field(row, 3), field(row, 4), field(row, 5)
      out[#out + 1] = {
        npcId = npcId,
        seen = field(row, 2),
        copper = copper > 0 and copper or nil,
        stock = stock > 0 and stock or nil,
        uiMap = uiMap > 0 and uiMap or nil,
        cost = costAt(source, field(row, 6)),
        side = PlayerSources.SIDES_SEEN[field(row, 7)] and field(row, 7) or nil,
      }
    end
  end
  return out
end

--- Whether a module table states one fact, in the collector's words: kind "drop", "gather",
--- "container", "disenchant" or "vendor", the item, and the source's kind and id. Pure.
function PlayerSources.States(source, kind, itemId, sourceKind, sourceId)
  if type(itemId) ~= "number" or type(sourceId) ~= "number" then
    return false
  end
  local fields = PlayerSources.QUEST_KINDS[kind]
  if fields then
    return sourceKind == "quest" and PlayerSources.QuestStates(source, sourceId, fields, itemId)
  end
  if kind == PlayerSources.VENDOR_KIND then
    if sourceKind ~= "npc" then
      return false
    end
    for _, sale in ipairs(PlayerSources.Sales(source, itemId)) do
      if sale.npcId == sourceId then
        return true
      end
    end
    return false
  end
  for _, row in ipairs(PlayerSources.Rows(source, itemId)) do
    if row.kind == kind and row.sourceKind == sourceKind and row.sourceId == sourceId then
      return true
    end
  end
  return false
end

--- The provenance the installed data ships one fact with: "player" where the module states it,
--- else nil. The reader Core/Collector.lua's ShipsAsPlayer expects. Reads a module already built
--- only (the prune asks at login), so it never loads anything.
function PlayerSources.Provenance(kind, itemId, sourceKind, sourceId)
  local source = PlayerSources.Loaded()
  if source and PlayerSources.States(source, kind, itemId, sourceKind, sourceId) then
    return PlayerSources.PROVENANCE
  end
  return nil
end

--- Brief SK1: "skin" or "pickpocket" where a module table states one item off one npc as skinned
--- (section 7) or pickpocketed (section 8) and NOT as a drop (section 1), else nil. That is the
--- pipeline's cleanup of the drop rows older recorders filed (the Classic Era table lists the pair
--- only under Skinned from or Pickpocketed from), so a player's own older drop record of the same
--- pair is the same loot (Core/Collector.lua Collector.ShownKind). Pure.
function PlayerSources.RefiledIn(source, itemId, npcId)
  if type(itemId) ~= "number" or type(npcId) ~= "number" then
    return nil
  end
  local found = nil
  for _, row in ipairs(PlayerSources.Rows(source, itemId)) do
    if row.sourceKind == "npc" and row.sourceId == npcId then
      if row.section == 1 then
        return nil
      elseif row.section == 7 or row.section == 8 then
        found = found or row.kind
      end
    end
  end
  return found
end

--- PlayerSources.RefiledIn over the module already built, or nil. Never loads one.
function PlayerSources.Refiled(itemId, npcId)
  local source = PlayerSources.Loaded()
  if not source then
    return nil
  end
  return PlayerSources.RefiledIn(source, itemId, npcId)
end

--- The name the module states for a source, or nil: n for an npc, o for an object. Pure.
function PlayerSources.ModuleName(source, sourceKind, id)
  local names = nil
  if type(source) == "table" then
    if sourceKind == "npc" then
      names = source.n
    elseif sourceKind == "object" then
      names = source.o
    end
  end
  local name = type(names) == "table" and names[id] or nil
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return name
end

--------------------------------------------------------------------------------
-- An npc nothing of Forever's names: its Classic Era name and side (brief SD1)
--------------------------------------------------------------------------------

-- Brief SD1 (the owner's ruling of 2026-10-15 on the queued data concerns, item 2): players recorded
-- Rann Flamespinner (npc 1474) and Wrahk (npc 3485) selling Coarse, Fine and Rune Thread, and their
-- rows read "Creature 1474" with no zone and no side, so Wrahk showed to the Alliance. Nothing of
-- Forever's names either id (the module's n, the Creatures data, the client's vendor tables), but the
-- shipped Classic Era table names that very creature id (its ci, the CMaNGOS creature id) and states
-- the name's side (cf, joined out of EraPlaces.lua). So a player sourced npc nothing of Forever's
-- names reads its Classic Era name, and a vendor row of that name takes that name's side. The name
-- is what the rest already joins by: Core/Graph.lua's shadow rule folds the Classic Era row of the
-- same name into the player row (its zone and title), and Core/EraSources.lua E:NpcNameAt joins the
-- npc's page to that name's page (its Map tab and pins). Our own data only.

-- The Classic Era reader's table, built on this ask, or with builtOnly only one already built (a
-- namer never loads anything). nil with no reader or no table.
local function eraTable(era, builtOnly)
  local read = era.Table
  if builtOnly then
    read = era._BuiltTable
  end
  if type(read) ~= "function" then
    return nil
  end
  local ok, source = pcall(read, era)
  if ok and type(source) == "table" then
    return source
  end
  return nil
end

--- Brief SD1: the name the shipped Classic Era table states for the creature with this very id
--- (EraSources.CreatureNameIndex, its ci read back) and that name's string index, or nil. builtOnly
--- reads a table already built only. Guarded.
function PlayerSources.EraCreature(npcId, builtOnly)
  local era, EraSources = ItemTree.eraSources, ItemTree.EraSources
  if type(era) ~= "table" or type(EraSources) ~= "table" or type(EraSources.CreatureNameIndex) ~= "function" then
    return nil
  end
  local source = eraTable(era, builtOnly)
  if not source or type(era.NameAt) ~= "function" then
    return nil
  end
  local ok, nameIndex = pcall(EraSources.CreatureNameIndex, source, npcId)
  if not ok or type(nameIndex) ~= "number" then
    return nil
  end
  local named, name = pcall(era.NameAt, era, nameIndex)
  if not named or type(name) ~= "string" or name == "" then
    return nil
  end
  return name, nameIndex
end

-- One guarded call: fn's first answer where fn is a function and does not raise, else nil.
local function call(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, answer = pcall(fn, ...)
  if ok then
    return answer
  end
  return nil
end

-- Whether a data module the build ships (registered, or listed for the data addon) is not built
-- yet, so a reader of built modules alone cannot say what it holds.
local function unbuilt(module)
  if type(Data) ~= "table" or type(module) ~= "string" then
    return false
  end
  if type(Data.cache) == "table" and Data.cache[module] ~= nil then
    return false
  end
  return call(Data.Has, Data, module) == true or call(Data.IsOnDemand, Data, module) == true
end

-- Whether the Forever client's own data may name an npc id: the Creatures data (its creature cache)
-- or the client's vendor tables (Core/ForeverVendors.lua). Each module is built on this ask. With
-- builtOnly one that ships and is not built yet answers true, because it might name the id: a
-- namer's answer is kept for the session (Graph.names), so it must never stand where a Forever name
-- is due. A reader that is not loaded, or a module the build does not ship, names nothing.
local function foreverMayName(npcId, builtOnly)
  local function named(name)
    return type(name) == "string" and name ~= ""
  end
  local creatures = ItemTree.Creatures
  if type(creatures) == "table" then
    if not builtOnly then
      if named(call(creatures.Name, npcId)) then
        return true
      end
    elseif call(creatures.Loaded) ~= nil then
      if named(call(creatures.Namer, Graph.Key("npc", npcId))) then
        return true
      end
    elseif unbuilt(creatures.MODULE) then
      return true
    end
  end
  local vendors = ItemTree.ForeverVendors
  if type(vendors) == "table" then
    local read = vendors.Table
    if builtOnly then
      read = vendors.Loaded
    end
    local source = call(read)
    if source == nil and builtOnly and unbuilt(vendors.MODULE) then
      return true
    end
    if source ~= nil and named(call(vendors.ModuleName, source, npcId)) then
      return true
    end
  end
  return false
end

--- Brief SD1: the name a player sourced npc falls back to where neither the module nor anything of
--- Forever's names it: the Classic Era name of that very creature id (PlayerSources.EraCreature), or
--- nil. builtOnly reads modules already built only. Guarded.
function PlayerSources.FallbackName(npcId, builtOnly)
  if type(npcId) ~= "number" or npcId <= 0 or foreverMayName(npcId, builtOnly) then
    return nil
  end
  return (PlayerSources.EraCreature(npcId, builtOnly))
end

--- Brief SD1: the side the shipped Classic Era table states for the creature a vendor row's npc id
--- is (cf, 1 Alliance, 2 Horde, 3 both), where the row shows that creature's Classic Era name (shown
--- is the name the row is drawn with), or nil: a Forever name of its own that is not that name is
--- another creature as far as we know, and keeps no side. Guarded.
function PlayerSources.EraSide(npcId, shown)
  local name, nameIndex = PlayerSources.EraCreature(npcId)
  if not name or type(shown) ~= "string" or shown:lower() ~= name:lower() then
    return nil
  end
  local era = ItemTree.eraSources
  if type(era.Faction) ~= "function" then
    return nil
  end
  local ok, side = pcall(era.Faction, era, nameIndex)
  if ok and (side == 1 or side == 2 or side == 3) then
    return side
  end
  return nil
end

-- Brief SD1: whether the module states an npc at all (its roles or its spots), the npcs the namer
-- may name by their Classic Era id. Every vendor, giver, ender, trainer and stable master has a k.
local function statesNpc(source, npcId)
  if type(source) ~= "table" then
    return false
  end
  return (type(source.k) == "table" and source.k[npcId] ~= nil)
    or (type(source.p) == "table" and source.p[npcId] ~= nil)
end

--- The namer registered with the graph: the module's own name for npc:<id> or object:<id>, and
--- (brief PS5) its title for quest:<id>. Reads a module already built only, so asking a node its
--- name never loads anything. Brief SD1: an npc the module states and names nowhere, which nothing
--- of Forever's names either, reads its Classic Era name (PlayerSources.FallbackName).
function PlayerSources.Namer(key)
  local kind, id = Graph.Parse(key)
  if type(id) ~= "number" or id <= 0 then
    return nil
  end
  if kind == "quest" then
    return PlayerSources.QuestTitle(PlayerSources.Loaded(), id)
  end
  if kind ~= "npc" and kind ~= "object" then
    return nil
  end
  local source = PlayerSources.Loaded()
  local name = PlayerSources.ModuleName(source, kind, id)
  if name or kind ~= "npc" or not statesNpc(source, id) then
    return name
  end
  return PlayerSources.FallbackName(id, true)
end

--------------------------------------------------------------------------------
-- Quests (brief PS5)
--------------------------------------------------------------------------------

-- A flat list of whole numbers above nought out of a q field, or an empty list.
local function idList(list)
  local out = {}
  for _, value in ipairs(type(list) == "table" and list or EMPTY) do
    value = tonumber(value)
    if value and value > 0 and value == math.floor(value) then
      out[#out + 1] = value
    end
  end
  return out
end

-- The pairs of a flat { a, b, a, b, ... } q field, as { { a, b }, ... } with a above nought; b is
-- nil where it is 0 or not a whole number.
local function pairList(list)
  local out = {}
  list = type(list) == "table" and list or EMPTY
  for index = 1, #list - 1, 2 do
    local first, second = tonumber(list[index]), tonumber(list[index + 1])
    if first and first > 0 and first == math.floor(first) then
      if not second or second <= 0 or second ~= math.floor(second) then
        second = nil
      end
      out[#out + 1] = { first, second }
    end
  end
  return out
end

-- One quest's raw q entry, or nil.
local function questEntry(source, questId)
  local quests = type(source) == "table" and type(source.q) == "table" and source.q or nil
  local entry = quests and type(questId) == "number" and quests[questId] or nil
  if type(entry) ~= "table" then
    return nil
  end
  return entry
end

--- The title the module states for a quest, or nil. Pure.
function PlayerSources.QuestTitle(source, questId)
  local entry = questEntry(source, questId)
  local title = entry and entry.t or nil
  if type(title) ~= "string" or title == "" then
    return nil
  end
  return title
end

--- Brief QN1: a quest's place in a group of same titled quests one giver gives, { c, cl, cs }, cl
--- and cs nil where the entry states none, or nil for a quest the module numbers nowhere. Pure.
function PlayerSources.QuestChain(source, questId)
  local entry = questEntry(source, questId)
  local c = entry and tonumber(entry.c) or nil
  if not c or c < 1 or c ~= math.floor(c) then
    return nil
  end
  local cl = tonumber(entry.cl)
  if not cl or cl < c or cl ~= math.floor(cl) then
    cl = nil
  end
  local cs = entry.cs
  if cs ~= "id" and cs ~= "at" then
    cs = nil
  end
  return { c = c, cl = cl, cs = cs }
end

-- Brief QH1: h's when codes and the words a reader is given (Core/Collector.lua HANDOVER_WORDS).
PlayerSources.HANDOVER_WHEN = { [1] = "accept", [2] = "quest", [3] = "turnin" }
-- h's stride: item, count, when, taken, npc.
local HANDOVER_STRIDE = 5

--- Brief QH1: a q entry's h as { { itemId, count, when, taken, gone, giverNpcId } }, when one of
--- HANDOVER_WHEN's words, taken true (the hand-in took it, code 1), false (left with the player, 2) or
--- nil (not known, 0), gone true (brief IW1, the owner's "2B" bag check: gone before the hand-in, 3,
--- taken then nil), giverNpcId nil but for a mid quest hand-over. A row that does not read is skipped.
--- Pure.
function PlayerSources.Handovers(list)
  local out = {}
  list = type(list) == "table" and list or EMPTY
  for index = 1, #list - HANDOVER_STRIDE + 1, HANDOVER_STRIDE do
    local item, count, when, taken, npc =
      tonumber(list[index]),
      tonumber(list[index + 1]),
      tonumber(list[index + 2]),
      tonumber(list[index + 3]),
      tonumber(list[index + 4])
    local word = when and PlayerSources.HANDOVER_WHEN[when] or nil
    if item and item > 0 and item == math.floor(item) and word then
      local mark = nil
      if taken == 1 then
        mark = true
      elseif taken == 2 then
        mark = false
      end
      out[#out + 1] = {
        itemId = item,
        count = count and count >= 1 and math.floor(count) or 1,
        when = word,
        taken = mark,
        gone = taken == 3 or nil,
        giverNpcId = npc and npc > 0 and npc == math.floor(npc) and npc or nil,
      }
    end
  end
  return out
end

--- One quest decoded: { questId, title, rewards = { itemId, ... }, requires = { { itemId, count },
--- ... }, objectives = { itemId, ... }, givers = { { npcId, uiMap }, ... }, enders = { ... }, c, cl,
--- cs, objectGivers = { { objectId, uiMap }, ... }, objectEnders = { ... }, handovers =
--- (PlayerSources.Handovers) }, count and uiMap nil where the module states none, c, cl and cs
--- (brief QN1) only on a numbered quest; or nil for a quest it says nothing about. Pure.
function PlayerSources.Quest(source, questId)
  local entry = questEntry(source, questId)
  if not entry then
    return nil
  end
  local out = {
    questId = questId,
    title = PlayerSources.QuestTitle(source, questId),
    rewards = idList(entry.r),
    requires = {},
    objectives = idList(entry.o),
    givers = {},
    enders = {},
    -- Brief QH1: world objects that give or take the quest, and what the quest hands over.
    objectGivers = {},
    objectEnders = {},
    handovers = PlayerSources.Handovers(entry.h),
  }
  for _, pair in ipairs(pairList(entry.n)) do
    out.requires[#out.requires + 1] = { itemId = pair[1], count = pair[2] }
  end
  for name, list in pairs({ g = out.givers, e = out.enders }) do
    for _, pair in ipairs(pairList(entry[name])) do
      list[#list + 1] = { npcId = pair[1], uiMap = pair[2] }
    end
  end
  for name, list in pairs({ og = out.objectGivers, oe = out.objectEnders }) do
    for _, pair in ipairs(pairList(entry[name])) do
      list[#list + 1] = { objectId = pair[1], uiMap = pair[2] }
    end
  end
  local chain = PlayerSources.QuestChain(source, questId)
  if chain then
    out.c, out.cl, out.cs = chain.c, chain.cl, chain.cs
  end
  return out
end

--- Whether a quest's q entry names an item in one of the fields asked (r, n or o). Pure.
function PlayerSources.QuestStates(source, questId, fields, itemId)
  local entry = questEntry(source, questId)
  if not entry then
    return false
  end
  for _, name in ipairs(fields) do
    local list = type(entry[name]) == "table" and entry[name] or EMPTY
    local step = name == "n" and 2 or 1
    for index = 1, #list, step do
      if list[index] == itemId then
        return true
      end
    end
  end
  return false
end

--- Every quest fact the module states, the other way round, in one pass:
---
---   { rewardOf = { [itemId] = { questId, ... } }, neededFor = { [itemId] = { { quest, count }, ... } },
---     gives = { [npcId] = { questId, ... } }, takes = { [npcId] = { questId, ... } },
---     handedOverBy = { [itemId] = { { quest, count, when, taken, giverNpcId }, ... } } }
---
--- count nil where the module states none (an objective). Each list in id order. handedOverBy is
--- brief QH1's h read the other way. Pure.
function PlayerSources.QuestIndex(source)
  local index = { rewardOf = {}, neededFor = {}, gives = {}, takes = {}, handedOverBy = {} }
  local function add(map, id, value)
    map[id] = map[id] or {}
    table.insert(map[id], value)
  end
  local ids = {}
  for questId in pairs(type(source) == "table" and type(source.q) == "table" and source.q or EMPTY) do
    if type(questId) == "number" then
      ids[#ids + 1] = questId
    end
  end
  table.sort(ids)
  for _, questId in ipairs(ids) do
    local quest = PlayerSources.Quest(source, questId)
    for _, itemId in ipairs(quest.rewards) do
      add(index.rewardOf, itemId, questId)
    end
    for _, need in ipairs(quest.requires) do
      add(index.neededFor, need.itemId, { quest = questId, count = need.count })
    end
    for _, itemId in ipairs(quest.objectives) do
      add(index.neededFor, itemId, { quest = questId })
    end
    for _, giver in ipairs(quest.givers) do
      add(index.gives, giver.npcId, questId)
    end
    for _, ender in ipairs(quest.enders) do
      add(index.takes, ender.npcId, questId)
    end
    for _, handover in ipairs(quest.handovers) do
      add(index.handedOverBy, handover.itemId, {
        quest = questId,
        count = handover.count,
        when = handover.when,
        taken = handover.taken,
        gone = handover.gone,
        giverNpcId = handover.giverNpcId,
      })
    end
  end
  return index
end

--------------------------------------------------------------------------------
-- Roles (brief PS5)
--------------------------------------------------------------------------------

--- An npc's roles as the bits of k: the module's own k where it states one (schema 2), else what
--- a schema 1 module implies (a vendor row or a vendor spot: a vendor). 0 for none. Pure.
function PlayerSources.RoleBits(source, npcId)
  local roles = type(source) == "table" and type(source.k) == "table" and source.k or nil
  if roles then
    local bits = tonumber(roles[npcId])
    if bits and bits > 0 and bits == math.floor(bits) then
      return bits
    end
    return 0
  end
  if type(source) ~= "table" or type(npcId) ~= "number" then
    return 0
  end
  if type(source.p) == "table" and source.p[npcId] ~= nil then
    return PlayerSources.ROLES.vendor
  end
  for _, list in pairs(type(source.v) == "table" and source.v or EMPTY) do
    for _, sale in ipairs(type(list) == "table" and list or EMPTY) do
      if type(sale) == "table" and sale[1] == npcId then
        return PlayerSources.ROLES.vendor
      end
    end
  end
  return 0
end

-- Whether a bit set holds one bit (Lua 5.1 has no bit operators).
local function hasBit(bits, bit)
  return math.floor(bits / bit) % 2 == 1
end

--- The role words of a bit set, in ROLE_ORDER: { "giver", "trainer" }. Pure.
function PlayerSources.RoleWords(bits)
  local out = {}
  bits = tonumber(bits) or 0
  for _, word in ipairs(PlayerSources.ROLE_ORDER) do
    if hasBit(bits, PlayerSources.ROLES[word]) then
      out[#out + 1] = word
    end
  end
  return out
end

--- What the module says a trainer trains ("Leatherworking"), or nil. Pure.
function PlayerSources.Trains(source, npcId)
  local list = type(source) == "table" and type(source.w) == "table" and source.w or nil
  local word = list and list[npcId] or nil
  if type(word) ~= "string" or word == "" then
    return nil
  end
  return word
end

--------------------------------------------------------------------------------
-- Brief TW1: what a trainer teaches in Forever (owner QA 2026-10-18, item 242)
--------------------------------------------------------------------------------

-- tl, optional (ItemTree-Data player_sources.py, docs/mining.md "Shipped player sources"): the
-- class trainer lists the owner's own visits recorded (the Collector's trainer lists, a developer
-- checkout's), ONE LIST PER CLASS (the owner's ruling "A" of 2026-10-18: a list recorded at one
-- trainer shows on every trainer of that class, both factions); never a profession trainer's,
-- which waits on the owner's ruling:
--   tl = { c = { [classId] = { spell, level, rank, skill, skillRank, cost, spell, ... } },
--          f = { [classId] = 1 }, n = { [npcId] = classId } }
-- six whole numbers a spell in spell id order (0 for none; a cost read at a discount is shipped as
-- 0), f 1 where a read with every filter on listed the class whole on the newest build that read
-- it (so a spell it does not hold is one no trainer of the class teaches any more), n the class of
-- every trainer whose reads made a list.
PlayerSources.TRAINER_LIST_FIELDS = 6

-- Decoded lists, per module table and class, held weakly by the table.
local classLists = setmetatable({}, { __mode = "k" })

--- The list the recorded visits make for one class, { classId, complete, spells = { { spell,
--- level, rank, skill, skillRank, cost }, ... } } in spell id order, or nil where the module ships
--- none for it (a module before brief TW1 ships no tl at all). Kept per class and shared by every
--- trainer of the class: read it, never write it. Pure over the table handed in.
function PlayerSources.ClassList(source, classId)
  local tl = type(source) == "table" and type(source.tl) == "table" and source.tl or nil
  if not tl or type(tl.c) ~= "table" or type(classId) ~= "number" then
    return nil
  end
  local packed = tl.c[classId]
  if type(packed) ~= "table" or #packed == 0 or #packed % PlayerSources.TRAINER_LIST_FIELDS ~= 0 then
    return nil
  end
  local held = classLists[source]
  if not held then
    held = {}
    classLists[source] = held
  end
  if held[classId] then
    return held[classId]
  end
  local spells = {}
  for at = 1, #packed, PlayerSources.TRAINER_LIST_FIELDS do
    local spellId = tonumber(packed[at])
    if spellId and spellId > 0 then
      local spell = { spell = spellId }
      spell.level = math.max(0, tonumber(packed[at + 1]) or 0)
      spell.rank = math.max(0, tonumber(packed[at + 2]) or 0)
      spell.skill = math.max(0, tonumber(packed[at + 3]) or 0)
      spell.skillRank = math.max(0, tonumber(packed[at + 4]) or 0)
      spell.cost = math.max(0, tonumber(packed[at + 5]) or 0)
      spells[#spells + 1] = spell
    end
  end
  local answer = {
    classId = classId,
    complete = type(tl.f) == "table" and tl.f[classId] == 1,
    spells = spells,
  }
  held[classId] = answer
  return answer
end

-- Brief TW3 (the owner's ruling "A" carried over, 2026-10-18): beside the classes' lists, the pet
-- trainers' ONE list, which every pet trainer shows (Classic's pet trainers all teach the same
-- abilities): tl.p = { spell, level, rank, skill, skillRank, cost, ... } in the same six numbers a
-- spell, tl.pf = 1 where a read with every filter on listed it whole, tl.pn = { [npcId] = 1 } the pet
-- trainers whose reads made it. The class whose players open a pet trainer's window is the hunter's.
PlayerSources.PET_CLASS = 3

--- The pet trainers' list, { pet = true, classId = PET_CLASS, complete, spells = { { spell, level,
--- rank, skill, skillRank, cost }, ... } } in spell id order, or nil where the module ships none.
--- Kept per module and shared by every pet trainer: read it, never write it. Pure over the table.
function PlayerSources.PetList(source)
  local tl = type(source) == "table" and type(source.tl) == "table" and source.tl or nil
  local packed = tl and tl.p or nil
  if type(packed) ~= "table" or #packed == 0 or #packed % PlayerSources.TRAINER_LIST_FIELDS ~= 0 then
    return nil
  end
  local held = classLists[source]
  if not held then
    held = {}
    classLists[source] = held
  end
  if held.pet then
    return held.pet
  end
  local spells = {}
  for at = 1, #packed, PlayerSources.TRAINER_LIST_FIELDS do
    local spellId = tonumber(packed[at])
    if spellId and spellId > 0 then
      spells[#spells + 1] = {
        spell = spellId,
        level = math.max(0, tonumber(packed[at + 1]) or 0),
        rank = math.max(0, tonumber(packed[at + 2]) or 0),
        skill = math.max(0, tonumber(packed[at + 3]) or 0),
        skillRank = math.max(0, tonumber(packed[at + 4]) or 0),
        cost = math.max(0, tonumber(packed[at + 5]) or 0),
      }
    end
  end
  local answer = { pet = true, classId = PlayerSources.PET_CLASS, complete = tl.pf == 1, spells = spells }
  held.pet = answer
  return answer
end

--- Whether the module names this npc a pet trainer whose reads made the pet list (tl's pn). Pure.
function PlayerSources.RecordedPetTrainer(source, npcId)
  local tl = type(source) == "table" and type(source.tl) == "table" and source.tl or nil
  return tl ~= nil and type(tl.pn) == "table" and type(npcId) == "number" and tl.pn[npcId] == 1
end

--- The class a recorded trainer's reads were for (tl's n), or nil. Pure.
function PlayerSources.RecordedClass(source, npcId)
  local tl = type(source) == "table" and type(source.tl) == "table" and source.tl or nil
  local classId = tl and type(tl.n) == "table" and tl.n[npcId] or nil
  if type(classId) == "number" and classId > 0 and classId == math.floor(classId) then
    return classId
  end
  return nil
end

--------------------------------------------------------------------------------
-- The reverse index: what one container, disenchanted item or npc gives
--------------------------------------------------------------------------------

--- { items = { [sourceItemId] = { { section, itemId }, ... } }, npcs = { [npcId] = { drops =
--- { itemIds }, sells = { itemIds }, taken = { { section, itemId }, ... } } } } over the whole
--- module in one pass. taken (brief SK1) is what was skinned or pickpocketed off the npc (sections 7
--- and 8), present only where there is some. Pure. Brief RB4: check, where given, is called once per
--- item (Core/Data.lua Data.SliceCheck), so the login slicer carries the pass over frames (about 9 ms
--- over the shipped 1.60.1.70425 data offline, the slicer's longest tick before).
function PlayerSources.ReverseIndex(source, check)
  local items, npcs = {}, {}
  local function npc(id)
    local held = npcs[id]
    if not held then
      held = { drops = {}, sells = {} }
      npcs[id] = held
    end
    return held
  end
  for itemId in pairs(type(source) == "table" and type(source.r) == "table" and source.r or EMPTY) do
    if check then
      check()
    end
    if type(itemId) == "number" then
      for _, row in ipairs(PlayerSources.Rows(source, itemId)) do
        if row.sourceKind == "item" and PlayerSources.SECTIONS[row.section].down then
          items[row.sourceId] = items[row.sourceId] or {}
          table.insert(items[row.sourceId], { section = row.section, itemId = itemId })
        elseif row.sourceKind == "npc" and row.section == 1 then
          table.insert(npc(row.sourceId).drops, itemId)
        elseif row.sourceKind == "npc" and PlayerSources.SECTIONS[row.section].npc then
          local held = npc(row.sourceId)
          held.taken = held.taken or {}
          table.insert(held.taken, { section = row.section, itemId = itemId })
        end
      end
    end
  end
  for itemId in pairs(type(source) == "table" and type(source.v) == "table" and source.v or EMPTY) do
    if check then
      check()
    end
    if type(itemId) == "number" then
      for _, sale in ipairs(PlayerSources.Sales(source, itemId)) do
        table.insert(npc(sale.npcId).sells, itemId)
      end
    end
  end
  for _, list in pairs(items) do
    table.sort(list, function(a, b)
      return a.itemId < b.itemId
    end)
  end
  for _, held in pairs(npcs) do
    table.sort(held.drops)
    table.sort(held.sells)
    if held.taken then
      table.sort(held.taken, function(a, b)
        if a.itemId ~= b.itemId then
          return a.itemId < b.itemId
        end
        return a.section < b.section
      end)
    end
  end
  return { items = items, npcs = npcs }
end

local reverseFor, reverseOf = nil, nil
-- Brief PS2: the zone map index (PlayerSources.MapRows, below), kept the same way.
local mapsFor, mapsOf = nil, nil
-- Brief PS5: the quest index (PlayerSources.QuestIndex), kept the same way, per module table.
local questsFor, questsOf = nil, nil

-- The quest index of a module table, built on the first ask for that table and kept. A module with
-- no q (schema 1) builds an empty one for nothing.
local function questIndexOf(source)
  if type(source) ~= "table" then
    return nil
  end
  if questsFor ~= source then
    questsOf = PlayerSources.QuestIndex(source)
    questsFor = source
  end
  return questsOf
end

--- The reverse index, built once per module table and kept, or nil where no module ships. Only a
--- container's, a disenchanted item's or an npc's page asks for it.
function PlayerSources.Reverse()
  local source = PlayerSources.Table()
  if not source then
    return nil
  end
  if reverseFor ~= source then
    -- Brief RB4: built behind the loading screen (Core/Data.lua Data.PRELOAD_LOADING_SCREEN), else
    -- carried over frames by the login slicer (Data.SliceCheck).
    local built = PlayerSources.ReverseIndex(source, type(Data) == "table" and Data.SliceCheck or nil)
    -- A caller that built the index whole while the slicer's pass was paused keeps its own.
    if reverseFor == source then
      return reverseOf
    end
    reverseOf = built
    reverseFor = source
    PlayerSources.reverseBuilds = PlayerSources.reverseBuilds + 1
  end
  return reverseOf
end

--- Brief RB4: the quest index of the shipped module (PlayerSources.QuestIndex), built now where it is
--- not built yet, for the loading screen's builds (Core/Data.lua Data.PRELOAD_LOADING_SCREEN): the
--- first creature and item pages read it (about 2.5 ms over the shipped 1.60.1.70425 data offline).
--- Answers the index, or nil where no module ships.
function PlayerSources.WarmQuestIndex()
  local source = PlayerSources.Table()
  if type(source) ~= "table" or source.q == nil then
    return nil
  end
  return questIndexOf(source)
end

--- Drops the kept reverse index and zone map index (a spec that swaps the table).
function PlayerSources.Reset()
  reverseFor, reverseOf = nil, nil
  mapsFor, mapsOf = nil, nil
  questsFor, questsOf = nil, nil
  PlayerSources.reverseBuilds = 0
end

--------------------------------------------------------------------------------
-- Places: a vendor's spot, as the Map tab pins it
--------------------------------------------------------------------------------

--- The centre of one 1 percent cell in map percent, or nil. Pure.
function PlayerSources.CellCentre(cell)
  cell = tonumber(cell)
  if not cell or cell < 0 or cell > 9999 or cell ~= math.floor(cell) then
    return nil
  end
  return math.floor(cell / 100) + 0.5, cell % 100 + 0.5
end

--- One npc's spots: { { map, cells = { { cell, count }, ... } }, ... }, densest first as shipped,
--- or an empty list. Pure.
function PlayerSources.Spots(source, npcId)
  local out = {}
  local list = type(source) == "table" and type(source.p) == "table" and source.p[npcId] or nil
  for _, spot in ipairs(type(list) == "table" and list or EMPTY) do
    local map = type(spot) == "table" and field(spot, 1) or 0
    if map > 0 then
      local cells = {}
      for index = 2, #spot - 1, 2 do
        local cell, count = tonumber(spot[index]), field(spot, index + 1)
        if PlayerSources.CellCentre(cell) and count > 0 then
          cells[#cells + 1] = { cell = cell, count = count }
        end
      end
      if #cells > 0 then
        out[#out + 1] = { map = map, cells = cells }
      end
    end
  end
  return out
end

--- The pins an npc's Map tab draws for its spots: { map, x, y, zone, name, players = true }, one per
--- cell, x and y the cell's centre in percent (a place ships as cells, never as a made up exact
--- point). zoneOf(map) names a map, or nil. Pure over what it is handed.
function PlayerSources.Positions(spots, name, zoneOf)
  local out = {}
  for _, spot in ipairs(type(spots) == "table" and spots or EMPTY) do
    local zone = type(zoneOf) == "function" and zoneOf(spot.map) or nil
    for _, cell in ipairs(spot.cells) do
      local x, y = PlayerSources.CellCentre(cell.cell)
      out[#out + 1] = { map = spot.map, x = x, y = y, zone = zone, name = name, seen = false, players = true }
    end
  end
  return out
end

--------------------------------------------------------------------------------
-- Zones: what the module states on one zone map (brief PS2)
--------------------------------------------------------------------------------

-- The section codes whose source a zone's Here tab can list where the module places it: a drop and
-- a gathering row. A container or a disenchant names an item, which stands nowhere.
local ZONE_SECTIONS = { [1] = true, [2] = true }

-- The zone maps one npc's spots stand on, as a set, or nil where the module places it nowhere.
local function spotMaps(source, npcId)
  local maps = nil
  for _, spot in ipairs(PlayerSources.Spots(source, npcId)) do
    maps = maps or {}
    maps[spot.map] = true
  end
  return maps
end

local function byItemThenSource(a, b)
  if a.itemId ~= b.itemId then
    return a.itemId < b.itemId
  end
  if a.kind ~= b.kind then
    return a.kind < b.kind
  end
  return a.sourceId < b.sourceId
end

--- Every row the module places on a zone map, by uiMap, in one pass over the module:
---
---   { [uiMap] = { { kind, itemId, sourceKind, sourceId, sale }, ... } }
---
--- kind is the collector's word ("vendor", "drop" or "gather"), sale the decoded vendor row
--- (PlayerSources.Sales) on a vendor row and nil on the others. A vendor row stands on the uiMap the
--- sale states, else on every map the vendor's spots stand on. A drop or gathering row stands on the
--- maps its npc's spots stand on; an object, which the module places nowhere, and a row whose
--- source has no spot stand on no map at all (nothing guesses a zone). In item order. Pure.
function PlayerSources.MapIndex(source)
  local out = {}
  local function add(map, row)
    out[map] = out[map] or {}
    table.insert(out[map], row)
  end
  local spotsOf = {}
  local function npcMaps(npcId)
    local held = spotsOf[npcId]
    if held == nil then
      held = spotMaps(source, npcId) or false
      spotsOf[npcId] = held
    end
    return held or EMPTY
  end
  for itemId in pairs(type(source) == "table" and type(source.v) == "table" and source.v or EMPTY) do
    if type(itemId) == "number" then
      for _, sale in ipairs(PlayerSources.Sales(source, itemId)) do
        local row = {
          kind = PlayerSources.VENDOR_KIND,
          itemId = itemId,
          sourceKind = "npc",
          sourceId = sale.npcId,
          sale = sale,
        }
        if sale.uiMap then
          add(sale.uiMap, row)
        else
          for map in pairs(npcMaps(sale.npcId)) do
            add(map, row)
          end
        end
      end
    end
  end
  for itemId in pairs(type(source) == "table" and type(source.r) == "table" and source.r or EMPTY) do
    if type(itemId) == "number" then
      for _, row in ipairs(PlayerSources.Rows(source, itemId)) do
        if ZONE_SECTIONS[row.section] and row.sourceKind == "npc" then
          for map in pairs(npcMaps(row.sourceId)) do
            add(map, { kind = row.kind, itemId = itemId, sourceKind = "npc", sourceId = row.sourceId })
          end
        end
      end
    end
  end
  for _, rows in pairs(out) do
    table.sort(rows, byItemThenSource)
  end
  return out
end

--- The rows the module places on one zone map (PlayerSources.MapIndex), or an empty list where no
--- module ships or it places nothing there. The index is built once per module table, on the first
--- zone page that asks, and kept. Builds the module (a zone page is a view).
function PlayerSources.MapRows(uiMap)
  local source = PlayerSources.Table()
  if not source or type(uiMap) ~= "number" then
    return EMPTY
  end
  if mapsFor ~= source then
    mapsOf = PlayerSources.MapIndex(source)
    mapsFor = source
  end
  return mapsOf[uiMap] or EMPTY
end

--- The name a zone row gives a module row's source: the module's own, else (an npc) the Creatures
--- data's, else the name the graph already holds, or nil. Reads a module already built.
function PlayerSources.SourceName(sourceKind, id)
  local name = PlayerSources.ModuleName(PlayerSources.Loaded(), sourceKind, id)
  if not name and sourceKind == "npc" then
    local creatures = ItemTree.Creatures
    if type(creatures) == "table" and type(creatures.Name) == "function" then
      local ok, answer = pcall(creatures.Name, id)
      name = ok and type(answer) == "string" and answer ~= "" and answer or nil
    end
  end
  if not name then
    local held = Graph.Name(Graph.Key(sourceKind, id))
    name = type(held) == "string" and held ~= "" and held or nil
  end
  return name
end

--------------------------------------------------------------------------------
-- Edges
--------------------------------------------------------------------------------

local function collector()
  local instance = ItemTree.collector
  if type(instance) ~= "table" then
    return nil
  end
  return instance
end

-- Whether the player's own records state this fact (Core/Collector.lua C:HasFact). Such a fact is
-- the collector's row, so this provider draws nothing for it.
local function ownFact(kind, itemId, sourceKind, sourceId)
  local instance = collector()
  if not instance or type(instance.HasFact) ~= "function" then
    return false
  end
  -- Brief ST7: a collector whose provider is out of the graph (the self test's mask) draws no
  -- row, so a shipped fact must not be held back on its account.
  local provider = instance.provider
  if type(provider) == "function" and type(Graph.HasProvider) == "function" and not Graph.HasProvider(provider) then
    return false
  end
  local ok, answer = pcall(instance.HasFact, instance, kind, itemId, sourceKind, sourceId)
  return ok and answer == true
end

-- A map's words, through the collector's guarded client read (Collector.MapName), or nil.
function PlayerSources.MapName(uiMap)
  local Collector = ItemTree.Collector
  if type(uiMap) ~= "number" or type(Collector) ~= "table" or type(Collector.MapName) ~= "function" then
    return nil
  end
  local ok, name = pcall(Collector.MapName, uiMap)
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- Puts a name on the graph for a source node nothing on this client names yet: the module's own,
-- else (a creature) the Creatures data's, else (brief SD1) the Classic Era name of its id. A name
-- something already holds wins.
local function nameSource(source, sourceKind, id, target)
  if Graph.names[target] ~= nil then
    return
  end
  local name = PlayerSources.ModuleName(source, sourceKind, id)
  if not name and sourceKind == "npc" then
    local creatures = ItemTree.Creatures
    if type(creatures) == "table" and type(creatures.Name) == "function" then
      local ok, answer = pcall(creatures.Name, id)
      name = ok and type(answer) == "string" and answer ~= "" and answer or nil
    end
  end
  -- Brief SD1: last, the Classic Era name of this very creature id, where nothing of Forever's
  -- names it (Rann Flamespinner, npc 1474, read "Creature 1474").
  if not name and sourceKind == "npc" then
    name = PlayerSources.FallbackName(id)
  end
  if name then
    Graph.SetName(target, name)
  end
end

-- Brief PS5: puts the module's title on a quest node nothing on this client names yet.
local function nameQuest(source, questId, target)
  if Graph.names[target] ~= nil then
    return
  end
  local title = PlayerSources.QuestTitle(source, questId)
  if title then
    Graph.SetName(target, title)
  end
end

local function edge(spec, target, extra)
  local out = {
    type = spec.edge,
    target = target,
    group = spec.group,
    confidence = Confidence.MINED,
    provenance = PlayerSources.PROVENANCE,
    -- Brief SK1: a pickpocket row (section 8), kept apart from a drop of the same creature.
    pocket = spec.pocket,
  }
  for key, value in pairs(extra or EMPTY) do
    out[key] = value
  end
  return out
end

-- A sale's price, cost and zone, as a Sold by or Sells edge carries them, and (brief QN1) the side
-- PlayerSources.SaleSide lets it state: a faction where the place proves it, else the side of the
-- players who saw it, which UI/Tree.lua words as one muted tooltip line. Brief SD1: where the place
-- proves no side, the side the Classic Era table states for the vendor the row names by its Classic
-- Era name (PlayerSources.EraSide), so "Hide other faction data" hides Wrahk from the Alliance.
local function saleFields(sale)
  local faction, seen = PlayerSources.SaleSide(sale)
  if faction == nil then
    faction = PlayerSources.EraSide(sale.npcId, Graph.Name(Graph.Key("npc", sale.npcId)))
  end
  return {
    price = sale.copper,
    cost = sale.cost,
    zone = PlayerSources.MapName(sale.uiMap),
    faction = faction,
    seenSide = seen,
  }
end

--- The up edges one item's rows stand for, every row the player's own records do not already state:
--- its drops, gathering, containers and disenchants, then a Sold by edge per vendor. Pure over the
--- table handed in, the collector and the graph's names.
function PlayerSources.ItemEdges(source, itemId)
  local out = {}
  for _, row in ipairs(PlayerSources.Rows(source, itemId)) do
    if not ownFact(row.kind, itemId, row.sourceKind, row.sourceId) then
      local target = Graph.Key(row.sourceKind, row.sourceId)
      nameSource(source, row.sourceKind, row.sourceId, target)
      out[#out + 1] = edge(PlayerSources.SECTIONS[row.section].up, target)
    end
  end
  local sold = { edge = T.SOLD_BY, group = L["Sold by"] }
  for _, sale in ipairs(PlayerSources.Sales(source, itemId)) do
    if not ownFact(PlayerSources.VENDOR_KIND, itemId, "npc", sale.npcId) then
      local target = Graph.Key("npc", sale.npcId)
      nameSource(source, "npc", sale.npcId, target)
      out[#out + 1] = edge(sold, target, saleFields(sale))
    end
  end
  -- Brief PS5: the quests that hand it over, filed under Quests as the collector's own are.
  local quests = source.q and questIndexOf(source) or nil
  local reward = { edge = T.QUEST_REWARD, group = L["Quests"] }
  local rewarded = {}
  for _, questId in ipairs(quests and quests.rewardOf[itemId] or EMPTY) do
    rewarded[questId] = true
    if not ownFact("quest_reward", itemId, "quest", questId) then
      local target = Graph.Key("quest", questId)
      nameQuest(source, questId, target)
      out[#out + 1] = edge(reward, target)
    end
  end
  -- Brief IW1 (QH1's hand-overs on the item page, the owner's QA item 375): the quests the records say
  -- hand the item over at the accept or mid quest (PlayerSources.ProvidedQuestsIn), the Sources tab's
  -- "Provided by quest" rows (Core/Edges.lua QUEST_PROVIDED) under Quests, one per quest, a quest a
  -- reward row above names not again. The player's own record is verified, as the collector's own rows
  -- are; one the module ships is plain with the "player" provenance. Either outranks the predicted row
  -- of the same quest (Core/QuestsPredicted.lua EdgesFor) in the graph's merge, so a record of ours
  -- always wins the row.
  local provided = { edge = T.QUEST_PROVIDED, group = L["Quests"] }
  for _, entry in ipairs(PlayerSources.ProvidedQuestsIn(source, itemId)) do
    if not rewarded[entry.questId] then
      local target = Graph.Key("quest", entry.questId)
      nameQuest(source, entry.questId, target)
      local row = edge(provided, target)
      if entry.own then
        row.confidence = Confidence.VERIFIED
        row.provenance = nil
      end
      out[#out + 1] = row
    end
  end
  return out
end

--- Brief PS5: the quests that ask for an item, with the count each states: QUEST_OBJECTIVE edges
--- under Quests, the player's own record of the same fact left to the collector. Pure over the
--- table handed in, the collector and the graph's names.
function PlayerSources.ItemQuestEdges(source, itemId)
  local out = {}
  local quests = type(source) == "table" and source.q and questIndexOf(source) or nil
  local needed = { edge = T.QUEST_OBJECTIVE, group = L["Quests"] }
  for _, need in ipairs(quests and quests.neededFor[itemId] or EMPTY) do
    local kind = need.count and "quest_requires" or "quest_objective"
    if not ownFact(kind, itemId, "quest", need.quest) then
      local target = Graph.Key("quest", need.quest)
      nameQuest(source, need.quest, target)
      out[#out + 1] = edge(needed, target, { quantity = need.count })
    end
  end
  return out
end

--- Brief CT1b (QA item 228): the quests the module states ask for an item, as quest ids in the
--- module's order, out of the quest index PlayerSources.ItemQuestEdges reads (Core/Graph.lua
--- Graph.Summary counts them; a quest the player's own records state too is counted once there).
--- Read only where the module is built already (PlayerSources.Loaded), so a tooltip never builds it:
--- the loading screen does where item data loads at login (Core/Data.lua), else the first page's
--- walk, which an item page's counts make before its summary line. Empty otherwise.
function PlayerSources.ItemQuestNeeds(itemId)
  local out = {}
  local source = PlayerSources.Loaded()
  local quests = type(source) == "table" and source.q and questIndexOf(source) or nil
  for _, need in ipairs(quests and quests.neededFor[itemId] or EMPTY) do
    out[#out + 1] = need.quest
  end
  return out
end

--- Brief PS5: what one quest asks for, as QUEST_REQUIRES edges under Requires with the count each
--- states (an objective item states none). Pure over the table handed in and the collector.
function PlayerSources.QuestRequireEdges(source, questId)
  local out = {}
  local quest = PlayerSources.Quest(source, questId)
  if not quest then
    return out
  end
  local requires = { edge = T.QUEST_REQUIRES, group = L["Requires"] }
  for _, need in ipairs(quest.requires) do
    if not ownFact("quest_requires", need.itemId, "quest", questId) then
      out[#out + 1] = edge(requires, Graph.Key("item", need.itemId), { quantity = need.count })
    end
  end
  for _, itemId in ipairs(quest.objectives) do
    if not ownFact("quest_objective", itemId, "quest", questId) then
      out[#out + 1] = edge(requires, Graph.Key("item", itemId))
    end
  end
  return out
end

--- Brief SD1 (the owner's ruling of 2026-10-15, item 3: Tough Wolf Meat's quest 33 drew its rewards
--- 80 and 6070 Predicted in Used by and plain everywhere else, "fix it to not show if its been
--- properly recorded"): what one quest hands over as the module states it, QUEST_REWARDS edges under
--- Rewards, plain data like the item's own Quest reward row (PlayerSources.ItemEdges) and the quest
--- page's Rewards (Core/ViewModel.lua ViewModel.Quest, "players"). The graph keeps the more trusted
--- of two edges to one item, so a Classic Era reward the module states is this row, unmarked, as the
--- client's quest cache confirms one (Core/QuestFlags.lua). The collector draws no edge this way for
--- the player's own record, so every reward the module states is drawn. Pure over the table handed in.
function PlayerSources.QuestRewardEdges(source, questId)
  local out = {}
  local quest = PlayerSources.Quest(source, questId)
  if not quest then
    return out
  end
  local rewards = { edge = T.QUEST_REWARDS, group = L["Rewards"] }
  for _, itemId in ipairs(quest.rewards) do
    out[#out + 1] = edge(rewards, Graph.Key("item", itemId))
  end
  return out
end

--- The down edges of an item that is a container or is disenchanted: Contains and Disenchants into,
--- from the reverse index. Builds the index.
function PlayerSources.ItemDownEdges(itemId)
  local out = {}
  local reverse = PlayerSources.Reverse()
  for _, entry in ipairs(reverse and reverse.items[itemId] or EMPTY) do
    local section = PlayerSources.SECTIONS[entry.section]
    if section.down and not ownFact(section.kind, entry.itemId, "item", itemId) then
      out[#out + 1] = edge(section.down, Graph.Key("item", entry.itemId))
    end
  end
  return out
end

-- Brief PS5: the Quests tab's two sides, as the Classic Era table files them (Core/EraSources.lua
-- QUEST_GIVER_SIDES), so one quest both state is one row.
local QUEST_SIDES = {
  { list = "gives", spec = { edge = T.GIVES_QUEST, group = L["Starts"] } },
  { list = "takes", spec = { edge = T.TAKES_QUEST, group = L["Ends"] } },
}

-- Brief PS5: the quests one npc starts and ends, as Starts and Ends edges to each quest, named.
local function npcQuestEdges(source, npcId, out)
  local quests = type(source) == "table" and source.q and questIndexOf(source) or nil
  for _, side in ipairs(QUEST_SIDES) do
    for _, questId in ipairs(quests and quests[side.list][npcId] or EMPTY) do
      local target = Graph.Key("quest", questId)
      nameQuest(source, questId, target)
      out[#out + 1] = edge(side.spec, target)
    end
  end
  return out
end

--- An npc's down edges: Drops for its drop rows and Sells for its vendor rows, each with the sale's
--- price, and (brief PS5) Starts and Ends for the quests it gives and takes back. Builds the index.
function PlayerSources.NpcEdges(npcId)
  local out = {}
  local source = PlayerSources.Table()
  npcQuestEdges(source, npcId, out)
  local reverse = PlayerSources.Reverse()
  local held = reverse and reverse.npcs[npcId] or nil
  if not held then
    return out
  end
  for _, itemId in ipairs(held.drops) do
    if not ownFact("drop", itemId, "npc", npcId) then
      out[#out + 1] = edge(PlayerSources.SECTIONS[1].npc, Graph.Key("item", itemId))
    end
  end
  -- Brief SK1: Skinned and Pickpocketed, beside its Drops under the Loot tab.
  for _, entry in ipairs(held.taken or EMPTY) do
    local section = PlayerSources.SECTIONS[entry.section]
    if not ownFact(section.kind, entry.itemId, "npc", npcId) then
      out[#out + 1] = edge(section.npc, Graph.Key("item", entry.itemId))
    end
  end
  local sells = { edge = T.SELLS, group = L["Sells"] }
  for _, itemId in ipairs(held.sells) do
    if not ownFact(PlayerSources.VENDOR_KIND, itemId, "npc", npcId) then
      for _, sale in ipairs(PlayerSources.Sales(source, itemId)) do
        if sale.npcId == npcId then
          out[#out + 1] = edge(sells, Graph.Key("item", itemId), saleFields(sale))
          break
        end
      end
    end
  end
  return out
end

-- The npc id a key names, where it is a real one (npc:<id>, id above nought), or nil.
local function npcIdOf(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "npc" or type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then
    return nil
  end
  return id
end

--- What the module says about an npc key, for its page's tabs (Core/ViewModel.lua ViewsFor), its
--- header (UI/InfoPanel.lua) and its Map tab (UI/Map.lua):
---
---   { npcId, name, drops, sells, spots, positions, starts, ends, roles = { "giver", ... }, trains }
---
--- or nil for a key it states nothing about. starts and ends count the quests it gives and takes
--- back, roles are its role words in PlayerSources.ROLE_ORDER and trains what a trainer trains
--- (brief PS5). A pin of an npc that is not a vendor carries talked = true, so the Map tab says
--- players talked to it rather than opened it. Loads the module (an npc page is one of its first
--- needs); a made up key (a Classic Era name's node) never asks.
function PlayerSources.NpcFacts(key)
  local npcId = npcIdOf(key)
  if not npcId then
    return nil
  end
  local source = PlayerSources.Table()
  local reverse = source and PlayerSources.Reverse() or nil
  local held = reverse and reverse.npcs[npcId] or nil
  local spots = PlayerSources.Spots(source, npcId)
  local quests = source and source.q and questIndexOf(source) or nil
  local starts = quests and quests.gives[npcId] and #quests.gives[npcId] or 0
  local ends = quests and quests.takes[npcId] and #quests.takes[npcId] or 0
  local bits = source and PlayerSources.RoleBits(source, npcId) or 0
  if not held and #spots == 0 and starts + ends == 0 and bits == 0 then
    return nil
  end
  -- Brief SD1: the page names its npc the way its rows do (nameSource), so a vendor nothing of
  -- Forever's names reads its Classic Era name in the page header too.
  nameSource(source, "npc", npcId, key)
  local name = Graph.Name(key) or PlayerSources.ModuleName(source, "npc", npcId)
  local positions = PlayerSources.Positions(spots, name, PlayerSources.MapName)
  local vendor = hasBit(bits, PlayerSources.ROLES.vendor) or (held ~= nil and #held.sells > 0)
  if not vendor then
    for _, pin in ipairs(positions) do
      pin.talked = true
    end
  end
  return {
    npcId = npcId,
    name = name,
    -- Brief SK1: what was skinned or pickpocketed off it is loot on its page too.
    drops = held and (#held.drops + #(held.taken or EMPTY)) or 0,
    sells = held and #held.sells or 0,
    spots = #spots,
    positions = positions,
    starts = starts,
    ends = ends,
    roles = PlayerSources.RoleWords(bits),
    trains = PlayerSources.Trains(source, npcId),
  }
end

--- Brief PS5, for the Pets and Professions panels: every npc the module gives one role ("vendor",
--- "giver", "ender", "trainer" or "stable"), in id order:
---
---   { { npcId, name, roles = { words }, trains, spots = { { map, cells = { { cell, count } } } } }, ... }
---
--- name is the module's own, else the Creatures data's, else nil; trains is what a trainer trains
--- or nil; spots as PlayerSources.Spots answers them. An empty list for an unknown role or where no
--- module ships. Builds the module (a panel that asks is a view). Read only: the tables are fresh.
function PlayerSources.NpcsWithRole(role)
  local out = {}
  local bit = type(role) == "string" and PlayerSources.ROLES[role] or nil
  local source = bit and PlayerSources.Table() or nil
  if not source then
    return out
  end
  local ids, seen = {}, {}
  local function consider(npcId)
    if type(npcId) == "number" and not seen[npcId] then
      seen[npcId] = true
      if hasBit(PlayerSources.RoleBits(source, npcId), bit) then
        ids[#ids + 1] = npcId
      end
    end
  end
  if type(source.k) == "table" then
    for npcId in pairs(source.k) do
      consider(npcId)
    end
  elseif bit == PlayerSources.ROLES.vendor then
    for npcId in pairs(type(source.p) == "table" and source.p or EMPTY) do
      consider(npcId)
    end
    for _, list in pairs(source.v) do
      for _, sale in ipairs(type(list) == "table" and list or EMPTY) do
        consider(type(sale) == "table" and sale[1] or nil)
      end
    end
  end
  table.sort(ids)
  for _, npcId in ipairs(ids) do
    out[#out + 1] = {
      npcId = npcId,
      name = PlayerSources.SourceName("npc", npcId),
      roles = PlayerSources.RoleWords(PlayerSources.RoleBits(source, npcId)),
      trains = PlayerSources.Trains(source, npcId),
      spots = PlayerSources.Spots(source, npcId),
    }
  end
  return out
end

--- Where an npc stood for players on one uiMap: the centre of its densest cell there, x and y in
--- map percent, or nil where the module places it nowhere on that map. Pure.
function PlayerSources.SpotOn(source, npcId, uiMap)
  for _, spot in ipairs(PlayerSources.Spots(source, npcId)) do
    if spot.map == uiMap or uiMap == nil then
      return spot.map, PlayerSources.CellCentre(spot.cells[1].cell)
    end
  end
  return nil
end

--- Brief PS5: what the module says about one quest, for its page (Core/ViewModel.lua
--- ViewModel.Quest):
---
---   { questId, title, rewards = { itemId, ... }, givers = { npc, ... }, enders = { npc, ... } }
---
--- c, cl and cs (brief QN1) where the module numbers the quest among a giver's same titled ones;
--- each npc { key, npcId, name, mapId, x, y, zone, players = true }: mapId the uiMap it was met on
--- (else the map of its first spot), x and y its densest cell's centre on that map where the module
--- places it, zone that map's words. nil for a quest the module says nothing about or with no
--- module. Builds the module (a quest page is a view).
function PlayerSources.QuestFacts(questId)
  local source = PlayerSources.Table()
  local quest = source and PlayerSources.Quest(source, questId) or nil
  if not quest then
    return nil
  end
  local out = {
    questId = questId,
    title = quest.title,
    rewards = quest.rewards,
    givers = {},
    enders = {},
    c = quest.c,
    cl = quest.cl,
    cs = quest.cs,
    -- Brief QH1: what the quest handed over (PlayerSources.Handovers' shape).
    handovers = quest.handovers,
  }
  for side, list in pairs({ givers = quest.givers, enders = quest.enders }) do
    for _, npc in ipairs(list) do
      local key = Graph.Key("npc", npc.npcId)
      nameSource(source, "npc", npc.npcId, key)
      local map, x, y = PlayerSources.SpotOn(source, npc.npcId, npc.uiMap)
      if not map and not npc.uiMap then
        map, x, y = PlayerSources.SpotOn(source, npc.npcId, nil)
      end
      local mapId = npc.uiMap or map
      table.insert(out[side], {
        key = key,
        npcId = npc.npcId,
        name = PlayerSources.SourceName("npc", npc.npcId),
        mapId = mapId,
        x = x,
        y = y,
        zone = PlayerSources.MapName(mapId),
        players = true,
      })
    end
  end
  -- Brief QH1: a world object that gives or takes the quest, through the same "Given by" and
  -- "Turned in to" rows, opening its page (PlayerSources.ObjectKey) and named by the module's o.
  for side, list in pairs({ givers = quest.objectGivers, enders = quest.objectEnders }) do
    for _, object in ipairs(list) do
      nameSource(source, "object", object.objectId, Graph.Key("object", object.objectId))
      local name = PlayerSources.SourceName("object", object.objectId)
      table.insert(out[side], {
        key = PlayerSources.ObjectKey(object.objectId, name),
        objectId = object.objectId,
        object = true,
        name = name,
        mapId = object.uiMap,
        zone = PlayerSources.MapName(object.uiMap),
        players = true,
      })
    end
  end
  if quest.title then
    nameQuest(source, questId, Graph.Key("quest", questId))
  end
  return out
end

--- Brief QH1: the page a world object's id opens: the Classic Era object's page where that table
--- names the object (Core/QuestsPredicted.lua ObjectKey), else the Forever object's own, object:<id>.
--- Brief AQF1: name, the module's name for it where it has one, must be the one the table states.
function PlayerSources.ObjectKey(objectId, name)
  local predicted = ItemTree.QuestsPredicted
  if type(predicted) == "table" and type(predicted.ObjectKey) == "function" then
    local ok, key = pcall(predicted.ObjectKey, objectId, name)
    if ok and type(key) == "string" then
      return key
    end
  end
  return Graph.Key("object", objectId)
end

-- The player's own hand-over records for a quest or an item (Core/Collector.lua C:QuestHandovers,
-- C:ItemHandovers), or an empty list.
local function ownHandovers(method, id)
  local instance = ItemTree.collector
  if type(instance) ~= "table" or type(instance[method]) ~= "function" then
    return EMPTY
  end
  local ok, list = pcall(instance[method], instance, id)
  return ok and type(list) == "table" and list or EMPTY
end

--- Brief QH1: everything recorded about what one quest hands the player, the player's own records
--- first and then the shipped module's (players' records the pipeline decided may ship), one entry
--- per item and moment: { { itemId, count, when ("accept", "quest" or "turnin"), taken (true the
--- hand-in took it, false it stayed with the player, nil not known), gone (brief IW1: true where it was
--- gone before the hand-in), giverNpcId, own = true or players = true } }. A fact both state is the
--- player's own entry, marked players = true too, with a taken or gone the own record does not know
--- filled from the module. Builds the module (a page is a view).
--- This is the reader the provided item rows (brief PV1) read recorded hand-overs through, before
--- anything predicted.
function PlayerSources.QuestHandovers(questId)
  local out, at = {}, {}
  for _, entry in ipairs(ownHandovers("QuestHandovers", questId)) do
    local copy = {
      itemId = entry.itemId,
      count = entry.count,
      when = entry.when,
      taken = entry.taken,
      gone = entry.gone,
      giverNpcId = entry.giverNpcId,
      own = true,
    }
    out[#out + 1] = copy
    at[entry.itemId .. ":" .. tostring(entry.when)] = copy
  end
  local source = type(questId) == "number" and PlayerSources.Table() or nil
  local quest = source and PlayerSources.Quest(source, questId) or nil
  for _, entry in ipairs(quest and quest.handovers or EMPTY) do
    local held = at[entry.itemId .. ":" .. entry.when]
    if held then
      held.players = true
      if held.taken == nil and not held.gone then
        held.taken, held.gone = entry.taken, entry.gone
      end
    else
      out[#out + 1] = {
        itemId = entry.itemId,
        count = entry.count,
        when = entry.when,
        taken = entry.taken,
        gone = entry.gone,
        giverNpcId = entry.giverNpcId,
        players = true,
      }
    end
  end
  return out
end

--- Brief QH1: every quest recorded handing one item over, the player's own records first and then
--- the shipped module's, one entry per quest and moment: { { questId, count, when, taken,
--- giverNpcId, own = true or players = true } }, as QuestHandovers marks them. "Which quests use
--- this item" for an item a quest hands over (brief QX1): taken true is a quest whose hand-in takes
--- it back, false a quest that leaves it with the player (a tool such as a Soul Gem).
function PlayerSources.ItemHandovers(itemId)
  return PlayerSources.ItemHandoversIn(type(itemId) == "number" and PlayerSources.Table() or nil, itemId)
end

--- Brief IW1: PlayerSources.ItemHandovers over the module handed in (nil or a module with no q: the
--- player's own records alone), so a reader that must never build the module hands in
--- PlayerSources.Loaded(). Pure but for the collector's read.
function PlayerSources.ItemHandoversIn(source, itemId)
  local out, at = {}, {}
  for _, entry in ipairs(ownHandovers("ItemHandovers", itemId)) do
    local copy = {
      questId = entry.questId,
      count = entry.count,
      when = entry.when,
      taken = entry.taken,
      gone = entry.gone,
      giverNpcId = entry.giverNpcId,
      own = true,
    }
    out[#out + 1] = copy
    at[tostring(entry.questId) .. ":" .. tostring(entry.when)] = copy
  end
  local index = type(itemId) == "number" and type(source) == "table" and source.q and questIndexOf(source) or nil
  for _, entry in ipairs(index and index.handedOverBy[itemId] or EMPTY) do
    local held = at[entry.quest .. ":" .. entry.when]
    if held then
      held.players = true
      if held.taken == nil and not held.gone then
        held.taken, held.gone = entry.taken, entry.gone
      end
    else
      out[#out + 1] = {
        questId = entry.quest,
        count = entry.count,
        when = entry.when,
        taken = entry.taken,
        gone = entry.gone,
        giverNpcId = entry.giverNpcId,
        players = true,
      }
    end
  end
  return out
end

-- Brief IW1: the hand-over moments at which a recorded hand-over states a provided item of its quest:
-- at the accept, and from an NPC while the quest is worked (a gossip hand-over of an item the quest
-- asks for, given again on a retake). One handed over at the turn in comes as the quest ends (the next
-- step's item) and is no provided item of it. ItemTree-Data compile_lua.PROVIDED_HANDOVER_WHENS holds
-- a claimed provided item by the same two, and Core/ViewModel.lua's provided rows read them.
PlayerSources.PROVIDED_WHEN = { accept = true, quest = true }

--- Brief IW1: whether one hand-over entry (QuestHandovers' or ItemHandovers' shape) states a provided
--- item of its quest (PlayerSources.PROVIDED_WHEN). Pure.
function PlayerSources.ProvidedHandover(entry)
  return type(entry) == "table" and PlayerSources.PROVIDED_WHEN[entry.when] == true
end

--- Brief IW1: the quests the records say hand one item over at the accept or mid quest
--- (PlayerSources.ProvidedHandover), one entry per quest in ItemHandovers' order, the player's own
--- first: { { questId, own = true or nil, players = true or nil } }. source is the module to read
--- (nil: the player's own records alone). Pure but for the collector's read.
function PlayerSources.ProvidedQuestsIn(source, itemId)
  local out, at = {}, {}
  for _, entry in ipairs(PlayerSources.ItemHandoversIn(source, itemId)) do
    local questId = tonumber(entry.questId)
    if questId and PlayerSources.ProvidedHandover(entry) then
      local held = at[questId]
      if not held then
        held = { questId = questId }
        at[questId] = held
        out[#out + 1] = held
      end
      held.own = held.own or entry.own or nil
      held.players = held.players or entry.players or nil
    end
  end
  return out
end

--- Brief IW1: PlayerSources.ProvidedQuestsIn read only where the module is built already
--- (PlayerSources.Loaded: the loading screen builds it, Core/Data.lua PRELOAD_LOADING_SCREEN), so a
--- tooltip, a bag pass or Core/Keep.lua never builds it; the player's own records answer either way.
--- What Keep.ProvidedQuests and Graph.Summary's recorded provided quests read.
function PlayerSources.ItemProvidedQuests(itemId)
  if type(itemId) ~= "number" then
    return {}
  end
  return PlayerSources.ProvidedQuestsIn(PlayerSources.Loaded(), itemId)
end

--- The provider: see the note at the top of this file.
function PlayerSources.EdgesFor(key, direction)
  local kind, id = Graph.Parse(key)
  if kind == "item" and type(id) == "number" then
    local source = PlayerSources.Table()
    if not source then
      return EMPTY
    end
    if direction == Edges.UP then
      return PlayerSources.ItemEdges(source, id)
    end
    if direction == Edges.DOWN then
      local out = PlayerSources.ItemDownEdges(id)
      for _, quest in ipairs(PlayerSources.ItemQuestEdges(source, id)) do
        out[#out + 1] = quest
      end
      return out
    end
    return EMPTY
  end
  if kind == "quest" and direction == Edges.UP and type(id) == "number" then
    local source = PlayerSources.Table()
    if source and source.q then
      return PlayerSources.QuestRequireEdges(source, id)
    end
    return EMPTY
  end
  -- Brief SD1: what the quest hands over, so Used by reads a recorded reward as the other views do.
  if kind == "quest" and direction == Edges.DOWN and type(id) == "number" then
    local source = PlayerSources.Table()
    if source and source.q then
      return PlayerSources.QuestRewardEdges(source, id)
    end
    return EMPTY
  end
  if kind == "npc" and direction == Edges.DOWN then
    local npcId = npcIdOf(key)
    if npcId and PlayerSources.Table() then
      return PlayerSources.NpcEdges(npcId)
    end
  end
  return EMPTY
end

--------------------------------------------------------------------------------
-- Client side. Guarded: nothing here touches the WoW API (the one map name read goes through
-- Core/Collector.lua's guarded Collector.MapName), so this file loads under busted as it is.
--------------------------------------------------------------------------------

--- Registers the provider and the namer with the graph. Safe to call twice. The provider is marked
--- as one Graph.Summary skips, as Core/ForeverVendors.lua's is, so a tooltip never loads the module.
function PlayerSources.Install()
  if type(Graph) ~= "table" or type(Graph.RegisterProvider) ~= "function" then
    return false
  end
  if not Graph.HasProvider(PlayerSources.EdgesFor) then
    Graph.RegisterProvider(PlayerSources.EdgesFor, { predictedOnly = true })
  end
  if type(Graph.RegisterNamer) == "function" and not Graph.HasNamer(PlayerSources.Namer) then
    Graph.RegisterNamer(PlayerSources.Namer)
  end
  return true
end

PlayerSources.Install()

return PlayerSources
