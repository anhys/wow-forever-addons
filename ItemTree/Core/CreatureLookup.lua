-- Which ItemTree page a creature in the world opens onto (brief T7). Ctrl + right click on the
-- target frame, the focus frame or a nameplate (UI/ItemClick.lua), and the key binding over a
-- unit's tooltip (UI/Keybind.lua), both come here with a unit token and open what this answers.
-- Loaded as: local _, ItemTree = ...
--
-- The answer, in this order:
--   1. the Classic Era creature page whose name matches the unit's name, npc:-<creature id> (brief
--      EK1, Core/EraSources.lua EraSources.PageKey), which is the key every Classic Era source row
--      that states no place points at, so the page opened from the world is the page the item's
--      Sources tab opens;
--   2. else the page the player's own records keep for that creature id, npc:<id>: a drop or a
--      vendor visit the collector recorded (brief N2), or a vendor the client's own tables list
--      (brief V1, Core/ForeverVendors.lua);
--   3. else (brief T8) the creature's own page, npc:<id>, built from the unit itself: its name,
--      level, classification, creature type and the zone it was seen in, recorded as a sighting
--      (below) so the page, the breadcrumb and the window title can name it. The chat line
--      "Nothing known about <name> yet" is gone.
--
-- Only a Creature or a Vehicle GUID carries a creature id. A player, a pet and anything else
-- answers nothing at all: players are never looked up and never named.
--
-- A found page is cached per creature id for the session, so a second click is one table read.
-- A miss is not cached: a vendor visited a minute later has a record page, and the next click
-- should find it. A miss costs one name map read, one record index read and the handful of unit
-- reads the sighting takes, never a query and never a loop.
--
-- Sightings (brief T8). ItemTreeDB.seenCreatures[npcId] = { npcId, name, zone, mapId, level,
-- classification, creatureType, when }, one record per creature id, updated in place, in the
-- style of the collector's seenBosses (Core/Collector.lua, brief BL14). Written only for a
-- creature ItemTree's data knows nothing about, and only when the player asked for its page, so a
-- later data build or the Boss loot panel can use it. A creature's facts and nothing else: the
-- GUID check refuses players, so no character, realm or account fact reaches it.
--
-- Pure functions first; the unit reads below the divider are guarded, so this file loads and is
-- specced with no WoW API.
local _, ItemTree = ...

local Graph = ItemTree.Graph

local CreatureLookup = {}
ItemTree.CreatureLookup = CreatureLookup

-- The GUID kinds a creature id is read from. The client's GUID for an NPC is
-- "Creature-0-<server>-<instance>-<zone>-<npcId>-<spawn>", and a vehicle's has the same shape.
local CREATURE_KINDS = { Creature = true, Vehicle = true }

--- The creature id in a unit GUID, or nil for a player, a pet, an item or anything malformed.
--- Pure.
function CreatureLookup.CreatureIdFromGuid(guid)
  if type(guid) ~= "string" or guid == "" then
    return nil
  end
  local fields = {}
  for field in guid:gmatch("[^%-]+") do
    fields[#fields + 1] = field
  end
  if not CREATURE_KINDS[fields[1]] or #fields < 7 then
    return nil
  end
  local id = tonumber(fields[6])
  if not id or id <= 0 or id ~= math.floor(id) then
    return nil
  end
  return id
end

-- Brief NC1: the words the client puts in place of a name it has not been sent yet. UnitName
-- answers "Unknown" (the global UNKNOWNOBJECT on an English client) for a creature whose data has
-- not arrived, which is common for Forever's own creatures the first time they are near.
CreatureLookup.PLACEHOLDER_NAMES = { Unknown = true, UNKNOWNOBJECT = true }

--- A creature's name as the lookup and the sighting may use it: nil for no name, an empty one or
--- the client's placeholder (the fixed words above, or placeholder, the client's own
--- UNKNOWNOBJECT string where it has one). A placeholder must not be matched against the Classic
--- Era names or written over a real name already sighted. Pure.
function CreatureLookup.RealName(name, placeholder)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  if CreatureLookup.PLACEHOLDER_NAMES[name] or (type(placeholder) == "string" and name == placeholder) then
    return nil
  end
  return name
end

--- The page to open for one creature. ask carries the two lookups, so a spec passes stubs:
---   ask.eraKey(name)        the Classic Era creature page key for a name, or nil
---   ask.hasRecord(npcId)    true when the player's own records keep a page for the id
--- Returns key, name. key is nil when nothing is known, and name is then what the chat line says.
--- A creature with no id answers nil, nil, which says nothing at all. Pure.
function CreatureLookup.Resolve(creatureId, name, ask)
  if type(creatureId) ~= "number" or creatureId <= 0 then
    return nil, nil
  end
  if type(name) ~= "string" or name == "" then
    name = nil
  end
  ask = type(ask) == "table" and ask or {}
  if name and type(ask.eraKey) == "function" then
    local key = ask.eraKey(name)
    if type(key) == "string" then
      return key, name
    end
  end
  if type(ask.hasRecord) == "function" and ask.hasRecord(creatureId) then
    return Graph.Key("npc", creatureId), name
  end
  return nil, name
end

-- Found pages, keyed by creature id, for the session.
CreatureLookup.cache = {}

--- Forgets every found page and every page's origin. What a spec calls between cases.
function CreatureLookup.Reset()
  CreatureLookup.cache = {}
  CreatureLookup.origins = {}
  -- Brief QI1: and every display id a page's model was drawn with.
  CreatureLookup.displays = {}
end

--- Resolve with the session cache in front of it. Only a found page is kept.
function CreatureLookup.Cached(creatureId, name, ask)
  local held = type(creatureId) == "number" and CreatureLookup.cache[creatureId] or nil
  if held then
    return held, name
  end
  local key, named = CreatureLookup.Resolve(creatureId, name, ask)
  if key then
    CreatureLookup.cache[creatureId] = key
  end
  return key, named
end

-- The Classic Era creature page for a name: found by the name's index in the string table, keyed
-- by its creature id (brief EK1, E:PageKey), and only where the table ships a kind for it (a
-- creature or a vendor), so a quest title or a chest of the same words never opens as a creature.
local function eraKey(name)
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.NameIndexOf) ~= "function" or type(era.PageKey) ~= "function" then
    return nil
  end
  local ok, nameIndex = pcall(era.NameIndexOf, era, name)
  if not ok or type(nameIndex) ~= "number" then
    return nil
  end
  local okKey, key = pcall(era.PageKey, era, nameIndex)
  if not okKey or type(key) ~= "string" then
    return nil
  end
  if type(era.CreatureKind) == "function" then
    local kindOk, kind = pcall(era.CreatureKind, era, key)
    if kindOk and kind then
      return key
    end
  end
  return nil
end

-- Whether the player's own records keep a page for this creature id: a record the collector holds
-- for it, or a vendor the client's tables list.
local function hasRecord(npcId)
  local key = Graph.Key("npc", npcId)
  local collector = ItemTree.collector
  if type(collector) == "table" and type(collector.NpcRecords) == "function" then
    local ok, records = pcall(collector.NpcRecords, collector, key)
    if ok and type(records) == "table" and #records > 0 then
      return true
    end
  end
  local vendors = ItemTree.ForeverVendors
  if type(vendors) == "table" and type(vendors.IsVendor) == "function" then
    local ok, listed = pcall(vendors.IsVendor, key)
    if ok and listed then
      return true
    end
  end
  return false
end

-- The two lookups over ItemTree's own data. A spec replaces this table's fields.
CreatureLookup.ask = { eraKey = eraKey, hasRecord = hasRecord }

-- Brief T8: UnitClassification's answers, as the words the unknown creature page says. A minus or
-- trivial creature is drawn as a normal one by the client's own target frame, and says so here.
CreatureLookup.CLASSIFICATIONS = {
  worldboss = "Boss",
  rareelite = "Rare elite",
  elite = "Elite",
  rare = "Rare",
  normal = "Normal",
  trivial = "Normal",
  minus = "Normal",
}

--- The word for a classification, as its locale key ("Rare elite"), or nil for anything the
--- client does not answer. Pure.
function CreatureLookup.ClassificationWord(classification)
  if type(classification) ~= "string" then
    return nil
  end
  return CreatureLookup.CLASSIFICATIONS[classification]
end

--- A level as the client's target frame writes it: the number, or "??" for a creature too far
--- above the player to say (UnitLevel answers -1). nil for no level at all. Pure.
function CreatureLookup.LevelText(level)
  local n = tonumber(level)
  if not n or n ~= math.floor(n) or n == 0 then
    return nil
  end
  if n < 0 then
    return "??"
  end
  return tostring(n)
end

local positiveWhole = ItemTree.Util.PositiveId

local function text(value)
  if type(value) == "string" and value ~= "" then
    return value
  end
  return nil
end

--- One sighting record, or nil where it says nothing usable. fields is { npcId, name, zone, mapId,
--- level, classification, creatureType } as the client showed the unit; npcId is required, every
--- other field is kept only where it is well formed (a level is a whole number above nought, or
--- -1 for "??"; a classification is one the client answers). Pure.
function CreatureLookup.SightingRecord(fields, when)
  if type(fields) ~= "table" then
    return nil
  end
  local npcId = positiveWhole(fields.npcId)
  if not npcId then
    return nil
  end
  local level = tonumber(fields.level)
  if level and level ~= -1 and not positiveWhole(level) then
    level = nil
  end
  local classification = fields.classification
  if not CreatureLookup.ClassificationWord(classification) then
    classification = nil
  end
  return {
    npcId = npcId,
    name = text(fields.name),
    zone = text(fields.zone),
    mapId = positiveWhole(fields.mapId),
    level = level,
    classification = classification,
    creatureType = text(fields.creatureType),
    when = type(when) == "number" and when or nil,
  }
end

--- The newer record over the older one for the same creature: the newer's fields, and the
--- older's where the newer states none. The newer alone for a different creature. Pure.
function CreatureLookup.MergeSighting(older, newer)
  if type(newer) ~= "table" then
    return older
  end
  if type(older) ~= "table" or older.npcId ~= newer.npcId then
    return newer
  end
  for _, field in ipairs({ "name", "zone", "mapId", "level", "classification", "creatureType" }) do
    if newer[field] == nil then
      newer[field] = older[field]
    end
  end
  return newer
end

-- The sightings store: ItemTreeDB.seenCreatures, made on first write. nil with no saved variables
-- (a spec that loads none, or before the addon has loaded them).
function CreatureLookup.Store(create)
  local db = ItemTree.db
  if type(db) ~= "table" then
    return nil
  end
  if type(db.seenCreatures) ~= "table" then
    if not create then
      return nil
    end
    db.seenCreatures = {}
  end
  return db.seenCreatures
end

--- Stores one sighting, updated in place. Answers the record kept, or nil where it was refused.
function CreatureLookup.RecordSighting(fields, when)
  local record = CreatureLookup.SightingRecord(fields, when)
  if not record then
    return nil
  end
  local store = CreatureLookup.Store(true)
  if not store then
    return nil
  end
  record = CreatureLookup.MergeSighting(store[record.npcId], record)
  store[record.npcId] = record
  return record
end

--- The sighting for one creature id, or nil. The store's own record: read it, never change it.
function CreatureLookup.Sighting(npcId)
  local store = CreatureLookup.Store(false)
  local id = positiveWhole(npcId)
  if not store or not id then
    return nil
  end
  local record = store[id]
  if type(record) ~= "table" or positiveWhole(record.npcId) ~= id then
    return nil
  end
  return record
end

--- The creature id an npc key names, where it is a real one (npc:<id>, id above nought), else nil.
--- A Classic Era creature's page key (npc:-<creature id>, brief EK1) answers nil too: its id is a
--- CMaNGOS creature id, not one the Forever client is known to hold, so no portrait, sighting or
--- Creatures row is looked up by it. (Brief EK1 2b changes what a merged positive key does.) Pure.
function CreatureLookup.IdOfKey(key)
  if type(key) ~= "string" then
    return nil
  end
  return positiveWhole(key:match("^npc:(%d+)$"))
end

--- The namer Graph asks for a node nothing else names: a sighted creature's name for its npc key,
--- so the breadcrumb and the window title say "Prideclaw". A string match and a table read.
function CreatureLookup.Namer(key)
  local id = CreatureLookup.IdOfKey(key)
  local record = id and CreatureLookup.Sighting(id) or nil
  return record and record.name or nil
end

if type(Graph) == "table" and type(Graph.RegisterNamer) == "function" then
  if type(Graph.HasNamer) ~= "function" or not Graph.HasNamer(CreatureLookup.Namer) then
    Graph.RegisterNamer(CreatureLookup.Namer)
  end
end

-- Brief T8: the unit each page was last opened from this session, by key: { npcId, guid }. The
-- creature page reads it to draw its model from the unit while it is still the target, and from
-- the creature id where no display id is shipped. Session only, one entry per page opened.
CreatureLookup.origins = {}

--- Where a page was last opened from a unit: { npcId, guid }, or nil.
function CreatureLookup.Origin(key)
  local origin = type(key) == "string" and CreatureLookup.origins[key] or nil
  if type(origin) ~= "table" then
    return nil
  end
  return origin
end

-- Brief QI1 (owner QA 2026-10-17, feedback item 182: Owen Thadd 211022 wore the generic NPC icon):
-- the display id the client gave a creature page's own model this session, by creature id. A row's
-- portrait and the window's round portrait are drawn from a display id (Core/ViewModel.lua
-- CreatureDisplay and ForeverPortrait); a creature neither the Classic Era table nor the Creatures
-- data knows has none, so its page's model asks the client by creature id (UI/InfoPanel.lua
-- ApplyLiveModel) and the display id the client answers is kept here once it is not 0. Session only;
-- brief DM2 (item 192) also writes it to the saved records (CreatureLookup.SaveDisplay), which
-- SeenDisplay reads after this table, and the next compile's Creatures data is the lasting answer.
CreatureLookup.displays = {}

--- Keeps the display id the client drew a creature's model with. A whole number above nought for
--- each, else nothing is kept. Answers whether it was kept. Pure over the session table.
function CreatureLookup.RememberDisplay(creatureId, display)
  creatureId, display = tonumber(creatureId), tonumber(display)
  if not creatureId or creatureId <= 0 or creatureId ~= math.floor(creatureId) then
    return false
  end
  if not display or display <= 0 or display ~= math.floor(display) then
    return false
  end
  CreatureLookup.displays[creatureId] = display
  return true
end

--- The display id kept for a creature id this session, else (brief DM2, owner QA 2026-10-17 item
--- 192: "after a /reload the portrait is gone again until the model draws") the first one the
--- player's saved records keep for it (CreatureLookup.SavedDisplay), or nil. The session's wins.
--- Table reads only.
function CreatureLookup.SeenDisplay(creatureId)
  creatureId = tonumber(creatureId)
  local display = creatureId and CreatureLookup.displays[creatureId] or nil
  if type(display) ~= "number" then
    return CreatureLookup.SavedDisplay(creatureId)
  end
  return display
end

-- Brief DM2: the collector's creature displays store (Core/Collector.lua, collector.displays),
-- through the collector the addon built at login (ItemTree.collector). Neither call asks the client
-- anything.

--- The first display id the saved records keep for a creature id (C:SavedDisplay), or nil where
--- there is no collector or no record. A table read.
function CreatureLookup.SavedDisplay(creatureId)
  local collector = ItemTree.collector
  creatureId = tonumber(creatureId)
  if not creatureId or type(collector) ~= "table" or type(collector.SavedDisplay) ~= "function" then
    return nil
  end
  local ok, display = pcall(collector.SavedDisplay, collector, creatureId)
  if not ok or type(display) ~= "number" then
    return nil
  end
  return display
end

--- Brief DM2: writes a display id the client confirmed for a creature page's own model into the
--- saved records (C:RecordDisplay), while "Record what you see" (settings.collectorEnabled) is on.
--- Answers whether it was written.
function CreatureLookup.SaveDisplay(creatureId, display)
  local settings = ItemTree.db and ItemTree.db.settings
  local collector = ItemTree.collector
  if type(settings) ~= "table" or not settings.collectorEnabled then
    return false
  end
  if type(collector) ~= "table" or type(collector.RecordDisplay) ~= "function" then
    return false
  end
  local ok, written = pcall(collector.RecordDisplay, collector, tonumber(creatureId), tonumber(display))
  return ok and written == true
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

-- Brief SV1: every unit read here (UnitGUID, UnitName, UnitCreatureType and the rest) answers nil
-- where the client keeps the answer secret, which it does for a creature's identity in combat
-- (UnitDocumentation.lua SecretWhenUnitIdentityRestricted): a click on it then opens nothing.
local canRead = ItemTree.Util.CanRead

local function unitCall(name, unit)
  local fn = rawget(_G, name)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, answer = pcall(fn, unit)
  if not ok or not canRead(answer) then
    return nil
  end
  return answer
end

--- Whether a unit token is a player. Unknown counts as not, since the GUID check refuses a player
--- on its own anyway.
function CreatureLookup.IsPlayer(unit)
  if type(unit) ~= "string" or unit == "" then
    return false
  end
  return unitCall("UnitIsPlayer", unit) and true or false
end

-- The zone the player stands in, as the collector's records name it (UI/CollectorHooks.lua
-- zoneText, GetRealZoneText), and the map id under it. Either nil where the client will not say.
local function hereNow()
  local zone = unitCall("GetRealZoneText", nil)
  local mapId = nil
  local map = rawget(_G, "C_Map")
  if type(map) == "table" and type(map.GetBestMapForUnit) == "function" then
    local ok, answer = pcall(map.GetBestMapForUnit, "player")
    if ok then
      mapId = answer
    end
  end
  return zone, mapId
end

local function clock()
  local fn = rawget(_G, "time")
  if type(fn) ~= "function" then
    return nil
  end
  local ok, at = pcall(fn)
  if ok and type(at) == "number" then
    return at
  end
  return nil
end

--- Brief T8: what the client shows of a creature, as CreatureLookup.SightingRecord takes it. One
--- read of each unit call, made once for the one unit the player clicked.
function CreatureLookup.UnitFacts(unit, creatureId)
  local zone, mapId = hereNow()
  return {
    npcId = creatureId,
    name = CreatureLookup.RealName(unitCall("UnitName", unit), rawget(_G, "UNKNOWNOBJECT")),
    level = unitCall("UnitLevel", unit),
    classification = unitCall("UnitClassification", unit),
    creatureType = unitCall("UnitCreatureType", unit),
    zone = zone,
    mapId = mapId,
  }
end

--- The page for the creature a unit token names: key, name, and true third where it is unknown.
--- key and name are nil for a
--- player, a pet, a unit that does not exist or no client. For a creature ItemTree's data knows
--- nothing about, key is its own npc:<id> page and unknown is true, and the sighting is recorded
--- first so the page has something to draw (brief T8). The unit a page came from is remembered
--- for the session (CreatureLookup.Origin).
function CreatureLookup.ForUnit(unit)
  if type(unit) ~= "string" or unit == "" or CreatureLookup.IsPlayer(unit) then
    return nil, nil
  end
  local guid = unitCall("UnitGUID", unit)
  local creatureId = CreatureLookup.CreatureIdFromGuid(guid)
  if not creatureId then
    return nil, nil
  end
  local name = CreatureLookup.RealName(unitCall("UnitName", unit), rawget(_G, "UNKNOWNOBJECT"))
  local key, named = CreatureLookup.Cached(creatureId, name, CreatureLookup.ask)
  if not key then
    key = Graph.Key("npc", creatureId)
    CreatureLookup.RecordSighting(CreatureLookup.UnitFacts(unit, creatureId), clock())
    CreatureLookup.origins[key] = { npcId = creatureId, guid = guid }
    return key, named, true
  end
  CreatureLookup.origins[key] = { npcId = creatureId, guid = guid }
  return key, named
end

return CreatureLookup
