-- The main ItemTree window: the portrait frame, the tab strip, the header, the body and the
-- footer, and the pane regions the other UI files draw into.
--
-- Design components: chrome/PortraitFrame.jsx, chrome/TabBar.jsx, frame/Breadcrumb.jsx,
-- controls/SearchBox.jsx, controls/Checkbox.jsx, controls/Button.jsx,
-- badges/ConfidenceLegend.jsx, the assembled screen in ui_kits/itemtree_addon/Frame.jsx, and
-- harness/src/render-design.tsx, which is the reproduction this file transliterates.
--
-- Anatomy (Theme.sizes), measured from the frame's own edges, at the default 1000 by 560:
--   ITEMTREE_FRAME_DEFAULT_W 1000 by ITEMTREE_FRAME_DEFAULT_H 560, never smaller than
--   ITEMTREE_FRAME_MIN_W 840 by ITEMTREE_FRAME_MIN_H 420.
--   ITEMTREE_FRAME_BORDER 16 ornamental border on three sides, and the template's own top chrome
--   above: the title art down to ITEMTREE_CHROME_TITLE_ART_H 21 and the round portrait, whose
--   ring reaches ITEMTREE_CHROME_PORTRAIT_INSET_X 64 in from the left edge and
--   ITEMTREE_CHROME_PORTRAIT_INSET_Y 68 down from the top. Those four edges are the window's
--   inner edge, which Frame.BodyInsets states: 16, 16, 68, 16.
--   The grey band between the title art and the inner edge is where the window's own top level
--   navigation lives, the way the Macro window carries its two tabs: the Item tree, Boss loot and
--   Discoveries tabs at ITEMTREE_CHROME_TAB_TOP_H 32 tall, each as wide as Frame.TopTabWidth
--   says its glyph and its word need, their bottom edge on the dark surface, starting clear of
--   the portrait at x 68, and the New toggle, the Changed toggle, the random item button, the
--   recently viewed button and the item search at ITEMTREE_CONTROL_H_MD 24 on the right of the
--   same band, right to left with ITEMTREE_SPACE_1 4 between each.
--   The dark body surface is inset ITEMTREE_CHROME_BODY_MARGIN 8 from every one of those four
--   inner edges: 24 in from the left and the right, 24 up from the bottom, 76 down from the top.
--   Inside it everything is inset another ITEMTREE_SPACE_2 8: 32, 32, 84, 32 from the frame's own
--   edges. That is the breadcrumb row at ITEMTREE_ROW_CATEGORY 24, the caption row at
--   ITEMTREE_CONTROL_H_SM 20 carrying the Show classic diff tick box, the content area with
--   ITEMTREE_SPACE_2 8 between the panes, and the footer row pinned at the bottom of the surface.
--   The ITEMTREE_CHROME_GRIP 16 resize grip sits in the frame's own bottom right corner, outside
--   the surface. The two side columns are ITEMTREE_LIST_COL_INFO and ITEMTREE_LIST_COL_SIDEBAR,
--   225 each: Frame.INFO_COLUMN_W and Frame.COLUMN_W.
--
-- The top tabs are the client's own PanelTopTabButtonTemplate, which both target branches define
-- as TabButtonTemplate (Interface/AddOns/Blizzard_SharedXML/Classic/SharedUIPanelTemplates.xml),
-- and which the Macro window uses for "General Macros" and "Character Specific Macros". The
-- template never changes the button's height when the tab is selected: the selected art hangs
-- 3px lower inside the same 32px button, which is what the home made tabs got wrong. A client
-- carrying neither template falls back to those home made buttons.
--
-- The portrait numbers are the client's own, read off PortraitFrameTemplate in
-- Interface/AddOns/Blizzard_SharedXML/Classic/SharedUIPanelTemplates.xml (the classic_era and
-- classic_beta branches of the wow-ui-source mirror carry the same XML): a 61 by 61 portrait
-- texture anchored TOPLEFT at (-6, 8) inside a 78 by 78 UI-Frame-Portrait ring anchored TOPLEFT
-- at (-14, 11), a 17px title tile from y -3 to y -20, and the rock background from y -21 down.
-- Blizzard's own ButtonFrameTemplate insets its content by (4, -60), which is the same idea.
--
-- The content area is the three pane composition of design/templates/bag-interaction, which is
-- the only design artefact that draws all three panes: info, then categories, then the tree
-- filling what is left, with the Item chain, Used by, Sources, Requires and Disenchants into view
-- tabs spanning the category and tree columns together because the view changes what both of them
-- list. The tree's own filter box shares that row, at its right hand end, so the sidebar and the
-- tree start at the same height directly under it: Frame.ViewRowFit shares the row out and
-- Frame.Regions().filter is what UI/Tree.lua re-parents its box into. Frame.jsx is
-- two columns at 620 by 460 with no info column, so the size and the order are both deviations,
-- recorded in docs/design-deviations.md.
--
-- Tabs are Item tree (the tab id is still "Tree") and Discoveries, with Boss loot registering
-- between them. History is not a tab: the rewind button on the tab row raises ItemTree.UI.History
-- as a modal over the window, the way the design's own overlays are drawn
-- (design/ui_kits/itemtree_addon/ScreensOther.jsx). Chain is not a tab any more either (brief C2):
-- it is the first of an item's view tabs, "Item chain", and UI/Chain.lua's pane draws in the space
-- the category column and the row list take while it is up. Discoveries owns a region filling the
-- content area, and a Discoveries module that is not loaded at all costs the window that tab
-- rather than an empty pane. The window never changes size when the tab changes.
--
-- The window sits at frame strata HIGH and is toplevel, because a nameplate (the player's own
-- personal resource bar) draws through MEDIUM and was landing between the body surface and the
-- panes. The search dropdown and the History modal are DIALOG, so both are still above it. The
-- client's own settings panel is HIGH and toplevel too, so it opened behind this window: while
-- the panel is up the window stays on screen at Frame.SETTINGS_STRATA, under the panel whatever
-- the player clicks, and goes back to HIGH after (brief E76). While the client's profession window
-- has the front, the window sits one strata under it, and a click on the window brings it back
-- (brief PW1, Frame.ProfessionsToFront and Frame.ItemTreeToFront).
--
-- The window scales itself: settings.windowScale (0.5 to 1.5) times Frame.AutoScale, which
-- normalises 1x to the screen so the same setting reads the same on a 1080p display and on a
-- high resolution one with a small UI scale. Only the one frame is scaled, so a pane that turns
-- cursor positions into frame positions through GetEffectiveScale still gets the right answer.
--
-- Client APIs: CreateFrame("Frame", name, UIParent, "PortraitFrameTemplate") with a plain
-- BackdropTemplate frame and the FRAME_BORDER asset behind it, PanelTemplates_SetNumTabs and
-- PanelTemplates_SetTab for the tab strip, UISpecialFrames for Escape, ITEM_QUALITY_COLORS for
-- the title, C_Timer.After to debounce the search and to put the window back after the settings
-- panel closes it, GetNumSkillLines and GetSkillLineInfo (or their C_SpellBook and
-- C_TradeSkillUI equivalents) for the player's professions, and Assets.Apply for every texture.
--
-- This file owns the window, the single ViewModel and three pieces of session state: the
-- view, the Show classic diff toggle and the sidebar's text filter. Open(key) builds the
-- window once, makes the model from ItemTree.db.settings, records the view through
-- ItemTree.History and then hands the model to the panes: UI/Sidebar.lua, UI/Tree.lua and
-- UI/InfoPanel.lua. The panes never build a model and never walk the graph, and re-rooting
-- always comes back here through Frame.Open, so the breadcrumb trail and the history are
-- written in one place.
--
-- Saved variables: the window rect in ItemTree.charDb.window and nothing else. The recently
-- viewed list is written only through ItemTree.History.
--
-- Everything above the "Client side" divider is pure and runs under busted with no WoW API.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local Frame = {}
ItemTree.UI.Frame = Frame

local Theme = ItemTree.Theme
local Assets = ItemTree.Assets
local Badges = ItemTree.Badges
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

Frame.FRAME_NAME = "ItemTreeFrame"

-- Tab order, left to right, from chrome/TabBar.jsx. History is not a tab any more: the recently
-- viewed button raises it as a modal instead, and Sources is not a tab any more either.
-- Discoveries is what this client has watched the realm find of the items the Forever build
-- withholds, which is a list of its own rather than anything the tree can walk to. Brief C2: the
-- Chain tab left this strip to become the Item chain view of an item (Frame.VIEW_TABS), so a
-- released build draws Item tree, Boss loot and Discoveries.
Frame.TABS = { "Tree", "Discoveries" }

-- The word a top tab carries where it is not the tab's own id, as a locale key. The owner renamed
-- the first tab "Item tree" (brief C2) and the id stays "Tree", because every file that sends the
-- window back to it names it that way. A tab this says nothing about carries its id.
Frame.TAB_WORDS = { Tree = "Item tree" }

-- The shorter word a tab falls back to on a narrow band (Frame.TabWords), before the tabs give way
-- to their glyphs alone and for the tab that keeps its word once they have. A tab with none keeps
-- its word as it is.
Frame.TAB_SHORT_WORDS = { Tree = "Tree" }

-- Tabs that are only drawn when their module is loaded. Discoveries is a whole file that a build
-- need not carry at all, and a tab that opens on nothing is worse than no tab.
Frame.OPTIONAL_TABS = { Discoveries = true }

-- The client's own top tab templates, best first. The Forever client (the mirror's `forever`
-- branch) builds PanelTopTabButtonTemplate from PanelTabButtonTemplate with PanelTopTabButtonMixin
-- on it, which flips the tab art to the bottom of the button and sets isTopTab; the classic_beta
-- branch defines the same name as plain TabButtonTemplate, with no mixin and no flip. Both carry
-- Left and Text, which is all this file probes for, and Frame.TabTextY reads the difference off
-- the button rather than assuming either. A client carrying neither falls back to the home made
-- buttons this file drew before.
Frame.TAB_TEMPLATES = { "PanelTopTabButtonTemplate", "TabButtonTemplate" }

-- The glyph beside each tab's word, so the panes read at a glance.
Frame.TAB_ICONS = { Tree = "ICON_TAB_TREE", Discoveries = "ICON_TAB_DISCOVERIES" }

-- The client's own tab metrics, read off TabButtonTemplate and PanelTemplates_TabResize on both
-- branches of the wow-ui-source mirror rather than guessed. The Left and Right art are 16px
-- each, so a tab is always 32 wider than the middle PanelTemplates_TabResize sizes, and the
-- default padding that function puts around the word is 24. The glyph asks for its own width on
-- top of that padding, so the tab widens for the group rather than the group being squeezed.
Frame.TAB_PADDING = 24
Frame.TAB_SIDE_ART = 16

-- The two numbers PanelTemplates_SelectTab and PanelTemplates_DeselectTab start from when they
-- re-anchor a tab's word: 3px under the tab's centre when it is selected and 2px over it when it
-- is not. They are the client's own defaults for a BOTTOM tab, whose deselected art sits at the
-- top of the button, and they are only the start of the sum. See Frame.TabTextY for the rest.
Frame.TAB_TEXT_Y = { selected = -3, deselected = 2 }

-- What the client does to those two numbers on a TOP tab, whose art hangs off the bottom of the
-- button instead. Both functions above read the base offset and then, where the tab says
-- isTopTab, flip it and drop it:
--   offsetY = -offsetY - 6   (deselected)
--   offsetY = -offsetY - 7   (selected)
-- from Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua on the mirror's `forever` branch,
-- which is the Forever client's own source. So the word lands at -4 selected and -8 deselected,
-- and a window that put its glyph on the un-flipped +2 left the glyph half above the tab.
Frame.TAB_TEXT_TOP_FLIP = { selected = 7, deselected = 6 }

-- The transparent margin inside the auction house clock's own 24 by 24 atlas rect, measured off
-- the extracted PNG: left, right, top, bottom. Frame.SquareGlyphOffset turns it into a nudge.
Frame.CLOCK_RECT = 24
Frame.CLOCK_PAD = { left = 2, right = 3, top = 2, bottom = 2 }

-- The same measurement for the group loot die on the random item button, off its own 32 by 32
-- file: the artwork runs edge to edge across and stops 3 rows short of the bottom, so it sits
-- high in its canvas and Frame.SquareGlyphOffset nudges it back down onto the button's centre.
Frame.DICE_RECT = 32
Frame.DICE_PAD = { left = 0, right = 0, top = 0, bottom = 3 }

-- How far below a square band button's own centre the bevel's opening sits. See
-- Frame.SquareGlyphOffset for the measurement.
Frame.BEVEL_DROP = 1

-- The tabs whose pane is one region filling the content area, and the region that holds it.
Frame.HOSTED = { Discoveries = "discoveries" }

-- Which rows of the window's own header each top tab draws.
--
--   crumbs   the breadcrumb trail, which says where the tree has been walked from
--   diffRow  the "Show classic diff" tick box and the caption beside it
--   viewRow  the view tab row over the sidebar and the tree, with the tree's filter box on it
--
-- All three are about the item the window is rooted on, and the Discoveries tab is a list rather
-- than an item: a trail of items nobody walked to get there and a tick box that turns change rows
-- on in a tree that is not showing say nothing, so that tab draws none of them and its list takes
-- the height back.
--
-- The rule is stated here rather than left to whichever frame happens to be a child of a hidden
-- one, so a reader can see what each tab draws without tracing the parents.
Frame.HEADER_ROWS = {
  Tree = { crumbs = true, diffRow = true, viewRow = true },
  Discoveries = { crumbs = false, diffRow = false, viewRow = false },
}

-- What a tab nothing has been decided for draws: the whole header, which is what every tab drew
-- before this rule existed. A tab added later cannot silently lose a row.
Frame.HEADER_ROWS_DEFAULT = { crumbs = true, diffRow = true, viewRow = true }

-- Whether a top tab draws the item the window is rooted on at all.
--
-- Tree is the item's own page, its chain included, so it follows a new root. Discoveries is a
-- list of what the realm has found: it draws nothing about the root, so an item opened while it
-- is up would change a root nobody can see, which is what the owner saw as a dropdown pick doing
-- nothing. A tab this says nothing about
-- draws the root, because that is what a tab in this window is for and a new one must not go
-- silently unreachable.
Frame.TAB_SHOWS_ROOT = { Tree = true, Discoveries = false }

-- Tabs that also wait on a setting: tab name to the key in ItemTree.db.settings that must be true
-- for the tab to be drawn, on top of its module being loaded (Frame.OPTIONAL_TABS). Turning the
-- setting on or off shows or hides the tab at once, with no reload: Frame.SyncTabs is the part
-- that touches the buttons, and Frame.RefreshFromSettings calls it for every setting change.
-- Empty in a released build.
Frame.TAB_SETTINGS = {}

-- Brief S6: the tabs this file declares that also wait on a setting, filed apart from
-- Frame.TAB_SETTINGS, which holds only what a module registers (Frame.RegisterTab) and so stays
-- empty in a released build. The Discoveries tab waits on showDiscoveries, which is off by
-- default (Core/Init.lua DB_DEFAULTS, brief E96): turning it on adds the tab, and nothing stops
-- being recorded either way.
Frame.DECLARED_TAB_SETTINGS = { Discoveries = "showDiscoveries" }

--- Adds a tab a module brings with it, after every tab this file declares: its name goes on the
--- end of Frame.TABS and it is filed in every table above, so it is drawn, hosted, gated and
--- worded exactly like a tab declared here. spec is
---   { region, icon, setting, headerRows = { crumbs, diffRow, viewRow }, showsRoot, before }
--- where region is the Frame.Regions() key its pane is handed, icon an Assets key, setting the
--- key in ItemTree.db.settings the tab waits on (Frame.TAB_SETTINGS), and showsRoot false for a
--- list that draws nothing about the root. before (brief BL8) names a tab already on the strip
--- this one goes in front of, which is how Boss loot sits between Tree and Discoveries; a name
--- that is not there puts the tab on the end as usual. The tab is always optional: a module that
--- registers a tab and then fails to load has no tab.
---
--- The developer only tabs register themselves this way from files the package never carries, so
--- a released build's copy of this file names none of them. Only before the window is built,
--- because the tab strip and the regions are made once; answers whether the tab was added, and
--- true for a name already on the strip.
function Frame.RegisterTab(name, spec)
  if type(name) ~= "string" or name == "" or type(spec) ~= "table" then
    return false
  end
  for _, existing in ipairs(Frame.TABS) do
    if existing == name then
      return true
    end
  end
  if Frame.frame then
    return false
  end
  local at = #Frame.TABS + 1
  if type(spec.before) == "string" then
    for index, existing in ipairs(Frame.TABS) do
      if existing == spec.before then
        at = index
        break
      end
    end
  end
  table.insert(Frame.TABS, at, name)
  Frame.OPTIONAL_TABS[name] = true
  if type(spec.setting) == "string" and spec.setting ~= "" then
    Frame.TAB_SETTINGS[name] = spec.setting
  end
  if type(spec.icon) == "string" then
    Frame.TAB_ICONS[name] = spec.icon
  end
  if type(spec.region) == "string" and spec.region ~= "" then
    Frame.HOSTED[name] = spec.region
  end
  if type(spec.headerRows) == "table" then
    Frame.HEADER_ROWS[name] = {
      crumbs = spec.headerRows.crumbs == true,
      diffRow = spec.headerRows.diffRow == true,
      viewRow = spec.headerRows.viewRow == true,
    }
  end
  if spec.showsRoot == false then
    Frame.TAB_SHOWS_ROOT[name] = false
  end
  return true
end

-- The view strip over the sidebar and the tree, in the order an item's views are drawn: "chain",
-- then Edges.VIEWS, "uses", "sources", "requires" and "disenchants". A view is a filter over the
-- two edge directions rather than a direction of its own (Core/Edges.lua owns the rule), so each
-- tab is named for the question it answers rather than for the way the tree walks. The chain view
-- (brief C2, Core/ViewModel.lua CHAIN_VIEW) is the one that is no filter: it draws UI/Chain.lua's
-- pane where the two lists go. The words are locale keys, the way Frame.TABS is. The strip draws
-- one tab per key Core states, so a root with fewer views leaves the rest of the buttons hidden
-- rather than offering a view nothing can answer.
Frame.VIEW_TABS = { "Item chain", "Used by", "Sources", "Requires", "Disenchants into" }

-- Brief C2: the chain view's key, which is Core/ViewModel.lua CHAIN_VIEW, stated here as well so
-- a window whose Core did not load still knows the name.
Frame.CHAIN_VIEW = "chain"

-- The word each view key carries, whichever set of views the root's kind has. The list above is
-- the order an ITEM's four are drawn in and is what a build whose Edges did not load falls back
-- to; this is the lookup, so a creature root's two tabs get their own words without the strip
-- having to know which index they sit at (brief E57).
Frame.VIEW_LABELS = {
  -- Brief C2: an item's chain, first of its tabs.
  chain = "Item chain",
  uses = "Used by",
  sources = "Sources",
  requires = "Requires",
  disenchants = "Disenchants into",
  loot = "Loot",
  map = "Map",
  -- Brief OL1: what an openable item holds, on an item root (Core/Edges.lua CONTAINS_VIEW).
  contains = "Contains",
  -- Brief N2: what a vendor sells, on an npc root.
  sells = "Sells",
  -- Brief N3: the quests an NPC starts and ends, on an npc root.
  quests = "Quests",
  -- Brief Z1: what Classic Era placed in a zone, on a zone root.
  here = "Here",
  -- Brief Q8: everything known about a quest, on a quest root (Core/ViewModel.lua QUEST_VIEWS).
  quest = "Quest",
  -- Brief P6b: the recipes a trainer teaches, on an npc root.
  teaches = "Teaches",
}

-- The shorter word a view tab falls back to where the row cannot hold every word even at the least
-- padding (Frame.ViewRowFit), before the client's ellipsis ends any of them. Brief C2.
Frame.VIEW_SHORT_LABELS = { chain = "Chain" }

-- The glyph a view tab carries beside its word, as an Assets key. Only the chain view has one: it
-- was a top tab with this glyph, and the owner kept the glyph when it moved (brief C2).
Frame.VIEW_ICONS = { chain = "ICON_TAB_CHAIN" }

-- The view the window opens on. The addon's promise is "what is this used for", so it is uses.
-- A root whose kind has no such view opens on the first view it does have, which is Loot on a
-- creature (Frame.DefaultView).
Frame.DEFAULT_VIEW = "uses"

-- The air either side of a view tab's word, the least it may be squeezed to, and the gap
-- between two tabs. Four tabs and the tree's filter box have to fit over the category column and
-- the start of the tree at the minimum window, so the padding is what gives way first and the
-- words are never cut.
Frame.VIEW_TAB_PAD = 12
Frame.VIEW_TAB_PAD_MIN = 4
Frame.VIEW_TAB_GAP = 2

-- The tree pane's filter box now shares the view tab row: the row reads [Used by][Sources]
-- [Requires][Disenchants into] [ search ... ] and the sidebar and the tree then start at the
-- same height under it. The box takes whatever the tabs leave, and this is the least it may be
-- given before the tabs start losing padding: at 140 the box still holds a typical placeholder
-- and a word or two of what was typed, which is the same floor Frame.SEARCH_W_MIN keeps for the
-- item search on the band above.
Frame.VIEW_FILTER_W_MIN = 140

-- The breadcrumb trail is capped. Eight is well past what Breadcrumb.jsx draws, and it stops the
-- trail growing without end on a long walk through a crafting chain.
Frame.PATH_LIMIT = 8

-- Breadcrumb.jsx shows at most four crumbs: the first, an ellipsis, then the last two.
Frame.CRUMB_MAX = 4

-- How many pages the window keeps notes on (brief E61): the last 24 it was rooted on, least
-- recently used dropped first. A page is a root key and the set of view tabs it draws, and its
-- notes are keys and numbers alone, so 24 of them is a few kilobytes and a walk of any length
-- costs the same. Well past the breadcrumb trail (Frame.PATH_LIMIT 8) and past a session's worth
-- of back and forth, and small enough that nothing has to be tidied up on a timer.
Frame.PAGE_MEMORY = 24

-- The item search on the tab row: how many results drop down, how wide the box is, and how long
-- a keystroke waits before the search runs. The harness drops twenty, which is also what
-- Data:SearchItems defaults to.
Frame.SEARCH_LIMIT = 20
-- Brief SR2: with "Search everything" on the dropdown holds a few more rows, and each kind has a
-- reserved share of them, in the order the kinds are drawn: items, creatures, then Core/Data.lua's
-- Data.SEARCH_KINDS. A share a kind does not fill is handed down to the next kind, and the items
-- refill whatever is still empty at the end. The shares add up to the limit.
Frame.SEARCH_LIMIT_EVERYTHING = 24
Frame.SEARCH_QUOTAS = { item = 10, creature = 4, quest = 2, vendor = 2, zone = 2, node = 2, set = 2 }
-- Brief SR4 (the owner, 2026-10-09): a kind with more matches than its rows show ends its rows
-- with a "+N more" row (N the matches not shown yet, Frame.SearchMoreText), drawn in the hint
-- colour with this glyph, the one the tree's own "Show N more" row wears. Pressing it, or Enter on
-- it, shows this many more of that kind where it stood, in rank order, until the text changes.
-- The first screen keeps the limits and shares above; the more rows and the rows they open come
-- on top of them, and the dropdown scrolls.
Frame.SEARCH_MORE_STEP = 20
Frame.SEARCH_MORE_ASSET = "ICON_ZOOMIN"
-- Brief S8, the owner's addendum (2026-10-09): the header row above each kind's rows wears the item
-- page's section header look (UI/Tree.lua Tree.CATEGORY_BAND and Tree.BORDER_COLOR: the sticky
-- surface between two divider hairlines, the words in the body colour), slimmed to the dropdown's
-- own row height, with no chevron, no marks and no count.
Frame.SEARCH_HEADER_WORD = "ITEMTREE_COLOR_TEXT_BODY"
Frame.SEARCH_HEADER_BAND = "ITEMTREE_COLOR_SURFACE_STICKY"
Frame.SEARCH_HEADER_LINE = "ITEMTREE_COLOR_BORDER_DIVIDER"
Frame.SEARCH_HEADER_PAD = 6
Frame.SEARCH_W = 170
-- How narrow the search box is allowed to get before the recently viewed button gives up its
-- words. At 140 the box still holds a typical item name and its placeholder. Brief UX1 (QA item
-- 403) took the trainer button's square and its gap (28) out of the floor, so the band at the 840
-- minimum is laid out exactly as it was before the button: every tab and the Recent button keep
-- their words, and only the box, which gives way first by the owner's rule, is 28 narrower there.
-- At 112 it still holds a short name ("Linen Cloth") or "t:warlock" beside its glyph; a longer
-- one scrolls in the box as it is typed.
Frame.SEARCH_W_MIN = 112
Frame.SEARCH_DEBOUNCE = 0.15

-- The dropdown's right hand columns, right to left. The id keeps a fixed column of its own, so
-- every id down the list is right aligned on the same pixel; the badge column beside it has room
-- for both marks whether a row carries one, two or none, so a mark never moves the name beside
-- it; and the name stops at the badge column and is truncated with the client's own ellipsis
-- rather than running under it. SEARCH_ID_W is the widest id the data build carries drawn at
-- ITEMTREE_FONTSIZE_BODY_SM, with air. New and Changed is every mark Core/Diff keeps for an item.
Frame.SEARCH_BADGE_MAX = 2
Frame.SEARCH_ID_W = 46
Frame.SEARCH_PAD = 6
Frame.SEARCH_COL_GAP = ((Theme and Theme.sizes) or EMPTY).ITEMTREE_SPACE_1 or 4
-- A creature row has no id and no marks, and says what kind of creature it is and its level band
-- in their place ("Humanoid, 55 to 56"), and a quest or other page row its kind words ("Quest").
-- Brief S7: those words are measured and drawn only as wide as they are, up to this width, and
-- the name takes the rest (Frame.SearchNameRight). Wide enough for the longest kind word and a two
-- number band at ITEMTREE_FONTSIZE_BODY_SM; anything longer is truncated by the client.
Frame.SEARCH_KIND_W = 104

-- How much wider than the search box the dropdown hangs. It is anchored by its right edge and
-- clamped to the screen, so it is free to be wider than the box: the badge column would
-- otherwise come out of the name, and typical item names already fill the old width.
Frame.SEARCH_LIST_EXTRA = 70

-- Brief SR3: the most rows the dropdown draws at once. A longer answer (20 items and creatures, or
-- Search everything's 24) scrolls under the mouse wheel and the arrow keys rather than growing the
-- list until the screen clamp pushes it up over the search box. Only this many row frames are ever
-- made. The scroll bar is a slim track and thumb down the right hand edge, the width the chain's
-- own drop down draws (UI/Chain.lua MENU_SCROLLER_W), shown only while there is more to scroll.
-- Brief N4: 16, held to the room the window leaves under the search box (Frame.SearchRowsFor), and
-- never fewer than Frame.SEARCH_MIN_ROWS.
Frame.SEARCH_VISIBLE_ROWS = 16
Frame.SEARCH_MIN_ROWS = 8
Frame.SEARCH_SCROLLER_W = 4

-- Cache invalidation for Frame.PlayerSkills.
Frame.SKILL_EVENTS = { "SKILL_LINES_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_ENTERING_WORLD" }

-- The confidence legend in the footer, in the order Frame.jsx lists it, with Season of
-- Discovery (the New mark in purple, brief D2) straight after New. Brief GS3 asked for the guess
-- mark after Predicted, and it does not fit: the footer would want 822 of the 776 the row has at
-- Frame.MinSize. It waits on the owner's call (a wider minimum, or shorter legend words).
Frame.LEGEND_KINDS = { "new", "sod", "changed", "note", "predicted" }

-- The category column and the item info column. Read once, with the design's own numbers as the
-- fallback, so the module still loads if Theme is ever absent.
Frame.COLUMN_W = ((Theme and Theme.sizes) or EMPTY).ITEMTREE_LIST_COL_SIDEBAR or 225
Frame.INFO_COLUMN_W = ((Theme and Theme.sizes) or EMPTY).ITEMTREE_LIST_COL_INFO or Frame.COLUMN_W

-- The window's frame strata. A nameplate draws through MEDIUM, which is where the personal
-- resource bar was landing between the body surface and the panes.
Frame.STRATA = "HIGH"

-- The strata the search dropdown and anything else that must clear every pane is raised into.
Frame.OVERLAY_STRATA = "DIALOG"

-- Where the window sits while the client's own settings panel is up. SettingsPanel is declared
-- frameStrata="HIGH" toplevel="true" on both branches, the same as this window, so with both at
-- HIGH the panel opened behind the window whose Options button raised it. The window stays
-- visible and drops one strata instead, and goes back to Frame.STRATA when the panel has gone.
Frame.SETTINGS_STRATA = "MEDIUM"

-- settings.windowScale is a multiplier the player sets, clamped to this range. Core owns the
-- numbers, because it is Core that migrates a saved setting and Core that the options panel's
-- slider reads; these are the fallbacks for a load order that has not reached Core/Init.lua.
Frame.SCALE_MIN = ItemTree.SCALE_MIN or 0.5
Frame.SCALE_MAX = ItemTree.SCALE_MAX or 1.5

-- Every scale is multiplied by this. The window was drawn larger than the owner wanted at every
-- setting, so 1.0 now means 0.85 of what it used to; Core migrates the saved windowScale by the
-- reciprocal so nobody's window changes size on the first login after this. Read off Core rather
-- than declared again here, so the two cannot drift.
Frame.SCALE_BASE = ItemTree.SCALE_BASE or 0.85

-- What the scale is actually multiplied by, asked of Core every time rather than read once: the
-- TOC can load this file before Core/Init.lua, and the answer must be Core's either way.
function Frame.ScaleBase()
  return tonumber(ItemTree.SCALE_BASE) or Frame.SCALE_BASE or 0.85
end

-- 1x is normalised to the screen: the window is sized so the default rect fills this much of
-- UIParent, never below 1x and never past 2x. A common 1080p setup lands on about 1x, which is
-- the size the window has always been; a high resolution display with a small UI scale, where
-- the same window is half the size the owner wants, lands near 2x.
Frame.SCALE_SCREEN_FRACTION = 0.75
Frame.AUTO_SCALE_MIN = 1.0
Frame.AUTO_SCALE_MAX = 2.0

-- Cache invalidation for the scale: the client says when UIParent changed shape.
Frame.SCALE_EVENTS = { "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }

-- Brief E91: the combat edges. PLAYER_REGEN_DISABLED runs Frame.OnCombatStart's list, the last
-- moment a protected call is allowed, and PLAYER_REGEN_ENABLED runs Frame.AfterCombat's queue.
Frame.COMBAT_EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

-- Brief RO1: a /reload or a logout with the window up writes down where it is (Frame.OnLogout), so
-- the first open of the next session comes back to it. PLAYER_LOGOUT is the event the client fires
-- before it writes the saved variables, on a /reload as well.
Frame.LOGOUT_EVENT = "PLAYER_LOGOUT"

-- Node keys behind the current root, oldest first.
Frame.path = {}

-- Brief E97: the bosses the trail has passed through, by crumb key (Frame.BossCrumbKey), each the
-- record the Boss loot tab handed over when an item was opened from that boss's loot. In memory
-- only, one per boss at most, so it is bounded by the index and needs no tidying.
Frame.bossCrumbs = {}

-- Which panes have been handed their region. Reset nowhere: the window is built once.
Frame.attached = {}

-- Session state, none of which reaches saved variables. views is the view tab the player left
-- each SET of tabs on, showChanges is the Show classic diff tick box on the caption row, and
-- textFilter is whatever the sidebar's search box holds.
--
-- Two roots can have two different sets of tabs (brief E57: an item has four, a creature has Loot
-- and Map), and the view is the player's and it sticks, so one slot per set rather than one for
-- the window: pressing Loot on a creature must not move the item tab they left. Frame.view beside
-- it is the last view set anywhere, and it is only ever read as the seed for a set that has no
-- memory of its own yet, so a caller that writes it still puts the window where it asked.
Frame.views = {}
Frame.view = Frame.DEFAULT_VIEW
-- Brief GW3 (2B): the sets of tabs whose remembered view Frame.ItemOpenView put there (an openable
-- item with no uses landing on Contains), not the player; a tab press clears its set's mark.
Frame.autoViews = {}

-- Brief E61: what the player did to the last Frame.PAGE_MEMORY pages, so coming back to one puts
-- them where they were. { pages = { [pageKey] = page }, order = { pageKey, ... } }, oldest key at
-- the front. A field on this table like everything else here: in memory, gone on a reload, and
-- never written to saved variables.
Frame.memory = { pages = {}, order = {} }
-- Off to start with: the diff rows are a thing the player asks for, not the first thing the
-- window shows them.
Frame.showChanges = false
Frame.textFilter = nil

-- Item quality index to a Theme colour key, through Theme's own name table so the two cannot
-- drift. An unknown quality reads as common, which is what the client does with item links.
local function qualityColourKey(quality)
  local names = (Theme and Theme.QUALITY_NAMES) or EMPTY
  local name = names[tonumber(quality) or 1] or "common"
  return "ITEMTREE_COLOR_QUALITY_" .. string.upper(name)
end

-- "item:2835" -> "item", 2835, through Graph so no one here parses a key by hand.
local function parseKey(key)
  local Graph = ItemTree.Graph
  if not (Graph and type(Graph.Parse) == "function") then
    return nil, nil
  end
  return Graph.Parse(key)
end

-- An item id to the node key the window roots on, through Graph for the same reason.
local function itemNodeKey(itemId)
  local Graph = ItemTree.Graph
  if Graph and type(Graph.Key) == "function" then
    return Graph.Key("item", itemId)
  end
  return "item:" .. tostring(itemId)
end

-- The item id a node key names, or nil for every other kind of node.
function Frame.ItemId(key)
  local kind, id = parseKey(key)
  if kind == "item" then
    return id
  end
  return nil
end

-- The node Core states for a key, or nil where Core is not loaded. Guarded, so the window still
-- draws under a Core that has no Graph at all.
local function graphNode(key)
  local Graph = ItemTree.Graph
  if not (Graph and type(Graph.Node) == "function") then
    return nil
  end
  local ok, node = pcall(Graph.Node, key)
  if ok and type(node) == "table" then
    return node
  end
  return nil
end

-- Title text, Theme colour key and quality for an item. The name comes from Core, which is the
-- one place that knows what an item is called: the data build's own name, the live client's
-- where the realm has found an item the build withholds, and "Undiscovered mail head" for a
-- withheld item nothing has found yet. An item nothing can name still opens, under its id.
function Frame.TitleFor(itemId)
  itemId = tonumber(itemId)
  local node = itemId and graphNode(itemNodeKey(itemId)) or nil
  if node and type(node.name) == "string" and node.name ~= "" then
    return node.name, qualityColourKey(node.quality), tonumber(node.quality)
  end
  -- A Core with no Graph, which is what the harness and the older specs load.
  local Data = ItemTree.Data
  local item = nil
  if itemId and Data and type(Data.GetItem) == "function" then
    item = Data:GetItem(itemId)
  end
  if item and item.n then
    return item.n, qualityColourKey(item.q), tonumber(item.q)
  end
  if itemId then
    return string.format(L["Item %d"], itemId), qualityColourKey(nil), nil
  end
  return L["ItemTree"], "ITEMTREE_COLOR_TEXT_TITLE", nil
end

-- The readable title Core states for a node key: an item's name, "Spell: Spiced Wolf Meat (2539)"
-- for anything else, and nil where Core has nothing to say. One place, so the window title, the
-- crumbs and the history all read the same.
local function graphTitle(key)
  local Graph = ItemTree.Graph
  if not (Graph and type(Graph.Title) == "function") then
    return nil
  end
  local ok, title = pcall(Graph.Title, key)
  if ok and type(title) == "string" and title ~= "" then
    return title
  end
  return nil
end

-- Brief Q9b: a node page (a herb, a vein, a fishing pool or a chest the shipped table places on a
-- map, which is exactly the object root that has a page) reads "Black Lotus node" in the title
-- bar and the breadcrumb, as its header does (UI/InfoPanel.lua ObjectHeader). The word follows the
-- name in the same text, so it takes the same colour. Two table lookups (E:ObjectMap), nothing
-- decoded; any other key and a load without Core/EraSources.lua keep the title as it was.
--
-- Brief QN1: a quest in a chain of same titled quests reads with its number in the title bar and
-- the breadcrumb, "Quest: Taming the Beast (II) (6062)" (Core/ViewModel.lua QuestTitleText).
local function nodeTitle(key, title)
  if type(title) == "string" and title ~= "" and parseKey(key) == "quest" then
    local ViewModel = ItemTree.ViewModel
    if type(ViewModel) == "table" and type(ViewModel.QuestTitleText) == "function" then
      local ok, shown = pcall(ViewModel.QuestTitleText, key, title)
      if ok and type(shown) == "string" and shown ~= "" then
        return shown
      end
    end
    return title
  end
  if type(title) ~= "string" or title == "" or parseKey(key) ~= "object" then
    return title
  end
  -- P6b addendum: a node page with no pins is a node page too (E:ObjectPage).
  local era = ItemTree.eraSources
  local method = type(era) == "table" and (era.ObjectPage or era.ObjectMap) or nil
  if type(method) ~= "function" then
    return title
  end
  local ok, nameIndex = pcall(method, era, key)
  if not ok or type(nameIndex) ~= "number" then
    return title
  end
  -- Brief EO1: a quest giving object's page (a wanted poster) is no node: its own name.
  if type(era.ObjectGiverOnly) == "function" then
    local okGiver, giver = pcall(era.ObjectGiverOnly, era, key)
    if okGiver and giver == true then
      return title
    end
  end
  return string.format(L["%s node"], title)
end

-- The label a crumb carries. Items read as their name in the trail, every other kind as
-- Graph.Title, then the name the collector recorded, then the key itself, so a crumb is never
-- blank and a spell never reads as "spell:2539".
function Frame.LabelFor(key)
  if Frame.IsBossCrumb(key) then
    local record = Frame.bossCrumbs[key]
    local name = type(record) == "table" and record.bossName or nil
    if type(name) == "string" and name ~= "" then
      return name
    end
    return L["Boss loot"]
  end
  local kind, id = parseKey(key)
  if kind == "item" then
    return (Frame.TitleFor(id))
  end
  local title = graphTitle(key)
  if title then
    return nodeTitle(key, title)
  end
  local Graph = ItemTree.Graph
  local named = Graph and Graph.names and Graph.names[key]
  return named or tostring(key)
end

-- Title text and Theme colour key for any node key, which is what the title bar draws. An item
-- keeps its quality colour; everything else is gold, because a spell has no quality.
function Frame.TitleForKey(key)
  local kind, id = parseKey(key)
  if kind == "item" then
    return Frame.TitleFor(id)
  end
  if key == nil then
    return L["ItemTree"], "ITEMTREE_COLOR_TEXT_TITLE", nil
  end
  return nodeTitle(key, graphTitle(key)) or tostring(key), "ITEMTREE_COLOR_TEXT_TITLE", nil
end

-- Brief E99: what the title bar says with a given top tab up. A tab that draws the root (Item
-- tree) is titled after it, as Frame.TitleForKey says; a tab that draws nothing about the root
-- (Boss loot, Discoveries, Guesses: Frame.TabShowsRoot) carries its own tab word instead, so the
-- bar never keeps the name of an item that tab is not showing. Same three answers as
-- Frame.TitleForKey. Pure.
function Frame.TitleForTab(tabName, rootKey)
  if tabName ~= nil and not Frame.TabShowsRoot(tabName) then
    return L[Frame.TabWord(tabName)], "ITEMTREE_COLOR_TEXT_TITLE", nil
  end
  return Frame.TitleForKey(rootKey)
end

-- The node key the player came from to reach this one: the entry before the current root in the
-- navigation trail, or nil at the start of it. The chain pane passes it to Core as opts.prefer,
-- so arriving at a recipe from Arcane Crystal keeps Arcane Crystal as the followed reagent.
-- Both arguments are optional and default to the window's own trail and root.
function Frame.PreviousKey(path, current)
  if path == nil then
    path = Frame.path
  end
  if type(path) ~= "table" then
    return nil
  end
  if current == nil then
    current = Frame.rootKey
  end
  local index = #path
  for position, key in ipairs(path) do
    if key == current then
      index = position
    end
  end
  if index <= 1 then
    return nil
  end
  -- Brief E97: a boss crumb is not a node the chain can follow, and the item before it was not
  -- where this one was reached from, so an item opened from a boss's loot has no previous key.
  if Frame.IsBossCrumb(path[index - 1]) then
    return nil
  end
  return path[index - 1]
end

-- Adds a key to the breadcrumb trail and returns the new trail. Re-rooting onto a key already in
-- the trail trims back to it rather than repeating it, which is what a crumb click does, so
-- walking back and forth cannot grow the trail. The oldest crumbs fall off the front at the cap.
function Frame.PushPath(path, key, limit)
  local out = {}
  if type(path) == "table" then
    for index, value in ipairs(path) do
      out[index] = value
    end
  end
  if key == nil then
    return out
  end
  for index, value in ipairs(out) do
    if value == key then
      for drop = #out, index + 1, -1 do
        out[drop] = nil
      end
      return out
    end
  end
  out[#out + 1] = key
  limit = tonumber(limit) or Frame.PATH_LIMIT
  while #out > limit and limit > 0 do
    table.remove(out, 1)
  end
  return out
end

-- The breadcrumb list to draw. path is Frame.path and current is the key the window is rooted
-- on: that crumb is gold and not clickable, the earlier ones are muted and re-root back to
-- themselves. Past max crumbs the middle collapses to one ellipsis crumb, the way
-- frame/Breadcrumb.jsx collapses it.
function Frame.Crumbs(path, current, max)
  local crumbs = {}
  if type(path) ~= "table" then
    return crumbs
  end
  local currentIndex = #path
  for index, key in ipairs(path) do
    if key == current then
      currentIndex = index
    end
  end
  for index, key in ipairs(path) do
    crumbs[index] = {
      key = key,
      index = index,
      label = Frame.LabelFor(key),
      current = index == currentIndex,
    }
    if Frame.IsBossCrumb(key) then
      crumbs[index].boss = true
      crumbs[index].tooltip = Frame.BossCrumbTooltip(Frame.bossCrumbs[key])
    end
  end
  max = tonumber(max) or Frame.CRUMB_MAX
  if max < 3 or #crumbs <= max then
    return crumbs
  end
  local shown = { crumbs[1], { label = "...", ellipsis = true, current = false } }
  for index = #crumbs - (max - 3), #crumbs do
    shown[#shown + 1] = crumbs[index]
  end
  return shown
end

--------------------------------------------------------------------------------
-- The boss crumb (brief E97)
--
-- An item opened from a boss's loot list on the Boss loot tab leaves the boss in the trail, just
-- before the item: "Shortsword of Vengeance > Geilhast > Reef Axe", or "Geilhast > Reef Axe" where
-- the window opened straight on Boss loot. The trail before the boss is whatever it was before the
-- tab was opened, because moving between top tabs never touches it. A boss crumb is a string in
-- Frame.path like any other, in a shape Graph.Parse does not read ("bossloot:1:12"), so nothing
-- that walks the graph can mistake it for a node. Its click goes back to the Boss loot tab on that
-- place and boss, with the lists scrolled where they were when the item was opened.
--------------------------------------------------------------------------------

Frame.BOSS_TAB = "Boss loot"
Frame.BOSS_CRUMB_PREFIX = "bossloot:"

-- The crumb key for one boss of one place, or nil where either is missing. Pure.
function Frame.BossCrumbKey(place, boss)
  if place == nil or boss == nil then
    return nil
  end
  return Frame.BOSS_CRUMB_PREFIX .. tostring(place) .. ":" .. tostring(boss)
end

-- Whether a trail entry is a boss crumb rather than a node key. Pure.
function Frame.IsBossCrumb(key)
  return type(key) == "string" and key:sub(1, #Frame.BOSS_CRUMB_PREFIX) == Frame.BOSS_CRUMB_PREFIX
end

-- The boss crumb's tooltip, "Blackfathom Deeps, Boss loot", or just "Boss loot" where the place
-- has no name to give. Pure.
function Frame.BossCrumbTooltip(record)
  local place = type(record) == "table" and record.placeName or nil
  if type(place) == "string" and place ~= "" then
    return string.format(L["%s, %s"], place, L["Boss loot"])
  end
  return L["Boss loot"]
end

-- Files the origin an open carried (opts.origin, from UI/BossLoot.lua) under its crumb key and
-- answers the key, or nil where the open did not come from a boss's loot. The record is a copy,
-- so the Boss loot tab's own state cannot write through it. A later open from the same boss
-- replaces it, which is what keeps the scroll the latest one. store defaults to the window's own.
--
--   origin = { kind = "boss", place, boss, placeName, bossName, offsets = { places, bosses, loot } }
function Frame.RememberBoss(origin, store)
  if type(origin) ~= "table" or origin.kind ~= "boss" then
    return nil
  end
  local key = Frame.BossCrumbKey(origin.place, origin.boss)
  if not key then
    return nil
  end
  local offsets = {}
  if type(origin.offsets) == "table" then
    for _, name in ipairs({ "places", "bosses", "loot" }) do
      offsets[name] = tonumber(origin.offsets[name]) or 0
    end
  end
  store = store or Frame.bossCrumbs
  store[key] = {
    kind = "boss",
    place = origin.place,
    boss = origin.boss,
    placeName = origin.placeName,
    bossName = origin.bossName,
    offsets = offsets,
  }
  return key
end

-- The trail after an item is opened from a boss's loot: the boss, then the item. Opening an item
-- the trail already holds first trims back to just before it, so the boss always sits directly in
-- front of the item it was opened from ("A > Reef Axe > B" and Reef Axe from Geilhast reads
-- "A > Geilhast > Reef Axe"); a boss already on the trail trims back to it, as a crumb does. The
-- cap then drops the oldest from the front. The trail handed in is left alone. Pure.
function Frame.PushBossPath(path, bossKey, key, limit)
  local out = {}
  if type(path) == "table" then
    for index, value in ipairs(path) do
      out[index] = value
    end
  end
  if key ~= nil then
    for index, value in ipairs(out) do
      if value == key then
        for drop = #out, index, -1 do
          out[drop] = nil
        end
        break
      end
    end
  end
  if bossKey ~= nil then
    out = Frame.PushPath(out, bossKey, limit)
  end
  return Frame.PushPath(out, key, limit)
end

-- Whether a mark is drawn at all. The two settings are the ones Core/ViewModel.lua reads for the
-- tree, so the window's own New and Changed toggles switch the search results with everything
-- else. opts is a Frame.OptionsFromSettings table; anything else reads as both marks on.
local function badgeAllowed(opts, kind)
  if type(opts) ~= "table" then
    return true
  end
  -- Season of Discovery is New in purple, so the New toggle switches it with New.
  if kind == "new" or kind == "sod" then
    return opts.badgesNew ~= false
  end
  if kind == "changed" then
    return opts.badgesChanged ~= false
  end
  return true
end

-- The marks Core keeps against one item, in Core/Diff's own order, with the two the player has
-- switched off dropped. Guarded: a build whose Diff cannot be asked answers with no marks rather
-- than raising, which is what leaves the dropdown drawable under busted with no data loaded.
local function itemBadges(itemId, opts)
  local out = {}
  local Diff = ItemTree.Diff
  if not (itemId and Diff and type(Diff.Badges) == "function") then
    return out
  end
  local ok, kinds = pcall(Diff.Badges, "items", itemId)
  if not ok or type(kinds) ~= "table" then
    return out
  end
  for _, kind in ipairs(kinds) do
    if badgeAllowed(opts, kind) then
      out[#out + 1] = kind
    end
  end
  return out
end

-- What a creature row in the dropdown says in its right hand column: the kind of creature it is
-- and its level band, as the creature page states them ("Humanoid, 55 to 56", "Wolf, 12"). The
-- beast family where there is one, because it is the more telling word of the two and the column
-- is narrow, and the type otherwise; the level as the page's Level line says it, one number where
-- the band is one level. nil where nothing states either. Pure.
--
-- Brief N1: the type the data calls "not specified" (10) reads "Creature" here ("Creature, 63"),
-- not "Unknown creature". A Forever NPC (entry.forever, Core/Data.lua Data:SearchCreatures) has
-- no level anywhere local, so it reads its role where one is known ("Vendor", "Trainer", "Quest
-- giver"), else its kind, else "Creature".
-- Brief PS5: "stable", a stable master the shipped player module names.
Frame.SEARCH_ROLE_WORDS = { vendor = "Vendor", trainer = "Trainer", quest = "Quest giver", stable = "Stable master" }

function Frame.SearchKindText(entry)
  if type(entry) ~= "table" then
    return nil
  end
  local Sources = ItemTree.Sources
  local types = (type(Sources) == "table" and Sources.CREATURE_TYPES) or EMPTY
  local families = (type(Sources) == "table" and Sources.CREATURE_FAMILIES) or EMPTY
  local word = families[entry.family] or types[entry.type]
  if not families[entry.family] and tonumber(entry.type) == 10 then
    word = "Creature"
  end
  local kind = word and L[word] or nil
  if entry.forever then
    local role = Frame.SEARCH_ROLE_WORDS[entry.role]
    return (role and L[role]) or kind or L["Creature"]
  end
  local low, high = tonumber(entry.low), tonumber(entry.high)
  local level = nil
  if low then
    if not high or high <= low then
      level = tostring(low)
    else
      level = string.format(L["%d to %d"], low, high)
    end
  end
  if kind and level then
    if type(Sources) == "table" and type(Sources.WithNote) == "function" then
      return Sources.WithNote(kind, level)
    end
    return kind .. ", " .. level
  end
  return kind or level
end

-- One creature result as a dropdown row: the npc key its page opens on, its name, the kind and
-- level band where an item shows its id, and the glyph its rows wear in the tree (the same Assets
-- key, out of Core/ViewModel.lua CreatureIcon). No id, no quality and no marks: Core keeps no
-- New or Changed against a creature.
local function creatureSearchRow(entry)
  local ViewModel = ItemTree.ViewModel
  local asset = nil
  if type(ViewModel) == "table" and type(ViewModel.CreatureIcon) == "function" then
    local ok, value = pcall(ViewModel.CreatureIcon, { type = entry.type, family = entry.family })
    if ok and type(value) == "string" and value ~= "" then
      asset = value
    end
  end
  local Sources = ItemTree.Sources
  local tooltipText = nil
  if type(Sources) == "table" and type(Sources.KindText) == "function" then
    -- Brief N1: the not specified type (10) says "Creature" here, as the right hand column does.
    local asked = entry
    if tonumber(entry.type) == 10 then
      asked = { family = entry.family, low = entry.low, high = entry.high }
    end
    local ok, value = pcall(Sources.KindText, asked)
    if ok and asked ~= entry and type(Sources.WithNote) == "function" then
      ok, value = pcall(Sources.WithNote, L["Creature"], value)
    end
    if ok and type(value) == "string" and value ~= "" then
      tooltipText = value
    end
  end
  -- A Forever NPC has no level to state, so its tooltip says what its row says.
  if entry.forever then
    tooltipText = Frame.SearchKindText(entry)
  end
  return {
    key = entry.key,
    tooltipText = tooltipText,
    creature = true,
    name = entry.name,
    colourKey = "ITEMTREE_COLOR_TEXT_BODY",
    asset = asset,
    idText = Frame.SearchKindText(entry) or "",
    badges = {},
    kinded = true,
  }
end

-- Brief SR1: the glyph each other kind of result wears, the Assets key its rows wear in the tree
-- (UI/Tree.lua NODE_ICONS, Core/ViewModel.lua NODE_GLYPHS). A node's is its own kind's.
Frame.SEARCH_KIND_ASSETS = {
  quest = "QUEST_AVAILABLE",
  vendor = "CAT_VENDOR",
  zone = "CAT_ZONE",
  set = "CAT_SET",
  herb = "CAT_HERBALISM",
  vein = "CAT_MINING",
  fished = "CAT_FISH_SCHOOL",
  object = "CAT_CHEST",
}

-- What a result of one of the other kinds (Core/Data.lua Data:SearchKind) says in its right hand
-- column, the way a creature row says "Humanoid, 55 to 56": "Quest" (with the zone where the
-- curated table states one), "Vendor, Stormwind City", "Zone" or "Instance", "Herb node", "Mining
-- node", "Fishing pool" or "Chest", "Set, 5 pieces". Each word is its own locale literal. nil for anything
-- else. Pure.
function Frame.SearchKindWords(entry)
  if type(entry) ~= "table" then
    return nil
  end
  local kind = entry.kind
  local word, detail = nil, nil
  if kind == "quest" then
    word, detail = L["Quest"], entry.zone
  elseif kind == "vendor" then
    word, detail = L["Vendor"], entry.zone
  elseif kind == "zone" then
    if entry.instance then
      word = L["Instance"]
    else
      word = L["Zone"]
    end
  elseif kind == "node" then
    -- Brief SR3: the node page's own words (UI/InfoPanel.lua ObjectKindWord), the same locale
    -- keys, so a row and the page it opens say the same thing.
    if entry.node == "herb" then
      word = L["Herb node"]
    elseif entry.node == "vein" then
      word = L["Mining node"]
    elseif entry.node == "fished" then
      word = L["Fishing pool"]
    else
      word = L["Chest"]
    end
  elseif kind == "set" then
    word = L["Set"]
    local pieces = tonumber(entry.pieces)
    if pieces and pieces > 0 then
      detail = string.format(L["%d pieces"], pieces)
    end
  end
  if not word then
    return nil
  end
  if type(detail) == "string" and detail ~= "" then
    return word .. ", " .. detail
  end
  return word
end

-- One result of the other kinds as a dropdown row: the page key it opens, its name, its kind words
-- where an item shows its id, and its glyph (a set wears its head or chest piece's icon where the
-- data has one, out of Core/ViewModel.lua SetIcon). No id, no quality and no marks, like a creature.
local function kindSearchRow(entry)
  local assetKey = Frame.SEARCH_KIND_ASSETS[entry.kind]
  if entry.kind == "node" then
    assetKey = Frame.SEARCH_KIND_ASSETS[entry.node] or Frame.SEARCH_KIND_ASSETS.object
  end
  local iconFile = nil
  local ViewModel = ItemTree.ViewModel
  if entry.kind == "set" and type(ViewModel) == "table" and type(ViewModel.SetIcon) == "function" then
    local ok, file = pcall(ViewModel.SetIcon, entry.key)
    if ok and file ~= nil then
      iconFile = file
    end
  end
  local words = Frame.SearchKindWords(entry) or ""
  return {
    key = entry.key,
    kind = entry.kind,
    -- Brief S8: a node's own kind, which its group's header words read (Frame.SearchGroupWords).
    node = entry.node,
    tooltipText = words,
    name = entry.name,
    colourKey = "ITEMTREE_COLOR_TEXT_BODY",
    asset = assetKey,
    iconFile = iconFile,
    idText = words,
    badges = {},
    kinded = true,
  }
end

-- Brief S6 (the owner, 2026-10-03: "if something is a quest item add a '!' icon next to its name
-- in the search panel"): the quest item class (12) and the quest item bind kind (4), as the shipped
-- data writes them (Core/Data.lua item.c and item.b), and the glyph the quest rows wear.
Frame.SEARCH_QUEST_CLASS = 12
Frame.SEARCH_QUEST_BINDING = 4
Frame.SEARCH_QUEST_ASSET = "QUEST_AVAILABLE"

-- Brief S6: whether an item search result is a quest item, true or false. Read from our own data
-- only, never the client: the class the result carries or the Names module states (Data:ItemGlance,
-- no item table built), and where that is not the quest class, the item row's bind kind through
-- Data:PeekItem, which never loads ItemTree_Data. Anything that is not an item result is false.
function Frame.SearchQuestItem(entry)
  local id = type(entry) == "table" and tonumber(entry.id) or nil
  if not id then
    return false
  end
  if tonumber(entry.class) == Frame.SEARCH_QUEST_CLASS then
    return true
  end
  local Data = ItemTree.Data
  if type(Data) ~= "table" then
    return false
  end
  if type(Data.ItemGlance) == "function" then
    local ok, glance = pcall(Data.ItemGlance, Data, id)
    if ok and type(glance) == "table" and tonumber(glance.class) == Frame.SEARCH_QUEST_CLASS then
      return true
    end
  end
  if type(Data.PeekItem) == "function" then
    local ok, item = pcall(Data.PeekItem, Data, id)
    if ok and type(item) == "table" then
      if tonumber(item.c) == Frame.SEARCH_QUEST_CLASS or tonumber(item.b) == Frame.SEARCH_QUEST_BINDING then
        return true
      end
    end
  end
  return false
end

-- Brief S6: the words a search row's name column draws: the name, and on a quest item the quest
-- glyph straight after it, sized to the row's text, so it reads before the New and Changed marks
-- in the badge column. Assets.Markup is the one place the key becomes a path. Pure over Assets.
function Frame.SearchNameText(row, fontSize)
  if type(row) ~= "table" then
    return ""
  end
  local name = type(row.name) == "string" and row.name or ""
  -- Brief S8: a trainer wears its side's mark after its name (Assets.SIDES), the one the tree's NPC
  -- rows wear, so the other side's trainers are listed and plainly marked. Brief RB2 (owner QA
  -- 2026-10-17 item 191): an item or a quest of one side wears it too, after a quest item's glyph.
  local assets = {}
  if row.questItem then
    assets[#assets + 1] = Frame.SEARCH_QUEST_ASSET
  end
  if type(row.sideKey) == "string" then
    assets[#assets + 1] = row.sideKey
  end
  if #assets == 0 or name == "" or type(Assets) ~= "table" or type(Assets.Markup) ~= "function" then
    return name
  end
  local points = tonumber(fontSize)
    or (Theme and Theme.fontSizes and tonumber(Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_MD))
    or 12
  local text = name
  for _, asset in ipairs(assets) do
    local ok, markup = pcall(Assets.Markup, asset, points)
    if ok and type(markup) == "string" and markup ~= "" then
      text = text .. " " .. markup
    end
  end
  return text
end

-- Brief SR4: the words of a kind's "+N more" row ("+23 more creatures", "+1 more item"), one
-- wording for one and one for more, each its own locale literal the way the tooltip's change count
-- is. nil for a kind with no words or a count under one. Pure.
function Frame.SearchMoreText(kind, count)
  count = math.floor(tonumber(count) or 0)
  if count < 1 then
    return nil
  end
  local words = {
    item = { L["+1 more item"], L["+%d more items"] },
    creature = { L["+1 more creature"], L["+%d more creatures"] },
    quest = { L["+1 more quest"], L["+%d more quests"] },
    vendor = { L["+1 more vendor"], L["+%d more vendors"] },
    zone = { L["+1 more zone"], L["+%d more zones"] },
    node = { L["+1 more node"], L["+%d more nodes"] },
    set = { L["+1 more set"], L["+%d more sets"] },
    -- Brief S8: a trainer search's rows.
    trainer = { L["+1 more trainer"], L["+%d more trainers"] },
  }
  local pair = words[kind]
  if not pair then
    return nil
  end
  if count == 1 then
    return pair[1]
  end
  return string.format(pair[2], count)
end

-- Brief SR4: a "+N more" entry (Frame.SearchAll) as a dropdown row: the words, in the hint colour
-- with the tree's "Show N more" glyph, no key (it opens no page), and the kind it opens more of in
-- more and group. nil where it has no words.
local function moreSearchRow(entry)
  local text = Frame.SearchMoreText(entry.more, entry.count)
  if not text then
    return nil
  end
  return {
    more = entry.more,
    moreCount = math.floor(tonumber(entry.count) or 0),
    group = entry.more,
    name = text,
    colourKey = "ITEMTREE_COLOR_TEXT_HINT",
    asset = Frame.SEARCH_MORE_ASSET,
    idText = "",
    badges = {},
    kinded = true,
  }
end

-- Brief S8: the glyph a trainer search's rows wear, the Sources view's own Trainer glyph.
Frame.SEARCH_TRAINER_ASSET = "CAT_TRAINER"

-- Brief S8: the words a trainer's side says in its row's tooltip, by the Classic Era table's
-- numbers (1 Alliance, 2 Horde, 3 both).
Frame.SEARCH_SIDE_WORDS = { [1] = L["Alliance"], [2] = L["Horde"], [3] = L["Neutral (both sides)"] }

-- Brief S8: one trainer (Core/TrainerSearch.lua TrainerSearch.Results) as a dropdown row: its
-- creature page's key (none for a Classic Era name with no page, which is listed and opens
-- nothing), its name with its side's mark after it, the zone it stands in where an item shows its
-- id ("Trainer" where nothing places it), and the Trainer glyph. Its tooltip says its title, zone
-- and side. Pure.
function Frame.TrainerSearchRow(entry)
  if type(entry) ~= "table" or type(entry.name) ~= "string" or entry.name == "" then
    return nil
  end
  local zone = type(entry.zone) == "string" and entry.zone ~= "" and entry.zone or nil
  local lines = {}
  if type(entry.title) == "string" and entry.title ~= "" then
    lines[#lines + 1] = "<" .. entry.title .. ">"
  end
  if zone then
    lines[#lines + 1] = zone
  end
  local sideWords = Frame.SEARCH_SIDE_WORDS[entry.side]
  if sideWords then
    lines[#lines + 1] = sideWords
  end
  local sides = type(Assets) == "table" and type(Assets.SIDES) == "table" and Assets.SIDES or EMPTY
  -- Brief BQ24: the trainer "Show nearest" found says so where its zone stands, and its tooltip
  -- carries the answer's line.
  local idText = zone or L["Trainer"]
  if type(entry.nearest) == "string" then
    idText = string.format(L["Nearest: %s"], idText)
    lines[#lines + 1] = entry.nearest
  end
  return {
    key = entry.key,
    kind = "trainer",
    trainer = entry.what,
    name = entry.name,
    sideKey = sides[entry.side],
    colourKey = "ITEMTREE_COLOR_TEXT_BODY",
    asset = Frame.SEARCH_TRAINER_ASSET,
    idText = idText,
    nearest = type(entry.nearest) == "string" or nil,
    tooltipLines = lines,
    badges = {},
    kinded = true,
    creature = true,
    group = "trainer",
  }
end

-- Brief S8: one kind "t:" alone (or a word several kinds start with) lists: its name, and what to
-- type for it where an item shows its id. Pressing it, or Enter on it, puts that in the box and
-- searches it (row.fill). Pure.
function Frame.TrainerKindRow(entry)
  if type(entry) ~= "table" or type(entry.name) ~= "string" or type(entry.fill) ~= "string" then
    return nil
  end
  return {
    fill = entry.fill,
    name = entry.name,
    colourKey = "ITEMTREE_COLOR_TEXT_BODY",
    asset = Frame.SEARCH_TRAINER_ASSET,
    idText = entry.fill,
    badges = {},
    kinded = true,
    group = "trainerkind",
  }
end

-- Brief S8: a line that is no result ("No trainer kind matches ...") as a row: the words in the hint
-- colour, nothing to press. Pure.
function Frame.SearchHintRow(entry)
  if type(entry) ~= "table" or type(entry.name) ~= "string" or entry.name == "" then
    return nil
  end
  return {
    hint = true,
    name = entry.name,
    colourKey = "ITEMTREE_COLOR_TEXT_HINT",
    idText = "",
    badges = {},
    kinded = true,
    group = "hint",
  }
end

-- Brief S8, the owner's addendum: whether a row of the dropdown can be highlighted, pressed and
-- reached with the arrows: everything but a group's header row and a hint line. Pure.
function Frame.SearchSelectable(row)
  return type(row) == "table" and not row.header and not row.hint
end

-- Brief RB2 (owner QA 2026-10-17 item 191, search "Crest of Lordaeron": "There's no indicator of side
-- in the search box and the items, although we know which side each belongs to we don't hide the
-- one not related to the user"). With "Hide other faction data" on, an item that belongs to the
-- other side alone (Core/Graph.lua Graph.ItemSide: every quest use and every source of it is that
-- side's, Crest of Lordaeron 275521 and its Horde quest 95204) leaves the item results, as the other
-- side's quests leave the quest results (Core/Data.lua). With it off (or no side known) nothing is
-- hidden, and an item or a quest of one side wears that side's mark after its name, the mark a
-- trainer's row wears (Assets.SIDES); a quest's row also says it in its tooltip ("Horde only"), and
-- a quest open to both that our data leans one way says "Possibly Horde only" there (item 194).

-- The side each item result belongs to (1, 2, or false for none), kept while the list is open
-- (Frame.CloseSearch lets go): every keystroke asks again for most of the same items.
Frame.searchSides = {}

--- The one side an item belongs to, 1 or 2, or nil (Core/Graph.lua Graph.ItemSide), kept in
--- Frame.searchSides. Guarded.
function Frame.SearchItemSide(itemId)
  local id = tonumber(itemId)
  if not id then
    return nil
  end
  local held = Frame.searchSides[id]
  if held ~= nil then
    return held or nil
  end
  local graph = ItemTree.Graph
  local side = nil
  if type(graph) == "table" and type(graph.ItemSide) == "function" then
    local ok, answer = pcall(graph.ItemSide, id)
    if ok and (answer == 1 or answer == 2) then
      side = answer
    end
  end
  Frame.searchSides[id] = side or false
  return side
end

--- The side "Hide other faction data" hides from, as a side number (1 Alliance, 2 Horde): the
--- character's own while the setting is on and the side is known (Core/Graph.lua Graph.HiddenSide),
--- else nil. Guarded.
function Frame.SearchHiddenSide()
  local graph = ItemTree.Graph
  if type(graph) ~= "table" or type(graph.HiddenSide) ~= "function" or type(graph.SIDE_NUMBERS) ~= "table" then
    return nil
  end
  local ok, side = pcall(graph.HiddenSide)
  return ok and graph.SIDE_NUMBERS[side] or nil
end

--- The item results less those of the other side than mine (a side number; nil hides nothing),
--- and total less the ones left out. The list handed in is not written into. The results past the
--- ones asked for are not looked at, so the "+N more" count may still hold one of them. Pure over
--- Frame.SearchItemSide.
function Frame.WithoutOtherSideItems(items, total, mine)
  if (mine ~= 1 and mine ~= 2) or type(items) ~= "table" or #items == 0 then
    return items, total
  end
  local kept, dropped = {}, 0
  for _, entry in ipairs(items) do
    local side = type(entry) == "table" and Frame.SearchItemSide(entry.id) or nil
    if side ~= nil and side ~= mine then
      dropped = dropped + 1
    else
      kept[#kept + 1] = entry
    end
  end
  if dropped == 0 then
    return items, total
  end
  return kept, math.max((tonumber(total) or 0) - dropped, #kept)
end

-- The words a quest row's tooltip says for its side, by side number.
Frame.SEARCH_ONLY_WORDS = { [1] = L["Alliance only"], [2] = L["Horde only"] }

--- A quest result's row given its side (Core/Graph.lua Graph.QuestSide): marks (true while nothing
--- is hidden) puts the side's mark after its name and "Horde only" in its tooltip, and a quest open
--- to both that leans to the other side (Graph.LeanWords) says "Possibly Horde only" there whatever
--- the setting says. The row, changed in place. Guarded.
function Frame.SideQuestRow(row, key, marks)
  local graph = ItemTree.Graph
  if type(row) ~= "table" or type(key) ~= "string" or type(graph) ~= "table" then
    return row
  end
  local words = nil
  if marks and type(graph.QuestSide) == "function" then
    local ok, side = pcall(graph.QuestSide, nil, key)
    if ok and (side == 1 or side == 2) then
      local sides = type(Assets) == "table" and type(Assets.SIDES) == "table" and Assets.SIDES or EMPTY
      row.sideKey = sides[side]
      words = Frame.SEARCH_ONLY_WORDS[side]
    end
  end
  if not words and type(graph.LeanWords) == "function" and type(graph.PlayerSide) == "function" then
    local ok, lean = pcall(graph.LeanWords, key, graph.PlayerSide())
    if ok and type(lean) == "string" then
      words = lean
    end
  end
  if words then
    local lines = {}
    local first = row.tooltipText
    if type(first) ~= "string" or first == "" then
      first = row.idText
    end
    if type(first) == "string" and first ~= "" then
      lines[1] = first
    end
    lines[#lines + 1] = words
    row.tooltipLines = lines
  end
  return row
end

-- One row model per search result, for the dropdown under the title bar search. An item result
-- is the item id, the node key it opens, its name in its quality colour, the id as the text
-- drawn on the right, and the New and Changed marks the beta build put on that item, so a player
-- reading the hits can see at a glance which of them the beta added or changed. A creature
-- result (Core/Data.lua Data:SearchCreatures, since the owner's ruling of 2026-09-25) keeps its
-- own npc key and is drawn by creatureSearchRow above. A result with no usable id or key is
-- dropped rather than drawn blank, but for a Classic Era creature or vendor that has no page
-- (brief EK1: noPage, the table states no creature id for its name), which is listed with no key
-- and opens nothing when picked (Frame.OpenSearchResult). opts is a Frame.OptionsFromSettings
-- table; left out, the current settings are read, which is what the window itself passes nothing
-- for.
--
-- Brief SR4: a "+N more" entry becomes moreSearchRow's row, and every row says which kind's rows it
-- is among in group ("item", "creature", or the kind), so the window can find where a kind's rows
-- end once more of them are shown.
function Frame.SearchModel(results, opts)
  local rows = {}
  if type(results) ~= "table" then
    return rows
  end
  if opts == nil then
    opts = Frame.OptionsFromSettings(ItemTree.db and ItemTree.db.settings)
  end
  -- Brief RB2: the side marks, only while "Hide other faction data" hides nothing.
  local marks = Frame.SearchHiddenSide() == nil
  local sideKeys = type(Assets) == "table" and type(Assets.SIDES) == "table" and Assets.SIDES or EMPTY
  for _, entry in ipairs(results) do
    local id = type(entry) == "table" and tonumber(entry.id) or nil
    local creatureKey, otherKind = nil, false
    local special = nil
    if type(entry) == "table" then
      -- Brief S8: a trainer search's rows.
      if entry.kind == "trainer" then
        special = Frame.TrainerSearchRow
      elseif entry.kind == "trainerkind" then
        special = Frame.TrainerKindRow
      elseif entry.kind == "hint" then
        special = Frame.SearchHintRow
      end
    end
    if special then
      local row = special(entry)
      if row then
        rows[#rows + 1] = row
      end
    elseif type(entry) == "table" and entry.kind == "more" then
      -- Brief SR4: a kind's "+N more" row.
      local row = moreSearchRow(entry)
      if row then
        rows[#rows + 1] = row
      end
    elseif not id and type(entry) == "table" and type(entry.name) == "string" and entry.name ~= "" then
      local kind = parseKey(entry.key)
      local noPage = entry.key == nil and entry.noPage == true
      -- Brief SR1: a result of the other kinds says which kind it is, and its key is a real key.
      if (kind or noPage) and Frame.SearchKindWords(entry) ~= nil then
        otherKind = true
      elseif kind == "npc" then
        creatureKey = entry.key
      elseif noPage then
        creatureKey = false
      end
    end
    if otherKind then
      local row = kindSearchRow(entry)
      row.group = entry.kind
      -- Brief RB2: a quest of one side says so (Frame.SideQuestRow).
      if entry.kind == "quest" then
        Frame.SideQuestRow(row, entry.key, marks)
      end
      rows[#rows + 1] = row
    elseif id then
      local name = entry.name
      if type(name) ~= "string" or name == "" then
        name = string.format(L["Item %d"], id)
      end
      local quality = tonumber(entry.quality)
      rows[#rows + 1] = {
        id = id,
        key = itemNodeKey(id),
        name = name,
        quality = quality,
        colourKey = qualityColourKey(quality),
        icon = entry.icon,
        -- Brief BQ7: a Classic item and its soulbound Forever copy are one row, both ids in it
        -- (Data.FoldCopyEntries).
        idText = tonumber(entry.pairId) and (tostring(id) .. " / " .. tostring(entry.pairId)) or tostring(id),
        badges = itemBadges(id, opts),
        -- Brief S6: a quest item wears the quest glyph after its name (Frame.SearchNameText).
        questItem = Frame.SearchQuestItem(entry) or nil,
        -- Brief RB2: and an item of one side its side's mark, while nothing is hidden.
        sideKey = marks and sideKeys[Frame.SearchItemSide(id)] or nil,
        group = "item",
      }
    elseif creatureKey ~= nil then
      local row = creatureSearchRow(entry)
      row.group = "creature"
      rows[#rows + 1] = row
    end
  end
  -- Brief QN1: quests numbered where in a chain, and told apart by zone where two read the same.
  local ViewModel = ItemTree.ViewModel
  if type(ViewModel) == "table" and type(ViewModel.TitleQuestRows) == "function" then
    pcall(ViewModel.TitleQuestRows, rows)
  end
  return rows
end

-- Whether "Search everything" is on (brief SR1), from the settings table. Off by default, so only
-- a true turns it on. Pure.
function Frame.SearchEverythingOn(settings)
  return type(settings) == "table" and settings.searchEverything == true
end

-- One search answer, guarded: the table a searcher answered, or an empty one where it is missing,
-- fails or answers anything but a table. Brief SR4: and how many it matched in all, the searcher's
-- second answer (Core/Data.lua), never fewer than the rows it gave; a searcher that says nothing
-- is taken to have matched only those, so it is offered no "more" row.
local function askSearch(fn, ...)
  if type(fn) ~= "function" then
    return EMPTY, 0
  end
  local ok, value, total = pcall(fn, ...)
  if ok and type(value) == "table" then
    total = tonumber(total)
    if not total or total < #value then
      total = #value
    end
    return value, total
  end
  return EMPTY, 0
end

-- Up to count entries of list appended to out.
local function appendSome(out, list, count)
  for index = 1, math.min(count, #list) do
    out[#out + 1] = list[index]
  end
end

-- Brief SR4: the "+N more" entry that ends a kind's results, where count of them are not shown.
local function appendMore(out, kind, count)
  count = math.floor(tonumber(count) or 0)
  if count > 0 then
    out[#out + 1] = { kind = "more", more = kind, count = count }
  end
end

-- Brief SR4: how many rows past its first screen a kind has been opened to (more[kind]), never
-- below 0.
local function extraRows(more, kind)
  local extra = math.floor(tonumber(more[kind]) or 0)
  if extra < 0 then
    return 0
  end
  return extra
end

-- Brief N1: the vendors in found that the first count creature results do not already hold (the
-- same page, or a Forever NPC of the same name), which are shown once, as the creature row.
local function vendorsNotShown(found, creatures, count)
  local shown = {}
  for index = 1, math.min(count, #creatures) do
    local entry = creatures[index]
    -- Brief EK1: a Classic Era name with no page has no key.
    if entry.key ~= nil then
      shown[entry.key] = true
    end
    shown[string.lower(entry.name or "")] = true
  end
  local kept = {}
  for _, entry in ipairs(found) do
    if not shown[entry.key] and not shown[string.lower(entry.name or "")] then
      kept[#kept + 1] = entry
    end
  end
  return kept
end

-- Everything the search box finds for one piece of text: items first, then creatures, within
-- limit in all, so items take precedence when the limit bites. Each is asked through Data and
-- guarded, so a build (or a harness) with no creature search still searches items. limit
-- defaults to Frame.SEARCH_LIMIT. Answers the raw results, which Frame.SearchModel turns into
-- rows.
--
-- Brief SR1: with "Search everything" on, the other kinds of page follow the creatures, in
-- Core/Data.lua's fixed order (Data.SEARCH_KINDS: quests, vendors, zones, nodes, sets). everything
-- is for the specs; left out, the setting is read. Off, this is the items and creatures search it
-- always was.
--
-- Brief SR2: on, limit defaults to Frame.SEARCH_LIMIT_EVERYTHING and every kind has its share
-- (Frame.SEARCH_QUOTAS), so a word that names plenty of items still shows its quests and zones.
-- Each kind in order is asked for its share plus whatever the kinds before it left unfilled; the
-- items are asked once for the whole limit, and those past their share fill whatever is still
-- empty at the end. The answer keeps each kind's results together, in the order the kinds are
-- drawn.
--
-- Brief SR4: each kind's results end with { kind = "more", more = <kind>, count = N } where the
-- searcher matched N more than are shown ("item", "creature", or a Data.SEARCH_KINDS kind), out of
-- the count each searcher makes in its one walk. Every kind is asked, for its count, even where it
-- has no row left to fill (a limit of 0), and so are the creatures with the setting off. more maps
-- a kind to how many rows past its first screen it has been opened to (Frame.SEARCH_MORE_STEP at a
-- press): that kind is asked for that many more and shows them after its own, while the first
-- screen's shares, refill and order are worked out exactly as without them, so the rows above
-- never move. The items are asked with the limit as their base (Data:SearchItems), for the same
-- reason.
--
-- Brief S8: text Core/Data.lua Data.ParseSearch reads as a trainer query ("t:lw", "trainer:hunter")
-- is Frame.SearchTrainers' alone; place (the player's place, for the specs) is handed on to it.
function Frame.SearchAll(text, limit, everything, more, place)
  local out = {}
  local Data = ItemTree.Data
  if type(text) ~= "string" or text == "" or type(Data) ~= "table" then
    return out
  end
  if everything == nil then
    everything = Frame.SearchEverythingOn(ItemTree.db and ItemTree.db.settings)
  end
  more = type(more) == "table" and more or EMPTY
  -- Brief S8: "t:" and "trainer:" ask for trainers, and nothing else.
  if type(Data.ParseSearch) == "function" then
    local ok, query = pcall(Data.ParseSearch, text)
    if ok and type(query) == "table" and query.kind == "trainer" then
      return Frame.SearchTrainers(query.word, limit, everything, more, place)
    end
  end
  local kinds = everything and type(Data.SearchKind) == "function" and type(Data.SEARCH_KINDS) == "table"
  if kinds then
    limit = math.floor(tonumber(limit) or Frame.SEARCH_LIMIT_EVERYTHING)
  else
    limit = math.floor(tonumber(limit) or Frame.SEARCH_LIMIT)
  end
  if limit <= 0 then
    return out
  end
  local extraItems = extraRows(more, "item")
  local items, itemTotal = askSearch(Data.SearchItems, Data, text, limit + extraItems, limit)
  -- Brief RB2: an item of the other side alone leaves the results while the setting hides that side.
  items, itemTotal = Frame.WithoutOtherSideItems(items, itemTotal, Frame.SearchHiddenSide())
  if not kinds then
    local itemCount = math.min(#items, limit)
    local itemShown = math.min(#items, itemCount + extraItems)
    appendSome(out, items, itemShown)
    appendMore(out, "item", itemTotal - itemShown)
    local left = limit - itemCount
    local extra = extraRows(more, "creature")
    local creatures, creatureTotal = askSearch(Data.SearchCreatures, Data, text, left + extra)
    local creatureShown = math.min(#creatures, left + extra)
    appendSome(out, creatures, creatureShown)
    appendMore(out, "creature", creatureTotal - creatureShown)
    return out
  end
  local quotas = Frame.SEARCH_QUOTAS
  local itemCount = math.min(#items, quotas.item, limit)
  local used = itemCount
  local carry = quotas.item - itemCount
  local groups = {}
  local order = { "creature" }
  for _, kind in ipairs(Data.SEARCH_KINDS) do
    order[#order + 1] = kind
  end
  for _, kind in ipairs(order) do
    local want = math.max(math.min((tonumber(quotas[kind]) or 0) + carry, limit - used), 0)
    local extra = extraRows(more, kind)
    local found, total
    if kind == "creature" then
      found, total = askSearch(Data.SearchCreatures, Data, text, want + extra)
    else
      found, total = askSearch(Data.SearchKind, Data, kind, text, want + extra)
    end
    -- The rows of the first screen, which the shares are worked out from.
    local got = math.min(#found, want)
    if kind == "vendor" and groups.creature and #found > 0 then
      -- Against the first screen's creature rows for the shares, and against every creature row
      -- shown for the rows drawn, so opening more creatures never moves a row above them. The
      -- vendors left out are taken off the count too (those the search never handed over cannot
      -- be, so the count may run one or two over where a vendor is also a creature).
      local creature = groups.creature
      got = math.min(#vendorsNotShown(found, creature[1], creature[3]), want)
      local kept = vendorsNotShown(found, creature[1], creature[2])
      total = total - (#found - #kept)
      found = kept
    end
    local shown = math.min(#found, want + extra)
    groups[kind] = { found, shown, got, total - shown }
    used = used + got
    carry = math.max((tonumber(quotas[kind]) or 0) + carry - got, 0)
  end
  -- The items refill whatever is left.
  itemCount = math.min(#items, itemCount + (limit - used))
  local itemShown = math.min(#items, itemCount + extraItems)
  appendSome(out, items, itemShown)
  appendMore(out, "item", itemTotal - itemShown)
  for _, kind in ipairs(order) do
    local group = groups[kind]
    appendSome(out, group[1], group[2])
    appendMore(out, kind, group[4])
  end
  return out
end

-- Brief BQ24 (owner QA 2026-10-10 item 25): "Show nearest" on the trainer search's divider. A press
-- finds the nearest trainer of the kind (Core/TrainerSearch.lua FindNearest), sets the waypoint,
-- says the answer in chat, and the search is drawn again with that trainer first and marked
-- ("Nearest: Wetlands"), the answer's line in its tooltip. The answer is kept for the text it was
-- pressed on (Frame.searchNearest); typing anything else lets it go.
-- How many trainers a held answer asks the search for, so the one found can be lifted to the top
-- wherever the order put it.
Frame.SEARCH_NEAREST_ALL = 10000

-- The held answer for a kind of trainer, or nil: only while the box holds the text it was pressed
-- on and only for that kind.
function Frame.SearchNearestFor(kind)
  local held = Frame.searchNearest
  if type(held) ~= "table" or held.what ~= kind or type(held.key) ~= "string" then
    return nil
  end
  if held.query ~= Frame.searchShownText then
    return nil
  end
  return held
end

-- The trainers (TrainerSearch.Results' entries) with the one held.key names first, marked with
-- held.text (entry.nearest), the rest in their order. A fresh list of fresh entries where it is
-- found; the list as handed where it is not. Pure.
function Frame.NearestFirst(found, held)
  if type(found) ~= "table" or type(held) ~= "table" or type(held.key) ~= "string" then
    return found
  end
  local at = nil
  for index, entry in ipairs(found) do
    if type(entry) == "table" and entry.key == held.key then
      at = index
      break
    end
  end
  if not at then
    return found
  end
  local first = {}
  for field, value in pairs(found[at]) do
    first[field] = value
  end
  first.nearest = type(held.text) == "string" and held.text or L["Show nearest"]
  local out = { first }
  for index, entry in ipairs(found) do
    if index ~= at then
      out[#out + 1] = entry
    end
  end
  return out
end

-- The kind of trainer a trainer search's rows are for (their row.trainer), or nil. Pure.
function Frame.SearchTrainerKind(rows)
  for _, row in ipairs(type(rows) == "table" and rows or EMPTY) do
    if type(row) == "table" and row.group == "trainer" and type(row.trainer) == "string" then
      return row.trainer
    end
  end
  return nil
end

-- The player's side for the press, "Alliance" or "Horde", or nil. Guarded.
function Frame.PlayerSide()
  local read = rawget(_G, "UnitFactionGroup")
  if type(read) ~= "function" then
    return nil
  end
  local ok, side = pcall(read, "player")
  if ok and (side == "Alliance" or side == "Horde") then
    return side
  end
  return nil
end

-- The press itself. Answers what TrainerSearch.FindNearest said, or nil. Guarded.
function Frame.SearchFindNearest(kind)
  local TrainerSearch = ItemTree.TrainerSearch
  if type(kind) ~= "string" or type(TrainerSearch) ~= "table" or type(TrainerSearch.FindNearest) ~= "function" then
    return nil
  end
  local ok, found = pcall(TrainerSearch.FindNearest, kind, Frame.PlayerSide())
  if not ok or type(found) ~= "table" then
    return nil
  end
  if type(found.key) == "string" then
    Frame.searchNearest = { what = kind, key = found.key, text = found.text, query = Frame.searchShownText }
  end
  local chat = rawget(_G, "DEFAULT_CHAT_FRAME")
  if type(found.text) == "string" and type(chat) == "table" and type(chat.AddMessage) == "function" then
    pcall(chat.AddMessage, chat, L["ItemTree"] .. ": " .. found.text)
  end
  local panel = ItemTree.UI and ItemTree.UI.InfoPanel
  if type(found.waypoint) == "table" and type(panel) == "table" and type(panel.SetWaypoint) == "function" then
    -- Brief UX1: with what it is for, which the waypoint's toast says (Core/Nearest.lua).
    local Nearest = ItemTree.Nearest
    local label = nil
    if type(Nearest) == "table" and type(Nearest.WaypointFor) == "function" then
      local named, words = pcall(Nearest.WaypointFor, found)
      label = named and words or nil
    end
    pcall(panel.SetWaypoint, found.waypoint, label)
  end
  return found
end

-- Brief F155: TrainerSearch.Search guarded, as askSearch asks any searcher: the rows, how many
-- there are in all (never fewer than the rows), and the muted line naming how many trainers of the
-- other side "Hide other faction data" left out, or nil for none.
function Frame.AskTrainerSearch(TrainerSearch, word, asked, place)
  if type(TrainerSearch) ~= "table" or type(TrainerSearch.Search) ~= "function" then
    return EMPTY, 0, nil
  end
  local ok, found, total, _, hidden, side = pcall(TrainerSearch.Search, word, asked, place)
  if not ok or type(found) ~= "table" then
    return EMPTY, 0, nil
  end
  total = tonumber(total)
  if not total or total < #found then
    total = #found
  end
  local graph = ItemTree.Graph
  local line = nil
  if type(graph) == "table" and type(graph.HiddenText) == "function" then
    line = graph.HiddenText(hidden, side, "trainer")
  end
  return found, total, line
end

-- Brief S8: the trainer search's answer for the word after "t:" or "trainer:" (Core/Data.lua
-- Data.ParseSearch), as Frame.SearchAll answers: a word that names one kind (Core/TrainerSearch.lua
-- TrainerSearch.Resolve) lists its trainers, nearest first (TrainerSearch.Search), up to the limit
-- the setting gives the dropdown (as SearchAll's), with a "+N more trainers" entry where there are
-- more (more.trainer opened as SR4's rows are); "t:" alone, or a word several kinds start with,
-- lists those kinds ({ kind = "trainerkind", what, name, fill }); a word no kind is called, or a kind
-- nothing is known for, answers one { kind = "hint", name } line. place is for the specs: the
-- player's place (TrainerSearch.PlayerPlace's shape); left out, the client is asked.
-- Brief F155: where "Hide other faction data" left the other side's trainers out, one muted hint
-- line under the rows says so ("4 Horde trainers hidden", Core/Graph.lua Graph.HiddenText), and it
-- stands in for "No hunter trainers known yet." where every one was hidden.
function Frame.SearchTrainers(word, limit, everything, more, place)
  local out = {}
  local TrainerSearch = ItemTree.TrainerSearch
  if type(TrainerSearch) ~= "table" or type(TrainerSearch.Resolve) ~= "function" then
    return out
  end
  more = type(more) == "table" and more or EMPTY
  local resolved = TrainerSearch.Resolve(word)
  if resolved.kind then
    if everything then
      limit = math.floor(tonumber(limit) or Frame.SEARCH_LIMIT_EVERYTHING)
    else
      limit = math.floor(tonumber(limit) or Frame.SEARCH_LIMIT)
    end
    if limit <= 0 then
      return out
    end
    local extra = extraRows(more, "trainer")
    -- Brief BQ24 (QA item 25): after a press on the divider's "Show nearest" the trainer it found
    -- leads the list, marked, wherever the order had put it (Frame.NearestFirst).
    local held = Frame.SearchNearestFor(resolved.kind)
    local asked = limit + extra
    if held then
      asked = Frame.SEARCH_NEAREST_ALL
    end
    local found, total, hiddenLine = Frame.AskTrainerSearch(TrainerSearch, word, asked, place)
    if held then
      found = Frame.NearestFirst(found, held)
    end
    if #found == 0 then
      local label = TrainerSearch.Heading(resolved.kind) or ""
      out[1] = { kind = "hint", name = hiddenLine or string.format(L["No %s known yet."], label:lower()) }
      return out
    end
    local shown = math.min(#found, limit + extra)
    appendSome(out, found, shown)
    appendMore(out, "trainer", total - shown)
    if hiddenLine then
      out[#out + 1] = { kind = "hint", name = hiddenLine }
    end
    return out
  end
  if resolved.unknown then
    out[1] = {
      kind = "hint",
      name = string.format(L["No trainer kind matches %s. Type t: to see them all."], resolved.unknown),
    }
    return out
  end
  for _, id in ipairs(resolved.list or EMPTY) do
    local kind = TrainerSearch.BY_ID and TrainerSearch.BY_ID[id]
    local fill = TrainerSearch.Fill(id)
    if type(kind) == "table" and fill then
      out[#out + 1] = { kind = "trainerkind", what = id, name = kind.label, fill = fill }
    end
  end
  return out
end

-- Brief S8, the owner's addendum (2026-10-09, after SR4: "we should add a divider between items and
-- other things, similar to our normal area (minus the chevron and era badges on the divider)"): the
-- words of the header row above each kind's rows in the dropdown. A node group says the one kind
-- its rows show ("Herb nodes", "Chests") and "Nodes" where they are mixed; a trainer search's says
-- which trainers ("Hunter trainers", Core/TrainerSearch.lua TrainerSearch.Heading).
Frame.SEARCH_GROUP_WORDS = {
  item = L["Items"],
  creature = L["Creatures"],
  quest = L["Quests"],
  vendor = L["Vendors"],
  zone = L["Zones"],
  set = L["Sets"],
  node = L["Nodes"],
  trainer = L["Trainers"],
  trainerkind = L["Trainers for"],
}
Frame.SEARCH_NODE_WORDS = {
  herb = L["Herb nodes"],
  vein = L["Mining nodes"],
  fished = L["Fishing pools"],
  object = L["Chests"],
}
-- The groups whose header is drawn even when they are the dropdown's only group: what a trainer
-- search found says what "t:" read the word as.
Frame.SEARCH_GROUP_ALWAYS = { trainer = true, trainerkind = true }

-- The header words for one group, given its rows. Pure.
function Frame.SearchGroupWords(group, rows)
  if group == "node" then
    local only = nil
    for _, row in ipairs(type(rows) == "table" and rows or EMPTY) do
      if row.group == "node" and not row.more then
        local nodeKind = row.node or "object"
        if only == nil then
          only = nodeKind
        elseif only ~= nodeKind then
          only = false
        end
      end
    end
    if only then
      return Frame.SEARCH_NODE_WORDS[only] or Frame.SEARCH_GROUP_WORDS.node
    end
    return Frame.SEARCH_GROUP_WORDS.node
  end
  if group == "trainer" then
    local TrainerSearch = ItemTree.TrainerSearch
    for _, row in ipairs(type(rows) == "table" and rows or EMPTY) do
      if row.group == "trainer" and row.trainer and type(TrainerSearch) == "table" then
        local words = TrainerSearch.Heading(row.trainer)
        if words then
          return words
        end
      end
    end
  end
  return Frame.SEARCH_GROUP_WORDS[group]
end

-- Brief S8, the owner's addendum: the dropdown's rows with a header row before each kind's group, a
-- copy of rows (Frame.SearchModel's) with
--
--   { header = true, group, name, colourKey, idText = "", badges = {}, kinded = true }
--
-- put in front of each run of one group: no chevron, no marks, no count, never highlighted, never
-- pressed and skipped by the arrows (Frame.SearchSelectable). Only where the rows hold two groups or
-- more: one group alone needs no divider, but for a trainer search (SEARCH_GROUP_ALWAYS), whose
-- header says what the word was read as. A hint line has no group header, and a group with no rows
-- has none either, there being no run of it. A kind's "+N more" row is its group's, so it stays the
-- last row under its header. The limits count results, not headers. Pure.
function Frame.SearchHeaders(rows)
  local out = {}
  if type(rows) ~= "table" then
    return out
  end
  local groups, always = 0, false
  local counted = {}
  for _, row in ipairs(rows) do
    local group = type(row) == "table" and row.group or nil
    if group ~= nil and group ~= "hint" and not counted[group] then
      counted[group] = true
      groups = groups + 1
      always = always or Frame.SEARCH_GROUP_ALWAYS[group] == true
    end
  end
  local headed = groups >= 2 or always
  local previous = nil
  for _, row in ipairs(rows) do
    local group = type(row) == "table" and row.group or nil
    if headed and group ~= nil and group ~= "hint" and group ~= previous then
      local words = Frame.SearchGroupWords(group, rows)
      if words then
        out[#out + 1] = {
          header = true,
          group = group,
          name = words,
          colourKey = Frame.SEARCH_HEADER_WORD,
          idText = "",
          badges = {},
          kinded = true,
          -- Brief BQ24: a trainer search's divider carries "Show nearest" for its kind.
          nearestKind = group == "trainer" and Frame.SearchTrainerKind(rows) or nil,
        }
      end
    end
    previous = group
    out[#out + 1] = row
  end
  return out
end

-- Brief S8, the owner's addendum: Down and Up through rows (Frame.SearchStep's wrapping), stepping
-- over every row that cannot be highlighted (a header, a hint line). 0 where none can be. Pure.
function Frame.SearchStepRows(index, rows, delta)
  rows = type(rows) == "table" and rows or EMPTY
  local count = #rows
  local at = Frame.SearchStep(index, count, delta)
  if delta == 0 or delta == nil then
    if Frame.SearchSelectable(rows[at]) then
      return at
    end
    return 0
  end
  for _ = 1, count do
    if Frame.SearchSelectable(rows[at]) then
      return at
    end
    at = Frame.SearchStep(at, count, delta)
  end
  return 0
end

-- Brief S8: the first row that can be pressed, or 0. Pure.
function Frame.SearchFirstSelectable(rows)
  for index, row in ipairs(type(rows) == "table" and rows or EMPTY) do
    if Frame.SearchSelectable(row) then
      return index
    end
  end
  return 0
end

-- The dropdown's right hand columns in pixels, measured in from the row's right edge: idRight is
-- where the id column's right edge sits, badgeRight and nameRight where the badge column and the
-- name stop. The badge column is wide enough for Frame.SEARCH_BADGE_MAX marks plus the pixel a
-- medallion stands proud of its cluster box on each side, because UI/Badges.lua draws a supplied
-- medallion one step up the badge size ladder. textHeight is the name's font size; the marks are
-- sized from it so they sit on the words' own centre line. Pure, and guarded: a build whose
-- Badges cannot be asked falls back to the list badge size rather than collapsing the column.
function Frame.SearchColumns(textHeight)
  local sizes = (Theme and Theme.sizes) or EMPTY
  local fonts = (Theme and Theme.fontSizes) or EMPTY
  local height = tonumber(textHeight) or tonumber(fonts.ITEMTREE_FONTSIZE_BODY_MD) or 12
  local badgeSize = tonumber(sizes.ITEMTREE_BADGE_SIZE_LIST) or 12
  local gap = 3
  local overhang = 0
  if Badges then
    local ok, value = pcall(Badges.SizeForText, height)
    if ok and tonumber(value) then
      badgeSize = tonumber(value)
    end
    ok, value = pcall(Badges.GapFor, badgeSize)
    if ok and tonumber(value) then
      gap = tonumber(value)
    end
    ok, value = pcall(Badges.ArtSize, badgeSize)
    if ok and tonumber(value) then
      overhang = math.max(0, math.ceil((tonumber(value) - badgeSize) / 2))
    end
  end
  local run = Frame.SEARCH_BADGE_MAX * badgeSize + (Frame.SEARCH_BADGE_MAX - 1) * gap
  local badge = run + overhang * 2
  local idRight = Frame.SEARCH_PAD
  local badgeRight = idRight + Frame.SEARCH_ID_W + Frame.SEARCH_COL_GAP
  return {
    badgeSize = badgeSize,
    badgeGap = gap,
    badge = badge,
    id = Frame.SEARCH_ID_W,
    idRight = idRight,
    badgeRight = badgeRight,
    nameRight = badgeRight + badge + Frame.SEARCH_COL_GAP,
    kind = Frame.SEARCH_KIND_W,
    kindNameRight = idRight + Frame.SEARCH_KIND_W + Frame.SEARCH_COL_GAP,
    width = Frame.SEARCH_W + Frame.SEARCH_LIST_EXTRA + badge,
  }
end

-- Brief S7: where a search row's name stops, in pixels in from the row's right edge, and how wide
-- its right hand text is drawn, given cols (Frame.SearchColumns), the row model and measured, what
-- the right hand text measures (nil where the client cannot say). The name takes all the width the
-- right hand text does not need, with the usual gap, for every kind of row:
--
--   * a creature, quest or other page (row.kinded): the words as wide as they measure, never wider
--     than cols.kind (longer words are cut by the client), and the name up to them; no words, the
--     name runs to the pad
--   * an item: its id keeps its fixed column so ids stay right aligned; with marks the name stops at
--     the badge column, without any it runs over the empty badge column up to the id's own digits
--
-- Answers nameRight, rightW. Pure.
function Frame.SearchNameRight(cols, row, measured)
  row = type(row) == "table" and row or EMPTY
  local gap = Frame.SEARCH_COL_GAP
  measured = tonumber(measured)
  if row.kinded then
    local words = type(row.idText) == "string" and row.idText or ""
    if words == "" then
      return cols.idRight, 0
    end
    local rightW = cols.kind
    if measured then
      rightW = math.max(0, math.min(math.ceil(measured) + 1, cols.kind))
    end
    return cols.idRight + rightW + gap, rightW
  end
  if type(row.badges) == "table" and #row.badges > 0 then
    return cols.nameRight, cols.id
  end
  local digits = cols.id
  if measured then
    digits = math.max(0, math.min(math.ceil(measured) + 1, cols.id))
  end
  return cols.idRight + digits + gap, cols.id
end

-- Down and Up through the dropdown, wrapping at both ends. index is the highlighted row, 0 or
-- nil for none; count is how many rows the dropdown holds; delta is 1 for Down and -1 for Up.
-- Returns the new index, and 0 when there is nothing to highlight. Enter with none highlighted
-- opens the first result, which is why 0 is a real answer rather than an error.
function Frame.SearchStep(index, count, delta)
  count = math.floor(tonumber(count) or 0)
  if count <= 0 then
    return 0
  end
  index = math.floor(tonumber(index) or 0)
  if index < 1 or index > count then
    index = 0
  end
  delta = math.floor(tonumber(delta) or 0)
  if delta == 0 then
    return index
  end
  if index == 0 then
    if delta > 0 then
      return 1
    end
    return count
  end
  return ((index - 1 + delta) % count) + 1
end

-- Brief N4: how many rows the dropdown draws at once, given room, the height from the search box's
-- bottom edge down to the window's bottom edge, and rowH, one row's height: as many as fit under
-- the box inside the window (the list hangs 2 below the box and carries a 1 pixel edge top and
-- bottom), never more than Frame.SEARCH_VISIBLE_ROWS and never fewer than Frame.SEARCH_MIN_ROWS.
-- Nothing measured answers Frame.SEARCH_VISIBLE_ROWS. Pure.
function Frame.SearchRowsFor(room, rowH)
  local most = Frame.SEARCH_VISIBLE_ROWS
  room, rowH = tonumber(room), tonumber(rowH)
  if not room or not rowH or rowH <= 0 then
    return most
  end
  local fit = math.floor((room - 4) / rowH)
  if fit > most then
    return most
  end
  if fit < Frame.SEARCH_MIN_ROWS then
    return Frame.SEARCH_MIN_ROWS
  end
  return fit
end

-- Brief SR3: the furthest the dropdown can scroll, as the number of rows above the first drawn,
-- for count results with visible rows on screen. 0 when they all fit. Pure.
function Frame.SearchMaxOffset(count, visible)
  count = math.floor(tonumber(count) or 0)
  visible = math.floor(tonumber(visible) or Frame.SEARCH_VISIBLE_ROWS)
  if visible < 1 then
    visible = 1
  end
  if count <= visible then
    return 0
  end
  return count - visible
end

-- Brief SR3: the scroll offset that keeps the highlighted row on screen. index is the highlighted
-- result (0 for none, which leaves the offset where it is), offset the rows scrolled past now.
-- A row above the window scrolls up to it, a row below scrolls down just far enough to draw it as
-- the last one, and the answer is always within 0 to Frame.SearchMaxOffset. Pure.
function Frame.SearchOffsetFor(index, offset, count, visible)
  visible = math.floor(tonumber(visible) or Frame.SEARCH_VISIBLE_ROWS)
  if visible < 1 then
    visible = 1
  end
  local most = Frame.SearchMaxOffset(count, visible)
  offset = math.floor(tonumber(offset) or 0)
  index = math.floor(tonumber(index) or 0)
  if index >= 1 then
    if index <= offset then
      offset = index - 1
    elseif index > offset + visible then
      offset = index - visible
    end
  end
  if offset > most then
    offset = most
  end
  if offset < 0 then
    offset = 0
  end
  return offset
end

-- Whether a recipe and the item it makes are drawn as one row, from the settings table. The
-- footer's tick box, the sync that follows it and the view model options all ask through here,
-- so the one trap in the setting is written down once: the default is on, so a nil is on, and
-- `not settings.mergeCrafts` would turn a box that is already ticked on again. Pure.
local function mergeCraftsOn(settings)
  return not (type(settings) == "table" and settings.mergeCrafts == false)
end

--- EXPERIMENTAL (brief E25). Which of the five ways a craft row in the Used by view shows what
--- the craft is made of, from the settings table. Core owns the five words and what anything
--- else means, so the window asks it rather than checking the string itself; a build of Core
--- that predates the option leaves it out altogether, which reads as off. Pure.
local function craftIngredientsMode(settings)
  local ViewModel = ItemTree.ViewModel
  if type(ViewModel) ~= "table" or type(ViewModel.CraftIngredients) ~= "function" then
    return nil
  end
  local ok, mode = pcall(ViewModel.CraftIngredients, settings.craftIngredients)
  if ok and type(mode) == "string" then
    return mode
  end
  return nil
end

-- The ViewModel options for the current settings. Anything missing falls back to
-- ViewModel.DEFAULTS, so a half applied saved variable still opens the window. showChanges is
-- not a setting: it is the caption row's tick box, which lives for the session only.
function Frame.OptionsFromSettings(settings)
  settings = type(settings) == "table" and settings or EMPTY
  local defaults = (ItemTree.ViewModel and ItemTree.ViewModel.DEFAULTS) or EMPTY
  local function flag(key)
    local value = settings[key]
    if value == nil then
      value = defaults[key]
    end
    if value == nil then
      value = true
    end
    return value and true or false
  end
  local density = settings.density
  if density == nil then
    density = defaults.density
  end
  -- mergeCrafts is the footer's second tick box: a recipe and the item it makes drawn as one row
  -- rather than as the spell and then the item. It is not read through flag(), because its
  -- default is on whatever ViewModel states, so a build whose ViewModel predates the setting
  -- merges rather than falling through to whatever that table happens to hold.
  return {
    showPredicted = flag("showPredicted"),
    -- Brief GS3: the guessed sources in the Sources view, so the window's options and the saved
    -- setting the reader itself reads (Core/GuessSources.lua) always agree. On by default.
    showGuessSources = flag("showGuessSources"),
    showChanges = Frame.showChanges and true or false,
    badgesNew = flag("badgesNew"),
    badgesChanged = flag("badgesChanged"),
    mergeCrafts = mergeCraftsOn(settings),
    -- EXPERIMENTAL (brief E25): which of the five ways a craft row shows its ingredients.
    craftIngredients = craftIngredientsMode(settings),
    density = density == "compact" and "compact" or "default",
    -- Brief TC1: the footer's Total counts box. Off unless the setting says true; false rather
    -- than nil, so turning it off reaches a view model that had it on (SetOptions skips a nil).
    totalCounts = settings.totalCounts == true,
  }
end

local clamp = ItemTree.Util.Clamp

-- What 1x means on this screen. The owner plays on a high resolution display with a small UI
-- scale, where the window is about half the size they want, while on a common 1080p setup the
-- same window is already right, so 1x is not a fixed number: it is whatever makes the default
-- rect fill Frame.SCALE_SCREEN_FRACTION of UIParent, never under 1x and never past 2x.
-- screenW and screenH are UIParent's size in UI units, which is what GetScreenWidth and
-- GetScreenHeight report. Pure, and it never reads the window's current size, so resizing the
-- window by hand cannot change the scale.
function Frame.AutoScale(screenW, screenH)
  screenW, screenH = tonumber(screenW), tonumber(screenH)
  if not (screenW and screenH and screenW > 0 and screenH > 0) then
    return Frame.AUTO_SCALE_MIN
  end
  local rect = Frame.DefaultRect()
  local defaultW = tonumber(rect.width) or 0
  local defaultH = tonumber(rect.height) or 0
  if defaultW <= 0 or defaultH <= 0 then
    return Frame.AUTO_SCALE_MIN
  end
  local fraction = Frame.SCALE_SCREEN_FRACTION
  local fit = math.min(fraction * screenW / defaultW, fraction * screenH / defaultH)
  return clamp(fit, Frame.AUTO_SCALE_MIN, Frame.AUTO_SCALE_MAX)
end

-- The scale the window is drawn at: the player's setting, clamped to 0.5 to 1.5, on top of what
-- 1x means on this screen, on top of Frame.SCALE_BASE. A missing or nonsense setting reads as
-- 1.0. The base is the rebase the owner asked for: every setting draws the window at 0.85 of
-- what it used to, and Core migrates the saved setting so nothing changes size for a player who
-- already had one they liked.
function Frame.ScaleFor(setting, screenW, screenH)
  local value = tonumber(setting)
  if not value then
    value = 1.0
  end
  local low = tonumber(ItemTree.SCALE_MIN) or Frame.SCALE_MIN
  local high = tonumber(ItemTree.SCALE_MAX) or Frame.SCALE_MAX
  return clamp(value, low, high) * Frame.AutoScale(screenW, screenH) * Frame.ScaleBase()
end

-- Clamps a remembered window rect to something that fits on this screen. saved is
-- ItemTree.charDb.window, defaults is ItemTree.CHAR_DEFAULTS.window, min is { width, height },
-- and screenW and screenH are what GetScreenWidth and GetScreenHeight report; leaving them out
-- skips the clamp. scale is what the window is drawn at, because a scaled frame measures itself
-- in its own units: a window at 2x on a 1400 unit wide screen can only be 700 units wide.
-- Returns { width, height, point, x, y }, all in the window's own units.
--
-- The anchor point is remembered too, so the offsets are clamped to the screen extent less the
-- window's own size in both directions, whichever corner the window is anchored by. That is
-- enough to keep the title bar reachable after a resolution change; SetClampedToScreen does the
-- rest while the window is being dragged.
function Frame.WindowRect(saved, defaults, min, screenW, screenH, scale)
  saved = type(saved) == "table" and saved or EMPTY
  defaults = type(defaults) == "table" and defaults or EMPTY
  min = type(min) == "table" and min or EMPTY
  local minW = tonumber(min.width) or 0
  local minH = tonumber(min.height) or 0
  local width = math.max(tonumber(saved.width) or tonumber(defaults.width) or minW, minW)
  local height = math.max(tonumber(saved.height) or tonumber(defaults.height) or minH, minH)
  local point = type(saved.point) == "string" and saved.point or defaults.point
  if type(point) ~= "string" then
    point = "CENTER"
  end
  local x = tonumber(saved.x) or tonumber(defaults.x) or 0
  local y = tonumber(saved.y) or tonumber(defaults.y) or 0
  screenW, screenH = tonumber(screenW), tonumber(screenH)
  scale = tonumber(scale)
  if not scale or scale <= 0 then
    scale = 1
  end
  if screenW then
    screenW = screenW / scale
  end
  if screenH then
    screenH = screenH / scale
  end
  if screenW and screenW > 0 then
    -- A window wider than the screen cannot be dragged back, so the screen wins over the minimum.
    width = math.min(width, screenW)
    local limit = math.max(0, screenW - width)
    x = math.max(-limit, math.min(x, limit))
  end
  if screenH and screenH > 0 then
    height = math.min(height, screenH)
    local limit = math.max(0, screenH - height)
    y = math.max(-limit, math.min(y, limit))
  end
  return { width = width, height = height, point = point, x = x, y = y }
end

-- The default rect and the minimum size, from Theme.sizes with CHAR_DEFAULTS.window as the
-- remembered anchor. Pure: both tables are plain data.
function Frame.DefaultRect()
  local sizes = (Theme and Theme.sizes) or EMPTY
  local saved = (ItemTree.CHAR_DEFAULTS and ItemTree.CHAR_DEFAULTS.window) or EMPTY
  return {
    width = sizes.ITEMTREE_FRAME_DEFAULT_W or saved.width or 1000,
    height = sizes.ITEMTREE_FRAME_DEFAULT_H or saved.height or 560,
    point = saved.point or "CENTER",
    x = saved.x or 0,
    y = saved.y or 0,
  }
end

function Frame.MinSize()
  local sizes = (Theme and Theme.sizes) or EMPTY
  return { width = sizes.ITEMTREE_FRAME_MIN_W or 840, height = sizes.ITEMTREE_FRAME_MIN_H or 420 }
end

-- The view keys, in the order the tabs are drawn. Core owns them; the list here is what a build
-- whose Edges did not load falls back to. Whatever Core states is taken as it stands, however
-- many keys it holds, so a Core that has not landed the fourth view yet draws three tabs and
-- the window never offers a view Core cannot answer.
local VIEW_KEYS = { "uses", "sources", "requires", "disenchants" }

-- The views the root the window is on is drawn in, which is what the tab strip is built from.
--
-- Core owns the answer twice over: Core/Edges.lua states which set of views each node KIND has,
-- and Core/ViewModel.lua ViewsFor is the seam that lets the shipped data have the last word,
-- because an npc key is a creature or a vendor and only the Classic Era table can tell them apart
-- (brief E57). The window asks the seam, falls back to Edges.VIEWS, and falls back again to the
-- four keys above for a build whose Core did not load: whatever it is handed is taken as it
-- stands, however many keys it holds, so the window never offers a view Core cannot answer.
--
-- Brief CT1b (QA item 227): one window action (an open, a tab press, a level filter, a refresh) asks
-- for the root's views 15 to 40 times over (the tab strip, the view, the page notes, the tree's
-- empty line), and on an NPC page each answer reads a dozen tables: the owner's hitch run on three
-- trainer pages counted 384 asks in a minute. While one of the window's entry points runs
-- (Frame.GUARDED, each wrapped in Frame.HoldingViews at the foot of this file) the first answer for a
-- root is kept and the rest read it. It goes when the outermost entry point returns, and a data
-- build or a collector record that moves in the middle of one is asked afresh. Held on Frame.viewHold
-- rather than in locals of this file, which is near Lua 5.1's limit (tests/spec/ui_frame_locals_spec.lua).
Frame.viewHold = { depth = 0, memo = nil }

-- The data build and the collector's records now, the two marks a held answer was asked against.
function Frame.viewHold.Generations()
  local data, collector = ItemTree.Data, ItemTree.Collector
  return type(data) == "table" and data.generation or nil, type(collector) == "table" and collector.generation or nil
end

-- The views held for a root in this action, or nil (none held, or the data or records moved since).
function Frame.viewHold.Held(rootKey)
  local hold = Frame.viewHold
  local held = hold.memo and hold.memo[rootKey] or nil
  if not held then
    return nil
  end
  local data, collector = hold.Generations()
  if held.data ~= data or held.collector ~= collector then
    return nil
  end
  return held.views
end

--- Brief CT1b: runs fn(...) with the root's views held (viewKeys above), and lets them go when the
--- outermost such call returns, whether or not fn raised. Answers fn's answers; an error goes on up.
function Frame.HoldingViews(fn, ...)
  local hold = Frame.viewHold
  hold.depth = hold.depth + 1
  if hold.depth == 1 then
    hold.memo = {}
  end
  local results = { pcall(fn, ...) }
  hold.depth = hold.depth - 1
  if hold.depth == 0 then
    hold.memo = nil
  end
  if not results[1] then
    error(results[2], 0)
  end
  return unpack(results, 2, table.maxn(results))
end

local function viewKeys(rootKey)
  if rootKey == nil then
    rootKey = Frame.rootKey
  end
  local ViewModel = ItemTree.ViewModel
  if type(rootKey) == "string" and type(ViewModel) == "table" and type(ViewModel.ViewsFor) == "function" then
    local hold = Frame.viewHold
    local held = hold.Held(rootKey)
    if held then
      return held
    end
    local ok, views = pcall(ViewModel.ViewsFor, rootKey)
    if ok and type(views) == "table" and #views > 0 then
      if hold.memo then
        local data, collector = hold.Generations()
        hold.memo[rootKey] = { views = views, data = data, collector = collector }
      end
      return views
    end
  end
  local Edges = ItemTree.Edges
  local views = Edges and Edges.VIEWS
  if type(views) == "table" and #views > 0 then
    return views
  end
  return VIEW_KEYS
end

-- How many view tabs this build draws: one per key Core states, and never more words than
-- Frame.VIEW_TABS has. The strip is built for the longest list and the surplus buttons are
-- hidden, which is how a creature root draws two tabs out of the four buttons.
function Frame.ViewCount()
  return math.min(#viewKeys(), #Frame.VIEW_TABS)
end

-- The view one of the tabs stands for, by index. Anything off the end is the root's default.
function Frame.ViewAt(index)
  return viewKeys()[tonumber(index) or 0] or Frame.DefaultView()
end

-- Where a view sits in the strip, or nil for a key this root has no tab for.
function Frame.ViewIndex(view)
  for index, key in ipairs(viewKeys()) do
    if key == view then
      return index
    end
  end
  return nil
end

-- The key the sticky view is remembered under: one slot per SET of views rather than one for the
-- window.
--
-- The owner's rule is that the view is the player's and it sticks as they walk from item to item.
-- A creature root has a different pair of tabs entirely, so pressing Loot on a creature must not
-- move the item tab they left, and coming back to an item has to land on it. Keyed by the set's
-- own keys joined, so a set added later gets a slot of its own with no list to maintain.
local function viewSet(rootKey)
  return table.concat(viewKeys(rootKey), ",")
end

-- The view a root opens on when the player has not been on one of its tabs yet: the addon's
-- promise where the root has that tab, and otherwise the first tab it does have, which is Loot on
-- a creature.
function Frame.DefaultView(rootKey)
  local keys = viewKeys(rootKey)
  for _, key in ipairs(keys) do
    if key == Frame.DEFAULT_VIEW then
      return Frame.DEFAULT_VIEW
    end
  end
  return keys[1] or Frame.DEFAULT_VIEW
end

-- Brief NP1: the tabs a creature or NPC page opens on, best first: what a trainer teaches (brief
-- TR2: its Teaches tab, the Trains tab folded into it), what a vendor sells, the quests an NPC gives
-- or ends. The owner's words (2026-10-04): "the tab that opens should be the most relevant for that
-- npc". A page none of them has anything on lands on Frame.NPC_FALLBACK_VIEW, Loot, with its 0, as
-- it always did.
Frame.NPC_VIEW_ORDER = { "teaches", "sells", "quests" }
Frame.NPC_FALLBACK_VIEW = "loot"

-- The tab a creature or NPC page opens on, out of the views its strip draws and the count Core
-- states for each (ViewModel.ViewCounts): the first of Frame.NPC_VIEW_ORDER the strip has with
-- rows in it, else Loot where the strip has it, else nil (the root's own default). A view the
-- counts say nothing about counts as holding rows, because the strip offers it only where the data
-- has some. Pure.
function Frame.BestNpcView(views, counts)
  local has = {}
  for _, view in ipairs(type(views) == "table" and views or EMPTY) do
    has[view] = true
  end
  counts = type(counts) == "table" and counts or EMPTY
  for _, view in ipairs(Frame.NPC_VIEW_ORDER) do
    local count = tonumber(counts[view])
    if has[view] and (count == nil or count > 0) then
      return view
    end
  end
  if has[Frame.NPC_FALLBACK_VIEW] then
    return Frame.NPC_FALLBACK_VIEW
  end
  return nil
end

-- Brief GW3 (the owner's ruling 2B, 2026-10-13: "an openable item with NO uses opens on Contains"):
-- the tab an item page opens on where the strip has a Contains tab (Edges.CONTAINS_VIEW), out of the
-- strip's views, the counts Core states (ViewModel.ViewCounts), the view the tab memory holds for
-- this set of tabs (held, nil for none) and whether that view was put there by this rule rather
-- than by the player (auto). Only where the held view is the player's promise (Frame.DEFAULT_VIEW,
-- Used by), none, or this rule's own: Contains where Used by counts 0 rows (and Contains does not
-- count 0), else Used by again where the rule had moved it (an openable item with uses opens on
-- Used by). nil leaves the sticky tab alone: a tab the player pressed always wins, and a page with
-- no Contains tab is never touched. A count not known is no answer (nil). Pure.
function Frame.ItemOpenView(views, counts, held, auto)
  local Edges = ItemTree.Edges
  local contains = type(Edges) == "table" and Edges.CONTAINS_VIEW or "contains"
  local hasContains, hasUses = false, false
  for _, view in ipairs(type(views) == "table" and views or EMPTY) do
    if view == contains then
      hasContains = true
    elseif view == Frame.DEFAULT_VIEW then
      hasUses = true
    end
  end
  if not (hasContains and hasUses) then
    return nil
  end
  if not (held == nil or held == Frame.DEFAULT_VIEW or auto == true) then
    return nil
  end
  counts = type(counts) == "table" and counts or EMPTY
  local uses, inside = tonumber(counts[Frame.DEFAULT_VIEW]), tonumber(counts[contains])
  if uses == 0 and inside ~= 0 then
    return contains
  end
  if auto == true and uses ~= nil then
    return Frame.DEFAULT_VIEW
  end
  return nil
end

-- Brief C2: the list view a stage clicked in the chain opens on, for a root. A click on a stage is
-- the player asking for that item's rows, so it cannot be the chain again: it is the last list
-- view the player was on anywhere (Frame.rowView, written by Frame.SetView and Frame.Open), where
-- this root has that tab, and the root's own default otherwise. Never the chain view.
function Frame.RowView(rootKey)
  if rootKey == nil then
    rootKey = Frame.rootKey
  end
  local held = Frame.rowView
  local keys = viewKeys(rootKey)
  if held ~= nil and held ~= Frame.CHAIN_VIEW then
    for _, key in ipairs(keys) do
      if key == held then
        return held
      end
    end
  end
  local default = Frame.DefaultView(rootKey)
  if default ~= Frame.CHAIN_VIEW then
    return default
  end
  for _, key in ipairs(keys) do
    if key ~= Frame.CHAIN_VIEW then
      return key
    end
  end
  return default
end

-- Whether a root has the chain view at all, which is an item or a recipe (brief C2).
function Frame.HasChainView(rootKey)
  for _, key in ipairs(viewKeys(rootKey)) do
    if key == Frame.CHAIN_VIEW then
      return true
    end
  end
  return false
end

-- The view the window is on. Session state, so it is read back through here rather than off the
-- field, and a remembered view this root has no tab for reads as the root's own default.
function Frame.View()
  local held = Frame.views[viewSet()]
  if held == nil then
    held = Frame.view
  end
  for _, key in ipairs(viewKeys()) do
    if key == held then
      return held
    end
  end
  return Frame.DefaultView()
end

-- The direction the current view walks, for a caller that still thinks in directions. Kept as
-- the compatibility half of the contract: down is the uses view, up is both of the others.
function Frame.Direction()
  local Edges = ItemTree.Edges
  local down = (Edges and Edges.DOWN) or "down"
  if Edges and type(Edges.ViewDirection) == "function" then
    local ok, direction = pcall(Edges.ViewDirection, Frame.View())
    if ok and type(direction) == "string" then
      return direction
    end
  end
  if Frame.View() == Frame.DEFAULT_VIEW then
    return down
  end
  return (Edges and Edges.UP) or "up"
end

-- The locale key for one view's word: the view's own where Frame.VIEW_LABELS names it, and the
-- word at that place in the item strip otherwise, which is what a build with a view key this
-- window has never heard of draws. short asks for the narrow row's word (Frame.VIEW_SHORT_LABELS),
-- which only a view that has one answers differently. Pure.
function Frame.ViewWord(view, index, short)
  if short and type(view) == "string" and Frame.VIEW_SHORT_LABELS[view] then
    return Frame.VIEW_SHORT_LABELS[view]
  end
  local word = type(view) == "string" and Frame.VIEW_LABELS[view] or nil
  return word or Frame.VIEW_TABS[tonumber(index) or 0] or ""
end

-- The word a view tab carries, with the count Core states for it: "Used by (3)". A count that
-- is not a number leaves the label as it is, which is what the tabs draw on a build of Core
-- with no ViewCounts to ask. Pure, so the specs read it with no client at all.
function Frame.ViewLabel(label, count)
  label = tostring(label or "")
  count = tonumber(count)
  if not count then
    return label
  end
  return string.format(L["%s (%d)"], label, math.floor(count))
end

-- How wide each view tab is drawn, given what its word measures. Pure.
--
-- The tabs have to fit over the category column and the start of the tree at the minimum
-- window (840 at the default scale), and the words are what the window is navigated by, so the
-- padding around them is what gives way: full padding first, then Frame.VIEW_TAB_PAD_MIN, and
-- only a band too narrow for even that shares what is left out equally and lets the client's
-- own ellipsis end the words.
--
--   band     the strip's own width
--   widths   what each word measures, in tab order
--   gap      the air between two tabs
--   padding  the air either side of a word, and minPadding the least it may be squeezed to
--
-- Answers the width of each tab, the padding it was drawn with, and whether the words fit.
function Frame.ViewTabWidths(band, widths, gap, padding, minPadding)
  band = math.max(tonumber(band) or 0, 0)
  widths = type(widths) == "table" and widths or EMPTY
  gap = math.max(tonumber(gap) or 0, 0)
  padding = math.max(tonumber(padding) or 0, 0)
  minPadding = math.max(math.min(tonumber(minPadding) or 0, padding), 0)
  local count = #widths
  if count == 0 then
    return {}, padding, true
  end
  local air = gap * (count - 1)
  local words = 0
  for _, width in ipairs(widths) do
    words = words + math.max(tonumber(width) or 0, 0)
  end
  for _, pad in ipairs({ padding, minPadding }) do
    if words + 2 * pad * count + air <= band then
      local out = {}
      for index, width in ipairs(widths) do
        out[index] = math.max(tonumber(width) or 0, 0) + 2 * pad
      end
      return out, pad, true
    end
  end
  local share = math.max(0, (band - air) / count)
  local out = {}
  for index = 1, count do
    out[index] = math.floor(share)
  end
  return out, minPadding, false
end

-- The whole view tab row: the tabs on the left and the tree's filter box on the right, sharing
-- one band. Pure, and the one place the owner's order of giving way is written down.
--
-- The filter box is what takes the slack, because a tab's word is navigation and the box is a
-- field the player types into: the box gets everything the tabs leave, and shrinks with the
-- window down to filterMin. Only once the box is at that floor do the tabs start losing padding,
-- full first and then minPadding, and only a band too narrow for even that shares what is left
-- between the tabs and lets the client's own ellipsis end the words.
--
--   band       the row's own width, from the sidebar's left edge to the tree's right edge
--   widths     what each tab's word measures, in tab order
--   gap        the air between two tabs
--   padding    the air either side of a word, and minPadding the least it may be squeezed to
--   filterMin  the least the filter box may be given
--   rowGap     the air between the last tab and the filter box
--
-- Answers the width of each tab, the padding they were drawn with, whether the words fit, and
-- the filter box's width.
function Frame.ViewRowFit(band, widths, gap, padding, minPadding, filterMin, rowGap)
  band = math.max(tonumber(band) or 0, 0)
  widths = type(widths) == "table" and widths or EMPTY
  gap = math.max(tonumber(gap) or 0, 0)
  padding = math.max(tonumber(padding) or 0, 0)
  minPadding = math.max(math.min(tonumber(minPadding) or 0, padding), 0)
  filterMin = math.max(tonumber(filterMin) or 0, 0)
  rowGap = math.max(tonumber(rowGap) or 0, 0)
  local count = #widths
  if count == 0 then
    return {}, padding, true, band
  end
  local air = gap * (count - 1)
  local words = 0
  for _, width in ipairs(widths) do
    words = words + math.max(tonumber(width) or 0, 0)
  end
  for _, pad in ipairs({ padding, minPadding }) do
    local tabs = words + 2 * pad * count + air
    local filter = band - tabs - rowGap
    if filter >= filterMin then
      local out = {}
      for index, width in ipairs(widths) do
        out[index] = math.max(tonumber(width) or 0, 0) + 2 * pad
      end
      return out, pad, true, filter
    end
  end
  -- The box is at its floor and the tabs take what is left of the row, ellipsis and all.
  local out, pad, fits = Frame.ViewTabWidths(math.max(0, band - rowGap - filterMin), widths, gap, padding, minPadding)
  local used = air
  for _, width in ipairs(out) do
    used = used + width
  end
  return out, pad, fits, math.max(0, band - rowGap - used)
end

-- The key in ItemTree.db.settings a tab waits on: the one its module registered
-- (Frame.TAB_SETTINGS), else the one this file declares for it (Frame.DECLARED_TAB_SETTINGS),
-- else nil for a tab that waits on none. Pure.
function Frame.TabSettingKey(name)
  local key = Frame.TAB_SETTINGS[name]
  if key == nil then
    key = Frame.DECLARED_TAB_SETTINGS[name]
  end
  return key
end

-- What a setting reads as while the player has not touched it: the default Core names in
-- DB_DEFAULTS.settings where it names the key, else the default the setting's own module stated
-- when it registered it with the panel (Options.RegisterSetting, which files it in Options.EXTRA),
-- else nil. Read at call time: UI/Options.lua loads after the files that register settings, so
-- they register again at ADDON_LOADED, which is before the window is built and before any tab is
-- gated. Pure.
function Frame.SettingDefault(key)
  if key == nil then
    return nil
  end
  local defaults = ItemTree.DB_DEFAULTS and ItemTree.DB_DEFAULTS.settings
  if type(defaults) == "table" and defaults[key] ~= nil then
    return defaults[key]
  end
  local Options = ItemTree.Options
  local extra = type(Options) == "table" and Options.EXTRA or nil
  if type(extra) == "table" then
    for _, entry in ipairs(extra) do
      if type(entry) == "table" and entry.key == key then
        return entry.default
      end
    end
  end
  return nil
end

-- Whether the setting a tab waits on (Frame.TabSettingKey) is on. A tab that waits on none is
-- always on. One that does reads the saved value, and a value nobody has set (nil) reads as the
-- setting's registered default (Frame.SettingDefault), so a tab that is on by default is drawn
-- without its default having to be written into the saved settings, and one with no default at
-- all stays away. Only an explicit true draws it. Pure.
function Frame.TabSettingOn(name, settings)
  local key = Frame.TabSettingKey(name)
  if key == nil then
    return true
  end
  local value = nil
  if type(settings) == "table" then
    value = settings[key]
  end
  if value == nil then
    value = Frame.SettingDefault(key)
  end
  return value == true
end

-- The tabs this build actually draws, in Frame.TABS order, with an optional tab whose module is
-- absent left out. present is a table keyed by tab name, saying which modules are loaded; a tab
-- that is not optional is always drawn. settings is ItemTree.db.settings: a tab that waits on a
-- setting (Frame.TabSettingKey) is left out unless it is on, and ungated drops that rule, which is
-- what the window builds its buttons from so a setting turned on later has a button to show.
-- Pure, so the rule reads in one place.
function Frame.TabNames(present, settings, ungated)
  present = type(present) == "table" and present or EMPTY
  local out = {}
  for _, name in ipairs(Frame.TABS) do
    if not Frame.OPTIONAL_TABS[name] or present[name] then
      if ungated or Frame.TabSettingOn(name, settings) then
        out[#out + 1] = name
      end
    end
  end
  return out
end

-- The word on a top tab, which is the tab's own name and nothing else: the count a pane says is
-- waiting rides on the bubble over the tab's corner (Frame.BubbleText), not in brackets after the
-- word, so the tab keeps one width however many discoveries arrive. Pure.
function Frame.TabLabel(label)
  return tostring(label or "")
end

-- The notification bubble over a top tab's corner.
--
-- Its size follows the tab's own word: the gem is BUBBLE_SCALE times the label's font height
-- across (a 10 point label, which is what GameFontNormalSmall is, gives a 22 wide gem), and the
-- count on it is set at the label's own height, so the number reads as the same size as the word
-- beside it and sits inside the gem. Frame.BubbleSize is the rule.
--
-- The art does not fill its square, so the square is drawn larger than the gem by the share each
-- piece of art fills, measured off the Forever client's own files (build 1.60.1.70009):
--   atlas    communities-icon-notification, 38 by 38 in atlas file 1981967,
--            a diamond gem solid over 20 of the 38 with a soft glow round it
--   texture  Interface\COMMON\Indicator-Red (518450), 32 by 32, the dot solid over 22 of them
--   fill     the flat square, which is all gem
-- Frame.BubbleFrameSize turns a gem size into the square the art is drawn in.
Frame.BUBBLE_SCALE = 2.2
Frame.BUBBLE_ART_FILL = { atlas = 20 / 38, texture = 22 / 32, fill = 1 }
-- The label height used where the tab's word will not say its own: GameFontNormalSmall's.
Frame.BUBBLE_LABEL_HEIGHT = 10

-- Where the gem's centre sits: ON the top right corner of the tab art the player sees, so half
-- the gem is above the tab and half over it. On the Forever client's PanelTopTabButtonTemplate
-- that corner is not the button's. PanelTopTabButtonMixin:OnLoad (Blizzard_SharedXML/Mainline on
-- the wow-ui-source mirror's `forever` branch) hangs the deselected Right slice off the button's
-- BOTTOMRIGHT at x +7, 27 tall inside the 32 tall button, and the slice's own top 8 rows and
-- right 8 columns are drop shadow (uiframe-tab-right, 37 by 36, gold edge at column 28 and, once
-- flipped, row 8 from the top; the Camelot uiframe-tab-right-c60 is the same shape). So the
-- drawn corner is 8 in and 8 down from the Right slice's TOPRIGHT, which is 1 in from the
-- button's right edge and 13 down from its top. The gem is anchored to that slice with these two
-- numbers. A tab with no such slice (the home made fallback, or the classic TabButtonTemplate) is
-- its own art, so its corner is the button's.
Frame.BUBBLE_X = -8
Frame.BUBBLE_Y = -8
-- The most the bubble spells out; anything above it reads "99+".
Frame.BUBBLE_MAX = 99

-- What the bubble says for a count: nothing at all for no count, zero or anything that is not a
-- number (the bubble is then hidden), the whole number up to BUBBLE_MAX, and "99+" above it.
-- Pure.
function Frame.BubbleText(count)
  count = tonumber(count)
  if not count or count < 1 then
    return ""
  end
  count = math.floor(count)
  if count > Frame.BUBBLE_MAX then
    return tostring(Frame.BUBBLE_MAX) .. "+"
  end
  return tostring(count)
end

-- The gem's size for a tab label of the given font height: BUBBLE_SCALE times it, rounded to a
-- whole number, with BUBBLE_LABEL_HEIGHT standing in for a height that is not a positive number.
-- Answers the gem's diameter and the count's font height. Pure.
function Frame.BubbleSize(labelFontHeight)
  local height = tonumber(labelFontHeight)
  if not height or height <= 0 then
    height = Frame.BUBBLE_LABEL_HEIGHT
  end
  local text = math.floor(height + 0.5)
  return math.floor(height * Frame.BUBBLE_SCALE + 0.5), text
end

-- The square a piece of bubble art is drawn in so its gem comes out gem wide: the gem over the
-- share of the square that art fills (Frame.BUBBLE_ART_FILL), rounded up. An art kind it does not
-- know fills its square. Pure.
function Frame.BubbleFrameSize(gem, art)
  gem = tonumber(gem) or 0
  local fill = Frame.BUBBLE_ART_FILL[art] or 1
  return math.ceil(gem / fill - 1e-9)
end

-- Which header rows one top tab draws: { crumbs = bool, diffRow = bool, viewRow = bool }, all
-- three plain booleans and never nil, from Frame.HEADER_ROWS with Frame.HEADER_ROWS_DEFAULT
-- behind it. A fresh table every call, so a caller that writes into the answer cannot reach the
-- rule itself. Pure.
function Frame.HeaderRowsFor(tabName)
  local rows = Frame.HEADER_ROWS[tabName] or Frame.HEADER_ROWS_DEFAULT
  return {
    crumbs = rows.crumbs == true,
    diffRow = rows.diffRow == true,
    viewRow = rows.viewRow == true,
  }
end

-- Whether that tab draws the item the window is rooted on, from Frame.TAB_SHOWS_ROOT. Only an
-- explicit false is false, so a tab the rule says nothing about reads as drawing the root. Pure.
function Frame.TabShowsRoot(tabName)
  return Frame.TAB_SHOWS_ROOT[tabName] ~= false
end

-- The tabs the window built, which is Frame.TABS less any optional tab this build has no module
-- for. Read back through here rather than off the field, so a caller asking before the window
-- was built still gets the declared order.
local function tabNames()
  local built = Frame.tabNames
  if type(built) == "table" and #built > 0 then
    return built
  end
  return Frame.TABS
end

function Frame.Tab()
  return Frame.tab or tabNames()[1]
end

-- Brief BQ24 (owner QA 2026-10-10 item 27): the window remembers the tab it was closed on (Item
-- tree, Boss loot, Professions, Discoveries), per character, in the per character saved table the
-- window's own rect lives in (ItemTree.charDb.lastTab, the tab's id), with no setting of its own.
-- An open with no item (the key with nothing hovered, the minimap button, /itemtree show) returns
-- to it (Frame.OpenDefault); an open from an item goes to the Item tree tab on it as before
-- (Frame.Open). The tab id the character's saved table holds, or nil.
function Frame.SavedTab()
  local charDb = ItemTree.charDb
  if type(charDb) ~= "table" or type(charDb.lastTab) ~= "string" or charDb.lastTab == "" then
    return nil
  end
  return charDb.lastTab
end

-- Writes the tab the window is on (or name) into the character's saved table. Answers the id
-- written, nil where there is no saved table.
function Frame.RememberTab(name)
  local charDb = ItemTree.charDb
  if type(charDb) ~= "table" then
    return nil
  end
  local tab = name or Frame.tab
  if type(tab) ~= "string" or tab == "" then
    return nil
  end
  charDb.lastTab = tab
  return tab
end

-- The tab an open with no item goes to: saved where the window has that tab now (names, the tabs
-- built; a tab whose setting was turned off since is not one), else nil, which leaves the open as
-- it was. Pure.
function Frame.ReturnTab(saved, names)
  if type(saved) ~= "string" or type(names) ~= "table" then
    return nil
  end
  for _, name in ipairs(names) do
    if name == saved then
      return saved
    end
  end
  return nil
end

-- The locale key a top tab's word is read through: Frame.TAB_WORDS where the word is not the id,
-- the short form where short is asked and the tab has one (Frame.TAB_SHORT_WORDS), and the id
-- itself otherwise. Pure.
function Frame.TabWord(tabName, short)
  if short and Frame.TAB_SHORT_WORDS[tabName] then
    return Frame.TAB_SHORT_WORDS[tabName]
  end
  return Frame.TAB_WORDS[tabName] or tabName
end

-- Brief B1: the tabs that have a key binding of their own, by tab id, as the binding action
-- UI/Keybind.lua reads the bound key for. Their tooltip gains a muted line saying the key, or
-- where to set one.
Frame.TAB_KEYS = { ["Boss loot"] = "ITEMTREE_BOSSLOOT" }

-- The lines a top tab's tooltip carries, as { text, muted } pairs, or an empty list for no
-- tooltip at all. A tab drawn with its glyph alone says its word (brief BL4); a tab with a key of
-- its own (Frame.TAB_KEYS) says its word too, then the key as keyText gives it, or where to set
-- one when keyText is nil. Pure.
--
-- Brief BQ24 (QA item 35): alert is the tab's notification where its gem shows (Frame.TabAlert,
-- { text, lines }): its words follow, then its muted lines, and a tab with an alert always has a
-- tooltip.
function Frame.TabTooltipLines(tabName, label, glyphOnly, keyText, alert)
  local lines = {}
  local keyed = Frame.TAB_KEYS[tabName] ~= nil
  local alerted = type(alert) == "table" and type(alert.text) == "string"
  if not (glyphOnly or keyed or alerted) then
    return lines
  end
  if glyphOnly or keyed then
    lines[1] = { text = tostring(label or ""), muted = false }
  end
  if keyed then
    local hint
    if type(keyText) == "string" and keyText ~= "" then
      hint = string.format(L["Key: %s"], keyText)
    else
      hint = L["Set a key for this tab under Settings"]
    end
    lines[#lines + 1] = { text = hint, muted = true }
  end
  if alerted then
    lines[#lines + 1] = { text = alert.text, muted = false }
    for _, extra in ipairs(type(alert.lines) == "table" and alert.lines or EMPTY) do
      if type(extra) == "string" and extra ~= "" then
        lines[#lines + 1] = { text = extra, muted = true }
      end
    end
  end
  return lines
end

-- Brief BQ24 (owner QA 2026-10-10 item 35): a tab's notification, a gem with no number on its
-- corner in a red tint (Frame.BubbleTone) and words in its tooltip, from Frame.TAB_ALERTS[name],
-- a function answering nil or { text, lines = { muted words } }. The Professions tab's is
-- Frame.ProfessionsAlert. Guarded.
Frame.TAB_ALERTS = {}
function Frame.TabAlert(name)
  local read = Frame.TAB_ALERTS[name]
  if type(read) ~= "function" then
    return nil
  end
  local ok, alert = pcall(read)
  if ok and type(alert) == "table" and type(alert.text) == "string" then
    return alert
  end
  return nil
end

-- Brief BQ24: the Professions tab's notification out of the player's professions
-- (Frame.PlayerSkills): where any is at its cap with a further rank to train
-- (Core/Skills.lua Skills.TrainableLines), "Some of your professions can be levelled up" and one
-- muted line per profession ("Skinning 150/150"); nil where none is. nameOf(line) names a line
-- (the data's skill name where none is handed). Pure over skills.
function Frame.ProfessionsAlert(skills, nameOf)
  local Skills = ItemTree.Skills
  if type(Skills) ~= "table" or type(Skills.TrainableLines) ~= "function" then
    return nil
  end
  skills = type(skills) == "table" and skills or EMPTY
  local lines = Skills.TrainableLines(skills)
  if #lines == 0 then
    return nil
  end
  local out = { text = L["Some of your professions can be levelled up"], lines = {} }
  for _, line in ipairs(lines) do
    local name = type(nameOf) == "function" and nameOf(line) or nil
    if type(name) ~= "string" or name == "" then
      name = L["Profession"]
    end
    local skill = skills[line]
    out.lines[#out.lines + 1] = string.format("%s %d/%d", name, tonumber(skill.rank) or 0, tonumber(skill.max) or 0)
  end
  return out
end

-- Brief BQ24: the Professions tab's alert, read from the player's professions as the tab draws
-- them (Frame.PlayerSkills, the demo's while it is on), each named by the data's skill name.
Frame.TAB_ALERTS.Professions = function()
  local data = ItemTree.Data
  local function nameOf(line)
    if type(data) == "table" and type(data.GetSkillName) == "function" then
      local ok, name = pcall(data.GetSkillName, data, line)
      return ok and name or nil
    end
    return nil
  end
  return Frame.ProfessionsAlert(Frame.PlayerSkills(), nameOf)
end

-- Tab name or index to an index in the tabs this build drew. Anything unknown is the first tab.
local function tabIndex(name)
  local names = tabNames()
  if type(name) == "number" then
    return names[name] and name or 1
  end
  for index, tab in ipairs(names) do
    if tab == name or L[tab] == name or L[Frame.TabWord(tab)] == name then
      return index
    end
  end
  return 1
end

-- A glyph and a word laid out as one group, centred in a box: the top tabs and the recently
-- viewed button both draw that, so both ask here.
--
-- Every number is an offset from the box's own CENTRE to the CENTRE of one object, which is the
-- whole reason this answers centres rather than edges. A FontString's box is as wide as the
-- client feels like making it (PanelTemplates_TabResize hands the tab's Text a width of its own
-- whenever a maxWidth is in play, and the word is centre justified inside whatever box it ends
-- up with), so anchoring a glyph to the box's LEFT puts the glyph wherever the box's edge
-- happens to be rather than beside the first letter. Anchoring both centres, off the box and
-- never off each other, cannot be fooled by a wide label box.
--
--   width        the box the group sits in, only used to answer whether the group fits
--   stringWidth  the word as the client measures it, GetStringWidth, not the FontString's box
--   glyphWidth   the glyph's drawn width, 0 or nil where there is no glyph
--   gap          the air between the glyph and the word
--
-- Answers the glyph's x, the word's x, the group's width and whether the group fits the box.
-- With no glyph the word sits centred and the glyph's x is nil. Pure.
function Frame.GlyphGroup(width, stringWidth, glyphWidth, gap)
  width = math.max(tonumber(width) or 0, 0)
  stringWidth = math.max(tonumber(stringWidth) or 0, 0)
  glyphWidth = math.max(tonumber(glyphWidth) or 0, 0)
  gap = math.max(tonumber(gap) or 0, 0)
  if glyphWidth <= 0 then
    return nil, 0, stringWidth, stringWidth <= width
  end
  local group = glyphWidth + gap + stringWidth
  return -group / 2 + glyphWidth / 2, group / 2 - stringWidth / 2, group, group <= width
end

-- The width a box has to be for Frame.GlyphGroup's group plus the padding on each side. Pure.
function Frame.GlyphGroupWidth(stringWidth, glyphWidth, gap, padding)
  local _, _, group = Frame.GlyphGroup(0, stringWidth, glyphWidth, gap)
  return group + 2 * math.max(tonumber(padding) or 0, 0)
end

-- How wide one top tab is drawn, which this file owns rather than leaving to the client.
--
-- The window's tabs carry a glyph as well as a word, and the client knows nothing about the
-- glyph: PanelTemplates_TabResize sizes a tab from tab.Text alone, and the template's own OnLoad
-- runs it with no padding at all. A tab left at a width worked out from the word is narrower
-- than the group the window centres in it, and the glyph then hangs off the left hand end,
-- outside the tab's art, with the word still inside. So the width is worked out here, from
-- Frame.GlyphGroupWidth, and put back on the tab after every selection change.
--
--   stringWidth  the word as GetStringWidth measures it
--   glyphWidth   the glyph's drawn width, 0 where there is none
--   gap          the air between the glyph and the word
--   padding      what PanelTemplates_TabResize puts around the word, counted once the way that
--                function counts it, so half of it lands on each side of the group
--   sideArt      the Left and Right art, which a tab is always that much wider than its middle
--   minWidth     the least the middle may be, ITEMTREE_CHROME_TAB_W
--
-- Answers the tab's own width and the width of the middle art inside it. Pure.
function Frame.TopTabWidth(stringWidth, glyphWidth, gap, padding, sideArt, minWidth)
  padding = math.max(tonumber(padding) or 0, 0)
  sideArt = math.max(tonumber(sideArt) or 0, 0)
  local middle = Frame.GlyphGroupWidth(stringWidth, glyphWidth, gap, padding / 2)
  middle = math.max(middle, math.max(tonumber(minWidth) or 0, 0))
  return middle + 2 * sideArt, middle
end

-- How wide a top tab is drawn with its glyph alone (brief BL4): the glyph and the same padding
-- and side art as a worded tab, and no floor, because ITEMTREE_CHROME_TAB_W is a floor for a
-- word and would give a glyph back nearly all the room it gave up. 72 for the template's tab
-- (16 + 24 + 2 * 16), 40 for the home made one. Answers the tab's width and its middle. Pure.
function Frame.GlyphTabWidth(glyphWidth, padding, sideArt)
  return Frame.TopTabWidth(0, glyphWidth, 0, padding, sideArt, 0)
end

-- Which top tabs keep their word on a band this wide (brief BL4). The window is never narrower
-- than 840. At the fat per character estimate, beside the 276 the right hand group needs at least:
-- the default strip (brief E96, Discoveries off) is Item tree and Boss loot, 276, which keeps its
-- words from a 652 window, and a developer build adds Guesses for 402, words from 778, so both
-- keep every word at 840 and never fall back. With Discoveries on the three released tabs take
-- 426 (words from 802), and a developer build's fourth tab does not fit at 840 (short words
-- from 908, full from 928), so the strip gives way before the tabs overlap the band's right hand
-- group:
--
--   * every tab with its word, where they all fit beside the rest;
--   * then every tab with its short word (Frame.TAB_SHORT_WORDS, "Item tree" to "Tree"), where
--     that fits;
--   * otherwise every tab that has a glyph draws the glyph alone (its word goes in the hover
--     tooltip), and the tab that is up keeps its word, the short one where it has one, where that
--     still fits.
--
--   band      the strip's width
--   rest      the least the band's right hand group takes: the squares, their gaps, the recently
--             viewed button as a glyph and the search box at its floor (Frame.SEARCH_W_MIN), so
--             the tabs never push the box under its floor
--   labelled  each tab's width with its word, in strip order
--   glyphs    each tab's width with its glyph alone, nil for a tab with no glyph, which always
--             keeps its word
--   spacing   the air between the tabs, all of it
--   active    the index of the tab that is up, or nil
--   shorts    each tab's width with its short word, nil for a tab with none; optional
--
-- Answers a list of booleans, true where the tab keeps its word, the width the tabs then take
-- with their spacing, and true where the worded tabs draw their short words (nil where they draw
-- the full ones, so a caller that passes no shorts reads the two answers it always did). Pure.
function Frame.TabWords(band, rest, labelled, glyphs, spacing, active, shorts)
  band = math.max(tonumber(band) or 0, 0)
  rest = math.max(tonumber(rest) or 0, 0)
  labelled = type(labelled) == "table" and labelled or EMPTY
  glyphs = type(glyphs) == "table" and glyphs or EMPTY
  shorts = type(shorts) == "table" and shorts or EMPTY
  spacing = math.max(tonumber(spacing) or 0, 0)
  local words, full, bare = {}, spacing, spacing
  for index = 1, #labelled do
    local worded = math.max(tonumber(labelled[index]) or 0, 0)
    local glyph = tonumber(glyphs[index])
    full = full + worded
    if glyph then
      bare = bare + math.max(glyph, 0)
    else
      bare = bare + worded
    end
    words[index] = true
  end
  if full + rest <= band then
    return words, full
  end
  -- Brief C2: the short words, where any tab has one.
  local short, shortened = spacing, false
  for index = 1, #labelled do
    local width = tonumber(shorts[index])
    if width then
      shortened = true
      short = short + math.max(width, 0)
    else
      short = short + math.max(tonumber(labelled[index]) or 0, 0)
    end
  end
  if shortened and short + rest <= band then
    return words, short, true
  end
  for index = 1, #labelled do
    if tonumber(glyphs[index]) then
      words[index] = false
    end
  end
  local used = bare
  active = tonumber(active)
  if active and words[active] == false then
    local worded = tonumber(shorts[active]) or tonumber(labelled[active]) or 0
    local kept = bare - math.max(tonumber(glyphs[active]) or 0, 0) + math.max(worded, 0)
    if kept + rest <= band then
      words[active] = true
      used = kept
    end
  end
  if shortened then
    return words, used, true
  end
  return words, used
end

-- Where the client will put one tab's word, as an offset from the button's CENTRE, so the glyph
-- can be put on that same line instead of on a number copied out of the client's source.
--
-- PanelTemplates_SelectTab and PanelTemplates_DeselectTab both do the same two steps: read the
-- base offset off the tab (tab.selectedTextY, tab.deselectedTextY, defaulting to -3 and 2), and
-- then, where the tab says isTopTab, flip its sign and drop it by 7 selected or 6 deselected.
-- The flip is the whole of the fault the owner marked up: a top tab's deselected art hangs off
-- the BOTTOM of the button and is shorter than the selected art, so the bottom tab default of +2
-- puts the word and the glyph over the art's top edge, while the client itself was drawing the
-- word at -8. Selected it is -4, which is why that state already looked right against -3.
--
-- The base offsets are read off the tab when it states them, so a template that sets its own
-- numbers in OnLoad is followed rather than overruled; Frame.TAB_TEXT_Y is only the fall back.
-- Answers the offset the client's own functions will use. Pure.
function Frame.TabTextY(tab, active)
  local stated, flip, fallback
  if active then
    flip, fallback = Frame.TAB_TEXT_TOP_FLIP.selected, Frame.TAB_TEXT_Y.selected
  else
    flip, fallback = Frame.TAB_TEXT_TOP_FLIP.deselected, Frame.TAB_TEXT_Y.deselected
  end
  if type(tab) == "table" then
    if active then
      stated = tonumber(tab.selectedTextY)
    else
      stated = tonumber(tab.deselectedTextY)
    end
  end
  local base = stated or fallback
  if type(tab) == "table" and tab.isTopTab then
    return -base - flip
  end
  return base
end

-- Where the glyph goes inside one of the band's square buttons, as an offset from the button's
-- CENTRE. The New toggle, the Changed toggle and the recently viewed button all ask, so the
-- three cannot drift apart.
--
-- Two measured corrections, both pure arithmetic:
--
--   drop   the bevel the client's input box art draws is not symmetric top to bottom. Drawn over
--          a 24px control, Common-Input-Border's top edge takes 4 rows and its bottom edge 2, so
--          the opening the eye reads as the button's square sits 1px below the button's own
--          centre and a glyph centred on the button reads as sitting high. Measured off the
--          extracted PNG, assets/blizzard/textures/Common-Input-Border.png in ItemTree-Data.
--   pad    the artwork inside an atlas rect need not be centred in it. padLeft, padRight, padTop
--          and padBottom are the transparent margin in the rect's own pixels and rect is the
--          rect's side, so the correction scales with the size the glyph is drawn at. The
--          auction house clock is 2, 3, 2, 2 inside its 24 by 24 rect, a third of a pixel at the
--          16px the button draws it, which is why this rounds to whole pixels.
--
-- Answers x and y, both whole pixels. Pure.
function Frame.SquareGlyphOffset(size, drop, rect, padLeft, padRight, padTop, padBottom)
  size = math.max(tonumber(size) or 0, 0)
  local x, y = 0, -(tonumber(drop) or 0)
  rect = math.max(tonumber(rect) or 0, 0)
  if rect > 0 and size > 0 then
    local scale = size / rect
    x = x + ((tonumber(padRight) or 0) - (tonumber(padLeft) or 0)) / 2 * scale
    y = y + ((tonumber(padTop) or 0) - (tonumber(padBottom) or 0)) / 2 * scale
  end
  local function whole(value)
    return value >= 0 and math.floor(value + 0.5) or -math.floor(-value + 0.5)
  end
  return whole(x), whole(y)
end

-- Brief UX1 (QA item 403, the owner, 2026-10-23): "Add a trainer square button next to the dice so
-- you can easily find class trainers for your CURRENT character (shortcut to open the search in
-- t:warlock for example)". The words Core/TrainerSearch.lua's KINDS knows each class by, keyed by
-- the class's ChrClasses id (UnitClass's third answer, Core/Gear.lua Gear.CLASS).
Frame.CLASS_WORDS = {
  [1] = "warrior",
  [2] = "paladin",
  [3] = "hunter",
  [4] = "rogue",
  [5] = "priest",
  [7] = "shaman",
  [8] = "mage",
  [9] = "warlock",
  [11] = "druid",
}

--- Brief UX1: the word the trainer search knows a class by, from its ChrClasses id, else from the
--- client's own class token ("WARLOCK", UnitClass's second answer) lower cased, so a class this
--- table does not list still searches by its own name. nil for neither. Pure.
function Frame.ClassWord(classId, token)
  local word = Frame.CLASS_WORDS[tonumber(classId) or -1]
  if word then
    return word
  end
  if type(token) == "string" and token ~= "" then
    return (token:lower():gsub("%s+", ""))
  end
  return nil
end

--- Brief UX1: the search the trainer button fills the box with, "t:warlock" (Core/Data.lua
--- Data.ParseSearch's trainer prefix), or "t:" alone, which lists every kind of trainer, where the
--- class is not known. Pure.
function Frame.TrainerQuery(word)
  if type(word) == "string" and word ~= "" then
    return "t:" .. word
  end
  return "t:"
end

-- What fits on the band at a given window width, right to left: the top tabs on the left, then
-- the New and Changed toggles, the trainer button (brief UX1), the random item button, the recently
-- viewed button and the search box on the right.
--
-- The owner's rule, in order: the search box gives up its width first, down to
-- Frame.SEARCH_W_MIN; only once it is at its floor does the recently viewed button drop its
-- words and fall back to the glyph alone. The band never lets the tabs shrink, because the tabs
-- are what the window is navigated by.
--
--   band     the strip's own width
--   tabs     what the top tabs take together, including the air between them
--   squares  what the fixed width squares take together, without their gaps: the two badge
--            toggles, the trainer button and the dice button
--   labelled the recently viewed button with its words
--   glyph    the recently viewed button with the glyph alone
--   gap      the gap between each pair on the right
--   count    how many squares `squares` covers, so the gaps can be counted rather than assumed.
--            There is one gap between each pair of squares, one from the last square to the
--            recently viewed button, one from that button to the box and one more between the
--            tabs and the whole group, which is count + 2 in all. Defaults to 2, the two
--            toggles the band carried before the dice button joined them.
--   buttonGap the gap after each square (between the squares, and from the last one to the
--            recently viewed button), where it differs from gap: the owner halved it (brief
--            SH5, 2026-10-03) and kept the gap to the box and to the tabs. Defaults to gap.
--
-- The owner wants the recently viewed button to keep its word (2026-10-03): where the box at its
-- floor still leaves no room for it, every gap closes to buttonGap before the word goes, and the
-- third answer says so (the box then sits buttonGap right of the button rather than gap).
--
-- Answers the search box's width, whether the button keeps its words and whether the gaps were
-- closed up for them. Pure.
function Frame.BandFit(band, tabs, squares, labelled, glyph, gap, count, buttonGap)
  band = math.max(tonumber(band) or 0, 0)
  tabs = math.max(tonumber(tabs) or 0, 0)
  squares = math.max(tonumber(squares) or 0, 0)
  labelled = math.max(tonumber(labelled) or 0, 0)
  glyph = math.max(tonumber(glyph) or 0, 0)
  gap = math.max(tonumber(gap) or 0, 0)
  count = math.max(tonumber(count) or 2, 0)
  buttonGap = math.max(tonumber(buttonGap) or gap, 0)
  local floor = Frame.SEARCH_W_MIN
  local fixed = tabs + squares + count * buttonGap + 2 * gap
  local search = Frame.SEARCH_W
  if fixed + labelled + search <= band then
    return search, true
  end
  search = math.max(floor, band - fixed - labelled)
  if fixed + labelled + search <= band then
    return search, true
  end
  if buttonGap < gap then
    local tight = tabs + squares + (count + 2) * buttonGap
    search = math.max(floor, band - tight - labelled)
    if tight + labelled + search <= band then
      return search, true, true
    end
  end
  return math.max(floor, math.min(Frame.SEARCH_W, band - fixed - glyph)), false
end

function Frame.PendingKey()
  return Frame.pendingKey
end

-- How many New in Forever items this build has to offer, which is the only thing the dice button
-- needs to know about whether it can be pressed. 0 where Core is not loaded at all, so the
-- button reads as disabled rather than raising.
function Frame.NewItemPoolSize()
  local Data = ItemTree.Data
  if not (Data and type(Data.NewInForeverIds) == "function") then
    return 0
  end
  local ok, ids = pcall(Data.NewInForeverIds, Data)
  if not ok or type(ids) ~= "table" then
    return 0
  end
  return #ids
end

-- The item the dice button opens next: one of the build's New in Forever items, never the one
-- the window is already rooted on and never the one the last press landed on, so a press always
-- moves and two in a row never show the same item. rng is handed straight through to
-- Core/Data.lua, so a spec can fix the pick. nil where the build has nothing new.
function Frame.RandomNewItemId(rng)
  local Data = ItemTree.Data
  if not (Data and type(Data.RandomNewItem) == "function") then
    return nil
  end
  local avoid = {}
  local open = Frame.ItemId(Frame.rootKey)
  if open then
    avoid[#avoid + 1] = open
  end
  if Frame.lastRandomId and Frame.lastRandomId ~= open then
    avoid[#avoid + 1] = Frame.lastRandomId
  end
  local ok, itemId = pcall(Data.RandomNewItem, Data, rng, avoid)
  if not ok or type(itemId) ~= "number" then
    return nil
  end
  return itemId
end

-- What the window opens on when it is asked for with nothing pointed at, as one of four words.
-- lastKey is the node key this session has already opened, nil before the first one, hasNewPool
-- says whether this build has any New in Forever items to pick out of, and recentKey (brief RO1)
-- is the newest page in Recently viewed, nil while that list is empty.
--   "last"    open the item the player was last looking at, which is the one they asked for
--   "recent"  nothing opened yet this session, so open the page Recently viewed holds last, which
--             is where the window was before the reload or the logout (brief RO1, item 290)
--   "new"     nothing opened yet and no history, so pick out of the dice button's own pool
--   "random"  nothing opened yet, no history and this build added nothing, so pick out of the
--             whole database rather than leave the key dead
-- Pure: Frame.OpenDefault reads the facts off the window and does the opening.
function Frame.DefaultOpenChoice(lastKey, hasNewPool, recentKey)
  if type(lastKey) == "string" and lastKey ~= "" then
    return "last"
  end
  if type(recentKey) == "string" and recentKey ~= "" then
    return "recent"
  end
  if hasNewPool then
    return "new"
  end
  return "random"
end

-- Brief D2: the window's empty state when ItemTree_Data did not load. Brief D5: no illustration
-- (the dragon is for data the client really hides, not an addon that did not load), a headline for
-- each reason, the steps centred under it, and an Open AddOns button in place of Reload UI.
Frame.DATA_MISSING_W = 420
Frame.DATA_MISSING_BUTTON_W = 120

-- Why ItemTree_Data did not load, as the client said it, or nil while it has not failed. Pure.
function Frame.DataMissingReason()
  local Data = ItemTree.Data
  local reason = type(Data) == "table" and rawget(Data, "onDemandFailed") or nil
  if type(reason) == "string" and reason ~= "" then
    return reason
  end
  return nil
end

-- The headline for each reason the client gives, as locale keys (tests/spec/locale_spec.lua lists
-- them). Any other reason gets the plain line.
Frame.DATA_MISSING_HEADLINES = {
  DISABLED = "Make sure ItemTree Data is enabled in your addon settings.",
  MISSING = "The ItemTree_Data folder is missing.",
  INTERFACE_VERSION = "The game marks ItemTree Data as out of date. Tick Load out of date AddOns.",
}
Frame.DATA_MISSING_HEADLINES.INCOMPATIBLE = Frame.DATA_MISSING_HEADLINES.INTERFACE_VERSION
Frame.DATA_MISSING_OTHER_HEADLINE = "ItemTree's item data did not load."

-- The headline the empty state draws for a failed load, the words for the reason. Brief SR3: no
-- line under it; the client's own reason ("DISABLED") stays in /itemtree debug and the chat line,
-- which is where a player sending it to the author reads it. The steps that fit the reason go
-- under the headline (Frame.DataMissingSteps). Pure.
function Frame.DataMissingLines(reason)
  return L[Frame.DATA_MISSING_HEADLINES[reason] or Frame.DATA_MISSING_OTHER_HEADLINE]
end

-- The owner's numbered steps for each reason, as locale keys (tests/spec/locale_spec.lua lists
-- them). The chat line carries only the short hint; the window carries the whole list. Brief D5:
-- the client's AddOns list (Blizzard_AddOnList/AddonList.lua, branch forever) turns its Okay
-- button into Reload UI once anything was ticked, and AddonList_OnOkay then calls ReloadUI
-- itself, so the last step needs no button of ours. A new folder is only found on a restart.
Frame.DATA_MISSING_STEPS = {
  DISABLED = {
    "Press Escape and open AddOns.",
    "Tick ItemTree Data (and ItemTree).",
    "Click Reload UI (the Okay button) and the game reloads.",
  },
  MISSING = {
    "Uninstall ItemTree, then install it again: the download holds two folders, ItemTree and ItemTree_Data.",
    "Quit and restart the game.",
  },
  INTERFACE_VERSION = {
    "Press Escape and open AddOns.",
    "Tick Load out of date AddOns at the top.",
    "Click Reload UI (the Okay button) and the game reloads.",
  },
}
Frame.DATA_MISSING_STEPS.INCOMPATIBLE = Frame.DATA_MISSING_STEPS.INTERFACE_VERSION
-- Any other reason: this is the one step, and /itemtree debug names the reason.
Frame.DATA_MISSING_OTHER_STEP = "Type /itemtree debug and send the lines to the author."

-- Whether the Open AddOns button belongs under the steps for a reason: not for a missing folder,
-- which the AddOns list cannot show, and otherwise wherever the list can help. Pure.
function Frame.DataMissingWantsAddOns(reason)
  return reason ~= "MISSING"
end

-- The numbered steps the empty state draws for a reason, "1. Press Escape and open AddOns." and
-- on, in the player's language. Pure.
function Frame.DataMissingSteps(reason)
  local keys = Frame.DATA_MISSING_STEPS[reason] or { Frame.DATA_MISSING_OTHER_STEP }
  local out = {}
  for index, key in ipairs(keys) do
    out[index] = string.format("%d. %s", index, L[key])
  end
  return out
end

--------------------------------------------------------------------------------
-- Coming back to a page (brief E61)
--
-- The owner's report: walk from an item into "and 239 more", open a creature to read its map,
-- then press the item's crumb, and the opened list is shut again and the scroll is back at the
-- top. The window builds a new view model on every open, which is why.
--
-- So the window keeps notes. One page is a root key and the SET of view tabs that root draws
-- (an item's four, a creature's two: the same set brief E57 keys the sticky tab by), and its
-- notes are the marks the player made: which rows they opened or closed, which capped groups
-- they revealed, the category the column is filtered to, the text in the search box, the tab they
-- were on and where each list is scrolled to. Keys and numbers only, in memory only, for the last
-- Frame.PAGE_MEMORY pages of this session.
--
-- The three decisions are pure and live here; the capture and the restore are below the divider
-- with the panes they read.
--------------------------------------------------------------------------------

-- The key one page is remembered under. views is the set of view keys that root draws, joined the
-- way the sticky tab is keyed, so an item and a creature can never share a slot and a set added
-- later needs no list to maintain. nil for a key there is nothing to remember about.
function Frame.PageKey(rootKey, views)
  if type(rootKey) ~= "string" or rootKey == "" then
    return nil
  end
  if type(views) ~= "table" or #views == 0 then
    return rootKey
  end
  return rootKey .. "|" .. table.concat(views, ",")
end

-- Whether an open puts a page back the way it was left or starts it fresh.
--
-- The rule is HOW the player arrived, never whether the window happens to have notes. Coming
-- back restores: the breadcrumb, and any click that re-roots onto a key already on the trail,
-- which is the same step by another name. Asking for something new starts fresh: the search
-- dropdown, the dice, the key or click shortcut on an item, a chat link, and an ordinary row
-- click forward onto a page the trail does not hold, whether or not that page is remembered.
--
-- opts.restore is the carrier for a caller that knows better than the trail does: true for the
-- Recently viewed panel and for reopening the item the window was closed on, false for the two
-- picks above. Anything else, including no opts at all, reads the trail. Pure.
function Frame.ArrivalRestores(opts, path, key, current)
  if type(opts) == "table" and opts.restore ~= nil then
    if opts.restore == true then
      return true
    end
    return false
  end
  if key == nil then
    return false
  end
  -- The page the window is already on is not somewhere it can arrive forward from: reopening it
  -- (the key binding on the item the window was closed on, brief E47) is a return.
  if key == current then
    return true
  end
  if type(path) ~= "table" then
    return false
  end
  for _, held in ipairs(path) do
    if held == key then
      return true
    end
  end
  return false
end

-- Writes one page's notes into the store and makes it the most recently used. memory is
-- { pages = {}, order = {} } with the oldest key at the front of order; page = nil forgets a key.
-- Past cap the least recently used page is dropped, which is the whole of the tidying up: nothing
-- runs on a timer and nothing survives a reload. Answers the store, so a spec can chain. Pure.
function Frame.MemoryPut(memory, key, page, cap)
  if type(memory) ~= "table" or type(key) ~= "string" then
    return memory
  end
  if type(memory.pages) ~= "table" then
    memory.pages = {}
  end
  if type(memory.order) ~= "table" then
    memory.order = {}
  end
  for index, held in ipairs(memory.order) do
    if held == key then
      table.remove(memory.order, index)
      break
    end
  end
  if page == nil then
    memory.pages[key] = nil
    return memory
  end
  memory.pages[key] = page
  memory.order[#memory.order + 1] = key
  cap = math.floor(tonumber(cap) or Frame.PAGE_MEMORY)
  while cap > 0 and #memory.order > cap do
    local oldest = table.remove(memory.order, 1)
    memory.pages[oldest] = nil
  end
  return memory
end

-- One page's notes, or nil where the window has none. Reading them is a visit, so the page moves
-- to the most recently used end: the 24 the player is really walking are the 24 that are kept.
function Frame.MemoryGet(memory, key)
  if type(memory) ~= "table" or type(memory.pages) ~= "table" or type(key) ~= "string" then
    return nil
  end
  local page = memory.pages[key]
  if page == nil then
    return nil
  end
  Frame.MemoryPut(memory, key, page, Frame.PAGE_MEMORY)
  return page
end

-- The pages the window holds notes for, least recently used first. A copy, so reading the queue
-- cannot reorder it. Pure.
function Frame.MemoryKeys(memory)
  local out = {}
  if type(memory) ~= "table" or type(memory.order) ~= "table" then
    return out
  end
  for index, key in ipairs(memory.order) do
    out[index] = key
  end
  return out
end

-- Brief F1: the footer's Merge recipes hover, as a title and the body lines stacked under it. The
-- body is the settings row's own words (UI/Options.lua Options.MergeTooltipLines), one sentence a
-- line, so the tick box and the settings row cannot drift apart. Without the settings file the
-- hover is the title alone. Pure.
function Frame.MergeToggleTip()
  local lines = {}
  local Options = ItemTree.Options
  if type(Options) == "table" and type(Options.MergeTooltipLines) == "function" then
    local ok, answer = pcall(Options.MergeTooltipLines)
    if ok and type(answer) == "table" then
      for _, line in ipairs(answer) do
        if type(line) == "string" and line ~= "" then
          lines[#lines + 1] = line
        end
      end
    end
  end
  return L["Merge recipes"], lines
end

-- Brief TC1: the footer's Total counts hover, in the F1 shape: the title, then one plain line a
-- sentence, saying what it does, the owner's example, and what off means. Pure.
function Frame.TotalsToggleTip()
  return L["Total counts"],
    {
      L["Multiply a recipe's counts down the tree, so each row says how many you need in all."],
      L["12 Arcanite Bars need 12 Thorium Bar and 12 Arcane Crystal."],
      L["Off, each count is for one craft."],
    }
end

--------------------------------------------------------------------------------
-- The Worth keeping switch (brief K4)
--
-- An item page carries "Keep: [Auto] [Always] [Never] [Off]" (brief K5 added Off, TB6 the word) at the
-- right hand end of the caption row, the row that holds the Show classic diff tick box. The
-- segments are view tabs (buildTab and paintTab, so the same textures, the same
-- ITEMTREE_CHROME_TAB_H 24 height and the same selected look), each as wide as its word and
-- Frame.VIEW_TAB_PAD either side, with
-- Frame.VIEW_TAB_GAP between them and ITEMTREE_SPACE_2 between the label and the first. Core/
-- Keep.lua holds the value (Keep.Override, Keep.SetOverride); this only draws and sets it.
--------------------------------------------------------------------------------

-- The four values, in the order the segments are drawn.
Frame.KEEP_VALUES = { "auto", "always", "never", "off" }

-- The word a segment reads. Written out one literal at a time for the locale sweep. Pure.
function Frame.KeepWord(value)
  if value == "always" then
    return L["Always"]
  elseif value == "never" then
    return L["Never"]
  elseif value == "off" then
    return L["Off"]
  end
  return L["Auto"]
end

-- The hover text on the whole group. Brief FN2 (QA item 347j, the owner's choice A of 2026-10-21:
-- "describe what it does"): a title, then one plain line per segment in the order they are drawn,
-- saying what each does, in the Total counts hover's shape (Frame.TotalsToggleTip); no Jettison line
-- (he did not ask for one). Was four sentences in one paragraph (brief K20-wire). Pure.
function Frame.KeepSwitchTip()
  return L["Keep this item?"],
    {
      L["Auto: ItemTree decides from what it is used for"],
      L["Always: always marked Keep"],
      L["Never: never kept, shows how to sell it"],
      L["Off: no Keep or sell tags on this item"],
    }
end

-- Whether a root draws the switch: an item root, and nothing else (creature, vendor, zone, node,
-- quest and spell roots have no bag slot to mark). Pure.
function Frame.KeepSwitchShown(rootKey)
  return Frame.ItemId(rootKey) ~= nil
end

-- The selected segment for an item: "always", "never", "off" or "auto". Pure over Core/Keep.lua.
function Frame.KeepSwitchValue(itemId)
  local keep = ItemTree.Keep
  if type(keep) ~= "table" or type(keep.Override) ~= "function" then
    return "auto"
  end
  local ok, value = pcall(keep.Override, itemId)
  if ok and (value == "always" or value == "never" or value == "off") then
    return value
  end
  return "auto"
end

-- The switch's widths from its measured words: labelW the label, words the three segment words
-- in order, pad the gap after the label. Answers the whole width and each segment's. Pure.
function Frame.KeepSwitchWidths(labelW, words, pad)
  local total = math.max(tonumber(labelW) or 0, 0) + math.max(tonumber(pad) or 0, 0)
  local widths = {}
  for index, word in ipairs(type(words) == "table" and words or EMPTY) do
    widths[index] = math.max(tonumber(word) or 0, 0) + 2 * Frame.VIEW_TAB_PAD
    total = total + widths[index]
  end
  if #widths > 1 then
    total = total + Frame.VIEW_TAB_GAP * (#widths - 1)
  end
  return total, widths
end

-- Brief BL31: the one red plate button the Boss loot place row's map button and the zone list
-- row's eye both draw (Frame.NewPlateButton below): the client's red panel plate, a glyph centred
-- on it at the plate's side less PLATE_BEVEL each side. PLATE_SIZE is its default side, the
-- category glyph's 16.
Frame.PLATE_SIZE = ((Theme and Theme.sizes) or EMPTY).ITEMTREE_ICON_CATEGORY or 16
Frame.PLATE_BEVEL = 3

--- Brief BL31: the glyph's side on a plate button of the given side (PLATE_SIZE where none is
--- given): the side less PLATE_BEVEL at each edge, never under 1, so the glyph scales with the
--- plate. Pure.
function Frame.PlateGlyphSize(side)
  local n = tonumber(side) or Frame.PLATE_SIZE
  return math.max(1, n - 2 * Frame.PLATE_BEVEL)
end

--- Brief BL31: the glyph keys a plate button tries, in order: its own, then its fallback, with
--- nothing given and a repeat dropped. An empty list leaves the plate alone. Pure.
function Frame.PlateGlyphKeys(glyphKey, fallbackKey)
  local keys = {}
  local candidates = { glyphKey, fallbackKey }
  for index = 1, 2 do
    local key = candidates[index]
    if type(key) == "string" and key ~= "" and key ~= keys[1] then
      keys[#keys + 1] = key
    end
  end
  return keys
end

-- Nothing to do on load: the window is built the first time it is opened.
function Frame.Init() end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- One interface cue, by name. UI/Sound.lua owns which sound a cue is and whether cues are on at
-- all; this is the one line a call site writes. Looked up at call time, because a spec loads this
-- file on its own and a build without the module must cost the cue and nothing else.
local playCue = ItemTree.UI.Sound.PlayCue

-- The cue a tick box makes, which the client distinguishes on from off.
local function checkCue(value)
  if value then
    return "checkOn"
  end
  return "checkOff"
end

-- One CreateFrame call, pcall'd, reporting which template it got. A client that does not carry
-- the template still gets its frame without the art; a client with no CreateFrame at all gets
-- nothing, which is what leaves Open returning false under busted.
local function newFrame(kind, name, parent, ...)
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  for index = 1, select("#", ...) do
    local template = select(index, ...)
    local ok, frame = pcall(create, kind, name, parent, template)
    if ok and frame then
      return frame, template
    end
  end
  local ok, frame = pcall(create, kind, name, parent)
  if ok and frame then
    return frame, nil
  end
  return nil
end

-- One CreateFrame call with a template and nothing without one. newFrame above falls back to a
-- bare frame, which is right for everything that draws its own art; a tab made from the client's
-- own template must not, because a bare button with no tab art has to fall back to the home made
-- tab instead.
local function newTemplatedFrame(kind, name, parent, template)
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, kind, name, parent, template)
  if ok and frame then
    return frame
  end
  return nil
end

-- Runs fn on the next frame tick, or straight away on a client with no C_Timer. Returns whether
-- it was deferred, which is what the specs read. Two things in this file need the next tick and
-- not this one: putting the window back after the settings panel has closed it, and dropping the
-- guard that keeps a programmatic write to the search box from searching.
local function nextTick(fn)
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    local ok = pcall(timer.After, 0, fn)
    if ok then
      return true
    end
  end
  fn()
  return false
end

--------------------------------------------------------------------------------
-- Combat (brief E91)
--------------------------------------------------------------------------------

-- A tester could not close the window in combat. On the Forever client, which runs the retail
-- shaped Mainline files, HideUIPanel and ShowUIPanel start with CheckProtectedFunctionsAllowed
-- (Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua, branch forever), which returns
-- early whenever InCombatLockdown() is true and the caller is not secure, and puts up the
-- "Interface action failed because of an AddOn" line instead. The X that PortraitFrameTemplate
-- hands the window is UIPanelCloseButton, whose OnClick is UIPanelCloseButton_OnClick, which calls
-- HideUIPanel(parent) (Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua, same branch), so
-- the X did nothing at all in combat. The X now runs Frame.Hide, whose frame:Hide() is a plain
-- Hide on a frame that is not protected and is never blocked.
--
-- The rest of the rule: nothing on a way in or out of the window makes a protected call in
-- combat. What has to change then (a keyboard propagation reset, a binding, the settings panel)
-- waits in one small queue that runs once, in order, on PLAYER_REGEN_ENABLED. The client fires
-- PLAYER_REGEN_DISABLED before the lockdown begins, which is the last moment a protected call
-- is still allowed, so a pane that holds the keyboard lets it go from Frame.OnCombatStart.

-- Waiting for combat to end, oldest first: { key = key or nil, fn = fn }.
Frame.combatQueue = {}
-- The frames that hold the keyboard, in the order they were first registered:
-- { key = key, release = fn, restore = fn or nil }.
Frame.combatStart = {}

-- Whether the client is in combat lockdown now. A client that will not say reads as out of it.
function Frame.InCombat()
  local lockdown = rawget(_G, "InCombatLockdown")
  if type(lockdown) ~= "function" then
    return false
  end
  local ok, locked = pcall(lockdown)
  return (ok and locked) and true or false
end

-- Runs fn now when out of combat, and otherwise once, on PLAYER_REGEN_ENABLED. A key makes the
-- call replace an earlier one waiting under the same key, so a player pressing the same thing
-- five times in a fight gets it done once. Answers "ran" or "queued", or false for no function.
function Frame.AfterCombat(fn, key)
  if type(fn) ~= "function" then
    return false
  end
  if not Frame.InCombat() then
    pcall(fn)
    return "ran"
  end
  local queue = Frame.combatQueue
  if key ~= nil then
    for _, entry in ipairs(queue) do
      if entry.key == key then
        entry.fn = fn
        return "queued"
      end
    end
  end
  queue[#queue + 1] = { key = key, fn = fn }
  return "queued"
end

-- What PLAYER_REGEN_ENABLED runs: every registered restore first, so a pane has its keyboard
-- back before anything queued asks about it, then the queue. The queue is taken before anything
-- in it runs, so a call that finds itself in combat again lands in the next queue, not in this
-- loop. Answers how many queued calls ran.
function Frame.RunAfterCombat()
  for _, entry in ipairs(Frame.combatStart) do
    if entry.restore then
      pcall(entry.restore)
    end
  end
  local queue = Frame.combatQueue
  Frame.combatQueue = {}
  for _, entry in ipairs(queue) do
    pcall(entry.fn)
  end
  return #queue
end

-- A frame that takes the keyboard registers here. release runs on PLAYER_REGEN_DISABLED, before
-- the lockdown begins, and lets the keyboard go with propagation set back to true, so no key can
-- be kept from the game (Escape above all) while SetPropagateKeyboardInput is refused. restore,
-- when given, runs as combat ends. One entry per key however often it is asked. Answers whether
-- it was registered.
function Frame.OnCombatStart(key, release, restore)
  if key == nil or type(release) ~= "function" then
    return false
  end
  if restore ~= nil and type(restore) ~= "function" then
    restore = nil
  end
  for _, entry in ipairs(Frame.combatStart) do
    if entry.key == key then
      entry.release, entry.restore = release, restore
      return true
    end
  end
  Frame.combatStart[#Frame.combatStart + 1] = { key = key, release = release, restore = restore }
  return true
end

-- What PLAYER_REGEN_DISABLED runs. Answers how many releases ran.
function Frame.RunCombatStart()
  for _, entry in ipairs(Frame.combatStart) do
    pcall(entry.release)
  end
  return #Frame.combatStart
end

-- The tree pane takes the keyboard while the pointer is over it and turns propagation off for
-- the arrow keys it answers. Its own file is another brief's, so the window registers it: the
-- capture is dropped before combat (SetKeyboardCapture(false) lets the keyboard go with
-- propagation on) and worked out again from the pointer once combat is over.
local function treeFn(name)
  local ui = ItemTree.UI
  local tree = type(ui) == "table" and ui.Tree or nil
  local fn = type(tree) == "table" and tree[name] or nil
  if type(fn) == "function" then
    return fn
  end
  return nil
end

Frame.OnCombatStart("Tree", function()
  local release = treeFn("SetKeyboardCapture")
  if release then
    release(false)
  end
end, function()
  local sync = treeFn("SyncKeyboardCapture")
  if sync then
    sync()
  end
end)

-- Puts a frame in the window's own strata, a few levels above the window itself. Child frames
-- inherit their parent's strata, but a pane that sets its own, or a client that draws a nameplate
-- through the strata under this one, can otherwise land between the body surface and the panes.
-- Everything is pcall'd: a stub answers none of these.
local function raiseInto(object, base, step)
  if type(object) ~= "table" then
    return false
  end
  if type(object.SetFrameStrata) == "function" then
    -- Brief PW1: the strata the window is at now (Frame.WindowStrata), which setStrata keeps these
    -- children at as it moves.
    pcall(object.SetFrameStrata, object, Frame.WindowStrata and Frame.WindowStrata() or Frame.STRATA)
  end
  local level = nil
  if type(base) == "table" and type(base.GetFrameLevel) == "function" then
    local ok, value = pcall(base.GetFrameLevel, base)
    level = ok and tonumber(value) or nil
  end
  if level and type(object.SetFrameLevel) == "function" then
    pcall(object.SetFrameLevel, object, level + (tonumber(step) or 1))
  end
  return true
end

-- A child object a template gave the frame, taken as a table only, so a stub or a mixin that
-- answers every name with a function cannot be mistaken for one.
local function child(object, key)
  local value = type(object) == "table" and rawget(object, key) or nil
  if type(value) == "table" then
    return value
  end
  return nil
end

local function size(key)
  local value = (Theme and Theme.sizes and Theme.sizes[key]) or nil
  return tonumber(value) or 0
end

-- Theme.Color raises on an unknown key, so the table is read instead and a missing key leaves the
-- client's own colour alone. Same idiom as UI/Report.lua.
local function themeColor(key)
  local color = Theme and type(Theme.ColorTable) == "function" and Theme.ColorTable(key) or nil
  if not color then
    return nil
  end
  return color.r, color.g, color.b, color.a
end

local function assetEntry(key)
  if not (Assets and type(Assets.Has) == "function" and Assets.Has(key)) then
    return nil
  end
  local ok, entry = pcall(Assets.Get, key)
  if ok and type(entry) == "table" then
    return entry
  end
  return nil
end

local function assetPath(key)
  local entry = assetEntry(key)
  return entry and entry.path or nil
end

-- Applies an asset to a texture, reporting whether it took. A key this build has no art for, or
-- an atlas the client does not carry, leaves the texture blank rather than raising.
local function applyAsset(texture, key)
  if not (texture and Assets and type(Assets.Apply) == "function" and assetEntry(key)) then
    return false
  end
  local ok, applied = pcall(Assets.Apply, texture, key)
  return ok and applied ~= false
end

local function tintTexture(texture, colourKey, alpha)
  if not (texture and type(texture.SetVertexColor) == "function") then
    return false
  end
  local r, g, b, a = themeColor(colourKey)
  if not r then
    return false
  end
  texture:SetVertexColor(r, g, b, alpha or a or 1)
  return true
end

-- A flat fill in a Theme colour. Every texture goes through Assets so the path lives in one
-- table; FILL_WHITE8X8 tinted is what the design's solid colours resolve to.
local function fillTexture(parent, layer, colourKey, alpha)
  if type(parent.CreateTexture) ~= "function" then
    return nil
  end
  local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
  if not texture then
    return nil
  end
  applyAsset(texture, "FILL_WHITE8X8")
  tintTexture(texture, colourKey, alpha)
  return texture
end

-- A 1px border as four flat edges. Corner radius is zero everywhere in this design, so four
-- edges are exactly what the CSS draws. Returns them so the colour can be swapped on a state
-- change.
local function outline(parent, colourKey)
  local edges = {}
  local function edge(first, second, width, height)
    local texture = fillTexture(parent, "BORDER", colourKey)
    if not texture then
      return
    end
    texture:SetPoint(first)
    texture:SetPoint(second)
    if width then
      texture:SetWidth(width)
    end
    if height then
      texture:SetHeight(height)
    end
    edges[#edges + 1] = texture
  end
  edge("TOPLEFT", "TOPRIGHT", nil, 1)
  edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
  edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
  edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
  return edges
end

-- The bevelled corner border the client's own input boxes wear: three slices of
-- Common-Input-Border, which is exactly what InputBoxTemplate draws and so exactly what the
-- search box on the title row is already wearing. The three square buttons beside it are given
-- the same art, so the four controls read as one group. Returns the textures, and nil where the
-- client would not draw the art, which is what leaves the caller its gold hairline.
local function inputBorder(parent)
  if type(parent) ~= "table" or type(parent.CreateTexture) ~= "function" then
    return nil
  end
  local cap = 8
  local pieces = {}
  for _, slice in ipairs({
    { key = "INPUT_BORDER_LEFT", point = "LEFT", width = cap },
    { key = "INPUT_BORDER_RIGHT", point = "RIGHT", width = cap },
    { key = "INPUT_BORDER_MIDDLE" },
  }) do
    local texture = parent:CreateTexture(nil, "BORDER")
    if not (texture and applyAsset(texture, slice.key)) then
      for _, made in ipairs(pieces) do
        if type(made.Hide) == "function" then
          made:Hide()
        end
      end
      return nil
    end
    pieces[#pieces + 1] = texture
    if slice.point then
      texture:SetWidth(slice.width)
      texture:SetPoint("TOP", parent, "TOP", 0, 0)
      texture:SetPoint("BOTTOM", parent, "BOTTOM", 0, 0)
      texture:SetPoint(slice.point, parent, slice.point, 0, 0)
    end
  end
  local middle = pieces[3]
  middle:SetPoint("TOPLEFT", pieces[1], "TOPRIGHT", 0, 0)
  middle:SetPoint("BOTTOMRIGHT", pieces[2], "BOTTOMLEFT", 0, 0)
  return pieces
end

local function setTextColour(fontString, colourKey)
  if type(fontString) ~= "table" then
    return false
  end
  local r, g, b = themeColor(colourKey)
  if r and type(fontString.SetTextColor) == "function" then
    fontString:SetTextColor(r, g, b)
    return true
  end
  return false
end

-- The template a font string is created with, and the client font objects put on one that ended
-- up with no font at all.
Frame.FONT_TEMPLATE = "GameFontNormal"
Frame.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }

-- Hands the font string one of the client's own font objects. Nothing here can raise, and a
-- client carrying none of them answers false, which is as far as this file can go.
local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(Frame.FONT_FALLBACKS) do
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

-- Whether the client says this font string has a font. One that cannot be asked reads as having
-- none, so a font object is put on it anyway: setting one twice costs nothing.
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

-- Every word this file draws goes through here. The font is put back first and the write itself
-- is pcalled, so a font string that lost its font costs the window a blank label rather than
-- raising "FontString:SetText(): Font not set" from inside the client.
local function setText(fontString, text)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  ensureFont(fontString)
  return (pcall(fontString.SetText, fontString, text or ""))
end

-- A font string in the design's faces, with the 1px shadow every font string carries. It is
-- created with a font template, so it has a font before anything writes to it, and SetFont's
-- answer is read: the call answers false rather than raising where the face will not load, and
-- a font string left fontless raises from inside the next SetText.
local function newFontString(parent, faceKey, sizeKey, colourKey)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY", Frame.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY")
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  local face = (Theme and Theme.fonts and Theme.fonts[faceKey]) or nil
  local points = (Theme and Theme.fontSizes and Theme.fontSizes[sizeKey]) or 12
  if face and type(fontString.SetFont) == "function" then
    local set, applied = pcall(fontString.SetFont, fontString, face, points, "")
    if not set or applied == false then
      fallbackFont(fontString)
    end
  end
  ensureFont(fontString)
  local shadow = Theme and Theme.text and Theme.text.ITEMTREE_TEXT_OUTLINE
  if shadow and type(fontString.SetShadowOffset) == "function" then
    fontString:SetShadowOffset(shadow.x, shadow.y)
    if type(fontString.SetShadowColor) == "function" then
      fontString:SetShadowColor(shadow.r, shadow.g, shadow.b, shadow.a)
    end
  end
  setTextColour(fontString, colourKey)
  return fontString
end

-- One line, ended with the client's own ellipsis rather than wrapped or run under the column
-- beside it. A font string given both a left and a right anchor has a width, and without this it
-- wraps inside that width and the second line is clipped; with it the client truncates. Every one
-- of the four calls is optional on a client, so each is asked for and pcall'd, and a client
-- carrying none of them is left with the width it already had.
local function clampToOneLine(fontString, justify)
  if type(fontString) ~= "table" then
    return false
  end
  if justify and type(fontString.SetJustifyH) == "function" then
    pcall(fontString.SetJustifyH, fontString, justify)
  end
  if type(fontString.SetWordWrap) == "function" then
    pcall(fontString.SetWordWrap, fontString, false)
  end
  if type(fontString.SetNonSpaceWrap) == "function" then
    pcall(fontString.SetNonSpaceWrap, fontString, false)
  end
  if type(fontString.SetMaxLines) == "function" then
    pcall(fontString.SetMaxLines, fontString, 1)
  end
  return true
end

-- What a font string measures, or a width per character where the client will not measure one.
-- A stub and a font string with no face both report nothing, and a row of controls laid out at
-- zero width stacks on top of itself.
local function textWidth(fontString, text)
  local width = fontString and type(fontString.GetStringWidth) == "function" and fontString:GetStringWidth()
  return tonumber(width) or (#tostring(text or "") * 6 + 8)
end

-- Escape closes the window. UISpecialFrames is keyed by frame name, so the name is added once
-- however often this runs.
--
-- Brief T6: this list is the one client table ItemTree writes to, because it is the client's own
-- way for an addon window to answer Escape, and the client reads it only from CloseSpecialWindows,
-- which the Escape handler runs under securecallfunction (Blizzard_GameMenuEsc, branch forever),
-- so nothing it reads can taint the rest of the key press. Even so only ItemTree's own slot is
-- ever written: the name is appended, and taking it back out never shifts another entry down
-- (table.remove would rewrite every name after ours, the client's included, from our code). A
-- slot that is not last is parked under a name no frame has, which CloseSpecialWindows skips, and
-- the next register takes that same slot back.
Frame.ESCAPE_PARKED = "ItemTreeEscapeParked"

local function registerEscape(name)
  local special = rawget(_G, "UISpecialFrames")
  if type(special) ~= "table" then
    return false
  end
  local parked
  for index, existing in ipairs(special) do
    if existing == name then
      return true
    end
    if existing == Frame.ESCAPE_PARKED and not parked then
      parked = index
    end
  end
  special[parked or (#special + 1)] = name
  return true
end

-- The other half: takes the name back out, every copy of it, without moving anything else.
local function unregisterEscape(name)
  local special = rawget(_G, "UISpecialFrames")
  if type(special) ~= "table" then
    return false
  end
  local removed = false
  for index = #special, 1, -1 do
    if special[index] == name then
      if index == #special then
        special[index] = nil
      else
        special[index] = Frame.ESCAPE_PARKED
      end
      removed = true
    end
  end
  return removed
end

-- Whether the window is currently out of UISpecialFrames on purpose, which is only ever while
-- the settings panel it opened is up. Read by the specs.
Frame.escapeSuspended = false

-- Whether the window was up when the settings panel was opened, so the close flow knows whether
-- to put it back on screen.
Frame.settingsWasShown = false

-- The window's own strata, pcall'd, with no window to put it on reading as false. Brief PW1: and
-- the two children raiseInto pinned to Frame.STRATA by name (the content area and the data missing
-- block), so they go with the window wherever the client's strata rules leave a child that set its
-- own (a child the window left at HIGH would still draw over the profession window).
local function setStrata(strata)
  local frame = Frame.frame
  if not (frame and type(frame.SetFrameStrata) == "function") then
    return false
  end
  local ok = pcall(frame.SetFrameStrata, frame, strata)
  for _, key in ipairs({ "content", "dataMissing" }) do
    local pinned = rawget(Frame, key)
    if type(pinned) == "table" and type(pinned.SetFrameStrata) == "function" then
      pcall(pinned.SetFrameStrata, pinned, strata)
    end
  end
  return ok
end

-- The strata the window belongs at right now: under the client's profession window while that
-- window has the front (brief PW1, below), one under the settings panel while the panel is up (the
-- suspension below), its own the rest of the time. Every place that puts the window's strata back
-- asks this rather than naming Frame.STRATA, so nothing the player clicks in the window while the
-- settings are open can lift it over the panel.
function Frame.WindowStrata()
  if Frame.professionsFront then
    return Frame.behindStrata or Frame.BEHIND_STRATA
  end
  if Frame.escapeSuspended then
    return Frame.SETTINGS_STRATA
  end
  return Frame.STRATA
end

--------------------------------------------------------------------------------
-- Brief PW1: the client's profession window in front of ours, and ours back in front on a click
--------------------------------------------------------------------------------
-- QA items 238 d and 239 a, the owner: "WHen clicking 'Craft all' the professions page is behind the
-- itemtree tab when it should come to the front and when going back to item tree window the queue
-- and button stay in front", and on Show craft "our itemtree window stays in front".
--
-- Why: this window is HIGH (Frame.STRATA, for the nameplates) and the client's profession window
-- MEDIUM (ProfessionsFrameBase declares no strata, toplevel="true", parent UIParent:
-- Blizzard_Professions/Blizzard_ProfessionsFrameBase.xml:5, origin/forever 1.60.1.70450), raised in
-- MEDIUM by the client's panel manager as it shows (UIParentPanelManager.lua:647, a "left" panel,
-- Blizzard_ProfessionsRegistration.lua:1-14). PR39 E2 dropped this window to MEDIUM while the queue's
-- tray showed, but it kept its own frame levels there, so it still drew over the profession window,
-- and the tray and the View in ItemTree button (both HIGH) stayed over it after a click on it.
--
-- The design, the smallest that holds whatever the frame levels are: strata only, and only OUR
-- window moves. Nothing is called on the client's window (it is read: IsShown, GetFrameStrata).
--   * While the profession window has the front, this window sits one strata UNDER it
--     (Frame.behindStrata, LOW under MEDIUM), raised there over the HUD of that strata. The tray and
--     the View in ItemTree button stay where they are (HIGH), so all three draw over this window.
--   * A click on this window (or the window opening or coming back on purpose, Frame.Open) puts it
--     back at Frame.STRATA, raised there, so it draws over the profession window (MEDIUM) and over the
--     tray and the button (HIGH, under it by level once it is raised).
--   * The profession window takes the front as it shows (whoever opened it), when Craft all, Show
--     craft or the queue's press asks (Frame.ProfessionsToFront), and on a click on it, the tray, the
--     tray's main button or the View in ItemTree button (Frame.AddProfessionsCompanion).
-- The window follows the profession window through the client's own event bus only
-- (ProfessionsMixin:OnShow and OnHide end with EventRegistry "ProfessionsFrame.Show" and
-- "ProfessionsFrame.Hide", Blizzard_Professions/Blizzard_ProfessionsFrame.lua:522 and :541), a tick
-- later, as UI15's button does. A click is GLOBAL_MOUSE_DOWN (SystemDocumentation.lua:64-72) on our
-- own event frame, heard only while the profession window shows; the frame under the pointer is the
-- client's GetMouseFoci answer, walked up through GetParent, every answer read through
-- Util.CanRead (bible B10).
-- One block, so its helpers are not more of the file's top level locals (Lua allows 200).
do
  Frame.PROFESSIONS_WINDOW = "ProfessionsFrame"
  Frame.PROFESSIONS_SHOW_EVENT = "ProfessionsFrame.Show"
  Frame.PROFESSIONS_HIDE_EVENT = "ProfessionsFrame.Hide"
  Frame.CLICK_EVENT = "GLOBAL_MOUSE_DOWN"
  -- The client's strata, lowest first, and where the window goes when the profession window's strata
  -- cannot be read (one under MEDIUM).
  Frame.STRATA_ORDER = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
  Frame.BEHIND_STRATA = "LOW"
  -- How far up a clicked frame's parents are walked.
  Frame.CLICK_DEPTH = 40

  -- Whether the client's profession window has the front (this window under it), and the strata the
  -- window takes then.
  Frame.professionsFront = false
  Frame.behindStrata = Frame.BEHIND_STRATA

  -- Our frames that belong with the profession window: the craft queue's tray, its main button and
  -- the View in ItemTree button (ItemTree_Professions). A click on one gives that window the front.
  Frame.professionsCompanions = setmetatable({}, { __mode = "k" })

  --- The strata one under the given one, never under BACKGROUND; Frame.BEHIND_STRATA for anything
  --- that is not a strata name. Pure.
  function Frame.StrataBelow(strata)
    for index, name in ipairs(Frame.STRATA_ORDER) do
      if name == strata then
        return Frame.STRATA_ORDER[math.max(index - 1, 1)]
      end
    end
    return Frame.BEHIND_STRATA
  end

  -- Whether a client answer may be compared (bible B10), asked at call time so a spec can fake it.
  local function readable(value)
    local util = ItemTree.Util
    if type(util) ~= "table" or type(util.CanRead) ~= "function" then
      return true
    end
    local ok, answer = pcall(util.CanRead, value)
    return ok and answer == true
  end

  -- The client's profession window while it shows, or nil. Read only.
  local function professionsWindow()
    local window = rawget(_G, Frame.PROFESSIONS_WINDOW)
    if type(window) ~= "table" or type(window.IsShown) ~= "function" then
      return nil
    end
    local ok, shown = pcall(window.IsShown, window)
    if ok and readable(shown) and shown == true then
      return window
    end
    return nil
  end

  -- The profession window's strata where it can be read, else nil. Read only.
  local function professionsStrata(window)
    if type(window) ~= "table" or type(window.GetFrameStrata) ~= "function" then
      return nil
    end
    local ok, strata = pcall(window.GetFrameStrata, window)
    if ok and readable(strata) and type(strata) == "string" then
      return strata
    end
    return nil
  end

  -- Raises OUR window in its strata, while it shows.
  local function raiseWindow()
    local frame = Frame.frame
    if frame and type(frame.Raise) == "function" and Frame.IsShown() then
      return (pcall(frame.Raise, frame))
    end
    return false
  end

  -- Hears clicks only while the profession window shows. Answers whether the event frame took it.
  local function hearClicks(on)
    local events = Frame.clickEvents
    if type(events) ~= "table" then
      return false
    end
    local method = on and events.RegisterEvent or events.UnregisterEvent
    if type(method) ~= "function" then
      return false
    end
    Frame.hearingClicks = on and true or false
    return (pcall(method, events, Frame.CLICK_EVENT))
  end

  --- Brief PW1 (i): the client's profession window, with its tray and button, in front of this window.
  --- Only while that window shows; nothing moves otherwise. Answers whether it now has the front.
  function Frame.ProfessionsToFront()
    local window = professionsWindow()
    if not window then
      return false
    end
    Frame.behindStrata = Frame.StrataBelow(professionsStrata(window))
    Frame.professionsFront = true
    setStrata(Frame.WindowStrata())
    raiseWindow()
    hearClicks(true)
    return true
  end

  --- Brief PW1 (ii): this window back in front of the profession window, the tray and the button: its
  --- own strata again (or the settings panel's rule), raised there. Answers whether the profession
  --- window had the front before.
  function Frame.ItemTreeToFront()
    local had = Frame.professionsFront == true
    Frame.professionsFront = false
    setStrata(Frame.WindowStrata())
    raiseWindow()
    hearClicks(professionsWindow() ~= nil)
    return had
  end

  --- Brief PW1: one of our frames that belongs with the profession window (the tray, its main
  --- button, the View in ItemTree button). Answers whether it was taken.
  function Frame.AddProfessionsCompanion(frame)
    if type(frame) ~= "table" then
      return false
    end
    Frame.professionsCompanions[frame] = true
    return true
  end

  -- One frame's parent, read through Util.CanRead, or nil.
  local function parentOf(frame)
    if type(frame) ~= "table" or type(frame.GetParent) ~= "function" then
      return nil
    end
    local ok, parent = pcall(frame.GetParent, frame)
    if ok and readable(parent) and type(parent) == "table" then
      return parent
    end
    return nil
  end

  --- Which side a click landed on, from the frames under the pointer (GetMouseFoci's list, innermost
  --- first): "itemtree" where the first that says is this window or inside it, "professions" where it
  --- is the client's profession window or inside it, or one of its companions; nil for anything else
  --- (the world, the bags, the action bars). Each frame is walked up its parents.
  function Frame.ClickSide(foci)
    local window = rawget(_G, Frame.PROFESSIONS_WINDOW)
    for _, focus in ipairs(type(foci) == "table" and foci or EMPTY) do
      local walk = focus
      for _ = 1, Frame.CLICK_DEPTH do
        if type(walk) ~= "table" or not readable(walk) then
          break
        end
        if Frame.frame and walk == Frame.frame then
          return "itemtree"
        end
        if (window ~= nil and walk == window) or Frame.professionsCompanions[walk] then
          return "professions"
        end
        walk = parentOf(walk)
      end
    end
    return nil
  end

  -- The frames under the pointer, innermost first, or an empty list: GetMouseFoci, the client's
  -- modern shape, else the older GetMouseFocus (UI/Keybind.lua reads them the same way).
  local function mouseFoci()
    local foci = rawget(_G, "GetMouseFoci")
    if type(foci) == "function" then
      local ok, frames = pcall(foci)
      if ok and type(frames) == "table" then
        return frames
      end
    end
    local focus = rawget(_G, "GetMouseFocus")
    if type(focus) == "function" then
      local ok, frame = pcall(focus)
      if ok and type(frame) == "table" then
        return { frame }
      end
    end
    return EMPTY
  end

  --- GLOBAL_MOUSE_DOWN while the profession window shows: a click on this window brings it to the
  --- front; one on the profession window or a companion gives that window the front. Answers the
  --- side the click landed on.
  function Frame.OnClickAnywhere()
    local side = Frame.ClickSide(mouseFoci())
    if side == "itemtree" and Frame.professionsFront then
      Frame.ItemTreeToFront()
    elseif side == "professions" and not Frame.professionsFront then
      Frame.ProfessionsToFront()
    end
    return side
  end

  --- The profession window has shown (a tick after the client's own show): it takes the front,
  --- whoever opened it. Answers whether it did.
  function Frame.OnProfessionsShown()
    return Frame.ProfessionsToFront()
  end

  --- The profession window has gone: the window goes back to its own strata and stops hearing
  --- clicks. Nothing where it shows again by then. Answers whether the window moved.
  function Frame.OnProfessionsHidden()
    if professionsWindow() then
      return false
    end
    hearClicks(false)
    if not Frame.professionsFront then
      return false
    end
    Frame.professionsFront = false
    setStrata(Frame.WindowStrata())
    return true
  end

  -- The client's event bus the profession window's callbacks are registered with, once per bus.
  local professionsRegistry = nil

  -- Brief PW1: follows the profession window through EventRegistry only; each callback books the
  -- work for the next tick, after the client's own show and hide have run. Answers whether both
  -- were taken.
  function Frame.WatchProfessions()
    local registry = rawget(_G, "EventRegistry")
    if type(registry) ~= "table" or type(registry.RegisterCallback) ~= "function" then
      return false
    end
    if professionsRegistry == registry then
      return true
    end
    local okShow = pcall(registry.RegisterCallback, registry, Frame.PROFESSIONS_SHOW_EVENT, function()
      nextTick(Frame.OnProfessionsShown)
    end, Frame)
    local okHide = pcall(registry.RegisterCallback, registry, Frame.PROFESSIONS_HIDE_EVENT, function()
      nextTick(Frame.OnProfessionsHidden)
    end, Frame)
    if okShow and okHide then
      professionsRegistry = registry
    end
    return professionsRegistry == registry
  end

  -- Brief PW1: the click listener, our own frame with no parent, made once with the window (at
  -- login, brief PF2) and registered for GLOBAL_MOUSE_DOWN only while the profession window shows.
  function Frame.BuildClickEvents()
    if Frame.clickEvents then
      return Frame.clickEvents
    end
    local events = newFrame("Frame")
    if not events then
      return nil
    end
    if type(events.SetScript) == "function" then
      pcall(events.SetScript, events, "OnEvent", function(_, event)
        if event == Frame.CLICK_EVENT then
          pcall(Frame.OnClickAnywhere)
        end
      end)
    end
    Frame.clickEvents = events
    -- The window built with the profession window already up (the tab turned on with it open).
    if professionsWindow() then
      hearClicks(true)
    end
    return events
  end

  --- Brief PR39 item E2, kept as the tray's call (ItemTree_Professions/UI/Queue.lua Queue.TellWindow,
  --- on the tray's own OnShow and OnHide). Brief PW1: the tray showing (Craft all) gives the profession
  --- window the front; the tray going leaves this window where it is while that window still shows,
  --- and puts it back where the window does not. Answers the strata now asked for.
  function Frame.SetProfessionsUp(up)
    if up == true then
      Frame.ProfessionsToFront()
    elseif not professionsWindow() and Frame.professionsFront then
      Frame.professionsFront = false
      setStrata(Frame.WindowStrata())
    end
    return Frame.WindowStrata()
  end
end

-- Whether the client's own settings panel is on screen now. A panel that is not loaded, or will
-- not say, reads as not shown, which leaves every caller doing what it did before brief E76.
function Frame.SettingsPanelShown()
  local panel = rawget(_G, "SettingsPanel")
  if type(panel) ~= "table" or type(panel.IsShown) ~= "function" then
    return false
  end
  local ok, shown = pcall(panel.IsShown, panel)
  return (ok and shown) and true or false
end

-- Brief E76: the window stays on screen, one strata under the settings panel, for as long as the
-- panel is up. Called a tick after the panel shows (onSettingsShown) and a tick after that, after
-- the footer button, and a tick after anything hides the window while the suspension holds. Shown, never raised: the
-- panel stays on top. Answers whether the window is being held.
local function holdWindow()
  if not (Frame.escapeSuspended and Frame.settingsWasShown) then
    return false
  end
  -- Brief PW1: Frame.WindowStrata, so a window behind the profession window stays behind it.
  setStrata(Frame.WindowStrata())
  local frame = Frame.frame
  if frame and type(frame.Show) == "function" and not Frame.IsShown() then
    pcall(frame.Show, frame)
  end
  return true
end

-- Puts the window back the way it was before the settings panel: back in UISpecialFrames, back at
-- Frame.STRATA, and back on screen when it was on screen before the panel's close flow took it
-- off. Called a frame after the panel hides, and again from Frame.Open and Frame.Hide, so the
-- window can never be left permanently outside the list or stuck at the lower strata by a panel
-- that closed without telling us.
function Frame.RestoreEscape()
  if not Frame.escapeSuspended then
    return false
  end
  Frame.escapeSuspended = false
  setStrata(Frame.WindowStrata())
  local restored = registerEscape(Frame.FRAME_NAME)
  if Frame.settingsWasShown then
    Frame.settingsWasShown = false
    local frame = Frame.frame
    if frame and type(frame.Show) == "function" and not Frame.IsShown() then
      pcall(frame.Show, frame)
    end
  end
  return restored
end

-- What the settings panel hiding means to the window, on the next frame tick rather than on this
-- one. SettingsPanelMixin:Close runs ExitWithCommit, which runs TransitionBackOpeningPanel:
-- HideUIPanel(self), which is where OnHide fires, and then ToggleGameMenu, which runs
-- CloseAllWindows, which runs CloseSpecialWindows and hides every shown frame in UISpecialFrames.
-- Putting the window back in the list inside OnHide therefore put it back in time to be closed by
-- the panel's own X. A tick later the close flow has finished and the window is left alone.
local function onSettingsHidden()
  nextTick(function()
    Frame.RestoreEscape()
  end)
  return true
end

-- The client's event bus the two settings callbacks are registered with, so a second call (and a
-- spec's fresh registry) registers once per bus.
local settingsRegistry = nil

-- The client's own callback name for a managed panel coming up (UIParentPanelManager.lua,
-- BroadcastShowUIPanelEvent, branch forever). Read only: ItemTree never shows a client panel.
Frame.PANEL_SHOWN_EVENT = "UIParentPanelManager.ShowUIPanel"
-- Assigned below, and captured by the show callback before anything can fire it.
local suspendEscape

-- The panel appearing by any route at all, not only through the footer's Options button: the
-- player can reach it from the game menu with the window already up, and the window has to get
-- out of its way there too. A window the footer button marked as wanted (Frame.settingsWasShown)
-- is held even if something took it down before the panel appeared.
--
-- Brief TX1: never run inside the panel's Show. This used to be a HookScript on the panel's
-- OnShow, which put our code, our UISpecialFrames write and a Show of our window inside the
-- client's ShowUIPanel chain, where the gamepad FrameControlsManager and SmartNavigation write
-- their own state (Blizzard_GamepadSharedUtility FrameControlsManager.lua, branch forever). It
-- now runs a tick after the client's own "UIParentPanelManager.ShowUIPanel" callback, and does
-- nothing for a panel that has gone again by then.
local function onSettingsShown()
  if not Frame.SettingsPanelShown() then
    return false
  end
  if not (Frame.IsShown() or Frame.settingsWasShown) then
    return false
  end
  Frame.settingsWasShown = true
  local suspended = suspendEscape()
  holdWindow()
  nextTick(holdWindow)
  return suspended
end

-- Whether a frame carries a script, asked first because the beta is retail shaped in places and
-- Classic shaped in others. A frame that will not say reads as carrying it, because HookScript is
-- pcall'd anyway and a frame with no HasScript at all is the older shape that has every script.
local function carriesScript(frame, script)
  if type(frame.HasScript) ~= "function" then
    return true
  end
  local ok, has = pcall(frame.HasScript, frame, script)
  if not ok then
    return true
  end
  return has and true or false
end

-- Brief TX1: the settings panel is watched through the client's own event bus only, never with
-- HookScript on the panel. On the forever branch the panel is a managed UI panel (area "center",
-- Blizzard_Settings_Shared/Blizzard_Registration.lua), so its Open runs ShowUIPanel, which ends
-- with EventRegistry:TriggerEvent("UIParentPanelManager.ShowUIPanel", frame), and its OnHide
-- ends with EventRegistry:TriggerEvent("SettingsPanel.OnHide"). TriggerEvent runs every callback
-- through secureexecuterange, so whatever our callback does stays out of the client's own path,
-- and each callback only books the real work for the next tick. The owner's report: a HookScript
-- on the panel had the gamepad close path (FrameHidden, InputBindingManager:RemoveSet,
-- UpdateInteractIcons) call the protected SetPreferredGamepadInteractTarget as ItemTree.
local function hookSettingsEvent()
  local registry = rawget(_G, "EventRegistry")
  if type(registry) ~= "table" or type(registry.RegisterCallback) ~= "function" then
    return false
  end
  if settingsRegistry == registry then
    return true
  end
  local panelShown = function(_, frame)
    local panel = rawget(_G, "SettingsPanel")
    if panel == nil or frame ~= panel then
      return
    end
    nextTick(onSettingsShown)
  end
  local okShow = pcall(registry.RegisterCallback, registry, Frame.PANEL_SHOWN_EVENT, panelShown, Frame)
  local okHide = pcall(registry.RegisterCallback, registry, "SettingsPanel.OnHide", function()
    onSettingsHidden()
  end, Frame)
  if okShow or okHide then
    settingsRegistry = registry
  end
  return settingsRegistry == registry
end

-- Takes the window out of UISpecialFrames and drops it one strata for as long as the settings
-- panel is up. Two things went wrong before: Escape with the panel open ran the client's
-- CloseSpecialWindows, which hides every shown frame in that list, so the window went with the
-- panel, and SettingsPanel is declared HIGH and toplevel exactly like this window, so the panel
-- opened behind it. The owner wants the panel on top, the window still visible under it, and
-- neither Escape nor the panel's X to close the window.
--
-- Brief E76: the suspension no longer depends on the name having been in the list. It used to
-- answer false and leave Frame.settingsWasShown set with nothing to clear it, so the window was
-- neither held nor put back.
function suspendEscape()
  -- Brief PW1: through Frame.WindowStrata (the settings panel's strata, or under the profession
  -- window while that window has the front, which is under the panel too).
  if Frame.escapeSuspended then
    setStrata(Frame.WindowStrata())
    return true
  end
  unregisterEscape(Frame.FRAME_NAME)
  Frame.escapeSuspended = true
  setStrata(Frame.WindowStrata())
  hookSettingsEvent()
  return true
end

-- The window anatomy in pixels, worked out once from Theme.sizes. Every vertical offset in the
-- window is stacked here rather than added up again at each anchor, because the header was
-- drawing over the template's own chrome when each row worked its own top out.
local anatomy = nil

local function layout()
  if anatomy then
    return anatomy
  end
  local border = size("ITEMTREE_FRAME_BORDER")
  local titleBar = size("ITEMTREE_CHROME_TITLEBAR_H")
  local control = size("ITEMTREE_CONTROL_H_SM")
  local titleControl = size("ITEMTREE_CONTROL_H_MD")
  local pad = size("ITEMTREE_SPACE_2")
  local gap = size("ITEMTREE_SPACE_1")
  local margin = size("ITEMTREE_CHROME_BODY_MARGIN")
  local tabH = size("ITEMTREE_CHROME_TAB_H")
  local topTabH = size("ITEMTREE_CHROME_TAB_TOP_H")
  local crumbH = size("ITEMTREE_ROW_CATEGORY")
  local captionH =
    math.max(control, 6 + ((Theme and Theme.fontSizes and Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_SM) or 11))
  -- The title bar sits just inside the frame art. The window's inner edge clears both it and the
  -- portrait: the template's portrait ring reaches ITEMTREE_CHROME_PORTRAIT_INSET_Y down from the
  -- top edge, and anything drawn above that line was being drawn over.
  local titleTop = 6
  local portraitX = size("ITEMTREE_CHROME_PORTRAIT_INSET_X")
  local portraitY = size("ITEMTREE_CHROME_PORTRAIT_INSET_Y")
  local chromeTop = math.max(titleTop + titleBar, portraitY)
  -- The dark surface, inset the same margin from all four inner edges, and everything inside it
  -- inset the same padding again.
  local surfaceTop = chromeTop + margin
  local surfaceSide = border + margin
  local inner = surfaceSide + pad
  local innerTop = surfaceTop + pad
  local innerBottom = surfaceSide + pad
  -- The top tabs sit in the grey band the template draws between the title art and the inner
  -- edge, with their bottom edge on the dark surface, which is how the Macro window carries its
  -- own two tabs. They start clear of the portrait ring.
  local topTabTop = surfaceTop - topTabH
  local crumbTop = innerTop
  local captionTop = crumbTop + crumbH
  anatomy = {
    border = border,
    pad = pad,
    gap = gap,
    margin = margin,
    frame = size("ITEMTREE_PAD_FRAME"),
    titleBar = titleBar,
    titleArt = size("ITEMTREE_CHROME_TITLE_ART_H"),
    portrait = size("ITEMTREE_CHROME_PORTRAIT"),
    portraitX = portraitX,
    portraitY = portraitY,
    tabH = tabH,
    tabW = size("ITEMTREE_CHROME_TAB_W"),
    topTabH = topTabH,
    -- The glyph beside a tab's word, at the tab token's own 16px: the owner asked for 16 and
    -- ITEMTREE_CHROME_TAB_ICON now says so, so the top tabs read it again rather than borrowing
    -- the category icon's size.
    topTabIcon = size("ITEMTREE_CHROME_TAB_ICON"),
    topTabTop = topTabTop,
    topTabLeft = math.max(portraitX + gap, inner),
    crumbH = crumbH,
    -- The caption row is as tall as the tick box that sits in it.
    captionH = captionH,
    -- The footer is one row of 20px controls with the design's 4px above and below them.
    footerH = control + gap,
    rowH = size("ITEMTREE_LIST_ROW_H"),
    grip = size("ITEMTREE_CHROME_GRIP"),
    toggle = control,
    -- The square icon buttons on the title row, and the search box beside them: one height for
    -- all four. box.bandGap, the 8 token, is the gap to the search box and to the tabs (the owner
    -- asked for a few more pixels there). Brief SH5: the owner halved the gap between the buttons
    -- themselves, so box.buttonGap, the 4 token, sits between the two badge toggles, the dice and
    -- the recently viewed button.
    titleButton = titleControl,
    searchH = titleControl,
    bandGap = pad,
    buttonGap = gap,
    -- The air the content area leaves over the footer now that the footer's top rule has gone.
    -- The rule used to sit 2px under the panes' own bottom borders and the eye read the two as
    -- one doubled line; with the rule gone the legend wants room instead of a second edge.
    footerPad = pad,
    titleTop = titleTop,
    chromeTop = chromeTop,
    surfaceTop = surfaceTop,
    surfaceSide = surfaceSide,
    inner = inner,
    innerTop = innerTop,
    innerBottom = innerBottom,
    crumbTop = crumbTop,
    captionTop = captionTop,
    bodyTop = captionTop + captionH + gap,
  }
  return anatomy
end

-- The window's inner edge, measured in from each edge of Frame.frame: the ornamental border on
-- three sides and the template's own top chrome above. The anatomy above is a file local, so a
-- pane that has to cover or line up with the window asks for these rather than mirroring the
-- numbers. UI/History.lua anchors its scrim from them. Reads Theme only, so it answers with no
-- client present. The dark surface is inset a further ITEMTREE_CHROME_BODY_MARGIN inside this.
function Frame.BodyInsets()
  local box = layout()
  return { left = box.border, right = box.border, top = box.chromeTop, bottom = box.border }
end

-- Where a modal drawn over the window has to start, measured the same way.
--
-- The same three sides as the body, and the top tab band's own top on the fourth. The band
-- sits in the grey chrome above the window's inner edge, so a scrim anchored to the body
-- starts under it and leaves the tabs, the two toggles, the rewind button and the search box
-- uncovered and still clickable. UI/History.lua's scrim anchors from these. Reads Theme only.
function Frame.OverlayInsets()
  local box = layout()
  local insets = Frame.BodyInsets()
  if box.topTabTop < insets.top then
    insets.top = box.topTabTop
  end
  return insets
end

-- Brief SH5: where the Share link's left edge and vertical centre sit, measured from the window's
-- top left corner: left aligned with the tab row. Brief SH8 (owner QA, 2026-10-04: it sat high)
-- centres it in the gap between the two real anchors, the title bar's bottom edge (buildTitleBar
-- hangs the bar titleTop down and makes it titleBar tall) and the tab strip's top edge (buildTabs
-- hangs it topTabTop down), so the room above and below it is the same. Reads Theme only, so it
-- answers with no client.
function Frame.ShareLinkSpot()
  local box = layout()
  local barBottom = box.titleTop + box.titleBar
  return box.topTabLeft, math.floor((barBottom + box.topTabTop) / 2 + 0.5)
end

-- How far below the window's own top edge one tab starts its region, and how far in from the
-- left. A tab that draws either of the two header rows starts under them, at the body's own top,
-- which is where the content area is. A tab that draws neither starts at the breadcrumb row's own
-- top instead, so the two rows' height goes to that tab's list rather than to blank chrome.
-- Reads Theme and Frame.HEADER_ROWS only, so it answers with no client present.
function Frame.RegionTopFor(tabName)
  local box = layout()
  local rows = Frame.HeaderRowsFor(tabName)
  if rows.crumbs or rows.diffRow then
    return box.bodyTop, box.inner
  end
  return box.crumbTop, box.inner
end

--------------------------------------------------------------------------------
-- The player's professions
--------------------------------------------------------------------------------

-- The gathering itself is UI/PlayerSkills.lua (brief PR12b: it moved out to keep this file's chunk
-- under Lua 5.1's 200 locals). It is looked up at call time, so a spec that loads this file alone
-- answers an empty table here, the way a client with no professions does.
-- What the player can make: { [skillLine] = { rank, max, specialisations = { name, ... } } },
-- read off the client and cached until the client says it moved. The Tree and Sidebar panes call
-- this lazily, so nothing is asked of the client until a profession category is drawn, and with
-- no client at all the answer is an empty table rather than nothing.
-- Brief PR42: while the developer's pretend professions are on (UI/PlayerSkills.lua DemoSkills),
-- they are the answer, never cached, and the client is not asked.
function Frame.PlayerSkills()
  local skills = ItemTree.UI.PlayerSkills
  if type(skills) == "table" and type(skills.DemoSkills) == "function" then
    local pretend = skills.DemoSkills()
    if pretend then
      return pretend
    end
  end
  if Frame.skills then
    return Frame.skills
  end
  local out = {}
  if type(skills) ~= "table" then
    return out
  end
  -- GetProfessions lists every profession, secondary ones too, so where it answered the skill
  -- sheet has nothing to add; skipping it keeps its name lookup from loading ItemTree_Data.
  if not skills.gatherProfessions(out) then
    skills.gatherSkillSheet(out)
  end
  skills.gatherTradeSkills(out)
  -- An empty answer is never cached: at login the client can answer before its skill data is
  -- ready, and the next call should ask again.
  if next(out) ~= nil then
    Frame.skills = out
  end
  return out
end

-- Drops the cache. The event watcher at the bottom of this file calls it on SKILL_LINES_CHANGED,
-- LEARNED_SPELL_IN_TAB and PLAYER_ENTERING_WORLD.
function Frame.InvalidateSkills()
  Frame.skills = nil
  local skills = ItemTree.UI.PlayerSkills
  if type(skills) == "table" and type(skills.resetSkillLines) == "function" then
    skills.resetSkillLines()
  end
  return true
end

--------------------------------------------------------------------------------
-- Building the window
--------------------------------------------------------------------------------

-- The ornamental border. PortraitFrameTemplate draws its own; without it the nine slice layout
-- is asked for by name, and a client with neither takes the FRAME_BORDER art as a backdrop at the
-- asset's own 16px slice.
local function applyFrameArt(frame, template)
  if template == "PortraitFrameTemplate" then
    return true
  end
  local util = rawget(_G, "NineSliceUtil")
  if util and type(util.ApplyLayoutByName) == "function" then
    local ok = pcall(util.ApplyLayoutByName, frame, "Dialog")
    if ok then
      return true
    end
  end
  if type(frame.SetBackdrop) ~= "function" then
    return false
  end
  local entry = assetEntry("FRAME_BORDER")
  local ok = pcall(frame.SetBackdrop, frame, {
    bgFile = assetPath("FRAME_BACKGROUND"),
    edgeFile = entry and entry.path or nil,
    tile = true,
    tileSize = 16,
    edgeSize = (entry and entry.slice) or size("ITEMTREE_FRAME_BORDER"),
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  if ok and type(frame.SetBackdropColor) == "function" then
    local r, g, b = themeColor("ITEMTREE_COLOR_SURFACE_FRAME")
    if r then
      pcall(frame.SetBackdropColor, frame, r, g, b, 1)
    end
  end
  return ok
end

-- A 1px border around a texture, as four flat edges anchored to its corners. outline above draws
-- the same thing around a frame; a texture cannot be a parent, so this is the shape that works
-- for the body surface.
local function outlineTexture(parent, region, colourKey, layer)
  local edges = {}
  local function edge(first, second, width, height)
    local texture = fillTexture(parent, layer or "BORDER", colourKey)
    if not texture then
      return
    end
    texture:SetPoint(first, region, first)
    texture:SetPoint(second, region, second)
    if width then
      texture:SetWidth(width)
    end
    if height then
      texture:SetHeight(height)
    end
    edges[#edges + 1] = texture
  end
  edge("TOPLEFT", "TOPRIGHT", nil, 1)
  edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
  edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
  edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
  return edges
end

-- The body surface. PortraitFrameTemplate's own background is the grey translucent wash the beta
-- draws, which the design does not have anywhere: the body is the opaque
-- ITEMTREE_COLOR_SURFACE_FRAME. One fill over the template's background and under every child
-- frame is all that takes, because a child frame always draws above its parent's textures.
-- It is inset the same ITEMTREE_CHROME_BODY_MARGIN from all four of the window's inner edges, so
-- the template's title tile, its portrait and the tab row above keep the grey band they sit in
-- and the dark panel reads as a panel rather than as a hole. A dim gold hairline finishes it.
local function applyBodySurface(frame)
  local box = layout()
  local surface = fillTexture(frame, "BACKGROUND", "ITEMTREE_COLOR_SURFACE_FRAME", 1)
  if not surface then
    return nil
  end
  if type(surface.SetDrawLayer) == "function" then
    pcall(surface.SetDrawLayer, surface, "BACKGROUND", 1)
  end
  surface:SetPoint("TOPLEFT", frame, "TOPLEFT", box.surfaceSide, -box.surfaceTop)
  surface:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -box.surfaceSide, box.surfaceSide)
  Frame.bodySurface = surface
  -- On BORDER, not BACKGROUND: the surface itself is drawn at BACKGROUND sublevel 1 and would
  -- cover a hairline sitting under it.
  Frame.bodyEdges = outlineTexture(frame, surface, "ITEMTREE_COLOR_BORDER_GOLD_DIM")
  return surface
end

-- The template's own title font string, or nil where there is none to borrow.
local function templateTitle(frame)
  local container = child(frame, "TitleContainer")
  local text = (container and child(container, "TitleText")) or child(frame, "TitleText")
  if text and type(text.SetText) == "function" then
    return text
  end
  local named = rawget(_G, Frame.FRAME_NAME .. "Text")
  if type(named) == "table" and type(named.SetText) == "function" then
    return named
  end
  return nil
end

-- The template's round portrait slot, or nil.
local function templatePortrait(frame)
  local container = child(frame, "PortraitContainer")
  local portrait = (container and child(container, "portrait"))
    or child(frame, "portrait")
    or child(frame, "Portrait")
    or rawget(_G, Frame.FRAME_NAME .. "Portrait")
  if type(portrait) == "table" and type(portrait.SetTexture) == "function" then
    return portrait
  end
  return nil
end

local function saveWindow()
  return Frame.SaveWindow()
end

-- The clock, the words and the plate under them: the recently viewed button.
--
-- The band's other controls are squares, so the glyph in each one is placed by
-- Frame.SquareGlyphOffset and they cannot drift apart; this one is a real labelled button, so
-- its glyph and word are placed by Frame.GlyphGroup, the same function the top tabs use.

-- The three states the client's own panel button art carries, drawn here where the client does
-- not carry UIPanelButtonTemplate. Returns the table of textures, or nil where the art would not
-- draw, which leaves the caller its own plate.
local function panelButtonArt(button)
  local made = {}
  for _, state in ipairs({
    { key = "normal", asset = "BUTTON_UP", layer = "BACKGROUND" },
    { key = "pushed", asset = "BUTTON_DOWN", layer = "BACKGROUND" },
    { key = "highlight", asset = "BUTTON_HIGHLIGHT", layer = "HIGHLIGHT" },
  }) do
    local texture = type(button.CreateTexture) == "function" and button:CreateTexture(nil, state.layer) or nil
    if not (texture and applyAsset(texture, state.asset)) then
      for _, drawn in pairs(made) do
        if type(drawn.Hide) == "function" then
          drawn:Hide()
        end
      end
      return nil
    end
    texture:SetAllPoints(button)
    -- Brief BL32: the highlight file is an opaque orange plate unless it is drawn additively, and
    -- the HIGHLIGHT layer draws above every glyph on the button. The client's own
    -- UIPanelButtonTemplate declares it alphaMode="ADD", so it glows through as it does there.
    if state.key == "highlight" and type(texture.SetBlendMode) == "function" then
      pcall(texture.SetBlendMode, texture, "ADD")
    end
    if state.key == "normal" then
      texture:Show()
    else
      texture:Hide()
    end
    made[state.key] = texture
  end
  return made
end

-- Which of the home made plate's three textures is showing. The template draws its own states,
-- so this only runs on a client without it.
local function paintPanelButton(button, state)
  local art = button and button.plate
  if type(art) ~= "table" then
    return false
  end
  local pushed = state == "pushed"
  local lit = state == "hover" or state == "open"
  if art.pushed then
    if pushed then
      art.pushed:Show()
    else
      art.pushed:Hide()
    end
  end
  if art.normal then
    if pushed then
      art.normal:Hide()
    else
      art.normal:Show()
    end
  end
  if art.highlight then
    if lit then
      art.highlight:Show()
    else
      art.highlight:Hide()
    end
  end
  return true
end

-- Brief BL31: shows or hides one texture or frame, whatever it is.
local function showIf(region, shown)
  if type(region) ~= "table" then
    return
  end
  local method = shown and region.Show or region.Hide
  if type(method) == "function" then
    pcall(method, region)
  end
end

-- Brief BL32: the frame a plate button's glyph is drawn on, a child of the button one frame level
-- above it, so no HIGHLIGHT layer texture of the button (the plate's highlight) can ever cover the
-- glyph. Takes no mouse, so the button keeps every press and hover. The button itself where the
-- client makes no child frame.
local function plateGlyphFrame(button)
  local holder = newFrame("Frame", nil, button)
  if type(holder) ~= "table" then
    return button
  end
  if type(holder.SetAllPoints) == "function" then
    pcall(holder.SetAllPoints, holder, button)
  end
  if type(holder.EnableMouse) == "function" then
    pcall(holder.EnableMouse, holder, false)
  end
  local level = nil
  if type(button.GetFrameLevel) == "function" then
    local ok, value = pcall(button.GetFrameLevel, button)
    level = ok and tonumber(value) or nil
  end
  if level and type(holder.SetFrameLevel) == "function" then
    pcall(holder.SetFrameLevel, holder, level + 1)
  end
  return holder
end

--- Brief BL31: paints a plate button (Frame.NewPlateButton) in a state: "pushed" while the mouse
--- is down, "hover" under the pointer, "normal" at rest. The plate's own highlight lights under
--- the pointer; the glyph is shown in every state and nothing dims the button. Answers whether
--- it was a button.
function Frame.PaintPlateButton(button, state)
  if type(button) ~= "table" then
    return false
  end
  local art = rawget(button, "plate")
  if type(art) == "table" then
    local pushed = state == "pushed"
    showIf(art.pushed, pushed)
    showIf(art.normal, not pushed)
    showIf(art.highlight, state == "hover")
    -- Brief PW1: a sliced plate's end caps go with their middle (Frame.SlicePlate).
    local caps = rawget(art, "caps")
    if type(caps) == "table" then
      for key, shown in pairs({ normal = not pushed, pushed = pushed }) do
        local pair = caps[key]
        if type(pair) == "table" then
          showIf(pair.left, shown)
          showIf(pair.right, shown)
        end
      end
    end
  end
  showIf(rawget(button, "highlight"), state == "hover")
  local glyphFrame = rawget(button, "glyphFrame")
  if glyphFrame and glyphFrame ~= button then
    showIf(glyphFrame, true)
  end
  local icon = rawget(button, "icon")
  if icon then
    showIf(icon, true)
  end
  return true
end

-- Brief PW1 (QA item 238 c, the owner: "it also looks like we're slightly stretching the glyph for
-- the border but unsure"). The panel button art (Assets BUTTON_UP and BUTTON_DOWN, an 80 by 22 texel
-- plate in a 128 by 32 file) was drawn whole over the button (panelButtonArt, SetAllPoints), so on a
-- labelled plate about 110 by 18 its grey ends and rim were stretched wide and squashed. The client
-- draws this art in three: UIPanelButtonNoTooltipTemplate (Blizzard_SharedXML/
-- SecureUIPanelTemplates.xml:39-86, origin/forever 1.60.1.70450) has a 12 texel left cap (TexCoords
-- 0 to 0.09375), a 12 texel right cap (0.53125 to 0.625) and the middle (0.09375 to 0.53125) stretched
-- between them, all 0 to 0.6875 tall. Its highlight is one whole texture (UIPanelButtonHighlightTexture,
-- Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:3-5), so the highlight stays whole here too.
-- The caps keep the art's own shape at the button's height, 12 * h / 22 px (the rule the client's
-- three slice buttons scale their ends by, ThreeSliceButtonMixin:UpdateScale,
-- Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.lua:27-35), which is the template's own
-- 12 px at the art's 22.
Frame.PLATE_ART_H = 22
Frame.PLATE_CAP = 12
Frame.PLATE_SLICES = {
  left = { 0, 0.09375, 0, 0.6875 },
  middle = { 0.09375, 0.53125, 0, 0.6875 },
  right = { 0.53125, 0.625, 0, 0.6875 },
}
-- The art each state's three slices are cut from.
Frame.PLATE_STATE_ASSETS = { normal = "BUTTON_UP", pushed = "BUTTON_DOWN" }

--- Brief PW1: a plate's end cap width at height h, the art's own shape kept: 12 * h / 22, whole
--- pixels, never under 1; the art's own 12 where h is unknown. Pure.
function Frame.PlateCapWidth(h)
  h = tonumber(h)
  if not h or h <= 0 then
    return Frame.PLATE_CAP
  end
  return math.max(1, math.floor(Frame.PLATE_CAP * h / Frame.PLATE_ART_H + 0.5))
end

do
  local function setCoords(texture, coords)
    if type(texture) ~= "table" or type(texture.SetTexCoord) ~= "function" then
      return false
    end
    return (pcall(texture.SetTexCoord, texture, coords[1], coords[2], coords[3], coords[4]))
  end

  --- Brief PW1: draws a plate button's normal and pushed art (Frame.NewPlateButton's client art) the
  --- client's way, in three slices at height h: each state's texture becomes the middle slice between
  --- a left and a right cap of Frame.PlateCapWidth(h), kept on the plate as .caps[state] so
  --- Frame.PaintPlateButton shows them with their middle. The highlight stays whole. Answers the cap
  --- width, or nil where the button has no client plate (the home made flat plate is left as it is).
  function Frame.SlicePlate(button, h)
    local art = type(button) == "table" and rawget(button, "plate") or nil
    if type(art) ~= "table" or type(button.CreateTexture) ~= "function" then
      return nil
    end
    if not h and type(button.GetHeight) == "function" then
      local ok, height = pcall(button.GetHeight, button)
      h = ok and tonumber(height) or nil
    end
    local cap = Frame.PlateCapWidth(h)
    local caps = rawget(art, "caps") or {}
    for key, asset in pairs(Frame.PLATE_STATE_ASSETS) do
      local middle = art[key]
      if type(middle) == "table" and setCoords(middle, Frame.PLATE_SLICES.middle) then
        local pair = caps[key] or {}
        local shown = true
        if type(middle.IsShown) == "function" then
          local ok, answer = pcall(middle.IsShown, middle)
          shown = not ok or answer ~= false
        end
        for _, side in ipairs({ "left", "right" }) do
          local texture = pair[side]
          if not texture then
            local ok, made = pcall(button.CreateTexture, button, nil, "BACKGROUND")
            texture = ok and made or nil
          end
          if texture and applyAsset(texture, asset) and setCoords(texture, Frame.PLATE_SLICES[side]) then
            pcall(texture.ClearAllPoints, texture)
            local point = side == "left" and "LEFT" or "RIGHT"
            pcall(texture.SetPoint, texture, "TOP" .. point, button, "TOP" .. point, 0, 0)
            pcall(texture.SetPoint, texture, "BOTTOM" .. point, button, "BOTTOM" .. point, 0, 0)
            pcall(texture.SetWidth, texture, cap)
            showIf(texture, shown)
            pair[side] = texture
          end
        end
        pcall(middle.ClearAllPoints, middle)
        pcall(middle.SetPoint, middle, "TOPLEFT", button, "TOPLEFT", cap, 0)
        pcall(middle.SetPoint, middle, "BOTTOMRIGHT", button, "BOTTOMRIGHT", -cap, 0)
        caps[key] = pair
      end
    end
    art.caps = caps
    art.cap = cap
    return cap
  end
end

--- Brief BL31: sizes a plate button to a square of the given side (PLATE_SIZE where none is
--- given) and its glyph to Frame.PlateGlyphSize of it, centred. Answers the glyph's side.
function Frame.SizePlateButton(button, side)
  if type(button) ~= "table" then
    return nil
  end
  side = tonumber(side) or Frame.PLATE_SIZE
  if type(button.SetSize) == "function" then
    pcall(button.SetSize, button, side, side)
  end
  local glyph = Frame.PlateGlyphSize(side)
  local icon = rawget(button, "icon")
  if type(icon) == "table" and type(icon.SetSize) == "function" then
    pcall(icon.SetSize, icon, glyph, glyph)
  end
  return glyph
end

--- Brief BL31, lifted from the Boss loot place row's map button (briefs BL29, BL30): a square
--- button on parent drawn as the header's dice button is, the client's red panel plate (Assets
--- BUTTON_UP, BUTTON_DOWN, BUTTON_HIGHLIGHT), or where that art will not draw the dice button's
--- own plate (the dim accent fill in a gold edge, with a hover wash UNDER the glyph), and the
--- glyph centred on it at the plate less its bevel: glyphKey, else fallbackKey, else the plate
--- alone. Full strength at rest, the plate's highlight under the pointer, the glyph always
--- shown. The button paints itself on OnMouseDown, OnMouseUp, OnEnter and OnLeave; a caller
--- that sets its own OnEnter or OnLeave calls Frame.PaintPlateButton from it. Brief BL32: the
--- plate's highlight is drawn additively (it glows, as the client's own panel button does) and
--- the glyph sits on .glyphFrame, a child frame one level above the button, so nothing the
--- button draws covers it. Returns the button with .plate (or .background, .edges and
--- .highlight), .glyphFrame, .icon and .iconKey (nil where no glyph drew), hidden; nil where
--- the client makes no frame.
function Frame.NewPlateButton(parent, glyphKey, fallbackKey, side)
  local button = newFrame("Button", nil, parent)
  if not button then
    return nil
  end
  if type(button.RegisterForClicks) == "function" then
    pcall(button.RegisterForClicks, button, "LeftButtonUp")
  end
  button.plate = panelButtonArt(button)
  if not button.plate then
    button.background = fillTexture(button, "BACKGROUND", "ITEMTREE_COLOR_BUTTON_ACCENT_DIM")
    if button.background then
      button.background:SetAllPoints(button)
    end
    button.edges = outline(button, "ITEMTREE_COLOR_BORDER_GOLD")
    -- On the BORDER layer, under the ARTWORK glyph: a wash over the glyph is what hid the zone
    -- list's bare eye under the pointer.
    button.highlight = fillTexture(button, "BORDER", "ITEMTREE_COLOR_STATE_HOVER")
    if button.highlight then
      button.highlight:SetAllPoints(button)
    end
  end
  -- Brief BL32: the glyph is drawn on its own child frame one level up, above every plate state.
  local holder = plateGlyphFrame(button)
  button.glyphFrame = holder
  local icon = type(holder.CreateTexture) == "function" and holder:CreateTexture(nil, "ARTWORK") or nil
  if icon then
    local drawn = nil
    for _, key in ipairs(Frame.PlateGlyphKeys(glyphKey, fallbackKey)) do
      if applyAsset(icon, key) then
        drawn = key
        break
      end
    end
    if drawn then
      pcall(icon.SetPoint, icon, "CENTER", button, "CENTER", 0, 0)
      button.icon = icon
      button.iconKey = drawn
    else
      showIf(icon, false)
    end
  end
  Frame.SizePlateButton(button, side)
  Frame.PaintPlateButton(button, "normal")
  if type(button.SetScript) == "function" then
    pcall(button.SetScript, button, "OnMouseDown", function(self)
      Frame.PaintPlateButton(self, "pushed")
    end)
    pcall(button.SetScript, button, "OnMouseUp", function(self)
      -- A press let go off the button leaves it at rest, not pushed and not lit.
      local over = true
      if type(self.IsMouseOver) == "function" then
        local ok, answer = pcall(self.IsMouseOver, self)
        if ok and answer == false then
          over = false
        end
      end
      Frame.PaintPlateButton(self, over and "hover" or "normal")
    end)
    pcall(button.SetScript, button, "OnEnter", function(self)
      Frame.PaintPlateButton(self, "hover")
    end)
    pcall(button.SetScript, button, "OnLeave", function(self)
      Frame.PaintPlateButton(self, "normal")
    end)
    -- A button hidden mid press (a list redrawn under it) comes back at rest, never pushed.
    pcall(button.SetScript, button, "OnHide", function(self)
      Frame.PaintPlateButton(self, "normal")
    end)
  end
  showIf(button, false)
  return button
end

-- The open look, while the recently viewed overlay is up: the client's own locked highlight
-- where there is one, and the home made plate's highlight texture where there is not.
local function paintHistoryButton(button, open)
  if type(button) ~= "table" then
    return false
  end
  button.open = open and true or false
  if button.panelTemplate then
    local method = open and button.LockHighlight or button.UnlockHighlight
    if type(method) == "function" then
      pcall(method, button)
    end
    return true
  end
  return paintPanelButton(button, open and "open" or "normal")
end

-- Puts the clock and the words where Frame.GlyphGroup says, and sizes the button to hold them.
-- With the words dropped it is the square the band used to carry, and the clock is centred in it
-- by Frame.SquareGlyphOffset instead, so the glyph only fallback is centred too.
local function layoutHistoryButton(button)
  if type(button) ~= "table" then
    return 0
  end
  local box = layout()
  local icon, text = button.icon, button.historyText
  local labelled = button.labelled and text ~= nil
  local measured = labelled and textWidth(text, button.historyLabel) or 0
  local glyphW = (icon and icon.glyphW) or 0
  local width = labelled and Frame.GlyphGroupWidth(measured, glyphW, box.gap, box.pad) or box.titleButton
  if width < box.titleButton then
    width = box.titleButton
  end
  button:SetSize(width, box.titleButton)
  if text then
    if labelled then
      text:Show()
    else
      text:Hide()
    end
  end
  if not labelled then
    local pad = Frame.CLOCK_PAD
    local x, y =
      Frame.SquareGlyphOffset(glyphW, Frame.BEVEL_DROP, Frame.CLOCK_RECT, pad.left, pad.right, pad.top, pad.bottom)
    if icon and type(icon.ClearAllPoints) == "function" then
      icon:ClearAllPoints()
      icon:SetPoint("CENTER", button, "CENTER", x, y)
    end
    return width
  end
  local glyphX, labelX = Frame.GlyphGroup(width, measured, glyphW, box.gap)
  if text and type(text.ClearAllPoints) == "function" then
    text:ClearAllPoints()
    text:SetPoint("CENTER", button, "CENTER", labelX, 0)
  end
  if icon and glyphX and type(icon.ClearAllPoints) == "function" then
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", button, "CENTER", glyphX, 0)
  end
  return width
end

-- Brief F1: a hover on the window's bar or footer, drawn as stacked lines rather than one long
-- one. The title (nil for none) goes on as it is; each body line is { text, colorKey } and goes on
-- with AddLine's wrap flag, which is how the Worth keeping hover wraps (brief K2), so a long line
-- folds at the tooltip's width. Every call pcall'd; answers whether the tooltip was shown. The
-- anchor is optional and defaults to ANCHOR_BOTTOMLEFT (brief S5: the search box passes its own).
local function showStackedTip(owner, title, body, anchor)
  local tooltip = rawget(_G, "GameTooltip")
  if not (tooltip and type(tooltip.SetOwner) == "function") then
    return false
  end
  if type(anchor) ~= "string" or anchor == "" then
    anchor = "ANCHOR_BOTTOMLEFT"
  end
  pcall(tooltip.SetOwner, tooltip, owner, anchor)
  if type(title) == "string" and title ~= "" then
    pcall(tooltip.AddLine, tooltip, title)
  end
  for _, line in ipairs(type(body) == "table" and body or {}) do
    if type(line) == "table" and type(line.text) == "string" and line.text ~= "" then
      local r, g, b
      if line.colorKey then
        r, g, b = themeColor(line.colorKey)
      end
      pcall(tooltip.AddLine, tooltip, line.text, r, g, b, true)
    end
  end
  pcall(tooltip.Show, tooltip)
  return true
end

-- The one line the button's tooltip carries: the label already says what the button is, so the
-- tooltip says what is in the list instead. UI/History.lua owns the wording and the function is
-- pure, so it is asked rather than copied. Answers nil where there is nothing to say.
local function historyTooltipLine()
  local Core = ItemTree.History
  local UIList = ItemTree.UI and ItemTree.UI.History
  if not (Core and type(Core.Items) == "function" and UIList and type(UIList.FooterText) == "function") then
    return nil
  end
  local clock = rawget(_G, "time")
  local now = type(clock) == "function" and clock() or nil
  local ok, items = pcall(Core.Items, now)
  if not ok or type(items) ~= "table" then
    return nil
  end
  local said, line = pcall(UIList.FooterText, items)
  if not said or type(line) ~= "string" or line == "" then
    return nil
  end
  return line
end

-- The recently viewed button on the band. The client's own panel button where it carries
-- UIPanelButtonTemplate, which both branches of the wow-ui-source mirror define, and the same
-- art drawn here where it does not. Same height as the toggles and the search box beside it.
local function buildHistoryButton(parent, onClick)
  local box = layout()
  local button, template = newFrame("Button", nil, parent, "UIPanelButtonTemplate")
  if not button then
    return nil
  end
  button.panelTemplate = template
  -- One short word on the plate (owner, brief E83); the tooltip says "Recently viewed" whenever
  -- the band is too narrow for the word.
  button.historyLabel = L["Recent"]
  button.labelled = true
  if template then
    button.historyText = child(button, "Text")
    if button.historyText and type(button.historyText.SetJustifyH) == "function" then
      pcall(button.historyText.SetJustifyH, button.historyText, "CENTER")
    end
    if type(button.SetText) == "function" then
      pcall(button.SetText, button, button.historyLabel)
    end
  else
    button.plate = panelButtonArt(button)
    if not button.plate then
      button.background = fillTexture(button, "BACKGROUND", "ITEMTREE_COLOR_BUTTON_ACCENT_DIM")
      if button.background then
        button.background:SetAllPoints(button)
      end
      button.bevel = inputBorder(button)
      if not button.bevel then
        button.edges = outline(button, "ITEMTREE_COLOR_BORDER_GOLD")
      end
    end
    button.historyText =
      newFontString(button, "ITEMTREE_FONT_BODY", "ITEMTREE_FONTSIZE_BODY_MD", "ITEMTREE_COLOR_TEXT_TITLE")
    if button.historyText then
      setText(button.historyText, button.historyLabel)
    end
  end
  local icon = type(button.CreateTexture) == "function" and button:CreateTexture(nil, "ARTWORK") or nil
  if icon then
    local side = box.titleButton - 8
    icon:SetSize(side, side)
    if applyAsset(icon, "ICON_HISTORY") then
      tintTexture(icon, "ITEMTREE_COLOR_TEXT_TITLE")
      icon.glyphW = side
      button.icon = icon
    else
      icon:Hide()
    end
  end
  layoutHistoryButton(button)
  paintHistoryButton(button, false)
  button:SetScript("OnClick", onClick)
  if not template then
    button:SetScript("OnMouseDown", function(self)
      paintPanelButton(self, "pushed")
    end)
    button:SetScript("OnMouseUp", function(self)
      paintPanelButton(self, self.open and "open" or "normal")
    end)
  end
  button:SetScript("OnEnter", function(self)
    if not self.panelTemplate then
      paintPanelButton(self, "hover")
    end
    -- The words on the plate are not said again; only what the plate cannot say is.
    local title
    if not self.labelled then
      title = L["Recently viewed"]
    end
    showStackedTip(self, title, { { text = historyTooltipLine() or L["Nothing viewed yet"] } })
  end)
  button:SetScript("OnLeave", function(self)
    if not self.panelTemplate then
      paintPanelButton(self, self.open and "open" or "normal")
    end
    local tooltip = rawget(_G, "GameTooltip")
    if tooltip and type(tooltip.Hide) == "function" then
      tooltip:Hide()
    end
  end)
  return button
end

-- Whether the dice button can be pressed, and the look that says so. A build with nothing new in
-- it has nothing to offer, so the button greys out rather than answering a press with nothing:
-- the client's own Disable where the template carries it, and the die desaturated and dimmed
-- either way, because the home made plate has no disabled art of its own. `enabled` is kept on
-- the button so the state can be read back without asking the client.
local function paintRandomButton(button, enabled)
  if type(button) ~= "table" then
    return false
  end
  enabled = enabled and true or false
  button.enabled = enabled
  local method = enabled and button.Enable or button.Disable
  if type(method) == "function" then
    pcall(method, button)
  end
  local icon = button.icon
  if icon then
    if type(icon.SetDesaturated) == "function" then
      pcall(icon.SetDesaturated, icon, not enabled)
    end
    if type(icon.SetAlpha) == "function" then
      pcall(icon.SetAlpha, icon, enabled and 1 or 0.4)
    end
  end
  return enabled
end

-- The dice button on the band, immediately left of Recently viewed: one press opens one item
-- this build added, picked at random. The same red panel button as its neighbour, drawn the same
-- two ways (the client's own UIPanelButtonTemplate where it has it, the plate drawn here where
-- it does not), square at the band's one control height, with the client's own group loot die in
-- place of a word.
--
-- On the Forever client the template is the retail shaped one, read off
-- Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml on the mirror's `forever` branch (the
-- Camelot overrides beside it touch neither the template nor its mixin): a Left, Middle and
-- Right slice of UI-DialogBox-goldbutton, swapped for the down slices on OnMouseDown and for the
-- disabled ones on OnDisable, with a ButtonText at parentKey "Text" and a highlight inset 12px
-- from each side. So the pressed, hover and disabled looks are all the template's own, which is
-- why this only has to hide the word and hand Disable the button. The word is hidden rather than
-- written over: a FontString the client made may carry no font, and nothing is ever written to
-- one here.
local function buildRandomButton(parent, onClick)
  local box = layout()
  local button, template = newFrame("Button", nil, parent, "UIPanelButtonTemplate")
  if not button then
    return nil
  end
  button.panelTemplate = template
  button:SetSize(box.titleButton, box.titleButton)
  if template then
    -- The template puts a FontString on the button and the die goes where the word would. It is
    -- given no text at all, so nothing is ever written to a font string that may have no font.
    local text = child(button, "Text")
    if text and type(text.Hide) == "function" then
      pcall(text.Hide, text)
    end
  else
    button.plate = panelButtonArt(button)
    if not button.plate then
      button.background = fillTexture(button, "BACKGROUND", "ITEMTREE_COLOR_BUTTON_ACCENT_DIM")
      if button.background then
        button.background:SetAllPoints(button)
      end
      button.bevel = inputBorder(button)
      if not button.bevel then
        button.edges = outline(button, "ITEMTREE_COLOR_BORDER_GOLD")
      end
    end
  end
  local icon = type(button.CreateTexture) == "function" and button:CreateTexture(nil, "ARTWORK") or nil
  if icon then
    -- The same side as the clock on the button beside it, and placed by the same function, so
    -- the two glyphs sit on the same line.
    local side = box.titleButton - 8
    icon:SetSize(side, side)
    if applyAsset(icon, "ICON_DICE") then
      -- Not tinted: the die is the client's own white art with its own pips, and the gold the
      -- band's monochrome glyphs take would lose them.
      local pad = Frame.DICE_PAD
      local x, y =
        Frame.SquareGlyphOffset(side, Frame.BEVEL_DROP, Frame.DICE_RECT, pad.left, pad.right, pad.top, pad.bottom)
      icon:SetPoint("CENTER", button, "CENTER", x, y)
      icon.glyphW = side
      button.icon = icon
    else
      icon:Hide()
    end
  end
  paintRandomButton(button, Frame.NewItemPoolSize() > 0)
  button:SetScript("OnClick", onClick)
  if not template then
    button:SetScript("OnMouseDown", function(self)
      if self.enabled then
        paintPanelButton(self, "pushed")
      end
    end)
    button:SetScript("OnMouseUp", function(self)
      paintPanelButton(self, "normal")
    end)
  end
  button:SetScript("OnEnter", function(self)
    if not self.panelTemplate and self.enabled then
      paintPanelButton(self, "hover")
    end
    local line = self.enabled and L["Opens one of the items this build added."]
      or L["This build has added nothing yet."]
    showStackedTip(self, L["Random new item in Forever"], { { text = line, colorKey = "ITEMTREE_COLOR_TEXT_MUTED" } })
  end)
  button:SetScript("OnLeave", function(self)
    if not self.panelTemplate then
      paintPanelButton(self, "normal")
    end
    local tooltip = rawget(_G, "GameTooltip")
    if tooltip and type(tooltip.Hide) == "function" then
      tooltip:Hide()
    end
  end)
  return button
end

--- Brief UX1 (QA item 403): the player's own class as the word the trainer search knows it by: the
--- class Core/Keep.lua Keep.PlayerClass answers (the character's own, or the pretend class of
--- "/itemtree demo class" while one is set), else UnitClass's own token. nil where the client will
--- not say. Guarded.
function Frame.PlayerClassWord()
  local Keep = ItemTree.Keep
  local classId = nil
  if type(Keep) == "table" and type(Keep.PlayerClass) == "function" then
    local ok, answer = pcall(Keep.PlayerClass)
    classId = ok and tonumber(answer) or nil
  end
  local token = nil
  if not Frame.CLASS_WORDS[classId or -1] then
    local unitClass = rawget(_G, "UnitClass")
    if type(unitClass) == "function" then
      local ok, _, file, id = pcall(unitClass, "player")
      if ok then
        token = file
        classId = classId or tonumber(id)
      end
    end
  end
  return Frame.ClassWord(classId, token)
end

--- Brief UX1: the trainer button pressed. The search box takes the player's class trainer search
--- ("t:warlock", Frame.TrainerQuery) and runs it at once, the dropdown open on the trainers, exactly
--- as a press on a kind in the "t:" list does (Frame.FillSearch, which plays the click), and the box
--- takes the focus, so the arrows, Enter and Escape work the list as if it had been typed. A class
--- the data has no trainer for still opens the search with its query. Answers the query, or nil
--- where the window has no search box. Brief AT5 (QA item 413, "If pressed again while already open
--- should close the trainer search that is open"): a press while the box holds that very query and
--- its list shows closes it instead, as Escape twice does (Frame.ClearSearch), and answers false.
function Frame.OpenClassTrainers()
  local query = Frame.TrainerQuery(Frame.PlayerClassWord())
  local box = Frame.searchBox
  local text = box and type(box.GetText) == "function" and box:GetText() or nil
  if text == query and Frame.SearchShown() then
    playCue("click")
    Frame.ClearSearch()
    return false
  end
  if not Frame.FillSearch(query) then
    return nil
  end
  if box and type(box.SetFocus) == "function" then
    pcall(box.SetFocus, box)
  end
  return query
end

-- Brief UX1 (QA item 403): the trainer button on the band, immediately left of the dice: one press
-- searches the player's class trainers (Frame.OpenClassTrainers). The dice button's own build, the
-- same red panel square at the band's control height (the client's UIPanelButtonTemplate where it
-- has it, the plate drawn here where it does not), with the client's own trainer glyph in place of
-- the die: the gossip trainer icon a player sees beside "Train me", which the window already wears
-- for its Trainer category (Assets CAT_TRAINER). It is never disabled: a class with no trainer in
-- the data still gets its search. A field rather than a local, because this file's main chunk is
-- near Lua 5.1's limit of 200 locals.
function Frame.BuildTrainerButton(parent, onClick)
  local box = layout()
  local button, template = newFrame("Button", nil, parent, "UIPanelButtonTemplate")
  if not button then
    return nil
  end
  button.panelTemplate = template
  button:SetSize(box.titleButton, box.titleButton)
  if template then
    -- As on the dice: the template's word is hidden, never written to.
    local text = child(button, "Text")
    if text and type(text.Hide) == "function" then
      pcall(text.Hide, text)
    end
  else
    button.plate = panelButtonArt(button)
    if not button.plate then
      button.background = fillTexture(button, "BACKGROUND", "ITEMTREE_COLOR_BUTTON_ACCENT_DIM")
      if button.background then
        button.background:SetAllPoints(button)
      end
      button.bevel = inputBorder(button)
      if not button.bevel then
        button.edges = outline(button, "ITEMTREE_COLOR_BORDER_GOLD")
      end
    end
  end
  local icon = type(button.CreateTexture) == "function" and button:CreateTexture(nil, "ARTWORK") or nil
  if icon then
    -- The die's side, placed by the same function, so the two glyphs sit on the same line. The
    -- gossip glyph fills its own 16 by 16 canvas, so it takes no pad of its own.
    local side = box.titleButton - 8
    icon:SetSize(side, side)
    if applyAsset(icon, "CAT_TRAINER") then
      local x, y = Frame.SquareGlyphOffset(side, Frame.BEVEL_DROP)
      icon:SetPoint("CENTER", button, "CENTER", x, y)
      icon.glyphW = side
      button.icon = icon
    else
      icon:Hide()
    end
  end
  button.enabled = true
  button:SetScript("OnClick", onClick)
  if not template then
    button:SetScript("OnMouseDown", function(self)
      paintPanelButton(self, "pushed")
    end)
    button:SetScript("OnMouseUp", function(self)
      paintPanelButton(self, "normal")
    end)
  end
  button:SetScript("OnEnter", function(self)
    if not self.panelTemplate then
      paintPanelButton(self, "hover")
    end
    local line = string.format(L["Searches %s"], Frame.TrainerQuery(Frame.PlayerClassWord()))
    showStackedTip(self, L["Find your class trainers"], { { text = line, colorKey = "ITEMTREE_COLOR_TEXT_MUTED" } })
  end)
  button:SetScript("OnLeave", function(self)
    if not self.panelTemplate then
      paintPanelButton(self, "normal")
    end
    local tooltip = rawget(_G, "GameTooltip")
    if tooltip and type(tooltip.Hide) == "function" then
      tooltip:Hide()
    end
  end)
  return button
end

-- The title bar: the drag region across the template's own title art, the round portrait and the
-- window title. The search box and the rewind button are not here any more: the template draws
-- its title tile only 21px deep, so a 24px control centred on a 28px bar hung half out of the
-- art and read as cut off. They sit on the tab row inside the body instead, where there is room
-- for them. The window title carries Graph.Title, so a spell reads as a spell and not as a key.
local function buildTitleBar(frame)
  local box = layout()
  local bar = newFrame("Frame", nil, frame)
  if not bar then
    return nil
  end
  bar:SetHeight(box.titleBar)
  bar:SetPoint("TOPLEFT", frame, "TOPLEFT", box.border, -box.titleTop)
  bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -box.border, -box.titleTop)
  bar:EnableMouse(true)
  if type(bar.RegisterForDrag) == "function" and type(frame.StartMoving) == "function" then
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function()
      frame:StartMoving()
    end)
    bar:SetScript("OnDragStop", function()
      frame:StopMovingOrSizing()
      saveWindow()
    end)
  end
  Frame.titleBar = bar

  -- The template hangs its own portrait off the frame's top left corner, so ours is anchored the
  -- same way rather than to the title bar, and both sit inside the body inset.
  Frame.portrait = templatePortrait(frame)
  if not Frame.portrait then
    local texture = type(frame.CreateTexture) == "function" and frame:CreateTexture(nil, "ARTWORK") or nil
    if texture then
      texture:SetSize(box.portrait, box.portrait)
      texture:SetPoint("TOPLEFT", frame, "TOPLEFT", box.border, -box.titleTop)
      Frame.portrait = texture
      Frame.ownPortrait = true
    end
  end

  Frame.title = templateTitle(frame)
  if not Frame.title then
    Frame.title = newFontString(bar, "ITEMTREE_FONT_BODY", "ITEMTREE_FONTSIZE_BODY_LG", "ITEMTREE_COLOR_QUALITY_COMMON")
    if Frame.title then
      -- Clear of the portrait, which reaches ITEMTREE_CHROME_PORTRAIT_INSET_X in from the left
      -- edge, and clear of the close button on the right.
      Frame.title:SetPoint("LEFT", bar, "LEFT", math.max(box.portraitX - box.border, box.pad), 0)
      Frame.title:SetPoint("RIGHT", bar, "RIGHT", -(box.titleButton + box.pad), 0)
      if type(Frame.title.SetJustifyH) == "function" then
        Frame.title:SetJustifyH("LEFT")
      end
    end
  end

  local close = child(frame, "CloseButton")
  if not close then
    close = newFrame("Button", nil, frame, "UIPanelCloseButton")
    if close then
      close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -box.titleTop, -box.titleTop)
    end
  end
  -- Brief E91: the template's own X as well as ours. The template's OnClick runs HideUIPanel,
  -- which the client refuses in combat (see Combat above), so the window would not close; this
  -- button is the window's own child and Frame.Hide is a plain Hide.
  if close and type(close.SetScript) == "function" then
    pcall(close.SetScript, close, "OnClick", function()
      Frame.Hide()
    end)
  end
  Frame.closeButton = close
  return bar
end

--------------------------------------------------------------------------------
-- The tab row search
--------------------------------------------------------------------------------

-- The name index and the creature index cost about 70 ms together to build, and every keystroke
-- after that is a scan of a list that is already sorted.
--
-- Brief P2: they are built a slice at a time once the window is first shown
-- (Frame.WarmSearchSlices), one C_Timer.After(0) a slice, so the first keystroke finds them built.
-- Brief PF3b: each slice spends the login slicer's millisecond budget (Data:SearchIndexSlice under
-- Data.PRELOAD_BUDGET_MS) rather than a count of names, and the first one waits
-- Frame.SEARCH_INDEX_DELAY seconds, a few frames, so the build never shares the frame the window
-- opened in. A search typed before the last slice finishes the build there and then
-- (Data:NameIndex), so its answer is never partial. A client with no C_Timer builds on the first
-- focus instead, as it always did.
Frame.SEARCH_INDEX_DELAY = 0.25

-- Starts the sliced build once. Answers true when a build was started by this call.
function Frame.WarmSearchSlices()
  if Frame.searchWarming or Frame.searchIndexed then
    return false
  end
  local Data = ItemTree.Data
  local timer = rawget(_G, "C_Timer")
  if not (Data and type(Data.SearchIndexSlice) == "function") then
    return false
  end
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    return false
  end
  Frame.searchWarming = true
  local function slice()
    local ok, done = pcall(Data.SearchIndexSlice, Data, Data.PRELOAD_BUDGET_MS)
    if not ok or done then
      Frame.searchWarming = false
      if ok then
        Frame.searchIndexed = true
      end
      return
    end
    if not pcall(timer.After, 0, slice) then
      Frame.searchWarming = false
    end
  end
  if not pcall(timer.After, Frame.SEARCH_INDEX_DELAY, slice) then
    Frame.searchWarming = false
    return false
  end
  return true
end

local function warmSearchIndex()
  if Frame.searchIndexed then
    return false
  end
  -- A sliced build is on its way, or has just been started: the search itself finishes it.
  if Frame.searchWarming or Frame.WarmSearchSlices() then
    return false
  end
  Frame.searchIndexed = true
  local Data = ItemTree.Data
  if Data and type(Data.NameIndex) == "function" then
    pcall(Data.NameIndex, Data)
  end
  return true
end

-- Whether the dropdown is on screen. The Escape handling turns on it, so it is asked rather
-- than remembered.
function Frame.SearchShown()
  local list = Frame.searchList
  if not (list and type(list.IsShown) == "function") then
    return false
  end
  return list:IsShown() and true or false
end

-- Whether the pointer is still inside the dropdown. A mark on a row is a child frame that takes
-- the mouse for its own hover tooltip, so the row's own OnLeave fires the moment the pointer
-- crosses onto one and the flag alone would read as "the mouse has left the list". A badge sits
-- inside the list's own rect, so the list is asked where the pointer is instead. A client that
-- will not answer IsMouseOver leaves the flag as the only word on it.
function Frame.SearchMouseOver()
  local list = Frame.searchList
  if not (list and type(list.IsMouseOver) == "function" and type(list.IsShown) == "function") then
    return false
  end
  if not list:IsShown() then
    return false
  end
  local ok, over = pcall(list.IsMouseOver, list)
  if ok and over then
    return true
  end
  return false
end

-- The item's own tooltip for one result row, so hovering a hit reads exactly what a bag slot
-- would, with ItemTree's own block appended by the hook UI/Tooltip.lua puts on the client's
-- tooltip. Brief BQ28 (owner QA 2026-10-10 item 80): its corner on the row icon's, the bag slot's
-- rule (UI/Compare.lua Compare.OwnIcon), as every item tooltip the window raises; ANCHOR_LEFT of
-- the row where Compare is not loaded. Guarded and pcall'd: a client with no GameTooltip costs the
-- row its tooltip and nothing else.
local function creatureTooltip(tooltip, row)
  if type(tooltip.SetText) ~= "function" then
    return false
  end
  if not pcall(tooltip.SetText, tooltip, row.name) then
    return false
  end
  local r, g, b = themeColor("ITEMTREE_COLOR_TEXT_MUTED")
  -- Brief S8: a trainer's title, zone and side, a line each.
  if type(row.tooltipLines) == "table" then
    for _, each in ipairs(row.tooltipLines) do
      if type(each) == "string" and each ~= "" and type(tooltip.AddLine) == "function" then
        pcall(tooltip.AddLine, tooltip, each, r, g, b)
      end
    end
    return true
  end
  local line = row.tooltipText or row.idText
  if type(line) == "string" and line ~= "" and type(tooltip.AddLine) == "function" then
    pcall(tooltip.AddLine, tooltip, line, r, g, b)
  end
  return true
end

local function showSearchTooltip(button)
  local tooltip = rawget(_G, "GameTooltip")
  local row = (Frame.searchResults or EMPTY)[button and button.rowIndex or 0]
  if not (row and button.rowKey and type(tooltip) == "table" and type(tooltip.SetOwner) == "function") then
    return false
  end
  local Compare = ItemTree.Compare
  local owned = false
  if type(Compare) == "table" and type(Compare.OwnIcon) == "function" then
    local ok, anchorType = pcall(Compare.OwnIcon, tooltip, button, rawget(button, "icon"))
    owned = ok and anchorType ~= nil
  end
  if not owned and not pcall(tooltip.SetOwner, tooltip, button, "ANCHOR_LEFT") then
    return false
  end
  -- Brief BQ25a (QA item 72): Ctrl unfolds the uses here too (UI/Tooltip.lua RedrawOnModifier).
  local tip = ItemTree.Tooltip
  if type(tip) == "table" and type(tip.RedrawOnModifier) == "function" then
    tip.RedrawOnModifier(button, showSearchTooltip, button)
  end
  -- Brief TT2 (QA item 247, Windsong Bangles): the search box holds the keyboard while the dropdown
  -- is up, so the key binding never fires over a row, and the row opens the item on any click of
  -- its own (searchRow's OnClick). The block's hint names that click alone (UI/Tooltip.lua
  -- Tooltip.SetOwnerContext, clickOnly); a creature or other kind of row has no item block.
  if type(tip) == "table" and type(tip.SetOwnerContext) == "function" then
    local context = nil
    if not row.kinded then
      context = { itemId = row.id, clickOnly = true }
    end
    pcall(tip.SetOwnerContext, button, context)
  end
  local drawn = false
  if row.kinded then
    -- A creature has no hyperlink the client will draw for it, so the tooltip is its name and the
    -- line its source rows say about it ("Beast, Wolf, level 23 to 24"), both out of our own data.
    -- A quest, a vendor, a zone, a node or a set (brief SR1) says its kind the same way.
    drawn = creatureTooltip(tooltip, row)
  elseif type(tooltip.SetItemByID) == "function" then
    drawn = pcall(tooltip.SetItemByID, tooltip, row.id)
  end
  if not drawn and not row.kinded and type(tooltip.SetHyperlink) == "function" then
    drawn = pcall(tooltip.SetHyperlink, tooltip, "item:" .. tostring(row.id))
  end
  if not drawn then
    if type(tooltip.Hide) == "function" then
      pcall(tooltip.Hide, tooltip)
    end
    return false
  end
  if type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  -- Brief BQ28: below the icon where the filled tooltip would run off the top of the screen.
  if owned then
    pcall(Compare.FitIcon, tooltip)
  end
  Frame.searchTooltip = true
  return true
end

-- Puts the client's tooltip away, and only the one this file raised: nothing else in the window
-- has its tooltip taken from under it.
local function hideSearchTooltip()
  if not Frame.searchTooltip then
    return false
  end
  Frame.searchTooltip = false
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    pcall(tooltip.Hide, tooltip)
  end
  return true
end

-- Brief E2E-1 (the e2e plan's addition 2): a result row's hover, made reachable for the developer only
-- e2e run. The row's own show and hide; nothing else changes.
function Frame.ShowSearchTooltip(button)
  return showSearchTooltip(button)
end

function Frame.HideSearchTooltip()
  return hideSearchTooltip()
end

function Frame.CloseSearch()
  Frame.searchIndex = 0
  -- Brief RB2: the item sides the open list kept.
  Frame.searchSides = {}
  -- Any keystroke still waiting out the debounce is dropped, so a search queued before the list
  -- was closed cannot drop it open again over the item that just opened.
  Frame.searchToken = (Frame.searchToken or 0) + 1
  hideSearchTooltip()
  if Frame.searchList and type(Frame.searchList.Hide) == "function" then
    Frame.searchList:Hide()
  end
  return true
end

-- Brief S5: the search box's hover hint. It hangs ABOVE the box, so it never sits over the
-- results that drop below it, and it shows only while the box is empty: hovering a box with text
-- in it shows nothing, typing puts it away, and clearing the box while the pointer is still on it
-- brings it back. Focus alone never shows it. Answers whether the hint is up.
Frame.SEARCH_TIP_ANCHOR = "ANCHOR_TOP"

function Frame.SearchBoxHasText()
  local box = Frame.searchBox
  local text = box and type(box.GetText) == "function" and box:GetText() or nil
  return type(text) == "string" and text ~= ""
end

function Frame.HideSearchBoxTip()
  if not Frame.searchBoxTip then
    return false
  end
  Frame.searchBoxTip = false
  local tooltip = rawget(_G, "GameTooltip")
  if not (type(tooltip) == "table" and type(tooltip.Hide) == "function") then
    return false
  end
  -- Only our own hint: a result row's hover may have taken the tooltip since.
  if type(tooltip.IsOwned) == "function" then
    local ok, owned = pcall(tooltip.IsOwned, tooltip, Frame.searchBox)
    if ok and owned == false then
      return false
    end
  end
  pcall(tooltip.Hide, tooltip)
  return true
end

function Frame.SyncSearchBoxTip()
  if Frame.SearchBoxHasText() then
    Frame.HideSearchBoxTip()
    return false
  end
  if not (Frame.searchBoxHover and Frame.searchBox) then
    return Frame.searchBoxTip == true
  end
  if Frame.searchBoxTip then
    return true
  end
  -- Brief S8: and how to find a trainer, in the words of the line above it.
  local shown = showStackedTip(Frame.searchBox, L["Search names, or c:1234 for an item id"], {
    { text = L["t:hunter or trainer:leatherworking for trainers"] },
    { text = L["Creatures are found by name only."], colorKey = "ITEMTREE_COLOR_TEXT_MUTED" },
  }, Frame.SEARCH_TIP_ANCHOR)
  Frame.searchBoxTip = shown == true
  return Frame.searchBoxTip
end

-- The placeholder shows only while the box is empty, and the hover hint with it.
local function updateSearchHint()
  Frame.SyncSearchBoxTip()
  local hint = Frame.searchHint
  if not hint then
    return false
  end
  local box = Frame.searchBox
  local text = box and type(box.GetText) == "function" and box:GetText() or nil
  if type(text) == "string" and text ~= "" then
    hint:Hide()
  else
    hint:Show()
  end
  return true
end

-- Writes the box without searching. The window writes the box itself in two places, after a
-- result is opened and on the second Escape, and neither may drop the dropdown open again over
-- the item that was just opened. Three things stop it: any keystroke still waiting out the
-- debounce is dropped, the OnTextChanged handler reads the client's own userInput flag, and this
-- guard is held for the write. The guard is dropped on the next frame tick rather than on the
-- next line, because a client that raises OnTextChanged after the write rather than inside it
-- would otherwise find it already gone.
local function writeSearchBox(text)
  local box = Frame.searchBox
  if not (box and type(box.SetText) == "function") then
    return false
  end
  text = type(text) == "string" and text or ""
  Frame.searchToken = (Frame.searchToken or 0) + 1
  Frame.searchQuietToken = (Frame.searchQuietToken or 0) + 1
  local token = Frame.searchQuietToken
  Frame.searchQuiet = true
  Frame.searchText = text
  local ok = pcall(box.SetText, box, text)
  updateSearchHint()
  nextTick(function()
    if Frame.searchQuietToken == token then
      Frame.searchQuiet = false
    end
  end)
  return ok
end

-- The highlight sits on one row at a time, whether the keyboard or the mouse put it there.
local function paintSearchHighlight()
  for _, button in ipairs(Frame.searchRows or EMPTY) do
    if button.highlight then
      -- A pooled row draws the result at its rowIndex, which moves as the list scrolls (SR3).
      -- Brief SR4: a "+N more" row has no key and lights up all the same, and (brief S8) so does
      -- a trainer kind the box can be filled with.
      local on = button.rowIndex == Frame.searchIndex
        and (button.rowKey ~= nil or button.rowMore ~= nil or button.rowFill ~= nil)
      if on then
        button.highlight:Show()
      else
        button.highlight:Hide()
      end
    end
  end
  return Frame.searchIndex
end

-- Puts the highlight on one row, which is what a mouse hover does. An index past the end reads
-- as none, so a stale hover cannot light a row that is no longer drawn.
function Frame.HighlightSearch(index)
  -- Brief S8: a header row or a hint line lights nothing.
  Frame.searchIndex = Frame.SearchStepRows(index, Frame.searchResults or EMPTY, 0)
  return paintSearchHighlight()
end

-- Brief N4: the rows the dropdown draws at once in the window as it stands now, out of
-- Frame.SearchRowsFor: the room is the search box's bottom edge down to the window's bottom edge,
-- each read under pcall. A window or a box that will not say where it is draws the full count.
local function edgeOf(region, getter)
  if type(region) ~= "table" or type(region[getter]) ~= "function" then
    return nil
  end
  local ok, value = pcall(region[getter], region)
  if not ok then
    return nil
  end
  return tonumber(value)
end

function Frame.SearchVisibleRows()
  local boxBottom = edgeOf(Frame.searchBox, "GetBottom")
  local windowBottom = edgeOf(Frame.frame, "GetBottom")
  if not boxBottom or not windowBottom then
    return Frame.SEARCH_VISIBLE_ROWS
  end
  return Frame.SearchRowsFor(boxBottom - windowBottom, layout().rowH)
end

-- Down and Up, wrapping. Returns where the highlight landed, and 0 with the dropdown closed.
-- The tooltip follows the keyboard, but only while the mouse is away from the list: a pointer
-- resting on one row while the arrows walk another would otherwise fight over it.
function Frame.StepSearch(delta)
  if not Frame.SearchShown() then
    return 0
  end
  local results = Frame.searchResults or EMPTY
  -- Brief S8: the arrows step over a header row and a hint line.
  Frame.searchIndex = Frame.SearchStepRows(Frame.searchIndex, results, delta)
  -- Brief SR3: the list scrolls to keep the highlight in view, wrapping included.
  local offset = Frame.SearchOffsetFor(Frame.searchIndex, Frame.searchOffset, #results, Frame.SearchVisibleRows())
  -- Brief S8: scrolling up to a group's first row brings its header into view with it.
  local above = results[Frame.searchIndex - 1]
  if type(above) == "table" and above.header and offset == Frame.searchIndex - 1 and offset > 0 then
    offset = offset - 1
  end
  if offset ~= (Frame.searchOffset or 0) then
    Frame.searchOffset = offset
    Frame.PaintSearchList(results)
  end
  local index = paintSearchHighlight()
  if not Frame.SearchMouseOver() then
    local button = (Frame.searchRows or EMPTY)[index - (Frame.searchOffset or 0)]
    if button and button.rowKey then
      showSearchTooltip(button)
    else
      hideSearchTooltip()
    end
  end
  return index
end

-- E6: the standard modified clicks on a search result. A left click with the client's dress up
-- or chat link modifier on an item goes to UI/ItemClick.lua first, and answers true when the
-- client took it (the item is on in the Dressing Room, or its link is in the chat box); the row
-- then opens nothing. Every other click, and a creature result, answers false.
function Frame.ModifiedClick(nodeKey, button)
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

-- One row in the dropdown, reused from the pool.
local function searchRow(index)
  local pool = Frame.searchRows
  if pool[index] then
    return pool[index]
  end
  local list = Frame.searchList
  if not list then
    return nil
  end
  local box = layout()
  local button = newFrame("Button", nil, list)
  if not button then
    return nil
  end
  button.rowIndex = index
  button:SetHeight(box.rowH)
  button:SetPoint("LEFT", list, "LEFT", 1, 0)
  button:SetPoint("RIGHT", list, "RIGHT", -1, 0)
  button.highlight = fillTexture(button, "BACKGROUND", "ITEMTREE_COLOR_STATE_HOVER")
  if button.highlight then
    button.highlight:SetAllPoints(button)
    button.highlight:Hide()
  end
  -- Brief S8, the owner's addendum: a header row's band and the divider hairlines along its top
  -- and bottom edges (Frame.SEARCH_HEADER_BAND and SEARCH_HEADER_LINE), shown only while the row
  -- draws a header.
  button.band = fillTexture(button, "BACKGROUND", Frame.SEARCH_HEADER_BAND, 1)
  if button.band then
    button.band:SetAllPoints(button)
    button.band:Hide()
  end
  button.topLine = fillTexture(button, "BORDER", Frame.SEARCH_HEADER_LINE, 1)
  if button.topLine then
    button.topLine:SetHeight(1)
    button.topLine:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.topLine:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    button.topLine:Hide()
  end
  button.divider = fillTexture(button, "BORDER", Frame.SEARCH_HEADER_LINE, 1)
  if button.divider then
    button.divider:SetHeight(1)
    button.divider:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    button.divider:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    button.divider:Hide()
  end
  local icon = type(button.CreateTexture) == "function" and button:CreateTexture(nil, "ARTWORK") or nil
  if icon then
    icon:SetSize(size("ITEMTREE_LIST_ICON"), size("ITEMTREE_LIST_ICON"))
    icon:SetPoint("LEFT", button, "LEFT", 4, 0)
    button.icon = icon
  end
  local cols = Frame.SearchColumns()
  button.idText =
    newFontString(button, "ITEMTREE_FONT_NUMBER", "ITEMTREE_FONTSIZE_BODY_SM", "ITEMTREE_COLOR_TEXT_MUTED")
  if button.idText then
    button.idText:SetPoint("RIGHT", button, "RIGHT", -cols.idRight, 0)
    button.idText:SetWidth(cols.id)
    clampToOneLine(button.idText, "RIGHT")
  end
  -- One cluster per pooled row, made once and reused. It sits in its own fixed width column
  -- immediately left of the id, so the marks line up down the list whether a row carries one,
  -- two or none, and a row reused for an item Core keeps nothing against is cleared rather than
  -- left pointing at the item before it. See paintSearchList.
  if Badges and type(Badges.CreateCluster) == "function" then
    local made, cluster =
      pcall(Badges.CreateCluster, button, cols.badgeSize, Frame.SEARCH_BADGE_MAX, "row", cols.badgeGap)
    if made and type(cluster) == "table" then
      button.badges = cluster
      cluster:SetPoint("RIGHT", button, "RIGHT", -cols.badgeRight, 0)
    end
  end
  button.label = newFontString(button, "ITEMTREE_FONT_BODY", "ITEMTREE_FONTSIZE_BODY_MD", "ITEMTREE_COLOR_TEXT_BODY")
  if button.label then
    button.label:SetPoint("LEFT", button, "LEFT", size("ITEMTREE_LIST_ICON") + 8, 0)
    -- Stopped at the badge column, and truncated by the client rather than run under it: the
    -- long names the beta ships were landing on top of their own id.
    button.label:SetPoint("RIGHT", button, "RIGHT", -cols.nameRight, 0)
    clampToOneLine(button.label, "LEFT")
  end
  -- The press is taken on the way down, because the edit box loses focus on the same press.
  if type(button.RegisterForClicks) == "function" then
    pcall(button.RegisterForClicks, button, "AnyDown")
  end
  button:SetScript("OnClick", function(self, mouseButton)
    -- Brief SR4: a "+N more" row opens more of its kind where it stands, and gives the search box
    -- its focus back, which the press took: the arrows, Enter and Escape keep working on the list,
    -- and a click away still closes it. A click on our own row, never on the open path (A4).
    if self.rowMore then
      Frame.ExpandSearch(self.rowMore, self.rowIndex)
      local editBox = Frame.searchBox
      if editBox and type(editBox.SetFocus) == "function" then
        pcall(editBox.SetFocus, editBox)
      end
      return
    end
    -- Brief S8: a trainer kind "t:" listed puts its words in the box and searches them, the box
    -- keeping its focus the same way.
    if self.rowFill then
      Frame.FillSearch(self.rowFill)
      local editBox = Frame.searchBox
      if editBox and type(editBox.SetFocus) == "function" then
        pcall(editBox.SetFocus, editBox)
      end
      return
    end
    if self.rowKey then
      -- E6: the dress up or chat link click on an item is the client's, and the dropdown is left
      -- as it is. See Frame.ModifiedClick.
      if Frame.ModifiedClick(self.rowKey, mouseButton) then
        return
      end
      Frame.OpenSearchResult(self.rowIndex)
    end
  end)
  -- Frame.searchHover is what keeps the dropdown open while the mouse is on it: the focus is
  -- lost on the same mouse down that lands the click, and hiding the list on that focus loss is
  -- the classic race that swallowed the click.
  button:SetScript("OnEnter", function(self)
    Frame.searchHover = true
    Frame.HighlightSearch(self.rowIndex)
    showSearchTooltip(self)
  end)
  -- A mark on this row is a child frame with the mouse of its own, so crossing onto one fires
  -- this: the list is asked where the pointer really is rather than the flag simply dropped,
  -- and the dropdown stays open under the badge and under its own hover tooltip.
  button:SetScript("OnLeave", function()
    Frame.searchHover = Frame.SearchMouseOver()
    hideSearchTooltip()
  end)
  pool[index] = button
  return button
end

-- A mark on a row is a child frame that takes the mouse for its own hover tooltip, so the row
-- under it never hears the pointer arrive and the highlight would stay on whichever row the
-- mouse was on before. Each mark is hooked once, after UI/Badges.lua has put its own scripts on
-- it: a hook runs after the script it hooks rather than instead of it, so the badge keeps its
-- tooltip and the row keeps the highlight and the flag that holds the dropdown open.
local function adoptBadgeHover(button)
  local cluster = button.badges
  local marks = type(cluster) == "table" and rawget(cluster, "badges") or nil
  if type(marks) ~= "table" then
    return false
  end
  for _, mark in ipairs(marks) do
    if type(mark) == "table" and not rawget(mark, "itemTreeSearchHover") and type(mark.HookScript) == "function" then
      mark.itemTreeSearchHover = true
      pcall(mark.HookScript, mark, "OnEnter", function()
        Frame.searchHover = true
        Frame.HighlightSearch(button.rowIndex)
      end)
      pcall(mark.HookScript, mark, "OnLeave", function()
        Frame.searchHover = Frame.SearchMouseOver()
      end)
    end
  end
  return true
end

-- Lays a pooled row out for what it is drawing (brief S7: the owner, 2026-10-03, "We are cutting
-- off the quest text very early compared to other items"): the right hand text is measured and
-- the name takes every pixel it leaves (Frame.SearchNameRight). The right hand text is put in its
-- widest column first so the client measures it whole, then narrowed to what it needs. The name
-- is only re-anchored when where it stops changes.
local function fitSearchColumns(button, row)
  local cols = Frame.SearchColumns()
  local idText = button.idText
  local measured = nil
  if idText and type(idText.SetWidth) == "function" then
    idText:SetWidth(row.kinded and cols.kind or cols.id)
    if type(idText.GetUnboundedStringWidth) == "function" then
      local ok, width = pcall(idText.GetUnboundedStringWidth, idText)
      measured = ok and tonumber(width) or nil
    end
    measured = measured or textWidth(idText, row.idText)
  end
  local nameRight, rightW = Frame.SearchNameRight(cols, row, measured)
  if idText and type(idText.SetWidth) == "function" then
    idText:SetWidth(rightW)
  end
  if button.searchNameRight == nameRight then
    return false
  end
  button.searchNameRight = nameRight
  local label = button.label
  if label and type(label.ClearAllPoints) == "function" then
    label:ClearAllPoints()
    label:SetPoint("LEFT", button, "LEFT", size("ITEMTREE_LIST_ICON") + 8, 0)
    label:SetPoint("RIGHT", button, "RIGHT", -nameRight, 0)
  end
  return true
end

-- Brief S8, the owner's addendum: a pooled row drawing a group's header shows the band and the two
-- hairlines and starts its words at the row's own pad (there is no icon before them); any other
-- row hides them, and the next row the button draws lays its name out again (fitSearchColumns).
-- A field rather than a file level local: UI/Frame.lua is at its locals guard
-- (tests/spec/ui_frame_locals_spec.lua).
function Frame.PaintSearchHeader(button, on)
  for _, part in ipairs({ button.band, button.topLine, button.divider }) do
    if on then
      part:Show()
    else
      part:Hide()
    end
  end
  local label = button.label
  if on and label and type(label.ClearAllPoints) == "function" then
    label:ClearAllPoints()
    label:SetPoint("LEFT", button, "LEFT", Frame.SEARCH_HEADER_PAD, 0)
    label:SetPoint("RIGHT", button, "RIGHT", -Frame.SEARCH_PAD, 0)
    button.searchNameRight = nil
  end
  return on
end

-- Brief BQ24 (QA item 25): the trainer search divider's "Show nearest" button, the Sources tab's
-- plate button with its words (UI/Tree.lua draws the same one on a "Sold by" header), made the
-- first time a pooled row draws a trainer divider, on the row (our own frame) and hidden on every
-- other row. The divider's words then stop short of it. Answers whether it is shown.
Frame.SEARCH_NEAREST_INSET = 3
function Frame.PaintSearchNearest(button, row)
  local held = rawget(button, "nearestButton")
  local wanted = type(row) == "table" and row.header == true and type(row.nearestKind) == "string"
  if not wanted then
    if held then
      held:Hide()
    end
    return false
  end
  if held == nil then
    local box = layout()
    held =
      Frame.NewPlateButton(button, nil, nil, math.max(10, (tonumber(box.rowH) or 20) - 2 * Frame.SEARCH_NEAREST_INSET))
    button.nearestButton = held or false
    if held then
      held.label = newFontString(
        rawget(held, "glyphFrame") or held,
        "ITEMTREE_FONT_BODY",
        "ITEMTREE_FONTSIZE_BODY_SM",
        "ITEMTREE_COLOR_TEXT_TITLE"
      )
      if held.label then
        held.label:SetPoint("CENTER", held, "CENTER", 0, 0)
      end
      if type(held.RegisterForClicks) == "function" then
        pcall(held.RegisterForClicks, held, "AnyDown")
      end
      held:SetPoint("RIGHT", button, "RIGHT", -Frame.SEARCH_PAD, 0)
      held:SetScript("OnClick", function(self)
        Frame.SearchNearestPress(rawget(self, "nearestKind"))
      end)
      -- The dropdown stays open while the pointer is on the button, as on any row of it.
      held:SetScript("OnEnter", function(self)
        Frame.searchHover = true
        Frame.PaintPlateButton(self, "hover")
        local tooltip = rawget(_G, "GameTooltip")
        if type(tooltip) == "table" and type(tooltip.SetOwner) == "function" then
          pcall(tooltip.SetOwner, tooltip, self, "ANCHOR_RIGHT")
          pcall(tooltip.AddLine, tooltip, L["Finds the nearest of these trainers and sets a waypoint."], 1, 1, 1, true)
          pcall(tooltip.Show, tooltip)
        end
      end)
      held:SetScript("OnLeave", function(self)
        Frame.searchHover = Frame.SearchMouseOver()
        Frame.PaintPlateButton(self, "normal")
        local tooltip = rawget(_G, "GameTooltip")
        if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
          pcall(tooltip.Hide, tooltip)
        end
      end)
    end
  end
  if not held then
    return false
  end
  held.nearestKind = row.nearestKind
  local label = held.label
  if label then
    setText(label, L["Show nearest"])
    local width = math.ceil(textWidth(label, L["Show nearest"]) + 2 * Frame.SEARCH_PAD)
    if type(held.SetWidth) == "function" then
      held:SetWidth(width)
    end
    local words = button.label
    if words and type(words.ClearAllPoints) == "function" then
      words:ClearAllPoints()
      words:SetPoint("LEFT", button, "LEFT", Frame.SEARCH_HEADER_PAD, 0)
      words:SetPoint("RIGHT", button, "RIGHT", -(width + 2 * Frame.SEARCH_PAD), 0)
    end
  end
  held:Show()
  return true
end

-- The slim scroll bar down the dropdown's right hand edge (brief SR3): a track, and a thumb as tall
-- as the share of the list on screen, placed at how far down it is scrolled. Hidden while every
-- row fits. Nothing to drag: the wheel and the arrow keys move the list.
local function paintSearchScroller(count, offset, visible, height)
  local list = Frame.searchList
  local track, thumb = list and list.track, list and list.thumb
  if not (track and thumb) then
    return false
  end
  local most = Frame.SearchMaxOffset(count, visible)
  if most == 0 then
    track:Hide()
    thumb:Hide()
    return false
  end
  local run = math.max(math.floor(height * visible / count + 0.5), math.floor(height / visible + 0.5))
  local drop = math.floor((height - run) * offset / most + 0.5)
  thumb:ClearAllPoints()
  thumb:SetHeight(run)
  thumb:SetPoint("TOPLEFT", track, "TOPLEFT", 0, -drop)
  thumb:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, -drop)
  track:Show()
  thumb:Show()
  return true
end

-- Draws the dropdown for the rows in hand, and hides it when there are none. Brief SR3: only
-- Frame.SEARCH_VISIBLE_ROWS of them at once, from Frame.searchOffset down; each pooled row keeps
-- the result index it draws as its rowIndex, which the highlight, the hover and the click read.
local function paintSearchList(rows)
  local list = Frame.searchList
  if not list then
    return false
  end
  local box = layout()
  local count = #rows
  local visible = Frame.SearchVisibleRows()
  local offset = Frame.SearchOffsetFor(0, Frame.searchOffset, count, visible)
  Frame.searchOffset = offset
  local scrolls = Frame.SearchMaxOffset(count, visible) > 0
  local rightInset = 1
  if scrolls then
    rightInset = 1 + Frame.SEARCH_SCROLLER_W
  end
  local shown = 0
  for slot = 1, math.min(count - offset, visible) do
    local index = offset + slot
    local row = rows[index]
    local button = searchRow(slot)
    if button then
      shown = slot
      button.rowIndex = index
      setText(button.label, Frame.SearchNameText(row))
      setTextColour(button.label, row.colourKey)
      setText(button.idText, row.idText)
      fitSearchColumns(button, row)
      Frame.PaintSearchHeader(button, row.header == true)
      -- Brief BQ24: a trainer divider's "Show nearest".
      Frame.PaintSearchNearest(button, row)
      if button.icon then
        if row.iconFile ~= nil and type(button.icon.SetTexture) == "function" then
          -- A set wears its piece's own icon (brief SR1), uncropped like an item's.
          button.icon:SetTexture(row.iconFile)
          if type(button.icon.SetTexCoord) == "function" then
            pcall(button.icon.SetTexCoord, button.icon, 0, 1, 0, 1)
          end
          button.icon:Show()
        elseif row.kinded then
          -- The glyph the creature's (or the page's) rows wear in the tree, through Assets like
          -- every texture.
          if row.asset and applyAsset(button.icon, row.asset) then
            button.icon:Show()
          else
            button.icon:Hide()
          end
        else
          local icon = nil
          if Assets and type(Assets.ItemIcon) == "function" then
            local ok, value = pcall(Assets.ItemIcon, row.id)
            icon = ok and value or nil
          end
          if icon and type(button.icon.SetTexture) == "function" then
            button.icon:SetTexture(icon)
            -- A pooled row that last drew a creature may have had its glyph cropped by Assets.
            if type(button.icon.SetTexCoord) == "function" then
              pcall(button.icon.SetTexCoord, button.icon, 0, 1, 0, 1)
            end
            button.icon:Show()
          else
            button.icon:Hide()
          end
        end
      end
      -- The subject first, so a mark made by SetKinds inherits it, then the kinds. A row with
      -- no marks is cleared both ways, which is what takes the mouse back off a pooled mark.
      -- A creature row (or any other page's) is no item, so its cluster has no subject at all.
      if button.badges then
        if type(button.badges.SetSubject) == "function" then
          if row.kinded then
            pcall(button.badges.SetSubject, button.badges, nil, nil)
          else
            pcall(button.badges.SetSubject, button.badges, "items", row.id)
          end
        end
        if type(button.badges.SetKinds) == "function" then
          pcall(button.badges.SetKinds, button.badges, row.badges or EMPTY)
        end
        adoptBadgeHover(button)
      end
      button.rowKey = row.key
      button.rowMore = row.more
      button.rowFill = row.fill
      button:ClearAllPoints()
      button:SetPoint("LEFT", list, "LEFT", 1, 0)
      button:SetPoint("RIGHT", list, "RIGHT", -rightInset, 0)
      button:SetPoint("TOP", list, "TOP", 0, -(1 + (slot - 1) * box.rowH))
      button:Show()
    end
  end
  for index = shown + 1, #Frame.searchRows do
    local spare = Frame.searchRows[index]
    spare.rowKey = nil
    spare.rowMore = nil
    spare.rowFill = nil
    if spare.badges then
      if type(spare.badges.SetKinds) == "function" then
        pcall(spare.badges.SetKinds, spare.badges, EMPTY)
      end
      if type(spare.badges.SetSubject) == "function" then
        pcall(spare.badges.SetSubject, spare.badges, nil, nil)
      end
    end
    spare:Hide()
  end
  if shown == 0 then
    Frame.CloseSearch()
    return false
  end
  list:SetHeight(shown * box.rowH + 2)
  paintSearchScroller(count, offset, visible, shown * box.rowH)
  list:Show()
  if type(list.Raise) == "function" then
    pcall(list.Raise, list)
  end
  paintSearchHighlight()
  return true
end

-- The position of the row whose page is key in a dropdown's rows, or nil. Pure.
function Frame.SearchRowFor(rows, key)
  if type(key) ~= "string" then
    return nil
  end
  for index, row in ipairs(type(rows) == "table" and rows or EMPTY) do
    if type(row) == "table" and row.key == key and not row.header then
      return index
    end
  end
  return nil
end

-- Brief BQ24: the press. The nearest trainer is found (Frame.SearchFindNearest) and the search is
-- drawn again on the same text, with every kind shown as far as it was, that trainer first and
-- marked, from the top. Brief BQ25b (owner QA 2026-10-10 item 53): the press then OPENS that
-- trainer's page on its Map tab, exactly as a click on its row does (Frame.OpenSearchResult), the
-- waypoint and the chat line kept. Where nothing was found the list stays up with the box focused.
-- Answers what the find said, or nil.
function Frame.SearchNearestPress(kind)
  local text = Frame.searchShownText
  if type(kind) ~= "string" or type(text) ~= "string" or text == "" then
    return nil
  end
  local found = Frame.SearchFindNearest(kind)
  local more = type(Frame.searchMore) == "table" and Frame.searchMore or {}
  Frame.searchResults = Frame.SearchHeaders(Frame.SearchModel(Frame.SearchAll(text, nil, nil, more)))
  Frame.searchIndex = 0
  Frame.searchOffset = 0
  hideSearchTooltip()
  local key = type(found) == "table" and found.key or nil
  local at = Frame.SearchRowFor(Frame.searchResults, key)
  if at then
    Frame.OpenSearchResult(at)
    return found
  end
  playCue("click")
  paintSearchList(Frame.searchResults)
  if type(key) == "string" then
    Frame.CloseSearch()
    Frame.OpenPicked(key, { restore = false, trainer = true })
    return found
  end
  local editBox = Frame.searchBox
  if editBox and type(editBox.SetFocus) == "function" then
    pcall(editBox.SetFocus, editBox)
  end
  return found
end

-- Runs the search and redraws the dropdown. Returns the row models, so a caller that wants the
-- first result does not have to look inside the frames.
function Frame.RunSearch(text)
  -- Brief SR4: a new search starts with every kind shown to its first screen again.
  Frame.searchMore = {}
  Frame.searchShownText = text
  -- The limit follows the setting (brief SR2): Frame.SearchAll picks it. Brief S8: each kind's rows
  -- under a header row where there are two kinds or more (Frame.SearchHeaders).
  Frame.searchResults = Frame.SearchHeaders(Frame.SearchModel(Frame.SearchAll(text, nil, nil, Frame.searchMore)))
  Frame.searchIndex = 0
  Frame.searchOffset = 0
  paintSearchList(Frame.searchResults)
  return Frame.searchResults
end

-- Brief SR4: a press on a kind's "+N more" row (the mouse, or Enter with it highlighted). The same
-- text is searched again with that kind shown Frame.SEARCH_MORE_STEP rows further, every other row
-- where it was; the first new row takes the "+N more" row's place and the rest extend below it.
-- Brief S8, the owner's second addendum (2026-10-09: the jump to the new rows was "jarring ... just
-- leave it where it is and let the user scroll"): the list does not move. The scroll offset is
-- exactly what it was, the scroll range grows, and the highlight takes the first new row, which
-- stands where the pressed row stood and so is in view, with no scroll. index is where the row was
-- pressed; a stale one is looked up by kind. Answers whether more rows were asked for.
function Frame.ExpandSearch(kind, index)
  local text = Frame.searchShownText
  if type(kind) ~= "string" or type(text) ~= "string" or text == "" then
    return false
  end
  local rows = Frame.searchResults or EMPTY
  index = math.floor(tonumber(index) or 0)
  if not (rows[index] and rows[index].more == kind) then
    index = 0
    for at, row in ipairs(rows) do
      if row.more == kind then
        index = at
        break
      end
    end
  end
  if index < 1 then
    return false
  end
  local more = type(Frame.searchMore) == "table" and Frame.searchMore or {}
  more[kind] = (tonumber(more[kind]) or 0) + Frame.SEARCH_MORE_STEP
  Frame.searchMore = more
  rows = Frame.SearchHeaders(Frame.SearchModel(Frame.SearchAll(text, nil, nil, more)))
  Frame.searchResults = rows
  local visible = Frame.SearchVisibleRows()
  local offset = Frame.SearchOffsetFor(0, Frame.searchOffset, #rows, visible)
  Frame.searchOffset = offset
  if Frame.SearchSelectable(rows[index]) and index > offset and index <= offset + visible then
    Frame.searchIndex = index
  else
    Frame.searchIndex = 0
  end
  hideSearchTooltip()
  playCue("click")
  paintSearchList(rows)
  return true
end

-- Brief S8: a press on a trainer kind ("Leatherworking  t:lw", listed for "t:" alone): the box takes
-- its words through writeSearchBox (no queued keystroke can reopen anything) and they are searched
-- at once, the dropdown staying open on the trainers. Answers whether the box took them.
function Frame.FillSearch(text)
  if type(text) ~= "string" or text == "" or not Frame.searchBox then
    return false
  end
  writeSearchBox(text)
  local box = Frame.searchBox
  if type(box.SetCursorPosition) == "function" then
    pcall(box.SetCursorPosition, box, #text)
  end
  hideSearchTooltip()
  playCue("click")
  Frame.RunSearch(text)
  return true
end

-- Brief E2E-1 (the e2e plan's addition 3): the developer only e2e run's quiet write. The box takes
-- the words through writeSearchBox, as Frame.FillSearch does but with no click sound, and with run
-- they are searched at once, past the typing debounce. An empty text clears the box and closes the
-- dropdown. Answers whether the box took them.
function Frame.SetSearchBox(text, run)
  if not Frame.searchBox then
    return false
  end
  text = type(text) == "string" and text or ""
  writeSearchBox(text)
  hideSearchTooltip()
  if text == "" then
    Frame.CloseSearch()
    return true
  end
  if run then
    Frame.RunSearch(text)
  end
  return true
end

-- Brief AT5 (QA item 413): the search put away the way Escape twice puts it away: the dropdown
-- shut, the box emptied through writeSearchBox (no queued keystroke can reopen anything), the
-- results dropped and the focus given up. Answers whether there was a box to clear.
function Frame.ClearSearch()
  local box = Frame.searchBox
  if not box then
    return false
  end
  Frame.CloseSearch()
  writeSearchBox("")
  Frame.searchResults = {}
  if type(box.ClearFocus) == "function" then
    pcall(box.ClearFocus, box)
  end
  return true
end

-- Brief SR3: redraws the dropdown's window of rows for the results in hand, at the current offset.
-- Frame.StepSearch calls it when the highlight scrolls the list.
function Frame.PaintSearchList(rows)
  return paintSearchList(rows or Frame.searchResults or EMPTY)
end

-- Brief SR3: the mouse wheel over the dropdown, a row a notch (delta 1 is up, as the client sends
-- it). The tooltip the pointer raised belongs to the row that just scrolled away, so it goes;
-- the highlight stays on its result, drawn or not. Answers whether the list moved.
function Frame.ScrollSearch(delta)
  if not Frame.SearchShown() then
    return false
  end
  local results = Frame.searchResults or EMPTY
  local most = Frame.SearchMaxOffset(#results, Frame.SearchVisibleRows())
  local offset = (Frame.searchOffset or 0) - math.floor(tonumber(delta) or 0)
  if offset > most then
    offset = most
  end
  if offset < 0 then
    offset = 0
  end
  if offset == (Frame.searchOffset or 0) then
    return false
  end
  Frame.searchOffset = offset
  hideSearchTooltip()
  paintSearchList(results)
  return true
end

-- Opens one result, by position in the dropdown. Enter with nothing highlighted takes the first.
-- The box is left showing the item's name and the dropdown closes, so the window and the box
-- agree about what is open. A pick lands on the Tree tab whatever tab it was made from, which is
-- Frame.OpenPicked's rule and is shared with the Recently viewed panel.
function Frame.OpenSearchResult(index)
  local rows = Frame.searchResults or EMPTY
  index = math.floor(tonumber(index) or 0)
  if index < 1 or index > #rows then
    index = math.floor(tonumber(Frame.searchIndex) or 0)
  end
  if index < 1 then
    -- Brief S8: the first row that can be pressed, past a header.
    index = Frame.SearchFirstSelectable(rows)
  end
  local row = rows[index]
  if not row then
    return false
  end
  -- Brief S8: a header row and a hint line open nothing.
  if not Frame.SearchSelectable(row) then
    return false
  end
  -- Brief SR4: Enter on a "+N more" row opens more of its kind, and the dropdown stays.
  if row.more then
    return Frame.ExpandSearch(row.more, index)
  end
  -- Brief S8: Enter on a trainer kind puts its words in the box and searches them.
  if row.fill then
    return Frame.FillSearch(row.fill)
  end
  -- Brief EK1: a Classic Era creature or vendor with no page is listed and opens nothing.
  if row.key == nil and row.id == nil then
    return false
  end
  -- A pick, whether it came from the mouse on a row or from Enter on the box. The window is
  -- already up whenever the dropdown is, so the re-root that follows adds no second cue.
  playCue("click")
  Frame.CloseSearch()
  local box = Frame.searchBox
  if box then
    -- The box is left showing the item's name, and the list stays shut: writeSearchBox is the
    -- one way this file writes the box, and it drops the pending debounce and holds the guard
    -- over the write and the frame after it.
    writeSearchBox(row.name)
    if type(box.ClearFocus) == "function" then
      box:ClearFocus()
    end
  end
  Frame.CloseSearch()
  -- E61: typing a name and pressing a hit is asking for that item fresh, not asking for a page
  -- back, so the window never reopens it with the last visit's lists and scroll on it. Brief BQ24:
  -- a trainer's row opens its page on the Map tab (Frame.TrainerOpenView).
  return Frame.OpenPicked(row.key, { restore = false, trainer = row.kind == "trainer" or nil })
end

-- A keystroke. C_Timer.After holds the search back so a fast typist pays for one scan rather than
-- one per letter; a client with no C_Timer searches on the keystroke itself.
local function queueSearch(text)
  if Frame.searchQuiet then
    return false
  end
  Frame.searchText = text
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    local token = (Frame.searchToken or 0) + 1
    Frame.searchToken = token
    local ok = pcall(timer.After, Frame.SEARCH_DEBOUNCE, function()
      if Frame.searchToken == token then
        Frame.RunSearch(Frame.searchText)
      end
    end)
    if ok then
      return true
    end
  end
  Frame.RunSearch(text)
  return false
end

-- The dropdown. It is parented to the window rather than the tab row and raised into the overlay
-- strata, so it draws over every pane rather than behind them, and it is clamped to the screen so
-- a long list near the bottom edge is still readable.
local function buildSearchList(frame)
  local list = newFrame("Frame", nil, frame, "BackdropTemplate")
  if not list then
    return nil
  end
  -- Wider than the box it hangs under, by exactly the badge column: the list is right aligned
  -- with the box and clamped to the screen, so the extra room comes out of the window rather
  -- than out of the names.
  list:SetWidth(Frame.SearchColumns().width)
  list:Hide()
  if type(list.SetFrameStrata) == "function" then
    pcall(list.SetFrameStrata, list, Frame.OVERLAY_STRATA)
  end
  if type(list.SetToplevel) == "function" then
    pcall(list.SetToplevel, list, true)
  end
  if type(list.SetClampedToScreen) == "function" then
    pcall(list.SetClampedToScreen, list, true)
  end
  local level = nil
  if type(frame.GetFrameLevel) == "function" then
    local ok, value = pcall(frame.GetFrameLevel, frame)
    level = ok and tonumber(value) or nil
  end
  if level and type(list.SetFrameLevel) == "function" then
    pcall(list.SetFrameLevel, list, level + 50)
  end
  list:EnableMouse(true)
  list:SetScript("OnEnter", function()
    Frame.searchHover = true
  end)
  list:SetScript("OnLeave", function()
    Frame.searchHover = false
  end)
  local background = fillTexture(list, "BACKGROUND", "ITEMTREE_COLOR_SURFACE_TOOLTIP_OPAQUE", 1)
  if background then
    background:SetAllPoints(list)
  end
  outline(list, "ITEMTREE_COLOR_BORDER_GOLD")
  -- Brief SR3: the wheel scrolls a list longer than Frame.SEARCH_VISIBLE_ROWS, and the slim bar
  -- down the right hand edge says how far, in the chain menu's colours (UI/Chain.lua).
  if type(list.EnableMouseWheel) == "function" then
    pcall(list.EnableMouseWheel, list, true)
  end
  list:SetScript("OnMouseWheel", function(_, delta)
    Frame.ScrollSearch(delta)
  end)
  list.track = fillTexture(list, "ARTWORK", "ITEMTREE_COLOR_BORDER_DIVIDER")
  if list.track then
    list.track:SetWidth(Frame.SEARCH_SCROLLER_W)
    list.track:SetPoint("TOPRIGHT", list, "TOPRIGHT", -1, -1)
    list.track:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -1, 1)
    list.track:Hide()
  end
  list.thumb = fillTexture(list, "OVERLAY", "ITEMTREE_COLOR_BORDER_GOLD")
  if list.thumb then
    list.thumb:SetWidth(Frame.SEARCH_SCROLLER_W)
    list.thumb:Hide()
  end
  Frame.searchList = list
  Frame.searchRows = {}
  Frame.searchIndex = 0
  Frame.searchOffset = 0
  Frame.searchHover = false
  return list
end

-- Hands the tree pane its keyboard capture back, or takes it away. The pane only ever hears
-- about the mouse crossing its own edge, and the cursor can rest on it the whole time the
-- player is typing up here, so it is told to ask again whenever the box's focus moves.
local function syncTreeKeyboard()
  local tree = ItemTree.UI and ItemTree.UI.Tree
  if not (tree and type(tree.SyncKeyboardCapture) == "function") then
    return false
  end
  return (pcall(tree.SyncKeyboardCapture))
end

-- The search box and the icon buttons beside it: controls/SearchBox.jsx, which is the inset fill,
-- the search glyph and the placeholder. They live on the right of the tab strip, which is the
-- grey band under the title art, rather than on the title bar itself: the template's title art is
-- 21px deep and a 24px control on it reads as cut in half. Right to left, all at
-- box.titleButton tall: the box, the recently viewed button box.bandGap (the 8 token) left of
-- it, then the dice, the trainer button (brief UX1) and the two badge toggles UI/Frame.lua's
-- header anchors to it, each box.buttonGap (the 4 token, brief SH5: the owner halved the gap
-- between the buttons).
local function buildSearch(frame)
  local strip = Frame.tabStrip
  if not strip then
    return nil
  end
  local box = layout()
  local editBox, template = newFrame("EditBox", nil, strip, "InputBoxTemplate")
  if not editBox then
    return nil
  end
  editBox:SetSize(Frame.SEARCH_W, box.searchH)
  editBox:SetPoint("RIGHT", strip, "RIGHT", 0, 0)
  editBox:SetAutoFocus(false)
  if type(editBox.SetTextInsets) == "function" then
    editBox:SetTextInsets(20, 6, 0, 0)
  end
  local face = (Theme and Theme.fonts and Theme.fonts.ITEMTREE_FONT_BODY) or nil
  local points = (Theme and Theme.fontSizes and Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_MD) or 12
  if face and type(editBox.SetFont) == "function" then
    -- SetFont answers false rather than raising where the face will not load, and an edit box
    -- with no font raises from inside its own SetText, so the answer is read here too.
    local ok, applied = pcall(editBox.SetFont, editBox, face, points, "")
    if (not ok or applied == false) and type(editBox.SetFontObject) == "function" then
      local object = rawget(_G, "GameFontHighlightSmall") or rawget(_G, "GameFontNormalSmall")
      if object ~= nil then
        pcall(editBox.SetFontObject, editBox, object)
      end
    end
  end

  -- InputBoxTemplate already draws its own edge. Without it the design's inset panel is drawn
  -- here instead, so the box reads the same on a client that has neither.
  if not template then
    local background = fillTexture(editBox, "BACKGROUND", "ITEMTREE_COLOR_SURFACE_INSET", 1)
    if background then
      background:SetAllPoints(editBox)
    end
    outline(editBox, "ITEMTREE_COLOR_BORDER_GOLD_DIM")
  end

  local glyph = type(editBox.CreateTexture) == "function" and editBox:CreateTexture(nil, "OVERLAY") or nil
  if glyph then
    glyph:SetSize(12, 12)
    glyph:SetPoint("LEFT", editBox, "LEFT", 5, 0)
    if applyAsset(glyph, "ICON_SEARCH") then
      tintTexture(glyph, "ITEMTREE_COLOR_TEXT_MUTED")
    else
      glyph:Hide()
    end
    Frame.searchGlyph = glyph
  end

  local hint = newFontString(editBox, "ITEMTREE_FONT_BODY", "ITEMTREE_FONTSIZE_BODY_MD", "ITEMTREE_COLOR_TEXT_HINT")
  if hint then
    hint:SetPoint("LEFT", editBox, "LEFT", 20, 0)
    setText(hint, L["Search"])
    Frame.searchHint = hint
  end
  Frame.searchBox = editBox

  -- Brief S4: the box is too narrow for a longer placeholder, so hovering it says how to search
  -- by id (Core/Data.lua Data.ParseSearch) and that a creature is found by its name alone.
  -- Brief S5: it hangs above the box and only while the box is empty (Frame.SyncSearchBoxTip).
  editBox:SetScript("OnEnter", function()
    Frame.searchBoxHover = true
    Frame.searchBoxTip = false
    Frame.SyncSearchBoxTip()
  end)
  editBox:SetScript("OnLeave", function()
    Frame.searchBoxHover = false
    Frame.HideSearchBoxTip()
  end)

  -- The recently viewed button raises the list over the window. It is a real labelled button
  -- now, the clock and the words as one centred group: a bare square with a glyph in it read as
  -- decoration rather than as something to press.
  Frame.historyButton = buildHistoryButton(strip, function()
    Frame.ToggleHistory()
  end)
  if Frame.historyButton then
    Frame.historyButton:SetPoint("RIGHT", editBox, "LEFT", -box.bandGap, 0)
    Frame.historyButton.bandGapUsed = box.bandGap
  end

  -- The dice button sits immediately left of it, so the band's two red panel buttons are a pair
  -- and the two bevelled toggles stay a pair beyond them. It is a square, so it never changes
  -- width; the button on its right does, and everything left of that is anchored through it, so
  -- the whole group still slides as one when the words go.
  --
  -- One press, one small click. The cue is on the press rather than inside Frame.OpenRandomNew,
  -- because the button only exists on a window that is already up: the open it leads to is a
  -- re-root and plays nothing, so the press is never heard twice.
  Frame.randomButton = buildRandomButton(strip, function()
    playCue("click")
    Frame.OpenRandomNew()
  end)
  if Frame.randomButton then
    local anchor = Frame.historyButton or editBox
    local gap = Frame.historyButton and box.buttonGap or box.bandGap
    Frame.randomButton:SetPoint("RIGHT", anchor, "LEFT", -gap, 0)
  end

  -- Brief UX1 (QA item 403): the trainer button immediately left of the dice, the same square at the
  -- buttons' own gap, so the band's red panel buttons read as one group; the badge toggles anchor
  -- to it in turn (buildHeader). Its press plays its click through Frame.FillSearch.
  Frame.trainerButton = Frame.BuildTrainerButton(strip, function()
    Frame.OpenClassTrainers()
  end)
  if Frame.trainerButton then
    local anchor = Frame.randomButton or Frame.historyButton or editBox
    local gap = anchor == editBox and box.bandGap or box.buttonGap
    Frame.trainerButton:SetPoint("RIGHT", anchor, "LEFT", -gap, 0)
  end

  -- Brief SH5: the Share link, "Help make ItemTree better" in yellow behind its round "!", top
  -- left in the gap between the title bar and the tab row, left aligned with the tabs
  -- (Frame.ShareLinkSpot). UI/Share.lua owns it: the medallion, the words, the window it opens
  -- and the ping after an update, which hooks this window's own show and hide. It is made on the
  -- title bar, one of our own frames, so it sits above the bar's drag region. A build without
  -- that file has no link and nothing else moves.
  local shareUi = ItemTree.UI and ItemTree.UI.Share
  if type(shareUi) == "table" and type(shareUi.BuildLink) == "function" then
    local ok, link = pcall(shareUi.BuildLink, Frame.titleBar or frame, frame)
    Frame.shareLink = ok and link or nil
  end
  if Frame.shareLink then
    local x, y = Frame.ShareLinkSpot()
    Frame.shareLink:SetPoint("LEFT", frame, "TOPLEFT", x, -y)
  end

  buildSearchList(frame)
  if Frame.searchList then
    Frame.searchList:SetPoint("TOPRIGHT", editBox, "BOTTOMRIGHT", 0, -2)
  end

  -- userInput is the client's own flag: false for a write this file made, true for a keystroke.
  -- An engine that hands back nothing at all is read as a keystroke, so real typing still
  -- searches, and Frame.searchQuiet is the belt to that pair of braces.
  editBox:SetScript("OnTextChanged", function(self, userInput)
    updateSearchHint()
    if userInput == false then
      return
    end
    local text = type(self.GetText) == "function" and self:GetText() or nil
    queueSearch(type(text) == "string" and text or "")
  end)
  editBox:SetScript("OnEditFocusGained", function()
    warmSearchIndex()
    -- The tree pane takes the arrow keys while the cursor is over it, and the dropdown hangs
    -- over that pane: the pane is told to work its capture out again, so the arrows walk the
    -- results rather than the rows behind them.
    syncTreeKeyboard()
  end)
  editBox:SetScript("OnEditFocusLost", function()
    -- Not while the mouse is on the dropdown: the click that is landing took the focus away.
    -- A mark on a row is a child frame with its own mouse, so the row's OnLeave has already
    -- fired by the time the click lands on the mark: the list is asked where the pointer is as
    -- well as the flag read, and a click on a badge still reaches the row under it.
    if Frame.searchHover or Frame.SearchMouseOver() then
      return
    end
    -- Brief AT5 (QA item 413): nor while it is on the trainer button. The press landing there takes
    -- the focus first, and its OnClick decides: a second press closes the class trainer search
    -- (Frame.OpenClassTrainers), any other runs it, so it must still find the list as it was.
    local trainer = Frame.trainerButton
    if trainer and type(trainer.IsMouseOver) == "function" then
      local ok, over = pcall(trainer.IsMouseOver, trainer)
      if ok and over then
        syncTreeKeyboard()
        return
      end
    end
    Frame.CloseSearch()
    syncTreeKeyboard()
  end)
  editBox:SetScript("OnEnterPressed", function()
    Frame.OpenSearchResult(Frame.searchIndex)
  end)
  editBox:SetScript("OnEscapePressed", function(self)
    -- The first press closes the dropdown and leaves the box alone. Only the second clears the
    -- text and gives up the focus, so Escape never throws a search away in one press.
    if Frame.SearchShown() then
      Frame.CloseSearch()
      return
    end
    writeSearchBox("")
    Frame.searchResults = {}
    if type(self.ClearFocus) == "function" then
      self:ClearFocus()
    end
  end)

  -- Down and Up walk the dropdown. An edit box starts in alt arrow key mode, where a plain Up or
  -- Down is never delivered to it at all and only Alt with the arrow is, which is why the
  -- dropdown's arrows answered only some of the time: turning that mode off is what hands the
  -- box its arrows. The client's own autocomplete box reads them from OnArrowPressed, which is
  -- the script made for exactly this and is declared on both target branches; OnKeyDown is the
  -- fallback for a client carrying no such script. Only one of the two is ever wired, so one
  -- press can only move the highlight once.
  if type(editBox.SetAltArrowKeyMode) == "function" then
    pcall(editBox.SetAltArrowKeyMode, editBox, false)
  end
  local function walkResults(key)
    if key == "DOWN" then
      Frame.StepSearch(1)
      return true
    end
    if key == "UP" then
      Frame.StepSearch(-1)
      return true
    end
    return false
  end
  local function takesScript(script)
    if type(editBox.HasScript) ~= "function" then
      return true
    end
    local ok, has = pcall(editBox.HasScript, editBox, script)
    if not ok then
      return true
    end
    return has and true or false
  end
  if takesScript("OnArrowPressed") then
    editBox:SetScript("OnArrowPressed", function(_, key)
      walkResults(key)
    end)
  elseif takesScript("OnKeyDown") then
    editBox:SetScript("OnKeyDown", function(_, key)
      walkResults(key)
    end)
  end
  return editBox
end

--------------------------------------------------------------------------------
-- Tabs, tick boxes and the header
--------------------------------------------------------------------------------

-- The view strip over the body (Item chain, Used by, Sources and the rest), and the fallback top
-- tabs on a client carrying neither of the client's own top tab templates. PanelTemplates does the work
-- where the client has it; the look is drawn either way, because a plain button carries no art.
-- keepHeight is what the top tabs pass: the client's own tab never changes height when it is
-- selected and neither may the fallback, while the view tabs keep the look they had.
local function paintTab(button, active, keepHeight)
  local box = layout()
  if not keepHeight then
    button:SetHeight(active and box.tabH or (box.tabH - 2))
  end
  for _, texture in ipairs(button.edges or EMPTY) do
    tintTexture(texture, active and "ITEMTREE_COLOR_BORDER_GOLD" or "ITEMTREE_COLOR_BORDER_GOLD_DIM")
  end
  tintTexture(button.background, active and "ITEMTREE_COLOR_STATE_SELECTED" or "ITEMTREE_COLOR_SURFACE_INSET")
  if button.label then
    setTextColour(button.label, active and "ITEMTREE_COLOR_TEXT_TITLE" or "ITEMTREE_COLOR_TEXT_MUTED")
  end
end

local function buildTab(parent, name, label, onClick)
  local box = layout()
  local button = newFrame("Button", name, parent)
  if not button then
    return nil
  end
  button:SetSize(box.tabW, box.tabH)
  button.background = fillTexture(button, "BACKGROUND", "ITEMTREE_COLOR_SURFACE_INSET")
  if button.background then
    button.background:SetAllPoints(button)
  end
  button.edges = outline(button, "ITEMTREE_COLOR_BORDER_GOLD_DIM")
  button.label = newFontString(button, "ITEMTREE_FONT_BODY", "ITEMTREE_FONTSIZE_BODY_MD", "ITEMTREE_COLOR_TEXT_MUTED")
  if button.label then
    button.label:SetPoint("CENTER")
    setText(button.label, label)
  end
  button:SetScript("OnClick", onClick)
  return button
end

-- Which of the client's own top tab templates this build carries, worked out once from a throw
-- away button: CreateFrame raises on a template the client does not know, and a template that
-- exists but hands back no tab art is no use either. nil means neither, and the tabs fall back to
-- the home made buttons above. Frame.topTabTemplate is what the specs read.
local function topTabTemplate()
  if Frame.topTabTemplate ~= nil then
    if Frame.topTabTemplate == false then
      return nil
    end
    return Frame.topTabTemplate
  end
  Frame.topTabTemplate = false
  -- Parented to the window rather than to UIParent, so the one throw away button lives inside a
  -- frame that is hidden anyway.
  local parent = Frame.frame or rawget(_G, "UIParent")
  for _, template in ipairs(Frame.TAB_TEMPLATES) do
    local probe = newTemplatedFrame("Button", nil, parent, template)
    if probe then
      local usable = child(probe, "Left") ~= nil and child(probe, "Text") ~= nil
      if type(probe.Hide) == "function" then
        pcall(probe.Hide, probe)
      end
      if usable then
        Frame.topTabTemplate = template
        return template
      end
    end
  end
  return nil
end

-- The box a tab glyph is drawn in: ITEMTREE_CHROME_TAB_ICON wide, and as tall as the artwork's
-- own shape allows inside that, so a wide glyph like the chat link's chain links is drawn at its
-- own proportions rather than stretched square. Assets is the only place the shape of a piece of
-- artwork is written down, and it answers with a ratio; a key that does not crop its canvas reads
-- as square. Pure, and guarded.
local function glyphBox(key, side)
  side = tonumber(side) or 14
  local ratio = 1
  if Assets and type(Assets.Aspect) == "function" and assetEntry(key) then
    local ok, value = pcall(Assets.Aspect, key)
    if ok and tonumber(value) and tonumber(value) > 0 then
      ratio = tonumber(value)
    end
  end
  if ratio >= 1 then
    return side, math.max(1, math.floor(side / ratio + 0.5))
  end
  return math.max(1, math.floor(side * ratio + 0.5)), side
end

-- Puts the width Frame.TopTabWidth asks for on one tab, and on the art inside it.
--
-- PanelTemplates_TabResize is the client's own way of doing this and it keeps three things in
-- step: the button, the middle slice of the deselected art (Middle) and the middle slice of the
-- selected art (MiddleDisabled), which are two different textures and so two different widths
-- to get wrong. It is handed an absolute size, because the number is ours: the client sizes a
-- tab from its Text alone and knows nothing about the glyph beside it.
--
-- A client with neither that function nor those slices gets the button's own width set, which
-- is as far as this can go. Returns the width that was applied.
local function setTabWidth(button, width, middle)
  width = math.max(math.floor(tonumber(width) or 0), 1)
  local resize = rawget(_G, "PanelTemplates_TabResize")
  if button.topTab and type(resize) == "function" and pcall(resize, button, 0, width) then
    button.tabWidth = width
    return width
  end
  if type(button.SetWidth) == "function" then
    pcall(button.SetWidth, button, width)
  end
  middle = math.max(math.floor(tonumber(middle) or 0), 1)
  for _, key in ipairs({ "Middle", "MiddleDisabled" }) do
    local slice = child(button, key)
    if slice and type(slice.SetWidth) == "function" then
      pcall(slice.SetWidth, slice, middle)
    end
  end
  local highlight = child(button, "HighlightTexture")
  if highlight and type(highlight.SetWidth) == "function" then
    pcall(highlight.SetWidth, highlight, width)
  end
  button.tabWidth = width
  return width
end

-- Puts a tab's glyph and its word where Frame.GlyphGroup says, for the state the tab is in, in a
-- tab this file has just sized to hold them.
--
-- Both are anchored to the BUTTON's centre and never to each other. The glyph used to hang off
-- the FontString's LEFT, which is the edge of whatever box the client gave the FontString and
-- not the first letter of the word, and that is how it ended up against the tab's own art with
-- the word sitting centred a long way to its right. The word's own width is measured with
-- GetStringWidth, so a wide label box cannot move either object.
--
-- The width is set here and not only at build time, which is the second half of the same fault:
-- the group is centred on the button, so a button narrower than the group puts the glyph outside
-- the tab's art on the left while the word, being nearer the centre, still reads as inside. The
-- client sizes a tab from its Text alone (see Frame.TopTabWidth), so the window sets its own
-- width back every time this runs, which is every select and every deselect.
--
-- selectedTextX and deselectedTextX are the client's own hooks: PanelTemplates_SelectTab and
-- its Deselect twin re-anchor the Text from them every time the strip is painted, so they carry
-- the same x this put on the FontString and nothing moves under us. The y is whatever those two
-- functions will work out for this tab, which Frame.TabTextY answers (the top tab flip included),
-- and the glyph takes the same one so the pair stays on one line through the client's drop.
--
-- Called again whenever the selection, the word, the font or the scale changes. Returns the
-- group's width.
local function layoutTopTab(button, active)
  if type(button) ~= "table" then
    return 0
  end
  local box = layout()
  local text = button.tabText
  local icon = button.icon
  -- The word the tab is drawing, which is the short one on a narrow band (brief C2).
  local word = button.tabDrawn or button.tabLabel
  local measured = textWidth(text, word)
  local glyphW = (icon and icon.glyphW) or 0
  -- The home made fallback carries no Left and Right art, so it is only ever as wide as the
  -- group and its padding; the template's tab is that much wider again on each side.
  local sideArt = button.topTab and Frame.TAB_SIDE_ART or 0
  -- Brief BL4: a narrow band draws the tab with its glyph alone (Frame.TabWords decides, in
  -- Frame.FitBand), sized by Frame.GlyphTabWidth, and the word is hidden rather than cleared so
  -- it comes back as it was. A tab with no glyph always keeps its word.
  local glyphOnly = button.glyphOnly == true and glyphW > 0
  local gap, floor = box.gap, box.tabW
  if glyphOnly then
    measured, gap, floor = 0, 0, 0
  end
  if text then
    local method = glyphOnly and text.Hide or text.Show
    if type(method) == "function" then
      pcall(method, text)
    end
  end
  local width, middle = Frame.TopTabWidth(measured, glyphW, gap, Frame.TAB_PADDING, sideArt, floor)
  setTabWidth(button, width, middle)
  local glyphX, labelX, group = Frame.GlyphGroup(width, measured, glyphW, gap)
  button.selectedTextX, button.deselectedTextX = labelX, labelX
  -- The base offsets the client's own two functions read, left alone where the template already
  -- states them so the window follows the tab rather than overruling it.
  if tonumber(button.selectedTextY) == nil then
    button.selectedTextY = Frame.TAB_TEXT_Y.selected
  end
  if tonumber(button.deselectedTextY) == nil then
    button.deselectedTextY = Frame.TAB_TEXT_Y.deselected
  end
  -- The home made fallback has no client art to drop, so its pair sits on the button's own line.
  local y = 0
  if not button.flatText then
    y = Frame.TabTextY(button, active)
  end
  if text and type(text.ClearAllPoints) == "function" then
    -- An absolute resize hands the Text a box of its own, so the word is stopped at one line and
    -- centred in that box; both points are the button's centre, so the box cannot move it.
    clampToOneLine(text, "CENTER")
    pcall(text.ClearAllPoints, text)
    pcall(text.SetPoint, text, "CENTER", button, "CENTER", labelX, y)
  end
  if icon and glyphX and type(icon.ClearAllPoints) == "function" then
    pcall(icon.ClearAllPoints, icon)
    pcall(icon.SetPoint, icon, "CENTER", button, "CENTER", glyphX, y)
  end
  return group
end

-- The client sizes one of its own tabs itself, from the word alone, and it does it after this
-- file has sized it.
--
-- PanelTabButtonTemplate, which PanelTopTabButtonTemplate inherits, carries
-- <OnShow method="OnShow"/> and <OnEvent method="OnEvent"/>, and PanelTabButtonMixin answers both
-- with PanelTemplates_TabResize(self, parent.tabPadding, nil, parent.minTabWidth,
-- parent.maxTabWidth). With no absolute size that function sets Text's width to 0, measures the
-- string and puts textWidth + TAB_SIDES_PADDING 20 on the tab: nothing for the glyph, nothing for
-- this window's own padding and side art, and none of its floor
-- (Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua on the mirror's `forever` branch, which
-- is the Forever client's own source). The window builds its tabs while it is hidden, so that
-- handler ran on the first Show, after the build time layout, and the tabs stood at the word's
-- width until the next select painted them again. That is exactly what the owner saw: no padding
-- until a tab was clicked.
--
-- The answer is to run last rather than to stop the client running: HookScript, so the template's
-- own handler still does its work and this puts the window's width back over it. OnEvent is hooked
-- for the same reason, because the mixin registers DISPLAY_SIZE_CHANGED in its OnLoad and answers
-- it the same way. Nothing here loops: PanelTemplates_TabResize with an absolute size, which is
-- what setTabWidth hands it, fires neither script.
--
-- Answers whether either hook took, which is false for the home made fallback tab (it has no
-- client handler to run after) and for a client that will not hook.
local function hookTabResize(button)
  if not (type(button) == "table" and type(button.HookScript) == "function") then
    return false
  end
  local function relayout(self)
    layoutTopTab(self, self.tabName ~= nil and self.tabName == Frame.Tab())
  end
  local hooked = false
  for _, script in ipairs({ "OnShow", "OnEvent" }) do
    if carriesScript(button, script) and pcall(button.HookScript, button, script, relayout) then
      hooked = true
    end
  end
  return hooked
end

-- The key bound to a tab's own action, or nil, read at hover time so a key set a moment ago shows.
local function tabKeyText(tabName)
  local action = Frame.TAB_KEYS[tabName]
  local keybind = ItemTree.Keybind
  if not action or type(keybind) ~= "table" or type(keybind.KeyText) ~= "function" then
    return nil
  end
  local ok, text = pcall(keybind.KeyText, action)
  if ok and type(text) == "string" and text ~= "" then
    return text
  end
  return nil
end

-- Brief BL4: a tab drawn with its glyph alone says its word in the tooltip on hover. Hooked after
-- the template's own OnEnter (PanelTabButtonMixin hides the tooltip and shows the word only when
-- the word is truncated), so this runs last and wins; a tab that keeps its word adds nothing,
-- unless it has a key of its own to mention (brief B1, Frame.TabTooltipLines). Answers whether
-- the scripts went on.
local function hookTabTooltip(button)
  if type(button) ~= "table" then
    return false
  end
  local function onEnter(self)
    local lines = Frame.TabTooltipLines(
      self.tabName,
      self.tabLabel,
      self.glyphOnly,
      tabKeyText(self.tabName),
      rawget(self, "alert")
    )
    self.tooltipShown = nil
    if #lines == 0 then
      return
    end
    local tooltip = rawget(_G, "GameTooltip")
    if not (type(tooltip) == "table" and type(tooltip.SetOwner) == "function") then
      return
    end
    pcall(tooltip.SetOwner, tooltip, self, "ANCHOR_BOTTOM")
    if type(tooltip.AddLine) == "function" then
      for _, line in ipairs(lines) do
        if line.muted then
          local r, g, b = themeColor("ITEMTREE_COLOR_TEXT_MUTED")
          pcall(tooltip.AddLine, tooltip, line.text, r, g, b)
        else
          pcall(tooltip.AddLine, tooltip, line.text)
        end
      end
    end
    if type(tooltip.Show) == "function" then
      pcall(tooltip.Show, tooltip)
    end
    self.tooltipShown = true
  end
  local function onLeave(self)
    local tooltip = rawget(_G, "GameTooltip")
    if self.tooltipShown and type(tooltip) == "table" and type(tooltip.Hide) == "function" then
      pcall(tooltip.Hide, tooltip)
    end
    self.tooltipShown = nil
  end
  local hooked = false
  for script, handler in pairs({ OnEnter = onEnter, OnLeave = onLeave }) do
    if carriesScript(button, script) then
      if type(button.HookScript) == "function" and pcall(button.HookScript, button, script, handler) then
        hooked = true
      elseif type(button.SetScript) == "function" and pcall(button.SetScript, button, script, handler) then
        hooked = true
      end
    end
  end
  return hooked
end

-- The glyph on one top tab, sized at the artwork's own shape inside the 16px box. Returns the
-- texture and its drawn width, or nil where the client would not draw the art at all.
local function buildTabGlyph(button, iconKey)
  local box = layout()
  local icon = type(button.CreateTexture) == "function" and button:CreateTexture(nil, "OVERLAY") or nil
  if not icon then
    return nil
  end
  local wide, tall = glyphBox(iconKey, box.topTabIcon)
  if not applyAsset(icon, iconKey) then
    icon:Hide()
    return nil
  end
  -- Sized after the art is on it, never before: SetAtlas can carry the atlas's own size with it,
  -- and a glyph drawn at a size the layout was never told about is a glyph hanging off the tab.
  icon:SetSize(wide, tall)
  icon.glyphW = wide
  return icon
end

-- One top tab: the client's own tab art, its own FontString, and the glyph for the view to the
-- left of the word, the two of them laid out as one group centred in the tab by layoutTopTab.
--
-- The tab is widened for the group rather than the group squeezed into it: the client's own
-- Frame.TopTabWidth is what the tab is sized by, applied by layoutTopTab, so the tab comes out
-- the word plus the glyph plus the padding plus the 16px Left and Right art on each side, and
-- never under ITEMTREE_CHROME_TAB_W.
local function buildTopTab(parent, name, label, iconKey, onClick)
  local template = topTabTemplate()
  if not template then
    return nil
  end
  local button = newTemplatedFrame("Button", name, parent, template)
  if not button then
    return nil
  end
  button.topTab = template
  if type(button.SetText) == "function" then
    pcall(button.SetText, button, label)
  end
  button.tabText = child(button, "Text")
  button.tabLabel = label
  button.icon = buildTabGlyph(button, iconKey)
  layoutTopTab(button, false)
  hookTabResize(button)
  hookTabTooltip(button)
  button:SetScript("OnClick", onClick)
  return button
end

-- The glyph's colour, which is the tab text's own, read off the FontString rather than guessed:
-- the template gives a deselected tab GameFontNormalSmall and hands the selected one
-- GameFontHighlightSmall, so the word is gold on the tabs the player can press and white on the
-- one that is up. The glyph beside it took the muted grey and read as faint next to a gold word,
-- which is what the owner marked. Alpha is forced to 1 for the same reason.
--
-- Both glyphs are monochrome art of the client's own, so they are desaturated first and the tint
-- then lands as the colour itself rather than multiplying through whatever hue the file carries.
-- activeKey and idleKey are the Theme tokens a client that will not report a text colour falls
-- back to, which differ between the template's tabs and the home made ones because their two
-- words do.
local function tintTabGlyph(icon, active, text, activeKey, idleKey)
  if type(icon) ~= "table" then
    return false
  end
  if type(icon.SetDesaturated) == "function" then
    pcall(icon.SetDesaturated, icon, true)
  end
  if type(icon.SetAlpha) == "function" then
    pcall(icon.SetAlpha, icon, 1)
  end
  if type(text) == "table" and type(text.GetTextColor) == "function" and type(icon.SetVertexColor) == "function" then
    local ok, r, g, b = pcall(text.GetTextColor, text)
    if ok and tonumber(r) then
      icon:SetVertexColor(r, g, b, 1)
      return true
    end
  end
  local key = idleKey
  if active then
    key = activeKey
  end
  return tintTexture(icon, key, 1)
end

-- The two pairs of fallback tokens. The client's own template draws a deselected tab's word in
-- GameFontNormalSmall, which is gold, and the selected one in GameFontHighlightSmall, which is
-- near white; the home made tab is the other way about, gold when it is up and muted when it is
-- not, because it has no art to say which is which.
Frame.TAB_GLYPH_COLOURS = {
  template = { active = "ITEMTREE_COLOR_TEXT_BODY", idle = "ITEMTREE_COLOR_TEXT_TITLE" },
  flat = { active = "ITEMTREE_COLOR_TEXT_TITLE", idle = "ITEMTREE_COLOR_TEXT_MUTED" },
}

-- The selected state. The client's own template says it with its own art and never changes the
-- button's height doing it, so what is left here is the tab's width, its glyph's place and its
-- glyph's colour; the fallback buttons are drawn the way the view tabs are, minus the height
-- change.
--
-- Called for every tab on every selection change, the selected one and the deselected ones
-- alike, which is what keeps a tab that has just been deselected as wide as the group it holds.
local function paintTopTab(button, active)
  if type(button) ~= "table" then
    return false
  end
  if button.topTab then
    -- Frame.SelectTab hands the whole strip to PanelTemplates_SetTab where the client has it,
    -- which is what swaps the art and the font. A client that carries the template but not that
    -- function is told one tab at a time instead, so the art still follows the selection. Either
    -- way it happens before the layout, so the width and the glyph's colour are worked out
    -- against the state the tab has actually ended up in.
    if type(rawget(_G, "PanelTemplates_SetTab")) ~= "function" then
      local swap = rawget(_G, active and "PanelTemplates_SelectTab" or "PanelTemplates_DeselectTab")
      if type(swap) == "function" then
        pcall(swap, button)
      end
    end
    -- The client re-anchors the word on every selection change, to a line that is not the same in
    -- the two states and not the same on a top tab as on a bottom one, so the glyph is put back on
    -- that line every time, in a tab this sets back to the width the pair needs.
    layoutTopTab(button, active)
    local colours = Frame.TAB_GLYPH_COLOURS.template
    tintTabGlyph(button.icon, active, button.tabText, colours.active, colours.idle)
    return true
  end
  paintTab(button, active, true)
  layoutTopTab(button, active)
  local colours = Frame.TAB_GLYPH_COLOURS.flat
  tintTabGlyph(button.icon, active, button.tabText, colours.active, colours.idle)
  return true
end

-- The fallback tab, for a client with neither template: the home made button, with the same glyph
-- beside the same word, laid out by the same function, and a fixed height whether it is selected
-- or not. It has no client art to drop, so both its text offsets are the deselected one.
local function buildFallbackTopTab(parent, name, label, iconKey, onClick)
  local box = layout()
  local button = buildTab(parent, name, label, onClick)
  if not button then
    return nil
  end
  button:SetHeight(box.topTabH)
  button.tabText = button.label
  button.tabLabel = label
  button.flatText = true
  button.icon = buildTabGlyph(button, iconKey)
  layoutTopTab(button, false)
  hookTabTooltip(button)
  return button
end

-- Whether a pane's module is loaded, which is what decides whether an optional tab is drawn at
-- all. A module is a table with a Show: a namespace some other file has only reserved is not a
-- pane yet.
local function paneLoaded(name)
  local module = ItemTree.UI and ItemTree.UI[name]
  return type(module) == "table" and type(module.Show) == "function"
end

-- The unseen count a pane wants in brackets on its own tab, through pcall because these files
-- land in parallel: a module with no UnseenCount, or one that raises, has nothing to say and the
-- tab draws its plain word.
--
-- Memoised, because answering it walks the pane's own store and Frame.RelayoutTabs asks for
-- every tab: the answer is worked out once per pass and false is the "asked, nothing to say"
-- entry, so a tab with no count costs one table read rather than a call. Every path that can
-- change a count clears the memo first, which is what clearTabCounts is for.
local tabCounts = {}

local function clearTabCounts()
  tabCounts = {}
end

local function tabCount(name)
  local cached = tabCounts[name]
  if cached ~= nil then
    if cached == false then
      return nil
    end
    return cached
  end
  local module = ItemTree.UI and ItemTree.UI[name]
  if not (type(module) == "table" and type(module.UnseenCount) == "function") then
    tabCounts[name] = false
    return nil
  end
  local ok, count = pcall(module.UnseenCount)
  count = ok and tonumber(count) or nil
  tabCounts[name] = count or false
  return count
end

-- The bubble's disc. The client's own notification atlas first (communities-icon-notification,
-- the red disc the Communities button wears, 38 by 38 in UiTextureAtlasMember on 1.60.1.70009),
-- then the plain red indicator dot (Interface\COMMON\Indicator-Red, fileDataID 518450 in the
-- same build's manifest), then a flat red square, which is square but still reads as a badge.
local function applyBubbleArt(texture)
  if applyAsset(texture, "BUBBLE_NOTIFICATION") then
    return "atlas"
  end
  if applyAsset(texture, "BUBBLE_INDICATOR") then
    return "texture"
  end
  applyAsset(texture, "FILL_WHITE8X8")
  tintTexture(texture, "ITEMTREE_COLOR_SEMANTIC_REMOVED", 1)
  return "fill"
end

-- The tab word's font height, off the FontString itself (GetFont's second answer), or nil where
-- the client will not say.
local function labelFontHeight(button)
  local text = type(button) == "table" and button.tabText or nil
  if not (type(text) == "table" and type(text.GetFont) == "function") then
    return nil
  end
  local ok, _, height = pcall(text.GetFont, text)
  if ok and tonumber(height) and tonumber(height) > 0 then
    return tonumber(height)
  end
  return nil
end

-- Where the gem's centre goes: the drawn corner of a top tab's deselected Right slice, or the
-- button's own corner where the tab has no such slice. See Frame.BUBBLE_X. Answers the region,
-- the x and the y.
local function bubbleAnchor(button)
  local right = child(button, "Right")
  if button.isTopTab and right then
    return right, Frame.BUBBLE_X, Frame.BUBBLE_Y
  end
  return button, 0, 0
end

-- One bubble, a child of the tab so it moves and hides with it, a few levels above the tab so the
-- tab's own art, and the next tab along, never draw over it. Nothing on the tab strip or the
-- window clips its children, so the half of the gem above the tab is drawn. Built the first time
-- a tab has a count to wear. Answers nil where the client will not make the frame, and the tab
-- then goes without.
local function buildBubble(button)
  local bubble = newFrame("Frame", nil, button)
  if not bubble then
    return nil
  end
  local gem, textHeight = Frame.BubbleSize(labelFontHeight(button))
  local region, x, y = bubbleAnchor(button)
  bubble:SetPoint("CENTER", region, "TOPRIGHT", x, y)
  if type(button.GetFrameLevel) == "function" and type(bubble.SetFrameLevel) == "function" then
    local ok, level = pcall(button.GetFrameLevel, button)
    if ok and tonumber(level) then
      pcall(bubble.SetFrameLevel, bubble, tonumber(level) + 5)
    end
  end
  if type(bubble.EnableMouse) == "function" then
    pcall(bubble.EnableMouse, bubble, false)
  end
  local disc = type(bubble.CreateTexture) == "function" and bubble:CreateTexture(nil, "ARTWORK") or nil
  if disc then
    disc:SetAllPoints(bubble)
    bubble.art = applyBubbleArt(disc)
  end
  bubble.disc = disc
  -- The square the art is drawn in, so the gem inside it comes out gem wide whichever art took.
  local side = Frame.BubbleFrameSize(gem, bubble.art)
  bubble:SetSize(side, side)
  bubble.gem = gem
  local text = newFontString(bubble, "ITEMTREE_FONT_BODY", nil, "ITEMTREE_COLOR_QUALITY_COMMON")
  if text then
    -- The count is bold with a shadow under it, so it reads on the gem. The client ships no bold
    -- face, so the weight is the full outline flag, and the theme's 1px shadow goes back on after
    -- the font change, since a fallback font object brings a shadow of its own.
    local face = Theme and Theme.fonts and Theme.fonts.ITEMTREE_FONT_BODY
    local flags = (Theme and Theme.text and Theme.text.ITEMTREE_TEXT_OUTLINE_FULL) or ""
    if face and type(text.SetFont) == "function" then
      local set, applied = pcall(text.SetFont, text, face, textHeight, flags)
      if not set or applied == false then
        ensureFont(text)
      end
    end
    local shadow = Theme and Theme.text and Theme.text.ITEMTREE_TEXT_OUTLINE
    if shadow and type(text.SetShadowOffset) == "function" then
      pcall(text.SetShadowOffset, text, shadow.x, shadow.y)
      if type(text.SetShadowColor) == "function" then
        pcall(text.SetShadowColor, text, shadow.r, shadow.g, shadow.b, shadow.a)
      end
    end
    if type(text.SetJustifyH) == "function" then
      pcall(text.SetJustifyH, text, "CENTER")
    end
    if type(text.SetJustifyV) == "function" then
      pcall(text.SetJustifyV, text, "MIDDLE")
    end
    -- One line, as wide as the whole square rather than the gem, so "99+" is centred on the gem
    -- and never wraps or clips even where it runs a touch past the gem's edge.
    if type(text.SetWordWrap) == "function" then
      pcall(text.SetWordWrap, text, false)
    end
    if type(text.SetWidth) == "function" then
      pcall(text.SetWidth, text, side)
    end
    text:SetPoint("CENTER", bubble, "CENTER", 0, 0)
  end
  bubble.text = text
  bubble:Hide()
  return bubble
end

-- The bubble on one tab, from its pane's count: hidden with no count and while that tab is the
-- one showing (the player is looking at the list the count is about), shown with the count
-- otherwise. Answers what the bubble now says, "" where it is hidden.
-- Brief BQ24 (QA item 35): alert is the tab's notification (Frame.TabAlert), drawn where the tab
-- has no count: the same gem with no number on it, in the alert tint (Frame.BubbleTone).
local function updateBubble(button, count, active, alert)
  local word = Frame.BubbleText(count)
  if active then
    word = ""
    alert = nil
  end
  local bubble = button.bubble
  button.alert = alert
  if word == "" and not alert then
    if bubble then
      bubble:Hide()
    end
    button.bubbleText = ""
    return ""
  end
  if not bubble then
    bubble = buildBubble(button)
    button.bubble = bubble
    if not bubble then
      return ""
    end
  end
  Frame.BubbleTone(bubble, word == "" and alert ~= nil)
  setText(bubble.text, word)
  bubble:Show()
  button.bubbleText = word
  return word
end

-- Brief BQ24: the gem's tint. An alert gem (no count) wears Frame.ALERT_TINT, a Theme red, over
-- the same art; a count's gem its art's own colour (the flat fallback its red). Answers whether
-- the tint is the alert's.
Frame.ALERT_TINT = "ITEMTREE_COLOR_SEMANTIC_REMOVED"
function Frame.BubbleTone(bubble, alert)
  local disc = type(bubble) == "table" and bubble.disc or nil
  if not (disc and type(disc.SetVertexColor) == "function") then
    return false
  end
  if alert then
    tintTexture(disc, Frame.ALERT_TINT, 1)
    return true
  end
  if bubble.art == "fill" then
    tintTexture(disc, "ITEMTREE_COLOR_SEMANTIC_REMOVED", 1)
  else
    disc:SetVertexColor(1, 1, 1, 1)
  end
  return false
end

-- The settings the window reads its tab gates from.
local function currentSettings()
  local settings = ItemTree.db and ItemTree.db.settings
  if type(settings) == "table" then
    return settings
  end
  return nil
end

-- Puts the tabs the settings allow on the strip and takes the rest away: the buttons were all
-- built once (buildTabs), and this shows, anchors and counts the ones that are drawn now, in
-- Frame.TABS order, and hides the others. Frame.tabNames and Frame.tabs then hold only what is
-- drawn, so everything downstream (the index a click selects, the band fit, the bubbles) reads
-- the same strip the player sees. Answers the names drawn and whether the set changed.
local function applyTabSet(frame)
  local names = Frame.TabNames(Frame.tabsPresent, currentSettings())
  local wanted = {}
  for _, name in ipairs(names) do
    wanted[name] = true
  end
  local shown, drawn, previous = {}, {}, nil
  for _, button in ipairs(Frame.builtTabs or EMPTY) do
    if wanted[button.tabName] then
      if type(button.ClearAllPoints) == "function" then
        button:ClearAllPoints()
      end
      if previous then
        button:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT", button.tabSpacing or 0, 0)
      elseif Frame.tabStrip then
        button:SetPoint("BOTTOMLEFT", Frame.tabStrip, "BOTTOMLEFT", 0, 0)
      end
      if type(button.Show) == "function" then
        button:Show()
      end
      shown[#shown + 1] = button
      drawn[#drawn + 1] = button.tabName
      previous = button
    elseif type(button.Hide) == "function" then
      button:Hide()
    end
  end
  local before = table.concat(Frame.tabNames or EMPTY, ",")
  Frame.tabNames = drawn
  Frame.tabs = shown
  if frame then
    frame.Tabs = shown
  end
  local setNumTabs = rawget(_G, "PanelTemplates_SetNumTabs")
  if frame and type(setNumTabs) == "function" then
    pcall(setNumTabs, frame, #drawn)
  end
  return drawn, before ~= table.concat(drawn, ",")
end

-- The top level navigation: the Item tree and Discoveries tabs in the grey band the template
-- draws between the title art and the window's inner edge, with their bottom edge on the dark
-- surface, which is where the Macro window carries its own two. The strip also holds the title
-- row controls, which buildSearch and buildHeader hang off its right edge.
--
-- Discoveries is only drawn where UI/Discoveries.lua is loaded: Frame.TabNames is the rule, and
-- everything downstream reads Frame.tabNames rather than Frame.TABS, so a build without the file
-- has one fewer tab and no way to reach a pane that is not there.
local function buildTabs(frame)
  local box = layout()
  local strip = newFrame("Frame", nil, frame)
  if not strip then
    return nil
  end
  strip:SetHeight(box.topTabH)
  strip:SetPoint("TOPLEFT", frame, "TOPLEFT", box.topTabLeft, -box.topTabTop)
  strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -box.inner, -box.topTabTop)
  Frame.tabStrip = strip

  local present = {}
  for _, name in ipairs(Frame.TABS) do
    present[name] = paneLoaded(name)
  end
  Frame.tabsPresent = present
  -- A button for every tab whose module is loaded, whether or not its setting is on, so a
  -- setting turned on later has a button to show (Frame.SyncTabs). The tabs a setting keeps away
  -- come after every other tab in Frame.TABS, so the ones drawn keep their positions.
  local names = Frame.TabNames(present, nil, true)

  local tabs = {}
  local previous = nil
  for index, name in ipairs(names) do
    -- The cue is on the press, not in Frame.SelectTab: Frame.Build and Frame.Open both select a
    -- tab themselves, and a tab that changes because an item was opened is not a tab press.
    local onClick = function()
      playCue("tab")
      Frame.SelectTab(name)
    end
    local buttonName = Frame.FRAME_NAME .. "Tab" .. index
    local iconKey = Frame.TAB_ICONS[name]
    local word = Frame.TabLabel(L[Frame.TabWord(name)])
    local button = buildTopTab(strip, buttonName, word, iconKey, onClick)
    local spacing = 0
    if not button then
      button = buildFallbackTopTab(strip, buttonName, word, iconKey, onClick)
      spacing = 2
    end
    if button then
      button.tabName = name
      button.tabSpacing = spacing
      -- Brief C2: the word the tab falls back to on a narrow band, where it has a shorter one.
      local short = Frame.TabLabel(L[Frame.TabWord(name, true)])
      button.tabShort = short ~= word and short or nil
      if previous then
        button:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT", spacing, 0)
      else
        button:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, 0)
      end
      tabs[#tabs + 1] = button
      previous = button
    end
  end
  Frame.builtTabs = tabs
  applyTabSet(frame)
  return strip
end

-- One line of hover text on a control, in the client's own tooltip, anchored under it the way
-- every small control on this window anchors one. Guarded at both ends: a client with no
-- GameTooltip, and a control the client would not make, both leave the scripts unset rather than
-- raising. Answers whether the scripts went on.
local function attachTooltip(button, text)
  if not (type(button) == "table" and type(button.SetScript) == "function" and type(text) == "string") then
    return false
  end
  button:SetScript("OnEnter", function(self)
    local tooltip = rawget(_G, "GameTooltip")
    if not (tooltip and type(tooltip.SetOwner) == "function") then
      return
    end
    tooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    tooltip:AddLine(text)
    tooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    local tooltip = rawget(_G, "GameTooltip")
    if tooltip and type(tooltip.Hide) == "function" then
      tooltip:Hide()
    end
  end)
  return true
end

-- One New or Changed toggle: the badge in a 20px box that flips the setting through
-- Options.OnChanged, so the tooltip and every other surface follow it.
local function buildBadgeToggle(parent, kind, settingKey, tooltipKey)
  local box = layout()
  local button = newFrame("Button", nil, parent)
  if not button then
    return nil
  end
  -- The same height as the recently viewed button and the search box beside them, with the same
  -- bevelled corner border, so the four controls on the title row read as one group.
  button:SetSize(box.titleButton, box.titleButton)
  button.background = fillTexture(button, "BACKGROUND", "ITEMTREE_COLOR_SURFACE_INSET")
  if button.background then
    button.background:SetAllPoints(button)
  end
  button.bevel = inputBorder(button)
  if not button.bevel then
    button.edges = outline(button, "ITEMTREE_COLOR_BORDER_GOLD_DIM")
  end
  if Badges and type(Badges.Create) == "function" then
    local badge = Badges.Create(button, "list")
    if badge then
      -- The same offset the recently viewed button's glyph takes when it is a square, so the
      -- three controls on the band cannot drift apart: the bevel's opening is a pixel below the
      -- button's own centre, and everything drawn in these squares follows it.
      local side = (Badges and type(Badges.SizeFor) == "function" and Badges.SizeFor("list")) or 12
      local x, y = Frame.SquareGlyphOffset(side, Frame.BEVEL_DROP, side, 0, 0, 0, 0)
      badge:SetPoint("CENTER", button, "CENTER", x, y)
      if type(badge.SetKind) == "function" then
        badge:SetKind(kind)
      end
      button.badge = badge
    end
  end
  button:SetScript("OnClick", function()
    local settings = ItemTree.db and ItemTree.db.settings
    if type(settings) ~= "table" then
      return
    end
    settings[settingKey] = not settings[settingKey]
    playCue(checkCue(settings[settingKey]))
    local Options = ItemTree.Options
    if Options and type(Options.OnChanged) == "function" then
      pcall(Options.OnChanged, settingKey, settings[settingKey])
    else
      Frame.RefreshFromSettings()
    end
  end)
  attachTooltip(button, L[tooltipKey])
  button.settingKey = settingKey
  return button
end

-- A tick box: controls/Checkbox.jsx, which is the client's check box art in a 20px square with
-- the label beside it. Drawn from the two textures rather than UICheckButtonTemplate, so the same
-- code draws it on a client that does not carry the template.
local function buildCheckBox(parent, label, onClick)
  local box = layout()
  local button = newFrame("Button", nil, parent)
  if not button then
    return nil
  end
  button:SetHeight(box.toggle)
  local square = type(button.CreateTexture) == "function" and button:CreateTexture(nil, "ARTWORK") or nil
  if square then
    square:SetSize(box.toggle, box.toggle)
    square:SetPoint("LEFT", button, "LEFT", 0, 0)
    if not applyAsset(square, "CHECKBOX_UP") then
      tintTexture(square, "ITEMTREE_COLOR_SURFACE_INSET")
    end
    button.square = square
  end
  local check = type(button.CreateTexture) == "function" and button:CreateTexture(nil, "OVERLAY") or nil
  if check then
    check:SetSize(box.toggle, box.toggle)
    check:SetPoint("CENTER", square or button, "CENTER", 0, 0)
    if not applyAsset(check, "CHECKBOX_CHECK") then
      tintTexture(check, "ITEMTREE_COLOR_BORDER_GOLD")
    end
    check:Hide()
    button.check = check
  end
  button.label = newFontString(button, "ITEMTREE_FONT_BODY", "ITEMTREE_FONTSIZE_BODY_MD", "ITEMTREE_COLOR_TEXT_BODY")
  if button.label then
    button.label:SetPoint("LEFT", button, "LEFT", box.toggle + box.gap, 0)
    setText(button.label, label)
  end
  button:SetWidth(box.toggle + box.gap + textWidth(button.label, label))
  button:SetScript("OnClick", onClick)
  return button
end

local function setChecked(button, checked)
  if not (button and button.check) then
    return false
  end
  if checked then
    button.check:Show()
  else
    button.check:Hide()
  end
  return true
end

-- Brief K4: the Worth keeping switch, laid out and painted for the root the window is on. Shown
-- on an item root only; the selected segment is Keep.Override's word; each segment is as wide as
-- Frame.KeepSwitchWidths says, anchored right to left from the group's right hand end with their
-- bottoms level, so the selected one stands 2px taller the way a view tab does. Answers the value
-- drawn, or nil where the switch is hidden or was never built.
local function updateKeepSwitch()
  local group = Frame.keepSwitch
  if type(group) ~= "table" then
    return nil
  end
  local itemId = Frame.ItemId(Frame.rootKey)
  if not itemId then
    if type(group.Hide) == "function" then
      group:Hide()
    end
    return nil
  end
  local box = layout()
  local value = Frame.KeepSwitchValue(itemId)
  local segments = Frame.keepSegments or EMPTY
  local words = {}
  for index, button in ipairs(segments) do
    local word = Frame.KeepWord(Frame.KEEP_VALUES[index])
    words[index] = textWidth(button.label, word)
  end
  local labelWord = L["Keep:"]
  local total, widths = Frame.KeepSwitchWidths(textWidth(Frame.keepLabel, labelWord), words, box.pad)
  if type(group.SetWidth) == "function" then
    group:SetWidth(math.max(total, 1))
  end
  local previous = nil
  for index = #segments, 1, -1 do
    local button = segments[index]
    if type(button.SetWidth) == "function" then
      button:SetWidth(math.max(widths[index] or 0, 1))
    end
    if type(button.ClearAllPoints) == "function" then
      button:ClearAllPoints()
      if previous then
        button:SetPoint("BOTTOMRIGHT", previous, "BOTTOMLEFT", -Frame.VIEW_TAB_GAP, 0)
      else
        button:SetPoint("BOTTOMRIGHT", group, "BOTTOMRIGHT", 0, 0)
      end
    end
    paintTab(button, Frame.KEEP_VALUES[index] == value)
    previous = button
  end
  local label = Frame.keepLabel
  if label and type(label.ClearAllPoints) == "function" then
    label:ClearAllPoints()
    if previous then
      label:SetPoint("RIGHT", previous, "LEFT", -box.pad, 0)
    else
      label:SetPoint("RIGHT", group, "RIGHT", 0, 0)
    end
  end
  if type(group.Show) == "function" then
    group:Show()
  end
  Frame.keepValue = value
  return value
end

-- Brief K4: a segment pressed. Core/Keep.lua stores the word (Auto clears it), drops the item's
-- cached score and paints the bags and the tooltip again; the switch and the info column's Marked
-- line are drawn again here, and nothing else on the page moves. Answers the value now drawn.
function Frame.SetKeepOverride(value)
  local itemId = Frame.ItemId(Frame.rootKey)
  local keep = ItemTree.Keep
  if not itemId or type(keep) ~= "table" or type(keep.SetOverride) ~= "function" then
    return nil
  end
  local stored = value
  if stored == "auto" then
    stored = nil
  end
  pcall(keep.SetOverride, itemId, stored)
  local drawn = updateKeepSwitch()
  local ui = ItemTree.UI
  local InfoPanel = type(ui) == "table" and ui.InfoPanel or nil
  if type(InfoPanel) == "table" and type(InfoPanel.Refresh) == "function" then
    Frame.Guarded("InfoPanel.Refresh", InfoPanel.Refresh)
  end
  return drawn
end

-- The group's hover text in the client's own tooltip under the control. On the group and on each
-- segment, because a segment takes the pointer from the group behind it. Brief FN2 (QA item 347j):
-- the title, then a line per segment, stacked as the footer's hovers are (showStackedTip).
local function keepSwitchTip(owner)
  local title, lines = Frame.KeepSwitchTip()
  local body = {}
  for _, line in ipairs(lines) do
    body[#body + 1] = { text = line }
  end
  showStackedTip(owner, title, body)
end

local function hideTip()
  local tooltip = rawget(_G, "GameTooltip")
  if tooltip and type(tooltip.Hide) == "function" then
    pcall(tooltip.Hide, tooltip)
  end
end

-- Brief TA1 (the developer only tooltip audit): the Keep switch's hover, made reachable as the
-- search row's is, on the switch itself (Frame.keepSwitch). Answers whether there was a switch.
function Frame.ShowKeepSwitchTip()
  local group = Frame.keepSwitch
  if type(group) ~= "table" then
    return false
  end
  keepSwitchTip(group)
  return true
end

local function hoverKeepSwitch(region)
  if type(region) ~= "table" or type(region.SetScript) ~= "function" then
    return
  end
  region:SetScript("OnEnter", keepSwitchTip)
  region:SetScript("OnLeave", hideTip)
end

-- Brief K4: the switch itself, one frame on the caption row holding the label and the three
-- segments, anchored to the row's right hand end and centred on it. It is as tall as a view tab
-- (ITEMTREE_CHROME_TAB_H 24), so it stands 2px proud of the 20px row above and below, into the
-- trail's row and the gap over the body, both of which are clear at that end. Plain buttons, no
-- key binding.
local function buildKeepSwitch(host)
  local box = layout()
  local group = newFrame("Frame", nil, host)
  if not group then
    return nil
  end
  group:SetSize(1, box.tabH)
  group:SetPoint("RIGHT", host, "RIGHT", 0, 0)
  if type(group.EnableMouse) == "function" then
    pcall(group.EnableMouse, group, true)
  end
  hoverKeepSwitch(group)
  Frame.keepLabel = newFontString(group, "ITEMTREE_FONT_BODY", "ITEMTREE_FONTSIZE_BODY_MD", "ITEMTREE_COLOR_TEXT_BODY")
  setText(Frame.keepLabel, L["Keep:"])
  local segments = {}
  for index, value in ipairs(Frame.KEEP_VALUES) do
    local button = buildTab(group, nil, Frame.KeepWord(value), function()
      playCue("tab")
      Frame.SetKeepOverride(value)
    end)
    if button then
      hoverKeepSwitch(button)
      segments[index] = button
    end
  end
  Frame.keepSegments = segments
  Frame.keepSwitch = group
  if type(group.Hide) == "function" then
    group:Hide()
  end
  return group
end

-- Badge toggles on the tab row, the breadcrumb row, and the caption row with its tick box. The
-- toggles sit left of the rewind button, which sits left of the search box, so the whole cluster
-- reads right to left from the corner of the body and nothing on the row overlaps a tab.
local function buildHeader(frame)
  local box = layout()
  local strip = Frame.tabStrip or frame
  Frame.newToggle = buildBadgeToggle(strip, "new", "badgesNew", "Show New badges")
  Frame.changedToggle = buildBadgeToggle(strip, "changed", "badgesChanged", "Show Changed badges")
  if Frame.changedToggle then
    -- The buttons' own gap (box.buttonGap, brief SH5), so the toggles, the dice and the clock are
    -- evenly spaced; the search box alone keeps the wider box.bandGap.
    local anchor = Frame.trainerButton or Frame.randomButton or Frame.historyButton or Frame.searchBox
    if anchor then
      local gap = anchor == Frame.searchBox and box.bandGap or box.buttonGap
      Frame.changedToggle:SetPoint("RIGHT", anchor, "LEFT", -gap, 0)
    else
      Frame.changedToggle:SetPoint("RIGHT", strip, "RIGHT", 0, 0)
    end
  end
  if Frame.newToggle and Frame.changedToggle then
    Frame.newToggle:SetPoint("RIGHT", Frame.changedToggle, "LEFT", -box.buttonGap, 0)
  end

  local crumbs = newFrame("Frame", nil, frame)
  if crumbs then
    crumbs:SetHeight(box.crumbH)
    crumbs:SetPoint("TOPLEFT", frame, "TOPLEFT", box.inner, -box.crumbTop)
    crumbs:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -box.inner, -box.crumbTop)
    Frame.crumbBar = crumbs
    Frame.crumbButtons = {}
  end

  -- The caption row: the one diff toggle, which drives the info column's old to new values and
  -- the tree's change rows together, with Diff.Caption() beside it.
  local row = newFrame("Frame", nil, frame)
  if row then
    row:SetHeight(box.captionH)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", box.inner, -box.captionTop)
    row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -box.inner, -box.captionTop)
    Frame.captionRow = row
  end
  local host = row or frame
  Frame.diffToggle = buildCheckBox(host, L["Show classic diff"], function()
    playCue(checkCue(not Frame.showChanges))
    Frame.SetShowChanges(not Frame.showChanges)
  end)
  if Frame.diffToggle then
    Frame.diffToggle:SetPoint("LEFT", host, "LEFT", 0, 0)
  end

  local caption = newFontString(host, "ITEMTREE_FONT_BODY", "ITEMTREE_FONTSIZE_BODY_SM", "ITEMTREE_COLOR_TEXT_MUTED")
  if caption then
    if Frame.diffToggle then
      caption:SetPoint("LEFT", Frame.diffToggle, "RIGHT", box.pad, 0)
    else
      caption:SetPoint("LEFT", host, "LEFT", 0, 0)
    end
    Frame.caption = caption
  end
  buildKeepSwitch(host)
end

--------------------------------------------------------------------------------
-- The body and the footer
--------------------------------------------------------------------------------

-- The footer: the confidence legend on the left, then the Merge recipes, Total counts (brief
-- TC1) and Compact rows tick boxes and the Options button pinned to the right, all on one row
-- inside the dark surface, which is the row Frame.jsx ends on. It keeps clear of the resize grip,
-- which sits in the frame's own corner outside the surface.
--
-- The row is laid out from both ends and never wraps, so what matters is that the two ends cannot
-- meet. The right hand cluster is at its widest with both boxes ticked and every word at its
-- longest, and the left hand legend is a fixed four badges and four words: Frame.legendWidth and
-- Frame.FooterRightWidth() are what they measured, and the spec holds the pair against the least
-- the window may be resized to (Frame.MinSize), so a longer word in another locale fails a test
-- rather than overlapping the legend in the client. Since brief TC1's third tick box the legend
-- gives way to its medallions alone where its words do not fit (Frame.LayoutLegend).
local function buildFooter(frame)
  local box = layout()
  local row = newFrame("Frame", nil, frame)
  if not row then
    return nil
  end
  row:SetHeight(box.footerH)
  row:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", box.inner, box.innerBottom)
  row:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -box.inner, box.innerBottom)
  Frame.footer = row

  -- No rule along the top of this row. It ran the full width of the window a couple of pixels
  -- under the bottom borders of the three panes, and across the gaps between them, so the eye
  -- read a doubled line: each pane's own border and then this one right under it. The content
  -- area stops box.footerPad higher instead, which is the air the legend wanted. The body
  -- surface's own dim gold hairline sits further out and is untouched.

  -- badges/ConfidenceLegend.jsx: one badge and its own label per kind, left to right.
  local offset = 0
  Frame.legend = {}
  for _, kind in ipairs(Frame.LEGEND_KINDS) do
    local label = (Badges and type(Badges.Label) == "function" and Badges.Label(kind)) or kind
    local text = newFontString(row, "ITEMTREE_FONT_BODY", "ITEMTREE_FONTSIZE_BODY_SM", "ITEMTREE_COLOR_TEXT_MUTED")
    local badge = Badges and type(Badges.Create) == "function" and Badges.Create(row, "list") or nil
    local badgeSize = (Badges and type(Badges.SizeFor) == "function" and Badges.SizeFor("list")) or 12
    if badge then
      badge:SetPoint("LEFT", row, "LEFT", offset, 0)
      if type(badge.SetKind) == "function" then
        badge:SetKind(kind)
      end
      -- E48: the legend explains itself on hover too. The word beside a medallion names the
      -- mark; pointing at the medallion adds the sentence under the name, the same sentence the
      -- same mark gives on a row. Nothing sits under a legend badge for a click to reach, and
      -- UI/Badges.lua leaves the click alone where the client can separate motion from clicks.
      if type(badge.SetHoverEnabled) == "function" then
        pcall(badge.SetHoverEnabled, badge, true)
      end
      badge:Show()
    end
    if text then
      text:SetPoint("LEFT", row, "LEFT", offset + badgeSize + size("ITEMTREE_SPACE_1"), 0)
      setText(text, label)
    end
    Frame.legend[#Frame.legend + 1] = { kind = kind, badge = badge, label = text, badgeSize = badgeSize }
    -- Brief E76 tightened the row by 33: "Compact rows" is 36 wider than the "Guides" it
    -- replaced, and the row still has to fit at Frame.MinSize without raising the minimum, which
    -- every band layout is measured against. SPACE_2 between entries (was SPACE_3), SPACE_1 from
    -- a badge to its word (was 5), and no slack around the Options button below (was 12).
    offset = offset + badgeSize + size("ITEMTREE_SPACE_1") + textWidth(text, label) + size("ITEMTREE_SPACE_2")
  end
  -- What the legend actually took, without the trailing gap after the last word: the left hand
  -- half of the fit above, measured rather than guessed at.
  Frame.legendWidth = math.max(offset - size("ITEMTREE_SPACE_2"), 0)
  -- Brief TC1: and what it takes as the medallions alone, which is what it gives way to when the
  -- row is too narrow for its words (Frame.LayoutLegend).
  local badges = 0
  for _, entry in ipairs(Frame.legend) do
    badges = badges + entry.badgeSize + size("ITEMTREE_SPACE_2")
  end
  Frame.legendBadgesWidth = math.max(badges - size("ITEMTREE_SPACE_2"), 0)

  -- controls/Button.jsx, secondary variant: text only, with no plate under it, and a small gold
  -- cog to the left of the word so the button reads as settings at a glance.
  local options = newFrame("Button", nil, row)
  if options then
    local glyph = size("ITEMTREE_ICON_TOGGLE")
    local cog = type(options.CreateTexture) == "function" and options:CreateTexture(nil, "ARTWORK") or nil
    local block = 0
    if cog then
      cog:SetSize(glyph, glyph)
      if applyAsset(cog, "ICON_COG") then
        tintTexture(cog, "ITEMTREE_COLOR_TEXT_TITLE")
        block = glyph + box.gap
        Frame.optionsCog = cog
      else
        cog:Hide()
      end
    end
    options.label =
      newFontString(options, "ITEMTREE_FONT_BODY", "ITEMTREE_FONTSIZE_BODY_SM", "ITEMTREE_COLOR_TEXT_TITLE")
    if options.label then
      -- The word shifts right by half the cog's block, so the cog and the word sit centred in the
      -- button together.
      options.label:SetPoint("CENTER", options, "CENTER", block / 2, 0)
      setText(options.label, L["Options"])
    end
    if cog and Frame.optionsCog then
      if options.label then
        cog:SetPoint("RIGHT", options.label, "LEFT", -box.gap, 0)
      else
        cog:SetPoint("LEFT", options, "LEFT", box.gap, 0)
      end
    end
    -- No slack past the cog and the word: the button draws no plate (brief E76, see the legend).
    options:SetSize(textWidth(options.label, L["Options"]) + block, box.toggle)
    options:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    options:SetScript("OnClick", function()
      Frame.OpenOptions()
    end)
    Frame.optionsButton = options
  end

  -- Compact rows (brief E76, in the place the Guides box had): the same density setting the
  -- settings panel's Display row switches, "compact" ticked and "default" not. It goes through
  -- Options.OnChanged as Merge recipes does, so the tree redraws at the new row height and the
  -- settings row follows.
  Frame.compactToggle = buildCheckBox(row, L["Compact rows"], function()
    local settings = ItemTree.db and ItemTree.db.settings
    if type(settings) ~= "table" then
      return
    end
    local compact = settings.density ~= "compact"
    if compact then
      settings.density = "compact"
    else
      settings.density = "default"
    end
    playCue(checkCue(compact))
    setChecked(Frame.compactToggle, compact)
    local Options = ItemTree.Options
    if Options and type(Options.OnChanged) == "function" then
      pcall(Options.OnChanged, "density", settings.density)
    else
      Frame.RefreshFromSettings()
    end
  end)
  if Frame.compactToggle then
    if Frame.optionsButton then
      Frame.compactToggle:SetPoint("RIGHT", Frame.optionsButton, "LEFT", -box.pad, 0)
    else
      Frame.compactToggle:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    end
  end

  -- Brief TC1: Total counts, between Merge recipes and Compact rows at the same gap. Off by default
  -- (settings.totalCounts), and like Merge recipes it changes what the rows say, so the click goes
  -- through Options.OnChanged and the tree redraws with the root, the view and the scroll kept.
  Frame.totalsToggle = buildCheckBox(row, L["Total counts"], function()
    local settings = ItemTree.db and ItemTree.db.settings
    if type(settings) ~= "table" then
      return
    end
    settings.totalCounts = settings.totalCounts ~= true
    playCue(checkCue(settings.totalCounts))
    setChecked(Frame.totalsToggle, settings.totalCounts)
    local Options = ItemTree.Options
    if Options and type(Options.OnChanged) == "function" then
      pcall(Options.OnChanged, "totalCounts", settings.totalCounts)
    else
      Frame.RefreshFromSettings()
    end
  end)
  if Frame.totalsToggle then
    Frame.totalsToggle:SetScript("OnEnter", function(self)
      local title, lines = Frame.TotalsToggleTip()
      local body = {}
      for _, line in ipairs(lines) do
        body[#body + 1] = { text = line }
      end
      showStackedTip(self, title, body)
    end)
    Frame.totalsToggle:SetScript("OnLeave", hideTip)
    local anchor = Frame.compactToggle or Frame.optionsButton
    if anchor then
      Frame.totalsToggle:SetPoint("RIGHT", anchor, "LEFT", -box.pad, 0)
    else
      Frame.totalsToggle:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    end
  end

  -- The second tick box, left of Total counts (brief TC1; left of Compact rows before it) at the
  -- same gap that keeps from the Options button.
  -- It is the one setting on this row that changes what the tree lists rather than how it is drawn,
  -- so the click rebuilds the model's options and redraws, which is what the Show predicted and
  -- Show classic diff toggles do; the root, the view and every pane's scroll stay where they are.
  Frame.mergeToggle = buildCheckBox(row, L["Merge recipes"], function()
    local settings = ItemTree.db and ItemTree.db.settings
    if type(settings) ~= "table" then
      return
    end
    settings.mergeCrafts = not mergeCraftsOn(settings)
    playCue(checkCue(settings.mergeCrafts))
    setChecked(Frame.mergeToggle, settings.mergeCrafts)
    local Options = ItemTree.Options
    if Options and type(Options.OnChanged) == "function" then
      pcall(Options.OnChanged, "mergeCrafts", settings.mergeCrafts)
    else
      Frame.RefreshFromSettings()
    end
  end)
  if Frame.mergeToggle then
    -- Brief F1: the title, then one wrapped line per sentence, wrapped the way the Worth keeping
    -- hover wraps (brief K2: AddLine's wrap flag), rather than one line across the screen.
    Frame.mergeToggle:SetScript("OnEnter", function(self)
      local title, lines = Frame.MergeToggleTip()
      local body = {}
      for _, line in ipairs(lines) do
        body[#body + 1] = { text = line }
      end
      showStackedTip(self, title, body)
    end)
    Frame.mergeToggle:SetScript("OnLeave", hideTip)
    local anchor = Frame.totalsToggle or Frame.compactToggle or Frame.optionsButton
    if anchor then
      Frame.mergeToggle:SetPoint("RIGHT", anchor, "LEFT", -box.pad, 0)
    else
      Frame.mergeToggle:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    end
  end
  -- Brief TC1: the third tick box made the right hand end wider than the row has room for beside
  -- the whole legend at Frame.MinSize, so the legend gives way: below the width it needs, its
  -- words go and the medallions close up, each still naming itself on hover (E48). The row is
  -- the window's own frame, so the script is ours to set; it runs again on every resize.
  if type(row.SetScript) == "function" then
    row:SetScript("OnSizeChanged", function(self, width)
      Frame.LayoutLegend(width or (type(self.GetWidth) == "function" and self:GetWidth()) or nil)
    end)
  end
  Frame.LayoutLegend(type(row.GetWidth) == "function" and row:GetWidth() or nil)
  return row
end

-- Brief TC1: whether the legend keeps its words in a footer row this wide: the whole legend, the
-- ITEMTREE_SPACE_3 the fit has always kept between the two ends, and the right hand controls. A
-- width not known yet keeps the words, which is the row as it was drawn before this existed. Pure.
function Frame.LegendWords(rowWidth, legendWidth, rightWidth, gap)
  local width = tonumber(rowWidth)
  if not width or width <= 0 then
    return true
  end
  return (tonumber(legendWidth) or 0) + (tonumber(gap) or 0) + (tonumber(rightWidth) or 0) <= width
end

-- Lays the legend out for a footer row this wide: the badge and its word per entry where the
-- words fit (Frame.LegendWords), else the badges alone at ITEMTREE_SPACE_2 apart. Answers whether
-- the words are shown, or nil where the legend was never built.
function Frame.LayoutLegend(rowWidth)
  local legend = Frame.legend
  local row = Frame.footer
  if type(legend) ~= "table" or not row then
    return nil
  end
  local words = Frame.LegendWords(rowWidth, Frame.legendWidth, Frame.FooterRightWidth(), size("ITEMTREE_SPACE_3"))
  Frame.legendWords = words
  local offset = 0
  for _, entry in ipairs(legend) do
    local badge, label = entry.badge, entry.label
    local badgeSize = tonumber(entry.badgeSize) or 12
    if badge and type(badge.ClearAllPoints) == "function" then
      badge:ClearAllPoints()
      badge:SetPoint("LEFT", row, "LEFT", offset, 0)
    end
    offset = offset + badgeSize
    if label and type(label.ClearAllPoints) == "function" then
      label:ClearAllPoints()
      label:SetPoint("LEFT", row, "LEFT", offset + size("ITEMTREE_SPACE_1"), 0)
      if words then
        label:Show()
      else
        label:Hide()
      end
    end
    if words then
      offset = offset + size("ITEMTREE_SPACE_1") + textWidth(label, label and label:GetText())
    end
    offset = offset + size("ITEMTREE_SPACE_2")
  end
  return words
end

-- What the right hand end of the footer takes: the Options button, the three tick boxes and the
-- box.pad between each, measured off the controls the client made rather than from the words. A
-- control the client would not make counts as nothing, which is what it draws. The legend's own
-- width is Frame.legendWidth, and the two together are what has to fit inside the footer row.
function Frame.FooterRightWidth()
  local box = layout()
  local total = 0
  local controls = {}
  -- Listed one at a time rather than in a constructor: a control the client would not make is
  -- nil, and a nil in the middle of a table ends ipairs at it.
  controls[#controls + 1] = Frame.mergeToggle
  controls[#controls + 1] = Frame.totalsToggle
  controls[#controls + 1] = Frame.compactToggle
  controls[#controls + 1] = Frame.optionsButton
  for _, control in ipairs(controls) do
    local width = type(control) == "table" and type(control.GetWidth) == "function" and control:GetWidth()
    width = tonumber(width) or 0
    if width > 0 then
      total = total > 0 and (total + box.pad + width) or width
    end
  end
  return total
end

-- Hands the tree pane the filter region on the view tab row, once. The box itself is UI/Tree.lua's
-- and always has been; all this does is tell it where the row's spare width is, so the pane can
-- re-parent the box it already draws and start its list at the top of its own pane.
--
-- Guarded, and called both from buildContent and from the pass that attaches the panes: a build
-- whose Tree has no AttachFilter (UI/Tree.lua lands in parallel with this file) leaves the box
-- where it is today, one row below the tabs, and nothing here raises. Answers whether it took.
local function attachFilter()
  if Frame.attached.filter then
    return false
  end
  local region = Frame.regions and Frame.regions.filter
  local Tree = ItemTree.UI and ItemTree.UI.Tree
  if not (region and type(Tree) == "table" and type(Tree.AttachFilter) == "function") then
    return false
  end
  Frame.attached.filter = true
  pcall(Tree.AttachFilter, region)
  return true
end

-- The content area, and the pane regions inside it. Tree is the three pane composition of
-- design/templates/bag-interaction, left to right in the order it composes them: the item info
-- column, then the view tabs over the category column and the tree, at ITEMTREE_SPACE_2 8
-- between each. The tree pane draws its own ITEMTREE_SCROLLBAR_W 16 gutter inside that width, so
-- nothing is reserved for it here. The Item chain view gets one region where the category column
-- and the row list go (brief C2), and Discoveries one filling the whole content area. The
-- regions are bare frames: each pane draws its own inset panel, the way the design composes them.
-- The content area is put in the window's own strata, so nothing the client draws through MEDIUM
-- can land between the body surface and the panes.
local function buildContent(frame)
  local box = layout()
  local bottom = box.innerBottom + box.footerH + box.footerPad
  local content = newFrame("Frame", nil, frame)
  if not content then
    return nil
  end
  raiseInto(content, frame, 2)
  content:SetPoint("TOPLEFT", frame, "TOPLEFT", box.inner, -box.bodyTop)
  content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -box.inner, bottom)
  Frame.content = content

  local tree = newFrame("Frame", nil, content)
  if not tree then
    return nil
  end
  tree:SetAllPoints(content)
  Frame.treeTab = tree

  local info = newFrame("Frame", nil, tree)
  local views = newFrame("Frame", nil, tree)
  local sidebar = newFrame("Frame", nil, tree)
  local trees = newFrame("Frame", nil, tree)
  if not (sidebar and trees and info and views) then
    return nil
  end
  info:SetWidth(Frame.INFO_COLUMN_W)
  info:SetPoint("TOPLEFT", tree, "TOPLEFT", 0, 0)
  info:SetPoint("BOTTOMLEFT", tree, "BOTTOMLEFT", 0, 0)

  -- The view strip spans the category column and the tree together, because it changes what both
  -- of them list. It is not over the info column, which is the root item whatever tab is up.
  views:SetHeight(box.tabH)
  views:SetPoint("TOPLEFT", info, "TOPRIGHT", box.pad, 0)
  views:SetPoint("TOPRIGHT", tree, "TOPRIGHT", 0, 0)
  Frame.viewBar = views

  -- Every tab is drawn whatever the root holds: a tab with nothing in it is dimmed rather than
  -- taken away, so the strip never changes shape under the player's hand and an empty tab can
  -- still be pressed to see for itself. A button is made for every word Frame.VIEW_TABS carries
  -- and updateViewTabs hides any that Core has no view key for, so a Core that has not landed
  -- the fourth view draws three and the fourth waits rather than being built twice.
  local viewTabs = {}
  for index, label in ipairs(Frame.VIEW_TABS) do
    -- Voiced on the press, the way the top tabs are, so pressing the tab that is already up
    -- still answers: Frame.SetView takes that press as asking for nothing and returns early.
    local button = buildTab(views, nil, L[label], function()
      playCue("tab")
      Frame.SetView(Frame.ViewAt(index), true)
    end)
    if button then
      viewTabs[index] = button
    end
  end
  Frame.viewTabs = viewTabs

  -- The tree pane's filter box shares this row, at its right hand end: the row reads
  -- [Used by][Sources][Requires][Disenchants into] [ search ... ] and the sidebar and the tree
  -- then start at the same height under it. The region is a bare frame the way every other pane
  -- region is, and UI/Tree.lua fills it through Tree.AttachFilter. updateViewTabs gives it its
  -- width, because what is left of the row is whatever the tabs did not take.
  local filter = newFrame("Frame", nil, views)
  if filter then
    filter:SetPoint("TOPRIGHT", views, "TOPRIGHT", 0, 0)
    filter:SetPoint("BOTTOMRIGHT", views, "BOTTOMRIGHT", 0, 0)
    filter:SetWidth(Frame.VIEW_FILTER_W_MIN)
  end

  sidebar:SetWidth(Frame.COLUMN_W)
  sidebar:SetPoint("TOPLEFT", views, "BOTTOMLEFT", 0, -box.gap)
  sidebar:SetPoint("BOTTOM", tree, "BOTTOM", 0, 0)
  trees:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", box.pad, 0)
  trees:SetPoint("BOTTOMRIGHT", tree, "BOTTOMRIGHT", 0, 0)

  -- The Map view's own rectangle (brief E57): the space the category column and the row list take
  -- TOGETHER, which is those two regions' own outer corners, so it lines up with the view strip
  -- above it and with the info column beside it whatever the window is dragged to. It is hidden
  -- until a creature root's Map tab is up, and then the two lists are hidden instead of it.
  -- UI/Tree.lua owns what is drawn inside it (Tree.ShowMap).
  local map = newFrame("Frame", nil, tree)
  if map then
    map:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, 0)
    map:SetPoint("BOTTOMRIGHT", trees, "BOTTOMRIGHT", 0, 0)
    map:Hide()
  end

  -- Brief Z2: a zone's Map view keeps the category column's place for the zone's items
  -- (UI/ZoneItems.lua), and its map takes only the row list's space beside it. The region is the
  -- category column's own rectangle, hidden until a zone root's Map tab is up.
  local zoneItems = newFrame("Frame", nil, tree)
  if zoneItems then
    zoneItems:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, 0)
    zoneItems:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)
    zoneItems:Hide()
  end

  -- Brief C2: the Item chain view's rectangle, the same space the Map view takes: the category
  -- column and the row list together, under the view strip and beside the info column. The chain
  -- has no categories, so both lists are hidden while it is up and UI/Chain.lua's pane is handed
  -- this region instead. Hidden until an item's Item chain tab is up.
  local chain = newFrame("Frame", nil, tree)
  if chain then
    chain:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, 0)
    chain:SetPoint("BOTTOMRIGHT", trees, "BOTTOMRIGHT", 0, 0)
    chain:Hide()
  end

  -- One region per hosted tab, made whether or not the tab was drawn: Frame.Regions() is a
  -- contract other files read, and a region nothing shows costs an empty frame.
  --
  -- A tab that draws the two header rows fills the content area, which is what every hosted tab
  -- did before the Discoveries tab wanted the room. A tab that draws neither row starts where the
  -- breadcrumb trail would have, anchored to the window itself rather than to the content area,
  -- and so is that much taller. The rows it does not draw are hidden while it is up (see
  -- applyHeaderRows), so the two never overlap, and the region's own top never changes after
  -- this: it is the tab's own rule, not the tab that happens to be selected.
  local hosted = {}
  for name, key in pairs(Frame.HOSTED) do
    local region = newFrame("Frame", nil, content)
    if not region then
      return nil
    end
    local top, left = Frame.RegionTopFor(name)
    if top < box.bodyTop then
      region:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
      region:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    else
      region:SetAllPoints(content)
    end
    region:Hide()
    hosted[key] = region
  end

  Frame.regions = {
    sidebar = sidebar,
    tree = trees,
    info = info,
    filter = filter,
    map = map,
    zoneitems = zoneItems,
    chain = chain,
  }
  for key, region in pairs(hosted) do
    Frame.regions[key] = region
  end

  local placeholder =
    newFontString(content, "ITEMTREE_FONT_BODY", "ITEMTREE_FONTSIZE_BODY_MD", "ITEMTREE_COLOR_TEXT_MUTED")
  if placeholder then
    placeholder:SetPoint("CENTER", content, "CENTER", 0, 0)
    setText(placeholder, L["Not built yet"])
    Frame.placeholder = placeholder
  end
  attachFilter()
  return content
end

-- The resize grip: three gold bars in the bottom right corner, the way PortraitFrame.jsx draws
-- them, over a button that drives the client's own sizing.
local function buildGrip(frame)
  local box = layout()
  local grip = newFrame("Button", nil, frame)
  if not grip then
    return nil
  end
  grip:SetSize(box.grip, box.grip)
  grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
  for index = 0, 2 do
    local bar = fillTexture(grip, "OVERLAY", "ITEMTREE_COLOR_BORDER_GOLD")
    if bar then
      bar:SetSize(12 - index * 4, 1)
      bar:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -2, 2 + index * 4)
    end
  end
  if type(grip.RegisterForDrag) == "function" and type(frame.StartSizing) == "function" then
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function()
      frame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnDragStop", function()
      frame:StopMovingOrSizing()
      saveWindow()
      Frame.FitBand()
    end)
  end
  -- The band is refitted while the window is being dragged rather than only when the drag ends,
  -- so the search box and the recently viewed button follow the grip instead of jumping after
  -- it. Hooked rather than set, because the template may carry a handler of its own.
  if type(frame.HasScript) == "function" and type(frame.HookScript) == "function" then
    local ok, has = pcall(frame.HasScript, frame, "OnSizeChanged")
    if ok and has then
      pcall(frame.HookScript, frame, "OnSizeChanged", function()
        Frame.FitBand()
      end)
    end
  end
  Frame.grip = grip
  return grip
end

-- Minimum size, in both the shapes the clients use.
local function applyResizeBounds(frame)
  local min = Frame.MinSize()
  if type(frame.SetResizable) == "function" then
    pcall(frame.SetResizable, frame, true)
  end
  if type(frame.SetResizeBounds) == "function" then
    local ok = pcall(frame.SetResizeBounds, frame, min.width, min.height)
    if ok then
      return true
    end
  end
  if type(frame.SetMinResize) == "function" then
    return (pcall(frame.SetMinResize, frame, min.width, min.height))
  end
  return false
end

-- The chrome laid out again because the window has just been shown.
--
-- The window is built and laid out while it is hidden, so everything that only settles once a
-- frame is on screen settles after that first pass: the client's own tab handlers (see
-- hookTabResize), and a FontString that answers nothing for its width until it has been drawn
-- once. Both are answered the same way, by measuring again once the window is up, and then once
-- more on the next tick for the measure that was not ready in the same frame. A client with no
-- C_Timer runs the second pass straight away, which costs one more pass and is still correct.
--
-- Read through Frame rather than through the file locals because this is built before they are;
-- Frame.FitBand lays the view row out itself. Nothing here shows or hides anything, so the hook
-- cannot set itself off.
local function relayoutShownChrome()
  if not Frame.frame then
    return false
  end
  Frame.RelayoutTabs()
  Frame.FitBand()
  return true
end

-- Hooked rather than set: the template carries handlers of its own and they must still run.
local function hookWindowShow(frame)
  if not (type(frame) == "table" and type(frame.HookScript) == "function") then
    return false
  end
  if not carriesScript(frame, "OnShow") then
    return false
  end
  local function onShown()
    -- Brief E76: a window shown while the settings panel is up goes under it, whatever showed it.
    setStrata(Frame.WindowStrata())
    relayoutShownChrome()
    nextTick(function()
      if Frame.IsShown() then
        relayoutShownChrome()
      end
    end)
  end
  return (pcall(frame.HookScript, frame, "OnShow", onShown))
end

-- The one place the window's close cue is played. Every way the window goes down ends in this
-- frame being hidden, and two of them never reach Frame.Hide at all: Escape and the client's own
-- CloseSpecialWindows hide the frame where it stands, which is why the window used to close in
-- silence on Escape. Hooked on OnHide instead, the X, a toggle, Escape and CloseSpecialWindows
-- each sound once, and only once: the client fires OnHide as a shown frame goes down and not at
-- all on one that is already hidden, so a second Hide, or a Hide on a window that was never
-- opened, says nothing.
--
-- Silent while the escape suspension is up, which is exactly the settings flow:
-- Frame.escapeSuspended is true from suspendEscape before Options.Open until RestoreEscape a tick
-- after the settings panel hides. Anything that takes the window down in that time is not the
-- player closing it (Frame.Hide drops the suspension first), so nothing is voiced and the window
-- is held on screen again (holdWindow).
--
-- Hooked rather than set, for the same reason as the show hook: the template's own handlers must
-- still run.
local function hookWindowHide(frame)
  if not (type(frame) == "table" and type(frame.HookScript) == "function") then
    return false
  end
  if not carriesScript(frame, "OnHide") then
    return false
  end
  local function onHidden()
    if not Frame.escapeSuspended then
      playCue("close")
    end
    -- Brief E76: while the settings panel is up the window is out of UISpecialFrames, so nothing
    -- the player means as a close reaches it except Frame.Hide, which drops the suspension first.
    -- Anything else that takes it down while the panel is still up is undone a tick later.
    if Frame.escapeSuspended and Frame.settingsWasShown and Frame.SettingsPanelShown() then
      nextTick(holdWindow)
    end
    -- E61: every way of closing the window comes through here, Escape and CloseSpecialWindows
    -- included, so it is where the page the player is leaving is written down.
    pcall(Frame.CapturePage)
    -- Brief BQ24 (QA item 27): and the tab it is closed on, for the next open with no item.
    pcall(Frame.RememberTab)
    -- E57: a creature page draws one PlayerModel and the Map tab draws a rectangle of its own, and
    -- both belong to a window the player can no longer see. This is the one hook every way of
    -- closing the window reaches, Escape and CloseSpecialWindows included, so it is where they are
    -- taken down. Both are idempotent and neither is the window's own to know about, so both are
    -- read through the namespace and pcall'd.
    local ui = ItemTree.UI or EMPTY
    if type(ui.InfoPanel) == "table" and type(ui.InfoPanel.ClearModel) == "function" then
      pcall(ui.InfoPanel.ClearModel)
    end
    if type(ui.Tree) == "table" and type(ui.Tree.ClearMap) == "function" then
      pcall(ui.Tree.ClearMap)
    end
  end
  return (pcall(frame.HookScript, frame, "OnHide", onHidden))
end

-- Builds the window once. Returns nil outside the client, which is what leaves Open returning
-- false and /itemtree show printing the tooltip block instead.
function Frame.Build()
  if Frame.frame then
    return Frame.frame
  end
  local parent = rawget(_G, "UIParent")
  local frame, template = newFrame("Frame", Frame.FRAME_NAME, parent, "PortraitFrameTemplate", "BackdropTemplate")
  if not frame then
    return nil
  end
  Frame.frame = frame
  Frame.template = template
  frame:Hide()
  -- HIGH and toplevel, because a nameplate (the player's own personal resource bar) draws
  -- through MEDIUM and was landing between the body surface and the panes.
  if type(frame.SetFrameStrata) == "function" then
    pcall(frame.SetFrameStrata, frame, Frame.STRATA)
  end
  if type(frame.SetToplevel) == "function" then
    pcall(frame.SetToplevel, frame, true)
  end
  frame:EnableMouse(true)
  frame:SetMovable(true)
  if type(frame.SetClampedToScreen) == "function" then
    frame:SetClampedToScreen(true)
  end
  applyResizeBounds(frame)
  applyFrameArt(frame, template)
  applyBodySurface(frame)
  -- The tab strip is built before the search, because the search box, the rewind button and the
  -- badge toggles all hang off it, right to left.
  buildTitleBar(frame)
  buildTabs(frame)
  buildSearch(frame)
  buildHeader(frame)
  buildContent(frame)
  buildFooter(frame)
  buildGrip(frame)
  -- Not while the settings panel has the window out of the list (brief E76): RestoreEscape puts
  -- it in when the panel goes.
  if not Frame.escapeSuspended then
    registerEscape(Frame.FRAME_NAME)
  end
  -- The window is laid out while it is hidden, so the chrome is measured again the moment it is
  -- actually on screen. See relayoutShownChrome.
  hookWindowShow(frame)
  -- The close cue, on every path down. See hookWindowHide.
  hookWindowHide(frame)
  -- Registered as early as the window exists, so a settings panel the player reaches from the
  -- game menu rather than from the footer button is handled too. Brief TX1: through the client's
  -- event bus only, never a HookScript on the panel.
  hookSettingsEvent()
  -- Brief PW1: the client's profession window followed the same way, and the click listener that
  -- trades the front with it, made here with the window (at login).
  Frame.WatchProfessions()
  Frame.BuildClickEvents()
  Frame.ApplyWindow()
  Frame.SelectTab(Frame.Tab())
  return frame
end

-- Brief PF2: the window's first build moved to login, so the first open finds it built. Core/Init.lua
-- calls this a tick after the first PLAYER_ENTERING_WORLD of the session, behind the loading
-- screen, when no client panel is open (bible A2: a frame made inside an open client panel in
-- gamepad mode taints that panel's navigation). The window is our own frame on UIParent, built
-- hidden, with no page drawn: the frame, its tabs and its panes, nothing else. In combat the
-- build waits for PLAYER_REGEN_ENABLED (Frame.AfterCombat). Every lazy Frame.Build stays, so an
-- open before this ran builds the window as it always did, and this then does nothing.
--
-- done, when given, is called once with whether this call built the window. Answers "ran",
-- "queued" or "already" (the window was built before login's turn came).
function Frame.BuildAtLogin(done)
  local function report(built)
    if type(done) == "function" then
      pcall(done, built)
    end
  end
  if Frame.frame then
    report(false)
    return "already"
  end
  return Frame.AfterCombat(function()
    if Frame.frame then
      report(false)
      return
    end
    report(Frame.Build() ~= nil)
  end, "buildAtLogin")
end

--------------------------------------------------------------------------------
-- Position, size and the remembered rect
--------------------------------------------------------------------------------

local function screenSize()
  local width = rawget(_G, "GetScreenWidth")
  local height = rawget(_G, "GetScreenHeight")
  local w = type(width) == "function" and tonumber(width()) or nil
  local h = type(height) == "function" and tonumber(height()) or nil
  return w, h
end

-- The scale the window should be drawn at right now: the player's setting on top of what 1x
-- means on this screen. Answers with no client, which is what lets the specs read it.
function Frame.Scale()
  local settings = (ItemTree.db and ItemTree.db.settings) or EMPTY
  local screenW, screenH = screenSize()
  return Frame.ScaleFor(settings.windowScale, screenW, screenH)
end

-- Puts that scale on the one frame. Nothing else in the window is scaled, so a pane that turns
-- cursor positions into frame positions through GetEffectiveScale still gets the right answer.
-- Returns the scale, and nil where there is no window to scale.
function Frame.ApplyScale()
  local frame = Frame.frame
  local scale = Frame.Scale()
  if not (frame and type(frame.SetScale) == "function") then
    return nil
  end
  local ok = pcall(frame.SetScale, frame, scale)
  if not ok then
    return nil
  end
  Frame.scale = scale
  return scale
end

-- Puts the window back where this character left it, at the scale the settings ask for, clamped
-- to the minimum and to the screen. Slash.ResetWindow calls this after writing the defaults back,
-- so it must survive being called with no window built.
function Frame.ApplyWindow()
  local frame = Frame.frame
  if not frame then
    return false
  end
  local scale = Frame.ApplyScale() or 1
  local saved = ItemTree.charDb and ItemTree.charDb.window
  local screenW, screenH = screenSize()
  local rect = Frame.WindowRect(saved, Frame.DefaultRect(), Frame.MinSize(), screenW, screenH, scale)
  frame:SetSize(rect.width, rect.height)
  if type(frame.ClearAllPoints) == "function" then
    frame:ClearAllPoints()
  end
  frame:SetPoint(rect.point, rawget(_G, "UIParent"), rect.point, rect.x, rect.y)
  Frame.rect = rect
  -- A new width or a new scale changes what the band holds, and the tabs measure their own word
  -- again with whatever font the client ended up giving them.
  Frame.FitBand()
  Frame.RelayoutTabs()
  return true
end

local round = ItemTree.Util.Round

-- Remembers the rect per character. Only width, height, point, x and y are written: the keys
-- CHAR_DEFAULTS already declares, and nothing else ever reaches saved variables from here.
function Frame.SaveWindow()
  local frame = Frame.frame
  local charDb = ItemTree.charDb
  if not (frame and type(charDb) == "table") then
    return false
  end
  local window = type(charDb.window) == "table" and charDb.window or {}
  charDb.window = window
  if type(frame.GetWidth) == "function" then
    window.width = round(frame:GetWidth()) or window.width
    window.height = round(frame:GetHeight()) or window.height
  end
  if type(frame.GetPoint) == "function" then
    local point, _, _, x, y = frame:GetPoint()
    if type(point) == "string" then
      window.point = point
    end
    window.x = round(x) or window.x
    window.y = round(y) or window.y
  end
  return true
end

--------------------------------------------------------------------------------
-- Header, tabs and panes
--------------------------------------------------------------------------------

-- The client's own quality colours where it has them, the design tokens where it does not.
local function qualityRGB(quality, colourKey)
  local colors = rawget(_G, "ITEM_QUALITY_COLORS")
  local entry = type(colors) == "table" and quality and colors[quality] or nil
  if type(entry) == "table" and tonumber(entry.r) then
    return entry.r, entry.g, entry.b
  end
  return themeColor(colourKey)
end

-- Brief NP2: the owner's words (2026-10-04), the round portrait "only items display in the top left
-- so if I had an item open previously it shows the previously opened item when I click on an npc
-- instead of the npc portrait". A creature or NPC root draws the creature into the portrait, on our
-- own texture: the client's unit portrait (SetPortraitTexture) while the creature is the target,
-- the mouseover or the NPC whose window is open, else the display id portrait the Boss loot tab and
-- the tree's rows draw (SetPortraitTextureFromCreatureDisplayID). One client call per open, about
-- 1 ms on the beta (forever-beta-probe-results, 2026-09-21). A creature with neither clears the
-- portrait to the window's own empty ring rather than leaving the last item's icon there.
Frame.PORTRAIT_UNITS = { "target", "mouseover", "npc" }

-- Whether a root is a creature or NPC page (an npc key). Pure.
function Frame.IsCreatureRoot(key)
  local kind = parseKey(key)
  return kind == "npc"
end

-- The ways one creature root's portrait can be drawn, best first, each { how, value }: "unit" for a
-- unit whose GUID is the one the page was opened from (origin.guid) or names the page's own
-- creature id, then "display" for the display id. guids is { [unit] = GUID } as read now; origin
-- the page's (Core/CreatureLookup.lua Origin); creatureId the page's own real id; display the
-- display id (Core/ViewModel.lua CreatureDisplay). Empty where none applies. Pure.
function Frame.CreaturePortraitSources(guids, origin, creatureId, display)
  local out = {}
  guids = type(guids) == "table" and guids or EMPTY
  local wantedGuid = type(origin) == "table" and type(origin.guid) == "string" and origin.guid or nil
  local lookup = ItemTree.CreatureLookup
  for _, unit in ipairs(Frame.PORTRAIT_UNITS) do
    local guid = guids[unit]
    if type(guid) == "string" and guid ~= "" then
      local match = guid == wantedGuid
      if not match and creatureId and type(lookup) == "table" and type(lookup.CreatureIdFromGuid) == "function" then
        local ok, id = pcall(lookup.CreatureIdFromGuid, guid)
        match = ok and id == creatureId
      end
      if match then
        out[#out + 1] = { how = "unit", value = unit }
        break
      end
    end
  end
  display = tonumber(display)
  if display and display > 0 and display == math.floor(display) then
    out[#out + 1] = { how = "display", value = display }
  end
  return out
end

-- The GUID each of Frame.PORTRAIT_UNITS has now, read once per creature open. Guarded.
function Frame.PortraitGuids()
  local out = {}
  local guidOf = rawget(_G, "UnitGUID")
  if type(guidOf) ~= "function" then
    return out
  end
  -- Brief SV1: a GUID the client keeps secret (a creature's, in combat) is left out.
  local canRead = ItemTree.Util.CanRead
  for _, unit in ipairs(Frame.PORTRAIT_UNITS) do
    local ok, guid = pcall(guidOf, unit)
    if ok and canRead(guid) and type(guid) == "string" then
      out[unit] = guid
    end
  end
  return out
end

-- Draws a creature root into the portrait texture (ours). Answers whether a portrait was drawn;
-- false after clearing the texture to the window's empty ring.
function Frame.DrawCreaturePortrait(texture, key)
  local lookup = ItemTree.CreatureLookup
  local ViewModel = ItemTree.ViewModel
  local origin, creatureId, display = nil, nil, nil
  if type(lookup) == "table" then
    if type(lookup.Origin) == "function" then
      local ok, answer = pcall(lookup.Origin, key)
      origin = ok and type(answer) == "table" and answer or nil
    end
    if type(lookup.IdOfKey) == "function" then
      local ok, answer = pcall(lookup.IdOfKey, key)
      creatureId = ok and tonumber(answer) or nil
    end
  end
  if type(ViewModel) == "table" and type(ViewModel.CreatureDisplay) == "function" then
    local ok, answer = pcall(ViewModel.CreatureDisplay, key)
    display = ok and answer or nil
  end
  local sources = Frame.CreaturePortraitSources(Frame.PortraitGuids(), origin, creatureId, display)
  for _, source in ipairs(sources) do
    local name = source.how == "unit" and "SetPortraitTexture" or "SetPortraitTextureFromCreatureDisplayID"
    local call = rawget(_G, name)
    if type(call) == "function" and pcall(call, texture, source.value) then
      Frame.portraitDrawn = source
      return true
    end
  end
  Frame.portraitDrawn = nil
  if type(texture.SetTexture) == "function" then
    pcall(texture.SetTexture, texture, nil)
  end
  return false
end

-- The art the portrait shows for a root: an item's own icon, and for a spell the icon Core gives
-- the recipe, which is the item it makes or the profession's own glyph. Nothing else has art, so
-- the portrait is left as it was rather than blanked.
local function portraitIcon(key)
  local kind, id = parseKey(key)
  if kind == "item" and Assets and type(Assets.ItemIcon) == "function" then
    local ok, icon = pcall(Assets.ItemIcon, id)
    if ok and icon then
      return icon
    end
    return nil
  end
  if kind == "spell" then
    local Graph = ItemTree.Graph
    if Graph and type(Graph.SpellInfo) == "function" then
      local ok, info = pcall(Graph.SpellInfo, id)
      if ok and type(info) == "table" and info.icon then
        return info.icon
      end
    end
  end
  return nil
end

local function setPortrait(key)
  local texture = Frame.portrait
  -- Brief NP2: a creature or NPC root draws its own portrait, or clears the last root's art.
  if texture and Frame.IsCreatureRoot(key) then
    return Frame.DrawCreaturePortrait(texture, key)
  end
  Frame.portraitDrawn = nil
  local icon = texture and portraitIcon(key) or nil
  if not icon then
    return false
  end
  local setPortraitToTexture = rawget(_G, "SetPortraitToTexture")
  if type(setPortraitToTexture) == "function" and pcall(setPortraitToTexture, texture, icon) then
    return true
  end
  return (pcall(texture.SetTexture, texture, icon))
end

-- The window title is the root's own readable name through Graph.Title, so a spell reads
-- "Spell: Spiced Wolf Meat (2539)" rather than "spell:2539", and an item keeps its quality
-- colour. A tab that draws nothing about the root carries its own word instead (Frame.TitleForTab),
-- which is why a tab change calls updateTitleText as well.
local function updateTitleText()
  local text, colourKey, quality = Frame.TitleForTab(Frame.Tab(), Frame.rootKey)
  local title = Frame.title
  if title then
    setText(title, text)
    local r, g, b = qualityRGB(quality, colourKey)
    if r and type(title.SetTextColor) == "function" then
      title:SetTextColor(r, g, b)
    end
  end
  if Frame.frame and type(Frame.frame.SetTitle) == "function" then
    pcall(Frame.frame.SetTitle, Frame.frame, text)
  end
  return text
end

local function updateTitle()
  local text = updateTitleText()
  setPortrait(Frame.rootKey)
  return text
end

local function updateCaption()
  local caption = Frame.caption
  setChecked(Frame.diffToggle, Frame.showChanges)
  if not (caption and type(caption.SetText) == "function") then
    return nil
  end
  local Diff = ItemTree.Diff
  local text = nil
  if Diff and type(Diff.Caption) == "function" then
    local ok, value = pcall(Diff.Caption)
    text = ok and value or nil
  end
  setText(caption, text or "")
  return text
end

local function updateToggles()
  local settings = (ItemTree.db and ItemTree.db.settings) or EMPTY
  local buttons = {}
  buttons[#buttons + 1] = Frame.newToggle
  buttons[#buttons + 1] = Frame.changedToggle
  for _, button in ipairs(buttons) do
    local active = settings[button.settingKey] and true or false
    for _, texture in ipairs(button.edges or EMPTY) do
      tintTexture(texture, active and "ITEMTREE_COLOR_BORDER_GOLD" or "ITEMTREE_COLOR_BORDER_GOLD_DIM")
    end
    tintTexture(button.background, active and "ITEMTREE_COLOR_STATE_SELECTED" or "ITEMTREE_COLOR_SURFACE_INSET")
    if type(button.SetAlpha) == "function" then
      button:SetAlpha(active and 1 or 0.55)
    end
  end
  setChecked(Frame.compactToggle, settings.density == "compact")
  -- The footer's two tick boxes are both synced from here, so a setting changed in the Options
  -- panel, or by another surface, shows on the row without the window being rebuilt.
  setChecked(Frame.mergeToggle, mergeCraftsOn(settings))
  -- Brief TC1: and the third, off unless the setting says true.
  setChecked(Frame.totalsToggle, settings.totalCounts == true)
end

-- How many rows each view has for a root, from Core, keyed by view. ViewModel.ViewCounts is
-- asked first and ViewModel.DirectionCounts is the fallback for a build of Core that predates
-- the third tab: it answers "down" and "up", which are the uses and sources views, and leaves
-- requires with no count, which is what Frame.ViewLabel draws as the plain word. A build with
-- neither leaves every tab with its plain word, and so does a ViewCounts that has not learnt
-- the fourth view yet: a missing count is the plain word, never a nought.
local function viewCounts(rootKey)
  rootKey = rootKey or Frame.rootKey
  local ViewModel = ItemTree.ViewModel
  if not (rootKey and type(ViewModel) == "table") then
    return nil
  end
  local settings = ItemTree.db and ItemTree.db.settings
  local opts = Frame.OptionsFromSettings(settings)
  if type(ViewModel.ViewCounts) == "function" then
    local ok, counts = pcall(ViewModel.ViewCounts, rootKey, opts)
    if ok and type(counts) == "table" then
      return counts
    end
  end
  if type(ViewModel.DirectionCounts) == "function" then
    local ok, counts = pcall(ViewModel.DirectionCounts, rootKey, opts)
    if ok and type(counts) == "table" then
      return { uses = counts.down, sources = counts.up }
    end
  end
  return nil
end

-- Brief NP1: the tab an open of a creature or NPC page lands on (Frame.BestNpcView over the
-- page's own strip and counts), or nil for any other root. The counts are the ones the strip's
-- labels ask for, under the same options, so the answer costs the tab labels nothing more.
-- Brief BQ24 (QA item 25): the tab a page opened from a trainer row lands on: its Map where the
-- page's views (the strip's keys) have one, else nil (the page's own choice). Pure.
function Frame.TrainerOpenView(views)
  local Edges = ItemTree.Edges
  local map = type(Edges) == "table" and Edges.MAP or "map"
  for _, view in ipairs(type(views) == "table" and views or EMPTY) do
    if view == map then
      return map
    end
  end
  return nil
end

function Frame.NpcOpenView(rootKey)
  local Graph = ItemTree.Graph
  if type(rootKey) ~= "string" or type(Graph) ~= "table" or type(Graph.Kind) ~= "function" then
    return nil
  end
  local ok, kind = pcall(Graph.Kind, rootKey)
  if not ok or kind ~= "npc" then
    return nil
  end
  return Frame.BestNpcView(viewKeys(rootKey), viewCounts(rootKey))
end

-- The look of one view tab: selected, plain, or dimmed because the view has nothing in it.
-- A dimmed tab is still a button, so it keeps its border and its click; it only stops
-- competing for the eye with the two that have something to show.
local function paintViewTab(button, active, empty)
  paintTab(button, active)
  if active or not empty then
    return
  end
  for _, texture in ipairs(button.edges or EMPTY) do
    tintTexture(texture, "ITEMTREE_COLOR_BORDER_DIVIDER")
  end
  if button.label then
    setTextColour(button.label, "ITEMTREE_COLOR_TEXT_DISABLED")
  end
end

--------------------------------------------------------------------------------
-- The view tab, lent out
--------------------------------------------------------------------------------

-- The view row's own button, for a pane that wants a row reading as the same strip. UI/
-- Discoveries.lua draws its source filter with these, so the two rows share one look, one set of
-- colours and one painter rather than a second pane's copy of the numbers. Nothing here is the
-- window's own row: the caller owns its buttons, anchors them and decides what is selected.

-- One view tab: a button with the inset background, the dim gold border and a centred label.
-- parent is the frame it hangs in, text is the word, onClick is what pressing it runs. Answers
-- the button, or nil for no parent and for a client that could not make one.
function Frame.BuildViewTab(parent, text, onClick)
  if type(parent) ~= "table" then
    return nil
  end
  return buildTab(parent, nil, text, onClick)
end

-- One view tab painted: selected, plain, or dimmed because it has nothing in it. The same
-- painter the window's own row uses, so a borrowed row cannot drift from it. Answers whether it
-- took, which is false for anything that is not a button this file made.
function Frame.PaintViewTab(button, active, empty)
  if type(button) ~= "table" then
    return false
  end
  return (pcall(paintViewTab, button, active == true, empty == true))
end

-- The numbers the view row is laid out with, so a borrowed row reads them rather than copying
-- them: the tab's height and its least width, both Theme's, and the gap and the two paddings this
-- file owns. The last three are what Frame.ViewTabWidths and Frame.ViewRowFit take, and both of
-- those are pure, so a pane can measure its own row with the window's own arithmetic.
function Frame.ViewTabMetrics()
  local box = layout()
  return {
    height = box.tabH,
    width = box.tabW,
    gap = Frame.VIEW_TAB_GAP,
    padding = Frame.VIEW_TAB_PAD,
    minPadding = Frame.VIEW_TAB_PAD_MIN,
  }
end

-- Brief C2: the glyph a view tab carries beside its word (Frame.VIEW_ICONS), made the first time a
-- view that has one lands on the button and shown or hidden to match the view it stands for now:
-- a button stands for a different view on a creature root. Built the way a top tab's glyph is
-- (buildTabGlyph), so it goes through Assets and is sized at the artwork's own shape. Answers the
-- glyph's drawn width, 0 where the view has none or the art would not draw.
local function viewTabGlyph(button, key)
  local iconKey = Frame.VIEW_ICONS[key]
  local icon = rawget(button, "viewIcon")
  if icon and rawget(button, "viewIconKey") ~= iconKey then
    if type(icon.Hide) == "function" then
      pcall(icon.Hide, icon)
    end
    button.viewIcon, button.viewIconKey, icon = nil, nil, nil
  end
  if not iconKey then
    return 0
  end
  if not icon then
    icon = buildTabGlyph(button, iconKey)
    if not icon then
      return 0
    end
    button.viewIcon, button.viewIconKey = icon, iconKey
  end
  if type(icon.Show) == "function" then
    pcall(icon.Show, icon)
  end
  return tonumber(icon.glyphW) or 0
end

-- Puts a view tab's word, and its glyph where it has one, as one group centred on the button
-- (Frame.GlyphGroup, the top tabs' own rule). A tab with no glyph keeps its word centred.
local function placeViewGlyph(button, glyphW, textW, width)
  local label = button.label
  local icon = rawget(button, "viewIcon")
  local glyphX, labelX = Frame.GlyphGroup(width, textW, glyphW, layout().gap)
  if label and type(label.ClearAllPoints) == "function" then
    pcall(label.ClearAllPoints, label)
    pcall(label.SetPoint, label, "CENTER", button, "CENTER", labelX, 0)
  end
  if icon and glyphX and type(icon.ClearAllPoints) == "function" then
    pcall(icon.ClearAllPoints, icon)
    pcall(icon.SetPoint, icon, "CENTER", button, "CENTER", glyphX, 0)
  end
end

-- The view row: the word and the count on each tab, the width each one needs, which of them is
-- selected, and the width left over for the tree's filter box beside them. Called on a root
-- change, on a settings change, on every resize and on every Frame.Refresh, which is every path
-- that can change what a view holds or how much room the row has.
--
-- The tabs are sized here rather than at build time because the count is part of the word and
-- the count changes: "Sources" and "Sources (12)" are not the same width. Frame.ViewRowFit
-- decides, so the rule is pure and specced, and each tab is anchored to the one before it.
--
-- One button is drawn per view key Core states. A build of Core with three views hides the
-- fourth button rather than offering a tab nothing can fill, and the row is measured for the
-- tabs that are showing.
local function updateViewTabs()
  local tabs = Frame.viewTabs or EMPTY
  if #tabs == 0 then
    return
  end
  local shown = Frame.ViewCount()
  local view = Frame.View()
  local counts = viewCounts()
  local words, empties, texts, glyphs = {}, {}, {}, {}
  local box = layout()
  local hasShort = false
  -- Every word on the row, measured, with the glyph and its gap counted in where the view has one
  -- (brief C2). short asks for Frame.VIEW_SHORT_LABELS, the second pass below.
  local function measureRow(short)
    for index = 1, shown do
      local button = tabs[index]
      local key = Frame.ViewAt(index)
      local count = counts and counts[key] or nil
      -- A view with no count stated is never dimmed. A count of nought means the tab really is
      -- empty; no count at all means the view is not a list of rows to count, which is the Map tab
      -- (brief E57), the Item chain tab (brief C2), or that this build of Core has no ViewCounts.
      empties[index] = count ~= nil and (tonumber(count) or 0) <= 0
      if Frame.VIEW_SHORT_LABELS[key] then
        hasShort = true
      end
      local text = Frame.ViewLabel(L[Frame.ViewWord(key, index, short)], count)
      local glyphW = button and viewTabGlyph(button, key) or 0
      glyphs[index] = glyphW
      if button and button.label then
        setText(button.label, text)
        texts[index] = textWidth(button.label, text)
        words[index] = texts[index] + (glyphW > 0 and (glyphW + box.gap) or 0)
      else
        texts[index] = 0
        words[index] = 0
      end
    end
  end
  measureRow(false)
  -- The row's own width, worked out from the window rather than asked of the frame: a frame
  -- answers with its old width until the client's next layout pass, and this runs the moment
  -- the window is resized. The bar is anchored to the info column on one side and the window's
  -- inner edge on the other, so it is the window less both insets, the info column and the gap
  -- beside it. The bar is only asked where there is no window to measure.
  local bar = Frame.viewBar
  local metrics = layout()
  local frame = Frame.frame
  local outer = frame and type(frame.GetWidth) == "function" and tonumber(frame:GetWidth()) or 0
  local band = outer > 0 and (outer - 2 * metrics.inner - Frame.INFO_COLUMN_W - metrics.pad) or 0
  if band <= 0 then
    band = (bar and type(bar.GetWidth) == "function" and tonumber(bar:GetWidth())) or 0
  end
  local widths, padding, fits, filterWidth = Frame.ViewRowFit(
    band,
    words,
    Frame.VIEW_TAB_GAP,
    Frame.VIEW_TAB_PAD,
    Frame.VIEW_TAB_PAD_MIN,
    Frame.VIEW_FILTER_W_MIN,
    metrics.pad
  )
  -- Brief C2: a row that cannot hold every word at the least padding tries the short words
  -- ("Item chain" to "Chain") before the client's ellipsis ends any of them.
  local short = false
  if not fits and hasShort then
    measureRow(true)
    short = true
    widths, padding, fits, filterWidth = Frame.ViewRowFit(
      band,
      words,
      Frame.VIEW_TAB_GAP,
      Frame.VIEW_TAB_PAD,
      Frame.VIEW_TAB_PAD_MIN,
      Frame.VIEW_FILTER_W_MIN,
      metrics.pad
    )
  end
  Frame.viewTabsFit = fits
  Frame.viewTabsShort = short
  Frame.viewRow = { band = band, padding = padding, filter = filterWidth, tabs = shown }
  local previous = nil
  for index, button in ipairs(tabs) do
    if index > shown then
      if type(button.Hide) == "function" then
        button:Hide()
      end
    else
      if type(button.Show) == "function" then
        button:Show()
      end
      if type(button.SetWidth) == "function" then
        button:SetWidth(math.max(widths[index] or 0, 1))
      end
      if type(button.ClearAllPoints) == "function" then
        button:ClearAllPoints()
        if previous then
          button:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT", Frame.VIEW_TAB_GAP, 0)
        else
          button:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
        end
      end
      local glyphW = glyphs[index] or 0
      local room = math.max(1, (widths[index] or 0) - 2 * padding - (glyphW > 0 and (glyphW + box.gap) or 0))
      if button.label then
        clampToOneLine(button.label, "CENTER")
        -- A row too narrow for even the least padding shares what is left out equally, and then
        -- the word has to end somewhere: a FontString with a width of its own is truncated by the
        -- client's own ellipsis rather than wrapping into a second line nobody can read. While
        -- the words fit, the label keeps the box the client gave it.
        if not fits and type(button.label.SetWidth) == "function" then
          pcall(button.label.SetWidth, button.label, room)
        end
      end
      placeViewGlyph(button, glyphW, fits and texts[index] or math.min(texts[index] or 0, room), widths[index])
      local active = Frame.ViewAt(index) == view
      paintViewTab(button, active, empties[index])
      -- The glyph takes the word's own colour, after the paint has set it.
      local icon = rawget(button, "viewIcon")
      if icon then
        tintTabGlyph(icon, active, button.label, "ITEMTREE_COLOR_TEXT_TITLE", "ITEMTREE_COLOR_TEXT_MUTED")
      end
      previous = button
    end
  end
  -- Whatever the tabs left, which is the tree's filter box. It is anchored to the row's right
  -- hand end, so only its width changes as the window is dragged.
  local filter = Frame.regions and Frame.regions.filter
  if filter and type(filter.SetWidth) == "function" then
    filter:SetWidth(math.max(filterWidth, 1))
  end
end

-- One crumb button, reused from the pool so re-rooting does not leak frames.
local function crumbButton(index)
  local pool = Frame.crumbButtons
  local button = pool[index]
  if button then
    return button
  end
  local bar = Frame.crumbBar
  if not bar then
    return nil
  end
  button = newFrame("Button", nil, bar)
  if not button then
    return nil
  end
  button:SetHeight(layout().crumbH)
  button.label = newFontString(button, "ITEMTREE_FONT_BODY", "ITEMTREE_FONTSIZE_BODY_MD", "ITEMTREE_COLOR_TEXT_MUTED")
  if button.label then
    button.label:SetPoint("LEFT")
  end
  local chevron = button.CreateTexture and button:CreateTexture(nil, "ARTWORK") or nil
  if chevron then
    chevron:SetSize(10, 10)
    chevron:SetPoint("LEFT", button, "RIGHT", 2, 0)
    applyAsset(chevron, "ICON_CHEVRON_EXPAND")
    tintTexture(chevron, "ITEMTREE_COLOR_BORDER_GOLD_DIM")
    button.chevron = chevron
  end
  button:SetScript("OnClick", function(self)
    -- Brief E97: a boss crumb goes back to the Boss loot tab rather than rooting the window on it.
    if Frame.IsBossCrumb(self.crumbKey) then
      Frame.OpenBossCrumb(self.crumbKey)
    elseif self.crumbKey then
      Frame.Open(self.crumbKey)
    end
  end)
  -- Only a boss crumb carries a tooltip ("Blackfathom Deeps, Boss loot"); the rest show nothing.
  button:SetScript("OnEnter", function(self)
    local tooltip = rawget(_G, "GameTooltip")
    if type(self.crumbTooltip) ~= "string" or not (tooltip and type(tooltip.SetOwner) == "function") then
      return
    end
    pcall(tooltip.SetOwner, tooltip, self, "ANCHOR_BOTTOMLEFT")
    pcall(tooltip.AddLine, tooltip, self.crumbTooltip)
    pcall(tooltip.Show, tooltip)
  end)
  button:SetScript("OnLeave", function(self)
    local tooltip = rawget(_G, "GameTooltip")
    if type(self.crumbTooltip) == "string" and tooltip and type(tooltip.Hide) == "function" then
      pcall(tooltip.Hide, tooltip)
    end
  end)
  pool[index] = button
  return button
end

local function updateCrumbs()
  local bar = Frame.crumbBar
  if not bar then
    return nil
  end
  local crumbs = Frame.Crumbs(Frame.path, Frame.rootKey)
  local offset = 0
  for index, crumb in ipairs(crumbs) do
    local button = crumbButton(index)
    if button then
      local label = crumb.label or ""
      if button.label then
        setText(button.label, label)
        setTextColour(button.label, crumb.current and "ITEMTREE_COLOR_TEXT_TITLE" or "ITEMTREE_COLOR_TEXT_MUTED")
      end
      -- The label measures itself where the client can; a stub or a font string with no face
      -- falls back to a width per character, which keeps the crumbs from stacking up.
      local width = textWidth(button.label, label)
      button:SetWidth(width)
      button:ClearAllPoints()
      button:SetPoint("LEFT", bar, "LEFT", offset, 0)
      button.crumbKey = (not crumb.current) and not crumb.ellipsis and crumb.key or nil
      button.crumbTooltip = crumb.tooltip
      if button.chevron then
        if index < #crumbs then
          button.chevron:Show()
        else
          button.chevron:Hide()
        end
      end
      button:Show()
      offset = offset + width + 14
    end
  end
  for index = #crumbs + 1, #Frame.crumbButtons do
    Frame.crumbButtons[index]:Hide()
  end
  return crumbs
end

-- The panes, in the order the design reads them. InfoPanel is handed the root key rather than the
-- model: it draws the root item's own facts, not the tree.
local PANES = {
  { name = "Sidebar", region = "sidebar" },
  { name = "Tree", region = "tree" },
  { name = "InfoPanel", region = "info", wantsKey = true },
}

-- Hands one pane module its region and the root key: a hosted tab's pane (Frame.HOSTED), or the
-- chain pane on the Item chain view (brief C2, regionKey "chain"). Returns whether a module drew
-- it, which is what decides between the pane and the "Not built yet" placeholder.
local function handRegion(name, regionKey)
  local regions = Frame.regions
  local region = regions and regions[regionKey or ""]
  local module = ItemTree.UI and ItemTree.UI[name]
  if not (region and type(module) == "table" and type(module.Show) == "function") then
    return false
  end
  if not Frame.attached[name] and type(module.Attach) == "function" then
    -- Flagged before the call, so a pane that raises is not attached again on every refresh.
    Frame.attached[name] = true
    Frame.Guarded(name .. ".Attach", module.Attach, region)
  end
  -- Brief G1: a pane draw that raises goes to the window's boundary (Frame.Guarded), which hands
  -- it to the client's error handler and puts the empty page up, rather than a bare pcall that
  -- swallowed it without a word.
  Frame.Guarded(name .. ".Show", module.Show, Frame.rootKey)
  return true
end

local function handHosted(name)
  return handRegion(name, Frame.HOSTED[name])
end

-- Shows or hides one region, where there is one to show. Answers whether it took, so a caller
-- with a fall back knows the row was never there.
local function setRegionShown(region, shown)
  if not (type(region) == "table" and type(region.Show) == "function" and type(region.Hide) == "function") then
    return false
  end
  if shown then
    region:Show()
  else
    region:Hide()
  end
  return true
end

-- The header rows the tab that is up draws, put on the frames: Frame.HeaderRowsFor is the rule and
-- this is the part that touches them. The caption row holds the tick box and the caption, so
-- hiding the row hides both; where the row was never built the two are hidden themselves, which is
-- what a client that could not make the frame leaves behind. The regions the rows leave are not
-- re-anchored here: each hosted region was anchored to its own tab's rule when it was built.
-- Answers the rows, so a caller (and a spec) can read what was applied.
local function applyHeaderRows(tab)
  local rows = Frame.HeaderRowsFor(tab)
  Frame.headerRows = rows
  setRegionShown(Frame.crumbBar, rows.crumbs)
  if not setRegionShown(Frame.captionRow, rows.diffRow) then
    setRegionShown(Frame.diffToggle, rows.diffRow)
    setRegionShown(Frame.caption, rows.diffRow)
  end
  setRegionShown(Frame.viewBar, rows.viewRow)
  return rows
end

-- Which of the Tree tab's own regions the VIEW that is up draws in (brief E57).
--
-- Every view but one is the category column and the row list, which is what the tab has always
-- drawn. The Map tab is one rectangle in the space both of those take, so they are hidden and it
-- is shown, and the row list's own filter box goes with them: there is nothing on a map to search.
-- What is drawn inside the rectangle is UI/Tree.lua's (Tree.ShowMap), and the painter behind that
-- is UI/Map.lua, which draws the zone's own art with the creature's pins on it (brief E59).
--
-- Leaving the Map tab takes the map down rather than only hiding the rectangle it sits in: the
-- real painter holds tile textures and pin frames, and a tab the player has walked away from has
-- no business still holding a zone's art. Tree.ClearMap is idempotent and is the same call the
-- window's own OnHide makes.
--
-- Answers whether the map is what is showing, so a caller and a spec can read it back.
--
-- Brief Z2: a ZONE root's Map view is the one that keeps a list beside the map. The category
-- column's place holds the zone's items (UI/ZoneItems.lua), the search box stays up to filter
-- them, and the map takes the row list's space alone. The list is drawn before the map, because
-- the list settles which item the map pins.
function Frame.IsZoneRoot(rootKey)
  local Graph = ItemTree.Graph
  if type(rootKey) ~= "string" or type(Graph) ~= "table" or type(Graph.Kind) ~= "function" then
    return false
  end
  local ok, kind = pcall(Graph.Kind, rootKey)
  return ok and kind == "zone"
end

--- Brief PR37 (the owner, 2026-10-02): an open that names a zone's item groups (opts.zoneGroups,
--- group ids in order of preference, with opts.view the Map view and opts.pickFirst; the
--- Professions tab's gathering zones, ItemTree_Professions/UI/Pane.lua Pane.ZoneOpenOpts). Where
--- the zone's item list (ViewModel.ZoneItemList, under the window's own options, the list the Map
--- view draws and keeps) holds one of those groups, its column is asked to open on it with its
--- first item picked (UI/ZoneItems.lua ZoneItems.ArriveOnGroup) and the opts go on as given.
--- Otherwise, or for anything that is not a zone, the open goes on without the view or the groups,
--- so the page opens as any other open would. Answers the opts to open with.
function Frame.ZoneGroupOpts(key, opts)
  if type(opts) ~= "table" or type(opts.zoneGroups) ~= "table" then
    return opts
  end
  local out = {}
  for field, value in pairs(opts) do
    out[field] = value
  end
  out.zoneGroups, out.pickFirst = nil, nil
  local ui = ItemTree.UI
  local pane = type(ui) == "table" and ui.ZoneItems or nil
  local ViewModel = ItemTree.ViewModel
  local usable = Frame.IsZoneRoot(key)
    and type(pane) == "table"
    and type(pane.MatchGroup) == "function"
    and type(pane.ArriveOnGroup) == "function"
    and type(ViewModel) == "table"
    and type(ViewModel.ZoneItemList) == "function"
  local group = nil
  if usable then
    local settings = ItemTree.db and ItemTree.db.settings
    local ok, list = pcall(ViewModel.ZoneItemList, key, Frame.OptionsFromSettings(settings))
    group = ok and pane.MatchGroup(list, opts.zoneGroups) or nil
  end
  if group == nil then
    out.view = nil
    return out
  end
  if opts.pickFirst == true then
    pane.ArriveOnGroup(key, group)
  end
  return out
end

-- The map's rectangle: both lists' space, or on a zone root the row list's alone. Re-anchored only
-- when that changes. Answers which it is.
local function anchorMap(map, zone)
  local regions = Frame.regions or EMPTY
  if type(map) ~= "table" or type(map.ClearAllPoints) ~= "function" then
    return false
  end
  zone = zone and true or false
  if rawget(map, "itemTreeZoneAnchor") == zone then
    return zone
  end
  map.itemTreeZoneAnchor = zone
  map:ClearAllPoints()
  if zone and regions.tree then
    map:SetPoint("TOPLEFT", regions.tree, "TOPLEFT", 0, 0)
  elseif regions.sidebar then
    map:SetPoint("TOPLEFT", regions.sidebar, "TOPLEFT", 0, 0)
  end
  if regions.tree then
    map:SetPoint("BOTTOMRIGHT", regions.tree, "BOTTOMRIGHT", 0, 0)
  end
  return zone
end

local function zoneItemsPane()
  local ui = ItemTree.UI
  local pane = type(ui) == "table" and ui.ZoneItems or nil
  return type(pane) == "table" and pane or nil
end

-- Brief C2: the Item chain view is the other one that takes both lists' space. The category column,
-- the row list and the filter box are hidden (the chain has no categories and nothing to search),
-- the chain region is shown, and UI/Chain.lua's pane is attached to it once and handed the root on
-- every pass, exactly as the Chain tab's pane was. Leaving the view hides the region, and the
-- pane's own viewport OnHide closes its menu and stops a drag, which is what leaving the tab did.
-- The second answer is true where the chain view is up with no pane to draw it, which is what
-- puts the "Not built yet" placeholder up.
local function updateViewRegions()
  local regions = Frame.regions or EMPTY
  local Edges = ItemTree.Edges
  local view = Frame.View()
  local chained = view == Frame.CHAIN_VIEW
  local mapped = view == ((Edges and Edges.MAP) or "map")
  local zoneMap = mapped and Frame.IsZoneRoot(Frame.rootKey) and regions.zoneitems ~= nil
  local lists = not mapped and not chained
  setRegionShown(regions.sidebar, lists)
  setRegionShown(regions.tree, lists)
  setRegionShown(regions.filter, lists or zoneMap)
  setRegionShown(regions.zoneitems, zoneMap)
  anchorMap(regions.map, zoneMap)
  setRegionShown(regions.map, mapped)
  setRegionShown(regions.chain, chained)
  local chainMissing = false
  if chained then
    chainMissing = not handRegion("Chain", "chain")
  end
  local Tree = ItemTree.UI and ItemTree.UI.Tree
  local pane = zoneItemsPane()
  if not zoneMap and pane and type(pane.Hide) == "function" then
    pcall(pane.Hide)
  end
  if not mapped then
    if type(Tree) == "table" and type(Tree.ClearMap) == "function" then
      pcall(Tree.ClearMap)
    end
    return false, chainMissing
  end
  if zoneMap and pane and type(pane.Show) == "function" then
    local vm = Frame.vm
    local opts = type(vm) == "table" and type(vm.opts) == "table" and vm.opts or nil
    Frame.Guarded("ZoneItems.Show", pane.Show, regions.zoneitems, Frame.rootKey, opts, Frame.PreviousKey(), regions.map)
  end
  if type(Tree) == "table" and type(Tree.ShowMap) == "function" then
    Frame.Guarded("Tree.ShowMap", Tree.ShowMap, regions.map, Frame.rootKey)
  end
  return true, false
end

-- Shows the regions the active tab needs and hands the tab its pane. Nothing here changes the
-- window's size: every tab is drawn in the one content area.
local function updateTabPanes()
  local tab = Frame.Tab()
  applyHeaderRows(tab)
  local hosted = Frame.HOSTED[tab]
  local chainMissing = false
  if not hosted then
    local _, missing = updateViewRegions()
    chainMissing = missing == true
  end
  local regions = Frame.regions or EMPTY
  if Frame.treeTab then
    if hosted then
      Frame.treeTab:Hide()
    else
      Frame.treeTab:Show()
    end
  end
  for name, key in pairs(Frame.HOSTED) do
    local region = regions[key]
    if region then
      if name == tab then
        region:Show()
      else
        region:Hide()
      end
    end
  end
  local drawn = hosted and handHosted(tab) or false
  if Frame.placeholder then
    if (hosted and not drawn) or chainMissing then
      Frame.placeholder:Show()
    else
      Frame.placeholder:Hide()
    end
  end
  return drawn
end

-- Hands the current model to every pane in the Tree tab, attaching each to its region the first
-- time, then hands the active tab its own pane. A pane that is absent, or that has no Show, is
-- skipped: the window opens with the panes it has.
local function handPanes()
  local regions = Frame.regions
  if not (regions and Frame.vm) then
    return false
  end
  -- The tree's filter box moves onto the view tab row the first time the pane is here to be
  -- told about it, which need not be the moment the regions were built.
  attachFilter()
  for _, pane in ipairs(PANES) do
    local module = ItemTree.UI and ItemTree.UI[pane.name]
    if type(module) == "table" then
      if not Frame.attached[pane.name] and type(module.Attach) == "function" then
        Frame.attached[pane.name] = true
        Frame.Guarded(pane.name .. ".Attach", module.Attach, regions[pane.region])
      end
      if type(module.Show) == "function" then
        -- E61: the page notes ride along with the model. Nil on a plain refresh, which is what
        -- tells a pane to leave its scroll exactly where the player left it; a table on an open,
        -- holding the remembered search and offsets, or empty for an arrival that starts fresh.
        Frame.Guarded(
          pane.name .. ".Show",
          module.Show,
          pane.wantsKey and Frame.rootKey or Frame.vm,
          Frame.pendingState
        )
      end
    end
  end
  updateTabPanes()
  return true
end

-- The pane regions, created once: the three inside the Tree tab, the filter region on the view
-- tab row, and one per hosted tab. Returns nil where there is no window to hang them on.
function Frame.Regions()
  if Frame.regions then
    return Frame.regions
  end
  if not Frame.Build() then
    return nil
  end
  return Frame.regions
end

-- Puts the word a top tab draws on it: the template's own SetText, or the home made label. The
-- word the tab is drawing is kept as tabDrawn, which layoutTopTab measures (brief C2).
local function putTabWord(button, word)
  word = tostring(word or "")
  if button.topTab and type(button.SetText) == "function" then
    pcall(button.SetText, button, word)
  else
    setText(button.label, word)
  end
  button.tabDrawn = word
  return word
end

-- What one word measures on a tab, read off the tab's own FontString with the word put on it,
-- because the client only measures what a FontString holds. The caller puts the word it wants
-- drawn back afterwards; nothing is drawn in between.
local function measureTabWord(button, word)
  putTabWord(button, word)
  return textWidth(button.tabText, word)
end

-- Brief BL4: which tabs keep their word on this band (Frame.TabWords), applied. Each tab is
-- measured with its word (Frame.TopTabWidth, exactly as layoutTopTab sizes it), with its short
-- word where it has one (brief C2), and with its glyph alone (Frame.GlyphTabWidth), and a tab whose
-- answer changed is laid out again. The answer is kept in Frame.tabWords, and whether the short
-- words are up in Frame.tabShort, for the specs and the debug report. Answers the list.
local function fitTabWords(band, rest)
  local box = layout()
  local current = tabIndex(Frame.Tab())
  local labelled, glyphs, shorts, spacing = {}, {}, {}, 0
  local buttons = Frame.tabs or EMPTY
  for index, button in ipairs(buttons) do
    local glyphW = (button.icon and button.icon.glyphW) or 0
    local sideArt = button.topTab and Frame.TAB_SIDE_ART or 0
    local drawn = button.tabDrawn or button.tabLabel
    local measured = measureTabWord(button, button.tabLabel)
    labelled[index] = Frame.TopTabWidth(measured, glyphW, box.gap, Frame.TAB_PADDING, sideArt, box.tabW)
    if button.tabShort then
      local short = measureTabWord(button, button.tabShort)
      shorts[index] = Frame.TopTabWidth(short, glyphW, box.gap, Frame.TAB_PADDING, sideArt, box.tabW)
    end
    putTabWord(button, drawn)
    if glyphW > 0 then
      glyphs[index] = Frame.GlyphTabWidth(glyphW, Frame.TAB_PADDING, sideArt)
    end
    if index > 1 then
      spacing = spacing + (button.tabSpacing or 0)
    end
  end
  local words, _, short = Frame.TabWords(band, rest, labelled, glyphs, spacing, current, shorts)
  for index, button in ipairs(buttons) do
    local bare = words[index] == false
    local word = (short and button.tabShort) or button.tabLabel
    local moved = button.tabDrawn ~= word
    if moved then
      putTabWord(button, word)
    end
    if (button.glyphOnly == true) ~= bare or moved then
      button.glyphOnly = bare
      layoutTopTab(button, index == current)
    end
  end
  Frame.tabWords = words
  Frame.tabShort = short == true
  return words
end

-- Lays the top tabs out again, words, bubbles and all. The word is written again first, then the
-- width is measured and set and the group is placed, so a font the client swapped, a scale the
-- player changed and a selection all land here rather than leaving the glyph where the last
-- measurement put it. The bubble over a tab's corner follows its pane's unseen count, which a
-- discovery arriving while the window is open changes, and is hidden on the tab that is up.
-- Returns how many tabs were laid out.
function Frame.RelayoutTabs()
  local names = tabNames()
  local current = tabIndex(Frame.Tab())
  local count = 0
  for position, button in ipairs(Frame.tabs or EMPTY) do
    local name = button.tabName or names[position]
    if name then
      local word = Frame.TabLabel(L[Frame.TabWord(name)])
      local short = Frame.TabLabel(L[Frame.TabWord(name, true)])
      button.tabShort = short ~= word and short or nil
      if button.tabLabel ~= word then
        button.tabLabel = word
        putTabWord(button, (Frame.tabShort and button.tabShort) or word)
      end
    end
    layoutTopTab(button, position == current)
    if name then
      updateBubble(button, tabCount(name), position == current, Frame.TabAlert(name))
    end
    count = count + 1
  end
  -- Brief BL4: a new selection moves which tab keeps its word on a narrow band, so the last band
  -- Frame.FitBand measured is shared out again here too.
  local fit = Frame.tabFit
  if type(fit) == "table" then
    fitTabWords(fit.band, fit.rest)
  end
  return count
end

-- What the top tabs take together, including the gap the strip leaves between them. The width is
-- the one this file put on each tab (layoutTopTab owns it), and the client's own answer is the
-- fallback: a live frame has no `width` field, so reading one off the button reported nothing
-- and the band thought the tabs were free.
local function tabsWidth()
  local total = 0
  for index, button in ipairs(Frame.tabs or EMPTY) do
    local width = tonumber(button.tabWidth)
    if not width and type(button.GetWidth) == "function" then
      local ok, value = pcall(button.GetWidth, button)
      width = ok and tonumber(value) or nil
    end
    total = total + (width or 0)
    if index > 1 then
      total = total + (button.tabSpacing or 0)
    end
  end
  return total
end

-- The owner's narrow band rule, applied. The search box gives up its width first and the
-- recently viewed button drops its words only once the box is at its floor; Frame.BandFit is the
-- arithmetic and this is the part that touches frames. Where the gaps closed up so the button
-- keeps its words, the box moves in to the button's own gap too. Returns the search box's width
-- and whether the button kept its words.
function Frame.FitBand()
  local strip = Frame.tabStrip
  local box = Frame.searchBox
  local button = Frame.historyButton
  if not (strip and box) then
    return nil
  end
  local metrics = layout()
  -- The strip is anchored to both of the window's inner edges, so its width is the window's less
  -- those two insets. That is worked out here rather than asked of the strip, because a frame
  -- still answers with its old width until the client's next layout pass and this runs the
  -- moment the window is resized. The strip is only asked where there is no window to measure.
  local frame = Frame.frame
  local outer = frame and type(frame.GetWidth) == "function" and tonumber(frame:GetWidth()) or 0
  local band = outer > 0 and (outer - metrics.topTabLeft - metrics.inner) or 0
  if band <= 0 then
    band = (type(strip.GetWidth) == "function" and tonumber(strip:GetWidth())) or 0
  end
  -- The two toggles, the trainer button (brief UX1) and the dice button are all built as squares of
  -- exactly this height, so the token is the answer and the client's own width is only asked in
  -- case something has since resized one. They are counted as well as measured, because the gaps between them are what
  -- Frame.BandFit needs to know and a build with no dice button has one gap fewer.
  local squares, count = 0, 0
  for _, square in ipairs({ Frame.newToggle, Frame.changedToggle, Frame.trainerButton, Frame.randomButton }) do
    if square then
      local width = nil
      if type(square.GetWidth) == "function" then
        local ok, value = pcall(square.GetWidth, square)
        width = ok and tonumber(value) or nil
      end
      squares = squares + (width or metrics.titleButton)
      count = count + 1
    end
  end
  local labelled, glyphOnly = metrics.titleButton, metrics.titleButton
  if button then
    local glyphW = (button.icon and button.icon.glyphW) or 0
    local measured = textWidth(button.historyText, button.historyLabel)
    labelled = math.max(metrics.titleButton, Frame.GlyphGroupWidth(measured, glyphW, metrics.gap, metrics.pad))
  end
  -- Brief BL4: the tabs give way before they push the box under its floor. The least the right
  -- hand group can take is the squares, every gap, the recently viewed glyph and the floored box.
  if band > 0 then
    local gaps = count * metrics.buttonGap + 2 * metrics.bandGap
    Frame.tabFit = { band = band, rest = squares + gaps + glyphOnly + Frame.SEARCH_W_MIN }
    fitTabWords(Frame.tabFit.band, Frame.tabFit.rest)
  end
  local search, words, tight =
    Frame.BandFit(band, tabsWidth(), squares, labelled, glyphOnly, metrics.bandGap, count, metrics.buttonGap)
  -- The word won over the gap (Frame.BandFit): the box closes up to the button's own gap.
  if button and type(button.SetPoint) == "function" then
    local gap = tight and metrics.buttonGap or metrics.bandGap
    if button.bandGapUsed ~= gap then
      if type(button.ClearAllPoints) == "function" then
        button:ClearAllPoints()
      end
      button:SetPoint("RIGHT", box, "LEFT", -gap, 0)
      button.bandGapUsed = gap
    end
  end
  if button and button.labelled ~= words then
    button.labelled = words
    layoutHistoryButton(button)
  end
  if type(box.SetWidth) == "function" then
    box:SetWidth(search)
  end
  Frame.bandFit = { search = search, labelled = words, tight = tight == true }
  -- The view row narrows with the window as well, and its tabs and its filter box are both
  -- sized from the row they are given, so they are laid out again on the same pass.
  updateViewTabs()
  return search, words
end

--- The top tabs' counts read afresh and their bubbles laid out again, and nothing else: no pane
--- is handed the model and nothing is redrawn. UI/Discoveries.lua calls this when the Discovery
--- Miner finds something while the player is on another tab, so the bubble on the Discoveries
--- tab rises without the tree being drawn again. Answers how many tabs were laid
--- out, and 0 where there is no window.
function Frame.RefreshTabCounts()
  clearTabCounts()
  if not Frame.frame then
    return 0
  end
  return Frame.RelayoutTabs()
end

-- The whole top of the window laid out again: the tabs' words and widths, then the band that
-- holds them, then the view row under it. Every path that can change a word or a count ends
-- here. Frame.FitBand lays the view row out itself, so it is only done separately where there
-- is no band to fit.
local function relayoutChrome()
  -- The counts are memoised per pass, and this is the start of one: a discovery that arrived
  -- since the last pass is read once here and then reused for every tab.
  clearTabCounts()
  Frame.RelayoutTabs()
  if not Frame.FitBand() then
    updateViewTabs()
  end
end

--------------------------------------------------------------------------------
-- Coming back to a page: the capture and the restore (brief E61)
--
-- The pure half is up beside Frame.ArrivalRestores. This is the part that reads the panes and
-- the view model, and it runs at three seams: the window leaving a root (Frame.Open), the player
-- leaving a view tab (Frame.SetView), and the window going down (the OnHide hook and Frame.Hide,
-- so closing on an item and pressing the key again brings the page back as it was left).
--------------------------------------------------------------------------------

-- The page a root key stands for: the key and the set of tabs that root draws.
local function pageKey(rootKey)
  return Frame.PageKey(rootKey, viewKeys(rootKey))
end

-- Brief RO1: the tab the window's page is on now, onto its Recently viewed entry when that page is
-- the newest one (Core/History.lua History.NoteView), so a reload or a logout after a view tab was
-- pressed still comes back on that tab. Fields rather than locals: this file's main chunk is near
-- Lua 5.1's 200 locals. Guarded; answers whether the word was written.
function Frame.NoteRecentView()
  local History = ItemTree.History
  local key = Frame.rootKey
  if not (type(key) == "string" and type(History) == "table" and type(History.NoteView) == "function") then
    return false
  end
  local ok, written = pcall(History.NoteView, key, Frame.View())
  return ok and written == true
end

-- Brief RO1: the newest Recently viewed page and the tab it was left on (History.Last), or nil,
-- nil where Recently viewed is empty or not loaded.
function Frame.LastRecentPage()
  local History = ItemTree.History
  if not (type(History) == "table" and type(History.Last) == "function") then
    return nil, nil
  end
  local ok, key, view = pcall(History.Last)
  if not ok or type(key) ~= "string" or key == "" then
    return nil, nil
  end
  if type(view) ~= "string" then
    view = nil
  end
  return key, view
end

-- What the view that is up looks like right now: the text in the tree's search box, which is the
-- window's own (Frame.SetTextFilter is the one path in and out of that box), and where each of
-- the two lists is scrolled to, in pixels, which is each pane's. Guarded, because a pane that was
-- never built has nothing to say and a build without one must still open.
local function paneState()
  local state = {}
  state.search = Frame.textFilter
  local ui = ItemTree.UI or EMPTY
  local Tree = ui.Tree
  if type(Tree) == "table" and type(Tree.Snapshot) == "function" then
    local ok, snap = pcall(Tree.Snapshot)
    if ok and type(snap) == "table" then
      state.offset = tonumber(snap.offset)
    end
  end
  local Sidebar = ui.Sidebar
  if type(Sidebar) == "table" and type(Sidebar.ScrollOffset) == "function" then
    local ok, offset = pcall(Sidebar.ScrollOffset)
    if ok then
      state.sidebarOffset = tonumber(offset)
    end
  end
  return state
end

-- Writes down what the player has done to the page that is up, under the view they are on. Called
-- on the way out of a page, a view or the window, and it is the same call every time: the notes
-- for a view are replaced whole, so leaving a page twice costs no more than leaving it once.
-- Answers the page's notes, or nil where there is no root to write any about.
function Frame.CapturePage()
  local key = pageKey(Frame.rootKey)
  if not key then
    return nil
  end
  local page = Frame.memory.pages[key]
  if type(page) ~= "table" or type(page.views) ~= "table" then
    page = { views = {} }
  end
  local view = Frame.View()
  local state = paneState()
  local vm = Frame.vm
  if type(vm) == "table" and type(vm.Snapshot) == "function" then
    local ok, marks = pcall(vm.Snapshot, vm)
    if ok and type(marks) == "table" then
      state.marks = marks
    end
  end
  page.view = view
  page.views[view] = state
  Frame.MemoryPut(Frame.memory, key, page, Frame.PAGE_MEMORY)
  return page
end

-- The notes an open should come back to, or nil to start the page fresh. The decision is
-- Frame.ArrivalRestores and is taken BEFORE the window moves, because it reads the trail the
-- player arrived from.
local function recallPage(key, opts)
  if not Frame.ArrivalRestores(opts, Frame.path, key, Frame.rootKey) then
    return nil
  end
  local stored = pageKey(key)
  if not stored then
    return nil
  end
  return Frame.MemoryGet(Frame.memory, stored)
end

-- What a pane is handed with the model (Frame.pendingState), in three shapes:
--   nil                 a plain refresh. Nothing moves: a row opened mid list must not jump.
--   { top = true }      an arrival that starts fresh. Both lists go to the top of themselves and
--                       the search box is left exactly as the window set it.
--   { restore = true }  a return, with the remembered search and offsets beside it.
Frame.PANE_TOP = { top = true }

-- Puts one view's notes back. The marks go on the view model BEFORE anything asks it for a row,
-- so the panes are handed the list the player left and the scroll below lands on the right pixel.
-- Answers the pane half of the notes, as a table of its own so the store cannot be written
-- through, or nil where this view has none and the arrival starts fresh.
local function restoreView(page)
  if type(page) ~= "table" or type(page.views) ~= "table" then
    return nil
  end
  local state = page.views[Frame.View()]
  if type(state) ~= "table" then
    return nil
  end
  local vm = Frame.vm
  if type(vm) == "table" and type(vm.Restore) == "function" then
    pcall(vm.Restore, vm, state.marks)
  end
  -- The window's own mirror of the tree's search box, so the two agree before the pane redraws.
  Frame.textFilter = state.search
  return {
    restore = true,
    search = state.search,
    offset = state.offset,
    sidebarOffset = state.sidebarOffset,
  }
end

-- Shows one tab. The window keeps its size: only which region is shown changes.
--
-- The window marks nothing seen: a pane does that itself as the player leaves it (the region it
-- is hidden with fires its OnHide, see UI/Discoveries.lua). The counts are then read afresh and
-- the tabs laid out again, which hides the bubble on the tab now up and puts back, or clears,
-- the one on the tab just left.
function Frame.SelectTab(name)
  -- Brief C2: the Chain tab is the Item chain view now, so a caller that still names the tab lands
  -- on the view instead of on whichever tab an unknown name falls to.
  if name == "Chain" then
    Frame.ShowChain()
    return Frame.tab or tabNames()[1]
  end
  local index = tabIndex(name)
  Frame.tab = tabNames()[index]
  local frame = Frame.frame
  if not frame then
    return Frame.tab
  end
  local setTab = rawget(_G, "PanelTemplates_SetTab")
  if type(setTab) == "function" then
    pcall(setTab, frame, index)
  end
  for position, button in ipairs(Frame.tabs or EMPTY) do
    paintTopTab(button, position == index)
  end
  updateTabPanes()
  clearTabCounts()
  Frame.RelayoutTabs()
  updateTitleText()
  return Frame.tab
end

-- Brief C2: every route that opened the Chain tab opens the Item chain view instead. The window goes
-- to the Item tree tab, opened on key where one is given (or on the root it is on), and the view is
-- set to the chain where that root has one; a root with no chain (a creature, a zone, a quest)
-- opens on its own view as any other open does. Answers whether the chain view is up afterwards.
function Frame.ShowChain(key)
  if Frame.Build() and Frame.Tab() ~= "Tree" then
    Frame.SelectTab("Tree")
  end
  key = key or Frame.rootKey or Frame.pendingKey
  if type(key) ~= "string" then
    return false
  end
  if key ~= Frame.rootKey or not Frame.IsShown() then
    if Frame.HasChainView(key) then
      Frame.Open(key, { view = Frame.CHAIN_VIEW })
    else
      Frame.Open(key)
    end
  elseif Frame.HasChainView(key) then
    Frame.SetView(Frame.CHAIN_VIEW)
  end
  return Frame.View() == Frame.CHAIN_VIEW
end

--- The tab strip brought into line with the settings: a tab that waits on a setting
--- (Frame.TabSettingKey) is shown the moment it is turned on and taken away the moment it is
--- turned off, with no reload. A tab taken away while it was up hands the window back to the
--- first tab. Nothing moves where the set of tabs has not changed. Answers the names drawn, and
--- the declared order where there is no window yet.
function Frame.SyncTabs()
  local frame = Frame.frame
  if not frame then
    return Frame.TabNames(Frame.tabsPresent, currentSettings())
  end
  local drawn, changed = applyTabSet(frame)
  if not changed then
    return drawn
  end
  local current = Frame.tab
  local still = false
  for _, name in ipairs(drawn) do
    if name == current then
      still = true
    end
  end
  if still then
    Frame.SelectTab(current)
  else
    Frame.SelectTab(drawn[1])
  end
  -- The tabs take a different width together, so the band is shared out again.
  Frame.FitBand()
  return drawn
end

--------------------------------------------------------------------------------
-- The view, the diff toggle and the text filter
--------------------------------------------------------------------------------

-- The view is fixed at the root, so changing it is a new model on the same key rather than an
-- option pushed into the one in hand. The new model carries no category filter, which is how a
-- filter picked in one view stops narrowing the next: the ids are the view's own and a
-- Reagents filter means nothing on the Sources tab.
--
-- A click here is the player's decision and the window never second guesses it: pressing a
-- dimmed tab shows that tab and its "nothing here" line rather than bouncing off it, and the
-- view then stays put as the player walks from item to item (see Frame.Open).
--
-- fromTab says the call came from the player pressing a view tab. Pressing the tab that is
-- already up asks for nothing, so it is answered with nothing: rebuilding the model there would
-- throw away the category filter the player has just picked, for no visible change. A
-- programmatic SetView, which is what a root change makes, has no flag and always rebuilds.
function Frame.SetView(view, fromTab)
  local wanted = Frame.ViewIndex(view) and view or Frame.DefaultView()
  if fromTab and wanted == Frame.View() then
    return Frame.View()
  end
  -- E61: the tab being left keeps its own notes, so a player who opens a list under Sources,
  -- reads Used by and presses Sources again finds it as they left it. Before the view moves.
  Frame.CapturePage()
  -- Remembered against this root's own set of tabs as well as as the last view set anywhere, so a
  -- creature's Loot and Map never overwrite the item tab the player left (brief E57).
  Frame.views[viewSet()] = wanted
  Frame.view = wanted
  -- Brief GW3 (2B): a pressed tab is the player's own, never the open rule's.
  if fromTab then
    Frame.autoViews[viewSet()] = nil
  end
  -- Brief C2: the last list view, which a stage clicked in the chain opens on (Frame.RowView).
  if wanted ~= Frame.CHAIN_VIEW then
    Frame.rowView = wanted
  end
  updateViewTabs()
  local ViewModel = ItemTree.ViewModel
  if Frame.rootKey and ViewModel and type(ViewModel.New) == "function" then
    local settings = ItemTree.db and ItemTree.db.settings
    Frame.vm = ViewModel.New(Frame.rootKey, Frame.View(), Frame.OptionsFromSettings(settings))
  end
  -- E61: and the tab being arrived at gets its own back, where this page has been on it before.
  -- A tab this page has not been on yet is untouched, which is the plain new model it always was,
  -- category filter and all.
  local stored = pageKey(Frame.rootKey)
  Frame.pendingState = restoreView(stored and Frame.memory.pages[stored] or nil) or Frame.PANE_TOP
  Frame.Refresh()
  Frame.pendingState = nil
  -- Brief RO1: the newest Recently viewed entry follows the tab, for the first open after a reload.
  Frame.NoteRecentView()
  return Frame.View()
end

-- The compatibility half of the contract, for a caller that still hands the window a direction:
-- down is the uses view and up is the sources view, which is the tab an up direction stood for
-- before requires existed. Answers the direction the window ends up walking, so a caller that
-- asked for up and landed on sources reads its own answer back.
function Frame.SetDirection(direction)
  local Edges = ItemTree.Edges
  local up = (Edges and Edges.UP) or "up"
  local view = Frame.DEFAULT_VIEW
  if direction == up then
    view = "sources"
    if Edges and type(Edges.ViewOf) == "function" then
      local ok, answer = pcall(Edges.ViewOf, direction)
      if ok and Frame.ViewIndex(answer) then
        view = answer
      end
    end
  end
  Frame.SetView(view)
  return Frame.Direction()
end

-- Brief E88: whether the Show classic diff tick box is on, for a reader outside the window. It is
-- session state held here (Frame.showChanges, never saved) and the one source the tree's change
-- rows read through Frame.OptionsFromSettings, so the item tooltip asks this and the two agree.
-- Anything but true reads as off. Pure.
function Frame.ShowChanges()
  return Frame.showChanges == true
end

-- The Show classic diff tick box. The change rows are a view model option, and the item info
-- column draws its own old to new values, so both are told.
function Frame.SetShowChanges(value)
  Frame.showChanges = value and true or false
  setChecked(Frame.diffToggle, Frame.showChanges)
  local InfoPanel = ItemTree.UI and ItemTree.UI.InfoPanel
  if InfoPanel and type(InfoPanel.SetShowChanges) == "function" then
    pcall(InfoPanel.SetShowChanges, Frame.showChanges)
  end
  local vm = Frame.vm
  if vm and type(vm.SetOptions) == "function" then
    vm:SetOptions(Frame.OptionsFromSettings(ItemTree.db and ItemTree.db.settings))
  end
  Frame.Refresh()
  return Frame.showChanges
end

-- The sidebar's search box. The tree pane is the one that narrows, so it is the one that is told.
function Frame.SetTextFilter(text)
  Frame.textFilter = (type(text) == "string" and text ~= "") and text or nil
  local Tree = ItemTree.UI and ItemTree.UI.Tree
  if Tree and type(Tree.SetTextFilter) == "function" then
    Frame.Guarded("Tree.SetTextFilter", Tree.SetTextFilter, Frame.textFilter)
  end
  return Frame.textFilter
end

-- The footer's Options button. Brief E76: the window stays where it is and the settings panel
-- opens over it. On the forever branch SettingsPanel is a managed UI panel (area "center",
-- Blizzard_Settings_Shared/Blizzard_Registration.lua), opened through ShowUIPanel; it is the
-- panel's close that runs CloseAllWindows (TransitionBackOpeningPanel, then ToggleGameMenu), and
-- CloseSpecialWindows hides every shown frame in UISpecialFrames. So, for as long as the panel is
-- up: the window is out of UISpecialFrames, which keeps the panel's X and the first Escape from
-- closing it; it sits at Frame.SETTINGS_STRATA, one under the panel that is HIGH and toplevel like
-- this window; and it is held on screen (holdWindow), a tick after this button and a tick after
-- the client's ShowUIPanel callback. A tick after the panel hides, RestoreEscape puts all of it
-- back. All of it runs from this click or from a timer, never inside the panel's own Show or Hide
-- (brief TX1).
function Frame.OpenOptions()
  -- Brief E91: the client refuses to show the settings panel in combat (ShowUIPanel), so the
  -- press is kept for when combat ends, and the window is left exactly as it is meanwhile: taking
  -- it out of UISpecialFrames for a panel that never came up would leave Escape dead.
  if Frame.InCombat() then
    Frame.AfterCombat(Frame.OpenOptions, "Frame.OpenOptions")
    return false
  end
  local wasShown = Frame.IsShown()
  if wasShown then
    Frame.settingsWasShown = true
    suspendEscape()
  end
  local Options = ItemTree.Options
  local opened = false
  if Options and type(Options.Open) == "function" then
    local ok, value = pcall(Options.Open)
    opened = ok and value ~= false
  end
  if not wasShown then
    return opened
  end
  -- A panel that never opened leaves nothing to hide, so the window goes straight back.
  if not opened then
    Frame.settingsWasShown = false
    Frame.RestoreEscape()
    return opened
  end
  -- Shown, not raised: the panel belongs on top of the window, and the window is a strata below
  -- it until the panel has gone.
  holdWindow()
  nextTick(holdWindow)
  return opened
end

-- Whether the recently viewed overlay is up, and the button painted to match, so the button
-- reads as open while its list is showing. The overlay can also be closed by Escape or by its
-- own close button, so this is asked on every refresh rather than only when the button is
-- pressed. Answers whether the overlay is showing.
function Frame.SyncHistoryButton()
  local History = ItemTree.UI and ItemTree.UI.History
  local open = false
  if History and type(History.IsShown) == "function" then
    local ok, shown = pcall(History.IsShown)
    open = ok and shown and true or false
  end
  if Frame.historyButton then
    paintHistoryButton(Frame.historyButton, open)
  end
  return open
end

-- The dice button's own state, from the one thing that can change it: whether this build has any
-- New in Forever items left to offer. Answers whether the button can be pressed.
function Frame.SyncRandomButton()
  local button = Frame.randomButton
  if not button then
    return false
  end
  return paintRandomButton(button, Frame.NewItemPoolSize() > 0)
end

-- The recently viewed list, which wave two builds as a modal over the window. Until it is there
-- the button does nothing rather than raising an error.
function Frame.ToggleHistory()
  local History = ItemTree.UI and ItemTree.UI.History
  if History and type(History.Toggle) == "function" then
    pcall(History.Toggle, Frame.frame)
    Frame.SyncHistoryButton()
    return true
  end
  return false
end

local function hideHistory()
  local History = ItemTree.UI and ItemTree.UI.History
  if History and type(History.Hide) == "function" then
    pcall(History.Hide)
    Frame.SyncHistoryButton()
    return true
  end
  return false
end

--------------------------------------------------------------------------------
-- Opening, refreshing and closing
--------------------------------------------------------------------------------

-- Brief SR1: every page opened goes into Recently viewed by its node key, not only an item. What
-- a key may be is Core/History.lua's to decide (History.KeyOf), so a key it refuses records nothing.
-- Brief RO1: with the view tab it opened on, which the newest entry keeps (History.Push), so the
-- first open after a reload or a logout lands on that page and that tab (Frame.OpenDefault).
local function recordView(key, view)
  local History = ItemTree.History
  if not (type(key) == "string" and History and type(History.Push) == "function") then
    return false
  end
  local clock = rawget(_G, "time")
  local now = type(clock) == "function" and clock() or nil
  local ok, entry = pcall(History.Push, key, now, view)
  return ok and entry ~= nil
end

-- Opens the window on a node key, building it the first time. Returns true when the window
-- opened, false where there is no client to build one on, which is what tells /itemtree show to
-- print the tooltip block instead.
--
-- opts is optional and takes one thing, opts.view: the view this open should land on. A caller
-- that knows which of the four questions the player was asking says so, and the window opens
-- there instead of on the view it was already on. The chain's disenchant signpost is the caller
-- that needs it: a click on one is the player asking for exactly that node's Disenchants into
-- tab, and the window has to draw once, rooted there, with that view up. A stage clicked in the
-- chain says Frame.RowView the same way, and Frame.ShowChain says the Item chain view (brief C2).
-- A view named that way is the same decision as a tab press, so it is the view the window then
-- sticks on until something changes it again.
--
-- The same key with a different view is not a root change, so nothing else about the window
-- moves: the view is swapped, the model is rebuilt on it, and the panes are handed the new one.
-- A view key the window does not know is ignored, and Frame.Open(key) with no opts at all is
-- exactly what it always was.
function Frame.Open(itemKey, opts)
  -- Brief PF1: /itprobe open is armed. The probe calls this very function back, timed, with the
  -- same arguments; nil (one table read) otherwise.
  local armed = ItemTree.openProbe
  if armed and not armed.openRun then
    return armed.TracedOpen(Frame.Open, itemKey, opts)
  end
  -- Read before anything can move the window: the open cue belongs to the window appearing, not
  -- to every call. Walking from item to item, picking a search result and pressing the dice all
  -- come through here with the window already up, and none of them is an open.
  local wasShown = Frame.IsShown()
  -- Brief RB3 (the owner's QA item 196): a dead twin quest's id opens its live quest's page.
  local Graph = ItemTree.Graph
  if type(Graph) == "table" and type(Graph.FoldTwinKey) == "function" then
    itemKey = Graph.FoldTwinKey(itemKey)
  end
  -- Brief VN1 (the owner's QA item 214): a Classic Era key of a vendor the client's own tables list
  -- under that very name opens the vendor's one page, named before it is drawn
  -- (Core/ForeverVendors.lua OpenKey).
  local vendors = ItemTree.ForeverVendors
  if itemKey ~= nil and type(vendors) == "table" and type(vendors.OpenKey) == "function" then
    local folded, onePage = pcall(vendors.OpenKey, itemKey)
    if folded and type(onePage) == "string" then
      itemKey = onePage
    end
  end
  -- Brief NP1 and NP3: a Trains row and a "Boss of" line open a tab, never a page.
  local special, answered = Frame.OpenSpecial(itemKey)
  if special then
    return answered == true
  end
  -- Brief E76: with the settings panel up, the window opens (or stays) under it, out of
  -- UISpecialFrames, and is held there until the panel goes. This used to put the window back at
  -- HIGH and back in the list, so a click on a row while the settings were open lifted the window
  -- over the panel, and the panel's close then ran CloseSpecialWindows and took the window with
  -- it, with nothing left to bring it back. With no panel up, the window is being opened on
  -- purpose and is not waiting on the settings any more: the show below is the one that counts.
  if Frame.SettingsPanelShown() then
    Frame.settingsWasShown = true
    suspendEscape()
  else
    Frame.settingsWasShown = false
    Frame.RestoreEscape()
  end
  Frame.pendingKey = itemKey or Frame.pendingKey
  local key = itemKey or Frame.rootKey or Frame.pendingKey
  -- Brief PF1: the window's first build, timed while an open is traced.
  local trace = ItemTree.openTrace
  local frame
  if trace and not Frame.frame then
    frame = trace.Span("window", nil, Frame.Build)
  else
    frame = Frame.Build()
  end
  if not (frame and key) then
    return false
  end
  -- Brief D2: a real page takes the place of the failed load's empty state.
  Frame.HideDataMissing()
  -- E61: what the player did to the page being left, written down before anything here moves,
  -- and then whether this arrival is a return to the page being opened. Both read the trail and
  -- the root as they stand now, so both come first.
  Frame.CapturePage()
  local page = recallPage(key, opts)
  -- Brief PW1: a window opened (or walked on) on purpose comes in front of the client's profession
  -- window again, and is raised below.
  Frame.professionsFront = false
  -- Never left at the strata the settings panel put it at once the panel has gone, and never lifted
  -- over the panel while it is up.
  setStrata(Frame.WindowStrata())
  -- An item cannot be opened onto a tab that does not draw one. The Discoveries tab is a list of
  -- what the realm has found and shows nothing about the root, so opening an item while it is up
  -- used to change a root nobody could see: the owner pressed a search result on that tab and
  -- nothing happened. Every route in lands here, so the rule is stated once rather than in each
  -- of them, and Frame.TAB_SHOWS_ROOT is where a new tab says which kind it is.
  --
  -- The Item chain view is a view of the Item tree tab (brief C2), so a chain that follows the item
  -- just opened is the sticky view rule below and nothing here. The two header dropdowns want the
  -- Item tree tab from Discoveries too; that is Frame.OpenPicked, below.
  if not Frame.TabShowsRoot(Frame.Tab()) then
    Frame.SelectTab("Tree")
  end
  -- The filter narrows one root's tree, so it does not follow the player to the next one. The
  -- box itself lives in the tree pane; this is the one entry point that clears it.
  local rooted = Frame.rootKey ~= key
  if rooted and Frame.textFilter then
    Frame.SetTextFilter(nil)
  end
  Frame.rootKey = key
  -- What this session has looked at, in memory only and never written to saved variables: it is
  -- what Frame.OpenDefault opens again when the window is asked for with nothing pointed at.
  Frame.lastRootKey = key
  -- The view is the player's and it sticks. Opening another item never moves it, not even when
  -- that item has nothing in the view they are on: the owner's words are that a tab changing
  -- under the hand on every item clicked is disorienting, and an empty view already says it is
  -- empty in its own line and its own count. The window used to walk a fall back order here
  -- instead, which is what made the tab jump about.
  --
  -- Two things move the view, and neither of them is a root change: the player pressing a view
  -- tab (Frame.SetView), and a caller opening an item on a view on purpose (opts.view, which is
  -- the chain signposts and the info panel's summary links). An explicit view is the same
  -- decision as a press, so it becomes the view that sticks from here on rather than lasting for
  -- the one call. The first open of a session has no view yet, so Frame.View answers
  -- Frame.DEFAULT_VIEW, which is uses.
  --
  -- Brief E57: the memory is per SET of tabs, so a root whose kind has a different set (a creature
  -- has Loot and Map) lands on its own default and leaves the item tab the player left exactly
  -- where it was, and coming back to an item lands on it again.
  -- Brief PR37: a gathering zone's open from the Professions tab lands on its Map view's group
  -- where the zone has one, and opens as any other open where it has none.
  opts = Frame.ZoneGroupOpts(key, opts)
  -- Brief NP1: a creature or NPC page opens on the tab that fits it (Frame.NpcOpenView), whatever
  -- tab the last page of its kind was left on and whatever this page was left on. On purpose, and
  -- for these pages only: an item's page keeps the sticky tab. A caller naming a view still wins.
  -- Brief RO1 (the owner's QA item 290, 2026-10-20: "if you close itemtree, when you open it up
  -- again without anything changing it should open to the same place"): so does the window brought
  -- back as it was closed (opts.reopen, Frame.OpenDefault and the Boss loot key with the window
  -- down), where it holds notes for the page: an NPC left on its Map comes back on its Map. A
  -- crumb, a click or the key on the creature still lands on the tab that fits.
  local reopened = type(opts) == "table" and opts.reopen == true and page ~= nil and Frame.ViewIndex(page.view) ~= nil
  local npcView = nil
  if not (type(opts) == "table" and Frame.ViewIndex(opts.view)) and not reopened then
    npcView = Frame.NpcOpenView(key)
    -- Brief BQ24 (QA item 25, the owner: "trainers should always open to map tab"): a page opened
    -- from a trainer row (the trainer search's results, a Trainer group's rows) lands on its Map.
    if type(opts) == "table" and opts.trainer then
      npcView = Frame.TrainerOpenView(viewKeys(key)) or npcView
    end
  end
  if type(opts) == "table" and Frame.ViewIndex(opts.view) then
    Frame.views[viewSet()] = opts.view
    Frame.view = opts.view
    if opts.view ~= Frame.CHAIN_VIEW then
      Frame.rowView = opts.view
    end
  elseif npcView and Frame.ViewIndex(npcView) then
    Frame.views[viewSet()] = npcView
  elseif page and Frame.ViewIndex(page.view) then
    -- E61, and the third thing that moves the view: coming back to a page lands on the tab it
    -- was left on, which is the player's own last decision about this very page. Only on a
    -- return, so walking on to a new item still keeps the tab that sticks.
    Frame.views[viewSet()] = page.view
    Frame.view = page.view
  else
    -- Brief GW3 (the owner's ruling 2B): an openable item with no uses opens on Contains, and the
    -- next one with uses on Used by again; a tab the player pressed is left alone.
    local set = viewSet()
    local held = Frame.views[set]
    if held == nil then
      held = Frame.view
    end
    local keys, auto = viewKeys(key), Frame.autoViews[set] == true
    -- The counts only for a page the rule can move (a Contains tab, the held view Used by or its own).
    local itemView = nil
    if Frame.ItemOpenView(keys, { [Frame.DEFAULT_VIEW] = 0 }, held, auto) ~= nil then
      itemView = Frame.ItemOpenView(keys, viewCounts(key), held, auto)
    end
    if itemView and Frame.ViewIndex(itemView) then
      Frame.views[set] = itemView
      if itemView == Frame.DEFAULT_VIEW then
        Frame.autoViews[set] = nil
      else
        Frame.autoViews[set] = true
      end
    end
  end
  -- Brief E97: an item opened from a boss's loot list carries where it came from, and the boss
  -- goes into the trail just before it.
  local bossKey = type(opts) == "table" and Frame.RememberBoss(opts.origin) or nil
  if bossKey then
    Frame.path = Frame.PushBossPath(Frame.path, bossKey, key, Frame.PATH_LIMIT)
  else
    Frame.path = Frame.PushPath(Frame.path, key, Frame.PATH_LIMIT)
  end
  Frame.ApplyScale()

  local ViewModel = ItemTree.ViewModel
  if ViewModel and type(ViewModel.New) == "function" then
    local settings = ItemTree.db and ItemTree.db.settings
    Frame.vm = ViewModel.New(key, Frame.View(), Frame.OptionsFromSettings(settings))
  end
  -- E61: the remembered expansion goes on the model here, before a single row is asked for, and
  -- the rest of the notes travel to the panes with the model. An arrival that is not a return
  -- hands them an empty table rather than nothing at all, which is what puts a new root's list at
  -- the top of itself; a plain refresh passes nothing and never moves the scroll.
  Frame.pendingState = restoreView(page) or Frame.PANE_TOP
  recordView(key, Frame.View())

  updateTitle()
  updateCaption()
  updateKeepSwitch()
  updateToggles()
  relayoutChrome()
  updateCrumbs()

  frame:Show()
  if not wasShown then
    playCue("open")
  end
  if type(frame.Raise) == "function" then
    frame:Raise()
  end
  -- Brief CT1b (QA item 227): the column learns the diff box's state before it draws, so the first
  -- open of a session draws it once rather than twice (the column starts on true, the window on
  -- false, and InfoPanel.SetShowChanges below drew it again with the other). Every later open finds
  -- the two agreeing and nothing here changes.
  local column = ItemTree.UI and ItemTree.UI.InfoPanel
  if Frame.regions and Frame.vm and type(column) == "table" and type(column.showChanges) == "boolean" then
    column.showChanges = Frame.showChanges == true
  end
  -- Brief PF1: the page draw (tree + info panel), timed while an open is traced. Brief CT1b (step
  -- 3): the tree may leave this view model's rows to the next frame (UI/Tree.lua Tree.DeferRows).
  Frame.openingVm = Frame.vm
  if trace then
    trace.Span("page", nil, handPanes)
  else
    handPanes()
  end
  Frame.openingVm = nil
  Frame.pendingState = nil
  local InfoPanel = ItemTree.UI and ItemTree.UI.InfoPanel
  if InfoPanel and type(InfoPanel.SetShowChanges) == "function" then
    pcall(InfoPanel.SetShowChanges, Frame.showChanges)
  end
  -- Brief P2: the search indexes, a slice a frame from the next frame on, so the first keystroke
  -- finds them built. Once per session; a no op on every later open.
  Frame.WarmSearchSlices()
  return true
end

-- Brief NP1 and NP3: the two keys a creature page's links carry that are no page of their own.
-- "profession:<line>" is a Trains row (Core/ViewModel.lua ProfessionKey) and opens the Professions
-- tab on that line; "bossentry:<entry>" is a "Boss of" line whose instance has no zone page and opens
-- the Boss loot tab at that boss. Neither ever becomes the window's root.
Frame.PROFESSION_KIND = "profession"
Frame.BOSS_ENTRY_KIND = "bossentry"

-- Whether a Trains row may open the Professions tab: the module loaded and its setting on
-- (UI/ProfessionsStub.lua Active), and its pane there to be told the line.
function Frame.ProfessionsLinked()
  local stub = ItemTree.UI and ItemTree.UI.ProfessionsStub
  if type(stub) ~= "table" or type(stub.Active) ~= "function" or type(stub.ModulePane) ~= "function" then
    return false
  end
  local ok, active = pcall(stub.Active)
  if not ok or active ~= true then
    return false
  end
  local found, pane = pcall(stub.ModulePane)
  return found and type(pane) == "table"
end

-- Brief NP1: the Professions tab, on one line. The line goes on the module's pane as the one it
-- shows (Pane.selected, which its strip picks where the player has the line), then the tab is
-- chosen. Answers whether the tab is up afterwards; false, and nothing moves, where the module is
-- not loaded or its setting is off.
function Frame.OpenProfessionLine(line)
  line = tonumber(line)
  if not line or not Frame.ProfessionsLinked() or not Frame.Build() then
    return false
  end
  local stub = ItemTree.UI.ProfessionsStub
  local _, pane = pcall(stub.ModulePane)
  pane.selected = line
  Frame.SelectTab(stub.TAB_NAME)
  return Frame.Tab() == stub.TAB_NAME
end

-- Brief NP3: the Boss loot tab at one boss entry, its place read off the shared model.
function Frame.OpenBossEntry(bossId)
  bossId = tonumber(bossId)
  local BossLoot = ItemTree.BossLoot
  if not bossId or type(BossLoot) ~= "table" or type(BossLoot.Shared) ~= "function" then
    return false
  end
  local ok, model = pcall(BossLoot.Shared)
  if not ok or type(model) ~= "table" or type(model.PlaceOf) ~= "function" then
    return false
  end
  local found, place = pcall(model.PlaceOf, model, bossId)
  if not found or place == nil then
    return false
  end
  return Frame.OpenBossRecord({ kind = "boss", place = place, boss = bossId, offsets = {} })
end

-- One of the two keys above, carried out: answers true and what the opener answered, or false for
-- any other key, which the caller opens as a page.
function Frame.OpenSpecial(key)
  local kind, id = parseKey(key)
  if kind == Frame.PROFESSION_KIND then
    return true, Frame.OpenProfessionLine(id)
  end
  if kind == Frame.BOSS_ENTRY_KIND then
    return true, Frame.OpenBossEntry(id)
  end
  return false, nil
end

if type(ItemTree.ViewModel) == "table" then
  ItemTree.ViewModel.professionsLinked = function()
    return Frame.ProfessionsLinked()
  end
end

-- Brief E97: a boss crumb pressed. The window goes back to the Boss loot tab with that place and
-- boss chosen and the lists scrolled where they were when the item was opened (the record
-- Frame.RememberBoss filed). The root and the trail stay as they are, so the Item tree tab still
-- holds the item and its trail. Answers whether the Boss loot tab is up afterwards; false, and
-- nothing moves, where the crumb is unknown or the tab is not in the strip (its setting is off).
function Frame.OpenBossCrumb(key)
  return Frame.OpenBossRecord(Frame.bossCrumbs[key])
end

-- The Boss loot tab with one record's place and boss chosen (a crumb's, or brief NP3's made on the
-- spot), its lists at the record's offsets. Answers whether the tab is up afterwards; false, and
-- nothing moves, for no record or where the tab is not in the strip (its setting is off).
function Frame.OpenBossRecord(record)
  if type(record) ~= "table" or not Frame.Build() then
    return false
  end
  local present = false
  for _, name in ipairs(tabNames()) do
    if name == Frame.BOSS_TAB then
      present = true
    end
  end
  if not present then
    return false
  end
  local pane = ItemTree.UI and ItemTree.UI[Frame.BOSS_TAB]
  if type(pane) == "table" and type(pane.RestoreSnapshot) == "function" then
    pcall(pane.RestoreSnapshot, record)
  end
  Frame.SelectTab(Frame.BOSS_TAB)
  return Frame.Tab() == Frame.BOSS_TAB
end

-- An item picked out of one of the two dropdowns in the header: the global search list and the
-- Recently viewed panel. UI/History.lua's row click comes here too, so the two picks behave the
-- same.
--
-- A pick is a jump to an item rather than a step through the graph, so it always lands on the
-- Item tree tab, from Discoveries or Boss loot as well: the player asked to look at that item.
-- Everything else is Frame.Open, the view included, so the sticky view survives the jump (the
-- Item chain view among them, brief C2) and the window still opens once, on one root, with one
-- breadcrumb step. Answers what Frame.Open answered.
-- opts is Frame.Open's, and a pick that says nothing is a RETURN (brief E61): the Recently viewed
-- panel is the player naming a page they want back, so it comes back as they left it. The search
-- dropdown and the dice are picks too and neither is that, so both say restore = false below.
function Frame.OpenPicked(itemKey, opts)
  -- Brief NP1 and NP3: a key that opens a tab goes there, and never by way of the Tree tab.
  local special, answered = Frame.OpenSpecial(itemKey)
  if special then
    return answered == true
  end
  -- The tab is set before the open so the pane that ends up drawn is handed the new root once.
  -- Guarded on the window existing, because the very first pick can be what builds it, and a
  -- window that is still a stub has no tab to select.
  if Frame.Build() then
    Frame.SelectTab("Tree")
  end
  if type(opts) ~= "table" then
    opts = { restore = true }
  end
  return Frame.Open(itemKey, opts)
end

-- The dice button pressed. One press, one item: a New in Forever item picked at random and then
-- opened exactly as a pick out of the search dropdown is, so it lands on the Tree tab from
-- wherever the window was, records in Recently viewed like any other open and leaves the sticky
-- view tab alone. The id is remembered so the next press cannot land on it again.
--
-- The pick is local data and nothing else: no item query goes out over the pool, and the one
-- item that comes back is opened through the window's own path, which is the only thing that
-- ever asks the client about it. rng is handed through for the specs.
--
-- Answers false where the build has nothing new, which is also when the button is disabled, so a
-- press that somehow arrives anyway does nothing rather than opening the wrong thing.
function Frame.OpenRandomNew(rng)
  local itemId = Frame.RandomNewItemId(rng)
  if not itemId then
    return false
  end
  Frame.lastRandomId = itemId
  -- E61: the dice is the one button that is entirely about arriving somewhere new, so it starts
  -- the page fresh even on the rare press that lands on an item this session has seen.
  return Frame.OpenPicked(itemNodeKey(itemId), { restore = false })
end

-- Brief D2: the empty state for a build whose ItemTree_Data did not load. The window still opens,
-- so the player has somewhere to read why: the headline for the reason, the reason in brackets,
-- the numbered steps, and (brief D5) an Open AddOns button. It sits over the content area on its
-- own surface, above every pane, and goes the moment the window opens on a real page.

-- Whether this client can open its AddOns list from Lua. On the forever branch the game menu's
-- AddOns entry is ShowUIPanel(AddonList) (Blizzard_GameMenu/Shared/GameMenuFrame.lua), and
-- Blizzard_AddOnList loads with the interface, not on demand, so the frame is there to show.
function Frame.AddOnsPanelAvailable()
  local list = rawget(_G, "AddonList")
  return type(list) == "table" and type(list.Show) == "function"
end

-- The button's own click: the client's AddOns list, which the player asked for. ShowUIPanel is
-- the game menu's way in, but the taint rule keeps ItemTree off the panel manager (it moves the
-- client's own panel layout, tests/spec/taint_lint_spec.lua), so the list gets a plain Show: its
-- XML anchors it at the centre (Blizzard_AddOnList/AddonList.xml), it is not protected, and its
-- Okay and Cancel go through HideUIPanel, which falls back to a plain Hide for a panel the manager
-- did not place (Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua), all on branch
-- forever. The list sits at the centre under this window's HIGH strata, so the window goes first.
-- Answers whether the list was shown.
function Frame.OpenAddOns()
  if not Frame.AddOnsPanelAvailable() then
    return false
  end
  Frame.Hide()
  local list = rawget(_G, "AddonList")
  local ok = pcall(list.Show, list)
  return ok
end

local function buildAddOnsButton(parent)
  local button, template = newFrame("Button", nil, parent, "UIPanelButtonTemplate")
  if not button then
    return nil
  end
  button.panelTemplate = template
  button:SetSize(Frame.DATA_MISSING_BUTTON_W, size("ITEMTREE_CONTROL_H_MD"))
  if template then
    -- The template's own word is hidden rather than written to, as on the dice button: a font
    -- string the client made may carry no font.
    local text = child(button, "Text")
    if text and type(text.Hide) == "function" then
      pcall(text.Hide, text)
    end
  else
    button.plate = panelButtonArt(button)
    if not button.plate then
      button.background = fillTexture(button, "BACKGROUND", "ITEMTREE_COLOR_BUTTON_ACCENT_DIM")
      if button.background then
        button.background:SetAllPoints(button)
      end
      button.edges = outline(button, "ITEMTREE_COLOR_BORDER_GOLD")
    end
  end
  local label = newFontString(button, "ITEMTREE_FONT_BODY", "ITEMTREE_FONTSIZE_BODY_MD", "ITEMTREE_COLOR_TEXT_TITLE")
  if label then
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    setText(label, L["Open AddOns"])
    button.label = label
  end
  button:SetScript("OnClick", function()
    Frame.OpenAddOns()
  end)
  if not template then
    button:SetScript("OnMouseDown", function(self)
      paintPanelButton(self, "pushed")
    end)
    button:SetScript("OnMouseUp", function(self)
      paintPanelButton(self, "normal")
    end)
  end
  return button
end

local function wrapLine(fontString, width)
  if type(fontString) ~= "table" then
    return
  end
  fontString:SetWidth(width)
  if type(fontString.SetJustifyH) == "function" then
    pcall(fontString.SetJustifyH, fontString, "CENTER")
  end
  if type(fontString.SetWordWrap) == "function" then
    pcall(fontString.SetWordWrap, fontString, true)
  end
  if type(fontString.SetMaxLines) == "function" then
    pcall(fontString.SetMaxLines, fontString, 0)
  end
end

local function buildDataMissing()
  if Frame.dataMissing then
    return Frame.dataMissing
  end
  local content = Frame.content
  if not content then
    return nil
  end
  local block = newFrame("Frame", nil, content)
  if not block then
    return nil
  end
  block:SetAllPoints(content)
  raiseInto(block, content, 50)
  -- Its own surface, so no pane drawn under it shows through.
  local surface = fillTexture(block, "BACKGROUND", "ITEMTREE_COLOR_SURFACE_FRAME", 1)
  if surface then
    surface:SetAllPoints(block)
  end
  local width = Frame.DATA_MISSING_W
  local heading = newFontString(block, "ITEMTREE_FONT_TITLE", "ITEMTREE_FONTSIZE_TITLE_SM", "ITEMTREE_COLOR_TEXT_TITLE")
  if heading then
    wrapLine(heading, width)
    heading:SetPoint("BOTTOM", block, "CENTER", 0, size("ITEMTREE_SPACE_2"))
  end
  -- The numbered steps, one a line, under the headline and over the button, centred like the rest.
  -- Brief SR3: no reason line between them any more.
  local steps = newFontString(block, "ITEMTREE_FONT_BODY", "ITEMTREE_FONTSIZE_BODY_MD", "ITEMTREE_COLOR_TEXT_BODY")
  if steps then
    wrapLine(steps, width)
    steps:SetPoint("TOP", heading or block, heading and "BOTTOM" or "CENTER", 0, -size("ITEMTREE_SPACE_3"))
  end
  -- No button at all on a client that cannot open its AddOns list; the steps stand alone.
  local button
  if Frame.AddOnsPanelAvailable() then
    local above = steps or heading
    button = buildAddOnsButton(block)
    if button then
      button:SetPoint("TOP", above or block, above and "BOTTOM" or "CENTER", 0, -size("ITEMTREE_SPACE_4"))
    end
  end
  block.heading, block.steps, block.button = heading, steps, button
  block:Hide()
  Frame.dataMissing = block
  return block
end

-- Takes the empty state away. Frame.Open calls it, so a real page always replaces it.
function Frame.HideDataMissing()
  local block = Frame.dataMissing
  if block and type(block.Hide) == "function" then
    block:Hide()
  end
  Frame.dataMissingShown = false
  Frame.pageErrorShown = false
end

-- Whether the window is up on the empty state for a failed load.
function Frame.DataMissingShown()
  return Frame.dataMissingShown == true and Frame.IsShown()
end

-- Opens the window on that empty state, or closes it when it is already up on it, so the key and
-- the minimap click stay a toggle. Answers whether the window is open afterwards.
function Frame.OpenDataMissing(reason)
  if Frame.DataMissingShown() then
    Frame.Hide()
    return false
  end
  local wasShown = Frame.IsShown()
  local frame = Frame.Build()
  if not frame then
    return false
  end
  -- The settings panel rule Frame.Open follows (brief E76).
  if Frame.SettingsPanelShown() then
    Frame.settingsWasShown = true
    suspendEscape()
  else
    Frame.settingsWasShown = false
    Frame.RestoreEscape()
  end
  -- Brief PW1: opened on purpose, so in front of the client's profession window, as Frame.Open.
  Frame.professionsFront = false
  setStrata(Frame.WindowStrata())
  if not Frame.TabShowsRoot(Frame.Tab()) then
    Frame.SelectTab("Tree")
  end
  Frame.ApplyScale()
  pcall(updateTitle)
  local block = buildDataMissing()
  if block then
    reason = reason or Frame.DataMissingReason()
    setText(block.heading, Frame.DataMissingLines(reason))
    if block.steps then
      setText(block.steps, table.concat(Frame.DataMissingSteps(reason), "\n"))
    end
    if block.note then
      block.note:Hide()
    end
    Frame.pageErrorShown = false
    if block.button then
      if Frame.DataMissingWantsAddOns(reason) then
        block.button:Show()
      else
        block.button:Hide()
      end
    end
    block:Show()
  end
  Frame.dataMissingShown = true
  frame:Show()
  if not wasShown then
    playCue("open")
  end
  if type(frame.Raise) == "function" then
    frame:Raise()
  end
  return true
end

--------------------------------------------------------------------------------
-- Brief G1: the boundary around every page draw
--------------------------------------------------------------------------------

-- Every way the window draws or redraws a page runs under Core/Guard.lua's boundary, through
-- Frame.Guarded. Only the OUTERMOST guarded call catches: a guarded call made while one is already
-- running (Frame.OpenPicked calling Frame.Open, a pane's Show inside Frame.Refresh) calls straight
-- through, so an error unwinds to the one boundary the player's action started at and the page is
-- either whole or replaced by one empty page. With Guard.strict on (the whole busted suite), or
-- with no Guard loaded, nothing is caught at all.
--
-- What each guarded place is: "open" opens the window, so a failure still shows it, on the empty
-- page; "redraw" draws the whole page again, so a success takes an earlier empty page down; any
-- other place ("part", the default) redraws a piece of the page and leaves the empty page as it
-- is either way, because the rest of the page under it is still the half drawn one.
Frame.GUARD_KINDS = {
  ["Frame.Open"] = "open",
  ["Frame.OpenPicked"] = "open",
  ["Frame.OpenSearchResult"] = "open",
  ["Frame.OpenRandomNew"] = "open",
  ["Frame.OpenDefault"] = "open",
  ["Frame.OpenDataMissing"] = "open",
  ["Frame.Toggle"] = "open",
  ["Frame.ShowChain"] = "open",
  ["Frame.OpenBossCrumb"] = "redraw",
  ["Frame.SelectTab"] = "redraw",
  ["Frame.SetView"] = "redraw",
  ["Frame.SetDirection"] = "redraw",
  ["Frame.SetShowChanges"] = "redraw",
  ["Frame.SyncTabs"] = "redraw",
  ["Frame.Refresh"] = "redraw",
  ["Frame.RefreshFromSettings"] = "redraw",
  ["BossLoot.SelectPlace"] = "redraw",
  ["BossLoot.SelectBoss"] = "redraw",
  ["Frame.SetTextFilter"] = "part",
  ["Frame.SetKeepOverride"] = "part",
}

-- The Frame functions wrapped at the foot of this file, by the place name they are filed under.
Frame.GUARDED = {
  "Open",
  "OpenPicked",
  "OpenSearchResult",
  "OpenRandomNew",
  "OpenDefault",
  "OpenDataMissing",
  "Toggle",
  "ShowChain",
  "OpenBossCrumb",
  "SelectTab",
  "SetView",
  "SetDirection",
  "SetShowChanges",
  "SyncTabs",
  "Refresh",
  "RefreshFromSettings",
  "SetTextFilter",
  "SetKeepOverride",
}

Frame.guardDepth = 0

--- Calls fn(...) at the boundary named where. Answers true and fn's answers, or false where fn
--- raised and the boundary caught it (the error is recorded, handed to the client's error handler
--- and the empty page is up).
function Frame.GuardedRun(where, fn, ...)
  local Guard = ItemTree.Guard
  if type(Guard) ~= "table" or type(Guard.Run) ~= "function" or Guard.strict or Frame.guardDepth > 0 then
    return true, fn(...)
  end
  Frame.guardDepth = 1
  return Frame.AfterGuard(where, Guard.Run(where, fn, ...))
end

-- The outermost boundary's answer, with the page brought into line with it.
function Frame.AfterGuard(where, ok, ...)
  Frame.guardDepth = 0
  local kind = Frame.GUARD_KINDS[where] or "part"
  if ok then
    if kind ~= "part" then
      Frame.HidePageError()
    end
    return true, ...
  end
  -- Nothing half way through an open may ride along to the next draw.
  Frame.pendingState = nil
  Frame.ShowPageError(kind == "open")
  return false
end

function Frame.GuardedResults(ok, ...)
  if ok then
    return ...
  end
  return false
end

--- Frame.GuardedRun, answering fn's own answers, or false where it raised and was caught.
function Frame.Guarded(where, fn, ...)
  return Frame.GuardedResults(Frame.GuardedRun(where, fn, ...))
end

--- Whether the window is up on the empty page a failed draw leaves.
function Frame.PageErrorShown()
  return Frame.pageErrorShown == true and Frame.IsShown()
end

--- Takes the empty page down, where it is the failed draw's (never the failed load's, brief D2).
function Frame.HidePageError()
  if not Frame.pageErrorShown then
    return false
  end
  Frame.pageErrorShown = false
  local block = Frame.dataMissing
  if block and type(block.Hide) == "function" then
    pcall(block.Hide, block)
  end
  return true
end

-- The empty page itself: the failed load's surface and layout (brief D2), with the heading saying
-- the page could not be shown and one muted line saying where the details are. No button.
function Frame.DrawPageError(openWindow)
  local block = buildDataMissing()
  if not block then
    return false
  end
  setText(block.heading, L["This page could not be shown"])
  if block.steps then
    setText(block.steps, "")
  end
  if block.button then
    block.button:Hide()
  end
  if not block.note then
    local note = newFontString(block, "ITEMTREE_FONT_BODY", "ITEMTREE_FONTSIZE_BODY_MD", "ITEMTREE_COLOR_TEXT_MUTED")
    if note then
      wrapLine(note, Frame.DATA_MISSING_W)
      note:SetPoint("TOP", block.heading or block, block.heading and "BOTTOM" or "CENTER", 0, -size("ITEMTREE_SPACE_3"))
    end
    block.note = note
  end
  if block.note then
    setText(block.note, L["The details are in /itemtree debug"])
    block.note:Show()
  end
  block:Show()
  Frame.dataMissingShown = false
  Frame.pageErrorShown = true
  local frame = Frame.frame
  if openWindow and frame and type(frame.Show) == "function" then
    frame:Show()
  end
  return true
end

--- Puts the empty page up over the content area, and shows the window where the failed call was
--- opening it. The header, the search box, Recently viewed and the close button stay usable, and
--- the next page drawn whole takes it down. Never raises: a fault here goes to the boundary too.
function Frame.ShowPageError(openWindow)
  local Guard = ItemTree.Guard
  if type(Guard) == "table" and type(Guard.Run) == "function" then
    local ok, drawn = Guard.Run("Frame.ShowPageError", Frame.DrawPageError, openWindow)
    return ok and drawn == true
  end
  local ok, drawn = pcall(Frame.DrawPageError, openWindow)
  return ok and drawn == true
end

-- The window asked for with nothing pointed at: the key binding pressed with no item under the
-- cursor, and a left click on the minimap button. Both come here, so the two agree.
--
-- The owner's rule. An item this session has already shown is what the player wants back, so the
-- window opens on it again, on the tab and the view it was left on, and through Frame.Toggle, so
-- the key stays a toggle: a press with that window already up closes it. Brief RO1 (item 290,
-- 2026-10-20: "if there is a recent history it should actually open to the most recent item
-- instead (i.e. the previous state before you logged out)"): the first open of a session opens the
-- newest page in Recently viewed, on the tab it was on (Core/History.lua History.Last). Only with
-- Recently viewed empty does it pick anything, and it picks the way the dice button does, out of
-- the New in Forever pool, rather than out of the whole database. A build that added nothing falls
-- back to the older pick of anything worth opening, so the key is never dead.
--
-- Frame.lastRootKey and the page notes are fields on this table, so a fresh session has neither;
-- what it reads is Recently viewed's own saved list, whose newest entry carries the tab. rng is
-- handed through for the specs.
--
-- Answers two things: whether the window is open afterwards, and which of "last", "recent", "new",
-- "random", "missing" (the data failed to load, brief D2) and "none" happened, which is the one
-- chat line's whole decision. A pick that comes
-- back with nothing falls through to the next way rather than answering nothing at all.
function Frame.OpenDefault(rng)
  -- Brief BQ24 (QA item 27): an open with nothing pointed at returns to the tab the window was
  -- closed on (Frame.SavedTab), read before anything below moves the tab. The item the page is
  -- rooted on is chosen as before, so the Item tree tab is the same page when the player goes back.
  local saved = nil
  if not Frame.IsShown() then
    saved = Frame.SavedTab()
  end
  local opened, choice = Frame.OpenDefaultPage(rng)
  -- Checked against the tabs the window built, once it is built.
  local returnTo = opened and Frame.ReturnTab(saved, tabNames()) or nil
  if returnTo and returnTo ~= Frame.Tab() then
    Frame.SelectTab(returnTo)
  end
  return opened, choice
end

-- The page half of Frame.OpenDefault (the last item, else the newest Recently viewed page, else a
-- pick); answers opened and the choice.
function Frame.OpenDefaultPage(rng)
  -- Asked first: the pool is what loads ItemTree_Data, and a failed load (brief D2) is what keeps
  -- the window off a remembered page it could not draw, for the empty state that says why.
  local hasNewPool = Frame.NewItemPoolSize() > 0
  local recentKey, recentView = nil, nil
  if Frame.lastRootKey == nil and not Frame.DataMissingReason() then
    recentKey, recentView = Frame.LastRecentPage()
  end
  local choice = Frame.DefaultOpenChoice(Frame.lastRootKey, hasNewPool, recentKey)
  if choice == "last" then
    -- E61: the item this session last showed is the page the player wants BACK, opened lists,
    -- scroll, tab and all, whether the window was closed on it or walked away from it. Brief RO1:
    -- and nothing asked for anything new, so the page's own tab wins over a creature's fitting one.
    return Frame.Toggle(Frame.lastRootKey, { restore = true, reopen = true }), "last"
  end
  if choice == "recent" then
    -- Brief RO1: the page before the reload or the logout, on the tab it was on. The tab is named
    -- the way a caller names one (opts.view), so it is the tab that sticks, as it was; a tab the
    -- page no longer has is ignored and the page opens as any other open would.
    return Frame.Toggle(recentKey, { restore = true, reopen = true, view = recentView }), "recent"
  end
  if choice == "new" and Frame.OpenRandomNew(rng) then
    return true, "new"
  end
  local Data = ItemTree.Data
  if Data and type(Data.RandomItem) == "function" then
    local ok, itemId = pcall(Data.RandomItem, Data, rng)
    if ok and type(itemId) == "number" then
      return Frame.OpenPicked(itemNodeKey(itemId)), "random"
    end
  end
  -- Brief D2: nothing to pick because ItemTree_Data did not load. The window still opens, on the
  -- empty state that says why, so the player has somewhere to read it.
  local reason = Frame.DataMissingReason()
  if reason then
    return Frame.OpenDataMissing(reason), "missing"
  end
  return false, "none"
end

-- Re-hands the current model to every pane. The panes call this after they mutate the model
-- (vm:Toggle, vm:ShowMore, vm:SetFilter), so nothing else has to know what changed.
function Frame.Refresh()
  if not (Frame.frame and Frame.vm) then
    return false
  end
  updateToggles()
  updateKeepSwitch()
  updateCrumbs()
  -- The counts beside the words follow the settings and the root, so they are worked out again
  -- on every refresh rather than only when the view changes. That goes for the top tabs too: a
  -- discovery arriving while the window is open changes the number in brackets on one of them.
  relayoutChrome()
  Frame.SyncHistoryButton()
  Frame.SyncRandomButton()
  return handPanes()
end

-- Rebuilds the model options from ItemTree.db.settings and refreshes. Options.OnChanged calls
-- this, so a setting changed in the panel reaches the open window.
function Frame.RefreshFromSettings()
  -- A setting can bring a tab or take one away (Frame.TabSettingKey), which needs only the window.
  if Frame.frame then
    Frame.SyncTabs()
  end
  if not (Frame.frame and Frame.vm) then
    return false
  end
  local settings = ItemTree.db and ItemTree.db.settings
  if type(Frame.vm.SetOptions) == "function" then
    Frame.vm:SetOptions(Frame.OptionsFromSettings(settings))
  end
  -- settings.windowScale reaches the window through here, and a new scale changes what fits on
  -- the screen, so the rect is clamped again with it.
  Frame.ApplyWindow()
  return Frame.Refresh()
end

function Frame.IsShown()
  local frame = Frame.frame
  if not (frame and type(frame.IsShown) == "function") then
    return false
  end
  return frame:IsShown() and true or false
end

function Frame.Hide()
  -- Cleared first: the window is being closed on purpose, so RestoreEscape must not put it back
  -- on screen because the settings panel had it open a moment ago. RestoreEscape runs before the
  -- Hide so the suspension is down and the OnHide hook voices the close.
  Frame.settingsWasShown = false
  pcall(Frame.RestoreEscape)
  -- E61: the page is written down on the way down, so the key that reopens the last item brings
  -- it back as it was left. The window's own OnHide does this as well, for Escape and for
  -- CloseSpecialWindows, and writing the same notes twice costs nothing.
  pcall(Frame.CapturePage)
  -- Brief BQ24: the tab it is closed on (the OnHide hook writes it too, for Escape).
  pcall(Frame.RememberTab)
  local frame = Frame.frame
  if not (frame and type(frame.Hide) == "function") then
    return false
  end
  -- Brief E91: the Hide comes before everything that tidies up after it, and nothing ahead of it
  -- can raise, so no refusal in combat can leave the window on screen.
  --
  -- No cue here: the close cue hangs off the window's own OnHide (see hookWindowHide), so this
  -- path and the ones that never come through here sound the same. The Recently viewed overlay
  -- plays the same cue as it is taken down a line below, and UI/Sound.lua's throttle is what
  -- turns the pair into the one sound a single click should make.
  pcall(frame.Hide, frame)
  pcall(Frame.CloseSearch)
  hideHistory()
  return true
end

-- Brief RO1: PLAYER_LOGOUT, which a /reload fires too. A window still up has not been closed, so
-- nothing has written down the top tab it is on (Frame.RememberTab, per character) or the view
-- tab its page is on (Frame.NoteRecentView, on the newest Recently viewed entry); both are written
-- here, so the first open of the next session comes back to the same place. A window that is
-- down wrote its top tab as it closed, and the view tab goes down whenever it moves (Frame.Open,
-- Frame.SetView), so this is belt and braces for the second. Answers whether the window was up.
function Frame.OnLogout()
  if not Frame.IsShown() then
    return false
  end
  pcall(Frame.RememberTab)
  pcall(Frame.NoteRecentView)
  return true
end

-- Closes the window when it is already rooted on this key, opens it on the key otherwise.
-- Returns true when the window opened and false when it closed or could not open.
--
-- opts is Frame.Open's and is handed straight on, which is how Frame.OpenDefault says that
-- reopening the last item is a return (brief E61). A caller that says nothing, which is the key
-- binding with an item under the cursor, leaves the decision to the trail.
function Frame.Toggle(itemKey, opts)
  if itemKey and Frame.rootKey == itemKey and Frame.IsShown() then
    Frame.Hide()
    return false
  end
  return Frame.Open(itemKey, opts)
end

-- What one event means to the window: the professions cache is dropped when the client says the
-- player's skills moved, and the window is scaled and clamped again when UIParent changes shape,
-- because what 1x means is worked out from the screen.
function Frame.OnEvent(event)
  if event == Frame.LOGOUT_EVENT then
    return Frame.OnLogout()
  end
  if event == "PLAYER_REGEN_ENABLED" then
    return Frame.RunAfterCombat()
  end
  if event == "PLAYER_REGEN_DISABLED" then
    return Frame.RunCombatStart()
  end
  for _, name in ipairs(Frame.SCALE_EVENTS) do
    if name == event then
      return Frame.ApplyWindow()
    end
  end
  return Frame.InvalidateSkills()
end

-- Brief G1: the entry points above, each wrapped once at load in the boundary (Frame.Guarded).
-- These are ItemTree's own functions; nothing of the client's is wrapped. The bodies stay on
-- Frame.unguarded for a reader that wants one without the boundary.
Frame.unguarded = {}
for _, name in ipairs(Frame.GUARDED) do
  local body = Frame[name]
  if type(body) == "function" then
    local where = "Frame." .. name
    Frame.unguarded[name] = body
    -- Brief CT1b: with the root's views held for the call (Frame.HoldingViews).
    Frame[name] = function(...)
      return Frame.HoldingViews(Frame.Guarded, where, body, ...)
    end
  end
end

-- Each registration is taken on its own, so an engine that has dropped one of these events costs
-- us that event and not the rest.
local createFrameGlobal = rawget(_G, "CreateFrame")
if type(createFrameGlobal) == "function" then
  local ok, watcher = pcall(createFrameGlobal, "Frame")
  if ok and type(watcher) == "table" and type(watcher.RegisterEvent) == "function" then
    for _, event in ipairs(Frame.SKILL_EVENTS) do
      pcall(watcher.RegisterEvent, watcher, event)
    end
    for _, event in ipairs(Frame.SCALE_EVENTS) do
      pcall(watcher.RegisterEvent, watcher, event)
    end
    for _, event in ipairs(Frame.COMBAT_EVENTS) do
      pcall(watcher.RegisterEvent, watcher, event)
    end
    pcall(watcher.RegisterEvent, watcher, Frame.LOGOUT_EVENT)
    pcall(watcher.SetScript, watcher, "OnEvent", function(_, event)
      Frame.OnEvent(event)
    end)
    Frame.skillWatcher = watcher
  end
end

return Frame
