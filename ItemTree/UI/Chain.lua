-- The Item chain view: the whole crafting chain through one item, drawn left to right with the
-- root in the middle, on a canvas the player can zoom and pan. It was a window tab of its own
-- until brief C2 made it the first of an item's view tabs, beside Used by and Sources; the pane is
-- the same, handed a region where the category column and the row list go instead of the whole
-- content area.
--
-- Design reference: the window's own pane, harness/src/render-panes.tsx ChainPane, rather than
-- design/components/tree/ChainView.jsx. The component draws a single path with a path dropdown
-- above it and cannot show both directions, zoom, pan or take the wheel.
--
-- Anatomy (Theme.sizes):
--   ITEMTREE_CHAIN_ICON 36 stage icon in a bordered slot, ITEMTREE_CHAIN_GAP 20 plus
--   ITEMTREE_CHAIN_ARROW 24 between stages (44 all up, the span the design draws),
--   ITEMTREE_FONTSIZE_BODY_SM 11 for the name, the meta line and the quantity on the arrow,
--   ITEMTREE_BADGE_SIZE_TREE 16 for stage badges, ITEMTREE_CONTROL_H_SM 20 for the chain
--   selector, the two controls under a stage and the zoom buttons.
--
-- Data: ItemTree.Chain.Full(rootKey, opts) (Core/Chain.lua) is the only source. It hands back
-- { stages, rootIndex, choices, choice, label, dropped } with every stage already carrying its
-- key, kind, name, quality, icon, meta, badges, quantity, arrow text, skill, slot, the
-- alternatives that could stand in its slot, the co-reagents a recipe needs alongside it and
-- the tools it asks the player to hold. This pane never walks the graph itself and never
-- touches saved variables. Brief SF1: it reads the "Show predicted data" setting and hands it to
-- Core (opts.showPredicted), and holds what Core built while nothing the chain reads has moved
-- (Chain.CacheKey, Chain.ChainFor), so a window refresh draws the held chain.
--
-- What the player can change, all of it session state that resets with the root:
--   the choice    an id from full.choices, picked in the selector at the top left, passed
--                 back as opts.choice.
--   the pins      { [slot] = nodeKey }, passed back as opts.pins. Clicking an alternative or
--                 a co-reagent pins it in that slot, so the stage is swapped in place and the
--                 rest of that side is recomputed rather than the window re-rooting.
--   Core drops a pin nothing can meet and names its slot in full.dropped, which is what the
--   pane reads to forget it again. A reagent alongside the root, or alongside a stage
--   downstream of it, is not offered as a pin at all: those slots are decided by the walk out of
--   the root, so picking one opens it as the new root instead and the row says so.
-- Re-rooting is still one click away: an entry's own arrow button, or a right click on it,
-- hands the key to the window, and so does a right click on a stage.
--
-- Everything above the "Client side" divider is pure and runs under busted with no WoW API:
--   Chain.Layout(stages, rootIndex, sizes)   x, y and width per stage, the arrow rects between
--                                            them, and the content width and height
--   Chain.TextWidth(text, fontSize)          roughly how wide a label is with nothing to ask
--   Chain.SortEntries(list)                  New and Changed first, then by name
--   Chain.MaxOffset(count, rows)             how far a list of that many can be scrolled
--   Chain.FitZoom(contentW, viewportW, ...)  the zoom that fits the chain in the viewport
--   Chain.ZoomAbout(zoom, newZoom, p, pan)   the pan that keeps the point under the pointer
--   Chain.ViewportPoint(x, y, left, top, s)  screen pixels to the viewport's own units
--   Chain.SnapShaft(centre, zoom, ...)       the arrow shaft, on whole pixels at any zoom
--   Chain.ClampPan(...)                      pan held inside the content, centred when it fits
--   Chain.CentrePan(centre, viewportW, zoom) the pan that puts one content point in the middle
--   Chain.BadgeOverhang(size)                the pixels a medallion stands proud of its badge
--   Chain.BadgeAnchor(size)                  where a stage's badges sit on its icon
--   Chain.ArrowText(stage)                   "x10", "x1 to 2" or "78%"
--   Chain.IsSignpost(stage)                  one of Core's two disenchant signs, not a step
--   Chain.SignpostClickAction(model, button) "view" with the node and the view, or "none"
--   Chain.SignpostTooltip(model)             the one line a signpost's tooltip says
--   Chain.StageModel(stage, isRoot, pinned)  one drawable stage: art, colours, badges, lists
--   Chain.CoReagentModel(entry)              one drawable co-reagent: art, colour, quantity
--   Chain.SelectorModel(full)                the selector's label and its list of chains
--   Chain.ZoomText(zoom)                     "85%" for the corner readout
--   Chain.CacheKey(rootKey, opts, facts)     the key and the stamp a built chain is held under
--
-- Zoom and pan on the client: the strip is laid out once at 1x on a canvas frame inside a
-- clipping viewport, and the zoom is canvas:SetScale, so icons and text scale together. Anchor
-- offsets are in the anchored frame's own scaled units, so a pan held in viewport pixels is
-- divided by the zoom before it is handed to SetPoint. GetCursorPosition answers in screen
-- pixels, which is neither of those: it is divided by the viewport's effective scale, which
-- carries the window's own scale as well, before it is measured against the viewport's edges.
-- Where the client has no SetClipsChildren the stages and arrows that fall outside the
-- viewport are hidden instead, so the strip still never spills over the rest of the window.
--
-- Contract with UI/Frame.lua, which owns the window:
--   Frame calls Chain.Attach(region) once with the region it created and sized (Frame.Regions()
--   chain), then Chain.Show(rootKey) whenever the Item chain view is up and the window draws.
--   Chain.Refresh() redraws the last root, Chain.Hide() hides the pane, Chain.Init() stays a
--   no op. All idempotent, and all no ops with no client. Clicking a stage opens it on a list view
--   (ItemTree.UI.Frame.Open(key, { view = Frame.RowView(key) })), and right clicking one re-roots
--   the chain on it (ItemTree.UI.Frame.Open(key), which keeps the Item chain view up because the
--   view sticks), all looked up lazily and guarded. A disenchant signpost is the one stage that
--   opens something other than itself: ItemTree.UI.Frame.Open(of, { view = ... }), so the window
--   draws once, rooted on the stage the sign belongs to, with that stage's Disenchants into or
--   Sources tab up. A window whose Open takes no options still opens the right node. The root the player came from
--   is read from ItemTree.UI.Frame.PreviousKey()
--   where the window states one and handed to Core as opts.prefer. No frame here needs a
--   template, so there is no template to fall back from: every CreateFrame is a plain frame and
--   every one of them is pcall'd.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local Chain = {}
ItemTree.UI.Chain = Chain

local Theme = ItemTree.Theme
local Assets = ItemTree.Assets
local Badges = ItemTree.Badges
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}
local NO_CHAIN = { stages = {}, rootIndex = 0, choices = {}, dropped = {} }
local SIZES = Theme.sizes
local FONTS = Theme.fontSizes

-- Stage slot and spacing, straight from the design tokens. The stage column is ChainView.jsx's
-- own 96px, which the tokens have no name for; the 44px between two stages is the gap and the
-- arrow together, the same span the design draws.
Chain.STAGE_W = 96
-- A slot grows to hold a control whose label will not fit, up to this. Two slots wide is as far
-- as one long label may push the run apart before the strip stops reading as a row.
Chain.STAGE_MAX_W = 192
Chain.ICON = SIZES.ITEMTREE_CHAIN_ICON
Chain.GAP = SIZES.ITEMTREE_CHAIN_GAP
Chain.ARROW = SIZES.ITEMTREE_CHAIN_ARROW
Chain.PAD = SIZES.ITEMTREE_SPACE_1
-- The room above the icon inside a slot. A whole step rather than the 4px padding, so the art
-- does not sit against the top edge of the root's own highlighted column.
Chain.TOP_PAD = SIZES.ITEMTREE_SPACE_2
Chain.CONTROL_H = SIZES.ITEMTREE_CONTROL_H_SM
Chain.BORDER = SIZES.ITEMTREE_BORDER_HAIRLINE
Chain.BAND = 2
Chain.BADGE = SIZES.ITEMTREE_BADGE_SIZE_TREE
Chain.BADGE_MAX = 2
Chain.FONT_SM = FONTS.ITEMTREE_FONTSIZE_BODY_SM
Chain.LINE = 14
Chain.ARROW_HEAD = 8
Chain.MENU_ICON = SIZES.ITEMTREE_ICON_CATEGORY
Chain.MENU_ROW_H = SIZES.ITEMTREE_LIST_ROW_H
Chain.MENU_W = 170
-- The widest a list may grow for its own longest entry, and the room a quantity takes on the
-- right of a row.
Chain.MENU_MAX_W = 320
Chain.MENU_RIGHT_W = 40
Chain.MENU_ACTION = 16
-- The most rows a list draws at once. Eighty seven ways to use a bar is a list taller than the
-- screen, and every row past the bottom edge is one the player cannot click; the rest are
-- reached with the wheel.
Chain.MENU_MAX_ROWS = 10
Chain.MENU_SCROLLER_W = 4
-- The list has to sit strictly above the catcher: the catcher is a screen wide mouse trap and a
-- click that lands on it closes the list, which is exactly the click that was meant for a row.
Chain.CATCHER_STRATA = "FULLSCREEN"
Chain.MENU_STRATA = "FULLSCREEN_DIALOG"
-- How far over everything the list is raised. The client's own menus take the owner's level and
-- add 500 (Blizzard_Menu/Menu.lua on the `forever` branch, MenuManagerMixin:OpenMenu), with the
-- comment that "there are some frames on the FULLSCREEN_DIALOG with questionably high frame
-- levels". A step of ten only ever cleared ItemTree's own frames, which was never the question.
Chain.MENU_LEVEL_STEP = 500
-- How many menu picks the debug trail remembers. Counts, keys and labels only: no saved
-- variables, and nothing about the character, the realm or the account.
Chain.TRAIL_MAX = 5
-- The selector reads a whole chain's name ("Arcane Crystal to Arcane Megabomb"), so it is
-- given the width of two stage slots and its list a little more again.
Chain.SELECTOR_W = 200
Chain.SELECTOR_MENU_W = 240
-- A chain's name is a sentence, not a word, so its list is allowed wider than any other before
-- a row is cut. Never wider than the pane it drops into, and a row that is still cut carries the
-- whole label and the stages it runs through in its own tooltip.
Chain.SELECTOR_MENU_MAX_W = 420
-- The corner glyphs on a stage icon: the spell mark bottom right, so a recipe is never read as
-- an item, and the pin mark bottom left on a stage the player has pinned. The bottom right
-- corner draws one glyph, whichever the stage asks for: the blue flame on a recipe, and on an
-- item this build withholds the question mark or the chest (Core/Graph.lua Graph.DiscoveryMark).
Chain.SPELL_MARK = 14
Chain.SPELL_MARK_ASSET = "ICON_SPELL_MARK"
-- E44: the slop around the glyph the chest's own hover target takes, the same couple of pixels a
-- tree row gives it (UI/Tree.lua Tree.MARK_HIT_SLOP).
Chain.MARK_HIT_SLOP = 2
Chain.PIN_MARK = 12

-- The client's own font objects, in the order they are tried. A font string is never left
-- fontless: SetText raises inside the client on one that is.
Chain.FONT_TEMPLATE = "GameFontNormalSmall"
Chain.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }

-- Zoom floor and ceiling. Fit never zooms past 1.0, because a short chain blown up reads as a
-- mistake; the wheel and the buttons go further in, which is what makes a long chain legible.
Chain.ZOOM_MIN = 0.4
Chain.ZOOM_MAX = 3.0
Chain.FIT_MAX = 1.0
Chain.ZOOM_STEP = 1.25
-- The zoom readout's room, left of the zoom buttons (Chain.ZoomBar).
Chain.ZOOM_LABEL_W = 40

Chain.PANEL_SURFACE = "ITEMTREE_COLOR_SURFACE_INSET"
Chain.PANEL_BORDER = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
Chain.ARROW_COLOR = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
Chain.ROOT_BAND = "ITEMTREE_COLOR_BORDER_GOLD"
Chain.ROOT_WASH = "ITEMTREE_COLOR_STATE_SELECTED"
Chain.PIN_COLOR = "ITEMTREE_COLOR_BORDER_GOLD"

-- Node kind to the Assets glyph a stage draws when it carries no art of its own. Same table
-- as UI/Tree.lua reads for its rows, so a quest stage looks the same in both panes. An item set
-- is not listed: its art is decided in one place, Core/ViewModel.lua SetIcon, which the tree's
-- set row wears too (see setArt), so the two panes can never draw a set differently.
local NODE_ICONS = {
  quest = "QUEST_AVAILABLE",
  npc = "CAT_DROPS",
  object = "CAT_NOTE",
  zone = "CAT_ZONE",
  skill = "CAT_NOTE",
  enchant = "CAT_ENCHANTING",
  -- Core's two disenchant signposts, which wear the Disenchants into category's own glyph.
  disenchant = "CAT_ENCHANTING",
}

-- The edge that reached a stage, to the Assets glyph it wears when it carries no art of its own.
-- Read before the node kind, because the kind cannot tell a vendor from a creature that drops the
-- item: all three are npc nodes, and it is the edge that says which one the player goes to. Core
-- keeps that edge with the node as reachedBy (Core/Chain.lua buildStage), because edgeType moves
-- onto the stage in front when an upward path is reversed. A later source edge that is not named
-- here falls through to the kind's glyph.
local EDGE_ICONS = {
  DROPPED_BY = "CAT_DROPS",
  SOLD_BY = "CAT_VENDOR",
  SKINNED_FROM = "CAT_SKINNING",
}

-- The kinds whose page is the only thing a click can open. A creature has no edges of its own in
-- the graph (its loot is kept out on purpose, brief E57), so re-rooting the chain on one draws an
-- empty strip: both buttons open its page instead.
local PAGE_KINDS = { npc = true }

-- How far a signpost's glyph is faded, so it reads as a sign at the end of the run rather than as
-- another step in it. The same number a predicted stage is drawn at.
Chain.QUIET_ALPHA = 0.6

-- Node kind to the Diff module kind that holds its New and Changed sets, the same table Core
-- reads. A badge cluster is told which of these it stands for so it can answer for itself.
local DIFF_KINDS = { item = "items", spell = "recipes", skill = "skills", enchant = "enchants" }

-- The kinds that are a recipe rather than a thing: both take the corner spell mark.
local SPELL_KINDS = { spell = true, enchant = true }

-- What the build says about a stage decides where it sits in a list: New first, then Changed,
-- then everything else by name. With eighty seven ways to use a bar, what the build changed is
-- what the player came to find.
local MARK_ORDER = { new = 1, changed = 2 }
local MARK_LAST = 3

local clamp = ItemTree.Util.Clamp

-- Core states the words for a co-reagent count and a tool list, so the pane and anything else
-- that says them cannot drift. Looked up rather than held, because Core loads before the UI in
-- the client but not in the spec that loads the UI files on their own.
local function coreChain()
  local core = ItemTree.Chain
  return type(core) == "table" and core or nil
end

local function coreText(name, argument, second)
  local core = coreChain()
  if not (core and type(core[name]) == "function") then
    return nil
  end
  local ok, text = pcall(core[name], argument, second)
  if ok and type(text) == "string" and text ~= "" then
    return text
  end
  return nil
end

--- "x10", "x1 to 2", "78%" or "" for a stage nothing flows into.
--
-- Core writes the arrow when it builds the stage, so that is what is drawn where it is there.
-- A stage that carries only the numbers is written the same way here, so a caller that built a
-- stage by hand still reads the same.
function Chain.ArrowText(stage)
  if type(stage) ~= "table" then
    return ""
  end
  if type(stage.arrow) == "string" and stage.arrow ~= "" then
    return stage.arrow
  end
  local quantity = tonumber(stage.quantity)
  if quantity then
    local most = tonumber(stage.quantityMax)
    if most and most > quantity then
      return string.format("x%d to %d", quantity, most)
    end
    return "x" .. tostring(quantity)
  end
  local percent = tonumber(stage.percent)
  if percent then
    local confidence = ItemTree.Confidence
    if confidence and type(confidence.Percent) == "function" then
      return confidence.Percent(percent / 100)
    end
    return string.format("%d%%", math.floor(percent + 0.5))
  end
  return ""
end

-- The average advance of the body face, as a fraction of the font size.
Chain.CHAR_W = 0.55

--- Roughly how wide a string is at one font size, in pixels.
---
--- Nothing outside the client can measure a font, so this is the body face's average advance
--- times the number of characters: near enough to size a button that also has padding either
--- side, and the same answer every time, which is what the layout spec measures against. The
--- client hands Chain.Layout a sizes.measure that asks the client itself instead.
function Chain.TextWidth(text, fontSize)
  if type(text) ~= "string" or text == "" then
    return 0
  end
  fontSize = tonumber(fontSize) or Chain.FONT_SM
  return math.ceil(#text * fontSize * Chain.CHAR_W)
end

-- Where one entry sits in a list: 1 for New, 2 for Changed, 3 for everything else.
local function markRank(entry)
  local rank = MARK_LAST
  for _, badge in ipairs(type(entry) == "table" and entry.badges or EMPTY) do
    local order = MARK_ORDER[badge]
    if order and order < rank then
      rank = order
    end
  end
  return rank
end

--- Sorts a list of drawable stages the way a drop down reads: New first, then Changed, then by
--- name, and where two read alike the order they arrived in. Stable, because a list the player
--- reopens must not shuffle under them.
function Chain.SortEntries(list)
  if type(list) ~= "table" then
    return list
  end
  local arrived = {}
  for index, entry in ipairs(list) do
    arrived[entry] = index
  end
  table.sort(list, function(a, b)
    local rankA, rankB = markRank(a), markRank(b)
    if rankA ~= rankB then
      return rankA < rankB
    end
    local nameA, nameB = a.name or "", b.name or ""
    if nameA ~= nameB then
      return nameA < nameB
    end
    return (arrived[a] or 0) < (arrived[b] or 0)
  end)
  return list
end

--- True for one of Core's two disenchant signposts: the stage after the last item of a chain that
--- says it is disenchanted rather than used any further, and its mirror in front of a chain that
--- begins on a dust, an essence or a shard. Core names the kind, so the pane files a stage by
--- what Core calls it rather than by a word of its own, and a build whose Core predates the
--- signposts answers false for every stage it will ever be handed. Pure.
function Chain.IsSignpost(stage)
  if type(stage) ~= "table" then
    return false
  end
  local core = coreChain()
  local kind = core and core.DISENCHANT_KIND
  if type(kind) ~= "string" or kind == "" then
    kind = "disenchant"
  end
  return stage.kind == kind
end

-- Items and recipes take Blizzard's quality colour, everything else body cream. Same rule as
-- the tree's rows. A signpost is quieter than either: it is not a thing the player can hold, so
-- it takes the muted grey the meta lines are drawn in.
local function nameColorFor(stage)
  if Chain.IsSignpost(stage) then
    return "ITEMTREE_COLOR_TEXT_MUTED"
  end
  if stage.kind == "item" or stage.kind == "spell" then
    return Theme.QualityKey(stage.quality)
  end
  return "ITEMTREE_COLOR_TEXT_BODY"
end

-- Brief SET1: an item set stage asks the view model for its art, the same answer the Used by
-- tree's set row wears (its head or chest piece's icon, else the Item set glyph), rather than a
-- glyph of this file's own. A lookup in the shipped records, never a client call.
local function setArt(stage)
  local viewModel = ItemTree.ViewModel
  if type(viewModel) ~= "table" or type(viewModel.SetIcon) ~= "function" then
    return nil, nil
  end
  local ok, file, asset = pcall(viewModel.SetIcon, stage.key)
  if not ok then
    return nil, nil
  end
  if asset and not Assets.Has(asset) then
    asset = nil
  end
  return file, asset
end

-- The art one stage draws: an Assets key the stage names itself, else an item set's art
-- (setArt), else a file id where the node carries one, otherwise the glyph its kind stands for,
-- and the question mark for anything left over. An Assets key is how Core says "draw this glyph"
-- without naming a texture, which is what the disenchant signposts carry; a file id or a path is
-- not a key and falls through to the art.
local function stageArt(stage)
  if type(stage.icon) == "string" and Assets.Has(stage.icon) then
    return nil, stage.icon
  end
  if stage.kind == "set" then
    local file, asset = setArt(stage)
    if file or asset then
      return file, asset
    end
  end
  local glyph = EDGE_ICONS[stage.reachedBy] or NODE_ICONS[stage.kind]
  if glyph and not Assets.Has(glyph) then
    glyph = NODE_ICONS[stage.kind]
  end
  if glyph and Assets.Has(glyph) then
    return nil, glyph
  end
  if stage.icon then
    return stage.icon, nil
  end
  if stage.kind == "item" and type(Assets.ItemIcon) == "function" then
    local ok, icon = pcall(Assets.ItemIcon, tonumber(stage.id))
    if ok and icon then
      return icon, nil
    end
  end
  return nil, "ICON_QUESTIONMARK"
end

-- The corner mark an item stage wears about how much ItemTree can tell the player, and the
-- Assets key it is drawn with. The rule is Core's (Core/Graph.lua Graph.DiscoveryMark), the same
-- one the tree row, the Discoveries row and the info column's header ask, so the four surfaces
-- can never disagree about what a mark means.
--
-- E39: Core/Chain.lua carries both halves of the fact onto a stage now, so a stage that states
-- it has been discovered is read where it stands: Graph.DiscoveryMark is pure and looks nothing
-- up. Only a stage that says nothing either way falls through to the id lookup, for that one id
-- and never a list, because a stage with no word on it may still be an id the client has named
-- since. Every other stage asks nothing at all, and in an ordinary chain not one is withheld.
local function stageDiscovery(stage)
  if type(stage) ~= "table" or stage.kind ~= "item" or not stage.undiscovered then
    return nil
  end
  local graph = ItemTree.Graph
  if type(graph) ~= "table" then
    return nil
  end
  local mark, art
  if stage.discovered ~= nil and type(graph.DiscoveryMark) == "function" then
    local asked, answer, glyph = pcall(graph.DiscoveryMark, stage)
    if asked and type(answer) == "string" then
      mark, art = answer, glyph
    end
  end
  if not mark then
    if type(graph.ItemDiscoveryMark) ~= "function" then
      return nil
    end
    local ok, answer, glyph = pcall(graph.ItemDiscoveryMark, tonumber(stage.id))
    if not ok or type(answer) ~= "string" then
      return nil
    end
    mark, art = answer, glyph
  end
  if type(art) ~= "string" or not Assets.Has(art) then
    return mark, nil
  end
  return mark, art
end

--- What the corner mark on a stage says in words, or nothing for a stage that wears no mark and
--- for the mark that needs none. Core owns the wording for the same reason it owns the rule.
function Chain.DiscoveryText(model)
  local mark = type(model) == "table" and model.discovery or nil
  local graph = ItemTree.Graph
  if type(mark) ~= "string" or type(graph) ~= "table" or type(graph.DiscoveryMarkText) ~= "function" then
    return nil
  end
  local ok, text = pcall(graph.DiscoveryMarkText, mark)
  if not ok or type(text) ~= "string" or text == "" then
    return nil
  end
  return text
end

--- One drawable co-reagent: the other items a recipe needs alongside the one the chain
--- follows. Always an item, so it takes the quality colour and an item's art.
function Chain.CoReagentModel(entry)
  entry = type(entry) == "table" and entry or EMPTY
  local quantity = tonumber(entry.quantity)
  local model = {
    key = entry.key,
    name = entry.name or entry.key or "",
    slot = tonumber(entry.slot),
    quality = entry.quality,
    nameColor = Theme.QualityKey(entry.quality),
    quantity = quantity,
    quantityText = quantity and ("x" .. tostring(quantity)) or "",
  }
  model.iconFile, model.iconAsset = stageArt({ kind = "item", icon = entry.icon, id = entry.id })
  return model
end

--- One drawable stage: what the slot shows, what a click on it re-roots to, and the two lists
--- it can drop down (the stages that could stand in its slot, and the reagents the recipe in
--- front of it needs alongside it).
---
--- Alternatives are modelled the same way, one level deep: Core hands every alternative an
--- empty alternatives list of its own, so the shape is the same all the way down. pinned is
--- what the pane knows and Core does not: this stage is the one the player pinned in its slot.
function Chain.StageModel(stage, isRoot, pinned)
  stage = type(stage) == "table" and stage or EMPTY
  local model = {
    key = stage.key,
    kind = stage.kind,
    id = stage.id,
    itemId = stage.kind == "item" and tonumber(stage.id) or nil,
    name = stage.name or stage.key or "",
    meta = (type(stage.meta) == "string" and stage.meta ~= "") and stage.meta or nil,
    skill = stage.skill,
    quality = stage.quality,
    nameColor = nameColorFor(stage),
    confidence = stage.confidence,
    predicted = stage.confidence == "predicted",
    root = isRoot and true or false,
    pinned = pinned and true or false,
    slot = tonumber(stage.slot),
    edgeType = stage.edgeType,
    diffKind = DIFF_KINDS[stage.kind],
    spellMark = SPELL_KINDS[stage.kind] == true,
    arrow = Chain.ArrowText(stage),
    badges = Badges.Sort(stage.badges, Chain.BADGE_MAX),
    alternatives = {},
    coReagents = {},
  }
  -- A signpost is not a node: it has no key to re-root on, no quality, no recipe mark and no
  -- badges, and what a click on it opens is the stage it belongs to rather than itself.
  model.signpost = Chain.IsSignpost(stage)
  if model.signpost then
    model.of = stage.of
    model.view = stage.view
    model.leading = stage.leading and true or false
    model.spellMark = false
    model.quiet = true
  end
  model.tools = coreText("ToolsText", stage.tools)
  model.iconFile, model.iconAsset = stageArt(stage)
  -- The corner glyph, and there is only ever one: a stage is a recipe or an item, never both, so
  -- the blue flame and a withheld item's mark share the one texture the slot draws.
  model.discovery, model.markAsset = stageDiscovery(stage)
  if model.spellMark then
    model.markAsset = Chain.SPELL_MARK_ASSET
  end
  for _, other in ipairs(type(stage.alternatives) == "table" and stage.alternatives or EMPTY) do
    model.alternatives[#model.alternatives + 1] = Chain.StageModel(other, false, false)
  end
  for _, other in ipairs(type(stage.coReagents) == "table" and stage.coReagents or EMPTY) do
    model.coReagents[#model.coReagents + 1] = Chain.CoReagentModel(other)
  end
  Chain.SortEntries(model.alternatives)
  model.alternativeCount = #model.alternatives
  model.coReagentCount = #model.coReagents
  -- What a stage is needed alongside is a quest's other items or a recipe's other reagents, and
  -- Core says which wording that is, so the button and the list never disagree about the words.
  model.coReagentKind = stage.coReagentKind
  model.coReagentText = coreText("CoReagentsText", model.coReagentCount, model.coReagentKind)
  -- The meta row draws whatever the stage states about itself. A recipe that states nothing
  -- else says what it asks the player to be holding instead, and a quest says that it is one,
  -- because a quest carries no quality, no skill and no arrow numbers to read it by.
  model.metaLine = model.meta or model.tools
  if not model.metaLine and stage.kind == "quest" then
    model.metaLine = L["Quest"]
  end
  return model
end

--- What a click on a stage does: "tree", "reroot" or "none".
---
--- A left click on any stage is the player asking for that item, so the window opens it on a list
--- view (Frame.RowView: the last of Used by, Sources and the rest the player was on). Re-rooting the
--- chain and then asking for the lists was two clicks for the one thing the player wanted, and the
--- first of them landed them on the same pane they were already on.
--- A right click is the other half: it re-roots the strip in place and stays on the chain,
--- which is how a chain is still explored a step at a time. The root stage has nothing to
--- re-root to, so its right click does nothing at all. Pure, so the decision is stated in one
--- place and the hint lines and the click read the same answer. Anything that is not the right
--- button is a left click, which is every button the stage registers.
---
--- N1: a creature stage opens its page on either button. It has no edges of its own, so a chain
--- re-rooted on it would be empty. kind is the stage's node kind; a caller that does not state it
--- has it read off the key.
function Chain.StageClickAction(clickedKey, rootKey, button, kind)
  if button ~= "RightButton" then
    return "tree"
  end
  if kind == nil and type(clickedKey) == "string" then
    kind = clickedKey:match("^(%a+):")
  end
  if kind ~= nil and PAGE_KINDS[kind] then
    return "tree"
  end
  if type(clickedKey) == "string" and clickedKey ~= "" and clickedKey ~= rootKey then
    return "reroot"
  end
  return "none"
end

--- The lines the stage tooltip ends on, which say what each button does: what a click does
--- first, then what a right click does where there is a chain left to follow. The second is nil
--- at the root, where a right click does nothing, and on a creature, where a right click opens
--- its page just as a left click does and "Click" already says so. Pure.
function Chain.StageClickHint(clickedKey, rootKey, kind)
  local follow = nil
  if Chain.StageClickAction(clickedKey, rootKey, "RightButton", kind) == "reroot" then
    follow = L["Right click to follow the chain from here"]
  end
  return L["Click to open its page"], follow
end

--- What a click on a disenchant signpost does: "view" with the node to open and the view to open
--- it on, or "none".
---
--- A left click is the player asking to see the results themselves, which live in the tree. They
--- belong to the stage the signpost stands after, never to the chain's own root: standing on
--- Arcane Crystal and clicking the Disenchants drawn after Dawnbringer Shoulders asks for the
--- shoulders' results and not the crystal's. The leading signpost is the mirror, and opens the
--- stage in front of it on its Sources view.
---
--- A right click does nothing at all. Every other stage re-roots the chain on a right click, and
--- a signpost is not a node: there is nothing to re-root on. Pure.
function Chain.SignpostClickAction(model, button)
  if type(model) ~= "table" or not model.signpost then
    return "none"
  end
  if button == "RightButton" then
    return "none"
  end
  if type(model.of) ~= "string" or model.of == "" then
    return "none"
  end
  return "view", model.of, model.view
end

--- The one line a disenchant signpost's tooltip says under its name: what the sign stands for and
--- what a click on it does. The leading signpost says the mirror of it. Pure.
function Chain.SignpostTooltip(model)
  if type(model) ~= "table" or not model.signpost then
    return nil
  end
  if model.leading then
    return L["Disenchanted from the usual pieces of equipment. Click to see them on the Sources tab."]
  end
  return L["Disenchants into the usual dusts, essences and shards. Click to see them on the Disenchants into tab."]
end

--- Where every stage and every arrow sits, at 1x, measured from the top left of the content.
---
--- x runs left to right and y runs down, because that is how the strip reads and it keeps the
--- pan arithmetic in one direction; the client negates y once, when it anchors a frame.
--- sizes overrides any of stage, gap, arrow, icon, line, pad and control, which is what lets
--- the spec lay a chain out at sizes it can check by hand.
---
--- Returns { stages, arrows, width, height, rootIndex, rootX, rootCentre, rows } where rows
--- carries the y of the icon, the name, the meta line and the two controls inside every slot,
--- all of which are the same for every stage so the strip reads as one row. An arrow rect
--- states the centre line its shaft and its head share, which is the icon's own centre line.
---
--- A slot is as wide as the widest control it carries: "+ 2 other reagents" is longer than 96px
--- of slot and used to be drawn straight through the button's own edge. The slot grows for it,
--- up to maxStage, and the control is its text plus padding inside that. The gap between two
--- slots grows the same way, for the longest arrow label in the chain, so "x2 to 3" is not cut
--- to "x2 t...". Widths come from sizes.measure where the caller can measure a string and from
--- Chain.TextWidth where nothing can.
function Chain.Layout(stages, rootIndex, sizes)
  stages = type(stages) == "table" and stages or EMPTY
  sizes = type(sizes) == "table" and sizes or EMPTY
  local stageW = tonumber(sizes.stage) or Chain.STAGE_W
  local maxStage = tonumber(sizes.maxStage) or Chain.STAGE_MAX_W
  if maxStage < stageW then
    maxStage = stageW
  end
  local gap = tonumber(sizes.gap) or Chain.GAP
  local arrowW = tonumber(sizes.arrow) or Chain.ARROW
  local icon = tonumber(sizes.icon) or Chain.ICON
  local line = tonumber(sizes.line) or Chain.LINE
  local pad = tonumber(sizes.pad) or Chain.PAD
  local top = tonumber(sizes.top) or Chain.TOP_PAD
  local control = tonumber(sizes.control) or Chain.CONTROL_H
  local fontSize = tonumber(sizes.font) or Chain.FONT_SM
  local measure = type(sizes.measure) == "function" and sizes.measure or nil
  rootIndex = tonumber(rootIndex) or 0

  local function widthOf(text)
    if type(text) ~= "string" or text == "" then
      return 0
    end
    if measure then
      local ok, value = pcall(measure, text)
      value = ok and tonumber(value) or nil
      if value and value > 0 then
        return math.ceil(value)
      end
    end
    return Chain.TextWidth(text, fontSize)
  end

  local total = #stages
  local hasMeta, hasAlternatives, hasCoReagents = false, false, false
  -- One pass for what every slot carries, so the run can be sized before any of it is placed.
  local columns = {}
  for index, stage in ipairs(stages) do
    local column = { alternatives = 0, coReagents = 0, width = stageW }
    if type(stage) == "table" then
      local tools = type(stage.tools) == "table" and #stage.tools > 0
      if (type(stage.meta) == "string" and stage.meta ~= "") or tools then
        hasMeta = true
      end
      if type(stage.alternatives) == "table" then
        column.alternatives = #stage.alternatives
      end
      if type(stage.coReagents) == "table" then
        column.coReagents = #stage.coReagents
      end
      if column.alternatives > 0 then
        hasAlternatives = true
      end
      if column.coReagents > 0 then
        hasCoReagents = true
      end
    end
    column.altText = Chain.AlternativesText(column.alternatives)
    column.coText = coreText("CoReagentsText", column.coReagents)
    column.altWidth = column.altText and (widthOf(column.altText) + pad * 2) or 0
    column.coWidth = column.coText and (widthOf(column.coText) + pad * 2) or 0
    local widest = column.altWidth > column.coWidth and column.altWidth or column.coWidth
    local wanted = widest + pad * 2
    if wanted > column.width then
      column.width = wanted < maxStage and wanted or maxStage
    end
    local room = column.width - pad * 2
    if column.altWidth > room then
      column.altWidth = room
    end
    if column.coWidth > room then
      column.coWidth = room
    end
    columns[index] = column
  end

  -- The gap holds the longest label in the chain, whatever that costs, because every gap is the
  -- same width and a label wider than its own gap is the one that reads as cut off.
  local arrowText = {}
  for index = 2, total do
    local text = Chain.ArrowText(stages[index])
    arrowText[index] = text
    local wanted = widthOf(text) + pad * 2
    if wanted > arrowW then
      arrowW = wanted
    end
  end
  local span = gap + arrowW

  -- The name is given two lines: at 96px most item names take them, and a slot that grew for
  -- the longest name would put every other icon at a different height.
  local rows = { icon = top, name = top + icon + pad }
  local bottom = rows.name + line * 2
  if hasMeta then
    rows.meta = bottom
    bottom = bottom + line
  end
  if hasAlternatives then
    rows.control = bottom + pad
    bottom = rows.control + control
  end
  if hasCoReagents then
    rows.co = bottom + pad
    bottom = rows.co + control
  end

  local layout = {
    stages = {},
    arrows = {},
    width = 0,
    height = total > 0 and (bottom + pad) or 0,
    stage = stageW,
    gap = gap,
    arrow = arrowW,
    icon = icon,
    line = line,
    pad = pad,
    top = top,
    control = control,
    rows = rows,
    meta = hasMeta,
    alternatives = hasAlternatives,
    coReagents = hasCoReagents,
    rootIndex = rootIndex,
    rootX = 0,
    rootCentre = 0,
  }
  if total == 0 then
    return layout
  end

  -- The arrow block is the quantity over a shaft, and the shaft and the head both sit on the
  -- icon's own centre line, which is the bottom edge of the rect, so the chain reads as one
  -- run rather than a row of cards.
  local arrowH = line + 4
  local centre = top + icon / 2

  local x = 0
  for index, stage in ipairs(stages) do
    local column = columns[index]
    layout.stages[index] = {
      index = index,
      key = type(stage) == "table" and stage.key or nil,
      x = x,
      y = 0,
      width = column.width,
      height = layout.height,
      root = index == rootIndex,
      alternatives = column.alternatives,
      coReagents = column.coReagents,
      altText = column.altText,
      altWidth = column.altWidth,
      coText = column.coText,
      coWidth = column.coWidth,
    }
    if index > 1 then
      layout.arrows[#layout.arrows + 1] = {
        into = index,
        x = x - span + gap / 2,
        y = centre - arrowH,
        width = arrowW,
        height = arrowH,
        centre = centre,
        text = arrowText[index],
      }
    end
    x = x + column.width + span
  end

  layout.width = x - span
  local root = layout.stages[rootIndex]
  if root then
    layout.rootX = root.x
    layout.rootCentre = root.x + root.width / 2
  end
  return layout
end

--- The zoom that fits contentW into viewportW, never past maxZoom (1.0 by default, because a
--- short chain blown up reads as a mistake) and never under minZoom, so a very long chain
--- stops shrinking and is panned instead. viewportW is the width the caller will actually
--- draw in, padding already taken off.
function Chain.FitZoom(contentW, viewportW, minZoom, maxZoom)
  local low = tonumber(minZoom) or Chain.ZOOM_MIN
  local high = tonumber(maxZoom) or Chain.FIT_MAX
  contentW = tonumber(contentW) or 0
  viewportW = tonumber(viewportW) or 0
  if contentW <= 0 or viewportW <= 0 then
    return high
  end
  return clamp(viewportW / contentW, low, high)
end

--- The pan that keeps whatever is under pointerX under it while the zoom changes from zoom to
--- newZoom. pointerX and panX are both viewport pixels, measured from the viewport's left. The
--- same arithmetic holds down the other axis, measured from the viewport's top, and the pane
--- runs it once per axis on every wheel step.
function Chain.ZoomAbout(zoom, newZoom, pointerX, panX)
  zoom = tonumber(zoom) or 1
  newZoom = tonumber(newZoom) or zoom
  pointerX = tonumber(pointerX) or 0
  panX = tonumber(panX) or 0
  if zoom <= 0 then
    return panX
  end
  return pointerX - (pointerX - panX) * (newZoom / zoom)
end

--- The cursor, in the viewport's own units, measured from the viewport's top left with y
--- running down the way the layout does.
---
--- Three coordinate systems meet here and getting any of them wrong is what makes a zoom feel
--- as though it happens somewhere else:
---   cursorX, cursorY  screen pixels, which is what GetCursorPosition answers in.
---   left, top         the viewport's own edges, in the viewport's scaled units, which is what
---                     GetLeft and GetTop answer in.
---   scale             the viewport's effective scale, which carries the window's own SetScale
---                     and UIParent's, and turns the one into the other.
--- The canvas's SetScale is deliberately not in it: the canvas is what is being zoomed, and a
--- pan is held in the viewport's units on the outside of it.
--- Returns nil where the client would not answer, so the caller can fall back to the middle.
function Chain.ViewportPoint(cursorX, cursorY, left, top, scale)
  cursorX, cursorY = tonumber(cursorX), tonumber(cursorY)
  left, top = tonumber(left), tonumber(top)
  scale = tonumber(scale) or 1
  if not (cursorX and cursorY and left and top) or scale <= 0 then
    return nil
  end
  return cursorX / scale - left, top - cursorY / scale
end

--- The arrow shaft at one zoom: how thick to draw it in canvas units, and how far to move its
--- centre line so both of its edges land on whole viewport pixels.
---
--- A hairline on a canvas scaled to 0.75 is three quarters of a pixel and the client draws it
--- as a grey smear half a pixel off the icon's middle. Rounding the thickness up to a whole
--- pixel and then rounding the line itself onto the pixel grid is what keeps it a line at
--- every zoom. centre is the line's y in canvas units, pan is the viewport pixel the canvas's
--- own top sits on, and the offset comes back in canvas units, positive downwards.
function Chain.SnapShaft(centre, zoom, thickness, pan)
  centre = tonumber(centre) or 0
  zoom = tonumber(zoom) or 1
  if zoom <= 0 then
    zoom = 1
  end
  thickness = tonumber(thickness) or Chain.BORDER
  pan = tonumber(pan) or 0
  local pixels = math.floor(thickness * zoom + 0.5)
  if pixels < 1 then
    pixels = 1
  end
  local top = centre * zoom + pan - pixels / 2
  local snapped = math.floor(top + 0.5)
  return pixels / zoom, (snapped - top) / zoom
end

--- The pan that puts one content point in the middle of the viewport.
function Chain.CentrePan(centre, viewportW, zoom)
  centre = tonumber(centre) or 0
  viewportW = tonumber(viewportW) or 0
  zoom = tonumber(zoom) or 1
  return viewportW / 2 - centre * zoom
end

--- The pixels a supplied medallion stands proud of its badge frame on each side: the art is drawn
--- a step up the size ladder (Badges.ArtSize), 18 on a 16 badge, so one pixel. Pure.
function Chain.BadgeOverhang(size)
  local wanted = tonumber(size) or Chain.BADGE
  local art = wanted
  if type(Badges) == "table" and type(Badges.ArtSize) == "function" then
    local ok, value = pcall(Badges.ArtSize, wanted)
    if ok and tonumber(value) then
      art = tonumber(value)
    end
  end
  return math.max(0, math.ceil((art - wanted) / 2))
end

--- Where a stage's badge cluster sits: point, relativePoint on the icon, x and y. Brief E82: the
--- cluster used to hang 3px past the icon's top right corner, and the infinity medallion, which
--- has no transparent corners the way the old star had, showed the cut along its top and right
--- edges. It now sits inside the icon's corner, inset by the medallion's own overhang, so the
--- art ends on the icon's edge, the way the bag overlay puts its badges inside the slot. Pure.
function Chain.BadgeAnchor(size)
  local inset = Chain.BadgeOverhang(size)
  return "TOPRIGHT", "TOPRIGHT", -inset, -inset
end

--- Pan held inside the content, so the chain can never be lost off screen: an edge is the most
--- that can leave the viewport, and an axis the content already fits on is centred instead.
function Chain.ClampPan(panX, panY, contentW, contentH, viewportW, viewportH, zoom)
  panX = tonumber(panX) or 0
  panY = tonumber(panY) or 0
  zoom = tonumber(zoom) or 1
  local width = (tonumber(contentW) or 0) * zoom
  local height = (tonumber(contentH) or 0) * zoom
  viewportW = tonumber(viewportW) or 0
  viewportH = tonumber(viewportH) or 0
  local x, y
  if width <= viewportW then
    x = (viewportW - width) / 2
  else
    x = clamp(panX, viewportW - width, 0)
  end
  if height <= viewportH then
    y = (viewportH - height) / 2
  else
    y = clamp(panY, viewportH - height, 0)
  end
  return x, y
end

--- "85%", the way the corner readout writes the zoom.
function Chain.ZoomText(zoom)
  return string.format("%d%%", math.floor((tonumber(zoom) or 1) * 100 + 0.5))
end

--- The label on a stage's alternatives control, or nil when it has none to offer.
function Chain.AlternativesText(count)
  count = tonumber(count) or 0
  if count < 1 then
    return nil
  end
  if count == 1 then
    return L["1 alternative"]
  end
  return string.format(L["%d alternatives"], count)
end

--- The chain selector: what its button reads and what its list offers. Core hands back every
--- chain worth offering through the root, best first, already labelled "First stage to Last
--- stage", and says which of them is the one drawn. One chain is no choice at all, which is
--- what shown answers.
function Chain.SelectorModel(full)
  full = type(full) == "table" and full or EMPTY
  local choices = type(full.choices) == "table" and full.choices or EMPTY
  local model = { entries = {}, count = #choices, label = "", shown = false }
  for index, choice in ipairs(choices) do
    local names = {}
    for at, name in ipairs(type(choice.names) == "table" and choice.names or EMPTY) do
      names[at] = name
    end
    model.entries[index] = {
      id = choice.id,
      label = (type(choice.label) == "string" and choice.label ~= "") and choice.label or tostring(choice.id or ""),
      current = choice.id ~= nil and choice.id == full.choice,
      -- The stages that chain runs through, in order, for the row's own tooltip: a label wider
      -- than the list is cut, and the cut is exactly where two chains start to differ.
      names = names,
    }
  end
  if type(full.label) == "string" and full.label ~= "" then
    model.label = full.label
  elseif model.entries[1] then
    model.label = model.entries[1].label
  end
  model.shown = model.count > 1
  return model
end

--------------------------------------------------------------------------------
-- The menu pick trail
--------------------------------------------------------------------------------
-- The last few picks out of the three drop down lists, kept in memory for the session and
-- printed by "/itemtree debug" under a Chain heading. This exists because the pane cannot be
-- run under busted the way the client runs it: a pick that is lost between the mouse going down
-- and coming up leaves no trace at all, and the owner has now reported the same silent failure
-- twice with nothing to hand over but a screenshot. Each entry says what was clicked, the pin or
-- the choice that was written, how many chains came back, the chain that was drawn, and any
-- error the pick raised.
--
-- Nothing is saved: no saved variables, no character, no realm, no account. Keys, slots, counts
-- and the labels already drawn on the screen.

-- One line per pick, newest last. Pure: it reads the list it is handed and writes nothing.
function Chain.TrailLines(trail)
  trail = type(trail) == "table" and trail or EMPTY
  local lines = {}
  for index, entry in ipairs(trail) do
    if type(entry) == "table" then
      local parts = { string.format("%d. %s", index, tostring(entry.kind or "menu")) }
      if type(entry.label) == "string" and entry.label ~= "" then
        parts[#parts + 1] = string.format("%q", entry.label)
      end
      if entry.pin then
        parts[#parts + 1] = "pin " .. tostring(entry.pin)
      end
      if entry.choice then
        parts[#parts + 1] = "choice " .. tostring(entry.choice)
      end
      if entry.chains then
        local chains = tonumber(entry.chains) or 0
        parts[#parts + 1] = string.format("%d chain%s back", chains, chains == 1 and "" or "s")
      end
      if entry.chain then
        parts[#parts + 1] = "drew " .. tostring(entry.chain)
      end
      if entry.dropped then
        parts[#parts + 1] = "dropped " .. tostring(entry.dropped)
      end
      if entry.err then
        parts[#parts + 1] = "ERROR " .. tostring(entry.err)
      end
      lines[#lines + 1] = table.concat(parts, ", ")
    end
  end
  if #lines == 0 then
    return { "Chain: no menu picks this session" }
  end
  table.insert(lines, 1, string.format("Chain: last %d menu pick%s", #lines, #lines == 1 and "" or "s"))
  return lines
end

--------------------------------------------------------------------------------
-- The held chains (brief SF1)
--------------------------------------------------------------------------------
-- CH1's queued note (QA item 295): every window refresh handed the pane its root again and the
-- pane asked Core for the whole chain again, 20 to 37 ms on the worst roots, though nothing it
-- reads had moved. The pane holds what Core built, per root and per what it asked (the choice,
-- the pins, the reagent the player came from), and lets every held chain go the moment anything
-- else the chain reads moves: the "Show predicted data" and "Hide other faction data" settings,
-- the character's side, the settings that change what the data reads (Classic Era details,
-- harvested items, minor changes) and the data itself (Core/Data.lua's generation, which a reload
-- of the tables or one of those settings bumps, and Core/Collector.lua's, which every record the
-- player's own collector writes bumps).
-- Brief FX-AG2 (FR-AG2's M2): Merge recipes and the provider layer's switch are read at call time
-- too, so they are in the stamp; and since a setting added later could be missed here, every
-- setting changed through UI/Options.lua's OnChanged lets the held chains go as well.

-- How many chains the pane holds at once: the root on screen and the few the player stepped
-- between or pinned their way through, the oldest going first. The worst roots' chains (Thorium
-- Bar, Thick Leather) hold about 190 KB each over data 6829fdba, so four is under 1 MB, and all of
-- it goes when the pane hides.
Chain.CACHE_MAX = 4

-- The facts a held chain is told apart by, in the order the stamp joins them.
Chain.CACHE_FACTS = {
  "showPredicted",
  "hideOtherFaction",
  "side",
  "eraDetails",
  "harvested",
  "includeMinor",
  -- Brief FX-AG2: Merge recipes folds a set's unnamed pieces into their named twins
  -- (Core/Graph.lua Graph.FoldsSetTwins), and the provider layer's switch adds or takes away every
  -- edge an installed source addon answers (Providers/Registry.lua Registry.Enabled).
  "mergeCrafts",
  "useProviders",
  "data",
  "dataGeneration",
  "collectorGeneration",
}

--- The two strings a built chain is held under: the entry's key (the root, the choice, the pins by
--- slot and the reagent the player came from, as the pane hands them to Core) and the stamp (every
--- fact in Chain.CACHE_FACTS; a stamp that differs from the held one lets every held chain go).
--- opts is the pane's ask ({ choice, pins, prefer }), facts the table the client side reads. Pure.
function Chain.CacheKey(rootKey, opts, facts)
  opts = type(opts) == "table" and opts or EMPTY
  facts = type(facts) == "table" and facts or EMPTY
  local pins = {}
  for slot, key in pairs(type(opts.pins) == "table" and opts.pins or EMPTY) do
    pins[#pins + 1] = tostring(slot) .. "=" .. tostring(key)
  end
  table.sort(pins)
  local key = table.concat({
    tostring(rootKey),
    tostring(opts.choice),
    table.concat(pins, ","),
    tostring(opts.prefer),
  }, "|")
  local stamp = {}
  for index, name in ipairs(Chain.CACHE_FACTS) do
    stamp[index] = tostring(facts[name])
  end
  return key, table.concat(stamp, "|")
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

Chain.stageFrames = {}
Chain.arrowFrames = {}
Chain.menuRows = {}
-- The list in hand, how far down it the drawn rows start, how wide it is and whether it is long
-- enough to scroll. The last two are what tell a label that fits from one the list has cut.
Chain.menuEntries = nil
Chain.menuOffset = 0
Chain.menuWidth = nil
Chain.menuScrolls = false
Chain.zoom = 1
Chain.panX, Chain.panY = 0, 0
-- Session state, reset whenever the root changes: the chain the player picked in the selector,
-- the stages they pinned by slot, and the node they navigated from.
Chain.pins = {}
Chain.choice = nil
Chain.prefer = nil
-- The menu pick trail, and the entry a pick in flight is filling in. Chain.TrailLines above
-- turns the first into the lines "/itemtree debug" prints.
Chain.trail = {}
Chain.pick = nil

local globalFn = ItemTree.Util.GlobalFn

-- Brief E91: the list's keyboard, which is combat safe. SetPropagateKeyboardInput is refused in
-- combat lockdown on the Forever client, so the list never decides propagation then: it takes the
-- keyboard only out of combat, with propagation on, lets it go on PLAYER_REGEN_DISABLED (before
-- the lockdown, through UI/Frame.lua's Frame.OnCombatStart) and takes it back as combat ends. In
-- combat Escape therefore reaches the client's CloseSpecialWindows and closes the window.
local function inCombat()
  local lockdown = globalFn("InCombatLockdown")
  if not lockdown then
    return false
  end
  local ok, locked = pcall(lockdown)
  return (ok and locked) and true or false
end

local function menuPropagate(menu, on)
  if inCombat() or type(menu) ~= "table" or type(menu.SetPropagateKeyboardInput) ~= "function" then
    return false
  end
  return (pcall(menu.SetPropagateKeyboardInput, menu, on))
end

local function menuKeyboard(menu, on)
  if type(menu) == "table" and type(menu.EnableKeyboard) == "function" then
    pcall(menu.EnableKeyboard, menu, on)
  end
end

-- Takes the keyboard for a list going up, out of combat only. Answers whether it holds it.
local function takeMenuKeyboard(menu)
  if inCombat() then
    menuKeyboard(menu, false)
    return false
  end
  menuPropagate(menu, true)
  menuKeyboard(menu, true)
  return true
end

-- One interface cue, by name. UI/Sound.lua owns which sound a cue is and whether cues are on at
-- all; this is the one line a call site writes. Looked up at call time, because a spec loads this
-- file on its own and a build without the module must cost the cue and nothing else.
local playCue = ItemTree.UI.Sound.PlayCue

-- One CreateFrame call, pcall'd. Nothing here is templated, so a client that carries no
-- template at all still draws the whole pane; a client with no CreateFrame gets nothing, which
-- is what leaves Attach returning false under busted.
local function newFrame(kind, parent)
  local create = globalFn("CreateFrame")
  if not create then
    return nil
  end
  local ok, frame = pcall(create, kind, nil, parent)
  if ok and frame then
    return frame
  end
  return nil
end

-- True when the frame admits to a script type. A client that has dropped one raises when it is
-- given a handler, so nothing is set without asking first, and a frame with no HasScript at
-- all is taken at its word. Same idiom as UI/Minimap.lua and UI/Tooltip.lua.
local hasScript = ItemTree.Util.HasScript

local function setScript(frame, script, handler)
  if type(frame.SetScript) ~= "function" or not hasScript(frame, script) then
    return false
  end
  return (pcall(frame.SetScript, frame, script, handler))
end

-- Which presses a button answers, in the modern shape first and the classic one after, each
-- pcall'd, the way every other two signature call in this addon is tried. Answers the shape that
-- took, or nil where the client would take neither, so a spec can read what was asked for.
local function registerClicks(frame, modern, classic)
  if type(frame) ~= "table" or type(frame.RegisterForClicks) ~= "function" then
    return nil
  end
  if pcall(frame.RegisterForClicks, frame, unpack(modern)) then
    return modern
  end
  if classic and pcall(frame.RegisterForClicks, frame, unpack(classic)) then
    return classic
  end
  return nil
end

-- Theme.Color raises on an unknown key, so the table is read instead and a missing key leaves
-- the region's own colour alone. Same idiom as UI/Report.lua.
local function tint(region, key, alpha)
  local colour = key and Theme.ColorTable(key) or nil
  if not colour or type(region.SetVertexColor) ~= "function" then
    return false
  end
  region:SetVertexColor(colour.r, colour.g, colour.b)
  if type(region.SetAlpha) == "function" then
    region:SetAlpha(alpha or colour.a or 1)
  end
  return true
end

local function textColor(fontString, key, alpha)
  local colour = key and Theme.ColorTable(key) or nil
  if not colour or type(fontString.SetTextColor) ~= "function" then
    return false
  end
  fontString:SetTextColor(colour.r, colour.g, colour.b, alpha or colour.a or 1)
  return true
end

--------------------------------------------------------------------------------
-- Font safety
--------------------------------------------------------------------------------

-- Hands the font string one of the client's own font objects. Nothing here can raise, and a
-- client carrying none of them answers false, which is as far as this file can go.
local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(Chain.FONT_FALLBACKS) do
    local object = rawget(_G, name)
    if object ~= nil then
      local ok, applied = pcall(fontString.SetFontObject, fontString, object)
      if ok and applied ~= false then
        return true
      end
    end
  end
  return false
end

-- Whether the client says this font string has a font. One that cannot be asked reads as
-- having none, so a font object is put on it anyway: setting one twice costs nothing.
local function hasFont(fontString)
  if type(fontString) ~= "table" or type(fontString.GetFont) ~= "function" then
    return false
  end
  local ok, face = pcall(fontString.GetFont, fontString)
  if not ok then
    return false
  end
  return face ~= nil and face ~= ""
end

local function ensureFont(fontString)
  if hasFont(fontString) then
    return true
  end
  return fallbackFont(fontString)
end

-- A font string that is never fontless. The client's own font object is asked for at creation,
-- through the template argument where the client takes one and by hand where it does not, so
-- a SetText is never the first thing to touch the font.
local function newFontString(parent, layer)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, layer, Chain.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, layer)
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  return fontString
end

-- Body face, 1px shadow. SetFont answers false rather than raising where the client cannot
-- load the face, so the answer is read and a font object put back: a font string that lost its
-- font raises from inside the next SetText.
local function styleText(fontString, fontSize, colorKey, justify)
  if type(fontString) ~= "table" then
    return nil
  end
  local face = Theme.fonts and Theme.fonts.ITEMTREE_FONT_BODY
  if face and type(fontString.SetFont) == "function" then
    local ok, applied = pcall(fontString.SetFont, fontString, face, fontSize, "")
    if not ok or applied == false then
      fallbackFont(fontString)
    end
  end
  ensureFont(fontString)
  local outline = Theme.text and Theme.text.ITEMTREE_TEXT_OUTLINE
  if outline and type(fontString.SetShadowOffset) == "function" then
    fontString:SetShadowOffset(outline.x, outline.y)
    if type(fontString.SetShadowColor) == "function" then
      fontString:SetShadowColor(outline.r, outline.g, outline.b, outline.a)
    end
  end
  if type(fontString.SetJustifyH) == "function" then
    fontString:SetJustifyH(justify or "CENTER")
  end
  textColor(fontString, colorKey)
  return fontString
end

local function newText(parent, fontSize, colorKey, justify)
  local fontString = newFontString(parent, "OVERLAY")
  if not fontString then
    return nil
  end
  return styleText(fontString, fontSize, colorKey, justify)
end

-- Every word this pane draws goes through here. The font is put back first, and the write
-- itself is pcalled, so a client that can give a font string no font at all costs the pane a
-- blank label rather than the whole draw.
local function setText(fontString, text)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  ensureFont(fontString)
  return (pcall(fontString.SetText, fontString, text or ""))
end

--------------------------------------------------------------------------------
-- Textures
--------------------------------------------------------------------------------

-- A flat fill in one Theme colour. Every texture goes through Assets so the path lives in one
-- table and the harness can report it.
local function wash(parent, layer, colorKey)
  if type(parent.CreateTexture) ~= "function" then
    return nil
  end
  local texture = parent:CreateTexture(nil, layer)
  if not texture then
    return nil
  end
  if Assets and type(Assets.Apply) == "function" then
    pcall(Assets.Apply, texture, "FILL_WHITE8X8")
  end
  tint(texture, colorKey)
  return texture
end

-- The design's InsetPanel edge: four hairlines in one Theme colour, drawn by hand. Not a nine
-- slice, because the live clients' NineSliceUtil is atlas oriented and a file layout renders
-- as a dotted edge. See docs/design-deviations.md.
local function insetBorder(frame, colorKey)
  local edges = {}
  for index = 1, 4 do
    edges[index] = wash(frame, "BORDER", colorKey)
    if not edges[index] then
      return nil
    end
    edges[index]:Show()
  end
  local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
  top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  top:SetHeight(Chain.BORDER)
  bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(Chain.BORDER)
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  left:SetWidth(Chain.BORDER)
  right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  right:SetWidth(Chain.BORDER)
  return { top = top, bottom = bottom, left = left, right = right }
end

local function applyArt(texture, iconFile, iconAsset)
  if not texture then
    return false
  end
  if iconFile and type(texture.SetTexture) == "function" then
    if pcall(texture.SetTexture, texture, iconFile) then
      if type(texture.SetVertexColor) == "function" then
        texture:SetVertexColor(1, 1, 1)
      end
      return true
    end
  end
  if iconAsset and Assets.Has(iconAsset) then
    local ok, applied = pcall(Assets.Apply, texture, iconAsset)
    if ok and applied ~= false then
      if type(texture.SetVertexColor) == "function" then
        texture:SetVertexColor(1, 1, 1)
      end
      return true
    end
  end
  return false
end

-- One Assets key onto a texture, hidden where this build has neither the key nor the art. The
-- glyphs the pane draws on top of an icon all go through here.
local function applyGlyph(texture, key, colorKey)
  if not texture then
    return false
  end
  if not (key and Assets.Has(key)) then
    return false
  end
  local ok, applied = pcall(Assets.Apply, texture, key)
  if not (ok and applied ~= false) then
    return false
  end
  if colorKey then
    tint(texture, colorKey)
  elseif type(texture.SetVertexColor) == "function" then
    texture:SetVertexColor(1, 1, 1)
  end
  return true
end

--------------------------------------------------------------------------------
-- The window and Core
--------------------------------------------------------------------------------

local function frameModule()
  local ui = ItemTree.UI
  local frame = type(ui) == "table" and ui.Frame or nil
  return type(frame) == "table" and frame or nil
end

-- Re-rooting is the window's job entirely. Looked up lazily, because UI/Frame.lua loads before
-- this file but only fills itself in later.
local function askFrameToOpen(nodeKey)
  if type(nodeKey) ~= "string" or nodeKey == "" then
    return false
  end
  local frame = frameModule()
  if frame and type(frame.Open) == "function" then
    pcall(frame.Open, nodeKey)
    return true
  end
  return false
end

-- The other half of a stage click: the window opens the stage that was clicked on a list view
-- (brief C2). The chain is a view now, and the view sticks as the player walks, so a plain open
-- would land on the chain again; the view is named instead, Frame.RowView's answer for the key,
-- which is the list view the player was last on. Frame.Open takes the view as an option so the
-- window draws once, on the root and on the view together, and the chain is never redrawn on the
-- new root under the player's eyes. The root's own stage opens too: the same key on another view
-- is a view change and nothing else. UI/Frame.lua is another file's, so every call is type checked
-- and pcall'd; a window with no RowView opens the key as a right click would.
local function askFrameForTree(nodeKey)
  local frame = frameModule()
  if not (frame and type(nodeKey) == "string" and nodeKey ~= "") then
    return false
  end
  local view = nil
  if type(frame.RowView) == "function" then
    local ok, answer = pcall(frame.RowView, nodeKey)
    if ok and type(answer) == "string" and answer ~= "" then
      view = answer
    end
  end
  if not view then
    if nodeKey == Chain.rootKey then
      return false
    end
    return askFrameToOpen(nodeKey)
  end
  if type(frame.Open) == "function" then
    return pcall(frame.Open, nodeKey, { view = view }) and true or false
  end
  return false
end

-- A click on a disenchant signpost: the window rooted on the stage the sign belongs to, with the
-- view it names already up. Frame.Open takes the view as an option so the window draws once,
-- on the root and on the view together, rather than opening and then being told to switch; a
-- window that does not take the option yet still opens the right node on whichever view its own
-- fall back picks.
--
-- This opens the key even where it is the chain's own root, because the view is the whole point
-- of the press: a player on Arcane Crystal asking for its own Disenchants into tab would otherwise
-- be left on the chain.
local function askFrameForView(nodeKey, view)
  if type(nodeKey) ~= "string" or nodeKey == "" then
    return false
  end
  local frame = frameModule()
  if not frame then
    return false
  end
  local moved = false
  if type(frame.Open) == "function" then
    local opts = nil
    if type(view) == "string" and view ~= "" then
      opts = { view = view }
    end
    if pcall(frame.Open, nodeKey, opts) then
      moved = true
    end
  end
  return moved
end

-- The node the player navigated from, which Core takes as opts.prefer: it picks the reagent
-- inside an AND group, so walking from a reagent to its recipe keeps that reagent on the
-- chain. The window states it; where this build's window does not, Frame.path is the same
-- trail and the key behind the root is the same answer. Nothing here fails if it has neither.
local function previousKey(rootKey)
  local frame = frameModule()
  if not frame then
    return nil
  end
  local key
  if type(frame.PreviousKey) == "function" then
    local ok, answer = pcall(frame.PreviousKey)
    key = ok and answer or nil
  end
  if key == nil and type(frame.path) == "table" then
    local path = frame.path
    for index = #path, 1, -1 do
      if path[index] ~= rootKey then
        key = path[index]
        break
      end
    end
  end
  if type(key) ~= "string" or key == "" or key == rootKey then
    return nil
  end
  return key
end

-- The saved settings, or nil where there are none (a load with no saved variables yet).
local function savedSettings()
  local db = ItemTree.db
  return type(db) == "table" and type(db.settings) == "table" and db.settings or nil
end

-- Brief SF1 (CH1's queued note, QA item 295): the "Show predicted data" setting, read the way the
-- item column reads it (UI/InfoPanel.lua showingPredicted): the window's options built from the
-- saved settings first, because UI/Frame.lua holds the default for a setting nobody has set, then
-- the saved setting, and a load that answers neither leaves predictions on, the default.
local function showingPredicted()
  local settings = savedSettings()
  local frame = frameModule()
  if frame and type(frame.OptionsFromSettings) == "function" then
    local ok, answer = pcall(frame.OptionsFromSettings, settings)
    if ok and type(answer) == "table" and answer.showPredicted ~= nil then
      return answer.showPredicted ~= false
    end
  end
  if type(settings) == "table" and settings.showPredicted ~= nil then
    return settings.showPredicted ~= false
  end
  return true
end

-- What the pane asks Core for: the chain the player picked, through the stages they pinned,
-- following the reagent they came from, with the predicted stages only while the player's setting
-- shows predicted data (brief SF1; Core/Chain.lua's walks and its disenchant signposts follow it).
local function chainOpts()
  return { choice = Chain.choice, pins = Chain.pins, prefer = Chain.prefer, showPredicted = showingPredicted() }
end

-- One answer from a Core/Graph.lua function of no arguments (a false kept as false), or nil.
local function graphAnswer(name)
  local graph = ItemTree.Graph
  if type(graph) ~= "table" or type(graph[name]) ~= "function" then
    return nil
  end
  local ok, answer = pcall(graph[name])
  if not ok then
    return nil
  end
  return answer
end

-- Brief FX-AG2: whether the provider layer answers, asked the way its own providers ask it
-- (Providers/Registry.lua Registry.Enabled), or nil for a load with no provider layer.
local function providersOn()
  local providers = ItemTree.Providers
  if type(providers) ~= "table" or type(providers.Enabled) ~= "function" then
    return nil
  end
  local ok, on = pcall(providers.Enabled)
  if not ok then
    return nil
  end
  return on
end

-- Brief SF1: the facts a held chain is told apart by (Chain.CACHE_FACTS says why each one), read
-- from the settings, the graph and the two data modules' generations. Tables are told apart by
-- identity: a namespace that swaps its data module for another is new data. Brief FX-AG2: Merge
-- recipes is read through Graph.FoldsSetTwins, the one place the chain's walk reads it.
local function cacheFacts(showPredicted)
  local settings = savedSettings() or EMPTY
  local data, collector = ItemTree.Data, ItemTree.Collector
  return {
    showPredicted = showPredicted,
    hideOtherFaction = graphAnswer("HidesOtherFaction"),
    side = graphAnswer("PlayerSide"),
    eraDetails = settings.showEraDetails ~= false,
    harvested = settings.showHarvested ~= false,
    includeMinor = settings.includeMinorChanges == true,
    mergeCrafts = graphAnswer("FoldsSetTwins"),
    useProviders = providersOn(),
    data = type(data) == "table" and tostring(data) or nil,
    dataGeneration = type(data) == "table" and rawget(data, "generation") or nil,
    collectorGeneration = type(collector) == "table" and rawget(collector, "generation") or nil,
  }
end

-- Brief SF1: the held chains, { stamp, entries = { [key] = full }, order = { key, ... } }, oldest
-- first in order.
Chain.cache = { stamp = nil, entries = {}, order = {} }

--- Brief SF1: lets every held chain go, so the next draw asks Core again. The viewport's OnHide
--- calls it (the window closing, or another view taking the pane's place), so a chain is held
--- only while the player is looking at it, and Chain.Refresh, which promises a fresh read. Brief
--- FX-AG2: UI/Options.lua's OnChanged calls it for every setting, before the window draws again.
function Chain.DropCache()
  Chain.cache = { stamp = nil, entries = {}, order = {} }
  return true
end

local function holdChain(key, full)
  local cache = Chain.cache
  if cache.entries[key] == nil then
    cache.order[#cache.order + 1] = key
  end
  cache.entries[key] = full
  while #cache.order > Chain.CACHE_MAX do
    cache.entries[table.remove(cache.order, 1)] = nil
  end
end

--- The whole chain through a key, from Core, or the one held for the same ask while nothing it
--- reads has moved (brief SF1, Chain.CacheKey). A build with no Chain module, or a key it knows
--- nothing about, reads as no chain at all, which is the muted empty message; an answer Core
--- refused is never held. A pin nothing can meet comes back in dropped, and is forgotten here so
--- the pane and Core agree on what is pinned.
function Chain.ChainFor(rootKey)
  local core = coreChain()
  if type(rootKey) ~= "string" or rootKey == "" then
    return NO_CHAIN
  end
  if not (core and type(core.Full) == "function") then
    return NO_CHAIN
  end
  local opts = chainOpts()
  local key, stamp = Chain.CacheKey(rootKey, opts, cacheFacts(opts.showPredicted))
  if Chain.cache.stamp ~= stamp then
    Chain.DropCache()
    Chain.cache.stamp = stamp
  end
  local full = Chain.cache.entries[key]
  if full == nil then
    local ok, built = pcall(core.Full, rootKey, opts)
    if not ok or type(built) ~= "table" or type(built.stages) ~= "table" then
      return NO_CHAIN
    end
    full = built
    holdChain(key, full)
  end
  for _, slot in ipairs(type(full.dropped) == "table" and full.dropped or EMPTY) do
    Chain.pins[slot] = nil
  end
  return full
end
local chainFor = Chain.ChainFor

--------------------------------------------------------------------------------
-- Measuring, the zoom and the pan
--------------------------------------------------------------------------------

-- A number the client answers with, or nil. Sizes are asked for through measure, which reads a
-- zero or a negative answer as "not laid out yet"; an edge or a scale is asked for through
-- number, because a frame's left edge is honestly 0 on the left of the screen.
local function number(frame, method)
  if not frame or type(frame[method]) ~= "function" then
    return nil
  end
  local ok, value = pcall(frame[method], frame)
  return ok and tonumber(value) or nil
end

local function measure(frame, method)
  local value = number(frame, method)
  if value and value > 0 then
    return value
  end
  return nil
end

-- The viewport's own size, falling back to the region it was anchored inside for a frame the
-- client has not laid out yet.
local function viewportSize()
  local viewport, region = Chain.viewport, Chain.region
  local inset = Chain.BORDER * 2
  local width = measure(viewport, "GetWidth") or (measure(region, "GetWidth") or inset) - inset
  local height = measure(viewport, "GetHeight") or (measure(region, "GetHeight") or inset) - inset
  return width > 0 and width or 0, height > 0 and height or 0
end

-- The cursor, in the viewport's own units. GetCursorPosition answers in screen pixels, which
-- the viewport's effective scale (the window's own SetScale and UIParent's, together) turns
-- back into the coordinates SetPoint, GetLeft and GetTop speak.
local function cursorPoint()
  local get = globalFn("GetCursorPosition")
  if not get then
    return nil
  end
  local ok, x, y = pcall(get)
  x, y = ok and tonumber(x) or nil, ok and tonumber(y) or nil
  if not (x and y) then
    return nil
  end
  local scale = number(Chain.viewport, "GetEffectiveScale") or 1
  if scale <= 0 then
    scale = 1
  end
  return x / scale, y / scale
end

--- How far the pointer is inside the viewport, from its top left, with y running down the way
--- the layout does. nil where the client will not say, which leaves the caller the middle.
local function pointerOffsets()
  local viewport = Chain.viewport
  if not viewport then
    return nil
  end
  local get = globalFn("GetCursorPosition")
  if not get then
    return nil
  end
  local ok, x, y = pcall(get)
  if not ok then
    return nil
  end
  local scale = number(viewport, "GetEffectiveScale") or 1
  return Chain.ViewportPoint(x, y, number(viewport, "GetLeft"), number(viewport, "GetTop"), scale)
end

-- The client's own measurement of a string at the size the controls draw it, so a button is
-- sized to the words on it rather than to an average. A client that will not answer leaves the
-- estimate in Chain.TextWidth standing, which is what the spec measures against.
local function rulerWidth(text)
  local ruler = Chain.ruler
  if not ruler or not setText(ruler, text) then
    return nil
  end
  return number(ruler, "GetStringWidth")
end

local function updateZoomLabel()
  local controls = Chain.controls
  local label = controls and controls.label
  if not label then
    return false
  end
  return setText(label, Chain.ZoomText(Chain.zoom))
end

-- Where the client has no SetClipsChildren, anything outside the viewport is hidden instead,
-- so the strip is never drawn over the rest of the window.
local function cullOutside()
  local layout = Chain.layout
  if Chain.clips or not layout then
    return false
  end
  local width = viewportSize()
  local zoom = Chain.zoom or 1
  local function visible(rect)
    local left = Chain.panX + rect.x * zoom
    return left + rect.width * zoom > 0 and left < width
  end
  for index, frame in ipairs(Chain.stageFrames) do
    local rect = layout.stages[index]
    if frame.active and rect then
      if visible(rect) then
        frame:Show()
      else
        frame:Hide()
      end
    end
  end
  for index, frame in ipairs(Chain.arrowFrames) do
    local rect = layout.arrows[index]
    if frame.active and rect then
      if visible(rect) then
        frame:Show()
      else
        frame:Hide()
      end
    end
  end
  return true
end

-- The shaft and the head on one centre line, snapped to the pixel grid for the zoom in force.
-- Both are anchored by a side rather than a corner, so both are centred on the same line: the
-- rect's bottom edge, which the layout put on the icon's middle.
local function applyShaft(frame, rect)
  local thickness, offset = Chain.SnapShaft(rect.centre, Chain.zoom or 1, Chain.BORDER, Chain.panY or 0)
  if frame.shaft then
    frame.shaft:ClearAllPoints()
    frame.shaft:SetHeight(thickness)
    frame.shaft:SetPoint("LEFT", frame, "BOTTOMLEFT", 0, -offset)
    frame.shaft:SetWidth(frame.head and math.max(rect.width - Chain.ARROW_HEAD + 2, 1) or rect.width)
  end
  if frame.head then
    frame.head:ClearAllPoints()
    frame.head:SetPoint("RIGHT", frame, "BOTTOMRIGHT", 0, -offset)
  end
  return true
end

local function snapArrows()
  local layout = Chain.layout
  if not layout then
    return false
  end
  for index, frame in ipairs(Chain.arrowFrames) do
    local rect = layout.arrows[index]
    if frame.active and rect then
      applyShaft(frame, rect)
    end
  end
  return true
end

-- Pushes the zoom and the pan onto the canvas. SetScale is what makes icons and text grow
-- together; the anchor offsets are in the canvas's own scaled units, so viewport pixels are
-- divided by the zoom on the way in.
local function applyView()
  local canvas, viewport = Chain.canvas, Chain.viewport
  if not (canvas and viewport) then
    return false
  end
  local zoom = Chain.zoom or 1
  if zoom <= 0 then
    zoom = 1
    Chain.zoom = zoom
  end
  if type(canvas.SetScale) == "function" then
    pcall(canvas.SetScale, canvas, zoom)
  end
  canvas:ClearAllPoints()
  canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", Chain.panX / zoom, -Chain.panY / zoom)
  updateZoomLabel()
  snapArrows()
  cullOutside()
  return true
end

--- Pans the canvas, clamped so the chain cannot be lost off screen. Viewport pixels.
function Chain.SetPan(panX, panY)
  local layout = Chain.layout or EMPTY
  local width, height = viewportSize()
  local x, y = Chain.ClampPan(panX, panY, layout.width or 0, layout.height or 0, width, height, Chain.zoom or 1)
  Chain.panX, Chain.panY = x, y
  applyView()
  return x, y
end

--- Zooms by a factor about a point in the viewport, the pointer by default, and about the
--- middle of the pane where the client will not say where the pointer is. Both axes are moved,
--- because a chain that grew downwards from the top edge is not a zoom about anything.
--- Returns the zoom now in force.
function Chain.ZoomBy(factor, pointerX, pointerY)
  local zoom = Chain.zoom or 1
  local width, height = viewportSize()
  local newZoom = clamp(zoom * (tonumber(factor) or 1), Chain.ZOOM_MIN, Chain.ZOOM_MAX)
  pointerX = tonumber(pointerX) or (width / 2)
  pointerY = tonumber(pointerY) or (height / 2)
  local panX = Chain.ZoomAbout(zoom, newZoom, pointerX, Chain.panX)
  local panY = Chain.ZoomAbout(zoom, newZoom, pointerY, Chain.panY)
  Chain.zoom = newZoom
  Chain.SetPan(panX, panY)
  return newZoom
end

--- Zooms so the whole chain fits the viewport and centres it on the root. Where the chain is
--- longer than the zoom floor allows, the root is what the player is left looking at.
function Chain.Fit()
  local layout = Chain.layout
  if not (layout and Chain.viewport) then
    return false
  end
  local width = viewportSize()
  local zoom = Chain.FitZoom(layout.width, width - Chain.PAD * 2, Chain.ZOOM_MIN, Chain.FIT_MAX)
  Chain.zoom = zoom
  Chain.SetPan(Chain.CentrePan(layout.rootCentre or 0, width, zoom), 0)
  return zoom
end

--------------------------------------------------------------------------------
-- Tooltips
--------------------------------------------------------------------------------

-- r, g, b for a Theme colour key, and white for a key this build does not carry, because a
-- tooltip line has to be some colour and the client's own default is white.
local function tooltipColor(key)
  local colour = key and Theme.ColorTable(key) or nil
  if not colour then
    return 1, 1, 1
  end
  return colour.r, colour.g, colour.b
end

local function mutedLine(tooltip, text)
  if type(text) ~= "string" or text == "" or type(tooltip.AddLine) ~= "function" then
    return false
  end
  tooltip:AddLine(text, tooltipColor("ITEMTREE_COLOR_TEXT_MUTED"))
  return true
end

-- The client's own tooltip for an item, which ItemTree's tooltip hook then appends its block
-- to, so the player gets both. SetItemByID is the modern call and the item link the older one;
-- a client that carries neither leaves this to the info panel's lines.
local function setClientItem(tooltip, itemId)
  if not itemId then
    return false
  end
  if type(tooltip.SetItemByID) == "function" and pcall(tooltip.SetItemByID, tooltip, itemId) then
    return true
  end
  if type(tooltip.SetHyperlink) == "function" then
    return pcall(tooltip.SetHyperlink, tooltip, "item:" .. tostring(itemId)) and true or false
  end
  return false
end

-- The lines the info panel writes for an item, drawn straight onto the tooltip. Lazy and
-- guarded: UI/InfoPanel.lua may not carry TooltipLines on this build.
local function addPanelLines(tooltip, itemId)
  if not itemId or type(tooltip.AddLine) ~= "function" then
    return false
  end
  local ui = ItemTree.UI
  local panel = type(ui) == "table" and ui.InfoPanel or nil
  if type(panel) ~= "table" or type(panel.TooltipLines) ~= "function" then
    return false
  end
  local ok, lines = pcall(panel.TooltipLines, itemId)
  if not ok or type(lines) ~= "table" or #lines == 0 then
    return false
  end
  for _, line in ipairs(lines) do
    local r, g, b = tooltipColor(line.colorKey)
    if line.right and type(tooltip.AddDoubleLine) == "function" then
      tooltip:AddDoubleLine(line.text or "", line.right, r, g, b, r, g, b)
    else
      tooltip:AddLine(line.text or "", r, g, b)
    end
  end
  return true
end

local function hideTooltip()
  local tooltip = rawget(_G, "GameTooltip")
  if tooltip and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end

-- The tooltip a hovered stage raises. An item takes the client's own tooltip where the client
-- can draw one, so the player reads exactly what a bag slot shows plus ItemTree's block;
-- everything else is written from what the pane already knows. The tools a recipe asks for and
-- the pin the player put on the slot are stated either way, because neither is on the item.
local function showStageTooltip(frame, model)
  local tooltip = rawget(_G, "GameTooltip")
  model = model or rawget(frame, "model")
  if not model or type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  tooltip:SetOwner(frame, "ANCHOR_RIGHT")
  -- A signpost says what it stands for and what a click does, and nothing else: it is not an
  -- item, so there is no client tooltip to draw, and it cannot be re-rooted on, so the right
  -- click hint every other stage carries would be a lie.
  if model.signpost then
    local drew = false
    if type(tooltip.AddLine) == "function" and model.name ~= "" then
      tooltip:AddLine(model.name, tooltipColor(model.nameColor))
      drew = true
    end
    if mutedLine(tooltip, model.meta) then
      drew = true
    end
    if mutedLine(tooltip, Chain.SignpostTooltip(model)) then
      drew = true
    end
    if not drew then
      hideTooltip()
      return false
    end
    tooltip:Show()
    return true
  end
  local drawn = false
  if model.itemId and setClientItem(tooltip, model.itemId) then
    drawn = true
  else
    if type(tooltip.AddLine) == "function" and model.name ~= "" then
      tooltip:AddLine(model.name, tooltipColor(model.nameColor))
      drawn = true
    end
    if addPanelLines(tooltip, model.itemId) then
      drawn = true
    end
    if mutedLine(tooltip, model.meta) then
      drawn = true
    end
    -- The quantity belongs to the arrow drawn into this stage, which is why it is read off the
    -- frame rather than off the model: Core leaves the quantity of the edge it walked on the
    -- first stage of a reversed path, where no arrow is drawn at all.
    if mutedLine(tooltip, rawget(frame, "arrowText")) then
      drawn = true
    end
    for _, badge in ipairs(model.badges or EMPTY) do
      if mutedLine(tooltip, string.format(L["Marked %s"], Badges.Label(badge) or badge)) then
        drawn = true
      end
    end
  end
  -- E44: what the chest in the corner of the slot means, on every hover, under whichever block
  -- was drawn above it, the client's own item tooltip included. This is the one place the pane
  -- writes the sentence, and ItemTree's block (UI/Tooltip.lua) never writes it at all, so it can
  -- never land twice.
  if mutedLine(tooltip, Chain.DiscoveryText(model)) then
    drawn = true
  end
  if mutedLine(tooltip, model.tools) then
    drawn = true
  end
  if model.coReagentText and mutedLine(tooltip, model.coReagentText) then
    drawn = true
  end
  if model.pinned and mutedLine(tooltip, L["Pinned"]) then
    drawn = true
  end
  -- Last, because it is what the two buttons do rather than a fact about the stage, and only
  -- where the stage said something first: a stage with nothing to say still hides the tooltip
  -- rather than showing a lone hint. The root stage says only the first line, because a right
  -- click on it has no chain to follow.
  if drawn then
    local clickHint, followHint = Chain.StageClickHint(model.key, Chain.rootKey, model.kind)
    mutedLine(tooltip, clickHint)
    mutedLine(tooltip, followHint)
  end
  if not drawn then
    hideTooltip()
    return false
  end
  tooltip:Show()
  return true
end

-- The words over a control, and where a row states one, the run of stages under them. A row
-- whose label the list had to cut is the whole reason the list carries a tooltip at all: the
-- part that is cut is the part that says which chain this is.
local function showHint(frame, text, lines)
  local tooltip = rawget(_G, "GameTooltip")
  local hasText = type(text) == "string" and text ~= ""
  local hasLines = type(lines) == "table" and #lines > 0
  if not hasText and not hasLines then
    return false
  end
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  tooltip:SetOwner(frame, "ANCHOR_TOP")
  if hasText and type(tooltip.AddLine) == "function" then
    tooltip:AddLine(text, tooltipColor("ITEMTREE_COLOR_TEXT_BODY"))
  end
  if hasLines then
    for _, line in ipairs(lines) do
      mutedLine(tooltip, line)
    end
  end
  tooltip:Show()
  return true
end

local function onLeaveHideTooltip()
  hideTooltip()
end

--------------------------------------------------------------------------------
-- The drop down lists: alternatives, co-reagents and the chain selector
--------------------------------------------------------------------------------
-- One pooled list serves all three. UIDropDownMenu is not used anywhere here: it is global,
-- shared with the client's own menus and taints easily, and this list has to carry an icon, a
-- quantity and a second action on every row, which its item format cannot say.
--
-- The list is at most MENU_MAX_ROWS tall and the wheel moves it through the rest. Arcanite Bar
-- is a reagent for eighty seven recipes, and drawn one row per entry that list is taller than
-- the screen: every row past the bottom edge is one the player cannot click at all.

-- A click anywhere else closes the list. The catcher is a mouse enabled frame under the list
-- and over everything else, which is how a menu closes without every other frame in the addon
-- having to know the menu exists. It is hidden with the list, and with the pane, so it can
-- never be left swallowing clicks.
local function hideCatcher()
  local catcher = Chain.catcher
  if catcher and type(catcher.Hide) == "function" then
    catcher:Hide()
  end
  return true
end

--- Whether the pointer is over the open list or one of its rows.
---
--- The client's own menus ask exactly this before closing on a global mouse down
--- (MenuManagerMixin:ContainsCursor, Blizzard_Menu/Menu.lua on the `forever` branch), and for
--- the same reason: a press that lands inside a menu is the player picking a row, never the
--- player dismissing it. Without the question a closer that happens to be over the list on that
--- press takes the pick away and the pane answers a click with the chain it already had.
---
--- A client that will not say where the pointer is answers false, which leaves the closers doing
--- what they always did.
function Chain.MenuHasCursor()
  local menu = Chain.menu
  if not (menu and menu.shownMenu) then
    return false
  end
  local frames = { menu }
  for _, row in ipairs(Chain.menuRows or EMPTY) do
    frames[#frames + 1] = row
  end
  for _, frame in ipairs(frames) do
    if type(frame.IsShown) == "function" and type(frame.IsMouseOver) == "function" then
      local asked, shown = pcall(frame.IsShown, frame)
      if asked and shown then
        local answered, over = pcall(frame.IsMouseOver, frame)
        if answered and over then
          return true
        end
      end
    end
  end
  return false
end

--- Hides the list, if one is open.
---
--- E39: voiced is the player putting the list away themselves, which is a second press on the
--- control that opened it, Escape, or a press that lands anywhere outside it. That plays
--- menuClose, and only where a list was really open, so a close that closes nothing is silent.
--- Every other close stays silent on purpose: a close that follows a pick has already been
--- voiced by the pick's own click, and a close that a redraw or a hidden pane brought about is
--- not something the player did at all.
function Chain.CloseMenu(voiced)
  local menu = Chain.menu
  local wasOpen = (menu and menu.shownMenu) and true or false
  if menu and type(menu.Hide) == "function" then
    menu.shownMenu = false
    menu:Hide()
  end
  -- The rows are hidden in their own right rather than left to the list they hang off. A pooled
  -- row still carries the action the last list put on it, so a row that is only hidden because
  -- its parent is, is a row that comes back the moment anything shows that parent.
  for _, row in ipairs(Chain.menuRows or EMPTY) do
    if type(row.Hide) == "function" then
      row:Hide()
    end
  end
  hideCatcher()
  Chain.menuOwner, Chain.menuKind = nil, nil
  Chain.menuEntries, Chain.menuOffset = nil, 0
  Chain.menuWidth, Chain.menuScrolls = nil, false
  if wasOpen and voiced == true then
    playCue("menuClose")
  end
  return true
end

local function setStrata(frame, strata)
  if not (frame and type(frame.SetFrameStrata) == "function") then
    return false
  end
  return (pcall(frame.SetFrameStrata, frame, strata))
end

-- The list over everything, every time it opens rather than once at Attach.
--
-- Worth stating plainly, because this was twice diagnosed as the swap bug and twice was not:
-- layering alone never explained it. The list is in its own strata above the catcher's, so
-- nothing of ours was ever in front of a row, and the pick was being lost between the mouse
-- going down and coming back up instead (see menuRow). Layering still has to be right, so this
-- stays: the strata are named constants rather than whatever each frame inherited, and both are
-- re-stated on every open, because the window this pane lives in sets its own strata and
-- anything that restates the pane's would otherwise carry the list down with it.
--- The level a list has to clear to be clickable: the catcher's, the control it drops out of,
--- and the pane they both sit in, whichever of them is highest.
---
--- Reading the catcher alone is not enough. The catcher hangs off UIParent and carries a level
--- of its own, usually a very low one, while the list drops out of a control inside a window
--- whose frames are nested far deeper; a list left at the catcher's level is one the window's
--- own frames can answer for, and a row nothing can click is a row that does nothing.
function Chain.MenuLevel(...)
  local level = 0
  for index = 1, select("#", ...) do
    local at = number(select(index, ...), "GetFrameLevel")
    if at and at > level then
      level = at
    end
  end
  return level + Chain.MENU_LEVEL_STEP
end

local function raiseMenu(owner)
  setStrata(Chain.catcher, Chain.CATCHER_STRATA)
  setStrata(Chain.menu, Chain.MENU_STRATA)
  local menu = Chain.menu
  if menu and type(menu.SetFrameLevel) == "function" then
    pcall(menu.SetFrameLevel, menu, Chain.MenuLevel(Chain.catcher, owner, Chain.region))
  end
  return true
end

-- Puts one row above the list it sits in, and its second action above the row.
--
-- Not the swap bug, but still necessary. The
-- rows are pooled, and the list's own level is worked out again on every open from whichever
-- control it drops out of: the selector sits on the pane and a stage's control sits inside the
-- canvas, so the two answers are a dozen levels apart. The client gives a new frame its parent's
-- level plus one and never moves it again, so a row keeps the level the list happened to be at
-- when that row was first built while the list climbs out from under it. The list is mouse
-- enabled, so a row below it is a row the LIST answers for: the click lands on the list, which
-- does nothing with it, and the player sees a drop down that will not pick.
--
-- So every row is levelled again on every fill, against the level the list is at by then.
local function levelRow(row, level)
  if not level then
    return false
  end
  if type(row.SetFrameLevel) == "function" then
    pcall(row.SetFrameLevel, row, level + 1)
  end
  if row.action and type(row.action.SetFrameLevel) == "function" then
    pcall(row.action.SetFrameLevel, row.action, level + 2)
  end
  return true
end

-- One line to the player, through whichever print the client carries. Used for a pick that
-- raised and nothing else: the client hides Lua errors by default, so an error inside a menu
-- handler reads on screen as a click that did nothing, which is the whole of what the owner has
-- reported twice.
local function announce(text)
  local say = globalFn("print")
  if not say then
    return false
  end
  return (pcall(say, text))
end

-- Starts a trail entry for the pick now in flight. The pin or the choice fills itself in as it
-- is written, and the redraw adds what came back, so the trail says which half of the pick
-- failed rather than only that one did.
local function beginPick(kind, label)
  local entry = { kind = kind or "menu", label = label }
  local trail = Chain.trail
  trail[#trail + 1] = entry
  for _ = 1, #trail - Chain.TRAIL_MAX do
    table.remove(trail, 1)
  end
  Chain.pick = entry
  return entry
end

-- The short form of whatever a pcall handed back, for the trail and for the one line the player
-- is told. A client error carries the file and the line, which is the useful half.
local function shortError(err)
  local text = tostring(err)
  if #text > 160 then
    text = text:sub(1, 160)
  end
  return text
end

-- Runs one of a row's two actions and closes the list first, so nothing redraws underneath an
-- open menu.
--
-- The action is pcall'd, and an error is written into the trail and said out loud rather than
-- left to the client, which hides Lua errors unless the player has turned them on. A pick that
-- raises halfway through looks exactly like a pick that never fired, and telling the two apart
-- by eye was impossible.
local function runRow(row, field)
  local action = row and rawget(row, field) or nil
  if type(action) ~= "function" then
    return false
  end
  local entry = beginPick(Chain.menuKind, rawget(row, "text"))
  -- E39: one small click for the pick, and the list then closes silently behind it. A pick that
  -- both clicked and said menuClose would be two sounds for one press.
  playCue("click")
  Chain.CloseMenu()
  local ok, err = pcall(action)
  Chain.pick = nil
  if not ok then
    entry.err = shortError(err)
    announce("ItemTree: that chain pick failed. Type /itemtree debug and send the Chain lines.")
    announce("ItemTree: " .. entry.err)
    return false
  end
  return true
end

-- E6: the standard modified clicks on anything in the chain that is an item. A left click with
-- the client's dress up or chat link modifier goes to UI/ItemClick.lua first, and answers true
-- when the client took it (the item is on in the Dressing Room, or its link is in the chat box);
-- the stage or list row then does nothing else. Every other click, and anything that is not an
-- item, answers false and does what it always did.
function Chain.ModifiedClick(nodeKey, button)
  if button ~= nil and button ~= "LeftButton" then
    return false
  end
  local helper = ItemTree.ItemClick
  if type(helper) ~= "table" or type(helper.HandleKey) ~= "function" then
    return false
  end
  local ok, handled = pcall(helper.HandleKey, nodeKey)
  return ok and handled == true
end

local function onRowClick(row, button)
  -- An alternative or a co-reagent is an item or a spell; a chain choice carries no key at all.
  if type(row) == "table" and Chain.ModifiedClick(rawget(row, "itemKey"), button) then
    return true
  end
  if button == "RightButton" then
    if runRow(row, "onSecondary") then
      return true
    end
    return false
  end
  -- Every other button is one "AnyDown" brought with it. The middle button and the thumb buttons
  -- were never meant to pick a row, and a list that answered them would swap a chain out from
  -- under a player who was only scrolling. A client that will not name the button is taken as a
  -- left click, which is what it always was.
  if button ~= nil and button ~= "LeftButton" then
    return false
  end
  return runRow(row, "onPrimary")
end

local function menuRow(index)
  local pool = Chain.menuRows
  if pool[index] then
    return pool[index]
  end
  local menu = Chain.menu
  if not menu then
    return nil
  end
  local row = newFrame("Button", menu)
  if not row then
    return nil
  end
  row:SetHeight(Chain.MENU_ROW_H)
  -- Said out loud rather than left to the frame kind's default: a row the client does not take
  -- the mouse on hands the click straight through to the catcher underneath, which closes the
  -- list and changes nothing.
  if type(row.EnableMouse) == "function" then
    pcall(row.EnableMouse, row, true)
  end
  row.hover = wash(row, "HIGHLIGHT", "ITEMTREE_COLOR_STATE_HOVER")
  if row.hover then
    row.hover:SetAllPoints(row)
    row.hover:Show()
  end
  row.icon = type(row.CreateTexture) == "function" and row:CreateTexture(nil, "ARTWORK") or nil
  if row.icon then
    row.icon:SetSize(Chain.MENU_ICON, Chain.MENU_ICON)
    row.icon:SetPoint("LEFT", row, "LEFT", Chain.PAD, 0)
  end
  row.label = newText(row, Chain.FONT_SM, "ITEMTREE_COLOR_TEXT_BODY", "LEFT")
  if row.label then
    row.label:SetPoint("LEFT", row, "LEFT", Chain.PAD * 2 + Chain.MENU_ICON, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -(Chain.PAD * 2 + Chain.MENU_ACTION), 0)
    if type(row.label.SetWordWrap) == "function" then
      row.label:SetWordWrap(false)
    end
  end
  row.right = newText(row, Chain.FONT_SM, "ITEMTREE_COLOR_TEXT_MUTED", "RIGHT")
  if row.right then
    row.right:SetPoint("RIGHT", row, "RIGHT", -(Chain.PAD * 2 + Chain.MENU_ACTION), 0)
    row.right:SetWidth(Chain.MENU_RIGHT_W)
  end
  row.tick = type(row.CreateTexture) == "function" and row:CreateTexture(nil, "OVERLAY") or nil
  if row.tick then
    row.tick:SetSize(Chain.MENU_ICON - 4, Chain.MENU_ICON - 4)
    row.tick:SetPoint("RIGHT", row, "RIGHT", -(Chain.PAD * 2 + Chain.MENU_ACTION), 0)
    row.tick:Hide()
  end
  -- The second action: open that node as the new root, which is what a click on a row used to
  -- do before a click began pinning it in place instead.
  row.action = newFrame("Button", row)
  if row.action then
    row.action:SetSize(Chain.MENU_ACTION, Chain.MENU_ACTION)
    row.action:SetPoint("RIGHT", row, "RIGHT", -Chain.PAD, 0)
    row.action.glyph = type(row.action.CreateTexture) == "function" and row.action:CreateTexture(nil, "ARTWORK") or nil
    if not applyGlyph(row.action.glyph, "ICON_CHEVRON_EXPAND", Chain.ARROW_COLOR) then
      row.action.glyph = nil
    elseif row.action.glyph then
      row.action.glyph:SetAllPoints(row.action)
    end
    row.action.hover = wash(row.action, "HIGHLIGHT", "ITEMTREE_COLOR_STATE_HOVER")
    if row.action.hover then
      row.action.hover:SetAllPoints(row.action)
      row.action.hover:Show()
    end
    -- On the way down, for the same reason the row is: the row under it closes the list on the
    -- press, so an arrow that waited for the release would be answering for a frame that is
    -- already hidden.
    row.action.clickShape = registerClicks(row.action, { "LeftButtonDown" }, { "AnyDown" })
    setScript(row.action, "OnClick", function()
      runRow(row, "onSecondary")
    end)
    setScript(row.action, "OnEnter", function(self)
      showHint(self, rawget(row, "secondaryHint"))
    end)
    setScript(row.action, "OnLeave", onLeaveHideTooltip)
    row.action:Hide()
  end
  -- THE PICK IS TAKEN ON THE PRESS, NOT ON THE RELEASE. This is the whole of the swap bug.
  --
  -- Everything that closes one of these lists fires on the way DOWN: the screen wide catcher's
  -- OnMouseDown, the viewport's OnMouseDown, and the client's own menu manager, which listens
  -- for GLOBAL_MOUSE_DOWN. Closing hides the rows, and a Button that is hidden between the press
  -- and the release never delivers OnClick at all. So a row that waited for LeftButtonUp was
  -- racing every closer in the pane for its own click, and losing silently: the list shut, the
  -- chain did not change, and nothing was raised for anyone to see.
  --
  -- The live client settles this the same way. In Blizzard_Menu/Menu.lua on the `forever`
  -- branch (the Forever client loads the shared Menu.lua; only Menu.xml is swapped for
  -- Camelot/Menu.xml, which overrides no clicks), InitializeFrame gives every menu element
  -- frame:SetScript("OnMouseDown", menu.onElementMouseDown) and no OnClick, and
  -- MenuManagerMixin:HandleGlobalMouseEvent closes on GLOBAL_MOUSE_DOWN only after asking
  -- ContainsCursor, so a press that lands inside a menu never closes it. Both halves are copied
  -- here: the rows answer the press, and the catcher asks first (see buildCatcher).
  --
  -- UI/Frame.lua's own search dropdown already worked this out for itself and registers
  -- "AnyDown", with the comment that waiting for the release is "the classic race that swallowed
  -- the click". This list is the last one in the addon that was still waiting.
  row.clickShape = registerClicks(row, { "AnyDown" }, { "LeftButtonDown", "RightButtonDown" })
  setScript(row, "OnClick", onRowClick)
  setScript(row, "OnEnter", function(self)
    showHint(self, rawget(self, "hint"), rawget(self, "lines"))
  end)
  setScript(row, "OnLeave", onLeaveHideTooltip)
  pool[index] = row
  return row
end

-- How much of a row is left for its label: the icon on the left and the second action on the
-- right are taken out of it, and so are the scroller and a quantity where the list draws them.
local function labelRoom(hasRight)
  local room = (tonumber(Chain.menuWidth) or Chain.MENU_W) - Chain.BORDER * 2
  room = room - (Chain.PAD * 2 + Chain.MENU_ICON) - (Chain.PAD * 2 + Chain.MENU_ACTION)
  if Chain.menuScrolls then
    room = room - Chain.MENU_SCROLLER_W
  end
  if hasRight then
    room = room - Chain.MENU_RIGHT_W
  end
  return room
end

-- Whether the list had to cut this label. The cut falls at the end of the label, which on a
-- chain is exactly the part that says which chain it is, so a cut row says the rest in a tooltip.
local function outgrowsRow(text, hasRight)
  if type(text) ~= "string" or text == "" then
    return false
  end
  local width = rulerWidth(text) or Chain.TextWidth(text)
  if not width then
    return false
  end
  return width > labelRoom(hasRight)
end

-- entry = { key, text, colorKey, iconFile, iconAsset, right, current, onPrimary, onSecondary,
--           hint, secondaryHint, lines }
local function applyMenuRow(row, entry)
  row.onPrimary = type(entry.onPrimary) == "function" and entry.onPrimary or nil
  -- E6: the node the row stands for, for the modified clicks in onRowClick.
  row.itemKey = type(entry.key) == "string" and entry.key or nil
  row.onSecondary = type(entry.onSecondary) == "function" and entry.onSecondary or nil
  -- Kept on the row for the pick trail, so a report says which row was pressed rather than only
  -- which list was open. The font string's own text is the client's to answer for.
  row.text = type(entry.text) == "string" and entry.text or nil
  row.hint = entry.hint
  row.lines = nil
  if type(entry.lines) == "table" and #entry.lines > 0 then
    row.lines = entry.lines
    -- A row the list cut says the whole of its label over the stages, so nothing the player is
    -- choosing between is left off the screen.
    if not row.hint then
      local hasRight = type(entry.right) == "string" and entry.right ~= ""
      if outgrowsRow(entry.text, hasRight) then
        row.hint = entry.text
      end
    end
  end
  row.secondaryHint = entry.secondaryHint
  if row.label then
    setText(row.label, entry.text)
    textColor(row.label, entry.colorKey or "ITEMTREE_COLOR_TEXT_BODY")
  end
  if row.icon then
    if applyArt(row.icon, entry.iconFile, entry.iconAsset) then
      row.icon:Show()
    else
      row.icon:Hide()
    end
  end
  if row.right then
    setText(row.right, entry.right or "")
    if entry.right and entry.right ~= "" then
      row.right:Show()
    else
      row.right:Hide()
    end
  end
  if row.tick then
    if entry.current and applyGlyph(row.tick, "ICON_CHECK", "ITEMTREE_COLOR_TEXT_TITLE") then
      row.tick:Show()
    else
      row.tick:Hide()
    end
  end
  if row.action then
    if row.onSecondary then
      row.action:Show()
    else
      row.action:Hide()
    end
  end
  return row
end

local function hideRowsFrom(from)
  for index = from, #Chain.menuRows do
    Chain.menuRows[index]:Hide()
  end
  return true
end

--- Closes an open list when a press lands outside it. What the client tells us directly.
---
--- A catcher frame is the obvious way to close a drop down and it is the wrong one here. To do
--- its job it has to cover the screen and take the mouse, which puts a frame that closes the
--- list on the press in front of the very rows the player is reaching for, and anything that
--- closes the list hides those rows. The client's own menus use no such frame:
--- MenuManagerMixin listens for GLOBAL_MOUSE_DOWN and closes only where ContainsCursor says the
--- press landed outside the menu (Blizzard_Menu/Menu.lua on the `forever` branch, which is the
--- file the Forever client loads). This is the same rule, asked the same way round, so nothing
--- of ours is ever over a row.
function Chain.OnGlobalMouseDown(button)
  if button ~= nil and button ~= "LeftButton" and button ~= "RightButton" then
    return false
  end
  local menu = Chain.menu
  if not (menu and menu.shownMenu) then
    return false
  end
  if Chain.MenuHasCursor() then
    return false
  end
  return Chain.CloseMenu(true)
end

-- Listens for the press itself, once per session. A client that has never heard of the event
-- refuses to register it, which leaves the catcher as the only way to close a list; the same
-- shape UI/Keybind.lua's own click to open uses for the same event.
local function watchGlobalMouse()
  if Chain.globalMouse then
    return true
  end
  local watcher = Chain.watcher
  if not watcher then
    watcher = newFrame("Frame", nil)
    if not watcher then
      return false
    end
    Chain.watcher = watcher
    setScript(watcher, "OnEvent", function(_, event, button)
      if event == "GLOBAL_MOUSE_DOWN" then
        Chain.OnGlobalMouseDown(button)
      end
    end)
  end
  if type(watcher.RegisterEvent) ~= "function" then
    return false
  end
  -- An unknown event raises on one client and answers false on another, so both are refusals.
  local ok, registered = pcall(watcher.RegisterEvent, watcher, "GLOBAL_MOUSE_DOWN")
  if not ok or registered == false then
    return false
  end
  Chain.globalMouse = true
  return true
end

local function showCatcher()
  -- Nothing of ours goes over the rows on a client that will tell us about the press itself.
  if Chain.globalMouse then
    return false
  end
  local catcher = Chain.catcher
  if not catcher then
    return false
  end
  catcher:Show()
  return true
end

-- As wide as the longest thing in it, within reason. Eighty seven recipes that all read
-- "Enchant 2H Weapon - ..." truncated at 170px is a list the player cannot tell apart; opts.width
-- is the floor rather than the answer, and MENU_MAX_W the ceiling.
local function menuWidth(entries, least, most)
  most = tonumber(most) or Chain.MENU_MAX_W
  if most < least then
    most = least
  end
  local widest = 0
  local hasRight = false
  for _, entry in ipairs(entries) do
    local at = rulerWidth(entry.text) or Chain.TextWidth(entry.text)
    if at and at > widest then
      widest = at
    end
    if type(entry.right) == "string" and entry.right ~= "" then
      hasRight = true
    end
  end
  local wanted = math.ceil(widest) + Chain.MENU_ICON + Chain.MENU_ACTION + Chain.PAD * 5
  if hasRight then
    wanted = wanted + Chain.MENU_RIGHT_W
  end
  if wanted < least then
    return least
  end
  if wanted > most then
    return most
  end
  return wanted
end

--- The most entries a list of this many can start at and still fill itself.
function Chain.MaxOffset(count, rows)
  count = tonumber(count) or 0
  rows = tonumber(rows) or Chain.MENU_MAX_ROWS
  if rows < 1 then
    rows = 1
  end
  local most = count - rows
  if most < 0 then
    return 0
  end
  return most
end

-- The thin bar down the right hand edge that says how far through a long list the player is.
-- Drawn only where there is something to scroll, so a short list is still a plain drop down.
local function applyScroller(count, offset)
  local menu = Chain.menu
  local track, thumb = menu and menu.track, menu and menu.thumb
  if not (track and thumb) then
    return false
  end
  local rows = Chain.MENU_MAX_ROWS
  if count <= rows then
    track:Hide()
    thumb:Hide()
    return false
  end
  local height = rows * Chain.MENU_ROW_H
  local run = math.max(math.floor(height * rows / count + 0.5), Chain.MENU_ROW_H)
  local most = Chain.MaxOffset(count, rows)
  local travel = height - run
  local at = most > 0 and (offset / most) or 0
  thumb:ClearAllPoints()
  thumb:SetHeight(run)
  thumb:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, -math.floor(travel * at + 0.5))
  thumb:SetPoint("TOPLEFT", track, "TOPLEFT", 0, -math.floor(travel * at + 0.5))
  track:Show()
  thumb:Show()
  return true
end

-- Draws the window of rows the offset names. The pool is only ever MENU_MAX_ROWS deep, so a list
-- of eighty seven costs the same frames as a list of three.
local function fillMenu(entries, offset)
  local menu = Chain.menu
  local count = #entries
  local rows = math.min(count, Chain.MENU_MAX_ROWS)
  local shown = 0
  -- Read once, after the list has been raised for this open: every row is put above it.
  local level = number(menu, "GetFrameLevel")
  for index = 1, rows do
    local row = menuRow(index)
    if row then
      shown = index
      levelRow(row, level)
      applyMenuRow(row, entries[offset + index])
      row:ClearAllPoints()
      local top = Chain.BORDER + (index - 1) * Chain.MENU_ROW_H
      row:SetPoint("TOPLEFT", menu, "TOPLEFT", Chain.BORDER, -top)
      row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -(Chain.BORDER + (count > rows and Chain.MENU_SCROLLER_W or 0)), -top)
      row:Show()
    end
  end
  hideRowsFrom(shown + 1)
  applyScroller(count, offset)
  return shown
end

--- Scrolls an open list by whole rows. delta is the wheel's own sign: up is towards the start.
function Chain.ScrollMenu(delta)
  local entries = Chain.menuEntries
  local menu = Chain.menu
  if not (entries and menu and menu.shownMenu) then
    return false
  end
  local most = Chain.MaxOffset(#entries, Chain.MENU_MAX_ROWS)
  if most == 0 then
    return false
  end
  local offset = clamp((Chain.menuOffset or 0) - (tonumber(delta) or 0), 0, most)
  if offset == Chain.menuOffset then
    return false
  end
  Chain.menuOffset = offset
  fillMenu(entries, offset)
  return true
end

--- Opens the list under a control. entries is what each row draws and does; opts takes kind
--- (which list this is, so a second click on the same control closes it again) and width.
--- Clicking the same control twice closes the list, which is what a drop down does.
---
--- Only MENU_MAX_ROWS of the list are drawn at once and the wheel moves the window through the
--- rest: eighty seven alternatives is a list taller than the screen, and a row below the bottom
--- edge is a row the player cannot click at all.
function Chain.OpenMenu(owner, entries, opts)
  opts = type(opts) == "table" and opts or EMPTY
  local menu = Chain.menu
  if not (menu and owner and type(entries) == "table" and #entries > 0) then
    return false
  end
  local kind = opts.kind or "menu"
  if Chain.menuOwner == owner and Chain.menuKind == kind and menu.shownMenu then
    -- A second press on the same control is the player putting the list away, so it is voiced.
    return Chain.CloseMenu(true)
  end
  local width = menuWidth(entries, tonumber(opts.width) or Chain.MENU_W, opts.maxWidth)
  -- Both are read while a row is filled, to tell a label that fits from one the list has cut.
  Chain.menuWidth = width
  Chain.menuScrolls = #entries > Chain.MENU_MAX_ROWS
  Chain.menuEntries, Chain.menuOffset = entries, 0
  -- Raised before it is filled, never after: the rows are levelled against the list, so the list
  -- has to be at the level it is going to be at before the first row is put above it.
  raiseMenu(owner)
  local shown = fillMenu(entries, 0)
  if shown == 0 then
    return Chain.CloseMenu()
  end
  menu:SetSize(width, shown * Chain.MENU_ROW_H + Chain.BORDER * 2)
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -Chain.PAD)
  showCatcher()
  menu.shownMenu = true
  menu:Show()
  takeMenuKeyboard(menu)
  Chain.menuOwner, Chain.menuKind = owner, kind
  -- E39: the one cue a list raises. Every control that opens one comes through here, so the
  -- alternatives, the co-reagents and the chain selector all say the same thing and say it once.
  playCue("menuOpen")
  return true
end

--------------------------------------------------------------------------------
-- What the player can change: the chain, and what stands in a slot
--------------------------------------------------------------------------------

local function redraw()
  if not Chain.viewport then
    return false
  end
  Chain.full = chainFor(Chain.rootKey)
  -- What the pick in flight got back, for the trail: how many chains Core offered, the chain it
  -- drew, and any pin Core could not meet. Counts and keys only.
  local entry = Chain.pick
  if entry then
    local full = Chain.full or NO_CHAIN
    entry.chains = #(type(full.choices) == "table" and full.choices or EMPTY)
    entry.chain = full.label
    local dropped = type(full.dropped) == "table" and full.dropped or EMPTY
    if #dropped > 0 then
      entry.dropped = table.concat(dropped, " ")
    end
  end
  return Chain.Draw()
end

--- Draws a different chain through the same root. An id Core no longer offers falls back to
--- the best chain, which is what Core does with one it does not know.
---
--- A whole chain is every stage at once, so the stages an earlier click pinned go with the old
--- one. Left standing, a pin is the narrower thing the player said and Core honours it first, so
--- the chain they have just picked would be drawn only as far as the pin allows: on a dense root
--- that reads as a selector that answers a click with the chain it already had.
function Chain.SetChoice(id)
  Chain.choice = (type(id) == "string" and id ~= "") and id or nil
  Chain.pins = {}
  if Chain.pick then
    Chain.pick.choice = Chain.choice or "none"
  end
  Chain.CloseMenu()
  return redraw()
end

--- Pins a node in one slot, counted from the root, and redraws the same root with that stage
--- swapped and the rest of that side recomputed. This is what makes an alternative or a
--- co-reagent swap in place rather than re-rooting the window on it.
function Chain.Pin(slot, nodeKey)
  slot = tonumber(slot)
  if not (slot and type(nodeKey) == "string" and nodeKey ~= "") then
    if Chain.pick then
      Chain.pick.err = string.format("pin refused, slot %s key %s", tostring(slot), tostring(nodeKey))
    end
    return false
  end
  Chain.pins[slot] = nodeKey
  if Chain.pick then
    Chain.pick.pin = string.format("%d=%s", slot, nodeKey)
  end
  Chain.CloseMenu()
  return redraw()
end

--- Forgets the pin in one slot.
function Chain.Unpin(slot)
  slot = tonumber(slot)
  if not (slot and Chain.pins[slot]) then
    return false
  end
  Chain.pins[slot] = nil
  Chain.CloseMenu()
  return redraw()
end

--- True where this node is the one the player pinned in that slot.
function Chain.IsPinned(slot, nodeKey)
  slot = tonumber(slot)
  if not slot then
    return false
  end
  return Chain.pins[slot] ~= nil and Chain.pins[slot] == nodeKey
end

-- The rows a stage's alternatives list draws. A click pins the alternative in the slot, and
-- the arrow button (or a right click) opens it as the new root instead.
local function alternativeEntries(model)
  local entries = {}
  for _, other in ipairs(model.alternatives or EMPTY) do
    local slot = other.slot or model.slot
    local key = other.key
    entries[#entries + 1] = {
      key = key,
      text = other.name,
      colorKey = other.nameColor,
      iconFile = other.iconFile,
      iconAsset = other.iconAsset,
      current = Chain.IsPinned(slot, key),
      hint = L["Follow this step instead"],
      secondaryHint = L["Open as the new root"],
      onPrimary = function()
        Chain.Pin(slot, key)
      end,
      onSecondary = function()
        askFrameToOpen(key)
      end,
    }
  end
  return entries
end

-- The rows a stage's co-reagents list draws: the other things the recipe in front of it needs,
-- with how many of each. Upstream of the root, picking one follows it instead and the one being
-- followed becomes a co-reagent in its turn.
--
-- At the root and downstream there is nothing to follow: those slots are decided by the walk out
-- of the root, so a reagent that is not on that walk cannot stand in one and Core would drop the
-- pin and redraw the chain the player already had. Picking one opens it as the new root, which
-- is the same chain read from the other reagent, and the row says so.
local function coReagentEntries(model)
  local entries = {}
  -- A quest has no reagents: the things it is needed alongside are the other items of its turn
  -- in, so the row says item where the stage in front of it is a quest. Core/Chain.lua words
  -- the count on the control the same way, off the same field.
  local followHint = L["Follow this reagent instead"]
  if model.coReagentKind == "quest" then
    followHint = L["Follow this item instead"]
  end
  for _, other in ipairs(model.coReagents or EMPTY) do
    local slot = other.slot or model.slot
    local key = other.key
    local follows = tonumber(slot) ~= nil and slot < 0
    local entry = {
      key = key,
      text = other.name,
      colorKey = other.nameColor,
      iconFile = other.iconFile,
      iconAsset = other.iconAsset,
      right = other.quantityText,
      hint = follows and followHint or L["Open as the new root"],
      secondaryHint = L["Open as the new root"],
      onSecondary = function()
        askFrameToOpen(key)
      end,
    }
    if follows then
      entry.onPrimary = function()
        Chain.Pin(slot, key)
      end
    else
      entry.onPrimary = function()
        askFrameToOpen(key)
      end
    end
    entries[#entries + 1] = entry
  end
  return entries
end

--- Opens the list of the other stages that could stand in a slot.
function Chain.OpenAlternatives(stageFrame)
  local model = stageFrame and rawget(stageFrame, "model") or nil
  if not model or model.alternativeCount == 0 then
    return false
  end
  local owner = rawget(stageFrame, "altControl") or stageFrame
  return Chain.OpenMenu(owner, alternativeEntries(model), { kind = "alternatives" })
end

--- Opens the list of the reagents a stage is needed alongside.
function Chain.OpenCoReagents(stageFrame)
  local model = stageFrame and rawget(stageFrame, "model") or nil
  if not model or model.coReagentCount == 0 then
    return false
  end
  local owner = rawget(stageFrame, "coControl") or stageFrame
  return Chain.OpenMenu(owner, coReagentEntries(model), { kind = "coReagents" })
end

--- Opens the chain selector's own list.
function Chain.OpenChoices()
  local selector = Chain.selector
  local model = Chain.SelectorModel(Chain.full)
  if not (selector and model.shown) then
    return false
  end
  local entries = {}
  for _, entry in ipairs(model.entries) do
    local id = entry.id
    entries[#entries + 1] = {
      text = entry.label,
      colorKey = entry.current and "ITEMTREE_COLOR_TEXT_TITLE" or "ITEMTREE_COLOR_TEXT_BODY",
      current = entry.current,
      lines = entry.names,
      onPrimary = function()
        Chain.SetChoice(id)
      end,
    }
  end
  -- The list may grow to a chain's own sentence, but never past the pane it drops into.
  local room = measure(Chain.region, "GetWidth")
  local most = Chain.SELECTOR_MENU_MAX_W
  if room then
    most = math.min(most, math.floor(room - Chain.PAD * 4))
  end
  return Chain.OpenMenu(selector, entries, { kind = "choices", width = Chain.SELECTOR_MENU_W, maxWidth = most })
end

--------------------------------------------------------------------------------
-- Stages and arrows
--------------------------------------------------------------------------------

local function onStageClick(frame, button)
  local model = rawget(frame, "model")
  Chain.CloseMenu()
  if not model then
    return
  end
  -- E6: the dress up or chat link click on an item stage is the client's, and the chain stays
  -- where it is. See Chain.ModifiedClick.
  if not model.signpost and Chain.ModifiedClick(model.key, button) then
    return
  end
  -- A signpost answers for itself: it has no key, so it can be neither opened nor re-rooted on,
  -- and what it opens is the stage it stands beside with that stage's own view up.
  if model.signpost then
    local signAction, nodeKey, view = Chain.SignpostClickAction(model, button)
    if signAction == "view" then
      playCue("click")
      askFrameForView(nodeKey, view)
    end
    return
  end
  local action = Chain.StageClickAction(model.key, Chain.rootKey, button, model.kind)
  -- E39: voiced where the press does something. A right click on the root answers "none", and a
  -- press that changes nothing should not sound as though it had.
  if action == "tree" or action == "reroot" then
    playCue("click")
  end
  if action == "tree" then
    askFrameForTree(model.key)
    return
  end
  if action == "reroot" then
    askFrameToOpen(model.key)
  end
end

local function onStageEnter(frame)
  showStageTooltip(frame)
end

-- A small bordered button under a stage, the shape both of the slot's own controls take.
local function stageControl(frame, onClick)
  local control = newFrame("Button", frame)
  if not control then
    return nil
  end
  control:SetHeight(Chain.CONTROL_H)
  control.face = wash(control, "BACKGROUND", "ITEMTREE_COLOR_BUTTON_FACE")
  if control.face then
    control.face:SetAllPoints(control)
    control.face:Show()
  end
  insetBorder(control, Chain.PANEL_BORDER)
  control.hover = wash(control, "HIGHLIGHT", "ITEMTREE_COLOR_STATE_HOVER")
  if control.hover then
    control.hover:SetAllPoints(control)
    control.hover:Show()
  end
  control.label = newText(control, Chain.FONT_SM, "ITEMTREE_COLOR_TEXT_MUTED", "CENTER")
  if control.label then
    control.label:SetPoint("CENTER", control, "CENTER", 0, 0)
  end
  if type(control.RegisterForClicks) == "function" then
    pcall(control.RegisterForClicks, control, "LeftButtonUp")
  end
  setScript(control, "OnClick", onClick)
  control:Hide()
  return control
end

local function buildStage(index)
  local pool = Chain.stageFrames
  if pool[index] then
    return pool[index]
  end
  local canvas = Chain.canvas
  if not canvas then
    return nil
  end
  local frame = newFrame("Button", canvas)
  if not frame then
    return nil
  end
  -- Both buttons: a click opens the stage on a list view and a right click follows the chain
  -- from it. The two controls under the slot stay left only, so a right click over one of them
  -- is still the slot's own.
  if type(frame.RegisterForClicks) == "function" then
    pcall(frame.RegisterForClicks, frame, "LeftButtonUp", "RightButtonUp")
  end

  frame.wash = wash(frame, "BACKGROUND", Chain.ROOT_WASH)
  if frame.wash then
    frame.wash:SetAllPoints(frame)
    frame.wash:Hide()
  end
  -- The gold band that marks the root, across the top of its slot.
  frame.band = wash(frame, "ARTWORK", Chain.ROOT_BAND)
  if frame.band then
    frame.band:SetHeight(Chain.BAND)
    frame.band:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.band:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.band:Hide()
  end
  frame.hover = wash(frame, "HIGHLIGHT", "ITEMTREE_COLOR_STATE_HOVER")
  if frame.hover then
    frame.hover:SetAllPoints(frame)
    frame.hover:Show()
  end
  -- The bordered slot: a 1px gold edge a hairline outside the icon.
  frame.iconBorder = wash(frame, "BORDER", Chain.PANEL_BORDER)
  frame.icon = type(frame.CreateTexture) == "function" and frame:CreateTexture(nil, "ARTWORK") or nil
  if frame.icon then
    frame.icon:SetSize(Chain.ICON, Chain.ICON)
  end
  if frame.iconBorder and frame.icon then
    frame.iconBorder:SetPoint("TOPLEFT", frame.icon, "TOPLEFT", -Chain.BORDER, Chain.BORDER)
    frame.iconBorder:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", Chain.BORDER, -Chain.BORDER)
    frame.iconBorder:Show()
  end

  -- The corner glyph that says this slot is a recipe rather than a thing, on a dark backing so
  -- it reads over any icon. A build with neither the key nor the art draws nothing at all.
  frame.spellBack = wash(frame, "ARTWORK", "ITEMTREE_BADGE_BACKING")
  frame.spellMark = type(frame.CreateTexture) == "function" and frame:CreateTexture(nil, "OVERLAY") or nil
  if not applyGlyph(frame.spellMark, "ICON_SPELL_MARK") then
    frame.spellMark = nil
  end
  if frame.spellMark and frame.icon then
    frame.spellMark:SetSize(Chain.SPELL_MARK, Chain.SPELL_MARK)
    frame.spellMark:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", 2, -2)
    frame.spellMark:Hide()
  end
  if frame.spellBack then
    if frame.spellMark then
      frame.spellBack:SetPoint("TOPLEFT", frame.spellMark, "TOPLEFT", -1, 1)
      frame.spellBack:SetPoint("BOTTOMRIGHT", frame.spellMark, "BOTTOMRIGHT", 1, -1)
    end
    frame.spellBack:Hide()
  end

  -- E44: the hover target over that corner, shown only where the glyph is the chest, so the
  -- player can point at it and be told what it means. A Button, because a press on it is handed
  -- straight to the slot's own handler: the target sits over the slot and would otherwise
  -- swallow the click that was meant to open the stage.
  frame.markHit = newFrame("Button", frame)
  if frame.markHit and frame.spellMark then
    local slop = Chain.MARK_HIT_SLOP
    frame.markHit:SetPoint("TOPLEFT", frame.spellMark, "TOPLEFT", -slop, slop)
    frame.markHit:SetPoint("BOTTOMRIGHT", frame.spellMark, "BOTTOMRIGHT", slop, -slop)
    if type(frame.markHit.RegisterForClicks) == "function" then
      pcall(frame.markHit.RegisterForClicks, frame.markHit, "LeftButtonUp", "RightButtonUp")
    end
    setScript(frame.markHit, "OnClick", function(_, button)
      onStageClick(frame, button)
    end)
    setScript(frame.markHit, "OnEnter", function(self)
      showHint(self, Chain.DiscoveryText(rawget(frame, "model")))
    end)
    setScript(frame.markHit, "OnLeave", onLeaveHideTooltip)
    frame.markHit:Hide()
  else
    frame.markHit = nil
  end

  -- The pin mark, the opposite corner, and a click on it lets the slot go again. ICON_PIN is
  -- what it wants, and neither build ships anything to hang it on: Classic Era
  -- 1.15.9.69722 has no pin or thumbtack texture and none of the map pin atlases the Forever
  -- beta carries, so an ICON_PIN key would answer false on Era and fail the asset check. The
  -- gold tab stands until ItemTree ships art of its own, and it still reads as a mark the
  -- player put there. Assets.Has is asked anyway, so adding the key is all it would take.
  frame.pin = newFrame("Button", frame)
  if frame.pin then
    frame.pin:SetSize(Chain.PIN_MARK, Chain.PIN_MARK)
    if frame.icon then
      frame.pin:SetPoint("BOTTOMLEFT", frame.icon, "BOTTOMLEFT", -2, -2)
    end
    frame.pin.back = wash(frame.pin, "BACKGROUND", "ITEMTREE_BADGE_BACKING")
    if frame.pin.back then
      frame.pin.back:SetAllPoints(frame.pin)
      frame.pin.back:Show()
    end
    frame.pin.glyph = type(frame.pin.CreateTexture) == "function" and frame.pin:CreateTexture(nil, "OVERLAY") or nil
    if frame.pin.glyph then
      frame.pin.glyph:SetPoint("TOPLEFT", frame.pin, "TOPLEFT", 2, -2)
      frame.pin.glyph:SetPoint("BOTTOMRIGHT", frame.pin, "BOTTOMRIGHT", -2, 2)
      if not applyGlyph(frame.pin.glyph, "ICON_PIN", Chain.PIN_COLOR) then
        applyGlyph(frame.pin.glyph, "FILL_WHITE8X8", Chain.PIN_COLOR)
      end
      frame.pin.glyph:Show()
    end
    if type(frame.pin.RegisterForClicks) == "function" then
      pcall(frame.pin.RegisterForClicks, frame.pin, "LeftButtonUp")
    end
    setScript(frame.pin, "OnClick", function()
      local model = rawget(frame, "model")
      if model then
        -- E39: taking a pin off is a small press like any other, whatever Unpin makes of it.
        playCue("click")
        Chain.Unpin(model.slot)
      end
    end)
    setScript(frame.pin, "OnEnter", function(self)
      showHint(self, L["Unpin"])
    end)
    setScript(frame.pin, "OnLeave", onLeaveHideTooltip)
    frame.pin:Hide()
  end

  frame.badges = Badges.CreateCluster(frame, Chain.BADGE, Chain.BADGE_MAX)
  if frame.badges and frame.icon then
    local point, relativePoint, x, y = Chain.BadgeAnchor(Chain.BADGE)
    frame.badges:SetPoint(point, frame.icon, relativePoint, x, y)
  end
  -- E48: each mark on a stage is its own hover target, so pointing at one says what that mark
  -- means rather than raising the stage's own tooltip over it. A stage with nothing to diff is
  -- no different: UI/Badges.lua keeps hover and the subject apart. The press still reaches the
  -- stage. The method arrived with that brief, so an older Badges simply draws as it did.
  if frame.badges and type(frame.badges.SetHoverEnabled) == "function" then
    pcall(frame.badges.SetHoverEnabled, frame.badges, true)
  end
  frame.name = newText(frame, Chain.FONT_SM, "ITEMTREE_COLOR_TEXT_BODY", "CENTER")
  frame.meta = newText(frame, Chain.FONT_SM, "ITEMTREE_COLOR_TEXT_MUTED", "CENTER")

  frame.altControl = stageControl(frame, function()
    Chain.OpenAlternatives(frame)
  end)
  frame.coControl = stageControl(frame, function()
    Chain.OpenCoReagents(frame)
  end)

  setScript(frame, "OnClick", onStageClick)
  setScript(frame, "OnEnter", onStageEnter)
  setScript(frame, "OnLeave", onLeaveHideTooltip)
  pool[index] = frame
  return frame
end

-- One of the two controls under a slot, or hidden where the stage has nothing to say there. The
-- button is as wide as its own words plus padding, never wider than the slot: the layout already
-- grew the slot for it, so a label that still does not fit is one the layout capped and the
-- font string truncates rather than the button's edge cutting through it.
local function applyControl(control, row, text, layout, frame, width, slot)
  if not control then
    return false
  end
  if not (row and text) then
    control:Hide()
    return false
  end
  -- The layout already held the label inside the slot it sized for it; this is the floor and the
  -- ceiling for a caller that built a rect by hand.
  local room = math.max((tonumber(slot) or layout.stage) - layout.pad * 2, layout.pad * 2)
  width = math.min(math.max(tonumber(width) or room, layout.pad * 2), room)
  control:ClearAllPoints()
  control:SetPoint("TOP", frame, "TOP", 0, -row)
  control:SetWidth(width)
  control:SetHeight(layout.control)
  setText(control.label, text)
  control:Show()
  return true
end

local function applyStage(frame, model, layout, rect, arrowText)
  frame.model = model
  frame.arrowText = arrowText
  frame.active = true
  frame:SetSize(rect.width, rect.height)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", Chain.canvas, "TOPLEFT", rect.x, -rect.y)

  if frame.wash then
    if model.root then
      frame.wash:Show()
    else
      frame.wash:Hide()
    end
  end
  if frame.band then
    if model.root then
      frame.band:Show()
    else
      frame.band:Hide()
    end
  end
  if frame.icon then
    frame.icon:ClearAllPoints()
    frame.icon:SetPoint("TOP", frame, "TOP", 0, -layout.rows.icon)
    frame.icon:SetSize(layout.icon, layout.icon)
    if applyArt(frame.icon, model.iconFile, model.iconAsset) then
      frame.icon:Show()
    else
      frame.icon:Hide()
    end
    if type(frame.icon.SetAlpha) == "function" then
      local faded = 1
      if model.predicted or model.quiet then
        faded = Chain.QUIET_ALPHA
      end
      frame.icon:SetAlpha(faded)
    end
  end
  -- One texture, one glyph: the art is put on at every draw because the slot is pooled and the
  -- stage before it may have been a recipe where this one is a withheld item.
  local markShown = false
  if frame.spellMark then
    if model.markAsset and applyGlyph(frame.spellMark, model.markAsset) then
      frame.spellMark:Show()
      markShown = true
    else
      frame.spellMark:Hide()
    end
  end
  if frame.spellBack then
    if markShown then
      frame.spellBack:Show()
    else
      frame.spellBack:Hide()
    end
  end
  -- E44: the hover target follows the chest and nothing else. A recipe's blue flame says what it
  -- is in the slot's own tooltip, and a question mark needs no words the pane does not already
  -- give it. The slot is pooled, so the stage before it may have shown the target.
  if frame.markHit then
    if markShown and Chain.DiscoveryText(model) then
      frame.markHit:Show()
    else
      frame.markHit:Hide()
    end
  end
  if frame.pin then
    if model.pinned then
      frame.pin:Show()
    else
      frame.pin:Hide()
    end
  end
  if frame.badges then
    if type(frame.badges.SetSubject) == "function" then
      pcall(frame.badges.SetSubject, frame.badges, model.diffKind, model.id)
    end
    if type(frame.badges.SetKinds) == "function" then
      frame.badges:SetKinds(model.badges)
    end
  end
  if frame.name then
    frame.name:ClearAllPoints()
    frame.name:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.pad, -layout.rows.name)
    frame.name:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -layout.pad, -layout.rows.name)
    frame.name:SetHeight(layout.line * 2)
    if type(frame.name.SetWordWrap) == "function" then
      frame.name:SetWordWrap(true)
    end
    if type(frame.name.SetMaxLines) == "function" then
      pcall(frame.name.SetMaxLines, frame.name, 2)
    end
    setText(frame.name, model.name)
    textColor(frame.name, model.nameColor)
    frame.name:Show()
  end
  if frame.meta then
    if layout.rows.meta and model.metaLine then
      frame.meta:ClearAllPoints()
      frame.meta:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.pad, -layout.rows.meta)
      frame.meta:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -layout.pad, -layout.rows.meta)
      frame.meta:SetHeight(layout.line)
      setText(frame.meta, model.metaLine)
      frame.meta:Show()
    else
      setText(frame.meta, "")
      frame.meta:Hide()
    end
  end
  local altText = rect.altText or Chain.AlternativesText(model.alternativeCount)
  local coText = rect.coText or model.coReagentText
  applyControl(frame.altControl, layout.rows.control, altText, layout, frame, rect.altWidth, rect.width)
  applyControl(frame.coControl, layout.rows.co, coText, layout, frame, rect.coWidth, rect.width)
  frame:Show()
  return frame
end

local function buildArrow(index)
  local pool = Chain.arrowFrames
  if pool[index] then
    return pool[index]
  end
  local canvas = Chain.canvas
  if not canvas then
    return nil
  end
  local frame = newFrame("Frame", canvas)
  if not frame then
    return nil
  end
  frame.label = newText(frame, Chain.FONT_SM, "ITEMTREE_COLOR_TEXT_MUTED", "CENTER")
  frame.shaft = wash(frame, "ARTWORK", Chain.ARROW_COLOR)
  if frame.shaft then
    frame.shaft:SetHeight(Chain.BORDER)
    frame.shaft:Show()
  end
  -- The head is the client's own right chevron, tinted to the shaft. A build without the
  -- atlas draws the shaft alone rather than a blank square.
  frame.head = type(frame.CreateTexture) == "function" and frame:CreateTexture(nil, "OVERLAY") or nil
  if applyGlyph(frame.head, "ICON_CHEVRON_EXPAND", Chain.ARROW_COLOR) then
    frame.head:SetSize(Chain.ARROW_HEAD, Chain.ARROW_HEAD)
    frame.head:Show()
  elseif frame.head then
    frame.head:Hide()
    frame.head = nil
  end
  pool[index] = frame
  return frame
end

-- The quantity sits above the line, never on it: the label fills the rect down to the shaft,
-- which the layout put on the icon's own centre.
local function applyArrow(frame, rect, layout)
  frame.active = true
  frame:SetSize(rect.width, rect.height)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", Chain.canvas, "TOPLEFT", rect.x, -rect.y)
  if frame.label then
    frame.label:ClearAllPoints()
    frame.label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.label:SetHeight(layout.line)
    setText(frame.label, rect.text or "")
    frame.label:Show()
  end
  applyShaft(frame, rect)
  frame:Show()
  return frame
end

local function hideFrom(pool, from)
  for index = from, #pool do
    pool[index].active = false
    pool[index]:Hide()
  end
end

local function setEmptyShown(shown)
  for _, region in pairs({ title = Chain.emptyTitle, line = Chain.emptyLine }) do
    if shown then
      region:Show()
    else
      region:Hide()
    end
  end
  local bar = Chain.controls and Chain.controls.bar
  if bar then
    if shown then
      bar:Hide()
    else
      bar:Show()
    end
  end
  if shown and Chain.selector then
    Chain.selector:Hide()
  end
end

-- The selector reads the chain in hand and offers the rest. One chain through a root is no
-- choice at all, so the button is not drawn: an item with one use should not look as though
-- the pane is hiding something.
local function updateSelector(full)
  local selector = Chain.selector
  if not selector then
    return false
  end
  local model = Chain.SelectorModel(full)
  Chain.selectorModel = model
  if not model.shown then
    selector:Hide()
    return false
  end
  -- Never wide enough to reach the zoom controls in the other corner, however narrow the
  -- window is dragged: the label is truncated instead.
  local region = measure(Chain.region, "GetWidth") or 0
  local bar = measure(Chain.controls and Chain.controls.bar, "GetWidth") or 0
  local room = region - bar - Chain.PAD * 6
  local width = Chain.SELECTOR_W
  if room > 0 and room < width then
    width = math.max(room, Chain.CONTROL_H * 2)
  end
  selector:SetWidth(width)
  setText(selector.label, model.label)
  selector:Show()
  return true
end

local function runOf(stages)
  local keys = {}
  for index, stage in ipairs(stages) do
    keys[index] = tostring(type(stage) == "table" and stage.key or index)
  end
  return table.concat(keys, ">")
end

--- Redraws the chain in hand. The zoom is refitted whenever the run of stages changes, which
--- is what "the whole chain on open" amounts to, and left alone on a redraw of the same chain
--- so a player who has zoomed in keeps their place. Swapping a stage for an alternative or a
--- co-reagent changes the run, so the new chain is fitted and centred the way a new root is.
function Chain.Draw()
  local canvas = Chain.canvas
  if not (Chain.viewport and canvas) then
    return false
  end
  Chain.CloseMenu()
  local full = Chain.full or NO_CHAIN
  local stages = type(full.stages) == "table" and full.stages or EMPTY
  local rootIndex = tonumber(full.rootIndex) or 0
  local layout = Chain.Layout(stages, rootIndex, { measure = rulerWidth })
  Chain.layout = layout

  if #stages < 2 or rootIndex < 1 then
    hideFrom(Chain.stageFrames, 1)
    hideFrom(Chain.arrowFrames, 1)
    canvas:Hide()
    setEmptyShown(true)
    Chain.run = nil
    return true
  end

  setEmptyShown(false)
  updateSelector(full)
  canvas:Show()
  canvas:SetSize(math.max(layout.width, 1), math.max(layout.height, 1))
  -- The text on the arrow that enters each stage, by the stage it enters.
  local incoming = {}
  for _, rect in ipairs(layout.arrows) do
    incoming[rect.into] = rect.text
  end
  for index, stage in ipairs(stages) do
    local frame = buildStage(index)
    if frame then
      local pinned = Chain.IsPinned(stage.slot, stage.key)
      local model = Chain.StageModel(stage, index == rootIndex, pinned)
      applyStage(frame, model, layout, layout.stages[index], incoming[index])
    end
  end
  hideFrom(Chain.stageFrames, #stages + 1)
  for index, rect in ipairs(layout.arrows) do
    local frame = buildArrow(index)
    if frame then
      applyArrow(frame, rect, layout)
    end
  end
  hideFrom(Chain.arrowFrames, #layout.arrows + 1)

  local run = runOf(stages)
  if run ~= Chain.run then
    Chain.run = run
    Chain.Fit()
  else
    Chain.SetPan(Chain.panX, Chain.panY)
  end
  return true
end

--------------------------------------------------------------------------------
-- Panning, the wheel and the zoom controls
--------------------------------------------------------------------------------

-- The stage the cursor is over, if any. A drag that starts on one is a click on the way to
-- somewhere else, never a pan, so every stage stays clickable.
local function stageUnderMouse()
  for _, frame in ipairs(Chain.stageFrames) do
    if frame.active and type(frame.IsMouseOver) == "function" then
      local ok, over = pcall(frame.IsMouseOver, frame)
      if ok and over then
        return frame
      end
    end
  end
  return nil
end

local function stopDrag()
  Chain.drag = nil
  local viewport = Chain.viewport
  if viewport then
    setScript(viewport, "OnUpdate", nil)
  end
  return true
end

local function onDragUpdate()
  local drag = Chain.drag
  if not drag then
    return stopDrag()
  end
  local x, y = cursorPoint()
  if not x then
    return false
  end
  -- Screen y runs up and the pan runs down, so the vertical delta is taken the other way.
  Chain.SetPan(drag.panX + (x - drag.x), drag.panY - (y - drag.y))
  return true
end

local function onViewportMouseDown(_, button)
  if button and button ~= "LeftButton" then
    return false
  end
  -- A press over the open list is the player picking a row, so it is neither a pan nor a reason
  -- to close: the same rule the catcher holds.
  if Chain.MenuHasCursor() then
    return false
  end
  -- E39: a press on bare canvas is the player putting an open list away, so it is voiced. A
  -- press that lands on a stage is the stage's own click and is left to speak for itself.
  local onStage = stageUnderMouse()
  Chain.CloseMenu(not onStage)
  if onStage then
    return false
  end
  local x, y = cursorPoint()
  if not x then
    return false
  end
  Chain.drag = { x = x, y = y, panX = Chain.panX, panY = Chain.panY }
  setScript(Chain.viewport, "OnUpdate", onDragUpdate)
  return true
end

local function onViewportWheel(_, delta)
  delta = tonumber(delta) or 0
  if delta == 0 then
    return false
  end
  Chain.CloseMenu()
  local factor = delta > 0 and Chain.ZOOM_STEP or (1 / Chain.ZOOM_STEP)
  local pointerX, pointerY = pointerOffsets()
  Chain.ZoomBy(factor, pointerX, pointerY)
  return true
end

local function controlButton(parent, text, width, hint, onClick)
  local button = newFrame("Button", parent)
  if not button then
    return nil
  end
  button:SetSize(width, Chain.CONTROL_H)
  button.face = wash(button, "BACKGROUND", "ITEMTREE_COLOR_BUTTON_FACE")
  if button.face then
    button.face:SetAllPoints(button)
    button.face:Show()
  end
  insetBorder(button, Chain.PANEL_BORDER)
  button.hover = wash(button, "HIGHLIGHT", "ITEMTREE_COLOR_STATE_HOVER")
  if button.hover then
    button.hover:SetAllPoints(button)
    button.hover:Show()
  end
  button.label = newText(button, Chain.FONT_SM, "ITEMTREE_COLOR_TEXT_BODY", "CENTER")
  if button.label then
    button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
    setText(button.label, text)
  end
  if type(button.RegisterForClicks) == "function" then
    pcall(button.RegisterForClicks, button, "LeftButtonUp")
  end
  setScript(button, "OnClick", onClick)
  setScript(button, "OnEnter", function(self)
    showHint(self, hint)
  end)
  setScript(button, "OnLeave", onLeaveHideTooltip)
  return button
end

--- Brief PR13: the zoom controls' button, shared so the Professions tab's zoom reads as this
--- one: ControlButton(parent, text, width, hint, onClick). Answers the button, or nil.
Chain.ControlButton = controlButton

-- A corner control sits over the viewport, which fills the region, so it is raised above it by
-- hand: a control the canvas could cover is no control at all. Level 0 is a real answer, so it
-- is read straight rather than through the positive number helper.
local function raiseAbove(frame, region)
  local level = number(region, "GetFrameLevel")
  if level and type(frame.SetFrameLevel) == "function" then
    pcall(frame.SetFrameLevel, frame, level + 10)
  end
  return true
end

--- Brief UX2 (the owner, 2026-10-23: the Map tab's zoom reuses this view's controls): THE ZOOM BAR,
--- shared so the Map tab's zoom reads as this one. Fills a bar frame the caller has already made,
--- sized to Chain.CONTROL_H and anchored, with one Chain.ControlButton per entry laid out from the
--- bar's right edge leftwards, Chain.PAD apart, and the muted zoom readout left of the last of them:
---
---   entries  { { key, text, width, hint, onClick }, ... } in order from the right
---
--- Answers { bar, [key] = button, ..., label, width }, the bar sized to what it holds.
function Chain.ZoomBar(bar, entries)
  if type(bar) ~= "table" then
    return nil
  end
  local controls = { bar = bar }
  local width, previous = 0, nil
  for _, entry in ipairs(type(entries) == "table" and entries or {}) do
    local button = controlButton(bar, entry.text, entry.width, entry.hint, entry.onClick)
    controls[entry.key] = button
    if button then
      button:SetPoint("RIGHT", previous or bar, previous and "LEFT" or "RIGHT", previous and -Chain.PAD or 0, 0)
      width = width + entry.width + (previous and Chain.PAD or 0)
      previous = button
    end
  end
  controls.label = newText(bar, Chain.FONT_SM, "ITEMTREE_COLOR_TEXT_MUTED", "RIGHT")
  if controls.label then
    controls.label:SetPoint("RIGHT", previous or bar, previous and "LEFT" or "RIGHT", -Chain.PAD, 0)
    controls.label:SetWidth(Chain.ZOOM_LABEL_W)
    width = width + Chain.ZOOM_LABEL_W + Chain.PAD
  end
  bar:SetWidth(math.max(width, Chain.CONTROL_H))
  controls.width = width
  return controls
end

-- The zoom readout and its three buttons, in the top right corner of the pane. They sit on the
-- region rather than the viewport, so nothing the canvas does can move or clip them.
local function buildControls(region)
  local bar = newFrame("Frame", region)
  if not bar then
    return nil
  end
  bar:SetHeight(Chain.CONTROL_H)
  bar:SetPoint("TOPRIGHT", region, "TOPRIGHT", -Chain.PAD * 2, -Chain.PAD * 2)
  raiseAbove(bar, region)

  return Chain.ZoomBar(bar, {
    {
      key = "fit",
      text = L["Fit"],
      width = 32,
      hint = L["Fit the whole chain"],
      onClick = function()
        Chain.Fit()
      end,
    },
    {
      key = "plus",
      text = "+",
      width = Chain.CONTROL_H,
      hint = L["Zoom in"],
      onClick = function()
        Chain.ZoomBy(Chain.ZOOM_STEP)
      end,
    },
    {
      key = "minus",
      text = "-",
      width = Chain.CONTROL_H,
      hint = L["Zoom out"],
      onClick = function()
        Chain.ZoomBy(1 / Chain.ZOOM_STEP)
      end,
    },
  })
end

-- The chain selector, top left of the pane: which of the chains through this root is drawn.
-- Its own frames rather than UIDropDownMenu, which is global and taints.
local function buildSelector(region)
  local selector = newFrame("Button", region)
  if not selector then
    return nil
  end
  selector:SetSize(Chain.SELECTOR_W, Chain.CONTROL_H)
  selector:SetPoint("TOPLEFT", region, "TOPLEFT", Chain.PAD * 2, -Chain.PAD * 2)
  raiseAbove(selector, region)
  selector.face = wash(selector, "BACKGROUND", "ITEMTREE_COLOR_BUTTON_FACE")
  if selector.face then
    selector.face:SetAllPoints(selector)
    selector.face:Show()
  end
  insetBorder(selector, Chain.PANEL_BORDER)
  selector.hover = wash(selector, "HIGHLIGHT", "ITEMTREE_COLOR_STATE_HOVER")
  if selector.hover then
    selector.hover:SetAllPoints(selector)
    selector.hover:Show()
  end
  selector.chevron = type(selector.CreateTexture) == "function" and selector:CreateTexture(nil, "OVERLAY") or nil
  if applyGlyph(selector.chevron, "ICON_CHEVRON_COLLAPSE", "ITEMTREE_COLOR_TEXT_BODY") then
    selector.chevron:SetSize(Chain.MENU_ACTION, Chain.MENU_ACTION)
    selector.chevron:SetPoint("RIGHT", selector, "RIGHT", -Chain.PAD, 0)
  else
    selector.chevron = nil
  end
  selector.label = newText(selector, Chain.FONT_SM, "ITEMTREE_COLOR_TEXT_BODY", "LEFT")
  if selector.label then
    selector.label:SetPoint("LEFT", selector, "LEFT", Chain.PAD, 0)
    selector.label:SetPoint("RIGHT", selector, "RIGHT", -(Chain.PAD * 2 + Chain.MENU_ACTION), 0)
    if type(selector.label.SetWordWrap) == "function" then
      selector.label:SetWordWrap(false)
    end
  end
  if type(selector.RegisterForClicks) == "function" then
    pcall(selector.RegisterForClicks, selector, "LeftButtonUp")
  end
  setScript(selector, "OnClick", function()
    Chain.OpenChoices()
  end)
  setScript(selector, "OnEnter", function(self)
    showHint(self, L["Choose which chain to show"])
  end)
  setScript(selector, "OnLeave", onLeaveHideTooltip)
  selector:Hide()
  return selector
end

local function buildEmpty(region)
  Chain.emptyTitle = newText(region, FONTS.ITEMTREE_FONTSIZE_BODY_MD, "ITEMTREE_COLOR_TEXT_MUTED", "CENTER")
  if Chain.emptyTitle then
    Chain.emptyTitle:SetPoint("CENTER", region, "CENTER", 0, Chain.LINE)
    setText(Chain.emptyTitle, L["No chain from this item"])
    Chain.emptyTitle:Hide()
  end
  Chain.emptyLine = newText(region, Chain.FONT_SM, "ITEMTREE_COLOR_TEXT_HINT", "CENTER")
  if Chain.emptyLine then
    local title = Chain.emptyTitle
    Chain.emptyLine:SetPoint("TOP", title or region, title and "BOTTOM" or "CENTER", 0, -Chain.PAD)
    setText(Chain.emptyLine, L["Nothing links this item to another one in either direction."])
    Chain.emptyLine:Hide()
  end
  return Chain.emptyTitle ~= nil
end

-- The recessed panel the strip sits in (core/InsetPanel.jsx): the inset surface under a 1px
-- edge, drawn whether there is a chain or not, so an empty pane reads as a panel rather than a
-- hole in the window.
local function buildPanel(region)
  local surface = wash(region, "BACKGROUND", Chain.PANEL_SURFACE)
  if surface then
    surface:SetAllPoints(region)
    surface:Show()
  end
  Chain.panel = { surface = surface, border = insetBorder(region, Chain.PANEL_BORDER) }
  return Chain.panel
end

local function buildViewport(region)
  local viewport = newFrame("Frame", region)
  if not viewport then
    return nil
  end
  local edge = Chain.BORDER
  viewport:SetPoint("TOPLEFT", region, "TOPLEFT", edge, -edge)
  viewport:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -edge, edge)
  if type(viewport.EnableMouse) == "function" then
    viewport:EnableMouse(true)
  end
  if type(viewport.EnableMouseWheel) == "function" then
    viewport:EnableMouseWheel(true)
  end
  -- Clipping is what keeps a zoomed chain inside the pane. A client without it culls instead,
  -- which is what Chain.clips decides.
  Chain.clips = false
  if type(viewport.SetClipsChildren) == "function" then
    Chain.clips = pcall(viewport.SetClipsChildren, viewport, true) and true or false
  end
  setScript(viewport, "OnMouseDown", onViewportMouseDown)
  setScript(viewport, "OnMouseUp", stopDrag)
  setScript(viewport, "OnMouseWheel", onViewportWheel)
  setScript(viewport, "OnHide", function()
    stopDrag()
    Chain.CloseMenu()
    -- Brief SF1: a chain is held only while it is looked at; the next showing reads Core afresh.
    Chain.DropCache()
  end)
  -- A resized window is a new fit: the whole chain is what the view is for.
  setScript(viewport, "OnSizeChanged", function()
    if Chain.viewport and Chain.layout then
      Chain.Fit()
    end
  end)
  return viewport
end

-- The click catcher under the drop down list. UIParent where the client has one, so a click
-- anywhere on the screen closes the list; the region otherwise, which is as far as this pane
-- can see.
local function buildCatcher(region)
  local host = rawget(_G, "UIParent")
  if type(host) ~= "table" then
    host = region
  end
  local catcher = newFrame("Frame", host)
  if not catcher then
    return nil
  end
  catcher:SetAllPoints(host)
  if type(catcher.EnableMouse) == "function" then
    catcher:EnableMouse(true)
  end
  setStrata(catcher, Chain.CATCHER_STRATA)
  -- Never the press that belongs to a row. The catcher is a screen wide trap and the rows now
  -- answer the press themselves, so a catcher that closed on any press at all could take the
  -- pick off the row it was meant for and leave the player looking at the chain they already
  -- had. The client's own menu manager asks the same question before it closes anything
  -- (MenuManagerMixin:ContainsCursor, Blizzard_Menu/Menu.lua on the `forever` branch).
  setScript(catcher, "OnMouseDown", function()
    if Chain.MenuHasCursor() then
      return false
    end
    return Chain.CloseMenu(true)
  end)
  catcher:Hide()
  return catcher
end

local function buildMenu(region)
  local menu = newFrame("Frame", region)
  if not menu then
    return nil
  end
  menu:SetSize(Chain.MENU_W, Chain.MENU_ROW_H)
  menu.face = wash(menu, "BACKGROUND", "ITEMTREE_COLOR_SURFACE_STICKY")
  if menu.face then
    menu.face:SetAllPoints(menu)
    menu.face:Show()
  end
  insetBorder(menu, Chain.PANEL_BORDER)
  setStrata(menu, Chain.MENU_STRATA)
  -- The list takes the mouse itself, so a click that lands between two rows stops there rather
  -- than falling through to the catcher and closing the list from under the player.
  if type(menu.EnableMouse) == "function" then
    pcall(menu.EnableMouse, menu, true)
  end
  if type(menu.EnableMouseWheel) == "function" then
    pcall(menu.EnableMouseWheel, menu, true)
  end
  -- A long list opened near the bottom of the screen is dragged back onto it rather than drawn
  -- off the edge, where every row past the edge is one nothing can click.
  if type(menu.SetClampedToScreen) == "function" then
    pcall(menu.SetClampedToScreen, menu, true)
  end
  setScript(menu, "OnMouseWheel", function(_, delta)
    Chain.ScrollMenu(delta)
  end)

  -- The scroll indicator: a track down the right hand edge with a thumb on it.
  menu.track = wash(menu, "ARTWORK", "ITEMTREE_COLOR_BORDER_DIVIDER")
  if menu.track then
    menu.track:SetWidth(Chain.MENU_SCROLLER_W)
    menu.track:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -Chain.BORDER, -Chain.BORDER)
    menu.track:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -Chain.BORDER, Chain.BORDER)
    menu.track:Hide()
  end
  menu.thumb = wash(menu, "OVERLAY", Chain.PIN_COLOR)
  if menu.thumb then
    menu.thumb:SetWidth(Chain.MENU_SCROLLER_W)
    menu.thumb:Hide()
  end
  -- Escape closes the list and nothing else: every other key is handed straight back to the
  -- client, so typing is never swallowed by an open menu. Brief E91: never decided in combat.
  takeMenuKeyboard(menu)
  setScript(menu, "OnKeyDown", function(self, key)
    local propagate = key ~= "ESCAPE"
    menuPropagate(self, propagate)
    if not propagate then
      Chain.CloseMenu(true)
    end
  end)
  local ui = ItemTree.UI
  local Frame = type(ui) == "table" and ui.Frame or nil
  if type(Frame) == "table" and type(Frame.OnCombatStart) == "function" then
    Frame.OnCombatStart("Chain.menu", function()
      menuPropagate(Chain.menu, true)
      menuKeyboard(Chain.menu, false)
    end, function()
      takeMenuKeyboard(Chain.menu)
    end)
  end
  setScript(menu, "OnHide", function()
    hideCatcher()
  end)
  menu:Hide()
  return menu
end

--------------------------------------------------------------------------------
-- The window's contract
--------------------------------------------------------------------------------

--- Builds the pane inside the region the window created and sized. Idempotent, and false with
--- no client, which leaves Show and Refresh as no ops.
function Chain.Attach(region)
  if type(region) ~= "table" then
    return false
  end
  if Chain.region == region and Chain.viewport then
    return true
  end
  if not globalFn("CreateFrame") then
    return false
  end
  Chain.region = region
  Chain.stageFrames, Chain.arrowFrames, Chain.menuRows = {}, {}, {}
  Chain.menuEntries, Chain.menuOffset = nil, 0
  Chain.menuWidth, Chain.menuScrolls = nil, false
  Chain.layout, Chain.run, Chain.drag, Chain.full = nil, nil, nil, nil
  Chain.zoom, Chain.panX, Chain.panY = 1, 0, 0
  Chain.pins, Chain.choice, Chain.prefer = {}, nil, nil
  Chain.DropCache()
  -- The trail survives a re-attach on purpose: it is a session log the owner reads after the
  -- fact. Only the pick in flight is dropped, because there is no longer a list to finish it.
  Chain.pick = nil

  buildPanel(region)
  local viewport = buildViewport(region)
  if not viewport then
    Chain.region = nil
    return false
  end
  Chain.viewport = viewport
  local canvas = newFrame("Frame", viewport)
  if not canvas then
    Chain.region, Chain.viewport = nil, nil
    return false
  end
  canvas:SetSize(1, 1)
  canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)
  Chain.canvas = canvas
  -- The tape measure: one hidden font string at the size the controls draw, asked how wide a
  -- label is before a slot is sized for it.
  Chain.ruler = newText(region, Chain.FONT_SM, "ITEMTREE_COLOR_TEXT_MUTED", "LEFT")
  if Chain.ruler then
    Chain.ruler:Hide()
  end
  -- The event first: where the client answers it, no frame of ours ever sits over a row. The
  -- catcher is still built, because a client that refuses the event has nothing else.
  watchGlobalMouse()
  Chain.catcher = buildCatcher(region)
  Chain.menu = buildMenu(region)
  Chain.selector = buildSelector(region)
  Chain.controls = buildControls(region)
  buildEmpty(region)
  updateZoomLabel()
  return true
end

--- Draws the chain for a root key. The window calls this whenever it draws with the Item chain
--- view up, a new root included. Remembers the key even with no client, so a later Attach and Refresh
--- draws the right thing. A new root is a new chain: the selector's choice and every pin go
--- with the old one, and the node the player came from is read once, here, because that is
--- when the window knows it.
function Chain.Show(rootKey)
  local changed = rootKey ~= nil and rootKey ~= Chain.rootKey
  if rootKey ~= nil then
    Chain.rootKey = rootKey
  end
  -- The first draw after the window hands the pane its region counts as a change: the pane was
  -- given a key before there was a client to ask the window anything.
  if changed or Chain.full == nil then
    Chain.pins, Chain.choice = {}, nil
    Chain.prefer = previousKey(Chain.rootKey)
  end
  if not Chain.viewport then
    return false
  end
  Chain.shown = true
  Chain.full = chainFor(Chain.rootKey)
  if Chain.region and type(Chain.region.Show) == "function" then
    Chain.region:Show()
  end
  return Chain.Draw()
end

--- Redraws the last root, re-reading the chain from Core (brief SF1: the held chains go first).
function Chain.Refresh()
  Chain.DropCache()
  return redraw()
end

--- Hides the pane and everything it raised.
function Chain.Hide()
  Chain.shown = false
  stopDrag()
  Chain.CloseMenu()
  hideTooltip()
  if not Chain.region then
    return false
  end
  Chain.region:Hide()
  return true
end

-- The window builds and attaches the pane, so there is nothing to do at load. Kept because
-- every panel carries an Init.
function Chain.Init()
  return false
end

return Chain
