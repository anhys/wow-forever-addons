-- The item graph: keys, nodes, edges and walks over the generated data.
-- Pure Lua, no WoW API. Loaded as: local _, ItemTree = ...
--
-- A node is addressed by a string key, "<kind>:<id>", so a row can be identified and
-- compared without carrying a table around. Edges are filtered by direction: "up" answers
-- "where does this come from", "down" answers "what is this used for". The direction is
-- chosen once at the root and never flips inside a branch, which is what keeps a chain
-- readable (see design: rerooting).
local _, ItemTree = ...

local Data = ItemTree.Data
local Edges = ItemTree.Edges
local Confidence = ItemTree.Confidence
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local T = Edges.Types
local EMPTY = {}

local Graph = {}
ItemTree.Graph = Graph

-- Node kind (the key prefix) to the row type the UI draws.
local NODE_TYPES = {
  item = "item",
  spell = "recipe",
  skill = "skill",
  set = "set",
  enchant = "enchant",
  quest = "quest",
  npc = "npc",
  object = "object",
  zone = "zone",
}

-- Kinds with no generated module behind them. They are only ever reached through
-- collector or curated edges, so the name comes from the registry below or a fallback.
local REFERENCE_KINDS = {
  quest = true,
  npc = true,
  object = true,
  zone = true,
}

-- The word a title and a nameless node lead with, one per node kind. Each word is the English
-- wording and its own locale key, read through L by key rather than written as a literal, so
-- tests/spec/locale_spec.lua lists the block rather than sweeping for it.
local KIND_LABELS = {
  item = "Item",
  spell = "Spell",
  skill = "Skill",
  set = "Set",
  enchant = "Enchant",
  quest = "Quest",
  npc = "Creature",
  object = "Object",
  zone = "Zone",
}

-- The shape a title takes for everything that is not an item: the kind, the name and the id,
-- "Spell: Spiced Wolf Meat (2539)". A kind with no name to show falls back to "Spell 2539".
local TITLE_FORMAT = "%s: %s (%d)"
-- Brief TR2 (item 130): a creature or NPC with a client id, its name and that id and no kind word.
local NPC_TITLE_FORMAT = "%s (%d)"

-- An item combine is a spell, but calling it one says nothing: a player knows it as the thing
-- they do by using an item. The word leads its title ("Combine: Sulfuras, Hand of Ragnaros
-- (21160)") and names the category its edges are filed under, and each is its own locale key.
local COMBINE_LABEL = "Combine"
local COMBINE_GROUP = "Item use"

-- The item class the build gives armour, which is the one class a withheld item is named by its
-- slot as well as its subclass: a mail chest and a mail helm are different items, where a sword
-- is a sword whichever hand it goes in.
local ARMOUR_CLASS = 4

-- Inventory type to the word a withheld item is named by, for the slots where the slot says
-- more than the subclass does. Each word is the English wording and its own locale key, read
-- through L by key, so tests/spec/locale_spec.lua lists the block rather than sweeping for it.
-- A slot that is not here (a weapon hand, a bag, a quiver) is named by its subclass instead.
local SLOT_WORDS = {
  [1] = "head",
  [2] = "neck",
  [3] = "shoulder",
  [4] = "shirt",
  [5] = "chest",
  [6] = "waist",
  [7] = "legs",
  [8] = "feet",
  [9] = "wrist",
  [10] = "hands",
  [11] = "ring",
  [12] = "trinket",
  [14] = "shield",
  [16] = "back",
  [19] = "tabard",
  [20] = "chest",
  [23] = "held in off hand",
  [28] = "relic",
}

-- Default confidence for an edge, from the edge type's source.
local SOURCE_CONFIDENCE = {
  mined = Confidence.MINED,
  predicted = Confidence.PREDICTED,
  curated = Confidence.CURATED,
  collected = Confidence.BASELINE,
}

-- Classic class mask bits. No bitwise operators: WoW runs Lua 5.1.
-- id is the ChrClasses id the Uses module's cs rows carry (brief P5b), and token the client's
-- own class file word, which is what its class colour table is keyed by.
local CLASS_BITS = {
  { bit = 1, id = 1, token = "WARRIOR", name = "Warrior" },
  { bit = 2, id = 2, token = "PALADIN", name = "Paladin" },
  { bit = 4, id = 3, token = "HUNTER", name = "Hunter" },
  { bit = 8, id = 4, token = "ROGUE", name = "Rogue" },
  { bit = 16, id = 5, token = "PRIEST", name = "Priest" },
  { bit = 64, id = 7, token = "SHAMAN", name = "Shaman" },
  { bit = 128, id = 8, token = "MAGE", name = "Mage" },
  { bit = 256, id = 9, token = "WARLOCK", name = "Warlock" },
  { bit = 1024, id = 11, token = "DRUID", name = "Druid" },
}

-- Names observed at runtime for kinds with no generated module (quest, npc, object, zone).
-- The collector fills this in as it records, so a source row reads "Hogger" and not
-- "Creature 448". Never stores anything a player typed; see Core/Privacy.lua. A name no
-- writer put here is asked of the namers below, once, and remembered here.
--
-- Brief R3: an item key nothing wrote here reads through to the item name source
-- (Graph.SetItemNameSource), which the collector sets to its discovery store, so the names the
-- realm has discovered answer every direct read of this table without being copied into it at
-- login. A read through is not written back: the store stays the one copy.
local itemNameSource = nil

local NAMES_META = {
  __index = function(_, key)
    if not itemNameSource or type(key) ~= "string" or key:byte(1) ~= 105 then
      return nil
    end
    local id = key:match("^item:(%d+)$")
    if not id then
      return nil
    end
    local ok, name = pcall(itemNameSource, tonumber(id))
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
    return nil
  end,
}

Graph.names = setmetatable({}, NAMES_META)

--- Sets the function every item key missing from Graph.names reads through to: fn(itemId) ->
--- the name, or nil. nil takes it away. The collector's C:Install sets it and C:Uninstall takes it.
function Graph.SetItemNameSource(fn)
  if type(fn) == "function" then
    itemNameSource = fn
  else
    itemNameSource = nil
  end
end

--- The item name source in force, or nil.
function Graph.ItemNameSource()
  return itemNameSource
end

local providers = {}

function Graph.Key(kind, id)
  return tostring(kind) .. ":" .. tostring(id)
end

-- "item:2835" -> "item", 2835. Returns nil for anything that is not a node key.
function Graph.Parse(key)
  if type(key) ~= "string" then
    return nil
  end
  local kind, id = key:match("^(%a+):(%-?%d+)$")
  if not kind then
    return nil
  end
  return kind, tonumber(id)
end

-- Brief RB3 (the owner's QA item 196, his choice A of 2026-10-17): a dead twin quest's key folded into
-- its live quest's (Core/QuestFlags.lua LiveTwin: The Captain's Chest quest:614 reads quest:8551), any
-- other key as it is. Every edge, count and quest list of the graph goes through it, so the twin is
-- one row and one count with its live quest, and its id opens the live quest (UI/Frame.lua Open).
function Graph.FoldTwinKey(key)
  if type(key) ~= "string" or key:sub(1, 6) ~= "quest:" then
    return key
  end
  local flags = ItemTree.QuestFlags
  if type(flags) ~= "table" or type(flags.LiveTwin) ~= "function" then
    return key
  end
  local live = flags.LiveTwin(tonumber(key:sub(7)))
  return live and Graph.Key("quest", live) or key
end

-- Brief RB3: quest ids with each dead twin folded into its live quest, each id once and ascending;
-- the list itself, untouched, where none is a twin.
local function foldTwinIds(ids)
  local flags = ItemTree.QuestFlags
  if type(flags) ~= "table" or type(flags.LiveTwin) ~= "function" or #ids == 0 then
    return ids
  end
  local out, seen, folded = {}, {}, false
  for _, questId in ipairs(ids) do
    local live = flags.LiveTwin(questId)
    folded = folded or live ~= nil
    local id = live or questId
    if not seen[id] then
      seen[id] = true
      out[#out + 1] = id
    end
  end
  if not folded then
    return ids
  end
  table.sort(out)
  return out
end

-- Brief RB3b (the review's M2): the side facts a dead twin's edge states about the TWIN, which a
-- folded edge never keeps: it reads its live quest's side (Graph.QuestSide over the live id), so a
-- twin the Alliance list holds never lends that side to a live quest open to both.
local TWIN_SIDE_FIELDS = { "faction", "seenSide" }

-- A copy of a folded twin's edge without TWIN_SIDE_FIELDS (the provider's own edge is never changed).
local function withoutTwinSide(edge)
  local copy = {}
  for field, value in pairs(edge) do
    copy[field] = value
  end
  for _, field in ipairs(TWIN_SIDE_FIELDS) do
    copy[field] = nil
  end
  return copy
end

function Graph.SetName(key, name)
  if type(key) == "string" and type(name) == "string" and name ~= "" then
    Graph.names[key] = name
  end
end

function Graph.ClearNames()
  Graph.names = setmetatable({}, NAMES_META)
end

-- Namers: a last resort for a node nothing on this client could name.
--
-- A name comes from the generated data, from the running client, or from Graph.names, which the
-- collector and the curated quest table fill in as they build their own indexes. A provider
-- whose data is only read on demand has nowhere to put a name until something asks it for an
-- edge, so a node opened by its key alone (the recently viewed list after a reload, a debug
-- command) would read "Quest 4242" until an item row had named it. A namer answers that question
-- at the moment it is asked, and Core/EraSources.lua is what registers one.
--
-- fn(key) -> the name, or nil. It is asked ONLY for a key every other route answered nothing
-- for, so a load that opens nothing asks nothing and a node the data already names never
-- reaches it. The answer is remembered in Graph.names, so a key is resolved once; a namer must
-- therefore not ask the graph for the name it is answering. Errors cost the name and nothing
-- else, the way an adapter's do.
local namers = {}

-- Brief GF5: first puts the namer ahead of every one already registered, for a namer that answers
-- only keys no other namer can name and must spare them the cost of being asked (Core/QuestsPredicted.lua
-- FirstNamer: a quest Classic Era never knew, which the Era namer would build its quest index to miss).
function Graph.RegisterNamer(fn, first)
  if type(fn) == "function" then
    if first == true then
      table.insert(namers, 1, fn)
    else
      namers[#namers + 1] = fn
    end
  end
  return fn
end

function Graph.UnregisterNamer(fn)
  for index = #namers, 1, -1 do
    if namers[index] == fn then
      table.remove(namers, index)
    end
  end
end

function Graph.ClearNamers()
  namers = {}
end

function Graph.HasNamer(fn)
  for _, namer in ipairs(namers) do
    if namer == fn then
      return true
    end
  end
  return false
end

function Graph.Namers()
  return namers
end

-- The name this client has for a node, asking the namers only where there is none. Every last
-- resort read of Graph.names goes through here, so nothing has to remember to ask.
local function storedName(key)
  local held = Graph.names[key]
  if held ~= nil then
    return held
  end
  for _, namer in ipairs(namers) do
    local ok, name = pcall(namer, key)
    if ok and type(name) == "string" and name ~= "" then
      Graph.names[key] = name
      return name
    end
  end
  return nil
end

-- What the running client says about an item, or nil. The client is the only thing that can
-- name an item this build withholds and someone on the realm has since found, so it is asked
-- for any item the data cannot name and for nothing else. Read through the ItemTree namespace
-- the way ItemTree.SpellName is, so Core stays pure and UI/Client.lua is what fills it in.
local function clientFacts(itemId)
  local resolver = ItemTree.ItemFacts
  if type(resolver) ~= "function" then
    return nil
  end
  local ok, facts = pcall(resolver, itemId)
  if not ok or type(facts) ~= "table" then
    return nil
  end
  if type(facts.name) ~= "string" or facts.name == "" then
    return nil
  end
  return facts
end

-- The words a withheld item is named by, built from what the build's own Item row states and
-- from nothing else: "mail chest", "sword", "trade goods". Never a Classic Era name, never a
-- quality and never a stat, because the build is refusing to state them.
local function undiscoveredWords(item)
  local class, subclass = Data:GetClassName(item.c, item.sc)
  local slot = SLOT_WORDS[item.it] and L[SLOT_WORDS[item.it]] or nil
  local sub = nil
  if type(subclass) == "string" and subclass ~= "" then
    -- The build marks a subclass it no longer uses in brackets ("Explosives (OBSOLETE)"), which
    -- is a note to a dataminer and not a word to name an item by.
    sub = (subclass:gsub("%s*%b()$", "")):lower()
  end
  if sub == "" then
    sub = nil
  end
  if item.c == ARMOUR_CLASS then
    -- Subclass 0 is the build's own Miscellaneous, which says less than the slot alone does.
    if sub and slot and item.sc ~= 0 and sub ~= slot then
      return sub .. " " .. slot
    end
    return slot or sub
  end
  if sub then
    return sub
  end
  if slot then
    return slot
  end
  if type(class) == "string" and class ~= "" then
    return class:lower()
  end
  return nil
end

-- "Undiscovered mail chest", or "Undiscovered item" where the row states nothing to go on. The
-- honest name for an item the build has an Item row for and no ItemSparse row: it exists, and
-- the build will not say what it is until it has dropped for someone on the realm.
function Graph.UndiscoveredName(item)
  if type(item) ~= "table" then
    return nil
  end
  local words = undiscoveredWords(item)
  if not words then
    return L["Undiscovered item"]
  end
  return string.format(L["Undiscovered %s"], words)
end

-- Brief SET2: a set's unnamed member folded into the named piece of the same slot. The client's
-- ItemSet row can list withheld ids for a set while the pieces players have found carry the set
-- in their own data and are not in that list (Grovekeeper Ferocity lists six undiscovered leather
-- pieces, and the crafted Grovekeeper Sandals are feet of the same set). With Merge recipes on, an
-- unnamed withheld member whose armour subclass and slot match EXACTLY ONE named member of the same
-- set is drawn as that named member's row. It is a guess by set, slot and armour class, so the
-- named row says so (Graph.SetTwinText). Any other case (two named pieces for the slot, two
-- placeholders for it, a placeholder with no slot, a twin of another subclass) leaves both rows.
--
-- Only local data decides it: the item's own row and the names the collector has recorded. The
-- client is never asked about a member here, so a hover over a set piece never queries the rest
-- of its set. Once the placeholder id is named anywhere local, it is no longer unnamed and the
-- fold stops by itself.

-- Whether a set member is named by something local: its own row, or a name the collector
-- recorded for it.
local function namedLocally(itemId, item)
  if type(item.n) == "string" and item.n ~= "" then
    return true
  end
  return Graph.names[Graph.Key("item", itemId)] ~= nil
end

-- The slot a member is folded by: armour subclass and slot word, or nil for anything else. The
-- slot word rather than the inventory type, so a chest and a robe are the one slot, as the
-- placeholder's own name already says. Subclass 0, the build's Miscellaneous, is no armour class:
-- it holds the rings and trinkets a set can list two of (Scale of the Gods, set 241, lists two
-- trinkets), so a piece of it is never anyone's twin.
local function twinSlot(item)
  if item.c ~= ARMOUR_CLASS or type(item.sc) ~= "number" or item.sc == 0 then
    return nil
  end
  local slot = SLOT_WORDS[item.it]
  if not slot then
    return nil
  end
  return item.sc .. ":" .. slot
end

--- The fold for one set, as two maps: byNamed { [namedId] = placeholderId } and byPlaceholder
--- { [placeholderId] = namedId }. Empty maps for a set with nothing to fold. Pure over Data and
--- Graph.names.
function Graph.SetTwins(setId)
  local byNamed, byPlaceholder = {}, {}
  local set = Data:GetSet(setId)
  if type(set) ~= "table" or type(set.items) ~= "table" then
    return byNamed, byPlaceholder
  end
  local seen, named, unnamed = {}, {}, {}
  for _, member in ipairs(set.items) do
    local id = tonumber(member)
    if id and not seen[id] then
      seen[id] = true
      local item = Data:GetItem(id)
      local slot = type(item) == "table" and twinSlot(item) or nil
      if slot then
        local into = named
        if item.u and not namedLocally(id, item) then
          into = unnamed
        elseif not namedLocally(id, item) then
          into = nil
        end
        if into then
          local list = into[slot]
          if not list then
            list = {}
            into[slot] = list
          end
          list[#list + 1] = id
        end
      end
    end
  end
  for slot, placeholders in pairs(unnamed) do
    local pieces = named[slot]
    if #placeholders == 1 and pieces and #pieces == 1 then
      byNamed[pieces[1]] = placeholders[1]
      byPlaceholder[placeholders[1]] = pieces[1]
    end
  end
  return byNamed, byPlaceholder
end

--- Whether set members are folded (Graph.SetTwins): opts.foldSetTwins where a caller states it,
--- else the Merge recipes setting (settings.mergeCrafts), which is on unless it is false. Read at
--- call time, so the tree, the chain and the tooltip all follow the one tick box. Pure over opts
--- and ItemTree.db.
function Graph.FoldsSetTwins(opts)
  if type(opts) == "table" and opts.foldSetTwins ~= nil then
    return opts.foldSetTwins == true
  end
  local db = ItemTree.db
  local settings = type(db) == "table" and db.settings or nil
  if type(settings) ~= "table" then
    return true
  end
  return settings.mergeCrafts ~= false
end

--- The placeholder id folded into this named item, or nil. on is Graph.FoldsSetTwins's answer,
--- read from the setting when nil. Pure over Data.
function Graph.SetTwinOf(itemId, on)
  local id = tonumber(itemId)
  if not id then
    return nil
  end
  if on == nil then
    on = Graph.FoldsSetTwins()
  end
  if not on then
    return nil
  end
  local item = Data:GetItem(id)
  if type(item) ~= "table" or item.set == nil then
    return nil
  end
  local byNamed = Graph.SetTwins(item.set)
  return byNamed[id]
end

--- The one line a folded row's tooltip and info column carry: "The set's own list also names an
--- undiscovered leather feet item (id 280996). It is probably this one." nil for an item that
--- carries no fold. Pure over Data.
function Graph.SetTwinText(itemId, on)
  local twin = Graph.SetTwinOf(itemId, on)
  if not twin then
    return nil
  end
  local item = Data:GetItem(twin)
  local words = type(item) == "table" and undiscoveredWords(item) or nil
  if not words then
    return nil
  end
  return string.format(
    L["The set's own list also names an undiscovered %s item (id %d). It is probably this one."],
    words,
    twin
  )
end

-- The corner mark an item's icon wears, in ONE place, because four surfaces draw it: the tree
-- row (UI/Tree.lua), the Discoveries row (UI/Discoveries.lua), the info column's header icon
-- (UI/InfoPanel.lua) and a chain stage (UI/Chain.lua). The rule lives here rather than in any
-- one of them so the four can never disagree about what a mark means.
--
--   nil            an ordinary item: this build names it, so there is nothing to mark
--   "undiscovered" the build has an Item row for it and will not say what it is, and nothing
--                  outside the data has named it either. The client's own question mark.
--   "discovered"   somebody on the realm has found it, so this client can name it, and
--                  ItemTree's shipped data still holds only the stub: class, slot and icon, no
--                  stats, no sources, no recipes. A small chest.
--
-- The Assets keys sit beside the rule rather than at each drawing site, which is how Core
-- already hands the window a glyph to draw (a disenchant signpost's own icon key).
Graph.DISCOVERY_MARK_ART = {
  undiscovered = "ICON_QUESTIONMARK",
  discovered = "ICON_DISCOVERED_MARK",
}

--- The mark for a subject that states the two facts Graph.Node puts on an item node,
--- undiscovered and discovered: a node, an info column's content, a row a pane built for
--- itself. Answers the word and the Assets key it is drawn with, or nothing at all for an item
--- that wears no mark. Pure.
function Graph.DiscoveryMark(subject)
  if type(subject) ~= "table" or not subject.undiscovered then
    return nil
  end
  if subject.discovered then
    return "discovered", Graph.DISCOVERY_MARK_ART.discovered
  end
  return "undiscovered", Graph.DISCOVERY_MARK_ART.undiscovered
end

--- The one line a tooltip carries about a mark, or nothing for a mark that needs none. Only the
--- chest gets one: the question mark's own sentence is already drawn wherever it is marked
--- ("Undiscovered in Forever. Its details appear once someone on your realm finds it."), and the
--- same fact twice in one tooltip reads as a stutter.
---
--- E44: the four surfaces write this line on every hover of a marked item, the client's own item
--- tooltip included, and it is the whole of the small tooltip the chest itself raises. Each of
--- them writes it in exactly one place and ItemTree's tooltip block never writes it at all, so it
--- can never land twice in one tooltip. Pure.
function Graph.DiscoveryMarkText(mark)
  if mark == "discovered" then
    return L["This item has been discovered"]
  end
  return nil
end

--- The same answer for ONE item id, where the surface holds no node to ask about: a chain stage
--- carries the withheld fact and not the other half of it, and a bare withheld id has no node at
--- all. Never a list: the caller has a single withheld id in front of it, and the node it builds
--- is the one Core already built for that id in the same breath.
function Graph.ItemDiscoveryMark(itemId)
  local id = tonumber(itemId)
  if not id then
    return nil
  end
  local node = Graph.Node(Graph.Key("item", id))
  if node then
    return Graph.DiscoveryMark(node)
  end
  -- No node: the build withholds the id, nothing compiled points at it and nothing outside the
  -- data has named it, so there was no name to build a node from. It is a withheld item still.
  if Data:IsUndiscovered(id) then
    return "undiscovered", Graph.DISCOVERY_MARK_ART.undiscovered
  end
  return nil
end

local function itemName(itemId)
  local item = Data:GetItem(itemId)
  if item and item.n then
    return item.n
  end
  local de = Data:GetDisenchant()
  local material = de and de.materials and de.materials[itemId]
  if material then
    return material
  end
  local stored = Graph.names[Graph.Key("item", itemId)]
  if stored then
    return stored
  end
  local facts = clientFacts(itemId)
  if facts then
    return facts.name
  end
  if item and item.u then
    return Graph.UndiscoveredName(item)
  end
  return nil
end

-- Whether a recipe row is an item combine: a create item spell an item's own use effect casts,
-- with no SkillLineAbility behind it and so no profession. Takes the recipe table or a spell id.
function Graph.IsCombine(recipe)
  if type(recipe) == "number" then
    recipe = Data:GetRecipe(recipe)
  end
  return type(recipe) == "table" and recipe.src == "item"
end

-- The items whose use effect casts this spell, as { { itemId, name } }. Empty for anything that
-- is not a combine, and for a combine the build states no via item for.
function Graph.CombineVia(recipe)
  if type(recipe) == "number" then
    recipe = Data:GetRecipe(recipe)
  end
  local out = {}
  if type(recipe) ~= "table" then
    return out
  end
  for _, itemId in ipairs(recipe.via or EMPTY) do
    out[#out + 1] = { itemId = itemId, name = itemName(itemId) or Graph.Fallback("item", itemId) }
  end
  return out
end

-- The recipe items that teach a spell, as { { key, name } }, in the order the build states
-- them. Takes a spell key or a plain spell id.
--
-- The same fact the TAUGHT_BY edges carry and Graph.SpellInfo answers with in taughtBy, read on
-- its own so a row can say "a recipe teaches this" without walking the spell's whole up side or
-- building its info table. Empty for a spell nothing teaches, which is the ordinary trainer
-- taught case (693 of the 2,549 recipes in build 1.60.1.69913), and for anything that is not a
-- spell. Pure.
function Graph.TaughtBy(spellOrKey)
  local out = {}
  local id = tonumber(spellOrKey)
  if not id then
    local kind, parsed = Graph.Parse(spellOrKey)
    if kind ~= "spell" then
      return out
    end
    id = parsed
  end
  local recipe = Data:GetRecipe(id)
  for _, itemId in ipairs((recipe and recipe.by) or EMPTY) do
    out[#out + 1] = {
      key = Graph.Key("item", itemId),
      name = itemName(itemId) or Graph.Fallback("item", itemId),
    }
  end
  return out
end

-- What a combine is called, and whether that name was taken from what it makes.
--
-- The build very often names the spell after the item you use: 21160 is called "Eye of Sulfuras"
-- and makes Sulfuras, Hand of Ragnaros, so a row reading "Eye of Sulfuras" beside the item of
-- the same name says nothing at all. Such a row is named after what it makes instead, and
-- Graph.Node puts "Combine: " in front of it so it is never mistaken for the item itself. A
-- combine the build gave a name of its own ("Mend Sigil", "Forming Rhok'delar") keeps it.
local function combineName(recipe)
  local name = recipe.n
  local sameAsVia = false
  for _, itemId in ipairs(recipe.via or EMPTY) do
    if name ~= nil and itemName(itemId) == name then
      sameAsVia = true
    end
  end
  if name ~= nil and name ~= "" and not sameAsVia then
    return name, false
  end
  local outputId = recipe.out and recipe.out[1] or nil
  local made = outputId and itemName(outputId) or nil
  if not made then
    return name, false
  end
  return made, true
end

-- The node kind a key names ("item", "spell", "npc"), or nil for anything that is not a key.
-- The first half of Graph.Parse, for a caller that only wants to know what it is holding.
function Graph.Kind(key)
  local kind = Graph.Parse(key)
  if not kind or not NODE_TYPES[kind] then
    return nil
  end
  return kind
end

-- "Spell 2539": what a node is called when nothing on this client names it.
function Graph.Fallback(kind, id)
  return L[KIND_LABELS[kind] or kind] .. " " .. tostring(id)
end

-- The name a node is known by, or nil when nothing on this client names it. Graph.Node fills
-- a fallback in for the kinds with no generated module, so this is the one that answers
-- honestly and lets a title say "Creature 448" once rather than twice.
function Graph.Name(key)
  local kind, id = Graph.Parse(key)
  if not kind or not NODE_TYPES[kind] then
    return nil
  end
  if kind == "item" then
    return itemName(id)
  end
  if kind == "spell" then
    local recipe = Data:GetRecipe(id)
    if recipe and recipe.src == "item" then
      local name = combineName(recipe)
      if name then
        return name
      end
    end
    if recipe and recipe.n then
      return recipe.n
    end
    local resolver = ItemTree.SpellName
    local named = type(resolver) == "function" and resolver(id) or nil
    if named then
      return named
    end
  elseif kind == "skill" then
    local skill = Data:GetSkill(id)
    if skill and skill.n then
      return skill.n
    end
  elseif kind == "set" then
    local set = Data:GetSet(id)
    if set and set.n then
      return set.n
    end
  elseif kind == "enchant" then
    local enchant = Data:GetEnchant(id)
    if enchant and enchant.n then
      return enchant.n
    end
  end
  return storedName(key)
end

-- What a window title and a breadcrumb call a node. An item is its own name, because a player
-- knows the item by it; everything else says which kind it is, because "Spiced Wolf Meat" on
-- its own would read as the item rather than the recipe that makes it. nil for a key that is
-- not a node key.
function Graph.Title(key)
  local kind, id = Graph.Parse(key)
  if not kind or not NODE_TYPES[kind] then
    return nil
  end
  local name = Graph.Name(key)
  if not name then
    return Graph.Fallback(kind, id)
  end
  if kind == "item" then
    return name
  end
  -- A combine leads with the word for what it is rather than with "Spell", because a player
  -- knows it as something they do by using an item and never as a spell they cast.
  if kind == "spell" and Graph.IsCombine(id) then
    return string.format(L[TITLE_FORMAT], L[COMBINE_LABEL], name, id)
  end
  -- An id that is not positive is one the ADDON made up, not one the game states: the nodes
  -- Core/EraSources.lua keys by a name's place in the string table (a vendor or a creature in one
  -- place, an object, a pocket, a gathering node), a Classic Era creature's page (its CMaNGOS
  -- creature id negated, brief EK1) and the world drop every such row shares. The owner's
  -- rule, brief E57: no made up id anywhere a player reads, which is this title, the breadcrumb
  -- and the Recently viewed list, so "Creature: Skum (-5199)" is just "Skum". The kind word goes
  -- with it, because a name with no id after it reads as a made up label rather than as a lookup
  -- (and since brief TR2 an NPC with a client id carries no kind word either).
  if id <= 0 then
    return name
  end
  -- Brief Z1: a zone is titled by its name alone, the way a creature is. Its area id is a table
  -- row nobody reads, and the page says "Zone" or "Instance" in its own column (UI/InfoPanel.lua
  -- ZoneKindWord) where a creature's says what kind of creature it is.
  if kind == "zone" then
    return name
  end
  -- Brief TR2 (owner QA 2026-10-11 item 130): an NPC page drops the kind word, "Lilyssia
  -- Nightbreeze (5499)": its page says what kind of creature it is in its own column.
  if kind == "npc" then
    return string.format(L[NPC_TITLE_FORMAT], name, id)
  end
  return string.format(L[TITLE_FORMAT], L[KIND_LABELS[kind] or kind], name, id)
end

-- "Blacksmithing 300". Rank is dropped when it is nil or zero.
function Graph.SkillLabel(skillLine, rank)
  if not skillLine then
    return nil
  end
  local name = Data:GetSkillName(skillLine)
  if rank and rank > 0 then
    return name .. " " .. tostring(rank)
  end
  return name
end

-- How many playable classes the mask is read against. A requirement row is only a restriction
-- when the mask leaves at least one of them out, and the count is taken from the same list the
-- names are, so a build with a different class list still reads correctly.
function Graph.ClassCount()
  return #CLASS_BITS
end

-- Class names allowed by an allowableClass mask, in Classic order.
function Graph.ClassNames(mask)
  local names = {}
  if type(mask) ~= "number" or mask <= 0 then
    return names
  end
  for _, entry in ipairs(CLASS_BITS) do
    if mask % (entry.bit * 2) >= entry.bit then
      names[#names + 1] = entry.name
    end
  end
  return names
end

-- Brief P5b: one class by its ChrClasses id, as { id, token, name }, or nil for 0 (a spell several
-- classes share) and for an id no playable class has. name is the English word the Requires rows
-- use too; token is the client's class file word ("SHAMAN"). Pure.
function Graph.ClassInfo(classId)
  local id = tonumber(classId)
  for _, entry in ipairs(CLASS_BITS) do
    if entry.id == id then
      return { id = entry.id, token = entry.token, name = entry.name }
    end
  end
  return nil
end

-- The band entry that names one material, so a reverse edge carries the same chance and
-- counts the forward edge does.
local function disenchantResult(band, materialId)
  for _, result in ipairs(band and band.out or EMPTY) do
    if result[1] == materialId then
      return result
    end
  end
  return nil
end

-- The art a recipe row draws. A recipe has no icon of its own: the design shows the item
-- the recipe makes, with the profession glyph tucked into the corner, so the output item's
-- icon is the right answer. A recipe that makes no item, an enchant for example, falls back
-- to the profession's own icon, and one with neither returns nil so the row draws the plain
-- stand in rather than a question mark.
local function recipeIcon(recipe)
  local outputId = recipe.out and recipe.out[1] or nil
  if outputId then
    local item = Data:GetItem(outputId)
    if item and item.i then
      return item.i
    end
  end
  -- An item combine has no profession behind it, so the skill's icon is not there to fall back
  -- to and ten of the 358 in build 1.60.1.69913 drew nothing at all. The item you use is the
  -- next best picture of what the row is, and the row already carries the spell mark, so it can
  -- never be read as the item itself.
  for _, itemId in ipairs(recipe.via or EMPTY) do
    local item = Data:GetItem(itemId)
    if item and item.i then
      return item.i
    end
  end
  local skill = recipe.sl and Data:GetSkill(recipe.sl) or nil
  return skill and skill.i or nil
end

-- The qualifier an item combine's row carries where a profession recipe carries "Mining": the
-- item whose use casts it. 53 combines in build 1.60.1.69913 are cast by more than one item, so
-- the rest are counted rather than listed; the info column names them all.
function Graph.CombineMeta(recipe)
  if type(recipe) == "number" then
    recipe = Data:GetRecipe(recipe)
  end
  local via = Graph.CombineVia(recipe)
  if #via == 0 then
    return L[COMBINE_GROUP]
  end
  if #via == 1 then
    return via[1].name
  end
  return string.format(L["%s and %d more"], via[1].name, #via - 1)
end

-- Builds a node for a key, or nil when nothing is known about it.
function Graph.Node(key)
  local kind, id = Graph.Parse(key)
  if not kind or not NODE_TYPES[kind] then
    return nil
  end
  local node = { key = key, kind = kind, id = id, type = NODE_TYPES[kind], badges = {} }
  if kind == "item" then
    -- Brief DV1: 1 for a developer item, 2 for one probably never released, nil otherwise.
    if type(Data.HiddenKind) == "function" then
      node.unobtainable = Data:HiddenKind(id)
    end
    local item = Data:GetItem(id)
    if item and item.n then
      node.name = item.n
      node.quality = item.q
      node.icon = item.i
      -- Brief D5: a withheld item Core/Data.lua serves its Classic Era row for. It reads as the
      -- named item it was in Classic Era, and says so to any reader through this flag.
      if item.era then
        node.era = true
      end
      if item.sk then
        node.meta = Graph.SkillLabel(item.sk, item.skr)
      end
    else
      -- An item the data cannot name: a withheld stub, or an id nothing in the build states.
      --
      -- node.undiscovered says the build has an Item row and no ItemSparse row for it, which is
      -- what draws the dimmed row and the line about the realm. node.discovered says something
      -- outside the data named it anyway: the running client, because someone on the realm has
      -- found it, or the collector's own note from the session that watched that happen. Both
      -- can be true at once, and that is the ordinary case for a discovered item.
      --
      -- No quality and no stats come from anywhere but the client here. The baseline's name for
      -- such an id is served only through Data:GetItem's Classic Era row (brief D5), which takes
      -- the branch above; with that setting off, this is the stub and nothing more.
      if item and item.u then
        node.undiscovered = true
        node.icon = item.i
      elseif Data:IsUndiscovered(id) then
        -- Sealed, and nothing in the compiled data points at it, so it has no stub: 12,504 ids
        -- are withheld in build 1.60.1.69913 and only 2,599 of them are reachable from the
        -- data. Such an id is only ever drawn once something outside the data names it, and it
        -- is still a withheld item when it is.
        node.undiscovered = true
      end
      local facts = clientFacts(id)
      if facts then
        node.discovered = true
        node.name = facts.name
        node.quality = facts.quality
        node.icon = facts.icon or node.icon
      else
        -- Graph.names rather than storedName: a name here means the collector watched this
        -- client resolve the item, which is what node.discovered stands for, and a namer's
        -- answer is not that. An item is named by the trailing fallback below instead.
        local stored = Graph.names[key]
        if stored then
          node.discovered = true
          node.name = stored
        else
          local de = Data:GetDisenchant()
          node.name = de and de.materials and de.materials[id] or nil
          if not node.name and node.undiscovered then
            node.name = Graph.UndiscoveredName(item)
          end
        end
      end
    end
  elseif kind == "spell" then
    local recipe = Data:GetRecipe(id)
    if recipe then
      node.name = recipe.n
      node.skillLine = recipe.sl
      node.profession = recipe.sl
      node.meta = Graph.SkillLabel(recipe.sl, recipe.r)
      node.outputItem = recipe.out and recipe.out[1] or nil
      node.icon = recipeIcon(recipe)
      if recipe.src == "item" then
        -- An item combine: no profession to qualify the row with, so it says what you use
        -- instead, and a row the build named after that item is renamed after what it makes.
        node.combine = true
        local name, fromOutput = combineName(recipe)
        node.name = name
        if fromOutput and name then
          node.name = string.format(L["Combine: %s"], name)
        end
        node.meta = Graph.CombineMeta(recipe)
      end
    else
      -- Brief P5b: a spell that is no recipe, a class spell an item is the reagent for. Its name
      -- is the one resolver's (the SpellNames module, or the client's in the UI layer).
      local resolver = ItemTree.SpellName
      if type(resolver) == "function" then
        local ok, named = pcall(resolver, id)
        if ok and type(named) == "string" and named ~= "" then
          node.name = named
        end
      end
    end
  elseif kind == "skill" then
    local skill = Data:GetSkill(id)
    node.name = skill and skill.n or nil
  elseif kind == "set" then
    local set = Data:GetSet(id)
    node.name = set and set.n or nil
    if set and set.sk then
      node.meta = Graph.SkillLabel(set.sk, set.skr)
    end
  elseif kind == "enchant" then
    local enchant = Data:GetEnchant(id)
    node.name = enchant and enchant.n or nil
    if enchant and enchant.sk then
      node.meta = Graph.SkillLabel(enchant.sk, enchant.skr)
    end
  elseif REFERENCE_KINDS[kind] then
    -- The kinds with no generated module behind them, which is where a namer earns its keep: a
    -- quest or a creature reached by its key alone is named here or not at all.
    node.name = storedName(key) or Graph.Fallback(kind, id)
  end
  if not node.name then
    node.name = storedName(key)
  end
  if not node.name then
    return nil
  end
  return node
end

-- Providers that answer nothing but Predicted edges, which the edge counts in Graph.Summary drop
-- anyway (providerEdges). Brief U3: the Classic Era table is one, and asking it would load the
-- data addon on every tooltip for edges that are then thrown away, so Graph.Summary skips it.
local predictedOnly = setmetatable({}, { __mode = "k" })

-- Brief GS2: providers that answer nothing but guesses (Core/GuessSources.lua). Such a provider
-- is asked only by a walk that set opts.includeGuessSources, which only the Sources view's root walk
-- does, so it is never asked for a nested row, a chain or a count.
local guessOnly = setmetatable({}, { __mode = "k" })

-- opts.predictedOnly says every edge the provider gives is Predicted (see above), and
-- opts.guessOnly that every edge it gives is a guess.
function Graph.RegisterProvider(fn, opts)
  if type(fn) == "function" then
    providers[#providers + 1] = fn
    if type(opts) == "table" and opts.predictedOnly == true then
      predictedOnly[fn] = true
    end
    if type(opts) == "table" and opts.guessOnly == true then
      guessOnly[fn] = true
    end
  end
  return fn
end

function Graph.UnregisterProvider(fn)
  for i = #providers, 1, -1 do
    if providers[i] == fn then
      table.remove(providers, i)
    end
  end
  predictedOnly[fn] = nil
  guessOnly[fn] = nil
end

function Graph.ClearProviders()
  providers = {}
  predictedOnly = setmetatable({}, { __mode = "k" })
  guessOnly = setmetatable({}, { __mode = "k" })
end

-- Whether a provider was registered as answering Predicted edges alone. False, never nil.
function Graph.IsPredictedOnly(fn)
  return predictedOnly[fn] == true
end

-- Whether a provider was registered as answering guesses alone. False, never nil.
function Graph.IsGuessOnly(fn)
  return guessOnly[fn] == true
end

-- Whether one provider function is registered right now. Core/Collector.lua reads it back so
-- a load can say whether collected sources actually reach the graph.
function Graph.HasProvider(fn)
  for _, provider in ipairs(providers) do
    if provider == fn then
      return true
    end
  end
  return false
end

function Graph.Providers()
  return providers
end

local function reagentCount(recipe, itemId)
  for _, reagent in ipairs(recipe.re or EMPTY) do
    if reagent[1] == itemId then
      return reagent[2]
    end
  end
  return nil
end

local function skillGroup(skillLine, fallback)
  return (skillLine and Data:GetSkillName(skillLine)) or fallback
end

-- The category an edge that points at a recipe is filed under. A profession recipe is filed
-- under its profession's own name; an item combine has no profession at all, so it is filed
-- under "Item use" rather than falling into the generic "Produced by" and "Reagent for" buckets
-- with nothing to say which of the 358 of them it is. Anything else keeps the edge's own word.
local function recipeGroup(recipe, fallback)
  if recipe and recipe.src == "item" then
    return L[COMBINE_GROUP]
  end
  return skillGroup(recipe and recipe.sl, fallback)
end

-- The fields an edge carries straight through from what the section that raised it states, in
-- one list rather than a line each in the copy below, so the next field is a word here. An edge
-- holds four things beyond these and every one of them is worked out rather than handed in: its
-- type, its target, its confidence and its group.
--
--   quantity, quantityMax  how many of the target the edge is about, as a number or a range.
--   seen                   a tally of what this client has watched, which Core/Collector.lua is
--                          the only thing that writes. Never a quantity: see the note over
--                          Core/Collector.lua's EdgesFor.
--   used                   true on the item an item combine is cast by USING, as against one it
--                          merely consumes. Both are things the player has to be holding, so
--                          both are reagents and both belong in the Requires view; only the
--                          row's own wording tells them apart.
--   percent                a drop or disenchant rate, out of 100.
--   percentSource          what client line that percentage was measured on. "era" means an
--                          imported Classic Era rate, which is only an estimate on a client
--                          that is not Era; see Core/Sources.lua.
--   meta                   the row's second line, where the section has one to state.
--   zone                   the zone the source is in, stated rather than parsed back out of the
--                          meta line. Core/Sources.lua draws the zone column from it and falls
--                          back to the meta line for an edge written before the field existed.
--                          Nothing mined here knows a zone yet.
--   skillLine              the recipe's skill line, where there is a recipe. A build can name
--                          two skill lines the same way (1.60.1.69893 lists Blacksmithing as
--                          164 and 2938), so the id travels with the edge and the category
--                          never has to look one up from the label.
--   provenance             which database an edge came from, as a short stable key ("att",
--                          "questie"). Nothing the addon ships sets it: it marks the edges an
--                          adapter in Providers/ read out of an addon the player installed
--                          themselves, so a row can say where the claim came from.
--                          Core/Sources.lua turns it into the words a source row draws.
--   price                  a vendor's asking price in copper, where the edge itself knows one.
--                          The item record's buy price is the usual source (Core/Sources.lua),
--                          so this is only set where a provider read a price off the source
--                          rather than off the item, or where the collector read it off the
--                          merchant window the player opened (brief M2).
--   cost                   what a vendor asks beyond money, where the edge itself knows it:
--                          { currency = { [currencyId] = amount }, items = { [itemId] = amount } },
--                          either part absent where there is none, ids and amounts only. Only
--                          the collector sets it, from the merchant window the player opened
--                          ("30 Merchant's Favor"). Core/Sources.lua CostText words it together
--                          with price, so a mixed price reads "200 Merchant's Favor, 5g".
--   choice                 true on a quest reward the player picks one of. The items a quest
--                          requires are an AND group and carry nothing; the ones it offers as a
--                          choice say so, so a chain never reads as though all of them are yours.
--   basis                  what a PREDICTED edge is predicted from (Core/Confidence.lua
--                          BASIS_*). The disenchant results are worked out from item level and
--                          quality; a Classic Era source row is history. The tier says how far
--                          a fact is trusted and this says what kind of fact it is, which is
--                          what lets the Predicted badge explain itself in the right words.
--   note                   the qualifier a row's own words end with, where the section that
--                          raised it has one more thing to say about this particular source:
--                          "only while on a quest", "limited stock 5", the level band of the
--                          group a summary row stands for. Core/Sources.lua turns it into the
--                          row's line and Core/EraSources.lua is the only thing that sets it.
--   dedupeName             the name a provider's edge stands for, where the provider had no id
--                          to point at and made a node of its own. Such an edge is dropped when
--                          a live edge of the same type already names the same thing, which the
--                          key on key merge below cannot see. Only Core/EraSources.lua sets it.
--   historical             true on an edge that states what another game used to do rather than
--                          anything about this client (Core/EraSources.lua). It is only handed
--                          to a caller that asked for it, opts.includeHistorical: see the note
--                          over the provider loop.
--   summary                on an edge that stands for a GROUP of sources rather than for one of
--                          them: { item, category, listed }. Such a row is not a thing the
--                          window can open, so Core/ViewModel.lua never lets it re-root, and
--                          listed says how many further sources the section that raised it can
--                          hand over when the player asks for them (0 where it ships none).
--                          Only Core/EraSources.lua sets it.
--   creature               what KIND of creature the row names, where the section that raised it
--                          knows: { type, family, low, high }, plain ids and levels. The view
--                          model turns it into the row's icon key and Core/Sources.lua into the
--                          words its tooltip says. Only Core/EraSources.lua sets it.
--   community              on a shipped community row (brief M3, Core/Sources.lua Favour):
--                          { sources = { { url, date } }, faction, own }, the pages the row rests
--                          on for its hover, the vendor's side, and whether that is the player's
--                          own, which the Sources view sorts first. Only Favour sets it.
--   rank                   a shipped "Disenchanted from" edge's place in the order the Sources
--                          view sorts that group into (Data:DisenchantOrder). Set by the
--                          disenchant reverse below and never copied from a provider.
--   guess                  on a source ItemTree's model guessed (brief GS2, Core/GuessSources.lua):
--                          { level, strength, why, whyWords, area }. level is 1 the kind, 2 the
--                          place, 3 the specific source; strength 1 Strong or 2 Likely; why the
--                          code of the strategy that led it and whyWords its short name through
--                          the locale; area the area the guessed creature or vendor stands in,
--                          where the model states one. Such an edge is only handed to a walk that
--                          asked for guesses, opts.includeGuessSources, and Graph.GuessSurvives decides
--                          whether it stands beside the real edges. Only GuessSources sets it.
--   areaId                 the area a row's zone column names, where the section that raised it
--                          knows the id and not only the words, so the column links to that
--                          zone's page without matching the words back to an area.
--   title                  the title under the vendor's, trainer's or quest giver's name the edge
--                          points at ("Wrought Iron Supplies"), where the section that raised it
--                          knows one (brief T2b). Only Core/EraSources.lua sets it, from st.
--   faction                the side that vendor, trainer or quest giver serves: 1 Alliance, 2
--                          Horde, 3 both (brief T2b). Graph.FactionOnly reads it against the
--                          player's own side. Core/EraSources.lua sets it from cf, and (brief
--                          QN1) Core/PlayerSources.lua on a vendor row met in a place that
--                          proves the side (PlayerSources.SaleSide).
--   seenSide               brief QN1: 1 or 2, the side of the players who recorded a vendor row
--                          where nothing proves the side the vendor serves. UI/Tree.lua words it
--                          as "Seen by Alliance players"; it is never a faction. Only
--                          Core/PlayerSources.lua sets it.
--   classId                the class a class spell belongs to, as a ChrClasses id, 0 where
--                          several classes share it (brief P5b, Uses cs). Only REAGENT_FOR_SPELL
--                          carries it; Core/Keep.lua and UI/Tree.lua read it.
--   listed                 brief Q1: true on a Classic Era quest row (QUEST_OBJECTIVE or
--                          QUEST_REQUIRES) whose quest the Forever client's own tables list. It is
--                          the baseline tier rather than Predicted, and Core/ViewModel.lua draws no
--                          "not yet confirmed" mark or notice for it. Only Core/EraSources.lua sets it.
--   event                  brief Q1: the game event a Classic Era quest belongs to (EraSources qe);
--                          such a quest never keeps an item, and its Used by row says "Event".
--                          Only Core/EraSources.lua sets it.
--   rewardChanged          brief QB2: true on a Classic Era reward row (QUEST_REWARD or
--                          QUEST_REWARDS) whose quest hands over other rewards in Forever, this item
--                          not among them. Core/ViewModel.lua draws the Changed mark for it. Only
--                          Core/QuestFlags.lua MarkReward sets it. Brief QB2 also sets listed on a
--                          reward row the quest cache confirmed.
local EDGE_FIELDS = {
  "quantity",
  "quantityMax",
  "seen",
  "used",
  "percent",
  "percentSource",
  "meta",
  "zone",
  "skillLine",
  "provenance",
  "price",
  "cost",
  "choice",
  "basis",
  "note",
  "dedupeName",
  "historical",
  "summary",
  "creature",
  "community",
  "guess",
  "areaId",
  "title",
  "faction",
  "seenSide",
  "classId",
  -- Brief SET2: on a set member edge, the unnamed placeholder id folded into this named piece.
  "setTwin",
  -- Brief B7: a Classic Era pickpocket row, which only another pocket shadows (dropShadowed).
  "pocket",
  -- Brief B7: the Classic Era drop rate of a row this edge shadowed (Graph.AdoptSourceFacts).
  "eraRate",
  -- Brief EK1: a Classic Era creature or vendor with no page (Core/EraSources.lua CreatureNode):
  -- its row is drawn and opens nothing (UI/Tree.lua Tree.NoPage).
  "noPage",
  -- Brief Q1: a Classic Era quest row whose quest the Forever client lists (no Predicted mark, and
  -- Core/Keep.lua counts it), and the game event a quest belongs to (Core/EraSources.lua _MarkQuest).
  "listed",
  "event",
  -- Brief QB2: a Classic Era reward row whose quest the client's quest cache states other rewards
  -- for, and this item is not among them (Core/QuestFlags.lua MarkReward): the Changed mark.
  "rewardChanged",
  -- Brief GF6 (the owner's ruling of 2026-10-14, "Turn it on"): a predicted quest objective
  -- (Core/QuestsPredicted.lua EdgesFor), read as any quest use (its reason shows no mark: the owner's
  -- ruling). Brief RB1: every Predicted edge counts now; the mark is Core/Keep.lua's internal note.
  "predictedObjective",
}

-- The side words an edge's faction number stands for, by number. 3 is both and is no one's.
local FACTION_SIDES = { [1] = "Alliance", [2] = "Horde" }

-- Brief T2b: the one side an edge's source serves where the player's own side is not it, or nil.
-- playerSide is "Alliance" or "Horde" (UnitFactionGroup's own words); nil, or an edge with no
-- faction or faction 3, answers nil, because nothing is known to stand in the player's way. The
-- answer is the English side word, which is its own locale key; UI/Tree.lua says "Alliance only".
--
-- THE FACTION HOOK for Core/Keep.lua (brief T4): a use taught by a vendor or a trainer of the
-- other side is not current, and Keep reads that through this function on the teaching edge, so
-- the tree's "Alliance only" and Keep's answer can never disagree. Pure.
--
-- Brief FX14 (the QA page check of 2026-10-17): a row that names a quest (a quest reward on an
-- item's Sources tab) says the quest's side from the final lists, Graph.QuestSide (the shipped
-- alliance / horde lists, then the predicted side), never from the edge's faction: that is the
-- Classic Era table's own f, which still sided the quests ItemTree-Data's QS4 opened to both (the
-- owner's "if we're unsure show to both"), so A Thief's Reward 9339 read "Horde only" to the Alliance
-- on Crown of the Fire Festival 23323. A quest the lists side reads the same words without one. The
-- vendor, trainer and NPC rows keep their edge's faction.
function Graph.FactionOnly(edge, playerSide)
  if type(edge) ~= "table" or (playerSide ~= "Alliance" and playerSide ~= "Horde") then
    return nil
  end
  local side = FACTION_SIDES[edge.faction]
  if Graph.Kind(edge.target) == "quest" then
    side = FACTION_SIDES[Graph.QuestSide(nil, edge.target)]
  end
  if side == nil or side == playerSide then
    return nil
  end
  return side
end

-- Brief B7: the facts a Classic Era edge states about its SOURCE (where the creature, vendor or
-- quest giver stands, its side, its title, what kind of creature it is and its level band, and
-- the qualifier its row ends with), which a live edge naming the same source takes over where it
-- states none of its own. The drop rate is not one of them: it is a fact about the item, measured
-- in another game, and a player sourced row ships no rate (owner ruling 2026-10-02).
Graph.ADOPTED_SOURCE_FACTS = { "zone", "areaId", "faction", "title", "creature", "note" }

--- Folds the source facts of a historical edge into the live edge that shadows it: each field of
--- Graph.ADOPTED_SOURCE_FACTS the live edge leaves nil is copied over (a table is copied, so the
--- two never share one), and the historical edge's percent is kept as live.eraRate where the live
--- edge has none, for the row's tooltip, never as live.percent. Changes live only. Answers live.
function Graph.AdoptSourceFacts(live, era)
  if type(live) ~= "table" or type(era) ~= "table" then
    return live
  end
  for _, field in ipairs(Graph.ADOPTED_SOURCE_FACTS) do
    local value = era[field]
    if live[field] == nil and value ~= nil then
      if type(value) == "table" then
        local copy = {}
        for key, inner in pairs(value) do
          copy[key] = inner
        end
        value = copy
      end
      live[field] = value
    end
  end
  if live.eraRate == nil and type(era.percent) == "number" then
    live.eraRate = era.percent
  end
  return live
end

-- Brief BQ5: a player's gathering row now named from the Classic Era objects ("Silverleaf", "Copper
-- Vein") shadows the Classic Era node row of the same name, which is one row per NODE opening onto
-- the zones it stands in (Core/EraSources.lua E:NodeZones). The live row takes the node's key, so it
-- still opens onto those zones and its node page, rather than onto the bare object id it was recorded
-- by, which opens nothing. Only for a historical edge whose key the Classic Era reader answers zones
-- for; every other row keeps its own key. Changes live only. Answers live.
function Graph.AdoptNodeKey(live, era)
  if type(live) ~= "table" or type(era) ~= "table" or not era.historical then
    return live
  end
  local reader = ItemTree.eraSources
  if type(reader) ~= "table" or type(reader.NodeZones) ~= "function" or type(era.target) ~= "string" then
    return live
  end
  local ok, zones = pcall(reader.NodeZones, reader, era.target)
  if ok and type(zones) == "table" and #zones > 0 then
    live.recordedTarget = live.recordedTarget or live.target
    live.target = era.target
  end
  return live
end

-- Drops an edge that only says by name what another edge already says by key.
--
-- The merge below pairs two edges by their type and the node they point at, which is the whole
-- answer for every provider that has an id to point at. Core/EraSources.lua has none: the
-- shipped Classic Era table names a creature and a vendor and carries no NPC id anywhere, so
-- its rows point at nodes of its own making and the collector's sighting of that very creature
-- lands on a different key. Such an edge carries dedupeName, and this drops it where a live
-- edge of the SAME type already names the same thing. Live knowledge wins; a different name
-- stays, because both may be true.
--
-- Brief B7 (2026-10-03): the dropped edge is not simply lost. The live edge that shadows it
-- takes over the facts the historical edge states about the SOURCE where it states none of its
-- own (Graph.AdoptSourceFacts), so a player sourced row of a creature still says where the
-- creature stands, what kind it is and which side it serves. A Classic Era pickpocket row
-- (edge.pocket) is a different act from a drop, though both are filed under DROPPED_BY, so only
-- another pocket shadows it: since brief SK1, the player's own pickpocket record or a shipped
-- player pickpocket row of a creature of that name.
--
-- Run once, after every provider has been asked, so the answer does not depend on the order
-- they registered in. Nothing is built unless an edge carries a name to drop by, which is only
-- ever the historical ones.
local function shadowKey(edge, name)
  return edge.type.name .. "\0" .. (edge.pocket and "pocket" or "") .. "\0" .. name:lower()
end

-- Brief SK1: the key two provider edges are one source by: the type and the node, and a pickpocket
-- edge (edge.pocket, the player's own or a shipped player row since SK1) is never one source with
-- a drop of the same creature, though both are filed under DROPPED_BY.
local function mergeSlot(typeName, edge, target)
  -- Brief RB3: `target` is the edge's target folded (Graph.FoldTwinKey) where the caller folded it.
  return typeName .. "\0" .. (target or edge.target) .. (edge.pocket and "\0pocket" or "")
end

-- A live edge: one that names its source by key rather than by dedupeName. A guess names nothing
-- a player saw, so it is never one here.
local function isLive(edge)
  return type(edge) == "table" and type(edge.dedupeName) ~= "string" and edge.type ~= nil and edge.guess == nil
end

-- A Classic Era edge that says where its source stands.
local function isPlaced(edge)
  return edge.zone ~= nil or edge.areaId ~= nil
end

-- The key a placeless Classic Era row and a placed one of the same source share: the source's
-- name, the edge type and the qualifier the row ends with ("only on the quest ...").
local function twinKey(edge)
  return shadowKey(edge, edge.dedupeName) .. "\0" .. tostring(edge.note or "")
end

-- The first live edge of each name among edges, keyed by shadowKey.
local function liveByName(edges)
  local named = {}
  for _, other in ipairs(edges) do
    if isLive(other) and other.target then
      local name = Graph.Name(other.target)
      if type(name) == "string" and name ~= "" then
        local key = shadowKey(other, name)
        named[key] = named[key] or other
      end
    end
  end
  return named
end

-- QA 2026-10-10 item 26 (Water Pitcher, G7): the Classic Era table ships a source's spawns in the
-- areas this build names as one row per area and the spawns it names no area for as one more row
-- with no place, so a chest drew twice, once with its zone and once with none. The placeless row
-- says nothing the placed one does not, so it is dropped where a placed row of the same source and
-- qualifier stands beside it. Answers the set of twin keys that have a placed row among edges.
local function placedTwins(placed, edges)
  for _, edge in ipairs(edges) do
    if type(edge) == "table" and type(edge.dedupeName) == "string" and edge.type and edge.guess == nil then
      if isPlaced(edge) then
        local key = twinKey(edge)
        placed[key] = placed[key] or edge
      end
    end
  end
  return placed
end

-- Brief BQ25b (ruling Q3, carry across; owner QA 2026-10-10 item 73): a placeless Classic Era row
-- dropped for its placed twin hands its rate over where the placed row states none, so the rate is
-- not lost with the row. A placed row stating its own rate keeps it (each twin is its own object
-- with its own rate). Changes placed only. Answers placed.
local function carryTwinRate(placed, placeless)
  if type(placed) ~= "table" or type(placeless) ~= "table" then
    return placed
  end
  if placed.percent == nil and type(placeless.percent) == "number" then
    placed.percent = placeless.percent
  end
  return placed
end
Graph.CarryTwinRate = carryTwinRate

-- Brief TR1b (the owner's mine of 2026-10-11: his one recorded Battered Chest, object 106318,
-- folded all three of the Classic Era table's Battered Chest rows, Elwynn Forest, Durotar and
-- Westfall, into one Elwynn row). An object's name stands for many spawns, and the table names no
-- object id, so a recorded object row is the twin of ONE placed Classic Era row of its name: the
-- first, whose place it takes over (or its own place where it states one). A placed Classic Era row
-- of the same name in another place is another spawn and stands beside it, so the record adds to
-- the Classic Era zones rather than replacing them. True where edge is such a row for holder. Pure.
local function otherSpawn(holder, edge)
  if Graph.Kind(holder.target) ~= "object" or not isPlaced(edge) or not isPlaced(holder) then
    return false
  end
  if holder.areaId ~= nil and edge.areaId ~= nil then
    return holder.areaId ~= edge.areaId
  end
  return holder.zone ~= edge.zone
end
Graph.OtherSpawn = otherSpawn

-- One shadow pass over candidates. named holds the live edges a candidate may fold into, placed
-- the twin keys of the placed Classic Era rows. A folded live holder is recorded in adopted, and
-- takes a gathering node's key over only where moveKey is set (Graph.AdoptNodeKey). Answers the
-- candidates kept, in order.
local function shadowPass(candidates, named, placed, adopted, moveKey)
  local kept = {}
  for _, edge in ipairs(candidates) do
    local drop = false
    if type(edge) == "table" and type(edge.dedupeName) == "string" and edge.type then
      local holder = named[shadowKey(edge, edge.dedupeName)]
      if holder and otherSpawn(holder, edge) then
        holder = nil
      end
      if holder then
        Graph.AdoptSourceFacts(holder, edge)
        if moveKey then
          Graph.AdoptNodeKey(holder, edge)
        end
        adopted[holder] = true
        drop = true
      elseif edge.guess == nil and not isPlaced(edge) and placed[twinKey(edge)] then
        carryTwinRate(placed[twinKey(edge)], edge)
        drop = true
      end
    end
    if not drop then
      kept[#kept + 1] = edge
    end
  end
  return kept
end

-- Brief BQ5 names a recorded object from the Classic Era objects, so three recorded Copper Vein
-- ids (1731, 2055, 3763) all read "Copper Vein", and only the first took the Classic node over:
-- the other two drew beside it as bare rows (QA 2026-10-10 item 26 sweep). A recorded object row
-- that states no rate and no place of its own, named the same as a live row of the same type that
-- took a Classic Era row over, is that row again and is dropped. Answers the edges kept.
local function foldLiveTwins(edges, named, adopted)
  local kept = {}
  for _, edge in ipairs(edges) do
    local drop = false
    if isLive(edge) and edge.percent == nil and not isPlaced(edge) and Graph.Kind(edge.target) == "object" then
      local name = Graph.Name(edge.target)
      local holder = type(name) == "string" and name ~= "" and named[shadowKey(edge, name)] or nil
      drop = holder ~= nil and holder ~= edge and adopted[holder] == true
    end
    if not drop then
      kept[#kept + 1] = edge
    end
  end
  return kept
end

local function dropShadowed(out)
  local any = false
  for _, edge in ipairs(out) do
    if type(edge.dedupeName) == "string" and edge.type then
      any = true
      break
    end
  end
  if not any then
    return
  end
  local named = liveByName(out)
  local adopted = {}
  local kept = shadowPass(out, named, placedTwins({}, out), adopted, true)
  if next(adopted) then
    kept = foldLiveTwins(kept, named, adopted)
  end
  if #kept == #out then
    return
  end
  for index = 1, #out do
    out[index] = kept[index]
  end
end

-- The same rule for the rest of a summary's list (Core/EraSources.lua E:MoreEdges), which the graph
-- never sees: a Classic Era table caps a category at three named rows and keeps the rest behind a
-- summary row, so a vendor or a creature it lists only there was never shadowed by the live row
-- that names it, and an opened "Show 101 vendors" drew Alexandra Bolero a second time under Coarse
-- Thread (QA 2026-10-10 item 26; 862 vendor, 67 creature and 17 object rows over the data). list
-- is the decoded list, live the edges drawn beside the summary. Answers a new list without the
-- edges a live edge of the same type already names, which take their source facts over
-- (Graph.AdoptSourceFacts), and without a placeless row whose placed twin stands in the list or
-- beside it. The live edge's key is left as it is: its row is already drawn, and a key that moved
-- would close it. Pure.
function Graph.DropShadowedList(list, live)
  if type(list) ~= "table" then
    return {}
  end
  live = type(live) == "table" and live or {}
  local placed = placedTwins(placedTwins({}, live), list)
  return shadowPass(list, liveByName(live), placed, {}, false)
end

-- The other half of the placeless rule for a summary's list: a placeless Classic Era row drawn
-- among the named rows whose placed twin is in the opened list (a Battered Chest with no zone over
-- "Show 12 more" holding its Darkshore and Westfall rows). Answers a set of those sibling edges,
-- keyed by the edge, or nil where there are none. Pure.
function Graph.PlacelessTwinsOf(siblings, list)
  if type(siblings) ~= "table" or type(list) ~= "table" then
    return nil
  end
  local placed = placedTwins({}, list)
  local twins = nil
  for _, edge in ipairs(siblings) do
    if
      type(edge) == "table"
      and type(edge.dedupeName) == "string"
      and edge.type
      and edge.guess == nil
      and not isPlaced(edge)
      and placed[twinKey(edge)]
    then
      carryTwinRate(placed[twinKey(edge)], edge)
      twins = twins or {}
      twins[edge] = true
    end
  end
  return twins
end

-- Brief GS2: which guesses stand beside the real edges of an item.
--
-- A guess (an edge carrying guess, Core/GuessSources.lua) is never a data row of its own and
-- never overwrites a real source. After every provider has answered, each guess is weighed against
-- the real (non guess) edges of the same item, one family of source at a time, and dropped where
-- real data already says as much or more. Nothing compares sentences: the one place a words match
-- is needed (a collected row's zone), the caller hands in areaOf, which is an exact table lookup
-- (Core/EraSources.lua E:AreaIdOf, the same one the zone column links through).
--
-- Each edge type a source can be filed under belongs to a family. The first five are the ones a
-- guess can be of; the last two are real sources no guess is ever of, which count as "another
-- family has a real source" and nothing more.
Graph.GUESS_FAMILIES = {
  DROPPED_BY = "drop",
  SOLD_BY = "vendor",
  QUEST_REWARD = "quest",
  QUEST_PROVIDED = "quest",
  CONTAINED_IN = "container",
  LOOTED_FROM = "container",
  GATHERED_FROM = "gathered",
  FISHED_FROM = "gathered",
  SKINNED_FROM = "gathered",
  PRODUCED_BY = "crafted",
  DISENCHANTED_FROM = "disenchant",
}

-- The guess levels, which are also how far a real edge narrows its family's source (K):
-- 0 nothing, 1 the kind only, 2 a place, 3 a specific source.
Graph.GUESS_KIND, Graph.GUESS_PLACE, Graph.GUESS_SPECIFIC = 1, 2, 3

-- The strength a guess is shown alone at, beside a real source of another family.
local STRONG = 1

local function familyOf(edge)
  local def = type(edge) == "table" and edge.type or nil
  return def and Graph.GUESS_FAMILIES[def.name] or nil
end

-- How far one real edge narrows its family's source.
--
--   1  a row that stands for a group and names nothing: the Classic Era world drop (a summary of
--      category "world"), and a summary from the client's own data with nothing listed behind it,
--      which is brief V1's "Sold by a vendor (not yet named by the client)".
--   2  a row that names a place and no source in it: its target is a zone node.
--   3  anything else, which names a creature, a vendor, a quest, an object or an item, including
--      a Classic Era summary, which stands for sources the table does name.
function Graph.RealLevel(edge)
  local summary = type(edge) == "table" and edge.summary or nil
  if type(summary) == "table" then
    if summary.category == "world" then
      return 1
    end
    if not edge.historical and (tonumber(summary.listed) or 0) == 0 then
      return 1
    end
    return 3
  end
  if Graph.Kind(edge and edge.target) == "zone" then
    return 2
  end
  return 3
end

-- The area a real edge states: its own areaId, else its zone words matched by areaOf, else nil.
local function realArea(edge, areaOf)
  local areaId = tonumber(edge.areaId)
  if areaId then
    return areaId
  end
  if type(areaOf) == "function" and type(edge.zone) == "string" and edge.zone ~= "" then
    local ok, found = pcall(areaOf, edge.zone)
    if ok and type(found) == "number" then
      return found
    end
  end
  return nil
end

-- The name a real edge stands for, lower cased, for the "same creature" test.
local function realName(edge)
  if type(edge.dedupeName) == "string" then
    return edge.dedupeName:lower()
  end
  local name = Graph.Name(edge.target)
  if type(name) == "string" and name ~= "" then
    return name:lower()
  end
  return nil
end

-- What the rules read about one guess against the real edges of its item. Pure.
function Graph.GuessFacts(guess, realEdges, areaOf)
  local facts = {
    family = familyOf(guess),
    level = 0,
    strong = false,
    k = 0,
    otherReal = false,
    several = false,
    sameName = false,
    ownArea = nil,
    rowWithoutArea = false,
    areaStated = false,
    eraBeside = false,
    placed = false,
  }
  local g = type(guess) == "table" and guess.guess or nil
  if type(g) ~= "table" or not facts.family then
    return facts
  end
  facts.level = tonumber(g.level) or 0
  facts.strong = g.strength == STRONG
  -- Brief M14: a placed object (Core/GuessSources.lua specific type 6, which carries guess.placed).
  facts.placed = type(g.placed) == "table"
  facts.ownArea = tonumber(g.area)
  local guessName = type(guess.dedupeName) == "string" and guess.dedupeName:lower() or nil
  local creature = facts.family == "drop"
    and facts.level == Graph.GUESS_SPECIFIC
    and guessName ~= nil
    and Graph.Kind(guess.target) == "npc"
  local named = {}
  for _, edge in ipairs(realEdges or EMPTY) do
    local family = edge.guess == nil and familyOf(edge) or nil
    if family == facts.family then
      local level = Graph.RealLevel(edge)
      if level > facts.k then
        facts.k = level
      end
      if guessName and edge.type == guess.type then
        local name = realName(edge)
        if name then
          named[name] = true
        end
      end
      -- The rows rule 5 weighs: the real drops that name their source.
      if creature and level == Graph.GUESS_SPECIFIC then
        if edge.historical then
          facts.eraBeside = true
        end
        local area = realArea(edge, areaOf)
        if not area then
          facts.rowWithoutArea = true
        elseif area == facts.ownArea then
          facts.areaStated = true
        end
      end
    elseif family then
      facts.otherReal = true
    end
  end
  facts.sameName = guessName ~= nil and named[guessName] == true
  facts.several = creature and facts.k == Graph.GUESS_SPECIFIC
  return facts
end

-- The rules, in the order they are asked; the first whose test holds decides. Each row names the
-- rule of the plan it implements (guesses-in-sources-plan.md section 2) so a spec can say which
-- one fired. show is true, false, or a test of its own.
Graph.GUESS_RULES = {
  -- A real row of the same type already names the same creature or vendor.
  {
    rule = "same name",
    test = function(f)
      return f.sameName
    end,
    show = false,
  },
  -- Rule 5, several creatures: a guessed creature beside real drops that name theirs stands only
  -- where it can be shown to be somewhere else.
  {
    rule = "5, a real row states no area",
    test = function(f)
      return f.several and f.rowWithoutArea
    end,
    show = false,
  },
  {
    rule = "5b, the guess states no area",
    test = function(f)
      return f.several and not f.ownArea
    end,
    show = false,
  },
  {
    rule = "5c, a real row states the area",
    test = function(f)
      return f.several and f.areaStated
    end,
    show = false,
  },
  {
    rule = "5, beside Classic Era rows only Strong",
    test = function(f)
      return f.several and f.eraBeside and not f.strong
    end,
    show = false,
  },
  {
    rule = "5, several creatures",
    test = function(f)
      return f.several
    end,
    show = true,
  },
  -- Rules 1 and 2: the same family, weighed by how far real data narrows it.
  {
    rule = "1, more specific than real data",
    test = function(f)
      return f.k > 0 and f.level > f.k
    end,
    show = true,
  },
  {
    rule = "2, real data says as much",
    test = function(f)
      return f.k > 0
    end,
    show = false,
  },
  -- Rule 3: nothing real in this family and something real in another.
  -- Brief M14: a placed object stands here at any strength. The pipeline's contract (docs/guesses.md,
  -- "Specific type 6, placed object") ships it Likely and never shadowed, because the object is
  -- another source even where real data sources the item. A real Contained in row (the player's
  -- own record of opening it, or shipped data) is the same family, so rule 2 above still lets it
  -- replace the guess.
  {
    rule = "3, another family, Strong only",
    test = function(f)
      return f.otherReal
    end,
    show = function(f)
      return f.strong or f.placed
    end,
  },
  -- Rule 4: no real source at all.
  {
    rule = "4, no real source",
    test = function()
      return true
    end,
    show = true,
  },
}

--- Whether one guess edge stands beside an item's real edges, and the rule that said so. Pure:
--- realEdges is the item's own list (guesses in it are skipped), areaOf an optional exact lookup
--- from a zone's words to its area id. A guess of no family never stands.
function Graph.GuessSurvives(guess, realEdges, areaOf)
  local facts = Graph.GuessFacts(guess, realEdges, areaOf)
  if not facts.family or facts.level < Graph.GUESS_KIND then
    return false, "no family"
  end
  for _, row in ipairs(Graph.GUESS_RULES) do
    if row.test(facts) then
      local show = row.show
      if type(show) == "function" then
        show = show(facts)
      end
      return show == true, row.rule
    end
  end
  return false, "none"
end

-- The area lookup the post pass hands the rules: the Classic Era table's own name to id map,
-- read at call time so this file loads without it, and nil where it is absent.
local function eraAreaOf()
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.AreaIdOf) ~= "function" then
    return nil
  end
  return function(name)
    return era:AreaIdOf(name)
  end
end

--- The post pass over one item's edge list (brief GS2): every guess that does not survive the
--- rules is removed in place, and of the guesses of one family that do, only the most specific
--- level stays (rule 0: a guess's own creature says more than its own place, which says more than
--- its kind). Real edges are never touched. Nothing is built for a list that holds no guess.
function Graph.DropGuessEdges(out, areaOf)
  local any = false
  for _, edge in ipairs(out) do
    if edge.guess ~= nil then
      any = true
      break
    end
  end
  if not any then
    return out
  end
  areaOf = areaOf or eraAreaOf()
  local real = {}
  for _, edge in ipairs(out) do
    if edge.guess == nil then
      real[#real + 1] = edge
    end
  end
  local keep, best = {}, {}
  for index, edge in ipairs(out) do
    if edge.guess ~= nil and Graph.GuessSurvives(edge, real, areaOf) then
      keep[index] = true
      local family = familyOf(edge)
      local level = tonumber(edge.guess.level) or 0
      if level > (best[family] or 0) then
        best[family] = level
      end
    end
  end
  for index = #out, 1, -1 do
    local edge = out[index]
    if edge.guess ~= nil then
      local level = tonumber(edge.guess.level) or 0
      if not keep[index] or level < (best[familyOf(edge)] or 0) then
        table.remove(out, index)
      end
    end
  end
  return out
end

-- Brief DV1: whether an item id is one no player can ever get (Data:IsHidden, one read of the
-- Diff module's dev set). False wherever Core/Data.lua cannot say.
function Graph.IsUnobtainable(itemId)
  if type(Data) ~= "table" or type(Data.IsHidden) ~= "function" then
    return false
  end
  return Data:IsHidden(itemId) == true
end

-- Whether an edge's target is such an item. Only an "item:" key is read, so any other target
-- costs one byte compare.
local function unobtainableTarget(target)
  if type(target) ~= "string" or target:byte(1) ~= 105 or target:sub(1, 5) ~= "item:" then
    return false
  end
  return Graph.IsUnobtainable(tonumber(target:sub(6)))
end

-- Brief CH1 (owner QA 2026-10-18 item 249, Horn of the Red Wolf's "No chain from this item"; ruling
-- A, "Forever data is important and so is the functionality"): the Classic Era rows a chain steps
-- through, which are a quest's: the quest an item is asked for by (QUEST_OBJECTIVE), what a quest
-- asks for (QUEST_REQUIRES), the quest an item comes from (QUEST_REWARD) and what a quest hands over
-- (QUEST_REWARDS). A quest the Forever client lists reads as its baseline (Core/EraSources.lua
-- E:_MarkQuest) and one it does not as Predicted, with its badge (the standing rule "Predicted is
-- our data", brief RB1): the brief's own Wolf Swapping 7661 is one the client does not list. A
-- drop, a vendor, a pickpocket, a zone and a quest giver stay rows in a tree and never steps.
-- Brief NX1 (the owner's ruling "2A" of 2026-10-22): and the quest that hands an item over when it is taken
-- (QUEST_PROVIDED, the Classic Era table's qp), which a Predicted "Provided by quest" step already was before
-- the pipeline held those claims for the Era rows: the Soul Gem's chain still opens on Saving Yenniku.
Graph.CHAIN_QUEST_TYPES = {
  QUEST_OBJECTIVE = true,
  QUEST_REQUIRES = true,
  QUEST_REWARD = true,
  QUEST_REWARDS = true,
  QUEST_PROVIDED = true,
}

--- Brief CH1: whether a chain walk takes one historical edge: a Classic Era quest row of
--- Graph.CHAIN_QUEST_TYPES. Never a summary row ("Show 7 more", which names no quest) and never a
--- reward the client's quest cache says the quest no longer hands over (rewardChanged, brief QB2),
--- which is no route in Forever. Every other edge answers false. Pure.
function Graph.ChainQuestEdge(edge)
  if type(edge) ~= "table" or not edge.historical or edge.summary ~= nil or edge.rewardChanged then
    return false
  end
  local def = edge.type
  return type(def) == "table" and Graph.CHAIN_QUEST_TYPES[def.name] == true
end

-- Collects the edges leaving a node in one direction. firstOnly stops at the first
-- section that produced an edge, which is what Graph.HasChildren uses so a collapsed row
-- can draw a chevron without building the whole child list.
-- Brief Q10: defined below providerEdges, which it reads. See the note over it.
local dropRestatedRequirements

-- Brief RPAR (the owner's ruling Q1 of 2026-10-09: "event quests (AQ War Effort, holidays) NEVER keep an
-- item and show an Event tag"): a game event's quest a record of ours asks an item for is the event's all
-- the same. Its live QUEST_OBJECTIVE row takes the Classic Era row's place (the merge, or
-- dropRestatedRequirements) without the event and the "Event" tag Core/EraSources.lua E:_MarkQuest puts on
-- that row, so the players' record of Hallow's End Treats for Jesper! (8311) drew Ironforge Mint's (20490)
-- Used by row untagged; it gets them here. Only on an item's DOWN walk and only while ItemTree_Data is
-- loaded (as Graph.EraEventQuestNeeds): one table read per quest row.
local function markEventQuests(out, kind, direction)
  if kind ~= "item" or direction ~= Edges.DOWN or #out == 0 or not Data:OnDemandLoaded() then
    return
  end
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.QuestEvent) ~= "function" then
    return
  end
  for _, edge in ipairs(out) do
    if edge.event == nil and edge.type and edge.type.name == "QUEST_OBJECTIVE" then
      local _, questId = Graph.Parse(edge.target)
      questId = tonumber(questId)
      if questId then
        local asked, event = pcall(era.QuestEvent, era, questId)
        if asked and event ~= nil then
          edge.event = event
          edge.meta = edge.meta or L["Event"]
        end
      end
    end
  end
end

local function collectEdges(key, direction, opts, firstOnly)
  opts = opts or EMPTY
  local out = {}
  local kind, id = Graph.Parse(key)
  if not kind then
    return out
  end
  -- Brief DV1: an item no player can get has no predicted sources (the Sources view then says
  -- what it says for an item with no data), and it is never a row under anything: a recipe whose
  -- only product is such an item keeps its own row and simply has no product row under it.
  local noPredicted = kind == "item" and direction == Edges.UP and Graph.IsUnobtainable(id)

  local function emit(def, target, fields)
    if not def or def.dir ~= direction or not target then
      return
    end
    -- Brief RB3: a dead twin quest's edge is its live quest's; brief RB3b, with the live quest's side.
    local live = Graph.FoldTwinKey(target)
    if live ~= target then
      target = live
      fields = fields and withoutTwinSide(fields) or nil
    end
    fields = fields or EMPTY
    local confidence = fields.confidence or SOURCE_CONFIDENCE[def.source] or Confidence.MINED
    if opts.showPredicted == false and confidence == Confidence.PREDICTED then
      return
    end
    if noPredicted and confidence == Confidence.PREDICTED then
      return
    end
    -- Brief GS2: a guess goes with the predictions it sits below, with its own setting, and with
    -- an item no player can get, exactly the way a Predicted edge does above.
    if confidence == Confidence.GUESS then
      if opts.showPredicted == false or opts.showGuessSources == false or noPredicted then
        return
      end
    end
    if unobtainableTarget(target) then
      return
    end
    local edge = {
      type = def,
      target = target,
      confidence = confidence,
      group = fields.group or def.label,
    }
    for _, field in ipairs(EDGE_FIELDS) do
      edge[field] = fields[field]
    end
    out[#out + 1] = edge
  end

  local function done()
    return firstOnly and #out > 0
  end

  if kind == "item" then
    local item = Data:GetItem(id)
    local uses = Data:GetUses(id) or EMPTY
    if direction == Edges.DOWN then
      for _, spell in ipairs(uses.r or EMPTY) do
        local recipe = Data:GetRecipe(spell)
        emit(T.REAGENT_FOR, Graph.Key("spell", spell), {
          quantity = recipe and reagentCount(recipe, id) or nil,
          group = recipeGroup(recipe, T.REAGENT_FOR.label),
          skillLine = recipe and recipe.sl or nil,
        })
      end
      -- Brief P5b: the class spells that consume this item, filed under the same "Reagent for"
      -- category a recipe with no profession would be. A count of one is the ordinary case and
      -- the column says nothing for it; a spell that eats two says "x2".
      for _, row in ipairs(uses.cs or EMPTY) do
        local spell, classId, count = row[1], row[2], row[3]
        if type(spell) == "number" then
          local quantity = nil
          if type(count) == "number" and count > 1 then
            quantity = count
          end
          emit(T.REAGENT_FOR_SPELL, Graph.Key("spell", spell), {
            quantity = quantity,
            classId = tonumber(classId) or 0,
          })
        end
      end
      if done() then
        return out
      end
      for _, spell in ipairs(uses.t or EMPTY) do
        local taught = Data:GetRecipe(spell)
        emit(T.TEACHES, Graph.Key("spell", spell), {
          group = L["Teaches"],
          skillLine = taught and taught.sl or nil,
        })
      end
      for _, lockbox in ipairs(uses.k or EMPTY) do
        emit(T.OPENS, Graph.Key("item", lockbox), { group = L["Opens"] })
      end
      if done() then
        return out
      end
      if item and item.sq then
        emit(T.STARTS_QUEST, Graph.Key("quest", item.sq), { group = L["Quests"] })
      end
      if item and item.set then
        emit(T.PART_OF_SET, Graph.Key("set", item.set), { group = L["Item set"] })
      elseif item and item.u then
        -- A withheld item's stub states no set of its own, and 2,225 of build 1.60.1.69913's
        -- withheld ids are named by an ItemSet row, so the set's own member list is walked
        -- back. Only ever asked for a stub, so nothing else pays for the index.
        for _, setId in ipairs(Data:SetsForItem(id)) do
          emit(T.PART_OF_SET, Graph.Key("set", setId), { group = L["Item set"] })
        end
      end
      -- Every recipe that asks for this item as a tool, whether the recipe named the item's
      -- totem category or the item itself. Core/Data.lua's ToolRecipes walks both ways back and
      -- answers each recipe once, so an item with no totem category, such as Flint and Tinder,
      -- reaches its recipes and a recipe that states both ways is still one row.
      for _, tool in ipairs(Data:ToolRecipes(id)) do
        local needs = Data:GetRecipe(tool.spell)
        local meta = nil
        if tool.category then
          meta = Data:GetTotemCategoryName(tool.category)
        end
        emit(T.TOOL_FOR, Graph.Key("spell", tool.spell), {
          meta = meta,
          group = L["Tool for"],
          skillLine = needs and needs.sl or nil,
        })
      end
      if done() then
        return out
      end
      local band = Data:DisenchantBand(item)
      for _, result in ipairs(band and band.out or EMPTY) do
        emit(T.DISENCHANTS_INTO, Graph.Key("item", result[1]), {
          percent = (result[2] or 0) * 100,
          quantity = result[3],
          quantityMax = result[4],
          confidence = Confidence.PREDICTED,
          basis = Confidence.BASIS_DISENCHANT,
          group = L["Disenchants into"],
        })
      end
    else
      for _, spell in ipairs(uses.p or EMPTY) do
        local recipe = Data:GetRecipe(spell)
        local output = recipe and recipe.out or nil
        emit(T.PRODUCED_BY, Graph.Key("spell", spell), {
          quantity = output and output[2] or nil,
          quantityMax = output and output[3] or nil,
          group = recipeGroup(recipe, T.PRODUCED_BY.label),
          skillLine = recipe and recipe.sl or nil,
        })
      end
      if done() then
        return out
      end
      for _, keyItem in ipairs(item and item.keys or EMPTY) do
        emit(T.OPENED_BY, Graph.Key("item", keyItem), { group = L["Opened by"] })
      end
      if done() then
        return out
      end
      -- Where a crystal, a dust or an essence comes from. The generated Disenchant module
      -- only states the forward bands, so the reverse is Data:DisenchantSources, which is
      -- built from those same bands and only for an item the module names as a material.
      -- The edge is predicted, exactly as the DISENCHANTS_INTO edge on the other side is.
      --
      -- Brief P2: a cheap test stops at the first source rather than walking every one (a shard
      -- has 2,530), and the full list reads each source's facts from Data:DisenchantOrder, built
      -- once per material. The edges keep the order they always had (by id), and each carries
      -- rank, its place in the order the Sources view sorts the group into, so the view can lay
      -- the group out without sorting it (Core/ViewModel.lua VM:_SortEntries). rank is only
      -- stamped where that order is exact.
      local order = not firstOnly and Data:DisenchantOrder(id) or nil
      local byId = order and order.byId or EMPTY
      for _, sourceId in ipairs(Data:DisenchantSources(id)) do
        local facts = byId[sourceId]
        if facts then
          -- The memo's own facts table carries every field emit reads (Data:DisenchantOrder), so
          -- no fields table and no key string is made per source.
          if not facts.key then
            facts.key = Graph.Key("item", sourceId)
            facts.confidence = Confidence.PREDICTED
            facts.basis = Confidence.BASIS_DISENCHANT
            facts.group = L["Disenchanted from"]
          end
        else
          local source = Data:GetItem(sourceId)
          local result = disenchantResult(Data:DisenchantBand(source), id)
          facts = {
            key = Graph.Key("item", sourceId),
            percent = result and (result[2] or 0) * 100 or nil,
            quantity = result and result[3] or nil,
            quantityMax = result and result[4] or nil,
            confidence = Confidence.PREDICTED,
            basis = Confidence.BASIS_DISENCHANT,
            group = L["Disenchanted from"],
          }
        end
        local before = #out
        emit(T.DISENCHANTED_FROM, facts.key, facts)
        if #out > before and order and order.exact and facts.rank then
          out[#out].rank = facts.rank
        end
        if done() then
          return out
        end
      end
    end
  elseif kind == "spell" then
    local recipe = Data:GetRecipe(id)
    if recipe then
      if direction == Edges.DOWN then
        if recipe.out and recipe.out[1] then
          emit(T.CREATES, Graph.Key("item", recipe.out[1]), {
            quantity = recipe.out[2],
            quantityMax = recipe.out[3],
          })
        end
        if recipe.en then
          emit(T.ENCHANTS, Graph.Key("enchant", recipe.en))
        end
      else
        local asked = {}
        for _, reagent in ipairs(recipe.re or EMPTY) do
          asked[reagent[1]] = true
          emit(T.REAGENT, Graph.Key("item", reagent[1]), {
            quantity = reagent[2],
            group = L["Reagents"],
          })
        end
        -- The item an item combine is cast by USING. The build states it in via and only
        -- sometimes repeats it under SpellReagents: 262 of the 358 combines in 1.60.1.69913
        -- list no reagents at all, and without this every one of them is a dead end walking up,
        -- with the item you actually have to use appearing nowhere (Dim Torch answered "Produced
        -- by, Light Torch" and never named the Unlit Poor Torch). The 96 that do state it keep
        -- the one row they already had, with the count the recipe gave it.
        for _, viaItem in ipairs(recipe.via or EMPTY) do
          if not asked[viaItem] then
            asked[viaItem] = true
            emit(T.REAGENT, Graph.Key("item", viaItem), {
              group = L["Reagents"],
              meta = L["Used"],
              used = true,
            })
          end
        end
        if done() then
          return out
        end
        for _, source in ipairs(recipe.by or EMPTY) do
          emit(T.TAUGHT_BY, Graph.Key("item", source), { group = L["Taught by"] })
        end
        -- A recipe nothing teaches is learnt from a trainer. No build states that outright, so
        -- the absence of a teaching item is the fact the row is read from: 693 of the 2,549
        -- recipes in build 1.60.1.69913 have no scroll, and without this their Sources tab
        -- would be empty. It points at the profession, which is what a player goes looking for.
        --
        -- Asked for rather than always emitted, the way the profession edge above is: it ends on
        -- a skill, and a skill is not a step between two items, so a walk that reads the graph as
        -- a chain (Core/Chain.lua) must not be handed one. The tree asks; nothing else does.
        --
        -- Brief P6b: the trainers themselves come from the shipped Classic Era table's tr list
        -- (Core/EraSources.lua TrainerEdges), as LEARNED_FROM_TRAINER rows of the same "Trainer"
        -- group pointing at each trainer's creature node, so they sit beside this row. This row
        -- stays: it is the summary where no trainer is known (every recipe Forever added), and a
        -- walk that did not ask for history sees it alone.
        if opts.includeTrainer and recipe.sl and not (recipe.by and recipe.by[1]) then
          emit(T.LEARNED_FROM_TRAINER, Graph.Key("skill", recipe.sl), {
            group = L["Trainer"],
            skillLine = recipe.sl,
          })
        end
        -- Tools stated by totem category, then tools stated as the exact item. A build states a
        -- recipe's tools either way and sometimes both, so the items already named by a category
        -- are remembered and the same tool is never drawn twice.
        local named = {}
        for _, category in ipairs(recipe.tools or EMPTY) do
          local tools = Data:ItemsWithTotemCategory(category)
          local tool = tools and tools[1]
          if tool and not named[tool] then
            named[tool] = true
            emit(T.REQUIRES_TOOL, Graph.Key("item", tool), {
              meta = Data:GetTotemCategoryName(category),
              group = L["Tools"],
              skillLine = recipe.sl,
            })
          end
        end
        for _, tool in ipairs(recipe.toolItems or EMPTY) do
          if not named[tool] then
            named[tool] = true
            emit(T.REQUIRES_TOOL, Graph.Key("item", tool), {
              group = L["Tools"],
              skillLine = recipe.sl,
            })
          end
        end
        if opts.includeSkill and recipe.sl then
          emit(T.BELONGS_TO_SKILL, Graph.Key("skill", recipe.sl), {
            group = skillGroup(recipe.sl, T.BELONGS_TO_SKILL.label),
            skillLine = recipe.sl,
          })
        end
      end
    end
  elseif kind == "set" then
    local set = Data:GetSet(id)
    -- Brief SET2: with Merge recipes on, an unnamed member with exactly one named twin is drawn
    -- as that twin's row (Graph.SetTwins), here and so in the tree, the chain and Used by alike.
    local byNamed, byPlaceholder = EMPTY, EMPTY
    if set and Graph.FoldsSetTwins(opts) then
      byNamed, byPlaceholder = Graph.SetTwins(id)
    end
    for _, member in ipairs(set and set.items or EMPTY) do
      if not byPlaceholder[member] then
        emit(T.SET_MEMBER, Graph.Key("item", member), { group = L["Item set"], setTwin = byNamed[member] })
      end
    end
  end

  if done() then
    return out
  end

  -- Provider edges come last and are merged rather than appended: the collector and an adapter
  -- in Providers/ can both name the same creature for the same item, and a player should see
  -- that source once. Two edges are the same source when they are the same edge type pointing
  -- at the same node, and the more trusted confidence wins, so the collector's verified sighting
  -- keeps its place and the imported duplicate is dropped. The index is built on first use, so
  -- a node with no providers pays nothing for this.
  -- A historical edge is asked for rather than always handed over, exactly the way the trainer
  -- edge above is. The shipped Classic Era table states what another game used to do, so a drop
  -- or a vendor row through it is not a route a player can walk, and a walk that reads the graph
  -- as a chain (Core/Chain.lua) would put a guess at the head of one and lengthen every path it
  -- touched. The views ask for every row (Core/ViewModel.lua WALK_OPTS). Brief CH1 (owner QA
  -- 2026-10-18 item 249, ruling A): a chain asks for the quest rows alone
  -- (opts.includeEraQuests, Graph.ChainQuestEdge), so an item a Classic quest asks for steps
  -- through that quest to what it hands over.
  local emitted
  local function merge(edge)
    local def = edge.type
    if not def or def.dir ~= direction or not edge.target then
      return
    end
    if edge.historical and not opts.includeHistorical then
      if not (opts.includeEraQuests and Graph.ChainQuestEdge(edge)) then
        return
      end
    end
    -- Brief GS2: a guess is a row in the Sources view and never a step in a chain, so it is only
    -- handed to a walk that asked for guesses, the way a historical edge is above.
    if edge.guess ~= nil and not opts.includeGuessSources then
      return
    end
    if not emitted then
      emitted = {}
      for index = 1, #out do
        emitted[mergeSlot(out[index].type.name, out[index])] = index
      end
    end
    -- Brief RB3: merged on the folded target, so a dead twin's edge and its live quest's are one.
    -- Brief RB3b: a folded twin's edge goes on without the twin's side (`fields`), on every path.
    local target = Graph.FoldTwinKey(edge.target)
    local fields = target ~= edge.target and withoutTwinSide(edge) or edge
    local slot = mergeSlot(def.name, edge, target)
    local at = emitted[slot]
    local before = #out
    if not at then
      emit(def, target, fields)
      if #out > before then
        emitted[slot] = #out
      end
      return
    end
    local confidence = edge.confidence or SOURCE_CONFIDENCE[def.source] or Confidence.MINED
    local held = out[at]
    if Confidence.Rank(confidence) <= Confidence.Rank(held.confidence) then
      -- Brief B7: a Classic Era edge that loses to a live edge on the same key still hands over
      -- what it states about the source (the quest's side, the creature's place). Brief RB3b: a
      -- folded twin's edge never hands over the twin's side.
      if edge.historical and not held.historical then
        Graph.AdoptSourceFacts(held, fields)
      end
      return
    end
    -- Emitted and then moved into the loser's slot, so the row keeps the position it already
    -- had and only the facts behind it change.
    emit(def, target, fields)
    if #out > before then
      out[at] = out[#out]
      out[#out] = nil
      if held.historical and not out[at].historical then
        Graph.AdoptSourceFacts(out[at], held)
      end
    end
  end

  for _, provider in ipairs(providers) do
    -- A provider of guesses alone is not even asked by a walk that did not ask for guesses, so a
    -- chain, a tooltip count or a nested row never pays for its lookup.
    if opts.includeGuessSources or not guessOnly[provider] then
      local edges = provider(key, direction)
      for _, edge in ipairs(edges or EMPTY) do
        merge(edge)
      end
      if done() then
        return out
      end
    end
  end
  dropShadowed(out)
  dropRestatedRequirements(out, kind)
  markEventQuests(out, kind, direction)
  if opts.includeGuessSources then
    Graph.DropGuessEdges(out)
  end
  return out
end

-- Edges leaving a node in one direction. opts.includeSkill adds the recipe's profession edge,
-- opts.includeTrainer adds the trainer edge for a recipe no item teaches,
-- opts.includeHistorical adds the shipped Classic Era rows, opts.includeEraQuests (brief CH1) only
-- their quest rows (Graph.ChainQuestEdge), and opts.showPredicted = false
-- drops predicted edges, which the Era rows are. opts.includeGuessSources (brief GS2) adds the guessed
-- sources, shadowed by the real edges beside them (Graph.DropGuessEdges); only the Sources view's
-- walk of its own root sets it, and opts.showGuessSources = false drops them again.
-- Brief F155: opts.hideSide ("Alliance" or "Horde", the character's side while "Hide other faction
-- data" is on) leaves out what the other side owns (Graph.WithoutOtherSide). The views' walks
-- (Core/ViewModel.lua) and, since brief CH1, a chain's (Core/Chain.lua) state it, after every merge
-- and shadow, so a row keeps the side a Classic Era row handed it; Keep's own walks never do.
local function sidedEdges(key, direction, opts, firstOnly)
  local trace = ItemTree.openTrace
  local out
  if trace then
    out = trace.Span("graph", nil, collectEdges, key, direction, opts, firstOnly)
  else
    out = collectEdges(key, direction, opts, firstOnly)
  end
  local side = type(opts) == "table" and opts.hideSide or nil
  if side == nil or #out == 0 then
    return out
  end
  local kept = Graph.WithoutOtherSide(out, side)
  -- A chevron test stopped at the first edge, which was hidden: the whole list answers it.
  if firstOnly and #kept == 0 then
    kept = Graph.WithoutOtherSide(collectEdges(key, direction, opts, false), side)
  end
  return kept
end

function Graph.Children(key, direction, opts)
  -- Brief PF1: summed while /itprobe open traces an open; one table read otherwise.
  return sidedEdges(key, direction, opts, false)
end

-- Cheap "is there anything under this row" test. Stops at the first edge, so a collapsed
-- row never pays for the whole child list.
function Graph.HasChildren(key, direction, opts)
  return #sidedEdges(key, direction, opts, true) > 0
end

-- Only the provider (collector, curated and installed addon) edges, used by Summary. The same
-- source named twice counts once, the way it is drawn once in the tree: see the merge in
-- collectEdges, which this follows so a tooltip count and the window never disagree.
--
-- A predicted provider edge is not read here: a provider of Predicted edges alone is never asked
-- (brief U3: the Classic Era table would load the data addon on every tooltip). Brief RB1 (the owner's
-- standing rule of 2026-10-17, "Predicted IS our data"): the Predicted QUESTS are no longer left out
-- of the counts for it. Graph.Summary reads them with readers of their own that load nothing
-- (Graph.EraQuestNeeds, Graph.PredictedQuestNeeds, Graph.PredictedRewardQuests), the rule this
-- comment used to state ("an item whose only quest is a Classic Era row must not read 1 quest")
-- being the one the owner overturned.
local function providerEdges(key, direction)
  local out, at = {}, {}
  for _, provider in ipairs(providers) do
    -- A provider of Predicted edges alone has nothing this could keep, so it is not asked.
    local answer = not predictedOnly[provider] and not guessOnly[provider] and provider(key, direction) or EMPTY
    for _, edge in ipairs(answer) do
      if
        edge.confidence ~= Confidence.PREDICTED
        and edge.guess == nil
        and edge.type
        and edge.type.dir == direction
        and edge.target
      then
        -- Brief RB3: a dead twin quest's edge counts as its live quest's (a copy: the provider's own
        -- edge is never changed).
        local target = Graph.FoldTwinKey(edge.target)
        if target ~= edge.target then
          -- Brief RB3b: with the live quest's side, never the twin's (Graph.Summary's sides).
          edge = withoutTwinSide(edge)
          edge.target = target
        end
        local slot = mergeSlot(edge.type.name, edge)
        local held = at[slot]
        if not held then
          out[#out + 1] = edge
          at[slot] = #out
        elseif Confidence.Rank(edge.confidence) > Confidence.Rank(out[held].confidence) then
          out[held] = edge
        end
      end
    end
  end
  return out
end

-- Whether anything this client trusts states one quest's requirements: a curated quest
-- (Core/Quests.lua) or one the collector watched handed in, either of which answers QUEST_REQUIRES
-- walking up from the quest. providerEdges asks no provider of predicted or guessed edges alone,
-- so the shipped Classic Era table is never asked about itself.
local function statesRequirements(questKey)
  for _, edge in ipairs(providerEdges(questKey, Edges.UP)) do
    if edge.type.name == "QUEST_REQUIRES" then
      return true
    end
  end
  return false
end

-- Brief Q10: a quest's requirements come from ONE place. Classic Era's qr says what a quest asked
-- for in another game; the curated table and the collector say what it asks for here, and where
-- either states that quest's requirements at all, the whole of the Era answer about that quest
-- goes, not only the rows the merge above pairs by key. So:
--   on a quest, a historical QUEST_REQUIRES edge goes when any other QUEST_REQUIRES edge is there;
--   on an item, a historical QUEST_OBJECTIVE edge goes when that quest's requirements are stated
--   by a trusted provider, which is one providerEdges call per Era quest the item is asked for by
--   (a handful at most), and only for an item that has such an edge.
-- Nothing is asked for a node with no historical quest edge, so every other walk pays nothing.
dropRestatedRequirements = function(out, kind)
  if kind ~= "item" and kind ~= "quest" then
    return
  end
  local live, asked = nil, nil
  for index = #out, 1, -1 do
    local edge = out[index]
    local name = edge.historical and edge.type and edge.type.name or nil
    local drop = false
    if kind == "quest" and name == "QUEST_REQUIRES" then
      if live == nil then
        live = false
        for _, other in ipairs(out) do
          if not other.historical and other.type and other.type.name == "QUEST_REQUIRES" then
            live = true
            break
          end
        end
      end
      drop = live
    elseif kind == "item" and name == "QUEST_OBJECTIVE" then
      asked = asked or {}
      local stated = asked[edge.target]
      if stated == nil then
        stated = statesRequirements(edge.target)
        asked[edge.target] = stated
      end
      drop = stated
    end
    if drop then
      table.remove(out, index)
    end
  end
end

-- What a node asks of the player, as rows the Requires view draws above the edges: an item's
-- level, profession and class, and a recipe's own skill line and rank.
--
-- A quest is not answered here. The curated table states its name, the items it asks for (which
-- are QUEST_REQUIRES edges and rows of their own) and where it is handed in, and no build states
-- a level or a class for one, so there is nothing to say that the edges do not already say.
function Graph.Requirements(key)
  local out = {}
  local kind, id = Graph.Parse(key)
  if kind == "spell" then
    -- Worded exactly the way Graph.SpellInfo words skillText, so the tree row and the info
    -- column never disagree about the rank a recipe asks for.
    local recipe = Data:GetRecipe(id)
    local label = recipe and recipe.sl and Graph.SkillLabel(recipe.sl, recipe.r) or nil
    if label then
      out[#out + 1] = { label = label, kind = "skill" }
    end
    return out
  end
  if kind ~= "item" then
    return out
  end
  local item = Data:GetItem(id)
  if not item then
    return out
  end
  if item.rl and item.rl > 0 then
    out[#out + 1] = { label = string.format(L["Level %d"], item.rl), kind = "level" }
  end
  if item.sk then
    out[#out + 1] = { label = Graph.SkillLabel(item.sk, item.skr), kind = "skill" }
  end
  -- A mask that names every playable class restricts nothing, and 801 items in build
  -- 1.60.1.69913 carry one, so the rows would say "Warrior, Paladin, Hunter..." nine times over
  -- and push everything else behind a "Show 2 more". Only a mask that leaves a class out is a
  -- requirement worth a row.
  local classes = Graph.ClassNames(item.ac)
  if #classes < Graph.ClassCount() then
    for _, class in ipairs(classes) do
      out[#out + 1] = { label = class, kind = "class" }
    end
  end
  return out
end

-- Everything the info column draws for a spell, as a plain table, or nil when nothing on this
-- client names the spell or states a recipe for it. Pure: the description is not here, because
-- only the running client knows it, so UI/ adds that line itself.
--
-- combine is true for an item combine, which has no profession at all, and via is
-- { { itemId, name } }, the items whose own use effect casts it; the column draws that as
-- "Used from: Eye of Sulfuras" where a profession recipe draws "Profession: Blacksmithing".
--
-- reagents is { { itemId, name, count } }, tools is { { category, name, itemId } } where itemId
-- is the first item that carries the tool category and may be nil, creates is
-- { itemId, name, min, max } or nil, enchant is { id, name } or nil, and taughtBy is the item
-- ids that teach it. requiredSkill is the rank the recipe needs, which is nil when the build
-- never stated one, and trainerTaught is true when the rank came from a trainer ability, false
-- when it came from the recipe item, and nil when the build says neither.
function Graph.SpellInfo(spellId)
  if type(spellId) ~= "number" then
    return nil
  end
  local key = Graph.Key("spell", spellId)
  local recipe = Data:GetRecipe(spellId)
  local name = Graph.Name(key)
  if not recipe and not name then
    return nil
  end
  recipe = recipe or EMPTY

  local info = {
    id = spellId,
    key = key,
    name = name,
    title = Graph.Title(key),
    icon = recipeIcon(recipe),
    skillLine = recipe.sl,
    skillName = recipe.sl and Data:GetSkillName(recipe.sl) or nil,
    requiredSkill = recipe.r,
    skillText = recipe.sl and Graph.SkillLabel(recipe.sl, recipe.r) or nil,
    cooldown = recipe.cd,
    reagents = {},
    tools = {},
    taughtBy = {},
    changes = {},
    new = false,
    changed = false,
    -- An item combine: no profession, and the items whose use casts it, which is what the
    -- column says in place of the profession line. Empty for everything else.
    combine = recipe.src == "item",
    via = Graph.CombineVia(recipe),
  }

  for _, reagent in ipairs(recipe.re or EMPTY) do
    info.reagents[#info.reagents + 1] = {
      itemId = reagent[1],
      name = itemName(reagent[1]) or Graph.Fallback("item", reagent[1]),
      count = reagent[2] or 1,
    }
  end

  -- Tools by totem category first, then the ones the recipe names as exact items, which carry no
  -- category at all and are called by the item's own name. An item already named by a category is
  -- listed once.
  local namedTools = {}
  for _, category in ipairs(recipe.tools or EMPTY) do
    local tools = Data:ItemsWithTotemCategory(category)
    local tool = tools and tools[1] or nil
    if tool then
      namedTools[tool] = true
    end
    info.tools[#info.tools + 1] = {
      category = category,
      name = Data:GetTotemCategoryName(category),
      itemId = tool,
    }
  end
  for _, tool in ipairs(recipe.toolItems or EMPTY) do
    if not namedTools[tool] then
      namedTools[tool] = true
      info.tools[#info.tools + 1] = {
        category = nil,
        name = itemName(tool) or Graph.Fallback("item", tool),
        itemId = tool,
      }
    end
  end

  if recipe.out and recipe.out[1] then
    info.creates = {
      itemId = recipe.out[1],
      name = itemName(recipe.out[1]) or Graph.Fallback("item", recipe.out[1]),
      min = recipe.out[2] or 1,
      max = recipe.out[3] or recipe.out[2] or 1,
    }
  end

  if recipe.en then
    local enchant = Data:GetEnchant(recipe.en)
    info.enchant = { id = recipe.en, name = enchant and enchant.n or Graph.Fallback("enchant", recipe.en) }
  end

  for _, taught in ipairs(recipe.by or EMPTY) do
    info.taughtBy[#info.taughtBy + 1] = taught
  end

  if recipe.rs == "ability" then
    info.trainerTaught = true
  elseif recipe.rs == "item" then
    info.trainerTaught = false
  end

  -- Diff loads after Graph, so it is read at call time rather than held as an upvalue.
  local Diff = ItemTree.Diff
  if Diff then
    info.new = Diff.IsNew("recipes", spellId)
    info.changed = Diff.IsChanged("recipes", spellId)
    info.changes = Diff.ChangeLines("recipes", spellId)
  end
  return info
end

local function countOf(list)
  return list and #list or 0
end

--------------------------------------------------------------------------------
-- Brief BQ5: the professions of an item's recipes and the listed Classic quests that ask for it,
-- for the uses line ("Made by [icon] Alchemy", "Used in 1 First Aid recipe", "1 quest"). Read off
-- the core set's Summary module while ItemTree_Data is not loaded (the pipeline works them out from
-- the same tables, build_summary in ItemTree-Data's compile_lua.py), and off the loaded tables after
-- that. The two must agree; tests/spec/load_on_demand_spec.lua holds them to it.
--------------------------------------------------------------------------------

-- Whether a sorted list of ids holds one id. Pure.
local function inSortedIds(list, id)
  local low, high = 1, type(list) == "table" and #list or 0
  while low <= high do
    local mid = math.floor((low + high) / 2)
    local at = list[mid]
    if at == id then
      return true
    elseif type(at) ~= "number" or at < id then
      low = mid + 1
    else
      high = mid - 1
    end
  end
  return false
end

-- { { line = skill line, count = n, name = profession name or nil }, ... } out of a flat
-- { line, count, line, count, ... }, most recipes first as shipped. names is skill line -> name.
local function skillPairs(flat, names)
  local out = {}
  for at = 1, #flat - 1, 2 do
    local line, count = tonumber(flat[at]) or 0, tonumber(flat[at + 1]) or 0
    if count > 0 then
      out[#out + 1] = { line = line, count = count, name = line > 0 and names[line] or nil }
    end
  end
  return out
end

-- Sorts skill entries the way the pipeline ships them (recipe_lines): most recipes first, then by
-- skill line.
local function bySkillCount(a, b)
  if a.count ~= b.count then
    return a.count > b.count
  end
  return a.line < b.line
end

--- The professions of an item's recipes of one kind ("p" the recipes that make it, "r" the ones
--- that use it) out of the Summary module, as Graph.RecipeSkills answers them, or nil where the
--- module ships none (a build compiled before brief BQ5). count is the item's Uses list length.
function Graph.SummarySkills(summary, itemId, kind, count)
  if type(summary) ~= "table" or count <= 0 then
    return nil
  end
  local single = kind == "p" and summary.mk or summary.us
  local mixed = kind == "p" and summary.mkx or summary.usx
  if type(single) ~= "table" or type(mixed) ~= "table" then
    return nil
  end
  local names = type(summary.sk) == "table" and summary.sk or EMPTY
  local flat = mixed[itemId]
  if type(flat) == "table" then
    return skillPairs(flat, names)
  end
  for line, ids in pairs(single) do
    if inSortedIds(ids, itemId) then
      return { { line = line, count = count, name = names[line] } }
    end
  end
  return {}
end

--- Brief BQ14 (the owner's QA items 14 and 43, 2026-10-10): the qualities of the items an item's
--- use recipes make, by profession, out of the Summary module's uq (the pipeline's
--- use_quality_masks): { [skill line] = mask }, bit q set (mask % 2^(q+1) >= 2^q) where one of that
--- profession's recipes using the item makes an item of quality q. A us item's uq is one number for
--- its one line; a usx item's a list parallel to its {line, count, ...} pairs. nil where the module
--- ships none (a build compiled before BQ14) or names no quality for the item. Read at login and
--- after alike: Summary.lua is in the core set. Pure over the summary handed in.
function Graph.UseQualities(summary, itemId)
  if type(summary) ~= "table" or type(summary.uq) ~= "table" then
    return nil
  end
  local held = summary.uq[itemId]
  if held == nil then
    return nil
  end
  local out = {}
  if type(held) == "number" then
    for line, ids in pairs(type(summary.us) == "table" and summary.us or EMPTY) do
      if type(ids) == "table" and inSortedIds(ids, itemId) then
        out[tonumber(line) or 0] = held
        return out
      end
    end
    return nil
  end
  local flat = type(summary.usx) == "table" and summary.usx[itemId] or nil
  if type(held) ~= "table" or type(flat) ~= "table" then
    return nil
  end
  for at = 1, #flat - 1, 2 do
    local line, mask = tonumber(flat[at]) or 0, tonumber(held[(at + 1) / 2]) or 0
    if mask > 0 then
      out[line] = mask
    end
  end
  return next(out) ~= nil and out or nil
end

-- A skill line's name from the loaded Skills table, or nil where it names none (Data:GetSkillName
-- answers "Skill 40" for those, which is no profession's name).
local function loadedSkillName(line)
  if line <= 0 or type(Data.GetSkill) ~= "function" then
    return nil
  end
  local skill = Data:GetSkill(line)
  local name = type(skill) == "table" and skill.n or nil
  if type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

--- The same answer off the loaded recipe tables: each recipe's skill line (sl, 0 for an item
--- combine or a spell the tables do not hold), counted. Pure over the data tables.
function Graph.RecipeSkills(spells)
  local counts, out = {}, {}
  for _, spell in ipairs(type(spells) == "table" and spells or EMPTY) do
    local recipe = Data:GetRecipe(spell)
    local line = type(recipe) == "table" and tonumber(recipe.sl) or 0
    counts[line] = (counts[line] or 0) + 1
  end
  for line, count in pairs(counts) do
    out[#out + 1] = { line = line, count = count, name = loadedSkillName(line) }
  end
  table.sort(out, bySkillCount)
  return out
end

-- The named entries of a skills answer, or nil where none is named.
local function namedSkills(skills)
  if type(skills) ~= "table" then
    return nil
  end
  local out = {}
  for _, entry in ipairs(skills) do
    if type(entry.name) == "string" then
      out[#out + 1] = entry
    end
  end
  return #out > 0 and out or nil
end

-- Whether a Classic quest's need counts (the filter Core/Keep.lua's Keep.Uses applies): it is no
-- reputation turn in and no game event's quest. Brief RB1 (the owner's standing rule of 2026-10-17,
-- "Predicted IS our data"): listed or not, where before only a quest the client lists counted; an
-- unlisted one only once the data judges it (Core/QuestFlags.lua Unjudged, as Keep.QuestUnjudged).
-- era is the Classic Era reader (Core/EraSources.lua), read only while ItemTree_Data is loaded.
local function countedEraQuest(questId, era)
  local flags = ItemTree.QuestFlags
  if type(flags) ~= "table" then
    return false
  end
  -- Brief RB1b (the owner's answer of 2026-10-17 on item 190, "B but make repeatable quests never
  -- relevant"): a reputation turn in counts here now, so the page's count matches the Used by rows;
  -- Graph.Summary counts it apart too (questRepeats) and the tooltip folds it, and Keep never keeps
  -- for it. Before, a turn in was left out of every count.
  if type(flags.Unjudged) == "function" and flags.Unjudged(questId) == true then
    return false
  end
  if era and type(era.QuestEvent) == "function" then
    local ok, event = pcall(era.QuestEvent, era, questId)
    if ok and event ~= nil then
      return false
    end
  end
  return true
end

--- The Classic quests that ask for an item, quest id ascending: the Summary module's qn (glance,
--- Data:Glance's answer for the id: its own half, or the Classic Era half where that row is served)
--- while ItemTree_Data is not loaded, else the Classic Era table's qr (Core/EraSources.lua RequiredBy)
--- with the same filter. Either way only for an item the data serves (no stub of a harvested item the
--- setting hides), and only quests that are no event's and no reputation turn in. Brief RB1: listed
--- or not (countedEraQuest; it was Graph.ListedQuestNeeds, the listed ones alone). The module's qn
--- holds the unlisted quests from the compile with RB1's pipeline change, the one that judges them.
function Graph.EraQuestNeeds(itemId, glance)
  local out = {}
  if glance then
    if not glance.named then
      return out
    end
    local summary = Data:Get("Summary")
    local half = glance.era and type(summary) == "table" and summary.era or summary
    local needs = type(half) == "table" and type(half.qn) == "table" and half.qn[itemId] or nil
    if type(needs) == "number" then
      needs = { needs }
    end
    for _, questId in ipairs(type(needs) == "table" and needs or EMPTY) do
      if countedEraQuest(questId, nil) then
        out[#out + 1] = questId
      end
    end
    return out
  end
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.RequiredBy) ~= "function" then
    return out
  end
  if type(Data.HarvestMasked) == "function" and Data:HarvestMasked(itemId) then
    return out
  end
  if type(era._Unlocked) == "function" and not era:_Unlocked(itemId) then
    return out
  end
  local ok, entries = pcall(era.RequiredBy, era, itemId)
  for _, entry in ipairs(ok and type(entries) == "table" and entries or EMPTY) do
    if countedEraQuest(entry.quest, era) then
      out[#out + 1] = entry.quest
    end
  end
  return out
end

-- Brief EQ1 (the owner's ruling A of 2026-10-18 on QA item 233, "Add them to the summary line as well
-- so they're consistent"): the Classic quests tied to a game event (the Classic Era table's qe: the AQ
-- War Effort, a holiday, the Darkmoon Faire) that ask for an item, quest id ascending: the ones
-- Graph.EraQuestNeeds leaves out and the Used by tab lists (Core/EraSources.lua E:_MarkQuest's "Event"
-- rows, Copper Bar's The Alliance Needs Copper Bars!). Graph.Summary counts them so the item page's
-- summary line holds every quest Used by lists, and counts them apart (questEvents) so the tooltip
-- leaves them out as before; Keep never keeps for them (Keep.QuestNeverKeeps). Only while ItemTree_Data
-- is loaded: the core set's Summary module, all a tooltip reads before that (Graph.Summary's glance),
-- lists no event quest. The same guards as Graph.EraQuestNeeds, and an unjudged quest stays out as
-- there (countedEraQuest).
function Graph.EraEventQuestNeeds(itemId)
  local out = {}
  local era = ItemTree.eraSources
  if not Data:OnDemandLoaded() or type(era) ~= "table" or type(era.RequiredBy) ~= "function" then
    return out
  end
  if type(era.QuestEvent) ~= "function" then
    return out
  end
  if type(Data.HarvestMasked) == "function" and Data:HarvestMasked(itemId) then
    return out
  end
  if type(era._Unlocked) == "function" and not era:_Unlocked(itemId) then
    return out
  end
  local flags = ItemTree.QuestFlags
  local unjudged = type(flags) == "table" and flags.Unjudged or nil
  local ok, entries = pcall(era.RequiredBy, era, itemId)
  for _, entry in ipairs(ok and type(entries) == "table" and entries or EMPTY) do
    local asked, event = pcall(era.QuestEvent, era, entry.quest)
    if asked and event ~= nil and not (type(unjudged) == "function" and unjudged(entry.quest) == true) then
      out[#out + 1] = entry.quest
    end
  end
  return out
end

-- Brief INT14 (HF1's invariant over GF6, 2026-10-17): the new Forever quests whose predicted
-- objectives ask for an item, the quest needs Core/Keep.lua counts since GF6 (the owner's ruling of
-- 2026-10-14, "Turn it on"), quest id ascending: Core/QuestsPredicted.lua ObjectiveOf, never loading
-- ItemTree_Data (nothing until the module is registered, as Keep.Score answers nothing until then),
-- less a quest that never keeps an item (Keep.QuestNeverKeeps, which Keep.Uses leaves out too).
-- Graph.Summary counts them so the item page's count and the tooltip's uses line hold the quests the
-- Keep block counts. Pure over the shipped tables.
function Graph.PredictedQuestNeeds(itemId)
  local out = {}
  local predicted = ItemTree.QuestsPredicted
  local id = tonumber(itemId)
  if not id or type(predicted) ~= "table" or type(predicted.ObjectiveOf) ~= "function" then
    return out
  end
  local ok, needs = pcall(predicted.ObjectiveOf, id, false)
  local keep = ItemTree.Keep
  local neverKeeps = type(keep) == "table" and keep.QuestNeverKeeps or nil
  for _, need in ipairs(ok and type(needs) == "table" and needs or EMPTY) do
    local questId = type(need) == "table" and tonumber(need.quest) or nil
    local skip = false
    if questId and type(neverKeeps) == "function" then
      local asked, never = pcall(neverKeeps, questId)
      skip = asked and never == true
    end
    if questId and not skip then
      out[#out + 1] = questId
    end
  end
  return out
end

-- Brief RB1 (the owner's standing rule of 2026-10-17, "Predicted IS our data"): the new Forever quests
-- whose predicted rewards hand an item over (Core/QuestsPredicted.lua RewardOf, the Sources tab's
-- Predicted quest rows), quest id ascending as the module lists them, never loading ItemTree_Data.
-- Graph.Summary counts them with the quests the item comes from, as it counts a recorded reward.
-- Pure over the shipped tables.
-- Brief IC1: and, after them, the quests the predicted item sources say hand it over (Core/ItemsPredicted.lua
-- RewardQuests, the Sources tab's Predicted "Quests" rows of an item page's own claim), each quest once.
function Graph.PredictedRewardQuests(itemId)
  local out, seen = {}, {}
  local id = tonumber(itemId)
  if not id then
    return out
  end
  local function take(module, method)
    if type(module) ~= "table" or type(module[method]) ~= "function" then
      return
    end
    local ok, quests = pcall(module[method], id, false)
    for _, questId in ipairs(ok and type(quests) == "table" and quests or EMPTY) do
      questId = tonumber(questId)
      if questId and questId > 0 and not seen[questId] then
        seen[questId] = true
        out[#out + 1] = questId
      end
    end
  end
  take(ItemTree.QuestsPredicted, "RewardOf")
  take(ItemTree.ItemsPredicted, "RewardQuests")
  return out
end

-- Brief PV1 (the owner's QA item 375, Alexston's Reply on Making Do): the new Forever quests that hand
-- an item over at accept (Core/QuestsPredicted.lua ProvidedBy, the Sources tab's Predicted "Provided by
-- quest" rows), quest id ascending as the module lists them, never loading ItemTree_Data. Graph.Summary
-- counts each like a quest the item comes from, once, where nothing above counted that quest already.
-- Brief IC1 (the owner's ruling "2B" of 2026-10-23): and, after them, the quests the predicted item
-- sources say hand it over when taken (Core/ItemsPredicted.lua ProvidedBy), each quest once.
-- Pure over the shipped tables.
function Graph.PredictedProvidedQuests(itemId)
  local out, seen = {}, {}
  local id = tonumber(itemId)
  if not id then
    return out
  end
  for _, module in ipairs({ ItemTree.QuestsPredicted, ItemTree.ItemsPredicted }) do
    if type(module) == "table" and type(module.ProvidedBy) == "function" then
      local ok, quests = pcall(module.ProvidedBy, id, false)
      for _, questId in ipairs(ok and type(quests) == "table" and quests or EMPTY) do
        questId = tonumber(questId)
        if questId and questId > 0 and not seen[questId] then
          seen[questId] = true
          out[#out + 1] = questId
        end
      end
    end
  end
  return out
end

-- Brief NX1 (the owner's ruling "2A" of 2026-10-22, the Classic Era provided items): the Classic Era quests
-- that hand an item over when taken (Core/EraSources.lua E:ProvidedBy: the table's qp, less a quest the
-- item itself starts), the Sources tab's Classic Era "Provided by quest" rows, quest id ascending. As
-- Graph.EraQuestNeeds reads qr: nothing while only the glance is at hand (ItemTree_Data not loaded, so a
-- login tooltip never loads it), nor for an item the harvest setting masks or whose details are withheld.
-- Graph.Summary counts each like a quest the item comes from, once, where nothing above counted that quest.
-- Pure over the shipped table.
function Graph.EraProvidedQuests(itemId, glance)
  local out = {}
  local reader = ItemTree.eraSources
  local id = tonumber(itemId)
  if glance or not id or type(reader) ~= "table" or type(reader.ProvidedBy) ~= "function" then
    return out
  end
  if type(Data.HarvestMasked) == "function" and Data:HarvestMasked(id) then
    return out
  end
  if type(reader._Unlocked) == "function" and not reader:_Unlocked(id) then
    return out
  end
  local ok, quests = pcall(reader.ProvidedBy, reader, id)
  for _, questId in ipairs(ok and type(quests) == "table" and quests or EMPTY) do
    questId = tonumber(questId)
    if questId and questId > 0 then
      out[#out + 1] = questId
    end
  end
  return out
end

-- Brief IW1 (QH1's hand-overs on the item page, the owner's QA item 375): the quests the records say hand
-- an item over at the accept or mid quest (Core/PlayerSources.lua ItemProvidedQuests: the player's own
-- records, then the ones the shipped module states, read only where the module is built), quest id
-- ascending. The player module's provider, which draws them as "Provided by quest" rows, is marked so
-- that Graph.Summary never asks it, and a recorded hand-over holds the predicted provided item of the
-- same quest in the pipeline (ItemTree-Data compile_lua._provided_ours), so without this the item
-- page's count would lose the quest the Sources tab still lists. Empty while ItemTree_Data is not
-- loaded (Graph.Summary's glance). Pure over the shipped tables and the player's own records.
function Graph.RecordedProvidedQuests(itemId)
  local out = {}
  local module = ItemTree.PlayerSources
  local id = tonumber(itemId)
  if
    not id
    or type(module) ~= "table"
    or type(module.ItemProvidedQuests) ~= "function"
    or not Data:OnDemandLoaded()
  then
    return out
  end
  local ok, list = pcall(module.ItemProvidedQuests, id)
  local seen = {}
  for _, entry in ipairs(ok and type(list) == "table" and list or EMPTY) do
    local questId = type(entry) == "table" and tonumber(entry.questId) or nil
    if questId and questId > 0 and not seen[questId] then
      seen[questId] = true
      out[#out + 1] = questId
    end
  end
  table.sort(out)
  return out
end

-- Brief CT1b (QA item 228, Wool Cloth "Used in 14 recipes, 4 quests" over Used by's Quests (5) and
-- the Keep block's "5 quests"): the quests the player module states ask for an item
-- (Core/PlayerSources.lua ItemQuestNeeds), quest id ascending. The Used by tab and Keep read them
-- through the graph; Graph.Summary asks no provider marked predictedOnly (providerEdges), and the
-- player module's provider is marked so that a tooltip never loads it, so its quests went uncounted:
-- A Donation of Wool 99191 on Wool Cloth. Read only where the module is built (it is never built
-- here), and empty while ItemTree_Data is not loaded (Graph.Summary's glance). Pure over the shipped
-- tables.
function Graph.PlayerQuestNeeds(itemId)
  local out = {}
  local module = ItemTree.PlayerSources
  local id = tonumber(itemId)
  if not id or type(module) ~= "table" or type(module.ItemQuestNeeds) ~= "function" or not Data:OnDemandLoaded() then
    return out
  end
  local ok, needs = pcall(module.ItemQuestNeeds, id)
  local seen = {}
  for _, questId in ipairs(ok and type(needs) == "table" and needs or EMPTY) do
    questId = tonumber(questId)
    if questId and questId > 0 and not seen[questId] then
      seen[questId] = true
      out[#out + 1] = questId
    end
  end
  table.sort(out)
  return out
end

-- Brief QS1 (the owner's ruling A of 2026-10-14): the side a quest is for, 1 Alliance, 2 Horde, or
-- nil (both sides, or nobody states one): faction where it is 1 or 2 (3 is both), else the side the
-- client's listing gives the quest key's id (Core/QuestFlags.lua Side), as Core/Keep.lua reads a
-- quest use's side. Pure over the shipped listing.
-- Brief HF1 of 2026-10-23 (QA item 406): the shipped lists first. For a quest they speak for
-- (Graph.ListsSpeakFor) faction is not read: their side, else the predicted side, else open to both,
-- leaning or not (a lean never hides). faction stands only for a quest they say nothing about, so a
-- Classic Era f on an edge never hides a quest ItemTree-Data opened to both, such as CX1's paladin
-- and shaman class quests.
function Graph.QuestSide(faction, questKey)
  faction = tonumber(faction)
  if faction ~= nil and Graph.ListsSpeakFor(questKey) then
    faction = nil
  end
  if faction == 1 or faction == 2 then
    return faction
  end
  if faction == 3 or type(questKey) ~= "string" then
    return nil
  end
  local flags = ItemTree.QuestFlags
  if type(flags) ~= "table" or type(flags.Side) ~= "function" then
    return nil
  end
  local kind, id = Graph.Parse(questKey)
  if kind ~= "quest" or tonumber(id) == nil then
    return nil
  end
  id = tonumber(id)
  local ok, side = pcall(flags.Side, id)
  if ok and (side == 1 or side == 2) then
    return side
  end
  return Graph.UnlistedQuestSide(id)
end

--- Brief HF1 (item 406): whether the shipped quest lists speak for the side of the quest a key names
--- (Core/QuestFlags.lua SpeaksFor), so an edge's own faction gives way to them. False for a key that
--- names no quest and while the lists are not loaded. Guarded; pure over the shipped listing.
function Graph.ListsSpeakFor(questKey)
  local flags = ItemTree.QuestFlags
  if type(questKey) ~= "string" or type(flags) ~= "table" or type(flags.SpeaksFor) ~= "function" then
    return false
  end
  local kind, id = Graph.Parse(questKey)
  if kind ~= "quest" or tonumber(id) == nil then
    return false
  end
  local ok, speaks = pcall(flags.SpeaksFor, tonumber(id))
  return ok and speaks == true
end

-- Brief HF1 (owner QA 2026-10-17 item 181): the side of a quest the client's listing does not side,
-- so every surface Graph.QuestSide serves (the Used by rows "Hide other faction data" hides, their
-- "Horde only" words, Graph.Summary's sides) reads the same answer: a new Forever quest's predicted
-- side (Core/QuestsPredicted.lua Facts, the gap fill's module, the side Core/Keep.lua Keep.QuestSide
-- reads since brief GF6), where that module is loaded; 3 (both) answers nil. Never loads the data
-- addon for it. nil otherwise: open to both sides (the owner's "if we're unsure show to both").
-- Brief RP14 (2026-10-17): HF1's second fallback, the side every Classic Era giver of a quest the
-- client does not list stands on, is gone. ItemTree-Data's QS4 (its rule 7) now puts those sides in
-- the shipped lists itself (the Horde capitals' "Additional Runecloth" repeats 7819, 7825, 7832 and
-- 7837 are Horde there) and leaves 17 open on purpose, which the fallback sided again: 7660 to 7665
-- and 7671 to 7678 (a claim of both sides), 3645 (a race mask of both sides), 8228 and 8229 (a race
-- mask of the other side). QS4 also withholds the predicted side of every quest it opens. Guarded.
function Graph.UnlistedQuestSide(questId)
  local id = tonumber(questId)
  if id == nil then
    return nil
  end
  local predicted = ItemTree.QuestsPredicted
  if type(predicted) == "table" and type(predicted.Facts) == "function" then
    local ok, facts = pcall(predicted.Facts, id, false)
    local side = ok and type(facts) == "table" and tonumber(facts.side) or nil
    if side == 1 or side == 2 then
      return side
    end
  end
  return nil
end

-- Brief QS2b (QS2's rule 2): the one side players were SEEN taking a quest on (Core/QuestFlags.lua
-- SeenSide), 1 Alliance or 2 Horde, or nil: an edge that states a side (1, 2 or 3 both), a quest
-- Graph.QuestSide sides, or one nobody was seen taking on one side alone. It only takes the quest out
-- of the other side's counts (Graph.Summary's questSeenSides): Graph.HidesEdge and the "Alliance
-- only" words read Graph.QuestSide alone, so a seen quest is never hidden or worded. Pure over the
-- shipped listing. Brief AT2 of 2026-10-24: unlike Graph.QuestSide, an edge's side does NOT give way
-- to the lists here (brief HF1 made it, item 406): the owner's QS2b ruling of 2026-10-14 reads a seen
-- side only for a quest nothing else sides, so an edge stating 1, 2 or 3 reads none, as before HF1.
function Graph.QuestSeenSide(faction, questKey)
  faction = tonumber(faction)
  if faction == 1 or faction == 2 or faction == 3 or type(questKey) ~= "string" then
    return nil
  end
  if Graph.QuestSide(nil, questKey) ~= nil then
    return nil
  end
  local flags = ItemTree.QuestFlags
  if type(flags) ~= "table" or type(flags.SeenSide) ~= "function" then
    return nil
  end
  local kind, id = Graph.Parse(questKey)
  if kind ~= "quest" or tonumber(id) == nil then
    return nil
  end
  local ok, side = pcall(flags.SeenSide, tonumber(id))
  if ok and (side == 1 or side == 2) then
    return side
  end
  return nil
end

-- Brief RB2 (owner QA 2026-10-17 item 194, "are we able to mark items as possibly horde only if we're
-- showing them to the opposite faction?"): the side a quest open to both sides leans to in our own
-- data (Core/QuestFlags.lua Lean, ItemTree-Data RB3's leanAlliance / leanHorde), 1 or 2, or nil: a
-- quest Graph.QuestSide sides (its side stands), one that leans nowhere, and every key that is no
-- quest. Soft: Graph.HidesEdge, the counts and Keep never read it. Pure over the shipped listing.
function Graph.QuestLean(questKey)
  if type(questKey) ~= "string" or Graph.QuestSide(nil, questKey) ~= nil then
    return nil
  end
  local flags = ItemTree.QuestFlags
  if type(flags) ~= "table" or type(flags.Lean) ~= "function" then
    return nil
  end
  local kind, id = Graph.Parse(questKey)
  if kind ~= "quest" or tonumber(id) == nil then
    return nil
  end
  local ok, side = pcall(flags.Lean, tonumber(id))
  if ok and (side == 1 or side == 2) then
    return side
  end
  return nil
end

-- Brief RB2: the muted words the other side's player reads on a leaning quest's rows and page.
Graph.LEAN_WORDS = { [1] = L["Possibly Alliance only"], [2] = L["Possibly Horde only"] }

--- Brief RB2: "Possibly Alliance only" or "Possibly Horde only" for a quest that leans to the side
--- that is not playerSide's ("Alliance" or "Horde"), or nil: the leaning side's own player, a quest
--- that leans nowhere or is sided outright, a player whose side is not known. Pure.
function Graph.LeanWords(questKey, playerSide)
  local mine = Graph.SIDE_NUMBERS[playerSide]
  local lean = mine and Graph.QuestLean(questKey) or nil
  if lean == nil or lean == mine then
    return nil
  end
  return Graph.LEAN_WORDS[lean]
end

--------------------------------------------------------------------------------
-- Brief F155 (owner QA 2026-10-14 item 155): "Hide other faction data", on by default. The owner:
-- "Should we hide unrelated faction NPCs to the current character and as a settings? e.g. Hide
-- other faction data / On by default", and "Could link in with those wool quests we hid the other
-- day" (brief QS1). One setting, read here, governs everything the other side owns that this
-- character cannot use: QS1's quests (Core/Keep.lua, Core/ViewModel.lua, UI/Tooltip.lua), the
-- trainers' and vendors' rows and their counts (Graph.WithoutOtherSide through the views' walks),
-- the trainer and vendor searches (Core/TrainerSearch.lua, Core/Data.lua), the Professions tab's
-- Trainers & vendors panel and the zone maps' NPC pins. Never hidden: a drop source, boss loot,
-- Discoveries, a neutral NPC, an NPC whose side nothing states, and a row the player's own
-- records show. Nothing is hidden while the character's side is not known (the client answers
-- no side, a Neutral pandaren). Brief HF2 (item 270): and the Sources rows of a quest reward of
-- the other side alone, with the item page's count (Graph.SIDE_SOURCE_QUEST_TYPES).
--------------------------------------------------------------------------------

-- The settings key, read nowhere else by name.
Graph.HIDE_OTHER_FACTION = "hideOtherFaction"

--- Whether the setting is on: anything but a stated false. settings is the saved settings table;
--- left out, ItemTree.db.settings is read (a namespace with none reads as the shipped default, on).
--- Pure over what it reads.
function Graph.HidesOtherFaction(settings)
  if type(settings) ~= "table" then
    local db = ItemTree.db
    settings = type(db) == "table" and type(db.settings) == "table" and db.settings or nil
  end
  return not (type(settings) == "table" and settings[Graph.HIDE_OTHER_FACTION] == false)
end

--- The character's side, "Alliance" or "Horde", or nil while it is not known. Graph.playerSide
--- states it for a spec; otherwise Core/Sources.lua's Favour.PlayerFaction answers, the pretend side
--- first (Core/Demo.lua), then the client's UnitFactionGroup("player"), whose first answer is the
--- faction group tag (Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:1207 to 1221 in the
--- UI source mirror; the Forever (camelot) PVP rank frame compares it the same way,
--- Blizzard_UIPanels_Game/Camelot/PVPRankFrame.lua:213). A Neutral answer is no side. Guarded.
Graph.playerSide = nil
function Graph.PlayerSide()
  if Graph.playerSide == "Alliance" or Graph.playerSide == "Horde" then
    return Graph.playerSide
  end
  local sources = ItemTree.Sources
  local favour = type(sources) == "table" and sources.Favour or nil
  if type(favour) ~= "table" or type(favour.PlayerFaction) ~= "function" then
    return nil
  end
  local ok, side = pcall(favour.PlayerFaction)
  if ok and (side == "Alliance" or side == "Horde") then
    return side
  end
  return nil
end

--- The side the setting hides FROM: the character's own side word while the setting is on and the
--- side is known, else nil, and then nothing is hidden anywhere. Guarded.
function Graph.HiddenSide(settings)
  if not Graph.HidesOtherFaction(settings) then
    return nil
  end
  return Graph.PlayerSide()
end

-- The side numbers every side field in the data uses (Core/Keep.lua's, the Classic Era cf): 1
-- Alliance, 2 Horde, 3 both.
Graph.SIDE_NUMBERS = { Alliance = 1, Horde = 2 }

--- The side the NPC a vendor's or a trainer's row names serves: 1 Alliance, 2 Horde, 3 both, or nil
--- where nothing states one. The edge's faction (the Classic Era cf, Core/EraSources.lua; a player
--- row whose place proves the side, Core/PlayerSources.lua SaleSide; a live row that took a Classic
--- Era row's side, Graph.AdoptSourceFacts), else the side word a Merchant's Favour row ships
--- (Core/Sources.lua communityOf), else the side the shipped Classic Era table states for the name
--- the row's npc key joins (E:NpcNameAt and E:Faction, the read UI/Tree.lua Tree.RowSide draws the
--- row's side icon from), so a player reported or client row of a Classic Era vendor reads that
--- vendor's side. A summary row ("Show 101 vendors") names no NPC and has none. Guarded.
function Graph.NpcSide(edge)
  if type(edge) ~= "table" then
    return nil
  end
  local side = tonumber(edge.faction)
  if side == 1 or side == 2 or side == 3 then
    return side
  end
  local community = type(edge.community) == "table" and edge.community or nil
  side = community and Graph.SIDE_NUMBERS[community.faction] or nil
  if side or edge.summary ~= nil or type(edge.target) ~= "string" then
    return side
  end
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.NpcNameAt) ~= "function" or type(era.Faction) ~= "function" then
    return nil
  end
  local okName, nameIndex = pcall(era.NpcNameAt, era, edge.target)
  if not okName or type(nameIndex) ~= "number" then
    return nil
  end
  local okSide, stated = pcall(era.Faction, era, nameIndex)
  if okSide and (stated == 1 or stated == 2 or stated == 3) then
    return stated
  end
  return nil
end

-- The rows the setting hides, by edge type: a vendor's and a trainer's row walking up (Sold by and
-- Trainer, each pointing at the NPC), and QS1's quests walking down from an item (the quests it is
-- asked for and the quests it starts, which are the item's Used by quests).
Graph.SIDE_NPC_TYPES = { SOLD_BY = true, LEARNED_FROM_TRAINER = true }
Graph.SIDE_QUEST_TYPES = { QUEST_OBJECTIVE = true, STARTS_QUEST = true }

-- Brief HF2 (owner QA 2026-10-18 item 270, Minor Healing Potion's Sources on his Alliance hunter with
-- the setting on: "Why is horde only being displayed?", Burning Blade Medallion 794 marked "Horde
-- only"): the rows that name a quest as a SOURCE of the item walking up (a quest reward, a choice of
-- rewards among them, a quest that provides the item), every type the Sources view lists
-- (Edges.SOURCE_TYPES) whose target is a quest, so a type added there later follows. QUEST_REWARD
-- and QUEST_PROVIDED today.
Graph.SIDE_SOURCE_QUEST_TYPES = {}
for name in pairs(Edges.SOURCE_TYPES or EMPTY) do
  local def = T[name]
  if type(def) == "table" and def.target == "quest" then
    Graph.SIDE_SOURCE_QUEST_TYPES[name] = true
  end
end

-- Brief CH1 (with item 270's note: an NPC's Quests tab did not read the setting): the rows of an NPC's
-- Quests tab, the quests it starts and ends (Edges.QUEST_GIVER_TYPES), sided by the quest key alone
-- like a reward row above, the read the row's "Horde only" words come from (Graph.FactionOnly).
Graph.SIDE_GIVER_QUEST_TYPES = {}
for name in pairs(Edges.QUEST_GIVER_TYPES or EMPTY) do
  Graph.SIDE_GIVER_QUEST_TYPES[name] = true
end

--- Whether the setting hides one edge from a character of playerSide ("Alliance" or "Horde"): a
--- vendor's or a trainer's row whose NPC serves the other side alone (Graph.NpcSide), unless the
--- player's own records show it (the collector's verified row), and a quest of the other side alone
--- the item is asked for or starts (Graph.QuestSide, QS1's rule). Everything else answers false: a
--- drop, a neutral NPC (3), an NPC or a quest whose side nothing states, and every edge while
--- playerSide is nil. Pure over the shipped listing.
--- Brief HF2: and a quest of the other side alone the item comes from (Graph.SIDE_SOURCE_QUEST_TYPES),
--- sided by the quest key alone (Graph.QuestSide with no faction), never by the edge's faction: that
--- is the read Graph.FactionOnly words the row's "Horde only" from (brief FX14, the Classic Era f
--- still sides quests the final lists open to both), so the setting hides exactly the reward rows
--- that would say it, and a quest the lists open to both stays whatever the edge's faction says.
--- Brief CH1: and a quest of the other side alone an NPC starts or ends (Graph.SIDE_GIVER_QUEST_TYPES),
--- sided the same way.
--- Brief HF1 (item 406): a need's or a start's own faction gives way to the shipped lists as well
--- (Graph.QuestSide), so a quest they open to both, leaning or not, stays on both sides' Used by.
function Graph.HidesEdge(edge, playerSide)
  local mine = Graph.SIDE_NUMBERS[playerSide]
  if mine == nil or type(edge) ~= "table" or type(edge.type) ~= "table" then
    return false
  end
  local name = edge.type.name
  local side = nil
  if Graph.SIDE_NPC_TYPES[name] then
    if edge.confidence == Confidence.VERIFIED then
      return false
    end
    side = Graph.NpcSide(edge)
  elseif Graph.SIDE_QUEST_TYPES[name] then
    side = Graph.QuestSide(edge.faction, edge.target)
  elseif Graph.SIDE_SOURCE_QUEST_TYPES[name] or Graph.SIDE_GIVER_QUEST_TYPES[name] then
    side = Graph.QuestSide(nil, edge.target)
  end
  return (side == 1 or side == 2) and side ~= mine
end

--- edges less every edge Graph.HidesEdge hides from playerSide. The list is the caller's and is not
--- written into; the same list comes back where nothing goes (and for a nil side). Pure.
function Graph.WithoutOtherSide(edges, playerSide)
  if type(edges) ~= "table" or #edges == 0 or Graph.SIDE_NUMBERS[playerSide] == nil then
    return edges
  end
  local out, dropped = {}, false
  for _, edge in ipairs(edges) do
    if Graph.HidesEdge(edge, playerSide) then
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

-- Brief RB2 (owner QA 2026-10-17 item 191, Crest of Lordaeron 275521, "if we're hiding the related
-- quest why aren't we hiding the related item?"): the one side an ITEM belongs to, 1 Alliance or 2
-- Horde, or nil. An item belongs to a side where every quest use it has (the quests that ask for
-- it or that it starts, counted as Graph.Summary counts them, sided by Graph.QuestSide) and every
-- source it has (an UP edge: a quest reward sided by Graph.QuestSide, a vendor's or a trainer's row
-- sided by Graph.NpcSide and not the player's own record) is that side's, and there is at least
-- one of them. Anything else answers nil: a use that is no quest (a recipe, a tool, a class spell),
-- a source no side owns (a drop, an object, a recipe that makes it, a neutral or unstated NPC), a
-- quest open to both, uses or sources split between the sides, and an item read while ItemTree_Data
-- is not loaded (only its glance is at hand). Pure over the shipped listing and the providers.
-- Brief EQ1: the quest uses hold the game event quests Graph.Summary counts since, as Used by lists them.
-- Brief HF1 (item 406): every quest here is sided by the shipped lists first (Graph.QuestSide), its
-- edge's faction only where they say nothing, so an item of a quest they open to both is no side's.
function Graph.ItemSide(itemId)
  local id = tonumber(itemId)
  if not id or not Data:OnDemandLoaded() then
    return nil
  end
  -- The cheap answers first, so a reagent or a dropped item never pays for the quest count: a
  -- recipe, a teaching or a class spell use, then the first source no side owns.
  local uses = Data:GetUses(id) or EMPTY
  if countOf(uses.r) + countOf(uses.t) + countOf(uses.cs) > 0 then
    return nil
  end
  local side = nil
  for _, edge in ipairs(Graph.Children(Graph.Key("item", id), Edges.UP)) do
    local def = type(edge) == "table" and edge.type or nil
    local stated = nil
    if type(def) == "table" and def.target == "quest" then
      stated = Graph.QuestSide(edge.faction, edge.target)
    elseif type(def) == "table" and Graph.SIDE_NPC_TYPES[def.name] and edge.confidence ~= Confidence.VERIFIED then
      stated = Graph.NpcSide(edge)
    end
    if (stated ~= 1 and stated ~= 2) or (side ~= nil and side ~= stated) then
      return nil
    end
    side = stated
  end
  local summary = Graph.Summary(id)
  if (tonumber(summary.toolFor) or 0) + (tonumber(summary.classUse) or 0) > 0 then
    return nil
  end
  local quests = tonumber(summary.questUses) or 0
  local sides = type(summary.questSides) == "table" and summary.questSides or EMPTY
  if quests > 0 then
    local used = (sides[1] == quests and 1) or (sides[2] == quests and 2) or nil
    if used == nil or (side ~= nil and side ~= used) then
      return nil
    end
    side = used
  end
  return side
end

--- Brief RB2: whether "Hide other faction data" hides an item from a character of playerSide
--- ("Alliance" or "Horde"): the item belongs to the other side alone (Graph.ItemSide). False for
--- every item while playerSide is nil. Pure over the shipped listing.
function Graph.HidesItem(itemId, playerSide)
  local mine = Graph.SIDE_NUMBERS[playerSide]
  if mine == nil then
    return false
  end
  local side = Graph.ItemSide(itemId)
  return side ~= nil and side ~= mine
end

-- The words a list says where the setting took rows out of it, by the hidden side and the noun.
local HIDDEN_WORDS = {
  trainer = {
    [1] = { L["1 Alliance trainer hidden"], L["%d Alliance trainers hidden"] },
    [2] = { L["1 Horde trainer hidden"], L["%d Horde trainers hidden"] },
  },
  vendor = {
    [1] = { L["1 Alliance vendor hidden"], L["%d Alliance vendors hidden"] },
    [2] = { L["1 Horde vendor hidden"], L["%d Horde vendors hidden"] },
  },
}

--- Brief F155: the one muted line a list says in place of the rows the setting took out of it, so
--- the player knows the setting did it: "4 Horde trainers hidden", "1 Alliance vendor hidden".
--- side is the HIDDEN side (1 Alliance, 2 Horde), noun "trainer" or "vendor". nil for a count
--- below one or anything else. Pure.
function Graph.HiddenText(count, side, noun)
  count = math.floor(tonumber(count) or 0)
  local words = HIDDEN_WORDS[noun] and HIDDEN_WORDS[noun][tonumber(side)] or nil
  if count < 1 or not words then
    return nil
  end
  if count == 1 then
    return words[1]
  end
  return string.format(words[2], count)
end

-- Counts for the tooltip and the summary HUD.
function Graph.Summary(itemId)
  local uses = Data:GetUses(itemId) or EMPTY
  local key = Graph.Key("item", itemId)
  local usedIn = countOf(uses.r)
  local teaches = countOf(uses.t)
  -- Brief P5b: the class spells the item is a reagent for, a use like any other.
  local classSpells = countOf(uses.cs)
  -- Brief U3: while the item tables are not loaded (they ship in ItemTree_Data), what this reads
  -- off an item row comes out of the core set's Summary module instead (Data:Glance), which the
  -- pipeline works out from the same rows, so a tooltip at login never loads the data addon. Once
  -- the data addon is loaded the rows are read as they always were.
  local glance = nil
  if not Data:OnDemandLoaded() then
    glance = Data:Glance(itemId)
  end
  local toolFor, quests, disenchant
  -- Brief HF1: the item row's start quest (sq), counted once with the others below.
  local startsQuest = nil
  -- Brief BQ5: the professions of the recipes that make it and of the ones that use it.
  local producedBy = countOf(uses.p)
  local madeSkills, usedSkills
  -- Brief TB10: a class locked consumable's own use (Core/Keep.lua ClassUse), which no edge states,
  -- read off the item row once it is loaded; nothing while only the glance is.
  local classUse = 0
  -- Brief TBR2: the class use in the Keep block's own words ("Mages read it (Comprehension 1)",
  -- Keep.ClassWords), so the uses line can say it rather than "No known uses".
  local classWords = nil
  if glance then
    toolFor = glance.toolFor
    quests = glance.quest and 1 or 0
    disenchant = glance.disenchant
    local summary = Data:Get("Summary")
    madeSkills = Graph.SummarySkills(summary, itemId, "p", producedBy)
    usedSkills = Graph.SummarySkills(summary, itemId, "r", usedIn)
  else
    if producedBy > 0 then
      madeSkills = Graph.RecipeSkills(uses.p)
    end
    if usedIn > 0 then
      usedSkills = Graph.RecipeSkills(uses.r)
    end
    local item = Data:GetItem(itemId)
    -- Recipes this item is a tool for, counted the same way whether the recipe named the item's
    -- totem category or the item itself. A tool is a use: an item counted at zero reads as "No
    -- known uses on this client", which is what every tool said before this was counted at all.
    toolFor = #Data:ToolRecipes(itemId)
    -- Brief HF1 (QI1's finding, 2026-10-17): the quest the item starts is counted below with the
    -- quests it is asked for, once per quest and by its side, no longer apart.
    startsQuest = item and item.sq or nil
    quests = 0
    disenchant = Data:DisenchantBand(item) ~= nil
    local keep = ItemTree.Keep
    if item and type(keep) == "table" and type(keep.ClassUse) == "function" then
      local ok, use = pcall(keep.ClassUse, itemId)
      if ok and type(use) == "table" then
        classUse = 1
        if type(keep.ClassWords) == "function" then
          local worded, words = pcall(keep.ClassWords, use)
          if worded and type(words) == "string" then
            classWords = words
          end
        end
      end
    end
  end
  local up = providerEdges(key, Edges.UP)
  local down = providerEdges(key, Edges.DOWN)
  -- Brief K24e: the quests the item only comes from (an UP edge to a quest no DOWN edge names
  -- too), counted apart as well, so the tooltip can leave them out of its "N quests" (owner QA
  -- 2026-10-06: "I assume the '1 quest' is that it CAME from a quest ... not necessary to
  -- display"). quests still counts them, for the item page's own summary line.
  local needed = {}
  -- Brief QS1 (the owner's ruling A of 2026-10-14): the quests that need the item or that it starts,
  -- by the side they are for (1 Alliance, 2 Horde; Graph.QuestSide), so the tooltip can leave the
  -- other side's out of its count (UI/Tooltip.lua TooltipSummary): they are no use of the item for
  -- the player.
  local questSides = { 0, 0 }
  -- Brief QS2b: the same quests counted by the one side players were seen taking them on
  -- (Graph.QuestSeenSide), where nothing else sides them, so every count can leave them out for the
  -- other side whatever "Hide other faction data" says (UI/Tooltip.lua SeenOtherQuests).
  local questSeenSides = { 0, 0 }
  -- Brief RB1b: each counted quest's side as bySide filed it ({ side } or { seen }), and the quests the
  -- item starts, so the repeatable quests are counted apart below by the same sides.
  local sideOf, started = {}, {}
  local function bySide(side, faction, target)
    if side == 1 or side == 2 then
      questSides[side] = questSides[side] + 1
      if target ~= nil then
        sideOf[target] = { side = side }
      end
      return
    end
    local seen = Graph.QuestSeenSide(faction, target)
    if seen then
      questSeenSides[seen] = questSeenSides[seen] + 1
    end
    if target ~= nil then
      sideOf[target] = { seen = seen }
    end
  end
  -- Brief HF1 (QI1's finding: An Unsent Letter 2874 read 2 quests for its one quest 373): a quest
  -- the item starts and is asked for (a STARTS_QUEST and a QUEST_OBJECTIVE edge) is one quest, as
  -- the Used by tab draws one row per quest (Core/ViewModel.lua, QI1).
  for _, edge in ipairs(down) do
    if edge.type.target == "quest" and edge.type.name == "STARTS_QUEST" and edge.target ~= nil then
      started[edge.target] = true
    end
    if edge.type.target == "quest" and not (edge.target ~= nil and needed[edge.target]) then
      quests = quests + 1
      -- Brief HF1 (item 406): the edge's faction counts only for a quest the shipped lists say
      -- nothing about (Graph.QuestSide). Brief AT2: an edge stating a side still reads no seen side
      -- (Graph.QuestSeenSide, the owner's QS2b ruling).
      bySide(Graph.QuestSide(edge.faction, edge.target), edge.faction, edge.target)
      if edge.target ~= nil then
        needed[edge.target] = true
      end
    end
  end
  -- Brief BQ5 (owner QA item 1, Garrick's Head, Okra, Goretusk Snout, Holy Spring Water read no
  -- quest): the listed Classic quests that ask for it count, once each, and not where a trusted
  -- provider states that quest's requirements (the graph's own rule, dropRestatedRequirements).
  -- Brief RB1: the unlisted (Predicted) ones too, once the data judges them (Graph.EraQuestNeeds).
  for _, questId in ipairs(Graph.EraQuestNeeds(itemId, glance)) do
    local target = Graph.Key("quest", questId)
    if not needed[target] and not statesRequirements(target) then
      needed[target] = true
      quests = quests + 1
      bySide(Graph.QuestSide(nil, target), nil, target)
    end
  end
  -- Brief HF1 (QI1's finding: Crest of Lordaeron 275521 read "1 quest" on the Alliance with "Hide
  -- other faction data" on while its Used by was empty, its quest 95204 the Horde's): the quest the
  -- item row says it starts counts once, with its side, unless an edge counted it already. A start
  -- flag that names no quest id counts as before, open to both sides.
  if startsQuest then
    local startId = tonumber(startsQuest)
    local target = startId and Graph.Key("quest", startId) or nil
    if target == nil then
      quests = quests + 1
    elseif not needed[target] then
      needed[target] = true
      quests = quests + 1
      bySide(Graph.QuestSide(nil, target), nil, target)
    end
    if target ~= nil then
      started[target] = true
    end
  end
  -- Brief INT14 (HF1's note on GF6): a new Forever quest whose predicted objectives ask for the item
  -- counts once, with its side (its predicted side, Graph.QuestSide), as Keep counts it, unless a
  -- record of ours or the start counted that quest already. Before, Keep's "1 quest" on Rough Dynamite
  -- (A Dynamite Plan) stood over a page that counted none.
  for _, questId in ipairs(Graph.PredictedQuestNeeds(itemId)) do
    local target = Graph.Key("quest", questId)
    if not needed[target] then
      needed[target] = true
      quests = quests + 1
      bySide(Graph.QuestSide(nil, target), nil, target)
    end
  end
  -- Brief CT1b (QA item 228): a quest the player module states asks for the item counts once, with its
  -- side, as the Used by tab and Keep count it (Graph.PlayerQuestNeeds), unless counted above.
  for _, questId in ipairs(Graph.PlayerQuestNeeds(itemId)) do
    local target = Graph.Key("quest", questId)
    if not needed[target] then
      needed[target] = true
      quests = quests + 1
      bySide(Graph.QuestSide(nil, target), nil, target)
    end
  end
  -- Brief EQ1 (the owner's ruling A of 2026-10-18 on QA item 233): a game event's quest that asks for
  -- the item counts once, with its side, as the Used by tab lists it (Graph.EraEventQuestNeeds), unless
  -- counted above or a trusted provider states that quest's requirements (the Classic quests' rule
  -- above). Filed apart below (questEvents) so the tooltip can leave these out as before.
  local events = {}
  for _, questId in ipairs(Graph.EraEventQuestNeeds(itemId)) do
    local target = Graph.Key("quest", questId)
    if not needed[target] and not statesRequirements(target) then
      needed[target] = true
      events[target] = true
      quests = quests + 1
      bySide(Graph.QuestSide(nil, target), nil, target)
    end
  end
  -- Brief RB1b (the owner's answer of 2026-10-17 on item 190): of the quests counted above, the
  -- repeatable ones the item does not start (Core/Keep.lua Keep.QuestRepeat: a reputation turn in, no
  -- event's), by the same sides, so the tooltip can fold them (UI/Tooltip.lua TooltipSummary) while the
  -- item page counts them. Keep never keeps for them.
  local questRepeats, questRepeatSides, questRepeatSeenSides = 0, { 0, 0 }, { 0, 0 }
  local keep, flags = ItemTree.Keep, ItemTree.QuestFlags
  local isRepeat = type(keep) == "table" and keep.QuestRepeat or nil
  -- Without Core/Keep.lua (a spec's core set) the turn in list alone answers.
  if type(isRepeat) ~= "function" and type(flags) == "table" then
    isRepeat = flags.IsTurnIn
  end
  -- Brief RB1c (the owner's ruling "A" of 2026-10-17): and apart from them the quests an instance holds
  -- back for this character (Core/QuestFlags.lua HeldBack, a need or a start), by the same sides, which
  -- the tooltip folds as well until the character has been inside.
  local questGated, questGatedSides, questGatedSeenSides = 0, { 0, 0 }, { 0, 0 }
  local heldBack = type(flags) == "table" and flags.HeldBack or nil
  -- Brief EQ1: and apart from both the game event quests counted above, by the same sides, which the
  -- tooltip leaves out (UI/Tooltip.lua TooltipSummary) while the item page counts them.
  local questEvents, questEventSides, questEventSeenSides = 0, { 0, 0 }, { 0, 0 }
  -- Brief RPAR (the owner's ruling Q1 of 2026-10-09: "event quests (AQ War Effort, holidays) NEVER keep an
  -- item and show an Event tag"): a game event's quest a record of ours asks the item for is the event's
  -- all the same. The players' record of Hallow's End Treats for Jesper! (8311) on Ironforge Mint (20490)
  -- is counted above (the player provider's QUEST_OBJECTIVE edge, or Graph.PlayerQuestNeeds) before the
  -- event loop can file it, so the tooltip counted the Alliance's event quest ("1 quest", and "No known
  -- uses for Horde" on the Horde) while Keep keeps nothing for it (Keep.QuestNeverKeeps reads the quest id
  -- alone). The same read here, a quest the item starts left as it was. Only while ItemTree_Data is
  -- loaded, as Graph.EraEventQuestNeeds.
  local eventEra = Data:OnDemandLoaded() and ItemTree.eraSources or nil
  local function eventQuest(target, id)
    if events[target] then
      return true
    end
    if started[target] or type(eventEra) ~= "table" or type(eventEra.QuestEvent) ~= "function" then
      return false
    end
    local asked, event = pcall(eventEra.QuestEvent, eventEra, id)
    return asked and event ~= nil
  end
  local function file(target, sides, seenSides)
    local filed = sideOf[target]
    if filed and filed.side then
      sides[filed.side] = sides[filed.side] + 1
    elseif filed and filed.seen then
      seenSides[filed.seen] = seenSides[filed.seen] + 1
    end
  end
  for target in pairs(needed) do
    local kind, id = Graph.Parse(target)
    id = tonumber(id)
    if kind == "quest" and id then
      if eventQuest(target, id) then
        questEvents = questEvents + 1
        file(target, questEventSides, questEventSeenSides)
      elseif type(isRepeat) == "function" and not started[target] and isRepeat(id) == true then
        questRepeats = questRepeats + 1
        file(target, questRepeatSides, questRepeatSeenSides)
      -- Brief WS1: a quest the item starts is never held back by its starter (started).
      elseif type(heldBack) == "function" and heldBack(id, started[target]) ~= nil then
        questGated = questGated + 1
        file(target, questGatedSides, questGatedSeenSides)
      end
    end
  end
  -- Brief RB2: how many distinct quests use the item (asked for, started, predicted), the quests
  -- questSides sides; the rewards below are counted in quests too.
  local questUses = quests
  local questRewards = 0
  -- Brief HF2 (owner QA 2026-10-18 item 270): the quests the item only comes from (questRewards) by
  -- the side they are for alone, { alliance, horde }, the quest key's side (Graph.QuestSide with no
  -- faction, the read Graph.HidesEdge hides their Sources rows by), so the item page's count can leave
  -- the other side's out while "Hide other faction data" is on (UI/Tooltip.lua WithoutOtherSide).
  local questRewardSides = { 0, 0 }
  local function rewardSide(target)
    local side = target ~= nil and Graph.QuestSide(nil, target) or nil
    if side == 1 or side == 2 then
      questRewardSides[side] = questRewardSides[side] + 1
    end
  end
  local rewarded = {}
  for _, edge in ipairs(up) do
    if edge.type.target == "quest" then
      quests = quests + 1
      if edge.target ~= nil then
        rewarded[edge.target] = true
      end
      if edge.target == nil or not needed[edge.target] then
        questRewards = questRewards + 1
        rewardSide(edge.target)
      end
    end
  end
  -- Brief RB1 (the owner's standing rule of 2026-10-17, "Predicted IS our data"): a new Forever quest
  -- whose predicted rewards hand the item over counts like a recorded reward (Graph.PredictedRewardQuests),
  -- once, unless a record of ours names the same quest's reward already. Before, the provider's
  -- Predicted edges were never asked here, so the page's count left out the Sources tab's Predicted
  -- quest rows.
  for _, questId in ipairs(Graph.PredictedRewardQuests(itemId)) do
    local target = Graph.Key("quest", questId)
    if not rewarded[target] then
      rewarded[target] = true
      quests = quests + 1
      if not needed[target] then
        questRewards = questRewards + 1
        rewardSide(target)
      end
    end
  end
  -- Brief PV1 (the owner's QA item 375): a new Forever quest that hands the item over at accept counts
  -- like a quest the item comes from (Graph.PredictedProvidedQuests), once, and only where nothing above
  -- counted that quest: a quest that hands the item over and asks for it back (Making Do and Alexston's
  -- Reply, every inline provided item) is one quest, already counted as the item's use.
  -- Brief IW1: the same for a quest the records say hands the item over (Graph.RecordedProvidedQuests),
  -- which wins the item page's row over the predicted one and so is counted the same way, once.
  -- Brief NX1 (the owner's ruling "2A"): and a Classic Era quest that hands it over (Graph.EraProvidedQuests),
  -- the Classic Era provider's own row, which a provider of history alone never answers here.
  for _, list in ipairs({
    Graph.RecordedProvidedQuests(itemId),
    Graph.EraProvidedQuests(itemId, glance),
    Graph.PredictedProvidedQuests(itemId),
  }) do
    for _, questId in ipairs(list) do
      local target = Graph.Key("quest", questId)
      if not rewarded[target] and not needed[target] then
        rewarded[target] = true
        quests = quests + 1
        questRewards = questRewards + 1
        rewardSide(target)
      end
    end
  end
  return {
    usedIn = usedIn,
    producedBy = producedBy,
    -- Brief BQ5: { { line, count, name }, ... }, the named professions only, most recipes first;
    -- nil where none is named. UI/Tooltip.lua words them (UsedInWords, MadeByWords).
    usedInSkills = namedSkills(usedSkills),
    producedBySkills = namedSkills(madeSkills),
    teaches = teaches,
    toolFor = toolFor,
    classSpells = classSpells,
    quests = quests,
    questRewards = questRewards,
    -- Brief HF2: { alliance, horde }, how many of questRewards are for one side alone.
    questRewardSides = questRewardSides,
    -- Brief RB2: the distinct quests that ask for or are started by the item (its quest uses).
    questUses = questUses,
    -- Brief QS1: { alliance, horde }, how many of the quests needing or started by the item are for
    -- one side alone.
    questSides = questSides,
    -- Brief QS2b: { alliance, horde }, how many of the rest only that side's players were seen taking.
    questSeenSides = questSeenSides,
    -- Brief RB1b: how many of the quests asked for are repeatable (never kept for), and of them how
    -- many questSides and questSeenSides side, { alliance, horde } each.
    questRepeats = questRepeats,
    questRepeatSides = questRepeatSides,
    questRepeatSeenSides = questRepeatSeenSides,
    -- Brief RB1c: how many of the quests an instance holds back for this character, by the same sides.
    questGated = questGated,
    questGatedSides = questGatedSides,
    questGatedSeenSides = questGatedSeenSides,
    -- Brief EQ1: how many of the quests asked for are game event quests only the Classic Era table
    -- states (Graph.EraEventQuestNeeds), and of them how many questSides and questSeenSides side.
    questEvents = questEvents,
    questEventSides = questEventSides,
    questEventSeenSides = questEventSeenSides,
    sources = #up,
    disenchant = disenchant,
    classUse = classUse,
    classWords = classWords,
    total = usedIn + teaches + toolFor + quests + classSpells + classUse,
  }
end

-- Depth first walk with an ancestor path cycle guard. The visitor is called as
-- visitor(key, depth, edge, path, loop) and may return false to stop descending. A key
-- already in its own ancestor path is visited once as a loop and never descended into.
function Graph.Walk(rootKey, direction, maxDepth, visitor)
  maxDepth = maxDepth or 6
  local path, onPath = {}, {}

  local function step(key, depth, edge)
    local loop = onPath[key] == true
    local snapshot = {}
    for i = 1, #path do
      snapshot[i] = path[i]
    end
    if visitor(key, depth, edge, snapshot, loop) == false or loop or depth >= maxDepth then
      return
    end
    onPath[key] = true
    path[#path + 1] = key
    for _, child in ipairs(Graph.Children(key, direction)) do
      step(child.target, depth + 1, child)
    end
    path[#path] = nil
    onPath[key] = nil
  end

  step(rootKey, 0, nil)
end

-- Brief RB3 (the owner's QA item 196): every quest id list the counts and Keep read folds each dead
-- twin into its live quest (foldTwinIds), so Smotts' Chest, asked for by 614 and 8551, is one quest's
-- need. Wrapped here, once, over whichever of these lists this file defines, so the fold holds for
-- each without a line in its body.
-- Brief CT1b: and the player module's quest needs. Brief EQ1: and the game event quests'.
for _, name in ipairs({
  "ListedQuestNeeds",
  "EraQuestNeeds",
  "EraEventQuestNeeds",
  "PredictedQuestNeeds",
  "PredictedRewardQuests",
  "PredictedProvidedQuests",
  "RecordedProvidedQuests",
  "EraProvidedQuests",
  "PlayerQuestNeeds",
}) do
  local list = Graph[name]
  if type(list) == "function" then
    Graph[name] = function(...)
      return foldTwinIds(list(...))
    end
  end
end

return Graph
