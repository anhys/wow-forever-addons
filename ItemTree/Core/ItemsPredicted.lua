-- Brief IC1: the predicted item sources (ItemTree-Data, the "Item claims" section of its page docs; the ItemsPredicted
-- module). Pure Lua, no WoW API.
--
-- The load on demand module ItemsPredicted (ItemTree_Data, all rights reserved) holds the sources of an
-- item that no table of ours states a source of that kind for: the creatures that drop it, the vendors
-- that sell it, what it is found in, the quests that hand it over as a reward and (the owner's ruling
-- "2B" of 2026-10-23) when taken, and the spells that make it. Each is shown with the Predicted mark,
-- under the Sources tab's existing words, below every fact of ours. Beside them (the owner's ruling
-- "3B") the "sold everywhere" vendor count where the Forever vendors the player records and the item
-- claims add stand widely spread. Every entry is ONE packed string of whole numbers, "," between them:
--
--   drops       { [itemId] = "npcIds" }
--   vendors     { [itemId] = "npcIds" }
--   vendorStock { [itemId] = "npcId,stock,..." }, pairs: the limited stock of a vendor in vendors
--   containers  { [itemId] = "ids" }, an item id positive, an object id negative
--   rewardOf    { [itemId] = "questIds" }
--   providedBy  { [itemId] = "questIds" }, the quests that hand it over when taken
--   createdBy   { [itemId] = "spellIds" }, the spells that make it
--   soldWide    { [itemId] = "count" }, how many vendors sell it (five zones or more, both sides)
--
-- Brief LS1 (review ORDR2 M2, the owner's "Bring the rows back"): a vendor that sells the item only a few at
-- a time ships in vendors like any other, and its stock beside it in vendorStock, a key of its own, so a reader
-- that knows nothing of it (0.1.17's) reads vendors unchanged. Its Sold by edge carries stock and the note a
-- Classic Era limited stock edge carries (Core/EraSources.lua, Sources.LimitedStock); the graph's merge keeps
-- the note for both (Core/Graph.lua EDGE_FIELDS), so the Sources tab reads "Vizzklick (limited stock 1)" and
-- the row's hover says "limited stock 1", never a steady sale. Keep reads no predicted vendor row (its vendor
-- count is the tables' and soldWide, which leaves a limited stock sale out).
--
-- No rate and no price ships (the owner's ruling of 2026-10-02: sources only). The reader splits one
-- entry the first time something asks for it and keeps the answer in a weak cache per key, so the
-- module's first build makes no table per item. A build with no module answers "no data": an empty
-- list, never an error.
--
-- What reads it:
--   ItemsPredicted.EdgesFor(key, dir)   the graph provider, Predicted edges alone, item:<id> up:
--     DROPPED_BY "Drops from", SOLD_BY "Sold by", CONTAINED_IN "Contained in" (an item),
--     LOOTED_FROM "Found in" (an object), QUEST_REWARD "Quests", QUEST_PROVIDED "Quests" (its type
--     column "Provided by quest"), PRODUCED_BY "Produced by" (a spell)
--   ItemsPredicted.RewardQuests(itemId)  the quests that hand the item over, for Graph.Summary's count
--                                        (Graph.PredictedRewardQuests), never loading the module
--   ItemsPredicted.ProvidedBy(itemId)    ruling "2B": the quests that hand it over when taken, for
--                                        Graph.PredictedProvidedQuests and Keep.ProvidedQuests (a
--                                        provided item counts only while its quest is in the log)
--   ItemsPredicted.SoldWide(itemId)      ruling "3B": the sold everywhere count, for Keep.VendorCount
--   ItemsPredicted.VendorStock(itemId)   brief LS1: npcId -> the limited stock of a vendor in Vendors
--
-- The provider is registered as Predicted only, so a tooltip or a bag pass never asks it and never loads
-- ItemTree_Data for it; a guess (Core/GuessSources.lua) beside one of its rows is shadowed by the graph's
-- own rules (Graph.DropGuessEdges), as beside any real row, and goes with it when Predicted data is off.
-- Keep and Jettison count these sources as they count the player records' (the owner's standing rule
-- of 2026-10-17, "Predicted IS our data"): a quest that hands the item over counts on the item page's
-- line as any quest the item comes from; Keep's vendor count is the larger of the client's, the Classic
-- Era vendor lists' and soldWide (ItemTree-Data item_claims.sold_wide: the player records' and the item
-- claims' vendors joined to the client's only where they stand in five zones or more and serve both
-- sides, unless the item is one side's), the count Jettison's facts carry as vc, so both addons agree.
local _, ItemTree = ...

local ItemsPredicted = {}
ItemTree.ItemsPredicted = ItemsPredicted

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

ItemsPredicted.MODULE = "ItemsPredicted"

-- A shared empty answer. Never modified.
local EMPTY = {}

local function positiveId(value)
  local id = tonumber(value)
  if not id or id <= 0 or id ~= math.floor(id) then
    return nil
  end
  return id
end

--- The whole numbers in one packed list ("12,-4002"), in order, or an empty list. Pure.
function ItemsPredicted.Numbers(text)
  local out = {}
  if type(text) ~= "string" then
    return out
  end
  for number in text:gmatch("-?%d+") do
    out[#out + 1] = tonumber(number)
  end
  return out
end

-- The positive ids of a packed list (a creature, a vendor or a quest), repeats dropped. Pure.
local function positiveIds(text)
  local out, seen = {}, {}
  for _, value in ipairs(ItemsPredicted.Numbers(text)) do
    local id = positiveId(value)
    if id and not seen[id] then
      seen[id] = true
      out[#out + 1] = id
    end
  end
  return out
end

-- Brief LS1: a vendorStock entry ("npcId,stock,...") as npcId -> stock, each a positive whole number; a pair
-- that is not, and a repeat of a vendor, left out. Pure.
local function stockPairs(text)
  local out = {}
  local numbers = ItemsPredicted.Numbers(text)
  for at = 1, #numbers - 1, 2 do
    local npcId, stock = positiveId(numbers[at]), positiveId(numbers[at + 1])
    if npcId and stock and out[npcId] == nil then
      out[npcId] = stock
    end
  end
  return out
end

-- The signed ids of a containers list (an item positive, an object negative), 0 left out. Pure.
local function signedIds(text)
  local out, seen = {}, {}
  for _, value in ipairs(ItemsPredicted.Numbers(text)) do
    if value ~= 0 and value == math.floor(value) and not seen[value] then
      seen[value] = true
      out[#out + 1] = value
    end
  end
  return out
end

--------------------------------------------------------------------------------
-- The module and the per key caches
--------------------------------------------------------------------------------

-- A table a spec hands in place of the module (the packed shape). Never set in the client.
ItemsPredicted.source = nil

-- The packed table, or nil. load says whether asking may load ItemTree_Data: a page may, the provider
-- and the counts may not, so they answer only once the module is registered.
local function packed(load)
  if type(ItemsPredicted.source) == "table" then
    return ItemsPredicted.source
  end
  local Data = ItemTree.Data
  if type(Data) ~= "table" or type(Data.Get) ~= "function" then
    return nil
  end
  if not load and type(Data.Has) == "function" and not Data:Has(ItemsPredicted.MODULE) then
    return nil
  end
  local ok, value = pcall(Data.Get, Data, ItemsPredicted.MODULE)
  if ok and type(value) == "table" then
    return value
  end
  return nil
end

local cacheFrom, caches = nil, {}

local function decoded(key, id, decode, load)
  local source = packed(load)
  local entries = source and source[key]
  if type(entries) ~= "table" or id == nil then
    return nil
  end
  if cacheFrom ~= source then
    cacheFrom, caches = source, {}
  end
  local cache = caches[key]
  if not cache then
    cache = setmetatable({}, { __mode = "v" })
    caches[key] = cache
  end
  local held = cache[id]
  if held ~= nil then
    return held ~= EMPTY and held or nil
  end
  local text = entries[id]
  local value = type(text) == "string" and decode(text) or nil
  cache[id] = value or EMPTY
  return value
end

--- Drops every decoded answer (a spec, a data reset).
function ItemsPredicted.Reset()
  cacheFrom, caches = nil, {}
end

--- Whether the predicted item sources are there at all. load as the readers take it.
function ItemsPredicted.Available(load)
  return packed(load) ~= nil
end

--- The creatures that drop one item, a list of npc ids (empty for none).
function ItemsPredicted.Drops(itemId, load)
  return decoded("drops", positiveId(itemId), positiveIds, load) or EMPTY
end

--- The vendors that sell one item, a list of npc ids (empty for none).
function ItemsPredicted.Vendors(itemId, load)
  return decoded("vendors", positiveId(itemId), positiveIds, load) or EMPTY
end

--- Brief LS1: the limited stock of each vendor in Vendors(itemId) that sells the item only a few at a time,
--- { [npcId] = stock } (empty for none: every vendor of it sells it steadily).
function ItemsPredicted.VendorStock(itemId, load)
  return decoded("vendorStock", positiveId(itemId), stockPairs, load) or EMPTY
end

--- What one item is found in, a list of signed ids: an item positive, an object negative (empty for none).
function ItemsPredicted.Containers(itemId, load)
  return decoded("containers", positiveId(itemId), signedIds, load) or EMPTY
end

--- The quests that hand one item over, a list of quest ids (empty for none).
function ItemsPredicted.RewardOf(itemId, load)
  return decoded("rewardOf", positiveId(itemId), positiveIds, load) or EMPTY
end

--- The quests that hand one item over, for Graph.Summary's count: never loads the module (nothing
--- until it is registered, as the provider). A fresh list, quest id order as shipped.
function ItemsPredicted.RewardQuests(itemId)
  local out = {}
  for _, questId in ipairs(ItemsPredicted.RewardOf(itemId, false)) do
    out[#out + 1] = questId
  end
  return out
end

--- The owner's ruling "2B" of 2026-10-23: the quests that hand one item over when taken, a list of quest
--- ids (empty for none).
function ItemsPredicted.ProvidedBy(itemId, load)
  return decoded("providedBy", positiveId(itemId), positiveIds, load) or EMPTY
end

--- Ruling "2B": the spells that make one item, a list of spell ids (empty for none).
function ItemsPredicted.CreatedBy(itemId, load)
  return decoded("createdBy", positiveId(itemId), positiveIds, load) or EMPTY
end

--- The owner's ruling "3B" of 2026-10-23: how many vendors sell one item where the Forever vendors stand
--- widely spread, 0 where the module states none. Never loads the module (Keep.VendorCount asks it for
--- every scored item).
function ItemsPredicted.SoldWide(itemId)
  local list = decoded("soldWide", positiveId(itemId), positiveIds, false)
  return list and list[1] or 0
end

--------------------------------------------------------------------------------
-- The graph provider
--------------------------------------------------------------------------------

-- The page key a creature id opens: Core/QuestsPredicted.lua's rule (the Forever page where the Creatures
-- data or the player's sightings know it, else its Classic Era page where the table names it), else
-- npc:<id>.
local function creatureKey(npcId)
  local predicted = ItemTree.QuestsPredicted
  if type(predicted) == "table" and type(predicted.CreatureKey) == "function" then
    local ok, key = pcall(predicted.CreatureKey, npcId)
    if ok and type(key) == "string" then
      return key
    end
  end
  return "npc:" .. tostring(npcId)
end

-- The page key an object id opens: its Classic Era page where the table names it, else object:<id>.
local function objectKey(objectId)
  local predicted = ItemTree.QuestsPredicted
  if type(predicted) == "table" and type(predicted.ObjectKey) == "function" then
    local ok, key = pcall(predicted.ObjectKey, objectId)
    if ok and type(key) == "string" then
      return key
    end
  end
  return "object:" .. tostring(objectId)
end

-- Brief LS1: the words a limited stock row ends with, "limited stock 1", from Core/Sources.lua as the Classic
-- Era rows take them (Core/EraSources.lua phrase), read at call time; nil where Sources is absent.
local function limitedStockNote(stock)
  local Sources = ItemTree.Sources
  if type(Sources) ~= "table" or type(Sources.LimitedStock) ~= "function" then
    return nil
  end
  local ok, note = pcall(Sources.LimitedStock, stock)
  if ok and type(note) == "string" and note ~= "" then
    return note
  end
  return nil
end

local function graphParts()
  local Graph, Edges, Confidence = ItemTree.Graph, ItemTree.Edges, ItemTree.Confidence
  if type(Graph) ~= "table" or type(Edges) ~= "table" or type(Confidence) ~= "table" then
    return nil
  end
  return Graph, Edges, Confidence
end

--- The provider's edges for one key, Predicted every one: an item's sources, up. Never loads the module.
function ItemsPredicted.EdgesFor(key, direction)
  local out = {}
  local Graph, Edges, Confidence = graphParts()
  if not Graph or direction ~= Edges.UP or not packed(false) then
    return out
  end
  local kind, id = Graph.Parse(key)
  if kind ~= "item" then
    return out
  end
  local T = Edges.Types
  local function add(edgeType, target, group)
    local edge = { type = edgeType, target = target, confidence = Confidence.PREDICTED, group = group }
    out[#out + 1] = edge
    return edge
  end
  for _, npcId in ipairs(ItemsPredicted.Drops(id, false)) do
    add(T.DROPPED_BY, creatureKey(npcId), L["Drops from"])
  end
  -- Brief LS1: a vendor that sells it only a few at a time carries its stock and the note a Classic Era
  -- limited stock row carries, so its row reads "Vizzklick (limited stock 1)" (Sources.Row, Sources.Qualified).
  local stocks = ItemsPredicted.VendorStock(id, false)
  for _, npcId in ipairs(ItemsPredicted.Vendors(id, false)) do
    local edge = add(T.SOLD_BY, creatureKey(npcId), L["Sold by"])
    local stock = stocks[npcId]
    if stock then
      edge.stock = stock
      edge.note = limitedStockNote(stock)
    end
  end
  for _, signed in ipairs(ItemsPredicted.Containers(id, false)) do
    if signed > 0 then
      add(T.CONTAINED_IN, Graph.Key("item", signed), L["Contained in"])
    else
      add(T.LOOTED_FROM, objectKey(-signed), L["Found in"])
    end
  end
  local rewarded = {}
  for _, questId in ipairs(ItemsPredicted.RewardOf(id, false)) do
    rewarded[questId] = true
    add(T.QUEST_REWARD, Graph.Key("quest", questId), L["Quests"])
  end
  -- Ruling "2B": the quests that hand the item over when taken, the Sources tab's "Provided by quest"
  -- rows (QUEST_PROVIDED, the Quest type column) under Quests, as Core/QuestsPredicted.lua draws its
  -- own: a quest a reward row above names already is not named twice, and a record of ours of the same
  -- quest outranks the row in the graph's merge (same type and target).
  for _, questId in ipairs(ItemsPredicted.ProvidedBy(id, false)) do
    if not rewarded[questId] then
      rewarded[questId] = true
      add(T.QUEST_PROVIDED, Graph.Key("quest", questId), L["Quests"])
    end
  end
  -- Ruling "2B": the spells that make it, "Produced by" rows (PRODUCED_BY, the Recipe type column), the
  -- group a recipe of no profession takes (Core/Graph.lua recipeGroup's fallback).
  for _, spellId in ipairs(ItemsPredicted.CreatedBy(id, false)) do
    add(T.PRODUCED_BY, Graph.Key("spell", spellId), L["Produced by"])
  end
  return out
end

--- Registers the provider, Predicted only (Graph.Summary never asks it; its quests reach the counts
--- through ItemsPredicted.RewardQuests). Safe to call twice.
function ItemsPredicted.Install()
  local Graph = ItemTree.Graph
  if type(Graph) ~= "table" or type(Graph.RegisterProvider) ~= "function" then
    return false
  end
  if not Graph.HasProvider(ItemsPredicted.EdgesFor) then
    Graph.RegisterProvider(ItemsPredicted.EdgesFor, { predictedOnly = true })
  end
  return true
end

ItemsPredicted.Install()

return ItemsPredicted
