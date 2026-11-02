-- ItemTreeAPI (brief IT1): a small read only public API, so another addon can ask what ItemTree
-- knows about one item. Owner ruling 2026-10-04 (R1): ItemTree is optional for Droplist, the first
-- consumer, but should make it richer. docs/public-api.md is the page for another addon's author.
-- Loaded as: local _, ItemTree = ...
--
-- The contract, version 1 (names and shapes are exact; another addon codes against them):
--   ItemTreeAPI.version                   1, bumped on any breaking change
--   ItemTreeAPI.IsReady()                 true when ItemTree_Data is loaded and the item tables are
--                                         there (Data:OnDemandLoaded, the test every surface uses)
--   ItemTreeAPI.RequestData()             loads ItemTree_Data through Data:LoadOnDemand, the loader
--                                         login uses; answers IsReady() afterwards; never raises
--   ItemTreeAPI.RegisterReadyCallback(fn) fn() once when the data becomes ready, at once when it
--                                         already is; the same fn twice runs once; a raise in fn is
--                                         caught and dropped
--   ItemTreeAPI.RegisterChangeCallback(fn) brief JET13, an addition: fn(what) on the frame after
--                                         ItemTree's answers may have changed with no bag change:
--                                         "demo" (the demo state changed) or "setting" (a saved
--                                         setting that changes answers, API.CHANGE_SETTINGS and the
--                                         gear spec rows; brief K14: the player's Keep word on one
--                                         item, Keep.SetOverride); one call per frame however many changes;
--                                         the same fn twice runs once; a raise in fn is dropped
--   ItemTreeAPI.GetItemFacts(itemId, link) the facts table below, or nil when not ready or the id
--                                         is not a positive integer
--   ItemTreeAPI.demo                      brief BQ13, an addition: the demo state, { on = false }
--                                         while off; while on also level, professions ({ { line,
--                                         rank } }, empty for none), specs, carefulAim, quests
--                                         ({ [questId] = { kind, have, need } }), questsNone and
--                                         have ({ [itemId] = count }); the same table, rewritten
--   facts = {
--     itemId, known,
--     keep    = { marked, valuable, never, always, off, line, lines, state,
--                 gear = { upgrade, basis, specs = { key, ... }, labels = { label, ... },
--                          carefulAim = rank or nil, off = true or nil } or nil },
--     uses    = { current, stale, kinds = { reagent, tool, teaches, lock, quest, spell },
--                 professions = { name, ... } },
--     quests  = { needs = { questId, ... }, starts = { questId, ... },
--                 staleAfter = { questId, ... }, staleAfterKind = 1 | 2 or nil, stale,
--                 titles = { [questId] = title }, counts = { [questId] = n }, keepUpTo,
--                 predicted = { [questId] = true } },
--     route   = { needed, profession } or nil,
--     vendors = { count, everywhere, buyPrice },
--     price   = { copper, source } or nil,
--   }
--
-- Brief IT2 added uses.professions and quests.staleAfter, staleAfterKind, stale and titles, all
-- additions, so the version stays 1:
--   uses.professions      the player's professions by name, sorted, from Keep.PlayerProfessions
--                         (the developer's pretend set included); empty when none or unknown
--   quests.staleAfter     the quests after whose completion the item has no use left, from the
--                         StaleAfter module (Data:StaleAfter); empty when none shipped
--   quests.staleAfterKind 1 a predicted claim, 2 one the owner verified; nil when staleAfter is empty
--   quests.stale          true when the player has completed at least one staleAfter quest
--                         (Keep.QuestCompleted, the check needs and starts make); else false
--   quests.titles         quest id to title for every id in needs, starts and staleAfter the data
--                         names (Era qt, PlayerSources, then Era's quest rows where already indexed)
--
-- Brief GF6 (the owner's ruling of 2026-10-14, "Turn it on") added quests.predicted, an addition too:
-- the needs (quest id to true) of a new Forever quest that rest on the predicted facts alone, counted
-- and judged as any other need (side, level, reach, count). An internal note: ItemTree's lines show no
-- mark for them (the owner's ruling of 2026-10-14, "Remove the predicted text").
--
-- Brief Q1 added quests.counts (quest id to how many of the item each need asks for) and
-- quests.keepUpTo (how many the keep holds where it rests on quest needs alone, nil otherwise),
-- additions too; needs and starts now leave out a quest the player cannot still do (the other
-- side), and a quest that never keeps an item (an event quest, a reputation turn in) is in neither.
-- Brief QS1 (the owner's ruling A of 2026-10-14): a quest of the other side is no use at all, so
-- uses.current and uses.stale never count it either (Keep.OtherSideQuest); the shape is unchanged.
-- Brief F155: that holds while the player's "Hide other faction data" setting is on (the default);
-- with it off such a quest is counted in uses.stale again, as before QS1.
-- Brief QS2b: a quest nothing sides that only the other side's players were seen taking (Diff.quests'
-- seenAlliance / seenHorde, Keep.SeenOtherSideQuest) is in neither needs, starts, uses.current nor
-- uses.stale, whatever the setting says; the shape is unchanged.
--
-- Brief K27 added keep.gear, an addition too, for a weapon or armour: upgrade (the gear test keeps
-- it, an upgrade for any spec of the player's class), basis (Gear.Compare's), specs (the spec keys
-- it upgrades, in the class's order, empty where the stats did not decide) and labels (each spec's
-- label, "Holy"), so another addon reads the same spec answer the tooltip words. Brief ST3 (QA item
-- 320, the owner's ruling A), still within version 1: with every spec unticked in ItemTree's settings
-- gear suggestions are off, and a weapon or armour piece answers keep.gear { upgrade = false, specs =
-- {}, labels = {}, off = true } (no basis): never an upgrade, so another addon's own item level
-- compare does not keep it in ItemTree's place.
--
-- Brief JI1 (the owner's ruling of 2026-10-09, "Use ItemTree's verdict") added keep.consumable, an
-- addition too, so Jettison judges a consumable as ItemTree does: { judged, keep, kind, why, words,
-- efficient, buffFood, xpFood, notFood } for a consumable ItemTree's consumable facts judge (or say is
-- no food), nil for anything else (API.ConsumableFacts).
--
-- Brief BQ9 added keep.action, an addition too: { kind = "open" | "use" | "quest", words } where
-- ItemTree says to open the item, use the buff now or start its quest (the [Open] and [Use]
-- verdicts), nil otherwise; such an item is never keep.marked or keep.byUse. Brief BQ25a added
-- keep.action.now: true for those; false for a usable consumable whose [Use] tag is its keep (the
-- buff on, a potion, a bandage: { kind = "use", words = its reason line, now = false }, marked as a
-- keep), which is never a prompt to use it now. Brief BQ29 (QA items 86 and 87): a buff food reads
-- now = true while the player is not well fed; an elixir or scroll with its buff on, and a buff food
-- while well fed, are [Keep] and keep.action { kind = "use", now = false }.
--
-- Brief BQ6 added keep.consumable.restore (the amount ItemTree compares it by, 0 for none) and
-- keep.consumable.outranked (a bandage kept while still relevant beside a better usable one carried),
-- additions too, so Jettison orders two kept bandages as ItemTree words them; and vendors.everywhere
-- is false for an item vendors sell mostly in limited stock (Keep.LimitedStock).
--
-- Brief GW1 (the owner's ruling, QA item 101 (a)) added keep.cosmetic, an addition too: { collected }
-- for a cosmetic piece (armour subclass 5), never judged as gear (keep.gear is nil for it): collected
-- true where the account has its appearance (its ordinary sale verdict, "Appearance collected"),
-- false or nil (not known) where not, when keep.action is { kind = "use", collect = true, now = true,
-- words = "Use it to collect the appearance" }, so Jettison's use now prompt follows it as it is.
--
-- Brief BQ23 added keep.camp, an addition too: true for a camp item (the item effects' kind 62, Camp
-- Chair and Camp Tent), nil otherwise.
--
-- Brief TOY2 added keep.toy, an addition too: true for a toy (Keep.IsToy: the client's Toy Box, or
-- the shipped toy list, which also names the toys the server alone knows, Night Watchman's Torch
-- 280612 among them), nil otherwise, so Jettison locks what ItemTree keeps as a toy.
--
-- Brief AM1 (the owner's QA item 330) added keep.ammo, an addition too: { weapon, required, words }
-- where ItemTree keeps the item as ammo the worn ranged weapon fires, in reach of the player's level
-- (Keep.AmmoFacts, Jettison's ammoForWorn rule): weapon the worn weapon's subclass (2 bow, 3 gun, 18
-- crossbow), required the ammo's required level (nil for none), words "Ammo for your bow"; keep.byUse
-- is true beside it. nil otherwise.
--
-- Brief BQ25c added keep.bag, an addition too: the bag rule's answer for a bag, quiver, ammo pouch,
-- soul or reagent bag against the player's equipped bags of its kind (Keep.BagFacts): { kind =
-- "normal" | "quiver" | "pouch" | "soul" | "reagent" | "profession", keep (true: a Keep; false: no
-- better, so its other verdict), words ("Bigger than your 6 slot bag", "Faster quiver than yours",
-- "No bigger than your 14 slot bag"), slots, against (the slots it was weighed against, 0 for an empty
-- slot, nil where it was not weighed), speed (a quiver's or pouch's ranged attack speed percent) },
-- nil for anything else or where the equipped bags are not known. Jettison reads the same words.
-- Brief BG1 (QA item 83 as the owner revised it on 2026-10-13) added, within keep.bag: spare = true
-- for a spare bag kept for the bank and alts (keep true, the [Keep] tag beside its sale verdict),
-- reason = "bankAlts" ("Useful for bank and alts"), "bank" ("Useful for your bank": bound),
-- "bankSlot" ("Fills an empty bank slot") or "bankBigger" ("Bigger than your bank bag"), and cap = {
-- kept, max, copies } wherever the spare rule weighed the bag: max the bank's bag slots with every
-- slot bought, kept the spare bags kept in all (carried and in the bank), copies how many copies of
-- this item are kept (0: beyond the cap, so keep false and its sale verdict). keep true with spare
-- nil is an upgrade, ItemTree's [Equip]. QA item 153 (the owner, 2026-10-14): a quiver or ammo pouch
-- is never a spare (spare and cap are never set for one); it keeps only as an upgrade on the worn
-- one, and later = N (an addition) marks an upgrade the character cannot wear until level N,
-- ItemTree's [Keep] until then rather than [Equip].
--
-- Brief BQ18 added keep.stock and uses.reagentSkills, additions too: keep.stock = { cap, uses = { {
-- skill, profession, item, name, useful, usefulName, kind } } } where ItemTree keeps a working stock of
-- a reagent off the levelling route (one stack, cap units; its profession's recipe makes item, which
-- is or leads to useful, kind "gear" or "consumable"), nil otherwise, so Jettison keeps the stacks
-- that cover the cap and ranks the rest on value; uses.reagentSkills, the skill lines of the
-- player's own professions whose current recipes use the item (empty for none or professions not
-- known), so Jettison never says "not your trade" of a reagent ItemTree counts as the player's.
--
-- Brief QX1 (the owner, 2026-10-22, "track quest items in your bags that are fully safe to throw away")
-- added keep.finished, an addition too: { complete = { questId, ... }, abandoned = { questId, ... },
-- titles = { [questId] = title } } for a quest bound or soulbound quest item whose quests of this
-- character are all completed, or abandoned where the owner's checks allow (Core/Keep.lua
-- Keep.QuestFinished): ItemTree's [Vendor] (with a sell price) or [Worthless] and the lines 'Quest
-- complete: "<title>"' and 'Quest abandoned: "<title>"' ("and N more" after the first title of a
-- kind). nil for anything else, a quest item something keeps included, so Jettison drops its quest
-- item lock only where ItemTree says so. Brief AQF1 (the owner's rulings of 2026-10-22): below = {
-- questId, ... }, the quests never taken that are grey for the player, a chain end and not in the log
-- ('Quest below your level: "<title>"', after the other two), and never for an epic or better quest item,
-- which reads the lines with no tag (ruling "B"), so Jettison keeps its quest item lock on it.
--
-- Every fact comes from ItemTree's own tables through Core/Keep.lua's public functions, the score
-- through Keep.CachedScore with the same player context the bag marks use, so the API shares their
-- cache and costs one table lookup per call once an item has been scored. Nothing here asks the
-- client about an item (no GetItemInfo, no RequestLoadItemDataByID, nothing like them), and
-- nothing here writes to any table but its own cache.
local _, ItemTree = ...

local API = {}
ItemTree.API = API

local EMPTY = {}

API.VERSION = 1

local function copyList(list)
  local out = {}
  for index, value in ipairs(list or EMPTY) do
    out[index] = value
  end
  return out
end

local function copyMap(map)
  local out = {}
  for key, value in pairs(map or EMPTY) do
    out[key] = value
  end
  return out
end

-- Brief RB2A (QA item 250): uses.reagentSkills, the score's trade lines (Keep's route count, a grey
-- gathering recipe among them) then its gathering lines not grey yet (score.gatherLines), once each:
-- every line of the player's own current recipe uses, as the list read before RB2A. A new list.
local function reagentLines(score)
  local out = copyList(type(score.tradeLines) == "table" and score.tradeLines or nil)
  for _, skill in ipairs(type(score.gatherLines) == "table" and score.gatherLines or EMPTY) do
    local held = false
    for _, listed in ipairs(out) do
      held = held or listed == skill
    end
    if not held then
      out[#out + 1] = skill
    end
  end
  return out
end

-- The fine kind each counted edge type is filed under. Core/Keep.lua files the first four as one
-- "recipe" kind; the contract splits them. USED_BY_SPELL (an item a spell consumes that is not a
-- trade recipe) is a reagent.
API.SUB_KINDS = {
  REAGENT_FOR = "reagent",
  USED_BY_SPELL = "reagent",
  TOOL_FOR = "tool",
  TEACHES = "teaches",
  OPENS = "lock",
  QUEST_OBJECTIVE = "quest",
  STARTS_QUEST = "quest",
  REAGENT_FOR_SPELL = "spell",
}

-- The kinds the contract's uses.kinds always carries, each a number.
API.KIND_NAMES = { "reagent", "tool", "teaches", "lock", "quest", "spell" }

-- Which quest list an edge type's quest goes in.
API.QUEST_LISTS = { QUEST_OBJECTIVE = "needs", STARTS_QUEST = "starts" }

-- The confidences Core/Keep.lua never counts (its NOT_COUNTED, kept in step by the spec). Brief RB1
-- (the owner's standing rule of 2026-10-17, "Predicted IS our data"): a guess alone; a Predicted edge
-- counts.
API.NOT_COUNTED = { guess = true }

-- Brief GF6: whether an edge counts as a use, Core/Keep.lua's own rule (Keep.CountsEdge: no guess;
-- brief RB1: every Predicted edge counts), so Jettison online counts what ItemTree counts. Without
-- Keep, NOT_COUNTED alone. Pure.
function API.Counts(edge)
  if type(edge) ~= "table" then
    return false
  end
  local k = ItemTree.Keep
  if type(k) == "table" and type(k.CountsEdge) == "function" then
    local ok, counts = pcall(k.CountsEdge, edge)
    return ok and counts == true
  end
  return not API.NOT_COUNTED[edge.confidence] and not edge.guess
end

local function keep()
  local k = ItemTree.Keep
  if type(k) == "table" and type(k.CachedScore) == "function" then
    return k
  end
  return nil
end

local function data()
  local d = ItemTree.Data
  if type(d) == "table" then
    return d
  end
  return nil
end

-- Whether a value is a positive whole number. Pure.
function API.ValidId(itemId)
  return type(itemId) == "number" and itemId > 0 and itemId == math.floor(itemId) and itemId < math.huge
end

-- Whether ItemTree_Data is loaded and the item tables are there: Data:OnDemandLoaded (the same
-- test the tooltip, the collector and Keep.Score ask) and the item index registered. Never loads
-- anything. Pure over Data.
function API.IsReady()
  local d = data()
  if not d or type(d.OnDemandLoaded) ~= "function" or type(d.Has) ~= "function" then
    return false
  end
  if not keep() then
    return false
  end
  local ok, loaded = pcall(d.OnDemandLoaded, d)
  if not ok or loaded ~= true then
    return false
  end
  local okHas, has = pcall(d.Has, d, "Index")
  return okHas and has == true
end

-- Edge type ids to their names in Edges.Types, built once.
local typeNames
local function typeName(edgeType)
  if type(edgeType) ~= "table" then
    return nil
  end
  if not typeNames then
    typeNames = {}
    local types = ItemTree.Edges and ItemTree.Edges.Types or EMPTY
    for name in pairs(API.SUB_KINDS) do
      local def = types[name]
      if type(def) == "table" and def.id then
        typeNames[def.id] = name
      end
    end
  end
  return typeNames[edgeType.id]
end

-- The edge type name of each counted use, by its target key, read off the graph's down edges with
-- Core/Keep.lua Keep.Uses' own filter: a counted type, not a guess (brief RB1: a Predicted edge
-- counts, API.Counts), the first edge per target. Pure over the graph.
function API.UseTypes(itemId)
  local Graph = ItemTree.Graph
  if type(Graph) ~= "table" or type(Graph.Children) ~= "function" or type(Graph.Key) ~= "function" then
    return {}
  end
  -- Brief Q1: the walk Keep.Uses reads with (Keep.USES_WALK), so a Classic quest the client lists
  -- is typed too.
  local k = keep()
  local walk = k and type(k.USES_WALK) == "table" and k.USES_WALK or nil
  local ok, edges = pcall(Graph.Children, Graph.Key("item", itemId), "down", walk)
  if not ok or type(edges) ~= "table" then
    return {}
  end
  local types = {}
  for _, edge in ipairs(edges) do
    if type(edge) == "table" then
      local name = typeName(edge.type)
      if name and API.Counts(edge) and edge.target ~= nil and types[edge.target] == nil then
        types[edge.target] = name
      end
    end
  end
  return types
end

-- The contract's kinds over a list of uses: lock, quest and spell straight off the score's own
-- current counts, and the score's recipe count split by edge type, each part counted by
-- Keep.ScoreUses over that part's uses with the same player facts, so a part counts exactly the
-- uses the score counted. Pure over Core/Keep.lua.
function API.Kinds(score, uses, types, context)
  local k = keep()
  local kinds = {}
  for _, name in ipairs(API.KIND_NAMES) do
    kinds[name] = 0
  end
  if not k or type(score) ~= "table" then
    return kinds
  end
  local scored = type(score.kinds) == "table" and score.kinds or EMPTY
  kinds.lock = tonumber(scored.lock) or 0
  kinds.quest = tonumber(scored.quest) or 0
  kinds.spell = tonumber(scored.spell) or 0
  if (tonumber(scored.recipe) or 0) <= 0 then
    return kinds
  end
  local parts = {}
  for _, use in ipairs(uses or EMPTY) do
    if type(use) == "table" and use.kind == "recipe" then
      local sub = API.SUB_KINDS[types[use.target]] or "reagent"
      parts[sub] = parts[sub] or {}
      parts[sub][#parts[sub] + 1] = use
    end
  end
  context = context or EMPTY
  for sub, list in pairs(parts) do
    -- Brief K24b (G): the carried via items the score was worked with (score.viaCarried), so an
    -- item combine whose crate is in the bags counts as a current reagent here too.
    local ok, part = pcall(k.ScoreUses, list, context.level, context.faction, nil, context.class, {
      completed = context.completed,
      carried = type(score.viaCarried) == "table" and score.viaCarried or nil,
    })
    if ok and type(part) == "table" then
      kinds[sub] = kinds[sub] + (tonumber(part.current) or 0)
    end
  end
  return kinds
end

-- The quests the item is needed for and starts, in the order Keep.Uses yields them, leaving out
-- every quest completed(questId) says the player has done. Brief Q1: with context ({ level,
-- faction, class }), also every quest the player cannot still do (Keep.IsCurrent: the other side,
-- or grey; Keep.QuestOutOfReach: a need whose minimum level is too far ahead); Keep.Uses already
-- left out a need of a quest that never keeps an item. counts is quest
-- id to how many of the item it asks for, for the needs whose edge states a count. Brief GF6:
-- predicted is the set of needs (quest id to true) that rest on the predicted facts alone. Pure.
function API.Quests(uses, types, completed, context)
  local quests = { needs = {}, starts = {}, counts = {}, predicted = {} }
  local k = keep()
  local isCurrent = type(context) == "table" and k and type(k.IsCurrent) == "function" and k.IsCurrent or nil
  for _, use in ipairs(uses or EMPTY) do
    if type(use) == "table" and use.kind == "quest" and type(use.questId) == "number" then
      local list = API.QUEST_LISTS[types[use.target]]
      local done = false
      if type(completed) == "function" then
        local ok, answer = pcall(completed, use.questId)
        done = ok and answer == true
      end
      if not done and isCurrent then
        local ok, current = pcall(isCurrent, use, context.level, context.faction, context.class)
        done = ok and current == false
      end
      -- Brief Q1 (the owner's ruling of 2026-10-09): nor a need the player cannot take for a while.
      if not done and isCurrent and type(k.QuestOutOfReach) == "function" then
        local ok, ahead = pcall(k.QuestOutOfReach, use, context.level)
        done = ok and ahead == true
      end
      if list and not done then
        quests[list][#quests[list] + 1] = use.questId
        if list == "needs" and tonumber(use.quantity) then
          quests.counts[use.questId] = tonumber(use.quantity)
        end
        -- Brief GF6: a need that rests on the predicted facts alone (an internal note, never drawn).
        if list == "needs" and use.predicted == true then
          quests.predicted[use.questId] = true
        end
      end
    end
  end
  return quests
end

-- Brief IT2: the StaleAfter row for an item, a list of quest ids (empty when none shipped) and its
-- kind (nil when the list is empty), read through Data:StaleAfter. Pure over Core/Data.lua.
function API.StaleAfter(itemId)
  local d = data()
  if not d or type(d.StaleAfter) ~= "function" then
    return {}, nil
  end
  local ok, quests, kind = pcall(d.StaleAfter, d, itemId)
  if not ok or type(quests) ~= "table" or #quests == 0 then
    return {}, nil
  end
  return copyList(quests), kind
end

-- Whether completed(questId) says the player has done at least one of the quests. false for none,
-- for no predicate, and for a predicate that raises. Pure.
function API.AnyCompleted(quests, completed)
  if type(completed) ~= "function" then
    return false
  end
  for _, questId in ipairs(quests or EMPTY) do
    local ok, answer = pcall(completed, questId)
    if ok and answer == true then
      return true
    end
  end
  return false
end

-- The title ItemTree's own data gives a quest, or nil. Never a client call and never a write: the
-- Classic Era table's qt first (EraSources.QuestTitleAt), then the titles the collector recorded
-- (PlayerSources.QuestTitle), then the titles the Era reader took off its quest rows (c = 3), only
-- where that reader has already indexed them, because the index is a pass over every row. Brief
-- GF6: then the predicted title (QuestsPredicted.Title, never loading the module). Pure.
function API.QuestTitle(questId)
  if type(questId) ~= "number" then
    return nil
  end
  local era = ItemTree.eraSources
  local source = nil
  if type(era) == "table" and type(era.Table) == "function" then
    local ok, answer = pcall(era.Table, era)
    source = ok and type(answer) == "table" and answer or nil
  end
  local Era = ItemTree.EraSources
  if source and type(Era) == "table" and type(Era.QuestTitleAt) == "function" then
    local ok, title = pcall(Era.QuestTitleAt, source, questId)
    if ok and type(title) == "string" and title ~= "" then
      return title
    end
  end
  local players = ItemTree.PlayerSources
  if type(players) == "table" and type(players.Table) == "function" and type(players.QuestTitle) == "function" then
    local okTable, module = pcall(players.Table)
    if okTable and type(module) == "table" then
      local ok, title = pcall(players.QuestTitle, module, questId)
      if ok and type(title) == "string" and title ~= "" then
        return title
      end
    end
  end
  local names = type(era) == "table" and rawget(era, "questNames") or nil
  local title = type(names) == "table" and names[questId] or nil
  if type(title) == "string" and title ~= "" then
    return title
  end
  -- Brief GF6: last, the predicted title of a quest nothing of ours names (a new Forever quest's,
  -- Core/QuestsPredicted.lua Title), only while that module is registered.
  local predicted = ItemTree.QuestsPredicted
  if type(predicted) == "table" and type(predicted.Title) == "function" then
    local ok, named = pcall(predicted.Title, questId, false)
    if ok and type(named) == "string" and named ~= "" then
      return named
    end
  end
  return nil
end

-- Quest id to title for every quest id in the given lists that API.QuestTitle names. Pure.
function API.Titles(...)
  local titles = {}
  for index = 1, select("#", ...) do
    local list = select(index, ...)
    for _, questId in ipairs(type(list) == "table" and list or EMPTY) do
      if titles[questId] == nil then
        titles[questId] = API.QuestTitle(questId)
      end
    end
  end
  return titles
end

-- The names of a set of skill line ids (Keep.PlayerProfessions' shape), through Keep.SkillName,
-- each name once (a build can list one profession on two lines), sorted. Lines the tables do not
-- name are left out. Pure over Core/Keep.lua.
function API.ProfessionNames(professions)
  local k = keep()
  local names = {}
  if not k or type(k.SkillName) ~= "function" or type(professions) ~= "table" then
    return names
  end
  local seen = {}
  for skill, held in pairs(professions) do
    if held then
      local ok, name = pcall(k.SkillName, tonumber(skill))
      if ok and type(name) == "string" and name ~= "" and not seen[name] then
        seen[name] = true
        names[#names + 1] = name
      end
    end
  end
  table.sort(names)
  return names
end

-- The contract's price source for Core/Prices.lua's answer: its key ("auctionator", "auctioneer",
-- "tsm") for an auction addon's label, nil for the vendor sell price or anything else. Pure.
function API.PriceSource(label)
  local prices = ItemTree.Prices
  local sources = type(prices) == "table" and prices.SOURCES or nil
  if type(label) ~= "string" or type(sources) ~= "table" then
    return nil
  end
  for _, source in ipairs(sources) do
    if type(source) == "table" and (source.label == label or source.key == label) then
      return source.key
    end
  end
  return nil
end

-- The Keep verdict's lines as plain words, or an empty list. Keep.VerdictLines is the list the
-- tooltip and the item page draw; handed no bag count, the route line names its skill band rather
-- than "12 / 40 needed", because the API reads nothing from the bags. Pure over Core/Keep.lua.
--
-- Brief K24b: the tag row reads as its plain words ("Keep, Auction", "Auction, Vendor (No AH
-- data)"), and the blank spacers around it are left out. env is Keep.Tags' (the money carried);
-- the API knows no bag slot, so the row's bonding decides whether an item can be auctioned.
function API.VerdictWords(score, env)
  local k = keep()
  local words = {}
  if not k or type(k.VerdictLines) ~= "function" or type(score) ~= "table" then
    return words
  end
  local ok, lines = pcall(k.VerdictLines, score, nil, nil, env)
  if not ok or type(lines) ~= "table" then
    return words
  end
  -- Brief GW1b: a block with no tag row (Keep.ReasonAloneParts, a gear line alone on an item with
  -- no tags) says nothing here, so keep.line stays the tag row's words and nil with no tags.
  local tagged = false
  for _, line in ipairs(lines) do
    if type(line) == "table" and line.head then
      tagged = true
    end
  end
  if not tagged then
    return words
  end
  for _, line in ipairs(lines) do
    local text = nil
    if type(line) == "table" and not line.spacer then
      text = type(line.plain) == "string" and line.plain or k.Plain(line.text)
    end
    if text and text ~= "" then
      words[#words + 1] = text
    end
  end
  return words
end

--------------------------------------------------------------------------------
-- The per item cache. What depends only on the score (the kinds, the quests, the vendor facts) is
-- kept beside it and thrown away with it (brief IT2: the stale after quests, whether one is done
-- and the titles too, so a quest turned in, which drops Keep's cache, drops them as well): an
-- entry stands while Keep.CachedScore still answers the same score table, and the lot goes
-- whenever Core/Keep.lua starts a new cache (a level, side, class, profession or route change, a
-- quest turned in, a data change). The Keep line is kept with the value it was built for, since
-- Keep refreshes the value on the score in place.
--------------------------------------------------------------------------------

API.cache = {}
API.cacheOwner = nil

function API.Reset()
  API.cache = {}
  API.cacheOwner = nil
  API.professionsFrom = nil
  API.professionNames = {}
end

-- Brief JI1: ItemTree's consumable verdict for keep.consumable, an addition within version 1, or nil
-- for an item it does not judge as a consumable. judged: the consumable facts judged it
-- (Consumables.Judge, score.consumable): keep, kind ("food", "drink", "potion", "bandage", "buff",
-- "other"), why (nil when kept, else "class", "level", "skill", "weak", "better", "rested", "cap" or,
-- brief ST4, "conjure"; brief RB5, QA item 202: "ahead" for a profession the player has at a rank not
-- reached yet, kept far ahead by the rule, so keep.marked and keep.byUse are true beside keep false
-- here; "skill" is only for a profession the player lacks), words (the reason line, "More kill
-- experience while levelling", "Useful at First Aid 225"), efficient
-- (its restore's share answer, nil where no pool is known or it restores none), buffFood and xpFood
-- (brief K25f, K29).
-- notFood (brief K29): a Food and Drink item the effects say is no food (alcohol): judged false, keep
-- false. notFood is asked for an unjudged consumable of the Food and Drink subclass alone. Pure over
-- the score and Core/Consumables.lua.
function API.ConsumableFacts(itemId, score)
  local verdict = type(score) == "table" and score.consumable or nil
  if type(verdict) == "table" then
    return {
      judged = true,
      keep = verdict.keep == true,
      kind = verdict.kind,
      why = verdict.why,
      words = verdict.words,
      efficient = verdict.efficient,
      buffFood = verdict.buffFood == true,
      xpFood = verdict.xpFood == true,
      notFood = false,
      -- Brief BQ6: additions within version 1.
      restore = tonumber(verdict.restore) or 0,
      outranked = verdict.outranked == true,
      -- Brief BQ6 addendum: the spec keys and labels that want it where not every spec of the
      -- class open at the player's level does (nil otherwise), as the words' brackets name them.
      -- Brief EC2 emptied Consumables.SPEC_WANTS, so both are nil today (brief F164).
      specs = type(verdict.specs) == "table" and copyList(verdict.specs) or nil,
      specLabels = type(verdict.specLabels) == "table" and copyList(verdict.specLabels) or nil,
    }
  end
  local consumables = ItemTree.Consumables
  if
    type(score) == "table"
    and tonumber(score.itemClass) == 0
    and tonumber(score.subclass) == 5
    and type(consumables) == "table"
    and type(consumables.IsNotFood) == "function"
    and consumables.IsNotFood(itemId)
  then
    return { judged = false, keep = false, buffFood = false, xpFood = false, notFood = true }
  end
  return nil
end

-- The derived facts for one scored item, from the cache or built now.
local function derived(k, id, score, context)
  if API.cacheOwner ~= k.cache then
    API.cache = {}
    API.cacheOwner = k.cache
  end
  local entry = API.cache[id]
  if entry and entry.score == score then
    return entry
  end
  local okUses, uses = pcall(k.Uses, id)
  uses = okUses and type(uses) == "table" and uses or {}
  local types = API.UseTypes(id)
  local count = tonumber(score.vendors)
  if count == nil and type(k.VendorCount) == "function" then
    local ok, answer = pcall(k.VendorCount, id)
    count = ok and tonumber(answer) or 0
  end
  local buyPrice = tonumber(score.price)
  -- Brief SE1: the bundle that price buys (the item row's vs), so vendors.everywhere judges one
  -- item's price as Keep's own score.everywhere does.
  local bundle = tonumber(score.bundle)
  if buyPrice == nil and score.vendors == nil and type(k.Price) == "function" then
    local ok, answer, size = pcall(k.Price, id)
    buyPrice = ok and tonumber(answer) or nil
    bundle = ok and tonumber(size) or nil
  end
  local known = false
  local d = data()
  if d and type(d.GetItem) == "function" then
    local ok, row = pcall(d.GetItem, d, id)
    known = ok and type(row) == "table"
  end
  local quests = API.Quests(uses, types, context.completed, context)
  local staleAfter, staleAfterKind = API.StaleAfter(id)
  entry = {
    score = score,
    known = known,
    kinds = API.Kinds(score, uses, types, context),
    quests = quests,
    staleAfter = staleAfter,
    staleAfterKind = staleAfterKind,
    stale = API.AnyCompleted(staleAfter, context.completed),
    titles = API.Titles(quests.needs, quests.starts, staleAfter),
    count = count or 0,
    buyPrice = buyPrice,
    bundle = bundle,
  }
  API.cache[id] = entry
  return entry
end

-- Brief K24b (G): the tags for a score (Keep.Tags with env), or nil for none, Off, or where Keep
-- cannot say. Pure over Core/Keep.lua.
function API.Tags(score, env)
  local k = keep()
  if not k or type(k.Tags) ~= "function" or type(score) ~= "table" then
    return nil
  end
  local ok, answer = pcall(k.Tags, score, nil, env)
  if ok and type(answer) == "table" then
    return answer
  end
  return nil
end

-- The Keep line and lines, rebuilt only when what they say may have moved. Brief K20-wire: the
-- state joins the stamp (the Bar setting, or a price crossing it, moves the head with no value field
-- moving), and so do the auction price and the disenchant value the reason lines name.
local function verdict(entry, score, state, sale, env, tagWords)
  local disenchant = type(score.disenchant) == "table" and score.disenchant.copper or nil
  local stamp = tostring(score.value)
    .. ":"
    -- Brief K24b: and the tags, which move with the money carried and no score field moving.
    .. tostring(tagWords)
    .. ":"
    .. tostring(score.valueSource)
    .. ":"
    .. tostring(score.valuable)
    .. ":"
    .. tostring(state)
    .. ":"
    -- Brief K21: and the sale beside a keep, which moves with the Bar and no state moving.
    .. tostring(sale)
    .. ":"
    .. tostring(score.vendor)
    .. ":"
    .. tostring(score.auction)
    .. ":"
    .. tostring(disenchant)
  if entry.lineStamp ~= stamp then
    entry.lines = API.VerdictWords(score, env)
    entry.lineStamp = stamp
  end
  return entry.lines
end

-- Brief BQ9: keep.action, { kind, words } for a "do this now" verdict (Keep.ActionTags' action), or
-- nil. Pure over Core/Keep.lua.
-- Brief BQ25a (the owner's ruling of 2026-10-10, QA item 67; the Jettison round's contract): now is
-- true where ItemTree says to do it now (open it, start its quest, a lasting buff the character
-- lacks), false for a consumable whose [Use] tag is its keep (Keep.Tags' useKeep: the buff already on,
-- a health or mana potion, a bandage), which Jettison never prompts; words are then its reason line.
local function actionFacts(k, score, tags)
  local kind = type(tags) == "table" and tags.action or nil
  if type(kind) ~= "string" then
    -- Brief BQ29 (QA items 86 and 87): and a lasting buff kept with its buff on, or a buff food
    -- while the player is well fed ([Keep], tags.buffOn).
    if type(tags) == "table" and (tags.useKeep == true or tags.buffOn == true) and type(k.TagReasons) == "function" then
      local ok, reasons = pcall(k.TagReasons, score, tags)
      local first = ok and type(reasons) == "table" and reasons[1] or nil
      local words = type(first) == "table" and type(first.text) == "string" and first.text or nil
      if words and type(k.Plain) == "function" then
        words = k.Plain(words)
      end
      return { kind = "use", words = words, now = false }
    end
    return nil
  end
  local words = nil
  if type(k.ActionWords) == "function" then
    local ok, answer = pcall(k.ActionWords, kind, score, tags)
    words = ok and type(answer) == "string" and answer or nil
  end
  -- Brief GW1: a cosmetic to collect is a "use" for another addon, marked collect.
  if kind == k.ACTION_COLLECT then
    return { kind = "use", words = words, now = true, collect = true }
  end
  return { kind = kind, words = words, now = true }
end

--- Brief AM1 (QA item 330): keep.ammo, { weapon, required, words } where ItemTree keeps the item as ammo
--- the worn ranged weapon fires (the tags' keepBy Keep.KEEP_AMMO: [Keep] "Ammo for your bow"), or nil:
--- weapon the worn weapon's subclass (2 bow, 3 gun, 18 crossbow), required the ammo's required level
--- (nil for none) and words the reason line. Pure over Core/Keep.lua.
function API.AmmoFacts(k, score, tags)
  local ammo = type(score) == "table" and score.ammo or nil
  if type(ammo) ~= "table" or type(tags) ~= "table" or type(k) ~= "table" or tags.keepBy ~= k.KEEP_AMMO then
    return nil
  end
  local words = type(k.AmmoWords) == "function" and k.AmmoWords(ammo) or nil
  return { weapon = tonumber(ammo.weapon), required = tonumber(ammo.required), words = words }
end

--- Brief QX1 (the owner, 2026-10-22: quest items you no longer need): keep.finished, { complete = {
--- questId, ... }, abandoned = { questId, ... }, below = { questId, ... } (brief AQF1 fix 4), titles = {
--- [questId] = title } } where ItemTree's
--- verdict is a finished quest item (the tags' finished: [Vendor] or [Worthless] with 'Quest complete:
--- "..."' and 'Quest abandoned: "..."', Keep.FinishedLines), titles the very titles those lines name
--- (Keep.FinishedTitle), so another addon words them as ItemTree does; nil otherwise (a kept quest item
--- included). Pure over Core/Keep.lua.
function API.FinishedFacts(k, tags)
  local finished = type(tags) == "table" and tags.finished or nil
  if type(finished) ~= "table" or type(k) ~= "table" then
    return nil
  end
  local answer = {
    complete = copyList(finished.complete),
    abandoned = copyList(finished.abandoned),
    -- Brief AQF1 fix 4 (the owner's ruling "A" of 2026-10-22): the grey chain ends never taken.
    below = copyList(finished.below),
    titles = {},
  }
  for _, list in ipairs({ answer.complete, answer.abandoned, answer.below }) do
    for _, questId in ipairs(list) do
      local title = type(k.FinishedTitle) == "function" and k.FinishedTitle(questId) or nil
      if type(title) == "string" then
        answer.titles[questId] = title
      end
    end
  end
  return answer
end

--- Brief GW1: keep.cosmetic, { collected } for a cosmetic piece (Keep.CosmeticFacts), or nil. Pure.
function API.CosmeticFacts(score)
  local cosmetic = type(score) == "table" and score.cosmetic or nil
  if type(cosmetic) ~= "table" then
    return nil
  end
  return { collected = cosmetic.collected }
end

-- Brief IT2: the player's professions by name, held against the set Keep.PlayerProfessions
-- answered, by identity: that set is read again only on SKILL_LINES_CHANGED or after Keep.Reset
-- (a new table each time), and the pretend set is its own table, so a new set is new names.
API.professionsFrom = nil
API.professionNames = {}

local function professionNames(k)
  if type(k.PlayerProfessions) ~= "function" then
    return {}
  end
  local ok, set = pcall(k.PlayerProfessions)
  set = ok and type(set) == "table" and set or nil
  if set ~= API.professionsFrom or set == nil then
    API.professionsFrom = set
    API.professionNames = API.ProfessionNames(set)
  end
  return API.professionNames
end

-- Brief K27: the gear compare's answer for keep.gear, an addition within version 1, or nil for an
-- item with no gear facts (not a weapon or armour, or Core/Gear.lua not loaded): upgrade (the gear
-- test keeps it, Keep.GearUpgrade: an upgrade for ANY spec, wearable now or within the look ahead),
-- basis (Gear.Compare's, nil where it did not compare), specs (the spec keys it upgrades in the
-- class's order, empty where the stats did not decide) and labels (each spec's label, the same
-- order). Pure over Core.
local function gearFacts(k, score)
  local gear = type(score.gear) == "table" and score.gear or nil
  if not gear then
    -- Brief ST3 (QA item 320): gear whose suggestions the player turned off (no spec ticked,
    -- Keep.GearOff): not an upgrade, said outright, so Jettison does not fall back to its own item
    -- level compare and keep it as one.
    if score.gearOff == true then
      return { upgrade = false, specs = {}, labels = {}, off = true }
    end
    return nil
  end
  local specs = copyList(type(gear.specs) == "table" and gear.specs or nil)
  local model = ItemTree.Gear
  local labels = {}
  for index, spec in ipairs(specs) do
    local label = type(model) == "table" and type(model.SpecLabel) == "function" and model.SpecLabel(gear.classId, spec)
      or nil
    labels[index] = type(label) == "string" and label or spec
  end
  -- Brief BQ11: a hunter's Careful Aim rank the compare weighed by (0 to 5), nil for another class
  -- or while the rank is not read.
  local carefulAim = nil
  if type(model) == "table" and tonumber(gear.classId) == 3 then
    -- Brief BQ13: through Gear.CarefulAimRank, the pretend rank while /itemtree demo sets one.
    if type(model.CarefulAimRank) == "function" then
      carefulAim = tonumber(model.CarefulAimRank())
    else
      carefulAim = tonumber(model.carefulAimRank)
    end
  end
  return {
    upgrade = type(k.GearUpgrade) == "function" and k.GearUpgrade(score) == true,
    basis = gear.basis,
    specs = specs,
    labels = labels,
    carefulAim = carefulAim,
  }
end

-- Brief K30: keep.need, the route's count where the item's keep rests on it alone
-- (Keep.ReagentKeepNeed), or nil; nil too where the block says nothing (line is nil). Brief INT1b
-- (the owner's ruling of 2026-10-10, Q(c)): or, where the route and the open quests keep it
-- together, their sum (Keep.KeepNeed over Keep.CombinedKeepNeed); route.need is then the route's part
-- and the quests' part the rest. Pure over Core.
local function reagentKeepNeed(k, score, line)
  local count = type(k.KeepNeed) == "function" and k.KeepNeed or k.ReagentKeepNeed
  if line == nil or type(count) ~= "function" then
    return nil
  end
  local ok, need = pcall(count, score)
  if ok and tonumber(need) then
    return tonumber(need)
  end
  return nil
end

-- Brief RB2B (QA item 267 (c)): keep.why, the reason a keep by the item's uses rests on where a
-- profession names it (Keep.KeepWhy), with the professions by name; nil where Keep names none.
local function whyFacts(k, score)
  if type(k.KeepWhy) ~= "function" then
    return nil
  end
  local ok, why = pcall(k.KeepWhy, score)
  if not ok or type(why) ~= "table" then
    return nil
  end
  local function named(skill)
    if skill == nil or type(k.SkillName) ~= "function" then
      return nil
    end
    local okName, name = pcall(k.SkillName, tonumber(skill))
    return okName and type(name) == "string" and name or nil
  end
  return {
    kind = why.kind,
    skill = tonumber(why.skill),
    profession = named(why.skill),
    via = tonumber(why.via),
    viaProfession = named(why.via),
    name = type(why.name) == "string" and why.name or nil,
  }
end

-- Brief BQ18: keep.stock, the working stock ItemTree keeps (Keep.StockFacts on the score, while the
-- tags keep it as such: keepBy Keep.KEEP_STOCK), or nil. Pure over Core.
local function stockFacts(k, score, tags)
  local stock = type(score.stock) == "table" and score.stock or nil
  if not stock or type(tags) ~= "table" or tags.keepBy ~= k.KEEP_STOCK then
    return nil
  end
  local function nameOf(itemId)
    local d = data()
    if not d or type(d.GetItem) ~= "function" then
      return nil
    end
    local ok, row = pcall(d.GetItem, d, tonumber(itemId))
    return ok and type(row) == "table" and row.n or nil
  end
  local profession = nil
  if type(k.SkillName) == "function" then
    local ok, name = pcall(k.SkillName, tonumber(stock.skill))
    profession = ok and type(name) == "string" and name or nil
  end
  return {
    cap = tonumber(stock.cap),
    uses = {
      {
        skill = tonumber(stock.skill),
        profession = profession,
        item = tonumber(stock.product),
        name = nameOf(stock.product),
        useful = tonumber(stock.useful),
        usefulName = nameOf(stock.useful),
        kind = stock.kind,
      },
    },
  }
end

--- Brief K31: keep.tool, a profession tool's facts, or nil for an item that is no tool:
--- { skill, name, own, best, bag, slot }. skill is the skill line it serves (the player's own one
--- first; for a tool kept, the profession it is kept for), name that profession's name, own true
--- where it is one of the player's professions, best true where this item is the tool the player
--- keeps for it (Keep.ToolFor over the bag walk; false for a spare and for a tool of another
--- profession), bag and slot the bag slot of the copy kept where best and the player carries it
--- (two copies of one id share this answer; the copy in that slot is the one kept), nil otherwise.
--- Pure over Core.
function API.ToolFacts(k, score, env)
  local tool = type(score) == "table" and score.tool or nil
  if type(tool) ~= "table" then
    return nil
  end
  local held = type(env) == "table" and type(env.tool) == "table" and env.tool or nil
  local best = false
  if tool.own then
    best = held == nil or held.best ~= false
  end
  local skill = tonumber(tool.skill)
  if held and tonumber(held.skill) then
    skill = tonumber(held.skill)
  end
  local name = tool.name
  if type(k) == "table" and type(k.ToolName) == "function" then
    local ok, named = pcall(k.ToolName, score, env)
    if ok and type(named) == "string" then
      name = named
    end
  end
  local answer = { skill = skill, name = name, own = tool.own == true, best = best }
  if best and held then
    answer.bag, answer.slot = tonumber(held.bag), tonumber(held.slot)
  end
  return answer
end

--- Brief BQ25c: keep.bag, a copy of the score's bag rule answer (Keep.BagFacts), or nil. Pure.
function API.BagFacts(score)
  local bag = type(score) == "table" and score.bag or nil
  if type(bag) ~= "table" then
    return nil
  end
  local answer = {
    kind = bag.kind,
    keep = bag.keep == true,
    words = bag.words,
    slots = tonumber(bag.slots),
    against = tonumber(bag.against),
    speed = tonumber(bag.speed),
  }
  -- Brief BG1: a spare bag kept for the bank and alts (spare, reason), and the cap where the spare
  -- bag rule weighed it.
  if bag.spare == true then
    answer.spare = true
    answer.reason = bag.reason
  end
  if type(bag.cap) == "table" then
    answer.cap = { kept = tonumber(bag.cap.kept), max = tonumber(bag.cap.max), copies = tonumber(bag.cap.copies) }
  end
  -- QA item 153: a quiver or pouch upgrade kept until the level the character can wear it.
  if bag.keep == true and tonumber(bag.later) then
    answer.later = tonumber(bag.later)
  end
  return answer
end

-- The facts for one item and player context { level, faction, class, completed }, or nil when the
-- id is not a positive integer, the data is not ready, or Keep cannot score it. Pure over Core.
function API.Facts(itemId, link, context)
  if not API.ValidId(itemId) or not API.IsReady() then
    return nil
  end
  local k = keep()
  context = type(context) == "table" and context or {}
  if type(link) ~= "string" or link == "" then
    link = nil
  end
  local ok, score = pcall(k.CachedScore, itemId, context.level, context.faction, nil, nil, nil, link)
  if not ok or type(score) ~= "table" then
    return nil
  end
  if context.class == nil and type(k.PlayerClass) == "function" then
    local okClass, class = pcall(k.PlayerClass)
    context.class = okClass and class or nil
  end
  if context.completed == nil and type(k.QuestCompleted) == "function" then
    context.completed = k.QuestCompleted
  end
  local entry = derived(k, itemId, score, context)
  -- Brief K24b (G): keep.state and keep.sale keep answering their old values, mapped from the
  -- tags (Keep.TagState), which the money carried decides with the score.
  local env = type(k.Env) == "function" and k.Env() or nil
  -- Brief K31: for a tool of one of the player's professions, which copy the player keeps
  -- (Keep.ToolFor over the bag walk, for the item id alone: no bag slot is known here).
  if type(env) == "table" and type(score.tool) == "table" and score.tool.own and type(k.ToolFor) == "function" then
    local okTool, tool = pcall(k.ToolFor, itemId)
    env.tool = okTool and type(tool) == "table" and tool or nil
  end
  local tags = API.Tags(score, env)
  local state, sale = nil, nil
  if tags and type(k.TagState) == "function" then
    state, sale = k.TagState(tags)
  end
  local tagWords = tags and type(k.TagWords) == "function" and k.TagWords(tags) or nil
  local lines = verdict(entry, score, state, sale, env, tagWords)
  local kinds = {}
  for _, name in ipairs(API.KIND_NAMES) do
    kinds[name] = entry.kinds[name] or 0
  end
  local facts = {
    itemId = itemId,
    known = entry.known,
    keep = {
      -- Brief K24b: the same answer as the bag's Keep look, which follows the Keep tag.
      -- Brief K31: never for a spare copy of the player's tool (Keep.ToolSpare), whatever else
      -- the score says.
      marked = (k.Marked(score) == true and not (type(k.ToolSpare) == "function" and k.ToolSpare(score, env)))
        or (tags ~= nil and type(k.HasTag) == "function" and k.HasTag(tags, "keep")),
      valuable = score.valuable == true,
      never = score.override == "never",
      always = score.override == "always",
      -- Brief RB5b (an addition within version 1): the player's Off, silence on this item (Keep marks
      -- nothing, the tooltip says nothing, brief K5), so another addon takes no keep reason from the
      -- rule answers beside it either.
      off = score.override == "off",
      line = lines[1],
      lines = copyList(lines),
      -- Brief K20-wire: an additive field (docs/public-api.md, version 1 unchanged), nil where
      -- the block says nothing, like line.
      state = lines[1] ~= nil and state or nil,
      -- Brief K21: an additive field too, the sale beside a keep state ("sell" or "disenchant"),
      -- nil where there is none.
      sale = lines[1] ~= nil and sale or nil,
      -- Brief K24b (G): additive fields within version 1. tags is the list of tag keys in display
      -- order ("keep", "auction", "vendor", "disenchant"), empty where line is nil; the three flags
      -- are false there. Brief WL1: "worthless" (Keep.TagState's "worthless" in keep.state) passes
      -- through as any tag does: a bound piece no one buys and nothing claims.
      tags = copyList(lines[1] ~= nil and tags and tags.tags or nil),
      noAuctionData = lines[1] ~= nil and tags ~= nil and tags.noAuctionData == true,
      legendary = lines[1] ~= nil and tags ~= nil and tags.legendary == true,
      byUse = lines[1] ~= nil and tags ~= nil and tags.byUse == true,
      -- Brief JI1: an addition within version 1, nil for an item not judged as a consumable.
      consumable = API.ConsumableFacts(itemId, score),
      -- Brief K27: an addition within version 1, nil for an item with no gear facts.
      gear = gearFacts(k, score),
      -- Brief K30: an addition within version 1, the route's count where the keep rests on it
      -- alone (Keep.ReagentKeepNeed): the player's units beyond it are the item's other verdict.
      -- Brief INT1b: or the sum of the route's and the open quests' counts where they keep it
      -- together (Keep.CombinedKeepNeed). nil for any other item.
      need = reagentKeepNeed(k, score, lines[1]),
      -- Brief BQ9: an addition within version 1, what the character should do with the item now:
      -- { kind = "open" | "use" | "quest", words } (the tooltip's [Open] or [Use] and its line),
      -- nil for anything else. keep.marked and keep.byUse are false for it (no Keep).
      action = actionFacts(k, score, tags),
      -- Brief BQ18: an addition within version 1, the working stock (one stack of a reagent off the
      -- levelling route): { cap, uses = { { skill, profession, item, name, useful, usefulName, kind }
      -- } }, nil for anything else.
      stock = lines[1] ~= nil and stockFacts(k, score, tags) or nil,
      -- Brief RB2B (QA item 267 (c)): an addition within version 1, the reason a keep by its uses rests
      -- on where a profession names it: { kind = "trade" | "tracked" | "chain" | "recipe", skill,
      -- profession, via, viaProfession, name } (Keep.KeepWhy), nil for anything else.
      why = lines[1] ~= nil and tags ~= nil and tags.byUse == true and whyFacts(k, score) or nil,
      -- Brief BQ23: an addition within version 1, true for a camp item (Camp Chair, Camp Tent: the
      -- item effects' kind 62), so Jettison names it "camp item", never a profession's tool; nil
      -- otherwise.
      camp = score.campItem == true or nil,
      -- Brief TOY2 (the owner's QA item 303): an addition within version 1, true for a toy (score.toy,
      -- Keep.IsToy), so Jettison locks it ("Locked: toy") where the client's Toy Box names none and its
      -- own baked list is not loaded; nil otherwise.
      toy = score.toy == true or nil,
      -- Brief AM1 (the owner's QA item 330): an addition within version 1, { weapon, required, words }
      -- where ItemTree keeps the item as ammo the worn ranged weapon fires ("Ammo for your bow"), so
      -- Jettison words its ammo lock and this keep once; nil otherwise.
      ammo = lines[1] ~= nil and API.AmmoFacts(k, score, tags) or nil,
      -- Brief BQ25c: an addition within version 1, the bag rule's answer (see the header), nil for
      -- an item that is no bag.
      bag = API.BagFacts(score),
      -- Brief GW1: an addition within version 1, { collected } for a cosmetic piece, nil otherwise.
      cosmetic = API.CosmeticFacts(score),
      -- Brief K31: an addition within version 1, a profession tool's facts (see the header), nil for
      -- an item that is no tool.
      tool = API.ToolFacts(k, score, env),
      -- Brief QX1: an addition within version 1, a finished quest item's quests done (see the header),
      -- nil for anything else.
      finished = lines[1] ~= nil and API.FinishedFacts(k, tags) or nil,
    },
    uses = {
      current = tonumber(score.current) or 0,
      stale = tonumber(score.stale) or 0,
      kinds = kinds,
      professions = copyList(professionNames(k)),
      -- Brief BQ18: an addition within version 1, the player's own professions' skill lines whose
      -- current recipes use the item (Keep's trade lines), empty for none.
      -- Brief RB2A (QA item 250): and the gathering trades' lines whose recipes are not grey yet, which
      -- Keep holds apart from the route's count (score.gatherLines), so the list is as it was.
      reagentSkills = reagentLines(score),
    },
    quests = {
      needs = copyList(entry.quests.needs),
      starts = copyList(entry.quests.starts),
      staleAfter = copyList(entry.staleAfter),
      staleAfterKind = entry.staleAfterKind,
      stale = entry.stale == true,
      titles = copyMap(entry.titles),
      -- Brief Q1: additions within version 1. counts, quest id to how many of the item each need
      -- asks for; keepUpTo, how many the keep holds where it rests on quest needs alone (the rest
      -- can go: Keep.QuestKeepUpTo), nil otherwise.
      counts = copyMap(entry.quests.counts),
      keepUpTo = type(k.QuestKeepUpTo) == "function" and k.QuestKeepUpTo(score) or nil,
      -- Brief GF6: an addition within version 1, the needs (quest id to true) that rest on the
      -- predicted facts alone (a new Forever quest's objective), an internal note no line draws;
      -- empty for none.
      predicted = copyMap(entry.quests.predicted),
    },
    vendors = {
      count = entry.count,
      -- Brief BQ6 (backlog 5): never for an item sold mostly in limited stock (score.limited).
      -- Brief SE1 (the owner's ruling A of 2026-10-20, QA item 301): one item's price, buyPrice over
      -- the bundle it buys; buyPrice itself stays the bundle's, as the data ships it.
      everywhere = k.Everywhere(entry.count, entry.buyPrice, entry.bundle) == true and score.limited ~= true,
      buyPrice = entry.buyPrice,
    },
  }
  -- The route only while the Professions module is on and loaded (Keep.ProfessionModel).
  local okModel, model = pcall(k.ProfessionModel)
  if okModel and model ~= nil then
    local info = type(score.profession) == "table" and score.profession or nil
    local route = { needed = info ~= nil }
    -- Brief K30: an addition within version 1, the route's count for the item's own profession
    -- recipes (0 for none left on the route), nil where it could not be worked out.
    route.need = tonumber(score.reagentNeed)
    if info and type(k.SkillName) == "function" then
      local okName, name = pcall(k.SkillName, tonumber(info.skillLine))
      if okName and type(name) == "string" then
        route.profession = name
      end
    end
    facts.route = route
  end
  local source = API.PriceSource(score.valueSource)
  local copper = tonumber(score.value)
  if source and copper and copper > 0 then
    -- Brief K24b (G): worthTrip, true where the Auction tag is there on a known price.
    -- Brief K24b follow-up: only a known price that earned the Auction tag (never noAuctionData).
    local worthTrip = tags ~= nil
      and lines[1] ~= nil
      and not tags.noAuctionData
      and type(k.HasTag) == "function"
      and k.HasTag(tags, "auction")
    facts.price = { copper = copper, source = source, worthTrip = worthTrip == true }
  end
  return facts
end

--------------------------------------------------------------------------------
-- Ready callbacks. Pure: API.Notice runs them, and the client side below calls it.
--------------------------------------------------------------------------------

API.pending = {}
API.seen = {}

-- Runs fn under pcall, dropping anything it raises.
local function run(fn)
  pcall(fn)
end

-- Runs every waiting callback once the data is ready, in the order they were registered. Answers
-- whether the data is ready.
function API.Notice()
  if not API.IsReady() then
    return false
  end
  local waiting = API.pending
  API.pending = {}
  for _, fn in ipairs(waiting) do
    run(fn)
  end
  return true
end

-- Registers fn to run once when the data is ready, or runs it at once when it already is. Answers
-- true when fn was taken, false for a non function or a second registration of the same fn.
function API.RegisterReadyCallback(fn)
  if type(fn) ~= "function" or API.seen[fn] then
    return false
  end
  API.seen[fn] = true
  if API.IsReady() then
    run(fn)
    return true
  end
  API.pending[#API.pending + 1] = fn
  return true
end

--------------------------------------------------------------------------------
-- Change callbacks (brief JET13, item 161 of the owner's QA of 2026-10-14: after `/itemtree demo bags
-- 14,14,14,14` and `/itemtree demo have 4240 14` ItemTree read Vendor for Linen Bag while Jettison
-- went on reading "Locked: useful for bank and alts" until something else made it rank again).
-- Another addon registers fn(what) and hears when ItemTree's answers may have changed with nothing
-- in its bags moving: "demo" after the demo state changed (on, off, any demo sub-command: Core/Demo.lua
-- calls API.NotifyChange from Demo.Publish, which every change goes through), "setting" after a saved
-- setting that changes answers (API.SettingChangesAnswers, heard through UI/Options.lua's
-- ITEMTREE_SETTING_CHANGED) and, brief K14 (ruling 1 of 2026-10-14), after the player's Keep word on
-- one item changed (Always keep, Never keep, Off, or back to Auto: Core/Keep.lua Keep.SetOverride
-- calls API.NotifyChange("setting")). The changes of one frame are told once, on the next frame
-- (C_Timer.After 0), so a scenario's several steps or a slider's drag reach the consumer as one call;
-- what is the first change since the last call. Without a timer (a spec) the call is at once. Nothing
-- is scheduled while no one listens. Pure but for that timer, looked up at call time.
--------------------------------------------------------------------------------

API.changeCallbacks = {}
API.changeSeen = {}
API.changeWanted = nil
API.changeScheduled = false

-- The saved settings whose value changes what GetItemFacts answers (UI/Options.lua's keys): Valuable
-- at (keep.valuable), the auction bar and its formula (keep.tags, keep.state, price.worthTrip), and the
-- Professions tab (UI/ProfessionsStub.lua's SETTING: route, keep.need, keep.stock). And every gear spec
-- row (Options.SPEC_KEY_PREFIX, "gearSpec_holy": keep.gear, keep.consumable.specs), and Hide other
-- faction data (brief F155, review of 0.1.13: which side's quests and NPCs count as uses). The rest (badges,
-- tooltips, the window, Keep marks' look) change no answer. compareBuild has no control and nothing in
-- Core reads it.
API.CHANGE_SETTINGS = {
  keepValueCopper = true,
  keepSellBar = true,
  keepSellFormula = true,
  showProfessions = true,
  hideOtherFaction = true,
}
API.SPEC_SETTING_PREFIX = "gearSpec_"

--- Whether saving the setting key can change an answer (API.CHANGE_SETTINGS, a gear spec row). Pure.
function API.SettingChangesAnswers(key)
  if type(key) ~= "string" then
    return false
  end
  if API.CHANGE_SETTINGS[key] then
    return true
  end
  return key:sub(1, #API.SPEC_SETTING_PREFIX) == API.SPEC_SETTING_PREFIX
end

--- Registers fn(what) to run after each change (above). Answers true when fn was taken, false for a
--- non function or a second registration of the same fn. Never runs fn at once.
function API.RegisterChangeCallback(fn)
  if type(fn) ~= "function" or API.changeSeen[fn] then
    return false
  end
  API.changeSeen[fn] = true
  API.changeCallbacks[#API.changeCallbacks + 1] = fn
  return true
end

-- Whether the change waits: while ItemTree's developer test run sets the demo state case by case, a
-- consumer would rank its bags against every case. The run's end puts the player's own state back,
-- which is a change of its own, so the consumer hears the one that matters then.
local function changesHeld()
  return false
end

--- Runs every change callback with what, in the order they were registered, each under pcall (a
--- raise is dropped and never stops the next). Answers how many ran.
function API.RunChange(what)
  local count = 0
  for _, fn in ipairs(API.changeCallbacks) do
    run(function()
      fn(what)
    end)
    count = count + 1
  end
  return count
end

--- The frame after a change: tells the waiting one, unless a test run holds it (it then waits for the
--- next change). Answers whether the callbacks ran.
function API.FlushChange()
  API.changeScheduled = false
  local what = API.changeWanted
  if what == nil or changesHeld() then
    return false
  end
  API.changeWanted = nil
  API.RunChange(what)
  return true
end

--- A change happened ("demo" or "setting"): the callbacks hear it on the next frame, once however many
--- changes come before it. Answers true when the callbacks will run or ran; false while no one listens.
function API.NotifyChange(what)
  if #API.changeCallbacks == 0 then
    return false
  end
  if API.changeWanted == nil then
    API.changeWanted = what or "demo"
  end
  if API.changeScheduled then
    return true
  end
  local timer = rawget(_G, "C_Timer")
  local after = type(timer) == "table" and rawget(timer, "After") or nil
  if type(after) == "function" and pcall(after, 0, API.FlushChange) then
    API.changeScheduled = true
    return true
  end
  return API.FlushChange()
end

--- A saved setting (UI/Options.lua's ITEMTREE_SETTING_CHANGED): a change only where it can move an
--- answer. Answers whether it was one.
function API.OnSettingChanged(key)
  if not API.SettingChangesAnswers(key) then
    return false
  end
  return API.NotifyChange("setting")
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

-- The player's level and side as Core/Keep.lua takes them: UI/Overlay.lua's PlayerFacts, which
-- the bag marks score with, so the API shares their cache key; else the same two client calls
-- about the player, never about an item.
function API.PlayerContext()
  -- Brief BQ13: the pretend level (Core/Demo.lua) replaces the client's while it is set.
  local demo = ItemTree.Demo
  local function levelOf(real)
    if type(demo) == "table" and type(demo.PlayerLevel) == "function" then
      local ok, level = pcall(demo.PlayerLevel, real)
      if ok then
        return level
      end
    end
    return real
  end
  local ui = ItemTree.UI
  local overlay = type(ui) == "table" and ui.Overlay or nil
  if type(overlay) == "table" and type(overlay.PlayerFacts) == "function" then
    local ok, level, faction = pcall(overlay.PlayerFacts)
    if ok then
      return { level = levelOf(level), faction = faction }
    end
  end
  local level, word
  local unitLevel = rawget(_G, "UnitLevel")
  if type(unitLevel) == "function" then
    local ok, answer = pcall(unitLevel, "player")
    level = ok and tonumber(answer) or nil
  end
  local factionGroup = rawget(_G, "UnitFactionGroup")
  if type(factionGroup) == "function" then
    local ok, answer = pcall(factionGroup, "player")
    word = ok and answer or nil
  end
  -- Brief BQ14 follow up: the pretend side (Core/Demo.lua) while it is set.
  local pretendDemo = ItemTree.Demo
  if type(pretendDemo) == "table" and type(pretendDemo.FactionWord) == "function" then
    local ok, pretend = pcall(pretendDemo.FactionWord)
    if ok and pretend then
      word = pretend
    end
  end
  local k = keep()
  local faction = nil
  if k and type(k.FactionOf) == "function" then
    faction = k.FactionOf(word)
  end
  return { level = levelOf(level), faction = faction }
end

-- Asks for ItemTree_Data through Data:LoadOnDemand, the loader login uses (tried once per session;
-- a failure is final until /reload and prints its one chat line). Does nothing when ready. Runs
-- the waiting callbacks where the load made it ready. Never raises. Brief PF5: named as the
-- caller, so a load another addon asked for says so on /itprobe show (Data.loadTiming.module).
function API.RequestData()
  if API.IsReady() then
    return true
  end
  local d = data()
  if d and type(d.LoadOnDemand) == "function" then
    pcall(d.LoadOnDemand, d, nil, "ItemTreeAPI.RequestData")
  end
  local ok, ready = pcall(API.Notice)
  return ok and ready == true
end

-- The facts with ItemTree's own player context.
function API.GetItemFacts(itemId, link)
  if not API.ValidId(itemId) or not API.IsReady() then
    return nil
  end
  local ok, facts = pcall(API.Facts, itemId, link, API.PlayerContext())
  if ok and type(facts) == "table" then
    return facts
  end
  return nil
end

-- The data arrives through LoadAddOn, at PLAYER_LOGIN (Core/Init.lua) or the first time any
-- surface asks Data:Get for one of its modules, and the client announces it with ADDON_LOADED for
-- ItemTree_Data. Nothing else in the core exposes that moment, so one small frame of our own
-- listens, parented to nothing, and stops listening once the data is there.
API.EVENTS = { "ADDON_LOADED", "PLAYER_LOGIN" }

function API.OnEvent(frame, event, name)
  if event == "ADDON_LOADED" then
    local d = data()
    local folder = d and d.ON_DEMAND_ADDON or "ItemTree_Data"
    if name ~= folder then
      return false
    end
  elseif event ~= "PLAYER_LOGIN" then
    return false
  end
  local ok, ready = pcall(API.Notice)
  if ok and ready and type(frame) == "table" and type(frame.UnregisterAllEvents) == "function" then
    pcall(frame.UnregisterAllEvents, frame)
  end
  return ok and ready == true
end

function API.Install()
  if API.frame then
    return API.frame
  end
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, "Frame")
  if not ok or type(frame) ~= "table" or type(frame.RegisterEvent) ~= "function" then
    return nil
  end
  for _, event in ipairs(API.EVENTS) do
    pcall(frame.RegisterEvent, frame, event)
  end
  pcall(frame.SetScript, frame, "OnEvent", function(self, event, name)
    API.OnEvent(self, event, name)
  end)
  API.frame = frame
  return frame
end

API.Install()

-- Brief JET13 (161): the saved settings, from UI/Options.lua's ITEMTREE_SETTING_CHANGED, which
-- Options.OnChanged fires through ItemTree's CallbackHandler after every save (an addon callback, not
-- a client event; the handler is (event, key, value)). Registered once, as the file loads, after
-- Core/Init.lua made ItemTree.RegisterCallback; nothing where the library is not there.
function API.ListenSettings()
  if API.settingsHeard then
    return true
  end
  local register = ItemTree.RegisterCallback
  if type(register) ~= "function" then
    return false
  end
  local ok = pcall(register, API, "ITEMTREE_SETTING_CHANGED", function(_, key)
    API.OnSettingChanged(key)
  end)
  API.settingsHeard = ok == true
  return API.settingsHeard
end

API.ListenSettings()

-- The public table. Only these seven names; everything else stays on the private namespace.
-- Brief BQ13: demo, the demo state (Core/Demo.lua Demo.Publish rewrites it in place on every change),
-- { on = false } while nothing is pretended, so Jettison and the self test know a verdict was given
-- for a pretend character. A reader only reads it.
local api = {
  version = API.VERSION,
  demo = { on = false },
  IsReady = function()
    local ok, ready = pcall(API.IsReady)
    return ok and ready == true
  end,
  RequestData = function()
    local ok, ready = pcall(API.RequestData)
    return ok and ready == true
  end,
  RegisterReadyCallback = function(fn)
    local ok, taken = pcall(API.RegisterReadyCallback, fn)
    return ok and taken == true
  end,
  -- Brief JET13 (161): fn(what) after the demo state or an answer changing setting changed.
  RegisterChangeCallback = function(fn)
    local ok, taken = pcall(API.RegisterChangeCallback, fn)
    return ok and taken == true
  end,
  GetItemFacts = function(itemId, link)
    local ok, facts = pcall(API.GetItemFacts, itemId, link)
    if ok and type(facts) == "table" then
      return facts
    end
    return nil
  end,
}
API.public = api

-- The one intended global: ItemTreeAPI, the read only API other addons find with
-- rawget(_G, "ItemTreeAPI"). Assigned plainly, never through _G, as the taint lint asks.
ItemTreeAPI = api
