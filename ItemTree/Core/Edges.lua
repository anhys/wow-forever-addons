-- Edge types between nodes in the item graph, and which direction each one walks.
-- Pure Lua, no WoW API. Loaded as: local _, ItemTree = ...
local _, ItemTree = ...

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local Edges = {}
ItemTree.Edges = Edges

-- Direction relative to the root item: "up" edges answer "where does this come from",
-- "down" edges answer "what is this used for". The direction is fixed at the root and
-- never flips inside a branch (see ViewModel).
Edges.UP = "up"
Edges.DOWN = "down"

-- kind: item, spell, quest, npc, object, zone, skill, set, note
--
-- label is the English wording and doubles as its locale key: nothing draws it raw, every
-- reader asks Edges.Label (or indexes L with it), so a translated client changes the words
-- and never the key a category id or a saved filter is built from.
Edges.Types = {
  -- Crafting
  REAGENT_FOR = { id = 1, dir = "down", label = "Reagent for", source = "mined", target = "spell" },
  PRODUCED_BY = { id = 2, dir = "up", label = "Produced by", source = "mined", target = "spell" },
  CREATES = { id = 3, dir = "down", label = "Creates", source = "mined", target = "item" },
  TEACHES = { id = 4, dir = "down", label = "Teaches", source = "mined", target = "spell" },
  TAUGHT_BY = { id = 5, dir = "up", label = "Taught by", source = "mined", target = "item" },
  TOOL_FOR = { id = 6, dir = "down", label = "Tool for", source = "mined", target = "spell" },
  REQUIRES_TOOL = { id = 7, dir = "up", label = "Requires tool", source = "mined", target = "item" },
  ENCHANTS = { id = 8, dir = "down", label = "Enchants", source = "mined", target = "enchant" },
  -- Brief P5b: a class ability that consumes the item (Uses cs, docs/uses.md in ItemTree-Data):
  -- Shiny Fish Scales for the Shaman's Water Breathing. The spell is no recipe and has no page, so
  -- this is its own type rather than REAGENT_FOR; the edge carries classId and quantity. It shares
  -- REAGENT_FOR's words, so both kinds of row sit under the one "Reagent for" category.
  REAGENT_FOR_SPELL = { id = 49, dir = "down", label = "Reagent for", source = "mined", target = "spell" },
  -- Disenchanting and salvage
  DISENCHANTS_INTO = { id = 9, dir = "down", label = "Disenchants into", source = "predicted", target = "item" },
  DISENCHANTED_FROM = { id = 10, dir = "up", label = "Disenchanted from", source = "predicted", target = "item" },
  PROSPECTS_INTO = { id = 11, dir = "down", label = "Prospects into", source = "mined", target = "item" },
  MILLS_INTO = { id = 12, dir = "down", label = "Mills into", source = "mined", target = "item" },
  -- Locks and containers
  OPENS = { id = 13, dir = "down", label = "Opens", source = "mined", target = "item" },
  OPENED_BY = { id = 14, dir = "up", label = "Opened by", source = "mined", target = "item" },
  CONTAINS = { id = 15, dir = "down", label = "Contains", source = "collected", target = "item" },
  CONTAINED_IN = { id = 16, dir = "up", label = "Contained in", source = "collected", target = "item" },
  -- Quests
  STARTS_QUEST = { id = 17, dir = "down", label = "Starts quest", source = "mined", target = "quest" },
  QUEST_OBJECTIVE = { id = 18, dir = "down", label = "Quest objective", source = "collected", target = "quest" },
  QUEST_REWARD = { id = 19, dir = "up", label = "Quest reward", source = "collected", target = "quest" },
  QUEST_PROVIDED = { id = 20, dir = "up", label = "Provided by quest", source = "collected", target = "quest" },
  -- The other side of the four above: what a quest itself asks for, hands back and is started
  -- by. No build states any of that (it is server side data), so these only ever come from the
  -- hand maintained table in Data/curated/Quests.lua, through Core/Quests.lua.
  QUEST_REQUIRES = { id = 35, dir = "up", label = "Requires", source = "curated", target = "item" },
  QUEST_REWARDS = { id = 36, dir = "down", label = "Rewards", source = "curated", target = "item" },
  QUEST_STARTED_BY = { id = 37, dir = "up", label = "Started by", source = "curated", target = "item" },
  -- Sources
  DROPPED_BY = { id = 21, dir = "up", label = "Dropped by", source = "collected", target = "npc" },
  LOOTED_FROM = { id = 22, dir = "up", label = "Looted from", source = "collected", target = "object" },
  SOLD_BY = { id = 23, dir = "up", label = "Sold by", source = "collected", target = "npc" },
  GATHERED_FROM = { id = 24, dir = "up", label = "Gathered from", source = "collected", target = "object" },
  FISHED_FROM = { id = 25, dir = "up", label = "Fished from", source = "collected", target = "zone" },
  SKINNED_FROM = { id = 26, dir = "up", label = "Skinned from", source = "collected", target = "npc" },
  -- Skills, sets, requirements
  REQUIRES_SKILL = { id = 27, dir = "up", label = "Requires", source = "mined", target = "skill" },
  BELONGS_TO_SKILL = { id = 28, dir = "up", label = "Profession", source = "mined", target = "skill" },
  PART_OF_SET = { id = 29, dir = "down", label = "Part of set", source = "mined", target = "set" },
  SET_MEMBER = { id = 30, dir = "down", label = "Set member", source = "mined", target = "item" },
  USED_BY_SPELL = { id = 31, dir = "down", label = "Used by", source = "mined", target = "spell" },
  REAGENT = { id = 33, dir = "up", label = "Reagent", source = "mined", target = "item" },
  LEARNED_FROM_TRAINER = { id = 34, dir = "up", label = "Trainer", source = "mined", target = "skill" },
  -- What comes off a CREATURE: the down side of the three source edges above, which is the whole
  -- of what a creature page lists (brief E57). Only the shipped Classic Era table states any of
  -- them (Core/EraSources.lua CREATURE_LOOT), and each is its own type rather than one type with
  -- three groups, because the type is the word the row's own column says: under the "All" row
  -- every kind of loot is in one list and "Drop", "Skinned" and "Pickpocketed" are what tell them
  -- apart. A herbable or minable creature, when Forever turns out to have one, is a fourth and a
  -- fifth here and one entry each in CREATURE_LOOT.
  CREATURE_DROPS = { id = 38, dir = "down", label = "Drops", source = "collected", target = "item" },
  CREATURE_SKINNED = { id = 39, dir = "down", label = "Skinned", source = "collected", target = "item" },
  CREATURE_POCKETED = { id = 40, dir = "down", label = "Pickpocketed", source = "collected", target = "item" },
  -- What a VENDOR sells (brief N2): SOLD_BY read from the other end, npc to item. The shipped
  -- Classic Era table states it for its vendor rows (Core/EraSources.lua VendorIndex) and the
  -- collector states it for every merchant window the player has opened, with the price.
  SELLS = { id = 41, dir = "down", label = "Sells", source = "collected", target = "item" },
  -- The quests a creature or a vendor starts and ends (brief N3), from the shipped Classic Era
  -- table's quest giver lists (Core/EraSources.lua QuestGiverEdges). Server side facts, like the
  -- rest of an NPC's page. The ids leave room below them for the edge types other briefs add.
  GIVES_QUEST = { id = 46, dir = "down", label = "Starts", source = "collected", target = "quest" },
  TAKES_QUEST = { id = 47, dir = "down", label = "Ends", source = "collected", target = "quest" },
  -- What a ZONE holds (brief Z1): every source row that states the zone, read from the zone's end,
  -- zone to item. One type for every kind of source, because the group the row is filed under and
  -- the up type it carries in `as` (the words its columns are drawn in) already say which kind it
  -- is. The id leaves a gap below it for the types other briefs add beside it.
  ZONE_HOLDS = { id = 48, dir = "down", label = "Here", source = "collected", target = "item" },
  -- What a TRAINER teaches (brief P6b): the recipe spells the shipped Classic Era table's tr list
  -- names for a trainer's name, npc to spell (Core/EraSources.lua TeachesEdges). Its own type
  -- rather than TEACHES, which is an item's Used by edge to the recipe it teaches: a type is drawn
  -- in exactly one view, and this one is drawn in the trainer's Teaches tab alone.
  TRAINER_TEACHES = { id = 50, dir = "down", label = "Teaches", source = "collected", target = "spell" },
  -- What a Classic Era chest or other looted OBJECT holds (brief OL1): LOOTED_FROM read from the
  -- object's end, object to item, from the shipped table's "Found in" rows (Core/EraSources.lua
  -- OBJECT_LOOT). Drawn in the object's Loot tab alone, beside a creature's loot types.
  OBJECT_CONTAINS = { id = 51, dir = "down", label = "Contains", source = "collected", target = "item" },
  -- Curated
  COMMUNITY_NOTE = { id = 32, dir = "down", label = "Community note", source = "curated", target = "note" },
}

local byId = {}
for name, def in pairs(Edges.Types) do
  def.name = name
  byId[def.id] = def
end

-- The four views the window draws. A view is a filter over the two directions above and never
-- a direction of its own: no edge changes dir here, so Core/Chain.lua, Core/Collector.lua and
-- Core/Sources.lua keep branching on direction and keep working. Two views walk down and two
-- walk up, so a view is never worked out from a direction alone.
--   uses        every down edge but the disenchant results: what this is used for.
--   sources     the up edges that answer "where do I get or learn this".
--   requires    the up edges that answer "what does this need", plus the requirement rows
--               Core/Graph.lua works out (level, class, skill), which appear in no other view.
--   disenchants what a rule says this turns into at an enchanting table. A prediction rather
--               than a use, and on an armour piece it used to bury the real uses under it.
Edges.USES = "uses"
Edges.SOURCES = "sources"
Edges.REQUIRES = "requires"
Edges.DISENCHANTS = "disenchants"
Edges.VIEWS = { Edges.USES, Edges.SOURCES, Edges.REQUIRES, Edges.DISENCHANTS }

-- The two views a CREATURE root has instead of those four (brief E57). A creature is not made of
-- anything, needs nothing and cannot be disenchanted, so the four questions above are four empty
-- tabs on it; the two a player really asks are "what comes off this thing" and "where is it".
--
--   loot  every down edge the shipped Classic Era table states about the creature, in the standard
--         category list and row list the window draws every other view in.
--   map   one map of where it is known, filling the space both of those lists take. It is a view
--         with no rows at all on purpose: InView answers false for every type, so the view model
--         holds no categories and the pane draws the map in their place.
Edges.LOOT = "loot"
Edges.MAP = "map"
Edges.CREATURE_VIEWS = { Edges.LOOT, Edges.MAP }

-- Brief N2: an NPC's page, of which a creature's is one case. sells is what a vendor sells, from
-- the shipped Classic Era table and from the merchant windows the player has opened, in the
-- standard category and row lists. NPC_VIEWS is every view an npc root can have, in the order the
-- tabs are drawn; Core/ViewModel.lua ViewsFor hands a root the ones its data can fill (a creature
-- that sells nothing keeps CREATURE_VIEWS, a vendor that is no creature has VENDOR_VIEWS).
Edges.SELLS = "sells"
-- Brief N3: the quests an NPC starts and ends, a view of its own between what it sells and where
-- it stands. ViewsFor hands it out only where the table lists a quest for the name.
Edges.QUESTS = "quests"
-- Brief P6b: the recipes a trainer teaches, first where a name has any, so a trainer's page opens
-- on the answer a player went there for. ViewsFor hands it out only where the table's tr list
-- names the trainer.
Edges.TEACHES_VIEW = "teaches"
Edges.NPC_VIEWS = { Edges.TEACHES_VIEW, Edges.LOOT, Edges.SELLS, Edges.QUESTS, Edges.MAP }
Edges.VENDOR_VIEWS = { Edges.SELLS }

-- The one view a Classic Era OBJECT root has where the shipped table places it on a map (brief
-- D7): a herb, a vein, a fishing pool or a chest. It is not in VIEWS_BY_KIND below, because an
-- object key is also every live object the collector records, and those keep the four item views:
-- Core/ViewModel.lua ViewsFor asks the table and hands this out only for an object whose name has
-- pins.
Edges.NODE_VIEWS = { Edges.MAP }

-- Brief OL1 (owner, 2026-10-11: "we probably can just make it a loot tab for the node"): a chest or
-- another looted object the table files under category 11 takes the creature's Loot tab, the items
-- it holds, in front of its Map; one with no pins has the Loot tab alone. A herb, a vein and a
-- fishing pool keep NODE_VIEWS: their loot is the item page that led to them.
Edges.OBJECT_VIEWS = { Edges.LOOT, Edges.MAP }
Edges.OBJECT_LOOT_VIEWS = { Edges.LOOT }

-- Brief EO1: a world object the table says starts or ends quests (a wanted poster, a sign) takes the
-- NPC's Quests tab, in NPC_VIEWS' order: after its Loot tab where it has loot, before its Map where it
-- has pins. Core/ViewModel.lua ViewsFor picks one of these four.
Edges.OBJECT_QUEST_VIEWS = { Edges.QUESTS, Edges.MAP }
Edges.OBJECT_QUEST_ONLY_VIEWS = { Edges.QUESTS }
Edges.OBJECT_LOOT_QUEST_VIEWS = { Edges.LOOT, Edges.QUESTS, Edges.MAP }
Edges.OBJECT_LOOT_QUEST_ONLY_VIEWS = { Edges.LOOT, Edges.QUESTS }

-- Brief OL1: what an openable ITEM holds (a chest, a clam, a lockbox), from the shipped table's
-- container rows and the containers the player has opened. An item with any takes CONTAINER_VIEWS,
-- the four item views with Contains in the Disenchants slot: the window draws five view tabs at
-- most, and only a weapon or an armour piece is ever disenchanted (Core/Data.lua DisenchantBand),
-- which an openable item never is.
Edges.CONTAINS_VIEW = "contains"
Edges.CONTAINER_VIEWS = { Edges.USES, Edges.SOURCES, Edges.REQUIRES, Edges.CONTAINS_VIEW }

-- The two views a ZONE root has (brief Z1): here is what Classic Era placed there, by kind, in the
-- standard category and row lists, and map is the zone's own art with the pins of the row the
-- player picked on the here list. Not in VIEWS_BY_KIND, for the reason NODE_VIEWS is not: only the
-- shipped table can say whether a zone key names an area, so Core/ViewModel.lua ViewsFor asks it.
Edges.HERE = "here"
Edges.ZONE_VIEWS = { Edges.HERE, Edges.MAP }

-- Which set of views a root of one node kind has. A kind this says nothing about has the four
-- above, so a node kind added later cannot silently lose its tabs.
--
-- It is keyed by the node KIND and not by the node, because a kind is all Core/Edges.lua can see:
-- an npc key can be a creature or a vendor, and only the shipped table can say which, so
-- Core/ViewModel.lua ViewsFor asks this and then asks the table. That is the seam, and this is the
-- list each answer draws from.
Edges.VIEWS_BY_KIND = { npc = Edges.NPC_VIEWS }

local VIEW_DIRECTION = {
  [Edges.USES] = Edges.DOWN,
  [Edges.SOURCES] = Edges.UP,
  [Edges.REQUIRES] = Edges.UP,
  [Edges.DISENCHANTS] = Edges.DOWN,
  [Edges.LOOT] = Edges.DOWN,
  [Edges.SELLS] = Edges.DOWN,
  [Edges.QUESTS] = Edges.DOWN,
  [Edges.TEACHES_VIEW] = Edges.DOWN,
  [Edges.MAP] = Edges.DOWN,
  [Edges.HERE] = Edges.DOWN,
  [Edges.CONTAINS_VIEW] = Edges.DOWN,
}

-- The views a node kind's root can be drawn in, as the list the tab strip is built from. Pure.
function Edges.ViewsFor(kind)
  local views = type(kind) == "string" and Edges.VIEWS_BY_KIND[kind] or nil
  if type(views) == "table" and #views > 0 then
    return views
  end
  return Edges.VIEWS
end

-- Which of the two up views a type belongs to, read by edge NAME so a type is filed by what it
-- is called rather than by its id, its label or the group a row happened to be written with.
-- Every up type is named in exactly one of the two sets and tests/spec/edges_spec.lua sweeps
-- Edges.Types for it, so a type added later cannot fall through without a tab being chosen for
-- it. InView still files an unnamed up type under sources, because "where do I get this" is the
-- question that tab answers for anything that is not a requirement.
Edges.REQUIREMENT_TYPES = {
  REAGENT = true,
  REQUIRES_TOOL = true,
  REQUIRES_SKILL = true,
  BELONGS_TO_SKILL = true,
  QUEST_REQUIRES = true,
}

Edges.SOURCE_TYPES = {
  PRODUCED_BY = true,
  TAUGHT_BY = true,
  OPENED_BY = true,
  DISENCHANTED_FROM = true,
  QUEST_REWARD = true,
  QUEST_PROVIDED = true,
  QUEST_STARTED_BY = true,
  DROPPED_BY = true,
  LOOTED_FROM = true,
  SOLD_BY = true,
  GATHERED_FROM = true,
  FISHED_FROM = true,
  SKINNED_FROM = true,
  CONTAINED_IN = true,
  LEARNED_FROM_TRAINER = true,
}

-- The same decision on the down side, now that it has two views of its own. Only the predicted
-- disenchant results leave "Used by": they are what a rule says an armour piece turns into and
-- not something the piece is used for, and on most armour they were the whole of that tab, so
-- a count beside "Used by" promised uses and delivered a guess. "Disenchanted from", the up
-- side a dust or a shard answers with, is a source and stays in SOURCE_TYPES.
--
-- Every down type this does not name is drawn under "uses", the way an up type nobody has
-- decided on is drawn under "sources": a type added later cannot fall out of the window.
Edges.DISENCHANT_TYPES = {
  DISENCHANTS_INTO = true,
}

-- The down types a CREATURE's Loot tab draws, and which therefore never appear under "Used by".
-- They only ever leave an npc node, so an item's Used by tab could not have held one anyway; the
-- set is named all the same, because "every down type nobody has decided on is a use" is the rule
-- that keeps a later type in the window, and a creature's loot is the one down type that is not a
-- use of anything.
Edges.LOOT_TYPES = {
  CREATURE_DROPS = true,
  CREATURE_SKINNED = true,
  CREATURE_POCKETED = true,
  -- Brief OL1: what a chest holds, on the object's own Loot tab.
  OBJECT_CONTAINS = true,
}

-- The down types a vendor's Sells tab draws (brief N2), which for the same reason as LOOT_TYPES
-- never appear under "Used by": selling an item is not a use of it.
Edges.SELLS_TYPES = {
  SELLS = true,
}

-- The down types an NPC's Quests tab draws (brief N3), which never appear under "Used by" either:
-- starting a quest is not a use of anything.
Edges.QUEST_GIVER_TYPES = {
  GIVES_QUEST = true,
  TAKES_QUEST = true,
}

-- The down type a zone's Here tab draws (brief Z1), which is not a use of anything either.
Edges.HERE_TYPES = {
  ZONE_HOLDS = true,
}

-- The down type a trainer's Teaches tab draws (brief P6b). Teaching a recipe is not a use of the
-- trainer, so it never appears under "Used by" either.
Edges.TRAINER_TYPES = {
  TRAINER_TEACHES = true,
}

-- The down type an openable item's Contains tab draws (brief OL1). It is still a use while the item
-- has no Contains tab (Core/ViewModel.lua keeps a recorded open under Used by there), so unlike the
-- sets above it is not taken out of the uses view here.
Edges.CONTAINS_TYPES = {
  CONTAINS = true,
}

-- The same edges walking up: what a dust or a shard says it came from. They belong to the sources
-- view (SOURCE_TYPES names DISENCHANTED_FROM, and this does not change that), so this set is not
-- a view of its own. It is here so a reader that wants "every predicted enchanting edge" can name
-- both sides rather than one side and a hand written string: Core/Chain.lua, which follows
-- neither direction, reads the pair.
Edges.DISENCHANT_SOURCE_TYPES = {
  DISENCHANTED_FROM = true,
}

-- The direction a view walks, or nil for anything that is not a view key.
function Edges.ViewDirection(view)
  return VIEW_DIRECTION[view]
end

-- The view a plain direction stands for, for a caller that still holds one: down is the uses
-- view and up is the sources view, which is where an up tab landed before requires existed.
-- Neither of the two later views is reachable this way, on purpose: a direction says nothing
-- about which of the two views that walk it was wanted, and uses and sources are the pair the
-- window drew when a direction was all a caller had.
function Edges.ViewOf(direction)
  if direction == Edges.UP then
    return Edges.SOURCES
  end
  return Edges.USES
end

-- Whether one edge type is drawn in a view. Takes the type table or its name.
function Edges.InView(nameOrDef, view)
  local def = type(nameOrDef) == "table" and nameOrDef or Edges.Types[nameOrDef]
  local direction = VIEW_DIRECTION[view]
  if not def or not direction or def.dir ~= direction then
    return false
  end
  if direction == Edges.DOWN then
    if view == Edges.DISENCHANTS then
      return Edges.DISENCHANT_TYPES[def.name] == true
    end
    if view == Edges.LOOT then
      return Edges.LOOT_TYPES[def.name] == true
    end
    if view == Edges.SELLS then
      return Edges.SELLS_TYPES[def.name] == true
    end
    if view == Edges.QUESTS then
      return Edges.QUEST_GIVER_TYPES[def.name] == true
    end
    if view == Edges.HERE then
      return Edges.HERE_TYPES[def.name] == true
    end
    if view == Edges.TEACHES_VIEW then
      return Edges.TRAINER_TYPES[def.name] == true
    end
    if view == Edges.CONTAINS_VIEW then
      return Edges.CONTAINS_TYPES[def.name] == true
    end
    -- The map draws no rows at all: it is one rectangle where the two lists go, so the view model
    -- holds no categories and there is nothing for a type to be filed under.
    if view == Edges.MAP then
      return false
    end
    return Edges.DISENCHANT_TYPES[def.name] ~= true
      and Edges.LOOT_TYPES[def.name] ~= true
      and Edges.SELLS_TYPES[def.name] ~= true
      and Edges.QUEST_GIVER_TYPES[def.name] ~= true
      and Edges.HERE_TYPES[def.name] ~= true
      and Edges.TRAINER_TYPES[def.name] ~= true
  end
  if view == Edges.REQUIRES then
    return Edges.REQUIREMENT_TYPES[def.name] == true
  end
  return Edges.REQUIREMENT_TYPES[def.name] ~= true
end

function Edges.Get(name)
  return Edges.Types[name]
end

-- The words for an edge type, translated. Takes the type table or its name. The one place
-- an edge's wording comes from, so a breadcrumb and a category never disagree.
function Edges.Label(nameOrDef)
  local def = type(nameOrDef) == "table" and nameOrDef or Edges.Types[nameOrDef]
  if not def or type(def.label) ~= "string" then
    return nil
  end
  return L[def.label]
end

function Edges.ById(id)
  return byId[id]
end

-- Edge types that are only ever known from the server side, so they carry an
-- Unverified badge until the collector or a curated note confirms them.
function Edges.IsServerSide(def)
  return def.source == "collected"
end

-- Sorted list of edge type names, stable for UI menus and tests.
function Edges.Names()
  local names = {}
  for name in pairs(Edges.Types) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

return Edges
