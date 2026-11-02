-- Brief FE1 (the owner's QA item 398, 2026-10-23): the beta event fence, as the share text applies it.
-- Pure Lua, loaded before Core/Share.lua. Loaded as: local _, ItemTree = ...
--
-- Blizzard closed the Forever beta with the Beta Farewell Tour, a server side event from 17:00 UTC
-- on 22 October 2026 to the beta close 24 hours later: event bosses and Molten Core loot from every
-- mob in the seven starting zones, none of it in the game at launch. The data pipeline fences
-- everything recorded in it (ItemTree-Data's curated/beta_fence.json and its docs/mining.md, "Beta
-- event fence"); this is the same fence one step earlier, defence in depth: the Share your finds
-- text never carries a record whose build and days fall in a fenced window, a record of a build
-- fenced whole, nor one that names a denylisted id. Nothing is ever deleted from the player's own
-- saved records; the share simply leaves those at home.
--
-- The addon cannot tell a record seen before 17:00 on the window's first day from one seen after,
-- nor what of a tally came from inside, so a record of a window's build (or of no build) whose days
-- overlap the window's days stays home whole. A future beta build is real data: only the builds
-- named below are fenced.
--
-- Brief FE2b (the owner's item 420, 2026-10-24; ItemTree-Data's brief FE2): 1.60.1.70532, the beta's
-- last build, which appeared mid event, is also the live Forever build. It is no longer fenced whole:
-- like 1.60.1.70450 it is fenced inside the event's window alone, so what a player records in the
-- live game from launch is shared. No build is fenced whole now; the whole list stays for the config's
-- shape.
local _, ItemTree = ...

local BetaFence = {}
ItemTree.BetaFence = BetaFence

local DAY = 86400

-- BEGIN fence constants: kept in step with ItemTree-Data's curated/beta_fence.json by its test
-- (tests/test_beta_fence.py, "the addon's constants"). Builds are client build numbers, moments
-- whole seconds UTC.
BetaFence.CONFIG = {
  windows = {
    { name = "beta-farewell-tour", builds = { 70450 }, from = 1792688400, to = 1792774800 },
    { name = "beta-farewell-tour-70532", builds = { 70532 }, from = 1792688400, to = 1792774800 },
  },
  whole = {},
  deny = {
    creature = { 278241, 278242, 278243, 278245, 278256, 278271 },
    item = {},
    object = {},
    quest = {},
  },
}
-- END fence constants

local function set(list)
  local out = {}
  for _, value in ipairs(list or {}) do
    out[value] = true
  end
  return out
end

local WHOLE = set(BetaFence.CONFIG.whole)
local DENY = {}
for kind, ids in pairs(BetaFence.CONFIG.deny) do
  DENY[kind] = set(ids)
end
local WINDOWS = {}
for index, window in ipairs(BetaFence.CONFIG.windows) do
  WINDOWS[index] = {
    builds = set(window.builds),
    fromDay = math.floor(window.from / DAY),
    toDay = math.floor(window.to / DAY),
  }
end

local function number(value)
  return type(value) == "number" and value == value and value % 1 == 0 and value or nil
end

--- A build string's client build number ("1.60.1.70450" is 70450), or nil.
function BetaFence.BuildNumber(build)
  if type(build) ~= "string" then
    return number(build)
  end
  return tonumber(build:match("(%d+)$"))
end

--- Whether an id of a kind (creature, item, object, quest) is denylisted.
function BetaFence.Denied(kind, id)
  local ids = DENY[kind]
  return ids ~= nil and ids[number(id) or tonumber(id) or -1] == true
end

--- Whether a record of `build` (a build string or number, or nil where the record states none) seen
--- from day `first` to day `last` (whole days since 1970; either may be nil) stays home: its build is
--- fenced whole, or it is a window's build (or states none) and its days overlap the window's.
function BetaFence.Fenced(build, first, last)
  local buildNumber = build ~= nil and BetaFence.BuildNumber(build) or nil
  if buildNumber and WHOLE[buildNumber] then
    return true
  end
  first, last = number(first) or number(last), number(last) or number(first)
  if not first then
    return false
  end
  for _, window in ipairs(WINDOWS) do
    if (buildNumber == nil or window.builds[buildNumber]) and last >= window.fromDay and first <= window.toDay then
      return true
    end
  end
  return false
end

local function day(seconds)
  seconds = number(seconds)
  return seconds and math.floor(seconds / DAY) or nil
end

-- Collector.lua SOURCE_CODES, as a denylist kind.
local SOURCE_KINDS = { n = "creature", o = "object", q = "quest", i = "item" }
local LONG_SOURCE_KINDS = { npc = "creature", object = "object", quest = "quest", item = "item" }
-- The ledger's kinds and the kind of the id each is keyed by.
local LEDGER_KINDS = {
  creature = "creature",
  object = "object",
  container = "item",
  disenchant = "item",
  vendor = "creature",
  quest = "quest",
}
-- A ledger entry's maps keyed by an item id, whose denylisted entries are stripped.
local ITEM_MAPS = { "i", "q", "iq", "iqw", "c", "s", "a", "d", "r" }

local function dropKeys(store, fenced, counts, what)
  if type(store) ~= "table" then
    return
  end
  for key, record in pairs(store) do
    if fenced(key, record) then
      store[key] = nil
      counts[what] = (counts[what] or 0) + 1
    end
  end
end

local function empty(value)
  return type(value) ~= "table" or next(value) == nil
end

--- The share snapshot (Share.Snapshot's table) with every record the fence keeps home taken out, in
--- place, and the counts taken out by store. Pure apart from the snapshot it changes.
function BetaFence.Filter(snapshot)
  local counts = {}
  if type(snapshot) ~= "table" then
    return snapshot, counts
  end
  local collector = type(snapshot.collector) == "table" and snapshot.collector or {}
  local builds = type(collector.builds) == "table" and collector.builds or {}
  local function buildAt(index)
    return builds[number(index) or 1]
  end
  dropKeys(collector.records, function(key, row)
    if type(row.kind) == "string" then
      if
        BetaFence.Denied("item", row.itemId) or BetaFence.Denied(LONG_SOURCE_KINDS[row.sourceKind] or "", row.sourceId)
      then
        return true
      end
      return BetaFence.Fenced(row.build, day(row.first), day(row.last))
    end
    local code, item, source, id = tostring(key):match("^(%a):(%d+):(%a):(%d+)$")
    if
      code and (BetaFence.Denied("item", tonumber(item)) or BetaFence.Denied(SOURCE_KINDS[source] or "", tonumber(id)))
    then
      return true
    end
    return BetaFence.Fenced(buildAt(row.b), row.f, row.l)
  end, counts, "records")
  dropKeys(collector.discoveries, function(itemId, packed)
    if BetaFence.Denied("item", itemId) then
      return true
    end
    local dayText = type(packed) == "string" and packed:match("^[^|]*|(%d+)|") or nil
    return BetaFence.Fenced(nil, tonumber(dayText), tonumber(dayText))
  end, counts, "discoveries")
  dropKeys(collector.seenBosses, function(_, record)
    return BetaFence.Denied("creature", record.npcId) or BetaFence.Fenced(nil, day(record.when), day(record.when))
  end, counts, "seenBosses")
  dropKeys(collector.questNpcs, function(questId, roles)
    if BetaFence.Denied("quest", questId) then
      return true
    end
    for role, record in pairs(roles) do
      if
        BetaFence.Denied("creature", record.npcId)
        or BetaFence.Denied("object", record.objectId)
        or BetaFence.Fenced(nil, day(record.when), day(record.when))
      then
        roles[role] = nil
      end
    end
    return next(roles) == nil
  end, counts, "questNpcs")
  dropKeys(collector.questFacts, function(questId, facts)
    if BetaFence.Denied("quest", questId) or BetaFence.Denied("item", facts.i) then
      return true
    end
    for _, goal in ipairs(type(facts.o) == "table" and facts.o or {}) do
      if BetaFence.Denied("creature", goal.c) then
        return true
      end
    end
    for _, handover in ipairs(type(facts.h) == "table" and facts.h or {}) do
      if BetaFence.Denied("item", handover.i) or BetaFence.Denied("creature", handover.g) then
        return true
      end
    end
    return BetaFence.Fenced(buildAt(facts.b), facts.d, facts.d)
  end, counts, "questFacts")
  dropKeys(collector.displays, function(creatureId, record)
    return BetaFence.Denied("creature", creatureId) or BetaFence.Fenced(buildAt(record.b), record.d, record.d)
  end, counts, "displays")
  for _, name in ipairs({ "records", "discoveries", "seenBosses", "questNpcs", "questFacts", "displays" }) do
    if collector[name] ~= nil and empty(collector[name]) then
      collector[name] = nil
    end
  end
  if snapshot.collector ~= nil and collector.records == nil then
    collector.shape = nil
  end
  if snapshot.collector ~= nil and collector.discoveries == nil then
    collector.discoveriesShape = nil
  end
  local ledger = type(snapshot.ledger) == "table" and snapshot.ledger or nil
  for kind, idKind in pairs(LEDGER_KINDS) do
    dropKeys(ledger and ledger[kind], function(id, entry)
      if BetaFence.Denied(idKind, id) then
        return true
      end
      for _, name in ipairs(ITEM_MAPS) do
        local map = entry[name]
        if type(map) == "table" then
          for item in pairs(map) do
            if BetaFence.Denied("item", item) then
              map[item] = nil
            end
          end
        end
      end
      return kind == "vendor" and BetaFence.Fenced(nil, entry.f, entry.l)
    end, counts, "ledger")
    if ledger and ledger[kind] ~= nil and empty(ledger[kind]) then
      ledger[kind] = nil
    end
  end
  local entrances = type(snapshot.places) == "table" and snapshot.places.e or nil
  dropKeys(entrances, function(_, entry)
    return BetaFence.Fenced(nil, entry.d, entry.d)
  end, counts, "places")
  dropKeys(snapshot.seenCreatures, function(npcId, record)
    return BetaFence.Denied("creature", npcId) or BetaFence.Fenced(nil, day(record.when), day(record.when))
  end, counts, "seenCreatures")
  for _, name in ipairs({ "collector", "ledger", "seenCreatures" }) do
    if snapshot[name] ~= nil and empty(snapshot[name]) then
      snapshot[name] = nil
    end
  end
  if snapshot.places ~= nil and empty(snapshot.places.e) then
    snapshot.places = nil
  end
  return snapshot, counts
end
