-- The Boss loot model: the places, their bosses and what each boss drops, read off the shipped
-- BossLoot index and merged with what the collector has watched drop. Pure Lua, no WoW API.
--
-- The index is the load on demand module BossLoot (ItemTree_Data), whose shape is the contract in
-- ItemTree-Data docs/boss-loot.md, section 1:
--
--   { v = 1, s = { strings }, p = { places, in draw order }, b = { bosses, rares and chests } }
--   p = { n, k (1 dungeon, 2 raid, 3 world boss), lv, lo, hi, m, a, an, z, sz, g, b = { ... } }
--   b = { n, r (1 boss, 2 rare elite, 3 rare, 4 chest), lo, hi, e, c = { ... }, d, g, w, l }
--
-- l is the boss's loot as fixed 8 byte records in the EraSources xl alphabet (base 91, the bytes
-- 35 to 126 with 92 left out, most significant digit first): item id (3 digits), value (2: the
-- chance in tenths of a percent, plus 2048 where the drop is quest only, 0 where no chance is
-- stated), type code (1) and item level (2, 0 where unknown). Any v but 1 is refused whole, with a
-- plain error value and never a raise.
--
-- What is built when (plan section 2). The module is built once and kept by Core/Data.lua, which
-- lets its loader go. The place list is a few dozen small tables kept for the session. A boss's
-- rows are decoded only when it is opened, and held in a small LRU of places (cap 3) that
-- M:Release empties when the tab is hidden; the strings stay packed in the module the whole time.
-- Nothing here builds EraSources, EraSources.LootIndex, any Items_* module, EraItems or
-- DiffChanges: names come from Data:ItemGlance (the Names module), locks from Data:EraUnlocked,
-- developer items from Data:IsHidden and the marks from Discoveries.Badges, all table reads. An
-- entry's creature page key comes off the index too (brief EK1: ei, the creature id the Classic
-- Era page is keyed by, and em, whether that page is merged with the Forever page of that id),
-- through EraSources' one page key builder, which reads no table.
--
-- HARD RULE: nothing here asks the client about an item. No GetItemInfo, GetItemInfoInstant or
-- RequestLoadItemDataByID, not once and never in a loop. A name comes from the shipped Names
-- module or from the neutral placeholder Core/Graph.lua builds (Graph.UndiscoveredName).
-- tests/spec/boss_loot_spec.lua spies on all three.
--
-- Brief DL1 (the owner, 2026-10-20, QA items 274 and 291): an entry may carry cl, its community
-- drops, in l's record shape: what pages the owner saved himself say its creatures drop
-- (ItemTree-Data curated/community_drops.json). Brief DL1b (the owner's ruling of 2026-10-20): no
-- rate ships, the value is 0, and a community row and edge show none whatever a value says. They are
-- listed with the entry's other rows as Predicted rows of community provenance (never verified),
-- and the collector's own record of the item off that entry replaces one, as it
-- replaces a Classic Era row. A guess of the same item is folded into it (BossLoot.GuessRows leaves
-- out every item the entry's rows list). The same facts reach the graph through BossLoot.EdgesFor:
-- an item's Sources rows "Drops from <boss>" and the boss's own page's Drops, Predicted, where
-- Graph.Summary never asks (a tooltip never builds the index for them). Neither is a reason to keep
-- an item: Core/Keep.lua reads uses, never where an item comes from.
local _, ItemTree = ...

local BossLoot = {}
ItemTree.BossLoot = BossLoot

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

-- The generated module's name, which Data:Get loads, and the one contract version read here.
BossLoot.MODULE = "BossLoot"
BossLoot.VERSION = 1

-- Brief DL1: the provenance a community drop carries (Core/Sources.lua words it "Community note")
-- and the basis its Predicted mark reads, which no meaning line names, so the mark says the plain
-- Predicted meaning and never the Classic Era one.
BossLoot.PROVENANCE_COMMUNITY = "community"
BossLoot.BASIS_COMMUNITY = "community"

-- Place kinds (p.k) and entry ranks (b.r).
BossLoot.KIND_DUNGEON, BossLoot.KIND_RAID, BossLoot.KIND_WORLD = 1, 2, 3
BossLoot.RANK_BOSS, BossLoot.RANK_RARE_ELITE, BossLoot.RANK_RARE, BossLoot.RANK_CHEST = 1, 2, 3, 4

-- What a rank is called beside an entry's name. A boss says nothing: it is what the column is.
BossLoot.RANK_WORDS = { [2] = "Rare elite", [3] = "Rare", [4] = "Chest" }

-- How many places the decoded rows are held for, and the growth that earns a GC step.
BossLoot.CACHE_CAP = 3
BossLoot.GC_THRESHOLD_KB = 8192

--------------------------------------------------------------------------------------------------
-- Level bands
--------------------------------------------------------------------------------------------------

-- The bands of the place list: 1 to 6 ("Level 1 to 10" to "Level 51 to 60"), 7 "Endgame (60+)"
-- (brief BL28: a place whose entry level is 60, and every world boss whatever its level), and 8
-- for a place the data gives no level, which draws last.
BossLoot.BAND_WIDTH = 10
BossLoot.BAND_COUNT = 6
BossLoot.BAND_ENDGAME = 7
BossLoot.ENDGAME_LEVEL = 60
BossLoot.BAND_UNKNOWN = 8

-- The band a place's lv and kind fall in: BAND_ENDGAME for lv 60 or more or a world boss (k = 3),
-- else min(6, max(1, ceil(lv / 10))), so a change of band width needs no data rebuild.
-- BAND_UNKNOWN where there is no level and the place is not a world boss.
function BossLoot.Band(lv, k)
  if tonumber(k) == BossLoot.KIND_WORLD then
    return BossLoot.BAND_ENDGAME
  end
  local level = tonumber(lv)
  if not level then
    return BossLoot.BAND_UNKNOWN
  end
  if level >= BossLoot.ENDGAME_LEVEL then
    return BossLoot.BAND_ENDGAME
  end
  local band = math.ceil(level / BossLoot.BAND_WIDTH)
  if band < 1 then
    band = 1
  elseif band > BossLoot.BAND_COUNT then
    band = BossLoot.BAND_COUNT
  end
  return band
end

-- "Level 11 to 20", "Endgame (60+)" for band 7, or "Level unknown" for the last band and anything
-- that is not a band.
function BossLoot.BandLabel(band)
  local value = tonumber(band)
  if value == BossLoot.BAND_ENDGAME then
    return L["Endgame (60+)"]
  end
  if not value or value < 1 or value > BossLoot.BAND_COUNT or value ~= math.floor(value) then
    return L["Level unknown"]
  end
  local width = BossLoot.BAND_WIDTH
  return string.format(L["Level %d to %d"], (value - 1) * width + 1, value * width)
end

--------------------------------------------------------------------------------------------------
-- Type codes
--------------------------------------------------------------------------------------------------

-- The contract's type codes, 1 to 21, in the order the groups draw, and the locale key of each.
BossLoot.TYPE_ORDER = {}
for code = 1, 21 do
  BossLoot.TYPE_ORDER[code] = code
end
BossLoot.TYPE_OTHER = 21

BossLoot.TYPE_WORDS = {
  "Plate",
  "Mail",
  "Leather",
  "Cloth",
  "Back",
  "Shield",
  "Held in off-hand",
  "Neck",
  "Finger",
  "Trinket",
  "Relic",
  "One-hand weapon",
  "Two-hand weapon",
  "Ranged",
  "Recipe",
  "Quest",
  "Material",
  "Consumable",
  "Container",
  "Key",
  "Other",
}

-- The group header's word for a type code, "Other" for a code the contract does not name.
function BossLoot.TypeWord(code)
  local key = BossLoot.TYPE_WORDS[tonumber(code) or 0] or BossLoot.TYPE_WORDS[BossLoot.TYPE_OTHER]
  return L[key]
end

-- The word beside an entry of this rank, or nil for a boss.
function BossLoot.RankWord(rank)
  local key = BossLoot.RANK_WORDS[tonumber(rank) or 0]
  if not key then
    return nil
  end
  return L[key]
end

-- The type a row the index does not list goes under, from the item's class alone (the Names
-- module states no subclass or slot). Armour and weapons cannot be told apart that way, so they
-- go under Other; the caller asks the rest of the index first (see typeMap in the reader).
local CLASS_TYPES = { [0] = 18, [1] = 19, [5] = 17, [7] = 17, [9] = 15, [12] = 16, [13] = 20 }

function BossLoot.TypeForClass(class)
  return CLASS_TYPES[tonumber(class) or -1] or BossLoot.TYPE_OTHER
end

--------------------------------------------------------------------------------------------------
-- Decoding
--------------------------------------------------------------------------------------------------

local PACK_BASE = 91
local PACK_FIRST = 35
local PACK_SKIPPED = 92
local RECORD = 8
local QUEST_ONLY = 2048
BossLoot.RECORD_BYTES = RECORD
BossLoot.QUEST_ONLY = QUEST_ONLY

-- One packed field, or nil where a byte is outside the alphabet.
local function packedInt(text, at, digits)
  local value = 0
  for offset = 0, digits - 1 do
    local code = string.byte(text, at + offset)
    if not code or code == PACK_SKIPPED then
      return nil
    end
    if code > PACK_SKIPPED then
      code = code - 1
    end
    code = code - PACK_FIRST
    if code < 0 or code >= PACK_BASE then
      return nil
    end
    value = value * PACK_BASE + code
  end
  return value
end

-- A boss's l as a flat stride 4 array { id, value, type, ilvl, id, value, ... }, and how many
-- records could not be read: a bad byte spoils its own record, and a length that is not a
-- multiple of eight spoils the tail. Counted, never raised. An empty array for no l.
function BossLoot.DecodeLoot(packed)
  local out, malformed = {}, 0
  if type(packed) ~= "string" or packed == "" then
    return out, malformed
  end
  local length = #packed
  local whole = length - length % RECORD
  if whole < length then
    malformed = malformed + 1
  end
  local n = 0
  for at = 1, whole, RECORD do
    local id = packedInt(packed, at, 3)
    local value = packedInt(packed, at + 3, 2)
    local code = packedInt(packed, at + 5, 1)
    local ilvl = packedInt(packed, at + 6, 2)
    if id and value and code and ilvl and id > 0 then
      out[n + 1], out[n + 2], out[n + 3], out[n + 4] = id, value, code, ilvl
      n = n + 4
    else
      malformed = malformed + 1
    end
  end
  return out, malformed
end

-- A record's value split: the chance as a percent (12.5), or nil where none is stated, and
-- whether the drop is quest only.
function BossLoot.SplitValue(value)
  local number = tonumber(value) or 0
  local questOnly = false
  if number >= QUEST_ONLY then
    questOnly = true
    number = number - QUEST_ONLY
  end
  if number <= 0 then
    return nil, questOnly
  end
  return number / 10, questOnly
end

--------------------------------------------------------------------------------------------------
-- The two files (brief GA1)
--------------------------------------------------------------------------------------------------

-- Owner ruling of 2026-10-09: only data derived from the CMaNGOS Classic content database may be in
-- a GPL file. The index ships as two modules, BossLootIndex (ours, all rights reserved: the v = 1
-- index with no l, plus it and, on a chest, ob) and BossLoot (GPL-3.0, the Classic Era half, v = 2:
-- what each CMaNGOS creature and chest drops). Core/Data.lua's Data.JoinBossLoot makes the v = 1
-- index every reader below reads, the first time Data:Get builds it (Data.JOINS), so a namespace
-- that never loads this file still reads the one table. BossLoot.Join is the same function.
BossLoot.INDEX_MODULE = "BossLootIndex"
BossLoot.ERA_VERSION = 2
BossLoot.Join = ItemTree.Data and ItemTree.Data.JoinBossLoot or nil

--------------------------------------------------------------------------------------------------
-- The index
--------------------------------------------------------------------------------------------------

-- Whether a table is one this reader may read. Answers the table, or nil and a plain reason.
function BossLoot.Check(index)
  if type(index) ~= "table" then
    return nil, "no Boss loot data in this build"
  end
  if index.v ~= BossLoot.VERSION then
    return nil,
      string.format("Boss loot data version %s, this ItemTree reads version %d", tostring(index.v), BossLoot.VERSION)
  end
  if type(index.s) ~= "table" or type(index.p) ~= "table" or type(index.b) ~= "table" then
    return nil, "Boss loot data is missing its strings, places or bosses"
  end
  return index
end

local function str(index, at)
  local strings = index.s
  local value = type(at) == "number" and strings[at] or nil
  if type(value) == "string" then
    return value
  end
  return nil
end

-- One point on a zone map as the index ships it (brief M8): the UiMapID of the zone map, then x and
-- y in tenths of a percent (integers 0 to 1000, x from the left, y from the top). All three or
-- none. Answers { map, x, y } with x and y in percent, or nil where any is absent or out of range.
local function shippedPoint(place, mapField, xField, yField)
  if type(place) ~= "table" then
    return nil
  end
  local map, x, y = place[mapField], place[xField], place[yField]
  if type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
    return nil
  end
  if map <= 0 or map ~= math.floor(map) or x ~= math.floor(x) or y ~= math.floor(y) then
    return nil
  end
  if x < 0 or x > 1000 or y < 0 or y > 1000 then
    return nil
  end
  return { map = map, x = x / 10, y = y / 10 }
end

-- Where a place's instance portal stands, the point the player zones in at (brief M8, contract
-- shared with W16): eu, ex, ey. { map, x, y } in percent, or nil. Pure.
function BossLoot.EntrancePoint(place)
  return shippedPoint(place, "eu", "ex", "ey")
end

-- Where a place's outdoor mouth stands, the way in a traveller walks to (brief M8, contract shared
-- with W17): mu, mx, my, shaped as the portal's. { map, x, y } in percent, or nil. Pure.
function BossLoot.MouthPoint(place)
  return shippedPoint(place, "mu", "mx", "my")
end

-- Brief Z4: the place of one instance area, out of the index alone: the id (its position in p) and
-- the place whose area (a) is areaId, or nil. A world boss (k = 3) is never an instance. Pure.
function BossLoot.PlaceOfArea(index, areaId)
  if type(index) ~= "table" or type(index.p) ~= "table" or type(areaId) ~= "number" then
    return nil
  end
  for id, place in ipairs(index.p) do
    if type(place) == "table" and tonumber(place.k) ~= BossLoot.KIND_WORLD and tonumber(place.a) == areaId then
      return id, place
    end
  end
  return nil
end

-- The place list the left column draws: a band header before the first place of each band, then
-- the places in the index's own order. Brief BL28: the bands draw in ascending order (7, Endgame,
-- after 6 and 8, Level unknown, last) and a band's places keep the index's order, so a data build
-- sorted by the older rule (world bosses by their own level) still draws each header once.
--
--   { kind = "band", band, label }
--   { kind = "place", id, name, k, band, lv, lo, hi, sz, isNew, zones = { names }, zone, continent,
--     bossCount, entrance, mouth }
--
-- id is the place's index in p. zones is the world boss's zone names (k = 3), else empty. zone is
-- the entrance zone's name (ez) and continent the continent's (ec), each nil where absent.
-- entrance is the shipped instance portal (BossLoot.EntrancePoint) and mouth the shipped outdoor
-- mouth (BossLoot.MouthPoint), each nil where the place has none.
function BossLoot.PlaceRows(index)
  local rows = {}
  if type(index) ~= "table" or type(index.p) ~= "table" then
    return rows
  end
  local byBand, bands = {}, {}
  for id, place in ipairs(index.p) do
    if type(place) == "table" then
      local band = BossLoot.Band(place.lv, place.k)
      if not byBand[band] then
        byBand[band] = {}
        bands[#bands + 1] = band
      end
      local zones = {}
      for _, at in ipairs(type(place.z) == "table" and place.z or EMPTY) do
        zones[#zones + 1] = str(index, at)
      end
      local list = byBand[band]
      list[#list + 1] = {
        kind = "place",
        id = id,
        name = str(index, place.n) or "",
        k = place.k,
        band = band,
        lv = place.lv,
        lo = place.lo,
        hi = place.hi,
        sz = place.sz,
        isNew = place.g == 1,
        zones = zones,
        zone = str(index, place.ez),
        continent = str(index, place.ec),
        bossCount = #(type(place.b) == "table" and place.b or EMPTY),
        entrance = BossLoot.EntrancePoint(place),
        mouth = BossLoot.MouthPoint(place),
      }
    end
  end
  table.sort(bands)
  for _, band in ipairs(bands) do
    rows[#rows + 1] = { kind = "band", band = band, label = BossLoot.BandLabel(band) }
    for _, row in ipairs(byBand[band]) do
      rows[#rows + 1] = row
    end
  end
  return rows
end

-- The place tooltip's location line (brief BL13b): the zone, then the continent, "Westfall,
-- Eastern Kingdoms". A world boss (k = 3) lists its zones, "Azshara, Kalimdor" or "Ashenvale,
-- Duskwood, Feralas, The Hinterlands" with the continent after where all share one. A field that
-- is absent drops out of the line; nil where nothing at all is known. Where the place ships its
-- entrance (brief M8) the zone carries its coordinates, "The Barrens 46.0, 36.0, Kalimdor": the
-- outdoor mouth where it ships one, which is where a traveller heads, else the instance portal.
function BossLoot.PlaceWhere(place)
  if type(place) ~= "table" then
    return nil
  end
  local parts = {}
  local function add(value)
    if type(value) == "string" and value ~= "" then
      parts[#parts + 1] = value
    end
  end
  if tonumber(place.k) == 3 then
    for _, zone in ipairs(type(place.zones) == "table" and place.zones or EMPTY) do
      add(zone)
    end
  else
    local zone = place.zone
    local at = type(place.mouth) == "table" and place.mouth or place.entrance
    if type(zone) == "string" and zone ~= "" and type(at) == "table" and tonumber(at.x) and tonumber(at.y) then
      zone = string.format(L["%s %s"], zone, string.format("%.1f, %.1f", tonumber(at.x), tonumber(at.y)))
    end
    add(zone)
  end
  add(place.continent)
  local line = nil
  for _, part in ipairs(parts) do
    line = line and string.format(L["%s, %s"], line, part) or part
  end
  return line
end

-- One place's entries, in the index's own order, read straight off b. Nothing is decoded: the
-- count is the packed length over eight.
--
--   { id, name, r, rankWord, lo, hi, isNew, count, creature, worldDrops }
--
-- id is the entry's index in b; creature is whether it has a creature page (e).
function BossLoot.BossRows(index, placeId)
  local rows = {}
  local place = type(index) == "table" and type(index.p) == "table" and index.p[placeId] or nil
  if type(place) ~= "table" or type(place.b) ~= "table" then
    return rows
  end
  for _, id in ipairs(place.b) do
    local boss = index.b[id]
    if type(boss) == "table" then
      local packed = type(boss.l) == "string" and boss.l or ""
      rows[#rows + 1] = {
        id = id,
        name = str(index, boss.n) or "",
        r = boss.r,
        rankWord = BossLoot.RankWord(boss.r),
        lo = boss.lo,
        hi = boss.hi,
        isNew = boss.g == 1,
        count = math.floor(#packed / RECORD),
        creature = type(boss.e) == "number",
        worldDrops = tonumber(boss.w) or 0,
      }
    end
  end
  return rows
end

-- The creature page an entry opens, or nil where it has none. Brief EK1: the Classic Era page is
-- keyed by its creature id, which the index states as ei (the page of e's name), and em = 1 where
-- that page is one with the Forever page of that id (brief EK1 2b). The key is built by EraSources'
-- one builder (EraSources.CreaturePageKey), which reads no table, so the tab builds nothing of
-- Classic Era to draw or open it. An entry with no ei has no Classic Era page. Pure.
function BossLoot.CreatureKeyOf(boss)
  local EraSources = ItemTree.EraSources
  if type(boss) ~= "table" or type(EraSources) ~= "table" or type(EraSources.CreaturePageKey) ~= "function" then
    return nil
  end
  return EraSources.CreaturePageKey(tonumber(boss.ei), boss.em == 1)
end

-- Brief NP3: the boss entries a creature page can be matched to, read once off the index: byPage
-- maps the creature id an entry's Classic Era page is keyed by (ei, brief EK1) to the entry, byId
-- each of its creature ids (c). Brief EK2: byPage is also how a page that joins a Classic Era name
-- finds its boss (by that name's creature id), so nothing here matches on a name's place in the
-- Classic Era strings (e) any more. The first entry wins where two name the same creature. Only a
-- boss (r 1, or no rank) of a dungeon or a raid is filed: a rare, a chest and a world boss are no
-- boss "of" a place. Pure.
function BossLoot.CreatureBossMap(index)
  local map = { byPage = {}, byId = {} }
  if type(index) ~= "table" or type(index.p) ~= "table" or type(index.b) ~= "table" then
    return map
  end
  for placeId, place in ipairs(index.p) do
    local instance = type(place) == "table" and tonumber(place.k) ~= BossLoot.KIND_WORLD
    for _, bossId in ipairs(instance and type(place.b) == "table" and place.b or EMPTY) do
      local boss = index.b[bossId]
      local rank = type(boss) == "table" and tonumber(boss.r) or nil
      if type(boss) == "table" and (rank == nil or rank == BossLoot.RANK_BOSS) then
        local held = { bossId = bossId, placeId = placeId }
        if type(boss.ei) == "number" and map.byPage[boss.ei] == nil then
          map.byPage[boss.ei] = held
        end
        for _, creatureId in ipairs(type(boss.c) == "table" and boss.c or EMPTY) do
          if type(creatureId) == "number" and map.byId[creatureId] == nil then
            map.byId[creatureId] = held
          end
        end
      end
    end
  end
  return map
end

-- Brief NP3: the place a creature page's creature is a boss of, or nil. key is the page's npc key;
-- creatureId the real creature id behind it where one is known (npc:<id> itself, or the unit the
-- page was opened from); eraId the creature id of the Classic Era name it joins (a positive id's
-- name, E:CreatureIdAt; brief EK2: until then the name's index, matched against e). Brief EK1: a
-- Classic Era page key holds the creature id the page is keyed by, read back by EraSources' one
-- parser (EraSources.PageId) and matched against ei, and so is eraId. Answers { bossId,
-- placeId, bossName, placeName, areaId, areaName }, areaId the area the instance's zone page is
-- keyed by (a) and areaName its AreaTable name (an, else the name). Pure over the index and the map.
function BossLoot.BossOf(index, map, key, creatureId, eraId)
  if type(index) ~= "table" or type(map) ~= "table" then
    return nil
  end
  local kind, id = nil, nil
  if type(key) == "string" then
    kind, id = key:match("^(%a+):(%-?%d+)$")
    id = tonumber(id)
  end
  local held = nil
  if kind == "npc" and id and id > 0 then
    held = map.byId[id]
  elseif kind == "npc" and id and id < 0 then
    local EraSources = ItemTree.EraSources
    local pageId = type(EraSources) == "table" and type(EraSources.PageId) == "function" and EraSources.PageId(key)
    held = pageId and type(map.byPage) == "table" and map.byPage[pageId] or nil
  end
  if not held and type(creatureId) == "number" then
    held = map.byId[creatureId]
  end
  if not held and type(eraId) == "number" and type(map.byPage) == "table" then
    held = map.byPage[eraId]
  end
  if not held then
    return nil
  end
  local place = index.p[held.placeId]
  local boss = index.b[held.bossId]
  if type(place) ~= "table" or type(boss) ~= "table" then
    return nil
  end
  local placeName = str(index, place.n)
  return {
    bossId = held.bossId,
    placeId = held.placeId,
    bossName = str(index, boss.n),
    placeName = placeName,
    areaId = tonumber(place.a),
    areaName = str(index, place.an) or placeName,
  }
end

--------------------------------------------------------------------------------------------------
-- Matching, merging, sorting and grouping
--------------------------------------------------------------------------------------------------

-- A name or a zone as the collector's by name index keys it: lower case, trimmed.
function BossLoot.Fold(text)
  if type(text) ~= "string" then
    return nil
  end
  local folded = string.lower(text):match("^%s*(.-)%s*$")
  if folded == "" then
    return nil
  end
  return folded
end

-- The collector's drop records for one entry, out of C:DropsBySource's answer (drops): by
-- creature id where the entry has c, and otherwise, for a boss or rare with no creature id (a
-- Forever only encounter), by its name together with the place's name or AreaTable name as the
-- zone. A chest has no creature and is never matched by name. A fresh list.
function BossLoot.DropsFor(index, boss, place, drops)
  local out = {}
  if type(boss) ~= "table" or type(drops) ~= "table" then
    return out
  end
  if type(boss.c) == "table" and #boss.c > 0 then
    local byId = type(drops.byId) == "table" and drops.byId or EMPTY
    for _, creatureId in ipairs(boss.c) do
      for _, record in ipairs(byId[creatureId] or EMPTY) do
        out[#out + 1] = record
      end
    end
    return out
  end
  if boss.r == BossLoot.RANK_CHEST or type(place) ~= "table" then
    return out
  end
  local byName = type(drops.byName) == "table" and drops.byName or EMPTY
  local name = BossLoot.Fold(str(index, boss.n))
  if not name then
    return out
  end
  local seenZone = {}
  for _, at in ipairs({ place.n, place.an }) do
    local zone = BossLoot.Fold(str(index, at))
    if zone and not seenZone[zone] then
      seenZone[zone] = true
      for _, record in ipairs(byName[name .. "\0" .. zone] or EMPTY) do
        out[#out + 1] = record
      end
    end
  end
  return out
end

-- The shipped rows and the collector's records as one list, one row per item:
--
--   { id, type, ilvl, verified, seen, chance, questOnly, community }
--
-- decoded is DecodeLoot's stride 4 array; records the collector's drop records for this entry.
-- Brief DL1: community is DecodeLoot's array of the entry's cl, rows marked community = true after
-- the Classic Era rows, an item the Era rows list kept as the Era row; brief DL1b: with no chance.
-- An item the collector has seen is one verified row, its seen the sum over its records, and keeps
-- the shipped chance (for the tooltip) where the index lists it too; a community row it replaces is
-- no longer community.
-- typeOf(id, record) answers the type and item level of an item only the collector knows
-- (defaults: Other, 0).
function BossLoot.Merge(decoded, records, typeOf, community)
  local rows, byId = {}, {}
  local function shipped(list, fromCommunity)
    for at = 1, #list - 3, 4 do
      local id = list[at]
      if not byId[id] then
        local chance, questOnly = BossLoot.SplitValue(list[at + 1])
        local row = {
          id = id,
          type = list[at + 2],
          ilvl = list[at + 3],
          verified = false,
          seen = 0,
          chance = chance,
          questOnly = questOnly,
        }
        if fromCommunity then
          -- Brief DL1b (the owner's ruling of 2026-10-20): a community row carries no chance,
          -- whatever its record's value says.
          row.community = true
          row.chance = nil
          row.questOnly = false
        end
        rows[#rows + 1] = row
        byId[id] = row
      end
    end
  end
  shipped(type(decoded) == "table" and decoded or EMPTY, false)
  shipped(type(community) == "table" and community or EMPTY, true)
  for _, record in ipairs(type(records) == "table" and records or EMPTY) do
    local id = type(record) == "table" and tonumber(record.itemId) or nil
    if id then
      local row = byId[id]
      if not row then
        local code, ilvl = BossLoot.TYPE_OTHER, 0
        if type(typeOf) == "function" then
          local known, level = typeOf(id, record)
          code = tonumber(known) or code
          ilvl = tonumber(level) or ilvl
        end
        row = { id = id, type = code, ilvl = ilvl, verified = false, seen = 0, questOnly = false }
        rows[#rows + 1] = row
        byId[id] = row
      end
      row.verified = true
      row.community = nil
      row.seen = row.seen + (tonumber(record.seen) or 1)
    end
  end
  return rows
end

-- The order within the list (the owner's answer d): type code, then verified rows first by seen
-- descending, item level descending and name; then the shipped rows by chance descending (none
-- last), item level descending and id.
local function before(a, b)
  local ta, tb = a.type or BossLoot.TYPE_OTHER, b.type or BossLoot.TYPE_OTHER
  if ta ~= tb then
    return ta < tb
  end
  if a.verified ~= b.verified then
    return a.verified == true
  end
  if a.verified then
    if (a.seen or 0) ~= (b.seen or 0) then
      return (a.seen or 0) > (b.seen or 0)
    end
    if (a.ilvl or 0) ~= (b.ilvl or 0) then
      return (a.ilvl or 0) > (b.ilvl or 0)
    end
    local na, nb = a.name or "", b.name or ""
    if na ~= nb then
      return na < nb
    end
    return a.id < b.id
  end
  local ca, cb = a.chance or -1, b.chance or -1
  if ca ~= cb then
    return ca > cb
  end
  if (a.ilvl or 0) ~= (b.ilvl or 0) then
    return (a.ilvl or 0) > (b.ilvl or 0)
  end
  return a.id < b.id
end

-- Sorts the rows in place and answers them.
function BossLoot.Sort(rows)
  if type(rows) ~= "table" then
    return {}
  end
  table.sort(rows, before)
  return rows
end

-- Sorted rows as their type groups, in type code order: { { type, word, count, rows }, ... }.
function BossLoot.Group(rows)
  local groups, current = {}, nil
  for _, row in ipairs(type(rows) == "table" and rows or EMPTY) do
    local code = row.type or BossLoot.TYPE_OTHER
    if not current or current.type ~= code then
      current = { type = code, word = BossLoot.TypeWord(code), count = 0, rows = {} }
      groups[#groups + 1] = current
    end
    current.count = current.count + 1
    current.rows[current.count] = row
  end
  return groups
end

-- What the pane says for an entry nobody knows the loot of (the owner's answer a): the title and
-- the line under it.
function BossLoot.NothingKnown()
  return L["Nothing known yet"], L["ItemTree lists what you loot here as you play"]
end

--------------------------------------------------------------------------------------------------
-- The LRU and the GC plan
--------------------------------------------------------------------------------------------------

local Cache = {}
Cache.__index = Cache

-- A least recently used map of at most cap entries (default 3). Get and Put both count as a use.
function BossLoot.NewCache(cap)
  local size = tonumber(cap) or BossLoot.CACHE_CAP
  if size < 1 then
    size = 1
  end
  return setmetatable({ cap = math.floor(size), order = {}, values = {} }, Cache)
end

local function touch(cache, key)
  local order = cache.order
  for at = #order, 1, -1 do
    if order[at] == key then
      table.remove(order, at)
    end
  end
  order[#order + 1] = key
end

function Cache:Get(key)
  local value = self.values[key]
  if value ~= nil then
    touch(self, key)
  end
  return value
end

-- Stores a value, and answers the key it evicted, if any.
function Cache:Put(key, value)
  local evicted = nil
  if self.values[key] == nil and #self.order >= self.cap then
    evicted = table.remove(self.order, 1)
    self.values[evicted] = nil
  end
  self.values[key] = value
  touch(self, key)
  return evicted
end

function Cache:Clear()
  self.order = {}
  self.values = {}
end

function Cache:Size()
  return #self.order
end

-- The keys, least recent first. A fresh list.
function Cache:Keys()
  local out = {}
  for at, key in ipairs(self.order) do
    out[at] = key
  end
  return out
end

-- Whether to step the garbage collector after the tab lets go of its rows: "step" when the heap
-- has grown by more than thresholdKB (default 8,192) since the mark taken when the tab was
-- shown, otherwise "none". Never "collect".
function BossLoot.GCPlan(countKB, markKB, thresholdKB)
  local count, mark = tonumber(countKB), tonumber(markKB)
  local threshold = tonumber(thresholdKB) or BossLoot.GC_THRESHOLD_KB
  if not count or not mark then
    return "none"
  end
  if count - mark > threshold then
    return "step"
  end
  return "none"
end

--------------------------------------------------------------------------------------------------
-- The reader
--------------------------------------------------------------------------------------------------

-- The name a row draws where the Names module does not hold the item: Core/Graph.lua's neutral
-- placeholder, never the client.
local function placeholder(id)
  local Graph = ItemTree.Graph
  if type(Graph) == "table" and type(Graph.UndiscoveredName) == "function" then
    local ok, name = pcall(Graph.UndiscoveredName, { id = id })
    if ok and type(name) == "string" then
      return name
    end
  end
  return L["Undiscovered item"]
end

-- Brief GS5, lifted out of UI/BossLoot.lua by brief Z4 so a zone page lists the same rows: the
-- Predicted rows of a boss entry that has creature ids (c), every item whose guessed source names
-- one of those creatures as a new creature (Core/GuessSources.lua specific type 5,
-- R:ItemsForCreature), and of an entry with a Classic Era page (ei), every item whose guessed source
-- names that Era creature (specific type 1, R:ItemsForEraCreature). Brief EK2: a type 1 ref is the
-- creature id the Classic Era table states for the name (ci), and so is the entry's ei, so the two
-- are compared as numbers and the Era table is never built. An item already among the known rows
-- (known, the rows of the entry's M:Loot answer) is left out, since a real row always replaces a
-- guess, and so is an item no player can get or one already listed off another of the entry's
-- creatures. Empty with either
-- Show predicted data or Show guessed sources off (the reader answers nothing then). Names, icons
-- and qualities come from the shipped Names module (Data:ItemGlance), never the client. Strong
-- before Likely, then by item id. The rate column and its tooltip are the tab's to add
-- (UIBossLoot.GuessRows).
--
--   { id, name, quality, icon, era, type, ilvl, verified = false, seen = 0, guess, confidence,
--     basis, badges }
function BossLoot.GuessRows(entry, known)
  local out = {}
  local reader = ItemTree.guessSources
  if type(entry) ~= "table" or type(reader) ~= "table" then
    return out
  end
  -- Every guess naming this entry: the new creatures by creature id, then the Era creature by ei.
  local found = {}
  local function gather(method, ref)
    if type(reader[method]) ~= "function" or ref == nil then
      return
    end
    local ok, guesses = pcall(reader[method], reader, ref)
    for _, guess in ipairs(ok and type(guesses) == "table" and guesses or EMPTY) do
      found[#found + 1] = guess
    end
  end
  for _, creatureId in ipairs(type(entry.c) == "table" and entry.c or EMPTY) do
    gather("ItemsForCreature", tonumber(creatureId))
  end
  gather("ItemsForEraCreature", tonumber(entry.ei))
  if #found == 0 then
    return out
  end
  -- An item two of the entry's creatures are guessed for is listed once, at its stronger guess.
  table.sort(found, function(a, b)
    local sa, sb = tonumber(a.strength) or 9, tonumber(b.strength) or 9
    if sa ~= sb then
      return sa < sb
    end
    return (tonumber(a.item) or 0) < (tonumber(b.item) or 0)
  end)
  local taken = {}
  for _, row in ipairs(type(known) == "table" and known or EMPTY) do
    if type(row) == "table" and row.id ~= nil then
      taken[row.id] = true
    end
  end
  local data = ItemTree.Data
  local Confidence = ItemTree.Confidence or EMPTY
  local Discoveries = ItemTree.Discoveries
  local settings = ItemTree.db and ItemTree.db.settings
  settings = type(settings) == "table" and settings or EMPTY
  local badgeOpts = { badgesNew = settings.badgesNew ~= false, badgesChanged = settings.badgesChanged ~= false }
  for _, guess in ipairs(found) do
    local id = guess.item
    local hidden = false
    if type(data) == "table" and type(data.IsHidden) == "function" then
      local asked, answer = pcall(data.IsHidden, data, id)
      hidden = asked and answer and true or false
    end
    if type(id) == "number" and not taken[id] and not hidden then
      taken[id] = true
      local glance = nil
      if type(data) == "table" and type(data.ItemGlance) == "function" then
        local asked, answer = pcall(data.ItemGlance, data, id)
        glance = asked and type(answer) == "table" and answer or nil
      end
      local row = {
        id = id,
        name = glance and glance.name or placeholder(id),
        quality = glance and glance.quality or nil,
        icon = glance and glance.icon or nil,
        era = glance and glance.era or nil,
        type = BossLoot.TypeForClass(glance and glance.class),
        ilvl = 0,
        verified = false,
        seen = 0,
        guess = { strength = guess.strength, why = guess.why, whyWords = guess.whyWords },
        confidence = Confidence.GUESS or "guess",
        basis = Confidence.BASIS_GUESS or "guess",
        badges = {},
      }
      if type(Discoveries) == "table" and type(Discoveries.Badges) == "function" then
        local asked, badges = pcall(Discoveries.Badges, id, badgeOpts)
        row.badges = asked and type(badges) == "table" and badges or {}
      end
      out[#out + 1] = row
    end
  end
  table.sort(out, function(a, b)
    local sa, sb = a.guess.strength or 9, b.guess.strength or 9
    if sa ~= sb then
      return sa < sb
    end
    return a.id < b.id
  end)
  return out
end

local M = {}
M.__index = M

-- opts, every field optional:
--   data       the Data layer (ItemTree.Data)
--   collector  the collector (ItemTree.collector, read at call time)
--   settings   the saved settings table, or a function answering it (ItemTree.db.settings)
--   cap        the LRU's size (3)
function BossLoot.New(opts)
  opts = type(opts) == "table" and opts or EMPTY
  local model = setmetatable({}, M)
  model.data = opts.data
  model.collector = opts.collector
  model.settings = opts.settings
  model.cache = BossLoot.NewCache(opts.cap or BossLoot.CACHE_CAP)
  model.places = nil
  model.placeOf = nil
  model.typeMap = nil
  model.malformed = 0
  model.decodes = 0
  return model
end

function M:Data()
  return self.data or ItemTree.Data
end

function M:Collector()
  if self.collector ~= nil then
    return self.collector
  end
  return ItemTree.collector
end

function M:Settings()
  local settings = self.settings
  if type(settings) == "function" then
    local ok, answer = pcall(settings)
    settings = ok and answer or nil
  end
  if type(settings) ~= "table" then
    local db = ItemTree.db
    settings = type(db) == "table" and db.settings or nil
  end
  if type(settings) ~= "table" then
    return EMPTY
  end
  return settings
end

-- The index, or nil and a plain reason (no module, or a version this reader refuses).
function M:Index()
  local data = self:Data()
  if type(data) ~= "table" or type(data.Get) ~= "function" then
    return nil, "no data layer"
  end
  local ok, index = pcall(data.Get, data, BossLoot.MODULE)
  if not ok then
    return nil, "the Boss loot data could not be read"
  end
  return BossLoot.Check(index)
end

-- The place list (PlaceRows), built once and kept for the session. An empty list and the reason
-- where the index cannot be read.
function M:Places()
  if self.places then
    return self.places
  end
  local index, err = self:Index()
  if not index then
    return {}, err
  end
  self.places = BossLoot.PlaceRows(index)
  local placeOf = {}
  for id, place in ipairs(index.p) do
    for _, bossId in ipairs(type(place) == "table" and type(place.b) == "table" and place.b or EMPTY) do
      if placeOf[bossId] == nil then
        placeOf[bossId] = id
      end
    end
  end
  self.placeOf = placeOf
  return self.places
end

-- One place's entries (BossRows). An empty list for a place the index does not hold.
function M:Bosses(placeId)
  local index, err = self:Index()
  if not index then
    return {}, err
  end
  return BossLoot.BossRows(index, placeId)
end

-- The creature page an entry opens, or nil.
function M:CreatureKey(bossId)
  local index = self:Index()
  if not index then
    return nil
  end
  return BossLoot.CreatureKeyOf(index.b[bossId])
end

-- The place an entry belongs to.
function M:PlaceOf(bossId)
  if not self.placeOf then
    self:Places()
  end
  return self.placeOf and self.placeOf[bossId] or nil
end

-- Brief NP3: the place a creature page's creature is a boss of (BossLoot.BossOf), or nil. The map
-- is read off the index once and kept with the model, so a creature page asks a table lookup.
function M:BossOfCreature(key, creatureId, eraId)
  local index = self:Index()
  if not index then
    return nil
  end
  if not self.creatureBosses then
    self.creatureBosses = BossLoot.CreatureBossMap(index)
  end
  return BossLoot.BossOf(index, self.creatureBosses, key, creatureId, eraId)
end

-- The settings the rows depend on, as one string, so a held answer made under other settings,
-- other collector records or other data is made again.
local function stamp(self, settings)
  local data = self:Data()
  local Collector = ItemTree.Collector
  return table.concat({
    tostring(settings.showPredicted ~= false),
    tostring(settings.showEraDetails ~= false),
    tostring(settings.badgesNew ~= false),
    tostring(settings.badgesChanged ~= false),
    tostring(type(Collector) == "table" and Collector.generation or 0),
    tostring(type(data) == "table" and data.generation or 0),
  }, "|")
end

-- The packed loot fields of an entry: its Classic Era loot and (brief DL1) its community drops.
local LOOT_FIELDS = { "l", "cl" }

-- The type and item level the index gives an item anywhere, for a row only the collector knows:
-- one pass over every l and cl, made the first time such a row turns up and let go by Release. The
-- item's class (Names) where no entry lists it.
local function typeOf(self, index, id, glance)
  if not self.typeMap then
    local map = {}
    for _, boss in ipairs(index.b) do
      -- Brief DL1: the community drops (cl) state an item's type and level as l does.
      for _, field in ipairs(LOOT_FIELDS) do
        local packed = type(boss) == "table" and boss[field] or nil
        if type(packed) == "string" then
          local decoded = BossLoot.DecodeLoot(packed)
          for at = 1, #decoded - 3, 4 do
            if map[decoded[at]] == nil then
              map[decoded[at]] = decoded[at + 2] * 65536 + decoded[at + 3]
            end
          end
        end
      end
    end
    self.typeMap = map
  end
  local packed = self.typeMap[id]
  if packed then
    return math.floor(packed / 65536), packed % 65536
  end
  return BossLoot.TypeForClass(glance and glance.class), 0
end

-- Brief DL1: a community row's rate column and tooltip line. Brief DL1b (the owner's ruling of
-- 2026-10-20, his weak indicator rule's spirit: a thin third-party number is not shown as fact): the
-- column stays empty, and the tooltip line is the words its provenance has everywhere ("Community
-- note"), never a Classic Era figure.
local function communityRate(row)
  local Sources = ItemTree.Sources
  row.note = nil
  row.rate = nil
  row.rateTip = nil
  if type(Sources) == "table" and type(Sources.ProvenanceLabel) == "function" then
    row.rateTip = Sources.ProvenanceLabel(BossLoot.PROVENANCE_COMMUNITY)
  end
end

-- The rate column and its tooltip line for a row.
local function rateOf(row)
  if row.community and not row.verified then
    communityRate(row)
    return
  end
  local Sources = ItemTree.Sources
  local note = nil
  if row.questOnly and type(Sources) == "table" and type(Sources.OnlyQuest) == "function" then
    note = Sources.OnlyQuest()
  end
  local historical, tip = nil, nil
  if row.chance and type(Sources) == "table" and type(Sources.HistoricalRate) == "function" then
    historical, tip = Sources.HistoricalRate(row.chance)
  end
  -- Brief LF1 (QA item 248): the qualifier in brackets after the rate's words, "About 80% in
  -- Classic Era (only while on a quest)", or alone where there are none.
  if note and type(Sources.Qualified) == "function" then
    tip = Sources.Qualified(tip, note)
  end
  row.note = note
  if row.verified then
    row.rate = string.format(L["Seen %d"], row.seen or 0)
    row.rateTip = tip
  else
    row.rate = historical
    row.rateTip = tip
  end
end

local function badgeOpts(settings)
  return { badgesNew = settings.badgesNew ~= false, badgesChanged = settings.badgesChanged ~= false }
end

-- One entry's loot, the whole answer the right column draws:
--
--   {
--     boss,             BossRows' row for the entry
--     place,            the place's id
--     rows,             the sorted rows, each { id, name, quality, icon, era, type, ilvl,
--                       verified, seen, chance, questOnly, note, rate, rateTip, confidence,
--                       basis, badges }, and on a community drop (brief DL1) community = true
--                       and provenance "community"
--     groups,           Group(rows)
--     locked,           shipped rows left out because the item is not yet found on the realm
--                       and Classic Era details are off (Data:EraUnlocked false)
--     predictedHidden,  shipped rows left out because showPredicted is off
--     worldDrops,       w, the world drops the index left out
--     malformed,        records DecodeLoot could not read
--     nothingKnown,     true where neither the index nor the collector knows anything
--   }
--
-- nil and a reason for an entry the index does not hold. Held in the LRU by place until Release,
-- and made again when the settings, the collector's records or the data move on.
function M:Loot(bossId)
  local index, err = self:Index()
  if not index then
    return nil, err
  end
  local boss = index.b[bossId]
  if type(boss) ~= "table" then
    return nil, "no such entry"
  end
  local placeId = self:PlaceOf(bossId)
  local settings = self:Settings()
  local key = stamp(self, settings)
  local held = placeId and self.cache:Get(placeId) or nil
  if held and held.stamp == key and held.rows[bossId] then
    return held.rows[bossId]
  end

  local data = self:Data()
  local decoded, malformed = BossLoot.DecodeLoot(boss.l)
  -- Brief DL1: the entry's community drops, read the same way.
  local community, badCommunity = BossLoot.DecodeLoot(boss.cl)
  malformed = malformed + badCommunity
  self.decodes = self.decodes + 1
  self.malformed = self.malformed + malformed

  local records = {}
  local collector = self:Collector()
  if type(collector) == "table" and type(collector.DropsBySource) == "function" then
    local ok, drops = pcall(collector.DropsBySource, collector)
    if ok then
      records = BossLoot.DropsFor(index, boss, index.p[placeId], drops)
    end
  end

  local glances = {}
  local function glance(id)
    local answer = glances[id]
    if answer == nil then
      answer = false
      if type(data) == "table" and type(data.ItemGlance) == "function" then
        answer = data:ItemGlance(id) or false
      end
      glances[id] = answer
    end
    return answer or nil
  end

  local merged = BossLoot.Merge(decoded, records, function(id)
    return typeOf(self, index, id, glance(id))
  end, community)

  local showPredicted = settings.showPredicted ~= false
  local opts = badgeOpts(settings)
  local Discoveries = ItemTree.Discoveries
  local Confidence = ItemTree.Confidence or EMPTY
  local rows, locked, predictedHidden = {}, 0, 0
  for _, row in ipairs(merged) do
    local id = row.id
    local hidden = type(data) == "table" and type(data.IsHidden) == "function" and data:IsHidden(id)
    if not hidden then
      local keep = true
      if not row.verified then
        if not showPredicted then
          predictedHidden = predictedHidden + 1
          keep = false
        elseif type(data) == "table" and type(data.EraUnlocked) == "function" and not data:EraUnlocked(id) then
          locked = locked + 1
          keep = false
        end
      end
      if keep then
        local seen = glance(id)
        row.name = seen and seen.name or placeholder(id)
        row.quality = seen and seen.quality or nil
        row.icon = seen and seen.icon or nil
        row.era = seen and seen.era or nil
        if row.verified then
          row.confidence = Confidence.VERIFIED or "verified"
        elseif row.community then
          -- Brief DL1: Predicted, its basis the community's (no Classic Era words on its badge).
          row.confidence = Confidence.PREDICTED or "predicted"
          row.basis = BossLoot.BASIS_COMMUNITY
          row.provenance = BossLoot.PROVENANCE_COMMUNITY
        else
          row.confidence = Confidence.PREDICTED or "predicted"
          row.basis = Confidence.BASIS_ERA or "era"
        end
        rateOf(row)
        if type(Discoveries) == "table" and type(Discoveries.Badges) == "function" then
          row.badges = Discoveries.Badges(id, opts)
        else
          row.badges = {}
        end
        rows[#rows + 1] = row
      end
    end
  end
  BossLoot.Sort(rows)

  local bossRow = nil
  for _, candidate in ipairs(BossLoot.BossRows(index, placeId)) do
    if candidate.id == bossId then
      bossRow = candidate
    end
  end
  local answer = {
    boss = bossRow,
    place = placeId,
    rows = rows,
    groups = BossLoot.Group(rows),
    locked = locked,
    predictedHidden = predictedHidden,
    worldDrops = tonumber(boss.w) or 0,
    malformed = malformed,
    nothingKnown = #merged == 0,
  }

  if placeId then
    if not held or held.stamp ~= key then
      held = { stamp = key, rows = {} }
      self.cache:Put(placeId, held)
    end
    held.rows[bossId] = answer
  end
  return answer
end

-- Brief Z4: what one instance's bosses drop, as its zone page's Here tab lists it: every row the
-- Boss loot tab lists for each of the place's entries (M:Loot's known rows, the collector's seen
-- drops and the index's Classic Era loot, then BossLoot.GuessRows' Predicted rows), one row per
-- item, the first entry to list it keeping it and a known row always winning over a guess. Each is
-- the tab's own row (a fresh copy) with bossId and bossName beside it, in the place's entry order,
-- the known rows before the guesses. Empty for a place the index does not hold.
function M:PlaceDrops(placeId)
  local out = {}
  local index = self:Index()
  local place = index and index.p[placeId] or nil
  if type(place) ~= "table" then
    return out
  end
  local ids = type(place.b) == "table" and place.b or EMPTY
  local taken, known = {}, {}
  local function add(bossId, row)
    if type(row) ~= "table" or type(row.id) ~= "number" or taken[row.id] then
      return
    end
    taken[row.id] = true
    local copy = {}
    for key, value in pairs(row) do
      copy[key] = value
    end
    copy.bossId = bossId
    copy.bossName = str(index, type(index.b[bossId]) == "table" and index.b[bossId].n or nil)
    out[#out + 1] = copy
  end
  for _, bossId in ipairs(ids) do
    local answer = self:Loot(bossId)
    known[bossId] = type(answer) == "table" and answer.rows or EMPTY
    for _, row in ipairs(known[bossId]) do
      add(bossId, row)
    end
  end
  for _, bossId in ipairs(ids) do
    for _, row in ipairs(BossLoot.GuessRows(index.b[bossId], known[bossId])) do
      add(bossId, row)
    end
  end
  return out
end

-- Brief Z4: the one model a page outside the Boss loot tab reads through (a zone page's Here tab),
-- made on the first ask and kept. The tab keeps its own (UIBossLoot.model), whose Release this one
-- does not share.
function BossLoot.Shared()
  if not BossLoot.shared then
    BossLoot.shared = BossLoot.New({})
  end
  return BossLoot.shared
end

-- Lets go of every decoded row and the type map, which is what the tab does when it is hidden.
-- The place list stays for the session, and the module and Names stay in Data's own cache.
function M:Release()
  self.cache:Clear()
  self.typeMap = nil
end

-- What the reader holds, for /itemtree debug: { loaded, refused, places, bosses, cachedPlaces,
-- cachedBosses, decodes, malformed }.
function M:Counts()
  local data = self:Data()
  local cache = type(data) == "table" and type(data.cache) == "table" and data.cache or EMPTY
  local index = cache[BossLoot.MODULE]
  local _, refused = BossLoot.Check(index)
  local cachedBosses = 0
  for _, held in pairs(self.cache.values) do
    for _ in pairs(held.rows) do
      cachedBosses = cachedBosses + 1
    end
  end
  local ok = refused == nil
  return {
    loaded = index ~= nil,
    refused = index ~= nil and refused or nil,
    places = ok and #index.p or 0,
    bosses = ok and #index.b or 0,
    cachedPlaces = self.cache:Size(),
    cachedBosses = cachedBosses,
    decodes = self.decodes,
    malformed = self.malformed,
  }
end

--------------------------------------------------------------------------------------------------
-- Brief DL1: the community drops in the graph
--------------------------------------------------------------------------------------------------

-- The community drops of one index both ways round, built once per index table and kept against
-- it (a spec handing over another table is answered from that one). Pure:
--
--   byItem      { [itemId] = { { creature, zone, areaId }, ... } }, one per creature in c
--   byCreature  { [creatureId] = { { item }, ... } }
--
-- zone is the place's name and areaId its area (nil where the index states none); brief DL1b: no
-- chance, whatever a record's value says. nil for a table that is no index.
local communityFor, communityOf = nil, nil

function BossLoot.CommunityIndex(index)
  if type(index) ~= "table" or type(index.b) ~= "table" then
    return nil
  end
  if communityFor == index and communityOf then
    return communityOf
  end
  local placeOf = {}
  for _, place in ipairs(type(index.p) == "table" and index.p or EMPTY) do
    for _, bossId in ipairs(type(place) == "table" and type(place.b) == "table" and place.b or EMPTY) do
      if placeOf[bossId] == nil then
        placeOf[bossId] = place
      end
    end
  end
  local out = { byItem = {}, byCreature = {} }
  for bossId, boss in ipairs(index.b) do
    if type(boss) == "table" and type(boss.cl) == "string" and type(boss.c) == "table" then
      local place = placeOf[bossId]
      local zone = place and type(index.s) == "table" and str(index, place.n) or nil
      local areaId = place and tonumber(place.a) or nil
      local decoded = BossLoot.DecodeLoot(boss.cl)
      for at = 1, #decoded - 3, 4 do
        local item = decoded[at]
        for _, creatureId in ipairs(boss.c) do
          local creature = tonumber(creatureId)
          if creature then
            local sources = out.byItem[item] or {}
            out.byItem[item] = sources
            sources[#sources + 1] = { creature = creature, zone = zone, areaId = areaId }
            local drops = out.byCreature[creature] or {}
            out.byCreature[creature] = drops
            drops[#drops + 1] = { item = item }
          end
        end
      end
    end
  end
  communityFor, communityOf = index, out
  return out
end

-- The shipped index where the data addon is loaded already, else nil: a walk never loads it for
-- these rows (a tooltip, a bag pass or a chain at login never pays for them). The Sources view's own
-- walk has the data addon loaded (the Classic Era table is asked first), and so has a session that
-- loads it at login (the default).
local function communityIndex()
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.Get) ~= "function" then
    return nil
  end
  local modules = type(data.modules) == "table" and data.modules or EMPTY
  local cache = type(data.cache) == "table" and data.cache or EMPTY
  if modules[BossLoot.MODULE] == nil and cache[BossLoot.MODULE] == nil then
    return nil
  end
  local ok, index = pcall(data.Get, data, BossLoot.MODULE)
  if not ok then
    return nil
  end
  return BossLoot.CommunityIndex(BossLoot.Check(index))
end

-- Whether an item's shipped rows may be shown: Classic Era details lock an item the realm has not
-- found yet (Data:EraUnlocked), as they lock its Classic Era rows on the Boss loot tab.
local function unlocked(itemId)
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.EraUnlocked) ~= "function" then
    return true
  end
  local ok, answer = pcall(data.EraUnlocked, data, itemId)
  return not ok or answer ~= false
end

-- Brief DL1b: no percent, so the Sources row's rate column stays empty.
local function communityEdge(def, target, group, zone, areaId)
  local Confidence = ItemTree.Confidence or EMPTY
  return {
    type = def,
    target = target,
    group = group,
    confidence = Confidence.PREDICTED or "predicted",
    basis = BossLoot.BASIS_COMMUNITY,
    provenance = BossLoot.PROVENANCE_COMMUNITY,
    zone = zone,
    areaId = areaId,
  }
end

-- Edges for Graph.RegisterProvider. Walking up from an item: DROPPED_BY, "Drops from" each creature
-- of an entry whose community drops list it, the place as its zone, no rate (brief DL1b). Walking
-- down from a creature: CREATURE_DROPS, its page's Drops. Every edge is Predicted
-- with community provenance, so the player's own record of the same source (verified) takes its row
-- (Core/Graph.lua's merge), a guess naming the same creature folds into it (Graph.DropGuessEdges),
-- and Show predicted data off drops it. Any other key answers nothing without reading anything.
function BossLoot.EdgesFor(key, direction)
  local Graph, Edges = ItemTree.Graph, ItemTree.Edges
  if type(Graph) ~= "table" or type(Edges) ~= "table" or type(Graph.Parse) ~= "function" then
    return EMPTY
  end
  local kind, id = Graph.Parse(key)
  local up = kind == "item" and direction == Edges.UP
  local down = kind == "npc" and direction == Edges.DOWN
  if type(id) ~= "number" or not (up or down) then
    return EMPTY
  end
  local community = communityIndex()
  if not community then
    return EMPTY
  end
  local T = Edges.Types
  local out = {}
  if up then
    local sources = community.byItem[id]
    if not sources or not unlocked(id) then
      return EMPTY
    end
    for _, source in ipairs(sources) do
      local target = Graph.Key("npc", source.creature)
      out[#out + 1] = communityEdge(T.DROPPED_BY, target, L["Drops from"], source.zone, source.areaId)
    end
    return out
  end
  for _, drop in ipairs(community.byCreature[id] or EMPTY) do
    if unlocked(drop.item) then
      out[#out + 1] = communityEdge(T.CREATURE_DROPS, Graph.Key("item", drop.item), L["Drops"])
    end
  end
  return out
end

-- Client side. Guarded
--
-- The model makes no client call at all. UI/BossLoot.lua (brief BL3) owns the pane, the GC ticker
-- and every client read.

--- Brief DL1: registers BossLoot.EdgesFor with the graph, once. Marked as a provider Graph.Summary
--- skips (Predicted edges alone), as Core/PlayerSources.lua's is, so a tooltip never asks it.
function BossLoot.Install()
  local Graph = ItemTree.Graph
  if type(Graph) ~= "table" or type(Graph.RegisterProvider) ~= "function" then
    return false
  end
  if type(Graph.HasProvider) == "function" and Graph.HasProvider(BossLoot.EdgesFor) then
    return true
  end
  Graph.RegisterProvider(BossLoot.EdgesFor, { predictedOnly = true })
  return true
end

BossLoot.Install()
