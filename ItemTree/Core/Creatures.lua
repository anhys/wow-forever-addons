-- The creatures testers have met (brief C4): the reader over the load on demand module Creatures,
-- which the pipeline compiles from the client's creature cache, donated caches and the Discovery
-- Miner's creature harvest (ItemTree-Data brief C3, docs/creatures-met.md is the contract):
--
--   { c = { [creatureId] = { n = name, ti = title, t = creature type, f = family,
--                            k = classification (0 normal, 1 elite, 2 rare elite, 3 boss, 4 rare),
--                            d = { display ids }, w = source flags (1 cache, 2 donated, 4 harvest) } },
--     s = { strings } }
--
-- n and ti are indices into s. n, ti, t, f and k are absent where nothing states them (a creature
-- only the harvest knows has no t and no k), and d may be empty.
--
-- Brief TR1: the trainer fields the pipeline decides from our own sources (ItemTree-Data
-- itemtree_data/trainers.py, docs/data-format.md "Creatures: trainer fields"): tp the profession's
-- skill line, tk the top rank taught (1 Apprentice to 5 Master), tz the zone's name (an index into
-- s) where no map id is known, tx 1 for a creature the owner says never trains. Decode answers them
-- as trainsLine, trainsRank, trainsZone and neverTrainer.
--
-- Brief TR1c (owner 2026-10-11, "YES FILL THE PINS"): tq = { uiMap, cell, uiMap, cell, ... }, an
-- owner confirmed claim's APPROXIMATE positions (a cell is floor(x) * 100 + floor(y) in map percent,
-- as PlayerSources cells are). The pipeline ships them only where our own records place the creature
-- nowhere (ours wins). Decode answers them as claimSpots; Creatures.ClaimPositions makes the pins.
--
-- Brief NW1 (owner ruling B of 2026-10-19, QA item 283): sp = { uiMap, x, y, uiMap, x, y, ... }, the
-- hand kept spots of a creature found at one of several places (the Night Watch Guard 271866 in
-- Duskwood), x and y in tenths of a percent, every one shipped whether the owner has seen it or not
-- (ItemTree-Data curated/creature_spots.json). Decode answers them as spots; Creatures.SpotPositions
-- makes the pins, which the Map tab draws as community positions. The module's qn = { [questId] =
-- index into s } is a quest's how-to note from the same file, read by Creatures.QuestNote. The owner's
-- standing rule of 2026-10-20: sw = { n, ... } on the row names the place in sp (1 for its first
-- triple) of each weak spot, one an unverified single report names; its pin is drawn dimmed with the
-- tooltip line "Weak indicator" (Decode's spots carry weak = true).
--
-- Brief CS1 (the owner's ruling A of 2026-10-20, QA item 304): spots draw in three tiers, all kept on
-- the map. sc = { n, ... } on the row names the place in sp of each Confirmed spot, one a player's
-- recorded find backs (ItemTree-Data creature_spots.confirm: the mined bank's records, never a web
-- report); Decode's spots carry confirmed = true and never weak. A spot in neither list is Reported.
-- The player's own record of the creature (a quest it gave or took back, its vendor window) confirms
-- the spot it ties on their own client before any compile ships it (Creatures.WithOwn), by the same
-- radius rule the pipeline ties a find with (Creatures.SpotRadius).
--
-- Since brief N1 (the owner, 2026-10-02: "I should be able to search for NPCs") the search box
-- finds these creatures too (Core/Data.lua Data:ForeverCreatureIndex), so the module is built on
-- the first creature search as well as on the first page that needs it (Data:Get, which loads
-- ItemTree_Data if it must). A node asked its name reads a module already built and never loads
-- one.
--
-- Pure Lua: nothing here touches the WoW API, so the client side half under the divider is empty.
-- Loaded as: local _, ItemTree = ...
local _, ItemTree = ...

local Data = ItemTree.Data
local Graph = ItemTree.Graph
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

local Creatures = {}
ItemTree.Creatures = Creatures

Creatures.MODULE = "Creatures"

-- The source flags a row's w carries, lowest bit first, and the word each is known by.
Creatures.SOURCES = { { bit = 1, name = "cache" }, { bit = 2, name = "donated" }, { bit = 4, name = "harvest" } }

-- The classification a row's k states, as the locale key the page says it in (the same words
-- Core/CreatureLookup.lua gives UnitClassification's answers).
Creatures.CLASSIFICATIONS = {
  [0] = "Normal",
  [1] = "Elite",
  [2] = "Rare elite",
  [3] = "Boss",
  [4] = "Rare",
}

--------------------------------------------------------------------------------
-- The module
--------------------------------------------------------------------------------

-- The module table, built on this first ask, or nil for a build that ships none. Creatures.source
-- states one for a spec.
function Creatures.Table()
  if type(Creatures.source) == "table" then
    return Creatures.source
  end
  if type(Data) ~= "table" or type(Data.Get) ~= "function" then
    return nil
  end
  local ok, table_ = pcall(Data.Get, Data, Creatures.MODULE)
  if ok and type(table_) == "table" then
    return table_
  end
  return nil
end

-- The module table only where it is already built, or nil: what the namer reads.
function Creatures.Loaded()
  if type(Creatures.source) == "table" then
    return Creatures.source
  end
  local cache = type(Data) == "table" and Data.cache or nil
  local held = type(cache) == "table" and cache[Creatures.MODULE] or nil
  return type(held) == "table" and held or nil
end

-- Kept answers: the decoded rows and the count, each against the module table they came from.
local decodedFor, decoded, countFor, count = nil, {}, nil, 0

-- Forgets the kept answers and any stated table (a spec that swaps the table).
function Creatures.Reset()
  decodedFor, decoded, countFor, count = nil, {}, nil, 0
  Creatures.source = nil
end

-- A positive whole number, or nil.
local function whole(value)
  if type(value) == "number" and value > 0 and value == math.floor(value) then
    return value
  end
  return nil
end

-- Brief NW1: a whole number of tenths of a percent, 0 to 1000, or nil.
local function tenths(value)
  if type(value) == "number" and value >= 0 and value <= 1000 and value == math.floor(value) then
    return value
  end
  return nil
end

-- A string out of s at an index, or nil.
local function stringAt(source, index)
  local strings = type(source) == "table" and source.s or nil
  local text = type(strings) == "table" and type(index) == "number" and strings[index] or nil
  if type(text) ~= "string" or text == "" then
    return nil
  end
  return text
end

--- The source words a row's w states, lowest bit first: { "cache", "harvest" } for 5. Pure.
function Creatures.SourceNames(flags)
  local out = {}
  local w = tonumber(flags)
  if not w or w <= 0 then
    return out
  end
  w = math.floor(w)
  for _, source in ipairs(Creatures.SOURCES) do
    if math.floor(w / source.bit) % 2 == 1 then
      out[#out + 1] = source.name
    end
  end
  return out
end

--- Brief TR1c: a row's tq list as { { map, cell }, ... } in the shipped order, each pair a whole
--- uiMap above nought and a cell 0 to 9999; anything else is left out. nil for no list. Pure.
function Creatures.ClaimSpots(list)
  if type(list) ~= "table" then
    return nil
  end
  local out = {}
  for index = 1, #list - 1, 2 do
    local map, cell = whole(list[index]), whole(list[index + 1])
    if map and map > 0 and cell and cell >= 0 and cell <= 9999 then
      out[#out + 1] = { map = map, cell = cell }
    end
  end
  if #out == 0 then
    return nil
  end
  return out
end

--- Brief TR1c: the pins a creature's claim positions draw, one per spot at its cell's centre:
--- { map, x, y, zone, name, approx = true }, x and y in map percent, or an empty list. spots as
--- Creatures.ClaimSpots answers them; zoneOf(map) names a map, or nil. Pure over what it is handed.
function Creatures.ClaimPins(spots, name, zoneOf)
  local out = {}
  for _, spot in ipairs(type(spots) == "table" and spots or EMPTY) do
    local zone = nil
    if type(zoneOf) == "function" then
      local ok, answer = pcall(zoneOf, spot.map)
      zone = ok and type(answer) == "string" and answer or nil
    end
    out[#out + 1] = {
      map = spot.map,
      x = math.floor(spot.cell / 100) + 0.5,
      y = spot.cell % 100 + 0.5,
      zone = zone,
      name = name,
      approx = true,
    }
  end
  return out
end

--- Brief TR1c: the approximate pins for a creature id out of the Creatures data (Creatures.Get),
--- or an empty list. Builds the module like Creatures.Get. zoneOf as Creatures.ClaimPins takes it.
function Creatures.ClaimPositions(id, zoneOf)
  local row = Creatures.Get(id)
  if not row or not row.claimSpots then
    return {}
  end
  return Creatures.ClaimPins(row.claimSpots, row.name, zoneOf)
end

--- Brief NW1: a row's sp list as { { map, x, y }, ... } in the shipped order, x and y in map percent
--- (the tenths over ten), each a whole uiMap above nought and whole tenths 0 to 1000; anything else
--- is left out. nil for no list or none left. Pure.
---
--- weakList is the row's sw (the owner's standing rule of 2026-10-20): the places in sp, 1 for its
--- first triple, of the weak spots, each of which answers weak = true. A place no spot stands at is
--- ignored.
---
--- Brief CS1: confirmedList is the row's sc, the places in sp of the Confirmed spots, each of which
--- answers confirmed = true and never weak, whatever sw says.
function Creatures.Spots(list, weakList, confirmedList)
  if type(list) ~= "table" then
    return nil
  end
  local function places(given)
    local held = {}
    for _, place in ipairs(type(given) == "table" and given or EMPTY) do
      if whole(place) then
        held[place] = true
      end
    end
    return held
  end
  local weak, confirmed = places(weakList), places(confirmedList)
  local out = {}
  for index = 1, #list - 2, 3 do
    local map, x, y = whole(list[index]), tenths(list[index + 1]), tenths(list[index + 2])
    if map and x and y then
      local place = (index + 2) / 3
      local spot = { map = map, x = x / 10, y = y / 10 }
      if confirmed[place] then
        spot.confirmed = true
      elseif weak[place] then
        spot.weak = true
      end
      out[#out + 1] = spot
    end
  end
  if #out == 0 then
    return nil
  end
  return out
end

-- Brief CS1: the farthest, in map percent, a recorded find stands from a spot it ties: the distance
-- under which the curated file already counts two reports as one spot (ItemTree-Data
-- creature_spots.SAME_SPOT).
Creatures.SAME_SPOT = 1.5

--- Brief CS1: how far a recorded find may stand from one of these spots and tie it, in map percent:
--- Creatures.SAME_SPOT, or half the distance between the two closest spots on one map where that is
--- less, so one find never ties two spots. The pipeline's own rule (ItemTree-Data
--- creature_spots.radius), here over the spots the row ships. spots as Creatures.Spots answers them.
--- Pure.
function Creatures.SpotRadius(spots)
  local best = Creatures.SAME_SPOT
  local list = type(spots) == "table" and spots or EMPTY
  for first = 1, #list do
    local a = list[first]
    for second = first + 1, #list do
      local b = list[second]
      if type(a) == "table" and type(b) == "table" and a.map == b.map then
        local dx = (tonumber(a.x) or 0) - (tonumber(b.x) or 0)
        local dy = (tonumber(a.y) or 0) - (tonumber(b.y) or 0)
        local half = math.sqrt(dx * dx + dy * dy) / 2
        if half < best then
          best = half
        end
      end
    end
  end
  return best
end

--- Brief CS1: the index in spots of the spot a position ties: the nearest on the position's map within
--- reach (map percent), ties the lower index, or nil. pos is { map, x, y }. Pure.
function Creatures.SpotTied(spots, pos, reach)
  if type(spots) ~= "table" or type(pos) ~= "table" then
    return nil
  end
  local x, y, limit = tonumber(pos.x), tonumber(pos.y), tonumber(reach)
  if not x or not y or not limit then
    return nil
  end
  local best, bestAt = nil, nil
  for index, spot in ipairs(spots) do
    if type(spot) == "table" and spot.map == pos.map then
      local dx, dy = (tonumber(spot.x) or 0) - x, (tonumber(spot.y) or 0) - y
      local distance = math.sqrt(dx * dx + dy * dy)
      if distance <= limit and (best == nil or distance < best) then
        best, bestAt = distance, index
      end
    end
  end
  return bestAt
end

--- Brief CS1: the spots with the player's own records of the creature taken in: a spot one of own
--- ties (Creatures.SpotTied within Creatures.SpotRadius) answers confirmed = true and is no longer
--- weak, so a find the player made draws Confirmed on their own client before a compile ships it. own
--- is { { map, x, y }, ... } in map percent. A new list, its changed spots new tables, so a decoded
--- row is never changed; the spots as handed where own ties none. Pure.
function Creatures.WithOwn(spots, own)
  if type(spots) ~= "table" or type(own) ~= "table" or #own == 0 then
    return spots
  end
  local reach = Creatures.SpotRadius(spots)
  local tied = {}
  for _, pos in ipairs(own) do
    local index = Creatures.SpotTied(spots, pos, reach)
    if index and not spots[index].confirmed then
      tied[index] = true
    end
  end
  if next(tied) == nil then
    return spots
  end
  local out = {}
  for index, spot in ipairs(spots) do
    if tied[index] then
      out[index] = { map = spot.map, x = spot.x, y = spot.y, confirmed = true }
    else
      out[index] = spot
    end
  end
  return out
end

--- Brief NW1: the pins a creature's hand kept spots draw, one per spot: { map, x, y, zone, name,
--- spot = true, weak = true where the spot is weak }, or an empty list. spots as Creatures.Spots
--- answers them; zoneOf(map) names a map, or nil. Pure over what it is handed. Brief CS1: and
--- confirmed = true where a recorded find backs the spot.
function Creatures.SpotPins(spots, name, zoneOf)
  local out = {}
  for _, spot in ipairs(type(spots) == "table" and spots or EMPTY) do
    local zone = nil
    if type(zoneOf) == "function" then
      local ok, answer = pcall(zoneOf, spot.map)
      zone = ok and type(answer) == "string" and answer or nil
    end
    out[#out + 1] = {
      map = spot.map,
      x = spot.x,
      y = spot.y,
      zone = zone,
      name = name,
      spot = true,
      weak = spot.weak or nil,
      confirmed = spot.confirmed or nil,
    }
  end
  return out
end

--- Brief NW1: the hand kept spot pins for a creature id out of the Creatures data, or an empty list.
--- Builds the module like Creatures.Get. zoneOf as Creatures.SpotPins takes it. Brief CS1: own, where
--- handed, is the player's own records' positions of the creature (Creatures.WithOwn).
function Creatures.SpotPositions(id, zoneOf, own)
  local row = Creatures.Get(id)
  if not row or not row.spots then
    return {}
  end
  return Creatures.SpotPins(Creatures.WithOwn(row.spots, own), row.name, zoneOf)
end

--- Brief NW1: a quest's hand kept how-to note (the module's qn, its text in s), or nil. Pure over
--- the module table handed in.
function Creatures.QuestNoteIn(source, questId)
  local notes = type(source) == "table" and source.qn or nil
  local index = type(notes) == "table" and whole(questId) and notes[questId] or nil
  return stringAt(source, index)
end

--- Brief NW1: the same for the shipped module, which this builds like Creatures.Get (a quest page
--- asks once per draw). nil for no module, no note or a made up id.
function Creatures.QuestNote(questId)
  if not whole(questId) then
    return nil
  end
  return Creatures.QuestNoteIn(Creatures.Table(), questId)
end

--- One creature's row in a module table, decoded, or nil where the table has none. Pure.
---   { id, name, title, typeId, familyId, classification, displays = { ... }, sources = { ... } }
--- name and title are strings or nil; typeId, familyId and classification numbers or nil (a
--- classification of 0, normal, is a number); displays holds the whole display ids in the data's
--- order, possibly none; sources the words Creatures.SourceNames gives. Brief TR1: trainsLine,
--- trainsRank (numbers), trainsZone (a string) and neverTrainer (true), each nil where not stated.
--- Brief NW1: spots (Creatures.Spots), nil where the row has none.
function Creatures.Decode(source, id)
  local rows = type(source) == "table" and source.c or nil
  local row = type(rows) == "table" and whole(id) and rows[id] or nil
  if type(row) ~= "table" then
    return nil
  end
  local displays = {}
  for _, display in ipairs(type(row.d) == "table" and row.d or EMPTY) do
    if whole(display) then
      displays[#displays + 1] = display
    end
  end
  local classification = tonumber(row.k)
  if classification and not Creatures.CLASSIFICATIONS[classification] then
    classification = nil
  end
  return {
    id = id,
    name = stringAt(source, row.n),
    title = stringAt(source, row.ti),
    typeId = whole(row.t),
    familyId = whole(row.f),
    classification = classification,
    displays = displays,
    sources = Creatures.SourceNames(row.w),
    trainsLine = whole(row.tp),
    trainsRank = whole(row.tk),
    trainsZone = stringAt(source, row.tz),
    neverTrainer = row.tx == 1 or nil,
    claimSpots = Creatures.ClaimSpots(row.tq),
    spots = Creatures.Spots(row.sp, row.sw, row.sc),
  }
end

--- One creature's decoded row (Creatures.Decode), or nil. Builds the module on this first ask and
--- keeps each decoded row for the table it came from, so a second ask is one table read.
function Creatures.Get(id)
  id = whole(id)
  if not id then
    return nil
  end
  local source = Creatures.Table()
  if not source then
    return nil
  end
  if decodedFor ~= source then
    decodedFor, decoded = source, {}
  end
  local held = decoded[id]
  if held == nil then
    held = Creatures.Decode(source, id) or false
    decoded[id] = held
  end
  return held or nil
end

--- The name the data states for a creature id, or nil. Builds the module like Creatures.Get.
function Creatures.Name(id)
  local row = Creatures.Get(id)
  return row and row.name or nil
end

--- The first display id the data states for a creature id, or nil. Builds the module.
function Creatures.Display(id)
  local row = Creatures.Get(id)
  return row and row.displays[1] or nil
end

--- The words for a creature type id ("Beast"), through the words the Classic Era pages use
--- (Core/Sources.lua CREATURE_TYPES), or nil for an id they do not word. Pure.
function Creatures.TypeWord(typeId)
  local Sources = ItemTree.Sources
  local types = type(Sources) == "table" and Sources.CREATURE_TYPES or nil
  local key = type(types) == "table" and types[tonumber(typeId) or -1] or nil
  if type(key) ~= "string" then
    return nil
  end
  return L[key]
end

--- The words for a family id ("Cat"), through Core/Sources.lua CREATURE_FAMILIES, or nil. Pure.
function Creatures.FamilyWord(familyId)
  local Sources = ItemTree.Sources
  local families = type(Sources) == "table" and Sources.CREATURE_FAMILIES or nil
  local key = type(families) == "table" and families[tonumber(familyId) or -1] or nil
  if type(key) ~= "string" then
    return nil
  end
  return L[key]
end

--- The words for a classification k ("Rare elite"), or nil for one the contract does not name.
--- Pure.
function Creatures.ClassificationWord(k)
  local key = Creatures.CLASSIFICATIONS[tonumber(k) or -1]
  if not key then
    return nil
  end
  return L[key]
end

--- How many creatures the module holds, 0 where none ships. Builds the module; counted once per
--- module table.
function Creatures.Count()
  local source = Creatures.Table()
  if not source then
    return 0
  end
  if countFor ~= source then
    local n = 0
    for _ in pairs(type(source.c) == "table" and source.c or EMPTY) do
      n = n + 1
    end
    countFor, count = source, n
  end
  return count
end

--- The namer Graph asks for a node nothing else names: the data's name for npc:<id>, so the
--- breadcrumb and the window title name a creature the data knows. Reads a module already built
--- only, so asking a node its name never loads anything.
function Creatures.Namer(key)
  if type(key) ~= "string" then
    return nil
  end
  local id = whole(tonumber(key:match("^npc:(%d+)$")))
  local source = id and Creatures.Loaded() or nil
  if not source then
    return nil
  end
  local rows = type(source.c) == "table" and source.c or EMPTY
  local row = rows[id]
  return type(row) == "table" and stringAt(source, row.n) or nil
end

--- Brief BQ4 (QA item 25): the places a creature page names. A creature the shipped table states
--- zones for keeps them, untouched (the same table). One it states none for, but that the Boss loot
--- index files as a boss (boss is BossLoot.BossOf's answer: areaId, areaName, placeName), is known
--- in that instance: a summoned boss such as Mutanus the Devourer has no spawn in the Classic data,
--- because an event brings him, and "Boss of Wailing Caverns" is the one place we know. Answers a
--- new list of one { areaId, name }, the shape a zone row takes, or zones as handed in. Pure.
function Creatures.BossZones(zones, boss)
  if type(zones) == "table" and #zones > 0 then
    return zones
  end
  if type(boss) ~= "table" then
    return zones
  end
  local name = boss.areaName
  if type(name) ~= "string" or name == "" then
    name = boss.placeName
  end
  if type(name) ~= "string" or name == "" then
    return zones
  end
  return { { areaId = tonumber(boss.areaId), name = name } }
end

--------------------------------------------------------------------------------
-- Client side. Guarded: nothing here, and the file loads with no WoW API present.
--------------------------------------------------------------------------------

if type(Graph) == "table" and type(Graph.RegisterNamer) == "function" then
  if type(Graph.HasNamer) ~= "function" or not Graph.HasNamer(Creatures.Namer) then
    Graph.RegisterNamer(Creatures.Namer)
  end
end

return Creatures
