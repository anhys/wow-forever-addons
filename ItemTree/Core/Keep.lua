-- Keep marks (brief T4): is an item in the bags worth keeping? Pure Lua, no WoW API.
-- Loaded as: local _, ItemTree = ...
--
-- A tester's bags were full of new items the addon had taught him were used for something, when
-- the only use was a recipe far below his level or a quest for the other faction. So a bag slot
-- wears a gold glow when the item still has uses ahead of the player, worked out entirely from
-- ItemTree's own tables. Nothing here asks the client about an item.
--
-- The rule, which the item tooltip explains in one line:
--
--   Uses     what the item is for, read off the graph's own down edges: a recipe it is a reagent
--            of, a recipe it is the tool for, a recipe it teaches, a lock it opens, and a quest
--            that needs it or that it starts. Guessed edges never count. Brief RB1 (the owner's
--            standing rule of 2026-10-17, "Predicted IS our data"): a Predicted edge counts like any
--            other (Keep.CountsEdge), judged by the same rules.
--   Level    each use's level: the crafted item's required level, else the recipe's skill rank
--            divided by five and rounded up (a level proxy: rank 300 is about level 60), else the
--            quest's level where an edge carries one, else nil (not known).
--   Faction  a use's side, from the edge's faction field: 1 Alliance, 2 Horde, 3 both, nil not
--            known. A use for the other side is never current. An edge with no field is anyone's.
--            Brief QS1 (the owner's ruling A of 2026-10-14): a QUEST of the other side is no use at
--            all for this character, neither current nor stale (score.questsOtherSide). Brief F155:
--            only while "Hide other faction data" is on (Keep.HidesOtherSide, the default); off, such
--            a quest is a stale use again, as before QS1. Brief QS2b: a quest with no side whose
--            only records are of the other side's players (use.seenSide, Keep.SeenOtherSideQuest)
--            is no use either, whatever the setting says (score.questsSeenOtherSide); it is never
--            hidden or worded "Alliance only" anywhere.
--   Class    a class spell the item is the reagent for (brief P5b, REAGENT_FOR_SPELL) has no
--            level, and is current only for its own class, or for everyone where its classId is
--            0. For another class it is neither current nor stale: the tooltip says whose it is.
--   Current  a use is current when its level is unknown, or at least ENDGAME (endgame stays
--            relevant to everyone), or no more than BEHIND levels below the player's.
--   Marked   two or more current uses; or an endgame use; or a current class spell use (a reagent
--            the player casts with is always worth carrying); or one current use on an item that
--            is itself at least OWN_LEVEL (required level or item level); or (brief TB12) a current
--            quest use, whatever the item's level. An item whose only uses are stale is not marked,
--            and its tooltip says so.
--
-- Brief K1 refined it three ways (the owner on Refreshing Spring Water, 2026-09-28: "useful but
-- very available to buy, so make it neutral most of the time"):
--
--   Everywhere  an item EVERYWHERE_VENDORS or more vendors sell, for CHEAP_COPPER or less, is
--               neutral whatever its uses: no glow, and the line reads "Sold by vendors
--               everywhere" (muted). The vendors are counted off the shipped tables the Sources
--               view reads: the Classic Era vendor rows (EraSources, a summary row's list decoded
--               where it ships one) and Forever's own vendor lists (ForeverVendors), the larger of
--               the two, since one vendor can sit in both and nothing ties them together (brief IC1,
--               the owner's ruling "3B": Forever's own counts the player records' and the item
--               claims' vendors too where they stand widely spread, Keep.WideVendorCount). A
--               limited stock vendor (the Era row's k) is not counted; nothing in either table
--               marks a reputation vendor. The price is the item row's buy price (bp), which the
--               pipeline ships; an item with none is judged on the vendor count alone. Brief SE1
--               (the owner's ruling A of 2026-10-20, QA item 301): the price judged is ONE item's,
--               the buy price divided by the bundle a vendor sells (the row's vs): Jagged Arrow's
--               10s buys 200, so 5c each.
--   Professions a recipe use counts whoever's profession it is (a reagent for another profession
--               is still sale value), but the line names the profession and draws one the
--               player lacks in grey, the player's own listed first. The client side reads
--               the professions (GetProfessions) and hands the scorer a set of skill line ids.
--   Quests      a quest use whose quest the player has completed does not count at all. The
--               scorer takes a completed(questId) predicate; the client side asks
--               C_QuestLog.IsQuestFlaggedCompleted once per quest and remembers the answer.
--
-- Brief K9 added auction value: an item an installed auction addon (Auctionator, Auctioneer or
-- TSM, read through Core/Prices.lua, never our own scan) prices at the Keep value or more
-- (keepValueCopper, 100 gold by default, 0 off) is marked whatever its uses, takes the ramp's top
-- tier, carries valuable = true for the bags' orange look, and its line leads with the value.
-- The player's Never and Off still win, and "sold everywhere" no longer unmarks it. Brief K19:
-- where no auction addon has a price, the item's vendor sell price stands in, so the Keep value
-- works with none installed; the line then reads "sells for 1s 40c at a vendor".
--
-- Brief PR4 (owner rulings 2026-09-30): with the Professions tab on and its module loaded, a
-- reagent (or teaching item) the player's profession route still needs is worth keeping, even when
-- sold everywhere. It only ever turns a not keep into a keep, and the player's own word still wins.
-- With the tab off, or the module not loaded, nothing here changes.
--
-- Brief K18 (owner QA 2026-10-02): the Keep block is the one list of an item's uses, so the
-- tooltip no longer says "Used in N recipes" above it. Where the route line is drawn the list is
-- the whole list, the route's own profession and the recipes below the player's level included;
-- and the recipes no profession names read their shipped name ("Replace Supplies") or "N other
-- recipes", never a bare "1 recipe".
--
-- Brief TBR (a tester's feedback, 2026-10-04) refined it four ways:
--
--   TB2   one current recipe use, where the player's professions are known, always says
--         something: a recipe of the player's own profession (Cooking, First Aid and Fishing
--         included) keeps the item and marks it, a recipe of a profession the player lacks reads
--         "No need to keep" over its profession, muted (Keep.SingleRecipe).
--   TB4   a quest the player has completed or abandoned is done: an item whose quest uses are
--         all done reads "No need to keep" with "Quest done" or "Quest abandoned". The client has
--         no abandoned flag, so a quest that leaves the log (QUEST_REMOVED) without a turn in is
--         remembered per character (ItemTreeCharDB.keepAbandoned, quest ids only) until it is taken
--         again or found completed. No quest row the addon counts states a class or race mask, so
--         only the side judges whether a quest is open to the player.
--   TB9   a chained use: a recipe whose product another recipe uses reaches that recipe's
--         profession, one level down and capped (Keep.ChainedUses). A chain that ends in one of
--         the player's professions marks the item; one that does not is listed, muted.
--   TB10  a class locked consumable (a consumable whose class mask names some classes) has a
--         use of its own, kind "class": current and marked for those classes, "For Mages" for any
--         other, and nothing at all while the player's class is not known (Keep.ClassUse).
--
-- Brief K20-wire (design K20 sections 1 to 3; the owner confirms the assumptions Q5 and Q6) wires
-- Core/Gear.lua and Core/DisenchantValue.lua into the verdict: an item level upgrade the player can
-- wear now or within BEHIND levels is a Keep, with a gear line under every state; with Enchanting
-- at the item's (stand-in) rank, Keep (disenchant) where a likely result is itself a Keep for the
-- player, and Disenchant (Sell AH) where the disenchant sum after the cut beats the other sales.
--
-- Brief TB12 (owner 2026-10-05, a repeatable reputation turn in with no Keep mark): a current quest
-- use marks the item on its own, whatever its level and however many other uses it has. The head is
-- "Keep" with "1 quest" under it, and the quests done or abandoned (TB4) under that. A quest for
-- the other side is no use at all (brief QS1; with "Hide other faction data" off, brief F155, it is
-- stale again). The single use neutral case is left to lock uses.
--
-- Brief K22 (owner 2026-10-05, Rough Stone on a leatherworker): where the player's professions are
-- known, a current recipe of a profession the player lacks no longer counts towards the mark (not
-- towards two or more, an endgame use, or one use at OWN_LEVEL); the mark reads the player's own
-- count (Keep.Counted), and an item kept only by others' recipes reads "No need to keep" over the
-- same lines. An item combine with a via item (a crate whose use takes the item) counts, and marks
-- the item on its own, only while the via item is in the bags; otherwise its line ("Waylaid
-- Supplies: Rough Stone needs 10") is muted and counts for nothing.
--
-- Brief K24h (tester QA 2026-10-07, screenshots of a level 1 to 5 character): gear of EVERY quality
-- is held against what is worn (Keep.EQUIPMENT_QUALITY 0), body armour by its kind as well as its
-- level (Core/Gear.lua), an empty slot is an upgrade, an upgrade the player can wear today is the
-- [Equip] tag (Keep.TAG_EQUIP, a Keep tag by look), the comparison tooltip's worn item says
-- "Better gear available", and food or drink for the player's level is a soft keep.
--
-- Brief K27 (owner 2026-10-08, "a true gear upgrade by stats and the player's spec"): the gear
-- compare is handed the player's class, so Core/Gear.lua weighs the stats (equip effects' too) for
-- every spec of that class and names the specs the item upgrades. An upgrade for ANY spec is a
-- Keep (and the Equip tag where wearable today), so a piece is never sold out from under the spec
-- the player is in; the line names the specs ("Upgrade for your Chest (Holy)"), plain for
-- every spec. Not an upgrade for any spec falls through to the sale as before. The owner's per
-- character setting turns specs off (Keep.SetSpecEnabled, the Settings rows of UI/Options.lua):
-- only the enabled specs are scored, so the Keep, the Equip tag, the line and "Better gear
-- available" all follow them, and the score cache's key carries the enabled set. Brief ST3 (QA item
-- 320, the owner's ruling A: "unticked means off"): every spec unticked turns gear suggestions off
-- (Keep.GearOff): no gear facts, so a weapon or armour piece is judged like any other item (its
-- sale), never kept or marked as an upgrade; until then it counted as every spec ticked.
--
-- Brief BQ6 (the owner's QA backlog of 2026-10-09 and 10-10; Jettison implements the same rules):
--   5   a consumable whose required skill is one of the professions (a lure, Aquadynamic Fish
--       Attractor at Fishing 100; an engineer's device) is a soft keep while the player has that
--       skill at its rank, whatever its level ("For your Fishing", Keep.ProfessionUseWords); and an
--       item vendors sell mostly in limited stock (the Era rows' stock, Keep.EraVendorCount's second
--       answer, at least as many as the free vendors: Keep.LimitedStock) is never "sold everywhere"
--       (score.limited).
--   15  the owner's answer of 2026-10-10: soulbound gear (binds when picked up, so never for the
--       auction house) that the class can use but not yet, its required level beyond the gear window
--       (Keep.GearWithin), and that carries a Use effect or a special Equip effect (a spell, not plain
--       stats: Keep.SpecialEffect) is a Keep, "Keep for level 36" (gear.later, Keep.GearLater). No
--       quality gate and no item list.
local _, ItemTree = ...

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local Keep = {}
ItemTree.Keep = Keep

local EMPTY = {}

Keep.ENDGAME = 50
Keep.BEHIND = 10
Keep.OWN_LEVEL = 45
-- The recipe skill rank to level proxy: rank 300 reads as level 60.
Keep.RANK_PER_LEVEL = 5

-- Brief K1: sold by at least this many vendors, for this many copper or less (five silver), and an
-- item is neutral whatever its uses.
Keep.EVERYWHERE_VENDORS = 5
Keep.CHEAP_COPPER = 500

Keep.ALLIANCE = 1
Keep.HORDE = 2
Keep.BOTH = 3

-- The kind each counted edge type is filed under, by the type's key in Edges.Types.
Keep.USE_KINDS = {
  REAGENT_FOR = "recipe",
  USED_BY_SPELL = "recipe",
  TOOL_FOR = "recipe",
  TEACHES = "recipe",
  OPENS = "lock",
  QUEST_OBJECTIVE = "quest",
  STARTS_QUEST = "quest",
  REAGENT_FOR_SPELL = "spell",
  -- Brief TB10: a class locked consumable's own use, derived from its item row (Keep.ClassUse).
  -- No edge type carries this name, so kindOfType never files an edge under it.
  DERIVED_CLASS_USE = "class",
}

-- The confidences that never count: a guess is not a fact. Brief RB1 (the owner's standing rule of
-- 2026-10-17, "Predicted IS our data until we can find a better source ... it should show in the
-- tooltips"): Predicted is no longer here. Before RB1 a Predicted edge never counted but for GF6's
-- predicted quest objectives, so a Classic Era quest the Forever client does not list (Runecloth's
-- nine Predicted rows) was in no count. Such a quest now counts like a listed one, by every rule a
-- listed one meets (side, level, class, quantity, events and turn ins: Keep.Uses, Keep.IsCurrent).
-- A disenchant result, the other Predicted edge an item walks down to, is no use kind at all.
local NOT_COUNTED = { guess = true }

-- Brief GF6 (the owner's ruling of 2026-10-14, "Turn it on"): the field a predicted quest objective
-- carries (Core/QuestsPredicted.lua OBJECTIVE_MARK: a new Forever quest that asks for the item). Brief
-- RB1: every Predicted edge counts now; the mark only says which needs rest on the gap fill's
-- predicted facts alone (use.predicted, the internal note ScoreUses keeps as questsPredicted).
Keep.PREDICTED_NEED_MARK = "predictedObjective"

-- Brief GF6: whether an edge is a predicted quest objective: Predicted, a QUEST_OBJECTIVE, carrying
-- Keep.PREDICTED_NEED_MARK, and no Classic Era row. Pure.
function Keep.PredictedNeed(edge)
  if type(edge) ~= "table" or edge.confidence ~= "predicted" or edge[Keep.PREDICTED_NEED_MARK] ~= true then
    return false
  end
  local def = edge.type
  return type(def) == "table" and def.name == "QUEST_OBJECTIVE" and not edge.historical and edge.guess == nil
end

-- Brief GF6: whether an edge's confidence lets it count as a use: no guess. Brief RB1: a Predicted
-- edge counts (NOT_COUNTED). Core/API.lua's UseTypes asks the same. Pure.
function Keep.CountsEdge(edge)
  if type(edge) ~= "table" or edge.guess then
    return false
  end
  return not NOT_COUNTED[edge.confidence]
end

-- Brief Q1: the walk Keep.Uses reads an item's uses with. The Classic Era quest rows are history
-- (Core/EraSources.lua), so they are asked for; the ones whose quest the Forever client lists are
-- the baseline tier, the rest Predicted, and brief RB1 counts both (Keep.CountsEdge). Core/API.lua's
-- UseTypes walks the same way.
Keep.USES_WALK = { includeHistorical = true }

local kindById
local function kindOfType(edgeType)
  if type(edgeType) ~= "table" then
    return nil
  end
  if not kindById then
    kindById = {}
    local types = ItemTree.Edges and ItemTree.Edges.Types or EMPTY
    for name, kind in pairs(Keep.USE_KINDS) do
      local def = types[name]
      if type(def) == "table" and def.id then
        kindById[def.id] = kind
      end
    end
  end
  return kindById[edgeType.id]
end

local function whole(value)
  local number = tonumber(value)
  if number == nil or number <= 0 then
    return nil
  end
  return math.floor(number)
end

local function data()
  local d = ItemTree.Data
  if type(d) == "table" then
    return d
  end
  return nil
end

-- Brief BQ13: the demo state (Core/Demo.lua), or nil where it is not loaded (a spec, a persona).
-- Every reader of the pretend facts asks it first: Keep.EnabledSpecs, Keep.QuestCompleted,
-- Keep.QuestAbandoned and the held counts (Keep.DemoHave).
local function demoState()
  local demo = ItemTree.Demo
  if type(demo) == "table" then
    return demo
  end
  return nil
end

local function itemRow(itemId)
  local d = data()
  if not d or type(d.GetItem) ~= "function" then
    return nil
  end
  local ok, item = pcall(d.GetItem, d, itemId)
  if ok and type(item) == "table" then
    return item
  end
  return nil
end

-- The level of a recipe: what its output needs to wear, else its rank as a level. Pure over the
-- data tables.
function Keep.RecipeLevel(spellId)
  local d = data()
  if not d or type(d.GetRecipe) ~= "function" or type(spellId) ~= "number" then
    return nil
  end
  local ok, recipe = pcall(d.GetRecipe, d, spellId)
  if not ok or type(recipe) ~= "table" then
    return nil
  end
  local out = type(recipe.out) == "table" and recipe.out[1] or nil
  local made = type(out) == "number" and itemRow(out) or nil
  local level = made and whole(made.rl) or nil
  if level then
    return level
  end
  local rank = whole(recipe.r)
  if rank then
    return math.ceil(rank / Keep.RANK_PER_LEVEL)
  end
  return nil
end

-- Brief K1: the skill line of a recipe (its sl), or nil for an item combine or a spell the tables
-- do not hold. Pure over the data tables.
function Keep.RecipeSkill(spellId)
  local d = data()
  if not d or type(d.GetRecipe) ~= "function" or type(spellId) ~= "number" then
    return nil
  end
  local ok, recipe = pcall(d.GetRecipe, d, spellId)
  if not ok or type(recipe) ~= "table" then
    return nil
  end
  return whole(recipe.sl)
end

-- Brief K18: the name a recipe goes by in the shipped tables, its row's n (an item combine such as
-- Season of Discovery's "Replace Supplies" carries one), else the shipped SpellNames module, else
-- nil. Never a client call. Pure over the data tables.
function Keep.RecipeName(spellId)
  local d = data()
  if not d or type(spellId) ~= "number" then
    return nil
  end
  if type(d.GetRecipe) == "function" then
    local ok, recipe = pcall(d.GetRecipe, d, spellId)
    if ok and type(recipe) == "table" and type(recipe.n) == "string" and recipe.n ~= "" then
      return recipe.n
    end
  end
  if type(d.Get) == "function" then
    local ok, names = pcall(d.Get, d, "SpellNames")
    local name = ok and type(names) == "table" and names[spellId] or nil
    if type(name) == "string" and name ~= "" then
      return name
    end
  end
  return nil
end

-- The level of one use edge, or nil where the tables do not say.
function Keep.UseLevel(edge)
  if type(edge) ~= "table" then
    return nil
  end
  local stated = whole(edge.level)
  if stated then
    return stated
  end
  local Graph = ItemTree.Graph
  local kind, id
  if Graph and type(Graph.Parse) == "function" and type(edge.target) == "string" then
    kind, id = Graph.Parse(edge.target)
  end
  if kind == "spell" then
    return Keep.RecipeLevel(tonumber(id))
  end
  if kind == "item" then
    local item = itemRow(tonumber(id))
    return item and whole(item.rl) or nil
  end
  return nil
end

-- Brief K22: the items whose use casts an item combine, other than the item itself, as a list of
-- ids, or nil for a spell that is not a combine (Graph.IsCombine), a combine the build states no
-- via item for, and the via item's own combine. Ids straight off the recipe row's via, the list
-- Graph.CombineVia names; no name is looked up here. Pure over the data tables.
function Keep.CombineVia(spellId, itemId)
  local Graph = ItemTree.Graph
  local d = data()
  if type(spellId) ~= "number" or not d or type(d.GetRecipe) ~= "function" then
    return nil
  end
  if type(Graph) ~= "table" or type(Graph.IsCombine) ~= "function" then
    return nil
  end
  local ok, recipe = pcall(d.GetRecipe, d, spellId)
  if not ok or type(recipe) ~= "table" or type(recipe.via) ~= "table" then
    return nil
  end
  local isCombine, combine = pcall(Graph.IsCombine, recipe)
  if not isCombine or not combine then
    return nil
  end
  local out, seen = {}, {}
  for _, via in ipairs(recipe.via) do
    via = tonumber(via)
    if via and via ~= tonumber(itemId) and not seen[via] then
      seen[via] = true
      out[#out + 1] = via
    end
  end
  if #out == 0 then
    return nil
  end
  return out
end

-- Brief UL2 (QA item 366, the owner on Refreshing Spring Water: Snowmaster 9000 "is a toy whose use turns
-- the water into snowballs. It is not a supply crate"): whether an item combine is a supply crate, the
-- Waylaid Supplies kind: its via item and what it makes are both Trade Goods of the Other subclass
-- (Keep.CRATE_CLASS, Keep.CRATE_SUBCLASS: a crate filled into a Supply Shipment), read off the shipped item
-- rows. A toy, a key half or a weapon's other half is no crate. false for any other spell. Pure over the
-- data tables.
Keep.CRATE_CLASS = 7
Keep.CRATE_SUBCLASS = 11
function Keep.CombineCrate(spellId)
  local d = data()
  if type(spellId) ~= "number" or not d or type(d.GetRecipe) ~= "function" then
    return false
  end
  local ok, recipe = pcall(d.GetRecipe, d, spellId)
  if not ok or type(recipe) ~= "table" or type(recipe.via) ~= "table" or type(recipe.out) ~= "table" then
    return false
  end
  local function crateRow(itemId)
    local row = itemRow(tonumber(itemId))
    return type(row) == "table" and tonumber(row.c) == Keep.CRATE_CLASS and tonumber(row.sc) == Keep.CRATE_SUBCLASS
  end
  return crateRow(recipe.via[1]) and crateRow(recipe.out[1]) or false
end

-- The item's uses: { { kind = "recipe" | "quest" | "lock" | "spell", target = key, level = n or
-- nil, faction = 1 | 2 | 3 or nil, classId = n on a spell, skill = the recipe's skill line on a
-- recipe whose spell the tables hold, name = the shipped name of a recipe no profession names
-- (brief K18, Keep.RecipeName), questId = n on a quest } }, one per target, in the graph's own
-- order, then (brief TB10) the item's own class use where Keep.ClassUse derives one. Brief K22: an
-- item combine with a via item also carries via = { itemId, ... } (Keep.CombineVia) and quantity,
-- how many of this item it takes.
--
-- Brief Q1 (the owner's rulings of 2026-10-09): the Classic Era quests the Forever client lists
-- count (Keep.USES_WALK); a quest that never keeps an item (Keep.QuestNeverKeeps: an event quest or
-- a reputation turn in) is no use at all, whoever states it; a quest use carries quantity, how
-- many of the item it asks for (nil where its edge states none; 1 for a quest the item starts),
-- and, where its edge states no side, the side the listing gives it (Core/QuestFlags.lua Side).
-- Brief GF6: a predicted quest objective counts too (Keep.CountsEdge), its use marked predicted =
-- true; a record of ours of the same quest need wins the graph's merge and carries no mark.
-- Brief RB1: so does a Classic quest the client does not list, by the same rules, but for an
-- unjudged one (Keep.EraQuestUnjudged: the shipped turn ins cannot say whether it is a repeat yet).
function Keep.Uses(itemId)
  local uses = Keep.UsesAndRepeats(itemId)
  return uses
end

-- Brief RB1b (the owner's answer of 2026-10-17 on item 190, "B but make repeatable quests never
-- relevant (so always collapsed)"): Keep.Uses' list, and beside it the needs of the repeatable quests
-- it leaves out (Keep.QuestRepeat: a reputation turn in, no event's), each marked as a quest use is
-- (Keep.MarkQuestUse), never a use: they never keep or lock an item; Keep.Score counts them for the
-- tooltip's folded line alone (score.questsRepeat, Keep.RepeatCount). Two lists, both fresh.
-- Brief RB1c (the owner's ruling "A" of 2026-10-17): a third list, the needs and starts of the quests an
-- instance holds back for this character (Keep.QuestHeldBack: Naxxramas's tier 3 quests until the
-- character has been inside), each marked as a quest use is and given its gate (use.gate); never a use
-- either, counted by Keep.Score for the tooltip's folded line (score.questsGated). A repeatable quest
-- is a repeat first.
-- Brief QX1 (the owner, 2026-10-22: quest items you no longer need): a fourth list, the quest needs
-- Keep.Uses leaves out that are neither a repeat nor held back (an event quest's, an unjudged Classic
-- quest's), each marked as a quest use is. Never a use and in no count: Keep.QuestFinished alone reads
-- it, since a quest that can come round again (or one the data cannot judge) is no proof the item is
-- done with.
function Keep.UsesAndRepeats(itemId)
  local Graph = ItemTree.Graph
  local id = tonumber(itemId)
  if not id or not Graph or type(Graph.Children) ~= "function" then
    return {}, {}, {}, {}
  end
  local ok, edges = pcall(Graph.Children, Graph.Key("item", id), "down", Keep.USES_WALK)
  if not ok or type(edges) ~= "table" then
    return {}, {}, {}, {}
  end
  local uses, seen, repeats, gated, others = {}, {}, {}, {}, {}
  for _, edge in ipairs(edges) do
    local kind = kindOfType(edge.type)
    if kind and Keep.CountsEdge(edge) and not seen[edge.target] then
      seen[edge.target] = true
      local faction = tonumber(edge.faction)
      if faction ~= Keep.ALLIANCE and faction ~= Keep.HORDE and faction ~= Keep.BOTH then
        faction = nil
      end
      local use = { kind = kind, target = edge.target, faction = faction }
      if kind == "spell" then
        -- A class spell has no level: it is the player's for as long as they are that class.
        use.classId = tonumber(edge.classId) or 0
      else
        use.level = Keep.UseLevel(edge)
      end
      local targetKind, targetId
      if type(Graph.Parse) == "function" and type(edge.target) == "string" then
        targetKind, targetId = Graph.Parse(edge.target)
      end
      if kind == "recipe" and targetKind == "spell" then
        use.skill = Keep.RecipeSkill(tonumber(targetId))
        -- Brief TV1 (QA item 347 D1, INV1's trace): the recipe a recipe item teaches is no reagent
        -- use: marked, so it never enters the route's count (Keep.TradeUse) nor the mark (Keep.OwnUse,
        -- Keep.SingleRecipe); the recipe item's own facts (Keep.RecipeFacts) decide its verdict.
        if type(edge.type) == "table" and edge.type.name == "TEACHES" then
          use.teaches = true
        end
        if use.skill == nil then
          use.name = Keep.RecipeName(tonumber(targetId))
          -- Brief K22: an item combine another item's use casts, judged by whether it is carried.
          use.via = Keep.CombineVia(tonumber(targetId), id)
          if use.via then
            use.quantity = whole(edge.quantity) or 1
            -- Brief UL2 (QA item 366): whether it is a supply crate (Keep.CombineCrate).
            use.crate = Keep.CombineCrate(tonumber(targetId)) or nil
          end
        end
      elseif kind == "quest" and targetKind == "quest" then
        use.questId = tonumber(targetId)
        Keep.MarkQuestUse(use, edge)
        -- Brief GF6: a need of a new Forever quest that rests on the predicted facts alone, judged as
        -- any other. The owner's ruling of 2026-10-14 ("Remove the predicted text ... just keep the
        -- note internal"): its lines carry no mark; ScoreUses counts it (questsPredicted) for the self
        -- test and the debug output alone.
        if Keep.PredictedNeed(edge) then
          use.predicted = true
        end
      end
      -- Brief Q1: a need of a quest that never keeps an item is no use at all; an item that starts
      -- one still is (the owner's ruling 4: a Darkmoon deck), judged by Keep.IsCurrent. Brief RB1:
      -- nor, yet, a need of an unlisted quest the data cannot judge (Keep.EraQuestUnjudged).
      local neverKeeps = use.kind == "quest"
        and not use.start
        and (Keep.QuestNeverKeeps(use.questId) or Keep.EraQuestUnjudged(edge))
      -- Brief RB1c: a quest an instance holds back is no use yet, a need or a start alike.
      -- Brief WS1 (the owner's ruling "A for writs" of 2026-10-17 night): nor, a need alone, a quest an
      -- item starts while the character holds none of its starters and has not got it in the log
      -- (Core/QuestFlags.lua's STARTER_GATE); the starter's own start use is never held back by it.
      -- use.starterHeldBack keeps the starter's answer for such a quest (true or false), which Keep.Score
      -- watches (Keep.StarterWatch, Keep.RecheckStarters).
      local heldBack, starter = nil, nil
      if not neverKeeps and use.kind == "quest" then
        heldBack, starter = Keep.QuestHeldBack(use.questId, use.start or Keep.StartsQuest(id, use.questId))
      end
      if starter ~= nil then
        use.starterHeldBack = starter
      end
      if heldBack then
        use.gate = heldBack
        gated[#gated + 1] = use
      elseif not neverKeeps then
        uses[#uses + 1] = use
      elseif not Keep.EraQuestUnjudged(edge) and Keep.QuestRepeat(use.questId) then
        -- Brief RB1b: a repeatable quest's need, counted on the page and folded on the tooltip.
        repeats[#repeats + 1] = use
      elseif use.kind == "quest" then
        -- Brief QX1: an event quest's need or an unjudged one, for Keep.QuestFinished alone.
        others[#others + 1] = use
      end
    end
  end
  -- Brief IW1 (the owner's ruling 1B of 2026-10-22: "a provided item that is not a turn-in requirement
  -- keeps while its quest is in the log"): each quest our data says hands the item over
  -- (Keep.ProvidedQuests: the recorded hand-overs, brief NX1's Classic Era rows, then the predicted
  -- provided items) that no edge
  -- above names already (an item the quest also asks back is its objective, judged as before) is a
  -- quest use marked provided = true, its facts as any quest use's (Keep.MarkQuestUse: side, seen side,
  -- levels, classes; no count: the hand-over is no turn in requirement) and filed by the same gates:
  -- a quest that never keeps an item (a repeatable or event quest: repeats, folded, never keeping, or
  -- others), one an instance or a starter holds back (gated), else a use. Keep.ScoreUses counts it only
  -- while the quest is in the log (opts.onQuest), and Keep.QuestFinished clears it once the quest is
  -- done, as any quest item.
  for _, entry in ipairs(Keep.ProvidedQuests(id)) do
    local target = Graph.Key("quest", entry.questId)
    if not seen[target] then
      seen[target] = true
      local use = Keep.MarkQuestUse({ kind = "quest", target = target, questId = entry.questId, provided = true }, nil)
      local neverKeeps = Keep.QuestNeverKeeps(use.questId)
      local heldBack, starter = nil, nil
      if not neverKeeps then
        heldBack, starter = Keep.QuestHeldBack(use.questId, Keep.StartsQuest(id, use.questId))
      end
      if starter ~= nil then
        use.starterHeldBack = starter
      end
      if heldBack then
        use.gate = heldBack
        gated[#gated + 1] = use
      elseif not neverKeeps then
        uses[#uses + 1] = use
      elseif Keep.QuestRepeat(use.questId) then
        repeats[#repeats + 1] = use
      else
        others[#others + 1] = use
      end
    end
  end
  -- Brief TB10: a class locked consumable's own use, which no graph edge states.
  local classUse = Keep.ClassUse(id)
  if classUse then
    uses[#uses + 1] = classUse
  end
  return uses, repeats, gated, others
end

--------------------------------------------------------------------------------
-- Brief Q1 (the owner's rulings of 2026-10-09): quest needs keep an item only for quests the
-- character can still do. Keep.Uses leaves out a NEED of a quest that never keeps an item (an event
-- quest or a reputation turn in); an item that STARTS a quest is kept whatever the quest (ruling 4).
-- Keep.IsCurrent judges side (the edge's, else the listing's, Core/QuestFlags.lua Side) and grey
-- (Keep.QuestGrey: the player QUEST_GREY or more levels above the quest's level, the Classic Era
-- table's ql; brief QF2b: the predicted facts' Forever level first, Keep.QuestLevels); Keep.ScoreUses
-- sets a need whose minimum level is more than QUEST_AHEAD above the player's aside
-- (Keep.QuestOutOfReach: neither current nor stale) and skips a quest the player has completed
-- (Keep.QuestCompleted, one C_QuestLog.IsQuestFlaggedCompleted per quest) or abandoned.
-- Brief INT1b (the owner's ruling of 2026-10-10, Q(b)): a class quest (the Classic Era table's qa)
-- keeps an item only for a character of one of its classes; for any other class it is neither
-- current nor stale (Keep.QuestOtherClass), for a need and a start alike.
-- The count the open needs ask for is score.questNeed: the item is kept up to it, and the need
-- line (brief BQ16, Keep.QuestNeedWords) shows the player's count against it.
--------------------------------------------------------------------------------

-- Brief Q1 (the owner's ruling of 2026-10-09): a quest is grey for a player this many levels or more
-- above its level (ItemTree has no client grey rule of its own), and a need keeps only while the
-- quest's minimum level is at most this many above the player's (the consumables' window,
-- Core/Consumables.lua AHEAD).
Keep.QUEST_GREY = 10
Keep.QUEST_AHEAD = 10

-- A quest's level and minimum level from the Classic Era table's ql where it is built (never loads
-- the data addon for it), each nil where none is stated. Pure over the shipped table.
-- Brief GF6: field by field, a level the Classic Era table does not state is the predicted facts'
-- (Keep.PredictedQuestFacts: level, required level), so a new Forever quest's need is judged grey or
-- out of reach as any other.
-- Brief QF2b (the owner's "Yes to both" of 2026-10-24): the predicted facts FIRST, field by field, and
-- the Classic Era table's ql where they state nothing. The pipeline ships a predicted level for a Classic
-- quest only where Forever retuned it (the listing's level over a different Era one: Fiora Longears 1132,
-- 20 from 18 in Era, 30 from 30 in Forever) or Era states none, so a grey or out of reach need is judged
-- by the Forever level, as Jettison's own facts judge it (ItemTree-Data jettison_facts.fill_levels, the
-- qnl and qsl columns). No record of the player's states a quest's level here: the quest page reads the
-- client's own level first (Core/ViewModel.lua QuestFacts), and never ql.
function Keep.QuestLevels(questId)
  local level, minimum = nil, nil
  local facts = Keep.PredictedQuestFacts(questId)
  if facts then
    level, minimum = whole(facts.level), whole(facts.requiredLevel)
  end
  if level == nil or minimum == nil then
    local eraLevel, eraMinimum = Keep.EraQuestLevels(questId)
    level = level or eraLevel
    minimum = minimum or eraMinimum
  end
  return level, minimum
end

-- The Classic Era table's levels alone (Keep.QuestLevels before brief GF6). Pure over the table.
function Keep.EraQuestLevels(questId)
  local era = ItemTree.EraSources
  if type(era) ~= "table" or type(era.QuestLevels) ~= "function" or type(questId) ~= "number" then
    return nil, nil
  end
  local source = Keep.BuiltEraTable()
  if source == nil then
    return nil, nil
  end
  local ok, level, minimum = pcall(era.QuestLevels, source, questId)
  if not ok then
    return nil, nil
  end
  return level, minimum
end

-- Brief GF6: one quest's predicted facts (Core/QuestsPredicted.lua Facts: level, requiredLevel, side
-- and, the follow up, classes, each nil where unknown), only while the module is registered (never
-- loads ItemTree_Data for it), or nil. The module ships a fact only where nothing of ours states it;
-- brief QF2b: and a Classic quest's level and required level where Forever retuned it (Keep.QuestLevels).
-- Pure over the module.
function Keep.PredictedQuestFacts(questId)
  local predicted = ItemTree.QuestsPredicted
  if type(predicted) ~= "table" or type(predicted.Facts) ~= "function" or type(questId) ~= "number" then
    return nil
  end
  local ok, facts = pcall(predicted.Facts, questId, false)
  if ok and type(facts) == "table" then
    return facts
  end
  return nil
end

-- Puts brief Q1's quest facts on one quest use made from edge: quantity (Keep.QuestQuantity),
-- start (true for a quest the item starts), the listing's side where the edge states none
-- (Keep.QuestSide), questLevel and minLevel (Keep.QuestLevels; apart from use.level, which the
-- brackets and the endgame test read). Brief INT1b: questClasses, the class mask of a class quest
-- (Keep.QuestClasses), nil for a quest every class can do. Answers use. Pure over the shipped tables.
function Keep.MarkQuestUse(use, edge)
  use.quantity = Keep.QuestQuantity(edge)
  local def = type(edge) == "table" and edge.type or nil
  if type(def) == "table" and def.name == "STARTS_QUEST" then
    use.start = true
  end
  -- Brief HF1 of 2026-10-23 (QA item 406): the edge's side gives way to the shipped lists wherever
  -- they speak for the quest (Keep.ListsSpeakFor), as Core/Graph.lua Graph.QuestSide reads it, so a
  -- quest they open to both, leaning or not, is judged as usual on either side.
  -- Brief AT2 of 2026-10-24: whether the edge stated a side is kept for the seen side below.
  local stated = use.faction ~= nil
  if stated and Keep.ListsSpeakFor(use.questId) then
    use.faction = nil
  end
  if use.faction == nil then
    use.faction = Keep.QuestSide(use.questId)
  end
  -- Brief QS2b: a quest nothing sides keeps the side players were seen taking it on, apart from its
  -- faction, so it counts for that side only and is never hidden or worded as the other side's.
  -- Brief AT2: "nothing sides" includes the edge (the owner's QS2b ruling of 2026-10-14): an edge that
  -- stated a side, 3 (both) among them, reads no seen side, even where HF1 gave its faction to the lists.
  if use.faction == nil and not stated then
    use.seenSide = Keep.QuestSeenSide(use.questId)
  end
  use.questLevel, use.minLevel = Keep.QuestLevels(use.questId)
  use.questClasses = Keep.QuestClasses(use.questId)
  -- Brief IW1 (the owner's ruling "B" of 2026-10-22): a repeatable helper quest's parent (Keep.QuestHelperParent).
  use.helperOf = Keep.QuestHelperParent(use.questId)
  return use
end

-- Brief IW1 (the owner's ruling "B" of 2026-10-22): the parent of a repeatable helper quest, one that can
-- only be taken while its parent is in the log (the Classic Era table's qw, CMaNGOS PrevQuestId below 0:
-- Filling the Soul Gem 593 -> Saving Yenniku 592), or nil. Keep.QuestFinished judges such a quest as part
-- of its parent: it blocks only while the parent would. Pure over the shipped table (never loads it).
-- Brief IW1: a stand in a spec or a persona case sets for the helpers' parents, { [questId] = parent
-- questId }, read before the shipped table (the data in a tree may predate qw); nil on the client.
Keep.helperParents = nil

function Keep.QuestHelperParent(questId)
  local stand = Keep.helperParents
  if type(questId) == "number" and type(stand) == "table" and tonumber(stand[questId]) then
    return tonumber(stand[questId])
  end
  local era = ItemTree.EraSources
  if type(questId) ~= "number" or type(era) ~= "table" or type(era.QuestHelperParent) ~= "function" then
    return nil
  end
  local source = Keep.BuiltEraTable()
  if source == nil then
    return nil
  end
  local ok, parent = pcall(era.QuestHelperParent, source, questId)
  if ok and type(parent) == "number" then
    return parent
  end
  return nil
end

-- Brief PL1 (the owner's ruling "B" of 2026-10-22, the Classic Era prerequisite links): the quests that
-- come after a quest, out of the Classic Era table's qo (Core/EraSources.lua QuestNextSteps: CMaNGOS
-- quest_template.PrevQuestId naming the quest, or its own NextQuestId / NextQuestInChain, each above 0;
-- since brief NX2 also a quest whose RequiredCondition asks for it rewarded, and its BreadcrumbForQuestId),
-- read only where the table is built (Keep.BuiltEraTable, as the quest's level is). { questId, ... }, the
-- quest itself never among them, empty where none ships. Pure over the shipped table (never loads it).
-- Brief PL1: a stand in a spec or a persona case sets for the later quests, { [questId] = { later
-- questId, ... } }, read before the shipped table (the data in a tree may predate qo); nil on the client.
Keep.nextSteps = nil

function Keep.QuestNextSteps(questId)
  local out = {}
  if type(questId) ~= "number" then
    return out
  end
  local stand = Keep.nextSteps
  if type(stand) == "table" and type(stand[questId]) == "table" then
    for _, later in ipairs(stand[questId]) do
      if tonumber(later) and tonumber(later) ~= questId then
        out[#out + 1] = tonumber(later)
      end
    end
    return out
  end
  local era = ItemTree.EraSources
  local source = Keep.BuiltEraTable()
  if source == nil or type(era) ~= "table" or type(era.QuestNextSteps) ~= "function" then
    return out
  end
  local ok, steps = pcall(era.QuestNextSteps, source, questId)
  return ok and type(steps) == "table" and steps or out
end

-- Brief INT1b (the owner's ruling of 2026-10-10, Q(b)): the class mask of a class quest from the
-- Classic Era table's qa where it is built (never loads the data addon for it, as Keep.QuestLevels),
-- or nil for a quest every class can do. Pure over the shipped table. Brief QB2: the client's quest
-- cache is asked first (Core/QuestFlags.lua Classes, Diff.quests.classes), and its answer wins.
-- Brief GF6's follow up: last, the predicted facts' mask of a new class quest (Keep.PredictedQuestFacts,
-- never loading the data addon), which the pipeline ships only where neither of ours states one.
function Keep.QuestClasses(questId)
  local flags = ItemTree.QuestFlags
  if type(flags) == "table" and type(flags.Classes) == "function" then
    local okFlags, forever = pcall(flags.Classes, questId)
    if okFlags and type(forever) == "number" and forever > 0 then
      return forever
    end
  end
  local era = ItemTree.EraSources
  local source = Keep.BuiltEraTable()
  if type(era) == "table" and type(era.QuestClasses) == "function" and type(questId) == "number" and source then
    local ok, mask = pcall(era.QuestClasses, source, questId)
    if ok and type(mask) == "number" and mask > 0 then
      return mask
    end
  end
  local facts = Keep.PredictedQuestFacts(questId)
  local predicted = facts and tonumber(facts.classes) or nil
  if predicted and predicted > 0 then
    return predicted
  end
  return nil
end

-- Brief INT1b (the owner's ruling of 2026-10-10, Q(b)): whether a quest use is a class quest for
-- other classes than the player's: a class restricted quest keeps an item only for a character of
-- one of its classes. false for a quest every class can do and while the player's class is not
-- known (taken at nothing, as Keep.OtherClass takes a class spell). Pure.
function Keep.QuestOtherClass(use, playerClass)
  if type(use) ~= "table" or use.kind ~= "quest" then
    return false
  end
  local mask = tonumber(use.questClasses)
  local player = tonumber(playerClass)
  if mask == nil or mask <= 0 or player == nil then
    return false
  end
  return not Keep.MaskHasClass(mask, player)
end

-- Whether a quest use is grey for the player: its quest's level is known and the player is
-- QUEST_GREY or more levels above it. false where either level is not known. Pure.
function Keep.QuestGrey(use, playerLevel)
  local level = type(use) == "table" and tonumber(use.questLevel) or nil
  local player = tonumber(playerLevel)
  if level == nil or level <= 0 or player == nil then
    return false
  end
  return player >= level + Keep.QUEST_GREY
end

-- Whether a quest NEED is out of the player's reach: its minimum level is more than QUEST_AHEAD
-- above the player's. A start item is never out of reach (the owner's ruling 4). false where either
-- level is not known. Pure.
function Keep.QuestOutOfReach(use, playerLevel)
  if type(use) ~= "table" or use.kind ~= "quest" or use.start then
    return false
  end
  local minimum = tonumber(use.minLevel)
  local player = tonumber(playerLevel)
  if minimum == nil or player == nil then
    return false
  end
  return minimum > player + Keep.QUEST_AHEAD
end

-- Brief BQ9: whether a current quest use (Keep.IsCurrent passed: the side, the class, not grey, not
-- done, the caller's test) is a quest the item starts that the character can accept now: no event
-- or turn in quest (Keep.QuestNeverKeeps), and its minimum level, where the table states one,
-- reached. Pure over the shipped tables.
function Keep.StartsNow(use, playerLevel)
  if type(use) ~= "table" or use.kind ~= "quest" or not use.start or type(use.questId) ~= "number" then
    return false
  end
  if Keep.QuestNeverKeeps(use.questId) then
    return false
  end
  local minimum, player = tonumber(use.minLevel), tonumber(playerLevel)
  if minimum ~= nil and (player == nil or minimum > player) then
    return false
  end
  return true
end

-- How many of the item a quest use asks for: the quantity its QUEST_OBJECTIVE edge states, 1 for
-- a quest the item starts, nil where an objective states none (a quest log objective seen with no
-- count). Pure.
function Keep.QuestQuantity(edge)
  if type(edge) ~= "table" then
    return nil
  end
  local def = edge.type
  if type(def) == "table" and def.name == "STARTS_QUEST" then
    return 1
  end
  return whole(edge.quantity)
end

-- The side the shipped listing gives a Classic quest (1 Alliance, 2 Horde), or nil. Pure over the
-- core data (Diff.quests). Brief GF6: where the listing states none, the predicted facts' side
-- (Keep.PredictedQuestFacts: 1 Alliance, 2 Horde; 3 both answers nil, a quest for either side).
function Keep.QuestSide(questId)
  if type(questId) ~= "number" then
    return nil
  end
  local flags = ItemTree.QuestFlags
  if type(flags) == "table" and type(flags.Side) == "function" then
    local ok, side = pcall(flags.Side, questId)
    if ok and (side == Keep.ALLIANCE or side == Keep.HORDE) then
      return side
    end
  end
  local facts = Keep.PredictedQuestFacts(questId)
  local side = facts and tonumber(facts.side) or nil
  if side == Keep.ALLIANCE or side == Keep.HORDE then
    return side
  end
  return nil
end

-- Brief HF1 (item 406): whether the shipped quest lists speak for one quest's side (Core/QuestFlags.lua
-- SpeaksFor): false for no id and no lists. Pure over the core data.
function Keep.ListsSpeakFor(questId)
  local flags = ItemTree.QuestFlags
  if type(flags) ~= "table" or type(flags.SpeaksFor) ~= "function" or type(questId) ~= "number" then
    return false
  end
  local ok, speaks = pcall(flags.SpeaksFor, questId)
  return ok and speaks == true
end

-- Brief QS2b (QS2's rule 2): the one side players were seen taking a quest on (1 Alliance, 2 Horde)
-- where nothing else sides it, or nil. Pure over the core data (Diff.quests' seenAlliance and
-- seenHorde, Core/QuestFlags.lua SeenSide).
function Keep.QuestSeenSide(questId)
  local flags = ItemTree.QuestFlags
  if type(flags) ~= "table" or type(flags.SeenSide) ~= "function" or type(questId) ~= "number" then
    return nil
  end
  local ok, side = pcall(flags.SeenSide, questId)
  if ok and (side == Keep.ALLIANCE or side == Keep.HORDE) then
    return side
  end
  return nil
end

-- The Classic Era table where it is already built, or nil: never loads the data addon for this
-- question (Keep.eraSource stands one in for a spec). Its quest rows only reach a score once it is
-- built, so a quest it alone knows is never judged without it.
function Keep.BuiltEraTable()
  if type(Keep.eraSource) == "table" then
    return Keep.eraSource
  end
  local d = data()
  local cache = d and type(d.cache) == "table" and d.cache or nil
  local held = cache and cache.EraSources or nil
  if type(held) == "table" then
    return held
  end
  return nil
end

-- Whether a quest never keeps an item, whatever states the need (the owner's rulings B and C): a
-- quest tied to a game event (the AQ War Effort, a holiday: the Classic Era table's qe) or a
-- reputation turn in (a cloth donation and the like: Core/QuestFlags.lua IsTurnIn). Pure over the
-- shipped tables.
-- The owner's ruling of 2026-10-10 (Wool Cloth on a level 15 warrior, A Donation of Wool, quest
-- 7791): the FIRST hand in of a reputation quest that gives experience keeps the item up to its
-- count, like any other quest need; only the repeats are excluded ("probably better done early for
-- the XP and it unlocks the other donation quests"), and (feedback item 47, Q6) "Keep all 4" open
-- capital donations. Brief BQ25a: the pipeline's u1 round closed the data gap: Diff.quests.turnIns
-- (era_sources.is_turn_in) now lists the repeatable quests alone, so every quest in that listing is
-- a repeat and is left out here, and the one time donations are ordinary needs.
function Keep.QuestNeverKeeps(questId)
  if type(questId) ~= "number" then
    return false
  end
  local flags = ItemTree.QuestFlags
  if type(flags) == "table" and type(flags.IsTurnIn) == "function" then
    local ok, turnIn = pcall(flags.IsTurnIn, questId)
    if ok and turnIn == true then
      return true
    end
  end
  local era = ItemTree.EraSources
  if type(era) == "table" and type(era.QuestEvent) == "function" then
    local ok, event = pcall(era.QuestEvent, Keep.BuiltEraTable(), questId)
    if ok and event ~= nil then
      return true
    end
  end
  return false
end

-- Brief RB1b (the owner's answer of 2026-10-17 on item 190): whether a quest is a repeatable quest, a
-- reputation turn in (Core/QuestFlags.lua IsTurnIn, listed or not since RB1's pipeline change) that is
-- no game event's (an event quest stays out of every count, as before). Such a quest never keeps an
-- item (Keep.QuestNeverKeeps, the owner's rulings of 2026-10-09 and 10) but counts on the item page and
-- folds on the tooltip ("9 repeatable quests" under the modifier). Pure over the shipped tables.
function Keep.QuestRepeat(questId)
  if type(questId) ~= "number" then
    return false
  end
  local flags = ItemTree.QuestFlags
  if type(flags) ~= "table" or type(flags.IsTurnIn) ~= "function" then
    return false
  end
  local ok, turnIn = pcall(flags.IsTurnIn, questId)
  if not ok or turnIn ~= true then
    return false
  end
  local era = ItemTree.EraSources
  if type(era) == "table" and type(era.QuestEvent) == "function" then
    local asked, event = pcall(era.QuestEvent, Keep.BuiltEraTable(), questId)
    if asked and event ~= nil then
      return false
    end
  end
  return true
end

-- Brief RB1c (the owner's ruling "A" of 2026-10-17): the gate (an instance's Classic map id) that holds a
-- quest back for this character now (Core/QuestFlags.lua HeldBack: gated in the data and the character
-- has not been inside, or the demo pretends so), or nil. A held back quest never keeps or locks an
-- item; it counts on the page and folds on the tooltip. Pure over the shipped tables and the record.
-- Brief WS1: or QuestFlags.STARTER_GATE for a quest an item starts that the character neither holds a
-- starter of nor has in the log (never for starts, true where the item asked about starts the quest),
-- and as the second answer the starter's own (true, false, or nil for a quest no item starts).
function Keep.QuestHeldBack(questId, starts)
  local flags = ItemTree.QuestFlags
  if type(questId) ~= "number" or type(flags) ~= "table" or type(flags.HeldBack) ~= "function" then
    return nil, nil
  end
  local ok, gate, starter = pcall(flags.HeldBack, questId, starts)
  if not ok then
    return nil, nil
  end
  if type(starter) ~= "boolean" then
    starter = nil
  end
  if type(gate) == "number" then
    return gate, starter
  end
  return nil, starter
end

-- Brief WS1: whether an item is one of the items that start a quest (Core/QuestFlags.lua IsStarter over
-- the shipped QuestStarts), so a quest the item asks for and starts keeps its start use. Brief ASF1 (the
-- Opus review of round AS, M1): or the item's own row says it starts the quest (QuestFlags.ItemStartsQuest:
-- its sq, the STARTS_QUEST edge's fact, else a withheld item's Classic Era row's), so Keep.EraProvidedQuests
-- never makes Essence of Eranikus 10454 a provided item of the quest it starts, 3373. Pure.
function Keep.StartsQuest(itemId, questId)
  local flags = ItemTree.QuestFlags
  if type(flags) ~= "table" then
    return false
  end
  local ask = type(flags.ItemStartsQuest) == "function" and flags.ItemStartsQuest or flags.IsStarter
  if type(ask) ~= "function" then
    return false
  end
  local ok, starts = pcall(ask, itemId, questId)
  return ok and starts == true
end

-- Brief WS1: the starter answers a score rests on, { [questId] = true (held back) | false }, over
-- Keep.UsesAndRepeats' uses and held back lists (each quest need an item starts carries
-- use.starterHeldBack), or nil for none. Keep.RecheckStarters asks them again on a bag, bank or quest
-- log change and drops the score where one moved. Pure.
function Keep.StarterWatch(uses, gated)
  local watch = nil
  for _, list in ipairs({ uses, gated }) do
    for _, use in ipairs(type(list) == "table" and list or EMPTY) do
      if type(use) == "table" and type(use.questId) == "number" and type(use.starterHeldBack) == "boolean" then
        watch = watch or {}
        watch[use.questId] = use.starterHeldBack
      end
    end
  end
  return watch
end

-- Brief RB1c: Keep.RepeatCount over the held back quests (Keep.UsesAndRepeats' third list), and beside
-- it how many each gate holds, { [gateId] = count }. Pure.
function Keep.HeldBackCount(gated, playerFaction, opts)
  local count, ids = Keep.RepeatCount(gated, playerFaction, opts)
  local shown, byGate = {}, {}
  for _, questId in ipairs(ids) do
    shown[questId] = true
  end
  for _, use in ipairs(type(gated) == "table" and gated or EMPTY) do
    if shown[use.questId] and use.gate then
      byGate[use.gate] = (byGate[use.gate] or 0) + 1
      shown[use.questId] = nil
    end
  end
  return count, ids, byGate
end

-- Brief RB1b: how many of an item's repeatable quests (Keep.UsesAndRepeats' second list) the player's
-- page counts, and their ids ascending: every one but a quest of the other side while "Hide other
-- faction data" is on (Keep.HidesOtherSide over opts) and one only the other side was seen taking
-- (QS2b). Never relevant: no level, class or completion test, as the owner asked ("always collapsed").
-- Pure.
function Keep.RepeatCount(repeats, playerFaction, opts)
  local ids = {}
  local hides = Keep.HidesOtherSide(opts)
  for _, use in ipairs(type(repeats) == "table" and repeats or EMPTY) do
    local hidden = Keep.SeenOtherSideQuest(use, playerFaction) or (hides and Keep.OtherSideQuest(use, playerFaction))
    if not hidden and type(use.questId) == "number" then
      ids[#ids + 1] = use.questId
    end
  end
  table.sort(ids)
  return #ids, ids
end

-- Brief AA-RB (the owner's QA item 219): how many of a list of repeatable or held back quests
-- (Keep.UsesAndRepeats' second or third list) Keep.RepeatCount leaves out as the other side's, the
-- quests behind the Keep block's "No known uses for Alliance" (Keep.NoUsesWords). Pure.
function Keep.OtherSideCount(list, playerFaction, opts)
  local count = 0
  local hides = Keep.HidesOtherSide(opts)
  for _, use in ipairs(type(list) == "table" and list or EMPTY) do
    if Keep.SeenOtherSideQuest(use, playerFaction) or (hides and Keep.OtherSideQuest(use, playerFaction)) then
      count = count + 1
    end
  end
  return count
end

-- Brief RB1: whether a quest use's edge is a Classic Era quest row (historical) whose quest the client
-- does not list (no listed mark, Core/EraSources.lua _MarkQuest) while the shipped turn ins cannot
-- judge such quests (Core/QuestFlags.lua JudgesUnlisted: a compile before RB1's pipeline change flags
-- the listed quests' turn ins alone), so its need is left out as before RB1 rather than kept as a
-- possible repeat. false for every edge of ours (a record, a curated quest, a gap fill objective),
-- for a listed row, and for every row once the data judges the unlisted quests. Pure over the core
-- data.
function Keep.EraQuestUnjudged(edge)
  if type(edge) ~= "table" or edge.historical ~= true or edge.listed == true then
    return false
  end
  local flags = ItemTree.QuestFlags
  if type(flags) ~= "table" or type(flags.JudgesUnlisted) ~= "function" then
    return true
  end
  local ok, judged = pcall(flags.JudgesUnlisted)
  return not (ok and judged == true)
end

-- Whether a score's keep rests on its quest uses alone: the use rule keeps it (Keep.KeepRule), and
-- would not with every current quest use left out. The player's Always is never quest only. Pure.
function Keep.QuestOnly(score)
  if type(score) ~= "table" or score.override == "always" then
    return false
  end
  local quests = tonumber((score.kinds or EMPTY).quest) or 0
  if quests <= 0 or not Keep.KeepRule(score) then
    return false
  end
  return not Keep.KeepRule(Keep.QuestFree(score))
end

-- A view of the score with its current quest uses left out (a shallow copy: kinds.quest gone, and
-- current and ownCurrent less that many), for the verdict the item would have without them. Pure.
function Keep.QuestFree(score)
  local view, kinds = {}, {}
  for key, value in pairs(type(score) == "table" and score or EMPTY) do
    view[key] = value
  end
  local quests = tonumber((view.kinds or EMPTY).quest) or 0
  for key, value in pairs(view.kinds or EMPTY) do
    kinds[key] = value
  end
  kinds.quest = nil
  view.kinds = kinds
  view.current = math.max(0, (tonumber(view.current) or 0) - quests)
  if tonumber(view.ownCurrent) ~= nil then
    view.ownCurrent = math.max(0, tonumber(view.ownCurrent) - quests)
  end
  return view
end

-- How many of the item a quest only keep holds (score.questNeed), or nil: the keep rests on more
-- than quests, or an open quest states no count. Pure.
function Keep.QuestKeepUpTo(score)
  local need = type(score) == "table" and tonumber(score.questNeed) or nil
  if need == nil or need <= 0 or not Keep.QuestOnly(score) then
    return nil
  end
  return math.floor(need)
end

--------------------------------------------------------------------------------
-- Brief QX1 (the owner, 2026-10-22: "track quest items in your bags that are fully safe to throw
-- away", "It should become part of the keep flag family and reason line"; his rulings of the same
-- day, 1B and the words): a FINISHED quest item. A quest bound or soulbound quest item (Keep.QuestItem
-- with bonding 4 or 1, Keep.FinishedBound) is finished when our data names at least one quest use for
-- it that is this character's and every such quest is done:
--   completed  the client flags it (Keep.QuestCompleted), or
--   abandoned  this character took it and dropped it (Keep.QuestAbandoned), and one of the owner's
--              safety checks holds for that quest (Keep.AbandonedSafe): (a) the quest hands the item
--              over, so taking it again gives the item again (Keep.QuestGivesItem); (b) taking it again
--              gives no experience, the quest grey for the player (Keep.QuestGrey). Never the level cap
--              alone (his ruling "A"). An abandoned quest that passes neither (a dropped item whose
--              quest is in range) leaves the item silent: retaking it would mean farming it again.
-- Brief AQF1 fix 4 (the owner's ruling "A" of 2026-10-22, QA item 380): and a quest neither completed nor
-- abandoned counts as done too where it is not in the log, grey for the player (Keep.QuestGrey) and a chain
-- end (Keep.QuestHasNextStep false), "Quest below your level" (Keep.QuestBelowLevel).
-- It stays silent (owner ruling 12, as before) where any of its quests of this character is in the log
-- or still to do (a grey chain end out of the log excepted, above), where a repeatable quest (Keep.UsesAndRepeats'
-- second list), an event or unjudged quest (its fourth) or a held back quest not done (its third) is among them, where
-- it has any use that is no quest (unknown is not safe), and where our data names no quest use at all. A quest that
-- is no use for this character at all (the other side's, by its side whatever "Hide other faction data"
-- says; another class's quest) is neither a reason nor a block. Brief RF375 (the review's M5): a quest
-- only the other side's players were SEEN taking (Keep.SeenOtherSideQuest) is not proof the quest is
-- theirs (the seen side runs are sparse), so it is judged as this character's: it blocks while not done.
-- Brief RF375 (M4): a start use of a quest that never keeps an item (a repeatable or an event quest,
-- Keep.QuestNeverKeeps) is judged as the repeatable or event quest's needs are: it can come round again,
-- so it blocks (a repeatable helper as its parent), even where a session's QUEST_TURNED_IN marked it done.
-- Brief RF375 (M1): and while the client's quest log wants the item (Keep.Score asks opts.logWants,
-- Core/QuestFlags.lua LogWantsItem: an item objective of a quest in the log names it), as Jettison's
-- isQuestNeeded keeps its lock, so a quest our data does not know never sees its item called done.
-- A tradable quest class item is no quest item (Keep.QuestItem) and keeps the ordinary rules.
-- Keep logic stays on top: the verdict (Keep.FinishedTags) is drawn only where nothing keeps the item.
-- Brief IW1 (the owner's ruling "3A"): never for an item of epic quality or better (Keep.FinishedEpicGuard).
-- Brief AQF1 fix 3 (the owner's ruling "B" of 2026-10-22, QA item 379): such an item still reads its finished
-- LINES, with no tag and no keep.finished (score.questFinishedLines, Keep.FinishedOnlyParts).
-- Cost: one completed answer per quest of the item (Keep.QuestCompleted's held answers, dropped on
-- QUEST_TURNED_IN and on an abandoned quest settled after QUEST_REMOVED), only for an item scored.
--------------------------------------------------------------------------------

-- Brief QX1: the bondings a finished quest item can have: 4 quest bound, 1 bind on pickup
-- (soulbound). A class 12 item of any other bonding stays silent, as before.
Keep.FINISHED_BONDING = { [1] = true, [4] = true }

-- Brief QX1: whether a score is a quest item the finished rule judges: Keep.QuestItem, bound to the
-- quest or soulbound (Keep.FINISHED_BONDING). Pure.
function Keep.FinishedBound(score)
  if type(score) ~= "table" or not Keep.QuestItem(score) then
    return false
  end
  return Keep.FINISHED_BONDING[tonumber(score.bonding) or -1] == true
end

-- Brief IW1 (the owner's ruling "3A" of 2026-10-22, the epic guard): the quality from which a quest item is
-- never finished, whatever its quests say: 4, epic (Keep.QUALITY_EPIC), and better. An epic quest item is
-- a raid's or a long chain's piece (the Scepter Shards, the Primal Hakkari bindings, the Unfired Ancient
-- Blade) whose loss is costly, so the finished verdict never offers it to the vendor.
Keep.FINISHED_QUALITY_CAP = 4

-- Brief IW1 (ruling "3A"): whether the epic guard holds for a score: its quality (the item row's
-- OverallQuality, score.quality) is Keep.FINISHED_QUALITY_CAP or more. Keep.Score asks it before the
-- finished rule (Keep.QuestFinished); a quality not known never holds it. Pure.
function Keep.FinishedEpicGuard(score)
  local quality = type(score) == "table" and tonumber(score.quality) or nil
  return quality ~= nil and quality >= Keep.FINISHED_QUALITY_CAP
end

-- Brief QX1 (the owner's ruling 1B, check (a)): a stand in a spec or a persona case sets for the
-- quests that hand an item over, { [questId] = { [itemId] = true } }; nil on the client.
Keep.givenItems = nil

-- Brief IW1 (QX1's accessor wired to PV1's and QH1's facts): the quests our data says hand an item
-- over, a provided item that taking the quest again gives again, each quest once in this order:
--   1. Keep.givenItems, the stand in a spec or a persona case sets;
--   2. the recorded hand-overs (Core/PlayerSources.lua ItemProvidedQuests: the player's own records,
--      then the ones the shipped module states, at the accept or mid quest, never one at the turn in;
--      read only where the module is built, so a tooltip or a bag pass never builds it);
--   3. brief NX1 (the owner's ruling "2A" of 2026-10-22): the Classic Era rows (Keep.EraProvidedQuests,
--      the Classic Era table's qp, CMaNGOS SrcItemId: Saving Yenniku 592 hands over the Soul Gem 3912),
--      read only where the table is built, less a quest the item itself starts;
--   4. the predicted provided items (Core/QuestsPredicted.lua ProvidedBy, never loading ItemTree_Data),
--      the same facts the item page's Predicted "Provided by quest" rows draw;
--   5. brief IC1 (the owner's ruling "2B" of 2026-10-23): the predicted item sources' hand-overs
--      (Core/ItemsPredicted.lua ProvidedBy, never loading ItemTree_Data), an item page's own claim,
--      which follow the owner's ruling 1B as every provided item does.
-- THE ONE ACCESSOR for the fact: Keep.QuestGivesItem (QX1's abandoned check (a)) and the provided uses
-- of the owner's ruling 1B (Keep.UsesAndRepeats) both read it. Answers { { questId, recorded = true
-- or nil } }, a fresh list. Pure over the modules.
function Keep.ProvidedQuests(itemId)
  local out, seen = {}, {}
  local id = tonumber(itemId)
  if id == nil then
    return out
  end
  local function add(questId, recorded)
    questId = tonumber(questId)
    if questId and questId > 0 and questId == math.floor(questId) and not seen[questId] then
      seen[questId] = true
      out[#out + 1] = { questId = questId, recorded = recorded or nil }
    end
  end
  local given = Keep.givenItems
  if type(given) == "table" then
    local ids = {}
    for questId, items in pairs(given) do
      if type(items) == "table" and items[id] == true then
        ids[#ids + 1] = questId
      end
    end
    table.sort(ids)
    for _, questId in ipairs(ids) do
      add(questId, true)
    end
  end
  local players = ItemTree.PlayerSources
  if type(players) == "table" and type(players.ItemProvidedQuests) == "function" then
    local ok, list = pcall(players.ItemProvidedQuests, id)
    for _, entry in ipairs(ok and type(list) == "table" and list or EMPTY) do
      add(type(entry) == "table" and entry.questId or nil, true)
    end
  end
  -- Brief NX1: the Classic Era rows, after our records and before the predicted provided items.
  for _, questId in ipairs(Keep.EraProvidedQuests(id)) do
    add(questId, false)
  end
  for _, predicted in ipairs({ ItemTree.QuestsPredicted, ItemTree.ItemsPredicted }) do
    if type(predicted) == "table" and type(predicted.ProvidedBy) == "function" then
      local ok, list = pcall(predicted.ProvidedBy, id, false)
      for _, questId in ipairs(ok and type(list) == "table" and list or EMPTY) do
        add(questId, false)
      end
    end
  end
  return out
end

-- Brief NX1 (the owner's ruling "2A" of 2026-10-22): a stand in a spec or a persona case sets for the
-- Classic Era provided items, { [questId] = { [itemId] = true } }, read in place of the built table's qp
-- (the data in a tree may predate qp); nil on the client.
Keep.eraProvided = nil

-- Brief NX1: the quests the Classic Era rows say hand an item over when taken (the table's qp, CMaNGOS
-- quest_template.SrcItemId; Core/EraSources.lua ProvidedBy), quest id ascending, read only where the table
-- is built (Keep.BuiltEraTable, as a quest's level is), less a quest the item itself starts (PV1's rule,
-- Keep.StartsQuest: the starter the quest keeps, which abandoning the quest does not give back). A fresh
-- list. Pure over the shipped table (never loads it).
function Keep.EraProvidedQuests(itemId)
  local out = {}
  local id = tonumber(itemId)
  if id == nil then
    return out
  end
  local ids = {}
  local stand = Keep.eraProvided
  if type(stand) == "table" then
    for questId, items in pairs(stand) do
      if type(questId) == "number" and type(items) == "table" and items[id] == true then
        ids[#ids + 1] = questId
      end
    end
    table.sort(ids)
  else
    local era = ItemTree.EraSources
    local source = Keep.BuiltEraTable()
    if source ~= nil and type(era) == "table" and type(era.ProvidedBy) == "function" then
      local ok, list = pcall(era.ProvidedBy, source, id)
      ids = ok and type(list) == "table" and list or ids
    end
  end
  for _, questId in ipairs(ids) do
    if not Keep.StartsQuest(id, questId) then
      out[#out + 1] = questId
    end
  end
  return out
end

-- Brief QX1 (ruling 1B, check (a)): whether a quest hands the item over (a provided item, which
-- taking the quest again gives again), from our data: one of Keep.ProvidedQuests (brief IW1: the
-- stand in, the recorded hand-overs, brief NX1's Classic Era rows, the predicted provided items). Pure
-- over the modules.
function Keep.QuestGivesItem(questId, itemId)
  questId, itemId = tonumber(questId), tonumber(itemId)
  if questId == nil or itemId == nil then
    return false
  end
  for _, entry in ipairs(Keep.ProvidedQuests(itemId)) do
    if entry.questId == questId then
      return true
    end
  end
  return false
end

-- Brief IW1 (the owner's ruling 1B of 2026-10-22): whether a quest is in this character's log now
-- (Core/QuestFlags.lua OnQuest: C_QuestLog.IsOnQuest, the demo first), true or false. Brief AQF2 (the
-- Fable review of round AR, 2026-10-23, M2): nil where the client cannot say (OnQuest's nil, a raise or a
-- secret value, or a raise here), handed through so the below level rule reads it as maybe in the log
-- (Keep.QuestBelowLevel); the provided rule still reads anything but true as not in the log (a provided
-- item keeps only while its quest is known to be in it, Keep.ProvidedInLog). What Keep.CachedScore hands
-- Keep.ScoreUses and Keep.QuestFinished as opts.onQuest.
function Keep.QuestInLog(questId)
  local flags = ItemTree.QuestFlags
  if type(questId) ~= "number" or type(flags) ~= "table" or type(flags.OnQuest) ~= "function" then
    return false
  end
  local ok, onQuest = pcall(flags.OnQuest, questId)
  if not ok or onQuest == nil then
    return nil
  end
  return onQuest == true
end

-- Brief IW1 (ruling 1B): whether a provided use's quest is in the log, asked through onQuest (opts.onQuest;
-- none: not in the log), the answer kept on the score as score.providedWatch = { [questId] = true |
-- false } so a quest taken or dropped later re-reads it (Keep.RecheckProvided). Brief AQF2 (M2): the
-- second answer is the log's own, true or false, nil where it cannot say (no onQuest, a raise, nil or any
-- other answer), for the below level rule (Keep.QuestBelowLevel); the first and the watch are as before.
-- Pure but for onQuest.
function Keep.ProvidedInLog(score, use, onQuest)
  local questId = type(use) == "table" and tonumber(use.questId) or nil
  if questId == nil then
    return false, nil
  end
  local answer, said = false, nil
  if type(onQuest) == "function" then
    local ok, inLog = pcall(onQuest, questId)
    answer = ok and inLog == true
    if ok and type(inLog) == "boolean" then
      said = inLog
    end
  end
  if type(score) == "table" then
    score.providedWatch = score.providedWatch or {}
    score.providedWatch[questId] = answer
  end
  return answer, said
end

-- Brief QX1 (ruling 1B as the owner narrowed it, "A" of 2026-10-22): whether an abandoned quest leaves
-- its item safe to throw away: check (a), the quest hands the item over (Keep.QuestGivesItem), or check
-- (b), taking it again gives no experience because it is grey for the player (Keep.QuestGrey: QUEST_GREY
-- or more levels above its level; false where its level is not known). The level cap is NOT a check:
-- level 55 and up quests whose quest bound items are drops (Nefarius's Corruption's Red Scepter Shard,
-- Blood of the Black Dragon Champion) would be thrown away at 60 after an abandon to make log space.
-- Brief RF375 (the owner's ruling "A" of 2026-10-22 on the review's M2): check (b) holds only for a
-- quest with no later step in its chain (Keep.QuestHasNextStep): a grey chain step stays silent, since
-- the chain's next quest may still want what this one gathered. Check (a) is unchanged.
-- Brief ASF1 (the Opus review of round AS, M1; the owner's ruling of 2026-10-09: a starter item keeps unless
-- its quest is completed, grey or the other side's): check (a) never frees a START use (use.start, the item
-- starts the quest): an abandoned item started quest is taken again from the item itself, so throwing the
-- starter away loses the quest, whatever a provided list says (the Classic Era qp names Essence of Eranikus
-- 10454 for 3373, the quest it starts). Check (b) still holds for it.
-- Pure over the graph.
function Keep.AbandonedSafe(use, itemId, playerLevel)
  if type(use) ~= "table" or type(use.questId) ~= "number" then
    return false
  end
  if use.start ~= true and Keep.QuestGivesItem(use.questId, itemId) then
    return true
  end
  return Keep.QuestGrey(use, playerLevel) and not Keep.QuestHasNextStep(use.questId)
end

-- Brief AQF1 fix 4 (the owner's ruling "A" of 2026-10-22, QA item 380: Painted Gnoll Armband at 40, Riverpaw
-- Gnoll Bounty grey and never taken, read only "1 quest below your level"): whether a quest use the character
-- has neither completed nor abandoned is finished for it anyway, "Quest below your level": the quest is grey
-- for the player (Keep.QuestGrey: QUEST_GREY or more levels above its level), a chain end (no shipped table
-- names a later step, Keep.QuestHasNextStep), and not in the log (inLog, asked last and only where the two
-- hold, so a caller that records the answer records it only for such a quest). Taking it would give no
-- experience and nothing after it wants what it asks for. Brief AQF2 (the Fable review of round AR,
-- 2026-10-23, M2): "not in the log" is the log's explicit false; where it cannot say (nil, a raise, any
-- other answer) or no inLog is given, the quest may be in the log, so the rule says nothing (the safe side
-- for a line that frees the item). Pure over the shipped tables but for inLog.
function Keep.QuestBelowLevel(use, playerLevel, inLog)
  if type(use) ~= "table" or use.kind ~= "quest" or type(use.questId) ~= "number" then
    return false
  end
  if type(inLog) ~= "function" then
    return false
  end
  if not Keep.QuestGrey(use, playerLevel) or Keep.QuestHasNextStep(use.questId) then
    return false
  end
  local ok, answer = pcall(inLog, use.questId)
  return ok and answer == false
end

-- Brief RF375 (the owner's ruling "A" of 2026-10-22 on the review's M2, Legends of Maraudon's Celebrian
-- Diamond): whether a quest has a later step in its chain, from the data already shipped, any one of:
--   1. the Classic Era table's qc, a position before the chain's last (Core/EraSources.lua QuestChain:
--      c below cl), read only where the table is built (Keep.BuiltEraTable, as the quest's level is);
--   2. our records' chain, the same (Core/PlayerSources.lua QuestChain, read only where the module is
--      built), and only for a quest qc does not hold: brief CN1 (the owner's ruling of 2026-10-24, "Classic
--      ordering"), the Classic chain decides wherever one holds the quest, as it decides the numeral
--      (Core/ViewModel.lua QuestChain). Our records number one giver's same titled quests by quest id, so
--      their c below cl says only that a higher id follows: Crown of the Earth 935 (the records' 3 of 4) ends
--      its Classic chain (6 of 6), so its Filled Vessel can read "Quest below your level". Arugal's Folly 99
--      (1 of 3, the chain's 4 of 4) keeps a later step through Forever's predicted chain (3 below);
--   3. the predicted chain's next quests (Core/QuestsPredicted.lua Chain, never loading ItemTree_Data), or
--      a quest whose predicted chain names this one as its previous (QuestsPredicted.FollowedBy);
--   4. a Classic Era quest link (the rows a chain steps through, Graph.ChainQuestEdge): a quest item (quest
--      class, or bound to the quest) the quest hands over as a reward (Core/QuestFlags.lua EraRewards) that
--      another quest asks for (the Classic Era table's qr, E:RequiredBy), read only where the table is built;
--   5. a repeatable helper (the table's qw) counts as its parent (Keep.QuestHelperParent);
--   6. brief PL1 (the owner's ruling "B" of 2026-10-22): the Classic Era table's qo, a quest that comes
--      after it by CMaNGOS's prerequisite links (Keep.QuestNextSteps), whatever its title: Legends of
--      Maraudon 7044 goes on to The Scepter of Celebras 7046, so the Celebrian Diamond stays silent. Brief
--      NX2 (the owner's word of 2026-10-23): qo also holds a quest whose RequiredCondition asks for this one
--      rewarded (Rise of the Silithid 4267 -> March of the Silithid 4493) and a breadcrumb's target
--      (Deliveries to Sven 164 -> Sven's Revenge 95), so their items read no "Quest below your level".
-- false where none names one (a chain end, a single step quest, or a link no shipped table holds).
-- Pure over the shipped tables.
function Keep.QuestHasNextStep(questId, depth)
  local id = tonumber(questId)
  if id == nil then
    return false
  end
  local source = Keep.BuiltEraTable()
  local era = ItemTree.EraSources
  -- Brief CN1: whether qc holds the quest at all, so our records' chain is not asked about it.
  local classicChain = false
  if source ~= nil and type(era) == "table" and type(era.QuestChain) == "function" then
    local ok, chain = pcall(era.QuestChain, source, id)
    if ok and type(chain) == "table" then
      classicChain = true
      if chain.cl ~= nil and chain.c < chain.cl then
        return true
      end
    end
  end
  -- Brief PL1: a later quest by the Classic Era prerequisite links (qo), read beside qc.
  if #Keep.QuestNextSteps(id) > 0 then
    return true
  end
  local players = ItemTree.PlayerSources
  if
    not classicChain
    and type(players) == "table"
    and type(players.Loaded) == "function"
    and type(players.QuestChain) == "function"
  then
    local okLoaded, loaded = pcall(players.Loaded)
    if okLoaded and type(loaded) == "table" then
      local ok, chain = pcall(players.QuestChain, loaded, id)
      if ok and type(chain) == "table" and chain.cl ~= nil and chain.c < chain.cl then
        return true
      end
    end
  end
  local predicted = ItemTree.QuestsPredicted
  if type(predicted) == "table" and type(predicted.Chain) == "function" then
    local ok, _, nextIds = pcall(predicted.Chain, id, false)
    if ok and type(nextIds) == "table" and #nextIds > 0 then
      return true
    end
  end
  if type(predicted) == "table" and type(predicted.FollowedBy) == "function" then
    local ok, later = pcall(predicted.FollowedBy, id, false)
    if ok and type(later) == "table" and #later > 0 then
      return true
    end
  end
  local flags = ItemTree.QuestFlags
  local instance = ItemTree.eraSources
  if
    source ~= nil
    and type(flags) == "table"
    and type(flags.EraRewards) == "function"
    and type(instance) == "table"
    and type(instance.RequiredBy) == "function"
  then
    local ok, rewards = pcall(flags.EraRewards, id)
    for itemId in pairs(ok and type(rewards) == "table" and rewards or EMPTY) do
      -- Only a quest item handed on (quest class, or bound to the quest): a common reward another quest
      -- also asks for (Ice Cold Milk, Refreshing Spring Water, a potion) is no step of a chain.
      local reward = itemRow(itemId)
      if
        type(reward) == "table"
        and (tonumber(reward.c) == Keep.QUEST_CLASS or tonumber(reward.b) == Keep.QUEST_BONDING)
      then
        local asked, list = pcall(instance.RequiredBy, instance, itemId)
        for _, entry in ipairs(asked and type(list) == "table" and list or EMPTY) do
          if type(entry) == "table" and entry.quest ~= id then
            return true
          end
        end
      end
    end
  end
  local parent = Keep.QuestHelperParent(id)
  if parent ~= nil and parent ~= id and (tonumber(depth) or 0) < 1 then
    return Keep.QuestHasNextStep(parent, (tonumber(depth) or 0) + 1)
  end
  return false
end

-- Brief RF375 (M1): the item name an item link carries ("|h[Linen Cloth]|h"), or nil. Pure.
function Keep.LinkName(link)
  if type(link) ~= "string" then
    return nil
  end
  local name = link:match("|h%[(.-)%]|h")
  if type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- Brief RF375 (M1): whether the client's quest log wants an item (Core/QuestFlags.lua LogWantsItem: an
-- item objective of a quest in the log names it by name), true or false. What Keep.CachedScore hands
-- Keep.Score as opts.logWants. No item query and no server call: the log's own objectives, read again
-- only after the log changed.
function Keep.LogWants(itemId, name)
  local flags = ItemTree.QuestFlags
  if type(flags) ~= "table" or type(flags.LogWantsItem) ~= "function" then
    return false
  end
  local ok, wants = pcall(flags.LogWantsItem, itemId, name)
  return ok and wants == true
end

-- Brief RF375 (the review's M4): whether a use is a start use of a quest that never keeps an item (a
-- repeatable or an event quest, Keep.QuestNeverKeeps), which Keep.QuestFinished judges as that quest's
-- needs are judged (Keep.UsesAndRepeats files a start use among the uses, the owner's ruling 4). Pure
-- over the shipped tables.
function Keep.FinishedRepeatStart(use)
  return type(use) == "table"
    and use.kind == "quest"
    and use.start == true
    and type(use.questId) == "number"
    and Keep.QuestNeverKeeps(use.questId)
end

-- Brief QX1: the finished answer for one item, over Keep.UsesAndRepeats' four lists (uses, repeats,
-- gated, others) and the player: { complete = { questId, ... }, abandoned = { questId, ... }, below = {
-- questId, ... } } (in use order, the held back quests after the uses; below, brief AQF1 fix 4, the quests
-- neither completed nor abandoned that are grey, a chain end and not in the log, Keep.QuestBelowLevel), or
-- nil where the item is not finished (see the section's head). opts: completed(questId) and abandoned(questId), the
-- predicates Keep.ScoreUses takes (no predicate: nothing done), and (brief IW1) onQuest(questId). Brief IW1 (the
-- owner's ruling 1B): a provided use (use.provided, Keep.UsesAndRepeats) whose quest is neither done nor in the log is
-- neither a reason nor a block: taking the quest again gives the item again. Brief IW1 (the owner's
-- ruling "B"): a repeatable helper quest (use.helperOf, Keep.QuestHelperParent) is judged as its parent,
-- which blocks while it is open, still to do or abandoned and not safe; done, it names the parent once
-- among the completed (or abandoned) quests; the helper never blocks on its own. Pure over its arguments
-- and the graph.
function Keep.QuestFinished(itemId, uses, repeats, gated, others, playerLevel, playerFaction, playerClass, opts)
  opts = type(opts) == "table" and opts or EMPTY
  local completed = type(opts.completed) == "function" and opts.completed or nil
  local abandoned = type(opts.abandoned) == "function" and opts.abandoned or nil
  local onQuest = type(opts.onQuest) == "function" and opts.onQuest or nil
  local function ask(fn, questId)
    if fn == nil then
      return false
    end
    local ok, answer = pcall(fn, questId)
    return ok and answer == true
  end
  -- A quest that is no use for this character at all: the other side's (by its side, whatever the
  -- setting says) or another class's. Brief RF375 (M5): never one only the other side was seen taking
  -- (Keep.SeenOtherSideQuest): sparse seen side data is no proof, and the safe direction is silence.
  local function theirs(use)
    return Keep.OtherSide(use.faction, playerFaction) or Keep.QuestOtherClass(use, playerClass)
  end
  local complete, dropped, below = {}, {}, {}
  -- false where the use keeps the item from being finished.
  local function judge(use)
    if type(use) ~= "table" then
      return true
    end
    if use.kind ~= "quest" or type(use.questId) ~= "number" then
      return false
    end
    if theirs(use) then
      return true
    end
    if ask(completed, use.questId) then
      complete[#complete + 1] = use.questId
      return true
    end
    local wasAbandoned = ask(abandoned, use.questId)
    if wasAbandoned and Keep.AbandonedSafe(use, itemId, playerLevel) then
      dropped[#dropped + 1] = use.questId
      return true
    end
    -- Brief AQF1 fix 4 (the owner's ruling "A", QA item 380): neither completed nor abandoned, but grey, a
    -- chain end and not in the log (Keep.QuestBelowLevel): "Quest below your level".
    if not wasAbandoned and Keep.QuestBelowLevel(use, playerLevel, onQuest) then
      below[#below + 1] = use.questId
      return true
    end
    -- Brief IW1 (ruling 1B): a provided item whose quest is not in the log is no use now.
    if use.provided and not ask(onQuest, use.questId) then
      return true
    end
    return false
  end
  -- Brief RF375 (M4): a start use of a quest that never keeps an item waits for the repeats' pass.
  local repeatStarts = {}
  for _, list in ipairs({ uses or EMPTY, gated or EMPTY }) do
    for _, use in ipairs(list) do
      if Keep.FinishedRepeatStart(use) then
        repeatStarts[#repeatStarts + 1] = use
      elseif not judge(use) then
        return nil
      end
    end
  end
  -- Brief IW1 (ruling "B"): a repeatable helper as its parent, the parent judged as a quest use of its own.
  local named = {}
  for _, list in ipairs({ complete, dropped, below }) do
    for _, questId in ipairs(list) do
      named[questId] = true
    end
  end
  local function judgeParent(use)
    local parent = Keep.MarkQuestUse({ kind = "quest", questId = use.helperOf, target = "quest:" .. use.helperOf }, nil)
    if named[parent.questId] then
      return true
    end
    local before = { #complete, #dropped, #below }
    if not judge(parent) then
      return false
    end
    for at, list in ipairs({ complete, dropped, below }) do
      for index = before[at] + 1, #list do
        named[list[index]] = true
      end
    end
    return true
  end
  for _, list in ipairs({ repeats or EMPTY, others or EMPTY, repeatStarts }) do
    for _, use in ipairs(list) do
      if type(use) == "table" and not theirs(use) then
        if type(use.helperOf) ~= "number" or not judgeParent(use) then
          return nil
        end
      end
    end
  end
  if #complete + #dropped + #below == 0 then
    return nil
  end
  return { complete = complete, abandoned = dropped, below = below }
end

-- Brief QX1: the title a finished line names a quest by: Keep.QuestTitle (the need lines' own), else
-- "Quest", as the need line words a quest with no title (Keep.QuestNeedWords). Pure but for the title
-- read.
function Keep.FinishedTitle(questId)
  local id = tonumber(questId)
  if id == nil then
    return nil
  end
  return Keep.QuestTitle(id) or L["Quest"]
end

-- Brief QX1: the tags for a finished quest item (score.questFinished, Keep.QuestFinished): [Vendor]
-- where it has a sell price, else [Worthless], the answer carrying finished for its lines
-- (Keep.FinishedLines); nil for any other score. Only Keep.RawTags asks, where nothing keeps the item.
-- Pure.
function Keep.FinishedTags(score)
  local finished = type(score) == "table" and score.questFinished or nil
  if type(finished) ~= "table" then
    return nil
  end
  local tag = (tonumber(score.vendor) or 0) > 0 and Keep.TAG_VENDOR or Keep.TAG_WORTHLESS
  return {
    tags = { tag },
    noAuctionData = false,
    legendary = false,
    byUse = false,
    keepBy = nil,
    finished = finished,
  }
end

-- Brief BQ16 (the owner's ruling of 2026-10-10, QA item 8: "if there's 1 quest and you're 9/8 we
-- should just show that like our levelling instead of word salad"): every need reads in the
-- levelling line's shape, "(have / needed)", and a count past the need shows what is spare with no
-- sentence added. The words for one need: "Westfall Stew (II) (9 / 8 needed)". Pure.
function Keep.NeedWords(label, have, need)
  return string.format(
    L["%s (%d / %d needed)"],
    label,
    math.floor(tonumber(have) or 0),
    math.floor(tonumber(need) or 0)
  )
end

-- Brief BQ16: the title a need line names a quest by, "Westfall Stew (II)": the Classic Era
-- reader's (E:QuestTitle, the title rows draw, numbered by brief QN1), else ItemTree's own data
-- (API.QuestTitle, never a client call) with its place in a chain of same titled quests
-- (ViewModel.QuestDisplayName); nil where none is loaded or names it.
function Keep.QuestTitle(questId)
  if type(questId) ~= "number" then
    return nil
  end
  local era = ItemTree.eraSources
  if type(era) == "table" and type(era.QuestTitle) == "function" then
    local okEra, named = pcall(era.QuestTitle, era, questId)
    if okEra and type(named) == "string" and named ~= "" then
      return named
    end
  end
  local API = ItemTree.API
  if type(API) ~= "table" or type(API.QuestTitle) ~= "function" then
    return nil
  end
  local ok, title = pcall(API.QuestTitle, questId)
  if not ok or type(title) ~= "string" or title == "" then
    return nil
  end
  local ViewModel = ItemTree.ViewModel
  if type(ViewModel) == "table" and type(ViewModel.QuestDisplayName) == "function" then
    local okShown, shown = pcall(ViewModel.QuestDisplayName, questId, title)
    if okShown and type(shown) == "string" and shown ~= "" then
      return shown
    end
  end
  return title
end

-- Brief BQ16: the open quests' need line, "Westfall Stew (II) (9 / 8 needed)" for one open quest
-- (its title, else "Quest"), "2 quests (30 / 20 needed)" for more (kinds.quest). have is the count
-- the line shows, need the quests' count. Pure but for the title read (Keep.QuestTitle).
function Keep.QuestNeedWords(score, have, need)
  local open = type(score) == "table" and tonumber((score.kinds or EMPTY).quest) or 0
  if open > 1 then
    return Keep.NeedWords(string.format(L["%d quests"], open), have, need)
  end
  local ids = type(score) == "table" and type(score.questIds) == "table" and score.questIds or EMPTY
  return Keep.NeedWords(Keep.QuestTitle(ids[1]) or L["Quest"], have, need)
end

-- Brief BQ16: the two numbers the quests' need line shows, (have, need), or nil where it shows none:
-- have (the player's count) not known, or no quest count holds the keep. questPart (brief INT1b,
-- the route and the quests together) is the quests' part, served first from the count; else a
-- quest only keep's count (Keep.QuestKeepUpTo) against the whole count. Pure.
-- Brief UL1 (QA item 347i, the owner: uses shown "as in the Keep block ... named quest, need counts"):
-- the open quests' count (score.questNeed, every open quest stating one) is shown whatever keeps the
-- item, not only where the quests alone keep it, so a named quest always reads "Riverpaw Gnoll Bounty
-- (20 / 8 needed)" and never a bare "1 quest" beside another quest's need line.
function Keep.QuestNeedCounts(score, have, questPart)
  have = tonumber(have)
  if have == nil then
    return nil, nil
  end
  local part = tonumber(questPart)
  if part and part > 0 then
    part = math.floor(part)
    return math.min(math.floor(have), part), part
  end
  local upTo = Keep.QuestKeepUpTo(score)
  if upTo == nil then
    upTo = type(score) == "table" and tonumber(score.questNeed) or nil
    if upTo == nil or upTo <= 0 then
      return nil, nil
    end
    upTo = math.floor(upTo)
  end
  return math.floor(have), upTo
end

-- Brief UL1: whether the uses lines show the player's count of the item: a need line of the quests
-- (score.questNeed), an item combine's ("Waylaid Supplies (0 / 20 needed)"), a quest only keep's
-- (Keep.QuestKeepUpTo) or a working stock keep's (Keep.StockCap). Pure.
function Keep.WantsHave(score)
  if type(score) ~= "table" then
    return false
  end
  if Keep.QuestKeepUpTo(score) ~= nil or Keep.StockCap(score) ~= nil then
    return true
  end
  if (tonumber(score.questNeed) or 0) > 0 then
    return true
  end
  -- Brief UL2 (QA item 366): a supply crate's need line; another combine shows no count.
  for _, combine in ipairs(type(score.combines) == "table" and score.combines or EMPTY) do
    if type(combine) == "table" and combine.crate then
      return true
    end
  end
  return false
end

--------------------------------------------------------------------------------
-- Class locked consumables (brief TB10). Pure over the item row.
--------------------------------------------------------------------------------

-- The ChrClasses ids a playable class can have, in the order the class mask's bits run.
Keep.CLASS_IDS = { 1, 2, 3, 4, 5, 7, 8, 9, 11 }
-- The item class a consumable is filed under.
Keep.CONSUMABLE_CLASS = 0

-- The class mask bit of one ChrClasses id. Pure.
local function classBit(classId)
  return 2 ^ (classId - 1)
end

-- Whether a class mask names this ChrClasses id. No bitwise operators: WoW runs Lua 5.1. Pure.
function Keep.MaskHasClass(mask, classId)
  mask, classId = tonumber(mask), tonumber(classId)
  if not mask or not classId or mask <= 0 or classId < 1 then
    return false
  end
  local bit = classBit(classId)
  return mask % (bit * 2) >= bit
end

-- The ChrClasses ids a class mask names, in class order, or an empty list for 0, nil, a negative
-- mask and a mask that names every playable class (no restriction at all). Pure.
function Keep.MaskClasses(mask)
  local out = {}
  mask = tonumber(mask)
  if not mask or mask <= 0 then
    return out
  end
  for _, classId in ipairs(Keep.CLASS_IDS) do
    if Keep.MaskHasClass(mask, classId) then
      out[#out + 1] = classId
    end
  end
  if #out == #Keep.CLASS_IDS then
    return {}
  end
  return out
end

-- Brief TB10: the use a class locked consumable has of its own, read off its item row: a
-- consumable (class 0) whose allowableClass mask (ac) names one or more classes, but not every
-- class. { kind = "class", target = "class:<mask>", classMask = mask, classIds = { ... },
-- reqSkill = the row's sk or nil, reqRank = its skr or nil }, or nil. The row's sk alone, with
-- no class mask, derives nothing: every class can use such an item. Pure over the data tables.
function Keep.ClassUse(itemId)
  local item = itemRow(tonumber(itemId))
  if not item or tonumber(item.c) ~= Keep.CONSUMABLE_CLASS then
    return nil
  end
  local mask = whole(item.ac)
  local classIds = Keep.MaskClasses(mask)
  if #classIds == 0 then
    return nil
  end
  local use = { kind = "class", target = "class:" .. tostring(mask), classMask = mask, classIds = classIds }
  local skill = whole(item.sk)
  if skill then
    use.reqSkill = skill
    use.reqRank = whole(item.skr)
  end
  return use
end

--------------------------------------------------------------------------------
-- Chained uses (brief TB9): a recipe use whose recipe makes an item, and that item's own recipe
-- uses, one level down and never deeper. Pure over the graph and the data tables.
--------------------------------------------------------------------------------

-- The caps on the walk: products walked, and chained uses filed (each spell once).
Keep.CHAIN_PRODUCTS = 8
Keep.CHAIN_USES = 24

-- The item a recipe spell makes, or nil (an enchant, or a spell the tables do not hold). Pure.
local function productOf(spellId)
  local d = data()
  if not d or type(d.GetRecipe) ~= "function" or type(spellId) ~= "number" then
    return nil
  end
  local ok, recipe = pcall(d.GetRecipe, d, spellId)
  local out = ok and type(recipe) == "table" and type(recipe.out) == "table" and recipe.out[1] or nil
  if type(out) == "number" then
    return out
  end
  return nil
end

-- The recipes a product is a reagent for and teaches, straight off its Uses row (r, then t), in
-- the order Graph.Children emits them, or nil where it has none: a product nothing uses (a
-- crafted chest piece) costs no walk and no place under the cap. The row rather than a second
-- Graph.Children walk, which would ask every provider (the collector, the Classic Era table,
-- the installed source addons) about every product of every bag slot. Over the shipped data no
-- reagent or teaching edge of the 3,141 items with one is missing from the row; a product's tool
-- uses (42 edges) are left out of chains. Pure.
local function productRecipes(itemId)
  local d = data()
  if not d or type(d.GetUses) ~= "function" then
    return nil
  end
  local ok, row = pcall(d.GetUses, d, itemId)
  if not ok or type(row) ~= "table" then
    return nil
  end
  local reagent = type(row.r) == "table" and row.r or EMPTY
  local teaches = type(row.t) == "table" and row.t or EMPTY
  if #reagent == 0 and #teaches == 0 then
    return nil
  end
  return reagent, teaches
end

-- Brief TB9: the chained uses of an item whose direct uses are handed in (Keep.Uses), in the
-- graph's order: for each direct recipe use with a profession whose recipe makes an item, that
-- item's own recipe uses with a profession, each as
--   { kind = "recipe", target = the chained spell's key, level, faction, skill = its profession,
--     via = { item = the product's id, skill = the direct recipe's profession, level, faction =
--     the direct use's, so the scorer can judge both ends } }
-- At most Keep.CHAIN_PRODUCTS products are walked and Keep.CHAIN_USES chained uses filed; a
-- spell is filed once whichever product reaches it, never where it is a direct use already, never
-- for a product that is the item itself, and (brief TB13) never where its profession is the
-- direct recipe's own. Pure over the graph and the data tables.
function Keep.ChainedUses(itemId, uses)
  local out = {}
  local Graph = ItemTree.Graph
  local id = tonumber(itemId)
  if not id or type(uses) ~= "table" or not Graph or type(Graph.Parse) ~= "function" then
    return out
  end
  local seen, walked = {}, {}
  for _, use in ipairs(uses) do
    seen[use.target] = true
  end
  local products = 0
  for _, use in ipairs(uses) do
    if products >= Keep.CHAIN_PRODUCTS or #out >= Keep.CHAIN_USES then
      break
    end
    if use.kind == "recipe" and use.skill ~= nil and type(use.target) == "string" then
      local kind, spellId = Graph.Parse(use.target)
      local product = kind == "spell" and productOf(tonumber(spellId)) or nil
      local reagent, teaches = nil, nil
      if product and product ~= id and not walked[product] then
        reagent, teaches = productRecipes(product)
      end
      if reagent then
        walked[product] = true
        products = products + 1
        for _, list in ipairs({ reagent, teaches }) do
          for _, chainedSpell in ipairs(list) do
            if #out >= Keep.CHAIN_USES then
              break
            end
            local target = type(chainedSpell) == "number" and Graph.Key("spell", chainedSpell) or nil
            local skill = target and Keep.RecipeSkill(chainedSpell) or nil
            -- Brief TB13: nothing via itself. A chained recipe of the direct recipe's own
            -- profession (Leatherworking via Leatherworking) is dropped here, where it is
            -- collected, so it is never filed, counted, capped or listed: a player of that
            -- profession is counted on the direct use already.
            if skill ~= nil and skill ~= use.skill and not seen[target] then
              seen[target] = true
              out[#out + 1] = {
                kind = "recipe",
                target = target,
                level = Keep.RecipeLevel(chainedSpell),
                skill = skill,
                via = { item = product, skill = use.skill, level = use.level, faction = use.faction },
              }
            end
          end
        end
      end
    end
  end
  return out
end

-- Whether a use is for the other side. Pure.
function Keep.OtherSide(faction, playerFaction)
  if faction ~= Keep.ALLIANCE and faction ~= Keep.HORDE then
    return false
  end
  if playerFaction ~= Keep.ALLIANCE and playerFaction ~= Keep.HORDE then
    return false
  end
  return faction ~= playerFaction
end

-- Brief QS1 (the owner's ruling A of 2026-10-14): whether a use is a quest of the other side (the
-- listing's side, its edge's only where the listing is silent since brief HF1 of 2026-10-23,
-- Keep.MarkQuestUse), which is no use at all for this character:
-- neither current nor stale, in no count line and no uses list. A quest for both sides, one whose
-- side nobody states and a player whose side is not known answer false. Pure. Brief F155: the rule
-- holds while "Hide other faction data" is on (Keep.HidesOtherSide); Keep.ScoreUses asks that first.
function Keep.OtherSideQuest(use, playerFaction)
  return type(use) == "table" and use.kind == "quest" and Keep.OtherSide(use.faction, playerFaction)
end

-- Brief QS2b (QS2's rule 2): whether a quest use with no side of its own (use.faction nil) was only
-- seen taken by the other side's players (use.seenSide, Keep.MarkQuestUse). Such a quest counts as a
-- use for that side only: for this character it is neither current nor stale and never asked about,
-- whatever "Hide other faction data" says, though no list hides it or words it "Alliance only". A
-- player whose side is not known answers false. Pure.
function Keep.SeenOtherSideQuest(use, playerFaction)
  return type(use) == "table"
    and use.kind == "quest"
    and use.faction == nil
    and Keep.OtherSide(use.seenSide, playerFaction)
end

-- Brief F155 (owner QA 2026-10-14 item 155): whether "Hide other faction data" is on, so the other
-- side's quests are no use at all (QS1). opts.hideOtherSide states it (a spec, a persona case, the
-- self test); otherwise the saved setting answers through Core/Graph.lua Graph.HidesOtherFaction,
-- on by default. Keep.DropScores is how a change reaches the held scores (UI/Options.lua).
function Keep.HidesOtherSide(opts)
  if type(opts) == "table" and opts.hideOtherSide ~= nil then
    return opts.hideOtherSide ~= false
  end
  local Graph = ItemTree.Graph
  if type(Graph) == "table" and type(Graph.HidesOtherFaction) == "function" then
    return Graph.HidesOtherFaction() and true or false
  end
  return true
end

-- Whether a class spell use belongs to another class than the player's. A classId of 0 is
-- everyone's, and a player whose class is not known is taken at nothing: false. Pure.
function Keep.OtherClass(use, playerClass)
  if type(use) == "table" and use.kind == "class" then
    -- Brief TB10: a class locked consumable another class uses.
    local player = tonumber(playerClass)
    return player ~= nil and not Keep.MaskHasClass(use.classMask, player)
  end
  if type(use) ~= "table" or use.kind ~= "spell" then
    return false
  end
  local classId = tonumber(use.classId) or 0
  local player = tonumber(playerClass)
  return classId ~= 0 and player ~= nil and classId ~= player
end

-- Whether one use is current for this player. Pure. A class spell use (brief P5b) is current only
-- for the player's own class, or for everyone at classId 0, and never while the class is unknown.
-- Brief QS2b: nor a quest only the other side's players were seen taking (Keep.SeenOtherSideQuest),
-- so the API's quests.needs and starts leave it out as Keep.ScoreUses does.
function Keep.IsCurrent(use, playerLevel, playerFaction, playerClass)
  if
    type(use) ~= "table"
    or Keep.OtherSide(use.faction, playerFaction)
    or Keep.SeenOtherSideQuest(use, playerFaction)
  then
    return false
  end
  if use.kind == "spell" then
    local classId = tonumber(use.classId) or 0
    return classId == 0 or (tonumber(playerClass) ~= nil and classId == tonumber(playerClass))
  end
  -- Brief TB10: a class locked consumable is current for a class its mask names, and never while
  -- the player's class is not known. Its required skill (reqSkill) is not a profession the client
  -- lists, so it is taken as met.
  if use.kind == "class" then
    return tonumber(playerClass) ~= nil and Keep.MaskHasClass(use.classMask, playerClass)
  end
  -- Brief Q1: a quest grey for the player (Keep.QuestGrey) is behind them.
  if use.kind == "quest" and Keep.QuestGrey(use, playerLevel) then
    return false
  end
  -- Brief INT1b: a class quest for other classes is never the player's (Keep.QuestOtherClass).
  if use.kind == "quest" and Keep.QuestOtherClass(use, playerClass) then
    return false
  end
  local level = use.level
  if level == nil or level >= Keep.ENDGAME then
    return true
  end
  local player = tonumber(playerLevel)
  if player == nil then
    return true
  end
  return level >= player - Keep.BEHIND
end

-- Brief K1: the name a skill line goes by, or nil where the tables do not name it. Pure.
local function skillName(skill)
  local d = data()
  if not d or type(d.GetSkill) ~= "function" or type(skill) ~= "number" then
    return nil
  end
  local ok, row = pcall(d.GetSkill, d, skill)
  if ok and type(row) == "table" and type(row.n) == "string" and row.n ~= "" then
    return row.n
  end
  return nil
end
Keep.SkillName = skillName

-- Brief K1: whether a recipe's skill line is one of the player's professions. professions is a set
-- of skill line ids; a build can list one profession on two skill lines (Blacksmithing on 164 and
-- 2938), so a line that shares its name with one in the set counts too. Pure.
function Keep.IsOwnSkill(skill, professions)
  if type(professions) ~= "table" or type(skill) ~= "number" then
    return false
  end
  if professions[skill] then
    return true
  end
  local name = skillName(skill)
  if not name then
    return false
  end
  for id, on in pairs(professions) do
    if on and type(id) == "number" and skillName(id) == name then
      return true
    end
  end
  return false
end

-- Brief SE1: how many items a vendor's price buys, from the item row's vs (VendorStackCount,
-- shipped above 1 only, as Sources.BundleCount reads it for the price words): a whole count of 2 or
-- more, else 1 (nil, 1, or a value that is no count). Pure.
function Keep.BundleSize(count)
  count = tonumber(count)
  if count == nil or count ~= count or count == math.huge or count < 2 then
    return 1
  end
  return math.floor(count)
end

-- Brief K1: whether an item sold by this many vendors at this price is sold everywhere. A price
-- of nil (the data ships none) is judged on the count alone. Pure.
--
-- Brief SE1 (the owner's ruling A of 2026-10-20 on QA item 301: "The A route is simple and keeps it
-- base on vendor value"): the rule judges the price of ONE item. A vendor's price buys the bundle
-- it sells (bundle, the item row's vs; nil or 1 for one item), so the price is held against
-- CHEAP_COPPER times the bundle, the same as price / bundle against CHEAP_COPPER with no fraction:
-- Jagged Arrow's 10s buys 200 (5c each), Frog Leg Stew's 12s 50c buys 5 (2s 50c each).
function Keep.Everywhere(vendors, price, bundle)
  vendors = tonumber(vendors) or 0
  if vendors < Keep.EVERYWHERE_VENDORS then
    return false
  end
  price = tonumber(price)
  return price == nil or price <= Keep.CHEAP_COPPER * Keep.BundleSize(bundle)
end

--------------------------------------------------------------------------------
-- Brief BQ14 (the owner's QA items 14 and 43, 2026-10-10: "make the 10 x Leatherworking white with
-- the recipe colours after"): each profession use line carries the qualities of the items its
-- recipes make, a mask with bit q set for quality q (poor 0 to artifact 6), out of the Summary
-- module (Graph.UseQualities), which the tooltip draws as one small circle per quality after the
-- count, highest first. The mask covers every recipe of that profession using the item, the
-- pipeline's one answer for login and after alike.
--------------------------------------------------------------------------------

-- The highest quality a mask holds a bit for (artifact).
Keep.QUALITY_TOP = 6

-- Whether a mask holds quality q. Pure.
function Keep.HasQuality(mask, quality)
  mask, quality = tonumber(mask), tonumber(quality)
  if not mask or not quality or quality < 0 or mask <= 0 then
    return false
  end
  local bit = 2 ^ quality
  return mask % (bit * 2) >= bit
end

-- Two masks joined (a bitwise or, Lua 5.1 has none). nil and 0 are empty. Pure.
function Keep.MaskUnion(a, b)
  local out = 0
  for quality = 0, Keep.QUALITY_TOP do
    if Keep.HasQuality(a, quality) or Keep.HasQuality(b, quality) then
      out = out + 2 ^ quality
    end
  end
  return out
end

-- The qualities a mask holds, highest first ({ 4, 3, 2, 1 } for epic to common). Pure.
function Keep.MaskQualities(mask)
  local out = {}
  for quality = Keep.QUALITY_TOP, 0, -1 do
    if Keep.HasQuality(mask, quality) then
      out[#out + 1] = quality
    end
  end
  return out
end

-- The item's use qualities by skill line (Graph.UseQualities over the Summary module), or nil.
-- Guarded: nil without the graph, the data or the module.
function Keep.UseQualities(itemId)
  local Graph, d = ItemTree.Graph, data()
  local id = tonumber(itemId)
  if not id or type(Graph) ~= "table" or type(Graph.UseQualities) ~= "function" then
    return nil
  end
  if not d or type(d.Get) ~= "function" then
    return nil
  end
  local okSummary, summary = pcall(d.Get, d, "Summary")
  if not okSummary or type(summary) ~= "table" then
    return nil
  end
  local ok, masks = pcall(Graph.UseQualities, summary, id)
  return ok and type(masks) == "table" and masks or nil
end

-- Puts each group's mask on it (group.qualities): every line of masks whose skill is the group's or
-- shares its name (one profession on two skill lines, First Aid 129 and 2942), joined; nothing for a
-- group no line names. Answers groups. Pure over the Skills table.
function Keep.GroupQualities(groups, masks)
  if type(groups) ~= "table" or type(masks) ~= "table" then
    return groups
  end
  for _, group in ipairs(groups) do
    local mask = 0
    for line, held in pairs(masks) do
      if line == group.skill or (line > 0 and skillName(line) == group.name) then
        mask = Keep.MaskUnion(mask, held)
      end
    end
    if mask > 0 then
      group.qualities = mask
    end
  end
  return groups
end

-- How the working stock asks Keep.ReasonLines for its lines (spare, brief K30's lead line, with the
-- player's own lines in white; QA item 43).
Keep.SPARE_STOCK = "stock"
-- Brief TV1 (QA item 347, the owner on Linen Bandage: "Use should probably be the main one"): how a
-- [Use] keep asks for its lines: the player's own lines muted as spare, with no "Not needed to level
-- First Aid" lead (it read as a counter argument under the Use).
Keep.SPARE_QUIET = "quiet"

-- The recipe groups by profession, the player's own first, then the most recipes, then by name.
local function sortGroups(groups)
  table.sort(groups, function(a, b)
    if a.own ~= b.own then
      return a.own
    end
    if a.count ~= b.count then
      return a.count > b.count
    end
    return a.name < b.name
  end)
  return groups
end

-- Brief K18: a bucket the recipe uses are filed into by profession. groups and byName as
-- recipeGroups; plain counts the recipes no profession names, names holds their distinct shipped
-- names (Keep.RecipeName) and unnamed how many carry none; total counts every recipe filed.
local function newBucket()
  return { groups = {}, byName = {}, plain = 0, names = {}, distinct = 0, unnamed = 0, total = 0 }
end

-- Files one recipe use. A group is the player's own where Keep.IsOwnSkill says so, or (brief K18)
-- where it is the profession of the route line, routeName, which the route only ever names for a
-- profession the player is levelling. professions true groups the recipes with nobody's grey
-- (the route's list where the client did not say which professions the player has); nil only
-- counts them. Pure.
local function fileRecipe(bucket, use, professions, routeName)
  bucket.total = bucket.total + 1
  if not professions then
    return
  end
  local name = skillName(use.skill)
  if name then
    local group = bucket.byName[name]
    -- Brief UL1 (QA item 356, the owner on Formula: Runed Arcanite Rod): the recipe a recipe item
    -- teaches is counted apart (group.teaches), so no line names it (Keep.ReasonLines), and it is never
    -- the recipe a group of one names.
    local teaches = use.teaches == true
    if not group then
      -- Brief TV1 (QA item 347b): the first recipe's target too, so a group of one names that recipe
      -- (Keep.GroupWords) rather than "1 x Mining".
      group = { name = name, count = 0, own = false, skill = use.skill, first = not teaches and use.target or nil }
      bucket.byName[name] = group
      bucket.groups[#bucket.groups + 1] = group
    end
    group.count = group.count + 1
    if teaches then
      group.teaches = (group.teaches or 0) + 1
    elseif group.first == nil then
      group.first = use.target
    end
    if name == routeName or professions == true or Keep.IsOwnSkill(use.skill, professions) then
      group.own = true
    end
    return
  end
  bucket.plain = bucket.plain + 1
  local recipeName = type(use.name) == "string" and use.name ~= "" and use.name or nil
  if not recipeName then
    bucket.unnamed = bucket.unnamed + 1
  elseif not bucket.names[recipeName] then
    bucket.names[recipeName] = true
    bucket.distinct = bucket.distinct + 1
    bucket.name = recipeName
  end
end

-- The one name the recipes no profession names all share, or nil where they carry two or more
-- names, or one carries none. Pure.
local function bucketName(bucket)
  if bucket.distinct == 1 and bucket.unnamed == 0 then
    return bucket.name
  end
  return nil
end

-- Brief K22 (the owner on Rough Stone, 2026-10-05): whether a current use is the player's own,
-- so it counts towards the mark. A recipe of a profession the player lacks is not, where the
-- professions are known (a set handed in); a recipe of the route's profession (routeName) is.
-- Everything else is: quests, class spells and class uses, locks, recipes no profession names,
-- and every use while the professions are not known. Pure.
function Keep.OwnUse(use, professions, routeName)
  -- Brief TV1 (QA item 347 D1): the recipe a recipe item teaches never counts towards the mark; the
  -- recipe item's own facts keep it (Keep.RecipeKeeps).
  if type(use) == "table" and use.teaches == true then
    return false
  end
  if type(use) ~= "table" or use.kind ~= "recipe" or type(professions) ~= "table" or use.skill == nil then
    return true
  end
  if Keep.IsOwnSkill(use.skill, professions) then
    return true
  end
  return routeName ~= nil and skillName(use.skill) == routeName
end

--------------------------------------------------------------------------------
-- Brief K30 (owner QA 2026-10-09, Linen Bandage x66 read [Keep] "1 x First Aid" at First Aid 46,
-- where only First Aid Kit, grey for him, uses it: "I won't need to keep multiple stacks of them
-- forever"): a reagent of the player's own profession is kept for that reason only up to the
-- route's count, brief PR9's need (the route bands from the player's rank, stopping at grey, the
-- Professions model's Needed). The count is worked out only where every profession it rests on
-- has route data (a craft line of ProfessionTracks) and the player's rank in it is known; else
-- it is nil and everything reads as before. With a count of 0 the player's own recipe uses and
-- the route entry keep nothing (Keep.TradeSpare); with a count above 0 the item is kept as
-- before, and where the tooltip knows the player holds more than the count, the rest is the
-- item's other verdict (Keep.Tags; brief BQ16 words it "Level First Aid (200 / 131 needed)"). The other keep
-- reasons (quests, spells, class uses, chains, item combines, gear, the player's word, the
-- consumable rules) are untouched.
--------------------------------------------------------------------------------

-- Adds a skill line to a list once. Pure.
local function addLine(list, skill)
  for _, held in ipairs(list) do
    if held == skill then
      return list
    end
  end
  list[#list + 1] = skill
  return list
end

-- Brief K30: whether a use is a trade use, a recipe of one of the player's own professions (or of
-- the route's, routeName) that a profession names. Never an item combine, a recipe no profession
-- names, or any use while the professions are not known (a set handed in). Pure.
function Keep.TradeUse(use, professions, routeName)
  if type(use) ~= "table" or use.kind ~= "recipe" then
    return false
  end
  -- An item combine (a via item, Keep.FileCombine's) is never a trade use.
  if type(use.via) == "table" and #use.via > 0 then
    return false
  end
  -- Brief TV1 (QA item 347 D1, INV1's trace): nor the recipe a recipe item teaches (use.teaches), so a
  -- recipe item never enters the route's count ("Not needed to level Alchemy" on Recipe: Transmute
  -- Iron to Gold, [Vendor] on Formula: Runed Arcanite Rod at Enchanting 300).
  if use.teaches == true then
    return false
  end
  if type(professions) ~= "table" or type(use.skill) ~= "number" then
    return false
  end
  local name = skillName(use.skill)
  if not name then
    return false
  end
  return Keep.IsOwnSkill(use.skill, professions) or name == routeName
end

--------------------------------------------------------------------------------
-- Brief RB2A (QA item 250, the owner's ruling "for herbs do A" of 2026-10-18): a gathering trade's
-- own recipes (Herbalism's Incense Candle, Greenhouse and Seed Hybridizer; Skinning's Camp Chair,
-- Field Guide and Trapper's Workbench; Mining's smelts and stone recipes) keep their reagents only
-- while the recipe is not grey for the character, as the crafting trades stop at grey (ruling item
-- 12 of 2026-10-10). A gathering line has no levelling route (ProfessionTracks plans its spots, never
-- its recipes), so its recipe uses are no part of K30's count: until grey such a use keeps the item
-- as any other own use does (score.gatherLines) and never stops a crafting trade's count being worked
-- out (LH1: Skinning's Camp Chair hid "12 / 172 for Leatherworking" on Light Leather); once grey it
-- is a trade use the count holds nothing for, so it keeps nothing and, where nothing else keeps the
-- item, its line reads "Below your current Herbalism level" (brief RB2B, Keep.GatherSpareWords; the
-- crafting trades read "Not needed to level Tailoring"). The grey rank is
-- the recipe's own (Keep.RecipeWindow: the route's window for Mining's smelts, else the item tables'
-- recipe row) against the character's rank in the line (Keep.GatherRank); a rank or a grey rank not
-- known is never grey, today's answer.
--------------------------------------------------------------------------------

-- The gathering trades' skill lines (ItemTree_Professions' Model.GATHER_LINES: Herbalism, Mining,
-- Fishing, Skinning).
Keep.GATHER_LINES = { [182] = true, [186] = true, [356] = true, [393] = true }

-- Brief RB2A: whether a skill line is a gathering trade's: the route's own word for it where its lines
-- are there (lines, else the K30 facts' stand in Keep.reagentFacts, else the shipped ProfessionTracks:
-- kind "gather"), else Keep.GATHER_LINES by its id or a line of the same name (the Forever client's
-- child lines: Herbalism's 2944). Pure over the data tables.
function Keep.GatherLine(skill, lines)
  skill = tonumber(skill)
  if skill == nil then
    return false
  end
  if type(lines) ~= "table" then
    local held = Keep.reagentFacts
    local tracks = ItemTree.ProfessionTracks
    lines = type(held) == "table" and held.lines or type(tracks) == "table" and tracks.lines or nil
  end
  local entry = Keep.LineEntry(lines, skill)
  if type(entry) == "table" and type(entry.kind) == "string" then
    return entry.kind == "gather"
  end
  if Keep.GATHER_LINES[skill] then
    return true
  end
  local name = skillName(skill)
  if not name then
    return false
  end
  for line in pairs(Keep.GATHER_LINES) do
    if skillName(line) == name then
      return true
    end
  end
  return false
end

-- Brief RB2A: the character's rank in a gathering line, or nil where nothing says: the route's facts
-- (skills, the K30 facts' { [skillLine] = { rank } }), else rankOf(skillLine) (the client's skill
-- read, Keep.SkillRank), asked for the line and then for a gathering line of the same name (the client
-- lists the profession on one of the two). Brief TG1: a tracked range is never read by its rank here
-- (Keep.GreyGatherUses weighs its whole range, Keep.GatherInRange). Pure over rankOf.
function Keep.GatherRank(skill, skills, rankOf)
  skill = tonumber(skill)
  if skill == nil then
    return nil
  end
  local held = Keep.LineEntry(skills, skill)
  if type(held) == "table" and tonumber(held.rank) then
    return tonumber(held.rank)
  end
  if type(rankOf) ~= "function" then
    return nil
  end
  local ok, rank = pcall(rankOf, skill)
  if ok and tonumber(rank) then
    return tonumber(rank)
  end
  local name = skillName(skill)
  for line in pairs(Keep.GATHER_LINES) do
    if line ~= skill and name ~= nil and skillName(line) == name then
      ok, rank = pcall(rankOf, line)
      if ok and tonumber(rank) then
        return tonumber(rank)
      end
    end
  end
  return nil
end

-- Brief RB2A: whether one use is a gathering trade's recipe that is grey at rank: its grey rank
-- (Keep.RecipeWindow over lines, the ProfessionTracks lines, else the item tables) at or under the
-- rank. False for any other use, and where the rank or the grey rank is not known. Pure over the
-- data tables.
function Keep.GatherGrey(use, rank, lines)
  rank = tonumber(rank)
  if type(use) ~= "table" or use.kind ~= "recipe" or rank == nil or not Keep.GatherLine(use.skill) then
    return false
  end
  local Graph = ItemTree.Graph
  if not Graph or type(Graph.Parse) ~= "function" or type(use.target) ~= "string" then
    return false
  end
  local kind, spell = Graph.Parse(use.target)
  spell = kind == "spell" and tonumber(spell) or nil
  if spell == nil then
    return false
  end
  local _, th = Keep.RecipeWindow(spell, use.skill, lines)
  return th ~= nil and rank >= th
end

-- Brief TG1 (the Fable review's M2, QA item 260, and the owner's ruling "A" of 2026-10-18: "a tracked
-- gathering line keeps only the recipes its chosen range can make"): whether a gathering trade's recipe
-- is one a range from lo to hi can make: its learn rank (Keep.RecipeWindow's r, the route's window
-- for Mining, else the item tables') at or under hi, and its grey rank above lo (no grey rank: never
-- grey). False where the learn rank or either end is not known. Herbalism 1 to 50 makes Incense Candle
-- (20, grey 25), not Greenhouse (140) or Seed Hybridizer (300). Pure over the data tables.
function Keep.GatherInRange(use, lo, hi, lines)
  lo, hi = tonumber(lo), tonumber(hi)
  if type(use) ~= "table" or use.kind ~= "recipe" or lo == nil or hi == nil then
    return false
  end
  local Graph = ItemTree.Graph
  if not Graph or type(Graph.Parse) ~= "function" or type(use.target) ~= "string" then
    return false
  end
  local kind, spell = Graph.Parse(use.target)
  spell = kind == "spell" and tonumber(spell) or nil
  if spell == nil then
    return false
  end
  local r, th = Keep.RecipeWindow(spell, use.skill, lines)
  if r == nil or r > hi then
    return false
  end
  return th == nil or th > lo
end

-- Brief TG1: the range a gathering line is tracked at, lo and hi, or nil where the line is the
-- character's own: the route's facts' skills entry the tracked list makes (Core/TrackedProfessions.lua
-- Tracked.SkillsOf: { rank = lo, top = hi, lo, hi, tracked = true }). Where own (the character's own
-- professions, Keep.Score's full.ownProfessions) is handed in and leaves the line out, it is a tracked
-- one whatever the skills say: false, false where no range is read for it (it makes nothing). Pure.
function Keep.TrackedRange(skill, skills, own)
  local held = Keep.LineEntry(skills, tonumber(skill))
  if type(held) == "table" and held.tracked == true then
    local lo = tonumber(held.lo) or tonumber(held.rank)
    local hi = tonumber(held.hi) or tonumber(held.top)
    if lo and hi then
      return lo, hi
    end
    return false, false
  end
  if type(own) == "table" and not Keep.IsOwnSkill(tonumber(skill), own) then
    return false, false
  end
  return nil, nil
end

-- Brief RB2A: the gathering trade recipe uses of the character's own professions that are grey for
-- it, as a set { [use] = true } (Keep.GatherGrey at Keep.GatherRank's rank), empty for none. skills,
-- rankOf and lines as Keep.GatherRank and Keep.GatherGrey take them. Brief TG1 (the owner's ruling
-- "A"): a gathering line the character only tracks (Keep.TrackedRange, own the character's own
-- professions where tracked ones joined professions) files every recipe its range cannot make
-- (Keep.GatherInRange) as grey, so it keeps nothing; a line the character has is as RB2A left it.
-- Pure over the data tables and rankOf.
function Keep.GreyGatherUses(uses, professions, skills, rankOf, lines, own)
  local grey = {}
  if type(professions) ~= "table" then
    return grey
  end
  for _, use in ipairs(type(uses) == "table" and uses or EMPTY) do
    if
      type(use) == "table"
      and use.kind == "recipe"
      and Keep.GatherLine(use.skill)
      and Keep.IsOwnSkill(tonumber(use.skill), professions)
    then
      local lo, hi = Keep.TrackedRange(use.skill, skills, own)
      if lo ~= nil then
        if not (lo and Keep.GatherInRange(use, lo, hi, lines)) then
          grey[use] = true
        end
      elseif Keep.GatherGrey(use, Keep.GatherRank(use.skill, skills, rankOf), lines) then
        grey[use] = true
      end
    end
  end
  return grey
end

-- Brief RB2A: whether every line of a non empty list is a gathering line (Keep.GatherLine). Pure.
function Keep.GatherOnly(lines)
  if type(lines) ~= "table" or #lines == 0 then
    return false
  end
  for _, skill in ipairs(lines) do
    if not Keep.GatherLine(skill) then
      return false
    end
  end
  return true
end

-- Brief RB2A: whether a gathering trade's recipe of the player's own that is current and not grey yet
-- (not in grey, Keep.GreyGatherUses' set) is among the uses: an own use that keeps the item whole,
-- whatever the route's count says. Pure.
function Keep.GatherKeeps(uses, playerLevel, playerFaction, playerClass, professions, grey)
  if type(professions) ~= "table" then
    return false
  end
  for _, use in ipairs(type(uses) == "table" and uses or EMPTY) do
    if
      Keep.TradeUse(use, professions)
      and Keep.GatherLine(use.skill)
      and not (type(grey) == "table" and grey[use] == true)
      and Keep.IsCurrent(use, playerLevel, playerFaction, playerClass)
    then
      return true
    end
  end
  return false
end

-- Brief RB2A: Keep.TradeUse for the route's count: a gathering trade's recipe counts only once grey
-- (grey, Keep.GreyGatherUses' set; nil for none), so until then it is an own use the count leaves
-- alone. Pure.
function Keep.CountedTradeUse(use, professions, routeName, grey)
  if not Keep.TradeUse(use, professions, routeName) then
    return false
  end
  if Keep.GatherLine(use.skill) then
    return type(grey) == "table" and grey[use] == true
  end
  return true
end

-- Brief K30: the skill lines the route's count must cover for one item, in use order: those of its
-- current trade uses (Keep.TradeUse over the uses Keep.ScoreUses counts current), then the route
-- entry's (profession, Keep.ProfessionRelevant's), once each. nil where the professions are not
-- known; an empty list where it has none. Brief RB2A: a gathering trade's recipe is among them only
-- once grey (grey, Keep.GreyGatherUses' set; Keep.CountedTradeUse). Pure.
function Keep.TradeLines(uses, playerLevel, playerFaction, playerClass, professions, profession, grey)
  if type(professions) ~= "table" then
    return nil
  end
  local routeLine = type(profession) == "table" and tonumber(profession.skillLine) or nil
  local routeName = routeLine and skillName(routeLine) or nil
  local lines = {}
  for _, use in ipairs(uses or EMPTY) do
    if
      Keep.CountedTradeUse(use, professions, routeName, grey)
      and Keep.IsCurrent(use, playerLevel, playerFaction, playerClass)
    then
      addLine(lines, use.skill)
    end
  end
  if routeLine then
    addLine(lines, routeLine)
  end
  return lines
end

-- Brief K30: the entry of map (a table keyed by skill line id) for a skill line: its own, else the
-- one keyed by a line of the same name (a build can list one profession on two lines, as
-- Keep.IsOwnSkill reads them: First Aid's 129 and 2942). nil for none. Pure.
function Keep.LineEntry(map, skill)
  if type(map) ~= "table" or type(skill) ~= "number" then
    return nil
  end
  if map[skill] ~= nil then
    return map[skill]
  end
  local name = skillName(skill)
  if not name then
    return nil
  end
  for id, entry in pairs(map) do
    if type(id) == "number" and skillName(id) == name then
      return entry
    end
  end
  return nil
end

-- Brief K30: the route's count for one item's trade lines (Keep.TradeLines), or nil where it
-- cannot be worked out: no lines, a line with no route data (no craft line in tracks, the
-- ProfessionTracks lines table, or one with no bands: a gathering line's smelts are never a
-- route), or a line the player's skills ({ [skillLine] = { rank } }) hold no rank for. Else the
-- need of entry (the Professions model's Needed entry for the item, { need }), 0 where there is
-- none. Brief RB2A (QA item 250): a gathering line is no part of the count and never stops it being
-- worked out (Keep.TradeLines names one only for a recipe grey for the player, which keeps nothing):
-- it adds nothing, and lines that are all gathering lines count 0. Pure.
function Keep.ReagentNeed(lines, tracks, skills, entry)
  if type(lines) ~= "table" or #lines == 0 or type(tracks) ~= "table" or type(skills) ~= "table" then
    return nil
  end
  local crafting = 0
  for _, skill in ipairs(lines) do
    local line = Keep.LineEntry(tracks, skill)
    if not Keep.GatherLine(skill, tracks) then
      if type(line) ~= "table" or type(line.bands) ~= "table" or #line.bands == 0 then
        return nil
      end
      local held = Keep.LineEntry(skills, skill)
      if type(held) ~= "table" or tonumber(held.rank) == nil then
        return nil
      end
      crafting = crafting + 1
    end
  end
  if crafting == 0 then
    return 0
  end
  local need = type(entry) == "table" and tonumber(entry.need) or nil
  if need == nil or need < 0 then
    return 0
  end
  return math.floor(need)
end

-- Brief K30: whether the player's own trade uses and the route entry keep nothing: the score is
-- Keep.TradeFree's view, or the route's count was worked out at 0. Pure.
function Keep.TradeSpare(score)
  if type(score) ~= "table" then
    return false
  end
  return score.tradeFree == true or tonumber(score.reagentNeed) == 0
end

-- Brief K30: a view of the score with the trade reasons left out, for the item's other verdict
-- (the surplus beyond the route's count): a shallow copy with tradeFree set and no route entry.
-- Pure.
function Keep.TradeFree(score)
  local view = {}
  for key, value in pairs(type(score) == "table" and score or EMPTY) do
    view[key] = value
  end
  view.tradeFree = true
  view.profession = nil
  -- Brief BQ18: the working stock is a trade reason too.
  view.stockFree = true
  return view
end

-- Brief K30: whether an item that is not kept has trade uses the route's count left out (a count
-- of 0), so its lines say so (Keep.SpareWords). Pure.
function Keep.ReagentSpare(score)
  return type(score) == "table"
    and tonumber(score.reagentNeed) == 0
    and (tonumber(score.tradeUses) or 0) > 0
    and type(score.tradeLines) == "table"
end

--------------------------------------------------------------------------------
-- Brief BQ18 (the owner's ruling of 2026-10-10, QA item 12: Light Hide read [Vendor] "Not needed to
-- level Leatherworking", "it's still used in LW and could create gear"): the WORKING STOCK tier. A
-- reagent the route's count leaves at 0 (off the levelling route: K30's count of 0, Keep.ReagentSpare)
-- that the player's own profession can use now is kept up to ONE FULL STACK (one bag slot, the item's
-- stack size, no setting) while a recipe of that profession uses it, directly or through one
-- intermediate (the chain followed two levels: Light Hide > Cured Light Hide > Hillman's Leather
-- Vest), whose product is still useful to the player: gear the K27 compare calls an upgrade for any
-- enabled spec, within the gear window (Keep.GearWithin), or a consumable the consumable rules keep.
-- A recipe counts where the player can learn it within STOCK_REACH ranks of their own (the owner's
-- Shadowgem case: Brawler's Leather Gloves, learnt at 75, "within reach of rank 60") and, for the
-- recipe that makes the useful product, while it is not grey at the player's rank; an intermediate's
-- recipe needs only be learnable. The windows are the route's own (ProfessionTracks, through the K30
-- facts), else the item tables'. Over the stack the rest is the item's other verdict (Auction or
-- Vendor), as past the route's count (K30); with no such recipe, or every product below what the
-- player wears, the keep ends by itself. The route's count stays above it: the tier is only ever
-- worked out for a count of 0.
--------------------------------------------------------------------------------

Keep.KEEP_STOCK = "stock"
-- How far above the player's rank a recipe still counts as learnable now.
Keep.STOCK_REACH = 15
-- The most products the walk judges for one reagent, direct and through an intermediate together.
Keep.STOCK_PRODUCTS = 40

-- Brief BQ18: one recipe's learn rank and grey rank: the route's window (the ProfessionTracks line's
-- recipe row, lines its lines table: r, th), else the item tables' recipe row (r, else tl, as the
-- learn rank; th). nil, nil where neither states a rank. Also the row's side (fa) where the route
-- names one. Pure over the data tables.
function Keep.RecipeWindow(spellId, skill, lines)
  local line = Keep.LineEntry(lines, tonumber(skill))
  local recipes = type(line) == "table" and type(line.recipes) == "table" and line.recipes or nil
  local held = recipes and recipes[spellId] or nil
  if type(held) == "table" and (tonumber(held.r) or tonumber(held.tl)) then
    return tonumber(held.r) or tonumber(held.tl), tonumber(held.th), tonumber(held.fa)
  end
  local d = data()
  if not d or type(d.GetRecipe) ~= "function" or type(spellId) ~= "number" then
    return nil, nil, nil
  end
  local ok, recipe = pcall(d.GetRecipe, d, spellId)
  if not ok or type(recipe) ~= "table" then
    return nil, nil, nil
  end
  local learn = tonumber(recipe.r) or tonumber(recipe.tl)
  if learn == nil then
    return nil, nil, nil
  end
  return learn, tonumber(recipe.th), nil
end

-- Brief BQ18: whether a recipe of learn rank r and grey rank th counts at the player's rank: learnable
-- within Keep.STOCK_REACH, and (where points is true) not grey there. No grey rank is never grey.
-- Pure.
function Keep.StockRecipeOk(r, th, rank, points)
  r, rank = tonumber(r), tonumber(rank)
  if r == nil or rank == nil or r > rank + Keep.STOCK_REACH then
    return false
  end
  if points then
    th = tonumber(th)
    return th == nil or th > rank
  end
  return true
end

-- Brief BQ18: what a product is to the player, "gear" (an upgrade the K27 compare keeps, within the
-- gear window: Keep.GearFacts and Keep.GearUpgrade over ctx.worn, the player's class, level and
-- enabled specs), "consumable" (one the consumable rules keep: the shipped facts' Judge where they
-- cover it, else Keep.CouldUse), or nil. ctx: { classId, level, worn, enabledSpecs, skillRank,
-- maxLevel, pools, effects }. Pure over the data tables and Core/Gear.lua.
function Keep.ProductUse(productId, ctx)
  local row = itemRow(tonumber(productId))
  if type(row) ~= "table" then
    return nil
  end
  ctx = type(ctx) == "table" and ctx or EMPTY
  if Keep.EQUIPMENT_CLASSES[tonumber(row.c) or -1] then
    local facts = Keep.GearFacts(row, ctx.worn, ctx.classId, ctx.level, ctx.enabledSpecs)
    if Keep.GearUpgrade({ gear = facts }) then
      return "gear"
    end
    return nil
  end
  if tonumber(row.c) ~= Keep.CONSUMABLE_CLASS then
    return nil
  end
  local consumables = ItemTree.Consumables
  if type(consumables) == "table" and type(consumables.Facts) == "function" then
    local module = ctx.effects
    if module == nil and type(consumables.Module) == "function" then
      local okModule, read = pcall(consumables.Module)
      module = okModule and read or nil
    end
    local okFacts, facts = pcall(consumables.Facts, tonumber(productId), module)
    if okFacts and facts and type(consumables.Judge) == "function" then
      local pools = ctx.pools
      if type(pools) == "function" then
        local okPools, read = pcall(pools)
        pools = okPools and type(read) == "table" and read or nil
      end
      local okJudge, judged = pcall(consumables.Judge, facts, row, {
        classId = ctx.classId,
        level = ctx.level,
        maxLevel = ctx.maxLevel or Keep.MAX_LEVEL,
        pools = pools,
        rankOf = ctx.skillRank,
        module = module,
        specs = ctx.enabledSpecs,
      })
      if okJudge and type(judged) == "table" and judged.keep == true then
        return "consumable"
      end
      return nil
    end
  end
  if Keep.CouldUse(row, ctx.classId, ctx.level, ctx.skillRank, nil, ctx.maxLevel) then
    return "consumable"
  end
  return nil
end

-- Brief ST4 (bin D): whether the item is a consumable the shipped consumable facts cover
-- (Consumables.Facts over the ItemEffects module, module the caller's or the shipped one). Pure over
-- the data tables.
function Keep.JudgedConsumable(itemId, module)
  local row = itemRow(tonumber(itemId))
  if type(row) ~= "table" or tonumber(row.c) ~= Keep.CONSUMABLE_CLASS then
    return false
  end
  local consumables = ItemTree.Consumables
  if type(consumables) ~= "table" or type(consumables.Facts) ~= "function" then
    return false
  end
  if module == nil and type(consumables.Module) == "function" then
    local okModule, read = pcall(consumables.Module)
    module = okModule and read or nil
  end
  local ok, facts = pcall(consumables.Facts, tonumber(itemId), module)
  return ok and facts ~= nil or false
end

-- Brief BQ18: the working stock facts for one reagent, or nil: { cap, skill, product, useful, kind,
-- spell, via }, cap the item's stack size (one bag slot), skill the player's profession line, product
-- the first recipe's product (the item the line names: "your Leatherworking makes Cured Light Hide"),
-- useful the product that is still useful (product itself, or what the intermediate makes), kind
-- Keep.ProductUse's answer for it, spell the first recipe, via the second where the chain took one.
-- uses are the item's (Keep.Uses), in the graph's order, the first that holds wins. ctx is
-- Keep.ProductUse's plus { professions (the player's set), skills ({ [skillLine] = { rank } }, the K30
-- facts'), lines (ProfessionTracks lines), faction, stack (the item's stack size) }. Pure over the
-- data tables and Core/Gear.lua.
function Keep.StockFacts(itemId, uses, ctx)
  ctx = type(ctx) == "table" and ctx or EMPTY
  local Graph = ItemTree.Graph
  if type(uses) ~= "table" or type(ctx.professions) ~= "table" or type(ctx.skills) ~= "table" then
    return nil
  end
  if not Graph or type(Graph.Parse) ~= "function" then
    return nil
  end
  local id = tonumber(itemId)
  -- Brief ST4 (bin D, the owner's QA of 2026-10-10): a consumable the shipped consumable facts judge
  -- (a bandage, a food) is working stock only while its own verdict keeps it (Keep.ProductUse over the
  -- item itself: the share, "Too weak for your level"), the over levelled check the rest of the tier
  -- has. Linen Bandage makes the First Aid Kit, a recipe with no grey rank, so the walk alone kept a
  -- stack of it at First Aid 150 on a level 40; at 15 (66 of 280 health) it still keeps one stack.
  if Keep.JudgedConsumable(id, ctx.effects) and Keep.ProductUse(id, ctx) ~= "consumable" then
    return nil
  end
  local judged, count = {}, 0
  local function useOf(productId)
    if judged[productId] == nil then
      if count >= Keep.STOCK_PRODUCTS then
        return nil
      end
      count = count + 1
      judged[productId] = Keep.ProductUse(productId, ctx) or false
    end
    return judged[productId] or nil
  end
  -- Brief RB2A (QA item 254, the owner's ruling "A. No" of 2026-10-18): a profession the character
  -- only tracks (the skills entry Core/TrackedProfessions.lua marks tracked) holds no rank here, so the
  -- working stock never keeps for it: a tracked range keeps its own band's items alone (TP1b).
  local function rankIn(skill)
    local held = Keep.LineEntry(ctx.skills, skill)
    if type(held) ~= "table" or held.tracked == true then
      return nil
    end
    return tonumber(held.rank)
  end
  local function own(skill, faction)
    return type(skill) == "number"
      and Keep.IsOwnSkill(skill, ctx.professions)
      and not Keep.OtherSide(faction, ctx.faction)
  end
  local cap = Keep.StackSize({ stack = ctx.stack })
  for _, use in ipairs(uses) do
    if use.kind == "recipe" and own(use.skill, use.faction) and not (type(use.via) == "table" and #use.via > 0) then
      local kind, spell = Graph.Parse(use.target)
      spell = kind == "spell" and tonumber(spell) or nil
      local rank = rankIn(use.skill)
      local r, th, fa = Keep.RecipeWindow(spell, use.skill, ctx.lines)
      local product = spell and productOf(spell) or nil
      if
        product
        and product ~= id
        and not Keep.OtherSide(fa, ctx.faction)
        and Keep.StockRecipeOk(r, th, rank, false)
      then
        local direct = Keep.StockRecipeOk(r, th, rank, true) and useOf(product) or nil
        if direct then
          return { cap = cap, skill = use.skill, product = product, useful = product, kind = direct, spell = spell }
        end
        local reagentOf = productRecipes(product)
        for _, second in ipairs(reagentOf or EMPTY) do
          local skill = type(second) == "number" and Keep.RecipeSkill(second) or nil
          if skill and own(skill) then
            local r2, th2, fa2 = Keep.RecipeWindow(second, skill, ctx.lines)
            local made = productOf(second)
            if
              made
              and made ~= id
              and not Keep.OtherSide(fa2, ctx.faction)
              and Keep.StockRecipeOk(r2, th2, rankIn(skill), true)
            then
              local found = useOf(made)
              if found then
                return {
                  cap = cap,
                  skill = use.skill,
                  product = product,
                  useful = made,
                  kind = found,
                  spell = spell,
                  via = second,
                }
              end
            end
          end
        end
      end
    end
  end
  return nil
end

-- Brief BQ18: the stack the working stock keeps (score.stock.cap), or nil for none or a view with the
-- stock left out (Keep.StockFree). Pure.
function Keep.StockCap(score)
  if type(score) ~= "table" or score.stockFree == true or type(score.stock) ~= "table" then
    return nil
  end
  return tonumber(score.stock.cap)
end

-- Brief BQ18: a view of the score with the working stock left out, for the item's other verdict past
-- the stack: a shallow copy with stockFree set. Pure.
function Keep.StockFree(score)
  local view = {}
  for key, value in pairs(type(score) == "table" and score or EMPTY) do
    view[key] = value
  end
  view.stockFree = true
  return view
end

-- Brief BQ18: whether the player holds more than the stack the working stock keeps: the cap where so,
-- else nil. have nil (the bags, the API) is never more. Pure.
function Keep.StockSurplus(score, have)
  local cap = Keep.StockCap(score)
  have = tonumber(have)
  if cap == nil or have == nil or have <= cap then
    return nil
  end
  return cap
end

-- Brief K22: the via item of a combine use the player carries (opts.carried, a set the client side
-- hands in, true for a via item in the bags), else nil. Pure.
local function carriedVia(use, carried)
  if type(carried) ~= "table" then
    return nil
  end
  for _, via in ipairs(use.via) do
    if carried[via] == true then
      return via
    end
  end
  return nil
end

-- Brief K22: whether a use is an item combine with a via item (Keep.CombineVia). Pure.
local function isViaCombine(use)
  return use.kind == "recipe" and type(use.via) == "table" and #use.via > 0
end

-- Brief K22: the most item combine lines one item lists.
Keep.COMBINE_LINES = 3

-- Brief K22: files one item combine use on a score: its line, and where via (the via item the
-- player carries) is given, a current use of the player's own that marks the item. Pure.
function Keep.FileCombine(score, use, via)
  score.combines = score.combines or {}
  score.combines[#score.combines + 1] = {
    via = via or use.via[1],
    count = tonumber(use.quantity) or 1,
    carried = via ~= nil,
    -- Brief UL2 (QA item 366): a supply crate (Keep.CombineCrate), the one kind drawn in the need shape.
    crate = use.crate == true or nil,
  }
  if via == nil then
    return score
  end
  if use.crate == true then
    score.carriedCrates = (tonumber(score.carriedCrates) or 0) + 1
  end
  score.current = score.current + 1
  score.ownCurrent = (tonumber(score.ownCurrent) or 0) + 1
  score.kinds.recipe = (score.kinds.recipe or 0) + 1
  score.carriedCombines = (tonumber(score.carriedCombines) or 0) + 1
  score.carried = true
  return score
end

-- Brief K22: the combine lines, a carried one first (so the line that keeps the item is never
-- capped away), then the most needed, then by the via item's id, capped at Keep.COMBINE_LINES.
-- Pure.
function Keep.SortCombines(score)
  local list = type(score) == "table" and score.combines or nil
  if type(list) ~= "table" then
    return score
  end
  table.sort(list, function(a, b)
    if a.carried ~= b.carried then
      return a.carried
    end
    if a.count ~= b.count then
      return a.count > b.count
    end
    return a.via < b.via
  end)
  for index = #list, Keep.COMBINE_LINES + 1, -1 do
    list[index] = nil
  end
  return score
end

-- The score over a list of uses. Pure, and what Keep.Score answers:
--   current, stale   how many uses count and how many do not
--   endgame          whether any current use is at ENDGAME or above
--   top              the highest level among the current uses, or nil
--   kinds            { recipe = n, quest = n, lock = n } over the current uses
--   allEndgame       whether every current use has a known level at ENDGAME or above
--   own              the item's own required level, else its item level, or nil
--   spells           the targets of the current class spell uses, in order (brief P5b)
--   otherClasses     the class ids of the class spell uses that belong to another class, sorted
--                    and once each; such a use is neither current nor stale
--   lo, hi           the lowest and highest level among the current uses with a level, or nil
--                    where none has one (brief Q9a: the tooltip's level bracket)
--   staleLo, staleHi the same over the stale uses
--   staleKinds       { recipe = n, quest = n, lock = n } over the stale uses
-- and, brief K1, from opts (all optional):
--   questNeed        brief Q1: how many of the item the current (open) quest uses ask for in
--                    all, nil where none is open, one states no count or one is a quest the item
--                    starts (Keep.QuestKeepUpTo)
--   questIds         brief BQ16: the open quest uses' quest ids, in use order, nil for none
--   questsPredicted  brief GF6: how many of the open needs rest on the predicted facts alone (a
--                    new Forever quest's objective, use.predicted), nil for none; predictedQuests
--                    their quest ids as a set. An internal note: no line shows it (the owner's
--                    ruling of 2026-10-14, "Remove the predicted text")
--   questsAhead      brief Q1: the quest needs out of the player's reach (Keep.QuestOutOfReach),
--                    neither current nor stale; nil for none
--   questsAheadFrom  QA item 158 (the owner, 2026-10-14): the lowest minimum level among those, the
--                    level the first of them can be taken from (the tooltip's folded "5 quests from
--                    level 50", UI/Tooltip.lua Tooltip.FoldAheadQuests); nil with none
--   questsOtherClass brief INT1b: the class quests for other classes than the player's
--                    (Keep.QuestOtherClass), neither current nor stale; nil for none
--   otherClassMasks  brief HF1: the class masks of those the item page lists (not of the side
--                    "Hide other faction data" hides), one per quest, for the tooltip's "1
--                    Paladin quest" (UI/Tooltip.lua Tooltip.OtherQuestLines); nil for none
--   otherClassSeenOther  brief RB1d: how many of those masks are of quests nothing sides that only the
--                    other side's players were seen taking (Keep.SeenOtherSideQuest), which the
--                    tooltip's count already leaves out (UI/Tooltip.lua Tooltip.WithoutOtherQuests);
--                    nil for none
--   questsOtherSide  brief QS1 (the owner's ruling A of 2026-10-14): the quests of the other side
--                    (Keep.OtherSideQuest), no use at all for this character: neither current
--                    nor stale, never done, in no count line; nil for none. Brief F155: only while
--                    "Hide other faction data" is on (opts.hideOtherSide, else the setting); off,
--                    each is a stale use, as before QS1
--   questsShownOtherSide  brief HF1: with the setting off, how many of those stale uses are the
--                    other side's quests (the tooltip's "4 Horde quests"); nil for none
--   questsSeenOtherSide  brief QS2b: the quests nothing sides that only the other side's players
--                    were seen taking (Keep.SeenOtherSideQuest): no use for this character, neither
--                    current nor stale, never done, whatever the setting says; nil for none
--   done             how many quest uses were skipped because opts.completed(questId) said the
--                    player has done that quest, or (brief TB4) opts.abandoned(questId) said the
--                    player dropped it; they are neither current nor stale
--   abandoned        brief TB4: how many of those were abandoned
-- and, brief TB10:
--   classUse         the current class use, for its words
--   forClasses       the class ids of a class use another class has, sorted; neither current
--                    nor stale
--   unjudged         how many class uses were left out because the player's class is not known
-- and, brief TB9, with professions only (Keep.ScoreChains): chained, chainGroups
--   recipeGroups     where opts.professions (a set of skill line ids) is given: the current
--                    recipes by profession, { { name, count, own, skill } }, the player's own
--                    first; skill is the first skill line id seen for that name (brief K11:
--                    its glyph); nil without it
--   plainRecipes     the current recipes no profession names (with recipeGroups only)
--   plainName        brief K18: the one shipped name those recipes share ("Replace Supplies"),
--                    nil where they carry two or more names or one carries none
--   vendors, price   opts.vendors and opts.price as handed in
--   bundle           brief SE1: opts.bundle, the count the price buys (the item row's vs), or nil
--   everywhere       Keep.Everywhere(vendors, price, bundle)
--   override         opts.override where it is "always", "never" (brief K4) or "off" (brief
--                    K5), else nil
-- and, brief K9:
--   value            opts.value, the item's auction value in copper from an installed auction
--                    addon (Core/Prices.lua), or nil
--   valueSource      opts.valueSource, the name of the addon the value came from
--   valuable         whether the value is at or above the Keep value setting (Keep.Valuable)
-- and, brief PR4:
--   profession       opts.profession, the route entry { skillLine, lo, hi } (brief PR4), else nil
-- and, brief K18, only where profession is set (the Professions module is on and its route needs
-- the item), the list the Keep block draws: every recipe use the item has, current or below the
-- player's level, so the lines add up to the item's whole recipe count:
--   listRecipes      how many recipe uses in all
--   listGroups       those recipes by profession, recipeGroups' shape and order, the route's own
--                    profession counted as the player's; without professions none is grey
--   listPlain        those no profession names
--   listPlainName    the one name they share, as plainName
-- and, brief K22 (the mark reads these through Keep.Counted and Keep.CountedEndgame):
--   ownCurrent       how many current uses are the player's own (Keep.OwnUse); current itself
--                    still counts every current use, for the lines and the stale words
--   ownEndgame       whether any of the player's own current uses is at ENDGAME or above
--   ownRecipes       how many of those are recipes (an item combine carried not among them)
--   combines         the item combines with a via item, { { via = the item id the line names,
--                    count = how many of this item it takes, carried = true or false } }, the
--                    most needed first, at most Keep.COMBINE_LINES; nil for none. One the player
--                    carries the via item of (opts.carried, a set of item ids) is current and
--                    the player's own whatever its level; one they do not, or where opts.carried
--                    is not handed in, is neither current nor stale
--   carried          true where a carried combine marks the item
--   carriedCombines  how many carried combines current and kinds.recipe count
-- and, brief RB2A (QA item 250), with opts.gatherGrey (Keep.GreyGatherUses' set):
--   gatherLines      the gathering trades' lines (Keep.GatherLine) of the player's own current
--                    recipe uses that are not grey, which keep the item as any own use does and are
--                    no trade use (Keep.CountedTradeUse); a grey one is a trade use (tradeUses,
--                    tradeLines) the route's count holds nothing for
function Keep.ScoreUses(uses, playerLevel, playerFaction, own, playerClass, opts)
  opts = type(opts) == "table" and opts or EMPTY
  local completed = type(opts.completed) == "function" and opts.completed or nil
  local abandoned = type(opts.abandoned) == "function" and opts.abandoned or nil
  -- Brief IW1 (the owner's ruling 1B): whether a quest is in the log (Keep.QuestInLog on the client).
  local onQuest = type(opts.onQuest) == "function" and opts.onQuest or nil
  local professions = type(opts.professions) == "table" and opts.professions or nil
  local score = {
    current = 0,
    stale = 0,
    done = 0,
    abandoned = 0,
    endgame = false,
    kinds = {},
    staleKinds = {},
    own = own,
    spells = {},
    otherClasses = {},
    vendors = tonumber(opts.vendors),
    price = tonumber(opts.price),
    -- Brief SE1: the bundle the price buys, so sold everywhere judges one item's price.
    bundle = tonumber(opts.bundle),
    -- Brief BQ6 (backlog 5): vendors sell it mostly in limited stock (opts.limited, Keep.LimitedStock),
    -- so it is never sold everywhere.
    limited = opts.limited == true or nil,
    override = Keep.OVERRIDES[opts.override] and opts.override or nil,
    profession = type(opts.profession) == "table" and opts.profession or nil,
    -- Brief K20a/K20b: the item row's facts the verdict reads: its stack size (prices read "each"
    -- for a stack), quality, class and bonding (1 bind on pickup and 4 quest item never go to the
    -- auction house).
    -- Brief K20c: the item's id, for the price formula's per source names.
    itemId = tonumber(opts.itemId),
    stack = tonumber(opts.stack),
    quality = tonumber(opts.quality),
    itemClass = tonumber(opts.itemClass),
    bonding = tonumber(opts.bonding),
    -- Brief K24b: the row's subclass (food and drink, rule 4) and the provisional soft keep
    -- (Keep.CouldUse) where the caller worked it out.
    subclass = tonumber(opts.subclass),
    couldUse = opts.couldUse == true or nil,
    -- Brief BQ23: a camp item (Consumables.IsCampItem), where the caller worked it out.
    campItem = opts.campItem == true or nil,
    -- Brief AA-RB (QA item 216): a toy (Keep.IsToy), where the caller worked it out.
    toy = opts.toy == true or nil,
    -- Brief JG1 (item 302): a warlock's demon grimoire (Keep.PetBookFacts), where the caller worked it
    -- out.
    petBook = type(opts.petBook) == "table" and opts.petBook or nil,
    -- Brief CB1 (item 305): a class book of the player's own class (Keep.ClassBookFacts), where the
    -- caller worked it out.
    classBook = type(opts.classBook) == "table" and opts.classBook or nil,
    -- Brief AM1 (QA item 330): ammo the worn weapon fires, in reach (Keep.AmmoFacts), where the caller
    -- worked it out.
    ammo = type(opts.ammo) == "table" and opts.ammo or nil,
    -- Brief AM3 (QA item 340): ammo the rule turned down (Keep.AmmoRejected), where the caller
    -- worked it out; Keep.Worthless reads it.
    ammoRejected = opts.ammoRejected == true or nil,
    -- Brief BQ25c: the bag rule's answer (Keep.BagFacts), where the caller worked it out.
    bag = type(opts.bag) == "table" and opts.bag or nil,
    -- Brief K26: what a food or drink does (Keep.FoodEffect), where the caller worked it out.
    foodEffect = opts.foodEffect,
    -- Brief BQ6 (backlog 5): the profession a soft kept consumable is for (Keep.ProfessionLine).
    professionUse = tonumber(opts.professionUse),
    -- Brief K25: the consumable facts' verdict (Consumables.Judge), where the data ships.
    consumable = type(opts.consumable) == "table" and opts.consumable or nil,
    -- Brief K20-wire: the gear facts (Keep.GearFacts) and the disenchant facts
    -- (Keep.DisenchantFacts) where the caller worked them out.
    gear = type(opts.gear) == "table" and opts.gear or nil,
    -- Brief ST3 (QA item 320): gear with no facts because no spec is ticked (Keep.GearOff).
    gearOff = opts.gearOff == true or nil,
    -- Brief GW1: a cosmetic piece's own facts (Keep.CosmeticFacts), where the caller worked them out.
    cosmetic = type(opts.cosmetic) == "table" and opts.cosmetic or nil,
    -- Brief TV1 (QA item 347): a companion pet item's facts (Keep.CompanionFacts) and a recipe item's
    -- (Keep.RecipeFacts), where the caller worked them out.
    companion = type(opts.companion) == "table" and opts.companion or nil,
    recipe = type(opts.recipe) == "table" and opts.recipe or nil,
    -- Brief K31: a profession tool's facts (Keep.ToolFacts), where the caller worked them out.
    tool = type(opts.tool) == "table" and opts.tool or nil,
    disenchant = type(opts.disenchant) == "table" and opts.disenchant or nil,
    -- Brief K22: the player's own current uses, which the mark counts (Keep.Counted).
    ownCurrent = 0,
    ownEndgame = false,
    ownRecipes = 0,
    carriedCombines = 0,
    -- Brief K30: the route's count for the player's own trade uses (opts.reagentNeed, Keep.Score
    -- works it out), nil where it was not worked out; and those trade uses (Keep.TradeUse).
    reagentNeed = tonumber(opts.reagentNeed),
    tradeUses = 0,
    tradeLines = {},
    -- Brief RB2A: the gathering trades' lines whose own recipe uses are not grey (no part of the count).
    gatherLines = {},
    ownEndgameOther = false,
  }
  score.everywhere = Keep.Everywhere(score.vendors, score.price, score.bundle) and not score.limited
  -- Brief K20a: the two prices where the caller read them (opts.vendor, opts.auction), else the
  -- one value of the K9 shape (opts.value, opts.valueSource).
  if opts.vendor ~= nil or opts.auction ~= nil then
    Keep.SetPrices(score, opts.vendor, opts.auction, opts.auctionSource)
  else
    Keep.SetValue(score, opts.value, opts.valueSource)
  end
  local allEndgame = true
  local otherSeen = {}
  local current = newBucket()
  -- Brief UL3 (QA item 369): the recipes behind the character, filed by profession as the current ones are
  -- (Keep.BehindLines folds each into its profession's line).
  local behind = newBucket()
  -- Brief F155: whether the other side's quests are no use at all (QS1) or stale uses (the setting
  -- off), asked once per score.
  local hidesOtherSide = Keep.HidesOtherSide(opts)
  -- Brief Q1: the open quests' count (score.questNeed).
  local questNeed, questCountless = 0, false
  -- Brief K18: the route's profession by name, and the whole list, only while the route is there.
  local routeName, every = nil, nil
  if score.profession then
    routeName = skillName(tonumber(score.profession.skillLine))
    every = newBucket()
  end
  for _, use in ipairs(uses or EMPTY) do
    if every and use.kind == "recipe" and not isViaCombine(use) then
      fileRecipe(every, use, professions or true, routeName)
    end
    local finished, dropped = false, false
    -- Brief QS1 (the owner's ruling A of 2026-10-14): a quest of the other side is not a use at all
    -- for this character, so it is never asked about. The class is weighed first (brief INT1b: a
    -- Horde mage quest is another class's for a hunter, its side never weighed). Brief F155: only
    -- while "Hide other faction data" is on (hidesOtherSide, asked once above the loop).
    local otherSide = hidesOtherSide
      and not Keep.QuestOtherClass(use, playerClass)
      and Keep.OtherSideQuest(use, playerFaction)
    -- Brief QS2b: a quest only the other side's players were seen taking is no use for this character
    -- either, whatever the setting says (it hides nothing: no list leaves it out for it). The class
    -- is weighed first, as above.
    local seenOther = not otherSide
      and not Keep.QuestOtherClass(use, playerClass)
      and Keep.SeenOtherSideQuest(use, playerFaction)
    if not otherSide and not seenOther and completed and use.kind == "quest" and type(use.questId) == "number" then
      local ok, answer = pcall(completed, use.questId)
      finished = ok and answer == true
    end
    -- Brief TB4: a quest the player took and then dropped counts as done, and says so.
    if
      not otherSide
      and not seenOther
      and not finished
      and abandoned
      and use.kind == "quest"
      and type(use.questId) == "number"
    then
      local ok, answer = pcall(abandoned, use.questId)
      dropped = ok and answer == true
    end
    if otherSide then
      score.questsOtherSide = (score.questsOtherSide or 0) + 1
      -- Brief AA-RB (QA item 219): the side a "No known uses for Alliance" line names (Keep.NoUsesWords).
      score.playerSide = playerFaction
    elseif seenOther then
      score.questsSeenOtherSide = (score.questsSeenOtherSide or 0) + 1
      score.playerSide = playerFaction
    elseif finished or dropped then
      score.done = score.done + 1
      if dropped then
        score.abandoned = score.abandoned + 1
      end
    elseif use.kind == "class" and tonumber(playerClass) == nil then
      -- Brief TB10: whose consumable it is cannot be judged while the class is not known.
      score.unjudged = (score.unjudged or 0) + 1
    elseif use.kind == "class" and Keep.OtherClass(use, playerClass) then
      -- Brief TB10: another class's consumable: neither current nor stale, and the tooltip says
      -- whose it is ("For Mages").
      score.forClasses = score.forClasses or {}
      for _, classId in ipairs(use.classIds or EMPTY) do
        if not otherSeen["class" .. classId] then
          otherSeen["class" .. classId] = true
          score.forClasses[#score.forClasses + 1] = classId
        end
      end
    elseif Keep.OtherClass(use, playerClass) then
      local classId = tonumber(use.classId)
      if not otherSeen[classId] then
        otherSeen[classId] = true
        score.otherClasses[#score.otherClasses + 1] = classId
      end
      -- Brief UL2 (QA item 367): how many, so the tooltip's fold counts them (Keep.BehindLines).
      score.otherSpellUses = (score.otherSpellUses or 0) + 1
    elseif Keep.QuestOtherClass(use, playerClass) then
      -- Brief INT1b (the owner's ruling of 2026-10-10, Q(b)): a class quest for other classes (the
      -- paladin's Tome of Divinity for a hunter): neither current nor stale, counted apart.
      score.questsOtherClass = (score.questsOtherClass or 0) + 1
      -- Brief HF1: its class, where the item page lists it (the setting does not hide its side).
      if not (hidesOtherSide and Keep.OtherSideQuest(use, playerFaction)) then
        score.otherClassMasks = score.otherClassMasks or {}
        score.otherClassMasks[#score.otherClassMasks + 1] = tonumber(use.questClasses)
        -- Brief RB1d: one the tooltip's count already leaves out as seen on the other side alone.
        if Keep.SeenOtherSideQuest(use, playerFaction) then
          score.otherClassSeenOther = (score.otherClassSeenOther or 0) + 1
        end
      end
    elseif use.provided and not Keep.ProvidedInLog(score, use, onQuest) then
      -- Brief IW1 (the owner's ruling 1B of 2026-10-22): a provided item that is not a turn in
      -- requirement keeps while its quest is in the log; out of the log it is no use now (taking the
      -- quest again gives it again): neither current nor stale, in no count.
      score.providedIdle = (score.providedIdle or 0) + 1
    elseif
      not use.provided
      and Keep.QuestOutOfReach(use, playerLevel)
      and not Keep.OtherSide(use.faction, playerFaction)
    then
      -- Brief Q1: a need whose quest the player cannot take for a while yet: neither current nor
      -- stale, counted apart. Brief F155: with "Hide other faction data" off a quest of the other side
      -- reaches here and stays stale, the rule before QS1 (with it on, otherSide took it above).
      score.questsAhead = (score.questsAhead or 0) + 1
      -- QA item 158: the level the first of them can be taken from (QuestOutOfReach read minLevel).
      local minimum = tonumber(use.minLevel)
      if minimum and (score.questsAheadFrom == nil or minimum < score.questsAheadFrom) then
        score.questsAheadFrom = minimum
      end
    elseif isViaCombine(use) then
      -- Brief K22: an item combine counts while its via item is in the bags, whatever its level.
      Keep.FileCombine(score, use, carriedVia(use, opts.carried))
      if score.carried then
        allEndgame = false
      end
    elseif Keep.IsCurrent(use, playerLevel, playerFaction, playerClass) then
      score.current = score.current + 1
      score.kinds[use.kind] = (score.kinds[use.kind] or 0) + 1
      -- Brief BQ9: a quest the item starts that the character can accept now (Keep.StartsNow).
      if score.startsNow == nil and Keep.StartsNow(use, playerLevel) then
        score.startsNow = use.questId
      end
      -- Brief Q1: what the open needs ask for, in all; unknown once one states no count or the item
      -- starts an open quest (a start item is kept whole).
      if use.kind == "quest" then
        local quantity = not use.start and whole(use.quantity) or nil
        if quantity == nil then
          questCountless = true
        else
          questNeed = questNeed + quantity
        end
        -- Brief BQ16: the open quests by id, so the need line can name one (Keep.QuestNeedWords).
        if type(use.questId) == "number" then
          score.questIds = score.questIds or {}
          score.questIds[#score.questIds + 1] = use.questId
        end
        -- Brief GF6: the open needs that rest on the predicted facts alone (questsPredicted, and
        -- predictedQuests by id): an internal note for the self test and the debug output; no line
        -- shows it (the owner's ruling of 2026-10-14).
        if use.predicted and not use.start then
          score.questsPredicted = (score.questsPredicted or 0) + 1
          if type(use.questId) == "number" then
            score.predictedQuests = score.predictedQuests or {}
            score.predictedQuests[use.questId] = true
          end
        end
      end
      -- Brief K22: only the player's own uses count towards the mark.
      if Keep.OwnUse(use, professions, routeName) then
        score.ownCurrent = score.ownCurrent + 1
        if use.kind == "recipe" then
          score.ownRecipes = score.ownRecipes + 1
        end
        -- Brief K30: a recipe of one of the player's own professions, which the route's count
        -- governs (Keep.TradeSpare).
        -- Brief RB2A (QA item 250): a gathering trade's recipe only once grey (opts.gatherGrey,
        -- Keep.GreyGatherUses' set); until then an own use the count leaves alone, its line kept
        -- apart (score.gatherLines).
        local trade = Keep.CountedTradeUse(use, professions, routeName, opts.gatherGrey)
        if trade then
          score.tradeUses = score.tradeUses + 1
          addLine(score.tradeLines, use.skill)
        elseif Keep.TradeUse(use, professions, routeName) then
          addLine(score.gatherLines, use.skill)
        end
        if use.level and use.level >= Keep.ENDGAME then
          score.ownEndgame = true
          if not trade then
            score.ownEndgameOther = true
          end
        end
      end
      if use.kind == "spell" then
        score.spells[#score.spells + 1] = use.target
      end
      if use.kind == "class" then
        score.classUse = use
      end
      if use.kind == "recipe" then
        fileRecipe(current, use, professions, routeName)
      end
      -- Brief TV1 (QA item 347 D1): the current recipes a recipe item teaches (Keep.SingleRecipe).
      if use.teaches == true then
        score.teachUses = (score.teachUses or 0) + 1
      end
      if use.level and use.level >= Keep.ENDGAME then
        score.endgame = true
      else
        allEndgame = false
      end
      if use.level and (score.top == nil or use.level > score.top) then
        score.top = use.level
      end
      if use.level then
        score.lo = (score.lo == nil or use.level < score.lo) and use.level or score.lo
        score.hi = (score.hi == nil or use.level > score.hi) and use.level or score.hi
      end
    else
      score.stale = score.stale + 1
      score.staleKinds[use.kind] = (score.staleKinds[use.kind] or 0) + 1
      -- Brief UL3 (QA item 369): what the tooltip's fold lists of them, by profession and by quest. The other
      -- side's quests "Hide other faction data" leaves stale are not among them (the tooltip names those).
      if use.kind == "recipe" then
        fileRecipe(behind, use, professions, routeName)
      elseif use.kind == "quest" and not Keep.OtherSide(use.faction, playerFaction) then
        score.behindQuestIds = score.behindQuestIds or {}
        score.behindQuestIds[#score.behindQuestIds + 1] = use.questId or false
      end
      -- Brief HF1: with "Hide other faction data" off, the other side's quests are these stale uses;
      -- the tooltip names them ("4 Horde quests") so the setting shows there too.
      if use.kind == "quest" and Keep.OtherSide(use.faction, playerFaction) then
        score.questsShownOtherSide = (score.questsShownOtherSide or 0) + 1
      end
      if use.level then
        score.staleLo = (score.staleLo == nil or use.level < score.staleLo) and use.level or score.staleLo
        score.staleHi = (score.staleHi == nil or use.level > score.staleHi) and use.level or score.staleHi
      end
    end
  end
  score.allEndgame = score.current > 0 and allEndgame
  -- Brief Q1: how many the open quests ask for in all, nil with none open or one that states none.
  if (score.kinds.quest or 0) > 0 and not questCountless then
    score.questNeed = questNeed
  end
  Keep.SortCombines(score)
  table.sort(score.otherClasses)
  if score.forClasses then
    table.sort(score.forClasses)
  end
  -- Brief BQ14: the qualities each profession's recipes make, read once for both group lists.
  local qualities = (professions or every) and Keep.UseQualities(score.itemId) or nil
  if professions then
    score.recipeGroups = Keep.GroupQualities(sortGroups(current.groups), qualities)
    score.plainRecipes = current.plain
    score.plainName = bucketName(current)
    -- Brief RB2B (QA item 267, the AD7 Do 5 "Locked: ItemTree keep" on Light Leather): a chain ends in
    -- one of the professions the character HAS (opts.ownProfessions where tracked ones joined the set,
    -- as the owner's ruling "A. No" of item 254 holds the working stock to them), never one it only
    -- tracks; and one whose last recipe is a gathering trade's that keeps nothing (opts.chainGrey) is
    -- behind the character, filed stale.
    local chainOwn = type(opts.ownProfessions) == "table" and opts.ownProfessions or professions
    Keep.ScoreChains(score, opts.chained, playerLevel, playerFaction, chainOwn, opts.chainGrey)
  end
  -- Brief UL3: the recipes behind, as recipeGroups (with professions) or a count (without).
  score.behindGroups = professions and Keep.GroupQualities(sortGroups(behind.groups), qualities) or nil
  score.behindPlain = behind.plain
  score.behindPlainName = bucketName(behind)
  score.behindRecipes = behind.total
  if every then
    score.listRecipes = every.total
    score.listGroups = Keep.GroupQualities(sortGroups(every.groups), qualities)
    score.listPlain = every.plain
    score.listPlainName = bucketName(every)
  end
  return score
end

-- Brief TB9: files an item's chained uses (Keep.ChainedUses) on its score, where the player's
-- professions are known. A chained use is weighed only where both ends would count (the direct
-- recipe and the chained one are current by level and side, Keep.IsCurrent); then it is the
-- player's where its own profession is (Keep.IsOwnSkill), and neither current nor stale where it
-- is not. Sets on the score:
--   chained      how many chained uses end in one of the player's professions
--   chainGroups  { { viaSkill, skill, name = the end profession's name, count, own, item = the
--                product with the most recipes (the lowest id on a tie), more = how many other
--                products the pair reaches } }, brief TB13: one per pair of the via and end
--                professions, the count summed over its products; the player's own first, then
--                the most recipes, then by name, then by product id; brief BQ25a: stale = true
--                on a pair of the player's own end profession whose recipes are below the
--                player, filed only where the pair has no current chain, after every current one
-- A chain whose end profession the tables do not name is left out. Brief RB2B: grey (optional) is
-- the set of chained uses whose last recipe is a gathering trade's that keeps nothing, filed stale.
-- Pure.
function Keep.ScoreChains(score, chained, playerLevel, playerFaction, professions, grey)
  score.chained = 0
  score.chainGroups = {}
  if type(chained) ~= "table" or type(professions) ~= "table" then
    return score
  end
  local byKey = {}
  for _, use in ipairs(chained) do
    local via = type(use.via) == "table" and use.via or nil
    local name = via and skillName(use.skill) or nil
    local viaUse = via and { kind = "recipe", level = via.level, faction = via.faction } or nil
    -- Brief RB2B: a chain whose last recipe is a gathering trade's that keeps nothing (grey, the set
    -- Keep.GreyGatherUses files over the chained uses) is behind the character: stale.
    local current = name
      and not (type(grey) == "table" and grey[use] == true)
      and Keep.IsCurrent(viaUse, playerLevel, playerFaction)
      and Keep.IsCurrent(use, playerLevel, playerFaction)
    -- Brief BQ25a (the owner's ruling of 2026-10-10, QA item 45: "Count and show it while it's
    -- relevant (near your level or above)"): a chain that ends in one of the player's own
    -- professions but whose recipes are below the player (Keep.IsCurrent's level test, the one the
    -- plain use lines pass) is filed as stale: listed, never counted, and folded on the tooltip
    -- like any stale use. A chain for the other side is still left out.
    local stale = name
      and not current
      and Keep.IsOwnSkill(use.skill, professions)
      and not Keep.OtherSide(via.faction, playerFaction)
      and not Keep.OtherSide(use.faction, playerFaction)
    if current or stale then
      local key = tostring(via.skill) .. ":" .. name .. (stale and ":stale" or "")
      local group = byKey[key]
      if not group then
        group = { viaSkill = via.skill, skill = use.skill, name = name, count = 0, own = false, products = {} }
        -- Brief BQ7 (item 19): whether the player has the via profession too. Brief BQ25a (item
        -- 45): kept for the specs and the item page; the tooltip's fold reads own and stale only.
        group.viaOwn = Keep.IsOwnSkill(via.skill, professions) and true or false
        if stale then
          group.stale = true
        end
        byKey[key] = group
        score.chainGroups[#score.chainGroups + 1] = group
      end
      group.count = group.count + 1
      if via.item ~= nil then
        group.products[via.item] = (group.products[via.item] or 0) + 1
      end
      if Keep.IsOwnSkill(use.skill, professions) then
        group.own = true
        if not stale then
          score.chained = score.chained + 1
        end
      end
    end
  end
  -- Brief BQ25a (item 45): a pair with a current chain says so on its one line; its stale chains are
  -- filed only where the pair has no current one, so no pair is listed twice.
  local kept = {}
  for _, group in ipairs(score.chainGroups) do
    if not (group.stale and byKey[tostring(group.viaSkill) .. ":" .. group.name]) then
      kept[#kept + 1] = group
    end
  end
  score.chainGroups = kept
  -- Brief TB13: each pair names its product with the most recipes, and counts the others.
  for _, group in ipairs(score.chainGroups) do
    local best, bestCount, others = nil, 0, -1
    for item, n in pairs(group.products) do
      others = others + 1
      if n > bestCount or (n == bestCount and (tonumber(item) or 0) < (tonumber(best) or 0)) then
        best, bestCount = item, n
      end
    end
    group.item = best
    group.more = others > 0 and others or 0
    group.products = nil
  end
  table.sort(score.chainGroups, function(a, b)
    -- Brief BQ25a (item 45): the stale chains after every current one.
    if (a.stale == true) ~= (b.stale == true) then
      return not a.stale
    end
    if a.own ~= b.own then
      return a.own
    end
    if a.count ~= b.count then
      return a.count > b.count
    end
    if a.name ~= b.name then
      return a.name < b.name
    end
    return (tonumber(a.item) or 0) < (tonumber(b.item) or 0)
  end)
  return score
end

-- The item's own level: its required level, else its item level.
function Keep.OwnLevel(itemId)
  local item = itemRow(tonumber(itemId))
  if not item then
    return nil
  end
  return whole(item.rl) or whole(item.il)
end

--------------------------------------------------------------------------------
-- Availability (brief K1). Pure over the shipped tables.
--------------------------------------------------------------------------------

-- How many vendors sell an item in a Classic Era table, and how many limited stock vendors were
-- left out. A named vendor row counts once per node (its name and area); a summary row counts the
-- list it stands for where the table ships one (decoded, so its limited stock vendors are left
-- out too) and its bare count where it does not. Pure.
function Keep.EraVendorCount(source, itemId)
  local Era = ItemTree.EraSources
  if type(Era) ~= "table" or type(Era.Rows) ~= "function" or type(source) ~= "table" then
    return 0, 0
  end
  local count, limited, seen = 0, 0, {}
  local function take(row)
    if type(row) ~= "table" or row.category ~= "vendor" or row.summary then
      return
    end
    if row.stock ~= nil then
      limited = limited + 1
      return
    end
    local key = row.key or row.name
    if key ~= nil and not seen[key] then
      seen[key] = true
      count = count + 1
    end
  end
  local ok, rows = pcall(Era.Rows, source, itemId)
  for _, row in ipairs(ok and type(rows) == "table" and rows or EMPTY) do
    if type(row) == "table" and row.category == "vendor" and row.summary then
      local listed = tonumber(row.listed) or 0
      if listed > 0 and type(Era.More) == "function" then
        local gotMore, more = pcall(Era.More, source, itemId, "vendor")
        for _, extra in ipairs(gotMore and type(more) == "table" and more or EMPTY) do
          take(extra)
        end
      else
        count = count + (tonumber(row.more) or 0)
      end
    else
      take(row)
    end
  end
  return count, limited
end

-- How many vendors Forever's own lists name for an item: its distinct npc ids, or 1 for the empty
-- list that means a vendor the client does not name yet. Pure.
function Keep.ForeverVendorCount(source, itemId)
  local items = type(source) == "table" and source.i or nil
  local list = type(items) == "table" and items[itemId] or nil
  if type(list) ~= "table" then
    return 0
  end
  if #list == 0 then
    return 1
  end
  local count, seen = 0, {}
  for _, npcId in ipairs(list) do
    if not seen[npcId] then
      seen[npcId] = true
      count = count + 1
    end
  end
  return count
end

-- The shipped Era table, or nil. Keep.eraSource stands one in for a spec.
local function eraTable()
  if type(Keep.eraSource) == "table" then
    return Keep.eraSource
  end
  local d = data()
  if not d or type(d.Get) ~= "function" then
    return nil
  end
  local ok, source = pcall(d.Get, d, "EraSources")
  if ok and type(source) == "table" then
    return source
  end
  return nil
end

local function foreverTable()
  local vendors = ItemTree.ForeverVendors
  if type(vendors) ~= "table" or type(vendors.Table) ~= "function" then
    return nil
  end
  local ok, source = pcall(vendors.Table)
  if ok and type(source) == "table" then
    return source
  end
  return nil
end

--- Brief BQ6 (backlog 5): whether an item is a limited stock vendor item: the Era table names limited
--- stock vendors for it (limited) at least as many as the vendors that sell it freely (vendors,
--- Keep.VendorCount's count). Aquadynamic Fish Attractor: 22 limited, none free. One limited vendor
--- among many does not make one (Refreshing Spring Water: 1 among 183 stays "sold everywhere", the
--- owner's K1 example). Pure.
function Keep.LimitedStock(vendors, limited)
  limited = tonumber(limited) or 0
  return limited > 0 and limited >= (tonumber(vendors) or 0)
end

-- Brief IC1 (the owner's ruling "3B" of 2026-10-23, "if they truly are sold everywhere"): a stand in a
-- spec or a persona case sets for the sold everywhere counts, { [itemId] = count }, read in place of the
-- shipped module's; nil on the client.
Keep.wideVendors = nil

-- Ruling "3B": how many Forever vendors sell the item where the player records' and the item claims'
-- vendors, joined to the client's own list, show it widely sold (ItemTree-Data item_claims.sold_wide:
-- five or more vendors, Keep.EVERYWHERE_VENDORS, in five zones or more, serving both sides unless the
-- item is one side's, a limited stock sale left out), Core/ItemsPredicted.lua SoldWide; 0 where it states
-- none. A handful of vendors in one place never ships one. Never loads ItemTree_Data. Pure.
function Keep.WideVendorCount(itemId)
  local id = tonumber(itemId)
  if not id then
    return 0
  end
  if type(Keep.wideVendors) == "table" then
    return tonumber(Keep.wideVendors[id]) or 0
  end
  local predicted = ItemTree.ItemsPredicted
  if type(predicted) ~= "table" or type(predicted.SoldWide) ~= "function" then
    return 0
  end
  local ok, count = pcall(predicted.SoldWide, id)
  return ok and tonumber(count) or 0
end

-- How many vendors sell the item: the larger of the Era count and Forever's own, because the same
-- vendor can be in both and nothing ties an Era name to a Forever npc id. Brief IC1 (ruling "3B"):
-- Forever's own is the larger of the client's lists and Keep.WideVendorCount, the count Jettison's
-- facts carry as vc. Pure over the tables.
function Keep.VendorCount(itemId)
  local id = tonumber(itemId)
  if not id then
    return 0
  end
  local era, limited = Keep.EraVendorCount(eraTable(), id)
  local forever = math.max(Keep.ForeverVendorCount(foreverTable(), id), Keep.WideVendorCount(id))
  -- Brief BQ6 (backlog 5): the limited stock vendors the Era table names, the second answer.
  if forever > era then
    return forever, limited
  end
  return era, limited
end

-- The item's buy price in copper from its shipped row (bp), or nil where the row carries none.
-- Brief SE1: and the bundle that price buys (the row's vs, Keep.BundleSize), nil for one item.
function Keep.Price(itemId)
  local item = itemRow(tonumber(itemId))
  if not item then
    return nil
  end
  local bundle = Keep.BundleSize(item.vs)
  if bundle <= 1 then
    bundle = nil
  end
  return tonumber(item.bp), bundle
end

--------------------------------------------------------------------------------
-- Auction value (brief K9). An item an installed auction addon prices at the Keep value or more
-- (ItemTreeDB.settings.keepValueCopper, 100 gold by default, 0 off) is worth keeping whatever its
-- uses. The price is that addon's own scan, read through Core/Prices.lua; ItemTree never scans.
-- Brief K10: the value is stored in copper and the slider moves over Keep.VALUE_STOPS.
--------------------------------------------------------------------------------

Keep.COPPER_PER_GOLD = 10000
-- Brief K19: the source Core/Prices.lua answers for an item's vendor sell price (Prices.VENDOR),
-- asked where no auction addon has a price, so the Keep value works with none installed.
Keep.VENDOR_SOURCE = "vendor"
Keep.COPPER_PER_SILVER = 100
Keep.VALUE_COPPER_DEFAULT = 100 * Keep.COPPER_PER_GOLD

-- The slider's stops in copper, in order: Off, 1 silver, 10 silver, 1 gold, 2, 5, 10, 20, 50,
-- 100 (the default), 200, 500 and 1000 gold. The slider's position is the stop's index.
Keep.VALUE_STOPS = {
  0,
  100,
  1000,
  10000,
  20000,
  50000,
  100000,
  200000,
  500000,
  1000000,
  2000000,
  5000000,
  10000000,
}

-- The index of the stop a stored copper value sits on: the nearest stop at or below it, so an old
-- 30 gold reads as 20 gold. A missing or malformed value reads as the default, and anything at or
-- below 0 as Off (the first stop). Pure.
function Keep.ValueStopIndex(copper)
  local value = tonumber(copper)
  if value == nil or value ~= value then
    value = Keep.VALUE_COPPER_DEFAULT
  end
  local index = 1
  for i, stop in ipairs(Keep.VALUE_STOPS) do
    if value >= stop then
      index = i
    end
  end
  return index
end

-- The stop's copper at an index, held inside the table (the slider hands back whole numbers, but
-- a stray one never stores a value that is not a stop). Pure.
function Keep.ValueStopCopper(index)
  local count = #Keep.VALUE_STOPS
  local i = math.floor((tonumber(index) or 1) + 0.5)
  if i < 1 then
    i = 1
  elseif i > count then
    i = count
  end
  return Keep.VALUE_STOPS[i]
end

-- The threshold in words: "Off", "1 silver", "10 silver", "1 gold", "100 gold". Whole gold reads
-- in gold, below a gold in silver, and anything left in copper. Pure.
function Keep.ValueLabel(copper)
  local value = math.floor(tonumber(copper) or 0)
  if value <= 0 then
    return L["Off"]
  end
  if value % Keep.COPPER_PER_GOLD == 0 then
    return string.format(L["%d gold"], value / Keep.COPPER_PER_GOLD)
  end
  if value < Keep.COPPER_PER_GOLD and value % Keep.COPPER_PER_SILVER == 0 then
    return string.format(L["%d silver"], value / Keep.COPPER_PER_SILVER)
  end
  return Keep.MoneyWords(value)
end

-- The /itemtree debug line: "Keep value: 100 gold", the setting as stored. Pure over ItemTree.db.
-- Brief K20c: a Bar other than the default follows ("; sell bar 2x"), and a formula that is not
-- understood says where ("; sell bar formula not understood at 12 (unknown name 'vendr')").
function Keep.ValueStatusLine(settings)
  local threshold = Keep.ValueThreshold(settings)
  local line = "Keep value: " .. Keep.ValueLabel(threshold or 0)
  local stop, read = Keep.BarSetting(settings)
  if stop.key == "formula" then
    local formula = ItemTree.PriceFormula
    if type(formula) == "table" and type(formula.Check) == "function" then
      local ok, understood, pos, words = pcall(formula.Check, read)
      if ok and understood == false then
        return line .. string.format("; sell bar formula not understood at %s (%s)", tostring(pos), tostring(words))
      end
    end
    return line .. "; sell bar formula"
  end
  if stop.key ~= Keep.BAR_DEFAULT then
    line = line .. "; sell bar " .. stop.key
  end
  return line
end

-- The Keep value in copper, or nil where the setting turns it off (0 or less). A missing or
-- malformed setting reads as the default. Pure over ItemTree.db.
function Keep.ValueThreshold(settings)
  if type(settings) ~= "table" then
    local db = ItemTree.db
    settings = type(db) == "table" and type(db.settings) == "table" and db.settings or EMPTY
  end
  local copper = tonumber(settings.keepValueCopper)
  if copper == nil or copper ~= copper then
    copper = Keep.VALUE_COPPER_DEFAULT
  end
  if copper <= 0 then
    return nil
  end
  return math.floor(copper + 0.5)
end

-- Whether a value in copper reaches the threshold (Keep.ValueThreshold where none is given).
-- Pure.
function Keep.Valuable(value, threshold)
  value = tonumber(value)
  if threshold == nil then
    threshold = Keep.ValueThreshold()
  end
  threshold = tonumber(threshold)
  if value == nil or threshold == nil then
    return false
  end
  return value >= threshold
end

-- The item's value: copper and the addon it came from (or Keep.VENDOR_SOURCE for its vendor sell
-- price), or nil. Asks Core/Prices.lua, which reads the installed auction addons' own prices and
-- then the item's sell price; nothing where it is not loaded. Brief K20a: kept beside
-- Keep.ItemPrices for one release, "auction, else vendor".
function Keep.ItemValue(itemId, link)
  local prices = ItemTree.Prices
  if type(prices) ~= "table" or type(prices.Value) ~= "function" then
    return nil
  end
  local ok, copper, source = pcall(prices.Value, itemId, link)
  if not ok then
    return nil
  end
  copper = tonumber(copper)
  if copper == nil or copper <= 0 then
    return nil
  end
  if type(source) ~= "string" then
    source = nil
  end
  return math.floor(copper), source
end

-- A positive whole copper, or nil. Pure.
local function positiveCopper(value)
  value = tonumber(value)
  if value == nil or value ~= value or value <= 0 or value == math.huge then
    return nil
  end
  return math.floor(value)
end

-- Brief K20a: the item's two prices, never one: its vendor sell price per unit, then its auction
-- price per unit and the addon that answered it (Core/Prices.lua Prices.Vendor and
-- Prices.Auction). A Prices without the two calls (a spec's stand in with Value alone) is read
-- through Prices.Value, whose vendor source fills the vendor price and any other the auction one.
-- nil for each price nobody has. Never a client item query beyond what Prices does.
function Keep.ItemPrices(itemId, link)
  local vendor, auction, source = Keep.ReadPrices(itemId, link)
  -- Brief K24b (H): the owner's session only pretend auction price per item (/itemtree demo
  -- price), which every item reads while it is set. Memory only.
  local pretend = tonumber(Keep.demoPrice)
  if pretend and pretend > 0 then
    return vendor, math.floor(pretend), "demo"
  end
  return vendor, auction, source
end

-- The two prices as Core/Prices.lua answers them (Keep.ItemPrices' words), with no pretend price.
function Keep.ReadPrices(itemId, link)
  local prices = ItemTree.Prices
  if type(prices) ~= "table" then
    return nil, nil, nil
  end
  if type(prices.Vendor) ~= "function" or type(prices.Auction) ~= "function" then
    local copper, source = Keep.ItemValue(itemId, link)
    if copper == nil then
      return nil, nil, nil
    end
    if source == Keep.VENDOR_SOURCE then
      return copper, nil, nil
    end
    return nil, copper, source
  end
  local vendor, auction, auctionSource
  local okVendor, answer = pcall(prices.Vendor, itemId)
  if okVendor then
    vendor = positiveCopper(answer)
  end
  local okAuction, copper, source = pcall(prices.Auction, itemId, link)
  if okAuction then
    auction = positiveCopper(copper)
  end
  if auction ~= nil and type(source) == "string" and source ~= "" then
    auctionSource = source
  end
  return vendor, auction, auctionSource
end

-- Brief K20a: puts the two prices on a score: vendor, auction and auctionSource, then the value
-- the earlier contract reads (value and valueSource, "auction, else vendor") and valuable, which
-- is true when either price reaches the Keep value. Answers the score. Pure.
function Keep.SetPrices(score, vendor, auction, auctionSource)
  if type(score) ~= "table" then
    return score
  end
  vendor, auction = positiveCopper(vendor), positiveCopper(auction)
  score.vendor = vendor
  score.auction = auction
  if auction ~= nil and type(auctionSource) == "string" then
    score.auctionSource = auctionSource
  else
    score.auctionSource = nil
  end
  if auction ~= nil then
    score.value, score.valueSource = auction, score.auctionSource
  elseif vendor ~= nil then
    score.value, score.valueSource = vendor, Keep.VENDOR_SOURCE
  else
    score.value, score.valueSource = nil, nil
  end
  -- Brief K20b: an auction price counts only for an item that can go to the auction house.
  local threshold = Keep.ValueThreshold()
  score.valuable = Keep.Valuable(vendor, threshold) or (Keep.Tradable(score) and Keep.Valuable(auction, threshold))
  -- Brief K20-wire (design K20 section 1): the disenchant value too, where the player can
  -- disenchant the item (score.disenchant is there only then).
  if not score.valuable and type(score.disenchant) == "table" then
    score.valuable = Keep.Valuable(score.disenchant.copper, threshold)
  end
  return score
end

-- Puts one value on a score, the K9 and K19 shape: a value whose source is Keep.VENDOR_SOURCE is
-- the vendor price, any other an auction price. Brief K20a: through Keep.SetPrices, so the two
-- prices are set too. Answers the score. Pure.
function Keep.SetValue(score, value, source)
  if source == Keep.VENDOR_SOURCE then
    return Keep.SetPrices(score, value, nil, nil)
  end
  return Keep.SetPrices(score, nil, value, source)
end

--------------------------------------------------------------------------------
-- The player's own word (brief K4): ItemTreeDB.keepOverrides = { [itemId] = "always" | "never" |
-- "off" }, absent for auto. "always" marks the item whatever its uses, "never" never marks it, and
-- auto is the rule above. Brief K5: "off" is silence, no mark and no tooltip line at all; it
-- touches the marks only, so Core/Ledger.lua still counts the item as looted. Pure over
-- ItemTree.db, which Core/Init.lua defaults.
--------------------------------------------------------------------------------

Keep.OVERRIDES = { always = true, never = true, off = true }

-- The saved table, made where create asks for it and the saved variables are there to hold it.
local function overrideStore(create)
  local db = ItemTree.db
  if type(db) ~= "table" then
    return nil
  end
  local store = db.keepOverrides
  if type(store) ~= "table" then
    if not create then
      return nil
    end
    store = {}
    db.keepOverrides = store
  end
  return store
end

-- "always", "never", "off", or nil for auto (and for anything else the table might hold). Pure.
function Keep.Override(itemId)
  local id = tonumber(itemId)
  local store = id and overrideStore(false) or nil
  local value = store and store[id] or nil
  if Keep.OVERRIDES[value] then
    return value
  end
  return nil
end

-- Sets the player's word on one item: "always", "never" or "off", or nil (or "auto") to clear it. The
-- item's cached score goes with it, and the bags and the tooltip are painted again through
-- Keep.Repaint where the client side is loaded. Answers the value now held, nil for auto, and
-- false where nothing could be stored (no id, or no saved variables yet).
-- Brief K14 (ruling 1, the owner on 2026-10-14: "Yes add the fix"): a word that changes also tells
-- another addon, through the API's change callback as "setting" (API.NotifyChange, one call a frame
-- however many words change), so Jettison ranks its bags again at once instead of on the next bag
-- event. The API is looked up at the call (Core/API.lua loads after this file).
function Keep.SetOverride(itemId, value)
  local id = tonumber(itemId)
  if not id then
    return false
  end
  if not Keep.OVERRIDES[value] then
    value = nil
  end
  local before = Keep.Override(id)
  local store = overrideStore(value ~= nil)
  if not store then
    if value ~= nil then
      return false
    end
  else
    store[id] = value
  end
  -- Brief K28: the item's random suffix rolls' scores go with it.
  if type(Keep.cache) == "table" then
    Keep.DropItemScores(id)
  end
  if type(Keep.Repaint) == "function" then
    pcall(Keep.Repaint)
  end
  local api = ItemTree.API
  if before ~= value and type(api) == "table" and type(api.NotifyChange) == "function" then
    pcall(api.NotifyChange, "setting")
  end
  return value
end

-- Brief PR4: the Professions module's model, or nil unless the tab's setting is on and its folder
-- has loaded (UI/ProfessionsStub.lua Active) and the model answers Current. Keep.professionModel
-- stands one in for a spec: a table, or false for none.
function Keep.ProfessionModel()
  if Keep.professionModel ~= nil then
    return Keep.professionModel or nil
  end
  local ui = ItemTree.UI
  local stub = type(ui) == "table" and ui.ProfessionsStub or nil
  if type(stub) ~= "table" or type(stub.Active) ~= "function" then
    return nil
  end
  local ok, active = pcall(stub.Active)
  if not ok or active ~= true then
    return nil
  end
  local professions = ItemTree.Professions
  local model = type(professions) == "table" and professions.model or nil
  if type(model) ~= "table" or type(model.Current) ~= "function" then
    return nil
  end
  return model
end

-- Brief PR4: the route entry { skillLine, lo, hi } for an item the player's profession route still
-- needs, or nil. A lookup in the model's cached set, no client call.
function Keep.ProfessionRelevant(itemId)
  local id = tonumber(itemId)
  local model = id and Keep.ProfessionModel() or nil
  if not model then
    return nil
  end
  local ok, set = pcall(model.Current)
  local info = ok and type(set) == "table" and set[id] or nil
  if type(info) == "table" then
    return info
  end
  return nil
end

-- Answers the score for one item and player, or nil while the item rows are not loaded (a bag
-- pass at login never pulls ItemTree_Data in for this). opts is ScoreUses's: professions and
-- completed pass through, and the vendor count and price are read here for every item (brief
-- K24j; K1 read them only for an item with a use).
function Keep.Score(itemId, playerLevel, playerFaction, playerClass, opts)
  local d = data()
  if d and type(d.OnDemandLoaded) == "function" and not d:OnDemandLoaded() then
    return nil
  end
  -- Brief RB1b: the repeatable quests beside the uses, counted below for the tooltip's folded line.
  -- Brief QX1: and the event or unjudged quests, which Keep.QuestFinished alone reads.
  local uses, repeats, gated, others = Keep.UsesAndRepeats(itemId)
  local full = {}
  for key, value in pairs(type(opts) == "table" and opts or EMPTY) do
    full[key] = value
  end
  -- Brief K24j (owner QA 2026-10-07, Rough Arrow x200 read [Auction]: 70 vendors sell it for 10
  -- copper, but K1 counted vendors only for an item with a use, so an item with none was never
  -- "sold everywhere" and the auction house was offered for it): the count and the price are
  -- read for every item the caller did not read them for, so the K1 rule stops the Auction tag on
  -- anything vendors sell everywhere, used or not.
  if full.vendors == nil then
    local limited
    full.vendors, limited = Keep.VendorCount(itemId)
    -- Brief SE1: the bundle the price buys beside it, so sold everywhere judges one item's price.
    full.price, full.bundle = Keep.Price(itemId)
    -- Brief BQ6 (backlog 5): sold mostly in limited stock, so never "sold everywhere".
    if full.limited == nil then
      full.limited = Keep.LimitedStock(full.vendors, limited)
    end
  end
  -- Brief TB9: the chained uses, walked only where the player's professions are known, the one
  -- case the scorer weighs them in.
  if full.chained == nil and type(full.professions) == "table" and #uses > 0 then
    full.chained = Keep.ChainedUses(itemId, uses)
  end
  -- Brief K22: which via items of this item's combines are carried, asked only where it has one.
  local asked = nil
  if full.carried == nil and type(full.carries) == "function" then
    asked = Keep.CarriedSet(uses, full.carries)
    full.carried = asked
  end
  if full.override == nil then
    full.override = Keep.Override(itemId)
  end
  -- Brief K20a/K20b: the row's stack size, quality, class and bonding, for the verdict's words and
  -- its states.
  if full.itemId == nil then
    full.itemId = tonumber(itemId)
  end
  local row = itemRow(tonumber(itemId))
  -- Brief AA-RB (the owner's QA item 216, 2026-10-17: Adventurer's Tent 288185, new in 1.60.1.70450,
  -- "both addons agree on whether a toy is kept"): a toy, as the client's Toy Box answers for it
  -- (Keep.IsToy, brief TF1: else the shipped toy list; opts.toy where the caller states it), is kept,
  -- [Keep] "Toy" (Keep.KEEP_TOY), as Jettison locks it ("Locked: toy").
  if full.toy == nil then
    full.toy = Keep.IsToy(itemId)
  end
  -- Brief JG1 (item 302, a player's Grimoire of Torment (Rank 2) read as a sale while the Voidwalker
  -- knew Rank 1 only): a warlock's demon grimoire is kept, [Keep] "Teaches your Voidwalker Torment
  -- (Rank 2)" (Keep.KEEP_PET_BOOK), until the summoned demon is known to have learnt it.
  -- opts.petSpellKnown answers the pet's spells where the caller states them (a spec), else the
  -- client's read (Keep.PetSpellKnown). The pet's moves drop these scores (Keep.DropPetBookScores).
  if full.petBook == nil then
    full.petBook = Keep.PetBookFacts(itemId, playerClass, full.petSpellKnown or Keep.PetSpellKnown)
  end
  -- Brief CB1 (item 305): a book that teaches the player a spell of their own class (Tome of Arcane
  -- Brilliance for a mage) is kept, [Keep] "Teaches you Arcane Brilliance (Rank 1)"
  -- (Keep.KEEP_CLASS_BOOK), until the player is known to have learnt it. opts.spellKnown answers the
  -- player's spells where the caller states them (a spec), else the client's read
  -- (Keep.PlayerSpellKnown). A spell learnt drops these scores (Keep.DropClassBookScores).
  if full.classBook == nil then
    local known = full.spellKnown or Keep.PlayerSpellKnown
    full.classBook = Keep.ClassBookFacts(row, playerClass, known, full.spellName or ItemTree.SpellName)
  end
  -- Brief AM1 (QA item 330): ammo the worn ranged weapon fires (opts.worn, Gear.Worn's map, through
  -- Keep.AmmoWeapons), in reach of the player's level, is kept, [Keep] "Ammo for your bow"
  -- (Keep.KEEP_AMMO), as Jettison locks it. opts.ammo stands where the caller states it. Brief AM3
  -- (item 340): ammo vendors sell everywhere counts only 3 levels ahead, by the score's own sold
  -- everywhere fact (Keep.ScoreUses' everywhere, from the count, price and bundle read above); and
  -- ammo the rule turns down (Keep.AmmoRejected) is told to Keep.Worthless, only where the worn map
  -- is known (opts.worn a table; nil is Gear not loaded or the client not answering).
  if full.ammo == nil then
    local weapons = Keep.AmmoWeapons(full.worn)
    local everywhere = Keep.Everywhere(full.vendors, full.price, full.bundle) and full.limited ~= true
    full.ammo = Keep.AmmoFacts(row, weapons, playerLevel, everywhere)
    if full.ammo == nil and full.ammoRejected == nil and type(full.worn) == "table" then
      full.ammoRejected = Keep.AmmoRejected(row, weapons, playerLevel, everywhere)
    end
  end
  if row then
    if full.stack == nil then
      full.stack = row.st
    end
    if full.quality == nil then
      full.quality = row.q
    end
    if full.itemClass == nil then
      full.itemClass = row.c
    end
    if full.bonding == nil then
      full.bonding = row.b
    end
    if full.subclass == nil then
      full.subclass = row.sc
    end
    -- Brief K24b (B): the provisional "could use" of a consumable, a soft keep. opts.skillRank
    -- answers the player's rank in a skill line (Keep.SkillRank on the client), asked only for a
    -- consumable that names a required skill.
    -- Brief K26: what a food or drink does (Keep.FoodEffect over the shipped spell names,
    -- opts.spellName or ItemTree.SpellName), read before the soft keep weighs it.
    if full.foodEffect == nil then
      full.foodEffect = Keep.FoodEffect(row, full.spellName or ItemTree.SpellName)
    end
    -- Brief K25: the consumable facts (Core/Consumables.lua over the ItemEffects module), where
    -- they ship, replace the K24b window for that item: the verdict's keep is its soft keep and
    -- its words the reason line. opts.effects is a module handed in (a spec), opts.pools the
    -- player's pools and opts.carriedConsumables the bag read (Keep.CarriedConsumables).
    -- Brief K25d: for a consumable only (the row's class, as Keep.CouldUse reads it). The shipped
    -- module covers every usable item, so a trinket, quest item, trade good or weapon with a use
    -- effect has facts too, and keeps the verdict it had before K25.
    if
      full.consumable == nil
      and tonumber(row.c) == Keep.CONSUMABLE_CLASS
      and type(ItemTree.Consumables) == "table"
    then
      -- Brief K25g: the module read once, for the facts and for its shares table (Judge's module).
      local module = full.effects or ItemTree.Consumables.Module()
      local facts = ItemTree.Consumables.Facts(tonumber(itemId), module)
      if facts then
        local carried = full.carriedConsumables
        if type(carried) == "function" then
          local okCarried, list = pcall(carried, tonumber(itemId))
          carried = okCarried and type(list) == "table" and list or nil
        end
        local pools = full.pools
        if type(pools) == "function" then
          local okPools, read = pcall(pools)
          pools = okPools and type(read) == "table" and read or nil
        end
        local conjure = full.conjure
        if type(conjure) == "function" then
          local okConjure, read = pcall(conjure, playerClass, playerLevel)
          conjure = okConjure and type(read) == "table" and read or nil
        end
        full.consumable = ItemTree.Consumables.Judge(facts, row, {
          classId = playerClass,
          level = playerLevel,
          maxLevel = full.maxLevel or Keep.MAX_LEVEL,
          pools = pools,
          rankOf = full.skillRank,
          carried = carried,
          module = module,
          -- Brief ST4 (G1): the conjures the character knows (Keep.Conjured).
          conjure = type(conjure) == "table" and conjure or nil,
          -- Brief BQ6 (backlog 21): the player's enabled specs (nil: every spec of the class).
          specs = full.enabledSpecs,
        })
      elseif
        tonumber(row.sc) == Keep.FOOD_SUBCLASS
        and type(ItemTree.Consumables.IsNotFood) == "function"
        and ItemTree.Consumables.IsNotFood(tonumber(itemId), module)
      then
        -- Brief K29: a Food and Drink item the effects say is no food (alcohol alone) is no soft
        -- keep and no food with a buff: plain, so it is never offered for auction (K26), and it
        -- goes by its other facts, as Jettison's verdict does.
        full.notFood = true
        full.foodEffect = Keep.FOOD_PLAIN
      end
    end
    -- Brief BQ23 (the owner's QA of 2026-10-10, item 38): a camp item (the pipeline's kind 62: Camp
    -- Chair, Camp Tent) is its own kind, never a profession's tool: kept while levelling (the buff
    -- at a campfire is worth having) where the player meets its skill, "Camp item: a buff at a
    -- campfire" (Keep.CampCouldUse); at the level cap it goes by its other facts.
    if full.campItem == nil and tonumber(row.c) == Keep.CONSUMABLE_CLASS then
      local consumables = ItemTree.Consumables
      if type(consumables) == "table" and type(consumables.IsCampItem) == "function" then
        full.campItem = consumables.IsCampItem(tonumber(itemId), full.effects) or nil
      end
    end
    if full.couldUse == nil and full.campItem then
      full.couldUse = Keep.CampCouldUse(row, playerClass, playerLevel, full.skillRank, full.foodEffect, full.maxLevel)
    end
    -- Brief TV1 (QA item 347, the owner on a new companion pet: "Yea this seems like a Use/Auction"):
    -- a companion pet item is a soft keep, read [Use] (Keep.UseTagged) with its sale tags beside.
    if full.companion == nil then
      full.companion = Keep.CompanionFacts(row)
    end
    if full.couldUse == nil and full.companion then
      full.couldUse = true
    end
    -- Brief TV1 (QA item 347 D1): a recipe item's own facts, against the character's own professions
    -- (never a tracked one) and spell book (opts.spellKnown where the caller states it, else the
    -- client's read, Keep.PlayerSpellKnown).
    if full.recipe == nil then
      full.recipe = Keep.RecipeFacts(
        row,
        full.ownProfessions or full.professions,
        full.skillRank,
        full.spellKnown or Keep.PlayerSpellKnown
      )
    end
    if full.couldUse == nil then
      if type(full.consumable) == "table" then
        full.couldUse = full.consumable.keep == true
      elseif full.notFood then
        full.couldUse = false
      else
        full.couldUse = Keep.CouldUse(row, playerClass, playerLevel, full.skillRank, full.foodEffect, full.maxLevel)
      end
    end
    -- Brief BQ6 (backlog 5): a soft keep for one of the player's professions says which.
    if full.professionUse == nil and full.couldUse == true and full.consumable == nil and not full.campItem then
      full.professionUse = Keep.ProfessionLine(row.sk)
    end
    -- Brief BQ25c (item 52): a bag, quiver, ammo pouch, soul or reagent bag against the equipped
    -- bags of its kind (opts.bags, Keep.BagState's state, or a function answering it), the worn
    -- ranged weapon deciding the ammo a quiver or pouch is for.
    if full.bag == nil and full.bags ~= nil and Keep.BagKind(row) ~= nil then
      local bags = full.bags
      if type(bags) == "function" then
        local okBags, read = pcall(bags)
        bags = okBags and read or nil
      end
      local worn = type(full.worn) == "table" and full.worn or EMPTY
      -- Brief BG1 (item 83): the item's id ranks it among the spare bags (Keep.SpareBagVerdict).
      -- QA item 153: and the character's level, for a quiver or pouch upgrade not wearable yet.
      local rangedRow = worn[Keep.RANGED_SLOT]
      -- Brief TP1: the player's own professions (full.ownProfessions where tracked ones joined the
      -- set): a profession bag is for a trade the character itself works.
      local trades = full.ownProfessions or full.professions
      full.bag = Keep.BagFacts(row, bags, playerClass, trades, rangedRow, tonumber(itemId), playerLevel)
    end
    -- Brief K31: a profession tool (Keep.ToolFacts over the shared list) is judged by its trade,
    -- never as gear: no gear facts, so no compare, no Equip tag and no "Not an upgrade".
    if full.tool == nil then
      -- Brief TP1: a tool is for a trade the character itself works, never a tracked one.
      full.tool = Keep.ToolFacts(itemId, row, full.ownProfessions or full.professions) or false
    end
    -- Brief K20-wire: the gear facts against what the player wears (opts.worn, Gear.Worn's map).
    -- Brief K28: and the item's link (opts.link), whose random suffix roll is weighed as stats.
    if full.gear == nil and not full.tool then
      -- Brief ST3 (QA item 320): and whether it is gear whose suggestions the player turned off, for
      -- the API's keep.gear (Core/API.lua), so another addon does not judge it as an upgrade itself.
      local off
      full.gear, off = Keep.GearFacts(row, full.worn, playerClass, playerLevel, full.enabledSpecs, full.link)
      full.gearOff = off == true or nil
    end
    -- Brief GW1 (QA item 101 (a)): a cosmetic piece's own facts, whether the account has its
    -- appearance (opts.appearanceCollected, else the client's answer, Keep.AppearanceCollected).
    -- Brief GW1c: only for a piece the row marks as collected by using it (row.cl).
    if full.cosmetic == nil then
      full.cosmetic = Keep.CosmeticFacts(row, full.appearanceCollected, tonumber(itemId))
    end
    -- Brief K20-wire: the disenchant facts, only with Enchanting (full.enchanting, the rank), never
    -- for a material being scored for them (noDisenchant).
    if full.disenchant == nil and full.enchanting ~= nil and not full.noDisenchant then
      full.disenchant = Keep.DisenchantFacts(row, full.enchanting, Keep.MaterialPriceFunction(full), function(id)
        return Keep.MaterialKeep(id, playerLevel, playerFaction, playerClass, full)
      end)
      if type(full.disenchant) == "table" then
        local values = ItemTree.DisenchantValue
        full.disenchant.at = type(values) == "table" and type(values.Now) == "function" and values.Now() or nil
      end
    end
  end
  if full.profession == nil then
    full.profession = Keep.ProfessionRelevant(itemId)
  end
  -- Brief RB2A (QA item 250, the owner's ruling "for herbs do A"): the gathering trades' recipe uses
  -- grey for the character (Keep.GreyGatherUses, its ranks the route's facts else the client's), read
  -- once per score; a caller's opts.gatherGrey stands. Brief TG1 (QA item 260, ruling "A"): with the
  -- character's own professions (full.ownProfessions, where tracked ones joined the set), so a tracked
  -- gathering line keeps only what its range can make.
  if full.gatherGrey == nil then
    local facts = Keep.ReagentFacts()
    local skills = type(facts) == "table" and facts.skills or nil
    local lines = type(facts) == "table" and facts.lines or nil
    full.gatherGrey = Keep.GreyGatherUses(uses, full.professions, skills, full.skillRank, lines, full.ownProfessions)
  end
  -- Brief RB2B (QA item 267): the chained uses (TB9) whose end recipe is a gathering trade's that keeps
  -- nothing (grey, or outside a tracked range), the same rule over the chain's last step; a caller's
  -- opts.chainGrey stands.
  if full.chainGrey == nil and type(full.chained) == "table" and #full.chained > 0 then
    local facts = Keep.ReagentFacts()
    local skills = type(facts) == "table" and facts.skills or nil
    local lines = type(facts) == "table" and facts.lines or nil
    full.chainGrey =
      Keep.GreyGatherUses(full.chained, full.professions, skills, full.skillRank, lines, full.ownProfessions)
  end
  -- Brief K30: the route's count for the item's own trade uses (Keep.ReagentNeedFor), read once
  -- per score; a caller's opts.reagentNeed stands (false for not worked out). A count of 0 leaves
  -- the route entry out too: a band the player has passed names the item while its recipe is not
  -- grey, but nothing left on the route makes it.
  if full.reagentNeed == nil then
    local lines =
      Keep.TradeLines(uses, playerLevel, playerFaction, playerClass, full.professions, full.profession, full.gatherGrey)
    local need = nil
    if type(lines) == "table" and #lines > 0 then
      if Keep.GatherOnly(lines) then
        -- Brief RB2A: grey gathering recipes alone keep nothing, with the route's facts or without.
        need = 0
      elseif type(Keep.ReagentNeedFor) == "function" then
        need = Keep.ReagentNeedFor(itemId, lines)
      end
    end
    -- Brief RB2A: a count of 0 says nothing where a gathering recipe not grey yet keeps every unit
    -- (Copper Bar's Smelt Bronze beside the grey Lodestone): no count, as before RB2A.
    if
      need == 0
      and Keep.GatherKeeps(uses, playerLevel, playerFaction, playerClass, full.professions, full.gatherGrey)
    then
      need = nil
    end
    full.reagentNeed = need or false
  end
  if full.reagentNeed == 0 then
    full.profession = nil
  end
  -- Brief BQ18: the working stock (Keep.StockFacts), worked out only where the route's count is 0,
  -- over the same K30 facts (the player's ranks and the route's windows); a caller's opts.stock
  -- stands (false for none).
  if full.stock == nil then
    full.stock = false
    if full.reagentNeed == 0 then
      local facts = Keep.ReagentFacts()
      if type(facts) == "table" then
        full.stock = Keep.StockFacts(itemId, uses, {
          -- Brief RB2A (QA item 254, ruling "A. No"): the professions the character really has
          -- (full.ownProfessions where tracked ones joined the set); a tracked one keeps no stock.
          professions = full.ownProfessions or full.professions,
          skills = facts.skills,
          lines = facts.lines,
          faction = playerFaction,
          stack = row and row.st or nil,
          classId = playerClass,
          level = playerLevel,
          worn = full.worn,
          enabledSpecs = full.enabledSpecs,
          skillRank = full.skillRank,
          maxLevel = full.maxLevel,
          pools = full.pools,
          effects = full.effects,
        }) or false
      end
    end
  end
  -- Brief K9: the auction value, from an installed auction addon's own scan. Brief K20a: the two
  -- prices, the vendor sell price and the auction price, read apart.
  if full.value == nil and full.vendor == nil and full.auction == nil then
    full.vendor, full.auction, full.auctionSource = Keep.ItemPrices(itemId, full.link)
  end
  local score = Keep.ScoreUses(uses, playerLevel, playerFaction, Keep.OwnLevel(itemId), playerClass, full)
  -- Brief QX1: a quest bound or soulbound quest item whose quests of this character are all done
  -- (Keep.QuestFinished), for its verdict (Keep.FinishedTags) and the API's keep.finished. Brief IW1
  -- (ruling "3A"): never an epic or better one (Keep.FinishedEpicGuard); brief AQF1 fix 3 (ruling "B"):
  -- such an item keeps the answer for its lines alone (score.questFinishedLines), below.
  if Keep.FinishedBound(score) then
    -- Brief IW1: a provided item's quest in the log or not (ruling 1B). Brief AQF1 fix 4: and a grey chain
    -- end's (Keep.QuestBelowLevel), each answer held on the score (Keep.ProvidedInLog, score.providedWatch)
    -- so the quest taken or dropped later re-reads it (Keep.RecheckProvided). Brief AQF2 (M2): the log's own
    -- answer goes on (ProvidedInLog's second, nil where the client cannot say), so the below level rule reads
    -- an unknown as maybe in the log; the provided rule reads anything but true as not in it, as before.
    local onQuest = nil
    if type(full.onQuest) == "function" then
      onQuest = function(questId)
        local _, said = Keep.ProvidedInLog(score, { questId = questId }, full.onQuest)
        return said
      end
    end
    score.questFinished =
      Keep.QuestFinished(itemId, uses, repeats, gated, others, playerLevel, playerFaction, playerClass, {
        completed = full.completed,
        abandoned = full.abandoned,
        onQuest = onQuest,
      })
    -- Brief RF375 (the review's M1): never while the client's quest log wants the item (an item
    -- objective of a quest in the log names it, opts.logWants: Keep.LogWants on the client), as
    -- Jettison keeps its lock (isQuestNeeded), so a quest our data does not know keeps it. The answer
    -- is held on the score (score.logWatch) so a quest taken or dropped later re-reads it
    -- (Keep.RecheckLogWants). The item is named by its row, else by the caller's link.
    if score.questFinished ~= nil and type(full.logWants) == "function" then
      local name = type(row) == "table" and type(row.n) == "string" and row.n ~= "" and row.n or nil
      name = name or Keep.LinkName(full.link)
      local ok, wants = pcall(full.logWants, tonumber(itemId), name)
      wants = ok and wants == true
      score.logWatch = { itemId = tonumber(itemId), name = name, wants = wants }
      if wants then
        score.questFinished = nil
      end
    end
    -- Brief AQF1 fix 3 (the owner's ruling "B" of 2026-10-22, QA item 379, Red Scepter Shard at 60 with
    -- Nefarius's Corruption done): an epic or better quest item (Keep.FinishedEpicGuard) reads its finished
    -- lines with no finished tag (Keep.FinishedOnlyParts), and no keep.finished goes to another addon, so
    -- Jettison keeps its quest item lock. The answer moves to score.questFinishedLines.
    if score.questFinished ~= nil and Keep.FinishedEpicGuard(score) then
      score.questFinishedLines = score.questFinished
      score.questFinished = nil
    end
  end
  -- Brief RB2B (QA item 267): the character's own professions where tracked ones joined the set, for the
  -- words of a tracked line (Keep.GatherSpareWords) and the reason the API names (Keep.KeepWhy); nil where
  -- nothing is tracked.
  score.ownProfessions = type(full.ownProfessions) == "table" and full.ownProfessions or nil
  -- Brief RB1b (the owner's answer of 2026-10-17 on item 190): the repeatable quests the item page
  -- counts, which keep nothing; UI/Tooltip.lua OtherQuestLines folds them as "9 repeatable quests".
  score.questsRepeat, score.repeatQuestIds = Keep.RepeatCount(repeats, playerFaction, full)
  -- Brief RB1c (the owner's ruling "A" of 2026-10-17): the quests an instance holds back, folded the
  -- same way ("8 Naxxramas quests"), by gate.
  score.questsGated, score.gatedQuestIds, score.gatedByGate = Keep.HeldBackCount(gated, playerFaction, full)
  -- Brief WS1 (the owner's ruling "A for writs" of 2026-10-17 night): the quests held back by their
  -- starter file under QuestFlags.STARTER_GATE there ("1 quest (started by an item you don't have)"); the
  -- starter answers the verdict rests on, so a bag, bank or quest log change re-reads it.
  score.starterWatch = Keep.StarterWatch(uses, gated)
  -- Brief AA-RB (QA item 219): the other side's repeatable and held back quests those counts leave out,
  -- for the Keep block's "No known uses for Alliance" (Keep.NoUsesWords).
  local foldedOther = Keep.OtherSideCount(repeats, playerFaction, full)
    + Keep.OtherSideCount(gated, playerFaction, full)
  if foldedOther > 0 then
    score.questsOtherSideFolded = foldedOther
    score.playerSide = playerFaction
  end
  -- Brief BQ18: the working stock facts, nil for none.
  if type(full.stock) == "table" then
    score.stock = full.stock
  end
  -- Brief JO1 (BQ7): whether the character can open it (Keep.OpenState); the Lockpicking rank is
  -- read only for a locked box (opts.lockpick, else Keep.LockpickRank).
  score.open = Keep.ScoreOpen(row, playerClass, playerLevel, full.lockpick)
  -- Brief BQ9: the item's id (Keep.OpenWords) and, for a buff to use now, its effect spells
  -- (Keep.UseBuffFacts; whether the buff is on the player is Keep.Tags' env.auras, never cached).
  score.itemId = tonumber(itemId)
  score.useBuff = Keep.UseBuffFacts(row, full.consumable, playerLevel, full.spellName or ItemTree.SpellName)
  -- Brief K22 (merge KSM3): a disenchant verdict that rests on a material's carried via item rests
  -- on it too, so Keep.RecheckCarried re-reads this score when it moves.
  asked = Keep.MaterialCarried(full.disenchant, full.materialScores, asked)
  if asked and next(asked) ~= nil then
    -- Brief K22: the answers the verdict rests on, so a bag change can re-read it (Keep.RecheckCarried).
    score.viaCarried = asked
  end
  return score
end

-- Brief K22: the via items of an item's combine uses as a set { [itemId] = true | false }, each
-- asked once through carries(itemId), which answers true (in the bags), false (not) or nil (the
-- client will not say, left out). Empty for an item with no such use, which asks nothing. Pure
-- over carries.
function Keep.CarriedSet(uses, carries)
  local set = {}
  for _, use in ipairs(uses or EMPTY) do
    if isViaCombine(use) then
      for _, via in ipairs(use.via) do
        if set[via] == nil then
          local ok, answer = pcall(carries, via)
          if ok and answer ~= nil then
            set[via] = answer == true
          end
        end
      end
    end
  end
  return set
end

-- Brief K22 (merge KSM3): the carried answers the disenchant facts' material scores rest on (their
-- viaCarried, held in materialScores), merged into asked (a new set where asked is nil), or asked
-- unchanged where there are none. Pure.
function Keep.MaterialCarried(disenchant, materialScores, asked)
  local expected = type(disenchant) == "table" and disenchant.expected or nil
  local results = type(expected) == "table" and expected.results or nil
  if type(results) ~= "table" or type(materialScores) ~= "table" then
    return asked
  end
  for _, result in ipairs(results) do
    local held = type(result) == "table" and materialScores[result.id] or nil
    if type(held) == "table" and type(held.viaCarried) == "table" then
      asked = asked or {}
      for via, answer in pairs(held.viaCarried) do
        if asked[via] == nil then
          asked[via] = answer
        end
      end
    end
  end
  return asked
end

-- Brief K20-wire: the material price function the disenchant facts use: opts.materialPrice where a
-- caller hands one in, else DisenchantValue.MaterialPrice (Prices.Auction, cached a minute).
function Keep.MaterialPriceFunction(opts)
  if type(opts) == "table" and type(opts.materialPrice) == "function" then
    return opts.materialPrice
  end
  local values = ItemTree.DisenchantValue
  if type(values) == "table" and type(values.MaterialPrice) == "function" then
    return values.MaterialPrice
  end
  return nil
end

-- Brief K20-wire: whether a disenchant material is itself a Keep for this player (design K20
-- section 1 step 4: "a dust their Enchanting route or current recipes need"), by its own score
-- through Keep.Score with the same professions and quests (never its own disenchant facts), and the
-- words of its first reason ("14 x Enchanting"). The material's score is held in
-- opts.materialScores where the caller keeps one (Keep.CachedScore's, dropped with its cache).
function Keep.MaterialKeep(materialId, playerLevel, playerFaction, playerClass, opts)
  opts = type(opts) == "table" and opts or EMPTY
  local held = type(opts.materialScores) == "table" and opts.materialScores[materialId] or nil
  if held == nil then
    held = Keep.Score(materialId, playerLevel, playerFaction, playerClass, {
      professions = opts.professions,
      completed = opts.completed,
      abandoned = opts.abandoned,
      -- Brief K22 (merge KSM3): the same bag count, so a material with an item combine (Illusion
      -- Dust has one) reads the same verdict here as on its own tooltip.
      carries = opts.carries,
      noDisenchant = true,
    }) or false
    if type(opts.materialScores) == "table" then
      opts.materialScores[materialId] = held
    end
  end
  if not held or not Keep.Marked(held) then
    return false
  end
  local lines = Keep.ReasonLines(held, nil)
  local first = lines[1]
  return true, type(first) == "table" and Keep.Plain(first.text) or nil
end

-- Brief TB2: where an item's one current use is a recipe and the player's professions are known
-- (score.recipeGroups), whose it is: "own" for a profession the player has (or the route's, or a
-- recipe no profession names, which anyone can make), "other" for one the player lacks; nil
-- for anything else (no professions known, more or fewer current uses, or a quest, lock or spell).
-- Pure.
function Keep.SingleRecipe(score)
  if type(score) ~= "table" or score.current ~= 1 or type(score.recipeGroups) ~= "table" then
    return nil
  end
  -- Brief TV1 (QA item 347 D1): the recipe a recipe item teaches is not a recipe that uses it.
  if (tonumber(score.teachUses) or 0) > 0 then
    return nil
  end
  local kinds = score.kinds or EMPTY
  if (tonumber(kinds.recipe) or 0) ~= 1 then
    return nil
  end
  if (tonumber(score.plainRecipes) or 0) == 1 then
    return "own"
  end
  local group = score.recipeGroups[1]
  if type(group) ~= "table" then
    return nil
  end
  if group.own then
    return "own"
  end
  return "other"
end

-- The mark rule: is it a Keep. Pure. Brief K1: an item sold everywhere never glows.
--
-- Brief K20b (design K20 section 1): "valuable" no longer means Keep. The owner's assumed answer
-- to design question 1, to confirm: a valuable item with no use reads Sell (AH) or Vendor in
-- orange, never Keep. So the rule here is steps 2 and 3 of the order of decision: the player's
-- Always, then (unless Never or Off) the route, then the uses (Keep.KeepRule). Brief K24b: the
-- tags (Keep.Tags) answer what an item shows; this answers only whether it is a Keep, for the bag
-- look's tier and the API's keep.marked.
function Keep.Marked(score)
  if type(score) ~= "table" then
    return false
  end
  -- Brief K4: the player's own word overrules the rule, whichever way it goes.
  if score.override == "always" then
    return true
  end
  if score.override == "never" or score.override == "off" then
    return false
  end
  -- Brief K20-wire: Keep (disenchant) wears the Keep look in the bag too. Brief BQ9: an item the
  -- character can open is no Keep (its [Open] verdict, Keep.DoNow), nor is an item that starts a
  -- quest the character can take now (its [Use] verdict).
  if Keep.DoNow(score) == Keep.ACTION_QUEST then
    return false
  end
  -- Brief K31: a tool of the player's professions is a Keep (the copy kept: the bags and the API
  -- read the copy from env.tool through the tags).
  if Keep.ToolKeeps(score) then
    return true
  end
  return Keep.KeepRule(score) or Keep.DisenchantKeeps(score)
end

-- Brief K20b: step 3 of the order of decision, the player's word aside: the Professions route
-- needs the item, or the Marked rule over its uses keeps it ("sold everywhere" still unmarks a use
-- based keep, never a route one). Brief K20-wire (design K20d): or the gear test, an upgrade the
-- player can wear now or within BEHIND levels (Keep.GearUpgrade). Pure.
function Keep.KeepRule(score)
  if type(score) ~= "table" then
    return false
  end
  -- Brief K30: where the route's count is 0 (or for the other verdict's view, Keep.TradeFree), the
  -- player's own trade uses and the route entry keep nothing; every other reason below stands.
  local spare = Keep.TradeSpare(score)
  -- Brief PR4: a reagent the profession route still needs, even one sold everywhere. Brief PM1:
  -- the route beats "sold everywhere", never the player's Never.
  if score.profession and not spare then
    return true
  end
  -- Brief K20-wire (design K20 section 1 step 3, G): equipment the player can wear now or within
  -- BEHIND levels that is an item level upgrade on what is worn.
  if Keep.GearUpgrade(score) then
    return true
  end
  -- Brief BQ6 (backlog 15): soulbound gear with a special effect, kept until its level.
  if Keep.GearLater(score) then
    return true
  end
  -- Brief BQ25c (item 52): a bag better than the equipped one of its kind, sold everywhere or not.
  if Keep.BagKeeps(score) then
    return true
  end
  if score.everywhere then
    return false
  end
  -- Brief K22: only the player's own current uses count here (Keep.Counted). Brief K30: less the
  -- trade uses where they keep nothing.
  local trade = 0
  if spare then
    trade = tonumber(score.tradeUses) or 0
  end
  local counted = math.max(0, Keep.Counted(score) - trade)
  local endgame = Keep.CountedEndgame(score)
  if spare and endgame then
    endgame = score.ownEndgameOther == true
  end
  if counted >= 2 or endgame then
    return true
  end
  -- Brief K22: an item combine whose via item (a crate) is in the bags is wanted now.
  if score.carried == true then
    return true
  end
  if score.kinds and (score.kinds.spell or 0) > 0 then
    return true
  end
  -- Brief RB5 (QA item 202, the owner's ruling 2 of 2026-10-14): a consumable for a profession the
  -- player has, at a rank not reached yet (Heavy Runecloth Bandage at First Aid 46), keeps far ahead,
  -- banked until the rank comes; never one sold everywhere (above).
  if Keep.ConsumableAhead(score) then
    return true
  end
  -- Brief TB10: a class locked consumable of the player's own class, like a class spell's reagent.
  if score.kinds and (score.kinds.class or 0) > 0 then
    return true
  end
  -- Brief TB12: a current quest use, whatever the item's level and its other uses. A quest item
  -- is kept until its quest is done or abandoned (TB4); a repeatable turn in never is. kinds
  -- counts current uses only, so the current count is read too for a hand built score.
  if score.current > 0 and score.kinds and (tonumber(score.kinds.quest) or 0) > 0 then
    return true
  end
  -- Brief TB9: a chain that ends in one of the player's professions.
  if (tonumber(score.chained) or 0) > 0 then
    return true
  end
  -- Brief TB2: one current recipe of the player's own profession (a cook keeps the fish). Brief
  -- K30: where the trade uses keep nothing, only a recipe no profession names still does.
  if Keep.SingleRecipe(score) == "own" and (not spare or (tonumber(score.plainRecipes) or 0) == 1) then
    return true
  end
  -- Brief K22: the same one recipe of the player's own beside other professions' recipes.
  local ownRecipes = (tonumber(score.ownRecipes) or 0) - trade
  if type(score.recipeGroups) == "table" and counted == 1 and ownRecipes == 1 then
    return true
  end
  return counted == 1 and (tonumber(score.own) or 0) >= Keep.OWN_LEVEL
end

-- Brief RB2B (QA item 267 (c), the owner: Jettison's bare "Locked: ItemTree keep" where the reason is
-- known): the reason a rule keep (Keep.KeepRule) rests on, where another addon can name it from a
-- profession, or nil: { kind, skill, via, name }, kind
--   "trade"    a recipe of a profession the character has keeps it: a crafting trade's that the route's
--              count does not leave spare (Keep.TradeSpare), a gathering trade's not grey
--              (score.gatherLines); skill its line
--   "tracked"  the same for a profession the character only tracks (score.ownProfessions leaves it out)
--   "chain"    a chain ending in one of the character's professions (score.chained, TB9): skill the
--              end's line, via the middle one's
--   "recipe"   a recipe no profession names keeps it (score.plainRecipes): name its shipped name
-- in that order, the first that holds. Pure.
function Keep.KeepWhy(score)
  if type(score) ~= "table" or not Keep.KeepRule(score) then
    return nil
  end
  local own = type(score.ownProfessions) == "table" and score.ownProfessions or nil
  local spare = Keep.TradeSpare(score)
  local gathered = {}
  for _, skill in ipairs(type(score.gatherLines) == "table" and score.gatherLines or EMPTY) do
    gathered[skill] = true
  end
  for _, group in ipairs(type(score.recipeGroups) == "table" and score.recipeGroups or EMPTY) do
    local skill = tonumber(group.skill)
    if group.own and skill then
      local keeps
      if Keep.GatherLine(skill) then
        keeps = Keep.IsOwnSkill(skill, gathered)
      else
        keeps = not spare
      end
      if keeps then
        local tracked = own ~= nil and not Keep.IsOwnSkill(skill, own)
        return { kind = tracked and "tracked" or "trade", skill = skill }
      end
    end
  end
  if (tonumber(score.chained) or 0) > 0 then
    for _, group in ipairs(type(score.chainGroups) == "table" and score.chainGroups or EMPTY) do
      if group.own and not group.stale then
        return { kind = "chain", skill = tonumber(group.skill), via = tonumber(group.viaSkill) }
      end
    end
  end
  if (tonumber(score.plainRecipes) or 0) > 0 and type(score.plainName) == "string" then
    return { kind = "recipe", name = score.plainName }
  end
  return nil
end

--------------------------------------------------------------------------------
-- Brief K20-wire: gear (design K20 sections 1 and 5, K20d). Core/Gear.lua's pure facts, put on
-- the score as score.gear by Keep.Score for equipment of every quality (brief K24h: grey and white
-- gear too, since at low levels a grey mail piece beats worn cloth; EQUIPMENT_QUALITY was 2):
--   usable   Gear.Usable's answer at the player's level plus BEHIND (true, false, nil not known)
--   why      its reason for a false or a nil ("class", "armour", "weapon", "level", ...)
--   now      brief K24h: true where the player can wear it at their REAL level (the Equip tag),
--            false where only within the look ahead, nil where the level is not known
--   compare  Gear.Compare's "upgrade", "not_upgrade" or "unknown" (nil where not usable); brief
--            K27: "upgrade" is an upgrade for ANY spec of the player's class
--   basis    brief K24h: Gear.Compare's basis, "level", "kind", "lighter" or "empty"; brief K27:
--            or "stats" (the spec gate, or the stats per spec decided)
--   specs    brief K27: the spec keys it upgrades in the class's order (Gear.SPECS), nil where
--            the stats compare did not decide (no class, nothing weighed: the K24h answer)
--   slots    brief K27: the worn slots an upgraded spec was held against (nil with no specs)
--   classId  brief K27: the player's class the compare weighed for, for the spec labels
--   scored   brief K27: how many of the class's specs were scored (the player's enabled specs)
--   il       the item's level, worn the worn reference's (il minus the difference), slot the
--            worn slot compared against, wornSubclass the worn piece's armour subclass
--   itemClass, subclass   the row's c and sc, for the words
--   roll     brief K28: the key of the random suffix roll the compare weighed (Gear.SuffixStats,
--            "b12761"), nil where the link named none the module prices
--   ahead    brief GW1: beyond the look ahead (usable false), the level the class first wears it
--            (Gear.WearLevel), where the compare read it at that level; an "upgrade" there is a Keep
--            ("Upgrade for your Hands at level 49 (Holy, Retribution)")
--   at       brief GW1: the level the compare read the item at where it is above the player's (a
--            piece for later, within the look ahead or beyond it), nil for one worn at their level
--   needs    brief GW1: the level a piece needs where it is above the level cap (never reached)
--   poor     brief GW1b: true for a grey piece beyond the look ahead, never compared ("Poor quality")
--   common   brief GW3 (3B): true for a white piece beyond the look ahead, never compared ("Common
--            quality")
--   unwanted brief GW1: true where it is not an upgrade because no spec scored weighs its stats at
--            all (Gear.SpecsWant: the spec gate), "Not for your specs"
--   classes  brief GW1: the class ids the row's class list names, where it leaves the player out
--            (why "class"), for "Not for your class (Paladin only)"
-- Brief K27: stats per spec decide where the rows carry them (Core/Gear.lua's header has every
-- rule and fallback); item level and armour kind stand where they do not. Pure.
--------------------------------------------------------------------------------

--- Brief ST3 (QA item 320, the owner's ruling A): whether an enabled spec set turns gear
--- suggestions off: an empty set, every spec of the class unticked (Keep.EnabledSpecs). nil is every
--- spec, as before. Pure.
function Keep.GearOff(enabledSpecs)
  return type(enabledSpecs) == "table" and next(enabledSpecs) == nil
end

-- The gear facts for one shipped row and the player, or nil for anything that is not equipment,
-- or where Core/Gear.lua is not loaded. worn is Gear.Worn's map (nil compares as "unknown"), level
-- and classId the player's (nil: not known). Brief K27: enabledSpecs, the player's per character
-- spec setting as a set (Keep.EnabledSpecs; nil for every spec). Brief K28: link, the item's own
-- link (a bag slot's, a tooltip's), whose random suffix roll (Gear.SuffixStats, one split per
-- link string) the compare weighs as stats; nil, or a link with no roll the module prices, is the
-- K27 answer exactly. Brief ST3 (QA item 320): an empty enabledSpecs (Keep.GearOff, every spec
-- unticked) answers nil and true for gear the compare would have judged: no facts, so the item is
-- judged like any other, and the true tells Keep.Score it is gear with suggestions off. Pure.
function Keep.GearFacts(row, worn, classId, level, enabledSpecs, link)
  local gear = ItemTree.Gear
  if type(gear) ~= "table" or type(gear.Usable) ~= "function" or type(row) ~= "table" then
    return nil
  end
  if not Keep.EQUIPMENT_CLASSES[tonumber(row.c) or -1] or (tonumber(row.q) or 0) < Keep.EQUIPMENT_QUALITY then
    return nil
  end
  if type(gear.SlotsFor) ~= "function" or not gear.SlotsFor(row.it) then
    return nil
  end
  -- Brief GW1 (the owner's ruling, QA item 101 (a)): a cosmetic (armour subclass 5) is never gear
  -- to compare; Keep.CosmeticFacts judges it as its own kind.
  if type(gear.IsCosmetic) == "function" and gear.IsCosmetic(row) then
    return nil
  end
  -- Brief ST3 (QA item 320, the owner's ruling A): no spec ticked, no gear suggestion: no compare, no
  -- "Upgrade for", no Equip, no Keep for its level, no "Not for your class".
  if Keep.GearOff(enabledSpecs) then
    return nil, true
  end
  level = tonumber(level)
  -- Brief K24b (owner ruling 11): how far ahead the player is judged by the item's quality: green
  -- and below 3 levels, blue 10, epic and better any level the class can ever use it (nil).
  local within = Keep.GearWithin(level, row.q)
  local usable, why = gear.Usable(row, classId, within)
  local facts = {
    usable = usable,
    why = why,
    il = tonumber(row.il),
    rl = tonumber(row.rl),
    level = level,
    itemClass = tonumber(row.c),
    subclass = tonumber(row.sc),
  }
  -- Brief GW1 (the owner's rule for the round, QA items 101 and 102): in order, the class list on
  -- the item, then the armour or weapon kind the class can ever wear (Gear.WearLevel), whatever the
  -- level: the first that fails is the one reason, "Not for your class (Paladin only)", "Not for
  -- your class (plate)". An empty slot never makes such an item an upgrade.
  local wearAt, never = nil, nil
  if type(gear.WearLevel) == "function" then
    wearAt, never = gear.WearLevel(row, classId)
  end
  if wearAt == nil and Keep.GEAR_NOT_FOR_CLASS[never] then
    facts.usable, facts.why = false, never
    if never == "class" then
      facts.classes = Keep.MaskClasses(row.ac)
    end
    return facts
  end
  if usable == false then
    -- Brief BQ6 (backlog 15): soulbound gear with a Use or special Equip effect, beyond the window
    -- only by its level, is kept until that level.
    facts.later = Keep.LaterLevel(row, classId, why)
    if facts.later ~= nil or wearAt == nil or level == nil or wearAt <= level then
      return facts
    end
    -- Brief GW1: a level the character can never reach (a row above the level cap) says so.
    if wearAt > Keep.MaxLevel() then
      facts.needs = wearAt
      return facts
    end
    -- Brief GW1b (decided): a poor quality (grey) piece is never kept far ahead: no compare at its
    -- level, the ordinary sale verdict with the muted "Poor quality". Brief GW3 (the owner's ruling
    -- 3B, 2026-10-13: "whites go the way of greys"): a common quality (white) piece neither, with its
    -- own muted "Common quality". Greens and better go on.
    local quality = tonumber(row.q) or 0
    if quality == Keep.QUALITY_POOR then
      facts.poor = true
      return facts
    end
    if quality == Keep.QUALITY_COMMON then
      facts.common = true
      return facts
    end
    -- Brief GW1 (the owner's ruling, QA item 97 and 101's correction: "keep binds on pickup gear
    -- that is for your class and will be an upgrade at its level, however far ahead"; item 102 (a):
    -- any far ahead upgrade, with the price tags beside the keep as usual): beyond the look ahead,
    -- the item is compared at the level the class first wears it against what is worn now, for the
    -- specs open at that level. facts.ahead is that level; the compare below fills the rest.
    facts.ahead = wearAt
  end
  -- Brief K24h: whether the player can wear it today, at their real level, which is what turns a
  -- Keep into an Equip. Not known (nil) without a level.
  if usable == true and level ~= nil then
    if within == level then
      facts.now = true
    else
      facts.now = gear.Usable(row, classId, level) == true
    end
  end
  -- Brief GW1: the level the compare reads the item at: the player's for a piece they can wear now,
  -- else the level the class first wears it (Gear.WearLevel: its required level, mail and plate at
  -- 40, Dual Wield's level), so a piece for later is weighed for the specs open then, its ratings at
  -- that level, against what is worn now. facts.at holds it where it is above the player's.
  local at = level
  if wearAt ~= nil and level ~= nil and wearAt > level and facts.now ~= true then
    at = wearAt
    facts.at = wearAt
  end
  -- Brief K24b (C1): a one hander is held against the off hand only where the player can dual
  -- wield NOW, at their real level ("Upgrade for your Off Hand (28 over 0)" on a level 14 hunter
  -- was the fault). An unknown level keeps the old answer (at some level). Brief GW1: at the level
  -- the compare reads the item at.
  local dual = nil
  if classId ~= nil and type(gear.CanDualWield) == "function" then
    dual = gear.CanDualWield(classId, at)
  end
  -- Brief K27: the player's class, so the compare weighs the stats for each of its specs that the
  -- player's setting leaves on, and the player's real level, which a rating is read at (the score
  -- cache's key holds the level, so a level up scores again).
  -- Brief K28: the roll in the item's link, priced for its row, nil where there is none.
  local suffix, roll = nil, nil
  if type(link) == "string" and type(gear.SuffixStats) == "function" then
    local okRoll, stats, key = pcall(gear.SuffixStats, link, row)
    if okRoll then
      suffix, roll = stats, key
    end
  end
  local compare, diff, slot, basis, specs, slots = gear.Compare(row, worn, dual, classId, enabledSpecs, at, suffix)
  facts.compare, facts.slot, facts.basis = compare, slot, basis
  -- Brief GW1: not an upgrade because no spec scored wants its stats at all (the spec gate), the
  -- third of the owner's checks, "Not for your specs".
  if
    compare == "not_upgrade"
    and basis == "stats"
    and type(specs) == "table"
    and #specs == 0
    and type(gear.SpecsWant) == "function"
    and not gear.SpecsWant(row, classId, enabledSpecs, at, suffix)
  then
    facts.unwanted = true
  end
  facts.roll = roll
  facts.specs, facts.slots, facts.classId = specs, slots, tonumber(classId)
  -- Brief K27: how many specs were scored, so the line reads plain for an upgrade for every one.
  if type(gear.ScoredSpecs) == "function" then
    -- Brief BQ30: at the player's level, so a closed spec is never counted. Brief GW1: at the level
    -- the compare read the item at.
    local scored = gear.ScoredSpecs(classId, enabledSpecs, at)
    facts.scored = type(scored) == "table" and #scored or nil
    -- Brief BQ30 addendum (QA item 96): the scored specs themselves, for the Equip pill's names.
    facts.scoredSpecs = type(scored) == "table" and scored or nil
  end
  if tonumber(diff) and facts.il then
    facts.diff = tonumber(diff)
    facts.worn = facts.il - facts.diff
  end
  -- Brief K24h: the worn piece's armour subclass, for the "mail over cloth" words.
  local entry = type(worn) == "table" and slot ~= nil and worn[slot] or nil
  if type(entry) == "table" then
    facts.wornSubclass = tonumber(entry.sc)
  end
  return facts
end

-- Brief K27 (owner 2026-10-08): the per character spec setting. Each spec of the player's class can
-- be turned off for gear suggestions in Settings (UI/Options.lua Options.SpecDefinitions), all on by
-- default. Stored in ItemTreeCharDB as the specs turned OFF (ItemTree.charDb.gearSpecsOff =
-- { holy = true }), made on the first one, so a character that never touched the setting stores
-- nothing. A character's class never changes, so the spec keys need no class beside them. Brief ST3
-- (QA item 320, the owner's ruling A): every box unticked turns gear suggestions off (Keep.GearOff);
-- it read as every box ticked before.
local function specsOffStore(create)
  local charDb = ItemTree.charDb
  if type(charDb) ~= "table" then
    return nil
  end
  local store = charDb.gearSpecsOff
  if type(store) ~= "table" then
    if not create then
      return nil
    end
    store = {}
    charDb.gearSpecsOff = store
  end
  return store
end

-- Whether a spec is on for this character's gear suggestions: true unless turned off. Pure over
-- ItemTree.charDb.
function Keep.SpecEnabled(spec)
  local store = specsOffStore(false)
  return not (store ~= nil and store[spec] == true)
end

-- Turns a spec on or off for this character and drops the held set (Keep.EnabledSpecs), so the
-- next score reads the new one; the score cache's key holds the set, so every item is scored again.
-- Answers whether the setting changed.
function Keep.SetSpecEnabled(spec, on)
  if type(spec) ~= "string" or spec == "" then
    return false
  end
  local was = Keep.SpecEnabled(spec)
  local wanted = on and true or false
  if was == wanted then
    return false
  end
  local store = specsOffStore(true)
  if not store then
    return false
  end
  if wanted then
    store[spec] = nil
  else
    store[spec] = true
  end
  Keep.enabledSpecsHeld = nil
  return true
end

-- The set the gear compare takes for a class (Gear.Compare's enabledSpecs) and its signature for
-- the score cache's key: nil, nil where every spec of the class is on or the class has no specs;
-- else { holy = true, ... } and the keys in the class's order, "holy,retribution". Brief ST3 (QA
-- item 320, the owner's ruling A): every one off is the empty set and "none", gear suggestions off
-- (Keep.GearOff); it was nil, nil (all on) before. Held until the setting moves (Keep.SetSpecEnabled),
-- the class or the saved table changes, or Keep.Reset, so a bag pass reads one held answer per
-- slot.
function Keep.EnabledSpecs(classId)
  -- Brief BQ13: the pretend specs (/itemtree demo spec) answer instead of the setting while set.
  local demo = demoState()
  if demo and type(demo.Specs) == "function" then
    local ok, on, set, signature = pcall(demo.Specs, classId)
    if ok and on then
      return set, signature
    end
  end
  local held = Keep.enabledSpecsHeld
  local charDb = ItemTree.charDb
  if held and held.classId == classId and held.charDb == charDb then
    return held.set, held.signature
  end
  local set, signature = nil, nil
  local gear = ItemTree.Gear
  local specs = type(gear) == "table" and type(gear.SPECS) == "table" and gear.SPECS[tonumber(classId) or -1] or nil
  if type(specs) == "table" then
    local on = {}
    for _, spec in ipairs(specs) do
      if Keep.SpecEnabled(spec) then
        on[#on + 1] = spec
      end
    end
    if #on > 0 and #on < #specs then
      set = {}
      for _, spec in ipairs(on) do
        set[spec] = true
      end
      signature = table.concat(on, ",")
    elseif #on == 0 and #specs > 0 then
      -- Brief ST3 (QA item 320): no spec ticked, gear suggestions off.
      set, signature = {}, "none"
    end
  end
  Keep.enabledSpecsHeld = { classId = classId, charDb = charDb, set = set, signature = signature }
  return set, signature
end

-- Brief K31: a score's gear facts, or nil for none and for a profession tool (score.tool), which is
-- never judged as gear whatever facts a caller put on it: no upgrade, no Equip, no gear line. Pure.
function Keep.GearOf(score)
  if type(score) ~= "table" or type(score.tool) == "table" then
    return nil
  end
  return type(score.gear) == "table" and score.gear or nil
end

-- Brief K24h: whether the gear test keeps an item the player can wear TODAY: an upgrade (or a
-- piece for an empty slot) at their real level, which the tags call Equip rather than Keep. Pure.
function Keep.EquipNow(score)
  local gear = type(score) == "table" and score.gear or nil
  return Keep.GearUpgrade(score) and type(gear) == "table" and gear.now == true
end

-- Brief K24b (owner ruling 11): the levels ahead the gear test looks, by quality: uncommon (green)
-- and below GEAR_AHEAD_GREEN, rare (blue) GEAR_AHEAD_RARE, epic and better nil (any level the class
-- can ever use it: "keep until you're that level").
Keep.GEAR_AHEAD_GREEN = 3
Keep.GEAR_AHEAD_RARE = 10
Keep.QUALITY_RARE = 3
Keep.QUALITY_EPIC = 4

-- The level the gear test reads an item at for a player of this level and an item of this
-- quality, or nil for no level limit (an epic, or the player's level not known). Pure.
function Keep.GearWithin(level, quality)
  level = tonumber(level)
  if level == nil then
    return nil
  end
  quality = tonumber(quality) or 0
  if quality >= Keep.QUALITY_EPIC then
    return nil
  end
  if quality == Keep.QUALITY_RARE then
    return level + Keep.GEAR_AHEAD_RARE
  end
  return level + Keep.GEAR_AHEAD_GREEN
end

-- Brief BQ6 (backlog 15): the client's spell trigger codes on a row's fx entries ({ trigger, spellId,
-- ... }, ItemSpellTriggerType): 0 on use, 1 on equip, 2 a chance on hit.
Keep.TRIGGER_USE = 0
Keep.TRIGGER_EQUIP = 1
Keep.TRIGGER_HIT = 2

--- Brief BQ6 (backlog 15): whether a gear row carries a Use effect or a special Equip effect, a spell
--- rather than plain stats: any use spell or chance on hit spell, or an equip spell on a row whose
--- equip spells give no stat (no es: the pipeline turns an equip spell that is a plain stat, "+7
--- spell damage", into es, so a row with es is read as stats; Carrot on a Stick's mount speed has
--- none). Pure.
function Keep.SpecialEffect(row)
  if type(row) ~= "table" or type(row.fx) ~= "table" then
    return false
  end
  local stats = type(row.es) == "table" and next(row.es) ~= nil
  for _, effect in ipairs(row.fx) do
    local trigger = type(effect) == "table" and tonumber(effect[1]) or nil
    local spell = type(effect) == "table" and tonumber(effect[2]) or 0
    if spell and spell > 0 then
      if trigger == Keep.TRIGGER_USE or trigger == Keep.TRIGGER_HIT then
        return true
      end
      if trigger == Keep.TRIGGER_EQUIP and not stats then
        return true
      end
    end
  end
  return false
end

--- Brief BQ6 (backlog 15, the owner's answer of 2026-10-10): the level soulbound gear is kept for,
--- or nil: the row binds when picked up (so it can never go to the auction house), Gear.Usable said
--- no for its level alone (why "level", beyond the window Keep.GearWithin gives its quality), the
--- class can use it at its required level, and it carries a Use or special Equip effect
--- (Keep.SpecialEffect). No quality gate and no item list. Pure over Core/Gear.lua.
function Keep.LaterLevel(row, classId, why)
  local gear = ItemTree.Gear
  if why ~= "level" or type(row) ~= "table" or type(gear) ~= "table" or type(gear.Usable) ~= "function" then
    return nil
  end
  if tonumber(row.b) ~= Keep.BOP_BONDING or not Keep.SpecialEffect(row) then
    return nil
  end
  local required = tonumber(row.rl)
  if required == nil or required <= 0 then
    return nil
  end
  local ok, usable = pcall(gear.Usable, row, classId, required)
  if ok and usable == true then
    return required
  end
  return nil
end

--- Brief BQ6 (backlog 15): whether the gear test keeps an item for later (Keep.LaterLevel). Pure.
function Keep.GearLater(score)
  local gear = Keep.GearOf(score)
  return type(gear) == "table" and tonumber(gear.later) ~= nil
end

-- Whether the gear test keeps an item: usable now or within the look ahead, and an upgrade. Brief
-- K27: an upgrade for ANY spec of the player's class counts (Gear.Compare answers "upgrade" then).
-- Brief GW1 (the owner's rulings, QA items 97, 101 and 102): or beyond the look ahead, an upgrade at
-- the level the class first wears it (gear.ahead), however far ahead. Pure.
function Keep.GearUpgrade(score)
  local gear = Keep.GearOf(score)
  if type(gear) ~= "table" or gear.compare ~= "upgrade" then
    return false
  end
  return gear.usable == true or tonumber(gear.ahead) ~= nil
end

-- Brief GW1: the class names of a class list, "Paladin", "Warrior and Paladin", "Warrior, Paladin
-- and Hunter" (Keep.ClassName), or nil for none. Pure.
function Keep.ClassListWords(classIds)
  local names = {}
  for _, classId in ipairs(type(classIds) == "table" and classIds or EMPTY) do
    local name = Keep.ClassName(classId)
    if name then
      names[#names + 1] = name
    end
  end
  if #names == 0 then
    return nil
  end
  if #names == 1 then
    return names[1]
  end
  local last = table.remove(names)
  return string.format(L["%s and %s"], table.concat(names, ", "), last)
end

-- Brief GW1 (the owner's ruling, QA item 101 (a)): a cosmetic piece (armour subclass 5,
-- Gear.IsCosmetic: "Use: Add this appearance to your Account collection") is its own kind, never
-- gear: { collected } where collected is true (the account has the appearance), false (it has not)
-- or nil (not known: the client cannot say, read as not collected). nil for any other row. collected
-- is the caller's answer where it gives one (true or false), else the client's
-- (Keep.AppearanceCollected over itemId). Brief GW1c: only a subclass 5 piece the pipeline marks
-- with cl 1 is collected by using it (ItemSparse.Flags_3 bit 0x800000: Forever's appearance pieces
-- and the Bloodsail set; the shirts, tuxedo pieces and Hallow's End masks have no marker). The
-- client draws that Use line from a cosmetic flag, not an item spell, so the row is the one answer.
-- Without the marker it is nil here, no collect action and no "Appearance collected"
-- (Keep.GearFacts still never judges the piece as gear). Pure but for the collected read.
-- Brief TV1 (QA item 347, the owner on White Tuxedo Shirt 6833: "This cosmetic item HAS NOT BEEN
-- COLLECTED - it is also not bound. The user should wear it and collect the appearnce and after they
-- can then vendor it"): a piece WITHOUT the marker whose row names no bonding (wearing it binds
-- nothing, so it can still be sold after) is collected by wearing it: { collected, wear = true },
-- [Use] "Wear it to collect the appearance" while not collected. A piece without the marker that
-- binds (the Hallow's End masks bind when equipped) is nil as before.
function Keep.CosmeticFacts(row, collected, itemId)
  local gear = ItemTree.Gear
  if type(gear) ~= "table" or type(gear.IsCosmetic) ~= "function" or not gear.IsCosmetic(row) then
    return nil
  end
  local wear = nil
  if tonumber(row.cl) ~= 1 then
    if (tonumber(row.b) or 0) ~= 0 then
      return nil
    end
    wear = true
  end
  if collected ~= true and collected ~= false then
    collected = Keep.AppearanceCollected(itemId)
  end
  return { collected = collected, wear = wear }
end

-- Brief GW1: whether a score is a cosmetic to use now, its appearance not known to be collected:
-- [Use] "Use it to collect the appearance" while the client says it is not collected (and while it
-- cannot say). Pure.
function Keep.CollectNow(score)
  local cosmetic = type(score) == "table" and score.cosmetic or nil
  return type(cosmetic) == "table" and cosmetic.collected ~= true
end

-- Brief GW1: whether a score is a cosmetic whose appearance the account has: its ordinary sale
-- verdict, "Appearance collected". Pure.
function Keep.CosmeticCollected(score)
  local cosmetic = type(score) == "table" and score.cosmetic or nil
  return type(cosmetic) == "table" and cosmetic.collected == true
end

-- A worn slot's words, "Chest", "Main Hand". Written out one literal at a time for the locale
-- sweep. Pure.
function Keep.SlotWords(slot)
  local gear = ItemTree.Gear
  local S = type(gear) == "table" and gear.SLOT or EMPTY
  if slot == S.HEAD then
    return L["Head"]
  elseif slot == S.NECK then
    return L["Neck"]
  elseif slot == S.SHOULDER then
    return L["Shoulder"]
  elseif slot == S.SHIRT then
    return L["Shirt"]
  elseif slot == S.CHEST then
    return L["Chest"]
  elseif slot == S.WAIST then
    return L["Waist"]
  elseif slot == S.LEGS then
    return L["Legs"]
  elseif slot == S.FEET then
    return L["Feet"]
  elseif slot == S.WRIST then
    return L["Wrist"]
  elseif slot == S.HANDS then
    return L["Hands"]
  elseif slot == S.FINGER1 or slot == S.FINGER2 then
    return L["Finger"]
  elseif slot == S.TRINKET1 or slot == S.TRINKET2 then
    return L["Trinket"]
  elseif slot == S.BACK then
    return L["Back"]
  elseif slot == S.MAINHAND then
    return L["Main Hand"]
  elseif slot == S.OFFHAND then
    return L["Off Hand"]
  elseif slot == S.RANGED then
    return L["Ranged"]
  elseif slot == S.TABARD then
    return L["Tabard"]
  end
  return nil
end

-- An armour (class 4) or weapon (class 2) subclass in words, "cloth", "one-hand sword", or nil for
-- one with no plain word (miscellaneous, a subclass the tables do not know). Pure.
function Keep.SubclassWords(itemClass, subclass)
  if itemClass == 4 then
    if subclass == 1 then
      return L["cloth"]
    elseif subclass == 2 then
      return L["leather"]
    elseif subclass == 3 then
      return L["mail"]
    elseif subclass == 4 then
      return L["plate"]
    elseif subclass == 6 then
      -- Brief K27: armour subclass 5 is cosmetic (no plain word), not a buckler.
      return L["shield"]
    elseif subclass == 7 then
      return L["libram"]
    elseif subclass == 8 then
      return L["idol"]
    elseif subclass == 9 then
      return L["totem"]
    end
    return nil
  end
  if itemClass ~= 2 then
    return nil
  end
  if subclass == 0 then
    return L["one-hand axe"]
  elseif subclass == 1 then
    return L["two-hand axe"]
  elseif subclass == 2 then
    return L["bow"]
  elseif subclass == 3 then
    return L["gun"]
  elseif subclass == 4 then
    return L["one-hand mace"]
  elseif subclass == 5 then
    return L["two-hand mace"]
  elseif subclass == 6 then
    return L["polearm"]
  elseif subclass == 7 then
    return L["one-hand sword"]
  elseif subclass == 8 then
    return L["two-hand sword"]
  elseif subclass == 10 then
    return L["staff"]
  elseif subclass == 13 then
    return L["fist weapon"]
  elseif subclass == 15 then
    return L["dagger"]
  elseif subclass == 16 then
    return L["thrown"]
  elseif subclass == 18 then
    return L["crossbow"]
  elseif subclass == 19 then
    return L["wand"]
  end
  return nil
end

-- Brief K24e: the two item levels of the gear line, the worn one first: drawn with a small inline
-- right arrow between them ("13 |T..|t 28", the Assets key Keep.ARROW_ICON through Keep.InlineGlyph,
-- which the chain lines use too), and as plain words ("13 to 28"). The arrow is a texture because
-- the client's tooltip font may not carry the arrow character. Where the art is not there to draw,
-- both answers are the plain words. Pure apart from the art read.
Keep.ARROW_ICON = "ICON_ARROW_RIGHT"
function Keep.LevelPair(worn, il)
  local plain = string.format(L["%d to %d"], worn, il)
  local arrow = Keep.InlineGlyph(Keep.ARROW_ICON)
  if arrow == "" then
    return plain, plain
  end
  return tostring(worn) .. " " .. arrow .. tostring(il), plain
end

-- The reasons Gear.Usable gives for an item the class never uses (rather than one it cannot use
-- yet): these read "Not for your class".
Keep.GEAR_NOT_FOR_CLASS = { class = true, armour = true, weapon = true, dual_wield = true }

-- The gear line's words, whether it is muted, and its plain words (no inline texture), or nil
-- for nothing to say:
--   "Upgrade for your Chest (ilvl 22 -> 28)"     an upgrade the player can wear
--   "Upgrade for your Main Hand at level 23 (ilvl 12 -> 28)"   brief K24b: one they can wear later
-- Brief K24e (owner QA 2026-10-06, his own mock-up): the WORN item level first, then the item's,
-- joined by a small inline arrow (Keep.LevelPair); the plain words read "12 to 28".
--   "Not an upgrade"                             muted (brief K24d, the owner: "'You wear item
--                                                level 13' doesn't really say anything useful")
--   "Not for your class (cloth)"                 muted; "Not for your class" with no word
-- Brief K24d (the owner asked "what does 28 over 13 mean?"): the two item levels in words.
-- "unknown", or an item not usable only by level (beyond the look ahead), adds nothing. Brief
-- K24b (C3): where the row's class mask leaves the class out (why "class") the line is "Not for
-- your class" alone: the armour or weapon word would claim the class cannot wear that kind
-- ("Not for your class (leather)" on a hunter, who wears leather at every level). Brief K27: where
-- the stats decided, the brackets name the specs it upgrades ("Upgrade for your Chest (Holy
-- Paladin)"), and an upgrade for every spec reads plain ("Upgrade for your Chest"); not an upgrade
-- for any spec reads "Not an upgrade", muted, even where the spec gate answered with no worn item
-- level known. Brief RP-AI (ST3's note on QA item 320): gear whose suggestions the player turned off
-- (every "Suggest gear for" box unticked, score.gearOff, Keep.GearOff) has no gear facts; it reads
-- "Gear suggestions off", muted, where its gear line would stand, so its Vendor or Auction tag never
-- stands bare. Pure.
function Keep.GearWords(score)
  local gear = Keep.GearOf(score)
  if type(gear) ~= "table" then
    if type(score) == "table" and score.gearOff == true and type(score.tool) ~= "table" then
      return L["Gear suggestions off"], true
    end
    return nil
  end
  -- Brief BQ6 (backlog 15): "Keep for level 36". Brief TV1 (QA item 347, the owner on Tidal Charm at
  -- 15: "Maybe just Useful at level 36?"): "Useful at level 36", so the Keep tag's word is not said
  -- twice.
  if tonumber(gear.later) then
    local words = string.format(L["Useful at level %d"], tonumber(gear.later))
    return words, false, words
  end
  -- Brief GW1: a piece above the level cap. Brief GW2 (QA item 139): "the cap" is the level cap,
  -- Keep.MaxLevel() (the client's GetMaxPlayerLevel, else Keep.MAX_LEVEL): gear.needs is set only
  -- where the class first wears the piece above it, with no compare made, so this line can never
  -- stand in for an upgrade; "Needs level N" says nothing else.
  if tonumber(gear.needs) then
    return string.format(L["Needs level %d"], tonumber(gear.needs)), true
  end
  -- Brief GW1b: a grey piece beyond the look ahead, never compared at its level. Brief GW3 (3B): a
  -- white one likewise, in its own words. Brief TV1 (QA item 347, the owner's ruling G: "To me its the
  -- Low quality - We already have this rule pretty well established we dont care about white after
  -- early game unless they have uses"): "Low quality" (was "Common quality"), never the cause ("Mail
  -- from level 40"). Where the early game ends is unchanged: Keep.GearFacts sets gear.common only for
  -- a white piece beyond the look ahead (Keep.GearWithin, the player's level + GEAR_AHEAD_GREEN).
  if gear.poor == true then
    return L["Poor quality"], true
  end
  if gear.common == true then
    return L["Low quality"], true
  end
  local worn = tonumber(gear.worn)
  if gear.usable == false and tonumber(gear.ahead) == nil then
    if not Keep.GEAR_NOT_FOR_CLASS[gear.why] then
      return nil
    end
    -- Brief GW1 (QA item 101 (g)): the class list names the classes it is for, "Not for your class
    -- (Paladin only)"; an off hand weapon a class never dual wields says so rather than naming a
    -- weapon kind the class may well use in the main hand.
    if gear.why == "class" then
      local who = Keep.ClassListWords(gear.classes)
      if who then
        return string.format(L["Not for your class (%s only)"], who), true
      end
      return L["Not for your class"], true
    end
    if gear.why == "dual_wield" then
      return L["Not for your class (off hand weapon)"], true
    end
    local word = Keep.SubclassWords(gear.itemClass, gear.subclass)
    if word then
      return string.format(L["Not for your class (%s)"], word), true
    end
    return L["Not for your class"], true
  end
  -- Brief GW1: no spec scored wants its stats (the spec gate), whenever it is worn.
  if gear.unwanted == true and gear.compare == "not_upgrade" then
    return L["Not for your specs"], true
  end
  -- Brief GW1: beyond the look ahead, compared at the level the class first wears it (gear.ahead):
  -- not an upgrade there says so with the level. Brief GW2 (QA item 139): a found upgrade always
  -- wins (the branch below); a compare that could not be made (a worn piece whose level is not
  -- known) says so, as one the player can wear now does, never "Needs level N" (that line is the
  -- level cap's alone, above).
  local ahead = tonumber(gear.ahead)
  if ahead and gear.compare ~= "upgrade" then
    if gear.compare == "not_upgrade" then
      return string.format(L["Not an upgrade at level %d"], ahead), true
    end
    return L["Nothing to compare"], true
  end
  if gear.compare == "upgrade" and (gear.usable == true or ahead) and worn and gear.il then
    local slotWords = Keep.SlotWords(gear.slot)
    local drawn, plain = Keep.UpgradeDetail(gear)
    -- Brief GW1: the level it is an upgrade at, where it is above the player's (gear.at: the level
    -- the class first wears it), else its required level as before.
    local rl, level = tonumber(gear.at) or tonumber(gear.rl), tonumber(gear.level)
    -- Brief K27: an upgrade for every spec of the class, no brackets.
    if drawn == nil then
      local words = L["Upgrade"]
      if slotWords and rl and level and rl > level then
        words = string.format(L["Upgrade for your %s at level %d"], slotWords, rl)
      elseif slotWords then
        words = string.format(L["Upgrade for your %s"], slotWords)
      end
      return words, false, words
    end
    if slotWords and rl and level and rl > level then
      local later = L["Upgrade for your %s at level %d (%s)"]
      return string.format(later, slotWords, rl, drawn), false, string.format(later, slotWords, rl, plain)
    end
    if slotWords then
      local now = L["Upgrade for your %s (%s)"]
      return string.format(now, slotWords, drawn), false, string.format(now, slotWords, plain)
    end
    local bare = L["Upgrade (%s)"]
    return string.format(bare, drawn), false, string.format(bare, plain)
  end
  -- Brief K24h: body armour of a lighter kind than the worn piece, Jettison's own words.
  if gear.compare == "not_upgrade" and gear.basis == "lighter" then
    return L["Lighter armour than you wear"], true
  end
  if gear.compare == "not_upgrade" and (worn or gear.basis == "stats") then
    return L["Not an upgrade"], true
  end
  -- Brief GW1b: a piece the player can wear whose compare could not be made (the worn piece or
  -- its level not known, no item level): it says so rather than leaving a Vendor bare.
  if gear.usable == true and gear.compare ~= "upgrade" then
    return L["Nothing to compare"], true
  end
  return nil
end

-- Brief K27: the labels of the specs an upgrade names, joined with ", " ("Holy, Protection"), the
-- spec alone (the owner's ruling: only the player's own class is ever named), or nil where the
-- line names none: no spec list (the stats did not decide), an empty
-- one, or every spec scored (every ENABLED spec, gear.scored) while Gear.NAME_ALL_SPECS is false
-- (the owner's plain line). Only the player's own class's specs are ever in the list. Pure.
function Keep.SpecWords(gear)
  local specs = type(gear) == "table" and gear.specs or nil
  local model = ItemTree.Gear
  if type(specs) ~= "table" or #specs == 0 or type(model) ~= "table" or type(model.SpecLabel) ~= "function" then
    return nil
  end
  -- Brief K27: every spec scored, which is every spec the player's setting leaves on.
  local every = tonumber(gear.scored)
  if every == nil then
    local list = type(model.SPECS) == "table" and model.SPECS[tonumber(gear.classId) or -1] or nil
    every = type(list) == "table" and #list or nil
  end
  if model.NAME_ALL_SPECS ~= true and every ~= nil and #specs >= every then
    return nil
  end
  local labels = {}
  for _, spec in ipairs(specs) do
    local label = model.SpecLabel(gear.classId, spec)
    if type(label) == "string" and label ~= "" then
      labels[#labels + 1] = label
    end
  end
  if #labels == 0 then
    return nil
  end
  return table.concat(labels, ", ")
end

-- Brief BQ30 addendum (the owner's ruling of 2026-10-10, QA item 92: a bare "Equip" reads as "for
-- the spec I'm in now"): the specs an [Equip] tag names in short form, "BM, MM", or "Any".
-- Brief BQ30 addendum (QA item 96, the owner's QA of the pill: Survival alone ticked read "Equip
-- (Any)", which misleads): "Any" means every spec of the CLASS open at the player's level wants it
-- (Gear.SpecsFor: all three hunter specs at 30, two below); where the enabled set is narrower, the
-- wanting specs among the enabled ones are named, so Survival alone reads "Surv". The stats did
-- not decide (an item level or armour kind upgrade, an empty slot nothing weighs: one for every
-- scored spec): "Any" only where the scored specs are the whole open class, else the scored specs
-- named. In the class's order. nil where the score has no gear facts or the class has no specs (a
-- bag's Equip tag stays plain). Pure over Core/Gear.lua.
-- Brief EQ2 (QA item 342, the owner 2026-10-21: "Let's add "Any spec" to make it clear what any
-- means"): the every spec label reads "Any spec", so the pill and the plain word say "Equip (Any
-- spec)". When it applies is unchanged.
function Keep.EquipSpecWords(score)
  local gear = type(score) == "table" and score.gear or nil
  local model = ItemTree.Gear
  if type(gear) ~= "table" or type(model) ~= "table" or type(model.SPECS) ~= "table" then
    return nil
  end
  local classId = tonumber(gear.classId)
  if classId == nil or model.SPECS[classId] == nil then
    return nil
  end
  local open = type(model.SpecsFor) == "function" and model.SpecsFor(classId, gear.level) or model.SPECS[classId]
  local specs = gear.specs
  if type(specs) ~= "table" or #specs == 0 then
    specs = type(gear.scoredSpecs) == "table" and gear.scoredSpecs or open
  end
  if #specs >= #open then
    return L["Any spec"]
  end
  local short = type(model.SpecShortList) == "function" and model.SpecShortList(classId, specs) or nil
  return short or L["Any spec"]
end

-- Brief K24h: the words inside an upgrade line's brackets, drawn and plain, by the compare's basis:
--   "slot empty"       nothing is worn there
--   "mail over cloth"  a heavier armour kind than the worn piece's (the kinds in words; the item
--                      levels where either kind has no word)
--   "ilvl 12 -> 28"    the item level, the worn one first (Keep.LevelPair; plain "ilvl 12 to 28")
-- Brief K27, where the stats decided (basis "stats", or "empty" with a spec list):
--   "Holy, Protection"   the specs it upgrades (Keep.SpecWords), where not every spec of the class
--   nil                  basis "stats" and every spec: no brackets at all (an empty slot for every
--                        spec still says "slot empty")
-- Pure apart from Keep.LevelPair's art read.
function Keep.UpgradeDetail(gear)
  if gear.basis == "stats" or (gear.basis == "empty" and type(gear.specs) == "table") then
    local words = Keep.SpecWords(gear)
    if words then
      return words, words
    end
    if gear.basis == "stats" then
      return nil, nil
    end
  end
  if gear.basis == "empty" then
    local words = L["slot empty"]
    return words, words
  end
  if gear.basis == "kind" then
    local mine = Keep.SubclassWords(4, tonumber(gear.subclass))
    local theirs = Keep.SubclassWords(4, tonumber(gear.wornSubclass))
    if mine and theirs then
      local words = string.format(L["%s over %s"], mine, theirs)
      return words, words
    end
  end
  local over = math.floor(tonumber(gear.worn) + 0.5)
  local drawn, plain = Keep.LevelPair(over, gear.il)
  return string.format(L["ilvl %s"], drawn), string.format(L["ilvl %s"], plain)
end

--------------------------------------------------------------------------------
-- Brief K20b: the sale (design K20 sections 1 and 2). Pure.
--------------------------------------------------------------------------------

-- The auction house's cut: an auction price counts at 95% of itself (the deposit is not
-- modelled; the Bar's margin leaves room for it).
Keep.AUCTION_CUT = 0.95
-- Brief K24b (A6): the hidden 5 silver floor K20 put under every multiplier stop is gone. The
-- money test (Keep.Tags, rule 7) is what keeps a 2 copper auction from being offered now.

-- Bonding values (the shipped item row's b) that never go to the auction house: 1 bind on pickup
-- and 4 quest item. Brief K24b: a bag slot's REAL bound state (a worn bind on equip item is
-- soulbound) is read by the client side where the slot is known (Keep.SlotBound) and handed to
-- Keep.Tags in env.bound; everywhere else the row decides.
Keep.UNTRADABLE = { [1] = true, [4] = true }
-- Bonding values whose item may be bound or not in the bags (2 bind on equip, 3 bind on use): the
-- only rows a bag slot's bound state is asked for.
Keep.MAY_BIND = { [2] = true, [3] = true }

-- The Bar: the price the auction house has to clear to be worth listing, as the stops of the
-- "List on the auction house when it beats the vendor by" dropdown, in its order. Each stop is
-- { key, flat = copper over the vendor price } or { key, times = a multiple of the vendor price },
-- or Never (Sell (AH) is never chosen) or Formula (the player's own, Core/PriceFormula.lua).
Keep.BAR_STOPS = {
  { key = "never" },
  { key = "10s", flat = 1000 },
  { key = "1g", flat = 10000 },
  { key = "1.25x", times = 1.25 },
  { key = "1.5x", times = 1.5 },
  { key = "2x", times = 2 },
  { key = "3x", times = 3 },
  { key = "formula" },
}
Keep.BAR_DEFAULT = "1.5x"

-- The stop for a key, or the default stop for anything else. Pure.
function Keep.BarStop(key)
  local fallback
  for _, stop in ipairs(Keep.BAR_STOPS) do
    if stop.key == key then
      return stop
    end
    if stop.key == Keep.BAR_DEFAULT then
      fallback = stop
    end
  end
  return fallback
end

-- Whether an item can go to the auction house: no bonding its row names as bound (Keep.UNTRADABLE).
-- Pure.
function Keep.Tradable(score)
  if type(score) ~= "table" then
    return false
  end
  return not Keep.UNTRADABLE[tonumber(score.bonding) or 0]
end

-- The auction price after the auction house's cut, in whole copper, or nil where there is no
-- auction price or the item never goes to the auction house. Pure.
function Keep.AuctionNet(score)
  if type(score) ~= "table" or not Keep.Tradable(score) then
    return nil
  end
  local auction = tonumber(score.auction)
  if auction == nil or auction <= 0 then
    return nil
  end
  return math.floor(auction * Keep.AUCTION_CUT)
end

-- The Bar in copper for a vendor price and a stop: what the net auction price must reach. nil for
-- Never (nothing clears it). A multiplier stop is vendor times the stop; a flat stop is vendor plus
-- the stop. formulaBar is the formula's answer in copper (Keep.FormulaBar), used for the Formula
-- stop; where it is nil the default stop stands in. A missing vendor price counts as 0. Brief
-- K24b: no hidden floor any more. Pure.
function Keep.BarCopper(vendor, stop, formulaBar)
  vendor = tonumber(vendor) or 0
  if vendor < 0 then
    vendor = 0
  end
  if type(stop) ~= "table" then
    stop = Keep.BarStop(Keep.BAR_DEFAULT)
  end
  if stop.key == "never" then
    return nil
  end
  if stop.key == "formula" then
    formulaBar = tonumber(formulaBar)
    if formulaBar == nil then
      stop = Keep.BarStop(Keep.BAR_DEFAULT)
    else
      return math.floor(formulaBar + 0.5)
    end
  end
  if stop.flat then
    return vendor + stop.flat
  end
  return math.floor(vendor * stop.times + 0.5)
end

-- The Bar's setting, as a stop: brief K20c's dropdown, "List on the auction house when it beats
-- the vendor by" (settings.keepSellBar, Keep.BAR_DEFAULT where unset or unknown). settings are
-- the saved ones unless given. Answers the stop and the settings read.
function Keep.BarSetting(settings)
  if type(settings) ~= "table" then
    local db = ItemTree.db
    settings = type(db) == "table" and type(db.settings) == "table" and db.settings or EMPTY
  end
  return Keep.BarStop(settings.keepSellBar), settings
end

-- Brief K20c: the formula's Bar in copper for a score (Core/PriceFormula.lua BarFor), or nil where
-- the Formula stop is not chosen, the formula is not understood, or it comes out empty or
-- negative (the default stop stands in then).
function Keep.FormulaBar(score, settings)
  local formula = ItemTree.PriceFormula
  if type(formula) ~= "table" or type(formula.BarFor) ~= "function" or type(score) ~= "table" then
    return nil
  end
  local ok, copper = pcall(formula.BarFor, settings, score)
  if ok then
    return tonumber(copper)
  end
  return nil
end

-- What the sale states weigh for one score: the vendor price, the net auction price, the Bar and
-- whether the net auction price clears it. settings are the saved ones unless given. Pure.
function Keep.SaleFacts(score, settings)
  local stop
  stop, settings = Keep.BarSetting(settings)
  local vendor = tonumber(score.vendor) or 0
  local net = Keep.AuctionNet(score)
  local formulaBar = nil
  if stop.key == "formula" then
    formulaBar = Keep.FormulaBar(score, settings)
  end
  local bar = Keep.BarCopper(vendor, stop, formulaBar)
  local facts = {
    vendor = vendor,
    auctionNet = net,
    bar = bar,
    stop = stop.key,
    clears = net ~= nil and bar ~= nil and net >= bar,
  }
  -- Brief K20-wire (design K20 section 1 step 5): the disenchant sum after the auction house's cut,
  -- counted only where the player can disenchant the item (score.disenchant is there only then)
  -- and only where it clears the Bar worked out against the larger of the vendor price and the net
  -- auction price. Under the Formula stop the formula's answer (worked against the vendor price)
  -- stands, with the floor over that larger price.
  local disenchantNet = Keep.DisenchantNet(score)
  if disenchantNet ~= nil then
    local base = vendor
    if net ~= nil and net > base then
      base = net
    end
    local disenchantBar = Keep.BarCopper(base, stop, formulaBar)
    facts.disenchantNet = disenchantNet
    facts.disenchantBar = disenchantBar
    facts.disenchantClears = disenchantBar ~= nil and disenchantNet >= disenchantBar
  end
  return facts
end

--------------------------------------------------------------------------------
-- Brief K20b: the verdict's state words (design K20 section 1), kept as the words the API's
-- keep.state and keep.sale answer (Keep.TagState maps the tags onto them). Brief K24b: the
-- ordered states that chose one of them (Keep.STATES, Keep.State, Keep.SaleState,
-- Keep.SaleBeside, Keep.Verdict) are gone; the tags decide (Keep.Tags).
--------------------------------------------------------------------------------

Keep.STATE_KEEP = "keep"
Keep.STATE_VENDOR = "vendor"
Keep.STATE_SELL = "sell"
-- Brief WL1: the state word for a Worthless tag (Keep.TagState), the API's keep.state.
Keep.STATE_WORTHLESS = "worthless"
-- Brief K20-wire: the two disenchant states.
Keep.STATE_KEEP_DISENCHANT = "keepDisenchant"
Keep.STATE_DISENCHANT = "disenchant"

-- Brief K20b, design question 6 (assumed): whether an auction outranks a Keep (disenchant): the
-- net auction price reaches the Keep value. Keep.DisenchantKeeps asks this before it says yes.
-- Pure.
function Keep.SellOutranksDisenchant(score, threshold)
  local net = Keep.AuctionNet(score)
  if net == nil then
    return false
  end
  return Keep.Valuable(net, threshold)
end

--------------------------------------------------------------------------------
-- Brief K24b (owner redesign, 2026-10-05): the verdict is a row of action TAGS, one per action,
-- always in the order [Keep] [Auction] [Vendor] (an enchanter's [Disenchant] where Auction would
-- stand). Everything K20 to K22 decided about WHAT is a keep stays (Keep.KeepRule with K22's own
-- use counts, Keep (disenchant), the player's Always); this decides how a sale is judged and what
-- is shown; the tooltip, the item page, the bags and the API read the tags.
--
-- The order of decision (Keep.Tags):
--   1. Off: nil. Never: no keep tag, the sale tags below, "(marked by you)" on a muted line.
--   2. Keep: the player's Always, today's rule (Keep.KeepRule), Keep (disenchant), or the
--      provisional "could use" of a consumable (Keep.CouldUse, a soft keep). byUse is true for
--      every keep but the soft one: a reason other than the item's price.
--   3. The auction house is never offered for a bound item (the bag slot's real bound state where
--      the caller knows it, the row's bonding elsewhere) or a quest item.
--   4. Beside these (brief K24b follow-up): an item vendors sell everywhere (K1, score.everywhere)
--      is never offered for auction and is never a soft keep.
--      Jettison's four rules by kind, word for word so the two addons agree, in front of every
--      price test: a grey (poor quality) never counts; a soulbound item never counts; a Common
--      (white) weapon or armour counts only if the facts list a use for it (uses.current above
--      0); food and drink count only if the facts list a use.
--   5. Legendary, above 4 and 6 to 8 (not above 3): a single item's auction price of
--      LEGENDARY_COPPER (500 gold) or more is the legendary Auction tag and no Vendor tag.
--   6. A known auction price must beat the vendor price by the Bar setting per item after the
--      auction house's cut (Keep.SaleFacts; the Never stop never offers the auction house).
--   7. The money test on a FULL STACK's net auction value against the money the player carries:
--      under max(MONEY_LOW of it, MONEY_MIN) no Auction tag; up to MONEY_HIGH of it Auction and
--      Vendor; over that Auction alone. Money not known counts as 0, so MONEY_MIN decides.
--   8. No auction price known, rules 3 and 4 passed: Auction and Vendor, noAuctionData = true,
--      whether or not an auction addon is installed.
--   9. Vendor: where there is no Auction (or Disenchant) tag and the item has a vendor sell price,
--      and beside Auction in 7 and 8. A keep with no auction tag is [Keep] alone, never Keep and
--      Vendor; a strong keep with no auction data is [Keep] alone too, a soft keep keeps the
--      unknown price pair.
--  10. Disenchant, only with Enchanting (score.disenchant is there only then): the disenchant net
--      clears K20-wire's Bar (against the larger of the vendor and net auction prices) and the
--      money test; it stands where Auction would, or beside it, the larger value first (K20-wire
--      picked the largest, a tie to the auction).
--  11. Brief WL1 (the owner's ruling "A" of 2026-10-11, QA item 108): Worthless, the rung below
--      Vendor. Where the sale verdict would be Vendor alone (no keep, no Use, Open or Equip, no
--      Auction or Disenchant tag) but the item has no vendor sell price, the auction house cannot
--      take it (Keep.CanAuction: bound, or a quest item, which rule 12 of 2026-09 already
--      silences), and the gear test turned it down (Keep.GearRejected), the tag is [Worthless] with
--      the muted line "No sell price". Brief AM3 (QA item 340): so is ammo the ammo rule turned down
--      (Keep.AmmoRejected) that the auction house cannot take or vendors sell everywhere (Sharp
--      Arrow at 40), its lines "No sell price" and "Sold by vendors everywhere". Nobody buys it and
--      nothing claims it. Keep logic stays above it: an empty slot still reads Equip, a quest still
--      keeps, a Use still reads Use.
--  12. Nothing to say (no keep, no vendor price, an auction house that could take it): nil.
--------------------------------------------------------------------------------

Keep.TAG_KEEP = "keep"
Keep.TAG_AUCTION = "auction"
Keep.TAG_VENDOR = "vendor"
Keep.TAG_DISENCHANT = "disenchant"
-- Brief WL1 (QA item 108, the owner's ruling "A"): the bottom rung of the sale ladder (Auction >
-- Vendor > Worthless), rule 11 above. Never a keep and never a sale; the bags draw nothing for it,
-- as for Vendor alone.
Keep.TAG_WORTHLESS = "worthless"
-- Brief K24h (tester QA 2026-10-07): the Equip tag stands where Keep would for an upgrade the
-- player can wear today (Keep.EquipNow): the Keep colour, the word "Equip". It IS a Keep tag to
-- everything that asks (Keep.HasTag answers true for "keep", so the bags, the API's keep.marked
-- and keep.state, and Jettison read it as one); only its look and word differ.
Keep.TAG_EQUIP = "equip"
-- Brief K26 (owner 2026-10-07, "pets need a specific type of meat, a single stack is sufficient"):
-- the Pet food tag stands where Keep would for the one stack of food a hunter's pet eats
-- (Keep.PetKeeps): the Keep colour, a paw, the words "Pet food". A Keep tag to everything that
-- asks, as the Equip tag is.
Keep.TAG_PET = "pet"

-- Rule 5: a single item's auction price at which the Auction tag turns legendary, FIXED (the
-- owner's hard rule), never the "Valuable at" setting.
Keep.LEGENDARY_COPPER = 5000000
-- Rule 7: the money test's two shares of the money carried and its minimum (1 silver), to be
-- tuned by the owner.
Keep.MONEY_LOW = 0.01
Keep.MONEY_HIGH = 0.03
Keep.MONEY_MIN = 100

Keep.QUALITY_POOR = 0
Keep.QUALITY_COMMON = 1
-- The consumable subclass food and drink are filed under.
Keep.FOOD_SUBCLASS = 5
-- The item class quest items are filed under, beside the bonding 4.
Keep.QUEST_CLASS = 12
Keep.QUEST_BONDING = 4
Keep.BOP_BONDING = 1

-- Whether a score is a quest item (owner ruling 12: "we say nothing for quest items" unless one
-- is kept). Pure.
-- Brief TV1 (QA item 347, the owner's ruling E1 on Wartorn Plate Scrap 22375: keep it when one of its
-- quests is for your class, otherwise Auction, "these would be expensive items when they become
-- available", not hardcoded): an item of the quest class that names no bonding at all trades like any
-- other good (the auction house takes it), so it is no quest item here and takes the ordinary sale
-- verdict when nothing keeps it. A quest bound item (bonding 4) and a quest class item that binds stay
-- quest items, silent unless kept.
function Keep.QuestItem(score)
  if type(score) ~= "table" then
    return false
  end
  if tonumber(score.bonding) == Keep.QUEST_BONDING then
    return true
  end
  return tonumber(score.itemClass) == Keep.QUEST_CLASS and (tonumber(score.bonding) or 0) ~= 0
end

-- Rule 3: whether the auction house can take the item at all: never a quest item, never a bound
-- one. env.bound is the bag slot's real bound state where the caller read it (true, false), nil
-- elsewhere, where the row's bonding decides (Keep.Tradable). Pure.
function Keep.CanAuction(score, env)
  if type(score) ~= "table" or Keep.QuestItem(score) then
    return false
  end
  local bound = nil
  if type(env) == "table" then
    bound = env.bound
  end
  if bound == true then
    return false
  end
  if bound == false then
    return true
  end
  return Keep.Tradable(score)
end

-- Rule 4, Jettison's four rules by kind, in front of every price test. Pure.
function Keep.KindCounts(score, env)
  if type(score) ~= "table" then
    return false
  end
  local quality = tonumber(score.quality)
  if quality == Keep.QUALITY_POOR then
    return false
  end
  local bound = nil
  if type(env) == "table" then
    bound = env.bound
  end
  if bound == true or (bound == nil and tonumber(score.bonding) == Keep.BOP_BONDING) then
    return false
  end
  local hasUse = (tonumber(score.current) or 0) > 0
  if quality == Keep.QUALITY_COMMON and Keep.EQUIPMENT_CLASSES[tonumber(score.itemClass) or -1] and not hasUse then
    return false
  end
  -- Brief K26: a food or drink with a buff is sold like any trade good (at the level cap it is
  -- what the owner wants kept or auctioned); plain food stays off the auction house.
  if Keep.IsFood(score) and not hasUse and score.foodEffect ~= Keep.FOOD_EFFECT then
    return false
  end
  return true
end

-- Whether a score is food or drink (a consumable of the Food and Drink subclass). Pure.
function Keep.IsFood(score)
  if type(score) ~= "table" then
    return false
  end
  return tonumber(score.itemClass) == Keep.CONSUMABLE_CLASS and tonumber(score.subclass) == Keep.FOOD_SUBCLASS
end

--------------------------------------------------------------------------------
-- Brief K26 (owner 2026-10-07, "the well fed or effect foods and drinks are more than standard
-- food"): what a food or drink does, from the names of its effect spells (the shipped SpellNames
-- module, through spellName(id); the pipeline ships the names and nothing of what a spell does).
-- FOOD_PLAIN where every effect is the client's plain "Food" or "Drink", or none is named;
-- FOOD_EFFECT where any effect spell is named anything else: Forever's "Nutritious Food" and
-- "Nutritious Drink" (the buff tier, 105 items of 1.60.1.70170), and the one-offs (Thistle Tea,
-- Savory Deviate Delight, Dragonbreath Chili, the alcohol tiers). nil for a row that is not food
-- or drink. A food with a buff is a soft keep at every level below the cap (Keep.CouldUse) and
-- may be auctioned (Keep.KindCounts). WHAT the buff does (a stat, rested experience) is not
-- shipped yet: the consumable facts pass (brief K25) is where that lands, and with it the per
-- class and per level read the owner asked for (a Strength buff for a warrior, not a mage; rested
-- experience worth nothing at the cap). Replace the window, not the callers, when it does. Pure.
--------------------------------------------------------------------------------

Keep.FOOD_PLAIN = "plain"
Keep.FOOD_EFFECT = "effect"
Keep.PLAIN_FOOD_SPELLS = { ["Food"] = true, ["Drink"] = true }

function Keep.FoodEffect(row, spellName)
  if type(row) ~= "table" or tonumber(row.c) ~= Keep.CONSUMABLE_CLASS or tonumber(row.sc) ~= Keep.FOOD_SUBCLASS then
    return nil
  end
  for _, effect in ipairs(type(row.fx) == "table" and row.fx or EMPTY) do
    local spellId = type(effect) == "table" and effect[2] or nil
    local name = nil
    if spellId ~= nil and type(spellName) == "function" then
      local ok, answer = pcall(spellName, spellId)
      name = ok and type(answer) == "string" and answer or nil
    end
    if name ~= nil and name ~= "" and not Keep.PLAIN_FOOD_SPELLS[name] then
      return Keep.FOOD_EFFECT
    end
  end
  return Keep.FOOD_PLAIN
end

--------------------------------------------------------------------------------
-- Brief K26 (owner 2026-10-07, "pets need a specific type of meat; a single stack is probably
-- sufficient"): a hunter keeps ONE stack of food the pet eats. stacks are the bag stacks of pet
-- food the pet out eats, as the client read them (Keep.PetFoodStacks: a reagent of the player's
-- trade and a food with a buff are left out, each judged on its own), each { id, count, level }.
-- itemId and count are the item and stack asked about; count is nil where the tooltip shows no
-- bag slot (loot, a vendor, a link). No pet food in the bags: keep it. Else the one stack to keep
-- is the biggest, a tie to the higher level food, then to the lower id (Keep.PetFoodStack), and
-- the item asked about is kept where it is that stack (or, with no slot known, that item). Pure.
--------------------------------------------------------------------------------

function Keep.PetFoodStack(stacks)
  local best = nil
  for _, stack in ipairs(type(stacks) == "table" and stacks or EMPTY) do
    local id = tonumber(type(stack) == "table" and stack.id or nil)
    if id then
      local count, level = tonumber(stack.count) or 0, tonumber(stack.level) or 0
      if
        best == nil
        or count > best.count
        or (count == best.count and (level > best.level or (level == best.level and id < best.id)))
      then
        best = { id = id, count = count, level = level }
      end
    end
  end
  return best
end

function Keep.PetFoodKeep(stacks, itemId, count)
  local id = tonumber(itemId)
  if not id then
    return false
  end
  local best = Keep.PetFoodStack(stacks)
  if best == nil then
    return true
  end
  if best.id ~= id then
    return false
  end
  count = tonumber(count)
  return count == nil or count == best.count
end

-- Whether a score is the pet food stack the hunter keeps: env.pet is the client's read for the
-- item shown (Keep.PetFor: eats, whether the pet out eats it; keep, Keep.PetFoodKeep's answer).
-- A food with a buff is never it (judged as a buff food). Keep.KeepReason asks after the rule
-- keep, so a reagent of the player's trade stays [Keep] by its use. Pure.
function Keep.PetKeeps(score, env)
  local pet = type(env) == "table" and env.pet or nil
  if type(pet) ~= "table" or pet.eats ~= true or pet.keep ~= true then
    return false
  end
  if type(score) ~= "table" or score.foodEffect == Keep.FOOD_EFFECT then
    return false
  end
  return true
end

-- Rule 7: the band a full stack's net value falls in against the money carried: "none" (under
-- max(MONEY_LOW of the money, MONEY_MIN)), "both" (up to MONEY_HIGH of it: Auction and Vendor) or
-- "auction" (over that). money nil or below 0 counts as 0. Pure.
function Keep.MoneyBand(value, money)
  value = tonumber(value) or 0
  money = tonumber(money) or 0
  if money < 0 then
    money = 0
  end
  local low = math.max(money * Keep.MONEY_LOW, Keep.MONEY_MIN)
  if value < low then
    return "none"
  end
  if value <= money * Keep.MONEY_HIGH then
    return "both"
  end
  return "auction"
end

-- The stack the money test weighs: the row's stack size, 1 where the item does not stack or it is
-- not known. Pure.
function Keep.StackSize(score)
  local stack = type(score) == "table" and tonumber(score.stack) or nil
  if stack == nil or stack < 1 then
    return 1
  end
  return math.floor(stack)
end

-- Brief ST4 (G1, the owner's ruling of 2026-10-10: "sold everywhere never vendors the best food or
-- drink a character holds"): whether the consumable verdict keeps the item, so "sold everywhere"
-- leaves its soft keep alone. Brief BQ29 (the owner's pick on QA item 85, option 1: a level 15 hunter
-- with 377 health and one Lesser Healing Potion read [Vendor] "Sold by vendors everywhere"): every
-- kind the consumable rules judge, potions, bandages, elixirs and scrolls as well as food and drink.
-- The verdict already runs the share first ("Too weak for your level") and then "Better potion in
-- your bags", so only the best one held is kept here; a relevant bandage beside a better one carried
-- (verdict.outranked, "Still useful, a better bandage in your bags") is not the best one, and
-- "sold everywhere" still applies to it. Pure.
Keep.BEST_SUPPLY_KINDS = { food = true, drink = true, potion = true, bandage = true, buff = true }

function Keep.BestSupply(score)
  local verdict = type(score) == "table" and score.consumable or nil
  if type(verdict) ~= "table" or verdict.keep ~= true or verdict.outranked then
    return false
  end
  return Keep.BEST_SUPPLY_KINDS[verdict.kind] == true
end

-- Brief ST4 (G1, the owner's ruling of 2026-10-10 and the guide review's refinement): a mage may
-- vendor a plain food or drink the best conjure rank they know makes as well. Each rank as
-- { spell, level, item }: the spell ids and their learn levels as the client's SpellLevels states
-- them (1.60.1.70009: BaseLevel), the conjured item by rank order (its required level and restore in
-- the shipped item rows and ItemEffects: Muffin rl 1 61 health ... Cinnamon Roll rl 55 3180; Conjured
-- Water rl 1 151 mana ... Crystal Water rl 55 4200).
Keep.MAGE_CLASS = 8
Keep.CONJURE_FOOD = {
  { 587, 6, 5349 },
  { 597, 12, 1113 },
  { 990, 22, 1114 },
  { 6129, 32, 1487 },
  { 10144, 42, 8075 },
  { 10145, 52, 8076 },
  { 28612, 60, 22895 },
}
Keep.CONJURE_WATER = {
  { 5504, 4, 5350 },
  { 5505, 10, 2288 },
  { 5506, 20, 2136 },
  { 6127, 30, 3772 },
  { 10138, 40, 8077 },
  { 10139, 50, 8078 },
  { 10140, 60, 8079 },
}

-- Brief ST4 (G1): the item the best known rank of one conjure makes, or nil. known(spellId) answers
-- whether the character knows a rank; nil reads the ranks off level (the persona harness and the demo
-- state: a rank is known from its learn level). Pure.
function Keep.ConjuredItem(ranks, level, known)
  local best = nil
  level = tonumber(level)
  for _, rank in ipairs(ranks or EMPTY) do
    local has
    if type(known) == "function" then
      local ok, answer = pcall(known, rank[1])
      has = ok and answer == true
    else
      has = level ~= nil and level >= rank[2]
    end
    if has then
      best = rank[3]
    end
  end
  return best
end

-- Brief ST4 (G1): what the character conjures, { food = itemId, drink = itemId } (each nil for none),
-- or nil for no mage. A pretend class or level (Core/Demo.lua) reads the ranks off the level; the
-- character's own off IsPlayerSpell over the rank spell ids (a plain read of the spell book under
-- pcall, never a protected call).
function Keep.Conjured(classId, level)
  if tonumber(classId) ~= Keep.MAGE_CLASS then
    return nil
  end
  local demo = ItemTree.Demo
  local pretend = type(demo) == "table"
    and type(demo.ClassId) == "function"
    and (demo.ClassId() ~= nil or (type(demo.Level) == "function" and demo.Level() ~= nil))
  local known = rawget(_G, "IsPlayerSpell")
  if pretend or type(known) ~= "function" then
    known = nil
  end
  return {
    food = Keep.ConjuredItem(Keep.CONJURE_FOOD, level, known),
    drink = Keep.ConjuredItem(Keep.CONJURE_WATER, level, known),
  }
end

-- Brief JG1 (item 302, a player's comment on Jettison of 2026-10-20: "Grimoire of Torment (Rank 2)"
-- read as a sale, "Use: none", while the Voidwalker knew Torment Rank 1 only): a warlock's demon
-- grimoire teaches one demon a rank of one of its abilities. No shipped row says so (the book's use
-- spell is a learn spell, which the item effects leave out), so every book is listed here, by demon
-- and ability, in rank order: { itemId, rank (0 for an ability with no rank), the pet spell it
-- teaches }. Read from the Forever client's own tables (build 1.60.1.70009): the book's use spell's
-- learn effect (SpellEffect, effect 36, its trigger spell), that spell's rank (Spell's subtext) and
-- its demon (SkillLineAbility: Pet - Imp 188, Pet - Voidwalker 204, Pet - Succubus 205, Pet -
-- Felhunter 189). These 59 are every item whose use teaches a pet a spell; no hunter pet ability has
-- a book. Rank 1 of Firebolt, Torment, Lash of Pain and Devour Magic comes with the demon, no book.
Keep.DEMON_BOOKS = {
  {
    demon = L["Imp"],
    name = L["Firebolt"],
    books = {
      { 16302, 2, 7799 },
      { 16316, 3, 7800 },
      { 16317, 4, 7801 },
      { 16318, 5, 7802 },
      { 16319, 6, 11762 },
      { 16320, 7, 11763 },
    },
  },
  {
    demon = L["Imp"],
    name = L["Blood Pact"],
    books = { { 16321, 1, 6307 }, { 16322, 2, 7804 }, { 16323, 3, 7805 }, { 16324, 4, 11766 }, { 16325, 5, 11767 } },
  },
  {
    demon = L["Imp"],
    name = L["Fire Shield"],
    books = { { 16326, 1, 2947 }, { 16327, 2, 8316 }, { 16328, 3, 8317 }, { 16329, 4, 11770 }, { 16330, 5, 11771 } },
  },
  { demon = L["Imp"], name = L["Phase Shift"], books = { { 16331, 0, 4511 } } },
  {
    demon = L["Voidwalker"],
    name = L["Torment"],
    books = { { 16346, 2, 7809 }, { 16347, 3, 7810 }, { 16348, 4, 7811 }, { 16349, 5, 11774 }, { 16350, 6, 11775 } },
  },
  {
    demon = L["Voidwalker"],
    name = L["Sacrifice"],
    books = {
      { 16351, 1, 7812 },
      { 16352, 2, 19438 },
      { 16353, 3, 19440 },
      { 16354, 4, 19441 },
      { 16355, 5, 19442 },
      { 16356, 6, 19443 },
    },
  },
  {
    demon = L["Voidwalker"],
    name = L["Consume Shadows"],
    books = {
      { 16357, 1, 17767 },
      { 16358, 2, 17850 },
      { 16359, 3, 17851 },
      { 16360, 4, 17852 },
      { 16361, 5, 17853 },
      { 16362, 6, 17854 },
    },
  },
  {
    demon = L["Voidwalker"],
    name = L["Suffering"],
    books = { { 16363, 1, 17735 }, { 16364, 2, 17750 }, { 16365, 3, 17751 }, { 16366, 4, 17752 } },
  },
  {
    demon = L["Succubus"],
    name = L["Lash of Pain"],
    books = { { 16368, 2, 7815 }, { 16371, 3, 7816 }, { 16372, 4, 11778 }, { 16373, 5, 11779 }, { 16374, 6, 11780 } },
  },
  {
    demon = L["Succubus"],
    name = L["Soothing Kiss"],
    books = { { 16375, 1, 6360 }, { 16376, 2, 7813 }, { 16377, 3, 11784 }, { 16378, 4, 11785 } },
  },
  { demon = L["Succubus"], name = L["Seduction"], books = { { 16379, 0, 6358 } } },
  { demon = L["Succubus"], name = L["Lesser Invisibility"], books = { { 16380, 0, 7870 } } },
  {
    demon = L["Felhunter"],
    name = L["Devour Magic"],
    books = { { 16381, 2, 19731 }, { 16382, 3, 19734 }, { 16383, 4, 19736 } },
  },
  {
    demon = L["Felhunter"],
    name = L["Tainted Blood"],
    books = { { 16384, 1, 19478 }, { 16385, 2, 19655 }, { 16386, 3, 19656 }, { 16387, 4, 19660 } },
  },
  { demon = L["Felhunter"], name = L["Spell Lock"], books = { { 16388, 1, 19244 }, { 16389, 2, 19647 } } },
  { demon = L["Felhunter"], name = L["Paranoia"], books = { { 16390, 0, 19480 } } },
}

-- Brief JG1: Keep.DEMON_BOOKS by item id, built on first use.
local demonBookIndex = nil

--- Brief JG1: one demon grimoire, { demon, name, rank, spell, ranks }: the demon's and the ability's
--- words, the rank it teaches (0 for none), the pet spell it teaches, and ranks, that spell and every
--- higher rank's (the books after it). nil for any other item. Pure.
function Keep.DemonBook(itemId)
  if demonBookIndex == nil then
    demonBookIndex = {}
    for _, ability in ipairs(Keep.DEMON_BOOKS) do
      for at, book in ipairs(ability.books) do
        local ranks = {}
        for higher = at, #ability.books do
          ranks[#ranks + 1] = ability.books[higher][3]
        end
        demonBookIndex[book[1]] = {
          demon = ability.demon,
          name = ability.name,
          rank = book[2],
          spell = book[3],
          ranks = ranks,
        }
      end
    end
  end
  return demonBookIndex[tonumber(itemId) or -1]
end

--- Brief JG1: whether the demon is known to have learnt a grimoire's rank: known(spellId) answers
--- true for the book's pet spell or a higher rank's (the client's read of the summoned pet's spells,
--- Keep.PetSpellKnown). Anything else, the demon not summoned, another demon out, no read or an error,
--- is not known, so false: only a rank the demon is confirmed to know (or a higher one) is learnt.
--- Pure.
function Keep.DemonBookLearnt(book, known)
  if type(book) ~= "table" or type(known) ~= "function" then
    return false
  end
  for _, spell in ipairs(book.ranks or EMPTY) do
    local ok, answer = pcall(known, spell)
    if ok and answer == true then
      return true
    end
  end
  return false
end

--- Brief JG1: a warlock's demon grimoire, { demon, name, rank, learnt }, or nil for anyone else's
--- (another class judges the book as before) and for any other item. known is Keep.DemonBookLearnt's.
--- Pure.
function Keep.PetBookFacts(itemId, playerClass, known)
  if tonumber(playerClass) ~= Keep.WARLOCK_CLASS then
    return nil
  end
  local book = Keep.DemonBook(itemId)
  if book == nil then
    return nil
  end
  return { demon = book.demon, name = book.name, rank = book.rank, learnt = Keep.DemonBookLearnt(book, known) }
end

--- Brief JG1: whether a score is a demon grimoire the warlock's demon is not known to have learnt,
--- the [Keep] (Keep.KEEP_PET_BOOK). Pure.
function Keep.PetBookKeeps(score)
  local book = type(score) == "table" and score.petBook or nil
  return type(book) == "table" and book.learnt ~= true
end

--- Brief JG1: whether a score is a demon grimoire the warlock's demon has learnt. Pure.
function Keep.PetBookLearnt(score)
  local book = type(score) == "table" and score.petBook or nil
  return type(book) == "table" and book.learnt == true
end

--- Brief JG1: what a grimoire teaches, the keep's one reason: "Teaches your Voidwalker Torment (Rank
--- 2)", "Teaches your Imp Phase Shift" for an ability with no rank. nil for no book. Pure.
function Keep.PetBookWords(book)
  if type(book) ~= "table" or book.demon == nil or book.name == nil then
    return nil
  end
  local ability = book.name
  local rank = tonumber(book.rank) or 0
  if rank > 0 then
    ability = string.format(L["%s (%s)"], book.name, string.format(L["Rank %d"], rank))
  end
  return string.format(L["Teaches your %s %s"], book.demon, ability)
end

--- Brief JG1: a learnt grimoire's muted line above its sale reasons, "Learnt by your Voidwalker". nil
--- for no book. Pure.
function Keep.PetBookLearntWords(book)
  if type(book) ~= "table" or book.demon == nil then
    return nil
  end
  return string.format(L["Learnt by your %s"], book.demon)
end

-- Brief CB1 (item 305, JG1's note of 2026-10-20: the player's own class books had the grimoires'
-- hole, Tome of Arcane Brilliance, the AQ tomes, Codex: Prayer of Fortitude and the rogue disguises
-- read [Vendor] or [Auction] whether learnt or not): a book that teaches the player a spell. Its
-- shipped row says so itself: item class 9 (Recipe) subclass 0 (Book), a learn effect (row.fx trigger
-- 6, the spell it teaches) and allowed classes that name some classes but not every one. Over the
-- shipped data (build 1.60.1.70450) that is 61 released books: the AQ and Naxxramas tomes, Tome of
-- Arcane Brilliance, the Prayer of Fortitude, Prayer of Shadow Protection and Gift of the Wild books,
-- the Polymorph tomes, Grimoire of Doom and of Inferno, Tome of Tranquilizing Shot, the six rogue
-- disguises, the nine Season of Discovery Spell Notes and Tome of Enchanted Flare (Jettison lists the
-- same, Core/ClassTables.lua CLASS_BOOKS; tests/spec/cb1_class_books_spec.lua holds the two
-- together). The developer books match too and are never in a bag. Not class books: profession books
-- and campsite blueprints (no class), the Season of Discovery runes (item class 0, a class use of
-- their own, brief TB10) and relics (class 4, judged as gear), and Forever's mage scrolls (277492 and
-- beside it), whose use casts its effect and teaches nothing.
Keep.BOOK_ITEM_CLASS = 9
Keep.BOOK_SUBCLASS = 0
-- An item row's effect trigger for "Use: teaches" (ItemSpellTriggerType 6, the learn effect).
Keep.LEARN_TRIGGER = 6
-- The rank numerals in a book's name ("Tome of Frostbolt XI"), in order.
Keep.BOOK_NUMERALS = {
  "I",
  "II",
  "III",
  "IV",
  "V",
  "VI",
  "VII",
  "VIII",
  "IX",
  "X",
  "XI",
  "XII",
  "XIII",
  "XIV",
  "XV",
  "XVI",
  "XVII",
  "XVIII",
  "XIX",
  "XX",
}

local numeralAt = nil

-- Brief CB1: a name's trailing rank numeral, "Tome of Frostbolt XI" to "Tome of Frostbolt", 11; a
-- name with none answers itself and nil. Pure.
local function splitNumeral(name)
  if numeralAt == nil then
    numeralAt = {}
    for at, numeral in ipairs(Keep.BOOK_NUMERALS) do
      numeralAt[numeral] = at
    end
  end
  local base, numeral = name:match("^(.-) ([IVX]+)$")
  if base and numeralAt[numeral] then
    return base, numeralAt[numeral]
  end
  return name, nil
end

--- Brief CB1: the spell a row's learn effect teaches, or nil. Pure.
function Keep.LearntSpell(row)
  for _, effect in ipairs(type(row) == "table" and type(row.fx) == "table" and row.fx or EMPTY) do
    local spell = type(effect) == "table" and tonumber(effect[1]) == Keep.LEARN_TRIGGER and tonumber(effect[2]) or nil
    if spell then
      return spell
    end
  end
  return nil
end

--- Brief CB1: what a class book teaches, in the words its own row gives, and the rank: its flavour
--- text "Teaches Arcane Brilliance (Rank 1)." (the rank in brackets) or "Teaches Tranquilizing
--- Shot."; else the item's name less its book word ("Tome of Polymorph: Pig" to Polymorph: Pig,
--- "Knowledge: Defias Disguise", "Spell Notes: Ice Lance"), a rank numeral after it read as the rank;
--- else the spell's name (spellName, the shipped SpellNames on busted). The rank is 0 for none.
--- Pure over its arguments.
function Keep.ClassBookLabel(row, spell, spellName)
  local flavour = type(row) == "table" and type(row.fl) == "string" and row.fl or ""
  local name, rank = flavour:match("^Teaches (.-) %(Rank (%d+)%)%.?$")
  if name and name ~= "" then
    return name, tonumber(rank)
  end
  name = flavour:match("^Teaches (.-)%.?$")
  if name and name ~= "" and not name:find("^you ") then
    return name, 0
  end
  local item = type(row) == "table" and type(row.n) == "string" and row.n or ""
  name = item:match("^%a+ of (.+)$") or item:match("^[^:]+: (.+)$")
  if name and name ~= "" then
    local base, at = splitNumeral(name)
    return base, at or 0
  end
  if type(spellName) == "function" then
    local ok, words = pcall(spellName, spell)
    if ok and type(words) == "string" and words ~= "" then
      return words, 0
    end
  end
  return nil, 0
end

--- Brief CB1: a class book's own facts, { spell, name, rank, classMask }, from its row alone (above),
--- or nil for any other row. spellName is Keep.ClassBookLabel's. Pure over its arguments.
function Keep.ClassBook(row, spellName)
  if type(row) ~= "table" or tonumber(row.c) ~= Keep.BOOK_ITEM_CLASS or tonumber(row.sc) ~= Keep.BOOK_SUBCLASS then
    return nil
  end
  local mask = whole(row.ac)
  if #Keep.MaskClasses(mask) == 0 then
    return nil
  end
  local spell = Keep.LearntSpell(row)
  if spell == nil then
    return nil
  end
  local name, rank = Keep.ClassBookLabel(row, spell, spellName)
  if name == nil then
    return nil
  end
  return { spell = spell, name = name, rank = rank, classMask = mask }
end

-- Brief CB1: the books' names (item class 9 in the shipped Names module) to their item ids, the
-- lowest id for a name held twice, read in one pass and kept: the names never change. Brief RP-AH2
-- (FR-AH M3): that pass walks every row of the Names module (29,220 over the shipped 1.60.1.70450 data,
-- 2,780 class 9 names kept; about 1.5 ms offline on the Mac, more on a slower machine), which the first
-- bag paint or hover that scored a class book paid in its frame. It is built behind the loading
-- screen now (Keep.WarmClassBookIndex, in Core/Data.lua Data.PRELOAD_LOADING_SCREEN), and the first
-- book scored builds it only where that did not run. Keep.bookIndexBuilds counts the passes.
local bookIds, bookNames = nil, 0
Keep.bookIndexBuilds = 0

local function bookIndex()
  if bookIds == nil then
    local d = data()
    local ok, names = false, nil
    if d and type(d.Get) == "function" then
      ok, names = pcall(d.Get, d, "Names")
    end
    if not ok or type(names) ~= "table" or type(names.ids) ~= "table" then
      return nil
    end
    local list, classes = names.names or EMPTY, names.c or EMPTY
    local index, count = {}, 0
    for pos, id in ipairs(names.ids) do
      local words = list[pos]
      if tonumber(classes[pos]) == Keep.BOOK_ITEM_CLASS and type(words) == "string" then
        local held = index[words]
        if held == nil then
          count = count + 1
        end
        if held == nil or id < held then
          index[words] = id
        end
      end
    end
    bookIds, bookNames = index, count
    Keep.bookIndexBuilds = Keep.bookIndexBuilds + 1
  end
  return bookIds
end

local function bookIdNamed(name)
  local index = bookIndex()
  return index and index[name] or nil
end

--- Brief RP-AH2 (FR-AH M3): builds the class books' name index now, behind the loading screen
--- (Data:PreloadLoadingScreen) and as the slicer's fallback (Data.PRELOAD_WARM). Answers how many
--- names it holds, 0 where the Names module is not there (the first book scored builds it then).
function Keep.WarmClassBookIndex()
  if bookIndex() == nil then
    return 0
  end
  return bookNames
end

--- Brief CB1: the spells that make a class book learnt: its own, then each higher rank's that a book
--- of the next numeral teaches ("Codex: Prayer of Fortitude" then "Codex: Prayer of Fortitude II",
--- the same words and class, a higher rank), so a player who knows a higher rank has learnt the
--- lower book. A lookup by name per rank, never a walk of the rows. Pure over the data tables.
function Keep.ClassBookRanks(row, book, spellName)
  if type(book) ~= "table" then
    return {}
  end
  local ranks = { book.spell }
  local name = type(row) == "table" and type(row.n) == "string" and row.n or nil
  if name == nil then
    return ranks
  end
  local base, at = splitNumeral(name)
  for step = (at or 1) + 1, #Keep.BOOK_NUMERALS do
    local id = bookIdNamed(base .. " " .. Keep.BOOK_NUMERALS[step])
    local higher = id and Keep.ClassBook(itemRow(id), spellName) or nil
    if higher == nil then
      break
    end
    if higher.name == book.name and higher.classMask == book.classMask and higher.rank > book.rank then
      ranks[#ranks + 1] = higher.spell
    end
  end
  return ranks
end

--- Brief CB1: a class book of the player's own class, { name, rank, spell, ranks, learnt }, or nil
--- for another class's book (judged as before), a class not known and any other item. learnt is true
--- only where known(spellId) (the client's read of the player's spell book, Keep.PlayerSpellKnown)
--- answers true for the book's spell or a higher rank's (Keep.DemonBookLearnt's rule); the level the
--- book asks for plays no part: a book above the player's level is kept for later. Pure over the data
--- tables.
function Keep.ClassBookFacts(row, playerClass, known, spellName)
  local book = Keep.ClassBook(row, spellName)
  if book == nil or not Keep.MaskHasClass(book.classMask, playerClass) then
    return nil
  end
  local ranks = Keep.ClassBookRanks(row, book, spellName)
  return {
    name = book.name,
    rank = book.rank,
    spell = book.spell,
    ranks = ranks,
    learnt = Keep.DemonBookLearnt({ ranks = ranks }, known),
  }
end

--- Brief CB1: whether a score is a class book the player is not known to have learnt, the [Keep]
--- (Keep.KEEP_CLASS_BOOK). Pure.
function Keep.ClassBookKeeps(score)
  local book = type(score) == "table" and score.classBook or nil
  return type(book) == "table" and book.learnt ~= true
end

--- Brief CB1: whether a score is a class book the player has learnt. Pure.
function Keep.ClassBookLearnt(score)
  local book = type(score) == "table" and score.classBook or nil
  return type(book) == "table" and book.learnt == true
end

--- Brief CB1: what a class book teaches, the keep's one reason: "Teaches you Arcane Brilliance (Rank
--- 1)", "Teaches you Tranquilizing Shot" for a spell with no rank. nil for no book. Pure.
function Keep.ClassBookWords(book)
  if type(book) ~= "table" or type(book.name) ~= "string" then
    return nil
  end
  local spell = book.name
  local rank = tonumber(book.rank) or 0
  if rank > 0 then
    spell = string.format(L["%s (%s)"], book.name, string.format(L["Rank %d"], rank))
  end
  return string.format(L["Teaches you %s"], spell)
end

--------------------------------------------------------------------------------
-- Brief TV1 (QA item 347b, the owner's ruling D1 of 2026-10-21: "D1. We can optionally have auction
-- tag there if its worth lots of money on teh AH and we ahve the data"): a recipe item (item class 9,
-- a profession named by its row's sk, a learn effect, row.fx trigger 6) of one of the character's own
-- professions that the character has not learnt is kept, whatever their skill: [Keep]
-- (Keep.KEEP_RECIPE, a strong keep, so the Auction tag stands beside it only where a known price
-- clears the Bar and the money test, K21). Its first line names its state: "Learn it (Alchemy 225)",
-- "Needs Alchemy 225 (you have 180)", and under a sale "Already known" or "Not your profession
-- (Engineering)". Learnt is the client's read of the spell book (IsPlayerSpell answers a recipe's
-- learnt status, proven in game: ItemTree_Professions/Core/Craft.lua Craft.KnowsRecipe), not known
-- reading as not learnt, so a recipe is never sold on a guess. The recipe it teaches is no reagent
-- use (use.teaches: Keep.TradeUse, Keep.OwnUse).
--------------------------------------------------------------------------------

Keep.KEEP_RECIPE = "recipe"

--- Brief TV1 (D1): a recipe item's facts { skill, rank, spell, own, have, learnt }, or nil for any
--- other row: skill the profession its row names (sk), rank the rank it asks for (skr, 0 for none),
--- spell the recipe it teaches (Keep.LearntSpell); own true or false where professions (a set of
--- skill lines) is known, nil where it is not; for an own recipe, have the character's rank in that
--- profession (rankOf, nil for not known) and learnt, true where known(spell) answers true. Pure over
--- its arguments.
function Keep.RecipeFacts(row, professions, rankOf, known)
  if type(row) ~= "table" or tonumber(row.c) ~= Keep.BOOK_ITEM_CLASS then
    return nil
  end
  local skill = whole(row.sk)
  local spell = Keep.LearntSpell(row)
  if skill == nil or skill <= 0 or spell == nil then
    return nil
  end
  local facts = { skill = skill, rank = whole(row.skr) or 0, spell = spell }
  if type(professions) == "table" then
    facts.own = Keep.IsOwnSkill(skill, professions) == true
  end
  -- The rank and the spell book are read only for a recipe of the character's own profession, the one
  -- whose verdict they decide.
  if facts.own then
    local consumables = ItemTree.Consumables
    if type(consumables) == "table" and type(consumables.RankIn) == "function" then
      facts.have = tonumber(consumables.RankIn(rankOf, skill))
    elseif type(rankOf) == "function" then
      local ok, rank = pcall(rankOf, skill)
      facts.have = ok and tonumber(rank) or nil
    end
    if type(known) == "function" then
      local ok, answer = pcall(known, spell)
      facts.learnt = ok and answer == true or nil
    end
  end
  return facts
end

--- Brief TV1 (D1): whether a score is a recipe item of the character's own professions not known to
--- be learnt, the [Keep] (Keep.KEEP_RECIPE). Pure.
function Keep.RecipeKeeps(score)
  local recipe = type(score) == "table" and score.recipe or nil
  return type(recipe) == "table" and recipe.own == true and recipe.learnt ~= true
end

--- Brief TV1 (D1): a recipe item's state line and whether it is muted: "Learn it now" and "Learn it
--- (Requires Alchemy 225)" for a keep (the reasons' colour; brief UL1's words), "Already known" and "Not your
--- profession (Engineering)" under a sale (muted); nil, nil for no recipe facts, a profession the
--- tables do not name, or professions not known. Pure over the data tables.
function Keep.RecipeWords(score)
  local recipe = type(score) == "table" and score.recipe or nil
  if type(recipe) ~= "table" then
    return nil, nil
  end
  local name = skillName(recipe.skill)
  if recipe.own == true and recipe.learnt == true then
    return L["Already known"], true
  end
  if name == nil then
    return nil, nil
  end
  if recipe.own == false then
    return string.format(L["Not your profession (%s)"], name), true
  end
  if recipe.own ~= true then
    return nil, nil
  end
  -- Brief UL1 (QA item 356, the owner on Formula: Runed Arcanite Rod): "Learn it now" where the
  -- character meets the recipe's skill (or it asks none), else "Learn it (Requires Enchanting 290)",
  -- the rank not known to be met read as not met (was TV1's "Needs Enchanting 290 (you have 200)" and
  -- "Learn it (Enchanting 290)").
  local need, have = tonumber(recipe.rank) or 0, tonumber(recipe.have)
  if need <= 0 or (have ~= nil and have >= need) then
    return L["Learn it now"], false
  end
  return string.format(L["Learn it (Requires %s %d)"], name, need), false
end

--- Brief TV1 (QA item 347, the owner on Sinister Squashling: "Yea this seems like a Use/Auction / Yes
--- this needs a reason"): a companion pet item's facts { spell }, the companion its learn effect
--- teaches (Keep.LearntSpell), or nil for any other row: item class 15 (Miscellaneous) subclass 2
--- (Companion Pets) with a learn effect. Pure.
Keep.MISC_ITEM_CLASS = 15
Keep.COMPANION_SUBCLASS = 2

function Keep.CompanionFacts(row)
  if type(row) ~= "table" or tonumber(row.c) ~= Keep.MISC_ITEM_CLASS or tonumber(row.sc) ~= Keep.COMPANION_SUBCLASS then
    return nil
  end
  local spell = Keep.LearntSpell(row)
  if spell == nil then
    return nil
  end
  return { spell = spell }
end

--------------------------------------------------------------------------------
-- Brief AM1 (QA item 330, the owner on 2026-10-21: "Why on my hunter am I now told to vendor my
-- arrows that are good for my level?"; Jagged Arrow at demo level 40 read [Vendor] "Sold by vendors
-- everywhere"): ammo the character's ranged weapon fires is kept, [Keep] "Ammo for your bow" (a
-- crossbow's "Ammo for your crossbow", a gun's "Ammo for your gun"), as Jettison locks it ("Locked:
-- ammo for your bow": its Core/Floors.lua lock "ammo", Core/Features.lua ammoForWorn, Core/Reasons.lua
-- RANGED_WORDS). It wins over "sold everywhere" (Keep.KeepReason asks it before the rule). Its tags are
-- the ordinary keep path's (the review, the owner's K21 ruling: "a keep state never hides a worthwhile
-- sale"): [Keep] first, [Auction] beside it where the auction price clears the Bar and the money test
-- (Thorium Shells), [Keep] alone for a cheap item sold everywhere (Jagged Arrow), with no auction price
-- known, or for a plain vendor sale. The rule is Jettison's:
--   weapon  arrows (Projectile subclass 2) for a bow or crossbow (weapon subclass 2, 18), bullets
--           (subclass 3) for a gun (3), the same table as Jettison's ClassTables.AMMO_FOR. Item 330c
--           (the owner): the WORN ranged weapon only; bullets with a bow worn are not kept, nor is
--           anything with no ranged weapon worn. Keep.AmmoWeapons is the one place that says which
--           weapons count (Jettison: Client/Player.lua Player.RangedSubclass)
--   level   a required level no more than Keep.AMMO_FRESH_LEVELS (15) below the character's and,
--           item 330c, no more than Keep.AMMO_AHEAD_LEVELS (10) above it; brief AM3 (item 340, the
--           owner: "10 levels is probably too many for a sold everywhere item...probably want within
--           3 levels"), ammo vendors sell everywhere (K1 and SE1, the score's everywhere) no more than
--           Keep.AMMO_AHEAD_SOLD_EVERYWHERE (3) above it; an item with no required level counts at any
--           level, and so does any item while the level is not known (Jettison:
--           Features.CONSTANTS.FRESH_LEVELS, AMMO_AHEAD_LEVELS and AMMO_AHEAD_SOLD_EVERYWHERE)
-- Anything else (ammo too low or too high, for a weapon not worn, every class without one) reads as
-- before. The score holds the facts (score.ammo, Keep.AmmoFacts); the worn map is in the score
-- cache's key, so a weapon put on or taken off scores the ammo again. Brief AM3 (item 340, Sharp Arrow
-- at demo level 40 read no tag at all): ammo the rule turns down (Keep.AmmoRejected: no worn weapon
-- fires it, or it is out of reach) with no sell price that nobody buys reads [Worthless], Keep.Worthless.
--------------------------------------------------------------------------------

-- The item class of arrows and bullets, and their two subclasses.
Keep.PROJECTILE_CLASS = 6
Keep.ARROW_SUBCLASS = 2
Keep.BULLET_SUBCLASS = 3
-- The ranged weapon subclasses whose ammo the words name.
Keep.BOW_SUBCLASS = 2
Keep.GUN_SUBCLASS = 3
Keep.CROSSBOW_SUBCLASS = 18
-- Jettison's Features.CONSTANTS.FRESH_LEVELS: levels below the character ammo's required level may be
-- and still count.
Keep.AMMO_FRESH_LEVELS = 15
-- Item 330c, Jettison's Features.CONSTANTS.AMMO_AHEAD_LEVELS (brief AM2): levels above the character
-- ammo's required level may be and still count (Thorium Shells, required 52, at 50).
Keep.AMMO_AHEAD_LEVELS = 10
-- Brief AM3 (item 340), Jettison's Features.CONSTANTS.AMMO_AHEAD_SOLD_EVERYWHERE: the same for ammo
-- vendors sell everywhere, which the character can buy at any town when the level comes (Jagged Arrow,
-- required 40, at 37 but not at 36).
Keep.AMMO_AHEAD_SOLD_EVERYWHERE = 3
-- Brief AM1: the keep reason (Keep.KeepReason) for ammo the worn weapon fires (score.ammo).
Keep.KEEP_AMMO = "ammo"

--- Brief AM1: the ranged weapon subclasses whose ammo the character keeps, a list: the weapon worn in
--- the ranged slot (worn, Gear.Worn's map: its row's c and sc), where it is a weapon. Item 330c (the
--- owner, 2026-10-21): the worn weapon only. A later ruling that counts a weapon carried in the bags
--- adds it here and nowhere else. Pure.
function Keep.AmmoWeapons(worn)
  local weapons = {}
  local ranged = type(worn) == "table" and worn[Keep.RANGED_SLOT] or nil
  if type(ranged) == "table" and tonumber(ranged.c) == Keep.WEAPON_CLASS and whole(ranged.sc) then
    weapons[#weapons + 1] = whole(ranged.sc)
  end
  return weapons
end

--- Brief AM1: whether a ranged weapon of that subclass fires ammo of that Projectile subclass: arrows
--- from a bow or crossbow, bullets from a gun (Jettison's ClassTables.AmmoFits). Pure.
function Keep.AmmoFits(projectileSubclass, rangedSubclass)
  local sub = tonumber(projectileSubclass)
  local fires = nil
  if sub == Keep.ARROW_SUBCLASS then
    fires = Keep.FIRES_ARROWS
  elseif sub == Keep.BULLET_SUBCLASS then
    fires = Keep.FIRES_BULLETS
  end
  return type(fires) == "table" and fires[tonumber(rangedSubclass) or -1] == true
end

--- Brief AM1: whether ammo of that required level counts at the character's level: no required level
--- (nil or 0), no level known, or a required level from AMMO_FRESH_LEVELS below to AMMO_AHEAD_LEVELS
--- above it, both ends included (Jettison's ammoForWorn). Brief AM3 (item 340): everywhere true (ammo
--- vendors sell everywhere) counts only AMMO_AHEAD_SOLD_EVERYWHERE above it. Pure.
function Keep.AmmoInReach(required, level, everywhere)
  required = tonumber(required) or 0
  level = tonumber(level)
  if level == nil or required <= 0 then
    return true
  end
  local ahead = Keep.AMMO_AHEAD_LEVELS
  if everywhere == true then
    ahead = Keep.AMMO_AHEAD_SOLD_EVERYWHERE
  end
  return required >= level - Keep.AMMO_FRESH_LEVELS and required <= level + ahead
end

--- Brief AM1: the ammo facts of an item row, { weapon = the subclass of the weapon that fires it,
--- required = its required level or nil }, where it is ammo one of the weapons (Keep.AmmoWeapons'
--- list) fires and its level is in reach (Keep.AmmoInReach, brief AM3: everywhere true for ammo
--- vendors sell everywhere); nil for anything else. Pure.
function Keep.AmmoFacts(row, weapons, level, everywhere)
  if type(row) ~= "table" or tonumber(row.c) ~= Keep.PROJECTILE_CLASS then
    return nil
  end
  if not Keep.AmmoInReach(row.rl, level, everywhere) then
    return nil
  end
  for _, weapon in ipairs(type(weapons) == "table" and weapons or EMPTY) do
    if Keep.AmmoFits(row.sc, weapon) then
      return { weapon = weapon, required = whole(row.rl) }
    end
  end
  return nil
end

--- Brief AM3 (item 340, the owner: "With demo level 40 itemtree does not say to vendor/no worthless tag
--- for sharp arrow"): whether the ammo rule judged an arrow or bullet and turned it down, the ammo's like
--- of the gear test's turn down (Keep.GearRejected): no weapon in the list fires it (another weapon's
--- ammo, or no ranged weapon worn), or its level is out of reach (Keep.AmmoInReach with everywhere: Sharp
--- Arrow, required 10, at 40; Razor Arrow, required 25 and sold everywhere, at 15). It is exactly the
--- ammo Jettison's ammo lock leaves out (ammoForWorn false), which Jettison ranks as junk where nothing
--- buys it, so the two addons agree. False for anything that is not ammo. Pure.
function Keep.AmmoRejected(row, weapons, level, everywhere)
  if type(row) ~= "table" or tonumber(row.c) ~= Keep.PROJECTILE_CLASS then
    return false
  end
  return Keep.AmmoFacts(row, weapons, level, everywhere) == nil
end

--- Brief AM1: whether a score is ammo the worn weapon fires, in reach, the [Keep] (Keep.KEEP_AMMO).
--- Pure.
function Keep.AmmoKeeps(score)
  return type(score) == "table" and type(score.ammo) == "table"
end

--- Brief AM1: the ammo keep's one reason, "Ammo for your bow", "Ammo for your crossbow" or "Ammo for
--- your gun" (Jettison's "ammo for your bow"); nil for no ammo facts. Pure.
function Keep.AmmoWords(ammo)
  local weapon = type(ammo) == "table" and tonumber(ammo.weapon) or nil
  if weapon == Keep.BOW_SUBCLASS then
    return L["Ammo for your bow"]
  elseif weapon == Keep.CROSSBOW_SUBCLASS then
    return L["Ammo for your crossbow"]
  elseif weapon == Keep.GUN_SUBCLASS then
    return L["Ammo for your gun"]
  end
  return nil
end

-- Rule 2: whether a score is a keep and why: "always" (the player's word), "rule" (Keep.KeepRule),
-- Keep.KEEP_PET (brief K26: the one pet food stack a hunter keeps, over env.pet, Keep.PetKeeps),
-- "disenchant" (Keep (disenchant)), "could" (the provisional soft keep, Keep.CouldUse), or nil.
-- Brief AA-RB: Keep.KEEP_TOY for a toy (score.toy). Brief JG1: Keep.KEEP_PET_BOOK for a demon
-- grimoire the warlock's demon is not known to have learnt (score.petBook). Brief CB1:
-- Keep.KEEP_CLASS_BOOK for a book of the player's class not known to be learnt (score.classBook).
-- Brief AM1: Keep.KEEP_AMMO for ammo the worn weapon fires, in reach (score.ammo), ahead of the rule,
-- so sold everywhere never sells it. Never and Off are never a keep. Pure.
function Keep.KeepReason(score, settings, env)
  if type(score) ~= "table" or score.override == "off" or score.override == "never" then
    return nil
  end
  if score.override == "always" then
    return "always"
  end
  -- Brief AA-RB (QA item 216): a toy is kept, whatever else it is (Jettison's toy lock).
  if score.toy == true then
    return Keep.KEEP_TOY
  end
  -- Brief TV1 (QA item 347, the owner on the Hearthstone: "Should probably have a keep - its a
  -- important item for leveling"): the essentials are kept, whatever else they are.
  if Keep.HOME_ITEMS[tonumber(score.itemId) or 0] then
    return Keep.KEEP_HOME
  end
  -- Brief JG1 (item 302): a demon grimoire is never sold while the demon is not known to have learnt
  -- it (Jettison's pet book lock).
  if Keep.PetBookKeeps(score) then
    return Keep.KEEP_PET_BOOK
  end
  -- Brief CB1 (item 305): a book of the player's class is never sold while the player is not known
  -- to have learnt it (Jettison's class book lock).
  if Keep.ClassBookKeeps(score) then
    return Keep.KEEP_CLASS_BOOK
  end
  -- Brief TV1 (QA item 347b, ruling D1): a recipe of the character's own profession not known to be
  -- learnt, whatever their skill.
  if Keep.RecipeKeeps(score) then
    return Keep.KEEP_RECIPE
  end
  -- Brief K31: the best tool the player carries for one of their professions (Keep.ToolKeeps); a
  -- spare copy is judged as if it were no tool of theirs (Keep.ToolFree's view).
  if Keep.ToolKeeps(score, env) then
    return Keep.KEEP_TOOL
  end
  if Keep.ToolSpare(score, env) then
    return Keep.KeepReason(Keep.ToolFree(score), settings, env)
  end
  -- Brief AM1 (QA item 330): ammo the worn ranged weapon fires, in reach, is kept whatever else it is,
  -- sold everywhere included (Jettison's ammo lock, ahead of its ItemTree keep lock).
  if Keep.AmmoKeeps(score) then
    return Keep.KEEP_AMMO
  end
  if Keep.KeepRule(score) then
    return "rule"
  end
  -- Brief BQ18: the working stock, one stack of a reagent off the route (Keep.StockFacts).
  if Keep.StockCap(score) then
    return Keep.KEEP_STOCK
  end
  if Keep.PetKeeps(score, env) then
    return Keep.KEEP_PET
  end
  if Keep.DisenchantKeeps(score, settings) then
    return "disenchant"
  end
  -- Brief K24b follow-up: an item vendors sell everywhere (K1) is never a soft keep. Brief ST4 (G1,
  -- the owner's ruling of 2026-10-10): but the best food or drink a character holds is (Keep.BestSupply;
  -- brief BQ29, QA item 85: the best consumable of any kind the consumable rules judge).
  if score.couldUse == true and (not score.everywhere or Keep.BestSupply(score)) then
    return "could"
  end
  return nil
end

-- Brief K24d (owner QA 2026-10-06, Linen Cloth and Light Leather read [Keep] [Auction] while the
-- route lines read "Level First Aid (78 / 100 needed)": "probably should be just keep right
-- now"): whether the profession route still needs MORE of the item than the player holds, the two
-- numbers the route line prints. have is the player's count (bags and bank, Keep.ProfessionHave);
-- nil, where the caller did not read it (the bags, the API), counts as none held. False where the
-- route names no count. Pure.
function Keep.RouteStillNeeds(score, have)
  local info = type(score) == "table" and score.profession or nil
  local need = type(info) == "table" and tonumber(info.need) or nil
  if need == nil or need <= 0 then
    return false
  end
  return (tonumber(have) or 0) < need
end

-- Brief K24d: whether a keep has a reason beyond the player's professions, so the sale tags stand
-- beside it whatever the route needs: the player's Always, an upgrade to wear, a carried crate's
-- combine, a class spell's reagent or the player's class consumable, or an open quest. The
-- player's own recipe uses and chains are the route's own business and do not count. Pure.
function Keep.KeepBeyondRoute(score)
  if type(score) ~= "table" then
    return false
  end
  if score.override == "always" or Keep.GearUpgrade(score) or score.carried == true then
    return true
  end
  local kinds = score.kinds or EMPTY
  if (tonumber(kinds.spell) or 0) > 0 or (tonumber(kinds.class) or 0) > 0 then
    return true
  end
  return (tonumber(score.current) or 0) > 0 and (tonumber(kinds.quest) or 0) > 0
end

-- Brief K24d, the one named test Keep.Tags asks: a keep the profession route still needs more of
-- than the player holds, with no reason beyond the route, is [Keep] alone. Pure.
function Keep.RouteKeepsAll(score, have)
  return Keep.RouteStillNeeds(score, have) and not Keep.KeepBeyondRoute(score)
end

-- Brief K30: the route's count where the item's keep rests on it alone, or nil: the count was worked
-- out above 0, the rule keeps the item (Keep.KeepRule), and with the trade reasons left out
-- (Keep.TradeFree) nothing keeps it (Keep.KeepReason: not the rule, the pet food stack, Keep
-- (disenchant) or the soft keep). Never for the player's own Always, Never or Off. settings and env
-- are Keep.KeepReason's. Pure.
-- Brief BQ25a (the owner's ruling for scenario i9, the same as his Jettison item 33 ruling: a count
-- based answer decides, the blanket pet food keep joins as a second line and never replaces the
-- count): env with the hunter's pet left out, for the "would anything else keep it" tests of the
-- route and quest counts below. A fresh table where env names a pet, else env. Pure.
function Keep.WithoutPet(env)
  if type(env) ~= "table" or env.pet == nil then
    return env
  end
  local copy = {}
  for key, value in pairs(env) do
    copy[key] = value
  end
  copy.pet = nil
  return copy
end

function Keep.ReagentKeepNeed(score, settings, env)
  if type(score) ~= "table" or score.override ~= nil then
    return nil
  end
  local need = tonumber(score.reagentNeed)
  if need == nil or need <= 0 or score.tradeFree == true or not Keep.KeepRule(score) then
    return nil
  end
  if Keep.KeepReason(Keep.TradeFree(score), settings, Keep.WithoutPet(env)) ~= nil then
    return nil
  end
  return need
end

-- Brief INT1b (the owner's ruling of 2026-10-10, Q(c)): where the profession route (brief K30's
-- count) and the open quests (brief Q1's) both keep the same item and nothing else does, the keep
-- holds their SUM (brief BQ16: two need lines share the count, Keep.ReasonLines). Answers the sum,
-- the route's part and the quests' part, or nil: the route's count was worked out above 0, the rule
-- keeps the item (Keep.KeepRule), with the trade reasons left out the keep rests on the open quests
-- alone and they state their counts (Keep.QuestKeepUpTo over Keep.TradeFree's view), and with the
-- quests left out too nothing keeps it (Keep.KeepReason over Keep.QuestFree's view). Never for the
-- player's own Always, Never or Off. settings and env are Keep.KeepReason's. Pure.
function Keep.CombinedKeepNeed(score, settings, env)
  if type(score) ~= "table" or score.override ~= nil or score.tradeFree == true then
    return nil
  end
  local route = tonumber(score.reagentNeed)
  if route == nil or route <= 0 or not Keep.KeepRule(score) then
    return nil
  end
  local tradeFree = Keep.TradeFree(score)
  local quest = Keep.QuestKeepUpTo(tradeFree)
  if quest == nil or quest <= 0 then
    return nil
  end
  -- Brief BQ25a: a pet food keep never takes the counts' place (Keep.WithoutPet).
  if Keep.KeepReason(Keep.QuestFree(tradeFree), settings, Keep.WithoutPet(env)) ~= nil then
    return nil
  end
  route = math.floor(route)
  return route + quest, route, quest
end

-- Brief BQ16: the open quests' part of a combined keep (Keep.CombinedKeepNeed), whatever the count
-- held, else nil: the need lines share the player's count between the quests and the route. Pure.
function Keep.CombinedQuestPart(score, settings, env)
  local total, _, quest = Keep.CombinedKeepNeed(score, settings, env)
  if total == nil then
    return nil
  end
  return quest
end

-- Brief INT1b: the count the keep holds where it rests on the route alone (Keep.ReagentKeepNeed) or
-- on the route and the open quests together (Keep.CombinedKeepNeed, their sum), else nil. The API's
-- keep.need. Pure.
function Keep.KeepNeed(score, settings, env)
  local need = Keep.ReagentKeepNeed(score, settings, env)
  if need ~= nil then
    return need
  end
  return (Keep.CombinedKeepNeed(score, settings, env))
end

-- Brief K30: whether the player holds more than the route's count of an item whose keep rests on it
-- alone (Keep.ReagentKeepNeed): the count where so, else nil. have is env.have, the tooltip's read
-- (bags and bank); nil, where the caller did not read it (the bags, the API), is never more. Pure.
function Keep.ReagentSurplus(score, have, settings, env)
  have = tonumber(have)
  if have == nil then
    return nil
  end
  local need = Keep.ReagentKeepNeed(score, settings, env)
  if need == nil or have <= need then
    return nil
  end
  return need
end

-- The tags for a score, or nil for Off or nothing to say:
--   { tags = { "keep", "auction", "vendor" } in display order, noAuctionData, legendary, byUse,
--     keepBy = Keep.KeepReason's answer, Keep.KEEP_WORN, or nil, surplus = brief K30's route
--     count where the player holds more of an item kept for it alone (Keep.ReagentSurplus), or
--     brief INT1b's sum of the route's and the open quests' counts where they keep it together
--     (Keep.CombinedKeepNeed), else nil, questPart = the quests' part of that sum, else nil }
-- env (all optional): money (copper carried), bound (the bag slot's real bound state), have (the
-- player's count of the item, for the route rule, Keep.RouteKeepsAll), worn (brief K24d: true
-- where the tooltip shows an item instance the player is wearing, or the client's comparison
-- tooltip). Brief K24e (owner QA 2026-10-06, Tracker's Pants: "if it's my current best it should
-- be keep"): a worn item is [Keep] alone, keepBy Keep.KEEP_WORN, never a sale tag and never the
-- legendary one, whatever the player's word on it (Off still says nothing). settings are the
-- saved ones unless given. Pure.
Keep.KEEP_WORN = "worn"
-- Brief F160 (owner QA 2026-10-14, item 160: Old Blanchy's Feed Pouch hovered in the bag bar read
-- [Equip] "Bigger than your 6 slot bag"): a bag hovered in one of the character's own bag slots (the
-- four bags and the reagent bag slot) or a bank bag slot is worn too, env.wornBag naming which
-- (UI/Tooltip.lua Tooltip.EquippedBag): [Keep] "Equipped bag" or "Equipped bank bag".
Keep.WORN_BAG = "bag"
Keep.WORN_BANK_BAG = "bank"
-- Brief K26: the pet food stack a hunter keeps (Keep.KeepReason, over env.pet).
Keep.KEEP_PET = "pet"
-- Brief AA-RB (the owner's QA item 216): a toy (score.toy, Keep.IsToy), kept as Jettison locks it.
Keep.KEEP_TOY = "toy"
-- Brief JG1 (item 302): a demon grimoire the warlock's demon is not known to have learnt
-- (score.petBook, Keep.PetBookKeeps), kept as Jettison locks it.
Keep.KEEP_PET_BOOK = "petbook"
-- Brief CB1 (item 305): a book of the player's class the player is not known to have learnt
-- (score.classBook, Keep.ClassBookKeeps), kept as Jettison locks it.
Keep.KEEP_CLASS_BOOK = "classbook"
-- Brief TV1 (QA item 347, the owner: the Hearthstone "Should probably have a keep - its a important
-- item for leveling"): the essentials, by item id as Jettison's own list names them
-- (Jettison/Data/Essentials.lua, which leaves them out of its ranking): [Keep] "Takes you back to
-- your inn".
Keep.KEEP_HOME = "home"
Keep.HOME_ITEMS = {
  [6948] = true, -- Hearthstone
}

--------------------------------------------------------------------------------
-- Brief JO1 (tester QA 2026-10-09: "wanted Tom to sell an unopened clam instead of opening it
-- first"), built in brief BQ7: an item the character can open now (a clam, a loot bag, a lockbox
-- they can pick) is opened before it is sold or dropped. The item row's op (1 openable) says it
-- holds loot, and its lt ({lockType, skill} pairs) the lock: a lockpicking lock (lock type 1) is
-- opened only by a rogue with that Lockpicking rank. A box the character cannot open keeps its
-- verdict and says why, muted ("Locked: needs a key or a rogue").
--
-- Brief BQ9 (the owner's design of 2026-10-10, "the blue means do this now"): an item the character
-- should use now is no Keep any more but a verdict of its own beside Keep, Vendor and Auction, drawn
-- in the one Use blue (Theme ITEMTREE_COLOR_USE, the same hue as Jettison's Use rows):
--   [Open]  an openable the character can open now (Keep.OpensFirst), "Open it: Clam Meat,
--           sometimes Small Lustrous Pearl" from the Classic Era table's container rows
--           (Keep.OpenWords), "Open it" alone where nothing is known. Every one, no aura test.
--   [Use]   a buff consumable (a potion, elixir or scroll whose effect is a buff on the user, never
--           food, drink, healing or mana) the character can use now (its required level met and
--           the consumable facts keep it for the class), whose buff is NOT on the player
--           (Keep.BuffOn over env.auras, read out of combat; in combat or unread it counts as not
--           on, so it stays Use). While the buff is on, the rest of the stack takes its ordinary
--           verdict ("use one and dump the others"). "Use it now to get a buff" (QA item 95).
--   [Use]   an item that starts a quest the character can accept now (score.startsNow: Q1's rules,
--           the side, not done, no event quest, its minimum level reached): "Use it: starts a
--           quest". A starter the character cannot take keeps its ordinary verdict.
-- The player's Always, Never and Off win over all three. None of them is a Keep tag (Keep.HasTag),
-- so the bags' Keep look, the API's keep.marked and keep.byUse and Jettison's locks leave them be;
-- the API names the action (keep.action).
--------------------------------------------------------------------------------

Keep.KEEP_OPEN = "open"
Keep.ROGUE_CLASS = 4
Keep.LOCKPICK_LOCK_TYPE = 1
-- The rogue's Pick Lock, and the Lockpicking rank a rogue reaches per level (Classic's cap is five
-- per level), the rank read where the client lists no Lockpicking skill line.
Keep.PICK_LOCK_SPELL = 1804
Keep.LOCKPICK_PER_LEVEL = 5

-- An item row's open facts: { lockSkill = the Lockpicking rank its lock needs, or nil for no
-- lock }, or nil for an item that holds no loot. Pure.
function Keep.OpenFacts(row)
  if type(row) ~= "table" or tonumber(row.op) ~= 1 then
    return nil
  end
  local skill = nil
  for _, entry in ipairs(type(row.lt) == "table" and row.lt or EMPTY) do
    if type(entry) == "table" and tonumber(entry[1]) == Keep.LOCKPICK_LOCK_TYPE then
      skill = math.max(tonumber(entry[2]) or 0, skill or 0)
    end
  end
  return { lockSkill = skill }
end

-- Whether the character can open it now: no lock, or a rogue whose Lockpicking rank (rank, nil for
-- not known) reaches the lock's. Pure.
function Keep.CanOpen(open, classId, rank)
  if type(open) ~= "table" then
    return false
  end
  local need = tonumber(open.lockSkill)
  if need == nil then
    return true
  end
  if tonumber(classId) ~= Keep.ROGUE_CLASS then
    return false
  end
  rank = tonumber(rank)
  return rank ~= nil and rank >= need
end

-- The score's open state: { lockSkill, canOpen, rogue }, or nil for an item that holds no loot.
-- Pure.
function Keep.OpenState(row, classId, rank)
  local open = Keep.OpenFacts(row)
  if not open then
    return nil
  end
  open.canOpen = Keep.CanOpen(open, classId, rank)
  open.rogue = tonumber(classId) == Keep.ROGUE_CLASS
  return open
end

-- Whether the score is opened first: the character can open it, and the player's word is not
-- Never or Off. Pure.
function Keep.OpensFirst(score)
  if type(score) ~= "table" or score.override == "never" or score.override == "off" then
    return false
  end
  return type(score.open) == "table" and score.open.canOpen == true
end

-- The muted words for a box the character cannot open, or nil: "Locked: needs Lockpicking 25" for
-- a rogue below the lock's rank, "Locked: needs a key or a rogue" for anyone else. Pure.
function Keep.LockedWords(score)
  local open = type(score) == "table" and score.open or nil
  if type(open) ~= "table" or open.canOpen or tonumber(open.lockSkill) == nil then
    return nil
  end
  if open.rogue then
    return string.format(L["Locked: needs Lockpicking %d"], tonumber(open.lockSkill))
  end
  return L["Locked: needs a key or a rogue"]
end

-- The score's open state (Keep.OpenState) for the item row: the rank lockpick where the caller read
-- it, else, for a rogue and a locked box only, Keep.LockpickRank(level). nil for no loot. Pure but
-- for that one read.
function Keep.ScoreOpen(row, classId, level, lockpick)
  local open = Keep.OpenFacts(row)
  if not open then
    return nil
  end
  local rank = tonumber(lockpick)
  if rank == nil and open.lockSkill ~= nil and tonumber(classId) == Keep.ROGUE_CLASS then
    rank = Keep.LockpickRank(level)
  end
  return Keep.OpenState(row, classId, rank)
end

-- Brief BQ9: the "do this now" kinds, their tags (the Use blue, Keep.TagRow) and their keepBy.
Keep.ACTION_OPEN = "open"
Keep.ACTION_USE = "use"
Keep.ACTION_QUEST = "quest"
-- Brief GW1 (QA item 101 (a)): a cosmetic whose appearance the account has not collected: [Use],
-- "Use it to collect the appearance".
Keep.ACTION_COLLECT = "collect"
Keep.TAG_OPEN = "open"
Keep.TAG_USE = "use"
Keep.KEEP_USE = "use"
Keep.KEEP_QUEST = "quest"
-- The consumable subclasses a buff is used from now: 2 elixir, 4 scroll (a flask, 3, is kept for a
-- hard fight; food and drink, 5, and bandages, 7, are never a Use). Brief ST4 (bin C, the owner's
-- ruling of 2026-10-10): a potion, 1, is not either: its buff is short and drunk in a fight (a level 30
-- mage's spell damage potion), so it keeps its ordinary verdict. The use now kind is for scrolls, the
-- long buffs the character lacks, openables and quest starters.
Keep.USE_SUBCLASSES = { [2] = true, [4] = true }
-- An item row's effect trigger for "Use:" (row.fx entries are { trigger, spellId }).
Keep.USE_TRIGGER = 0

-- Brief BQ9: the buff facts of a consumable the character can use now, { spells = { spellId },
-- names = { spellName } }, or nil: an elixir or scroll (USE_SUBCLASSES) whose consumable
-- verdict (Consumables.Judge) is a kept buff, so no restore and an effect the class wants, and whose
-- required level the player has reached. spellName (optional) names an effect spell. Pure.
function Keep.UseBuffFacts(row, consumable, level, spellName)
  if type(row) ~= "table" or tonumber(row.c) ~= Keep.CONSUMABLE_CLASS then
    return nil
  end
  local required, player = tonumber(row.rl) or 0, tonumber(level)
  if required > 0 and (player == nil or required > player) then
    return nil
  end
  -- Brief BQ29 (the owner's ruling on QA item 86): a buff food (Keep.FedFood) is a use now while the
  -- player is not well fed: { food = true }, its buff the Well Fed aura (Keep.FedState).
  if tonumber(row.sc) == Keep.FOOD_SUBCLASS then
    if Keep.FedFood(consumable) then
      return { food = true, spells = {}, names = {} }
    end
    return nil
  end
  if not Keep.USE_SUBCLASSES[tonumber(row.sc) or -1] then
    return nil
  end
  if type(consumable) ~= "table" or consumable.kind ~= "buff" or consumable.keep ~= true then
    return nil
  end
  local facts = { spells = {}, names = {} }
  for _, effect in ipairs(type(row.fx) == "table" and row.fx or EMPTY) do
    local trigger = type(effect) == "table" and tonumber(effect[1]) or nil
    local spellId = type(effect) == "table" and tonumber(effect[2]) or nil
    if spellId and (trigger == nil or trigger == Keep.USE_TRIGGER) then
      facts.spells[#facts.spells + 1] = spellId
      if type(spellName) == "function" then
        local ok, name = pcall(spellName, spellId)
        if ok and type(name) == "string" and name ~= "" then
          facts.names[#facts.names + 1] = name
        end
      end
    end
  end
  return facts
end

-- Brief BQ9: whether the buff of a use now consumable is on the player: auras is the player's
-- helpful auras read out of combat (Keep.PlayerAuras: spell id and name to true), nil for not
-- known (in combat, or the client would not say), which counts as not on. Pure.
function Keep.BuffOn(facts, auras)
  if type(facts) ~= "table" or type(auras) ~= "table" then
    return false
  end
  for _, spellId in ipairs(facts.spells or EMPTY) do
    if auras[spellId] then
      return true
    end
  end
  for _, name in ipairs(facts.names or EMPTY) do
    if auras[name] then
      return true
    end
  end
  return false
end

-- Brief BQ29 (the owner's ruling on QA item 86, "ItemTree is not showing herb egg as Use, still as
-- keep, while I don't have the well fed buff; Jet is correct"): a buff food is a food or drink the
-- consumable verdict keeps for its Well Fed buff or its kill experience while levelling (verdict
-- buffFood or xpFood), the same test as Jettison's lastingFood (brief BQ26). Plain food and drink
-- (a restore and nothing else) never are. Pure.
function Keep.FedFood(verdict)
  if type(verdict) ~= "table" or verdict.keep ~= true then
    return false
  end
  if verdict.kind ~= "food" and verdict.kind ~= "drink" then
    return false
  end
  return verdict.buffFood == true or verdict.xpFood == true
end

-- Brief BQ29: the Well Fed aura's name as the client names it (Jettison's Player.WELL_FED).
Keep.WELL_FED = L["Well Fed"]

-- Brief BQ29: whether the player is well fed, as Jettison's BQ26 reads it: true or false, or nil
-- where it cannot be told (in combat, no aura read), which prompts nothing. The demo state's
-- `demo wellfed on|off` (Demo.WellFed) answers first, then env.wellFed where a caller states it
-- ("unknown" for cannot tell), then the Well Fed aura among env.auras. Pure but for the demo read.
function Keep.FedState(env)
  local demo = ItemTree.Demo
  if type(demo) == "table" and type(demo.WellFed) == "function" then
    local ok, pretend = pcall(demo.WellFed)
    if ok and pretend == "unknown" then
      return nil
    elseif ok and (pretend == true or pretend == false) then
      return pretend
    end
  end
  if type(env) ~= "table" then
    return nil
  end
  if env.wellFed == true or env.wellFed == false then
    return env.wellFed
  end
  if env.wellFed == "unknown" or type(env.auras) ~= "table" then
    return nil
  end
  return env.auras[Keep.WELL_FED] == true
end

-- Brief BQ9: what the character should do with the item now, "open", "quest" or "use", or nil:
-- never under the player's Always, Never or Off. env.auras decides a buff (Keep.BuffOn). Brief BQ29:
-- a buff food (score.useBuff.food) is a use only while the player is known not to be well fed
-- (Keep.FedState false). Pure.
function Keep.DoNow(score, env)
  if type(score) ~= "table" or score.override ~= nil then
    return nil
  end
  -- Brief GW1 (QA item 101 (a)): a cosmetic not collected yet (or not known to be) is used to
  -- collect its appearance.
  if Keep.CollectNow(score) then
    return Keep.ACTION_COLLECT
  end
  if Keep.OpensFirst(score) then
    return Keep.ACTION_OPEN
  end
  if score.startsNow ~= nil then
    return Keep.ACTION_QUEST
  end
  -- Brief BQ32 (the owner's ruling of 2026-10-13 on QA item 79 (b): "They are use if they are
  -- relevant to your level but they aren't USE NOW (the blue highlighted version)"): a bandage is
  -- never a use now, whatever its row; its keep reads the plain [Use] (Keep.UseTagged).
  if Keep.IsBandage(score) then
    return nil
  end
  if type(score.useBuff) == "table" and score.useBuff.food == true then
    if Keep.FedState(env) == false then
      return Keep.ACTION_USE
    end
    return nil
  end
  if type(score.useBuff) == "table" then
    local auras = type(env) == "table" and env.auras or nil
    if not Keep.BuffOn(score.useBuff, auras) then
      return Keep.ACTION_USE
    end
  end
  return nil
end

-- Brief BQ9: the tags answer for a "do this now" kind. Pure.
function Keep.ActionTags(kind)
  local tag, keepBy = Keep.TAG_USE, Keep.KEEP_USE
  if kind == Keep.ACTION_OPEN then
    tag, keepBy = Keep.TAG_OPEN, Keep.KEEP_OPEN
  elseif kind == Keep.ACTION_QUEST then
    keepBy = Keep.KEEP_QUEST
  end
  return { tags = { tag }, noAuctionData = false, legendary = false, byUse = false, keepBy = keepBy, action = kind }
end

-- Brief BQ9: the reason words of a "do this now" kind, as the tooltip draws them. Pure but for the
-- contents read of an [Open] line (Keep.OpenWords). Brief BQ30 addendum (QA item 95): a buff food
-- (the score's useBuff.food, or the tags answer's food, answer) eats rather than uses.
function Keep.ActionWords(kind, score, answer)
  if kind == Keep.ACTION_OPEN then
    return Keep.OpenWords(score)
  elseif kind == Keep.ACTION_QUEST then
    return L["Use it: starts a quest"]
  elseif kind == Keep.ACTION_COLLECT then
    -- Brief TV1 (QA item 347): a piece collected by wearing it (no collect marker, never binds).
    local cosmetic = type(score) == "table" and score.cosmetic or nil
    if type(cosmetic) == "table" and cosmetic.wear == true then
      return L["Wear it to collect the appearance"]
    end
    return L["Use it to collect the appearance"]
  elseif kind == Keep.ACTION_USE then
    -- Brief BQ30 addendum (the owner's word choice, QA item 95): a buff food (Keep.FedFood, the
    -- score's useBuff.food) reads "Eat it now to get a buff"; an elixir or scroll "Use it now to get
    -- a buff".
    local buff = type(score) == "table" and score.useBuff or nil
    if (type(buff) == "table" and buff.food == true) or (type(answer) == "table" and answer.food == true) then
      return L["Eat it now to get a buff"]
    end
    return L["Use it now to get a buff"]
  end
  return nil
end

-- Brief BQ9: the Classic Era table's container rows turned round, container item id to its contents
-- { { itemId, chance }, ... } best chance first, built once per table on the first ask (about 60 ms
-- over the whole table on the test machine, no client call) and kept. EraSources.More decodes a
-- packed container list; a row that names its container itself is read as it is. Pure over the
-- shipped table.
Keep.contentsFor, Keep.contentsOf = nil, nil

function Keep.ContentsIndex(source)
  local era = ItemTree.EraSources
  local dataLayer = ItemTree.Data
  if type(source) ~= "table" or type(source.r) ~= "table" or type(era) ~= "table" then
    return {}
  end
  local index = {}
  local function add(containerId, itemId, chance)
    containerId = tonumber(containerId)
    if containerId == nil then
      return
    end
    local list = index[containerId]
    if list == nil then
      list = {}
      index[containerId] = list
    end
    list[#list + 1] = { itemId = itemId, chance = tonumber(chance) or 0 }
  end
  local scan = {}
  for itemId, packed in pairs(source.r) do
    if type(itemId) == "number" then
      local rows = nil
      if type(packed) == "string" and type(dataLayer) == "table" and type(dataLayer.ScanRows) == "function" then
        local ok, iter, state, first = pcall(dataLayer.ScanRows, source, source.r, itemId, scan)
        if ok and type(iter) == "function" then
          rows = { iter = iter, state = state, first = first }
        end
      elseif type(packed) == "table" then
        local list = packed
        if packed.c ~= nil then
          list = { packed }
        end
        rows = { iter = ipairs(list), state = list, first = 0 }
      end
      local more = false
      if rows then
        for _, raw in rows.iter, rows.state, rows.first do
          if type(raw) == "table" and tonumber(raw.c) == Keep.CONTAINER_CATEGORY then
            if raw.i ~= nil then
              add(raw.i, itemId, raw.p)
            end
            if raw.x ~= nil or raw.t ~= nil then
              more = true
            end
          end
        end
      end
      if more and type(era.More) == "function" then
        local ok, list = pcall(era.More, source, itemId, Keep.CONTAINER_CATEGORY)
        for _, row in ipairs(ok and type(list) == "table" and list or EMPTY) do
          if type(row) == "table" and row.container ~= nil then
            add(row.container, itemId, row.chance)
          end
        end
      end
    end
  end
  for _, list in pairs(index) do
    table.sort(list, function(a, b)
      if a.chance ~= b.chance then
        return a.chance > b.chance
      end
      return a.itemId < b.itemId
    end)
  end
  return index
end
-- The Classic Era table's category for a container row (EraSources.CATEGORIES 13).
Keep.CONTAINER_CATEGORY = 13

-- The contents of one container item, or an empty list. Builds the index on the first ask.
function Keep.Contents(containerId)
  local dataLayer = ItemTree.Data
  local era = ItemTree.EraSources
  if type(dataLayer) ~= "table" or type(dataLayer.Get) ~= "function" or type(era) ~= "table" then
    return EMPTY
  end
  local ok, source = pcall(dataLayer.Get, dataLayer, era.MODULE)
  if not ok or type(source) ~= "table" then
    return EMPTY
  end
  if Keep.contentsFor ~= source then
    Keep.contentsOf = Keep.ContentsIndex(source)
    Keep.contentsFor = source
  end
  return Keep.contentsOf[tonumber(containerId)] or EMPTY
end

-- Brief BQ9: a content is common at this chance (percent) or more, and named "sometimes" below
-- it; at most OPEN_NAMES common names, and the rare ones named only where there are OPEN_NAMES or
-- fewer of them (a lockbox's long list of 1 percent gear reads "sometimes other loot").
Keep.OPEN_COMMON = 50
Keep.OPEN_NAMES = 2

-- Two names as "A or B", one as itself. Pure.
local function eitherOf(names)
  if #names >= 2 then
    return string.format(L["%s or %s"], names[1], names[2])
  end
  return names[1]
end

-- Brief BQ9: the [Open] line from a container's contents ({ itemId, chance }, best chance first)
-- and nameOf(itemId), the item's name: "Open it: Clam Meat, sometimes Small Lustrous Pearl",
-- "Open it: sometimes Pattern: X or Plans: Y", "Open it: Tangy Clam Meat, sometimes other loot", and
-- "Open it" where nothing is known or only a long list of rare loot is (a lockbox). No rates in
-- the words. Pure.
function Keep.OpenWordsFrom(contents, nameOf)
  local common, rare = {}, {}
  local rareCount = 0
  for _, entry in ipairs(type(contents) == "table" and contents or EMPTY) do
    local name = nil
    if type(nameOf) == "function" then
      local ok, answer = pcall(nameOf, entry.itemId)
      name = ok and type(answer) == "string" and answer ~= "" and answer or nil
    end
    if name then
      if (tonumber(entry.chance) or 0) >= Keep.OPEN_COMMON then
        if #common < Keep.OPEN_NAMES then
          common[#common + 1] = name
        end
      else
        rareCount = rareCount + 1
        if #rare < Keep.OPEN_NAMES then
          rare[#rare + 1] = name
        end
      end
    end
  end
  -- Nothing known, or only a long list of rare loot (a lockbox's gear), names nothing.
  if #common == 0 and (rareCount == 0 or rareCount > Keep.OPEN_NAMES) then
    return L["Open it"]
  end
  local sometimes = nil
  if rareCount > Keep.OPEN_NAMES then
    sometimes = L["other loot"]
  elseif rareCount > 0 then
    sometimes = eitherOf(rare)
  end
  local text
  if #common == 0 then
    text = string.format(L["sometimes %s"], sometimes)
  elseif sometimes then
    text = string.format(L["%s, sometimes %s"], table.concat(common, ", "), sometimes)
  else
    text = table.concat(common, ", ")
  end
  return string.format(L["Open it: %s"], text)
end

-- Brief BQ9: the [Open] line for a scored item (score.itemId), its contents from the Classic Era
-- table and each content's name from the item rows (Data:GetItem, local data, never a client ask).
function Keep.OpenWords(score)
  local id = type(score) == "table" and tonumber(score.itemId) or nil
  if id == nil then
    return L["Open it"]
  end
  local dataLayer = ItemTree.Data
  return Keep.OpenWordsFrom(Keep.Contents(id), function(itemId)
    if type(dataLayer) ~= "table" or type(dataLayer.GetItem) ~= "function" then
      return nil
    end
    local ok, row = pcall(dataLayer.GetItem, dataLayer, itemId)
    return ok and type(row) == "table" and row.n or nil
  end)
end

function Keep.RawTags(score, settings, env)
  if type(score) ~= "table" or score.override == "off" then
    return nil
  end
  env = type(env) == "table" and env or EMPTY
  if env.worn == true then
    -- Brief BQ18 (the owner's ruling of 2026-10-10, QA item 11): a worn piece a CARRIED one beats
    -- (env.outdone with env.outdoneCarried) is sold: Keep.OutdoneTags. The player's Always keeps it.
    if env.outdoneCarried == true and type(env.outdone) == "string" and score.override ~= "always" then
      return Keep.OutdoneTags(score, settings, env)
    end
    return { tags = { Keep.TAG_KEEP }, noAuctionData = false, legendary = false, byUse = true, keepBy = Keep.KEEP_WORN }
  end
  -- Brief K31: a spare copy of the player's tool reads its ordinary verdict (Keep.ToolFree's view,
  -- the tool's keep and the player's trade uses left out), flagged so its reasons say "Spare
  -- Skinning tool". The player's Always keeps it.
  if score.override ~= "always" and Keep.ToolSpare(score, env) then
    local other = Keep.RawTags(Keep.ToolFree(score), settings, env)
    if type(other) == "table" then
      other.toolSpare = true
    end
    return other
  end
  -- Brief BQ9: an item to open, or a quest to start, now: [Open] or [Use] alone, never a sale.
  local now = Keep.DoNow(score, env)
  if now == Keep.ACTION_OPEN or now == Keep.ACTION_QUEST or now == Keep.ACTION_COLLECT then
    return Keep.ActionTags(now)
  end
  local keepBy = Keep.KeepReason(score, settings, env)
  -- Brief BQ9: a buff to use now, where nothing but the consumable facts' soft keep holds it.
  -- Brief BQ25a (the owner's ruling of 2026-10-10, QA item 67: "the [Use] tag can sit beside
  -- [Auction] as today, when the auction price checks out"): the price tags the item's ordinary
  -- verdict draws (Keep.UseBesides) follow the [Use] tag.
  if now == Keep.ACTION_USE and (keepBy == nil or keepBy == "could") then
    local useTags = Keep.ActionTags(now)
    -- Brief BQ30 addendum (QA item 95): a buff food's use now says "Eat it now to get a buff".
    if type(score.useBuff) == "table" and score.useBuff.food == true then
      useTags.food = true
    end
    return Keep.UseBesides(useTags, score, settings, env)
  end
  -- Brief BG1 (item 83, the owner's ruling 2 of 2026-10-13): a spare bag the rule alone keeps is the
  -- Keep, Vendor pair: [Keep], then the item's own sale verdict (Keep.BagFree's view) beside it, the
  -- choice the player's.
  if keepBy == "rule" and Keep.BagSpare(score) then
    local free = Keep.BagFree(score)
    if not Keep.KeepRule(free) then
      return Keep.SpareBagTags(Keep.RawTags(free, settings, env))
    end
  end
  -- Brief K30: the player holds more than the route's count of an item kept for it alone: [Keep]
  -- for the count, then the item's other verdict's tags for the rest (Keep.TradeFree's view, which
  -- keeps nothing), and the count as surplus (brief BQ16: the words are the route line's count,
  -- "Level First Aid (200 / 131 needed)").
  if keepBy == "rule" then
    local surplus = Keep.ReagentSurplus(score, env.have, settings, env)
    local otherView = surplus and Keep.TradeFree(score) or nil
    -- Brief INT1b (the owner's ruling of 2026-10-10, Q(c)): the route and the open quests together,
    -- their sum (Keep.CombinedKeepNeed); the rest is the item's verdict with both left out.
    local questPart = nil
    if surplus == nil then
      local total, _, quest = Keep.CombinedKeepNeed(score, settings, env)
      local have = tonumber(env.have)
      if total and have and have > total then
        surplus, questPart = total, quest
        otherView = Keep.QuestFree(Keep.TradeFree(score))
      end
    end
    if surplus then
      local other = Keep.RawTags(otherView, settings, env)
      local tags = { Keep.TAG_KEEP }
      local noData, legendary = false, false
      if type(other) == "table" then
        for _, tag in ipairs(other.tags or EMPTY) do
          tags[#tags + 1] = tag
        end
        noData = other.noAuctionData == true
        legendary = other.legendary == true
      end
      return {
        tags = tags,
        noAuctionData = noData,
        legendary = legendary,
        byUse = true,
        keepBy = keepBy,
        surplus = surplus,
        questPart = questPart,
      }
    end
  end
  -- Brief BQ18: the working stock keeps one stack, [Keep] alone; past it, [Keep] for the stack, then
  -- the item's other verdict's tags for the rest (Keep.StockFree's view), the stack as surplus.
  if keepBy == Keep.KEEP_STOCK then
    local surplus = Keep.StockSurplus(score, env.have)
    local tags = { Keep.TAG_KEEP }
    local noData, legendary = false, false
    if surplus then
      local other = Keep.RawTags(Keep.StockFree(score), settings, env)
      if type(other) == "table" then
        for _, tag in ipairs(other.tags or EMPTY) do
          if tag ~= Keep.TAG_KEEP then
            tags[#tags + 1] = tag
          end
        end
        noData = other.noAuctionData == true
        legendary = other.legendary == true
      end
    end
    return {
      tags = tags,
      noAuctionData = noData,
      legendary = legendary,
      byUse = true,
      keepBy = keepBy,
      surplus = surplus,
    }
  end
  -- Owner ruling 12: a quest item says nothing unless it is kept (a quest he is on). Brief QX1: or
  -- finished (Keep.FinishedTags: [Vendor] or [Worthless] with the quests done), nil otherwise.
  if keepBy == nil and Keep.QuestItem(score) then
    return Keep.FinishedTags(score)
  end
  local strong = keepBy ~= nil and keepBy ~= "could"
  local vendorPrice = tonumber(score.vendor) or 0
  local auction, legendary, beside, noData = false, false, false, false
  local facts = nil
  if Keep.CanAuction(score, env) then
    local price = tonumber(score.auction)
    if price and price >= Keep.LEGENDARY_COPPER then
      auction, legendary = true, true
    elseif Keep.KindCounts(score, env) and not score.everywhere then
      -- Brief K24b follow-up: beside the four rules by kind, an item vendors sell everywhere (K1)
      -- is never offered for auction, known price or not; anyone can buy it.
      facts = Keep.SaleFacts(score, settings)
      if facts.bar == nil then
        -- The Never stop: the player's own line says the auction house is never worth it.
        auction = false
      elseif price then
        if facts.clears then
          local band = Keep.MoneyBand(facts.auctionNet * Keep.StackSize(score), env.money)
          auction = band ~= "none"
          beside = band == "both"
        end
      else
        auction, beside, noData = true, true, true
      end
    end
  end
  -- Rule 10: disenchanting, only with Enchanting at the item's rank (score.disenchant).
  local disenchant, disenchantFirst = false, false
  if type(score.disenchant) == "table" then
    facts = facts or Keep.SaleFacts(score, settings)
    if facts.disenchantClears then
      local band = Keep.MoneyBand(facts.disenchantNet, env.money)
      disenchant = band ~= "none"
      if band == "both" then
        beside = true
      end
      disenchantFirst = disenchant and auction and facts.auctionNet ~= nil and facts.disenchantNet > facts.auctionNet
    end
  end
  -- Brief K24d: a keep the route still needs more of is [Keep] alone; the legendary rule stands
  -- beside Keep in every case.
  -- Brief CB1: so is a class book still to learn: it is for the player to read, not to sell.
  -- Brief AM1 (the review, the owner's K21 ruling of 2026-10-05: "a keep state never hides a worthwhile
  -- sale"): ammo the worn weapon fires is NOT among these; it takes the ordinary keep path below.
  if keepBy ~= nil and not legendary and (Keep.RouteKeepsAll(score, env.have) or keepBy == Keep.KEEP_CLASS_BOOK) then
    auction, beside, noData = false, false, false
    disenchant, disenchantFirst = false, false
  end
  -- Brief TV1 (QA item 347, the owner on Roasted Boar Meat: "When its best food in your bags it's
  -- probably a keep if its for your level and has a buff you need"): the best food or drink held for
  -- the player's level with a buff the class wants or the kill experience while levelling
  -- (Keep.BestBuffFood) is [Keep] alone, no sale tags; the legendary rule stands beside it.
  if keepBy == "could" and not legendary and Keep.BestBuffFood(score) then
    auction, beside, noData = false, false, false
    disenchant, disenchantFirst = false, false
  end
  -- Rule 9: a strong keep with no auction data is [Keep] alone. Brief GW3 (the owner's ruling 5B,
  -- 2026-10-13): except a [Keep] the gear test makes (Keep.GearUpgrade for a piece not worn today:
  -- far ahead, or within the look ahead), which keeps the "Auction (No AH data)" pair beside it, so a
  -- far ahead Six Demon Bag still says it could sell: "Keep, Auction (No AH data)", the Auction tag
  -- alone beside the keep (no Vendor: the piece is kept). An [Equip] (Keep.EquipNow) stays alone: a
  -- piece to put on now is never nudged to the auction house, nor is the player's own Always. QA item
  -- 153: a quiver or pouch upgrade kept until its level (Keep.BagLater) is far ahead gear's like.
  if strong and noData then
    local ahead = (Keep.GearUpgrade(score) and not Keep.EquipNow(score)) or Keep.BagLater(score) ~= nil
    if keepBy == "rule" and ahead then
      beside = false
    else
      auction, beside, noData = false, false, false
    end
  end
  if legendary then
    beside = false
  end
  local tags = {}
  local equipSpecs = nil
  if keepBy then
    -- Brief K24h: an upgrade the player can wear today is [Equip], the Keep tag's own look.
    -- Brief K26: the pet food stack a hunter keeps is [Pet food], the same look with a paw.
    if keepBy == Keep.KEEP_PET then
      tags[#tags + 1] = Keep.TAG_PET
    elseif Keep.EquipNow(score) then
      tags[#tags + 1] = Keep.TAG_EQUIP
      -- Brief BQ30 addendum (QA item 92): the specs the tag names, "Equip (Ret, Prot)".
      equipSpecs = Keep.EquipSpecWords(score)
    elseif keepBy == "rule" and Keep.BagUpgrade(score) then
      -- Brief BG1 (item 83's first half, the 10 October ruling): a bag that beats a worn one is
      -- [Equip] like a gear upgrade, the tag plain (QA item 92).
      tags[#tags + 1] = Keep.TAG_EQUIP
    else
      tags[#tags + 1] = Keep.TAG_KEEP
    end
  end
  if disenchantFirst then
    tags[#tags + 1] = Keep.TAG_DISENCHANT
  end
  if auction then
    tags[#tags + 1] = Keep.TAG_AUCTION
  end
  if disenchant and not disenchantFirst then
    tags[#tags + 1] = Keep.TAG_DISENCHANT
  end
  local sold = auction or disenchant
  if vendorPrice > 0 and ((sold and beside) or (not sold and not keepBy)) then
    tags[#tags + 1] = Keep.TAG_VENDOR
  elseif Keep.Worthless(score, env, vendorPrice, sold, keepBy) then
    -- Brief WL1 (rule 11): Vendor refused for no sell price, nothing else claims it.
    tags[#tags + 1] = Keep.TAG_WORTHLESS
  end
  if #tags == 0 then
    return nil
  end
  -- Brief BQ25a (the owner's ruling of 2026-10-10, QA item 67: "scrolls / pots / etc can be 'Use'
  -- all the time rather than Keep"): a usable consumable its own soft keep holds reads [Use], buff
  -- on or off; it stays a keep everywhere else (Keep.HasTag, the bag look, the API's keep).
  -- Brief BQ29 (QA item 87, the owner's correction of 2026-10-10: "If you use and you have the buff,
  -- both marks should become Keep"): a lasting buff consumable (an elixir or scroll whose verdict is
  -- a kept buff, Keep.LastingBuff) is [Use] only while its buff is off (Keep.DoNow above); kept with
  -- the buff on it is [Keep], as is a buff food while the player is well fed (QA item 86). The API
  -- then says its use is not for now (answer.buffOn: keep.action { kind = "use", now = false }).
  -- Potions, flasks and bandages have no buff state to wait on and stay [Use] at all times.
  local useKeep, buffOn = nil, nil
  if keepBy == "could" and tags[1] == Keep.TAG_KEEP then
    if Keep.LastingBuff(score) then
      buffOn = true
    elseif type(score.useBuff) == "table" and score.useBuff.food == true then
      buffOn = Keep.FedState(env) == true or nil
    elseif Keep.UseTagged(score) then
      tags[1] = Keep.TAG_USE
      useKeep = true
    end
  end
  return {
    tags = tags,
    noAuctionData = noData and auction or false,
    legendary = legendary,
    byUse = strong,
    keepBy = keepBy,
    useKeep = useKeep,
    equipSpecs = equipSpecs,
    buffOn = buffOn,
  }
end

-- Brief TV1 (QA item 347, the owner's ruling A of 2026-10-21: "A2 except we say [Keep] (Not enough AH
-- data) this simplifies that 3 way call and explains why - This should only happen for 3 way ties"):
-- the tags for a score, Keep.RawTags' answer (the order of decision above) with one last step, the
-- three way tie (Keep.SettleTie). Every reader asks this one; Keep.RawTags is the rules' own
-- recursion. Pure.
-- Brief FN2 (QA item 347 F): and the amount a [Keep] resting on a counted need holds, answer.keepCount
-- (Keep.KeepCount), which the tag reads as "Keep (22)" (Keep.TagWord, Keep.TagRow).
function Keep.Tags(score, settings, env)
  local answer = Keep.SettleTie(Keep.RawTags(score, settings, env))
  if type(answer) == "table" then
    answer.keepCount = Keep.KeepCount(score, answer, settings, env)
  end
  return answer
end

-- Brief FN2: a view of the score with the carried crates' combines left out (a shallow copy: not
-- carried, and current, ownCurrent and kinds.recipe less the carried combines Keep.FileCombine counted
-- in), for the verdict the item would have without them. Pure.
function Keep.CrateFree(score)
  local view, kinds = {}, {}
  for key, value in pairs(type(score) == "table" and score or EMPTY) do
    view[key] = value
  end
  -- Brief UL2 (QA item 366): the carried supply crates alone (score.carriedCrates); a toy combine carried
  -- stays a use without a count.
  local crates = tonumber(view.carriedCrates) or 0
  local others = math.max(0, (tonumber(view.carriedCombines) or 0) - crates)
  for key, value in pairs(view.kinds or EMPTY) do
    kinds[key] = value
  end
  local recipes = (tonumber(kinds.recipe) or 0) - crates
  kinds.recipe = recipes > 0 and recipes or nil
  view.kinds = kinds
  view.carried = others > 0
  view.carriedCombines = others
  view.carriedCrates = 0
  view.current = math.max(0, (tonumber(view.current) or 0) - crates)
  if tonumber(view.ownCurrent) ~= nil then
    view.ownCurrent = math.max(0, tonumber(view.ownCurrent) - crates)
  end
  return view
end

-- Brief FN2 (QA item 347 F, the owner's ruling of 2026-10-21: "Keep (N) where N is the amount
-- required"): how many of the item a [Keep] holds where it rests on a counted need, the need its
-- "(have / need needed)" lines end on, else nil:
--   the levelling route alone, or the route and the open quests together (Keep.KeepNeed, the API's
--     keep.need: "Level First Aid (40 / 78 needed)" holds 78)
--   the open quests alone (Keep.QuestKeepUpTo, the API's quests.keepUpTo, the count the quests' need
--     line reads: "Westfall Stew (II) (9 / 8 needed)" holds 8)
--   a carried crate (an item combine whose via item is in the bags): what the carried crates take
--     ("Waylaid Supplies: Peacebloom needs 20" holds 20), alone (the use rule keeps the item and would
--     not with the carried combines left out, Keep.CrateFree, as Keep.QuestOnly asks of the quests) or
--     added to the count above where that holds the rest (brief INT1b's sum, one need more: a crate and a
--     quest only keep of 5 hold 25)
-- The route's and the quests' are the counts Jettison keeps up to (keep.need, quests.keepUpTo). Only for
-- a keep by the use rule (answer.keepBy "rule") that leads with [Keep]: never the player's Always, a
-- worn piece, a spare bag or tool, or the working stock's own keep. settings and env are Keep.Tags'.
-- Pure.
function Keep.KeepCount(score, answer, settings, env)
  if type(score) ~= "table" or type(answer) ~= "table" or answer.keepBy ~= "rule" then
    return nil
  end
  if type(answer.tags) ~= "table" or answer.tags[1] ~= Keep.TAG_KEEP or answer.spareBag or answer.toolSpare then
    return nil
  end
  local crates = 0
  for _, combine in ipairs(score.carried == true and type(score.combines) == "table" and score.combines or EMPTY) do
    -- Brief UL2 (QA item 366): a supply crate's need alone, never a toy combine's.
    if type(combine) == "table" and combine.carried == true and combine.crate then
      crates = crates + (tonumber(combine.count) or 0)
    end
  end
  local view = crates > 0 and Keep.CrateFree(score) or score
  local count = Keep.KeepNeed(view, settings, env) or Keep.QuestKeepUpTo(view)
  if crates > 0 then
    -- Something with no count keeps the item beside the crates: no count.
    if count == nil and Keep.KeepRule(view) then
      return nil
    end
    count = (tonumber(count) or 0) + crates
  end
  count = tonumber(count)
  if count == nil or count < 1 then
    return nil
  end
  return math.floor(count)
end

-- Brief TV1 (ruling A): a tags answer that is exactly [Keep] [Auction] [Vendor] with no auction data
-- (a soft keep, a keep with a surplus, a spare bag) is [Keep] alone, flagged notEnoughData so the tag
-- row reads "[Keep] (Not enough AH data)"; exactly [Use] [Auction] [Vendor] with no auction data is
-- plain [Use], no sale tags and no note (the owner asked; the integrator's answer, plain [Use]). Any
-- other answer, two tags, a known price or a Disenchant tag among them, stands. The answer itself,
-- changed in place. Pure.
function Keep.SettleTie(answer)
  if type(answer) ~= "table" or answer.noAuctionData ~= true or type(answer.tags) ~= "table" then
    return answer
  end
  local tags = answer.tags
  if #tags ~= 3 or tags[2] ~= Keep.TAG_AUCTION or tags[3] ~= Keep.TAG_VENDOR then
    return answer
  end
  if tags[1] == Keep.TAG_KEEP then
    answer.tags = { Keep.TAG_KEEP }
    answer.noAuctionData = false
    answer.notEnoughData = true
  elseif tags[1] == Keep.TAG_USE then
    answer.tags = { Keep.TAG_USE }
    answer.noAuctionData = false
  end
  return answer
end

-- Brief TV1 (QA item 347): whether a score's consumable verdict is the best food or drink held for
-- the player's level with a buff they need: kept (verdict.keep), not outranked, food or drink, and
-- either a buff food for the class (verdict.buffFood) or an XP food whose restore holds for the level
-- (verdict.xpFood with verdict.efficient: "Best food in your bags, more kill experience"). An XP food
-- kept for its kill experience alone ("More kill experience while levelling") is not. Pure.
function Keep.BestBuffFood(score)
  local verdict = type(score) == "table" and score.consumable or nil
  if type(verdict) ~= "table" or verdict.keep ~= true or verdict.outranked then
    return false
  end
  if verdict.kind ~= "food" and verdict.kind ~= "drink" then
    return false
  end
  if verdict.buffFood == true then
    return true
  end
  return verdict.xpFood == true and verdict.efficient == true
end

--- Brief RB5 (QA item 202, the owner's ruling 2 of 2026-10-14: "a character can bank those items if
--- they are far ahead"): whether a score's consumable verdict (Consumables.Judge) is "ahead": a
--- profession the player has, at a rank not reached yet. Keep.KeepRule keeps it far ahead. Pure.
function Keep.ConsumableAhead(score)
  local verdict = type(score) == "table" and score.consumable or nil
  return type(verdict) == "table" and verdict.ahead == true
end

--- Brief BG1: the spare bag pair from the item's other verdict (other, Keep.Tags over Keep.BagFree's
--- view, or nil): [Keep], then its sale tags (no keep of its own). Pure.
function Keep.SpareBagTags(other)
  local tags = { Keep.TAG_KEEP }
  local noData, legendary = false, false
  if type(other) == "table" then
    for _, tag in ipairs(other.tags or EMPTY) do
      -- A bag no one buys keeps [Keep] alone (no Worthless beside a keep).
      local keepTag = tag == Keep.TAG_KEEP or tag == Keep.TAG_EQUIP or tag == Keep.TAG_USE or tag == Keep.TAG_PET
      if not keepTag and tag ~= Keep.TAG_WORTHLESS then
        tags[#tags + 1] = tag
      end
    end
    noData = other.noAuctionData == true
    legendary = other.legendary == true
  end
  return {
    tags = tags,
    noAuctionData = noData,
    legendary = legendary,
    byUse = true,
    keepBy = "rule",
    spareBag = true,
  }
end

-- Brief WL1 (QA item 108, the owner's ruling "A" of 2026-10-11): rule 11's test, in one place. True
-- where the sale verdict would be Vendor alone (not sold at auction or by disenchanting, no keep:
-- keepBy nil, which also leaves out the Use, Open, Equip and Pet food tags) but the vendor price is
-- 0 (vendorPrice, the score's), the auction house cannot take the item (Keep.CanAuction false:
-- bound by the slot's real state where env knows it, else by the row's bonding; a quest item never
-- gets here, rule 12 of 2026-09), and the gear test turned it down (Keep.GearRejected). The last
-- is the WL1 agent's narrowing, for the owner to confirm: without it 1,519 to 1,564 shipped rows
-- read Worthless per character, the Hearthstone, dungeon keys, Thieves' Tools, the shaman totems,
-- Soul Shards, mana gems "Can't use at your level" and quest letters among them, items ItemTree has no
-- verdict on at all (today they draw nothing, and still do). Brief AM3 (QA item 340, the owner at demo
-- level 40: "itemtree does not say to vendor/no worthless tag for sharp arrow"): beside the gear test's
-- turn down, the ammo rule's (score.ammoRejected, Keep.AmmoRejected: no worn weapon fires it, or it is
-- out of reach), where the auction house cannot take it OR vendors sell it everywhere (K24b: never
-- offered for auction, so there too nobody buys it): Sharp Arrow at 40 with a bow worn. Pure.
function Keep.Worthless(score, env, vendorPrice, sold, keepBy)
  if type(score) ~= "table" or keepBy ~= nil or sold then
    return false
  end
  if (tonumber(vendorPrice) or 0) > 0 then
    return false
  end
  local noAuction = not Keep.CanAuction(score, env)
  if score.ammoRejected == true then
    return noAuction or score.everywhere == true
  end
  return noAuction and Keep.GearRejected(score)
end

-- Brief WL1: whether the gear test judged a weapon or armour piece and turned it down for this
-- character: not an upgrade (at any level it is compared at), not for the class, not for the specs,
-- a grey or (brief GW3) white beyond the look ahead, or above the level cap. False for no gear
-- facts, an upgrade, a keep for a later level, and a compare that could not be made ("Nothing to
-- compare", for a piece whose worn match is not known; brief GW2: a far ahead one too, which read
-- "Needs level N" before). Pure.
function Keep.GearRejected(score)
  local gear = Keep.GearOf(score)
  if type(gear) ~= "table" or not Keep.EQUIPMENT_CLASSES[tonumber(score.itemClass) or -1] then
    return false
  end
  if tonumber(gear.later) then
    return false
  end
  if tonumber(gear.needs) or gear.poor == true or gear.common == true then
    return true
  end
  if gear.usable == false and tonumber(gear.ahead) == nil then
    return Keep.GEAR_NOT_FOR_CLASS[gear.why] == true
  end
  return gear.compare == "not_upgrade"
end

-- Brief BQ25a (the owner's ruling of 2026-10-10, QA item 67): the consumable subclasses whose own
-- keep reads [Use] at all times: 1 potion, 2 elixir (troll's blood among them), 3 flask, 4 scroll,
-- 7 bandage ("health and mana potions (and bandages) are [Use] items in ItemTree"). Food and drink
-- (5) stay [Keep], as do reagents, gear and quest items, which are kept by other rules.
Keep.USE_TAG_SUBCLASSES = { [1] = true, [2] = true, [3] = true, [4] = true, [7] = true }

-- Brief BQ29 (QA item 87): whether a score is a lasting buff consumable, an elixir or scroll
-- (USE_SUBCLASSES) whose consumable verdict is a kept buff: [Use] while its buff is off, [Keep] while
-- it is on. Pure.
function Keep.LastingBuff(score)
  if type(score) ~= "table" or tonumber(score.itemClass) ~= Keep.CONSUMABLE_CLASS then
    return false
  end
  if not Keep.USE_SUBCLASSES[tonumber(score.subclass) or -1] then
    return false
  end
  local verdict = score.consumable
  return type(verdict) == "table" and verdict.kind == "buff" and verdict.keep == true
end

-- Brief BQ32: the bandage subclass (consumable subclass 7).
Keep.BANDAGE_SUBCLASS = 7

-- Brief BQ32 (QA item 79 (b)): whether a score is a bandage: consumable subclass 7, or a consumable
-- whose verdict (Consumables.Judge) is a bandage on another subclass (Forever's Dense Runecloth
-- Bandage 232433 sits in 8, Other). Pure.
function Keep.IsBandage(score)
  if type(score) ~= "table" or tonumber(score.itemClass) ~= Keep.CONSUMABLE_CLASS then
    return false
  end
  if tonumber(score.subclass) == Keep.BANDAGE_SUBCLASS then
    return true
  end
  local verdict = score.consumable
  return type(verdict) == "table" and verdict.kind == "bandage"
end

-- Whether a score is a usable consumable by its row (score.itemClass, score.subclass). Brief BQ32:
-- or a bandage on another subclass (Keep.IsBandage), so every bandage its own keep holds reads
-- [Use]. Pure.
function Keep.UseTagged(score)
  -- Brief TV1 (QA item 347): a companion pet item's soft keep reads [Use] too (learn it).
  if type(score) == "table" and type(score.companion) == "table" then
    return true
  end
  if type(score) ~= "table" or tonumber(score.itemClass) ~= Keep.CONSUMABLE_CLASS then
    return false
  end
  return Keep.USE_TAG_SUBCLASSES[tonumber(score.subclass) or -1] == true or Keep.IsBandage(score)
end

-- Brief BQ25a (item 67): a [Use] verdict (Keep.ActionTags) with the price tags the item's ordinary
-- verdict would draw beside its keep ([Auction], [Disenchant], [Vendor] and their flags), read from
-- the same score with no use now buff (Keep.Tags, so the price rules are the normal ones). The
-- answer itself, changed in place. Pure.
function Keep.UseBesides(answer, score, settings, env)
  if type(answer) ~= "table" or type(score) ~= "table" then
    return answer
  end
  local plain = {}
  for key, value in pairs(score) do
    plain[key] = value
  end
  plain.useBuff = nil
  local ordinary = Keep.RawTags(plain, settings, env)
  if type(ordinary) ~= "table" then
    return answer
  end
  for _, tag in ipairs(ordinary.tags or EMPTY) do
    if tag ~= Keep.TAG_KEEP and tag ~= Keep.TAG_USE and tag ~= Keep.TAG_EQUIP and tag ~= Keep.TAG_PET then
      answer.tags[#answer.tags + 1] = tag
    end
  end
  answer.noAuctionData = ordinary.noAuctionData == true
  answer.legendary = ordinary.legendary == true
  return answer
end

-- Brief K24b (owner ruling 2026-10-05: "We have KEEP AND VALUE but we probably need DISENCHANT"):
-- whether the bags draw the item's Keep look in the Valuable colour (the VALUE mark): a KNOWN price
-- (the vendor sell price, or the auction price where the auction house can take the item) reaches
-- the "Valuable at" setting, whether or not the item is also a keep, as 0.1.7 marked a valuable
-- item (brief K9, with K19's vendor price). An item that cannot be sold (env.bound, a bind on
-- pickup or quest row) is never valuable; the player's Never and Off draw nothing (the caller's
-- rule). settings are the saved ones unless given. Pure.
function Keep.BagValuable(score, settings, env)
  if type(score) ~= "table" or Keep.QuestItem(score) then
    return false
  end
  local bound = nil
  if type(env) == "table" then
    bound = env.bound
  end
  if bound == true or (bound == nil and not Keep.Tradable(score)) then
    return false
  end
  local threshold = Keep.ValueThreshold(settings)
  if threshold == nil then
    return false
  end
  return Keep.Valuable(tonumber(score.vendor), threshold) or Keep.Valuable(tonumber(score.auction), threshold)
end

-- Whether a tags answer holds a tag. Brief K24h: the Equip tag is a Keep tag by another name, so
-- asking for "keep" finds it too; asking for "equip" finds Equip alone. Pure.
function Keep.HasTag(answer, tag)
  for _, held in ipairs(type(answer) == "table" and answer.tags or EMPTY) do
    if held == tag or (tag == Keep.TAG_KEEP and (held == Keep.TAG_EQUIP or held == Keep.TAG_PET)) then
      return true
    end
    -- Brief BQ25a (item 67): a consumable's own keep drawn as [Use] (answer.useKeep) is a keep.
    if tag == Keep.TAG_KEEP and held == Keep.TAG_USE and type(answer) == "table" and answer.useKeep == true then
      return true
    end
  end
  return false
end

-- Brief K24b (G): the old state word for a tags answer, so the API's keep.state keeps answering one
-- of its values: "keep" (or "keepDisenchant" for a Keep (disenchant)), else "sell" for an Auction
-- tag, "disenchant" for a Disenchant tag, "vendor" for a Vendor tag alone, "worthless" for a
-- Worthless tag (brief WL1); nil for no tags. And
-- the sale beside a keep (keep.sale): "sell" or "disenchant", nil for none. Pure.
function Keep.TagState(answer)
  if type(answer) ~= "table" then
    return nil, nil
  end
  local sale = nil
  if Keep.HasTag(answer, Keep.TAG_AUCTION) then
    sale = Keep.STATE_SELL
  elseif Keep.HasTag(answer, Keep.TAG_DISENCHANT) then
    sale = Keep.STATE_DISENCHANT
  end
  if Keep.HasTag(answer, Keep.TAG_KEEP) then
    if answer.keepBy == "disenchant" then
      return Keep.STATE_KEEP_DISENCHANT, sale
    end
    return Keep.STATE_KEEP, sale
  end
  if sale then
    return sale, nil
  end
  if Keep.HasTag(answer, Keep.TAG_VENDOR) then
    return Keep.STATE_VENDOR, nil
  end
  -- Brief WL1: a Worthless tag alone.
  if Keep.HasTag(answer, Keep.TAG_WORTHLESS) then
    return Keep.STATE_WORTHLESS, nil
  end
  return nil, nil
end

--------------------------------------------------------------------------------
-- Brief K24b (B): "could use", PROVISIONAL. A STAND IN for the data round: until the pipeline
-- ships what each consumable does, a consumable is a SOFT keep when the player's class is allowed
-- by its class mask, any required skill is one the player has at that rank, its required level
-- is no more than COULD_AHEAD above the player's, and the player's level minus its required level
-- (its item level where it has none) is COULD_BEHIND or less. Brief K24h (tester QA 2026-10-07, a
-- level 1 character told to vendor the food they start with): food and drink are judged the same
-- way, by their level window alone (Classic's food tiers open about every ten levels, so a stack
-- is still worth eating for a few levels after its own), and read "Food or drink for your level"
-- (Jettison's wording); the restore amount the pipeline does not ship yet would refine it.
-- Replace this function, not its callers, when the data lands.
--------------------------------------------------------------------------------

Keep.COULD_AHEAD = 10
Keep.COULD_BEHIND = 5

-- Brief BQ6 (backlog 5): the professions' skill lines (First Aid, Blacksmithing, Leatherworking,
-- Alchemy, Herbalism, Cooking, Mining, Tailoring, Engineering, Enchanting, Fishing, Skinning). A
-- consumable that asks for one of them is that profession's (a lure, a device).
Keep.PROFESSION_LINES = {
  [129] = true,
  [164] = true,
  [165] = true,
  [171] = true,
  [182] = true,
  [185] = true,
  [186] = true,
  [197] = true,
  [202] = true,
  [333] = true,
  [356] = true,
  [393] = true,
}

--- Brief BQ6 (backlog 5): the profession line a row's required skill is, or nil for none or a skill
--- that is no profession: the line itself, or its parent (Consumables.ParentLine) for a profession's
--- child line (First Aid's 2942). Pure over the data tables.
function Keep.ProfessionLine(skill)
  skill = tonumber(skill)
  if skill == nil or skill <= 0 then
    return nil
  end
  if Keep.PROFESSION_LINES[skill] then
    return skill
  end
  local consumables = ItemTree.Consumables
  if type(consumables) == "table" and type(consumables.ParentLine) == "function" then
    local ok, parent = pcall(consumables.ParentLine, skill)
    if ok and tonumber(parent) and Keep.PROFESSION_LINES[tonumber(parent)] then
      return tonumber(parent)
    end
  end
  return nil
end
-- Brief K26: the level cap the client does not state (GetMaxPlayerLevel, Keep.MaxLevel).
Keep.MAX_LEVEL = 60

--- Brief BQ23 (item 38): a camp item's soft keep: below the level cap (maxLevel, MAX_LEVEL unless
--- given) and usable by Keep.CouldUse's gates (its class mask, its required skill at its rank, its
--- level in reach); false at the cap. Pure over its arguments and the data tables.
function Keep.CampCouldUse(row, classId, level, rankOf, effect, maxLevel)
  level = tonumber(level)
  if level == nil or level >= (tonumber(maxLevel) or Keep.MAX_LEVEL) then
    return false
  end
  return Keep.CouldUse(row, classId, level, rankOf, effect, maxLevel)
end

--------------------------------------------------------------------------------
-- Brief BQ25c (the owner's QA of 2026-10-10, item 52: Old Blanchy's Feed Pouch read [Vendor] while
-- Jettison read "Locked: bigger than your 6 slot bag"): the bag rule, like compared with like.
--   normal bag     against the smallest equipped NORMAL bag, or an empty normal bag slot: bigger is a
--                  Keep ("Bigger than your 6 slot bag", "Fills an empty bag slot"), else [Vendor].
--                  Brief BG4 follow up (the owner's leeway, item 186, both ways): a profession bag
--                  worn in a normal slot is weighed too, counting Keep.PROFESSION_BAG_LEEWAY slots
--                  smaller, a tie to the normal bag ("Better than your 12 slot profession bag")
--   quiver, ammo pouch  only for a character that can shoot its ammo (a hunter, warrior or rogue; a
--                  quiver for a worn bow or crossbow, a pouch for a worn gun, either with no ranged
--                  weapon worn), against the equipped one of its kind: ranged attack speed first, then
--                  slots ("Faster quiver than yours"); none of its kind equipped is a Keep. QA item 153
--                  (the owner, 2026-10-14): an upgrade whose required level is above the character's
--                  keeps until that level, [Keep] "Quiver upgrade at level 30", never [Equip]; that
--                  upgrade is the one Keep a quiver or pouch earns (never a spare for the bank)
--   soul bag       only for a warlock, against the smallest equipped soul bag (brief F160: one in the
--                  reagent bag slot counts too, the owner on 2026-10-14: "same with warlock soul shard
--                  bags but not hunter quivers")
--   reagent bag    Forever's reagent bag slot (Enum.BagIndex.ReagentBag). Brief F160 (the owner's
--                  ruling of 2026-10-14, "general reagent bags ... not just leatherworking/profession
--                  specific"): a plain reagent bag (container subclass 11) is ITS OWN KIND, the way a
--                  quiver is: weighed only against the reagent bag in that slot (an empty slot is a
--                  Keep), for every character (no trade asked), an upgrade the character cannot use
--                  yet kept until its level, never a spare for the bank (brief RB5, QA item 206: the
--                  owner's "No it can't", a reagent bag never goes in a bank bag slot), never
--                  "Bigger than your N slot bag" against a general bag.
--                  Brief BG4 (the owner's QA of 2026-10-17, items 184 to 186, tested on 70425: a
--                  reagent bag goes in the reagent slot only; a profession bag, and a warlock's soul
--                  bag, in any slot, the reagent slot too): whatever bag the slot holds is weighed
--                  by slots, and a tie goes to the reagent bag over a profession bag ("If its a tie
--                  then reagent bag wins over profession bag"): "Upgrade for your reagent bag slot",
--                  else "Smaller than" (or "No bigger than") "the bag in your reagent bag slot" (was
--                  "Your reagent bag slot holds a ...", no keep, which the owner could not read)
--   profession bag only for the character's trades (BQ25c: its family names them). Brief K14 (ruling
--                  2, the owner on 2026-10-14: "skinny satchel can go in normal/bank/reagent slots"):
--                  it fits the reagent bag slot AND a normal bag slot, and is kept when it would be
--                  kept for either: against the reagent slot by slots (brief BG4: whatever bag is
--                  there; a reagent bag the same size keeps the slot), or in the normal slots against
--                  an empty slot, the smallest profession bag worn there ("Bigger than your 4 slot
--                  profession bag") or (brief BG4, item 186: "I would give more leeway to real bags
--                  in real bag slots") a normal bag, the profession bag counting as
--                  Keep.PROFESSION_BAG_LEEWAY slots smaller and a tie going to the normal bag; never
--                  a quiver or soul bag. Kept for neither place: "Worse than your current bags" (the
--                  owner's words for Jettison, item 185). Never a spare for the bank (the bank
--                  question is the owner's, not asked)
--   the keyring    never a slot and never an upgrade (it is no item; the bag read leaves it out)
-- Quivers, ammo pouches and soul bags sit in normal bag slots, so they count among the normal
-- slots: an empty slot is free for any of them, and a normal bag is compared with the normal bags
-- only (brief F160: never with a quiver, pouch or soul bag, so a character with none but those worn
-- and no slot empty gets no bag word; brief BG4 follow up: a profession bag in a normal slot is
-- weighed, with the leeway). The state is Keep.BagState's (the client's bags, or the demo's `demo
-- bags`); with none the rule says nothing and the item goes by its other facts, as before.
--------------------------------------------------------------------------------

Keep.CONTAINER_CLASS = 1
Keep.QUIVER_CLASS = 11
Keep.BAG_NORMAL = "normal"
Keep.BAG_SOUL = "soul"
Keep.BAG_QUIVER = "quiver"
Keep.BAG_POUCH = "pouch"
Keep.BAG_REAGENT = "reagent"
Keep.BAG_PROFESSION = "profession"
Keep.WARLOCK_CLASS = 9
-- Brief BG4 (the owner's ruling of 2026-10-17, item 186: "a profession bag that is 16 slot is
-- probably worse than a normal bag that is 14 slot (or possibly even 12 slot)"): in a normal bag slot
-- a profession bag counts as this many slots smaller than it is against a normal bag, and a tie goes
-- to the normal bag (16 slots against 12 is a tie, so the 12 slot bag stays).
Keep.PROFESSION_BAG_LEEWAY = 4
-- The classes that shoot arrows and bullets: warrior, hunter, rogue.
Keep.SHOOTER_CLASSES = { [1] = true, [3] = true, [4] = true }
-- The ranged weapon subclasses (item class 2) that fire arrows and bullets.
Keep.FIRES_ARROWS = { [2] = true, [18] = true }
Keep.FIRES_BULLETS = { [3] = true }
Keep.RANGED_SLOT = 18

-- A profession bag's family bit (the client's GetItemFamily, the rows' bf) by container subclass,
-- where a row states none.
Keep.BAG_SUBCLASS_FAMILY = {
  [2] = 32, -- herb
  [3] = 64, -- enchanting
  [4] = 128, -- engineering
  [5] = 512, -- gem
  [6] = 1024, -- mining
  [7] = 33554432, -- skinning (Forever's leather bags)
  [8] = 16, -- inscription
}
-- The trades whose goods a profession bag holds, by family bit: Leatherworking 8 and Skinning
-- 33554432 hold leather and hides; Herb 32 herbs (Herbalism, Alchemy); Enchanting 64; Engineering
-- 128; Mining 1024 ore and bars (Mining, Blacksmithing, Engineering); Gem 512; Inscription 16;
-- Fishing 32768; Cooking 65536.
Keep.BAG_FAMILY_TRADES = {
  [8] = { 165, 393 },
  [16] = { 773 },
  [32] = { 182, 171 },
  [64] = { 333 },
  [128] = { 202 },
  [512] = { 186 },
  [1024] = { 186, 164, 202 },
  [32768] = { 356 },
  [65536] = { 185 },
  [33554432] = { 393, 165 },
}
-- The ranged attack speed a quiver or ammo pouch gives, by its equip spell ("Haste"). Every spell
-- reads "Increases ranged attack speed by $s1%." and the amounts are the spells' own $s1 (SpellEffect
-- EffectBasePointsF, aura 557, the same from build 1.60.1.70058 to 70338): quivers 29418 10%, 29417
-- 11%, 29416 12%, 29413 13%, 29415 14%, 29414 15%; ammo pouches 14824 10%, 14825 11%, 14826 12%,
-- 14827 13%, 14828 14%, 14829 15%. Brief SM1 (QA item 77c): these twelve cover every quiver and pouch
-- shipped, the Classic Era rows (Ribbly's, Sanguine, Soulfrost, Scarlet) among them, and every class
-- 11 item of the client's own Item table (tests/spec/keep_quiver_speeds_spec.lua); 29413 was 14 here
-- before the client tables were read (Quickdraw Quiver and Matriarch Quiver read 13%).
Keep.BAG_SPEED_SPELLS = {
  [29418] = 10,
  [29417] = 11,
  [29416] = 12,
  [29413] = 13,
  [29415] = 14,
  [29414] = 15,
  [14824] = 10,
  [14825] = 11,
  [14826] = 12,
  [14827] = 13,
  [14828] = 14,
  [14829] = 15,
}

--- The bag kind of an item row (Keep.BAG_NORMAL and the rest) and its family bit (0 for a normal bag,
--- a quiver 1, an ammo pouch 2, a soul bag 4, a profession bag its trade's bit, a plain reagent bag 0),
--- or nil for an item that is no bag. Pure.
function Keep.BagKind(row)
  if type(row) ~= "table" then
    return nil
  end
  local class, sub = tonumber(row.c), tonumber(row.sc) or 0
  if class == Keep.QUIVER_CLASS then
    if sub == 2 then
      return Keep.BAG_QUIVER, 1
    elseif sub == 3 then
      return Keep.BAG_POUCH, 2
    end
    return nil
  end
  if class ~= Keep.CONTAINER_CLASS then
    return nil
  end
  if sub == 0 then
    return Keep.BAG_NORMAL, 0
  elseif sub == 1 then
    return Keep.BAG_SOUL, 4
  elseif sub == 11 then
    return Keep.BAG_REAGENT, 0
  end
  return Keep.BAG_PROFESSION, tonumber(row.bf) or Keep.BAG_SUBCLASS_FAMILY[sub] or 0
end

--- The ranged attack speed (a whole percent) a quiver or ammo pouch row gives, 0 for none. Pure.
function Keep.BagSpeed(row)
  local best = 0
  for _, effect in ipairs(type(row) == "table" and type(row.fx) == "table" and row.fx or EMPTY) do
    local speed = type(effect) == "table" and Keep.BAG_SPEED_SPELLS[tonumber(effect[2]) or -1] or nil
    if speed and speed > best then
      best = speed
    end
  end
  return best
end

-- One equipped bag as the rule reads it: { size, kind, family, speed, itemId }. size 0 is an empty
-- slot. rowOf(itemId) answers the item row.
local function bagEntry(size, itemId, rowOf)
  local id = tonumber(itemId)
  local row = id and type(rowOf) == "function" and rowOf(id) or nil
  local kind, family = Keep.BagKind(row)
  size = tonumber(size) or 0
  if type(row) == "table" and size <= 0 then
    size = tonumber(row.cs) or 0
  end
  if size <= 0 then
    return { size = 0, kind = Keep.BAG_NORMAL, family = 0, speed = 0 }
  end
  return {
    size = size,
    kind = kind or Keep.BAG_NORMAL,
    family = family or 0,
    speed = Keep.BagSpeed(row),
    itemId = id,
  }
end

--- The bag state from the demo's shape (`/itemtree demo bags`, the self test's Pretend: { sizes = {
--- n, n, n, n }, items = { [slot] = itemId }, reagent = { size, family } }): the four normal slots
--- and the reagent slot (empty where the shape names none: the Forever client has one). rowOf
--- answers an equipped bag's row (its kind, slots and speed). nil for no shape. Pure over rowOf.
function Keep.BagStateOf(bags, rowOf)
  if type(bags) ~= "table" or type(bags.sizes) ~= "table" then
    return nil
  end
  local items = type(bags.items) == "table" and bags.items or EMPTY
  local state = { slots = {} }
  for index = 1, 4 do
    state.slots[index] = bagEntry(bags.sizes[index], items[index], rowOf)
  end
  local reagent = type(bags.reagent) == "table" and bags.reagent or nil
  state.reagent = {
    size = reagent and tonumber(reagent.size) or 0,
    family = reagent and tonumber(reagent.family) or 0,
  }
  -- Brief F160: the kind of bag in the reagent slot, so a bag is weighed against it only where the
  -- kinds match: the shape's own kind (the client's read), else by its family bit (the demo's).
  if state.reagent.size > 0 then
    state.reagent.kind = reagent.kind or Keep.ReagentSlotKind(state.reagent.family)
  end
  Keep.AddSpareState(state, bags, rowOf)
  return state
end

--- Brief F160: the kind of bag a family bit stands for in the reagent slot, where no row says: a soul
--- bag's 4, a plain reagent bag's 0, any other bit a profession bag's. Pure.
function Keep.ReagentSlotKind(family)
  family = tonumber(family) or 0
  if family == 0 then
    return Keep.BAG_REAGENT
  elseif family == 4 then
    return Keep.BAG_SOUL
  end
  return Keep.BAG_PROFESSION
end

--- Brief BG1 (item 83, the owner's rulings of 2026-10-13): the spare bag facts on a bag state, from
--- the shape's optional fields: carried (the bag item ids in the bags, a list), bank ({ sizes = { n,
--- ... } for each BOUGHT bank bag slot in order, 0 for an empty one, items = { [slot] = itemId },
--- stored = { itemIds } the bags lying in the bank }, nil while the bank is not known) and bankMax
--- (the bank's bag slots with every slot bought, the spare bag cap). Sets state.carried and
--- state.stored (lists of bag entries, Keep.BagStateOf's shape), state.bank ({ slots = entries },
--- nil while not known) and state.bankMax. Answers the state. Pure over rowOf.
function Keep.AddSpareState(state, bags, rowOf)
  if type(state) ~= "table" or type(bags) ~= "table" then
    return state
  end
  local function entries(ids)
    local out = {}
    for _, id in ipairs(type(ids) == "table" and ids or EMPTY) do
      local entry = bagEntry(0, id, rowOf)
      if entry.size > 0 and entry.itemId then
        out[#out + 1] = entry
      end
    end
    return out
  end
  state.carried = entries(bags.carried)
  local bank = type(bags.bank) == "table" and bags.bank or nil
  state.stored = entries(bank and bank.stored or nil)
  state.bank = nil
  if bank and type(bank.sizes) == "table" then
    local items = type(bank.items) == "table" and bank.items or EMPTY
    local slots = {}
    for index, size in ipairs(bank.sizes) do
      slots[index] = bagEntry(size, items[index], rowOf)
    end
    state.bank = { slots = slots }
  end
  state.bankMax = tonumber(bags.bankMax) or (bank and tonumber(bank.max)) or nil
  return state
end

--- A bag state's signature for the score cache key: "6.0.0,6.0.0,...|r12.0", or nil for no state.
--- Pure.
function Keep.BagSignature(state)
  if type(state) ~= "table" or type(state.slots) ~= "table" then
    return nil
  end
  -- Brief BG1: a state is never changed once built, so its signature is worked out once.
  if type(state.signature) == "string" then
    return state.signature
  end
  local parts = {}
  for index, slot in ipairs(state.slots) do
    parts[index] =
      string.format("%d.%d.%d", tonumber(slot.size) or 0, tonumber(slot.family) or 0, tonumber(slot.speed) or 0)
  end
  local text = table.concat(parts, ",")
  if type(state.reagent) == "table" then
    text = text .. string.format("|r%d.%d", tonumber(state.reagent.size) or 0, tonumber(state.reagent.family) or 0)
    -- Brief F160: and its kind, where a bag is in it (a soul bag and a reagent bag weigh apart).
    if state.reagent.kind ~= nil then
      text = text .. "." .. tostring(state.reagent.kind)
    end
  end
  -- Brief BG1: the spare bags carried and stored and the bank's bag slots, only where stated, so the
  -- key is as it was for a state without them.
  local function ids(list)
    local out = {}
    for _, entry in ipairs(type(list) == "table" and list or EMPTY) do
      out[#out + 1] = tonumber(entry.itemId) or 0
    end
    table.sort(out)
    return table.concat(out, ".")
  end
  if type(state.carried) == "table" and #state.carried > 0 then
    text = text .. "|c" .. ids(state.carried)
  end
  if type(state.bank) == "table" then
    local slots = {}
    for index, slot in ipairs(state.bank.slots or EMPTY) do
      slots[index] = string.format("%d.%d", tonumber(slot.size) or 0, tonumber(slot.family) or 0)
    end
    text = text .. "|b" .. table.concat(slots, ",") .. "/" .. ids(state.stored)
  end
  if tonumber(state.bankMax) then
    text = text .. "|m" .. tostring(state.bankMax)
  end
  state.signature = text
  return text
end

-- Whether the character can shoot the ammo a quiver (BAG_QUIVER) or pouch holds, and the words when
-- not: a class that shoots none, or a worn ranged weapon that fires the other ammo (or none).
local function canShoot(kind, classId, ranged)
  if not Keep.SHOOTER_CLASSES[tonumber(classId) or -1] then
    return false, L["Not for your class"]
  end
  if type(ranged) == "table" and tonumber(ranged.c) == 2 then
    local sub = tonumber(ranged.sc) or -1
    if kind == Keep.BAG_QUIVER and not Keep.FIRES_ARROWS[sub] then
      return false, L["Your ranged weapon does not use arrows"]
    end
    if kind == Keep.BAG_POUCH and not Keep.FIRES_BULLETS[sub] then
      return false, L["Your ranged weapon does not use bullets"]
    end
  end
  return true, nil
end

-- Whether the character's professions (a set of skill line ids) use a reagent or profession bag of
-- that family: a plain reagent bag (family 0) any trade, a profession bag its family's trades.
local function bagForTrades(family, professions)
  if type(professions) ~= "table" then
    return false
  end
  family = tonumber(family) or 0
  if family == 0 then
    for line, held in pairs(professions) do
      if held and Keep.PROFESSION_LINES[tonumber(line) or -1] then
        return true
      end
    end
    return false
  end
  for bit, trades in pairs(Keep.BAG_FAMILY_TRADES) do
    if family % (bit * 2) >= bit then
      for _, line in ipairs(trades) do
        if professions[line] then
          return true
        end
      end
    end
  end
  return false
end

local function verdict(kind, slots, keep, words, against, speed)
  return { kind = kind, slots = slots, keep = keep, words = words, against = against, speed = speed }
end

-- The normal slots' answer for a normal bag. Brief F160 ("Bigger than your N slot bag" never crosses
-- kinds): weighed against the normal bags, never a quiver, ammo pouch or soul bag, so with only those
-- worn and no slot empty there is no answer, where it was the smallest special bag. Brief BG4 follow
-- up (the owner's ruling of 2026-10-17, item 186, "more leeway to real bags in real bag slots", both
-- ways): a profession bag worn in a normal slot is weighed too, counting Keep.PROFESSION_BAG_LEEWAY
-- slots smaller than it is, a tie to the normal bag, so the bag must beat its slots less the leeway
-- less one. The bag replaces the weakest slot: the profession bag where its mark is no higher than
-- the smallest normal bag's ("Bigger than your 4 slot profession bag", or "Better than your 12 slot
-- profession bag" for one no bigger); no better than it and no normal bag worn, "Worse than your
-- current bags".
local function normalVerdict(slots, state)
  local smallest, weakest = nil, nil
  for _, slot in ipairs(state.slots) do
    local size = tonumber(slot.size) or 0
    if size <= 0 then
      return verdict(Keep.BAG_NORMAL, slots, true, L["Fills an empty bag slot"], 0)
    end
    if slot.kind == Keep.BAG_NORMAL and (smallest == nil or size < smallest) then
      smallest = size
    end
    if slot.kind == Keep.BAG_PROFESSION then
      local mark = size - Keep.PROFESSION_BAG_LEEWAY - 1
      if weakest == nil or mark < weakest.mark then
        weakest = { mark = mark, size = size }
      end
    end
  end
  if weakest ~= nil and slots > weakest.mark and (smallest == nil or weakest.mark <= smallest) then
    local words = L["Better than your %d slot profession bag"]
    if slots > weakest.size then
      words = L["Bigger than your %d slot profession bag"]
    end
    return verdict(Keep.BAG_NORMAL, slots, true, string.format(words, weakest.size), weakest.size)
  end
  if smallest == nil then
    if weakest ~= nil then
      return verdict(Keep.BAG_NORMAL, slots, false, L["Worse than your current bags"], weakest.size)
    end
    return nil
  end
  if slots > smallest then
    return verdict(Keep.BAG_NORMAL, slots, true, string.format(L["Bigger than your %d slot bag"], smallest), smallest)
  elseif slots < smallest then
    return verdict(Keep.BAG_NORMAL, slots, false, string.format(L["Smaller than your %d slot bag"], smallest), smallest)
  end
  return verdict(Keep.BAG_NORMAL, slots, false, string.format(L["No bigger than your %d slot bag"], smallest), smallest)
end

-- QA item 153 (the owner, 2026-10-14: "you still want to keep better ones you can't wear yet but
-- that is really the only keep"): an upgrade (keep true) whose required level is above the
-- character's keeps until that level, as far ahead gear does: [Keep] "Quiver upgrade at level 30",
-- later the level, never [Equip] (Keep.BagUpgrade). required and level nil: no level test.
local function ammoUpgrade(answer, quiver, required, level)
  required, level = tonumber(required), tonumber(level)
  if required == nil or level == nil or required <= level then
    return answer
  end
  local words = quiver and L["Quiver upgrade at level %d"] or L["Ammo pouch upgrade at level %d"]
  answer.words, answer.later = string.format(words, required), required
  return answer
end

-- A quiver's or ammo pouch's answer against the equipped one of its kind (the best of them).
-- required is the row's required level and level the character's (QA item 153: ammoUpgrade).
local function ammoVerdict(kind, slots, speed, state, classId, ranged, required, level)
  local quiver = kind == Keep.BAG_QUIVER
  local ok, why = canShoot(kind, classId, ranged)
  if not ok then
    return verdict(kind, slots, false, why, nil, speed)
  end
  local best = nil
  for _, slot in ipairs(state.slots) do
    if slot.kind == kind and (tonumber(slot.size) or 0) > 0 then
      if best == nil or slot.speed > best.speed or (slot.speed == best.speed and slot.size > best.size) then
        best = slot
      end
    end
  end
  if best == nil then
    local words = quiver and L["No quiver equipped"] or L["No ammo pouch equipped"]
    return ammoUpgrade(verdict(kind, slots, true, words, 0, speed), quiver, required, level)
  end
  if speed > best.speed then
    local words = quiver and L["Faster quiver than yours"] or L["Faster ammo pouch than yours"]
    return ammoUpgrade(verdict(kind, slots, true, words, best.size, speed), quiver, required, level)
  end
  if speed < best.speed then
    local words = quiver and L["Slower than your quiver"] or L["Slower than your ammo pouch"]
    return verdict(kind, slots, false, words, best.size, speed)
  end
  if slots > best.size then
    local words = quiver and L["Bigger than your %d slot quiver"] or L["Bigger than your %d slot ammo pouch"]
    local answer = verdict(kind, slots, true, string.format(words, best.size), best.size, speed)
    return ammoUpgrade(answer, quiver, required, level)
  end
  if slots < best.size then
    local words = quiver and L["Smaller than your quiver"] or L["Smaller than your ammo pouch"]
    return verdict(kind, slots, false, words, best.size, speed)
  end
  local words = quiver and L["No better than your quiver"] or L["No better than your ammo pouch"]
  return verdict(kind, slots, false, words, best.size, speed)
end

-- A soul bag's answer: a warlock's, against the smallest equipped soul bag.
local function soulVerdict(slots, state, classId)
  if tonumber(classId) ~= Keep.WARLOCK_CLASS then
    return verdict(Keep.BAG_SOUL, slots, false, L["Soul bags are for warlocks"])
  end
  local smallest = nil
  for _, slot in ipairs(state.slots) do
    if slot.kind == Keep.BAG_SOUL and (tonumber(slot.size) or 0) > 0 then
      if smallest == nil or slot.size < smallest then
        smallest = slot.size
      end
    end
  end
  -- Brief F160 (the owner, 2026-10-14: a soul shard bag fits the reagent bag slot): a soul bag there
  -- is an equipped soul bag too.
  local reagent = type(state.reagent) == "table" and state.reagent or nil
  local held = reagent and tonumber(reagent.size) or 0
  if reagent and reagent.kind == Keep.BAG_SOUL and held > 0 and (smallest == nil or held < smallest) then
    smallest = held
  end
  if smallest == nil then
    return verdict(Keep.BAG_SOUL, slots, true, L["No soul bag equipped"], 0)
  end
  if slots > smallest then
    return verdict(
      Keep.BAG_SOUL,
      slots,
      true,
      string.format(L["Bigger than your %d slot soul bag"], smallest),
      smallest
    )
  end
  return verdict(
    Keep.BAG_SOUL,
    slots,
    false,
    string.format(L["No bigger than your %d slot soul bag"], smallest),
    smallest
  )
end

-- Brief BG4 (the owner's QA of 2026-10-17, items 184 and 185): the reagent slot's words against a
-- bag there that is no plain reagent bag (a profession bag, a warlock's soul bag), weighed by slots;
-- won is the slot's answer. Written out one literal at a time, so the locale sweep sees every key.
local function slotWords(won, slots, size)
  if won then
    return L["Upgrade for your reagent bag slot"]
  elseif slots < size then
    return L["Smaller than the bag in your reagent bag slot"]
  end
  return L["No bigger than the bag in your reagent bag slot"]
end

-- A reagent or profession bag's answer against the reagent bag slot. Brief F160 (the owner's ruling
-- of 2026-10-14): a plain reagent bag is its own kind, for every character (a profession bag still
-- asks the character's trades, BQ25c); an upgrade above the character's level keeps until that level
-- ("Reagent bag upgrade at level 30", later, as a quiver's: QA item 153). Brief BG4 (the owner's
-- rulings of 2026-10-17, items 184 and 186): the slot takes a reagent bag, a profession bag or a soul
-- bag, so whatever bag is there is weighed by slots, and on a tie a reagent bag wins over a profession
-- bag ("If its a tie then reagent bag wins over profession bag"); a plain reagent bag there keeps its
-- words ("Bigger than your 6 slot reagent bag"). Was: another kind there kept nothing and said "Your
-- reagent bag slot holds a profession bag", so a 6 slot reagent bag read no upgrade over a 4 slot
-- leather bag in the slot. required and level are the row's and the character's.
local function reagentVerdict(kind, family, slots, state, professions, required, level)
  local slot = state.reagent
  if type(slot) ~= "table" then
    return nil
  end
  if kind ~= Keep.BAG_REAGENT and not bagForTrades(family, professions) then
    return verdict(kind, slots, false, L["Not for your professions"])
  end
  local size = tonumber(slot.size) or 0
  local held = slot.kind or Keep.ReagentSlotKind(slot.family)
  local answer
  if size <= 0 then
    answer = verdict(kind, slots, true, L["Fills your empty reagent bag slot"], 0)
  elseif held ~= Keep.BAG_REAGENT then
    local won = slots > size or (slots == size and kind == Keep.BAG_REAGENT and held == Keep.BAG_PROFESSION)
    answer = verdict(kind, slots, won, slotWords(won, slots, size), size)
    if not won then
      return answer
    end
  elseif slots > size then
    answer = verdict(kind, slots, true, string.format(L["Bigger than your %d slot reagent bag"], size), size)
  else
    return verdict(kind, slots, false, string.format(L["No bigger than your %d slot reagent bag"], size), size)
  end
  required, level = tonumber(required), tonumber(level)
  if kind == Keep.BAG_REAGENT and required and level and required > level then
    answer.words, answer.later = string.format(L["Reagent bag upgrade at level %d"], required), required
  end
  return answer
end

-- Brief K14 (ruling 2, the owner on 2026-10-14: "skinny satchel can go in normal/bank/reagent
-- slots"): a profession bag's answer in the four normal bag slots: an empty slot is a Keep ("Fills an
-- empty bag slot"); else it is weighed against the weakest bag it could take the place of, the
-- smallest profession bag worn in a normal slot ("Bigger than your 4 slot profession bag") or, brief
-- BG4 (the owner's ruling of 2026-10-17, item 186: "I would give more leeway to real bags in real bag
-- slots"), the smallest normal bag, which counts Keep.PROFESSION_BAG_LEEWAY slots bigger than it is
-- (a tie goes to the normal bag: a 16 slot profession bag beats no 12 slot bag, "Bigger than your 10
-- slot bag" where it does). Where both are as weak, the profession bag is named. No better than
-- that: "Worse than your current bags". With neither worn there (every slot a quiver, an ammo pouch
-- or a soul bag) there is no answer: never a compare with those kinds.
local function professionSlotsVerdict(slots, state)
  local weakest = nil
  for _, slot in ipairs(state.slots) do
    local size = tonumber(slot.size) or 0
    if size <= 0 then
      return verdict(Keep.BAG_PROFESSION, slots, true, L["Fills an empty bag slot"], 0)
    end
    local worth = nil
    if slot.kind == Keep.BAG_PROFESSION then
      worth = size
    elseif slot.kind == Keep.BAG_NORMAL then
      worth = size + Keep.PROFESSION_BAG_LEEWAY
    end
    if
      worth ~= nil
      and (weakest == nil or worth < weakest.worth or (worth == weakest.worth and slot.kind == Keep.BAG_PROFESSION))
    then
      weakest = { worth = worth, size = size, kind = slot.kind }
    end
  end
  if weakest == nil then
    return nil
  end
  if slots <= weakest.worth then
    return verdict(Keep.BAG_PROFESSION, slots, false, L["Worse than your current bags"], weakest.size)
  end
  local words
  if weakest.kind == Keep.BAG_PROFESSION then
    words = string.format(L["Bigger than your %d slot profession bag"], weakest.size)
  else
    words = string.format(L["Bigger than your %d slot bag"], weakest.size)
  end
  return verdict(Keep.BAG_PROFESSION, slots, true, words, weakest.size)
end

-- Brief K14 (ruling 2): a profession bag fits a normal bag slot and the reagent bag slot, so it is
-- worth keeping when it would be kept for either place. Only for the character's trades (BQ25c);
-- then the reagent slot's answer (reagentVerdict) where it keeps, else the normal slots' where they
-- keep. Brief BG4 (the owner's QA of 2026-10-17, item 185: "this is worse than your current bag"):
-- where both places weighed it and neither keeps it, one line for both, "Worse than your current
-- bags" (was the reagent slot's "Your reagent bag slot holds a reagent bag"), weighed against the
-- reagent slot's bag; where one place alone weighed it (a client with no reagent slot, or no bag in
-- a normal slot it could replace), that place's words.
local function professionVerdict(family, slots, state, professions)
  if not bagForTrades(family, professions) then
    return verdict(Keep.BAG_PROFESSION, slots, false, L["Not for your professions"])
  end
  local reagent = reagentVerdict(Keep.BAG_PROFESSION, family, slots, state, professions)
  if reagent and reagent.keep then
    return reagent
  end
  local normal = professionSlotsVerdict(slots, state)
  if normal and normal.keep then
    return normal
  end
  if normal == nil or reagent == nil then
    return normal or reagent
  end
  return verdict(Keep.BAG_PROFESSION, slots, false, L["Worse than your current bags"], reagent.against)
end

-- The bag rule's answer before the spare bag rule: the upgrade test, like compared with like.
-- required and level (a quiver's or pouch's required level and the character's) are QA item 153's.
local function upgradeVerdict(kind, family, slots, speed, state, classId, professions, ranged, required, level)
  if kind == Keep.BAG_NORMAL then
    return normalVerdict(slots, state)
  elseif kind == Keep.BAG_QUIVER or kind == Keep.BAG_POUCH then
    return ammoVerdict(kind, slots, speed, state, classId, ranged, required, level)
  elseif kind == Keep.BAG_SOUL then
    return soulVerdict(slots, state, classId)
  elseif kind == Keep.BAG_PROFESSION then
    return professionVerdict(family, slots, state, professions)
  end
  return reagentVerdict(kind, family, slots, state, professions, required, level)
end

--------------------------------------------------------------------------------
-- Brief BG1 (QA item 83 as revised by the owner on 2026-10-13, his seven answers): the spare bag rule.
--   1. A bag of SPARE_BAG_MIN slots or more that is no upgrade for the worn set is a spare: [Keep]
--      "Useful for bank and alts", or "Useful for your bank" where it cannot be mailed (bound on
--      pickup, a quest item).
--   2. Its tags are the Keep, Vendor PAIR: [Keep] then the item's own sale verdict beside it (Keep.Tags).
--   3. The CAP: at most the bank's bag slots with every slot bought (state.bankMax, the client's
--      count, else BANK_BAG_SLOTS) spares are kept, counting the spares carried and, where the bank
--      is known, those stored in it. The biggest keep (then the lower item id); the rest read the
--      ordinary sale verdict.
--   4. The bank read, where the bank is known (state.bank, read at the bank and held for the
--      session): a normal bag that would fill an empty BOUGHT bank bag slot reads "Fills an empty
--      bank slot", one bigger than the smallest bank bag "Bigger than your bank bag"; these outrank 1.
--   5. QA item 153 (the owner, 2026-10-14: "A quiver SHOULD NEVER read 'useful for your bank'. Only
--      compare quivers with your currently equipped/available to equip quiver"): a quiver or ammo
--      pouch is NEVER a spare. It is judged only against the one worn (the upgrade test: [Equip],
--      or [Keep] until its level for one the character cannot wear yet); anything else reads the
--      ordinary sale verdict by class (his ruling 83.5), bound or not, with no bank words. This
--      replaces BG1's spare quiver for a class that shoots.
--   7. A bag that beats a worn one is an upgrade, [Equip] (the 10 October ruling), never a spare.
-- Soul, reagent and profession bags keep their own rule (no spare keep). Brief F160 held whether a
-- plain reagent bag can be a bank bag in one constant for the owner's word; brief RB5 (QA item 206,
-- the owner on 2026-10-17: "No it can't", tested in game) settles it for good: a reagent bag never
-- goes in a bank bag slot, so it is out of the spare rule, the cap and the bank read, and nothing
-- ever calls a spare reagent bag useful for the bank (Keep.BankableKind: a normal bag only).
--------------------------------------------------------------------------------

Keep.SPARE_BAG_MIN = 6
-- The bank's bag slots with every slot bought, where the client does not say (Keep.BankMax reads
-- C_Bank.FetchMaxNumBankTabs less the bank's own first tab on the Forever client).
Keep.BANK_BAG_SLOTS = 7
Keep.SPARE_ALTS = "bankAlts"
Keep.SPARE_BANK = "bank"
Keep.SPARE_BANK_SLOT = "bankSlot"
Keep.SPARE_BANK_BIGGER = "bankBigger"

--- Brief BG1: the words for a spare bag's reason (Keep.SPARE_ALTS and the rest). Pure.
function Keep.SpareBagWords(reason)
  if reason == Keep.SPARE_BANK_SLOT then
    return L["Fills an empty bank slot"]
  elseif reason == Keep.SPARE_BANK_BIGGER then
    return L["Bigger than your bank bag"]
  elseif reason == Keep.SPARE_BANK then
    return L["Useful for your bank"]
  end
  return L["Useful for bank and alts"]
end

-- Brief F160: whether a bag of this kind can be a bank bag the spare rule weighs: a normal bag only.
-- Brief RB5 (QA item 206, the owner's "No it can't" of 2026-10-17): never a reagent bag, for good (F160's
-- Keep.REAGENT_BAG_BANK switch is gone), nor a quiver, pouch, soul or profession bag. Pure.
function Keep.BankableKind(kind)
  return kind == Keep.BAG_NORMAL
end

-- Whether a bag of this kind and size can be a spare (rules 1 and 5): a normal bag only (brief RB5,
-- QA item 206: never a reagent bag). QA item 153: never a quiver or ammo pouch, whatever the class.
local function spareKind(kind, slots)
  if (tonumber(slots) or 0) < Keep.SPARE_BAG_MIN then
    return false
  end
  return Keep.BankableKind(kind)
end

--- Brief BG1: the spare bags the cap counts, carried and stored in the bank (state.carried and
--- state.stored), each { itemId, size }: those of a spare kind for the class that are no upgrade.
--- Pure.
function Keep.SparePool(state, classId, ranged)
  local pool = {}
  if type(state) ~= "table" or type(state.slots) ~= "table" then
    return pool
  end
  for _, list in ipairs({ state.carried, state.stored }) do
    for _, entry in ipairs(type(list) == "table" and list or EMPTY) do
      if entry.itemId and spareKind(entry.kind, entry.size) then
        local base = upgradeVerdict(entry.kind, entry.family, entry.size, entry.speed or 0, state, classId, nil, ranged)
        if not (type(base) == "table" and base.keep == true) then
          pool[#pool + 1] = { itemId = entry.itemId, size = entry.size }
        end
      end
    end
  end
  return pool
end

--- Brief BG1: how many copies of itemId (slots each) the cap keeps, the spares kept in all, and the
--- cap: the pool ranked biggest first, then by item id; an item with no copy in the pool (a link, a
--- loot roll) counts as one more copy. Pure.
function Keep.SpareCap(pool, itemId, slots, max)
  local id = tonumber(itemId) or 0
  slots = tonumber(slots) or 0
  max = math.max(0, math.floor(tonumber(max) or Keep.BANK_BAG_SLOTS))
  local before, copies, total = 0, 0, 0
  for _, entry in ipairs(type(pool) == "table" and pool or EMPTY) do
    total = total + 1
    local size, other = tonumber(entry.size) or 0, tonumber(entry.itemId) or 0
    if other == id and size == slots then
      copies = copies + 1
    elseif size > slots or (size == slots and other < id) then
      before = before + 1
    end
  end
  if copies == 0 then
    copies, total = 1, total + 1
  end
  local kept = math.max(0, math.min(copies, max - before))
  return kept, math.min(total, max), max
end

-- Rule 4: the bank read for a normal bag, or nil (the bank not known, no word). Brief RB5 (QA item
-- 206): never for a reagent bag, which no bank bag slot takes.
local function bankReason(kind, slots, state)
  local bank = type(state.bank) == "table" and state.bank or nil
  if not Keep.BankableKind(kind) or bank == nil then
    return nil
  end
  local smallest = nil
  for _, slot in ipairs(bank.slots or EMPTY) do
    local size = tonumber(slot.size) or 0
    if size <= 0 then
      return Keep.SPARE_BANK_SLOT
    end
    if Keep.BankableKind(slot.kind) and (smallest == nil or size < smallest) then
      smallest = size
    end
  end
  if smallest ~= nil and slots > smallest then
    return Keep.SPARE_BANK_BIGGER
  end
  return nil
end

--- Brief BG1: the spare bag rule over the upgrade test's answer (base, no keep): the spare verdict {
--- kind, slots, keep = true, spare = true, reason, words, against, speed, cap = { kept, max, copies }
--- }, or base with its cap where the cap leaves this one out, or base alone where the bag is no spare.
--- bound is true for a bag that cannot be mailed. Pure.
function Keep.SpareBagVerdict(base, kind, slots, bound, state, classId, ranged, itemId)
  if type(base) ~= "table" or base.keep == true or not spareKind(kind, slots) then
    return base
  end
  local pool = Keep.SparePool(state, classId, ranged)
  local copies, kept, max = Keep.SpareCap(pool, itemId, slots, tonumber(state.bankMax) or Keep.BANK_BAG_SLOTS)
  local cap = { kept = kept, max = max, copies = copies }
  if copies <= 0 then
    base.cap = cap
    return base
  end
  local reason = bankReason(kind, slots, state)
  if reason == nil then
    if bound then
      reason = Keep.SPARE_BANK
    else
      reason = Keep.SPARE_ALTS
    end
  end
  local spare = verdict(kind, slots, true, Keep.SpareBagWords(reason), base.against, base.speed)
  spare.spare, spare.reason, spare.cap = true, reason, cap
  return spare
end

--- The bag rule's answer for an item row: { kind, slots, keep, words, against, speed }, keep true for
--- a Keep and false for [Vendor] (its words then said muted), against the slots it was weighed
--- against (0 for an empty slot, nil where it was not weighed), speed a quiver's or pouch's ranged
--- attack speed. nil for an item that is no bag, a bag whose slots the row does not state, or no
--- bag state (state, Keep.BagState's). classId is the player's, professions their set of skill
--- lines, ranged the worn ranged weapon's row ({ c, sc }) or nil. Brief BG1: itemId ranks a spare
--- among the spare bags (Keep.SpareBagVerdict: spare, reason and cap join the answer); keep true
--- with spare nil is an upgrade, [Equip]. QA item 153: level is the character's; a quiver or pouch
--- upgrade the row's required level puts above it answers later = that level, a [Keep] until then
--- (Keep.BagLater), not [Equip]. Pure.
function Keep.BagFacts(row, state, classId, professions, ranged, itemId, level)
  local kind, family = Keep.BagKind(row)
  local slots = type(row) == "table" and tonumber(row.cs) or nil
  if kind == nil or slots == nil or slots <= 0 or type(state) ~= "table" or type(state.slots) ~= "table" then
    return nil
  end
  local speed = Keep.BagSpeed(row)
  local base = upgradeVerdict(kind, family, slots, speed, state, classId, professions, ranged, row.rl, level)
  local bound = Keep.UNTRADABLE[tonumber(row.b) or 0] == true
  return Keep.SpareBagVerdict(base, kind, slots, bound, state, classId, ranged, itemId)
end

--- Brief BG1 (item 83's first half, the 10 October ruling): whether the bag rule answers an upgrade,
--- worn as [Equip] like a gear upgrade. QA item 153: not one the character cannot wear yet
--- (Keep.BagLater), which is a [Keep]. Pure.
function Keep.BagUpgrade(score)
  local bag = type(score) == "table" and score.bag or nil
  return type(bag) == "table" and bag.keep == true and bag.spare ~= true and tonumber(bag.later) == nil
end

--- QA item 153: the level a quiver or pouch upgrade the character cannot wear yet is kept until, or
--- nil. Pure.
function Keep.BagLater(score)
  local bag = type(score) == "table" and score.bag or nil
  if type(bag) ~= "table" or bag.keep ~= true then
    return nil
  end
  return tonumber(bag.later)
end

--- Brief BG1: whether the bag rule keeps the score's item as a spare (the Keep, Vendor pair). Pure.
function Keep.BagSpare(score)
  local bag = type(score) == "table" and score.bag or nil
  return type(bag) == "table" and bag.keep == true and bag.spare == true
end

--- Brief BG1: the score with the spare keep left out (its bag rule answer no keep), for the sale
--- tags beside the pair. A shallow copy. Pure.
function Keep.BagFree(score)
  local copy = {}
  for key, value in pairs(type(score) == "table" and score or EMPTY) do
    copy[key] = value
  end
  if type(copy.bag) == "table" then
    local bag = {}
    for key, value in pairs(copy.bag) do
      bag[key] = value
    end
    bag.keep = false
    copy.bag = bag
  end
  return copy
end

--- Whether the bag rule keeps the score's item (score.bag, Keep.BagFacts). Pure.
function Keep.BagKeeps(score)
  return type(score) == "table" and type(score.bag) == "table" and score.bag.keep == true
end

--------------------------------------------------------------------------------
-- Brief K31 (feedback item 144 and the owner's rulings of 2026-10-13: "it is a skinning tool",
-- "which I should keep but not to equip", "you probably need to keep at least one profession
-- tool", "related to your professions", "if there's 10 then we just want to keep the best one"):
-- PROFESSION TOOLS. An item in the shared tools list (Data/curated/Tools.lua, the same ids and
-- skill lines as Jettison's Data/Tools.lua; a fishing pole by its weapon subclass too) is never
-- judged as gear: no gear compare, no Equip tag, no "Not an upgrade". For a profession the player
-- has (Keep.IsOwnSkill over the professions read; Fishing only for a player who fishes, as the read
-- lists it only then) the BEST such tool the player carries keeps: [Keep] "Skinning tool". Best is
-- the tool's own skill bonus (a fishing pole's +Fishing, from its stats and equip effects), then
-- item level, then quality; among identical copies the one in a profession bag of its trade (brief
-- F160, item 165: the owner's two Skinning Knives, the one in his Apprentice's Skinning Satchel is the
-- kept one, the new one in the backpack the spare), then a general bag's (brief RB5, item 200: a copy
-- in any other bag is misplaced and comes after), then the lowest bag and slot (Keep.ToolHome). Every other
-- carried copy reads its ordinary sale verdict with the muted line "Spare Skinning tool". A tool
-- for a profession the player lacks reads its ordinary sale verdict with the muted line "Tool for
-- Mining" (Jettison's words). The keep sits above any sale (K21).
--   score.tool  Keep.ToolFacts: { skill, skills, own, name }, held with the score (the professions
--               are part of the cache key)
--   env.tool    which copy is kept, per bag slot (Keep.ToolFor on the client: { best, skill, bag,
--               slot }); nil (no bag read: a spec, the invariants) counts as the best one
--------------------------------------------------------------------------------

Keep.KEEP_TOOL = "tool"
Keep.FISHING = 356
Keep.WEAPON_CLASS = 2
Keep.FISHING_POLE_SUBCLASS = 20
-- The stat code a tool's skill bonus is stated in (the pipeline's ITEM_MOD codes: Herbalism 112,
-- Mining 113, Skinning 114, Fishing 117), by the skill line it raises.
Keep.TOOL_SKILL_STATS = { [182] = 112, [186] = 113, [393] = 114, [356] = 117 }
-- Where a copy with no bag slot (one not carried, a pretend one) sorts: after every real slot.
Keep.TOOL_NO_SLOT = 1000000

--- The skill lines a tool serves, as a list, or nil for an item that is no tool: its entry in the
--- shared list (ItemTree.CuratedTools), else Fishing for a fishing pole by its weapon subclass.
--- row is the item's shipped row (nil: the list alone). Pure over the list.
function Keep.ToolSkills(itemId, row)
  local tools = ItemTree.CuratedTools
  local entry = type(tools) == "table" and tools[tonumber(itemId) or -1] or nil
  if type(entry) == "table" then
    return entry
  end
  if tonumber(entry) then
    return { tonumber(entry) }
  end
  if
    type(row) == "table"
    and tonumber(row.c) == Keep.WEAPON_CLASS
    and tonumber(row.sc) == Keep.FISHING_POLE_SUBCLASS
  then
    return { Keep.FISHING }
  end
  return nil
end

--- The tool facts for an item and the player's professions (a set of skill line ids), or nil for an
--- item that is no tool: { skill, skills, own, name }. skill is the first line it serves that is the
--- player's (own true), else the first it serves (own false); name the profession's name. Pure over
--- the list and the data tables.
function Keep.ToolFacts(itemId, row, professions)
  local skills = Keep.ToolSkills(itemId, row)
  if type(skills) ~= "table" or #skills == 0 then
    return nil
  end
  local skill, own = tonumber(skills[1]), false
  for _, line in ipairs(skills) do
    if Keep.IsOwnSkill(tonumber(line), professions) then
      skill, own = tonumber(line), true
      break
    end
  end
  local list = {}
  for index, line in ipairs(skills) do
    list[index] = tonumber(line)
  end
  return { skill = skill, skills = list, own = own, name = skillName(skill) }
end

local function addBonus(list, code)
  local sum = 0
  if type(list) ~= "table" then
    return sum
  end
  for _, pair in ipairs(list) do
    if type(pair) == "table" and tonumber(pair[1]) == code then
      sum = sum + (tonumber(pair[2]) or 0)
    end
  end
  return sum
end

--- A tool's own bonus to the skill line it serves (a fishing pole's +Fishing), from the row's stats
--- and its equip effects (es), 0 for none. Pure.
function Keep.ToolBonus(row, skill)
  local code = Keep.TOOL_SKILL_STATS[tonumber(skill) or -1]
  if code == nil or type(row) ~= "table" then
    return 0
  end
  return addBonus(row.stats, code) + addBonus(row.es, code)
end

-- Brief F160 (item 165): where a tool copy sits, best first.
Keep.TOOL_HOME_TRADE = 2
Keep.TOOL_HOME_GENERAL = 0
-- Brief RB5 (QA item 200, the owner's ruling of 2026-10-17: "You can't actually put tools into
-- reagent satchels", only a client swap bug rotates one in; the coordinator's follow up: the client
-- takes a tool only in a general bag or its own trade's profession bag): a copy in any other bag (a
-- reagent bag, a quiver, an ammo pouch, a soul bag, another trade's profession bag) is misplaced,
-- below a general bag's copy and above a copy in no bag. F160's TOOL_HOME_SPECIAL (1, any bag that
-- is no general bag, ranked above a general bag) is gone.
Keep.TOOL_HOME_MISPLACED = -0.5
Keep.TOOL_HOME_NONE = -1

-- Whether a bag family bit holds the goods of the skill line's trade (Keep.BAG_FAMILY_TRADES).
local function familyHolds(family, skill)
  family = tonumber(family) or 0
  if family <= 0 then
    return false
  end
  for bit, trades in pairs(Keep.BAG_FAMILY_TRADES) do
    if family % (bit * 2) >= bit then
      for _, line in ipairs(trades) do
        if line == tonumber(skill) then
          return true
        end
      end
    end
  end
  return false
end

--- Brief F160 (owner QA 2026-10-14, item 165: two Skinning Knives, the new one in the backpack read
--- Keep "Skinning tool" and the old one in his Apprentice's Skinning Satchel read Vendor "Spare
--- Skinning tool"): where a copy of a tool for skill sits, for the tie between identical copies:
--- TOOL_HOME_TRADE in a profession bag whose family holds that trade's goods (the knife in a
--- skinning bag), TOOL_HOME_GENERAL in a general bag or the backpack (or a bag the client would not
--- name), TOOL_HOME_MISPLACED in any other bag (brief RB5, QA item 200: a reagent bag, a quiver, an
--- ammo pouch, a soul bag, another trade's profession bag; the client refuses a tool there and only
--- its swap bug puts one in, so the copy in a real home is the one kept), TOOL_HOME_NONE for a copy
--- in no bag. bag is the container (nil for none), kind and family the bag item's (Keep.BagKind; nil
--- for the backpack). Pure.
function Keep.ToolHome(skill, bag, kind, family)
  if tonumber(bag) == nil then
    return Keep.TOOL_HOME_NONE
  end
  if kind == nil or kind == Keep.BAG_NORMAL then
    return Keep.TOOL_HOME_GENERAL
  end
  if kind == Keep.BAG_PROFESSION and familyHolds(family, skill) then
    return Keep.TOOL_HOME_TRADE
  end
  return Keep.TOOL_HOME_MISPLACED
end

--- Whether tool copy a ranks above copy b, each { id, bonus, il, q, home, bag, slot }: the skill
--- bonus, then item level, then quality, then (brief F160) where it sits (home, Keep.ToolHome: a
--- profession bag of its trade first, a copy with none last), then the lowest bag, then the lowest
--- slot (a copy with no slot last), then the lowest id. Pure.
function Keep.ToolBetter(a, b)
  local function n(value, default)
    return tonumber(value) or default
  end
  if n(a.bonus, 0) ~= n(b.bonus, 0) then
    return n(a.bonus, 0) > n(b.bonus, 0)
  end
  if n(a.il, 0) ~= n(b.il, 0) then
    return n(a.il, 0) > n(b.il, 0)
  end
  if n(a.q, 0) ~= n(b.q, 0) then
    return n(a.q, 0) > n(b.q, 0)
  end
  local none = Keep.TOOL_HOME_NONE
  if n(a.home, none) ~= n(b.home, none) then
    return n(a.home, none) > n(b.home, none)
  end
  local far = Keep.TOOL_NO_SLOT
  if n(a.bag, far) ~= n(b.bag, far) then
    return n(a.bag, far) < n(b.bag, far)
  end
  if n(a.slot, far) ~= n(b.slot, far) then
    return n(a.slot, far) < n(b.slot, far)
  end
  return n(a.id, 0) < n(b.id, 0)
end

--- One tool copy as Keep.ToolBetter weighs it for a skill line: { id, bonus, il, q, home, bag, slot
--- }. Brief F160: bagKind and bagFamily are its bag's (Keep.BagKind of the bag item, nil for the
--- backpack or a bag not named), for home (Keep.ToolHome). Pure.
function Keep.ToolCopy(itemId, row, skill, bag, slot, bagKind, bagFamily)
  row = type(row) == "table" and row or EMPTY
  return {
    id = tonumber(itemId),
    bonus = Keep.ToolBonus(row, skill),
    il = tonumber(row.il) or 0,
    q = tonumber(row.q) or 0,
    home = Keep.ToolHome(skill, bag, bagKind, bagFamily),
    bag = tonumber(bag),
    slot = tonumber(slot),
  }
end

--- Which copy of a tool the player keeps for one skill line, and whether the copy asked about is it.
--- carried is the bag read, a list of { id, row, bag, slot, bagKind, bagFamily } (every listed tool the
--- player carries, whatever its profession; brief F160: bagKind and bagFamily its bag's, nil where not
--- known); itemId and row the copy asked about, bag and slot its bag slot (nil
--- where none is known: the API, a vendor's or a link's item). A copy with a slot is found among the
--- carried ones by it; one with none is the carried copy of that id that ranks first, or, where the
--- player carries none of that id, a copy not carried, which wins only over a worse one. Answers
--- best (true where the copy asked about is the one kept), and the kept copy (nil for none). Pure.
function Keep.ToolPick(carried, skill, itemId, row, bag, slot)
  local id = tonumber(itemId)
  local best, mine = nil, nil
  for _, held in ipairs(type(carried) == "table" and carried or EMPTY) do
    local skills = type(held) == "table" and Keep.ToolSkills(held.id, held.row) or nil
    local serves = false
    for _, line in ipairs(skills or EMPTY) do
      if tonumber(line) == skill then
        serves = true
      end
    end
    if serves then
      local copy = Keep.ToolCopy(held.id, held.row, skill, held.bag, held.slot, held.bagKind, held.bagFamily)
      if best == nil or Keep.ToolBetter(copy, best) then
        best = copy
      end
      if copy.id == id then
        if bag ~= nil and slot ~= nil then
          if copy.bag == tonumber(bag) and copy.slot == tonumber(slot) then
            mine = copy
          end
        elseif mine == nil or Keep.ToolBetter(copy, mine) then
          mine = copy
        end
      end
    end
  end
  if mine == nil then
    -- Not among the carried copies: weighed as one more, after every real slot on a tie.
    mine = Keep.ToolCopy(id, row, skill, bag, slot)
    if bag == nil or slot == nil then
      mine.bag, mine.slot, mine.home = nil, nil, Keep.TOOL_HOME_NONE
    end
    if best == nil or Keep.ToolBetter(mine, best) then
      return true, nil
    end
    return false, best
  end
  return best == mine, best
end

--- What env.tool holds for one copy: { best, skill, bag, slot } over the bag read (Keep.ToolPick
--- for each of the player's professions the tool serves; best where it is the kept copy for any of
--- them, skill the profession it is kept for, else the first own one; bag and slot the kept copy's
--- for that skill, nil where it is the copy asked about and not carried). nil for a tool of no
--- profession the player has, or an item that is no tool. Pure over its arguments.
function Keep.ToolAnswer(facts, carried, itemId, row, bag, slot, professions)
  if type(facts) ~= "table" or not facts.own then
    return nil
  end
  local answer = nil
  for _, skill in ipairs(facts.skills or EMPTY) do
    if Keep.IsOwnSkill(skill, professions) then
      local best, kept = Keep.ToolPick(carried, skill, itemId, row, bag, slot)
      local entry = { best = best == true, skill = skill }
      if type(kept) == "table" then
        entry.bag, entry.slot = kept.bag, kept.slot
      end
      if best then
        return entry
      end
      answer = answer or entry
    end
  end
  return answer
end

--- Whether a score's tool is one of the player's professions' and this copy is not the one kept
--- (env.tool, Keep.ToolFor's answer: best false). Pure.
function Keep.ToolSpare(score, env)
  local tool = type(score) == "table" and score.tool or nil
  if type(tool) ~= "table" or not tool.own then
    return false
  end
  local held = type(env) == "table" and env.tool or nil
  return type(held) == "table" and held.best == false
end

--- Whether the tool rule keeps the copy: a tool of one of the player's professions that is the
--- best one carried (env.tool), or with no bag read at all. Pure.
function Keep.ToolKeeps(score, env)
  local tool = type(score) == "table" and score.tool or nil
  if type(tool) ~= "table" or not tool.own then
    return false
  end
  return not Keep.ToolSpare(score, env)
end

--- The profession a tool line names: the env's kept skill (the profession the copy is kept or
--- spare for), else the score's. Pure over the data tables.
function Keep.ToolName(score, env)
  local tool = type(score) == "table" and score.tool or nil
  if type(tool) ~= "table" then
    return nil
  end
  local held = type(env) == "table" and env.tool or nil
  local skill = type(held) == "table" and tonumber(held.skill) or nil
  if skill and skill ~= tool.skill then
    return skillName(skill) or tool.name
  end
  return tool.name
end

--- Brief K31: a view of the score for a spare tool's ordinary verdict: the tool's own keep and the
--- player's own trade uses left out (Keep.TradeFree's view), so a spare Blacksmith Hammer reads
--- what a vendor or the auction house pays. Pure.
function Keep.ToolFree(score)
  local view = Keep.TradeFree(score)
  view.tool = nil
  view.toolSpare = true
  return view
end

-- row is the shipped item row, classId and level the player's, rankOf(skillLine) the player's
-- rank in a skill or nil (a function, so the ranks are read only for an item that needs one).
-- Brief K26: effect is Keep.FoodEffect's answer for the row and maxLevel the level cap (MAX_LEVEL
-- unless given): a food or drink with a buff (FOOD_EFFECT) is a soft keep at every level below
-- the cap (the owner's "+5% rested experience is good at all levels"), its own level only capped
-- by the look ahead; at the cap the level window applies to it as to plain food, so the high
-- level buff food is kept (and auctioned, Keep.KindCounts) and the low level one sold. Brief
-- K25f: a skill on a child line is met by the rank in its parent (Consumables.RankIn). Pure over
-- its arguments and the data tables.
function Keep.CouldUse(row, classId, level, rankOf, effect, maxLevel)
  if type(row) ~= "table" or tonumber(row.c) ~= Keep.CONSUMABLE_CLASS then
    return false
  end
  level = tonumber(level)
  if level == nil then
    return false
  end
  local classes = Keep.MaskClasses(row.ac)
  if #classes > 0 and (tonumber(classId) == nil or not Keep.MaskHasClass(row.ac, classId)) then
    return false
  end
  local skill = tonumber(row.sk)
  if skill and skill > 0 then
    local need = tonumber(row.skr) or 0
    local have = nil
    -- Brief K25f: a child line (First Aid's 2942) is met by the rank in its parent (129, the line
    -- the client reports), through Consumables.RankIn where it is loaded.
    local consumables = ItemTree.Consumables
    if type(consumables) == "table" and type(consumables.RankIn) == "function" then
      have = consumables.RankIn(rankOf, skill)
    elseif type(rankOf) == "function" then
      local ok, answer = pcall(rankOf, skill)
      have = ok and tonumber(answer) or nil
    end
    if have == nil or have < need then
      return false
    end
  end
  local required = tonumber(row.rl)
  if required and required <= 0 then
    required = nil
  end
  if required and required > level + Keep.COULD_AHEAD then
    return false
  end
  -- Brief BQ6 (backlog 5): a profession's consumable (a lure, a device) the player can use at their
  -- rank is kept whatever its level.
  if Keep.ProfessionLine(skill) ~= nil then
    return true
  end
  if effect == Keep.FOOD_EFFECT and level < (tonumber(maxLevel) or Keep.MAX_LEVEL) then
    return true
  end
  local at = required or tonumber(row.il)
  if at == nil then
    return false
  end
  return level - at <= Keep.COULD_BEHIND
end

--------------------------------------------------------------------------------
-- Brief K20-wire: disenchanting (design K20 sections 1 to 3, K20e). Core/DisenchantValue.lua's
-- pure facts, put on the score as score.disenchant by Keep.Score, ONLY where the player has
-- Enchanting at the rank the item needs (the stand-in table, DisenchantValue.RequiredRank). The
-- owner's assumed answer to design question 5, to confirm: a player without Enchanting sees no
-- disenchant state and no disenchant line at all. The facts:
--   band      the shipped band (kept, so the value is worked again as the prices move)
--   rank, required   the player's Enchanting rank and the rank the item needs
--   copper    the expected value, DisenchantValue.Expected's (about, before the auction cut)
--   expected  DisenchantValue.Expected's whole answer (results, missing, likely)
--   keep      { id, name, words } the first likely result (chance DISENCHANT_LIKELY or more) that
--             is itself a Keep for this player, with the first reason it is ("14 x Enchanting")
--   at        when the value was worked out (DisenchantValue.Now)
-- Every chance is rough and the module is predicted, so every sum says "about".
--------------------------------------------------------------------------------

Keep.DISENCHANT_LIKELY = 0.2
Keep.ENCHANTING = 333

-- The disenchant facts for one shipped row, or nil: Core/DisenchantValue.lua not loaded, no
-- Enchanting (rank nil) or not enough, no band. priceOf(materialId) answers copper per unit or nil
-- (DisenchantValue.MaterialPrice: Prices.Auction, cached a minute); materialKeep(materialId)
-- answers whether that material is a Keep for this player and the words of its first reason.
-- module is the Disenchant module (nil: the shipped one). Pure over its arguments and the data.
function Keep.DisenchantFacts(row, rank, priceOf, materialKeep, module)
  local values = ItemTree.DisenchantValue
  if type(values) ~= "table" or type(values.Band) ~= "function" or type(values.Expected) ~= "function" then
    return nil
  end
  if type(values.CanDisenchant) ~= "function" or not values.CanDisenchant(row, rank) then
    return nil
  end
  local band = values.Band(row, module)
  if not band then
    return nil
  end
  local expected = values.Expected(band, priceOf, module)
  if type(expected) ~= "table" then
    return nil
  end
  local facts = {
    band = band,
    module = module,
    rank = tonumber(rank),
    required = values.RequiredRank(row),
    copper = tonumber(expected.copper) or 0,
    expected = expected,
  }
  if type(materialKeep) == "function" then
    for _, result in ipairs(expected.results or EMPTY) do
      if (tonumber(result.chance) or 0) >= Keep.DISENCHANT_LIKELY then
        local ok, keeps, words = pcall(materialKeep, result.id)
        if ok and keeps then
          facts.keep = { id = result.id, name = result.name }
          if type(words) == "string" and words ~= "" then
            facts.keep.words = words
          end
          break
        end
      end
    end
  end
  return facts
end

-- Works a held score's disenchant value again with the material prices of now, at most once every
-- DisenchantValue.REFRESH_SECONDS (the material prices are held that long anyway), so a bag pass
-- over held scores costs a table read per item. Answers whether it worked it again.
function Keep.RefreshDisenchant(score)
  local facts = type(score) == "table" and score.disenchant or nil
  local values = ItemTree.DisenchantValue
  if type(facts) ~= "table" or type(facts.band) ~= "table" or type(values) ~= "table" then
    return false
  end
  if type(values.Now) ~= "function" or type(values.MaterialPrice) ~= "function" then
    return false
  end
  local at = tonumber(values.Now()) or 0
  if facts.at ~= nil and at - facts.at < (tonumber(values.REFRESH_SECONDS) or 60) then
    return false
  end
  local expected = values.Expected(facts.band, values.MaterialPrice, facts.module)
  facts.at = at
  if type(expected) ~= "table" then
    return false
  end
  facts.expected = expected
  facts.copper = tonumber(expected.copper) or 0
  return true
end

-- The disenchant sum after the auction house's cut, in whole copper, or nil where the player cannot
-- disenchant the item or no material has a price. Pure.
function Keep.DisenchantNet(score)
  local facts = type(score) == "table" and score.disenchant or nil
  local copper = type(facts) == "table" and tonumber(facts.copper) or nil
  if copper == nil or copper <= 0 then
    return nil
  end
  return math.floor(copper * Keep.AUCTION_CUT)
end

-- Step 4: whether the item is a Keep (disenchant): a likely result the player uses, unless the net
-- auction price reaches the Keep value (design question 6, assumed). settings are the saved ones
-- unless given. Pure.
function Keep.DisenchantKeeps(score, settings)
  local facts = type(score) == "table" and score.disenchant or nil
  if type(facts) ~= "table" or type(facts.keep) ~= "table" then
    return false
  end
  return not Keep.SellOutranksDisenchant(score, Keep.ValueThreshold(settings))
end

-- Brief K22: the current uses the mark counts, the player's own (score.ownCurrent), never more
-- than current (a score whose current was set by hand), or every current use for a score that
-- does not carry the field (one built by hand). Pure.
function Keep.Counted(score)
  if type(score) ~= "table" then
    return 0
  end
  local current = tonumber(score.current) or 0
  local own = tonumber(score.ownCurrent)
  if own ~= nil and own < current then
    return own
  end
  return current
end

-- Brief K22: whether an endgame use counts towards the mark, as Keep.Counted. Pure.
function Keep.CountedEndgame(score)
  if type(score) ~= "table" or score.endgame ~= true then
    return false
  end
  return score.ownEndgame ~= false
end

-- Brief K22: whether a score that is not marked has lines worth saying under "No need to keep":
-- current uses the mark does not count (another profession's recipes), or item combines listed
-- muted where no use is current or stale. Pure.
function Keep.OthersOnly(score)
  if type(score) ~= "table" then
    return false
  end
  local current = tonumber(score.current) or 0
  if current > Keep.Counted(score) then
    return true
  end
  local combines = type(score.combines) == "table" and #score.combines or 0
  local quiet = (tonumber(score.stale) or 0) == 0 and (tonumber(score.done) or 0) == 0
  return current == 0 and quiet and combines > 0
end

--------------------------------------------------------------------------------
-- The cache: one score per item and player level, side, class and professions, all dropped
-- together when any of them moves, when the data changes, or when a quest is turned in (brief
-- K1). Pure, the caller hands the player facts in; a caller that hands no class, professions or
-- completed predicate in gets Keep.PlayerClass, Keep.PlayerProfessions and Keep.QuestCompleted,
-- the client reads below the divider.
--------------------------------------------------------------------------------

Keep.cache = {}
Keep.cacheKey = nil
-- Brief K20-wire: the disenchant materials' own scores (Keep.DisenchantFacts asks whether a likely
-- result is a Keep), held with the cache and dropped with it.
Keep.materialScores = {}

-- Brief OPT3 (F11): the parts Keep.cacheKey was last built from, so a call whose parts are all
-- unchanged reuses the key string instead of building it (and the profession signature) again.
-- The profession signature is held against the set it was worked out from, by identity: the set
-- Keep.PlayerProfessions answers is a new table on every read, and it is read again only on
-- SKILL_LINES_CHANGED or after Keep.Reset, so a new set (a profession learned or dropped) is a new
-- signature and the same set is the same one. Any other set a caller hands in is signed again on
-- every call, as before, because it may have been written to since.
local keyParts = { held = false }
local NO_ROUTE = {}
local signatureFor, signatureOf = nil, nil

local function forgetKeyParts()
  keyParts.level, keyParts.faction, keyParts.class = nil, nil, nil
  keyParts.professions, keyParts.route, keyParts.held = nil, nil, false
  keyParts.worn, keyParts.rank = nil, nil
  keyParts.specs = nil
  keyParts.bags = nil
  signatureFor, signatureOf = nil, nil
end

function Keep.Reset()
  Keep.cache = {}
  Keep.materialScores = {}
  Keep.cacheKey = nil
  Keep.playerClass = nil
  Keep.professions = nil
  Keep.professionsRead = false
  -- Brief TP1: the held set with the tracked professions joined (Keep.KeepProfessions).
  Keep.keptProfessions = nil
  Keep.completed = {}
  Keep.removed = {}
  Keep.questLogSeen = nil
  Keep.petEats = {}
  Keep.enabledSpecsHeld = nil
  -- Brief BQ18: the worn items watched for a carried upgrade go with the scores they were read from.
  Keep.outdoneWatch = {}
  -- Brief BQ25c: the held bag read.
  Keep.bagState = nil
  -- Brief K31: the tool rule's bag walk.
  Keep.toolWalk = nil
  Keep.toolWalkStale = false
  -- Brief BG1: the carried bag walk (the bank read stands for the session: Keep.ForgetBank).
  Keep.carriedBags = nil
  -- Brief AA-RB: the Toy Box answers (Keep.IsToy).
  Keep.toys = {}
  forgetKeyParts()
end

Keep.completed = {}

-- The set's ids sorted into one string, "164,186", or "-" for none, "?" for not known. Pure.
function Keep.ProfessionSignature(professions)
  if type(professions) ~= "table" then
    return "?"
  end
  local ids = {}
  for id, on in pairs(professions) do
    if on and type(id) == "number" then
      ids[#ids + 1] = id
    end
  end
  if #ids == 0 then
    return "-"
  end
  table.sort(ids)
  return table.concat(ids, ",")
end

-- Brief K28: rollLink, a link the caller read only for its random suffix roll (a bag slot's,
-- Baganator's): its roll keys the cache slot as link's does, and it is handed on as the link (to the
-- gear facts and the price read) only where it names a roll the module prices, so every other item
-- is scored and priced as with no link at all. link, where a caller hands one (the API), is used as
-- before whatever it names. Keep.RollKey runs once per call, here.
function Keep.CachedScore(itemId, playerLevel, playerFaction, playerClass, professions, completed, link, rollLink)
  local id = tonumber(itemId)
  if not id then
    return nil
  end
  -- Brief K24b (H): the owner's session only pretend level (/itemtree demo level), for the Keep
  -- rules only. The one seam every caller (tooltip, item page, bags, API) scores through; the
  -- level is part of the key, so setting it starts a new cache.
  if tonumber(Keep.demoLevel) then
    playerLevel = tonumber(Keep.demoLevel)
  end
  if playerClass == nil and type(Keep.PlayerClass) == "function" then
    playerClass = Keep.PlayerClass()
  end
  -- Brief TP1 (QA item 210, ruling A): the set scored with is the player's own professions and the
  -- ones the character tracks at a range (Keep.KeepProfessions); own keeps the player's own alone for
  -- the rules that ask what the character itself can do (the tool and bag rules), nil where nothing
  -- is tracked.
  local own = nil
  if professions == nil and type(Keep.PlayerProfessions) == "function" then
    professions = Keep.PlayerProfessions()
    local kept = Keep.KeepProfessions(professions)
    if kept ~= professions then
      own, professions = professions, kept
    end
  end
  if completed == nil and type(Keep.QuestCompleted) == "function" then
    completed = Keep.QuestCompleted
  end
  -- Brief PR4: the route's facts join the key only while the module is active, so the key is as
  -- it always was with the tab off. NO_ROUTE stands for "module off" among the key's parts.
  local model = Keep.ProfessionModel()
  local route = NO_ROUTE
  if model then
    route = "?"
    if type(model.CurrentSignature) == "function" then
      local ok, answer = pcall(model.CurrentSignature)
      if ok and answer ~= nil then
        route = answer
      end
    end
  end
  -- Brief K20-wire: what the player wears (Gear.WornState, its signature held beside the map) and
  -- the Enchanting rank (DisenchantValue.EnchantingRank, held until SKILL_LINES_CHANGED) join the
  -- key, each one held read per call.
  local worn, wornSig = Keep.WornFacts()
  local rank = Keep.EnchantingRank()
  -- Brief K27: the player's per character spec setting, held (Keep.EnabledSpecs), joins the key
  -- only while some spec is off, so the key is as it was for a player who never touched it.
  local enabledSpecs, specsSig = Keep.EnabledSpecs(playerClass)
  -- Brief BQ25c: the equipped bags (Keep.BagState, held until the bags or the demo move) join the key
  -- only where the client or the demo states them.
  local bagState = Keep.BagState()
  local bagSig = Keep.BagSignature(bagState)
  -- Brief OPT3 (F11): the key string is built only when one of its parts moved (keyParts).
  local key = Keep.cacheKey
  if
    not keyParts.held
    or key == nil
    or playerLevel ~= keyParts.level
    or playerFaction ~= keyParts.faction
    or playerClass ~= keyParts.class
    or professions ~= keyParts.professions
    or (type(professions) == "table" and not Keep.HeldProfessions(professions))
    or route ~= keyParts.route
    or wornSig ~= keyParts.worn
    or rank ~= keyParts.rank
    or specsSig ~= keyParts.specs
    or bagSig ~= keyParts.bags
  then
    local signature
    if type(professions) == "table" and professions == signatureFor then
      signature = signatureOf
    else
      signature = Keep.ProfessionSignature(professions)
      if type(professions) == "table" and Keep.HeldProfessions(professions) then
        signatureFor, signatureOf = professions, signature
      end
    end
    key = tostring(playerLevel) .. ":" .. tostring(playerFaction) .. ":" .. tostring(playerClass) .. ":" .. signature
    if route ~= NO_ROUTE then
      key = key .. ":route=" .. tostring(route)
    end
    -- Brief K20-wire: the worn gear and the Enchanting rank, only where they are known, so the key
    -- is as it was on a client (or a spec) with neither.
    if wornSig ~= nil then
      key = key .. ":worn=" .. wornSig
    end
    if rank ~= nil then
      key = key .. ":ench=" .. tostring(rank)
    end
    if specsSig ~= nil then
      key = key .. ":specs=" .. specsSig
    end
    if bagSig ~= nil then
      key = key .. ":bags=" .. bagSig
    end
    keyParts.level, keyParts.faction, keyParts.class = playerLevel, playerFaction, playerClass
    keyParts.professions, keyParts.route, keyParts.held = professions, route, true
    keyParts.worn, keyParts.rank = wornSig, rank
    keyParts.specs = specsSig
    keyParts.bags = bagSig
  end
  if key ~= Keep.cacheKey then
    Keep.cache = {}
    Keep.materialScores = {}
    Keep.cacheKey = key
  end
  -- Brief K28: a gear item whose link names a random suffix roll the module prices is held under
  -- its id and the roll's key ("14173/b12761", Keep.CacheSlot), every other score under its id
  -- alone as before, so two rolls of one id never share a verdict.
  local roll = Keep.RollKey(id, link or rollLink)
  if link == nil and roll ~= nil then
    link = rollLink
  end
  local slot = Keep.CacheSlot(id, roll)
  local held = Keep.cache[slot]
  if held ~= nil then
    -- Brief K9: the value is read again on every hit; Core/Prices.lua holds each answer for a
    -- minute, so this is a table read, and a new scan or a moved setting lands on the next draw.
    if type(held) == "table" then
      -- Brief K20-wire: the disenchant value too, at most once a minute (Keep.RefreshDisenchant).
      if held.disenchant ~= nil then
        Keep.RefreshDisenchant(held)
      end
      Keep.SetPrices(held, Keep.ItemPrices(id, link))
    end
    return held or nil
  end
  local scoreOpts = {
    professions = professions,
    -- Brief TP1: the player's own professions alone, where tracked ones joined professions.
    ownProfessions = own,
    completed = completed,
    -- Brief TB4: the quests this character took and dropped (Keep.QuestAbandoned).
    abandoned = Keep.QuestAbandoned,
    -- Brief IW1 (the owner's ruling 1B): the quests in this character's log, for a provided item.
    onQuest = Keep.QuestInLog,
    -- Brief RF375 (M1): whether the quest log's objectives want the item, for a finished one.
    logWants = Keep.LogWants,
    link = link,
    -- Brief K20-wire: the gear and disenchant facts' inputs, and the materials' scores held
    -- with this cache (Keep.materialScores, dropped with it).
    worn = worn,
    enchanting = rank,
    materialScores = Keep.materialScores,
    -- Brief K27: the specs the gear compare scores (nil: every spec of the class).
    enabledSpecs = enabledSpecs,
    -- Brief K22: the bag count of a via item, asked only for an item with an item combine use.
    carries = Keep.Carries,
    -- Brief K24b (B): the player's skill ranks, asked only for a consumable that needs one.
    skillRank = Keep.SkillRank,
    -- Brief K26: the level cap, for a food or drink with a buff.
    maxLevel = Keep.MaxLevel(),
    -- Brief K25: the player's pools and the bag read, asked only for an item the facts cover.
    pools = Keep.Pools,
    carriedConsumables = Keep.CarriedConsumables,
    -- Brief ST4 (G1): the mage's conjures, asked only for an item the facts cover.
    conjure = Keep.Conjured,
    -- Brief BQ25c: the equipped bags, for a bag's verdict.
    bags = bagState,
  }
  -- Brief PF1: a cold score is timed (summed) while /itprobe open traces an open; one read else.
  local score
  local trace = ItemTree.openTrace
  if trace then
    score = trace.Span("keep", nil, Keep.Score, id, playerLevel, playerFaction, playerClass, scoreOpts)
  else
    score = Keep.Score(id, playerLevel, playerFaction, playerClass, scoreOpts)
  end
  if score == nil then
    -- Not cached: the rows are not loaded yet, and the next pass after they are should score it.
    return nil
  end
  Keep.cache[slot] = score
  -- Brief K22: a verdict that rests on a carried via item is re-read when the bags change.
  if type(score) == "table" and type(score.viaCarried) == "table" then
    Keep.carryWatch[slot] = score
  end
  -- Brief WS1: and one that rests on whether a quest's starter is held or the quest is in the log.
  if type(score) == "table" and type(score.starterWatch) == "table" then
    Keep.starterWatch[slot] = score
  end
  -- Brief IW1: and one that rests on whether a provided item's quest is in the log (ruling 1B).
  if type(score) == "table" and type(score.providedWatch) == "table" then
    Keep.providedWatch[slot] = score
  end
  -- Brief RF375 (M1): and a finished one that rests on whether the quest log wants the item.
  if type(score) == "table" and type(score.logWatch) == "table" then
    Keep.logWatch[slot] = score
  end
  return score
end

-- Brief K28: the key a score is held under in Keep.cache: the item id alone, or, for a random
-- suffix roll, the id and the roll's key joined by "/" ("14173/b12761"). Pure.
function Keep.CacheSlot(itemId, roll)
  if type(roll) == "string" and roll ~= "" then
    return tostring(itemId) .. "/" .. roll
  end
  return itemId
end

-- Brief K28: the roll's key for an item and its link (Gear.SuffixStats), or nil: no link, an item
-- that is not weapon or armour, no module, or no roll the module prices. One table read for the
-- row and one held parse per link string, so a hit on the cache stays cheap.
function Keep.RollKey(itemId, link)
  if type(link) ~= "string" then
    return nil
  end
  local gear = ItemTree.Gear
  if type(gear) ~= "table" or type(gear.SuffixStats) ~= "function" then
    return nil
  end
  local row = itemRow(itemId)
  if type(row) ~= "table" or not Keep.EQUIPMENT_CLASSES[tonumber(row.c) or -1] then
    return nil
  end
  local ok, _, key = pcall(gear.SuffixStats, link, row)
  if ok and type(key) == "string" then
    return key
  end
  return nil
end

-- Brief K28: drops every held score of an item, its rolls' too (Keep.CacheSlot's "id/roll" keys).
function Keep.DropItemScores(itemId)
  local id = tonumber(itemId)
  if not id or type(Keep.cache) ~= "table" then
    return
  end
  Keep.cache[id] = nil
  local prefix = tostring(id) .. "/"
  for slot in pairs(Keep.cache) do
    if type(slot) == "string" and string.sub(slot, 1, #prefix) == prefix then
      Keep.cache[slot] = nil
    end
  end
end

-- Brief K22: the cached scores whose verdict rests on whether a via item is carried, by item id.
-- An entry whose score is no longer the cached one (the cache was dropped) is skipped and
-- forgotten by Keep.RecheckCarried.
Keep.carryWatch = {}

-- Brief WS1: the cached scores whose verdict rests on a quest's starter (score.starterWatch), by slot,
-- skipped and forgotten by Keep.RecheckStarters once the score is no longer the cached one.
Keep.starterWatch = {}

-- Brief IW1: the cached scores whose verdict rests on whether a provided item's quest is in the log
-- (score.providedWatch, ruling 1B), by slot, skipped and forgotten by Keep.RecheckProvided once the
-- score is no longer the cached one.
Keep.providedWatch = {}

-- Brief RF375 (M1): the cached scores of finished quest items whose verdict rests on whether the quest
-- log wants the item (score.logWatch), by slot, skipped and forgotten by Keep.RecheckLogWants once the
-- score is no longer the cached one.
Keep.logWatch = {}

-- Drops every cached score, and nothing else: a quest turned in (brief K1) moves which quest uses
-- count, and every item's score may hold one.
function Keep.DropScores()
  Keep.cache = {}
  Keep.materialScores = {}
  Keep.cacheKey = nil
  -- Brief K31: and the tool rule's bag walk (a pretend held item moved with the demo).
  Keep.toolWalk = nil
  forgetKeyParts()
end

--------------------------------------------------------------------------------
-- Words. Pure.
--------------------------------------------------------------------------------

local KIND_ORDER = { "recipe", "quest", "lock" }

-- Brief K11: the verdict is a block of lines, a head and then one line per reason, each reason
-- with a small glyph at its left. These are the glyphs, Assets keys, the same ones the tree rows
-- wear for each kind: the rolled scroll for a recipe no profession names (ICON_RECIPE_MARK), the
-- quest "!" (CAT_QUEST), the padlock (CAT_REQUIREMENT) and the class spell flame (ICON_SPELL_MARK).
-- A profession's recipes wear that profession's glyph (Assets.ForSkill).
Keep.KIND_ICONS = {
  recipe = "ICON_RECIPE_MARK",
  quest = "CAT_QUEST",
  lock = "CAT_REQUIREMENT",
  spell = "ICON_SPELL_MARK",
}
-- Brief K20-wire: the gear line's glyph, the chest piece the item level bands wear (no key of
-- its own yet).
Keep.GEAR_ICON = "ICON_BAND_2"
Keep.SKILL_ICON_FALLBACK = "CAT_NOTE"
-- Brief TB13: a chained use's line leads with the Item chain tab's linked rings, under a key of
-- its own in UI/Assets.lua so the art can change in one place.
Keep.CHAIN_ICON = "ICON_KEEP_CHAIN"

-- The colours, Theme keys read by whoever draws the lines. Brief K4: muted for the player's own
-- Never, which is their word and not a warning. The reasons in the tooltip's plain white, and
-- brief K6: muted under Never too. Brief W27/W28: a use that is not the player's (another
-- profession's recipes) is a muted line, the grey alone saying so, and the Keep setting's help
-- text says that another profession's recipes read grey. Brief K24b: the heads and their colours
-- are gone; each tag carries its own tint (Keep.TagRow).
Keep.MUTED_COLOR = "ITEMTREE_COLOR_TEXT_MUTED"
Keep.BODY_COLOR = "ITEMTREE_COLOR_QUALITY_COMMON"

-- The colour key for a verdict's reason lines under its head. Pure.
function Keep.BodyColor(tone)
  if tone == "never" then
    return Keep.MUTED_COLOR
  end
  return Keep.BODY_COLOR
end

-- Written out one literal at a time, so the locale sweep sees every key.
local function counted(kind, n)
  if kind == "recipe" then
    return n == 1 and L["1 recipe"] or string.format(L["%d recipes"], n)
  end
  if kind == "quest" then
    return n == 1 and L["1 quest"] or string.format(L["%d quests"], n)
  end
  return n == 1 and L["1 lock"] or string.format(L["%d locks"], n)
end

-- "a", "a and b", "a, b and c", or nil for no parts. Pure.
local function joined(parts)
  if #parts == 0 then
    return nil
  end
  if #parts == 1 then
    return parts[1]
  end
  local last = table.remove(parts)
  return string.format(L["%s and %s"], table.concat(parts, ", "), last)
end

-- The words with every colour escape and inline texture taken out, for the specs, a label or a
-- width measure. A non string answers nil. Pure.
function Keep.Plain(text)
  if type(text) ~= "string" then
    return nil
  end
  -- Brief TB13: and every inline texture or atlas escape with the space after it, so a chain
  -- line's profession glyphs leave plain words ("8 x Blacksmithing via Alchemy (Sulfuric Acid)").
  local plain = Keep.Uncoloured(text):gsub("|T[^|]*|t ?", ""):gsub("|A[^|]*|a ?", "")
  return plain
end

-- The words with every colour escape taken out and any inline texture left in, or nil for a non
-- string. Brief K20-core drew each verdict line in its body colour (Keep.VerdictLines); brief
-- TB13's chain line keeps its profession glyphs there, so only the colours go. Pure.
function Keep.Uncoloured(text)
  if type(text) ~= "string" then
    return nil
  end
  return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- "3 recipes and 1 quest", "2 recipes, 1 quest and 1 lock".
function Keep.CountWords(kinds)
  local parts = {}
  for _, kind in ipairs(KIND_ORDER) do
    local n = kinds and kinds[kind] or 0
    if n > 0 then
      parts[#parts + 1] = counted(kind, n)
    end
  end
  return joined(parts)
end

-- Brief K1: one profession's recipes. Brief TB5 (a player's feedback, 2026-10-05): "9 Tailoring
-- recipes" read like Tailoring level 9, so the count reads "9 x Tailoring" ("1 x Tailoring" for
-- one). Brief W28: the same words for a profession the player lacks; brief K11: its line is drawn
-- muted (Keep.ReasonLines), so the words carry no colour of their own. Pure.
function Keep.GroupWords(group)
  if type(group) ~= "table" or type(group.name) ~= "string" then
    return nil
  end
  local n = tonumber(group.count) or 0
  if n <= 0 then
    return nil
  end
  -- Brief TV1 (QA item 347b, the owner: "I would maybe expand the single mining line to the actual line
  -- instead of 1 x mining (keep the icon next to it still)"): a group of one recipe names that recipe
  -- as the graph names it ("Smelt Copper"), its glyph kept by the caller; "1 x Mining" where the graph
  -- names none.
  if n == 1 and type(group.first) == "string" then
    local Graph = ItemTree.Graph
    if type(Graph) == "table" and type(Graph.Name) == "function" then
      local ok, name = pcall(Graph.Name, group.first)
      if ok and type(name) == "string" and name ~= "" then
        return name
      end
    end
  end
  return string.format(L["%d x %s"], n, group.name)
end

-- Brief K18: the line for the recipes no profession names. The recipe's own shipped name where
-- they all share one ("Replace Supplies", or "Replace Supplies (2 recipes)" for two spells of that
-- name), else "1 other recipe" or "3 other recipes"; a bare "1 recipe" never shows. nil for none.
-- Pure.
function Keep.PlainWords(count, name)
  local n = tonumber(count) or 0
  if n <= 0 then
    return nil
  end
  if type(name) == "string" and name ~= "" then
    if n == 1 then
      return name
    end
    return string.format(L["%s (%d recipes)"], name, n)
  end
  if n == 1 then
    return L["1 other recipe"]
  end
  return string.format(L["%d other recipes"], n)
end

-- The name a class spell use is called by, from its target key, or nil. Pure over the graph.
local function spellName(target)
  local Graph = ItemTree.Graph
  if type(Graph) ~= "table" or type(Graph.Name) ~= "function" or type(target) ~= "string" then
    return nil
  end
  local ok, name = pcall(Graph.Name, target)
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- Brief P5b: "Used by your Water Breathing" for one class spell, "Used by 3 of your spells" for
-- more, or nil for none. Brief K11: a line of its own, so it starts with a capital. Pure.
function Keep.SpellWords(score)
  local spells = type(score) == "table" and score.spells or nil
  local n = type(spells) == "table" and #spells or 0
  if n == 0 then
    return nil
  end
  if n == 1 then
    local name = spellName(spells[1])
    if name then
      return string.format(L["Used by your %s"], name)
    end
  end
  return string.format(L["Used by %d of your spells"], n)
end

-- The class words for a list of class ids, "Shaman" or "Shaman and Mage". Pure.
local function classWords(classIds)
  local Graph = ItemTree.Graph
  local names = {}
  for _, classId in ipairs(classIds or EMPTY) do
    local info = nil
    if type(Graph) == "table" and type(Graph.ClassInfo) == "function" then
      info = Graph.ClassInfo(classId)
    end
    if info and info.name then
      names[#names + 1] = info.name
    end
  end
  if #names == 0 then
    return nil
  end
  if #names == 1 then
    return names[1]
  end
  local last = table.remove(names)
  return string.format(L["%s and %s"], table.concat(names, ", "), last)
end

--------------------------------------------------------------------------------
-- Words for briefs TB4, TB9 and TB10. Pure.
--------------------------------------------------------------------------------

-- Brief TB10: a class locked consumable's line wears the class trainer's glyph, the one the item
-- page's class spell category wears too.
Keep.KIND_ICONS.class = "CAT_TRAINER"

-- Brief TB10, TB14: a class by its ChrClasses id, singular as the item's own "Classes: Mage"
-- line has it, or nil for an id no playable class has. A locale word of its own, so the words
-- read the same where the client's class names are not there to ask. Written out one literal at
-- a time for the locale sweep. Pure.
function Keep.ClassName(classId)
  local id = tonumber(classId)
  if id == 1 then
    return L["Warrior"]
  elseif id == 2 then
    return L["Paladin"]
  elseif id == 3 then
    return L["Hunter"]
  elseif id == 4 then
    return L["Rogue"]
  elseif id == 5 then
    return L["Priest"]
  elseif id == 7 then
    return L["Shaman"]
  elseif id == 8 then
    return L["Mage"]
  elseif id == 9 then
    return L["Warlock"]
  elseif id == 11 then
    return L["Druid"]
  end
  return nil
end

-- Brief TB14: "Class: Mage" for one class, "Classes: Mage, Priest" for two or more, or nil for
-- none. Pure.
local function classLabel(classIds)
  local parts = {}
  for _, classId in ipairs(classIds or EMPTY) do
    local word = Keep.ClassName(classId)
    if word then
      parts[#parts + 1] = word
    end
  end
  if #parts == 0 then
    return nil
  end
  if #parts == 1 then
    return string.format(L["Class: %s"], parts[1])
  end
  return string.format(L["Classes: %s"], table.concat(parts, ", "))
end

-- Brief TB10, TB14 (the owner on Scroll: CWAL, 2026-10-05): a class locked consumable's use in
-- words: "Class: Mage (Comprehension 1)" where the row's required skill has a name and a rank,
-- "Class: Mage (Comprehension)" where it has no rank, "Class: Mage" where it has no skill,
-- "Classes: Mage, Priest (...)" for two or more. nil for anything else. Pure.
function Keep.ClassWords(use)
  if type(use) ~= "table" or use.kind ~= "class" then
    return nil
  end
  local who = classLabel(use.classIds)
  if not who then
    return nil
  end
  local skill = skillName(tonumber(use.reqSkill))
  local rank = whole(use.reqRank)
  if skill and rank then
    return string.format(L["%s (%s %d)"], who, skill, rank)
  end
  if skill then
    return string.format(L["%s (%s)"], who, skill)
  end
  return who
end

-- Brief TB10, TB14: the line a class locked consumable another class uses reads, in
-- Keep.ClassWords' shape with no skill: "Class: Mage", "Classes: Mage, Priest", or nil. Pure.
function Keep.ForClassesWords(classIds)
  return classLabel(classIds)
end

-- Brief TB4: why a finished quest use no longer counts, one line per reason: "Quest done" or
-- "3 quests done" for the quests the player has completed, "Quest abandoned" or "2 quests
-- abandoned" for the ones taken and dropped. Empty where none are. Pure.
-- Brief UL1 (the owner's design-5 of 2026-10-21, Huge Gnoll Claw: "1 quest (completed)" with the quest
-- mark's green tick): the qualifier in brackets, "1 quest (completed)", "3 quests (completed)", "1 quest
-- (abandoned)", the completed line led by the client's tick (ICON_CHECK, inline after the quest mark),
-- the one shape the uses line's "1 quest" with its tick and the folded "and 1 other quest (1
-- completed)" said differently (the uses line matrix's "Same thing, said differently").
function Keep.DoneLines(score)
  local lines = {}
  if type(score) ~= "table" then
    return lines
  end
  local dropped = tonumber(score.abandoned) or 0
  local finished = (tonumber(score.done) or 0) - dropped
  local tick = Keep.InlineGlyph(Keep.DONE_ICON)
  if finished == 1 then
    lines[#lines + 1] = { text = tick .. L["1 quest (completed)"], icon = Keep.KIND_ICONS.quest }
  elseif finished > 1 then
    lines[#lines + 1] = {
      text = tick .. string.format(L["%d quests (completed)"], finished),
      icon = Keep.KIND_ICONS.quest,
    }
  end
  if dropped == 1 then
    lines[#lines + 1] = { text = L["1 quest (abandoned)"], icon = Keep.KIND_ICONS.quest }
  elseif dropped > 1 then
    lines[#lines + 1] = { text = string.format(L["%d quests (abandoned)"], dropped), icon = Keep.KIND_ICONS.quest }
  end
  return lines
end

-- Brief UL1: the tick a completed quest's line wears after its quest mark (the tree's completed quest
-- mark, the uses line's ICON_CHECK).
Keep.DONE_ICON = "ICON_CHECK"

-- Brief TB14 (the owner on Al'Alketh Cultist's Ear, 2026-10-05): the quest line while at least
-- one quest use is open, counting every quest the item serves, the finished ones in brackets:
-- "2 quests", "2 quests (1 completed)", "3 quests (1 completed, 1 abandoned)". open is the open
-- quest uses, done and abandoned are ScoreUses' score.done (abandoned among them) and
-- score.abandoned. Pure.
function Keep.QuestWords(open, done, abandoned)
  open = math.max(0, math.floor(tonumber(open) or 0))
  done = math.max(0, math.floor(tonumber(done) or 0))
  local dropped = math.min(done, math.max(0, math.floor(tonumber(abandoned) or 0)))
  local finished = done - dropped
  local words = counted("quest", open + done)
  local parts = {}
  if finished > 0 then
    parts[#parts + 1] = string.format(L["%d completed"], finished)
  end
  if dropped > 0 then
    parts[#parts + 1] = string.format(L["%d abandoned"], dropped)
  end
  if #parts == 0 then
    return words
  end
  return string.format(L["%s (%s)"], words, table.concat(parts, ", "))
end

-- The glyph a profession's recipes wear, from UI/Assets.lua (loaded after Core, so read when the
-- lines are built), or the note where Assets is not there to ask. Pure.
local function skillIcon(skill)
  local Assets = ItemTree.Assets
  if type(Assets) == "table" and type(Assets.ForSkill) == "function" then
    local ok, key = pcall(Assets.ForSkill, skill)
    if ok and type(key) == "string" then
      return key
    end
  end
  return Keep.SKILL_ICON_FALLBACK
end

-- Brief TB13: a profession's glyph inline in a line's words, its escape and a space, sized to a
-- tooltip line (the Theme's tooltip badge size, Keep.INLINE_GLYPH_SIZE where the Theme is not
-- loaded), or "" where Assets is not there to ask or has no art for the key, so the words read
-- plain. Assets.Markup is the one place a key becomes a path. Pure.
Keep.INLINE_GLYPH_SIZE = 14
function Keep.InlineGlyph(key)
  local Assets = ItemTree.Assets
  if type(key) ~= "string" or type(Assets) ~= "table" or type(Assets.Markup) ~= "function" then
    return ""
  end
  if type(Assets.Has) == "function" and not Assets.Has(key) then
    return ""
  end
  local Theme = ItemTree.Theme
  local sizes = type(Theme) == "table" and type(Theme.sizes) == "table" and Theme.sizes or EMPTY
  local size = tonumber(sizes.ITEMTREE_BADGE_SIZE_TOOLTIP) or Keep.INLINE_GLYPH_SIZE
  local ok, markup = pcall(Assets.Markup, key, size)
  if not ok or type(markup) ~= "string" or markup == "" then
    return ""
  end
  return markup .. " "
end

-- Brief TB14: the skill lines a chain line names by a short name, in the order ShortSkill tries
-- them for a skill line that shares one's name (a build can list one profession on two lines).
local SHORT_SKILLS = { 171, 164, 333, 202, 165, 197, 186, 182, 393, 185, 129, 356 }

-- One skill line's short name, or nil. Written out one literal at a time for the locale sweep.
local function shortByLine(id)
  if id == 171 then
    return L["Alch"]
  elseif id == 164 then
    return L["BS"]
  elseif id == 333 then
    return L["Ench"]
  elseif id == 202 then
    return L["Eng"]
  elseif id == 165 then
    return L["LW"]
  elseif id == 197 then
    return L["Tailor"]
  elseif id == 186 then
    return L["Mining"]
  elseif id == 182 then
    return L["Herb"]
  elseif id == 393 then
    return L["Skin"]
  elseif id == 185 then
    return L["Cook"]
  elseif id == 129 then
    return L["FA"]
  elseif id == 356 then
    return L["Fish"]
  end
  return nil
end

-- Brief TB14 (the owner, 2026-10-05: "literally 'BS via LW' with the icons"): a profession's short
-- name by its skill line ("BS" for Blacksmithing), the short name of a listed line that shares its
-- name where the line is not listed itself, else its full name, or nil where it has no name. Pure.
function Keep.ShortSkill(skillId)
  local id = tonumber(skillId)
  local short = shortByLine(id)
  if short then
    return short
  end
  local name = skillName(id)
  if not name then
    return nil
  end
  for _, line in ipairs(SHORT_SKILLS) do
    if skillName(line) == name then
      return shortByLine(line)
    end
  end
  return name
end

-- Brief TB13 (the owner on Light Leather, 2026-10-06): one chain in words, in the shape of the
-- direct lines above it, "8 x [glyph] Blacksmithing via [glyph] Alchemy (Sulfuric Acid)": the
-- count, the end profession and the via profession each after its own glyph (Keep.InlineGlyph),
-- and the product closing the line in brackets, ", +2 more" where the pair reaches other
-- products. nil where a profession has no name. The product's name is the graph's. Brief TB14:
-- both professions by their short names (Keep.ShortSkill), "8 x BS via LW (Medium Leather)",
-- the end profession's full name (group.name) where its skill line has no name. Pure.
function Keep.ChainWords(group)
  if type(group) ~= "table" or type(group.name) ~= "string" then
    return nil
  end
  local via = skillName(tonumber(group.viaSkill)) and Keep.ShortSkill(group.viaSkill)
  local n = tonumber(group.count) or 0
  if not via or n <= 0 then
    return nil
  end
  local Graph = ItemTree.Graph
  local product = nil
  if type(Graph) == "table" and type(Graph.Name) == "function" and group.item then
    local ok, name = pcall(Graph.Name, "item:" .. tostring(group.item))
    product = ok and type(name) == "string" and name ~= "" and name or nil
  end
  product = product or tostring(group.item)
  local more = tonumber(group.more) or 0
  if more > 0 then
    product = string.format(L["%s, +%d more"], product, more)
  end
  return string.format(
    L["%d x %s via %s (%s)"],
    n,
    Keep.InlineGlyph(skillIcon(tonumber(group.skill))) .. (Keep.ShortSkill(group.skill) or group.name),
    Keep.InlineGlyph(skillIcon(tonumber(group.viaSkill))) .. via,
    product
  )
end

-- Brief K24b (D3): the level bracket a Keep's uses span, the old head's "lvl 12 to 19" as words of
-- its own: "Useful from level 12 to 19", "Useful at level 12" where both ends are one level, or
-- nil where no use has a level. Pure.
function Keep.BracketWords(lo, hi)
  lo, hi = tonumber(lo), tonumber(hi)
  if lo == nil and hi == nil then
    return nil
  end
  lo = lo or hi
  hi = hi or lo
  if lo > hi then
    lo, hi = hi, lo
  end
  if lo == hi then
    return string.format(L["Useful at level %d"], lo)
  end
  return string.format(L["Useful from level %d to %d"], lo, hi)
end

-- Brief K9: copper as "1g 20s", the way the game's own letters write it: gold and silver where
-- there is gold, silver and copper below that, a zero part dropped, "0c" for nothing. Pure.
function Keep.MoneyWords(copper)
  local value = math.floor(tonumber(copper) or 0)
  if value < 0 then
    value = 0
  end
  local gold = math.floor(value / 10000)
  local silver = math.floor((value % 10000) / 100)
  local rest = value % 100
  local parts = {}
  if gold > 0 then
    parts[#parts + 1] = gold .. "g"
    if silver > 0 then
      parts[#parts + 1] = silver .. "s"
    end
  else
    if silver > 0 then
      parts[#parts + 1] = silver .. "s"
    end
    if rest > 0 or silver == 0 then
      parts[#parts + 1] = rest .. "c"
    end
  end
  return table.concat(parts, " ")
end

-- Brief K1: the words of the neutral line, and the help text that names its two thresholds, for a
-- settings row or a help page to show. Brief W28: the help text also says that another
-- profession's recipes read grey, since the line no longer says so in words. Pure.
function Keep.EverywhereWords()
  return L["Sold by vendors everywhere"]
end

-- Brief K20b (design K20 section 4): the order of decision in two sentences, for the Keep marks
-- settings row's hover. Brief K20-wire: the gear upgrade and the two disenchant states. Brief
-- K24b: the tags, Keep, Auction and Vendor (Disenchant for an enchanter). Pure.
function Keep.OrderText()
  return L["Keep when you mark it Always, your route needs it, it has uses ahead, it is an upgrade,"]
    .. " "
    .. L["or it disenchants into something you use."]
    .. " "
    .. L["Auction when its price beats the vendor by your margin and a stack is worth it for the money you carry,"]
    .. " "
    .. L["and Vendor beside it while that is close. Disenchant stands beside or for Auction when you enchant."]
end

function Keep.HelpText()
  local copper = Keep.CHEAP_COPPER
  local price
  if copper >= 100 and copper % 100 == 0 then
    price = string.format(L["%d silver"], copper / 100)
  else
    price = string.format(L["%d copper"], copper)
  end
  return string.format(
    L["An item %d or more vendors sell for %s or less never glows, and its tooltip says Sold by vendors everywhere."],
    Keep.EVERYWHERE_VENDORS,
    price
  ) .. " " .. L["Recipes for a profession you do not have read grey."]
end

-- Brief PR4: the route entry in words, "Cooking, skill 50 to 100", with the skill line's name from
-- the Skills table. Pure.
--
-- Brief PR9: where the entry carries the route's need (info.need, from the model) and the caller
-- hands the player's count in (have, bags and bank), the count replaces the band, because the
-- need runs over every band still ahead, not the one named. With either missing, the band words
-- as before. Brief PR39 (the owner: "just saying Cooking, 0 35 needed is not clear"): the count
-- reads "Level Cooking (12 / 40 needed)". Brief BQ16 (the owner's ruling of 2026-10-10, QA item 8):
-- at and past the need too, "Level First Aid (12 / 8 needed)", the count itself showing what is
-- spare (was "First Aid, you have enough (8)" and K30's "Keep 8 for First Aid, the rest can go").
function Keep.ProfessionWords(info, have)
  if type(info) ~= "table" then
    return nil
  end
  local lo, hi = tonumber(info.lo) or 0, tonumber(info.hi) or 0
  local name = skillName(tonumber(info.skillLine))
  local need = tonumber(info.need)
  have = tonumber(have)
  if need and need > 0 and have then
    if name then
      return string.format(L["Level %s (%d / %d needed)"], name, have, need)
    end
    return string.format(L["Level a profession (%d / %d needed)"], have, need)
  end
  if name then
    return string.format(L["%s, skill %d to %d"], name, lo, hi)
  end
  return string.format(L["Profession, skill %d to %d"], lo, hi)
end

-- Brief K30: the line of an item whose own profession recipes the route's count of 0 leaves
-- unkept: "Not needed to level First Aid" for one trade line the tables name, else "Not needed to
-- level your professions". Brief RB2B (QA item 267, the owner: "peacebloom is never needed to level
-- herbalism (you gain levels from picking herbs) ... 'Below your current herbalism level' is
-- probably better"): a gathering trade's lines (Keep.GatherLine) are never "needed to level" it. The
-- crafting lines alone say so where there are any; where every line is a gathering trade's, "Below
-- your current Herbalism level" (Keep.GatherSpareWords). Pure.
function Keep.SpareWords(score)
  local trades = type(score) == "table" and type(score.tradeLines) == "table" and score.tradeLines or EMPTY
  local crafting = {}
  for _, skill in ipairs(trades) do
    if not Keep.GatherLine(skill) then
      crafting[#crafting + 1] = skill
    end
  end
  if #trades > 0 and #crafting == 0 then
    return Keep.GatherSpareWords(score)
  end
  -- One profession on two skill lines (First Aid's 129 and 2942) is one name.
  local name = nil
  for _, skill in ipairs(crafting) do
    local named = skillName(tonumber(skill))
    if not named or (name and named ~= name) then
      return L["Not needed to level your professions"]
    end
    name = named
  end
  if name then
    return string.format(L["Not needed to level %s"], name)
  end
  return L["Not needed to level your professions"]
end

-- Brief RB2B (QA item 267): the line of an item whose gathering trade recipes keep nothing (grey,
-- brief RB2A): "Below your current Herbalism level" for one trade the tables name, else "Below your
-- current profession levels"; for a trade the character only tracks (brief TG1: outside the chosen
-- range; score.ownProfessions, the character's own where tracked ones joined the set), "Outside your
-- Herbalism range (tracked)". Pure.
function Keep.GatherSpareWords(score)
  local trades = type(score) == "table" and type(score.tradeLines) == "table" and score.tradeLines or EMPTY
  local own = type(score) == "table" and type(score.ownProfessions) == "table" and score.ownProfessions or nil
  local name, tracked = nil, own ~= nil
  for _, skill in ipairs(trades) do
    local named = skillName(tonumber(skill))
    if not named or (name and named ~= name) then
      return L["Below your current profession levels"]
    end
    name = named
    if own and Keep.IsOwnSkill(tonumber(skill), own) then
      tracked = false
    end
  end
  if not name then
    return L["Below your current profession levels"]
  end
  if tracked then
    return string.format(L["Outside your %s range (tracked)"], name)
  end
  return string.format(L["Below your current %s level"], name)
end

-- One reason line, { text, icon, muted }. Pure.
local function reason(text, icon, isMuted, plain)
  local line = { text = text, icon = icon }
  if isMuted then
    line.muted = true
  end
  -- Brief K24e: the words where they differ from Keep.Plain(text) (the gear line's inline arrow).
  if type(plain) == "string" and plain ~= text then
    line.plain = plain
  end
  return line
end

-- Brief TB9: the chain lines, appended to into: brief TB13, one per pair of professions in
-- Keep.ScoreChains' order, each led by the chain glyph (Keep.CHAIN_ICON) with the professions'
-- glyphs inline in its words, the player's own in the reasons' colour and the others muted.
-- Answers into. Pure.
local function chainLines(score, into)
  for _, group in ipairs(type(score) == "table" and score.chainGroups or EMPTY) do
    local words = Keep.ChainWords(group)
    if words then
      -- Brief BQ25a (the owner's ruling of 2026-10-10, QA item 45): a current chain that ends in
      -- one of the player's own professions is their use, through whatever profession it runs
      -- ("1 x LW via Alch (Minor Mana Potion)" on a leatherworker): drawn in the reasons' colour
      -- and shown in the folded view. A stale one (ScoreChains' stale) folds under the modifier.
      local mine = group.own and not group.stale
      local line = reason(words, Keep.CHAIN_ICON, not mine)
      into[#into + 1] = Keep.MarkOtherUse(line, not mine, group.count)
    end
  end
  return into
end

-- Brief BQ7 (owner QA item 19, "Hide irrelevant uses"): marks a reason line as a use that is not
-- the player's (a profession they do not have, or a chain through one), with the uses it counts,
-- so the tooltip can fold such lines into one "and N other uses" line (UI/Tooltip.lua
-- Tooltip.FoldUses). The item page draws every line as before. Answers the line. Pure.
function Keep.MarkOtherUse(line, other, count)
  if type(line) == "table" and other then
    line.other = true
    line.otherUses = math.max(1, math.floor(tonumber(count) or 1))
  end
  return line
end

-- Brief K22: one item combine in words, "Waylaid Supplies: Rough Stone needs 10": the via item's
-- name (the graph's, else its fallback), "needs" and how many of the hovered item it takes. nil
-- for anything else. Pure.
-- Brief UL1 (QA items 347g and 347h, the owner on Peacebloom: "We should use the same setup as
-- elsewhere so its consistent"): the need shape the quest and route lines use, the crate named,
-- "Waylaid Supplies (0 / 20 needed)", "Snowmaster 9000 (0 / 1 needed)": have the player's count of
-- the hovered item (bags and bank), "Waylaid Supplies (20 needed)" where it is not known. itemId (the
-- hovered item, optional) lets the crate's name leave off what follows its colon where that names
-- the hovered item ("Waylaid Supplies: Peacebloom", Keep.CrateName).
function Keep.CombineWords(combine, have, itemId)
  if type(combine) ~= "table" or tonumber(combine.via) == nil then
    return nil
  end
  local key = "item:" .. tostring(combine.via)
  local Graph = ItemTree.Graph
  local name = nil
  if type(Graph) == "table" and type(Graph.Name) == "function" then
    local ok, answer = pcall(Graph.Name, key)
    name = ok and type(answer) == "string" and answer ~= "" and answer or nil
  end
  if not name and type(Graph) == "table" and type(Graph.Fallback) == "function" then
    local ok, answer = pcall(Graph.Fallback, "item", tonumber(combine.via))
    name = ok and type(answer) == "string" and answer ~= "" and answer or nil
  end
  -- Brief UL2 (QA item 366): another item combine (a toy, Snowmaster 9000) reads as before UL1, the via
  -- item's whole name, "needs" and the count: "Snowmaster 9000 needs 1".
  if not combine.crate then
    return string.format(L["%s needs %d"], name or tostring(combine.via), tonumber(combine.count) or 1)
  end
  name = Keep.CrateName(name or tostring(combine.via), itemId)
  local need = tonumber(combine.count) or 1
  if tonumber(have) == nil then
    return string.format(L["%s (%d needed)"], name, math.floor(need))
  end
  return Keep.NeedWords(name, have, need)
end

-- Brief UL1 (QA item 347h): a crate's name as its need line names it: "Waylaid Supplies" for
-- "Waylaid Supplies: Peacebloom" where what follows the colon starts with the hovered item's first
-- word (the crate names the item it takes, "Herb Baked Eggs" for Herb Baked Egg), else the name
-- whole ("Snowmaster 9000"). Pure but for the hovered item's name (Graph.Name).
function Keep.CrateName(name, itemId)
  if type(name) ~= "string" then
    return name
  end
  local head, rest = name:match("^(.-): (.+)$")
  if not head or head == "" then
    return name
  end
  local Graph = ItemTree.Graph
  local own = nil
  if tonumber(itemId) and type(Graph) == "table" and type(Graph.Name) == "function" then
    local ok, answer = pcall(Graph.Name, "item:" .. tostring(itemId))
    own = ok and type(answer) == "string" and answer or nil
  end
  local first = type(own) == "string" and own:match("^(%S+)") or nil
  if not first then
    return name
  end
  if rest:lower():sub(1, #first) == first:lower() then
    return head
  end
  return name
end

-- Brief UL1 (QA item 347h): a crate line's glyph, the wooden crate (UI/Assets.lua CAT_CONTAINER, the
-- art of "Contained in"), no longer the recipe scroll the recipes no profession names wear.
Keep.CRATE_ICON = "CAT_CONTAINER"

-- Brief K22: the item combine lines, appended to into in Keep.SortCombines' order, each with the
-- glyph the recipes no profession names wear, muted unless its via item is carried. Answers into.
-- Pure. Brief UL1: in the need shape with the crate's glyph (Keep.CombineWords, Keep.CRATE_ICON); have
-- as Keep.CombineWords'.
local function combineLines(score, into, have)
  for _, combine in ipairs(type(score) == "table" and type(score.combines) == "table" and score.combines or EMPTY) do
    local words = Keep.CombineWords(combine, have, score.itemId)
    if words and combine.crate then
      into[#into + 1] = reason(words, Keep.CRATE_ICON, combine.carried ~= true)
    elseif words then
      -- Brief UL2 (QA item 366): another combine wears the recipe mark as before UL1; not carried, it is a
      -- use that is not the character's, folded with the other uses (Keep.MarkOtherUse).
      local line = reason(words, Keep.KIND_ICONS.recipe, combine.carried ~= true)
      into[#into + 1] = Keep.MarkOtherUse(line, combine.carried ~= true, 1)
    end
  end
  return into
end

-- Brief UL1 (QA item 356, the owner on Formula: Runed Arcanite Rod and Schematic: Ez-Thro Radiation
-- Bomb: no product name line under the recipe item's state line): a recipe group as its line counts
-- it, less the recipes a recipe item teaches (group.teaches, fileRecipe); the group itself where it
-- holds none, a fresh copy where it holds some, nil where they are all it holds. Pure.
function Keep.GroupShown(group)
  if type(group) ~= "table" then
    return nil
  end
  local teaches = tonumber(group.teaches) or 0
  if teaches <= 0 then
    return group
  end
  local n = (tonumber(group.count) or 0) - teaches
  if n <= 0 then
    return nil
  end
  local copy = {}
  for key, value in pairs(group) do
    copy[key] = value
  end
  copy.count = n
  copy.teaches = nil
  return copy
end

-- Brief K11: why an item is worth keeping, one line per reason, in this order (brief K24b: the
-- auction value line is gone, the client prints the prices):
--   with recipeGroups (Keep.ScoreUses with professions): the player's own professions' recipes,
--     then recipes no profession names, then the other professions' recipes, these muted
--   without: every current recipe as one count
--   then quests, locks and the class spells ("Used by your Stone Ward")
-- Each is { text, icon = Assets key, muted = true or nil }; the caller colours it. Pure.
--
-- Brief PM1: where the Professions route still needs the item (score.profession, only ever set
-- while the module is on), its line comes first of all, the most specific reason to the player,
-- with the profession's glyph and Keep.ProfessionWords' words ("Level Cooking (12 / 40 needed)" where
-- have, the player's count, is handed in). With the module off nothing here changes.
--
-- Brief K18: the recipes no profession names read Keep.PlainWords (their own name, or "N other
-- recipes"). And where the route line is drawn, the recipe lines are the item's whole list
-- (score.listGroups, every recipe use whatever its level), the route's own profession among them
-- ("1 x Cooking" under "Level Cooking (0 / 35 needed)"): the route line counts items, never
-- recipes, so each recipe is counted once, on its profession's line.
--
-- Brief K30: spare true
-- (an item the route's count of 0 leaves unkept, Keep.ReagentSpare) leads with "Not needed to
-- level First Aid" (Keep.SpareWords), muted, and draws the player's own professions' recipe lines
-- muted too, since they keep nothing. The owner's QA item 43: spare Keep.SPARE_STOCK (the working
-- stock keeps it, brief BQ18) leads the same way but draws the player's own lines in the reasons'
-- white, since they are why it is kept.
--
-- Brief BQ14 (QA items 14 and 43): each profession line carries its group's qualities (a mask,
-- Keep.GroupQualities), which the tooltip draws as small circles after the count.
--
-- Brief BQ16 (the owner's ruling of 2026-10-10, QA item 8): every need in the levelling line's
-- shape, with no "the rest can go" sentence. The route line is always Keep.ProfessionWords' count
-- ("Level First Aid (12 / 8 needed)"); a quest only keep (Keep.QuestKeepUpTo) adds the quests'
-- need line under the quest count ("Westfall Stew (II) (9 / 8 needed)", Keep.QuestNeedWords). Brief
-- INT1b's questPart, where the route and the open quests keep the item together
-- (Keep.CombinedKeepNeed), is the quests' count: the player's count serves the quests first, so the
-- quest line reads min(have, questPart) of it and the route line the rest ("Level Cooking (57 / 48
-- needed)" and "Thelsamar Blood Sausages (3 / 3 needed)" at 60 held). _surplus (Keep.Tags'
-- answer.surplus) stays in the signature for the callers that pass it; the counts say it now.
function Keep.ReasonLines(score, have, _surplus, spare, questPart)
  local lines = {}
  if type(score) ~= "table" then
    return lines
  end
  -- Brief TV1: Keep.SPARE_QUIET mutes as spare does, with no lead line.
  if spare and spare ~= Keep.SPARE_QUIET then
    local trades = type(score.tradeLines) == "table" and score.tradeLines or EMPTY
    lines[#lines + 1] = reason(Keep.SpareWords(score), skillIcon(tonumber(trades[1])), true)
  end
  local questHave, questNeed = Keep.QuestNeedCounts(score, have, questPart)
  if type(score.profession) == "table" then
    local routeHave = have
    if tonumber(have) and tonumber(questPart) then
      routeHave = math.max(0, tonumber(have) - (questHave or 0))
    end
    local words = Keep.ProfessionWords(score.profession, routeHave)
    if words then
      lines[#lines + 1] = reason(words, skillIcon(tonumber(score.profession.skillLine)))
    end
  end
  -- Brief K24b (D2): no prices line any more, under a Keep or anywhere else in the section.
  local kinds = score.kinds or EMPTY
  local groups, plain, plainName = score.recipeGroups, score.plainRecipes, score.plainName
  local recipes = kinds.recipe
  if type(score.profession) == "table" and score.listRecipes ~= nil then
    groups, plain, plainName = score.listGroups, score.listPlain, score.listPlainName
    recipes = score.listRecipes
  end
  if type(groups) == "table" then
    for _, held in ipairs(groups) do
      local group = Keep.GroupShown(held)
      local words = group and group.own and Keep.GroupWords(group) or nil
      if words then
        -- Brief K30: muted where the route's count leaves them keeping nothing (spare).
        local line = reason(words, skillIcon(group.skill), spare == true or spare == Keep.SPARE_QUIET)
        line.qualities = group.qualities
        -- Brief UL3: the profession and count, so the recipes behind can join the line (Tooltip.FoldBehindUses).
        line.groupName, line.groupCount = group.name, group.count
        -- Brief TV1 (QA item 347b): a profession's recipe line, which a group of one words as its recipe's
        -- name (Keep.GroupWords), so a reader can still tell it from the other reasons.
        line.group = true
        lines[#lines + 1] = line
      end
    end
    local words = Keep.PlainWords(plain, plainName)
    if words then
      lines[#lines + 1] = reason(words, Keep.KIND_ICONS.recipe)
    end
    -- Brief K22: the item combines where the other recipes no profession names sit.
    combineLines(score, lines, have)
    for _, held in ipairs(groups) do
      local group = Keep.GroupShown(held)
      words = group and not group.own and Keep.GroupWords(group) or nil
      if words then
        -- Brief BQ7: another profession's recipes, folded on the tooltip (Keep.MarkOtherUse).
        local line = reason(words, skillIcon(group.skill), true)
        line.qualities = group.qualities
        line.group = true
        line.groupName, line.groupCount = group.name, group.count
        lines[#lines + 1] = Keep.MarkOtherUse(line, true, group.count)
      end
    end
  else
    -- Brief K22: a carried combine has a line of its own, so it is not in the count too. Brief UL1 (QA
    -- item 356): nor the recipe a recipe item teaches (score.teachUses), which no line names.
    local n = (tonumber(recipes) or 0) - (tonumber(score.carriedCombines) or 0) - (tonumber(score.teachUses) or 0)
    if n > 0 then
      lines[#lines + 1] = reason(counted("recipe", n), Keep.KIND_ICONS.recipe)
    end
    combineLines(score, lines, have)
  end
  for _, kind in ipairs(KIND_ORDER) do
    local n = kind ~= "recipe" and tonumber(kinds[kind]) or 0
    if n > 0 then
      -- Brief TB14: the open quests count the finished ones too, in brackets on the one line.
      local words = kind == "quest" and Keep.QuestWords(n, score.done, score.abandoned) or counted(kind, n)
      -- Brief TV1 (QA item 347, the owner on Noboru's Cudgel: '1 quest' unnamed): one open quest and no
      -- finished one, with no need line under it to name it, reads the quest's title (Keep.QuestTitle).
      if kind == "quest" and n == 1 and not questNeed and words == counted("quest", 1) then
        local ids = type(score.questIds) == "table" and score.questIds or EMPTY
        words = Keep.QuestTitle(tonumber(ids[1])) or words
      end
      lines[#lines + 1] = reason(words, Keep.KIND_ICONS[kind])
      -- Brief Q1: a quest only keep holds the count the quests ask for. Brief BQ16: its need line,
      -- "Westfall Stew (II) (9 / 8 needed)", in the levelling line's shape.
      if kind == "quest" and questNeed then
        lines[#lines + 1] = reason(Keep.QuestNeedWords(score, questHave, questNeed), Keep.KIND_ICONS.quest)
      end
    end
  end
  local spells = Keep.SpellWords(score)
  if spells then
    lines[#lines + 1] = reason(spells, Keep.KIND_ICONS.spell)
  end
  -- Brief TB10: the player's own class locked consumable, "Class: Mage (Comprehension 1)".
  local classUse = (tonumber(kinds.class) or 0) > 0 and Keep.ClassWords(score.classUse) or nil
  if classUse then
    lines[#lines + 1] = reason(classUse, Keep.KIND_ICONS.class)
  end
  -- Brief TB9: the chains last, under the direct uses.
  return chainLines(score, lines)
end

-- Brief K11: why an item is not worth keeping, one line per kind of use below the player
-- ("2 recipes below your level"), or the count where no kind is named. Pure.
local function staleLines(score)
  local lines = {}
  local kinds = score.staleKinds or EMPTY
  for _, kind in ipairs(KIND_ORDER) do
    local n = tonumber(kinds[kind]) or 0
    if n > 0 then
      lines[#lines + 1] = reason(string.format(L["%s below your level"], counted(kind, n)), Keep.KIND_ICONS[kind])
    end
  end
  if #lines == 0 then
    if score.stale == 1 then
      lines[1] = reason(L["Its 1 use is below your level"])
    else
      lines[1] = reason(string.format(L["Its %d uses are below your level"], score.stale))
    end
  end
  return lines
end

-- Brief UL1 (QA item 347i, the owner on "Used in 15 recipes, 1 quest" under Sold by vendors everywhere:
-- "What in the 15 recipes and quest is useful to the player? We need to pull out the useful items and
-- hide the other items behind other uses"): an item's uses in the Keep block's shape, for the tooltip's
-- uses lines where its block lists none (UI/Tooltip.lua Tooltip.UseLines draws them in place of the
-- one "Used in" line): the lines a block that lists the uses draws, Keep.ReasonLines' (the route, one
-- line per profession of the character's with its glyph and dots, the recipes no profession names, the
-- crates in the need shape, the quests named with their counts, the spells, the class use, the
-- chains), the other professions' recipes and chains marked for the fold (Keep.MarkOtherUse), the own
-- profession lines muted where the route's count leaves them keeping nothing (Keep.ReagentSpare, no
-- lead line), and the quests finished where none is open (Keep.DoneLines). An item with no current use
-- but uses behind it or quests finished lists them as a sale does (Keep.SaleReasons): the uses below
-- the character's level, the quests finished, the crates, the chains. have as Keep.ReasonLines'. The
-- tooltip adds the quests the character cannot take (the fold's lines) as it does to a block. A list
-- of raw reason lines, empty for none. Pure.
function Keep.UseLines(score, have)
  local lines = {}
  if type(score) ~= "table" then
    return lines
  end
  local function append(more)
    for _, line in ipairs(more) do
      lines[#lines + 1] = line
    end
  end
  local current = tonumber(score.current) or 0
  local stale, done = tonumber(score.stale) or 0, tonumber(score.done) or 0
  if current == 0 and (stale > 0 or done > 0) then
    if stale > 0 then
      append(staleLines(score))
    end
    append(Keep.DoneLines(score))
    combineLines(score, lines, have)
    chainLines(score, lines)
    return lines
  end
  append(Keep.ReasonLines(score, have, nil, Keep.ReagentSpare(score) and Keep.SPARE_QUIET or nil))
  if (tonumber((score.kinds or EMPTY).quest) or 0) == 0 then
    append(Keep.DoneLines(score))
  end
  return lines
end

-- Brief UL2 (QA item 367, the owner's ruling B of 2026-10-21 on UL1's open call: "Count them in 'and N
-- other uses, hold Ctrl'"): the uses UL1's lines leave out because they are behind the character, as
-- muted lines marked as uses that are not theirs (Keep.MarkOtherUse), so the tooltip's fold counts them
-- and lists them under Ctrl, as the one "Used in 63 recipes" line counted them before UL1; and another
-- class's spells ("Used by Shaman spells", Keep.SaleReasons' words, score.otherSpellUses), which the one
-- line counted too. Empty where no use is current: a sale lists its uses behind the character itself then
-- (Keep.SaleReasons, Keep.UseLines). Keep's verdicts never read these lines.
-- Brief UL3 (QA item 369, the owner on Bronze Bar at 55 with Ctrl held: "WHY DOES IT SAY 73 RECIPES PLAINLY
-- LIKE THIS ... ITS THE EXPANDED OPTION TO SHOW DETAIL"): no "below your level" line. The recipes behind
-- come by profession in the group lines' shape ("40 x Blacksmithing" with its glyph and dots, each line
-- carrying groupName and groupCount, so the tooltip joins it to that profession's own folded line,
-- Tooltip.FoldBehindUses); the recipes no profession names in Keep.PlainWords' words; with no
-- professions read, one count ("52 recipes"); the quests behind as a quest lists, one by its title (else
-- "1 quest"), more by their count ("2 quests"). The other side's quests the setting leaves stale are not
-- among them (the tooltip names those, "4 Horde quests"); with the Professions route on, the block's
-- recipe lines are the item's whole list already (score.listGroups), so its recipes are not added. Pure but
-- for the title read (Keep.QuestTitle).
function Keep.BehindLines(score)
  local lines = {}
  if type(score) ~= "table" or (tonumber(score.current) or 0) <= 0 then
    return lines
  end
  local listed = type(score.profession) == "table" and score.listRecipes ~= nil
  if not listed and type(score.behindGroups) == "table" then
    for _, held in ipairs(score.behindGroups) do
      local group = Keep.GroupShown(held)
      local words = group and Keep.GroupWords(group) or nil
      if words then
        local line = reason(words, skillIcon(group.skill), true)
        line.qualities = group.qualities
        line.group = true
        line.groupName = group.name
        line.groupCount = group.count
        lines[#lines + 1] = Keep.MarkOtherUse(line, true, group.count)
      end
    end
    local plain = tonumber(score.behindPlain) or 0
    local words = Keep.PlainWords(plain, score.behindPlainName)
    if words then
      lines[#lines + 1] = Keep.MarkOtherUse(reason(words, Keep.KIND_ICONS.recipe, true), true, plain)
    end
  elseif not listed and (tonumber(score.behindRecipes) or 0) > 0 then
    local n = tonumber(score.behindRecipes)
    lines[#lines + 1] = Keep.MarkOtherUse(reason(counted("recipe", n), Keep.KIND_ICONS.recipe, true), true, n)
  end
  local quests = type(score.behindQuestIds) == "table" and score.behindQuestIds or EMPTY
  if #quests > 0 then
    local words = counted("quest", #quests)
    if #quests == 1 and quests[1] then
      words = Keep.QuestTitle(tonumber(quests[1])) or words
    end
    lines[#lines + 1] = Keep.MarkOtherUse(reason(words, Keep.KIND_ICONS.quest, true), true, #quests)
  end
  local spells = tonumber(score.otherSpellUses) or 0
  local others = spells > 0 and classWords(score.otherClasses) or nil
  if others then
    local line = reason(string.format(L["Used by %s spells"], others), Keep.KIND_ICONS.spell, true)
    lines[#lines + 1] = Keep.MarkOtherUse(line, true, spells)
  end
  return lines
end

-- Brief UL1: a score less the quest the item starts that the character can take now (score.startsNow),
-- for the uses lines beside a [Use] "Use it: starts a quest" block, which names that quest: the open
-- quests, their ids and the current uses without it, and no quests' count (the quest it starts states
-- none, so none was summed). The score itself where it starts none. A fresh table (its kinds and ids
-- fresh too) otherwise. Pure.
function Keep.WithoutStartedQuest(score)
  if type(score) ~= "table" or score.startsNow == nil then
    return score
  end
  local open = tonumber((score.kinds or EMPTY).quest) or 0
  if open < 1 then
    return score
  end
  local copy = {}
  for key, value in pairs(score) do
    copy[key] = value
  end
  local kinds = {}
  for key, value in pairs(score.kinds or EMPTY) do
    kinds[key] = value
  end
  kinds.quest = open - 1
  copy.kinds = kinds
  copy.current = math.max(0, (tonumber(score.current) or 0) - 1)
  local ids, dropped = {}, false
  for _, questId in ipairs(type(score.questIds) == "table" and score.questIds or EMPTY) do
    if questId == score.startsNow and not dropped then
      dropped = true
    else
      ids[#ids + 1] = questId
    end
  end
  copy.questIds = #ids > 0 and ids or nil
  copy.questNeed = nil
  copy.startsNow = nil
  return copy
end

-- Brief K24b (owner redesign, 2026-10-05): the verdict for a score in its parts, or nil for Off
-- or an item with nothing to say (Keep.Tags answered nil):
--   tags   Keep.Tags' answer: the tag keys in display order and its flags
--   head   the tags as plain words, "Keep, Auction", "Auction, Vendor (No AH data)" (Keep.TagWords),
--          for the API and wherever textures cannot draw
--   state, sale   the old state words (Keep.TagState), for the API's keep.state and keep.sale
--   tone   "yes" for a keep, "never" for the player's Never, else the state
--   lines  the reasons under the tags, Keep.ReasonLines' shape (Keep.TagReasons); NO price line
--          of ours anywhere: the client's own tooltip already prints the prices
--   lists  true where the lines list the item's uses, so the tooltip's uses line steps aside for
--          them (brief K18); false where they do not
--   valuable  true where either price reaches the Keep value (the orange flag)
--   marked    the player's word, "always" or "never"
--   vendor    true where the state is Vendor (brief TB6's flag, kept)
-- Brief K5: an item the player marked Off answers nil. Brief PR9: have is the player's count of
-- the item (bags and bank) for the route line's "12 / 40 needed". settings (the Bar) are the saved
-- ones unless given; env is Keep.Tags' (money carried, the bag slot's bound state).
function Keep.TooltipParts(score, have, settings, env)
  if type(score) ~= "table" or score.override == "off" then
    return nil
  end
  -- Brief K24d: the route rule reads the same count the route line prints (env.have), unless the
  -- caller's env already carries one.
  if have ~= nil and (type(env) ~= "table" or env.have == nil) then
    local withHave = { have = have }
    for key, value in pairs(type(env) == "table" and env or EMPTY) do
      withHave[key] = value
    end
    env = withHave
  end
  local answer = Keep.Tags(score, settings, env)
  if answer == nil then
    -- Brief AQF1 fix 3: an epic quest item whose quests are all done draws its finished lines alone.
    local finishedOnly = Keep.FinishedOnlyParts(score)
    if finishedOnly then
      return finishedOnly
    end
    -- Brief GW1b (the review, the owner's 101 (a) "shows nothing"): a piece with no tags (no sell
    -- price, nothing keeping it) whose gear line has an answer ("Not for your class (Paladin
    -- only)") draws that muted line alone, no tag row.
    return Keep.ReasonAloneParts(score)
  end
  local lines, lists = Keep.TagReasons(score, answer, have, settings, env)
  local state, sale = Keep.TagState(answer)
  local tone = state
  if answer.keepBy ~= nil then
    tone = "yes"
  elseif score.override == "never" then
    tone = "never"
  end
  local marked = nil
  if score.override == "always" or score.override == "never" then
    marked = score.override
  end
  return {
    tags = answer,
    head = Keep.TagWords(answer),
    state = state,
    sale = sale,
    tone = tone,
    lines = lines,
    lists = lists,
    valuable = score.valuable == true or nil,
    marked = marked,
    vendor = state == Keep.STATE_VENDOR or nil,
  }
end

-- Brief GW1b: the parts for a score with no tags whose gear line has an answer: that line alone,
-- muted, with no tag row (tags and head nil, so Keep.VerdictLines draws no tag row, the API's
-- keep.line stays nil and the bag mark, which reads the tags, draws nothing). nil where the gear
-- line has nothing to say. Pure.
function Keep.ReasonAloneParts(score)
  local line = Keep.GearLine(score)
  if line == nil then
    return nil
  end
  line.muted = true
  return { tags = nil, head = nil, tone = Keep.STATE_VENDOR, lines = { line }, lists = false }
end

-- Brief K24b (D3): the level bracket a Keep's uses span, kept from the old "Keep (lvl 4 to 10)"
-- head as the first reason line, muted: "Useful from level 4 to 10", "Useful at level 12" where
-- both ends are one level, nil where no use has a level, and nil where the profession route is
-- why the item is kept (the rule alone would not keep it), as the head carried none then. Pure.
function Keep.KeepBracket(score)
  if type(score) ~= "table" then
    return nil
  end
  if type(score.profession) == "table" then
    local plain = {}
    for key, value in pairs(score) do
      plain[key] = value
    end
    plain.profession = nil
    plain.override = nil
    if not Keep.KeepRule(plain) then
      return nil
    end
  end
  return Keep.BracketWords(score.lo, score.hi)
end

-- Brief K31: the muted line over a tool's ordinary verdict: "Spare Skinning tool" for a copy of the
-- player's tool that is not the one kept (answer.toolSpare), "Tool for Mining" for a tool of a
-- profession the player lacks; nil for anything else. Pure.
function Keep.ToolLine(score, answer, env)
  local tool = type(score) == "table" and score.tool or nil
  if type(tool) ~= "table" then
    return nil
  end
  local name = Keep.ToolName(score, env)
  if tool.own and type(answer) == "table" and answer.toolSpare then
    local words = name and string.format(L["Spare %s tool"], name) or L["Spare profession tool"]
    return reason(words, skillIcon(tool.skill), true)
  end
  if not tool.own then
    local words = name and string.format(L["Tool for %s"], name) or L["Tool for another profession"]
    return reason(words, skillIcon(tool.skill), true)
  end
  return nil
end

-- Brief QX1 (the owner's words of 2026-10-22): one finished line's words, the template's quest
-- title (Keep.FinishedTitle) for the first quest and "and N more" for the rest, as the existing lines
-- count ("%s and %d more"), or nil for no quest. Pure but for the title read.
local function finishedWords(template, ids)
  if type(ids) ~= "table" or ids[1] == nil then
    return nil
  end
  local words = string.format(template, Keep.FinishedTitle(ids[1]))
  if #ids > 1 then
    words = string.format(L["%s and %d more"], words, #ids - 1)
  end
  return words
end

-- Brief QX1: a finished quest item's reason lines, the quest mark on each: 'Quest complete: "Riverpaw
-- Gnoll Bounty"' for the completed quests, then 'Quest abandoned: "..."' for the abandoned ones, one
-- line each kind (Keep.QuestFinished's answer). Empty for none. Pure but for the title and art reads.
-- Brief AQF1 fix 2 (the owner, QA item 378): the complete line wears the green tick after its quest mark,
-- inline at the front of its words (Keep.DONE_ICON), exactly as the uses line's "1 quest (completed)" did
-- (Keep.DoneLines); the abandoned line keeps the quest mark alone. Brief AQF1 fix 4 (the owner's ruling
-- "A", QA item 380): then 'Quest below your level: "..."' for the grey chain ends never taken, the quest
-- mark alone.
function Keep.FinishedLines(finished)
  local lines = {}
  if type(finished) ~= "table" then
    return lines
  end
  local complete = finishedWords(L["KEEP_QUEST_COMPLETE"], finished.complete)
  if complete then
    lines[#lines + 1] = { text = Keep.InlineGlyph(Keep.DONE_ICON) .. complete, icon = Keep.KIND_ICONS.quest }
  end
  local dropped = finishedWords(L["KEEP_QUEST_ABANDONED"], finished.abandoned)
  if dropped then
    lines[#lines + 1] = reason(dropped, Keep.KIND_ICONS.quest)
  end
  local below = finishedWords(L["KEEP_QUEST_BELOW_LEVEL"], finished.below)
  if below then
    lines[#lines + 1] = reason(below, Keep.KIND_ICONS.quest)
  end
  return lines
end

-- Brief AQF1 fix 3 (the owner's ruling "B" of 2026-10-22, QA item 379): the parts of an epic or better quest
-- item whose quests are all done (score.questFinishedLines, Keep.Score): its finished lines (Keep.FinishedLines)
-- with no tag row, which list its uses so the uses line steps aside for them as it does under [Vendor] or
-- [Worthless]. tags and head nil, as Keep.ReasonAloneParts', so the bag mark draws nothing and the API's
-- keep.line and keep.finished stay nil. nil for any other score. Pure.
function Keep.FinishedOnlyParts(score)
  local finished = type(score) == "table" and score.questFinishedLines or nil
  if type(finished) ~= "table" then
    return nil
  end
  local lines = Keep.FinishedLines(finished)
  if #lines == 0 then
    return nil
  end
  return { tags = nil, head = nil, tone = Keep.STATE_VENDOR, lines = lines, lists = true }
end

-- Brief K24b (D1): the reasons under the tags, and whether they list the item's uses:
--   "(marked by you)", muted, first, under the player's Always or Never
--   a keep by today's rule: the level bracket (muted), then the Keep lines as before (the route,
--     the player's uses, other professions' muted lines, the crate, quests, chains, the done
--     lines, the gear line)
--   Keep (disenchant): the material the player uses, then the gear line
--   the provisional soft keep: "You could use this", then why it is not a Keep
--   everything else: why it is not a Keep, as the sale verdict said it (Keep.SaleReasons)
-- No price line, not under a sale and not under a Keep. Brief K24h: env is Keep.Tags' (optional);
-- its outdone, the name of a bag item that is an upgrade on this worn one (Keep.ItemLines reads
-- it for the client's comparison tooltip), adds the muted "Better gear available" under
-- "Equipped". Pure.
function Keep.TagReasons(score, answer, have, settings, env)
  local lines, lists = {}, false
  if type(score) ~= "table" then
    return lines, lists
  end
  local function append(more)
    for _, line in ipairs(more) do
      lines[#lines + 1] = line
    end
  end
  if score.override == "always" or score.override == "never" then
    lines[#lines + 1] = reason(L["(marked by you)"], nil, true)
  end
  -- Brief QX1: a finished quest item's lines (Keep.FinishedLines), the complete line then the
  -- abandoned one, and nothing else: they list its uses, so the uses line steps aside.
  if type(answer) == "table" and type(answer.finished) == "table" then
    append(Keep.FinishedLines(answer.finished))
    return lines, true
  end
  local keepBy = type(answer) == "table" and answer.keepBy or nil
  -- Brief BQ18 (QA item 11): a worn piece a carried one beats, its one reason naming the carried one.
  if type(answer) == "table" and type(answer.outdone) == "string" and answer.outdone ~= "" then
    -- Brief WL1: a worn piece with no sell price said so under it, muted. Brief TV1 (QA item 347): the
    -- tag row says it now ("[Worthless] (No sell price or use)", Keep.TagRow).
    return { reason(string.format(L["Better gear in your bags: %s"], answer.outdone), Keep.GEAR_ICON) }, false
  end
  -- Brief K24e: a worn item's one reason, in the reasons' colour, and nothing else (no gear line).
  -- Brief K24h: and, in the comparison tooltip, the bag item that outdoes it, muted.
  if keepBy == Keep.KEEP_WORN then
    -- Brief F160: a bag in a bag slot says what it is, with no gear glyph.
    local wornBag = type(env) == "table" and env.wornBag or nil
    if wornBag == Keep.WORN_BANK_BAG then
      return { reason(L["Equipped bank bag"]) }, false
    elseif wornBag ~= nil then
      return { reason(L["Equipped bag"]) }, false
    end
    local worn = { reason(L["Equipped"], Keep.GEAR_ICON) }
    local outdone = type(env) == "table" and env.outdone or nil
    if type(outdone) == "string" and outdone ~= "" then
      worn[#worn + 1] = reason(L["Better gear available"], nil, true)
    end
    return worn, false
  end
  -- Brief K26: the pet food stack a hunter keeps, one reason and nothing else. Brief TV1 (QA item 347,
  -- the owner approved the audit's "Drop the line"): the Pet food tag says it, so no line at all.
  if keepBy == Keep.KEEP_PET then
    return {}, false
  end
  -- Brief AA-RB (QA item 216): a toy, one reason and nothing else: "Toy".
  if keepBy == Keep.KEEP_TOY then
    return { reason(L["Toy"]) }, false
  end
  -- Brief TV1 (QA item 347): the Hearthstone, one plain reason and nothing else.
  if keepBy == Keep.KEEP_HOME then
    return { reason(L["Takes you back to your inn"]) }, false
  end
  -- Brief TV1 (QA item 347b, ruling D1): a recipe of the player's own profession not learnt: its state
  -- first ("Learn it (Alchemy 225)", "Needs Alchemy 225 (you have 180)", with the profession's glyph),
  -- then its uses as the item's lines list them (the recipe it teaches, "Philosopher's Stone").
  if keepBy == Keep.KEEP_RECIPE then
    local recipe = score.recipe or EMPTY
    local words = Keep.RecipeWords(score)
    local out = {}
    if words then
      out[1] = reason(words, skillIcon(tonumber(recipe.skill)))
    end
    for _, line in ipairs(Keep.ReasonLines(score, have)) do
      out[#out + 1] = line
    end
    return out, true
  end
  -- Brief JG1 (item 302): a demon grimoire, one reason and nothing else: "Teaches your Voidwalker
  -- Torment (Rank 2)".
  if keepBy == Keep.KEEP_PET_BOOK then
    return { reason(Keep.PetBookWords(score.petBook)) }, false
  end
  -- Brief CB1 (item 305): a class book, one reason and nothing else: "Teaches you Arcane Brilliance
  -- (Rank 1)".
  if keepBy == Keep.KEEP_CLASS_BOOK then
    return { reason(Keep.ClassBookWords(score.classBook)) }, false
  end
  -- Brief AM1 (QA item 330): ammo the worn weapon fires, one reason and nothing else: "Ammo for your
  -- bow" (no "Sold by vendors everywhere" under it: the keep wins).
  if keepBy == Keep.KEEP_AMMO then
    return { reason(Keep.AmmoWords(score.ammo)) }, false
  end
  -- Brief K31: the best tool of one of the player's professions, one reason and nothing else:
  -- "Skinning tool".
  -- Brief UL1 (QA item 355, the owner on Philosopher's Stone as an alchemist: "Doesn't need to say 'Tool
  -- for 19 recipes' the 19 x Alchemy is enough with its use line 'Tool for alchemy'"): the standard uses
  -- shape, "Tool for Alchemy" (the words a tool of another profession reads, Keep.ToolLine) and then
  -- the uses as a keep lists them ("19 x Alchemy", the via lines and the other professions marked for
  -- the fold), so the block lists the uses and the uses line steps aside.
  if keepBy == Keep.KEEP_TOOL then
    local tool = score.tool or EMPTY
    local held = type(env) == "table" and type(env.tool) == "table" and env.tool or EMPTY
    local name = Keep.ToolName(score, env)
    local words = name and string.format(L["Tool for %s"], name) or L["Profession tool"]
    local out = { reason(words, skillIcon(tonumber(held.skill) or tonumber(tool.skill))) }
    for _, line in ipairs(Keep.ReasonLines(score, have)) do
      out[#out + 1] = line
    end
    return out, true
  end
  -- Brief K31: a spare copy of the player's tool ("Spare Skinning tool") or a tool for a profession
  -- the player lacks ("Tool for Mining"), muted, above its ordinary verdict's reasons.
  local toolLine = Keep.ToolLine(score, answer, env)
  if toolLine then
    lines[#lines + 1] = toolLine
  end
  -- Brief BQ9: the "do this now" verdicts, one reason and nothing else (Keep.OpenWords); a box the
  -- character cannot open says why first, muted, above its own verdict's reasons (BQ7).
  -- Brief BQ18 (folded in, BQ15's gap, QA item 4): a quest to start now carries the quest mark on its
  -- line, so the tooltip and the item page both draw it from the first build.
  if keepBy == Keep.KEEP_OPEN or keepBy == Keep.KEEP_USE or keepBy == Keep.KEEP_QUEST then
    return {
      reason(
        Keep.ActionWords(answer.action, score, answer),
        answer.action == Keep.ACTION_QUEST and Keep.KIND_ICONS.quest or nil
      ),
    },
      false
  end
  local locked = Keep.LockedWords(score)
  if locked then
    lines[#lines + 1] = reason(locked, nil, true)
  end
  -- Brief BQ18: the working stock keeps the item. The owner's QA item 43 (2026-10-10: "I didn't ask
  -- you to add all this random tooltip crap. I just want you to make the 10 x Leatherworking white
  -- with the recipe colours after"): no line of its own; K30's "Not needed to level Leatherworking"
  -- stays muted and the character's own profession lines under it are drawn in the reasons' white
  -- (Keep.SPARE_STOCK), the other professions muted as ever.
  if keepBy == Keep.KEEP_STOCK then
    append(Keep.ReasonLines(score, have, nil, Keep.SPARE_STOCK))
    return lines, true
  end
  if keepBy == "rule" or (keepBy == "always" and Keep.KeepRule(score)) then
    local bracket = Keep.KeepBracket(score)
    if bracket then
      lines[#lines + 1] = reason(bracket, nil, true)
    end
    -- Brief RB5 (QA item 202): a consumable kept far ahead says the rank it waits for ("Useful at
    -- First Aid 225"), under the bracket its uses give.
    if Keep.ConsumableAhead(score) and type(score.consumable.words) == "string" then
      lines[#lines + 1] = reason(score.consumable.words)
    end
    -- Brief K30: the route count's words for the surplus (Keep.Tags' answer.surplus). Brief INT1b:
    -- and the quests' part of a combined count (answer.questPart). Brief BQ16: the quests' part at
    -- or under the sum too (Keep.CombinedQuestPart), so the two need lines share the count alike.
    local held = type(answer) == "table" and answer or EMPTY
    local questPart = held.questPart or Keep.CombinedQuestPart(score, settings, env)
    append(Keep.KeepLines(score, have, true, true, held.surplus, questPart))
    -- Brief BQ25a (the owner's ruling for scenario i9): the hunter's pet food keep joins the counts
    -- as its own line after them.
    if keepBy == "rule" and Keep.PetKeeps(score, env) then
      lines[#lines + 1] = reason(L["Food for your pet"])
    end
    return lines, true
  end
  if keepBy == "disenchant" or (keepBy == "always" and Keep.DisenchantKeeps(score, settings)) then
    append(Keep.DisenchantKeepLines(score))
    return lines, false
  end
  if keepBy == "could" then
    -- Brief K24h: food and drink say what they are for; any other consumable as before. Brief
    -- K26: a food or drink with a buff says so instead. Brief K25: the consumable facts' own
    -- words ("Best food in your bags") where the data ships.
    if type(score.companion) == "table" then
      -- Brief TV1 (QA item 347): a companion pet item, [Use] beside its sale tags.
      lines[#lines + 1] = reason(L["Use it to learn this companion"])
    elseif score.campItem then
      -- Brief BQ23 (item 38): a camp item, never "For your Skinning".
      lines[#lines + 1] = reason(L["Camp item: a buff at a campfire"])
    elseif type(score.consumable) == "table" and type(score.consumable.words) == "string" then
      lines[#lines + 1] = reason(score.consumable.words)
    elseif Keep.ProfessionUseWords(score) then
      -- Brief BQ6 (backlog 5): a lure or device for one of the player's professions.
      lines[#lines + 1] = reason(Keep.ProfessionUseWords(score))
    elseif score.foodEffect == Keep.FOOD_EFFECT then
      lines[#lines + 1] = reason(L["Food or drink with a buff"])
    elseif Keep.IsFood(score) then
      lines[#lines + 1] = reason(L["Food or drink for your level"])
    else
      lines[#lines + 1] = reason(L["You could use this"])
    end
  end
  -- Brief K25: a consumable the facts do not keep says why, muted ("Too weak for your level").
  -- Brief TV1 (QA item 347, the owner on Thistle Tea for a warrior: "I like the idea of removing the
  -- Classes rogue druid at the bottom for purely just 'Not for your class (Rogue, Druid)'"): another
  -- class's consumable names the classes in that one line (Keep.NotForClassWords), and the muted
  -- "Classes: Rogue, Druid" line under it (SaleReasons' classUse line) goes.
  local classNamed = false
  if keepBy == nil and type(score.consumable) == "table" and score.consumable.keep == false then
    local words = score.consumable.words
    local named = score.consumable.why == "class" and Keep.NotForClassWords(score.forClasses) or nil
    if named then
      words, classNamed = named, true
    end
    if type(words) == "string" and words ~= "" then
      lines[#lines + 1] = reason(words, nil, true)
    end
  end
  -- Brief TV1 (QA item 347b, ruling D1): a recipe item no keep holds says why first, muted: "Already
  -- known", "Not your profession (Engineering)".
  if keepBy == nil then
    local words, muted = Keep.RecipeWords(score)
    if words then
      lines[#lines + 1] = reason(words, skillIcon(tonumber((score.recipe or EMPTY).skill)), muted)
    end
  end
  -- Brief JG1 (item 302): a demon grimoire the demon has learnt says so, muted, above its sale reasons.
  if keepBy == nil and Keep.PetBookLearnt(score) then
    lines[#lines + 1] = reason(Keep.PetBookLearntWords(score.petBook), nil, true)
  end
  -- Brief CB1 (item 305): a class book the player has learnt says so, muted, above its sale reasons.
  if keepBy == nil and Keep.ClassBookLearnt(score) then
    lines[#lines + 1] = reason(L["Learnt"], nil, true)
  end
  local worthless = Keep.HasTag(answer, Keep.TAG_WORTHLESS)
  -- Brief TV1 (QA item 347): under a [Use] keep (a bandage, a potion: answer.useKeep) the item is in
  -- use, so its trade lines are muted with no "Not needed to level First Aid" lead (Keep.SPARE_QUIET).
  local inUse = type(answer) == "table" and answer.useKeep == true
  local more, listed = Keep.SaleReasons(score, nil, have, true, worthless, inUse)
  -- Brief TV1: the classes are named in the consumable's own line above.
  if classNamed then
    local kept = {}
    for _, line in ipairs(more) do
      if not line.classUse then
        kept[#kept + 1] = line
      end
    end
    more = kept
  end
  append(more)
  if (keepBy == "always" or score.override == "never") and #more == 0 then
    lines[#lines + 1] = reason(Keep.NoUsesWords(score))
  end
  return lines, listed
end

-- Brief TV1 (QA item 347): "Not for your class (Rogue, Druid)", the classes a class locked consumable
-- is for (score.forClasses, ChrClasses ids, Keep.ClassName), joined by ", ", or nil for none. Pure.
function Keep.NotForClassWords(classIds)
  local names = {}
  for _, classId in ipairs(type(classIds) == "table" and classIds or EMPTY) do
    local name = Keep.ClassName(classId)
    if name then
      names[#names + 1] = name
    end
  end
  if #names == 0 then
    return nil
  end
  return string.format(L["Not for your class (%s)"], table.concat(names, ", "))
end

-- Brief AA-RB (the owner's QA item 219, 2026-10-17: "When we know there are uses (but not for your
-- current faction) make the wording 'No known uses for [your_faction]'"): the Keep block's line for an
-- item with nothing else to say under the player's Always or Never: "No known uses for Alliance" (or
-- Horde, the player's own side, score.playerSide) where a quest of the other side was all it had
-- (score.questsOtherSide while "Hide other faction data" is on, score.questsSeenOtherSide whatever it
-- says, and score.questsOtherSideFolded, the other side's repeatable or held back quests) and no
-- repeatable or held back quest of the player's own side is left (score.questsRepeat, questsGated),
-- else "No uses known". Pure. Brief UL1 (the uses line matrix's "No uses": "No uses known" here, "No
-- known uses" on the item page and in "No known uses for Alliance"): one wording, "No known uses".
function Keep.NoUsesWords(score)
  local other = 0
  if type(score) == "table" then
    other = (tonumber(score.questsOtherSide) or 0)
      + (tonumber(score.questsSeenOtherSide) or 0)
      + (tonumber(score.questsOtherSideFolded) or 0)
    if (tonumber(score.questsRepeat) or 0) + (tonumber(score.questsGated) or 0) > 0 then
      other = 0
    end
  end
  if other > 0 and score.playerSide == Keep.ALLIANCE then
    return L["No known uses for Alliance"]
  elseif other > 0 and score.playerSide == Keep.HORDE then
    return L["No known uses for Horde"]
  end
  return L["No known uses"]
end

-- Brief BQ6 (backlog 5): "For your Fishing", the soft keep's words for a profession's consumable
-- (score.professionUse, Keep.ProfessionLine), or nil where it is none or the skill is not named. Pure
-- over the data tables.
function Keep.ProfessionUseWords(score)
  local line = type(score) == "table" and tonumber(score.professionUse) or nil
  local name = line and skillName(line) or nil
  if name == nil then
    return nil
  end
  return string.format(L["For your %s"], name)
end

-- Brief BQ30 addendum (QA item 92): the Assets key of the Equip pill drawn with a spec label inside
-- ("BM, MM" is TAG_EQUIP_BM_MM, "Any spec" TAG_EQUIP_ANY_SPEC since brief EQ2), as
-- scripts/build-art.py equip_key names it.
-- nil for no label. Pure.
function Keep.EquipTagKey(label)
  if type(label) ~= "string" or label == "" then
    return nil
  end
  local key = label:upper():gsub("[^A-Z0-9]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if key == "" then
    return nil
  end
  return "TAG_EQUIP_" .. key
end

-- Brief K24b (D5): one tag's plain word. Written out one literal at a time for the locale sweep.
-- Brief BQ30 addendum (QA item 92): answer, the Tags answer, gives the Equip tag its specs,
-- "Equip (Ret, Prot)" or "Equip (Any spec)" (answer.equipSpecs; "Any" until brief EQ2); plain
-- "Equip" without them. Pure.
-- Brief FN2 (QA item 347 F): a [Keep] resting on a counted need (answer.keepCount, Keep.KeepCount)
-- reads "Keep (22)", as its tag row does (brief FN2c: [lock Keep | 22]).
function Keep.TagWord(tag, answer)
  if tag == Keep.TAG_KEEP then
    local digits = Keep.CountDigits(type(answer) == "table" and answer.keepCount or nil)
    if digits then
      return string.format(L["Keep (%s)"], digits)
    end
    return L["Keep"]
  elseif tag == Keep.TAG_EQUIP then
    local specs = type(answer) == "table" and answer.equipSpecs or nil
    if type(specs) == "string" and specs ~= "" then
      return string.format(L["Equip (%s)"], specs)
    end
    return L["Equip"]
  elseif tag == Keep.TAG_PET then
    return L["Pet food"]
  elseif tag == Keep.TAG_AUCTION then
    return L["Auction"]
  elseif tag == Keep.TAG_DISENCHANT then
    return L["Disenchant"]
  elseif tag == Keep.TAG_OPEN then
    return L["Open"]
  elseif tag == Keep.TAG_USE then
    return L["Use"]
  elseif tag == Keep.TAG_WORTHLESS then
    return L["Worthless"]
  end
  return L["Vendor"]
end

-- Brief K24b (D5): the tags in plain words, "Keep, Auction", joined by ", ", then " (No AH data)"
-- where the flag is set. nil for no tags. Brief TV1 (QA item 347): or the tag row's other note
-- (Keep.TagNote), "Keep (Not enough AH data)", "Worthless (No sell price or use)". Pure.
function Keep.TagWords(answer)
  if type(answer) ~= "table" or type(answer.tags) ~= "table" or #answer.tags == 0 then
    return nil
  end
  local words = {}
  for index, tag in ipairs(answer.tags) do
    words[index] = Keep.TagWord(tag, answer)
  end
  local text = table.concat(words, ", ")
  local note = Keep.TagNote(answer)
  if note then
    text = text .. " " .. note
  end
  return text
end

-- The note that follows the tags on their row, or nil: "(No AH data)" where no auction price is known
-- beside an Auction tag (K24b); brief TV1 (QA item 347): "(Not enough AH data)" on the three way tie's
-- [Keep] (Keep.SettleTie), and "(No sell price or use)" after [Worthless] (the owner: "lets do
-- [Worthless] (No sell price or use) and drop the 'No sell price' below"). Pure.
function Keep.TagNote(answer)
  if type(answer) ~= "table" then
    return nil
  end
  if answer.noAuctionData then
    return L["(No AH data)"]
  end
  if answer.notEnoughData then
    return L["(Not enough AH data)"]
  end
  if Keep.HasTag(answer, Keep.TAG_WORTHLESS) then
    return L["(No sell price or use)"]
  end
  return nil
end

-- Brief K24b (D1): the tag row's art, Assets keys from UI/Assets.lua (brief K24a's contract), the
-- height every tag is drawn at (one constant), and the two fixed tints. The Keep tag wears the
-- player's Keep colour and the Auction tag their Valuable colour (Keep.TagTints); the legendary
-- Auction tag is full colour art and never tinted.
Keep.TAG_ASSETS = {
  keep = "TAG_KEEP",
  equip = "TAG_EQUIP",
  pet = "TAG_PET",
  auction = "TAG_AUCTION",
  vendor = "TAG_VENDOR",
  disenchant = "TAG_DISENCHANT",
  -- Brief BQ9: the "do this now" tags, white and greys tinted the Use blue.
  open = "TAG_OPEN",
  use = "TAG_USE",
  -- Brief WL1: the Worthless tag, the Vendor tag's look in a darker grey (WORTHLESS_TINT).
  worthless = "TAG_WORTHLESS",
}
Keep.TAG_ASSET_LEGENDARY = "TAG_AUCTION_LEGENDARY"
Keep.TAG_SIZE = 17
Keep.VENDOR_TINT = { r = 0.59, g = 0.60, b = 0.63 }
-- Brief WL1: the Worthless tag's muted grey, darker than the Vendor grey (never a red).
Keep.WORTHLESS_TINT = { r = 0.40, g = 0.40, b = 0.42 }
Keep.DISENCHANT_TINT = { r = 0.64, g = 0.44, b = 0.88 }
-- The colours the Keep and Auction tags fall back to where the bag module cannot say (Theme keys).
Keep.KEEP_TINT_FALLBACK = "ITEMTREE_COLOR_KEEP_YES"
Keep.AUCTION_TINT_FALLBACK = "ITEMTREE_COLOR_KEEP_VALUE"
-- Brief BQ9: the Use blue the [Open] and [Use] tags wear (the same hue as Jettison's Use rows), and
-- its value where Theme cannot say.
Keep.USE_TINT_KEY = "ITEMTREE_COLOR_USE"
Keep.USE_TINT = { r = 0x4D / 255, g = 0xA6 / 255, b = 1 }

-- A Theme colour key as { r, g, b }, or nil. Pure over UI/Theme.lua.
local function themeColour(colorKey)
  local theme = ItemTree.Theme
  if type(theme) ~= "table" or type(theme.ColorTable) ~= "function" then
    return nil
  end
  local ok, colour = pcall(theme.ColorTable, colorKey)
  if ok and type(colour) == "table" and tonumber(colour.r) then
    return { r = colour.r, g = colour.g, b = colour.b }
  end
  return nil
end

-- Brief BQ9: the Use blue as { r, g, b }: the Theme token, else Keep.USE_TINT.
function Keep.UseTint()
  return themeColour(Keep.USE_TINT_KEY) or Keep.USE_TINT
end

-- Brief K24b (D1, E): the Keep tag's and the Auction tag's tints for these settings (the saved
-- ones unless given), each { r, g, b }: UI/Overlay.lua's one reader (Overlay.TagColours), the
-- very colours the bag looks are drawn in, else the Theme fallbacks. Reads only ItemTree's tables.
function Keep.TagTints(settings)
  if type(settings) ~= "table" then
    local db = ItemTree.db
    settings = type(db) == "table" and type(db.settings) == "table" and db.settings or {}
  end
  local ui = ItemTree.UI
  local overlay = type(ui) == "table" and ui.Overlay or nil
  local keepTint, auctionTint = nil, nil
  if type(overlay) == "table" and type(overlay.TagColours) == "function" then
    local ok, first, second = pcall(overlay.TagColours, settings)
    if ok then
      keepTint = type(first) == "table" and tonumber(first.r) and first or nil
      auctionTint = type(second) == "table" and tonumber(second.r) and second or nil
    end
  end
  return keepTint or themeColour(Keep.KEEP_TINT_FALLBACK), auctionTint or themeColour(Keep.AUCTION_TINT_FALLBACK)
end

-- One tag drawn inline, or its plain word where the art is not there at run time (brief K24a's
-- keys missing, or Assets not loaded). tint is { r, g, b } in 0 to 1, or nil for none. Pure over
-- UI/Assets.lua.
function Keep.TagMarkup(key, tint, word)
  local assets = ItemTree.Assets
  if type(assets) ~= "table" or type(assets.Has) ~= "function" or type(assets.Markup) ~= "function" then
    return word
  end
  local okHas, has = pcall(assets.Has, key)
  if not okHas or not has then
    return word
  end
  local colour = nil
  if type(tint) == "table" and tonumber(tint.r) then
    -- Both shapes, named and in order, so either reading of "{ r, g, b }" finds the colour.
    colour = { r = tint.r, g = tint.g, b = tint.b, tint.r, tint.g, tint.b }
  end
  local ok, markup = pcall(assets.Markup, key, Keep.TAG_SIZE, colour)
  if ok and type(markup) == "string" and markup ~= "" then
    return markup
  end
  return word
end

-- Brief FN2: a count's digits as a string, "22", or nil for anything that is not a whole number from 1
-- up (a count past a billion is not one a bag holds, and nil too). Pure.
function Keep.CountDigits(count)
  count = tonumber(count)
  if count == nil or count ~= count or count < 1 or count >= 1e9 then
    return nil
  end
  return string.format("%d", math.floor(count))
end

-- Brief FN2b (QA item 368, the owner's round AN, 2026-10-21): the count after a counted [Keep] pill,
-- "(51)", in the tag's own colour (tint, { r, g, b } in 0 to 1) so it reads as the pill's; plain "(51)"
-- with no tint. digits is Keep.CountDigits' string. Brief FN2c: drawn only where the counted tag's
-- segments are not there. Pure.
function Keep.CountText(digits, tint)
  local words = string.format(L["(%s)"], tostring(digits))
  if type(tint) ~= "table" or not (tonumber(tint.r) and tonumber(tint.g) and tonumber(tint.b)) then
    return words
  end
  local function byte(value)
    return math.max(0, math.min(255, math.floor(tonumber(value) * 255 + 0.5)))
  end
  return string.format("|cff%02x%02x%02x%s|r", byte(tint.r), byte(tint.g), byte(tint.b), words)
end

-- Brief FN2c (QA item 371, the owner 2026-10-21: "make a second keep tag with the right hand corners
-- cut off (i.e. straight edge) and then build the others on the left and just have one for each number
-- up to 99+"): the counted Keep tag is one pill in two segments, [lock Keep | 51], from UI/Assets.lua's
-- keep-count art (scripts/build-art.py keep-count): the Keep segment (square right edge) and one number
-- segment per count 1 to 99, "99+" for more (a dark divider down its square left edge).
Keep.KEEP_SEGMENT = "TAG_KEEP_SEGMENT"
Keep.KEEP_COUNT_PREFIX = "TAG_KEEP_COUNT_"
Keep.KEEP_COUNT_MAX = 99

-- Brief FN2c: the Assets key of a count's number segment: TAG_KEEP_COUNT_51 for 51, TAG_KEEP_COUNT_99_PLUS
-- for anything over 99 (as scripts/build-art.py keep_count_key names it), nil for no count. Pure.
function Keep.KeepCountKey(count)
  local digits = Keep.CountDigits(count)
  if digits == nil then
    return nil
  end
  if tonumber(digits) > Keep.KEEP_COUNT_MAX then
    return Keep.KEEP_COUNT_PREFIX .. Keep.KEEP_COUNT_MAX .. "_PLUS"
  end
  return Keep.KEEP_COUNT_PREFIX .. digits
end

-- Brief FN2c: the counted Keep tag drawn inline, the Keep segment then the count's number segment, two
-- escapes with nothing between them, both at Keep.TAG_SIZE in the tint, or nil where either's art is not
-- there at run time (the caller falls back). The client snaps each escape's edges to whole pixels on
-- its own (brief FN2b), so the join can open by a pixel; that pixel falls against the number segment's
-- dark divider and reads as part of it (out-fn2/fn2c-joins-preview.png). Pure over UI/Assets.lua.
function Keep.KeepCountMarkup(count, tint)
  local key = Keep.KeepCountKey(count)
  local assets = ItemTree.Assets
  if key == nil or type(assets) ~= "table" or type(assets.Has) ~= "function" then
    return nil
  end
  local parts = {}
  for index, piece in ipairs({ Keep.KEEP_SEGMENT, key }) do
    local okHas, has = pcall(assets.Has, piece)
    if not okHas or not has then
      return nil
    end
    local drawn = Keep.TagMarkup(piece, tint, nil)
    if type(drawn) ~= "string" or drawn == "" then
      return nil
    end
    parts[index] = drawn
  end
  return parts[1] .. parts[2]
end

-- Brief K24b (D1): the tag row as one line of inline textures, one space between tags, then the
-- white words "(No AH data)" where the flag is set (brief TV1: or the row's other note, Keep.TagNote);
-- each tag falls back to its word where its art is missing. nil for no tags. settings are the saved
-- ones unless given.
function Keep.TagRow(answer, settings)
  if type(answer) ~= "table" or type(answer.tags) ~= "table" or #answer.tags == 0 then
    return nil
  end
  local keepTint, auctionTint = Keep.TagTints(settings)
  local parts = {}
  for _, tag in ipairs(answer.tags) do
    local key, tint = Keep.TAG_ASSETS[tag], nil
    if tag == Keep.TAG_KEEP or tag == Keep.TAG_EQUIP or tag == Keep.TAG_PET then
      tint = keepTint
    elseif tag == Keep.TAG_AUCTION then
      if answer.legendary then
        key = Keep.TAG_ASSET_LEGENDARY
      else
        tint = auctionTint
      end
    elseif tag == Keep.TAG_DISENCHANT then
      tint = Keep.DISENCHANT_TINT
    elseif tag == Keep.TAG_OPEN or tag == Keep.TAG_USE then
      tint = Keep.UseTint()
    elseif tag == Keep.TAG_WORTHLESS then
      tint = Keep.WORTHLESS_TINT
    else
      tint = Keep.VENDOR_TINT
    end
    local word = Keep.TagWord(tag, answer)
    -- Brief BQ30 addendum (the owner's rulings of 2026-10-10, QA item 92): the specs sit INSIDE the
    -- Equip pill, one label in one font ("Equip (BM, MM)", the pill as wide as its label): the
    -- pill drawn with that label (Keep.EquipTagKey, Art/equip-tags). Where the label has no art
    -- (another locale's words), the plain Equip pill and the words after it.
    local specs = tag == Keep.TAG_EQUIP and type(answer.equipSpecs) == "string" and answer.equipSpecs or nil
    local labelled = specs and Keep.EquipTagKey(specs) or nil
    local assets = ItemTree.Assets
    if labelled and type(assets) == "table" and type(assets.Has) == "function" and assets.Has(labelled) then
      key, specs = labelled, nil
    end
    -- Brief FN2 (QA item 347 F): a [Keep] resting on a counted need carries the amount required.
    -- Brief FN2c (QA item 371, the owner's design): one pill in two segments, [lock Keep | 51], 99+
    -- over 99 (Keep.KeepCountMarkup). Where that art is not there, brief FN2b's plain Keep pill with the
    -- count after it in the pill's colour (Keep.CountText); with no art at all, the words "Keep (51)".
    local digits = tag == Keep.TAG_KEEP and Keep.CountDigits(answer.keepCount) or nil
    local drawn = digits and Keep.KeepCountMarkup(answer.keepCount, tint) or nil
    if drawn == nil then
      drawn = Keep.TagMarkup(key, tint, word)
      if digits and drawn ~= word then
        drawn = drawn .. " " .. Keep.CountText(digits, tint)
      end
    end
    if specs and drawn ~= word then
      drawn = drawn .. " " .. string.format(L["(%s)"], specs)
    end
    parts[#parts + 1] = drawn
  end
  local text = table.concat(parts, " ")
  -- Brief TV1: the row's note, whichever it is (Keep.TagNote).
  local note = Keep.TagNote(answer)
  if note then
    text = text .. " " .. note
  end
  return text
end

-- Brief K20-wire: equipment is a weapon (class 2) or armour (class 4); the gear facts weigh every
-- quality from poor (brief K24h: EQUIPMENT_QUALITY was uncommon, 2, so a grey or white piece was
-- never held against what is worn and read [Vendor] beside an empty slot), and the four rules by
-- kind (Keep.KindCounts) a Common weapon or armour. Brief K24b: Keep.Shows, which these first
-- served, is gone (the tags decide what shows, Keep.Tags rule 11).
Keep.EQUIPMENT_CLASSES = { [2] = true, [4] = true }
Keep.EQUIPMENT_QUALITY = 0

-- Brief K20b: a sale state's reason lines, and whether they list the item's uses (parts.lists):
--   the gear line (brief K20-wire)
--   then why it is not a Keep, the earlier verdict's words in its order:
--     sold everywhere (brief K1): "Sold by vendors everywhere", muted, whatever else it has
--     the rule would keep it but for the player's Never: its uses, as the Keep lines list them
--     brief K30, own profession recipes the route's count of 0 leaves unkept: "Not needed to
--       level First Aid", muted, then its uses with those recipes muted (Keep.ReagentSpare)
--     another class's spells: "Used by Shaman spells", muted
--     another class's consumable: "Class: Mage", muted (classUse, so the tooltip can leave it out)
--     one recipe of a profession the player lacks: that profession, muted (brief TB2)
--     no current use: the uses below the player's level, the quests done, the chains (TB4, TB9)
--     a current use the rule does not keep on: its uses
-- Brief K24b: no prices line any more (the client prints the prices); state and noPrices stay in
-- the signature for the callers that pass them. Brief WL1: worthless (true under a Worthless tag)
-- adds "No sell price", muted, after the gear line. Brief TV1 (QA item 347, the owner: "lets do
-- [Worthless] (No sell price or use) and drop the 'No sell price' below"): no longer; the tag row
-- carries it (Keep.TagRow), and _worthless stays in the signature for the callers that pass it.
-- Brief TV1: quiet (true under a [Use] keep, the item in use) asks the trade lines muted with no "Not
-- needed to level First Aid" lead (Keep.SPARE_QUIET). Pure.
function Keep.SaleReasons(score, _state, have, _noPrices, _worthless, quiet)
  local lines, lists = {}, false
  if type(score) ~= "table" then
    return lines, lists
  end
  -- Brief GW1 (QA item 101 (a)): a cosmetic whose appearance the account has says so, muted.
  if Keep.CosmeticCollected(score) then
    lines[#lines + 1] = reason(L["Appearance collected"], nil, true)
  end
  local gear = Keep.GearLine(score)
  if gear then
    lines[#lines + 1] = gear
  end
  -- Brief BQ25c: a bag no better than the equipped one of its kind says so, muted ("No bigger than
  -- your 14 slot bag").
  local bag = Keep.BagLine(score)
  if bag then
    lines[#lines + 1] = bag
  end
  local function append(more)
    for _, line in ipairs(more) do
      lines[#lines + 1] = line
    end
  end
  local current = tonumber(score.current) or 0
  local plain = {}
  for key, value in pairs(score) do
    plain[key] = value
  end
  plain.everywhere = false
  plain.override = nil
  local others = classWords(score.otherClasses)
  if score.everywhere and not score.profession then
    lines[#lines + 1] = reason(Keep.EverywhereWords(), nil, true)
    -- Brief K30 addendum (owner QA 2026-10-09, Bottle of Dalaran Noir sold everywhere): where the
    -- route's count of 0 leaves the player's own profession recipes out, its lines say so under it,
    -- as an item sold nowhere does (Keep.ReagentSpare).
    if Keep.ReagentSpare(score) then
      append(Keep.ReasonLines(score, have, nil, quiet and Keep.SPARE_QUIET or true))
      lists = true
    end
  elseif Keep.KeepRule(plain) then
    append(Keep.ReasonLines(score, have))
    lists = true
  elseif Keep.ReagentSpare(score) then
    -- Brief K30: the player's own profession recipes the route's count of 0 leaves unkept, said so
    -- ("Not needed to level First Aid"), the uses under it muted. Brief TV1: no lead under a [Use].
    append(Keep.ReasonLines(score, have, nil, quiet and Keep.SPARE_QUIET or true))
    lists = true
  elseif others then
    lines[#lines + 1] = reason(string.format(L["Used by %s spells"], others), nil, true)
  elseif current == 0 and type(score.forClasses) == "table" and Keep.ForClassesWords(score.forClasses) then
    local line = reason(Keep.ForClassesWords(score.forClasses), nil, true)
    line.classUse = true
    lines[#lines + 1] = line
  elseif Keep.SingleRecipe(score) == "other" or Keep.OthersOnly(score) then
    -- Brief K22: the same where the current uses are none of the player's (Keep.OthersOnly): the
    -- other professions' lines and an item combine not carried, muted under the sale's head. Brief
    -- TV1 (D1): a recipe item's own profession line too, muted under its sale ("Already known").
    local recipeItem = type(score.recipe) == "table" and Keep.SPARE_QUIET or nil
    append(Keep.ReasonLines(score, have, nil, recipeItem))
    lists = true
  elseif current == 0 and ((tonumber(score.stale) or 0) > 0 or (tonumber(score.done) or 0) > 0) then
    if (tonumber(score.stale) or 0) > 0 then
      append(staleLines(score))
    end
    -- Brief TB14: the done lines stand here because no quest use is open (current is 0, so no
    -- open quest line counts them already, Keep.QuestWords).
    append(Keep.DoneLines(score))
    -- Brief K22: the item combines, none carried here, muted.
    combineLines(score, lines, have)
    -- Brief TB9: the chains, none of them the player's here, muted under the reasons.
    chainLines(score, lines)
    lists = true
  elseif current > 0 then
    append(Keep.ReasonLines(score, have))
    lists = true
  end
  return lines, lists
end

-- Brief K20b: the Keep state's reason lines (Keep.ReasonLines), the route line first. Brief
-- K20-wire: then the gear line (Keep.GearLine). Brief TB12: withDone puts the quests done or
-- abandoned (Keep.DoneLines) under the reasons, above the gear line. Brief TB14: only where no
-- quest use is open; an open one's line already counts them (Keep.QuestWords). Brief K24b: no
-- prices line any more; noPrices stays in the signature for the callers that pass it. Brief K30:
-- surplus is Keep.Tags' answer.surplus (brief BQ16: the counts on the need lines say it now)
-- (Keep.ReasonLines). Brief INT1b: questPart, answer.questPart, the quests' part of a combined
-- count. Pure.
function Keep.KeepLines(score, have, _noPrices, withDone, surplus, questPart)
  local lines = Keep.ReasonLines(score, have, surplus, nil, questPart)
  if withDone and (tonumber((score.kinds or EMPTY).quest) or 0) == 0 then
    for _, line in ipairs(Keep.DoneLines(score)) do
      lines[#lines + 1] = line
    end
  end
  -- Brief TV1 (QA item 347, the owner on Noboru's Cudgel: "Agree though that the poor quality tag isn't
  -- needed here if its a keep for quest"): a kept piece never carries the quality line ("Poor quality",
  -- "Low quality"), which argues the other way.
  local facts = Keep.GearOf(score)
  local quality = type(facts) == "table" and (facts.poor == true or facts.common == true)
  local gear = not quality and Keep.GearLine(score) or nil
  if gear then
    lines[#lines + 1] = gear
  end
  -- Brief BQ25c: the bag rule's line ("Bigger than your 6 slot bag").
  local bag = Keep.BagLine(score)
  if bag then
    lines[#lines + 1] = bag
  end
  return lines
end

-- Brief K20-wire: "Disenchants into Soul Dust, 14 x Enchanting", the likely result the player
-- uses and its first reason, or "Disenchants into Soul Dust" where it has none to name. Pure.
function Keep.DisenchantKeepWords(score)
  local facts = type(score) == "table" and score.disenchant or nil
  local keep = type(facts) == "table" and facts.keep or nil
  if type(keep) ~= "table" then
    return nil
  end
  if type(keep.words) == "string" then
    return string.format(L["Disenchants into %s, %s"], tostring(keep.name), keep.words)
  end
  return string.format(L["Disenchants into %s"], tostring(keep.name))
end

-- Brief K20-wire: Keep (disenchant)'s lines: the material the player uses, with the Enchanting
-- glyph, then the gear line. Pure.
function Keep.DisenchantKeepLines(score)
  local lines = {}
  local words = Keep.DisenchantKeepWords(score)
  if words then
    lines[#lines + 1] = reason(words, skillIcon(Keep.ENCHANTING))
  end
  local gear = Keep.GearLine(score)
  if gear then
    lines[#lines + 1] = gear
  end
  return lines
end

-- Brief BQ25c: the bag rule's reason line, its words, muted where the bag is no better, or nil. Pure.
function Keep.BagLine(score)
  local bag = type(score) == "table" and score.bag or nil
  if type(bag) ~= "table" or type(bag.words) ~= "string" or bag.words == "" then
    return nil
  end
  return reason(bag.words, nil, bag.keep ~= true or nil)
end

-- Brief K20-wire: the gear line as a reason line, with its glyph, muted where Keep.GearWords
-- says so, or nil. Pure.
function Keep.GearLine(score)
  local words, isMuted, plain = Keep.GearWords(score)
  if not words then
    return nil
  end
  return reason(words, Keep.GEAR_ICON, isMuted, plain)
end

-- Brief K24b (D1, owner ruling 4: "a bit more top/bottom margin"): the blank line above and below
-- the tag row. A fresh table each time. Brief K24d: the one gap of the section, in the tooltip
-- too (UI/Tooltip.lua Tooltip.Gap builds its gaps from this): one blank line of the tooltip's own
-- text height, GAP_TEXT, so every gap is the same height wherever it stands. Pure.
Keep.GAP_TEXT = " "

function Keep.Spacer()
  return { text = Keep.GAP_TEXT, plain = "", colorKey = Keep.BODY_COLOR, spacer = true }
end

-- Brief K11: the verdict as the lines the tooltip and the item page draw, the same list for
-- both so they never disagree, or nil for nothing to say. Brief K24b: a blank spacer, the tag
-- row, a blank spacer, then one line per reason with its glyph (the spacer under the tags only
-- where a reason follows). Each line is
--   { text, plain, colorKey, icon = Assets key or nil, muted = true or nil, head = true or nil,
--     tags = Keep.Tags' answer on the tag row, spacer = true on a blank line }
-- text is what is drawn (the tag row's inline textures; a blank " " for a spacer), plain the
-- words with no escape in them where they differ from Keep.Plain(text) (the tag row's "Keep,
-- Auction (No AH data)", "" for a spacer). The reasons are in Keep.BodyColor(tone), a muted reason
-- (a profession the player lacks) in the muted grey, its glyph still at full colour. The second
-- answer is the tone. have as TooltipParts (brief PR9); env is Keep.Tags'. Pure apart from the
-- art and colour reads of Keep.TagRow.
function Keep.VerdictLines(score, have, settings, env)
  local parts = Keep.TooltipParts(score, have, settings, env)
  if not parts then
    return nil
  end
  -- Brief GW1b: a reason alone (Keep.ReasonAloneParts) has no tag row.
  local tagLine = nil
  local lines = { Keep.Spacer() }
  if type(parts.head) == "string" then
    tagLine = {
      text = Keep.TagRow(parts.tags, settings) or parts.head,
      plain = parts.head,
      colorKey = Keep.BODY_COLOR,
      head = true,
      tags = parts.tags,
    }
    lines[2] = tagLine
  elseif type(parts.lines) ~= "table" or #parts.lines == 0 then
    return nil
  end
  local function body(held, bodyKey)
    local line = { text = Keep.Uncoloured(held.text), colorKey = bodyKey, icon = held.icon }
    -- Brief K24e: a reason's own plain words (the gear line's "13 to 28" where the arrow is drawn).
    if type(held.plain) == "string" then
      line.plain = held.plain
    end
    if held.muted then
      line.muted = true
      line.colorKey = Keep.MUTED_COLOR
    end
    -- Brief TBR2: the muted "For Mages" is marked, so the tooltip can leave it out where its uses
    -- line already says whose the item is ("Mages use it").
    if held.classUse then
      line.classUse = true
    end
    -- Brief BQ7: a use that is not the player's, for the tooltip's fold (Keep.MarkOtherUse).
    if held.other then
      line.other = true
      line.otherUses = held.otherUses
    end
    -- Brief BQ14: a profession line's qualities, the tooltip's circles after the count.
    if tonumber(held.qualities) and held.qualities > 0 then
      line.qualities = held.qualities
    end
    -- Brief TV1 (QA item 347b): a profession's recipe line (Keep.ReasonLines' group mark).
    if held.group then
      line.group = true
      -- Brief UL3: and its profession and count (Tooltip.FoldBehindUses).
      line.groupName, line.groupCount = held.groupName, held.groupCount
    end
    lines[#lines + 1] = line
  end
  local reasons = parts.lines or EMPTY
  if #reasons > 0 and tagLine ~= nil then
    lines[#lines + 1] = Keep.Spacer()
  end
  local bodyKey = Keep.BodyColor(parts.tone)
  for _, held in ipairs(reasons) do
    body(held, bodyKey)
  end
  -- Brief K20b: whether the lines list the item's uses (the tooltip's uses line steps aside), on
  -- the leading spacer and the tag row both, so a reader of either line finds it.
  if parts.lists == false then
    lines[1].lists = false
    if tagLine then
      tagLine.lists = false
    end
  end
  return lines, parts.tone
end

-- The verdict as plain words, its lines joined by new lines with the spacers left out, or nil. For
-- the specs and a width measure. have as TooltipParts (brief PR9). Pure.
function Keep.TooltipText(score, have, settings, env)
  local lines = Keep.VerdictLines(score, have, settings, env)
  if not lines then
    return nil
  end
  local words = {}
  for _, line in ipairs(lines) do
    if not line.spacer then
      words[#words + 1] = line.plain or line.text
    end
  end
  return table.concat(words, "\n")
end

-- "Alliance only" or "Horde only" for a use the player cannot take, else nil. For a row in the
-- Sources or Uses view that knows its edge's faction.
function Keep.FactionOnly(faction, playerFaction)
  if not Keep.OtherSide(faction, playerFaction) then
    return nil
  end
  if faction == Keep.ALLIANCE then
    return L["Alliance only"]
  end
  return L["Horde only"]
end

-- The player's side as the edge field spells it, from the client's word. Pure.
function Keep.FactionOf(word)
  if word == "Alliance" then
    return Keep.ALLIANCE
  end
  if word == "Horde" then
    return Keep.HORDE
  end
  return nil
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

-- Brief GW1 (QA item 101 (a)): whether the account has collected an item's appearance, the
-- client's own answer (C_TransmogCollection.PlayerHasTransmog, the call the item's "You haven't
-- collected this appearance" line rests on): true, false, or nil where the client has no such call
-- or its answer cannot be read (a secret value, an error). One read for the one item being scored;
-- never called over a list.
function Keep.AppearanceCollected(itemId)
  local id = tonumber(itemId)
  local collection = rawget(_G, "C_TransmogCollection")
  if id == nil or type(collection) ~= "table" or type(collection.PlayerHasTransmog) ~= "function" then
    return nil
  end
  local ok, has = pcall(collection.PlayerHasTransmog, id)
  if not ok then
    return nil
  end
  local util = ItemTree.Util
  if type(util) == "table" and type(util.CanRead) == "function" and not util.CanRead(has) then
    return nil
  end
  if has == true then
    return true
  end
  if has == false then
    return false
  end
  return nil
end

-- Brief AA-RB (the owner's QA item 216, 2026-10-17): item id -> true or false, the client's Toy Box
-- answer, read once per id per session (Keep.IsToy); Keep.Reset lets it go. Brief TF1: the client's
-- answers alone, never the shipped list's (Keep.ShippedToy). Brief TOY2: a false here is the client's
-- no, which the shipped list's yes still overrules (Keep.IsToy).
Keep.toys = {}

-- Brief TF1 (item 230 (c) of the QA run back; the owner on 2026-10-18: "Yes for the toy data build flag
-- if it will help with offline tests"): whether the shipped toy list names the item. The list is the
-- client's own Toy table as ItemTree-Data ships it, ItemTree_Data's Toys module ({ [itemId] = 1 },
-- itemtree_data/toys.py), and Jettison's Facts.lua carries the same one. true for an item it names, false
-- for any other, nil where the data ships no list (a compile before brief TF1, the specs' fixtures).
-- Keep.IsToy reads it where the client cannot answer, and (brief TOY2) where its Toy Box says no: the
-- list also names the toys the server alone knows. Pure over the data tables.
function Keep.ShippedToy(itemId)
  local id = tonumber(itemId)
  local d = data()
  if id == nil or not d or type(d.Get) ~= "function" then
    return nil
  end
  local ok, toys = pcall(d.Get, d, "Toys")
  if not ok or type(toys) ~= "table" then
    return nil
  end
  return toys[id] == 1
end

-- Brief AA-RB (QA item 216: Adventurer's Tent 288185, new in 1.60.1.70450, a toy the client lists in
-- its Toy table): whether the item is a toy, by the client's Toy Box, C_ToyBox.GetToyInfo(itemId),
-- whose first two answers are the item's id and the toy's name. Blizzard's own Toy Box asks it the
-- same way and takes an item as no toy where either is nil (wow-ui-source, branch forever,
-- Interface/AddOns/Blizzard_Collections/Classic/Blizzard_ToyBox.lua:242 to 245; the same call at
-- Mainline/AlertFrameSystems.lua:1294 in Blizzard_FrameXML). The client's answer comes first (the in
-- game self test proves it on the real client: the persona keep case for the tent). One local lookup
-- for the one item a tooltip or a bag slot shows, never a loop over a list. Brief TF1: where the client
-- cannot answer (no Toy Box, an error, an answer it keeps secret (bible B10), and every offline test),
-- the shipped toy list answers (Keep.ShippedToy), not held, so a readable answer later still wins. nil
-- where neither can say, which is no toy. Guarded.
-- Brief TOY2 (the owner's QA item 303, 2026-10-20: Night Watchman's Torch 280612, a toy in Forever, a
-- plain bag item with no toy label): a toy the server alone knows is in neither the client's ItemSparse
-- nor its Toy table, so the Toy Box names no toy for it. The shipped list carries it (ItemTree-Data's
-- curated/server_toys.json beside the Toy table), so where the Toy Box says no, the list's yes still
-- makes it a toy: a toy where either names one.
function Keep.IsToy(itemId)
  local id = tonumber(itemId)
  if id == nil then
    return nil
  end
  local held = Keep.toys[id]
  if held == nil then
    local box = rawget(_G, "C_ToyBox")
    if type(box) ~= "table" or type(box.GetToyInfo) ~= "function" then
      return Keep.ShippedToy(id)
    end
    local ok, toyItem, toyName = pcall(box.GetToyInfo, id)
    if not ok then
      return Keep.ShippedToy(id)
    end
    local util = ItemTree.Util
    if type(util) == "table" and type(util.CanRead) == "function" then
      if not util.CanRead(toyItem) or not util.CanRead(toyName) then
        return Keep.ShippedToy(id)
      end
    end
    held = toyItem ~= nil and toyName ~= nil
    Keep.toys[id] = held
  end
  if held then
    return true
  end
  -- Brief TOY2: the Toy Box's no, and the shipped list's word over it (a server only toy).
  return Keep.ShippedToy(id) == true
end

-- Brief BQ13: the pretend held count of one item (/itemtree demo have), or nil where none is set:
-- every held count below asks it before the client.
function Keep.DemoHave(itemId)
  local demo = demoState()
  if demo and type(demo.Have) == "function" then
    local ok, count = pcall(demo.Have, itemId)
    if ok and tonumber(count) then
      return tonumber(count)
    end
  end
  return nil
end

-- Brief PR9: the player's count of one item, bags and bank, for the route line's "12 / 40
-- needed", or nil where the route needs none of it (or the module is off). One local read for
-- the one item a tooltip shows; never called over a list.
function Keep.ProfessionHave(itemId)
  local info = Keep.ProfessionRelevant(itemId)
  local need = type(info) == "table" and tonumber(info.need) or nil
  if not need or need <= 0 then
    return nil
  end
  local id = tonumber(itemId)
  local pretend = Keep.DemoHave(id)
  if pretend then
    return pretend
  end
  local itemApi = rawget(_G, "C_Item")
  if type(itemApi) == "table" and type(itemApi.GetItemCount) == "function" then
    local ok, count = pcall(itemApi.GetItemCount, id, true)
    if ok and tonumber(count) then
      return tonumber(count)
    end
  end
  local legacy = rawget(_G, "GetItemCount")
  if type(legacy) == "function" then
    local ok, count = pcall(legacy, id, true)
    if ok and tonumber(count) then
      return tonumber(count)
    end
  end
  return nil
end

-- Brief K30: what the route's count is worked out from, or nil: the Professions model (only while
-- its tab is on and loaded, Keep.ProfessionModel) with PR9's NeededFor and its Facts (the player's
-- skills, the same read its Current set is built from), and the shipped ProfessionTracks lines.
-- { lines, skills, needed = the model's NeededFor }. Keep.reagentFacts stands one in for a spec: a
-- table, or false for none. No item is asked about.
function Keep.ReagentFacts()
  if Keep.reagentFacts ~= nil then
    return Keep.reagentFacts or nil
  end
  local model = Keep.ProfessionModel()
  if not model or type(model.NeededFor) ~= "function" or type(model.Facts) ~= "function" then
    return nil
  end
  local tracks = ItemTree.ProfessionTracks
  local lines = type(tracks) == "table" and tracks.lines or nil
  if type(lines) ~= "table" then
    return nil
  end
  local ok, skills = pcall(model.Facts)
  if not ok or type(skills) ~= "table" then
    return nil
  end
  return { lines = lines, skills = skills, needed = model.NeededFor }
end

-- Brief K30: the route's count for one item over its trade lines (Keep.TradeLines), or nil where it
-- cannot be worked out (Keep.ReagentNeed; the module off). One lookup in the model's cached pass.
function Keep.ReagentNeedFor(itemId, lines)
  local id = tonumber(itemId)
  if not id or type(lines) ~= "table" or #lines == 0 then
    return nil
  end
  local facts = Keep.ReagentFacts()
  if type(facts) ~= "table" or type(facts.needed) ~= "function" then
    return nil
  end
  local ok, entry = pcall(facts.needed, id)
  if not ok then
    return nil
  end
  return Keep.ReagentNeed(lines, facts.lines, facts.skills, entry)
end

-- Brief Q1: the player's count of one item, bags and bank, where a quest only keep holds it to the
-- count its quests ask for (Keep.QuestKeepUpTo over the item's cached score), else nil. One local
-- read for the one item a tooltip shows; never called over a list.
function Keep.QuestHave(itemId, playerLevel, playerFaction)
  local id = tonumber(itemId)
  if not id or type(Keep.CachedScore) ~= "function" then
    return nil
  end
  local scored, score = pcall(Keep.CachedScore, id, playerLevel, playerFaction)
  -- Brief BQ18: or a working stock keep (Keep.StockCap), whose words weigh the count against a stack.
  -- Brief UL1: or any need line the uses lines show (Keep.WantsHave: the quests' count, a crate's).
  if not scored or not Keep.WantsHave(score) then
    return nil
  end
  local pretend = Keep.DemoHave(id)
  if pretend then
    return pretend
  end
  local itemApi = rawget(_G, "C_Item")
  if type(itemApi) == "table" and type(itemApi.GetItemCount) == "function" then
    local ok, count = pcall(itemApi.GetItemCount, id, true)
    if ok and tonumber(count) then
      return tonumber(count)
    end
  end
  local legacy = rawget(_G, "GetItemCount")
  if type(legacy) == "function" then
    local ok, count = pcall(legacy, id, true)
    if ok and tonumber(count) then
      return tonumber(count)
    end
  end
  return nil
end

-- Brief K20-wire: the worn map and its signature (Core/Gear.lua Gear.WornState, held there until
-- PLAYER_EQUIPMENT_CHANGED), or nil, nil where Gear is not loaded or the client will not say.
function Keep.WornFacts()
  local gear = ItemTree.Gear
  if type(gear) ~= "table" or type(gear.WornState) ~= "function" then
    return nil, nil
  end
  local ok, worn, signature = pcall(gear.WornState)
  if not ok or type(worn) ~= "table" then
    return nil, nil
  end
  return worn, signature
end

-- Brief BQ25c: one client call under pcall, the answer as a number, or nil.
local function clientNumber(name, ...)
  local container = rawget(_G, "C_Container")
  local fn = type(container) == "table" and rawget(container, name) or nil
  if type(fn) ~= "function" then
    fn = rawget(_G, name)
  end
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if ok then
    return tonumber(value)
  end
  return nil
end

-- Brief BQ25c: the item id in an equipped bag slot (its container id), or nil.
local function bagItemId(bag)
  local slot = clientNumber("ContainerIDToInventoryID", bag)
  local read = rawget(_G, "GetInventoryItemID")
  if slot == nil or type(read) ~= "function" then
    return nil
  end
  local ok, id = pcall(read, "player", slot)
  return ok and tonumber(id) or nil
end

-- Brief BQ25c: the bag slots the rule reads, 1 to 4 (NUM_BAG_SLOTS where the client states it).
Keep.BAG_SLOT_COUNT = 4

--- Brief BQ25c: the client's equipped bags as Keep.BagStateOf's state: the four normal bag slots by
--- their slots and item ids, and Forever's reagent bag slot (Enum.BagIndex.ReagentBag) where the
--- client has one (nil on a client without it). The backpack and the keyring are never read. nil
--- where the client cannot say. Questions about the player, never about an item.
function Keep.ReadBags()
  if rawget(_G, "C_Container") == nil and rawget(_G, "GetContainerNumSlots") == nil then
    return nil
  end
  local count = tonumber(rawget(_G, "NUM_BAG_SLOTS")) or Keep.BAG_SLOT_COUNT
  local shape = { sizes = {}, items = {} }
  for bag = 1, math.min(count, Keep.BAG_SLOT_COUNT) do
    local size = clientNumber("GetContainerNumSlots", bag) or 0
    shape.sizes[bag] = size
    if size > 0 then
      shape.items[bag] = bagItemId(bag)
    end
  end
  for bag = count + 1, Keep.BAG_SLOT_COUNT do
    shape.sizes[bag] = 0
  end
  -- Brief BG1: the spare bags carried, the bank's bags as last read at the bank, and the cap.
  Keep.AddSpareShape(shape)
  local state = Keep.BagStateOf(shape, itemRow)
  local enum = rawget(_G, "Enum")
  local index = type(enum) == "table" and rawget(enum, "BagIndex") or nil
  local reagentBag = type(index) == "table" and tonumber(rawget(index, "ReagentBag")) or nil
  if state and reagentBag == nil then
    state.reagent = nil
  elseif state then
    local size = clientNumber("GetContainerNumSlots", reagentBag) or 0
    local family, kind = 0, nil
    if size > 0 then
      local bagKind, bit = Keep.BagKind(itemRow(bagItemId(reagentBag)))
      family = bit or 0
      -- Brief F160: the kind of bag in the slot (a reagent bag, or a warlock's soul bag), by its row,
      -- else (no row, or a general bag the client let in) by its family bit.
      if bagKind == nil or bagKind == Keep.BAG_NORMAL then
        bagKind = Keep.ReagentSlotKind(family)
      end
      kind = bagKind
    end
    state.reagent = { size = size, family = family, kind = kind }
  end
  return state
end

--- Brief BQ25c: the bag state the rule reads: the demo's pretend bags while they are on (Demo.Bags,
--- `/itemtree demo bags`), else the client's (Keep.ReadBags), held until the bags or the worn set move
--- (Keep.BagsMoved, PLAYER_EQUIPMENT_CHANGED) or Keep.Reset. nil where neither says.
function Keep.BagState()
  local demo = demoState()
  if demo and type(demo.Bags) == "function" then
    local ok, bags = pcall(demo.Bags)
    if ok and type(bags) == "table" then
      -- Brief BG1: with the spare bags carried and the bank (the demo's, else the last read).
      local shape = { sizes = bags.sizes, items = bags.items, reagent = bags.reagent }
      return Keep.BagStateOf(Keep.AddSpareShape(shape), itemRow)
    end
  end
  -- Brief BG1: a pretend bank (`/itemtree demo bank`) over the client's own bags, read each time
  -- (the carried walk is held, Keep.CarriedBags).
  if Keep.DemoBank() ~= nil then
    return Keep.ReadBags()
  end
  if Keep.bagState ~= nil then
    return Keep.bagState or nil
  end
  local state = Keep.ReadBags()
  Keep.bagState = state or false
  return state
end

--- Brief BQ25c: on a bag update, whether the equipped bags moved (a bag put in, taken out or swapped):
--- the held read is dropped and read again, and its signature compared. Never true while the demo's
--- bags stand (Demo.Apply drops the scores itself).
function Keep.BagsMoved()
  local held = Keep.bagState
  if held == nil then
    return false
  end
  local before = Keep.BagSignature(held or nil)
  Keep.bagState = nil
  -- Brief BG1: the carried bags walked again too.
  Keep.carriedBags = nil
  local state = Keep.ReadBags()
  Keep.bagState = state or false
  return Keep.BagSignature(state) ~= before
end

-- Brief K20-wire: the player's Enchanting rank (Core/DisenchantValue.lua, held there until
-- SKILL_LINES_CHANGED), or nil for none or where the module is not loaded.
function Keep.EnchantingRank()
  local values = ItemTree.DisenchantValue
  if type(values) ~= "table" or type(values.EnchantingRank) ~= "function" then
    return nil
  end
  local ok, rank = pcall(values.EnchantingRank)
  if ok then
    return tonumber(rank)
  end
  return nil
end

-- The player's class as a ChrClasses id (UnitClass's third answer), read once and kept until
-- Keep.Reset: a question about the player, never about an item. nil where the client will not say.
function Keep.PlayerClass()
  -- Brief BQ14 follow up: the pretend class (/itemtree demo class, Core/Demo.lua) while it is set.
  local demo = demoState()
  local pretend = demo and type(demo.ClassId) == "function" and demo.ClassId() or nil
  if pretend ~= nil then
    return pretend
  end
  if Keep.playerClass ~= nil then
    return Keep.playerClass
  end
  local unitClass = rawget(_G, "UnitClass")
  if type(unitClass) ~= "function" then
    return nil
  end
  local ok, _, _, classId = pcall(unitClass, "player")
  classId = ok and tonumber(classId) or nil
  Keep.playerClass = classId
  return classId
end

-- Brief K1: the skill line ids a list of profession names stands for, every line of each name (a
-- build can list one profession twice), out of the Skills table. Pure over the data tables.
local function idsNamed(names, into)
  local d = data()
  if not d or type(d.Get) ~= "function" or next(names) == nil then
    return into
  end
  local ok, skills = pcall(d.Get, d, "Skills")
  for id, row in pairs(ok and type(skills) == "table" and skills or EMPTY) do
    if type(id) == "number" and type(row) == "table" and names[row.n] then
      into[id] = true
    end
  end
  return into
end

-- Every answer of a call, nils included, with n the count. Pure.
local function packed(...)
  return { n = select("#", ...), ... }
end

-- The modern shape: GetProfessions answers up to five indices (two professions, then archaeology,
-- fishing and cooking), and GetProfessionInfo(index) answers the name first and the skill line
-- seventh. nil where the client has neither. Brief TB2: every index it answers is read, so a
-- client that adds first aid as a sixth (the Cataclysm shape) has its secondary professions
-- counted as the player's too.
local function modernProfessions(names, ids)
  local getProfessions = rawget(_G, "GetProfessions")
  local getInfo = rawget(_G, "GetProfessionInfo")
  if type(getProfessions) ~= "function" or type(getInfo) ~= "function" then
    return false
  end
  local answer = packed(pcall(getProfessions))
  if not answer[1] then
    return false
  end
  for index = 2, answer.n do
    local slot = answer[index]
    if type(slot) == "number" then
      local ok, name, _, _, _, _, _, skillLine = pcall(getInfo, slot)
      if ok then
        if type(name) == "string" and name ~= "" then
          names[name] = true
        end
        if tonumber(skillLine) then
          ids[tonumber(skillLine)] = true
        end
      end
    end
  end
  return true
end

-- The classic shape: the skill sheet's lines by name (GetNumSkillLines, GetSkillLineInfo), headers
-- left out. Weapon skills and languages come along and never match a recipe's line.
local function classicProfessions(names)
  local count = rawget(_G, "GetNumSkillLines")
  local info = rawget(_G, "GetSkillLineInfo")
  if type(count) ~= "function" or type(info) ~= "function" then
    return false
  end
  local ok, total = pcall(count)
  total = ok and tonumber(total) or nil
  if not total then
    return false
  end
  for index = 1, total do
    local gotInfo, name, isHeader = pcall(info, index)
    if gotInfo and not isHeader and type(name) == "string" and name ~= "" then
      names[name] = true
    end
  end
  return true
end

-- Brief K1: the player's professions as a set of skill line ids, read once and kept until
-- SKILL_LINES_CHANGED or Keep.Reset: a question about the player, never about an item. nil where
-- the client will not say, and then the Keep line names no profession at all.
function Keep.PlayerProfessions()
  -- Brief PR42: the developer's pretend professions (UI/PlayerSkills.lua DemoSet) replace the
  -- player's own while they are on.
  local skills = ItemTree.UI and ItemTree.UI.PlayerSkills
  if type(skills) == "table" and type(skills.DemoSet) == "function" then
    local pretend = skills.DemoSet()
    if pretend then
      return pretend
    end
  end
  if Keep.professionsRead then
    return Keep.professions
  end
  local names, ids = {}, {}
  local read = modernProfessions(names, ids)
  if not read then
    read = classicProfessions(names)
  end
  Keep.professionsRead = true
  Keep.professions = read and idsNamed(names, ids) or nil
  return Keep.professions
end

-- Brief TP1 (the owner's QA item 210 and his ruling A of 2026-10-17: "a tracked range also KEEPS
-- those items as if the character had the profession at that range"): the skill line set Keep scores
-- with. The player's own professions (real, Keep.PlayerProfessions' answer) with every profession the
-- character tracks at a range on the Professions tab joined (Core/TrackedProfessions.lua Tracked.Set;
-- "none" tracks nothing), so the recipe uses and the route's count count a tracked profession as the
-- character's own (brief RB2A: never the working stock; brief TG1: a tracked gathering line only the
-- recipes its range can make, Keep.GatherInRange). Only while the tab is on and loaded (Keep.ProfessionModel): the
-- list is the tab's, and with it off the tab keeps no route at all. real itself where nothing is
-- tracked or real is not known (the client did not say; tracking never makes it say). The joined set
-- is held until real, the list (its generation) or the saved table moves, or Keep.Reset, so Keep's
-- cache key holds it as it holds Keep.professions (Keep.HeldProfessions).
function Keep.KeepProfessions(real)
  if type(real) ~= "table" then
    return real
  end
  local tracked = ItemTree.TrackedProfessions
  if type(tracked) ~= "table" or type(tracked.Set) ~= "function" or not Keep.ProfessionModel() then
    return real
  end
  local held = Keep.keptProfessions
  local charDb = ItemTree.charDb
  if
    type(held) == "table"
    and held.real == real
    and held.generation == tracked.generation
    and held.charDb == charDb
  then
    return held.set
  end
  local set = real
  local ok, extra = pcall(tracked.Set, real, Keep.IsOwnSkill)
  if ok and type(extra) == "table" and type(tracked.Join) == "function" then
    set = tracked.Join(real, extra)
  end
  Keep.keptProfessions = { real = real, generation = tracked.generation, charDb = charDb, set = set }
  return set
end

-- Brief TP1: whether a skill line set is one Keep holds unchanged between reads, so the score cache's
-- key may keep its signature: Keep.professions, or the joined set Keep.KeepProfessions holds. Pure
-- over Keep's own fields.
function Keep.HeldProfessions(professions)
  if type(professions) ~= "table" then
    return false
  end
  if professions == Keep.professions then
    return true
  end
  local held = Keep.keptProfessions
  return type(held) == "table" and professions == held.set
end

-- Brief K1: whether the player has completed a quest, one C_QuestLog.IsQuestFlaggedCompleted call
-- per quest, remembered: a yes for the session, a no until the next quest is turned in. The guard
-- is UI/InfoPanel.lua ReadQuest's. false where the client will not say.
function Keep.QuestCompleted(questId)
  if type(questId) ~= "number" or questId <= 0 then
    return false
  end
  -- Brief BQ13: a pretend quest (/itemtree demo quest) answers first, and is never held.
  local demo = demoState()
  if demo and type(demo.QuestCompleted) == "function" then
    local ok, pretend = pcall(demo.QuestCompleted, questId)
    if ok and pretend ~= nil then
      return pretend == true
    end
  end
  local held = Keep.completed[questId]
  if held ~= nil then
    return held
  end
  local questLog = rawget(_G, "C_QuestLog")
  local ask = type(questLog) == "table" and questLog.IsQuestFlaggedCompleted or nil
  local answer = false
  if type(ask) == "function" then
    local ok, done = pcall(ask, questId)
    answer = ok and done == true
  end
  Keep.completed[questId] = answer
  -- Brief TB4: a quest once dropped and since completed is done, not abandoned.
  if answer then
    Keep.ForgetAbandoned(questId)
  end
  return answer
end

--------------------------------------------------------------------------------
-- Abandoned quests (brief TB4). The client has no "abandoned" flag, so the addon remembers, per
-- character, the quests that left the log without being turned in: a set of quest ids in
-- ItemTreeCharDB (ItemTree.charDb.keepAbandoned = { [questId] = true }), made on the first one.
-- Ids only: nothing about the character is stored. An id goes again when the quest is taken
-- again (QUEST_ACCEPTED), turned in, or found flagged completed.
--------------------------------------------------------------------------------

-- The saved set, made where create asks and the saved variables are there to hold it.
local function abandonedStore(create)
  local charDb = ItemTree.charDb
  if type(charDb) ~= "table" then
    return nil
  end
  local store = charDb.keepAbandoned
  if type(store) ~= "table" then
    if not create then
      return nil
    end
    store = {}
    charDb.keepAbandoned = store
  end
  return store
end

-- Whether this character took the quest and dropped it. Pure over ItemTree.charDb.
function Keep.QuestAbandoned(questId)
  -- Brief BQ13: a pretend quest is in the log, done or not taken, never abandoned.
  local demo = demoState()
  if demo and type(demo.QuestPretended) == "function" then
    local ok, pretended = pcall(demo.QuestPretended, questId)
    if ok and pretended then
      return false
    end
  end
  local store = type(questId) == "number" and abandonedStore(false) or nil
  return store ~= nil and store[questId] == true
end

-- Records a quest as abandoned. Answers whether the set changed.
function Keep.MarkAbandoned(questId)
  if type(questId) ~= "number" or questId <= 0 then
    return false
  end
  local store = abandonedStore(true)
  if not store or store[questId] == true then
    return false
  end
  store[questId] = true
  return true
end

-- Forgets a quest's abandoned mark. Answers whether the set changed.
function Keep.ForgetAbandoned(questId)
  local store = type(questId) == "number" and abandonedStore(false) or nil
  if not store or store[questId] == nil then
    return false
  end
  store[questId] = nil
  return true
end

-- The quests that left the log since the last QUEST_LOG_UPDATE without a QUEST_TURNED_IN, by id.
-- QUEST_REMOVED can come before QUEST_TURNED_IN for one turn in, so a removal is only judged on
-- the next QUEST_LOG_UPDATE (Keep.SettleRemoved). Not saved.
Keep.removed = {}

-- The quest id an event names first, or nil. QUEST_ACCEPTED on the retail shaped engine the
-- Forever client runs names the quest id alone; Classic Era names the log index and then the id.
local function acceptedId(first, second)
  local questId = tonumber(second) or tonumber(first)
  if not questId or questId <= 0 or questId ~= math.floor(questId) then
    return nil
  end
  return questId
end

-- Whether the client flags a quest completed right now, asked afresh (a held "no" is not
-- trusted here). false where the client will not say.
local function flaggedNow(questId)
  local questLog = rawget(_G, "C_QuestLog")
  local ask = type(questLog) == "table" and questLog.IsQuestFlaggedCompleted or nil
  if type(ask) ~= "function" then
    return false
  end
  local ok, done = pcall(ask, questId)
  return ok and done == true
end

-- Brief TB4: judges the quests that left the log: one turned in (QUEST_TURNED_IN named it, or the
-- client flags it completed) is done, any other was abandoned. Answers whether anything moved.
function Keep.SettleRemoved()
  local moved = false
  for questId in pairs(Keep.removed) do
    Keep.removed[questId] = nil
    if Keep.completed[questId] == true or flaggedNow(questId) then
      Keep.completed[questId] = true
      if Keep.ForgetAbandoned(questId) then
        moved = true
      end
    elseif Keep.MarkAbandoned(questId) then
      moved = true
    end
  end
  return moved
end

-- Paints the bags and empties the tooltip's block cache again, through their own public calls.
local function repaint()
  local tooltip = ItemTree.Tooltip
  if type(tooltip) == "table" and type(tooltip.ClearCache) == "function" then
    pcall(tooltip.ClearCache)
  end
  local ui = ItemTree.UI
  local overlay = type(ui) == "table" and ui.Overlay or nil
  if type(overlay) == "table" then
    if type(overlay.Forget) == "function" then
      pcall(overlay.Forget)
    end
    if type(overlay.Queue) == "function" then
      pcall(overlay.Queue)
    end
  end
end

-- Brief K4: Keep.SetOverride paints through this.
Keep.Repaint = repaint

-- Brief K22: whether the player carries an item in their bags (the bank left out): true, false,
-- or nil where the client will not say. One count call for one via item, never over a list and
-- never an item data request; the answer is asked through Util.CanRead before any compare.
function Keep.Carries(itemId)
  local id = tonumber(itemId)
  if not id then
    return nil
  end
  local pretend = Keep.DemoHave(id)
  if pretend then
    return pretend > 0
  end
  local itemApi = rawget(_G, "C_Item")
  local ask = type(itemApi) == "table" and itemApi.GetItemCount or nil
  if type(ask) ~= "function" then
    ask = rawget(_G, "GetItemCount")
  end
  if type(ask) ~= "function" then
    return nil
  end
  local ok, count = pcall(ask, id)
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

-- Brief K22: on a bag change, each cached score that rests on a carried via item asks the bags
-- again, one Keep.Carries call per distinct via item among those scores (none at all while no
-- scored item has an item combine use); a score whose answer moved is dropped and the bags and
-- tooltip are painted again. Answers whether anything was dropped.
function Keep.RecheckCarried()
  local asked, moved = {}, false
  -- Brief K22 (merge KSM3): a disenchant material's own held score (Keep.materialScores) is dropped
  -- the same way; the item scores resting on it watch its via items too (Keep.MaterialCarried).
  for materialId, held in pairs(Keep.materialScores) do
    if type(held) == "table" and type(held.viaCarried) == "table" then
      for via, was in pairs(held.viaCarried) do
        if asked[via] == nil then
          asked[via] = Keep.Carries(via) == true
        end
        if asked[via] ~= was then
          Keep.materialScores[materialId] = nil
          moved = true
          break
        end
      end
    end
  end
  for itemId, score in pairs(Keep.carryWatch) do
    if Keep.cache[itemId] ~= score or type(score.viaCarried) ~= "table" then
      Keep.carryWatch[itemId] = nil
    else
      for via, was in pairs(score.viaCarried) do
        if asked[via] == nil then
          asked[via] = Keep.Carries(via) == true
        end
        if asked[via] ~= was then
          Keep.cache[itemId] = nil
          Keep.carryWatch[itemId] = nil
          moved = true
          break
        end
      end
    end
  end
  -- Brief BQ18 (QA item 11): a worn item's carried upgrade, read again (Keep.CarriedUpgrade).
  for wornId, was in pairs(Keep.outdoneWatch) do
    local _, upgrade = Keep.CarriedUpgrade(wornId)
    if (upgrade or false) ~= was then
      Keep.outdoneWatch[wornId] = nil
      moved = true
    end
  end
  if moved then
    repaint()
  end
  return moved
end

-- Brief WS1 (the owner's ruling "A for writs" of 2026-10-17 night): on a bag, bank or quest log change,
-- each cached score that rests on a quest's starter (Keep.starterWatch) asks Core/QuestFlags.lua
-- StarterHeldBack again, once per distinct quest among those scores (nothing at all while no scored item
-- has such a quest); a score whose answer moved is dropped and the bags and tooltip are painted again, so
-- a writ picked up, banked, used or the quest taken keeps or frees the item at once. Answers whether
-- anything was dropped.
function Keep.RecheckStarters()
  local flags = ItemTree.QuestFlags
  if type(flags) ~= "table" or type(flags.StarterHeldBack) ~= "function" then
    return false
  end
  local asked, moved = {}, false
  for slot, score in pairs(Keep.starterWatch) do
    if Keep.cache[slot] ~= score or type(score.starterWatch) ~= "table" then
      Keep.starterWatch[slot] = nil
    else
      for questId, was in pairs(score.starterWatch) do
        if asked[questId] == nil then
          local ok, now = pcall(flags.StarterHeldBack, questId)
          asked[questId] = ok and now == true
        end
        if asked[questId] ~= was then
          Keep.cache[slot] = nil
          Keep.starterWatch[slot] = nil
          moved = true
          break
        end
      end
    end
  end
  if moved then
    repaint()
  end
  return moved
end

-- Brief IW1 (the owner's ruling 1B of 2026-10-22: a provided item keeps while its quest is in the log): on
-- a quest taken or the log changed, each cached score that rests on whether a provided item's quest is
-- in the log (Keep.providedWatch) asks Keep.QuestInLog again, once per distinct quest among those scores
-- (nothing at all while no scored item has one); a score whose answer moved is dropped and the bags and
-- tooltip are painted again, so the Soul Gem keeps the moment Saving Yenniku is taken. A quest turned in
-- or abandoned drops every score already (Keep.OnEvent). Answers whether anything was dropped.
function Keep.RecheckProvided()
  local asked, moved = {}, false
  for slot, score in pairs(Keep.providedWatch) do
    if Keep.cache[slot] ~= score or type(score.providedWatch) ~= "table" then
      Keep.providedWatch[slot] = nil
    else
      for questId, was in pairs(score.providedWatch) do
        -- Brief AQF2 (M2): the watch holds ProvidedInLog's true or false, so the log's unknown (nil) reads
        -- as false here too and a log that cannot say drops nothing.
        if asked[questId] == nil then
          asked[questId] = Keep.QuestInLog(questId) == true
        end
        if asked[questId] ~= was then
          Keep.cache[slot] = nil
          Keep.providedWatch[slot] = nil
          moved = true
          break
        end
      end
    end
  end
  if moved then
    repaint()
  end
  return moved
end

-- Brief RF375 (the review's M1): on a quest taken, dropped or the log changed, each cached finished score
-- that rests on whether the quest log wants its item (Keep.logWatch) asks Keep.LogWants again (the log's
-- objectives are read at most once per change, Core/QuestFlags.lua LogWantsItem; nothing at all while no
-- scored item is finished); a score whose answer moved is dropped and the bags and tooltip are painted
-- again, so an item the quest just taken asks for loses its finished verdict at once. Where the log
-- changed again inside QuestFlags.LOG_REBUILD_SECONDS, one more pass is booked for when the next read
-- is due (C_Timer.After), so the change still lands. Answers whether anything was dropped.
Keep.logRecheckBooked = false

function Keep.RecheckLogWants()
  local moved = false
  for slot, score in pairs(Keep.logWatch) do
    local watch = type(score) == "table" and score.logWatch or nil
    if Keep.cache[slot] ~= score or type(watch) ~= "table" then
      Keep.logWatch[slot] = nil
    elseif Keep.LogWants(watch.itemId, watch.name) ~= watch.wants then
      Keep.cache[slot] = nil
      Keep.logWatch[slot] = nil
      moved = true
    end
  end
  if moved then
    repaint()
  end
  local flags = ItemTree.QuestFlags
  local pending = next(Keep.logWatch) ~= nil
    and type(flags) == "table"
    and type(flags.LogPending) == "function"
    and flags.LogPending() == true
  if pending and not Keep.logRecheckBooked then
    local timer = rawget(_G, "C_Timer")
    local after = type(timer) == "table" and rawget(timer, "After") or nil
    local wait = tonumber(flags.LOG_REBUILD_SECONDS) or 1
    if
      type(after) == "function"
      and pcall(after, wait, function()
        Keep.logRecheckBooked = false
        -- Under the boundary (Core/Guard.lua), as every timer callback of ours.
        local guard = ItemTree.Guard
        if type(guard) == "table" and type(guard.Run) == "function" then
          guard.Run("Keep.RecheckLogWants", Keep.RecheckLogWants)
        else
          Keep.RecheckLogWants()
        end
      end)
    then
      Keep.logRecheckBooked = true
    end
  end
  return moved
end

--------------------------------------------------------------------------------
-- Brief K24b: what Keep.Tags is handed from the client (env), and the owner's session only
-- pretend values (/itemtree demo price, money, level). Memory only: nothing here is saved.
--------------------------------------------------------------------------------

-- The pretend values, nil while off: demoPrice (an auction price per item in copper for every
-- item, Keep.ItemPrices), demoMoney (the money carried, Keep.Money), demoLevel (the player's
-- level for the Keep rules only, Keep.CachedScore) and, brief K24d, demoDisenchant (what every
-- disenchant material is worth each, Core/DisenchantValue.lua DisenchantValue.MaterialPrice).
Keep.demoPrice = nil
Keep.demoMoney = nil
Keep.demoLevel = nil
Keep.demoDisenchant = nil
Keep.DEMO_KINDS = { price = "demoPrice", money = "demoMoney", level = "demoLevel", disenchant = "demoDisenchant" }

-- Sets or clears one pretend value ("price", "money", "level" or "disenchant"; value a whole
-- number, or nil for off) and drops every held score and repaints, so the bags and the tooltip
-- read it at once. Answers whether the kind was known.
function Keep.SetDemo(kind, value)
  local field = Keep.DEMO_KINDS[kind]
  if not field then
    return false
  end
  value = tonumber(value)
  if value ~= nil then
    value = math.floor(value)
  end
  Keep[field] = value
  -- Brief K24d: the disenchant materials' pretend price lives with their prices, whose held
  -- answers it drops.
  if kind == "disenchant" then
    local values = ItemTree.DisenchantValue
    if type(values) == "table" and type(values.SetDemoPrice) == "function" then
      pcall(values.SetDemoPrice, value)
    end
  end
  Keep.DropScores()
  repaint()
  return true
end

-- The money the player carries, in copper (the pretend money while set), or nil where the client
-- will not say. One GetMoney call, a question about the player and never about an item; the
-- answer is asked through Util.CanRead before any compare (bible B10).
--------------------------------------------------------------------------------
-- Brief K26: the client side of the pet food rule, every read of the pet and the bags local to
-- the client (no server query, bible B10: every answer through Util.CanRead before a compare):
--   Keep.PetFamily()        the family of the pet out, for a hunter with one (UnitCreatureFamily),
--                           else nil; the one question that gates everything below
--   Keep.PetEats(id, family) whether the pet eats the item, C_PetInfo.CanPetEatItem under pcall,
--                           held per family per item (Keep.petEats, the way Jettison holds it);
--                           nil where the client will not say
--   Keep.SlotCount(bag, slot, id) the stack count of one bag slot, C_Container.GetContainerItemInfo
--   Keep.PetFoodStacks(family, level, faction) the bag stacks of food the pet eats, each
--                           { id, count, level }, less a reagent of the player's trade (its cached
--                           score keeps it by rule) and a food with a buff (Keep.FOOD_EFFECT); one
--                           walk of the five bags, one CanPetEatItem per item id not yet held
--   Keep.PetFor(id, bag, slot, level, faction) what Keep.Tags reads as env.pet for the item a
--                           tooltip shows: { eats = true, keep = Keep.PetFoodKeep's answer }, or nil
--                           for anyone but a hunter with a pet out that eats the item
--   Keep.MaxLevel()         the level cap, GetMaxPlayerLevel or Keep.MAX_LEVEL
--------------------------------------------------------------------------------

Keep.HUNTER_CLASS = 3
Keep.PET_BAGS = { 0, 1, 2, 3, 4 }
Keep.petEats = {}

local function readable(value)
  local util = ItemTree.Util
  if type(util) == "table" and type(util.CanRead) == "function" then
    return util.CanRead(value)
  end
  return true
end

-- Brief JG1 (item 302): whether the summoned pet's spell book knows a spell, for a warlock's demon
-- grimoire (Keep.PetBookFacts), asked for the one item scored and the ranks of its one ability, never a
-- pass over a list. C_SpellBook.IsSpellKnown with the pet's bank is the Forever client's call
-- (wow-ui-source, branch forever at 1.60.1 70245: Blizzard_APIDocumentationGenerated/
-- SpellBookDocumentation.lua:738, its spellBank argument :746; SpellBookConstantsDocumentation.lua:43,
-- Enum.SpellBookSpellBank.Pet), IsSpellKnown(spellId, true) the older shape; the first a client has
-- answers, each pcalled, and an answer the client keeps secret (bible B10) reads as not known. A
-- demon that is not summoned knows nothing here, so its books stay kept. A read of the spell book,
-- never a server query. The same read as UI/Tree.lua Tree.PetSpellKnown (brief PL1).
function Keep.PetSpellKnown(spellId)
  spellId = tonumber(spellId)
  if not spellId then
    return false
  end
  local calls = {}
  local book = rawget(_G, "C_SpellBook")
  local enum = rawget(_G, "Enum")
  local banks = type(enum) == "table" and enum.SpellBookSpellBank or nil
  local petBank = type(banks) == "table" and banks.Pet or nil
  if type(book) == "table" and type(book.IsSpellKnown) == "function" and petBank ~= nil then
    local ask = book.IsSpellKnown
    calls[#calls + 1] = function()
      return ask(spellId, petBank)
    end
  end
  local older = rawget(_G, "IsSpellKnown")
  if type(older) == "function" then
    calls[#calls + 1] = function()
      return older(spellId, true)
    end
  end
  for _, call in ipairs(calls) do
    local ok, known = pcall(call)
    if ok then
      -- Asked before the answer is compared with anything at all.
      if not readable(known) then
        return false
      end
      if known ~= nil then
        return known == true
      end
    end
  end
  return false
end

-- Brief JG1: drops the held scores of the demon grimoires (score.petBook), the pet's spells having
-- moved (a demon summoned, dismissed or taught a rank). Answers how many went.
function Keep.DropPetBookScores()
  local dropped = 0
  for slot, score in pairs(Keep.cache) do
    if type(score) == "table" and type(score.petBook) == "table" then
      Keep.cache[slot] = nil
      dropped = dropped + 1
    end
  end
  return dropped
end

-- Brief CB1 (item 305): whether the player's own spell book knows a spell, for a class book
-- (Keep.ClassBookFacts), asked for the one item scored and the ranks of its one spell, never a pass
-- over a list. The same read as UI/Tree.lua Tree.SpellKnown (brief CT1, a class trainer's Learnt),
-- which Core cannot reach: C_SpellBook.IsSpellKnown is the Forever client's call (wow-ui-source,
-- branch forever at 1.60.1 70245: Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua:738,
-- its spellBank argument :746 the player's by default), IsPlayerSpell and IsSpellKnown the older
-- ones; the first a client has answers, each pcalled, and an answer the client keeps secret (bible
-- B10) reads as not known, as does no answer at all, so a book is never sold on a guess. A read of
-- the spell book, never a server query. A pretend class (`/itemtree demo class`) reads the
-- character's own book, which knows none of another class's spells, so its books stay kept.
function Keep.PlayerSpellKnown(spellId)
  spellId = tonumber(spellId)
  if not spellId then
    return false
  end
  local calls = {}
  local book = rawget(_G, "C_SpellBook")
  if type(book) == "table" and type(book.IsSpellKnown) == "function" then
    calls[#calls + 1] = book.IsSpellKnown
  end
  for _, name in ipairs({ "IsPlayerSpell", "IsSpellKnown" }) do
    local fn = rawget(_G, name)
    if type(fn) == "function" then
      calls[#calls + 1] = fn
    end
  end
  for _, fn in ipairs(calls) do
    local ok, known = pcall(fn, spellId)
    if ok then
      -- Asked before the answer is compared with anything at all.
      if not readable(known) then
        return false
      end
      if known ~= nil then
        return known == true
      end
    end
  end
  return false
end

-- Brief TV1 (D1): drops the held scores of the recipe items (score.recipe), a recipe having been
-- learnt. Answers how many went.
function Keep.DropRecipeScores()
  local dropped = 0
  for slot, score in pairs(Keep.cache) do
    if type(score) == "table" and type(score.recipe) == "table" then
      Keep.cache[slot] = nil
      dropped = dropped + 1
    end
  end
  return dropped
end

-- Brief CB1: drops the held scores of the class books (score.classBook), the player's spells having
-- moved (a spell learnt from a trainer or a book). Answers how many went.
function Keep.DropClassBookScores()
  local dropped = 0
  for slot, score in pairs(Keep.cache) do
    if type(score) == "table" and type(score.classBook) == "table" then
      Keep.cache[slot] = nil
      dropped = dropped + 1
    end
  end
  return dropped
end

function Keep.PetFamily()
  if Keep.PlayerClass() ~= Keep.HUNTER_CLASS then
    return nil
  end
  -- Brief ST5: the pretend pet (/itemtree demo pet) while it is set. Brief ST6 (bin E2): and while
  -- the demo speaks for the pet at all (a case with no pet out), the character's own pet is not read.
  local demo = demoState()
  if demo and type(demo.PetPretended) == "function" and demo.PetPretended() then
    return demo.PetFamily()
  end
  local exists = rawget(_G, "UnitExists")
  local family = rawget(_G, "UnitCreatureFamily")
  if type(exists) ~= "function" or type(family) ~= "function" then
    return nil
  end
  local okPet, hasPet = pcall(exists, "pet")
  if not okPet or not readable(hasPet) or hasPet ~= true then
    return nil
  end
  local okName, name = pcall(family, "pet")
  if not okName or not readable(name) then
    return nil
  end
  if type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

function Keep.PetEats(itemId, family)
  local id = tonumber(itemId)
  if not id or type(family) ~= "string" then
    return nil
  end
  -- Brief ST5: a pretend pet eats the foods its command named (the client answers for a real pet).
  local demo = demoState()
  if demo and type(demo.PetFamily) == "function" and demo.PetFamily() == family then
    return demo.PetEats(id)
  end
  local held = Keep.petEats[family]
  if type(held) ~= "table" then
    held = {}
    Keep.petEats[family] = held
  end
  if held[id] ~= nil then
    return held[id]
  end
  local petApi = rawget(_G, "C_PetInfo")
  local ask = type(petApi) == "table" and petApi.CanPetEatItem or nil
  if type(ask) ~= "function" then
    return nil
  end
  local ok, answer = pcall(ask, id)
  if not ok or not readable(answer) or (answer ~= true and answer ~= false) then
    return nil
  end
  held[id] = answer
  return answer
end

local function slotInfo(bag, slot)
  local container = rawget(_G, "C_Container")
  local ask = type(container) == "table" and container.GetContainerItemInfo or nil
  if type(ask) ~= "function" then
    return nil
  end
  local ok, info = pcall(ask, bag, slot)
  if not ok or type(info) ~= "table" then
    return nil
  end
  local id, count = info.itemID, info.stackCount
  if not readable(id) or not readable(count) then
    return nil
  end
  return tonumber(id), tonumber(count)
end

function Keep.SlotCount(bag, slot, itemId)
  bag, slot = tonumber(bag), tonumber(slot)
  if bag == nil or slot == nil then
    return nil
  end
  local id, count = slotInfo(bag, slot)
  if id == nil or (itemId ~= nil and id ~= tonumber(itemId)) then
    return nil
  end
  return count
end

function Keep.PetFoodStacks(family, playerLevel, playerFaction)
  local stacks = {}
  local container = rawget(_G, "C_Container")
  local slotsOf = type(container) == "table" and container.GetContainerNumSlots or nil
  if type(slotsOf) ~= "function" then
    return stacks
  end
  local counts = {}
  for _, bag in ipairs(Keep.PET_BAGS) do
    local ok, slots = pcall(slotsOf, bag)
    slots = ok and readable(slots) and tonumber(slots) or 0
    for slot = 1, slots do
      local id, count = slotInfo(bag, slot)
      if id and Keep.PetEats(id, family) == true then
        if counts[id] == nil then
          local score = Keep.CachedScore(id, playerLevel, playerFaction)
          local judged = type(score) == "table" and (Keep.KeepRule(score) or score.foodEffect == Keep.FOOD_EFFECT)
          counts[id] = not judged
        end
        if counts[id] then
          local row = itemRow(id)
          local level = type(row) == "table" and (tonumber(row.rl) or tonumber(row.il)) or nil
          stacks[#stacks + 1] = { id = id, count = count or 1, level = level or 0 }
        end
      end
    end
  end
  return stacks
end

function Keep.PetFor(itemId, bag, slot, playerLevel, playerFaction)
  local id = tonumber(itemId)
  if not id then
    return nil
  end
  local family = Keep.PetFamily()
  if family == nil or Keep.PetEats(id, family) ~= true then
    return nil
  end
  local count = Keep.SlotCount(bag, slot, id)
  local stacks = Keep.PetFoodStacks(family, playerLevel, playerFaction)
  return { eats = true, keep = Keep.PetFoodKeep(stacks, id, count) }
end

--------------------------------------------------------------------------------
-- Brief K31: the client side of the profession tool rule, every read local to the client (no item
-- query; bible B10: every answer through Util.CanRead before a compare):
--   Keep.CarriedTools()      the listed tools in the bags, each { id, row, bag, slot, bagKind,
--                            bagFamily } (brief F160: the bag's kind and family bit, Keep.BagKind of the
--                            bag item in that bag slot, nil for the backpack): one walk of
--                            the backpack, the four bags and the reagent bag where the client has
--                            one, held until the bags change (BAG_UPDATE_DELAYED, Keep.ForgetTools);
--                            in combat the last walk held answers. The pretend held items (/itemtree
--                            demo have) count as carried, after every real slot.
--   Keep.ToolFor(id, bag, slot, professions)  what Keep.Tags reads as env.tool for one copy
--                            (Keep.ToolAnswer over the walk), nil for anything but a tool of one of
--                            the player's professions
--------------------------------------------------------------------------------

Keep.TOOL_BAGS = { 0, 1, 2, 3, 4, 5 }
Keep.toolWalk = nil
Keep.toolWalkStale = false

-- Whether the client is in combat lockdown (false where it cannot say).
local function toolsInCombat()
  local locked = rawget(_G, "InCombatLockdown")
  if type(locked) ~= "function" then
    return false
  end
  local ok, answer = pcall(locked)
  return ok and answer == true
end

-- The bags changed: the next read walks them again (in combat, the walk held still answers until
-- combat ends). Answers whether the held walk had a tool in it, so the bags paint again.
function Keep.ForgetTools()
  local had = type(Keep.toolWalk) == "table" and #Keep.toolWalk > 0
  Keep.toolWalkStale = true
  if not toolsInCombat() then
    Keep.toolWalk = nil
  end
  return had
end

-- Whether an item id is a listed tool, its row read only for an id the list does not name (a
-- fishing pole by its subclass).
local function isTool(id)
  if Keep.ToolSkills(id, nil) ~= nil then
    return true
  end
  return Keep.ToolSkills(id, itemRow(id)) ~= nil
end

function Keep.CarriedTools()
  if Keep.toolWalk ~= nil and (not Keep.toolWalkStale or toolsInCombat()) then
    return Keep.toolWalk
  end
  local list = {}
  local demo = demoState()
  local pretend = demo and type(demo.HaveList) == "function" and demo.HaveList() or EMPTY
  local container = rawget(_G, "C_Container")
  local slotsOf = type(container) == "table" and container.GetContainerNumSlots or nil
  if type(slotsOf) == "function" then
    for _, bag in ipairs(Keep.TOOL_BAGS) do
      local ok, slots = pcall(slotsOf, bag)
      slots = ok and readable(slots) and tonumber(slots) or 0
      -- Brief F160 (item 165): the bag's kind and family, asked once per bag that holds a tool.
      local bagKind, bagFamily, asked = nil, nil, bag == 0
      for slot = 1, slots do
        local id = slotInfo(bag, slot)
        -- A pretend count of 0 hides the real copies, as for the consumables (Keep.CarriedConsumables).
        if id and (tonumber(pretend[id]) or 1) > 0 and isTool(id) then
          if not asked then
            asked = true
            bagKind, bagFamily = Keep.BagKind(itemRow(bagItemId(bag)))
          end
          list[#list + 1] =
            { id = id, row = itemRow(id), bag = bag, slot = slot, bagKind = bagKind, bagFamily = bagFamily }
        end
      end
    end
  end
  local ids = {}
  for id, count in pairs(pretend) do
    if (tonumber(count) or 0) > 0 and isTool(id) then
      ids[#ids + 1] = id
    end
  end
  table.sort(ids)
  for _, id in ipairs(ids) do
    for _ = 1, math.floor(tonumber(pretend[id]) or 0) do
      list[#list + 1] = { id = id, row = itemRow(id) }
    end
  end
  Keep.toolWalk = list
  Keep.toolWalkStale = false
  return list
end

function Keep.ToolFor(itemId, bag, slot, professions)
  local id = tonumber(itemId)
  if not id then
    return nil
  end
  if professions == nil and type(Keep.PlayerProfessions) == "function" then
    professions = Keep.PlayerProfessions()
  end
  local row = itemRow(id)
  local facts = Keep.ToolFacts(id, row, professions)
  if type(facts) ~= "table" or not facts.own then
    return nil
  end
  return Keep.ToolAnswer(facts, Keep.CarriedTools(), id, row, tonumber(bag), tonumber(slot), professions)
end

--------------------------------------------------------------------------------
-- Brief BG1 (QA item 83, the owner's rulings of 2026-10-13): the client side of the spare bag rule,
-- every read local to the client (no item query; bible B10: every answer through Util.CanRead), and
-- never a Blizzard frame touched (the events come to Keep's own frame):
--   Keep.CarriedBags()   the bag items in the backpack and the four bags (ids, one per copy), the
--                        bags a spare can be; held until the bags change (Keep.BagsMoved). The
--                        pretend held items (/itemtree demo have) that are bags count as carried.
--   Keep.BankMax()       the cap: the bank's bag slots with every slot bought. On the Forever client
--                        the character bank is tabs: tab 1 is the bank's own slots and tabs 2 to
--                        C_Bank.FetchMaxNumBankTabs(Enum.BankType.Character) are the bank bag slots
--                        (Blizzard_UIPanels_Game/Camelot/BankFrame.lua, RefreshBagButtons: "for
--                        bagNum = 2, maxBankBags", the bag in slot n at (Enum.BagIndex.Characterbanktab,
--                        n), its contents in container Enum.BagIndex.CharacterBankTab_1 + n - 1,
--                        GetExactBankTabSlot), so the count is that less one; else the Classic
--                        NUM_BANKBAGSLOTS; else BANK_BAG_SLOTS (7).
--   Keep.ReadBank()      the bank's bag slots (bought ones only: tab n is bought when n is no more
--                        than C_Bank.FetchNumPurchasedBankTabs; an unbought slot is not empty) and the
--                        bags lying in the bank, read only while the bank is open (BANKFRAME_OPENED
--                        to BANKFRAME_CLOSED) and held for the rest of the session (Keep.bankHeld):
--                        nothing in the bank moves while it is closed, so the held read stays true
--                        whether or not the client keeps the bank readable after the visit.
--------------------------------------------------------------------------------

Keep.CARRIED_BAGS = { 0, 1, 2, 3, 4 }
-- The bank events Keep's frame hears (BANK_TABS_CHANGED: a bank bag slot bought on Forever).
Keep.BANK_EVENT_LIST = { "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "BANK_TABS_CHANGED" }
Keep.BANK_EVENTS = {}
for _, event in ipairs(Keep.BANK_EVENT_LIST) do
  Keep.BANK_EVENTS[event] = true
end
Keep.carriedBags = nil
Keep.bankHeld = nil
Keep.bankOpen = false

-- One client call under pcall (C_Container's, else the global), its answer where readable.
local function readClient(space, name, ...)
  local api = space and rawget(_G, space) or nil
  local fn = type(api) == "table" and rawget(api, name) or nil
  if type(fn) ~= "function" and space == "C_Container" then
    fn = rawget(_G, name)
  end
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if not ok or not readable(value) then
    return nil
  end
  return value
end

local function numberOf(space, name, ...)
  return tonumber(readClient(space, name, ...))
end

-- Whether an item id is a bag the spare rule could keep (a normal bag of SPARE_BAG_MIN slots or
-- more; QA item 153: never a quiver or ammo pouch; brief RB5, QA item 206: never a reagent bag),
-- its row read from ItemTree's own data.
local function spareCandidate(id)
  local row = itemRow(id)
  local kind = Keep.BagKind(row)
  if not Keep.BankableKind(kind) then
    return false
  end
  return (tonumber(row.cs) or 0) >= Keep.SPARE_BAG_MIN
end

-- The candidate bag ids in one container, appended to into.
local function bagsIn(container, into)
  local slots = numberOf("C_Container", "GetContainerNumSlots", container) or 0
  for slot = 1, slots do
    local id = numberOf("C_Container", "GetContainerItemID", container, slot)
    if id and spareCandidate(id) then
      into[#into + 1] = id
    end
  end
  return into
end

function Keep.CarriedBags()
  if Keep.carriedBags ~= nil then
    return Keep.carriedBags
  end
  local list = {}
  if rawget(_G, "C_Container") ~= nil or rawget(_G, "GetContainerNumSlots") ~= nil then
    for _, bag in ipairs(Keep.CARRIED_BAGS) do
      bagsIn(bag, list)
    end
  end
  local demo = demoState()
  local pretend = demo and type(demo.HaveList) == "function" and demo.HaveList() or EMPTY
  local ids = {}
  for id, count in pairs(pretend) do
    if (tonumber(count) or 0) > 0 and spareCandidate(id) then
      ids[#ids + 1] = id
    end
  end
  table.sort(ids)
  for _, id in ipairs(ids) do
    for _ = 1, math.min(Keep.BANK_BAG_SLOTS * 2, math.floor(tonumber(pretend[id]) or 0)) do
      list[#list + 1] = id
    end
  end
  Keep.carriedBags = list
  return list
end

--------------------------------------------------------------------------------
-- Brief F160 follow up (the report's point 4, the coordinator's ruling of 2026-10-14): the item page
-- shows the item, not a copy, so an equipped Old Blanchy's Feed Pouch read [Equip] "Bigger than your 6
-- slot bag" there (the bag rule weighs it against the other worn bags). Where the character has the
-- bag in one of the bag slots (the four bags or the reagent bag slot) and carries no other copy in
-- the bags, the page reads [Keep] "Equipped bag" as the bag bar's hover does (UI/InfoPanel.lua
-- InfoPanel.KeepRows); with a copy carried the bag rule's verdict for that copy stands.
--------------------------------------------------------------------------------

--- Brief F160: Keep.WORN_BAG where itemId is among equipped (the bag item ids in the bag slots, a
--- list) and carried (the copies of itemId in the bags, a count) is 0, else nil. Pure.
function Keep.EquippedBagPage(itemId, equipped, carried)
  local id = tonumber(itemId)
  if id == nil or (tonumber(carried) or 0) > 0 then
    return nil
  end
  for _, held in ipairs(type(equipped) == "table" and equipped or EMPTY) do
    if tonumber(held) == id then
      return Keep.WORN_BAG
    end
  end
  return nil
end

-- Brief F160: the bag item in bag slot (container) bag, asked of the client through Util.CanRead, or nil.
local function equippedBagId(bag)
  local slot = numberOf("C_Container", "ContainerIDToInventoryID", bag)
  local ask = rawget(_G, "GetInventoryItemID")
  if slot == nil or type(ask) ~= "function" then
    return nil
  end
  local ok, id = pcall(ask, "player", slot)
  if not ok or not readable(id) then
    return nil
  end
  return tonumber(id)
end

--- Brief F160: the client's answer for the item page, Keep.EquippedBagPage over the bag items in the
--- four bag slots and the reagent bag slot and the copies of itemId in the backpack and the four bags
--- (Keep.CARRIED_BAGS). Only an item whose row is a bag is asked about, the bag slots first (five
--- calls); the bags are walked only for a bag the character has equipped, stopping at the first copy.
--- Questions about the player, never about an item; every answer through Util.CanRead. nil for none.
function Keep.EquippedBagAlone(itemId)
  local id = tonumber(itemId)
  if id == nil or Keep.BagKind(itemRow(id)) == nil then
    return nil
  end
  if rawget(_G, "C_Container") == nil then
    return nil
  end
  local equipped = {}
  local count = tonumber(rawget(_G, "NUM_BAG_SLOTS")) or Keep.BAG_SLOT_COUNT
  for bag = 1, math.min(count, Keep.BAG_SLOT_COUNT) do
    equipped[#equipped + 1] = equippedBagId(bag)
  end
  local enum = rawget(_G, "Enum")
  local index = type(enum) == "table" and rawget(enum, "BagIndex") or nil
  local reagentBag = type(index) == "table" and tonumber(rawget(index, "ReagentBag")) or nil
  if reagentBag ~= nil then
    equipped[#equipped + 1] = equippedBagId(reagentBag)
  end
  if Keep.EquippedBagPage(id, equipped, 0) == nil then
    return nil
  end
  local carried = 0
  for _, bag in ipairs(Keep.CARRIED_BAGS) do
    local slots = numberOf("C_Container", "GetContainerNumSlots", bag) or 0
    for slot = 1, slots do
      if numberOf("C_Container", "GetContainerItemID", bag, slot) == id then
        carried = 1
        break
      end
    end
    if carried > 0 then
      break
    end
  end
  return Keep.EquippedBagPage(id, equipped, carried)
end

-- The Forever client's bank enums: the character bank type, the first tab's container and the
-- container that holds the bank bag items, or nil on a client without bank tabs.
local function bankEnums()
  local enum = rawget(_G, "Enum")
  local index = type(enum) == "table" and rawget(enum, "BagIndex") or nil
  local types = type(enum) == "table" and rawget(enum, "BankType") or nil
  if type(index) ~= "table" or rawget(_G, "C_Bank") == nil then
    return nil
  end
  local first = tonumber(rawget(index, "CharacterBankTab_1"))
  local holder = tonumber(rawget(index, "Characterbanktab"))
  if first == nil or holder == nil then
    return nil
  end
  local character = type(types) == "table" and tonumber(rawget(types, "Character")) or 0
  return character, first, holder
end

function Keep.BankMax()
  local character = bankEnums()
  if character ~= nil then
    local tabs = numberOf("C_Bank", "FetchMaxNumBankTabs", character)
    if tabs and tabs > 1 then
      return tabs - 1
    end
  end
  local constant = tonumber(rawget(_G, "NUM_BANKBAGSLOTS"))
  if constant and constant > 0 then
    return constant
  end
  return Keep.BANK_BAG_SLOTS
end

-- The Forever read: tabs 2 to the most bought are the bank bag slots.
local function readTabs(character, first, holder)
  local bought = numberOf("C_Bank", "FetchNumPurchasedBankTabs", character)
  local tabs = numberOf("C_Bank", "FetchMaxNumBankTabs", character)
  if bought == nil or tabs == nil then
    return nil
  end
  local shape = { sizes = {}, items = {}, stored = {} }
  for tab = 1, math.min(bought, tabs) do
    local container = first + tab - 1
    bagsIn(container, shape.stored)
    if tab >= 2 then
      local size = numberOf("C_Container", "GetContainerNumSlots", container) or 0
      shape.sizes[tab - 1] = size
      if size > 0 then
        shape.items[tab - 1] = numberOf("C_Container", "GetContainerItemID", holder, tab)
      end
    end
  end
  return shape
end

-- The Classic read: the bank's own container and the bought bank bag slots after the bags.
local function readClassicBank()
  local bought = nil
  local fn = rawget(_G, "GetNumBankSlots")
  if type(fn) == "function" then
    local ok, value = pcall(fn)
    bought = ok and readable(value) and tonumber(value) or nil
  end
  if bought == nil then
    return nil
  end
  local shape = { sizes = {}, items = {}, stored = {} }
  bagsIn(tonumber(rawget(_G, "BANK_CONTAINER")) or -1, shape.stored)
  local bags = tonumber(rawget(_G, "NUM_BAG_SLOTS")) or Keep.BAG_SLOT_COUNT
  for slot = 1, bought do
    local container = bags + slot
    bagsIn(container, shape.stored)
    local size = numberOf("C_Container", "GetContainerNumSlots", container) or 0
    shape.sizes[slot] = size
    if size > 0 then
      shape.items[slot] = bagItemId(container)
    end
  end
  return shape
end

function Keep.ReadBank()
  local character, first, holder = bankEnums()
  if character ~= nil then
    return readTabs(character, first, holder)
  end
  return readClassicBank()
end

--- Brief BG1: the pretend bank (`/itemtree demo bank`, Demo.Bank: { sizes, items }), or nil.
function Keep.DemoBank()
  local demo = demoState()
  if demo and type(demo.Bank) == "function" then
    local ok, bank = pcall(demo.Bank)
    if ok and type(bank) == "table" then
      return bank
    end
  end
  return nil
end

--- Brief BG1: shape (a bag state's shape, Keep.BagStateOf's) with the spare facts joined: carried,
--- bank (the demo's, else the session's last read, nil before the first visit) and bankMax.
function Keep.AddSpareShape(shape)
  if type(shape) ~= "table" then
    return shape
  end
  shape.carried = Keep.CarriedBags()
  shape.bank = Keep.DemoBank() or Keep.bankHeld
  shape.bankMax = Keep.BankMax()
  return shape
end

--- Brief BG1: the bank opened, changed or closed. Opening (and any bag or bank change while it is
--- open) reads it again; closing keeps the held read. Answers whether the bank read moved.
function Keep.OnBank(event)
  if event == "BANKFRAME_CLOSED" then
    Keep.bankOpen = false
    return false
  end
  if event == "BANKFRAME_OPENED" then
    Keep.bankOpen = true
  end
  if not Keep.bankOpen then
    return false
  end
  local before = Keep.bankHeld
  local read = Keep.ReadBank()
  if read == nil then
    return false
  end
  Keep.bankHeld = read
  return before == nil
    or Keep.BagSignature(Keep.BagStateOf({ sizes = {}, bank = before }, itemRow))
      ~= Keep.BagSignature(Keep.BagStateOf({ sizes = {}, bank = read }, itemRow))
end

--- Brief BG1: forget the bank read (a spec's clean slate).
function Keep.ForgetBank()
  Keep.bankHeld = nil
  Keep.bankOpen = false
end

-- Brief K25: the player's pools (Consumables.Pools) for the restore shares, read per cold score.
function Keep.Pools()
  local consumables = ItemTree.Consumables
  if type(consumables) ~= "table" or type(consumables.Pools) ~= "function" then
    return nil
  end
  local ok, pools = pcall(consumables.Pools)
  if ok and type(pools) == "table" then
    return pools
  end
  return nil
end

-- Brief K25: the consumables in the bags the facts cover, each { facts, row, id }, less the item
-- asked about, for Consumables.BetterUsable. One walk of bags 0 to 4 (the slot read of brief K26),
-- one facts read per item id; nil until the ItemEffects module ships, so nothing is walked for
-- an addon without it. A cold score reads it once; BAG_UPDATE_DELAYED drops the scores that read
-- it (Keep.DropConsumableScores), so a better potion picked up moves the lesser one's verdict.
function Keep.CarriedConsumables(itemId)
  local consumables = ItemTree.Consumables
  if type(consumables) ~= "table" or type(consumables.Module) ~= "function" then
    return nil
  end
  local module = consumables.Module()
  if type(module) ~= "table" then
    return nil
  end
  local container = rawget(_G, "C_Container")
  local slotsOf = type(container) == "table" and container.GetContainerNumSlots or nil
  if type(slotsOf) ~= "function" then
    return nil
  end
  local list, seen = {}, {}
  local skip = tonumber(itemId)
  -- Brief BQ13: the pretend held items count as carried (a pretend 0 as not carried).
  local demo = demoState()
  local pretend = demo and type(demo.HaveList) == "function" and demo.HaveList() or EMPTY
  for id, count in pairs(pretend) do
    if count <= 0 then
      seen[id] = true
    end
  end
  local function take(id)
    seen[id] = true
    local facts = consumables.Facts(id, module)
    -- Brief K25d: a consumable only, as the seam in Keep.Score judges (a quest item or a
    -- trinket with a restore is no better potion).
    local row = facts and itemRow(id) or nil
    if row and tonumber(row.c) == Keep.CONSUMABLE_CLASS then
      list[#list + 1] = { id = id, facts = facts, row = row }
    end
  end
  for id, count in pairs(pretend) do
    if count > 0 and id ~= skip and not seen[id] then
      take(id)
    end
  end
  for _, bag in ipairs(Keep.PET_BAGS) do
    local ok, slots = pcall(slotsOf, bag)
    slots = ok and readable(slots) and tonumber(slots) or 0
    for slot = 1, slots do
      local id = slotInfo(bag, slot)
      if id and id ~= skip and not seen[id] then
        take(id)
      end
    end
  end
  return list
end

-- Brief K25: the cached scores that read the bags for a better consumable are dropped when the
-- bags change, so the next draw judges again. Answers how many went.
function Keep.DropConsumableScores()
  local dropped = 0
  for itemId, score in pairs(Keep.cache) do
    if type(score) == "table" and type(score.consumable) == "table" then
      Keep.cache[itemId] = nil
      dropped = dropped + 1
    end
  end
  return dropped
end

function Keep.MaxLevel()
  local ask = rawget(_G, "GetMaxPlayerLevel")
  if type(ask) == "function" then
    local ok, level = pcall(ask)
    if ok and readable(level) and tonumber(level) and tonumber(level) > 0 then
      return tonumber(level)
    end
  end
  return Keep.MAX_LEVEL
end

function Keep.Money()
  if tonumber(Keep.demoMoney) then
    return tonumber(Keep.demoMoney)
  end
  local getMoney = rawget(_G, "GetMoney")
  if type(getMoney) ~= "function" then
    return nil
  end
  local ok, money = pcall(getMoney)
  if not ok then
    return nil
  end
  local util = ItemTree.Util
  if type(util) == "table" and type(util.CanRead) == "function" and not util.CanRead(money) then
    return nil
  end
  return tonumber(money)
end

-- Brief BQ18 (the owner's ruling of 2026-10-10, QA item 11: the worn Handstitched Leather Boots read
-- [Keep] "Equipped", "Better gear available" beside the carried Inscribed Leather Boots' [Equip]
-- "Upgrade for your Feet"; "Vendor (because better gear in bags)"): the tags of a worn piece a
-- carried one beats. Its sale verdict as a bag copy would read (Keep.Tags with the worn facts left
-- out), its sale tags only (Auction where it can be sold there, Disenchant with Enchanting), else
-- [Vendor] (soulbound gear, white gear, anything the sale rules do not offer): never a Keep. outdone
-- is the carried piece's name, for the one reason line (Keep.TagReasons). Pure.
function Keep.OutdoneTags(score, settings, env)
  local plain = {}
  for key, value in pairs(type(env) == "table" and env or EMPTY) do
    plain[key] = value
  end
  plain.worn, plain.outdone, plain.outdoneCarried = nil, nil, nil
  local other = Keep.RawTags(score, settings, plain)
  local tags, noData = {}, false
  for _, tag in ipairs(type(other) == "table" and other.tags or EMPTY) do
    -- Brief WL1: a worn piece with no sell price that nothing else claims stays Worthless, never a
    -- Vendor the merchant would refuse.
    if tag == Keep.TAG_AUCTION or tag == Keep.TAG_VENDOR or tag == Keep.TAG_DISENCHANT or tag == Keep.TAG_WORTHLESS then
      tags[#tags + 1] = tag
      if tag == Keep.TAG_AUCTION and other.noAuctionData == true then
        noData = true
      end
    end
  end
  if #tags == 0 then
    tags[1] = Keep.TAG_VENDOR
  end
  return {
    tags = tags,
    noAuctionData = noData,
    legendary = false,
    byUse = false,
    outdone = type(env) == "table" and env.outdone or nil,
  }
end

-- Brief BQ18 (QA item 11): the name of a carried piece that beats the worn item wornItemId, for a worn
-- tooltip shown with no comparison beside it (the character sheet): the held scores (Keep.cache, the
-- bag marks score every bag slot) whose gear test makes them an upgrade the player can wear today
-- against that worn piece (Keep.OutdoneBy over the worn map), the lowest id first, each asked once
-- whether it is carried (Keep.Carries, one count for each such upgrade, never over the bags). nil
-- for none, and the upgrade's id beside the name. A table walk; no item is asked about.
function Keep.CarriedUpgrade(wornItemId)
  local worn = Keep.WornFacts()
  local wornId = tonumber(wornItemId)
  if type(worn) ~= "table" or wornId == nil or type(Keep.cache) ~= "table" then
    return nil, nil
  end
  local found = {}
  for _, score in pairs(Keep.cache) do
    local id = type(score) == "table" and tonumber(score.itemId) or nil
    if id and id ~= wornId and Keep.OutdoneBy(wornId, score, worn) then
      found[#found + 1] = id
    end
  end
  table.sort(found)
  for _, id in ipairs(found) do
    if Keep.Carries(id) == true then
      local row = itemRow(id)
      local name = type(row) == "table" and row.n or nil
      if type(name) == "string" and name ~= "" then
        return name, id
      end
    end
  end
  return nil, nil
end

-- Brief BQ18: the worn items whose verdict was built over Keep.CarriedUpgrade, and the upgrade it
-- found (its id, or false for none), so a bag change can read it again (Keep.RecheckCarried).
Keep.outdoneWatch = {}

-- The env Keep.Tags reads: the money carried and the bag slot's real bound state (true, false or
-- nil where no slot is known). Brief K24d: worn true where the tooltip shows an item the player
-- is wearing (UI/Tooltip.lua Tooltip.Worn), which is [Keep] Equipped (brief K24e). Brief K24h:
-- outdone, the name of the bag item that outdoes a worn one (Keep.Outdone), for the muted line
-- under Equipped. A fresh table.
function Keep.Env(bound, worn, outdone, pet, outdoneCarried, tool)
  -- Brief BQ9: and the player's buffs, read out of combat (Keep.CurrentAuras), nil in combat.
  local env = { money = Keep.Money(), auras = Keep.CurrentAuras() }
  -- Brief K26: the hunter's pet food read for the item shown (Keep.PetFor), where there is one.
  if type(pet) == "table" then
    env.pet = pet
  end
  -- Brief K31: which copy of a profession tool the player keeps (Keep.ToolFor), where it is one.
  if type(tool) == "table" then
    env.tool = tool
  end
  if bound == true or bound == false then
    env.bound = bound
  end
  if worn == true then
    env.worn = true
  end
  if type(outdone) == "string" and outdone ~= "" then
    env.outdone = outdone
    -- Brief BQ18 (QA item 11): the better piece is in the bags, so the worn one is sold.
    if outdoneCarried == true then
      env.outdoneCarried = true
    end
  end
  return env
end

-- Brief K24h: whether a scored bag item outdoes the worn item wornItemId: the bag item is an upgrade
-- the player can wear today (Keep.EquipNow) and the worn slot its compare was held against holds
-- wornItemId. worn is Gear.Worn's map. Brief K27: where the stats decided, any worn slot an
-- upgraded spec was held against (score.gear.slots: each spec's weaker ring, both hands under a two
-- hander), so the worn piece outdone for one spec says so too. Pure.
function Keep.OutdoneBy(wornItemId, score, worn)
  if not Keep.EquipNow(score) or type(worn) ~= "table" then
    return false
  end
  local slots = score.gear.slots
  if type(slots) == "table" then
    for _, slot in ipairs(slots) do
      local held = worn[slot]
      if type(held) == "table" and tonumber(held.itemId) == tonumber(wornItemId) then
        return true
      end
    end
    return false
  end
  local entry = worn[score.gear.slot]
  return type(entry) == "table" and tonumber(entry.itemId) == tonumber(wornItemId)
end

-- Brief K24h: the name of the bag item againstId where it outdoes the worn item wornItemId
-- (Keep.OutdoneBy over the cached score of againstId and the worn map), else nil. Asks the client
-- nothing an ordinary score does not; the name is the shipped row's. Brief K28: againstLink, the
-- bag item's own link where the caller has it, so its random suffix roll is weighed.
function Keep.Outdone(wornItemId, againstId, playerLevel, playerFaction, againstLink)
  local against = tonumber(againstId)
  if not against or type(Keep.CachedScore) ~= "function" then
    return nil
  end
  local ok, score = pcall(Keep.CachedScore, against, playerLevel, playerFaction, nil, nil, nil, againstLink)
  if not ok or type(score) ~= "table" then
    return nil
  end
  local worn = Keep.WornFacts()
  if not Keep.OutdoneBy(wornItemId, score, worn) then
    return nil
  end
  local row = itemRow(against)
  local name = type(row) == "table" and row.n or nil
  if type(name) ~= "string" or name == "" then
    return nil
  end
  -- Brief BQ18 (QA item 11): and whether that piece is carried (one count for the one item): the
  -- comparison tooltip also shows beside a vendor's, an auction's or a chat link's item, which is
  -- better gear available but not in the bags.
  return name, Keep.Carries(against) == true
end

-- Brief K24b (A3): the real bound state of the item in one bag slot: true, false, or nil where the
-- client will not say or the slot no longer holds itemId. Client assumption (bible B1), read on
-- the forever branch of the UI source mirror at 1.60.1.70205
-- (Interface/AddOns/Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua:780):
-- C_Container.GetContainerItemInfo(bag, slot) answers a table whose isBound is the slot's bound
-- state and whose itemID is the item, from what the client holds, with no server query. Each
-- value is asked through Util.CanRead before any compare (bible B10). One call for one slot,
-- only for a row that may bind (Keep.MAY_BIND), never over a list.
function Keep.SlotBound(bag, slot, itemId)
  bag, slot = tonumber(bag), tonumber(slot)
  if bag == nil or slot == nil then
    return nil
  end
  local container = rawget(_G, "C_Container")
  local ask = type(container) == "table" and container.GetContainerItemInfo or nil
  if type(ask) ~= "function" then
    return nil
  end
  local ok, info = pcall(ask, bag, slot)
  if not ok or type(info) ~= "table" then
    return nil
  end
  local util = ItemTree.Util
  local canRead = type(util) == "table" and type(util.CanRead) == "function" and util.CanRead or nil
  local held = info.itemID
  if canRead and not canRead(held) then
    return nil
  end
  if itemId ~= nil and tonumber(held) ~= tonumber(itemId) then
    return nil
  end
  local bound = info.isBound
  if canRead and not canRead(bound) then
    return nil
  end
  if bound == true then
    return true
  end
  if bound == false then
    return false
  end
  return nil
end

-- The bound state to hand Keep.Tags for an item shown from a bag slot: asked of the slot only
-- where the item's row may bind (bind on equip, bind on use), nil otherwise (the row decides).
function Keep.BoundFor(itemId, bag, slot)
  local row = itemRow(tonumber(itemId))
  if type(row) ~= "table" or not Keep.MAY_BIND[tonumber(row.b) or -1] then
    return nil
  end
  return Keep.SlotBound(bag, slot, itemId)
end

-- Brief K28: the link of the item in one bag slot, for its random suffix roll, asked only where
-- the item's row may roll one (Gear.MayRoll: weapon or armour with rp, or a module of Classic Era
-- link rows), nil otherwise and for a slot that no longer holds itemId. Client assumption (bible
-- B1), read on the forever branch of the UI source mirror at 1.60.1.70245:
-- C_Container.GetContainerItemLink(bag, slot) answers the slot's item link from what the client
-- holds, with no server query (Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua:209;
-- Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua:1782 calls it with the button's GetBagID()
-- and GetID()), and the bare GetContainerItemLink is Classic Era's (UI/Tooltip.lua's SetBagItem
-- resolver reads both the same way). The answer is asked through Util.CanRead (bible B10) and
-- must name itemId (Gear.ParseItemLink). One call for one slot, never over a list. Fake variants:
-- tests/spec/keep_suffix_spec.lua "forever 1.60.1.70245 container links", "no
-- GetContainerItemLink", "raising" and "another item".
function Keep.SlotLink(itemId, bag, slot)
  local id = tonumber(itemId)
  bag, slot = tonumber(bag), tonumber(slot)
  local gear = ItemTree.Gear
  if not id or bag == nil or slot == nil or type(gear) ~= "table" or type(gear.MayRoll) ~= "function" then
    return nil
  end
  local row = itemRow(id)
  if not gear.MayRoll(row) then
    return nil
  end
  local container = rawget(_G, "C_Container")
  local ask = type(container) == "table" and container.GetContainerItemLink or nil
  if type(ask) ~= "function" then
    ask = rawget(_G, "GetContainerItemLink")
  end
  if type(ask) ~= "function" then
    return nil
  end
  local ok, link = pcall(ask, bag, slot)
  if not ok or not readable(link) or type(link) ~= "string" then
    return nil
  end
  local parsed = type(gear.ParseItemLink) == "function" and gear.ParseItemLink(link) or nil
  if type(parsed) ~= "table" or parsed.id ~= id then
    return nil
  end
  return link
end

-- Brief K24b (B): the player's rank in one skill line, for Keep.CouldUse, or nil. Reads the item
-- page's own held profession table (UI/Frame.lua Frame.PlayerSkills, the pretend professions
-- while they are on), asked only for a consumable that names a required skill.
function Keep.SkillRank(skillLine)
  local ui = ItemTree.UI
  local frame = type(ui) == "table" and ui.Frame or nil
  frame = frame or ItemTree.Frame
  if type(frame) ~= "table" or type(frame.PlayerSkills) ~= "function" then
    return nil
  end
  local ok, skills = pcall(frame.PlayerSkills)
  local entry = ok and type(skills) == "table" and skills[tonumber(skillLine)] or nil
  if type(entry) == "table" then
    return tonumber(entry.rank)
  end
  return tonumber(entry)
end

-- Brief JO1 (BQ7): Lockpicking's skill line, and the rogue's rank in it: the skill sheet's rank where
-- the client lists the line (Keep.SkillRank), else, where the rogue knows Pick Lock (or the client
-- cannot say), the cap for the level (Keep.LOCKPICK_PER_LEVEL a level; the Forever client's skill
-- sheet reads empty). 0 for a rogue the client says has not learnt Pick Lock; nil where the level
-- is not known. A question about the player, never about an item.
Keep.LOCKPICKING = 633

function Keep.LockpickRank(level)
  local listed = Keep.SkillRank(Keep.LOCKPICKING)
  if listed ~= nil then
    return listed
  end
  for _, name in ipairs({ "IsPlayerSpell", "IsSpellKnown" }) do
    local known = rawget(_G, name)
    if type(known) == "function" then
      local ok, answer = pcall(known, Keep.PICK_LOCK_SPELL)
      if ok and answer == false then
        return 0
      end
      if ok and answer == true then
        break
      end
    end
  end
  level = tonumber(level)
  if level == nil then
    return nil
  end
  return level * Keep.LOCKPICK_PER_LEVEL
end

-- Brief BQ9: whether the client is in combat lockdown (false where it cannot say).
local function inCombat()
  local locked = rawget(_G, "InCombatLockdown")
  if type(locked) ~= "function" then
    return false
  end
  local ok, answer = pcall(locked)
  return ok and answer == true
end

-- Brief BQ9: one aura's name and spell id into the set, each only where the client lets addon code
-- read it (Util.CanRead, bible B10: a value it cannot read is left out, never compared).
local function noteAura(set, name, spellId)
  local util = ItemTree.Util
  local function canRead(value)
    return type(util) ~= "table" or type(util.CanRead) ~= "function" or util.CanRead(value)
  end
  if name ~= nil and canRead(name) and type(name) == "string" and name ~= "" then
    set[name] = true
  end
  if spellId ~= nil and canRead(spellId) and type(spellId) == "number" then
    set[spellId] = true
  end
end

-- Brief BQ9: the most helpful auras read at once.
Keep.AURA_MAX = 40

-- Brief BQ9: the player's helpful auras as a set of spell ids and names, or nil: in combat (the
-- answer may be secret there, and Keep.DoNow then counts every buff as not on, so a Use stays a
-- Use), or where the client has no aura reader. C_UnitAuras.GetAuraDataByIndex first, then
-- UnitAura, each call under pcall. A question about the player, never about an item.
function Keep.PlayerAuras()
  if inCombat() then
    return nil
  end
  local set = {}
  local auras = rawget(_G, "C_UnitAuras")
  if type(auras) == "table" and type(auras.GetAuraDataByIndex) == "function" then
    for index = 1, Keep.AURA_MAX do
      local ok, aura = pcall(auras.GetAuraDataByIndex, "player", index, "HELPFUL")
      if not ok or type(aura) ~= "table" then
        break
      end
      noteAura(set, aura.name, aura.spellId)
    end
    return set
  end
  local unitAura = rawget(_G, "UnitAura")
  if type(unitAura) ~= "function" then
    return nil
  end
  for index = 1, Keep.AURA_MAX do
    local ok, name, _, _, _, _, _, _, _, _, spellId = pcall(unitAura, "player", index, "HELPFUL")
    if not ok or name == nil then
      break
    end
    noteAura(set, name, spellId)
  end
  return set
end

-- Brief BQ9: the auras Keep.Tags weighs, read once and kept until the next UNIT_AURA out of combat
-- (Keep.OnAura); nil in combat.
Keep.auraSet = nil

function Keep.CurrentAuras()
  if inCombat() then
    return nil
  end
  if Keep.auraSet == nil then
    Keep.auraSet = Keep.PlayerAuras()
  end
  return Keep.auraSet
end

-- Two aura sets hold the same entries. Pure.
local function sameSet(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return a == b
  end
  for key in pairs(a) do
    if not b[key] then
      return false
    end
  end
  for key in pairs(b) do
    if not a[key] then
      return false
    end
  end
  return true
end

-- Brief BQ9: what UNIT_AURA on the player (and the end of combat) does: out of combat the buffs are
-- read again, and where they moved the tooltip's held blocks go and the bags paint again, so a
-- scroll whose buff just landed leaves [Use]. Nothing in combat. Answers whether it repainted.
function Keep.OnAura()
  if inCombat() then
    return false
  end
  local now = Keep.PlayerAuras()
  if sameSet(now, Keep.auraSet) then
    return false
  end
  Keep.auraSet = now
  repaint()
  return true
end

-- Brief K24b: the money the bags were last painted against, so a PLAYER_MONEY that moves it
-- little (under MONEY_REPAINT of it) clears the tooltip's held blocks only.
Keep.MONEY_REPAINT = 0.1
Keep.paintedMoney = nil

-- What PLAYER_MONEY does: the tooltip's held blocks go (they hold tags read against the money),
-- and the bags paint again where the money moved by MONEY_REPAINT of itself or more. Answers
-- whether the bags were painted again.
function Keep.OnMoney()
  local money = Keep.Money()
  local was = Keep.paintedMoney
  if money ~= nil and (was == nil or math.abs(money - was) >= math.max(was * Keep.MONEY_REPAINT, Keep.MONEY_MIN)) then
    Keep.paintedMoney = money
    repaint()
    return true
  end
  local tooltip = ItemTree.Tooltip
  if type(tooltip) == "table" and type(tooltip.ClearCache) == "function" then
    pcall(tooltip.ClearCache)
  end
  return false
end

-- The noes Keep.completed holds are dropped, the yeses kept.
local function forgetNoes()
  for questId, done in pairs(Keep.completed) do
    if not done then
      Keep.completed[questId] = nil
    end
  end
end

-- Brief RF375 (M1): the events after which the quest log's objectives are read again.
Keep.LOG_EVENTS = { QUEST_TURNED_IN = true, QUEST_ACCEPTED = true, QUEST_REMOVED = true, QUEST_LOG_UPDATE = true }

-- Brief K1: what the event frame does. QUEST_TURNED_IN names the quest, which is taken as done at
-- once (the flag can lag the event); QUEST_LOG_UPDATE, heard only where the client refused
-- QUEST_TURNED_IN, names none and only forgets the noes and the scores, with no repaint, because
-- it comes in bursts. SKILL_LINES_CHANGED fires on every weapon skill point too, so the
-- professions are read again and the scores dropped only when the set moved. Answers whether the
-- scores were dropped.
--
-- Brief TB4: QUEST_REMOVED notes the quest (Keep.removed) and the next QUEST_LOG_UPDATE judges it
-- (Keep.SettleRemoved): abandoned unless it was turned in, which drops the scores and repaints.
-- QUEST_ACCEPTED of a quest marked abandoned forgets the mark, and the first QUEST_LOG_UPDATE of
-- the session forgets the noes and the scores once, so a "not completed" asked before the client
-- had its completed quests at login does not stand all session. QUEST_LOG_UPDATE is heard on
-- every client now; it only forgets the noes and the scores on every burst where QUEST_TURNED_IN
-- was refused (Keep.questEvent), as before.
function Keep.OnEvent(event, ...)
  -- Brief RF375 (M1): a quest turned in, taken, dropped or the log changed: the log's objectives are
  -- read again on the next ask (Core/QuestFlags.lua MarkLogDirty), before anything below asks them.
  if Keep.LOG_EVENTS[event] then
    local flags = ItemTree.QuestFlags
    if type(flags) == "table" and type(flags.MarkLogDirty) == "function" then
      pcall(flags.MarkLogDirty)
    end
  end
  if event == "QUEST_TURNED_IN" then
    local questId = tonumber((...))
    forgetNoes()
    if questId and questId > 0 then
      Keep.completed[questId] = true
      Keep.removed[questId] = nil
      Keep.ForgetAbandoned(questId)
    end
    Keep.DropScores()
    repaint()
    return true
  end
  if event == "QUEST_REMOVED" then
    local questId = tonumber((...))
    if questId and questId > 0 and Keep.completed[questId] ~= true then
      Keep.removed[questId] = true
    end
    -- Brief RF375 (M1): a quest that asked for a finished item left the log.
    return Keep.RecheckLogWants()
  end
  if event == "QUEST_ACCEPTED" then
    local questId = acceptedId(...)
    if questId then
      Keep.removed[questId] = nil
      if Keep.ForgetAbandoned(questId) then
        Keep.DropScores()
        repaint()
        return true
      end
    end
    -- Brief WS1: a quest an item starts, taken: its needs keep now (Keep.RecheckStarters). Brief IW1:
    -- and a provided item of the quest taken keeps now (Keep.RecheckProvided).
    local provided = Keep.RecheckProvided()
    -- Brief RF375 (M1): and a finished item the quest taken asks for is no longer finished.
    provided = Keep.RecheckLogWants() or provided
    return Keep.RecheckStarters() or provided
  end
  if event == "QUEST_LOG_UPDATE" then
    -- Brief WS1: a quest an item starts that left the log (abandoned) holds its needs back again.
    -- Brief IW1: and a provided item's quest that came into or left the log (Keep.RecheckProvided).
    local dropped = Keep.RecheckProvided()
    dropped = Keep.RecheckStarters() or dropped
    -- Brief RF375 (M1): and a finished item whose wanting by the log moved.
    dropped = Keep.RecheckLogWants() or dropped
    if not Keep.questLogSeen then
      Keep.questLogSeen = true
      forgetNoes()
      Keep.DropScores()
      repaint()
      dropped = true
    elseif Keep.questEvent ~= "QUEST_TURNED_IN" then
      forgetNoes()
      Keep.DropScores()
      dropped = true
    end
    if next(Keep.removed) ~= nil and Keep.SettleRemoved() then
      Keep.DropScores()
      repaint()
      dropped = true
    end
    return dropped
  end
  -- Brief K20-wire: a piece of gear put on or taken off moves which items are upgrades. The worn
  -- map is dropped here as well as on Gear's own frame, since the two frames hear the event in no
  -- set order, and the bags paint again.
  if event == "PLAYER_EQUIPMENT_CHANGED" then
    -- Brief BQ25c: a bag put in or taken out of a bag slot moves the bag rule's state too.
    Keep.bagState = nil
    Keep.carriedBags = nil
    local gear = ItemTree.Gear
    if type(gear) == "table" and type(gear.Drop) == "function" then
      pcall(gear.Drop)
    end
    Keep.DropScores()
    repaint()
    return true
  end
  if event == "SKILL_LINES_CHANGED" then
    -- Brief K20-wire: an Enchanting skill point moves which items the player can disenchant, so a
    -- moved rank drops the scores too.
    local values = ItemTree.DisenchantValue
    local rankBefore = Keep.EnchantingRank()
    if type(values) == "table" and type(values.OnEvent) == "function" then
      pcall(values.OnEvent, event)
    end
    local rankMoved = Keep.EnchantingRank() ~= rankBefore
    local before = Keep.ProfessionSignature(Keep.professionsRead and Keep.professions or nil)
    Keep.professionsRead = false
    forgetKeyParts()
    local after = Keep.ProfessionSignature(Keep.PlayerProfessions())
    if before == after and not rankMoved then
      return false
    end
    Keep.DropScores()
    repaint()
    return true
  end
  -- Brief K22: a crate picked up or used moves the item combines that count. Brief K25: and the
  -- consumables judged against what the bags hold.
  -- Brief BG1: the bank opened, closed or changed (its bag slots bought or filled): the bank read
  -- the spare bag rule holds (Keep.OnBank); where it moved, every bag's verdict goes.
  if Keep.BANK_EVENTS[event] then
    if Keep.OnBank(event) then
      Keep.bagState = nil
      Keep.DropScores()
      repaint()
      return true
    end
    -- Brief WS1: a quest's starter put in or taken out of the bank (the bank counts as held).
    return Keep.RecheckStarters()
  end
  if event == "BAG_UPDATE_DELAYED" then
    -- Brief BG1: a bag put in or taken out of the bank while it is open is read again first.
    if Keep.bankOpen then
      Keep.OnBank(event)
    end
    -- Brief BQ25c: an equipped bag swapped moves every bag's verdict: the scores go and the bags
    -- paint again (Keep.BagsMoved). Brief BG1: and a spare bag picked up, dropped or moved to the
    -- bank (the carried and bank bags join the signature).
    if Keep.BagsMoved() then
      Keep.DropScores()
      repaint()
      return true
    end
    local dropped = Keep.DropConsumableScores() > 0
    -- Brief K31: the bag walk the tool rule reads is taken again, and the bags painted where it held
    -- a tool (which copy is kept may have moved).
    if Keep.ForgetTools() then
      dropped = true
    end
    local moved = Keep.RecheckCarried()
    -- Brief WS1: and the scores that rest on a quest's starter (picked up, used, sold, banked).
    if Keep.RecheckStarters() then
      moved = true
    end
    if dropped and not moved then
      repaint()
    end
    return moved or dropped
  end
  -- Brief K24b: the money carried moves the money test (Keep.Tags, rule 7).
  if event == "PLAYER_MONEY" then
    return Keep.OnMoney()
  end
  -- Brief BQ9: the player's buffs, for the use now consumables (Keep.OnAura).
  if (event == "UNIT_AURA" and select(1, ...) == "player") or event == "PLAYER_REGEN_ENABLED" then
    return Keep.OnAura()
  end
  -- Brief JG1 (item 302): a demon summoned, dismissed or swapped (UNIT_PET for the player), or a rank
  -- learnt (PET_BAR_UPDATE), moves which grimoires the demon has learnt: those scores go, and the
  -- bags paint again where one was held. The unit is asked readable before the compare (bible B10).
  -- Brief RP-AH2 (FR-AH M2): only a warlock's scores hold a grimoire (Keep.PetBookFacts), so any other
  -- class (the pretend class counts, Keep.PlayerClass) answers at once and a hunter's pet bar churn in
  -- combat sweeps nothing.
  if event == "UNIT_PET" or event == "PET_BAR_UPDATE" then
    if tonumber(Keep.PlayerClass()) ~= Keep.WARLOCK_CLASS then
      return false
    end
    if event == "UNIT_PET" then
      local unit = ...
      if not readable(unit) or unit ~= "player" then
        return false
      end
    end
    if Keep.DropPetBookScores() > 0 then
      repaint()
      return true
    end
    return false
  end
  -- Brief CB1 (item 305): a spell learnt (from a trainer, or a copy of the book read) moves which
  -- class books the player has learnt: those scores go, and the bags paint again where one was held.
  -- Brief TV1 (QA item 347b, D1): and which recipe items the player has learnt (a recipe learnt reads
  -- NEW_RECIPE_LEARNED where the client sends it).
  if event == "LEARNED_SPELL_IN_SKILL_LINE" or event == "NEW_RECIPE_LEARNED" then
    if Keep.DropClassBookScores() + Keep.DropRecipeScores() > 0 then
      repaint()
      return true
    end
    return false
  end
  return false
end

-- The event frame, ItemTree's own, made once where the client can make one. QUEST_TURNED_IN where
-- the client has it, else QUEST_LOG_UPDATE.
function Keep.Install()
  if Keep.frame then
    return Keep.frame
  end
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, "Frame")
  if not ok or type(frame) ~= "table" or type(frame.RegisterEvent) ~= "function" then
    return nil
  end
  pcall(frame.RegisterEvent, frame, "SKILL_LINES_CHANGED")
  Keep.questEvent = "QUEST_TURNED_IN"
  if not pcall(frame.RegisterEvent, frame, "QUEST_TURNED_IN") then
    Keep.questEvent = "QUEST_LOG_UPDATE"
  end
  -- Brief TB4: the log's own update on every client, and the two moments a quest enters or
  -- leaves the log, for the abandoned quests.
  pcall(frame.RegisterEvent, frame, "QUEST_LOG_UPDATE")
  pcall(frame.RegisterEvent, frame, "QUEST_ACCEPTED")
  pcall(frame.RegisterEvent, frame, "QUEST_REMOVED")
  -- Brief K20-wire: the worn gear, for the upgrade test.
  pcall(frame.RegisterEvent, frame, "PLAYER_EQUIPMENT_CHANGED")
  -- Brief K22: the bags, for the item combines a carried via item counts (Keep.RecheckCarried).
  pcall(frame.RegisterEvent, frame, "BAG_UPDATE_DELAYED")
  -- Brief K24b: the money carried, for the money test (Keep.OnMoney).
  pcall(frame.RegisterEvent, frame, "PLAYER_MONEY")
  -- Brief BG1: the bank, for the spare bag rule's bank read (Keep.OnBank).
  for _, event in ipairs(Keep.BANK_EVENT_LIST) do
    pcall(frame.RegisterEvent, frame, event)
  end
  -- Brief BQ9: the player's buffs (Keep.OnAura), the player's unit alone where the client can.
  local unitOnly = type(frame.RegisterUnitEvent) == "function"
    and pcall(frame.RegisterUnitEvent, frame, "UNIT_AURA", "player")
  if not unitOnly then
    pcall(frame.RegisterEvent, frame, "UNIT_AURA")
  end
  pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED")
  -- Brief JG1: the warlock's demon, for the grimoires it has learnt (Keep.DropPetBookScores):
  -- UNIT_PET (UnitDocumentation.lua:4450, forever branch) for the player's unit alone where the
  -- client can, and PET_BAR_UPDATE (ActionBarFrameDocumentation.lua:1098). Brief RP-AH2: registered for
  -- every class, since the pretend class can make a warlock of anyone; Keep.OnEvent answers at once for
  -- any other class.
  local petOnly = type(frame.RegisterUnitEvent) == "function"
    and pcall(frame.RegisterUnitEvent, frame, "UNIT_PET", "player")
  if not petOnly then
    pcall(frame.RegisterEvent, frame, "UNIT_PET")
  end
  pcall(frame.RegisterEvent, frame, "PET_BAR_UPDATE")
  -- Brief CB1: a spell the player learns, for the class books (Keep.DropClassBookScores):
  -- LEARNED_SPELL_IN_SKILL_LINE (SpellBookDocumentation.lua:851, forever branch; the client's own
  -- Blizzard_UIPanels_Game/Mainline/QuestFrame.lua:19 registers it).
  pcall(frame.RegisterEvent, frame, "LEARNED_SPELL_IN_SKILL_LINE")
  -- Brief TV1 (D1): a recipe learnt, for the recipe items (Keep.DropRecipeScores): NEW_RECIPE_LEARNED
  -- (TradeSkillUIDocumentation.lua:1239, forever branch), pcalled where the client has no such event.
  pcall(frame.RegisterEvent, frame, "NEW_RECIPE_LEARNED")
  pcall(frame.SetScript, frame, "OnEvent", function(_, event, ...)
    Keep.OnEvent(event, ...)
  end)
  Keep.frame = frame
  return frame
end

Keep.Install()

-- Brief K7: which tier of a ramp a score draws in, from 1 (the lowest) to the ramp's length, or 0
-- for an item that is not marked. ramp is the ramp's list of tiers (UI/Theme.lua keepRamps) or
-- just its length; anything else reads as one tier. Every marked item is tier 1; two or more
-- current uses lift it to tier 2 and four or more to tier 3, clamped to the ramp's length; the
-- player's own Always word takes the top tier whatever the uses. Pure.
function Keep.Tier(score, ramp)
  if not Keep.Marked(score) then
    return 0
  end
  local length = type(ramp) == "table" and #ramp or tonumber(ramp) or 1
  length = math.floor(length)
  if length < 1 then
    length = 1
  end
  if score.override == "always" then
    return length
  end
  -- Brief K9: a valuable item takes the top tier too; score.valuable lets the drawing tell it
  -- from a plain top tier.
  if score.valuable then
    return length
  end
  local tier = 1
  -- Brief K22: the uses the mark counts (Keep.Counted), not another profession's recipes.
  local current = Keep.Counted(score)
  for index, uses in ipairs({ 2, 4 }) do
    if current >= uses then
      tier = index + 1
    end
  end
  if tier > length then
    return length
  end
  return tier
end

-- Brief K11: the Keep lines for one item, the list Keep.VerdictLines answers and its tone, or nil
-- (the item has nothing to say, or its rows are not loaded yet). Scored once through
-- Keep.CachedScore from ItemTree's own tables, the auction value read from an installed auction
-- addon's own prices for this one item; never a client item query. The tooltip and the item page
-- both ask this, so the two never disagree.
--
-- Brief PM1: have is the player's count for the Professions route line (brief PR9), handed in by
-- a caller that already read it (the tooltip, whose cache keys on it); where it is nil the count
-- is read here through Keep.ProfessionHave, which asks nothing unless the route needs the item.
--
-- Brief K24b: bound is the real bound state of the bag slot the caller shows the item from (true or
-- false), nil where it knows no slot; the money carried is read here (Keep.Env). Brief K24d: worn
-- true for an item instance the player wears (or the comparison tooltip), which brief K24e reads
-- as [Keep] alone with the reason "Equipped". Brief K24h: against is the id of the bag item the
-- client's comparison tooltip is shown beside (UI/Tooltip.lua); where that item outdoes this worn
-- one (Keep.Outdone) the block adds "Better gear available". Brief K26: pet is the client's pet
-- food read for the item shown (Keep.PetFor, read by UI/Tooltip.lua for the one item it draws),
-- or nil. Brief K28: link is the item's own link (the tooltip's GetItem link), whose random suffix
-- roll the gear compare weighs (Keep.CachedScore holds each roll apart); againstLink the bag
-- item's link beside a comparison tooltip, for Keep.Outdone. Brief K31: tool is the tool read for
-- the copy shown (Keep.ToolFor over its bag slot, read by UI/Tooltip.lua), or nil; for a tool
-- with none it is read here for the item alone. Brief F160: wornBag, with worn true, names a bag
-- hovered in a bag slot (Keep.WORN_BAG, Keep.WORN_BANK_BAG; UI/Tooltip.lua Tooltip.EquippedBag):
-- [Keep] "Equipped bag", with no carried upgrade asked.
function Keep.ItemLines(
  itemId,
  playerLevel,
  playerFaction,
  link,
  have,
  bound,
  worn,
  against,
  pet,
  againstLink,
  tool,
  wornBag
)
  local id = tonumber(itemId)
  if not id or type(Keep.CachedScore) ~= "function" then
    return nil
  end
  local ok, score = pcall(Keep.CachedScore, id, playerLevel, playerFaction, nil, nil, nil, link)
  if not ok or type(score) ~= "table" then
    return nil
  end
  if have == nil and score.profession ~= nil and type(Keep.ProfessionHave) == "function" then
    local read, count = pcall(Keep.ProfessionHave, id)
    have = read and count or nil
  end
  -- Brief Q1: a quest only keep's words weigh the player's count against what the quests ask for.
  -- Brief BQ18: and a working stock keep's words weigh it against a stack (Keep.StockCap).
  -- Brief UL1: and every need line the block shows (Keep.WantsHave: the quests' count, a crate's).
  if (have == nil or have == false) and Keep.WantsHave(score) then
    local read, count = pcall(Keep.QuestHave, id, playerLevel, playerFaction)
    if read and type(count) == "number" then
      have = count
    end
  end
  local outdone, carried = nil, false
  if worn == true and against ~= nil then
    local asked, name, held = pcall(Keep.Outdone, id, against, playerLevel, playerFaction, againstLink)
    outdone = asked and name or nil
    carried = asked and held == true
  elseif worn == true and wornBag == nil then
    -- Brief BQ18 (QA item 11): a worn item shown alone (the character sheet) asks the held scores for
    -- a carried upgrade, and is watched so a bag change reads it again (Keep.RecheckCarried). Brief
    -- F160: never for a bag in a bag slot, which no gear outdoes.
    local asked, name, upgrade = pcall(Keep.CarriedUpgrade, id)
    outdone = asked and name or nil
    carried = outdone ~= nil
    Keep.outdoneWatch[id] = asked and upgrade or false
  end
  if tool == nil and type(score.tool) == "table" and score.tool.own then
    local read, answer = pcall(Keep.ToolFor, id)
    tool = read and answer or nil
  end
  local env = Keep.Env(bound, worn, outdone, pet, carried, tool)
  -- Brief F160: which bag slot a worn bag is in, for its one reason.
  if worn == true and (wornBag == Keep.WORN_BAG or wornBag == Keep.WORN_BANK_BAG) then
    env.wornBag = wornBag
  end
  local worded, lines, tone = pcall(Keep.VerdictLines, score, have, nil, env)
  if worded and type(lines) == "table" and #lines > 0 then
    return lines, tone
  end
  return nil
end

return Keep
