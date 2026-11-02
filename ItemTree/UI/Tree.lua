-- The tree pane: a flat virtualised row list over the rows ItemTree.ViewModel hands out.
--
-- Design components: tree/TreeList.jsx, tree/TreeRow.jsx, tree/CategoryRow.jsx,
-- tree/ChangeRow.jsx, tree/ShowMoreRow.jsx, tree/NoticeRow.jsx, tree/LoadingRow.jsx,
-- tree/EmptyState.jsx.
--
-- Anatomy (Theme.sizes):
--   ITEMTREE_LIST_ROW_H 22, ITEMTREE_LIST_ROW_H_COMPACT 18 (density setting)
--   ITEMTREE_LIST_CATEGORY_H 24, ITEMTREE_LIST_CHANGE_H 20
--   ITEMTREE_LIST_INDENT 14 per depth, compressed to 6 past depth 6 (Theme.Indent)
--   Columns: ITEMTREE_LIST_CHEVRON 12, ITEMTREE_LIST_ICON 20, name fills,
--   ITEMTREE_LIST_COL_QUANTITY 40, ITEMTREE_LIST_COL_META 104,
--   ITEMTREE_LIST_COL_BADGES 48 right aligned, ITEMTREE_LIST_COL_COUNT 36 on category rows
--   ITEMTREE_SCROLLBAR_W 16
--
-- Client APIs: ScrollBox with CreateScrollBoxListLinearView over CreateDataProvider (the
-- ViewModel already flattens the tree, so the linear view is the right one), initialised
-- with ScrollUtil.InitScrollBoxListWithScrollBar and a MinimalScrollBar. Every one of those
-- is pcall'd, and a client that carries none of them falls back to a plain frame pool inside
-- a ScrollFrame that draws only the rows the offset shows. Assets.Apply for icons,
-- Badges.CreateCluster(row, 16, 3) for the badge column.
--
-- Everything above the divider is pure and runs under busted with no WoW API:
--   Tree.Layout(row, density, opts)   one row's height, indent, columns, colours and badges
--   Tree.Extent(row, density, opts)   the same row's height alone, with no table built
--   Tree.Interpret(row, click)        what a click on a column means: toggle, more, reroot
--   Tree.KeyboardMove(rows, i, key)   what up, down, left, right and enter mean
--   Tree.Window(extents, offset, h)   which rows a scroll offset shows
--   Tree.Overflows(total, height)     whether the list is taller than the pane
--   Tree.ListRightInset(overflows)    how far in from the pane's right edge the rows stop
--   Tree.WidestCount(rows)            the longest count a category header in the list draws
--   Tree.CountWidth(text, size, px)   the room that count needs, so its badges sit against it
--   Tree.BadgeOverhang(size)          how far a badge's medallion stands proud of its own box
--   Tree.BadgeColumn(count, size)     the room a cluster of that many badges really takes
--   Tree.IconSize(rowHeight, wanted)  the icon box a row this tall has room for
--   Tree.MarkSize(iconSize)           the corner glyph that fits inside that icon
--   Tree.SearchInsets(templated)      the search box art's overhang, so its edges line up
--   Tree.StickyIndex(rows, first)     the category row the sticky header mirrors
--   Tree.FilterRows(rows, text)       the search box's view over the rows
--   Tree.IsSummary(row)               whether a row stands for a group rather than for a thing
--   Tree.PlacedTarget(row)            the zone and item a placed object row opens (brief M15)
--   Tree.OpensList(row)               whether the table ships the rest of that group's list
--   Tree.IsQuietSummary(row)          a summary row that cannot be pressed, drawn as plain words
--   Tree.SummaryText(row)             the words that row draws, "2 more, not listed here"
--   Tree.MoreText(row)                the words a "Show N more" row draws
--   Tree.MoreTooltipText(row)         that row's tooltip line, "Show 15 more, level 11 to 36"
--   Tree.ChangeText(change)           the words a change row draws, moved, added or removed
--   Tree.SourceText(row)              the type, zone, rate and tally a source row draws
--   Tree.SourceColumns(width)         which of those three columns a pane that wide can hold
--   Tree.HasEraRows(rows)             whether any row on screen is Classic Era history
--   Tree.EraBanner(rows, filter)      the quiet line at the top of the pane, and its tooltip
--   Tree.BadgeBasis(row)              what a row's Predicted mark is predicted from
--   Tree.BadgeNote(row)               the lines a row's Community note mark says on hover (E93)
--   Tree.MarkLabel(row)               "Recipe (Blacksmithing)" for a row that is not an item
--   Tree.ClassSpell(row)              the class spell a "Reagent for" row names, or nil (P5b)
--   Tree.NoPage(row)                  a Classic Era creature row with no page, which opens nothing
--   Tree.ClassSpellText(row)          "Reagent for the Shaman spell Water Breathing"
--   Tree.EnchantEffect(node)          "Stamina +2", what an enchanting recipe's enchant does
--   Tree.RowText(node, row)           a row's name, with that effect in brackets after it
--   Tree.EmptyState(view, discovery)  the designed block a view with nothing in it draws
--   Tree.RecipeMark()                 the corner glyph a craft a recipe item taught wears
--   Tree.YieldText(craft, w, size)    "4" or "1-2" in the corner of a merged craft's icon
--   Tree.YieldLabel(craft)            "Makes 4", the same fact in the row's tooltip
--   Tree.TotalLabel(row)              "12 in all: 1 per craft, 12 crafts" (brief TC1)
--   Tree.RecipeLabels(craft)          "Taught by Recipe: Thistle Tea", one line per recipe
--   Tree.DiffSubject(node)            the diff kind and id a badge cluster hovers over
--   Tree.SkillLineOf(row)             the profession a category row stands for
--   Tree.CategoryHeader(row)          what that profession says about the player
--   Tree.SkillRows(rows)              the rows plus each profession's specialisation row
--   Tree.PlaceholderText()            what the search box says before anything is typed
-- The frame code below the divider only draws those answers.
--
-- The search box sits at the top of the pane, across its whole width, because the tree is the
-- half that narrows. What is typed is debounced and handed to ItemTree.UI.Frame.SetTextFilter,
-- which forwards it back to Tree.SetTextFilter: one path, so the window still knows what the
-- pane is filtered by. The filter is a view over vm:Rows() and never touches the view model,
-- and Show and Refresh honour it. Frame clearing the filter writes the box back to empty.
--
-- Walking up (the Sources direction) a row carries the source facts Core/Sources.lua worked
-- out, and the pane draws them as the columns the removed Sources tab had: the type, the zone,
-- the rate or price, and the confidence badge at the right edge. The columns are measured from
-- the pane's real width and the widest are dropped rather than squeezing the name past its
-- floor, so every row of a category lines up whatever the window has been resized to.
--
-- A row whose node is a spell or an enchant rather than an item takes a small corner glyph on
-- a dark backing over its icon, so "Linen Boots" the recipe is not "Linen Boots" the item.
--
-- A Sources view showing a row out of the shipped historical Classic Era table (brief E28)
-- carries one quiet line across the top of the pane saying so, with a tooltip that explains in
-- plain language why nobody has real Forever drop data yet. It is not a row of the view: it
-- takes its own strip off the top of the pane the way the search box does, so nothing counts it,
-- the keyboard cursor cannot reach it, the filter never sees it, and typing in the search box
-- takes it down with the rows it was standing over.
--
-- A row of kind "hint" is a quiet footnote the view model adds at the foot of a list (the world
-- drop note under a creature's Loot tab). It is counted nowhere and does nothing when clicked.
-- The source hint that used to offer other addons here is gone (brief E1).
--
-- Under Used by, with settings.mergeCrafts on, the view model draws a craft and the one item it
-- makes as a single row for that item (row.merged, row.craft). Such a row is an item row in
-- every other way: no spell mark, the item's quality and tooltip, and the craft's own quantity
-- and skill in the columns the craft's row used. What it adds is the yield in the bottom right
-- corner of the icon, where the client writes a stack count, and the recipe mark in the top
-- left where a recipe item taught the craft rather than a trainer.
--
-- Contract with UI/Frame.lua, which owns the window and the single ViewModel:
--   Frame calls Tree.Attach(region) once with a child frame it created and sized, then
--   Tree.Show(vm) on every open, re-root and refresh. Show re-reads vm:Rows() and redraws,
--   Tree.Refresh() redraws from the last vm, Tree.Hide() hides the pane. All idempotent, and
--   all no-ops with no client. After the pane mutates the view model (vm:Toggle on a chevron
--   or a category, vm:ShowMore on a "Show N more" row) it calls ItemTree.UI.Frame.Refresh(),
--   looked up lazily, and never redraws itself. Clicking a row's name re-roots through
--   ItemTree.UI.Frame.Open(nodeKey). Keys are the view model's own strings and node ids are
--   read back through ItemTree.Graph, never by parsing. The pane never creates a view model,
--   never walks the graph and never touches saved variables.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local Tree = {}
ItemTree.UI.Tree = Tree

local Theme = ItemTree.Theme
local Assets = ItemTree.Assets
local Badges = ItemTree.Badges
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}
local SIZES = Theme.sizes

-- Column widths and paddings, straight from the design tokens.
Tree.PAD = SIZES.ITEMTREE_SPACE_1
Tree.GUTTER = SIZES.ITEMTREE_LIST_GUTTER
Tree.CHEVRON = SIZES.ITEMTREE_LIST_CHEVRON
Tree.ICON = SIZES.ITEMTREE_LIST_ICON
Tree.CATEGORY_ICON = SIZES.ITEMTREE_ICON_CATEGORY
Tree.MARK = SIZES.ITEMTREE_ICON_BADGE
Tree.QUANTITY = SIZES.ITEMTREE_LIST_COL_QUANTITY
Tree.META = SIZES.ITEMTREE_LIST_COL_META
Tree.BADGES = SIZES.ITEMTREE_LIST_COL_BADGES
Tree.COUNT = SIZES.ITEMTREE_LIST_COL_COUNT
Tree.SCROLLBAR = SIZES.ITEMTREE_SCROLLBAR_W
-- The source columns, the same tokens the removed Sources tab measured its table with.
Tree.SOURCE_TYPE = SIZES.ITEMTREE_LIST_COL_META
Tree.SOURCE_ZONE = SIZES.ITEMTREE_LIST_COL_ZONE
Tree.SOURCE_RATE = SIZES.ITEMTREE_LIST_COL_RATE
-- The design's SearchBox is a medium control with a 12px glyph in it, and the list starts one
-- gutter under it.
Tree.SEARCH_H = SIZES.ITEMTREE_CONTROL_H_MD
Tree.SEARCH_ICON = SIZES.ITEMTREE_ICON_TOGGLE
Tree.SEARCH_GAP = SIZES.ITEMTREE_LIST_GUTTER
Tree.BADGE_TREE = SIZES.ITEMTREE_BADGE_SIZE_TREE
Tree.BADGE_LIST = SIZES.ITEMTREE_BADGE_SIZE_LIST
Tree.BADGE_MAX_ROW = 3
Tree.BADGE_MAX_CATEGORY = 2
Tree.BORDER = SIZES.ITEMTREE_BORDER_HAIRLINE
-- Brief PR29: the "Show nearest" button on a "Sold by" header (and, brief PR34, a "Trainer" one), a
-- plate button (Frame.NewPlateButton) with words on it, a little shorter than the header and as
-- wide as its words plus NEAREST_PAD each side.
Tree.NEAREST_H = SIZES.ITEMTREE_LIST_CATEGORY_H - 6
Tree.NEAREST_PAD = SIZES.ITEMTREE_SPACE_1

-- The count on a category header is right aligned at the row's padding and the badges sit
-- immediately to its left, so the column is only as wide as the widest count the list draws
-- and never wider than the design's own 36px column. An Arial Narrow digit runs a little over
-- half the font size wide, which is what a client that will not measure the string gets.
Tree.COUNT_CHAR = 0.6

-- The corner glyph and its backing both sit inside the icon box: the glyph is pulled in by a
-- hairline so the backing, which is a pixel wider again, lands exactly on the icon's corner.
-- Nothing a row draws may cross into the row above or below it, because the rows abut.
Tree.MARK_INSET = SIZES.ITEMTREE_BORDER_HAIRLINE

-- E44: the chest in the corner is its own hover target, so the player can point at the mark
-- itself and be told in words what it means. The target is the glyph's own rect with a couple of
-- pixels of slop around it, which is a 14px mark at 18px: small enough that the row under it is
-- still what the pointer lands on nearly everywhere, big enough to hit.
Tree.MARK_HIT_SLOP = 2

-- The mark a merged craft row wears when a recipe item taught the craft. Asked for through
-- Assets.Has, the way the empty state's illustration is, so a build without the key draws no
-- mark rather than raising.
Tree.RECIPE_MARK_KEY = "ICON_RECIPE_MARK"

-- InputBoxVisualTemplate, which SearchBoxTemplate inherits, hangs its left border art five
-- pixels outside the edit box and keeps the right one flush: Blizzard_SharedXML's
-- SecureUIPanelTemplates.xml, identical on the classic_era and classic_beta branches of the
-- wow-ui-source mirror. A box anchored flush to the pane therefore draws its edge left of the
-- list panel under it, so the frame is pushed in by exactly that much instead. A box the pane
-- drew itself has no overhang at all.
Tree.SEARCH_ART_LEFT = 5
Tree.SEARCH_ART_RIGHT = 0

-- The list sits in a recessed panel (core/InsetPanel.jsx): the inset surface behind it and a
-- 1px edge around it, so an empty pane still reads as a panel rather than a hole in the
-- window. Drawn as four hairlines rather than a nine slice, because the live clients'
-- NineSliceUtil is atlas oriented and a file layout renders as a dotted edge.
Tree.PANEL_SURFACE = "ITEMTREE_COLOR_SURFACE_INSET"
Tree.PANEL_BORDER = "ITEMTREE_COLOR_BORDER_GOLD_DIM"

-- CategoryRow.jsx draws every category header on the sticky surface, with the divider hairline
-- along its top edge, so Blacksmithing and Requirements read as sections rather than rows.
Tree.CATEGORY_BAND = "ITEMTREE_COLOR_SURFACE_STICKY"
Tree.BORDER_COLOR = "ITEMTREE_COLOR_BORDER_DIVIDER"

-- The name column never collapses past this, so a very deep row still reads.
Tree.MIN_NAME_W = 80

-- The empty state is a centred block rather than a row, so it gets the pane height when the
-- caller passes one and this much at the very least: the message plus room around it.
Tree.EMPTY_MIN_H = SIZES.ITEMTREE_LIST_ROW_H * 3

-- Every empty state wraps. The words take the pane less generous padding on both sides and
-- never run wider than a paragraph, because a sentence stretched across a wide window reads as
-- a single long line and a sentence with nowhere to wrap ran off the pane entirely, which is
-- what the owner saw. A pane too narrow for the generous padding keeps the list padding instead
-- of giving up its words.
Tree.EMPTY_MAX_W = 420
Tree.EMPTY_PAD = SIZES.ITEMTREE_SPACE_6
Tree.EMPTY_MIN_W = 160

-- The designed empty state: an illustration, a heading and the paragraph under it. It offers
-- nothing: the owner's ruling for the first release is that no other addon is promoted.
--
-- The art is a picture rather than a glyph, so it is drawn at its own shape at EMPTY_ART_W wide
-- and never in an icon square: no border, no quality frame, no tint. A pane too short for the
-- whole block shrinks it rather than pushing the heading and the lines off the
-- bottom, down to EMPTY_ART_MIN_W and then away altogether, because a player who cannot read
-- what the pane is offering has lost more than a picture. 160 is twice the old chest glyph and
-- still leaves air around the block in the default window.
Tree.EMPTY_ART_W = 160
Tree.EMPTY_ART_MIN_W = 88
Tree.EMPTY_GAP = SIZES.ITEMTREE_SPACE_3
Tree.EMPTY_LINE_GAP = SIZES.ITEMTREE_SPACE_2

-- How tall the block is reckoned to be before a single string has been drawn, so it can be
-- placed as though it were centred: an Arial Narrow glyph runs about half the font size wide,
-- and a wrapped line takes the design's prose line height.
Tree.EMPTY_CHAR = 0.5

-- The illustration over the sources empty state: the owner's own dragon curled round a treasure
-- chest, the key this file asks UI/Assets.lua for. That file is not this one's, so the key is
-- asked for behind Assets.Has and the client's own chest icon stands in where it is not there,
-- the way UI/Badges.lua falls back from a shipped medallion to the composed form.
Tree.EMPTY_ART_KEY = "ART_EMPTY_SOURCES"
Tree.EMPTY_ART_FALLBACK = "ART_EMPTY_SOURCES_ICON"

-- Loop rows are dimmed whole. A predicted or guessed row is never dimmed (brief T9): its badge,
-- the group notice and the confidence column carry the meaning. Only the undiscovered placeholder
-- dims its name, a separate case: nobody can say what that item is yet.
Tree.LOOP_ALPHA = 0.55
Tree.UNDISCOVERED_ALPHA = 0.6

-- The 12 percent white row wash, which is what ITEMTREE_COLOR_STATE_HOVER resolves to.
Tree.HOVER_ALPHA = Theme.colors.ITEMTREE_COLOR_STATE_HOVER.a

-- The note tinted wash behind a notice row (NoticeRow.jsx draws it at 6 percent).
Tree.NOTICE_ALPHA = 0.06

-- The quiet banner across the top of the pane while a Classic Era row is on screen: one line in
-- the muted face behind a small info mark, no box art and no wash, above the list rather than in
-- it. It takes its own strip off the top of the pane the way the search box does, which is what
-- keeps it out of the rows: nothing counts it, the keyboard cursor cannot reach it and the
-- filter never sees it.
Tree.BANNER_H = SIZES.ITEMTREE_LIST_ROW_H
Tree.BANNER_GAP = SIZES.ITEMTREE_SPACE_1
Tree.BANNER_ICON = SIZES.ITEMTREE_ICON_BADGE
Tree.BANNER_ART = "BADGE_INFO"
Tree.BANNER_COLOR = "ITEMTREE_COLOR_TEXT_MUTED"

-- Every kind the pane draws. "skill" is the only one the view model does not produce: the pane
-- puts it under a profession header for the specialisation the player holds. "strip" is the
-- pane's own as well, and EXPERIMENTAL (brief E25): the row of ingredient icons under a craft.
Tree.ROW_KINDS = { "category", "skill", "row", "change", "more", "notice", "empty", "loading", "hint", "strip" }

-- Layout alignment to the client's own justify token. Only the token is American.
Tree.JUSTIFY = { left = "LEFT", right = "RIGHT", centre = "CENTER" }

-- The client font objects a font string is created from, in the order they are tried. The
-- template is handed to CreateFontString so the string has a font before anything can write to
-- it, and the rest are what a client that refused the template is offered instead. A font
-- string with no font at all raises from inside SetText on the beta, which is the whole point.
Tree.FONT_TEMPLATE = "GameFontNormalSmall"
Tree.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }

-- The client's own search box, where the client carries it, and how long a keystroke is held
-- back so a fast typist pays for one scan rather than one per letter.
Tree.SEARCH_TEMPLATE = "SearchBoxTemplate"
Tree.SEARCH_DEBOUNCE = 0.15

-- E53: the creature's own portrait on a source row, and what keeps it from costing anything.
--
-- SetPortraitTextureFromCreatureDisplayID hands the texture a render target the client fills in
-- asynchronously, so the call itself is cheap (measured in the beta on 2026-09-20: 0.75 ms and
-- 1.50 ms for two uncached display ids, 0.01 ms for a cached one) and the model load behind it
-- is not. Two hundred rows dragged past under the pointer would ask for two hundred of them, so
-- the pane asks for none of that:
--
--   * a row draws its kind icon AT ONCE, exactly as it did before, and the portrait only ever
--     replaces it later;
--   * a row must stay on screen for PORTRAIT_DWELL before it is served, so dragging the scroll
--     bar through a long list asks for nothing at all;
--   * at most PORTRAIT_PER_FRAME calls go out per frame, from one queue on one OnUpdate driver
--     that runs only while the queue has something in it;
--   * the queue never holds more than PORTRAIT_QUEUE rows, because a queue longer than the list
--     on screen is a queue of rows nobody is looking at any more.
--
-- The dwell is the search box's own debounce, for the same reason: it is the pause that tells a
-- player who has stopped from one who is still moving.
Tree.PORTRAIT_DWELL = 0.15
Tree.PORTRAIT_PER_FRAME = 1
Tree.PORTRAIT_QUEUE = 40

-- Node kind to the Assets glyph a row draws when the node carries no art of its own. A
-- requirement is not listed: the view model names its glyph on the node itself (CAT_REQUIREMENT),
-- so the pane reads it rather than keeping a second mapping that can drift.
local NODE_ICONS = {
  quest = "QUEST_AVAILABLE",
  npc = "CAT_DROPS",
  object = "CAT_CHEST",
  zone = "CAT_ZONE",
  skill = "CAT_NOTE",
  set = "CAT_SET",
  enchant = "CAT_ENCHANTING",
}

-- Node kind to the diff kind Core/Diff.lua files its changes under, which is what a badge
-- cluster is told so it can show the old to new lines on hover. Same table as ViewModel's.
local DIFF_KINDS = { item = "items", spell = "recipes", skill = "skills", enchant = "enchants" }

-- The node kinds that are not items and therefore take the corner glyph. A row whose node is
-- one of these says so in its tooltip as well, because the glyph alone only says "not an item".
local MARK_KINDS = { spell = true, enchant = true }

-- The source columns, right to left from the badge column, and the order they are given up in
-- when the pane is too narrow to keep the name readable. The type goes first, because walking
-- up the category header over the row already says it ("Drops from", "Sold by"); then the
-- zone, which is the widest; and the rate, the one thing nothing else states, is the last.
local SOURCE_ORDER = { "sourceRate", "sourceZone", "sourceType" }
local SOURCE_DROP = { "sourceType", "sourceZone", "sourceRate" }
local SOURCE_W = {
  sourceRate = Tree.SOURCE_RATE,
  sourceZone = Tree.SOURCE_ZONE,
  sourceType = Tree.SOURCE_TYPE,
}
local SOURCE_ALIGN = { sourceRate = "right", sourceZone = "left", sourceType = "left" }

-- The keys the pane answers to, normalised from what OnKeyDown reports. Enter is not one of
-- them: the pane holds the keys whenever the pointer is over it, and a player pressing Enter to
-- type in chat got nothing, so Enter goes back to the client and opens the chat box.
Tree.NAV_KEYS = {
  UP = "UP",
  DOWN = "DOWN",
  LEFT = "LEFT",
  RIGHT = "RIGHT",
}

-- Density from the settings, defaulting to the design's 22px rows.
function Tree.Density()
  local settings = ItemTree.db and ItemTree.db.settings
  return (settings and settings.density) == "compact" and "compact" or "default"
end

--- Whether a creature row may ask the client for the creature's own portrait. On by default,
--- and the one thing a player on a slow computer turns off: with it off nothing is ever queued
--- and every creature row keeps the kind icon brief E50 gave it. Written as an explicit if,
--- because a nil setting is the default rather than the off answer.
function Tree.PortraitsEnabled()
  local settings = ItemTree.db and ItemTree.db.settings
  if settings and settings.creaturePortraits == false then
    return false
  end
  return true
end

--- The creature display id a row would draw its portrait from, or nil for every row that is not
--- a creature the shipped table states one for. The view model put it on the node
--- (Core/ViewModel.lua CreaturePortrait) and this only reads it back. Pure.
function Tree.PortraitOf(row)
  local node = type(row) == "table" and type(row.node) == "table" and row.node or nil
  local display = node and node.portrait or nil
  if type(display) ~= "number" or display <= 0 or display ~= math.floor(display) then
    return nil
  end
  return display
end

--- Puts one request in the queue and answers it, or nil for one it will not take.
---
--- An entry is { frame, row, display, at }: the frame drawing the row, the row itself so a
--- recycled frame can be told from the one that asked, and when the row appeared. A frame
--- already in the queue is REPLACED rather than queued twice, because a pooled frame drawing
--- another row is another request and the one before it is dead. Past the cap the oldest goes.
--- Pure: it mutates only the queue it is handed.
function Tree.PortraitPush(queue, entry, cap)
  if type(queue) ~= "table" or type(entry) ~= "table" or entry.frame == nil then
    return nil
  end
  Tree.PortraitDrop(queue, entry.frame)
  queue[#queue + 1] = entry
  local limit = tonumber(cap) or 0
  while limit > 0 and #queue > limit do
    table.remove(queue, 1)
  end
  return entry
end

--- Takes every request one frame has out of the queue and answers how many went. A row that is
--- recycled, hidden or re-rooted away drops out this way. Pure.
function Tree.PortraitDrop(queue, frame)
  if type(queue) ~= "table" or frame == nil then
    return 0
  end
  local gone = 0
  for index = #queue, 1, -1 do
    local entry = queue[index]
    if type(entry) ~= "table" or entry.frame == frame then
      table.remove(queue, index)
      gone = gone + 1
    end
  end
  return gone
end

--- Which request to serve next: the first whose dwell has passed, which is the one that has
--- been waiting longest, because the queue is in the order the rows asked. nil while nothing
--- has settled yet, which is what a list being dragged past looks like. Pure.
function Tree.PortraitReady(queue, now, dwell)
  if type(queue) ~= "table" then
    return nil
  end
  local at = tonumber(now) or 0
  local wait = tonumber(dwell) or 0
  for index = 1, #queue do
    local entry = queue[index]
    if type(entry) == "table" and (tonumber(entry.at) or 0) + wait <= at then
      return index, entry
    end
  end
  return nil
end

--- Drops every request the caller's own test says is gone, and answers how many went. The test
--- is what asks whether the frame is still drawing the row that queued it; this only walks.
--- Pure.
function Tree.PortraitPrune(queue, isLive)
  if type(queue) ~= "table" or type(isLive) ~= "function" then
    return 0
  end
  local gone = 0
  for index = #queue, 1, -1 do
    if isLive(queue[index]) ~= true then
      table.remove(queue, index)
      gone = gone + 1
    end
  end
  return gone
end

local function assetKey(key, fallback)
  if type(key) == "string" and Assets.Has(key) then
    return key
  end
  return fallback
end

-- The view model already names a category's glyph, because it knows the skill line behind it.
-- A key this build does not carry falls back through Assets, then to the note icon.
local function categoryIcon(row, node)
  local key = node and node.icon
  if type(key) == "string" and Assets.Has(key) then
    return key
  end
  local category = type(row.category) == "table" and row.category or nil
  local skillLine = category and tonumber(category.skillLine) or nil
  if skillLine and type(Assets.ForSkill) == "function" then
    return Assets.ForSkill(skillLine)
  end
  return "CAT_NOTE"
end

--- The skill line a category row stands for, or nil when it is not a profession.
--
-- The view model names it on the category itself; a row that carries no category table still
-- answers, because the view model keys a profession category by its skill line id and
-- everything else by a slug, which is the same read the harness does.
function Tree.SkillLineOf(row)
  row = type(row) == "table" and row or EMPTY
  local category = type(row.category) == "table" and row.category or nil
  local skillLine = category and tonumber(category.skillLine) or nil
  if skillLine then
    return skillLine
  end
  local id = category and category.id or nil
  if type(id) == "string" and id:match("^%d+$") then
    return tonumber(id)
  end
  local key = type(row.key) == "string" and row.key:match("^cat:(%d+)$") or nil
  return key and tonumber(key) or nil
end

-- The player's trade skills, which the window reads from the client. Looked up lazily and
-- guarded: UI/Frame.lua loads before this file and may not carry PlayerSkills on this build,
-- and a player with no professions is the same answer as a window that cannot say.
local function playerSkills()
  local ui = ItemTree.UI
  local frame = type(ui) == "table" and ui.Frame or nil
  if type(frame) ~= "table" or type(frame.PlayerSkills) ~= "function" then
    return nil
  end
  local ok, skills = pcall(frame.PlayerSkills)
  if ok and type(skills) == "table" then
    return skills
  end
  return nil
end

--- Brief BQ14: a category row's rarity circles (its category's qualities, Tooltip.QualityDots), or ""
--- for none or while the tooltip module is not there. Pure over the row.
function Tree.QualityDots(row)
  local category = type(row) == "table" and type(row.category) == "table" and row.category or nil
  local mask = category and tonumber(category.qualities) or nil
  local tooltip = ItemTree.Tooltip
  if not mask or mask <= 0 or type(tooltip) ~= "table" or type(tooltip.QualityDots) ~= "function" then
    return ""
  end
  local ok, dots = pcall(tooltip.QualityDots, mask)
  return ok and type(dots) == "string" and dots or ""
end

--- What a profession category header says about the player, or nil when there is nothing to
--- say: the category is not a profession, the player does not have it, or the window cannot
--- say yet. The wording is all Core's, so the pane and the harness read the same.
function Tree.CategoryHeader(row)
  local skillLine = Tree.SkillLineOf(row)
  if not skillLine then
    return nil
  end
  local Skills = ItemTree.Skills
  if type(Skills) ~= "table" or type(Skills.CategoryHeader) ~= "function" then
    return nil
  end
  local skills = playerSkills()
  if not skills then
    return nil
  end
  local category = type(row) == "table" and row.category or nil
  if type(category) ~= "table" or not tonumber(category.skillLine) then
    category = skillLine
  end
  local ok, header = pcall(Skills.CategoryHeader, category, skills)
  if ok and type(header) == "table" and type(header.line) == "string" then
    return header
  end
  return nil
end

-- Theme keeps its quality keys private, so the key is built from the exported names rather
-- than copied. An unknown quality falls back to body cream.
local function qualityKey(quality)
  local name = Theme.QUALITY_NAMES[quality or 1]
  if not name then
    return "ITEMTREE_COLOR_TEXT_BODY"
  end
  local key = "ITEMTREE_COLOR_QUALITY_" .. name:upper()
  return Theme.colors[key] and key or "ITEMTREE_COLOR_TEXT_BODY"
end

-- Items and recipes take Blizzard's quality colour, everything else body cream. An item this
-- build withholds has no quality to colour by and must not borrow one: it reads muted until
-- something outside the data names it, and then in whatever quality that answered.
local function nameColorFor(node)
  if type(node) ~= "table" then
    return "ITEMTREE_COLOR_TEXT_BODY"
  end
  if node.undiscovered and not node.discovered then
    return "ITEMTREE_COLOR_TEXT_MUTED"
  end
  if node.kind == "item" or node.kind == "spell" then
    return qualityKey(node.quality)
  end
  return "ITEMTREE_COLOR_TEXT_BODY"
end

-- What a category header writes in its count column. One function, because the column is
-- measured from the widest of these and then laid out from the same string.
local function countTextOf(row)
  return tostring((type(row) == "table" and row.count) or 0)
end

-- "x28", "x1 to 2", "78%" or nothing. Numbers read the way the client writes them.
local function quantityText(node)
  if type(node) ~= "table" then
    return ""
  end
  if node.quantity then
    if node.quantityMax and node.quantityMax ~= node.quantity then
      return string.format("x%s to %s", tostring(node.quantity), tostring(node.quantityMax))
    end
    return "x" .. tostring(node.quantity)
  end
  if node.percent then
    return tostring(node.percent) .. "%"
  end
  return ""
end

--------------------------------------------------------------------------------
-- EXPERIMENTAL (brief E25): what a craft is made of, on the craft's own row.
--
-- Core works the ingredients out (Core/ViewModel.lua, opts.craftIngredients) and every craft row
-- in the Used by view carries row.ingredients and row.tools. This file draws them four ways, so
-- the owner can flip between them in game and keep one:
--   tooltip  an Ingredients block on the row's tooltip
--   group    the muted "Ingredients (n)" group Core adds as the craft's first child, drawn here
--            as a plain row with a dimmer chevron where the group is all the craft has
--   strip    a small button at the row's right hand end that opens a strip of icons under it
--   card     UI/InfoPanel.lua draws a Recipe card while the row is hovered
-- Every piece of it is marked E25 and gated on the mode, so the losers come out cleanly.
--
-- Brief E30: no drawing site compares the mode's word any more. Each asks Core whether the mode
-- in force draws its surface (Tree.CraftShows), so "all" switches three of them on at once and
-- the tooltip block can no longer turn up in a mode that never asked for it.
--------------------------------------------------------------------------------

-- The icon in a strip cell and how far apart the cells sit. A category glyph rather than a row
-- icon: the strip is a quiet second line under a row and must not out weigh the row's own art.
Tree.STRIP_ICON = SIZES.ITEMTREE_ICON_CATEGORY
Tree.STRIP_GAP = SIZES.ITEMTREE_LIST_GUTTER
-- The gap between an icon and the count beside it, which is tighter than the gap between two
-- cells so a count reads as belonging to the icon on its left.
Tree.STRIP_COUNT_GAP = 2
-- Brief LF1 (QA item 246): a reagent's icon on the tooltip block's line, the item tooltip's own icon
-- size (UI/Tooltip.lua ICON_SIZE_KEY, the profession glyph on "Made by [glyph] Alchemy").
Tree.INGREDIENT_ICON = SIZES.ITEMTREE_BADGE_SIZE_TOOLTIP or 14
-- The root's own icon in the strip: the item the player is already reading, dimmed rather than
-- marked, because a mark on it would read as a badge.
Tree.STRIP_ROOT_ALPHA = 0.45

-- The button that opens and closes a strip, in the client's own expander art. PLUS and MINUS are
-- already in UI/Assets.lua, so this mode adds no asset key of its own.
Tree.STRIP_OPEN_ASSET = "MINUS"
Tree.STRIP_SHUT_ASSET = "PLUS"

-- The strips the player has opened, keyed by row key, for the session. The pane's own state and
-- nothing the view model or the saved variables ever hear about, which is what lets a strip
-- survive a refresh and cost nothing at all in the other four modes.
Tree.strips = {}

-- The chevron on a craft row whose only child is the ingredient group ("group" mode): still a
-- chevron, because the row does open, and dimmer, so "this goes on to make something" can still
-- be told from "this only lists what it is made of" at a glance.
Tree.CHEVRON_COLOR = "ITEMTREE_COLOR_TEXT_MUTED"
Tree.CHEVRON_COLOR_DIM = "ITEMTREE_COLOR_TEXT_DISABLED"

--- Brief Z1: a zone column that is a link is written in the gold every link in the window wears
--- (UI/InfoPanel.lua's link words), and its hover on a zone's Here tab says what a click does.
Tree.ZONE_LINK_COLOR = "ITEMTREE_COLOR_TEXT_TITLE"
Tree.ZONE_PICK_HINT = "Click to show %s on the map"

--- Brief GS3: a guessed source's row. The rate column's "Guess" wears the guess colour (the muted
--- rose the owner chose, UI/Theme.lua), and the name the muted face, so a guess never reads as a
--- row somebody saw.
Tree.GUESS_RATE_COLOR = "ITEMTREE_COLOR_SEMANTIC_GUESS"
Tree.GUESS_NAME_COLOR = "ITEMTREE_COLOR_TEXT_MUTED"

--- Brief C6: the name colour of a guessed row. A guess that names a creature, a place or a vendor
--- (an item's Sources view) reads muted, so the eye lands on the real rows first; a guess whose row
--- is an item (a creature's Predicted loot) keeps the colour the item row already chose, its
--- quality, the same token path as a Classic Era drop row. Pure.
function Tree.GuessNameColor(node, itemColor)
  if type(node) == "table" and node.kind == "item" and type(itemColor) == "string" then
    return itemColor
  end
  return Tree.GUESS_NAME_COLOR
end

--- Brief T2b: a vendor's title after its name ("Trader Selm <Wrought Iron Supplies>") and the
--- "Alliance only" a source the player's side cannot use says where its rate would be, both in the
--- muted face.
Tree.TITLE_COLOR = "ITEMTREE_COLOR_TEXT_MUTED"
Tree.FACTION_COLOR = "ITEMTREE_COLOR_TEXT_MUTED"
--- The fewest characters of a title worth drawing once it has been cut short, the ellipsis apart.
Tree.TITLE_MIN_CHARS = 4

--- Brief T2b: the player's own side, "Alliance" or "Horde", or nil. Tree.playerFaction states it for
--- a spec; otherwise it is Core/Sources.lua's Favour.PlayerFaction, which asks UnitFactionGroup once
--- a session under pcall and keeps the answer, so every row costs a table read. Guarded: a load
--- with no Sources, or no client, answers nil and every row says nothing about sides.
Tree.playerFaction = nil
function Tree.PlayerFaction()
  if Tree.playerFaction == "Alliance" or Tree.playerFaction == "Horde" then
    return Tree.playerFaction
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

--- Brief T2b: "Alliance only" or "Horde only" for a row whose source serves the other side alone,
--- or nil: a source for both sides, one whose side nobody states, a player whose side is unknown,
--- and every source the player's own side can use. The rule is Core's (Core/Graph.lua
--- Graph.FactionOnly, the same hook Core/Keep.lua reads), so the tree and Keep agree. playerSide
--- defaults to Tree.PlayerFaction(). Pure over what it is handed.
function Tree.FactionOnlyText(row, playerSide)
  local edge = type(row) == "table" and type(row.edge) == "table" and row.edge or nil
  if not edge then
    return nil
  end
  local graph = ItemTree.Graph
  if type(graph) ~= "table" or type(graph.FactionOnly) ~= "function" then
    return nil
  end
  -- Brief FX14: a quest row's side is the shipped lists' (Graph.FactionOnly), so it is asked even
  -- where the edge states no faction; any other row with none says nothing, as before.
  local quest = type(graph.Kind) == "function" and graph.Kind(edge.target) == "quest"
  if edge.faction == nil and not quest then
    return nil
  end
  if playerSide == nil then
    playerSide = Tree.PlayerFaction()
  end
  local ok, side = pcall(graph.FactionOnly, edge, playerSide)
  if not ok then
    return nil
  end
  if side == "Alliance" then
    return L["Alliance only"]
  end
  if side == "Horde" then
    return L["Horde only"]
  end
  -- Brief RB2 (owner QA 2026-10-17 item 194): a quest open to both that our data leans to the other
  -- side says "Possibly Horde only" in the same muted place (Core/Graph.lua Graph.LeanWords). A
  -- lean is no side: Keep never reads it.
  if quest and type(graph.LeanWords) == "function" then
    local asked, lean = pcall(graph.LeanWords, edge.target, playerSide)
    if asked and type(lean) == "string" then
      return lean
    end
  end
  return nil
end

--- Brief QN1: "Seen by Alliance players" or "Seen by Horde players" on a player sourced vendor row
--- whose edge states the side of the players who recorded it (edge.seenSide, Core/PlayerSources.lua
--- SaleSide), which is never a faction: a side seen is not a side served. nil otherwise. Pure.
function Tree.SeenSideText(row)
  local edge = type(row) == "table" and type(row.edge) == "table" and row.edge or nil
  local side = edge and edge.seenSide or nil
  if side == 1 then
    return L["Seen by Alliance players"]
  end
  if side == 2 then
    return L["Seen by Horde players"]
  end
  return nil
end

--- Brief T2b: the title a row's edge carries for the vendor, trainer or quest giver it points at, or
--- nil. Pure.
function Tree.RowTitle(row)
  local edge = type(row) == "table" and type(row.edge) == "table" and row.edge or nil
  local title = edge and edge.title or nil
  if type(title) ~= "string" or title == "" then
    return nil
  end
  return title
end

--- Brief T2b: a name with the vendor's title after it, as the plain words and the drawn string:
--- "Trader Selm <Wrought Iron Supplies>", the title in the muted face. text is what the name column
--- would say without it ("Trader Selm (limited stock 5)"), and name the node's own name, which the
--- title goes straight after when text starts with it; otherwise the title ends the line.
---
--- A short column cuts the TITLE first: width and fontSize estimate the room the way the type
--- column's is (Tree.SourceTypeLine), the title is cut to fit and ends in "...", and one with fewer
--- than Tree.TITLE_MIN_CHARS characters left is dropped, so the name keeps every character it can.
--- No width (a caller with no pane in front of it) keeps the whole title. Pure.
function Tree.TitledName(text, name, title, width, fontSize)
  text = type(text) == "string" and text or ""
  if type(title) ~= "string" or title == "" or text == "" then
    return text, nil
  end
  local head, rest = text, ""
  if type(name) == "string" and name ~= "" and text:sub(1, #name) == name then
    head, rest = name, text:sub(#name + 1)
  end
  local room = tonumber(width)
  if room then
    local size = tonumber(fontSize) or Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_MD
    local chars = math.floor(room / (size * Tree.COUNT_CHAR))
    -- " <" and ">" around the title, and the name and whatever follows it.
    local left = chars - #head - #rest - 3
    if left < #title then
      if left - 3 < Tree.TITLE_MIN_CHARS then
        return text, nil
      end
      title = title:sub(1, left - 3) .. "..."
    end
  end
  local bracketed = "<" .. title .. ">"
  local plain = head .. " " .. bracketed .. rest
  local rich = head .. " " .. Theme.Colorise(Tree.TITLE_COLOR, bracketed) .. rest
  return plain, rich
end

--- Brief P6b: the words the side icon on an NPC's row stands for, by the shipped table's own side
--- numbers (cf): the row's tooltip says them under the zone. 3 is both sides, which the window
--- calls neutral. Each is the English wording and its own locale key.
Tree.SIDE_WORDS = { [1] = "Alliance", [2] = "Horde", [3] = "Neutral (both sides)" }

--- Brief P6b: the side the NPC a row names serves, 1 Alliance, 2 Horde or 3 both, or nil. Only a
--- row whose node is an npc has one: a vendor's or a trainer's row carries its side on the edge
--- (cf, brief T2b), and any other npc row (a quest giver, a creature, a vendor the player saw) is
--- asked of the shipped table by the name its key joins (Core/EraSources.lua E:NpcNameAt, a key's
--- arithmetic or one lookup, and E:Faction, one more). A quest row's side is the quest's and an
--- item's is its vendor's, so neither wears one. Guarded; pure over what it is handed and the
--- table it reads.
function Tree.RowSide(row)
  if type(row) ~= "table" or (row.kind or "row") ~= "row" or type(row.summary) == "table" then
    return nil
  end
  local node = type(row.node) == "table" and row.node or nil
  local key = node and node.key or nil
  local graph = ItemTree.Graph
  if type(key) ~= "string" or type(graph) ~= "table" or type(graph.Parse) ~= "function" then
    return nil
  end
  local okKey, kind = pcall(graph.Parse, key)
  if not okKey or kind ~= "npc" then
    return nil
  end
  local edge = type(row.edge) == "table" and row.edge or nil
  local side = edge and edge.faction or nil
  if Tree.SIDE_WORDS[side] then
    return side
  end
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.NpcNameAt) ~= "function" or type(era.Faction) ~= "function" then
    return nil
  end
  local okName, nameIndex = pcall(era.NpcNameAt, era, key)
  if not okName or type(nameIndex) ~= "number" then
    return nil
  end
  local okSide, answer = pcall(era.Faction, era, nameIndex)
  if okSide and Tree.SIDE_WORDS[answer] then
    return answer
  end
  return nil
end

--- Brief P6b: the word a side's icon stands for, translated ("Alliance", "Horde", "Neutral (both
--- sides)"), or nil. Pure.
function Tree.SideText(side)
  local word = Tree.SIDE_WORDS[side]
  if not word then
    return nil
  end
  return L[word]
end

--- Brief P6b: the zone column's words with the side icon before them, "|A:...|a Ironforge", or the
--- icon alone on a row that names no zone, or the zone alone where there is no side (or the
--- Assets table carries no key for it). size is the icon's side in pixels. Pure.
function Tree.SideZoneText(zone, side, size)
  zone = type(zone) == "string" and zone or ""
  local key = type(Assets.SIDES) == "table" and Assets.SIDES[side] or nil
  if not key or (type(Assets.Has) == "function" and not Assets.Has(key)) then
    return zone
  end
  local ok, markup = pcall(Assets.Markup, key, tonumber(size) or Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_SM)
  if not ok or type(markup) ~= "string" then
    return zone
  end
  if zone == "" then
    return markup
  end
  return markup .. " " .. zone
end

--- The mode in force, from the settings table. Core owns the six words and what anything else
--- means, so this asks rather than checking the string itself; a build with neither a settings
--- table nor a ViewModel reads as off, which is the tree with none of this in it.
function Tree.CraftIngredients()
  local settings = ItemTree.db and ItemTree.db.settings
  local ViewModel = ItemTree.ViewModel
  if type(ViewModel) == "table" and type(ViewModel.CraftIngredients) == "function" then
    local ok, mode = pcall(ViewModel.CraftIngredients, settings and settings.craftIngredients)
    if ok and type(mode) == "string" then
      return mode
    end
  end
  return "off"
end

--- Whether the mode draws one of the four surfaces ("tooltip", "group", "strip", "card"). Core
--- owns the rule (Core/ViewModel.lua CRAFT_INGREDIENT_SURFACES), so a mode added there needs no
--- edit here. A caller that already holds a mode passes it, which is what keeps Tree.Layout pure;
--- a caller with none reads the setting. A build with no ViewModel draws no surface at all.
function Tree.CraftShows(surface, mode)
  local ViewModel = ItemTree.ViewModel
  if type(ViewModel) ~= "table" or type(ViewModel.CraftIngredientShows) ~= "function" then
    return false
  end
  if mode == nil then
    mode = Tree.CraftIngredients()
  end
  local ok, shows = pcall(ViewModel.CraftIngredientShows, mode, surface)
  if not ok then
    return false
  end
  return shows == true
end

--- The craft behind a row, as its spell key, or nil for a row that is not a craft row. A merged
--- row says so on row.craft; an unmerged one is the spell itself. Pure.
function Tree.CraftKey(row)
  if type(row) ~= "table" then
    return nil
  end
  local craft = type(row.craft) == "table" and row.craft or nil
  if craft and type(craft.key) == "string" then
    return craft.key
  end
  local node = type(row.node) == "table" and row.node or nil
  if node and node.kind == "spell" and type(node.key) == "string" then
    return node.key
  end
  return nil
end

--- Whether a row is one of the ingredient rows the group mode adds: the group header itself or
--- one of its leaves. Nothing counts them and the search drops both, so every mode lists and
--- counts alike. Pure.
function Tree.IsIngredientRow(row)
  if type(row) ~= "table" then
    return false
  end
  return row.ingredientGroup == true or row.ingredient == true
end

--- "x2", or "" where the recipe states no count. The quantity column's own writer, so a count in
--- a strip, in a tooltip and in the column can never be written three ways. Pure.
function Tree.IngredientCount(part)
  return quantityText(part)
end

--- Brief LF1 (QA item 246, the owner: "And add the icon to the ingredients liek we do for
--- professions"): the inline texture escape for a reagent's icon at size px, the way the item
--- tooltip's profession lines wear their glyph (UI/Tooltip.lua Tooltip.Icon: an escape inside the
--- line's own text, ITEMTREE_BADGE_SIZE_TOOLTIP square): an Assets key through Assets.Markup, a file
--- data id or a texture path straight into the escape. "" where the part carries no icon, so the line
--- has no gap. The icon is the one the row already carries (the graph's own, from our data), so no
--- item is ever asked for. Pure.
function Tree.IngredientIcon(icon, size)
  local box = math.max(math.floor(tonumber(size) or Tree.INGREDIENT_ICON), 1)
  if type(icon) == "string" and icon ~= "" and type(Assets.Has) == "function" and Assets.Has(icon) then
    local ok, markup = pcall(Assets.Markup, icon, box)
    return ok and type(markup) == "string" and markup or ""
  end
  if (type(icon) == "number" and icon > 0) or (type(icon) == "string" and icon ~= "") then
    return string.format("|T%s:%d:%d|t", tostring(icon), box, box)
  end
  return ""
end

--- Brief LF1 (the owner's QA item 246, 2026-10-18: "The quantities should be [N] x [incgredient]. So
--- Ingredients: / 1 x Silverleaf"): one reagent's line in the tooltip block, its icon first
--- (Tree.IngredientIcon) then "1 x Silverleaf" ("2 to 4 x Silverleaf" for a stated range), the bare
--- name where the recipe states no count. The strip and the quantity column keep
--- Tree.IngredientCount's "x1". Pure.
function Tree.IngredientLine(part)
  local name = type(part) == "table" and type(part.name) == "string" and part.name or ""
  local count = type(part) == "table" and tonumber(part.quantity) or nil
  local text = name
  if count then
    local most = tonumber(part.quantityMax)
    if most and most ~= count then
      text = string.format(L["%d to %d x %s"], count, most, name)
    else
      text = string.format(L["%d x %s"], count, name)
    end
  end
  local icon = Tree.IngredientIcon(type(part) == "table" and part.icon or nil)
  if icon ~= "" then
    return icon .. " " .. text
  end
  return text
end

--- The Ingredients block a craft row's tooltip carries, as { text, colorKey } lines, or an empty
--- list for a row that carries no ingredients (every row at all in the off mode). The mode is
--- asked at the drawing site rather than here: the strip's own button draws this block whatever
--- the tooltip surface says, because the button only exists where the strip does. One line per
--- reagent in its own quality colour (Tree.IngredientLine), led by the heading, and one muted line
--- naming the tools where the recipe asks for any. Brief LF1 (QA item 246, the owner: "Ingredients
--- should be in white and have a colon"): the heading "Ingredients:" in the tooltip's plain white,
--- where E25 wrote "Ingredients" muted; and (the owner: "we want to add some space between
--- ingredients and hte contenst above") after is true where the tooltip already holds lines, and
--- then a blank line leads the block, the " " the item tooltip's own block starts with (UI/Tooltip.lua
--- its spacer), so it stands apart from what is above it; none where it is the first thing. Pure.
function Tree.IngredientLines(row, after)
  local out = {}
  local ingredients = type(row) == "table" and type(row.ingredients) == "table" and row.ingredients or nil
  local tools = type(row) == "table" and type(row.tools) == "table" and row.tools or EMPTY
  if not ingredients or #ingredients == 0 then
    return out
  end
  if after then
    out[#out + 1] = { text = " ", colorKey = "ITEMTREE_COLOR_QUALITY_COMMON", spacer = true }
  end
  out[#out + 1] = { text = L["Ingredients:"], colorKey = "ITEMTREE_COLOR_QUALITY_COMMON" }
  for _, part in ipairs(ingredients) do
    out[#out + 1] = { text = Tree.IngredientLine(part), colorKey = qualityKey(part.quality) }
  end
  local names = {}
  for _, tool in ipairs(tools) do
    if type(tool.name) == "string" and tool.name ~= "" then
      names[#names + 1] = tool.name
    end
  end
  if #names > 0 then
    out[#out + 1] = {
      text = string.format(L["Tools: %s"], table.concat(names, ", ")),
      colorKey = "ITEMTREE_COLOR_TEXT_MUTED",
    }
  end
  return out
end

--- Where every icon of a strip sits, as { lines, cells }: one cell per ingredient, with x
--- measured from the strip's own left edge, line counted from 1, the count text beside it and
--- the part itself for the caller to draw and click. The strip runs left to right and wraps to
--- another line when the next cell would cross the width it was given; a caller with no width to
--- give keeps it all on one line. Pure, and the only place the strip's shape is decided, so the
--- row's height and the icons it draws can never disagree.
function Tree.StripCells(ingredients, width, iconSize, fontSize)
  local cells = { lines = 1, cells = {} }
  ingredients = type(ingredients) == "table" and ingredients or EMPTY
  iconSize = tonumber(iconSize) or Tree.STRIP_ICON
  local size = tonumber(fontSize) or Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_SM
  local room = tonumber(width) or 0
  local x, line = 0, 1
  for _, part in ipairs(ingredients) do
    local text = Tree.IngredientCount(part)
    local cellWidth = iconSize
    if text ~= "" then
      cellWidth = cellWidth + Tree.STRIP_COUNT_GAP + math.ceil(#text * size * Tree.COUNT_CHAR)
    end
    if room > 0 and x > 0 and x + cellWidth > room then
      line = line + 1
      x = 0
    end
    cells.cells[#cells.cells + 1] = {
      x = x,
      line = line,
      width = cellWidth,
      iconSize = iconSize,
      text = text,
      part = part,
      key = part.key,
      root = part.root == true,
    }
    x = x + cellWidth + Tree.STRIP_GAP
  end
  cells.lines = line
  return cells
end

--- How far in a row is DRAWN, which is its own depth.
---
--- E54 drew the rows behind an opened summary one step out from their depth, because they hung
--- off the summary row. E75 draws them in place of the summary's "Show N more" row, at the named
--- rows' own depth, so there is no step left to take and every row is drawn where it sits. The
--- one place the pane measures indents from is still this. Pure.
function Tree.DrawDepth(row)
  if type(row) ~= "table" then
    return 0
  end
  return math.max(0, tonumber(row.depth) or 0)
end

--- The words a "Show N more" row draws. E75: a Classic Era summary is this very row, and carries
--- the table's own words ("Show 184 vendors" where the pipeline named none), so a whole category
--- never reads "Show 184 more". Pure.
function Tree.MoreText(row)
  row = type(row) == "table" and row or EMPTY
  if type(row.text) == "string" and row.text ~= "" then
    return row.text
  end
  return string.format(L["Show %d more"], tonumber(row.moreCount) or tonumber(row.count) or 0)
end

--- The one line a "Show N more" row's tooltip says, or nil where it has nothing to add to the
--- row's own words. A Classic Era summary carries the qualifier its old row ended with ("level 11
--- to 36", the quest it depends on), so its tooltip reads "Show 15 more (level 11 to 36)" (brief
--- LF1, QA item 248: the qualifier in brackets, Core/Sources.lua Sources.Qualified; it read "Show 15
--- more, level 11 to 36"). The group cap's own row carries none and raises no tooltip, as before.
--- Pure.
function Tree.MoreTooltipText(row)
  if type(row) ~= "table" or type(row.note) ~= "string" or row.note == "" then
    return nil
  end
  local text = Tree.MoreText(row)
  local Sources = ItemTree.Sources
  if type(Sources) == "table" and type(Sources.Qualified) == "function" then
    local ok, joined = pcall(Sources.Qualified, text, row.note)
    if ok and type(joined) == "string" and joined ~= "" then
      return joined
    end
  end
  return string.format(L["%s (%s)"], text, row.note)
end

--- Where a strip starts: under the name of the row it belongs to, which is past the pad, the
--- indent, the chevron and the icon. Pure.
function Tree.StripLeft(depth)
  return Tree.PAD + Theme.Indent(tonumber(depth) or 0) + Tree.CHEVRON + Tree.GUTTER + Tree.ICON + Tree.GUTTER
end

--- The rows the pane draws once the open strips are in: the list it was handed, with a strip row
--- under every craft row whose strip the player has opened. open is keyed by row key, which is
--- why a strip survives a refresh and a re-root brings back whatever was open for those very
--- rows. Pure, and it never mutates what it was given: the view model hears nothing about it.
function Tree.StripRows(rows, mode, open)
  rows = type(rows) == "table" and rows or EMPTY
  -- Pure: the mode is the caller's, never the settings table, so a caller that states none gets
  -- the list it handed over.
  if not Tree.CraftShows("strip", mode or "off") or type(open) ~= "table" then
    return rows
  end
  local out, added = {}, false
  for _, row in ipairs(rows) do
    out[#out + 1] = row
    local ingredients = type(row) == "table" and type(row.ingredients) == "table" and row.ingredients or nil
    if ingredients and #ingredients > 0 and type(row.key) == "string" and open[row.key] then
      added = true
      out[#out + 1] = {
        key = row.key .. "/strip",
        kind = "strip",
        depth = tonumber(row.depth) or 0,
        owner = row.key,
        ingredients = ingredients,
        tools = row.tools,
      }
    end
  end
  if not added then
    return rows
  end
  return out
end

-- Brief PS2 (the owner, 2026-10-02: a fact verified in our database wears no mark on its row): the
-- provenance keys whose words go in the row's tooltip only and never behind the type column's word.
-- A player sourced row (Core/PlayerSources.lua) reads "Vendor" or "Drop" alone, and its tooltip
-- keeps the one muted line "Reported by players". Every other provenance keeps its suffix.
Tree.TOOLTIP_ONLY_PROVENANCE = { player = true }

--- What a source row draws in its own columns, or nil for a row that carries no source facts.
---
--- Core works all of it out (Sources.Source), so this only turns it into the strings the
--- columns hold: the type, the zone, the rate or the price where there is no rate, and the
--- collector's tally. seen is a count of sightings and never a quantity, so it is written as
--- "Seen 10" and kept out of the quantity column, which a source row does not draw at all.
function Tree.SourceText(row)
  local source = type(row) == "table" and row.source or nil
  if type(source) ~= "table" then
    return nil
  end
  local typeText = source.typeLabel
  if type(typeText) ~= "string" or typeText == "" then
    typeText = type(source.type) == "string" and L[source.type] or ""
  end
  local price = type(source.price) == "string" and source.price or ""
  local rate = source.rate
  if type(rate) == "number" then
    rate = tostring(rate)
  end
  if type(rate) ~= "string" or rate == "" then
    rate = price
  end
  -- Brief QV2 (owner QA item 266): a quest's own row states how many it gives or asks for (Core/
  -- ViewModel.lua VM:_AppendQuestEntry puts the count on the source), and a source row has no quantity
  -- column, so the count is drawn where the rate would be, the way every other row writes one ("x60").
  -- Only a quest's row carries it: a Sources row's tally stays a tally.
  if rate == "" and tonumber(source.quantity) then
    rate = quantityText(source)
  end
  local seen = tonumber(source.seen)
  -- "via All The Things" for a row an installed source database answered with, and "" for
  -- everything the addon ships and everything this client watched: Core/Sources.lua only sets
  -- the label where a provider stamped the edge, so a collector row never carries one.
  local provenance = source.provenanceLabel
  if type(provenance) ~= "string" then
    provenance = ""
  end
  -- Brief PS2: the words the type column puts behind the type. A provenance the tooltip alone
  -- states (Tree.TOOLTIP_ONLY_PROVENANCE) puts none there, so the row reads its kind word alone.
  local rowProvenance = provenance
  if Tree.TOOLTIP_ONLY_PROVENANCE[source.provenance] then
    rowProvenance = ""
  end
  return {
    type = typeText,
    zone = type(source.zone) == "string" and source.zone or "",
    rate = rate,
    -- The words the row draws in place of the node's own name, and the qualifier inside them on
    -- its own, for the tooltip: "Skum, only while on a quest", "and 239 more, level 11 to 36".
    -- Core writes both (Core/Sources.lua) and both are empty on every row that needs neither.
    name = type(source.name) == "string" and source.name or "",
    note = type(source.note) == "string" and source.note or "",
    -- What the rate column's "~12.5%" says in full ("About 12.5% in Classic Era"), for the row
    -- tooltip, which has room for the whole sentence. Empty on every row but a historical one.
    rateLabel = type(source.rateLabel) == "string" and source.rateLabel or "",
    -- Brief B7: "Classic Era drop rate: ~49%" on a live row that took a Classic Era row's place,
    -- for the tooltip only. Empty on every other row.
    eraRate = type(source.eraRateLine) == "string" and source.eraRateLine or "",
    -- Brief BQ10: true where the rate column draws that Classic Era rate (a combined row stating no
    -- rate of its own), so the tooltip says the figure once, on the Classic Era line.
    eraRateInColumn = source.eraRateInColumn == true and source.eraRateLine ~= nil,
    -- What KIND of creature the row names, in words ("Beast, Wolf, level 23 to 24"). Core words
    -- it (Core/Sources.lua KindText); the row's tooltip says it and the search box matches on it,
    -- and the row's icon is the same fact drawn (Core/ViewModel.lua CreatureIcon). Empty on every
    -- row whose source states no kind, which is everything but a Classic Era creature.
    kind = type(source.kind) == "string" and source.kind or "",
    -- The same band as plain numbers, so a level typed into the search box finds a creature whose
    -- band holds it and not only one whose words happen to carry those digits.
    levelLow = tonumber(source.levelLow),
    levelHigh = tonumber(source.levelHigh),
    price = price,
    -- Brief PS1 bundle prices: how many the vendor's price buys where the words say so ("25c for
    -- 5"), so the rate column makes room for them. nil on every other row.
    bundle = tonumber(source.bundle),
    seen = seen and string.format(L["Seen %d"], seen) or "",
    provenance = provenance,
    rowProvenance = rowProvenance,
    -- True for a row out of the shipped Classic Era table (Core/EraSources.lua): history, not a
    -- fact about the client the player is running. The row says so in its tooltip and the
    -- banner at the top of the pane says it once for the whole view.
    historical = source.historical == true,
    -- Brief GS3: true for a source ItemTree's model guessed (Core/GuessSources.lua). The rate
    -- column says "Guess" in the guess colour, the name is muted, and the tooltip says how strong
    -- the guess is, why, and that nobody has seen it in the game. Empty on every real row.
    guess = source.guess == true,
    guessStrength = type(source.guessStrengthLine) == "string" and source.guessStrengthLine or "",
    guessWhy = type(source.guessWhyLine) == "string" and source.guessWhyLine or "",
    guessLine = type(source.guessLine) == "string" and source.guessLine or "",
  }
end

--- The prediction basis a row's badge cluster explains itself by, or nil for a row whose marks
--- need no explaining beyond their own words. A source row carries it (Core/Sources.lua), and
--- the node carries it for everything else, so a predicted disenchant result and a Classic Era
--- drop can wear the same medallion and say different things under it. Pure.
function Tree.BadgeBasis(row)
  if type(row) ~= "table" then
    return nil
  end
  local source = type(row.source) == "table" and row.source or nil
  local basis = source and source.basis or nil
  if type(basis) ~= "string" then
    local node = type(row.node) == "table" and row.node or nil
    basis = node and node.basis or nil
  end
  -- Brief QB2: a Classic Era reward the quest no longer hands over in Forever (Core/ViewModel.lua
  -- rewardChanged) says so on its Changed mark.
  local rowNode = type(row.node) == "table" and row.node or nil
  if rowNode and rowNode.rewardChanged == true then
    return Tree.BASIS_REWARD_CHANGED
  end
  if type(basis) ~= "string" or basis == "" then
    return nil
  end
  -- Brief BQ15 (QA 2026-10-10 item 2): a Classic Era reward under a quest the Forever client lists
  -- (Core/ViewModel.lua listedReward) says so in its own words: the quest is real, its reward is not
  -- seen yet. Every other row keeps its basis.
  if basis == Tree.BASIS_ERA and row.listedReward == true then
    return Tree.BASIS_ERA_REWARD
  end
  return basis
end

-- Brief BQ15: Core/Confidence.lua BASIS_ERA, and the basis a listed quest's Classic Era reward
-- reads under (UI/Badges.lua MEANING_BY_BASIS).
Tree.BASIS_ERA = "era"
Tree.BASIS_ERA_REWARD = "erareward"
-- Brief QB2: the basis a Classic Era reward reads under where the quest no longer hands it over in
-- Forever (UI/Badges.lua MEANING_BY_BASIS changed).
Tree.BASIS_REWARD_CHANGED = "rewardchanged"

--- Brief BQ15 (QA 2026-10-10 item 5): whether the current character has completed a quest, for the
--- green check beside a quest row's name. The answer is Core/Keep.lua QuestCompleted's, the one Q1's
--- keep rules read "completed" from: one C_QuestLog.IsQuestFlaggedCompleted per quest, remembered,
--- and set at once on QUEST_TURNED_IN. In combat nothing new is asked of the client: only an answer
--- already held counts. false where Keep or the client will not say. Guarded.
function Tree.QuestDone(questId)
  questId = tonumber(questId)
  if not questId or questId <= 0 then
    return false
  end
  if Tree.questsDone[questId] then
    return true
  end
  local keep = ItemTree.Keep
  if type(keep) ~= "table" or type(keep.QuestCompleted) ~= "function" then
    return false
  end
  local inCombat = rawget(_G, "InCombatLockdown")
  if type(inCombat) == "function" then
    local ok, fighting = pcall(inCombat)
    if ok and fighting then
      return type(keep.completed) == "table" and keep.completed[questId] == true
    end
  end
  local ok, done = pcall(keep.QuestCompleted, questId)
  return ok and done == true
end

-- Brief BQ15: the check a completed quest's row wears before its name, as inline art (the client's
-- own green tick on transparency, Assets ICON_CHECK, so no square backing shows behind it), and the
-- pale green square behind its icon. Before the name so the client's ellipsis never cuts it off.
local function markQuestDone(layout, node)
  if type(node) ~= "table" or node.kind ~= "quest" or not Tree.QuestDone(node.id) then
    return
  end
  layout.questDone = true
  layout.iconBorderColor = Tree.QUEST_DONE_COLOR
  local size = math.max(1, math.floor((tonumber(layout.fontSize) or Tree.MARK) + 0.5))
  local mark = Assets.Has("ICON_CHECK") and Assets.Markup("ICON_CHECK", size) or nil
  if mark then
    layout.richText = mark .. " " .. (layout.richText or layout.text or "")
  end
end

Tree.QUEST_DONE_COLOR = "ITEMTREE_COLOR_QUEST_DONE"

-- Brief BQ15: the quests turned in this session, by id, held here as well as in Keep's memory,
-- because the client's flag can lag the event and the two event frames run in either order.
Tree.questsDone = {}

--- Brief BQ15: QUEST_TURNED_IN. The quest is done at once, and an open pane redraws so its row
--- gains the check. Answers whether the pane redrew.
function Tree.OnQuestTurnedIn(questId)
  questId = tonumber(questId)
  if not questId or questId <= 0 then
    return false
  end
  Tree.questsDone[questId] = true
  if not Tree.shown then
    return false
  end
  local ok, drew = pcall(Tree.Refresh)
  return ok and drew == true
end

--- Whether any row on screen is a Classic Era row, which is what the banner at the top of the
--- pane is drawn for. Pure.
function Tree.HasEraRows(rows)
  for _, row in ipairs(type(rows) == "table" and rows or EMPTY) do
    local source = type(row.source) == "table" and row.source or nil
    if source and source.historical == true then
      return true
    end
    -- E75: a Classic Era summary drawn as its "Show N more" row carries no source of its own, and
    -- only the Classic Era table ever writes one, so it is a Classic Era row on screen all the same.
    -- Brief GS3: a guess that names no source is a summary too, and is no Classic Era row.
    if Tree.IsSummary(row) and not (source and source.guess == true) then
      return true
    end
  end
  return false
end

-- Brief E102: the banner is switched off. Owner 2026-09-29: "I want to hide the very top one (just
-- disable for now in case we want to add back in)". The group notices under the list say the same
-- thing where it is relevant, and the banner coming and going made the list shift under the
-- pointer. With this false the tree pane never puts the banner up (updateBanner below), so the list
-- starts at its first group. Setting it true brings the banner back unchanged. Tree.EraBanner itself
-- still answers as before, because the Boss loot tab draws its own line from it.
Tree.SHOW_TOP_ERA_NOTICE = false

--- The quiet banner at the top of the tree pane, or nil when there is none to draw.
---
--- One line, in the muted face with a small info mark, whenever a Classic Era row is on screen:
--- the rows themselves say "Predicted" and "Classic Era" in their own columns, and this says
--- once, up front, what that means for the list under it. It is not a row of the view. Nothing
--- counts it, the keyboard cursor never lands on it and the filter never keeps it, and typing
--- in the search box takes it away with everything else it is standing over.
---
--- rows are the rows the pane is about to draw, filter is what the search box holds. Answers
--- { text, lines }, where lines are the tooltip's, in order. Pure.
function Tree.EraBanner(rows, filter)
  if type(filter) == "string" and filter:match("%S") then
    return nil
  end
  if not Tree.HasEraRows(rows) then
    return nil
  end
  return {
    text = L["Some of these sources are from Classic Era and may have changed."],
    lines = {
      L["WoW Forever keeps loot details on the server until players find them, so nobody has real drop data yet."],
      L["Rows marked Predicted come from Classic Era, and their drop chances were measured there."],
      L["Use them as a guide."],
    },
  }
end

-- The page a community source stands for, by host and date: "example.org 2026-09-26". Pure.
local function communityPage(source)
  if type(source) ~= "table" or type(source.url) ~= "string" or source.url == "" then
    return nil
  end
  local host = source.url:match("^%a+://([^/]+)") or source.url
  host = host:gsub("^www%.", "")
  if type(source.date) == "string" and source.date ~= "" then
    host = host .. " " .. source.date
  end
  return host
end

-- A note fragment as a sentence: its first letter capitalised and a full stop on the end where it
-- has no closing mark of its own. Pure.
local function asSentence(text)
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then
    return nil
  end
  text = text:sub(1, 1):upper() .. text:sub(2)
  if not text:find("[%.!?]$") then
    text = text .. "."
  end
  return text
end

--- Brief E93: what a row's Community note mark says under its heading when hovered, in place of
--- the generic meaning: the note's own sentence where the shipped row carries one (a Waylaid
--- Crate's "From ordinary creatures from level 10, ..."), then the pages it rests on, "From
--- example.org 2026-09-26 and example.net 2026-09-23", as the last line. A vendor offer's note
--- is only the vendor's side ("Alliance"), which the row already says, so it is not repeated as a
--- sentence. nil for a row with no community note, which keeps the meaning. Pure.
function Tree.BadgeNote(row)
  local edge = type(row) == "table" and row.edge or nil
  if type(edge) ~= "table" then
    return nil
  end
  local community = type(edge.community) == "table" and edge.community or nil
  if not community then
    return nil
  end
  local lines = {}
  local note = edge.note
  if type(note) == "string" and note ~= "" then
    local faction = community.faction
    local side = type(faction) == "string" and (note == faction or note == L[faction])
    if not side then
      lines[#lines + 1] = asSentence(note)
    end
  end
  local pages = {}
  for _, source in ipairs(type(community.sources) == "table" and community.sources or EMPTY) do
    pages[#pages + 1] = communityPage(source)
  end
  if #pages > 0 then
    local last = table.remove(pages)
    local joined = last
    if #pages > 0 then
      joined = string.format(L["%s and %s"], table.concat(pages, ", "), last)
    end
    lines[#lines + 1] = string.format(L["From %s"], joined)
  end
  if #lines == 0 then
    return nil
  end
  return lines
end

--- The type column's own text: the type, with the provenance behind it where the column can
--- hold both ("Drop via All The Things"). The column is the dim meta face, so the suffix is
--- already dimmer than the name beside it.
---
--- Room is estimated the way the count column's is, off the character count and the font size,
--- because a row is laid out for every row in the list and the client is only asked to measure
--- once per draw. The row tooltip says the same words whatever this answers, so a column with
--- no room loses the suffix and never the type. Pure.
function Tree.SourceTypeLine(typeText, provenance, width, fontSize)
  typeText = type(typeText) == "string" and typeText or ""
  if type(provenance) ~= "string" or provenance == "" then
    return typeText
  end
  local combined = typeText == "" and provenance or (typeText .. " " .. provenance)
  local size = tonumber(fontSize) or Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_SM
  local room = tonumber(width) or 0
  if math.ceil(#combined * size * Tree.COUNT_CHAR) > room then
    return typeText
  end
  return combined
end

--- The diff kind and id a row's badge cluster shows the old to new lines for, or nil twice for
--- a node Core keeps no changes against. The cluster is told on every draw, so a pooled frame
--- reused for a requirement row is cleared rather than left pointing at the item before it.
function Tree.DiffSubject(node)
  if type(node) ~= "table" then
    return nil, nil
  end
  local kind = DIFF_KINDS[node.kind]
  local id = tonumber(node.id)
  if not kind or not id then
    return nil, nil
  end
  return kind, id
end

--- What the corner glyph on a row means, in words, or nil for a row that draws none. The
--- profession comes from Core where this build knows one, so a recipe reads as "Recipe
--- (Blacksmithing)" and an enchant simply as "Enchant".
function Tree.MarkLabel(row)
  local node = type(row) == "table" and row.node or nil
  if type(node) ~= "table" or not MARK_KINDS[node.kind] then
    return nil
  end
  -- Brief P5b: a class spell is no recipe, and its line says whose spell it is.
  local classText = Tree.ClassSpellText(row)
  if classText then
    return classText
  end
  -- Brief CT1: nor is a class trainer's spell: "Hunter spell".
  local trainerText = Tree.TrainerSpellText(row)
  if trainerText then
    return trainerText
  end
  if node.kind == "enchant" then
    return L["Enchant"]
  end
  local Graph = ItemTree.Graph
  if type(Graph) == "table" and type(Graph.SpellInfo) == "function" then
    local ok, info = pcall(Graph.SpellInfo, tonumber(node.id))
    if ok and type(info) == "table" then
      -- An item combine is a spell with no profession at all, and calling it a recipe says the
      -- one thing about it that is not true.
      if info.combine then
        return L["Combine"]
      end
      if type(info.skillName) == "string" and info.skillName ~= "" then
        return string.format(L["Recipe (%s)"], info.skillName)
      end
    end
  end
  return L["Recipe"]
end

--- Brief EK1: whether a row names a Classic Era creature or vendor that has no page (the table
--- states no creature id for its name, Core/EraSources.lua CreatureNode): its edge carries noPage,
--- and the row is drawn and opens nothing. Pure.
function Tree.NoPage(row)
  local edge = type(row) == "table" and row.edge or nil
  return type(edge) == "table" and edge.noPage == true
end

--- Brief P5b: what a "Reagent for" row that names a class spell stands for, as { spellId, classId,
--- name, token, spellName }, or nil for every other row. name and token are nil at classId 0, a
--- spell several classes share. Read off the row's own edge (Core/Graph.lua REAGENT_FOR_SPELL), so
--- nothing is looked up but the class words. Pure.
function Tree.ClassSpell(row)
  local edge = type(row) == "table" and row.edge or nil
  local def = type(edge) == "table" and edge.type or nil
  if type(def) ~= "table" or def.name ~= "REAGENT_FOR_SPELL" then
    return nil
  end
  local node = type(row.node) == "table" and row.node or EMPTY
  local classId = tonumber(edge.classId) or 0
  local out = { spellId = tonumber(node.id), classId = classId, spellName = node.name }
  local Graph = ItemTree.Graph
  if type(Graph) == "table" and type(Graph.ClassInfo) == "function" then
    local ok, info = pcall(Graph.ClassInfo, classId)
    if ok and type(info) == "table" then
      out.name = info.name
      out.token = info.token
    end
  end
  return out
end

--- Brief CT1: what a class trainer's spell row stands for (Core/EraSources.lua E:ClassTeachesEdges),
--- as { spellId, classId, level, rank, cost }, or nil for every other row. Read off the row's own
--- edge, so nothing is looked up. Pure.
function Tree.TrainerSpell(row)
  local edge = type(row) == "table" and row.edge or nil
  local def = type(edge) == "table" and edge.type or nil
  local facts = type(edge) == "table" and edge.classSpell or nil
  if type(def) ~= "table" or def.name ~= "TRAINER_TEACHES" or type(facts) ~= "table" then
    return nil
  end
  local node = type(row.node) == "table" and row.node or EMPTY
  local spellId = tonumber(node.id)
  if not spellId then
    return nil
  end
  return {
    spellId = spellId,
    classId = tonumber(facts.classId),
    level = tonumber(facts.level),
    rank = tonumber(facts.rank) or 0,
    cost = tonumber(facts.cost) or 0,
    -- Brief TW3: a pet trainer's ability (Core/EraSources.lua E:_ForeverClassEdges).
    pet = facts.pet == true or nil,
  }
end

--- Brief CT1: what the corner mark of a class trainer's spell row says, "Hunter spell", or nil for
--- every other row ("Class spell" where the class is not one Graph.ClassInfo names). Pure.
function Tree.TrainerSpellText(row)
  local spell = Tree.TrainerSpell(row)
  if not spell then
    return nil
  end
  -- Brief TW3: a pet trainer's row teaches the pet, not the character.
  if spell.pet then
    return L["Pet ability"]
  end
  local Graph = ItemTree.Graph
  if type(Graph) == "table" and type(Graph.ClassInfo) == "function" then
    local ok, info = pcall(Graph.ClassInfo, spell.classId)
    if ok and type(info) == "table" and type(info.name) == "string" then
      return string.format(L["%s spell"], info.name)
    end
  end
  return L["Class spell"]
end

--- Brief CT1: the second column of a class trainer's spell row the character has learnt: "Learnt
--- (Rank 3)", or "Learnt" for a spell of no rank. The price is no longer the player's question.
--- Brief LF1 (QA item 241, the owner: "Text for these shuld be Learnt (Rank 1) not your comma
--- version"): the rank in brackets, where CT1 wrote "Learnt, Rank 3". Pure.
function Tree.LearntMeta(spell)
  local rank = type(spell) == "table" and tonumber(spell.rank) or 0
  if rank and rank > 0 then
    return string.format(L["%s (%s)"], L["Learnt"], string.format(L["Rank %d"], rank))
  end
  return L["Learnt"]
end

--- Brief PL1 (QA item 288, the owner on round AF's AF7: "Why are none learnt for my hunter? If I'm a
--- hunter it should look at my hunters ranks if possible"): what the hunter's pets know, out of the
--- client's own pet lists, as { ids = { [spellId] = true }, top = { [name] = rank } }. pets is the
--- lists' entries (C_StableInfo's PetInfo, whose petAbilities is the spell ids the pet knows), ranks
--- { [spellId] = rank } the pet trainers' list's ranks, and nameOf(spellId) a spell's name or nil:
--- ids holds every ability any pet knows, top the highest rank of each ability the list ranks, by
--- its name. canRead (Util.CanRead, bible B10) is asked of every value before anything else reads
--- it, and a value it refuses is skipped. Pure.
function Tree.PetAbilitiesKnown(pets, ranks, nameOf, canRead)
  local known = { ids = {}, top = {} }
  local function readable(value)
    return type(canRead) ~= "function" or canRead(value) == true
  end
  if not readable(pets) or type(pets) ~= "table" then
    return known
  end
  for _, pet in ipairs(pets) do
    local abilities = nil
    if readable(pet) and type(pet) == "table" then
      abilities = pet.petAbilities
    end
    if readable(abilities) and type(abilities) == "table" then
      for _, spellId in ipairs(abilities) do
        if readable(spellId) and type(spellId) == "number" then
          known.ids[spellId] = true
        end
      end
    end
  end
  if type(ranks) ~= "table" or type(nameOf) ~= "function" then
    return known
  end
  for spellId in pairs(known.ids) do
    local rank = tonumber(ranks[spellId]) or 0
    if rank > 0 then
      local name = nameOf(spellId)
      if readable(name) and type(name) == "string" and name ~= "" and rank > (known.top[name] or 0) then
        known.top[name] = rank
      end
    end
  end
  return known
end

--- Brief PL1: whether the hunter's pets know a pet trainer's row (spell, Tree.TrainerSpell's
--- answer): its very rank (known.ids), or a higher rank of the same ability (known.top, by the
--- row's spell name, which nameOf answers and is asked only then). A pet that holds only the
--- highest rank it has learnt has learnt the lower ones too, so a pet with Growl rank 4 has learnt
--- rank 3. known is Tree.PetAbilitiesKnown's answer. Pure.
function Tree.PetRowKnown(known, spell, nameOf)
  if type(known) ~= "table" or type(spell) ~= "table" then
    return false
  end
  local spellId = tonumber(spell.spellId)
  if not spellId then
    return false
  end
  if type(known.ids) == "table" and known.ids[spellId] == true then
    return true
  end
  local rank = tonumber(spell.rank) or 0
  if rank <= 0 or type(known.top) ~= "table" or next(known.top) == nil or type(nameOf) ~= "function" then
    return false
  end
  local name = nameOf(spellId)
  local top = type(name) == "string" and known.top[name] or nil
  return type(top) == "number" and top >= rank
end

--- Brief P5b: "Reagent for the Shaman spell Water Breathing", the sentence a class spell row's
--- tooltip says, or nil for any other row. A spell several classes share drops the class word. Pure.
function Tree.ClassSpellText(row)
  local spell = Tree.ClassSpell(row)
  if not spell then
    return nil
  end
  local name = type(spell.spellName) == "string" and spell.spellName or ""
  if spell.name then
    return string.format(L["Reagent for the %s spell %s"], spell.name, name)
  end
  return string.format(L["Reagent for the spell %s"], name)
end

--- What an enchanting recipe's enchant does, in the enchant's own words ("Stamina +2"), or nil
--- for every node that is not such a recipe. A node that carries Graph.SpellInfo's shape reads
--- info.enchant; any other spell node looks its recipe record up by id, which is the one lookup
--- the row's own ENCHANTS edge already paid for (recipe.en, then the Enchants module's n).
---
--- A name that is only Graph.Fallback's "Enchant 1234" is no effect, and neither is one that
--- repeats the recipe's own name or the words after its dash, so none of those gives a suffix.
--- Guarded throughout: a half loaded addon costs the suffix and nothing else. Pure.
function Tree.EnchantEffect(node)
  if type(node) ~= "table" or node.kind ~= "spell" then
    return nil
  end
  local enchantId, name
  local info = type(node.info) == "table" and node.info or nil
  if info and type(info.enchant) == "table" then
    enchantId, name = info.enchant.id, info.enchant.name
  else
    local data = ItemTree.Data
    local id = tonumber(node.id)
    if not id or type(data) ~= "table" or type(data.GetRecipe) ~= "function" then
      return nil
    end
    local ok, recipe = pcall(data.GetRecipe, data, id)
    if not ok or type(recipe) ~= "table" or recipe.en == nil or type(data.GetEnchant) ~= "function" then
      return nil
    end
    local found, enchant = pcall(data.GetEnchant, data, recipe.en)
    enchantId = recipe.en
    name = found and type(enchant) == "table" and enchant.n or nil
  end
  if type(name) ~= "string" or name == "" then
    return nil
  end
  -- 21 of the 182 enchanting recipes name their enchant exactly as the part after the dash
  -- ("Enchant Weapon - Fiery Weapon"), and "(Fiery Weapon)" after that would say nothing new.
  if type(node.name) == "string" then
    local own = node.name:lower()
    local tail = own:match(" %- (.+)$")
    if name:lower() == own or name:lower() == tail then
      return nil
    end
  end
  local graph = ItemTree.Graph
  if enchantId ~= nil and type(graph) == "table" and type(graph.Fallback) == "function" then
    local ok, fallback = pcall(graph.Fallback, "enchant", enchantId)
    if ok and fallback == name then
      return nil
    end
  end
  return name
end

--- The words a tree row draws for its node, as two strings: the plain text, which the tooltip,
--- the filter box and the tests read, and the same text as the name column draws it. They differ
--- only on an enchanting recipe (brief E81), which reads "Enchant Gloves - Shadow Power (Shadow
--- Damage +20)" with the bracketed effect in the muted text colour, so a player can tell what an
--- enchant does without opening the row. Every tree row of a node goes through here, in every
--- view, so every view says the same thing; search results, the item tooltip, the info panel's
--- title and the sidebar keep the spell's own name and never call it. Pure.
function Tree.RowText(node, row)
  local name = type(node) == "table" and node.name or nil
  if type(name) ~= "string" then
    name = type(row) == "table" and (row.text or row.key) or nil
  end
  if type(name) ~= "string" then
    name = ""
  end
  local effect = Tree.EnchantEffect(node)
  if not effect or name == "" then
    return name, name
  end
  local suffix = "(" .. effect .. ")"
  return name .. " " .. suffix, name .. " " .. Theme.Colorise("ITEMTREE_COLOR_TEXT_MUTED", suffix)
end

--- The corner mark an item row wears about how much ItemTree can tell the player: nothing,
--- "undiscovered" or "discovered", with the Assets key it is drawn with. The rule is Core's
--- (Core/Graph.lua Graph.DiscoveryMark), so this row, the Discoveries row, the info column's
--- header and a chain stage all read the same answer. Guarded rather than called outright: a
--- half loaded addon costs the mark and nothing else. Pure.
function Tree.DiscoveryMark(node)
  local graph = ItemTree.Graph
  if type(graph) ~= "table" or type(graph.DiscoveryMark) ~= "function" then
    return nil
  end
  local ok, mark, art = pcall(graph.DiscoveryMark, node)
  if not ok or type(mark) ~= "string" then
    return nil
  end
  if type(art) ~= "string" or not Assets.Has(art) then
    return mark, nil
  end
  return mark, art
end

--- What that mark says in words, or nothing for a mark with nothing to add. Core owns the
--- wording for the same reason it owns the rule. Pure.
function Tree.DiscoveryMarkLabel(mark)
  local graph = ItemTree.Graph
  if type(graph) ~= "table" or type(graph.DiscoveryMarkText) ~= "function" then
    return nil
  end
  local ok, text = pcall(graph.DiscoveryMarkText, mark)
  if not ok or type(text) ~= "string" or text == "" then
    return nil
  end
  return text
end

--- The corner glyph a merged craft row wears when a recipe item teaches the craft, or nil on a
--- build whose Assets table does not carry it. A trainer taught craft never draws one: that is
--- the ordinary case, and a mark on every row says nothing. Pure.
function Tree.RecipeMark()
  if Assets.Has(Tree.RECIPE_MARK_KEY) then
    return Tree.RECIPE_MARK_KEY
  end
  return nil
end

--- What the corner of a merged craft row's icon says about how many the craft makes: nothing at
--- all for a craft that makes one, the number where the build states one, and "1-2" for a range.
---
--- The client's own wording, from Blizzard_TradeSkillUI (Vanilla), which writes the count on the
--- trade skill icon only above one, joins a range with a hyphen and falls back to the average
--- behind a "~" when that string is wider than the icon. width is the icon box and fontSize the
--- size the number is drawn at, estimated the way the count column's is; a caller that states
--- neither keeps the range. Pure.
function Tree.YieldText(craft, width, fontSize)
  craft = type(craft) == "table" and craft or EMPTY
  local low = tonumber(craft.yield)
  local high = tonumber(craft.yieldMax) or low
  if not high or high <= 1 then
    return ""
  end
  low = low or high
  if low >= high then
    return tostring(high)
  end
  local text = tostring(low) .. "-" .. tostring(high)
  local room = tonumber(width) or 0
  local size = tonumber(fontSize) or Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_SM
  if room > 0 and math.ceil(#text * size * Tree.COUNT_CHAR) > room then
    return "~" .. tostring(math.floor((low + high) / 2))
  end
  return text
end

--- Brief TC1: what a multiplied count is made of, for the row's tooltip: "12 in all: 1 per craft,
--- 12 crafts". Only on a row Core multiplied (Total counts on, and a total that differs from the
--- count for one craft), so nil everywhere else and always with the setting off. Plain digits,
--- the way the quantity column writes them. Pure.
function Tree.TotalLabel(row)
  local node = type(row) == "table" and row.node or nil
  if type(node) ~= "table" then
    return nil
  end
  local total, perCraft, crafts = tonumber(node.quantity), tonumber(node.perCraft), tonumber(node.crafts)
  if not (total and perCraft and crafts) or total == perCraft then
    return nil
  end
  return string.format(L["%s in all: %s per craft, %s crafts"], tostring(total), tostring(perCraft), tostring(crafts))
end

--- The same fact in words for the row's tooltip, or nil where the craft makes one. Prose rather
--- than the corner's shorthand, so a range reads the way every other range in the window does.
--- Pure.
function Tree.YieldLabel(craft)
  craft = type(craft) == "table" and craft or EMPTY
  local low = tonumber(craft.yield)
  local high = tonumber(craft.yieldMax) or low
  if not high or high <= 1 then
    return nil
  end
  low = low or high
  if low >= high then
    return string.format(L["Makes %s"], tostring(high))
  end
  return string.format(L["Makes %s"], string.format(L["%s to %s"], tostring(low), tostring(high)))
end

--- One line per recipe item that teaches a merged row's craft, which is what the corner mark
--- means in words. A build can teach one craft from two items of the same name, and two
--- identical lines say nothing twice, so a name is drawn once. Empty for a trainer taught
--- craft and for a row that is not merged. Pure.
function Tree.RecipeLabels(craft)
  craft = type(craft) == "table" and craft or EMPTY
  local out, seen = {}, {}
  local recipes = type(craft.recipes) == "table" and craft.recipes or nil
  if not recipes and type(craft.recipeName) == "string" then
    recipes = { { name = craft.recipeName } }
  end
  for _, recipe in ipairs(recipes or EMPTY) do
    local name = type(recipe) == "table" and recipe.name or nil
    if type(name) == "string" and name ~= "" and not seen[name] then
      seen[name] = true
      out[#out + 1] = string.format(L["Taught by %s"], name)
    end
  end
  return out
end

-- Which of the three things a change row says. Core hangs an op of "added", "removed" or
-- "changed" on a line it split out of a list field, with the side that does not exist left
-- nil; a line from before that carries no op at all, so the side it does carry answers for it.
-- UI/Badges.lua works the same answer out for a tooltip line and is asked first, so the two can
-- never drift; the rest is what a build where it cannot be asked gets.
local function changeOp(change)
  if type(Badges) == "table" and type(Badges.ChangeOp) == "function" then
    local ok, op = pcall(Badges.ChangeOp, change)
    if ok and (op == "added" or op == "removed" or op == "changed") then
      return op
    end
  end
  local op = change.op
  if op == "added" or op == "removed" or op == "changed" then
    return op
  end
  local hasOld = type(change.oldText) == "string" and change.oldText ~= ""
  local hasNew = type(change.newText) == "string" and change.newText ~= ""
  if hasOld and not hasNew then
    return "removed"
  end
  if hasNew and not hasOld then
    return "added"
  end
  return "changed"
end

--- One change row as the words it draws: the plain line, and the same line with the client's
--- colour escapes in it.
--
-- A value that moved reads "Cooldown none to 24h". Font strings have no strike through, so the
-- old value leads in disabled grey and the new one follows in body cream
-- (docs/design-deviations.md).
--
-- An entry out of a list field came or went rather than moved, and Core says which on the line
-- itself, so it names only the side that exists and ends with the word for what happened:
-- "Effects +14 Shadow spell damage added", "Reagents Linen Cloth removed". Written as the
-- whole sentence out of the locale, because where the word sits in it is the locale's to say.
--
-- A change carrying neither side falls back to whatever text Core wrote on it. Pure.
function Tree.ChangeText(change)
  change = type(change) == "table" and change or EMPTY
  local label = change.label or change.field or L["Changed"]
  local op = changeOp(change)
  local old = type(change.oldText) == "string" and change.oldText or ""
  local new = type(change.newText) == "string" and change.newText or ""
  local showOld = op ~= "added" and old ~= ""
  local showNew = op ~= "removed" and new ~= ""
  local plain, rich
  if showOld and showNew then
    plain = string.format(L["%s to %s"], old, new)
    rich = string.format(
      L["%s to %s"],
      Theme.Colorise("ITEMTREE_COLOR_TEXT_DISABLED", old),
      Theme.Colorise("ITEMTREE_COLOR_TEXT_BODY", new)
    )
  elseif showNew then
    plain, rich = new, Theme.Colorise("ITEMTREE_COLOR_TEXT_BODY", new)
    if op == "added" then
      plain = string.format(L["%s added"], plain)
      rich = string.format(L["%s added"], rich)
    end
  elseif showOld then
    plain, rich = old, Theme.Colorise("ITEMTREE_COLOR_TEXT_DISABLED", old)
    if op == "removed" then
      plain = string.format(L["%s removed"], plain)
      rich = string.format(L["%s removed"], rich)
    end
  else
    plain = type(change.text) == "string" and change.text or ""
    rich = plain
  end
  if plain == "" then
    return label, label
  end
  return label .. " " .. plain, label .. " " .. rich
end

local function chevronState(row)
  if row.loop then
    return "loop", nil
  end
  if not row.hasChildren then
    return "none", nil
  end
  if row.expanded then
    return "expanded", "ICON_CHEVRON_COLLAPSE"
  end
  return "collapsed", "ICON_CHEVRON_EXPAND"
end

local function addLeft(layout, cursor, name, width)
  layout.columns[name] = { width = width, x = cursor, align = "left" }
  layout.order[#layout.order + 1] = name
  return cursor + width + layout.gutter
end

-- cursor is the distance from the row's right edge. pad is extra air on both sides of the
-- column, which is what a badge cluster asks for: its medallion art stands proud of the box
-- the cluster measures itself as, and neither the words beside it nor the row's edge may be
-- drawn under that art.
local function addRight(layout, cursor, name, width, align, pad)
  pad = pad or 0
  layout.columns[name] = { width = width, right = cursor + pad, align = align or "right" }
  layout.order[#layout.order + 1] = name
  return cursor + pad + width + pad + layout.gutter
end

--- How far a badge's medallion stands proud of the cluster box on each side. UI/Badges.lua
--- draws a supplied medallion one step up the badge size ladder (12 as 14, 16 as 18), because
--- the medallion carries its own ring where a composed badge draws its glyph inside one. Pure,
--- and guarded, so a build whose Badges cannot be asked reads as no overhang at all.
function Tree.BadgeOverhang(size)
  size = tonumber(size) or Tree.BADGE_TREE
  local art = size
  if type(Badges) == "table" and type(Badges.ArtSize) == "function" then
    local ok, value = pcall(Badges.ArtSize, size)
    if ok and tonumber(value) then
      art = tonumber(value)
    end
  end
  return math.max(0, math.ceil((art - size) / 2))
end

--- The room a cluster of this many badges of this size really takes, medallion art and all.
--- Pure. Nothing to draw is no room at all.
function Tree.BadgeColumn(count, size)
  count = tonumber(count) or 0
  size = tonumber(size) or Tree.BADGE_LIST
  if count <= 0 or size <= 0 then
    return 0
  end
  local gap = 0
  if type(Badges) == "table" and type(Badges.GapFor) == "function" then
    local ok, value = pcall(Badges.GapFor, size)
    if ok and tonumber(value) then
      gap = tonumber(value)
    end
  end
  return count * size + (count - 1) * gap + 2 * Tree.BadgeOverhang(size)
end

--- The icon box a row this tall has room for. The design's 20px glyph wears a 1px gold edge,
--- so a compact 18px row gives the glyph back the two pixels that edge needs rather than
--- letting it, and the corner glyph on it, reach into the row above and below. Pure.
function Tree.IconSize(rowHeight, wanted)
  wanted = tonumber(wanted) or Tree.ICON
  local room = (tonumber(rowHeight) or 0) - 2 * Tree.BORDER
  if room <= 0 then
    return wanted
  end
  return math.min(wanted, room)
end

--- The corner glyph an icon this size wears: never more than half of it, and never more than
--- the badge token, so the glyph plus its backing always sit inside the icon box. Pure.
function Tree.MarkSize(iconSize)
  local size = tonumber(iconSize) or Tree.ICON
  return math.max(1, math.min(Tree.MARK, math.floor(size / 2)))
end

--- The longest count a category header in these rows draws, as the string it draws. "" when
--- the list has no category headers. Pure.
function Tree.WidestCount(rows)
  local widest = ""
  for _, row in ipairs(rows or EMPTY) do
    if type(row) == "table" and row.kind == "category" then
      local text = countTextOf(row)
      if #text > #widest then
        widest = text
      end
    end
  end
  return widest
end

--- The room the count column needs for that string. measured is what the client made of it in
--- pixels, or nil where it could not be asked, and the character estimate is the floor either
--- way. Never wider than the design's own count column, and never narrower than one
--- character, so an empty list still lays a header out. Pure.
function Tree.CountWidth(text, fontSize, measured)
  local size = tonumber(fontSize) or Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_SM
  local one = math.ceil(size * Tree.COUNT_CHAR)
  local chars = type(text) == "string" and #text or 0
  local width = math.max(math.ceil(chars * size * Tree.COUNT_CHAR), tonumber(measured) or 0)
  return math.max(one, math.min(Tree.COUNT, width))
end

--- How far in from the pane's right edge the rows stop. A list that overflows stops at the
--- scroll bar, and one that fits runs to the panel's inner edge, so a row's divider, its
--- category band and its hover wash fill the panel rather than stopping at a gutter that is
--- not there. Pure.
function Tree.ListRightInset(overflows)
  if overflows then
    return Tree.BORDER + Tree.SCROLLBAR + Tree.PAD
  end
  return Tree.BORDER
end

--- The pixels a search box's frame is pushed in by so the edges it draws line up with the list
--- panel under it. templated says whether the client's own SearchBoxTemplate art is on it.
--- Pure.
function Tree.SearchInsets(templated)
  if not templated then
    return 0, 0
  end
  return Tree.SEARCH_ART_LEFT, Tree.SEARCH_ART_RIGHT
end

-- Where a source row's name starts at depth 0: past the pad, the chevron and the icon. The
-- column set is measured from here and not from the row's own indent, so every source row of a
-- draw keeps the same columns whatever depth it sits at and a category lines up down its whole
-- length. A row deep enough to be squeezed gives up its name width, never its columns.
local SOURCE_NAME_LEFT = Tree.PAD + Tree.CHEVRON + Tree.GUTTER + Tree.ICON + Tree.GUTTER

--- Which source columns fit beside a name column that still reads, at a stated row width. The
--- width is the pane's own less the scrollbar gutter; a caller that states none is not laying
--- out for a real pane and keeps all three. Pure.
function Tree.SourceColumns(width)
  local kept = { sourceRate = true, sourceZone = true, sourceType = true }
  width = tonumber(width) or 0
  if width <= 0 then
    return kept
  end
  local function room()
    local pad = Tree.BadgeOverhang(Tree.BADGE_TREE)
    local right = Tree.GUTTER + pad + Tree.BADGES + pad + Tree.GUTTER
    for _, name in ipairs(SOURCE_ORDER) do
      if kept[name] then
        right = right + SOURCE_W[name] + Tree.GUTTER
      end
    end
    return width - SOURCE_NAME_LEFT - right
  end
  for _, name in ipairs(SOURCE_DROP) do
    if room() >= Tree.MIN_NAME_W then
      return kept
    end
    kept[name] = nil
  end
  return kept
end

-- The count column this draw was measured for, or the design's own column where nothing
-- measured it, which is what a caller laying a row out with no pane in front of it gets.
local function countColumn(opts, fontSize)
  local width = tonumber(opts.countWidth)
  if not width then
    return Tree.COUNT
  end
  return Tree.CountWidth(nil, fontSize, width)
end

-- The name column fills what the fixed columns leave. Its width is only known when the
-- caller says how wide the row is; without that it carries both edges and the frame fills.
-- floor is the least the column is given, Tree.MIN_NAME_W unless the row says otherwise (brief
-- FX-AG2: a bundle price that took its room out of the name column lowers it by that much).
local function fillName(layout, left, right, opts, align, floor)
  local column = { x = left, right = right, fill = true, align = align or "left" }
  if opts.width then
    column.width = math.max(floor or Tree.MIN_NAME_W, opts.width - left - right)
  end
  layout.columns.name = column
  layout.order[#layout.order + 1] = "name"
  return column
end

--- One row's geometry, colours, text and badges.
--
-- row is a row from vm:Rows(), density is "default" or "compact", opts may carry:
--   width   the row's width in pixels, which is the pane width less layout.scrollbar
--   height  the pane height, used by the empty state, which is a block and not a row
--   sticky  true when the row is being drawn as the pinned category header
--
-- The returned table names every column the kind draws in layout.columns, keyed by name,
-- with a width plus either x (from the row's left edge) or right (from its right edge). The
-- name column carries both and fills between them. layout.order is the same names in draw
-- order. Nothing here touches a frame, so every row kind is specced with no client present.
function Tree.Layout(row, density, opts)
  row = type(row) == "table" and row or EMPTY
  opts = type(opts) == "table" and opts or EMPTY
  density = density == "compact" and "compact" or "default"

  local kind = row.kind or "row"
  local depth = tonumber(row.depth) or 0
  -- Every indent on this row is measured from where the row is DRAWN (Tree.DrawDepth), which
  -- is its own depth.
  local drawDepth = Tree.DrawDepth(row)
  local node = type(row.node) == "table" and row.node or nil
  local rowHeight = Theme.RowHeight(density)
  local small = Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_SM
  local body = density == "compact" and small or Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_MD

  local layout = {
    kind = kind,
    key = row.key,
    depth = depth,
    density = density,
    height = rowHeight,
    indent = Theme.Indent(drawDepth),
    pad = Tree.PAD,
    gutter = Tree.GUTTER,
    scrollbar = Tree.SCROLLBAR,
    columns = {},
    order = {},
    alpha = 1,
    nameAlpha = 1,
    badges = EMPTY,
    badgeSize = Tree.BADGE_TREE,
    badgeMax = Tree.BADGE_MAX_ROW,
    chevron = "none",
    fontSize = body,
    metaFontSize = small,
    nameColor = "ITEMTREE_COLOR_TEXT_BODY",
    metaColor = "ITEMTREE_COLOR_TEXT_MUTED",
    text = "",
  }

  if kind == "category" then
    layout.height = SIZES.ITEMTREE_LIST_CATEGORY_H
    layout.badgeSize = Tree.BADGE_LIST
    layout.badgeMax = Tree.BADGE_MAX_CATEGORY
    layout.badges = Badges.Sort(node and node.badges, Tree.BADGE_MAX_CATEGORY)
    -- E48: a header's own marks are hover targets too, so a Predicted orb on "Gathered in" says
    -- which kind of prediction it stands for rather than falling back to the disenchant wording.
    layout.badgeBasis = Tree.BadgeBasis(row)
    layout.chevron, layout.chevronAsset = chevronState(row)
    layout.iconAsset = categoryIcon(row, node)
    layout.iconSize = Tree.CATEGORY_ICON
    layout.text = (node and node.name) or row.text or ""
    layout.countText = countTextOf(row)
    -- A section header, not a row: the divider hairline along the top, the same one along the
    -- bottom, and the sticky surface tint across the whole width in between. The pinned header
    -- is the same row drawn again, so it takes the same treatment rather than one of its own.
    layout.topBorder = true
    layout.divider = true
    layout.borderColor = Tree.BORDER_COLOR
    layout.dividerColor = Tree.BORDER_COLOR
    layout.band = true
    layout.bandColor = Tree.CATEGORY_BAND
    layout.background = Tree.CATEGORY_BAND
    layout.backgroundAlpha = 1
    layout.sticky = opts.sticky and true or false
    -- A profession says where the player stands. Skills writes the line, so "Blacksmithing"
    -- becomes "Blacksmithing 265/300" without this file knowing how that reads. An expanded
    -- header with a specialisation gets the "Your skill" row under it from Tree.SkillRows, so
    -- it takes the rank line and lets that row say the specialisation once.
    local header = Tree.CategoryHeader(row)
    if header then
      layout.text = (row.expanded and header.specialisation) and header.rankLine or header.line
      layout.rank, layout.max = header.rank, header.max
      layout.specialisation = header.specialisation
    end
    -- Brief BQ14 (QA item 14): a Used by profession header's rarity circles after its words, one
    -- per quality its recipes make (ViewModel.MarkQualities), drawn as the tooltip draws them.
    local dots = Tree.QualityDots(row)
    if dots ~= "" then
      layout.richText = (layout.richText or layout.text or "") .. dots
    end
    -- CategoryRow.jsx orders the label, then the badges, then the count, so the count sits
    -- at the right edge where an item row keeps its badges. The two are one tight cluster: the
    -- count is right aligned at the row's padding in a column only as wide as the widest count
    -- in the list, and the badges sit one gutter to its left in a column only as wide as the
    -- marks a header can carry. A count column of a fixed 36 left the mark stranded half a row
    -- away from the "1" beside it, which is what the owner's markup was about.
    local left = addLeft(layout, Tree.PAD + layout.indent, "chevron", Tree.CHEVRON)
    left = addLeft(layout, left, "icon", Tree.CATEGORY_ICON)
    local pad = Tree.BadgeOverhang(layout.badgeSize)
    local right = addRight(layout, Tree.GUTTER, "count", countColumn(opts, layout.metaFontSize))
    -- Brief PR29: "Show nearest" on a "Sold by" header, right aligned just before the count.
    if Tree.NearestShows(row) then
      layout.nearest = true
      right = addRight(layout, right, "nearest", Tree.NearestWidth(layout.metaFontSize, Tree.nearestMeasured))
    end
    right = addRight(layout, right, "badges", Tree.BadgeColumn(layout.badgeMax, layout.badgeSize), "right", pad)
    fillName(layout, left, right, opts)
    return layout
  end

  if kind == "skill" then
    -- The "Your skill" row CategoryPanel.jsx draws under a profession header: the category's
    -- own glyph in gold, the specialisation in muted small text, and the divider under it. It
    -- sits at the indent of the rows it heads rather than the design's flat 8px, so it reads
    -- as part of the section it belongs to.
    layout.height = SIZES.ITEMTREE_LIST_ROW_H
    layout.divider = true
    layout.dividerColor = Tree.BORDER_COLOR
    layout.fontSize = small
    layout.nameColor = "ITEMTREE_COLOR_TEXT_MUTED"
    layout.iconAsset = assetKey(row.icon, "CAT_NOTE")
    layout.iconColor = "ITEMTREE_COLOR_BORDER_GOLD"
    layout.iconSize = Tree.CATEGORY_ICON
    layout.text = row.text or ""
    local left = addLeft(layout, Tree.PAD + layout.indent, "icon", Tree.CATEGORY_ICON)
    fillName(layout, left, Tree.GUTTER, opts)
    return layout
  end

  if kind == "change" then
    layout.height = density == "compact" and SIZES.ITEMTREE_LIST_ROW_H_COMPACT or SIZES.ITEMTREE_LIST_CHANGE_H
    -- A change belongs to the row above it, so it sits at the parent's indent and then steps
    -- past the chevron to line up under the parent's name.
    layout.indent = Theme.Indent(math.max(0, drawDepth - 1)) + Tree.CHEVRON + Tree.GUTTER
    layout.badgeSize = Tree.BADGE_LIST
    layout.badgeMax = 1
    layout.badges = { "changed" }
    layout.fontSize = small
    layout.nameColor = "ITEMTREE_COLOR_TEXT_MUTED"
    layout.text, layout.richText = Tree.ChangeText(row.change)
    local left = addLeft(layout, Tree.PAD + layout.indent, "badges", Tree.MARK)
    fillName(layout, left, Tree.GUTTER, opts)
    return layout
  end

  if kind == "more" then
    -- The link lines up under the names of the children it is standing in for.
    layout.indent = Theme.Indent(drawDepth) + Tree.CHEVRON + Tree.GUTTER
    layout.nameColor = "ITEMTREE_COLOR_TEXT_HINT"
    layout.iconAsset = "ICON_ZOOMIN"
    layout.iconSize = Tree.MARK
    layout.text = Tree.MoreText(row)
    local left = addLeft(layout, Tree.PAD + layout.indent, "icon", Tree.MARK)
    fillName(layout, left, Tree.GUTTER, opts)
    return layout
  end

  -- EXPERIMENTAL (brief E25), a mode that asks for the strip: the row of ingredient icons under a craft row,
  -- indented to that row's name and as tall as the lines its icons wrap onto. It is the pane's
  -- own row (Tree.StripRows), so the view model never hears about it and nothing counts it.
  if kind == "strip" then
    layout.indent = Theme.Indent(drawDepth) + Tree.CHEVRON + Tree.GUTTER + Tree.ICON + Tree.GUTTER
    layout.stripLeft = Tree.StripLeft(drawDepth)
    layout.iconSize = math.max(1, math.min(Tree.STRIP_ICON, rowHeight - 2 * Tree.BORDER))
    local room = nil
    if opts.width then
      room = math.max(1, opts.width - layout.stripLeft - Tree.GUTTER)
    end
    layout.strip = Tree.StripCells(row.ingredients, room, layout.iconSize, layout.metaFontSize)
    layout.height = rowHeight * layout.strip.lines
    layout.owner = row.owner
    return layout
  end

  if kind == "hint" then
    -- A quiet footnote at the foot of a list (the world drop note under a creature's Loot tab).
    -- It reads as part of the list rather than as a banner: no wash, no badges, no chevron, no
    -- quantity, the muted face, and one small mark in the icon column where it is not a note.
    layout.hint = true
    layout.height = rowHeight + Tree.GUTTER
    layout.fontSize = small
    layout.wrap = true
    layout.text = row.text or ""
    layout.indent = Theme.Indent(drawDepth) + Tree.CHEVRON + Tree.GUTTER
    local left = Tree.PAD + layout.indent
    if row.note then
      layout.nameColor = "ITEMTREE_COLOR_TEXT_DISABLED"
      layout.wrap = false
      layout.height = rowHeight
    else
      layout.nameColor = "ITEMTREE_COLOR_TEXT_MUTED"
      layout.iconAsset = "BADGE_INFO"
      layout.iconColor = "ITEMTREE_COLOR_TEXT_MUTED"
      layout.iconSize = Tree.MARK
      left = addLeft(layout, left, "icon", Tree.MARK)
    end
    -- Every line of the hint starts at the same x, whether or not it drew the mark, so the
    -- block reads as one thing.
    if not layout.columns.icon then
      left = left + Tree.MARK + Tree.GUTTER
    end
    fillName(layout, left, Tree.GUTTER, opts)
    return layout
  end

  if kind == "notice" then
    -- Notice text wraps, so the row is a little taller than a list row.
    layout.height = rowHeight + Tree.GUTTER
    layout.nameColor = "ITEMTREE_COLOR_TEXT_MUTED"
    layout.fontSize = small
    layout.iconAsset = "BADGE_INFO"
    layout.iconSize = Tree.MARK
    layout.background = "ITEMTREE_COLOR_SEMANTIC_NOTE"
    layout.backgroundAlpha = Tree.NOTICE_ALPHA
    layout.divider = true
    layout.wrap = true
    layout.text = row.text or ""
    local left = addLeft(layout, Tree.PAD + layout.indent, "icon", Tree.MARK)
    fillName(layout, left, Tree.GUTTER, opts)
    return layout
  end

  if kind == "loading" then
    layout.nameColor = "ITEMTREE_COLOR_TEXT_HINT"
    layout.iconAsset = "BADGE_RING"
    layout.iconColor = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
    layout.iconSize = Tree.MARK
    layout.text = row.text or L["Loading data"]
    local left = addLeft(layout, Tree.PAD + layout.indent, "icon", Tree.MARK)
    fillName(layout, left, Tree.GUTTER, opts)
    return layout
  end

  if kind == "empty" then
    -- EmptyState is a centred block, not a row: it takes the pane. The message is the view
    -- model's, because the view model knows which direction was asked for.
    --
    -- The words wrap inside a paragraph centred in the pane rather than running its whole
    -- width: the sources line is two sentences long, and a column the width of a wide window
    -- read as one line that ran off the end and ended in an ellipsis.
    layout.fill = true
    layout.indent = 0
    layout.height = math.max(tonumber(opts.height) or 0, Tree.EMPTY_MIN_H)
    layout.nameColor = "ITEMTREE_COLOR_TEXT_MUTED"
    layout.fontSize = Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_LG
    layout.wrap = true
    layout.text = row.text or L["No known uses"]
    local inset = Tree.PAD
    if opts.width then
      layout.textWidth = Tree.EmptyWidth(opts.width)
      inset = math.max(Tree.PAD, math.floor((opts.width - layout.textWidth) / 2))
    end
    fillName(layout, inset, inset, opts, "centre")
    return layout
  end

  -- EXPERIMENTAL (brief E25), a mode that asks for the group: the muted "Ingredients (2)" header Core adds as
  -- a craft row's first child. It reads as a quiet divider inside the branch rather than as a
  -- row of the tree: no icon of its own beyond the small note mark, no badges, no quantity, the
  -- muted face, and its own chevron. Its leaves are ordinary item rows and fall through to the
  -- item row below.
  if row.ingredientGroup then
    layout.kind = "row"
    layout.chevron, layout.chevronAsset = chevronState(row)
    layout.chevronColor = Tree.CHEVRON_COLOR
    layout.fontSize = small
    layout.nameColor = "ITEMTREE_COLOR_TEXT_MUTED"
    layout.iconAsset = "CAT_NOTE"
    layout.iconColor = "ITEMTREE_COLOR_TEXT_MUTED"
    layout.iconSize = Tree.MARK
    layout.ingredientGroup = true
    layout.text = row.text or ""
    local left = addLeft(layout, Tree.PAD + layout.indent, "chevron", Tree.CHEVRON)
    left = addLeft(layout, left, "icon", Tree.MARK)
    fillName(layout, left, Tree.GUTTER, opts)
    return layout
  end

  -- Brief BQ15 (QA 2026-10-10 item 1): the "Rewards (2)" group Core adds under a quest in Used by,
  -- drawn the way the "Ingredients (n)" group is: its own chevron, the muted face, no badges and
  -- no quantity, with the gold coins in the icon column in their own colours.
  if row.rewardGroup then
    layout.kind = "row"
    layout.chevron, layout.chevronAsset = chevronState(row)
    layout.chevronColor = Tree.CHEVRON_COLOR
    layout.fontSize = small
    layout.nameColor = "ITEMTREE_COLOR_TEXT_MUTED"
    layout.iconAsset = "CAT_REWARDS"
    layout.iconSize = Tree.MARK
    layout.rewardGroup = true
    layout.text = row.text or ""
    local left = addLeft(layout, Tree.PAD + layout.indent, "chevron", Tree.CHEVRON)
    left = addLeft(layout, left, "icon", Tree.MARK)
    fillName(layout, left, Tree.GUTTER, opts)
    return layout
  end

  -- Brief E87: a summary that cannot be pressed is words, not a source. It lines up with the
  -- "Show N more" row it would otherwise have been, in the muted face with the small note mark:
  -- no chevron, no badge and none of a source row's columns, so nothing on it reads as a creature
  -- or a vendor with a type and a rate.
  if Tree.IsQuietSummary(row) then
    layout.kind = "row"
    layout.quietSummary = true
    layout.chevron = "none"
    layout.badges = {}
    layout.indent = Theme.Indent(drawDepth) + Tree.CHEVRON + Tree.GUTTER
    layout.nameColor = "ITEMTREE_COLOR_TEXT_MUTED"
    layout.iconAsset = "CAT_NOTE"
    layout.iconColor = "ITEMTREE_COLOR_TEXT_MUTED"
    layout.iconSize = Tree.MARK
    layout.text = Tree.SummaryText(row)
    if row.loop then
      layout.alpha = Tree.LOOP_ALPHA
      layout.hint = L["Already in this path"]
    end
    local left = addLeft(layout, Tree.PAD + layout.indent, "icon", Tree.MARK)
    fillName(layout, left, Tree.GUTTER, opts)
    return layout
  end

  -- An item row, and the shape anything unrecognised falls back to.
  layout.kind = "row"
  layout.badges = Badges.Sort(node and node.badges, Tree.BADGE_MAX_ROW)
  layout.chevron, layout.chevronAsset = chevronState(row)
  -- E25: a craft whose only child is its ingredient group still opens, so it keeps a chevron,
  -- and the chevron is drawn dimmer so a branch that goes on to make something else can still be
  -- told from one that only lists what it is made of.
  layout.chevronColor = row.ingredientsOnly and Tree.CHEVRON_COLOR_DIM or Tree.CHEVRON_COLOR
  layout.nameColor = nameColorFor(node)
  -- E81: the name and, on an enchanting recipe, what its enchant does. The column draws the rich
  -- string and the client ends it with its own ellipsis by drawn width, so the colour codes in it
  -- never count as characters; layout.text stays the plain words everything else reads.
  local plainText, richText = Tree.RowText(node, row)
  layout.text = plainText
  if richText ~= plainText then
    layout.richText = richText
  end
  layout.quantityText = quantityText(node)
  layout.metaText = (node and node.meta) or ""
  -- The quantity column shows one number, and a quantity beats a percentage there, so a row
  -- that carries both (a predicted disenchant result) keeps its rate in the meta column
  -- rather than losing it. "78%" is the client's own way of writing it.
  if layout.metaText == "" and node and node.percent and node.quantity then
    layout.metaText = tostring(node.percent) .. "%"
  end
  layout.diffKind, layout.diffId = Tree.DiffSubject(node)
  -- What a Predicted mark on this row is predicted from, so its tooltip says which kind of
  -- prediction it is marking rather than the disenchant rule's words on every one of them.
  layout.badgeBasis = Tree.BadgeBasis(row)
  -- Brief E93: the row's own note, which its Community note mark says when hovered.
  layout.badgeNote = Tree.BadgeNote(row)
  layout.iconSize = Tree.IconSize(layout.height, Tree.ICON)
  -- The node names its own glyph. An Assets key (a requirement's CAT_REQUIREMENT) is the key
  -- itself; anything else is a texture path or a file data id out of the generated data.
  local nodeIcon = node and node.icon or nil
  if type(nodeIcon) == "string" and Assets.Has(nodeIcon) then
    layout.iconAsset = nodeIcon
  elseif node and (node.kind == "object" or node.kind == "set") then
    -- Brief Q9b: a herb, a vein, a fishing pool or a chest wears what it yields, and an item set
    -- its head or chest piece: the item's own icon the view model found (Core/ViewModel.lua
    -- NodeIcon and SetIcon), over the glyph of its kind. Never the note.
    if nodeIcon then
      layout.iconFile = nodeIcon
    end
    layout.iconAsset = assetKey(node.iconAsset, assetKey(NODE_ICONS[node.kind], "ICON_QUESTIONMARK"))
  else
    if nodeIcon and node.kind ~= "category" and not NODE_ICONS[node.kind] then
      layout.iconFile = nodeIcon
    end
    layout.iconAsset = assetKey(NODE_ICONS[node and node.kind], "ICON_QUESTIONMARK")
  end
  -- E53: the creature's own portrait, where the shipped table states one. The kind icon above is
  -- what this row draws now; the number here is only an offer, and applyIcon decides whether to
  -- take it up. Nothing about the row's geometry depends on it.
  layout.portrait = Tree.PortraitOf(row)
  -- Brief P5b: a class spell's row. The data ships no spell icon, so the spell's own comes from the
  -- client, one pcalled and cached lookup per drawn row (Tree.SpellTexture), and the spell mark
  -- stands in where the client has none. The class word goes in the meta column, in the class's
  -- own colour where the client states one.
  local classSpell = Tree.ClassSpell(row)
  local spellTexture = nil
  if classSpell then
    layout.classSpell = true
    if type(Tree.SpellTexture) == "function" then
      spellTexture = Tree.SpellTexture(classSpell.spellId)
    end
    if spellTexture then
      layout.iconFile = spellTexture
    else
      layout.iconFile = nil
      layout.iconAsset = assetKey("ICON_SPELL_MARK", layout.iconAsset)
    end
    if classSpell.name then
      layout.classWord = classSpell.name
      local color = type(Tree.ClassColor) == "function" and Tree.ClassColor(classSpell.token) or nil
      layout.classColor = color
      if color then
        layout.metaText = "|c" .. color .. classSpell.name .. "|r"
      else
        layout.metaText = classSpell.name
      end
    end
  end
  -- Brief CT1: a class trainer's spell row wears the spell's own icon the same way (one pcalled and
  -- cached lookup per drawn row), and where the character knows the spell (Tree.SpellKnown, a read
  -- of the spell book for this drawn row alone, never a pass over the list) the muted name and
  -- "Learnt, Rank 3" in the second column.
  local trainerSpell = Tree.TrainerSpell(row)
  if trainerSpell then
    if type(Tree.SpellTexture) == "function" then
      spellTexture = Tree.SpellTexture(trainerSpell.spellId)
    end
    if spellTexture then
      layout.iconFile = spellTexture
    else
      layout.iconFile = nil
      layout.iconAsset = assetKey("ICON_SPELL_MARK", layout.iconAsset)
    end
    -- Brief PL1 (QA item 288): a pet trainer's row reads Learnt where the hunter or one of the
    -- hunter's pets knows it (Tree.PetTrainerLearnt), where TW3 never marked it.
    local learnt
    if trainerSpell.pet then
      learnt = type(Tree.PetTrainerLearnt) == "function" and Tree.PetTrainerLearnt(trainerSpell) == true
    else
      learnt = type(Tree.SpellKnown) == "function" and Tree.SpellKnown(trainerSpell.spellId) == true
    end
    if learnt then
      layout.learnt = true
      layout.nameColor = "ITEMTREE_COLOR_TEXT_MUTED"
      layout.metaText = Tree.LearntMeta(trainerSpell)
    end
  end
  -- A spell or an enchant is not the item it makes, so it says so in the corner of its icon. A
  -- class spell drawn with the spell mark itself for want of its own icon needs no second one.
  if node and MARK_KINDS[node.kind] and not ((classSpell or trainerSpell) and not spellTexture) then
    layout.markAsset = "ICON_SPELL_MARK"
    layout.markSize = Tree.MarkSize(layout.iconSize)
    layout.markBacking = "ITEMTREE_BADGE_BACKING"
  end
  if row.loop then
    layout.alpha = Tree.LOOP_ALPHA
    layout.hint = L["Already in this path"]
  end
  -- An item the build withholds, in the corner of its icon, both ways round (Tree.DiscoveryMark).
  -- While nobody has found it the name is dimmed (Tree.UNDISCOVERED_ALPHA), because nobody can
  -- say what it is yet, with the client's own question mark in the corner. Once the realm has
  -- found it the dimming goes and the corner wears a chest instead, because the row is now a
  -- real item ItemTree's own data still holds only a stub for.
  -- Either way it keeps the icon the build's Item row states, which is the one thing the build
  -- does say about it.
  local discovery, discoveryAsset = Tree.DiscoveryMark(node)
  if discovery == "undiscovered" then
    layout.undiscovered = true
    layout.nameAlpha = Tree.UNDISCOVERED_ALPHA
  end
  if discovery then
    layout.discovery = discovery
  end
  if discoveryAsset then
    layout.markAsset = discoveryAsset
    layout.markSize = Tree.MarkSize(layout.iconSize)
    layout.markBacking = "ITEMTREE_BADGE_BACKING"
  end
  -- A craft and the item it makes drawn as one row (Core/ViewModel.lua opts.mergeCrafts). The
  -- row is the item, so it wears no spell mark; what it adds is how many the craft makes, in
  -- the bottom right of the icon where the client writes a stack count, and the recipe mark in
  -- the top left where the two can never land on each other. The columns are the item row's
  -- own: the quantity is how many of the root the craft eats and the meta line is its skill.
  local craft = type(row.craft) == "table" and row.craft or nil
  if craft then
    layout.merged = true
    layout.yieldText = Tree.YieldText(craft, layout.iconSize, layout.metaFontSize)
    local recipeAsset = type(craft.recipe) == "string" and Tree.RecipeMark() or nil
    if recipeAsset then
      layout.recipeAsset = recipeAsset
      layout.recipeSize = Tree.MarkSize(layout.iconSize)
      layout.recipeBacking = "ITEMTREE_BADGE_BACKING"
    end
  end
  local left = addLeft(layout, Tree.PAD + layout.indent, "chevron", Tree.CHEVRON)
  left = addLeft(layout, left, "icon", layout.iconSize)
  -- The medallion in a badge stands a pixel proud of the cluster's own box on each side, so
  -- the badge column is given that pixel back rather than letting a mark sit over the name
  -- beside it or over the row's right edge.
  local badgePad = Tree.BadgeOverhang(layout.badgeSize)
  -- Walking up, a source row spends the quantity and meta columns on the facts a player
  -- compares sources by instead, with the confidence badge left at the right edge.
  local source = Tree.SourceText(row)
  if source then
    layout.source = source
    -- A source with one more thing to say about itself says it after the name, because no column
    -- has room for it: Core words the whole line, so the pane never joins anything.
    if source.name ~= "" then
      layout.text = source.name
      layout.richText = nil
    end
    layout.sourceTypeText =
      Tree.SourceTypeLine(source.type, source.rowProvenance, SOURCE_W.sourceType, layout.metaFontSize)
    layout.sourceZoneText = source.zone
    -- Brief P6b: the side the NPC serves, as a small icon before the zone column's words.
    layout.side = Tree.RowSide(row)
    -- Brief Z1: the zone column opens the zone it names, or on a zone's Here tab picks the source.
    layout.zoneLink = Tree.ZoneLink(row)
    layout.sourceRateText = source.rate
    -- Brief GS3: a guess reads as one at a glance: "Guess" in the guess colour where a rate would
    -- be, and the name in the muted face so the eye lands on the real rows first. Brief C6: only
    -- where the row names a creature, a place or a vendor (an item's Sources view). A row that IS
    -- an item (a creature's Predicted loot) keeps its quality colour like every other item row.
    if source.guess then
      layout.nameColor = Tree.GuessNameColor(node, layout.nameColor)
      layout.sourceRateColor = Tree.GUESS_RATE_COLOR
    end
    -- Brief T2b: a source only the other side can use says so where its rate or price would be,
    -- in the muted face; the row's tooltip keeps the rate and says the same words on a line.
    local factionOnly = Tree.FactionOnlyText(row, opts.playerFaction)
    if factionOnly then
      layout.factionOnly = factionOnly
      layout.sourceRateText = factionOnly
      layout.sourceRateColor = Tree.FACTION_COLOR
    end
    layout.quantityText = ""
    local kept = Tree.SourceColumns(opts.width)
    local right = addRight(layout, Tree.GUTTER, "badges", Tree.BADGES, "right", badgePad)
    -- Brief T2b: "Alliance only" is wider than any rate, so the rate column takes what it needs
    -- out of the zone column beside it on this row alone; the zone column's left edge stays where
    -- every other row has it, so the columns still line up. Brief PS1 bundle prices: a vendor's
    -- price that says its bundle ("1s 25c for 5") takes room the same way, or the column's
    -- ellipsis would cut the count off. Brief FX-AG2 (FR-AG2's M3): a bundle price is never cut.
    -- Whatever half the zone column cannot give it (all of it once a narrow pane has dropped the
    -- zone column, Tree.SourceColumns) comes out of the name column, on this row alone, and the
    -- name's floor goes down by the same amount, so the name never runs further under the price
    -- than it would under a plain one. No shipped bundle price needs more than the zone's half.
    local widths = SOURCE_W
    local wideRate = layout.factionOnly
    local bundle = false
    if not wideRate and source.bundle and type(layout.sourceRateText) == "string" then
      wideRate = layout.sourceRateText
      bundle = true
    end
    local fromName = 0
    if wideRate and kept.sourceRate then
      local extra = math.ceil(#wideRate * layout.metaFontSize * Tree.COUNT_CHAR) - SOURCE_W.sourceRate
      if extra > 0 then
        local fromZone = 0
        if kept.sourceZone then
          fromZone = math.min(extra, math.floor(SOURCE_W.sourceZone / 2))
        end
        if bundle then
          fromName = extra - fromZone
        end
        widths = {
          sourceRate = SOURCE_W.sourceRate + fromZone + fromName,
          sourceZone = SOURCE_W.sourceZone - fromZone,
          sourceType = SOURCE_W.sourceType,
        }
      end
    end
    for _, name in ipairs(SOURCE_ORDER) do
      if kept[name] then
        right = addRight(layout, right, name, widths[name], SOURCE_ALIGN[name])
      end
    end
    local nameColumn = fillName(layout, left, right, opts, nil, math.max(0, Tree.MIN_NAME_W - fromName))
    -- Brief T2b: "Trader Selm <Wrought Iron Supplies>", the title muted and cut first.
    local title = Tree.RowTitle(row)
    if title then
      local plain, rich = Tree.TitledName(layout.text, node and node.name, title, nameColumn.width, layout.fontSize)
      if rich then
        layout.title = title
        layout.text = plain
        layout.richText = rich
      end
    end
    markQuestDone(layout, node)
    return layout
  end
  local right = addRight(layout, Tree.GUTTER, "badges", Tree.BADGES, "right", badgePad)
  -- E25, a mode that asks for the strip: the small quiet button that opens the strip of ingredient icons under
  -- the row, at the row's right hand end and before the badges. Only a craft row that has
  -- ingredients draws one, and only in that mode, so every other row and every other mode lays
  -- out exactly as it did before.
  if
    Tree.CraftShows("strip", opts.craftIngredients or "off")
    and type(row.ingredients) == "table"
    and #row.ingredients > 0
  then
    local open = false
    if type(opts.strips) == "table" and opts.strips[row.key] == true then
      open = true
    end
    layout.stripOpen = open
    layout.stripAsset = open and Tree.STRIP_OPEN_ASSET or Tree.STRIP_SHUT_ASSET
    right = addRight(layout, right, "strip", Tree.MARK, "right")
  end
  right = addRight(layout, right, "meta", Tree.META, "left")
  right = addRight(layout, right, "quantity", Tree.QUANTITY)
  fillName(layout, left, right, opts)
  markQuestDone(layout, node)
  return layout
end

-- One row's height and nothing else, which is what a list of 1,500 rows is measured with: a
-- draw asks for every row's extent and lays out only the handful it draws, so the extents have
-- to cost nothing. The numbers are Tree.Layout's own, read from the same tokens.
function Tree.Extent(row, density, opts)
  row = type(row) == "table" and row or EMPTY
  opts = type(opts) == "table" and opts or EMPTY
  density = density == "compact" and "compact" or "default"
  local kind = row.kind or "row"
  if kind == "category" then
    return SIZES.ITEMTREE_LIST_CATEGORY_H
  end
  if kind == "skill" then
    return SIZES.ITEMTREE_LIST_ROW_H
  end
  if kind == "change" then
    if density == "compact" then
      return SIZES.ITEMTREE_LIST_ROW_H_COMPACT
    end
    return SIZES.ITEMTREE_LIST_CHANGE_H
  end
  if kind == "notice" then
    return Theme.RowHeight(density) + Tree.GUTTER
  end
  -- A hint line wraps and is given the room to; a note is one line, so it is a plain row.
  if kind == "hint" then
    if row.note then
      return Theme.RowHeight(density)
    end
    return Theme.RowHeight(density) + Tree.GUTTER
  end
  if kind == "empty" then
    return math.max(tonumber(opts.height) or 0, Tree.EMPTY_MIN_H)
  end
  -- E25: a strip is as tall as the lines its icons wrap onto, so this is the one kind whose
  -- extent has to lay the row out. It costs one small table per OPEN strip, of which there are a
  -- handful, and nothing at all for every other row in the list.
  if kind == "strip" then
    return Theme.RowHeight(density) * Tree.Layout(row, density, opts).strip.lines
  end
  return Theme.RowHeight(density)
end

-- The node key behind a row, read back through Graph rather than parsed here. Rows that
-- stand for something the graph does not hold, a requirement for instance, answer nil.
local function nodeKeyOf(row)
  local node = type(row) == "table" and row.node or nil
  if type(node) ~= "table" or type(node.key) ~= "string" then
    return nil
  end
  local graph = ItemTree.Graph
  if type(graph) ~= "table" or type(graph.Parse) ~= "function" then
    return nil
  end
  if not graph.Parse(node.key) then
    return nil
  end
  return node.key
end

--- Brief D7: the line a gathering node row's hover ends on where its name opens the node's Map
--- page, "Click to open Rich Thorium Vein". nil for every other row, a node with no page included:
--- that row toggles its zones as D6 made it, and says nothing new about it. Pure.
function Tree.NodeHint(row)
  if type(row) ~= "table" or not (row.gatherNode and row.gatherPage) then
    return nil
  end
  local node = type(row.node) == "table" and row.node or nil
  local name = node and node.name or nil
  if type(name) ~= "string" or name == "" then
    name = row.text
  end
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return string.format(L["Click to open %s"], name)
end

--- Brief Z1: what a row's zone column does when it is clicked, or nil where it does nothing.
---
--- On a zone's own Here tab the column holds the SOURCE the row names, and a click picks that source
--- for the zone's Map tab: { action = "pick", name, pick }. Everywhere else it holds a place, and a
--- click opens that zone's own page: { action = "reroot", key, name }. Core states both
--- (Core/ViewModel.lua zonePick and zoneLink), so this only reads them. Pure.
---
--- Brief N1: where Core states the page that source opens on (sourceLink: the vendor's or the
--- creature's npc page, the node's page), the click opens it: { action = "source", key, name,
--- pick }, pick being the Map tab pick the row also carries, or nil. A Here row with no such page
--- keeps the Z1 pick.
function Tree.ZoneLink(row)
  if type(row) ~= "table" or (row.kind or "row") ~= "row" then
    return nil
  end
  local pick = type(row.zonePick) == "table" and row.zonePick or nil
  local source = type(row.sourceLink) == "table" and row.sourceLink or nil
  if source and type(source.key) == "string" and type(source.name) == "string" and source.name ~= "" then
    return { action = "source", key = source.key, name = source.name, pick = pick }
  end
  if pick and type(pick.name) == "string" and pick.name ~= "" then
    return { action = "pick", name = pick.name, pick = pick }
  end
  local link = type(row.zoneLink) == "table" and row.zoneLink or nil
  if link and type(link.key) == "string" and type(link.name) == "string" and link.name ~= "" then
    return { action = "reroot", key = link.key, name = link.name }
  end
  return nil
end

--- The line the zone column's hover ends on: "Click to open Feralas", or on a zone's Here tab
--- "Click to show Rich Thorium Vein on the map". nil for a column that is not a link. Pure.
function Tree.ZoneHint(row)
  local link = Tree.ZoneLink(row)
  -- Brief N1: a source with a page says so in the row's own tooltip (Tree.SourceHint), which the
  -- column's hover already shows, so the column adds nothing of its own.
  if not link or link.action == "source" then
    return nil
  end
  if link.action == "pick" then
    return string.format(L[Tree.ZONE_PICK_HINT], link.name)
  end
  return string.format(L["Click to open %s"], link.name)
end

--- Brief N1: the line a zone Here row's tooltip ends on where the source it names opens its own
--- page from the column: "Click Zerril Softbreeze to open its page". nil for every other row. Pure.
function Tree.SourceHint(row)
  local link = Tree.ZoneLink(row)
  if not link or link.action ~= "source" then
    return nil
  end
  return string.format(L["Click %s to open its page"], link.name)
end

--- Whether a row stands for a GROUP of sources rather than for one of them: a Classic Era
--- summary ("Show 239 more", whose tooltip adds "level 11 to 36") or a world drop. Such a row
--- names nothing the window could open, so it never re-roots. Pure.
function Tree.IsSummary(row)
  return type(row) == "table" and type(row.summary) == "table"
end

--- Brief M15: what a placed object guess row (Core/GuessSources.lua specific type 6, which carries
--- edge.guess.placed) opens: { zone = the zone key its spot stands in, item = the item key the row
--- is a source of }, or nil for any other row. Pressed anywhere, the row opens that zone's Map view
--- on that item, pinned at the object. Pure over Graph's keys.
function Tree.PlacedTarget(row)
  if type(row) ~= "table" or (row.kind or "row") ~= "row" then
    return nil
  end
  local edge = type(row.edge) == "table" and row.edge or EMPTY
  local guess = type(edge.guess) == "table" and edge.guess or EMPTY
  local placed = type(guess.placed) == "table" and guess.placed or nil
  local area = placed and tonumber(placed.area) or nil
  local summary = type(row.summary) == "table" and row.summary or EMPTY
  local itemId = tonumber(summary.item)
  local graph = ItemTree.Graph
  if not area or area < 1 or not itemId or type(graph) ~= "table" or type(graph.Key) ~= "function" then
    return nil
  end
  local okZone, zone = pcall(graph.Key, "zone", area)
  local okItem, item = pcall(graph.Key, "item", itemId)
  if not okZone or not okItem or type(zone) ~= "string" or type(item) ~= "string" then
    return nil
  end
  return { zone = zone, item = item }
end

--- Whether the shipped table really carries the sources behind that summary. The view model
--- draws such a summary as a "Show N more" row (kind "more") and pressing it draws the list in
--- place. A world drop stands for hundreds of creatures the pipeline measured and refused, so it
--- is a plain row that opens nothing and draws no chevron at all. Pure.
function Tree.OpensList(row)
  if not Tree.IsSummary(row) then
    return false
  end
  return (tonumber(row.summary.listed) or 0) > 0
end

--- Brief E87: whether a row is a summary that stands for an unlisted REMAINDER and is drawn as a
--- row, so cannot be pressed: a list the loop or the depth cap stops, or a remainder the table
--- ships no list for ("and 239 more"). Such a row names no source, so it is drawn as the words it
--- is, muted, with no badge, no type, no zone, no rate and no source tooltip. Two summaries keep
--- their own look: the World drop, which is a real statement about the item (a drop, predicted,
--- with its tooltip) and still opens nothing, and a guess that names no source (brief GS3). Pure.
function Tree.IsQuietSummary(row)
  if not Tree.IsSummary(row) or (row.kind or "row") ~= "row" then
    return false
  end
  if row.summary.category == "world" then
    return false
  end
  local source = type(row.source) == "table" and row.source or nil
  return not (source and source.guess == true)
end

--- The words such a row draws. A remainder with no list keeps the table's own ("and 239 more"),
--- which never offers anything. A list that is shipped but cannot be opened here
--- would still read "Show 2 more", which is an offer it cannot keep, so it says what it is
--- instead: "2 more, not listed here". Pure.
function Tree.SummaryText(row)
  row = type(row) == "table" and row or EMPTY
  local summary = type(row.summary) == "table" and row.summary or EMPTY
  local listed = tonumber(summary.listed) or 0
  if listed > 0 then
    return string.format(L["%d more, not listed here"], listed)
  end
  local source = type(row.source) == "table" and row.source or nil
  if source and type(source.name) == "string" and source.name ~= "" then
    return source.name
  end
  local node = type(row.node) == "table" and row.node or nil
  local name = node and node.name or row.text
  return type(name) == "string" and name or ""
end

--- What a click means. Returns the action and the key it applies to.
--
-- click is the column name ("chevron", "icon", "name" or "row") or a table carrying column
-- and button. Actions are "toggle" and "more", which the pane applies to the view model, and
-- "reroot", which it hands to Frame.Open. "none" is a click that does nothing. Brief M15: "placed"
-- answers the zone key and, third, the item key a placed object row opens (Tree.PlacedTarget).
function Tree.Interpret(row, click)
  if type(row) ~= "table" then
    return "none", nil
  end
  local column, button = "row", "LeftButton"
  if type(click) == "string" then
    column = click
  elseif type(click) == "table" then
    column = click.column or "row"
    button = click.button or "LeftButton"
  end
  if button ~= "LeftButton" then
    return "none", nil
  end

  local kind = row.kind or "row"
  if kind == "category" then
    return "toggle", row.key
  end
  if kind == "more" then
    return "more", row.key
  end
  if kind ~= "row" then
    return "none", nil
  end
  -- Brief M15: a placed object row opens its zone's map at the object, from its name, its zone or
  -- anywhere else on it, with the item picked.
  if column ~= "strip" then
    local placed = Tree.PlacedTarget(row)
    if placed then
      return "placed", placed.zone, placed.item
    end
  end
  -- Brief Z1: the zone column, where it is a link. Anywhere else on the row does what it did.
  if column == "zone" then
    local link = Tree.ZoneLink(row)
    if link and link.action == "pick" then
      return "pick", row.key
    end
    -- Brief N1: the source's own page, the row's key going with it for the Map tab pick.
    if link and link.action == "source" then
      return "source", link.key, row.key
    end
    if link then
      return "reroot", link.key
    end
  end
  -- A loop row is already somewhere in its own path, so neither half of it does anything.
  if row.loop then
    return "none", nil
  end
  -- A summary row is not a thing: it stands for the sources a cap did not name, and its key is
  -- one the shipped table made up so the row could point somewhere. It re-rooted the window onto
  -- that made up node from every column, which is the "Object: and 1 more (-1000215496)" the
  -- owner found. A summary whose list can be drawn is a "more" row (answered above, E75, under
  -- any row since E87), so one that is still a row has nothing to open and does nothing at all.
  if Tree.IsSummary(row) then
    return "none", nil
  end
  -- Brief D7: a gathering node whose node has a Map page (Core/ViewModel.lua gatherPage) opens
  -- that page from its name, icon or row, the way every other row re-roots, and still opens and
  -- closes its zones from the chevron.
  if row.gatherNode and row.gatherPage and column ~= "chevron" then
    local pageKey = nodeKeyOf(row)
    if pageKey then
      return "reroot", pageKey
    end
  end
  -- Brief D6: a Classic Era gathering node's row (Core/ViewModel.lua gatherNode) with no page of
  -- its own (no pins) opens or closes its zones on a click anywhere, and one that opens onto
  -- nothing (a node inside an instance, or one the table places nowhere) does nothing at all. The
  -- chevron of a node that does have a page lands here too.
  if row.gatherNode then
    if row.hasChildren then
      return "toggle", row.key
    end
    return "none", nil
  end
  -- E25: the ingredient group is a header, not a thing, so it opens and closes wherever it is
  -- clicked, the way a category header does. Its leaves are ordinary rows and fall through.
  if row.ingredientGroup or row.rewardGroup then
    return "toggle", row.key
  end
  -- E25: the small button at the right hand end of a craft row, which opens the strip of
  -- ingredient icons under it. It is the pane's own state, so the answer is the pane's own
  -- action and the view model never hears about it.
  if column == "strip" then
    return "strip", row.key
  end
  if column == "chevron" then
    if row.hasChildren then
      return "toggle", row.key
    end
    return "none", nil
  end
  -- Brief P5b: a class spell has no page, so its row opens nothing. Brief CT1: nor does a class
  -- trainer's spell row (its spell's page would hold nothing).
  if Tree.ClassSpell(row) or Tree.TrainerSpell(row) then
    return "none", nil
  end
  -- Brief EK1: nor does a Classic Era creature or vendor the table states no creature id for.
  if Tree.NoPage(row) then
    return "none", nil
  end
  local nodeKey = nodeKeyOf(row)
  if nodeKey then
    return "reroot", nodeKey
  end
  return "none", nil
end

--- What a key means. Returns the new highlighted index, an action and its key.
--
-- Up and down move the highlight and answer "move". Right expands a closed row and answers
-- "toggle", or steps into an open one and answers "move". Left collapses an open row and
-- answers "toggle", or walks out to the parent row and answers "move". Anything else, Enter
-- included, answers "none" and stays put.
function Tree.KeyboardMove(rows, index, key)
  rows = type(rows) == "table" and rows or EMPTY
  local count = #rows
  if count == 0 then
    return 0, "none", nil
  end
  index = tonumber(index) or 1
  if index < 1 then
    index = 1
  elseif index > count then
    index = count
  end
  key = Tree.NAV_KEYS[type(key) == "string" and key:upper() or ""]
  local row = rows[index]
  local kind = row.kind or "row"
  local openable = kind == "category" or kind == "row"

  if key == "UP" then
    return math.max(1, index - 1), "move", nil
  end
  if key == "DOWN" then
    return math.min(count, index + 1), "move", nil
  end
  if key == "RIGHT" then
    if openable and not row.loop then
      if row.expanded then
        if index < count then
          return index + 1, "move", nil
        end
      elseif row.hasChildren then
        return index, "toggle", row.key
      end
    end
    return index, "none", nil
  end
  if key == "LEFT" then
    if openable and row.expanded then
      return index, "toggle", row.key
    end
    local depth = tonumber(row.depth) or 0
    for back = index - 1, 1, -1 do
      if (tonumber(rows[back].depth) or 0) < depth then
        return back, "move", nil
      end
    end
    return index, "none", nil
  end
  return index, "none", nil
end

--- Which rows a scroll offset shows. extents is one height per row, in order.
--
-- Returns the first and last visible index, the y of the first one from the top of the whole
-- list, and the total height. first is 0 when there is nothing to draw.
function Tree.Window(extents, offset, height)
  extents = type(extents) == "table" and extents or EMPTY
  offset = math.max(0, tonumber(offset) or 0)
  height = math.max(0, tonumber(height) or 0)
  local total, first, last, top = 0, 0, 0, 0
  for index = 1, #extents do
    local extent = tonumber(extents[index]) or 0
    local bottom = total + extent
    if first == 0 and bottom > offset then
      first, top = index, total
    end
    if first ~= 0 and total < offset + height then
      last = index
    end
    total = bottom
  end
  if first ~= 0 and last < first then
    last = first
  end
  return first, last, top, total
end

-- The category row the sticky header mirrors: the nearest one at or before the first visible
-- row. Nil when that category is itself the first visible row, because then it draws in
-- place, and nil when nothing above the first visible row is a category.
function Tree.StickyIndex(rows, firstVisible)
  rows = type(rows) == "table" and rows or EMPTY
  firstVisible = math.max(1, tonumber(firstVisible) or 1)
  if firstVisible <= 1 or firstVisible > #rows then
    return nil
  end
  for index = firstVisible, 1, -1 do
    local row = rows[index]
    if row and row.kind == "category" then
      if index == firstVisible then
        return nil
      end
      return index
    end
  end
  return nil
end

--- The rows the pane draws for the rows the view model hands out: the same list, with the
--- specialisation row under every expanded profession header the player holds one for.
---
--- Pure, and it never mutates what it was given: the rows are carried over by reference and
--- the specialisation row is the pane's own. The view model's list comes straight back when
--- there is nothing to add, which is every category that is not a profession.
function Tree.SkillRows(rows)
  rows = type(rows) == "table" and rows or EMPTY
  local out, added = {}, false
  for _, row in ipairs(rows) do
    out[#out + 1] = row
    if row.kind == "category" and row.expanded then
      local header = Tree.CategoryHeader(row)
      if header and header.specialisation then
        added = true
        local node = type(row.node) == "table" and row.node or nil
        out[#out + 1] = {
          key = (row.key or "cat") .. "/skill",
          kind = "skill",
          depth = 1,
          text = string.format(L["Your skill: %s"], header.specialisation),
          specialisation = header.specialisation,
          icon = categoryIcon(row, node),
          category = row.category,
        }
      end
    end
  end
  if not added then
    return rows
  end
  return out
end

-- Everything on a row a filter reads, folded once: the name, the meta line beside it, and for
-- a source row the three columns it draws instead of the meta line. A player who can see a
-- word on a row can search for it, which is the whole rule.
--
-- A merged craft row adds the craft's own name, which is the one word a player can no longer
-- see: typing "Boiled Clams" has to find the row whether the setting drew the spell, the item
-- or the two of them as one.
local function filterHaystack(row)
  local node = type(row.node) == "table" and row.node or nil
  local parts = { (Tree.RowText(node, { text = row.text })) }
  if node and type(node.meta) == "string" then
    parts[#parts + 1] = node.meta
  end
  local craft = type(row.craft) == "table" and row.craft or nil
  if craft and type(craft.name) == "string" then
    parts[#parts + 1] = craft.name
  end
  local source = Tree.SourceText(row)
  if source then
    parts[#parts + 1] = source.type
    parts[#parts + 1] = source.zone
    parts[#parts + 1] = source.rate
    -- The words a source row ends with are words on the row, so they are words to search by.
    parts[#parts + 1] = source.note
    -- What kind of creature the row names. The icon says it without words, and the row's tooltip
    -- says it in them, so "beast", "humanoid" and "wolf" are words a player can see and type.
    parts[#parts + 1] = source.kind
    -- Brief T2b: the vendor's title and "Alliance only" are words on the row too.
    parts[#parts + 1] = Tree.RowTitle(row)
    parts[#parts + 1] = Tree.FactionOnlyText(row)
  end
  return table.concat(parts, " "):lower()
end

-- Whether a plain number typed into the search box falls inside a creature row's own level band.
-- "23" finds every creature between 20 and 30, which is what a player typing a level means, and
-- what matching the digits in the words alone would never answer. Pure.
local function withinLevelBand(row, level)
  if not level then
    return false
  end
  local source = Tree.SourceText(row)
  if not source or not source.levelLow or not source.levelHigh then
    return false
  end
  return level >= source.levelLow and level <= source.levelHigh
end

-- The row a change or a "Show N more" row belongs to, read off its key, which the view model
-- builds as parent .. "/change:N" and parent .. "/more".
local function parentKeyOf(row)
  local key = type(row.key) == "string" and row.key or nil
  if not key then
    return nil
  end
  if row.kind == "change" then
    return key:match("^(.*)/change:%d+$")
  end
  if row.kind == "more" then
    return key:match("^(.*)/more$")
  end
  return nil
end

--- The search box's view over the rows. Pure, and the view model never hears about it.
---
--- Non empty text keeps the item rows any of whose drawn words contain it, ignoring case, and
--- the category header above each section that still has one. A change or a "Show N more" row
--- is kept only while the row it belongs to is. Nothing matching at all answers with the empty
--- row, and empty or nil text answers with the rows it was handed, unchanged.
---
--- While the box holds anything the view model draws every shipped summary's list in place
--- (VM:SetSearching), so no "Show N more" row for a summary is handed over at all. A summary row
--- whose list is shipped but cannot open (the loop or the depth cap stops it) is dropped,
--- matching or not: a count over the matching rows is not an answer. A summary with nothing
--- shipped behind it (a world drop) is an answer, and stays.
function Tree.FilterRows(rows, text)
  rows = type(rows) == "table" and rows or EMPTY
  local needle = type(text) == "string" and text:match("^%s*(.-)%s*$"):lower() or ""
  if needle == "" then
    return rows
  end
  -- A plain number is also read as a level, so it can be matched against a creature's band.
  local level = needle:match("^%d+$") and tonumber(needle) or nil

  local matched, matchedKeys = {}, {}
  for _, row in ipairs(rows) do
    -- E25: the ingredient group and its leaves are not rows of the view, so the search neither
    -- matches them nor keeps them. That is what makes a filtered list identical in all five
    -- modes, which is the promise the modes are being compared under.
    -- Brief BQ15: so is the "Rewards (n)" group's header; the rewards under it are rows and match.
    local eligible = (row.kind or "row") == "row"
      and not Tree.IsIngredientRow(row)
      and not row.rewardGroup
      and not Tree.OpensList(row)
    if eligible and (filterHaystack(row):find(needle, 1, true) or withinLevelBand(row, level)) then
      matched[row] = true
      if type(row.key) == "string" then
        matchedKeys[row.key] = true
      end
    end
  end

  -- A category survives while anything in its own section matched.
  local alive, section = {}, nil
  for _, row in ipairs(rows) do
    if row.kind == "category" then
      section = type(row.key) == "string" and row.key or nil
    elseif matched[row] and section then
      alive[section] = true
    end
  end

  local out = {}
  for _, row in ipairs(rows) do
    local kind = row.kind or "row"
    local keep = false
    if kind == "category" then
      keep = type(row.key) == "string" and alive[row.key] == true
    elseif kind == "row" then
      keep = matched[row] == true
    elseif kind == "change" or kind == "more" then
      local parent = parentKeyOf(row)
      keep = parent ~= nil and (matchedKeys[parent] == true or alive[parent] == true)
    end
    if keep then
      out[#out + 1] = row
    end
  end
  if #out == 0 then
    out[1] = { key = "filter:empty", kind = "empty", depth = 0, text = L["No matches"] }
  end
  return out
end

--- The words the search box carries for each view, by view key (Core/Edges.lua USES, SOURCES,
--- REQUIRES and DISENCHANTS). Each is the English wording and its own locale key.
local PLACEHOLDER_TEXT = {
  uses = "Search uses",
  sources = "Search sources",
  requires = "Search requirements",
  disenchants = "Search disenchant results",
  -- A creature root's two views (brief E57). The Map tab hides the box altogether, because a map
  -- is not a list, but the words are here so a build that shows it anyway still says something
  -- true rather than reading as Used by.
  loot = "Search loot",
  map = "Search loot",
  -- Brief Q8: a quest root's Quest tab.
  quest = "Search this quest",
}

--- What the search box says before anything is typed. The window has three views over two
--- directions, so the box says which of the three is being narrowed: the view is asked for
--- first, and a window that still only answers with a direction falls back to the two words
--- that direction stood for. Read lazily and guarded either way, and a window that cannot say
--- at all reads as Used by.
function Tree.PlaceholderText()
  local ui = ItemTree.UI
  local frame = type(ui) == "table" and ui.Frame or nil
  local Edges = ItemTree.Edges
  local up = (type(Edges) == "table" and Edges.UP) or "up"
  if type(frame) == "table" then
    if type(frame.View) == "function" then
      local ok, view = pcall(frame.View)
      if ok and PLACEHOLDER_TEXT[view] then
        return L[PLACEHOLDER_TEXT[view]]
      end
    end
    if type(frame.Direction) == "function" then
      local ok, direction = pcall(frame.Direction)
      if ok and direction == up then
        return L["Search sources"]
      end
    end
  end
  return L["Search uses"]
end

--- How far one wheel click moves the list: one row, whatever else is in it. Pure.
---
--- E54, the scroll jumping the owner reported on Arcane Crystal 12363. The pane never stated a
--- step, and a ScrollBox with none of its own falls back to the extent of the FIRST element of
--- the list, caches that on the view and never clears it again
--- (ScrollBoxListViewMixin:GetPanExtent, wow-ui-source branch `forever`). The wheel then moves
--- twice that per click (ScrollControllerMixin.Defaults.WheelPanScalar), so the first list the
--- pane ever measured sets the step for the rest of the session, and a view whose only row is
--- the plain empty line sets it to the WHOLE PANE, because that is what Tree.Extent answers for
--- that row. One click then swallowed a list only a little taller than the pane, which is the
--- two positions and nothing in between that he saw. The pane states this instead, on every
--- draw, so neither the density nor whatever was drawn before it can leave a stale step behind.
function Tree.WheelStep(density)
  return Theme.RowHeight(density == "compact" and "compact" or "default")
end

--- Where a remembered scroll offset really lands in the list drawn now (brief E61). The player's
--- pixels, clamped to what this list can scroll: the data can change between visits, a discovery
--- can shorten a list while the window is elsewhere, and a list that no longer runs that far
--- comes back at its own end rather than past it. A list that now fits comes back at the top.
--- Pure.
function Tree.ClampOffset(offset, total, height)
  offset = math.max(0, tonumber(offset) or 0)
  local range = math.max(0, (tonumber(total) or 0) - math.max(0, tonumber(height) or 0))
  if offset > range then
    return range
  end
  return offset
end

--- The share of its own range a ScrollBox has to be put at to show a given pixel offset.
---
--- The box keeps a percentage and works the pixels out from it
--- (ScrollBoxBaseMixin:GetDerivedScrollOffset is GetDerivedScrollRange times GetScrollPercentage,
--- wow-ui-source branch `forever`, Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua), and its own
--- range is only right once it has laid the new list out, which is a frame too late for a restore.
--- So the share is worked out here, from the heights this draw measured. 0 for a list that fits,
--- which is the top of it. Pure.
function Tree.ScrollPercent(offset, total, height)
  local range = math.max(0, (tonumber(total) or 0) - math.max(0, tonumber(height) or 0))
  if range <= 0 then
    return 0
  end
  return math.max(0, math.min(1, (math.max(0, tonumber(offset) or 0)) / range))
end

--- Whether a list that tall needs the scrollbar. A pane that has not been sized yet reports no
--- height at all, and then the bar stays, which is what it did before it could be hidden.
function Tree.Overflows(total, height)
  total = tonumber(total) or 0
  height = tonumber(height) or 0
  if height <= 0 then
    return true
  end
  return total > height
end

--- How wide the words of an empty state may run in a pane this wide: the pane less generous
--- padding on both sides, and never wider than a paragraph. A pane too narrow to give up that
--- padding keeps the list's own instead, because a sentence squeezed to nothing reads worse
--- than one close to the edge. A caller that states no width is not laying out for a real pane
--- and gets the paragraph width. Pure.
function Tree.EmptyWidth(width)
  width = tonumber(width) or 0
  if width <= 0 then
    return Tree.EMPTY_MAX_W
  end
  local room = math.min(width - 2 * Tree.EMPTY_PAD, Tree.EMPTY_MAX_W)
  if room < Tree.EMPTY_MIN_W then
    room = math.max(math.min(width - 2 * Tree.PAD, Tree.EMPTY_MIN_W), 1)
  end
  return math.floor(room)
end

--- The illustration key the designed empty state draws, which is the owner's own art where the
--- build carries it and the client's own chest icon where it does not. Pure.
function Tree.EmptyArt()
  if Assets.Has(Tree.EMPTY_ART_KEY) then
    return Tree.EMPTY_ART_KEY
  end
  return Tree.EMPTY_ART_FALLBACK
end

--- How wide that illustration is for its height. UI/Assets.lua reads it off the rect the
--- artwork occupies inside its canvas, so the block draws the picture at its own shape rather
--- than stretching it into a square; a key that states no rect reads as square, which is what
--- the icon the fallback names is. Guarded rather than asked outright, because an Assets table
--- with neither key raises and a pane is worth more than a shape. Pure.
function Tree.EmptyAspect()
  local ok, aspect = pcall(Assets.Aspect, Tree.EmptyArt())
  if not ok or type(aspect) ~= "number" or aspect <= 0 then
    return 1
  end
  return aspect
end

--- How big the illustration is drawn with this much of the pane left over for it: its own width
--- where there is room, shrunk to fit where there is not, and nothing at all once shrinking it
--- would leave a smudge rather than a picture. width is the widest the block lets it be, aspect
--- is how wide the artwork is for its height, and room is what is left of the pane once every
--- other piece of the block has taken its share; a caller with no pane to answer for passes no
--- room and gets the full size. Returns the width and the height, both whole pixels. Pure.
function Tree.EmptyArtSize(width, aspect, room)
  aspect = tonumber(aspect) or 1
  if aspect <= 0 then
    aspect = 1
  end
  width = math.floor(tonumber(width) or 0)
  if width < 1 then
    return 0, 0
  end
  local least = math.min(Tree.EMPTY_ART_MIN_W, width)
  room = tonumber(room)
  if room and room < width / aspect then
    local fits = math.floor(math.max(room, 0) * aspect)
    if fits < least then
      return 0, 0
    end
    width = fits
  end
  return width, math.max(1, math.floor(width / aspect + 0.5))
end

--- Whether a drawn list is one empty state and nothing else, which is the only list the
--- designed block stands in for. Pure.
function Tree.IsEmptyOnly(rows)
  rows = type(rows) == "table" and rows or EMPTY
  return #rows == 1 and type(rows[1]) == "table" and rows[1].kind == "empty"
end

--- Which empty state the pane draws, from the view it is on and the root's own corner mark
--- (Tree.DiscoveryMark's word). Pure.
---
--- The answer is always a table:
---   kind      "plain", and then the pane draws the view model's own line and nothing else;
---             "sources", the block over an item's Sources view with nothing in it; or
---             "undiscovered", the block over any view of an item nobody has found
---   heading   the gold line over the block
---   lines     the wrapped paragraph under it, in order
---
--- "undiscovered" wins over everything else on every view: an item nobody has found has no uses,
--- no sources and no recipes to list, and each view's ordinary line ("No known uses on this
--- client") reads as though ItemTree had looked and found nothing. The block says what is
--- actually true instead.
---
--- The sources block is the same whatever source databases are installed or switched on: the
--- owner's ruling for the first release is that it promotes no other addon (brief E1), and an
--- item with nothing known reads the same to every player.
---
--- Brief R3: the undiscovered block points at the Discoveries tab only while that tab is on.
--- discoveriesTab says whether it is; nil reads the setting (settings.showDiscoveries).
function Tree.EmptyState(view, discovery, discoveriesTab)
  if discovery == "undiscovered" then
    if discoveriesTab == nil then
      local db = ItemTree.db
      local settings = type(db) == "table" and db.settings or nil
      discoveriesTab = type(settings) == "table" and settings.showDiscoveries == true
    end
    local lines = {
      L["WoW Forever keeps an item's details on the server until it first drops."],
      L["Until then ItemTree can show its type and its icon, and nothing more."],
    }
    if discoveriesTab then
      lines[#lines + 1] = L["It will appear under Discoveries as soon as someone on your realm finds it."]
    end
    return {
      kind = "undiscovered",
      heading = L["Nobody has found this item yet"],
      lines = lines,
    }
  end
  -- Brief Q8: a quest's Quest tab with nothing in it, in the quest's own words and over the same
  -- illustration. The pane asks only for a list that is the empty row and nothing else
  -- (emptySpec, Tree.IsEmptyOnly), and the quest view holds no rows at all only where nothing is
  -- known: not in the log, no record of who gave it, no Classic Era row. So the dragon is drawn
  -- only then, which is BL9's rule: no illustration once anything is known.
  if view == "quest" then
    return {
      kind = "sources",
      heading = L["Nothing known about this quest yet"],
      lines = { L["ItemTree records who gives it and where as you play"] },
    }
  end
  if view ~= "sources" then
    return { kind = "plain" }
  end
  return {
    kind = "sources",
    heading = L["No data for this item yet"],
    -- Brief E98: no line points at the Discoveries tab, which is off by default (E96).
    lines = { L["Start exploring. Maybe you'll be the one to find it!"] },
  }
end

-- How tall a string this wide takes at a font size, reckoned rather than measured: the block is
-- laid out before a font string exists to ask, and the answer only has to be close enough to
-- place the block as though it were centred.
local function textHeight(text, fontSize, width)
  local chars = #tostring(text or "")
  local perLine = math.max(1, math.floor(width / math.max(1, fontSize * Tree.EMPTY_CHAR)))
  local lines = math.max(1, math.ceil(chars / perLine))
  return math.ceil(lines * fontSize * Theme.lineHeights.ITEMTREE_LINEHEIGHT_PROSE)
end

--- Where the designed empty state sits in a pane this size: the width every string wraps at,
--- the art box, the gaps between the pieces, the height the whole block is
--- reckoned to take and the y it starts at so it reads as centred. Nothing here touches a
--- frame, so the block is laid out and specced with no client at all. Pure.
---
--- The words come first and the picture takes what is left. A pane too short for the designed
--- spacing gives up the air between the pieces before it gives up a word, and then shrinks the
--- illustration and finally drops it, so the smallest window the player can drag the frame down
--- to still shows the heading and every line.
function Tree.EmptyBlock(width, height, spec)
  spec = type(spec) == "table" and spec or EMPTY
  height = tonumber(height) or 0
  local textWidth = Tree.EmptyWidth(width)
  local headingSize = Theme.fontSizes.ITEMTREE_FONTSIZE_TITLE_SM
  local bodySize = Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_MD
  local block = {
    width = textWidth,
    gap = Tree.EMPTY_GAP,
    lineGap = Tree.EMPTY_LINE_GAP,
    headingSize = headingSize,
    lineSize = bodySize,
  }

  -- Everything but the illustration and the gap under it, at whatever gap the block is running.
  local function bodyHeight(gap)
    local total = 0
    if spec.heading then
      total = total + textHeight(spec.heading, headingSize, textWidth) + gap
    end
    for _, line in ipairs(type(spec.lines) == "table" and spec.lines or EMPTY) do
      total = total + textHeight(line, bodySize, textWidth) + block.lineGap
    end
    return total
  end

  local body = bodyHeight(block.gap)
  if height > 0 and body + block.gap > height then
    block.gap = Tree.EMPTY_LINE_GAP
    body = bodyHeight(block.gap)
  end

  -- What is left for the picture, less a line gap at either end of the block: art grown into
  -- every last pixel leaves the block flush against the panel's own hairlines, which reads as a
  -- picture that overran rather than as an empty state.
  local artRoom = nil
  if height > 0 then
    artRoom = height - body - block.gap - 2 * Tree.EMPTY_LINE_GAP
  end
  block.artWidth, block.artHeight =
    Tree.EmptyArtSize(math.min(Tree.EMPTY_ART_W, textWidth), Tree.EmptyAspect(), artRoom)

  local total = body
  if block.artHeight > 0 then
    total = total + block.artHeight + block.gap
  end
  block.height = total
  -- Centred in the room the pane has, and never above its top edge: a block that still does not
  -- fit once the art has gone loses its bottom rather than its heading. A pane nobody has sized
  -- yet gets the padding, because it is not a short pane, it is a pane with no size to centre in.
  if height > 0 then
    block.top = math.max(0, math.floor((height - total) / 2))
  else
    block.top = Tree.EMPTY_PAD
  end
  return block
end

--- Brief E90: one coordinate the way the game's own map prints it, to one decimal: "45.2, 61.0".
--- nil for anything that is not a pair of numbers. Pure.
function Tree.CoordText(x, y)
  x, y = tonumber(x), tonumber(y)
  if not x or not y then
    return nil
  end
  return string.format("%.1f, %.1f", x, y)
end

-- Brief TV4 (the owner's ruling C2 on the tooltip audit, 2026-10-21, item 347, and his designs 3 to
-- 5): a row's hover is built in the game tooltip's own lines, a label on the left and its value on
-- the right, and a blank line where his designs draw a divider (the game tooltip has no rule of its
-- own to draw; ItemTree's block hangs its hairline on the item tooltip's hooks, which a row's lines
-- never pass through). A line is { text, right, colorKey, rightColorKey } or { text = " ", gap =
-- true }. Map spots are written in brackets, "[26.3, 93.1]" (Core/Sources.lua Sources.SpotText),
-- since a tooltip line cannot draw a chip.
Tree.TIP_BODY = "ITEMTREE_COLOR_TEXT_BODY"
Tree.TIP_MUTED = "ITEMTREE_COLOR_TEXT_MUTED"
Tree.TIP_HINT = "ITEMTREE_COLOR_TEXT_HINT"
-- Brief TV4: how many spots a zone lists before "+N more on map", how many zones a hover lists, and
-- how many spots share a line.
Tree.SPOTS_PER_ZONE = 6
Tree.SPOT_ZONES = 3
Tree.SPOTS_PER_LINE = 3
-- Brief TV4: the colour each map spot tier draws in (the owner's standing rule of 2026-10-20, memory
-- weak-indicator-map-spots): a Confirmed spot in gold, a Reported one plainly, a Weak indicator
-- dimmed, the way the Map tab draws their pins; the tier's own word leads the line.
Tree.SPOT_TIER_COLORS = {
  confirmed = "ITEMTREE_COLOR_TEXT_TITLE",
  reported = "ITEMTREE_COLOR_TEXT_BODY",
  weak = "ITEMTREE_COLOR_TEXT_HINT",
}
Tree.SPOT_TIERS = { "confirmed", "reported", "weak" }

--- Brief TV4: the word a spot tier is called by on the hover's line, or nil for a spot with none (a
--- Classic Era pin, a vendor's own place). Pure.
function Tree.SpotTierWord(tier)
  if tier == "confirmed" then
    return L["Confirmed"]
  end
  if tier == "reported" then
    return L["Reported"]
  end
  if tier == "weak" then
    return L["Weak indicator"]
  end
  return nil
end

--- Brief TV4: a decoded pin list grouped by zone for a row's hover: { { areaId, zone, points = { {
--- x, y, tier } }, more }, ..., zonesMore = n }. pins are { area or map, x, y, zone, spot, weak,
--- confirmed } (E:PinsOf's, or the Map tab's hand kept spots). home is the area id the row stands
--- for, listed first where it holds a pin; the rest follow by how many pins each holds, the first
--- met winning a tie. nameOf(area) names a zone a pin does not. perZone (Tree.SPOTS_PER_ZONE) caps
--- the spots each zone lists, more counts the rest, and maxZones (Tree.SPOT_ZONES) the zones, with
--- zonesMore the rest. A hand kept spot's tier is "confirmed", "weak" or "reported". nil for no pin.
--- Pure over what it is handed.
function Tree.PlaceGroups(pins, home, nameOf, perZone, maxZones)
  if type(pins) ~= "table" then
    return nil
  end
  perZone = tonumber(perZone) or Tree.SPOTS_PER_ZONE
  maxZones = tonumber(maxZones) or Tree.SPOT_ZONES
  local order, byArea = {}, {}
  for _, pin in ipairs(pins) do
    local area = type(pin) == "table" and (pin.area or pin.map) or nil
    local x, y = type(pin) == "table" and tonumber(pin.x) or nil, type(pin) == "table" and tonumber(pin.y) or nil
    if area ~= nil and x and y then
      local group = byArea[area]
      if not group then
        group = { areaId = area, count = 0, points = {}, first = #order + 1 }
        byArea[area] = group
        order[#order + 1] = group
      end
      if not group.zone and type(pin.zone) == "string" and pin.zone ~= "" then
        group.zone = pin.zone
      end
      group.count = group.count + 1
      if #group.points < perZone then
        local tier = nil
        if pin.confirmed then
          tier = "confirmed"
        elseif pin.weak then
          tier = "weak"
        elseif pin.spot then
          tier = "reported"
        end
        group.points[#group.points + 1] = { x = x, y = y, tier = tier }
      end
    end
  end
  if #order == 0 then
    return nil
  end
  table.sort(order, function(a, b)
    if (a.areaId == home) ~= (b.areaId == home) then
      return a.areaId == home
    end
    if a.count ~= b.count then
      return a.count > b.count
    end
    return a.first < b.first
  end)
  local out = {}
  for index, group in ipairs(order) do
    if index <= maxZones then
      if not group.zone and type(nameOf) == "function" then
        local ok, name = pcall(nameOf, group.areaId)
        group.zone = ok and type(name) == "string" and name ~= "" and name or nil
      end
      out[#out + 1] =
        { areaId = group.areaId, zone = group.zone, points = group.points, more = group.count - #group.points }
    end
  end
  out.zonesMore = #order - #out
  return out
end

--- Brief TV4 (design 3: Hogger with one spot, many, and two zones): the "Known location" lines of a
--- row's hover out of Tree.PlaceGroups' answer. One spot in all is one line, "Known location
--- [26.3, 93.1]". More is a heading, "Known locations", then each zone's name where there are
--- several, its spots Tree.SPOTS_PER_LINE to a line, and "+23 more on map" after the last. A spot
--- in another zone than home (the row's own zone words) names its zone, "[Stormwind: 42.1, 65.8]",
--- where no zone heading does. A hand kept spot's tier stays visible in words: its spots go on
--- lines led by the tier ("Confirmed", "Reported", "Weak indicator"), in the tier's colour
--- (Tree.SPOT_TIER_COLORS). An empty list for nothing to say. Pure.
function Tree.KnownLocationLines(groups, home)
  local lines = {}
  local shown = {}
  for _, group in ipairs(type(groups) == "table" and groups or EMPTY) do
    if type(group) == "table" and type(group.points) == "table" and #group.points > 0 then
      shown[#shown + 1] = group
    end
  end
  if #shown == 0 then
    return lines
  end
  local Sources = ItemTree.Sources
  local function spot(point, zone)
    if type(Sources) ~= "table" or type(Sources.SpotText) ~= "function" then
      return Tree.CoordText(point.x, point.y)
    end
    return Sources.SpotText(zone, point.x, point.y, home)
  end
  local several = #shown > 1
  local first = shown[1]
  local more = math.floor(tonumber(first.more) or 0)
  if not several and #first.points == 1 and more <= 0 and first.points[1].tier == nil then
    lines[1] = {
      text = L["Known location"],
      right = spot(first.points[1], first.zone),
      colorKey = Tree.TIP_BODY,
      rightColorKey = Tree.TIP_MUTED,
    }
    return lines
  end
  lines[1] = { text = L["Known locations"], colorKey = Tree.TIP_BODY }
  for _, group in ipairs(shown) do
    -- Under a zone heading the spots need no zone of their own; alone, one in another zone says it.
    local zone = group.zone
    if several then
      lines[#lines + 1] = { text = group.zone or "", colorKey = Tree.TIP_MUTED }
      zone = home
    end
    local runs, plain = {}, {}
    for _, point in ipairs(group.points) do
      local text = spot(point, zone)
      if text then
        if point.tier then
          runs[point.tier] = runs[point.tier] or {}
          table.insert(runs[point.tier], text)
        else
          plain[#plain + 1] = text
        end
      end
    end
    local left = math.floor(tonumber(group.more) or 0)
    local tail = left > 0 and string.format(L["+%d more on map"], left) or nil
    local function chunk(list, label, colorKey, last)
      local at = 1
      if last and tail then
        list[#list + 1] = tail
      end
      while at <= #list do
        local words = table.concat(list, "  ", at, math.min(#list, at + Tree.SPOTS_PER_LINE - 1))
        if label ~= nil then
          lines[#lines + 1] = {
            text = at == 1 and label or "",
            right = words,
            colorKey = Tree.TIP_MUTED,
            rightColorKey = colorKey,
          }
        else
          lines[#lines + 1] = { text = words, colorKey = colorKey }
        end
        at = at + Tree.SPOTS_PER_LINE
      end
    end
    local tiers = {}
    for _, tier in ipairs(Tree.SPOT_TIERS) do
      if runs[tier] then
        tiers[#tiers + 1] = tier
      end
    end
    chunk(plain, nil, Tree.TIP_MUTED, #tiers == 0)
    for index, tier in ipairs(tiers) do
      chunk(runs[tier], Tree.SpotTierWord(tier), Tree.SPOT_TIER_COLORS[tier], index == #tiers)
    end
  end
  return lines
end

--- Brief TV4 (designs 3 to 5): a source row's own part of its hover, as tooltip lines, out of the
--- row and the place groups Tree.RowPlaceGroups found for it (nil for none):
---
---   Side             the side the NPC serves, with its icon (brief P6b), then the side notes
---   Zone             the row's zone, and every other zone its spots stand in, joined
---   Known location   the spots (Tree.KnownLocationLines)
---   Type             the creature's kind with its level in brackets, "Humanoid (7 - 8)"
---   Source           what kind of source it is, for every kind but a drop: "Recipe (Engineering
---                    285)", "Vendor", "Skinned"
---   Quest only drop  the quest it only drops on, then any other qualifier ("limited stock 5")
---   Price            a vendor's price
---   Drop chance      "50%", or "33.3% (Classic Era)" on a Classic Era row
---   Classic Era drop rate   "~100%", on a live row that took a Classic Era row's place (brief B7)
---   the guess's words, and where the row came from (a provider, client data)
---   blank, then Player sightings N, the collector's tally
---
--- Ruling B2: no Predicted words and no "From Classic Era" line here; the drop chance keeps
--- "(Classic Era)". "Map: click the zone" is gone (the zone column's own hover still says where a
--- click goes). A player sourced row's "Reported by players" stays only where it shows no
--- sightings count. An empty list for a row that carries no source. Pure over the row, the groups
--- and the tables Tree.RowSide reads.
function Tree.SourceTipLines(row, groups)
  local lines = {}
  local source = Tree.SourceText(row)
  if not source then
    return lines
  end
  local raw = row.source
  local edge = type(row.edge) == "table" and row.edge or EMPTY
  local Sources, Confidence = ItemTree.Sources, ItemTree.Confidence
  local function call(module, name, ...)
    if type(module) ~= "table" or type(module[name]) ~= "function" then
      return nil
    end
    local ok, a, b, c = pcall(module[name], ...)
    if not ok then
      return nil
    end
    return a, b, c
  end
  local main, tail = {}, {}
  local function pair(list, label, value)
    if type(value) == "string" and value ~= "" then
      list[#list + 1] = { text = label, right = value, colorKey = Tree.TIP_BODY, rightColorKey = Tree.TIP_MUTED }
    end
  end
  local function single(list, text, colorKey)
    if type(text) == "string" and text ~= "" then
      list[#list + 1] = { text = text, colorKey = colorKey or Tree.TIP_MUTED }
    end
  end

  -- Brief P6b: the side, with the icon the row's zone column wears.
  local side = Tree.RowSide(row)
  local sideWord = Tree.SideText(side)
  if sideWord then
    local key = type(Assets.SIDES) == "table" and Assets.SIDES[side] or nil
    local ok, markup = false, nil
    if key and type(Assets.Markup) == "function" then
      ok, markup = pcall(Assets.Markup, key, Tree.TIP_ICON)
    end
    if ok and type(markup) == "string" and markup ~= "" then
      sideWord = markup .. " " .. sideWord
    end
    pair(main, L["Side"], sideWord)
  end
  single(main, Tree.FactionOnlyText(row))
  single(main, Tree.SeenSideText(row))

  -- The row's own zone words, where they name a place: a gathering node's count ("4 zones") and
  -- the side word a Classic Era vendor or quest with no area keeps in the slot (Core/EraSources.lua
  -- questRow) are no zone.
  local home = source.zone
  if home == "" or row.gatherNode or home == L["Alliance"] or home == L["Horde"] then
    home = nil
  end
  local zones, named = {}, {}
  local function addZone(zone)
    if type(zone) == "string" and zone ~= "" and not named[zone] then
      named[zone] = true
      zones[#zones + 1] = zone
    end
  end
  addZone(home)
  for _, group in ipairs(type(groups) == "table" and groups or EMPTY) do
    if type(group) == "table" then
      addZone(group.zone)
    end
  end
  local zoneText = table.concat(zones, ", ")
  local zonesMore = type(groups) == "table" and math.floor(tonumber(groups.zonesMore) or 0) or 0
  if zoneText ~= "" and zonesMore > 0 then
    zoneText = string.format(L["%s and %d more"], zoneText, zonesMore)
  end
  if zoneText == "" and row.gatherNode then
    zoneText = source.zone
  end
  pair(main, L["Zone"], zoneText)
  -- A row whose words name no zone reads its spots against the zone the Zone line just named.
  if not home and type(groups) == "table" and type(groups[1]) == "table" then
    home = groups[1].zone
  end
  for _, line in ipairs(Tree.KnownLocationLines(groups, home)) do
    main[#main + 1] = line
  end
  pair(main, L["Type"], (call(Sources, "KindLevelText", edge.creature)))

  -- What kind of source, for every kind but a drop: the chance line says that one. A recipe's or
  -- a key's skill, and a quest's count, is the qualifier on it: "Recipe (Engineering 285)".
  local column = type(raw) == "table" and raw.type or nil
  local percent = type(raw) == "table" and tonumber(raw.percent) or nil
  if column ~= "Drop" and source.type ~= "" then
    local value = source.type
    if not source.guess and not percent and not source.eraRateInColumn and column ~= "Vendor" then
      value = call(Sources, "Qualified", value, source.rate) or value
    end
    pair(main, L["Source"], value)
  end
  -- Brief TV4 (design 5): the quest it only drops on, before the rates, then any other qualifier.
  local only, title, rest = call(Sources, "SplitQuestNote", source.note)
  if only then
    if title then
      pair(main, L["Quest only drop"], title)
    else
      single(main, L["Quest only drop"], Tree.TIP_BODY)
    end
    single(main, rest)
  else
    single(main, source.note)
  end
  if not source.guess then
    if column == "Vendor" then
      pair(main, L["Price"], source.price ~= "" and source.price or source.rate)
    elseif percent then
      local chance = source.rate
      if source.historical then
        local figure = call(Confidence, "Chance", percent)
        if figure then
          chance = string.format(L["%s (Classic Era)"], figure)
        end
      end
      pair(main, L["Drop chance"], chance)
    end
    -- Brief B7: the Classic Era rate of the row this live row took the place of: the figure the
    -- rate column borrowed (brief BQ10), else the edge's own, else the line Core worded.
    if not source.historical and source.eraRate ~= "" then
      local figure = nil
      if source.eraRateInColumn and source.rate ~= "" then
        figure = source.rate
      elseif tonumber(edge.eraRate) then
        local chance = call(Confidence, "Chance", tonumber(edge.eraRate))
        figure = chance and (call(Confidence, "Historical", chance) or chance) or nil
      end
      if figure then
        pair(main, L["Classic Era drop rate"], figure)
      else
        single(main, source.eraRate)
      end
    end
  end

  if source.guess then
    -- Brief GS3: how strong the guess is and why, then its last word.
    single(main, source.guessStrength)
    single(main, source.guessWhy)
    single(main, source.guessLine)
  end
  local seen = type(raw) == "table" and tonumber(raw.seen) or nil
  if seen and seen <= 0 then
    seen = nil
  end
  local playerRow = type(raw) == "table" and Tree.TOOLTIP_ONLY_PROVENANCE[raw.provenance] or false
  if not source.guess and not source.historical and not (playerRow and seen) then
    single(main, source.provenance)
  end
  if seen then
    pair(tail, L["Player sightings"], tostring(math.floor(seen)))
  end

  for _, line in ipairs(main) do
    lines[#lines + 1] = line
  end
  if #tail > 0 then
    if #lines > 0 then
      lines[#lines + 1] = { text = " ", gap = true, colorKey = Tree.TIP_BODY }
    end
    for _, line in ipairs(tail) do
      lines[#lines + 1] = line
    end
  end
  return lines
end

-- Brief TV4: the size of an icon inside a hover's line (the side's), the size the info column's
-- quest card draws its item icons at (UI/InfoPanel.lua InfoPanel.CARD_ICON).
Tree.TIP_ICON = 14

--- Brief TV4 (design 4, Razormane Scout): the muted line a creature's row hover ends on where a
--- click on its name opens the creature's page, "Click the creature name to see more info". nil
--- for every other row: one that opens something else, or nothing (Tree.Interpret). Pure.
function Tree.CreatureFooter(row)
  local action, key = Tree.Interpret(row, { column = "name" })
  if action ~= "reroot" or type(key) ~= "string" then
    return nil
  end
  local graph = ItemTree.Graph
  if type(graph) ~= "table" or type(graph.Parse) ~= "function" then
    return nil
  end
  local ok, kind = pcall(graph.Parse, key)
  if ok and kind == "npc" then
    return L["Click the creature name to see more info"]
  end
  return nil
end

--- Brief PR29: whether a category header draws the "Show nearest" button: a "Sold by" group (brief
--- PR34: or a "Trainer" group) with at least one NPC whose place our data holds (Core/Nearest.lua
--- Nearest.Shows, which decodes nothing for the group's own NPCs and keeps its answer per group).
--- Guarded: no Nearest, no.
function Tree.NearestShows(row)
  local Nearest = ItemTree.Nearest
  if type(Nearest) ~= "table" or type(Nearest.GroupKind) ~= "function" or type(Nearest.Shows) ~= "function" then
    return false
  end
  if Nearest.GroupKind(row) == nil then
    return false
  end
  local ok, shows = pcall(Nearest.Shows, row.category, Tree.VisibleEntries)
  return ok and shows == true
end

--- Brief PR29: the entries of a group the view model shows (its own filter), or the entries as they
--- are where there is no view model.
function Tree.VisibleEntries(entries)
  local vm = Tree.vm
  if type(vm) == "table" and type(vm._VisibleEntries) == "function" then
    local ok, shown = pcall(vm._VisibleEntries, vm, entries)
    if ok and type(shown) == "table" then
      return shown
    end
  end
  return entries
end

--- Brief PR29: the button's width at a font size: its words measured (measured, where the client
--- measured them) or estimated at the count column's character width, plus NEAREST_PAD each side.
--- Pure.
function Tree.NearestWidth(fontSize, measured)
  local words = tonumber(measured)
  if not words or words <= 0 then
    local text = L["Show nearest"]
    words = string.len(text) * (tonumber(fontSize) or 10) * Tree.COUNT_CHAR
  end
  return math.ceil(words + 2 * Tree.NEAREST_PAD)
end

-- Brief Q9b: the category tooltip's count line. The rows the category draws before its cap
-- ("32 rows in this category"), and where the category holds fewer sources than it draws rows
-- (a shipped summary stands for its whole list) both numbers: "4 sources, 32 rows". Pure.
function Tree.CategoryCountText(row)
  local count = math.floor(tonumber(type(row) == "table" and row.count) or 0)
  local sources = math.floor(tonumber(type(row) == "table" and row.sources) or count)
  if sources ~= count then
    local left = sources == 1 and L["1 source"] or string.format(L["%d sources"], sources)
    local right = count == 1 and L["1 row"] or string.format(L["%d rows"], count)
    return string.format(L["%s, %s"], left, right)
  end
  local template = count == 1 and L["%d row in this category"] or L["%d rows in this category"]
  return string.format(template, count)
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- Brief P5b: a class spell's own icon, by spell id, or nil. C_Spell.GetSpellTexture is the newer
-- engine's call and GetSpellTexture the older one's, each pcalled. A spell lookup and never an item
-- query, asked only for a row being drawn, and the answer (none included) is kept for the session.
local spellTextures = {}

function Tree.SpellTexture(spellId)
  spellId = tonumber(spellId)
  if not spellId then
    return nil
  end
  local held = spellTextures[spellId]
  if held ~= nil then
    return held or nil
  end
  local texture = nil
  local spellApi = rawget(_G, "C_Spell")
  if type(spellApi) == "table" and type(spellApi.GetSpellTexture) == "function" then
    local ok, answer = pcall(spellApi.GetSpellTexture, spellId)
    if ok and answer ~= nil and answer ~= "" and answer ~= 0 then
      texture = answer
    end
  end
  if texture == nil then
    local older = rawget(_G, "GetSpellTexture")
    if type(older) == "function" then
      local ok, answer = pcall(older, spellId)
      if ok and answer ~= nil and answer ~= "" and answer ~= 0 then
        texture = answer
      end
    end
  end
  spellTextures[spellId] = texture or false
  return texture
end

-- For a spec: forget every spell icon the session has kept.
function Tree.ResetSpellTextures()
  spellTextures = {}
end

-- Brief CT1: whether the character knows a spell, asked for a class trainer's spell row as it is
-- drawn and for that row alone (never a pass over a trainer's list, and nothing kept, so a spell
-- learnt a moment ago reads learnt on the next draw). C_SpellBook.IsSpellKnown is the Forever
-- client's call (Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua:738, forever branch
-- at 1.60.1.70245), IsPlayerSpell and IsSpellKnown the older ones (bible B11): the first a client has
-- answers, each pcalled, and an answer the client keeps secret (Util.CanRead, bible B10) reads as
-- not known. A read of the spell book, never a protected call.
function Tree.SpellKnown(spellId)
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
  local util = ItemTree.Util
  local canRead = type(util) == "table" and util.CanRead or nil
  for _, fn in ipairs(calls) do
    local ok, known = pcall(fn, spellId)
    if ok then
      -- Asked before the answer is compared with anything at all.
      if type(canRead) == "function" and not canRead(known) then
        return false
      end
      if known ~= nil then
        return known == true
      end
    end
  end
  return false
end

-- Brief PL1 (QA item 288): whether the summoned pet's spell book knows a spell, asked for a pet
-- trainer's row as it is drawn and for that row alone, as Tree.SpellKnown asks the character's.
-- C_SpellBook.IsSpellKnown with the pet's bank is the Forever client's call (forever branch at
-- 1.60.1.70450: Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua:738, its spellBank
-- argument :746; SpellBookConstantsDocumentation.lua:43, Enum.SpellBookSpellBank.Pet), and
-- IsSpellKnown(spellId, true) the older shape (Blizzard_DeprecatedSpellBook/Deprecated_SpellBook.lua:16
-- keeps it). The first a client has answers, each pcalled, and an answer the client keeps secret
-- (Util.CanRead, bible B10) reads as not known. A read of the spell book, never a server query.
function Tree.PetSpellKnown(spellId)
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
  local util = ItemTree.Util
  local canRead = type(util) == "table" and util.CanRead or nil
  for _, call in ipairs(calls) do
    local ok, known = pcall(call)
    if ok then
      -- Asked before the answer is compared with anything at all.
      if type(canRead) == "function" and not canRead(known) then
        return false
      end
      if known ~= nil then
        return known == true
      end
    end
  end
  return false
end

-- Brief PL1: the pet trainers' list's ranks, { [spellId] = rank } (Core/PlayerSources.lua
-- PlayerSources.PetList), kept per list. A read of our own data, no client call.
local petRanks = { list = nil, ranks = EMPTY }

local function petTrainerRanks()
  local reader = ItemTree.PlayerSources
  if type(reader) ~= "table" or type(reader.Table) ~= "function" or type(reader.PetList) ~= "function" then
    return EMPTY
  end
  local ok, source = pcall(reader.Table)
  if not ok or type(source) ~= "table" then
    return EMPTY
  end
  local found, list = pcall(reader.PetList, source)
  if not found or type(list) ~= "table" or type(list.spells) ~= "table" then
    return EMPTY
  end
  if petRanks.list ~= list then
    local ranks = {}
    for _, spell in ipairs(list.spells) do
      if type(spell) == "table" and tonumber(spell.spell) then
        ranks[tonumber(spell.spell)] = tonumber(spell.rank) or 0
      end
    end
    petRanks.list, petRanks.ranks = list, ranks
  end
  return petRanks.ranks
end

-- A spell's name as every row's is read (Graph.Name, the client's own word for it), or nil.
local function spellName(spellId)
  local Graph = ItemTree.Graph
  if type(Graph) ~= "table" or type(Graph.Name) ~= "function" or type(Graph.Key) ~= "function" then
    return nil
  end
  local ok, name = pcall(function()
    return Graph.Name(Graph.Key("spell", spellId))
  end)
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- Brief PL1: what the hunter's pets know, out of the client's own pet lists: C_StableInfo's
-- GetActivePetList and GetStabledPetList (forever branch at 1.60.1.70450:
-- Blizzard_APIDocumentationGenerated/StableInfoDocumentation.lua:19 and :103), whose PetInfo carries
-- petAbilities, the spell ids the pet knows (:226; the retail stable window reads them so,
-- Blizzard_StableUI/Standard/Blizzard_StableUI.lua:1170). Both answer away from a stable master (the
-- owner's pet probe, 2026-10-02: a level 9 pet listed 16). Two reads of what the client already
-- holds, never a server query and never a pass of queries over a list, kept PET_ABILITIES_SECONDS
-- so a page of rows reads the lists once, and read afresh after that, so a pet trained a moment
-- ago reads learnt on a later draw. Tree.PetAbilitiesKnown's shape.
Tree.PET_ABILITIES_SECONDS = 2
local petAbilities = { known = nil, at = nil }

-- For a spec: forget the pets' abilities read last.
function Tree.ResetPetAbilities()
  petAbilities = { known = nil, at = nil }
  petRanks = { list = nil, ranks = EMPTY }
end

-- The client's clock in seconds (GetTime), or nil where it will not say.
local function clockNow()
  local getTime = rawget(_G, "GetTime")
  if type(getTime) ~= "function" then
    return nil
  end
  local ok, now = pcall(getTime)
  if ok and type(now) == "number" then
    return now
  end
  return nil
end

function Tree.PetAbilities()
  local now = clockNow()
  local at = petAbilities.at
  if petAbilities.known and now and at and now >= at and now - at < Tree.PET_ABILITIES_SECONDS then
    return petAbilities.known
  end
  local util = ItemTree.Util
  local canRead = type(util) == "table" and util.CanRead or nil
  local pets = {}
  local api = rawget(_G, "C_StableInfo")
  if type(api) == "table" then
    for _, name in ipairs({ "GetActivePetList", "GetStabledPetList" }) do
      local fn = api[name]
      if type(fn) == "function" then
        local ok, list = pcall(fn)
        if ok and (type(canRead) ~= "function" or canRead(list)) and type(list) == "table" then
          for _, pet in ipairs(list) do
            pets[#pets + 1] = pet
          end
        end
      end
    end
  end
  local known = Tree.PetAbilitiesKnown(pets, petTrainerRanks(), spellName, canRead)
  petAbilities = { known = known, at = now }
  return known
end

--- Brief PL1 (QA item 288): whether a pet trainer's row (spell, Tree.TrainerSpell's answer) reads
--- Learnt. The hunter knows that rank (Tree.SpellKnown, the read a class trainer's row makes: a pet
--- trainer teaches the hunter, and the client reports its window as a general trainer's, QA item
--- 265), the summoned pet knows it (Tree.PetSpellKnown), or a pet in the client's pet lists knows it
--- or a higher rank of it (Tree.PetAbilities, Tree.PetRowKnown). Reads only; false where none says.
function Tree.PetTrainerLearnt(spell)
  if type(spell) ~= "table" or not tonumber(spell.spellId) then
    return false
  end
  if Tree.SpellKnown(spell.spellId) then
    return true
  end
  if Tree.PetSpellKnown(spell.spellId) then
    return true
  end
  return Tree.PetRowKnown(Tree.PetAbilities(), spell, spellName) == true
end

-- Brief P5b: the client's colour for a class, as the "ffrrggbb" an escape sequence takes, or nil.
-- RAID_CLASS_COLORS is the table every client has; C_ClassColor the newer engine's call.
function Tree.ClassColor(token)
  if type(token) ~= "string" then
    return nil
  end
  local colors = rawget(_G, "RAID_CLASS_COLORS")
  local color = type(colors) == "table" and colors[token] or nil
  if type(color) ~= "table" then
    local api = rawget(_G, "C_ClassColor")
    if type(api) == "table" and type(api.GetClassColor) == "function" then
      local ok, answer = pcall(api.GetClassColor, token)
      if ok and type(answer) == "table" then
        color = answer
      end
    end
  end
  if type(color) ~= "table" then
    return nil
  end
  if type(color.colorStr) == "string" and #color.colorStr == 8 then
    return color.colorStr
  end
  local r, g, b = tonumber(color.r), tonumber(color.g), tonumber(color.b)
  if not (r and g and b) then
    return nil
  end
  local function byte(value)
    return math.max(0, math.min(255, math.floor(value * 255 + 0.5)))
  end
  return string.format("ff%02x%02x%02x", byte(r), byte(g), byte(b))
end

local globalFn = ItemTree.Util.GlobalFn

-- One interface cue, by name. UI/Sound.lua owns which sound a cue is and whether cues are on at
-- all; this is the one line a call site writes. Looked up at call time, because a spec loads this
-- file on its own and a build without the module must cost the cue and nothing else.
local playCue = ItemTree.UI.Sound.PlayCue

-- One CreateFrame call, pcall'd. A client that does not carry the template still gets a plain
-- frame; a client with no CreateFrame at all gets nothing, which is what leaves Attach
-- returning false under busted.
local function newFrame(kind, parent, template)
  local create = globalFn("CreateFrame")
  if not create then
    return nil
  end
  if template then
    local ok, frame = pcall(create, kind, nil, parent, template)
    if ok and frame then
      return frame
    end
  end
  local ok, frame = pcall(create, kind, nil, parent)
  if ok and frame then
    return frame
  end
  return nil
end

-- A frame that must carry its template, with no plain fallback. A ScrollBox whose template
-- the client does not have is not a ScrollBox, so the pane wants the pool instead.
local function newTemplatedFrame(kind, parent, template)
  local create = globalFn("CreateFrame")
  if not create then
    return nil
  end
  local ok, frame = pcall(create, kind, nil, parent, template)
  if ok and frame then
    return frame
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

-- Hands the font string one of the client's own font objects. Nothing here can raise, and a
-- client carrying none of them answers false, which is as far as this file can go.
local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(Tree.FONT_FALLBACKS) do
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
-- through the template argument where the client takes one and by hand where it does not, so a
-- SetText is never the first thing to touch the font.
local function newFontString(parent, layer)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, layer, Tree.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, layer)
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  return fontString
end

-- The Theme face at a size, over whatever font the string already has. SetFont answers false
-- rather than raising where the client cannot load the face, so the answer is read and a font
-- object put back: a font string that lost its font raises from inside the next SetText. The
-- body face is what a row wants; a caller after the title face (the empty state's heading)
-- names it instead.
local function setFont(fontString, size, face)
  if type(fontString) ~= "table" then
    return false
  end
  if type(fontString.SetFont) == "function" then
    local ok, applied = pcall(fontString.SetFont, fontString, face or Theme.fonts.ITEMTREE_FONT_BODY, size, "")
    if not ok or applied == false then
      fallbackFont(fontString)
    end
  end
  ensureFont(fontString)
  if type(fontString.SetShadowOffset) == "function" then
    local outline = Theme.text.ITEMTREE_TEXT_OUTLINE
    fontString:SetShadowOffset(outline.x, outline.y)
    fontString:SetShadowColor(outline.r, outline.g, outline.b, outline.a)
  end
  return true
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

-- Places a region in one of the layout's columns, or hides it when this kind has no such
-- column. A filling column carries both edges, so the region stretches between them.
local function place(frame, region, layout, name, height)
  if not region then
    return false
  end
  local column = layout.columns[name]
  if not column then
    region:Hide()
    return false
  end
  region:ClearAllPoints()
  if column.fill then
    region:SetPoint("LEFT", frame, "LEFT", column.x, 0)
    region:SetPoint("RIGHT", frame, "RIGHT", -column.right, 0)
  elseif column.right then
    region:SetPoint("RIGHT", frame, "RIGHT", -column.right, 0)
    region:SetWidth(column.width)
  else
    region:SetPoint("LEFT", frame, "LEFT", column.x, 0)
    region:SetWidth(column.width)
  end
  if height then
    region:SetHeight(height)
  end
  region:Show()
  return true
end

local function frameModule()
  local ui = ItemTree.UI
  local frame = type(ui) == "table" and ui.Frame or nil
  return type(frame) == "table" and frame or nil
end

-- The window owns the view model and the redraw, so the pane hands every mutation back and
-- redraws nothing itself. Looked up lazily, because UI/Frame.lua loads before this file but
-- only fills itself in later.
local function askFrameToRefresh()
  local frame = frameModule()
  if frame and type(frame.Refresh) == "function" then
    frame.Refresh()
    return true
  end
  return false
end

local function askFrameToOpen(nodeKey, opts)
  local frame = frameModule()
  if frame and type(frame.Open) == "function" then
    if type(opts) == "table" then
      frame.Open(nodeKey, opts)
    else
      frame.Open(nodeKey)
    end
    return true
  end
  return false
end

--- Brief BQ24 (owner QA 2026-10-10 item 25, "trainers should always open to map tab"): whether a
--- row is an NPC under a Sources view's "Trainer" group (its key cat:trainer/npc:...), whose page
--- then opens on its Map tab. Pure.
function Tree.IsTrainerRow(row)
  if type(row) ~= "table" or (row.kind or "row") ~= "row" or type(row.key) ~= "string" then
    return false
  end
  return row.key:match("^cat:trainer/npc:[^/]+$") ~= nil
end

-- Applies one of Interpret's answers. Toggle and ShowMore change the view model and then ask
-- the window to refresh; re-rooting is the window's job entirely.
local function perform(action, key, extra)
  local vm = Tree.vm
  -- E39: one small click for the actions the pane carries out itself.
  local cued = action == "toggle" or action == "more" or action == "strip" or action == "reroot"
  if cued or action == "pick" or action == "placed" or action == "source" then
    playCue("click")
  end
  if action == "toggle" then
    if vm and type(vm.Toggle) == "function" then
      vm:Toggle(key)
    end
    askFrameToRefresh()
    return true
  end
  if action == "more" then
    if vm and type(vm.ShowMore) == "function" then
      vm:ShowMore(key)
    end
    askFrameToRefresh()
    return true
  end
  -- E25: the strip is the pane's own state. The view model is untouched, so the pane redraws
  -- itself rather than asking the window to rebuild anything.
  if action == "strip" then
    return Tree.ToggleStrip(key)
  end
  if action == "reroot" then
    -- Brief BQ24: extra is Frame.Open's opts where the click handed one ({ trainer = true }).
    return askFrameToOpen(key, extra)
  end
  if action == "pick" then
    return Tree.PickZoneRow(key)
  end
  if action == "placed" then
    return Tree.OpenPlaced(key, extra)
  end
  if action == "source" then
    return Tree.OpenZoneSource(extra)
  end
  return false
end

--- Brief M15: opens a zone's page on its Map view with one item picked in the item column
--- (Core/ViewModel.lua ViewModel.ArriveOnZoneItem, taken by the column's next draw). Both calls are
--- looked up at call time and pcall'd. Answers whether the window took the key.
function Tree.OpenPlaced(zoneKey, itemKey)
  local frame = frameModule()
  if type(zoneKey) ~= "string" or not frame or type(frame.Open) ~= "function" then
    return false
  end
  local ViewModel = ItemTree.ViewModel
  if type(itemKey) == "string" and type(ViewModel) == "table" and type(ViewModel.ArriveOnZoneItem) == "function" then
    pcall(ViewModel.ArriveOnZoneItem, zoneKey, itemKey)
  end
  local Edges = ItemTree.Edges
  local view = type(Edges) == "table" and Edges.MAP or "map"
  local ok, opened = pcall(frame.Open, zoneKey, { view = view })
  return ok and opened ~= false
end

--- EXPERIMENTAL (brief E25). Opens or closes the strip of ingredient icons under one craft row
--- and redraws. The open strips are the pane's own, keyed by row key, so they survive a refresh
--- and a re-root brings back whatever was open for those very rows. Returns whether the strip is
--- now open.
function Tree.ToggleStrip(rowKey)
  if type(rowKey) ~= "string" then
    return false
  end
  Tree.strips = Tree.strips or {}
  local open = Tree.strips[rowKey] ~= true
  if open then
    Tree.strips[rowKey] = true
  else
    Tree.strips[rowKey] = nil
  end
  if Tree.pane then
    Tree.Draw()
  end
  return open
end

--- Whether a row's strip is open right now. The reader for the writer above, so a caller never
--- has to reach into the table.
function Tree.StripOpen(rowKey)
  return type(Tree.strips) == "table" and Tree.strips[rowKey] == true
end

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

--- The item a row's tooltip describes, or nil when there is no item behind it. An item row is
--- itself; a recipe stands for the item it makes, which is the one the player wants to read.
function Tree.TooltipItemId(row)
  local node = type(row) == "table" and row.node or nil
  if type(node) ~= "table" then
    return nil
  end
  if node.kind == "item" then
    return tonumber(node.id)
  end
  if node.kind == "spell" then
    return tonumber(node.outputItem)
  end
  return nil
end

-- The client's own tooltip for an item, which ItemTree's tooltip hook then appends its block
-- to, so the player gets both. SetItemByID is the modern call and the item link is the older
-- one; a client that carries neither leaves this to the info panel's lines.
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
-- guarded: UI/InfoPanel.lua loads after this file and may not carry TooltipLines yet.
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
  -- Brief TV4: label and value pairs with the value in its own colour, blank lines between parts.
  Tree.DrawTipLines(tooltip, lines)
  return true
end

-- The row's own name, in its quality colour. The info panel writes the block under a name and
-- never the name itself, so this is the pane's line either way.
local function addNodeTitle(tooltip, row)
  local node = type(row.node) == "table" and row.node or nil
  -- E81: the whole of it, effect included and plain, in the name's own colour.
  local name = (Tree.RowText(node, { text = row.text }))
  if type(name) ~= "string" or name == "" or type(tooltip.AddLine) ~= "function" then
    return false
  end
  tooltip:AddLine(name, tooltipColor(nameColorFor(node)))
  return true
end

-- What a row with no record behind it can still say: its meta, how many of it and its marks.
-- A requirement and a recipe this build has no output item for both land here.
local function addNodeFacts(tooltip, row)
  local node = type(row.node) == "table" and row.node or nil
  if not node or type(tooltip.AddLine) ~= "function" then
    return false
  end
  -- Brief TV4: a source row's meta ("Hogger, Elwynn Forest", "33.3%") and count are what its
  -- source lines say in full (Tree.SourceTipLines), so they are not said twice.
  if type(row.source) ~= "table" then
    mutedLine(tooltip, node.meta)
    local quantity = quantityText(node)
    if quantity ~= "" then
      mutedLine(tooltip, quantity)
    end
  end
  for _, badge in ipairs(Badges.Sort(node.badges, Tree.BADGE_MAX_ROW)) do
    -- Brief TV4 (ruling B2): the inner tooltips say no "Marked Predicted"; the badge says it.
    if badge ~= "predicted" then
      mutedLine(tooltip, string.format(L["Marked %s"], Badges.Label(badge) or badge))
    end
  end
  return true
end

-- What the corner glyph says in words, so a row that is a recipe rather than the item it makes
-- says so rather than leaving the player to read a 12px glyph. Brief TV4: a recipe's source row
-- says it on its Source line ("Recipe (Engineering 285)"), so the mark's line is not drawn there.
local function addMarkLine(tooltip, row)
  local source = type(row.source) == "table" and row.source or nil
  if source and source.type == "Recipe" then
    return false
  end
  return mutedLine(tooltip, Tree.MarkLabel(row))
end

-- What a merged craft row knows that the item's own tooltip cannot say: how many one craft
-- makes, and the recipe item that teaches it, by name. The second is what the mark in the
-- corner of the icon means, so the glyph never has to carry the fact on its own.
local function addCraftLines(tooltip, row)
  if type(row.craft) ~= "table" or type(tooltip.AddLine) ~= "function" then
    return false
  end
  local drawn = mutedLine(tooltip, Tree.YieldLabel(row.craft))
  for _, line in ipairs(Tree.RecipeLabels(row.craft)) do
    if mutedLine(tooltip, line) then
      drawn = true
    end
  end
  return drawn
end

-- EXPERIMENTAL (brief E25). The Ingredients block on a craft row's tooltip: the heading, one
-- line per reagent in its own quality colour, and the tools line where the recipe asks for any.
--
-- Not gated on the mode itself (brief E30): the strip's own button draws this block as its hover,
-- and that button only exists in a mode that asked for the strip. The row's tooltip asks
-- Tree.CraftShows("tooltip") at its call site, which is the live setting rather than what the
-- row was built under, so a mode change is right on the very next hover.
local function addIngredientLines(tooltip, row)
  if type(tooltip.AddLine) ~= "function" then
    return false
  end
  -- Brief LF1 (QA item 246): a blank line first where the tooltip already holds lines.
  -- The client's answer is read through Util.CanRead before it is compared (bible B10).
  local after = false
  if type(tooltip.NumLines) == "function" then
    local ok, count = pcall(tooltip.NumLines, tooltip)
    local util = ItemTree.Util
    local readable = type(util) ~= "table" or type(util.CanRead) ~= "function" or util.CanRead(count)
    if ok and readable and type(count) == "number" then
      after = count > 0
    end
  end
  local drawn = false
  for _, line in ipairs(Tree.IngredientLines(row, after)) do
    tooltip:AddLine(line.text, tooltipColor(line.colorKey))
    drawn = true
  end
  return drawn
end

-- What a row whose item this build withholds says about itself, under whichever block was drawn
-- above it. Two sentences, one each way round: the build is refusing to state the item until it
-- has dropped for somebody on the realm, or somebody has, and the data has not caught up yet.
--
-- E44: on every hover, the client's own item tooltip included. This is the one place the pane
-- writes the sentence, and ItemTree's block (UI/Tooltip.lua) never writes it at all, so it lands
-- under whatever was drawn above and can never land twice.
local function addUndiscoveredLine(tooltip, row)
  local node = type(row.node) == "table" and row.node or nil
  if not node or not node.undiscovered then
    return false
  end
  if node.discovered then
    -- What the chest in the corner means, then the rest of the sentence.
    local said = mutedLine(tooltip, Tree.DiscoveryMarkLabel(Tree.DiscoveryMark(node)))
    if mutedLine(tooltip, L["Discovered on your realm. Not yet in ItemTree data."]) then
      said = true
    end
    return said
  end
  return mutedLine(tooltip, L["Undiscovered in Forever. Its details appear once someone on your realm finds it."])
end

--- Brief E90: where the source a row names is, for its tooltip: { zone, points, more } or nil.
---
--- A Classic Era creature, vendor, node, fishing pool or chest reads the shipped table's pins
--- through the reader's own E:Places (Core/EraSources.lua), which is the Map tab's reader and its
--- small cache: one pin string decoded for the one row hovered, out of a table the row was built
--- from and so already loaded. A key that is not the table's own answers before the table is asked.
--- A vendor the client's own tables place (Core/ForeverVendors.lua) answers its one position, and
--- only where that module is already built: a hover never loads it. Guarded throughout.
function Tree.RowPlaces(row)
  if type(row) ~= "table" or (row.kind or "row") ~= "row" or Tree.IsSummary(row) then
    return nil
  end
  local key = nodeKeyOf(row)
  local graph = ItemTree.Graph
  if not key or type(graph) ~= "table" or type(graph.Parse) ~= "function" then
    return nil
  end
  local edge = type(row.edge) == "table" and row.edge or EMPTY
  -- The row's own zone: the edge's area where it states one, else the zone its column opens.
  local areaId = tonumber(edge.areaId)
  local link = Tree.ZoneLink(row)
  if not areaId and link and link.action == "reroot" then
    local okLink, kind, id = pcall(graph.Parse, link.key)
    if okLink and kind == "zone" and type(id) == "number" and id > 0 then
      areaId = id
    end
  end

  -- Brief EK1: the reader's PinSubject, which reads a creature page key's name out of the table.
  local era = ItemTree.eraSources
  if type(era) == "table" and type(era.PinSubject) == "function" then
    local okSubject, field = pcall(era.PinSubject, era, key)
    if okSubject and field then
      if type(era.Places) ~= "function" then
        return nil
      end
      local ok, places = pcall(era.Places, era, key, areaId)
      return ok and type(places) == "table" and places or nil
    end
  end

  local forever = ItemTree.ForeverVendors
  if type(forever) ~= "table" or type(forever.Loaded) ~= "function" or type(forever.VendorAt) ~= "function" then
    return nil
  end
  local okKey, kind, npcId = pcall(graph.Parse, key)
  if not okKey or kind ~= "npc" or type(npcId) ~= "number" or npcId <= 0 then
    return nil
  end
  local okLoaded, loaded = pcall(forever.Loaded)
  if not okLoaded or type(loaded) ~= "table" then
    return nil
  end
  local okVendor, vendor = pcall(forever.VendorAt, loaded, npcId)
  if not okVendor or type(vendor) ~= "table" then
    return nil
  end
  local x, y = tonumber(vendor.x), tonumber(vendor.y)
  if not x or not y then
    return nil
  end
  -- The zone words the row's own column already says, which ForeverVendors.Place wrote into the
  -- edge when the row was built, so nothing is asked of anything here.
  local zone = type(edge.zone) == "string" and edge.zone ~= "" and edge.zone or nil
  return {
    areaId = vendor.a,
    zone = zone,
    points = { { x = math.floor(x * 1000 + 0.5) / 10, y = math.floor(y * 1000 + 0.5) / 10 } },
    more = 0,
  }
end

--- Brief TV4: every place the source a row names stands, grouped by zone for its hover
--- (Tree.PlaceGroups), or nil. A Classic Era creature, vendor or object reads its decoded pins
--- through the reader's own E:PinsOf or E:ObjectPinsOf (the Map tab's cache, out of a table the row
--- was built from), every zone it stands in, the row's own first; a key that names one place keeps
--- to that zone. A vendor the client's own tables place answers its one position (Tree.RowPlaces).
--- A Forever creature's hand kept spots (UI/Map.lua Map.SpotPins), each with its tier, join where
--- the Creatures module is already built: a hover never builds it. Guarded.
function Tree.RowPlaceGroups(row)
  if type(row) ~= "table" or (row.kind or "row") ~= "row" or Tree.IsSummary(row) then
    return nil
  end
  local key = nodeKeyOf(row)
  local graph = ItemTree.Graph
  if not key or type(graph) ~= "table" or type(graph.Parse) ~= "function" then
    return nil
  end
  local edge = type(row.edge) == "table" and row.edge or EMPTY
  local home = tonumber(edge.areaId)
  local link = Tree.ZoneLink(row)
  if not home and link and link.action == "reroot" then
    local okLink, kind, id = pcall(graph.Parse, link.key)
    if okLink and kind == "zone" and type(id) == "number" and id > 0 then
      home = id
    end
  end
  local era = ItemTree.eraSources
  if type(era) == "table" and type(era.PinSubject) == "function" then
    local okSubject, field, nameIndex, keyArea = pcall(era.PinSubject, era, key)
    if okSubject and field then
      local reader = nil
      if field == "mp" then
        reader = era.PinsOf
      elseif field == "op" then
        reader = era.ObjectPinsOf
      end
      if type(reader) ~= "function" then
        return nil
      end
      local okPins, pins = pcall(reader, era, nameIndex)
      if not okPins or type(pins) ~= "table" then
        return nil
      end
      local maxZones = nil
      if keyArea ~= nil then
        -- A name in one place: the row is that place, and the name's other places are rows of their own.
        local only = {}
        for _, pin in ipairs(pins) do
          if type(pin) == "table" and pin.area == keyArea then
            only[#only + 1] = pin
          end
        end
        pins, home, maxZones = only, keyArea, 1
      end
      return Tree.PlaceGroups(pins, home, function(areaId)
        if type(era.Places) ~= "function" then
          return nil
        end
        local okPlace, places = pcall(era.Places, era, key, areaId)
        return okPlace and type(places) == "table" and places.zone or nil
      end, nil, maxZones)
    end
  end

  local groups = nil
  local places = Tree.RowPlaces(row)
  if type(places) == "table" and type(places.points) == "table" and #places.points > 0 then
    groups = { { areaId = places.areaId, zone = places.zone, points = places.points, more = 0 }, zonesMore = 0 }
  end
  -- Brief CS1's tiers on a Forever creature's hand kept spots, read only off a built module.
  local creatures = ItemTree.Creatures
  local map = type(ItemTree.UI) == "table" and ItemTree.UI.Map or nil
  local okKey, kind, id = pcall(graph.Parse, key)
  if
    okKey
    and kind == "npc"
    and type(id) == "number"
    and id > 0
    and type(creatures) == "table"
    and type(creatures.Loaded) == "function"
    and type(map) == "table"
    and type(map.SpotPins) == "function"
  then
    local okLoaded, loaded = pcall(creatures.Loaded)
    if okLoaded and type(loaded) == "table" then
      local okSpots, spots = pcall(map.SpotPins, key)
      local spotGroups = okSpots and Tree.PlaceGroups(spots, nil, nil) or nil
      if spotGroups then
        groups = groups or { zonesMore = 0 }
        for _, group in ipairs(spotGroups) do
          groups[#groups + 1] = group
        end
        groups.zonesMore = (groups.zonesMore or 0) + (spotGroups.zonesMore or 0)
      end
    end
  end
  return groups
end

--- Brief TV4: draws hover lines (Tree.SourceTipLines' shape) on a tooltip: a pair with AddDoubleLine
--- where the client has it, its value in its own colour, a blank line as one blank line. Answers
--- whether any line went on. Guarded.
function Tree.DrawTipLines(tooltip, lines)
  if type(tooltip) ~= "table" or type(tooltip.AddLine) ~= "function" or type(lines) ~= "table" then
    return false
  end
  local drawn = false
  for _, line in ipairs(lines) do
    if type(line) == "table" and type(line.text) == "string" then
      local r, g, b = tooltipColor(line.colorKey)
      if type(line.color) == "table" and tonumber(line.color.r) then
        r, g, b = line.color.r, line.color.g, line.color.b
      end
      if line.right ~= nil and type(tooltip.AddDoubleLine) == "function" then
        local rr, rg, rb = tooltipColor(line.rightColorKey or line.colorKey)
        tooltip:AddDoubleLine(line.text, tostring(line.right), r, g, b, rr, rg, rb)
        drawn = true
      elseif line.text ~= "" or line.right ~= nil then
        local text = line.text
        if line.right ~= nil then
          text = text .. " " .. tostring(line.right)
        end
        tooltip:AddLine(text, r, g, b)
        drawn = true
      end
    end
  end
  return drawn
end

-- Brief TV4 (the owner's designs 3 to 5): a source row's part of its hover, after a blank line,
-- in Tree.SourceTipLines' label and value lines.
local function addSourceLines(tooltip, row)
  local lines = Tree.SourceTipLines(row, Tree.RowPlaceGroups(row))
  if #lines == 0 then
    return false
  end
  table.insert(lines, 1, { text = " ", gap = true, colorKey = Tree.TIP_BODY })
  return Tree.DrawTipLines(tooltip, lines)
end

--- Brief TV4 (the owner's designs 1 and 2): a quest row's hover is the quest's own card, the one
--- the quest page's header draws (UI/InfoPanel.lua InfoPanel.QuestCard): the title with the quest
--- id, its state, side, zone, givers and turn ins with their spots, what it asks for and gives.
--- Answers false where the row is no quest's, or the panel is not loaded, and the row's hover is
--- drawn as any other row's. Guarded.
function Tree.AddQuestCard(tooltip, row)
  local node = type(row) == "table" and type(row.node) == "table" and row.node or nil
  if not node or node.kind ~= "quest" or Tree.IsSummary(row) or type(tooltip.AddLine) ~= "function" then
    return false
  end
  local questId = tonumber(node.id)
  local ui = ItemTree.UI
  local panel = type(ui) == "table" and ui.InfoPanel or nil
  if not questId or questId <= 0 or type(panel) ~= "table" or type(panel.QuestCard) ~= "function" then
    return false
  end
  local ok, title, lines = pcall(panel.QuestCard, questId)
  if not ok or type(title) ~= "string" or title == "" then
    return false
  end
  tooltip:AddLine(title, tooltipColor("ITEMTREE_COLOR_TEXT_TITLE"))
  Tree.DrawTipLines(tooltip, lines)
  return true
end

-- A category's own small tooltip: how much is under it, where the player stands on it, and
-- what its marks mean.
local function addCategoryLines(tooltip, row)
  if type(tooltip.AddLine) ~= "function" then
    return false
  end
  local node = type(row.node) == "table" and row.node or nil
  tooltip:AddLine((node and node.name) or row.text or "", tooltipColor("ITEMTREE_COLOR_TEXT_TITLE"))
  mutedLine(tooltip, Tree.CategoryCountText(row))
  local header = Tree.CategoryHeader(row)
  if header then
    mutedLine(tooltip, header.line)
  end
  for _, badge in ipairs(Badges.Sort(node and node.badges, Tree.BADGE_MAX_CATEGORY)) do
    -- Brief TV4 (ruling B2): no "Marked Predicted" in a hover inside the window; the badge says it.
    if badge ~= "predicted" then
      mutedLine(tooltip, string.format(L["Marked %s"], Badges.Label(badge) or badge))
    end
  end
  return true
end

-- Brief BQ28 (owner QA 2026-10-10 item 80): owns the tooltip on a row with its corner on the row
-- icon's, the bag slot's rule (UI/Compare.lua Compare.OwnIcon), read afresh on every show because
-- the row frames are pooled; ANCHOR_RIGHT where Compare is not loaded.
function Tree.OwnRowTooltip(tooltip, frame)
  local Compare = ItemTree.Compare
  if type(Compare) == "table" and type(Compare.OwnIcon) == "function" then
    local ok, owned = pcall(Compare.OwnIcon, tooltip, frame, rawget(frame, "icon"))
    if ok and owned then
      return owned
    end
  end
  tooltip:SetOwner(frame, "ANCHOR_RIGHT")
  return "ANCHOR_RIGHT"
end

-- Brief BQ28: after the Show, below the icon where the filled tooltip would run off the top of
-- the screen (UI/Compare.lua Compare.FitIcon).
local function fitRowTooltip(tooltip)
  local Compare = ItemTree.Compare
  if type(Compare) == "table" and type(Compare.FitIcon) == "function" then
    pcall(Compare.FitIcon, tooltip)
  end
end

-- The tooltip a hovered row raises, anchored to its icon. An item takes the client's own
-- tooltip where the client can draw one, so the player reads exactly what a bag slot shows
-- plus ItemTree's block; everything else is written from what the pane already knows.
local function showRowTooltip(frame)
  local tooltip = rawget(_G, "GameTooltip")
  local row = rawget(frame, "row")
  if not row or type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  Tree.OwnRowTooltip(tooltip, frame)
  -- Brief BQ25a (QA item 72): Ctrl unfolds the uses here too (UI/Tooltip.lua RedrawOnModifier).
  local tip = ItemTree.Tooltip
  if type(tip) == "table" and type(tip.RedrawOnModifier) == "function" then
    tip.RedrawOnModifier(frame, showRowTooltip, frame)
  end

  local kind = row.kind or "row"
  local drawn = false
  if kind == "category" then
    drawn = addCategoryLines(tooltip, row)
  elseif kind == "more" then
    -- E75: a Classic Era summary's qualifier, which its "Show N more" row has no column for.
    local line = Tree.MoreTooltipText(row)
    if line and type(tooltip.AddLine) == "function" then
      tooltip:AddLine(line, tooltipColor("ITEMTREE_COLOR_TEXT_HINT"))
      drawn = true
    end
  elseif kind == "row" and Tree.IsQuietSummary(row) then
    -- Brief E87: the row's own words and nothing else. It names no source, so there is no type,
    -- no rate, no mark and no Classic Era line to say about it.
    local line = Tree.SummaryText(row)
    if line ~= "" and type(tooltip.AddLine) == "function" then
      tooltip:AddLine(line, tooltipColor("ITEMTREE_COLOR_TEXT_MUTED"))
      drawn = true
    end
  elseif kind == "row" and Tree.AddQuestCard(tooltip, row) then
    -- Brief TV4: the quest's own card says everything the row knows, and more.
    drawn = true
  elseif kind == "row" then
    local itemId = Tree.TooltipItemId(row)
    local node = type(row.node) == "table" and row.node or nil
    if node and node.kind == "item" and setClientItem(tooltip, itemId) then
      drawn = true
    else
      -- The name is the pane's line, the block under it the info panel's, and a row the panel
      -- has no record for says what it knows about itself instead.
      drawn = addNodeTitle(tooltip, row)
      if addPanelLines(tooltip, itemId) then
        drawn = true
      elseif addNodeFacts(tooltip, row) then
        drawn = true
      end
    end
    -- What the row is, then where it comes from, under whichever block was drawn above.
    if addMarkLine(tooltip, row) then
      drawn = true
    end
    if addCraftLines(tooltip, row) then
      drawn = true
    end
    -- Brief TC1: a total says what it is made of, in one muted line.
    if mutedLine(tooltip, Tree.TotalLabel(row)) then
      drawn = true
    end
    -- E25: what the craft is made of, in the two modes that ask for it ("tooltip" and "all").
    -- The row only carries ingredients when Core was asked for them, so this is one answer from
    -- Core and nothing else in every other mode.
    if Tree.CraftShows("tooltip") and addIngredientLines(tooltip, row) then
      drawn = true
    end
    if addUndiscoveredLine(tooltip, row) then
      drawn = true
    end
    if addSourceLines(tooltip, row) then
      drawn = true
    end
    -- Brief D7: a gathering node whose name opens its Map page says so, last. Brief N1: so does a
    -- zone Here row whose source name opens that source's page. Brief TV4: and a creature's row
    -- whose name opens the creature's page (Tree.CreatureFooter).
    local hint = Tree.NodeHint(row) or Tree.SourceHint(row) or Tree.CreatureFooter(row)
    if hint and type(tooltip.AddLine) == "function" then
      tooltip:AddLine(hint, tooltipColor("ITEMTREE_COLOR_TEXT_HINT"))
      drawn = true
    end
  end
  if row.loop and type(tooltip.AddLine) == "function" then
    mutedLine(tooltip, L["Already in this path"])
    drawn = true
  end
  if not drawn then
    if type(tooltip.Hide) == "function" then
      tooltip:Hide()
    end
    return false
  end
  tooltip:Show()
  fitRowTooltip(tooltip)
  return true
end

-- E44: the chest's own hover, raised from the small target over the mark itself. One line, the
-- sentence, and nothing else: the player is pointing at a 14px glyph and asking what it is, not
-- at the row. A row wearing the question mark has no target over it, so there is nothing here
-- for it to say.
local function showMarkTooltip(button)
  local frame = rawget(button, "owner")
  local row = frame and rawget(frame, "row") or nil
  local node = type(row) == "table" and type(row.node) == "table" and row.node or nil
  local text = Tree.DiscoveryMarkLabel(Tree.DiscoveryMark(node))
  local tooltip = rawget(_G, "GameTooltip")
  if type(text) ~= "string" or text == "" then
    return false
  end
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" or type(tooltip.AddLine) ~= "function" then
    return false
  end
  tooltip:SetOwner(button, "ANCHOR_RIGHT")
  tooltip:AddLine(text, tooltipColor("ITEMTREE_COLOR_TEXT_TITLE"))
  tooltip:Show()
  return true
end

local function hideHint()
  local tooltip = rawget(_G, "GameTooltip")
  if tooltip and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end

-- Whether somebody else has a claim on the arrow keys. Two things have one: any edit box with
-- the keyboard focus, which the client itself will name, and the window's own global item
-- search while its dropdown is open, which hangs over this pane, so a pointer resting on the
-- rows under it had the tree swallowing the arrows the player meant for the results. Both are
-- asked rather than remembered, and both are guarded: a client that will not answer, or a
-- window this pane is not inside, reads as nothing holding the keys. Nothing here is pure.
function Tree.KeyboardBlocked()
  local focused = rawget(_G, "GetCurrentKeyBoardFocus")
  if type(focused) == "function" then
    local ok, box = pcall(focused)
    if ok and box ~= nil and box ~= false then
      return true
    end
  end
  local frame = ItemTree.UI and ItemTree.UI.Frame
  if frame and type(frame.SearchShown) == "function" then
    local ok, shown = pcall(frame.SearchShown)
    if ok and shown then
      return true
    end
  end
  return false
end

-- Brief E91: SetPropagateKeyboardInput is refused in combat lockdown on the Forever client, so a
-- pane deciding per key in combat would keep whatever it decided last, which could leave Escape
-- swallowed and the window unable to close. The window's own answer first (UI/Frame.lua), then
-- the client's, and a client that will not say reads as out of combat.
local function inCombat()
  local ui = ItemTree.UI
  local Frame = type(ui) == "table" and ui.Frame or nil
  if type(Frame) == "table" and type(Frame.InCombat) == "function" then
    local ok, answer = pcall(Frame.InCombat)
    if ok then
      return answer == true
    end
  end
  local lockdown = globalFn("InCombatLockdown")
  if not lockdown then
    return false
  end
  local ok, locked = pcall(lockdown)
  return (ok and locked) and true or false
end

-- Propagation, never in combat. Answers whether it was set.
local function setPropagate(pane, on)
  if inCombat() or type(pane.SetPropagateKeyboardInput) ~= "function" then
    return false
  end
  return (pcall(pane.SetPropagateKeyboardInput, pane, on))
end

-- Keyboard capture is opt in: it is switched on only while the cursor is over the pane, so
-- the arrow keys keep turning the player everywhere else, and never while something else holds
-- the keys. See onKeyDown for the other half.
--
-- Brief E91: never taken in combat either. UI/Frame.lua lets it go on PLAYER_REGEN_DISABLED
-- (SetKeyboardCapture(false), before the lockdown) and works it out again on
-- PLAYER_REGEN_ENABLED (SyncKeyboardCapture).
function Tree.SetKeyboardCapture(enabled)
  local wanted = enabled and true or false
  if wanted and (Tree.KeyboardBlocked() or inCombat()) then
    wanted = false
  end
  Tree.keyboard = wanted
  local pane = Tree.pane
  if pane and type(pane.EnableKeyboard) == "function" then
    setPropagate(pane, true)
    pcall(pane.EnableKeyboard, pane, Tree.keyboard)
  end
  return Tree.keyboard
end

-- Works the capture out again from where the pointer is and who holds the keys. The window's
-- global search box calls it as its focus comes and goes: the pointer can be resting on these
-- rows the whole time, so no OnEnter or OnLeave fires and there is nothing else to ask.
function Tree.SyncKeyboardCapture()
  local pane = Tree.pane
  local over = false
  if pane and type(pane.IsMouseOver) == "function" then
    local ok, value = pcall(pane.IsMouseOver, pane)
    over = (ok and value) and true or false
  end
  return Tree.SetKeyboardCapture(over)
end

-- EXPERIMENTAL (brief E25), the modes that ask for the card ("card" and "all"): the info column
-- draws a Recipe card for the craft the player is reading, and clears it the moment they read
-- something else. The panel is another
-- file's and loads after this one, so it is looked up lazily and every call is pcall'd: a half
-- loaded client costs the player a card and nothing else.
--
-- Only the craft behind the row travels, as its spell key, plus the ingredient lists Core
-- already worked out, so the column never walks the graph twice for the same answer and no item
-- is ever queried for it.
local function showRecipeCard(row)
  local ui = ItemTree.UI
  local panel = type(ui) == "table" and ui.InfoPanel or nil
  if type(panel) ~= "table" or type(panel.SetRecipe) ~= "function" then
    return false
  end
  local key = nil
  if Tree.CraftShows("card") then
    key = Tree.CraftKey(row)
  end
  if not key or type(row.ingredients) ~= "table" then
    return (pcall(panel.SetRecipe, nil))
  end
  return (pcall(panel.SetRecipe, { key = key, ingredients = row.ingredients, tools = row.tools }))
end

-- Takes the card away. Not gated on the mode, unlike raising one: the owner is switching
-- between the modes in game, and a card raised while the mode still wanted one has to go the
-- moment he reads something else, whatever the mode has become since. Telling a column that is
-- holding nothing to hold nothing costs a type check and no draw at all.
local function clearRecipeCard()
  local ui = ItemTree.UI
  local panel = type(ui) == "table" and ui.InfoPanel or nil
  if type(panel) ~= "table" or type(panel.SetRecipe) ~= "function" then
    return false
  end
  return (pcall(panel.SetRecipe, nil))
end

local function onRowEnter(frame)
  Tree.SetKeyboardCapture(true)
  showRowTooltip(frame)
  showRecipeCard(rawget(frame, "row"))
end

-- Row frames sit on top of the pane, so the pane's own OnEnter and OnLeave do not always
-- fire: the cursor can arrive on a row and leave from one. A row losing the mouse therefore
-- asks whether the pane still has it, and lets the keyboard go when it does not.
local function onRowLeave(_frame)
  hideHint()
  clearRecipeCard()
  local pane = Tree.pane
  if pane and type(pane.IsMouseOver) == "function" and pane:IsMouseOver() then
    return
  end
  Tree.SetKeyboardCapture(false)
end

local function onPaneLeave()
  hideHint()
  clearRecipeCard()
  Tree.SetKeyboardCapture(false)
end

-- E6: the standard modified clicks. A left click with the client's dress up or chat link
-- modifier on an item row is handed to UI/ItemClick.lua first, and when the client takes it (the
-- item is on in the Dressing Room, or its link is in the chat box) the row does not re-root.
-- Every other click, and every row that is not an item, is exactly what it was.
local function modifiedItemClick(key, button)
  if button ~= nil and button ~= "LeftButton" then
    return false
  end
  local helper = ItemTree.ItemClick
  if type(helper) ~= "table" or type(helper.HandleKey) ~= "function" then
    return false
  end
  local ok, handled = pcall(helper.HandleKey, key)
  return ok and handled == true
end

local function onRowClick(frame, button)
  local row = rawget(frame, "row")
  if not row then
    return
  end
  local node = type(row.node) == "table" and row.node or nil
  if node and modifiedItemClick(node.key, button) then
    return
  end
  local action, key, extra = Tree.Interpret(row, { column = "name", button = button or "LeftButton" })
  -- Brief BQ24: a trainer's row opens its page on the Map tab (UI/Frame.lua Frame.TrainerOpenView).
  if action == "reroot" and extra == nil and Tree.IsTrainerRow(row) then
    extra = { trainer = true }
  end
  perform(action, key, extra)
end

-- E44: the hover target over the chest. Entering it is still being on the row as far as the
-- pane is concerned, so the keyboard stays captured, and leaving it is leaving the row: the row's
-- own OnLeave already fired when the pointer crossed onto this target, and going back onto the
-- row raises the row's tooltip again.
local function onMarkEnter(button)
  Tree.SetKeyboardCapture(true)
  showMarkTooltip(button)
end

-- The target never eats the row's click: the press is handed straight to the row's own handler,
-- so clicking the chest opens exactly what clicking the row opens.
local function onMarkClick(button, mouseButton)
  local frame = rawget(button, "owner")
  if not frame then
    return
  end
  onRowClick(frame, mouseButton)
end

local function onChevronClick(button, mouseButton)
  local frame = rawget(button, "owner")
  local row = frame and rawget(frame, "row") or nil
  if not row then
    return
  end
  local action, key, extra = Tree.Interpret(row, { column = "chevron", button = mouseButton or "LeftButton" })
  perform(action, key, extra)
end

-- Brief Z1: the zone column's own hit target, over the words only, laid down on a row whose column
-- is a link (Tree.ZoneLink). A press opens the zone, or on a zone's Here tab picks the source; the
-- hover is the row's own tooltip with one more line saying which.
local function onZoneClick(button, mouseButton)
  local frame = rawget(button, "owner")
  local row = frame and rawget(frame, "row") or nil
  if not row then
    return
  end
  local action, key, extra = Tree.Interpret(row, { column = "zone", button = mouseButton or "LeftButton" })
  perform(action, key, extra)
end

local function onZoneEnter(button)
  local frame = rawget(button, "owner")
  if not frame then
    return
  end
  Tree.SetKeyboardCapture(true)
  showRowTooltip(frame)
  local hint = Tree.ZoneHint(rawget(frame, "row"))
  local tooltip = rawget(_G, "GameTooltip")
  if hint and type(tooltip) == "table" and type(tooltip.AddLine) == "function" then
    if type(tooltip.IsShown) == "function" and not tooltip:IsShown() and type(tooltip.SetOwner) == "function" then
      tooltip:SetOwner(button, "ANCHOR_RIGHT")
    end
    tooltip:AddLine(hint, tooltipColor("ITEMTREE_COLOR_TEXT_HINT"))
    if type(tooltip.Show) == "function" then
      tooltip:Show()
    end
  end
end

-- E25: the strip button, which opens and closes the icons under a craft row, and the hover on
-- it, which says in words what the icons would show.
local function onStripClick(button, mouseButton)
  local frame = rawget(button, "owner")
  local row = frame and rawget(frame, "row") or nil
  if not row then
    return
  end
  local action, key = Tree.Interpret(row, { column = "strip", button = mouseButton or "LeftButton" })
  perform(action, key)
end

local function onStripButtonEnter(button)
  local frame = rawget(button, "owner")
  local row = frame and rawget(frame, "row") or nil
  local tooltip = rawget(_G, "GameTooltip")
  if not row or type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return
  end
  tooltip:SetOwner(button, "ANCHOR_RIGHT")
  if not addIngredientLines(tooltip, row) then
    if type(tooltip.Hide) == "function" then
      tooltip:Hide()
    end
    return
  end
  tooltip:Show()
end

-- E25: one icon in a strip. A click opens that item exactly as a click on a row's name does, and
-- a hover gives the client's own item tooltip, so the strip is not a picture of something the
-- player cannot reach.
local function onStripCellClick(button, mouseButton)
  local key = rawget(button, "itemTreeKey")
  if type(key) == "string" and modifiedItemClick(key, mouseButton) then
    return
  end
  if type(key) == "string" then
    -- E42: through perform, not straight to askFrameToOpen, so the icon makes the same one small
    -- click a row's name does. A re-root is a re-root wherever it was pressed.
    perform("reroot", key)
  end
end

local function onStripCellEnter(button)
  local tooltip = rawget(_G, "GameTooltip")
  local key = rawget(button, "itemTreeKey")
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" or type(key) ~= "string" then
    return
  end
  tooltip:SetOwner(button, "ANCHOR_RIGHT")
  local graph = ItemTree.Graph
  local kind, id = nil, nil
  if type(graph) == "table" and type(graph.Parse) == "function" then
    kind, id = graph.Parse(key)
  end
  local shown = false
  if kind == "item" then
    shown = setClientItem(tooltip, id)
  end
  if not shown then
    local name = rawget(button, "itemTreeName")
    if type(name) ~= "string" or name == "" or type(tooltip.AddLine) ~= "function" then
      if type(tooltip.Hide) == "function" then
        tooltip:Hide()
      end
      return
    end
    tooltip:AddLine(name, tooltipColor(rawget(button, "itemTreeColor")))
    local count = rawget(button, "itemTreeCount")
    if type(count) == "string" and count ~= "" then
      mutedLine(tooltip, count)
    end
  end
  tooltip:Show()
end

-- E48: asks a badge cluster to make every mark in it its own hover target. The method arrived
-- with that brief, so a build whose Badges predates it simply draws the marks it always drew.
local function askBadgeHover(cluster)
  if type(cluster) ~= "table" or type(cluster.SetHoverEnabled) ~= "function" then
    return false
  end
  return (pcall(cluster.SetHoverEnabled, cluster, true))
end

-- Gives a frame the regions one drawn row needs, laid out per kind from Tree.Layout. The
-- chevron is its own button so a click on it toggles rather than re-roots, which is what
-- TreeRow.jsx does by stopping propagation. Public, because the ScrollBox element
-- initialiser is handed frames the client made and builds on the same regions the pool uses.
function Tree.Decorate(frame)
  if type(frame) ~= "table" or rawget(frame, "itemtreeRow") then
    return frame
  end
  if type(frame.CreateTexture) ~= "function" or type(frame.CreateFontString) ~= "function" then
    return frame
  end
  frame.itemtreeRow = true
  if type(frame.RegisterForClicks) == "function" then
    frame:RegisterForClicks("LeftButtonUp")
  end

  frame.background = frame:CreateTexture(nil, "BACKGROUND")
  frame.background:SetAllPoints(frame)
  Assets.Apply(frame.background, "FILL_WHITE8X8")
  frame.background:Hide()

  frame.selection = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  frame.selection:SetAllPoints(frame)
  Assets.Apply(frame.selection, "FILL_WHITE8X8")
  tint(frame.selection, "ITEMTREE_COLOR_STATE_SELECTED")
  frame.selection:Hide()

  frame.selectionBar = frame:CreateTexture(nil, "BORDER")
  Assets.Apply(frame.selectionBar, "FILL_WHITE8X8")
  tint(frame.selectionBar, "ITEMTREE_COLOR_BORDER_GOLD", 1)
  frame.selectionBar:SetWidth(2)
  frame.selectionBar:Hide()

  -- The 12 percent white wash washes the whole row and never boxes the icon or the name.
  frame.hover = frame:CreateTexture(nil, "HIGHLIGHT")
  frame.hover:SetAllPoints(frame)
  Assets.Apply(frame.hover, "FILL_WHITE8X8")
  frame.hover:SetVertexColor(1, 1, 1)
  frame.hover:SetAlpha(Tree.HOVER_ALPHA)

  frame.divider = frame:CreateTexture(nil, "ARTWORK")
  Assets.Apply(frame.divider, "FILL_WHITE8X8")
  tint(frame.divider, Tree.BORDER_COLOR, 1)
  frame.divider:SetHeight(Tree.BORDER)
  frame.divider:Hide()

  -- The hairline along the top of a section header. A row that is not a header never shows it.
  frame.topBorder = frame:CreateTexture(nil, "ARTWORK")
  Assets.Apply(frame.topBorder, "FILL_WHITE8X8")
  tint(frame.topBorder, Tree.BORDER_COLOR, 1)
  frame.topBorder:SetHeight(Tree.BORDER)
  frame.topBorder:Hide()

  frame.chevron = newFrame("Button", frame)
  if frame.chevron then
    frame.chevron.owner = frame
    frame.chevron.art = frame.chevron:CreateTexture(nil, "ARTWORK")
    frame.chevron.art:SetAllPoints(frame.chevron)
    if type(frame.chevron.RegisterForClicks) == "function" then
      frame.chevron:RegisterForClicks("LeftButtonUp")
    end
    frame.chevron:SetScript("OnClick", onChevronClick)
    frame.chevron:Hide()
  end

  -- A 1px gold edge under the icon, which is the design's gold framed icon box.
  frame.iconBorder = frame:CreateTexture(nil, "BORDER")
  Assets.Apply(frame.iconBorder, "FILL_WHITE8X8")
  tint(frame.iconBorder, "ITEMTREE_COLOR_BORDER_GOLD_DIM", 1)
  frame.iconBorder:Hide()
  frame.icon = frame:CreateTexture(nil, "ARTWORK")
  frame.icon:Hide()

  -- The corner glyph a spell or an enchant row wears, on its own dark disc so it reads over
  -- the bright corner of any icon. Both sit over the icon, which is ARTWORK, so they are on
  -- OVERLAY with the glyph a sublayer above its backing.
  frame.markBacking = frame:CreateTexture(nil, "OVERLAY")
  Assets.Apply(frame.markBacking, "FILL_WHITE8X8")
  frame.markBacking:Hide()
  frame.mark = frame:CreateTexture(nil, "OVERLAY", nil, 1)
  frame.mark:Hide()

  -- E44: the mark's own hover target, over the glyph with a couple of pixels of slop. A Button
  -- rather than a bare frame, because a press on it is handed to the row's handler: the target
  -- sits above the row and would otherwise swallow the click the player meant for the row. Only
  -- a row wearing the chest ever shows it, and a pooled row puts it away.
  frame.markHit = newFrame("Button", frame)
  if frame.markHit then
    frame.markHit.owner = frame
    if type(frame.markHit.RegisterForClicks) == "function" then
      frame.markHit:RegisterForClicks("LeftButtonUp")
    end
    frame.markHit:SetScript("OnClick", onMarkClick)
    frame.markHit:SetScript("OnEnter", onMarkEnter)
    frame.markHit:SetScript("OnLeave", onRowLeave)
    frame.markHit:Hide()
  end

  -- The recipe mark a merged craft row wears in the other corner of its icon, on its own disc
  -- for the same reason the spell mark has one. Both are hidden until a row asks for them.
  frame.recipeBacking = frame:CreateTexture(nil, "OVERLAY")
  Assets.Apply(frame.recipeBacking, "FILL_WHITE8X8")
  frame.recipeBacking:Hide()
  frame.recipeMark = frame:CreateTexture(nil, "OVERLAY", nil, 1)
  frame.recipeMark:Hide()

  -- E25: the small button at the right hand end of a craft row that opens the strip of
  -- ingredient icons under it, and the cells of the strip itself, which are made on the first
  -- row that needs them. Both are hidden on every row that does not ask, because the frame they
  -- are drawn on is pooled and the row before it may have been a craft.
  frame.stripButton = newFrame("Button", frame)
  if frame.stripButton then
    frame.stripButton.owner = frame
    frame.stripButton.art = frame.stripButton:CreateTexture(nil, "ARTWORK")
    frame.stripButton.art:SetAllPoints(frame.stripButton)
    if type(frame.stripButton.RegisterForClicks) == "function" then
      frame.stripButton:RegisterForClicks("LeftButtonUp")
    end
    frame.stripButton:SetScript("OnClick", onStripClick)
    frame.stripButton:SetScript("OnEnter", onStripButtonEnter)
    frame.stripButton:SetScript("OnLeave", hideHint)
    frame.stripButton:Hide()
  end
  frame.stripCells = {}

  frame.name = newFontString(frame, "OVERLAY")
  -- How many a merged craft makes, drawn over the corner of the icon as the client draws a
  -- stack count, so it can never be read as the quantity column beside it.
  frame.yield = newFontString(frame, "OVERLAY")
  frame.quantity = newFontString(frame, "OVERLAY")
  frame.meta = newFontString(frame, "OVERLAY")
  frame.count = newFontString(frame, "OVERLAY")
  frame.sourceType = newFontString(frame, "OVERLAY")
  frame.sourceZone = newFontString(frame, "OVERLAY")
  frame.sourceRate = newFontString(frame, "OVERLAY")
  -- Brief Z1: the zone column's hit target, hidden on every row whose column is not a link.
  frame.zoneHit = newFrame("Button", frame)
  if frame.zoneHit then
    frame.zoneHit.owner = frame
    if type(frame.zoneHit.RegisterForClicks) == "function" then
      frame.zoneHit:RegisterForClicks("LeftButtonUp")
    end
    frame.zoneHit:SetScript("OnClick", onZoneClick)
    frame.zoneHit:SetScript("OnEnter", onZoneEnter)
    frame.zoneHit:SetScript("OnLeave", onRowLeave)
    frame.zoneHit:Hide()
  end

  frame.treeBadges = Badges.CreateCluster(frame, Tree.BADGE_TREE, Tree.BADGE_MAX_ROW)
  frame.listBadges = Badges.CreateCluster(frame, Tree.BADGE_LIST, Tree.BADGE_MAX_CATEGORY)
  -- E48: every mark is its own hover target, whether or not the row under it has anything to
  -- diff. A source row and a category header name no Diff subject, and a badge used to take the
  -- mouse only where one was named, so pointing at the Predicted orb on "Mushgog" or on
  -- "Gathered in" raised the row's tooltip and never the mark's own words. Asked for once per
  -- pooled frame; UI/Badges.lua hands it on to every mark the cluster draws later.
  askBadgeHover(frame.treeBadges)
  askBadgeHover(frame.listBadges)

  frame:SetScript("OnClick", onRowClick)
  frame:SetScript("OnEnter", onRowEnter)
  frame:SetScript("OnLeave", onRowLeave)
  return frame
end

local function newRowFrame(parent)
  local frame = newFrame("Button", parent)
  if not frame then
    return nil
  end
  return Tree.Decorate(frame)
end

-- E44: the hover target over the glyph, which comes and goes with the chest and with nothing
-- else. A question mark needs none, because the row says what it means in words wherever it is
-- drawn, and an unmarked row has nothing to point at.
local function applyMarkHit(frame, layout, shown)
  local hit = frame.markHit
  if not hit then
    return false
  end
  if not shown or layout.discovery ~= "discovered" then
    hit:Hide()
    return false
  end
  local slop = Tree.MARK_HIT_SLOP
  hit:ClearAllPoints()
  hit:SetPoint("TOPLEFT", frame.mark, "TOPLEFT", -slop, slop)
  hit:SetPoint("BOTTOMRIGHT", frame.mark, "BOTTOMRIGHT", slop, -slop)
  hit:Show()
  return true
end

-- The corner glyph, pinned inside the bottom right of the icon by a hairline so the dark disc
-- behind it, which is a pixel wider again, lands exactly on the icon's corner. It used to hang
-- a pixel outside, which put the disc over the icon border of the row below and read as
-- "Enchant 2H" sitting on top of "Strength". Hidden on every row that does not ask for it,
-- because the frame it is drawn on is pooled.
local function applyMark(frame, layout)
  local mark, backing = frame.mark, frame.markBacking
  if not mark then
    applyMarkHit(frame, layout, false)
    return false
  end
  if not layout.markAsset or not frame.icon or not frame.icon:IsShown() then
    mark:Hide()
    if backing then
      backing:Hide()
    end
    applyMarkHit(frame, layout, false)
    return false
  end
  local size = layout.markSize or Tree.MARK
  mark:ClearAllPoints()
  mark:SetSize(size, size)
  mark:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", -Tree.MARK_INSET, Tree.MARK_INSET)
  Assets.Apply(mark, layout.markAsset)
  if type(mark.SetVertexColor) == "function" then
    mark:SetVertexColor(1, 1, 1)
  end
  mark:Show()
  if backing then
    backing:ClearAllPoints()
    backing:SetPoint("TOPLEFT", mark, "TOPLEFT", -1, 1)
    backing:SetPoint("BOTTOMRIGHT", mark, "BOTTOMRIGHT", 1, -1)
    tint(backing, layout.markBacking or "ITEMTREE_BADGE_BACKING")
    backing:Show()
  end
  applyMarkHit(frame, layout, true)
  return true
end

-- The two corners only a merged craft row draws: how many the craft makes, bottom right where
-- the client itself writes a stack count, and the recipe mark top left, which is the one corner
-- that count can never reach. Every row that does not ask for them hides both, because the
-- frame they are drawn on is pooled and the row before it may have been a craft.
local function applyCraft(frame, layout)
  local icon = frame.icon
  local drawn = icon ~= nil and icon:IsShown()
  local yield, mark, backing = frame.yield, frame.recipeMark, frame.recipeBacking
  if yield then
    local text = drawn and layout.yieldText or nil
    if type(text) == "string" and text ~= "" then
      yield:ClearAllPoints()
      yield:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -Tree.MARK_INSET, Tree.MARK_INSET)
      setFont(yield, layout.metaFontSize)
      setText(yield, text)
      textColor(yield, "ITEMTREE_COLOR_TEXT_BODY")
      yield:Show()
    else
      yield:Hide()
    end
  end
  if not mark then
    return
  end
  if not drawn or not layout.recipeAsset then
    mark:Hide()
    if backing then
      backing:Hide()
    end
    return
  end
  local size = layout.recipeSize or Tree.MARK
  mark:ClearAllPoints()
  mark:SetSize(size, size)
  mark:SetPoint("TOPLEFT", icon, "TOPLEFT", Tree.MARK_INSET, -Tree.MARK_INSET)
  Assets.Apply(mark, layout.recipeAsset)
  if type(mark.SetVertexColor) == "function" then
    mark:SetVertexColor(1, 1, 1)
  end
  mark:Show()
  if backing then
    backing:ClearAllPoints()
    backing:SetPoint("TOPLEFT", mark, "TOPLEFT", -1, 1)
    backing:SetPoint("BOTTOMRIGHT", mark, "BOTTOMRIGHT", 1, -1)
    tint(backing, layout.recipeBacking or "ITEMTREE_BADGE_BACKING")
    backing:Show()
  end
end

-- E25: the strip button at the right hand end of a craft row. Placed in its own column so it
-- never lands on the badges, and hidden on every row and in every mode that does not ask for it.
local function applyStripButton(frame, layout)
  local button = frame.stripButton
  if not button then
    return false
  end
  if not layout.stripAsset or not place(frame, button, layout, "strip", Tree.MARK) then
    button:Hide()
    return false
  end
  button:SetSize(Tree.MARK, Tree.MARK)
  Assets.Apply(button.art, layout.stripAsset)
  tint(button.art, layout.stripOpen and "ITEMTREE_COLOR_BORDER_GOLD_DIM" or "ITEMTREE_COLOR_TEXT_MUTED", 1)
  button.art:Show()
  button:Show()
  return true
end

-- Brief PR29: the last "Show nearest" answer, kept with the item it was asked on, so the button's
-- tooltip says it again when the player comes back to that item's Sources view.
Tree.nearestResult = nil
-- The button's words as the client measured them, which the next layout sizes the column by.
Tree.nearestMeasured = nil

local function nearestRoot()
  local vm = Tree.vm
  return type(vm) == "table" and vm.root or nil
end

-- Brief PR34: the hint before any press, per kind of group.
local NEAREST_HINTS = {
  vendor = L["Finds the nearest vendor that sells this and sets a waypoint."],
  trainer = L["Finds the nearest trainer who teaches this and sets a waypoint."],
}

--- Brief PR29: the button's tooltip lines, { text, muted } pairs: the last answer on this item and
--- the straight line note under it, else the hint. kind ("vendor", the default, or "trainer",
--- brief PR34) is the header's group: an answer is said again only on a header of its own kind.
--- Pure over Tree.nearestResult and the root.
function Tree.NearestTooltipLines(root, kind)
  kind = NEAREST_HINTS[kind] and kind or "vendor"
  local held = Tree.nearestResult
  local heldKind = type(held) == "table" and held.kind or "vendor"
  if
    type(held) == "table"
    and held.root ~= nil
    and held.root == root
    and heldKind == kind
    and type(held.text) == "string"
  then
    local lines = { { text = held.text, muted = false } }
    if held.measured then
      lines[2] = { text = L["Straight line; flight paths and roads are not counted."], muted = true }
    end
    return lines
  end
  return { { text = NEAREST_HINTS[kind], muted = false } }
end

-- The kind of group ("vendor" or "trainer") the button's own header row holds, or nil.
local function nearestKind(button)
  local Nearest = ItemTree.Nearest
  local frame = rawget(button, "owner")
  local row = frame and rawget(frame, "row") or nil
  if type(Nearest) ~= "table" or type(Nearest.GroupKind) ~= "function" then
    return nil
  end
  local ok, kind = pcall(Nearest.GroupKind, row)
  return ok and kind or nil
end

local function onNearestEnter(button)
  local ui = ItemTree.UI
  local frameApi = type(ui) == "table" and ui.Frame or nil
  if type(frameApi) == "table" and type(frameApi.PaintPlateButton) == "function" then
    pcall(frameApi.PaintPlateButton, button, "hover")
  end
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return
  end
  tooltip:SetOwner(button, "ANCHOR_RIGHT")
  -- Brief TV2 (QA item 347, the audit's buttons/show-nearest: one line 510 wide): every line wraps,
  -- so the hover wraps at the tooltip's usual width, as the item page's Keep switch hover does
  -- (UI/Frame.lua, AddLine with wrap on).
  for _, line in ipairs(Tree.NearestTooltipLines(nearestRoot(), nearestKind(button))) do
    if type(line.text) == "string" and line.text ~= "" and type(tooltip.AddLine) == "function" then
      local r, g, b = tooltipColor(line.muted and "ITEMTREE_COLOR_TEXT_MUTED" or "ITEMTREE_COLOR_TEXT_BODY")
      tooltip:AddLine(line.text, r, g, b, true)
    end
  end
  tooltip:Show()
end

local function onNearestLeave(button)
  local ui = ItemTree.UI
  local frameApi = type(ui) == "table" and ui.Frame or nil
  if type(frameApi) == "table" and type(frameApi.PaintPlateButton) == "function" then
    pcall(frameApi.PaintPlateButton, button, "normal")
  end
  hideHint()
end

-- The answer in chat, through the client's own chat frame, guarded.
local function nearestChat(text)
  local chat = rawget(_G, "DEFAULT_CHAT_FRAME")
  if type(chat) ~= "table" or type(chat.AddMessage) ~= "function" or type(text) ~= "string" then
    return false
  end
  return (pcall(chat.AddMessage, chat, L["ItemTree"] .. ": " .. text))
end

-- The waypoint through the NPC page's own path (UI/InfoPanel.lua InfoPanel.SetWaypoint, which is
-- UI/Map.lua Map.SetWaypoint), guarded. Brief UX1: label is what it is for, which its toast says.
local function nearestWaypoint(at, label)
  local ui = ItemTree.UI
  local panel = type(ui) == "table" and ui.InfoPanel or nil
  if type(at) ~= "table" or type(panel) ~= "table" or type(panel.SetWaypoint) ~= "function" then
    return false
  end
  local ok, set = pcall(panel.SetWaypoint, at, label)
  return ok and set == true
end

--- Owner request 2026-10-02: the tab the vendor's page opens on after "Show nearest": Map where
--- the page has one (its pins are known), else Sells (brief PR34: Teaches for a trainer, kind
--- "trainer"), else nil for the page's own default. Takes the page's view keys
--- (Core/ViewModel.lua ViewModel.ViewsFor). Pure.
function Tree.NearestView(views, kind)
  local Edges = ItemTree.Edges
  local map = type(Edges) == "table" and Edges.MAP or "map"
  local second = type(Edges) == "table" and Edges.SELLS or "sells"
  if kind == "trainer" then
    second = type(Edges) == "table" and Edges.TEACHES_VIEW or "teaches"
  end
  local hasSecond = false
  for _, view in ipairs(type(views) == "table" and views or {}) do
    if view == map then
      return map
    end
    if view == second then
      hasSecond = true
    end
  end
  if hasSecond then
    return second
  end
  return nil
end

-- Opens the vendor's page on the tab Tree.NearestView picks, through Frame.Open's own view option
-- (the one Tree.OpenPlaced uses), and plainly where it picks none. Guarded.
local function openNearest(key, kind)
  local frame = frameModule()
  if not frame or type(frame.Open) ~= "function" then
    return false
  end
  local ViewModel = ItemTree.ViewModel
  local views = nil
  if type(ViewModel) == "table" and type(ViewModel.ViewsFor) == "function" then
    local ok, answer = pcall(ViewModel.ViewsFor, key)
    views = ok and answer or nil
  end
  local view = Tree.NearestView(views, kind)
  if view then
    return (pcall(frame.Open, key, { view = view }))
  end
  return askFrameToOpen(key)
end

--- Brief PR29: a press on "Show nearest" for one "Sold by" (or "Trainer", brief PR34) header row:
--- Core/Nearest.lua finds the NPC, the waypoint goes on, the answer goes to chat and the tooltip,
--- and the NPC's page opens. Answers what Nearest.Find said, or nil where it could not be asked.
function Tree.FindNearest(row)
  local Nearest = ItemTree.Nearest
  if type(row) ~= "table" or type(Nearest) ~= "table" or type(Nearest.Find) ~= "function" then
    return nil
  end
  local ok, found = pcall(Nearest.Find, row.category, { visible = Tree.VisibleEntries, faction = Tree.PlayerFaction() })
  if not ok or type(found) ~= "table" then
    return nil
  end
  Tree.nearestResult = { root = nearestRoot(), text = found.text, measured = found.key ~= nil, kind = found.kind }
  nearestChat(found.text)
  if found.waypoint then
    nearestWaypoint(found.waypoint, type(Nearest.WaypointFor) == "function" and Nearest.WaypointFor(found) or nil)
  end
  if type(found.key) == "string" then
    openNearest(found.key, found.kind)
  end
  return found
end

local function onNearestClick(button)
  local frame = rawget(button, "owner")
  local row = frame and rawget(frame, "row") or nil
  local found = Tree.FindNearest(row)
  -- No page opened: the button is still under the pointer, so its tooltip says the answer now.
  if found and not found.key and type(button.IsMouseOver) == "function" then
    local ok, over = pcall(button.IsMouseOver, button)
    if ok and over then
      onNearestEnter(button)
    end
  end
end

-- The button itself, made the first time a pooled row draws a "Sold by" header that asks for it:
-- the window's plate button with no glyph, and the words on its glyph frame, which sits above
-- every plate state. false where the window makes none, so it is asked once.
local function nearestButton(frame)
  local held = rawget(frame, "nearestButton")
  if held ~= nil then
    return held or nil
  end
  local ui = ItemTree.UI
  local frameApi = type(ui) == "table" and ui.Frame or nil
  local button = nil
  if type(frameApi) == "table" and type(frameApi.NewPlateButton) == "function" then
    local ok, made = pcall(frameApi.NewPlateButton, frame, nil, nil, Tree.NEAREST_H)
    button = ok and type(made) == "table" and made or nil
  end
  if not button then
    frame.nearestButton = false
    return nil
  end
  button.owner = frame
  button.label = newFontString(rawget(button, "glyphFrame") or button, "OVERLAY")
  if button.label then
    button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
  end
  button:SetScript("OnClick", onNearestClick)
  button:SetScript("OnEnter", onNearestEnter)
  button:SetScript("OnLeave", onNearestLeave)
  frame.nearestButton = button
  return button
end

-- Brief PR29: the "Show nearest" button in its own column on a "Sold by" header, hidden on every
-- other row.
local function applyNearestButton(frame, layout)
  local held = rawget(frame, "nearestButton")
  if not layout.nearest then
    if held then
      held:Hide()
    end
    return false
  end
  local button = nearestButton(frame)
  if not button or not place(frame, button, layout, "nearest", Tree.NEAREST_H) then
    return false
  end
  local label = button.label
  if label then
    setFont(label, layout.metaFontSize)
    setText(label, L["Show nearest"])
    textColor(label, "ITEMTREE_COLOR_TEXT_TITLE")
    if type(label.GetStringWidth) == "function" then
      local ok, width = pcall(label.GetStringWidth, label)
      if ok and tonumber(width) and tonumber(width) > 0 then
        Tree.nearestMeasured = tonumber(width)
      end
    end
  end
  button:Show()
  return true
end

-- E25: one cell of a strip, made the first time a row needs it and reused from then on. A cell
-- is a button so the icon can be clicked and hovered; the count beside it is the same "x2" the
-- quantity column writes.
local function stripCell(frame, index)
  frame.stripCells = frame.stripCells or {}
  local cell = frame.stripCells[index]
  if cell then
    return cell
  end
  cell = newFrame("Button", frame)
  if not cell then
    return nil
  end
  cell.owner = frame
  if type(cell.CreateTexture) == "function" then
    cell.art = cell:CreateTexture(nil, "ARTWORK")
    if cell.art then
      cell.art:SetAllPoints(cell)
    end
  end
  cell.label = newFontString(frame, "OVERLAY")
  if type(cell.RegisterForClicks) == "function" then
    cell:RegisterForClicks("LeftButtonUp")
  end
  cell:SetScript("OnClick", onStripCellClick)
  cell:SetScript("OnEnter", onStripCellEnter)
  cell:SetScript("OnLeave", hideHint)
  frame.stripCells[index] = cell
  return cell
end

local function hideStripCells(frame, from)
  local cells = rawget(frame, "stripCells")
  if type(cells) ~= "table" then
    return
  end
  for index = from or 1, #cells do
    local cell = cells[index]
    if cell then
      cell:Hide()
      if cell.label then
        cell.label:Hide()
      end
    end
  end
end

-- E25: the whole strip, drawn on its own row under the craft. Every cell hangs off the row's top
-- left at the x and line Tree.StripCells worked out, so a strip that wrapped puts its second
-- line under its first and the row is already tall enough to hold it. The root's own icon is
-- dimmed: it is the item the player is reading, and a mark on it would read as a badge.
local function applyStrip(frame, layout)
  if layout.kind ~= "strip" or type(layout.strip) ~= "table" then
    hideStripCells(frame)
    return false
  end
  local lineHeight = Theme.RowHeight(layout.density)
  local size = layout.iconSize or Tree.STRIP_ICON
  local used = 0
  for index, entry in ipairs(layout.strip.cells) do
    local cell = stripCell(frame, index)
    if not cell then
      break
    end
    used = index
    local part = entry.part or EMPTY
    cell.itemTreeKey = entry.key
    cell.itemTreeName = part.name
    cell.itemTreeCount = entry.text
    cell.itemTreeColor = qualityKey(part.quality)
    cell:SetSize(size, size)
    cell:ClearAllPoints()
    local top = (entry.line - 1) * lineHeight + math.floor((lineHeight - size) / 2)
    cell:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.stripLeft + entry.x, -top)
    if cell.art then
      if type(part.icon) == "string" and Assets.Has(part.icon) then
        Assets.Apply(cell.art, part.icon)
      elseif part.icon ~= nil then
        pcall(cell.art.SetTexture, cell.art, part.icon)
      else
        Assets.Apply(cell.art, "ICON_QUESTIONMARK")
      end
      cell.art:Show()
    end
    cell:SetAlpha(entry.root and Tree.STRIP_ROOT_ALPHA or 1)
    if cell.label then
      if entry.text ~= "" then
        cell.label:ClearAllPoints()
        cell.label:SetPoint("LEFT", cell, "RIGHT", Tree.STRIP_COUNT_GAP, 0)
        setFont(cell.label, layout.metaFontSize)
        setText(cell.label, entry.text)
        textColor(cell.label, "ITEMTREE_COLOR_TEXT_MUTED")
        cell.label:SetAlpha(entry.root and Tree.STRIP_ROOT_ALPHA or 1)
        cell.label:Show()
      else
        cell.label:Hide()
      end
    end
    cell:Show()
  end
  hideStripCells(frame, used + 1)
  return true
end

--------------------------------------------------------------------------------
-- E53: the portrait queue.
--
-- The rules and the constants behind them are at the head of this file. Everything here is one
-- queue, one OnUpdate driver that runs only while the queue has something in it, and one call
-- per frame out of it. Every pure part of it (what to queue, what to serve next, what to drop)
-- is a Tree.Portrait* function above the divider.
--------------------------------------------------------------------------------

-- Whether the portrait on a frame's icon is the one the row it is drawing now wants. A pooled
-- frame that comes back to the same creature keeps its portrait rather than blinking the kind
-- icon through, and asks the client for nothing at all.
local function portraitKept(frame, layout)
  -- Turning the setting off puts the kind icons back on the window that is already open, so a
  -- portrait is never kept once it is off: Frame.RefreshFromSettings redraws every row, and a
  -- row that keeps its portrait would be a row the setting did nothing to.
  if not Tree.PortraitsEnabled() then
    return false
  end
  local held = rawget(frame, "itemTreePortrait")
  return held ~= nil and held == (layout and layout.portrait or nil)
end

-- Takes the portrait off a recycled frame's icon, and its request out of the queue.
--
-- A portrait is a RENDER TARGET texture ("RTPortrait1" in the beta probe of 2026-09-20), so it
-- is not something the next SetTexture is guaranteed to wash away: Blizzard's own search rows
-- put the tex coords back and set a plain texture before they ask for another one
-- (Blizzard_EncounterJournal.lua:2532 and :2688 on the forever branch of Gethe/wow-ui-source).
-- This does the same, and it happens on EVERY row a pooled frame draws, so a creature portrait
-- can never linger on a vendor row or an item row.
local function portraitClear(frame, layout)
  Tree.PortraitDrop(Tree.portraits, frame)
  local icon = frame and frame.icon or nil
  if rawget(frame, "itemTreePortrait") == nil or not icon then
    return false
  end
  if portraitKept(frame, layout) then
    return false
  end
  frame.itemTreePortrait = nil
  if type(icon.SetTexCoord) == "function" then
    pcall(icon.SetTexCoord, icon, 0, 1, 0, 1)
  end
  if type(icon.SetTexture) == "function" then
    pcall(icon.SetTexture, icon, nil)
  end
  return true
end

-- Whether a queued request is still worth serving: the frame is still there, still shown, and
-- still drawing the very row that asked. A recycled, hidden or re-rooted row fails this and is
-- dropped on the next tick.
local function portraitLive(entry)
  local frame = type(entry) == "table" and entry.frame or nil
  if type(frame) ~= "table" then
    return false
  end
  if rawget(frame, "row") ~= entry.row then
    return false
  end
  local layout = rawget(frame, "layout")
  if type(layout) ~= "table" or layout.portrait ~= entry.display then
    return false
  end
  if type(frame.IsShown) == "function" and frame:IsShown() == false then
    return false
  end
  return true
end

-- The one client call, pcall'd. A client with no such function, or one that raises, stops this
-- session asking for good: every creature row keeps the kind icon it already drew, which is the
-- answer this whole feature is an improvement on rather than a replacement for.
local function portraitDraw(entry)
  local frame = entry.frame
  local icon = frame and frame.icon or nil
  local fn = globalFn("SetPortraitTextureFromCreatureDisplayID")
  if not fn or not icon then
    Tree.portraitsBroken = true
    return false
  end
  local ok = pcall(fn, icon, entry.display)
  if not ok then
    Tree.portraitsBroken = true
    return false
  end
  frame.itemTreePortrait = entry.display
  -- The portrait is round with clear corners, and the row's icon box wears a square gold edge.
  -- The edge goes while the portrait is up (it reads as a broken frame around a circle) and
  -- comes back with the kind icon the moment the frame draws anything else.
  local border = frame.iconBorder
  if border and type(border.Hide) == "function" then
    border:Hide()
  end
  return true
end

local function portraitStop()
  local driver = Tree.portraitDriver
  if driver and type(driver.Hide) == "function" then
    driver:Hide()
  end
  return false
end

--- One turn of the portrait driver: the dwell clock moves on, dead requests go, and at most
--- Tree.PORTRAIT_PER_FRAME rows are served. Answers how many portraits were asked for.
---
--- The clock is the driver's own accumulated elapsed rather than GetTime, because the driver
--- only runs while there is something to serve, which is exactly when the dwell has to be
--- measured, and it needs no client API at all.
function Tree.PortraitTick(elapsed)
  local queue = Tree.portraits
  if type(queue) ~= "table" or #queue == 0 then
    portraitStop()
    return 0
  end
  Tree.portraitClock = (Tree.portraitClock or 0) + (tonumber(elapsed) or 0)
  Tree.PortraitPrune(queue, portraitLive)
  local served = 0
  while served < Tree.PORTRAIT_PER_FRAME do
    local index = Tree.PortraitReady(queue, Tree.portraitClock, Tree.PORTRAIT_DWELL)
    if not index then
      break
    end
    local entry = table.remove(queue, index)
    served = served + 1
    if not portraitDraw(entry) then
      break
    end
  end
  if Tree.portraitsBroken then
    Tree.portraits = {}
  end
  if #(Tree.portraits or EMPTY) == 0 then
    portraitStop()
  end
  return served
end

-- The one driver, made on the first row that asks and hidden whenever the queue empties, so a
-- window full of vendor rows runs no OnUpdate at all.
local function portraitDriver()
  local driver = Tree.portraitDriver
  if driver then
    return driver
  end
  driver = newFrame("Frame", Tree.pane or rawget(_G, "UIParent"))
  if not driver then
    return nil
  end
  if type(driver.SetScript) ~= "function" then
    return nil
  end
  driver:SetScript("OnUpdate", function(_, elapsed)
    Tree.PortraitTick(elapsed)
  end)
  if type(driver.Hide) == "function" then
    driver:Hide()
  end
  Tree.portraitDriver = driver
  return driver
end

-- Asks for one row's portrait, which is all a row ever does: it joins the queue and its turn
-- comes, or it is dropped before it does. Answers whether anything was queued.
local function portraitAsk(frame, layout)
  if Tree.portraitsBroken then
    return false
  end
  local display = layout and layout.portrait or nil
  if type(display) ~= "number" or layout.kind ~= "row" then
    return false
  end
  -- The frame is already showing this very creature, so there is nothing to ask for.
  if portraitKept(frame, layout) then
    return false
  end
  if not Tree.PortraitsEnabled() then
    return false
  end
  if not globalFn("SetPortraitTextureFromCreatureDisplayID") then
    -- A client with no portrait call is not a fault to report on every row: the session simply
    -- stops asking and the kind icons stand.
    Tree.portraitsBroken = true
    return false
  end
  local icon = frame and frame.icon or nil
  if not icon or (type(icon.IsShown) == "function" and icon:IsShown() == false) then
    return false
  end
  Tree.portraits = Tree.portraits or {}
  local queued = Tree.PortraitPush(Tree.portraits, {
    frame = frame,
    row = rawget(frame, "row"),
    display = display,
    at = Tree.portraitClock or 0,
  }, Tree.PORTRAIT_QUEUE)
  if not queued then
    return false
  end
  local driver = portraitDriver()
  if driver and type(driver.Show) == "function" then
    driver:Show()
  end
  return true
end

local function applyIcon(frame, layout)
  local border = frame.iconBorder
  -- Before anything else: a pooled frame may have been a creature a moment ago, and the row it
  -- is about to draw is very likely not one. The one exception is the same creature coming back
  -- round, which keeps its portrait.
  local kept = portraitKept(frame, layout)
  portraitClear(frame, layout)
  if not place(frame, frame.icon, layout, "icon", layout.iconSize) then
    if border then
      border:Hide()
    end
    applyMark(frame, layout)
    applyCraft(frame, layout)
    return
  end
  local size = layout.iconSize or Tree.ICON
  frame.icon:SetSize(size, size)
  if kept then
    -- The portrait already on this icon is the one this row wants. Drawing the kind icon over it
    -- and asking for it again is a blink and a wasted call.
    applyMark(frame, layout)
    applyCraft(frame, layout)
    return
  end
  if layout.iconFile then
    pcall(frame.icon.SetTexture, frame.icon, layout.iconFile)
  elseif layout.iconAsset then
    Assets.Apply(frame.icon, layout.iconAsset)
  end
  if layout.iconColor then
    tint(frame.icon, layout.iconColor, 1)
  elseif type(frame.icon.SetVertexColor) == "function" then
    frame.icon:SetVertexColor(1, 1, 1)
  end
  if border then
    if layout.kind == "row" then
      -- Brief BQ15: a completed quest's square is pale green; every other row keeps the gold edge.
      -- Set on every draw, because the frame is pooled.
      tint(border, layout.iconBorderColor or "ITEMTREE_COLOR_BORDER_GOLD_DIM", 1)
      border:ClearAllPoints()
      border:SetPoint("TOPLEFT", frame.icon, "TOPLEFT", -1, 1)
      border:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", 1, -1)
      border:Show()
    else
      border:Hide()
    end
  end
  applyMark(frame, layout)
  applyCraft(frame, layout)
  -- The kind icon is on screen. Now, and only now, the row asks for the creature's own face.
  portraitAsk(frame, layout)
end

-- One small muted column: place it, font it, write it, and hide it where this kind of row has
-- no such column. The font goes on before the text, every time, because the frame is pooled
-- and the beta raises from inside SetText on a font string that has lost its font.
local function applyColumn(frame, fontString, layout, name, text, justify)
  if not place(frame, fontString, layout, name, layout.height) then
    return false
  end
  setFont(fontString, layout.metaFontSize)
  setText(fontString, text or "")
  textColor(fontString, layout.metaColor)
  if type(fontString.SetJustifyH) == "function" then
    fontString:SetJustifyH(justify)
  end
  -- Every column is one line, ended with the client's own ellipsis where the words do not fit.
  -- A font string wraps by default, and a column that wraps draws a row TALLER than Tree.Extent
  -- measured it at, which puts the pixels and the scroll range out of step: E54 found the zone
  -- column running "Stonetalon Mountains" onto a second line over the row below it. The name
  -- column has been held to one line this way since it started landing on its own numbers; this
  -- is the same treatment for the columns beside it. All three calls are optional on a client.
  for method, value in pairs({ SetWordWrap = false, SetNonSpaceWrap = false, SetMaxLines = 1 }) do
    if type(fontString[method]) == "function" then
      pcall(fontString[method], fontString, value)
    end
  end
  return true
end

-- Brief Z1: a zone column that is a link wears the link gold and carries a hit target over its own
-- words, no wider than the column; every other row puts the target away, because the frame is
-- pooled and the row drawn on it a moment ago may have been a link.
local function applyZoneLink(frame, layout)
  local hit = frame.zoneHit
  local words = frame.sourceZone
  local column = layout.columns and layout.columns.sourceZone or nil
  local text = layout.sourceZoneText
  if not layout.zoneLink or not column or not words or type(text) ~= "string" or text == "" then
    if hit then
      hit:Hide()
    end
    return false
  end
  textColor(words, Tree.ZONE_LINK_COLOR)
  if not hit then
    return false
  end
  local wide = tonumber(column.width) or Tree.SOURCE_ZONE
  if type(words.GetStringWidth) == "function" then
    local ok, measured = pcall(words.GetStringWidth, words)
    measured = ok and tonumber(measured) or nil
    if measured and measured > 0 and measured < wide then
      wide = measured
    end
  end
  hit:ClearAllPoints()
  hit:SetPoint("LEFT", words, "LEFT", 0, 0)
  hit:SetWidth(wide)
  hit:SetHeight(layout.height)
  hit:Show()
  return true
end

local function applyText(frame, layout)
  local justify = Tree.JUSTIFY[layout.columns.name and layout.columns.name.align or "left"] or "LEFT"
  if place(frame, frame.name, layout, "name", layout.fill and nil or layout.height) then
    setFont(frame.name, layout.fontSize)
    setText(frame.name, layout.richText or layout.text or "")
    textColor(frame.name, layout.nameColor, layout.nameAlpha)
    if type(frame.name.SetJustifyH) == "function" then
      frame.name:SetJustifyH(justify)
    end
    if type(frame.name.SetWordWrap) == "function" then
      frame.name:SetWordWrap(layout.wrap and true or false)
    end
    -- A row that does not wrap is one line, ended with the client's own ellipsis rather than
    -- run under the column beside it: a long name was landing on top of its own numbers. Both
    -- calls are optional on a client, so both are asked for and pcall'd.
    --
    -- A row that DOES wrap has to put both of them back, because the frame it is being drawn on
    -- was very likely an item row a moment ago and a font string held to one line does not wrap
    -- however wide it is. That is what made the empty state one line that ran off the pane.
    if not layout.wrap then
      if type(frame.name.SetNonSpaceWrap) == "function" then
        pcall(frame.name.SetNonSpaceWrap, frame.name, false)
      end
      if type(frame.name.SetMaxLines) == "function" then
        pcall(frame.name.SetMaxLines, frame.name, 1)
      end
    else
      if type(frame.name.SetNonSpaceWrap) == "function" then
        pcall(frame.name.SetNonSpaceWrap, frame.name, true)
      end
      if type(frame.name.SetMaxLines) == "function" then
        pcall(frame.name.SetMaxLines, frame.name, 0)
      end
    end
    if layout.fill then
      frame.name:SetPoint("TOP", frame, "TOP", 0, 0)
      frame.name:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    end
  end
  applyColumn(frame, frame.quantity, layout, "quantity", layout.quantityText, "RIGHT")
  applyColumn(frame, frame.meta, layout, "meta", layout.metaText, "LEFT")
  applyColumn(frame, frame.count, layout, "count", layout.countText, "RIGHT")
  applyColumn(frame, frame.sourceType, layout, "sourceType", layout.sourceTypeText, "LEFT")
  -- Brief P6b: the side icon leads the zone column's words, where the row names an NPC with a side.
  local zoneText = layout.sourceZoneText
  if layout.side then
    zoneText = Tree.SideZoneText(zoneText, layout.side, layout.metaFontSize)
  end
  applyColumn(frame, frame.sourceZone, layout, "sourceZone", zoneText, "LEFT")
  if applyColumn(frame, frame.sourceRate, layout, "sourceRate", layout.sourceRateText, "RIGHT") then
    -- Brief GS3: the guess colour over the meta colour applyColumn just put on it; every other row
    -- keeps that, so a pooled frame never carries the colour on to the row drawn on it next.
    if layout.sourceRateColor then
      textColor(frame.sourceRate, layout.sourceRateColor)
    end
  end
  applyZoneLink(frame, layout)
end

-- What a badge cluster shows the old to new lines for on hover. The method arrived with the
-- badges this round, so it is only called where the cluster carries one, and a cluster on a
-- pooled frame reused for a row Core keeps no changes against is cleared rather than left
-- pointing at the item before it.
local function setClusterSubject(cluster, diffKind, diffId)
  if type(cluster) ~= "table" or type(cluster.SetSubject) ~= "function" then
    return false
  end
  return (pcall(cluster.SetSubject, cluster, diffKind, diffId))
end

-- What the facts under this cluster's marks are based on, which picks the meaning line a hovered
-- badge draws. Cleared the same way the subject is, so a pooled frame never keeps the wording of
-- the row before it.
local function setClusterBasis(cluster, basis)
  if type(cluster) ~= "table" or type(cluster.SetBasis) ~= "function" then
    return false
  end
  return (pcall(cluster.SetBasis, cluster, basis))
end

-- The row's own note, for a Community note mark's hover (brief E93). Cleared the same way the
-- basis is, so a pooled frame never says the note of the row before it.
local function setClusterNote(cluster, note)
  if type(cluster) ~= "table" or type(cluster.SetNote) ~= "function" then
    return false
  end
  return (pcall(cluster.SetNote, cluster, note))
end

local function applyBadges(frame, layout)
  local wanted = layout.badgeSize == Tree.BADGE_TREE and frame.treeBadges or frame.listBadges
  local other = wanted == frame.treeBadges and frame.listBadges or frame.treeBadges
  if other then
    setClusterSubject(other, nil, nil)
    setClusterBasis(other, nil)
    setClusterNote(other, nil)
    other:Hide()
  end
  if not wanted then
    return
  end
  setClusterSubject(wanted, layout.diffKind, layout.diffId)
  setClusterBasis(wanted, layout.badgeBasis)
  setClusterNote(wanted, layout.badgeNote)
  if not place(frame, wanted, layout, "badges", nil) then
    return
  end
  wanted:SetKinds(layout.badges or EMPTY)
end

local function applyChevron(frame, layout)
  local chevron = frame.chevron
  if not chevron then
    return
  end
  if not place(frame, chevron, layout, "chevron", Tree.CHEVRON) then
    return
  end
  chevron:SetSize(Tree.CHEVRON, Tree.CHEVRON)
  if layout.chevronAsset then
    Assets.Apply(chevron.art, layout.chevronAsset)
    -- E25: a craft row whose only child is its ingredient group draws this dimmer, so the
    -- chevron still says "there is something under here" without promising another branch.
    tint(chevron.art, layout.chevronColor or Tree.CHEVRON_COLOR, 1)
    chevron.art:Show()
    chevron:Show()
  elseif layout.chevron == "loop" then
    -- A loop row cannot open, so the chevron slot carries the ring instead of an arrow.
    Assets.Apply(chevron.art, "BADGE_RING")
    tint(chevron.art, "ITEMTREE_COLOR_TEXT_DISABLED", 1)
    chevron.art:Show()
    chevron:Show()
  else
    chevron:Hide()
  end
end

local function applyRow(frame, row, density, opts)
  local layout = Tree.Layout(row, density, opts)
  frame.row = row
  frame.layout = layout
  frame:SetHeight(layout.height)
  frame:SetAlpha(layout.alpha or 1)

  if layout.background then
    tint(frame.background, layout.background, layout.backgroundAlpha)
    frame.background:Show()
  else
    frame.background:Hide()
  end
  if layout.divider then
    frame.divider:ClearAllPoints()
    frame.divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.divider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    tint(frame.divider, layout.dividerColor or Tree.BORDER_COLOR, 1)
    frame.divider:Show()
  else
    frame.divider:Hide()
  end
  if frame.topBorder then
    if layout.topBorder then
      frame.topBorder:ClearAllPoints()
      frame.topBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
      frame.topBorder:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
      tint(frame.topBorder, layout.borderColor or Tree.BORDER_COLOR, 1)
      frame.topBorder:Show()
    else
      frame.topBorder:Hide()
    end
  end

  applyChevron(frame, layout)
  applyIcon(frame, layout)
  applyText(frame, layout)
  applyBadges(frame, layout)
  -- E25: both are hidden on every row that does not ask for them, because the frame is pooled
  -- and the row drawn on it a moment ago may have been a craft with its strip open.
  applyStripButton(frame, layout)
  applyStrip(frame, layout)
  -- Brief PR29: hidden on every row but a "Sold by" header that asks, for the same pooled reason.
  applyNearestButton(frame, layout)
  return layout
end

-- Walks whatever is drawing rows right now, ScrollBox managed frames or the pool.
local function eachRowFrame(fn)
  local box = Tree.scrollBox
  if box and type(box.ForEachFrame) == "function" then
    pcall(box.ForEachFrame, box, fn)
    return
  end
  for _, frame in ipairs(Tree.pool or EMPTY) do
    if rawget(frame, "row") then
      fn(frame, frame.row)
    end
  end
end

-- Brief E2E-1 (the e2e plan's additions 1 and 2): the drawn row walk and a row's hover, made
-- reachable for the developer only e2e run, which reads what the rows drew and puts a row's tooltip
-- up. Nothing changes what a row draws; the hover is the row's own, without the keyboard capture a
-- real pointer turns on (onRowEnter).
Tree.EachRowFrame = eachRowFrame
function Tree.ShowRowTooltip(frame)
  return showRowTooltip(frame)
end

-- The highlight is the pane's own state, not the view model's, so moving it redraws nothing.
local function applySelection()
  local rows = Tree.rows or EMPTY
  local current = Tree.cursor and rows[Tree.cursor] or nil
  eachRowFrame(function(frame, row)
    local selection, bar = rawget(frame, "selection"), rawget(frame, "selectionBar")
    if not selection then
      return
    end
    if current ~= nil and row == current then
      selection:Show()
      if bar then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        bar:Show()
      end
    else
      selection:Hide()
      if bar then
        bar:Hide()
      end
    end
  end)
end

--- Brief Z1: picks the source one row of a zone's Here tab names for that zone's Map tab, and moves
--- the pane's own highlight onto the row so the pick shows. The pick is Core's session state
--- (ViewModel.PickZoneSource); nothing is saved and nothing is redrawn but the highlight.
function Tree.PickZoneRow(rowKey)
  local rows = Tree.rows or EMPTY
  local index, row = nil, nil
  for at, held in ipairs(rows) do
    if held.key == rowKey then
      index, row = at, held
      break
    end
  end
  local link = Tree.ZoneLink(row)
  if not link or link.action ~= "pick" then
    return false
  end
  local ViewModel = ItemTree.ViewModel
  local vm = Tree.vm
  local root = type(vm) == "table" and vm.root or nil
  if type(ViewModel) ~= "table" or type(ViewModel.PickZoneSource) ~= "function" then
    return false
  end
  -- Brief Z2: the row's own item goes with the source, so the Map view's item column opens on it.
  local edge = type(row) == "table" and type(row.edge) == "table" and row.edge or nil
  local item = edge and type(edge.target) == "string" and edge.target or nil
  local ok, kept = pcall(ViewModel.PickZoneSource, root, link.pick, item)
  if not ok or not kept then
    return false
  end
  Tree.cursor = index
  if Tree.pane then
    pcall(applySelection)
  end
  return true
end

--- Brief N1: opens the page the source one row of a zone's Here tab names (Tree.ZoneLink's "source"
--- link), through the window's own Frame.Open, which runs under the error boundary like every
--- other open (UI/Frame.lua Frame.GUARDED). The row's Map tab pick, where it carries one, is made
--- first (ViewModel.PickZoneSource, session state only), so the zone's Map tab still shows that
--- source when the player comes back. Answers whether the window took the key.
function Tree.OpenZoneSource(rowKey)
  local row = nil
  for _, held in ipairs(Tree.rows or EMPTY) do
    if held.key == rowKey then
      row = held
      break
    end
  end
  local link = Tree.ZoneLink(row)
  if not link or link.action ~= "source" then
    return false
  end
  local ViewModel = ItemTree.ViewModel
  local vm = Tree.vm
  local root = type(vm) == "table" and vm.root or nil
  if link.pick and type(ViewModel) == "table" and type(ViewModel.PickZoneSource) == "function" then
    local edge = type(row.edge) == "table" and row.edge or nil
    local item = edge and type(edge.target) == "string" and edge.target or nil
    pcall(ViewModel.PickZoneSource, root, link.pick, item)
  end
  return askFrameToOpen(link.key)
end

local function paneSize()
  local pane = Tree.pane
  local width, height = 0, 0
  if pane and type(pane.GetWidth) == "function" then
    local ok, value = pcall(pane.GetWidth, pane)
    width = ok and tonumber(value) or 0
  end
  if pane and type(pane.GetHeight) == "function" then
    local ok, value = pcall(pane.GetHeight, pane)
    height = ok and tonumber(value) or 0
  end
  return width, height
end

-- What the list itself has, which is the pane less whatever the search box holds off the top
-- and less the panel's own hairline top and bottom. The box is the pane's own and is never
-- counted as room for a row, and neither is the edge the panel draws around the rows.
local function listSize()
  local width, height = paneSize()
  return width, math.max(0, height - (Tree.listTop or 0) - 2 * Tree.BORDER)
end

-- What the client makes of a string in the pane's own body face, or nil where it will not say.
-- A hidden font string measures exactly like a drawn one, and the font goes on before the text
-- every time, because the beta raises from inside SetText on a font string with no font.
local function measureText(text, fontSize)
  local ruler = Tree.ruler
  if not ruler or type(ruler.GetStringWidth) ~= "function" then
    return nil
  end
  setFont(ruler, fontSize)
  setText(ruler, text or "")
  local ok, width = pcall(ruler.GetStringWidth, ruler)
  if not ok or type(width) ~= "number" or width <= 0 then
    return nil
  end
  return math.ceil(width)
end

-- The count column for this draw, worked out once for the whole list so every header's badges
-- sit in the same column whatever their own count reads.
local function measureCountColumn(rows)
  local widest = Tree.WidestCount(rows)
  local fontSize = Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_SM
  Tree.countWidth = Tree.CountWidth(widest, fontSize, measureText(widest, fontSize))
  return Tree.countWidth
end

-- The room a row really has: the pane less the panel's left hairline and less whatever the
-- right edge is giving up to a scroll bar right now. Nothing is held back for a bar that is
-- not drawn, so a list that fits fills the panel to its inner edge.
local function rowOpts()
  local width, height = listSize()
  local inset = Tree.BORDER + Tree.ListRightInset(Tree.scrollbarShown)
  local rowWidth = width > inset and width - inset or nil
  -- E25: the mode and the open strips travel with the row options, so Tree.Layout stays pure and
  -- decides nothing from the settings table itself. Off is the ordinary case and adds two keys
  -- that nothing reads.
  return {
    width = rowWidth,
    height = height,
    countWidth = Tree.countWidth,
    craftIngredients = Tree.CraftIngredients(),
    strips = Tree.strips,
  },
    height
end

-- One height per row, in order, and what they come to. Tree.Extent and not Tree.Layout: a
-- category of 1,500 rows is measured on every draw and laid out only where it is drawn, so an
-- extent must not build a table. The gutter the scrollbar sits in is the same whether the bar
-- is drawn or not, so hiding it never re-flows a single row.
local function rowExtents(rows, density, opts)
  local extents, total = {}, 0
  for index, row in ipairs(rows) do
    local height = Tree.Extent(row, density, opts) or 0
    extents[index] = height
    total = total + height
  end
  return extents, total
end

-- The wheel step, handed to the client on every draw. The view owns it; a box that carries the
-- call passes it straight to its own view, so either is the same thing and whichever the client
-- offers is used. Guarded and pcalled like every other client call: a client with neither keeps
-- whatever it worked out for itself. See Tree.WheelStep for why the fallback is wrong for us.
local function applyPanExtent(density)
  local step = Tree.WheelStep(density)
  for _, target in ipairs({ Tree.view, Tree.scrollBox }) do
    if type(target) == "table" and type(target.SetPanExtent) == "function" then
      if pcall(target.SetPanExtent, target, step) then
        Tree.panExtent = step
        return true
      end
    end
  end
  return false
end

-- Where the list is scrolled to, in pixels from the top of the whole list, or nil for a client
-- that will not say. The ScrollBox holds a percentage of its own range and derives the pixels
-- from it; the fallback pool path keeps the pixels itself in Tree.offset.
local function scrollOffset()
  local box = Tree.scrollBox
  if type(box) ~= "table" then
    return math.max(0, tonumber(Tree.offset) or 0)
  end
  if type(box.GetDerivedScrollOffset) == "function" then
    local ok, value = pcall(box.GetDerivedScrollOffset, box)
    if ok and tonumber(value) then
      return math.max(0, tonumber(value))
    end
  end
  -- The other shape: the percentage alone, against the range the pane measured this draw.
  if type(box.GetScrollPercentage) == "function" then
    local ok, value = pcall(box.GetScrollPercentage, box)
    if ok and tonumber(value) then
      local percent = math.max(0, math.min(1, tonumber(value)))
      local range = math.max(0, (tonumber(Tree.extent) or 0) - (tonumber(Tree.paneHeight) or 0))
      return percent * range
    end
  end
  return nil
end

-- Which row the top of the pane is really showing, from the offset the client is at and the
-- extents this draw measured: the pane's own arithmetic (Tree.Window), over the very list the
-- pane holds. The client's GetDataIndexBegin is the last resort rather than the first, because
-- it answers about the list the box laid out, which is not always the list the pane just handed
-- it, and on a client that reports no scroll at all it never moves off the first row.
-- known is the offset the pane has just PUT the list at (brief E61), which is the honest answer
-- on the frame a restore is drawn: the box has been told a percentage but its own derived range
-- is still the old list's until it lays out, so asking it back would pin the header from the
-- wrong place. Anything else, including the box handed in as the callback's owner, reads the
-- client the way it always did.
local function firstVisibleRow(known)
  local offset = type(known) == "number" and known or scrollOffset()
  local extents = Tree.extents
  if offset and type(extents) == "table" and #extents > 0 then
    local first = Tree.Window(extents, offset, tonumber(Tree.paneHeight) or 0)
    if first > 0 then
      return first
    end
  end
  local box = Tree.scrollBox
  if type(box) == "table" and type(box.GetDataIndexBegin) == "function" then
    local ok, value = pcall(box.GetDataIndexBegin, box)
    local index = ok and tonumber(value) or nil
    if index and index >= 1 then
      return index
    end
  end
  return math.max(1, tonumber(Tree.firstVisible) or 1)
end

-- The bar the pane is scrolled by, whichever path drew the list. rawget, because a frame
-- answers a missing field with nil and nothing else should be mistaken for a bar.
local function scrollBars()
  local bars = {}
  if type(Tree.scrollBar) == "table" then
    bars[#bars + 1] = Tree.scrollBar
  end
  local scroll = Tree.scroll
  local bar = type(scroll) == "table" and rawget(scroll, "ScrollBar") or nil
  if type(bar) == "table" then
    bars[#bars + 1] = bar
  end
  return bars
end

-- A full height bar over a list that fits is chrome that says nothing, so the bar is drawn
-- only while there is something to scroll. Re-evaluated on every draw, which is every show,
-- every refresh and every size change.
local function updateScrollBar(total, height)
  Tree.extent = total
  local needed = Tree.Overflows(total, height)
  Tree.scrollbarShown = needed
  for _, bar in ipairs(scrollBars()) do
    if needed then
      bar:Show()
    else
      bar:Hide()
    end
  end
  return needed
end

-- The right edge the list runs to, re-applied whenever the scroll bar arrives or goes. The
-- ScrollBox sizes its rows from the box, and the pool anchors its rows to the content frame,
-- so moving this one edge is what makes a row's divider, its category band and its hover wash
-- fill the panel instead of stopping at a gutter with nothing in it.
local function anchorList()
  local right = Tree.ListRightInset(Tree.scrollbarShown)
  if Tree.listRight == right then
    return false
  end
  Tree.listRight = right
  local pane = Tree.pane
  local edge = Tree.BORDER
  local box = Tree.scrollBox
  if box and pane and type(box.SetPoint) == "function" then
    pcall(box.SetPoint, box, "BOTTOMRIGHT", pane, "BOTTOMRIGHT", -right, edge)
    return true
  end
  local scroll = Tree.scroll
  if scroll and pane and type(scroll.SetPoint) == "function" then
    pcall(scroll.SetPoint, scroll, "BOTTOMRIGHT", pane, "BOTTOMRIGHT", -right, edge)
    return true
  end
  return false
end

-- ScrollBox has no sticky row support, so the header is a row frame re-anchored just above
-- the scroll box, mirroring the first visible category. The real row keeps its place in the
-- data provider. See docs/design-deviations.md.
local function updateSticky(known)
  local header = Tree.sticky
  if not header then
    return
  end
  local rows = Tree.rows or EMPTY
  local first = firstVisibleRow(known)
  Tree.firstVisible = first
  local index = Tree.StickyIndex(rows, first)
  if not index then
    header:Hide()
    return
  end
  local opts = rowOpts()
  opts.sticky = true
  applyRow(header, rows[index], Tree.Density(), opts)
  local top = Tree.BORDER + (Tree.listTop or 0)
  header:ClearAllPoints()
  header:SetPoint("TOPLEFT", Tree.pane, "TOPLEFT", Tree.BORDER, -top)
  header:SetPoint("TOPRIGHT", Tree.pane, "TOPRIGHT", -Tree.ListRightInset(Tree.scrollbarShown), -top)
  header:Show()
end

--- What the pane holds for the page that is up (brief E61): where the rows are scrolled to, in
--- whole pixels from the top of the list. One number, and no row, key or height of the list's
--- own, which is the whole of what the window writes down about this pane. The text in the search
--- box is not here because it is not the pane's to own: it goes in and comes out through
--- ItemTree.UI.Frame.SetTextFilter, and the window is what remembers it.
---
--- The offset is the honest reader E54 left (scrollOffset), so it is the pixels the client is
--- really at whichever way the pane drew the list.
function Tree.Snapshot()
  local offset = tonumber(scrollOffset()) or 0
  return { offset = math.max(0, math.floor(offset + 0.5)) }
end

-- Puts the ScrollBox at a pixel offset, now, with no glide: a page coming back has to be where
-- the player left it on the frame it is drawn, not sliding towards it. The share is the pane's
-- own arithmetic over the heights this draw measured (Tree.ScrollPercent says why), and
-- ScrollToOffset is the fallback for a client that carries it and not SetScrollPercentage. Both
-- are ScrollBoxBaseMixin on wow-ui-source branch `forever`, and both are pcalled, so a client
-- with neither leaves the list at the top rather than raising.
local function scrollBoxTo(offset, total, height)
  local box = Tree.scrollBox
  if type(box) ~= "table" then
    return false
  end
  if type(box.SetScrollPercentage) == "function" then
    if pcall(box.SetScrollPercentage, box, Tree.ScrollPercent(offset, total, height), true) then
      return true
    end
  end
  if type(box.ScrollToOffset) == "function" then
    return (pcall(box.ScrollToOffset, box, offset, true))
  end
  return false
end

--------------------------------------------------------------------------------
-- The search box, which is the pane's own: controls/SearchBox.jsx across the top
--------------------------------------------------------------------------------

-- Four hairlines around a frame, the same inset edge the list panel draws, handed back as an
-- array so the focus colour can be put on all of them at once.
local function insetEdges(frame, colorKey)
  if type(frame.CreateTexture) ~= "function" then
    return nil
  end
  local edges = {}
  for _, name in ipairs({ "top", "bottom", "left", "right" }) do
    local line = frame:CreateTexture(nil, "BORDER")
    if not line then
      return nil
    end
    Assets.Apply(line, "FILL_WHITE8X8")
    tint(line, colorKey, 1)
    edges[#edges + 1] = line
    edges[name] = line
  end
  edges.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  edges.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  edges.top:SetHeight(Tree.BORDER)
  edges.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  edges.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  edges.bottom:SetHeight(Tree.BORDER)
  edges.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  edges.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  edges.left:SetWidth(Tree.BORDER)
  edges.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  edges.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  edges.right:SetWidth(Tree.BORDER)
  return edges
end

-- A focused box takes the design's focus border, but only where the pane drew the border: a
-- client that carried SearchBoxTemplate brought its own art and keeps it.
local function searchFocus(focused)
  local box = Tree.search
  local edges = box and rawget(box, "itemTreeEdges") or nil
  if not edges then
    return false
  end
  local key = focused and "ITEMTREE_COLOR_STATE_FOCUS" or "ITEMTREE_COLOR_BORDER_GOLD_DIM"
  for _, edge in ipairs(edges) do
    tint(edge, key, 1)
  end
  return true
end

-- The placeholder and the clear button both follow whether there is anything in the box. Only
-- the ones the pane built are touched: a template brings its own and shows them itself.
local function updateSearchChrome(text)
  local box = Tree.search
  if not box then
    return false
  end
  local empty = text == nil or text == ""
  local placeholder = rawget(box, "itemTreePlaceholder")
  if placeholder and rawget(box, "itemTreeOwnsPlaceholder") then
    if empty then
      placeholder:Show()
    else
      placeholder:Hide()
    end
  end
  local clear = rawget(box, "itemTreeClear")
  if clear and rawget(box, "itemTreeOwnsClear") then
    if empty then
      clear:Hide()
    else
      clear:Show()
    end
  end
  return true
end

-- The box says which of the two directions is being narrowed, and the window can change that
-- under the pane, so the words are re-read on every draw and written only when they differ.
local function updatePlaceholderText()
  local box = Tree.search
  local placeholder = box and rawget(box, "itemTreePlaceholder") or nil
  if not placeholder then
    return false
  end
  local text = Tree.PlaceholderText()
  if rawget(box, "itemTreePlaceholderText") == text then
    return false
  end
  box.itemTreePlaceholderText = text
  return setText(placeholder, text)
end

-- Writes the filter back into the box, which is what the window clearing the filter on a
-- re-root looks like from in here. A box already carrying it, spaces and all, is left alone,
-- so nothing ever fights a player halfway through a word.
local function syncSearchBox(filter)
  local box = Tree.search
  if not box or type(box.GetText) ~= "function" or type(box.SetText) ~= "function" then
    Tree.searchText = filter
    return false
  end
  local ok, current = pcall(box.GetText, box)
  current = (ok and type(current) == "string") and current or ""
  if current:match("^%s*(.-)%s*$") == filter then
    Tree.searchText = current
    updateSearchChrome(current)
    return false
  end
  Tree.searchText = filter
  pcall(box.SetText, box, filter)
  updateSearchChrome(filter)
  return true
end

-- The window's half of the search: it is told, and it tells the pane back through
-- Tree.SetTextFilter, so there is one path in and one path out and the window always knows
-- what the tree is filtered by. A window that has not grown the entry point yet is filtered
-- directly rather than not at all.
local function applyFilter(text)
  local frame = frameModule()
  if frame and type(frame.SetTextFilter) == "function" then
    return (pcall(frame.SetTextFilter, text))
  end
  Tree.SetTextFilter(text)
  return false
end

-- C_Timer.After holds a keystroke back so a fast typist pays for one scan of the rows rather
-- than one per letter; a client with no C_Timer filters on the keystroke itself. The timer
-- reads the text that is current when it fires, so a burst ends in one filter.
local function queueFilter(text)
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    local token = (Tree.searchToken or 0) + 1
    Tree.searchToken = token
    local ok = pcall(timer.After, Tree.SEARCH_DEBOUNCE, function()
      if Tree.searchToken == token then
        applyFilter(Tree.searchText or "")
      end
    end)
    if ok then
      return true
    end
  end
  applyFilter(text)
  return false
end

--- A keystroke in the pane's search box. Returns whether anything changed, which is false for
--- a write that says what the box already said: the client fires OnTextChanged for its own
--- SetText as well as for a player's typing.
function Tree.SetSearchText(text)
  text = type(text) == "string" and text or ""
  updateSearchChrome(text)
  if text == Tree.searchText then
    return false
  end
  Tree.searchText = text
  queueFilter(text)
  return true
end

--- Escape, or the clear button: the box empties, the filter goes with it and the box gives the
--- keyboard back. Returns whether there was anything to clear.
function Tree.ClearSearch()
  local cleared = (Tree.searchText or "") ~= ""
  local box = Tree.search
  if box and type(box.SetText) == "function" then
    pcall(box.SetText, box, "")
  end
  Tree.SetSearchText("")
  if box and type(box.ClearFocus) == "function" then
    pcall(box.ClearFocus, box)
  end
  return cleared
end

-- A script on the box. HookScript is preferred so nothing a template already put there stops
-- working, and a frame that says it does not carry the script is left alone.
local function attachScript(frame, script, handler)
  if type(frame) ~= "table" then
    return false
  end
  if type(frame.HasScript) == "function" then
    local ok, has = pcall(frame.HasScript, frame, script)
    -- Only an explicit no is taken as one: a client that answers nothing has not said the
    -- frame lacks the script, and HookScript is pcalled anyway.
    if ok and has == false then
      return false
    end
  end
  if type(frame.HookScript) == "function" and pcall(frame.HookScript, frame, script, handler) then
    return true
  end
  if type(frame.SetScript) == "function" and pcall(frame.SetScript, frame, script, handler) then
    return true
  end
  return false
end

-- The little cross that empties the box, drawn only while there is something in it. A template
-- that brought its own keeps it, and then the template decides when it shows.
local function buildClearButton(box)
  local existing = rawget(box, "clearButton")
  if type(existing) == "table" then
    box.itemTreeClear = existing
    return existing
  end
  local button = newFrame("Button", box)
  if not button then
    return nil
  end
  button:SetSize(Tree.SEARCH_ICON, Tree.SEARCH_ICON)
  button:SetPoint("RIGHT", box, "RIGHT", -Tree.GUTTER, 0)
  if type(button.CreateTexture) == "function" then
    local art = button:CreateTexture(nil, "ARTWORK")
    if art then
      art:SetAllPoints(button)
      Assets.Apply(art, "ICON_REDX")
      tint(art, "ITEMTREE_COLOR_TEXT_MUTED", 1)
      button.art = art
    end
  end
  if type(button.RegisterForClicks) == "function" then
    button:RegisterForClicks("LeftButtonUp")
  end
  button:SetScript("OnClick", function()
    Tree.ClearSearch()
  end)
  button:Hide()
  box.itemTreeClear = button
  box.itemTreeOwnsClear = true
  return button
end

-- The design's SearchBox across the top of the pane: the glyph, the text, and the cross, in an
-- inset box one control high. The client's own SearchBoxTemplate is taken where there is one,
-- because it brings the art, the instructions font string and the clear button; its scripts are
-- hooked rather than replaced so none of that stops working. Everything it does not bring is
-- built here, and every font string is created from a client font object first, because the
-- beta raises "FontString:SetText(): Font not set" on one that was never given a font.
local function buildSearchBox(pane)
  local box = newTemplatedFrame("EditBox", pane, Tree.SEARCH_TEMPLATE)
  local templated = box ~= nil
  if not box then
    box = newFrame("EditBox", pane)
  end
  if not box then
    return nil
  end
  box.itemTreeTemplated = templated
  box:SetHeight(Tree.SEARCH_H)
  -- The client's own template hangs its left border art outside the edit box, so a box
  -- anchored flush to the pane drew its edge left of the list panel under it and the gap to
  -- the sidebar read as two different gaps. The frame is pushed in by exactly that overhang,
  -- which puts both drawn edges on the panel's own.
  local searchLeft, searchRight = Tree.SearchInsets(templated)
  box:SetPoint("TOPLEFT", pane, "TOPLEFT", searchLeft, 0)
  box:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -searchRight, 0)
  -- The window must not take the keyboard when it opens. Nothing here ever calls SetFocus.
  if type(box.SetAutoFocus) == "function" then
    pcall(box.SetAutoFocus, box, false)
  end
  if type(box.EnableMouse) == "function" then
    box:EnableMouse(true)
  end
  if type(box.SetMultiLine) == "function" then
    pcall(box.SetMultiLine, box, false)
  end
  if type(box.SetFont) == "function" then
    local size = Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_MD
    local ok, applied = pcall(box.SetFont, box, Theme.fonts.ITEMTREE_FONT_BODY, size, "")
    if not ok or applied == false then
      fallbackFont(box)
    end
  end
  ensureFont(box)
  textColor(box, "ITEMTREE_COLOR_TEXT_BODY")

  if not templated and type(box.CreateTexture) == "function" then
    local fill = box:CreateTexture(nil, "BACKGROUND")
    if fill then
      Assets.Apply(fill, "FILL_WHITE8X8")
      tint(fill, Tree.PANEL_SURFACE, 1)
      fill:SetAllPoints(box)
      fill:Show()
      box.itemTreeFill = fill
    end
    box.itemTreeEdges = insetEdges(box, Tree.PANEL_BORDER)
  end

  local icon = rawget(box, "searchIcon")
  if type(icon) ~= "table" and type(box.CreateTexture) == "function" then
    icon = box:CreateTexture(nil, "ARTWORK")
    if icon then
      icon:SetSize(Tree.SEARCH_ICON, Tree.SEARCH_ICON)
      icon:SetPoint("LEFT", box, "LEFT", Tree.GUTTER, 0)
      Assets.Apply(icon, "ICON_SEARCH")
      tint(icon, "ITEMTREE_COLOR_TEXT_MUTED")
      icon:Show()
    end
  end
  box.itemTreeIcon = icon

  local inset = Tree.GUTTER * 2 + Tree.SEARCH_ICON
  if type(box.SetTextInsets) == "function" then
    pcall(box.SetTextInsets, box, inset, inset, 0, 0)
  end
  buildClearButton(box)

  local instructions = rawget(box, "Instructions")
  if type(instructions) == "table" and type(instructions.SetText) == "function" then
    -- The template shows and hides its own instructions, so only the words are ours.
    ensureFont(instructions)
    box.itemTreePlaceholder = instructions
  else
    local placeholder = newFontString(box, "ARTWORK")
    if placeholder then
      setFont(placeholder, Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_MD)
      textColor(placeholder, "ITEMTREE_COLOR_TEXT_DISABLED")
      placeholder:SetPoint("LEFT", box, "LEFT", inset, 0)
      placeholder:SetPoint("RIGHT", box, "RIGHT", -inset, 0)
      if type(placeholder.SetJustifyH) == "function" then
        placeholder:SetJustifyH("LEFT")
      end
      placeholder:Show()
      box.itemTreePlaceholder = placeholder
      box.itemTreeOwnsPlaceholder = true
    end
  end

  attachScript(box, "OnTextChanged", function(self)
    local text = type(self.GetText) == "function" and self:GetText() or ""
    Tree.SetSearchText(type(text) == "string" and text or "")
  end)
  attachScript(box, "OnEscapePressed", function(self)
    Tree.ClearSearch()
    if type(self.ClearFocus) == "function" then
      pcall(self.ClearFocus, self)
    end
  end)
  attachScript(box, "OnEnterPressed", function(self)
    if type(self.ClearFocus) == "function" then
      pcall(self.ClearFocus, self)
    end
  end)
  attachScript(box, "OnEditFocusGained", function()
    searchFocus(true)
  end)
  attachScript(box, "OnEditFocusLost", function()
    searchFocus(false)
  end)
  return box
end

-- The designed empty state, for the sources view of an item nothing has anything to say about
-- yet. It is a block over the list panel rather than a row in it: a row is one font string, and
-- this carries an illustration, a heading and a paragraph. Tree.EmptyState decides which one is
-- drawn and Tree.EmptyBlock lays it out, both with no frame in front of them, so everything
-- below only places what they said.

-- One wrapped, centred line of the block, made the first time it is asked for.
local function emptyLine(block, index)
  local line = block.lines[index]
  if not line then
    line = newFontString(block, "OVERLAY")
    block.lines[index] = line
  end
  return line
end

-- Every string in the block wraps inside the same paragraph width, which is what the owner's
-- one line that ran off the pane was missing. SetMaxLines is put back to no limit every time,
-- because a font string held to one line does not wrap however wide it is.
local function wrapText(fontString, width, text, colorKey, size, face)
  if not fontString then
    return false
  end
  setFont(fontString, size, face)
  textColor(fontString, colorKey)
  if type(fontString.SetWidth) == "function" then
    fontString:SetWidth(width)
  end
  if type(fontString.SetJustifyH) == "function" then
    fontString:SetJustifyH("CENTER")
  end
  if type(fontString.SetWordWrap) == "function" then
    fontString:SetWordWrap(true)
  end
  if type(fontString.SetNonSpaceWrap) == "function" then
    pcall(fontString.SetNonSpaceWrap, fontString, true)
  end
  if type(fontString.SetMaxLines) == "function" then
    pcall(fontString.SetMaxLines, fontString, 0)
  end
  setText(fontString, text)
  fontString:Show()
  return true
end

local function buildEmptyBlock(pane)
  local block = newFrame("Frame", pane)
  if not block then
    return nil
  end
  block.lines = {}
  -- The block itself takes no mouse: it must leave the pane's own hover and keyboard capture
  -- alone.
  if type(block.EnableMouse) == "function" then
    block:EnableMouse(false)
  end
  -- Over the list rather than beside it, so the block is drawn in front of the scroll box under
  -- it. Both are the pane's children and the client would otherwise leave them on the same
  -- level.
  if type(block.SetFrameLevel) == "function" and type(pane.GetFrameLevel) == "function" then
    local ok, level = pcall(pane.GetFrameLevel, pane)
    if ok and type(level) == "number" then
      pcall(block.SetFrameLevel, block, level + 10)
    end
  end
  if type(block.CreateTexture) == "function" then
    block.art = block:CreateTexture(nil, "ARTWORK")
  end
  block.heading = newFontString(block, "OVERLAY")
  block:Hide()
  Tree.empty = block
  return block
end

-- Draws the designed empty state over the list panel, or takes it away again. spec is what
-- Tree.EmptyState answered, and nil is every other list: the rows themselves, or a view that
-- wants nothing but its own wrapped line.
local function showEmptyBlock(spec)
  local block = Tree.empty
  if not block then
    return false
  end
  if type(spec) ~= "table" then
    block:Hide()
    return false
  end
  local width, height = listSize()
  local layout = Tree.EmptyBlock(width, height, spec)
  local pane = Tree.pane
  block:ClearAllPoints()
  block:SetPoint("TOPLEFT", pane, "TOPLEFT", Tree.BORDER, -(Tree.BORDER + (Tree.listTop or 0)))
  block:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -Tree.BORDER, Tree.BORDER)

  -- Everything hangs off the piece above it, so a paragraph that wraps to one more line pushes
  -- what follows down by itself and nothing has to be measured to place it.
  local previous
  local function stack(region, gap)
    region:ClearAllPoints()
    if previous then
      region:SetPoint("TOP", previous, "BOTTOM", 0, -gap)
    else
      region:SetPoint("TOP", block, "TOP", 0, -layout.top)
    end
    previous = region
    return region
  end

  -- The illustration, at its own shape rather than in a square: Assets.Apply crops the canvas
  -- down to the artwork and the layout states the two sides, so nothing is stretched and no
  -- border or quality frame goes anywhere near it. A pane with no room for it at all gets no
  -- picture instead of a picture over the words, and the heading becomes the top of the block.
  local art = block.art
  if art then
    if layout.artHeight > 0 then
      Assets.Apply(art, Tree.EmptyArt())
      art:SetSize(layout.artWidth, layout.artHeight)
      stack(art, 0)
      art:Show()
    else
      art:ClearAllPoints()
      art:Hide()
    end
  end
  if block.heading and spec.heading then
    wrapText(
      block.heading,
      layout.width,
      spec.heading,
      "ITEMTREE_COLOR_TEXT_TITLE",
      layout.headingSize,
      Theme.fonts.ITEMTREE_FONT_TITLE
    )
    stack(block.heading, layout.gap)
  elseif block.heading then
    block.heading:Hide()
  end

  local lines = type(spec.lines) == "table" and spec.lines or EMPTY
  for index, text in ipairs(lines) do
    local line = emptyLine(block, index)
    if line then
      wrapText(line, layout.width, text, "ITEMTREE_COLOR_TEXT_MUTED", layout.lineSize)
      stack(line, index == 1 and layout.gap or layout.lineGap)
    end
  end
  for index = #lines + 1, #block.lines do
    local extra = block.lines[index]
    if extra then
      extra:Hide()
    end
  end

  block:Show()
  return true
end

-- The view the window is on, guarded: UI/Frame.lua may not carry View on this build, and then
-- the pane has no idea which empty state belongs to what it is drawing.
local function currentView()
  local frame = frameModule()
  if frame and type(frame.View) == "function" then
    local ok, view = pcall(frame.View)
    if ok and type(view) == "string" then
      return view
    end
  end
  return nil
end

-- The corner mark the pane's own root wears, as one word, or nil where there is none. ONE item,
-- once per draw, and only ever the root: Core has already built that node for the pane it is
-- drawing. A root that is not an item, and a pane with no view model yet, answer nothing.
local function rootDiscovery()
  local vm = Tree.vm
  local key = type(vm) == "table" and vm.root or nil
  local graph = ItemTree.Graph
  if type(key) ~= "string" or type(graph) ~= "table" then
    return nil
  end
  if type(graph.Parse) ~= "function" or type(graph.ItemDiscoveryMark) ~= "function" then
    return nil
  end
  local okParse, kind, id = pcall(graph.Parse, key)
  if not okParse or kind ~= "item" or not id then
    return nil
  end
  local ok, mark = pcall(graph.ItemDiscoveryMark, id)
  if not ok or type(mark) ~= "string" then
    return nil
  end
  return mark
end

-- The empty state a drawn list stands for, or nil when the list is rows or wants nothing but
-- its own line. A player who has filtered a view down to nothing keeps the plain "No matches"
-- row: what is missing there is a match, not a source database.
local function emptySpec(rows)
  if Tree.filter or not Tree.IsEmptyOnly(rows) then
    return nil
  end
  local spec = Tree.EmptyState(currentView(), rootDiscovery())
  if type(spec) ~= "table" or spec.kind == "plain" then
    return nil
  end
  return spec
end

local function poolFrame(index)
  Tree.pool = Tree.pool or {}
  local frame = Tree.pool[index]
  if not frame then
    frame = newRowFrame(Tree.content or Tree.pane)
    if not frame then
      return nil
    end
    Tree.pool[index] = frame
  end
  return frame
end

-- The fallback path: no ScrollBox, so the pool draws only what the offset shows.
local function drawPool(rows, density, extents, opts, paneHeight)
  local content = Tree.content
  if not content then
    return false
  end
  local first, last, top, total = Tree.Window(extents, Tree.offset or 0, paneHeight)
  Tree.firstVisible = first > 0 and first or 1
  if type(content.SetHeight) == "function" then
    content:SetHeight(math.max(total, 1))
  end
  -- The rows are anchored to both edges of the content frame, so this is what makes them fill
  -- the panel when the bar goes and stop at the bar when it comes back.
  if opts.width and type(content.SetWidth) == "function" then
    content:SetWidth(math.max(opts.width, 1))
  end
  local used, y = 0, top
  for index = first, last do
    local row = index >= 1 and rows[index] or nil
    if row then
      used = used + 1
      local frame = poolFrame(used)
      if not frame then
        break
      end
      applyRow(frame, row, density, opts)
      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
      frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
      frame:Show()
      y = y + (extents[index] or 0)
    end
  end
  for index = used + 1, #(Tree.pool or EMPTY) do
    Tree.pool[index].row = nil
    Tree.pool[index]:Hide()
  end
  return true
end

-- Forward declared: the banner is put up from Tree.Draw and takes its room off the same y the
-- list, its bar and the panel hang from, all of which are built further down the file.
local updateBanner

local function drawScrollBox(rows)
  local box = Tree.scrollBox
  local createProvider = globalFn("CreateDataProvider")
  if not box or not createProvider then
    return false
  end
  local ok, provider = pcall(createProvider, rows)
  if not ok or not provider then
    return false
  end
  Tree.provider = provider
  local set = pcall(box.SetDataProvider, box, provider, true)
  if not set then
    pcall(box.SetDataProvider, box, provider)
  end
  return true
end

--- Brief CT1b (QA item 227, step 3): whether the draw of a page just opened leaves its class trainer
--- Teaches rows to the next frame. Only the open's own view model (UI/Frame.lua sets
--- Frame.openingVm for the one draw Frame.Open makes) and only rows no trainer of the class list
--- has built yet (vm:RowsWaiting): the first hunter trainer page of a session paid the tab counts,
--- the sidebar and the rows in one frame, about 5 ms offline and near three times that on the
--- owner's PC. The rows are built and drawn by a C_Timer.After(0) a frame later, while the same
--- view model is still up; the list is empty for that one frame, with no placeholder row.
function Tree.DeferRows(vm)
  local frame = frameModule()
  if vm == nil or not frame or frame.openingVm ~= vm then
    return false
  end
  frame.openingVm = nil
  if type(vm.RowsWaiting) ~= "function" then
    return false
  end
  local okWaiting, waiting = pcall(vm.RowsWaiting, vm)
  local timer = rawget(_G, "C_Timer")
  if not (okWaiting and waiting == true) or type(timer) ~= "table" or type(timer.After) ~= "function" then
    return false
  end
  return (
    pcall(timer.After, 0, function()
      if Tree.vm == vm and Tree.shown and Tree.pane then
        Tree.Draw()
      end
    end)
  )
end

--- Redraws from the rows the view model holds now. Reads vm:Rows() and nothing else.
---
--- The search filter and the profession specialisation rows are the pane's own view over that
--- list: both are pure, neither is handed back to the view model.
function Tree.Draw()
  local pane = Tree.pane
  if not pane then
    return false
  end
  local vm = Tree.vm
  -- Brief CT1b (step 3): the list empty for the one frame before its rows are built, with no empty
  -- state block and no pinned header, and the page's remembered scroll kept for the next draw.
  if Tree.DeferRows(vm) then
    Tree.rows = EMPTY
    Tree.cursor = nil
    updatePlaceholderText()
    updateBanner(EMPTY)
    if Tree.scrollBox then
      drawScrollBox(EMPTY)
    else
      local _, paneHeight = listSize()
      drawPool(EMPTY, Tree.Density(), {}, rowOpts(), paneHeight)
    end
    showEmptyBlock(nil)
    if Tree.sticky and type(Tree.sticky.Hide) == "function" then
      Tree.sticky:Hide()
    end
    return true
  end
  local rows = EMPTY
  if vm and type(vm.Rows) == "function" then
    local ok, list = pcall(vm.Rows, vm)
    if ok and type(list) == "table" then
      rows = list
    end
  end
  -- E25: the open strips are the pane's own view over the rows, the way the search and the
  -- profession rows are, and they go in last so a strip always sits directly under its craft.
  rows = Tree.StripRows(Tree.SkillRows(Tree.FilterRows(rows, Tree.filter)), Tree.CraftIngredients(), Tree.strips)
  -- A view with nothing in it that has a designed empty state draws the block instead of the
  -- row, so the list itself is given nothing: the block carries the words, and a row under it
  -- would be the same sentence drawn twice. A client that would not give the pane a block keeps
  -- the row, because a pane with neither says nothing at all.
  local spec = Tree.empty and emptySpec(rows) or nil
  if spec then
    rows = EMPTY
  end
  Tree.rows = rows
  if Tree.cursor and Tree.cursor > #rows then
    Tree.cursor = #rows > 0 and #rows or nil
  end

  local density = Tree.Density()
  updatePlaceholderText()
  -- The banner first: it takes its strip off the top of the pane, so every height below is
  -- measured against the room the list actually has.
  updateBanner(rows)
  -- Heights first. A row's extent never depends on how wide the row is, so the whole list can
  -- be measured, the bar settled and the list's right edge moved before a single row is laid
  -- out: one pass, and the rows are laid out already knowing whether there is a bar to stop
  -- at. The count column is measured in the same breath, from the widest count in the list.
  --
  -- E25 is the one exception: a strip is as tall as the lines its icons wrap onto, so the
  -- extents are measured with the width the last draw settled on. A strip that wraps differently
  -- once the bar comes or goes is right again on the next draw, and a resize is a draw.
  local _, paneHeight = listSize()
  local extentOpts = rowOpts()
  extentOpts.height = paneHeight
  local extents, total = rowExtents(rows, density, extentOpts)
  -- Kept for the sticky header, which reads the offset the client is at against these very
  -- heights rather than asking the box which row it thinks it started at.
  Tree.extents, Tree.paneHeight = extents, paneHeight
  updateScrollBar(total, paneHeight)
  applyPanExtent(density)
  anchorList()
  measureCountColumn(rows)
  local opts = rowOpts()
  -- E61: the position the window asked for, in pixels, against the heights THIS draw measured
  -- and clamped to what this list can scroll. Worked out before the rows are laid out, because
  -- the fallback pool draws from Tree.offset; the box is told after it has the list, because a
  -- data provider arriving is what would otherwise move it. Consumed either way, so a later
  -- refresh, a wheel click or a resize never drags the list back here.
  local landed = nil
  if Tree.pendingOffset ~= nil then
    landed = Tree.ClampOffset(Tree.pendingOffset, total, paneHeight)
    Tree.pendingOffset = nil
    Tree.offset = landed
  end
  if Tree.scrollBox then
    drawScrollBox(rows)
    if landed then
      scrollBoxTo(landed, total, paneHeight)
    end
  else
    drawPool(rows, density, extents, opts, paneHeight)
  end
  showEmptyBlock(spec)
  applySelection()
  -- The pinned header is worked out from the offset the pane just landed on rather than from
  -- what the box says it derived, so it names the right category on the first frame.
  updateSticky(landed)
  return true
end

--- The text the search carries, from the window. Non empty text filters the drawn rows to the
--- rows a word of which contains it; empty or nil clears it. Returns the filter now in force,
--- which is nil when there is none. The view model is untouched either way.
---
--- This is the one way in, whether the pane's own box typed it or the window cleared it on a
--- re-root, so the box is written back to match rather than being left saying something the
--- rows no longer agree with.
---
--- The view model is told one thing and one thing only: whether the box holds anything. That is
--- what makes the search reach past a summary into the sources the cap never named, and it
--- is not the filter: the view model still knows nothing about what was typed, and the rows it
--- hands back are still filtered here. Clearing the box takes the lists away again and leaves
--- every list the player pressed exactly as it was.
function Tree.SetTextFilter(text)
  local filter = type(text) == "string" and text:match("^%s*(.-)%s*$") or ""
  Tree.filter = filter ~= "" and filter or nil
  syncSearchBox(filter)
  local vm = Tree.vm
  if vm and type(vm.SetSearching) == "function" then
    pcall(vm.SetSearching, vm, Tree.filter ~= nil)
  end
  if Tree.pane then
    Tree.Draw()
  end
  return Tree.filter
end

-- Whether the search box is taking the keys. The box sits inside the pane, so the cursor can
-- be over both at once, and then left and right belong to the word being typed and not to the
-- rows. A client that cannot be asked reads as not focused, which is what it was before the
-- box existed.
local function searchHasFocus()
  local box = Tree.search
  if not box or type(box.HasFocus) ~= "function" then
    return false
  end
  local ok, focused = pcall(box.HasFocus, box)
  return ok and focused == true
end

local function onKeyDown(pane, key)
  -- Brief E91: in combat nothing is decided here at all (see inCombat above); the capture is let
  -- go before combat, so a key only lands here if something kept it, and it goes on to the game.
  if inCombat() then
    return
  end
  local normalised = Tree.NAV_KEYS[type(key) == "string" and key:upper() or ""]
  local rows = Tree.rows or EMPTY
  -- Everything the pane does not answer to goes back to the client, and so does everything at
  -- all while the player is typing in the box above the rows or in the window's global item
  -- search, or while that search's dropdown hangs over this pane waiting for the same arrows.
  if not normalised or #rows == 0 or searchHasFocus() or Tree.KeyboardBlocked() then
    setPropagate(pane, true)
    return
  end
  setPropagate(pane, false)
  local index, action, actionKey = Tree.KeyboardMove(rows, Tree.cursor or 1, normalised)
  Tree.cursor = index > 0 and index or nil
  if action == "move" or action == "none" then
    applySelection()
    -- E25: the keyboard cursor reads a row the way the pointer does, so the Recipe card follows
    -- it. Only on a key, never on a redraw, so a card raised by the pointer is left alone.
    showRecipeCard(Tree.cursor and rows[Tree.cursor] or nil)
    return
  end
  -- Brief BQ24: Enter on a trainer's row opens its page on the Map tab, as a click does.
  if action == "reroot" and Tree.IsTrainerRow(Tree.cursor and rows[Tree.cursor] or nil) then
    perform(action, actionKey, { trainer = true })
    return
  end
  perform(action, actionKey)
end

local function wirePane(pane)
  if type(pane.EnableMouse) == "function" then
    pane:EnableMouse(true)
  end
  pane:SetScript("OnEnter", function()
    Tree.SetKeyboardCapture(true)
  end)
  pane:SetScript("OnLeave", onPaneLeave)
  pane:SetScript("OnKeyDown", onKeyDown)
  pane:SetScript("OnHide", function()
    Tree.SetKeyboardCapture(false)
  end)
  -- A wider pane gives the name column more room and a taller one may swallow the scrollbar,
  -- so a resize is a redraw. Nothing here resizes the pane, so it cannot feed itself.
  pane:SetScript("OnSizeChanged", function()
    if Tree.pane and Tree.rows then
      Tree.Draw()
    end
  end)
  Tree.SetKeyboardCapture(false)
end

-- Where the panel's five pieces sit for a given top edge. Pulled out of the build because the
-- top edge moves: the filter box leaving the pane for the view tab row takes it to zero, and
-- then the panel, the list and the bar all follow it up.
local function anchorPanel(pane, panel, top)
  if type(panel) ~= "table" then
    return false
  end
  local surface = panel.surface
  if surface then
    surface:ClearAllPoints()
    surface:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -top)
    surface:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
  end
  if panel.top then
    panel.top:ClearAllPoints()
    panel.top:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -top)
    panel.top:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, -top)
    panel.top:SetHeight(Tree.BORDER)
  end
  if panel.bottom then
    panel.bottom:ClearAllPoints()
    panel.bottom:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 0, 0)
    panel.bottom:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    panel.bottom:SetHeight(Tree.BORDER)
  end
  if panel.left then
    panel.left:ClearAllPoints()
    panel.left:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -top)
    panel.left:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 0, 0)
    panel.left:SetWidth(Tree.BORDER)
  end
  if panel.right then
    panel.right:ClearAllPoints()
    panel.right:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, -top)
    panel.right:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    panel.right:SetWidth(Tree.BORDER)
  end
  return true
end

-- The recessed panel the list sits in: core/InsetPanel.jsx, as the inset surface under a 1px
-- edge, drawn whether the list has rows or not so the empty state reads as a panel rather than
-- a hole. Four hairlines rather than a nine slice: the live clients' NineSliceUtil is atlas
-- oriented and a file layout renders as a dotted edge. See docs/design-deviations.md.
local function buildPanel(pane)
  if type(pane.CreateTexture) ~= "function" then
    return false
  end
  local top = Tree.listTop or 0
  local panel = {}
  panel.surface = pane:CreateTexture(nil, "BACKGROUND")
  if not panel.surface then
    return false
  end
  Assets.Apply(panel.surface, "FILL_WHITE8X8")
  tint(panel.surface, Tree.PANEL_SURFACE, 1)
  panel.surface:Show()

  local edges = { "top", "bottom", "left", "right" }
  for _, edge in ipairs(edges) do
    local line = pane:CreateTexture(nil, "BORDER")
    if not line then
      return false
    end
    Assets.Apply(line, "FILL_WHITE8X8")
    tint(line, Tree.PANEL_BORDER, 1)
    panel[edge] = line
  end

  anchorPanel(pane, panel, top)
  for _, edge in ipairs(edges) do
    panel[edge]:Show()
  end
  Tree.panel = panel
  return true
end

-- The ScrollBox path. Every call is guarded, and any one of them failing drops the pane to
-- the frame pool instead.
local function initScrollBox(pane)
  local createView = globalFn("CreateScrollBoxListLinearView")
  local createProvider = globalFn("CreateDataProvider")
  local scrollUtil = rawget(_G, "ScrollUtil")
  if not createView or not createProvider then
    return false
  end
  if type(scrollUtil) ~= "table" or type(scrollUtil.InitScrollBoxListWithScrollBar) ~= "function" then
    return false
  end
  local box = newTemplatedFrame("Frame", pane, "WowScrollBoxList")
  local bar = newTemplatedFrame("EventFrame", pane, "MinimalScrollBar")
  if not box or not bar then
    return false
  end
  -- Everything sits a hairline inside the pane, under whatever the search box holds off the
  -- top, so the inset panel's edge is never drawn over.
  local edge = Tree.BORDER
  local top = edge + (Tree.listTop or 0)
  bar:SetWidth(Tree.SCROLLBAR)
  bar:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -edge, -top)
  bar:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -edge, edge)
  box:SetPoint("TOPLEFT", pane, "TOPLEFT", edge, -top)
  box:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -Tree.ListRightInset(true), edge)
  Tree.listRight = Tree.ListRightInset(true)

  local okView, view = pcall(createView)
  if not okView or not view then
    return false
  end
  if type(view.SetElementInitializer) == "function" then
    pcall(view.SetElementInitializer, view, "Button", function(frame, row)
      if not rawget(frame, "itemtreeRow") then
        Tree.Decorate(frame)
      end
      applyRow(frame, row, Tree.Density(), rowOpts())
    end)
  end
  if type(view.SetElementExtentCalculator) == "function" then
    pcall(view.SetElementExtentCalculator, view, function(_, row)
      return Tree.Extent(row, Tree.Density(), rowOpts())
    end)
  end
  local ok = pcall(scrollUtil.InitScrollBoxListWithScrollBar, box, bar, view)
  if not ok then
    return false
  end
  Tree.scrollBox, Tree.scrollBar, Tree.view = box, bar, view
  -- One wheel click moves one row, stated here as well as on every draw so a box that is shown
  -- before the first draw already scrolls properly. Tree.WheelStep says why.
  applyPanExtent(Tree.Density())
  -- The sticky header follows the scroll, which the box announces as an event of its own.
  --
  -- E54: the name this asked for, ScrollBoxConstants.CallbackOnScroll, is not one the Forever
  -- client has. Its ScrollBox announces BaseScrollBoxEvents.OnScroll, which is the string
  -- "OnScroll" (wow-ui-source branch `forever`,
  -- Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua), so nothing was ever
  -- registered and the pinned header only moved on a redraw: it went on naming the category the
  -- top of the pane held when the list was last drawn, however far the player scrolled away from
  -- it. That is the "Contained in" over a pane full of "Mined in" rows the owner found.
  --
  -- RegisterCallback takes any string, so an event the client does not announce registers
  -- happily and simply never fires. Every name this pane knows is registered rather than the
  -- first one that does not raise, and updateSticky does the same thing however often it is
  -- called, so a client that announces two of them costs one extra call and nothing else.
  if type(box.RegisterCallback) == "function" then
    local events = rawget(_G, "BaseScrollBoxEvents")
    local constants = rawget(_G, "ScrollBoxConstants")
    local names, seen = {}, {}
    local function want(name)
      if type(name) == "string" and not seen[name] then
        seen[name] = true
        names[#names + 1] = name
      end
    end
    want(type(events) == "table" and events.OnScroll or nil)
    want("OnScroll")
    want(type(constants) == "table" and constants.CallbackOnScroll or nil)
    for _, name in ipairs(names) do
      pcall(box.RegisterCallback, box, name, updateSticky, Tree)
    end
  end
  return true
end

-- The fallback path, for a client with no ScrollBox: a plain ScrollFrame whose child is as
-- tall as the whole list, with pooled row frames placed over the visible window.
local function initFallback(pane)
  local scroll = newFrame("ScrollFrame", pane)
  if not scroll then
    return false
  end
  local edge = Tree.BORDER
  scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", edge, -(edge + (Tree.listTop or 0)))
  scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -Tree.ListRightInset(true), edge)
  Tree.listRight = Tree.ListRightInset(true)
  local content = newFrame("Frame", scroll)
  if not content then
    return false
  end
  local width = select(1, listSize()) - Tree.BORDER - Tree.ListRightInset(true)
  content:SetSize(width > 0 and width or SIZES.ITEMTREE_FRAME_MIN_W, 1)
  if type(scroll.SetScrollChild) == "function" then
    scroll:SetScrollChild(content)
  end
  scroll:SetScript("OnVerticalScroll", function(_, value)
    Tree.offset = tonumber(value) or 0
    Tree.Draw()
  end)
  Tree.scroll, Tree.content, Tree.pool, Tree.offset = scroll, content, {}, 0
  return true
end

-- The list, its bar and the panel around them all hang from the same y, so moving the filter
-- box off the top of the pane means moving every one of them up with it. Only the top anchors
-- are written: the right hand edge belongs to anchorList, which follows the scroll bar.
local function anchorListTop()
  local pane = Tree.pane
  if not pane then
    return false
  end
  local edge = Tree.BORDER
  local top = edge + (Tree.listTop or 0)
  anchorPanel(pane, Tree.panel, Tree.listTop or 0)
  local bar = Tree.scrollBar
  if bar and type(bar.SetPoint) == "function" then
    pcall(bar.SetPoint, bar, "TOPRIGHT", pane, "TOPRIGHT", -edge, -top)
  end
  for _, frame in ipairs({ Tree.scrollBox, Tree.scroll }) do
    if type(frame.SetPoint) == "function" then
      pcall(frame.SetPoint, frame, "TOPLEFT", pane, "TOPLEFT", edge, -top)
    end
  end
  return true
end

-- The banner sits under whatever the search box holds off the top of the pane, and the list
-- starts under the banner. Written whenever either of them changes.
local function anchorBanner()
  local frame = Tree.banner
  local pane = Tree.pane
  if not frame or not pane or type(frame.SetPoint) ~= "function" then
    return false
  end
  frame:ClearAllPoints()
  local top = Tree.searchTop or 0
  pcall(frame.SetPoint, frame, "TOPLEFT", pane, "TOPLEFT", Tree.BORDER + Tree.PAD, -top)
  pcall(frame.SetPoint, frame, "TOPRIGHT", pane, "TOPRIGHT", -(Tree.BORDER + Tree.PAD), -top)
  return true
end

-- How far down the pane the list starts: the search box's strip, plus the banner's where the
-- banner is up. Everything that hangs off that y is moved with it.
local function setListTop(bannerShown)
  local top = (Tree.searchTop or 0)
  if bannerShown then
    top = top + Tree.BANNER_H + Tree.BANNER_GAP
  end
  Tree.bannerShown = bannerShown and true or false
  if top == Tree.listTop then
    return false
  end
  Tree.listTop = top
  anchorBanner()
  anchorListTop()
  return true
end

-- The banner's own tooltip: why a row can be from Classic Era at all, in plain language. Its
-- own words, not a row's, so it is written here rather than through the row tooltip's blocks.
local function showBannerTooltip(frame)
  local spec = Tree.bannerSpec
  local tooltip = rawget(_G, "GameTooltip")
  if type(spec) ~= "table" or type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  if type(tooltip.AddLine) ~= "function" then
    return false
  end
  tooltip:SetOwner(frame, "ANCHOR_RIGHT")
  -- The heading is an AddLine like every other line this pane writes, the way a category's own
  -- tooltip heads itself: SetText is the client's and a tooltip that does not carry one is
  -- still a tooltip.
  tooltip:AddLine(spec.text, tooltipColor("ITEMTREE_COLOR_TEXT_TITLE"))
  for _, line in ipairs(spec.lines or EMPTY) do
    mutedLine(tooltip, line)
  end
  tooltip:Show()
  return true
end

-- Brief TA1 (the developer only tooltip audit): the hovers on a drawn row's own parts, made
-- reachable as Tree.ShowRowTooltip is: "mark" (the chest's target), "strip" (the craft strip's
-- button), "cell" (its first icon), "nearest" (Show nearest on a header, its plate put back to rest
-- at once, since nothing under the pointer will take it off) and "banner" (the Classic Era banner,
-- no row). Each is the part's own hover with nothing of a real pointer's (no keyboard capture).
-- Answers whether a tooltip went up.
function Tree.ShowPartTooltip(frame, part)
  local tooltip = rawget(_G, "GameTooltip")
  if part == "banner" then
    return Tree.banner ~= nil and showBannerTooltip(Tree.banner) == true
  end
  if type(frame) ~= "table" then
    return false
  end
  local target = nil
  if part == "mark" then
    target = rawget(frame, "markHit")
    return type(target) == "table" and showMarkTooltip(target) == true
  elseif part == "strip" then
    target = rawget(frame, "stripButton")
    if type(target) == "table" then
      onStripButtonEnter(target)
    end
  elseif part == "cell" then
    local cells = rawget(frame, "stripCells")
    target = type(cells) == "table" and cells[1] or nil
    if type(target) == "table" then
      onStripCellEnter(target)
    end
  elseif part == "nearest" then
    target = rawget(frame, "nearestButton")
    if type(target) == "table" then
      onNearestEnter(target)
      local ui = ItemTree.UI
      local frameApi = type(ui) == "table" and ui.Frame or nil
      if type(frameApi) == "table" and type(frameApi.PaintPlateButton) == "function" then
        pcall(frameApi.PaintPlateButton, target, "normal")
      end
    end
  end
  if type(target) ~= "table" or type(tooltip) ~= "table" or type(tooltip.IsShown) ~= "function" then
    return false
  end
  -- The client's answer is read through Util.CanRead before it is compared (bible B10).
  local ok, shown = pcall(tooltip.IsShown, tooltip)
  local util = ItemTree.Util
  local readable = type(util) ~= "table" or type(util.CanRead) ~= "function" or util.CanRead(shown)
  return ok and readable and shown == true
end

-- One line and a small mark across the top of the pane. Built once with the pane, hidden until
-- a draw finds a Classic Era row on screen.
local function buildBanner(pane)
  local frame = newFrame("Frame", pane)
  if not frame then
    return nil
  end
  frame:SetHeight(Tree.BANNER_H)
  if type(frame.CreateTexture) == "function" then
    local art = frame:CreateTexture(nil, "ARTWORK")
    if art then
      art:SetSize(Tree.BANNER_ICON, Tree.BANNER_ICON)
      art:SetPoint("LEFT", frame, "LEFT", 0, 0)
      Assets.Apply(art, Tree.BANNER_ART)
      tint(art, Tree.BANNER_COLOR, 1)
      frame.art = art
    end
  end
  local label = newFontString(frame, "OVERLAY")
  if label then
    setFont(label, Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_SM)
    textColor(label, Tree.BANNER_COLOR)
    label:SetPoint("LEFT", frame, "LEFT", Tree.BANNER_ICON + Tree.GUTTER, 0)
    label:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    if type(label.SetJustifyH) == "function" then
      label:SetJustifyH("LEFT")
    end
    frame.label = label
  end
  if type(frame.EnableMouse) == "function" then
    frame:EnableMouse(true)
  end
  frame:SetScript("OnEnter", showBannerTooltip)
  frame:SetScript("OnLeave", function()
    local tooltip = rawget(_G, "GameTooltip")
    if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
      tooltip:Hide()
    end
  end)
  frame:Hide()
  Tree.banner = frame
  anchorBanner()
  return frame
end

-- Shows or hides the banner for the rows about to be drawn, and gives the list whatever room is
-- left. Called from Tree.Draw before a single height is measured, because moving the top of the
-- list moves the room every row is measured against with it.
function updateBanner(rows)
  local spec = nil
  if Tree.SHOW_TOP_ERA_NOTICE == true then
    spec = Tree.EraBanner(rows, Tree.filter)
  end
  Tree.bannerSpec = spec
  local frame = Tree.banner
  if not frame then
    Tree.bannerShown = false
    return false
  end
  if not spec then
    frame:Hide()
    setListTop(false)
    return false
  end
  setText(frame.label, spec.text)
  frame:Show()
  setListTop(true)
  return true
end

-- Re-parents the filter box into a region of the window's and fills it. The client's own search
-- box art hangs outside the edit box on the left, so the same overhang the box compensated for
-- at the top of the pane is taken off here.
local function moveFilter(region)
  local box = Tree.search
  if type(region) ~= "table" or not box or type(box.SetPoint) ~= "function" then
    return false
  end
  if type(box.SetParent) == "function" then
    pcall(box.SetParent, box, region)
  end
  local left, right = Tree.SearchInsets(rawget(box, "itemTreeTemplated") == true)
  if type(box.ClearAllPoints) == "function" then
    box:ClearAllPoints()
  end
  pcall(box.SetPoint, box, "TOPLEFT", region, "TOPLEFT", left, 0)
  pcall(box.SetPoint, box, "BOTTOMRIGHT", region, "BOTTOMRIGHT", -right, 0)
  if type(box.Show) == "function" then
    box:Show()
  end
  -- The box is the window's now, so the tree list starts at the very top of its own pane, under
  -- the banner where the banner is up.
  if (Tree.searchTop or 0) ~= 0 then
    Tree.searchTop = 0
    Tree.listTop = nil
    setListTop(Tree.bannerShown)
  end
  return true
end

--------------------------------------------------------------------------------
-- The Map view (brief E57), and the seam brief E59 draws the real map through
--------------------------------------------------------------------------------

--- The lines the default map draws: the heading over the places, and what it says when the
--- shipped table states no place for the creature at all. Each is the English wording and its own
--- locale key.
Tree.MAP_HEADING = "Known in"
Tree.MAP_NOWHERE = "No place is known for this creature"

--- How many places the rectangle lists before it counts the rest out, and the air around them.
Tree.MAP_ZONES = 12
Tree.MAP_PAD = SIZES.ITEMTREE_SPACE_4
Tree.MAP_LINE_GAP = SIZES.ITEMTREE_SPACE_2

--- The zones one creature root is known in, as the painter below takes them: an array of
--- { areaId, name }, and the creature's own name index beside it.
---
--- Read off the shipped Classic Era table through the namespace and pcall'd like every other
--- module here, so a load without Core/EraSources.lua, and a build compiled with
--- --no-era-sources, costs the tab its places and nothing else. Nothing is asked of the client.
function Tree.MapFacts(rootKey)
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.CreatureFacts) ~= "function" then
    return nil, nil
  end
  local ok, facts = pcall(era.CreatureFacts, era, rootKey)
  if not ok or type(facts) ~= "table" then
    return nil, nil
  end
  local zones = {}
  for _, zone in ipairs(facts.zones or EMPTY) do
    if type(zone) == "table" and type(zone.name) == "string" and zone.name ~= "" then
      zones[#zones + 1] = { areaId = zone.areaId, name = zone.name }
    end
  end
  -- Brief BQ4 (QA item 25): a summoned boss has no spawn in the table, so no zone, and its Map tab
  -- read "No place is known for this creature". The instance the Boss loot index files it under is
  -- its place (the page's "Known in" line, UI/InfoPanel.lua FactsWithBossPlace), which the map
  -- draws as "Inside Wailing Caverns". Only asked when the table states no zone.
  if #zones == 0 then
    zones = Tree.BossZones(rootKey, zones)
  end
  return facts.nameIndex, zones
end

--- Brief BQ4: the boss place zones for a creature root the table states no zone for, or zones as
--- handed in. Read through the page's own boss lookup (UI/InfoPanel.lua BossOfFor) and
--- Core/Creatures.lua BossZones, both looked up at call time and pcall'd.
function Tree.BossZones(rootKey, zones)
  local ui = ItemTree.UI
  local panel = type(ui) == "table" and ui.InfoPanel or nil
  local creatures = ItemTree.Creatures
  if type(panel) ~= "table" or type(panel.BossOfFor) ~= "function" then
    return zones
  end
  if type(creatures) ~= "table" or type(creatures.BossZones) ~= "function" then
    return zones
  end
  local ok, boss = pcall(panel.BossOfFor, rootKey, nil)
  if not ok or type(boss) ~= "table" then
    return zones
  end
  local made, answer = pcall(creatures.BossZones, zones, boss)
  if not made or type(answer) ~= "table" then
    return zones
  end
  return answer
end

--- The words the default map lays out: the heading and one line per place, capped, with a plain
--- count line where the cap held any back, or the one line a creature with no place at all gets.
--- Pure, so the layout is read by a spec with no client at all.
function Tree.MapLines(zones, cap)
  cap = math.max(1, math.floor(tonumber(cap) or Tree.MAP_ZONES))
  local out = {}
  local places = type(zones) == "table" and zones or EMPTY
  if #places == 0 then
    out[#out + 1] = { text = L[Tree.MAP_NOWHERE], muted = true }
    return out
  end
  out[#out + 1] = { text = L[Tree.MAP_HEADING], heading = true }
  local held = 0
  for _, zone in ipairs(places) do
    local name = type(zone) == "table" and zone.name or nil
    if type(name) == "string" and name ~= "" then
      if #out - 1 < cap then
        out[#out + 1] = { text = name }
      else
        held = held + 1
      end
    end
  end
  if held > 0 then
    local more = nil
    local Sources = ItemTree.Sources
    if type(Sources) == "table" and type(Sources.MoreText) == "function" then
      local ok, text = pcall(Sources.MoreText, held)
      if ok and type(text) == "string" and text ~= "" then
        more = text
      end
    end
    out[#out + 1] = { text = more or (tostring(held) .. " more"), muted = true }
  end
  return out
end

--- The map's own bordered rectangle inside the region the window made, built once and reused.
local function buildMap(region)
  if Tree.map and Tree.map.region == region then
    return Tree.map
  end
  if type(region) ~= "table" or type(region.CreateTexture) ~= "function" then
    return nil
  end
  local map = { region = region, lines = {} }
  map.surface = region:CreateTexture(nil, "BACKGROUND")
  if map.surface then
    Assets.Apply(map.surface, "FILL_WHITE8X8")
    tint(map.surface, Tree.PANEL_SURFACE, 1)
    map.surface:SetAllPoints(region)
    map.surface:Show()
  end
  for _, edge in ipairs({ "top", "bottom", "left", "right" }) do
    local line = region:CreateTexture(nil, "BORDER")
    if line then
      Assets.Apply(line, "FILL_WHITE8X8")
      tint(line, Tree.PANEL_BORDER, 1)
      map[edge] = line
      line:Show()
    end
  end
  if map.top then
    map.top:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
    map.top:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, 0)
    map.top:SetHeight(Tree.BORDER)
  end
  if map.bottom then
    map.bottom:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, 0)
    map.bottom:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, 0)
    map.bottom:SetHeight(Tree.BORDER)
  end
  if map.left then
    map.left:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
    map.left:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, 0)
    map.left:SetWidth(Tree.BORDER)
  end
  if map.right then
    map.right:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, 0)
    map.right:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, 0)
    map.right:SetWidth(Tree.BORDER)
  end
  Tree.map = map
  return map
end

--- The map's bordered rectangle, built if it is not there yet. The real painter (UI/Map.lua) asks
--- for it before it draws, so the art sits inside the same inset panel the words sit in rather than
--- floating in a hole in the window. Answers nil on a client that could not make the textures.
function Tree.MapPanel(region)
  return buildMap(region)
end

--- One pooled line of the default map's text, kept on the map so a redraw reuses it.
local function mapLine(map, index)
  local held = map.lines[index]
  if held then
    return held
  end
  local fontString = newFontString(map.region, "OVERLAY")
  if not fontString then
    return nil
  end
  map.lines[index] = fontString
  return fontString
end

--- THE SEAM, which UI/Map.lua fills in (brief E59).
---
--- Tree.MapPainter is handed the rectangle, the creature's name index and the places the shipped
--- table states for it, and draws into the rectangle. Replacing this one field with a function of
--- the same three arguments is the whole of putting a real map there: nothing else in this pane,
--- in the window or in Core needs to change, and whatever the painter leaves behind is cleared by
--- Tree.ClearMap when the tab or the root changes.
---
---   region     the bordered frame, already sized to the space both lists take
---   nameIndex  the creature's place in the shipped string table, or nil
---   zones      { { areaId = <a Blizzard area id>, name = "<this build's own name for it>" } }
---
--- Tree.MapCleaner beside it is the other half: the painter's own way of taking its frames down,
--- called by Tree.ClearMap before this file hides its own lines. A painter that leaves nothing
--- behind leaves it nil.
---
--- The default implementation draws the places as centred text. It says nothing about being
--- unfinished: what it draws is true and is the answer a player wants when there is no map to look
--- at, which is why UI/Map.lua falls back to it rather than to a message of its own.
---
--- lines is that painter's one option: a line list to lay out INSTEAD of the places, in the same
--- { text, heading, muted } shape Tree.MapLines answers with. UI/Map.lua passes the places with
--- each pin written out under them when this client will not hand over the art.
function Tree.DrawMapZones(region, nameIndex, zones, lines)
  local map = buildMap(region)
  if not map then
    return false
  end
  -- Which creature the rectangle is showing. The text does not need it; it is kept because the
  -- seam hands it over and the real painter draws pins with it (UI/Map.lua), and because it is
  -- what a spec reads back to say the seam was called with the right creature.
  map.nameIndex = nameIndex
  if type(lines) ~= "table" or #lines == 0 then
    lines = Tree.MapLines(zones, Tree.MAP_ZONES)
  end
  local bodySize = Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_MD
  local titleSize = Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_LG or bodySize
  local outer = (type(region.GetWidth) == "function" and tonumber(region:GetWidth())) or 0
  local width = math.max(Tree.EMPTY_MIN_W, outer - 2 * Tree.MAP_PAD)
  local drawn, previous = 0, nil
  for index, line in ipairs(lines) do
    local fontString = mapLine(map, index)
    if fontString then
      drawn = drawn + 1
      local colour = "ITEMTREE_COLOR_TEXT_BODY"
      if line.heading then
        colour = "ITEMTREE_COLOR_TEXT_TITLE"
      elseif line.muted then
        colour = "ITEMTREE_COLOR_TEXT_MUTED"
      end
      wrapText(
        fontString,
        width,
        line.text,
        colour,
        line.heading and titleSize or bodySize,
        line.heading and Theme.fonts.ITEMTREE_FONT_TITLE or nil
      )
      fontString:ClearAllPoints()
      if previous then
        fontString:SetPoint("TOP", previous, "BOTTOM", 0, -Tree.MAP_LINE_GAP)
      else
        -- The whole block reads as centred in the rectangle, so the first line starts half the
        -- block's own height above the middle rather than at the top of the box.
        local rise = (#lines - 1) * (bodySize + Tree.MAP_LINE_GAP) / 2
        fontString:SetPoint("TOP", region, "CENTER", 0, rise + bodySize / 2)
      end
      previous = fontString
    end
  end
  for index = drawn + 1, #map.lines do
    local fontString = map.lines[index]
    if fontString and type(fontString.Hide) == "function" then
      fontString:Hide()
    end
  end
  return drawn > 0
end

Tree.MapPainter = Tree.DrawMapZones
--- The default painter draws font strings this file already owns, so it needs no cleaner of its
--- own. UI/Map.lua puts one here when it loads.
Tree.MapCleaner = nil

--- Draws the Map view for one root into the region the window hands over. The window calls this
--- while the Map tab is up and nothing else does; the two lists are hidden by then.
function Tree.ShowMap(region, rootKey)
  if type(region) ~= "table" then
    return false
  end
  local nameIndex, zones = Tree.MapFacts(rootKey)
  Tree.mapRoot = rootKey
  local painter = Tree.MapPainter
  if type(painter) ~= "function" then
    return false
  end
  local ok, drawn = pcall(painter, region, nameIndex, zones or EMPTY)
  if not ok then
    return false
  end
  return drawn ~= false
end

--- Hides everything the map drew. Called when the window hides, when the Map tab is left and when
--- the root changes, so nothing of one creature's map is left behind the next one.
---
--- The painter's own frames go first, through Tree.MapCleaner, and then this file's lines. Both
--- are idempotent and the cleaner is pcall'd, because it belongs to a file this one does not know
--- has loaded.
function Tree.ClearMap()
  Tree.mapRoot = nil
  local cleared = false
  local cleaner = Tree.MapCleaner
  if type(cleaner) == "function" then
    local ok, took = pcall(cleaner)
    if ok and took ~= false then
      cleared = true
    end
  end
  local map = Tree.map
  if type(map) ~= "table" then
    return cleared
  end
  for _, fontString in ipairs(map.lines or EMPTY) do
    if type(fontString) == "table" and type(fontString.Hide) == "function" then
      fontString:Hide()
    end
  end
  return true
end

--- Moves the pane's filter box onto the view tab row, into a region the window made for it, and
--- gives the tree list the whole pane under it. What the box does, the words it carries, its
--- debounce, its clear button and Escape are all unchanged: only where it is drawn moves.
---
--- The window calls this after it builds its regions and again whenever it rebuilds them. A
--- call that arrives before the pane has a box remembers the region and moves the box as soon
--- as Tree.Attach builds it, and a pane that is never called keeps its own box at the top,
--- which is what it looked like before this existed.
function Tree.AttachFilter(region)
  if type(region) ~= "table" then
    return false
  end
  Tree.filterRegion = region
  local moved = moveFilter(region)
  if moved and Tree.pane and Tree.rows then
    Tree.Draw()
  end
  return moved
end

-- Brief BQ15: the pane's own frame for QUEST_TURNED_IN, made with the pane (ItemTree's own frame,
-- never a Blizzard one), so a quest turned in while the window is open gains its check at once.
-- Each step is pcall'd: a client that refuses the event keeps the check for the next draw.
local function watchTurnIns(pane)
  if Tree.turnInWatch then
    return Tree.turnInWatch
  end
  local frame = newFrame("Frame", pane)
  if not frame or type(frame.RegisterEvent) ~= "function" or type(frame.SetScript) ~= "function" then
    return nil
  end
  if not pcall(frame.RegisterEvent, frame, "QUEST_TURNED_IN") then
    return nil
  end
  pcall(frame.SetScript, frame, "OnEvent", function(_, _, questId)
    Tree.OnQuestTurnedIn(questId)
  end)
  Tree.turnInWatch = frame
  return frame
end

--- Builds the pane inside the region the window created and sized. Idempotent, and false
--- with no client, which leaves Show and Refresh as no-ops.
function Tree.Attach(region)
  if type(region) ~= "table" then
    return false
  end
  if Tree.pane == region then
    return true
  end
  if not globalFn("CreateFrame") then
    return false
  end
  Tree.pane = region
  Tree.scrollBox, Tree.scrollBar, Tree.view = nil, nil, nil
  Tree.scroll, Tree.content, Tree.pool = nil, nil, {}
  Tree.offset, Tree.cursor, Tree.firstVisible = 0, nil, 1
  -- E61: a page's remembered offset, waiting for the draw that can clamp it to the list.
  Tree.pendingOffset = nil
  Tree.panel, Tree.extent, Tree.scrollbarShown = nil, 0, nil
  -- The heights the last draw measured and the room it measured them against, which is what the
  -- sticky header reads the scroll offset against (firstVisibleRow), and the wheel step the
  -- client was last given.
  Tree.extents, Tree.paneHeight, Tree.panExtent = {}, 0, nil
  Tree.listRight, Tree.countWidth, Tree.ruler = nil, nil, nil
  Tree.empty = nil
  -- The box is built first, because everything under it is anchored below whatever it holds
  -- off the top of the pane. A client that will not give one leaves the list the whole pane.
  Tree.search, Tree.searchTop, Tree.listTop = nil, 0, 0
  Tree.banner, Tree.bannerSpec, Tree.bannerShown = nil, nil, false
  Tree.search = buildSearchBox(region)
  if Tree.search then
    Tree.searchTop = Tree.SEARCH_H + Tree.SEARCH_GAP
    Tree.listTop = Tree.searchTop
  end
  -- The banner is above the list and below the box, and is hidden until a draw finds a Classic
  -- Era row, so the list keeps the whole pane on every view that has none.
  buildBanner(region)
  -- The window may already have taken the box out onto the view tab row, and a rebuilt pane
  -- has to put it straight back there rather than drawing a second one over its own list.
  if Tree.filterRegion then
    moveFilter(Tree.filterRegion)
  end
  -- A rebuild gets a box with nothing in it, so what the pane is still filtered by is written
  -- back into it rather than filtering the rows for a reason the player cannot see.
  syncSearchBox(Tree.filter or "")
  updatePlaceholderText()
  buildPanel(region)
  -- A hidden font string in the pane's own body face, which the count column is measured with.
  Tree.ruler = newFontString(region, "OVERLAY")
  if Tree.ruler then
    setFont(Tree.ruler, Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_SM)
    Tree.ruler:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
    Tree.ruler:Hide()
  end
  if not initScrollBox(region) then
    initFallback(region)
  end
  -- The designed empty state sits over the list panel, so it is built after the list and keeps
  -- whatever frame level that leaves it with, which is above it.
  buildEmptyBlock(region)
  Tree.sticky = newRowFrame(region)
  if Tree.sticky then
    Tree.sticky:Hide()
  end
  wirePane(region)
  watchTurnIns(region)
  return true
end

-- Brief E61: the page notes the window hands over with the model, applied before the one draw.
--
--   nil                 a plain refresh. The search box and the scroll are the player's and are
--                       left exactly where they are: a row opened mid list must not jump.
--   { top = true }      an arrival that starts fresh. The list goes to the top of itself and the
--                       box keeps whatever the window put in it.
--   { restore = true }  a return: the remembered search text goes back in the box and the
--                       remembered offset is handed to the draw, which clamps it to this list.
local function applyPageState(state)
  if type(state) ~= "table" then
    return false
  end
  if state.restore then
    local search = nil
    if type(state.search) == "string" and state.search ~= "" then
      search = state.search
    end
    Tree.filter = search
    syncSearchBox(search or "")
    local vm = Tree.vm
    if vm and type(vm.SetSearching) == "function" then
      pcall(vm.SetSearching, vm, search ~= nil)
    end
  end
  Tree.pendingOffset = math.max(0, tonumber(state.offset) or 0)
  return true
end

--- Shows the pane for a view model, re-reading its rows. The window calls this on every
--- open, re-root and refresh. Remembers the view model even with no client, so a later
--- Attach and Refresh draws the right thing.
---
--- state is the page notes above, and is nil on a refresh.
function Tree.Show(vm, state)
  if vm ~= nil then
    Tree.vm = vm
    -- A view model the window has just built knows nothing about the box above the rows, so it
    -- is told once here as well as on every keystroke. A re-root clears the filter first, so
    -- this only ever matters when the same root is rebuilt under a search that is still live.
    if type(vm.SetSearching) == "function" then
      pcall(vm.SetSearching, vm, Tree.filter ~= nil)
    end
  end
  applyPageState(state)
  if not Tree.pane then
    return false
  end
  Tree.shown = true
  Tree.pane:Show()
  return Tree.Draw()
end

--- Redraws from the last view model.
function Tree.Refresh()
  if not Tree.pane then
    return false
  end
  return Tree.Draw()
end

--- Hides the pane and gives the keyboard back, the search box's focus with it: a hidden edit
--- box that still holds focus swallows the player's keys everywhere else.
function Tree.Hide()
  Tree.shown = false
  Tree.SetKeyboardCapture(false)
  local box = Tree.search
  if box and type(box.ClearFocus) == "function" then
    pcall(box.ClearFocus, box)
  end
  if not Tree.pane then
    return false
  end
  Tree.pane:Hide()
  return true
end

-- The window builds and attaches the pane, so there is nothing to do at load. Kept because
-- every panel carries an Init.
function Tree.Init()
  return false
end

return Tree
