-- Curated quest edges: what a quest asks for, what it hands back and what starts it.
-- Pure Lua, no WoW API. Loaded as: local _, ItemTree = ...
--
-- A build's client tables carry recipes but nothing about a quest's turn in or its rewards,
-- because that lives on the server. The one quest fact a build states is the quest an item
-- starts (ItemSparse StartQuestID, item.sq), which Core/Graph.lua already draws as STARTS_QUEST.
-- Everything else here comes from Data/curated/Quests.lua and is shown at the curated tier.
--
-- The provider answers both kinds of key, in the direction each edge type walks:
--   item:<id>  down   QUEST_OBJECTIVE   to every quest that asks for the item, with its count
--   item:<id>  up     QUEST_REWARD      to every quest that hands the item back
--   quest:<id> up     QUEST_REQUIRES    to every item the quest asks for, with its count
--   quest:<id> up     QUEST_STARTED_BY  to the item that starts it
--   quest:<id> down   QUEST_REWARDS     to every item it hands back
--
-- QUEST_REQUIRES is one AND group, exactly like a recipe's reagents: a quest needs all of them.
-- A reward the player chooses between carries choice = true, so a chain can say "one of these".
--
-- This is not the only source of those edges any more. Core/Collector.lua answers the same two
-- keys for a quest this client watched: a turn in window that named its required items, or an
-- item whose name matched an objective in the quest log. Those edges are "verified" rather than
-- "curated", Core/Graph.lua merges the two, and Q:IsCurated tells a caller which kind of quest
-- it is holding so a row can say the addon was told rather than that it watched.
local _, ItemTree = ...

local Edges = ItemTree.Edges
local Graph = ItemTree.Graph
local Confidence = ItemTree.Confidence
local Data = ItemTree.Data
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local T = Edges.Types
local EMPTY = {}

local Quests = {}
ItemTree.Quests = Quests

local Q = {}
Q.__index = Q

-- The groups a quest's own rows are filed under are L["Quests"] on an item, and L["Requires"],
-- L["Rewards"] and L["Started by"] on a quest itself. Each is the English wording and its own
-- locale key, the way every other group is: a row carries the words a locale drew and
-- Core/ViewModel.lua leads them back to the key, so a translated client changes the words and
-- never a category id or a saved filter.

-- source is the curated table and defaults to ItemTree.CuratedQuests, read when it is first
-- needed rather than now, so the data file may load after this one. opts.data swaps the data
-- layer the mined mirror scans, which is what a spec passes.
function Quests.New(source, opts)
  opts = opts or EMPTY
  local quests = setmetatable({}, Q)
  quests.source = source
  quests.data = opts.data or Data
  quests.provider = nil
  quests.index = nil
  -- How many times the reverse indexes have been built (once, then kept) and how many times the
  -- mined mirror was asked for one quest's starting item, so a spec reads these back rather than
  -- timing anything.
  quests.builds = 0
  quests.lookups = 0
  return quests
end

function Q:Source()
  if type(self.source) == "table" then
    return self.source
  end
  local shipped = ItemTree.CuratedQuests
  if type(shipped) == "table" then
    return shipped
  end
  return EMPTY
end

-- One quest's curated entry, or nil when the table says nothing about it.
function Q:Quest(questId)
  local quest = self:Source()[questId]
  if type(quest) == "table" then
    return quest
  end
  return nil
end

-- Whether a quest id is one of the hand curated entries this table ships.
--
-- False for every other quest, including the ones Core/Collector.lua has learned from this
-- client: those are drawn from the collector's own records and their edges say "seen by you".
-- The answer is a plain boolean, never nil, so a caller can use it directly.
function Q:IsCurated(questId)
  return self:Quest(questId) ~= nil
end

-- One of a quest's list fields, or an empty list. A field the table never set and a field set
-- to something that is not a list read the same way, so a hand written entry with a typo in it
-- costs a row rather than an error.
local function listOf(quest, field)
  if type(quest) == "table" and type(quest[field]) == "table" then
    return quest[field]
  end
  return EMPTY
end

local function push(index, id, entry)
  if type(id) ~= "number" then
    return
  end
  index[id] = index[id] or {}
  local bucket = index[id]
  bucket[#bucket + 1] = entry
end

-- Quest ids in a stable order. pairs walks a table differently from one run to the next, and the
-- buckets below keep the order they were built in, so the rows under an item would otherwise
-- swap places between two loads of the same data.
local function questIds(source)
  local ids = {}
  for questId in pairs(source) do
    if type(questId) == "number" then
      ids[#ids + 1] = questId
    end
  end
  table.sort(ids)
  return ids
end

-- Item to the quests that ask for it and the quests that hand it back, built once from the
-- curated table. Names are set here as well, so a quest reached by any edge, including the mined
-- STARTS_QUEST one, reads "Rise, Thunderfury!" rather than "Quest 7787".
function Q:_Index()
  if self.index then
    return self.index
  end
  local source = self:Source()
  local byRequired, byReward = {}, {}
  for _, questId in ipairs(questIds(source)) do
    local quest = source[questId]
    if type(quest) == "table" then
      if type(quest.name) == "string" then
        Graph.SetName(Graph.Key("quest", questId), quest.name)
      end
      for _, required in ipairs(listOf(quest, "requires")) do
        if type(required) == "table" then
          push(byRequired, required[1], { quest = questId, count = required[2] or 1 })
        end
      end
      for _, itemId in ipairs(listOf(quest, "rewards")) do
        push(byReward, itemId, { quest = questId })
      end
      for _, itemId in ipairs(listOf(quest, "choice")) do
        push(byReward, itemId, { quest = questId, choice = true })
      end
    end
  end
  self.index = { byRequired = byRequired, byReward = byReward }
  self.builds = self.builds + 1
  return self.index
end

-- Quest to the item that starts it: the mined fact (item.sq), read the other way round. Brief P4:
-- the pipeline ships it the right way round (Data:QuestStartItem, the QuestStarts module), so a
-- quest key asks for its own quest and nothing walks every item. The data layer keeps what it
-- answered, so this keeps nothing itself. nil where no item starts the quest.
function Q:_StartOf(questId)
  local data = self.data
  if type(data) ~= "table" or type(data.QuestStartItem) ~= "function" then
    return nil
  end
  self.lookups = self.lookups + 1
  local ok, itemId = pcall(data.QuestStartItem, data, questId)
  if ok and type(itemId) == "number" then
    return itemId
  end
  return nil
end

-- Drops the reverse indexes, so the next call builds them again. The harness swaps data modules
-- underneath a loaded Core; nothing in the addon changes the curated table at runtime. The
-- starting items are the data layer's to drop (Data:Reset).
function Q:Invalidate()
  self.index = nil
end

local function zoneOf(quest)
  if type(quest) == "table" then
    return quest.zone
  end
  return nil
end

-- Edges for Graph.RegisterProvider. Everything answered here is "curated": it is a hand
-- maintained note shipped with the addon, not something this client saw.
function Q:EdgesFor(key, direction)
  local out = {}
  local kind, id = Graph.Parse(key)
  if kind ~= "item" and kind ~= "quest" then
    return out
  end

  local function emit(def, target, fields)
    if not def or def.dir ~= direction or not target then
      return
    end
    fields = fields or EMPTY
    out[#out + 1] = {
      type = def,
      target = target,
      quantity = fields.quantity,
      confidence = Confidence.CURATED,
      group = fields.group,
      meta = fields.meta,
      -- One of a set of rewards the player picks between. Core/Chain.lua reads it so a chain
      -- says the staff is a choice rather than a certainty.
      choice = fields.choice,
    }
  end

  local index = self:_Index()
  if kind == "item" then
    if direction == Edges.DOWN then
      for _, entry in ipairs(index.byRequired[id] or EMPTY) do
        emit(T.QUEST_OBJECTIVE, Graph.Key("quest", entry.quest), {
          quantity = entry.count,
          group = L["Quests"],
          meta = zoneOf(self:Quest(entry.quest)),
        })
      end
    else
      for _, entry in ipairs(index.byReward[id] or EMPTY) do
        emit(T.QUEST_REWARD, Graph.Key("quest", entry.quest), {
          group = L["Quests"],
          meta = zoneOf(self:Quest(entry.quest)),
          choice = entry.choice,
        })
      end
    end
    return out
  end

  local quest = self:Quest(id)
  if direction == Edges.UP then
    for _, required in ipairs(listOf(quest, "requires")) do
      if type(required) == "table" and type(required[1]) == "number" then
        emit(T.QUEST_REQUIRES, Graph.Key("item", required[1]), {
          quantity = required[2] or 1,
          group = L["Requires"],
        })
      end
    end
    -- The curated table names the starting item where it knows one; otherwise the mined mirror
    -- answers, which is what carries quests nothing has been curated for.
    local startedBy = nil
    if quest then
      startedBy = quest.startedBy
    end
    if type(startedBy) ~= "number" then
      startedBy = self:_StartOf(id)
    end
    if type(startedBy) == "number" then
      emit(T.QUEST_STARTED_BY, Graph.Key("item", startedBy), { group = L["Started by"] })
    end
    return out
  end

  for _, itemId in ipairs(listOf(quest, "rewards")) do
    if type(itemId) == "number" then
      emit(T.QUEST_REWARDS, Graph.Key("item", itemId), { group = L["Rewards"] })
    end
  end
  for _, itemId in ipairs(listOf(quest, "choice")) do
    if type(itemId) == "number" then
      emit(T.QUEST_REWARDS, Graph.Key("item", itemId), {
        group = L["Rewards"],
        choice = true,
        meta = L["Choose one"],
      })
    end
  end
  return out
end

-- What the curated table holds and whether it reaches the graph, for the debug command. A table
-- full of quests that is not installed draws exactly the same empty tree an empty one does, so
-- the two faults have to be told apart; Core/Collector.lua's Counts answers the same way.
function Q:Counts()
  local source = self:Source()
  local quests, requires, rewards = 0, 0, 0
  for _, questId in ipairs(questIds(source)) do
    local quest = source[questId]
    quests = quests + 1
    requires = requires + #listOf(quest, "requires")
    rewards = rewards + #listOf(quest, "rewards") + #listOf(quest, "choice")
  end
  return { quests = quests, requires = requires, rewards = rewards, installed = self:Installed() }
end

-- Registers EdgesFor with the graph. Safe to call twice: the previous registration is
-- replaced rather than stacked.
function Q:Install()
  if self.provider then
    Graph.UnregisterProvider(self.provider)
  end
  self.provider = function(key, direction)
    return self:EdgesFor(key, direction)
  end
  Graph.RegisterProvider(self.provider)
  return self.provider
end

-- Puts every curated quest's name on the graph now rather than on the first edge asked for.
--
-- A quest opened by its key alone, from the recently viewed list or from a debug command,
-- titles itself through Graph.Title before anything has asked this provider for an edge, and
-- would otherwise read "Quest 7786". Setting the names is part of building the reverse indexes,
-- which are built once and kept, so this is the same pass the first edge would have paid for
-- and never a second one. Core/Init.lua calls it once, straight after Install.
function Q:SetNames()
  self:_Index()
  return self
end

function Q:Installed()
  return self.provider ~= nil and Graph.HasProvider(self.provider) == true
end

function Q:Uninstall()
  if self.provider then
    Graph.UnregisterProvider(self.provider)
    self.provider = nil
  end
end

return Quests
