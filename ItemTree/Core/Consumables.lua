-- Consumable facts for the Keep verdict (brief K25): whether a food, drink, potion, bandage,
-- elixir or scroll is worth keeping, decided from the shipped effects data instead of the game's
-- tooltip. Loaded as: local _, ItemTree = ...
--
-- The data is the ItemEffects module the ItemTree-Data pipeline compiles from its u1-item-effects
-- branch (docs/briefs/K25-consumable-facts.md, step 1). Until it ships, Consumables.Facts answers
-- nil for every item and Core/Keep.lua keeps the brief K24b window (Keep.CouldUse) and brief
-- K26's spell name read (Keep.FoodEffect); nothing here changes a verdict without the data.
--
-- The contract, one entry per item id in ItemEffects (Consumables.MODULE), as the addon reads it:
--   { e = { effect, ... }, c = classMask, sk = skillLine, skr = rank }
--   effect: { k = kind, a = amount, s = seconds, sit = 1, st = statId, p = percent, n = name }
--     k   "health" or "mana" (a restore; a is the TOTAL over s seconds, sit = 1 where the player
--         sits for it: food and drink), "bandage" (a heal over time that needs First Aid),
--         "stat" (a buff of st by a for s seconds), "rested" (p percent more rested experience),
--         "buff" (any other named effect, n its spell name), "other"
--   c   the class mask of the classes the item helps (0 or absent: every class), the item row's
--       own allowable class mask where the effects name none
-- Consumables.FactsFrom(entry) is the ONE place that shape is read, so a pipeline that ships the
-- u1 shape under other keys is matched there (or made to ship this one), with the fixture entries
-- in tests/spec/consumables_spec.lua as the contract's own examples.
--
-- Brief K25d: the u1-item-effects pipeline ships ANOTHER shape (ItemTree-Data docs/data-format.md,
-- "Item effects"): a packed module (packed = 1, legend k, r, z, s) whose row, decoded by
-- Consumables.Facts through Data.ModuleRow as Data:GetItem decodes an item row, is
--   { k = { kind codes }, r = { { restoreKind, low, high, seconds, seated }, ... }, z = 1, s = level }
-- beside the module's own kinds, restoreKinds, classes and shares tables. FactsFrom maps it to the
-- same facts (SHIPPED_RESTORES, SHIPPED_STATS, SHIPPED_BUFFS below): a restore is health, mana or a
-- bandage with its LOW amount and sit from seated; a stat kind is that ITEM_MOD stat (no amount
-- ships, so 0: only Consumables.StatWanted reads the stats); a kind that is a real effect is a buff;
-- every other kind adds nothing. Rested experience has no kind and the module names no class mask
-- or skill per item, so classes stays 0 (the row's own ac gates, as brief K24b did) and the row's
-- sk and skr stand. An entry that maps to nothing is nil, so the K24b window and K26 stand for it.
--
-- Brief K25e (the orchestrator's rule from the K27 research cross-check, 2026-10-08): a buff is no
-- longer every class's. Each buff FactsFrom maps carries its kind's class mask from the shipped
-- module's own classes table (module.classes[kindCode], the class bits as MaskHasClass reads them)
-- in facts.gates, and Useful counts it as wanted only where that mask names the player's class. An
-- energy or rage restore (restoreKinds 9 and 8) is gated by the mask of the kind of the same name
-- (kinds 44 energy and 39 rage, matched by name through the module's own kinds and restoreKinds,
-- per the pipeline's docs/data-format.md). Health, mana and bandage restores are not gated (mana
-- keeps NO_MANA), a mask of all nine classes (1503) gates nothing, and a module with no classes
-- table (the contract's fixtures) gates nothing. Stats are judged by their kind's mask as well, in
-- Useful (brief EC2, below), not through facts.gates.
--
-- The rules (the owner's, 2026-10-07):
--   useful     an item is useful where it has an effect the player's class wants beyond the ones
--              every class uses; an item whose only effects are the ones every class uses (health,
--              a bandage, a buff that is not a stat) is useful to everyone. Mana is wanted by every
--              class but warriors and rogues; a stat by the classes its kind's shipped mask names
--              (Consumables.StatMask, brief EC2); rested experience below the level cap only.
--   efficient  a restore is worth carrying while it restores at least a share of the player's pool
--              at their level: food and drink SHARE_FOOD (three quarters, the total over the
--              duration), a potion SHARE_INSTANT (a quarter), a bandage (brief K29, below) no share;
--              Jettison's R94 shares. nil where the pool is not known (counts as efficient).
--              Brief K25g: the shipped module's own shares table answers first (one share per
--              restore kind, the table Jettison reads too); these numbers are the fallback.
--   better     a better one is usable: an item of the same kind the player carries that restores
--              more and that they can use now (level and skill); the lesser one stops being kept.
--   keep       useful, efficient, no better one usable, and the row's own gates (class mask, skill,
--              the K24b look ahead on the required level).
-- A buff (stat, rested, named) is useful in its own right and never judged by the shares.
--
-- Brief K25f (the orchestrator's rule, the same in Jettison; found by the persona tests, 2026-10-09):
-- a "buff food". Forever's Nutritious Food (Rainbow Fin Albacore, Smoked Sagefish, Sagefish Delight)
-- gives a Well Fed of spell damage beside its health, and a level 30 mage read Smoked Sagefish as
-- too weak by its health alone. A food or drink (a restore sat for) that also carries a buff kind
-- the player's class wants by the module's per kind class mask (facts.buffKinds: a buff or stat kind
-- whose mask is neither absent nor all nine classes, and holds the class) is a buff food for that
-- player: never "weak" by its restore share (the owner's 2026-10-07 ruling, "keep until a better one
-- is usable OR the current one is too inefficient": the restore is not what it is for), and no
-- longer kept once a BETTER buff food is carried and usable now: another food or drink with the
-- same wanted kinds whose amounts for them are higher (slot 5 `a`, facts.amounts), or, where either
-- side states no amount, whose restore is higher. For a class that does not want its buff it is
-- ordinary food, and an ungated buff (everyone's, stamina say) never makes a buff food. The stat
-- kinds (8, 12, 15, 17, 19) count here by the module's masks, as the rule says, and Useful reads the
-- same masks (brief EC2); "the same wanted kinds" is exactly the same set, and an amount is the first one the
-- row states for its kind. The rule's addition (found on the Jettison side: 12 of Forever's 15 new
-- drinks carry spirit or healing power, so a level 30 priest kept a level 1 water for ever): a food
-- or drink is a buff food only while its required level is no more than BUFF_FOOD_LEVELS below the
-- player's level; further below it is ordinary food and the share decides.
--
-- Brief K25f: a skill a row asks for on a CHILD line is met by the player's rank in its parent line
-- (Consumables.RankIn). The bandage rows ask for First Aid's Forever child line 2942, and the client
-- reports the player's First Aid as the parent 129 (GetProfessionInfo's skill line: Jettison's
-- stored snapshots record First Aid reagents as 129 and nothing as 2942, and the Professions tab's
-- First Aid route, keyed 129, reads the player's rank in play), so no bandage was ever kept.
--
-- Brief K29 (the owner's ruling of 2026-10-09, Roasted Boar Meat and Herb Baked Egg at level 15, the
-- same in Jettison): a food or drink whose buff raises the experience from kills (the pipeline's kind
-- 61, kill experience, 5 percent on Forever's Nutritious Food and Drink) is worth keeping for any
-- character still levelling, below the level cap (player.maxLevel, Keep.MaxLevel on the client,
-- else LEVEL_CAP 60), whatever its heal size and level: an "XP food" (Consumables.XpFood). It is
-- never "too weak" by its restore share, has no buff food level window, and gives way only to a
-- better XP food carried and usable now (Consumables.BetterXpFood: at least the same kill
-- experience, and better by the rule that applies to it today: a better buff food where it is one
-- for the class, else a higher restore of its kind). Kept for its kill experience alone (no buff
-- food, its restore not reaching its share), its words say so: "More kill experience while
-- levelling". At the
-- cap it is ordinary food again; an item whose only effect is kill experience is no use there
-- ("cap", "No use at the level cap").
--
-- Brief K29 (the owner's ruling of 2026-10-09 on his level 15 QA, "a big issue": Heavy Linen Bandage
-- read "Too weak for your level"; the same in Jettison): a bandage is judged against bandages, not by
-- half the health pool. A bandage the player can use (its First Aid rank met) is kept while it is
-- still relevant, its heal at least BANDAGE_IRRELEVANT_SHARE (a fifth since BQ16) of the health pool, or while
-- it is the best usable bandage carried; below that share with a better usable bandage in the bags
-- it is "too weak" as a pure consumable (a reagent use still keeps it, as before). The owner's
-- refinement: "the level 14 hunter scenario sounds about right up to the point where the hunter
-- completely outlevels it and it becomes truly irrelevant". Carried bandages only: the bags are
-- read (Keep.CarriedConsumables); what the player could make is not (no known recipe list here).
--
-- Brief K29 (the owner's ruling of 2026-10-09, Bottle of Dalaran Noir, the same in Jettison): a Food
-- and Drink item whose shipped effects state kinds, none of them a restore and none an effect
-- FactsFrom maps (alcohol, kind 13: the 28 alcohols of 1.60.1.70291), is no food at all
-- (Consumables.NotFood): not a soft keep as "Food or drink with a buff" (brief K26 read any spell
-- not named Food or Drink as a buff), never offered for auction as food with no use, so it goes by
-- its other facts (sold everywhere, its price), as ItemTree showed the bottle. A percent restore
-- (Harvest Bread: kind 1 with no restore entry) still names a restore kind, so it stays food.
--
-- Brief BQ6 (the owner's QA backlog of 2026-10-09 and 10-10, the same in Jettison):
--   29  "a better one in your bags" compares within a restore kind only: on the pool the item's own
--       restore is for (Consumables.MainPool: health, mana, or a bandage's heal), so a healing potion
--       never outranks a mana potion, whatever its size.
--   24  a bandage still relevant (a fifth of the pool or more, BQ16) beside a better usable bandage carried
--       is kept, but not as the best one: verdict.outranked, its words "Still useful, a better bandage
--       in your bags" (Jettison ranks it, and its surplus, to drop before the better one); under the
--       share with a better one carried it is "too weak", as K29 had it.
--   21  the class gate follows the player's specs where a Forever spec changes the stats a consumable
--       gives (Consumables.SPEC_WANTS, research-k27-classic-comparison.md): a spec adds a kind code or
--       a stat its class's mask leaves out. It held Survival's melee attack power (kind 24), strength
--       (kind 17, stat 4) and expertise (kind 54) and Marksmanship's intellect (stat 5, Careful Aim);
--       since brief EC2 the QA 163 masks name the hunter for all four, so every hunter spec wants them
--       and the table is empty, the machinery kept for a spec change the masks do not cover. specs is
--       the player's per character setting (Keep.EnabledSpecs: a set of Gear's spec keys, nil for
--       every spec), so by default a hunter counts all three specs, as the gear compare does. The
--       other spec changes the guides list move no consumable's answer: the classes already want the
--       kinds (Retribution and Protection spell power, Enhancement intellect, Affliction spirit,
--       Assassination and Arms attack power, Feral attack power, the priests' and the restoration
--       specs' spirit).
--   30  a food or drink kept for being the best one that is also an XP food while levelling reads
--       "Best food in your bags, more kill experience" (the owner had not answered; the
--       recommendation).
--
-- Brief EC2 (the owner's class mask rulings of 2026-10-14, QA 163: hunters always want strength,
-- attack power and expertise; spirit, crit, hit and dodge are every class's): a stat (ITEM_MOD 3
-- agility, 4 strength, 5 intellect, 6 spirit, 7 stamina) is wanted by the classes its kind's mask
-- names in the shipped module (classes[kind], kinds 19, 17, 12, 15 and 8: Consumables.StatMask),
-- the one table Jettison reads too. It replaces the addon's own STAT_CLASSES, which disagreed with
-- the masks (agility left out paladins and shamans, strength named only warriors and paladins,
-- spirit left out warriors, hunters and rogues). FALLBACK_STAT_MASKS answers for a call before the
-- module is loaded, and a class not known is never judged against (as a gated buff is not).
--
-- The functions above the divider are pure and run under busted with no WoW API.
local _, ItemTree = ...

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local Consumables = {}
ItemTree.Consumables = Consumables

local EMPTY = {}

Consumables.MODULE = "ItemEffects"

-- The kinds a judged consumable falls in, by its effects (Consumables.Kind).
Consumables.KIND_FOOD = "food"
Consumables.KIND_DRINK = "drink"
Consumables.KIND_POTION = "potion"
Consumables.KIND_BANDAGE = "bandage"
Consumables.KIND_BUFF = "buff"
Consumables.KIND_OTHER = "other"

-- The shares of the player's pool a restore must reach (Jettison R94). Brief K25g: the fallback
-- only, where the shipped module states no share (Consumables.ShareNeeded reads its own first).
Consumables.SHARE_FOOD = 0.75
Consumables.SHARE_INSTANT = 0.25
-- Brief K29: below this share of the health pool a bandage is no longer relevant, and it is kept only
-- while it is the best usable bandage carried. One constant, the same in Jettison; it replaces K25's
-- half (and the shipped module's bandage share, which no longer applies to bandages). Brief BQ16 (the
-- owner's ruling of 2026-10-10, QA item 3): "Let's bump the bandage rule to 20%" (was a tenth), so
-- Linen Bandage (66) at 427 health (15%) beside Heavy Linen is now "too weak".
Consumables.BANDAGE_IRRELEVANT_SHARE = 0.20

-- The look ahead on an item's required level (brief K24b's Keep.COULD_AHEAD, kept in step).
Consumables.AHEAD = 10

-- Brief K25f: how far below the player's level a food or drink's required level may be and still
-- count as a buff food (Consumables.BuffFood). The orchestrator's default (2026-10-09), the same in
-- Jettison, for the owner to tune in QA.
Consumables.BUFF_FOOD_LEVELS = 20

-- Brief K29: the level cap where the player's is not handed in (the owner's "else 60").
Consumables.LEVEL_CAP = 60

-- ChrClasses ids: 1 warrior, 2 paladin, 3 hunter, 4 rogue, 5 priest, 7 shaman, 8 mage,
-- 9 warlock, 11 druid. The classes with no mana pool.
Consumables.NO_MANA = { [1] = true, [4] = true }

-- Brief BQ6 (backlog 21): what a spec adds to its class's wants, by class id and Gear's spec key:
-- kinds, the shipped kind codes whose class mask leaves the class out but the spec wants; stats,
-- the ITEM_MOD stat ids whose kind's mask (Consumables.StatMask) leaves the class out. Only the
-- Forever spec changes that move a consumable's answer (the header lists the ones that do not).
-- Brief EC2: empty. The hunter's entries (Survival: kinds 17, 24, 54 and stat 4; Marksmanship:
-- stat 5) are the hunter's by the QA 163 masks (17, 24 and 54 1103, 12 1494), so every hunter spec
-- wants them and no "(Survival)" is named on a strength or attack power item.
Consumables.SPEC_WANTS = {}

--- Brief BQ30 (owner's spot fix, QA item 91): the player's enabled specs narrowed to those open at
--- their level (Gear.OpenSpecSet: a hunter under 30 has no Survival), the set as it came where Gear
--- is not loaded. Pure over Core/Gear.lua.
function Consumables.OpenSpecs(classId, specs, level)
  local gear = ItemTree.Gear
  if type(gear) == "table" and type(gear.OpenSpecSet) == "function" then
    return gear.OpenSpecSet(classId, specs, level)
  end
  return specs
end

--- Brief BQ6: whether one of the player's specs adds a kind code (what = "kinds") or a stat id
--- (what = "stats") to the class's wants. specs is the set of the player's enabled spec keys (Gear's
--- keys, Keep.EnabledSpecs), nil for every spec of the class. Pure.
function Consumables.SpecWants(classId, specs, what, code)
  local byClass = Consumables.SPEC_WANTS[tonumber(classId) or -1]
  code = tonumber(code)
  if type(byClass) ~= "table" or code == nil then
    return false
  end
  for spec, wants in pairs(byClass) do
    local on = specs == nil or (type(specs) == "table" and specs[spec] == true)
    local list = type(wants) == "table" and wants[what] or nil
    if on and type(list) == "table" and list[code] then
      return true
    end
  end
  return false
end

--- Brief BQ6: whether a gated kind is the class's: its mask holds the class, or one of the player's
--- specs adds it (Consumables.SpecWants). Pure.
function Consumables.KindForClass(mask, code, classId, specs)
  if Consumables.MaskHasClass(mask, classId) then
    return true
  end
  return Consumables.SpecWants(classId, specs, "kinds", code)
end

--- Brief BQ6 addendum (the coordinator's follow up to backlog 21, as K27's gear lines do): the specs
--- that want an item where FEWER than all of the player's enabled specs do, as { keys, labels } in
--- the class's order, else nil: nil where the item is useful with no spec addition (every spec wants
--- it), where no enabled spec wants it, and where every enabled spec does (the player turned the
--- others off). The enabled specs are Gear.ScoredSpecs over specs (nil: every spec of the class);
--- a label is Gear.SpecLabel's, the key where Gear is not loaded. Pure over Core/Gear.lua.
function Consumables.WantingSpecs(facts, classId, level, maxLevel, specs)
  classId = tonumber(classId)
  if type(facts) ~= "table" or classId == nil or Consumables.SPEC_WANTS[classId] == nil then
    return nil
  end
  if Consumables.Useful(facts, classId, level, maxLevel, EMPTY) then
    return nil
  end
  local gear = ItemTree.Gear
  local enabled = nil
  if type(gear) == "table" and type(gear.ScoredSpecs) == "function" then
    -- Brief BQ30: only the specs open at the player's level.
    enabled = gear.ScoredSpecs(classId, specs, level)
  end
  if type(enabled) ~= "table" then
    enabled = {}
    for spec in pairs(Consumables.SPEC_WANTS[classId]) do
      if specs == nil or (type(specs) == "table" and specs[spec] == true) then
        enabled[#enabled + 1] = spec
      end
    end
    table.sort(enabled)
  end
  local keys, labels = {}, {}
  for _, spec in ipairs(enabled) do
    if Consumables.Useful(facts, classId, level, maxLevel, { [spec] = true }) then
      keys[#keys + 1] = spec
      local label = type(gear) == "table" and type(gear.SpecLabel) == "function" and gear.SpecLabel(classId, spec)
        or nil
      labels[#labels + 1] = type(label) == "string" and label or spec
    end
  end
  -- Brief ST3 (bin F, the owner's ruling of 2026-10-10: "wanting specs in brackets"): the specs are
  -- named unless every spec of the class wants it, so a Survival only hunter still reads "(Survival)"
  -- where the other hunter specs do not want it (the BQ6 addendum named them only where fewer than
  -- all ENABLED specs did, which dropped the bracket for one enabled spec).
  local classSpecs = 0
  -- Brief BQ30: "every spec" is every spec open at the player's level (Gear.SpecsFor), so a hunter
  -- under 30 reads no bracket where Beast Mastery and Marksmanship both want it.
  local all = nil
  if type(gear) == "table" and type(gear.SpecsFor) == "function" then
    all = gear.SpecsFor(classId, level)
  elseif type(gear) == "table" and type(gear.SPECS) == "table" then
    all = gear.SPECS[classId]
  end
  if type(all) == "table" then
    classSpecs = #all
  else
    for _ in pairs(Consumables.SPEC_WANTS[classId]) do
      classSpecs = classSpecs + 1
    end
  end
  if #keys == 0 then
    return nil
  end
  if #keys >= classSpecs then
    local everyOne = true
    for _, spec in ipairs(type(all) == "table" and all or EMPTY) do
      if not Consumables.Useful(facts, classId, level, maxLevel, { [spec] = true }) then
        everyOne = false
      end
    end
    if everyOne then
      return nil
    end
  end
  return { keys = keys, labels = labels }
end

-- The words a kind is named by in the reason lines.
Consumables.KIND_WORDS = {
  food = L["food"],
  drink = L["drink"],
  potion = L["potion"],
  bandage = L["bandage"],
  buff = L["buff"],
  other = L["item"],
}

-- Brief K25d: the shipped module's codes (its own restoreKinds and kinds tables, FIXED codes per
-- ItemTree-Data docs/data-format.md, "Item effects") to the facts FactsFrom builds.
-- restoreKinds 1 heal, 2 mana, 3 food, 4 drink, 5 bandage, 6 heal over time, 7 mana over time,
-- 8 rage, 9 energy: what each restore adds to. Rage and energy are no pool the shares read, so
-- they are a buff.
Consumables.SHIPPED_RESTORES = {
  [1] = "health",
  [2] = "mana",
  [3] = "health",
  [4] = "mana",
  [5] = "bandage",
  [6] = "health",
  [7] = "mana",
  [8] = "buff",
  [9] = "buff",
}

-- kinds 8 stamina, 12 intellect, 15 spirit, 17 strength, 19 agility to their ITEM_MOD stat ids.
Consumables.SHIPPED_STATS = {
  [8] = 7,
  [12] = 5,
  [15] = 6,
  [17] = 4,
  [19] = 3,
}

-- Brief EC2: the other way, ITEM_MOD stat id to its kind code (3 to 19, 4 to 17, 5 to 12, 6 to 15,
-- 7 to 8), for the kind's class mask (Consumables.StatMask).
Consumables.STAT_KINDS = {}
for code, stat in pairs(Consumables.SHIPPED_STATS) do
  Consumables.STAT_KINDS[stat] = code
end

-- Brief EC2: the stat kinds' class masks where the shipped module cannot answer (a call before the
-- ItemEffects module is loaded, or a module with no classes table, as the contract's fixtures).
-- Mirrors ItemTree-Data's curated/effect_classes.json as of QA 163 (2026-10-14), and
-- tests/spec/consumables_spec.lua checks it against the installed module: 8 stamina and 15 spirit
-- every class (1503), 12 intellect 1494 (all but warrior and rogue), 17 strength and 19 agility
-- 1103 (warrior, paladin, hunter, rogue, shaman, druid).
Consumables.FALLBACK_STAT_MASKS = {
  [8] = 1503,
  [12] = 1494,
  [15] = 1503,
  [17] = 1103,
  [19] = 1103,
}

-- The kinds that are a real effect on the player or in play, each a buff: 9 damage, 11 crowd
-- control, 14 utility, 18 spell damage, 22 healing power, 23 cure or immunity, 24 attack power,
-- 25 ranged attack power, 27 absorb, 28 armour, 31 health, 32 resistance, 33 crit, 34 speed,
-- 35 mana regen, 36 health regen, 37 haste, 40 resurrect, 42 skill, 43 all damage, 45 hit, 47 spell
-- hit, 48 spell crit, 49 physical damage, 51 other power, 52 mana pool, 53 dodge, 54 expertise,
-- 58 damage shield, 59 block, 60 parry. Not here, so adding nothing: the restore kinds, read from
-- r with their amounts (1 food, 6 drink, 10 heal, 20 bandage, 21 mana, 38 heal over time, 39 rage,
-- 41 mana over time, 44 energy; a restore the module leaves out, a percent one, stays out), and
-- the kinds that are an action rather than an effect (2 learn other, 3 armour enhancement,
-- 4 weapon enhancement, 5 summon, 7 create item, 13 alcohol, 16 open container, 26 debuff,
-- 29 quest, 30 open lock, 46 teleport, 50 learn companion, 55 learn recipe, 56 learn mount,
-- 57 mount) or a code appended after these.
Consumables.SHIPPED_BUFFS = {
  [9] = true,
  [11] = true,
  [14] = true,
  [18] = true,
  [22] = true,
  [23] = true,
  [24] = true,
  [25] = true,
  [27] = true,
  [28] = true,
  [31] = true,
  [32] = true,
  [33] = true,
  [34] = true,
  [35] = true,
  [36] = true,
  [37] = true,
  [40] = true,
  [42] = true,
  [43] = true,
  [45] = true,
  [47] = true,
  [48] = true,
  [49] = true,
  [51] = true,
  [52] = true,
  [53] = true,
  [54] = true,
  [58] = true,
  [59] = true,
  [60] = true,
}

local function num(value)
  return tonumber(value) or 0
end

-- Brief K25e: the nine class ids (ChrClasses), for "a mask of all nine gates nothing".
Consumables.CLASS_IDS = { 1, 2, 3, 4, 5, 7, 8, 9, 11 }

--- The class mask that gates a kind code, from the module's own classes table, or nil for no gate:
--- no module, no classes table, no mask for the code, or a mask naming all nine classes. Pure.
function Consumables.GateOf(module, kindCode)
  local classes = type(module) == "table" and module.classes or nil
  local mask = type(classes) == "table" and tonumber(classes[tonumber(kindCode) or -1]) or nil
  if mask == nil or mask <= 0 then
    return nil
  end
  for _, classId in ipairs(Consumables.CLASS_IDS) do
    if not Consumables.MaskHasClass(mask, classId) then
      return mask
    end
  end
  return nil
end

-- Brief K25e: restore kind code to kind code, by name, per module (weak keys, so a module let go of
-- is not held here).
local restoreCodes = setmetatable({}, { __mode = "k" })

--- The kind code of the same name as a restore kind ("energy" restore 9 to kind 44, "rage" 8 to
--- 39), read through the module's own restoreKinds and kinds tables, or nil. Pure over the module.
function Consumables.RestoreKindCode(module, restoreKind)
  if type(module) ~= "table" or type(module.restoreKinds) ~= "table" or type(module.kinds) ~= "table" then
    return nil
  end
  local codes = restoreCodes[module]
  if codes == nil then
    codes = {}
    local byName = {}
    for code, name in pairs(module.kinds) do
      if type(code) == "number" and type(name) == "string" then
        byName[name] = code
      end
    end
    for code, name in pairs(module.restoreKinds) do
      if type(code) == "number" and type(name) == "string" then
        codes[code] = byName[name] or false
      end
    end
    restoreCodes[module] = codes
  end
  return codes[tonumber(restoreKind) or -1] or nil
end

-- Brief K25e: one buff's class gate onto the facts (nothing for an ungated buff). Brief BQ6: with
-- the kind code beside it (facts.gateCodes, the same index), for the spec additions.
local function addGate(facts, mask, code)
  if mask ~= nil then
    facts.gates = facts.gates or {}
    facts.gates[#facts.gates + 1] = mask
    facts.gateCodes = facts.gateCodes or {}
    facts.gateCodes[#facts.gates] = tonumber(code) or false
  end
end

-- Brief K25f: one buff or stat kind's class gate onto the facts by its code (nothing ungated).
local function addBuffKind(facts, code, mask)
  if mask ~= nil then
    facts.buffKinds = facts.buffKinds or {}
    facts.buffKinds[code] = mask
  end
end

--- The normalised facts of one ItemEffects entry, or nil for an entry with no effect. The entry
--- is either the shipped row as Consumables.Facts decodes it ({ k, r, z, s }, brief K25d) or the
--- contract's worked example ({ e, c, sk, skr }, the specs' fixtures). The one reader of the
--- shipped shape. module is the shipped module the entry came from, for its kinds, restoreKinds
--- and classes tables (brief K25e: facts.gates, one class mask per gated buff, absent where none
--- is gated); nil gates nothing. Brief K25f: facts.buffKinds = { [kindCode] = mask }, every buff
--- or stat kind of the row with a gate (absent where none), and facts.amounts = { [kindCode] =
--- amount }, the first amount slot 5 (a = { {kind, amount, percent, qualifier}, ... }, U3) states
--- for each kind (absent where the row states none, as on a module compiled before U3). Pure.
function Consumables.FactsFrom(entry, module)
  if type(entry) ~= "table" then
    return nil
  end
  local shipped = type(entry.e) ~= "table" and (type(entry.k) == "table" or type(entry.r) == "table")
  if not shipped and (type(entry.e) ~= "table" or #entry.e == 0) then
    return nil
  end
  if shipped then
    local facts = {
      health = 0,
      mana = 0,
      bandage = 0,
      seconds = 0,
      sit = false,
      stats = {},
      rested = 0,
      buffs = 0,
      classes = 0,
    }
    local found = false
    for _, restore in ipairs(type(entry.r) == "table" and entry.r or EMPTY) do
      local code = type(restore) == "table" and tonumber(restore[1]) or -1
      local adds = Consumables.SHIPPED_RESTORES[code]
      if adds == "buff" then
        facts.buffs = facts.buffs + 1
        -- Brief K25e: an energy or rage restore is gated by its kind's mask.
        local kindCode = Consumables.RestoreKindCode(module, code)
        addGate(facts, Consumables.GateOf(module, kindCode), kindCode)
        found = true
      elseif adds ~= nil and num(restore[2]) > 0 then
        facts[adds] = facts[adds] + num(restore[2])
        found = true
      end
      if adds ~= nil then
        if num(restore[4]) > facts.seconds then
          facts.seconds = num(restore[4])
        end
        if restore[5] == 1 then
          facts.sit = true
        end
      end
    end
    for _, code in ipairs(type(entry.k) == "table" and entry.k or EMPTY) do
      code = tonumber(code) or -1
      local stat = Consumables.SHIPPED_STATS[code]
      if stat then
        facts.stats[stat] = facts.stats[stat] or 0
        -- Brief K25f: a stat kind's own mask, for the buff food rule (Useful reads the same mask
        -- through Consumables.StatMask, brief EC2).
        addBuffKind(facts, code, Consumables.GateOf(module, code))
        found = true
      elseif Consumables.SHIPPED_BUFFS[code] then
        facts.buffs = facts.buffs + 1
        -- Brief K25e: a buff kind is gated by its own mask.
        local mask = Consumables.GateOf(module, code)
        addGate(facts, mask, code)
        addBuffKind(facts, code, mask)
        found = true
      elseif code == Consumables.KILL_XP_KIND then
        -- Brief K29: kill experience, every class's while levelling; its percent below.
        facts.killXp = 0
        found = true
      end
    end
    -- Brief K25f: the amounts, the first one per kind (the module orders them by kind, then unit,
    -- then qualifier; every food and drink with a gated buff states one per kind on 1.60.1.70170).
    for _, amount in ipairs(type(entry.a) == "table" and entry.a or EMPTY) do
      local code = type(amount) == "table" and tonumber(amount[1]) or nil
      local value = code and tonumber(amount[2]) or nil
      if value and (facts.amounts == nil or facts.amounts[code] == nil) then
        facts.amounts = facts.amounts or {}
        facts.amounts[code] = value
      end
    end
    -- Brief K29: the kill experience percent (0 where the row states none).
    if facts.killXp ~= nil and facts.amounts ~= nil and facts.amounts[Consumables.KILL_XP_KIND] then
      facts.killXp = facts.amounts[Consumables.KILL_XP_KIND]
    end
    if not found then
      return nil
    end
    facts.kind = Consumables.Kind(facts)
    return facts
  end
  local facts = {
    health = 0,
    mana = 0,
    bandage = 0,
    seconds = 0,
    sit = false,
    stats = {},
    rested = 0,
    buffs = 0,
    classes = num(entry.c),
    skill = tonumber(entry.sk),
    rank = tonumber(entry.skr),
  }
  for _, effect in ipairs(entry.e) do
    if type(effect) == "table" then
      local kind = effect.k
      if kind == "health" then
        facts.health = facts.health + num(effect.a)
      elseif kind == "mana" then
        facts.mana = facts.mana + num(effect.a)
      elseif kind == "bandage" then
        facts.bandage = facts.bandage + num(effect.a)
      elseif kind == "stat" then
        local stat = tonumber(effect.st)
        if stat then
          facts.stats[stat] = (facts.stats[stat] or 0) + num(effect.a)
        end
      elseif kind == "rested" then
        facts.rested = facts.rested + num(effect.p)
      elseif kind == "buff" then
        facts.buffs = facts.buffs + 1
      end
      if num(effect.s) > facts.seconds then
        facts.seconds = num(effect.s)
      end
      if effect.sit == 1 or effect.sit == true then
        facts.sit = true
      end
    end
  end
  facts.kind = Consumables.Kind(facts)
  return facts
end

-- Brief K29: the kind codes of the restores (ItemTree-Data docs/data-format.md, "Kind codes"): 1 food,
-- 6 drink, 10 heal, 20 bandage, 21 mana, 38 heal over time, 39 rage, 41 mana over time, 44 energy.
Consumables.RESTORE_KIND_CODES = {
  [1] = true,
  [6] = true,
  [10] = true,
  [20] = true,
  [21] = true,
  [38] = true,
  [39] = true,
  [41] = true,
  [44] = true,
}

-- Brief K29: kill experience, the kind the pipeline appended for Forever's Nutritious Food and
-- Drink (5 percent more experience from kills): facts.killXp (Consumables.XpFood), and a row that
-- states it is never "no food".
Consumables.KILL_XP_KIND = 61

--- Brief K29: whether a shipped entry (decoded, { k, r, ... }) says the item is no food or drink:
--- it names kinds, none of them a restore kind (RESTORE_KIND_CODES) or kill experience, and
--- FactsFrom maps none of them (alcohol alone). false for no entry, no kinds, a restore kind (a
--- percent restore the module leaves out of r included) or anything FactsFrom judges. Pure over
--- the module.
function Consumables.NotFood(entry, module)
  if type(entry) ~= "table" or type(entry.k) ~= "table" or #entry.k == 0 then
    return false
  end
  for _, code in ipairs(entry.k) do
    code = tonumber(code) or -1
    if Consumables.RESTORE_KIND_CODES[code] or code == Consumables.KILL_XP_KIND then
      return false
    end
  end
  return Consumables.FactsFrom(entry, module) == nil
end

--- Brief BQ23 (the owner's QA of 2026-10-10, item 38): camp item, the kind the pipeline appended for
--- Forever's camping family (Camp Chair, Camp Tent: a camp object with a buff at a campfire, the
--- shared camping cooldown, a profession requirement).
Consumables.CAMP_KIND = 62

--- Brief BQ23: whether a shipped entry (decoded, { k, ... }) names the camp item kind. Pure.
function Consumables.IsCamp(entry)
  if type(entry) ~= "table" or type(entry.k) ~= "table" then
    return false
  end
  for _, code in ipairs(entry.k) do
    if tonumber(code) == Consumables.CAMP_KIND then
      return true
    end
  end
  return false
end

--- The kind the facts fall in: food (health over time, sitting), drink (mana over time, sitting;
--- a food and drink is food), potion (any restore not sat for), bandage, buff (a stat, rested
--- experience or a named effect and no restore), else other. Pure.
function Consumables.Kind(facts)
  if type(facts) ~= "table" then
    return Consumables.KIND_OTHER
  end
  if facts.bandage > 0 then
    return Consumables.KIND_BANDAGE
  end
  if facts.health > 0 or facts.mana > 0 then
    if facts.sit then
      if facts.health > 0 then
        return Consumables.KIND_FOOD
      end
      return Consumables.KIND_DRINK
    end
    return Consumables.KIND_POTION
  end
  if next(facts.stats) ~= nil or facts.rested > 0 or facts.buffs > 0 or facts.killXp ~= nil then
    return Consumables.KIND_BUFF
  end
  return Consumables.KIND_OTHER
end

--- Brief EC2: the class mask of the classes that want an ITEM_MOD stat: its kind's mask in the
--- shipped module (classes[kind], Consumables.STAT_KINDS), else FALLBACK_STAT_MASKS where the module
--- is not loaded or states none; nil for a stat with no kind (every class's). module may be handed
--- in (a spec); nil reads the loaded one through Consumables.Module. Pure over the module.
function Consumables.StatMask(statId, module)
  local kind = Consumables.STAT_KINDS[tonumber(statId) or -1]
  if kind == nil then
    return nil
  end
  if module == nil and type(Consumables.Module) == "function" then
    module = Consumables.Module()
  end
  local classes = type(module) == "table" and module.classes or nil
  local mask = type(classes) == "table" and tonumber(classes[kind]) or nil
  if mask == nil or mask <= 0 then
    mask = Consumables.FALLBACK_STAT_MASKS[kind]
  end
  return mask
end

--- Whether a stat is one the class wants: its kind's mask names the class (Consumables.StatMask,
--- brief EC2), or the class is not known (never a guess against the player). Brief BQ6: or one of
--- the player's specs adds it (Consumables.SpecWants; specs nil is every spec). module as StatMask.
--- Pure over the module.
function Consumables.StatWanted(statId, classId, specs, module)
  local mask = Consumables.StatMask(statId, module)
  if mask == nil or tonumber(classId) == nil or Consumables.MaskHasClass(mask, classId) then
    return true
  end
  return Consumables.SpecWants(classId, specs, "stats", statId)
end

--- Whether the item is useful to the class: it has an effect the class wants beyond the ones every
--- class uses, or its effects are all ones every class uses. Second answer: why not ("class",
--- "rested"). level and maxLevel decide rested experience. Brief K25e: a buff with a class gate
--- (facts.gates) is wanted only by the classes its mask names; a buff with none is everyone's.
--- Brief BQ6: specs, the player's enabled specs (nil: every spec), add the kinds and stats
--- Consumables.SPEC_WANTS names. Pure.
function Consumables.Useful(facts, classId, level, maxLevel, specs)
  if type(facts) ~= "table" then
    return false, nil
  end
  classId = tonumber(classId)
  -- Brief BQ30: a spec closed at the player's level adds nothing.
  specs = Consumables.OpenSpecs(classId, specs, level)
  local wanted, named = false, false
  -- Effects every class uses.
  if facts.health > 0 or facts.bandage > 0 then
    wanted = true
  end
  -- Buffs: every class's where no gate names the classes, else the gate's classes (brief K25e).
  local gates = type(facts.gates) == "table" and facts.gates or EMPTY
  if facts.buffs > #gates then
    wanted = true
  end
  local gateCodes = type(facts.gateCodes) == "table" and facts.gateCodes or EMPTY
  for index, mask in ipairs(gates) do
    named = true
    if classId == nil or Consumables.KindForClass(mask, gateCodes[index], classId, specs) then
      wanted = true
    end
  end
  -- Mana: every class with a pool.
  if facts.mana > 0 then
    named = true
    if classId == nil or not Consumables.NO_MANA[classId] then
      wanted = true
    end
  end
  for statId in pairs(facts.stats) do
    named = true
    if Consumables.StatWanted(statId, classId, specs) then
      wanted = true
    end
  end
  if facts.rested > 0 then
    named = true
    level, maxLevel = tonumber(level), tonumber(maxLevel)
    if level == nil or maxLevel == nil or level < maxLevel then
      wanted = true
    elseif not wanted and facts.health == 0 and facts.mana == 0 and next(facts.stats) == nil then
      return false, "rested"
    end
  end
  -- Brief K29: kill experience is every class's while levelling (below the cap, LEVEL_CAP where
  -- none is handed in); an item that gives nothing else is no use at the cap.
  if facts.killXp ~= nil then
    named = true
    level = tonumber(level)
    if level == nil or level < (tonumber(maxLevel) or Consumables.LEVEL_CAP) then
      wanted = true
    elseif not wanted and facts.health == 0 and facts.mana == 0 and next(facts.stats) == nil then
      return false, "cap"
    end
  end
  if wanted then
    return true, nil
  end
  if named then
    return false, "class"
  end
  -- No effect at all that is known: not judged here.
  return false, nil
end

--- The share of the player's pool the restore reaches, or nil where no pool is known or the kind
--- has no restore. pools is { health = n, mana = n }. Pure.
function Consumables.Share(facts, pools)
  if type(facts) ~= "table" or type(pools) ~= "table" then
    return nil
  end
  if facts.kind == Consumables.KIND_BANDAGE then
    local pool = tonumber(pools.health)
    if pool and pool > 0 then
      return facts.bandage / pool
    end
    return nil
  end
  if
    facts.kind ~= Consumables.KIND_FOOD
    and facts.kind ~= Consumables.KIND_DRINK
    and facts.kind ~= Consumables.KIND_POTION
  then
    return nil
  end
  local best = nil
  if facts.health > 0 then
    local pool = tonumber(pools.health)
    if pool and pool > 0 then
      best = facts.health / pool
    end
  end
  if facts.mana > 0 then
    local pool = tonumber(pools.mana)
    if pool and pool > 0 then
      local share = facts.mana / pool
      if best == nil or share > best then
        best = share
      end
    end
  end
  return best
end

--- Brief K25g: the code the module's own restoreKinds table gives a restore kind's name ("food" 3,
--- "heal over time" 6), or nil. Pure over the module.
function Consumables.RestoreCodeNamed(module, name)
  local names = type(module) == "table" and module.restoreKinds or nil
  if type(names) ~= "table" or type(name) ~= "string" then
    return nil
  end
  for code, named in pairs(names) do
    if named == name and type(code) == "number" then
      return code
    end
  end
  return nil
end

-- Brief K25g: the restore kind, by its name in the module's own restoreKinds, whose share a judged
-- kind is held to on a pool: food "food", and on its mana side (a food and drink, Warsong Gulch
-- Enriched Ration) "drink"; drink "drink"; a bandage "bandage"; a potion (any restore not sat for)
-- "heal" or "mana", "heal over time" or "mana over time" where it restores over time (facts.seconds
-- above 0; no potion of 1.60.1.70170 carries both an instant and an over time restore). The facts
-- keep no restore codes, so this is the one place a kind is read back to one.
local function shareRestoreName(kind, pool, overTime)
  if kind == Consumables.KIND_BANDAGE then
    return "bandage"
  end
  if kind == Consumables.KIND_FOOD or kind == Consumables.KIND_DRINK then
    return pool == "mana" and "drink" or "food"
  end
  local name = pool == "mana" and "mana" or "heal"
  if overTime then
    return name .. " over time"
  end
  return name
end

--- The share a kind must reach. Brief K25g: the shipped module's own shares table first
--- (shares[restoreKind], ItemTree-Data curated/effect_shares.json, the one table Jettison's
--- effectShares is compiled from too), for the restore kind shareRestoreName names, found by name
--- through the module's restoreKinds; today's constants (SHARE_FOOD, SHARE_INSTANT) where there is
--- no module, no shares or restoreKinds table, no restore kind of that name or no share above 0 for
--- it (Jettison's EffectShareNeeded takes a share above 0 the same way). Brief K29: a bandage's is
--- BANDAGE_IRRELEVANT_SHARE, whatever the module says. pool is "health" or "mana" (nil: a drink's
--- mana, any other kind's health); overTime picks a potion's over time restore. nil for a kind that
--- is no restore. Pure over the module.
function Consumables.ShareNeeded(kind, module, pool, overTime)
  local fallback
  if kind == Consumables.KIND_FOOD or kind == Consumables.KIND_DRINK then
    fallback = Consumables.SHARE_FOOD
  elseif kind == Consumables.KIND_BANDAGE then
    return Consumables.BANDAGE_IRRELEVANT_SHARE
  elseif kind == Consumables.KIND_POTION then
    fallback = Consumables.SHARE_INSTANT
  else
    return nil
  end
  local shares = type(module) == "table" and module.shares or nil
  if type(shares) ~= "table" then
    return fallback
  end
  if pool == nil then
    pool = kind == Consumables.KIND_DRINK and "mana" or "health"
  end
  local code = Consumables.RestoreCodeNamed(module, shareRestoreName(kind, pool, overTime))
  local share = code and tonumber(shares[code]) or nil
  if share and share > 0 then
    return share
  end
  return fallback
end

-- Brief K25g: one pool's answer for Efficient: nil where the restore adds nothing to it or the
-- pool's size is not known, else whether it reaches the kind's share of that pool.
local function reaches(amount, size, kind, module, pool, overTime)
  amount, size = num(amount), tonumber(size)
  if amount <= 0 or size == nil or size <= 0 then
    return nil
  end
  return amount / size >= Consumables.ShareNeeded(kind, module, pool, overTime)
end

--- Whether a restore is worth carrying against the player's pools: true, false, or nil where the
--- kind is no restore or the pool is not known. Brief K25g: each pool it restores is held to its
--- own share (Consumables.ShareNeeded over module, the constants without one), and it is worth
--- carrying where any one reaches its share, as Jettison's EffectEfficiency judges each restore;
--- with one share per kind on both pools (the constants, and the shipped table today) that is the
--- best share against it, as before K25g. Pure over the module.
function Consumables.Efficient(facts, pools, module)
  local kind = type(facts) == "table" and facts.kind or nil
  if Consumables.ShareNeeded(kind) == nil or type(pools) ~= "table" then
    return nil
  end
  local overTime = num(facts.seconds) > 0
  local health, mana
  if kind == Consumables.KIND_BANDAGE then
    health = reaches(facts.bandage, pools.health, kind, module, "health", overTime)
  else
    health = reaches(facts.health, pools.health, kind, module, "health", overTime)
    mana = reaches(facts.mana, pools.mana, kind, module, "mana", overTime)
  end
  if health == nil and mana == nil then
    return nil
  end
  return health == true or mana == true
end

--- The restore a kind compares by: health for food and a bandage, mana for drink, the larger for a
--- potion. Pure.
function Consumables.Restore(facts)
  if type(facts) ~= "table" then
    return 0
  end
  if facts.kind == Consumables.KIND_BANDAGE then
    return facts.bandage
  end
  if facts.kind == Consumables.KIND_DRINK then
    return facts.mana
  end
  if facts.health > facts.mana then
    return facts.health
  end
  return facts.mana
end

-- Brief K25f: a profession's child skill line to its parent, for where the shipped Skills data
-- cannot be read (Consumables.ParentLine reads it first): 2942, First Aid's Forever child line the
-- bandage rows ask for, to 129, the line the client reports the player's First Aid as.
Consumables.SKILL_PARENTS = { [2942] = 129 }

--- Brief K25f: the parent line of a skill line, or nil for none: the shipped Skills data's own p
--- (SkillLine.ParentSkillLineID; 2937 to 2948 are the professions' child lines), else
--- SKILL_PARENTS where the data has no row for the line. Pure over the data tables.
function Consumables.ParentLine(skillLine)
  skillLine = tonumber(skillLine)
  if skillLine == nil then
    return nil
  end
  local d = ItemTree.Data
  if type(d) == "table" and type(d.Get) == "function" then
    local ok, skills = pcall(d.Get, d, "Skills")
    local row = ok and type(skills) == "table" and skills[skillLine] or nil
    if type(row) == "table" then
      return tonumber(row.p)
    end
  end
  return Consumables.SKILL_PARENTS[skillLine]
end

--- Brief RB5 (QA item 202): a skill line's name from the shipped Skills data (its n, "First Aid"), or
--- nil where the data does not name it. Pure over the data tables.
function Consumables.SkillName(skillLine)
  skillLine = tonumber(skillLine)
  local d = ItemTree.Data
  if skillLine == nil or type(d) ~= "table" or type(d.Get) ~= "function" then
    return nil
  end
  local ok, skills = pcall(d.Get, d, "Skills")
  local row = ok and type(skills) == "table" and skills[skillLine] or nil
  if type(row) == "table" and type(row.n) == "string" and row.n ~= "" then
    return row.n
  end
  return nil
end

--- Brief K25f: the player's rank in a skill line or in its parent line (Consumables.ParentLine),
--- the higher of the two, or nil where they have neither. A row asks for First Aid as the child
--- 2942 and the client reports it as 129. rankOf(skillLine) answers a rank or nil. Pure over the
--- data tables.
function Consumables.RankIn(rankOf, skillLine)
  if type(rankOf) ~= "function" then
    return nil
  end
  local function ask(line)
    local ok, answer = pcall(rankOf, line)
    return ok and tonumber(answer) or nil
  end
  local rank = ask(skillLine)
  local parent = Consumables.ParentLine(skillLine)
  if parent ~= nil and parent ~= tonumber(skillLine) then
    local held = ask(parent)
    if held ~= nil and (rank == nil or held > rank) then
      rank = held
    end
  end
  return rank
end

--- Whether the player has the skill an item needs (the facts' skill and rank, else the row's) at
--- that rank; true for an item that needs none. rankOf(skillLine) answers the rank or nil; brief
--- K25f: a child line is met by the rank in its parent (Consumables.RankIn). Pure over the data.
function Consumables.SkillMet(facts, row, rankOf)
  local skill = (type(facts) == "table" and facts.skill) or (type(row) == "table" and tonumber(row.sk)) or nil
  if not skill or skill <= 0 then
    return true
  end
  local need = (type(facts) == "table" and facts.rank) or (type(row) == "table" and tonumber(row.skr)) or 0
  local have = Consumables.RankIn(rankOf, skill)
  return have ~= nil and have >= need
end

--- Brief RB5 (QA item 202, the owner's ruling 2 of 2026-10-14 on Heavy Runecloth Bandage at First Aid
--- 46: "probably okay to keep if you are on First Aid; a character can bank those items if they are
--- far ahead"): the skill line an item needs (its parent line, Consumables.ParentLine, where it has one:
--- First Aid 129 for the child 2942) and the rank it needs, where the player HAS that line at a lower
--- rank; nil where the item needs no skill, the player meets it, or lacks the profession altogether
--- (then "Needs a skill you lack" stands). rankOf(skillLine) answers a rank or nil (Consumables.RankIn
--- reads the line and its parent). Pure over the data.
function Consumables.SkillAhead(facts, row, rankOf)
  local skill = (type(facts) == "table" and facts.skill) or (type(row) == "table" and tonumber(row.sk)) or nil
  if not skill or skill <= 0 then
    return nil
  end
  local need = tonumber((type(facts) == "table" and facts.rank) or (type(row) == "table" and row.skr)) or 0
  local have = Consumables.RankIn(rankOf, skill)
  if have == nil or have >= need then
    return nil
  end
  return Consumables.ParentLine(skill) or skill, need
end

--- Whether the player can use an item now: its required level is theirs or under, and its skill
--- is one they have at that rank (Consumables.SkillMet). Pure.
function Consumables.UsableNow(facts, row, level, rankOf)
  level = tonumber(level)
  local required = tonumber(type(row) == "table" and row.rl or nil)
  if required and required > 0 and (level == nil or required > level) then
    return false
  end
  return Consumables.SkillMet(facts, row, rankOf)
end

--- Brief BQ6 (backlog 29): the pool a restore is compared on, the one its own restore is for:
--- "bandage" for a bandage, "mana" for a drink, else the larger of its health and mana (a tie to
--- health), or nil for facts that restore neither. Pure.
function Consumables.MainPool(facts)
  if type(facts) ~= "table" then
    return nil
  end
  if facts.kind == Consumables.KIND_BANDAGE then
    return "bandage"
  end
  if facts.kind == Consumables.KIND_DRINK then
    return "mana"
  end
  local health, mana = num(facts.health), num(facts.mana)
  if health <= 0 and mana <= 0 then
    return nil
  end
  if health >= mana then
    return "health"
  end
  return "mana"
end

--- Whether the player carries a better item of the same kind they can use now. carried is a list
--- of { facts, row } for the consumables in the bags (the client's read, Keep.CarriedConsumables),
--- the item itself among them or not. Brief BQ6 (backlog 29): within a restore kind only, the other
--- restoring more on this item's own pool (Consumables.MainPool), so a bigger healing potion never
--- outranks a mana potion. Pure.
function Consumables.BetterUsable(facts, carried, level, rankOf)
  if type(facts) ~= "table" or type(carried) ~= "table" then
    return false
  end
  local pool = Consumables.MainPool(facts)
  local mine = pool and num(facts[pool]) or 0
  if mine <= 0 then
    return false
  end
  for _, other in ipairs(carried) do
    local theirs = type(other) == "table" and other.facts or nil
    if type(theirs) == "table" and theirs.kind == facts.kind and num(theirs[pool]) > mine then
      if Consumables.UsableNow(theirs, other.row, level, rankOf) then
        return true
      end
    end
  end
  return false
end

local function isFoodOrDrink(facts)
  return type(facts) == "table" and (facts.kind == Consumables.KIND_FOOD or facts.kind == Consumables.KIND_DRINK)
end

--- Brief K25f: the kind codes of the facts' gated buffs (facts.buffKinds) whose mask holds the
--- class, sorted; empty where there are none or the class is not known (no guess against the
--- player). Brief BQ6: or that one of the player's specs adds (specs nil: every spec). Pure.
function Consumables.WantedBuffKinds(facts, classId, specs)
  local out = {}
  classId = tonumber(classId)
  if type(facts) ~= "table" or type(facts.buffKinds) ~= "table" or classId == nil then
    return out
  end
  for code, mask in pairs(facts.buffKinds) do
    if Consumables.KindForClass(mask, code, classId, specs) then
      out[#out + 1] = code
    end
  end
  table.sort(out)
  return out
end

--- Brief K25f: whether the facts are a buff food for the class at its level: a food or drink (a
--- restore sat for) with a gated buff its class wants (Consumables.WantedBuffKinds), whose
--- required level (the row's rl; none or 0 reads as 1, as the data's "usable from" does) is no
--- more than BUFF_FOOD_LEVELS below the player's level. A level not known applies no window. Brief
--- BQ6: specs, the player's enabled specs (Consumables.WantedBuffKinds). Pure.
function Consumables.BuffFood(facts, classId, level, row, specs)
  if not isFoodOrDrink(facts) or #Consumables.WantedBuffKinds(facts, classId, specs) == 0 then
    return false
  end
  level = tonumber(level)
  if level == nil then
    return true
  end
  local required = tonumber(type(row) == "table" and row.rl or nil) or 0
  if required < 1 then
    required = 1
  end
  return level - required <= Consumables.BUFF_FOOD_LEVELS
end

--- Brief K25f: whether theirs betters mine on the wanted kinds: where both state an amount for
--- every kind, each of theirs at least mine and one higher (equal amounts are not better); where
--- either states none for one of them, a higher restore (Consumables.Restore). Pure.
function Consumables.BuffBetter(mine, theirs, kinds)
  local mineAmounts = type(mine) == "table" and type(mine.amounts) == "table" and mine.amounts or EMPTY
  local theirAmounts = type(theirs) == "table" and type(theirs.amounts) == "table" and theirs.amounts or EMPTY
  local stated = type(kinds) == "table" and #kinds > 0
  for _, code in ipairs(stated and kinds or EMPTY) do
    if tonumber(mineAmounts[code]) == nil or tonumber(theirAmounts[code]) == nil then
      stated = false
    end
  end
  if not stated then
    return Consumables.Restore(theirs) > Consumables.Restore(mine)
  end
  local higher = false
  for _, code in ipairs(kinds) do
    local ours, other = tonumber(mineAmounts[code]), tonumber(theirAmounts[code])
    if other < ours then
      return false
    end
    if other > ours then
      higher = true
    end
  end
  return higher
end

local function sameKinds(a, b)
  if #a ~= #b then
    return false
  end
  for index, code in ipairs(a) do
    if b[index] ~= code then
      return false
    end
  end
  return true
end

--- Brief K25f: whether the player carries a better buff food they can use now: another buff food
--- for the class at its level (Consumables.BuffFood) whose wanted buff kinds are exactly these
--- facts' and which betters them (Consumables.BuffBetter). carried is Consumables.BetterUsable's
--- list. Brief BQ6: specs, the player's enabled specs. Pure.
function Consumables.BetterBuffFood(facts, carried, level, rankOf, classId, specs)
  local kinds = Consumables.WantedBuffKinds(facts, classId, specs)
  if #kinds == 0 or type(carried) ~= "table" then
    return false
  end
  for _, other in ipairs(carried) do
    -- Brief K25g: an entry that is no table is skipped before its row is read, as BetterUsable does.
    local theirs = type(other) == "table" and other.facts or nil
    if
      type(theirs) == "table"
      and Consumables.BuffFood(theirs, classId, level, other.row, specs)
      and sameKinds(kinds, Consumables.WantedBuffKinds(theirs, classId, specs))
      and Consumables.BuffBetter(facts, theirs, kinds)
      and Consumables.UsableNow(theirs, other.row, level, rankOf)
    then
      return true
    end
  end
  return false
end

--- Brief K29: whether the facts are an XP food at the player's level: a food or drink (a restore sat
--- for) whose buff raises the experience from kills (facts.killXp), while the player is below the
--- level cap (maxLevel, else LEVEL_CAP). A level not known counts as levelling. Pure.
function Consumables.XpFood(facts, level, maxLevel)
  if not isFoodOrDrink(facts) or facts.killXp == nil then
    return false
  end
  level = tonumber(level)
  return level == nil or level < (tonumber(maxLevel) or Consumables.LEVEL_CAP)
end

--- Brief K29: whether the player carries a better XP food they can use now: another XP food with at
--- least these facts' kill experience that betters them by the rule that applies to them today: a
--- better buff food (Consumables.BetterBuffFood) where buffFood says they are one for the class,
--- else a higher restore of the same kind (Consumables.BetterUsable). Brief BQ6: specs, the
--- player's enabled specs. Pure.
function Consumables.BetterXpFood(facts, carried, level, rankOf, classId, maxLevel, buffFood, specs)
  if type(facts) ~= "table" or type(carried) ~= "table" then
    return false
  end
  local mine = tonumber(facts.killXp) or 0
  local rivals = {}
  for _, other in ipairs(carried) do
    local theirs = type(other) == "table" and other.facts or nil
    if Consumables.XpFood(theirs, level, maxLevel) and (tonumber(theirs.killXp) or 0) >= mine then
      rivals[#rivals + 1] = other
    end
  end
  if buffFood then
    return Consumables.BetterBuffFood(facts, rivals, level, rankOf, classId, specs)
  end
  return Consumables.BetterUsable(facts, rivals, level, rankOf)
end

--- The verdict for one item: { kind, useful, efficient, better, keep, why, words, buffFood }.
--- row is the shipped item row (its required level, skill and class mask), player is
--- { classId, level, maxLevel, pools = { health, mana }, rankOf, carried }. why names the first
--- reason it is not kept ("class", "rested", "weak", "better", "level", "skill") and words the
--- reason line for the tooltip (Consumables.Words). Brief K25f: buffFood is whether it is a buff
--- food for the class at its level (Consumables.BuffFood); efficient is still its restore's share
--- answer, which a buff food is not held to, and its better is a better buff food
--- (Consumables.BetterBuffFood). Brief K25g: player.module is the shipped module the facts came
--- from, whose shares table Consumables.Efficient reads (nil: the constants). Brief K29: xpFood is
--- whether it is an XP food at the player's level (Consumables.XpFood): never weak, and its better
--- is a better XP food (Consumables.BetterXpFood). Brief BQ6: player.specs, the player's enabled
--- specs (Keep.EnabledSpecs, nil for every spec) for the class gate (Consumables.SPEC_WANTS); restore,
--- the amount it is compared by (Consumables.Restore, 0 for none), for another addon's order; and
--- outranked, a bandage kept while relevant beside a better usable one carried (backlog 24).
--- Pure.
function Consumables.Judge(facts, row, player)
  player = type(player) == "table" and player or EMPTY
  local out = { kind = type(facts) == "table" and facts.kind or Consumables.KIND_OTHER }
  if type(facts) ~= "table" then
    out.keep, out.why = false, nil
    return out
  end
  out.restore = Consumables.Restore(facts)
  local specs = type(player.specs) == "table" and player.specs or nil
  -- Brief BQ30: the specs open at the player's level, for every rule below.
  specs = Consumables.OpenSpecs(player.classId, specs, player.level)
  local useful, why = Consumables.Useful(facts, player.classId, player.level, player.maxLevel, specs)
  out.useful = useful
  if not useful then
    out.keep, out.why = false, why
    out.words = Consumables.Words(out)
    return out
  end
  -- The row's own class mask gates it as brief K24b did, where the effects name no class.
  local mask = facts.classes
  if mask == 0 and type(row) == "table" then
    mask = num(row.ac)
  end
  if mask > 0 and (tonumber(player.classId) == nil or not Consumables.MaskHasClass(mask, player.classId)) then
    out.keep, out.why = false, "class"
    out.words = Consumables.Words(out)
    return out
  end
  local level = tonumber(player.level)
  local required = tonumber(type(row) == "table" and row.rl or nil)
  if required and required > 0 and level ~= nil and required > level + Consumables.AHEAD then
    out.keep, out.why = false, "level"
    out.words = Consumables.Words(out)
    return out
  end
  if not Consumables.SkillMet(facts, row, player.rankOf) then
    -- Brief RB5 (QA item 202, the owner's ruling 2 of 2026-10-14): a profession the player has at a
    -- lower rank is "ahead", not "skill": no use now, but Core/Keep.lua keeps it far ahead (banked
    -- until the rank comes, Keep.ConsumableAhead). "skill" is only for a profession the player lacks.
    local line, rank = Consumables.SkillAhead(facts, row, player.rankOf)
    if line then
      out.keep, out.why, out.ahead = false, "ahead", true
      out.skill, out.skillRank = line, rank
      out.words = Consumables.Words(out)
      return out
    end
    out.keep, out.why = false, "skill"
    out.words = Consumables.Words(out)
    return out
  end
  out.efficient = Consumables.Efficient(facts, player.pools, player.module)
  -- Brief K25f: a buff food is never too weak by its restore, and gives way to a better buff food.
  out.buffFood = Consumables.BuffFood(facts, player.classId, level, row, specs)
  -- Brief K29: nor is an XP food while the player levels, and it gives way to a better XP food.
  out.xpFood = Consumables.XpFood(facts, level, player.maxLevel)
  -- Brief K29: a bandage is kept while relevant (its share, BANDAGE_IRRELEVANT_SHARE), never bettered
  -- while it is; brief ST4: below the share it is too weak, the only one held or not.
  if facts.kind == Consumables.KIND_BANDAGE then
    return Consumables.JudgeBandage(out, facts, player, level)
  end
  if out.efficient == false and not out.buffFood and not out.xpFood then
    out.keep, out.why = false, "weak"
    out.words = Consumables.Words(out)
    return out
  end
  if out.xpFood then
    out.better = Consumables.BetterXpFood(
      facts,
      player.carried,
      level,
      player.rankOf,
      player.classId,
      player.maxLevel,
      out.buffFood,
      specs
    )
  elseif out.buffFood then
    out.better = Consumables.BetterBuffFood(facts, player.carried, level, player.rankOf, player.classId, specs)
  else
    out.better = Consumables.BetterUsable(facts, player.carried, level, player.rankOf)
  end
  if out.better then
    out.keep, out.why = false, "better"
    out.words = Consumables.Words(out)
    return out
  end
  -- Brief ST4 (G1): the conjure rule, plain food and drink only (Consumables.Conjures).
  if Consumables.Conjures(out, facts, player.conjure, player.module) then
    out.keep, out.why = false, "conjure"
    out.words = Consumables.Words(out)
    return out
  end
  out.keep = true
  -- Brief BQ6 addendum: the specs that want it, where fewer than all enabled ones do.
  local wanting = Consumables.WantingSpecs(facts, player.classId, level, player.maxLevel, specs)
  if wanting then
    out.specs, out.specLabels = wanting.keys, wanting.labels
  end
  out.words = Consumables.Words(out)
  return out
end

--- Brief ST4 (G1): whether the facts are a plain food or drink: a restore effect and nothing else
--- (no buff kind of any sort, no kill experience). Pure.
function Consumables.IsPlain(facts)
  if type(facts) ~= "table" or not isFoodOrDrink(facts) or facts.killXp ~= nil then
    return false
  end
  return type(facts.buffKinds) ~= "table" or next(facts.buffKinds) == nil
end

--- Brief ST4 (G1, the owner's ruling of 2026-10-10 and the guide review's refinement): the conjure
--- rule, which only ever looks at plain food and drink (Consumables.IsPlain): whether the
--- character's best known conjure rank makes one that restores at least as much. conjure is
--- { food = itemId, drink = itemId } (Keep.Conjured); the conjured item's restore is
--- Consumables.Restore over the shipped facts. Pure over module.
function Consumables.Conjures(out, facts, conjure, module)
  if type(out) ~= "table" or type(conjure) ~= "table" or not Consumables.IsPlain(facts) then
    return false
  end
  local made = nil
  if out.kind == Consumables.KIND_FOOD then
    made = conjure.food
  elseif out.kind == Consumables.KIND_DRINK then
    made = conjure.drink
  end
  if made == nil then
    return false
  end
  local ok, theirs = pcall(Consumables.Facts, tonumber(made), module)
  if not ok or type(theirs) ~= "table" then
    return false
  end
  return Consumables.Restore(theirs) >= Consumables.Restore(facts)
end

--- Brief K29: the rest of Judge for a bandage whose gates passed (out.efficient already its
--- relevance against BANDAGE_IRRELEVANT_SHARE): kept while relevant or unknown; below the share,
--- "weak" when a better usable bandage is carried (out.better, Consumables.BetterUsable), else kept
--- as the best usable one. Brief BQ6 (backlog 24): kept while relevant with a better usable bandage
--- carried is out.outranked, still kept but not the best one ("Still useful, a better bandage in
--- your bags"). Pure.
function Consumables.JudgeBandage(out, facts, player, level)
  local better = Consumables.BetterUsable(facts, player.carried, level, player.rankOf)
  -- Brief ST4 (the owner's ruling of 2026-10-10 on Jettison's consumable:41, "Weak and vendor it"): the
  -- share runs first, as for food and drink: below BANDAGE_IRRELEVANT_SHARE a bandage is too weak even
  -- as the only one held; "Best bandage in your bags" is for one that passes the share.
  if out.efficient == false then
    out.better = better or nil
    out.keep, out.why = false, "weak"
    out.words = Consumables.Words(out)
    return out
  end
  out.outranked = better or nil
  out.keep = true
  out.words = Consumables.Words(out)
  return out
end

--- Whether a class mask names a class (bit classId - 1). Pure.
function Consumables.MaskHasClass(mask, classId)
  mask, classId = tonumber(mask), tonumber(classId)
  if not mask or not classId or mask <= 0 or classId < 1 then
    return false
  end
  local bit = 2 ^ (classId - 1)
  return mask % (bit * 2) >= bit
end

--- The reason line for a verdict: the keep's "Best food in your bags", or why not. Brief BQ6
--- addendum: a keep that only some of the player's specs want names them in brackets
--- (verdict.specLabels: "You could use this (Survival)"). Pure.
function Consumables.Words(verdict)
  local words = Consumables.PlainWords(verdict)
  local labels = type(verdict) == "table" and verdict.keep and verdict.specLabels or nil
  if type(words) == "string" and type(labels) == "table" and #labels > 0 then
    return string.format(L["%s (%s)"], words, table.concat(labels, ", "))
  end
  return words
end

--- The reason line without the spec brackets (Consumables.Words). Pure.
function Consumables.PlainWords(verdict)
  if type(verdict) ~= "table" then
    return nil
  end
  local kindWord = Consumables.KIND_WORDS[verdict.kind] or Consumables.KIND_WORDS.other
  if verdict.keep then
    -- Brief K29: kept for its kill experience alone (no buff food, and its restore does not keep
    -- it: under its share, or a pool the class does not have, a warrior's mana).
    if verdict.xpFood and verdict.efficient ~= true and not verdict.buffFood then
      return L["More kill experience while levelling"]
    end
    if verdict.kind == Consumables.KIND_BUFF or verdict.kind == Consumables.KIND_OTHER then
      return L["You could use this"]
    end
    -- Brief BQ6 (backlog 24): a relevant bandage beside a better usable one carried.
    if verdict.outranked then
      return L["Still useful, a better bandage in your bags"]
    end
    -- Brief BQ6 (backlog 30, the recommendation): the best food that is also an XP food while
    -- levelling names both.
    if verdict.xpFood then
      return string.format(L["Best %s in your bags, more kill experience"], kindWord)
    end
    return string.format(L["Best %s in your bags"], kindWord)
  end
  if verdict.why == "weak" then
    return L["Too weak for your level"]
  elseif verdict.why == "better" then
    return string.format(L["Better %s in your bags"], kindWord)
  elseif verdict.why == "class" then
    return L["Not for your class"]
  elseif verdict.why == "rested" or verdict.why == "cap" then
    return L["No use at the level cap"]
  elseif verdict.why == "level" then
    return L["Can't use at your level"]
  elseif verdict.why == "skill" then
    return L["Needs a skill you lack"]
  elseif verdict.why == "ahead" then
    -- Brief RB5 (QA item 202): "Useful at First Aid 225", the line named where the data names it.
    local name = Consumables.SkillName(verdict.skill)
    if name and tonumber(verdict.skillRank) then
      return string.format(L["Useful at %s %d"], name, tonumber(verdict.skillRank))
    end
    return L["Useful once your skill is higher"]
  elseif verdict.why == "conjure" then
    -- Brief ST4 (G1).
    if verdict.kind == Consumables.KIND_DRINK then
      return L["You can conjure water as good"]
    end
    return L["You can conjure food as good"]
  end
  return nil
end

--------------------------------------------------------------------------------
-- Client side. Guarded.
--------------------------------------------------------------------------------

local function data()
  local d = ItemTree.Data
  if type(d) == "table" and type(d.Get) == "function" then
    return d
  end
  return nil
end

--- The shipped ItemEffects module, or nil until it ships. One Data:Get, under pcall.
function Consumables.Module()
  local d = data()
  if not d then
    return nil
  end
  local ok, module = pcall(d.Get, d, Consumables.MODULE)
  if ok and type(module) == "table" then
    return module
  end
  return nil
end

--- The facts for one item id, or nil (no module, or no entry). module may be handed in (a spec).
--- Brief K25d: the shipped module is packed, so its row is decoded through Data.ModuleRow, as
--- Data:GetItem decodes an item row; a plain module's entry (the specs' fixtures) is read as it is.
function Consumables.Facts(itemId, module)
  local id = tonumber(itemId)
  if not id then
    return nil
  end
  module = module or Consumables.Module()
  if type(module) ~= "table" then
    return nil
  end
  local entry = module[id]
  local d = ItemTree.Data
  if type(entry) == "string" and type(d) == "table" and type(d.ModuleRow) == "function" then
    local ok, row = pcall(d.ModuleRow, module, id)
    entry = ok and row or nil
  end
  -- Brief K25e: the module's own tables gate the buffs.
  return Consumables.FactsFrom(entry, module)
end

--- Brief K29: whether the shipped effects say the item is no food or drink (Consumables.NotFood);
--- false where no module ships or it has no entry. module may be handed in (a spec).
function Consumables.IsNotFood(itemId, module)
  local id = tonumber(itemId)
  module = module or (id and Consumables.Module() or nil)
  if not id or type(module) ~= "table" then
    return false
  end
  local entry = module[id]
  local d = ItemTree.Data
  if type(entry) == "string" and type(d) == "table" and type(d.ModuleRow) == "function" then
    local ok, row = pcall(d.ModuleRow, module, id)
    entry = ok and row or nil
  end
  return Consumables.NotFood(entry, module)
end

--- Brief BQ23: whether the shipped effects say the item is a camp item (Consumables.IsCamp); false
--- where no module ships or it has no entry. module may be handed in (a spec).
function Consumables.IsCampItem(itemId, module)
  local id = tonumber(itemId)
  module = module or (id and Consumables.Module() or nil)
  if not id or type(module) ~= "table" then
    return false
  end
  local entry = module[id]
  local d = ItemTree.Data
  if type(entry) == "string" and type(d) == "table" and type(d.ModuleRow) == "function" then
    local ok, row = pcall(d.ModuleRow, module, id)
    entry = ok and row or nil
  end
  return Consumables.IsCamp(entry)
end

--- The player's pools, { health, mana }, from UnitHealthMax and UnitPowerMax (mana is power 0),
--- each under pcall; a missing one is left out, so Consumables.Efficient answers nil for it.
function Consumables.Pools()
  local pools = {}
  local healthMax = rawget(_G, "UnitHealthMax")
  if type(healthMax) == "function" then
    local ok, value = pcall(healthMax, "player")
    if ok and tonumber(value) and tonumber(value) > 0 then
      pools.health = tonumber(value)
    end
  end
  local powerMax = rawget(_G, "UnitPowerMax")
  if type(powerMax) == "function" then
    local ok, value = pcall(powerMax, "player", 0)
    if ok and tonumber(value) and tonumber(value) > 0 then
      pools.mana = tonumber(value)
    end
  end
  -- Brief ST4 (bin B): the demo state's pretend pools over the client's (/itemtree demo health).
  local demo = ItemTree.Demo
  if type(demo) == "table" and type(demo.Pools) == "function" then
    local ok, pretend = pcall(demo.Pools, pools)
    if ok and type(pretend) == "table" then
      return pretend
    end
  end
  return pools
end

return Consumables
