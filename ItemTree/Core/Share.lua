-- Brief SH1: the player's recorded finds as one line of text they may copy and paste on our
-- website. The backup for the hidden channel, which does not carry addon messages on the beta.
--
-- The addon sends nothing anywhere: no network, no addon message, no chat. UI/Share.lua only
-- puts this text in a box when the player opens the window, and the player decides whether to
-- copy it.
--
-- What is in it is what ItemTree-Data's `mine` reads from a saved file (its docs/mining.md, the
-- allowlist), in the same shapes, already stripped the way that file's strip list says:
--
--   collector  the records (compact rows, or old long rows with their seconds cut to the day),
--              the builds they index, the record shape, the discoveries as the item id, how and
--              day only (never the item's name, a character's name or a realm id), the seen
--              bosses and the quest givers and enders (their seconds cut to the day), and (brief
--              QF1) the quest facts: each quest's level, sides, start item, goals (type, count and a
--              proven creature id, never the objective's text), money and XP by player level,
--              first day and build index, numbers only, and (brief DM2) the creature displays:
--              each creature's confirmed display ids, first day and build index, numbers only.
--              Brief QH1: a quest giver or ender that is a world object by its object id, a quest's
--              hand-overs (h) and the turn in window's word on them (k), and a loot row's quest (o),
--              numbers only
--   ledger     the loot ledger's counts, ids and days
--   places     the instance entrances (kind e)
--   seenCreatures  the creature sightings (seconds cut to the day, zone text dropped where the
--              sighting has a map id)
--
-- Brief FE1: a record of the end of beta event (Core/BetaFence.lua: a fenced build, a day inside the
-- fenced window, a denylisted id) stays home too, so the text never carries it.
--
-- Left out: the Pets feature's tames, the collector's counts, settings, history, keep overrides,
-- the minimap angles, hints, migrations and every other key. A record holding free text shaped
-- like a character's name ("Name-Realm", the collector's own rule) is left out whole. Only fields
-- of the type the pipeline accepts are copied, so one odd value costs that field, never the share.
--
-- The text is `ITEMTREE-SHARE:1:<kind>:<payload>`. Kind J is compact JSON with sorted keys, so
-- the same data always gives the same text; kind Z is the same JSON deflated and base64 encoded
-- by the client's C_EncodingUtil, used only where the client has it and a round trip gives the
-- JSON back. The identifier is a random 16 hex id made once per install (Share.InstallId), so two
-- shares from one install count once.
--
-- Brief SID1 (owner items 298 and 299, 2026-10-20): that id is the contributor id the pipeline
-- counts witnesses by, so one player's shares, sent again and again, are one witness. It is kept
-- account wide in ItemTreeDB (db.shareId) and never made again once kept, so a player who shared
-- before this release stays the same contributor. A new one is drawn from the client's math.random
-- stirred with the client's clock and a fresh table's address (Share.ClientStir): addons have no
-- cryptographic random source, and the stir keeps two clients whose math.random began alike from
-- drawing the same id. Nothing in it comes from the account, the character, the realm or a GUID.
-- The text's format is unchanged: every share since brief SH1 has carried the id.
--
-- Names (brief SH3): the text carries a character's name only when the player ticks Credit my
-- character in the share window (settings.shareCredit, off by default), and then only this
-- character's own name and realm, in one top level field, credit = { name, realm }, which every
-- part carries. With the box off there is no name anywhere in the text and nothing ties it to a
-- person. The stores above stay stripped either way.
--
-- Brief LC1 (owner item 179, 2026-10-15): the text carries the client's game language, GetLocale()
-- ("enUS", "deDE" and so on), in one top level field, locale, which every part carries. The
-- pipeline keeps the names and titles of an English share (enUS or enGB) and only the ids, counts
-- and positions of any other; a share made before this field reads there as unknown. A value that
-- is not two lower case letters then two upper case ones is left out.
--
-- Brief SH2: a text longer than Share.PART_BYTES characters is offered in parts, newest records
-- first (Share.Records, Share.Parts, Share.EncodeParts). Each part is a whole share text on its
-- own with two more top level fields, p (this part, from 1) and pn (how many parts); a share that
-- fits in one has neither. The pipeline merges parts by the install id and pn. Share.Read is the
-- reader for the addon's own text, so the specs can prove each part round trips.
--
-- Everything above the divider is pure and runs under busted.
local _, ItemTree = ...

local Share = {}
ItemTree.Share = Share

-- The website the text is pasted on (owner ruling 2026-10-03: the site is live). Were it empty
-- the window would say to paste it on the ItemTree site, with no address, and the header button
-- would never pulse.
Share.URL = "https://itemtree.net/"

-- Brief SH2: the most characters one part of the share text may hold, so it fits a website's
-- text box and a clipboard. A share over it is offered in parts.
Share.PART_BYTES = 256 * 1024

Share.FORMAT = 1
Share.PREFIX = "ITEMTREE-SHARE"
Share.KIND_JSON = "J"
Share.KIND_DEFLATE = "Z"

local DAY = 86400
-- The largest whole number the pipeline takes; anything past it is left out here.
local MAX_WHOLE = 2147483647

-- Privacy.LooksLikeCharacter (Core/Privacy.lua): "Thrall-Frostmourne".
local looksLikeCharacter = ItemTree.Privacy.LooksLikeCharacter
Share.LooksLikeCharacter = looksLikeCharacter

local function finite(value)
  return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- A whole number from low up to MAX_WHOLE, or nil.
local function whole(value, low)
  if not finite(value) or value % 1 ~= 0 or value < (low or 0) or value > MAX_WHOLE then
    return nil
  end
  return value
end

local function text(value)
  if type(value) ~= "string" then
    return nil
  end
  return value
end

-- A moment in seconds cut to the start of its day, so no time of day leaves.
local function dayStart(value)
  local seconds = whole(value, 0)
  if not seconds then
    return nil
  end
  return math.floor(seconds / DAY) * DAY
end

-- { [id] = whole number } with every id above nought and every value from low up, or nil when
-- nothing is left.
local function idMap(value, low)
  if type(value) ~= "table" then
    return nil
  end
  local out, any = {}, false
  for key, amount in pairs(value) do
    local id = whole(key, 1)
    local number = whole(amount, low or 0)
    if id and number then
      out[id] = number
      any = true
    end
  end
  return any and out or nil
end

local function cost(value)
  if type(value) ~= "table" then
    return nil
  end
  local out, any = {}, false
  local copper = whole(value.copper, 1)
  if copper then
    out.copper, any = copper, true
  end
  for _, part in ipairs({ "currency", "items" }) do
    local map = idMap(value[part], 1)
    if map then
      out[part], any = map, true
    end
  end
  return any and out or nil
end

-- Copies named fields through one checker each. checks is { field = function(value) }.
local function pick(source, checks)
  local out, any = {}, false
  for name, check in pairs(checks) do
    local value = check(source[name])
    if value ~= nil then
      out[name], any = value, true
    end
  end
  return out, any
end

local function positive(value)
  return whole(value, 1)
end
local function count(value)
  return whole(value, 0)
end
local function level(value)
  local number = whole(value, -1)
  if number == 0 then
    return nil
  end
  return number
end
local function coordinate(value)
  if finite(value) and value >= 0 and value <= 100 then
    return value
  end
  return nil
end

--------------------------------------------------------------------------------
-- The snapshot
--------------------------------------------------------------------------------

-- Collector.lua KIND_CODES and SOURCE_CODES: a compact row's key, "d:2589:n:117". Brief SK1: k a
-- skin and p a pickpocket (ItemTree-Data's mine reads both from the same release on).
local COMPACT_KEY = "^[dvrogqecfkp]:%d+:[noqiz]:%d+$"
local LONG_KINDS = {
  drop = true,
  gather = true,
  container = true,
  disenchant = true,
  fish = true,
  vendor = true,
  quest_reward = true,
  quest_objective = true,
  quest_requires = true,
}
local SOURCE_KINDS = { npc = true, object = true, quest = true, item = true, zone = true }

-- A packed point (Collector.PackPosition): x * 10000 + y in tenths of a percent, each 0 to 1000.
local function packedPoint(value)
  local number = whole(value, 0)
  if not number or math.floor(number / 10000) > 1000 or number % 10000 > 1000 then
    return nil
  end
  return number
end

local COMPACT_CHECKS = {
  n = text,
  m = positive,
  z = text,
  s = positive,
  c = count,
  l = count,
  f = count,
  q = count,
  w = positive,
  p = packedPoint,
  P = positive,
  x = cost,
  -- Brief QH1: a loot row's quest, the one the item was an objective of when looted.
  o = positive,
}

-- One compact row (brief R15) with only the fields `mine` reads, or nil where it must stay home:
-- a name or zone shaped like a character's, or a build index that is not one.
local function compactRow(row)
  if type(row) ~= "table" then
    return nil
  end
  if looksLikeCharacter(row.n) or looksLikeCharacter(row.z) then
    return nil
  end
  if row.b ~= nil and not whole(row.b, 1) then
    return nil
  end
  local out = pick(row, COMPACT_CHECKS)
  out.b = whole(row.b, 1)
  if out.m then
    out.z = nil
  end
  return out
end

local LONG_CHECKS = {
  itemId = positive,
  sourceId = count,
  sourceName = text,
  zone = text,
  quality = count,
  count = count,
  need = positive,
  seen = count,
  first = dayStart,
  last = dayStart,
  cost = cost,
}

-- One old shaped row, its seconds cut to the day, or nil.
local function longRow(row)
  if not LONG_KINDS[row.kind] or not SOURCE_KINDS[row.sourceKind] or not whole(row.itemId, 1) then
    return nil
  end
  if looksLikeCharacter(row.sourceName) or looksLikeCharacter(row.zone) then
    return nil
  end
  local out = pick(row, LONG_CHECKS)
  out.kind, out.sourceKind = row.kind, row.sourceKind
  if type(row.build) == "string" and row.build:match("^%d+[%.%d]*$") and not row.build:find("%.%.") then
    out.build = row.build
  end
  local pos = row.pos
  if type(pos) == "table" and positive(pos.map) and coordinate(pos.x) and coordinate(pos.y) then
    out.pos = { map = pos.map, x = pos.x, y = pos.y }
  end
  return out
end

local function records(store)
  local out, any = {}, false
  for key, row in pairs(type(store) == "table" and store or {}) do
    if type(key) == "string" and type(row) == "table" then
      local copy
      if type(row.kind) == "string" then
        copy = longRow(row)
      elseif key:match(COMPACT_KEY) then
        copy = compactRow(row)
      end
      if copy then
        out[key], any = copy, true
      end
    end
  end
  return any and out or nil
end

-- collector.builds: kept only as a whole list of build strings, since a row's b counts into it.
local function builds(list)
  if type(list) ~= "table" or #list == 0 then
    return nil
  end
  local out = {}
  for index, build in ipairs(list) do
    if type(build) ~= "string" or not build:match("^%d+[%.%d]*$") or build:find("%.%.") or build:find("%.$") then
      return nil
    end
    out[index] = build
  end
  return out
end

-- A discovery as the item id's how and day only: the packed shape (brief R3) with every other
-- field empty. Never the item's name, a character's name or a realm id.
local function discoveries(store)
  local collector = ItemTree.Collector
  local out, any = {}, false
  for itemId, held in pairs(type(store) == "table" and store or {}) do
    local id = whole(itemId, 1)
    if id then
      local how, day
      if type(held) == "string" and collector and type(collector.DiscoveryFields) == "function" then
        how, day = collector.DiscoveryFields(held)
      elseif type(held) == "table" then
        how = held.h
        day = held.t and whole(held.t, 0) and math.floor(held.t / DAY) or nil
      end
      if how then
        local code = how == "self" and "s" or "r"
        local dayText = whole(day, 0) and tostring(day) or ""
        out[id], any = code .. "|" .. dayText .. "||||||", true
      end
    end
  end
  return any and out or nil
end

local CREATURE_CHECKS = {
  npcId = positive,
  name = text,
  mapId = positive,
  level = level,
  when = dayStart,
  displayId = positive,
  displayCreatureId = positive,
}

local function seenBosses(store)
  local out, any = {}, false
  for index, record in pairs(type(store) == "table" and store or {}) do
    if whole(index, 1) and type(record) == "table" and not looksLikeCharacter(record.name) then
      out[index], any = (pick(record, CREATURE_CHECKS)), true
    end
  end
  return any and out or nil
end

local NPC_CHECKS = {
  questId = positive,
  npcId = positive,
  -- Brief QH1: a world object that gives or takes a quest.
  objectId = positive,
  name = text,
  mapId = positive,
  x = coordinate,
  y = coordinate,
  when = dayStart,
}

local function questNpcs(store)
  local out, any = {}, false
  for questId, byKind in pairs(type(store) == "table" and store or {}) do
    if whole(questId, 1) and type(byKind) == "table" then
      local roles, held = {}, false
      for _, role in ipairs({ "give", "end" }) do
        local record = byKind[role]
        if type(record) == "table" and not looksLikeCharacter(record.name) then
          if record.questId == nil or record.questId == questId then
            local copy = pick(record, NPC_CHECKS)
            if copy.npcId then
              copy.objectId = nil
            end
            copy.kind = role
            roles[role], held = copy, true
          end
        end
      end
      if held then
        out[questId], any = roles, true
      end
    end
  end
  return any and out or nil
end

-- Brief QF1: the quest facts store (Core/Collector.lua, the comment above
-- Collector.QUEST_FACTS_MAX_BYTES), numbers only. A goal list with one goal the pipeline would not
-- take is left out whole, since the goals keep the client's order; every other odd value costs its
-- own field.
local GOAL_TYPES = {
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

local function goals(list)
  if type(list) ~= "table" or #list == 0 then
    return nil
  end
  local out = {}
  for index, goal in ipairs(list) do
    if type(goal) ~= "table" or not GOAL_TYPES[goal.t] then
      return nil
    end
    local copy = { t = goal.t, n = whole(goal.n, 1) }
    if goal.t == "monster" then
      copy.c = whole(goal.c, 1)
    end
    out[index] = copy
  end
  return out
end

local function side(value)
  local number = whole(value, 1)
  if number and number <= 3 then
    return number
  end
  return nil
end

local function questLevel(value)
  local number = whole(value, 1)
  if number and number <= 255 then
    return number
  end
  return nil
end

-- Brief QH1: what a quest handed over, h { { i, n, w, g } } (Core/Collector.lua, the comment above
-- Collector.QUEST_FACTS_MAX_BYTES): an entry that does not read is left out, at most eight kept, g
-- only on a mid quest hand-over (w 2).
local function handovers(list)
  if type(list) ~= "table" then
    return nil
  end
  local out = {}
  for _, entry in ipairs(list) do
    local item = type(entry) == "table" and whole(entry.i, 1) or nil
    local when = item and whole(entry.w, 1) or nil
    if when and when <= 3 and #out < 8 then
      local count_ = whole(entry.n, 1)
      local copy = { i = item, n = count_ and count_ <= 10000 and count_ or 1, w = when }
      if when == 2 then
        copy.g = whole(entry.g, 1)
      end
      out[#out + 1] = copy
    end
  end
  return #out > 0 and out or nil
end

-- Brief QH1: the turn in window's word on each handed over item, k { [item] = 1 taken or 2 left }; brief
-- IW1 (the owner's "2B" bag check): or 3, gone before the hand-in.
local function takes(map)
  local held = idMap(map, 1)
  if not held then
    return nil
  end
  local out, any = {}, false
  for item, mark in pairs(held) do
    if mark <= 3 then
      out[item], any = mark, true
    end
  end
  return any and out or nil
end

local QUEST_FACT_CHECKS = {
  l = questLevel,
  s = side,
  i = positive,
  o = goals,
  m = positive,
  d = count,
  b = positive,
  h = handovers,
  k = takes,
}

local function questFacts(store)
  local out, any = {}, false
  for questId, record in pairs(type(store) == "table" and store or {}) do
    if whole(questId, 1) and type(record) == "table" then
      local copy, held = pick(record, QUEST_FACT_CHECKS)
      local byLevel = idMap(record.x, 1)
      if byLevel then
        local kept = {}
        for playerLevel, xp in pairs(byLevel) do
          if playerLevel <= 255 then
            kept[playerLevel] = xp
            copy.x, held = kept, true
          end
        end
      end
      if held then
        out[questId], any = copy, true
      end
    end
  end
  return any and out or nil
end

-- Brief DM2: the creature displays store (Core/Collector.lua, the comment above
-- Collector.DISPLAYS_MAX_BYTES), numbers only: i, the display ids (whole numbers above nought, at
-- most four, each once, in order), d the first day and b the build index. A creature whose list
-- keeps no display id is left out; every other odd value costs its own field.
local MAX_DISPLAYS = 4

local function displayIds(list)
  if type(list) ~= "table" then
    return nil
  end
  local out, seen = {}, {}
  for _, id in ipairs(list) do
    local kept = whole(id, 1)
    if kept and not seen[kept] and #out < MAX_DISPLAYS then
      out[#out + 1], seen[kept] = kept, true
    end
  end
  return #out > 0 and out or nil
end

local function displays(store)
  local out, any = {}, false
  for creatureId, record in pairs(type(store) == "table" and store or {}) do
    if whole(creatureId, 1) and type(record) == "table" then
      local ids = displayIds(record.i)
      if ids then
        out[creatureId], any = { i = ids, d = count(record.d), b = positive(record.b) }, true
      end
    end
  end
  return any and out or nil
end

local CLASSIFICATIONS = {
  worldboss = true,
  rareelite = true,
  elite = true,
  rare = true,
  normal = true,
  trivial = true,
  minus = true,
}

local SIGHTING_CHECKS = {
  npcId = positive,
  name = text,
  zone = text,
  mapId = positive,
  level = level,
  creatureType = text,
  when = dayStart,
}

local function seenCreatures(store)
  local out, any = {}, false
  for npcId, record in pairs(type(store) == "table" and store or {}) do
    if whole(npcId, 1) and type(record) == "table" then
      local named = looksLikeCharacter(record.name)
        or looksLikeCharacter(record.zone)
        or looksLikeCharacter(record.creatureType)
      if not named then
        local copy = pick(record, SIGHTING_CHECKS)
        if CLASSIFICATIONS[record.classification] then
          copy.classification = record.classification
        end
        if copy.mapId then
          copy.zone = nil
        end
        out[npcId], any = copy, true
      end
    end
  end
  return any and out or nil
end

-- The ledger's kinds and the keys `mine` reads on each (its LEDGER_LOOT_KEYS).
local LOOT_KINDS = { "creature", "object", "container", "fishing", "disenchant" }
-- A ledger creature's own counts (brief R4) beside w, i, q and g: kills, money windows, copper,
-- and the quest item windows.
local CREATURE_COUNTS = { "k", "mw", "m" }
local CREATURE_MAPS = { "iq", "iqw" }

local function lootCounts(record, out)
  local any = false
  local windows = whole(record.w, 0)
  if windows then
    out.w, any = windows, true
  end
  for _, name in ipairs({ "i", "q" }) do
    local map = idMap(record[name])
    if map then
      out[name], any = map, true
    end
  end
  return any
end

local function lootEntry(kind, record)
  local out = {}
  local any = lootCounts(record, out)
  if kind ~= "disenchant" and type(record.g) == "table" then
    local gathered = {}
    if lootCounts(record.g, gathered) then
      out.g, any = gathered, true
    end
  end
  if kind == "creature" then
    for _, name in ipairs(CREATURE_COUNTS) do
      local value = whole(record[name], 0)
      if value then
        out[name], any = value, true
      end
    end
    for _, name in ipairs(CREATURE_MAPS) do
      local value = idMap(record[name])
      if value then
        out[name], any = value, true
      end
    end
  end
  return any and out or nil
end

local function vendorEntry(record)
  local out, any = {}, false
  for _, name in ipairs({ "seen", "f", "l" }) do
    local value = whole(record[name], 0)
    if value then
      out[name], any = value, true
    end
  end
  for _, name in ipairs({ "i", "c", "s", "a", "d" }) do
    local map = idMap(record[name])
    if map then
      out[name], any = map, true
    end
  end
  return any and out or nil
end

local function questEntry(record)
  local out, any = {}, false
  local turnIns = whole(record.t, 0)
  if turnIns then
    out.t, any = turnIns, true
  end
  local rewards = idMap(record.r)
  if rewards then
    out.r, any = rewards, true
  end
  return any and out or nil
end

local function ledger(store)
  if type(store) ~= "table" then
    return nil
  end
  local out, any = {}, false
  local function kindOf(kind, entryOf)
    local sources, held = {}, false
    for id, record in pairs(type(store[kind]) == "table" and store[kind] or {}) do
      if whole(id, 1) and type(record) == "table" then
        local entry = entryOf(record)
        if entry then
          sources[id], held = entry, true
        end
      end
    end
    if held then
      out[kind], any = sources, true
    end
  end
  for _, kind in ipairs(LOOT_KINDS) do
    kindOf(kind, function(record)
      return lootEntry(kind, record)
    end)
  end
  kindOf("vendor", vendorEntry)
  kindOf("quest", questEntry)
  return any and out or nil
end

-- ItemTreeDB.places, the entrance kind only (the one kind `mine` reads).
local function places(store)
  local entrances = type(store) == "table" and store.e or nil
  if type(entrances) ~= "table" then
    return nil
  end
  local out, any = {}, false
  for id, byMap in pairs(entrances) do
    if whole(id, 1) and type(byMap) == "table" then
      local entry, held = {}, false
      for mapId, cells in pairs(byMap) do
        if mapId == "d" then
          if whole(cells, 0) then
            entry.d = cells
          end
        elseif whole(mapId, 1) and type(cells) == "table" then
          local kept, some = {}, false
          for cell, amount in pairs(cells) do
            if whole(cell, 0) and cell <= 9999 and whole(amount, 1) then
              kept[cell], some = amount, true
            end
          end
          if some then
            entry[mapId], held = kept, true
          end
        end
      end
      if held then
        out[id], any = entry, true
      end
    end
  end
  return any and { e = out } or nil
end

--- The stores `mine` reads, in its shapes, stripped (the header above). db is ItemTreeDB. A new
--- table every call; nothing of db is shared or changed. Pure.
function Share.Snapshot(db)
  local snapshot = {}
  if type(db) ~= "table" then
    return snapshot
  end
  local store = type(db.collector) == "table" and db.collector or {}
  local collector, held = {}, false
  local function put(name, value)
    if value ~= nil then
      collector[name], held = value, true
    end
  end
  put("records", records(store.records))
  put("builds", builds(store.builds))
  local discovered = discoveries(store.discoveries)
  put("discoveries", discovered)
  put("seenBosses", seenBosses(store.seenBosses))
  put("questNpcs", questNpcs(store.questNpcs))
  put("questFacts", questFacts(store.questFacts))
  -- Brief DM2: the creature displays, numbers only.
  put("displays", displays(store.displays))
  if held then
    if collector.records and (store.shape == 1 or store.shape == 2) then
      collector.shape = store.shape
    end
    if discovered then
      collector.discoveriesShape = 1
    end
    snapshot.collector = collector
  end
  snapshot.ledger = ledger(db.ledger)
  snapshot.places = places(db.places)
  snapshot.seenCreatures = seenCreatures(db.seenCreatures)
  -- Brief FE1: the beta event fence (Core/BetaFence.lua) keeps the end of beta event's records home.
  if ItemTree.BetaFence then
    ItemTree.BetaFence.Filter(snapshot)
  end
  return snapshot
end

--------------------------------------------------------------------------------
-- The install id
--------------------------------------------------------------------------------

local HEX = "0123456789abcdef"

-- Brief SID1: the stir's generator, Park and Miller's (state * 48271 modulo 2^31 - 1), whose
-- products stay below 2^53, so a double holds them exactly.
local STIR_MODULUS = 2147483647
local STIR_MULTIPLIER = 48271
Share.STIR_MODULUS = STIR_MODULUS

--- Whether value is an install id: 16 lower case hex digits. Pure.
function Share.IsId(value)
  return type(value) == "string" and #value == 16 and value:match("^[0-9a-f]+$") ~= nil
end

--- The install's share id, made once from the client's random source and kept in the saved file
--- as db.shareId. random(low, high) answers a whole number in that range (math.random where none
--- is given). Brief SID1: stir, a whole number (Share.ClientStir), is folded into every digit of a
--- new id; with none the digits are random's alone. A kept id is never made again. Derived from
--- nothing about the player. nil where there is no db to keep it in.
function Share.InstallId(db, random, stir)
  if type(db) ~= "table" then
    return nil
  end
  if Share.IsId(db.shareId) then
    return db.shareId
  end
  random = random or math.random
  local state = finite(stir) and math.floor(math.abs(stir)) % STIR_MODULUS or 0
  local digits = {}
  for index = 1, 16 do
    local digit = tonumber(random(0, 15)) or 0
    if state > 0 then
      -- The generator's high bits, added: uniform where random is, and different per client
      -- where two clients' random answers alike.
      state = (state * STIR_MULTIPLIER) % STIR_MODULUS
      digit = math.floor(digit) + math.floor(state / 65536)
    end
    digit = math.floor(digit) % 16
    digits[index] = HEX:sub(digit + 1, digit + 1)
  end
  db.shareId = table.concat(digits)
  return db.shareId
end

--------------------------------------------------------------------------------
-- The JSON writer
--------------------------------------------------------------------------------

-- A string as JSON, all ASCII: the UTF-8 the client hands over becomes \u escapes, a byte that
-- is not UTF-8 becomes U+FFFD, and "|" (the client's own escape character in an edit box) is
-- written | so the box never reads it as a colour or link code.
local function hex4(code)
  return string.format("\\u%04x", code)
end

local function utf8Escape(code, parts)
  if code < 0x10000 then
    parts[#parts + 1] = hex4(code)
  else
    code = code - 0x10000
    parts[#parts + 1] = hex4(0xD800 + math.floor(code / 0x400))
    parts[#parts + 1] = hex4(0xDC00 + code % 0x400)
  end
end

local SIMPLE_ESCAPES = { [34] = '\\"', [92] = "\\\\", [10] = "\\n", [13] = "\\r", [9] = "\\t" }

local function jsonString(value)
  local parts = { '"' }
  local index, length = 1, #value
  while index <= length do
    local byte = value:byte(index)
    if SIMPLE_ESCAPES[byte] then
      parts[#parts + 1] = SIMPLE_ESCAPES[byte]
      index = index + 1
    elseif byte < 0x20 or byte == 0x7c or byte == 0x7f then
      parts[#parts + 1] = hex4(byte)
      index = index + 1
    elseif byte < 0x80 then
      parts[#parts + 1] = string.char(byte)
      index = index + 1
    else
      local size, code
      if byte >= 0xC2 and byte <= 0xDF then
        size, code = 2, byte - 0xC0
      elseif byte >= 0xE0 and byte <= 0xEF then
        size, code = 3, byte - 0xE0
      elseif byte >= 0xF0 and byte <= 0xF4 then
        size, code = 4, byte - 0xF0
      end
      local ok = size ~= nil and index + size - 1 <= length
      if ok then
        for offset = 1, size - 1 do
          local next = value:byte(index + offset)
          if next < 0x80 or next > 0xBF then
            ok = false
            break
          end
          code = code * 64 + (next - 0x80)
        end
      end
      local minimum = size == 2 and 0x80 or size == 3 and 0x800 or 0x10000
      if ok and (code < minimum or code > 0x10FFFF or (code >= 0xD800 and code <= 0xDFFF)) then
        ok = false
      end
      if ok then
        utf8Escape(code, parts)
        index = index + size
      else
        parts[#parts + 1] = "\\ufffd"
        index = index + 1
      end
    end
  end
  parts[#parts + 1] = '"'
  return table.concat(parts)
end
Share.JsonString = jsonString

local function jsonNumber(value)
  if value % 1 == 0 and value >= -2 ^ 53 and value <= 2 ^ 53 then
    return string.format("%d", value)
  end
  return string.format("%.14g", value)
end

-- A table keyed exactly 1..n (n above nought) is a JSON array; anything else an object.
local function isArray(value)
  local size = #value
  if size == 0 then
    return false
  end
  local keys = 0
  for _ in pairs(value) do
    keys = keys + 1
  end
  return keys == size
end

-- Numbers first in order, then strings in byte order, so the text never depends on pairs().
local function keyLess(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then
    return ta == "number"
  end
  return a < b
end

local writeValue

local function writeTable(value, parts, depth)
  if depth > 16 then
    error("ItemTree share: the data is nested too deep")
  end
  if isArray(value) then
    parts[#parts + 1] = "["
    for index = 1, #value do
      if index > 1 then
        parts[#parts + 1] = ","
      end
      if not writeValue(value[index], parts, depth + 1) then
        parts[#parts + 1] = "null"
      end
    end
    parts[#parts + 1] = "]"
    return true
  end
  local keys = {}
  for key, item in pairs(value) do
    local usable = (type(key) == "string") or (finite(key) and key % 1 == 0)
    local writable = type(item) == "string" or type(item) == "table" or type(item) == "boolean" or finite(item)
    if usable and writable then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys, keyLess)
  parts[#parts + 1] = "{"
  for index, key in ipairs(keys) do
    if index > 1 then
      parts[#parts + 1] = ","
    end
    parts[#parts + 1] = jsonString(type(key) == "number" and jsonNumber(key) or key)
    parts[#parts + 1] = ":"
    writeValue(value[key], parts, depth + 1)
  end
  parts[#parts + 1] = "}"
  return true
end

writeValue = function(value, parts, depth)
  local kind = type(value)
  if kind == "string" then
    parts[#parts + 1] = jsonString(value)
  elseif kind == "boolean" then
    parts[#parts + 1] = value and "true" or "false"
  elseif kind == "number" and finite(value) then
    parts[#parts + 1] = jsonNumber(value)
  elseif kind == "table" then
    return writeTable(value, parts, depth)
  else
    return false
  end
  return true
end

--- A Lua value as compact JSON: sorted keys, numeric keys written as strings, ASCII only. The
--- same value always gives the same text. Pure.
function Share.Json(value)
  local parts = {}
  if not writeValue(value, parts, 0) then
    return "null"
  end
  return table.concat(parts)
end

--------------------------------------------------------------------------------
-- The text
--------------------------------------------------------------------------------

local function base64Text(value)
  return type(value) == "string" and value ~= "" and value:match("^[A-Za-z0-9+/=_%-]+$") ~= nil
end

-- The JSON deflated and base64 encoded by codec, or nil where codec is missing, refuses, or does
-- not give the JSON back. codec is C_EncodingUtil's shape: CompressString, DecompressString,
-- EncodeBase64, DecodeBase64, and an optional method (Enum.CompressionMethod.Deflate).
local function deflated(json, codec)
  if type(codec) ~= "table" then
    return nil
  end
  for _, name in ipairs({ "CompressString", "DecompressString", "EncodeBase64", "DecodeBase64" }) do
    if type(codec[name]) ~= "function" then
      return nil
    end
  end
  local method = codec.method
  local ok, packed = pcall(codec.CompressString, json, method)
  if not ok or type(packed) ~= "string" then
    return nil
  end
  local encodedOk, encoded = pcall(codec.EncodeBase64, packed)
  if not encodedOk or not base64Text(encoded) then
    return nil
  end
  local backOk, back = pcall(codec.DecodeBase64, encoded)
  if not backOk or back ~= packed then
    return nil
  end
  local plainOk, plain = pcall(codec.DecompressString, back, method)
  if not plainOk or plain ~= json then
    return nil
  end
  return encoded
end

-- Brief SH3: the longest name or realm the credit field takes.
Share.CREDIT_MAX = 64

local function creditText(value)
  if type(value) ~= "string" then
    return nil
  end
  value = value:match("^%s*(.-)%s*$")
  if value == "" or #value > Share.CREDIT_MAX or value:find("[%c|]") then
    return nil
  end
  return value
end

--- Brief SH3: the credit field, { name, realm }, or nil where either is missing, empty, longer
--- than Share.CREDIT_MAX or holds a control character or a bar. Pure.
function Share.Credit(name, realm)
  local cleanName, cleanRealm = creditText(name), creditText(realm)
  if not (cleanName and cleanRealm) then
    return nil
  end
  return { name = cleanName, realm = cleanRealm }
end

--- Brief LC1: a game language code as GetLocale() answers it ("enUS", "deDE"), or nil for
--- anything else. Pure.
function Share.Locale(value)
  if type(value) == "string" and value:match("^%l%l%u%u$") then
    return value
  end
  return nil
end

--- The share text for a snapshot: `ITEMTREE-SHARE:1:J:<json>`, or `...:Z:<base64>` where
--- opts.codec deflates and round trips. The JSON's top level is format, addon (version), build
--- (the client build, opts.build), id, day (opts.day, whole days), locale (brief LC1, the game
--- language, opts.locale, where Share.Locale takes it) and stores, for one part of several (brief
--- SH2) p (opts.part) and pn (opts.parts), and where opts.credit is { name, realm } (brief SH3,
--- the player ticked Credit my character) credit. Answers the text and its kind. Pure: the
--- client's encoder, build, language and the character's name come in through opts.
function Share.Encode(snapshot, id, version, opts)
  opts = type(opts) == "table" and opts or {}
  local credit = type(opts.credit) == "table" and Share.Credit(opts.credit.name, opts.credit.realm) or nil
  local document = {
    format = Share.FORMAT,
    addon = type(version) == "string" and version or "dev",
    id = Share.IsId(id) and id or nil,
    credit = credit,
    day = whole(opts.day, 0),
    build = type(opts.build) == "string" and opts.build or nil,
    locale = Share.Locale(opts.locale),
    stores = type(snapshot) == "table" and snapshot or {},
  }
  local parts = whole(opts.parts, 2)
  local part = whole(opts.part, 1)
  if parts and part and part <= parts then
    document.p, document.pn = part, parts
  end
  local json = Share.Json(document)
  local header = Share.PREFIX .. ":" .. Share.FORMAT .. ":"
  local packed = deflated(json, opts.codec)
  if packed then
    return header .. Share.KIND_DEFLATE .. ":" .. packed, Share.KIND_DEFLATE
  end
  return header .. Share.KIND_JSON .. ":" .. json, Share.KIND_JSON
end

local function size(map)
  local total = 0
  for _ in pairs(type(map) == "table" and map or {}) do
    total = total + 1
  end
  return total
end

-- Brief SK1: a skin (k) and a pickpocket (p) count among the finds' loot too.
local LOOT_CODES = { d = true, g = true, c = true, e = true, f = true, k = true, p = true }
local QUEST_CODES = { r = true, o = true, q = true }
local LOOT_LONG = { drop = true, gather = true, container = true, disenchant = true, fish = true }
local QUEST_LONG = { quest_reward = true, quest_objective = true, quest_requires = true }

--- The plain counts the window shows, and the line that says them: { drops, vendors, quests,
--- creatures, places, discoveries, bytes, kb, parts, line, sizeLine }. shareText is the share
--- text, or the list of its parts (brief SH2), whose size is stated. Pure.
function Share.Summary(snapshot, shareText)
  snapshot = type(snapshot) == "table" and snapshot or {}
  local collector = type(snapshot.collector) == "table" and snapshot.collector or {}
  local out = { drops = 0, vendors = 0, quests = 0, creatures = 0, places = 0, discoveries = 0 }
  for key, row in pairs(type(collector.records) == "table" and collector.records or {}) do
    local code = type(row) == "table" and row.kind or key:sub(1, 1)
    if LOOT_CODES[code] or LOOT_LONG[code] then
      out.drops = out.drops + 1
    elseif code == "v" or code == "vendor" then
      out.vendors = out.vendors + 1
    elseif QUEST_CODES[code] or QUEST_LONG[code] then
      out.quests = out.quests + 1
    end
  end
  for _, roles in pairs(type(collector.questNpcs) == "table" and collector.questNpcs or {}) do
    out.quests = out.quests + size(roles)
  end
  local book = type(snapshot.ledger) == "table" and snapshot.ledger or {}
  for _, vendor in pairs(type(book.vendor) == "table" and book.vendor or {}) do
    out.vendors = out.vendors + size(vendor.i) + size(vendor.c)
  end
  out.quests = out.quests + size(book.quest)
  -- Brief QF1: one quest fact per quest the facts store holds.
  out.quests = out.quests + size(collector.questFacts)
  out.creatures = size(collector.seenBosses) + size(snapshot.seenCreatures)
  -- Brief DM2: one per creature the displays store holds.
  out.creatures = out.creatures + size(collector.displays)
  local entrances = type(snapshot.places) == "table" and snapshot.places.e or nil
  for _, byMap in pairs(type(entrances) == "table" and entrances or {}) do
    for mapId in pairs(byMap) do
      if mapId ~= "d" then
        out.places = out.places + 1
      end
    end
  end
  out.discoveries = size(collector.discoveries)
  out.bytes, out.parts = 0, 0
  local texts = type(shareText) == "table" and shareText or { shareText }
  for _, part in ipairs(texts) do
    if type(part) == "string" then
      out.bytes, out.parts = out.bytes + #part, out.parts + 1
    end
  end
  out.kb = math.floor(out.bytes / 102.4 + 0.5) / 10
  local L = ItemTree.L or {}
  local format = L["%d drops, %d vendor prices, %d quest facts, %d creatures, %d places and %d discoveries"]
    or "%d drops, %d vendor prices, %d quest facts, %d creatures, %d places and %d discoveries"
  local sizeFormat = L["%s KB of text"] or "%s KB of text"
  out.line = string.format(format, out.drops, out.vendors, out.quests, out.creatures, out.places, out.discoveries)
  out.sizeLine = string.format(sizeFormat, tostring(out.kb))
  return out
end

--------------------------------------------------------------------------------
-- The reader (brief SH2)
--------------------------------------------------------------------------------

-- A whole number written as an object key ("117") is read back as the number, the way
-- Share.Json writes an id key, so a snapshot round trips to the same tables.
local function keyBack(key)
  if key:match("^%-?[1-9]%d*$") or key == "0" then
    local number = tonumber(key)
    if number and number >= -2 ^ 53 and number <= 2 ^ 53 then
      return number
    end
  end
  return key
end

local function utf8Char(code)
  if code < 0x80 then
    return string.char(code)
  elseif code < 0x800 then
    return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
  elseif code < 0x10000 then
    return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
  end
  return string.char(
    0xF0 + math.floor(code / 0x40000),
    0x80 + math.floor(code / 0x1000) % 0x40,
    0x80 + math.floor(code / 0x40) % 0x40,
    0x80 + code % 0x40
  )
end

local READ_ESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local readValue

local function skip(source, index)
  return source:find("[^ \t\r\n]", index) or #source + 1
end

local function readString(source, index)
  local parts = {}
  index = index + 1
  while true do
    local stop = source:find('["\\]', index)
    if not stop then
      error("unterminated string")
    end
    parts[#parts + 1] = source:sub(index, stop - 1)
    if source:sub(stop, stop) == '"' then
      return table.concat(parts), stop + 1
    end
    local escape = source:sub(stop + 1, stop + 1)
    if escape == "u" then
      local code = tonumber(source:sub(stop + 2, stop + 5), 16)
      if not code then
        error("bad escape")
      end
      index = stop + 6
      if code >= 0xD800 and code <= 0xDBFF and source:sub(index, index + 1) == "\\u" then
        local low = tonumber(source:sub(index + 2, index + 5), 16)
        if low and low >= 0xDC00 and low <= 0xDFFF then
          code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
          index = index + 6
        end
      end
      parts[#parts + 1] = utf8Char(code)
    elseif READ_ESCAPES[escape] then
      parts[#parts + 1] = READ_ESCAPES[escape]
      index = stop + 2
    else
      error("bad escape")
    end
  end
end

local function readObject(source, index, depth)
  local out = {}
  index = skip(source, index + 1)
  if source:sub(index, index) == "}" then
    return out, index + 1
  end
  while true do
    if source:sub(index, index) ~= '"' then
      error("expected a key")
    end
    local key
    key, index = readString(source, index)
    index = skip(source, index)
    if source:sub(index, index) ~= ":" then
      error("expected a colon")
    end
    local value
    value, index = readValue(source, skip(source, index + 1), depth + 1)
    out[keyBack(key)] = value
    index = skip(source, index)
    local char = source:sub(index, index)
    if char == "}" then
      return out, index + 1
    elseif char ~= "," then
      error("expected a comma")
    end
    index = skip(source, index + 1)
  end
end

local function readArray(source, index, depth)
  local out = {}
  index = skip(source, index + 1)
  if source:sub(index, index) == "]" then
    return out, index + 1
  end
  while true do
    local value
    value, index = readValue(source, index, depth + 1)
    out[#out + 1] = value
    index = skip(source, index)
    local char = source:sub(index, index)
    if char == "]" then
      return out, index + 1
    elseif char ~= "," then
      error("expected a comma")
    end
    index = skip(source, index + 1)
  end
end

readValue = function(source, index, depth)
  if depth > 32 then
    error("nested too deep")
  end
  local char = source:sub(index, index)
  if char == "{" then
    return readObject(source, index, depth)
  elseif char == "[" then
    return readArray(source, index, depth)
  elseif char == '"' then
    return readString(source, index)
  end
  if source:sub(index, index + 3) == "true" then
    return true, index + 4
  elseif source:sub(index, index + 4) == "false" then
    return false, index + 5
  elseif source:sub(index, index + 3) == "null" then
    return nil, index + 4
  end
  local number = source:match("^-?%d+%.?%d*[eE]?[-+]?%d*", index)
  if number and number ~= "" and tonumber(number) then
    return tonumber(number), index + #number
  end
  error("unexpected character at " .. index)
end

--- A JSON text as Lua tables, whole number object keys read back as numbers. Answers the value,
--- or nil and why. Pure.
function Share.ReadJson(source)
  if type(source) ~= "string" then
    return nil, "not text"
  end
  local ok, value, index = pcall(readValue, source, skip(source, 1), 0)
  if not ok then
    return nil, tostring(value)
  end
  if skip(source, index) <= #source then
    return nil, "text after the value"
  end
  return value
end

--- The document inside a share text (Share.Encode's own): the JSON's top level as a table, or nil
--- and why. A kind Z text needs codec (Share.Encode's shape) to read. Pure.
function Share.Read(shareText, codec)
  if type(shareText) ~= "string" then
    return nil, "not text"
  end
  local format, kind, payload = shareText:match("^" .. Share.PREFIX:gsub("%-", "%%-") .. ":(%d+):(%u):(.*)$")
  if tonumber(format) ~= Share.FORMAT then
    return nil, "not a share text"
  end
  local json = payload
  if kind == Share.KIND_DEFLATE then
    if
      type(codec) ~= "table"
      or type(codec.DecodeBase64) ~= "function"
      or type(codec.DecompressString) ~= "function"
    then
      return nil, "no decoder"
    end
    local ok, packed = pcall(codec.DecodeBase64, payload)
    local plainOk, plain = false, nil
    if ok and type(packed) == "string" then
      plainOk, plain = pcall(codec.DecompressString, packed, codec.method)
    end
    if not plainOk or type(plain) ~= "string" then
      return nil, "could not decode"
    end
    json = plain
  elseif kind ~= Share.KIND_JSON then
    return nil, "unknown kind"
  end
  local document, why = Share.ReadJson(json)
  if type(document) ~= "table" then
    return nil, why or "not an object"
  end
  return document
end

--------------------------------------------------------------------------------
-- Parts (brief SH2)
--------------------------------------------------------------------------------

-- The stores in the order their records are walked, each with where its records sit and how a
-- record's day is read (a whole day, or nil where it has none). Every record keeps its key whole:
-- a quest's giver and ender travel together, a ledger source with all its counts.
local function dayOfSeconds(value)
  local seconds = whole(value, 0)
  return seconds and math.floor(seconds / DAY) or nil
end

local function dayOfRow(row)
  if type(row) ~= "table" then
    return nil
  end
  if row.kind ~= nil then
    return dayOfSeconds(row.last) or dayOfSeconds(row.first)
  end
  return whole(row.l, 0) or whole(row.f, 0)
end

local function dayOfDiscovery(value)
  if type(value) ~= "string" then
    return nil
  end
  return tonumber(value:match("^%a|(%d+)|"))
end

local function dayOfWhen(record)
  return type(record) == "table" and dayOfSeconds(record.when) or nil
end

local function dayOfQuestNpcs(roles)
  local best
  for _, record in pairs(type(roles) == "table" and roles or {}) do
    local day = dayOfWhen(record)
    if day and (not best or day > best) then
      best = day
    end
  end
  return best
end

-- Brief QF1: a quest facts record's first day. Brief DM2: a creature displays record's too.
local function dayOfQuestFacts(record)
  return type(record) == "table" and whole(record.d, 0) or nil
end

local function dayOfVendor(record)
  return type(record) == "table" and (whole(record.l, 0) or whole(record.f, 0)) or nil
end

local function dayOfPlace(record)
  return type(record) == "table" and whole(record.d, 0) or nil
end

local function noDay()
  return nil
end

local RECORD_STORES = {
  { path = { "collector", "records" }, day = dayOfRow },
  { path = { "collector", "discoveries" }, day = dayOfDiscovery },
  { path = { "collector", "seenBosses" }, day = dayOfWhen },
  { path = { "collector", "questNpcs" }, day = dayOfQuestNpcs },
  { path = { "collector", "questFacts" }, day = dayOfQuestFacts },
  { path = { "collector", "displays" }, day = dayOfQuestFacts },
  { path = { "seenCreatures" }, day = dayOfWhen },
  { path = { "places", "e" }, day = dayOfPlace },
  { path = { "ledger", "vendor" }, day = dayOfVendor },
  { path = { "ledger", "quest" }, day = noDay },
}
for _, kind in ipairs(LOOT_KINDS) do
  RECORD_STORES[#RECORD_STORES + 1] = { path = { "ledger", kind }, day = noDay }
end
Share.RECORD_STORES = RECORD_STORES

local function at(root, path)
  local node = root
  for _, name in ipairs(path) do
    if type(node) ~= "table" then
      return nil
    end
    node = node[name]
  end
  return type(node) == "table" and node or nil
end

-- What one record adds to the J text: `"key":value,` (the comma counted on every record, so the
-- sum is never short).
local function recordCost(key, value)
  local keyText = type(key) == "number" and jsonNumber(key) or key
  return #jsonString(keyText) + 1 + #Share.Json(value) + 1
end

--- The snapshot's records one by one, newest first: { path, key, value, day, cost } where path is
--- the store's place in the snapshot (Share.RECORD_STORES), day is the record's last day seen in
--- whole days (nil where the store keeps none, which sorts after every dated record) and cost is
--- what it adds to the J text. Ties keep the stores' order, then the keys' order. Pure.
function Share.Records(snapshot)
  local out = {}
  for order, store in ipairs(RECORD_STORES) do
    local map = at(snapshot, store.path)
    if map then
      local keys = {}
      for key in pairs(map) do
        if type(key) == "string" or (finite(key) and key % 1 == 0) then
          keys[#keys + 1] = key
        end
      end
      table.sort(keys, keyLess)
      for index, key in ipairs(keys) do
        local value = map[key]
        out[#out + 1] = {
          path = store.path,
          key = key,
          value = value,
          day = store.day(value),
          cost = recordCost(key, value),
          order = order,
          index = index,
        }
      end
    end
  end
  table.sort(out, function(a, b)
    local da, db = a.day or -1, b.day or -1
    if da ~= db then
      return da > db
    end
    if a.order ~= b.order then
      return a.order < b.order
    end
    return a.index < b.index
  end)
  return out
end

--- Cuts records (Share.Records' list, newest first) into parts whose costs add up to at most
--- limit each, in order: part 1 the newest that fit, part 2 the next, and so on. A record is
--- never split: one that alone costs more than limit has a part to itself. Always at least one
--- part (an empty one for no records). Pure.
function Share.Parts(payloadRecords, limit)
  limit = tonumber(limit) or Share.PART_BYTES
  local parts = { {} }
  local used = 0
  for _, record in ipairs(type(payloadRecords) == "table" and payloadRecords or {}) do
    local weight = tonumber(record.cost) or recordCost(record.key, record.value)
    local current = parts[#parts]
    if #current > 0 and used + weight > limit then
      current = {}
      parts[#parts + 1] = current
      used = 0
    end
    current[#current + 1] = record
    used = used + weight
  end
  return parts
end

local function put(root, path, key, value)
  local node = root
  for _, name in ipairs(path) do
    if type(node[name]) ~= "table" then
      node[name] = {}
    end
    node = node[name]
  end
  node[key] = value
end

-- The fields every part carries whatever records it holds: the build list the compact rows index
-- into, and the shapes that say how to read them.
local function sharedFields(snapshot)
  local collector = type(snapshot) == "table" and type(snapshot.collector) == "table" and snapshot.collector or {}
  return { builds = collector.builds, shape = collector.shape, discoveriesShape = collector.discoveriesShape }
end

--- One part's snapshot: its records put back where they came from, with the collector's builds,
--- and its record and discovery shapes where the part holds such records. Pure.
function Share.Assemble(partRecords, snapshot)
  local shared = sharedFields(snapshot)
  local out = {}
  for _, record in ipairs(type(partRecords) == "table" and partRecords or {}) do
    put(out, record.path, record.key, record.value)
  end
  local collector = out.collector
  if collector or shared.builds then
    collector = collector or {}
    out.collector = collector
    collector.builds = shared.builds
    if collector.records then
      collector.shape = shared.shape
    end
    if collector.discoveries then
      collector.discoveriesShape = shared.discoveriesShape
    end
  end
  return out
end

--- The share texts for a snapshot (Share.Encode's arguments; opts.limit, default
--- Share.PART_BYTES, is the most characters a text may hold): one text with no part fields where
--- it fits, else the parts, newest records first, each a whole share text with p and pn. A part
--- whose deflated text would be longer than limit is written as JSON, which fits by construction.
--- opts.credit (brief SH3) and opts.locale (brief LC1) go on every part. Answers the list of texts
--- and the list of their kinds. Pure.
function Share.EncodeParts(snapshot, id, version, opts)
  opts = type(opts) == "table" and opts or {}
  local limit = tonumber(opts.limit) or Share.PART_BYTES
  local whole1, kind1 = Share.Encode(snapshot, id, version, opts)
  if #whole1 <= limit then
    return { whole1 }, { kind1 }
  end
  local all = Share.Records(snapshot)
  -- The text a part costs before its records: every store's empty table, the shared fields and
  -- the widest part numbers there could be.
  local skeleton = Share.Assemble({}, snapshot)
  for _, record in ipairs(all) do
    local node = skeleton
    for _, name in ipairs(record.path) do
      node[name] = type(node[name]) == "table" and node[name] or {}
      node = node[name]
    end
  end
  if skeleton.collector then
    skeleton.collector.shape = sharedFields(snapshot).shape
    skeleton.collector.discoveriesShape = sharedFields(snapshot).discoveriesShape
  end
  local widest = #all + 1
  local plainOpts = {
    build = opts.build,
    day = opts.day,
    credit = opts.credit,
    locale = opts.locale,
    part = widest,
    parts = widest,
  }
  local overhead = #Share.Encode(skeleton, id, version, plainOpts)
  local parts = Share.Parts(all, limit - overhead)
  if #parts == 1 then
    -- Everything fits once written as JSON: the deflated text was the one too long.
    local plain = Share.Encode(
      snapshot,
      id,
      version,
      { build = opts.build, day = opts.day, credit = opts.credit, locale = opts.locale }
    )
    return { plain }, { Share.KIND_JSON }
  end
  local texts, kinds = {}, {}
  for index, part in ipairs(parts) do
    local partOpts = {
      build = opts.build,
      day = opts.day,
      codec = opts.codec,
      credit = opts.credit,
      locale = opts.locale,
      part = index,
      parts = #parts,
    }
    local partSnapshot = Share.Assemble(part, snapshot)
    local partText, kind = Share.Encode(partSnapshot, id, version, partOpts)
    if #partText > limit and kind ~= Share.KIND_JSON then
      partOpts.codec = nil
      partText, kind = Share.Encode(partSnapshot, id, version, partOpts)
    end
    texts[index], kinds[index] = partText, kind
  end
  return texts, kinds
end

--------------------------------------------------------------------------------
-- The pulse after an update
--------------------------------------------------------------------------------

--- Whether the link pings this time the main window opens. forced (the developer demo) always
--- does. Otherwise only while there is an address to go to, never on a dev build, and only once a
--- version has been noted (db.shareSeen) that is not this one. Brief SH8 (the owner, 2026-10-04):
--- a fresh install's first load never pings, since the player has nothing to share yet; with no
--- version stored this answers false and Share.NoteVersion stores the running one, so the first
--- load after the next update is the first ping. savedState is kept for the callers' shape and no
--- longer read. Pure.
function Share.PulseDue(db, version, _savedState, url, forced)
  if forced then
    return true
  end
  if type(url) ~= "string" or url == "" then
    return false
  end
  if type(version) ~= "string" or version == "" or version == "dev" then
    return false
  end
  if type(db) ~= "table" or type(db.shareSeen) ~= "string" then
    return false
  end
  return db.shareSeen ~= version
end

--- Notes the version seen, so the pulse waits for the next update. A dev build notes nothing.
--- Pure.
function Share.NoteVersion(db, version)
  if type(db) ~= "table" or type(version) ~= "string" or version == "" or version == "dev" then
    return false
  end
  db.shareSeen = version
  return true
end

--------------------------------------------------------------------------------
-- The thank you note after an update (brief TY1)
--------------------------------------------------------------------------------

-- Brief TY1 (owner item 235): a once off note under the Share link (UI/Share.lua), keyed by a
-- message id in code (UIShare.NOTICE_ID). Its state is db.shareNotice, account wide, so an alt never
-- sees a closed note again: { due = <id>, closed = { [<id>] = true } }. due is the id an update made
-- due that nobody has closed yet; closed holds every id closed by the note's X or a click on the link.

local function noticeId(id)
  return type(id) == "string" and id ~= ""
end

--- Whether the note with this id shows now. updated is this open's update check (Share.PulseDue,
--- never forced): true makes the id due. A due id shows on every open until it is closed, and a
--- closed id never shows again, even after another update. A fresh install never has one due, since
--- PulseDue answers false with no version noted. Writes db.shareNotice.due. Pure.
function Share.NoticeDue(db, id, updated)
  if type(db) ~= "table" or not noticeId(id) then
    return false
  end
  local notice = type(db.shareNotice) == "table" and db.shareNotice or nil
  if notice and type(notice.closed) == "table" and notice.closed[id] then
    return false
  end
  if updated == true then
    if not notice then
      notice = {}
      db.shareNotice = notice
    end
    notice.due = id
    return true
  end
  return notice ~= nil and notice.due == id
end

--- Remembers the note with this id as closed for good, and no longer due. Answers whether it was
--- written. Pure.
function Share.CloseNotice(db, id)
  if type(db) ~= "table" or not noticeId(id) then
    return false
  end
  if type(db.shareNotice) ~= "table" then
    db.shareNotice = {}
  end
  local notice = db.shareNotice
  if type(notice.closed) ~= "table" then
    notice.closed = {}
  end
  notice.closed[id] = true
  if notice.due == id then
    notice.due = nil
  end
  return true
end


--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

--- C_EncodingUtil as Share.Encode's codec, or nil where the client does not carry it. Each call is
--- the client's own function, and Share.Encode calls them under pcall.
function Share.ClientCodec()
  local util = rawget(_G, "C_EncodingUtil")
  if type(util) ~= "table" then
    return nil
  end
  local codec = {
    CompressString = util.CompressString,
    DecompressString = util.DecompressString,
    EncodeBase64 = util.EncodeBase64,
    DecodeBase64 = util.DecodeBase64,
  }
  local enum = rawget(_G, "Enum")
  local methods = type(enum) == "table" and enum.CompressionMethod or nil
  if type(methods) == "table" then
    codec.method = methods.Deflate
  end
  return codec
end

-- The client's time in seconds, or nil.
local function clientTime()
  local clock = rawget(_G, "time")
  if type(clock) ~= "function" then
    return nil
  end
  local ok, now = pcall(clock)
  if ok and finite(now) then
    return now
  end
  return nil
end

--- Brief SH3: whether the player ticked Credit my character (settings.shareCredit). Pure.
function Share.CreditOn(db)
  local settings = type(db) == "table" and db.settings or nil
  return type(settings) == "table" and settings.shareCredit == true
end

-- One client call under pcall: its first answer, or nil.
local function clientCall(name, ...)
  local fn = rawget(_G, name)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, answer = pcall(fn, ...)
  if ok then
    return answer
  end
  return nil
end

--- Brief SH3: this character's credit field from UnitName("player") and GetRealmName(), or nil
--- where the client does not answer either. Asked only while the box is ticked.
function Share.ClientCredit()
  return Share.Credit(clientCall("UnitName", "player"), clientCall("GetRealmName"))
end

--- Brief LC1: the client's game language from GetLocale(), a plain client function answering a
--- code such as "enUS" (wow-ui-source, branch forever, 1.60.1.70245: Blizzard_APIDocumentation
--- Generated/LocaleDocumentation.lua:49), or nil where the client answers none Share.Locale takes.
function Share.ClientLocale()
  return Share.Locale(clientCall("GetLocale"))
end

--- Brief SID1: the stir for a new contributor id (Share.InstallId), a whole number from 0 below
--- Share.STIR_MODULUS: the client's clock since it started, to the microsecond (debugprofilestop,
--- what Blizzard's own code times with), plus the address of a table made just now, which differs
--- per client and per session. Neither is about the player and neither is used alone: InstallId
--- folds the stir into the client's math.random. Asked only while the saved file has no id.
function Share.ClientStir()
  local total = 0
  local clock = clientCall("debugprofilestop")
  if finite(clock) then
    total = total + math.floor(math.abs(clock) * 1000) % STIR_MODULUS
  end
  local address = tostring({}):match("(%x+)$")
  local value = address and tonumber(address:sub(-12), 16) or nil
  if finite(value) then
    total = total + value % STIR_MODULUS
  end
  return total % STIR_MODULUS
end

--- The share text for the saved file as it stands now: Snapshot, InstallId, the client build,
--- language (brief LC1) and encoder, cut into parts where it is longer than Share.PART_BYTES (brief
--- SH2), with this character's credit where the player ticked Credit my character (brief SH3).
--- Answers the first text, the snapshot, its kind, the list of every part's text and the credit's
--- state ("off", "on", or "missing" where the box is ticked but the client gave no name), or nil
--- where there is no saved file.
function Share.Build(db)
  db = db or ItemTree.db
  if type(db) ~= "table" then
    return nil
  end
  local snapshot = Share.Snapshot(db)
  -- Brief SID1: a kept id is used as it is; only a saved file with none asks for the stir.
  local id = Share.InstallId(db, nil, not Share.IsId(db.shareId) and Share.ClientStir() or nil)
  local now = clientTime()
  local opts = {
    build = ItemTree.state and ItemTree.state.clientBuild or nil,
    day = now and math.floor(now / DAY) or nil,
    codec = Share.ClientCodec(),
    locale = Share.ClientLocale(),
  }
  local creditState = "off"
  if Share.CreditOn(db) then
    opts.credit = Share.ClientCredit()
    if opts.credit then
      creditState = "on"
    else
      creditState = "missing"
    end
  end
  local texts, kinds = Share.EncodeParts(snapshot, id, ItemTree.version, opts)
  return texts[1], snapshot, kinds[1], texts, creditState
end

return Share
