-- Quest verdicts for the one quest the client is showing: is it New in Forever, and does it hand
-- over a reward Classic Era did not (brief Q2, docs/ideas/quest-new-changed.md). Pure Lua, no WoW
-- API: UI/QuestFlags.lua reads the quest id and the live reward ids off the client and asks here.
--
-- Two core data modules answer, both loaded at login so a quest giver's panel never loads the
-- item data (ItemTree-Data docs/quests.md):
--
--   Diff.quests.known   every quest id Classic Era knew (Era QuestV2 plus the CMaNGOS quests), as
--                       id runs {from, count, ...}. Data.InRuns is the decoder.
--   QuestRewards        [questId] = { {fixed reward item ids}, {choice item ids} }, the choice list
--                       left off when the quest offers none. Every Era quest that hands over an
--                       item; a quest with no entry is one the table knows nothing about.
--
-- The verdicts:
--   IsNew(questId)       the id is not in quests.known. No quests table, no verdict: false.
--   RewardVerdicts(...)  per live reward id, "new_item" when the item itself is New in Forever,
--                        whatever the quest (the item's newness is the Diff module's fact, not the
--                        quest table's), "new_reward" when the item existed in Classic Era and
--                        this quest did not hand it over, nothing otherwise. Only "new_reward"
--                        needs the quest's QuestRewards entry: with none, no reward is a New
--                        reward, because no data is not a change.
--   IsChanged(...)       any reward is "new_reward".
--
-- Nothing here loops over quests. Each call answers for one quest id, and the reward lists are
-- the few ids the client showed for that one quest.
local _, ItemTree = ...

local QuestFlags = {}
ItemTree.QuestFlags = QuestFlags

QuestFlags.NEW_ITEM = "new_item"
QuestFlags.NEW_REWARD = "new_reward"

local EMPTY = {}

-- A positive whole number id, or nil. Quest and item ids arrive from the client as numbers, and
-- from a link or a spec as strings.
local toId = ItemTree.Util.PositiveId

-- One data module through Data:Get, guarded: a missing module, a missing Data and a loader that
-- raises all read as nil.
local function module(name)
  local Data = ItemTree.Data
  if type(Data) ~= "table" or type(Data.Get) ~= "function" then
    return nil
  end
  local ok, value = pcall(Data.Get, Data, name)
  if ok and type(value) == "table" then
    return value
  end
  return nil
end

-- The known quest id runs, or nil when the data carries none. An empty list is no data too: a
-- known set with nothing in it would call every quest new.
local function knownRuns()
  local diff = module("Diff")
  local quests = diff and diff.quests
  local known = type(quests) == "table" and quests.known or nil
  if type(known) ~= "table" or #known < 2 then
    return nil
  end
  return known
end

-- Whether the id is in a flat run list. Data.InRuns when it is there (it always is in the addon),
-- with the same binary search here for a namespace built without Core/Data.lua.
local function inRuns(runs, id)
  local Data = ItemTree.Data
  if type(Data) == "table" and type(Data.InRuns) == "function" then
    return Data.InRuns(runs, id) == true
  end
  local low, high = 1, math.floor(#runs / 2)
  while low <= high do
    local mid = math.floor((low + high) / 2)
    local from, count = tonumber(runs[mid * 2 - 1]) or 0, tonumber(runs[mid * 2]) or 0
    if id < from then
      high = mid - 1
    elseif id >= from + count then
      low = mid + 1
    else
      return true
    end
  end
  return false
end

-- Whether the data can answer IsNew at all. The UI asks this so a build compiled without quests
-- draws nothing rather than calling every quest new.
function QuestFlags.HasQuestData()
  return knownRuns() ~= nil
end

-- True when Classic Era did not know this quest id. False for no id and for no data.
function QuestFlags.IsNew(questId)
  local id = toId(questId)
  if not id then
    return false
  end
  local known = knownRuns()
  if not known then
    return false
  end
  return not inRuns(known, id)
end

-- The Era reward and choice ids for one quest as a set, or nil when QuestRewards has no entry.
function QuestFlags.EraRewards(questId)
  local id = toId(questId)
  local rewards = id and module("QuestRewards") or nil
  local entry = rewards and rewards[id]
  if type(entry) ~= "table" then
    return nil
  end
  local set = {}
  for _, list in ipairs(entry) do
    if type(list) == "table" then
      for _, itemId in ipairs(list) do
        local item = toId(itemId)
        if item then
          set[item] = true
        end
      end
    end
  end
  return set
end

-- Whether an item is New in Forever, through Core/Diff.lua. Guarded: no Diff reads as no.
local function itemIsNew(itemId)
  local Diff = ItemTree.Diff
  if type(Diff) ~= "table" or type(Diff.IsNew) ~= "function" then
    return false
  end
  local ok, answer = pcall(Diff.IsNew, "items", itemId)
  return ok and answer == true
end

-- itemId -> "new_item" or "new_reward" for the live rewards that earn a mark; an id that earns
-- none is absent. liveRewardIds and liveChoiceIds are the item ids the client shows for the quest,
-- fixed rewards and choices, in any order; nil entries and junk are skipped. A New in Forever item
-- is "new_item" on any quest, with or without an Era entry, and it wins, so a reward never carries
-- both marks. Any other id is "new_reward" only when the quest has an Era entry and the id is in
-- neither of its lists.
function QuestFlags.RewardVerdicts(questId, liveRewardIds, liveChoiceIds)
  local verdicts = {}
  local era = QuestFlags.EraRewards(questId)
  for _, list in ipairs({ liveRewardIds or EMPTY, liveChoiceIds or EMPTY }) do
    if type(list) == "table" then
      for _, value in pairs(list) do
        local itemId = toId(value)
        if itemId and verdicts[itemId] == nil then
          if itemIsNew(itemId) then
            verdicts[itemId] = QuestFlags.NEW_ITEM
          elseif era and not era[itemId] then
            verdicts[itemId] = QuestFlags.NEW_REWARD
          end
        end
      end
    end
  end
  return verdicts
end

-- True when any live reward is one this quest did not hand over in Classic Era.
function QuestFlags.IsChanged(questId, liveRewardIds, liveChoiceIds)
  for _, verdict in pairs(QuestFlags.RewardVerdicts(questId, liveRewardIds, liveChoiceIds)) do
    if verdict == QuestFlags.NEW_REWARD then
      return true
    end
  end
  return false
end

--------------------------------------------------------------------------------
-- Brief Q1 (the owner's rulings of 2026-10-09): a Classic quest whose id the Forever client's own
-- tables list EXISTS in Forever, so its rows are no longer Predicted; and the quest keep rules'
-- facts. Diff.quests carries, where the compiled build states its QuestV2 (ours, a join of the
-- client's QuestV2 with the CMaNGOS quests; ItemTree-Data docs/quests.md):
--   unlisted   the quests Classic Era knew that the client's QuestV2 does not list: the only
--              Classic quests still Predicted
--   alliance, horde   of the listed Classic quests, those whose race mask names that side alone
--   turnIns    of the listed Classic quests, the reputation turn ins (flagged repeatable, or a plain
--              hand in rewarding reputation and no item, such as a cloth donation), which never keep
--              an item
-- each as id runs. One binary search per question; nothing loops over quests.
--------------------------------------------------------------------------------

QuestFlags.ALLIANCE = 1
QuestFlags.HORDE = 2

-- One of the brief Q1 run lists, or nil where the data carries none (a build compiled before it,
-- or one that states no QuestV2). An empty list is an answer: nothing is in it.
local function listingRuns(name)
  local diff = module("Diff")
  local quests = diff and diff.quests
  local runs = type(quests) == "table" and quests[name] or nil
  if type(runs) ~= "table" then
    return nil
  end
  return runs
end

-- True where the client's own tables list the quest (it exists in Forever), false for a Classic
-- quest they do not list, nil where the data cannot say (no listing shipped, or no id).
function QuestFlags.IsListed(questId)
  local id = toId(questId)
  local unlisted = id and listingRuns("unlisted") or nil
  if not unlisted then
    return nil
  end
  return not inRuns(unlisted, id)
end

-- The one side a listed Classic quest is open to, QuestFlags.ALLIANCE or QuestFlags.HORDE, or nil
-- for a quest open to both, one the data does not side, or no data.
function QuestFlags.Side(questId)
  local id = toId(questId)
  if not id then
    return nil
  end
  local alliance = listingRuns("alliance")
  if alliance and inRuns(alliance, id) then
    return QuestFlags.ALLIANCE
  end
  local horde = listingRuns("horde")
  if horde and inRuns(horde, id) then
    return QuestFlags.HORDE
  end
  return nil
end

-- True for a reputation turn in (a cloth donation and the like), which never keeps an item.
function QuestFlags.IsTurnIn(questId)
  local id = toId(questId)
  local runs = id and listingRuns("turnIns") or nil
  return runs ~= nil and inRuns(runs, id)
end

--------------------------------------------------------------------------------
-- Brief RB1 (the owner's standing rule of 2026-10-17, "Predicted IS our data"): a Classic quest the
-- client does not list counts like a listed one, under every rule a listed one meets, the turn in
-- rule among them (Core/Keep.lua Keep.QuestNeverKeeps: a repeatable reputation turn in never keeps an
-- item). A compile before RB1's pipeline change flags the turn ins of the listed quests alone, so it
-- cannot tell an unlisted one time quest from an unlisted repeat (543 of the 666 unlisted quests that
-- ask for an item are repeats in the Classic tables). Such a quest is UNJUDGED and is not counted
-- yet; the first compile whose turnIns names an unlisted quest judges them all, and they count.
--------------------------------------------------------------------------------

-- Whether the shipped turn ins judge the unlisted quests too: true where turnIns names at least one
-- quest the unlisted runs hold. Worked out once per pair of run lists (a pass over the turn in runs, a
-- few hundred ids at most). Pure over the core data.
local judgedTurnIns, judgedUnlisted, judged = nil, nil, false
function QuestFlags.JudgesUnlisted()
  local turnIns, unlisted = listingRuns("turnIns"), listingRuns("unlisted")
  if not turnIns or not unlisted then
    return false
  end
  if judgedTurnIns == turnIns and judgedUnlisted == unlisted then
    return judged
  end
  local answer = false
  for at = 1, #turnIns - 1, 2 do
    local from, count = tonumber(turnIns[at]) or 0, tonumber(turnIns[at + 1]) or 0
    for id = from, from + count - 1 do
      if not answer and inRuns(unlisted, id) then
        answer = true
      end
    end
  end
  judgedTurnIns, judgedUnlisted, judged = turnIns, unlisted, answer
  return answer
end

-- Whether one CLASSIC quest (the caller knows it is one: a Classic Era quest row) is one the client
-- does not list, or one no listing ships for, that the shipped turn ins cannot judge
-- (QuestFlags.JudgesUnlisted false). false for a listed quest, and for every Classic quest once the
-- data judges the unlisted ones.
function QuestFlags.Unjudged(questId)
  if QuestFlags.IsListed(questId) == true then
    return false
  end
  return not QuestFlags.JudgesUnlisted()
end

--------------------------------------------------------------------------------
-- Brief QS2b (ItemTree-Data brief QS2's rule 2, the owner's rulings of 2026-10-14): the side players
-- were SEEN taking a recorded quest on, where neither its race mask, its givers, its turn in nor the
-- capital it sits in state one (ItemTree-Data docs/quests.md, "A recorded quest's side"). Diff.quests
-- carries, each left off where empty:
--   seenAlliance, seenHorde   id runs: the recorded quests only that side's players were seen taking
-- A side seen is not a side served. The quest counts as a use for that side only (Core/Keep.lua
-- Keep.SeenOtherSideQuest, Core/Graph.lua Graph.QuestSeenSide), and it is never hidden by "Hide other
-- faction data" and never worded "Alliance only": Graph.QuestSide, which hides and words the other
-- side's quests, never reads it. Nothing ships these runs until the addon's quest side facts (brief
-- QF1) are banked.
--------------------------------------------------------------------------------

-- The one side players were seen taking a quest on, QuestFlags.ALLIANCE or QuestFlags.HORDE, or nil:
-- no data, no id, a quest QuestFlags.Side already sides (the side it is served to wins), and a quest
-- in both runs (the pipeline never ships one: seen by both is open to both).
function QuestFlags.SeenSide(questId)
  local id = toId(questId)
  if not id or QuestFlags.Side(id) ~= nil then
    return nil
  end
  local alliance = listingRuns("seenAlliance")
  local horde = listingRuns("seenHorde")
  local inAlliance = alliance ~= nil and inRuns(alliance, id)
  local inHorde = horde ~= nil and inRuns(horde, id)
  if inAlliance == inHorde then
    return nil
  end
  return inAlliance and QuestFlags.ALLIANCE or QuestFlags.HORDE
end

--------------------------------------------------------------------------------
-- Brief RB2 (owner QA 2026-10-17 item 194, the addon half of ItemTree-Data's RB3): the side a quest
-- the pipeline opened to both sides LEANS to. ItemTree-Data's QS4 opens a quest to both where our
-- own data names one side and the claims say both or the other (the owner's "if we're unsure show
-- to both"); RB3 ships the side our data leaned to as two soft lists:
--   leanAlliance, leanHorde   id runs: quests open to both whose own data leaned to that side
-- Read where Diff.quests carries them (the shape of every other quest list there), else at the top
-- of Diff, and read defensively: a build compiled before RB3 ships neither, and a quest in both
-- lists, or in neither, leans nowhere. A lean is never a side: nothing hides or counts by it; the
-- other side's player only reads "Possibly Horde only" on the quest's rows and page.
--------------------------------------------------------------------------------

-- One lean list as id runs, or nil where the data carries none: Diff.quests first, then Diff.
local function leanRuns(name)
  local runs = listingRuns(name)
  if runs then
    return runs
  end
  local diff = module("Diff")
  local top = type(diff) == "table" and diff[name] or nil
  if type(top) ~= "table" then
    return nil
  end
  return top
end

-- Whether an id is in a lean list. Id runs ({from, count, ...}) are the shipped shape; a set
-- ({ [id] = true }) is read too, so a list written either way answers the same.
local function inLean(list, id)
  if list[id] == true then
    return true
  end
  if #list < 2 then
    return false
  end
  -- A list of any other shape answers no rather than raising.
  local ok, hit = pcall(inRuns, list, id)
  return ok and hit == true
end

--- The side a quest open to both sides leans to, QuestFlags.ALLIANCE or QuestFlags.HORDE, or nil:
--- no lists shipped, no id, a quest QuestFlags.Side already sides (its side stands), and a quest in
--- both lists or in neither. Pure over the shipped module.
function QuestFlags.Lean(questId)
  local id = toId(questId)
  if not id or QuestFlags.Side(id) ~= nil then
    return nil
  end
  local alliance = leanRuns("leanAlliance")
  local horde = leanRuns("leanHorde")
  local inAlliance = alliance ~= nil and inLean(alliance, id)
  local inHorde = horde ~= nil and inLean(horde, id)
  if inAlliance == inHorde then
    return nil
  end
  return inAlliance and QuestFlags.ALLIANCE or QuestFlags.HORDE
end

--------------------------------------------------------------------------------
-- Brief HF1 of 2026-10-23 (QA item 406, the follow up to ItemTree-Data's CX1, which opens the
-- paladin and shaman class quests to both sides with a lean): whether the shipped lists speak for a
-- quest's side at all. ItemTree-Data works a side out for every quest its lists cover (docs/quests.md,
-- "A recorded quest's side" and brief QS4): a quest in alliance or horde is that side's, and one in
-- neither is open to both, with or without a lean (RB3's leanAlliance / leanHorde, which only word
-- or order a row). They cover every Classic quest (known) and this build's own (new). An edge's own
-- side (the Classic Era table's f on a reward row) never stands against them: Core/Graph.lua
-- Graph.QuestSide reads it only for a quest they say nothing about, an id in none of those lists or
-- any id at all while the build ships no side lists (compiled before brief Q1, or stating no QuestV2).
--------------------------------------------------------------------------------

-- The side lists, the seen lists (open to both, brief QS2b) and the quests they were worked out over;
-- the lean lists are read apart (leanRuns).
local SPOKEN_LISTS = { "alliance", "horde", "seenAlliance", "seenHorde", "known", "new" }

--- Whether the shipped lists decide one quest's side (true: QuestFlags.Side sides it, or it is open
--- to both, leaning or not) or say nothing about it (false: see above). Pure over the shipped module.
function QuestFlags.SpeaksFor(questId)
  local id = toId(questId)
  if not id or (listingRuns("alliance") == nil and listingRuns("horde") == nil) then
    return false
  end
  for _, name in ipairs(SPOKEN_LISTS) do
    local runs = listingRuns(name)
    if runs and inRuns(runs, id) then
      return true
    end
  end
  for _, name in ipairs({ "leanAlliance", "leanHorde" }) do
    local runs = leanRuns(name)
    if runs and inLean(runs, id) then
      return true
    end
  end
  return false
end

--------------------------------------------------------------------------------
-- Brief QB2: the quest cache bank's answers (ItemTree-Data docs/quests.md, "The quest cache"). The
-- client's quest cache states a quest's rewards for every quest a player has opened, and the compile
-- compares each banked quest with the Classic Era lists. Diff.quests carries, each key left off where
-- it is empty:
--   rewardsSeen     id runs: Classic quests whose cached rewards are the Classic ones. Their reward
--                   rows are confirmed, so they wear no Predicted mark (the owner's rule: no verified
--                   or predicted badge once the client confirms a fact).
--   rewardsChanged  id runs: Classic quests whose cached rewards differ: "changed in Forever".
--   foreverRewards  { [questId] = { {reward ids}, {choice ids} } } (QuestRewards' shape, the choice
--                   list left off when there is none; { {} } hands over nothing now): Forever's own
--                   lists for every changed quest and every cached Forever quest that hands over an
--                   item.
--   rewardSources   { [itemId] = { questId, ... } }: an item a quest's Forever lists hand over where
--                   its Classic lists do not.
--   classes         { [questId] = class mask }: a cached quest whose sort names a class.
-- One table read or one binary search per question; nothing loops over quests.
--------------------------------------------------------------------------------

QuestFlags.REWARD_SEEN = "seen"
QuestFlags.REWARD_CHANGED = "changed"
-- The provenance the cache's own edges carry (Core/Sources.lua words it, "From client data").
QuestFlags.PROVENANCE = "client"

-- One of the brief QB2 keys, or nil where the data carries none.
local function cacheKey(name)
  local diff = module("Diff")
  local quests = diff and diff.quests
  local value = type(quests) == "table" and quests[name] or nil
  if type(value) ~= "table" then
    return nil
  end
  return value
end

-- True where the client's quest cache confirmed this Classic quest's rewards as Classic Era's.
function QuestFlags.RewardsSeen(questId)
  local id = toId(questId)
  local runs = id and cacheKey("rewardsSeen") or nil
  return runs ~= nil and inRuns(runs, id)
end

-- True where the client's quest cache states other rewards for this Classic quest.
function QuestFlags.RewardsChanged(questId)
  local id = toId(questId)
  local runs = id and cacheKey("rewardsChanged") or nil
  return runs ~= nil and inRuns(runs, id)
end

-- Forever's own reward and choice lists for one quest, each a list (empty where there is none), or
-- nil where the cache states no lists for it. The lists are the data's own and must not be modified.
function QuestFlags.ForeverRewards(questId)
  local id = toId(questId)
  local lists = id and cacheKey("foreverRewards") or nil
  local entry = lists and lists[id]
  if type(entry) ~= "table" then
    return nil
  end
  local rewards = type(entry[1]) == "table" and entry[1] or EMPTY
  local choices = type(entry[2]) == "table" and entry[2] or EMPTY
  return rewards, choices
end

-- Whether one item is in a quest's Forever lists: "reward", "choice" or nil (also nil where the
-- cache states no lists for the quest).
function QuestFlags.ForeverRewardKind(questId, itemId)
  local item = toId(itemId)
  local rewards, choices = QuestFlags.ForeverRewards(questId)
  if not item or not rewards then
    return nil
  end
  for _, value in ipairs(rewards) do
    if toId(value) == item then
      return "reward"
    end
  end
  for _, value in ipairs(choices) do
    if toId(value) == item then
      return "choice"
    end
  end
  return nil
end

-- The quests whose Forever lists hand over an item their Classic lists do not, as a new list of
-- quest ids (empty for none).
function QuestFlags.RewardQuests(itemId)
  local out = {}
  local item = toId(itemId)
  local sources = item and cacheKey("rewardSources") or nil
  local list = sources and sources[item]
  for _, value in ipairs(type(list) == "table" and list or EMPTY) do
    local questId = toId(value)
    if questId then
      out[#out + 1] = questId
    end
  end
  return out
end

-- The class mask the client's quest cache states for one quest, or nil. Checked before the Classic
-- Era table's qa (Core/EraSources.lua E:QuestClasses, Core/Keep.lua Keep.QuestClasses): the Forever
-- answer wins where there is one.
function QuestFlags.Classes(questId)
  local id = toId(questId)
  local classes = id and cacheKey("classes") or nil
  local mask = classes and tonumber(classes[id]) or nil
  if mask == nil or mask <= 0 then
    return nil
  end
  return mask
end

-- What the quest cache says about one Classic Era reward row (the quest hands the item over in
-- Classic Era): REWARD_SEEN where the client confirmed it (the quest's rewards were seen as Classic
-- Era's, or the quest changed and the item is still in its Forever lists), REWARD_CHANGED where the
-- quest changed and the item is no longer in them, nil where the cache says nothing.
function QuestFlags.RewardState(questId, itemId)
  if QuestFlags.RewardsSeen(questId) then
    return QuestFlags.REWARD_SEEN
  end
  if not QuestFlags.RewardsChanged(questId) then
    return nil
  end
  if QuestFlags.ForeverRewardKind(questId, itemId) ~= nil then
    return QuestFlags.REWARD_SEEN
  end
  return QuestFlags.REWARD_CHANGED
end

-- Marks one Classic Era reward edge (an item's QUEST_REWARD row, a quest's QUEST_REWARDS row) by
-- RewardState: a confirmed reward is the baseline tier with listed = true, which takes off the
-- Predicted mark the way brief Q1's listed quest rows do; a changed one carries rewardChanged, which
-- Core/ViewModel.lua draws as the Changed mark ("changed in Forever"). Answers edge.
function QuestFlags.MarkReward(edge, questId, itemId)
  if type(edge) ~= "table" then
    return edge
  end
  local state = QuestFlags.RewardState(questId, itemId)
  if state == QuestFlags.REWARD_SEEN then
    local Confidence = ItemTree.Confidence
    edge.confidence = type(Confidence) == "table" and Confidence.BASELINE or "baseline"
    edge.listed = true
  elseif state == QuestFlags.REWARD_CHANGED then
    edge.rewardChanged = true
  end
  return edge
end

-- The cache's own edges, for Graph.RegisterProvider. Client data, so the "mined" tier ("From client
-- data", no mark):
--   item:<id>   up    QUEST_REWARD   a quest whose Forever lists hand the item over where its Classic
--                                    lists do not (rewardSources); a choice says so
--   quest:<id>  down  QUEST_REWARDS  every item in the quest's Forever lists (foreverRewards), so a
--                                    Classic reward still listed there is confirmed (it outranks the
--                                    Classic Era row of the same item) and a new one is drawn
-- The quest's title is the namer's (QuestFlags.Namer): never a shipped title.
function QuestFlags.EdgesFor(key, direction)
  local out = {}
  local Graph, Edges, Confidence = ItemTree.Graph, ItemTree.Edges, ItemTree.Confidence
  if type(Graph) ~= "table" or type(Edges) ~= "table" or type(Confidence) ~= "table" then
    return out
  end
  local L = ItemTree.L or {}
  local T = Edges.Types
  local kind, id = Graph.Parse(key)
  if kind == "item" and direction == Edges.UP then
    for _, questId in ipairs(QuestFlags.RewardQuests(id)) do
      out[#out + 1] = {
        type = T.QUEST_REWARD,
        target = Graph.Key("quest", questId),
        confidence = Confidence.MINED,
        group = L["Quests"],
        provenance = QuestFlags.PROVENANCE,
        choice = QuestFlags.ForeverRewardKind(questId, id) == "choice" or nil,
      }
    end
  elseif kind == "quest" and direction == Edges.DOWN then
    local rewards, choices = QuestFlags.ForeverRewards(id)
    for _, pair in ipairs({ { rewards, false }, { choices, true } }) do
      for _, value in ipairs(pair[1] or EMPTY) do
        local itemId = toId(value)
        if itemId then
          out[#out + 1] = {
            type = T.QUEST_REWARDS,
            target = Graph.Key("item", itemId),
            confidence = Confidence.MINED,
            group = L["Rewards"],
            provenance = QuestFlags.PROVENANCE,
            choice = pair[2] or nil,
          }
        end
      end
    end
  end
  return out
end

--------------------------------------------------------------------------------
-- Brief RB1c (the owner's ruling "A" of 2026-10-17 on QA item 190's Naxxramas quests): a quest an
-- instance holds back. 72 of the unlisted one time quests RB1 counts are the Naxxramas tier 3 class
-- quests, each asking for a token only Naxxramas drops; the client ships the instance but not those
-- quests, so game data cannot say whether the raid is open. The owner: "Or can we check if a player
-- has ever stepped into an instance?" ... "Lets do A then". Until THIS character has been inside the
-- instance (ItemTreeCharDB.instancesEntered, recorded below from GetInstanceInfo) or a client build
-- lists the quest (the pipeline then never gates it), a gated quest counts on the item page and
-- folds under the modifier on the tooltip like a repeatable quest, and never keeps or locks an item
-- (Core/Keep.lua Keep.QuestHeldBack, Core/Graph.lua Graph.Summary). Diff.quests carries, left off
-- where there is none (ItemTree-Data quest_gates.py):
--   gates   { [gateId] = { name = "Naxxramas", maps = { 533, 2921 }, quests = id runs } }
-- the gate id being the instance's Classic map id. `/itemtree demo naxx on | off` pretends either way.
--------------------------------------------------------------------------------

local function gatesTable()
  local diff = module("Diff")
  local quests = diff and diff.quests
  local gates = type(quests) == "table" and quests.gates or nil
  if type(gates) ~= "table" then
    return nil
  end
  return gates
end

-- The gate (its id) that holds one quest back in the shipped data, or nil: not gated, no id or no
-- data. A binary search per gate (one gate today).
function QuestFlags.GateOf(questId)
  local id = toId(questId)
  local gates = id and gatesTable() or nil
  if not gates then
    return nil
  end
  for gateId, gate in pairs(gates) do
    local runs = type(gate) == "table" and gate.quests or nil
    if type(runs) == "table" and inRuns(runs, id) then
      return tonumber(gateId)
    end
  end
  return nil
end

-- The client's name for a gate ("Naxxramas"), or nil.
function QuestFlags.GateName(gateId)
  local gates = gatesTable()
  local gate = gates and gates[tonumber(gateId) or -1] or nil
  local name = type(gate) == "table" and gate.name or nil
  if type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- Every map id of a gate (its own id first where the data names none), a fresh list.
function QuestFlags.GateMaps(gateId)
  local id = tonumber(gateId)
  local gates = gatesTable()
  local gate = id and gates and gates[id] or nil
  local out = {}
  for _, map in ipairs(type(gate) == "table" and type(gate.maps) == "table" and gate.maps or EMPTY) do
    if tonumber(map) then
      out[#out + 1] = tonumber(map)
    end
  end
  if #out == 0 and id then
    out[1] = id
  end
  return out
end

-- The gate one instance map id belongs to (any of its maps), or nil: what the watcher records.
function QuestFlags.GateOfMap(mapId)
  local map = tonumber(mapId)
  local gates = map and gatesTable() or nil
  if not gates then
    return nil
  end
  for gateId in pairs(gates) do
    for _, one in ipairs(QuestFlags.GateMaps(gateId)) do
      if one == map then
        return tonumber(gateId)
      end
    end
  end
  return nil
end

-- The character's store of the gate maps it has been inside, { [mapId] = true }, or nil.
local function entered()
  local charDb = ItemTree.charDb
  local store = type(charDb) == "table" and charDb.instancesEntered or nil
  if type(store) == "table" then
    return store
  end
  return nil
end

-- Whether a gate is open for this character: the demo's pretend answer first (Core/Demo.lua
-- Demo.GatesOpen: true, false or nil), else whether ItemTreeCharDB.instancesEntered holds any of the
-- gate's maps. false for no id.
function QuestFlags.GateOpen(gateId)
  local id = tonumber(gateId)
  if not id then
    return false
  end
  local demo = ItemTree.Demo
  if type(demo) == "table" and type(demo.GatesOpen) == "function" then
    local ok, pretend = pcall(demo.GatesOpen)
    if ok and pretend ~= nil then
      return pretend == true
    end
  end
  local store = entered()
  if not store then
    return false
  end
  for _, map in ipairs(QuestFlags.GateMaps(id)) do
    if store[map] == true then
      return true
    end
  end
  return false
end

-- The gate that holds one quest back for this character now (gated in the data and not open), or nil.
-- Brief WS1 (the owner's ruling "A for writs" of 2026-10-17 night): and, where no instance holds it
-- back, QuestFlags.STARTER_GATE for a quest an item starts while the character holds none of its
-- starters and does not have it in the log (QuestFlags.StarterHeldBack). starts is true where the item
-- asked about itself starts the quest: the starter keeps its own use (a start is never held back by its
-- starter). The second answer is QuestFlags.StarterHeldBack's (true, false, or nil for a quest no item
-- starts or a start), so Keep can watch the starter while an instance holds the quest too: both gates
-- apply, and the quest keeps only when both allow.
function QuestFlags.HeldBack(questId, starts)
  local gate = QuestFlags.GateOf(questId)
  if gate and QuestFlags.GateOpen(gate) then
    gate = nil
  end
  local starter = nil
  if not starts then
    starter = QuestFlags.StarterHeldBack(questId)
  end
  if gate then
    return gate, starter
  end
  if starter == true then
    return QuestFlags.STARTER_GATE, starter
  end
  return nil, starter
end

--------------------------------------------------------------------------------
-- Brief WS1 (the owner's ruling "A for writs" of 2026-10-17 night, QA item 226: GF9's 45 Craftsman's Writ
-- quests kept Heavy Quiver, Small Silk Pack and Dark Leather Tunic for every class at any level): "A
-- quest that starts from an item counts for Keep only while you hold that item (bags or bank) or have
-- the quest in your log. The quest page still lists it." For every quest the shipped QuestStarts module
-- names a starter for (ItemTree-Data item_lists.py build_quest_starts, the Forever item rows' start
-- quest), until the character holds one of its starters (Holds: bags and bank) or has the quest in its
-- log (OnQuest), the quest is held back like an instance's (QuestFlags.HeldBack answers STARTER_GATE):
-- it counts on the item page, folds under the modifier on the tooltip ("1 quest (started by an item
-- you don't have)") and never keeps or locks an item. A quest the character has completed is not held back
-- (its need reads done, as before), and the starter itself keeps its own [Use] (a start is never held
-- back). Keep re-reads it on a bag, bank or quest log change (Core/Keep.lua Keep.RecheckStarters).
--------------------------------------------------------------------------------

-- The gate id the starter gate files under (Keep.HeldBackCount's byGate, UI/Tooltip.lua
-- OtherQuestLines): never an instance's map id.
QuestFlags.STARTER_GATE = -1

-- The items that start one quest, the shipped QuestStarts list (sorted, developer items left out), or
-- nil: no item starts it, no id, or the module is not registered yet (the data addon is never loaded
-- for this: a quest is not held back before the item data is there, as Keep scores nothing before it).
function QuestFlags.Starters(questId)
  local id = toId(questId)
  local Data = ItemTree.Data
  if not id or type(Data) ~= "table" or type(Data.Has) ~= "function" or not Data:Has("QuestStarts") then
    return nil
  end
  local starts = module("QuestStarts")
  local list = starts and starts[id] or nil
  if type(list) ~= "table" or list[1] == nil then
    return nil
  end
  return list
end

-- Whether one item is among a quest's starters. Pure over the shipped list.
function QuestFlags.IsStarter(itemId, questId)
  local item = toId(itemId)
  for _, starter in ipairs(item and QuestFlags.Starters(questId) or EMPTY) do
    if toId(starter) == item then
      return true
    end
  end
  return false
end

-- Brief ASF1 (the Opus review of round AS, M1): the quest an item's own row says it starts, its `sq` (the
-- fact Core/Graph.lua's STARTS_QUEST edge draws, so the item reads "Use: starts a quest"), else, for an item
-- this build withholds, its Classic Era row's sq (Data:EraItem), whether Classic Era details are shown or
-- not: Essence of Eranikus 10454 starts The Essence of Eranikus 3373 by the Classic Era ItemSparse alone,
-- and the Forever QuestStarts never names it. nil for none. Read only where the item data is registered
-- (Data:Has), so it never loads the data addon; the Era row only for a withheld item, so an ordinary
-- item never builds the EraItems module for it.
function QuestFlags.RowStartQuest(itemId)
  local id = toId(itemId)
  local Data = ItemTree.Data
  if not id or type(Data) ~= "table" or type(Data.Has) ~= "function" or type(Data.GetItem) ~= "function" then
    return nil
  end
  if not Data:Has("Index") then
    return nil
  end
  local ok, row = pcall(Data.GetItem, Data, id)
  local quest = ok and type(row) == "table" and toId(row.sq) or nil
  if quest then
    return quest
  end
  if type(Data.IsUndiscovered) ~= "function" or type(Data.EraItem) ~= "function" or not Data:Has("EraItems") then
    return nil
  end
  local okWithheld, withheld = pcall(Data.IsUndiscovered, Data, id)
  if not okWithheld or withheld ~= true then
    return nil
  end
  local okEra, era = pcall(Data.EraItem, Data, id)
  return okEra and type(era) == "table" and toId(era.sq) or nil
end

-- Brief ASF1 (M1): whether an item starts a quest by any fact the addon ships: the Forever QuestStarts list
-- (QuestFlags.IsStarter) or the item's own row (QuestFlags.RowStartQuest). What Core/Keep.lua StartsQuest
-- and Core/EraSources.lua ProvidedIsStarter read, so the Classic Era qp (CMaNGOS fills SrcItemId with an
-- item started quest's own starter) never makes a quest's starter its provided item. The starter gate
-- (QuestFlags.Starters, StarterHeldBack) stays on QuestStarts alone. Pure over the shipped data.
function QuestFlags.ItemStartsQuest(itemId, questId)
  if QuestFlags.IsStarter(itemId, questId) then
    return true
  end
  local quest = toId(questId)
  return quest ~= nil and QuestFlags.RowStartQuest(itemId) == quest
end

-- Whether the starter gate holds one quest back for this character now: true (an item starts it, the
-- character holds none of its starters, has not got it in the log and has not completed it), false
-- (an item starts it and one of those holds, or the client cannot say: the quest keeps as it did before
-- WS1, the safe side), nil for a quest no item starts. Reads QuestFlags.Holds and QuestFlags.OnQuest
-- (the client, the demo first) and Core/Keep.lua Keep.QuestCompleted.
function QuestFlags.StarterHeldBack(questId)
  local starters = QuestFlags.Starters(questId)
  if not starters then
    return nil
  end
  local id = toId(questId)
  local keep = ItemTree.Keep
  if type(keep) == "table" and type(keep.QuestCompleted) == "function" then
    local ok, done = pcall(keep.QuestCompleted, id)
    if ok and done == true then
      return false
    end
  end
  local unknown = false
  for _, starter in ipairs(starters) do
    local held = QuestFlags.Holds(starter)
    if held == true then
      return false
    end
    unknown = unknown or held == nil
  end
  local onQuest = QuestFlags.OnQuest(id)
  if onQuest == true or onQuest == nil or unknown then
    return false
  end
  return true
end

-- Records that the character is inside one instance map, in charDb.instancesEntered (made on the
-- first one: an older character's table has none), where the map is a gate's. Answers true where it
-- was new. Pure over the tables handed in.
function QuestFlags.RecordEntered(charDb, mapId)
  local map = tonumber(mapId)
  if type(charDb) ~= "table" or not map or QuestFlags.GateOfMap(map) == nil then
    return false
  end
  local store = charDb.instancesEntered
  if type(store) ~= "table" then
    store = {}
    charDb.instancesEntered = store
  end
  if store[map] == true then
    return false
  end
  store[map] = true
  return true
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

-- Titles the client could not give, so a quest is asked once a session. A quest page the player
-- opens asks the client again through its own reader (Core/ViewModel.lua QuestLive) and names it.
QuestFlags.untitled = {}

-- The title the client gives a quest by its id (C_QuestLog.GetTitleForQuestID, a read), or nil.
function QuestFlags.ClientTitle(questId)
  local id = toId(questId)
  local questLog = rawget(_G, "C_QuestLog")
  if not id or type(questLog) ~= "table" or type(questLog.GetTitleForQuestID) ~= "function" then
    return nil
  end
  local ok, title = pcall(questLog.GetTitleForQuestID, id)
  if ok and type(title) == "string" and title ~= "" then
    return title
  end
  return nil
end

-- The namer for a quest only the cache names (a Forever quest in foreverRewards or rewardSources):
-- the client's own title, never a shipped one. Asked by Core/Graph.lua only for a key nothing else
-- names; a title the client cannot give answers nil, so the row reads "Quest <id>".
function QuestFlags.Namer(key)
  local Graph = ItemTree.Graph
  if type(Graph) ~= "table" or type(Graph.Parse) ~= "function" then
    return nil
  end
  local kind, id = Graph.Parse(key)
  if kind ~= "quest" or QuestFlags.untitled[id] or not QuestFlags.ForeverRewards(id) then
    return nil
  end
  local title = QuestFlags.ClientTitle(id)
  if not title then
    QuestFlags.untitled[id] = true
  end
  return title
end

--------------------------------------------------------------------------------
-- Brief RB3 (ItemTree-Data quest_twins.py, the owner's QA item 196 and his choice A of 2026-10-17): a
-- dead twin quest, one with a live quest's title and rewards that no source of ours gives or takes
-- back (The Captain's Chest 614 beside 8551, given and handed in by Captain Hecklebury Smotts), is
-- folded into its live quest: one row and one count, and its id opens the live quest. Diff.quests
-- carries, left off where there is none:
--   twins   { [twinId] = liveId }
-- Core/Graph.lua folds every edge, count and quest list through Graph.FoldTwinKey.
--------------------------------------------------------------------------------

-- The live quest a dead twin folds into, or nil: not a twin, no id or no data. One table read.
function QuestFlags.LiveTwin(questId)
  local id = toId(questId)
  local diff = id and module("Diff") or nil
  local quests = diff and diff.quests
  local twins = type(quests) == "table" and quests.twins or nil
  local live = type(twins) == "table" and toId(twins[id]) or nil
  if live and live ~= id then
    return live
  end
  return nil
end

-- Brief RB1c: the instance map id the character stands in (GetInstanceInfo's eighth answer, the
-- instance id, a map id), or nil outside an instance, before the client answers, or where the client
-- hands back a value that cannot be read (bible B10: Util.CanRead before any compare). A read only.
function QuestFlags.InstanceMap()
  local info = rawget(_G, "GetInstanceInfo")
  if type(info) ~= "function" then
    return nil
  end
  local ok, _, instanceType, _, _, _, _, _, instanceId = pcall(info)
  if not ok then
    return nil
  end
  local util = ItemTree.Util
  local readable = type(util) ~= "table" or type(util.CanRead) ~= "function" or util.CanRead
  if type(readable) == "function" and not (readable(instanceType) and readable(instanceId)) then
    return nil
  end
  if type(instanceType) ~= "string" or instanceType == "none" or type(instanceId) ~= "number" then
    return nil
  end
  return instanceId
end

-- Brief WS1: whether the character holds one item, bags and bank (C_Item.GetItemCount with the bank,
-- Blizzard_APIDocumentationGenerated/ItemDocumentation.lua:451 on the forever mirror; the legacy global
-- where the table is not there): true or false, nil where the client hands back a count that cannot be
-- read (bible B10). The demo's pretend count answers first (Core/Demo.lua Demo.Have, `/itemtree demo have
-- <id> <n>`). With no client at all (busted) nothing is held. One local count for one item, never an
-- item data request.
function QuestFlags.Holds(itemId)
  local id = toId(itemId)
  if not id then
    return false
  end
  local demo = ItemTree.Demo
  if type(demo) == "table" and type(demo.Have) == "function" then
    local ok, pretend = pcall(demo.Have, id)
    if ok and tonumber(pretend) then
      return tonumber(pretend) > 0
    end
  end
  local itemApi = rawget(_G, "C_Item")
  local ask = type(itemApi) == "table" and itemApi.GetItemCount or nil
  if type(ask) ~= "function" then
    ask = rawget(_G, "GetItemCount")
  end
  if type(ask) ~= "function" then
    return false
  end
  local ok, count = pcall(ask, id, true)
  if not ok then
    return nil
  end
  local util = ItemTree.Util
  if type(util) == "table" and type(util.CanRead) == "function" and not util.CanRead(count) then
    return nil
  end
  count = tonumber(count)
  if count == nil then
    return nil
  end
  return count > 0
end

-- Brief WS1: whether one quest is in the character's log (C_QuestLog.IsOnQuest,
-- Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua:825 on the forever mirror; else a log
-- index for it): true or false, nil where the answer cannot be read. The demo answers first: a quest
-- pretended in the log (`/itemtree demo quest <id> log`) is, one pretended done or off is not, and so is
-- every other while "none" is pretended (Core/Demo.lua Demo.Quest). With no client nothing is in it.
function QuestFlags.OnQuest(questId)
  local id = toId(questId)
  if not id then
    return false
  end
  local demo = ItemTree.Demo
  if type(demo) == "table" and type(demo.QuestPretended) == "function" then
    local ok, pretended = pcall(demo.QuestPretended, id)
    if ok and pretended then
      local quest = type(demo.Quest) == "function" and demo.Quest(id) or nil
      return type(quest) == "table" and quest.kind == "log"
    end
  end
  local questLog = rawget(_G, "C_QuestLog")
  if type(questLog) ~= "table" then
    return false
  end
  local util = ItemTree.Util
  local canRead = type(util) == "table" and type(util.CanRead) == "function" and util.CanRead or nil
  if type(questLog.IsOnQuest) == "function" then
    local ok, onQuest = pcall(questLog.IsOnQuest, id)
    if not ok or (canRead and not canRead(onQuest)) then
      return nil
    end
    return onQuest == true
  end
  if type(questLog.GetLogIndexForQuestID) == "function" then
    local ok, index = pcall(questLog.GetLogIndexForQuestID, id)
    if not ok or (canRead and not canRead(index)) then
      return nil
    end
    return type(index) == "number" and index > 0
  end
  return false
end

--------------------------------------------------------------------------------
-- Brief RF375 (the review's M1): whether the client's quest log wants an item, for Keep's finished
-- verdict (Core/Keep.lua Keep.LogWants), so ItemTree never calls an item done while a quest in the log,
-- one our data may not know, asks for it. The mirror of Jettison's Client/Quests.lua Quests.Needs (its
-- isQuestNeeded lock): the log read the modern way, C_QuestLog.GetNumQuestLogEntries, GetInfo (headers
-- skipped) and GetQuestObjectives(questID) per quest (Blizzard_APIDocumentationGenerated/
-- QuestLogDocumentation.lua at build 1.60.1.70450, mirror commit 172a387: :303, :191 and :477, the
-- QuestObjectiveInfo structure at :1581, { text, type, finished, numFulfilled, numRequired }), else the
-- Classic Era globals; only "item" objectives count, a finished one too (the player still hands the
-- items in), keyed by the lower cased name the objective's words give ("Boar Meat: 3/10" -> "boar
-- meat"). An objective names its item in words only, never by id, so the item is matched by its name.
-- The index is built on the first ask after a log change (MarkLogDirty: Core/Keep.lua calls it on
-- QUEST_TURNED_IN, QUEST_ACCEPTED, QUEST_REMOVED and QUEST_LOG_UPDATE) and at most once every
-- LOG_REBUILD_SECONDS, as Jettison's Quests.REBUILD_SECONDS; in between the last index answers. One
-- GetQuestObjectives per quest in the log, never an item query, never a server call, never a walk of any
-- quest id list (memory: no bulk API calls). Every client value goes through Util.CanRead first (bible
-- B10); a secret one is taken as absent. In memory only.
--------------------------------------------------------------------------------

QuestFlags.LOG_REBUILD_SECONDS = 1
-- The most log entries read, headers included (Jettison's Quests.MAX_ENTRIES).
QuestFlags.LOG_MAX_ENTRIES = 100

-- { [lower cased item name] = true }, or nil before the first read.
QuestFlags.logWants = nil
QuestFlags.logDirty = true
QuestFlags.logBuiltAt = nil
-- How many times the index was read off the client, which a spec reads back rather than timing.
QuestFlags.logReads = 0

--- The thing one objective line names: "Boar Meat: 3/10" and "3/10 Boar Meat" -> "Boar Meat", a
--- trailing bracket ("(Complete)") dropped, "Boar Meat:" -> "Boar Meat". nil for no text. Jettison's
--- Quests.ParseObjective's shapes. Pure.
function QuestFlags.ObjectiveName(text)
  if type(text) ~= "string" then
    return nil
  end
  local line = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s*%b()$", "")
  local name = line:match("^(.-)%s*:%s*%d+%s*/%s*%d+$")
  if not name then
    name = line:match("^%d+%s*/%s*%d+%s+(.+)$")
  end
  if not name then
    name = line:gsub("%s*:%s*$", "")
  end
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then
    return nil
  end
  return name
end

--- The wanted names out of a read log, { { questId, objectives = { { text, type } } } } ->
--- { [lower cased name] = true }, "item" objectives only. Pure.
function QuestFlags.LogWantsIndex(entries)
  local index = {}
  for _, entry in ipairs(type(entries) == "table" and entries or EMPTY) do
    local objectives = type(entry) == "table" and entry.objectives or nil
    for _, objective in ipairs(type(objectives) == "table" and objectives or EMPTY) do
      if type(objective) == "table" and objective.type == "item" then
        local name = QuestFlags.ObjectiveName(objective.text)
        if name then
          index[name:lower()] = true
        end
      end
    end
  end
  return index
end

-- A client value, or nil where it is secret (Util.CanRead; no helper: readable).
local function readable(value)
  local util = ItemTree.Util
  if type(util) == "table" and type(util.CanRead) == "function" and not util.CanRead(value) then
    return nil
  end
  return value
end

local function callGlobal(name, ...)
  local fn = rawget(_G, name)
  if type(fn) ~= "function" then
    return false
  end
  return pcall(fn, ...)
end

--- The log's quests and their objectives off the client, the modern way first, { { questId,
--- objectives = { { text, type } } } }, or nil where the client has no log to read.
function QuestFlags.ReadLogObjectives()
  local questLog = rawget(_G, "C_QuestLog")
  if
    type(questLog) == "table"
    and type(questLog.GetNumQuestLogEntries) == "function"
    and type(questLog.GetInfo) == "function"
    and type(questLog.GetQuestObjectives) == "function"
  then
    local ok, count = pcall(questLog.GetNumQuestLogEntries)
    count = ok and tonumber(readable(count)) or nil
    if count then
      local entries = {}
      for index = 1, math.min(count, QuestFlags.LOG_MAX_ENTRIES) do
        local okInfo, info = pcall(questLog.GetInfo, index)
        local questId = okInfo and type(info) == "table" and not readable(info.isHeader) and readable(info.questID)
          or nil
        questId = toId(questId)
        if questId then
          local objectives = {}
          local okList, list = pcall(questLog.GetQuestObjectives, questId)
          for _, objective in ipairs(okList and type(list) == "table" and list or EMPTY) do
            if type(objective) == "table" then
              objectives[#objectives + 1] = { text = readable(objective.text), type = readable(objective.type) }
            end
          end
          entries[#entries + 1] = { questId = questId, objectives = objectives }
        end
      end
      return entries
    end
  end
  local ok, count = callGlobal("GetNumQuestLogEntries")
  count = ok and tonumber(readable(count)) or nil
  if not count then
    return nil
  end
  local entries = {}
  for index = 1, math.min(count, QuestFlags.LOG_MAX_ENTRIES) do
    local okTitle, _, _, _, isHeader, _, _, _, questId = callGlobal("GetQuestLogTitle", index)
    questId = okTitle and not readable(isHeader) and toId(readable(questId)) or nil
    if questId then
      local objectives = {}
      local okBoards, boards = callGlobal("GetNumQuestLeaderBoards", index)
      for board = 1, math.min(okBoards and tonumber(readable(boards)) or 0, QuestFlags.LOG_MAX_ENTRIES) do
        local okBoard, text, kind = callGlobal("GetQuestLogLeaderBoard", board, index)
        if okBoard then
          objectives[#objectives + 1] = { text = readable(text), type = readable(kind) }
        end
      end
      entries[#entries + 1] = { questId = questId, objectives = objectives }
    end
  end
  return entries
end

--- The log changed: the next ask reads it again (once LOG_REBUILD_SECONDS have passed since the last).
function QuestFlags.MarkLogDirty()
  QuestFlags.logDirty = true
end

--- Whether a log change is waiting for its read (the last ask fell inside LOG_REBUILD_SECONDS).
function QuestFlags.LogPending()
  return QuestFlags.logDirty == true and QuestFlags.logWants ~= nil
end

--- Forgets the index (a spec, a reload).
function QuestFlags.ResetLog()
  QuestFlags.logWants = nil
  QuestFlags.logDirty = true
  QuestFlags.logBuiltAt = nil
  QuestFlags.logReads = 0
end

-- The clock the rebuild limit reads: the client's GetTime, else os.clock.
local function logNow()
  local ok, now = callGlobal("GetTime")
  now = ok and tonumber(readable(now)) or nil
  if now then
    return now
  end
  return os.clock()
end

-- One item's name from our item rows, only where they are loaded (never loading ItemTree_Data), or nil.
local function rowName(itemId)
  local data = ItemTree.Data
  local id = toId(itemId)
  if not id or type(data) ~= "table" or type(data.GetItem) ~= "function" then
    return nil
  end
  if type(data.OnDemandLoaded) == "function" then
    local ok, loaded = pcall(data.OnDemandLoaded, data)
    if ok and loaded == false then
      return nil
    end
  end
  local ok, row = pcall(data.GetItem, data, id)
  local name = ok and type(row) == "table" and row.n or nil
  return type(name) == "string" and name ~= "" and name or nil
end

--- Whether an item objective of a quest in the log names this item: name (the item's own, from our
--- data or a link; else the item rows' where loaded) matched by its lower cased form, as Jettison's
--- Client/Bags.lua looks a bag item up by its name. false for no name, no log or a log that wants
--- nothing. now is the clock (a spec states it).
function QuestFlags.LogWantsItem(itemId, name, now)
  if type(name) ~= "string" or name == "" then
    name = rowName(itemId)
  end
  if name == nil then
    return false
  end
  now = tonumber(now) or logNow()
  local due = QuestFlags.logBuiltAt == nil or now - QuestFlags.logBuiltAt >= QuestFlags.LOG_REBUILD_SECONDS
  if QuestFlags.logWants == nil or (QuestFlags.logDirty and due) then
    local entries = QuestFlags.ReadLogObjectives()
    QuestFlags.logWants = QuestFlags.LogWantsIndex(entries)
    QuestFlags.logReads = QuestFlags.logReads + 1
    QuestFlags.logBuiltAt = now
    -- An empty log is an answer too: the log filling in after login fires QUEST_LOG_UPDATE, which
    -- marks it again (a log read again on every ask would book a recheck every second, Keep's).
    QuestFlags.logDirty = false
  end
  return QuestFlags.logWants[name:lower()] == true
end

-- Brief RB1c: the answers a gate opening moves, dropped: Keep's held scores, the API's cache and the
-- tooltip's held blocks; another addon hears it as a setting change (ItemTreeAPI's change callback).
function QuestFlags.GatesChanged()
  local keep = ItemTree.Keep
  if type(keep) == "table" and type(keep.DropScores) == "function" then
    pcall(keep.DropScores)
  end
  local api = ItemTree.API
  if type(api) == "table" and type(api.Reset) == "function" then
    pcall(api.Reset)
  end
  local tooltip = ItemTree.Tooltip
  if type(tooltip) == "table" and type(tooltip.ResetRendered) == "function" then
    pcall(tooltip.ResetRendered)
  end
  if type(api) == "table" and type(api.NotifyChange) == "function" then
    pcall(api.NotifyChange, "setting")
  end
end

-- On entering the world and on each new zone: where the character stands inside a gate's map, it is
-- remembered for this character and the answers it moves are dropped. Answers whether it was new.
function QuestFlags.OnZone()
  local map = QuestFlags.InstanceMap()
  if map and QuestFlags.RecordEntered(ItemTree.charDb, map) then
    QuestFlags.GatesChanged()
    return true
  end
  return false
end

-- Our own event frame (the taint rule: nothing on a Blizzard frame), made at load where the client
-- is there to make one.
do
  local create = rawget(_G, "CreateFrame")
  if type(create) == "function" then
    local ok, watcher = pcall(create, "Frame")
    if ok and type(watcher) == "table" then
      pcall(watcher.RegisterEvent, watcher, "PLAYER_ENTERING_WORLD")
      pcall(watcher.RegisterEvent, watcher, "ZONE_CHANGED_NEW_AREA")
      pcall(watcher.SetScript, watcher, "OnEvent", function()
        QuestFlags.OnZone()
      end)
      QuestFlags.watcher = watcher
    end
  end
end

-- Registers the provider and the namer. Safe to call twice.
function QuestFlags.Install()
  local Graph = ItemTree.Graph
  if type(Graph) ~= "table" or type(Graph.RegisterProvider) ~= "function" then
    return false
  end
  if not Graph.HasProvider(QuestFlags.EdgesFor) then
    Graph.RegisterProvider(QuestFlags.EdgesFor)
  end
  if type(Graph.RegisterNamer) == "function" and not Graph.HasNamer(QuestFlags.Namer) then
    Graph.RegisterNamer(QuestFlags.Namer)
  end
  return true
end

QuestFlags.Install()

return QuestFlags
