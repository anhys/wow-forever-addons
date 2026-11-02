-- Reads sources out of Questie, if the player has it installed. Ships none of its data.
--
-- Modelled on the real addon at github.com/Questie/Questie, master 454b9d0 (v11.38.0):
--   Modules/Libs/QuestieLoader.lua  QuestieLoader:ImportModule(name) answers the module, and
--                       CREATES AN EMPTY ONE when it has not loaded yet, so the answer being a
--                       table says nothing at all about the database being ready.
--   Database/QuestieDB.lua  QueryItemSingle, QueryNPCSingle, QueryObjectSingle and
--                       QueryQuestSingle are only assigned inside QuestieDB:Initialize(), which
--                       runs well after ADDON_LOADED. That is what "waiting" means here.
--   Database/itemDB.lua    the item fields: name, npcDrops, objectDrops, itemDrops, startQuest,
--                       questRewards, vendors, relatedQuests, teachesSpell. npcDrops, vendors,
--                       itemDrops and objectDrops are all plain lists of ids.
--   Database/npcDB.lua     name and zoneID
--   Database/objectDB.lua  name and zoneID
--   Database/DropTables/dropDB.lua  QuestieDB.GetItemDroprate(itemId, npcId) answers
--                       { rate, sourceDB } as { float, string } or NIL, where 100.0 is 100%.
--                       Note the argument order and the ARRAY return: the research note for this
--                       round had both wrong.
--   Public/RegisterOnReady.lua  Questie.API.RegisterOnReady(callback) fires at once when
--                       Questie.API.isReady is already true, and otherwise queues the callback.
-- Questie's TOC lists interface 11508 and 11509 and no 16001 yet, so on the Forever beta this
-- adapter simply stays "absent", which costs nothing.
--
-- Its rates were measured on Classic Era, so every percentage is stamped percentSource = "era"
-- and Core/Sources.lua draws it as "about 3%" on a client that is not Era.
local _, ItemTree = ...

local Edges = ItemTree.Edges
local Graph = ItemTree.Graph
local Sources = ItemTree.Sources
local Confidence = ItemTree.Confidence
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local T = Edges.Types
local EMPTY = {}

local Questie = {}
ItemTree.Adapters = ItemTree.Adapters or {}
ItemTree.Adapters.questie = Questie

Questie.key = "questie"
Questie.label = "Questie"
-- The addon FOLDER, which is what a TOC OptionalDeps line and IsAddOnLoaded both name. The real
-- addon ships as Questie\Questie.toc with one TOC per flavour beside it.
Questie.addon = "Questie"

-- The first upstream error, which is the end of this adapter for the session.
local fault = nil

function Questie.Fault()
  return fault
end

function Questie.Reset()
  return true
end

local function call(fn, ...)
  if fault or type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if not ok then
    fault = tostring(value)
    return nil
  end
  return value
end

-- A zone's words out of Questie's own locale table, which is keyed by zone id and holds the
-- English name; a locale other than English puts a translation behind the callable l10n. Nil
-- rather than a guess when neither is there, so a source line is "Hogger" and not "Hogger, 12".
local function zoneName(db, zoneId)
  if type(zoneId) ~= "number" then
    return nil
  end
  local l10n = db.l10n
  local lookup = type(l10n) == "table" and l10n.zoneLookup or nil
  if type(lookup) ~= "table" then
    return nil
  end
  local name = call(function()
    return lookup[zoneId]
  end)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  -- l10n is a table the addon calls rather than a function (it carries a __call), so the
  -- translation is fetched through a closure the way every other upstream read here is.
  local translated = call(function()
    return l10n(name)
  end)
  if type(translated) == "string" and translated ~= "" then
    return translated
  end
  return name
end

-- The source line Core/Collector.lua writes, "Name, Zone", read back by Core/Sources.lua.
local function metaFor(name, zone)
  if not name then
    return nil
  end
  if not zone then
    return name
  end
  return name .. ", " .. zone
end

local function collector()
  local out, seen = {}, {}
  return out,
    function(def, targetKind, targetId, name, zone, fields)
      if not def or type(targetId) ~= "number" or targetId <= 0 then
        return
      end
      local target = Graph.Key(targetKind, targetId)
      local slot = def.name .. "\0" .. target
      if seen[slot] then
        return
      end
      seen[slot] = true
      if name then
        Graph.SetName(target, name)
      end
      fields = fields or EMPTY
      -- Questie's rates were measured on Classic Era, so every one of them says so and
      -- Core/Sources.lua draws it as an estimate on a client that is not Era.
      local percentSource = nil
      if fields.percent then
        percentSource = (Sources and Sources.ERA) or "era"
      end
      out[#out + 1] = {
        type = def,
        target = target,
        meta = metaFor(name, zone),
        zone = zone,
        group = fields.group or def.label,
        percent = fields.percent,
        percentSource = percentSource,
        quantity = fields.quantity,
        choice = fields.choice,
        confidence = Confidence.BASELINE,
        provenance = Questie.key,
      }
    end
end

-- The rate Questie has for this item off this creature, as a percentage out of a hundred, which
-- is what an edge carries. dropDB.lua answers { rate, sourceDB }, rate already out of a hundred.
local function droprate(db, itemId, npcId)
  local answer = call(db.GetItemDroprate, itemId, npcId)
  if type(answer) ~= "table" then
    return nil
  end
  local rate = tonumber(answer[1])
  if not rate or rate <= 0 then
    return nil
  end
  return rate
end

-- A single field off one of Questie's four compiled databases, through the query the database
-- documents. Nil for anything the database has no answer for.
local function single(query, id, field)
  local value = call(query, id, field)
  if value == nil then
    return nil
  end
  return value
end

local function text(value)
  if type(value) == "string" and value ~= "" then
    return value
  end
  return nil
end

--------------------------------------------------------------------------------
-- The reverse index: quests to items, and items to the quests that need them.
--
-- Questie's item database answers "which quests reward this item" and its quest database answers
-- "which items does this quest want", and neither answers the other way round. Both of those are
-- what a quest chain is walked by, so the two reverse lists are built once, by walking the quest
-- pointers and the item pointers, which is the id set of each compiled database.
--
-- That walk is thousands of queries, so it never runs at load and never runs in one go: Step
-- takes a budget of ids and answers whether it has finished, and the client side below spreads
-- the steps over frames. Under busted, and anywhere with no timer, the caller runs Step in a
-- loop instead. Nothing is written anywhere but this table, which goes when the session does.
--------------------------------------------------------------------------------

Questie.index = nil

-- ids of a compiled database, from the pointers Questie builds in QuestieDB:Initialize.
local function pointerIds(pointers)
  local ids = {}
  if type(pointers) ~= "table" then
    return ids
  end
  local ok = pcall(function()
    for id in pairs(pointers) do
      if type(id) == "number" then
        ids[#ids + 1] = id
      end
    end
  end)
  if not ok then
    return {}
  end
  table.sort(ids)
  return ids
end

-- Starts a build, or answers the one already running. Nothing upstream is read here.
function Questie.StartIndex(db)
  if Questie.index then
    return Questie.index
  end
  local index = {
    done = false,
    questsAt = 0,
    itemsAt = 0,
    quests = pointerIds(db and db.QuestPointers),
    items = pointerIds(db and db.ItemPointers),
    -- questId -> { itemId }, the items a quest asks for
    requires = {},
    -- questId -> { itemId }, what a quest gives back
    rewards = {},
    -- itemId -> { questId }, the quests that ask for the item
    neededBy = {},
  }
  Questie.index = index
  return index
end

local function push(bucket, key, value)
  local held = bucket[key]
  if not held then
    held = {}
    bucket[key] = held
  end
  for _, existing in ipairs(held) do
    if existing == value then
      return
    end
  end
  held[#held + 1] = value
end

-- Reads up to `budget` quest ids and then up to `budget` item ids, and answers true once the
-- whole walk is done. Pure given db, so a spec drives it straight through.
function Questie.Step(db, budget)
  local index = Questie.StartIndex(db)
  if index.done or fault or type(db) ~= "table" then
    return index.done
  end
  budget = tonumber(budget) or 250

  local taken = 0
  while index.questsAt < #index.quests and taken < budget do
    index.questsAt = index.questsAt + 1
    taken = taken + 1
    local questId = index.quests[index.questsAt]
    -- objectives[3] is the item objective list, { { itemId, text, icon }, ... }, and
    -- requiredSourceItems is a plain list of item ids the quest needs without them being an
    -- objective (Database/questDB.lua).
    local objectives = single(db.QueryQuestSingle, questId, "objectives")
    if type(objectives) == "table" and type(objectives[3]) == "table" then
      for _, objective in ipairs(objectives[3]) do
        local itemId = type(objective) == "table" and objective[1] or objective
        if type(itemId) == "number" then
          push(index.requires, questId, itemId)
          push(index.neededBy, itemId, questId)
        end
      end
    end
    for _, itemId in ipairs(single(db.QueryQuestSingle, questId, "requiredSourceItems") or EMPTY) do
      if type(itemId) == "number" then
        push(index.requires, questId, itemId)
        push(index.neededBy, itemId, questId)
      end
    end
    if fault then
      return false
    end
  end

  if index.questsAt < #index.quests then
    return false
  end

  taken = 0
  while index.itemsAt < #index.items and taken < budget do
    index.itemsAt = index.itemsAt + 1
    taken = taken + 1
    local itemId = index.items[index.itemsAt]
    for _, questId in ipairs(single(db.QueryItemSingle, itemId, "questRewards") or EMPTY) do
      if type(questId) == "number" then
        push(index.rewards, questId, itemId)
      end
    end
    if fault then
      return false
    end
  end

  index.done = index.itemsAt >= #index.items
  return index.done
end

function Questie.IndexReady()
  return Questie.index ~= nil and Questie.index.done == true
end

-- Every edge Questie has for one node. kind is "item" or "quest"; db is the QuestieDB module with
-- an l10n on it, passed in rather than looked up, so the whole mapping runs under busted against
-- a fake shaped like the real one.
function Questie.EdgesFrom(db, id, kind)
  if fault or type(id) ~= "number" or type(db) ~= "table" then
    return EMPTY
  end
  if type(db.QueryItemSingle) ~= "function" then
    return EMPTY
  end
  kind = kind or "item"
  if kind == "quest" then
    return Questie.QuestEdgesFrom(db, id)
  end
  if kind ~= "item" then
    return EMPTY
  end
  local itemId = id
  local out, add = collector()

  local function npcSource(npcId, def, group, percent)
    local name = text(single(db.QueryNPCSingle, npcId, "name"))
    local zone = zoneName(db, single(db.QueryNPCSingle, npcId, "zoneID"))
    add(def, "npc", npcId, name, zone, { group = group, percent = percent })
  end

  for _, npcId in ipairs(single(db.QueryItemSingle, itemId, "npcDrops") or EMPTY) do
    if type(npcId) == "number" then
      npcSource(npcId, T.DROPPED_BY, L["Drops from"], droprate(db, itemId, npcId))
    end
  end

  for _, npcId in ipairs(single(db.QueryItemSingle, itemId, "vendors") or EMPTY) do
    if type(npcId) == "number" then
      npcSource(npcId, T.SOLD_BY, L["Sold by"], nil)
    end
  end

  -- Questie says an object drops the item and never says what kind of object it is, so these
  -- are looted rather than gathered: "Looted from" is true of a vein and of a chest alike,
  -- where "Gathered from" would be a claim about a chest that is not.
  for _, objectId in ipairs(single(db.QueryItemSingle, itemId, "objectDrops") or EMPTY) do
    if type(objectId) == "number" then
      local name = text(single(db.QueryObjectSingle, objectId, "name"))
      local zone = zoneName(db, single(db.QueryObjectSingle, objectId, "zoneID"))
      add(T.LOOTED_FROM, "object", objectId, name, zone, { group = L["Contained in"] })
    end
  end

  for _, sourceId in ipairs(single(db.QueryItemSingle, itemId, "itemDrops") or EMPTY) do
    if type(sourceId) == "number" then
      local name = text(single(db.QueryItemSingle, sourceId, "name"))
      add(T.CONTAINED_IN, "item", sourceId, name, nil, { group = L["Contained in"] })
    end
  end

  for _, questId in ipairs(single(db.QueryItemSingle, itemId, "questRewards") or EMPTY) do
    if type(questId) == "number" then
      local name = text(single(db.QueryQuestSingle, questId, "name"))
      add(T.QUEST_REWARD, "quest", questId, name, nil, { group = L["Quests"] })
    end
  end

  -- The quests that want this item, which only the reverse index can answer. Nothing is drawn
  -- until the index has finished; the client side below kicks the build off and refreshes the
  -- window when it lands.
  if Questie.IndexReady() then
    for _, questId in ipairs(Questie.index.neededBy[itemId] or EMPTY) do
      local name = text(single(db.QueryQuestSingle, questId, "name"))
      add(T.QUEST_OBJECTIVE, "quest", questId, name, nil, { group = L["Quests"] })
    end
  end

  if fault then
    return EMPTY
  end
  return out
end

-- What one quest asks for and what it gives back. Both come off the reverse index, because
-- Questie's quest database states its item objectives in a nested table and never states its
-- rewards at all: only the item database says which quests reward an item.
function Questie.QuestEdgesFrom(db, questId)
  if fault or type(questId) ~= "number" or type(db) ~= "table" then
    return EMPTY
  end
  if not Questie.IndexReady() then
    return EMPTY
  end
  local out, add = collector()
  local name = text(single(db.QueryQuestSingle, questId, "name"))
  if name then
    Graph.SetName(Graph.Key("quest", questId), name)
  end
  for _, itemId in ipairs(Questie.index.requires[questId] or EMPTY) do
    local itemName = text(single(db.QueryItemSingle, itemId, "name"))
    -- Questie states which items a quest wants and never how many of each, so the count is left
    -- off rather than claimed as one.
    add(T.QUEST_REQUIRES, "item", itemId, itemName, nil, { group = L["Requires"] })
  end
  for _, itemId in ipairs(Questie.index.rewards[questId] or EMPTY) do
    local itemName = text(single(db.QueryItemSingle, itemId, "name"))
    -- Nor whether the rewards are a choice, so no edge here claims one either.
    add(T.QUEST_REWARDS, "item", itemId, itemName, nil, { group = L["Rewards"] })
  end
  if fault then
    return EMPTY
  end
  return out
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- QuestieDB with Questie's locale table hung on it, or nil. ImportModule builds an empty module
-- for a name it has never seen, so what comes back is only worth anything once the queries are
-- on it, which is what Ready tests for.
function Questie.Database()
  local loader = rawget(_G, "QuestieLoader")
  if type(loader) ~= "table" or type(loader.ImportModule) ~= "function" then
    return nil
  end
  local ok, db = pcall(loader.ImportModule, loader, "QuestieDB")
  if not ok or type(db) ~= "table" then
    return nil
  end
  if db.l10n == nil then
    local ok2, l10n = pcall(loader.ImportModule, loader, "l10n")
    if ok2 and type(l10n) == "table" then
      -- Read through a wrapper rather than written onto Questie's own module: nothing of ours
      -- belongs on another addon's table.
      return setmetatable({ l10n = l10n }, { __index = db })
    end
  end
  return db
end

-- "absent" with no Questie at all, "waiting" until its database has been compiled, then "ready".
-- QuestieDB.QueryItemSingle is assigned inside QuestieDB:Initialize and nowhere else, so its
-- presence is the one honest test that the database is answering.
function Questie.Ready()
  local global = rawget(_G, "Questie")
  local loader = rawget(_G, "QuestieLoader")
  if type(global) ~= "table" and type(loader) ~= "table" then
    return "absent"
  end
  local db = Questie.Database()
  if type(db) ~= "table" or type(db.QueryItemSingle) ~= "function" then
    return "waiting", "database not compiled yet"
  end
  -- Ready either way: sources answer at once, and only the quest chain questions wait on the
  -- reverse index, so the debug output says which of the two the window is looking at.
  if Questie.index and not Questie.index.done then
    return "ready", "quest index building"
  end
  if Questie.IndexReady() then
    return "ready", "quest index built"
  end
  return "ready"
end

-- Questie's own ready hook, which is the documented way to be told the database is answering.
-- It fires straight away when Questie is already ready, so onReady has to cope with being
-- called during this call. Answers true once the hook is on, and is retried until it is.
function Questie.Hook(onReady)
  local global = rawget(_G, "Questie")
  local api = type(global) == "table" and global.API or nil
  if type(api) ~= "table" or type(api.RegisterOnReady) ~= "function" then
    return false
  end
  local ok = pcall(api.RegisterOnReady, onReady)
  return ok == true
end

-- Builds the reverse index a few hundred ids at a time, one chunk per frame, and tells the rest
-- of the addon once it lands. Never at load: the first quest shaped question starts it, and the
-- window carries on answering everything else while it runs.
--
-- The budget is in ids rather than in milliseconds, and the time one chunk actually took is kept
-- in Questie.lastStepMs (debugprofilestop measures in milliseconds and is the client's own
-- profiler clock), so the owner can read what it cost on their machine off the debug output. A
-- client with no C_Timer, which is every spec run, walks it through in one go instead.
Questie.STEP_BUDGET = 250
Questie.lastStepMs = nil

local function stepOnce(db)
  local clock = rawget(_G, "debugprofilestop")
  local started = type(clock) == "function" and clock() or nil
  local done = Questie.Step(db, Questie.STEP_BUDGET)
  if started then
    Questie.lastStepMs = clock() - started
  end
  return done
end

function Questie.BuildIndex(onDone)
  local db = Questie.Database()
  if type(db) ~= "table" or type(db.QueryQuestSingle) ~= "function" then
    return false
  end
  if Questie.IndexReady() then
    return true
  end
  local timer = rawget(_G, "C_Timer")
  local after = type(timer) == "table" and timer.After or nil
  if type(after) ~= "function" then
    -- No timer to spread the walk over, so it runs through. Bounded by the id lists, which are
    -- finite, and by the fault latch, which stops it the moment the database misbehaves.
    local guard = 0
    while not Questie.Step(db, Questie.STEP_BUDGET) and not fault and guard < 100000 do
      guard = guard + 1
    end
    if Questie.IndexReady() and type(onDone) == "function" then
      onDone()
    end
    return Questie.IndexReady()
  end
  if Questie.building then
    return false
  end
  Questie.building = true
  local function chunk()
    if fault or stepOnce(db) then
      Questie.building = false
      if type(onDone) == "function" then
        pcall(onDone)
      end
      return
    end
    pcall(after, 0, chunk)
  end
  pcall(after, 0, chunk)
  return false
end

function Questie.Edges(id, kind)
  local db = Questie.Database()
  -- A quest shaped question is what the reverse index exists for, so the first one starts it.
  -- Walking down from an item asks the same thing, so that starts it too.
  if not Questie.IndexReady() then
    Questie.BuildIndex(function()
      local registry = ItemTree.Providers
      if registry and type(registry.Reset) == "function" then
        pcall(registry.Reset)
        pcall(registry.Invalidate)
      end
    end)
  end
  return Questie.EdgesFrom(db, id, kind)
end

if ItemTree.Providers and type(ItemTree.Providers.Add) == "function" then
  ItemTree.Providers.Add(Questie)
end

return Questie
