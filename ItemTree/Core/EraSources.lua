-- Historical Classic Era sources: the shipped table, turned into graph edges and marked as
-- history. Pure Lua, no WoW API. Loaded as: local _, ItemTree = ...
--
-- No client build states where an item comes from. Drops, vendors and quest turn ins are all
-- server side, so the compiled data carries none of them and the Sources view fills itself in
-- from what the player sees. ItemTree_Data/Data/generated/EraSources.lua is the one exception:
-- a facts only table derived from a historical snapshot of Classic Era, shipped so an item with
-- no first hand source at least has a lead. ../ItemTree-Data/docs/era-sources.md is the whole story,
-- and its "The record shape" section is the contract this file is written against.
--
-- It is NOT a fact about the client the player is running, and nothing here lets it read as
-- one. Every edge this file emits is:
--   * Confidence.PREDICTED, so it wears the Predicted badge, follows the "Show predicted data"
--     setting and disappears with it, counts and tab label and all;
--   * stamped with the provenance Core/Sources.lua draws as "Classic Era";
--   * stamped with the basis Confidence.BASIS_ERA, so the badge's own tooltip says what the
--     prediction is based on rather than claiming the disenchant rule's wording;
--   * carrying its chance as a historical figure, never as a rate this client measured.
--
-- It is also never a "ready provider". The table covers Classic Era and this build has 4,900
-- items Classic Era never had, so a view full of Era rows is still a view waiting on a source
-- database: this file registers itself straight with Core/Graph.lua and is not an adapter in
-- Providers/Registry.lua, so Tree.ProviderOffers, the quiet hint, the designed empty block and
-- the settings page's Source databases rows carry on exactly as they did.
--
-- An item is a LIST of rows, already in the order to draw them, and the list is never sorted
-- here: file order IS draw order. Thirteen categories, from a boss drop to the item a container
-- gives up, and a category that has more sources than the pipeline would list ends in a summary
-- row that says how many the rows above it left out.
--
-- Six more tables came with the data of 2026-09-20, and every one of them is read only when
-- something asks:
--   qt   the title of a quest a quest only row names in q, for the quests no quest row in the
--        table names. Before it, 934 of the 1,526 rows that name their quest still said the
--        shorter "only while on a quest".
--   ck   what KIND of creature a name is, packed into one integer: the type, the beast family
--        and the level band. E:KindOf reads it. This file chooses no icon; the interface does.
--   cd   the CreatureDisplayInfo id the client draws that name's portrait from, one plain
--        integer per name and no art of any kind. E:DisplayOf reads it, and every id in it was
--        checked against this build's own table before it shipped.
--   mp   where a creature name is FOUND, as map pins: at most six points per name per area,
--        each a percentage of that area's own zone map. One packed STRING per name, decoded
--        only when E:PinsOf is called, so building the tree never touches one.
--   op   the same for an OBJECT name (brief D7): a herb, a vein, a fishing pool or a chest, in mp's
--        exact packing. Its own table because one string can name a creature and an object both.
--        E:ObjectPinsOf reads it, and E:ObjectMap asks only whether a name has any.
--   ok   the category an op name is filed under (8 herb, 9 vein, 10 fishing pool, 11 chest), so an
--        object's page can say what it is without decoding a pin. EraSources.ObjectKind reads it.
--   qg   the quests a creature or vendor NAME starts and ends (brief N3): two packed strings of
--        quest ids per name. EraSources.QuestsGiven decodes them; the counts need no decode. Since
--        the same brief a vendor's name is in ck (negative), cd and mp too, so its page has a
--        portrait and a map.
--   og   the same for a world OBJECT name (brief EO1): a wanted poster, a sign, a corpse that
--        starts or ends quests, packed exactly as qg is and keyed by the object name's index the
--        way oi and op are. EraSources.ObjectQuestsGiven decodes them; its pins are in op (with no
--        ok category unless a row files the name under one).
--   zm   the zone map an area id is drawn on, which is the one thing a map tab needs that a pin
--        does not carry. E:MapOf reads it, and an area this build has no map for is absent.
--   zf   the sorted list of every area z names that is new in Forever (brief Z5): its own
--        instances and outdoor zones, which hold nothing out of Classic Era. E:IsForeverArea reads
--        it, and a table compiled before it answers false for every area.
--   pt   where a boss WALKS (brief M11): one packed path string per path, the area once and then
--        the points in walking order, in mp's alphabet. E:PathsOf reads it for a Map tab only.
--   mc   how many of the last records of a name's mp string are hand kept spots rather than
--        spawns (brief M11). E:PinsOf marks those pins kept; nothing else reads it.
--   x, xl  the rest of the list a summary row stands for, so "Show 239 more" can be opened and
--        searched. Each list is one packed STRING, identical lists are stored once and shared,
--        and nothing is decoded until E:More is called: building the tree never touches them.
--
-- A summary row therefore stands for sources that are really here. Its edge carries summary =
-- { item, category, listed }, which is what tells the interface that the row is a GROUP rather
-- than a thing: it never re-roots the window onto the node this file made up for it, and where
-- listed is above zero a click on it draws E:MoreEdges under it instead. listed is 0 for every
-- world drop, whose list the pipeline measured at about 2.1 MB and refused, and such a row keeps
-- its old wording and does nothing at all.
--
-- A row that names a creature carries creature = { type, family, low, high } as well, out of ck.
-- This file still chooses no icon and no words: Core/ViewModel.lua turns it into an Assets key
-- and Core/Sources.lua into the line the row's tooltip says.
--
-- The string table s is sorted, but since brief W15 (2026-09-29) it is TWO sorted runs: the names a
-- list record in xl carries first (its name field is two base 91 digits and stops at 8,280), then
-- every other string. Nothing here reads s as one sorted run or searches it by name: a name is
-- only ever reached by its index, E:NameIndexOf builds its own map in one walk, and the creature
-- search (Core/Data.lua Data:CreatureIndex) sorts the names itself. Its length is not bounded by
-- the 8,280 either, which is why the node id ranges below leave room for a hundred thousand names.
--
-- The table's rows name a creature, a vendor, an object or a quest and carry no creature or object
-- ids (the quest id and a container's item id are the only ids in them), so those rows point at a
-- node of this file's own making. Brief EK1: the table states one CMaNGOS creature id per creature
-- or vendor NAME (ci) and one gameobject id per object name (oi), and the node a row with no place
-- points at, the creature's or the object's own page, is keyed by that id, npc:-<creature id>
-- (EraSources.PageKey) or object:-<object id> (EraSources.ObjectKey). Brief EK2: a row in one
-- place, a pocket, a gathering node and its zones are keyed by those ids too (the ranges below), so
-- no key this file makes holds a name's place in the string table, and s may move from one release
-- to the next. Because such a node can never be the same key the collector's own sighting
-- points at (every id here is negated), the edge carries
-- dedupeName and Core/Graph.lua drops it when a live edge of the same type already names the
-- same thing. Live knowledge wins; a different name stays, because both may be true. Three kinds
-- of row point at a real node instead and need none of that: a quest (quest:<id>), a fishing
-- zone, which the contract lists by place rather than by name (zone:<areaId>), and the item a
-- container gives up (item:<id>), which opens like any other item.
--
-- A herb or a vein is a NODE (brief D6, the owner on Arcane Crystal: "replace Mined in with Mined
-- from, and the Mined in is at the node level"). The table ships one row per zone a node stands
-- in, a node's rows together; this file draws each run of them as ONE node row (an object key of
-- its own, keyed by the item and the node's object id, carrying the chance) that opens onto its
-- zone rows.
--
-- The provider answers:
--   item:<id>   up    DROPPED_BY    boss drops, creature drops, world drops, pickpocketing
--   item:<id>   up    SOLD_BY       vendors
--   item:<id>   up    SKINNED_FROM  the creatures it is skinned from
--   item:<id>   up    GATHERED_FROM herb nodes and mining veins, one row per NODE
--   object:<n>  up    GATHERED_FROM that node's zones, for a node row this file made (n below
--                                   NODE_BASE): the zone rows it opens onto
--   item:<id>   up    FISHED_FROM   a fishing zone, or the pool in one
--   item:<id>   up    LOOTED_FROM   a chest, a barrel or another world object
--   item:<id>   up    CONTAINED_IN  the container ITEM it comes out of
--   item:<id>   up    QUEST_REWARD  the quest that hands it over, and the further quests that
--                                   hand over the same item (usually the other faction's)
--   quest:<id>  down  QUEST_REWARDS what Era says that quest hands over
--   item:<id>   down  QUEST_OBJECTIVE  the quests whose qr asks for it, with the count (brief Q10)
--   quest:<id>  up    QUEST_REQUIRES   what qr says that quest asks for, with the count
--                                   Core/Graph.lua drops both where the curated table or the
--                                   collector already states that quest's requirements
--   spell:<id>  up    LEARNED_FROM_TRAINER  the trainers that teach it (brief P6b, tr), each at
--                                   its own creature page npc:-<creature id> (brief EK1)
--
-- A namer is registered beside it (Graph.RegisterNamer). Every node above is named as the row
-- that points at it is drawn, which is every route but one: a node opened by its key alone, out
-- of the recently viewed list after a reload or from a debug command, reaches Graph.Title before
-- anything has asked for an edge and would read "Quest 4242". Core/Graph.lua asks the namer only
-- for a key nothing else could name, so a curated or collector learned quest keeps its own title
-- and a load that opens nothing asks nothing: the shipped module is still read on demand, and a
-- session that never opens one of these nodes never reads it at all.
local _, ItemTree = ...

local Data = ItemTree.Data
local Edges = ItemTree.Edges
local Graph = ItemTree.Graph
local Confidence = ItemTree.Confidence
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local T = Edges.Types
local EMPTY = {}

local EraSources = {}
ItemTree.EraSources = EraSources

-- The generated module this reads, and the provenance every edge carries. The provenance key is
-- the same short word Core/Sources.lua already stamps a Classic Era drop rate with, because it
-- is the same fact about the same data: read through the namespace so this file still loads
-- with Core/Sources.lua absent.
EraSources.MODULE = "EraSources"
EraSources.PROVENANCE = (ItemTree.Sources and ItemTree.Sources.ERA) or "era"

-- Brief GA1 (owner ruling of 2026-10-09: only data derived from the CMaNGOS Classic content database
-- may be in a GPL file). The table ships as two modules, EraSources (GPL-3.0: the strings, each place
-- only a zone name holds left empty, and every table read out of the CMaNGOS dump) and EraPlaces
-- (ours, all rights reserved: the zone names by their place, z, zm, zf, cf, mp, op, ok, pt and
-- mc). Core/Data.lua's Data.JoinEraSources makes the one table every reader in this file reads, the
-- first time Data:Get builds it (Data.JOINS). EraSources.Join is the same function.
EraSources.PLACES_MODULE = "EraPlaces"
EraSources.Join = Data and Data.JoinEraSources or nil

-- The thirteen categories the table's c field uses, as the words the rest of Core reads. 2 is
-- reserved by the contract and never emitted, so it is missing here on purpose and is read the
-- way 14 and upwards will be: a category this file does not know is skipped, never guessed at.
EraSources.CATEGORIES = {
  [1] = "boss",
  [3] = "quest",
  [4] = "vendor",
  [5] = "world",
  [6] = "creature",
  [7] = "skinned",
  [8] = "herb",
  [9] = "vein",
  [10] = "fished",
  [11] = "object",
  [12] = "pickpocket",
  [13] = "container",
}

-- The number behind each of those words, for a caller that names a category the way a row does.
EraSources.NUMBERS = {}
for number, word in pairs(EraSources.CATEGORIES) do
  EraSources.NUMBERS[word] = number
end

-- The categories whose n names a CREATURE, which are exactly the four the table ships a kind
-- for: ck covers every name a c = 1, 6, 7 or 12 row or one of their lists uses and nothing else.
-- A vendor, an object, a gathering node and a quest are not creatures, so none of them asks, and
-- a vendor who happens to share a name with a creature keeps the vendor's own icon.
EraSources.CREATURE_CATEGORIES = {
  boss = true,
  creature = true,
  skinned = true,
  pickpocket = true,
}

-- The category a quest row belongs to, by number, for the one pass that has to find them in the
-- raw table rather than in a normalised row.
local QUEST_CATEGORY = 3

-- The two categories whose packed record is shaped differently from the rest: a container names
-- nothing and carries an item id, and a vendor carries a stock count where a chance would be.
local CONTAINER_CATEGORY = 13
local VENDOR_CATEGORY = 4
-- Brief OL1: the category of a chest's "Found in" rows (EraSources.CATEGORIES 11), which the loot
-- index reads the other way round for an object's Loot tab.
local OBJECT_CATEGORY = 11

-- The faction a vendor or a quest belongs to, by the table's f field. 3 is both sides, which
-- says nothing a row is worth drawing, so it answers nothing. Each word is the English wording
-- and its own locale key, read through L by key, so tests/spec/locale_spec.lua lists the block.
EraSources.FACTIONS = { [1] = "Alliance", [2] = "Horde" }

-- The words a world drop row is named by: the table states no creature and no area for one,
-- because "it drops out in the world somewhere" is the whole of what the source knew. Its level
-- band, where there is one, is a qualifier on the row rather than part of the node's name.
local WORLD_DROP = "World drop"

-- The node a world drop points at. Id 0 is no creature in any build, which is the point: the
-- row has to lead somewhere and there is nothing for it to lead to, so it leads to a node of
-- this file's own that every world drop shares.
local WORLD_ID = 0

-- The ranges of node id this file makes, all negative, so its own nodes can never be a creature or
-- an object this build states and can never be each other. Brief EK2 (owner ruling of 2026-10-09:
-- "pages are keyed by id, never by a name's position"): every range a key a player can open or save
-- sits in is keyed by ids and numbers alone, never by a name's place in the string table s, so s may
-- be reordered from one release to the next and a saved key still names the same thing. Each range
-- is a window of its own, [base, base + size), read and built by ONE pair of helpers per range
-- below (the builder EraSources.PlacedKey, PocketKey, GatheredKey or NodeKey, the parser
-- EraSources.PlacedId, PocketId, GatheredId or NodeAt); nothing else in the addon builds or reads
-- one by hand.
--
--   -1 down to -(SUMMARY_BASE - 1)   a PAGE (brief EK1), keyed by an id, negated: a creature's
--                                    CMaNGOS creature id for an npc key (ci,
--                                    EraSources.CreaturePageKey and EraSources.PageId) and an
--                                    object's gameobject id for an object key (oi,
--                                    EraSources.ObjectPageKey and EraSources.ObjectPageId).
--   SUMMARY_BASE                     a summary row, keyed by the item and the category it stands
--                                    for. It names no creature and no place, and two summary rows
--                                    on one item (or on two items open at once, a container under
--                                    its own row) must never be the same node.
--   NOPAGE_BASE                      (brief EK1) the node of a row naming a creature, a vendor or
--                                    an object the table states no id for, which is no page (see
--                                    below). Never opened, so never saved.
--   PLACED_BASE                      a name in one place: the creature id (an npc key) or the object
--                                    id (an object key) and the area. The contract lists the same
--                                    object in two zones as two rows, best chance first, and one
--                                    node per name would merge them into one row in Core/Graph.lua
--                                    and lose the second place.
--   POCKET_BASE                      a POCKET in one place, keyed by the creature id and the area
--                                    (0 where the table states none). A creature you can steal the
--                                    item from is a different node from the same creature dropping
--                                    it: see POCKETS below.
--   GATHERED_BASE                    a gathering node in one ZONE (a zone key), keyed by the node's
--                                    object id and the area: a node row's zone rows. The row reads
--                                    as the place and the node is a zone node, and a Copper Vein
--                                    and a Tin Vein in one zone are still two nodes.
--   NODE_BASE                        a gathering NODE on one item (an object key), keyed by the item
--                                    and the node's object id: the node row itself (brief D6).
--                                    Keyed by the item because the zones under it are the zones the
--                                    table lists for that item, so asking the key for its children
--                                    needs nothing but the key. Its row opens and closes rather
--                                    than re-rooting; since brief D7 a root on it has a Map tab
--                                    where op carries pins for the name.
--
-- The spans, and the edges each window is specced at (tests/spec/era_row_key_spec.lua):
--   ROW_IDS     a creature or object id, 1 to 999,999. On 1.60.1.70291 ci stops at 17,598 and oi at
--               186,750 (the CMaNGOS gameobject ids run higher than the creature ids).
--   ROW_AREAS   an area id, 0 to 99,999. This build's AreaTable stops at 17,847.
--   NODE_ITEMS  an item id, 1 to 999,999. This build's largest item id is 287,992.
-- So PLACED, POCKET and GATHERED each hold ROW_IDS * ROW_AREAS ids (a hundred thousand million) and
-- NODE holds NODE_ITEMS * ROW_IDS (a million million):
--   NOPAGE    2,000,000,000,000 to 2,000,000,099,999
--   PLACED    3,000,000,000,000 to 3,099,999,999,999
--   POCKET    3,200,000,000,000 to 3,299,999,999,999
--   GATHERED  3,400,000,000,000 to 3,499,999,999,999
--   NODE      4,000,000,000,000 to 4,999,999,999,999
-- with Core/GuessSources.lua's nodes from 9,000,000,000,000 up. The largest id is 13 digits, inside
-- the 14 Lua 5.1's tostring prints exactly, so a key still reads back as the id it was made from. An
-- id or an area past a span makes no row key: the row falls back to the page the id alone gives,
-- which merges two rows into one rather than pointing either at the wrong thing;
-- tests/spec/era_display_spec.lua fails on the merge, which is how such a table announces itself.
--
-- The windows 10,000,000,000 to 1,039,999,999,999 are RETIRED: ItemTree 0.1.3 to the EK1 build put
-- the same four ranges there keyed by a name's place in s (Core/History.lua converts a key saved in
-- one, with a frozen copy of the old formulas), so no key made now can ever be read as an old one,
-- nor an old one as a key made now: nothing here answers for an id in them.
local SUMMARY_BASE = 1000000000
local SUMMARY_SPAN = 16
local PLACED_BASE = 3000000000000
local POCKET_BASE = 3200000000000
local GATHERED_BASE = 3400000000000
local NODE_BASE = 4000000000000
local ROW_IDS = 1000000
local ROW_AREAS = 100000
local NODE_ITEMS = 1000000

-- Brief EK1 (the coordinator's ruling of 2026-10-09): a creature or vendor NAME the table states no
-- creature id for (ci) has no page, and a row that names it stays VISIBLE with nothing to open,
-- rather than being dropped. Its node is one of this file's own in a range of its own, keyed by
-- the name the way the plain page used to be (one node per name, so two rows of one name on one
-- item still merge as they did), which no reader answers as a page: CreatureAt, NpcNameAt and
-- PinSubject answer nothing for it, E:NameFor answers its name, and the edge carries noPage, which
-- UI/Tree.lua reads as a row that opens nothing. The window is the name span (NOPAGE_NAMES) at two
-- million million, below the row ranges and far below Core/GuessSources.lua's nodes. It is the one
-- node still keyed by a name's place, and safely so: it is never a page, never opened and so never
-- saved, and on 1.60.1.70291 no row makes one (every creature name has a ci id, every object an oi).
local NOPAGE_BASE = 2000000000000
local NOPAGE_NAMES = 100000

-- Where a category's row goes: the edge type it is drawn as, the category it is filed under and
-- the node kind it points at. Each group word is the English wording and its own locale key, the
-- way every other group in Core is, so a translated client changes the words and never a
-- category id or a saved filter.
--
-- Six of the thirteen are filed under a category the player already knows from their own
-- sightings (a boss drop, a creature drop and a world drop all read as "Drops from", and then
-- vendors, quests and containers), so live and historical rows about the same kind of source
-- read as one list. The other six are the shapes no live source has ever produced, and each is
-- its own category in the contract's own order; Core/ViewModel.lua orders and illustrates them.
--
-- summary is the node kind a summary row takes, which is the row's own kind except where that
-- kind would be read as something the player can open: a container's summary must not point at
-- an item, because a made up item id is exactly the thing the addon must never ask the client
-- about.
local PLACES = {
  boss = { edge = "DROPPED_BY", group = "Drops from", kind = "npc", summary = "npc" },
  quest = { edge = "QUEST_REWARD", group = "Quests", kind = "quest", summary = "object" },
  vendor = { edge = "SOLD_BY", group = "Sold by", kind = "npc", summary = "npc" },
  world = { edge = "DROPPED_BY", group = "Drops from", kind = "npc", summary = "npc" },
  creature = { edge = "DROPPED_BY", group = "Drops from", kind = "npc", summary = "npc" },
  skinned = { edge = "SKINNED_FROM", group = "Skinned from", kind = "npc", summary = "npc" },
  herb = { edge = "GATHERED_FROM", group = "Gathered from", kind = "object", summary = "object" },
  vein = { edge = "GATHERED_FROM", group = "Mined from", kind = "object", summary = "object" },
  fished = { edge = "FISHED_FROM", group = "Fished in", kind = "object", summary = "object" },
  object = { edge = "LOOTED_FROM", group = "Found in", kind = "object", summary = "object" },
  pickpocket = { edge = "DROPPED_BY", group = "Pickpocketed from", kind = "npc", summary = "npc" },
  container = { edge = "CONTAINED_IN", group = "Contained in", kind = "item", summary = "object" },
}

-- The categories whose rows are a gathering NODE's zones (brief D6). The table lists a herb or a
-- vein one row per zone the node stands in, a node's rows together, so each run of rows with one
-- name is drawn as ONE node row under "Gathered from" or "Mined from", carrying the chance (one
-- chance per node: every zone row of a node states the same one), and its zones are the rows it
-- opens onto, each under the words below. A node whose every zone is an instance (no zone map on
-- this build) opens onto nothing and names the instance in its zone column instead, the way a
-- creature row inside one does; a node the table places nowhere names nothing there at all.
--
-- A zone row is the node IN THAT ZONE rather than the zone itself (GATHERED_BASE), because one
-- item can come out of two different nodes in one zone: 2798 Rethban Ore is mined from a Copper
-- Vein AND a Tin Vein in Redridge Mountains, and those are two zone rows under two node rows.
local NODES = {
  herb = { edge = "GATHERED_FROM", group = "Gathered in" },
  vein = { edge = "GATHERED_FROM", group = "Mined in" },
}

-- The categories whose node is a creature you STEAL from rather than a creature that drops.
--
-- Pickpocketing is filed under the same edge type as a drop, because the player reads both as
-- "this creature has it", but it is a different act on the same creature, it draws under its own
-- group, and the table lists it with its own chance. Keyed like a drop, the two rows were one
-- edge (Core/Graph.lua pairs edges by type and target) and the "Pickpocketed from" category
-- never appeared on the seven items that carry both. 19775 Sealed Azure Bag was the worst of
-- them: the drop it showed is 0.4% and the pocket it hid is 26%.
local POCKETS = { pickpocket = true }

-- The words a row's qualifier is written in live in Core/Sources.lua, beside every other piece
-- of source wording, and are read through the namespace so this file still loads and answers
-- with that one absent.
local function phrase(name, ...)
  local Sources = ItemTree.Sources
  local fn = Sources and Sources[name] or nil
  if type(fn) ~= "function" then
    return nil
  end
  return fn(...)
end

-- One entry of the 1 based string table, or nil for an index that names nothing.
local function stringAt(source, index)
  if type(index) ~= "number" then
    return nil
  end
  local strings = source.s
  local text = type(strings) == "table" and strings[index] or nil
  if type(text) == "string" and text ~= "" then
    return text
  end
  return nil
end

-- The name THIS build's AreaTable gave an area, which is what z points at. The snapshot states
-- the id and no name at all, so an area the build does not name reads as no area.
local function areaName(source, areaId)
  if type(areaId) ~= "number" then
    return nil
  end
  local areas = source.z
  return stringAt(source, type(areas) == "table" and areas[areaId] or nil)
end

-- A chance the table states, or nil. The pipeline refuses a negative one, one above 100 and one
-- that rounds to zero before the module is written, so anything else here is a table that has
-- been edited by hand; it is checked again rather than drawn.
--
-- 100 is a chance like any other and every category draws it. A Black Lotus node gives a Black
-- Lotus every time and a copper vein gives copper ore every time, and that IS the drop chance;
-- how hard the node itself is to find is a different question, and no database here states it.
local function chanceOf(percent)
  if type(percent) ~= "number" or percent <= 0 or percent > 100 then
    return nil
  end
  return percent
end

local function factionWord(faction)
  local word = EraSources.FACTIONS[faction]
  if not word then
    return nil
  end
  return L[word]
end

-- The rows one item carries, as a list, in the table's own order. Version 3 (brief OPT7) ships
-- each item's rows as ONE packed string (packed = 1, the legend at the module's top level), which
-- Data.PackedList decodes on the first read into a weak valued cache per item: the same list
-- while anything holds it, decoded again when next wanted once nothing does. Version 2 states a
-- list; version 1 stated a single row, and a row is told from a list by its own c, so a module
-- of any of the three shapes reads correctly. EMPTY for an item the table has no rows for.
local function rowList(source, itemId)
  local rows = type(source) == "table" and source.r or nil
  if type(rows) ~= "table" or itemId == nil then
    return EMPTY
  end
  local raw = rows[itemId]
  if type(raw) == "string" then
    local decode = type(Data) == "table" and Data.PackedList or nil
    raw = decode and decode(source, rows, itemId) or nil
  end
  if type(raw) ~= "table" then
    return EMPTY
  end
  if raw.c ~= nil then
    return { raw }
  end
  return raw
end

-- The same rows for a pass over the whole table that reads fields and KEEPS NO ROW (an index
-- build), as a generic for: `for _, raw in scanRows(source, itemId, scan)`. A packed item not in
-- the cache is decoded row by row into scan's one reused table (Data.ScanRows), so a pass over
-- every item allocates nothing per row and leaves the cache as it found it. scan is a table the
-- pass makes once. Every other shape is rowList's own answer.
local function scanRows(source, itemId, scan)
  local rows = type(source) == "table" and source.r or nil
  local scanner = type(Data) == "table" and Data.ScanRows or nil
  if scanner ~= nil and type(rows) == "table" and type(rows[itemId]) == "string" then
    return scanner(source, rows, itemId, scan)
  end
  return ipairs(rowList(source, itemId))
end

-- Brief RB4: the item ids of one table's rows (its r), ascending: the order every pass over the
-- whole table walks them in, because pairs walks a table differently from one run to the next and
-- each index keeps the order its buckets were built in. Collected and sorted once per rows table and
-- kept (weakly, so a table let go takes its list with it): the loot, vendor, quest and quest facts
-- passes each sorted the same 12,149 ids over the shipped 1.60.1.70425 data, about 3.8 ms offline
-- that no Data.SliceCheck can cut, which was most of the login slicer's first quest facts tick.
-- The list is this file's own and must not be modified.
local sortedIdsOf = setmetatable({}, { __mode = "k" })

local function sortedItemIds(rows)
  local held = sortedIdsOf[rows]
  if held then
    return held
  end
  local ids = {}
  for itemId in pairs(rows) do
    if type(itemId) == "number" then
      ids[#ids + 1] = itemId
    end
  end
  table.sort(ids)
  sortedIdsOf[rows] = ids
  return ids
end

-- The node a summary row points at, and the item it belongs to read back out of one.
local function summaryId(itemId, category)
  if type(itemId) ~= "number" or type(category) ~= "number" then
    return nil
  end
  return -(SUMMARY_BASE + itemId * SUMMARY_SPAN + category)
end

local function summaryItem(id)
  local held = -id - SUMMARY_BASE
  if held < 0 then
    return nil
  end
  return math.floor(held / SUMMARY_SPAN)
end

--------------------------------------------------------------------------------
-- The row ranges, keyed by ids (brief EK2)
--------------------------------------------------------------------------------

-- The four windows, each its base and how many ids it holds.
local PLACED = { base = PLACED_BASE, size = ROW_IDS * ROW_AREAS }
local POCKET = { base = POCKET_BASE, size = ROW_IDS * ROW_AREAS }
local GATHERED = { base = GATHERED_BASE, size = ROW_IDS * ROW_AREAS }
local NODE = { base = NODE_BASE, size = NODE_ITEMS * ROW_IDS }
-- The summary window: from SUMMARY_BASE up to the first retired window (10,000,000,000).
local SUMMARY = { base = SUMMARY_BASE, size = 9000000000 }

-- A whole number in [low, high), or false.
local function within(value, low, high)
  return type(value) == "number" and value == math.floor(value) and value >= low and value < high
end

-- What one negative id holds past a window's base, or nil for an id outside the window. Pure.
local function heldIn(window, id)
  if type(id) ~= "number" or id ~= math.floor(id) then
    return nil
  end
  local held = -id - window.base
  if held < 0 or held >= window.size then
    return nil
  end
  return held
end

-- The one builder of the three paired windows: an id and an area packed into one, -(base + id *
-- ROW_AREAS + area). nil for an id or an area outside the spans; then the caller falls back to the
-- page the id alone gives, because two rows that merge into one is a far better answer than two
-- rows about the wrong thing. floorArea is 1 for a window that means nothing without a place
-- (placed, gathered) and 0 for one keyed on an id whether or not the table states an area (a
-- pocket: no area is area 0).
local function pairedId(window, id, areaId, floorArea)
  if areaId == nil and floorArea == 0 then
    areaId = 0
  end
  if not within(id, 1, ROW_IDS) or not within(areaId, floorArea, ROW_AREAS) then
    return nil
  end
  return -(window.base + id * ROW_AREAS + areaId)
end

-- The one parser of the three paired windows: the id and the area one id holds, or nil for an id
-- outside the window or one no builder makes (an id of 0, an area under floorArea).
local function pairedParts(window, id, floorArea)
  local held = heldIn(window, id)
  if not held then
    return nil
  end
  local areaId = held % ROW_AREAS
  local rowId = (held - areaId) / ROW_AREAS
  if rowId < 1 or areaId < floorArea then
    return nil
  end
  return rowId, areaId
end

-- Which row window a negative id sits in ("placed", "pocket", "gathered" or "node"), or nil for
-- every other id. Pure arithmetic: what decides whether a reader needs the table for a key.
local function rowWindow(id)
  if heldIn(PLACED, id) then
    return "placed"
  elseif heldIn(POCKET, id) then
    return "pocket"
  elseif heldIn(GATHERED, id) then
    return "gathered"
  elseif heldIn(NODE, id) then
    return "node"
  end
  return nil
end

--- The key of a creature (kind "npc", its CMaNGOS creature id) or an object (kind "object", its
--- gameobject id) in one area: the node a row that states a place points at. The ONE builder of the
--- placed range. nil for another kind, no area, or an id or area past the spans. Pure.
function EraSources.PlacedKey(kind, id, areaId)
  if kind ~= "npc" and kind ~= "object" then
    return nil
  end
  local paired = pairedId(PLACED, id, areaId, 1)
  return paired and Graph.Key(kind, paired) or nil
end

--- The kind, the id and the area one placed key holds, or nil for any other key. The ONE parser of
--- the placed range. Pure arithmetic.
function EraSources.PlacedId(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "npc" and kind ~= "object" then
    return nil
  end
  local rowId, areaId = pairedParts(PLACED, id, 1)
  if not rowId then
    return nil
  end
  return kind, rowId, areaId
end

--- Brief EK2: whether a key is one of this file's row keys in one place: a placed key (a creature or
--- an object in one area) or a pocket key. Core/ViewModel.lua sorts such a row before the page of the
--- same name, which is the order the old name keyed ranges' digits gave. Pure arithmetic.
function EraSources.StatesPlace(key)
  local kind, id = Graph.Parse(key)
  if kind == "npc" then
    return pairedParts(PLACED, id, 1) ~= nil or pairedParts(POCKET, id, 0) ~= nil
  end
  return kind == "object" and pairedParts(PLACED, id, 1) ~= nil
end

--- The key of a creature you can steal from, by its creature id and the area (nil or 0 for a row
--- that states none): keyed whether or not the table states an area, because 64 of the 300 named
--- pickpocket rows state none and each of those would otherwise land back on the page the
--- creature's drop row already holds. The ONE builder of the pocket range. Pure.
function EraSources.PocketKey(creatureId, areaId)
  local paired = pairedId(POCKET, creatureId, areaId, 0)
  return paired and Graph.Key("npc", paired) or nil
end

--- The creature id and the area (nil for none) one pocket key holds, or nil for any other key. The
--- ONE parser of the pocket range. Pure arithmetic.
function EraSources.PocketId(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "npc" then
    return nil
  end
  local creatureId, areaId = pairedParts(POCKET, id, 0)
  if not creatureId then
    return nil
  end
  if areaId == 0 then
    areaId = nil
  end
  return creatureId, areaId
end

--- The zone key of a gathering node in one area, by the node's gameobject id: what a node row's
--- zone rows point at. A row with no object (a whole fishing zone) has no node to name, so the
--- caller keeps the bare zone key. The ONE builder of the gathered range. Pure.
function EraSources.GatheredKey(objectId, areaId)
  local paired = pairedId(GATHERED, objectId, areaId, 1)
  return paired and Graph.Key("zone", paired) or nil
end

--- The object id and the area one gathered zone key holds, or nil for any other key. The ONE parser
--- of the gathered range. Pure arithmetic.
function EraSources.GatheredId(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "zone" then
    return nil
  end
  return pairedParts(GATHERED, id, 1)
end

-- The id a gathering node row points at, -(NODE_BASE + item * ROW_IDS + object id), or nil for an
-- item or an object id past the spans (then the row falls back to the object's page: it still
-- draws, and it opens onto nothing).
local function nodeId(itemId, objectId)
  if not within(itemId, 1, NODE_ITEMS) or not within(objectId, 1, ROW_IDS) then
    return nil
  end
  return -(NODE_BASE + itemId * ROW_IDS + objectId)
end

--- The key of a gathering node row, by the item it is drawn on and the node's gameobject id. The
--- ONE builder of the node range. Pure.
function EraSources.NodeKey(itemId, objectId)
  local id = nodeId(itemId, objectId)
  return id and Graph.Key("object", id) or nil
end

-- Whether a node key is one of this file's gathering node rows. Pure arithmetic over the key, so
-- Core/ViewModel.lua can ask it of every row it builds and nothing is loaded.
function EraSources.IsNodeKey(key)
  local kind, id = Graph.Parse(key)
  return kind == "object" and EraSources.NodeAt(id) ~= nil
end

--- The item and the gameobject id one node row's id states, or nil for an id that is not one. The
--- ONE parser of the node range (it takes the id, as Core/ViewModel.lua holds it). Pure arithmetic.
function EraSources.NodeAt(id)
  local held = heldIn(NODE, id)
  if not held then
    return nil
  end
  local objectId = held % ROW_IDS
  local itemId = (held - objectId) / ROW_IDS
  if itemId < 1 or objectId < 1 then
    return nil
  end
  return itemId, objectId
end

--------------------------------------------------------------------------------
-- A Classic Era creature's page key (brief EK1)
--------------------------------------------------------------------------------

-- The owner (2026-10-09): "isn't ID just better? why are we keying off a name that could be
-- changed?". A Classic Era creature's PAGE, the plain node one name opens (every row that states
-- no place, the search, a trainer row, a quest giver, a Boss loot entry, a unit in the world), is
-- keyed by its CMaNGOS creature id, npc:-<id>, and no longer by its name's place in s. ci carries
-- that id per name: the LOWEST creature entry whose name is exactly that string, so same named
-- variants still share one page as they did, and a vendor's name is in it too. The id stays
-- negated, so it is never read as an id the Forever client states.
--
-- These functions are the ONLY place an Era creature's page key is built (CreaturePageKey, which
-- PageKey wraps) or read back (PageId, which PageName wraps): every other file asks them, or the E
-- wrappers further down (E:PageKey, E:PageName, E:PinSubject). The placed, pocket, gathered, node
-- and summary ranges above are ROW nodes with builders and parsers of their own (brief EK2: keyed by
-- these same ids and a place, or an item); an object's page has helpers of its own beside these
-- (brief EK1 2c). Brief EK1 2b adds one branch to
-- PageKey and one to PageName for a creature the Forever data knows by the same id and the same
-- name, whose page is then the plain npc:<id>.
--
-- The plain range a page key sits in: below 0 and above the summary range.
local function isPageId(id)
  return type(id) == "number" and id < 0 and id > -SUMMARY_BASE and id == math.floor(id)
end

-- A creature id ci may state: a whole number from 1 up to, not into, the summary range, so its
-- negation is always a page key and never one of the row ranges.
local function validCreatureId(id)
  return type(id) == "number" and id >= 1 and id < SUMMARY_BASE and id == math.floor(id)
end

-- The reverse of ci (creature id to name index), built once per table and held WEAKLY against it,
-- the way E:_LootIndex is held against its table: a table swapped under a loaded Core (the harness,
-- a spec) is answered from the new table, and the old map goes with the old table. The pipeline
-- states every id once; were two names to state one id, the lower name index keeps it, so the
-- answer is the same on every load.
-- Brief EK1 2c: the same map for oi, the object pages (EraSources.ObjectName), held the same way.
local pageNameMaps = setmetatable({}, { __mode = "k" })
local objectNameMaps = setmetatable({}, { __mode = "k" })

local function reverseMap(cache, source, field)
  local map = cache[source]
  if map then
    return map
  end
  map = {}
  local ids = type(source[field]) == "table" and source[field] or EMPTY
  for nameIndex, id in pairs(ids) do
    if type(nameIndex) == "number" and validCreatureId(id) then
      local held = map[id]
      if held == nil or nameIndex < held then
        map[id] = nameIndex
      end
    end
  end
  cache[source] = map
  return map
end

-- Brief EK1 2b: whether the name at one string index is merged (cm, ours, joined out of
-- EraPlaces.lua): the Forever client's creature data holds its creature id with exactly its name,
-- so its Classic Era page and the Forever page of that id are one page, keyed npc:<id>.
local function isMerged(source, nameIndex)
  local merged = type(source) == "table" and source.cm or nil
  return type(merged) == "table" and type(nameIndex) == "number" and merged[nameIndex] == 1
end

-- The name index one page id stands for, or nil: an id out of the plain range, a table with no ci,
-- an id ci does not state, or (brief EK1 2b) a merged name's id, whose page is the positive key and
-- never this negative one, so each creature has exactly one page.
local function pageNameOf(source, id)
  if type(source) ~= "table" or not isPageId(id) then
    return nil
  end
  local nameIndex = reverseMap(pageNameMaps, source, "ci")[-id]
  if nameIndex and isMerged(source, nameIndex) then
    return nil
  end
  return nameIndex
end

-- Brief EK1 2b: the name index a positive npc id stands for where it is a merged name's page
-- (npc:<id>), or nil for every other positive id, which is the Forever creature's page alone.
local function mergedNameOf(source, id)
  if type(source) ~= "table" or type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then
    return nil
  end
  local nameIndex = reverseMap(pageNameMaps, source, "ci")[id]
  if nameIndex and isMerged(source, nameIndex) then
    return nameIndex
  end
  return nil
end

-- The object twin (brief EK1 2c): the name index one object page id stands for, out of oi.
local function objectNameOf(source, id)
  if type(source) ~= "table" or not isPageId(id) then
    return nil
  end
  return reverseMap(objectNameMaps, source, "oi")[-id]
end

--- Brief EK2: the string index of the Classic Era creature or vendor name ci states one CMaNGOS
--- creature id for, merged (cm) or not, or nil (no table, an id ci does not state). The reverse of
--- EraSources.CreatureIdOf, through the same once per table map the page keys read. What a row key
--- (placed, pocket) and a guess's creature (Core/GuessSources.lua) are read back through. Pure.
function EraSources.CreatureNameIndex(source, creatureId)
  if type(source) ~= "table" or not validCreatureId(creatureId) then
    return nil
  end
  return reverseMap(pageNameMaps, source, "ci")[creatureId]
end

--- Brief EK2: the object twin, the string index of the object name oi states one gameobject id for,
--- or nil. What a placed object, a gathering node row and its zone rows are read back through. Pure.
function EraSources.ObjectNameIndex(source, objectId)
  if type(source) ~= "table" or not validCreatureId(objectId) then
    return nil
  end
  return reverseMap(objectNameMaps, source, "oi")[objectId]
end

--- The CMaNGOS creature id ci states for the name at one string index, or nil (no table, no ci, a
--- name ci does not carry, or a value that is not a creature id). Pure.
function EraSources.CreatureIdOf(source, nameIndex)
  if type(source) ~= "table" or type(nameIndex) ~= "number" then
    return nil
  end
  local ids = source.ci
  local id = type(ids) == "table" and ids[nameIndex] or nil
  if not validCreatureId(id) then
    return nil
  end
  return id
end

--- The page key of the Classic Era creature with one CMaNGOS creature id, "npc:-<id>": the ONE
--- place a Classic Era creature's page key is built (EraSources.PageKey and the Boss loot index's
--- ei both come through it). merged is for brief EK1 2b's merge, where the page is one with the
--- Forever page of that id and the key is the plain "npc:<id>". nil for a value that is not a
--- creature id. Pure.
function EraSources.CreaturePageKey(id, merged)
  if not validCreatureId(id) then
    return nil
  end
  if merged then
    return Graph.Key("npc", id)
  end
  return Graph.Key("npc", -id)
end

--- The creature id one Classic Era creature's page key holds, or nil for anything but an npc key in
--- the plain negative range: the ONE place such a key is read back (EraSources.PageName reads the
--- name through it). Pure arithmetic.
function EraSources.PageId(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "npc" or not isPageId(id) then
    return nil
  end
  return -id
end

--- The page key of the Classic Era creature or vendor at one string index, "npc:-<creature id>", or
--- (brief EK1 2b) the plain "npc:<creature id>" for a merged name (cm), whose page is one with the
--- Forever page of that id; nil where the table states no creature id for the name: such a name has
--- no page, and nothing builds a key for it by hand. Pure.
function EraSources.PageKey(source, nameIndex)
  local id = EraSources.CreatureIdOf(source, nameIndex)
  if not id then
    return nil
  end
  return EraSources.CreaturePageKey(id, isMerged(source, nameIndex))
end

--- Brief EK1 2b: whether the Classic Era name at one string index is merged with the Forever page of
--- its creature id (cm). Pure.
function EraSources.IsMerged(source, nameIndex)
  return isMerged(source, nameIndex) == true
end

--- The string index a Classic Era creature's page key stands for, or nil: anything but an npc key
--- in the plain range (the world drop, a placed, pocket or summary row node), or a page id ci does
--- not state. Brief EK1 2b: a positive key answers for a merged name (cm) alone, and a merged
--- name's negative key answers nothing, so every creature has one page. The reverse map is built
--- once per table. Pure.
function EraSources.PageName(source, key)
  local id = EraSources.PageId(key)
  if id then
    return pageNameOf(source, -id)
  end
  -- Brief EK1 2b: a merged name's page is the plain npc:<id>.
  local kind, positive = Graph.Parse(key)
  if kind ~= "npc" then
    return nil
  end
  return mergedNameOf(source, positive)
end

-- The name index one of the no page nodes (NOPAGE_BASE) stands for, or nil for any other id.
local function noPageName(id)
  if type(id) ~= "number" or id ~= math.floor(id) then
    return nil
  end
  local held = -id - NOPAGE_BASE
  if held < 1 or held >= NOPAGE_NAMES then
    return nil
  end
  return held
end

--- The node a row naming the Classic Era creature or vendor at one string index points at, and
--- whether it is a page: its page key (EraSources.PageKey) and true, or, where the table states no
--- creature id for the name, the no page node of that name (NOPAGE_BASE) and false, which a row
--- draws and nothing opens. nil for an index that names nothing this file can key. Pure.
function EraSources.CreatureNode(source, nameIndex)
  local key = EraSources.PageKey(source, nameIndex)
  if key then
    return key, true
  end
  if type(nameIndex) ~= "number" or nameIndex ~= math.floor(nameIndex) then
    return nil
  end
  if nameIndex < 1 or nameIndex >= NOPAGE_NAMES then
    return nil
  end
  return Graph.Key("npc", -(NOPAGE_BASE + nameIndex)), false
end

--- Whether a key is one of those no page nodes: a row's node that is no page (an npc's, or since
--- brief EK1 2c an object's). Pure arithmetic.
function EraSources.IsNoPageKey(key)
  local kind, id = Graph.Parse(key)
  return (kind == "npc" or kind == "object") and noPageName(id) ~= nil
end

--------------------------------------------------------------------------------
-- A Classic Era object's page key (brief EK1 2c)
--------------------------------------------------------------------------------

-- The owner (2026-10-09, "Yes, in this round"): an object's PAGE, the plain object node one name
-- opens (a chest or a fishing pool a row names with no place, a herb, vein, pool or chest the search
-- finds), is keyed by its CMaNGOS gameobject id, object:-<id>, the way a creature's page is keyed
-- by its creature id. oi carries that id per object name: the LOWEST gameobject entry of exactly
-- that name. The placed, gathered and node ranges are rows keyed by the same id and a place (or an
-- item, brief EK2) with helpers of their own. These are the object siblings of the creature page
-- key helpers: one builder (EraSources.ObjectPageKey) and one parser (EraSources.ObjectPageId),
-- with the name index wrappers beside them. No object page is merged with anything this round.

--- The gameobject id oi states for the object name at one string index, or nil. Pure.
function EraSources.ObjectIdOf(source, nameIndex)
  if type(source) ~= "table" or type(nameIndex) ~= "number" then
    return nil
  end
  local ids = source.oi
  local id = type(ids) == "table" and ids[nameIndex] or nil
  if not validCreatureId(id) then
    return nil
  end
  return id
end

--- The page key of the Classic Era object with one gameobject id, "object:-<id>": the ONE place a
--- Classic Era object's page key is built. nil for a value that is not an id. Pure.
function EraSources.ObjectPageKey(id)
  if not validCreatureId(id) then
    return nil
  end
  return Graph.Key("object", -id)
end

--- The gameobject id one Classic Era object's page key holds, or nil for anything but an object key
--- in the plain negative range: the ONE place such a key is read back. Pure arithmetic.
function EraSources.ObjectPageId(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "object" or not isPageId(id) then
    return nil
  end
  return -id
end

--- The page key of the Classic Era object at one string index, or nil where oi states no id for the
--- name. Pure.
function EraSources.ObjectKey(source, nameIndex)
  return EraSources.ObjectPageKey(EraSources.ObjectIdOf(source, nameIndex))
end

--- The string index a Classic Era object's page key stands for, or nil (anything but a plain object
--- page key, or an id oi does not state). The reverse map is built once per table. Pure.
function EraSources.ObjectName(source, key)
  local id = EraSources.ObjectPageId(key)
  if not id then
    return nil
  end
  return objectNameOf(source, -id)
end

--- The node a row naming the Classic Era object at one string index points at, and whether it is a
--- page: its page key and true, or, where oi states no id for the name, the no page node of that
--- name (an object key in the NOPAGE_BASE window) and false. Pure.
function EraSources.ObjectNode(source, nameIndex)
  local key = EraSources.ObjectKey(source, nameIndex)
  if key then
    return key, true
  end
  if type(nameIndex) ~= "number" or nameIndex ~= math.floor(nameIndex) then
    return nil
  end
  if nameIndex < 1 or nameIndex >= NOPAGE_NAMES then
    return nil
  end
  return Graph.Key("object", -(NOPAGE_BASE + nameIndex)), false
end

-- The two packed encodings the table carries, both read with nothing but arithmetic and string
-- .byte: no load, no loadstring and no bit library, because Lua 5.1 has none of the three.
-- itemtree_data/era_sources.py writes them and ../ItemTree-Data/docs/era-sources.md states them.
--
-- A record of one of the x lists is a fixed run of base 91 digits, most significant first. The
-- alphabet is the printable bytes 35 to 126 with 92 (a backslash) left out, so no character the
-- pipeline's Lua writer would have escaped ever appears and one digit is always one byte.
local PACK_BASE = 91
local PACK_FIRST = 35
local PACK_SKIPPED = 92

-- The fields a record carries, in order and in digits, and what the last one means.
local PACK_NAME = 2 -- the name's index into s, 0 for a record that names nothing
local PACK_AREA = 2 -- the area id, 0 for a record with no area
local PACK_VALUE = 2 -- the stock (c = 4), or the chance and the quest only flag
local PACK_CONTAINER = 3 -- the container item's own id (c = 13)
local PACK_TENTHS = 10
local PACK_QUEST_ONLY = 2048

-- What kind of creature a name is, packed into one integer per name. The spans are the pipeline's
-- own, in the order that keeps the commonest values shortest: the band is nearly always 0, 1 or
-- 2, and the family is 0 for everything that is not a beast.
local KIND_TYPE_SPAN = 16
local KIND_LEVEL_SPAN = 128
local KIND_BAND_SPAN = 64

-- Brief N3: a VENDOR's name has a kind too, stored negative as -(2 * kind + both + 1), where both
-- is 1 for a name some creature row names as well and 0 for a vendor only. The one added for the
-- sign keeps a kind of 0 apart from its vendor twin. ../ItemTree-Data/docs/era-sources.md states it.
local KIND_VENDOR_BOTH = 1

-- One packed field, or nil for a string that is not one of ours.
local function packedInt(text, at, digits)
  local value = 0
  for offset = 0, digits - 1 do
    local code = string.byte(text, at + offset)
    if not code then
      return nil
    end
    if code > PACK_SKIPPED then
      code = code - 1
    end
    code = code - PACK_FIRST
    if code < 0 or code >= PACK_BASE then
      return nil
    end
    value = value * PACK_BASE + code
  end
  return value
end

-- How many bytes one record of a category's list takes.
local function recordWidth(category)
  if category == CONTAINER_CATEGORY then
    return PACK_CONTAINER + PACK_VALUE
  end
  return PACK_NAME + PACK_AREA + PACK_VALUE
end

-- One record, as the RAW row shape the rest of this file already reads, so a decoded source and
-- a shipped row go through exactly the same normalise and come out the same shape.
local function packedRow(text, at, category)
  local raw = { c = category }
  local value
  if category == CONTAINER_CATEGORY then
    raw.i = packedInt(text, at, PACK_CONTAINER)
    value = packedInt(text, at + PACK_CONTAINER, PACK_VALUE)
    if not raw.i then
      return nil
    end
  else
    local nameIndex = packedInt(text, at, PACK_NAME)
    local areaId = packedInt(text, at + PACK_NAME, PACK_AREA)
    value = packedInt(text, at + PACK_NAME + PACK_AREA, PACK_VALUE)
    if not nameIndex or not areaId then
      return nil
    end
    if nameIndex > 0 then
      raw.n = nameIndex
    end
    if areaId > 0 then
      raw.a = areaId
    end
  end
  if not value then
    return nil
  end
  if category == VENDOR_CATEGORY then
    if value > 0 then
      raw.k = value
    end
    return raw
  end
  if value >= PACK_QUEST_ONLY then
    -- A list entry never carries the quest id itself: the row says the source is quest only
    -- and names no quest, which is the documented shorter wording.
    raw.o = 1
    value = value - PACK_QUEST_ONLY
  end
  if value > 0 then
    raw.p = value / PACK_TENTHS
  end
  return raw
end

-- One normalised row: the plain words the rest of Core reads, with no index, no faction number
-- and no string table left in it.
--
--   category  the word EraSources.CATEGORIES gives the row's c
--   label     the words the row is named by, which is the node's name. nil for a container row,
--             because the item on the other end of it names itself
--   note      the qualifier the row's words end with: a level band, a limited stock, "only
--             while on a quest". Core/Sources.lua writes them and the pane draws them
--   name      the creature, the vendor, the object or the quest, where the table states one
--   nameIndex that name's place in the string table, which is what E:KindOf is keyed by
--   area      the area the source was recorded in, where the table states one
--   areaId    that area's id
--   questId   the quest that hands the item over (a quest row)
--   onQuest   the quest that has to be in the log for this source to give the item (an o row)
--   faction   "Alliance" or "Horde", translated, where the table states a side
--   side      a quest row's side as its number, 1 Alliance or 2 Horde, or nil (brief T2b)
--   chance    the drop chance as a percentage, or nil where none is known
--   stock     a limited stock vendor's stock count
--   container the container item's own id (a container row)
--   summary   true for the row that stands for a whole category
--   total     how many sources that category has in all (a summary row)
--   more      how many of them the rows above it did not name (a summary row)
--   key       the node the row's edge points at
--   dedupe    the name the row stands for, for the drop in Core/Graph.lua, or nil where the row
--             points at a real node and the ordinary key on key merge can see it
--   edge      the edge type it is drawn as
--   group     the category it is filed under, translated
--   zone      what the row's zone column says, where that is not the node's own name
local function place(row, spec)
  row.edge = T[spec.edge]
  row.group = L[spec.group]
  return row
end

-- A quest row, for the quest the table states and for each of the further quests that hand the
-- same item over. A quest with no side stated is everybody's and says nothing about a side.
--
-- The side goes in the row's zone slot deliberately, the way a vendor's does. Era states no area
-- for either, so the slot is empty, and in the Sources view that slot is one dim column with no
-- header over it: the column says the one thing the table knows about where this row applies.
-- Nothing downstream reads it as a place. Core/Sources.lua draws it, UI/Tree.lua puts it in the
-- column, the row's tooltip and the search box, and the dedupe matches on the row's name.
local function questRow(source, questId, nameIndex, faction)
  if type(questId) ~= "number" then
    return nil
  end
  local name = stringAt(source, nameIndex)
  if not name then
    return nil
  end
  local side = factionWord(faction)
  return place({
    category = "quest",
    label = name,
    name = name,
    nameIndex = nameIndex,
    dedupe = name,
    questId = questId,
    faction = side,
    -- Brief T2b: the side as its number, 1 or 2 (3 and none are nil), for the edge's faction.
    side = (faction == 1 or faction == 2) and faction or nil,
    zone = side,
    key = Graph.Key("quest", questId),
  }, PLACES.quest)
end

-- The words a row that only gives the item on a quest ends with, and the level band of a group,
-- joined the way Core/Sources.lua joins them.
local function conditionNote(raw, questTitle)
  if raw.o == nil then
    return nil
  end
  local title = nil
  if type(raw.q) == "number" and type(questTitle) == "function" then
    local ok, answer = pcall(questTitle, raw.q)
    if ok and type(answer) == "string" and answer ~= "" then
      title = answer
    end
  end
  return phrase("OnlyQuest", title)
end

local function bandNote(raw)
  return phrase("LevelBand", raw.lo, raw.hi)
end

-- The row that stands for a whole category: "Show 239 more, level 11 to 36" under the three rows
-- that named the best of the group, or "Show 184 vendors" where the pipeline named none at all.
--
-- t is the TOTAL the category has on this item, so what is left is t less the rows this client
-- actually drew: a named row the table could not resolve is one more thing the summary stands
-- for. A summary that is left with nothing to say is no row at all.
--
-- The words say "Show" only where the table really ships the list behind the row, because they
-- are an offer: a category whose list is not shipped (every c = 5 world drop, and anything a
-- later pipeline summarises without listing) keeps the plain "and 239 more" and does nothing at
-- all when it is pressed. listed is how many records that list holds, counted from the length of
-- the packed string, so nothing is decoded to write the row.
local function summaryRow(source, raw, category, spec, itemId, drawn, questTitle)
  local total = tonumber(raw.t)
  if not total then
    return nil
  end
  local named = drawn[raw.c] or 0
  local more = total - named
  local listed = EraSources.MoreCount(source, itemId, raw.c)
  local label
  if named > 0 then
    label = listed > 0 and phrase("ShowMoreText", more) or phrase("MoreText", more)
  else
    local counted = phrase("GroupCount", more, category)
    label = listed > 0 and phrase("ShowText", counted) or counted
  end
  if type(label) ~= "string" or label == "" then
    return nil
  end
  local key = summaryId(itemId, raw.c)
  if not key then
    return nil
  end
  return place({
    category = category,
    label = label,
    note = phrase("Note", bandNote(raw), conditionNote(raw, questTitle)),
    summary = true,
    total = total,
    more = more,
    listed = listed,
    key = Graph.Key(spec.summary, key),
  }, spec)
end

-- The table's own row, normalised, or nil where it promises something it does not carry: a
-- creature or a vendor with no name, a fishing row with neither a pool nor a zone, a category
-- from a later pipeline. itemId and drawn are what a summary row needs: the item it belongs to
-- and how many rows of its own category have been drawn above it.
local function normalise(source, raw, itemId, drawn, questTitle)
  local category = EraSources.CATEGORIES[raw.c]
  local spec = category and PLACES[category] or nil
  if not spec then
    return nil
  end
  if raw.t ~= nil and category ~= "world" then
    return summaryRow(source, raw, category, spec, itemId, drawn, questTitle)
  end
  if category == "quest" then
    return questRow(source, raw.q, raw.n, raw.f)
  end
  local chance = chanceOf(raw.p)
  local note = phrase("Note", bandNote(raw), conditionNote(raw, questTitle))
  local onQuest = nil
  if raw.o ~= nil then
    onQuest = raw.q
  end
  if category == "world" then
    -- The one row the table states no place and no creature for. It stands for every creature
    -- the fan out rule would not list, so it carries a total and a band like a summary row and
    -- keeps the shared node: the band is a qualifier on the row, so the node is still called
    -- "World drop" wherever else it is drawn.
    return place({
      category = category,
      label = L[WORLD_DROP],
      note = note,
      chance = chance,
      total = tonumber(raw.t),
      onQuest = onQuest,
      key = Graph.Key("npc", WORLD_ID),
    }, spec)
  end
  if category == "container" then
    -- A real edge to the container item, which this build names itself: the row wears that
    -- item's own icon and quality and opens like any other item row. Nothing is named here and
    -- nothing is deduped by name, because the key on key merge already sees a live sighting of
    -- the same container.
    local containerId = tonumber(raw.i)
    if not containerId then
      return nil
    end
    return place({
      category = category,
      note = note,
      chance = chance,
      container = containerId,
      onQuest = onQuest,
      key = Graph.Key("item", containerId),
    }, spec)
  end
  local name = stringAt(source, raw.n)
  local area = areaName(source, raw.a)
  -- A fishing row that states a zone and no pool reads as the place, and its node is the zone
  -- itself. (A herb or a vein never reaches here: see NODES and addRow below.)
  if category == "fished" and not name and area then
    return place({
      category = category,
      label = area,
      note = note,
      area = area,
      areaId = raw.a,
      chance = chance,
      onQuest = onQuest,
      zone = area,
      key = Graph.Key("zone", raw.a),
    }, spec)
  end
  if not name then
    return nil
  end
  -- A creature, a vendor or an object: a row names it by its name, so the node is keyed by the
  -- name's CMaNGOS id (ci for a creature or a vendor, oi for an object; brief EK2), negated so it can
  -- never collide with a real creature or object id, and by the area where the table states one, so
  -- the same chest in two zones stays the two rows the contract lists (EraSources.PlacedKey).
  --
  -- A pocket takes the same pair out of a range of its own (EraSources.PocketKey), so the creature
  -- you steal from and the same creature dropping the item are two nodes and two edges rather than
  -- one of each.
  --
  -- A creature or a vendor row that states no place points at the creature's own PAGE, which
  -- brief EK1 keys by its creature id (EraSources.CreatureNode), and an object's row at the object's
  -- page (EraSources.ObjectNode). A name the table states no id for has no page and no row key: its
  -- row is still drawn, on a node of this file's own that opens nothing (noPage).
  local key, noPage
  if spec.kind == "npc" then
    local creatureId = EraSources.CreatureIdOf(source, raw.n)
    if POCKETS[category] then
      key = EraSources.PocketKey(creatureId, raw.a)
    else
      key = EraSources.PlacedKey("npc", creatureId, raw.a)
    end
    if not key then
      local paged
      key, paged = EraSources.CreatureNode(source, raw.n)
      noPage = key ~= nil and not paged or nil
    end
  else
    -- Brief EK1 2c: an object row with no place points at the object's page, keyed by its
    -- gameobject id (EraSources.ObjectNode), or at a node that is no page where oi states none.
    key = EraSources.PlacedKey(spec.kind, EraSources.ObjectIdOf(source, raw.n), raw.a)
    if not key then
      local paged
      key, paged = EraSources.ObjectNode(source, raw.n)
      noPage = key ~= nil and not paged or nil
    end
  end
  if not key then
    return nil
  end
  if category == "vendor" then
    return place({
      category = category,
      label = name,
      name = name,
      nameIndex = raw.n,
      dedupe = name,
      note = phrase("Note", note, phrase("LimitedStock", raw.k)),
      stock = raw.k,
      faction = factionWord(raw.f),
      -- The area where the table states one, and the side where it does not: both answer the
      -- one question the dim column beside a row asks, which is where this row applies.
      zone = area or factionWord(raw.f),
      areaId = raw.a,
      area = area,
      key = key,
      noPage = noPage,
    }, spec)
  end
  return place({
    category = category,
    label = name,
    name = name,
    nameIndex = raw.n,
    dedupe = name,
    note = note,
    area = area,
    areaId = raw.a,
    chance = chance,
    onQuest = onQuest,
    zone = area,
    key = key,
    noPage = noPage,
  }, spec)
end

-- A gathering NODE row (brief D6): the node's name, its chance, the group "Gathered from" or
-- "Mined from", and an empty list its zone rows go into. nil for a row that names nothing, which
-- the contract never ships for a herb or a vein.
local function nodeRow(source, raw, category, itemId, questTitle)
  local name = stringAt(source, raw.n)
  if not name then
    return nil
  end
  local onQuest = nil
  if raw.o ~= nil then
    onQuest = raw.q
  end
  return place({
    category = category,
    node = true,
    label = name,
    name = name,
    nameIndex = raw.n,
    dedupe = name,
    note = phrase("Note", bandNote(raw), conditionNote(raw, questTitle)),
    chance = chanceOf(raw.p),
    onQuest = onQuest,
    zones = {},
    -- Brief EK2: keyed by the item and the node's gameobject id (EraSources.NodeKey); an id past the
    -- spans (or none) falls back to the object's page, never to its name's place by hand.
    key = EraSources.NodeKey(itemId, EraSources.ObjectIdOf(source, raw.n)) or EraSources.ObjectNode(source, raw.n),
  }, PLACES[category])
end

-- Whether an area is a place with no map on this build, which is every instance. A table that
-- ships no zm at all (one compiled before the map pins) says nothing about any area, so nothing
-- is inside there.
local function insideArea(source, areaId)
  local maps = source.zm
  if type(maps) ~= "table" or next(maps) == nil then
    return false
  end
  return EraSources.MapOf(source, areaId) == nil
end

-- One of the table's rows for a node, as a ZONE row under that node: the zone, the group "Gathered
-- in" or "Mined in", no chance (the node row carries it) and the node's own name, which is what the
-- row's tooltip says beside the zone. inside is true for a zone this build has no map for, which
-- is every instance. A row the table places nowhere adds no zone.
local function addZone(source, node, raw)
  local area = areaName(source, raw.a)
  if not area then
    return
  end
  local zones = node.zones
  zones[#zones + 1] = place({
    category = node.category,
    label = area,
    name = area,
    area = area,
    areaId = raw.a,
    zone = area,
    nodeName = node.name,
    inside = insideArea(source, raw.a),
    -- Brief EK2: the node in that zone, by the node's gameobject id (EraSources.GatheredKey).
    key = EraSources.GatheredKey(EraSources.ObjectIdOf(source, raw.n), raw.a) or Graph.Key("zone", raw.a),
  }, NODES[node.category])
end

-- What a finished node row's zone column says: how many zones it opens onto, or, for a node that
-- stands only inside instances, the instance itself, with no zone rows under it at all (the way a
-- creature row inside one names it). A node the table places nowhere says nothing there.
local function finishNode(node)
  local zones = node.zones
  if #zones == 0 then
    return
  end
  local open, inside = 0, {}
  for _, zone in ipairs(zones) do
    if zone.inside then
      inside[#inside + 1] = zone.area
    else
      open = open + 1
    end
  end
  if open == 0 then
    node.zone = table.concat(inside, ", ")
    node.inside = true
    node.zones = {}
    return
  end
  node.zone = phrase("ZoneCount", #zones)
end

-- One of the table's rows onto a list being built, which is every row but a herb's or a vein's
-- normalised on its own. A herb or a vein row joins the node row above it when it names the same
-- node, and starts a new one when it does not, so the cap the pipeline counts in nodes is drawn
-- in nodes too: drawn counts NODES for those two categories, which is what the summary row's t
-- is counted in.
local function addRow(out, drawn, source, entry, itemId, questTitle)
  local category = EraSources.CATEGORIES[entry.c]
  if NODES[category] and entry.t == nil then
    local node = out[#out]
    if not (node and node.node and node.category == category and node.nameIndex == entry.n) then
      node = nodeRow(source, entry, category, itemId, questTitle)
      if not node then
        return nil
      end
      out[#out + 1] = node
      drawn[entry.c] = (drawn[entry.c] or 0) + 1
    end
    addZone(source, node, entry)
    return node
  end
  local row = normalise(source, entry, itemId, drawn, questTitle)
  if row then
    out[#out + 1] = row
    if not row.summary and type(entry.c) == "number" then
      drawn[entry.c] = (drawn[entry.c] or 0) + 1
    end
  end
  return row
end

local function finishNodes(out)
  for _, row in ipairs(out) do
    if row.node then
      finishNode(row)
    end
  end
  return out
end

-- Every normalised row for one item, in the order the table states them, which is the order they
-- are drawn: category ascending, the sources anyone can reach before the ones a quest unlocks,
-- best chance first, and the summary row last. Nothing here sorts anything.
--
-- questTitle is optional and is how an "only on the quest X" row is titled: a function taking a
-- quest id and answering its name or nil. Without one such a row says the shorter wording, which
-- is what the module level caller (a spec, the harness) gets.
function EraSources.Rows(source, itemId, questTitle)
  if type(source) ~= "table" or type(itemId) ~= "number" then
    return EMPTY
  end
  local list = rowList(source, itemId)
  if list == EMPTY then
    return EMPTY
  end
  local out, drawn = {}, {}
  for _, entry in ipairs(list) do
    if type(entry) == "table" then
      local row = addRow(out, drawn, source, entry, itemId, questTitle)
      if row then
        -- The further quests that hand the same item over, which sit inside the quest's own row.
        if row.category == "quest" then
          for _, extra in ipairs(type(entry.m) == "table" and entry.m or EMPTY) do
            if type(extra) == "table" then
              local more = questRow(source, extra.q, extra.n, extra.f)
              if more then
                out[#out + 1] = more
                drawn[QUEST_CATEGORY] = (drawn[QUEST_CATEGORY] or 0) + 1
              end
            end
          end
        end
      end
    end
  end
  return finishNodes(out)
end

--------------------------------------------------------------------------------
-- The other side of a source row: a CREATURE, and what comes off it (brief E57)
--------------------------------------------------------------------------------

-- Every creature row points at a node of this file's own making, so the window can be rooted on
-- one, and until brief E57 that page was empty: the left column said "Not in ItemTree data" and
-- the four item tabs all read (0). Nothing new was needed to fill it. The table already states
-- what kind of creature a name is (ck), what the client draws its portrait from (cd) and every
-- item it gives up; the one thing missing was an index the other way round, because the table is
-- keyed by item.
--
-- The four categories whose n names a CREATURE, and the category a creature page files each of
-- them under. This table IS the extension point the owner asked for: "note there will be herbable
-- / minable monsters in Forever but we won't know what they are yet". When the collector first
-- sees one, a herb and a vein category are ONE entry each here,
--
--   [8] = { edge = "CREATURE_GATHERED", group = "Gathered from", order = 40 },
--   [9] = { edge = "CREATURE_MINED", group = "Mined from", order = 50 },
--
-- plus the edge type in Core/Edges.lua and the three words in Core/ViewModel.lua's group tables,
-- and nothing else in the addon changes: the categories, the counts, the badges, the order, the
-- sidebar and the search box all read this. docs/era-sources-creatures.md says the same.
--
-- order is the contract's own category order (../ItemTree-Data/docs/era-sources.md, the c column).
-- Boss and creature share one group because a player reads both as "this thing drops it", exactly
-- as PLACES above files both under "Drops from" on an item's own page.
EraSources.CREATURE_LOOT = {
  [1] = { edge = "CREATURE_DROPS", group = "Drops", order = 10 },
  [6] = { edge = "CREATURE_DROPS", group = "Drops", order = 10 },
  [7] = { edge = "CREATURE_SKINNED", group = "Skinned", order = 20 },
  [12] = { edge = "CREATURE_POCKETED", group = "Pickpocketed", order = 30 },
}

-- Brief OL1: the one category an OBJECT's Loot tab draws (a chest's "Found in" rows read from the
-- chest's end) and the one an openable item's Contains tab draws (the container rows read from the
-- container's end), in CREATURE_LOOT's shape so the same reader turns either into rows.
EraSources.OBJECT_LOOT = {
  [11] = { edge = "OBJECT_CONTAINS", group = "Contains", order = 10 },
}
EraSources.CONTAINER_LOOT = {
  [13] = { edge = "CONTAINS", group = "Contains", order = 10 },
}

-- The category a boss row uses, so a creature page can say "Boss" without naming the number
-- twice.
local BOSS_CATEGORY = 1

-- The name in the string table behind one of this file's own npc node ids, and the place the key
-- states where it states one. Pure over source, the shipped table: since brief EK2 every one of
-- these keys holds a CMaNGOS creature id, never a name's place, so the name always comes back
-- through ci (EraSources.CreatureNameIndex) and without a table nothing answers.
--
-- Of the kinds of npc id, these answer:
--   a plain negative id, a creature's PAGE (brief EK1), keyed by its creature id (EraSources.PageName;
--     a merged name's negative id answers nothing, brief EK1 2b);
--   a placed id (EraSources.PlacedId) and a pocket id (EraSources.PocketId): the creature id's
--     name, merged or not, and the area the key states (none for a pocket that states none);
--   a positive id where it is a merged name's page (cm, brief EK1 2b).
-- And these answer nothing on purpose: a summary node stands for a GROUP of sources and names
-- nothing; the world drop shares id 0, which says "somewhere out in the world"; a no page node is
-- no page; the gathered and node ranges are object and zone keys; a retired window (0.1.3 to EK1)
-- holds a name's old place and is read by nothing but Core/History.lua's conversion.
function EraSources.CreatureAt(id, source)
  if type(id) ~= "number" or id == 0 or id ~= math.floor(id) then
    return nil
  end
  -- Brief EK1 2b: a positive id is a merged name's page where cm says so (out of source).
  if id > 0 then
    return mergedNameOf(source, id)
  end
  if isPageId(id) then
    -- A plain negative id is a creature's page (a row the table knew no area for points there too),
    -- keyed by its creature id: the name comes back through ci.
    local nameIndex = pageNameOf(source, id)
    if not nameIndex then
      return nil
    end
    return nameIndex, nil
  end
  local creatureId, areaId = pairedParts(PLACED, id, 1)
  if not creatureId then
    creatureId, areaId = pairedParts(POCKET, id, 0)
  end
  local nameIndex = creatureId and EraSources.CreatureNameIndex(source, creatureId) or nil
  if not nameIndex then
    return nil
  end
  if areaId == 0 then
    areaId = nil
  end
  return nameIndex, areaId
end

-- How many numbers one entry of the loot index takes, and what each of them is: the item, the
-- value and the area. The VALUE is the chance in tenths of a percent plus PACK_QUEST_ONLY where
-- the source is quest only and 0 for "we do not know", which is exactly what a packed list states,
-- so a shipped row and a listed record are held the same way and read by the same code. The area
-- is 0 for a row that states no place.
--
-- Three plain numbers in one flat array rather than a table per entry, because this build has
-- 22,784 of them: measured on the real table, a table per entry is 6.9 MB and this is 2.6 MB, for
-- a page that is opened once and read. The reader turns the handful one creature has into rows.
local LOOT_STRIDE = 3

-- Brief OL1: the categories the loot index pass reads, the four creature ones plus a chest's
-- "Found in" rows (an object's Loot tab) and a container's rows (an item's Contains tab).
local LOOT_SCAN = { [OBJECT_CATEGORY] = true, [CONTAINER_CATEGORY] = true }
for category in pairs(EraSources.CREATURE_LOOT) do
  LOOT_SCAN[category] = true
end

-- Creature to the items it gives up, built in ONE pass over the whole table.
--
-- The table is keyed by item, so the only way to answer a question about a creature is to walk it,
-- exactly as EraSources.QuestIndex walks it for a quest. This pass is wider than that one, because
-- a creature the fan out rules never named is in a packed list rather than in r: it reads the
-- 18,597 shipped rows AND decodes every list of one of the four creature categories (859 of the
-- 2,262 lists, 17,611 records), which is 15 ms and 2.6 MB on build 1.60.1.69913, measured in
-- tests/spec/era_creature_spec.lua. The other 1,403 lists are vendors, objects and containers, and
-- a vendor is not a creature: ck covers exactly the names these four categories use and nothing
-- else, so there is nothing in them for a creature to find.
--
-- It is built on the first creature page OPENED and then kept (E:_LootIndex). Nothing at load and
-- nothing on the way to a drawn tree asks for it, which is why era.decodes stays 0 for an ordinary
-- tree build: this pass keeps its own count in index.lists and E:LootCounts reads it back, and the
-- one number era.decodes has always meant (lists decoded through E:More, for a summary row the
-- player opened) is untouched by it.
--
--   loot[nameIndex][category]  a flat array of LOOT_STRIDE numbers per entry, in item id order
--   entries                    how many entries there are in all
--   lists                      how many packed lists this pass decoded
--   names                      how many creature names carry anything at all
--
-- Brief OL1 widened the same pass to the two lists it used to skip that a page reads the other way
-- round, each kept apart from loot so nothing a creature page reads (its loot, its counts, its
-- locked items) can see them:
--   objects[nameIndex][11]     a chest's "Found in" rows (category 11), keyed by the object's name
--                              exactly as loot is keyed by a creature's, for an object's Loot tab
--   containers[itemId]         a container item's contents (category 13 rows, keyed by the
--                              container item's own id i), area always 0, for an item's Contains tab
--   objectEntries, objectLists, objectNames, containerEntries, containerLists  their own counts
-- On build 1.60.1.70291 that is 1,797 more lists for objects and 135 for containers; the cost of
-- the whole pass is measured in tests/spec/era_creature_spec.lua. Still built once, on the first
-- creature, object or openable item page OPENED.
--
-- Brief PF3b: check, where given, is called once per item row (Core/Data.lua Data.SliceCheck, which
-- lets the login slicer carry the pass over frames); the index is the same either way. Measured over
-- the shipped 1.60.1.70334 data offline the whole pass is about 80 ms, the first NPC page's 241 ms
-- hitch in the client (out-pf3b/REPORT.md), so the slicer builds it at login (Data.PRELOAD_WARM).
function EraSources.LootIndex(source, check)
  local index = {
    loot = {},
    entries = 0,
    lists = 0,
    names = 0,
    objects = {},
    objectEntries = 0,
    objectLists = 0,
    objectNames = 0,
    containers = {},
    containerEntries = 0,
    containerLists = 0,
  }
  local rows = type(source) == "table" and source.r or nil
  if type(rows) ~= "table" then
    return index
  end
  local loot = index.loot

  -- An object's row goes to index.objects and a container's to index.containers (keyed by the
  -- container item's id in the nameIndex slot), so the creature side's buckets and counts are
  -- exactly what they were before brief OL1.
  local function add(nameIndex, category, itemId, value, areaId)
    if type(nameIndex) ~= "number" or nameIndex < 1 or type(itemId) ~= "number" then
      return
    end
    if category == CONTAINER_CATEGORY then
      local bucket = index.containers[nameIndex]
      if not bucket then
        bucket = {}
        index.containers[nameIndex] = bucket
      end
      local at = #bucket
      bucket[at + 1] = itemId
      bucket[at + 2] = value
      bucket[at + 3] = 0
      index.containerEntries = index.containerEntries + 1
      return
    end
    local held = loot
    if category == OBJECT_CATEGORY then
      held = index.objects
    end
    local byCategory = held[nameIndex]
    if not byCategory then
      byCategory = {}
      held[nameIndex] = byCategory
      if held == loot then
        index.names = index.names + 1
      else
        index.objectNames = index.objectNames + 1
      end
    end
    local bucket = byCategory[category]
    if not bucket then
      bucket = {}
      byCategory[category] = bucket
    end
    local at = #bucket
    bucket[at + 1] = itemId
    bucket[at + 2] = value
    bucket[at + 3] = areaId
    if held == loot then
      index.entries = index.entries + 1
    else
      index.objectEntries = index.objectEntries + 1
    end
  end

  -- pairs walks a table differently from one run to the next and every bucket keeps the order it
  -- was built in, so one creature's loot would otherwise swap places between two loads of one
  -- build. The same reason EraSources.QuestIndex sorts (brief RB4: sorted once, sortedItemIds).
  local ids = sortedItemIds(rows)

  local lists = type(source.xl) == "table" and source.xl or nil
  local scan = { only = LOOT_SCAN, onlyKey = "c" }
  for _, itemId in ipairs(ids) do
    if check then
      check()
    end
    for _, raw in scanRows(source, itemId, scan) do
      if type(raw) == "table" and raw.t == nil and LOOT_SCAN[raw.c] then
        local value = 0
        local chance = chanceOf(raw.p)
        if chance then
          value = math.floor(chance * PACK_TENTHS + 0.5)
        end
        if raw.o ~= nil then
          value = value + PACK_QUEST_ONLY
        end
        if raw.c == CONTAINER_CATEGORY then
          add(tonumber(raw.i), raw.c, itemId, value, 0)
        else
          add(raw.n, raw.c, itemId, value, tonumber(raw.a) or 0)
        end
      end
    end
    -- And the rest of every capped creature list, which is where the creatures the fan out rules
    -- never named live: 17,611 of the 22,784 entries. The lookup is inlined rather than asking
    -- packedList, which is a local declared further down this file.
    local byCategory = type(source.x) == "table" and source.x[itemId] or nil
    if type(byCategory) == "table" and lists then
      for category, slot in pairs(byCategory) do
        if LOOT_SCAN[category] and type(slot) == "number" then
          local text = lists[slot]
          local width = recordWidth(category)
          if type(text) == "string" and text ~= "" and #text % width == 0 then
            if category == CONTAINER_CATEGORY then
              -- Brief OL1: a container record is the container item's id and the value, no name
              -- and no area (packedRow reads it the same way).
              index.containerLists = index.containerLists + 1
              for at = 1, #text, width do
                local containerId = packedInt(text, at, PACK_CONTAINER)
                local value = packedInt(text, at + PACK_CONTAINER, PACK_VALUE)
                if containerId and containerId > 0 and value then
                  add(containerId, category, itemId, value, 0)
                end
              end
            else
              if category == OBJECT_CATEGORY then
                index.objectLists = index.objectLists + 1
              else
                index.lists = index.lists + 1
              end
              for at = 1, #text, width do
                local nameIndex = packedInt(text, at, PACK_NAME)
                local areaId = packedInt(text, at + PACK_NAME, PACK_AREA)
                local value = packedInt(text, at + PACK_NAME + PACK_AREA, PACK_VALUE)
                if nameIndex and nameIndex > 0 and areaId and value then
                  add(nameIndex, category, itemId, value, areaId)
                end
              end
            end
          end
        end
      end
    end
  end
  return index
end

-- The quest a NAMED row states behind a creature's quest only drop, or nil.
--
-- A packed record never carries a quest id, by the contract's own design, so a listed source keeps
-- the shorter "only while on a quest" and only the rows the table ships by name can be titled.
-- This is the handful of lookups one creature page pays rather than a fourth number on all 22,784
-- entries of the index.
local function lootQuestId(source, itemId, category, nameIndex, areaId)
  for _, raw in ipairs(rowList(source, itemId)) do
    if
      type(raw) == "table"
      and raw.c == category
      and raw.n == nameIndex
      and (tonumber(raw.a) or 0) == areaId
      and raw.o ~= nil
    then
      return raw.q
    end
  end
  return nil
end

-- The rows one bucket set of the loot index draws, in the specs' own category order and best
-- chance first inside each (the body CreatureRows always had; brief OL1 shares it with an object's
-- Loot tab and a container's Contains tab). specs maps a category number to its edge, group and
-- order; a category it does not name is left out. nameIndex is only read to title a quest only
-- row, which a creature's rows alone can carry.
local function lootRows(source, nameIndex, byCategory, specs, questTitle)
  if type(byCategory) ~= "table" then
    return EMPTY
  end
  local order = {}
  for category in pairs(byCategory) do
    local spec = specs[category]
    if spec then
      order[#order + 1] = category
    end
  end
  table.sort(order, function(a, b)
    local left, right = specs[a], specs[b]
    if left.order ~= right.order then
      return left.order < right.order
    end
    return a < b
  end)

  local out = {}
  for _, category in ipairs(order) do
    local spec = specs[category]
    local bucket = byCategory[category]
    local entries = {}
    for at = 1, #bucket, LOOT_STRIDE do
      local itemId = bucket[at]
      local value = bucket[at + 1] or 0
      local areaId = bucket[at + 2] or 0
      local questOnly = false
      if value >= PACK_QUEST_ONLY then
        questOnly = true
        value = value - PACK_QUEST_ONLY
      end
      entries[#entries + 1] = {
        item = itemId,
        chance = chanceOf(value > 0 and value / PACK_TENTHS or nil),
        areaId = areaId > 0 and areaId or nil,
        onQuest = questOnly,
      }
    end
    table.sort(entries, function(a, b)
      local left = a.chance or -1
      local right = b.chance or -1
      if left ~= right then
        return left > right
      end
      return a.item < b.item
    end)
    for _, entry in ipairs(entries) do
      local raw = { c = category }
      if entry.onQuest then
        raw.o = 1
        raw.q = lootQuestId(source, entry.item, category, nameIndex, entry.areaId or 0)
      end
      local area = areaName(source, entry.areaId)
      out[#out + 1] = place({
        category = EraSources.CATEGORIES[category],
        item = entry.item,
        note = conditionNote(raw, questTitle),
        chance = entry.chance,
        area = area,
        areaId = entry.areaId,
        zone = area,
        key = Graph.Key("item", entry.item),
      }, { edge = spec.edge, group = spec.group })
    end
  end
  return out
end

-- One creature's loot, as the rows a creature page draws: the categories in the contract's own
-- order, and inside each of them the best chance first.
--
-- Each row carries the same fields a normalised source row does (category, group, edge, note, key,
-- chance, area, areaId, zone) plus the item it names in `item`, so Core/Sources.lua and the pane
-- read a creature's loot with exactly the code that reads an item's sources. The row names no
-- creature and no place of its own: the item on the other end of it is named by this build's own
-- data, the way a container row is.
--
-- Nothing here is sorted by the table, because the table's order is per item and this is per
-- creature: best chance first, then by item id so the answer is the same on every machine, and a
-- source the table states no chance for sorts last rather than first. questTitle is optional and
-- is how "only on the quest X" is titled, exactly as EraSources.Rows takes it.
function EraSources.CreatureRows(source, nameIndex, index, questTitle)
  if type(source) ~= "table" or type(nameIndex) ~= "number" then
    return EMPTY
  end
  if type(index) ~= "table" or type(index.loot) ~= "table" then
    index = EraSources.LootIndex(source)
  end
  return lootRows(source, nameIndex, index.loot[nameIndex], EraSources.CREATURE_LOOT, questTitle)
end

-- Brief OL1: what one Classic Era OBJECT holds (a chest's "Found in" rows read the other way
-- round), as the rows an object's Loot tab draws, best chance first, in exactly the shape
-- EraSources.CreatureRows answers: one row per item and place the table states, so an item a chest
-- gives in two zones at two rates is two rows, each naming its zone. index is an
-- EraSources.LootIndex, built here for a caller that holds none.
function EraSources.ObjectRows(source, nameIndex, index)
  if type(source) ~= "table" or type(nameIndex) ~= "number" then
    return EMPTY
  end
  if type(index) ~= "table" or type(index.objects) ~= "table" then
    index = EraSources.LootIndex(source)
  end
  return lootRows(source, nameIndex, index.objects[nameIndex], EraSources.OBJECT_LOOT, nil)
end

-- Brief OL1: what one container ITEM holds (the table's category 13 rows, keyed by the container's
-- own item id), as the rows an openable item's Contains tab draws, best chance first. The same
-- shape again; a container row states no place, so no row names a zone. index is an
-- EraSources.LootIndex, built here for a caller that holds none.
function EraSources.ContainerRows(source, containerId, index)
  if type(source) ~= "table" or type(containerId) ~= "number" then
    return EMPTY
  end
  if type(index) ~= "table" or type(index.containers) ~= "table" then
    index = EraSources.LootIndex(source)
  end
  local bucket = index.containers[containerId]
  if type(bucket) ~= "table" then
    return EMPTY
  end
  return lootRows(source, containerId, { [CONTAINER_CATEGORY] = bucket }, EraSources.CONTAINER_LOOT, nil)
end

-- Everything the table states about one CREATURE rather than about an item, in the shape the left
-- column draws it, or nil for a name the table says nothing about.
--
--   nameIndex  the name's place in the string table, which is what every other lookup is keyed by
--   name       the creature's own name, which is the only thing a player ever reads as its title
--   type       the CreatureType, family the beast family, low and high the level band (ck)
--   display    the id the client draws its model from, or nil (cd)
--   title      brief T2b: the title a quest giving or selling creature carries (st), or nil
--   faction    brief T2b: that name's side, 1 Alliance, 2 Horde, 3 both (cf), or nil
--   boss       true where any boss row in the table names it
--   areaIds    every area a row naming it states, ascending, and zones those areas' own names
--   total      how many items come off it in all
--
-- A name with no kind is not a creature: ck covers exactly the names the four creature categories
-- use, so a vendor, an object, a gathering node and a quest all answer nothing here and keep the
-- four item tabs they have always had. index is an EraSources.LootIndex, built here for a caller
-- that holds none.
function EraSources.CreatureFacts(source, nameIndex, index)
  if type(source) ~= "table" or type(nameIndex) ~= "number" then
    return nil
  end
  local name = stringAt(source, nameIndex)
  local creatureType, family, low, high, role = EraSources.KindOf(source, nameIndex)
  if not name or not creatureType then
    return nil
  end
  if type(index) ~= "table" or type(index.loot) ~= "table" then
    index = EraSources.LootIndex(source)
  end
  local facts = {
    nameIndex = nameIndex,
    name = name,
    type = creatureType,
    family = family,
    low = low,
    high = high,
    -- Brief N3: "creature", "vendor" (a vendor no creature row names, whose page is a vendor's) or
    -- "both".
    role = role,
    display = EraSources.DisplayOf(source, nameIndex),
    -- Brief T2b: a creature that gives quests or sells has a title and a side too; nil for the rest.
    title = EraSources.Title(source, nameIndex),
    faction = EraSources.Faction(source, nameIndex),
    areaIds = {},
    zones = {},
    total = 0,
  }
  local byCategory = index.loot[nameIndex]
  local seen = {}
  for category, bucket in pairs(type(byCategory) == "table" and byCategory or EMPTY) do
    if category == BOSS_CATEGORY then
      facts.boss = true
    end
    facts.total = facts.total + math.floor(#bucket / LOOT_STRIDE)
    for at = LOOT_STRIDE, #bucket, LOOT_STRIDE do
      local areaId = bucket[at]
      if type(areaId) == "number" and areaId > 0 and not seen[areaId] then
        seen[areaId] = true
        facts.areaIds[#facts.areaIds + 1] = areaId
      end
    end
  end
  -- pairs walked the categories, so the places are sorted rather than left in whatever order the
  -- walk found them: a zone list that reordered itself between two loads of one build would be a
  -- page that reads differently every time it is opened.
  table.sort(facts.areaIds)
  for _, areaId in ipairs(facts.areaIds) do
    facts.zones[#facts.zones + 1] = { areaId = areaId, name = areaName(source, areaId) }
  end
  return facts
end

-- Everything the table states ABOUT a quest rather than about an item: the items it hands over,
-- the items that only drop while a player is on it, the side it belongs to and its title.
--
-- The table indexes items, so the only way to answer a question about a quest is one pass over
-- every row: 18,597 rows on build 1.60.1.69913, about ten milliseconds, measured on the real
-- module in tests/spec/era_quest_facts_spec.lua. The pass reads the table's OWN rows rather than
-- normalised ones, so it allocates only the buckets a quest really has, and it never touches the
-- packed lists (x and xl): a record in one of those carries no quest id at all, by the contract's
-- own design, so there is nothing in them for a quest to find.
--
-- E:QuestFacts builds it on the first quest node that is opened and then keeps it. Nothing builds
-- it at load and nothing on the way to a drawn tree asks for it.
--
--   rewards[questId]  the item ids a c = 3 row hands the player on that quest, ascending
--   drops[questId]    { { item = itemId, rows = { the table's own rows } } }, the items that only
--                     drop while the player is on the quest (o = 1, with q naming this quest),
--                     item id ascending, each with every row that says so
--   sides[questId]    the f a c = 3 row states: 1 Alliance, 2 Horde, 3 both sides. Absent means
--                     the quest is open to everyone, which is not the same fact as 3
--   titles[questId]   the title a c = 3 row names the quest by. qt holds the titles of the quests
--                     no c = 3 row names, and EraSources.QuestTitleAt reads those
--
-- Brief RB4: check, where given, is called once per item (Core/Data.lua Data.SliceCheck), so the
-- login slicer carries the pass over frames: over the shipped 1.60.1.70425 data it costs 50 to
-- 110 ms offline, which was the owner's 87 ms info panel on his first predicted quest page.
function EraSources.QuestIndex(source, check)
  local index = { rewards = {}, drops = {}, sides = {}, titles = {} }
  local rows = type(source) == "table" and source.r or nil
  if type(rows) ~= "table" then
    return index
  end
  -- pairs walks a table differently from one run to the next and both buckets keep the order they
  -- were built in, so a quest's items would otherwise swap places between two loads of one build.
  -- Brief RB4: sorted once per table (sortedItemIds).
  local ids = sortedItemIds(rows)

  -- One quest a c = 3 row hands this item over on. The items arrive in id order and one item's
  -- rows are read together, so the same item twice on one quest is the bucket's own last entry.
  local function handsOver(itemId, questId, nameIndex, faction)
    if type(questId) ~= "number" then
      return
    end
    local bucket = index.rewards[questId]
    if not bucket then
      bucket = {}
      index.rewards[questId] = bucket
    end
    if bucket[#bucket] ~= itemId then
      bucket[#bucket + 1] = itemId
    end
    if type(faction) == "number" then
      index.sides[questId] = faction
    end
    local title = stringAt(source, nameIndex)
    if title then
      index.titles[questId] = title
    end
  end

  -- One source that only gives this item while the player is on the quest q names. A summary row
  -- never states a quest (the contract says so), so only named rows reach here.
  local function onlyOn(itemId, questId, raw)
    local bucket = index.drops[questId]
    if not bucket then
      bucket = {}
      index.drops[questId] = bucket
    end
    local held = bucket[#bucket]
    if not held or held.item ~= itemId then
      held = { item = itemId, rows = {} }
      bucket[#bucket + 1] = held
    end
    held.rows[#held.rows + 1] = raw
  end

  -- The rows are scanned (scanRows), so the one row this pass keeps, a quest only drop's, is kept
  -- as a copy of the scan's reused table: the same fields, its m (a fresh table per decode) shared.
  local scan = {}
  for _, itemId in ipairs(ids) do
    if check then
      check()
    end
    for _, raw in scanRows(source, itemId, scan) do
      if type(raw) == "table" then
        if raw.c == QUEST_CATEGORY then
          handsOver(itemId, raw.q, raw.n, raw.f)
          for _, extra in ipairs(type(raw.m) == "table" and raw.m or EMPTY) do
            if type(extra) == "table" then
              handsOver(itemId, extra.q, extra.n, extra.f)
            end
          end
        elseif raw.o ~= nil and raw.t == nil and type(raw.q) == "number" then
          local kept = raw
          if raw == scan.row then
            kept = {}
            for key, value in pairs(raw) do
              kept[key] = value
            end
          end
          onlyOn(itemId, raw.q, kept)
        end
      end
    end
  end
  return index
end

-- Everything the table says about ONE quest, in the shape the interface draws it, or nil for a
-- quest it says nothing about at all.
--
--   questId  the quest asked for
--   title    the title the table gives it, out of qt or out of a c = 3 row, or nil
--   faction  1 Alliance, 2 Horde, 3 both sides, or nil for a quest open to everyone
--   side     that faction in words, or nil: 3 is drawn as nothing, because "both sides" says no
--            more to a player than the quest saying nothing about a side, and the compiled table
--            has never carried one
--   rewards  { { item = itemId } }, the items it hands over, in item id order
--   drops    { { item = itemId, sources = { a normalised row, ... } } }, the items that only drop
--            while the player is on it, each with the sources the table names for it
--   requires { { item = itemId, count = n } }, what it asks the player to bring (qr, brief Q10),
--            in the quest's own slot order; empty for a module that ships no qr
--
-- A drop's sources are normalised exactly as EraSources.Rows normalises an item's own rows, so
-- one piece of interface code reads a quest's sources and an item's. index is an
-- EraSources.QuestIndex, built here for a caller that holds none.
function EraSources.QuestFacts(source, questId, index)
  if type(source) ~= "table" or type(questId) ~= "number" then
    return nil
  end
  if type(index) ~= "table" then
    index = EraSources.QuestIndex(source)
  end
  local facts = { questId = questId, rewards = {}, drops = {}, requires = {} }
  facts.title = EraSources.QuestTitleAt(source, questId)
  if not facts.title and type(index.titles) == "table" then
    facts.title = index.titles[questId]
  end
  local faction = type(index.sides) == "table" and index.sides[questId] or nil
  if type(faction) == "number" then
    facts.faction = faction
    facts.side = factionWord(faction)
  end
  for _, itemId in ipairs((type(index.rewards) == "table" and index.rewards[questId]) or EMPTY) do
    facts.rewards[#facts.rewards + 1] = { item = itemId }
  end
  for _, entry in ipairs((type(index.drops) == "table" and index.drops[questId]) or EMPTY) do
    local sources = {}
    for _, raw in ipairs(entry.rows or EMPTY) do
      -- No quest titler is passed: every row here depends on the very quest being drawn, so
      -- "only on the quest X" would be said once per row about the quest in the header.
      local row = normalise(source, raw, entry.item, {}, nil)
      if row then
        sources[#sources + 1] = row
      end
    end
    facts.drops[#facts.drops + 1] = { item = entry.item, sources = sources }
  end
  for _, pair in ipairs(EraSources.QuestRequires(source, questId)) do
    facts.requires[#facts.requires + 1] = { item = pair[1], count = pair[2] }
  end
  if not facts.title and not facts.faction and #facts.rewards == 0 and #facts.drops == 0 and #facts.requires == 0 then
    return nil
  end
  -- Brief QN1: its place in a chain of same titled quests, where qc states one.
  local chain = EraSources.QuestChain(source, questId)
  if chain then
    facts.c, facts.cl = chain.c, chain.cl
  end
  return facts
end

-- The title the table gives one quest in qt, which is the quests a quest only row names in q, a
-- qg list names or qr carries, and no quest row in the table names anywhere. nil for a quest the
-- table says nothing about.
--
-- A value is one of two shapes (brief Q10, the W12 data build): a NUMBER, an index into s, as it
-- always was, or a STRING, the title itself, which the pipeline writes only for a qr quest whose
-- title s does not hold. Both answer the same string here.
function EraSources.QuestTitleAt(source, questId)
  if type(source) ~= "table" or type(questId) ~= "number" then
    return nil
  end
  local titles = source.qt
  local value = type(titles) == "table" and titles[questId] or nil
  if type(value) == "string" then
    if value ~= "" then
      return value
    end
    return nil
  end
  return stringAt(source, value)
end

--------------------------------------------------------------------------------
-- Brief QF2b (the owner's "Yes to both" of 2026-10-24): the quest pairs the dump swaps
--------------------------------------------------------------------------------

-- The pinned CMaNGOS dump files some same titled pairs' givers, turn ins and chain links under each
-- other's id: A Lesson to Learn 26 is the Night Elf quest in Forever but the dump has Turak Runetotem
-- give it and lead it on to the Horde's Trial of the Lake 28, and 27 the other way round; Could I get a
-- Fishing Flier? 8228 (Horde) is given and taken back by Barrus, 8229 (Alliance) by Grinkle. The
-- pipeline's curated list (ItemTree-Data curated/quest_swaps.json, ours) ships the pairs in Diff.lua as
-- quests.swaps = { [26] = 27, [27] = 26, [8228] = 8229, [8229] = 8228 }: the Classic Era rows of quest
-- A's givers, turn ins and chain belong to quest B, and the other way round. EraSources.lua is GPL and
-- the dump as it is, so it is never changed for this: the readers below read those columns (qg, og, qc,
-- qo, qw) for one id as they would for its pair, at read time, here and nowhere else. The sides are
-- Diff's side lists' already (Core/QuestFlags.lua Side). An older Diff with no swaps key swaps nothing.

-- A spec's own list in Diff's shape, read before Diff. Never set in the client.
EraSources.swapList = nil

-- The validated map for the list it was made from (one slot: Diff is one table for the session).
local swapsFrom, swapsMap = nil, nil

-- Diff's quests.swaps, or nil. Reads Diff only where it is registered or built (Data:Has), so asking
-- never loads anything (Diff ships in ItemTree itself and is there from login).
local function shippedSwaps()
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.Get) ~= "function" then
    return nil
  end
  if type(data.Has) == "function" then
    local okHas, has = pcall(data.Has, data, "Diff")
    if not okHas or not has then
      return nil
    end
  end
  local ok, diff = pcall(data.Get, data, "Diff")
  local quests = ok and type(diff) == "table" and diff.quests or nil
  local swaps = type(quests) == "table" and quests.swaps or nil
  return type(swaps) == "table" and swaps or nil
end

--- The quest pairs whose Classic Era givers, turn ins and chain are read the other way round,
--- { [questId] = its pair }, both ways. Only a pair stated both ways round, of two different positive
--- whole ids, is taken; anything else is not one of ours and swaps nothing. EMPTY where none ships.
--- The map is this file's own and must not be modified.
function EraSources.QuestSwaps()
  local raw = EraSources.swapList
  if type(raw) ~= "table" then
    raw = shippedSwaps()
  end
  if type(raw) ~= "table" then
    return EMPTY
  end
  if swapsFrom == raw and swapsMap then
    return swapsMap
  end
  local function id(value)
    local number = tonumber(value)
    if number and number > 0 and number == math.floor(number) then
      return number
    end
    return nil
  end
  local map = {}
  for key, value in pairs(raw) do
    local a, b = id(key), id(value)
    if a and b and a ~= b and id(raw[b]) == a then
      map[a] = b
    end
  end
  if next(map) == nil then
    map = EMPTY
  end
  swapsFrom, swapsMap = raw, map
  return map
end

--- The quest whose Classic Era givers, turn ins and chain rows are this one's (its pair, where
--- EraSources.QuestSwaps names one), or the quest itself. swaps is a map a caller already holds, or
--- nil to read it.
function EraSources.SwappedQuest(questId, swaps)
  if type(questId) ~= "number" then
    return questId
  end
  local map = type(swaps) == "table" and swaps or EraSources.QuestSwaps()
  return map[questId] or questId
end

-- One decoded list of quest ids with every swapped id read as its pair, in place, sorted again
-- where one moved (the lists are ascending). Answers the list.
local function swapQuestList(list, swaps)
  if type(list) ~= "table" or next(swaps) == nil then
    return list
  end
  local moved = false
  for index, questId in ipairs(list) do
    local pair = swaps[questId]
    if pair then
      list[index] = pair
      moved = true
    end
  end
  if moved then
    table.sort(list)
  end
  return list
end

-- Brief QN1 (the owner, 2026-10-03: "I want numerals on classic quests too"): a quest's place in a
-- chain of quests that share its title, out of qc = { [questId] = { c = position, cl = length } },
-- which the pipeline writes only for a quest with a same titled chain mate. { c, cl } with cl nil
-- where the entry states none, or nil for a quest qc does not hold and for an older module that
-- ships no qc at all. A new table every call. Pure.
-- Brief QF2b: a swapped quest reads its pair's entry (EraSources.SwappedQuest).
function EraSources.QuestChain(source, questId)
  local chains = type(source) == "table" and source.qc or nil
  local entry = type(chains) == "table" and type(questId) == "number" and chains[EraSources.SwappedQuest(questId)]
    or nil
  if type(entry) ~= "table" then
    return nil
  end
  local c, cl = tonumber(entry.c), tonumber(entry.cl)
  if not c or c < 1 or c ~= math.floor(c) then
    return nil
  end
  if not cl or cl < c or cl ~= math.floor(cl) then
    cl = nil
  end
  return { c = c, cl = cl }
end

-- Brief Q10: what a quest asks the player to bring, out of qr. One packed string per quest, a run
-- of fixed 5 byte records in the x lists' alphabet, most significant digit first: the item id in
-- 3 digits, then how many in 2, in the quest's own slot order. The module header states it.
local QR_ITEM = 3
local QR_COUNT = 2
local QR_RECORD = QR_ITEM + QR_COUNT

-- One quest's packed requirements decoded into { { itemId, count }, ... } in slot order, the
-- shape Data/curated/Quests.lua's requires lists take. A record this file cannot read, or one
-- that names item 0, is skipped rather than guessed at; a count of 0 reads as 1, because a quest
-- that names an item asks for at least one. A string that is not a whole number of records is
-- not one of ours and holds nothing. Pure.
function EraSources.DecodeRequires(text)
  local out = {}
  if type(text) ~= "string" or text == "" or #text % QR_RECORD ~= 0 then
    return out
  end
  for at = 1, #text, QR_RECORD do
    local itemId = packedInt(text, at, QR_ITEM)
    local count = packedInt(text, at + QR_ITEM, QR_COUNT)
    if itemId and itemId > 0 and count then
      if count < 1 then
        count = 1
      end
      out[#out + 1] = { itemId, count }
    end
  end
  return out
end

-- Brief Q1: the game event a quest belongs to (qe: the AQ War Effort, a holiday, the Darkmoon Faire),
-- or nil for a quest tied to none and for a module that ships no qe. Pure.
function EraSources.QuestEvent(source, questId)
  local events = type(source) == "table" and type(source.qe) == "table" and source.qe or nil
  local event = events and type(questId) == "number" and events[questId] or nil
  if type(event) == "number" and event > 0 then
    return event
  end
  return nil
end

-- Brief Q1 (the owner's ruling of 2026-10-09): a quest's level and the level it can be taken from,
-- out of ql (level + QL_LEVEL_SPAN * minimum level, the dump's QuestLevel and MinLevel), each nil
-- where the table states none (0), and both nil for a quest ql does not hold or a module with no ql.
-- Pure.
EraSources.QL_LEVEL_SPAN = 128

function EraSources.QuestLevels(source, questId)
  local levels = type(source) == "table" and type(source.ql) == "table" and source.ql or nil
  local packed = levels and type(questId) == "number" and tonumber(levels[questId]) or nil
  if not packed or packed <= 0 then
    return nil, nil
  end
  local level = packed % EraSources.QL_LEVEL_SPAN
  local minimum = math.floor(packed / EraSources.QL_LEVEL_SPAN)
  return level > 0 and level or nil, minimum > 0 and minimum or nil
end

-- Brief INT1b (the owner's ruling of 2026-10-10, Q(b)): the classes a class quest is for, out of qa
-- (a class mask: 1 Warrior, 2 Paladin, 4 Hunter, 8 Rogue, 16 Priest, 64 Shaman, 128 Mage, 256
-- Warlock, 1024 Druid; the dump's RequiredClasses joined with a class ZoneOrSort), or nil for a quest
-- every class can do and for a module that ships no qa. Pure.
function EraSources.QuestClasses(source, questId)
  local classes = type(source) == "table" and type(source.qa) == "table" and source.qa or nil
  local mask = classes and type(questId) == "number" and tonumber(classes[questId]) or nil
  if mask == nil or mask <= 0 then
    return nil
  end
  return mask
end

-- Brief IW1 (the owner's ruling "B" of 2026-10-22): the parent of a repeatable helper quest, out of qw
-- (CMaNGOS quest_template.PrevQuestId below 0: the quest can only be taken while the parent is in the
-- log; Filling the Soul Gem 593 -> Saving Yenniku 592), or nil for any other quest and for a module that
-- ships no qw. Pure.
-- Brief QF2b: qw is a chain link (the dump's PrevQuestId), so a swapped quest reads its pair's entry and
-- a swapped parent reads as its pair (EraSources.QuestSwaps).
function EraSources.QuestHelperParent(source, questId)
  local helpers = type(source) == "table" and type(source.qw) == "table" and source.qw or nil
  if helpers == nil or type(questId) ~= "number" then
    return nil
  end
  local swaps = EraSources.QuestSwaps()
  local parent = tonumber(helpers[EraSources.SwappedQuest(questId, swaps)])
  if parent == nil or parent <= 0 or parent ~= math.floor(parent) then
    return nil
  end
  parent = EraSources.SwappedQuest(parent, swaps)
  if parent == questId then
    return nil
  end
  return parent
end

-- The items one quest asks for, out of qr, or an empty list for a quest it holds nothing for and
-- for an older module that ships no qr at all. A new list every call; E:QuestRequires caches.
function EraSources.QuestRequires(source, questId)
  if type(source) ~= "table" or type(questId) ~= "number" then
    return {}
  end
  local packed = type(source.qr) == "table" and source.qr[questId] or nil
  return EraSources.DecodeRequires(packed)
end

-- The reverse of qr: item id to the quests that ask for it, built in one pass over qr alone.
--
--   index[itemId] = { questId, count, questId, count, ... }, quest id ascending
--
-- Flat pairs, one table per ITEM rather than one per quest and item, because the index is kept
-- for the session once built: 2,835 quests on the W12 build, asking for about 3,900 quest and
-- item pairs between them, which is about 2,600 small tables. The pass decodes every record once
-- and reads nothing else in the module (no r, no x lists). Measured on the real table in
-- tests/spec/era_quest_requires_spec.lua. Pure.
-- Brief RB4: check, where given, is called once per quest (Data.SliceCheck), so the login slicer
-- carries the pass over frames (about 6 ms over the shipped 1.60.1.70425 data offline).
function EraSources.RequiredByIndex(source, check)
  local index = {}
  local packed = type(source) == "table" and source.qr or nil
  if type(packed) ~= "table" then
    return index
  end
  -- pairs walks a table differently from one run to the next, and each bucket keeps the order it
  -- was built in, so the quests go in id order.
  local ids = {}
  for questId in pairs(packed) do
    if type(questId) == "number" then
      ids[#ids + 1] = questId
    end
  end
  table.sort(ids)
  for _, questId in ipairs(ids) do
    if check then
      check()
    end
    for _, pair in ipairs(EraSources.DecodeRequires(packed[questId])) do
      local bucket = index[pair[1]]
      if not bucket then
        bucket = {}
        index[pair[1]] = bucket
      end
      -- One quest naming the same item in two slots is one quest asking for the sum.
      if bucket[#bucket - 1] == questId then
        bucket[#bucket] = bucket[#bucket] + pair[2]
      else
        bucket[#bucket + 1] = questId
        bucket[#bucket + 1] = pair[2]
      end
    end
  end
  return index
end

-- What kind of creature a NAME is: the CreatureType, the beast family where there is one, and
-- the level band, out of the one integer ck packs them into.
--
--   type    creature_template.CreatureType: 1 beast, 2 dragonkin, 3 demon, 4 elemental,
--           5 giant, 6 undead, 7 humanoid, 8 critter, 9 mechanical, 10 not specified, 11 totem
--   family  the beast family, or nil where the creature is not a beast
--   lo, hi  the level band, widened where two creatures of one name disagree
--   role    brief N3: "creature" for a name only creature rows name, "vendor" for a name only
--           vendor rows name, "both" for a name that is each
--
-- Nothing at all for a name the table ships no kind for, which is every name that is not a
-- creature or a vendor (an object, a node, a quest) and every creature the fan out rules never
-- named. This file chooses no icon: it says what the thing IS and the interface draws it.
function EraSources.KindOf(source, nameIndex)
  if type(source) ~= "table" or type(nameIndex) ~= "number" then
    return nil
  end
  local kinds = source.ck
  local packed = type(kinds) == "table" and kinds[nameIndex] or nil
  if type(packed) ~= "number" or packed ~= math.floor(packed) then
    return nil
  end
  local role = "creature"
  if packed < 0 then
    local inner = -packed - 1
    if inner % 2 == KIND_VENDOR_BOTH then
      role = "both"
    else
      role = "vendor"
    end
    packed = math.floor(inner / 2)
  end
  local kind = packed % KIND_TYPE_SPAN
  local rest = math.floor(packed / KIND_TYPE_SPAN)
  local low = rest % KIND_LEVEL_SPAN
  rest = math.floor(rest / KIND_LEVEL_SPAN)
  local band = rest % KIND_BAND_SPAN
  local family = math.floor(rest / KIND_BAND_SPAN)
  if family == 0 then
    family = nil
  end
  return kind, family, low, low + band, role
end

-- Every creature NAME the table states, one entry per name: { nameIndex, name, type, family, low,
-- high }, in no particular order (the caller sorts). A name is a creature exactly when ck carries a
-- kind for it, which is the rule E:CreatureKind reads one key at a time, so every name this answers
-- opens a creature page. A kind with no string behind it names nothing and is left out, and so is
-- a vendor only name (brief N3): the search lists the creatures it always listed.
--
-- A pure walk of ck and nothing else: no packed list is decoded and no loot index is built. The
-- window's search (Core/Data.lua Data:CreatureIndex) builds its sorted list once out of this walk
-- and keeps it, a step at a time through EraSources.CreatureNamesStep below.
function EraSources.CreatureNames(source)
  local walk = {}
  EraSources.CreatureNamesStep(source, walk, math.huge)
  return walk.out
end

-- Brief SI1 (QA item 231): the same walk a piece at a time, for the search index's sliced build.
-- The whole walk is about 3 ms offline over the shipped data and was the one step the window's
-- slices could not cut (18 to 20 ms on the owner's slower PC). walk is the caller's own table, {}
-- to start; it holds the list made so far (walk.out) and the last ck key read (walk.at). Reads at
-- most budget keys of ck and answers whether the walk is done, then what is left of the budget.
-- Each step goes on with next() from the key the last one stopped at, which is the order pairs
-- walks, so a walk cut into any number of steps lists the same names in the same order as one
-- whole walk. ck must not change between steps; the shipped table never does. Pure.
function EraSources.CreatureNamesStep(source, walk, budget)
  local out = walk.out
  if not out then
    out = {}
    walk.out = out
  end
  if walk.done then
    return true, budget
  end
  local kinds = type(source) == "table" and source.ck or nil
  if type(kinds) ~= "table" then
    walk.done = true
    return true, budget
  end
  local nameIndex = walk.at
  while budget > 0 do
    nameIndex = next(kinds, nameIndex)
    if nameIndex == nil then
      walk.at, walk.done = nil, true
      return true, budget
    end
    budget = budget - 1
    local name = stringAt(source, nameIndex)
    if name then
      local creatureType, family, low, high, role = EraSources.KindOf(source, nameIndex)
      if creatureType and role ~= "vendor" then
        out[#out + 1] = {
          nameIndex = nameIndex,
          name = name,
          type = creatureType,
          family = family,
          low = low,
          high = high,
        }
      end
    end
  end
  walk.at = nameIndex
  return false, budget
end

-- The display id the client draws one NAME's portrait from, out of cd, or nil for a name the
-- table ships none for.
--
-- It is a CreatureDisplayInfo id, which is the one number SetPortraitTextureFromCreatureDisplayID
-- takes, and the pipeline checked every one of them against THIS build's own CreatureDisplayInfo
-- before shipping it, so an id here is one this client has. No art of any kind is shipped: the
-- id names the client's own model and the client draws it.
--
-- cd covers a subset of the names ck covers, never more, so a row with a portrait always has a
-- kind as well. A name the table ships no display for is the ordinary case for a vendor, an
-- object, a node and a quest, and it happens to a creature whose model the source states none
-- of; the row keeps its kind icon and nothing else changes. This file chooses no icon and asks
-- the client for nothing: UI/Tree.lua decides whether a portrait is worth asking for.
function EraSources.DisplayOf(source, nameIndex)
  if type(source) ~= "table" or type(nameIndex) ~= "number" then
    return nil
  end
  local displays = source.cd
  local display = type(displays) == "table" and displays[nameIndex] or nil
  if type(display) ~= "number" or display <= 0 or display ~= math.floor(display) then
    return nil
  end
  return display
end

-- The title under a vendor's, a trainer's or a quest giver's NAME, out of st (brief T2b):
-- "Wrought Iron Supplies" for Trader Selm, or nil for a name the table titles none. st maps the
-- name's index to the title's own index into s, so a title a hundred vendors share is stored once.
-- The pipeline ships one only for a name it lists as a vendor, a quest giver or ender, or (since
-- brief P6a) a trainer tr carries. Pure.
function EraSources.Title(source, nameIndex)
  if type(source) ~= "table" or type(nameIndex) ~= "number" then
    return nil
  end
  local titles = source.st
  return stringAt(source, type(titles) == "table" and titles[nameIndex] or nil)
end

-- The side a vendor's, a trainer's or a quest giver's NAME is on, out of cf (brief T2b): 1
-- Alliance, 2 Horde, 3 both, or nil for a name the table states no side for (every name that is
-- not a vendor, a trainer or a giver, and one whose faction template the build does not carry).
-- Pure.
function EraSources.Faction(source, nameIndex)
  if type(source) ~= "table" or type(nameIndex) ~= "number" then
    return nil
  end
  local sides = source.cf
  local side = type(sides) == "table" and sides[nameIndex] or nil
  -- 3 is both sides, the value BOTH_SIDES names further down beside the vendor index.
  if side == 1 or side == 2 or side == 3 then
    return side
  end
  return nil
end

-- Map pins, out of mp and zm. The pipeline's own constants: a record is the area id, then x and
-- y in TENTHS of a percent of that area's zone map, in the same base 91 alphabet everything else
-- packed here uses. ../ItemTree-Data/docs/era-sources.md states them.
local PIN_AREA = 2 -- the area id, 1 to 8280
local PIN_COORD = 2 -- a coordinate in tenths of a percent, 0 to 1000
local PIN_TENTHS = 10
local PIN_WIDTH = PIN_AREA + PIN_COORD + PIN_COORD

-- Brief Z5: whether an area is one z names that is new in Forever, out of zf (a short sorted list,
-- eight areas on 1.60.1.70009, so a walk is the whole cost). false for any other area, for a
-- non-number, and for a table that ships no zf. Pure.
function EraSources.IsForeverArea(source, areaId)
  if type(source) ~= "table" or type(areaId) ~= "number" or type(source.zf) ~= "table" then
    return false
  end
  for _, held in ipairs(source.zf) do
    if held == areaId then
      return true
    end
  end
  return false
end

-- The zone map an area is drawn on, out of zm, or nil where this build has none.
--
-- Absent is the answer for every instance root area: this build ships no dungeon map at all, so
-- a creature inside Wailing Caverns has no map and no pins, and the interface says the creature
-- is in there rather than guessing the zone the entrance stands in. Absent is also what a build
-- compiled before the map pins answers for every area, so a caller must handle nil.
function EraSources.MapOf(source, areaId)
  if type(source) ~= "table" or type(areaId) ~= "number" then
    return nil
  end
  local maps = source.zm
  local uiMapId = type(maps) == "table" and maps[areaId] or nil
  if type(uiMapId) ~= "number" or uiMapId <= 0 or uiMapId ~= math.floor(uiMapId) then
    return nil
  end
  return uiMapId
end

-- The compile's Generated stamp, out of g, or nil where the table states none. Pure.
--
-- The pipeline writes the very value the module's header comment prints (brief E85), because a
-- comment cannot be read at run time. Core/GuessSources.lua compares it with a guess module's
-- meta.eraGenerated: a guess names a creature by its place in s, which holds only against the
-- table it was compiled with. A table compiled before the stamp answers nil.
function EraSources.Generated(source)
  if type(source) ~= "table" then
    return nil
  end
  local stamp = source.g
  if type(stamp) ~= "string" or stamp == "" then
    return nil
  end
  return stamp
end

-- One packed pin string decoded into the list EraSources.PinsOf answers with, below. kept is how
-- many of the string's LAST records are hand kept spots (brief M11, out of mc), which marks each
-- of them kept = true; 0 or nil marks none.
local function decodePins(source, text, kept)
  if type(text) ~= "string" or text == "" or #text % PIN_WIDTH ~= 0 then
    return EMPTY
  end
  local out = {}
  local firstKept = #text / PIN_WIDTH - (tonumber(kept) or 0) + 1
  for at = 1, #text, PIN_WIDTH do
    local areaId = packedInt(text, at, PIN_AREA)
    local x = packedInt(text, at + PIN_AREA, PIN_COORD)
    local y = packedInt(text, at + PIN_AREA + PIN_COORD, PIN_COORD)
    -- A record this file cannot read is skipped rather than guessed at, exactly as a row with
    -- an unknown category is: a shorter answer beats a wrong pin.
    if areaId and x and y and areaId > 0 and x <= 100 * PIN_TENTHS and y <= 100 * PIN_TENTHS then
      local pin = {
        area = areaId,
        map = EraSources.MapOf(source, areaId),
        x = x / PIN_TENTHS,
        y = y / PIN_TENTHS,
      }
      if (at - 1) / PIN_WIDTH + 1 >= firstKept then
        pin.kept = true
      end
      out[#out + 1] = pin
    end
  end
  return out
end

-- Brief M11: how many of the last records of one name's mp string are hand kept spots, out of mc,
-- or 0. Only the creature table has them: an object's op string never does.
local function keptCount(source, field, nameIndex)
  if field ~= "mp" or type(source) ~= "table" or type(source.mc) ~= "table" then
    return 0
  end
  local count = source.mc[nameIndex]
  if type(count) ~= "number" or count < 1 or count ~= math.floor(count) then
    return 0
  end
  return count
end

-- The packed pin string one name index carries in one of the two pin tables, or nil.
local function pinText(source, field, nameIndex)
  if type(source) ~= "table" or type(nameIndex) ~= "number" then
    return nil
  end
  local pins = source[field]
  local text = type(pins) == "table" and pins[nameIndex] or nil
  if type(text) ~= "string" or text == "" then
    return nil
  end
  return text
end

-- Where the creature at one string index is found: an array of { area, map, x, y }, or an empty
-- table for a name the table ships no pins for.
--
--   area  the Blizzard area id the pin stands in. z[area] names it
--   map   the zone map to draw it on, out of zm, or nil where this build has none
--   x, y  the pin's place on that map as a percentage, 0 to 100, one decimal place
--
-- The order is the pipeline's and is never sorted here: area ascending, and inside one area the
-- fullest cell first, so a map tab that can only draw a few draws the busiest first.
--
-- A pin is a reduction and not a spawn: at most six per name per area, each the mean of a five
-- percent cell of that map, so 10,052 points stand for 45,213 spawns. There is no spawn count,
-- no respawn timer and no height, and a creature with no pins is the ordinary case for a summon,
-- an instance script spawn and an event boss.
--
-- This decodes every time it is called. E:PinsOf keeps the last few, which is what an interface
-- should use.
--
-- Brief M11: a pin that is one of the name's hand kept spots (mc) carries kept = true as well. It
-- is drawn and labelled exactly as any other pin; the interface reads it only to say the boss
-- appears at one of the places shown.
function EraSources.PinsOf(source, nameIndex)
  return decodePins(source, pinText(source, "mp", nameIndex), keptCount(source, "mp", nameIndex))
end

-- Brief M11: one packed path string decoded, or nil where it is not one of ours. The area once,
-- then x and y per point, each in the pin record's own widths and alphabet.
local function decodePath(source, text)
  if type(text) ~= "string" or #text < PIN_WIDTH or (#text - PIN_AREA) % (2 * PIN_COORD) ~= 0 then
    return nil
  end
  local areaId = packedInt(text, 1, PIN_AREA)
  if not areaId or areaId <= 0 then
    return nil
  end
  local points = {}
  for at = PIN_AREA + 1, #text, 2 * PIN_COORD do
    local x = packedInt(text, at, PIN_COORD)
    local y = packedInt(text, at + PIN_COORD, PIN_COORD)
    -- A point this file cannot read is skipped, the way a pin record is.
    if x and y and x <= 100 * PIN_TENTHS and y <= 100 * PIN_TENTHS then
      points[#points + 1] = { x = x / PIN_TENTHS, y = y / PIN_TENTHS }
    end
  end
  if #points < 2 then
    return nil
  end
  return { area = areaId, map = EraSources.MapOf(source, areaId), points = points }
end

-- Brief M11: where the creature at one string index WALKS, out of pt: an array of
-- { area, map, points = { { x, y }, ... } }, or an empty table for a name that walks no known
-- path. area and map are a pin's (z names the area, zm gives the map, nil where this build has
-- none), and the points are percentages of that map, in walking order. A path with fewer than two
-- readable points is left out: it would draw nothing. Pure, and decodes on every call.
function EraSources.PathsOf(source, nameIndex)
  if type(source) ~= "table" or type(nameIndex) ~= "number" then
    return EMPTY
  end
  local paths = type(source.pt) == "table" and source.pt[nameIndex] or nil
  if type(paths) ~= "table" then
    return EMPTY
  end
  local out = {}
  for _, text in ipairs(paths) do
    local path = decodePath(source, text)
    if path then
      out[#out + 1] = path
    end
  end
  if #out == 0 then
    return EMPTY
  end
  return out
end

-- Where the OBJECT at one string index is found (brief D7): a herb, a vein, a fishing pool or a
-- chest, in exactly the shape EraSources.PinsOf answers for a creature, out of op rather than mp.
-- The two are separate tables because the string table is one table, and a name a creature and an
-- object share would otherwise have one entry standing for two different maps.
function EraSources.ObjectPinsOf(source, nameIndex)
  return decodePins(source, pinText(source, "op", nameIndex))
end

-- Whether the object at one string index has any pins at all, without decoding one: the question
-- a node's page asks before it offers a Map tab. A string lookup.
function EraSources.HasObjectPins(source, nameIndex)
  return pinText(source, "op", nameIndex) ~= nil
end

-- The creature twin (brief N3): whether the name at one string index has any pins in mp, without
-- decoding one. A vendor's page asks it before it offers a Map tab.
function EraSources.HasPins(source, nameIndex)
  return pinText(source, "mp", nameIndex) ~= nil
end

-- Brief E90: which pin table and which name one of this file's own node keys reads its places
-- out of, and the area the key states where it states one. Pure: a key that is not ours (a real
-- npc id, a plain zone, the world drop, a summary) answers nil, and every key of ours reads source,
-- the shipped table, for its name: a page key through ci or oi (brief EK1, EraSources.CreatureAt and
-- EraSources.ObjectAt) and, since brief EK2, a placed, pocket, node or gathered key the same way.
-- Without a table such a key answers nil. E:PinSubject hands the table over only for those keys, so
-- nothing is ever loaded for a key that is not ours.
--   npc:<ours>      a creature, a pocket or a Classic Era vendor, out of mp
--   object:<ours>   a herb or vein node row (no area), a fishing pool or a chest, out of op
--   zone:<gathered> a node in one zone (the rows under a node row), out of op
function EraSources.PinSubject(key, source)
  local kind, id = Graph.Parse(key)
  if type(id) ~= "number" then
    return nil
  end
  if kind == "npc" then
    local nameIndex, areaId = EraSources.CreatureAt(id, source)
    if nameIndex then
      return "mp", nameIndex, areaId
    end
  elseif kind == "object" then
    local nameIndex, areaId = EraSources.ObjectAt(id, source)
    if nameIndex then
      return "op", nameIndex, areaId
    end
  elseif kind == "zone" and id < 0 then
    local areaId, nameIndex = EraSources.ZoneAt(id, source)
    if areaId and nameIndex then
      return "op", nameIndex, areaId
    end
  end
  return nil
end

-- Brief E90: the pins one row or page names in words, out of a decoded pin list. Pure.
--
-- areaId is the zone the row stands in, and then only that zone's pins answer: a row in a zone
-- with no pins there answers nil rather than naming another zone. With no areaId the zone is the
-- one with the most pins (the first of them on a tie), which is the zone a Map tab opens on. At
-- most cap pins are named (3 where none is given), in the pipeline's own order, which is the
-- fullest cell first. more is every pin of the list the answer leaves out, which is what the map
-- still shows. nil for no pins.
--
--   { areaId, points = { { x, y }, ... }, more }
function EraSources.ZonePins(pins, areaId, cap)
  if type(pins) ~= "table" or #pins == 0 then
    return nil
  end
  cap = tonumber(cap) or 3
  if type(areaId) ~= "number" then
    local counts, best = {}, nil
    for _, pin in ipairs(pins) do
      local area = type(pin) == "table" and pin.area or nil
      if type(area) == "number" then
        counts[area] = (counts[area] or 0) + 1
        if not best or counts[area] > counts[best] then
          best = area
        end
      end
    end
    areaId = best
  end
  local points = {}
  for _, pin in ipairs(pins) do
    if type(pin) == "table" and pin.area == areaId and #points < cap then
      if type(pin.x) == "number" and type(pin.y) == "number" then
        points[#points + 1] = { x = pin.x, y = pin.y }
      end
    end
  end
  if #points == 0 then
    return nil
  end
  return { areaId = areaId, points = points, more = #pins - #points }
end

-- The category word the object at one string index is filed under, out of ok ("herb", "vein",
-- "fished" or "object"), or nil for a name the table ships no kind for. ok carries exactly the
-- names op does, so a name with no pins answers nil here and its page keeps what it had.
EraSources.OBJECT_KINDS = { herb = true, vein = true, fished = true, object = true }

function EraSources.ObjectKind(source, nameIndex)
  if type(source) ~= "table" or type(nameIndex) ~= "number" then
    return nil
  end
  local kinds = source.ok
  local number = type(kinds) == "table" and kinds[nameIndex] or nil
  local word = type(number) == "number" and EraSources.CATEGORIES[number] or nil
  if not (word and EraSources.OBJECT_KINDS[word]) then
    return nil
  end
  return word
end

-- The name in the string table behind one of this file's own OBJECT node ids, and the place the
-- key states where it states one. Pure over source, the object twin of EraSources.CreatureAt: since
-- brief EK2 every one of these keys holds a gameobject id, so the name comes back through oi
-- (EraSources.ObjectNameIndex) and without a table nothing answers.
--   a gathering node row (EraSources.NodeAt) is its node's name, with no place (it stands for all of
--     the node's zones on one item);
--   a name in one place (EraSources.PlacedId) is a chest or a fishing pool in that zone;
--   a plain negative id is an object's page, keyed by its gameobject id (brief EK1 2c);
--   a gathering node in one zone is a zone key, a pocket a creature's, a summary row and a no page
--     node name nothing, and neither do 0, a positive id or a retired window (0.1.3 to EK1).
function EraSources.ObjectAt(id, source)
  if type(id) ~= "number" or id >= 0 or id ~= math.floor(id) then
    return nil
  end
  if isPageId(id) then
    -- Brief EK1 2c: a plain negative id is an object's page, keyed by its gameobject id: the name
    -- comes back through oi, out of source.
    local nameIndex = objectNameOf(source, id)
    if not nameIndex then
      return nil
    end
    return nameIndex, nil
  end
  local _, nodeObject = EraSources.NodeAt(id)
  if nodeObject then
    return EraSources.ObjectNameIndex(source, nodeObject), nil
  end
  local objectId, areaId = pairedParts(PLACED, id, 1)
  local nameIndex = objectId and EraSources.ObjectNameIndex(source, objectId) or nil
  if not nameIndex then
    return nil
  end
  return nameIndex, areaId
end

-- The packed list behind one item's summary row, and the category number it was asked for, or
-- nothing at all. A string lookup and two table lookups: nothing is decoded here.
local function packedList(source, itemId, category)
  local number = EraSources.NUMBERS[category] or category
  if type(source) ~= "table" or type(itemId) ~= "number" or type(number) ~= "number" then
    return nil
  end
  local index = source.x
  local byCategory = type(index) == "table" and index[itemId] or nil
  local slot = type(byCategory) == "table" and byCategory[number] or nil
  local lists = source.xl
  local text = type(slot) == "number" and type(lists) == "table" and lists[slot] or nil
  if type(text) ~= "string" or text == "" then
    return nil
  end
  return text, number
end

-- How many further sources sit behind one item's summary row, WITHOUT decoding any of them: the
-- length of the packed string over the width of one record. 0 where the table ships no list,
-- which is every category that was never summarised and every world drop (c = 5), whose list the
-- pipeline measured at about 2.1 MB and refused.
--
-- category is the word a normalised row carries ("skinned") or the number the table uses (7).
function EraSources.MoreCount(source, itemId, category)
  local text, number = packedList(source, itemId, category)
  if not text then
    return 0
  end
  local width = recordWidth(number)
  if #text % width ~= 0 then
    return 0
  end
  return math.floor(#text / width)
end

-- The rest of the list a summary row stands for, normalised exactly like the rows above it, in
-- the order the contract states them (best chance first, then the quest only ones).
--
-- Each entry carries what the table kept of it: category, label, name, nameIndex, area, areaId,
-- zone, chance, stock, container, note, key, dedupe, edge and group, which is the same shape
-- EraSources.Rows produces, so one piece of interface code draws both. What a list entry never
-- carries is the quest id behind a quest only source: the row says "only while on a quest" and
-- names none, because a quest id on every record would have cost more than the lists do.
function EraSources.More(source, itemId, category, questTitle)
  local text, number = packedList(source, itemId, category)
  if not text then
    return EMPTY
  end
  local width = recordWidth(number)
  if #text % width ~= 0 then
    return EMPTY
  end
  local out, drawn = {}, {}
  for at = 1, #text, width do
    local raw = packedRow(text, at, number)
    if raw then
      addRow(out, drawn, source, raw, itemId, questTitle)
    end
  end
  return finishNodes(out)
end

local E = {}
E.__index = E

-- How many decoded lists one reader keeps. A player opens one summary and compares it with the
-- one before it, so a handful is the whole of the need: the point of packing the lists into
-- strings is that they cost nothing until they are asked for, and a cache that kept every list
-- it ever decoded would hand that straight back.
local MORE_CACHE = 4

-- source is the shipped table and defaults to Data:Get("EraSources"), read when it is first
-- needed rather than now, so the data file may load after this one. opts.data swaps the data
-- layer, which is what a spec passes.
function EraSources.New(source, opts)
  opts = opts or EMPTY
  local era = setmetatable({}, E)
  era.source = source
  era.data = opts.data or Data
  era.provider = nil
  era.namer = nil
  era.questIndex = nil
  era.questNames = nil
  -- The last few decoded lists, newest first, each { item, category, rows }.
  era.moreCache = {}
  -- How many times the quest index has been built. It is built once and kept, so a spec reads
  -- this back rather than timing anything.
  era.builds = 0
  -- How many packed lists have been decoded. Nothing on the ordinary path to a drawn tree
  -- touches one, so a spec reads this back and asserts it is still zero.
  era.decodes = 0
  return era
end

-- The shipped table, or nil when this build ships none: the pipeline's --no-era-sources writes
-- no module at all, and then nothing here answers anything.
function E:Table()
  if type(self.source) == "table" then
    return self.source
  end
  local data = self.data
  if type(data) ~= "table" or type(data.Get) ~= "function" then
    return nil
  end
  local ok, table_ = pcall(data.Get, data, EraSources.MODULE)
  if ok and type(table_) == "table" then
    return table_
  end
  return nil
end

-- Brief EK1 2b: the shipped table where it is already built, or nil, without loading it. A positive
-- npc key is a merged name's page only where the Classic Era table is shown at all, and then it is
-- built, so a positive key (a Forever creature, a vendor row, a node asked its name) is answered out
-- of the built table and never loads the module (tests/spec/load_on_demand_spec.lua).
function E:_BuiltTable()
  if type(self.source) == "table" then
    return self.source
  end
  local data = self.data
  local cache = type(data) == "table" and type(data.cache) == "table" and data.cache or nil
  local held = cache and cache[EraSources.MODULE] or nil
  if type(held) == "table" then
    return held
  end
  return nil
end

-- Brief EK1: the reader's own way to the two page key helpers (EraSources.PageKey and
-- EraSources.PageName), over the shipped table, so a caller holding the reader never builds or
-- reads an Era creature's page key by hand.

-- The page key of the Classic Era creature or vendor at one string index, or nil where the table
-- states no creature id for it (or there is no table).
function E:PageKey(nameIndex)
  if type(nameIndex) ~= "number" then
    return nil
  end
  return EraSources.PageKey(self:Table(), nameIndex)
end

-- The string index one Classic Era creature's page key stands for, or nil. The table is asked for
-- only for an npc key in the page range; a positive one (brief EK1 2b: a merged name's page) is
-- answered out of the table where it is built, and any other key loads nothing.
function E:PageName(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "npc" or type(id) ~= "number" then
    return nil
  end
  if id > 0 then
    return EraSources.PageName(self:_BuiltTable(), key)
  end
  if not isPageId(id) then
    return nil
  end
  return EraSources.PageName(self:Table(), key)
end

-- Brief EK1 2c: the object twins, EraSources.ObjectKey and EraSources.ObjectName over the table.
function E:ObjectKey(nameIndex)
  if type(nameIndex) ~= "number" then
    return nil
  end
  return EraSources.ObjectKey(self:Table(), nameIndex)
end

function E:ObjectName(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "object" or not isPageId(id) then
    return nil
  end
  return EraSources.ObjectName(self:Table(), key)
end

-- The name at one string index, or nil: what a caller holding a name index (a giver, a trainer, a
-- zone's person) says for a name that has no page key to be named through.
function E:NameAt(nameIndex)
  local source = self:Table()
  return source and stringAt(source, nameIndex) or nil
end

-- EraSources.PinSubject with the shipped table handed over only for a key of ours that needs it (a
-- page key, and since brief EK2 a placed, pocket, node or gathered key, each read back through ci
-- or oi), so a key that is not ours still loads nothing.
function E:PinSubject(key)
  local kind, id = Graph.Parse(key)
  local source = nil
  if (kind == "npc" or kind == "object") and (isPageId(id) or rowWindow(id)) then
    source = self:Table()
  elseif kind == "zone" and rowWindow(id) == "gathered" then
    source = self:Table()
  elseif kind == "npc" and type(id) == "number" and id > 0 then
    -- Brief EK1 2b: a positive npc key may be a merged name's page, out of the built table.
    source = self:_BuiltTable()
  end
  return EraSources.PinSubject(key, source)
end

-- The title this client has for a quest, for the one row that names the quest it depends on.
-- The graph answers from whatever named it first (a curated quest, the collector) and falls
-- through to this file's own namer, which is the Era table's quest rows.
--
-- Brief QN1: a quest in a chain of same titled quests reads with its number, "Taming the Beast
-- (II)", through Core/ViewModel.lua ViewModel.QuestDisplayName where that file is loaded.
function E:QuestTitle(questId)
  if type(questId) ~= "number" then
    return nil
  end
  local title = Graph.Name(Graph.Key("quest", questId))
  local ViewModel = ItemTree.ViewModel
  if type(title) == "string" and type(ViewModel) == "table" and type(ViewModel.QuestDisplayName) == "function" then
    local ok, shown = pcall(ViewModel.QuestDisplayName, questId, title)
    if ok and type(shown) == "string" and shown ~= "" then
      return shown
    end
  end
  return title
end

-- Brief QN1: one quest's place in a chain of same titled quests, out of this table's qc
-- (EraSources.QuestChain), or nil. Reads a table already built only (a row's title is drawn on
-- the way to a tree, which never loads the table for this), so asking never loads anything.
function E:QuestChain(questId)
  local source = self.source
  if type(source) ~= "table" then
    local data = self.data
    local cache = type(data) == "table" and data.cache or nil
    source = type(cache) == "table" and cache[EraSources.MODULE] or nil
  end
  return EraSources.QuestChain(source, questId)
end

--- Brief QV1 (the owner's ruling "2.a", 2026-10-18): the name of the reputation one quest gives, out
--- of the joined table's qf = { [questId] = factionId } and fn = { [factionId] = name } (EraPlaces.lua,
--- ours: the Classic Era quest's first reputation reward named by this build's Faction table), which
--- the pipeline writes only for the quests that share a title and give different reputations. nil for
--- a quest qf does not hold and for an older module that ships neither. Pure.
function EraSources.QuestReputation(source, questId)
  local factions = type(source) == "table" and source.qf or nil
  local names = type(source) == "table" and source.fn or nil
  local faction = type(factions) == "table" and type(questId) == "number" and factions[questId] or nil
  local name = type(names) == "table" and type(faction) == "number" and names[faction] or nil
  if type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- Brief QV1: E:QuestChain's way, a table already built only, so asking never loads anything.
function E:QuestReputation(questId)
  local source = self.source
  if type(source) ~= "table" then
    local data = self.data
    local cache = type(data) == "table" and data.cache or nil
    source = type(cache) == "table" and cache[EraSources.MODULE] or nil
  end
  return EraSources.QuestReputation(source, questId)
end

-- Brief D5: the table also carries the rows of the items this build withholds that Classic Era
-- named, so a realm's discoveries fill in without a new data build. Such an item's rows are
-- served only while its Classic Era details are (Core/Data.lua Data:EraUnlocked: the setting
-- "Show Classic Era details for items not yet found" is on, or the client can name the item).
-- Otherwise its own rows answer nothing, and a creature's loot and a quest's items leave it out
-- and count it, so the page can say "N not yet found on your realm" in one line.
--
-- Asked per item at the moment a list is drawn, never cached, so the answer follows the setting
-- and the realm check without anything having to be told.
function E:_Unlocked(itemId)
  local data = self.data
  if type(data) ~= "table" or type(data.EraUnlocked) ~= "function" then
    return true
  end
  local ok, unlocked = pcall(data.EraUnlocked, data, itemId)
  return not ok or unlocked ~= false
end

-- The normalised rows for one item, in the order they are drawn.
function E:Rows(itemId)
  local source = self:Table()
  if not source then
    return EMPTY
  end
  return EraSources.Rows(source, itemId, function(questId)
    return self:QuestTitle(questId)
  end)
end

-- What kind of creature the name at one string index is: type, family, lo, hi. A pure lookup,
-- and nothing at all for a name the table ships no kind for.
function E:KindOf(nameIndex)
  return EraSources.KindOf(self:Table(), nameIndex)
end

-- The display id the name at one string index draws its portrait from, or nil. A pure lookup,
-- and nothing at all for a name the table ships no display for.
function E:DisplayOf(nameIndex)
  return EraSources.DisplayOf(self:Table(), nameIndex)
end

-- The title under the name at one string index ("Wrought Iron Supplies"), or nil. A pure lookup.
function E:Title(nameIndex)
  return EraSources.Title(self:Table(), nameIndex)
end

-- The side the name at one string index is on: 1 Alliance, 2 Horde, 3 both, or nil. A pure lookup.
function E:Faction(nameIndex)
  return EraSources.Faction(self:Table(), nameIndex)
end

-- The zone map an area id is drawn on, or nil where this build has none. A pure lookup.
function E:MapOf(areaId)
  return EraSources.MapOf(self:Table(), areaId)
end

-- Brief Z5: whether an area is new in Forever (zf). A pure lookup; false with no table.
function E:IsForeverArea(areaId)
  return EraSources.IsForeverArea(self:Table(), areaId)
end

-- The shipped table's Generated stamp, or nil where it states none (or no table ships).
function E:Generated()
  return EraSources.Generated(self:Table())
end

-- How many packed pin strings have been decoded. Nothing on the ordinary path to a drawn tree
-- touches one, so a spec reads this back and asserts it is still zero. It lives on the metatable
-- so that a reader made before this table existed still answers 0: a read falls through to here
-- and the first decode writes the count onto the reader itself.
E.pinDecodes = 0

-- How many decoded pin lists one reader keeps. A player opens a creature, looks at the map and
-- goes back, so a handful is the whole of the need: the point of packing the pins into strings is
-- that they cost nothing until they are asked for.
local PIN_CACHE = 4

-- Where the creature at one string index is found: an array of { area, map, x, y }, newest first
-- in the cache and in the pipeline's own order in the answer. EMPTY for a name with no pins.
--
-- Nothing on the way to a drawn tree calls this: EdgesFor never does, so a session that never
-- opens a creature's map decodes not one byte of mp.
function E:PinsOf(nameIndex)
  return self:_CachedPins(nameIndex, "mp")
end

-- The object twin (brief D7): where the herb, vein, fishing pool or chest at one string index is
-- found, out of op, through the same small cache. Nothing on the way to a drawn tree calls it.
function E:ObjectPinsOf(nameIndex)
  return self:_CachedPins(nameIndex, "op")
end

-- Brief M11: where the creature at one string index walks, out of pt (EraSources.PathsOf). Only a
-- Map tab calls it, and a boss has one or two paths, so nothing is kept.
function E:PathsOf(nameIndex)
  return EraSources.PathsOf(self:Table(), nameIndex)
end

-- Whether the name at one string index has creature pins, without decoding them (brief N3).
function E:HasPins(nameIndex)
  return EraSources.HasPins(self:Table(), nameIndex)
end

-- One decoded pin list out of mp or op, kept in the reader's small cache. The cache is keyed by the
-- table as well as the name, so a creature and an object that share a name never answer for each
-- other.
function E:_CachedPins(nameIndex, field)
  local source = self:Table()
  if not source or type(nameIndex) ~= "number" then
    return EMPTY
  end
  -- The cache remembers which table it decoded, so swapping the data under the reader throws it
  -- away without anything having to be told: Core/Data.lua hands back the same table until its
  -- own cache is reset, and a different table is different data.
  local cache = self.pinCache
  if not cache or cache.source ~= source then
    cache = { source = source }
    self.pinCache = cache
  end
  for position, held in ipairs(cache) do
    if held.name == nameIndex and held.field == field then
      if position > 1 then
        table.remove(cache, position)
        table.insert(cache, 1, held)
      end
      return held.pins
    end
  end
  local pins = decodePins(source, pinText(source, field, nameIndex), keptCount(source, field, nameIndex))
  if #pins == 0 then
    return EMPTY
  end
  self.pinDecodes = self.pinDecodes + 1
  table.insert(cache, 1, { name = nameIndex, field = field, pins = pins })
  while #cache > PIN_CACHE do
    table.remove(cache)
  end
  return pins
end

-- Brief E90: where the source one node key names is, in words a row's tooltip and a page's header
-- can print: { areaId, zone, points = { { x, y }, ... }, more }, or nil. areaId narrows it to one
-- zone where the caller has one; otherwise the key's own area, and where the key states none, the
-- zone with the most pins. fallback lets a page whose key names a zone with no pins name the zone
-- the map opens on instead; a row keeps to its own zone.
--
-- The pins come through E:_CachedPins, the Map tab's own reader and cache, so a hover on a row the
-- player then opens decodes nothing twice. A key that is not one of this file's own answers nil
-- before the table is asked for, so a hover on anything else loads nothing.
function E:Places(key, areaId, fallback)
  local field, nameIndex, keyArea = self:PinSubject(key)
  if not field then
    return nil
  end
  local pins = self:_CachedPins(nameIndex, field)
  if #pins == 0 then
    return nil
  end
  local area = type(areaId) == "number" and areaId or keyArea
  local answer = EraSources.ZonePins(pins, area)
  if not answer and fallback and area ~= nil then
    answer = EraSources.ZonePins(pins, nil)
  end
  if not answer then
    return nil
  end
  answer.zone = areaName(self:Table(), answer.areaId)
  return answer
end

-- How many further sources sit behind one item's summary row, without decoding one of them.
-- category is the word the row carries ("skinned") or the number the table uses (7).
function E:MoreCount(itemId, category)
  return EraSources.MoreCount(self:Table(), itemId, category)
end

-- The rest of the list behind one item's summary row, normalised like the rows above it.
--
-- Nothing on the way to a drawn tree calls this: EdgesFor never does, so a session that opens
-- a Sources view and reads it decodes nothing at all. The last few lists are kept, because the
-- one thing a player does with an opened list is scroll it and come back to it.
function E:More(itemId, category)
  local source = self:Table()
  if not source then
    return EMPTY
  end
  local number = EraSources.NUMBERS[category] or category
  if type(itemId) ~= "number" or type(number) ~= "number" then
    return EMPTY
  end
  local cache = self.moreCache
  for position, held in ipairs(cache) do
    if held.item == itemId and held.category == number then
      if position > 1 then
        table.remove(cache, position)
        table.insert(cache, 1, held)
      end
      return held.rows
    end
  end
  local rows = EraSources.More(source, itemId, number, function(questId)
    return self:QuestTitle(questId)
  end)
  if #rows == 0 then
    return EMPTY
  end
  self.decodes = self.decodes + 1
  table.insert(cache, 1, { item = itemId, category = number, rows = rows })
  while #cache > MORE_CACHE do
    table.remove(cache)
  end
  return rows
end

-- The rest of the list behind one item's summary row, as EDGES rather than as rows: the same
-- shape EdgesFor hands the graph for the named rows above them, with every node's name put on
-- the graph on the way past, so the interface draws an opened list with exactly the code that
-- draws the three rows over it.
--
-- Nothing on the ordinary path to a drawn tree calls this either. Core/ViewModel.lua asks only
-- for a summary row the player has opened or the search box has reached into, and it keeps what
-- it is given for as long as the view lives, so one list is decoded once per root.
function E:MoreEdges(itemId, category)
  local out = {}
  if not self:_Unlocked(itemId) then
    return out
  end
  for _, row in ipairs(self:More(itemId, category)) do
    local edge = self:_RowEdge(row, itemId)
    if edge then
      out[#out + 1] = edge
    end
  end
  return out
end

-- One quest of the table's own, into the index and onto the graph.
local function indexQuest(source, index, names, itemId, questId, nameIndex)
  if type(questId) ~= "number" then
    return
  end
  local name = stringAt(source, nameIndex)
  if not name then
    return
  end
  Graph.SetName(Graph.Key("quest", questId), name)
  names[questId] = name
  local bucket = index[questId]
  if not bucket then
    bucket = {}
    index[questId] = bucket
  end
  bucket[#bucket + 1] = itemId
end

-- Quest to the items Era says it hands over, and quest to its title, built once from the whole
-- table.
--
-- The table indexes items, so the only way back is one pass over every row, which is why it is
-- built on the first quest key asked for and then kept: 18,597 rows on build 1.60.1.69913. The
-- pass reads the RAW rows rather than normalised ones, so it allocates nothing per row and can
-- never ask this file to name the very quest it is indexing. Every quest's name goes on the
-- graph as it goes into a table of its own beside it, so a quest opened by its key alone can be
-- named without anything asking for an edge.
function E:_QuestIndex()
  if self.questIndex then
    return self.questIndex
  end
  local index, names = {}, {}
  local source = self:Table()
  local rows = source and source.r or nil
  if type(rows) == "table" then
    -- pairs walks a table differently from one run to the next, and the buckets below keep the
    -- order they were built in, so a quest's items would otherwise swap places between loads.
    -- Brief RB4: sorted once per table (sortedItemIds).
    local ids = sortedItemIds(rows)
    local scan = { only = { [QUEST_CATEGORY] = true }, onlyKey = "c" }
    -- Brief PF3: the login slicer carries this pass over frames (Core/Data.lua Data.SliceCheck, a
    -- nil check for every other caller, which builds it whole as before).
    local check = type(Data) == "table" and Data.SliceCheck or nil
    for _, itemId in ipairs(ids) do
      if check then
        check()
      end
      for _, raw in scanRows(source, itemId, scan) do
        if type(raw) == "table" and raw.c == QUEST_CATEGORY then
          indexQuest(source, index, names, itemId, raw.q, raw.n)
          for _, extra in ipairs(type(raw.m) == "table" and raw.m or EMPTY) do
            if type(extra) == "table" then
              indexQuest(source, index, names, itemId, extra.q, extra.n)
            end
          end
        end
      end
    end
  end
  -- Brief PF3: a caller that built the index whole while the slicer's pass was paused keeps its own.
  if self.questIndex then
    return self.questIndex
  end
  self.questIndex = index
  self.questNames = names
  self.builds = self.builds + 1
  return index
end

-- The items Era says one quest hands over, sorted by id. The list is this table's own and must
-- not be modified.
function E:QuestItems(questId)
  if type(questId) ~= "number" then
    return EMPTY
  end
  return self:_QuestIndex()[questId] or EMPTY
end

-- The title Era gives one quest, or nil.
--
-- Two places have one, and the cheaper is asked first. qt is a table lookup and holds the
-- quests the table only ever mentions as the reason a drop is quest only, which is 478 of them
-- and the whole of what this change on 2026-09-20 was for. The quest index is the pass over
-- every row that finds the quests the table hands an item over on, built on the first ask and
-- then kept: it is the same pass the first quest edge would have paid for and never a second
-- one, and an item whose only quest is a qt one never pays it at all.
function E:QuestName(questId)
  if type(questId) ~= "number" then
    return nil
  end
  local titled = EraSources.QuestTitleAt(self:Table(), questId)
  if titled then
    return titled
  end
  self:_QuestIndex()
  return self.questNames[questId]
end

-- The name for one of this table's own node keys, for Graph.RegisterNamer.
--
-- Core/Graph.lua asks this only for a key nothing else on the client could name, so it is the
-- one path by which a node opened by its key alone (the recently viewed list after a reload, a
-- debug command) is named at all: every other route names a node as the row that points at it
-- is drawn. A curated or collector learned quest has already put its own title on the graph, so
-- it is never asked about and keeps that title.
--
-- Nothing here loads the shipped module for a key the table could not possibly hold, which is
-- every key but a quest, an area and one of this file's own creature, object and summary nodes.
-- A quest is the only one that costs the index pass; a creature, an object and an area are a
-- table lookup once the module is in hand, and a summary row is one item's rows. Nothing at all
-- happens at load, because nothing asks until something is opened.
function E:NameFor(key)
  local kind, id = Graph.Parse(key)
  if not kind or type(id) ~= "number" then
    return nil
  end
  if kind == "quest" then
    return self:QuestName(id)
  end
  if kind == "npc" or kind == "object" then
    -- The nodes this file makes: id 0 is the world drop every such row shares, a positive id is a
    -- merged name's page (brief EK1 2b) or nothing of ours, a no page node is named by the name its
    -- key carries, a summary row by its label, and every other key of ours (a page, a placed, pocket
    -- or node row) holds a CMaNGOS id that ci or oi reads back to its name (EraSources.CreatureAt and
    -- EraSources.ObjectAt, brief EK1 and EK2). A real creature or object id is never ours.
    if kind == "npc" and id == WORLD_ID then
      return L[WORLD_DROP]
    end
    if id > 0 then
      -- Brief EK1 2b: a merged name's page (npc:<id>) is named by that name, out of the built table:
      -- a node asked its name never loads the module.
      if kind == "npc" then
        local source = self:_BuiltTable()
        return source and stringAt(source, mergedNameOf(source, id)) or nil
      end
      return nil
    end
    local source = self:Table()
    -- Brief EK1: a row's node for a name with no page is named by that name, which its key carries.
    if noPageName(id) then
      return source and stringAt(source, noPageName(id)) or nil
    end
    if heldIn(SUMMARY, id) then
      for _, row in ipairs(self:Rows(summaryItem(id))) do
        if row.key == key then
          return row.label
        end
      end
      return nil
    end
    if not source then
      return nil
    end
    if kind == "npc" then
      return stringAt(source, (EraSources.CreatureAt(id, source)))
    end
    return stringAt(source, (EraSources.ObjectAt(id, source)))
  end
  if kind == "zone" then
    local source = self:Table()
    if not source then
      return nil
    end
    -- A gathering node in one zone reads as the zone, which is what the row that points at it
    -- says: the node is the node in that place, and the place is the answer a player wants.
    if id < 0 then
      local _, areaId = EraSources.GatheredId(key)
      return areaName(source, areaId)
    end
    return areaName(source, id)
  end
  return nil
end

-- Puts every quest name this table knows on the graph at once. The namer above answers one key
-- at a time and is what the addon uses; this is for a caller that wants the lot, and it forces
-- the shipped module to load, which a session that never opens a Sources view never pays for.
function E:SetNames()
  self:_QuestIndex()
  return self
end

-- Drops the quest index, so the next call builds it again. The harness swaps data modules
-- underneath a loaded Core; nothing in the addon changes the shipped table at runtime.
function E:Invalidate()
  self.questIndex = nil
  self.questNames = nil
  self.moreCache = {}
  self.requiresCache = nil
  self.requiresFor = nil
  self.requiredBy = nil
  self.requiredByFor = nil
  -- Brief CT1b: and the class lists' edges (E:ClassTeachesEdges).
  self.classEdges = nil
end

-- The fields every edge carries, whichever way it is pointing. Kept in one place so a row and
-- the quest side of it can never disagree about what marks it as history.
function E:_Mark(edge)
  edge.confidence = Confidence.PREDICTED
  edge.basis = Confidence.BASIS_ERA
  edge.provenance = EraSources.PROVENANCE
  -- What another game used to do, rather than anything about this client. Core/Graph.lua only
  -- hands such an edge to a caller that asked for it (opts.includeHistorical), which the views
  -- do and a chain walk does not: a guess is a row in a tree and never a step in a route. Brief
  -- CH1: a chain asks for the quest rows alone (opts.includeEraQuests, Graph.ChainQuestEdge).
  edge.historical = true
  return edge
end

-- One normalised row as the edge the graph draws, with the node's name put on the graph beside
-- it. nil for a row this file made that points nowhere, which nothing in the table produces.
--
-- The same function builds a named row's edge and a listed one's, so a summary a player has
-- opened is drawn by exactly the code that drew the three rows above it.
function E:_RowEdge(row, itemId)
  if not row.edge then
    return nil
  end
  -- A container row names nothing: the item on the other end of it is named by this build's own
  -- data, and writing a name over it is the one thing that would be wrong.
  if row.label then
    Graph.SetName(row.key, row.label)
  end
  local edge = self:_Mark({
    type = row.edge,
    target = row.key,
    group = row.group,
    zone = row.zone,
    percent = row.chance,
    -- What client line the chance was measured on, which Core/Sources.lua reads: the figure is
    -- worth showing and its precision is not.
    percentSource = EraSources.PROVENANCE,
    -- The words the row ends with, where this source needs one: a limited stock, a level band,
    -- the quest it depends on. Core/Sources.lua turns it into the row's own line.
    note = row.note,
    -- The name Core/Graph.lua drops this row by when a live edge of the same type already names
    -- the same creature, vendor, object or quest.
    dedupeName = row.dedupe,
  })
  if row.noPage then
    -- Brief EK1: a creature or vendor the table states no creature id for has no page, so its row
    -- is drawn and opens nothing (UI/Tree.lua reads this).
    edge.noPage = true
  end
  if row.category == "pickpocket" then
    -- Brief B7: a pocket is filed under DROPPED_BY like a drop, but stealing is a different act,
    -- so Core/Graph.lua lets only another pocket shadow it, never a drop of the same creature.
    edge.pocket = true
  end
  if row.category == "vendor" and type(row.nameIndex) == "number" then
    -- Brief T2b: the vendor's title and side, where the table states them, so the row can read
    -- "Trader Selm <Wrought Iron Supplies>" and say "Alliance only" to a player who cannot buy
    -- there. A recipe's Sold by rows are these rows, so a one sided recipe says so too.
    edge.title = self:Title(row.nameIndex)
    edge.faction = self:Faction(row.nameIndex)
  end
  if row.category == "quest" and row.side then
    -- Brief T2b: a quest only one side can take says so the same way ("Alliance only").
    edge.faction = row.side
  end
  if row.category == "quest" and type(row.questId) == "number" and not row.summary then
    self:_MarkReward(edge, row.questId, itemId)
  end
  if row.summary or row.category == "world" then
    -- A row that stands for a GROUP of sources rather than for one of them. It is never a thing
    -- the window can open, so the interface answers a click on it with the list where there is
    -- one and with nothing at all where there is not: listed is how many records the table ships
    -- behind it, counted without decoding a byte, and it is 0 for every world drop.
    edge.summary = {
      item = itemId,
      category = row.category,
      listed = tonumber(row.listed) or 0,
    }
  elseif EraSources.CREATURE_CATEGORIES[row.category] then
    -- What KIND of creature this row names, for the icon the interface draws and the line the
    -- row's tooltip says it in. A table lookup and a little arithmetic; this file chooses no
    -- icon and no words.
    local creatureType, family, low, high = self:KindOf(row.nameIndex)
    if creatureType then
      edge.creature = {
        type = creatureType,
        family = family,
        low = low,
        high = high,
        -- The creature's own portrait, where the table ships one. It is a number and nothing
        -- more: the interface decides whether to ask the client to draw it, and every row draws
        -- its kind icon first either way.
        display = self:DisplayOf(row.nameIndex),
      }
    end
  end
  return edge
end

-- The node row one gathering node key stands for, as Rows or More drew it, or nil for a key that is
-- not one of this file's node rows, an item that is locked, or a node the table no longer lists.
--
-- The named rows are read first, which is every node a tree draws before a summary is opened, so
-- the ordinary path to a drawn tree decodes nothing. A node that sits behind the summary is read
-- out of the list the player opened to reach it, which E:More keeps.
function E:NodeRow(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "object" then
    return nil
  end
  local itemId = EraSources.NodeAt(id)
  if not itemId or not self:_Unlocked(itemId) then
    return nil
  end
  for _, row in ipairs(self:Rows(itemId)) do
    if row.node and row.key == key then
      return row
    end
  end
  for category in pairs(NODES) do
    if self:MoreCount(itemId, category) > 0 then
      for _, row in ipairs(self:More(itemId, category)) do
        if row.node and row.key == key then
          return row
        end
      end
    end
  end
  return nil
end

-- The zone rows under one gathering node row, in the table's own order (commonest zone first), or
-- an empty list: a node inside an instance and a node the table places nowhere open onto nothing.
function E:NodeZones(key)
  local row = self:NodeRow(key)
  return (row and row.zones) or EMPTY
end

-- One zone row as the edge the graph draws under its node row. No chance: the node row carries
-- it. The node's name goes in meta, which is the line the row's tooltip says under the zone and a
-- word the search box finds the row by.
function E:_ZoneEdge(zone)
  Graph.SetName(zone.key, zone.label)
  return self:_Mark({
    type = zone.edge,
    target = zone.key,
    group = zone.group,
    zone = zone.zone,
    meta = zone.nodeName,
  })
end

-- Edges for Graph.RegisterProvider. Everything answered here is predicted: it is what Classic
-- Era used to do, and WoW Forever may have changed it.
function E:EdgesFor(key, direction)
  local out = {}
  local kind, id = Graph.Parse(key)
  if kind == "object" then
    -- A gathering node row this file made opens onto its zones, walking up; nothing else an
    -- object key names has anything under it here.
    if direction == Edges.UP then
      for _, zone in ipairs(self:NodeZones(key)) do
        out[#out + 1] = self:_ZoneEdge(zone)
      end
    end
    return out
  end
  -- Brief P6b: a recipe spell's trainers, walking up, in the Trainer category of its Sources.
  if kind == "spell" then
    if direction == Edges.UP then
      return self:TrainerEdges(id)
    end
    return out
  end
  if kind ~= "item" and kind ~= "quest" then
    return out
  end

  if kind == "item" then
    if not self:_Unlocked(id) then
      return out
    end
    if direction == Edges.DOWN then
      return self:RequiredByEdges(id)
    end
    if direction ~= Edges.UP then
      return out
    end
    local named = {}
    for _, row in ipairs(self:Rows(id)) do
      if row.edge and row.edge.dir == direction then
        local edge = self:_RowEdge(row, id)
        out[#out + 1] = edge
        if edge and edge.target then
          named[edge.target] = true
        end
      end
    end
    -- Brief NX1 (the owner's ruling "2A"): the Classic Era quests that hand the item over when taken, one row
    -- per quest: a quest a row above already names (its reward row, Field Duty 8508 and its Papers 20810) is
    -- not named twice.
    for _, edge in ipairs(self:ProvidedEdges(id)) do
      if not named[edge.target] then
        out[#out + 1] = edge
      end
    end
    return out
  end

  if direction == Edges.UP then
    return self:QuestRequiresEdges(id)
  end
  if direction ~= Edges.DOWN then
    return out
  end
  for _, itemId in ipairs(self:QuestItems(id)) do
    if self:_Unlocked(itemId) then
      out[#out + 1] = self:_MarkReward(
        self:_Mark({
          type = T.QUEST_REWARDS,
          target = Graph.Key("item", itemId),
          group = L["Rewards"],
        }),
        id,
        itemId
      )
    end
  end
  return out
end

-- What the shipped table holds and whether it reaches the graph, for the debug command. A table
-- full of rows that is not installed draws exactly the same tree an absent one does, so the two
-- faults have to be told apart; Core/Quests.lua's Counts answers the same way.
--
-- items is how many items the table sources, which is what Data/generated/Meta.lua counts, and
-- rows is how many rows they carry between them: an item is a list now, so the two differ.
function E:Counts()
  local counts = {
    items = 0,
    rows = 0,
    summary = 0,
    questTitles = 0,
    kinds = 0,
    lists = 0,
    installed = self:Installed(),
  }
  for _, word in pairs(EraSources.CATEGORIES) do
    counts[word] = 0
  end
  local source = self:Table()
  local rows = source and source.r or nil
  if type(rows) ~= "table" then
    return counts
  end
  for _ in pairs(type(source.qt) == "table" and source.qt or EMPTY) do
    counts.questTitles = counts.questTitles + 1
  end
  for _ in pairs(type(source.ck) == "table" and source.ck or EMPTY) do
    counts.kinds = counts.kinds + 1
  end
  counts.lists = #(type(source.xl) == "table" and source.xl or EMPTY)
  local scan = {}
  for itemId, raw in pairs(rows) do
    if type(itemId) == "number" and (type(raw) == "table" or (type(raw) == "string" and source.packed == 1)) then
      counts.items = counts.items + 1
      for _, entry in scanRows(source, itemId, scan) do
        if type(entry) == "table" then
          counts.rows = counts.rows + 1
          if entry.t ~= nil then
            counts.summary = counts.summary + 1
          end
          local category = EraSources.CATEGORIES[entry.c]
          if category then
            counts[category] = counts[category] + 1
          end
        end
      end
    end
  end
  return counts
end

-- Registers EdgesFor with the graph, and NameFor beside it so a node opened by its key alone can
-- still be named. Safe to call twice: the previous registration is replaced rather than stacked,
-- the way Core/Quests.lua's Install is.
function E:Install()
  self:Uninstall()
  self.provider = function(key, direction)
    return self:EdgesFor(key, direction)
  end
  -- Every edge this answers is Predicted (E:_Mark), so the counts a tooltip draws skip it rather
  -- than load the table to throw its edges away (brief U3, Graph.RegisterProvider).
  Graph.RegisterProvider(self.provider, { predictedOnly = true })
  self.namer = function(key)
    return self:NameFor(key)
  end
  Graph.RegisterNamer(self.namer)
  return self.provider
end

function E:Installed()
  return self.provider ~= nil and Graph.HasProvider(self.provider) == true
end

-- Whether the namer is registered right now, which is a different question from the provider:
-- Graph.ClearNamers and Graph.ClearProviders are separate, so a spec can have one and not the
-- other.
function E:Naming()
  return self.namer ~= nil and Graph.HasNamer(self.namer) == true
end

function E:Uninstall()
  if self.provider then
    Graph.UnregisterProvider(self.provider)
    self.provider = nil
  end
  if self.namer then
    Graph.UnregisterNamer(self.namer)
    self.namer = nil
  end
end

-- The quest facts index (EraSources.QuestIndex), built once and kept, or nil on a build that
-- ships no table at all.
--
-- It is held against the very table it was built from rather than behind a flag, so the harness
-- swapping a data module underneath a loaded Core is answered from the new table on the next ask
-- and nothing here has to be told: E:Invalidate drops the other index, and this one notices.
function E:_QuestFactIndex()
  local source = self:Table()
  if not source then
    return nil
  end
  if self.questFactsFor ~= source then
    -- Brief RB4: the login slicer builds it (Core/Data.lua Data.PRELOAD_WARM), carried over frames.
    local index = EraSources.QuestIndex(source, type(Data) == "table" and Data.SliceCheck or nil)
    -- A caller that built the index whole while the slicer's pass was paused keeps its own.
    if self.questFactsFor == source then
      return self.questFacts
    end
    self.questFacts = index
    self.questFactsFor = source
    -- How many times it has been built. It is built once per table, so a spec reads this back
    -- rather than timing anything.
    self.factBuilds = (self.factBuilds or 0) + 1
  end
  return self.questFacts
end

-- Everything the table states about one quest, or nil where it states nothing.
--
-- UI/InfoPanel.lua's quest column is the one caller: a quest node that is OPENED asks once, which
-- is what pays for the pass over the table, and nothing on the way to a drawn tree asks at all.
--
-- Brief D5: a withheld item whose details are not served is left out of rewards and drops, and
-- facts.locked says how many distinct items that was. The answer is a new table every time, so
-- the index it was read from is never changed.
function E:QuestFacts(questId)
  local source = self:Table()
  if not source then
    return nil
  end
  local facts = EraSources.QuestFacts(source, questId, self:_QuestFactIndex())
  if type(facts) ~= "table" then
    return facts
  end
  local locked, counted = 0, {}
  local function keep(list)
    local kept = {}
    for _, entry in ipairs(list or EMPTY) do
      if type(entry) == "table" and type(entry.item) == "number" and not self:_Unlocked(entry.item) then
        if not counted[entry.item] then
          counted[entry.item] = true
          locked = locked + 1
        end
      else
        kept[#kept + 1] = entry
      end
    end
    return kept
  end
  facts.rewards = keep(facts.rewards)
  facts.drops = keep(facts.drops)
  facts.requires = keep(facts.requires)
  facts.locked = locked
  return facts
end

-- Brief Q10: what one quest asks the player to bring, out of qr, as { { itemId, count }, ... } in
-- slot order. Decoded on the first ask for that quest and kept, held against the very table it was
-- read from, the way E:_QuestFactIndex is. The list is this file's own and must not be modified.
function E:QuestRequires(questId)
  local source = self:Table()
  if not source or type(questId) ~= "number" then
    return EMPTY
  end
  if self.requiresFor ~= source then
    self.requiresCache = {}
    self.requiresFor = source
  end
  local held = self.requiresCache[questId]
  if not held then
    held = EraSources.QuestRequires(source, questId)
    self.requiresCache[questId] = held
  end
  return held
end

-- The reverse of qr (EraSources.RequiredByIndex), built on the first item whose Used by asks and
-- then kept, or nil on a build that ships no table at all. Nothing builds it at load, and a
-- Sources view never asks.
function E:_RequiredByIndex()
  local source = self:Table()
  if not source then
    return nil
  end
  if self.requiredByFor ~= source then
    -- Brief RB4: carried over frames by the login slicer (Data.SliceCheck).
    local index = EraSources.RequiredByIndex(source, type(Data) == "table" and Data.SliceCheck or nil)
    -- A caller that built the index whole while the slicer's pass was paused keeps its own.
    if self.requiredByFor == source then
      return self.requiredBy
    end
    self.requiredBy = index
    self.requiredByFor = source
    -- How many times it has been built: once per table, so a spec reads this back.
    self.requiredByBuilds = (self.requiredByBuilds or 0) + 1
  end
  return self.requiredBy
end

-- The quests whose qr asks for one item, as { { quest = questId, count = n } }, quest id
-- ascending. A new list every call.
function E:RequiredBy(itemId)
  local out = {}
  local index = type(itemId) == "number" and self:_RequiredByIndex() or nil
  local bucket = type(index) == "table" and index[itemId] or nil
  if type(bucket) ~= "table" then
    return out
  end
  for at = 1, #bucket - 1, 2 do
    out[#out + 1] = { quest = bucket[at], count = bucket[at + 1] }
  end
  return out
end

-- Brief Q1: the game event one quest belongs to, out of the shipped table's qe, or nil.
function E:QuestEvent(questId)
  return EraSources.QuestEvent(self:Table(), questId)
end

-- Brief INT1b: the class mask of a class quest, out of the shipped table's qa, or nil. Brief QB2:
-- the client's quest cache is asked first (Core/QuestFlags.lua Classes), and its answer wins.
function E:QuestClasses(questId)
  local flags = ItemTree.QuestFlags
  if type(flags) == "table" and type(flags.Classes) == "function" then
    local mask = flags.Classes(questId)
    if mask ~= nil then
      return mask
    end
  end
  return EraSources.QuestClasses(self:Table(), questId)
end

-- Brief QB2: a Classic Era reward row (an item's quest row, a quest's reward row) marked by what the
-- client's quest cache says of it (Core/QuestFlags.lua MarkReward): confirmed, it loses the Predicted
-- mark; changed, it reads "changed in Forever". Answers edge.
function E:_MarkReward(edge, questId, itemId)
  local flags = ItemTree.QuestFlags
  if type(flags) == "table" and type(flags.MarkReward) == "function" then
    flags.MarkReward(edge, questId, itemId)
  end
  return edge
end

-- Brief Q1 (the owner's rulings of 2026-10-09): a Classic quest whose id the Forever client's own
-- tables list exists in Forever (Core/QuestFlags.lua IsListed), so its rows are no longer Predicted:
-- such an edge is the baseline tier with listed = true, which takes off the Predicted mark, keeps it
-- with "Show predicted data" off and lets Core/Keep.lua count it, while it stays history (the
-- counts are still Classic Era's, the client ships no requirements) and below a curated or a
-- collected row of the same quest. Core/ViewModel.lua draws no "not yet confirmed" mark or notice
-- for it. A quest the client does not list (or no listing shipped) stays Predicted, as before. The
-- edge also carries the quest's side where the listing states one (faction, which Keep and the
-- tree's "Alliance only" read) and, for a quest tied to a game event (qe), event and the row's
-- "Event" tag. Answers edge.
function E:_MarkQuest(edge, questId)
  local flags = ItemTree.QuestFlags
  if type(flags) == "table" and type(flags.IsListed) == "function" and flags.IsListed(questId) == true then
    edge.confidence = Confidence.BASELINE
    edge.listed = true
    local side = type(flags.Side) == "function" and flags.Side(questId) or nil
    if side ~= nil and edge.faction == nil then
      edge.faction = side
    end
  end
  local event = self:QuestEvent(questId)
  if event then
    edge.event = event
    edge.meta = L["Event"]
  end
  return edge
end

-- An item's Used by rows for the Classic Era quests that ask for it: QUEST_OBJECTIVE, under the
-- item's Quests group like a curated or a collected one, with the count the quest asks for, and
-- marked as history (E:_Mark). The quest's own title comes from the namer (qt in either form, or
-- the quest rows), so nothing is named here. Core/Graph.lua drops one where the curated table or
-- the collector states that quest's requirements, which win. Brief Q1: E:_MarkQuest.
function E:RequiredByEdges(itemId)
  local out = {}
  for _, entry in ipairs(self:RequiredBy(itemId)) do
    out[#out + 1] = self:_MarkQuest(
      self:_Mark({
        type = T.QUEST_OBJECTIVE,
        target = Graph.Key("quest", entry.quest),
        quantity = entry.count,
        group = L["Quests"],
      }),
      entry.quest
    )
  end
  return out
end

-- Brief NX1 (the owner's ruling "2A" of 2026-10-22, the Classic Era provided items): the item one quest
-- hands the player when it is taken, out of the shipped table's qp (EraSources.QuestProvided), as
-- { { itemId, count } }, leaving out an item that starts the quest (PV1's rule, EraSources.ProvidedIsStarter)
-- and a withheld item whose details are not served (as the quest's rewards and requirements leave it out).
-- A new list every call. What the quest page's "Provided items" category draws under the Classic Era line
-- (Core/ViewModel.lua EraQuestProvided).
function E:QuestProvided(questId)
  local out = {}
  if type(questId) ~= "number" then
    return out
  end
  for _, pair in ipairs(EraSources.QuestProvided(self:Table(), questId)) do
    if not EraSources.ProvidedIsStarter(pair[1], questId) and self:_Unlocked(pair[1]) then
      out[#out + 1] = { pair[1], pair[2] }
    end
  end
  return out
end

-- Brief NX1: the quests the shipped table's qp says hand one item over (EraSources.ProvidedBy), less a quest
-- the item itself starts (EraSources.ProvidedIsStarter), quest id ascending, a new list every call.
function E:ProvidedBy(itemId)
  local out = {}
  if type(itemId) ~= "number" then
    return out
  end
  for _, questId in ipairs(EraSources.ProvidedBy(self:Table(), itemId)) do
    if not EraSources.ProvidedIsStarter(itemId, questId) then
      out[#out + 1] = questId
    end
  end
  return out
end

-- Brief NX1: an item's Sources rows for the Classic Era quests that hand it over when taken: the existing
-- QUEST_PROVIDED edge ("Provided by quest", the Quest type column) under the item's Quests group, marked as
-- history (E:_Mark: the Classic Era line) and by the listing (E:_MarkQuest: a quest the client lists loses
-- the Predicted mark, as its Used by rows do). A recorded hand-over (Core/PlayerSources.lua) of the same
-- quest outranks it in the graph's merge, and the pipeline holds a claimed provided item the Era rows state
-- (ItemTree-Data quest_claims, `provided: era`), so one quest is one row.
function E:ProvidedEdges(itemId)
  local out = {}
  for _, questId in ipairs(self:ProvidedBy(itemId)) do
    out[#out + 1] = self:_MarkQuest(
      self:_Mark({
        type = T.QUEST_PROVIDED,
        target = Graph.Key("quest", questId),
        group = L["Quests"],
      }),
      questId
    )
  end
  return out
end

-- A quest's Requires rows out of qr, walking up: one AND group, each item with its count, the
-- way Core/Quests.lua draws a curated quest's. A withheld item whose details are not served is
-- left out, exactly as a quest's rewards leave it out. Brief Q1: a quest the client lists is not
-- Predicted here either (the baseline tier with listed, as E:_MarkQuest marks the Used by rows);
-- the side and the event tag are the Used by row's alone.
function E:QuestRequiresEdges(questId)
  local out = {}
  local flags = ItemTree.QuestFlags
  local listed = type(flags) == "table" and type(flags.IsListed) == "function" and flags.IsListed(questId) == true
  for _, pair in ipairs(self:QuestRequires(questId)) do
    if self:_Unlocked(pair[1]) then
      local edge = self:_Mark({
        type = T.QUEST_REQUIRES,
        target = Graph.Key("item", pair[1]),
        quantity = pair[2],
        group = L["Requires"],
      })
      if listed then
        edge.confidence = Confidence.BASELINE
        edge.listed = true
      end
      out[#out + 1] = edge
    end
  end
  return out
end

-- How many distinct items in one creature's loot are withheld items whose details are not served,
-- which is what E:CreatureEdges leaves out. 0 for a key that names no creature.
function E:CreatureLocked(key)
  local nameIndex = self:CreatureAt(key)
  if not nameIndex then
    return 0
  end
  local index = self:_LootIndex()
  local byCategory = type(index) == "table" and index.loot and index.loot[nameIndex] or nil
  if type(byCategory) ~= "table" then
    return 0
  end
  local locked, seen = 0, {}
  for _, bucket in pairs(byCategory) do
    for at = 1, #bucket, LOOT_STRIDE do
      local itemId = bucket[at]
      if type(itemId) == "number" and not seen[itemId] then
        seen[itemId] = true
        if not self:_Unlocked(itemId) then
          locked = locked + 1
        end
      end
    end
  end
  return locked
end

--------------------------------------------------------------------------------
-- A creature root, answered (brief E57)
--------------------------------------------------------------------------------

-- The name in the string table behind one of this file's own node keys, and the place the key
-- states. Arithmetic over a row key, and one lookup in ci's reverse map for a creature's page key
-- (brief EK1), so nothing is decoded: the window asks this of every root it opens.
--
-- Only an npc key can be a creature. A gathering node is a zone key, a container is an item key
-- and a quest is a quest key, and an object key is a chest, a node or a fishing hole, none of
-- which the table ships a kind for.
function E:CreatureAt(key)
  local kind = Graph.Parse(key)
  if kind ~= "npc" then
    return nil
  end
  -- Brief N2: a positive id joins the Classic Era name it carries (E:NpcNameAt).
  return self:NpcNameAt(key)
end

-- Brief EK2: the CMaNGOS creature id (ci) of the Classic Era name one npc key joins, or nil: what a
-- guess (Core/GuessSources.lua R:ItemsForEraCreature) and the Boss loot index (ei) name a Classic Era
-- creature by, so a caller matches on an id and never on a name's place.
function E:CreatureIdAt(key)
  local nameIndex = self:CreatureAt(key)
  if not nameIndex then
    return nil
  end
  return EraSources.CreatureIdOf(self:Table(), nameIndex)
end

-- What kind of creature one of this file's own npc keys names: the name index, then the type, the
-- family, the level band and the role ("creature", "vendor" or "both", brief N3). nil for a key that
-- names neither a creature nor a vendor, which is every object and every summary row.
--
-- Two table lookups and a little arithmetic, and deliberately cheaper than E:CreatureFacts: this
-- is what decides whether a root gets a creature's two tabs or an item's four
-- (Core/ViewModel.lua ViewsFor), and it is asked on every open of every node. Nothing here builds
-- the loot index.
function E:CreatureKind(key)
  local nameIndex = self:CreatureAt(key)
  if not nameIndex then
    return nil
  end
  local source = self:Table()
  if not source or not stringAt(source, nameIndex) then
    return nil
  end
  local creatureType, family, low, high, role = EraSources.KindOf(source, nameIndex)
  if not creatureType then
    return nil
  end
  return nameIndex, creatureType, family, low, high, role
end

-- The creature loot index (EraSources.LootIndex), built once and kept, or nil on a build that
-- ships no table at all.
--
-- Held against the very table it was built from rather than behind a flag, the way
-- E:_QuestFactIndex is, so the harness swapping a data module underneath a loaded Core is answered
-- from the new table on the next ask and nothing here has to be told.
function E:_LootIndex()
  local source = self:Table()
  if not source then
    return nil
  end
  if self.lootFor ~= source then
    local index = EraSources.LootIndex(source, type(Data) == "table" and Data.SliceCheck or nil)
    -- Brief PF3b: a caller that built the index whole while the slicer's pass was paused keeps its own.
    if self.lootFor == source then
      return self.lootIndex
    end
    self.lootIndex = index
    self.lootFor = source
    -- How many times it has been built. It is built once per table, so a spec reads this back
    -- rather than timing anything.
    self.lootBuilds = (self.lootBuilds or 0) + 1
  end
  return self.lootIndex
end

-- What the loot index cost, for the spec and the debug command: how many times it has been built,
-- how many entries it holds and how many packed lists the pass decoded.
--
-- lists is counted here and not in era.decodes, and that is the point. era.decodes has always
-- meant one thing, which is a list decoded through E:More because a player opened a summary row,
-- and tests/spec/era_display_spec.lua pins it at 0 for an ordinary tree build. This pass is a
-- different question asked on a different page, so it keeps its own count and that promise still
-- holds: nothing on the way to a drawn tree calls E:_LootIndex.
function E:LootCounts()
  local index = self.lootIndex
  return {
    builds = self.lootBuilds or 0,
    entries = (index and index.entries) or 0,
    lists = (index and index.lists) or 0,
    names = (index and index.names) or 0,
    -- Brief OL1: the object and container halves of the same pass, counted apart.
    objectEntries = (index and index.objectEntries) or 0,
    objectLists = (index and index.objectLists) or 0,
    objectNames = (index and index.objectNames) or 0,
    containerEntries = (index and index.containerEntries) or 0,
    containerLists = (index and index.containerLists) or 0,
  }
end

-- Everything the table states about the creature one npc key names, or nil for a key that names
-- no creature. The left column's one caller, so the index pass is paid on a creature page being
-- opened and never while a tree is built.
function E:CreatureFacts(key)
  local nameIndex, areaId = self:CreatureAt(key)
  if not nameIndex then
    return nil
  end
  local source = self:Table()
  if not source then
    return nil
  end
  local facts = EraSources.CreatureFacts(source, nameIndex, self:_LootIndex())
  if not facts then
    return nil
  end
  -- Brief D5: how many of its items the Loot tab leaves out, for the column's one line about them.
  facts.locked = self:CreatureLocked(key)
  -- Brief N3: a vendor has no loot rows to say where it stands, so its places are the ones its
  -- Sold by rows state. The vendor index is the one an npc page has already built.
  if facts.role ~= "creature" then
    local vendor = self:VendorFacts(key)
    local held = {}
    for _, area in ipairs(facts.zones) do
      held[area.areaId] = true
    end
    for _, area in ipairs(type(vendor) == "table" and vendor.zones or EMPTY) do
      if not held[area.areaId] then
        held[area.areaId] = true
        facts.areaIds[#facts.areaIds + 1] = area.areaId
        facts.zones[#facts.zones + 1] = area
      end
    end
  end
  -- Brief P6b: a trainer has no loot rows to say where it stands either, so a name that teaches and
  -- has no place yet takes the areas its own pins stand in, the busiest first. teaches is how many
  -- recipes it teaches, 0 for a creature that teaches none.
  facts.teaches = EraSources.TeachCount(source, nameIndex)
  if #facts.zones == 0 and facts.teaches > 0 then
    for _, area in ipairs(self:TrainerAreas(nameIndex)) do
      if area.name then
        facts.areaIds[#facts.areaIds + 1] = area.areaId
        facts.zones[#facts.zones + 1] = { areaId = area.areaId, name = area.name }
      end
    end
  end
  -- The place the key itself states leads the list where the index somehow did not hold it, so a
  -- creature opened from a row that named a zone always says that zone.
  if type(areaId) == "number" then
    local held = false
    for _, area in ipairs(facts.zones) do
      if area.areaId == areaId then
        held = true
      end
    end
    if not held then
      table.insert(facts.areaIds, 1, areaId)
      table.insert(facts.zones, 1, { areaId = areaId, name = areaName(source, areaId) })
    end
  end
  return facts
end

-- One creature's loot as the EDGES the Loot tab draws, in the contract's category order with the
-- best chance first inside each.
--
-- The same _Mark every other edge out of this file carries, so a creature's loot wears the
-- Predicted badge, follows the "Show predicted data" setting and says "Classic Era" in exactly
-- the same words an item's own source row does. Every edge points at a real item node, which this
-- build names itself, so nothing here writes a name onto the graph.
--
-- Nothing on the ordinary path to a drawn tree calls this: Core/ViewModel.lua asks only for the
-- loot view of a creature root, which is a page the player opened.
function E:CreatureEdges(key)
  local out = {}
  local nameIndex = self:CreatureAt(key)
  if not nameIndex then
    return out
  end
  local source = self:Table()
  if not source then
    return out
  end
  local rows = EraSources.CreatureRows(source, nameIndex, self:_LootIndex(), function(questId)
    return self:QuestTitle(questId)
  end)
  return self:_LootEdges(rows)
end

-- Brief OL1: the loot index's rows as the edges a Loot or Contains tab draws, marked the way
-- E:CreatureEdges marks a creature's (the Predicted badge, the "Show predicted data" setting, the
-- Classic Era words), withheld items whose details are not served left out.
function E:_LootEdges(rows)
  local out = {}
  for _, row in ipairs(rows) do
    if row.edge and self:_Unlocked(row.item) then
      out[#out + 1] = self:_Mark({
        type = row.edge,
        target = row.key,
        group = row.group,
        zone = row.zone,
        areaId = row.areaId,
        percent = row.chance,
        percentSource = EraSources.PROVENANCE,
        note = row.note,
      })
    end
  end
  return out
end

-- Brief OL1: what one Classic Era OBJECT holds, as the edges its Loot tab draws: the chest's
-- "Found in" rows read from the chest's end, one per item and zone, best chance first. Keyed by the
-- object's name (E:ObjectAt), so every object of that name answers the same list, each row naming
-- its zone. Builds the loot index on the first page that asks; nothing on the way to a drawn tree
-- does.
function E:ObjectEdges(key)
  local nameIndex = self:ObjectAt(key)
  local source = self:Table()
  if not nameIndex or not source then
    return {}
  end
  return self:_LootEdges(EraSources.ObjectRows(source, nameIndex, self:_LootIndex()))
end

-- Brief OL1: whether one object key's page has a Loot tab, which is where the table states "Found
-- in" rows for its name. ok answers for every name with pins without building anything: 11 (a
-- chest or another looted object, every one of which has such rows on build 1.60.1.70291) is a
-- yes, and a herb, a vein or a fishing pool is a no, as is every gathering node row, whose name is
-- a herb or a vein. Only a name ok does not file (an object with no pins: 113 of them have "Found
-- in" rows, Large Battered Chest among them) asks the loot index, and that is the page being opened.
-- So a drawn tree, which asks this only of its node rows (Core/ViewModel.lua hasNodePage), never
-- builds the index.
function E:ObjectHasLoot(key)
  if EraSources.IsNodeKey(key) then
    return false
  end
  local nameIndex = self:ObjectAt(key)
  local source = self:Table()
  if not nameIndex or not source then
    return false
  end
  local kinds = source.ok
  local filed = type(kinds) == "table" and kinds[nameIndex] or nil
  if filed ~= nil then
    return filed == OBJECT_CATEGORY
  end
  local index = self:_LootIndex()
  local objects = type(index) == "table" and index.objects or nil
  return type(objects) == "table" and objects[nameIndex] ~= nil
end

-- Brief OL1: the item id behind an item key whose item row says it can be opened (op 1), or nil.
-- One item row read (local data, never a client ask), so ViewsFor may ask it on every item open.
local function openableId(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "item" or type(id) ~= "number" or id <= 0 then
    return nil
  end
  if type(Data) ~= "table" or type(Data.GetItem) ~= "function" then
    return nil
  end
  local ok, row = pcall(Data.GetItem, Data, id)
  if not ok or type(row) ~= "table" or tonumber(row.op) ~= 1 then
    return nil
  end
  return id
end

-- Brief OL1: what one openable ITEM holds, as the edges its Contains tab draws: the table's
-- container rows read from the container's end, best chance first. Only an item its row calls
-- openable asks, and that ask builds the loot index the first time.
function E:ContainerEdges(key)
  local id = openableId(key)
  local source = self:Table()
  if not id or not source then
    return {}
  end
  return self:_LootEdges(EraSources.ContainerRows(source, id, self:_LootIndex()))
end

-- Brief OL1: whether an item key's page has a Contains tab: its row calls it openable and the table
-- states at least one container row for it. The item row read decides for every other item, so the
-- loot index is built only for an openable item's page.
function E:ContainerHasContents(key)
  local id = openableId(key)
  if not id or not self:Table() then
    return false
  end
  local index = self:_LootIndex()
  local bucket = type(index) == "table" and type(index.containers) == "table" and index.containers[id] or nil
  return type(bucket) == "table" and #bucket > 0
end

--------------------------------------------------------------------------------
-- An object root, answered (brief D7)
--------------------------------------------------------------------------------

-- The name index and the place behind one of this file's own object keys: a gathering node row, a
-- chest or a fishing pool in one zone, or a name with no place. Nothing is decoded; every such key
-- holds a gameobject id (brief EK1 2c, EK2) that oi reads back, so the table is asked for, and only
-- for a key of ours: any other object key (a live object, a guess's node) loads nothing.
function E:ObjectAt(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "object" then
    return nil
  end
  local source = nil
  if isPageId(id) or rowWindow(id) then
    source = self:Table()
  end
  return EraSources.ObjectAt(id, source)
end

-- The name index behind one object key, where the table ships map pins for that name, or nil. What
-- decides whether an object root gets the Map tab (Core/ViewModel.lua ViewsFor), and it is asked on
-- every open of every node: two table lookups and a string lookup, and no pin is decoded.
function E:ObjectMap(key)
  local nameIndex = self:ObjectAt(key)
  if not nameIndex then
    return nil
  end
  local source = self:Table()
  if not source or not stringAt(source, nameIndex) then
    return nil
  end
  if not EraSources.HasObjectPins(source, nameIndex) then
    return nil
  end
  return nameIndex
end

-- The name index behind one object key that has a page of its own, or nil: every object ObjectMap
-- answers (a name with pins), and every gathering node row this file makes (a herb or a vein, brief
-- D6) whether or not its name has pins. The owner (P6b addendum, Thorium Ore's Mined from rows): an
-- "Ooze Covered Rich Thorium Vein" with no pins could only be expanded, while "Rich Thorium Vein"
-- opened its page. A node row names its zones itself, so its page has something to say and its Map
-- tab lists them with "no positions known" (brief Q9b). Arithmetic and a string lookup, nothing
-- decoded; asked by Core/ViewModel.lua ViewsFor, which answers the node's views and so whether its
-- row opens a page.
function E:ObjectPage(key)
  local nameIndex = self:ObjectMap(key)
  if nameIndex then
    return nameIndex
  end
  -- Brief EO1: a world object that starts or ends quests (og) has a page too, pins or none, so a
  -- quest's giver row opens it on its Quests tab.
  if self:ObjectGivesQuests(key) then
    return self:ObjectAt(key)
  end
  if not EraSources.IsNodeKey(key) then
    return nil
  end
  nameIndex = self:ObjectAt(key)
  local source = self:Table()
  if not nameIndex or not source or not stringAt(source, nameIndex) then
    return nil
  end
  return nameIndex
end

-- Brief EO1: whether the world object one object key names starts or ends a quest the table lists
-- (og), out of the two list lengths: nothing decoded. false for any other key.
function E:ObjectGivesQuests(key)
  if Graph.Kind(key) ~= "object" then
    return false
  end
  local nameIndex = self:ObjectAt(key)
  if not nameIndex then
    return false
  end
  local source = self:Table()
  if not source or not stringAt(source, nameIndex) then
    return false
  end
  local starts, ends = EraSources.ObjectQuestCounts(source, nameIndex)
  return starts + ends > 0
end

-- Brief EO1: whether one object key's page is a quest giving object's and nothing else's (og lists
-- quests for its name, ok files it under no category and it is no gathering node row), so its title
-- is its own name rather than "<name> node". false for any other key.
function E:ObjectGiverOnly(key)
  if not self:ObjectGivesQuests(key) or EraSources.IsNodeKey(key) then
    return false
  end
  return EraSources.ObjectKind(self:Table(), self:ObjectAt(key)) == nil
end

-- Everything the table states about the herb, vein, fishing pool or chest one object key names, or
-- nil for a key that names none (a live object, a summary row, a name the table files under no
-- object category):
--
--   nameIndex  the name's index into s, which is what E:ObjectPinsOf takes
--   name       the object's name
--   category   "herb", "vein", "fished" or "object", out of ok, or the node row's own category
--   zones      { { areaId, name } }: the zones the key's own row lists first (a node row's zone
--              rows, a chest's one zone), then every further area its pins stand in, each once
--   inside     for a node that stands only inside instances, the words its row's zone column says
--   pinned     true where the table ships pins for the name, which is when the page has a map
--   starts, ends  brief EO1: how many quests the name starts and ends (og), each 0 for none. A
--              world object that gives quests answers with no category (a wanted poster is no node
--              and no chest), and its page says what it gives instead of what it is
--
-- Reads the item's rows for a node key (the ordinary path to a drawn tree already has), and decodes
-- the name's pins where it has any: the page is open, so the map is about to want them anyway.
function E:ObjectFacts(key)
  local kind, id = Graph.Parse(key)
  local nameIndex, areaId = self:ObjectAt(key)
  if kind ~= "object" or not nameIndex then
    return nil
  end
  local source = self:Table()
  local name = source and stringAt(source, nameIndex) or nil
  if not name then
    return nil
  end
  local starts, ends = EraSources.ObjectQuestCounts(source, nameIndex)
  local facts = {
    nameIndex = nameIndex,
    name = name,
    category = EraSources.ObjectKind(source, nameIndex),
    zones = {},
    pinned = EraSources.HasObjectPins(source, nameIndex),
    starts = starts,
    ends = ends,
  }
  local seen = {}
  local function add(area)
    if type(area) ~= "number" or seen[area] then
      return
    end
    local named = areaName(source, area)
    if named then
      seen[area] = true
      facts.zones[#facts.zones + 1] = { areaId = area, name = named }
    end
  end
  if EraSources.NodeAt(id) then
    local row = self:NodeRow(key)
    if row then
      facts.category = facts.category or row.category
      for _, zone in ipairs(row.zones or EMPTY) do
        add(zone.areaId)
      end
      if row.inside then
        facts.inside = row.zone
      end
    end
  end
  add(areaId)
  if not facts.category and starts + ends == 0 then
    return nil
  end
  if facts.pinned then
    for _, pin in ipairs(self:ObjectPinsOf(nameIndex)) do
      add(pin.area)
    end
  end
  return facts
end

--------------------------------------------------------------------------------
-- A vendor, and what it sells (brief N2)
--------------------------------------------------------------------------------

-- The other side of a "Sold by" row. The table is keyed by item, so the only way to answer "what
-- does this vendor sell" is one pass over it, the way EraSources.LootIndex answers a creature.
--
-- How many numbers one entry takes: the item, the stock (0 for a vendor that holds no limit) and
-- the area (0 for a row that states none). A flat array rather than a table per entry, for the same
-- reason the loot index is one.
local VENDOR_STRIDE = 3

-- Two sides stated for one name is both of them, which is what f = 3 says.
local BOTH_SIDES = 3

local function joinSides(held, faction)
  if faction ~= 1 and faction ~= 2 and faction ~= BOTH_SIDES then
    return held
  end
  if held == nil or held == faction then
    return faction
  end
  return BOTH_SIDES
end

-- Vendor to the items it sells, built in ONE pass over the whole table: every named c = 4 row in
-- r, and every packed vendor list in x and xl, which no other pass ever decodes (a list record of a
-- vendor carries the name, the area and the stock and nothing else; the side is only ever on a
-- named row). Built on the first npc page OPENED and then kept (E:_VendorIndex), and never on the
-- way to a drawn tree. tests/spec/era_creature_spec.lua measures it on the real table.
--
--   sells[nameIndex]  a flat array of VENDOR_STRIDE numbers per item, in item id order, one entry
--                     per item: a vendor the table states twice for one item (two areas) is one
--                     row, which keeps the first area and any stock either states
--   sides[nameIndex]  1 Alliance, 2 Horde, 3 both, where a named row states a side
--   entries           how many entries there are in all
--   lists             how many packed lists this pass decoded
--   names             how many vendor names carry anything at all
--
-- Brief PF3b: check, where given, is called once per item row (Data.SliceCheck), as for
-- EraSources.LootIndex; about 30 ms offline over the shipped data, built by the login slicer.
function EraSources.VendorIndex(source, check)
  local index = { sells = {}, sides = {}, entries = 0, lists = 0, names = 0 }
  local rows = type(source) == "table" and source.r or nil
  if type(rows) ~= "table" then
    return index
  end
  local sells = index.sells

  local function add(nameIndex, itemId, stock, areaId)
    if type(nameIndex) ~= "number" or nameIndex < 1 or type(itemId) ~= "number" then
      return
    end
    local bucket = sells[nameIndex]
    if not bucket then
      bucket = {}
      sells[nameIndex] = bucket
      index.names = index.names + 1
    end
    local at = #bucket
    -- Items arrive in id order and one item's rows are read together, so the same item twice for
    -- one vendor is always the bucket's own last entry.
    if at >= VENDOR_STRIDE and bucket[at - 2] == itemId then
      if bucket[at - 1] == 0 and stock > 0 then
        bucket[at - 1] = stock
      end
      if bucket[at] == 0 and areaId > 0 then
        bucket[at] = areaId
      end
      return
    end
    bucket[at + 1] = itemId
    bucket[at + 2] = stock
    bucket[at + 3] = areaId
    index.entries = index.entries + 1
  end

  -- Brief RB4: the ids in order, sorted once per table (sortedItemIds).
  local ids = sortedItemIds(rows)

  local lists = type(source.xl) == "table" and source.xl or nil
  local width = recordWidth(VENDOR_CATEGORY)
  local scan = { only = { [VENDOR_CATEGORY] = true }, onlyKey = "c" }
  for _, itemId in ipairs(ids) do
    if check then
      check()
    end
    for _, raw in scanRows(source, itemId, scan) do
      if type(raw) == "table" and raw.c == VENDOR_CATEGORY and raw.t == nil and type(raw.n) == "number" then
        local stock = tonumber(raw.k) or 0
        if stock < 0 then
          stock = 0
        end
        add(raw.n, itemId, stock, tonumber(raw.a) or 0)
        index.sides[raw.n] = joinSides(index.sides[raw.n], raw.f)
      end
    end
    local byCategory = type(source.x) == "table" and source.x[itemId] or nil
    local slot = type(byCategory) == "table" and byCategory[VENDOR_CATEGORY] or nil
    local text = type(slot) == "number" and lists and lists[slot] or nil
    if type(text) == "string" and text ~= "" and #text % width == 0 then
      index.lists = index.lists + 1
      for at = 1, #text, width do
        local nameIndex = packedInt(text, at, PACK_NAME)
        local areaId = packedInt(text, at + PACK_NAME, PACK_AREA)
        local stock = packedInt(text, at + PACK_NAME + PACK_AREA, PACK_VALUE)
        if nameIndex and nameIndex > 0 and areaId and stock then
          add(nameIndex, itemId, stock, areaId)
        end
      end
    end
  end
  return index
end

-- One vendor's stock, as the rows its Sells tab draws, in item id order (the view model sorts them
-- by name). Each row carries the fields a normalised source row does (category, edge, group, note,
-- key, stock, area, areaId, zone) plus the item it names in `item`, the way a creature's loot row
-- does. index is an EraSources.VendorIndex, built here for a caller that holds none.
function EraSources.VendorRows(source, nameIndex, index)
  if type(source) ~= "table" or type(nameIndex) ~= "number" then
    return EMPTY
  end
  if type(index) ~= "table" or type(index.sells) ~= "table" then
    index = EraSources.VendorIndex(source)
  end
  local bucket = index.sells[nameIndex]
  if type(bucket) ~= "table" then
    return EMPTY
  end
  local out = {}
  for at = 1, #bucket, VENDOR_STRIDE do
    local itemId = bucket[at]
    local stock = bucket[at + 1] or 0
    local areaId = bucket[at + 2] or 0
    if areaId <= 0 then
      areaId = nil
    end
    if stock <= 0 then
      stock = nil
    end
    local area = areaName(source, areaId)
    out[#out + 1] = place({
      category = "vendor",
      item = itemId,
      stock = stock,
      note = phrase("LimitedStock", stock),
      area = area,
      areaId = areaId,
      zone = area,
      key = Graph.Key("item", itemId),
    }, { edge = "SELLS", group = "Sells" })
  end
  return out
end

-- Everything the table states about one VENDOR, or nil for a name it lists as selling nothing.
--
--   nameIndex  the name's place in the string table
--   name       the vendor's own name
--   faction    1 Alliance, 2 Horde, 3 both sides (cf, else a named row's f), or nil where none says
--   title      the vendor's title ("Wrought Iron Supplies", st), or nil
--   total      how many items it sells
--   limited    how many of them it holds a limited stock of
--   display    the id the client draws its portrait from, or nil (cd; a vendor has one only where
--              the same name is a creature too)
--   areaIds    every area a row states for it, ascending, and zones those areas' own names
function EraSources.VendorFacts(source, nameIndex, index)
  if type(source) ~= "table" or type(nameIndex) ~= "number" then
    return nil
  end
  local name = stringAt(source, nameIndex)
  if not name then
    return nil
  end
  if type(index) ~= "table" or type(index.sells) ~= "table" then
    index = EraSources.VendorIndex(source)
  end
  local bucket = index.sells[nameIndex]
  if type(bucket) ~= "table" or #bucket == 0 then
    return nil
  end
  local facts = {
    nameIndex = nameIndex,
    name = name,
    -- Brief T2b: the name's own side out of cf, which every vendor carries on a table compiled
    -- since 2026-09-27; a table from before that states the side on a named row, if at all.
    faction = EraSources.Faction(source, nameIndex) or (index.sides and index.sides[nameIndex]) or nil,
    title = EraSources.Title(source, nameIndex),
    display = EraSources.DisplayOf(source, nameIndex),
    total = math.floor(#bucket / VENDOR_STRIDE),
    limited = 0,
    areaIds = {},
    zones = {},
  }
  local seen = {}
  for at = 1, #bucket, VENDOR_STRIDE do
    if (bucket[at + 1] or 0) > 0 then
      facts.limited = facts.limited + 1
    end
    local areaId = bucket[at + 2]
    if type(areaId) == "number" and areaId > 0 and not seen[areaId] then
      seen[areaId] = true
      facts.areaIds[#facts.areaIds + 1] = areaId
    end
  end
  table.sort(facts.areaIds)
  for _, areaId in ipairs(facts.areaIds) do
    facts.zones[#facts.zones + 1] = { areaId = areaId, name = areaName(source, areaId) }
  end
  return facts
end

-- The name index of one exact name in the string table, lower cased on both sides, or nil. One
-- walk of s builds the whole map, which a caller keeps (E:NameIndexOf).
function EraSources.NameMap(source, check)
  local map = {}
  local strings = type(source) == "table" and source.s or nil
  if type(strings) ~= "table" then
    return map
  end
  for index, text in ipairs(strings) do
    -- Brief RB4: check, where given, is called once per string (Data.SliceCheck).
    if check then
      check()
    end
    if type(text) == "string" and text ~= "" then
      local lower = text:lower()
      if map[lower] == nil then
        map[lower] = index
      end
    end
  end
  return map
end

-- The vendor index, built once per table and kept, or nil on a build that ships no table. Held
-- against the table it was built from, the way E:_LootIndex is.
function E:_VendorIndex()
  local source = self:Table()
  if not source then
    return nil
  end
  if self.vendorFor ~= source then
    local index = EraSources.VendorIndex(source, type(Data) == "table" and Data.SliceCheck or nil)
    -- Brief PF3b: a caller that built the index whole while the slicer's pass was paused keeps its own.
    if self.vendorFor == source then
      return self.vendorIndex
    end
    self.vendorIndex = index
    self.vendorFor = source
    self.vendorBuilds = (self.vendorBuilds or 0) + 1
  end
  return self.vendorIndex
end

-- What the vendor index cost, for the spec and the debug command, the way E:LootCounts is.
function E:VendorCounts()
  local index = self.vendorIndex
  return {
    builds = self.vendorBuilds or 0,
    entries = (index and index.entries) or 0,
    lists = (index and index.lists) or 0,
    names = (index and index.names) or 0,
  }
end

-- Brief RB4: the name map (EraSources.NameMap), one walk of s, made on the first ask and kept, or
-- nil on a build that ships no table. The owner's first Ctrl click on a creature built it inside the
-- click (his "lookup 8.6 ms"; about 7 ms offline over the shipped 1.60.1.70425 data), so it is built
-- behind the loading screen now (Core/Data.lua Data.PRELOAD_LOADING_SCREEN), and the login slicer
-- carries it over frames where that build did not run (Data.SliceCheck).
function E:_NameMap()
  local source = self:Table()
  if not source then
    return nil
  end
  if self.nameMapFor ~= source then
    local map = EraSources.NameMap(source, type(Data) == "table" and Data.SliceCheck or nil)
    -- A caller that built the map whole while the slicer's pass was paused keeps its own.
    if self.nameMapFor == source then
      return self.nameMap
    end
    self.nameMap = map
    self.nameMapFor = source
  end
  return self.nameMap
end

-- The string index of one name, or nil. The map is one walk of s, made on the first ask and kept.
function E:NameIndexOf(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  local map = self:_NameMap()
  if not map then
    return nil
  end
  return map[name:lower()]
end

-- The join (brief N2): the Classic Era name an npc key stands for, whichever kind of key it is.
-- A creature's page key (brief EK1) and one of this file's own row keys (a placed or a pocket key,
-- brief EK2) state its creature id, which ci reads back to the name (EraSources.CreatureAt), so a
-- creature or a vendor of one name answers that one index whatever place its keys carry, and the
-- page opened from either reads the same name. A POSITIVE id is an NPC the client named (the
-- collector's sightings, an installed source database), and it joins the page of the Classic Era
-- name it carries: the name the graph holds for it, matched without regard to case, the way
-- Core/Graph.lua drops a Classic Era row that names what a live row names. nil for a key that joins
-- nothing. A page key and (brief EK2) a placed or pocket key ask for the table, since each holds a
-- creature id ci reads back; any other negative key loads nothing.
function E:NpcNameAt(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "npc" or type(id) ~= "number" then
    return nil
  end
  if id > 0 then
    -- Brief EK1 2b: a merged name's page is its own key, so it joins its name without a lookup.
    local merged = mergedNameOf(self:Table(), id)
    if merged then
      return merged
    end
    return self:NameIndexOf(Graph.Name(key))
  end
  local source = nil
  if isPageId(id) or rowWindow(id) then
    source = self:Table()
  end
  return EraSources.CreatureAt(id, source)
end

-- The name index an npc key names as a VENDOR, or nil. Asked by Core/ViewModel.lua ViewsFor on the
-- open of an npc root: after the first npc page it is one table lookup, and the first pays for the
-- vendor index once (measured beside the loot index).
function E:VendorKind(key)
  local nameIndex = self:NpcNameAt(key)
  if not nameIndex then
    return nil
  end
  local index = self:_VendorIndex()
  local bucket = type(index) == "table" and index.sells[nameIndex] or nil
  if type(bucket) ~= "table" or #bucket == 0 then
    return nil
  end
  return nameIndex
end

-- Everything the table states about the vendor one npc key names, or nil.
function E:VendorFacts(key)
  local nameIndex = self:VendorKind(key)
  if not nameIndex then
    return nil
  end
  return EraSources.VendorFacts(self:Table(), nameIndex, self:_VendorIndex())
end

-- One vendor's stock as the EDGES the Sells tab draws, marked as history like every other edge out
-- of this file. A withheld item whose details are not served is left out, as a creature's loot
-- leaves one out.
function E:VendorEdges(key)
  local out = {}
  local nameIndex = self:VendorKind(key)
  if not nameIndex then
    return out
  end
  local side = self:Faction(nameIndex)
  for _, row in ipairs(EraSources.VendorRows(self:Table(), nameIndex, self:_VendorIndex())) do
    if row.edge and self:_Unlocked(row.item) then
      out[#out + 1] = self:_Mark({
        type = row.edge,
        target = row.key,
        group = row.group,
        zone = row.zone,
        areaId = row.areaId,
        note = row.note,
        -- Brief T2b: the vendor's own side on every row of its Sells tab, so a stock the player's
        -- side cannot buy says so the way the item's own Sold by row does.
        faction = side,
      })
    end
  end
  return out
end

--------------------------------------------------------------------------------
-- The quests a creature or a vendor starts and ends (brief N3)
--------------------------------------------------------------------------------

-- qg, keyed by NAME the way ck, cd and mp are: { [nameIndex] = { starts, ends } }, each a packed
-- string of quest ids, QG_QUEST base 91 digits apiece, ascending, "" for none. The pipeline ships
-- an entry only for a name a creature row or a vendor row already names, and only quests it can
-- title: a c = 3 row or qt names every one of them, so E:QuestName always has an answer.
local QG_QUEST = 3

-- The pair of packed strings one name carries, or nil. field is "qg" (a creature or vendor name, the
-- default) or "og" (brief EO1: a world object name), the two tables of one shape.
local function giverPair(source, nameIndex, field)
  if type(source) ~= "table" or type(nameIndex) ~= "number" then
    return nil
  end
  local givers = source[field or "qg"]
  local pair = type(givers) == "table" and givers[nameIndex] or nil
  if type(pair) ~= "table" then
    return nil
  end
  return pair
end

-- How many quest ids one packed list holds, from its length alone. A string that is not a whole
-- number of records is not one of ours and holds none.
local function questListLength(text)
  if type(text) ~= "string" or #text % QG_QUEST ~= 0 then
    return 0
  end
  return #text / QG_QUEST
end

-- One packed list decoded into its quest ids, in the pipeline's own order (ascending). A record
-- this file cannot read is skipped rather than guessed at.
local function decodeQuests(text)
  local out = {}
  if type(text) ~= "string" or text == "" or #text % QG_QUEST ~= 0 then
    return out
  end
  for at = 1, #text, QG_QUEST do
    local questId = packedInt(text, at, QG_QUEST)
    if questId and questId > 0 then
      out[#out + 1] = questId
    end
  end
  return out
end

-- How many quests one name starts and how many it ends, out of the two lists' lengths: nothing
-- is decoded, which is what the Quests tab's count and the page's header line ask. 0, 0 for a
-- name the table lists no quest for.
function EraSources.QuestCounts(source, nameIndex, field)
  local pair = giverPair(source, nameIndex, field)
  if not pair then
    return 0, 0
  end
  return questListLength(pair[1]), questListLength(pair[2])
end

-- The quests one name starts and ends, decoded on demand: { starts = { questId, ... }, ends = {
-- questId, ... } }, each ascending, and both lists empty for a name the table lists none for. A
-- quest the name both starts and ends is in both.
-- Brief QF2b: a swapped quest in either list reads as its pair (EraSources.QuestSwaps), so every
-- reader of a giver's quests (the Quests tab's rows and edges, its side count, the quest page's
-- givers and turn ins through Core/ViewModel.lua's index) reads the corrected pairs. The counts
-- (EraSources.QuestCounts) are the lists' lengths, which a swap never changes.
function EraSources.QuestsGiven(source, nameIndex, field)
  local pair = giverPair(source, nameIndex, field)
  if not pair then
    return { starts = {}, ends = {} }
  end
  local swaps = EraSources.QuestSwaps()
  return {
    starts = swapQuestList(decodeQuests(pair[1]), swaps),
    ends = swapQuestList(decodeQuests(pair[2]), swaps),
  }
end

-- Brief EO1: the same two answers for a world OBJECT name, out of og.
function EraSources.ObjectQuestCounts(source, nameIndex)
  return EraSources.QuestCounts(source, nameIndex, "og")
end

function EraSources.ObjectQuestsGiven(source, nameIndex)
  return EraSources.QuestsGiven(source, nameIndex, "og")
end

-- Brief PL1 (the owner's ruling "B" of 2026-10-22, the Classic Era prerequisite links): the quests that
-- come after a quest, out of qo = { [questId] = packed string }, each later quest id as QG_QUEST base 91
-- digits, ascending, a qg list's shape. A later quest is one whose CMaNGOS quest_template.PrevQuestId is
-- the quest, or the quest's own NextQuestId or NextQuestInChain, each above 0, so a step whose next quest
-- has another title has one (Legends of Maraudon 7044 -> The Scepter of Celebras 7046). Brief NX2 (the
-- owner's word of 2026-10-23): also one whose RequiredCondition asks for the quest rewarded (through AND and
-- OR condition rows, never NOT: Rise of the Silithid 4267 -> March of the Silithid 4493), and the quest's own
-- BreadcrumbForQuestId (Deliveries to Sven 164 -> Sven's Revenge 95); the reader is unchanged. { questId, ... }
-- in the pipeline's order, the quest itself never among them; an empty list for a quest qo does not hold
-- and for a module that ships no qo. A new list every call. Pure.
-- Brief QF2b: a swapped quest reads its pair's entry, and a swapped later quest reads as its pair
-- (EraSources.QuestSwaps): A Lesson to Learn 26 goes on to the Alliance's Trial of the Lake 29.
function EraSources.QuestNextSteps(source, questId)
  local steps = type(source) == "table" and type(source.qo) == "table" and source.qo or nil
  local swaps = steps and EraSources.QuestSwaps() or EMPTY
  local text = steps and type(questId) == "number" and steps[EraSources.SwappedQuest(questId, swaps)] or nil
  local out = {}
  for _, later in ipairs(swapQuestList(decodeQuests(text), swaps)) do
    if later ~= questId then
      out[#out + 1] = later
    end
  end
  return out
end

-- Brief NX1 (the owner's ruling "2A" of 2026-10-22, the Classic Era provided items): the item a quest
-- hands the player when it is taken, out of qp = { [questId] = packed string }, one qr record (the item id
-- in 3 base 91 digits, then the count in 2; CMaNGOS quest_template.SrcItemId and SrcItemCount): Saving
-- Yenniku 592 hands over the Soul Gem 3912. { { itemId, count } }, the qr shape (EraSources.DecodeRequires),
-- an empty list for a quest qp does not hold and for a module that ships no qp. The pipeline ships every
-- such pair, an item that also starts its own quest among them: the readers leave that one out (PV1's
-- rule, the client's QuestStarts: Core/QuestFlags.lua IsStarter), never this file. A new list every call.
-- Pure.
function EraSources.QuestProvided(source, questId)
  local provided = type(source) == "table" and type(source.qp) == "table" and source.qp or nil
  local text = provided and type(questId) == "number" and provided[questId] or nil
  return EraSources.DecodeRequires(text)
end

-- Brief NX1: the reverse of qp, item id to the quests that hand it over, { [itemId] = { questId, ... } },
-- quest id ascending, built in one pass over qp alone the first time an item asks and held WEAKLY against
-- the table it was read from (as the ci and oi maps are), so a table swapped under a loaded Core is
-- answered from the new one. About a thousand quests on the pinned dump, one small table per item.
local providedByMaps = setmetatable({}, { __mode = "k" })

function EraSources.ProvidedByIndex(source)
  if type(source) ~= "table" then
    return EMPTY
  end
  local held = providedByMaps[source]
  if held then
    return held
  end
  local index = {}
  local packed = type(source.qp) == "table" and source.qp or EMPTY
  local ids = {}
  for questId in pairs(packed) do
    if type(questId) == "number" then
      ids[#ids + 1] = questId
    end
  end
  table.sort(ids)
  for _, questId in ipairs(ids) do
    for _, pair in ipairs(EraSources.DecodeRequires(packed[questId])) do
      local bucket = index[pair[1]]
      if not bucket then
        bucket = {}
        index[pair[1]] = bucket
      end
      if bucket[#bucket] ~= questId then
        bucket[#bucket + 1] = questId
      end
    end
  end
  providedByMaps[source] = index
  return index
end

-- Brief NX1: the quests whose qp hands one item over, { questId, ... } ascending, a new list every call
-- (empty for an item none hands over and for a module that ships no qp). Pure over the table.
function EraSources.ProvidedBy(source, itemId)
  local out = {}
  local bucket = type(itemId) == "number" and EraSources.ProvidedByIndex(source)[itemId] or nil
  for _, questId in ipairs(type(bucket) == "table" and bucket or EMPTY) do
    out[#out + 1] = questId
  end
  return out
end

-- Brief NX1: whether an item starts the quest the Classic Era rows say hands it over (the client's own
-- QuestStarts, Core/QuestFlags.lua IsStarter: PV1's rule, the starter the quest keeps and the player
-- already holds), which every reader of qp leaves out. Brief ASF1 (the Opus review of round AS, M1): or the
-- item's own row says it starts the quest (Core/QuestFlags.lua ItemStartsQuest: its sq, the STARTS_QUEST
-- edge's fact, else a withheld item's Classic Era row's), so the item page never reads "Provided by quest"
-- for the quest the item starts (Essence of Eranikus 10454 and 3373). Guarded; false where nothing can say.
function EraSources.ProvidedIsStarter(itemId, questId)
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

-- The two groups of the Quests tab, in the order they are drawn: what the NPC starts, then what it
-- ends. The edge type and the group word each is filed under.
EraSources.QUEST_GIVER_SIDES = {
  { list = "starts", edge = "GIVES_QUEST", group = "Starts" },
  { list = "ends", edge = "TAKES_QUEST", group = "Ends" },
}

-- One name's quests as the rows the Quests tab draws: { questId, key, edge, group }, the starts
-- first and then the ends, each ascending. field as EraSources.QuestsGiven's. Pure.
function EraSources.QuestGiverRows(source, nameIndex, field)
  local given = EraSources.QuestsGiven(source, nameIndex, field)
  local out = {}
  for _, side in ipairs(EraSources.QUEST_GIVER_SIDES) do
    for _, questId in ipairs(given[side.list]) do
      out[#out + 1] = {
        questId = questId,
        key = Graph.Key("quest", questId),
        edge = side.edge,
        group = side.group,
      }
    end
  end
  return out
end

-- The quests the name at one string index starts and ends, decoded (EraSources.QuestsGiven).
function E:QuestsGiven(nameIndex)
  return EraSources.QuestsGiven(self:Table(), nameIndex)
end

-- How many quests the name at one string index starts and ends, with nothing decoded.
function E:QuestCounts(nameIndex)
  return EraSources.QuestCounts(self:Table(), nameIndex)
end

-- Brief EO1: the name one key's quest lists are read under and the table they are in: an npc key's
-- creature or vendor name (E:NpcNameAt) in qg, an object key's object name (E:ObjectAt) in og. nil for
-- any other key. Only an object key of ours asks for the table.
function E:QuestGiverAt(key)
  if Graph.Kind(key) == "object" then
    local nameIndex = self:ObjectAt(key)
    if nameIndex then
      return nameIndex, "og"
    end
    return nil
  end
  local nameIndex = self:NpcNameAt(key)
  if nameIndex then
    return nameIndex, "qg"
  end
  return nil
end

-- How many quests the creature or vendor one npc key names starts and ends: 0, 0 for a key that
-- names neither. The name join is E:NpcNameAt, so a collected NPC's positive key counts too. Brief
-- EO1: an object key's world object the same way, out of og.
function E:QuestGiverCounts(key)
  local nameIndex, field = self:QuestGiverAt(key)
  if not nameIndex then
    return 0, 0
  end
  return EraSources.QuestCounts(self:Table(), nameIndex, field)
end

-- Brief EO1: the quests one npc or object key starts and ends, decoded (EraSources.QuestsGiven's
-- shape), both lists empty for a key that names no giver.
function E:QuestsGivenBy(key)
  local nameIndex, field = self:QuestGiverAt(key)
  if not nameIndex then
    return { starts = {}, ends = {} }
  end
  return EraSources.QuestsGiven(self:Table(), nameIndex, field)
end

-- The Quests tab's EDGES for one npc key (brief EO1: or one object key, its object's og lists): a
-- GIVES_QUEST edge to every quest it starts and a
-- TAKES_QUEST edge to every quest it ends, marked as history like every other edge out of this
-- file, so they wear the Predicted badge and follow "Show predicted data". Each points at a real
-- quest node (quest:<id>), which the graph names from a curated or collected title first and from
-- this file's own namer (qt, then the quest rows) otherwise, exactly as a quest row in an item's
-- Sources view is named.
function E:QuestGiverEdges(key)
  local out = {}
  local nameIndex, field = self:QuestGiverAt(key)
  if not nameIndex then
    return out
  end
  for _, row in ipairs(EraSources.QuestGiverRows(self:Table(), nameIndex, field)) do
    local edgeType = T[row.edge]
    if edgeType then
      out[#out + 1] = self:_Mark({
        type = edgeType,
        target = row.key,
        group = row.group,
      })
    end
  end
  return out
end

--------------------------------------------------------------------------------
-- The recipes a trainer teaches (brief P6b)
--------------------------------------------------------------------------------

-- tr, keyed by NAME the way ck, qg and st are: { [nameIndex] = packed spell ids }, each spell id as
-- TR_SPELL base 91 digits, ascending, repeats dropped (../ItemTree-Data/docs/era-sources.md, "tr").
-- Only profession and secondary skill spells ship: the class trainers were cut. A spell's trainers
-- are the names whose list holds it, which is the one index below.
local TR_SPELL = 3
-- Brief TR5: tv, beside each spell of the same name's tr list and in its order, the skill rank the
-- trainer asks before teaching it, TV_LEVEL base 91 digits each. Absent in data compiled before TR5.
local TV_LEVEL = 2

-- The packed list one name carries, or nil.
local function trainerText(source, nameIndex)
  if type(source) ~= "table" or type(nameIndex) ~= "number" then
    return nil
  end
  local lists = source.tr
  local text = type(lists) == "table" and lists[nameIndex] or nil
  if type(text) ~= "string" or text == "" or #text % TR_SPELL ~= 0 then
    return nil
  end
  return text
end

-- How many spells the name at one string index teaches, out of its list's length alone: nothing
-- is decoded, which is what a page's tab strip and its one line ask. 0 for a name that teaches
-- nothing. Pure.
function EraSources.TeachCount(source, nameIndex)
  local text = trainerText(source, nameIndex)
  if not text then
    return 0
  end
  return #text / TR_SPELL
end

-- The spell ids the name at one string index teaches, ascending, decoded on demand. Empty for a
-- name that teaches nothing. A record this file cannot read is skipped rather than guessed at.
-- Brief TR5: and second, { [spellId] = learn level } out of tv where the table carries one whose
-- length matches the list, else nil (data compiled before TR5). Pure.
function EraSources.Teaches(source, nameIndex)
  local out = {}
  local text = trainerText(source, nameIndex)
  if not text then
    return out
  end
  local levelLists = source.tv
  local levelText = type(levelLists) == "table" and levelLists[nameIndex] or nil
  if type(levelText) ~= "string" or #levelText ~= (#text / TR_SPELL) * TV_LEVEL then
    levelText = nil
  end
  local levels = levelText and {} or nil
  local record = 0
  for at = 1, #text, TR_SPELL do
    local spellId = packedInt(text, at, TR_SPELL)
    if spellId and spellId > 0 then
      out[#out + 1] = spellId
      if levels then
        levels[spellId] = packedInt(levelText, record * TV_LEVEL + 1, TV_LEVEL)
      end
    end
    record = record + 1
  end
  return out, levels
end

-- Spell to trainers, built in ONE pass over tr: { [spellId] = { nameIndex, ... } }, each list in
-- name order (the string itself, then the index), and names how many trainer names carried a list
-- at all. 287 names and 4,514 pairs on 1.60.1.70009, so the pass is small; it is built on the
-- first spell whose Sources are drawn and then kept (E:_TrainerIndex). Pure. Brief PF3: check, where
-- given, is called once per trainer name and once per spell list sorted (Core/Data.lua
-- Data.SliceCheck, which lets the login slicer carry the pass over frames); the index is the same.
function EraSources.TrainerIndex(source, check)
  local index = { spells = {}, names = 0, pairs = 0 }
  local lists = type(source) == "table" and source.tr or nil
  if type(lists) ~= "table" then
    return index
  end
  local spells = index.spells
  for nameIndex in pairs(lists) do
    if check then
      check()
    end
    if type(nameIndex) == "number" and stringAt(source, nameIndex) then
      local taught = EraSources.Teaches(source, nameIndex)
      if #taught > 0 then
        index.names = index.names + 1
      end
      for _, spellId in ipairs(taught) do
        local held = spells[spellId]
        if not held then
          held = {}
          spells[spellId] = held
        end
        held[#held + 1] = nameIndex
        index.pairs = index.pairs + 1
      end
    end
  end
  -- pairs walked tr, so each list is put in a fixed order: a page that reordered its trainers
  -- between two loads of one build would read differently every time it was opened.
  for _, held in pairs(spells) do
    if check then
      check()
    end
    table.sort(held, function(a, b)
      local left, right = stringAt(source, a), stringAt(source, b)
      if left ~= right then
        return left < right
      end
      return a < b
    end)
  end
  return index
end

-- The name indices of the trainers that teach one spell, in name order, or an empty list. index is
-- an EraSources.TrainerIndex, built here for a caller that holds none. Pure.
function EraSources.TrainersOf(source, spellId, index)
  if type(source) ~= "table" or type(spellId) ~= "number" then
    return EMPTY
  end
  if type(index) ~= "table" or type(index.spells) ~= "table" then
    index = EraSources.TrainerIndex(source)
  end
  return index.spells[spellId] or EMPTY
end

-- The areas a creature NAME's pins stand in, read off mp without decoding a coordinate: { { areaId,
-- name, pins } }, the area with the most pins first (the zone a Map tab opens on), then by area id.
-- Empty for a name with no pins, which is a trainer who lives inside an instance. It reads only the
-- area digits of each record, so it costs nothing a pin decode costs and the Map tab's pin cache
-- and its count are left alone: a tree drawing a recipe's trainers decodes no pin. field reads
-- another table of mp's packing ("op", EraSources.ObjectPinAreas); mp where it is nil. Pure.
function EraSources.PinAreas(source, nameIndex, field)
  local out = {}
  local text = pinText(source, field or "mp", nameIndex)
  if not text or #text % PIN_WIDTH ~= 0 then
    return out
  end
  local counts, order = {}, {}
  for at = 1, #text, PIN_WIDTH do
    local areaId = packedInt(text, at, PIN_AREA)
    if areaId and areaId > 0 then
      if not counts[areaId] then
        counts[areaId] = 0
        order[#order + 1] = areaId
      end
      counts[areaId] = counts[areaId] + 1
    end
  end
  table.sort(order, function(a, b)
    if counts[a] ~= counts[b] then
      return counts[a] > counts[b]
    end
    return a < b
  end)
  for _, areaId in ipairs(order) do
    out[#out + 1] = { areaId = areaId, name = areaName(source, areaId), pins = counts[areaId] }
  end
  return out
end

-- Brief EO1: the same for an OBJECT name, read off op: where a quest giving object (a wanted
-- poster) stands, for its giver row's zone. Pure.
function EraSources.ObjectPinAreas(source, nameIndex)
  return EraSources.PinAreas(source, nameIndex, "op")
end

-- The trainer index, built once per table and kept, or nil on a build that ships no table. Held
-- against the table it was built from, the way E:_VendorIndex is.
function E:_TrainerIndex()
  local source = self:Table()
  if not source then
    return nil
  end
  if self.trainerFor ~= source then
    local index = EraSources.TrainerIndex(source, type(Data) == "table" and Data.SliceCheck or nil)
    -- Brief PF3: a caller that built the index whole while the slicer's pass was paused keeps its own.
    if self.trainerFor == source then
      return self.trainerIndex
    end
    self.trainerIndex = index
    self.trainerFor = source
    self.trainerBuilds = (self.trainerBuilds or 0) + 1
    self.trainerAreas = {}
  end
  return self.trainerIndex
end

-- The name indices of the trainers that teach one spell, in name order: Gimble Thistlefuzz and
-- Lavinia Crowe for 7779 Enchant Bracer - Minor Agility. An empty list for a spell no trainer
-- teaches, which is every spell Forever added (Dormant Heart of the Mountain's 1249114 included):
-- the table is Classic Era's.
function E:TrainersOf(spellId)
  local source = self:Table()
  if not source then
    return EMPTY
  end
  return EraSources.TrainersOf(source, spellId, self:_TrainerIndex())
end

-- The spell ids the name at one string index teaches, ascending, or an empty list, and (brief
-- TR5) { [spellId] = learn level } where the table carries tv, else nil.
function E:Teaches(nameIndex)
  return EraSources.Teaches(self:Table(), nameIndex)
end

-- How many spells the NPC one npc key names teaches, with nothing decoded: 0 for a key that
-- names no trainer. The name join is E:NpcNameAt, so a collected NPC's positive key counts too.
function E:TeachCount(key)
  local nameIndex = self:NpcNameAt(key)
  if not nameIndex then
    return 0
  end
  return EraSources.TeachCount(self:Table(), nameIndex)
end

-- The areas one trainer's pins stand in (EraSources.PinAreas), kept per name with the index, so a
-- tree that draws the same trainer under ten recipes reads its pin string once.
function E:TrainerAreas(nameIndex)
  if not self:_TrainerIndex() then
    return EMPTY
  end
  local held = self.trainerAreas[nameIndex]
  if not held then
    held = EraSources.PinAreas(self:Table(), nameIndex)
    self.trainerAreas[nameIndex] = held
  end
  return held
end

-- Whether the creature one npc key names has anything in its Loot tab, out of the loot index an
-- npc page builds anyway (its info column's facts read the same index). Asked only for a trainer,
-- whose Loot tab would otherwise lead with nothing in it.
function E:HasLoot(key)
  local nameIndex = self:CreatureAt(key)
  if not nameIndex then
    return false
  end
  local index = self:_LootIndex()
  local byCategory = type(index) == "table" and index.loot and index.loot[nameIndex] or nil
  return type(byCategory) == "table" and next(byCategory) ~= nil
end

-- One spell's trainers as the rows of its Sources view's Trainer category (brief P6b): a
-- LEARNED_FROM_TRAINER edge to each trainer's own creature page (EraSources.PageKey), beside the
-- generic profession row Core/Graph.lua draws for a recipe nothing teaches. The type is the
-- generic row's own, which is what Core/Sources.lua words as "Trainer" and gives a zone column,
-- so the row reads "Gimble Thistlefuzz <Expert Enchanter>", Trainer, Ironforge.
--
-- Each carries the trainer's title and side (st and cf), the zone its pins mostly stand in and
-- that zone's id (so the column opens the zone, and the row's hover says where in it through
-- E:Places, brief E90), and its kind and portrait for the row's icon. Marked as history like every
-- other edge out of this file: the table is Classic Era's, and WoW Forever may differ.
function E:TrainerEdges(spellId)
  local out = {}
  local source = self:Table()
  if not source then
    return out
  end
  for _, nameIndex in ipairs(self:TrainersOf(spellId)) do
    -- Brief EK1: the trainer's own page, keyed by its creature id. A name with none has no page:
    -- its row is still drawn and opens nothing.
    local key, paged = EraSources.CreatureNode(source, nameIndex)
    if key then
      local zone = self:TrainerAreas(nameIndex)[1]
      local edge = self:_Mark({
        type = T.LEARNED_FROM_TRAINER,
        target = key,
        group = L["Trainer"],
        zone = zone and zone.name or nil,
        areaId = zone and zone.name and zone.areaId or nil,
        title = self:Title(nameIndex),
        faction = self:Faction(nameIndex),
      })
      if not paged then
        Graph.SetName(key, stringAt(source, nameIndex))
        edge.noPage = true
      end
      local creatureType, family, low, high = self:KindOf(nameIndex)
      if creatureType then
        edge.creature = {
          type = creatureType,
          family = family,
          low = low,
          high = high,
          display = self:DisplayOf(nameIndex),
        }
      end
      out[#out + 1] = edge
    end
  end
  return out
end

-- The Teaches tab's EDGES for one npc key (brief P6b): a TRAINER_TEACHES edge to every recipe
-- spell the name teaches, each filed under its profession (the build's own skill line name, as a
-- recipe's own category is), and marked as history like every other edge out of this file. A
-- row opens the recipe's page. A spell this build states no recipe for is filed under "Teaches".
function E:TeachesEdges(key)
  local out = {}
  -- Brief FX-AF: the name asked once PlayerSources' module is built (E:TrainerNameAt).
  local nameIndex = self:TrainerNameAt(key)
  -- Brief TW1: a class trainer's list as its own window showed it in Forever, where one ships for
  -- this trainer (E:ForeverClassEdges), in place of the Classic Era list below.
  local forever = self:ForeverClassEdges(key, nameIndex)
  if not nameIndex then
    return forever or out
  end
  local data = self.data
  local spells, levels = self:Teaches(nameIndex)
  -- Brief CT1b: a class trainer that teaches no recipe answers its class list's shared edges as they
  -- are (E:ClassTeachesEdges), which the view model keeps its Teaches tab against.
  if #spells == 0 then
    local class = forever or self:ClassTeachesEdges(nameIndex)
    if #class > 0 then
      return class
    end
    return out
  end
  for _, spellId in ipairs(spells) do
    local recipe = nil
    if type(data) == "table" and type(data.GetRecipe) == "function" then
      local ok, answer = pcall(data.GetRecipe, data, spellId)
      recipe = ok and type(answer) == "table" and answer or nil
    end
    local skillLine = recipe and recipe.sl or nil
    local group = nil
    if skillLine and type(data.GetSkillName) == "function" then
      local ok, name = pcall(data.GetSkillName, data, skillLine)
      group = ok and type(name) == "string" and name ~= "" and name or nil
    end
    -- Brief TR5: the rank the trainer asks, which orders the tab and reads as "Mining 65".
    local learnLevel = levels and levels[spellId] or nil
    local meta = nil
    if learnLevel and learnLevel > 0 and skillLine and type(Graph.SkillLabel) == "function" then
      local ok, label = pcall(Graph.SkillLabel, skillLine, learnLevel)
      meta = ok and type(label) == "string" and label or nil
    end
    out[#out + 1] = self:_Mark({
      type = T.TRAINER_TEACHES,
      target = Graph.Key("spell", spellId),
      group = group or L["Teaches"],
      skillLine = skillLine,
      learnLevel = learnLevel,
      meta = meta,
    })
  end
  -- Brief CT1: and a class trainer's class spells (tc), filed by the level each is learnt at.
  -- Brief TW1: Forever's own list where one ships for this trainer.
  for _, edge in ipairs(forever or self:ClassTeachesEdges(nameIndex)) do
    out[#out + 1] = edge
  end
  return out
end

--------------------------------------------------------------------------------
-- The class spells a class trainer teaches (brief CT1)
--------------------------------------------------------------------------------

-- Brief CT1 (the owner, 2026-10-17, QA items 207 and 215: "Let's queue to add the teaches spells for
-- the next release"). tc, EraSources' (../ItemTree-Data/docs/era-sources.md, "tc"): { l = { packed
-- list, ... }, c = { class id, ... }, n = { [nameIndex] = list number } }, each distinct list once.
-- A list is a run of TC_RECORD byte records: the spell (TC_SPELL digits), the level the trainer asks
-- (TC_LEVEL) and the price in copper (TC_COST), in level order. tf, EraPlaces' (ours): this build's
-- own learn level and rank for each of those spells the build names, TF_RECORD byte records in spell
-- id order. A spell tf has no record for is one the build no longer has (Multi-Shot's ranks 2 to 4 on
-- 1.60.1.70425), and is left out; data compiled before CT1 ships neither, and the tab reads as before.
local TC_SPELL, TC_LEVEL, TC_COST = 3, 1, 3
local TC_RECORD = TC_SPELL + TC_LEVEL + TC_COST
local TF_SPELL, TF_LEVEL, TF_RANK = 3, 1, 1
local TF_RECORD = TF_SPELL + TF_LEVEL + TF_RANK

-- The packed list one name points at and the class it is for, or nil.
local function classListOf(source, nameIndex)
  local lists = type(source) == "table" and source.tc or nil
  if type(lists) ~= "table" or type(nameIndex) ~= "number" or type(lists.n) ~= "table" then
    return nil
  end
  local number = lists.n[nameIndex]
  local text = type(number) == "number" and type(lists.l) == "table" and lists.l[number] or nil
  if type(text) ~= "string" or text == "" or #text % TC_RECORD ~= 0 then
    return nil
  end
  return text, type(lists.c) == "table" and tonumber(lists.c[number]) or nil
end

-- How many class spells the name at one string index teaches, out of its list's length alone, the
-- spells this build no longer has included; 0 for a name with no list. Pure.
function EraSources.ClassTeachCount(source, nameIndex)
  local text = classListOf(source, nameIndex)
  if not text then
    return 0
  end
  return #text / TC_RECORD
end

-- tf decoded, { [spellId] = { level = n, rank = n } } (0 where the build states none), or nil where
-- the table carries none (data compiled before CT1, or a pair the join left apart). Pure.
function EraSources.ClassSpellFacts(source)
  local text = type(source) == "table" and source.tf or nil
  if type(text) ~= "string" or text == "" or #text % TF_RECORD ~= 0 then
    return nil
  end
  local out = {}
  for at = 1, #text, TF_RECORD do
    local spellId = packedInt(text, at, TF_SPELL)
    if spellId and spellId > 0 then
      out[spellId] = {
        level = packedInt(text, at + TF_SPELL, TF_LEVEL) or 0,
        rank = packedInt(text, at + TF_SPELL + TF_LEVEL, TF_RANK) or 0,
      }
    end
  end
  return out
end

-- What the name at one string index teaches as a class trainer: { classId, spells = { { spell,
-- level, eraLevel, cost, rank }, ... } } in level order (then spell id), or nil for a name with no
-- list. level is this build's own where facts (EraSources.ClassSpellFacts' answer) states one, else
-- the level the trainer asks (eraLevel); rank is this build's, 0 for none. With facts given, a spell
-- it has no record for is left out: the build no longer has it. Pure.
function EraSources.ClassTeaches(source, nameIndex, facts)
  local text, classId = classListOf(source, nameIndex)
  if not text then
    return nil
  end
  local spells = {}
  for at = 1, #text, TC_RECORD do
    local spellId = packedInt(text, at, TC_SPELL)
    local fact = type(facts) == "table" and spellId and facts[spellId] or nil
    if spellId and spellId > 0 and (facts == nil or fact ~= nil) then
      local eraLevel = packedInt(text, at + TC_SPELL, TC_LEVEL) or 0
      local level = eraLevel
      if fact and (tonumber(fact.level) or 0) > 0 then
        level = fact.level
      end
      spells[#spells + 1] = {
        spell = spellId,
        level = level,
        eraLevel = eraLevel,
        cost = packedInt(text, at + TC_SPELL + TC_LEVEL, TC_COST) or 0,
        rank = fact and tonumber(fact.rank) or 0,
      }
    end
  end
  table.sort(spells, function(a, b)
    if a.level ~= b.level then
      return a.level < b.level
    end
    return a.spell < b.spell
  end)
  return { classId = classId, spells = spells }
end

-- The second column of a class spell's row: "1s 80c (Rank 3)", the money first and the rank in
-- brackets (the owner, 2026-10-18: "make those 60s (Rank X) so money is always first for
-- unlearnt"; it read "Rank 3, 1s 80c"), either half alone where the other is not known ("Rank 3",
-- "1s 80c"), nil for neither. The price is Core/Sources.lua's money words. Pure.
function EraSources.ClassSpellMeta(rank, cost)
  local rankText = nil
  if (tonumber(rank) or 0) > 0 then
    rankText = string.format(L["Rank %d"], rank)
  end
  local Sources = ItemTree.Sources
  local money = (tonumber(cost) or 0) > 0
      and type(Sources) == "table"
      and type(Sources.MoneyText) == "function"
      and Sources.MoneyText(cost)
    or nil
  if type(money) ~= "string" or money == "" then
    return rankText
  end
  if rankText then
    return string.format(L["%s (%s)"], money, rankText)
  end
  return money
end

-- How many class spells the NPC one npc key names teaches, out of its list's length alone (the spells
-- this build no longer has included): 0 for a key that names no class trainer with a list. The name
-- join is E:NpcNameAt, as E:TeachCount's.
function E:ClassTeachCount(key)
  -- Brief FX-AF: the name asked once PlayerSources' module is built (E:TrainerNameAt).
  local nameIndex = self:TrainerNameAt(key)
  -- Brief TW1: a trainer whose Forever list ships counts that list's spells.
  local forever = self:ForeverClassList(key, nameIndex)
  if forever then
    return #forever.spells
  end
  if not nameIndex then
    return 0
  end
  return EraSources.ClassTeachCount(self:Table(), nameIndex)
end

-- tf decoded once per table and kept, or nil where the table carries none.
function E:ClassSpellFacts()
  local source = self:Table()
  if not source then
    return nil
  end
  if self.classFactsFor ~= source then
    self.classFacts = EraSources.ClassSpellFacts(source)
    self.classFactsFor = source
  end
  return self.classFacts
end

-- Brief CT1b (QA item 227): the creature id to name map (ci read the other way, reverseMap above),
-- which the first NPC page of a session built (about 1 ms offline over 1.60.1.70450, the owner's PC
-- near three times that). Core/Data.lua builds it behind the loading screen now, with tf decoded
-- (E:ClassSpellFacts). Answers the map, or nil where this build ships no table.
function E:PageNameMap()
  local source = self:Table()
  if type(source) ~= "table" then
    return nil
  end
  return reverseMap(pageNameMaps, source, "ci")
end

-- What the name at one string index teaches as a class trainer (EraSources.ClassTeaches), or nil.
function E:ClassTeaches(nameIndex)
  return EraSources.ClassTeaches(self:Table(), nameIndex, self:ClassSpellFacts())
end

-- Brief CT1b (QA item 227, the hunter trainer pages cost 5 to 8 ms an open with nothing kept between
-- opens): every trainer of one class list teaches the same spells, so E:ClassTeachesEdges keeps the
-- edges it builds, per list. Each list it keeps is in here (held weakly), so a reader can tell a
-- shared class list from any other edge list (EraSources.IsClassTeachesList).
local classEdgeLists = setmetatable({}, { __mode = "k" })

-- Whether an edge list is one class list's shared edges (E:ClassTeachesEdges), which every trainer
-- of that list is handed and nothing may write into. Pure.
function EraSources.IsClassTeachesList(edges)
  return type(edges) == "table" and classEdgeLists[edges] == true
end

-- The Teaches tab's class spell EDGES for one name: a TRAINER_TEACHES edge to every class spell the
-- name teaches that this build still has, each filed under the level it is learnt at ("Level 20"),
-- with its rank and price in the second column and its class, level and price on the edge
-- (classSpell) for Core/ViewModel.lua's order and UI/Tree.lua's row; marked as history like every
-- other edge out of this file. A level below 1 (two rows of the pinned dump state none) reads as 1.
-- Brief CT1b: built once per class list and kept until the table, its tc or this build's facts (tf)
-- change, or E:Invalidate. The list is SHARED by every trainer of that list: read it, never write it.
function E:ClassTeachesEdges(nameIndex)
  local source = self:Table()
  local lists = type(source) == "table" and source.tc or nil
  local number = nil
  if type(nameIndex) == "number" and type(lists) == "table" and type(lists.n) == "table" then
    number = lists.n[nameIndex]
  end
  if number == nil then
    return {}
  end
  local facts = self:ClassSpellFacts()
  local held = self.classEdges
  if not held or held.source ~= source or held.lists ~= lists or held.facts ~= facts then
    held = { source = source, lists = lists, facts = facts, byList = {} }
    self.classEdges = held
  end
  local edges = held.byList[number]
  if not edges then
    edges = self:_ClassTeachesEdges(nameIndex)
    if #edges > 0 then
      classEdgeLists[edges] = true
    end
    held.byList[number] = edges
  end
  return edges
end

-- E:ClassTeachesEdges' list for one name, built afresh.
function E:_ClassTeachesEdges(nameIndex)
  local out = {}
  local taught = type(nameIndex) == "number" and self:ClassTeaches(nameIndex) or nil
  if not taught then
    return out
  end
  for _, spell in ipairs(taught.spells) do
    local level = math.max(1, spell.level)
    out[#out + 1] = self:_Mark({
      type = T.TRAINER_TEACHES,
      target = Graph.Key("spell", spell.spell),
      group = string.format(L["Level %d"], level),
      learnLevel = level,
      meta = EraSources.ClassSpellMeta(spell.rank, spell.cost),
      classSpell = {
        classId = taught.classId,
        level = level,
        eraLevel = spell.eraLevel,
        cost = spell.cost,
        rank = spell.rank,
      },
    })
  end
  return out
end

--------------------------------------------------------------------------------
-- Brief TW1: a class trainer's list as Forever's own windows showed it
--------------------------------------------------------------------------------

-- The owner (2026-10-18, QA item 242): "What the best way to update our NPC to have forever skills?"
-- His own visits record what each trainer's window lists (the Collector's trainer lists,
-- UI/CollectorHooks.lua), and the pipeline ships them as PlayerSources' tl (ours, all rights
-- reserved: Core/PlayerSources.lua PlayerSources.ClassList), ONE LIST PER CLASS: his ruling "A" of
-- 2026-10-18, a list recorded at one trainer shows on every trainer of that class, both factions.
-- So a class trainer's Teaches tab reads its CLASS's list, in place of the Classic Era list (tc).
-- Each spell it holds is a row of the player tier (Confidence.MINED, provenance "player": no
-- Predicted badge, the tooltip's "Reported by players"), at the level, rank and price Forever's
-- window showed; where the list holds no price (none read, or one read at a reputation discount,
-- which ships as none) or no rank, the Classic Era list's for the same spell is shown. His ruling
-- "B" of 2026-10-18: a spell no Classic Era list of the class holds wears the New in Forever mark
-- (edge.newInForever, Core/ViewModel.lua VM:_Badges). A list no read with every filter on made
-- whole keeps the Classic Era rows of the trainer's own list it does not hold, marked as history as
-- they were; a complete one stands alone (a spell it does not hold is one no trainer of the class
-- teaches any more).
--
-- Which pages: a class trainer's, its class out of its own Classic Era list (tc), else the class its
-- recorded reads were for (tl's n), else its title's ("Hunter Trainer", TrainerSearch). A trainer
-- whose own Classic Era list is a short one (fewer than EraSources.CLASS_LIST_SHORT spells: the
-- starting area trainers' first ranks, 4 to 6 spells, and the Portal Trainers' 2 portals; a city
-- trainer's list holds 39 to 180) keeps its page as it was: the Classic Era tables give those
-- trainers lists of their own, not the class's. A profession trainer's page (one whose name
-- teaches recipes and no class list) is as it was, and none of theirs ships yet.
EraSources.CLASS_LIST_SHORT = 7

--- The creature id an npc page key stands for: a positive key's own id, a Classic Era page key's
--- (negative) id read back; nil for any other key. Pure.
function EraSources.PageCreatureId(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "npc" or type(id) ~= "number" or id ~= math.floor(id) then
    return nil
  end
  if id > 0 then
    return id
  end
  if isPageId(id) then
    return -id
  end
  return nil
end

-- Every spell any Classic Era list of one class holds, { [spellId] = true }, per table and class,
-- held weakly by the table; nil where the table carries no class lists.
local classEraSpells = setmetatable({}, { __mode = "k" })

--- Brief TW1 (ruling "B"): every spell the Classic Era class lists (tc) of one class hold, as a set,
--- or nil where the table carries none. A Forever list's spell outside it is New in Forever. Pure
--- over the table, kept per table and class.
function EraSources.ClassEraSpells(source, classId)
  local lists = type(source) == "table" and source.tc or nil
  if type(lists) ~= "table" or type(lists.l) ~= "table" or type(lists.c) ~= "table" then
    return nil
  end
  local held = classEraSpells[source]
  if not held then
    held = {}
    classEraSpells[source] = held
  end
  if held[classId] then
    return held[classId]
  end
  local set = {}
  for number, text in ipairs(lists.l) do
    if tonumber(lists.c[number]) == classId and type(text) == "string" and #text % TC_RECORD == 0 then
      for at = 1, #text, TC_RECORD do
        local spellId = packedInt(text, at, TC_SPELL)
        if spellId and spellId > 0 then
          set[spellId] = true
        end
      end
    end
  end
  held[classId] = set
  return set
end

-- PlayerSources' reader and its module (built on this ask, a view's), or nil.
local function foreverLists()
  local reader = ItemTree.PlayerSources
  if type(reader) ~= "table" or type(reader.Table) ~= "function" or type(reader.ClassList) ~= "function" then
    return nil, nil
  end
  local ok, source = pcall(reader.Table)
  if not ok or type(source) ~= "table" or type(source.tl) ~= "table" then
    return nil, nil
  end
  return reader, source
end

--- Brief FX-AF (the round AF review's finding 3, 2026-10-19): E:NpcNameAt's answer for an npc key,
--- asked once PlayerSources' module is built (foreverLists builds it). That module's namer names a
--- positive key nothing else of ours may name (Llane Beshere, npc:911) and reads a module already
--- built only, so a page asked before the module was built joined no name, and the class list's
--- fallback (the class his recorded reads were for) handed the Northshire trainer the whole warrior
--- list (101) in place of his own short Classic Era list (5) until something else built it. The
--- class trainer pages (E:TeachesEdges, E:ClassTeachCount) ask here, so the answer never turns on
--- what was asked first. Building the module costs nothing new: those pages build it anyway.
function E:TrainerNameAt(key)
  foreverLists()
  return self:NpcNameAt(key)
end

-- Brief FX-AF: the length of the Classic Era class list of the creature an npc key's id names
-- (its own name in ci, EraSources.CreatureNameIndex), 0 where it has none: a starting area
-- trainer's short list stands even where no name joined the key.
local function ownListLength(source, key)
  local creatureId = EraSources.PageCreatureId(key)
  local text = creatureId and classListOf(source, EraSources.CreatureNameIndex(source, creatureId)) or nil
  if not text then
    return 0
  end
  return #text / TC_RECORD
end

-- The class id a TrainerSearch kind id names ("hunter" is 3), through Graph.ClassInfo, or nil.
local function kindClassId(kindId)
  if type(Graph.ClassInfo) ~= "function" or type(kindId) ~= "string" then
    return nil
  end
  for classId = 1, 13 do
    local info = Graph.ClassInfo(classId)
    if type(info) == "table" and type(info.token) == "string" and info.token:lower() == kindId then
      return classId
    end
  end
  return nil
end

--- The class an npc key's page is a class trainer's page for and the length of its own Classic Era
--- class list (0 where it has none), or nil for a page that is no class trainer's: the class of its
--- own Classic Era list (nameIndex, E:NpcNameAt's), else the class its recorded reads were for
--- (PlayerSources.RecordedClass), else its title's (ViewModel.ClassTrainerTitle, TrainerSearch). A
--- name that teaches recipes and no class list (a profession trainer's) answers nil. Brief FX-AF: a
--- fallback answers the length of the key's own creature's Classic Era list (ownListLength), so a
--- starting area trainer no name joined still keeps his own short list.
function E:ClassTrainerClass(key, nameIndex, reader, source)
  if type(nameIndex) == "number" then
    local text, classId = classListOf(self:Table(), nameIndex)
    if text and classId then
      return classId, #text / TC_RECORD
    end
    -- A name that teaches recipes and no class list is a profession trainer's page.
    local spells = self:Teaches(nameIndex)
    if type(spells) == "table" and #spells > 0 then
      return nil
    end
  end
  local creatureId = EraSources.PageCreatureId(key)
  if creatureId and type(reader) == "table" and type(reader.RecordedClass) == "function" then
    local recorded = reader.RecordedClass(source, creatureId)
    if recorded then
      return recorded, ownListLength(self:Table(), key)
    end
  end
  local vm, search = ItemTree.ViewModel, ItemTree.TrainerSearch
  if type(vm) ~= "table" or type(vm.ClassTrainerTitle) ~= "function" then
    return nil
  end
  if type(search) ~= "table" or type(search.TitleKinds) ~= "function" then
    return nil
  end
  local ok, title = pcall(vm.ClassTrainerTitle, key)
  if not ok or type(title) ~= "string" then
    return nil
  end
  local read, kinds = pcall(search.TitleKinds, title, true)
  for kindId in pairs(read and type(kinds) == "table" and kinds or EMPTY) do
    local classId = kindClassId(kindId)
    if classId then
      return classId, ownListLength(self:Table(), key)
    end
  end
  return nil
end

--- Brief TW3 (the owner's ruling "A" of 2026-10-18, carried over to pet trainers): whether an npc
--- key's page is a pet trainer's: a pet trainer whose reads made the pet list (PlayerSources
--- RecordedPetTrainer), or one whose title says so (ViewModel.PetTrainerTitle, "Pet Trainer"). A name
--- with a Classic Era class list or recipes is a class or a profession trainer's page.
function E:IsPetTrainerPage(key, nameIndex, reader, source)
  local creatureId = EraSources.PageCreatureId(key)
  if creatureId and type(reader) == "table" and type(reader.RecordedPetTrainer) == "function" then
    if reader.RecordedPetTrainer(source, creatureId) then
      return true
    end
  end
  if type(nameIndex) == "number" then
    if classListOf(self:Table(), nameIndex) ~= nil then
      return false
    end
    local spells = self:Teaches(nameIndex)
    if type(spells) == "table" and #spells > 0 then
      return false
    end
  end
  local vm = ItemTree.ViewModel
  if type(vm) ~= "table" or type(vm.PetTrainerTitle) ~= "function" then
    return false
  end
  local ok, title = pcall(vm.PetTrainerTitle, key)
  return ok and type(title) == "string"
end

--- The Forever list one npc key's class trainer page reads (PlayerSources.ClassList, its class's)
--- and the module it is out of, or nil: no list ships for its class, the page is no class
--- trainer's, or its own Classic Era list is a short one. nameIndex is the key's Classic Era name
--- (E:NpcNameAt), or nil. Brief TW3: a pet trainer's page reads the pet trainers' one list
--- (PlayerSources.PetList) the same way. Brief FX-AF: a nameless call asks the name itself once the
--- module is built (E:TrainerNameAt's reason) before any fallback, and the name it read is the third
--- answer.
function E:ForeverClassList(key, nameIndex)
  local reader, source = foreverLists()
  if not reader then
    return nil
  end
  if type(nameIndex) ~= "number" then
    nameIndex = self:NpcNameAt(key)
  end
  if type(reader.PetList) == "function" and self:IsPetTrainerPage(key, nameIndex, reader, source) then
    local pets = reader.PetList(source)
    if type(pets) ~= "table" or #pets.spells == 0 then
      return nil
    end
    return pets, source, nameIndex
  end
  local classId, eraCount = self:ClassTrainerClass(key, nameIndex, reader, source)
  if not classId or (eraCount > 0 and eraCount < EraSources.CLASS_LIST_SHORT) then
    return nil
  end
  local list = reader.ClassList(source, classId)
  if type(list) ~= "table" or #list.spells == 0 then
    return nil
  end
  return list, source, nameIndex
end

--- The Teaches tab's class spell EDGES for one npc key out of its class's Forever list (the comment
--- above), or nil where none is read for it. Built once per class and Classic Era list and kept as
--- E:ClassTeachesEdges keeps its own (the view model's class tab cache reads them the same way):
--- SHARED by every trainer of the class with that Classic Era list, read it, never write it.
function E:ForeverClassEdges(key, nameIndex)
  local list, module, named = self:ForeverClassList(key, nameIndex)
  if not list then
    return nil
  end
  -- Brief FX-AF: the name the list was read for, asked there where none was given.
  nameIndex = named
  local source = self:Table()
  local lists = type(source) == "table" and source.tc or nil
  local eraNumber = nil
  if type(nameIndex) == "number" and type(lists) == "table" and type(lists.n) == "table" then
    eraNumber = lists.n[nameIndex]
  end
  local facts = self:ClassSpellFacts()
  local held = self.classEdges
  if not held or held.source ~= source or held.lists ~= lists or held.facts ~= facts then
    held = { source = source, lists = lists, facts = facts, byList = {} }
    self.classEdges = held
  end
  if held.forever ~= module or type(held.byForever) ~= "table" then
    held.forever, held.byForever = module, {}
  end
  local cacheKey = (list.pet and "pet" or tostring(list.classId)) .. ":" .. tostring(eraNumber or 0)
  local edges = held.byForever[cacheKey]
  if not edges then
    edges = self:_ForeverClassEdges(list, nameIndex)
    if #edges > 0 then
      classEdgeLists[edges] = true
    end
    held.byForever[cacheKey] = edges
  end
  return edges
end

-- E:ForeverClassEdges' list, built afresh: a row per spell the Forever list holds, then, for a list
-- that is not complete, the Classic Era rows of the name's own list it does not hold.
function E:_ForeverClassEdges(list, nameIndex)
  local out = {}
  local taught = type(nameIndex) == "number" and self:ClassTeaches(nameIndex) or nil
  local era = {}
  for _, spell in ipairs(taught and taught.spells or EMPTY) do
    era[spell.spell] = spell
  end
  local classId = list.classId
  -- Brief TW3: the Classic Era tables we ship hold no pet trainer's list, so a pet ability is never
  -- marked New in Forever, and a partial pet list has no Classic Era rows to keep.
  local known = not list.pet and EraSources.ClassEraSpells(self:Table(), classId) or nil
  local reader = ItemTree.PlayerSources
  local provenance = type(reader) == "table" and reader.PROVENANCE or "player"
  local held = {}
  for _, spell in ipairs(list.spells) do
    held[spell.spell] = true
    local old = era[spell.spell]
    local level = spell.level
    if level < 1 and old then
      level = old.level
    end
    level = math.max(1, level)
    local rank = spell.rank > 0 and spell.rank or (old and old.rank or 0)
    local cost = spell.cost > 0 and spell.cost or (old and old.cost or 0)
    local edge = {
      type = T.TRAINER_TEACHES,
      target = Graph.Key("spell", spell.spell),
      group = string.format(L["Level %d"], level),
      learnLevel = level,
      meta = EraSources.ClassSpellMeta(rank, cost),
      classSpell = {
        classId = classId,
        level = level,
        eraLevel = old and old.eraLevel or nil,
        cost = cost,
        rank = rank,
        -- Brief TW3: a pet trainer's ability (UI/Tree.lua words its mark "Pet ability"; brief PL1
        -- reads it Learnt where the hunter or a pet knows it, Tree.PetTrainerLearnt).
        pet = list.pet == true or nil,
      },
      confidence = Confidence.MINED,
      provenance = provenance,
    }
    -- Ruling "B": no Classic Era list of the class holds it.
    if type(known) == "table" and not known[spell.spell] then
      edge.newInForever = true
    end
    out[#out + 1] = edge
  end
  if not list.complete and not list.pet and type(nameIndex) == "number" then
    for _, edge in ipairs(self:_ClassTeachesEdges(nameIndex)) do
      local _, spellId = Graph.Parse(edge.target)
      if not held[spellId] then
        out[#out + 1] = edge
      end
    end
  end
  return out
end

--------------------------------------------------------------------------------
-- Brief TW1: a racial class spell's races (the owner's ruling "2.A", 2026-10-18)
--------------------------------------------------------------------------------

-- One class list shows on every trainer of the class (ruling "A"), so a spell only some races learn
-- (a priest's Starshards, Night Elf; a mage's Teleport: Ironforge, the Alliance's) reads with its
-- races in brackets, "Starshards (Night Elf)", on the recorded rows and the Classic Era rows alike
-- (Core/ViewModel.lua, a class spell row's name). The races come from this build's own tables: tm,
-- EraPlaces' (ours: the build's SkillLineAbility race masks, ItemTree-Data
-- era_places.read_spell_races), { [spellId] = race bits }; a spell open to every race has none. The
-- names are the client's own (C_CreatureInfo.GetRaceInfo, one guarded read a race, kept), else ours.
-- All four Alliance races read as the Alliance and all four Horde ones as the Horde.
EraSources.RACES = {
  { bit = 1, id = 1, word = L["Human"] },
  { bit = 2, id = 2, word = L["Orc"] },
  { bit = 4, id = 3, word = L["Dwarf"] },
  { bit = 8, id = 4, word = L["Night Elf"] },
  { bit = 16, id = 5, word = L["Undead"] },
  { bit = 32, id = 6, word = L["Tauren"] },
  { bit = 64, id = 7, word = L["Gnome"] },
  { bit = 128, id = 8, word = L["Troll"] },
}
EraSources.ALLIANCE_RACES = 1 + 4 + 8 + 64
EraSources.HORDE_RACES = 2 + 16 + 32 + 128
EraSources.ALL_RACES = 255

-- The client's own race names, read once a race (false where it would not say).
local raceNames = {}

--- Drops the kept race names (a spec that fakes the client).
function EraSources.ResetRaceNames()
  raceNames = {}
end

--- One Classic race's name: the client's own (C_CreatureInfo.GetRaceInfo's raceName, Util.CanRead
--- first), else our word for it. Guarded: a client that will not say costs the name, never the row.
function EraSources.RaceName(race)
  if type(race) ~= "table" then
    return nil
  end
  local held = raceNames[race.id]
  if held == nil then
    held = false
    local api = rawget(_G, "C_CreatureInfo")
    local util = ItemTree.Util
    if type(api) == "table" and type(api.GetRaceInfo) == "function" then
      local ok, info = pcall(api.GetRaceInfo, race.id)
      local name = ok and type(info) == "table" and info.raceName or nil
      if type(util) == "table" and type(util.CanRead) == "function" and not util.CanRead(name) then
        name = nil
      end
      if type(name) == "string" and name ~= "" then
        held = name
      end
    end
    raceNames[race.id] = held
  end
  return held or race.word
end

-- Whether a bit set holds one bit (Lua 5.1 has no bit operators).
local function hasRace(mask, bit)
  return math.floor(mask / bit) % 2 == 1
end

--- The words a race mask's brackets hold: "Dwarf", "Dwarf, Human" (by name), the Alliance or the
--- Horde for all four of a side's races, or nil for none or every race. Pure over the race names.
function EraSources.RaceWords(mask)
  if type(mask) ~= "number" or mask ~= math.floor(mask) or mask <= 0 then
    return nil
  end
  mask = mask % 256
  if mask == 0 or mask == EraSources.ALL_RACES then
    return nil
  end
  if mask == EraSources.ALLIANCE_RACES then
    return L["Alliance"]
  end
  if mask == EraSources.HORDE_RACES then
    return L["Horde"]
  end
  local names = {}
  for _, race in ipairs(EraSources.RACES) do
    if hasRace(mask, race.bit) then
      names[#names + 1] = EraSources.RaceName(race)
    end
  end
  table.sort(names, function(a, b)
    return a:lower() < b:lower()
  end)
  local words = names[1]
  for index = 2, #names do
    words = string.format(L["%s, %s"], words, names[index])
  end
  return words
end

--- The races one class spell is limited to (tm), as race bits, or nil. Pure over the table.
function EraSources.ClassSpellRaces(source, spellId)
  local masks = type(source) == "table" and source.tm or nil
  local mask = type(masks) == "table" and masks[spellId] or nil
  if type(mask) == "number" and mask > 0 then
    return mask
  end
  return nil
end

--- The words a class spell row's brackets hold (EraSources.RaceWords over tm), or nil.
function E:ClassSpellRaceWords(spellId)
  return EraSources.RaceWords(EraSources.ClassSpellRaces(self:Table(), spellId))
end

--------------------------------------------------------------------------------
-- A zone, and what Classic Era placed there (brief Z1)
--------------------------------------------------------------------------------

-- A zone is a page of its own: every Classic Era source row that states an area, read the other
-- way round, so the page lists what the zone holds by kind (the creatures that drop things there,
-- the veins and herbs, the pools, the chests, the vendors) and its Map tab pins the one the player
-- picks. The table is keyed by item, so the answer is one pass over it, the way a creature's loot
-- and a vendor's stock are.
--
-- The categories a zone lists, by the table's c, and what each is filed under there: the group
-- (the same words, the same ids and the same glyphs an item's own page uses, so a zone reads the
-- way its sources do), the up edge type the row's own columns are worded as (Core/Sources.lua words
-- a Dropped by row, and a zone's row is that fact read from the zone's end), and whether the name
-- is a creature's or an object's, which says whose pins the Map tab draws for it. A world drop and
-- a container state no area and are not here; a quest row states none on this build either, and is
-- listed for the table that one day does.
EraSources.AREA_GROUPS = {
  [1] = { group = "Drops from", as = "DROPPED_BY", kind = "npc" },
  [3] = { group = "Quests", as = "QUEST_REWARD", kind = "quest" },
  [4] = { group = "Sold by", as = "SOLD_BY", kind = "npc" },
  [6] = { group = "Drops from", as = "DROPPED_BY", kind = "npc" },
  [7] = { group = "Skinned from", as = "SKINNED_FROM", kind = "npc" },
  [8] = { group = "Gathered from", as = "GATHERED_FROM", kind = "object" },
  [9] = { group = "Mined from", as = "GATHERED_FROM", kind = "object" },
  [10] = { group = "Fished in", as = "FISHED_FROM", kind = "object" },
  [11] = { group = "Found in", as = "LOOTED_FROM", kind = "object" },
  [12] = { group = "Pickpocketed from", as = "DROPPED_BY", kind = "npc" },
}

-- The order the groups are listed in, each with the categories it gathers. A boss and a creature
-- are one group, as they are on an item's page. Core/ViewModel.lua orders the categories again by
-- its own table, so this is only the order the rows arrive in.
EraSources.AREA_ORDER = {
  { group = "Drops from", categories = { 1, 6 } },
  { group = "Mined from", categories = { 9 } },
  { group = "Gathered from", categories = { 8 } },
  { group = "Fished in", categories = { 10 } },
  { group = "Found in", categories = { 11 } },
  { group = "Skinned from", categories = { 7 } },
  { group = "Pickpocketed from", categories = { 12 } },
  { group = "Sold by", categories = { 4 } },
  { group = "Quests", categories = { 3 } },
}

-- One entry of the area index is ONE number: the item, the name and the value packed together as
-- ((item * AREA_SPAN) + name) * AREA_SPAN + value. The value is the stock for a vendor and otherwise
-- the chance in tenths plus PACK_QUEST_ONLY, exactly what a packed list states, so a named row and
-- a listed record are held the same way; the name is 0 for a row that names nothing (a whole
-- fishing zone). Both fit two base 91 digits, so under AREA_SPAN, and an item id under a million
-- keeps the whole number under 2^48, which a Lua number holds exactly. Measured on the real table
-- (59,810 entries), three numbers an entry was 4.4 MB and this is about a third of that, for a page
-- that is opened and read a zone at a time.
local AREA_SPAN = 16384

local function areaEntry(itemId, nameIndex, value)
  return (itemId * AREA_SPAN + nameIndex) * AREA_SPAN + value
end

local function areaParts(entry)
  local value = entry % AREA_SPAN
  local rest = (entry - value) / AREA_SPAN
  local nameIndex = rest % AREA_SPAN
  return (rest - nameIndex) / AREA_SPAN, nameIndex, value
end

-- Area to what Classic Era placed in it, built in ONE pass over the whole table: every shipped row
-- that states an area (a summary row states none) and every packed list of a category above, whose
-- records all carry theirs. Built on the first zone page OPENED and then kept (E:_AreaIndex), never
-- at load and never on the way to a drawn tree. tests/spec/era_creature_spec.lua measures it on the
-- real table.
--
--   areas[areaId][category]  an array of packed entries (areaEntry), in item id order
--   entries                  how many entries there are in all
--   lists                    how many packed lists this pass decoded
--   places                   how many areas carry anything at all
function EraSources.AreaIndex(source)
  local index = { areas = {}, entries = 0, lists = 0, places = 0 }
  local rows = type(source) == "table" and source.r or nil
  if type(rows) ~= "table" then
    return index
  end
  local areas = index.areas

  local function add(areaId, category, itemId, value, nameIndex)
    if type(areaId) ~= "number" or areaId < 1 or type(itemId) ~= "number" or itemId < 1 then
      return
    end
    if nameIndex < 0 or nameIndex >= AREA_SPAN or value < 0 or value >= AREA_SPAN or itemId >= 1000000 then
      return
    end
    local byCategory = areas[areaId]
    if not byCategory then
      byCategory = {}
      areas[areaId] = byCategory
      index.places = index.places + 1
    end
    local bucket = byCategory[category]
    if not bucket then
      bucket = {}
      byCategory[category] = bucket
    end
    bucket[#bucket + 1] = areaEntry(itemId, nameIndex, value)
    index.entries = index.entries + 1
  end

  local ids = {}
  for itemId in pairs(rows) do
    if type(itemId) == "number" then
      ids[#ids + 1] = itemId
    end
  end
  table.sort(ids)

  local lists = type(source.xl) == "table" and source.xl or nil
  local packs = type(source.x) == "table" and source.x or nil
  local scan = { only = EraSources.AREA_GROUPS, onlyKey = "c" }
  for _, itemId in ipairs(ids) do
    for _, raw in scanRows(source, itemId, scan) do
      if type(raw) == "table" and raw.t == nil and EraSources.AREA_GROUPS[raw.c] and type(raw.a) == "number" then
        local value = 0
        if raw.c == VENDOR_CATEGORY then
          value = tonumber(raw.k) or 0
        else
          local chance = chanceOf(raw.p)
          if chance then
            value = math.floor(chance * PACK_TENTHS + 0.5)
          end
          if raw.o ~= nil then
            value = value + PACK_QUEST_ONLY
          end
        end
        add(raw.a, raw.c, itemId, value, tonumber(raw.n) or 0)
      end
    end
    local byCategory = packs and packs[itemId] or nil
    if type(byCategory) == "table" and lists then
      -- In category order, so two lists of one item land in the same order on every load.
      for category = 1, CONTAINER_CATEGORY do
        local slot = byCategory[category]
        if EraSources.AREA_GROUPS[category] and type(slot) == "number" then
          local text = lists[slot]
          local width = recordWidth(category)
          if type(text) == "string" and text ~= "" and #text % width == 0 then
            index.lists = index.lists + 1
            for at = 1, #text, width do
              local nameIndex = packedInt(text, at, PACK_NAME)
              local areaId = packedInt(text, at + PACK_NAME, PACK_AREA)
              local value = packedInt(text, at + PACK_NAME + PACK_AREA, PACK_VALUE)
              if nameIndex and areaId and value then
                add(areaId, category, itemId, value, nameIndex)
              end
            end
          end
        end
      end
    end
  end
  return index
end

-- What one zone holds, as the rows its Here tab draws: the groups in AREA_ORDER, and inside each
-- the best chance first (a vendor's rows, which carry no chance, by item), then by item id and
-- name so the answer is the same on every machine. Each row carries the fields a creature's loot
-- row does (category, group, edge words, note, key, chance, stock, item) plus the source it names:
--
--   name       the creature's, the object's or the vendor's name, which the row's zone column says
--   nameIndex  that name's place in the string table, which is what its pins are keyed by (0 for a
--              whole fishing zone, which names nothing and has no pins of its own)
--   sourceKind "npc", "object" or "quest": whose pins the Map tab draws for the row
--   as         the up edge type the row's columns are worded as
--   areaId     the zone itself
--
-- index is an EraSources.AreaIndex, built here for a caller that holds none. questTitle titles an
-- "only on the quest X" row the way EraSources.Rows takes it.
function EraSources.ZoneRows(source, areaId, index, questTitle)
  if type(source) ~= "table" or type(areaId) ~= "number" then
    return EMPTY
  end
  if type(index) ~= "table" or type(index.areas) ~= "table" then
    index = EraSources.AreaIndex(source)
  end
  local byCategory = index.areas[areaId]
  if type(byCategory) ~= "table" then
    return EMPTY
  end
  local out = {}
  for _, spec in ipairs(EraSources.AREA_ORDER) do
    local entries = {}
    for _, category in ipairs(spec.categories) do
      local bucket = byCategory[category]
      for _, packed in ipairs(bucket or EMPTY) do
        local itemId, nameIndex, value = areaParts(packed)
        local entry = { category = category, item = itemId, nameIndex = nameIndex }
        if category == VENDOR_CATEGORY then
          entry.stock = value > 0 and value or nil
        else
          if value >= PACK_QUEST_ONLY then
            entry.onQuest = true
            value = value - PACK_QUEST_ONLY
          end
          entry.chance = chanceOf(value > 0 and value / PACK_TENTHS or nil)
        end
        entries[#entries + 1] = entry
      end
    end
    table.sort(entries, function(a, b)
      local left, right = a.chance or -1, b.chance or -1
      if left ~= right then
        return left > right
      end
      if a.item ~= b.item then
        return a.item < b.item
      end
      if a.nameIndex ~= b.nameIndex then
        return a.nameIndex < b.nameIndex
      end
      return a.category < b.category
    end)
    for _, entry in ipairs(entries) do
      local group = EraSources.AREA_GROUPS[entry.category]
      local note = nil
      if entry.stock then
        note = phrase("LimitedStock", entry.stock)
      elseif entry.onQuest then
        local raw = { o = 1, q = lootQuestId(source, entry.item, entry.category, entry.nameIndex, areaId) }
        note = conditionNote(raw, questTitle)
      end
      out[#out + 1] = place({
        category = EraSources.CATEGORIES[entry.category],
        item = entry.item,
        name = stringAt(source, entry.nameIndex),
        nameIndex = entry.nameIndex > 0 and entry.nameIndex or nil,
        sourceKind = group.kind,
        as = group.as,
        chance = entry.chance,
        stock = entry.stock,
        note = note,
        areaId = areaId,
        key = Graph.Key("item", entry.item),
      }, { edge = "ZONE_HOLDS", group = group.group })
    end
  end
  return out
end

-- The area one zone key's id stands for, and the gathering node it names where it names one. A
-- plain zone key (zone:357) is the area itself; a gathering node's zone row (brief D6,
-- EraSources.GatheredKey) is that node in that area, and opens the same zone with the node already
-- picked. Brief EK2: such a key holds the node's gameobject id, so its name index comes back through
-- oi out of source, the shipped table (nil without one; the area is arithmetic). nil for an id that
-- is neither.
function EraSources.ZoneAt(id, source)
  if type(id) ~= "number" or id ~= math.floor(id) or id == 0 then
    return nil
  end
  if id > 0 then
    if id >= ROW_AREAS then
      return nil
    end
    return id, nil
  end
  local objectId, areaId = pairedParts(GATHERED, id, 1)
  if not objectId then
    return nil
  end
  return areaId, EraSources.ObjectNameIndex(source, objectId)
end

-- The area index, built once per table and kept, or nil on a build that ships no table. Held
-- against the table it was built from, the way E:_LootIndex is.
function E:_AreaIndex()
  local source = self:Table()
  if not source then
    return nil
  end
  if self.areaFor ~= source then
    self.areaIndex = EraSources.AreaIndex(source)
    self.areaFor = source
    self.areaBuilds = (self.areaBuilds or 0) + 1
  end
  return self.areaIndex
end

-- What the area index cost, for the spec and the debug command, the way E:LootCounts is.
function E:AreaCounts()
  local index = self.areaIndex
  return {
    builds = self.areaBuilds or 0,
    entries = (index and index.entries) or 0,
    lists = (index and index.lists) or 0,
    places = (index and index.places) or 0,
  }
end

-- The area and the node one zone key names, where this build names the area, or nil. What decides
-- whether a zone root gets the Here and Map tabs (Core/ViewModel.lua ViewsFor): the key's
-- arithmetic and one table lookup (two for a gathering node's zone key, whose node oi reads back,
-- brief EK2), and no index is built.
function E:ZoneAt(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "zone" then
    return nil
  end
  if not EraSources.ZoneAt(id) then
    return nil
  end
  local source = self:Table()
  local areaId, nameIndex = EraSources.ZoneAt(id, source)
  if not source or not areaId or not areaName(source, areaId) then
    return nil
  end
  return areaId, nameIndex
end

-- The area id this build gives one area NAME, matched without regard to case, or nil. What a zone
-- column the player's own records wrote (the client's own zone text) is linked by. One walk of z
-- builds the whole map, made on the first ask and kept.
function E:AreaIdOf(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  local source = self:Table()
  if not source then
    return nil
  end
  if self.areaNamesFor ~= source then
    local map = {}
    for areaId in pairs(type(source.z) == "table" and source.z or EMPTY) do
      local named = areaName(source, areaId)
      if named then
        local lower = named:lower()
        -- Two areas of one name keep the lower id, so the answer is the same on every load.
        if map[lower] == nil or areaId < map[lower] then
          map[lower] = areaId
        end
      end
    end
    self.areaNames = map
    self.areaNamesFor = source
  end
  return self.areaNames[name:lower()]
end

-- Everything the page says about one zone key, or nil for a key that names no area:
--
--   areaId    the area
--   name      this build's name for it
--   map       the zone map it is drawn on, or nil for an instance (every instance: no dungeon maps)
--   instance  true where there is no map for it, which is how an instance is told from a zone
--   forever   true where the area is new in Forever (zf, brief Z5), else nil
--   nameIndex the gathering node the key names, where it names one (a node row's zone row)
--   nodeName  that node's name
function E:ZoneFacts(key)
  local areaId, nameIndex = self:ZoneAt(key)
  if not areaId then
    return nil
  end
  local source = self:Table()
  local map = EraSources.MapOf(source, areaId)
  return {
    areaId = areaId,
    name = areaName(source, areaId),
    map = map,
    instance = insideArea(source, areaId),
    forever = EraSources.IsForeverArea(source, areaId) or nil,
    nameIndex = nameIndex,
    nodeName = stringAt(source, nameIndex),
  }
end

-- Whether an item is one the zone page leaves out: a developer item the addon never lists
-- (Core/Data.lua Data:IsHidden). Asked per row; a data layer with no such question hides nothing.
function E:_HiddenItem(itemId)
  local data = self.data
  if type(data) ~= "table" or type(data.IsHidden) ~= "function" then
    return false
  end
  local ok, hidden = pcall(data.IsHidden, data, itemId)
  return ok and hidden == true
end

-- One zone's rows as the EDGES its Here tab draws, marked as history like every other edge out of
-- this file. Each points at the item, carries the source's name in its zone column's place (zone),
-- its chance and note, the up edge type its columns are worded as (as), and what the Map tab needs
-- to pin it (pick: the name index, whose pins, and the name). A withheld item whose details are not
-- served is left out and counted in locked, as a creature's loot leaves one out, and a developer
-- item is left out.
--
-- Nothing on the ordinary path to a drawn tree calls this: Core/ViewModel.lua asks only for the Here
-- view of a zone root, which is a page the player opened. Returns the edges and the locked count.
--
-- The last two zones are kept, because one open asks three times (the tab's count, the list and
-- the header's counts) and the biggest zone is some four thousand rows. The keep is dropped when
-- the table or the data layer's generation moves, which is what the Classic Era details setting
-- and the realm check bump, so a locked item never outlives the answer that locked it.
local ZONE_CACHE = 2

function E:ZoneEdges(key)
  local out = {}
  local areaId = self:ZoneAt(key)
  if not areaId then
    return out, 0
  end
  local generation = type(self.data) == "table" and self.data.generation or nil
  local cache = self.zoneCache
  if not cache or cache.source ~= self:Table() or cache.generation ~= generation then
    cache = { source = self:Table(), generation = generation }
    self.zoneCache = cache
  end
  for _, held in ipairs(cache) do
    if held.key == key then
      return held.edges, held.locked
    end
  end
  local rows = EraSources.ZoneRows(self:Table(), areaId, self:_AreaIndex(), function(questId)
    return self:QuestTitle(questId)
  end)
  local locked, counted = 0, {}
  for _, row in ipairs(rows) do
    if not self:_Unlocked(row.item) then
      if not counted[row.item] then
        counted[row.item] = true
        locked = locked + 1
      end
    elseif row.edge and not self:_HiddenItem(row.item) then
      local pick = nil
      if row.nameIndex and row.name then
        pick = { nameIndex = row.nameIndex, kind = row.sourceKind, name = row.name }
      end
      out[#out + 1] = self:_Mark({
        type = row.edge,
        target = row.key,
        group = row.group,
        zone = row.name,
        percent = row.chance,
        percentSource = row.chance and EraSources.PROVENANCE or nil,
        note = row.note,
        as = row.as,
        areaId = areaId,
        pick = pick,
      })
    end
  end
  table.insert(cache, 1, { key = key, edges = out, locked = locked })
  while #cache > ZONE_CACHE do
    table.remove(cache)
  end
  return out, locked
end

--------------------------------------------------------------------------------
-- The creatures and NPCs a zone holds (brief Z2, 2026-09-30)
--------------------------------------------------------------------------------

-- Area to the creature names whose pins stand in it, built in ONE pass over mp that reads only the
-- area digits of each record (the way EraSources.PinAreas does for one name), so no coordinate is
-- decoded and the Map tab's pin cache is left alone. Built on the first zone page OPENED and then
-- kept (E:_PinAreaIndex), never at load. Pure.
--
--   areas[areaId][nameIndex]  how many of that name's pins stand in the area
--   names                     how many names carry a pin at all
--   pairs                     how many (name, area) pairs there are
function EraSources.PinAreaIndex(source)
  local index = { areas = {}, names = 0, pairs = 0 }
  local pins = type(source) == "table" and source.mp or nil
  if type(pins) ~= "table" then
    return index
  end
  local areas = index.areas
  for nameIndex, text in pairs(pins) do
    if type(nameIndex) == "number" and type(text) == "string" and text ~= "" and #text % PIN_WIDTH == 0 then
      index.names = index.names + 1
      for at = 1, #text, PIN_WIDTH do
        local areaId = packedInt(text, at, PIN_AREA)
        if areaId and areaId > 0 then
          local bucket = areas[areaId]
          if not bucket then
            bucket = {}
            areas[areaId] = bucket
          end
          local held = bucket[nameIndex]
          if not held then
            index.pairs = index.pairs + 1
          end
          bucket[nameIndex] = (held or 0) + 1
        end
      end
    end
  end
  return index
end

-- Everything that stands in one area, split the way the zone page lists it: { creatures, npcs },
-- each an array of
--
--   { nameIndex, key, name, pins (how many in this area), type, family, low, high (out of ck, where
--     it states a kind), vendor, trainer (booleans), starts, ends (quest counts), title (st) }
--
-- key is the name's page (brief EK1, EraSources.PageKey), nil for a name the table states no
-- creature id for, which then has no page to open.
--
-- sorted by name without regard to case, then by name index. A name is an NPC where the table
-- lists it as a vendor (ck's role), a trainer (tr) or a quest giver or ender (qg); every other
-- name with a pin here is a creature. So a creature that is also a vendor is an NPC. ck states no
-- rank (no rare or elite), so nothing leads: the order is the name's. index is an
-- EraSources.PinAreaIndex, built here for a caller that holds none. Pure.
function EraSources.ZonePeople(source, areaId, index)
  local out = { creatures = {}, npcs = {} }
  if type(source) ~= "table" or type(areaId) ~= "number" then
    return out
  end
  if type(index) ~= "table" or type(index.areas) ~= "table" then
    index = EraSources.PinAreaIndex(source)
  end
  local names = index.areas[areaId]
  if type(names) ~= "table" then
    return out
  end
  for nameIndex, pins in pairs(names) do
    local name = stringAt(source, nameIndex)
    if name then
      local creatureType, family, low, high, role = EraSources.KindOf(source, nameIndex)
      local starts, ends = EraSources.QuestCounts(source, nameIndex)
      local person = {
        nameIndex = nameIndex,
        key = EraSources.PageKey(source, nameIndex),
        name = name,
        pins = pins,
        type = creatureType,
        family = family,
        low = low,
        high = high,
        vendor = role == "vendor" or role == "both",
        trainer = EraSources.TeachCount(source, nameIndex) > 0,
        starts = starts,
        ends = ends,
      }
      if person.vendor or person.trainer or starts > 0 or ends > 0 then
        person.title = EraSources.Title(source, nameIndex)
        out.npcs[#out.npcs + 1] = person
      else
        out.creatures[#out.creatures + 1] = person
      end
    end
  end
  local function byName(a, b)
    local left, right = a.name:lower(), b.name:lower()
    if left ~= right then
      return left < right
    end
    return a.nameIndex < b.nameIndex
  end
  table.sort(out.creatures, byName)
  table.sort(out.npcs, byName)
  return out
end

-- The pin area index, built once per table and kept, or nil on a build that ships no table. Held
-- against the table it was built from, the way E:_AreaIndex is.
function E:_PinAreaIndex()
  local source = self:Table()
  if not source then
    return nil
  end
  if self.pinAreaFor ~= source then
    self.pinAreaIndex = EraSources.PinAreaIndex(source)
    self.pinAreaFor = source
    self.pinAreaBuilds = (self.pinAreaBuilds or 0) + 1
  end
  return self.pinAreaIndex
end

-- What the pin area index cost, for the spec, the way E:AreaCounts is.
function E:PinAreaCounts()
  local index = self.pinAreaIndex
  return {
    builds = self.pinAreaBuilds or 0,
    names = (index and index.names) or 0,
    pairs = (index and index.pairs) or 0,
  }
end

-- The creatures and NPCs one zone key's area holds (EraSources.ZonePeople), or nil for a key that
-- names no area. The last two zones are kept, the way E:ZoneEdges keeps its rows, because one open
-- asks twice (the side panel's counts and the Map view's column).
function E:ZonePeople(key)
  local areaId = self:ZoneAt(key)
  if not areaId then
    return nil
  end
  local source = self:Table()
  local cache = self.peopleCache
  if not cache or cache.source ~= source then
    cache = { source = source }
    self.peopleCache = cache
  end
  for _, held in ipairs(cache) do
    if held.areaId == areaId then
      return held.people
    end
  end
  local people = EraSources.ZonePeople(source, areaId, self:_PinAreaIndex())
  table.insert(cache, 1, { areaId = areaId, people = people })
  while #cache > ZONE_CACHE do
    table.remove(cache)
  end
  return people
end

-- Installed here rather than in Core/Init.lua's OnLoaded, where the collector and the curated
-- quests are wired up, because there is nothing to wire: this table is shipped data with no
-- saved variables behind it, no settings of its own and no state to carry over a reload. The
-- module itself is read lazily, so a load that never opens a Sources view never builds it.
ItemTree.eraSources = EraSources.New()
ItemTree.eraSources:Install()

return EraSources
