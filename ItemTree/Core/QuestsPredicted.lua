-- Brief GF5: the predicted quest facts (ItemTree-Data docs/quests.md, the QuestsPredicted module).
-- Pure Lua, no WoW API above the divider.
--
-- The load on demand module QuestsPredicted (ItemTree_Data, all rights reserved; or, under the
-- pipeline's other placement, Diff.quests.predicted) holds facts about quests that no table of ours
-- states, each shown with the Predicted mark and below every fact of ours. Every entry is ONE packed
-- string of whole numbers, "," between them and ";" between the two lists of a pair:
--
--   rewards     { [questId] = "reward ids;choice ids" }, for a Classic quest only the items Forever adds
--   rewardOf    { [itemId] = "questIds" }, for items no other row of ours sources
--   facts       { [questId] = "level,required level,side,uiMap,money,xp,classes" }, 0 where unknown
--               and trailing zeros left off (side 1 Alliance, 2 Horde, 3 both; money in copper;
--               classes, brief GF6's follow up, a class quest's class mask in the client's bits);
--               brief QF2b: also a Classic quest's level and required level where Forever retuned
--               it, which Core/Keep.lua QuestLevels reads before the Classic Era table's ql
--   currency    { [questId] = "currencyId,amount,..." }
--   titles      { [questId] = title }, a plain string
--   giver       { [questId] = "ids" } and ender the same: a creature id positive, an object id negative
--   starts      { [npcId] = "questIds" } and ends the same: the creature pages' reverse maps
--   pins        { [id] = "uiMap,cell,..." }: APPROXIMATE positions, a cell floor(x) * 100 + floor(y),
--               the same signs as giver and ender
--   chain       { [questId] = "previous questIds;next questIds" }
--   objectives  { [questId] = "kind,id,count,..." }, kind 1 creature, 2 object, 3 item
--   provided    { [questId] = "itemId,count,..." }: brief PV1 (the owner's QA item 375), the items the
--               quest hands the player at accept (Making Do 97926 hands over Alexston's Reply 279048,
--               which its objectives also ask back)
--   providedBy  { [itemId] = "questIds" }: the item pages' reverse map of provided
--
-- The reader splits one entry the first time something asks for it and keeps the answer in a weak
-- cache per key (bible C1), so the module's first build makes no table per quest and a session pays
-- only for the quests and items it opens. A build with no module (an older data build) or no key
-- answers "no data": nil, or an empty list, never an error.
--
-- What reads it:
--   QuestsPredicted.Quest(questId)       the quest page's record (Core/ViewModel.lua ViewModel.Quest)
--   QuestsPredicted.EdgesFor(key, dir)   the graph provider, Predicted edges alone:
--     item:<id>   up    QUEST_REWARD     the quests rewardOf names, a choice says so ("Reward of")
--     item:<id>   down  QUEST_OBJECTIVE  the quests whose objectives ask for it, with the count
--     item:<id>   up    QUEST_PROVIDED   brief PV1: the quests providedBy names ("Provided by quest"),
--                                        the Sources tab's Quest rows beside the rewards
--     npc:<id>    down  GIVES_QUEST and TAKES_QUEST, the creature page's Starts and Ends rows
--   QuestsPredicted.Namer(key)           a quest's title where nothing else names it
--   QuestsPredicted.Titles()             the titles, for the quest search (Core/Data.lua)
--   QuestsPredicted.PinPoints(id, ...)   the approximate pins of a giver or a turn in (UI/Map.lua)
--
-- The provider and the namer never load ItemTree_Data: they answer only once the module is
-- registered, so a tooltip or a bag pass at login never pulls the data addon in for this. A page
-- that opens a quest may load it (QuestsPredicted.Quest).
--
-- Brief GF6 (the owner's ruling of 2026-10-14, "Turn it on"): Core/Keep.lua counts the item
-- objectives (QUEST_OBJECTIVE down edges, each marked with QuestsPredicted.OBJECTIVE_MARK) as quest
-- uses, judged as any other (level and grey from QuestsPredicted.Facts where nothing of ours states
-- them, side, reach, quantity, never keeps), its reason showing no mark (the owner's ruling of
-- 2026-10-14, "Remove the predicted text ... just keep the note internal"). The provider is
-- registered as Predicted only, so Graph.Summary never asks it; brief INT14: Graph.Summary counts the
-- item objectives Keep counts on its own (Graph.PredictedQuestNeeds over ObjectiveOf), so the item
-- page's count holds them too. Brief RB1 (the owner's standing rule of 2026-10-17, "Predicted IS our
-- data"): and the quests whose predicted rewards hand the item over (Graph.PredictedRewardQuests over
-- RewardOf), and a creature's Quests tab and quest line count its predicted Starts and Ends rows
-- (Core/ViewModel.lua ViewModel.NpcQuestCounts over NpcQuestCount).
local _, ItemTree = ...

local QuestsPredicted = {}
ItemTree.QuestsPredicted = QuestsPredicted

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

QuestsPredicted.MODULE = "QuestsPredicted"

-- The objective kinds, as the module states them.
QuestsPredicted.KILL = 1
QuestsPredicted.OBJECT = 2
QuestsPredicted.ITEM = 3

-- The sides facts states.
QuestsPredicted.ALLIANCE = 1
QuestsPredicted.HORDE = 2
QuestsPredicted.BOTH = 3

-- The order of the numbers in one facts entry.
QuestsPredicted.FACT_FIELDS = { "level", "requiredLevel", "side", "uiMap", "money", "xp", "classes" }

-- Brief GF6: the field an item objective edge carries (true), so Core/Keep.lua can count those edges
-- and no other Predicted edge (Core/Graph.lua EDGE_FIELDS carries it through a walk).
QuestsPredicted.OBJECTIVE_MARK = "predictedObjective"

-- A shared empty answer. Never modified.
local EMPTY = {}

local function positiveId(value)
  local id = tonumber(value)
  if not id or id <= 0 or id ~= math.floor(id) then
    return nil
  end
  return id
end

--------------------------------------------------------------------------------
-- The packed strings. Pure.
--------------------------------------------------------------------------------

--- The whole numbers in one packed list ("12,-4002,8"), in order, or an empty list for anything that
--- is not a string. Pure.
function QuestsPredicted.Numbers(text)
  local out = {}
  if type(text) ~= "string" then
    return out
  end
  for number in text:gmatch("-?%d+") do
    out[#out + 1] = tonumber(number)
  end
  return out
end

--- The two lists of one packed pair ("11,12;21,22", ";21", "4,5;"): the list before the ";" and
--- the list after it, the second empty where there is no ";". Two empty lists for anything that is
--- not a string. Pure.
function QuestsPredicted.Pair(text)
  if type(text) ~= "string" then
    return {}, {}
  end
  local at = text:find(";", 1, true)
  if not at then
    return QuestsPredicted.Numbers(text), {}
  end
  return QuestsPredicted.Numbers(text:sub(1, at - 1)), QuestsPredicted.Numbers(text:sub(at + 1))
end

--- One facts entry as { level, requiredLevel, side, uiMap, money, xp, classes }, each nil where the
--- entry states 0 or leaves it off (classes, brief GF6's follow up: a class mask, nil below 1). nil for
--- anything that is not a string. Pure.
function QuestsPredicted.FactsOf(text)
  if type(text) ~= "string" then
    return nil
  end
  local numbers = QuestsPredicted.Numbers(text)
  local out = {}
  for index, field in ipairs(QuestsPredicted.FACT_FIELDS) do
    local value = numbers[index]
    if type(value) == "number" and value ~= 0 then
      out[field] = value
    end
  end
  -- A cost (money below nought) never ships; were one to, it is no reward.
  if out.money and out.money < 0 then
    out.money = nil
  end
  local side = out.side
  if side ~= QuestsPredicted.ALLIANCE and side ~= QuestsPredicted.HORDE and side ~= QuestsPredicted.BOTH then
    out.side = nil
  end
  if out.classes and out.classes < 1 then
    out.classes = nil
  end
  return out
end

--- One objectives entry as { { kind, id, count }, ... }, a triple left out where its kind is none of
--- the three or its id is not a positive whole number; a count below 1 reads as 1. Brief QV3: such a
--- triple also carries stated = false, a count the entry does not state, which a quest page leaves
--- blank (every other count it draws, 1 included). Pure.
function QuestsPredicted.ObjectivesOf(text)
  local out = {}
  local numbers = QuestsPredicted.Numbers(text)
  for index = 1, #numbers - 2, 3 do
    local kind, id, count = numbers[index], positiveId(numbers[index + 1]), numbers[index + 2]
    if (kind == QuestsPredicted.KILL or kind == QuestsPredicted.OBJECT or kind == QuestsPredicted.ITEM) and id then
      local stated = nil
      if type(count) ~= "number" or count < 1 then
        count, stated = 1, false
      end
      out[#out + 1] = { kind = kind, id = id, count = count, stated = stated }
    end
  end
  return out
end

--- Brief PV1: one provided entry as { { id, count }, ... }, a pair left out where its id is not a
--- positive whole number; a count below 1 reads as 1. Pure.
function QuestsPredicted.ProvidedOf(text)
  local out = {}
  local numbers = QuestsPredicted.Numbers(text)
  for index = 1, #numbers - 1, 2 do
    local id, count = positiveId(numbers[index]), numbers[index + 1]
    if id then
      if type(count) ~= "number" or count < 1 then
        count = 1
      end
      out[#out + 1] = { id = id, count = math.floor(count) }
    end
  end
  return out
end

--- One currency entry as { { id, amount }, ... }, a pair left out where either is not positive. Pure.
function QuestsPredicted.CurrencyOf(text)
  local out = {}
  local numbers = QuestsPredicted.Numbers(text)
  for index = 1, #numbers - 1, 2 do
    local id, amount = positiveId(numbers[index]), numbers[index + 1]
    if id and type(amount) == "number" and amount > 0 then
      out[#out + 1] = { id = id, amount = amount }
    end
  end
  return out
end

--- One pins entry as { { map, cell }, ... } in the shipped order (densest first per map), a pair left
--- out where the map is not positive or the cell is outside 0 to 9999. Pure.
function QuestsPredicted.PinsOf(text)
  local out = {}
  local numbers = QuestsPredicted.Numbers(text)
  for index = 1, #numbers - 1, 2 do
    local map, cell = positiveId(numbers[index]), numbers[index + 1]
    if map and type(cell) == "number" and cell >= 0 and cell <= 9999 then
      out[#out + 1] = { map = map, cell = cell }
    end
  end
  return out
end

--- The approximate pins one pins list draws, one per cell at the cell's centre:
--- { map, x, y, zone, name, approx = true }, x and y in map percent. zoneOf(map) names a map, or
--- nil. The shape a trainer's approximate pins take (Core/Creatures.lua, brief TR1c), so UI/Map.lua
--- draws both alike. Pure over what it is handed.
function QuestsPredicted.PinsAt(spots, name, zoneOf)
  local out = {}
  for _, spot in ipairs(type(spots) == "table" and spots or EMPTY) do
    local zone = nil
    if type(zoneOf) == "function" then
      local ok, answer = pcall(zoneOf, spot.map)
      zone = ok and type(answer) == "string" and answer ~= "" and answer or nil
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

--- "5 Merchant's Favor": one currency reward in the client's own words, through nameOf(id), or
--- "currency 3402" where nothing names it. nil for an entry that is not one. Pure over nameOf.
function QuestsPredicted.CurrencyText(entry, nameOf)
  if type(entry) ~= "table" or not positiveId(entry.id) or type(entry.amount) ~= "number" then
    return nil
  end
  local name = nil
  if type(nameOf) == "function" then
    local ok, answer = pcall(nameOf, entry.id)
    name = ok and type(answer) == "string" and answer ~= "" and answer or nil
  end
  return math.floor(entry.amount) .. " " .. (name or string.format(L["currency %d"], entry.id))
end

--- The one compact money and XP line: "4s, 880 XP", "880 XP" or "4s"; nil where neither is stated.
--- moneyText(copper) words the money (Core/Sources.lua MoneyText). Pure over moneyText.
function QuestsPredicted.MoneyXpText(money, xp, moneyText)
  local coins = nil
  if type(money) == "number" and money > 0 and type(moneyText) == "function" then
    local ok, text = pcall(moneyText, money)
    coins = ok and type(text) == "string" and text ~= "" and text or nil
  end
  local points = type(xp) == "number" and xp > 0 and math.floor(xp) or nil
  if coins and points then
    return string.format(L["%s, %d XP"], coins, points)
  end
  if points then
    return string.format(L["%d XP"], points)
  end
  return coins
end

--------------------------------------------------------------------------------
-- The module and the per key caches
--------------------------------------------------------------------------------

-- A table a spec hands in place of the module (the packed shape). Never set in the client.
QuestsPredicted.source = nil

-- The packed table, or nil. load says whether asking may load ItemTree_Data: a page may, the
-- provider and the namer may not, so they answer only once the module is registered. The module
-- first, then the other placement, Diff.quests.predicted, which loads at login.
local function packed(load)
  if type(QuestsPredicted.source) == "table" then
    return QuestsPredicted.source
  end
  local Data = ItemTree.Data
  if type(Data) ~= "table" or type(Data.Get) ~= "function" then
    return nil
  end
  local function get(name)
    if not load and type(Data.Has) == "function" and not Data:Has(name) then
      return nil
    end
    local ok, value = pcall(Data.Get, Data, name)
    if ok and type(value) == "table" then
      return value
    end
    return nil
  end
  local module = get(QuestsPredicted.MODULE)
  if module then
    return module
  end
  local diff = get("Diff")
  local quests = diff and diff.quests
  local predicted = type(quests) == "table" and quests.predicted or nil
  if type(predicted) == "table" then
    return predicted
  end
  return nil
end

-- The decoded answers, per key and per id, for the packed table they came from: dropped whole when
-- that table changes (a reset, a spec's own). Weak valued, with EMPTY standing for "nothing", so a
-- quest asked twice is split once while it is held.
local cacheFrom, caches = nil, {}
-- Brief RF375 (the owner's ruling "A" on the review's M2): the reverse of the chain's previous lists,
-- { [questId] = { the quests that name it as their previous one } }, built once per packed table on the
-- first ask (one pass over the chain entries, about 300) and dropped with the table or by Reset.
local followedFrom, followedIndex = nil, nil

local function cacheFor(source, key)
  if cacheFrom ~= source then
    cacheFrom, caches = source, {}
  end
  local held = caches[key]
  if not held then
    held = setmetatable({}, { __mode = "v" })
    caches[key] = held
  end
  return held
end

-- One key's decoded answer for one id through decode(text), or nil where the key or the id is
-- absent. The decoded table is the cache's own and must not be modified.
local function decoded(key, id, decode, load)
  local source = packed(load)
  local entries = source and source[key]
  if type(entries) ~= "table" or id == nil then
    return nil
  end
  local cache = cacheFor(source, key)
  local held = cache[id]
  if held ~= nil then
    return held ~= EMPTY and held or nil
  end
  local text = entries[id]
  local value = type(text) == "string" and decode(text) or nil
  cache[id] = value or EMPTY
  return value
end

local function listOf(text)
  return QuestsPredicted.Numbers(text)
end

local function pairOf(text)
  local first, second = QuestsPredicted.Pair(text)
  return { first, second }
end

--- Drops every decoded answer (a spec, a data reset).
function QuestsPredicted.Reset()
  cacheFrom, caches = nil, {}
  followedFrom, followedIndex = nil, nil
end

--- Whether the predicted facts are there at all. load as the readers take it.
function QuestsPredicted.Available(load)
  return packed(load) ~= nil
end

--- One quest's facts ({ level, requiredLevel, side, uiMap, money, xp }, each nil where unknown), or
--- nil.
function QuestsPredicted.Facts(questId, load)
  return decoded("facts", positiveId(questId), QuestsPredicted.FactsOf, load)
end

--- One quest's reward and choice lists, each a list (the second empty where there is none), or nil.
function QuestsPredicted.Rewards(questId, load)
  local pair = decoded("rewards", positiveId(questId), pairOf, load)
  if not pair then
    return nil
  end
  return pair[1], pair[2]
end

--- The quests that hand one item over, as a list (empty for none).
function QuestsPredicted.RewardOf(itemId, load)
  return decoded("rewardOf", positiveId(itemId), listOf, load) or EMPTY
end

--- One quest's currency rewards, { { id, amount }, ... } (empty for none).
function QuestsPredicted.Currency(questId, load)
  return decoded("currency", positiveId(questId), QuestsPredicted.CurrencyOf, load) or EMPTY
end

--- One quest's title, or nil.
function QuestsPredicted.Title(questId, load)
  local source = packed(load)
  local titles = source and source.titles
  local id = positiveId(questId)
  local title = type(titles) == "table" and id and titles[id] or nil
  if type(title) == "string" and title ~= "" then
    return title
  end
  return nil
end

--- Every title, { [questId] = title }, the module's own table (never modified), or an empty table.
function QuestsPredicted.Titles(load)
  local source = packed(load ~= false)
  local titles = source and source.titles
  return type(titles) == "table" and titles or EMPTY
end

--- Who gives one quest and who takes it back, each a list of ids, a creature positive and an object
--- negative (empty for none).
function QuestsPredicted.Givers(questId, load)
  return decoded("giver", positiveId(questId), listOf, load) or EMPTY
end

function QuestsPredicted.Enders(questId, load)
  return decoded("ender", positiveId(questId), listOf, load) or EMPTY
end

--- The quests one creature starts, and the ones it ends (empty for none).
function QuestsPredicted.Starts(creatureId, load)
  return decoded("starts", positiveId(creatureId), listOf, load) or EMPTY
end

function QuestsPredicted.Ends(creatureId, load)
  return decoded("ends", positiveId(creatureId), listOf, load) or EMPTY
end

--- The approximate cells of one giver or turn in, by its signed id, { { map, cell }, ... } (empty).
function QuestsPredicted.Pins(signedId, load)
  local id = tonumber(signedId)
  if not id or id == 0 or id ~= math.floor(id) then
    return EMPTY
  end
  return decoded("pins", id, QuestsPredicted.PinsOf, load) or EMPTY
end

--- One quest's previous and next quests, two lists (each empty for none), or nil.
function QuestsPredicted.Chain(questId, load)
  local pair = decoded("chain", positiveId(questId), pairOf, load)
  if not pair then
    return nil
  end
  return pair[1], pair[2]
end

--- Brief RF375: the quests whose chain names this one among their previous quests, a list (empty for
--- none): a later step of its chain the quest's own entry may not name (a Classic quest a Forever
--- quest's page names as its predecessor). load as the other readers take it.
function QuestsPredicted.FollowedBy(questId, load)
  local id = positiveId(questId)
  local source = packed(load)
  local entries = source and source.chain
  if id == nil or type(entries) ~= "table" then
    return EMPTY
  end
  if followedFrom ~= source then
    local index = {}
    for laterId, text in pairs(entries) do
      local later = positiveId(laterId)
      if later and type(text) == "string" then
        local previous = QuestsPredicted.Pair(text)
        for _, earlier in ipairs(type(previous) == "table" and previous or EMPTY) do
          local earlierId = positiveId(earlier)
          if earlierId and earlierId ~= later then
            index[earlierId] = index[earlierId] or {}
            table.insert(index[earlierId], later)
          end
        end
      end
    end
    for _, list in pairs(index) do
      table.sort(list)
    end
    followedFrom, followedIndex = source, index
  end
  return followedIndex[id] or EMPTY
end

--- One quest's objectives, { { kind, id, count }, ... } (empty for none).
function QuestsPredicted.Objectives(questId, load)
  return decoded("objectives", positiveId(questId), QuestsPredicted.ObjectivesOf, load) or EMPTY
end

--- Brief PV1: the items one quest hands the player at accept, { { id, count }, ... } (empty for none).
function QuestsPredicted.Provided(questId, load)
  return decoded("provided", positiveId(questId), QuestsPredicted.ProvidedOf, load) or EMPTY
end

--- Brief PV1: the quests that hand one item over at accept, a list of quest ids (empty for none).
function QuestsPredicted.ProvidedBy(itemId, load)
  return decoded("providedBy", positiveId(itemId), listOf, load) or EMPTY
end

-- The item objectives read the other way: { [itemId] = { { quest, count }, ... } }, built once per
-- packed table on the first item asked (one pass over the objectives entries, a few hundred strings).
local objectiveIndexFrom, objectiveIndex = nil, nil

--- The quests whose objectives ask for one item, { { quest, count }, ... } (empty for none).
function QuestsPredicted.ObjectiveOf(itemId, load)
  local id = positiveId(itemId)
  local source = id and packed(load) or nil
  local entries = source and source.objectives
  if type(entries) ~= "table" then
    return EMPTY
  end
  if objectiveIndexFrom ~= source or not objectiveIndex then
    local index = {}
    for questId, text in pairs(entries) do
      if positiveId(questId) and type(text) == "string" then
        for _, objective in ipairs(QuestsPredicted.ObjectivesOf(text)) do
          if objective.kind == QuestsPredicted.ITEM then
            local list = index[objective.id]
            if not list then
              list = {}
              index[objective.id] = list
            end
            list[#list + 1] = { quest = questId, count = objective.count }
          end
        end
      end
    end
    for _, list in pairs(index) do
      table.sort(list, function(a, b)
        return a.quest < b.quest
      end)
    end
    objectiveIndexFrom, objectiveIndex = source, index
  end
  return objectiveIndex[id] or EMPTY
end

--- One quest's whole record, or nil where the module states nothing about it:
---   { questId, title, level, requiredLevel, side, uiMap, money, xp, rewards = { ids },
---     choices = { ids }, currency = { { id, amount } }, givers = { signed ids },
---     enders = { signed ids }, previous = { questIds }, next = { questIds },
---     objectives = { { kind, id, count } }, provided = { { id, count } } }
--- Every list is present (empty where nothing is stated). The lists are the caches' own and must
--- not be modified. load defaults to true: a page asks for this.
function QuestsPredicted.Quest(questId, load)
  local id = positiveId(questId)
  if not id then
    return nil
  end
  if load == nil then
    load = true
  end
  if not packed(load) then
    return nil
  end
  local record = { questId = id }
  local any = false
  local facts = QuestsPredicted.Facts(id, load)
  for _, field in ipairs(QuestsPredicted.FACT_FIELDS) do
    if facts and facts[field] ~= nil then
      record[field] = facts[field]
      any = true
    end
  end
  record.title = QuestsPredicted.Title(id, load)
  local rewards, choices = QuestsPredicted.Rewards(id, load)
  record.rewards, record.choices = rewards or EMPTY, choices or EMPTY
  record.currency = QuestsPredicted.Currency(id, load)
  record.givers = QuestsPredicted.Givers(id, load)
  record.enders = QuestsPredicted.Enders(id, load)
  local previous, following = QuestsPredicted.Chain(id, load)
  record.previous, record.next = previous or EMPTY, following or EMPTY
  record.objectives = QuestsPredicted.Objectives(id, load)
  record.provided = QuestsPredicted.Provided(id, load)
  any = any
    or record.title ~= nil
    or #record.rewards > 0
    or #record.choices > 0
    or #record.currency > 0
    or #record.givers > 0
    or #record.enders > 0
    or #record.previous > 0
    or #record.next > 0
    or #record.objectives > 0
    or #record.provided > 0
  if not any then
    return nil
  end
  return record
end

--------------------------------------------------------------------------------
-- Keys and names
--------------------------------------------------------------------------------

-- The Classic Era table, or nil. Only a page asks for a key (Core/ViewModel.lua QuestPredicted), and
-- the quest page builds the table anyway for Classic Era's givers.
local function eraTable()
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.Table) ~= "function" then
    return nil
  end
  local ok, source = pcall(era.Table, era)
  if ok and type(source) == "table" then
    return source
  end
  return nil
end

--- The page key a creature id opens: the Forever page (npc:<id>) where the Creatures data or the
--- player's own sightings know the creature, else its Classic Era page where the table names it
--- (npc:-<id>, or npc:<id> for a merged name), else npc:<id>. Never nil for a positive id.
function QuestsPredicted.CreatureKey(creatureId)
  local id = positiveId(creatureId)
  if not id then
    return nil
  end
  local plain = "npc:" .. tostring(id)
  local creatures = ItemTree.Creatures
  if type(creatures) == "table" and type(creatures.Get) == "function" then
    local ok, row = pcall(creatures.Get, id)
    if ok and type(row) == "table" then
      return plain
    end
  end
  local lookup = ItemTree.CreatureLookup
  if type(lookup) == "table" and type(lookup.Sighting) == "function" then
    local ok, record = pcall(lookup.Sighting, id)
    if ok and type(record) == "table" then
      return plain
    end
  end
  local module = ItemTree.EraSources
  local source = eraTable()
  if source and type(module) == "table" and type(module.CreatureNameIndex) == "function" then
    local ok, nameIndex = pcall(module.CreatureNameIndex, source, id)
    if ok and type(nameIndex) == "number" and type(module.PageKey) == "function" then
      local okKey, key = pcall(module.PageKey, source, nameIndex)
      if okKey and type(key) == "string" then
        return key
      end
    end
  end
  return plain
end

-- Brief AQF1: whether the name a record of ours holds for an object is the name the Classic Era table
-- states at one string index. true where the caller holds no name.
local function sameObjectName(nameIndex, name)
  if type(name) ~= "string" or name == "" then
    return true
  end
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.NameAt) ~= "function" then
    return true
  end
  local ok, stated = pcall(era.NameAt, era, nameIndex)
  return ok and type(stated) == "string" and stated:lower() == name:lower()
end

--- The page key an object id opens: its Classic Era page (object:-<id>) where the table names the
--- object, else object:<id>. Never nil for a positive id. Brief AQF1: name, where the caller holds the
--- object's own name (a record of ours, brief QH1), must be the name the table states for that id: a
--- Forever object id the table keys for ANOTHER object (1735, Classic Era's "Iron Deposit", recorded as
--- a "Wanted Poster") is the Forever object's own key, object:<id>, never the other object's page.
function QuestsPredicted.ObjectKey(objectId, name)
  local id = positiveId(objectId)
  if not id then
    return nil
  end
  local module = ItemTree.EraSources
  local source = eraTable()
  if source and type(module) == "table" and type(module.ObjectNameIndex) == "function" then
    local ok, nameIndex = pcall(module.ObjectNameIndex, source, id)
    if
      ok
      and type(nameIndex) == "number"
      and type(module.ObjectPageKey) == "function"
      and sameObjectName(nameIndex, name)
    then
      local okKey, key = pcall(module.ObjectPageKey, id)
      if okKey and type(key) == "string" then
        return key
      end
    end
  end
  return "object:" .. tostring(id)
end

--- The page key one signed giver or turn in id opens: a creature's for a positive id, an object's for
--- a negative one. nil for 0 or anything that is not a whole number.
function QuestsPredicted.KeyOf(signedId)
  local id = tonumber(signedId)
  if not id or id == 0 or id ~= math.floor(id) then
    return nil
  end
  if id > 0 then
    return QuestsPredicted.CreatureKey(id)
  end
  return QuestsPredicted.ObjectKey(-id)
end

--- The creature id an npc key stands for: a Forever page's own id (npc:<id>), or a Classic Era page's
--- creature id (npc:-<id>, Core/EraSources.lua PageId). nil for anything else.
function QuestsPredicted.CreatureIdOfKey(key)
  if type(key) ~= "string" then
    return nil
  end
  local positive = positiveId(key:match("^npc:(%d+)$"))
  if positive then
    return positive
  end
  local module = ItemTree.EraSources
  if type(module) == "table" and type(module.PageId) == "function" then
    local ok, id = pcall(module.PageId, key)
    if ok then
      return positiveId(id)
    end
  end
  return nil
end

--- How many quests one npc key starts and ends here, never loading the module (0 where it is not
--- loaded, or states none).
function QuestsPredicted.NpcQuestCount(key)
  local id = QuestsPredicted.CreatureIdOfKey(key)
  if not id then
    return 0
  end
  return #QuestsPredicted.Starts(id, false) + #QuestsPredicted.Ends(id, false)
end

--- The approximate pins of one npc key's creature, as QuestsPredicted.PinsAt draws them, never
--- loading the module (an empty list where it is not loaded or places it nowhere).
function QuestsPredicted.NpcPins(key, zoneOf, name)
  local id = QuestsPredicted.CreatureIdOfKey(key)
  if not id then
    return {}
  end
  return QuestsPredicted.PinsAt(QuestsPredicted.Pins(id, false), name, zoneOf)
end

--------------------------------------------------------------------------------
-- The graph provider and the namer
--------------------------------------------------------------------------------

-- The provenance the edges carry: none. A Predicted fact names no source; its mark says what it is.

local function graphParts()
  local Graph, Edges, Confidence = ItemTree.Graph, ItemTree.Edges, ItemTree.Confidence
  if type(Graph) ~= "table" or type(Edges) ~= "table" or type(Confidence) ~= "table" then
    return nil
  end
  return Graph, Edges, Confidence
end

-- Whether one item is in a quest's choice list.
local function isChoice(questId, itemId)
  local _, choices = QuestsPredicted.Rewards(questId, false)
  for _, value in ipairs(choices or EMPTY) do
    if value == itemId then
      return true
    end
  end
  return false
end

--- The provider's edges for one key, Predicted every one (see the header). Never loads the module.
function QuestsPredicted.EdgesFor(key, direction)
  local out = {}
  local Graph, Edges, Confidence = graphParts()
  if not Graph or not packed(false) then
    return out
  end
  local T = Edges.Types
  local kind, id = Graph.Parse(key)
  if kind == "item" and direction == Edges.UP then
    for _, questId in ipairs(QuestsPredicted.RewardOf(id, false)) do
      if positiveId(questId) then
        out[#out + 1] = {
          type = T.QUEST_REWARD,
          target = Graph.Key("quest", questId),
          confidence = Confidence.PREDICTED,
          group = L["Quests"],
          choice = isChoice(questId, id) or nil,
        }
      end
    end
    -- Brief PV1 (the owner's QA item 375): the quests that hand the item over at accept, the Sources
    -- tab's "Provided by quest" rows (Core/Edges.lua QUEST_PROVIDED, the Quest type column), one row
    -- per quest: a quest the reward rows above already name is not named twice. A recorded hand over
    -- of the same quest (brief QH1, the player module's provider) outranks this one in the graph's
    -- merge (same type and target), so a record of ours always wins the row.
    local rewarded = {}
    for _, edge in ipairs(out) do
      rewarded[edge.target] = true
    end
    for _, questId in ipairs(QuestsPredicted.ProvidedBy(id, false)) do
      local target = positiveId(questId) and Graph.Key("quest", questId) or nil
      if target and not rewarded[target] then
        rewarded[target] = true
        out[#out + 1] = {
          type = T.QUEST_PROVIDED,
          target = target,
          confidence = Confidence.PREDICTED,
          group = L["Quests"],
        }
      end
    end
  elseif kind == "item" and direction == Edges.DOWN then
    for _, need in ipairs(QuestsPredicted.ObjectiveOf(id, false)) do
      out[#out + 1] = {
        type = T.QUEST_OBJECTIVE,
        target = Graph.Key("quest", need.quest),
        confidence = Confidence.PREDICTED,
        group = L["Quests"],
        quantity = need.count,
        -- Brief GF6: the marker Core/Keep.lua counts these, and only these, Predicted edges by.
        [QuestsPredicted.OBJECTIVE_MARK] = true,
      }
    end
  elseif kind == "npc" and direction == Edges.DOWN then
    local creatureId = QuestsPredicted.CreatureIdOfKey(key)
    if creatureId then
      for _, side in ipairs({
        { QuestsPredicted.Starts(creatureId, false), T.GIVES_QUEST, L["Starts"] },
        { QuestsPredicted.Ends(creatureId, false), T.TAKES_QUEST, L["Ends"] },
      }) do
        for _, questId in ipairs(side[1]) do
          if positiveId(questId) then
            out[#out + 1] = {
              type = side[2],
              target = Graph.Key("quest", questId),
              confidence = Confidence.PREDICTED,
              group = side[3],
            }
          end
        end
      end
    end
  end
  return out
end

--- A quest's predicted title, for Graph.RegisterNamer: asked only for a key nothing else names. The
--- client's own title wins where it gives one (Core/QuestFlags.lua ClientTitle). Never loads the
--- module.
function QuestsPredicted.Namer(key)
  local Graph = graphParts()
  if not Graph then
    return nil
  end
  local kind, id = Graph.Parse(key)
  if kind ~= "quest" then
    return nil
  end
  local title = QuestsPredicted.Title(id, false)
  if not title then
    return nil
  end
  local flags = ItemTree.QuestFlags
  if type(flags) == "table" and type(flags.ClientTitle) == "function" then
    local ok, client = pcall(flags.ClientTitle, id)
    if ok and type(client) == "string" and client ~= "" then
      return client
    end
  end
  return title
end

--- The same, asked FIRST of all the namers, and only for a quest Classic Era never knew
--- (Core/QuestFlags.lua IsNew, one binary search over the core Diff module): no namer of ours can
--- name such a quest from a table (the Classic Era namer would build its whole quest index, about
--- 20 ms, to find nothing), and a title ours states is on the graph already (Graph.names, asked
--- before any namer). Every other quest is left to QuestsPredicted.Namer, after every other namer.
function QuestsPredicted.FirstNamer(key)
  local flags = ItemTree.QuestFlags
  if type(key) ~= "string" or key:sub(1, 6) ~= "quest:" then
    return nil
  end
  if type(flags) ~= "table" or type(flags.IsNew) ~= "function" then
    return nil
  end
  local ok, new = pcall(flags.IsNew, key:sub(7))
  if not ok or new ~= true then
    return nil
  end
  return QuestsPredicted.Namer(key)
end

--- Registers the provider (Predicted only, so Graph.Summary never asks it: its quests reach the counts
--- through the readers above, brief RB1) and the two namers:
--- FirstNamer ahead of every other, Namer after every other, so a title of ours always wins. Safe
--- to call twice.
function QuestsPredicted.Install()
  local Graph = ItemTree.Graph
  if type(Graph) ~= "table" or type(Graph.RegisterProvider) ~= "function" then
    return false
  end
  if not Graph.HasProvider(QuestsPredicted.EdgesFor) then
    Graph.RegisterProvider(QuestsPredicted.EdgesFor, { predictedOnly = true })
  end
  if type(Graph.RegisterNamer) == "function" and type(Graph.HasNamer) == "function" then
    if not Graph.HasNamer(QuestsPredicted.FirstNamer) then
      Graph.RegisterNamer(QuestsPredicted.FirstNamer, true)
    end
    if not Graph.HasNamer(QuestsPredicted.Namer) then
      Graph.RegisterNamer(QuestsPredicted.Namer)
    end
  end
  return true
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

-- Nothing here calls the client: the namer asks Core/QuestFlags.lua ClientTitle, which is guarded
-- there, and a map's name is asked of Core/Collector.lua MapName by the page that draws it.

QuestsPredicted.Install()

return QuestsPredicted
