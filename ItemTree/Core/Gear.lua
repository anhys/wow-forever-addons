-- Gear facts for the Keep verdict (design K20d, brief K20-facts): which worn slots an item goes in,
-- whether the player's class can use it, and whether it is an upgrade on what is worn.
-- Loaded as: local _, ItemTree = ...
--
-- Item level was the first proxy (brief K20-facts), the armour kind the second (brief K24h, below).
-- Brief K27 weighs the stats too, per spec of the player's class (below). Every fact about an item
-- comes from its shipped row (it inventory type, il item level, rl required level, c class, sc
-- subclass, ac allowable class mask, q quality, stats, es, arm, dmg, dl), never from the client:
-- this file asks the server nothing (bible C3). The client is asked the worn ids, the player's
-- class and level, and (brief K28) a worn piece's link where its row may roll a suffix, and
-- nothing else.
--
-- Brief K24h (tester QA 2026-10-07, a grey mail piece read [Vendor] beside worn cloth of the same
-- item level): body armour (cloth, leather, mail, plate on a body slot) is held by its KIND as
-- well as its level, since the shipped rows of grey and white gear were thought to carry no armour
-- value (brief K27: out of date; the armour curves cover every quality, and the rows of
-- 1.60.1.70170 carry it on 255 of 257 grey and all 557 white cloth, leather, mail and plate body
-- pieces, which Gear.Worth weighs). A kind lighter than the worn piece's is never an upgrade
-- (Jettison's own rule, so the two addons agree); a heavier kind at the worn level or above is
-- one; a heavier kind below the worn level is one only where both pieces are below uncommon
-- quality (no stats to weigh, armour alone), by the kind weights in Gear.ARMOUR_KIND_WEIGHT. An
-- empty slot is an upgrade for anything that goes in it. The player's class and level decide what
-- is wearable (Gear.Usable), not this compare.
--
-- Brief K27 (owner 2026-10-08, "a true gear upgrade by stats and the player's spec"): with the
-- player's class id, the item is scored for EVERY spec of that class (Gear.SPECS, no talent read)
-- by curated stat weights (Gear.SPEC_WEIGHTS), and the answer names the specs it is an upgrade
-- for. Gear.Worth is the weighted sum of a row's stats and its equip effects' stats (es, the same
-- codes), its armour and, for a weapon, its damage per second; hit, crit, dodge, parry, block and
-- haste are ratings, read as the percent they give (a row's stats at the player's level, es at
-- the level 60 rate) since the weights are per 1%. The owner's per character setting
-- (Core/Keep.lua Keep.EnabledSpecs) can leave specs out: only the enabled specs are scored
-- (Gear.ScoredSpecs), and every rule below reads "every spec" as "every enabled spec". The rules,
-- in the order they apply:
--   empty slot      an upgrade for each spec the item's Worth is above 0 for, basis "empty" with
--                   specs; where no spec weighs anything on it, the K24h answer (every spec). Never
--                   gated: an empty slot is an upgrade for anything wearable.
--   the spec gate   an item carrying a stat some class weighs (Gear.GATE_STATS) that is worth
--                   nothing, apart from its armour, to ANY spec of the class (each weight at
--                   Gear.GATE_MIN_WEIGHT or more) is not an upgrade, whatever its level, its kind
--                   or what is worn (Shadow spell damage on a paladin): "not_upgrade", basis
--                   "stats", specs empty. A weapon's damage a spec weighs saves it from the gate;
--                   armour does not. A resistance or any stat no class weighs never gates.
--   per spec        the item's Worth against the worn reference's for that spec (the same pieces
--                   reference holds it against, by Worth rather than level: rings, trinkets and a
--                   dual wielder's one hander against the WEAKER piece for that spec, a two hander
--                   against the hands summed). Above it by more than the margin
--                   (Gear.WORTH_MARGIN) is an upgrade, below it by more is not; within it is a
--                   tie, which K24h's answer breaks (a heavier body armour kind at the worn level
--                   or above, or a higher item level, is an upgrade; a lighter kind never), so
--                   the kind rule is a tie breaker and never a veto: a Holy Paladin's cloth with
--                   Intellect beats plate without. A spec that weighs neither piece is not named.
--   basis "stats"   where any spec weighs either piece; specs lists the specs it upgrades in the
--                   class's order, and "upgrade" means an upgrade for ANY spec
-- The fallbacks to the K24h answer (level, kind, lighter, empty; specs nil), every one of them:
--   no classId, or a class Gear.SPECS does not list (the K24h answer exactly, as before K27)
--   a green or better row with no stats and no es, the item or the worn reference (a random suffix
--     item whose roll the row does not carry, Gear.StatsUnknown; brief K28 hands in the roll)
--   the item carries nothing Worth reads (no stats, no es, no armour value, not a weapon with
--     damage and a delay: a shirt, a tabard, a row of a build that ships no armour value)
--   a worn reference piece carries nothing Worth reads (its row is not known, or holds none of
--     those fields), where K24h can still answer by its level
--   the item and the worn reference both worth 0 to every spec scored (nothing weighed on either
--     side: a mage's staff damage, which no mage spec weighs). Every spec weighs armour a little,
--     so two armour pieces with an armour value are always weighed.
-- Brief GW2 (the owner's paladin test of 0.1.11, QA item 139): a weapon or off hand piece is judged
-- PER SPEC against that spec's own weapon layout (Gear.WEAPON_LAYOUTS, Gear.LayoutTakes): only the
-- specs whose layouts take the candidate are scored (a held book only a one hand and held off hand
-- spec, a shield only a shield spec, a two hander only a two hand spec, a one hander only a spec
-- with a one hander in the main hand); where none does, "not_upgrade", basis "stats", specs empty
-- (Keep words it "Not for your specs"). An off hand piece (shield, held, off hand weapon) while a
-- two hander is worn is held against an EMPTY off hand for those specs (their layout has an off
-- hand there; it was "unknown" before GW2, which Keep printed as "Needs level N"); with no class,
-- or a class with no specs, it stays "unknown" as before.
--
-- Brief K28 (random suffix gear, "Buccaneer's Cord of Shadow Wrath", "of the Bear"): such an item is
-- one id for every roll and its row states no stats for any of them; the roll travels in the item
-- LINK. Gear.SuffixStats reads the link (pure string work, Gear.ParseItemLink), looks its bonus ids
-- (Forever) or its suffix id (a Classic Era layout) up in the RandomSuffixes module (ItemTree_Data,
-- brief K28 data side) and prices each share by the row's rp, floor(share * rp / 10000 + 0.5). The
-- answer is a ROLL, { stats = the priced shares, es = the flat values }, each a {{stat, value}}
-- list in es's codes, kept apart because their units differ (the owner's Fable review, 2026-10-09):
-- a priced share is part of the item's own budget and is read like the row's stats (a rating at
-- the player's level), a flat value is a fixed effect read like es (a rating at the level 60
-- rate); the two are never summed into one list. Gear.Worth and Gear.Compare take the roll as an
-- extra argument (Worth's fifth, Compare's seventh), and the stats compare, the spec gate and the
-- readable test all count it. Nothing is ever written onto a shipped row (Data shares its decoded
-- rows): the roll is a table of its own, held per link string. A worn piece carries its roll on
-- its entry (sfx, read from GetInventoryItemLink by Gear.ReadWorn) and the roll's key (sfxKey),
-- which joins Gear.Signature, so a re-roll of the same id signs differently. No module, no rp
-- (shares only), no link or no suffix in it: no roll, and every answer is exactly the K27 one.
--
-- The contract (brief K20-wire wires it into Core/Keep.lua: an upgrade is a Keep, and the gear
-- lines under the verdict):
--   Gear.SlotsFor(it)                    the worn slot ids an inventory type goes in, or nil
--   Gear.Usable(row, classId, level)     true, false or nil (not gear, or not known), and a reason
--   Gear.CanDualWield(classId, level)    whether the class wields a weapon in the off hand
--   Gear.Compare(row, worn, canDualWield, classId, enabledSpecs, playerLevel, suffix)
--                                        "upgrade", "not_upgrade" or "unknown", the item level
--                                        difference (row.il minus the worn reference), the slot
--                                        compared against and the basis (brief K24h): "level",
--                                        "kind" (a heavier armour kind), "lighter" (a lighter
--                                        one, never an upgrade), "empty" (nothing worn) or, brief
--                                        K27, "stats" (Worth per spec decided). Brief K27: a fifth
--                                        answer, specs, the spec keys it is an upgrade for in the
--                                        class's order (nil unless the stats compare decided: basis
--                                        "stats", or "empty" with a classId and something weighed),
--                                        and a sixth, the worn slots an upgraded spec was held
--                                        against (nil where specs is). classId nil is the K24h
--                                        compare exactly. enabledSpecs, the set of spec keys to
--                                        score (nil: every spec); playerLevel, the level a rating
--                                        in a row's stats is read at (nil: 60); brief K28: suffix,
--                                        the item's roll (Gear.SuffixStats' { stats, es }; nil:
--                                        none, the K27 answer exactly). worn is
--                                        { [slot] = { itemId = n, il = n or nil, it = n or nil,
--                                                     q = n or nil, sc = n or nil, c = n or nil,
--                                                     arm = n or nil, dl = n or nil,
--                                                     dmg = { min, max } or nil,
--                                                     stats = { { stat, value } } or nil,
--                                                     es = { { stat, value } } or nil,
--                                                     us = { { stat, value } } or nil,
--                                                     sfx = { stats = { { stat, value } } or nil,
--                                                             es = { { stat, value } } or nil }
--                                                           or nil,
--                                                     sfxKey = string or nil } },
--                                        an empty slot absent
--   Gear.Worth(row, classId, spec, level, suffix)
--                                        brief K27: the row's worth to one spec at the player's
--                                        level (nil: 60), or nil where the row is not gear or the
--                                        spec is not known; brief K28: plus suffix (nil: the
--                                        row's own sfx, which only a worn entry carries)
--   Gear.ParseItemLink(link)             brief K28: { id, suffix, count, bonus, refused } from an
--                                        item link or item string, or nil; a count the link cannot
--                                        back (Gear.MAX_BONUS_IDS) is refused, no roll
--   Gear.SuffixStats(link, row, module)  brief K28: the roll, { stats = priced shares, es = flat
--                                        values }, and its key, or nil where the link carries no
--                                        roll the module prices
--   Gear.SuffixModule()                  brief K28: the RandomSuffixes module where it is
--                                        registered or built, else nil (never loads ItemTree_Data)
--   Gear.MayRoll(row, module)            brief K28: whether a row's link is worth reading at all
--   Gear.StatsUnknown(row, suffix)       brief K27 round 4: a green or better whose stats the row does
--                                        not carry (K24h's answer); brief K28: suffix, the roll, or a
--                                        worn entry's sfx, makes it known
--   Gear.RatingScale(level)              brief K27: the share of its level 60 size the rating for
--                                        1% is at a level
--   Gear.SPECS[classId]                  brief K27: the class's spec keys, in the class's order
--   Gear.ScoredSpecs(classId, enabledSpecs, level)
--                                        brief K27: the specs the compare scores (every spec where
--                                        the set is nil or names none of them); brief BQ30: only
--                                        the specs open at level (Gear.SpecsFor)
--   Gear.SPEC_FROM_LEVEL[classId][spec]  brief BQ30: the level a spec opens at (none: always open)
--   Gear.SpecOpen(classId, spec, level)  brief BQ30: whether a spec counts at a level (nil: yes)
--   Gear.SpecsFor(classId, level)        brief BQ30: the class's specs open at a level, in order
--   Gear.OpenSpecSet(classId, enabledSpecs, level)
--                                        brief BQ30: the enabled set narrowed to the open specs
--   Gear.WEAPON_LAYOUTS[classId][spec]   brief GW2: the weapon layouts a spec holds (Gear.HAND: a
--                                        two hander, a one hander and a shield or a held piece,
--                                        two one handers)
--   Gear.DUAL_LAYOUT_FROM[classId]       brief GW2b: the level a dual wield layout opens at
--   Gear.BEFORE_DUAL_WIELD[classId]      brief GW2b: what a dual layout stands for before then
--   Gear.Layouts(classId, spec, level)   brief GW2b: a spec's layouts at a level (nil: any level)
--   Gear.LayoutTakes(classId, spec, it, level)
--                                        brief GW2: whether a spec's layouts take a hand piece of
--                                        that inventory type (true for anything else)
--   Gear.AnyDualLayout(classId, specs, level)
--                                        brief GW2b: whether a spec of the list holds a dual layout
--   Gear.LayoutSpecs(classId, specs, it, level)
--                                        brief GW2: the specs of a list whose layouts take it
--   Gear.SpecLabel(classId, spec)        brief K27: a spec's label through the locale, or nil
--   Gear.SpecShort(classId, spec)        brief BQ30 addendum (item 92): the short label ("Ret")
--   Gear.SpecShortList(classId, specs)   brief BQ30 addendum: "Ret, Prot", each label once, or nil
--   Gear.BodyKind(itemClass, subclass, it)
--                                        a body armour piece's kind rank (1 cloth to 4 plate), nil
--                                        for anything else (a cloak compares by level, like a ring)
--   Gear.Signature(worn)                 a string naming the worn ids, for a cache key (brief
--                                        K28: and each worn roll's key, "14173/b12761")
-- Client side, guarded:
--   Gear.Worn()                          the worn map, read once and kept until
--                                        PLAYER_EQUIPMENT_CHANGED or PLAYER_ENTERING_WORLD
--   Gear.WornState()                     the worn map and its signature, the signature held
--                                        until the map is dropped (brief K20-wire)
--   Gear.Player()                        the player's class id and level
--   Gear.RefreshTalents()                brief BQ11: the hunter's Careful Aim rank, read out of
--                                        combat (Gear.ReadCarefulAim) into Gear.carefulAimRank,
--                                        which Gear.WeightsFor weighs Intellect by
local _, ItemTree = ...

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local Gear = {}
ItemTree.Gear = Gear

-- The worn slots, as the client numbers them (GetInventoryItemID's second argument, the
-- INVSLOT_ constants). Slot 0, the ammo slot, is not gear and is never read.
Gear.SLOT = {
  HEAD = 1,
  NECK = 2,
  SHOULDER = 3,
  SHIRT = 4,
  CHEST = 5,
  WAIST = 6,
  LEGS = 7,
  FEET = 8,
  WRIST = 9,
  HANDS = 10,
  FINGER1 = 11,
  FINGER2 = 12,
  TRINKET1 = 13,
  TRINKET2 = 14,
  BACK = 15,
  MAINHAND = 16,
  OFFHAND = 17,
  RANGED = 18,
  TABARD = 19,
}
Gear.FIRST_SLOT = 1
Gear.LAST_SLOT = 19

-- The inventory types the rows carry (the it field, Classic's INVTYPE order).
Gear.TYPE = {
  WEAPON = 13,
  SHIELD = 14,
  TWO_HAND = 17,
  MAIN_HAND = 21,
  OFF_HAND_WEAPON = 22,
  HOLDABLE = 23,
}

local S = Gear.SLOT

-- Inventory type to the worn slots it goes in. A type that is not here (0 not equipped, 18 bag,
-- 24 ammo, 27 quiver, anything a later build adds) has no slot and compares as "unknown".
Gear.SLOTS_BY_TYPE = {
  [1] = { S.HEAD },
  [2] = { S.NECK },
  [3] = { S.SHOULDER },
  [4] = { S.SHIRT },
  [5] = { S.CHEST },
  [6] = { S.WAIST },
  [7] = { S.LEGS },
  [8] = { S.FEET },
  [9] = { S.WRIST },
  [10] = { S.HANDS },
  [11] = { S.FINGER1, S.FINGER2 },
  [12] = { S.TRINKET1, S.TRINKET2 },
  [13] = { S.MAINHAND, S.OFFHAND },
  [14] = { S.OFFHAND },
  [15] = { S.RANGED },
  [16] = { S.BACK },
  [17] = { S.MAINHAND, S.OFFHAND },
  [19] = { S.TABARD },
  [20] = { S.CHEST },
  [21] = { S.MAINHAND },
  [22] = { S.OFFHAND },
  [23] = { S.OFFHAND },
  [25] = { S.RANGED },
  [26] = { S.RANGED },
  [28] = { S.RANGED },
}

-- Brief K24h: the inventory types that are body armour, where the armour kind counts. A cloak (16)
-- is cloth by subclass but is held by level alone, like a ring; a shield (14) is its own kind.
Gear.BODY_TYPES =
  { [1] = true, [3] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [20] = true }
-- Brief K24h: the body armour kinds in order of weight, by armour subclass: 1 cloth, 2 leather, 3
-- mail, 4 plate. The rank is the order; the weight is about how much armour each gives at one
-- item level against cloth (Classic's curves run near 1 : 2 : 4 : 6), used only to hold two
-- pieces below uncommon quality against each other, where armour is all either has.
Gear.ARMOUR_KIND_RANK = { [1] = 1, [2] = 2, [3] = 3, [4] = 4 }
Gear.ARMOUR_KIND_WEIGHT = { [1] = 1, [2] = 2, [3] = 4, [4] = 6 }
-- The quality from which an item carries stats worth more than its armour (uncommon, green).
Gear.QUALITY_UNCOMMON = 2

-- The weapon types that sit in the off hand as a weapon (so a one hander can take that place).
local OFF_HAND_WEAPONS = { [13] = true, [22] = true }
-- The types that take the off hand and leave a worn two hander nothing to be compared with.
local OFF_HAND_ONLY = { [14] = true, [22] = true, [23] = true }

-- Item classes.
Gear.WEAPON_CLASS = 2
Gear.ARMOUR_CLASS = 4

-- Class ids (ChrClasses, UnitClass's third answer).
Gear.CLASS = {
  WARRIOR = 1,
  PALADIN = 2,
  HUNTER = 3,
  ROGUE = 4,
  PRIEST = 5,
  SHAMAN = 7,
  MAGE = 8,
  WARLOCK = 9,
  DRUID = 11,
}
local C = Gear.CLASS

-- The level mail (hunters, shamans) and plate (warriors, paladins) open at in Classic.
Gear.HEAVY_ARMOUR_LEVEL = 40

local function everyone(level)
  local out = {}
  for _, id in pairs(C) do
    out[id] = level
  end
  return out
end

-- Armour subclass to { [classId] = the level the class can first wear it at }, as Classic states
-- it. 0 misc (rings, necks, trinkets, holdables), 1 cloth, 2 leather, 3 mail, 4 plate, 5 cosmetic,
-- 6 shield, 7 libram, 8 idol, 9 totem. A subclass that is not here reads as not known. Brief K27
-- (the other session's oracle, 2026-10-08): 5 is "Cosmetic" in ItemSubClass on both the Era and
-- the Forever builds, not an obsolete buckler, and every class wears it (White Tuxedo Shirt, 6833,
-- and about a hundred more rows).
Gear.ARMOUR = {
  [0] = everyone(1),
  [1] = everyone(1),
  [2] = {
    [C.WARRIOR] = 1,
    [C.PALADIN] = 1,
    [C.HUNTER] = 1,
    [C.ROGUE] = 1,
    [C.SHAMAN] = 1,
    [C.DRUID] = 1,
  },
  [3] = {
    [C.WARRIOR] = 1,
    [C.PALADIN] = 1,
    [C.HUNTER] = Gear.HEAVY_ARMOUR_LEVEL,
    [C.SHAMAN] = Gear.HEAVY_ARMOUR_LEVEL,
  },
  [4] = { [C.WARRIOR] = Gear.HEAVY_ARMOUR_LEVEL, [C.PALADIN] = Gear.HEAVY_ARMOUR_LEVEL },
  [5] = everyone(1),
  [6] = { [C.WARRIOR] = 1, [C.PALADIN] = 1, [C.SHAMAN] = 1 },
  [7] = { [C.PALADIN] = 1 },
  [8] = { [C.DRUID] = 1 },
  [9] = { [C.SHAMAN] = 1 },
}

local function set(list)
  local out = {}
  for _, id in ipairs(list) do
    out[id] = true
  end
  return out
end

-- Weapon subclass to the classes that can train it, as Classic states it. 0 one hand axe, 1 two
-- hand axe, 2 bow, 3 gun, 4 one hand mace, 5 two hand mace, 6 polearm, 7 one hand sword, 8 two
-- hand sword, 10 staff, 13 fist, 14 miscellaneous, 15 dagger, 16 thrown, 18 crossbow, 19 wand, 20
-- fishing pole. A skill the player has not trained yet still reads usable: the class can train it.
-- 17 (spear) and any subclass not here read as not known. Brief K27: Forever's own tables where
-- they differ (the client's SkillLineAbility class masks at 1.60.1.70170): rogues train one hand
-- axes (the Axes skill's mask is 79 on Forever, 71 on Classic Era; Hatchet, 853, and Butcher's
-- Cleaver, 1292), and druids polearms (mask 1031 on both builds). Nothing here reads the Classic
-- Era client apart, so Forever's answer stands for both (ItemTree is Forever first).
local ALL_CLASSES = { C.WARRIOR, C.PALADIN, C.HUNTER, C.ROGUE, C.PRIEST, C.SHAMAN, C.MAGE, C.WARLOCK, C.DRUID }
Gear.WEAPON = {
  [0] = set({ C.WARRIOR, C.PALADIN, C.HUNTER, C.ROGUE, C.SHAMAN }),
  [1] = set({ C.WARRIOR, C.PALADIN, C.HUNTER, C.SHAMAN }),
  [2] = set({ C.WARRIOR, C.HUNTER, C.ROGUE }),
  [3] = set({ C.WARRIOR, C.HUNTER, C.ROGUE }),
  [4] = set({ C.WARRIOR, C.PALADIN, C.ROGUE, C.PRIEST, C.SHAMAN, C.DRUID }),
  [5] = set({ C.WARRIOR, C.PALADIN, C.SHAMAN, C.DRUID }),
  [6] = set({ C.WARRIOR, C.PALADIN, C.HUNTER, C.DRUID }),
  [7] = set({ C.WARRIOR, C.PALADIN, C.HUNTER, C.ROGUE, C.MAGE, C.WARLOCK }),
  [8] = set({ C.WARRIOR, C.PALADIN, C.HUNTER }),
  [10] = set({ C.WARRIOR, C.HUNTER, C.PRIEST, C.SHAMAN, C.MAGE, C.WARLOCK, C.DRUID }),
  [13] = set({ C.WARRIOR, C.HUNTER, C.ROGUE, C.SHAMAN, C.DRUID }),
  [14] = set(ALL_CLASSES),
  [15] = set({ C.WARRIOR, C.HUNTER, C.ROGUE, C.PRIEST, C.SHAMAN, C.MAGE, C.WARLOCK, C.DRUID }),
  [16] = set({ C.WARRIOR, C.HUNTER, C.ROGUE }),
  [18] = set({ C.WARRIOR, C.HUNTER, C.ROGUE }),
  [19] = set({ C.PRIEST, C.MAGE, C.WARLOCK }),
  [20] = set(ALL_CLASSES),
}

-- The level each class learns Dual Wield at in Classic. A class not here never does.
Gear.DUAL_WIELD = { [C.WARRIOR] = 20, [C.HUNTER] = 20, [C.ROGUE] = 10 }
-- Brief GW2b (the owner, 2026-10-12, and the layout research of the same day): the level a spec's dual
-- wield layout (Gear.WEAPON_LAYOUTS, H.DUAL) opens at, ONE constant per class that a later ruling
-- moves here and nowhere else (Gear.Layouts reads it). Warriors 30 (the Forever Fury 30 guide: Dual
-- Wield Specialization and Furious Precision make the pair "far stronger now"; Dual Wield itself is
-- learnt at 20), rogues 10, hunters 30 (Survival; brief GW3, the owner's ruling 6B of 2026-10-13:
-- moved from 20, the level Survival itself opens at, Gear.SPEC_FROM_LEVEL). Shamans never dual
-- wield; other classes have no dual layout.
Gear.DUAL_LAYOUT_FROM = { [C.WARRIOR] = 30, [C.HUNTER] = 30, [C.ROGUE] = 10 }

-- Brief K27: each class's specs, in the class's order (the talent trees'; the druid's feral tree
-- is two, one for each form's job). A class not here has no specs, and its compare is K24h's.
Gear.SPECS = {
  [C.WARRIOR] = { "arms", "fury", "protection" },
  [C.PALADIN] = { "holy", "protection", "retribution" },
  [C.HUNTER] = { "beast_mastery", "marksmanship", "survival" },
  [C.ROGUE] = { "assassination", "combat", "subtlety" },
  [C.PRIEST] = { "discipline", "holy", "shadow" },
  [C.SHAMAN] = { "elemental", "enhancement", "restoration" },
  [C.MAGE] = { "arcane", "fire", "frost" },
  [C.WARLOCK] = { "affliction", "demonology", "destruction" },
  [C.DRUID] = { "balance", "feral_dps", "feral_tank", "restoration" },
}

-- Brief BQ30 addendum (owner's ruling, QA item 92, 2026-10-10): each spec's short label for the
-- [Equip] tag, "Equip (Ret, Prot)", the common 2 to 4 letter form, beside the full labels and
-- through the locale the same way. The druid's two feral specs share "Feral" (Gear.SpecShortList
-- names it once).
Gear.SPEC_SHORT = {
  [C.WARRIOR] = {
    arms = L["Arms"],
    fury = L["Fury"],
    protection = L["Prot"],
  },
  [C.PALADIN] = {
    holy = L["Holy"],
    protection = L["Prot"],
    retribution = L["Ret"],
  },
  [C.HUNTER] = {
    beast_mastery = L["BM"],
    marksmanship = L["MM"],
    survival = L["Surv"],
  },
  [C.ROGUE] = {
    assassination = L["Assa"],
    combat = L["Combat"],
    subtlety = L["Sub"],
  },
  [C.PRIEST] = {
    discipline = L["Disc"],
    holy = L["Holy"],
    shadow = L["Shadow"],
  },
  [C.SHAMAN] = {
    elemental = L["Ele"],
    enhancement = L["Enh"],
    restoration = L["Resto"],
  },
  [C.MAGE] = {
    arcane = L["Arcane"],
    fire = L["Fire"],
    frost = L["Frost"],
  },
  [C.WARLOCK] = {
    affliction = L["Affl"],
    demonology = L["Demo"],
    destruction = L["Destro"],
  },
  [C.DRUID] = {
    balance = L["Bal"],
    feral_dps = L["Feral"],
    feral_tank = L["Feral"],
    restoration = L["Resto"],
  },
}

-- Brief BQ30 (owner's spot fix, QA item 91, 2026-10-10: "below level 30 let's just make Survival
-- gear triggers turn off as they are not relevant there"): the level a spec opens at. Below it the
-- spec is off whatever the setting says: no weights, no brackets, no keeps of its own. The one rule
-- every spec reader follows (Gear.SpecsFor, Gear.ScoredSpecs, Gear.OpenSpecSet), so the setting,
-- the demo specs and the demo level all read it the same way.
Gear.SPEC_FROM_LEVEL = {
  [C.HUNTER] = { survival = 30 },
}

-- Brief K27 (owner rulings 2026-10-08): each spec's label through the locale, the spec alone and
-- never the class ("Holy", "Feral DPS"), since only the player's own class's labels are ever
-- shown. Written out one literal at a time for the locale sweep. "Elemental" shares its key with
-- the creature type of the same word.
Gear.SPEC_LABELS = {
  [C.WARRIOR] = {
    arms = L["Arms"],
    fury = L["Fury"],
    protection = L["Protection"],
  },
  [C.PALADIN] = {
    holy = L["Holy"],
    protection = L["Protection"],
    retribution = L["Retribution"],
  },
  [C.HUNTER] = {
    beast_mastery = L["Beast Mastery"],
    marksmanship = L["Marksmanship"],
    survival = L["Survival"],
  },
  [C.ROGUE] = {
    assassination = L["Assassination"],
    combat = L["Combat"],
    subtlety = L["Subtlety"],
  },
  [C.PRIEST] = {
    discipline = L["Discipline"],
    holy = L["Holy"],
    shadow = L["Shadow"],
  },
  [C.SHAMAN] = {
    elemental = L["Elemental"],
    enhancement = L["Enhancement"],
    restoration = L["Restoration"],
  },
  [C.MAGE] = {
    arcane = L["Arcane"],
    fire = L["Fire"],
    frost = L["Frost"],
  },
  [C.WARLOCK] = {
    affliction = L["Affliction"],
    demonology = L["Demonology"],
    destruction = L["Destruction"],
  },
  [C.DRUID] = {
    balance = L["Balance"],
    feral_dps = L["Feral DPS"],
    feral_tank = L["Feral Tank"],
    restoration = L["Restoration"],
  },
}

-- Brief K27: the stat weights per spec, { [stat] = weight, arm = per point of armour, dps = per
-- point of a melee weapon's damage per second, rdps = a ranged weapon's (a wand's too) }. These
-- are curated version 1 weights, our own numbers from the owner's guide research (Forever's own
-- mechanics where they differ from Classic's), to be tuned in QA. A stat a spec does not list
-- weighs 0 for it. One table, so a tuning is a data change.
-- The stat codes (ITEM_MOD, the rows' stats and es alike): 3 Agility, 4 Strength, 5 Intellect, 6
-- Spirit, 7 Stamina, 12 Defence, 13 dodge rating, 14 parry rating, 15 block rating, 31 hit rating
-- and 32 crit rating (melee and spell together), 36 haste rating, 38 attack power, 39 ranged attack
-- power, 40 feral attack power, 41 extra healing, 42 spell damage, 43 mana per 5, 45 spell power
-- (damage and healing), 48 block value, 50 bonus armour, 84 holy, 85 fire, 86 nature, 87 frost, 88
-- shadow, 89 arcane spell damage.
-- The rating stats (31 hit, 32 crit, 13 dodge, 14 parry, 15 block, 36 haste) are weighted PER 1%;
-- Gear.Worth turns a row's rating into the percent it gives first (Gear.RATING_PER_PERCENT and
-- Gear.RatingScale, below). Forever never states 18 or 21 (spell hit and crit are 31 and 32).
-- Every spec weighs armour, a little (arm = 0.002) where the spec's priority does not, so armour
-- always counts. Attack power (38) is melee AND ranged (a Forever row and es write "+N Attack
-- Power" as 38), so the hunters weigh it as they weigh ranged attack power (39). The physical
-- melee specs (warriors' Arms and Fury, the three rogues) list no Spirit: a token weight would let
-- every caster piece past the spec gate for them (the gate ignores any weight under
-- Gear.GATE_MIN_WEIGHT anyway, below).
Gear.SPEC_WEIGHTS = {
  [C.WARRIOR] = {
    arms = { [4] = 1.0, [3] = 0.6, [7] = 0.35, [38] = 0.5, [31] = 9, [32] = 9, arm = 0.01, dps = 4.0 },
    fury = { [4] = 1.0, [3] = 0.6, [7] = 0.35, [38] = 0.5, [31] = 11, [32] = 10, arm = 0.01, dps = 3.0 },
    -- Forever's tanks greatly value health and hit.
    protection = {
      [7] = 1.0,
      [4] = 0.5,
      [3] = 0.6,
      [12] = 1.0,
      [13] = 12,
      [14] = 10,
      [15] = 4,
      [48] = 0.3,
      [31] = 8,
      [38] = 0.15,
      [50] = 0.06,
      arm = 0.06,
      dps = 1.0,
    },
  },
  [C.PALADIN] = {
    holy = {
      [41] = 1.0,
      [45] = 1.0,
      [5] = 0.7,
      [6] = 0.15,
      [7] = 0.2,
      [43] = 1.6,
      [32] = 7,
      [84] = 0.05,
      arm = 0.002,
    },
    -- Forever: spell power drives Consecration and the seals, level with Strength.
    protection = {
      [7] = 1.0,
      [4] = 0.6,
      [45] = 0.6,
      [42] = 0.6,
      [84] = 0.6,
      [3] = 0.3,
      [5] = 0.35,
      [12] = 0.8,
      [13] = 10,
      [14] = 8,
      [15] = 4,
      [48] = 0.25,
      [50] = 0.06,
      arm = 0.06,
      dps = 0.8,
    },
    -- Weapon damage first, then Strength and spell power together.
    retribution = {
      [4] = 1.0,
      [45] = 0.9,
      [42] = 0.9,
      [84] = 0.9,
      [3] = 0.5,
      [5] = 0.3,
      [7] = 0.3,
      [38] = 0.45,
      [6] = 0.1,
      [31] = 9,
      [32] = 9,
      arm = 0.01,
      dps = 4.0,
    },
  },
  [C.HUNTER] = {
    beast_mastery = {
      [3] = 1.0,
      [5] = 0.3,
      [7] = 0.35,
      [4] = 0.05,
      [39] = 0.45,
      [38] = 0.45,
      [31] = 9,
      [32] = 9,
      [6] = 0.1,
      [43] = 0.6,
      arm = 0.005,
      rdps = 3.0,
      dps = 0.4,
    },
    -- Forever: Careful Aim turns Intellect into attack power, by the character's rank
    -- (Gear.WeightsFor); 0.3 here is Intellect's mana alone, as for Beast Mastery.
    marksmanship = {
      [3] = 1.0,
      [5] = 0.3,
      [7] = 0.35,
      [4] = 0.05,
      [39] = 0.45,
      [38] = 0.45,
      [31] = 9,
      [32] = 9,
      [6] = 0.1,
      [43] = 0.6,
      arm = 0.005,
      rdps = 3.0,
      dps = 0.4,
    },
    -- Forever: a melee spec. Brief BQ11 (owner 2026-10-10, from the Forever Survival guide): Agility
    -- first; Strength "1 melee attack power per point" but "less valuable than Agility"; Intellect
    -- here is its mana alone, and Careful Aim adds its attack power by the character's rank
    -- (Gear.WeightsFor): at 5 of 5 Intellect is "your next most important stat after Agility".
    survival = {
      [3] = 1.0,
      [4] = 0.5,
      [7] = 0.45,
      [5] = 0.25,
      [6] = 0.1,
      [38] = 0.5,
      [39] = 0.3,
      [31] = 9,
      [32] = 9,
      [43] = 0.4,
      arm = 0.005,
      dps = 3.0,
      rdps = 1.5,
    },
  },
  [C.ROGUE] = {
    assassination = {
      [3] = 1.0,
      [4] = 0.5,
      [7] = 0.35,
      [38] = 0.5,
      [31] = 10,
      [32] = 9,
      arm = 0.005,
      dps = 3.0,
    },
    combat = {
      [3] = 1.0,
      [4] = 0.5,
      [7] = 0.35,
      [38] = 0.5,
      [31] = 10,
      [32] = 9,
      arm = 0.005,
      dps = 3.0,
    },
    subtlety = {
      [3] = 1.0,
      [4] = 0.5,
      [7] = 0.35,
      [38] = 0.5,
      [31] = 10,
      [32] = 9,
      arm = 0.005,
      dps = 3.0,
    },
  },
  -- The ranged slot holds only a wand for a priest, a mage and a warlock.
  [C.PRIEST] = {
    discipline = {
      [41] = 1.0,
      [45] = 1.0,
      [42] = 0.2,
      [5] = 0.6,
      [6] = 0.5,
      [7] = 0.25,
      [43] = 1.4,
      [32] = 5,
      arm = 0.002,
      rdps = 1.0,
    },
    holy = {
      [41] = 1.0,
      [45] = 1.0,
      [5] = 0.55,
      [6] = 0.65,
      [7] = 0.25,
      [43] = 1.4,
      [32] = 5,
      arm = 0.002,
      rdps = 1.0,
    },
    shadow = {
      [42] = 1.0,
      [45] = 1.0,
      [88] = 1.0,
      [5] = 0.4,
      [6] = 0.35,
      [7] = 0.3,
      [31] = 12,
      [32] = 2,
      [43] = 0.5,
      arm = 0.002,
      rdps = 1.0,
    },
  },
  [C.SHAMAN] = {
    elemental = {
      [42] = 1.0,
      [45] = 1.0,
      [86] = 1.0,
      [85] = 0.4,
      [87] = 0.3,
      [5] = 0.45,
      [6] = 0.15,
      [7] = 0.3,
      [31] = 10,
      [32] = 9,
      [43] = 0.8,
      arm = 0.002,
    },
    -- Forever: a talent turns Intellect into spell power (two handers only).
    enhancement = {
      [4] = 1.0,
      [3] = 0.6,
      [7] = 0.35,
      [5] = 0.35,
      [38] = 0.5,
      [31] = 9,
      [32] = 9,
      [45] = 0.3,
      [42] = 0.3,
      arm = 0.01,
      dps = 4.0,
    },
    -- Forever: Spirit is much stronger.
    restoration = { [41] = 1.0, [45] = 1.0, [5] = 0.6, [6] = 0.5, [7] = 0.25, [43] = 1.5, [32] = 6, arm = 0.002 },
  },
  [C.MAGE] = {
    arcane = {
      [42] = 1.0,
      [45] = 1.0,
      [89] = 1.0,
      [85] = 0.4,
      [87] = 0.4,
      [5] = 0.5,
      [6] = 0.3,
      [7] = 0.25,
      [31] = 11,
      [32] = 9,
      [36] = 6,
      [43] = 0.6,
      arm = 0.002,
      rdps = 1.5,
    },
    fire = {
      [42] = 1.0,
      [45] = 1.0,
      [85] = 1.0,
      [87] = 0.2,
      [89] = 0.2,
      [5] = 0.45,
      [6] = 0.2,
      [7] = 0.25,
      [31] = 11,
      [32] = 11,
      [36] = 6,
      [43] = 0.5,
      arm = 0.002,
      rdps = 1.5,
    },
    frost = {
      [42] = 1.0,
      [45] = 1.0,
      [87] = 1.0,
      [85] = 0.2,
      [89] = 0.2,
      [5] = 0.45,
      [6] = 0.2,
      [7] = 0.3,
      [31] = 11,
      [32] = 8,
      [36] = 6,
      [43] = 0.5,
      arm = 0.002,
      rdps = 1.5,
    },
  },
  [C.WARLOCK] = {
    affliction = {
      [42] = 1.0,
      [45] = 1.0,
      [88] = 1.0,
      [85] = 0.2,
      [5] = 0.35,
      [6] = 0.25,
      [7] = 0.45,
      [31] = 11,
      [32] = 3,
      [43] = 0.4,
      arm = 0.002,
      rdps = 1.5,
    },
    demonology = {
      [42] = 1.0,
      [45] = 1.0,
      [88] = 0.9,
      [85] = 0.4,
      [5] = 0.35,
      [6] = 0.25,
      [7] = 0.55,
      [31] = 10,
      [32] = 5,
      [43] = 0.4,
      arm = 0.002,
      rdps = 1.5,
    },
    destruction = {
      [42] = 1.0,
      [45] = 1.0,
      [88] = 0.9,
      [85] = 0.7,
      [5] = 0.35,
      [6] = 0.2,
      [7] = 0.4,
      [31] = 11,
      [32] = 10,
      [43] = 0.4,
      arm = 0.002,
      rdps = 1.5,
    },
  },
  [C.DRUID] = {
    balance = {
      [42] = 1.0,
      [45] = 1.0,
      [89] = 0.85,
      [86] = 0.85,
      [5] = 0.45,
      [6] = 0.2,
      [7] = 0.25,
      [31] = 11,
      [32] = 10,
      [36] = 7,
      [43] = 0.6,
      arm = 0.002,
    },
    -- Forever: the forms scale with the weapon's damage, so the weapon is the top upgrade.
    feral_dps = {
      [3] = 1.0,
      [4] = 1.0,
      [7] = 0.4,
      [38] = 0.5,
      [40] = 0.5,
      [31] = 9,
      [32] = 9,
      arm = 0.01,
      dps = 3.0,
    },
    feral_tank = {
      [7] = 1.0,
      [3] = 0.8,
      [4] = 0.6,
      [12] = 1.0,
      [13] = 10,
      [38] = 0.2,
      [40] = 0.2,
      [31] = 5,
      [50] = 0.08,
      arm = 0.08,
      dps = 1.0,
    },
    -- Forever: mana regeneration carries on at 50% in combat.
    restoration = { [41] = 1.0, [45] = 1.0, [5] = 0.6, [6] = 0.7, [7] = 0.25, [43] = 1.4, [32] = 4, arm = 0.002 },
  },
}

-- Brief K27: how far one Worth must beat another to decide, so a rounding never flips the answer:
-- the larger of least and share of the worn reference's Worth. Within it is a tie. The floor is
-- small (the pipeline branch, 2026-10-08), so a grey piece whose Worth is its armour alone can
-- still read an upgrade.
Gear.WORTH_MARGIN = { least = 0.01, share = 0.02 }

-- Brief K27 (the owner's review, 2026-10-09): the spec gate's scope. A stat counts towards the gate
-- only where some spec of some class weighs it at GATE_MIN_WEIGHT or more (Gear.GATE_STATS, worked
-- out from the table above when the file loads): a resistance (51 to 56), health per 5 (46), spell
-- penetration (47) or any code no spec weighs never gates a piece, which the Worth compare (its
-- armour, its damage) and the K24h fallbacks then judge. And a spec rescues a piece from the gate
-- only with a weight of GATE_MIN_WEIGHT or more, so a token weight never does.
Gear.GATE_MIN_WEIGHT = 0.1
local function gateStats()
  local out = {}
  for _, byClass in pairs(Gear.SPEC_WEIGHTS) do
    for _, weights in pairs(byClass) do
      for code, weight in pairs(weights) do
        if type(code) == "number" and weight >= Gear.GATE_MIN_WEIGHT then
          out[code] = true
        end
      end
    end
  end
  return out
end
Gear.GATE_STATS = gateStats()

-- Brief TK2 (QA item 105, the owner's "Do it" of 2026-10-13 on the TK1 research): a trinket row's us,
-- its Use effect in stat equivalent terms, worked out by the pipeline (ItemTree-Data
-- itemtree_data/use_score.py, docs/data-format.md "Use scores"; the constants F = 30 s per fight and
-- c = 0.5 share in combat are its curated file's). us is { {stat, value} } in es's codes and units, read
-- like es (a rating at the level 60 rate), plus one code of its own, Gear.USE_DPS: the Use's damage per
-- second of combat, weighed by the spec's damage weight (Gear.UseDpsWeight). A Use trinket the
-- pipeline could not score (no us: an Insignia, Six Demon Bag, a teleport) is never judged by its item
-- level against a worn trinket: Gear.Compare answers "unknown", basis "use" (Keep words it "Nothing to
-- compare"). An empty slot is still an upgrade for it.
Gear.USE_DPS = 1000
-- A caster's damage from spell power: one point of a Use's damage per combat second is worth this many
-- points of spell power (TK1's research figure).
Gear.USE_DPS_PER_SPELL_POWER = 3.5
Gear.TRINKET_TYPE = 12

-- Brief K27 (owner ruling 2026-10-08): an upgrade for EVERY spec of the class reads plain ("Upgrade
-- for your Chest"); true would name every spec instead. Core/Keep.lua reads it when it words the
-- line.
Gear.NAME_ALL_SPECS = false

-- Brief K27: the inventory types a ranged weapon goes in (bow, thrown, gun, crossbow and wand,
-- relic), whose damage per second weighs a spec's rdps rather than its dps.
Gear.RANGED_TYPES = { [15] = true, [25] = true, [26] = true, [28] = true }

-- Brief K27 (the pipeline branch and the coordinator, 2026-10-08): Forever's rows state hit,
-- crit, dodge, parry, block and haste as RATINGS, scaled by level the TBC way: the rating that
-- gives 1% is the base below (the level 60 rate) times Gear.RatingScale(level). Quick Strike Ring's
-- 1% crit is 32 = 14 and Don Julio's Band's 1% hit 31 = 10 (level 60 items); Moonsight Rifle,
-- required level 24, states its 1% hit as 31 = 3, which is 10 x 16 / 52. A rating in a row's stats
-- is worth what it gives at the WEARER's level, so Gear.Worth reads it at the player's level. The
-- pipeline's es carries the same codes, turned from an Era equip spell's fixed percent at the
-- level 60 rate, so es is read at the level 60 rate whatever the level (es 31 = 10 is always 1%).
-- Haste's rate is not confirmed (assumed 10, as hit).
Gear.RATING_PER_PERCENT = { [31] = 10, [32] = 14, [13] = 12, [14] = 15, [15] = 5, [36] = 10 }
-- The level a rating is read at where the player's level is not known: the level cap.
Gear.RATING_LEVEL = 60

-- Pure helpers ----------------------------------------------------------------

local function whole(value)
  local number = tonumber(value)
  if number == nil or number ~= number then
    return nil
  end
  return number
end

-- Brief BQ11 (owner 2026-10-10): Careful Aim, a hunter talent low in the Marksmanship tree that
-- any hunter may take, "Increases your Attack Power by 100% of your Intellect" at 5 of 5 ranks
-- (the owner's screenshot of the talent: trait 134473, ranks 1 to 5 at 20, 40, 60, 80 and 100%).
-- Forever 1.60.1.70245's SpellName names it spell 1223984, whose SpellEffect rows are two auras of
-- 100 on stat 3, Intellect: index 0 aura 580 (the screenshot's Effect #1, "Mod Ranged Attack Power
-- By Stat %") and index 1 aura 598 (not named in anything we hold; read as the melee half, as the
-- talent's text "Attack Power" and the guide's Survival advice imply, unconfirmed). The
-- Forever Survival guide: Intellect "provides one Attack Power through Careful Aim, while also
-- increasing your maximum mana. With Careful Aim talented this is your next most important stat
-- after Agility." A hunter's Intellect weight is the table's (its mana) plus rank x 0.2 x the
-- spec's attack power weight (38), so at rank 0 it is the mana alone and at rank 5 one attack
-- power per point on top: Beast Mastery and Marksmanship 0.3 to 0.75, Survival 0.25 to 0.75. The
-- rank is the character's own, read from the talent API out of combat (client side, below:
-- Gear.RefreshTalents), never assumed and never gated on the spec setting; nil (not read yet, or
-- not a hunter) weighs as rank 0.
Gear.CAREFUL_AIM_SPELL = 1223984
Gear.CAREFUL_AIM_MAX = 5
Gear.CAREFUL_AIM_PER_RANK = 0.2
Gear.carefulAimRank = nil

--- Brief BQ13: the Careful Aim rank every reader weighs by: the pretend rank (/itemtree demo talent
--- carefulaim, Core/Demo.lua) while it is set, else the character's own (Gear.carefulAimRank). Pure
--- over the held ranks.
function Gear.CarefulAimRank()
  local demo = ItemTree.Demo
  if type(demo) == "table" and type(demo.CarefulAim) == "function" then
    local ok, rank = pcall(demo.CarefulAim)
    if ok and rank ~= nil then
      return Gear.CleanRank(rank)
    end
  end
  return Gear.carefulAimRank
end

--- A Careful Aim rank as a whole number 0 to 5, or nil for anything else. Pure.
function Gear.CleanRank(value)
  local rank = whole(value)
  if rank == nil or rank < 0 then
    return nil
  end
  return math.min(math.floor(rank), Gear.CAREFUL_AIM_MAX)
end

--- A hunter spec's Intellect weight at a Careful Aim rank: the table's weight (Intellect's mana)
--- plus rank x 0.2 x the spec's attack power weight (38). Pure.
function Gear.CarefulAimWeight(weights, rank)
  if type(weights) ~= "table" then
    return 0
  end
  local mana = tonumber(weights[5]) or 0
  local ap = tonumber(weights[38]) or 0
  return mana + (Gear.CleanRank(rank) or 0) * Gear.CAREFUL_AIM_PER_RANK * ap
end

-- The adjusted tables, made once per spec table and rank: [weights][rank] = a copy.
local rankedWeights = setmetatable({}, { __mode = "k" })

--- The weights Gear.Worth and the spec gate read for one spec: Gear.SPEC_WEIGHTS' table, and for a
--- hunter at a Careful Aim rank above 0 a copy whose Intellect is Gear.CarefulAimWeight. rank nil
--- reads Gear.carefulAimRank. nil where the class or spec is not listed. Pure over the held rank.
function Gear.WeightsFor(classId, spec, rank)
  classId = whole(classId)
  local byClass = Gear.SPEC_WEIGHTS[classId or -1]
  local weights = byClass and byClass[spec] or nil
  if type(weights) ~= "table" or classId ~= C.HUNTER then
    return weights
  end
  if rank == nil then
    rank = Gear.CarefulAimRank()
  end
  rank = Gear.CleanRank(rank) or 0
  if rank == 0 then
    return weights
  end
  local held = rankedWeights[weights]
  if held == nil then
    held = {}
    rankedWeights[weights] = held
  end
  if held[rank] == nil then
    local copy = {}
    for key, value in pairs(weights) do
      copy[key] = value
    end
    copy[5] = Gear.CarefulAimWeight(weights, rank)
    held[rank] = copy
  end
  return held[rank]
end

--- Sets the held Careful Aim rank (Gear.CleanRank; nil for unknown) and answers whether it moved.
--- A move drops the worn signature, which joins the rank (Gear.WornState), so the Keep score
--- cache's key moves with it.
function Gear.SetCarefulAimRank(rank)
  rank = Gear.CleanRank(rank)
  if rank == Gear.carefulAimRank then
    return false
  end
  Gear.carefulAimRank = rank
  Gear.wornSignature = nil
  return true
end

--- The rank's part of the worn signature: "" while unknown, else ":ca=N". Pure over the held rank.
function Gear.TalentSignature()
  local rank = Gear.CarefulAimRank()
  if rank == nil then
    return ""
  end
  return ":ca=" .. tostring(rank)
end

-- The worn slots an inventory type goes in, the table's own list (read it, never change it), or
-- nil for a type that is not worn. Pure.
function Gear.SlotsFor(it)
  local key = whole(it)
  if not key then
    return nil
  end
  return Gear.SLOTS_BY_TYPE[key]
end

-- Whether an allowable class mask lets a class use the item. A mask of nil, 0 or below 0 (-1 is
-- every class), or one with no class bit at all, is every class. No bitwise operators: Lua 5.1.
function Gear.MaskAllows(mask, classId)
  local value = whole(mask)
  local id = whole(classId)
  if not value or value <= 0 or not id or id < 1 then
    return true
  end
  local bit = 2 ^ (id - 1)
  return math.floor(value / bit) % 2 == 1
end

-- Whether a class wields a weapon in the off hand at a level (nil level: at some level). Pure.
function Gear.CanDualWield(classId, level)
  local from = Gear.DUAL_WIELD[whole(classId) or -1]
  if not from then
    return false
  end
  local at = whole(level)
  if at == nil then
    return true
  end
  return at >= from
end

-- Whether a class can use an item at a level, from its shipped row: true, false or nil (not
-- gear, no class, a subclass the tables do not know), and the reason for a false or a nil:
--   "no_row" "not_gear" "no_class" "unknown_subclass"     (nil)
--   "class" (the row's class mask leaves the class out), "level" (the row's required level is
--   above the player's), "armour" (never this armour), "armour_level" (mail or plate before
--   40), "weapon" (a weapon type the class never trains), "dual_wield" (an off hand weapon
--   the class does not wield yet)                          (false)
-- A nil level skips the level checks. Pure.
function Gear.Usable(row, classId, level)
  if type(row) ~= "table" then
    return nil, "no_row"
  end
  local itemClass = whole(row.c)
  local it = whole(row.it)
  if (itemClass ~= Gear.WEAPON_CLASS and itemClass ~= Gear.ARMOUR_CLASS) or not Gear.SlotsFor(it) then
    return nil, "not_gear"
  end
  local id = whole(classId)
  if not id then
    return nil, "no_class"
  end
  local at = whole(level)
  local subclass = whole(row.sc)
  local rule
  if itemClass == Gear.ARMOUR_CLASS then
    rule = subclass and Gear.ARMOUR[subclass] or nil
  else
    rule = subclass and Gear.WEAPON[subclass] or nil
  end
  if rule == nil then
    return nil, "unknown_subclass"
  end
  if not Gear.MaskAllows(row.ac, id) then
    return false, "class"
  end
  local required = whole(row.rl)
  if at and required and required > at then
    return false, "level"
  end
  if itemClass == Gear.ARMOUR_CLASS then
    local from = rule[id]
    if not from then
      return false, "armour"
    end
    if at and at < from then
      return false, "armour_level"
    end
    return true
  end
  if not rule[id] then
    return false, "weapon"
  end
  if it == Gear.TYPE.OFF_HAND_WEAPON and not Gear.CanDualWield(id, at) then
    return false, "dual_wield"
  end
  return true
end

-- Brief GW1 (the owner's photos of 2026-10-11, QA items 101 and 102): armour subclass 5, Cosmetic in
-- ItemSubClass on both builds (Forever's "Use: Add this appearance to your Account collection"
-- pieces, the tuxedos, the festival masks). A cosmetic is never gear to compare: Core/Keep.lua reads
-- it as its own kind (Keep.CosmeticFacts).
Gear.COSMETIC_SUBCLASS = 5

-- Brief GW1: whether a row is a cosmetic piece (armour subclass 5). Pure.
function Gear.IsCosmetic(row)
  return type(row) == "table" and whole(row.c) == Gear.ARMOUR_CLASS and whole(row.sc) == Gear.COSMETIC_SUBCLASS
end

-- Brief GW1 (the owner's rule for the round, QA item 101: "the class list on the item, the armour
-- type the class can wear at that level, then the specs' stats"): the level a class first wears an
-- item at, the highest of its required level (1 where it states none), the level the class wears
-- its armour kind from (Gear.ARMOUR: mail and plate at 40) and, for an off hand weapon, the level
-- the class learns Dual Wield (Gear.DUAL_WIELD). nil and why where the class never wears it:
-- Gear.Usable's "class" (the row's class list leaves it out), "armour", "weapon" or "dual_wield",
-- checked in that order; nil and "no_row", "not_gear", "no_class" or "unknown_subclass" where there
-- is nothing to say. The one place the level rules meet, so the far ahead keep and the words read
-- the same answer. Pure.
function Gear.WearLevel(row, classId)
  local usable, why = Gear.Usable(row, classId, nil)
  if usable ~= true then
    return nil, why
  end
  local id = whole(classId)
  local at = math.max(1, whole(row.rl) or 1)
  if whole(row.c) == Gear.ARMOUR_CLASS then
    local from = Gear.ARMOUR[whole(row.sc)][id]
    at = math.max(at, from or 1)
  elseif whole(row.it) == Gear.TYPE.OFF_HAND_WEAPON then
    at = math.max(at, Gear.DUAL_WIELD[id] or 1)
  end
  return at
end

-- One worn slot's item level: 0 for an empty slot, the number for a worn item the rows know, nil
-- for a worn item whose level is not known (an undiscovered item, a row missing).
local function wornLevel(worn, slot)
  local entry = worn[slot]
  if entry == nil then
    return 0
  end
  if type(entry) ~= "table" then
    return nil
  end
  local il = whole(entry.il)
  if il == nil or il < 0 then
    return nil
  end
  return il
end

local function wornType(worn, slot)
  local entry = worn[slot]
  return type(entry) == "table" and whole(entry.it) or nil
end

-- The worn reference an item is held against: the item level and the slot, or nil where it is not
-- known. The cases, by the item's own type:
--   one slot        that slot (an off hand item while a two hander is worn: not known, since
--                   wearing it takes the two hander off)
--   rings, trinkets the weaker of the two slots (an empty slot is the weaker)
--   one hand        a worn two hander; else the main hand and, where the off hand is empty or holds
--                   a weapon and the player is not known NOT to dual wield, the weaker of the two
--   two hand        a worn two hander; else the mean of the main and off hand items worn (an empty
--                   hand leaves the mean, both empty is 0)
-- Brief K24h: a third answer, whether the reference slot holds nothing (an empty hand, an empty
-- finger, both hands empty for a two hander).
local function reference(it, worn, canDualWield)
  local slots = Gear.SLOTS_BY_TYPE[it]
  local mainType = wornType(worn, S.MAINHAND)
  if it == Gear.TYPE.TWO_HAND then
    if mainType == Gear.TYPE.TWO_HAND then
      return wornLevel(worn, S.MAINHAND), S.MAINHAND, false
    end
    local main, off = wornLevel(worn, S.MAINHAND), wornLevel(worn, S.OFFHAND)
    if main == nil or off == nil then
      return nil, S.MAINHAND, false
    end
    local total, count = 0, 0
    if worn[S.MAINHAND] ~= nil then
      total, count = total + main, count + 1
    end
    if worn[S.OFFHAND] ~= nil then
      total, count = total + off, count + 1
    end
    if count == 0 then
      return 0, S.MAINHAND, true
    end
    return total / count, S.MAINHAND, false
  end
  if it == Gear.TYPE.WEAPON then
    if mainType == Gear.TYPE.TWO_HAND then
      return wornLevel(worn, S.MAINHAND), S.MAINHAND, false
    end
    local offEntry = worn[S.OFFHAND]
    local offIsWeapon = offEntry == nil or OFF_HAND_WEAPONS[wornType(worn, S.OFFHAND) or -1] == true
    if canDualWield == false or not offIsWeapon then
      return wornLevel(worn, S.MAINHAND), S.MAINHAND, worn[S.MAINHAND] == nil
    end
  elseif OFF_HAND_ONLY[it] and mainType == Gear.TYPE.TWO_HAND then
    return nil, S.OFFHAND, false
  end
  if #slots == 1 then
    return wornLevel(worn, slots[1]), slots[1], worn[slots[1]] == nil
  end
  local weakest, weakestSlot = nil, slots[1]
  for _, slot in ipairs(slots) do
    local level = wornLevel(worn, slot)
    if level == nil then
      return nil, slot, false
    end
    if weakest == nil or level < weakest then
      weakest, weakestSlot = level, slot
    end
  end
  return weakest, weakestSlot, worn[weakestSlot] == nil
end

-- Brief K24h: a body armour piece's kind rank (Gear.ARMOUR_KIND_RANK: 1 cloth to 4 plate), or nil
-- for anything that is not body armour (a weapon, a cloak, a shield, a ring, a kind not known).
-- Pure.
function Gear.BodyKind(itemClass, subclass, it)
  if whole(itemClass) ~= Gear.ARMOUR_CLASS or not Gear.BODY_TYPES[whole(it) or -1] then
    return nil
  end
  return Gear.ARMOUR_KIND_RANK[whole(subclass) or -1]
end

-- Brief K27: a spec's label through the locale ("Holy"), or nil for a class or spec the
-- tables do not list. Pure.
function Gear.SpecLabel(classId, spec)
  local labels = Gear.SPEC_LABELS[whole(classId) or -1]
  return labels and labels[spec] or nil
end

-- Brief BQ30 addendum (QA item 92): a spec's short label ("Ret"), or nil for a class or spec the
-- table does not list. Pure.
function Gear.SpecShort(classId, spec)
  local labels = Gear.SPEC_SHORT[whole(classId) or -1]
  return labels and labels[spec] or nil
end

-- Brief BQ30 addendum (QA item 92): the short labels of a list of spec keys, in the list's order,
-- each named once ("Bal, Feral" for balance, feral_dps and feral_tank), joined with ", "; nil where
-- none has a short label. Pure.
function Gear.SpecShortList(classId, specs)
  local out, seen = {}, {}
  for _, spec in ipairs(type(specs) == "table" and specs or {}) do
    local label = Gear.SpecShort(classId, spec)
    if type(label) == "string" and label ~= "" and not seen[label] then
      seen[label] = true
      out[#out + 1] = label
    end
  end
  if #out == 0 then
    return nil
  end
  return table.concat(out, ", ")
end

-- Brief BQ30 (the owner, 2026-10-11: "a Survival hunter still wants a bow, so it is Any"): the
-- worn slots whose upgrade counts for every spec of the class once any spec's stats call it one: a
-- hunter's ranged weapon, which every hunter spec shoots (Survival's weights, melee first, could
-- otherwise leave it out of a better bow).
Gear.SHARED_SLOTS = {
  [C.HUNTER] = { [S.RANGED] = true },
}

-- Brief GW2 (the owner's ruling on QA item 139, 2026-10-11: "an off hand book is an upgrade for Holy
-- only, never Ret (two hander) or Prot (shield)"; the K27 guide research for the rest): the weapon
-- layouts each spec holds, the one place the rule lives. Gear.HAND.TWO a two hander and an empty off
-- hand; SHIELD a one hander and a shield; HELD a one hander and a held off hand piece; DUAL a one
-- hander in each hand (a one hander in the main hand alone before the class learns Dual Wield,
-- Gear.DUAL_WIELD; Forever shamans never dual wield). A class or spec not here takes every hand
-- piece, as before GW2. Brief GW2b (the owner, 2026-10-11 night: "Holy can take off hand or shield,
-- both are viable, it just comes down to what's better"): Holy holds a held piece or a shield, and
-- the stat compare decides between them.
Gear.HAND = { TWO = "two_hand", SHIELD = "shield", HELD = "held", DUAL = "dual" }
local H = Gear.HAND
local CASTER_HANDS = { H.TWO, H.HELD }
Gear.WEAPON_LAYOUTS = {
  [C.WARRIOR] = { arms = { H.TWO }, fury = { H.TWO, H.DUAL }, protection = { H.SHIELD } },
  [C.PALADIN] = { holy = { H.HELD, H.SHIELD }, protection = { H.SHIELD }, retribution = { H.TWO } },
  [C.HUNTER] = { beast_mastery = { H.TWO }, marksmanship = { H.TWO }, survival = { H.TWO, H.DUAL } },
  [C.ROGUE] = { assassination = { H.DUAL }, combat = { H.DUAL }, subtlety = { H.DUAL } },
  [C.PRIEST] = { discipline = CASTER_HANDS, holy = CASTER_HANDS, shadow = CASTER_HANDS },
  [C.SHAMAN] = {
    elemental = { H.SHIELD, H.HELD, H.TWO },
    enhancement = { H.TWO, H.SHIELD },
    restoration = { H.SHIELD, H.HELD, H.TWO },
  },
  [C.MAGE] = { arcane = CASTER_HANDS, fire = CASTER_HANDS, frost = CASTER_HANDS },
  [C.WARLOCK] = { affliction = CASTER_HANDS, demonology = CASTER_HANDS, destruction = CASTER_HANDS },
  [C.DRUID] = {
    balance = CASTER_HANDS,
    feral_dps = { H.TWO },
    feral_tank = { H.TWO },
    restoration = CASTER_HANDS,
  },
}

-- Brief GW2: the hand inventory types, each with the layouts that take it in the hand it goes in.
-- An off hand weapon (22) only a dual wielder's off hand, once the class dual wields at the level.
-- Brief GW2b (the owner, 2026-10-12: "if they are using a one hander or they're using a really old two
-- hander and this single hand is an upgrade dps wise, we should still tell them to use it"): a main
-- hand weapon (a one hander 13, a main hand piece 21, a two hander 17) is no longer judged by the
-- layout's weapon type. The layout names the PREFERRED type; a weapon of the other type is taken by
-- every spec with a layout and the stat compare against the worn set decides, except that a two
-- hander never replaces the shield of a spec whose every layout holds one (SHIELD_BOUND below).
local LAYOUT_TAKES = {
  [Gear.TYPE.SHIELD] = { [H.SHIELD] = true },
  [Gear.TYPE.HOLDABLE] = { [H.HELD] = true },
  [Gear.TYPE.OFF_HAND_WEAPON] = { [H.DUAL] = true },
}
local MAIN_HAND_WEAPONS = {
  [Gear.TYPE.WEAPON] = true,
  [Gear.TYPE.MAIN_HAND] = true,
  [Gear.TYPE.TWO_HAND] = true,
}

-- Brief GW2b: whether every one of a spec's layouts holds a shield (warrior and paladin Protection:
-- their key skills need one), so a two hander never replaces it. Pure.
local function shieldBound(layouts)
  for _, layout in ipairs(layouts) do
    if layout ~= H.SHIELD then
      return false
    end
  end
  return #layouts > 0
end

-- Brief GW2b (the owner, 2026-10-12: "You don't get the dual wield skill until later in the game, so
-- most two handed weapons before then will be good"): the layouts a dual wield layout stands for
-- before the class's dual layout opens (Gear.DUAL_LAYOUT_FROM), per class. Warriors (Fury) hold a two
-- hander until 30 (the two hander stays taken for Fury at every level, the compare decides). A
-- class not here keeps the dual layout, read as a one hander in the main hand alone: rogues (no two
-- hander to hold). Brief GW3 (the owner's ruling 6B, 2026-10-13): Survival hunters hold a two
-- hander until 30 as BM and MM do, so no hunter spec takes an off hand weapon before then. Since the
-- third ruling (above, MAIN_HAND_WEAPONS) the layout is the preferred type only: a one hander still
-- reads as an upgrade for Fury before 20 where it beats the worn weapon set; what this list closes
-- is the off hand weapon (an off hand weapon also needs the Dual Wield skill itself,
-- Gear.CanDualWield).
Gear.BEFORE_DUAL_WIELD = {
  [C.WARRIOR] = { H.TWO },
  [C.HUNTER] = { H.TWO },
}

--- Brief GW2b: a spec's weapon layouts at a level, opening by level like specs: below the class's
--- Gear.DUAL_LAYOUT_FROM a dual layout is replaced by the class's Gear.BEFORE_DUAL_WIELD list (each
--- layout once, the table's order). nil level: at some level, so the dual layout stays. nil for a
--- class or spec with no layouts. The table's own list is returned where nothing changes (read it,
--- never change it). Pure.
function Gear.Layouts(classId, spec, level)
  local class = whole(classId)
  local byClass = Gear.WEAPON_LAYOUTS[class or -1]
  local layouts = byClass and byClass[spec] or nil
  local before = Gear.BEFORE_DUAL_WIELD[class or -1]
  local at, from = whole(level), Gear.DUAL_LAYOUT_FROM[class or -1]
  if layouts == nil or before == nil or at == nil or (from ~= nil and at >= from) then
    return layouts
  end
  local out, seen, changed = {}, {}, false
  local function push(layout)
    if not seen[layout] then
      seen[layout] = true
      out[#out + 1] = layout
    end
  end
  for _, layout in ipairs(layouts) do
    if layout == H.DUAL then
      changed = true
      for _, stand in ipairs(before) do
        push(stand)
      end
    else
      push(layout)
    end
  end
  if not changed then
    return layouts
  end
  return out
end

--- Brief GW2: whether a spec's weapon layouts (Gear.WEAPON_LAYOUTS) take a candidate of an inventory
--- type at a level (nil: at some level). true for anything not held in the hands, and for a class or
--- spec with no layout. Pure.
function Gear.LayoutTakes(classId, spec, it, level)
  local layouts = Gear.Layouts(classId, spec, level)
  if layouts == nil then
    return true
  end
  if MAIN_HAND_WEAPONS[whole(it) or -1] then
    return whole(it) ~= Gear.TYPE.TWO_HAND or not shieldBound(layouts)
  end
  local takes = LAYOUT_TAKES[whole(it) or -1]
  if takes == nil then
    return true
  end
  for _, layout in ipairs(layouts) do
    if takes[layout] then
      if whole(it) ~= Gear.TYPE.OFF_HAND_WEAPON or Gear.CanDualWield(classId, level) then
        return true
      end
    end
  end
  return false
end

--- Brief GW2b: whether any spec of a list holds a dual wield layout at a level (Gear.Layouts); true
--- for a spec with no layouts (as before GW2). Pure.
function Gear.AnyDualLayout(classId, specs, level)
  for _, spec in ipairs(type(specs) == "table" and specs or {}) do
    local layouts = Gear.Layouts(classId, spec, level)
    if layouts == nil then
      return true
    end
    for _, layout in ipairs(layouts) do
      if layout == H.DUAL then
        return true
      end
    end
  end
  return false
end

--- Brief GW2: the specs of a list whose weapon layouts take a candidate of an inventory type at a
--- level, in the list's order: the list itself where every one does (read it, never change it), a
--- new list otherwise. Pure.
function Gear.LayoutSpecs(classId, specs, it, level)
  if type(specs) ~= "table" then
    return specs
  end
  local out = {}
  for _, spec in ipairs(specs) do
    if Gear.LayoutTakes(classId, spec, it, level) then
      out[#out + 1] = spec
    end
  end
  if #out == #specs then
    return specs
  end
  return out
end

-- Brief BQ30: whether a worn slot's upgrade is every spec's for the class (Gear.SHARED_SLOTS). Pure.
function Gear.SlotShared(classId, slot)
  local byClass = Gear.SHARED_SLOTS[whole(classId) or -1]
  return byClass ~= nil and byClass[whole(slot) or -1] == true
end

-- Brief BQ30: the level a spec opens at (Gear.SPEC_FROM_LEVEL), or nil for a spec always open. Pure.
function Gear.SpecFromLevel(classId, spec)
  local byClass = Gear.SPEC_FROM_LEVEL[whole(classId) or -1]
  return byClass and byClass[spec] or nil
end

-- Brief BQ30: whether a spec counts for a player of this level: true for a spec with no opening
-- level, and where the level is not known (nil reads as the cap, as a rating does). Pure.
function Gear.SpecOpen(classId, spec, level)
  local from = Gear.SpecFromLevel(classId, spec)
  local at = whole(level)
  return from == nil or at == nil or at >= from
end

-- Brief BQ30: the class's specs open at a level, in the class's order: the class's own list where
-- every one is open (read it, never change it), a new list otherwise; nil for a class Gear.SPECS
-- does not list. Pure.
function Gear.SpecsFor(classId, level)
  local specs = Gear.SPECS[whole(classId) or -1]
  if specs == nil then
    return nil
  end
  local out = {}
  for _, spec in ipairs(specs) do
    if Gear.SpecOpen(classId, spec, level) then
      out[#out + 1] = spec
    end
  end
  if #out == #specs then
    return specs
  end
  return out
end

-- Brief BQ30: the enabled set (Gear.Compare's enabledSpecs, nil for every spec) narrowed to the
-- specs open at a level: the set as it came where it names no spec closed at that level (an empty
-- set, "no spec additions", stays empty), else a new set of the open specs it names, or of every
-- open spec where it names only closed ones (a Survival only setting under 30 reads as every box
-- ticked, as every box unticked does); nil (every spec) is every open spec. Pure.
function Gear.OpenSpecSet(classId, enabledSpecs, level)
  local specs = Gear.SPECS[whole(classId) or -1]
  local open = Gear.SpecsFor(classId, level)
  if specs == nil or open == specs then
    return enabledSpecs
  end
  local out, any = {}, false
  if type(enabledSpecs) == "table" then
    local closed = false
    for _, spec in ipairs(specs) do
      if enabledSpecs[spec] and not Gear.SpecOpen(classId, spec, level) then
        closed = true
      end
    end
    if not closed then
      return enabledSpecs
    end
    for _, spec in ipairs(open) do
      if enabledSpecs[spec] then
        out[spec], any = true, true
      end
    end
  end
  if not any then
    for _, spec in ipairs(open) do
      out[spec] = true
    end
  end
  return out
end

-- Brief K27 (owner 2026-10-08, the per character spec setting): the class's specs the compare
-- scores, in the class's order: those enabledSpecs names ({ holy = true }), or every spec where
-- enabledSpecs is nil, not a set, or names none of the class's specs (every box unticked reads as
-- every box ticked, so the gear line never goes quiet). The class's own list where nothing is left
-- out (read it, never change it), a new list otherwise; nil for a class Gear.SPECS does not list.
-- Brief BQ30: level, the player's: only the specs open at it (Gear.SpecsFor) count, so "every
-- spec" there is every open spec. nil level: every spec, as before. Pure.
function Gear.ScoredSpecs(classId, enabledSpecs, level)
  local specs = Gear.SpecsFor(classId, level)
  if specs == nil or type(enabledSpecs) ~= "table" then
    return specs
  end
  local out = {}
  for _, spec in ipairs(specs) do
    if enabledSpecs[spec] then
      out[#out + 1] = spec
    end
  end
  if #out == 0 or #out == #specs then
    return specs
  end
  return out
end

-- Brief K27: a weapon row's damage per second, (min + max) / 2 over the delay in seconds, or nil
-- where the row states no damage or no delay. Pure.
function Gear.WeaponDps(row)
  local dmg = type(row) == "table" and row.dmg or nil
  if type(dmg) ~= "table" then
    return nil
  end
  local low, high, delay = whole(dmg[1]), whole(dmg[2]), whole(row.dl)
  if not low or not high or not delay or delay <= 0 then
    return nil
  end
  return (low + high) / 2 / (delay / 1000)
end

-- Whether a {{stat, value}} list holds at least one pair.
local function hasPairs(list)
  return type(list) == "table" and type(list[1]) == "table"
end

-- Brief K28: whether a roll ({ stats = priced shares, es = flat values }) holds a stat at all.
local function hasRoll(roll)
  return type(roll) == "table" and (hasPairs(roll.stats) or hasPairs(roll.es))
end

-- Brief TK2: the weight one point of a Use's damage per combat second (Gear.USE_DPS) has for a spec:
-- the larger of its melee weapon damage weight (dps), its ranged one (rdps) and
-- Gear.USE_DPS_PER_SPELL_POWER times its spell power weight (45, else 42). 0 where it weighs none.
-- Pure.
function Gear.UseDpsWeight(weights)
  if type(weights) ~= "table" then
    return 0
  end
  local spellPower = math.max(tonumber(weights[45]) or 0, tonumber(weights[42]) or 0)
  return math.max(tonumber(weights.dps) or 0, tonumber(weights.rdps) or 0, Gear.USE_DPS_PER_SPELL_POWER * spellPower)
end

-- Brief TK2: the Use's damage per combat second a us list states (Gear.USE_DPS), 0 for none. Pure.
local function useDps(list)
  local sum = 0
  if type(list) ~= "table" then
    return sum
  end
  for _, pair in ipairs(list) do
    if type(pair) == "table" and whole(pair[1]) == Gear.USE_DPS then
      sum = sum + (whole(pair[2]) or 0)
    end
  end
  return sum
end

-- Brief TK2: whether a row has an on use spell (an fx entry of trigger 0, { trigger, spellId, ... }).
-- Pure.
local function hasUseSpell(row)
  if type(row.fx) ~= "table" then
    return false
  end
  for _, effect in ipairs(row.fx) do
    if type(effect) == "table" and whole(effect[1]) == 0 and (whole(effect[2]) or 0) > 0 then
      return true
    end
  end
  return false
end

--- Brief TK2: whether a row is a trinket whose Use the pipeline could not score: an on use spell and
--- no us (an Insignia, Six Demon Bag, a teleport). Such a trinket is never judged by its item level
--- against a worn one (Gear.Compare's basis "use"). Pure.
function Gear.UseUnscored(row)
  return type(row) == "table" and whole(row.it) == Gear.TRINKET_TYPE and hasUseSpell(row) and not hasPairs(row.us)
end

-- Brief K28: the roll a row is weighed with: the suffix handed in, else the row's own sfx (only a
-- worn map entry carries one, Gear.ReadWorn; a shipped row never does). nil for none.
local function rollOf(row, suffix)
  if suffix ~= nil then
    return suffix
  end
  return row.sfx
end

-- Brief K27: whether a row carries stats of its own or through its equip effects (es). Brief K28:
-- or through its roll (suffix, else the entry's sfx), which is how a random suffix item whose row
-- states no stats at all (Buccaneer's Cord, 14173) carries any.
-- Brief TK2: or through its scored Use (us).
local function carriesStats(row, suffix)
  return hasPairs(row.stats) or hasPairs(row.es) or hasPairs(row.us) or hasRoll(rollOf(row, suffix))
end

-- Brief K27 (the owner's review, 2026-10-09): whether a row is a green or better that states no
-- stats and no es: a random suffix item ("of the Bear") whose rolled stats the row does not carry
-- (2,172 shipped gear rows). Weighed as its armour alone it read caster cloth an upgrade over a
-- warrior's worn "of the Bear" belt, and lost its own roll as the candidate, so the stats compare
-- leaves it to K24h, as the item and as the worn reference. Brief K28 is the seam: suffix, the roll
-- the item's link resolved (Gear.SuffixStats' { stats, es }, a table of its own, never the shipped
-- row changed), and a worn entry's own roll (sfx, Gear.ReadWorn) both count through carriesStats,
-- so a green whose roll is known reads as known here and goes through the stats path; one whose
-- link names no roll the module prices (or no link, or no module) still falls back to K24h. Pure.
function Gear.StatsUnknown(row, suffix)
  return type(row) == "table" and (whole(row.q) or 0) >= Gear.QUALITY_UNCOMMON and not carriesStats(row, suffix)
end

-- Brief K27: whether Gear.Worth has anything to read on a row (or a worn map entry, which carries
-- the same fields): weapon or armour, with stats, es, an armour value, or a weapon's damage; and
-- not a green or better whose stats the row does not carry (Gear.StatsUnknown). Brief K28: a roll
-- counts as stats in both tests (a ring "of the Bear" whose row states nothing at all is readable
-- once its link's roll is known); a worn entry's roll rides on it as sfx and counts the same way.
local function readable(row, suffix)
  if type(row) ~= "table" then
    return false
  end
  local itemClass = whole(row.c)
  if itemClass ~= Gear.WEAPON_CLASS and itemClass ~= Gear.ARMOUR_CLASS then
    return false
  end
  if Gear.StatsUnknown(row, suffix) then
    return false
  end
  if carriesStats(row, suffix) then
    return true
  end
  local arm = whole(row.arm)
  if arm and arm > 0 then
    return true
  end
  return itemClass == Gear.WEAPON_CLASS and Gear.WeaponDps(row) ~= nil
end

-- Brief K27: how much of its level 60 size the rating for 1% is at a level, TBC's combat rating
-- curve, which the shipped rows match (Moonsight Rifle, Gear.RATING_PER_PERCENT's comment):
-- (level - 8) / 52 from level 10 to 60, 2 / 52 below 10, and 1 at 60 and above or a level not known
-- (Gear.RATING_LEVEL). Pure.
function Gear.RatingScale(level)
  local at = whole(level) or Gear.RATING_LEVEL
  if at >= 60 then
    return 1
  end
  if at < 10 then
    return 2 / 52
  end
  return (at - 8) / 52
end

-- The weighted sum of one {{stat, value}} list: a rating (Gear.RATING_PER_PERCENT) is first turned
-- into the percent it gives, the base rate times scale (Gear.RatingScale) to 1%, since its weight
-- is per 1%; anything else is weighed per point.
local function weighPairs(list, weights, scale)
  local sum = 0
  if type(list) ~= "table" then
    return sum
  end
  for _, pair in ipairs(list) do
    if type(pair) == "table" then
      local code = whole(pair[1]) or -1
      local weight = weights[code]
      local value = whole(pair[2])
      if weight and value then
        local rating = Gear.RATING_PER_PERCENT[code]
        if rating then
          value = value / (rating * scale)
        end
        sum = sum + weight * value
      end
    end
  end
  return sum
end

-- Brief K27: a row's worth to one spec, in its parts: its stats and es (the stat part), its armour
-- value by arm, and for a weapon with damage and a delay its damage per second by dps (a melee
-- weapon) or rdps (one for the ranged slot, Gear.RANGED_TYPES). A row's stats ratings are read at
-- level (the player's), es's at the level 60 rate. nil where the row is not a weapon or armour, or
-- the class or spec is not listed. Brief K28: the roll (suffix, else the row's sfx) joins the stat
-- part, each half at its own rate and never mixed (the owner's Fable review, 2026-10-09): its
-- priced shares (roll.stats) are the item's own budget and read like the row's stats, a rating at
-- the player's level; its flat values (roll.es) are a fixed effect and read like es, at the level
-- 60 rate ("of Eluding"'s flat dodge is 13 = 12, 1% at 60).
local function worthParts(row, classId, spec, level, suffix)
  if type(row) ~= "table" then
    return nil
  end
  local itemClass = whole(row.c)
  if itemClass ~= Gear.WEAPON_CLASS and itemClass ~= Gear.ARMOUR_CLASS then
    return nil
  end
  local weights = Gear.WeightsFor(classId, spec)
  if type(weights) ~= "table" then
    return nil
  end
  local stats = weighPairs(row.stats, weights, Gear.RatingScale(level)) + weighPairs(row.es, weights, 1)
  -- Brief TK2: a trinket's scored Use, read like es, and its damage per combat second by the spec's
  -- damage weight.
  if type(row.us) == "table" then
    stats = stats + weighPairs(row.us, weights, 1) + useDps(row.us) * Gear.UseDpsWeight(weights)
  end
  local roll = rollOf(row, suffix)
  if type(roll) == "table" then
    stats = stats + weighPairs(roll.stats, weights, Gear.RatingScale(level)) + weighPairs(roll.es, weights, 1)
  end
  local armour = 0
  local arm = whole(row.arm)
  if arm and arm > 0 and weights.arm then
    armour = arm * weights.arm
  end
  local weapon = 0
  if itemClass == Gear.WEAPON_CLASS then
    local dps = Gear.WeaponDps(row)
    local weight = Gear.RANGED_TYPES[whole(row.it) or -1] and weights.rdps or weights.dps
    if dps and weight then
      weapon = dps * weight
    end
  end
  return stats, armour, weapon
end

-- Brief K27: a row's worth to one spec of a class (Gear.SPEC_WEIGHTS): its stats and its equip
-- effects' stats (es, the same codes) by the spec's weights, a rating as the percent it gives
-- (stats at the player's level, es at the level 60 rate), plus its armour value by arm, plus for
-- a weapon with damage and a delay its damage per second by dps (a melee weapon) or rdps (one for
-- the ranged slot). A worn map entry carries the same fields and is weighed the same way. level is
-- the player's; nil reads ratings at the cap. nil where the row is not a weapon or armour, or the
-- class or spec is not listed. Pure; a short loop, and Core/Keep.lua's score cache holds the
-- compare per item, level, class, enabled specs and worn set. Brief K28: suffix, the item's roll
-- (Gear.SuffixStats' { stats, es }: the priced shares weighed like the row's stats, the flat values
-- like es); nil reads the row's own sfx (a worn entry's), and a shipped row carries none, so nil
-- is the K27 answer exactly.
function Gear.Worth(row, classId, spec, level, suffix)
  local stats, armour, weapon = worthParts(row, classId, spec, level, suffix)
  if stats == nil then
    return nil
  end
  return stats + armour + weapon
end

-- Whether any pair of a {{stat, value}} list is a stat the gate reads (Gear.GATE_STATS), or, given
-- a spec's weights, one that spec weighs at Gear.GATE_MIN_WEIGHT or more.
local function pairsGate(list, weights)
  if type(list) ~= "table" then
    return false
  end
  for _, pair in ipairs(list) do
    local code = type(pair) == "table" and whole(pair[1]) or nil
    local value = type(pair) == "table" and whole(pair[2]) or nil
    if code and value and value ~= 0 then
      if weights == nil then
        if Gear.GATE_STATS[code] then
          return true
        end
      else
        local weight = weights[code]
        if weight and weight >= Gear.GATE_MIN_WEIGHT then
          return true
        end
      end
    end
  end
  return false
end

-- Brief K27: whether the spec gate reads the row at all: it carries a stat some class weighs.
-- Brief K28: a roll's stats count, both halves (suffix, else a worn entry's sfx).
local function carriesGateStats(row, suffix)
  if pairsGate(row.stats, nil) or pairsGate(row.es, nil) then
    return true
  end
  local roll = rollOf(row, suffix)
  return type(roll) == "table" and (pairsGate(roll.stats, nil) or pairsGate(roll.es, nil))
end

-- Brief K27: the spec gate's test, whether the row is worth anything to any spec scored APART FROM
-- its armour, each weight at Gear.GATE_MIN_WEIGHT or more: a stat of its stats or es the spec
-- weighs, or a weapon's damage the spec weighs (dps for a melee weapon, rdps for the ranged slot).
-- Armour never saves a piece from the gate (a paladin's belt of Shadow spell damage), but weapon
-- damage saves a weapon (a two hander of Intellect a Retribution Paladin still swings). Brief K28:
-- the roll's stats count as stats, both halves (a Cord of Shadow Wrath's shadow damage). Brief TK2: a
-- scored Use (us) a spec weighs saves it too (Thunderbrew's Boot Flask's stray Spirit on a warrior:
-- its fire weighs as damage), so "Not for your specs" is skipped where us holds something wanted.
local function weighsAny(row, classId, specs, suffix)
  local dps = whole(row.c) == Gear.WEAPON_CLASS and Gear.WeaponDps(row) or nil
  local ranged = Gear.RANGED_TYPES[whole(row.it) or -1] == true
  local roll = rollOf(row, suffix)
  if type(roll) ~= "table" then
    roll = nil
  end
  for _, spec in ipairs(specs) do
    local weights = Gear.WeightsFor(classId, spec) or {}
    if pairsGate(row.stats, weights) or pairsGate(row.es, weights) then
      return true
    end
    if roll and (pairsGate(roll.stats, weights) or pairsGate(roll.es, weights)) then
      return true
    end
    if pairsGate(row.us, weights) or (useDps(row.us) > 0 and Gear.UseDpsWeight(weights) >= Gear.GATE_MIN_WEIGHT) then
      return true
    end
    local weight = ranged and weights.rdps or weights.dps
    if dps and weight and weight >= Gear.GATE_MIN_WEIGHT then
      return true
    end
  end
  return false
end

local MAIN_ONLY = { S.MAINHAND }
local BOTH_HANDS = { S.MAINHAND, S.OFFHAND }

-- Brief K27: the worn pieces the stats compare holds an item against, the same cases as reference
-- (its empty and unknown answers are dealt with before this is asked): the slots, and how their
-- Worths join, "one" (a single slot), "weaker" (the lower Worth of the two, per spec) or "sum" (a
-- two hander against the main and off hand pieces worn, added).
local function statsReference(it, worn, canDualWield)
  local mainType = wornType(worn, S.MAINHAND)
  if it == Gear.TYPE.TWO_HAND then
    if mainType == Gear.TYPE.TWO_HAND then
      return MAIN_ONLY, "one"
    end
    return BOTH_HANDS, "sum"
  end
  if it == Gear.TYPE.WEAPON then
    if mainType == Gear.TYPE.TWO_HAND then
      return MAIN_ONLY, "one"
    end
    local offIsWeapon = worn[S.OFFHAND] == nil or OFF_HAND_WEAPONS[wornType(worn, S.OFFHAND) or -1] == true
    if canDualWield == false or not offIsWeapon then
      return MAIN_ONLY, "one"
    end
    return BOTH_HANDS, "weaker"
  end
  local slots = Gear.SLOTS_BY_TYPE[it]
  if #slots == 1 then
    return slots, "one"
  end
  return slots, "weaker"
end

-- Brief K27: one spec's worn reference Worth and the slot it stands for (the weaker piece's slot,
-- the main hand for a sum).
local function wornWorth(worn, slots, join, classId, spec, playerLevel)
  if join == "sum" then
    local total = 0
    for _, slot in ipairs(slots) do
      if worn[slot] ~= nil then
        total = total + (Gear.Worth(worn[slot], classId, spec, playerLevel) or 0)
      end
    end
    return total, S.MAINHAND
  end
  local least, leastSlot = nil, slots[1]
  for _, slot in ipairs(slots) do
    local worth = Gear.Worth(worn[slot], classId, spec, playerLevel) or 0
    if least == nil or worth < least then
      least, leastSlot = worth, slot
    end
  end
  return least or 0, leastSlot
end

-- Brief K24h: the answer by level and kind, once the reference is known and not empty. Gear.Compare
-- answers it as it is with no class, and the stats compare falls back to it and breaks ties by it.
local function byLevelAndKind(row, worn, il, it, level, slot)
  local diff = il - level
  local entry = worn[slot]
  local itemKind = Gear.BodyKind(row.c, row.sc, it)
  local wornKind = type(entry) == "table" and Gear.BodyKind(Gear.ARMOUR_CLASS, entry.sc, entry.it) or nil
  if itemKind and wornKind and itemKind ~= wornKind then
    if itemKind < wornKind then
      return "not_upgrade", diff, slot, "lighter"
    end
    if diff >= 0 then
      return "upgrade", diff, slot, "kind"
    end
    local plain = (whole(row.q) or 0) < Gear.QUALITY_UNCOMMON and (whole(entry.q) or 0) < Gear.QUALITY_UNCOMMON
    if plain and Gear.ARMOUR_KIND_WEIGHT[itemKind] * il > Gear.ARMOUR_KIND_WEIGHT[wornKind] * level then
      return "upgrade", diff, slot, "kind"
    end
    return "not_upgrade", diff, slot, "level"
  end
  if diff > 0 then
    return "upgrade", diff, slot, "level"
  end
  return "not_upgrade", diff, slot, "level"
end

-- Adds a slot to a list once.
local function addOnce(list, slot)
  for _, held in ipairs(list) do
    if held == slot then
      return
    end
  end
  list[#list + 1] = slot
end

-- Brief K27: the stats compare per spec, once the reference is known, not empty, and the item is
-- readable. The answer as Gear.Compare gives it, or nil where it falls back to K24h's (a worn
-- reference piece Worth cannot read, or the item and the worn reference both worth 0 to every
-- spec scored). slot and level are reference's; playerLevel is the player's, which a rating in a
-- row's stats is read at. Brief K28: suffix is the item's roll; a worn piece's rides on its entry.
local function byStats(row, worn, canDualWield, classId, specs, il, it, level, slot, playerLevel, suffix)
  local slots, join = statsReference(it, worn, canDualWield)
  for _, refSlot in ipairs(slots) do
    if worn[refSlot] ~= nil and not readable(worn[refSlot]) then
      return nil
    end
  end
  -- The tie breaker: K24h's answer (a heavier body armour kind at the worn level or above, a higher
  -- item level of the same kind; a lighter kind never), so where the stats cannot tell two pieces
  -- apart the item level and kind still do (a priest's white cloth chest five item levels up, whose
  -- few more points of armour sit inside the margin).
  local k24h = byLevelAndKind(row, worn, il, it, level, slot) == "upgrade"
  local margin = Gear.WORTH_MARGIN
  local list, held, weighed, firstSlot = {}, {}, false, nil
  for _, spec in ipairs(specs) do
    local itemWorth = Gear.Worth(row, classId, spec, playerLevel, suffix) or 0
    local worth, against = wornWorth(worn, slots, join, classId, spec, playerLevel)
    -- A spec that weighs neither piece has no say, and is never named for a tie.
    local up = false
    if itemWorth ~= 0 or worth ~= 0 then
      weighed = true
      up = k24h
    end
    local by = math.max(margin.least, margin.share * worth)
    if itemWorth > worth + by then
      up = true
    elseif itemWorth < worth - by then
      up = false
    end
    if up then
      list[#list + 1] = spec
      firstSlot = firstSlot or against
      if join == "sum" then
        for _, hand in ipairs(slots) do
          if worn[hand] ~= nil then
            addOnce(held, hand)
          end
        end
      else
        addOnce(held, against)
      end
    end
  end
  if not weighed then
    return nil
  end
  -- The slot the first upgraded spec was held against (a ring's weaker finger may differ by spec
  -- from the lower level one), and the item level difference against it.
  local outSlot = firstSlot or slot
  local diff = il - level
  if outSlot ~= slot and join ~= "sum" then
    local at = wornLevel(worn, outSlot)
    if at ~= nil then
      diff = il - at
    end
  end
  if #list == 0 then
    return "not_upgrade", diff, outSlot, "stats", list
  end
  return "upgrade", diff, outSlot, "stats", list, held
end

-- Brief GW1 (the owner's rule for the round: the class list, the armour or weapon kind, then "the
-- specs' stats"): whether any scored spec wants the item at all: false only where the spec gate
-- answers (Gear.Compare's): it carries a stat some class weighs and no scored spec weighs anything
-- on it apart from its armour, so "Not for your specs" is its reason. true for anything the gate
-- does not judge (no class with specs, stats not readable, no gate stat). Pure.
function Gear.SpecsWant(row, classId, enabledSpecs, playerLevel, suffix)
  local class = whole(classId)
  local specs = Gear.ScoredSpecs(class, enabledSpecs, playerLevel)
  if specs == nil or type(row) ~= "table" then
    return true
  end
  -- Brief GW2: only the specs whose weapon layouts take it; none is "Not for your specs" too.
  specs = Gear.LayoutSpecs(class, specs, row.it, playerLevel)
  if #specs == 0 then
    return false
  end
  if not hasRoll(suffix) then
    suffix = nil
  end
  if not readable(row, suffix) or not carriesGateStats(row, suffix) then
    return true
  end
  return weighsAny(row, class, specs, suffix)
end

-- Whether an item is an upgrade on what is worn: "upgrade", "not_upgrade" or "unknown" (no item
-- level, a type that is not worn, no worn map, a worn item whose level is not known), the item
-- level difference (row.il minus the reference, nil for "unknown" where nothing was compared),
-- the slot compared against, and the basis of the answer (brief K24h):
--   "empty"    nothing is worn there: an upgrade
--   "lighter"  body armour of a lighter kind than the worn piece: never an upgrade
--   "kind"     body armour of a heavier kind than the worn piece: an upgrade at the worn level
--              or above, and below it where both are below uncommon quality and the kind weights
--              say so (armour is all either has)
--   "level"    the item level, as before: above the reference is an upgrade
--   "stats"    brief K27, with a classId: the spec gate, or Worth per spec decided (the header)
--   "use"      brief TK2, with a classId: "unknown" for a trinket whose Use was not scored (no us),
--              never judged by item level (Gear.UseUnscored)
-- Brief K27: the fifth answer, specs, and the sixth, the worn slots the upgraded specs were held
-- against, as the header says. classId nil (or a class Gear.SPECS does not list) answers exactly
-- as K24h did. enabledSpecs is the set of spec keys the player wants weighed ({ holy = true }), nil
-- for every spec of the class; only those open at playerLevel are scored (Gear.ScoredSpecs, brief
-- BQ30). playerLevel is the player's, which a rating in a row's stats is read at (nil: the cap,
-- 60). canDualWield false keeps
-- a one hander to the main hand; nil (not known) or true lets it take a weapon's off hand place.
-- Brief K28: suffix is the item's roll (Gear.SuffixStats' { stats, es }), counted as stats everywhere: in
-- the spec gate, the readable test, the empty slot's specs and the per spec Worth. nil (no roll,
-- or a caller from before K28) answers exactly as K27 did. Pure.
function Gear.Compare(row, worn, canDualWield, classId, enabledSpecs, playerLevel, suffix)
  if type(row) ~= "table" then
    return "unknown", nil, nil, nil
  end
  local il = whole(row.il)
  local it = whole(row.it)
  if not il or il <= 0 or not it or not Gear.SLOTS_BY_TYPE[it] or type(worn) ~= "table" then
    return "unknown", nil, nil, nil
  end
  if not hasRoll(suffix) then
    suffix = nil
  end
  local level, slot, empty = reference(it, worn, canDualWield)
  local class = whole(classId)
  -- Brief BQ30: only the specs open at the player's level are scored.
  local specs = Gear.ScoredSpecs(class, enabledSpecs, playerLevel)
  -- Brief GW2 (QA item 139): and of those, only the specs whose weapon layouts take the candidate
  -- (Gear.LayoutTakes); narrowed, the specs it is an upgrade for are named even where the stats did
  -- not decide.
  local narrowed = nil
  if specs ~= nil then
    local takers = Gear.LayoutSpecs(class, specs, it, playerLevel)
    if #takers == 0 then
      return "not_upgrade", level and il - level or nil, slot, "stats", {}
    end
    if takers ~= specs then
      specs, narrowed = takers, takers
    end
    -- Brief GW2b: a one hander goes in the off hand only for a spec whose dual layout is open at the
    -- level (Gear.Layouts); where none is (a warrior before 30), it is held against the main hand.
    if it == Gear.TYPE.WEAPON and canDualWield ~= false and not Gear.AnyDualLayout(class, specs, playerLevel) then
      canDualWield = false
      level, slot, empty = reference(it, worn, canDualWield)
    end
    -- Their layouts hold an off hand piece, so beside a worn two hander the off hand is empty for
    -- them: an off hand candidate is held against nothing.
    if OFF_HAND_ONLY[it] and wornType(worn, S.MAINHAND) == Gear.TYPE.TWO_HAND then
      level, slot, empty = 0, S.OFFHAND, true
    end
  end
  local weighed = specs ~= nil and readable(row, suffix)
  if level ~= nil and empty then
    -- Brief K27: an upgrade for each spec that weighs anything on it. Never gated: an empty slot is
    -- an upgrade for anything wearable (K24h).
    local diff = il - level
    if weighed then
      local list = {}
      for _, spec in ipairs(specs) do
        if (Gear.Worth(row, class, spec, playerLevel, suffix) or 0) > 0 then
          list[#list + 1] = spec
        end
      end
      if #list > 0 then
        return "upgrade", diff, slot, "empty", list
      end
    end
    return "upgrade", diff, slot, "empty", narrowed
  end
  -- Brief K27: the spec gate, whatever the level, the kind or what is worn (an empty slot aside).
  -- Brief K28: the roll's stats count, so a Cord of Shadow Wrath is gated for every paladin spec.
  if weighed and carriesGateStats(row, suffix) and not weighsAny(row, class, specs, suffix) then
    return "not_upgrade", level and il - level or nil, slot, "stats", {}
  end
  if level == nil then
    return "unknown", nil, slot, nil
  end
  if weighed then
    local compare, statsDiff, statsSlot, basis, list, held =
      byStats(row, worn, canDualWield, class, specs, il, it, level, slot, playerLevel, suffix)
    if compare ~= nil then
      -- Brief BQ30 (the owner, 2026-10-11: "a Survival hunter still wants a bow, so it is Any"): a
      -- ranged weapon one hunter spec upgrades is an upgrade for every scored hunter spec
      -- (Gear.SHARED_SLOTS), so the line reads plain and the pill "Equip (Any spec)" (brief EQ2).
      if compare == "upgrade" and type(list) == "table" and #list > 0 and Gear.SlotShared(class, statsSlot) then
        list = specs
      end
      return compare, statsDiff, statsSlot, basis, list, held
    end
  end
  -- Brief TK2: a trinket whose Use could not be scored is never judged by its item level.
  if specs ~= nil and Gear.UseUnscored(row) then
    return "unknown", il - level, slot, "use"
  end
  local compare, diff, outSlot, basis = byLevelAndKind(row, worn, il, it, level, slot)
  if compare == "upgrade" and narrowed then
    return compare, diff, outSlot, basis, narrowed
  end
  return compare, diff, outSlot, basis
end

-- The worn ids in slot order as one string, "-" for an empty slot: "1234.-.5678...". Two worn
-- maps sign the same only when every slot holds the same id. "?" for no map. Brief K28: a worn
-- piece with a roll (sfxKey, Gear.ReadWorn) signs as its id and the roll's key, "14173/b12761", so
-- the same id re-rolled signs differently; a piece with none signs as before. Pure.
function Gear.Signature(worn)
  if type(worn) ~= "table" then
    return "?"
  end
  local parts = {}
  for slot = Gear.FIRST_SLOT, Gear.LAST_SLOT do
    local entry = worn[slot]
    local id = type(entry) == "table" and whole(entry.itemId) or nil
    local part = id and tostring(math.floor(id)) or "-"
    if id and type(entry.sfxKey) == "string" then
      part = part .. "/" .. entry.sfxKey
    end
    parts[#parts + 1] = part
  end
  return table.concat(parts, ".")
end

--------------------------------------------------------------------------------
-- Brief K28: random suffix gear. Pure, over the link string, the row and the module.
--------------------------------------------------------------------------------

-- The generated module's name (ItemTree_Data, load on demand), and its shape, from the data
-- branch's contract (ItemTree-Data docs/data-format.md "Random suffixes"):
--   { b = { [bonusListId] = row }, r = { [linkSuffixId] = row } }
--   row = { n = "of the Bear", s = { {stat, value} } flat, p = { {stat, share} } of 10,000 }
-- b is Forever's (its suffixes are bonus lists: the client has no ItemRandomProperties or
-- ItemRandomSuffix table), r a Classic Era compile's (a positive id ItemRandomProperties, flat; a
-- negative id ItemRandomSuffix, shares). Codes and units are es's. An id the module does not hold
-- rolled nothing the weights read: no stats, never an error.
Gear.SUFFIX_MODULE = "RandomSuffixes"
-- The share a module row states is out of this many, and an item row's rp is the budget it is a
-- share of: value = floor(share * rp / SHARE_WHOLE + 0.5) (Forever's own StatPercentEditor rule,
-- the data branch's finding: "of the Bear" is Strength 6,666 and Stamina 6,666).
Gear.SHARE_WHOLE = 10000

-- The item string's fields, split on ":" with the leading "item" as field 1 (the id is field 2).
-- Client assumption (bible B1), on the forever branch of the UI source mirror at 1.60.1.70245: the
-- client's own Lua reads an item link as LinkUtil.ExtractLink's type "item" and options split on
-- ":" with every empty field kept (Blizzard_SharedXML/LinkUtil.lua SplitLinkOptions, string.split;
-- Blizzard_UIPanels_Game/Mainline/DressUpFrames.lua DressUpBattlePetLink takes the first option as
-- the item id), so field 2 is the id. No Lua in the mirror reads a field past the id: the suffix
-- id at field 8, numBonusIds at field 14 and the bonus ids from field 15 are the retail engine's
-- item string layout, which the data branch documents and which is NOT confirmed in game until
-- the owner runs /itprobe suffix over a real roll (docs/briefs/K28-random-suffix.md). Fake
-- variants: tests/spec/gear_suffix_spec.lua "forever retail layout", "classic era suffix id".
Gear.LINK_FIELD = { ID = 2, SUFFIX = 8, NUM_BONUS = 14, FIRST_BONUS = 15 }
-- How many parsed links are held (by link string) before the memo is dropped whole.
Gear.LINK_MEMO_MAX = 512
-- Brief K28 (the owner's Fable addendum, 2026-10-09, a security fix): the most bonus ids a link is
-- read for. numBonusIds is the link's own field, and any hovered hyperlink reaches the parse (a
-- chat link from another player included), so a crafted count ("item:14173:::::::::::::2000000000")
-- must never drive a loop: a count above this, above the fields the link actually carries, below
-- 0 or not a whole number is refused (no roll at all), and the split itself stops at the last field
-- a count this size could name. A real roll names a handful.
Gear.MAX_BONUS_IDS = 64
-- The longest numeric field read: ten digits and a sign. A longer one (or "inf", "nan", "0x10",
-- which tonumber would take) is no number.
local MAX_FIELD_LENGTH = 11

local EMPTY_LIST = {}

-- The fields of an item string, every empty field kept as "", at most limit of them (the rest is
-- never split). Pure.
local function splitFields(text, limit)
  local fields, from = {}, 1
  while true do
    if #fields >= limit then
      return fields
    end
    local at = string.find(text, ":", from, true)
    if not at then
      fields[#fields + 1] = string.sub(text, from)
      return fields
    end
    fields[#fields + 1] = string.sub(text, from, at - 1)
    from = at + 1
  end
end

-- One field as a whole number, nil for an empty field or anything else: only an optional minus
-- and digits, at most MAX_FIELD_LENGTH characters.
local function field(fields, index)
  local text = fields[index]
  if type(text) ~= "string" or #text > MAX_FIELD_LENGTH or not string.find(text, "^%-?%d+$") then
    return nil
  end
  return tonumber(text)
end

Gear.linkMemo = {}
Gear.linkMemoCount = 0
-- Brief K28: the full answers of Gear.SuffixStats by link string, each held with the rp and the
-- module it was priced under, dropped with the parse memo.
Gear.suffixMemo = {}

-- Brief K28: an item link (or a bare item string) read into { id, suffix, count, bonus }: id the
-- item id (field 2), suffix the suffix id (field 8; nil where it is empty or 0), count numBonusIds
-- (field 14; 0 where it is empty) and bonus the bonus ids after it in link order (fields 15 on,
-- only the whole numbers among them). nil for anything that is not an item link. A count the link
-- cannot back (above Gear.MAX_BONUS_IDS, above the fields present, below 0, not a whole number) is
-- refused: refused = true, no suffix and no bonus ids, so the link names no roll, and no loop ever
-- runs past the fields present. One split per link string: the answer is held by the string
-- (Gear.linkMemo, read it and never change it). Pure.
function Gear.ParseItemLink(link)
  if type(link) ~= "string" then
    return nil
  end
  local held = Gear.linkMemo[link]
  if held ~= nil then
    return held or nil
  end
  local itemString = string.match(link, "item:[^|]*")
  local parsed = false
  if itemString then
    local F = Gear.LINK_FIELD
    local fields = splitFields(itemString, F.FIRST_BONUS + Gear.MAX_BONUS_IDS - 1)
    local id = field(fields, F.ID)
    if id and id > 0 then
      local suffix = field(fields, F.SUFFIX)
      if suffix == 0 then
        suffix = nil
      end
      local count, refused = 0, nil
      local countText = fields[F.NUM_BONUS]
      if countText ~= nil and countText ~= "" then
        count = field(fields, F.NUM_BONUS)
        if count == nil or count < 0 or count > Gear.MAX_BONUS_IDS or F.FIRST_BONUS + count - 1 > #fields then
          refused = true
        end
      end
      local bonus = {}
      if refused then
        suffix = nil
      else
        for index = F.FIRST_BONUS, F.FIRST_BONUS + count - 1 do
          local bonusId = field(fields, index)
          if bonusId then
            bonus[#bonus + 1] = bonusId
          end
        end
      end
      parsed = { id = id, suffix = suffix, count = count, bonus = bonus, refused = refused }
    end
  end
  if Gear.linkMemoCount >= Gear.LINK_MEMO_MAX then
    Gear.linkMemo, Gear.suffixMemo, Gear.linkMemoCount = {}, {}, 0
  end
  Gear.linkMemo[link] = parsed
  Gear.linkMemoCount = Gear.linkMemoCount + 1
  return parsed or nil
end

-- Brief K28: the module rows a parsed link names, in order: each bonus id the module's b holds
-- (once each), then the suffix id its r holds, as { kind = "b" or "r", id, row }. Ids it does not
-- hold are left out (a bonus list that is no suffix). Pure.
function Gear.SuffixRows(parsed, module)
  local found = {}
  if type(parsed) ~= "table" or type(module) ~= "table" then
    return found
  end
  local lists = module.b
  if type(lists) == "table" then
    local seen = {}
    for _, id in ipairs(parsed.bonus or EMPTY_LIST) do
      local row = lists[id]
      if type(row) == "table" and not seen[id] then
        seen[id] = true
        found[#found + 1] = { kind = "b", id = id, row = row }
      end
    end
  end
  local links = module.r
  if parsed.suffix ~= nil and type(links) == "table" then
    local row = links[parsed.suffix]
    if type(row) == "table" then
      found[#found + 1] = { kind = "r", id = parsed.suffix, row = row }
    end
  end
  return found
end

-- Brief K28: a share priced on a budget, floor(share * rp / 10000 + 0.5). Pure.
function Gear.PriceShare(share, rp)
  local amount, points = whole(share), whole(rp)
  if not amount or not points then
    return nil
  end
  return math.floor(amount * points / Gear.SHARE_WHOLE + 0.5)
end

-- A {{stat, value}} list from sums by code, sorted by code, a stat that sums to 0 left out; nil
-- for an empty one.
local function sortedPairs(sums, codes)
  table.sort(codes)
  local out = {}
  for _, code in ipairs(codes) do
    if sums[code] ~= 0 then
      out[#out + 1] = { code, sums[code] }
    end
  end
  return #out > 0 and out or nil
end

-- Brief K28: the rows' stats as a roll, { stats = priced, es = flat }, each half summed by code
-- into its own {{stat, value}} list sorted by code (nil where it holds nothing, a stat summing to 0
-- left out): stats the shares p, each pair priced on rp (Gear.PriceShare) where rp is above 0, es
-- the flat values s as they stand. The two halves are never summed together: a priced share reads
-- like the row's stats, a flat value like es (Gear.Worth). With no rp the shares are left out and
-- only the flat half counts. nil where neither half holds anything. Pure; a new table every call.
function Gear.PriceSuffix(found, rp)
  local points = whole(rp)
  if points ~= nil and points <= 0 then
    points = nil
  end
  local flat, flatCodes, priced, pricedCodes = {}, {}, {}, {}
  local function add(sums, codes, code, value)
    if code == nil or value == nil then
      return
    end
    if sums[code] == nil then
      sums[code] = 0
      codes[#codes + 1] = code
    end
    sums[code] = sums[code] + value
  end
  for _, entry in ipairs(type(found) == "table" and found or EMPTY_LIST) do
    local row = type(entry) == "table" and entry.row or nil
    if type(row) == "table" then
      for _, pair in ipairs(type(row.s) == "table" and row.s or EMPTY_LIST) do
        if type(pair) == "table" then
          add(flat, flatCodes, whole(pair[1]), whole(pair[2]))
        end
      end
      if points then
        for _, pair in ipairs(type(row.p) == "table" and row.p or EMPTY_LIST) do
          if type(pair) == "table" then
            add(priced, pricedCodes, whole(pair[1]), Gear.PriceShare(pair[2], points))
          end
        end
      end
    end
  end
  local stats, es = sortedPairs(priced, pricedCodes), sortedPairs(flat, flatCodes)
  if stats == nil and es == nil then
    return nil
  end
  return { stats = stats, es = es }
end

-- Brief K28: the roll's key, short and stable: "b" and the bonus ids found, sorted ("b12722" or
-- "b12722,13205"), then "r" and the suffix id ("r-9"), joined by ";" where a link names both.
local function rollKey(found)
  local lists, link = {}, nil
  for _, entry in ipairs(found) do
    if entry.kind == "b" then
      lists[#lists + 1] = entry.id
    else
      link = entry.id
    end
  end
  table.sort(lists)
  local parts = {}
  if #lists > 0 then
    local words = {}
    for index, id in ipairs(lists) do
      words[index] = tostring(id)
    end
    parts[#parts + 1] = "b" .. table.concat(words, ",")
  end
  if link ~= nil then
    parts[#parts + 1] = "r" .. tostring(link)
  end
  return table.concat(parts, ";")
end

-- Brief K28: the RandomSuffixes module, where it is registered or built (Data:Has), else nil. It
-- never asks for a module that is neither, so it never loads ItemTree_Data (a bag pass or a
-- tooltip never triggers the load; the item rows it prices against are ItemTree_Data's too).
-- Brief K28 (the owner's Fable addendum): a module found is held, against the Data table and its
-- generation (Data:Reset and every other drop of the built tables bump it), so a bag pass asks Data
-- once and not twice per slot; an answer of none is never held, so a module ItemTree_Data
-- registers later is seen at once. A Data with no generation (a spec's stand in) is asked every
-- time.
Gear.suffixModuleHeld = nil
function Gear.SuffixModule()
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.Get) ~= "function" then
    return nil
  end
  local generation = data.generation
  local held = Gear.suffixModuleHeld
  if held ~= nil and generation ~= nil and held.data == data and held.generation == generation then
    return held.module
  end
  local module = Gear.ReadSuffixModule(data)
  if module ~= nil and type(generation) == "number" then
    Gear.suffixModuleHeld = { data = data, generation = generation, module = module }
  else
    Gear.suffixModuleHeld = nil
  end
  return module
end

-- The module read from Data, as Gear.SuffixModule asks it: Data:Has first, then Data:Get, each
-- under pcall. nil for none.
function Gear.ReadSuffixModule(data)
  if type(data.Has) == "function" then
    local okHas, has = pcall(data.Has, data, Gear.SUFFIX_MODULE)
    if not okHas or not has then
      return nil
    end
  end
  local ok, module = pcall(data.Get, data, Gear.SUFFIX_MODULE)
  if ok and type(module) == "table" then
    return module
  end
  return nil
end

-- Brief K28: whether a row's link is worth reading for a roll: a weapon or armour row with rp (a
-- Forever item that can roll), or any weapon or armour row while the module holds Classic Era link
-- rows (r: an Era compile ships no rp, and its flat rows need none). module nil reads
-- Gear.SuffixModule. Pure over the module.
function Gear.MayRoll(row, module)
  if type(row) ~= "table" then
    return false
  end
  local itemClass = whole(row.c)
  if itemClass ~= Gear.WEAPON_CLASS and itemClass ~= Gear.ARMOUR_CLASS then
    return false
  end
  module = module or Gear.SuffixModule()
  if type(module) ~= "table" then
    return false
  end
  if whole(row.rp) ~= nil then
    return true
  end
  return type(module.r) == "table" and next(module.r) ~= nil
end

-- Brief K28: the roll in an item's link, priced for its row: the roll, { stats = the priced shares,
-- es = the flat values } (Gear.PriceSuffix, es's codes, each half nil where empty), and the roll's
-- key ("b12761", "r-9"), or nil, nil where the link carries no suffix, the module is absent or
-- holds none of its ids, or nothing prices (shares only and no rp). The caller hands in the row of
-- the link's own item, which is only read, never written (Data shares its decoded rows). module
-- nil reads Gear.SuffixModule. One split per link string (Gear.ParseItemLink), and the answer is
-- held by the link string beside the rp and module it was priced under: the roll is shared by
-- every caller of that link, so it is read and never changed. Pure; no client call.
function Gear.SuffixStats(link, row, module)
  if type(link) ~= "string" or type(row) ~= "table" then
    return nil, nil
  end
  local parsed = Gear.ParseItemLink(link)
  if parsed == nil or (parsed.suffix == nil and #parsed.bonus == 0) then
    return nil, nil
  end
  module = module or Gear.SuffixModule()
  if type(module) ~= "table" then
    return nil, nil
  end
  local rp = whole(row.rp)
  local held = Gear.suffixMemo[link]
  if held ~= nil and held.module == module and held.rp == rp then
    return held.roll, held.key
  end
  local found = Gear.SuffixRows(parsed, module)
  local roll, key = nil, nil
  if #found > 0 then
    roll = Gear.PriceSuffix(found, rp)
    if roll ~= nil then
      key = rollKey(found)
    end
  end
  Gear.suffixMemo[link] = { module = module, rp = rp, roll = roll, key = key }
  return roll, key
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

-- The worn map, read once and kept until an event drops it (Gear.Drop). nil until read.
Gear.worn = nil
-- Brief K20-wire: the worn map's signature (Gear.Signature), kept beside it and dropped with it,
-- so the Keep score cache's key costs no string building per bag slot.
Gear.wornSignature = nil
-- How many times the worn map was read from the client, for the probe and the specs.
Gear.reads = 0

function Gear.Drop()
  Gear.worn = nil
  Gear.wornSignature = nil
end

-- One shipped row by id, through Core/Data.lua (the shipped rows only, never the client).
local function shippedRow(itemId)
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.GetItem) ~= "function" then
    return nil
  end
  local ok, row = pcall(data.GetItem, data, itemId)
  if ok and type(row) == "table" then
    return row
  end
  return nil
end

-- Client assumption (bible B1), read on the forever branch of the UI source mirror at 1.60.1.70205
-- (Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua calls GetInventoryItemID("player", slot)):
-- the global answers the worn item's id, or nil for an empty slot, from what the client already
-- holds, with no server query. Fake variants: tests/spec/gear_spec.lua "forever 1.60.1.70205"
-- (ids), "no GetInventoryItemID" and "raising". Probe: /itprobe gear prints the map it reads.
-- The item levels and types are the shipped rows', so an item the rows do not hold has none.
-- Brief K27: each entry carries what Gear.Worth reads off the row too (c, arm, dmg, dl, stats, es;
-- the lists are the row's own, read and never changed), so the stats compare weighs the worn piece
-- the way it weighs the item. The signature names the ids (brief K28: and each worn roll's key):
-- the rows behind them are the shipped data's, which a session does not change.
--
-- Brief K28: a worn piece whose row may roll a suffix (Gear.MayRoll: the module is there, and the
-- row has rp or the module holds Classic Era link rows) has its link read too, and its roll
-- ({ stats, es }, Gear.SuffixStats) and the roll's key ride on the entry as sfx and sfxKey (only
-- where the link names a roll the module prices), so the signature names the roll as well. Client
-- assumption (bible B1), read on the forever branch of the UI source mirror at 1.60.1.70245:
-- GetInventoryItemLink("player", slot)
-- answers the worn item's link from what the client holds, with no server query
-- (Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua:2140 and 2179 call it with the slot button's
-- GetID(), Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua:1208 the same); a link the client keeps
-- secret (Util.CanRead, bible B10) or a raise reads as no link. Fake variants:
-- tests/spec/gear_suffix_spec.lua "forever 1.60.1.70245 links", "no GetInventoryItemLink",
-- "raising" and "secret". Probe: /itprobe suffix prints the hovered item's parse and pricing.
local function wornLink(getLink, slot, itemId)
  if type(getLink) ~= "function" then
    return nil
  end
  local ok, link = pcall(getLink, "player", slot)
  if not ok or type(link) ~= "string" then
    return nil
  end
  local util = ItemTree.Util
  if type(util) == "table" and type(util.CanRead) == "function" and not util.CanRead(link) then
    return nil
  end
  local parsed = Gear.ParseItemLink(link)
  if parsed == nil or parsed.id ~= itemId then
    return nil
  end
  return link
end

function Gear.ReadWorn()
  local getId = rawget(_G, "GetInventoryItemID")
  if type(getId) ~= "function" then
    return nil
  end
  Gear.reads = Gear.reads + 1
  -- Brief K28: the module read once per worn read, and the link global only where it is there.
  local module = Gear.SuffixModule()
  local getLink = module and rawget(_G, "GetInventoryItemLink") or nil
  local worn = {}
  for slot = Gear.FIRST_SLOT, Gear.LAST_SLOT do
    local ok, itemId = pcall(getId, "player", slot)
    local id = ok and whole(itemId) or nil
    if id and id > 0 then
      local row = shippedRow(id)
      local sfx, sfxKey = nil, nil
      if getLink and row and Gear.MayRoll(row, module) then
        local link = wornLink(getLink, slot, id)
        if link then
          sfx, sfxKey = Gear.SuffixStats(link, row, module)
        end
      end
      worn[slot] = {
        itemId = id,
        il = row and whole(row.il) or nil,
        it = row and whole(row.it) or nil,
        -- Brief K24h: the quality and armour subclass, for the body armour kind compare.
        q = row and whole(row.q) or nil,
        sc = row and whole(row.sc) or nil,
        -- Brief K27: what Gear.Worth weighs.
        c = row and whole(row.c) or nil,
        arm = row and whole(row.arm) or nil,
        dl = row and whole(row.dl) or nil,
        dmg = row and type(row.dmg) == "table" and row.dmg or nil,
        stats = row and type(row.stats) == "table" and row.stats or nil,
        es = row and type(row.es) == "table" and row.es or nil,
        -- Brief TK2: a worn trinket's scored Use.
        us = row and type(row.us) == "table" and row.us or nil,
        -- Brief K28: the worn roll ({ stats, es }) and its key, nil for none.
        sfx = sfx,
        sfxKey = sfxKey,
      }
    end
  end
  return worn
end

-- The worn map, read on first ask and kept until PLAYER_EQUIPMENT_CHANGED, PLAYER_ENTERING_WORLD
-- or Gear.Drop. nil where the client has no GetInventoryItemID.
--- Brief BQ14 follow up (the owner's gear:3, 2026-10-10): the pretend worn set (/itemtree demo worn,
--- Core/Demo.lua Demo.Worn: { [slot] = itemId }) as Gear.ReadWorn's map, built from the shipped rows,
--- or nil while none is pretended. The pretend set is the whole worn set: a slot it does not name is
--- empty. Held per pretend set (Gear.demoWorn), so the score cache's key holds while it stands.
Gear.demoWorn = nil
Gear.demoWornOf = nil

function Gear.DemoWorn()
  local demo = ItemTree.Demo
  if type(demo) ~= "table" or type(demo.Worn) ~= "function" then
    return nil
  end
  local ok, ids = pcall(demo.Worn)
  if not ok or type(ids) ~= "table" then
    return nil
  end
  if Gear.demoWornOf == ids and Gear.demoWorn then
    return Gear.demoWorn
  end
  -- Brief ST5: a pretend worn piece's roll (/itemtree demo worn <slot> <id:suffix or link>), read as
  -- Gear.ReadWorn reads a real one's link.
  local links = {}
  if type(demo.WornLinks) == "function" then
    local okLinks, held = pcall(demo.WornLinks)
    links = okLinks and type(held) == "table" and held or links
  end
  local module = next(links) ~= nil and Gear.SuffixModule() or nil
  local worn = {}
  for slot, id in pairs(ids) do
    local row = shippedRow(tonumber(id))
    local sfx, sfxKey = nil, nil
    if module and row and type(links[slot]) == "string" then
      sfx, sfxKey = Gear.SuffixStats(links[slot], row, module)
    end
    worn[slot] = {
      sfx = sfx,
      sfxKey = sfxKey,
      itemId = tonumber(id),
      il = row and whole(row.il) or nil,
      it = row and whole(row.it) or nil,
      q = row and whole(row.q) or nil,
      sc = row and whole(row.sc) or nil,
      c = row and whole(row.c) or nil,
      arm = row and whole(row.arm) or nil,
      dl = row and whole(row.dl) or nil,
      dmg = row and type(row.dmg) == "table" and row.dmg or nil,
      stats = row and type(row.stats) == "table" and row.stats or nil,
      es = row and type(row.es) == "table" and row.es or nil,
      us = row and type(row.us) == "table" and row.us or nil,
    }
  end
  Gear.demoWorn, Gear.demoWornOf = worn, ids
  return worn
end

function Gear.Worn()
  -- Brief BQ14 follow up: the pretend worn set while one is set.
  local pretend = Gear.DemoWorn()
  if pretend then
    return pretend
  end
  if Gear.worn ~= nil then
    return Gear.worn
  end
  Gear.worn = Gear.ReadWorn()
  return Gear.worn
end

-- Brief K20-wire: the worn map (Gear.Worn) and its signature (Gear.Signature), the signature
-- worked out once per read of the map and kept until Gear.Drop. Core/Keep.lua's score cache keys
-- on the signature, so a bag pass reads one held string per slot.
function Gear.WornState()
  local worn = Gear.Worn()
  if Gear.wornSignature == nil or Gear.wornSignatureOf ~= worn then
    -- Brief BQ11: the Careful Aim rank joins the signature, so a moved rank moves the key.
    Gear.wornSignature = Gear.Signature(worn) .. Gear.TalentSignature()
    Gear.wornSignatureOf = worn
  end
  return worn, Gear.wornSignature
end

-- The player's class id (UnitClass's third answer) and level (UnitLevel), each nil where the
-- client will not say. A question about the player's class and level only.
function Gear.Player()
  local classId, level = nil, nil
  local unitClass = rawget(_G, "UnitClass")
  if type(unitClass) == "function" then
    local ok, _, _, id = pcall(unitClass, "player")
    classId = ok and whole(id) or nil
  end
  -- Brief BQ14 follow up: the pretend class (Core/Demo.lua) while it is set.
  local pretendDemo = ItemTree.Demo
  if type(pretendDemo) == "table" and type(pretendDemo.ClassId) == "function" then
    local ok, pretend = pcall(pretendDemo.ClassId)
    if ok and pretend then
      classId = pretend
    end
  end
  local unitLevel = rawget(_G, "UnitLevel")
  if type(unitLevel) == "function" then
    local ok, value = pcall(unitLevel, "player")
    level = ok and whole(value) or nil
  end
  -- Brief BQ13: the pretend level (Core/Demo.lua) while it is set.
  local demo = ItemTree.Demo
  if type(demo) == "table" and type(demo.Level) == "function" then
    local ok, pretend = pcall(demo.Level)
    if ok and pretend then
      level = pretend
    end
  end
  return classId, level
end

-- Brief BQ11: the character's Careful Aim rank (Gear.carefulAimRank), read from the talent API.
-- Client assumption (bible B1), read on the forever branch of the UI source mirror at 1.60.1.70245:
-- Forever's talent frame is the trait system (Blizzard_PlayerSpells/Blizzard_PlayerSpells.toc loads
-- Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua for the camelot game type, which reads the
-- config through C_SpecializationInfo.GetCombatConfigIDForSpecGroup at :162 and
-- C_SpecializationInfo.GetActiveSpecGroup at :100, and the tree through C_Traits at :83 and :88).
-- The generated documentation (Blizzard_APIDocumentationGenerated) states the calls and fields:
-- ClassTalentsDocumentation.lua:73 C_ClassTalents.GetActiveConfigID; SharedTraitsDocumentation.lua
-- :201 GetConfigInfo (treeIDs, :1020), :586 GetTreeNodes, :370 GetNodeInfo (entryIDs :1101,
-- ranksPurchased :1108, activeRank :1111), :264 GetEntryInfo (definitionID :1052), :248
-- GetDefinitionInfo (spellID :1038); SpecializationInfoDocumentation.lua:90
-- GetCombatConfigIDForSpecGroup, :41 GetActiveSpecGroup, :316 GetTalentInfo(query) whose result
-- (:606) carries spellID and rank. The shapes, each under pcall, modern first:
--   "traits"      C_ClassTalents.GetActiveConfigID (else the combat config of the active spec
--                 group), then the node whose entry's definition is spell 1223984: walked once
--                 per config (every tree node's info, entries and definitions) and then held, so
--                 a later read is one GetNodeInfo; its activeRank, else ranksPurchased.
--   "talentinfo"  C_SpecializationInfo.GetTalentInfo({ specializationIndex, talentIndex }) over
--                 the talent tabs, the entry whose spellID is 1223984, its rank.
--   "classic"     GetTalentInfo(tab, index), the entry named as the spell (GetSpellInfo or
--                 C_Spell.GetSpellName of 1223984), its fifth answer the rank.
-- Read out of combat only (InCombatLockdown; a read asked in combat waits for
-- PLAYER_REGEN_ENABLED), every value through Util.CanRead (bible B10: a secret reads as unknown),
-- only for a hunter, whatever the spec setting. Refreshed on PLAYER_TALENT_UPDATE,
-- TRAIT_CONFIG_UPDATED, ACTIVE_TALENT_GROUP_CHANGED, CHARACTER_POINTS_CHANGED (each documented:
-- SpecializationInfoDocumentation.lua:503 and :447, SharedTraitsDocumentation.lua:873,
-- PaperDollInfoDocumentation.lua:297), on PLAYER_ENTERING_WORLD, and on the first SPELLS_CHANGED
-- (SpellBookDocumentation.lua:968) while nothing has been read, so login reads it once the spells
-- are in. No polling. A moved rank drops the Keep scores the way a gear change does. Fake
-- variants: tests/spec/gear_talent_spec.lua. Probe: /itprobe talent.
Gear.talent = { rank = nil, shape = nil, at = nil, reads = 0, pending = false }

local function canReadValue(value)
  local util = ItemTree.Util
  if type(util) == "table" and type(util.CanRead) == "function" then
    local ok, answer = pcall(util.CanRead, value)
    return ok and answer == true
  end
  return true
end

-- A number the client answered, or nil (a raise, a secret, anything else).
local function readNumber(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if not ok or type(value) ~= "number" or not canReadValue(value) then
    return nil
  end
  return value
end

-- A table the client answered, or nil.
local function readTable(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if not ok or type(value) ~= "table" then
    return nil
  end
  return value
end

local function numberField(info, key)
  local value = type(info) == "table" and info[key] or nil
  if type(value) ~= "number" or not canReadValue(value) then
    return nil
  end
  return value
end

-- The active talent config: C_ClassTalents' first, else the active spec group's combat config.
local function activeConfigId()
  local classTalents = rawget(_G, "C_ClassTalents")
  local id = type(classTalents) == "table" and readNumber(classTalents.GetActiveConfigID) or nil
  if id then
    return id
  end
  local specInfo = rawget(_G, "C_SpecializationInfo")
  if type(specInfo) ~= "table" then
    return nil
  end
  local group = readNumber(specInfo.GetActiveSpecGroup) or 1
  return readNumber(specInfo.GetCombatConfigIDForSpecGroup, group)
end

local function nodeRank(traits, configId, nodeId)
  local info = readTable(traits.GetNodeInfo, configId, nodeId)
  if info == nil then
    return nil
  end
  return numberField(info, "activeRank") or numberField(info, "ranksPurchased")
end

-- Whether a node's entries name Careful Aim's spell.
local function nodeIsCarefulAim(traits, configId, info)
  for _, entryId in ipairs(type(info.entryIDs) == "table" and info.entryIDs or {}) do
    local entry = readTable(traits.GetEntryInfo, configId, entryId)
    local definitionId = numberField(entry, "definitionID")
    local definition = definitionId and readTable(traits.GetDefinitionInfo, definitionId) or nil
    if numberField(definition, "spellID") == Gear.CAREFUL_AIM_SPELL then
      return true
    end
  end
  return false
end

-- The "traits" shape: the rank, or nil where the API is not there or answered nothing usable.
local function traitsRank()
  local traits = rawget(_G, "C_Traits")
  if type(traits) ~= "table" or type(traits.GetNodeInfo) ~= "function" then
    return nil
  end
  local configId = activeConfigId()
  if configId == nil then
    return nil
  end
  local held = Gear.talent
  if held.configId == configId and held.nodeId ~= nil then
    local rank = nodeRank(traits, configId, held.nodeId)
    if rank ~= nil then
      return rank
    end
  elseif held.configId == configId and held.missed then
    return 0
  end
  held.configId, held.nodeId, held.missed = configId, nil, nil
  local config = readTable(traits.GetConfigInfo, configId)
  local seen = 0
  for _, treeId in ipairs(type(config) == "table" and type(config.treeIDs) == "table" and config.treeIDs or {}) do
    for _, nodeId in ipairs(readTable(traits.GetTreeNodes, treeId) or {}) do
      local info = readTable(traits.GetNodeInfo, configId, nodeId)
      if info ~= nil then
        seen = seen + 1
        if nodeIsCarefulAim(traits, configId, info) then
          held.nodeId = nodeId
          return numberField(info, "activeRank") or numberField(info, "ranksPurchased")
        end
      end
    end
  end
  if seen == 0 then
    -- Nothing answered (the tree not loaded yet): unknown, and walked again next time.
    held.configId = nil
    return nil
  end
  -- The tree answered and holds no Careful Aim: rank 0 until the config changes.
  held.missed = true
  return 0
end

-- The number of talent tabs and talents per tab the classic shapes walk, the client's where it says.
local function tabCount()
  return readNumber(rawget(_G, "GetNumTalentTabs")) or 3
end

local function talentCount(tab)
  return readNumber(rawget(_G, "GetNumTalents"), tab) or 30
end

-- The "talentinfo" shape.
local function talentInfoRank()
  local specInfo = rawget(_G, "C_SpecializationInfo")
  if type(specInfo) ~= "table" or type(specInfo.GetTalentInfo) ~= "function" then
    return nil
  end
  local answered = false
  for tab = 1, tabCount() do
    for index = 1, talentCount(tab) do
      local info = readTable(specInfo.GetTalentInfo, { specializationIndex = tab, talentIndex = index })
      if info ~= nil then
        answered = true
        if numberField(info, "spellID") == Gear.CAREFUL_AIM_SPELL then
          return numberField(info, "rank") or 0
        end
      end
    end
  end
  return answered and 0 or nil
end

-- Careful Aim's name in the client's language, or nil.
local function carefulAimName()
  local spell = rawget(_G, "C_Spell")
  if type(spell) == "table" and type(spell.GetSpellName) == "function" then
    local ok, name = pcall(spell.GetSpellName, Gear.CAREFUL_AIM_SPELL)
    if ok and type(name) == "string" and name ~= "" and canReadValue(name) then
      return name
    end
  end
  local getInfo = rawget(_G, "GetSpellInfo")
  if type(getInfo) == "function" then
    local ok, name = pcall(getInfo, Gear.CAREFUL_AIM_SPELL)
    if ok and type(name) == "string" and name ~= "" and canReadValue(name) then
      return name
    end
  end
  return nil
end

-- The "classic" shape.
local function classicRank()
  local getTalent = rawget(_G, "GetTalentInfo")
  local name = type(getTalent) == "function" and carefulAimName() or nil
  if name == nil then
    return nil
  end
  local answered = false
  for tab = 1, tabCount() do
    for index = 1, talentCount(tab) do
      local ok, talentName, _, _, _, rank = pcall(getTalent, tab, index)
      if ok and type(talentName) == "string" and canReadValue(talentName) then
        answered = true
        if talentName == name then
          return (type(rank) == "number" and canReadValue(rank)) and rank or 0
        end
      end
    end
  end
  return answered and 0 or nil
end

--- Brief BQ11: the character's Careful Aim rank from the client, and the shape that answered
--- ("traits", "talentinfo", "classic"), or nil and "none". Asks the client; never in combat (the
--- caller's rule, Gear.RefreshTalents).
function Gear.ReadCarefulAim()
  local readers = {
    { "traits", traitsRank },
    { "talentinfo", talentInfoRank },
    { "classic", classicRank },
  }
  for _, reader in ipairs(readers) do
    local ok, rank = pcall(reader[2])
    if ok and rank ~= nil then
      return Gear.CleanRank(rank), reader[1]
    end
  end
  return nil, "none"
end

local function inCombat()
  local lockdown = rawget(_G, "InCombatLockdown")
  if type(lockdown) ~= "function" then
    return false
  end
  local ok, answer = pcall(lockdown)
  return ok and answer == true
end

local function now()
  local getTime = rawget(_G, "GetTime")
  if type(getTime) == "function" then
    local ok, value = pcall(getTime)
    if ok and type(value) == "number" then
      return value
    end
  end
  return nil
end

-- A moved rank moves which items are upgrades: the Keep scores go and the bags paint again, through
-- the gear change Core/Keep.lua already answers.
local function rankMoved()
  local keep = ItemTree.Keep
  if type(keep) == "table" and type(keep.OnEvent) == "function" then
    pcall(keep.OnEvent, "PLAYER_EQUIPMENT_CHANGED")
  end
end

--- Brief BQ11: reads the Careful Aim rank now, out of combat and for a hunter only. In combat it
--- marks the read pending (PLAYER_REGEN_ENABLED takes it). A character of another class holds nil.
--- Answers whether the held rank moved.
function Gear.RefreshTalents()
  local held = Gear.talent
  local classId = Gear.Player()
  if classId ~= C.HUNTER then
    held.shape, held.pending = classId == nil and "unknown class" or "not a hunter", false
    held.rank = nil
    return Gear.SetCarefulAimRank(nil)
  end
  if inCombat() then
    held.pending = true
    return false
  end
  held.pending = false
  local rank, shape = Gear.ReadCarefulAim()
  held.rank, held.shape, held.at, held.reads = rank, shape, now(), held.reads + 1
  local moved = Gear.SetCarefulAimRank(rank)
  if moved then
    rankMoved()
  end
  return moved
end

Gear.TALENT_EVENTS = {
  "PLAYER_TALENT_UPDATE",
  "TRAIT_CONFIG_UPDATED",
  "ACTIVE_TALENT_GROUP_CHANGED",
  "CHARACTER_POINTS_CHANGED",
  "SPELLS_CHANGED",
  "PLAYER_REGEN_ENABLED",
}

--- Brief BQ11: what a talent event does to the rank. Answers whether it read.
function Gear.OnTalentEvent(event)
  local held = Gear.talent
  if event == "PLAYER_REGEN_ENABLED" then
    if not held.pending then
      return false
    end
  elseif event == "SPELLS_CHANGED" then
    -- The login read, once the spells are in; the talent events take every later change.
    if held.reads > 0 and not held.pending then
      return false
    end
  elseif event == "TRAIT_CONFIG_UPDATED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
    -- Another config (or a changed one): find the node again.
    held.configId, held.nodeId, held.missed = nil, nil, nil
  end
  Gear.RefreshTalents()
  return true
end

Gear.EVENTS = { "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD" }
for _, event in ipairs(Gear.TALENT_EVENTS) do
  Gear.EVENTS[#Gear.EVENTS + 1] = event
end

-- What the event frame does: either gear event drops the worn map (and PLAYER_ENTERING_WORLD reads
-- the Careful Aim rank too); a talent event reads the rank (Gear.OnTalentEvent). Answers whether
-- the worn map was dropped, or for a talent event whether it read.
function Gear.OnEvent(event)
  if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
    Gear.Drop()
    if event == "PLAYER_ENTERING_WORLD" then
      pcall(Gear.RefreshTalents)
    end
    return true
  end
  for _, talentEvent in ipairs(Gear.TALENT_EVENTS) do
    if event == talentEvent then
      local ok, read = pcall(Gear.OnTalentEvent, event)
      return ok and read == true
    end
  end
  return false
end

-- The event frame, ItemTree's own and unparented, made once where the client can make one.
function Gear.Install()
  if Gear.frame then
    return Gear.frame
  end
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, "Frame")
  if not ok or type(frame) ~= "table" or type(frame.RegisterEvent) ~= "function" then
    return nil
  end
  for _, event in ipairs(Gear.EVENTS) do
    pcall(frame.RegisterEvent, frame, event)
  end
  pcall(frame.SetScript, frame, "OnEvent", function(_, event)
    Gear.OnEvent(event)
  end)
  Gear.frame = frame
  return frame
end

Gear.Install()

return Gear
