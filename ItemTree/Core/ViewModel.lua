-- Turns the graph into the flat row list the UI renders. Pure Lua, no WoW API.
--
-- The UI never walks the graph: it asks for Rows() and draws what it gets. Expansion is
-- lazy, so children are computed through Graph.Children the first time a row is opened
-- and then cached per row key. Only the root's direct edges are computed up front, and
-- only so the categories can be built.
--
-- The window has four views and the graph has two directions. A view is chosen once, at the
-- root, and fixes the direction every branch below it walks: "Used by" is every down edge but
-- one, "Sources" the up edges that answer "where do I get or learn this", "Requires" the up
-- edges that answer "what does this need" plus the requirement rows Core/Graph.lua works out,
-- and "Disenchants into" the predicted results, which walk down as well and used to sit under
-- "Used by". Core/Edges.lua owns that split (Edges.InView); nothing here decides it type by
-- type, so the two views that share the down direction are told apart by their view key alone.
--
-- The view only filters the root's own categories. Below them a branch keeps the whole
-- direction, so opening a recipe under Sources still shows what it is made of, which is the
-- chain a player is reading. In the Sources view a row also carries the source facts
-- Core/Sources.lua works out, so the tree answers "where do I get this" on its own.
--
-- In the Used by view, opts.mergeCrafts draws a craft and the one item it makes as a single row
-- for that item (see _AppendMerged), which is what settings.mergeCrafts turns on by default.
-- Every row it produces is an addition: with the option off this file builds exactly what it
-- built before merging existed. One edge type is never merged whatever the setting says
-- (NEVER_MERGED_EDGES, brief E30): a tool's "Tool for" list.
--
-- EXPERIMENTAL (brief E25): opts.craftIngredients is the same shape of option for what a craft
-- is made of. Every craft row in that view carries row.ingredients and row.tools, and in a mode
-- that asks for the group the craft's children gain a muted group row as their first child. It
-- is one block of this file, every entry point into it is marked E25, and "off" runs none of it.
local _, ItemTree = ...

local Data = ItemTree.Data
local Edges = ItemTree.Edges
local Graph = ItemTree.Graph
local Diff = ItemTree.Diff
local Confidence = ItemTree.Confidence
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local ViewModel = {}
ItemTree.ViewModel = ViewModel

local EMPTY = {}

-- Brief V1: the provenance Core/ForeverVendors.lua stamps on the client's own vendor rows. The
-- same string rather than a read of that file, which loads after this one.
local CLIENT_PROVENANCE = "client"

-- What the tree asks of a walk, on top of the options the player set. Both are asked for rather
-- than always emitted (see Core/Graph.lua), and for the same reason: each is a row in a tree and
-- never a step in a chain. The trainer row ends on a skill, and a historical row out of the
-- shipped Classic Era table states what another game used to do, so a route through it is not a
-- route a player can walk. Brief CH1: its quest rows alone are (Core/Graph.lua Graph.ChainQuestEdge).
local WALK_OPTS = { includeTrainer = true, includeHistorical = true }

-- Brief GS3: the Sources view's walk of its own root, and no other walk, also asks for the
-- guessed sources (Core/GuessSources.lua). A guess is a row in that one list and never a step in
-- a chain, so a nested row, a chevron test, a count of another view and every other tab walk
-- with WALK_OPTS above and never ask the module anything.
local GUESS_WALK_OPTS =
  { includeTrainer = true, includeHistorical = true, includeGuessSources = true, showGuessSources = true }

-- Brief F155 ("Hide other faction data"): a walk's options with the side the setting hides from
-- (opts.hideSide, which Core/Graph.lua Graph.WithoutOtherSide reads), one copy per base table and
-- side, made once and kept; the base itself while nothing is hidden, so with the setting off (or no
-- side known) every walk is exactly the walk it was before.
local sidedOpts = {}
local function sided(base, side)
  if side == nil then
    return base
  end
  local bySide = sidedOpts[base]
  if not bySide then
    bySide = {}
    sidedOpts[base] = bySide
  end
  local held = bySide[side]
  if not held then
    held = {}
    for key, value in pairs(base) do
      held[key] = value
    end
    held.hideSide = side
    bySide[side] = held
  end
  return held
end

-- Whether guessed sources are drawn under these options: never while predictions are hidden,
-- and otherwise as the "Show guessed sources" setting says. A caller that states
-- showGuessSources is taken at its word; one that does not (the window passes only the options
-- it has always passed) is answered from the saved setting, which is on by default. Pure over
-- opts and ItemTree.db.
local function guessSourcesShown(opts)
  opts = opts or EMPTY
  if opts.showPredicted == false then
    return false
  end
  if opts.showGuessSources ~= nil then
    return opts.showGuessSources ~= false
  end
  local db = ItemTree.db
  local settings = type(db) == "table" and db.settings or nil
  if type(settings) == "table" and settings.showGuessSources == false then
    return false
  end
  return true
end
ViewModel.GuessSourcesShown = guessSourcesShown

-- Copied from UI/Theme.lua Theme.rules and Theme.sizes. Core never requires UI at
-- runtime, so the two numbers live in both files; keep them in step.
ViewModel.DEFAULTS = {
  maxDepth = 6, -- ITEMTREE_LIST_DEPTH_MAX
  groupLimit = 8, -- GROUP_CHILD_LIMIT
  defaultDepth = 2, -- DEFAULT_EXPAND_DEPTH: depth 0 and 1 open, depth 2 closed
  showPredicted = true,
  -- Change rows under a row that this build changed, and the Changed badge a category
  -- raises for them. Off leaves the rows out entirely, so a player who only wants the
  -- graph never pays for the diff.
  showChanges = true,
  badgesNew = true,
  badgesChanged = true,
  filter = nil, -- a category id, from Categories()
  density = "default",
  -- opts.now is optional and is passed through for callers that need a fixed clock.
  --
  -- opts.mergeCrafts is deliberately not here. It is the one option whose absence has to mean
  -- off: a caller that states nothing gets the rows this file built before merging existed, and
  -- the window turns it on by passing it from settings.mergeCrafts, which defaults to true.
  --
  -- opts.craftIngredients is not here either, and for the same reason: absence has to mean "off", and
  -- off has to build exactly the rows this file built before the setting existed.
  --
  -- opts.totalCounts (brief TC1) is not here either: absent or false, every count is the count for
  -- one craft, which is the tree this file built before the footer's Total counts box existed.
}

-- EXPERIMENTAL (brief E25, extended by brief E30): the four ways a craft row in the Used by view
-- can show what the craft is made of, plus "all", which draws three of them together, and "off",
-- which is the tree as it was before any of this. The owner asked for all four so he can flip
-- between them in game and keep one; the losers are deleted, so every mode's code is kept
-- separable and marked.
--
--   off      no ingredients are worked out at all and no row changes
--   all      the default: the tooltip block, the group and the item column's card at once
--   tooltip  the row's tooltip gains an Ingredients block
--   group    the row's children gain a muted "Ingredients (n)" group as their first child
--   strip    UI/Tree.lua draws a strip of icons under the row, behind a small button
--   card     UI/InfoPanel.lua draws a Recipe card while the row is hovered
ViewModel.CRAFT_INGREDIENT_MODES = { "off", "all", "tooltip", "group", "strip", "card" }

local CRAFT_INGREDIENT_MODES = {}
for _, mode in ipairs(ViewModel.CRAFT_INGREDIENT_MODES) do
  CRAFT_INGREDIENT_MODES[mode] = true
end

-- The four surfaces a mode can switch on, which is what every drawing site asks about rather
-- than comparing the mode's own word: the block on a row's tooltip, the group under its chevron,
-- the strip of icons under the row and the Recipe card in the item column. Adding a mode is then
-- a line in the table below and nothing else, and "does the tooltip block show" has one answer
-- in one place instead of one per file (brief E30 task 4).
ViewModel.CRAFT_INGREDIENT_SURFACES = { "tooltip", "group", "strip", "card" }

-- What each mode switches on. "all" is every surface but the strip: the strip is the one that
-- moves the row's own art about and adds a row under it, so it stays a choice of its own.
local CRAFT_INGREDIENT_SHOWS = {
  off = {},
  all = { tooltip = true, group = true, card = true },
  tooltip = { tooltip = true },
  group = { group = true },
  strip = { strip = true },
  card = { card = true },
}

-- The mode a caller asked for, or "off" for anything else: nil, a word from a later build, a
-- saved variable somebody typed into. Pure, and the one place the six words are checked, so
-- the window passes the setting straight through and Core decides what it means.
function ViewModel.CraftIngredients(mode)
  if type(mode) == "string" and CRAFT_INGREDIENT_MODES[mode] then
    return mode
  end
  return "off"
end

-- Whether a mode draws one of the four surfaces. Pure, and the one place the rule lives: Core,
-- UI/Tree.lua and UI/InfoPanel.lua all ask this rather than reading the mode's word themselves.
function ViewModel.CraftIngredientShows(mode, surface)
  local shows = CRAFT_INGREDIENT_SHOWS[ViewModel.CraftIngredients(mode)]
  if not shows then
    return false
  end
  return shows[surface] == true
end

-- The same answer for every surface at once, as a table of the caller's own: a reader that wants
-- to hold a mode's capabilities rather than ask four times gets a fresh table, so nothing can
-- write into the rule above.
function ViewModel.CraftIngredientCapabilities(mode)
  local out = {}
  for _, surface in ipairs(ViewModel.CRAFT_INGREDIENT_SURFACES) do
    out[surface] = ViewModel.CraftIngredientShows(mode, surface)
  end
  return out
end

-- Edge types a craft is never merged into its product on, whatever settings.mergeCrafts says.
--
-- Owner's decision (brief E30): a tool's "Tool for" list is left alone. Merging it costs facts
-- and buys almost nothing there. Philosopher's Stone's nineteen transmutes are named after what
-- comes out, so merged the row no longer says what goes in and two pairs of rows read
-- identically; Arclight Spanner and Blacksmith Hammer between them drop 134 skill lines. The
-- reagent categories and "Teaches", where the craft's name and the item's name are the same
-- words, merge exactly as they always have.
ViewModel.NEVER_MERGED_EDGES = { TOOL_FOR = true }

-- Whether the merge may fold a craft reached by this edge into the item it makes. Takes the edge
-- type table or its name, and answers true for anything unnamed, so an edge type added later
-- merges the way every other craft edge does. Pure.
function ViewModel.MergesEdge(nameOrDef)
  local name = type(nameOrDef) == "table" and nameOrDef.name or nameOrDef
  if type(name) ~= "string" then
    return true
  end
  return ViewModel.NEVER_MERGED_EDGES[name] ~= true
end

-- Skill line to Assets key. Mirrors UI/Assets.lua Assets.skillGlyphs; Core only ever
-- names the key, the UI resolves it to a texture.
ViewModel.SKILL_ICONS = {
  [171] = "CAT_ALCHEMY",
  [164] = "CAT_BLACKSMITHING",
  [202] = "CAT_ENGINEERING",
  [333] = "CAT_ENCHANTING",
  [197] = "CAT_TAILORING",
  [165] = "CAT_LEATHERWORKING",
  [186] = "CAT_MINING",
  [182] = "CAT_HERBALISM",
  [393] = "CAT_SKINNING",
  [356] = "CAT_FISHING",
  [185] = "CAT_COOKING",
  [129] = "CAT_FIRSTAID",
}

-- What kind of creature a source row names, to the Assets key it draws. The same idea as
-- SKILL_ICONS above: Core names the key and the UI resolves it to a texture, so no file under
-- Core ever knows a path.
--
-- Every creature row used to wear one generic glyph, which said nothing at all on a list of
-- twenty. The type tier is the whole classification, eleven ids, and the family tier is the
-- finer answer for a beast (a wolf glyph rather than a paw print). The family wins where there
-- is one, the type is the fallback, and a row whose source states neither keeps the glyph its
-- node kind has always had. A family with no key here falls back to its type on purpose: the
-- source's own family list runs past the icons this build ships.
ViewModel.CREATURE_ICONS = {
  [1] = "CREATURE_BEAST",
  [2] = "CREATURE_DRAGONKIN",
  [3] = "CREATURE_DEMON",
  [4] = "CREATURE_ELEMENTAL",
  [5] = "CREATURE_GIANT",
  [6] = "CREATURE_UNDEAD",
  [7] = "CREATURE_HUMANOID",
  [8] = "CREATURE_CRITTER",
  [9] = "CREATURE_MECHANICAL",
  [10] = "CREATURE_UNKNOWN",
  [11] = "CREATURE_TOTEM",
}

ViewModel.CREATURE_FAMILY_ICONS = {
  [1] = "CREATURE_FAMILY_WOLF",
  [2] = "CREATURE_FAMILY_CAT",
  [3] = "CREATURE_FAMILY_SPIDER",
  [4] = "CREATURE_FAMILY_BEAR",
  [5] = "CREATURE_FAMILY_BOAR",
  [6] = "CREATURE_FAMILY_CROCOLISK",
  [7] = "CREATURE_FAMILY_CARRION_BIRD",
  [8] = "CREATURE_FAMILY_CRAB",
  [9] = "CREATURE_FAMILY_GORILLA",
  [11] = "CREATURE_FAMILY_RAPTOR",
  [12] = "CREATURE_FAMILY_TALLSTRIDER",
  [15] = "CREATURE_FAMILY_FELHUNTER",
  [20] = "CREATURE_FAMILY_SCORPID",
  [21] = "CREATURE_FAMILY_TURTLE",
  [24] = "CREATURE_FAMILY_BAT",
  [25] = "CREATURE_FAMILY_HYENA",
  [26] = "CREATURE_FAMILY_BIRD_OF_PREY",
  [27] = "CREATURE_FAMILY_WIND_SERPENT",
}

-- The icon key one creature kind draws, or nil where nothing states a kind at all. Pure.
function ViewModel.CreatureIcon(creature)
  if type(creature) ~= "table" then
    return nil
  end
  return ViewModel.CREATURE_FAMILY_ICONS[creature.family] or ViewModel.CREATURE_ICONS[creature.type]
end

-- The creature display id a row's own portrait would be drawn from, or nil where the source
-- states none. A CreatureDisplayInfo id the shipped table checked against this build before it
-- shipped it (Core/EraSources.lua DisplayOf), and a plain number here: Core asks the client for
-- nothing, decides nothing about cost and draws nothing. The row carries it and UI/Tree.lua
-- decides whether a portrait is worth asking for, which is where the setting and the queue are.
-- Pure.
function ViewModel.CreaturePortrait(creature)
  if type(creature) ~= "table" then
    return nil
  end
  local display = creature.display
  if type(display) ~= "number" or display <= 0 or display ~= math.floor(display) then
    return nil
  end
  return display
end

-- Brief PT2 (owner QA 2026-10-20 item 287: Ephemeral Choker 270227's Faldrim Anvilmar 261306 wore
-- the glyph): whether an npc row whose edge states no display id looks one up (ViewModel.EraPortrait,
-- then ForeverPortrait). A recorded row does (brief BQ25b), and so does a guess: Core/GuessSources.lua
-- names its creature and never its model, and the dedupeName it carries for the merge kept every
-- guess out until now.
-- Brief PT2b (the owner's choice A, 2026-10-20: every source row with a known display id draws its
-- portrait): a Classic Era row looks one up as well. Its own edge states a display only for a creature
-- category (Core/EraSources.lua E:_RowEdge), so a Sold by row on a Classic vendor's page wore the glyph
-- although the table has carried the vendor's display since brief N3, and its page drew it. So every
-- edge that names a creature (an npc key) answers true; no edge, or any other key, false. Pure.
function ViewModel.BorrowsPortrait(edge, key)
  return type(edge) == "table" and Graph.Kind(key) == "npc"
end

-- Every category that is not a profession, keyed by its group key. The key is the English
-- wording and its own locale key: L[key] is what the tree draws, so a translated client changes
-- the words and never the id. The sidebar and the saved filter hold these ids, so they must not
-- drift. tests/spec/locale_spec.lua lists the keys, which is how the sweep sees them.
local GROUP_IDS = {
  ["Quests"] = "quests",
  ["Requirements"] = "requirements",
  -- Brief TB10.
  ["Class use"] = "classuse",
  ["Disenchants into"] = "disenchant",
  ["Disenchanted from"] = "disenchantedfrom",
  ["Item set"] = "set",
  ["Tool for"] = "tools",
  ["Opens"] = "opens",
  ["Opened by"] = "openedby",
  ["Teaches"] = "teaches",
  ["Taught by"] = "taughtby",
  ["Sold by"] = "soldby",
  ["Drops from"] = "drops",
  ["Gathered from"] = "gathered",
  -- Brief D6: a Classic Era vein is a node row under "Mined from" (a herb's is under "Gathered
  -- from", beside the collector's own sightings), and its zones are the rows it opens onto.
  ["Mined from"] = "minedfrom",
  ["Fished from"] = "fished",
  ["Contained in"] = "contained",
  ["Contains"] = "contains",
  ["Community"] = "community",
  ["Reagents"] = "reagents",
  -- Item combines: a create item spell cast by USING an item, with no profession behind it.
  -- Both sides of one land here, the recipe walking up and the reagent walking down, so a
  -- player reading either way sees the same category rather than the generic bucket a recipe
  -- with no skill line used to fall into.
  ["Item use"] = "itemuse",
  -- Brief P5b: the class spells an item is consumed by (Shiny Fish Scales for Water Breathing), and
  -- any recipe with no profession to be filed under, which falls back to the edge's own words.
  ["Reagent for"] = "reagentfor",
  -- The requires side of the tools a recipe asks for. "Tool for" is the down side, the recipes
  -- an item is a tool for, and the two are different questions, so they are different ids: a
  -- saved filter set on one never selects the other.
  ["Tools"] = "requirestools",
  -- A recipe nothing teaches is learnt from a trainer, which is a source rather than a thing.
  ["Trainer"] = "trainer",
  -- A quest's own three groups, which only ever appear on a quest node. "Requires" is the
  -- quest's turn in and is a different group from an item's "Requirements", which is the level
  -- and skill it asks of the player; the ids keep them apart in a saved filter.
  ["Started by"] = "queststartedby",
  ["Requires"] = "questrequires",
  ["Rewards"] = "questrewards",
  -- The kinds of source no live sighting has ever produced, which the shipped Classic Era table
  -- states (Core/EraSources.lua). A boss drop, a creature drop, a world drop, a vendor, a quest
  -- and a container are filed under the categories above, beside the player's own sightings of
  -- the same kind of thing; these seven have nowhere else to go and are categories of their own.
  ["Skinned from"] = "skinned",
  ["Gathered in"] = "gatheredin",
  ["Mined in"] = "minedin",
  ["Fished in"] = "fishedin",
  ["Found in"] = "foundin",
  ["Pickpocketed from"] = "pickpocketed",
  -- The other end of three of those: what comes off a CREATURE, which is the whole of a creature
  -- root's Loot tab (brief E57, Core/EraSources.lua CREATURE_LOOT). They are their own ids rather
  -- than the item side's, because "Drops from" is the creatures an item comes off and "Drops" is
  -- the items a creature gives up: two different questions, so a saved filter set on one never
  -- selects the other.
  ["Drops"] = "creaturedrops",
  ["Skinned"] = "skinning",
  ["Pickpocketed"] = "pickpocketing",
  -- Brief N2: what a vendor sells, the one category its Sells tab holds. Its own id rather than
  -- "Sold by"'s for the same reason "Drops" has one.
  ["Sells"] = "sells",
  -- Brief N3: the two categories an NPC's Quests tab holds, the quests it starts and ends.
  ["Starts"] = "queststarts",
  ["Ends"] = "questends",
  -- Brief C5: the items a creature's Loot tab lists because ItemTree's model guesses it drops
  -- them (Core/GuessSources.lua), after every known group.
  ["Predicted"] = "predicted",
}

local GROUP_ICONS = {
  ["Quests"] = "CAT_QUEST",
  ["Item use"] = "CAT_ITEM_USE",
  -- Brief P5b: a class spell is learnt from a class trainer, so its category wears the trainer's.
  ["Reagent for"] = "CAT_TRAINER",
  ["Trainer"] = "CAT_TRAINER",
  ["Requirements"] = "CAT_REQUIREMENT",
  -- Brief TB10: a class's own consumable, the class trainer's glyph as the class spells wear.
  ["Class use"] = "CAT_TRAINER",
  ["Disenchants into"] = "CAT_ENCHANTING",
  ["Disenchanted from"] = "CAT_ENCHANTING",
  ["Sold by"] = "CAT_VENDOR",
  ["Drops from"] = "CAT_DROPS",
  ["Gathered from"] = "CAT_HERBALISM",
  ["Mined from"] = "CAT_MINING",
  ["Fished from"] = "CAT_FISHING",
  ["Started by"] = "CAT_QUEST",
  ["Requires"] = "CAT_QUEST",
  ["Rewards"] = "CAT_QUEST",
  -- One glyph per kind of source, each the art a player already knows it by: the profession
  -- icons for skinning, herbs, veins and fishing, a chest for a world object, the rogue's own
  -- stealth glyph for a pocket and a crate for the container an item comes out of.
  ["Skinned from"] = "CAT_SKINNING",
  ["Gathered in"] = "CAT_HERBALISM",
  ["Mined in"] = "CAT_MINING",
  ["Fished in"] = "CAT_FISHING",
  ["Found in"] = "CAT_CHEST",
  ["Pickpocketed from"] = "CAT_PICKPOCKET",
  ["Contained in"] = "CAT_CONTAINER",
  -- Brief Q9b: an item's set wears a helm, never the note.
  ["Item set"] = "CAT_SET",
  -- A creature's own three categories wear the same glyphs their item side counterparts do, so
  -- the two read as one idea from either end.
  ["Drops"] = "CAT_DROPS",
  ["Skinned"] = "CAT_SKINNING",
  ["Pickpocketed"] = "CAT_PICKPOCKET",
  ["Sells"] = "CAT_VENDOR",
  ["Starts"] = "CAT_QUEST",
  -- Brief QI2 (the owner's "A" of 2026-10-23): the quests an NPC or object takes back wear the turn
  -- in "?", as a quest page's Turned in to does; what it starts keeps the "!".
  ["Ends"] = "CAT_QUEST_TURNIN",
  ["Predicted"] = "CAT_DROPS",
}

-- The Assets key a named category wears, or "CAT_NOTE" for one this file has not named. Pure, so
-- the table can be read by a spec: "Gathered from" is a herb's and "Mined from" a vein's.
function ViewModel.GroupIcon(groupKey)
  return GROUP_ICONS[groupKey] or "CAT_NOTE"
end

-- Brief CT1: where a class trainer's level group sorts on the Teaches tab, after every other group:
-- by class, the player's own class (Core/Keep.lua Keep.PlayerClass, the pretend class included)
-- first, then by level. Every class trainer the data lists teaches one class, so on a real page this
-- is the level order alone. Pure over the player's class.
ViewModel.CLASS_LEVEL_ORDER = 1000

function ViewModel.ClassLevelOrder(classId, level)
  classId = tonumber(classId) or 0
  local keep = ItemTree.Keep
  local own = nil
  if type(keep) == "table" and type(keep.PlayerClass) == "function" then
    local ok, answer = pcall(keep.PlayerClass)
    own = ok and tonumber(answer) or nil
  end
  local classRank = (own ~= nil and classId == own) and 0 or (classId + 1)
  return ViewModel.CLASS_LEVEL_ORDER + classRank * 100 + math.max(0, math.min(99, tonumber(level) or 0))
end

-- Brief TB10: the words of an item's class locked use, "Mages read it (Comprehension 1)", the
-- same words the tooltip's Keep block says (Core/Keep.lua ClassUse and ClassWords), or nil for a
-- root that is no such item or while Core/Keep.lua is not loaded. Pure over the data tables.
function ViewModel.ClassUseLabel(rootKey)
  local kind, id = Graph.Parse(rootKey)
  local keep = ItemTree.Keep
  if kind ~= "item" or type(keep) ~= "table" or type(keep.ClassUse) ~= "function" then
    return nil
  end
  if type(keep.ClassWords) ~= "function" then
    return nil
  end
  local ok, use = pcall(keep.ClassUse, id)
  if not ok or type(use) ~= "table" then
    return nil
  end
  local worded, words = pcall(keep.ClassWords, use)
  if worded and type(words) == "string" and words ~= "" then
    return words
  end
  return nil
end

-- Category order in the tree: professions first alphabetically, then the fixed list,
-- then anything else alphabetically.
local PROFESSION_ORDER = 10
local GROUP_ORDER = {
  -- Straight after the professions: it answers the same question, and the answer is a recipe
  -- with no profession rather than a different kind of thing altogether.
  ["Item use"] = 12,
  -- Brief P5b: the class spells, beside the recipes and the combines: the same question again.
  ["Reagent for"] = 13,
  -- Brief TB10: a class locked consumable's own use, beside the class spells.
  ["Class use"] = 14,
  -- A quest reads from the item that starts it, through what it asks for, to what it hands
  -- back, so "Started by" leads the up side and "Rewards" is the only group on the down side.
  ["Started by"] = 15,
  ["Quests"] = 20,
  ["Requires"] = 25,
  ["Rewards"] = 25,
  ["Requirements"] = 30,
  ["Disenchants into"] = 40,
  ["Disenchanted from"] = 45,
  ["Item set"] = 50,
  ["Tool for"] = 60,
  ["Opens"] = 70,
  ["Opened by"] = 80,
  ["Sold by"] = 90,
  ["Drops from"] = 100,
  ["Gathered from"] = 110,
  ["Mined from"] = 112,
  ["Fished from"] = 115,
  ["Contained in"] = 120,
  ["Contains"] = 130,
  ["Community"] = 140,
  -- The categories only the shipped Classic Era table fills, after every category a player's own
  -- sightings can fill and in the contract's own category order (docs/era-sources.md, the c
  -- column). The five kinds of Era row that have a live category already keep it, so a vendor
  -- and a quest stay exactly where a player expects them.
  ["Skinned from"] = 150,
  ["Gathered in"] = 152,
  ["Mined in"] = 154,
  ["Fished in"] = 156,
  ["Found in"] = 158,
  ["Pickpocketed from"] = 160,
  -- A creature's own categories, in the contract's own category order: a drop (boss and creature
  -- together), then skinning, then pickpocketing. They are the only categories the Loot view ever
  -- holds, so these numbers never compete with the ones above them.
  ["Drops"] = 100,
  ["Skinned"] = 150,
  ["Pickpocketed"] = 160,
  ["Sells"] = 100,
  -- Brief N3: the only two categories the Quests view holds, what it starts before what it ends.
  ["Starts"] = 100,
  ["Ends"] = 105,
  -- Brief C5: a creature's guessed drops, after its known Drops, Skinned and Pickpocketed.
  ["Predicted"] = 190,
}

-- Brief Z1: the order a zone's Here tab lists its groups in, which is the brief's own: drops, then
-- the nodes, the pools and the chests, then the other ways off a creature, then vendors and quests.
local ZONE_ORDER = {
  ["Drops from"] = 100,
  ["Mined from"] = 110,
  ["Gathered from"] = 112,
  ["Fished in"] = 115,
  ["Found in"] = 120,
  ["Skinned from"] = 130,
  ["Pickpocketed from"] = 140,
  ["Sold by"] = 150,
  ["Quests"] = 160,
}

-- Brief Z2: what each of those groups is called on a zone's own page, which reads as what happens in
-- the zone rather than as what an item comes from: "Dropped here" where an item's page says "Drops
-- from". The group key, the id, the glyph and the order are the item side's own, so a saved filter
-- and the sidebar's glyphs are untouched; only the words drawn change. "Quests" reads the same on
-- both pages and is not here.
local ZONE_WORDS = {
  ["Drops from"] = "Dropped here",
  ["Mined from"] = "Mined here",
  ["Gathered from"] = "Gathered here",
  ["Fished in"] = "Fished here",
  ["Found in"] = "Found here",
  ["Skinned from"] = "Skinned here",
  ["Pickpocketed from"] = "Pickpocketed here",
  ["Sold by"] = "Sold here",
}

-- The locale key a group reads as on a zone's page, or nil for a group whose words do not change
-- there. Pure, so a spec reads the table.
function ViewModel.ZoneWord(groupKey)
  return ZONE_WORDS[groupKey]
end

-- The group the requirement rows are filed under, and the one group whose rows a confidence
-- tier says nothing about, so it is ordered by chance and item level instead.
local REQUIREMENTS_GROUP = "Requirements"
-- Brief TB10: the group a class locked consumable's own use is filed under on its Used by tab.
local CLASS_USE_GROUP = "Class use"
local DISENCHANTED_FROM_GROUP = "Disenchanted from"

-- The one quiet line at the foot of a creature's Loot tab (brief E57). A world drop names no
-- creature in the shipped table, so it can never be on one creature's list however complete that
-- list is, and the player is told rather than left to wonder.
local WORLD_DROP_NOTE = "World drops are not listed per creature"

-- The item classes that are equipment, which is the pair Core/Data.lua's disenchant rules pick
-- out by the same two ids. A Sources view of one of these opens the craft that makes it.
local EQUIPMENT_CLASSES = { [2] = true, [4] = true }

-- A group label back to its group key. Core/Graph.lua, Core/Collector.lua and the curated data
-- write the words a locale drew, so the words have to lead back to the key the tables above are
-- built on; anything the tables do not name, a profession for one, is its own key.
local groupKeys = nil
local function groupKeyOf(label)
  if not groupKeys then
    groupKeys = {}
    for _, table_ in ipairs({ GROUP_IDS, GROUP_ICONS, GROUP_ORDER }) do
      for key in pairs(table_) do
        groupKeys[L[key]] = key
      end
    end
  end
  return groupKeys[label] or label
end

-- Node kind to the Diff module kind that holds its New and Changed sets.
local DIFF_KINDS = { item = "items", spell = "recipes", skill = "skills", enchant = "enchants" }

-- The edge types whose quantity is a number the game itself states rather than anything this
-- client counted: a quest that asks for ten of an item asks for ten, however many times the
-- collector has watched the objective line. Named by edge type name, which is the identity every
-- other reader in Core compares an edge type by (Edges.REQUIREMENT_TYPES, Edges.SOURCE_TYPES).
-- _DecorateNode reads it so a verified quest row keeps its "x10" instead of having it turned
-- into a tally of sightings.
local STATED_TYPES = { QUEST_REQUIRES = true, QUEST_OBJECTIVE = true }

-- Notice rows, taken from the design system (CategoryPanel and NoticeRow cards).
ViewModel.SOURCE_NOTICE = L["Drop data is from Classic Era. Forever drop rates are not yet known."]
ViewModel.QUEST_NOTICE = L["Quest data is imported baseline data. Forever turn-ins are not yet confirmed."]
ViewModel.PREDICTED_NOTICE =
  L["Predicted from item level and quality. Confirmed results replace predictions as they are seen."]
-- What a category holding nothing but historical rows says. A quest's Era "Rewards" group used to
-- draw PREDICTED_NOTICE under it, which is the disenchant rule's own wording: a quest reward is
-- not predicted from an item level and a quality, it is what another game used to hand over. The
-- same line closes the Era block in the info column, so a player reads one sentence about this
-- data wherever it is drawn.
ViewModel.ERA_NOTICE = L["From Classic Era. WoW Forever may have changed this."]
-- Brief GS3: the one notice a Sources view draws above its first guessed row, and the notice a
-- category holding nothing but guesses carries in place of any Classic Era one: a guess is not
-- Classic Era data, and it is not drop data either.
ViewModel.GUESS_NOTICE =
  L["Guesses from ItemTree's model. Forever items are still being discovered and sources are not known."]

-- The line a view with no rows at all draws. Each is the English wording and its own locale
-- key, read through L when the row is built, and tests/spec/locale_spec.lua lists the block.
--
-- Sources is the heading of the designed empty block UI/Tree.lua draws over that view (brief E1),
-- as one sentence. This line is only what a client that would not give the pane that block sees.
local EMPTY_TEXT = {
  [Edges.USES] = "No known uses",
  [Edges.SOURCES] = "No data for this item yet.",
  [Edges.REQUIRES] = "Nothing is required",
  -- Two different answers in one line, because the tab cannot tell them apart: a shirt cannot
  -- be disenchanted at all, and a piece the bands do not cover has no result to predict.
  [Edges.DISENCHANTS] = "Cannot be disenchanted, or the result is not known",
  -- A creature the shipped table lists nothing for. It is not the same answer as an item's empty
  -- Sources tab: the collector has no creature records of its own to fill this in with, so the
  -- line says where what is here comes from rather than promising more.
  [Edges.LOOT] = "Nothing known to come off this creature",
  -- The map draws no rows, so this line is only ever reached by a caller asking the view model for
  -- the map view's rows directly. It still says something true rather than the Used by wording.
  [Edges.MAP] = "No places known for this creature",
  -- Brief N2: a vendor's Sells tab with nothing in it, which is a vendor the shipped table and the
  -- player's own visits both know by name and neither lists anything for.
  [Edges.SELLS] = "Nothing known to be sold here",
  -- Brief N3: the Quests tab with nothing in it, which is only ever reached with "Show predicted
  -- data" off, because the tab is offered only where the shipped table lists a quest.
  [Edges.QUESTS] = "No quests known for this NPC",
  -- Brief Z1: a zone the shipped table names and states no source row for, which is most instances
  -- and every city with nothing to drop.
  [Edges.HERE] = "Classic Era placed nothing here",
  -- Brief OL1: an openable item's Contains tab with nothing in it, only ever reached with "Show
  -- predicted data" off, because the tab is offered only where the shipped table lists contents.
  [Edges.CONTAINS_VIEW] = "Nothing known to be inside this",
  -- Brief OL1: a chest's Loot tab in the same case, in the same words.
  objectLoot = "Nothing known to be inside this",
  -- Brief Q8: a quest's Quest tab with nothing in it: not in the log, no record and no Classic Era
  -- row. The tree draws its own block for it (UI/Tree.lua); this is the line under that.
  quest = "Nothing known about this quest yet",
  -- Brief C4 addendum: the Loot tab of a creature with no Classic Era page (a sighting, or a row of
  -- the Creatures data), in the words its page's own column uses.
  metCreature = "ItemTree has no data for this creature yet",
  -- Brief TR1: the Teaches tab (brief TR2, the Trains tab before it) of a trainer our sources know
  -- without what it teaches (a pet trainer's title, a visit whose window named no profession).
  -- Brief fix156: a class trainer's tab reads its own line instead (VM:Rows).
  trainsUnknown = "Trainer (what they teach is not recorded yet)",
}

local VM = {}
VM.__index = VM

local function slug(label)
  return (tostring(label):lower():gsub("[^%a%d]", ""))
end

-- Profession name to skill line, built once from the Skills module. Only the last resort:
-- an edge names its skill line itself, and a build can list the same profession on more
-- than one skill line (1.60.1.69893 has Blacksmithing on 164 and again on 2938, which
-- holds no abilities). The lowest id is the one the client actually uses, so a name that
-- is claimed twice resolves to it and never to the duplicate.
local skillIndex = nil
local function skillIdForName(name)
  if not skillIndex then
    skillIndex = {}
    for id, skill in pairs(Data:Get("Skills") or EMPTY) do
      local current = skill.n and skillIndex[skill.n] or nil
      if skill.n and (current == nil or id < current) then
        skillIndex[skill.n] = id
      end
    end
  end
  return skillIndex[name]
end

-- The skill line a category stands for, or nil when it is not a profession. An edge carries
-- its recipe's skill line whatever group it sits in, so a Teaches or Tool for edge knows one
-- too; only the groups the skill line itself named are professions, which is exactly the
-- groups whose label is that skill's name. An edge that names none, a collector or curated
-- one, falls back to the label.
local function groupSkillLine(edge, label)
  -- A category this file has named is a category and never a profession, whatever a skill line
  -- happens to be called. Brief E57 found the collision: a creature's "Skinning" category is the
  -- items you get by skinning THAT creature, and the build calls skill line 393 "Skinning", so
  -- without this the category took the profession's id, the profession's place at the top of the
  -- list and a saved Skinning filter with it.
  if GROUP_IDS[label] then
    return nil
  end
  local skillLine = edge.skillLine
  if skillLine and Data:GetSkillName(skillLine) == label then
    return skillLine
  end
  return skillIdForName(label)
end

--- Brief BQ14 (the owner's QA item 14, 2026-10-10: "Leatherworking 60/75" and its circles): puts on
--- each profession group of an item's Used by the qualities of the items its recipes make
--- (group.qualities, a mask; Graph.UseQualities over the core set's Summary module), which UI/Tree.lua
--- draws as small circles after the header. Nothing for another root, a group no skill line names or
--- a build that ships no masks. Answers groups.
function ViewModel.MarkQualities(groups, rootKey)
  if type(groups) ~= "table" or type(Graph.Parse) ~= "function" or type(Graph.UseQualities) ~= "function" then
    return groups
  end
  local ok, kind, id = pcall(Graph.Parse, rootKey)
  if not ok or kind ~= "item" or tonumber(id) == nil or type(Data.Get) ~= "function" then
    return groups
  end
  local okSummary, summary = pcall(Data.Get, Data, "Summary")
  local okMasks, masks = pcall(Graph.UseQualities, okSummary and summary or nil, tonumber(id))
  if not okMasks or type(masks) ~= "table" then
    return groups
  end
  for _, group in ipairs(groups) do
    local mask = group.skillLine and masks[group.skillLine] or nil
    if mask and mask > 0 then
      group.qualities = mask
    end
  end
  return groups
end

-- Two skill lines can carry the same name. Their categories are kept apart, so the label
-- has to say which is which, but only when both of them are actually on screen.
local function disambiguate(order)
  local counts = {}
  for _, group in ipairs(order) do
    counts[group.label] = (counts[group.label] or 0) + 1
  end
  for _, group in ipairs(order) do
    if group.skillLine and counts[group.label] > 1 then
      group.label = string.format("%s (%d)", group.label, group.skillLine)
    end
  end
end

-- View counts, keyed by root and the options that change what is counted, with the data and
-- collector generations they were worked out against. The window asks for every view on each
-- refresh to label its tabs, so the answer is kept rather than built once per tab per
-- keystroke.
local countCache = {}

-- Drops the profession lookup and the view counts (tests, or after swapping data modules).
function ViewModel.Reset()
  skillIndex = nil
  countCache = {}
  -- Brief CT1b: the class trainers' kept Teaches tabs.
  ViewModel.ResetClassTabs()
  ViewModel.ResetZoneItems()
  -- Brief Q8: what the client said about each quest, and Classic Era's givers read the other way.
  ViewModel.questLive = {}
  ViewModel.ResetQuestIndex()
  -- Brief NP1: each Classic Era trainer's professions, read again from the data now in place.
  ViewModel.ResetTrains()
end

-- The view a caller asked for. A view key is taken as it is; a direction is read as the view it
-- stood for while there were only two tabs (down is uses, up is sources), which is what the
-- window and the harness still pass. Anything else is the uses view, the way anything that was
-- not Edges.UP used to be the down tree. A caller with a direction in hand therefore never
-- lands on the disenchants view: it has to be asked for by name.
function ViewModel.ViewKey(viewOrDirection)
  -- Brief Q8: a quest root's own tab, which Core/Edges.lua gives no direction. Brief C2: the Chain
  -- tab of an item, which has none either.
  if
    Edges.ViewDirection(viewOrDirection)
    or viewOrDirection == ViewModel.QUEST_VIEW
    or viewOrDirection == ViewModel.CHAIN_VIEW
  then
    return viewOrDirection
  end
  return Edges.ViewOf(viewOrDirection)
end

-- rootKey is a node key. viewOrDirection is a view key ("uses", "sources", "requires",
-- "disenchants") or a plain Edges.UP or Edges.DOWN; vm.view and vm.direction are both set
-- either way.
function ViewModel.New(rootKey, viewOrDirection, opts)
  local vm = setmetatable({}, VM)
  vm.root = rootKey
  vm.view = ViewModel.ViewKey(viewOrDirection)
  vm.direction = Edges.ViewDirection(vm.view)
  -- Brief Q8: the Quest tab draws flat rows and walks nowhere; down is what a row would walk.
  -- Brief C2: the Chain tab draws the chain pane and no rows; down is what the chain reads as.
  if vm.view == ViewModel.QUEST_VIEW or vm.view == ViewModel.CHAIN_VIEW then
    vm.direction = Edges.DOWN
  end
  vm.opts = {}
  for key, value in pairs(ViewModel.DEFAULTS) do
    vm.opts[key] = value
  end
  vm.expanded = {}
  vm.shown = {}
  vm.children = {}
  -- The rest of the list behind a summary the player has pressed, as edges, worked out once per
  -- list and kept for as long as this view model lives. Keyed by the list, "<item>:<category>".
  -- Nothing is in it until something asks, which is a click on its "Show N more" row or the
  -- search box reaching past it, and a re-root builds a new view model and drops the lot.
  vm.more = {}
  -- True while the search box holds something. Every summary then draws its list whether or not
  -- the player pressed it, so the box can find a creature that is still behind one. It is an
  -- override rather than a press, so clearing the box leaves vm.shown exactly as the player left
  -- it.
  vm.searching = false
  -- EXPERIMENTAL (brief E25): a craft's reagents and tools, worked out once per craft and owner
  -- and kept for as long as the children are. Empty in the "off" mode, where nothing asks.
  vm.crafts = {}
  -- Source facts per edge, worked out once and kept for as long as the edges are.
  vm.sources = {}
  vm.rows = nil
  vm.index = nil
  vm.categories = nil
  vm:SetOptions(opts)
  return vm
end

function VM:SetOptions(opts)
  for key, value in pairs(opts or EMPTY) do
    self.opts[key] = value
  end
  self.categories = nil
  self.sources = {}
  self.rows = nil
  self.index = nil
  return self.opts
end

function VM:SetFilter(categoryId)
  self.opts.filter = categoryId
  self.rows = nil
  self.index = nil
end

-- The category id the rows are filtered to, or nil while every category is shown. The reader
-- for SetFilter, so the sidebar can mark the selected row without reaching into vm.opts.
function VM:Filter()
  return self.opts.filter
end

function VM:Find(rowKey)
  self:Rows()
  return self.index[rowKey]
end

function VM:Expand(rowKey)
  self.expanded[rowKey] = true
  self.rows = nil
  self.index = nil
end

function VM:Collapse(rowKey)
  self.expanded[rowKey] = false
  self.rows = nil
  self.index = nil
end

function VM:Toggle(rowKey)
  local row = self:Find(rowKey)
  local open = row and row.expanded or false
  if open then
    self:Collapse(rowKey)
  else
    self:Expand(rowKey)
  end
end

-- Whether the search box holds anything. While it does, every summary draws the rest of its
-- list, so a creature the cap never named can still be found by typing its name; the decoded
-- lists are kept, so a whole word costs one decode per list and not one per keystroke.
--
-- The player's own expansions are untouched, so clearing the box puts the view back exactly as
-- they left it.
function VM:SetSearching(on)
  local wanted = on and true or false
  if self.searching == wanted then
    return self.searching
  end
  self.searching = wanted
  self.rows = nil
  self.index = nil
  return self.searching
end

-- Reveals every remaining child of a group. Accepts the group's own row key or the key
-- of the "more" row the group produced. A Classic Era summary's "Show N more" row is keyed the
-- same way (_AppendListed), so pressing it lands here too and marks the list as drawn.
--
-- Brief FIX176 (owner QA 2026-10-14 item 176): either press draws every row its number counted,
-- at once. A summary's list is drawn whole (VM:_AppendListed), and a cap row's press draws each
-- summary it stood over opened onto its list (VM:_AppendGroup), so no press leaves a more row of
-- its own behind.
function VM:ShowMore(rowKey)
  local parent = tostring(rowKey):gsub("/more$", "")
  self.shown[parent] = true
  self.rows = nil
  self.index = nil
end

--------------------------------------------------------------------------------
-- What the player did to a view, as keys and numbers (brief E61)
--
-- The window builds a new view model on every open, so walking away from a page and coming back
-- used to close every list the player had opened and lose where they were in it. A snapshot is
-- the marks they made and nothing else: row keys to true or false, the keys of the capped groups
-- they revealed, and the category id the sidebar is filtered to. No rows, no nodes and none of
-- the decoded lists behind a summary (vm.more), so a page is a handful of strings however
-- long its list is, and a restore pays for the one list the player had opened exactly as
-- reopening it by hand would.
--
-- The store is UI/Frame.lua's, it lives for this session only and nothing here ever reaches
-- saved variables.
--------------------------------------------------------------------------------

-- The marks on this view, or nil where the player has made none: an untouched view is the view a
-- fresh open draws, so there is nothing to remember about it.
function VM:Snapshot()
  local expanded, shown, marks = nil, nil, 0
  for key, value in pairs(self.expanded) do
    if type(key) == "string" then
      expanded = expanded or {}
      if value then
        expanded[key] = true
      else
        expanded[key] = false
      end
      marks = marks + 1
    end
  end
  for key, value in pairs(self.shown) do
    if type(key) == "string" and value == true then
      shown = shown or {}
      shown[key] = true
      marks = marks + 1
    end
  end
  local filter = self.opts.filter
  if marks == 0 and filter == nil then
    return nil
  end
  return { expanded = expanded, shown = shown, filter = filter }
end

-- Puts one back, before anything asks for a row. Everything the snapshot does not name is left at
-- its own default, so a row the data has since dropped takes nothing with it and a row that has
-- arrived opens the way it always would. Answers whether anything was applied.
function VM:Restore(state)
  if type(state) ~= "table" then
    return false
  end
  local applied = false
  for key, value in pairs(type(state.expanded) == "table" and state.expanded or EMPTY) do
    if type(key) == "string" then
      if value then
        self.expanded[key] = true
      else
        self.expanded[key] = false
      end
      applied = true
    end
  end
  for key, value in pairs(type(state.shown) == "table" and state.shown or EMPTY) do
    if type(key) == "string" and value == true then
      self.shown[key] = true
      applied = true
    end
  end
  if state.filter ~= nil then
    self.opts.filter = state.filter
    applied = true
  end
  if applied then
    self.rows = nil
    self.index = nil
  end
  return applied
end

-- Season of Discovery ("sod") is New in purple (brief D2), so Diff.IsNewBadge puts it under the
-- New toggle with New itself.
local function badgeAllowed(opts, badge)
  if Diff.IsNewBadge(badge) then
    return opts.badgesNew ~= false
  end
  if badge == "changed" then
    return opts.badgesChanged ~= false
  end
  return true
end

function VM:_EdgeVisible(edge)
  if self.opts.showPredicted == false and edge.confidence == Confidence.PREDICTED then
    return false
  end
  -- Brief GS3: a guess goes with the predictions and with its own setting.
  if edge.guess ~= nil and not guessSourcesShown(self.opts) then
    return false
  end
  return Graph.Node(edge.target) ~= nil
end

-- The item an edge leaves, where that is an item: the only place a vendor price is written.
function VM:_OwnerItem(ownerKey)
  local kind, id = Graph.Parse(ownerKey)
  if kind ~= "item" then
    return nil
  end
  return Data:GetItem(id)
end

-- The views whose rows carry the source facts Core/Sources.lua works out: the type, the zone and
-- the rate a player compares sources by.
--
-- Sources is the obvious one. Loot is the same question read from the other end, which is what a
-- creature page asks: the row still says what kind of source this is, where it was recorded and
-- how often it gave the item, and it is the same four columns and the same code drawing them. A
-- reagent under Requires is not a source of anything, and neither is a use.
--
-- Sells (brief N2) is the third: a vendor's row says what it asks and where the vendor stands, in
-- the Sold by row's own columns. Core/Sources.lua words a Sold by edge, and a Sells edge is the
-- same fact read from the vendor's end, so _Source asks it about the one as the other.
local SOURCE_VIEWS = { [Edges.SOURCES] = true, [Edges.LOOT] = true, [Edges.SELLS] = true }
-- Brief Z1: a zone's Here tab is the fourth, each row the source it names read from the zone's end.
SOURCE_VIEWS[Edges.HERE] = true
-- Brief OL1: an openable item's Contains tab is the fifth, each row a "Contained in" row read from
-- the container's end, with its rate.
SOURCE_VIEWS[Edges.CONTAINS_VIEW] = true

-- What Core/Sources.lua says about one edge, or nil when the edge answers something other than
-- "where do I get this". Only in the two views that ask it, because only there is the question
-- being asked. Worked out once per edge: the edges live as long as the categories they were
-- grouped into.
function VM:_Source(edge, ownerKey)
  if not SOURCE_VIEWS[self.view] or not edge or edge.requirement then
    return nil
  end
  local cached = self.sources[edge]
  -- Brief BQ25b: a live edge that took a Classic Era rate after its columns were worked out (a
  -- list opened later, Graph.AdoptSourceFacts) has them worked out again.
  if cached and edge.eraRate ~= nil and cached.eraRateLine == nil then
    cached = nil
  end
  if cached == nil then
    local Sources = ItemTree.Sources
    cached = false
    if Sources and type(Sources.Source) == "function" then
      local node = Graph.Node(edge.target)
      if node then
        local owner = self:_OwnerItem(ownerKey)
        local asked = edge
        if edge.type == Edges.Types.SELLS then
          -- A Sells row is a Sold by row read from the vendor's end: the same columns, and the
          -- item whose buy price a vendor with no price of its own falls back on is the row's own.
          asked = setmetatable({ type = Edges.Types.SOLD_BY }, { __index = edge })
          local kind, id = Graph.Parse(edge.target)
          owner = kind == "item" and Data:GetItem(id) or nil
        elseif edge.type == Edges.Types.ZONE_HOLDS then
          -- Brief Z1: a zone's row is the source it names, read from the zone's end: worded as the
          -- up type it carries (a drop, a vein, a vendor), with the item's own buy price behind a
          -- vendor that states none.
          asked = setmetatable({ type = Edges.Types[edge.as] }, { __index = edge })
          local kind, id = Graph.Parse(edge.target)
          owner = kind == "item" and Data:GetItem(id) or nil
        end
        cached = Sources.Source(asked, node, owner) or false
        -- Brief GS5: a guessed place row standing in for a new creature nobody has named reads
        -- as the place alone (Core/GuessSources.lua guess.nameAs), never as the Unknown creature.
        local nameAs = type(edge.guess) == "table" and edge.guess.nameAs or nil
        if cached and type(nameAs) == "string" and nameAs ~= "" then
          cached.name = nameAs
        end
      end
    end
    self.sources[edge] = cached
  end
  if cached == false then
    return nil
  end
  return cached
end

-- Brief EK2: 0 for a Classic Era row in one place (EraSources.StatesPlace: a placed or a pocket
-- row's key), 1 for every other target. Two rows of one name and rate read in the order their keys'
-- strings sort, and until EK2 a row in one place was keyed in a range whose digits sort before
-- every page key of a name (1,850 such pairs on 1.60.1.70291, every one placed first), which no
-- longer follows from the keys' digits now that both are ids; this says it in words instead.
local function placeRank(target)
  local EraSources = ItemTree.EraSources
  local fn = type(EraSources) == "table" and EraSources.StatesPlace or nil
  if type(fn) ~= "function" then
    return 1
  end
  local ok, answer = pcall(fn, target)
  return (ok and answer == true) and 0 or 1
end

-- Sort keys for one category's entries, read once each so the comparator never walks the data.
-- rate is the percentage behind a row, which a row without one sorts below rather than above.
function VM:_SortKeys(group)
  local keys = {}
  for index, entry in ipairs(group.entries) do
    local sortKey =
      { index = index, tier = 0, side = 0, named = 0, rate = -1, level = -1, name = "", place = 1, target = "" }
    if not entry.requirement then
      local kind, id = Graph.Parse(entry.target)
      if kind == "item" then
        local item = Data:GetItem(id)
        sortKey.level = item and item.il or -1
      end
      sortKey.tier = Confidence.Rank(entry.confidence)
      -- Brief M3: a shipped community row for the player's own side reads before the other side's.
      sortKey.side = (type(entry.community) == "table" and entry.community.own) and 1 or 0
      sortKey.rate = entry.percent or -1
      sortKey.name = Graph.Name(entry.target) or ""
      -- Brief TR2: a profession's rank spells read Apprentice to Artisan, in rank order.
      if kind == "spell" then
        local line, step = ViewModel.RankSpell(id)
        if line then
          sortKey.name = ViewModel.RankSortName(line, step)
        end
      end
      -- Brief V1: a vendor the client's own tables list and nothing names reads after the ones
      -- something does name, inside its tier: "Vendor (npc 252000)" says the least of them.
      sortKey.named = (entry.provenance == CLIENT_PROVENANCE and sortKey.name == "") and 0 or 1
      sortKey.place = placeRank(entry.target)
      sortKey.target = entry.target or ""
      -- Brief TR5: the rank a Classic Era trainer asks before teaching the spell, where known.
      sortKey.learn = tonumber(entry.learnLevel)
    end
    keys[entry] = sortKey
  end
  return keys
end

-- Brief P2 (#7): the shipped "Disenchanted from" edges arrive with rank, their place in the
-- order the sort below would put them in, worked out once per material by Data:DisenchantOrder.
-- When every entry of the group has one, the group is laid out by rank in one pass instead of
-- sorted. Any entry without one (a collected disenchant, or a source whose name only the client
-- knows) answers false and the group is sorted as it always was. The flag is off only in the
-- spec that proves the two orders equal.
ViewModel.presortedDisenchant = true

function VM:_LayByRank(group)
  local slots, top = {}, 0
  for _, entry in ipairs(group.entries) do
    local rank = entry.rank
    if type(rank) ~= "number" or slots[rank] then
      return false
    end
    slots[rank] = entry
    if rank > top then
      top = rank
    end
  end
  local entries = group.entries
  local at = 0
  for rank = 1, top do
    local entry = slots[rank]
    if entry then
      at = at + 1
      entries[at] = entry
    end
  end
  return true
end

-- The order a category of the Sources view reads in. Sources lead with what the collector
-- confirmed, then what a build imported, then what a rule predicted, and inside a tier the
-- better rate leads. Disenchanted from is the one category a tier says nothing about, so it
-- leads with the likeliest result and then with the item that gives the most up. The other two
-- views keep the order the graph stated: a recipe's reagents are the recipe's own list.
function VM:_SortEntries(group)
  -- Brief N2: a vendor's stock reads by item name, which is how a merchant window is scanned.
  -- Brief N3: an NPC's quests read the same way, by title, and brief P6b a trainer's recipes.
  local byName = self.view == Edges.SELLS or self.view == Edges.QUESTS or self.view == Edges.TEACHES_VIEW
  if byName and #group.entries > 1 then
    local keys = self:_SortKeys(group)
    -- Brief TR5: a trainer's recipes read in the order he teaches them, by the rank he asks,
    -- lowest first and the ones with no known rank last; the name orders the rest as before.
    local byLevel = self.view == Edges.TEACHES_VIEW
    table.sort(group.entries, function(a, b)
      local left, right = keys[a], keys[b]
      if byLevel and left.learn ~= right.learn and not a.requirement and not b.requirement then
        if left.learn == nil or right.learn == nil then
          return right.learn == nil
        end
        return left.learn < right.learn
      end
      if left.name ~= right.name then
        return left.name < right.name
      end
      if left.target ~= right.target then
        return left.target < right.target
      end
      return left.index < right.index
    end)
    return
  end
  if self.view ~= Edges.SOURCES or #group.entries < 2 then
    return
  end
  local disenchant = group.key == DISENCHANTED_FROM_GROUP
  local sourced = false
  if not disenchant then
    for _, entry in ipairs(group.entries) do
      if self:_Source(entry, self.root) then
        sourced = true
        break
      end
    end
  end
  if not (disenchant or sourced) then
    return
  end
  if disenchant and ViewModel.presortedDisenchant and self:_LayByRank(group) then
    return
  end
  local keys = self:_SortKeys(group)
  table.sort(group.entries, function(a, b)
    local left, right = keys[a], keys[b]
    if not disenchant and left.tier ~= right.tier then
      return left.tier > right.tier
    end
    if left.side ~= right.side then
      return left.side > right.side
    end
    if not disenchant and left.named ~= right.named then
      return left.named > right.named
    end
    if left.rate ~= right.rate then
      return left.rate > right.rate
    end
    if disenchant and left.level ~= right.level then
      return left.level > right.level
    end
    if left.name ~= right.name then
      return left.name < right.name
    end
    -- Brief EK2: a row of one name in one place before that name's page (placeRank).
    if left.place ~= right.place then
      return left.place < right.place
    end
    if left.target ~= right.target then
      return left.target < right.target
    end
    return left.index < right.index
  end)
end

-- How many rows a shipped summary's list draws once pressed: the number its own words state
-- ("Show 4 more"), which is the table's total less the rows named above it, read off the item's
-- normalised rows (E:Rows, the same pass the graph's edges come out of, and nothing decoded). Not
-- the list's record count: a herb's or a vein's records are its zones, which the list folds into
-- one node row each, so Arcane Crystal's 13 records are 4 veins. The record count stands in where
-- the rows cannot be read. Kept on the summary, which is this addon's own table.
local function summaryRows(entry, summary)
  if summary.rows ~= nil then
    return summary.rows
  end
  local rows = tonumber(summary.listed) or 0
  local era = ItemTree.eraSources
  if type(era) == "table" and type(era.Rows) == "function" and type(entry.target) == "string" then
    local ok, list = pcall(era.Rows, era, summary.item)
    for _, row in ipairs(ok and type(list) == "table" and list or EMPTY) do
      if type(row) == "table" and row.summary and row.key == entry.target and tonumber(row.more) then
        rows = tonumber(row.more)
        break
      end
    end
  end
  summary.rows = rows
  return rows
end

-- The summary of an entry whose list is shipped (E75), which draws as a "Show N more" row of its
-- own (VM:_AppendListed), or nil for every other entry.
local function listedSummary(entry)
  local summary = type(entry) == "table" and not entry.requirement and entry.summary or nil
  local listed = type(summary) == "table" and tonumber(summary.listed) or nil
  if listed and listed > 0 then
    return summary
  end
  return nil
end

-- The rows one entry draws: a shipped summary the rows of its list (listRows where given, else the
-- number its own words state), every other entry one.
local function entryRows(entry, listRows)
  local summary = listedSummary(entry)
  if not summary then
    return 1
  end
  if listRows then
    return listRows(entry)
  end
  return math.max(1, summaryRows(entry, summary))
end

-- Brief Q9b: how many rows a category's entries draw before the group cap. A shipped summary
-- (Core/EraSources.lua, E75) is one entry that stands for its whole list, so it counts the rows
-- that list draws once pressed (summaryRows); every other entry is one row, a summary with no
-- list shipped (a world drop) included. Raw Brilliant Smallfish's "Fished in" is 3 zone rows and
-- a summary of 29, which is 4 entries and 32 rows.
--
-- Brief FIX159: listRows, where given, is what one summary entry's list really adds once pressed
-- (VM:_ListRows, the decoded list less what folds away); the view model passes it for every count
-- it draws, so the header, a cap's number and a summary's own number all count the rows a press
-- will add. Without it the summary's own words stand in, as they did before.
function ViewModel.EntryRows(entries, listRows)
  local rows = 0
  for _, entry in ipairs(entries or EMPTY) do
    rows = rows + entryRows(entry, listRows)
  end
  return rows
end

-- Brief FIX149 (owner QA 2026-10-14 item 149, Stringy Wolf Meat's Sources: "Drops from 24", eight
-- rows, then "Show 1 more"): how many of a group's entries the group cap draws, and the number its
-- "Show N more" row states (nil where the cap draws no row). A shipped summary is a "Show N more"
-- row of its own, so the cap never hides one: where every entry past the limit is such a summary,
-- every entry is drawn. Before, the cap's "Show 1 more" stood over the Classic Era summary of 16
-- creatures, so the header's 24 read as 15 rows lost until the player pressed it. Where the cap
-- does hide rows, its number counts them as the header does (ViewModel.EntryRows, a summary counts
-- its list, through listRows where given), so the rows drawn and the cap's number add up to the
-- header's count. open is true where the whole group is drawn anyway (the search box holds
-- something, or the cap was pressed). Pure.
function ViewModel.GroupCap(entries, limit, open, listRows)
  entries = type(entries) == "table" and entries or EMPTY
  local total = #entries
  limit = tonumber(limit) or total
  if open or total <= limit then
    return total, nil
  end
  local hidden, onlyLists = 0, true
  for index = limit + 1, total do
    local entry = entries[index]
    if not listedSummary(entry) then
      onlyLists = false
    end
    hidden = hidden + entryRows(entry, listRows)
  end
  if onlyLists then
    return total, nil
  end
  return limit, hidden
end

-- Brief FIX159: the words a shipped summary's "Show N more" row says once its number is the rows
-- its list really adds (count) rather than the table's own (stated). The table words it one of two
-- ways (Core/EraSources.lua summaryRow): "Show 16 more" under named rows, "Show 184 vendors" where
-- it named none; the same words are written again with count. nil where text is neither (the pane
-- then says "Show N more" from the row's number). text where the two numbers agree. Pure.
function ViewModel.SummaryWords(text, stated, count, category)
  if stated == count then
    return text
  end
  local Sources = ItemTree.Sources
  if type(Sources) ~= "table" or type(text) ~= "string" then
    return nil
  end
  if type(Sources.ShowMoreText) == "function" and text == Sources.ShowMoreText(stated) then
    return Sources.ShowMoreText(count)
  end
  if type(Sources.ShowText) == "function" and type(Sources.GroupCount) == "function" then
    if text == Sources.ShowText(Sources.GroupCount(stated, category)) then
      return Sources.ShowText(Sources.GroupCount(count, category))
    end
  end
  return nil
end

function VM:_VisibleEntries(entries)
  local out = {}
  for _, entry in ipairs(entries or EMPTY) do
    if entry.requirement or self:_EdgeVisible(entry) then
      out[#out + 1] = entry
    end
  end
  return out
end

function VM:_FinishCategory(group)
  -- A category this file has named keeps its own id, icon and place, whatever a skill line happens
  -- to be called: see groupSkillLine above for the collision brief E57 found.
  local skillId = group.skillLine
  if not skillId and not GROUP_IDS[group.key] then
    skillId = skillIdForName(group.label)
  end
  if skillId then
    group.id = tostring(skillId)
    group.icon = ViewModel.SKILL_ICONS[skillId] or "CAT_NOTE"
    group.order = PROFESSION_ORDER
  else
    group.id = GROUP_IDS[group.key] or slug(group.key)
    group.icon = ViewModel.GroupIcon(group.key)
    group.order = GROUP_ORDER[group.key] or 200
  end
  -- Brief Z1: a zone's Here tab reads in its own order, what drops there first and what is sold
  -- there last, whatever order the same groups take on an item's page.
  if self.view == Edges.HERE and ZONE_ORDER[group.key] then
    group.order = ZONE_ORDER[group.key]
  end
  -- Brief Q9b: the count is of the rows the category draws, a summary counting its list, and
  -- sources keeps the entries themselves for the tooltip that says both where they differ.
  group.sources = #group.entries
  -- Brief FIX159: a summary counts the rows its list adds as drawn beside the visible entries (the
  -- ones VM:_AppendCategory hands its group), and a twin its list stands in for is not counted;
  -- read only where the category holds a list.
  local counted = group.entries
  local visible = nil
  for _, entry in ipairs(group.entries) do
    if listedSummary(entry) then
      visible = self:_VisibleEntries(group.entries)
      break
    end
  end
  local twins = visible and self:_ListsOpen(1) and self:_ListTwins(visible) or nil
  if twins then
    counted = {}
    for _, entry in ipairs(group.entries) do
      if not twins[entry] then
        counted[#counted + 1] = entry
      end
    end
  end
  group.count = ViewModel.EntryRows(counted, visible and self:_ListRowsOf(visible, 1) or nil)

  -- Brief GS3: guessed rows (Core/GuessSources.lua) are counted apart. Every flag below is read
  -- over the real rows alone, so a category of Classic Era rows and guesses keeps the badge and
  -- the notice its Era rows give it, and the guesses get their own notice above the first of
  -- them (VM:_AppendGroup). A category of guesses alone says only that.
  local guesses = 0
  for _, entry in ipairs(group.entries) do
    if not entry.requirement and entry.guess ~= nil then
      guesses = guesses + 1
    end
  end
  local real = #group.entries - guesses
  group.guesses = guesses
  group.guessOnly = guesses > 0 and real == 0

  local hasNew, hasChanged, anyBaseline = false, false, false
  local allPredicted = real > 0
  -- Whether every row of this category is history out of the shipped Classic Era table
  -- (Core/EraSources.lua stamps edge.historical), which decides which notice the category carries.
  local allHistorical = real > 0
  local anyHistorical = false
  local teachLines = 0
  -- Brief PS3: whether any real row here is Classic Era data: a row out of the shipped Era table
  -- (historical) or one imported from an outside baseline and not seen on this client (the
  -- baseline tier, which is what the "?" medallion stands for). The player's own records, the
  -- shipped player sourced rows, the client's tables and the build's own data are none of these,
  -- and a category holding only those carries neither the Classic Era notice nor the "?".
  local anyEra = false
  -- Brief V1: whether every row here is the client's own vendor table (Core/ForeverVendors.lua),
  -- which is no Classic Era data at all and so needs none of the Era notices.
  local allClient = real > 0
  for _, entry in ipairs(group.entries) do
    -- A guess sets none of the flags below, and does not lend the category the diff marks of
    -- what it names: it is not a source anyone has seen.
    if entry.requirement or entry.guess == nil then
      if entry.requirement or entry.provenance ~= CLIENT_PROVENANCE then
        allClient = false
      end
      if entry.requirement then
        allPredicted = false
        -- Brief TR2: a Teaches line is our own words beside the Classic Era rows, so it leaves the
        -- group's Classic Era notice where the rows put it (and a group of lines alone has none).
        if entry.requirement.trains ~= true then
          allHistorical = false
        else
          teachLines = teachLines + 1
        end
      else
        if entry.confidence ~= Confidence.PREDICTED then
          allPredicted = false
        end
        if entry.historical ~= true then
          allHistorical = false
        else
          anyHistorical = true
          -- Brief Q1: a Classic Era quest row whose quest the Forever client lists (entry.listed)
          -- is no turn in waiting to be confirmed: it lends the category neither the quest notice
          -- nor the "?" (its counts are still Classic Era's, which the row's own source line says).
          if entry.listed ~= true then
            anyEra = true
          end
        end
        if entry.confidence == Confidence.BASELINE and entry.listed ~= true then
          anyBaseline = true
          anyEra = true
        end
        -- Brief TW1 (ruling "B"): a class spell no Classic Era list of its class holds is new, so its
        -- level group wears New for it as an item's category does.
        if entry.newInForever == true then
          hasNew = true
        end
        local kind, id = Graph.Parse(entry.target)
        local diffKind = DIFF_KINDS[kind]
        if diffKind then
          for _, badge in ipairs(Diff.Badges(diffKind, id)) do
            -- A Season of Discovery child is new too, so the category wears New for it.
            if Diff.IsNewBadge(badge) then
              hasNew = true
            elseif badge == "changed" then
              hasChanged = true
            end
          end
        end
      end
    end
  end
  if teachLines >= real then
    allHistorical = false
  end

  local badges = {}
  if hasNew and badgeAllowed(self.opts, "new") then
    badges[#badges + 1] = "new"
  end
  -- showChanges leaves the change rows out, so the badge that promises them goes too. The
  -- New badge is not a promise of rows and stays.
  if hasChanged and self.opts.showChanges ~= false and badgeAllowed(self.opts, "changed") then
    badges[#badges + 1] = "changed"
  end
  if allPredicted then
    badges[#badges + 1] = "predicted"
  end
  if group.serverSide and anyBaseline then
    badges[#badges + 1] = "unverified"
  end
  -- Brief GS3: a category of guesses alone wears the guess mark and nothing that would say
  -- anyone has seen one of its rows.
  if group.guessOnly then
    badges[#badges + 1] = "guess"
  end
  group.badges = badges

  -- Brief Z1: a zone's Here tab says it once, above its first group (VM:Rows), and never per group.
  group.anyHistorical = anyHistorical
  -- Brief PS3: UI/Sidebar.lua puts the "?" medallion on a server side category only where this is
  -- true. A category the view model never judged (nil) keeps the sidebar's old rule.
  group.eraRows = anyEra
  if group.guessOnly then
    -- Brief GS3: not drop data and not Classic Era data, so neither of those notices; the one
    -- line a guess carries instead, drawn once per view (VM:_AppendCategory).
    group.notice = ViewModel.GUESS_NOTICE
  elseif self.view == Edges.HERE or allClient then
    group.notice = nil
  elseif
    group.serverSide and (self.view == Edges.SELLS or self.view == Edges.QUESTS or self.view == Edges.TEACHES_VIEW)
  then
    -- Brief N2: a vendor's stock is not drop data. Rows out of the shipped table say where they
    -- came from; the player's own sightings need no notice at all. Brief P6b: nor is what a
    -- trainer teaches.
    if allHistorical then
      group.notice = ViewModel.ERA_NOTICE
    end
  elseif group.serverSide and group.id == "quests" then
    -- Brief S6: the quest notice speaks of Classic Era quest data too (brief PS3's rule), so a
    -- Quests group holding no Classic Era row (the player's own records, the shipped player
    -- module's quests) draws none. It used to be drawn on every server side Quests group, which
    -- put it over Prideclaw Pelt's one Forever quest row.
    if anyEra then
      group.notice = ViewModel.QUEST_NOTICE
    else
      group.notice = nil
    end
  elseif group.serverSide then
    -- Brief PS3: the Classic Era notice speaks of the Classic Era rows, so a category holding none
    -- (every row the player's own, shipped player data or Forever data) draws no notice. A Sold by
    -- category's rows carry prices and no rates, so it never wears the drop rate notice: where it
    -- holds Classic Era rows it says what they are in the Era line.
    if not anyEra then
      group.notice = nil
    elseif group.id == "soldby" then
      group.notice = ViewModel.ERA_NOTICE
    else
      group.notice = ViewModel.SOURCE_NOTICE
    end
  elseif allHistorical then
    -- Every row here came out of the shipped Classic Era table, so the notice says that and
    -- nothing else. This is the fault the owner found on a QUEST root: its Era "Rewards" group is
    -- all predicted and is not server side, so it fell through to PREDICTED_NOTICE and told the
    -- player a quest reward was worked out from an item level and a quality.
    group.notice = ViewModel.ERA_NOTICE
  elseif allPredicted then
    group.notice = ViewModel.PREDICTED_NOTICE
  end
  -- Brief CT1: a class trainer's level groups ("Level 20") read in level order, the player's own
  -- class first, with the trainer glyph, and say where they came from once at the top of the tab
  -- (VM:Rows) rather than once a level.
  if group.classLevel then
    group.icon = "CAT_TRAINER"
    group.order = ViewModel.ClassLevelOrder(group.classId, group.classLevel)
    group.classNotice = group.notice
    group.notice = nil
  end
end

-- Categories are the root's edges that belong to this view, grouped by edge.group and the skill
-- line behind it, plus the requirement rows in the Requires view. The skill line is part of the
-- map key so two professions that share a name stay two categories rather than merging into one
-- that belongs to neither. group.key is the stable group key and group.label the words drawn.
--
-- The view filter is the only place an edge is dropped for the tab it is on, and it reads
-- Edges.InView rather than naming types itself.
-- The root's own edges for this view.
--
-- Every view but one is the graph walked in the view's direction, which is what Graph.Children
-- answers. The Loot view is the one exception: a creature's loot is not a route anything can walk
-- and no provider offers it as a graph edge (a click on a creature row is the end of the walk, and
-- Core/Chain.lua must never step through a creature into the items it drops), so the shipped table
-- is asked for it directly, on the one page that asks. Brief E57.
--
-- The rows are already in the order they are drawn, the way an item's own Era rows are: the
-- contract's category order, best chance first inside each. Nothing sorts them again.
--
-- Brief N2: Sells is the same shape from the vendor's end (E:VendorEdges), and both tabs also
-- hold what the player's own records say about the NPC, which the collector answers through the
-- graph (Core/Collector.lua, npc keys walking down). A collected row and a Classic Era row for one
-- item are one row, and the collected one wins: it is what this client showed, with its tally and
-- its price, where the other is what another game used to do.
--
-- Brief N3: Quests is the third, the quests the NPC starts and ends (E:QuestGiverEdges).
--
-- Brief P6b: Teaches is the fourth, the recipes a trainer teaches (E:TeachesEdges).
local NPC_EDGES = {
  [Edges.LOOT] = "CreatureEdges",
  [Edges.SELLS] = "VendorEdges",
  [Edges.QUESTS] = "QuestGiverEdges",
  [Edges.TEACHES_VIEW] = "TeachesEdges",
  -- Brief OL1: an openable item's Contains tab, the table's container rows joined to the player's
  -- own opens exactly as an NPC tab joins its records.
  [Edges.CONTAINS_VIEW] = "ContainerEdges",
}

-- Brief OL1: an OBJECT root's Loot tab is a chest's "Found in" rows read from its end
-- (E:ObjectEdges), not a creature's loot. Brief EO1: its Quests tab is the quests a world object
-- starts and ends (E:QuestGiverEdges, which reads og for an object key).
local OBJECT_EDGES = { [Edges.LOOT] = "ObjectEdges", [Edges.QUESTS] = "QuestGiverEdges" }

-- Brief OL2 (owner QA 2026-10-11 item 133): an object's Loot tab and an openable item's Contains
-- tab draw ONE row per item. The Classic Era table states a chest's loot once per chest id, and
-- one chest name stands for several ids in several zones (Battered Chest: 1,468 rows over 793
-- items, Minor Healing Potion three times), so the rows of one item fold into one edge: a copy of
-- its best rated row with no zone of its own, carrying every row it stands for in lootZones (only
-- where there are two or more), which VM:_AppendLootFold draws as one row that opens onto them.
-- The order is the order each item first came in. Pure; the edges given are not written into.
function ViewModel.FoldLootByItem(edges)
  if type(edges) ~= "table" or #edges < 2 then
    return edges
  end
  local order, members = {}, {}
  for _, edge in ipairs(edges) do
    local target = type(edge) == "table" and edge.target or nil
    if type(target) ~= "string" then
      order[#order + 1] = { edge }
    else
      local list = members[target]
      if not list then
        list = {}
        members[target] = list
        order[#order + 1] = list
      end
      list[#list + 1] = edge
    end
  end
  if #order == #edges then
    return edges
  end
  local out = {}
  for _, list in ipairs(order) do
    if #list == 1 then
      out[#out + 1] = list[1]
    else
      local best = list[1]
      for _, edge in ipairs(list) do
        if (tonumber(edge.percent) or -1) > (tonumber(best.percent) or -1) then
          best = edge
        end
      end
      local fold = {}
      for field, value in pairs(best) do
        fold[field] = value
      end
      fold.zone = nil
      fold.areaId = nil
      fold.lootZones = list
      out[#out + 1] = fold
    end
  end
  return out
end

-- Pure: the zone column of a folded loot row (ViewModel.FoldLootByItem): the one zone's name where
-- its rows name one zone, else how many zones they name ("3 zones"); nil where none names a zone.
-- A row with no zone (the table's unzoned chest) adds no zone of its own; it is still one of the
-- rows the fold opens onto.
function ViewModel.LootFoldZone(members)
  local zones, count, only = {}, 0, nil
  for _, edge in ipairs(type(members) == "table" and members or EMPTY) do
    local zone = type(edge) == "table" and edge.zone or nil
    if type(zone) == "string" and zone ~= "" and not zones[zone] then
      zones[zone] = true
      count = count + 1
      only = zone
    end
  end
  if count == 0 then
    return nil
  end
  if count == 1 then
    return only
  end
  local Sources = ItemTree.Sources
  if type(Sources) == "table" and type(Sources.ZoneCount) == "function" then
    return Sources.ZoneCount(count)
  end
  return nil
end

-- Brief OL2: the views whose rows fold per item, by the root's kind.
local LOOT_FOLD_VIEWS = {
  object = { [Edges.LOOT] = true },
  item = { [Edges.CONTAINS_VIEW] = true },
}

-- Brief OL1: an item root's Used by edges less what it contains, where the item has a Contains tab
-- that draws them (ViewsFor answers Edges.CONTAINER_VIEWS). An item with no such tab keeps a
-- recorded open under Used by, where it has always been. The list is the caller's and is not
-- written into.
function ViewModel.WithoutContents(rootKey, edges)
  if type(edges) ~= "table" or #edges == 0 or ViewModel.ViewsFor(rootKey) ~= ViewModel.CONTAINER_ROOT_VIEWS then
    return edges
  end
  local out = {}
  for _, edge in ipairs(edges) do
    if not (edge.type and Edges.CONTAINS_TYPES[edge.type.name]) then
      out[#out + 1] = edge
    end
  end
  return out
end

-- Brief QI1 (owner QA 2026-10-17, feedback item 182, Crest of Lordaeron 275521): an item that starts
-- a quest and is asked for by the same quest drew that quest twice under Used by, once for each edge
-- ("Quests (2)", the second row with "x1"); 12 shipped items do (An Unsent Letter 2874 and quest 373
-- among them). One row per quest: the start's twin goes where the same list asks for the item on the
-- same quest, since the objective's row carries the count and the side and the start's row said
-- nothing more. A Predicted objective never stands in for a start that is not Predicted, so "Show
-- predicted data" off still leaves the quest's row. Keep counts the quest once already (Keep.Uses).
-- The list is the caller's and is not written into; the same list comes back where nothing goes.
-- Pure.
--
-- Brief FX14 (the owner's rule "one row per quest", the QA page check of 2026-10-17): QI1 kept a
-- start of ours beside a Predicted objective of the same quest, so 16 shipped items still drew the
-- quest twice (Crest of Lordaeron 268579 and quest 95189: a plain row, then an "x1" row with the
-- Predicted mark). They fold into ONE row in the start's place: the start's row (its edge, so no
-- Predicted mark, the start being a fact of ours) carrying the count the objective asks for ("x1").
-- hidePredicted (the view's "Show predicted data" off) folds nothing, so a predicted count never
-- reaches a row of ours: the objective is not drawn there and the start keeps its plain row. A
-- Predicted objective beside a trusted objective of the same quest goes too: the trusted one
-- carries the count (no shipped item has both).

-- The edge type's name of a quest edge the rule reads (QUEST_OBJECTIVE or STARTS_QUEST), else nil.
local function questEdgeName(edge)
  local def = type(edge) == "table" and edge.type or nil
  if type(def) ~= "table" or type(edge.target) ~= "string" then
    return nil
  end
  if def.name == "QUEST_OBJECTIVE" or def.name == "STARTS_QUEST" then
    return def.name
  end
  return nil
end

-- Brief FX14: a copy of a start edge carrying the count a Predicted objective of its quest asks for.
local function startWithCount(start, objective)
  local out = {}
  for key, value in pairs(start) do
    out[key] = value
  end
  out.quantity = objective.quantity
  out.quantityMax = objective.quantityMax
  return out
end

function ViewModel.OneRowPerQuest(edges, hidePredicted)
  if type(edges) ~= "table" or #edges < 2 then
    return edges
  end
  -- Per quest: the objective that speaks for it (the first trusted one, else the first Predicted
  -- one), and whether a start of ours (not Predicted) names it.
  local asked, ours = {}, {}
  for _, edge in ipairs(edges) do
    local name = questEdgeName(edge)
    if name == "QUEST_OBJECTIVE" then
      local held = asked[edge.target]
      if held == nil or (held.confidence == Confidence.PREDICTED and edge.confidence ~= Confidence.PREDICTED) then
        asked[edge.target] = edge
      end
    elseif name == "STARTS_QUEST" and edge.confidence ~= Confidence.PREDICTED then
      ours[edge.target] = true
    end
  end
  local out, changed, folded = {}, false, {}
  for _, edge in ipairs(edges) do
    local name = questEdgeName(edge)
    local objective = name and asked[edge.target] or nil
    local trusted = objective ~= nil and objective.confidence ~= Confidence.PREDICTED
    local predicted = name ~= nil and edge.confidence == Confidence.PREDICTED
    if name == "STARTS_QUEST" and objective ~= nil and (trusted or predicted) then
      -- QI1: the objective's row stands for the quest.
      changed = true
    elseif name == "STARTS_QUEST" and objective ~= nil and not hidePredicted then
      -- FX14: a start of ours and a Predicted objective, one row: the start's, with the count.
      changed = true
      if not folded[edge.target] then
        folded[edge.target] = true
        out[#out + 1] = startWithCount(edge, objective)
      end
    elseif name == "QUEST_OBJECTIVE" and predicted and (trusted or (ours[edge.target] and not hidePredicted)) then
      -- FX14: folded into the start's row above, or a trusted objective carries the count.
      changed = true
    else
      out[#out + 1] = edge
    end
  end
  if not changed then
    return edges
  end
  return out
end

-- Brief QS1 (the owner's ruling A of 2026-10-14): a quest of the other faction is not a use of the
-- player's item at all, so an item's Used by leaves it out (Core/Keep.lua Keep.OtherSideQuest is the
-- same rule for the counts). Its own quest page and search are unchanged. ViewModel.playerSide
-- states the player's side ("Alliance" or "Horde") for a spec; otherwise it is Core/Sources.lua's
-- Favour.PlayerFaction (the pretend side first), asked as the root list is built. nil while not known,
-- and then nothing is left out.
-- Brief F155: the side itself is Core/Graph.lua's Graph.PlayerSide (the same Favour.PlayerFaction
-- read), behind this file's own spec seam.
ViewModel.playerSide = nil
function ViewModel.PlayerSide()
  if ViewModel.playerSide == "Alliance" or ViewModel.playerSide == "Horde" then
    return ViewModel.playerSide
  end
  return Graph.PlayerSide()
end

-- Brief F155 (owner QA 2026-10-14 item 155): whether "Hide other faction data" is on for a view
-- built with opts. A caller that states opts.hideOtherFaction is taken at its word (a spec, a persona
-- case); one that does not (the window passes only the options it always passed) is answered from
-- the saved setting (Core/Graph.lua Graph.HidesOtherFaction), on by default.
function ViewModel.HidesOtherSide(opts)
  if type(opts) == "table" and opts.hideOtherFaction ~= nil then
    return opts.hideOtherFaction ~= false
  end
  return Graph.HidesOtherFaction()
end

-- Brief F155: the side a view built with opts hides the other side's rows from: the character's
-- own side ("Alliance" or "Horde", ViewModel.PlayerSide) while the setting is on, else nil, and then
-- nothing is left out. QS1's quests, the trainers' and the vendors' rows all follow it.
function ViewModel.HiddenSide(opts)
  if not ViewModel.HidesOtherSide(opts) then
    return nil
  end
  return ViewModel.PlayerSide()
end

function VM:_HiddenSide()
  return ViewModel.HiddenSide(self.opts)
end

-- Brief F155: the side the held child walks and summary lists were made for, and those caches let
-- go once it moves (the setting or the pretend side changed under an open view). Answers the side.
function VM:_SideCaches()
  local side = self:_HiddenSide()
  if self.cachedSide ~= side then
    self.children = {}
    self.more = {}
    self.listRows = nil
    self.cachedSide = side
  end
  return side
end

-- The side numbers a quest's side is stated in (Core/Keep.lua's: 1 Alliance, 2 Horde).
local SIDE_NUMBERS = { Alliance = 1, Horde = 2 }

-- Brief QS1: edges less every quest edge whose quest is for the other side than playerSide
-- ("Alliance" or "Horde"), its side read by Core/Graph.lua Graph.QuestSide. A quest for both sides
-- or one whose side nobody states stays, and so does everything while playerSide is not known. The
-- list is the caller's and is not written into; the same list comes back where nothing is left out.
-- Brief RB2: an item row of the other side alone (Graph.ItemSide) goes too. Pure over the shipped
-- listing.
function ViewModel.WithoutOtherSideQuests(edges, playerSide)
  local mine = SIDE_NUMBERS[playerSide]
  if type(edges) ~= "table" or #edges == 0 or mine == nil then
    return edges
  end
  local out, dropped = {}, false
  for _, edge in ipairs(edges) do
    local def = type(edge) == "table" and edge.type or nil
    local side = nil
    if type(def) == "table" and def.target == "quest" then
      side = Graph.QuestSide(edge.faction, edge.target)
    elseif type(edge) == "table" and Graph.Kind(edge.target) == "item" then
      -- Brief RB2 (owner QA 2026-10-17 item 191): an item of the other side alone goes with its
      -- quests (Core/Graph.lua Graph.ItemSide, Crest of Lordaeron 275521 for the Alliance).
      local _, itemId = Graph.Parse(edge.target)
      side = Graph.ItemSide(itemId)
    end
    if side ~= nil and side ~= mine then
      dropped = true
    else
      out[#out + 1] = edge
    end
  end
  if not dropped then
    return edges
  end
  return out
end

-- Brief AA-RB (the owner's QA item 219, 2026-10-17: "When we know there are uses (but not for your
-- current faction) make the wording 'No known uses for [your_faction]'"): the line an item's empty Used
-- by tab draws where "Hide other faction data" took its rows out: "No known uses for Alliance" (side,
-- the side the view hides from, the player's own) where a quest of the other side alone asks for the
-- item or is started by it (Graph.Summary's questSides), else nil and the tab keeps "No known uses".
-- The literals are written out so the locale sweep sees them. Pure over the shipped listing.
function ViewModel.NoUsesText(root, side)
  local mine = SIDE_NUMBERS[side]
  if mine == nil or Graph.Kind(root) ~= "item" then
    return nil
  end
  local _, itemId = Graph.Parse(root)
  itemId = tonumber(itemId)
  if itemId == nil then
    return nil
  end
  local ok, summary = pcall(Graph.Summary, itemId)
  local sides = ok and type(summary) == "table" and summary.questSides or nil
  if type(sides) ~= "table" or (tonumber(sides[3 - mine]) or 0) <= 0 then
    return nil
  end
  if mine == 1 then
    return L["No known uses for Alliance"]
  end
  return L["No known uses for Horde"]
end

-- Brief CH1: the line an NPC's empty Quests tab draws where "Hide other faction data" took its rows
-- out: "No known quests for Alliance" (the player's own side) where a row the tab would otherwise
-- draw is a quest of the other side alone (Graph.HidesEdge; a Predicted row only while predicted
-- data is shown), else nil and the tab keeps "No quests known for this NPC". The literals are
-- written out so the locale sweep sees them.
function VM:_NoQuestsText()
  local side = self:_HiddenSide()
  local mine = SIDE_NUMBERS[side]
  if mine == nil then
    return nil
  end
  local hidPredicted = type(self.opts) == "table" and self.opts.showPredicted == false
  local hid = false
  for _, edge in ipairs(self:_NpcEdges(NPC_EDGES[Edges.QUESTS])) do
    if Graph.HidesEdge(edge, side) and not (hidPredicted and edge.confidence == Confidence.PREDICTED) then
      hid = true
      break
    end
  end
  if not hid then
    return nil
  end
  if mine == 1 then
    return L["No known quests for Alliance"]
  end
  return L["No known quests for Horde"]
end

-- Brief F155: the side words a Used by quest row of the other side says ("Horde only", the words
-- UI/Tree.lua Tree.FactionOnlyText says on a source row), or nil: the player's own side, both sides, a
-- quest whose side nothing states, a character whose side is not known and every edge that is not
-- one of the item's quests (Core/Graph.lua Graph.SIDE_QUEST_TYPES). Such a row only stands while
-- "Hide other faction data" is off. Pure over the shipped listing.
local OTHER_SIDE_WORDS = { [1] = "Alliance only", [2] = "Horde only" }
function ViewModel.OtherSideWords(edge, questKey)
  local def = type(edge) == "table" and edge.type or nil
  if type(def) ~= "table" or not Graph.SIDE_QUEST_TYPES[def.name] then
    return nil
  end
  local mine = SIDE_NUMBERS[ViewModel.PlayerSide()]
  local side = Graph.QuestSide(edge.faction, questKey or edge.target)
  if mine == nil or (side ~= 1 and side ~= 2) or side == mine then
    return nil
  end
  return L[OTHER_SIDE_WORDS[side]]
end

-- Brief RB2 (owner QA 2026-10-17 item 194): "Possibly Alliance only" or "Possibly Horde only" for a
-- Used by quest row (Core/Graph.lua Graph.SIDE_QUEST_TYPES) whose quest is open to both sides and
-- leans to the side that is not the player's (Graph.LeanWords, ItemTree-Data RB3's lean lists), or
-- nil: the leaning side's player, a quest that leans nowhere or is sided outright, a character
-- whose side is not known. Never hides the row. Pure over the shipped listing.
function ViewModel.LeanWords(edge, questKey)
  local def = type(edge) == "table" and edge.type or nil
  if type(def) ~= "table" or not Graph.SIDE_QUEST_TYPES[def.name] then
    return nil
  end
  return Graph.LeanWords(questKey or edge.target, ViewModel.PlayerSide())
end

-- Brief F155: a row's second column with the side words after what it already says ("Event, Horde
-- only"), or as it stood where there are none. Pure.
function ViewModel.WithSideWords(meta, words)
  if type(words) ~= "string" or words == "" then
    return meta
  end
  if type(meta) == "string" and meta ~= "" then
    return meta .. ", " .. words
  end
  return words
end

-- The options the root's own walk is made with. Brief GS3: only the Sources view asks for the
-- guessed sources, and only while they are shown, so with "Show guessed sources" or "Show
-- predicted data" off the walk is exactly the walk it was before guesses existed.
-- Brief F155: with the side "Hide other faction data" hides from (VM:_HiddenSide).
function VM:_RootWalkOpts()
  if self.view == Edges.SOURCES and guessSourcesShown(self.opts) then
    return sided(GUESS_WALK_OPTS, self:_HiddenSide())
  end
  return sided(WALK_OPTS, self:_HiddenSide())
end

function VM:_RootEdges()
  -- Brief Z1: a zone's Here tab, which no graph walk answers either.
  if self.view == Edges.HERE then
    return self:_ZoneEdges()
  end
  local rootKind = Graph.Kind(self.root)
  local method = NPC_EDGES[self.view]
  if rootKind == "object" then
    method = OBJECT_EDGES[self.view]
  end
  if not method then
    local walked = Graph.Children(self.root, self.direction, self:_RootWalkOpts())
    if self.view == Edges.USES and rootKind == "item" then
      -- Brief QI1: one row per quest where the item starts it and is asked for by it. Brief FX14:
      -- a Predicted objective folds into a start of ours only while predicted data is shown.
      walked = ViewModel.OneRowPerQuest(walked, self.opts.showPredicted == false)
      -- Brief QS1: the other side's quests are no use of the player's item. Brief F155: only while
      -- "Hide other faction data" is on (VM:_HiddenSide), which the walk above already obeyed.
      return ViewModel.WithoutOtherSideQuests(ViewModel.WithoutContents(self.root, walked), self:_HiddenSide())
    end
    return walked
  end
  local known = self:_NpcEdges(method)
  -- Brief CH1 (with item 270's note): an NPC's Quests tab leaves out the quests of the other side
  -- alone while "Hide other faction data" is on (Graph.HidesEdge, Graph.SIDE_GIVER_QUEST_TYPES), sided
  -- by the read its rows' "Horde only" words come from; off, they stay with those words.
  if self.view == Edges.QUESTS then
    known = Graph.WithoutOtherSide(known, self:_HiddenSide())
  end
  -- Brief OL2: one row per item on a chest's Loot tab and an openable item's Contains tab.
  local folds = LOOT_FOLD_VIEWS[rootKind]
  if folds and folds[self.view] then
    return ViewModel.FoldLootByItem(known)
  end
  -- Brief C5: a creature's Loot tab also lists what ItemTree's model guesses it drops, after the
  -- known groups and only while guesses are shown.
  if self.view == Edges.LOOT and rootKind == "npc" and guessSourcesShown(self.opts) then
    local guesses = ViewModel.CreatureGuessEdges(self.root, known)
    if #guesses > 0 then
      local out = {}
      for _, edge in ipairs(known) do
        out[#out + 1] = edge
      end
      for _, edge in ipairs(guesses) do
        out[#out + 1] = edge
      end
      return out
    end
  end
  return known
end

-- An NPC tab's own edges: the shipped table's answer for the tab joined to the player's records.
--
-- Brief EK1 2b step 1: a row both name (a Forever page that joins a Classic Era name, the player's
-- or the client's row for an item the Classic Era table names too) is ONE row, the live one, and
-- it keeps what the Classic Era row showed: the rule an item's Sources view already keeps for the
-- same pair (brief B7, Core/Graph.lua Graph.AdoptSourceFacts). The live row takes over the Classic
-- Era row's zone and its link, its side and title, the creature it names and its qualifier where
-- it states none of its own, and keeps the Classic Era drop rate (eraRate), which its tooltip
-- names and its rate column draws where it states none (brief BQ10). The live edge is copied
-- first, so the graph's own is never written into.
function VM:_NpcEdges(method)
  local live = Graph.Children(self.root, self.direction, WALK_OPTS)
  local era = ItemTree.eraSources
  local edges = EMPTY
  if type(era) == "table" and type(era[method]) == "function" then
    local ok, answer = pcall(era[method], era, self.root)
    if ok and type(answer) == "table" then
      edges = answer
    end
  end
  if #live == 0 then
    return edges
  end
  local out, held = {}, {}
  for _, edge in ipairs(live) do
    if edge.type and Edges.InView(edge.type, self.view) then
      out[#out + 1] = edge
      held[edge.type.name .. "\0" .. tostring(edge.target)] = #out
    end
  end
  -- Brief CT1b (the pre-QA review's M3): no live edge belongs to this tab (a class trainer's quest
  -- giver or vendor record is another tab's), so the answer is the table's alone, handed on as it
  -- came, exactly what the loop below would copy edge for edge. A class trainer's Teaches tab then
  -- keeps the shared class list it is kept against (VM:_ClassTab).
  if #out == 0 then
    return edges
  end
  for _, edge in ipairs(edges) do
    local at = edge.type and held[edge.type.name .. "\0" .. tostring(edge.target)] or nil
    if not at then
      out[#out + 1] = edge
    elseif edge.historical and not out[at].historical then
      local copy = {}
      for field, value in pairs(out[at]) do
        copy[field] = value
      end
      out[at] = Graph.AdoptSourceFacts(copy, edge)
    end
  end
  return out
end

--------------------------------------------------------------------------------
-- A zone's Here tab (brief Z1)
--------------------------------------------------------------------------------

-- One method of the shipped table's reader, pcall'd, answering its first two results or nil.
local function eraCall(method, ...)
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era[method]) ~= "function" then
    return nil
  end
  local ok, first, second = pcall(era[method], era, ...)
  if not ok then
    return nil
  end
  return first, second
end

--------------------------------------------------------------------------------
-- A creature's Predicted loot (brief C5)
--------------------------------------------------------------------------------

-- The group a creature's guessed drops are filed under. Its id, glyph and place are in GROUP_IDS,
-- GROUP_ICONS and GROUP_ORDER above.
ViewModel.PREDICTED_GROUP = "Predicted"

-- The creature ids an npc key's guesses can name as a creature new in Forever (Core/GuessSources.lua
-- specific type 5): the key's own id where it is a real one, and for a made up Classic Era key the
-- unit the page was last opened from this session (Core/CreatureLookup.lua Origin), which is the
-- only creature id such a page knows.
local function guessCreatureIds(rootKey, id)
  local out = {}
  if id > 0 and id == math.floor(id) then
    out[1] = id
    return out
  end
  local lookup = ItemTree.CreatureLookup
  if type(lookup) == "table" and type(lookup.Origin) == "function" then
    local ok, origin = pcall(lookup.Origin, rootKey)
    local npcId = ok and type(origin) == "table" and tonumber(origin.npcId) or nil
    if npcId and npcId > 0 and npcId == math.floor(npcId) then
      out[1] = npcId
    end
  end
  return out
end

--- Brief C5: the Loot tab edges of the items ItemTree's model guesses a creature drops, the way the
--- Boss loot tab's Predicted rows are found (UI/BossLoot.lua UIBossLoot.GuessRows): the type 5
--- guesses for the creature's id (R:ItemsForCreature) and the type 1 guesses for the Classic Era
--- name the key joins, by that name's creature id (brief EK2: E:CreatureIdAt,
--- R:ItemsForEraCreature). An item two guesses name is listed
--- once, at its stronger guess; one among the known edges is left out, since a real row always
--- replaces a guess, and so is one no player can get (Data:IsHidden). Strong before Likely, then by
--- item id. Empty for anything but an npc key, or while the reader answers nothing (either setting
--- off, the module absent or refused).
---
---   { type = CREATURE_DROPS, target = "item:<id>", group = "Predicted", confidence = GUESS,
---     basis = BASIS_GUESS, provenance = "guess", guess = { strength, why, whyWords } }
function ViewModel.CreatureGuessEdges(rootKey, known)
  local out = {}
  local reader = ItemTree.guessSources
  local kind, id = Graph.Parse(rootKey)
  if type(reader) ~= "table" or kind ~= "npc" or type(id) ~= "number" then
    return out
  end
  local found = {}
  local function gather(method, ref)
    if type(reader[method]) ~= "function" or type(ref) ~= "number" then
      return
    end
    local ok, guesses = pcall(reader[method], reader, ref)
    for _, guess in ipairs(ok and type(guesses) == "table" and guesses or EMPTY) do
      if type(guess) == "table" and type(guess.item) == "number" then
        found[#found + 1] = guess
      end
    end
  end
  for _, creatureId in ipairs(guessCreatureIds(rootKey, id)) do
    gather("ItemsForCreature", creatureId)
  end
  gather("ItemsForEraCreature", eraCall("CreatureIdAt", rootKey))
  if #found == 0 then
    return out
  end
  table.sort(found, function(a, b)
    local left, right = tonumber(a.strength) or 9, tonumber(b.strength) or 9
    if left ~= right then
      return left < right
    end
    return a.item < b.item
  end)
  local taken = {}
  for _, edge in ipairs(type(known) == "table" and known or EMPTY) do
    if type(edge) == "table" and edge.target ~= nil then
      taken[edge.target] = true
    end
  end
  local GuessSources = ItemTree.GuessSources
  local provenance = type(GuessSources) == "table" and GuessSources.PROVENANCE or "guess"
  for _, guess in ipairs(found) do
    local target = Graph.Key("item", guess.item)
    local hidden = false
    if type(Data.IsHidden) == "function" then
      local ok, answer = pcall(Data.IsHidden, Data, guess.item)
      hidden = ok and answer and true or false
    end
    if not taken[target] and not hidden then
      taken[target] = true
      out[#out + 1] = {
        type = Edges.Types.CREATURE_DROPS,
        target = target,
        group = ViewModel.PREDICTED_GROUP,
        confidence = Confidence.GUESS,
        basis = Confidence.BASIS_GUESS,
        provenance = provenance,
        guess = { strength = guess.strength, why = guess.why, whyWords = guess.whyWords },
      }
    end
  end
  return out
end

-- The player's own records a zone lists, by the record's kind: the group it is filed under (the
-- shipped rows' own words, so a drop the player saw and a Classic Era drop are one category), the
-- up type its columns are worded as, and whose pins its name has.
local ZONE_RECORDS = {
  drop = { group = "Drops from", as = "DROPPED_BY", kind = "npc" },
  vendor = { group = "Sold by", as = "SOLD_BY", kind = "npc" },
  gather = { group = "Gathered from", as = "GATHERED_FROM", kind = "object" },
  fish = { group = "Fished in", as = "FISHED_FROM", kind = "object" },
}

-- The player's own records for one zone, out of the collector (Core/Collector.lua C:ZoneRecords):
-- { kind, itemId, name, count }, the most seen first. Empty with no collector loaded.
function ViewModel.ZoneRecords(areaName)
  local collector = ItemTree.collector
  if type(collector) ~= "table" or type(collector.ZoneRecords) ~= "function" then
    return {}
  end
  local ok, records = pcall(collector.ZoneRecords, collector, areaName)
  if not ok or type(records) ~= "table" then
    return {}
  end
  return records
end

-- The pick one of those records gives the Map tab: the name's place in the shipped string table
-- and whose pins it has, or nil for a name the table does not know. A gathering record's node is
-- filed as the table files it, so a vein the player mined reads under "Mined from".
local function recordPick(record, spec)
  if not record.name then
    return nil, spec.group
  end
  local nameIndex = eraCall("NameIndexOf", record.name)
  if type(nameIndex) ~= "number" then
    return nil, spec.group
  end
  local group = spec.group
  if record.kind == "gather" then
    local EraSources = ItemTree.EraSources
    local era = ItemTree.eraSources
    local source = type(era) == "table" and type(era.Table) == "function" and era:Table() or nil
    local word = type(EraSources) == "table"
        and type(EraSources.ObjectKind) == "function"
        and EraSources.ObjectKind(source, nameIndex)
      or nil
    if word == "vein" then
      group = "Mined from"
    end
  end
  return { nameIndex = nameIndex, kind = spec.kind, name = record.name }, group
end

-- Brief Z4: the Boss loot place of an instance zone, or nil for a zone that is not an instance or
-- that the index lists no place for: { id, name, new, model }, id the place's position in the
-- index, new true where the place is new in Forever (g = 1) and model the shared Boss loot model
-- (Core/BossLoot.lua BossLoot.Shared) that read it. Loads the Boss loot index, so only an instance's
-- own page asks.
function ViewModel.InstancePlace(rootKey)
  if type(rootKey) ~= "string" or Graph.Kind(rootKey) ~= "zone" then
    return nil
  end
  local facts = eraCall("ZoneFacts", rootKey)
  if type(facts) ~= "table" or not facts.instance or type(facts.areaId) ~= "number" then
    return nil
  end
  local BossLoot = ItemTree.BossLoot
  if type(BossLoot) ~= "table" or type(BossLoot.Shared) ~= "function" or type(BossLoot.PlaceOfArea) ~= "function" then
    return nil
  end
  local model = BossLoot.Shared()
  local ok, index = pcall(model.Index, model)
  if not ok or type(index) ~= "table" then
    return nil
  end
  local id, place = BossLoot.PlaceOfArea(index, facts.areaId)
  if not id then
    return nil
  end
  local name = type(place.n) == "number" and index.s[place.n] or nil
  return { id = id, name = name or facts.name, new = tonumber(place.g) == 1, model = model }
end

-- Brief Z4: a Forever only instance's drops (M:PlaceDrops' rows) as its Here tab's edges, under
-- "Drops from" (which the tab calls "Dropped here"), each naming its boss in the source column and
-- carrying the Boss loot tab's own mark: seen with its tally, Predicted out of the Classic Era loot
-- with its chance, or a guess. No pick: nothing inside an instance has a map pin. Pure.
function ViewModel.BossDropEdges(rows, areaId)
  local out = {}
  local GuessSources = ItemTree.GuessSources
  local EraSources = ItemTree.EraSources
  for _, row in ipairs(type(rows) == "table" and rows or EMPTY) do
    if type(row) == "table" and type(row.id) == "number" then
      local edge = {
        type = Edges.Types.ZONE_HOLDS,
        target = Graph.Key("item", row.id),
        group = L["Drops from"],
        zone = row.bossName,
        confidence = row.confidence,
        basis = row.basis,
        note = row.note,
        as = "DROPPED_BY",
        areaId = areaId,
      }
      if row.guess ~= nil then
        edge.guess = row.guess
        edge.provenance = type(GuessSources) == "table" and GuessSources.PROVENANCE or "guess"
      elseif row.verified then
        edge.seen = tonumber(row.seen) or nil
      else
        edge.percent = row.chance
        edge.provenance = type(EraSources) == "table" and EraSources.PROVENANCE or nil
        edge.percentSource = row.chance and edge.provenance or nil
        edge.historical = true
      end
      out[#out + 1] = edge
    end
  end
  return out
end

-- Brief PS2: which area each zone map belongs to, out of the Classic Era table's own area to map
-- join (zm, EraSources.MapOf): { [uiMap] = areaId }. A map only one area is drawn on is that area's;
-- a map a zone shares with its subzones (Westfall's with Longshore's and Westfall Lighthouse's) is
-- the area the table files the most rows under (counts[areaId], the Here tab's own area index),
-- which is the zone itself, the lower id on a tie. Pure.
function ViewModel.MapOwners(zm, counts)
  local out, held = {}, {}
  for areaId, uiMap in pairs(type(zm) == "table" and zm or EMPTY) do
    if type(areaId) == "number" and type(uiMap) == "number" then
      local rows = type(counts) == "table" and tonumber(counts[areaId]) or 0
      local best = held[uiMap]
      if not best or rows > best.rows or (rows == best.rows and areaId < best.areaId) then
        held[uiMap] = { areaId = areaId, rows = rows }
        out[uiMap] = areaId
      end
    end
  end
  return out
end

local mapOwners = { era = nil, owners = nil }

-- Whether a zone page's area is the one its zone map belongs to (ViewModel.MapOwners), worked out
-- once per Classic Era table out of the area index the Here tab builds anyway. Local data only.
local function ownsMap(areaId, uiMap)
  local era = ItemTree.eraSources
  local source = type(era) == "table" and type(era.Table) == "function" and era:Table() or nil
  if type(source) ~= "table" or type(uiMap) ~= "number" then
    return false
  end
  if mapOwners.era ~= source then
    local index = eraCall("_AreaIndex")
    local counts = {}
    for area, byCategory in pairs(type(index) == "table" and type(index.areas) == "table" and index.areas or EMPTY) do
      local rows = 0
      for _, bucket in pairs(byCategory) do
        rows = rows + #bucket
      end
      counts[area] = rows
    end
    mapOwners.owners = ViewModel.MapOwners(source.zm, counts)
    mapOwners.era = source
  end
  return mapOwners.owners[uiMap] == areaId
end

-- The player sourced rows group by the collector's record kind, as ZONE_RECORDS files them.
local ZONE_SHIPPED = { vendor = true, drop = true, gather = true }

-- Brief PS2: the shipped player sourced rows (Core/PlayerSources.lua) one zone lists, as its Here
-- edges: every row the module places on the zone's map (PlayerSources.MapRows), for the area that
-- map belongs to only, and none for an instance (no map). Plain data like the item page's rows: the
-- "mined" tier with no check, the provenance "player", the vendor's price and cost, and the npc
-- whose page the source name opens. A fact the player's own records state is left to their row,
-- so it is one row. Empty with no module. facts is E:ZoneFacts' answer.
function ViewModel.PlayerZoneEdges(facts)
  local PlayerSources = ItemTree.PlayerSources
  if type(PlayerSources) ~= "table" or type(PlayerSources.MapRows) ~= "function" then
    return EMPTY
  end
  if type(facts) ~= "table" or type(facts.map) ~= "number" or not ownsMap(facts.areaId, facts.map) then
    return EMPTY
  end
  local rows = PlayerSources.MapRows(facts.map)
  if #rows == 0 then
    return EMPTY
  end
  local collector = ItemTree.collector
  local out = {}
  for _, row in ipairs(rows) do
    local own = false
    if type(collector) == "table" and type(collector.HasFact) == "function" then
      local ok, answer = pcall(collector.HasFact, collector, row.kind, row.itemId, row.sourceKind, row.sourceId)
      own = ok and answer == true
    end
    if ZONE_SHIPPED[row.kind] and not own then
      local spec = ZONE_RECORDS[row.kind]
      local name = PlayerSources.SourceName(row.sourceKind, row.sourceId)
      if not name and row.kind == PlayerSources.VENDOR_KIND then
        local vendors = ItemTree.ForeverVendors
        name = type(vendors) == "table" and type(vendors.Label) == "function" and vendors.Label(row.sourceId) or nil
      end
      local pick, group = recordPick({ kind = row.kind, name = name }, spec)
      local sale = row.sale or EMPTY
      out[#out + 1] = {
        type = Edges.Types.ZONE_HOLDS,
        target = Graph.Key("item", row.itemId),
        group = L[group],
        zone = name,
        confidence = Confidence.MINED,
        provenance = PlayerSources.PROVENANCE,
        price = sale.copper,
        cost = sale.cost,
        as = spec.as,
        areaId = facts.areaId,
        pick = pick,
        -- Brief N1: the npc whose page the source name opens.
        npc = row.sourceKind == "npc" and row.sourceId or nil,
      }
    end
  end
  return out
end

-- A zone root's Here edges: the player's own records for the zone first, each with its tally in
-- seen, then every Classic Era row the table states there (Core/EraSources.lua E:ZoneEdges). A
-- Classic Era row that names what a record names (the same group, item and source) is dropped:
-- the record is what this client showed. Both are one edge type, filed by group.
--
-- Brief PS2: a record whose fact the installed data ships as a player sourced row is drawn as that
-- plain row, with no check (C:ZoneRecords' shipped). Between the records and the Classic Era rows
-- come the player sourced rows the module places on the zone (ViewModel.PlayerZoneEdges), for every
-- player; a Classic Era row naming the same source and item gives way to one as it does to a record.
function VM:_ZoneEdges()
  local facts = eraCall("ZoneFacts", self.root)
  if type(facts) ~= "table" then
    return EMPTY
  end
  -- Brief PS2: the shipped player rows are built before the records are read, so a record's
  -- shipped mark (Collector.ShipsAsPlayer reads a module already built) answers on the first open.
  local PlayerSources = ItemTree.PlayerSources
  if type(PlayerSources) == "table" and type(PlayerSources.Table) == "function" then
    pcall(PlayerSources.Table)
  end
  local out, held = {}, {}
  local function slot(edge)
    return tostring(edge.group) .. "\0" .. tostring(edge.target) .. "\0" .. string.lower(edge.zone or "")
  end
  for _, record in ipairs(ViewModel.ZoneRecords(facts.name)) do
    local spec = ZONE_RECORDS[record.kind]
    local pick, group = recordPick(record, spec)
    local edge = {
      type = Edges.Types.ZONE_HOLDS,
      target = Graph.Key("item", record.itemId),
      group = L[group],
      zone = record.name,
      seen = record.count,
      confidence = Confidence.VERIFIED,
      as = spec.as,
      areaId = facts.areaId,
      pick = pick,
      -- Brief N1: the npc id the records name the source by, whose page the source name opens.
      npc = record.npcId,
    }
    if record.shipped then
      edge.confidence = Confidence.MINED
      edge.provenance = type(PlayerSources) == "table" and PlayerSources.PROVENANCE or "player"
    end
    out[#out + 1] = edge
    held[slot(edge)] = true
  end
  for _, edge in ipairs(ViewModel.PlayerZoneEdges(facts)) do
    if not held[slot(edge)] then
      out[#out + 1] = edge
      held[slot(edge)] = true
    end
  end
  local shipped = eraCall("ZoneEdges", self.root)
  -- Brief F155: a Classic Era vendor of the other side is no "Sold by" row of this zone for the
  -- character while "Hide other faction data" is on (ViewModel.HidesEraName); the player's own
  -- records above always stay.
  local hidden = self:_HiddenSide()
  for _, edge in ipairs(type(shipped) == "table" and shipped or EMPTY) do
    local pick = edge.as == "SOLD_BY" and type(edge.pick) == "table" and edge.pick or nil
    if not held[slot(edge)] and not (pick and ViewModel.HidesEraName(pick.nameIndex, hidden)) then
      out[#out + 1] = edge
    end
  end
  -- Brief Z4: an instance new in Forever, which the Classic Era table holds no row for, lists what
  -- the Boss loot tab lists for its bosses under Dropped here, one row per item (an item the
  -- player's own records already list there keeps that row), and shows the group even with none.
  if facts.instance then
    local place = ViewModel.InstancePlace(self.root)
    if place and place.new then
      self.keepGroups = { "Drops from" }
      local listed = {}
      for _, edge in ipairs(out) do
        if groupKeyOf(edge.group) == "Drops from" then
          listed[edge.target] = true
        end
      end
      local ok, rows = pcall(place.model.PlaceDrops, place.model, place.id)
      for _, edge in ipairs(ViewModel.BossDropEdges(ok and rows or EMPTY, facts.areaId)) do
        if not listed[edge.target] then
          listed[edge.target] = true
          out[#out + 1] = edge
        end
      end
    end
  end
  return out
end

-- The zone a row's zone column names, as a link to that zone's page ({ key, name }), or nil. The
-- edge's own area where a Classic Era row states one, and otherwise the column's words matched to
-- an area this build names, which is how a zone the player's own records wrote is linked. A column
-- that says something other than a place ("4 zones", "Alliance") links nothing. Never on a zone's
-- own Here tab, whose column holds the source's name instead.
function VM:_ZoneLink(edge, source)
  if self.view == Edges.HERE or type(source) ~= "table" then
    return nil
  end
  local text = source.zone
  if type(text) ~= "string" or text == "" then
    return nil
  end
  local areaId = tonumber(edge.areaId)
  if not areaId then
    areaId = eraCall("AreaIdOf", text)
  end
  if type(areaId) ~= "number" then
    return nil
  end
  return { key = Graph.Key("zone", areaId), name = text }
end

-- Brief CT1b (QA item 227, the owner's hunter trainer pages: 5 to 8 ms a page offline, the tab
-- counts, the tree and the sidebar each building the Teaches tab again on every open, tab press and
-- refresh): a class trainer's Teaches tab over its class list's shared edges (Core/EraSources.lua
-- E:ClassTeachesEdges) is the same tab for every trainer of that list, so what one builds is kept
-- for the next: its categories per option set, and its rows per option set and per state (the
-- level filter, what the player opened or closed). Held weakly by the list, so a list the reader
-- lets go of takes its tabs with it, and checked against the data and collector generations it was
-- built at. ViewModel.Reset drops the lot.
local classTabs = setmetatable({}, { __mode = "k" })
-- At most this many option sets a list, and this many states a set, before each starts over.
local CLASS_TAB_SETS, CLASS_TAB_STATES = 8, 16

function ViewModel.ResetClassTabs()
  classTabs = setmetatable({}, { __mode = "k" })
end

-- The options, the side, the player's class (Keep.PlayerClass, which orders the level groups) and
-- the generations a class trainer's tab depends on, as one string. The level filter is the rows'
-- state, never the categories'.
function VM:_ClassTabSignature()
  local keys = {}
  for key in pairs(self.opts) do
    if key ~= "filter" then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys)
  local parts = {}
  for index, key in ipairs(keys) do
    parts[index] = key .. "=" .. tostring(self.opts[key])
  end
  local keep = ItemTree.Keep
  local class = nil
  if type(keep) == "table" and type(keep.PlayerClass) == "function" then
    local ok, answer = pcall(keep.PlayerClass)
    class = ok and answer or nil
  end
  -- The data build in hand and the collector's records, read as ViewModel.ViewCounts' generations().
  local data, collector = ItemTree.Data, ItemTree.Collector
  local dataGeneration = tonumber(data and data.generation) or 0
  local collectorGeneration = tonumber(collector and collector.generation) or 0
  parts[#parts + 1] = "guessSources=" .. tostring(guessSourcesShown(self.opts))
  parts[#parts + 1] = "side=" .. tostring(self:_HiddenSide())
  parts[#parts + 1] = "class=" .. tostring(class)
  parts[#parts + 1] = "data=" .. tostring(dataGeneration)
  parts[#parts + 1] = "collector=" .. tostring(collectorGeneration)
  return table.concat(parts, ";")
end

-- The kept tab for this view model, { categories, rows = { [state] = held } }, made empty where
-- none is kept yet; nil for any tab but a class trainer's Teaches over its shared class list alone
-- (no recipe, no record of the player's, no profession a Teaches line names, VM:_TeachesLines).
function VM:_ClassTab(edges)
  local EraSources = ItemTree.EraSources
  if
    self.view ~= Edges.TEACHES_VIEW
    or type(EraSources) ~= "table"
    or type(EraSources.IsClassTeachesList) ~= "function"
    or not EraSources.IsClassTeachesList(edges)
    or #ViewModel.TrainerProfessions(self.root) > 0
  then
    return nil
  end
  local sets = classTabs[edges]
  if not sets then
    sets = { count = 0, tabs = {} }
    classTabs[edges] = sets
  end
  local signature = self:_ClassTabSignature()
  local tab = sets.tabs[signature]
  if not tab then
    if sets.count >= CLASS_TAB_SETS then
      sets.count, sets.tabs = 0, {}
    end
    tab = { rows = {}, states = 0 }
    sets.tabs[signature] = tab
    sets.count = sets.count + 1
  end
  return tab
end

--- Brief CT1b (QA item 227, step 3): whether VM:Rows would build a class trainer's Teaches rows now,
--- no trainer of its class list having drawn them in this state yet. UI/Tree.lua builds such rows on
--- the frame after a page opens rather than in the open's own frame.
function VM:RowsWaiting()
  if self.rows or self.view ~= Edges.TEACHES_VIEW then
    return false
  end
  local tab = self:Categories() and self.classTab or nil
  return tab ~= nil and #self.categories > 0 and tab.rows[self:_RowState()] == nil
end

-- The rows' state as one string: the level filter, the search, and what the player opened, closed
-- or drew in full.
function VM:_RowState()
  local parts = { "filter=" .. tostring(self.opts.filter), "searching=" .. tostring(self.searching) }
  local marks = {}
  for key, value in pairs(self.expanded) do
    marks[#marks + 1] = "e:" .. tostring(key) .. "=" .. tostring(value)
  end
  for key, value in pairs(self.shown) do
    marks[#marks + 1] = "s:" .. tostring(key) .. "=" .. tostring(value)
  end
  table.sort(marks)
  parts[#parts + 1] = table.concat(marks, ";")
  return table.concat(parts, ";")
end

function VM:Categories()
  if self.categories then
    return self.categories
  end
  -- Brief Q8: a quest's tab is built from what is known about the quest, not from one walk.
  if self.view == ViewModel.QUEST_VIEW then
    self.categories = self:_QuestCategories()
    return self.categories
  end
  -- Brief C2: the Chain tab holds no categories at all. The chain pane draws in the space the two
  -- lists take, the way the Map tab does, so nothing is walked for a list nobody sees.
  if self.view == ViewModel.CHAIN_VIEW then
    self.categories = {}
    return self.categories
  end
  local groups, order = {}, {}
  -- Brief TR2: a trainer's rank spells are drawn even where the client names no spell.
  if self.view == Edges.TEACHES_VIEW then
    ViewModel.EnsureRankNamer()
  end
  local rootEdges = self:_RootEdges()
  -- Brief CT1b: a class trainer's Teaches tab another trainer of its class list already built.
  local classTab = self:_ClassTab(rootEdges)
  self.classTab = classTab
  if classTab and classTab.categories then
    self.categories = classTab.categories
    return self.categories
  end
  for _, edge in ipairs(rootEdges) do
    if Edges.InView(edge.type, self.view) and self:_EdgeVisible(edge) then
      local groupKey = groupKeyOf(edge.group or edge.type.label)
      local skillLine = groupSkillLine(edge, groupKey)
      local key = skillLine and (groupKey .. "\0" .. tostring(skillLine)) or groupKey
      local group = groups[key]
      if not group then
        -- Brief Z2: a zone's Here tab names its groups for what happens in the zone.
        local word = (self.view == Edges.HERE and ZONE_WORDS[groupKey]) or groupKey
        group = { key = groupKey, label = L[word], skillLine = skillLine, entries = {}, serverSide = false }
        -- Brief CT1: a class trainer's level group (Core/EraSources.lua E:ClassTeachesEdges).
        if type(edge.classSpell) == "table" then
          group.classLevel = tonumber(edge.classSpell.level)
          group.classId = tonumber(edge.classSpell.classId)
        end
        groups[key] = group
        order[#order + 1] = group
      end
      group.entries[#group.entries + 1] = edge
      -- A guess says nothing about the server, so it never makes a category read as drop data.
      if edge.guess == nil and Edges.IsServerSide(edge.type) then
        group.serverSide = true
      end
    end
  end

  -- Brief TR2: a trainer's Teaches tab adds a line for a profession its rows cannot rank.
  if self.view == Edges.TEACHES_VIEW then
    self:_TeachesLines(groups, order)
  end

  -- Brief Z4: a group the root's edges asked to keep (a Forever instance's Dropped here) is drawn
  -- with a count of 0 where nothing is known yet, rather than left out.
  for _, groupKey in ipairs(self.view == Edges.HERE and self.keepGroups or EMPTY) do
    if not groups[groupKey] then
      local word = ZONE_WORDS[groupKey] or groupKey
      local group = { key = groupKey, label = L[word], entries = {}, serverSide = false, keep = true }
      groups[groupKey] = group
      order[#order + 1] = group
    end
  end

  -- The level, class and skill a node asks of the player. They are requirements, so they belong
  -- to the Requires view and to no other: under Used by or Sources they were answering a
  -- question nobody asked, which is what the third tab is for.
  local requirements = self.view == Edges.REQUIRES and Graph.Requirements(self.root) or EMPTY
  if #requirements > 0 then
    local group = { key = REQUIREMENTS_GROUP, label = L[REQUIREMENTS_GROUP], entries = {}, serverSide = false }
    for index, requirement in ipairs(requirements) do
      group.entries[index] = { requirement = requirement }
    end
    order[#order + 1] = group
  end

  -- Brief TB10: a class locked consumable's own use (Core/Keep.lua ClassUse), one row under Used
  -- by in the words the tooltip's Keep block says, so the page and the tooltip agree. Drawn the
  -- way a requirement row is: no edge, no node to open.
  local classUse = self.view == Edges.USES and ViewModel.ClassUseLabel(self.root) or nil
  if classUse then
    local group = { key = CLASS_USE_GROUP, label = L["Class use"], entries = {}, serverSide = false }
    group.entries[1] = { requirement = { label = classUse, classUse = true } }
    order[#order + 1] = group
  end

  -- Brief BQ14 (QA item 14): Used by's profession headers carry the qualities their recipes make.
  if self.view == Edges.USES then
    ViewModel.MarkQualities(order, self.root)
  end

  disambiguate(order)
  for _, group in ipairs(order) do
    self:_SortEntries(group)
    self:_FinishCategory(group)
  end
  table.sort(order, function(a, b)
    if a.order ~= b.order then
      return a.order < b.order
    end
    return a.label < b.label
  end)
  self.categories = order
  if classTab then
    classTab.categories = order
  end
  return order
end

function VM:_Push(rows, row)
  rows[#rows + 1] = row
  self.index[row.key] = row
  return row
end

function VM:_Changes(node)
  if self.opts.showChanges == false then
    return EMPTY
  end
  local diffKind = DIFF_KINDS[node.kind]
  if not diffKind then
    return EMPTY
  end
  -- A discovered item carries one line and no change of its own: the baseline had the Item row
  -- and would not name it, and this build does, which is news worth a row even though no field
  -- moved. Diff.GetChanges is what writes the line, so the row reads the same everywhere.
  if not Diff.IsChanged(diffKind, node.id) and not Diff.IsDiscovered(diffKind, node.id) then
    return EMPTY
  end
  return Diff.GetChanges(diffKind, node.id)
end

function VM:_Badges(node, edge)
  local badges = {}
  local diffKind = DIFF_KINDS[node.kind]
  if diffKind then
    for _, badge in ipairs(Diff.Badges(diffKind, node.id)) do
      if badgeAllowed(self.opts, badge) then
        badges[#badges + 1] = badge
      end
    end
  end
  local confidenceBadge = edge and Confidence.Badge(edge.confidence) or nil
  -- Brief Q1: a Classic Era quest row whose quest the Forever client lists wears no mark: the
  -- quest exists in Forever, and only its counts are Classic Era's.
  if confidenceBadge and edge.listed == true then
    confidenceBadge = nil
  end
  -- Brief QB2: a Classic Era reward the quest no longer hands over in Forever (the client's quest
  -- cache, Core/QuestFlags.lua MarkReward) wears the Changed mark in place of Predicted: what it says
  -- is known now, and it is "changed in Forever" (UI/Tree.lua BadgeBasis words the hover).
  if edge and edge.rewardChanged == true then
    confidenceBadge = nil
    local held = false
    for _, badge in ipairs(badges) do
      held = held or badge == "changed"
    end
    if not held and badgeAllowed(self.opts, "changed") then
      badges[#badges + 1] = "changed"
    end
  end
  -- Brief TW1 (the owner's ruling "B", 2026-10-18): a class trainer's spell that Forever's recorded
  -- list holds and no Classic Era list of the class does (Core/EraSources.lua E:_ForeverClassEdges)
  -- wears the New in Forever mark, once.
  if edge and edge.newInForever == true and badgeAllowed(self.opts, "new") then
    local held = false
    for _, badge in ipairs(badges) do
      held = held or badge == "new"
    end
    if not held then
      badges[#badges + 1] = "new"
    end
  end
  if confidenceBadge then
    badges[#badges + 1] = confidenceBadge
  end
  return badges
end

--------------------------------------------------------------------------------
-- What a node yields, and the icon it wears for it (brief Q9b)
--------------------------------------------------------------------------------

-- The owner on "Mined in / Found in etc. all use a recipe icon": a herb, a vein, a fishing pool
-- or a chest row wore the note glyph every object node shares. A node row and a node page now
-- wear the icon of what the node yields: a vein the ore's (Truesilver Deposit wears Truesilver
-- Ore's), a herb the herb's, a fishing school the fish's, and a chest the chest glyph. Where no
-- yield is known the glyph of the node's own kind stands in, never the note.
ViewModel.NODE_GLYPHS = {
  herb = "CAT_HERBALISM",
  vein = "CAT_MINING",
  fished = "CAT_FISH_SCHOOL",
  object = "CAT_CHEST",
}

-- The kind word an edge files a node under where the shipped table names none (a live object the
-- collector saw, or a node the table ships no pins for): by the edge type, and for a gathering
-- edge by its group, which is the one thing that tells a vein from a herb.
local NODE_KIND_BY_EDGE = { FISHED_FROM = "fished", LOOTED_FROM = "object" }

-- "herb", "vein", "fished" or "object" for one object key, or nil. The shipped table's own word
-- first (E:ObjectAt and EraSources.ObjectKind, two lookups and nothing decoded), then the edge's.
function ViewModel.NodeKind(nodeKey, edge)
  local kind = Graph.Parse(nodeKey)
  if kind ~= "object" then
    return nil
  end
  local era = ItemTree.eraSources
  local EraSources = ItemTree.EraSources
  if
    type(era) == "table"
    and type(era.ObjectAt) == "function"
    and type(era.Table) == "function"
    and type(EraSources) == "table"
    and type(EraSources.ObjectKind) == "function"
  then
    local ok, nameIndex = pcall(era.ObjectAt, era, nodeKey)
    if ok and type(nameIndex) == "number" then
      local okTable, source = pcall(era.Table, era)
      local okKind, word = pcall(EraSources.ObjectKind, okTable and source or nil, nameIndex)
      if okKind and type(word) == "string" then
        return word
      end
    end
  end
  local def = type(edge) == "table" and edge.type or nil
  local name = type(def) == "table" and def.name or nil
  if NODE_KIND_BY_EDGE[name] then
    return NODE_KIND_BY_EDGE[name]
  end
  if name == "GATHERED_FROM" then
    if edge.group == L["Mined from"] or edge.group == "Mined from" then
      return "vein"
    end
    return "herb"
  end
  return nil
end

-- The item key a node yields, or nil. In order:
--   1. the item the row is under, where the row is one of that item's sources (an up edge whose
--      owner is an item): Truesilver Deposit under Truesilver Ore yields Truesilver Ore;
--   2. the item a Classic Era gathering node row is keyed by (EraSources.NodeAt), which is the
--      item whose Sources view drew it;
--   3. the node's first "gives" edge on the graph (a down edge to an item, the collector's own
--      record of what the node gave), which is how a node page with no item in its key answers.
function ViewModel.NodeYield(nodeKey, ownerKey, edge)
  local kind, id = Graph.Parse(nodeKey)
  if kind ~= "object" then
    return nil
  end
  local def = type(edge) == "table" and edge.type or nil
  if type(ownerKey) == "string" and Graph.Kind(ownerKey) == "item" and type(def) == "table" and def.dir == Edges.UP then
    return ownerKey
  end
  local EraSources = ItemTree.EraSources
  if type(EraSources) == "table" and type(EraSources.NodeAt) == "function" then
    local ok, itemId = pcall(EraSources.NodeAt, id)
    if ok and type(itemId) == "number" then
      return Graph.Key("item", itemId)
    end
  end
  local ok, gives = pcall(Graph.Children, nodeKey, Edges.DOWN, WALK_OPTS)
  for _, give in ipairs(ok and type(gives) == "table" and gives or EMPTY) do
    if type(give) == "table" and type(give.target) == "string" and Graph.Kind(give.target) == "item" then
      return give.target
    end
  end
  return nil
end

-- An item's icon by item key, the one Graph.Node already reads for the item's own row (the
-- build's file id, or the client's where the realm found a withheld item), cached per item and
-- dropped when the data or the collector moves on. Never a client item query.
local yieldIcons, yieldGeneration = {}, nil

local function itemIcon(itemKey)
  local data, collector = ItemTree.Data, ItemTree.Collector
  local generation = tostring(data and data.generation) .. ":" .. tostring(collector and collector.generation)
  if generation ~= yieldGeneration then
    yieldIcons, yieldGeneration = {}, generation
  end
  local held = yieldIcons[itemKey]
  if held == nil then
    local node = Graph.Node(itemKey)
    held = (type(node) == "table" and node.icon ~= nil and node.icon) or false
    yieldIcons[itemKey] = held
  end
  return held or nil
end

-- Brief Q9b: the inventory types a set row takes its icon from, best first: the head, then the
-- chest and the robe. The first member of the set in that slot is the one drawn.
ViewModel.SET_ICON_SLOTS = { 1, 5, 20 }

-- The icon one item set row wears: (file, asset). file is the set's head piece's icon, or its chest
-- piece's where it has no head, out of the item records the build ships (a lookup per member, no
-- client call), and asset CAT_SET, which is what draws where there is neither.
function ViewModel.SetIcon(setKey)
  local kind, id = Graph.Parse(setKey)
  if kind ~= "set" then
    return nil, nil
  end
  local data = ItemTree.Data
  local set = type(data) == "table" and type(data.GetSet) == "function" and data:GetSet(id) or nil
  local members = type(set) == "table" and type(set.items) == "table" and set.items or EMPTY
  for _, slot in ipairs(ViewModel.SET_ICON_SLOTS) do
    for _, member in ipairs(members) do
      local item = data:GetItem(member)
      if type(item) == "table" and tonumber(item.it) == slot then
        local file = itemIcon(Graph.Key("item", member))
        if file then
          return file, "CAT_SET"
        end
      end
    end
  end
  return nil, "CAT_SET"
end

-- The icon one node row or node page wears: (file, asset). file is the yield's own icon (a file
-- id or a path) or nil, and asset is the Assets key to wear with no file, which is the glyph of the
-- node's kind and never the note. A chest always wears the chest glyph: its yield is whatever the
-- player is looking at, and the owner asked for the chest. nil, nil for a key that is no object.
function ViewModel.NodeIcon(nodeKey, ownerKey, edge)
  if Graph.Kind(nodeKey) ~= "object" then
    return nil, nil
  end
  local kind = ViewModel.NodeKind(nodeKey, edge)
  -- Brief EO1: a world object that gives quests and is filed under no category (a wanted poster)
  -- wears the quest glyph the client marks it with, never a chest's.
  if kind == nil then
    local era = ItemTree.eraSources
    if type(era) == "table" and type(era.ObjectGiverOnly) == "function" then
      local ok, giver = pcall(era.ObjectGiverOnly, era, nodeKey)
      if ok and giver == true then
        return nil, "CAT_QUEST"
      end
    end
  end
  local asset = ViewModel.NODE_GLYPHS[kind] or ViewModel.NODE_GLYPHS.object
  if kind == "object" then
    return nil, asset
  end
  local yield = ViewModel.NodeYield(nodeKey, ownerKey, edge)
  return yield and itemIcon(yield) or nil, asset
end

-- Graph.Node plus the numbers the edge carries. The graph's own table is never mutated.
--
-- node.seen is how many the collector has watched, which is not how many come at once: the
-- collector adds up every sighting, so the number on a mob is a tally, and drawing it as "x10"
-- read as ten of the item per kill. A tally goes in seen and never in quantity.
--
-- Core/Collector.lua writes it as edge.seen, whatever the edge's confidence: a collected edge
-- that a curated note has since downgraded is still a tally. A store written before the tally
-- had a name of its own put it in edge.quantity on a verified edge, so that is read too.
--
-- That last reading is the legacy one and it must not be applied to an edge type whose quantity
-- the game states (STATED_TYPES): the collector learns that a quest asks for ten of an item, and
-- ten is a quantity, not ten sightings. Without this a learned "Requires" row lost its "x10"
-- while the curated row beside it kept one.
-- Brief S6: the second column of a row that names a quest, out of the meta the edge carries, the
-- quest's title and the zone the edge states. A meta that is the title, or that starts with the
-- title and a comma, keeps only what follows it, else the zone, else nothing; any other meta is
-- kept as it is. Pure.
function ViewModel.QuestRowMeta(meta, title, zone)
  if type(meta) ~= "string" or meta == "" then
    return meta
  end
  if type(title) ~= "string" or title == "" then
    return meta
  end
  local rest = nil
  if meta == title then
    rest = ""
  elseif meta:sub(1, #title + 2) == title .. ", " then
    rest = meta:sub(#title + 3)
  end
  if rest == nil then
    return meta
  end
  if rest ~= "" then
    return rest
  end
  if type(zone) == "string" and zone ~= "" and zone ~= title then
    return zone
  end
  return nil
end

--------------------------------------------------------------------------------
-- Same titled quests (brief QN1)
--
-- The owner, 2026-10-03: six Classic "Taming the Beast" quests and three Forever ones from one
-- giver all read the same in search and on NPC pages. A quest in a chain of same titled quests
-- reads with its number ("Taming the Beast (II)", "I want numerals on classic quests too"), and
-- where two quests of one list still read the same, each says its zone ("Yes zone suffix").
--------------------------------------------------------------------------------

-- The numbers I to X; a chain longer than that reads its place as a plain number, "(11)".
ViewModel.QUEST_NUMERALS = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

--- A quest's place in its chain as the title says it: "I" to "X", then "11" and on, or nil for
--- anything that is not a whole number from 1. Pure.
function ViewModel.QuestNumeral(c)
  c = tonumber(c)
  if not c or c < 1 or c ~= math.floor(c) then
    return nil
  end
  return ViewModel.QUEST_NUMERALS[c] or tostring(c)
end

--- The title a quest is drawn by: "Taming the Beast (II)" where facts carries c (its place in a
--- chain of same titled quests: EraSources qc or the player module's q), else the title itself.
--- facts is any table with c ({ c, cl }, a quest's facts) or nil. zone (optional, brief S7) is
--- the zone it is told apart by, and comes BEFORE the number, "Taming the Beast (Mulgore) (I)",
--- so a sorted list keeps a zone's chain together. Pure.
function ViewModel.QuestDisplayTitle(title, facts, zone)
  if type(title) ~= "string" or title == "" then
    return title
  end
  local shown = title
  if type(zone) == "string" and zone ~= "" then
    shown = string.format(L["%s (%s)"], shown, zone)
  end
  local numeral = type(facts) == "table" and ViewModel.QuestNumeral(facts.c) or nil
  if not numeral then
    return shown
  end
  return string.format(L["%s (%s)"], shown, numeral)
end

--- One quest's place in a chain of same titled quests, { c, cl }, or nil: the Classic Era table's
--- qc (Core/EraSources.lua E:QuestChain, a swapped quest reading its pair's, brief QF2b) where it
--- holds the quest, else the shipped player module's (Core/PlayerSources.lua QuestChain). Reads
--- modules already built only.
--- Brief CN1 (the owner's ruling of 2026-10-24, "Classic ordering"): the Classic chain decides the
--- number wherever one links the quest, and our records' order (a giver's same titled quests by
--- quest id) numbers only a quest no Classic chain holds, Forever's own Taming the Beast three among
--- them. The records had won since QN1, so once the DR1 compile's records listed one giver's
--- Arugal's Folly quests (99, 422 and 424, by id), 99 read (I) where its chain makes it (IV).
function ViewModel.QuestChain(questId)
  if type(questId) ~= "number" then
    return nil
  end
  local era = eraCall("QuestChain", questId)
  if type(era) == "table" and era.c then
    return era
  end
  local players = ItemTree.PlayerSources
  if type(players) == "table" and type(players.QuestChain) == "function" and type(players.Loaded) == "function" then
    local okSource, source = pcall(players.Loaded)
    if okSource and type(source) == "table" then
      local ok, chain = pcall(players.QuestChain, source, questId)
      if ok and type(chain) == "table" and chain.c then
        return chain
      end
    end
  end
  return nil
end

--- A quest's title with its number where it is in a chain (ViewModel.QuestDisplayTitle over
--- ViewModel.QuestChain). title nil answers nil.
function ViewModel.QuestDisplayName(questId, title)
  if type(title) ~= "string" or title == "" then
    return title
  end
  return ViewModel.QuestDisplayTitle(title, ViewModel.QuestChain(questId))
end

--- A text that holds a quest node's plain name ("Quest: Taming the Beast (6062)", the title bar
--- and the breadcrumb) with the numbered title in its place, or the text as it was where the
--- quest is in no chain or the text does not hold its name. Any other key is left alone.
function ViewModel.QuestTitleText(key, text)
  if type(text) ~= "string" or text == "" then
    return text
  end
  local kind, id = Graph.Parse(key)
  if kind ~= "quest" or type(id) ~= "number" then
    return text
  end
  local name = Graph.Name(key)
  if type(name) ~= "string" or name == "" then
    return text
  end
  local shown = ViewModel.QuestDisplayName(id, name)
  if shown == name then
    return text
  end
  local at = text:find(name, 1, true)
  if not at then
    return text
  end
  return text:sub(1, at - 1) .. shown .. text:sub(at + #name)
end

--- The zone a quest is told apart by, or nil: where the player's own give record was written,
--- else the map the player module met its giver on, else the zone its Classic Era giver stands
--- in, else the curated table's zone, else (brief QV1) the map the predicted quest facts state.
--- Reads what is held; the one client read is a map's name through the collector's guarded
--- Collector.MapName.
function ViewModel.QuestZone(questId)
  if type(questId) ~= "number" then
    return nil
  end
  local Collector = ItemTree.Collector
  local function mapWords(mapId)
    if type(mapId) ~= "number" or type(Collector) ~= "table" or type(Collector.MapName) ~= "function" then
      return nil
    end
    local ok, name = pcall(Collector.MapName, mapId)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
    return nil
  end
  local records = ViewModel.QuestRecords(questId)
  local give = type(records) == "table" and type(records.give) == "table" and records.give or nil
  local zone = give and mapWords(tonumber(give.mapId)) or nil
  if zone then
    return zone
  end
  local players = ItemTree.PlayerSources
  if type(players) == "table" and type(players.Quest) == "function" and type(players.Loaded) == "function" then
    local okSource, source = pcall(players.Loaded)
    local ok, quest = false, nil
    if okSource and type(source) == "table" then
      ok, quest = pcall(players.Quest, source, questId)
    end
    for _, giver in ipairs(ok and type(quest) == "table" and quest.givers or EMPTY) do
      zone = mapWords(giver.uiMap)
      if zone then
        return zone
      end
    end
  end
  local ok, era = pcall(ViewModel.EraQuestNpcs, questId)
  for _, giver in ipairs(ok and type(era) == "table" and type(era.give) == "table" and era.give or EMPTY) do
    if type(giver.zone) == "string" and giver.zone ~= "" then
      return giver.zone
    end
  end
  local curated = type(ItemTree.CuratedQuests) == "table" and ItemTree.CuratedQuests[questId] or nil
  if type(curated) == "table" and type(curated.zone) == "string" and curated.zone ~= "" then
    return curated.zone
  end
  -- Brief QV1 (the owner's ruling "2.a", 2026-10-18): a quest nothing above places (A Donation of
  -- Wool 99191 and its Horde twin 99196, Forever quests whose only giver is the predicted quest
  -- facts' own) reads the map those facts state, named as the collector names any map. Read only
  -- once the module is registered (QuestsPredicted.Facts without load).
  local predicted = ItemTree.QuestsPredicted
  if type(predicted) == "table" and type(predicted.Facts) == "function" then
    local okFacts, facts = pcall(predicted.Facts, questId)
    zone = okFacts and type(facts) == "table" and mapWords(facts.uiMap) or nil
    if zone then
      return zone
    end
  end
  return nil
end

--- Brief QV1 (the owner's ruling "2.a", 2026-10-18): the place a quest row's own location column
--- names, or nil, out of the meta the edge carries, the quest's title and the zone the edge states.
--- The collector words a quest record "<title>, <zone>" (Core/Collector.lua metaFor), so the place
--- is what follows the title, else the edge's zone; a side word in the zone slot (a Classic Era
--- quest row's "Alliance", Core/Sources.lua questSideZone) is no place. Pure.
function ViewModel.QuestRowPlace(meta, title, zone)
  if type(meta) == "string" and type(title) == "string" and title ~= "" then
    if meta:sub(1, #title + 2) == title .. ", " and #meta > #title + 2 then
      return meta:sub(#title + 3)
    end
  end
  if type(zone) == "string" and zone ~= "" and zone ~= title and zone ~= L["Alliance"] and zone ~= L["Horde"] then
    return zone
  end
  return nil
end

--- Brief QV1: the name of the reputation a quest gives, or nil where none is known: the Classic Era
--- table's own (Core/EraSources.lua E:QuestReputation, ours, shipped only for the quests that share
--- a title and give different reputations). Reads what is built.
function ViewModel.QuestReputation(questId)
  local name = eraCall("QuestReputation", questId)
  if type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

--- Brief QV1: the name of whoever gives a quest, or nil: the player's own give record, else the
--- player module's first named giver, else the Classic Era giver, else the predicted quest facts'
--- giver, each creature named as the graph names it. Reads what is held.
function ViewModel.QuestGiverName(questId)
  if type(questId) ~= "number" then
    return nil
  end
  local function named(npcId)
    local id = tonumber(npcId)
    if not id or id <= 0 or id ~= math.floor(id) then
      return nil
    end
    local name = Graph.Name(Graph.Key("npc", id))
    if type(name) == "string" and name ~= "" then
      return name
    end
    return nil
  end
  local records = ViewModel.QuestRecords(questId)
  local give = type(records) == "table" and type(records.give) == "table" and records.give or nil
  if give then
    local name = type(give.name) == "string" and give.name ~= "" and give.name or named(give.npcId)
    if name then
      return name
    end
  end
  local players = ItemTree.PlayerSources
  if type(players) == "table" and type(players.Quest) == "function" and type(players.Loaded) == "function" then
    local okSource, source = pcall(players.Loaded)
    local ok, quest = false, nil
    if okSource and type(source) == "table" then
      ok, quest = pcall(players.Quest, source, questId)
    end
    for _, giver in ipairs(ok and type(quest) == "table" and quest.givers or EMPTY) do
      local name = named(giver.npcId)
      if name then
        return name
      end
    end
  end
  local ok, era = pcall(ViewModel.EraQuestNpcs, questId)
  for _, giver in ipairs(ok and type(era) == "table" and type(era.give) == "table" and era.give or EMPTY) do
    if type(giver.name) == "string" and giver.name ~= "" then
      return giver.name
    end
  end
  local predicted = ItemTree.QuestsPredicted
  if type(predicted) == "table" and type(predicted.Givers) == "function" then
    local okGivers, givers = pcall(predicted.Givers, questId)
    for _, id in ipairs(okGivers and type(givers) == "table" and givers or EMPTY) do
      local name = named(id)
      if name then
        return name
      end
    end
  end
  return nil
end

--- Brief QV1: whether a reputation's name says no more than the place a row already shows: the
--- same name ("Ironforge" in Ironforge) or the place's first words ("Stormwind" in Stormwind City),
--- any case. Pure.
function ViewModel.ReputationIsPlace(reputation, place)
  if type(reputation) ~= "string" or type(place) ~= "string" or reputation == "" or place == "" then
    return false
  end
  local name, where = reputation:lower(), place:lower()
  return name == where or where:sub(1, #name + 1) == name .. " "
end

--- Brief QV1 (the owner's ruling "2.a", 2026-10-18): the second part of the brackets for the rows
--- of one list that still read the same once their places are in (A Donation of Wool 7802 and 7807,
--- both "(Ironforge)"). group is those rows ({ questId, zoneShown }); the answer is a list as long,
--- each entry the words that follow the place, or false for none. A row's words are the reputation
--- its quest gives (reputationOf), none where that is its place's own (7802's Ironforge), and the
--- name of whoever gives it (giverOf) where no reputation is known or where two rows would still
--- read alike. Words that two rows would still share tell nothing apart and are left off (two quests
--- of one giver). Pure over the two functions it is handed, each asked under pcall.
function ViewModel.QuestSecondParts(group, reputationOf, giverOf)
  local function ask(fn, questId)
    if type(fn) ~= "function" or questId == nil then
      return nil
    end
    local ok, answer = pcall(fn, questId)
    if ok and type(answer) == "string" and answer ~= "" then
      return answer
    end
    return nil
  end
  local parts = {}
  for index, row in ipairs(type(group) == "table" and group or EMPTY) do
    local reputation = ask(reputationOf, row.questId)
    if reputation and ViewModel.ReputationIsPlace(reputation, row.zoneShown) then
      parts[index] = false
    elseif reputation then
      parts[index] = reputation
    else
      parts[index] = ask(giverOf, row.questId) or false
    end
  end
  local counts = {}
  for index = 1, #parts do
    local key = parts[index] or ""
    counts[key] = (counts[key] or 0) + 1
  end
  for index = 1, #parts do
    if counts[parts[index] or ""] > 1 then
      parts[index] = ask(giverOf, group[index].questId) or parts[index]
    end
  end
  counts = {}
  for index = 1, #parts do
    if parts[index] then
      counts[parts[index]] = (counts[parts[index]] or 0) + 1
    end
  end
  for index = 1, #parts do
    if parts[index] and counts[parts[index]] > 1 then
      parts[index] = false
    end
  end
  return parts
end

--- Brief QV1 (c): whether a quest row's location column holds nothing of its own: no meta, or only
--- the side words _DecorateNode put there ("Horde only"). Pure.
function ViewModel.QuestColumnEmpty(node)
  if type(node) ~= "table" then
    return false
  end
  local meta = node.meta
  return meta == nil or meta == "" or (node.sideWords ~= nil and meta == node.sideWords)
end

--- Tells apart the quests of ONE list that read the same (brief QN1, "Yes zone suffix"). rows is
--- { { title, zone, questId, base, chain }, ... }: title the quest's display title (numbers
--- already in), zone its zone or nil. Each row gains displayTitle: its title, and where another
--- row of the list has the same title, its title with its zone in brackets ("Taming the Beast
--- (Mulgore)"), or its title alone where no zone is known. A title unique in the list is never
--- touched. zoneOf (optional) is asked for a row's zone by its questId, only for a row that shares
--- its title and states none. Brief S7: a row that also carries base (its plain title) and chain
--- (its { c, cl }) puts the zone before the number, "Taming the Beast (Mulgore) (I)"
--- (ViewModel.QuestDisplayTitle), and where any two rows of one base read the same, every row of
--- that base is told apart, so a chain's unique numbers wear their zone too. A row told apart
--- also gains zoneShown, the zone it was given. Answers rows. Pure over what it is handed.
---
--- Brief QV1 (the owner's ruling "2.a", 2026-10-18): reputationOf and giverOf (optional, each asked
--- by questId) then tell apart the rows that still read the same once their zones are in: each
--- gains a second part in the same brackets (ViewModel.QuestSecondParts), "A Donation of Wool
--- (Ironforge, Gnomeregan Exiles)" beside "A Donation of Wool (Ironforge)", and secondShown, those
--- words. qualifierShown is everything the brackets hold (the zone, then the second part).
function ViewModel.DisambiguateQuestTitles(rows, zoneOf, reputationOf, giverOf)
  if type(rows) ~= "table" then
    return rows
  end
  local counts = {}
  for _, row in ipairs(rows) do
    if type(row) == "table" and type(row.title) == "string" and row.title ~= "" then
      counts[row.title] = (counts[row.title] or 0) + 1
    end
  end
  -- Brief S7: a chain where any two read the same is told apart whole, so a zone's V and IX read
  -- with the zone as its I and II do and sort beside them.
  local clashes = {}
  for _, row in ipairs(rows) do
    if type(row) == "table" and type(row.base) == "string" and (counts[row.title] or 0) > 1 then
      clashes[row.base] = true
    end
  end
  for _, row in ipairs(rows) do
    if type(row) == "table" then
      row.displayTitle = row.title
      row.zoneShown = nil
      row.secondShown = nil
      row.qualifierShown = nil
      local clash = (counts[row.title] or 0) > 1 or (type(row.base) == "string" and clashes[row.base])
      if type(row.title) == "string" and clash then
        local zone = row.zone
        if (type(zone) ~= "string" or zone == "") and type(zoneOf) == "function" and row.questId ~= nil then
          local ok, answer = pcall(zoneOf, row.questId)
          zone = ok and answer or nil
        end
        if type(zone) == "string" and zone ~= "" then
          row.zoneShown = zone
          row.qualifierShown = zone
          if type(row.base) == "string" and row.base ~= "" then
            row.displayTitle = ViewModel.QuestDisplayTitle(row.base, row.chain, zone)
          else
            row.displayTitle = string.format(L["%s (%s)"], row.title, zone)
          end
        end
      end
    end
  end
  if reputationOf ~= nil or giverOf ~= nil then
    ViewModel.TellApartAgain(rows, reputationOf, giverOf)
  end
  return rows
end

--- Brief QV1: the second pass of ViewModel.DisambiguateQuestTitles. The rows of the list that read
--- the same once their zones are in, and stand for two quests or more, gain the second part of their
--- brackets (ViewModel.QuestSecondParts): "(Ironforge, Gnomeregan Exiles)", or "(Gnomeregan Exiles)"
--- for a row no zone was found for. A row the second part leaves as it was keeps its title. Answers
--- rows.
function ViewModel.TellApartAgain(rows, reputationOf, giverOf)
  local groups, order = {}, {}
  for _, row in ipairs(type(rows) == "table" and rows or EMPTY) do
    if type(row) == "table" and type(row.displayTitle) == "string" and row.questId ~= nil then
      local group = groups[row.displayTitle]
      if not group then
        group = { quests = {}, count = 0 }
        groups[row.displayTitle] = group
        order[#order + 1] = row.displayTitle
      end
      group[#group + 1] = row
      if not group.quests[row.questId] then
        group.quests[row.questId] = true
        group.count = group.count + 1
      end
    end
  end
  for _, shown in ipairs(order) do
    local group = groups[shown]
    if group.count > 1 then
      local parts = ViewModel.QuestSecondParts(group, reputationOf, giverOf)
      for index, row in ipairs(group) do
        local part = parts[index]
        if part then
          local words = row.zoneShown and string.format(L["%s, %s"], row.zoneShown, part) or part
          row.secondShown = part
          row.qualifierShown = words
          if type(row.base) == "string" and row.base ~= "" then
            row.displayTitle = ViewModel.QuestDisplayTitle(row.base, row.chain, words)
          else
            row.displayTitle = string.format(L["%s (%s)"], row.title, words)
          end
        end
      end
    end
  end
  return rows
end

--- The search dropdown's quest rows (UI/Frame.lua Frame.SearchModel: { key = "quest:<id>", kind =
--- "quest", name }) titled as every other list titles them: numbered where in a chain, then told
--- apart by zone where two still read the same, the zone before the number. Changes the rows'
--- name in place; answers rows.
---
--- Brief S7: the quests that share a plain title are then put in order of what they read, in the
--- places they already held (the search answers them side by side, in one tier), so a zone's I,
--- II and III sit together: by the title with its zone, then by number (so IX follows VIII, not
--- I), then as they came. Nothing else in the list moves.
function ViewModel.TitleQuestRows(rows)
  local quests = {}
  local slots = {}
  for index, row in ipairs(type(rows) == "table" and rows or EMPTY) do
    if type(row) == "table" and row.kind == "quest" and type(row.name) == "string" then
      local kind, id = Graph.Parse(row.key)
      if kind == "quest" and type(id) == "number" then
        local chain = ViewModel.QuestChain(id)
        local entry = {
          row = row,
          index = index,
          questId = id,
          base = row.name,
          chain = chain,
          title = ViewModel.QuestDisplayTitle(row.name, chain),
        }
        quests[#quests + 1] = entry
        slots[row.name] = slots[row.name] or {}
        table.insert(slots[row.name], entry)
      end
    end
  end
  ViewModel.DisambiguateQuestTitles(quests, ViewModel.QuestZone, ViewModel.QuestReputation, ViewModel.QuestGiverName)
  for _, entry in ipairs(quests) do
    entry.row.name = entry.displayTitle
    -- What the entry sorts by: its title with the zone but without the number, then the number.
    -- Brief QV1: the zone with its second part, where it has one.
    entry.sortTitle = ViewModel.QuestDisplayTitle(entry.base, nil, entry.qualifierShown or entry.zoneShown)
    local c = type(entry.chain) == "table" and tonumber(entry.chain.c) or nil
    entry.sortNumber = ViewModel.QuestNumeral(c) and c or 0
  end
  for _, group in pairs(slots) do
    if #group > 1 then
      local places = {}
      for _, entry in ipairs(group) do
        places[#places + 1] = entry.index
      end
      table.sort(group, ViewModel.QuestSearchLess)
      for at, entry in ipairs(group) do
        rows[places[at]] = entry.row
      end
    end
  end
  return rows
end

--- The order TitleQuestRows puts same titled quests in (entries carrying sortTitle, sortNumber
--- and index): by the title with its zone, then by number, then as they came. Pure.
function ViewModel.QuestSearchLess(a, b)
  if a.sortTitle ~= b.sortTitle then
    return a.sortTitle < b.sortTitle
  end
  if a.sortNumber ~= b.sortNumber then
    return a.sortNumber < b.sortNumber
  end
  return a.index < b.index
end

function VM:_DecorateNode(node, edge, ownerKey)
  local out = {}
  for key, value in pairs(node) do
    out[key] = value
  end
  -- Brief Q9b: a herb, a vein, a fishing pool or a chest wears what it yields (ViewModel.NodeIcon):
  -- the file in icon and the kind's glyph in iconAsset, which UI/Tree.lua draws where no file is.
  if node.kind == "object" then
    local file, asset = ViewModel.NodeIcon(node.key, ownerKey, edge)
    out.icon = file
    out.iconAsset = asset
  elseif node.kind == "set" then
    local file, asset = ViewModel.SetIcon(node.key)
    out.icon = file
    out.iconAsset = asset
  elseif node.kind == "spell" then
    -- Brief TR2: a rank spell a trainer teaches ("Mining" four times over, with the spell's own
    -- missing icon) reads as its rank ("Apprentice Mining") and wears its profession's glyph.
    local line = ViewModel.RankSpell(node.id)
    if line then
      out.name = ViewModel.RankSpellLabel(node.id) or out.name
      out.icon = ViewModel.SKILL_ICONS[line] or out.icon
    end
  end
  out.quantity = edge.quantity
  out.quantityMax = edge.quantityMax
  local def = edge.type
  local stated = type(def) == "table" and STATED_TYPES[def.name] == true
  if edge.seen then
    out.seen = edge.seen
  elseif edge.confidence == Confidence.VERIFIED and edge.quantity and not stated then
    out.seen = edge.quantity
  end
  if out.seen then
    out.quantity = nil
    out.quantityMax = nil
  end
  out.percent = edge.percent
  -- What a predicted edge is predicted from (Core/Confidence.lua BASIS_*). It travels on the
  -- row's node rather than only on its source facts, because a disenchant row is not a source
  -- row at all and its Predicted mark has to explain itself too.
  out.basis = edge.basis
  -- Brief QB2: a Classic Era reward the quest no longer hands over in Forever, which the Changed
  -- mark's hover words as such (UI/Tree.lua BadgeBasis).
  out.rewardChanged = edge.rewardChanged == true or nil
  out.meta = edge.meta or node.meta
  -- Brief S6: a quest row's second column never repeats the quest's own title. The collector's
  -- quest records word their meta as "<title>, <zone>" (Core/Collector.lua metaFor), which put the
  -- title on both sides of Prideclaw Pelt's row; the column keeps what follows it (the zone), or
  -- nothing.
  if node.kind == "quest" then
    local questTitle = Graph.Name(node.key) or node.name
    -- Brief QV1: the place the row's own column names, which VM:_TellQuestsApart tells the row
    -- apart by before any other.
    out.questPlace = ViewModel.QuestRowPlace(out.meta, questTitle, edge.zone)
    out.meta = ViewModel.QuestRowMeta(out.meta, questTitle, edge.zone)
    -- Brief F155: with "Hide other faction data" off, the other side's quests are back in Used by,
    -- and each says whose it is in its second column ("Horde only"), the words UI/Tree.lua
    -- Tree.FactionOnlyText gives a source the player's side cannot use.
    if self.view == Edges.USES then
      -- Brief RB2 (owner QA 2026-10-17 item 194): a quest open to both that our data leans to the
      -- other side says "Possibly Horde only" there instead, whatever the setting says.
      local words = ViewModel.OtherSideWords(edge, node.key) or ViewModel.LeanWords(edge, node.key)
      out.meta = ViewModel.WithSideWords(out.meta, words)
      -- Brief QV1: kept, so a place put in the column later goes before them ("Orgrimmar, Horde only").
      out.sideWords = words
    end
    -- Brief QN1: a quest in a chain of same titled quests reads with its number. Brief S7: the
    -- plain title is kept beside it, so a zone told apart goes before the number.
    out.plainTitle = out.name
    out.name = ViewModel.QuestDisplayName(node.id, out.name)
  end
  -- Brief V1: a vendor the client's own tables list and nothing has named yet reads "Vendor (npc
  -- 252000)" rather than the graph's "Creature 252000". Its name comes from the player's visit
  -- (the collector puts it on the graph), never from a guess.
  if edge.provenance == CLIENT_PROVENANCE and node.kind == "npc" and Graph.Name(node.key) == nil then
    local module = ItemTree.ForeverVendors
    if type(module) == "table" and type(module.Label) == "function" then
      out.name = module.Label(node.id)
    end
  end
  -- Brief TW1 (the owner's ruling "2.A", 2026-10-18): a class trainer's spell only some races learn
  -- reads with its races in brackets, "Starshards (Night Elf)", on a recorded row and a Classic Era
  -- row alike (Core/EraSources.lua E:ClassSpellRaceWords, this build's own race masks).
  if type(edge) == "table" and type(edge.classSpell) == "table" and type(out.name) == "string" and out.name ~= "" then
    local races = eraCall("ClassSpellRaceWords", node.id)
    if type(races) == "string" and races ~= "" then
      out.name = string.format(L["%s (%s)"], out.name, races)
    end
  end
  out.badges = self:_Badges(node, edge)
  -- A skill row wears the profession's own glyph rather than the plain stand in. The one a
  -- player meets is the trainer row under Sources, where "Blacksmithing" with the blacksmithing
  -- glyph is exactly what they are looking for. Core names the key, the UI resolves it.
  if node.kind == "skill" and ViewModel.SKILL_ICONS[node.id] then
    out.icon = ViewModel.SKILL_ICONS[node.id]
  end
  -- A row that names a creature wears the kind of creature it is rather than the one generic
  -- glyph every creature node shares. Only where the edge states a kind, and only over a node
  -- with no art of its own: an item, a recipe and a container keep theirs.
  if out.icon == nil then
    out.icon = ViewModel.CreatureIcon(edge and edge.creature or nil)
    -- The creature's own portrait, where the table states one. The kind icon above is what the
    -- row draws at once; this is the offer the window may take up once the row has settled, so
    -- the number travels on the row and nothing here asks the client for anything.
    out.portrait = ViewModel.CreaturePortrait(edge and edge.creature or nil)
    -- Brief BQ25b (owner QA 2026-10-10 item 54): a recorded row states no display id (a recorder
    -- cannot read one), so a creature the Classic Era table knows, by the same creature id or by
    -- the merged twin's name, borrows the table's. The window's portrait queue, dwell and per
    -- frame cap take it from here as they take any other. A Classic Era row (dedupeName) was left
    -- with its own or none (until PT2b, below).
    -- Brief NP2b (owner QA item 81): a Forever creature the Classic Era table does not know takes
    -- the Creatures data's display id (the client creature cache's), else keeps the kind icon.
    -- Brief PT2 (owner QA item 287): a guess's row and a merged Classic Era row look it up too, and
    -- since PT2b every row that names a creature (ViewModel.BorrowsPortrait).
    if out.portrait == nil and node.kind == "npc" and ViewModel.BorrowsPortrait(edge, node.key) then
      out.portrait = ViewModel.EraPortrait(node.key) or ViewModel.ForeverPortrait(node.key)
    end
  end
  return out
end

-- Children of a row, computed on first expand and cached per row key. Brief F155: walked with the
-- side "Hide other faction data" hides from, and walked again once that side moves (the setting or
-- the pretend side changed under an open view).
function VM:_ChildEntries(rowKey, nodeKey)
  local side = self:_SideCaches()
  local cached = self.children[rowKey]
  if not cached then
    cached = Graph.Children(nodeKey, self.direction, sided(WALK_OPTS, side))
    self.children[rowKey] = cached
  end
  return self:_VisibleEntries(cached)
end

--------------------------------------------------------------------------------
-- A summary row, and the list behind it.
--
-- The shipped Classic Era table caps a category at three named rows and writes one row saying
-- how many more there are (Core/EraSources.lua). That row names nothing, points at a node of the
-- table's own making, and used to re-root the window onto it: the title read "Object: and 1 more
-- (-1000215496)" and the pane drew the find sources empty state. It is not a thing at all, so it
-- is never a thing the window opens.
--
-- What it is instead is an OFFER. The table ships the rest of every list it summarises, so the
-- row is the tree's one "Show N more" row (E75), and pressing it draws the sources the cap did
-- not name in place, in the contract's own order, by the very code that drew the three rows
-- above. A row the table ships no list for (a world drop, which stands for hundreds of creatures
-- the pipeline measured and refused) keeps its plain wording and does nothing at all.
--------------------------------------------------------------------------------

-- What a summary edge stands for ({ item, category, listed }), or nil for an ordinary edge. Only
-- Core/EraSources.lua ever sets it, and only walking up, so no other view can see one.
local function summaryOf(edge)
  local summary = type(edge) == "table" and edge.summary or nil
  if type(summary) ~= "table" then
    return nil
  end
  return summary
end

-- Brief D6: whether a row's node is a Classic Era gathering NODE row (Core/EraSources.lua), the
-- vein or the herb that opens onto the zones it stands in. Such a node has no page of its own, so
-- the pane answers a click on its row by opening and closing it rather than by re-rooting onto
-- it. Pure arithmetic over the key, and false with Core/EraSources.lua absent.
local function isGatherNode(nodeKey)
  local EraSources = ItemTree.EraSources
  local fn = type(EraSources) == "table" and EraSources.IsNodeKey or nil
  if type(fn) ~= "function" then
    return false
  end
  local ok, answer = pcall(fn, nodeKey)
  return ok and answer == true
end

-- Brief D7: whether a gathering node row's node has a page to open, which is when ViewsFor answers
-- Edges.NODE_VIEWS for it. Such a row re-roots from its name and toggles its zones from the chevron
-- (UI/Tree.lua Interpret). Since the P6b addendum that is every node row the shipped table names,
-- pins or none (E:ObjectPage); a node key nothing names keeps D6's toggle on any click. A key's
-- arithmetic and a string lookup, no pin decoded.
local function hasNodePage(nodeKey)
  local ok, views = pcall(ViewModel.ViewsFor, nodeKey)
  if not ok or type(views) ~= "table" then
    return false
  end
  for _, view in ipairs(views) do
    if view == Edges.MAP then
      return true
    end
  end
  return false
end

-- Brief N1: on a zone's own Here tab, the page the source a row names opens on, as { key, name },
-- or nil where the row names no source with a page of its own. The owner (2026-10-02): "when on
-- this page i should be able to click on the vendor to go to the vendors NPC page directly".
--
--   a record that names its npc by id (a vendor the player visited, a creature that dropped the
--     item) opens npc:<id>, which its records always give a page (its Sells or Loot tab);
--   a row whose pick names a Classic Era creature or vendor opens its page (brief EK1, keyed by its
--     creature id, E:PageKey), the node the creature search opens, where the table states a kind
--     for the name (E:CreatureKind);
--   a row whose pick names a herb, vein, fishing pool or chest opens its page (brief EK1 2c, keyed
--     by its gameobject id, E:ObjectKey), where that node has a page (hasNodePage);
--   anything else (a boss of a Forever instance, a name the table does not know) opens nothing.
--
-- Key arithmetic and a table lookup per distinct source, kept for the view model's life.
function VM:_SourceLink(edge)
  if self.view ~= Edges.HERE or type(edge) ~= "table" then
    return nil
  end
  local pick = type(edge.pick) == "table" and edge.pick or nil
  local name = edge.zone
  if type(name) ~= "string" or name == "" then
    name = pick and pick.name or nil
  end
  if type(name) ~= "string" or name == "" then
    return nil
  end
  local key = nil
  local npcId = tonumber(edge.npc)
  if npcId and npcId > 0 and npcId == math.floor(npcId) then
    key = Graph.Key("npc", npcId)
  elseif pick and type(pick.nameIndex) == "number" then
    if pick.kind == "npc" then
      key = eraCall("PageKey", pick.nameIndex)
    elseif pick.kind == "object" then
      -- Brief EK1 2c: the object's page, keyed by its gameobject id.
      key = eraCall("ObjectKey", pick.nameIndex)
    end
  end
  if not key then
    return nil
  end
  self.sourcePages = self.sourcePages or {}
  local paged = self.sourcePages[key]
  if paged == nil then
    if npcId then
      paged = true
    elseif Graph.Kind(key) == "npc" then
      paged = type(eraCall("CreatureKind", key)) == "number"
    else
      paged = hasNodePage(key)
    end
    self.sourcePages[key] = paged
  end
  if not paged then
    return nil
  end
  return { key = key, name = name }
end

-- The rest of one summary's list, as edges, worked out once per LIST and kept.
--
-- Nothing is decoded until this is called, and it is called only for a list the player pressed or
-- the search box reached into. Until brief E87 only the ROOT item's own summaries opened, which
-- kept a container opened three levels down from decoding anything; it also left "Show 2 more"
-- under a nested row (Smelt Thorium > Thorium Ore > its veins) drawn and dead. A nested summary
-- now opens like any other, and the cost stays where that rule put it: a list is still decoded
-- only on a press or a search, the search only reaches rows the player has already opened, and
-- the cache is keyed by the list ({ item, category }) rather than by the row, so the same list
-- met under two rows is decoded once.
--
-- siblings are the edges drawn beside the summary row (VM:_AppendGroup keeps them by the group's
-- key). A list row a live sibling of the same type already names is dropped and its source facts
-- go to that sibling (Graph.DropShadowedList), so a vendor the player recorded is one row, the
-- recorded one with the Classic Era title and place, however far down the list its Classic Era row
-- sat (QA 2026-10-10 item 26).
-- Brief F155: and less what "Hide other faction data" hides (a vendor of the other side in a
-- shipped "Show 101 vendors" list, Graph.WithoutOtherSide), so the summary's count (VM:_ListRows),
-- its group's header and the tab count are the rows the player can use.
function VM:_MoreEntries(summary, siblings)
  local side = self:_SideCaches()
  local listKey = tostring(summary.item) .. ":" .. tostring(summary.category)
  local cached = self.more[listKey]
  if not cached then
    cached = EMPTY
    local era = ItemTree.eraSources
    if type(era) == "table" and type(era.MoreEdges) == "function" then
      local ok, edges = pcall(era.MoreEdges, era, summary.item, summary.category)
      if ok and type(edges) == "table" then
        cached = Graph.WithoutOtherSide(Graph.DropShadowedList(edges, siblings), side)
      end
    end
    self.more[listKey] = cached
  end
  return self:_VisibleEntries(cached)
end

-- Brief FIX159 (owner QA 2026-10-14 item 159, Stringy Wolf Meat: "Show 16 more" added 8 rows and
-- "Show 6 more", 14 in all): how many rows pressing one shipped summary really adds. Its own words
-- state the table's count, but the list as drawn (VM:_MoreEntries) leaves out a row a live sibling
-- already names (Bloodsnout Worg and Mangy Wolf there, QA 2026-10-10 item 26) and a placeless row
-- whose placed twin stands in the list (787 Found in lists over the shipped data). So the list is
-- read here, the same one decode a press costs and kept the same way, and its rows are the count.
-- 0 where every row folds into a sibling (Wrathtail Sea Witch's three under item 5490): that
-- summary has nothing to add and draws no row. siblings are the edges drawn beside it. With no
-- reader to ask, the table's own count stands. Kept per list for as long as the view model, like
-- vm.more.
function VM:_ListRows(entry, siblings)
  local summary = listedSummary(entry)
  if not summary then
    return 1
  end
  local listKey = tostring(summary.item) .. ":" .. tostring(summary.category)
  -- Brief F155: counted again once the hidden side moves.
  self:_SideCaches()
  self.listRows = self.listRows or {}
  local held = self.listRows[listKey]
  if held == nil then
    local list = self:_MoreEntries(summary, siblings)
    if self.more[listKey] == EMPTY then
      held = math.max(1, summaryRows(entry, summary))
    else
      held = #list
    end
    self.listRows[listKey] = held
  end
  return held
end

-- Whether a summary drawn at depth opens onto its list: past the depth cap it is a plain row that
-- opens nothing (VM:_AppendEntry), so its list is neither counted nor read.
function VM:_ListsOpen(depth)
  return (tonumber(depth) or 1) < (tonumber(self.opts.maxDepth) or math.huge)
end

-- The listRows a count over siblings drawn at depth passes (ViewModel.EntryRows, GroupCap): the
-- rows a summary's list adds, or 1 for a summary the depth cap leaves a plain row.
function VM:_ListRowsOf(siblings, depth)
  if not self:_ListsOpen(depth) then
    return function()
      return 1
    end
  end
  return function(entry)
    return self:_ListRows(entry, siblings)
  end
end

-- ownerKey is the node the entries hang off, which is the root for a category's own rows. A
-- group over the limit draws its first rows and a more row, and nothing below the limit is
-- touched at all: a category of 1,502 disenchant sources costs the same as one of eight.
--
-- open is true where the whole group is drawn with no cap: a shipped summary's list once its
-- "Show N more" was pressed (VM:_AppendListed, brief FIX176).
function VM:_AppendGroup(rows, parentKey, entries, depth, path, ownerKey, open)
  -- The edges of this group, for a summary row among them to drop what they already name.
  self.groupEntries = self.groupEntries or {}
  self.groupEntries[parentKey] = entries
  self:_CarryListRates(entries, ownerKey)
  entries = self:_DropListTwins(entries, depth)
  local first = #rows + 1
  local total = #entries
  local limit = self.opts.groupLimit
  -- Brief BQ24 (owner QA 2026-10-10 item 29, "def" on Linen Cloth's Sources found no Drops from row
  -- past the first 8): while the search box holds anything the group's whole list is drawn, as a
  -- summary's list is (VM:_AppendListed), so the search filters every row the view has rather than
  -- the ones the cap let through. The rows a search does not match are filtered out by the pane.
  -- Brief FIX149: a shipped summary past the limit is drawn rather than capped, and the cap's
  -- number counts rows as the header does (ViewModel.GroupCap).
  -- Brief FIX159: a summary's list is counted as it draws beside these siblings (VM:_ListRows).
  local listRows = self:_ListRowsOf(self.groupEntries[parentKey], depth)
  local capPressed = self.shown[parentKey] == true and not self.searching
  local shown, moreCount = ViewModel.GroupCap(entries, limit, self.searching or open == true or capPressed, listRows)
  -- Brief FIX176 (owner QA 2026-10-14 item 176): the cap row's number counts a summary behind it
  -- as its whole list, so once the cap is pressed each entry it stood over (past capAt, where the
  -- first draw stopped) is drawn whole, a summary opened onto its list rather than left as a
  -- "Show N more" row of its own. A summary the first draw showed keeps its own row and number.
  local capAt = shown
  if capPressed then
    capAt = ViewModel.GroupCap(entries, limit, false, listRows)
  end
  for index = 1, shown do
    local entry = entries[index]
    -- Brief GS3: one notice directly above the first guessed row of the view. Guesses sort last
    -- in their category, so this is also below every real row of it.
    if entry.guess ~= nil and not entry.requirement and ownerKey == self.root and not self.guessNoticeDrawn then
      self.guessNoticeDrawn = true
      self:_Push(rows, {
        key = parentKey .. "/guessnotice",
        kind = "notice",
        depth = depth,
        text = ViewModel.GUESS_NOTICE,
        guess = true,
      })
    end
    self:_AppendEntry(rows, parentKey, entry, depth, path, ownerKey, index > capAt)
  end
  self:_GroupSameNamedObjects(rows, parentKey, first, depth)
  self:_TellQuestsApart(rows, first, depth)
  if shown < total then
    self:_Push(rows, {
      key = parentKey .. "/more",
      kind = "more",
      depth = depth,
      moreCount = moreCount,
    })
  end
end

-- Brief BQ25b (owner QA 2026-10-10 item 70, "duplicate Battered Chest entries"): the Classic Era
-- table ships one chest object per level band, each with its own place and rate, so Found in drew
-- Battered Chest three times (Durotar ~9%, Darkshore ~5.3%, Westfall ~3.7%). They are not merge
-- splits, but they read as duplicates. Under Found in the rows of one object name are drawn as ONE
-- row, the way Copper Vein is one row under Mined from: its zone column says how many zones ("3
-- zones"), its rate column the mean of the rates they state (the Classic Era "~" figure), and it
-- opens (a click anywhere, as a gathering node with no page does, UI/Tree.lua Interpret) onto the
-- per zone rows with their own rates. Closed by default; open while the search box holds anything,
-- so a search still reaches each zone's row.
ViewModel.OBJECT_GROUP_CATEGORY = "cat:" .. GROUP_IDS["Found in"]

-- Pure: the zone count words and the combined rate of the rows grouped under one name. units are
-- the rows' edges. Answers zoneText, rateText, rateLabel (each nil where nothing says it).
function ViewModel.ObjectGroupFacts(edges)
  local zones, zoneCount = {}, 0
  local total, rated = 0, 0
  for _, edge in ipairs(type(edges) == "table" and edges or EMPTY) do
    if type(edge) == "table" then
      local zone = edge.zone
      if type(zone) == "string" and zone ~= "" and not zones[zone] then
        zones[zone] = true
        zoneCount = zoneCount + 1
      end
      local percent = tonumber(edge.percent) or tonumber(edge.eraRate)
      if percent then
        total = total + percent
        rated = rated + 1
      end
    end
  end
  local Sources = ItemTree.Sources
  local zoneText = nil
  if zoneCount > 0 and type(Sources) == "table" and type(Sources.ZoneCount) == "function" then
    zoneText = Sources.ZoneCount(zoneCount)
  end
  local rateText, rateLabel = nil, nil
  if rated > 0 and type(Sources) == "table" and type(Sources.HistoricalRate) == "function" then
    local mean = math.floor(total / rated * 10 + 0.5) / 10
    rateText, rateLabel = Sources.HistoricalRate(mean)
  end
  return zoneText, rateText, rateLabel
end

-- The rows one group drew (rows from first on, at depth, each with the rows under it), with the
-- object rows of one name under Found in drawn as one group row. Changes rows in place.
function VM:_GroupSameNamedObjects(rows, parentKey, first, depth)
  if parentKey ~= ViewModel.OBJECT_GROUP_CATEGORY or #rows < first + 1 then
    return
  end
  -- The units: a row at this depth and every deeper row after it.
  local units, byName, repeated = {}, {}, false
  local index = first
  while index <= #rows do
    local head = rows[index]
    local unit = { head }
    index = index + 1
    while index <= #rows and (tonumber(rows[index].depth) or 0) > depth do
      unit[#unit + 1] = rows[index]
      index = index + 1
    end
    units[#units + 1] = unit
    local node = head.depth == depth and head.kind == "row" and type(head.node) == "table" and head.node or nil
    local edge = type(head.edge) == "table" and head.edge or nil
    if node and node.kind == "object" and type(node.name) == "string" and node.name ~= "" and edge then
      if edge.guess == nil and summaryOf(edge) == nil then
        local name = node.name:lower()
        byName[name] = byName[name] or {}
        local list = byName[name]
        list[#list + 1] = unit
        unit.name = name
        if #list > 1 then
          repeated = true
        end
      end
    end
  end
  if not repeated then
    return
  end
  local out, placed = {}, {}
  for _, unit in ipairs(units) do
    local list = unit.name and byName[unit.name] or nil
    if not list or #list < 2 then
      for _, row in ipairs(unit) do
        out[#out + 1] = row
      end
    elseif not placed[unit.name] then
      placed[unit.name] = true
      local head = unit[1]
      local key = parentKey .. "/objects:" .. slug(unit.name)
      local expanded = self:_IsExpanded(key, self.searching == true)
      local edges = {}
      for _, member in ipairs(list) do
        edges[#edges + 1] = member[1].edge
      end
      local zoneText, rateText, rateLabel = ViewModel.ObjectGroupFacts(edges)
      local source = type(head.source) == "table" and head.source or {}
      local group = {
        key = key,
        kind = "row",
        depth = depth,
        expanded = expanded,
        hasChildren = true,
        loop = false,
        capped = false,
        count = #list,
        -- Opens and closes on a click anywhere (UI/Tree.lua Interpret), as a node with no page.
        gatherNode = true,
        objectGroup = true,
        node = {
          key = key,
          kind = "object",
          type = head.node.type,
          name = head.node.name,
          icon = head.node.icon,
          badges = {},
        },
        source = {
          type = source.type,
          typeLabel = source.typeLabel,
          zone = zoneText,
          rate = rateText,
          rateLabel = rateLabel,
        },
      }
      self.index[key] = group
      out[#out + 1] = group
      if expanded then
        for _, member in ipairs(list) do
          for _, row in ipairs(member) do
            row.depth = (tonumber(row.depth) or depth) + 1
            out[#out + 1] = row
          end
        end
      end
    end
  end
  for at = first, math.max(#rows, first + #out - 1) do
    rows[at] = out[at - first + 1]
  end
end

-- Brief BQ25b (owner QA 2026-10-10 item 73, I67 half failed): a recorded row whose Classic Era twin
-- the table lists only behind the group's summary row ("Show 16 more") took that twin's rate only
-- once the list was opened (Graph.DropShadowedList in VM:_MoreEntries), so Stringy Wolf Meat's
-- Mangy Wolf row drew a blank rate and no "Classic Era drop rate: ~77.1%" line, where Mangy Wolf's
-- own page (VM:_NpcEdges) drew both. On the root's own groups only, where a live npc or object row
-- states no rate and no Classic Era rate yet and a summary beside it holds a list, that list is
-- read now, the same one decode a press on it costs and kept the same way (VM:_MoreEntries), so the
-- twin's rate reaches the live row before its source columns are worked out. Changes the live edges
-- only (Graph.AdoptSourceFacts).
function VM:_CarryListRates(entries, ownerKey)
  if ownerKey ~= self.root or type(entries) ~= "table" then
    return
  end
  local wanting = false
  for _, entry in ipairs(entries) do
    if
      type(entry) == "table"
      and entry.type
      and entry.dedupeName == nil
      and entry.guess == nil
      and entry.summary == nil
      and entry.eraRate == nil
      and entry.percent == nil
      and not entry.historical
    then
      local kind = Graph.Kind(entry.target)
      if kind == "npc" or kind == "object" then
        wanting = true
        break
      end
    end
  end
  if not wanting then
    return
  end
  for _, entry in ipairs(entries) do
    local summary = summaryOf(entry)
    if summary and type(summary.listed) == "number" and summary.listed > 0 then
      self:_MoreEntries(summary, entries)
    end
  end
end

-- QA 2026-10-10 item 26: a placeless Classic Era row of a group whose summary list holds the same
-- source with its place (Graph.PlacelessTwinsOf) is left out, so the chest draws once per place it
-- stands in. Until brief FIX159 only a list the player opened or the search reached was read for
-- this, so pressing "Show N more" drew the list and took a row away above it. Every list is read
-- now to count its rows (VM:_ListRows), so the twin is left out from the first draw and a press
-- only ever adds. Answers the set of sibling edges left out, keyed by the edge, or nil.
function VM:_ListTwins(entries)
  local hidden = nil
  for _, entry in ipairs(entries or EMPTY) do
    local summary = listedSummary(entry)
    if summary and type(entry.target) == "string" then
      local twins = Graph.PlacelessTwinsOf(entries, self:_MoreEntries(summary, entries))
      for edge in pairs(twins or EMPTY) do
        hidden = hidden or {}
        hidden[edge] = true
      end
    end
  end
  return hidden
end

-- entries drawn at depth without the twins VM:_ListTwins leaves out, or entries itself where there
-- are none (or the depth cap leaves every summary a plain row, so no list is drawn).
function VM:_DropListTwins(entries, depth)
  local hidden = self:_ListsOpen(depth) and self:_ListTwins(entries) or nil
  if not hidden then
    return entries
  end
  local out = {}
  for _, entry in ipairs(entries) do
    if not hidden[entry] then
      out[#out + 1] = entry
    end
  end
  return out
end

-- Brief QN1: the quest rows one group just drew (rows from first on, at this depth: a row's own
-- children sit deeper) told apart where two read the same (ViewModel.DisambiguateQuestTitles).
-- Brief QV1 (the owner's ruling "2.a", 2026-10-18): a row's place is the one its own location column
-- names (questPlace, VM:_DecorateNode) before any other, so the brackets and the column agree ("City
-- of Dalaran" on his A Donation of Wool 99191); rows still alike gain the reputation their quest gives
-- (else the giver's name) as a second part; and a row told apart whose column held nothing of its
-- own (the Classic Era row 7802, which no record of his names a zone for) shows its place there too.
function VM:_TellQuestsApart(rows, first, depth)
  local quests = nil
  for index = first, #rows do
    local row = rows[index]
    local node = row.depth == depth and type(row.node) == "table" and row.node or nil
    if node and node.kind == "quest" and type(node.name) == "string" then
      quests = quests or {}
      local base = type(node.plainTitle) == "string" and node.plainTitle or nil
      quests[#quests + 1] = {
        node = node,
        questId = node.id,
        title = node.name,
        zone = node.questPlace,
        base = base,
        chain = base and ViewModel.QuestChain(node.id) or nil,
      }
    end
  end
  if not quests or #quests < 2 then
    return
  end
  ViewModel.DisambiguateQuestTitles(quests, ViewModel.QuestZone, ViewModel.QuestReputation, ViewModel.QuestGiverName)
  for _, entry in ipairs(quests) do
    entry.node.name = entry.displayTitle
    if entry.zoneShown and ViewModel.QuestColumnEmpty(entry.node) then
      entry.node.meta = ViewModel.WithSideWords(entry.zoneShown, entry.node.sideWords)
    end
  end
end

-- The key of the "Show N more" row a shipped summary draws as, and so (through VM:ShowMore, which
-- drops the "/more") the mark that says the player pressed it: self.shown[rowKey .. "/listed"].
-- The list itself pages under the summary's own key, so its rows keep the keys they have always
-- had (rowKey .. "/" .. their node) and its own group cap row is rowKey .. "/more".
local function listedKey(rowKey)
  return rowKey .. "/listed"
end

-- E75: a summary whose list is shipped, as the one "Show N more" pattern the tree uses.
--
-- Until the player presses it (or while the search box holds something, which reaches past every
-- summary so the box can find a creature the cap never named) it is a more row at the named rows'
-- own depth. Its words are the table's ("Show 15 more", or "Show 184 vendors" where the pipeline
-- named none), and its note ("level 11 to 36") is what the row's tooltip adds to them.
--
-- Once pressed there is no summary row at all: the rest of the list is drawn in place, at that
-- same depth, as ordinary source rows. The search draws the whole list, because a page would hide
-- the very row it is looking for.
--
-- Brief FIX176 (owner QA 2026-10-14 item 176, Pugilist Bracers' Drops from (30): 3 rows and "Show
-- 27 more", then 11 rows and "Show 19 more", then 30): the pressed list went through
-- _AppendGroup's cap again, so a press drew 8 of the rows it promised. The press now draws the
-- whole list (_AppendGroup's open), every row the summary's number counted and no cap row after
-- them. opened is true where a group cap's pressed row stood over this summary, which draws it
-- whole in the same way (VM:_AppendGroup).
function VM:_AppendListed(rows, rowKey, nodeKey, edge, node, summary, depth, path, ownerKey, siblings, opened)
  local pressed = opened == true or self.shown[listedKey(rowKey)] == true
  if not pressed and not self.searching then
    -- Brief FIX159: the number is the rows a press adds (VM:_ListRows), and the words say it. A
    -- list whose every row is already drawn beside it adds nothing, so it is no row at all.
    local count = self:_ListRows(edge, siblings)
    if count <= 0 then
      return
    end
    self:_Push(rows, {
      key = listedKey(rowKey) .. "/more",
      kind = "more",
      depth = depth,
      moreCount = count,
      text = ViewModel.SummaryWords(node.name, summaryRows(edge, summary), count, summary.category),
      note = edge.note,
      -- What the row stands for: the summary ({ item, category, listed }) and the edge the table
      -- wrote it as, so a reader can still tell which Classic Era row this is.
      summary = summary,
      edge = edge,
    })
    return
  end
  local listed = self:_MoreEntries(summary, siblings)
  local nextPath = { [nodeKey] = true }
  for key in pairs(path) do
    nextPath[key] = true
  end
  if self.searching then
    for _, listedEdge in ipairs(listed) do
      self:_AppendEntry(rows, rowKey, listedEdge, depth, nextPath, ownerKey)
    end
    return
  end
  self:_AppendGroup(rows, rowKey, listed, depth, nextPath, ownerKey, true)
end

-- A craft and the one item it makes, as one row for that item (opts.mergeCrafts).
--
-- "Boiled Clams" the cooking spell with "Boiled Clams" the item under it says the same thing
-- twice, and in the Used by view of a reagent it says it once per craft. Merged, the row IS the
-- item: the item's key, name, icon and quality, so a click opens the item and the tooltip is the
-- item's. It keeps what the craft's row said, the quantity of the root that craft eats and the
-- skill and level it asks for, and the craft's own marks. The one fact the craft's row carried
-- that the item's cannot is the recipe item that teaches it, which is what a player is looking
-- for ("is this a recipe or just a trained spell"), so it travels on the row as craft.recipe.
--
-- Only in the Used by view: under Sources, Requires and Disenchants into the spell is the answer
-- to the question the tab asks. Everything below is additive. With the option off none of it is
-- reached and every row is byte for byte the row it was before this existed, which is how it can
-- be taken out again.
function VM:_Merging()
  if not self.opts.mergeCrafts then
    return false
  end
  return self.view == Edges.USES
end

-- The one item a craft makes, as the edge pointing at it, or nil when the craft is not one row's
-- worth: exactly one visible child, and that child an item. An enchant has none, a craft with
-- more than one child would lose whatever the second one is, and a child this client cannot name
-- is no row to merge into.
--
-- This is the one walk the merge costs: a closed craft row used to answer the chevron with
-- Graph.HasChildren, which stops at the first edge, and now its children are worked out whether
-- it is open or not. A craft's down side is its one product and, for an enchanter, the enchant,
-- so the walk is two emits, and the answer is cached under the row key the craft would have had,
-- which is the very key the unmerged row reads it back from.
function VM:_SoleProduct(rowKey, spellKey)
  local children = self:_ChildEntries(rowKey, spellKey)
  if #children ~= 1 then
    return nil
  end
  local product = children[1]
  if Graph.Kind(product.target) ~= "item" then
    return nil
  end
  return product
end

-- The item's badges, plus the craft's where the craft has one the item does not, in that order
-- and with no duplicates: a New recipe for an item that has been in the game all along still
-- reads as New, and a change to both is one mark rather than two.
function VM:_MergedBadges(itemNode, spellNode, edge)
  local badges = self:_Badges(itemNode, edge)
  local held = {}
  for _, badge in ipairs(badges) do
    held[badge] = true
  end
  for _, badge in ipairs(self:_Badges(spellNode, edge)) do
    if not held[badge] then
      held[badge] = true
      badges[#badges + 1] = badge
    end
  end
  return badges
end

-- The root's own name, worked out once per view model: what a merged row's meta has to be
-- measured against, because the page the player is already on is not news on a row of it.
function VM:_RootName()
  if self.rootName == nil then
    local node = Graph.Node(self.root)
    local name = node and node.name or nil
    if type(name) == "string" and name ~= "" then
      self.rootName = name
    else
      self.rootName = false
    end
  end
  if self.rootName == false then
    return nil
  end
  return self.rootName
end

-- The meta line a merged row draws, chosen rather than taken from the first place that states
-- one (brief E30 task 2).
--
-- Three things can state one. The craft says what it asks of the player ("Blacksmithing 10", or
-- on an item combine the item you cast it by using). The edge says what the root is to this
-- craft, which on a TOOL_FOR edge is the tool's own totem category name. The item says what it
-- asks of whoever uses it. The craft's leads, because that is the line the craft's own row
-- carried and this row is standing in for it; every candidate that only repeats the root is
-- skipped, because "Blacksmith Hammer" on a row of Blacksmith Hammer's own page says nothing
-- and it was replacing "Engineering 30" on 63 rows there and 71 on Arclight Spanner's.
--
-- If every candidate repeats the root, the first is drawn anyway: on Bent Sigil's own page the
-- combine's "Bent Sigil" is all the row says about the craft, and a blank column says less.
function VM:_MergedMeta(itemNode, spellNode, edge)
  local candidates = {}
  local function offer(value)
    if type(value) == "string" and value ~= "" then
      candidates[#candidates + 1] = value
    end
  end
  offer(spellNode.meta)
  if edge then
    offer(edge.meta)
  end
  offer(itemNode.meta)
  local rootName = self:_RootName()
  for _, text in ipairs(candidates) do
    if text ~= rootName then
      return text
    end
  end
  return candidates[1]
end

-- The item's node wearing the craft row's numbers: the edge decorates it exactly as it would
-- have decorated the craft's own row, so the quantity column still says how many of the root
-- this craft eats, and the meta column still says the skill and the level.
function VM:_MergedNode(itemNode, spellNode, edge)
  local node = self:_DecorateNode(itemNode, edge)
  node.meta = self:_MergedMeta(itemNode, spellNode, edge)
  node.badges = self:_MergedBadges(itemNode, spellNode, edge)
  return node
end

-- Both change lists, the item's first. The row wears the craft's Changed badge as well as the
-- item's, and a badge that promises rows has to have them under it.
function VM:_MergedChanges(itemNode, spellNode)
  local changes = {}
  for _, change in ipairs(self:_Changes(itemNode)) do
    changes[#changes + 1] = change
  end
  for _, change in ipairs(self:_Changes(spellNode)) do
    changes[#changes + 1] = change
  end
  return changes
end

-- What the row says about the craft behind it. The filter box matches on name, so a player can
-- still find the row by the spell's name; the tree draws the yield and the recipe mark.
--
-- A recipe item that is the very node this branch hangs off is left out: under the Teaches
-- category of Plans: Old Blade, every row is taught by Plans: Old Blade, and a mark saying so on
-- each of them is the noise the merge is here to remove.
function VM:_CraftFacts(spellNode, product, ownerKey)
  local craft = {
    key = spellNode.key,
    name = spellNode.name,
    yield = product.quantity,
    yieldMax = product.quantityMax,
  }
  local recipes = {}
  for _, taught in ipairs(Graph.TaughtBy(spellNode.id)) do
    if taught.key ~= ownerKey then
      recipes[#recipes + 1] = taught
    end
  end
  if #recipes > 0 then
    craft.recipe = recipes[1].key
    craft.recipeName = recipes[1].name
    craft.recipes = recipes
  end
  return craft
end

--------------------------------------------------------------------------------
-- EXPERIMENTAL (brief E25): what a craft is made of, on the craft's own row.
--
-- Everything in this block is reached only from opts.craftIngredients, and every mode but "off"
-- reaches it, so the whole feature comes out again by deleting this block and the four calls
-- marked E25 below. With the option off, or missing, not one line of it runs and the rows are
-- byte for byte the rows this file built before it existed.
--------------------------------------------------------------------------------

-- The mode in force for this walk. Only the Used by view has craft rows to hang ingredients on:
-- under Sources, Requires and Disenchants into the reagents are already rows of their own, and
-- listing them twice would be the noise this is trying to save.
function VM:_CraftMode()
  if self.view ~= Edges.USES then
    return "off"
  end
  return ViewModel.CraftIngredients(self.opts.craftIngredients)
end

-- Whether the mode in force draws one of the four surfaces here. The rows this file adds are the
-- group's, so this file only ever asks about "group"; it is written as the general question
-- because the drawing sites in UI ask the same one of the same table.
function VM:_CraftShows(surface)
  return ViewModel.CraftIngredientShows(self:_CraftMode(), surface)
end

-- One reagent or tool as the row carries it: the node's own name, art and quality, plus the
-- count the recipe asks for. An item nothing on this client names keeps its honest fallback
-- ("Item 13444") rather than borrowing a name from anywhere, which is the same rule the tree
-- draws an undiscovered row by.
local function craftPart(edge)
  local kind, id = Graph.Parse(edge.target)
  local node = Graph.Node(edge.target)
  local name = node and node.name or nil
  if (type(name) ~= "string" or name == "") and kind then
    name = Graph.Fallback(kind, id)
  end
  return {
    key = edge.target,
    name = name or tostring(edge.target),
    icon = node and node.icon or nil,
    quality = node and node.quality or nil,
    quantity = edge.quantity,
    quantityMax = edge.quantityMax,
  }
end

-- Every reagent a craft asks for and every tool it needs, from the graph and from nothing else:
-- these are the craft's own up edges, which is the list the Requires view of that craft draws.
-- No client call is made anywhere in here, and no item is ever queried: the reagent list is
-- shipped data.
--
-- ownerKey is the node the craft row hangs off, which is the root under a category and the
-- parent item deeper in. That reagent is marked root = true, because a player reading
-- "Refreshing Spring Water > Nightfin Soup" wants to see at a glance which of the ingredients is
-- the one they already had.
function VM:_CraftParts(spellKey, ownerKey)
  local slot = tostring(spellKey) .. "\0" .. tostring(ownerKey)
  local cached = self.crafts[slot]
  if cached then
    return cached
  end
  local parts = { ingredients = {}, tools = {} }
  for _, edge in ipairs(Graph.Children(spellKey, Edges.UP)) do
    local def = edge.type
    local name = type(def) == "table" and def.name or nil
    if name == "REAGENT" then
      local part = craftPart(edge)
      if part.key == ownerKey then
        part.root = true
      end
      parts.ingredients[#parts.ingredients + 1] = part
    elseif name == "REQUIRES_TOOL" then
      local part = craftPart(edge)
      parts.tools[#parts.tools + 1] = { key = part.key, name = part.name, icon = part.icon }
    end
  end
  self.crafts[slot] = parts
  return parts
end

-- The parts a craft row carries, or nil where this row is not a craft row or the mode is off.
-- Every mode but off wants them somewhere, on the row's tooltip, under its chevron, in a strip
-- or in the item column, so they are worked out for all of them and gated only at the surface.
-- spellNode is the craft behind the row: the row's own node where it is a spell, and the craft
-- the merge folded away where it is a merged row.
function VM:_RowParts(spellNode, ownerKey)
  if not spellNode or spellNode.kind ~= "spell" or self:_CraftMode() == "off" then
    return nil
  end
  local parts = self:_CraftParts(spellNode.key, ownerKey)
  if #parts.ingredients == 0 and #parts.tools == 0 then
    return nil
  end
  return parts
end

-- The muted group row and its leaves, as the FIRST children of a craft row, in every mode that
-- asks for the group ("group" and "all").
--
-- The group is closed to begin with, so an opened craft row still leads with its own uses; the
-- leaves are plain item rows that open like any other row and never expand further. Neither the
-- group nor a leaf is counted anywhere (a category's count is its edges, which these are not)
-- and UI/Tree.lua drops both from the search, so every mode filters and counts alike.
function VM:_AppendIngredientGroup(rows, parentKey, parts, depth)
  local key = parentKey .. "/ingredients"
  local expanded = self:_IsExpanded(key, false)
  self:_Push(rows, {
    key = key,
    kind = "row",
    depth = depth,
    expanded = expanded,
    hasChildren = true,
    loop = false,
    capped = false,
    ingredientGroup = true,
    ingredients = parts.ingredients,
    tools = parts.tools,
    text = string.format(L["Ingredients (%d)"], #parts.ingredients),
  })
  if not expanded then
    return
  end
  for _, part in ipairs(parts.ingredients) do
    local kind, id = Graph.Parse(part.key)
    local node = { key = part.key, kind = kind or "item", id = id, type = "item" }
    self:_Push(rows, {
      key = key .. "/" .. part.key,
      kind = "row",
      depth = depth + 1,
      expanded = false,
      hasChildren = false,
      loop = false,
      capped = false,
      ingredient = true,
      root = part.root,
      node = {
        key = part.key,
        kind = node.kind,
        id = id,
        type = "item",
        name = part.name,
        icon = part.icon,
        quality = part.quality,
        quantity = part.quantity,
        quantityMax = part.quantityMax,
        badges = self:_Badges(node, nil),
      },
    })
  end
end

-- Draws the merged row and everything under it, or answers false when this entry is not a craft
-- with one product, or is reached by an edge type the merge leaves alone, and the caller should
-- build the row it always built.
function VM:_AppendMerged(rows, parentKey, edge, spellNode, depth, path, ownerKey)
  if not self:_Merging() or spellNode.kind ~= "spell" then
    return false
  end
  -- Brief E30: a "Tool for" row is what the unmerged tree draws, whatever the setting says, and
  -- the answer comes before the walk _SoleProduct costs.
  if not ViewModel.MergesEdge(edge and edge.type or nil) then
    return false
  end
  local spellKey = spellNode.key
  local product = self:_SoleProduct(parentKey .. "/" .. spellKey, spellKey)
  if not product then
    return false
  end
  local itemKey = product.target
  local itemNode = Graph.Node(itemKey)
  if not itemNode then
    return false
  end
  -- An item this build withholds is no row to merge into. The merge makes the row the item, and
  -- a withheld item has no name of its own, so "Demon Forged Breastplate" under Plans: Demon
  -- Forged Breastplate became "Undiscovered plate chest" and the one readable name on the row
  -- was gone; Blacksmith Hammer's Tool for list read "Undiscovered axe" 77 times over. Such a
  -- craft keeps the two rows it has always had, the named craft over the dimmed placeholder. An
  -- item something outside the data has since named (node.discovered) has a name to take and
  -- merges as it always did.
  if itemNode.undiscovered and not itemNode.discovered then
    return false
  end

  -- The path is now root to item, so that is the key. Two crafts under one category that make
  -- the same item would land on one key, and then one chevron would open both rows, so the
  -- second says which craft it is; the first keeps the plain key a player's saved expansion
  -- state is already written against.
  local rowKey = parentKey .. "/" .. itemKey
  if self.index[rowKey] then
    rowKey = rowKey .. "~" .. tostring(spellNode.id)
  end
  local loop = path[itemKey] == true or path[spellKey] == true
  local capped = depth >= self.opts.maxDepth
  local changes = self:_MergedChanges(itemNode, spellNode)
  local expanded, hasChildren, children = false, false, nil

  if not loop and not capped then
    -- Opened the way the item's own row opened under the craft, which is one level deeper than
    -- the row now sits: the merge takes a level out of the tree and must not open a level the
    -- player never asked for in its place.
    expanded = self:_IsExpanded(rowKey, self:_DefaultExpanded(depth + 1))
    if expanded then
      children = self:_ChildEntries(rowKey, itemKey)
      hasChildren = #children > 0 or #changes > 0
    else
      -- Brief F155: the chevron asks the walk the row would open with, the other side left out.
      local walk = {
        showPredicted = self.opts.showPredicted,
        includeTrainer = true,
        includeHistorical = true,
        hideSide = self:_HiddenSide(),
      }
      hasChildren = #changes > 0 or Graph.HasChildren(itemKey, self.direction, walk)
    end
  end

  -- E25: the merged row IS the craft, so the craft's own reagents hang off it. The group is a
  -- child of its own, so a craft with nothing else under it still opens; the row says when the
  -- group is all it has, and the pane draws that chevron dimmer.
  local parts = self:_RowParts(spellNode, ownerKey)
  local ingredientsOnly = false
  if parts and not loop and not capped and self:_CraftShows("group") and #parts.ingredients > 0 then
    ingredientsOnly = not hasChildren
    hasChildren = true
  end

  local row = self:_Push(rows, {
    key = rowKey,
    kind = "row",
    depth = depth,
    expanded = expanded and hasChildren,
    hasChildren = hasChildren,
    loop = loop,
    capped = capped,
    count = children and #children or nil,
    edge = edge,
    merged = true,
    craft = self:_CraftFacts(spellNode, product, ownerKey),
    node = self:_MergedNode(itemNode, spellNode, edge),
    ingredients = parts and parts.ingredients or nil,
    tools = parts and parts.tools or nil,
    ingredientsOnly = ingredientsOnly or nil,
  })
  if not row.expanded then
    return true
  end
  -- E25: the group leads the children, so the item's own uses read exactly as they do today
  -- under it ("Ingredients (2)", then Supply Shipment).
  if parts and self:_CraftShows("group") and #parts.ingredients > 0 then
    self:_AppendIngredientGroup(rows, rowKey, parts, depth + 1)
  end

  -- The same tail _AppendEntry draws, over the merged row's own change list, and with both node
  -- keys on the path: the craft is not a row any more and still must not be walked into twice.
  for index, change in ipairs(changes) do
    self:_Push(rows, {
      key = rowKey .. "/change:" .. index,
      kind = "change",
      depth = depth + 1,
      change = {
        field = change.field,
        label = change.label,
        op = change.op,
        text = change.text,
        oldText = change.oldText,
        newText = change.newText,
      },
    })
  end
  if not children or #children == 0 then
    return true
  end
  local nextPath = { [itemKey] = true, [spellKey] = true }
  for key in pairs(path) do
    nextPath[key] = true
  end
  self:_AppendGroup(rows, rowKey, children, depth + 1, nextPath, itemKey)
  return true
end

--------------------------------------------------------------------------------
-- Brief TC1: Total counts.
--
-- Off (the default), a reagent row says how many one craft eats: Lionheart Helm's Arcanite Bar
-- x12, and under it Transmute: Arcanite's Thorium Bar x1 and Arcane Crystal x1. On, the counts
-- multiply down the tree: an item needed N times is made by ceil(N / yield) crafts, and each of
-- that craft's reagents is needed (its count per craft * crafts) times, which is the N passed on
-- to whatever is opened under it. So the Thorium Bar under 12 Arcanite Bars reads x12.
--
-- Only in the two views that walk down from an item to what it is made from (Sources and
-- Requires). Only a REAGENT edge's count is multiplied, because that is the one count the game
-- states as what a craft eats: a tool (REQUIRES_TOOL), the recipe item that teaches the craft
-- (TAUGHT_BY), an item a combine is cast by using (REAGENT with used = true), a drop, a vendor,
-- a quest, a percentage and a seen tally keep the number they always had. Each row is worked out
-- from its own parent chain, kept in self.totals under the row's key, so the same item under two
-- crafts reads two totals. The loop and depth guards that bound the walk bound this too.
--------------------------------------------------------------------------------

-- The largest total written: the largest count a Lua number prints exactly (%.14g in 5.1).
ViewModel.TOTAL_MAX = 99999999999999

-- The views the totals apply in.
local TOTAL_VIEWS = { [Edges.SOURCES] = true, [Edges.REQUIRES] = true }

-- What the root passes to its category's rows: an item is needed once, and a craft's own page is
-- one run of it. Pure.
function ViewModel.RootTotal(rootKey)
  local kind = Graph.Parse(rootKey)
  if kind == "spell" then
    return { crafts = 1 }
  end
  return { need = 1 }
end

-- How many times a craft has to run to make need of an item when one run makes yield of it:
-- ceil(need / yield), with an unknown or nonsense yield read as 1 and the answer capped at
-- ViewModel.TOTAL_MAX. A ranged yield is passed as its LOW end by the caller, so the count is
-- never short. Pure.
function ViewModel.CraftsFor(need, yield)
  need = tonumber(need)
  if not need or need < 1 then
    return 1
  end
  local per = tonumber(yield)
  if not per or per < 1 then
    per = 1
  end
  local crafts = math.ceil(need / per)
  if crafts > ViewModel.TOTAL_MAX then
    crafts = ViewModel.TOTAL_MAX
  end
  return crafts
end

-- A reagent's count across every run of its craft: perCraft * crafts, capped at
-- ViewModel.TOTAL_MAX. Pure.
function ViewModel.TotalCount(perCraft, crafts)
  local per = tonumber(perCraft) or 1
  local runs = tonumber(crafts) or 1
  local total = per * runs
  if total > ViewModel.TOTAL_MAX then
    total = ViewModel.TOTAL_MAX
  end
  return total
end

-- The low end of what one run of a craft makes, from the PRODUCED_BY edge that points at it
-- (its quantity and quantityMax are recipe.out's min and max), or 1 where the build states none.
-- Pure.
function ViewModel.YieldLow(edge)
  if type(edge) ~= "table" then
    return 1
  end
  local low = tonumber(edge.quantity)
  local high = tonumber(edge.quantityMax)
  if low and high and high < low then
    low = high
  end
  low = low or high
  if not low or low < 1 then
    return 1
  end
  return low
end

-- Whether the totals are worked out for these rows at all.
function VM:_Totalling()
  return self.opts.totalCounts == true and TOTAL_VIEWS[self.view] == true
end

-- One row's share of the totals. The parent's record says what it passes down ({ need = N } from
-- an item, { crafts = C } from a craft); a craft under an item records how many runs it takes, a
-- reagent under a craft gets its total written onto its own node and records it as its need.
-- Every other row records nothing, so nothing under it is multiplied. The node is the decorated
-- copy, never the graph's own table.
--
-- A multiplied node keeps its count for one craft in perCraft and the runs in crafts, only where
-- the total differs from the count for one craft, which is what the tooltip line reads.
function VM:_ApplyTotal(parentKey, rowKey, edge, node, decorated)
  local parent = self.totals[parentKey]
  local def = type(edge) == "table" and edge.type or nil
  local name = type(def) == "table" and def.name or nil
  if type(parent) ~= "table" or not name then
    return nil
  end
  if name == "PRODUCED_BY" and node.kind == "spell" and parent.need then
    local record = { crafts = ViewModel.CraftsFor(parent.need, ViewModel.YieldLow(edge)) }
    self.totals[rowKey] = record
    return record
  end
  if name ~= "REAGENT" or not parent.crafts or edge.used or decorated.seen then
    return nil
  end
  local perCraft = tonumber(edge.quantity) or 1
  local total = ViewModel.TotalCount(perCraft, parent.crafts)
  local record = { need = total }
  self.totals[rowKey] = record
  if total ~= perCraft then
    decorated.quantity = total
    decorated.quantityMax = nil
    decorated.perCraft = perCraft
    decorated.crafts = parent.crafts
  end
  return record
end

-- openList is true where a pressed group cap stood over this entry (VM:_AppendGroup, brief
-- FIX176): a shipped summary is then drawn opened onto its list.
function VM:_AppendEntry(rows, parentKey, entry, depth, path, ownerKey, openList)
  -- Brief Q8: a quest's tab draws its own flat rows.
  if self.view == ViewModel.QUEST_VIEW then
    return self:_AppendQuestEntry(rows, parentKey, entry, depth)
  end
  -- Brief TR2: a Teaches line ("Teaches Mining up to Artisan") draws as a Trains row once did.
  if type(entry.requirement) == "table" and entry.requirement.trains == true then
    return self:_AppendTrainsEntry(rows, parentKey, entry, depth)
  end
  if entry.requirement then
    local requirement = entry.requirement
    -- Brief TB10: a class locked consumable's own use is a row of kind "class" in its own group.
    local classUse = requirement.classUse == true
    self:_Push(rows, {
      key = parentKey .. "/req:" .. slug(requirement.label),
      kind = "row",
      depth = depth,
      expanded = false,
      hasChildren = false,
      loop = false,
      capped = false,
      node = {
        key = "req:" .. slug(requirement.label),
        kind = classUse and "class" or "requirement",
        type = "skill",
        name = requirement.label,
        icon = GROUP_ICONS[classUse and CLASS_USE_GROUP or REQUIREMENTS_GROUP],
        badges = {},
      },
    })
    return
  end

  local edge = entry
  local nodeKey = edge.target
  local node = Graph.Node(nodeKey)
  if not node then
    return
  end
  -- Brief OL2: the rows of one item on a chest's Loot tab, folded into one.
  if type(edge.lootZones) == "table" then
    return self:_AppendLootFold(rows, parentKey, edge, node, depth, path, ownerKey)
  end
  if self:_AppendMerged(rows, parentKey, edge, node, depth, path, ownerKey) then
    return
  end
  local rowKey = parentKey .. "/" .. nodeKey
  -- Two rows of one opened list can name the same creature in the same place, because the list
  -- is what a cap left over and nothing merged it the way the graph merges its own edges. The
  -- second takes a key of its own rather than overwriting the first in the index.
  if self.index[rowKey] then
    rowKey = rowKey .. "~" .. tostring(#rows)
  end
  local loop = path[nodeKey] == true
  local capped = depth >= self.opts.maxDepth
  local changes = self:_Changes(node)
  local summary = summaryOf(edge)
  local expanded, hasChildren, children = false, false, nil

  if summary then
    -- A summary row is never walked into: what is under it is the rest of its own list, not the
    -- sources of the thing it names, because it names nothing. A row with no list shipped has
    -- nothing under it at all and draws as a plain row that opens nothing.
    --
    -- E75, the owner: "Lets use the same yellow search + wording pattern everywhere instead of
    -- the expandable one." A summary whose list is shipped is the group cap's own "Show N more"
    -- row, at the named rows' depth, and pressing it draws the list in place. E87: under ANY
    -- owner, not only the root, so "Show 2 more" under a nested row presses too. The list's rows
    -- key off this row's key, which already carries the whole path, so they stay unique.
    if summary.listed > 0 and not loop and not capped then
      local siblings = self.groupEntries and self.groupEntries[parentKey] or nil
      self:_AppendListed(rows, rowKey, nodeKey, edge, node, summary, depth, path, ownerKey, siblings, openList)
      return
    end
  elseif not loop and not capped then
    expanded = self:_IsExpanded(rowKey, self:_DefaultExpanded(depth, node) or self:_OpensCraft(edge, depth))
    if expanded then
      children = self:_ChildEntries(rowKey, nodeKey)
      hasChildren = #children > 0 or #changes > 0
    else
      -- Brief F155: the other side left out, as the row would open.
      hasChildren = #changes > 0
        or Graph.HasChildren(nodeKey, self.direction, {
          showPredicted = self.opts.showPredicted,
          includeTrainer = true,
          includeHistorical = true,
          hideSide = self:_HiddenSide(),
        })
    end
  end

  -- E25: the same on the unmerged spell row, which is the craft row a player sees with Merge
  -- recipes off. _RowParts answers nil for everything that is not a craft and for the off mode,
  -- so with the option off this is one type check and nothing else.
  local parts = self:_RowParts(node, ownerKey)
  local ingredientsOnly = false
  if parts and not loop and not capped and self:_CraftShows("group") and #parts.ingredients > 0 then
    ingredientsOnly = not hasChildren
    hasChildren = true
  end

  local gather = isGatherNode(nodeKey)
  local source = self:_Source(edge, ownerKey)
  local decorated = self:_DecorateNode(node, edge, ownerKey)
  -- Brief TC1: with Total counts on, a reagent row's count becomes the total its parent chain
  -- needs. Off, nothing here runs and the node is the one _DecorateNode built.
  if self:_Totalling() then
    self:_ApplyTotal(parentKey, rowKey, edge, node, decorated)
  end
  local row = self:_Push(rows, {
    key = rowKey,
    kind = "row",
    depth = depth,
    expanded = expanded and hasChildren,
    hasChildren = hasChildren,
    loop = loop,
    capped = capped,
    count = children and #children or nil,
    edge = edge,
    source = source,
    node = decorated,
    ingredients = parts and parts.ingredients or nil,
    tools = parts and parts.tools or nil,
    ingredientsOnly = ingredientsOnly or nil,
    -- A row that stands for a group rather than for a thing: { item, category, listed }. Only a
    -- summary that opens nothing is drawn as a row (a world drop, a guess that names no source,
    -- or a list the loop or the depth cap stops), and the pane reads this to answer a click on it
    -- with nothing rather than with a re-root onto a node the table made up. An unlisted
    -- remainder draws as the words it is rather than as a source (brief E87, UI/Tree.lua).
    summary = summary,
    -- Brief D6: a Classic Era gathering node's own row, which opens onto its zones and has no
    -- page to re-root onto (UI/Tree.lua Interpret).
    gatherNode = gather or nil,
    -- Brief D7: such a row whose node has a Map page: its name opens that page.
    gatherPage = (gather and hasNodePage(nodeKey)) or nil,
    -- Brief Z1: the zone the row's zone column names, which the column opens ({ key, name }), and
    -- on a zone's own Here tab the source the row names, which the column picks for the Map tab
    -- ({ nameIndex, kind, name }). UI/Tree.lua draws either as a link.
    zoneLink = self:_ZoneLink(edge, source),
    zonePick = (self.view == Edges.HERE and edge.pick) or nil,
    -- Brief N1: on a zone's Here tab, the page the source the row names opens on ({ key, name }).
    sourceLink = self:_SourceLink(edge),
  })
  if not row.expanded then
    return
  end
  -- E25: the group leads the craft's children here too.
  if parts and self:_CraftShows("group") and #parts.ingredients > 0 then
    self:_AppendIngredientGroup(rows, rowKey, parts, depth + 1)
  end

  for index, change in ipairs(changes) do
    self:_Push(rows, {
      key = rowKey .. "/change:" .. index,
      kind = "change",
      depth = depth + 1,
      -- op and text come straight off Diff.ChangeLines: a multi value field answers with one
      -- line per entry, and an entry that came or went carries only its own side, so a row that
      -- read oldText and newText alone would draw "to +14 Shadow spell damage".
      change = {
        field = change.field,
        label = change.label,
        op = change.op,
        text = change.text,
        oldText = change.oldText,
        newText = change.newText,
      },
    })
  end

  if not children or #children == 0 then
    return
  end
  local nextPath = { [nodeKey] = true }
  for key in pairs(path) do
    nextPath[key] = true
  end
  -- Brief BQ15 (QA 2026-10-10 item 1, replacing BQ4's flat label): under Used by, a quest opened
  -- under the item it asks for lists what it hands back inside its own "Rewards (n)" group, the
  -- shape a craft's "Ingredients (n)" takes, open to begin with, the rewards one level beneath it.
  local rewards, rest = self:_SplitRewards(node, children)
  if rewards then
    self:_AppendRewardGroup(rows, rowKey, rewards, depth + 1, nextPath, nodeKey, edge.listed == true)
    if #rest == 0 then
      return
    end
    children = rest
  end
  self:_AppendGroup(rows, rowKey, children, depth + 1, nextPath, nodeKey)
end

-- Brief OL2: one item's folded loot row (ViewModel.FoldLootByItem), drawn the way a chest under
-- an item's Found in is (VM:_GroupSameNamedObjects): the item, its zone column saying the one zone
-- or how many ("3 zones"), its rate column the best rate its rows state, and opening onto the rows
-- it stands for, each with its own zone and rate, which are ordinary item rows. The name opens the
-- item's page and the chevron the zones (UI/Tree.lua Interpret, gatherNode with gatherPage).
-- Closed by default; open while the search box holds anything, so a search reaches each zone.
function VM:_AppendLootFold(rows, parentKey, edge, node, depth, path, ownerKey)
  local members = edge.lootZones
  local key = parentKey .. "/items:" .. tostring(edge.target)
  if self.index[key] then
    key = key .. "~" .. tostring(#rows)
  end
  local expanded = self:_IsExpanded(key, self.searching == true)
  local source = nil
  local best = self:_Source(edge, ownerKey)
  if best then
    source = {}
    for field, value in pairs(best) do
      source[field] = value
    end
    source.zone = ViewModel.LootFoldZone(members)
  end
  self:_Push(rows, {
    key = key,
    kind = "row",
    depth = depth,
    expanded = expanded,
    hasChildren = true,
    loop = false,
    capped = false,
    count = #members,
    edge = edge,
    source = source,
    node = self:_DecorateNode(node, edge, ownerKey),
    gatherNode = true,
    gatherPage = true,
    lootFold = true,
  })
  if not expanded then
    return
  end
  for _, member in ipairs(members) do
    self:_AppendEntry(rows, key, member, depth + 1, path, ownerKey)
  end
end

-- Brief BQ15: an opened row's children split into its rewards (QUEST_REWARDS) and the rest, where
-- the row is a quest in the Used by view with at least one reward below it; nil otherwise, and
-- the children then draw as they always did. Pure over the entries; the order inside each half is
-- the order they came in.
function VM:_SplitRewards(node, children)
  if self.view ~= Edges.USES or type(node) ~= "table" or node.kind ~= "quest" then
    return nil, children
  end
  local rewardType = Edges.Types.QUEST_REWARDS
  local rewards, rest = {}, {}
  for _, child in ipairs(children) do
    if type(child) == "table" and child.type == rewardType then
      rewards[#rewards + 1] = child
    else
      rest[#rest + 1] = child
    end
  end
  if #rewards == 0 then
    return nil, children
  end
  return rewards, rest
end

-- Brief BQ15: the "Rewards (n)" group row and, while it is open (it starts open), the rewards
-- under it one level deeper. The group is a header, not a thing: it carries no node, the search
-- box drops it (UI/Tree.lua FilterRows) and a click anywhere on it opens or closes it. The
-- rewards are ordinary rows of the view, keyed under the group, paged by the same group cap.
--
-- listed is whether the Forever client lists the quest (Q1, the quest row wears no Predicted mark).
-- Its rewards then carry listedReward, so a Predicted mark on one says it is a Classic Era reward
-- not yet seen in Forever (UI/Tree.lua BadgeBasis): the client's tables carry no quest rewards
-- (BQ17), so the quest is real and only what it hands back is Classic Era's.
function VM:_AppendRewardGroup(rows, parentKey, rewards, depth, path, ownerKey, listed)
  local key = parentKey .. "/rewards"
  local expanded = self:_IsExpanded(key, true)
  self:_Push(rows, {
    key = key,
    kind = "row",
    depth = depth,
    expanded = expanded,
    hasChildren = true,
    loop = false,
    capped = false,
    rewardGroup = true,
    count = #rewards,
    text = string.format(L["Rewards (%d)"], #rewards),
  })
  if not expanded then
    return
  end
  local first = #rows + 1
  self:_AppendGroup(rows, key, rewards, depth + 1, path, ownerKey)
  if not listed then
    return
  end
  for index = first, #rows do
    local row = rows[index]
    if row.depth == depth + 1 and row.kind == "row" then
      row.listedReward = true
    end
  end
end

-- What a row does before the player touches it. Used by opens its first levels, so a crafting
-- chain reads at a glance. Disenchants into opens its category and nothing below it: every
-- result is an enchanting material with dozens of uses, so a shard opened onto its first eight
-- recipes and a "Show 55 more" row, on every material, was noise. The owner's ruling is to wait
-- on the player for those, so the materials start closed. Requires opens its first level and no
-- further: the reagents and tools are the answer, and what those are made of is a question for
-- the row the player clicks. Sources opens nothing below a category: a source list is read
-- across, and one drop opened into its own sources buries the rest. Loot is read the same way,
-- so it opens nothing either: what one of a creature's drops is used for is a question for the
-- row the player clicks. Either way an explicit choice in vm.expanded wins.
--
-- Brief E81: an enchanting recipe starts closed at every depth and in every view. Its row already
-- says what the enchant does, in brackets after its name (UI/Tree.lua Tree.RowText), so the one
-- enchant row under it would only repeat that; the player opens it for the enchant and its
-- reagents. Every other row keeps the rule above. node is optional, and a caller that passes none
-- (the merged row, which is always an item) gets the rule by depth alone.
function VM:_DefaultExpanded(depth, node)
  if ViewModel.MakesEnchant(node) then
    return false
  end
  if self.view == Edges.USES then
    return depth < self.opts.defaultDepth
  end
  if self.view == Edges.REQUIRES or self.view == Edges.DISENCHANTS then
    -- Depth 1 is a category's own rows, which a category that starts open already draws; the
    -- rule is written out so it stays true if a category ever starts closed.
    return depth < 1
  end
  return false
end

-- Whether the root is a piece of equipment: a weapon or a piece of armour, which is the one
-- kind of item a player reads the Sources view of to find out what it is made of. Worked out
-- once per view model, because every row of a category asks.
-- Whether a node is a recipe whose product is an enchant: a spell whose record names one (the
-- recipe's en, which is what Graph emits the ENCHANTS edge from). One record lookup, the one the
-- row's own down edge already paid for. False, never nil, for everything else.
function ViewModel.MakesEnchant(node)
  if type(node) ~= "table" or node.kind ~= "spell" then
    return false
  end
  local id = tonumber(node.id)
  if not id or type(Data) ~= "table" or type(Data.GetRecipe) ~= "function" then
    return false
  end
  local recipe = Data:GetRecipe(id)
  return type(recipe) == "table" and recipe.en ~= nil
end

function VM:_EquipmentRoot()
  if self.equipment == nil then
    local kind, id = Graph.Parse(self.root)
    local item = kind == "item" and Data:GetItem(id) or nil
    self.equipment = item ~= nil and EQUIPMENT_CLASSES[item.c] == true
  end
  return self.equipment
end

-- The one row that opens itself over and above the rule above: in the Sources view of a piece of
-- equipment, the craft that makes it.
--
-- The owner asked for it by name ("always open the spell that creates it", meaning the
-- ingredients). It is the one place in that view where the answer to "where do I get this" is a
-- list rather than a place, and the list is what the player came for. Only at depth 1, only on
-- the craft that produces the root, and only as a default: _IsExpanded reads vm.expanded first,
-- so a player who closes the row keeps it closed. What is under it opens as it always did, which
-- is not at all, so the reagents are one level and no further.
function VM:_OpensCraft(edge, depth)
  if self.view ~= Edges.SOURCES or depth ~= 1 then
    return false
  end
  local def = edge and edge.type or nil
  if not def or def.name ~= "PRODUCED_BY" then
    return false
  end
  return self:_EquipmentRoot()
end

function VM:_IsExpanded(rowKey, default)
  local override = self.expanded[rowKey]
  if override == nil then
    return default
  end
  return override
end

-- A category always starts open, whatever it holds: a closed category hides the one thing the
-- window was opened to answer. A big one draws its first rows and a more row, so opening it
-- costs the same as opening a small one.
function VM:_AppendCategory(rows, category)
  local key = "cat:" .. category.id
  local entries = self:_VisibleEntries(category.entries)
  local count = ViewModel.EntryRows(self:_DropListTwins(entries, 1), self:_ListRowsOf(entries, 1))
  local holds = #entries > 0
  local expanded = self:_IsExpanded(key, true) and holds

  self:_Push(rows, {
    key = key,
    kind = "category",
    depth = 0,
    expanded = expanded,
    hasChildren = holds,
    loop = false,
    capped = false,
    count = category.count ~= nil and count or nil,
    sources = category.count ~= nil and #entries or nil,
    category = category,
    node = {
      key = key,
      kind = "category",
      type = "category",
      name = category.label,
      icon = category.icon,
      badges = category.badges,
    },
  })
  if not expanded then
    return
  end
  -- Brief GS3: a category of guesses alone carries the guess notice as its own, and it is the
  -- view's one guess notice: a second such category draws none.
  if category.guessOnly and category.notice == ViewModel.GUESS_NOTICE then
    if not self.guessNoticeDrawn then
      self.guessNoticeDrawn = true
      self:_Push(rows, { key = key .. "/notice", kind = "notice", depth = 1, text = category.notice, guess = true })
    end
  elseif category.notice then
    self:_Push(rows, {
      key = key .. "/notice",
      kind = "notice",
      depth = 1,
      text = category.notice,
    })
  end
  if self:_Totalling() then
    self.totals[key] = ViewModel.RootTotal(self.root)
  end
  -- Brief CT1: a class trainer's level group is drawn whole (a dozen spells at the most, the druid's
  -- level 20), never cut at the group limit with a "Show 2 more" under one level.
  self:_AppendGroup(rows, key, entries, 1, { [self.root] = true }, self.root, category.classLevel ~= nil)
end

-- The flat row list. Cached until state or options change.
function VM:Rows()
  if self.rows then
    return self.rows
  end
  -- Brief CT1b: a class trainer's Teaches tab another trainer of its class list already drew in this
  -- state. The rows and their index are shared and read only, as the edges under them are.
  local classTab = self:Categories() and self.classTab or nil
  local state = classTab and self:_RowState() or nil
  local kept = state and classTab.rows[state] or nil
  if kept then
    self.rows, self.index, self.totals = kept.rows, kept.index, kept.totals
    self.guessNoticeDrawn = kept.guessNoticeDrawn
    return self.rows
  end
  local rows = {}
  self.index = {}
  -- Brief TC1: what each row passes down to the rows under it, keyed by row key. Built afresh with
  -- the rows, and only ever written while the setting is on.
  self.totals = {}
  self.guessNoticeDrawn = false
  -- Brief Z1: a zone's Here tab carries the Classic Era notice once, above its first group, where
  -- any row it draws came out of the shipped table. Nothing counts it and the search drops it, as
  -- it does every notice row.
  if self.view == Edges.HERE then
    for _, category in ipairs(self:Categories()) do
      if category.anyHistorical and (not self.opts.filter or self.opts.filter == category.id) then
        self:_Push(rows, { key = "herenotice", kind = "notice", depth = 0, text = ViewModel.ERA_NOTICE })
        break
      end
    end
  end
  -- Brief CT1: a class trainer's Teaches tab says it once too, above its first level group.
  if self.view == Edges.TEACHES_VIEW then
    for _, category in ipairs(self:Categories()) do
      if category.classNotice and (not self.opts.filter or self.opts.filter == category.id) then
        self:_Push(rows, { key = "classnotice", kind = "notice", depth = 0, text = category.classNotice })
        break
      end
    end
  end
  for _, category in ipairs(self:Categories()) do
    if not self.opts.filter or self.opts.filter == category.id then
      self:_AppendCategory(rows, category)
    end
  end
  -- Brief E57: the one thing a creature's Loot tab can never list, said once at the foot of it.
  -- A world drop (c = 5 in the contract) names no creature at all, because "somewhere out in the
  -- world" is the whole of what the source knew, so a creature's list is complete and still
  -- cannot hold one. It carries hint = true, so nothing counts it, the search box drops it and
  -- it draws in the muted face: it is a footnote, not a row. Brief OL1: a chest's Loot tab is not
  -- a creature's and says nothing of creatures.
  if self.view == Edges.LOOT and #rows > 0 and Graph.Kind(self.root) ~= "object" then
    self:_Push(rows, {
      key = "worlddrops",
      kind = "hint",
      depth = 0,
      hint = true,
      note = true,
      text = L[WORLD_DROP_NOTE],
    })
  end
  if #rows == 0 then
    local empty = EMPTY_TEXT[self.view] or EMPTY_TEXT[Edges.USES]
    -- Brief C4 addendum: a creature with no Classic Era page says what its own page says.
    if self.view == Edges.LOOT and ViewModel.MetCreature(self.root) then
      empty = EMPTY_TEXT.metCreature
    end
    if self.view == Edges.LOOT and Graph.Kind(self.root) == "object" then
      empty = EMPTY_TEXT.objectLoot
    end
    local text = nil
    -- Brief AA-RB (QA item 219): an item's Used by tab the setting emptied names the player's side.
    if self.view == Edges.USES then
      text = ViewModel.NoUsesText(self.root, self:_HiddenSide())
    end
    -- Brief CH1: and an NPC's Quests tab the setting emptied the same way.
    if self.view == Edges.QUESTS then
      text = self:_NoQuestsText()
    end
    -- Brief TR1: a trainer whose teaching nothing records reads the one muted line (brief TR2: on
    -- its Teaches tab).
    if self.view == Edges.TEACHES_VIEW and ViewModel.IsTrainer(self.root) then
      empty = EMPTY_TEXT.trainsUnknown
      -- Brief fix156: a class trainer's line says what it is, in its own title, and why the tab
      -- holds nothing ("Hunter Trainer: teaches class spells, which ItemTree does not list").
      -- Brief CT1: one whose class spells ship (tc) and are hidden ("Show predicted data" off, every
      -- one of them a Classic Era row) says what it teaches and no more.
      local title = ViewModel.ClassTrainerTitle(self.root)
      if title and (tonumber(eraCall("ClassTeachCount", self.root)) or 0) > 0 then
        text = string.format(L["%s: teaches class spells"], title)
      elseif title then
        text = string.format(L["%s: teaches class spells, which ItemTree does not list"], title)
      end
    end
    self:_Push(rows, {
      key = "empty",
      kind = "empty",
      depth = 0,
      text = text or L[empty],
    })
  end
  self.rows = rows
  -- Brief CT1b: kept for the next trainer of the list, unless it is the empty line, which names this
  -- trainer's own title.
  if state and #self:Categories() > 0 then
    if classTab.states >= CLASS_TAB_STATES then
      classTab.rows, classTab.states = {}, 0
    end
    classTab.rows[state] = {
      rows = rows,
      index = self.index,
      totals = self.totals,
      guessNoticeDrawn = self.guessNoticeDrawn,
    }
    classTab.states = classTab.states + 1
  end
  return rows
end

-- Options that change nothing about how many rows a view has: the filter narrows which
-- category is drawn and the All row counts every one of them either way, a clock is not an
-- option at all, merging a craft into the item it makes draws one row where there were two but
-- leaves every category holding exactly the edges it held.
-- craftIngredients is ignored for the same reason merging is: every mode leaves each category
-- holding exactly the edges it held, and the rows it adds are not rows of the view. Counting
-- them per mode would also split this cache five ways for no answer that ever differs.
-- totalCounts (brief TC1) only changes the number a reagent row writes, never which rows there are.
local COUNT_IGNORED = { filter = true, now = true, mergeCrafts = true, craftIngredients = true, totalCounts = true }

-- The options a count was worked out under, as one string. Defaults are folded in first, so a
-- caller that passes nothing and a caller that passes the defaults get the same answer out of
-- the same cache entry.
local function optionFingerprint(opts)
  local merged = {}
  for key, value in pairs(ViewModel.DEFAULTS) do
    merged[key] = value
  end
  for key, value in pairs(opts or EMPTY) do
    merged[key] = value
  end
  local keys = {}
  for key in pairs(merged) do
    if not COUNT_IGNORED[key] then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys)
  local parts = {}
  for index, key in ipairs(keys) do
    parts[index] = key .. "=" .. tostring(merged[key])
  end
  -- Brief GS3: whether guesses are counted, which the window does not pass and the saved setting
  -- answers, so turning "Show guessed sources" off is never answered from a count made with it on.
  parts[#parts + 1] = "guessSources=" .. tostring(guessSourcesShown(merged))
  -- Brief QS1: the player's side, which the Used by count leaves the other side's quests out by
  -- (the pretend side can change it within a session). Brief F155: the side "Hide other faction
  -- data" hides from, nil while it is off, which every count of the other side's rows follows.
  parts[#parts + 1] = "side=" .. tostring(ViewModel.HiddenSide(merged))
  return table.concat(parts, ";")
end

-- What the counts were worked out against: the data build in hand and everything the collector
-- has recorded. Both are read through ItemTree rather than held as upvalues, because the
-- collector loads after this file and the harness swaps the data module out underneath it.
local function generations()
  local data = ItemTree.Data
  local collector = ItemTree.Collector
  return tonumber(data and data.generation) or 0, tonumber(collector and collector.generation) or 0
end

-- One root is asked about again and again while the player pages through a chain, and only a
-- handful of roots are ever live at once, so the cache is emptied rather than aged.
local COUNT_CACHE_LIMIT = 64

-- Brief CT1b (QA item 227): a root's counts are kept per option set, at most this many sets a root.
-- The window's tab strip (its own options) and the info column's "Sells" line (showPredicted alone)
-- ask about the same root under two sets, and one entry a root had each throw the other's away: the
-- owner's run on three trainer pages counted their tabs 33 times, every refresh of the page twice.
local COUNT_SETS_LIMIT = 4

-- The counts kept for one root under one option set, or nil.
local function countsHeld(rootKey, fingerprint)
  local sets = countCache[rootKey]
  return sets and sets[fingerprint] or nil
end

-- The number the sidebar's All row shows for each view: "Used by (3)", "Sources (6)",
-- "Requires (4)" and "Disenchants into (2)". Same rules as the sidebar, so showPredicted and
-- the rest of the options are respected, the requirement rows count towards Requires, and the
-- predicted disenchant results count towards Disenchants into and no longer towards Used by.
--
-- Answered from a cache keyed by the root and the options, dropped when the data is reset or
-- the collector records anything, so the tab labels do not cost one full view model per tab on
-- every refresh. The table returned is the caller's own and may be kept or changed.
-- The views one root is drawn in, which is the list the window's tab strip is built from.
--
-- This is the seam for "the views a root kind has" (brief E57). Core/Edges.lua owns the two lists
-- and which kind takes which (Edges.ViewsFor); this is where the DATA gets a say, because an npc
-- key is a creature or a vendor and only the shipped Classic Era table can tell them apart. A name
-- the table states a kind for is a creature and takes the Loot and Map tabs; everything else,
-- including a vendor and the world drop node, keeps the four item tabs it has always had.
--
-- The question is answered with two table lookups and a little arithmetic
-- (Core/EraSources.lua E:CreatureKind): nothing is decoded and the creature loot index is not
-- built, so asking it on every open of every node costs nothing. The MAP view has no rows at all,
-- so it is never counted below and the tab draws its plain word.
--
-- Brief N2 widened it to every NPC. An npc root takes the views its data can fill, out of
-- Edges.NPC_VIEWS and in that order: Loot where the shipped table calls the name a creature or the
-- player has looted the NPC, Sells where the table calls it a vendor or the player has bought from
-- it, and Map where it is a creature (the only names the table places on a map). A creature that
-- sells nothing keeps Edges.CREATURE_VIEWS itself, a vendor that is no creature has
-- Edges.VENDOR_VIEWS, and a name nobody knows keeps the four item tabs.
--
-- Every question is a lookup: the kind is ck, the vendor index and the collector's by-NPC index are
-- built once and kept, and a positive id's name is matched against a map of the string table made
-- once (Core/EraSources.lua E:NpcNameAt). Nothing is decoded per open.
--
-- Brief N3 added Quests, where the table lists a quest the name starts or ends (two string lengths,
-- nothing decoded), and gave a vendor the Map tab where the table places its name on a map. A
-- vendor only name has a kind in ck now, but no loot rows, so it still takes no Loot tab.
--
-- Brief P6b added Teaches, first, where the table's tr list names the trainer (a string length,
-- nothing decoded). A trainer takes the Loot tab only where the loot index holds something for it,
-- so a trainer's page opens on what it teaches rather than on an empty list.
local NPC_VIEW_SETS = {}

-- Brief TR2 (owner QA 2026-10-11 item 128): no Trains tab. A trainer's teaching is its Teaches tab,
-- which leads the set as Edges.NPC_VIEWS orders it.
local function npcViews(loot, sells, quests, map, teaches)
  if not teaches then
    if loot and not sells and not quests and map then
      return Edges.CREATURE_VIEWS
    end
    if sells and not loot and not quests and not map then
      return Edges.VENDOR_VIEWS
    end
  elseif loot and sells and quests and map then
    return Edges.NPC_VIEWS
  end
  local slot = (teaches and "t" or "")
    .. (loot and "l" or "")
    .. (sells and "s" or "")
    .. (quests and "q" or "")
    .. (map and "m" or "")
  local held = NPC_VIEW_SETS[slot]
  if not held then
    local wanted = {
      [Edges.TEACHES_VIEW] = teaches,
      [Edges.LOOT] = loot,
      [Edges.SELLS] = sells,
      [Edges.QUESTS] = quests,
      [Edges.MAP] = map,
    }
    held = {}
    for _, view in ipairs(Edges.NPC_VIEWS) do
      if wanted[view] then
        held[#held + 1] = view
      end
    end
    NPC_VIEW_SETS[slot] = held
  end
  return held
end

-- One method of a module's instance, pcall'd, answering its first result or nil.
local function ask(module, method, ...)
  if type(module) ~= "table" or type(module[method]) ~= "function" then
    return nil
  end
  local ok, answer = pcall(module[method], module, ...)
  if not ok then
    return nil
  end
  return answer
end

-- Brief GF5: one call into Core/QuestsPredicted.lua, guarded: no module, no function or a raise
-- reads as nil.
local function predictedCall(name, ...)
  local module = ItemTree.QuestsPredicted
  if type(module) ~= "table" or type(module[name]) ~= "function" then
    return nil
  end
  local ok, answer = pcall(module[name], ...)
  if ok then
    return answer
  end
  return nil
end

-- Brief V1: what the client's own vendor tables say about an npc key (Core/ForeverVendors.lua
-- Facts), or nil for a key they list no vendor under.
local function clientVendorFacts(rootKey)
  local module = ItemTree.ForeverVendors
  if type(module) ~= "table" or type(module.Facts) ~= "function" then
    return nil
  end
  local ok, facts = pcall(module.Facts, rootKey)
  if ok and type(facts) == "table" then
    return facts
  end
  return nil
end

-- Brief PS1: what the shipped player sourced rows say about an npc key (Core/PlayerSources.lua
-- NpcFacts), or nil for a key they state nothing about.
local function playerNpcFacts(rootKey)
  local module = ItemTree.PlayerSources
  if type(module) ~= "table" or type(module.NpcFacts) ~= "function" then
    return nil
  end
  local ok, facts = pcall(module.NpcFacts, rootKey)
  if ok and type(facts) == "table" then
    return facts
  end
  return nil
end

-- Brief PS5: how many quests the player module says an npc starts and ends, out of its NpcFacts.
local function playerQuestTotal(reported)
  if type(reported) ~= "table" then
    return 0
  end
  return (tonumber(reported.starts) or 0) + (tonumber(reported.ends) or 0)
end

-- The client's pin for those facts, as a list (Core/ForeverVendors.lua Positions), empty for none.
local function clientPositions(facts)
  local module = ItemTree.ForeverVendors
  if type(module) ~= "table" or type(module.Positions) ~= "function" then
    return EMPTY
  end
  local ok, positions = pcall(module.Positions, facts)
  if ok and type(positions) == "table" then
    return positions
  end
  return EMPTY
end

-- The name index and the role ("creature", "vendor" or "both") the shipped table gives an npc key
-- (Core/EraSources.lua E:CreatureKind, brief N3), or nil for a key it gives no kind.
local function npcKind(era, rootKey)
  if type(era) ~= "table" or type(era.CreatureKind) ~= "function" then
    return nil
  end
  local ok, nameIndex, _, _, _, _, role = pcall(era.CreatureKind, era, rootKey)
  if not ok or type(nameIndex) ~= "number" then
    return nil
  end
  return nameIndex, role
end

-- How many quests the name behind an npc key starts and ends together, out of the two lists'
-- lengths (Core/EraSources.lua E:QuestGiverCounts). Nothing is decoded. 0 for anything else.
local function questTotal(era, rootKey)
  if type(era) ~= "table" or type(era.QuestGiverCounts) ~= "function" then
    return 0
  end
  local ok, starts, ends = pcall(era.QuestGiverCounts, era, rootKey)
  if not ok then
    return 0
  end
  return (tonumber(starts) or 0) + (tonumber(ends) or 0)
end

--- Brief CH1 (with item 270's note): how many quests the Classic Era table says an npc key starts
--- and ends, the rows its Quests tab keeps: with no side, the two list lengths and nothing decoded
--- (brief N3); with side ("Alliance" or "Horde", the side "Hide other faction data" hides from), the
--- npc's two lists decoded (a few dozen ids at most) less every quest of the other side alone
--- (Graph.HidesEdge, the rule the tab's rows follow). 0, 0 for anything else. Guarded.
function ViewModel.EraQuestCounts(rootKey, side)
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.QuestGiverCounts) ~= "function" then
    return 0, 0
  end
  local ok, starts, ends = pcall(era.QuestGiverCounts, era, rootKey)
  if not ok then
    return 0, 0
  end
  starts, ends = tonumber(starts) or 0, tonumber(ends) or 0
  if Graph.SIDE_NUMBERS[side] == nil or starts + ends == 0 then
    return starts, ends
  end
  local okGiven, given
  if Graph.Kind(rootKey) == "object" then
    -- Brief EO1: a world object's lists (og), which E:QuestsGivenBy reads for an object key.
    if type(era.QuestsGivenBy) ~= "function" then
      return starts, ends
    end
    okGiven, given = pcall(era.QuestsGivenBy, era, rootKey)
  else
    if type(era.NpcNameAt) ~= "function" or type(era.QuestsGiven) ~= "function" then
      return starts, ends
    end
    local okName, nameIndex = pcall(era.NpcNameAt, era, rootKey)
    if not okName or type(nameIndex) ~= "number" then
      return starts, ends
    end
    okGiven, given = pcall(era.QuestsGiven, era, nameIndex)
  end
  if not okGiven or type(given) ~= "table" then
    return starts, ends
  end
  local counted = {}
  for _, part in ipairs({ { "starts", "GIVES_QUEST" }, { "ends", "TAKES_QUEST" } }) do
    local count, edge = 0, { type = Edges.Types[part[2]] }
    for _, questId in ipairs(given[part[1]] or EMPTY) do
      edge.target = Graph.Key("quest", questId)
      if not Graph.HidesEdge(edge, side) then
        count = count + 1
      end
    end
    counted[#counted + 1] = count
  end
  return counted[1], counted[2]
end

--------------------------------------------------------------------------------
-- What a trainer teaches (briefs NP1, TR1 and TR2)
--------------------------------------------------------------------------------

-- The owner's words (2026-10-04): "we also need to add in the 'trains' tab for trainers", and
-- (2026-10-11, QA item 128) "Train tab is redundant when we have a teaches tab. Fold train into
-- teaches". So a trainer's page has no Trains tab: what it trains is its Teaches tab. The professions
-- an NPC trains come out of three places: what the client said at the trainer's window (the places
-- store's trainer record, Core/Places.lua "k"), what the shipped player module states
-- (Core/PlayerSources.lua NpcFacts trains), the Creatures data's trainer fields, and the Classic Era
-- trainer table the Professions tab's trainer panel reads (EraSources tr, each spell filed under its
-- line). The Classic Era rank spells are rows of their own ("Apprentice Mining" to "Artisan
-- Mining"); a profession no row can rank gets one line, "Teaches Mining up to Artisan"
-- (VM:_TeachesLines), which opens the Professions tab on that line where the Professions module is
-- loaded and on; otherwise it is plain words.
-- Brief TR1: the muted line of a trainer whose teaching nothing records.
ViewModel.TRAINS_UNKNOWN = L["Trainer (what they teach is not recorded yet)"]

-- The rank spells of each profession line, Apprentice, Journeyman, Expert and Artisan, which a
-- trainer teaches whatever recipes it has: a fishing trainer teaches nothing else. The last three
-- are ItemTree_Professions/UI/Trainers.lua Trainers.RANKS (see its header for where each id comes
-- from); the Apprentice spells are the original game's own (Fishing 7620, Cooking 2550 and the
-- rest), which the shipped trainer table lists under every trainer of the line.
ViewModel.TRAINS_RANK_SPELLS = {
  [129] = { 3273, 3274, 7924, 10846 }, -- First Aid
  [164] = { 2018, 3100, 3538, 9785 }, -- Blacksmithing
  [165] = { 2108, 3104, 3811, 10662 }, -- Leatherworking
  [171] = { 2259, 3101, 3464, 11611 }, -- Alchemy
  [182] = { 2366, 2368, 3570, 11993 }, -- Herbalism
  [185] = { 2550, 3102, 3413, 18260 }, -- Cooking
  [186] = { 2575, 2576, 3564, 10248 }, -- Mining
  [197] = { 3908, 3909, 3910, 12180 }, -- Tailoring
  [202] = { 4036, 4037, 4038, 12656 }, -- Engineering
  [333] = { 7411, 7412, 7413, 13920 }, -- Enchanting
  [356] = { 7620, 7731, 7732, 18248 }, -- Fishing
  [393] = { 8613, 8617, 8618, 10768 }, -- Skinning
}

-- Spell to line, out of the table above, made on first use, and (brief TR1) spell to its step, 1
-- Apprentice to 4 Artisan, its place in the line's list.
local trainsRankLine = nil
local trainsRankStep = nil

local function rankTables()
  if not trainsRankLine then
    trainsRankLine, trainsRankStep = {}, {}
    for line, spells in pairs(ViewModel.TRAINS_RANK_SPELLS) do
      for step, spell in ipairs(spells) do
        trainsRankLine[spell] = line
        trainsRankStep[spell] = step
      end
    end
  end
  return trainsRankLine, trainsRankStep
end

-- Brief TR2: the profession line and step (1 Apprentice to 4 Artisan) of a rank spell, or nil for
-- any other spell. Our own table above, so nothing asks the client. Pure.
function ViewModel.RankSpell(spellId)
  local lines, steps = rankTables()
  local line = lines[tonumber(spellId) or false]
  if not line then
    return nil
  end
  return line, steps[tonumber(spellId)]
end

-- The Classic Era answer per trainer name index, kept for the session: the table is static, and a
-- trainer's list is decoded once however often its page or its tab strip asks. Dropped by
-- ViewModel.ResetTrains (and ViewModel.Reset).
ViewModel.trainsByName = {}
-- Brief TR1: the top rank per line of the same trainers, { [nameIndex] = { [line] = step } }, made
-- beside trainsByName.
ViewModel.trainsRankByName = {}

-- The seam the window fills (UI/Frame.lua): a function answering whether a Trains row may open the
-- Professions tab, which is when that module is loaded and its setting is on. nil in a load with no
-- UI, which leaves every row plain words.
ViewModel.professionsLinked = nil

function ViewModel.ResetTrains()
  ViewModel.trainsByName = {}
  ViewModel.trainsRankByName = {}
  trainsRankLine, trainsRankStep = nil, nil
end

-- The profession line a name the client or a record gives stands for ("Leatherworking", in any
-- case, or "Journeyman Leatherworking"), out of the build's own skill names for the lines
-- ViewModel.SKILL_ICONS draws. nil for a class line ("Arms") or anything else. Pure over the data.
function ViewModel.ProfessionLineOf(label)
  if type(label) ~= "string" or label == "" then
    return nil
  end
  local wanted = label:lower()
  for line in pairs(ViewModel.SKILL_ICONS) do
    local ok, name = pcall(Data.GetSkillName, Data, line)
    if ok and type(name) == "string" and name ~= "" then
      local lower = name:lower()
      if wanted == lower or wanted:sub(-(#lower + 1)) == " " .. lower then
        return line
      end
    end
  end
  return nil
end

-- The profession lines the Classic Era trainer at one name index teaches, ascending, each once:
-- its rank spells by ViewModel.TRAINS_RANK_SPELLS and its recipes by the build's own recipe line.
local function eraTrainsLines(era, nameIndex)
  local held = ViewModel.trainsByName[nameIndex]
  if held then
    return held
  end
  rankTables()
  local lines, seen, ranks = {}, {}, {}
  local ok, spells = pcall(era.Teaches, era, nameIndex)
  for _, spell in ipairs(ok and type(spells) == "table" and spells or EMPTY) do
    local line = trainsRankLine[spell]
    -- Brief TR1: the highest rank spell of a line it teaches is the top rank it trains to.
    local step = line and trainsRankStep[spell] or nil
    if step and (ranks[line] or 0) < step then
      ranks[line] = step
    end
    if not line and type(Data.GetRecipe) == "function" then
      local asked, recipe = pcall(Data.GetRecipe, Data, spell)
      line = asked and type(recipe) == "table" and tonumber(recipe.sl) or nil
    end
    if line and ViewModel.SKILL_ICONS[line] and not seen[line] then
      seen[line] = true
      lines[#lines + 1] = line
    end
  end
  table.sort(lines)
  ViewModel.trainsByName[nameIndex] = lines
  ViewModel.trainsRankByName[nameIndex] = ranks
  return lines
end

-- The places store's trainer record for a creature id (ItemTreeDB.places.t[id]), or nil.
local function placesTrainer(creatureId)
  local db = ItemTree.db
  local places = type(db) == "table" and type(db.places) == "table" and db.places or nil
  local Places = ItemTree.Places
  local kind = type(Places) == "table" and Places.TRAINER or "t"
  local byId = places and type(places[kind]) == "table" and places[kind] or nil
  local entry = byId and byId[creatureId] or nil
  return type(entry) == "table" and entry or nil
end

local trainsCreatureRow

-- The real creature id behind an npc key: its own (npc:<id>), else the unit the page was last
-- opened from (Core/CreatureLookup.lua Origin). nil for neither.
local function trainsCreatureId(rootKey)
  local _, id = Graph.Parse(rootKey)
  if type(id) == "number" and id > 0 then
    return id
  end
  local lookup = ItemTree.CreatureLookup
  if type(lookup) == "table" and type(lookup.Origin) == "function" then
    local ok, origin = pcall(lookup.Origin, rootKey)
    if ok and type(origin) == "table" and tonumber(origin.npcId) then
      return tonumber(origin.npcId)
    end
  end
  return nil
end

-- Brief BQ25b (owner QA 2026-10-10 item 54): the Classic Era table's display id for an npc key, or
-- nil: the table's name for the key (E:NpcNameAt, the same creature id, or for a creature the
-- client named its name, which is how the merge pairs a recorded row with its Classic Era twin) and
-- that name's display (E:DisplayOf). Only out of a table already built: a row never loads the
-- module for a portrait.
function ViewModel.EraPortrait(key)
  local era = ItemTree.eraSources
  if type(key) ~= "string" or type(era) ~= "table" or ask(era, "_BuiltTable") == nil then
    return nil
  end
  local nameIndex = ask(era, "NpcNameAt", key)
  if type(nameIndex) ~= "number" then
    return nil
  end
  return ViewModel.CreaturePortrait({ display = ask(era, "DisplayOf", nameIndex) })
end

-- Brief NP2b (owner QA 2026-10-10 item 81, "Make portraits work for Forever creatures"): whether the
-- Creatures data can be read without the client loading anything: a stated table (a spec), a table
-- already built, or ItemTree_Data's loader for it registered (the addon is loaded, so building the
-- table is one table constructor and no client call).
local function creaturesAtHand(creatures)
  if type(creatures.Loaded) == "function" then
    local ok, held = pcall(creatures.Loaded)
    if ok and type(held) == "table" then
      return true
    end
  end
  local modules = type(Data) == "table" and Data.modules or nil
  return type(modules) == "table" and type(modules[creatures.MODULE]) == "function"
end

-- Brief NP2b: the display id a Forever creature's row portrait is drawn from, or nil: the Creatures
-- data's first for the creature id an npc key names (the row's d, which the pipeline reads from
-- the client's creature cache and its cache bank). The fallback after EraPortrait for a creature
-- the Classic Era table does not know (Al'Aketh Spiritcaller 252763). Never makes the client load
-- ItemTree_Data for a portrait (creaturesAtHand); a row with nothing here keeps its kind icon.
function ViewModel.ForeverPortrait(key)
  if type(key) ~= "string" or Graph.Kind(key) ~= "npc" then
    return nil
  end
  local _, id = Graph.Parse(key)
  local creatures = ItemTree.Creatures
  if type(id) ~= "number" or type(creatures) ~= "table" or type(creatures.Display) ~= "function" then
    return ViewModel.SeenDisplay(id)
  end
  if not creaturesAtHand(creatures) then
    return ViewModel.SeenDisplay(id)
  end
  local ok, display = pcall(creatures.Display, id)
  if not ok then
    return ViewModel.SeenDisplay(id)
  end
  return ViewModel.CreaturePortrait({ display = display }) or ViewModel.SeenDisplay(id)
end

-- Brief QI1 (owner QA 2026-10-17, feedback item 182: Owen Thadd 211022, whom neither the Classic Era
-- table nor the Creatures data knows, wore the generic NPC icon on the quest page's "Turned in to"
-- row): the display id the client drew the creature's own page model with this session
-- (Core/CreatureLookup.lua SeenDisplay, kept by UI/InfoPanel.lua ApplyLiveModel), or nil. The last
-- answer after the shipped data's, so a row and the window's portrait draw the creature once its page
-- has shown it. A table read; asks the client nothing.
function ViewModel.SeenDisplay(creatureId)
  local lookup = ItemTree.CreatureLookup
  if type(creatureId) ~= "number" or type(lookup) ~= "table" or type(lookup.SeenDisplay) ~= "function" then
    return nil
  end
  local ok, display = pcall(lookup.SeenDisplay, creatureId)
  if not ok then
    return nil
  end
  return ViewModel.CreaturePortrait({ display = display })
end

-- Brief NP2: the CreatureDisplayInfo id a creature or NPC page's portrait is drawn from, or nil: the
-- shipped Classic Era table's for the name (E:DisplayOf), else the Creatures data's first for the
-- real creature id behind the key (Core/Creatures.lua Get, which a creature page builds anyway).
-- A whole number above nought, or nil.
function ViewModel.CreatureDisplay(rootKey)
  if Graph.Kind(rootKey) ~= "npc" then
    return nil
  end
  local era = ItemTree.eraSources
  local nameIndex = ask(era, "NpcNameAt", rootKey)
  if type(nameIndex) == "number" then
    local display = ViewModel.CreaturePortrait({ display = ask(era, "DisplayOf", nameIndex) })
    if display then
      return display
    end
  end
  local creatureId = trainsCreatureId(rootKey)
  local creatures = ItemTree.Creatures
  if creatureId and type(creatures) == "table" and type(creatures.Get) == "function" then
    local ok, row = pcall(creatures.Get, creatureId)
    local displays = ok and type(row) == "table" and type(row.displays) == "table" and row.displays or EMPTY
    local display = ViewModel.CreaturePortrait({ display = tonumber(displays[1]) })
    if display then
      return display
    end
  end
  -- Brief QI1: else the display id the page's own model was drawn with this session.
  return ViewModel.SeenDisplay(creatureId)
end

-- Brief TR1: the Creatures data's row for a creature id (Core/Creatures.lua Get, the trainer fields
-- among it), or nil. A page is one of the needs that may build the module.
function trainsCreatureRow(creatureId)
  local creatures = ItemTree.Creatures
  if not creatureId or type(creatures) ~= "table" or type(creatures.Get) ~= "function" then
    return nil
  end
  local ok, row = pcall(creatures.Get, creatureId)
  return ok and type(row) == "table" and row or nil
end

-- Brief TR1: the words a top rank reads as, 1 Apprentice to 5 Master (the Creatures data's tk, or a
-- Classic Era trainer's highest rank spell's step).
ViewModel.TRAINS_RANK_NAMES = { L["Apprentice"], L["Journeyman"], L["Expert"], L["Artisan"], L["Master"] }

-- A title's leading rank word as a top rank, the pipeline's rule (ItemTree-Data trainers.py):
-- "Junior" 1, "Journeyman" 2, "Expert" 3, "Artisan" 4, "Master" 5; "Apprentice" is not one.
ViewModel.TITLE_RANKS = { junior = 1, journeyman = 2, expert = 3, artisan = 4, master = 5 }

-- The top rank a title's first word names, or nil. Pure.
function ViewModel.TitleRank(title)
  if type(title) ~= "string" then
    return nil
  end
  local first = title:lower():match("^%s*(%a+)")
  return first and ViewModel.TITLE_RANKS[first] or nil
end

-- The profession lines a title says it trains (Core/TrainerSearch.lua TitleKinds, a rank word read
-- as a Forever trainer's), ascending; trains is true where a record already says it trains. Empty
-- where TrainerSearch is not loaded. Pure over it.
function ViewModel.TitleTrainsLines(title, trains)
  local out = {}
  local search = ItemTree.TrainerSearch
  if type(search) ~= "table" or type(search.TitleKinds) ~= "function" then
    return out
  end
  local ok, kinds = pcall(search.TitleKinds, title, trains == true, true)
  for id in pairs(ok and type(kinds) == "table" and kinds or EMPTY) do
    local kind = type(search.BY_ID) == "table" and search.BY_ID[id] or nil
    if kind and kind.line and ViewModel.SKILL_ICONS[kind.line] then
      out[#out + 1] = kind.line
    end
  end
  table.sort(out)
  return out
end

-- Brief fix156: the title the Classic Era table gives the name an npc key joins (st: E:CreatureAt,
-- the join E:CreatureKind reads ViewsFor's name through, then E:Title: "Hunter Trainer" for
-- Kaerbrus), or nil. Table reads; nothing is decoded.
local function eraTrainerTitle(rootKey)
  local era = ItemTree.eraSources
  local nameIndex = ask(era, "CreatureAt", rootKey)
  if type(nameIndex) ~= "number" then
    return nil
  end
  local title = ask(era, "Title", nameIndex)
  if type(title) == "string" and title ~= "" then
    return title
  end
  return nil
end

-- Brief fix156: the trainer kinds a title names, read the way the trainer search reads it
-- (Core/TrainerSearch.lua TitleKinds; rank is its third argument), as a set. Empty where the
-- search is not loaded or the title says nothing of training.
local function trainerTitleKinds(title, rank)
  local search = ItemTree.TrainerSearch
  if type(title) ~= "string" or type(search) ~= "table" or type(search.TitleKinds) ~= "function" then
    return EMPTY
  end
  local ok, kinds = pcall(search.TitleKinds, title, false, rank)
  if ok and type(kinds) == "table" then
    return kinds
  end
  return EMPTY
end

-- Brief TR1: whether an npc key is a trainer the Trains tab is offered for: one it names a
-- profession for (ViewModel.TrainerProfessions), or one our sources call a trainer without saying
-- what it teaches (a trainer visit, the player module's trainer role, a Creatures title that says
-- it trains: "Pet Trainer", "Hunter Trainer"), whose tab is then the one muted line. An owner
-- negative is never one. Pure over the loaded data.
-- Brief fix156 (owner QA 2026-10-14 item 156): and a Classic Era name whose own title says it
-- trains (st), read as the trainer search reads one, so every page the search lists is a trainer's.
-- The class trainers above all: the table's tr leaves their spells out, so nothing else names them.
function ViewModel.IsTrainer(rootKey)
  if Graph.Kind(rootKey) ~= "npc" then
    return false
  end
  if #ViewModel.TrainerProfessions(rootKey) > 0 then
    return true
  end
  local creatureId = trainsCreatureId(rootKey)
  local creature = trainsCreatureRow(creatureId)
  if creature and creature.neverTrainer then
    return false
  end
  if creatureId and placesTrainer(creatureId) then
    return true
  end
  local reported = playerNpcFacts(rootKey)
  for _, role in ipairs(type(reported) == "table" and type(reported.roles) == "table" and reported.roles or EMPTY) do
    if role == "trainer" then
      return true
    end
  end
  if creature and next(trainerTitleKinds(creature.title, true)) ~= nil then
    return true
  end
  -- Brief fix156: with no rank reading, as TrainerSearch.Build lists a Classic Era title: an Era
  -- "Apprentice Weaponsmith" who teaches nothing is a vendor.
  return next(trainerTitleKinds(eraTrainerTitle(rootKey))) ~= nil
end

-- Brief fix156: the title of a CLASS trainer (a kind TrainerSearch.KINDS gives class lines:
-- "Hunter Trainer", "Demon Trainer", "Portal Trainer"), the Creatures data's first, then the
-- Classic Era table's, or nil for any other npc key, an owner negative included. Its Teaches tab
-- says what it is (VM:Rows), since ItemTree ships no class spells. Pure over the loaded data.
function ViewModel.ClassTrainerTitle(rootKey)
  if Graph.Kind(rootKey) ~= "npc" then
    return nil
  end
  local creature = trainsCreatureRow(trainsCreatureId(rootKey))
  if creature and creature.neverTrainer then
    return nil
  end
  local search = ItemTree.TrainerSearch
  local byId = type(search) == "table" and type(search.BY_ID) == "table" and search.BY_ID or EMPTY
  local function classTitle(title)
    for id in pairs(trainerTitleKinds(title)) do
      local kind = byId[id]
      if type(kind) == "table" and type(kind.lines) == "table" then
        return title
      end
    end
    return nil
  end
  return classTitle(creature and creature.title or nil) or classTitle(eraTrainerTitle(rootKey))
end

-- Brief TW3 (the owner's ruling "A" of 2026-10-18, pet trainers): the title of a PET trainer
-- ("Pet Trainer", the kind TrainerSearch.KINDS gives "pet"), the Creatures data's first, then the
-- Classic Era table's, or nil for any other npc key, an owner negative included. Its Teaches tab
-- lists the pet trainers' recorded list (Core/EraSources.lua E:IsPetTrainerPage). Pure over the
-- loaded data.
function ViewModel.PetTrainerTitle(rootKey)
  if Graph.Kind(rootKey) ~= "npc" then
    return nil
  end
  local creature = trainsCreatureRow(trainsCreatureId(rootKey))
  if creature and creature.neverTrainer then
    return nil
  end
  local function petTitle(title)
    if trainerTitleKinds(title).pet then
      return title
    end
    return nil
  end
  return petTitle(creature and creature.title or nil) or petTitle(eraTrainerTitle(rootKey))
end

-- Brief TR1: the words one Teaches line reads (brief TR2): "Teaches Mining up to Artisan" where its
-- top rank is known, else "Teaches Mining". Built per creature from its own profession and rank,
-- through the locale's templates. Pure.
function ViewModel.TrainsLabel(profession)
  if type(profession) ~= "table" or type(profession.name) ~= "string" then
    return nil
  end
  local rankName = ViewModel.TRAINS_RANK_NAMES[tonumber(profession.rank) or 0]
  if rankName then
    return string.format(L["Teaches %s up to %s"], profession.name, rankName)
  end
  return string.format(L["Teaches %s"], profession.name)
end

-- Brief TR2: the words a rank spell's row reads, its rank word then its profession ("Apprentice
-- Mining", "Artisan Mining"), out of our own rank table and the build's skill name; nil for a spell
-- that is no rank spell. Pure over the data.
function ViewModel.RankSpellLabel(spellId)
  local line, step = ViewModel.RankSpell(spellId)
  local rankName = line and ViewModel.TRAINS_RANK_NAMES[step] or nil
  if not rankName then
    return nil
  end
  local ok, name = pcall(Data.GetSkillName, Data, line)
  if not (ok and type(name) == "string" and name ~= "") then
    return nil
  end
  return string.format(L["%s %s"], rankName, name)
end

-- Brief TR2: the sort words of a rank spell's row, so a profession's four read in rank order under
-- a list sorted by name. Pure over the data.
function ViewModel.RankSortName(line, step)
  local ok, name = pcall(Data.GetSkillName, Data, line)
  if not (ok and type(name) == "string") then
    name = tostring(line)
  end
  return string.format("%s %d", name, tonumber(step) or 0)
end

-- Brief TR2: names a rank spell's node where nothing else does (Graph.RegisterNamer's last resort:
-- a load with no client spell names, the specs), so its row is drawn rather than dropped. The client
-- names these spells "Mining" itself; VM:_DecorateNode relabels the row either way.
local function rankSpellNamer(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "spell" then
    return nil
  end
  return ViewModel.RankSpellLabel(id)
end

-- Registers the namer above once, on the first Teaches tab built. Answers nothing.
function ViewModel.EnsureRankNamer()
  if type(Graph.HasNamer) == "function" and not Graph.HasNamer(rankSpellNamer) then
    Graph.RegisterNamer(rankSpellNamer)
  end
end

-- What a trainer trains, for its Trains tab: { { line, name, from }, ... } by name, each line once,
-- from "seen" (the places store, the client's own words at the window), "players" (the player
-- module) or "era" (the Classic Era trainer table), the first that names it. Empty for an npc key
-- nothing names a profession for, a class trainer included, and for anything that is not one.
function ViewModel.TrainerProfessions(rootKey)
  local out = {}
  if Graph.Kind(rootKey) ~= "npc" then
    return out
  end
  local creatureId = trainsCreatureId(rootKey)
  local creature = trainsCreatureRow(creatureId)
  -- Brief TR1: an owner negative trains nothing, whatever a record or a title says.
  if creature and creature.neverTrainer then
    return out
  end
  local seen = {}
  local function add(line, from, rank)
    if not line then
      return
    end
    local held = seen[line]
    if held then
      held.rank = held.rank or rank
      return
    end
    local ok, name = pcall(Data.GetSkillName, Data, line)
    if not (ok and type(name) == "string" and name ~= "") then
      name = tostring(line)
    end
    held = { line = line, name = name, from = from, rank = rank }
    seen[line] = held
    out[#out + 1] = held
  end
  local record = creatureId and placesTrainer(creatureId) or nil
  if record then
    add(ViewModel.ProfessionLineOf(record.k), "seen")
  end
  local reported = playerNpcFacts(rootKey)
  if reported then
    add(ViewModel.ProfessionLineOf(reported.trains), "players")
  end
  -- Brief TR1: the Creatures data's trainer fields (the pipeline's tp and tk, from a title, a
  -- corroborated noun or an owner claim), else a title that says it trains by itself.
  if creature then
    local line = creature.trainsLine
    if line and ViewModel.SKILL_ICONS[line] then
      add(line, "data", creature.trainsRank)
    elseif type(creature.title) == "string" then
      for _, kindLine in ipairs(ViewModel.TitleTrainsLines(creature.title, record ~= nil or reported ~= nil)) do
        add(kindLine, "data", ViewModel.TitleRank(creature.title))
      end
    end
  end
  local era = ItemTree.eraSources
  if (tonumber(ask(era, "TeachCount", rootKey)) or 0) > 0 then
    local nameIndex = ask(era, "NpcNameAt", rootKey)
    if type(nameIndex) == "number" and type(era.Teaches) == "function" then
      local lines = eraTrainsLines(era, nameIndex)
      local ranks = ViewModel.trainsRankByName[nameIndex] or EMPTY
      for _, line in ipairs(lines) do
        add(line, "era", ranks[line])
      end
    end
  end
  table.sort(out, function(a, b)
    if a.name ~= b.name then
      return a.name < b.name
    end
    return a.line < b.line
  end)
  return out
end

-- Whether a Trains row opens the Professions tab: the window's seam, asked once per tab draw.
function ViewModel.TrainsLinked()
  local linked = ViewModel.professionsLinked
  if type(linked) ~= "function" then
    return false
  end
  local ok, answer = pcall(linked)
  return ok and answer == true
end

-- The page key a Trains row opens: "profession:<line>", which UI/Frame.lua Frame.Open turns into
-- the Professions tab on that line and never into a root.
function ViewModel.ProfessionKey(line)
  return Graph.Key("profession", line)
end

-- Brief C2: the Chain tab, first of an item's view tabs and of a recipe's. It was a window tab of
-- its own until the owner asked for it beside Used by and Sources (2026-09-28), because it is one
-- more question about the root the window is on. The view key is this file's own, like the Quest
-- tab's: Core/Edges.lua gives it no direction, it holds no categories and it is never counted, and
-- UI/Frame.lua draws UI/Chain.lua's pane in the space the two lists take while it is up.
ViewModel.CHAIN_VIEW = "chain"

-- The node kinds a chain is drawn for: an item and a recipe (a spell key), which are the two kinds
-- Core/Chain.lua walks through. A creature, a vendor, a zone, a node, a quest and the rest keep the
-- tabs they had, because a chain rooted on one of them is a single stage with nothing either side.
ViewModel.CHAIN_KINDS = { item = true, spell = true }

-- The views an item or a recipe root is drawn in: Chain, then Edges.VIEWS in their order. One
-- table per Edges.VIEWS table, made once, so the window's per set memory keys it the same way on
-- every ask and a Core whose Edges states fewer views still has the chain in front of them.
local chainRootViews = {}

local function chainViewsOf(views)
  local held = chainRootViews[views]
  if not held then
    held = { ViewModel.CHAIN_VIEW }
    for _, view in ipairs(views) do
      held[#held + 1] = view
    end
    chainRootViews[views] = held
  end
  return held
end

ViewModel.CHAIN_ROOT_VIEWS = chainViewsOf(Edges.VIEWS)
-- Brief OL1: an openable item's tabs, the chain and Edges.CONTAINER_VIEWS.
ViewModel.CONTAINER_ROOT_VIEWS = chainViewsOf(Edges.CONTAINER_VIEWS)

-- Brief C4 addendum: whether an npc key is a real creature id (npc:<id>, id above nought) the
-- player has met (Core/CreatureLookup.lua Sighting, a table read) or the Creatures data knows
-- (Core/Creatures.lua Get, which builds that module the first time a page asks). A made up
-- Classic Era creature's page key (npc:-<creature id>, brief EK1) is never one. False, never nil.
function ViewModel.MetCreature(rootKey)
  local kind, id = Graph.Parse(rootKey)
  if kind ~= "npc" or type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then
    return false
  end
  local lookup = ItemTree.CreatureLookup
  if type(lookup) == "table" and type(lookup.Sighting) == "function" then
    local ok, record = pcall(lookup.Sighting, id)
    if ok and type(record) == "table" then
      return true
    end
  end
  local creatures = ItemTree.Creatures
  if type(creatures) == "table" and type(creatures.Get) == "function" then
    local ok, row = pcall(creatures.Get, id)
    if ok and type(row) == "table" then
      return true
    end
  end
  return false
end

-- Brief D7: an object key the shipped table places on a map (a herb, a vein, a fishing pool or a
-- chest whose name op carries pins for, E:ObjectMap) takes Edges.NODE_VIEWS, the Map tab alone,
-- and since the P6b addendum so does every gathering node row the table names (E:ObjectPage), pins
-- or none. Every other object, a live one the collector saw included, keeps the four it has always had. The
-- same cost: a key's arithmetic and a string lookup, and no pin is decoded.
function ViewModel.ViewsFor(rootKey)
  local kind = Graph.Kind(rootKey)
  -- Brief C2: an item or a recipe root has the Chain tab in front of its four. The kind alone
  -- decides it, so asking costs nothing.
  if kind ~= nil and ViewModel.CHAIN_KINDS[kind] and Edges.ViewsFor(kind) == Edges.VIEWS then
    -- Brief OL1: an openable item the table states contents for has Contains in the Disenchants
    -- slot. Every other item answers on its item row (E:ContainerHasContents), so only an openable
    -- item's page builds the loot index.
    if kind == "item" and ask(ItemTree.eraSources, "ContainerHasContents", rootKey) == true then
      return ViewModel.CONTAINER_ROOT_VIEWS
    end
    return chainViewsOf(Edges.VIEWS)
  end
  -- Brief Q8: a quest root has the Quest and Map tabs, whatever is known about it. Nothing is
  -- asked here, so a quest key costs its kind and nothing else.
  if kind == "quest" then
    return ViewModel.QUEST_VIEWS
  end
  local views = Edges.ViewsFor(kind)
  -- Brief Z1: a zone key the shipped table names an area for takes the Here and Map tabs. The
  -- key's arithmetic and one table lookup; nothing is indexed.
  if kind == "zone" and type(Edges.ZONE_VIEWS) == "table" then
    if type(ask(ItemTree.eraSources, "ZoneAt", rootKey)) == "number" then
      return Edges.ZONE_VIEWS
    end
    return views
  end
  if kind == "object" and type(Edges.NODE_VIEWS) == "table" then
    -- Brief OL1: a chest or another looted object (E:ObjectHasLoot, a string lookup) has the Loot
    -- tab in front of its Map, or alone where it has no page with a map.
    local era = ItemTree.eraSources
    local loot = ask(era, "ObjectHasLoot", rootKey) == true
    -- Brief EO1: a world object that starts or ends quests (og, two list lengths) has the Quests tab,
    -- and its Map only where op places it (E:ObjectMap).
    if ask(era, "ObjectGivesQuests", rootKey) == true then
      local map = type(ask(era, "ObjectMap", rootKey)) == "number"
      if loot then
        return map and Edges.OBJECT_LOOT_QUEST_VIEWS or Edges.OBJECT_LOOT_QUEST_ONLY_VIEWS
      end
      return map and Edges.OBJECT_QUEST_VIEWS or Edges.OBJECT_QUEST_ONLY_VIEWS
    end
    -- P6b addendum: every gathering node row has a page, pins or none (E:ObjectPage).
    if type(era) == "table" and type(era.ObjectPage) == "function" then
      local ok, nameIndex = pcall(era.ObjectPage, era, rootKey)
      if ok and type(nameIndex) == "number" then
        if loot then
          return Edges.OBJECT_VIEWS
        end
        return Edges.NODE_VIEWS
      end
    end
    if loot then
      return Edges.OBJECT_LOOT_VIEWS
    end
    return views
  end
  if views ~= Edges.NPC_VIEWS then
    return views
  end
  -- The collector first: it puts the name of an NPC it holds records for on the graph, which is
  -- what a positive id joins its Classic Era name by.
  local collected = ask(ItemTree.collector, "NpcFacts", rootKey)
  local era = ItemTree.eraSources
  local nameIndex, role = npcKind(era, rootKey)
  local creature = nameIndex ~= nil and role ~= "vendor"
  local vendor = type(ask(era, "VendorKind", rootKey)) == "number"
  local looted = type(collected) == "table" and (tonumber(collected.drops) or 0) > 0
  local bought = type(collected) == "table" and (tonumber(collected.sells) or 0) > 0
  -- Brief M3: a Merchant's Favor vendor the curated tier ships sells, and has a Map tab for the
  -- place the file or the player's own visit puts it.
  local favour = ItemTree.Sources and ItemTree.Sources.Favour or nil
  local shipped = type(favour) == "table" and type(favour.VendorFor) == "function" and favour.VendorFor(rootKey) ~= nil
  local placed = shipped or (type(collected) == "table" and type(collected.pos) == "table")
  -- Brief V1: a vendor the client's own tables list (Core/ForeverVendors.lua) sells, and has a Map
  -- tab where the module places it on a zone map. Asking loads the module, which an npc page is one
  -- of the two first needs of; a made up id (a Classic Era name's node) never asks.
  local client = clientVendorFacts(rootKey)
  if client and #clientPositions(client) > 0 then
    placed = true
  end
  -- Brief PS1: what players recorded about this npc (Core/PlayerSources.lua NpcFacts): it drops,
  -- sells, and has a Map tab where a vendor spot ships. Loads the module as the client's does.
  local reported = playerNpcFacts(rootKey)
  if reported and (tonumber(reported.spots) or 0) > 0 then
    placed = true
  end
  -- Brief TR1c (one block, for the TR2 merge): an owner confirmed claim's approximate position
  -- (Core/Creatures.lua claimSpots) gives a creature the Map tab too.
  if not placed then
    local claimRow = trainsCreatureRow(trainsCreatureId(rootKey))
    placed = claimRow ~= nil and claimRow.claimSpots ~= nil
  end
  -- Brief GF5: a predicted giver's or turn in's approximate position gives it the Map tab too, the
  -- way a trainer's does above (Core/QuestsPredicted.lua NpcPins, which never loads the module).
  if not placed then
    placed = #(predictedCall("NpcPins", rootKey) or EMPTY) > 0
  end
  local loot = creature or looted or (reported ~= nil and (tonumber(reported.drops) or 0) > 0)
  local sells = vendor
    or bought
    or shipped
    or client ~= nil
    or (reported ~= nil and (tonumber(reported.sells) or 0) > 0)
  -- Brief PS5: an npc the player module says starts or ends a quest has the Quests tab too.
  -- Brief GF5: and so does one the predicted facts say starts or ends one (never loads the module).
  local quests = questTotal(era, rootKey) > 0
    or playerQuestTotal(reported) > 0
    or (tonumber(predictedCall("NpcQuestCount", rootKey)) or 0) > 0
  -- Brief P6b: a trainer the table lists, by its list's length alone. Brief TR2 (owner QA
  -- 2026-10-11 item 128, "Train tab is redundant when we have a teaches tab"): and any trainer our
  -- sources know, its profession named or not (ViewModel.IsTrainer, table reads; a Classic Era
  -- trainer's list is decoded once per name and kept). Brief fix156 (owner QA 2026-10-14 item 156):
  -- a Classic Era class trainer too, by its title, so a page the trainer search lists never falls
  -- through to the item tabs below (it was Used by, Sources, Requires, Disenchants into and no Map).
  local teaches = (tonumber(ask(era, "TeachCount", rootKey)) or 0) > 0
  if ViewModel.IsTrainer(rootKey) then
    teaches = true
  end
  -- Brief CT1: and a name the table lists class spells for (tc), by its list's length alone.
  if not teaches and (tonumber(ask(era, "ClassTeachCount", rootKey)) or 0) > 0 then
    teaches = true
  end
  -- Brief C4 addendum: a creature with no Classic Era page that the player has met (a sighting)
  -- or the Creatures data knows is a creature too: the Loot tab, never the four item tabs.
  if not loot and not creature and ViewModel.MetCreature(rootKey) then
    loot = true
  end
  -- Brief TR2: "Loot is not relevant for a city npc who drops nothing", and only for one we KNOW
  -- drops nothing (ViewModel.KnownNoLoot): a creature with no role and no loot rows keeps Loot (0).
  if loot then
    local cityRole = teaches
      or sells
      or quests
      or (reported ~= nil and #(type(reported.roles) == "table" and reported.roles or EMPTY) > 0)
      or (nameIndex ~= nil and type(ask(era, "Title", nameIndex)) == "string")
    local lootRows = looted or (reported ~= nil and (tonumber(reported.drops) or 0) > 0)
    if cityRole and not lootRows and creature then
      lootRows = ask(era, "HasLoot", rootKey) == true
    end
    if ViewModel.KnownNoLoot(cityRole, lootRows) then
      loot = false
    end
  end
  -- Brief PS5: an npc the player module knows only as a trainer or a stable master (nothing it
  -- drops, sells or gives) is still an npc: its page is its Map tab, never the four item tabs.
  if not loot and not sells and not quests and not teaches and reported and placed then
    return npcViews(false, false, false, true, false)
  end
  if not loot and not sells and not quests and not teaches then
    return Edges.VIEWS
  end
  -- A creature keeps its Map tab whatever its pins, as it always has; a vendor only name takes one
  -- where mp places it (a string lookup, no pin decoded).
  local map = creature
  if nameIndex ~= nil and role == "vendor" then
    map = ask(era, "HasPins", nameIndex) == true
  end
  map = map or placed
  return npcViews(loot, sells, quests, map, teaches)
end

-- Brief TR2: whether an NPC is KNOWN to drop nothing, the one case its Loot tab is left out. The
-- owner's words (2026-10-11): "I'm talking about NPCs who we KNOW have no loot, not creatures who
-- might have loot but we don't know yet." role is whether our data holds the NPC in a city role: a
-- trainer (Classic Era teach spells, the Creatures data's tp / tk, a trainer visit, the player
-- module's trainer bit), a vendor (any of the vendor sources), a quest giver or ender, any of the
-- player module's role bits (k: vendor, giver, ender, trainer, stable master) or a Classic Era
-- title (SubName, which the table ships for vendors, trainers and quest givers alone). lootRows is
-- whether any source holds a loot row for it: the Classic Era loot rows, the player's own recorded
-- drops or the shipped player drops. Known empty is a role and no loot rows; no role is UNKNOWN,
-- and a creature we know nothing about keeps Loot (0) as it always has. Pure.
function ViewModel.KnownNoLoot(role, lootRows)
  if role and not lootRows then
    return true
  end
  return false
end

function ViewModel.ViewCounts(rootKey, opts)
  local counts = {}
  local views = ViewModel.ViewsFor(rootKey)
  for _, view in ipairs(views) do
    if (Edges.ViewDirection(view) or view == ViewModel.QUEST_VIEW) and view ~= Edges.MAP then
      counts[view] = 0
    end
  end
  if type(rootKey) ~= "string" then
    return counts
  end
  local fingerprint = optionFingerprint(opts)
  local dataGeneration, collectorGeneration = generations()
  local cached = countsHeld(rootKey, fingerprint)
  if cached and cached.data == dataGeneration and cached.collector == collectorGeneration then
    for view in pairs(counts) do
      counts[view] = cached.counts[view] or 0
    end
    return counts, cached.guessed
  end

  -- Brief GS3: how many of the Sources rows are guesses, kept beside the counts for the info
  -- column's one line (ViewModel.GuessCount), so that line never builds a view of its own.
  local guessed = 0
  for view in pairs(counts) do
    local total = 0
    -- Brief PS5: an npc the player module gives quests to is counted the long way, because its rows
    -- are plain data the predicted setting keeps and a quest both state is one row. Brief RB1 (owner
    -- QA 2026-10-17 item 197, Rorian the Dayseeker's "Quests (0)" over 13 Predicted rows): so is one
    -- the predicted quest facts give quests to (Core/QuestsPredicted.lua NpcQuestCount), whose rows
    -- the two Classic Era list lengths below never held.
    if view == Edges.QUESTS and not ViewModel.NpcQuestsLongWay(rootKey) then
      -- Brief N3: the two list lengths, with nothing decoded. Every row the tab draws is one of
      -- them, and every one is predicted, so the setting that hides predicted rows empties it.
      -- Brief CH1: less the other side's quests while "Hide other faction data" is on.
      if not (type(opts) == "table" and opts.showPredicted == false) then
        local starts, ends = ViewModel.EraQuestCounts(rootKey, ViewModel.HiddenSide(opts))
        total = starts + ends
      end
    else
      local vm = ViewModel.New(rootKey, view, opts)
      for _, category in ipairs(vm:Categories()) do
        total = total + (tonumber(category.count) or 0)
        if view == Edges.SOURCES then
          guessed = guessed + (tonumber(category.guesses) or 0)
        end
      end
    end
    counts[view] = total
  end

  local sets = countCache[rootKey]
  if not sets then
    local held = 0
    for _ in pairs(countCache) do
      held = held + 1
    end
    if held >= COUNT_CACHE_LIMIT then
      countCache = {}
    end
    sets = {}
    countCache[rootKey] = sets
  elseif sets[fingerprint] == nil then
    -- Brief CT1b: a root asked under more option sets than that starts its sets over.
    local held = 0
    for _ in pairs(sets) do
      held = held + 1
    end
    if held >= COUNT_SETS_LIMIT then
      sets = {}
      countCache[rootKey] = sets
    end
  end
  local heldCounts = {}
  for view, total in pairs(counts) do
    heldCounts[view] = total
  end
  sets[fingerprint] = {
    data = dataGeneration,
    collector = collectorGeneration,
    counts = heldCounts,
    guessed = guessed,
  }
  return counts, guessed
end

-- Brief RB1: whether an npc's Quests tab is counted off its rows (the view's own categories) rather
-- than the two Classic Era list lengths: where the player module gives it quests (brief PS5) or the
-- predicted quest facts do (item 197), never loading the data addon to ask. Pure over the modules.
function ViewModel.NpcQuestsLongWay(rootKey)
  if playerQuestTotal(playerNpcFacts(rootKey)) > 0 then
    return true
  end
  return (tonumber(predictedCall("NpcQuestCount", rootKey)) or 0) > 0
end

--- Brief RB1 (owner QA 2026-10-17 item 197): how many quests an npc starts and ends, the two counts
--- its page's "Starts 9 quests, ends 4" line words, the same rows its Quests tab draws: the Classic Era
--- list lengths where nothing else gives it quests (nothing decoded, brief N3), else the tab's own
--- Starts and Ends groups, Predicted rows included while they are shown. 0, 0 for anything else.
function ViewModel.NpcQuestCounts(rootKey, opts)
  if type(rootKey) ~= "string" then
    return 0, 0
  end
  if not ViewModel.NpcQuestsLongWay(rootKey) then
    if type(opts) == "table" and opts.showPredicted == false then
      return 0, 0
    end
    -- Brief CH1: less the other side's quests while "Hide other faction data" is on, as the tab.
    return ViewModel.EraQuestCounts(rootKey, ViewModel.HiddenSide(opts))
  end
  local starts, ends = 0, 0
  for _, category in ipairs(ViewModel.New(rootKey, Edges.QUESTS, opts):Categories()) do
    local first = type(category.entries) == "table" and category.entries[1] or nil
    local name = type(first) == "table" and type(first.type) == "table" and first.type.name or nil
    local count = tonumber(category.count) or 0
    if name == "GIVES_QUEST" then
      starts = starts + count
    elseif name == "TAKES_QUEST" then
      ends = ends + count
    end
  end
  return starts, ends
end

-- Brief GS3: how many guessed rows an item's Sources view holds once the real rows beside them
-- have shadowed what they can (Core/Graph.lua DropGuessEdges), or 0. The same answer and the same
-- cache as the tab counts, so the info column's line and the Sources tab never disagree and the
-- line costs nothing on a page whose tabs are already counted. 0 for anything but an item.
function ViewModel.GuessCount(rootKey, opts)
  if type(rootKey) ~= "string" or Graph.Kind(rootKey) ~= "item" or not guessSourcesShown(opts) then
    return 0
  end
  local dataGeneration, collectorGeneration = generations()
  local cached = countsHeld(rootKey, optionFingerprint(opts))
  if cached and cached.data == dataGeneration and cached.collector == collectorGeneration then
    return tonumber(cached.guessed) or 0
  end
  -- Not counted yet: the Sources view alone, and nothing kept, so the tabs still count the rest.
  local guessed = 0
  for _, category in ipairs(ViewModel.New(rootKey, Edges.SOURCES, opts):Categories()) do
    guessed = guessed + (tonumber(category.guesses) or 0)
  end
  return guessed
end

-- The same answer for a caller that still thinks in directions: down is the uses view and up is
-- the sources view. Neither of the later two views is in it, so down no longer counts the
-- disenchant results. Kept until the window and the harness ask for ViewCounts, and then it goes.
function ViewModel.DirectionCounts(rootKey, opts)
  local counts = ViewModel.ViewCounts(rootKey, opts)
  return { down = counts[Edges.USES], up = counts[Edges.SOURCES] }
end

--------------------------------------------------------------------------------
-- The row a zone's Map tab pins (brief Z1)
--------------------------------------------------------------------------------

-- The source the player picked on each zone root's Here tab, by root key, for this session only:
-- it is never written to saved variables. The Map tab reads it back, so picking a row and then
-- pressing Map keeps the pick, and each zone keeps its own.
ViewModel.zonePicks = {}

-- Picks one source for a zone root's Map tab: { nameIndex, kind ("npc" or "object"), name }.
-- Answers whether it was kept, which is only for a zone root and a pick that names something.
--
-- Brief Z2: item is the item key of the Here row the source was picked on, where the caller has
-- one. The Map view's item column then opens on that row (ViewModel.ZoneItemPick), so the pick is
-- kept across the switch; the item row held before it is let go.
function ViewModel.PickZoneSource(rootKey, pick, item)
  if type(rootKey) ~= "string" or Graph.Kind(rootKey) ~= "zone" then
    return false
  end
  if type(pick) ~= "table" or type(pick.nameIndex) ~= "number" then
    return false
  end
  local held = { nameIndex = pick.nameIndex, kind = pick.kind, name = pick.name }
  if type(item) == "string" then
    held.item = item
  end
  ViewModel.zonePicks[rootKey] = held
  ViewModel.zoneItemPicks[rootKey] = nil
  return true
end

-- The source a zone root's Map tab pins, or nil for none: the player's pick, or where there is
-- none the gathering node the key itself names (a node row's zone row opens its zone with that
-- node already picked).
function ViewModel.ZonePick(rootKey)
  local held = type(rootKey) == "string" and ViewModel.zonePicks[rootKey] or nil
  if held then
    return held
  end
  local facts = eraCall("ZoneFacts", rootKey)
  if type(facts) == "table" and type(facts.nameIndex) == "number" and facts.nodeName then
    return { nameIndex = facts.nameIndex, kind = "object", name = facts.nodeName }
  end
  return nil
end

-- What a zone root's Here tab holds, per category, for the page's header: { { id, label, count } }
-- in the tab's own order, and the total. The same view model the tab draws from, so the header and
-- the tab never disagree.
function ViewModel.ZoneCounts(rootKey, opts)
  local out, total = {}, 0
  if type(rootKey) ~= "string" or Graph.Kind(rootKey) ~= "zone" then
    return out, total
  end
  local vm = ViewModel.New(rootKey, Edges.HERE, opts)
  for _, category in ipairs(vm:Categories()) do
    local count = tonumber(category.count) or 0
    -- Brief Z4: a kept group (a Forever instance's Dropped here) is counted at 0 too.
    if count > 0 or category.keep then
      out[#out + 1] = { id = category.id, label = category.label, count = count }
      total = total + count
    end
  end
  -- Brief Z2 (2026-09-30): the zone's creatures and NPCs, one line each, after the tab's own. They
  -- are the Map view's groups and not the tab's rows, so the total leaves them out.
  for _, group in ipairs(ViewModel.ZonePeopleGroups(ViewModel.ZonePeople(rootKey, opts))) do
    out[#out + 1] = { id = group.id, label = group.label, count = #group.items }
  end
  return out, total
end

--------------------------------------------------------------------------------
-- Where an instance's entrance is (brief M7)
--------------------------------------------------------------------------------

-- How many Classic Era pins stand in for an entrance where the client names none, the cap one
-- creature's zone takes on the Map tab (UI/Map.lua Map.PIN_CAP).
ViewModel.ENTRANCE_PIN_CAP = 6

-- A name as the entrance match folds it: lower case, trimmed. nil for no name.
local function foldName(text)
  if type(text) ~= "string" then
    return nil
  end
  local folded = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
  if folded == "" then
    return nil
  end
  return folded
end

-- A point a Boss loot place ships (brief M8): reader is "EntrancePoint" (the instance portal) or
-- "MouthPoint" (the outdoor mouth), read by Core/BossLoot.lua, which loads after this file and is
-- looked up at call time. nil where the place ships none.
local function shippedPoint(place, reader)
  local BossLoot = ItemTree.BossLoot
  if type(BossLoot) ~= "table" or type(BossLoot[reader]) ~= "function" then
    return nil
  end
  local ok, point = pcall(BossLoot[reader], place)
  if ok and type(point) == "table" then
    return point
  end
  return nil
end

-- The Boss loot index's place for one instance, out of the index alone: the place whose area (a)
-- is the instance's, or failing that the one whose name (n) or AreaTable name (an) is the
-- instance's name. Answers { name, names, zone, continent, creatures, portal, mouth } or nil, where
-- names is every name the place goes by (for matching the client's own entrance list), zone the
-- entrance zone's name (ez), creatures the name indexes of its entries that have a creature (e), in
-- the index's own order, portal the instance portal the index ships (brief M8: eu, ex, ey, read by
-- Core/BossLoot.lua BossLoot.EntrancePoint) and mouth its outdoor mouth (mu, mx, my, read by
-- BossLoot.MouthPoint), each { map, x, y } in percent or nil. A world boss (k = 3) has no entrance
-- and answers nil. Pure.
--
--   index  the BossLoot module's table ({ s, p, b })
--   facts  { areaId, name } of the instance (Core/EraSources.lua E:ZoneFacts)
function ViewModel.EntrancePlace(index, facts)
  if type(index) ~= "table" or type(index.p) ~= "table" or type(index.s) ~= "table" then
    return nil
  end
  if type(facts) ~= "table" then
    return nil
  end
  local strings = index.s
  local function str(at)
    local value = type(at) == "number" and strings[at] or nil
    return type(value) == "string" and value ~= "" and value or nil
  end
  local areaId = tonumber(facts.areaId)
  local wanted = foldName(facts.name)
  local found = nil
  for _, place in ipairs(index.p) do
    if type(place) == "table" and tonumber(place.k) ~= 3 then
      if areaId and tonumber(place.a) == areaId then
        found = place
        break
      end
      if not found and wanted and (foldName(str(place.n)) == wanted or foldName(str(place.an)) == wanted) then
        found = place
      end
    end
  end
  if not found then
    return nil
  end
  local names = {}
  for _, name in ipairs({ str(found.n), str(found.an), facts.name }) do
    if type(name) == "string" and name ~= "" then
      names[#names + 1] = name
    end
  end
  local creatures = {}
  for _, id in ipairs(type(found.b) == "table" and found.b or EMPTY) do
    local boss = type(index.b) == "table" and index.b[id] or nil
    if type(boss) == "table" and type(boss.e) == "number" then
      creatures[#creatures + 1] = boss.e
    end
  end
  return {
    name = str(found.n) or facts.name,
    names = names,
    zone = str(found.ez),
    continent = str(found.ec),
    creatures = creatures,
    portal = shippedPoint(found, "EntrancePoint"),
    mouth = shippedPoint(found, "MouthPoint"),
  }
end

-- The Classic Era pins that stand in for an entrance the client does not name: for each of the
-- instance's creatures, its first pin in the entrance zone, named for the creature, capped at
-- ViewModel.ENTRANCE_PIN_CAP. A creature that is only ever inside has no pin there (the table
-- ships no pin for an instance's own area), so this is usually empty. Pure.
--
--   pinsOf     function(nameIndex) -> the name's decoded pins ({ area, map, x, y })
--   nameOf     function(nameIndex) -> the name, or nil
function ViewModel.EntranceNearPins(creatures, zoneArea, pinsOf, nameOf)
  local out = {}
  if type(creatures) ~= "table" or type(zoneArea) ~= "number" or type(pinsOf) ~= "function" then
    return out
  end
  for _, nameIndex in ipairs(creatures) do
    if #out >= ViewModel.ENTRANCE_PIN_CAP then
      break
    end
    local pins = pinsOf(nameIndex)
    for _, pin in ipairs(type(pins) == "table" and pins or EMPTY) do
      local x = type(pin) == "table" and tonumber(pin.x) or nil
      local y = type(pin) == "table" and tonumber(pin.y) or nil
      if x and y and tonumber(pin.area) == zoneArea then
        local name = type(nameOf) == "function" and nameOf(nameIndex) or nil
        out[#out + 1] = { x = x, y = y, name = name }
        break
      end
    end
  end
  return out
end

-- Everything the Map tab of an instance's own page needs to draw its entrance, or nil where the
-- key is no instance, or it ships no entrance point and its entrance zone is not known or has no
-- map:
--
--   { areaId, instance, names, zoneName, zoneHint, zoneArea, map, near, shipped }
--
-- areaId and instance are the instance's own area and name; names every name it goes by; map the
-- zone map drawn (brief M8): the shipped mouth's (mu) where the index ships one, since that is the
-- map a traveller needs, else the shipped portal's (eu), else the entrance zone's; either shipped
-- map wins over the ez zone's. shipped is { mouth, portal }, each { x, y } in percent on that map
-- or nil (a portal on another map than the mouth's is left out), and shipped itself is nil where
-- neither is drawn. zoneName and zoneArea are the entrance zone's where its map is the map drawn,
-- else nil (UI/Map.lua then asks the client for the drawn map's name); zoneHint is the entrance
-- zone's name whatever map is drawn. near the Classic Era pins that stand in where neither the
-- client nor the index names the entrance (ViewModel.EntranceNearPins). Asks the client
-- nothing: UI/Map.lua asks the client's own entrance list itself. Reads the Boss loot index, which
-- the page's own data addon holds, and decodes the instance's creatures' pins, so only the Map tab
-- of an instance's page calls it.
function ViewModel.InstanceEntrance(rootKey)
  if type(rootKey) ~= "string" or Graph.Kind(rootKey) ~= "zone" then
    return nil
  end
  local facts = eraCall("ZoneFacts", rootKey)
  if type(facts) ~= "table" or type(facts.areaId) ~= "number" or facts.map ~= nil then
    return nil
  end
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.Get) ~= "function" then
    return nil
  end
  local ok, index = pcall(data.Get, data, "BossLoot")
  if not ok then
    return nil
  end
  local place = ViewModel.EntrancePlace(index, facts)
  if not place then
    return nil
  end
  local zoneArea = place.zone and eraCall("AreaIdOf", place.zone) or nil
  if type(zoneArea) ~= "number" then
    zoneArea = nil
  end
  local zoneMap = zoneArea and eraCall("MapOf", zoneArea) or nil
  if type(zoneMap) ~= "number" then
    zoneMap = nil
  end
  local mouth, portal = place.mouth, place.portal
  local map = (mouth and mouth.map) or (portal and portal.map) or zoneMap
  if type(map) ~= "number" then
    return nil
  end
  local shipped = nil
  if mouth then
    shipped = { mouth = { x = mouth.x, y = mouth.y } }
  end
  if portal and portal.map == map then
    shipped = shipped or {}
    shipped.portal = { x = portal.x, y = portal.y }
  end
  local sameZone = zoneMap ~= nil and zoneMap == map
  local near = {}
  if sameZone then
    near = ViewModel.EntranceNearPins(place.creatures, zoneArea, function(nameIndex)
      return eraCall("PinsOf", nameIndex)
    end, function(nameIndex)
      local key = eraCall("PageKey", nameIndex)
      if key then
        return (eraCall("NameFor", key))
      end
      -- Brief EK1: a name with no page key is named by its name all the same.
      return (eraCall("NameAt", nameIndex))
    end)
  end
  return {
    areaId = facts.areaId,
    instance = facts.name or place.name,
    names = place.names,
    zoneName = sameZone and place.zone or nil,
    zoneHint = place.zone,
    zoneArea = sameZone and zoneArea or nil,
    map = map,
    near = near,
    shipped = shipped,
  }
end

--------------------------------------------------------------------------------
-- Where a world boss spawns (brief M8, owner addition 2026-09-30)
--------------------------------------------------------------------------------

-- The world boss one Classic Era creature name is, out of the Boss loot index alone: the first
-- entry of a world boss place (k = 3) whose creature (e) is the name. Answers { name, zones } or
-- nil, where name is the boss entry's name and zones the place's zone names (z), in order, and
-- shared = true where the place is shared (po, brief M11). Several
-- bosses in one place are each their own entry, so each answers for its own name. Pure.
function ViewModel.WorldBossOf(index, nameIndex)
  if type(index) ~= "table" or type(index.p) ~= "table" or type(index.b) ~= "table" then
    return nil
  end
  if type(nameIndex) ~= "number" then
    return nil
  end
  local strings = type(index.s) == "table" and index.s or EMPTY
  local function str(at)
    local value = type(at) == "number" and strings[at] or nil
    return type(value) == "string" and value ~= "" and value or nil
  end
  for _, place in ipairs(index.p) do
    if type(place) == "table" and tonumber(place.k) == 3 then
      for _, id in ipairs(type(place.b) == "table" and place.b or EMPTY) do
        local boss = index.b[id]
        if type(boss) == "table" and boss.e == nameIndex then
          local zones = {}
          for _, at in ipairs(type(place.z) == "table" and place.z or EMPTY) do
            zones[#zones + 1] = str(at)
          end
          local answer = { name = str(boss.n) or str(place.n), zones = zones }
          -- Brief M11: po = 1 is a shared place (the boss stands at one of its places at a time).
          if tonumber(place.po) == 1 then
            answer.shared = true
          end
          return answer
        end
      end
    end
  end
  return nil
end

-- Everything a world boss's own Map tab needs beyond the creature's own pins, or nil where the
-- name is no world boss (or there is no Boss loot index): { name, zones, maps }, maps each of the
-- boss's zones that this build names an area and a zone map for, { areaId, name, map }, which is
-- where the map is drawn when Classic Era places the boss nowhere. Reads the Boss loot index,
-- which the page's own data addon holds, so only a creature page's Map tab calls it.
function ViewModel.WorldBoss(nameIndex)
  if type(nameIndex) ~= "number" then
    return nil
  end
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.Get) ~= "function" then
    return nil
  end
  local ok, index = pcall(data.Get, data, "BossLoot")
  if not ok then
    return nil
  end
  local boss = ViewModel.WorldBossOf(index, nameIndex)
  if not boss then
    return nil
  end
  local maps = {}
  for _, zone in ipairs(boss.zones) do
    local areaId = eraCall("AreaIdOf", zone)
    local map = type(areaId) == "number" and eraCall("MapOf", areaId) or nil
    if type(map) == "number" then
      maps[#maps + 1] = { areaId = areaId, name = zone, map = map }
    end
  end
  boss.maps = maps
  return boss
end

--------------------------------------------------------------------------------
-- The items a zone's Map view lists beside the map (brief Z2)
--------------------------------------------------------------------------------

-- What a zone's item row counts its sources in, by category id: the singular and the plural, each
-- the English wording and its own locale key. A creature for the three ways off a creature, a node
-- for a vein or a herb, a pool, an object for a chest, a vendor.
local ZONE_NOUNS = {
  drops = { "1 creature", "%d creatures" },
  skinned = { "1 creature", "%d creatures" },
  pickpocketed = { "1 creature", "%d creatures" },
  minedfrom = { "1 node", "%d nodes" },
  gathered = { "1 node", "%d nodes" },
  fishedin = { "1 pool", "%d pools" },
  foundin = { "1 object", "%d objects" },
  soldby = { "1 vendor", "%d vendors" },
  quests = { "1 quest", "%d quests" },
}

-- What a row says whose only source names nothing: a whole fishing zone, which is every pool in it.
ViewModel.ZONE_WHOLE = "Zone wide"

-- "8 creatures", "1 node": the muted count on one of a zone's item rows. Pure.
function ViewModel.ZoneSourceCount(categoryId, count)
  count = math.floor(tonumber(count) or 0)
  if count < 1 then
    return L[ViewModel.ZONE_WHOLE]
  end
  local nouns = ZONE_NOUNS[categoryId]
  if not nouns then
    return tostring(count)
  end
  if count == 1 then
    return L[nouns[1]]
  end
  return string.format(L[nouns[2]], count)
end

-- One source of an item row: the name its pins are keyed by and whose pins they are, the name, and
-- the rate the Here row states for it. Two rows naming one source keep one, with the better rate.
local function sourceSlot(edge)
  local pick = type(edge.pick) == "table" and edge.pick or nil
  if pick and type(pick.nameIndex) == "number" then
    return tostring(pick.kind) .. ":" .. tostring(pick.nameIndex), pick
  end
  if type(edge.zone) == "string" and edge.zone ~= "" then
    return "name:" .. string.lower(edge.zone), nil
  end
  return nil, nil
end

-- A zone's items, one row per item per category, out of the Here tab's own categories: the pure
-- half of ViewModel.ZoneItemList, which a spec hands categories to directly. sourceOf(edge) answers
-- the row's source facts (Core/Sources.lua), whose rate is what a pin's tooltip says; it may be nil.
--
--   { groups = { { id, key, label, icon, items = { entry } } }, byKey = { [entry.key] = entry },
--     total = entries in all }
--   entry = { key ("<category id>/<item key>"), group, item, itemId, name, quality, icon,
--             undiscovered, discovered, count (named sources), countText, historical,
--             sources = { { nameIndex, kind, name, percent, rate, historical } } }
--
-- Inside a group the rows read by name, then by item id, so the order is the same on every load.
function ViewModel.ZoneItemsOf(categories, sourceOf)
  local list = { groups = {}, byKey = {}, total = 0 }
  for _, category in ipairs(type(categories) == "table" and categories or EMPTY) do
    local group = {
      id = category.id,
      key = category.key,
      label = category.label,
      icon = category.icon,
      items = {},
    }
    local byItem = {}
    for _, edge in ipairs(category.entries or EMPTY) do
      local target = type(edge) == "table" and edge.target or nil
      if type(target) == "string" and not edge.requirement then
        local entry = byItem[target]
        if not entry then
          local node = Graph.Node(target) or EMPTY
          local _, itemId = Graph.Parse(target)
          entry = {
            key = tostring(category.id) .. "/" .. target,
            group = category.id,
            item = target,
            itemId = itemId,
            name = node.name or Graph.Name(target) or target,
            quality = node.quality,
            icon = node.icon,
            undiscovered = node.undiscovered,
            discovered = node.discovered,
            sources = {},
            slots = {},
            historical = true,
          }
          byItem[target] = entry
          group.items[#group.items + 1] = entry
        end
        if edge.historical ~= true then
          entry.historical = false
        end
        local slot, pick = sourceSlot(edge)
        if slot then
          local facts = type(sourceOf) == "function" and sourceOf(edge) or nil
          local rate = type(facts) == "table" and facts.rate or nil
          local held = entry.slots[slot]
          if not held then
            held = {
              nameIndex = pick and pick.nameIndex or nil,
              kind = pick and pick.kind or nil,
              name = (pick and pick.name) or edge.zone,
              percent = edge.percent,
              rate = rate,
              historical = edge.historical == true,
            }
            entry.slots[slot] = held
            entry.sources[#entry.sources + 1] = held
          elseif (tonumber(edge.percent) or -1) > (tonumber(held.percent) or -1) then
            held.percent, held.rate = edge.percent, rate
          end
        end
      end
    end
    table.sort(group.items, function(a, b)
      local left, right = string.lower(tostring(a.name)), string.lower(tostring(b.name))
      if left ~= right then
        return left < right
      end
      return (tonumber(a.itemId) or 0) < (tonumber(b.itemId) or 0)
    end)
    for _, entry in ipairs(group.items) do
      entry.slots = nil
      entry.count = #entry.sources
      entry.countText = ViewModel.ZoneSourceCount(category.id, entry.count)
      list.byKey[entry.key] = entry
      list.total = list.total + 1
    end
    if #group.items > 0 then
      list.groups[#list.groups + 1] = group
    end
  end
  return list
end

-- Brief Z2 (2026-09-30): the two groups after a zone's items, the creatures and the NPCs the Classic
-- Era table places in it, each row one name (Core/EraSources.lua EraSources.ZonePeople). Their ids
-- are this file's own and never a category's, so no saved filter can name them.
ViewModel.ZONE_CREATURES = "creatures"
ViewModel.ZONE_NPCS = "npcs"

-- "14 places", "1 place": a creature's or an NPC's muted count, its pins in this zone. The same
-- words the caption under the map counts places in (UI/Map.lua Map.PLACES). Pure.
function ViewModel.ZonePlacesText(count)
  count = math.floor(tonumber(count) or 0)
  if count == 1 then
    return L["1 place"]
  end
  return string.format(L["%d places"], count)
end

-- What an NPC is, in the words its row says at the right: a vendor, then a trainer, then a quest
-- giver, then one who only takes quests back, the first that holds. Pure.
function ViewModel.NpcRole(person)
  if type(person) ~= "table" then
    return nil
  end
  if person.vendor then
    return L["Vendor"]
  end
  if person.trainer then
    return L["Trainer"]
  end
  if (tonumber(person.starts) or 0) > 0 then
    return L["Quest giver"]
  end
  if (tonumber(person.ends) or 0) > 0 then
    return L["Quest ender"]
  end
  return nil
end

-- Every role an NPC has, joined: "Vendor, Quest giver". What its row's tooltip says. Pure.
local function npcRoles(person)
  local words = {}
  if person.vendor then
    words[#words + 1] = L["Vendor"]
  end
  if person.trainer then
    words[#words + 1] = L["Trainer"]
  end
  if (tonumber(person.starts) or 0) > 0 then
    words[#words + 1] = L["Quest giver"]
  end
  if (tonumber(person.ends) or 0) > 0 and (tonumber(person.starts) or 0) == 0 then
    words[#words + 1] = L["Quest ender"]
  end
  return table.concat(words, ", ")
end

-- The short words beside a creature's name: its level ("15" or "15-16") where ck states one, else
-- its type ("Beast"), else nothing. Pure.
function ViewModel.CreatureDetail(person)
  if type(person) ~= "table" then
    return nil
  end
  local low, high = tonumber(person.low), tonumber(person.high)
  if low and low > 0 then
    if high and high > low then
      return string.format("%d-%d", low, high)
    end
    return tostring(low)
  end
  local Sources = ItemTree.Sources
  local types = type(Sources) == "table" and Sources.CREATURE_TYPES or nil
  local word = type(types) == "table" and types[person.type] or nil
  if type(word) == "string" then
    return L[word]
  end
  return nil
end

-- A creature's line in its row's tooltip: "Beast, Wolf, level 23 to 24", out of Core/Sources.lua,
-- and "Critter, level 5" (brief Z4) for a creature of one level rather than "level 5 to 5".
local function creatureKindText(person)
  local Sources = ItemTree.Sources
  if type(Sources) ~= "table" or type(Sources.KindText) ~= "function" or person.type == nil then
    return nil
  end
  local low, high = tonumber(person.low), tonumber(person.high)
  if low and low == high and type(Sources.WithNote) == "function" then
    local asked, kind = pcall(Sources.KindText, { type = person.type, family = person.family })
    local level = string.format(L["level %d"], low)
    if asked and type(kind) == "string" and kind ~= "" then
      return Sources.WithNote(kind, level)
    end
    return level
  end
  local ok, text = pcall(Sources.KindText, person)
  if ok and type(text) == "string" and text ~= "" then
    return text
  end
  return nil
end

-- One name of EraSources.ZonePeople as an entry of ViewModel.ZoneItemsOf's shape: the page its eye
-- opens (person.key, the creature's or the vendor's own page, brief EK1 EraSources.PageKey), its one
-- source (the name itself, whose pins the map draws), and person = true, which is how the caption
-- and the tooltip tell it from an item. detail is the words beside the name, tips the tooltip's
-- lines under it. A name with no page (no key) is still listed, by its name's place, with no eye.
local function personEntry(groupId, person, npc)
  local key = person.key
  local entry = {
    key = groupId .. "/" .. (key or ("era:" .. tostring(person.nameIndex))),
    group = groupId,
    item = key,
    name = person.name,
    person = true,
    count = 1,
    places = person.pins,
    countText = npc and ViewModel.NpcRole(person) or ViewModel.ZonePlacesText(person.pins),
    sources = { { nameIndex = person.nameIndex, kind = "npc", name = person.name } },
    historical = true,
    tips = {},
  }
  if npc then
    if person.vendor then
      entry.icon = "CAT_VENDOR"
    elseif person.trainer then
      entry.icon = "CAT_TRAINER"
    else
      entry.icon = "CAT_QUEST"
    end
    if type(person.title) == "string" and person.title ~= "" then
      entry.tips[#entry.tips + 1] = person.title
    end
    entry.tips[#entry.tips + 1] = npcRoles(person)
    entry.tips[#entry.tips + 1] = ViewModel.ZonePlacesText(person.pins)
  else
    entry.icon = ViewModel.CreatureIcon(person) or "CREATURE_UNKNOWN"
    entry.detail = ViewModel.CreatureDetail(person)
    local kind = creatureKindText(person)
    if kind then
      entry.tips[#entry.tips + 1] = kind
    end
    entry.tips[#entry.tips + 1] = entry.countText
  end
  return entry
end

-- The two groups out of one zone's EraSources.ZonePeople answer, in ViewModel.ZoneItemsOf's group
-- shape: "Creatures here", then "NPCs here", each left out where it would be empty. Pure.
function ViewModel.ZonePeopleGroups(people)
  local out = {}
  if type(people) ~= "table" then
    return out
  end
  local specs = {
    { id = ViewModel.ZONE_CREATURES, label = L["Creatures here"], icon = "CREATURE_BEAST", list = people.creatures },
    { id = ViewModel.ZONE_NPCS, label = L["NPCs here"], icon = "CREATURE_HUMANOID", list = people.npcs, npc = true },
  }
  for _, spec in ipairs(specs) do
    local group = { id = spec.id, key = spec.id, label = spec.label, icon = spec.icon, items = {} }
    for _, person in ipairs(type(spec.list) == "table" and spec.list or EMPTY) do
      if type(person) == "table" and type(person.nameIndex) == "number" and type(person.name) == "string" then
        group.items[#group.items + 1] = personEntry(spec.id, person, spec.npc)
      end
    end
    if #group.items > 0 then
      out[#out + 1] = group
    end
  end
  return out
end

-- One zone root's creatures and NPCs (Core/EraSources.lua E:ZonePeople, kept there per zone), or
-- nil for a root that is not a zone or while predicted data is hidden: every name comes from the
-- Classic Era table, which is Predicted like every other row it gives a zone.
function ViewModel.ZonePeople(rootKey, opts)
  if type(rootKey) ~= "string" or Graph.Kind(rootKey) ~= "zone" then
    return nil
  end
  if type(opts) == "table" and opts.showPredicted == false then
    return nil
  end
  local people = eraCall("ZonePeople", rootKey)
  if type(people) ~= "table" then
    return nil
  end
  -- Brief F155: the other side's vendors and trainers leave "NPCs here", and with them their pins
  -- on the zone's map.
  return ViewModel.WithoutOtherSidePeople(people, ViewModel.HiddenSide(opts))
end

-- Brief F155 (owner QA 2026-10-14 item 155, "hide unrelated faction NPCs to the current
-- character"): whether a Classic Era NAME (a vendor, a trainer) serves the other side
-- alone for a character of side ("Alliance" or "Horde", nil while nothing is hidden), by the side
-- the table states for it (cf, Core/EraSources.lua E:Faction). A neutral name (3), a name with no
-- side and every name while side is nil answer false. Guarded.
function ViewModel.HidesEraName(nameIndex, side)
  local mine = SIDE_NUMBERS[side]
  if mine == nil or type(nameIndex) ~= "number" then
    return false
  end
  local stated = eraCall("Faction", nameIndex)
  return (stated == 1 or stated == 2) and stated ~= mine
end

-- Brief F155: one zone's people (E:ZonePeople's answer) less the vendors and trainers of the other
-- side (ViewModel.HidesEraName), the NPCs the setting hides everywhere else. A quest giver or ender
-- of the other side stays (it may be a creature the player hunts), and the creatures are never
-- touched (a drop source is never hidden). The answer is E:ZonePeople's own table, which E keeps, so
-- a copy comes back where an NPC goes; the same table where none does. Pure over the table it reads.
function ViewModel.WithoutOtherSidePeople(people, side)
  if type(people) ~= "table" or SIDE_NUMBERS[side] == nil or type(people.npcs) ~= "table" then
    return people
  end
  local npcs = {}
  for _, person in ipairs(people.npcs) do
    local trades = type(person) == "table" and (person.vendor or person.trainer)
    if not (trades and ViewModel.HidesEraName(person.nameIndex, side)) then
      npcs[#npcs + 1] = person
    end
  end
  if #npcs == #people.npcs then
    return people
  end
  local out = {}
  for field, value in pairs(people) do
    out[field] = value
  end
  out.npcs = npcs
  return out
end

-- Appends a zone's creature and NPC groups to its item list, their rows keyed and counted with the
-- items'. Answers the list.
local function addPeople(list, people)
  for _, group in ipairs(ViewModel.ZonePeopleGroups(people)) do
    list.groups[#list.groups + 1] = group
    for _, entry in ipairs(group.items) do
      list.byKey[entry.key] = entry
      list.total = list.total + 1
    end
  end
  return list
end

-- The item lists built so far, by root, each with the options and the generations it was built
-- under, the way the view counts are kept. A zone's list is built the first time its Map view is
-- shown and never at login or on the Here view; the last one built per root is what the map reads
-- its pick from (ViewModel.HeldZoneItem), whatever options it was built with.
local zoneItemCache = {}
local ZONE_ITEM_CACHE = 4
ViewModel.zoneItemBuilds = 0

-- Drops every kept list (ViewModel.Reset, and a spec). The picks are the player's and are kept.
function ViewModel.ResetZoneItems()
  zoneItemCache = {}
end

-- A zone root's item list for the Map view, built from the Here tab's categories once per root,
-- options and generation, and kept. nil for anything that is not a zone root.
function ViewModel.ZoneItemList(rootKey, opts)
  if type(rootKey) ~= "string" or Graph.Kind(rootKey) ~= "zone" then
    return nil
  end
  local fingerprint = optionFingerprint(opts)
  local dataGeneration, collectorGeneration = generations()
  local held = zoneItemCache[rootKey]
  if
    held
    and held.fingerprint == fingerprint
    and held.data == dataGeneration
    and held.collector == collectorGeneration
  then
    return held.list
  end
  local vm = ViewModel.New(rootKey, Edges.HERE, opts)
  local list = ViewModel.ZoneItemsOf(vm:Categories(), function(edge)
    return vm:_Source(edge)
  end)
  -- Brief M15: the items a placed object guess stands in this zone for.
  ViewModel.AddPlacedZoneItems(list, ViewModel.PlacedZoneItems(rootKey, opts))
  addPeople(list, ViewModel.ZonePeople(rootKey, opts))
  ViewModel.zoneItemBuilds = ViewModel.zoneItemBuilds + 1
  local count = 0
  for _ in pairs(zoneItemCache) do
    count = count + 1
  end
  if not held and count >= ZONE_ITEM_CACHE then
    zoneItemCache = {}
  end
  zoneItemCache[rootKey] = {
    fingerprint = fingerprint,
    data = dataGeneration,
    collector = collectorGeneration,
    list = list,
  }
  return list
end

-- The same list, kept with this view model as well, so a redraw of one page asks nothing twice.
function VM:ZoneItems()
  if self.zoneItems == nil then
    self.zoneItems = ViewModel.ZoneItemList(self.root, self.opts) or false
  end
  return self.zoneItems or nil
end

-- The rows the item column draws: a header per group ({ kind = "category", key, id, label, icon,
-- count, collapsed }) and under an open one its items ({ kind = "item", key, entry }). text filters
-- the items by name, plainly and without regard to case, and a group none of whose items match is
-- left out; collapsed is a set of group ids the player has closed. Pure.
function ViewModel.ZoneItemRows(list, text, collapsed)
  local rows = {}
  if type(list) ~= "table" then
    return rows
  end
  local needle = type(text) == "string" and string.lower(text:match("^%s*(.-)%s*$") or "") or ""
  collapsed = type(collapsed) == "table" and collapsed or EMPTY
  for _, group in ipairs(list.groups or EMPTY) do
    local shown = {}
    for _, entry in ipairs(group.items or EMPTY) do
      if needle == "" or string.find(string.lower(tostring(entry.name)), needle, 1, true) then
        shown[#shown + 1] = entry
      end
    end
    if #shown > 0 then
      local closed = collapsed[group.id] == true
      rows[#rows + 1] = {
        kind = "category",
        key = "cat:" .. tostring(group.id),
        id = group.id,
        label = group.label,
        icon = group.icon,
        count = #shown,
        collapsed = closed,
      }
      if not closed then
        for _, entry in ipairs(shown) do
          rows[#rows + 1] = { kind = "item", key = entry.key, entry = entry }
        end
      end
    end
  end
  return rows
end

-- The item row a zone's Map view opens on, out of a list: the row that names both the item the
-- player came from (prefer) and the source they arrived with (source, { nameIndex, kind }), else the
-- first row naming that source, else the first row of the item they came from, else the first row
-- of all. The second answer says whether the arrival named anything in the list. Pure.
function ViewModel.ResolveZoneItem(list, source, prefer)
  if type(list) ~= "table" then
    return nil, false
  end
  local first, bySource, byItem = nil, nil, nil
  local wanted = type(source) == "table" and type(source.nameIndex) == "number" and source or nil
  for _, group in ipairs(list.groups or EMPTY) do
    for _, entry in ipairs(group.items or EMPTY) do
      first = first or entry
      local named = false
      if wanted then
        for _, held in ipairs(entry.sources or EMPTY) do
          if held.nameIndex == wanted.nameIndex and (wanted.kind == nil or held.kind == wanted.kind) then
            named = true
            break
          end
        end
      end
      if named and prefer ~= nil and entry.item == prefer then
        return entry, true
      end
      if named then
        bySource = bySource or entry
      end
      if prefer ~= nil and entry.item == prefer then
        byItem = byItem or entry
      end
    end
  end
  if bySource then
    return bySource, true
  end
  if byItem then
    return byItem, true
  end
  return first, false
end

-- The item row picked on each zone root's Map view, by root key, for this session only (never
-- saved): { key, from }. from is the page the player arrived from when it was picked, so coming
-- back from somewhere else picks again while switching views keeps the pick.
ViewModel.zoneItemPicks = {}

-- Picks one item row of a zone's Map view by its key. Answers whether it was kept, which is only for
-- a zone root and a key its last built list holds (or any key, with no list built yet).
function ViewModel.PickZoneItem(rootKey, entryKey)
  if type(rootKey) ~= "string" or Graph.Kind(rootKey) ~= "zone" or type(entryKey) ~= "string" then
    return false
  end
  local held = zoneItemCache[rootKey]
  if held and not held.list.byKey[entryKey] then
    return false
  end
  local previous = ViewModel.zoneItemPicks[rootKey]
  ViewModel.zoneItemPicks[rootKey] = { key = entryKey, from = previous and previous.from or nil }
  return true
end

-- The item row a zone's Map view shows, choosing and remembering one where none is held: the
-- player's pick while they stay on the page, and on an arrival (fromKey, the page they came from,
-- which the window reads off its trail) the item they came from and the source the zone key or the
-- Here tab picked (ViewModel.ZonePick). An arrival that names nothing in the list keeps an earlier
-- pick. Builds the list where it is not built yet, which is only ever the Map view's own draw.
function ViewModel.ZoneItemPick(rootKey, opts, fromKey)
  local list = ViewModel.ZoneItemList(rootKey, opts)
  if not list then
    return nil
  end
  -- Brief M15: an item a Sources row asked this zone to open on.
  local arrival = ViewModel.TakeZoneArrival(rootKey, list, fromKey)
  if arrival then
    return arrival
  end
  local held = ViewModel.zoneItemPicks[rootKey]
  local heldEntry = held and list.byKey[held.key] or nil
  if heldEntry and (fromKey == nil or held.from == fromKey) then
    return heldEntry
  end
  local source = ViewModel.ZonePick(rootKey)
  local prefer = (type(source) == "table" and source.item) or fromKey
  local entry, named = ViewModel.ResolveZoneItem(list, source, prefer)
  -- Brief Z2 (2026-09-30): the column opens with every group closed, so an arrival that names
  -- nothing in the list keeps an earlier pick or picks nothing, rather than the first row.
  if not named then
    entry = heldEntry
  end
  if entry then
    ViewModel.zoneItemPicks[rootKey] = { key = entry.key, from = fromKey or (held and held.from) or nil }
  end
  return entry
end

-- The item row a zone's map pins, read without building anything: the held pick out of the last
-- list built for the root, or nil where the Map view's list has not been built. UI/Map.lua asks it.
function ViewModel.HeldZoneItem(rootKey)
  local held = type(rootKey) == "string" and ViewModel.zoneItemPicks[rootKey] or nil
  local cached = type(rootKey) == "string" and zoneItemCache[rootKey] or nil
  if not held or not cached then
    return nil
  end
  return cached.list.byKey[held.key]
end

-- Brief M15: a placed object guess (Core/GuessSources.lua specific type 6) in a zone's item column.
-- The Here tab is built from Classic Era rows, which never hold an item new in Forever, so a library
-- book's page opening its zone found nothing to select. The book is filed under the group a Classic
-- Era chest's item is ("Found here"), one source per spot in this zone, pinned at the object's own
-- coordinates, and its count reads as the Predicted word its Sources row wears.
ViewModel.PLACED_GROUP = "Found in"

--- The placed object guesses standing in a zone root's area (R:PlacedItemsIn), or an empty list.
--- The reader answers nothing while either Show predicted data or Show guessed sources is off, and
--- a list built with predicted data hidden (opts.showPredicted false) asks it nothing.
function ViewModel.PlacedZoneItems(rootKey, opts)
  local reader = ItemTree.guessSources
  local kind, areaId = Graph.Parse(rootKey)
  if kind ~= "zone" or type(reader) ~= "table" or type(reader.PlacedItemsIn) ~= "function" then
    return {}
  end
  if type(opts) == "table" and opts.showPredicted == false then
    return {}
  end
  local ok, placed = pcall(reader.PlacedItemsIn, reader, areaId)
  return ok and type(placed) == "table" and placed or {}
end

--- Adds placed object items ({ { item, spots = { { objectName, area, x, y } } } }) to a zone item
--- list in place: into its Found here group, made where the list has none at that group's place in
--- the zone's order. A source is { kind = "object", name, placed = true, area, x, y }, named "Object"
--- where the object ships unnamed. Answers the list. Pure over Graph's names.
function ViewModel.AddPlacedZoneItems(list, placed)
  if type(list) ~= "table" or type(list.groups) ~= "table" or type(placed) ~= "table" or #placed == 0 then
    return list
  end
  local groupKey = ViewModel.PLACED_GROUP
  local groupId = GROUP_IDS[groupKey]
  local group = nil
  for _, held in ipairs(list.groups) do
    if held.id == groupId then
      group = held
      break
    end
  end
  if not group then
    group = {
      id = groupId,
      key = groupKey,
      label = L[ZONE_WORDS[groupKey] or groupKey],
      icon = ViewModel.GroupIcon(groupKey),
      items = {},
    }
    local order, at = ZONE_ORDER[groupKey] or 200, #list.groups + 1
    for index, held in ipairs(list.groups) do
      if (ZONE_ORDER[held.key] or 200) > order then
        at = index
        break
      end
    end
    table.insert(list.groups, at, group)
  end
  list.byKey = list.byKey or {}
  for _, found in ipairs(placed) do
    local target = type(found) == "table" and type(found.item) == "number" and Graph.Key("item", found.item) or nil
    if target then
      local key = tostring(groupId) .. "/" .. target
      local entry = list.byKey[key]
      if not entry then
        local node = Graph.Node(target) or EMPTY
        entry = {
          key = key,
          group = groupId,
          item = target,
          itemId = found.item,
          name = node.name or Graph.Name(target) or target,
          quality = node.quality,
          icon = node.icon,
          undiscovered = node.undiscovered,
          discovered = node.discovered,
          sources = {},
          historical = false,
          predicted = true,
        }
        group.items[#group.items + 1] = entry
        list.byKey[key] = entry
        list.total = (list.total or 0) + 1
      end
      for _, spot in ipairs(type(found.spots) == "table" and found.spots or EMPTY) do
        local name = spot.objectName
        if type(name) ~= "string" or name == "" then
          name = L["Object"]
        end
        entry.sources[#entry.sources + 1] =
          { kind = "object", name = name, placed = true, area = spot.area, x = spot.x, y = spot.y }
      end
      entry.count = #entry.sources
      if entry.predicted then
        entry.countText = L["Predicted"]
      else
        entry.countText = ViewModel.ZoneSourceCount(groupId, entry.count)
      end
    end
  end
  table.sort(group.items, function(a, b)
    local left, right = string.lower(tostring(a.name)), string.lower(tostring(b.name))
    if left ~= right then
      return left < right
    end
    return (tonumber(a.itemId) or 0) < (tonumber(b.itemId) or 0)
  end)
  return list
end

-- Brief M15: the item each zone root is to open on next, by root key, set by a Sources row's click
-- (ViewModel.ArriveOnZoneItem) and taken by the very next ViewModel.ZoneItemPick. Nothing else is
-- kept, so the zone page afterwards is any zone page.
ViewModel.zoneItemArrivals = {}

--- Asks a zone root's Map view to open on one item (an item key). Answers whether it was kept.
function ViewModel.ArriveOnZoneItem(rootKey, itemKey)
  if type(rootKey) ~= "string" or Graph.Kind(rootKey) ~= "zone" or type(itemKey) ~= "string" then
    return false
  end
  ViewModel.zoneItemArrivals[rootKey] = itemKey
  return true
end

-- Whether a zone item row carries a placed object source.
local function hasPlacedSource(entry)
  for _, source in ipairs(entry.sources or EMPTY) do
    if type(source) == "table" and source.placed == true then
      return true
    end
  end
  return false
end

--- The arrival asked for a zone root, taken (so it counts once): the list's row of that item that
--- carries a placed object (the Found here row the Sources row stands for), else its first row, held
--- as the pick; nil where none was asked or the list holds no row of it.
function ViewModel.TakeZoneArrival(rootKey, list, fromKey)
  local itemKey = type(rootKey) == "string" and ViewModel.zoneItemArrivals[rootKey] or nil
  if not itemKey then
    return nil
  end
  ViewModel.zoneItemArrivals[rootKey] = nil
  local first, placed = nil, nil
  for _, group in ipairs(type(list) == "table" and list.groups or EMPTY) do
    for _, entry in ipairs(group.items or EMPTY) do
      if entry.item == itemKey then
        first = first or entry
        if not placed and hasPlacedSource(entry) then
          placed = entry
        end
      end
    end
  end
  local entry = placed or first
  if entry then
    ViewModel.zoneItemPicks[rootKey] = { key = entry.key, from = fromKey }
  end
  return entry
end

--------------------------------------------------------------------------------
-- A quest root (brief Q8)
--------------------------------------------------------------------------------

-- A quest's page has two tabs: "Quest", the categories below in the standard category and row
-- lists, and "Map", the recorded places and the client's objective mark. A quest is not made of
-- anything and is not used for anything, so the four item tabs were four questions nobody asks of
-- one; the owner opened The Criminal Element (92517) onto an empty Sources tab and read the item
-- wording over the dragon. The view key is this file's own: Core/Edges.lua gives it no direction,
-- so ViewKey, New, ViewCounts and Categories name it where they need to.
ViewModel.QUEST_VIEW = "quest"
ViewModel.QUEST_VIEWS = { ViewModel.QUEST_VIEW, Edges.MAP }

-- The categories a quest's tab holds, in the order they are drawn: what it hands over, who gives
-- it, what starts it, who takes it back, what it asks for, and what the log says is left to do.
local QUEST_GROUPS = {
  ["Rewards"] = { id = "questrewards", order = 10 },
  -- Brief IW1 (the owner's ruling "2B" of 2026-10-22): the items the quest hands the player, after what it
  -- hands back and before who gives it.
  ["Provided items"] = { id = "questprovided", order = 15 },
  ["Given by"] = { id = "questgivenby", order = 20 },
  ["Started by"] = { id = "queststartedby", order = 25 },
  -- Brief QI2 (the owner, 2026-10-23): who takes the quest back wears the client's turn in "?", the
  -- way the client marks an NPC with a quest to hand in; every other category keeps the quest "!".
  ["Turned in to"] = { id = "questturnedin", order = 30, icon = "CAT_QUEST_TURNIN" },
  ["Requires"] = { id = "questrequires", order = 35 },
  ["Objectives"] = { id = "questobjectives", order = 40 },
  -- Brief GF5: the quests before and after this one, where the predicted facts state them.
  ["Previous quest"] = { id = "questprevious", order = 45 },
  ["Next quest"] = { id = "questnext", order = 50 },
}

-- The graph edges a quest's tab keeps, by type name, each with the category it is filed under and
-- the direction it walks. Everything else the graph says about a quest node is not a fact about
-- the quest (an item's QUEST_REWARD edge walks the other way).
local QUEST_GRAPH_TYPES = {
  QUEST_REWARDS = { group = "Rewards", direction = "down" },
  QUEST_STARTED_BY = { group = "Started by", direction = "up" },
  QUEST_REQUIRES = { group = "Requires", direction = "up" },
}

-- The type column word of a reward row the player picks between. Brief QV3 (owner QA item 272, the
-- owner 2026-10-18: "I think nothing for fixed and keep choice when there is a choice"): a reward every
-- player gets says no word at all, in the column or on its hover: QUEST_FIXED is the empty word (it
-- read "Fixed", which looked like "bug fixed").
ViewModel.QUEST_CHOICE = "Choice"
ViewModel.QUEST_FIXED = ""

-- What the client knows about one quest, installed by UI/InfoPanel.lua (its client side) as
-- function(questId, mapIds) -> live table or nil. Core never calls the client itself: this is the
-- seam, and a load with no UI (the specs, the harness) answers nothing.
ViewModel.questReader = nil

-- The reader's answers, one per quest id for the session: { [questId] = live or false }. Every
-- client call a quest page makes is paid once per quest per session and again only after
-- ViewModel.DropQuestLive, which UI/InfoPanel.lua calls when the quest log says that quest moved.
ViewModel.questLive = {}

-- How many times the reader has been asked, which is what a spec reads back rather than timing.
ViewModel.questReads = 0

-- Forgets what the client said about one quest, or about every quest when questId is nil, and the
-- tab count worked out from it.
function ViewModel.DropQuestLive(questId)
  if questId == nil then
    ViewModel.questLive = {}
    for key in pairs(countCache) do
      if Graph.Kind(key) == "quest" then
        countCache[key] = nil
      end
    end
    return
  end
  ViewModel.questLive[questId] = nil
  if type(questId) == "number" then
    countCache[Graph.Key("quest", questId)] = nil
  end
end

-- The player's own records for one quest (Core/Collector.lua C:QuestNpcs), or nil.
function ViewModel.QuestRecords(questId)
  local collector = ItemTree.collector
  if type(collector) ~= "table" or type(collector.QuestNpcs) ~= "function" then
    return nil
  end
  local ok, records = pcall(collector.QuestNpcs, collector, questId)
  if ok and type(records) == "table" then
    return records
  end
  return nil
end

-- Brief BQ14 follow up: the demo state's quests over the client's answer (Core/Demo.lua
-- Demo.LiveQuest), never held, so the pretend quest's log and progress reach the quest page.
function ViewModel.DemoQuest(questId, live)
  local demo = ItemTree.Demo
  if type(demo) == "table" and type(demo.LiveQuest) == "function" then
    local ok, over = pcall(demo.LiveQuest, questId, live)
    if ok then
      return over
    end
  end
  return live
end

-- What the client knows about one quest, asked once per quest per session. mapIds are the maps
-- the player's own records name, which the reader names as well, so the page asks nothing twice.
-- A client title is put on the graph where nothing else names the quest, so the header, the
-- breadcrumb and the recently viewed list all read it.
function ViewModel.QuestLive(questId)
  if type(questId) ~= "number" then
    return nil
  end
  local held = ViewModel.questLive[questId]
  if held ~= nil then
    return ViewModel.DemoQuest(questId, held or nil)
  end
  local reader = ViewModel.questReader
  local live = nil
  if type(reader) == "function" then
    local mapIds = {}
    local records = ViewModel.QuestRecords(questId)
    for _, kind in ipairs({ "give", "end" }) do
      local record = type(records) == "table" and records[kind] or nil
      if type(record) == "table" and type(record.mapId) == "number" then
        mapIds[#mapIds + 1] = record.mapId
      end
    end
    ViewModel.questReads = ViewModel.questReads + 1
    local ok, answer = pcall(reader, questId, mapIds)
    if ok and type(answer) == "table" then
      live = answer
    end
  end
  ViewModel.questLive[questId] = live or false
  if live and type(live.title) == "string" and live.title ~= "" then
    local key = Graph.Key("quest", questId)
    -- Brief GF5: the client's title also replaces a predicted one the namer put there first.
    local named = Graph.Name(key)
    if named == nil or named == ViewModel.PredictedTitle(questId) then
      Graph.SetName(key, live.title)
    end
  end
  return ViewModel.DemoQuest(questId, live)
end

-- The rewards the shipped QuestRewards table (Classic Era's quest_template rows) states for one
-- quest: { fixed = { itemId, ... }, choice = { itemId, ... } }, or nil where it has no entry.
function ViewModel.QuestShipped(questId)
  if type(questId) ~= "number" or type(Data) ~= "table" or type(Data.Get) ~= "function" then
    return nil
  end
  local ok, rewards = pcall(Data.Get, Data, "QuestRewards")
  local entry = ok and type(rewards) == "table" and rewards[questId] or nil
  if type(entry) ~= "table" then
    return nil
  end
  return {
    fixed = type(entry[1]) == "table" and entry[1] or EMPTY,
    choice = type(entry[2]) == "table" and entry[2] or EMPTY,
  }
end

-- Who Classic Era says gives and takes back each quest, read the other way round out of the
-- shipped table's qg (brief N3 keys it by the NPC's name). Built once per session, on the first
-- quest page opened with predicted data shown: one pass over qg, with no client call. Keyed by
-- quest id, { give = { nameIndex, ... }, ["end"] = { nameIndex, ... } }.
local eraQuestNpcIndex = nil

-- Brief RB4: check, where given, is called once per name (Data.SliceCheck), so the login slicer can
-- carry the pass over frames; about 17 ms over the shipped 1.60.1.70425 data offline, which a trainer
-- page's predicted quests (the owner's "tree 14 ms" on 5117) and the first quest page paid.
-- Brief EO1: a world object's name (og) is held NEGATIVE in the same lists, so one quest's givers are
-- one list; the creatures come first, each run by its name index.
local function eraNpcOrder(a, b)
  if (a > 0) ~= (b > 0) then
    return a > 0
  end
  return math.abs(a) < math.abs(b)
end

local function buildEraQuestNpcIndex(check)
  local index = {}
  local era = ItemTree.eraSources
  local module = ItemTree.EraSources
  local source = type(era) == "table" and type(era.Table) == "function" and era:Table() or nil
  if type(source) ~= "table" or type(module) ~= "table" or type(module.QuestsGiven) ~= "function" then
    return index
  end
  -- qg's creature and vendor names, then (brief EO1) og's world object names, signed -1.
  for _, part in ipairs({ { "qg", 1 }, { "og", -1 } }) do
    local givers = source[part[1]]
    for nameIndex in pairs(type(givers) == "table" and givers or EMPTY) do
      if check then
        check()
      end
      local ok, given = pcall(module.QuestsGiven, source, nameIndex, part[1])
      if ok and type(given) == "table" then
        for side, list in pairs({ give = given.starts, ["end"] = given.ends }) do
          for _, questId in ipairs(type(list) == "table" and list or EMPTY) do
            local byQuest = index[questId]
            if not byQuest then
              byQuest = {}
              index[questId] = byQuest
            end
            byQuest[side] = byQuest[side] or {}
            table.insert(byQuest[side], part[2] * nameIndex)
          end
        end
      end
    end
  end
  for _, byQuest in pairs(index) do
    for _, list in pairs(byQuest) do
      table.sort(list, eraNpcOrder)
    end
  end
  return index
end

-- Where a Classic Era giver stands and what it is titled (brief Q11b): the zone its pins mostly
-- stand in (EraSources.PinAreas, which reads the area digits and decodes no coordinate) with that
-- zone's id, and its title out of st. Each is nil where the table states none: a name with no pins
-- has no zone, and a zone this build does not name has no name. Brief EO1: object, a world object's
-- name, reads its pins out of op (EraSources.ObjectPinAreas) and has no title.
local function eraNpcPlace(era, module, source, nameIndex, object)
  local zone, areaId, title, areas = nil, nil, nil, nil
  local areasOf = type(module) == "table" and module[object and "ObjectPinAreas" or "PinAreas"] or nil
  if type(areasOf) == "function" and type(source) == "table" then
    local ok, answer = pcall(areasOf, source, nameIndex)
    areas = ok and type(answer) == "table" and answer or nil
    local first = areas and areas[1] or nil
    if type(first) == "table" and type(first.name) == "string" and first.name ~= "" then
      zone, areaId = first.name, tonumber(first.areaId)
    end
  end
  if not object and type(era) == "table" and type(era.Title) == "function" then
    local ok, named = pcall(era.Title, era, nameIndex)
    if ok and type(named) == "string" and named ~= "" then
      title = named
    end
  end
  return zone, areaId, title, areas
end

-- Brief EO1: one object name can stand for objects in several zones (13 of the 177 on 1.60.1.70450:
-- the "WANTED" boards of four zones, the Ironforge and Orgrimmar presents), and og says which name
-- gives a quest, not which of its objects. Such an object row takes the zone, among its own, that the
-- quest's creature giver or turn in stands in (the Tanaris "Wanted Poster" beside Gadgetzan's turn
-- in), and no zone where none of its zones is one of theirs, rather than the name's commonest zone,
-- which would put a Tanaris quest's poster in Elwynn Forest. held maps each such row to its areas.
-- Pure over the rows.
local function settleObjectZones(out, held)
  local npcAreas = {}
  for _, rows in pairs(out) do
    for _, row in ipairs(rows) do
      if not row.object and row.areaId ~= nil then
        npcAreas[row.areaId] = true
      end
    end
  end
  for row, areas in pairs(held) do
    row.zone, row.areaId = nil, nil
    for _, area in ipairs(areas) do
      if npcAreas[tonumber(area.areaId)] and type(area.name) == "string" and area.name ~= "" then
        row.zone, row.areaId = area.name, tonumber(area.areaId)
        break
      end
    end
  end
end

-- The Classic Era givers and turn ins of one quest as npc rows { key, name, zone, areaId, title,
-- era = true }, or nil. zone, areaId and title are each absent where the table states none.
-- Brief RB4: the builder on the table, called only to build, so /itprobe hitch can time a build
-- (its "quest givers index" phase) and never the lookups.
ViewModel.BuildEraQuestNpcIndex = buildEraQuestNpcIndex

-- Brief RB4: the index above, built now where it is not built yet, and answered: what the loading
-- screen's builds call (Core/Data.lua Data.PRELOAD_LOADING_SCREEN), and the login slicer where that
-- did not run (Data.SliceCheck carries it over frames). A caller that built it whole while the
-- slicer's pass was paused keeps its own.
function ViewModel.EraQuestNpcIndex()
  if not eraQuestNpcIndex then
    local index = ViewModel.BuildEraQuestNpcIndex(type(Data) == "table" and Data.SliceCheck or nil)
    if not eraQuestNpcIndex then
      eraQuestNpcIndex = index
    end
  end
  return eraQuestNpcIndex
end

function ViewModel.EraQuestNpcs(questId)
  if type(questId) ~= "number" then
    return nil
  end
  local byQuest = ViewModel.EraQuestNpcIndex()[questId]
  if not byQuest then
    return nil
  end
  local era = ItemTree.eraSources
  local module = ItemTree.EraSources
  local source = type(era) == "table" and type(era.Table) == "function" and era:Table() or nil
  local out = {}
  local spread = {}
  for side, list in pairs(byQuest) do
    out[side] = {}
    for _, signed in ipairs(list) do
      -- Brief EO1: a negative entry is a world object's name (og): its page is keyed by its object id
      -- (oi), its place is read off op, and it has no title.
      local object = signed < 0
      local nameIndex = math.abs(signed)
      -- Brief EK1: the giver's page, keyed by its creature id. A name with none has no page: it is
      -- still listed by its name, with no key, which the quest page draws as a line that opens
      -- nothing (ViewModel QuestFacts' requirement row, InfoPanel.QuestNpcRow).
      local key = nil
      local keyOf = type(module) == "table" and module[object and "ObjectKey" or "PageKey"] or nil
      if type(keyOf) == "function" then
        local okKey, answer = pcall(keyOf, source, nameIndex)
        key = okKey and type(answer) == "string" and answer or nil
      end
      local name = nil
      if key and type(era) == "table" and type(era.NameFor) == "function" then
        local ok, named = pcall(era.NameFor, era, key)
        name = ok and type(named) == "string" and named ~= "" and named or nil
      elseif not key and type(era) == "table" and type(era.NameAt) == "function" then
        local ok, named = pcall(era.NameAt, era, nameIndex)
        name = ok and type(named) == "string" and named ~= "" and named or nil
      end
      if key or name then
        local zone, areaId, title, areas = eraNpcPlace(era, module, source, nameIndex, object)
        out[side][#out[side] + 1] = {
          key = key,
          name = name or Graph.Name(key),
          zone = zone,
          areaId = areaId,
          title = title,
          era = true,
          -- Brief TV4: the name's place in the table, so ViewModel.Quest can read its one spot
          -- (ViewModel.WithEraSpots). No coordinates here: the list lookups call this over many quests.
          nameIndex = nameIndex,
          -- Brief EO1: a world object (og), the shape a predicted object giver's row has.
          object = object or nil,
        }
        if object and areas and #areas > 1 then
          spread[out[side][#out[side]]] = areas
        end
      end
    end
  end
  if next(spread) then
    settleObjectZones(out, spread)
  end
  return out
end

-- Drops the Classic Era index above (tests, or after swapping data modules).
function ViewModel.ResetQuestIndex()
  eraQuestNpcIndex = nil
end

-- One objective as the page words it: the client's own text where it gave one ("0/10 Highlands
-- Bandit slain"), with the count put in front where the text does not already carry it, or nil.
-- objective is { text, have, need, done }. Pure.
function ViewModel.ObjectiveText(objective)
  if type(objective) ~= "table" then
    return nil
  end
  local text = type(objective.text) == "string" and objective.text ~= "" and objective.text or nil
  local have, need = tonumber(objective.have), tonumber(objective.need)
  if text and need and need > 0 and not text:find("%d+%s*/%s*%d+") then
    return string.format(L["%d/%d %s"], math.floor(have or 0), math.floor(need), text)
  end
  return text
end

-- The zone a map id is, by name: what the client said for it where it was asked, or nil.
local function mapName(live, mapId)
  local names = type(live) == "table" and type(live.mapNames) == "table" and live.mapNames or EMPTY
  local name = type(mapId) == "number" and names[mapId] or nil
  if type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- One recorded NPC as the page's row: { key, npcId, name, mapId, x, y, zone, when }.
-- Brief QH1: the page a world object's id opens, the Classic Era object's page where the table names
-- it (Core/QuestsPredicted.lua ObjectKey), else the Forever object's own page, object:<id>.
-- Brief AQF1: name, where the record holds one, keeps a Forever id the table keys for another object
-- off that object's page (QuestsPredicted.ObjectKey).
local function objectKey(objectId, name)
  local predicted = ItemTree.QuestsPredicted
  if type(predicted) == "table" and type(predicted.ObjectKey) == "function" then
    local ok, key = pcall(predicted.ObjectKey, objectId, name)
    if ok and type(key) == "string" then
      return key
    end
  end
  return Graph.Key("object", objectId)
end
ViewModel.ObjectKey = objectKey

local function recordedNpc(record, live)
  if type(record) ~= "table" then
    return nil
  end
  local npcId = tonumber(record.npcId)
  -- Brief QH1: a world object that gave or took the quest, kept by its object id.
  local objectId = not npcId and tonumber(record.objectId) or nil
  local name = type(record.name) == "string" and record.name ~= "" and record.name or nil
  local key = npcId and Graph.Key("npc", npcId) or (objectId and objectKey(objectId, name)) or nil
  if not name and key then
    name = Graph.Name(key)
  end
  if not key and not name then
    return nil
  end
  return {
    key = key,
    npcId = npcId,
    objectId = objectId,
    object = objectId and true or nil,
    name = name,
    mapId = tonumber(record.mapId),
    x = tonumber(record.x),
    y = tonumber(record.y),
    zone = mapName(live, tonumber(record.mapId)),
    when = record.when,
  }
end

-- Brief AQF1 (the owner's QA item 377, round AQ step AQ3: "I can't click on the wanted poster"): a
-- giver or turn in of ours that names no page of its own takes the page of the Classic Era giver or
-- turn in of the SAME quest and side that bears the same name. Two kinds of row name no page: a record
-- with a name alone (the player's own record of an object from before brief QH1 kept an object's id,
-- "Wanted Poster", or a creature recorded without one), which the Quest tab drew as a plain line and
-- the side column as a name with no link, and an object whose Forever id the Classic Era table does not
-- key (object:<id>, a live object's key with nothing behind it). The quest's own Classic Era relation
-- (og for an object, qg for a creature) is what confirms the name, never the name alone, and only while
-- the predicted setting shows that relation. The row stays ours: its place, its confidence, no Classic
-- Era line under it; only its key moves. A row that already opens a page is left as it is.
local function sameName(a, b)
  return type(a) == "string" and type(b) == "string" and a ~= "" and a:lower() == b:lower()
end

local function wantsEraPage(row)
  if type(row) ~= "table" or row.era == true then
    return false
  end
  if row.key == nil then
    return type(row.name) == "string" and row.name ~= ""
  end
  if row.object ~= true then
    return false
  end
  local kind, id = Graph.Parse(row.key)
  return kind == "object" and type(id) == "number" and id > 0
end

-- The row with the Classic Era page of the same name in eraRows, a copy (the caller's tables are left
-- alone), or the row itself where none fits. Pure.
function ViewModel.WithEraPage(row, eraRows)
  if not wantsEraPage(row) or type(eraRows) ~= "table" then
    return row
  end
  for _, eraRow in ipairs(eraRows) do
    local fits = type(eraRow) == "table"
      and type(eraRow.key) == "string"
      and sameName(eraRow.name, row.name)
      and (row.object ~= true or eraRow.object == true)
    if fits then
      local joined = {}
      for field, value in pairs(row) do
        joined[field] = value
      end
      joined.key = eraRow.key
      joined.object = eraRow.object
      return joined
    end
  end
  return row
end

-- Everything known about one quest, merged out of what each part states. Pure: the caller hands
-- in every part, so a spec drives it with its own tables.
--
--   parts.live       the client's answer (UI/InfoPanel.lua's reader), or nil:
--                    { title, level, onQuest, completed, mapId, zone, zoneFrom, mapNames,
--                      objectives = { { text, have, need, done } },
--                      rewards = { { itemId, count, choice } }, poi = { mapId, x, y } }
--   parts.records    Core/Collector.lua C:QuestNpcs, { give, ["end"] }, or nil
--   parts.era        ViewModel.EraQuestNpcs, { give = rows, ["end"] = rows }, or nil
--   parts.shipped    ViewModel.QuestShipped, { fixed, choice }, or nil
--   parts.players    brief PS5: Core/PlayerSources.lua QuestFacts, { title, rewards, givers,
--                    enders }, or nil: what the shipped player module states, plain data that the
--                    predicted setting never hides
--   parts.handovers  brief IW1: ViewModel.QuestHandovers, what the records say the quest hands the
--                    player ({ { itemId, count, when, own, players } }), or nil: facts.provided
--   parts.eraProvided  brief NX1: ViewModel.EraQuestProvided, the item the Classic Era rows say the
--                    quest hands the player when it is taken ({ { itemId, count } }), or nil:
--                    facts.eraProvided, each item only where facts.provided does not name it
--   parts.cache      brief QB2: ViewModel.QuestCache, what the client's quest cache states:
--                    { seen, changed, rewards, choices }, or nil
--   parts.showPredicted  false leaves out every Classic Era part (era and shipped), but for the
--                    shipped rewards the quest cache confirmed, and every predicted part
--   parts.predicted  brief GF5: ViewModel.QuestPredicted, the predicted facts as rows, or nil. Its
--                    givers and turn ins join the lists only where nothing above names any, and the
--                    rest is facts.predicted (ViewModel.PredictedFacts)
--
-- Answers { questId, title, level, state ("log", "done" or nil), zone, mapId, zoneFrom, givers,
-- enders, objectives, rewards, rewardsFrom ("log", "players", "forever", "confirmed", "shipped" or
-- nil; a reward's own from is one of those or "classic"), poi, predicted (brief GF5), known }. A
-- giver or a turn in the player saw comes first, then every other one the player module states,
-- and Classic Era's only where neither states any; the log's rewards win over the player module's,
-- and those over the shipped table's; a fact nothing states is absent. A recorded NPC the player
-- module states too carries shipped = true (plain data, no check). known is whether anything at
-- all beyond a title is.
function ViewModel.QuestFacts(questId, parts)
  parts = type(parts) == "table" and parts or EMPTY
  local live = type(parts.live) == "table" and parts.live or EMPTY
  local predicted = parts.showPredicted ~= false
  local facts = { questId = questId, givers = {}, enders = {}, objectives = {}, rewards = {} }

  local players = type(parts.players) == "table" and parts.players or EMPTY
  -- Brief PV1 (the owner's QA item 375): the items the quest hands the player that a record of ours
  -- states, { { itemId, count, own } }. THE one place a record of ours wins on the quest page:
  -- ViewModel.PredictedFacts then names only the predicted items these do not. Brief IW1 wires brief
  -- QH1's recorded hand-overs in: parts.handovers (ViewModel.QuestHandovers, the player's own records
  -- first, then the ones the player module ships), each item once, the first record of it kept, only
  -- the items handed over at the accept or mid quest (ViewModel.ProvidedHandover); own = true where the
  -- player's own record states it. Then the player module's `provided` list, where one states it.
  facts.provided = {}
  local providedAt = {}
  local function addProvided(itemId, count, own)
    if itemId and itemId > 0 and itemId == math.floor(itemId) and not providedAt[itemId] then
      providedAt[itemId] = true
      count = tonumber(count)
      facts.provided[#facts.provided + 1] = {
        itemId = itemId,
        count = count and count >= 1 and math.floor(count) or 1,
        own = own or nil,
      }
    end
  end
  for _, entry in ipairs(type(parts.handovers) == "table" and parts.handovers or EMPTY) do
    if ViewModel.ProvidedHandover(entry) then
      addProvided(tonumber(entry.itemId), entry.count, entry.own == true)
    end
  end
  for _, row in ipairs(type(players.provided) == "table" and players.provided or EMPTY) do
    addProvided(type(row) == "table" and tonumber(row.itemId) or nil, type(row) == "table" and row.count or nil, false)
  end
  -- Brief NX1 (the owner's ruling "2A" of 2026-10-22): then the Classic Era rows' provided item (the
  -- table's qp, CMaNGOS SrcItemId), drawn under the Classic Era line like an Era giver, each item only
  -- where a record above does not name it. With the predicted setting off it is left out, as the Era
  -- givers are (ViewModel.Quest hands no parts.eraProvided then).
  facts.eraProvided = {}
  for _, row in ipairs(type(parts.eraProvided) == "table" and parts.eraProvided or EMPTY) do
    local itemId = type(row) == "table" and tonumber(row.itemId) or nil
    if itemId and itemId > 0 and itemId == math.floor(itemId) and not providedAt[itemId] then
      providedAt[itemId] = true
      local count = tonumber(row.count)
      facts.eraProvided[#facts.eraProvided + 1] = {
        itemId = itemId,
        count = count and count >= 1 and math.floor(count) or 1,
      }
    end
  end
  if type(live.title) == "string" and live.title ~= "" then
    facts.title = live.title
  elseif type(players.title) == "string" and players.title ~= "" then
    facts.title = players.title
  end
  if type(live.level) == "number" and live.level > 0 then
    facts.level = math.floor(live.level)
  end
  if live.onQuest == true then
    facts.state = "log"
  elseif live.completed == true then
    facts.state = "done"
  end
  if type(live.mapId) == "number" and live.mapId > 0 then
    facts.mapId = live.mapId
    facts.zoneFrom = live.zoneFrom
  end
  facts.zone = type(live.zone) == "string" and live.zone ~= "" and live.zone or mapName(live, facts.mapId)

  -- Who gives it and who takes it back: the player's own record first, Classic Era's otherwise.
  local records = type(parts.records) == "table" and parts.records or EMPTY
  local era = (predicted and type(parts.era) == "table") and parts.era or EMPTY
  local foretold = (predicted and type(parts.predicted) == "table") and parts.predicted or EMPTY
  local shippedNpcs = { give = players.givers, ["end"] = players.enders }
  for kind, list in pairs({ give = facts.givers, ["end"] = facts.enders }) do
    local own = recordedNpc(records[kind], live)
    local reported = type(shippedNpcs[kind]) == "table" and shippedNpcs[kind] or EMPTY
    if own then
      list[1] = own
    end
    for _, row in ipairs(reported) do
      local same = own
        and ((own.npcId ~= nil and own.npcId == row.npcId) or (own.objectId ~= nil and own.objectId == row.objectId))
      if same then
        own.shipped = true
        own.mapId = own.mapId or row.mapId
        own.zone = own.zone or row.zone
      else
        list[#list + 1] = row
      end
    end
    -- Brief AQF1: a row of ours that names no page opens the quest's Classic Era one of its name.
    for index, row in ipairs(list) do
      list[index] = ViewModel.WithEraPage(row, era[kind])
    end
    if #list == 0 then
      for _, row in ipairs(type(era[kind]) == "table" and era[kind] or EMPTY) do
        list[#list + 1] = row
      end
    end
    -- Brief GF5: the predicted givers and turn ins (ViewModel.QuestPredicted), only where nothing of
    -- ours names any: the player's own record, the player module and Classic Era all come first.
    if #list == 0 then
      for _, row in ipairs(type(foretold[kind]) == "table" and foretold[kind] or EMPTY) do
        list[#list + 1] = row
      end
    end
  end
  -- The zone the client did not name, from where the giver stood. Only a giver the player saw:
  -- a Classic Era giver's zone is on its own row, under the line every Era fact ends on, and is
  -- not stated as the quest's zone (brief Q11b). Brief GF5: nor is a predicted giver's.
  local first = facts.givers[1]
  if not facts.zone and first and first.zone and first.era ~= true and first.predicted ~= true then
    facts.zone = first.zone
  end

  -- What the log says is left to do, only while the quest is in it.
  if facts.state == "log" then
    for _, objective in ipairs(type(live.objectives) == "table" and live.objectives or EMPTY) do
      local text = ViewModel.ObjectiveText(objective)
      if text then
        -- Brief QV3 (owner QA item 268): and how many the log says it asks for, which the row draws
        -- as every quest page count is drawn ("x1"); none where the log states no number.
        local need = tonumber(objective.need)
        need = need and need >= 1 and math.floor(need) or nil
        facts.objectives[#facts.objectives + 1] = { text = text, done = objective.done == true, need = need }
      end
    end
  end

  -- What it hands over: the log's own list while the quest is in it, the shipped table otherwise.
  if facts.state == "log" then
    for _, reward in ipairs(type(live.rewards) == "table" and live.rewards or EMPTY) do
      local itemId = type(reward) == "table" and tonumber(reward.itemId) or nil
      if itemId then
        facts.rewards[#facts.rewards + 1] =
          { itemId = itemId, count = tonumber(reward.count), choice = reward.choice == true, from = "log" }
      end
    end
    if #facts.rewards > 0 then
      facts.rewardsFrom = "log"
    end
  end
  local shipped = parts.shipped
  -- Brief QB2: what the client's quest cache states (ViewModel.QuestCache). Forever's own lists,
  -- where it states them, are the rewards ("forever", client data), and each Classic Era reward
  -- they no longer name follows as "classic" (changed in Forever) while predicted data is shown. A
  -- quest whose Classic Era rewards the cache confirmed reads them as "confirmed", shown whatever
  -- the predicted setting, because they are no longer a prediction.
  local cache = type(parts.cache) == "table" and parts.cache or EMPTY
  if #facts.rewards == 0 and type(cache.rewards) == "table" then
    local listed = {}
    for _, pair in ipairs({ { cache.rewards, false }, { cache.choices, true } }) do
      for _, itemId in ipairs(type(pair[1]) == "table" and pair[1] or EMPTY) do
        if type(itemId) == "number" and not listed[itemId] then
          listed[itemId] = true
          facts.rewards[#facts.rewards + 1] = { itemId = itemId, choice = pair[2], from = "forever" }
        end
      end
    end
    if predicted and type(shipped) == "table" then
      for _, pair in ipairs({ { shipped.fixed, false }, { shipped.choice, true } }) do
        for _, itemId in ipairs(type(pair[1]) == "table" and pair[1] or EMPTY) do
          if type(itemId) == "number" and not listed[itemId] then
            listed[itemId] = true
            facts.rewards[#facts.rewards + 1] = { itemId = itemId, choice = pair[2], from = "classic" }
          end
        end
      end
    end
    facts.rewardsFrom = "forever"
  end
  -- The shipped table's lists: "confirmed" where the quest cache saw them as Classic Era's, ahead of
  -- the player module's; "shipped" (predicted) only where nothing else names any.
  local function addShipped(from)
    for _, pair in ipairs({ { shipped.fixed, false }, { shipped.choice, true } }) do
      for _, itemId in ipairs(type(pair[1]) == "table" and pair[1] or EMPTY) do
        if type(itemId) == "number" then
          facts.rewards[#facts.rewards + 1] = { itemId = itemId, choice = pair[2], from = from }
        end
      end
    end
    if #facts.rewards > 0 then
      facts.rewardsFrom = from
    end
  end
  if #facts.rewards == 0 and facts.rewardsFrom == nil and cache.seen == true and type(shipped) == "table" then
    addShipped("confirmed")
  end
  -- Brief PS5: the player module's rewards, plain data, where the log and the quest cache name none.
  if #facts.rewards == 0 and facts.rewardsFrom == nil then
    for _, itemId in ipairs(type(players.rewards) == "table" and players.rewards or EMPTY) do
      if type(itemId) == "number" then
        facts.rewards[#facts.rewards + 1] = { itemId = itemId, choice = false, from = "players" }
      end
    end
    if #facts.rewards > 0 then
      facts.rewardsFrom = "players"
    end
  end
  if #facts.rewards == 0 and facts.rewardsFrom == nil and predicted and type(shipped) == "table" then
    addShipped("shipped")
  end

  -- The client's objective mark, which is a place only while the quest is in the log.
  local poi = type(live.poi) == "table" and live.poi or nil
  if facts.state == "log" and poi and type(poi.mapId) == "number" and tonumber(poi.x) and tonumber(poi.y) then
    facts.poi = { mapId = poi.mapId, x = tonumber(poi.x), y = tonumber(poi.y), zone = mapName(live, poi.mapId) }
  end

  -- Brief GF5: the rest of the predicted facts, each only where nothing above states it.
  if foretold ~= EMPTY then
    facts.predicted = ViewModel.PredictedFacts(facts, foretold)
  end

  -- Brief NW1: the quest's hand kept how-to note (Core/Creatures.lua QuestNote), a community note
  -- rather than a prediction, so the predicted setting leaves it be.
  if type(parts.note) == "string" and parts.note ~= "" then
    facts.note = parts.note
  end

  facts.known = facts.note ~= nil
    or #facts.provided > 0
    or #facts.eraProvided > 0
    or facts.predicted ~= nil
    or facts.state ~= nil
    or facts.level ~= nil
    or facts.zone ~= nil
    or #facts.givers > 0
    or #facts.enders > 0
    or #facts.objectives > 0
    or #facts.rewards > 0
  return facts
end

-- Whether predicted data is shown under these options, the setting every Classic Era part of a
-- quest page follows. opts is the window's own; a caller that passes none reads the default.
local function questPredicted(opts)
  if type(opts) == "table" and opts.showPredicted ~= nil then
    return opts.showPredicted ~= false
  end
  return ViewModel.DEFAULTS.showPredicted ~= false
end

--- Brief TV4 (INV1's finding on Deputy Rainer, Riverpaw Gnoll Bounty 11, item 347): where a Classic
--- Era giver or turn in stands, as x, y in its zone's map percent, out of the creature's decoded
--- pins ({ area, x, y }, E:PinsOf): only where that zone holds exactly one pin for it, so a creature
--- that spawns in several places is never pinned to one of them. nil, nil otherwise. Pure.
function ViewModel.EraNpcSpot(pins, areaId)
  if type(pins) ~= "table" or areaId == nil then
    return nil, nil
  end
  local found = nil
  for _, pin in ipairs(pins) do
    if type(pin) == "table" and pin.area == areaId and tonumber(pin.x) and tonumber(pin.y) then
      if found then
        return nil, nil
      end
      found = pin
    end
  end
  if not found then
    return nil, nil
  end
  return tonumber(found.x), tonumber(found.y)
end

--- Brief TV4: the Classic Era givers and turn ins (ViewModel.EraQuestNpcs' answer) with x and y on
--- each row whose zone holds one pin for it (ViewModel.EraNpcSpot), so the quest page and its hover
--- read "Elwynn Forest 24.2, 74.4" rather than the zone alone. EraSources.PinAreas, where the rows
--- take their zone, decodes the area and never the place. The rows are the fresh ones EraQuestNpcs
--- built for this call; nil answers nil. Guarded: no reader leaves the rows as they were.
function ViewModel.WithEraSpots(era)
  local reader = ItemTree.eraSources
  if type(era) ~= "table" or type(reader) ~= "table" or type(reader.PinsOf) ~= "function" then
    return era
  end
  for _, list in pairs(era) do
    for _, row in ipairs(type(list) == "table" and list or EMPTY) do
      if type(row) == "table" and type(row.nameIndex) == "number" and row.areaId ~= nil and row.x == nil then
        -- Brief EO1: a world object's row reads its pins out of op (E:ObjectPinsOf), a creature's mp.
        local pinsOf = reader[row.object and "ObjectPinsOf" or "PinsOf"]
        local ok, pins = false, nil
        if type(pinsOf) == "function" then
          ok, pins = pcall(pinsOf, reader, row.nameIndex)
        end
        if ok then
          row.x, row.y = ViewModel.EraNpcSpot(pins, row.areaId)
        end
      end
    end
  end
  return era
end

--- Brief NX1 (the owner's ruling "2A" of 2026-10-22, the Classic Era provided items): the item the Classic
--- Era rows say a quest hands the player when it is taken (Core/EraSources.lua E:QuestProvided: the table's
--- qp, CMaNGOS quest_template.SrcItemId and SrcItemCount, less an item that starts the quest and a withheld
--- item whose details are not served), as { { itemId, count } }, or nil where none is. Builds the Classic
--- Era table, as the quest page's Era givers do (ViewModel.EraQuestNpcs). Guarded.
function ViewModel.EraQuestProvided(questId)
  local era = ItemTree.eraSources
  if type(questId) ~= "number" or type(era) ~= "table" or type(era.QuestProvided) ~= "function" then
    return nil
  end
  local ok, pairs_ = pcall(era.QuestProvided, era, questId)
  if not ok or type(pairs_) ~= "table" or pairs_[1] == nil then
    return nil
  end
  local out = {}
  for _, pair in ipairs(pairs_) do
    if type(pair) == "table" and type(pair[1]) == "number" then
      out[#out + 1] = { itemId = pair[1], count = pair[2] }
    end
  end
  return out[1] and out or nil
end

-- ViewModel.QuestFacts over every part this load can answer for one quest: the client (once per
-- session, ViewModel.QuestLive), the player's records, Classic Era's givers and the shipped
-- rewards. What UI/InfoPanel.lua, the Quest tab and UI/Map.lua all read, so the three agree.
function ViewModel.Quest(questId, opts)
  if type(questId) ~= "number" then
    return nil
  end
  local predicted = questPredicted(opts)
  local cache = ViewModel.QuestCache(questId)
  return ViewModel.QuestFacts(questId, {
    live = ViewModel.QuestLive(questId),
    records = ViewModel.QuestRecords(questId),
    -- Brief TV4: with each Classic Era row's one spot (ViewModel.WithEraSpots).
    era = predicted and ViewModel.WithEraSpots(ViewModel.EraQuestNpcs(questId)) or nil,
    shipped = (predicted or (cache and cache.seen)) and ViewModel.QuestShipped(questId) or nil,
    players = ViewModel.QuestPlayers(questId),
    -- Brief IW1: the recorded hand-overs, which the provided rows read before anything predicted.
    handovers = ViewModel.QuestHandovers(questId),
    -- Brief NX1: the Classic Era rows' provided item, after the records, under the predicted setting.
    eraProvided = predicted and ViewModel.EraQuestProvided(questId) or nil,
    cache = cache,
    -- Brief GF5: after the Classic Era givers, which build the table the predicted keys read.
    predicted = predicted and ViewModel.QuestPredicted(questId) or nil,
    showPredicted = predicted,
    note = ViewModel.QuestNote(questId),
  })
end

--- Brief NW1 (owner ruling B of 2026-10-19, QA item 283): a quest's hand kept how-to note
--- (Core/Creatures.lua QuestNote, which builds the Creatures module), or nil. Guarded.
function ViewModel.QuestNote(questId)
  local creatures = ItemTree.Creatures
  if type(questId) ~= "number" or type(creatures) ~= "table" or type(creatures.QuestNote) ~= "function" then
    return nil
  end
  local ok, note = pcall(creatures.QuestNote, questId)
  if ok and type(note) == "string" and note ~= "" then
    return note
  end
  return nil
end

--------------------------------------------------------------------------------
-- Brief GF5: the predicted quest facts (Core/QuestsPredicted.lua), below every fact of ours
--------------------------------------------------------------------------------

-- The word the Quest tab's type column gives each objective kind (Core/QuestsPredicted.lua KILL,
-- OBJECT, ITEM): the English key, and the player's words.
ViewModel.OBJECTIVE_TYPES = { [1] = "Kill", [2] = "Use", [3] = "Collect" }
ViewModel.OBJECTIVE_WORDS = { [1] = L["Kill"], [2] = L["Use"], [3] = L["Collect"] }

--- The predicted title of one quest (Core/QuestsPredicted.lua Title), or nil. Never loads the module.
function ViewModel.PredictedTitle(questId)
  return predictedCall("Title", questId, false)
end

--- What the predicted module states about one quest, as the rows the quest page draws, or nil
--- (Core/QuestsPredicted.lua Quest, which may load ItemTree_Data: a page asks):
---   { title, level, requiredLevel, side, uiMap, zone, money, xp,
---     give = { npc rows }, ["end"] = { npc rows },
---     rewards = { { itemId, choice } }, currency = { { id, amount } },
---     previous = { { questId, key } }, next = { { questId, key } },
---     objectives = { { kind, id, count, key } }, provided = { { itemId, count, key } } }
--- An npc row is ViewModel.QuestFacts' own shape, { key, name, zone, mapId, x, y, approx, object,
--- predicted = true }: the place is the first approximate cell where one ships (mapId, x, y), and
--- zone that map's name. title is there only where the graph names the quest by it, so a title of
--- ours or the client's never reads as predicted.
function ViewModel.QuestPredicted(questId)
  if type(questId) ~= "number" then
    return nil
  end
  local record = predictedCall("Quest", questId)
  if type(record) ~= "table" then
    return nil
  end
  local players = ItemTree.PlayerSources
  local zoneOf = type(players) == "table" and players.MapName or nil
  local function zoneName(map)
    if type(zoneOf) ~= "function" or type(map) ~= "number" then
      return nil
    end
    local ok, name = pcall(zoneOf, map)
    return ok and type(name) == "string" and name ~= "" and name or nil
  end
  local out = {
    level = record.level,
    requiredLevel = record.requiredLevel,
    side = record.side,
    uiMap = record.uiMap,
    zone = zoneName(record.uiMap),
    money = record.money,
    xp = record.xp,
    rewards = {},
    currency = {},
    previous = {},
    next = {},
    objectives = {},
    provided = {},
  }
  if record.title and Graph.Name(Graph.Key("quest", questId)) == record.title then
    out.title = record.title
  end
  for side, list in pairs({ give = record.givers, ["end"] = record.enders }) do
    local rows = {}
    for _, signed in ipairs(type(list) == "table" and list or EMPTY) do
      local key = predictedCall("KeyOf", signed)
      if key then
        local pins = predictedCall("PinsAt", predictedCall("Pins", signed) or EMPTY, nil, zoneOf) or EMPTY
        local spot = pins[1]
        -- A creature or an object nothing of ours names reads in the unnamed form ("Object 61934").
        local name = Graph.Name(key)
        local kind, id = Graph.Parse(key)
        if name == nil and kind and id > 0 then
          name = Graph.Fallback(kind, id)
        end
        rows[#rows + 1] = {
          key = key,
          name = name,
          zone = spot and spot.zone or nil,
          mapId = spot and spot.map or nil,
          x = spot and spot.x or nil,
          y = spot and spot.y or nil,
          approx = spot and true or nil,
          object = signed < 0 or nil,
          predicted = true,
        }
      end
    end
    out[side] = rows
  end
  for _, pair in ipairs({ { record.rewards, false }, { record.choices, true } }) do
    for _, itemId in ipairs(type(pair[1]) == "table" and pair[1] or EMPTY) do
      if type(itemId) == "number" and itemId > 0 then
        out.rewards[#out.rewards + 1] = { itemId = itemId, choice = pair[2] }
      end
    end
  end
  for _, entry in ipairs(type(record.currency) == "table" and record.currency or EMPTY) do
    out.currency[#out.currency + 1] = { id = entry.id, amount = entry.amount }
  end
  for _, side in ipairs({ "previous", "next" }) do
    for _, linked in ipairs(type(record[side]) == "table" and record[side] or EMPTY) do
      if type(linked) == "number" and linked > 0 then
        out[side][#out[side] + 1] = { questId = linked, key = Graph.Key("quest", linked) }
      end
    end
  end
  for _, objective in ipairs(type(record.objectives) == "table" and record.objectives or EMPTY) do
    local key = nil
    if objective.kind == 1 then
      key = predictedCall("CreatureKey", objective.id)
    elseif objective.kind == 2 then
      key = predictedCall("ObjectKey", objective.id)
    elseif objective.kind == 3 then
      key = Graph.Key("item", objective.id)
    end
    if key then
      out.objectives[#out.objectives + 1] =
        { kind = objective.kind, id = objective.id, count = objective.count, stated = objective.stated, key = key }
    end
  end
  -- Brief PV1: the items the quest hands the player at accept (QuestsPredicted.Provided).
  for _, entry in ipairs(type(record.provided) == "table" and record.provided or EMPTY) do
    if type(entry) == "table" and type(entry.id) == "number" and entry.id > 0 then
      out.provided[#out.provided + 1] = { itemId = entry.id, count = entry.count, key = Graph.Key("item", entry.id) }
    end
  end
  return out
end

--- The predicted facts a quest page draws beside what ViewModel.QuestFacts already holds, or nil
--- where none is left. Each fact only where nothing of ours states it (the shipped rows ruling: a
--- fact of ours wears no mark and always wins): the title and the level where facts has none, the
--- zone where facts names none, the objectives only while the quest is not in the log (whose own
--- lines are the truth), and the rewards not at all where the log or the client's quest cache states
--- them, and otherwise only the items facts.rewards does not already name. The required level,
--- side, currency, money, XP and the previous and next quests: nothing of ours states them on this
--- page. Brief PV1: the items the quest hands the player at accept, whatever the log says (it is no
--- progress), each only where facts.provided (a record of ours) does not name it. facts is
--- QuestFacts' answer so far; predicted is ViewModel.QuestPredicted's. Pure.
function ViewModel.PredictedFacts(facts, predicted)
  if type(facts) ~= "table" or type(predicted) ~= "table" then
    return nil
  end
  local out = { rewards = {}, currency = {}, previous = {}, next = {}, objectives = {}, provided = {} }
  local any = false
  if facts.title == nil and type(predicted.title) == "string" and predicted.title ~= "" then
    out.title = predicted.title
    any = true
  end
  if facts.level == nil and type(predicted.level) == "number" and predicted.level > 0 then
    out.level = predicted.level
    any = true
  end
  for _, field in ipairs({ "requiredLevel", "side", "money", "xp" }) do
    if type(predicted[field]) == "number" and predicted[field] > 0 then
      out[field] = predicted[field]
      any = true
    end
  end
  if facts.zone == nil and type(predicted.zone) == "string" and predicted.zone ~= "" then
    out.zone = predicted.zone
    out.mapId = predicted.uiMap
    any = true
  end
  local from = facts.rewardsFrom
  if from ~= "log" and from ~= "forever" and from ~= "confirmed" then
    local listed = {}
    for _, reward in ipairs(type(facts.rewards) == "table" and facts.rewards or EMPTY) do
      listed[reward.itemId] = true
    end
    for _, reward in ipairs(type(predicted.rewards) == "table" and predicted.rewards or EMPTY) do
      if type(reward.itemId) == "number" and not listed[reward.itemId] then
        listed[reward.itemId] = true
        out.rewards[#out.rewards + 1] = { itemId = reward.itemId, choice = reward.choice == true, from = "predicted" }
        any = true
      end
    end
  end
  for _, entry in ipairs(type(predicted.currency) == "table" and predicted.currency or EMPTY) do
    out.currency[#out.currency + 1] = entry
    any = true
  end
  for _, side in ipairs({ "previous", "next" }) do
    for _, linked in ipairs(type(predicted[side]) == "table" and predicted[side] or EMPTY) do
      out[side][#out[side] + 1] = linked
      any = true
    end
  end
  if facts.state ~= "log" then
    for _, objective in ipairs(type(predicted.objectives) == "table" and predicted.objectives or EMPTY) do
      out.objectives[#out.objectives + 1] = objective
      any = true
    end
  end
  local handed = {}
  for _, row in ipairs(type(facts.provided) == "table" and facts.provided or EMPTY) do
    handed[row.itemId] = true
  end
  -- Brief NX1: nor where the Classic Era rows name the item (the pipeline holds such a claim already).
  for _, row in ipairs(type(facts.eraProvided) == "table" and facts.eraProvided or EMPTY) do
    handed[row.itemId] = true
  end
  for _, row in ipairs(type(predicted.provided) == "table" and predicted.provided or EMPTY) do
    if type(row.itemId) == "number" and not handed[row.itemId] then
      handed[row.itemId] = true
      out.provided[#out.provided + 1] = row
      any = true
    end
  end
  if not any then
    return nil
  end
  return out
end

--- One predicted objective's line, "Kill 8 Kobold Vermin", "Collect 6 Linen Cloth" or "Use Wanted
--- Poster": the target's name from our data alone (Graph.Name), and the unnamed form ("Creature
--- 1234", Graph.Fallback) where nothing names it. nil for anything that is not an objective.
function ViewModel.ObjectiveLine(objective)
  if type(objective) ~= "table" or type(objective.key) ~= "string" then
    return nil
  end
  local name = Graph.Name(objective.key)
  if type(name) ~= "string" or name == "" then
    local kind, id = Graph.Parse(objective.key)
    name = kind and Graph.Fallback(kind, id) or objective.key
  end
  local count = math.floor(tonumber(objective.count) or 1)
  if objective.kind == 1 then
    return string.format(L["Kill %d %s"], count, name)
  elseif objective.kind == 3 then
    return string.format(L["Collect %d %s"], count, name)
  elseif objective.kind == 2 then
    if count > 1 then
      return string.format(L["Use %d %s"], count, name)
    end
    return string.format(L["Use %s"], name)
  end
  return nil
end

-- Brief QB2: what the client's quest cache states about one quest (Core/QuestFlags.lua over
-- Diff.quests): { seen = true where it confirmed the Classic Era rewards, changed = true where it
-- states others, rewards and choices = Forever's own lists where it states them }, or nil where it
-- states nothing. Two binary searches and a table read.
function ViewModel.QuestCache(questId)
  local flags = ItemTree.QuestFlags
  if type(questId) ~= "number" or type(flags) ~= "table" or type(flags.ForeverRewards) ~= "function" then
    return nil
  end
  local seen = flags.RewardsSeen(questId) == true
  local changed = flags.RewardsChanged(questId) == true
  local rewards, choices = flags.ForeverRewards(questId)
  if not seen and not changed and rewards == nil then
    return nil
  end
  return { seen = seen, changed = changed, rewards = rewards, choices = choices }
end

-- Brief PS5: what the shipped player module states about one quest (Core/PlayerSources.lua
-- QuestFacts), or nil with no module or nothing stated.
function ViewModel.QuestPlayers(questId)
  local module = ItemTree.PlayerSources
  if type(questId) ~= "number" or type(module) ~= "table" or type(module.QuestFacts) ~= "function" then
    return nil
  end
  local ok, facts = pcall(module.QuestFacts, questId)
  if ok and type(facts) == "table" then
    return facts
  end
  return nil
end

-- Brief IW1: the hand-over moments at which a recorded hand-over states a provided item of its quest,
-- Core/PlayerSources.lua PROVIDED_WHEN's (at the accept, and from an NPC while the quest is worked; one
-- handed over at the turn in is the next step's), this copy only where that module is not loaded.
ViewModel.PROVIDED_WHEN = { accept = true, quest = true }

--- Brief IW1: whether one hand-over entry (Core/PlayerSources.lua QuestHandovers' shape) states a
--- provided item of its quest (PlayerSources.ProvidedHandover, else ViewModel.PROVIDED_WHEN). Pure.
function ViewModel.ProvidedHandover(entry)
  local module = ItemTree.PlayerSources
  if type(module) == "table" and type(module.ProvidedHandover) == "function" then
    return module.ProvidedHandover(entry) == true
  end
  return type(entry) == "table" and ViewModel.PROVIDED_WHEN[entry.when] == true
end

--- Brief IW1 (QH1's hand-overs into PV1's seam): what the records say one quest hands the player, the
--- player's own records first and then the ones the player module ships (Core/PlayerSources.lua
--- QuestHandovers), or nil. Guarded.
function ViewModel.QuestHandovers(questId)
  local module = ItemTree.PlayerSources
  if type(questId) ~= "number" or type(module) ~= "table" or type(module.QuestHandovers) ~= "function" then
    return nil
  end
  local ok, list = pcall(module.QuestHandovers, questId)
  if ok and type(list) == "table" then
    return list
  end
  return nil
end

-- "Westfall 45.2, 61.0", the zone column of a giver's row: the zone and the place the player
-- stood, each left out where nothing states it. nil for neither. Pure.
function ViewModel.QuestPlaceText(zone, x, y)
  local coords = nil
  if tonumber(x) and tonumber(y) then
    coords = string.format("%.1f, %.1f", tonumber(x), tonumber(y))
  end
  if type(zone) ~= "string" or zone == "" then
    return coords
  end
  if not coords then
    return zone
  end
  return string.format(L["%s %s"], zone, coords)
end

-- One quest fact as the entry its category holds. An item or an NPC is an edge the rows draw the
-- standard way; an objective, and a giver with no creature behind it, is a line of text.
local function questEdge(edgeType, target, group, source, extra)
  local edge = { type = edgeType, target = target, group = L[group], questSource = source }
  for key, value in pairs(extra or EMPTY) do
    edge[key] = value
  end
  return edge
end

function VM:_QuestId()
  local kind, id = Graph.Parse(self.root)
  if kind == "quest" then
    return id
  end
  return nil
end

-- The categories of a quest's tab, from ViewModel.Quest and the quest node's own edges.
function VM:_QuestCategories()
  local questId = self:_QuestId()
  local facts = ViewModel.Quest(questId, self.opts)
  local groups, order = {}, {}
  local function add(label, entry)
    local group = groups[label]
    if not group then
      group = { key = label, label = L[label], entries = {}, serverSide = false }
      groups[label] = group
      order[#order + 1] = group
    end
    group.entries[#group.entries + 1] = entry
  end
  if not facts then
    return order
  end

  local T = Edges.Types
  local rewarded = {}
  for _, reward in ipairs(facts.rewards) do
    rewarded[reward.itemId] = true
    local fromLog = reward.from == "log"
    -- Brief PS5: a reward the player module states is plain data, neither checked nor Predicted.
    local reported = reward.from == "players"
    -- Brief QB2: one the client's quest cache states or confirmed is client data, with no mark; a
    -- Classic Era one it no longer names wears the Changed mark (rewardChanged).
    local cached = reward.from == "forever" or reward.from == "confirmed"
    local changed = reward.from == "classic"
    local era = not fromLog and not reported and not cached
    local confidence = Confidence.PREDICTED
    if fromLog then
      confidence = Confidence.VERIFIED
    elseif reported or cached then
      confidence = Confidence.MINED
    end
    local provenance = nil
    if reported then
      provenance = "player"
    elseif cached then
      provenance = CLIENT_PROVENANCE
    end
    add(
      "Rewards",
      questEdge(T.QUEST_REWARDS, Graph.Key("item", reward.itemId), "Rewards", {
        type = reward.choice and ViewModel.QUEST_CHOICE or ViewModel.QUEST_FIXED,
        historical = era,
      }, {
        quantity = (reward.count and reward.count > 1) and reward.count or nil,
        confidence = confidence,
        historical = era or nil,
        provenance = provenance,
        rewardChanged = changed or nil,
      })
    )
  end
  -- Brief GF5: the predicted rewards (ViewModel.PredictedFacts), after every reward of ours, each
  -- wearing the Predicted mark.
  local foretold = type(facts.predicted) == "table" and facts.predicted or EMPTY
  for _, reward in ipairs(foretold.rewards or EMPTY) do
    if not rewarded[reward.itemId] then
      rewarded[reward.itemId] = true
      add(
        "Rewards",
        questEdge(T.QUEST_REWARDS, Graph.Key("item", reward.itemId), "Rewards", {
          type = reward.choice and ViewModel.QUEST_CHOICE or ViewModel.QUEST_FIXED,
        }, { confidence = Confidence.PREDICTED })
      )
    end
  end

  -- Brief QI2: each side's fourth is the glyph a name with no page wears on its line, the quest "!"
  -- for a giver and the turn in "?" for whoever takes it back.
  local sides = {
    { "Given by", facts.givers, T.GIVES_QUEST, "CAT_QUEST" },
    { "Turned in to", facts.enders, T.TAKES_QUEST, "CAT_QUEST_TURNIN" },
  }
  for _, side in ipairs(sides) do
    for _, npc in ipairs(side[2]) do
      -- Brief GF5: an approximate place says its zone alone, never coordinates it does not know.
      local zone = ViewModel.QuestPlaceText(npc.zone, not npc.approx and npc.x or nil, not npc.approx and npc.y or nil)
      if npc.key then
        -- Brief PS5: a giver the player module states (alone, or beside the player's own record of
        -- it) is plain data: no check, one tooltip line.
        local reported = npc.players == true or npc.shipped == true
        local confidence = Confidence.VERIFIED
        if npc.era or npc.predicted then
          confidence = Confidence.PREDICTED
        elseif reported then
          confidence = Confidence.MINED
        end
        add(
          side[1],
          questEdge(side[3], npc.key, side[1], { zone = zone, historical = npc.era == true }, {
            confidence = confidence,
            provenance = reported and "player" or nil,
            historical = npc.era or nil,
            questZone = npc.zone,
            questAreaId = npc.areaId,
            -- Brief Q11b: "Nalpak <Disciple of Naralex>", the way an Era vendor's row reads.
            title = npc.title,
          })
        )
      elseif npc.name then
        add(side[1], { requirement = { label = npc.name, zone = zone, icon = side[4] } })
      end
    end
  end

  -- Brief PV1 (the owner's QA item 375): the items the quest hands the player (Making Do: Alexston's Reply
  -- x1), each a row that opens the item, the count beside it and no type word: a record of ours first
  -- (facts.provided: the player's own verified, one the player module ships plain with its "player"
  -- provenance, brief IW1), then the predicted ones under the Predicted mark (facts.predicted.provided,
  -- the items ours does not name). Brief IW1 (the owner's ruling "2B" of 2026-10-22): a category of their
  -- own, "Provided items" (QUEST_GROUPS: after Rewards, before Given by), never a row under the giver, so
  -- the item is no longer listed as a giver, and drawn whether or not a giver is known.
  -- Brief NX1 (the owner's ruling "2A" of 2026-10-22): between the two, the Classic Era rows' provided item
  -- (facts.eraProvided), marked as an Era giver is: Predicted, with the Classic Era line (historical).
  for _, list in ipairs({
    { facts.provided, Confidence.MINED },
    { facts.eraProvided, Confidence.PREDICTED, true },
    { foretold.provided, Confidence.PREDICTED },
  }) do
    for _, row in ipairs(list[1] or EMPTY) do
      if type(row.itemId) == "number" then
        local own = list[2] == Confidence.MINED and row.own == true
        local era = list[3] == true
        add(
          "Provided items",
          questEdge(
            T.QUEST_PROVIDED,
            Graph.Key("item", row.itemId),
            "Provided items",
            { type = "", historical = era or nil },
            {
              quantity = tonumber(row.count) or 1,
              confidence = own and Confidence.VERIFIED or list[2],
              provenance = list[2] == Confidence.MINED and not own and "player" or nil,
              historical = era or nil,
            }
          )
        )
      end
    end
  end

  for _, objective in ipairs(facts.objectives) do
    add(
      "Objectives",
      { requirement = { label = objective.text, done = objective.done, objective = true, quantity = objective.need } }
    )
  end
  -- Brief GF5: the predicted objectives, each a row that opens what it names (the creature, the
  -- object, the item), its kind in the type column and the count beside it; and the quests before
  -- and after this one. Each wears the Predicted mark.
  for _, objective in ipairs(foretold.objectives or EMPTY) do
    add(
      "Objectives",
      questEdge(T.QUEST_REQUIRES, objective.key, "Objectives", {
        type = ViewModel.OBJECTIVE_TYPES[objective.kind],
        typeLabel = ViewModel.OBJECTIVE_WORDS[objective.kind],
      }, {
        -- Brief QV3 (owner QA item 268, "Horrible Rootcore  Collect" with no count, where the item's
        -- own Used by row reads x1): every count the objective states, 1 included, as the item page
        -- draws it; none where the entry states none (QuestsPredicted.ObjectivesOf stated = false).
        quantity = objective.stated ~= false and tonumber(objective.count) or nil,
        confidence = Confidence.PREDICTED,
      })
    )
  end
  for _, side in ipairs({ { "Previous quest", foretold.previous }, { "Next quest", foretold.next } }) do
    for _, linked in ipairs(side[2] or EMPTY) do
      add(side[1], questEdge(T.QUEST_REQUIRES, linked.key, side[1], nil, { confidence = Confidence.PREDICTED }))
    end
  end

  -- The quest node's own edges: the curated table's, an installed source database's and Classic
  -- Era's, each in its category. A reward the list above already names is not named twice.
  for _, direction in ipairs({ Edges.DOWN, Edges.UP }) do
    for _, edge in ipairs(Graph.Children(self.root, direction, WALK_OPTS)) do
      local spec = type(edge.type) == "table" and QUEST_GRAPH_TYPES[edge.type.name] or nil
      if spec and spec.direction == direction then
        local kind, id = Graph.Parse(edge.target)
        local skip = spec.group == "Rewards" and kind == "item" and rewarded[id]
        if not skip then
          if spec.group == "Rewards" and kind == "item" then
            rewarded[id] = true
          end
          local choice = edge.choice == true or (type(edge.meta) == "table" and edge.meta.choice == true)
          local wrapped = setmetatable({
            group = L[spec.group],
            questSource = spec.group == "Rewards" and {
              type = choice and ViewModel.QUEST_CHOICE or ViewModel.QUEST_FIXED,
              historical = edge.historical == true,
            } or nil,
          }, { __index = edge })
          add(spec.group, wrapped)
        end
      end
    end
  end

  for _, group in ipairs(order) do
    local spec = QUEST_GROUPS[group.key]
    self:_FinishCategory(group)
    group.id = spec and spec.id or group.id
    group.icon = spec and spec.icon or "CAT_QUEST"
    group.order = spec and spec.order or 200
    -- A quest's page says where its rows came from on the rows themselves: a recorded giver is
    -- the player's own sighting and a log row is the client's, so neither wears a drop notice.
    -- Only a category that is Classic Era through and through says so above it.
    local allHistorical = #group.entries > 0
    for _, entry in ipairs(group.entries) do
      if entry.requirement or entry.historical ~= true then
        allHistorical = false
      end
    end
    group.notice = allHistorical and ViewModel.ERA_NOTICE or nil
  end
  table.sort(order, function(a, b)
    if a.order ~= b.order then
      return a.order < b.order
    end
    return a.label < b.label
  end)
  return order
end

-- One row of a quest's tab. Flat: a reward, a giver and an objective are each the answer, and
-- what a reward is used for is a question for the reward's own page, one click away.
function VM:_AppendQuestEntry(rows, parentKey, entry, depth)
  if entry.requirement then
    local requirement = entry.requirement
    local rowKey = parentKey .. "/q:" .. slug(requirement.label)
    if self.index[rowKey] then
      rowKey = rowKey .. "~" .. tostring(#rows)
    end
    self:_Push(rows, {
      key = rowKey,
      kind = "row",
      depth = depth,
      expanded = false,
      hasChildren = false,
      loop = false,
      capped = false,
      source = requirement.zone and { type = "", zone = requirement.zone } or nil,
      node = {
        key = "q:" .. slug(requirement.label),
        kind = "requirement",
        type = "skill",
        name = requirement.label,
        -- Brief QI2: a turn in with no page wears the turn in "?" its side names; any other line the "!".
        icon = requirement.icon or "CAT_QUEST",
        badges = {},
        done = requirement.done or nil,
        -- Brief QV3: a log objective's stated count, drawn in the quantity column ("x1").
        quantity = requirement.quantity,
      },
    })
    return
  end
  local node = Graph.Node(entry.target)
  if not node then
    return
  end
  local rowKey = parentKey .. "/" .. entry.target
  if self.index[rowKey] then
    rowKey = rowKey .. "~" .. tostring(#rows)
  end
  local source = nil
  if type(entry.questSource) == "table" then
    source = {
      type = entry.questSource.type or "",
      -- Brief GF5: an objective's kind ("Kill"), already in the player's words.
      typeLabel = entry.questSource.typeLabel,
      zone = entry.questSource.zone,
      historical = entry.questSource.historical == true or nil,
      -- Brief QV2 (owner QA 2026-10-18 item 266, "No qty for the woolcloth objective of mulgore"): the
      -- count the quest states (60 Wool Cloth for 99196, five of a reward). A source row has no
      -- quantity column (UI/Tree.lua spends it on the source's facts), so the count travels on the
      -- source and Tree.SourceText draws it where a rate would be, "x60".
      quantity = entry.quantity,
      quantityMax = entry.quantityMax,
    }
  end
  local zoneLink = nil
  local zoneName = entry.questZone
  if type(zoneName) == "string" and zoneName ~= "" then
    local areaId = tonumber(entry.questAreaId) or eraCall("AreaIdOf", zoneName)
    if type(areaId) == "number" then
      zoneLink = { key = Graph.Key("zone", areaId), name = zoneName }
    end
  end
  -- A count on a quest's row is the number the quest states (two of a reward, ten of what the turn
  -- in asks for), never a tally of sightings, whatever the edge's footing.
  local decorated = self:_DecorateNode(node, entry)
  decorated.seen = entry.seen
  decorated.quantity = entry.quantity
  decorated.quantityMax = entry.quantityMax
  -- Brief QI2: a quest giving object that takes this quest back (Buzzbox 411 on 1001) wears the turn
  -- in "?" in place of the "!" ViewModel.NodeIcon gives it; on Given by it keeps the "!". A creature
  -- keeps its own portrait on either side.
  if decorated.iconAsset == "CAT_QUEST" and entry.type == Edges.Types.TAKES_QUEST then
    decorated.iconAsset = "CAT_QUEST_TURNIN"
  end
  self:_Push(rows, {
    key = rowKey,
    kind = "row",
    depth = depth,
    expanded = false,
    hasChildren = false,
    loop = false,
    capped = false,
    edge = entry,
    source = source,
    node = decorated,
    zoneLink = zoneLink,
  })
end

--------------------------------------------------------------------------------
-- A trainer's Teaches lines (briefs NP1, TR1 and TR2)
--------------------------------------------------------------------------------

-- Brief TR2: the owner's ruling (2026-10-11, QA item 128): the rank rows stay, labelled; "only if
-- the data cannot name them, a plain line item 'Teaches Mining up to Artisan' is ADDED under the
-- Teaches group". So for each profession ViewModel.TrainerProfessions names, a line goes into the
-- "Teaches" group where no rank spell row of that profession is among the tab's rows, and its top
-- rank is known (the Creatures data's tk, a title's rank word) or the tab has no row of that
-- profession at all ("Teaches Mining", a trainer visit that named only the profession). A Classic
-- Era trainer whose rank spells are listed gets none: its rows already say it. Every line is a
-- requirement shaped entry, so nothing walks, counts sources or wears a drop notice of its own.
function VM:_TeachesLines(groups, order)
  local professions = ViewModel.TrainerProfessions(self.root)
  if #professions == 0 then
    return
  end
  local ranked, rowed = {}, {}
  for _, group in ipairs(order) do
    for _, entry in ipairs(group.entries) do
      local kind, id = Graph.Parse(entry.target)
      local line = kind == "spell" and ViewModel.RankSpell(id) or nil
      if line then
        ranked[line] = true
        rowed[line] = true
      elseif tonumber(entry.skillLine) then
        rowed[tonumber(entry.skillLine)] = true
      end
    end
  end
  local linked = ViewModel.TrainsLinked()
  local groupKey = groupKeyOf(L["Teaches"])
  local group = groups[groupKey]
  for _, profession in ipairs(professions) do
    local line = profession.line
    if not ranked[line] and (profession.rank ~= nil or not rowed[line]) then
      if not group then
        group = { key = groupKey, label = L[groupKey], entries = {}, serverSide = false }
        groups[groupKey] = group
        order[#order + 1] = group
      end
      group.entries[#group.entries + 1] = {
        requirement = {
          label = ViewModel.TrainsLabel(profession),
          rank = profession.rank,
          line = line,
          from = profession.from,
          linked = linked,
          trains = true,
        },
      }
    end
  end
end

-- One Teaches line of a trainer (a Trains row before brief TR2): its words and the profession's
-- glyph. Where the Professions tab can take it the row's node is ViewModel.ProfessionKey, which the
-- tree's click hands to the window (UI/Frame.lua Frame.Open opens the tab on that line); otherwise
-- its key is no node key at all, so the click does nothing and the row reads as the plain words it is.
function VM:_AppendTrainsEntry(rows, parentKey, entry, depth)
  local requirement = type(entry) == "table" and entry.requirement or nil
  if type(requirement) ~= "table" then
    return
  end
  local line = requirement.line
  local nodeKey = requirement.linked and ViewModel.ProfessionKey(line) or ("trains/" .. tostring(line))
  local rowKey = parentKey .. "/" .. nodeKey
  if self.index[rowKey] then
    rowKey = rowKey .. "~" .. tostring(#rows)
  end
  self:_Push(rows, {
    key = rowKey,
    kind = "row",
    depth = depth,
    expanded = false,
    hasChildren = false,
    loop = false,
    capped = false,
    trains = { line = line, linked = requirement.linked == true, from = requirement.from, rank = requirement.rank },
    node = {
      key = nodeKey,
      kind = "requirement",
      type = "skill",
      name = requirement.label,
      icon = ViewModel.SKILL_ICONS[line] or "CAT_TRAINER",
      badges = {},
    },
  })
end

return ViewModel
