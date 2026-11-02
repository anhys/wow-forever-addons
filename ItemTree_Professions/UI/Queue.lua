-- The craft queue tray (brief PR18). The owner's words: "We want what some other addons do: queue
-- up items for work and create them ... display it to the user in its own mini window or tray
-- (similar to the vendors tray) and start creating all." Recommended recipes always come first, and
-- the tray warns where a Recommended recipe could be made more often with vendor-bought reagents
-- (Coarse Thread, Mild Spices). A recipe that goes grey leaves every queue.
--
-- Brief PR21 (QA round 5), the new flow. A band's Create all button (UI/Pane.lua, Core/Craft.lua
-- Craft.Click) calls Queue.OpenFor inside its click: the band's queue is built (one row a recipe,
-- duplicates merged, Recommended first), the profession window is opened (brief PR39: the ItemTree
-- window stays open), and the tray shows docked to the RIGHT of the profession window (to its left where the
-- screen has no room on the right, centred where there is no window), so nothing of ours sits over
-- it. NOTHING is crafted on that click. Each press of the tray's Start craft queue (then Craft next,
-- or Resume while paused) is ONE C_TradeSkillUI.CraftRecipe call, for the current row's remaining
-- count; the key binding "Create next in the ItemTree queue" (ItemTree's own Bindings.xml,
-- ITEMTREE_CRAFTNEXT, through UI/ProfessionsStub.lua CraftNext to Queue.Binding) is the same press.
-- Proven in game on 2026-10-01: CraftRecipe starts nothing with the profession window shut (so a
-- press with it shut opens it and asks for another press), and a call chained from the completion
-- event is ADDON_ACTION_BLOCKED (so press mode is the norm; the auto chain stays for a client that
-- ever proves otherwise, Craft.AutoChain). Closing the tray never reopens ItemTree; its "Back to
-- ItemTree" link does.
--
-- The tray, top to bottom: the title row (with the link and the close button), the controls
-- (brief PR38: ONE main button, [Start craft queue], [Craft next], [Pause] while a craft or batch
-- runs, [Resume] or [Switch to Cooking], then [Skip] and [Clear]), the progress, whole-queue total
-- and status lines, then the groups in their scroll area (brief PR35). Normal sized UI:
-- GameFontNormal and GameFontHighlight, 32 px icons, 38 px rows, 24 px plate buttons.
--
-- Brief PR38 (owner QA, 2026-10-02): one main button, and rows show the crafted item's own tooltip
-- (and a reagent's) beside the tray. Its "open profession goes first" rule was replaced by brief
-- PR39 (owner QA, 2026-10-03):
--   A. Pause stops the cast under way: a secure button of our own (the client's
--      SecureActionButtonTemplate running /stopcasting) sits over the main button while a craft runs,
--      made and moved only out of combat lockdown (Queue.SyncStop, Queue.StopClick).
--   B. Each queued row reads "- x12 +" with its X in the card's top right corner; a count the
--      player set is kept (Queue.RowMost, Queue.StepRow, entry.set).
--   C. Newest group on top: Craft all puts its group first (Queue.AddGroup) and the next row is the
--      top group's; "Switch to Cooking" where the top group's window is not the one that shows.
--   D. Craft all leaves the ItemTree window open. E. (withdrawn by brief PR40) F. Row tooltips touch
--      the tray's edge. G. No wash behind the shopping list's title, more padding. I. A need only the
--      profession's own window can check says so ("Cooking Fire: open Cooking to check").
--
-- Brief PR40 (owner QA, 2026-10-03):
--   A. PR39 item E made the tray a child of the profession window, and the client's gamepad code
--      walked that window's frame tree into our tray and was tainted (ADDON_ACTION_FORBIDDEN on
--      SetPreferredGamepadInteractTarget). The tray is on UIParent at HIGH always (Queue.HoldTray)
--      and never calls anything on the client's window; it still hides with the window through the
--      close events and its watch, never through parenting.
--   B. The main button IS the secure button (the client's SecureActionButtonTemplate, on UIParent,
--      over a slot the tray lays out): type "macro" with "/stopcasting" only while the queue's craft
--      is being cast, no type at every other time; our own handling runs in its raw PostClick, once
--      a press (Queue.ActsOn). /itemtree queuedemo stopprobe prints what each press did.
--   C. One X size (REMOVE) for rows and group headers; small "-" and "+" (STEP) on the line under
--      the X, right aligned with it; no bar under the group header.
--   D. Recommended is an "R" badge right of the name, with a tooltip. E. A Requirements line with
--      no tick or cross starts at the box's padding. F. "3 of 12 crafts done, 2 recipes".
--
-- Brief PR27 (the owner, 2026-10-02): "craft as many recipes as possible in this band, preferring
-- recommended items, but only queue enough to get to the next level". Each row is sized from the
-- player's rank to the band's hi (Craft.Size, the PR9 model: orange exact, yellow and green the
-- expected crafts rounded up), the rank read again before every press (Queue.Resize), a press's
-- batch never more than the points left (Queue.BatchSize), and at hi the queue stops with a line.
--
-- Brief PR35 (the owner, 2026-10-02: "Does the craft queue allow you to queue up multiple different
-- professions at once? Yep, do it."): the queue is a list of GROUPS, one a profession (skill line),
-- in the order added. Craft all on a band ADDS its rows as that profession's group (or refreshes
-- the group the profession already has), and the other groups keep their rows and progress. Each
-- group keeps its own band end (hi), sizing, requirements, vendor shopping list, starting rank and
-- crafted count. The run's rows stay one flat list, run.entries, in group order (each entry points
-- at its group, entry.group), so the current row is the first unfinished row of the first
-- unfinished group. A press whose row belongs to a profession whose window does not show switches
-- the window (Craft.Open(line, true)) and crafts nothing. The tray scrolls: a ScrollFrame of our
-- own with a slim scroll bar of our own frames; each group is a grey header strip (glyph, name,
-- band, its own Clear), the level summary or, at the band's end, the celebration card, then its
-- Requirements box, its vendor shopping list and its rows with thin dividers between them.
--
-- Brief PR36 (owner QA of PR35, 2026-10-02): the header strip is gunmetal (the client's dark plate
-- metal on a chamfered card), 30 px, "Cooking (16) - 1 to 50" in the next font size up with a slim
-- bar along its bottom edge, and no second progress line; the vendor shopping list is a parchment
-- card of its own written in dark ink, with a larger title, and its info mark has its own tooltip;
-- the celebration card shows the profession's glyph in a gold ring with a tick, hides the levels
-- gained, and its button, "View 45 to 55", opens ItemTree on that band (Queue.ViewBandClick).
--
-- The model is pure and runs under busted:
--   Queue.Groups(run), Queue.GroupEntries(run, group), Queue.ActiveGroup(run)
--   Queue.AddGroup(run, group, entries)  "added" or "refreshed"; Queue.ClearGroup(run, group)
--   Queue.ShoppingList(warnings), Queue.Summary(group, lineName), Queue.TotalText(run)
--   Queue.ScrollRange(contentH, viewH), Queue.ClampScroll(offset, contentH, viewH), Queue.TrayHeight
--   Queue.StatusColour(run), Queue.RequirementBorder(lines), Queue.NextBand(group)
--   Queue.HeaderText(group, lineName), Queue.InfoLines(line, names), Queue.BandColumn(columns, band)
--   Queue.Build(track, bandIndex, counts, known, vendorable, opts)
--       { entries = { { spell, n, route, missing = { { item, need, vendor } }, node, done, state } },
--         warnings = { { spell, item, short, more, node } } }
--   Queue.Resize(run, rank, counts, colourOf, grow)  the rows sized again from the real rank (PR27)
--   Queue.BatchSize(left, can, rank, hi, su)  one press's count, held to the points left (PR27)
--   Queue.DropGrey(entries, rank, colourOf)  the spells dropped; an entry crafting now is marked
--   Queue.Current, Queue.Remove, Queue.Clear, Queue.Skip, Queue.Progress, Queue.Rows, ...
--   Queue.DockSide(windowLeft, windowRight, screenRight, w, gap)  "right" or "left"
--
-- The tray is our own frame on UIParent in the Trainers & vendors panel's look (Skin.Card, the panel
-- fill and gold edge). It never touches a client frame: it reads the profession window's IsShown
-- and edges and anchors ITSELF to it with SetPoint; the window is opened with
-- C_TradeSkillUI.OpenTradeSkill, an API call (Craft.Open).
--
-- /itemtree queuedemo <case> (developer only, not packaged) fills the tray with fake rows that
-- never reach CraftRecipe; see the block at the end.
--
-- Load cost: nothing at load. The vendor tables (ItemTree_Data) are read on the Create all click
-- only, through the Trainers panel's own loader (Trainers.Load, Trainers.Vendors).
local _, ItemTree = ...
-- ItemTree_Professions is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Modules) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end

local Queue = {}
ItemTree.ProfessionsQueue = Queue

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

local themeSizes = ItemTree.ProfessionsKit.ThemeSizes

local SIZES = themeSizes()

-- Brief PR21 (the owner: "use more normal size UI elements"): the same frame art at normal sizes.
Queue.W = 360
Queue.ROW_H = 38
Queue.WARN_H = 32
Queue.TITLE_H = 22
Queue.LINE_H = 18
Queue.BUTTON_H = SIZES.ITEMTREE_PROFESSION_QUEUE_BUTTON_H or 24
Queue.ICON = SIZES.ITEMTREE_PROFESSION_QUEUE_ICON or 32
-- Brief PR22: the remove X is the client's close button art. Brief PR39 (the owner: "Move the 'X'
-- on the queue items ... to the top right of the card ... the 'X' should be larger (at least 1.5x
-- size for row items in the queue"): 30 px (it was 20) in the row card's top right corner, and the
-- row's "-" and "+" (STEP px, the red plate) either side of its count where the X was.
-- Brief PR40 item C (the owner: "make the + and - buttons smaller like the 'X' was previously"; "Make
-- the 'X' buttons the same size for the profession headers bars and individual crafts"): the "-"
-- and "+" are STEP px, about what the old 20 px close art drew, on the line under the X
-- (COUNT_GAP px below it), the group header's X is REMOVE px too.
Queue.REMOVE = 30
Queue.STEP = 16
-- Brief PR41 items 1 and 3 (the owner: "Add a bit of padding to the right side of the box for the
-- '+' ... same padding as X above it"; "Make the padding/gap between the edge and the X buttons the
-- same (use the line item distance)"): the row's X and the group header's X both sit REMOVE_INSET px
-- in from their card's right edge (the row's distance, kept), and the close art draws its ring
-- REMOVE_ART_INSET px inside its own REMOVE px square, so the "+" (a plate drawn to its edges) sits
-- REMOVE_INSET + REMOVE_ART_INSET px in, under the X's ring, and the "- x2 +" group moves left with it.
Queue.REMOVE_INSET = 0
Queue.REMOVE_ART_INSET = 6
Queue.COUNT_GAP = 2
Queue.COUNT_LINE_H = 18
Queue.CLOSE = 22
Queue.INNER = 12
Queue.GAP = 6
-- Brief PR35 (the owner: "there is no scroll bar for the queue. It just does a weird thing and
-- gets shorter"): the tray is at most TRAY_MAX_H tall, or the screen less SCREEN_MARGIN, and the
-- groups scroll inside it by the wheel (WHEEL_STEP px a notch) and our own slim bar (BAR_W wide,
-- BAR_GAP from the rows, its thumb never shorter than THUMB_MIN).
Queue.TRAY_MAX_H = SIZES.ITEMTREE_PROFESSION_QUEUE_MAX_H or 560
Queue.SCREEN_MARGIN = 80
Queue.SCREEN_H = 768
Queue.BAR_W = 6
Queue.BAR_GAP = 6
Queue.THUMB_MIN = 24
Queue.WHEEL_STEP = 40
-- Brief PR35: a group's header strip (the owner: "a thin strip with the profession title and icon,
-- nothing fancy, but a slightly different colour"), its glyph, its Clear X, and the space between
-- groups; the divider between two rows (the owner: "a thin line breaker between each queued item
-- (with a little margin top and bottom)").
Queue.HEADER_H = SIZES.ITEMTREE_PROFESSION_QUEUE_HEADER_H or 30
Queue.GROUP_CLEAR = Queue.REMOVE
-- Brief PR36 (the owner: "a darker grey with a textured background ... bevel the corners, and a
-- little more padding top and bottom"): the strip's gunmetal, its chamfer, the words' inset, the
-- space under it, and its slim bar along the bottom edge (in place of the second line).
Queue.HEADER_ICON = 20
Queue.HEADER_CHAMFER = 5
Queue.HEADER_INSET = 8
Queue.HEADER_PAD = 6
Queue.HEADER_BAR_H = 2
-- Brief PR40 item C (the owner: "lets hide the progress bars underneath the profession"): the slim
-- bar is not drawn; its numbers (Queue.Summary's fraction) stay for anything else that reads them.
Queue.HEADER_BAR = false
Queue.METAL_KEY = "PROFESSION_METAL"
Queue.METAL_TINT = "ITEMTREE_COLOR_PROFESSION_QUEUE_METAL_TINT"
Queue.METAL_EDGE = "ITEMTREE_COLOR_PROFESSION_QUEUE_METAL_EDGE"
Queue.FONT_HEADER = "GameFontNormalMed3"
Queue.HEADER_FONTS = { "GameFontNormalMed3", "GameFontNormalLarge", "GameFontNormal", "GameFontNormalSmall" }
Queue.GROUP_GAP = 10
Queue.DIVIDER_PAD = 4
-- Brief PR35 item 10: the level summary under the header, its words and its slim bar.
Queue.SUMMARY_PAD = 4
Queue.SUMMARY_BAR_H = 6
-- Brief PR35 item 8: the vendor shopping list's rows, icons and info mark.
Queue.SHOP_ROW_H = 20
Queue.SHOP_ICON = 16
Queue.SHOP_INFO = 14
Queue.SHOP_PAD = 6
-- Brief PR36 (the owner: "look more like a shopping list by putting it in its own card, and give it
-- a paper or scroll texture background and edges"; "the header should be bigger"): the card's
-- parchment, its inner padding, its margin from the tray's fill, the parchment's corners drawn
-- SHOP_EDGE px, the title's larger icon, and the dark ink its words are written in.
Queue.SHOP_INNER = 10
Queue.SHOP_MARGIN = 4
Queue.SHOP_EDGE = 24
Queue.SHOP_TITLE_ICON = 20
Queue.SHOP_TITLE_H = 22
-- Brief PR38 item I (the owner: "the title text contrast is not great ... Maybe add a little more
-- top/bottom padding to vendor list"): the title sat on the parchment art's darker top edge (its
-- top SHOP_EDGE px are the atlas's burnt brown rim; the vendor glyph is to the left of the words,
-- not under them). The card gains SHOP_PAD_Y px at its top and its bottom. Brief PR39 (the owner:
-- "HATE THE NEW BACKGROUND - Instead maybe we just add a bit more padding to the top/bottom to get
-- us away from the dark part of the note and remove that beige block"): no wash behind the title,
-- and the padding takes the title and the last row past the rim: SHOP_INNER + SHOP_PAD_Y is
-- SHOP_EDGE at each end.
Queue.SHOP_PAD_Y = Queue.SHOP_EDGE - Queue.SHOP_INNER
Queue.PARCHMENT_KEY = "PROFESSION_PARCHMENT"
Queue.PARCHMENT_FILL = "ITEMTREE_COLOR_PROFESSION_QUEUE_PARCHMENT_FILL"
Queue.PARCHMENT_EDGE = "ITEMTREE_COLOR_PROFESSION_QUEUE_PARCHMENT_EDGE"
Queue.INK = "ITEMTREE_COLOR_PROFESSION_QUEUE_INK"
Queue.INK_MUTED = "ITEMTREE_COLOR_PROFESSION_QUEUE_INK_MUTED"
Queue.INK_DIVIDER = "ITEMTREE_COLOR_PROFESSION_QUEUE_INK_DIVIDER"
Queue.INK_HOVER = "ITEMTREE_COLOR_PROFESSION_QUEUE_INK_HOVER"
-- Brief PR35 item 11: the celebration card's icon, padding and its next band button.
Queue.CARD_ICON = 36
Queue.CARD_PAD = 8
Queue.CARD_CHAMFER = 4
-- Brief PR36 (the owner: "We need a better icon; it's a bit hard to read. Let's hide the levels
-- gained for now"): the profession's glyph CARD_GLYPH px inside the gold ring, a CARD_TICK px tick
-- on the ring's lower right, and the summary line kept but not shown.
Queue.CARD_GLYPH = 28
Queue.CARD_TICK = 16
Queue.CARD_SUMMARY = false
Queue.NEXT_W = 150
Queue.SMALL_W = 62
-- Brief PR38 (the owner: "the pause button and the craft next should be the same button ... just
-- fill out the main button for the width"): the one main button takes the width Pause had too.
Queue.PRIMARY_W = 132 + Queue.GAP + Queue.SMALL_W
-- Brief PR38: seconds after a press that started a craft in which the same button (now Pause) does
-- nothing, so a double click never crafts and stops in one go. A clock check, never a timer.
Queue.PAUSE_GRACE = 0.5
-- Brief PR39 item A, brief PR40 item B: the client's own stop casting command, the main button's
-- secure action while the queue's craft is being cast (Queue.SyncStop), so the player's Pause click
-- cancels the cast in progress. The levels the main button (on UIParent) sits above the tray by.
Queue.STOP_MACRO = "/stopcasting"
Queue.STOP_LEVEL = 10
-- Brief PR40 item B: the client's setting that says whether its secure buttons act on the key's
-- (or mouse button's) down or its up (SecureActionButton_ShouldUseOnKeyDown, read on the forever
-- branch's Blizzard_FrameXML/SecureTemplates.lua).
Queue.KEY_DOWN_CVAR = "ActionButtonUseKeyDown"
-- Brief PR39 items F and F2 (the owner: "Hover: works but sits pretty far away from the item"):
-- px between the hovered element and its tooltip, and the width a tooltip is taken to need when
-- choosing its side (the client's item tooltip is about this wide; it is not measured before it
-- draws).
Queue.TIP_GAP = 4
Queue.TIP_W = 320
Queue.LINK_W = 118
-- The Recommended tag (brief PR21): RECOMMENDED in the client's Friz Quadrata (GameFontBlackSmall,
-- which carries no shadow), 2 px more above and below the words than PR17's 14 px pill.
-- Brief PR22: the queue's tag sits under the recipe name with more room inside (same font).
Queue.TAG_H = (SIZES.ITEMTREE_PROFESSION_TAG_H or 18) + 2
Queue.TAG_PAD = 20
-- Brief PR40 item D (the owner: "Make recommended use just the 'R' and put it to the right of the
-- name with a hover tooltip instead of consuming its own line"): the tag's gold look as a BADGE_H px
-- badge holding one letter, BADGE_PAD px wider than its letter, BADGE_GAP px after the name.
-- Brief PR41 item 2 (the owner: "The R and the name of the item ... needs to be centre aligned and
-- we can't see the 'R' at all here - add some padding inside"): a BADGE_H px medallion (it was 16, a
-- dark dot: the client's thin border art filled it), drawn as the flat gold chamfer (BADGE_CHAMFER)
-- with the letter in the client's GameFontBlack at least BADGE_INSET px in from each side, and
-- centred on the name's line (anchored to the name's own middle).
-- Brief PRX (PR45, the owner 2026-10-04: the padding is too big, "probs 50%", and the badge broke
-- out past the row card's right edge): the padding halved, about 4 px a side to 2 above and below
-- the letter (BADGE_H 20 to 16) and 5 to 3 at the sides (BADGE_INSET); the badge is measured again
-- each time a row is filled (Queue.FitTag), so its gold always holds the letter, and its whole
-- width is reserved inside the name's line (Queue.BadgePlace), left of the X column.
Queue.BADGE_H = 16
Queue.BADGE_INSET = 3
Queue.BADGE_PAD = 2 * Queue.BADGE_INSET
Queue.BADGE_GAP = 4
Queue.BADGE_CHAMFER = 4
Queue.BADGE_FONT = "GameFontBlack"
Queue.BADGE_FONTS = { "GameFontBlack", "GameFontBlackSmall", "GameFontNormal", "GameFontHighlight" }
-- Brief PR22: a row lists its reagents under the name as the cards do, a small icon and have/need
-- for the row's whole remaining count, and its count words sit at the right by the remove X.
Queue.REAGENT = SIZES.ITEMTREE_PROFESSION_REAGENT or 16
Queue.REAGENT_COUNT_W = 52
Queue.REAGENT_W = Queue.REAGENT + 3 + Queue.REAGENT_COUNT_W + 6
Queue.REAGENT_GAP = 3
Queue.REAGENT_MAX = 4
-- Brief PR25: the Requirements box's tick or cross, its inner padding, and how long the line the
-- pre-check stopped on stays lit; the box's watch looks again every REQ_GAP seconds.
Queue.REQ_ICON = 16
Queue.REQ_PAD = 6
Queue.PULSE = 1.5
Queue.REQ_GAP = 1
-- Brief PR25: a letter's width in the tray's text font, for a reagent's words before they are drawn.
Queue.REAGENT_CHAR_W = 6.5
-- Brief PR39: the count words between the row's "-" and "+" ("x 12"), centred.
Queue.COUNT_W = 44
Queue.TAG_CHAR_W = 7.2
-- The tray's words: client font objects at their own sizes, each with these as fallbacks.
Queue.FONT_TITLE = "GameFontNormal"
Queue.FONT_TEXT = "GameFontHighlight"
Queue.FONT_FALLBACKS = { "GameFontNormal", "GameFontHighlight", "GameFontNormalSmall", "GameFontHighlightSmall" }
-- Brief PR24 (the owner: "make that text decently bigger"): a row's count, "x 5", in the client's
-- large font object (16 px), falling back to the tray's own.
Queue.FONT_COUNT = "GameFontHighlightLarge"
Queue.COUNT_FONTS = { "GameFontHighlightLarge", "GameFontNormalLarge", "GameFontHighlight", "GameFontNormal" }
-- Seconds a chained craft has to start before the chain is taken as not allowed this session.
Queue.CHAIN_WAIT = 2
-- Brief PR22: seconds a pressed craft has to start (TRADE_SKILL_CRAFT_BEGIN or UNIT_SPELLCAST_START)
-- before the run goes back to ready and says nothing started.
Queue.START_WAIT = 2
-- Brief PR25: seconds after a failed craft in which the client's error words still belong to it.
Queue.ERROR_WAIT = 1
-- Brief PB1 addendum (owner QA 2026-10-09, 1.60.1.70291: the bags filled during a Craft all run,
-- he emptied them, opened the queue again, and it still said the inventory was full): the client's
-- own names for a craft refused for full bags. Assumed from the UI source (forever branch,
-- Blizzard_UIErrorsFrame/Mainline/UIErrorsFrame.lua reads UI_ERROR_MESSAGE as messageType,
-- message, and names a type through GetGameMessageInfo) and from his status line, which carried the
-- client's words; /itemtree queuetrace on (developer only) prints the payload in game. A burst of
-- bag events is folded into one look at the free slots ROOM_GAP seconds on.
Queue.FULL_ERRORS = { "ERR_INV_FULL", "ERR_BAG_FULL" }
Queue.ROOM_GAP = 0.2
-- Brief PR22: the profession tabs hanging off ProfessionsFrame's right edge (the Camelot layer's
-- ProfessionsOverviewTab and rightProfessionTabs): their width at scale 1 where they cannot be read,
-- measured from the owner's screenshot.
Queue.TAB_W = 44
-- Brief PR25 (the owner: "more snug with the native UI tabs ... not touching, but closer"): the
-- tabs' frames run about 6 px past their visible art (12 px seen in the owner's screenshot with the
-- old 6 px gap), and the tray now sits DOCK_GAP px past the art.
Queue.TAB_ART_MARGIN = 6
Queue.DOCK_GAP = 2
-- Brief PR22: seconds after Create all's open before the queue checks which line the window shows,
-- and how often the shown tray checks that the window it docked to still shows.
Queue.CONFIRM_WAIT = 0.5
Queue.WATCH_GAP = 0.25
-- Brief PR22: the client's TradeskillRelativeDifficulty (TradeSkillUITypesDocumentation, forever).
Queue.DIFFICULTY_OPTIMAL = 0
Queue.DIFFICULTY_MEDIUM = 1
Queue.DIFFICULTY_TRIVIAL = 3

-- Theme colour keys, the Trainers & vendors panel's own.
Queue.PANEL_FILL = "ITEMTREE_COLOR_PROFESSION_PANEL_FILL"
Queue.FACE = "ITEMTREE_COLOR_BUTTON_FACE"
Queue.BORDER = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
Queue.HOVER = "ITEMTREE_COLOR_STATE_HOVER"
Queue.CURRENT = "ITEMTREE_COLOR_STATE_HOVER"
Queue.TITLE_WORD = "ITEMTREE_COLOR_BAND_WORD"
-- The plate buttons' words, PR17's (Pane.PLATE_WORD, Trainers.BUTTON_WORD).
Queue.PLATE_WORD = "ITEMTREE_COLOR_TEXT_TITLE"
Queue.NAME_WORD = "ITEMTREE_COLOR_TEXT_BODY"
Queue.MUTED_WORD = "ITEMTREE_COLOR_TEXT_MUTED"
Queue.LINK_WORD = "ITEMTREE_COLOR_TEXT_MUTED"
Queue.WARN_WORD = "ITEMTREE_COLOR_PROFESSION_ROUTE_GOLD"
-- Brief PR22: a reagent the bags hold too little of for the row.
Queue.SHORT_WORD = "ITEMTREE_COLOR_PROFESSION_ROUTE_GOLD"
-- The Recommended tag in PR17's look (UI/Pane.lua fillTag): solid card gold, dark words, a 3 px
-- chamfer through Skin.Card; a square gold fill where that will not draw.
Queue.TAG_GOLD = "ITEMTREE_COLOR_PROFESSION_CARD_GOLD"
Queue.TAG_WORD = "ITEMTREE_COLOR_PROFESSION_TAG_WORD"
-- Brief PR35: the group header's neutral grey, the darker Requirements fill with its red or gold
-- edge, the dim divider, the scroll bar, and the celebration card's warm fill and gold edge.
Queue.HEADER_FILL = "ITEMTREE_COLOR_PROFESSION_QUEUE_HEADER_FILL"
Queue.REQ_FILL = "ITEMTREE_COLOR_PROFESSION_QUEUE_REQ_FILL"
Queue.REQ_UNMET = "ITEMTREE_COLOR_KEEP_NO"
Queue.REQ_MET = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
Queue.DIVIDER = "ITEMTREE_COLOR_BORDER_DIVIDER"
Queue.TRACK = "ITEMTREE_COLOR_PROFESSION_QUEUE_SCROLL_TRACK"
Queue.THUMB = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
Queue.CARD_FILL = "ITEMTREE_COLOR_PROFESSION_QUEUE_CARD_FILL"
Queue.CARD_EDGE = "ITEMTREE_COLOR_PROFESSION_CARD_GOLD"
Queue.CARD_WORD = "ITEMTREE_COLOR_PROFESSION_CARD_GOLD"
-- Brief PR35 item 9: the status line's colours, the Craft all hover's own red for a failure or a
-- block, green for done, muted for a neutral prompt.
Queue.STATUS_FAIL = "ITEMTREE_COLOR_KEEP_NO"
Queue.STATUS_DONE = "ITEMTREE_COLOR_KEEP_YES"
Queue.STATUS_NEUTRAL = "ITEMTREE_COLOR_TEXT_MUTED"
-- Brief PR35: the Assets keys the groups draw with (the celebration icon falls back to the tick).
Queue.SHOP_ICON_KEY = "CAT_VENDOR"
Queue.INFO_KEY = "BADGE_INFO"
Queue.CARD_RING_KEY = "PROFESSION_RING"
Queue.CARD_MASK_KEY = "PROFESSION_RING_MASK"
Queue.CARD_ICON_FALLBACK = "ICON_CHECK"
Queue.CLEAR_KEY = "BUTTON_CLOSE"
-- Brief PR35 item 10: the client's fonts carry no arrow glyph, so the summary says "to".
Queue.FONT_LARGE = "GameFontNormalLarge"
Queue.LARGE_FONTS = {
  "GameFontNormalLarge",
  "GameFontNormal",
  "GameFontHighlight",
  "GameFontNormalSmall",
  "GameFontHighlightSmall",
}
Queue.FONT_SMALL = "GameFontHighlightSmall"
Queue.SMALL_FONTS = { "GameFontHighlightSmall", "GameFontNormalSmall", "GameFontHighlight", "GameFontNormal" }

Queue.WORDS = {
  title = L["Craft all queue"],
  demo = L["Demo: %s"],
  -- Brief PR42: the main button while the developer's pretend professions are on.
  pretend = L["Demo"],
  pretendTip = L["Pretend professions: crafting is off"],
  back = L["Back to ItemTree"],
  start = L["Start craft queue"],
  nextUp = L["Craft next"],
  resume = L["Resume"],
  pause = L["Pause"],
  skip = L["Skip"],
  clear = L["Clear"],
  close = L["Close"],
  remove = L["Remove from the queue"],
  -- Brief PR39 item B: a row's "+" and "-", and their hovers.
  plus = L["+"],
  minus = L["-"],
  plusTip = L["One more"],
  plusHint = L["Adds one craft, up to what your materials and this level allow."],
  minusTip = L["One fewer"],
  minusHint = L["Takes one craft off. The X removes the row."],
  -- Brief PR24 (the owner): "x 5", not "5 to make"; "x 2 of 5" once two are made.
  -- Brief PR25 (the owner: "Just say x 16, and after one is done change it to x 15"): always the
  -- count still to make.
  toMake = L["x %d"],
  skipped = L["Skipped"],
  finished = L["Done"],
  -- Brief PR40 item D: the Recommended badge's one letter and its hover.
  badge = L["R"],
  badgeTip = L["Recommended: the route's pick for this band"],
  -- Brief PR40 item F (the owner: "the 0 of 3 recipes, 1 crafted is a bit confusing"): the crafts
  -- done of all the rows' crafts, and the recipes where more than one is queued.
  progress = L["%d of %d crafts done"],
  progressRecipes = L["%d of %d crafts done, %d recipes"],
  warningHint = L["Click to see where to get it"],
  empty = L["The queue is empty"],
  -- The owner, 2026-10-02: why a Craft all queue came out empty, at most two recipes named.
  emptyWhy = L["Nothing to craft: %s."],
  whyUnlearnt = L["%s isn't learnt"],
  whyRank = L["%s needs skill %d"],
  whyMaterials = L["%s needs %d %s, you have %d"],
  whyGrey = L["%s gives no skill"],
  whyMore = L["%s and %d more"],
  allDone = L["All done"],
  combat = L["Paused for combat"],
  -- Brief PR25: every "press" names the button the tray shows at that moment.
  interrupted = L["Interrupted. Press Resume to go on."],
  paused = L["Paused. Press Resume to go on."],
  ready = L["Press Start craft queue to begin"],
  -- Brief PR38: the button word, as the main button reads at that moment.
  pressAgain = L["Press %s again to start"],
  opening = L["Opening the profession window"],
  crafting = L["Crafting %s"],
  starting = L["Starting %s"],
  nothingStarted = L["Nothing started. Press Craft next to try again."],
  failed = L["The craft failed"],
  failedWith = L["The craft failed: %s"],
  noStart = L["The craft did not start"],
  stoppedAfter = L["Stopped after %d of %d"],
  outOf = L["Out of materials"],
  pressNext = L["Press Craft next to go on"],
  autoMode = L["Crafts each recipe in turn by itself"],
  pressMode = L["Press Craft next (or your key) for each recipe"],
  -- Brief PR25: Pause stops the batch's repeats where the client allows it (Craft.StopRepeat); the
  -- craft under way always finishes.
  pauseHint = L["Stops after the craft under way"],
  -- Brief PR39 item A: the main button's hover while its click stops the cast in progress.
  pauseNow = L["Stops now: the craft under way is cancelled and its materials kept."],
  pauseKey = L["Your key binding still stops after the craft under way."],
  pauseNoStop = L["Stops before the next recipe. The game has no way to stop a batch part way."],
  pausing = L["Paused: this one finishes, then it stops."],
  pausingBatch = L["Paused: this batch finishes, then it stops."],
  -- Brief PR39 item A: the main button's /stopcasting cancelled the cast under way.
  pausingNow = L["Paused: stopping the craft under way."],
  pausedAfter = L["Paused after %d of %d. Press Resume to go on."],
  -- Brief PB1 addendum: a stop for full bags, once the bags have room again (Queue.CheckRoom).
  roomAgain = L["Your bags have room again. Press Resume to go on."],
  skipHint = L["Moves on to the next recipe"],
  clearHint = L["Empties the queue"],
  -- Brief PR25: the button word first, then the profession.
  switched = L["Switched to %s. Press %s to craft."],
  -- Brief PR35: the switch to the next profession's group once the queue has started.
  switchedOn = L["Switched to %s. Press %s to go on."],
  switchedAny = L["Switched profession. Press %s to craft."],
  -- Brief PR38 (the owner: "'Swap profession tab' is maybe better here?"): the main button's
  -- label where the next row's profession is not the window that shows, and the hint under it.
  switchButton = L["Switch to %s"],
  switchButtonAny = L["Switch profession"],
  switchHint = L["Next up is %s. Press Switch to %s."],
  switchHintAny = L["Next up is another profession. Press Switch profession."],
  switchTip = L["Opens that profession's window. Nothing is crafted on this press."],
  queueFinished = L["Queue finished: %d crafted."],
  removed = L["%s removed: it no longer gives skill."],
  -- Brief PR25: a row's reagent, "5/5 (3 per craft)": have, need for the row's remaining count,
  -- and one craft's own count.
  reagent = L["%d/%d (%d per craft)"],
  -- Brief PR25: the Requirements box (spell focus, tools, area) and the pre-check's words.
  requirements = L["Requirements"],
  focusMet = L["%s: near one"],
  focusUnmet = L["%s: not near one"],
  toolMet = L["%s: in your bags"],
  toolUnmet = L["%s: not in your bags"],
  areaMet = L["%s: you are there"],
  areaUnmet = L["%s: not here"],
  reqUnknown = L["%s: needed"],
  -- Brief PR39 item I: a need only that profession's own window can check (a Cooking Fire).
  reqCheck = L["%s: open %s to check"],
  reqCheckAny = L["%s: open the profession window to check"],
  neededFor = L["For %s."],
  neededForMore = L["For %s and %d more."],
  needsFocus = L["%s needs a %s. Stand near one, then press %s."],
  needsTool = L["%s needs a %s in your bags. Get one, then press %s."],
  needsArea = L["%s needs %s. Go there, then press %s."],
  -- Brief PR27: a batch held to the crafts that can still give a skill point.
  capped = L["Crafted %d (the most that can still give skill). Press Craft next to go on."],
  -- Brief PR35: a group's own Clear.
  groupClear = L["Clear %s"],
  groupClearHint = L["Takes this profession off the queue. The others stay."],
  -- Brief PR35 item 8: the vendor shopping list.
  shopTitle = L["Vendor shopping list"],
  shopHint = L["Grab these to start crafting the queue."],
  shopFor = L["For %d more %s"],
  shopSold = L["Sold by vendors"],
  -- Brief PR35 item 10: the level summary and the whole-queue total.
  summaryAt = L["%s %d of %d"],
  summaryRunning = L["%s %d to %d of %d"],
  summaryLevel = L["+%d skill: %s %d to %d (level done)"],
  summaryOut = L["+%d skill: %s %d to %d of %d (out of materials)"],
  summaryDone = L["+%d skill: %s %d to %d of %d"],
  summaryCrafted = L["%d crafted"],
  total = L["+%d skill across %d professions"],
  -- Brief PR35 item 11: the celebration card at a group's band end.
  reached = L["You reached %s %d"],
  reachedWhy = L["Queue stopped so you don't waste materials"],
  -- Brief PR36: the card's button opens ItemTree on that profession's next band.
  viewBand = L["View %d to %d"],
  viewBandHint = L["Opens ItemTree on this profession's next level. Nothing is queued or crafted."],
  -- Brief PR36: a group's header, "Cooking (16) - 1 to 50", the rank in the brackets.
  headerFull = L["%s (%d) - %d to %d"],
  headerBand = L["%s - %d to %d"],
  headerRank = L["%s (%d)"],
  -- Brief PR36: the shopping line's info mark, its own tooltip's last line.
  shopClick = L["Click to see where to buy it"],
}

local number = ItemTree.Util.Number
-- Brief SV1: whether a client value may be read (Core/Util.lua Util.CanRead). A cast's payload is
-- secret for a spell the client flags always secret, even the player's own
-- (UnitDocumentation.lua SecretWhenUnitSpellCastRestricted).
local canRead = ItemTree.Util.CanRead

local function craftModule()
  local found = ItemTree.ProfessionsCraft
  return type(found) == "table" and found or nil
end

--- Brief PR42: whether the developer's pretend professions are on (Core\Craft.lua Craft.Pretend);
--- false with no craft module.
function Queue.Pretend()
  local craft = craftModule()
  if craft and type(craft.Pretend) == "function" then
    return craft.Pretend() == true
  end
  return false
end

local function modelModule()
  local found = ItemTree.ProfessionsModel
  return type(found) == "table" and found or nil
end

--- Whether an item is sold by a vendor: vendorable is { [itemId] = true } or a function. Pure.
function Queue.IsVendor(vendorable, itemId)
  if type(vendorable) == "function" then
    local ok, answer = pcall(vendorable, itemId)
    return ok and answer == true
  end
  return type(vendorable) == "table" and vendorable[itemId] == true
end

local function reagentsOf(node)
  local out = {}
  for _, reagent in ipairs(type(node) == "table" and type(node.re) == "table" and node.re or EMPTY) do
    local itemId = type(reagent) == "table" and number(reagent[1]) or nil
    if itemId then
      out[#out + 1] = { item = itemId, need = math.max(number(reagent[2]) or 1, 1) }
    end
  end
  return out
end

-- The band's recipes worth crafting (Craft.Order: no grey, unlearnable or enchant), the route
-- first in Track's route order (start, r, tl, page), then the rest by r, then by spell.
local function ordered(track, bandIndex)
  local craft = craftModule()
  local order = craft and type(craft.Order) == "function" and craft.Order(track, bandIndex) or {}
  local keyed = {}
  for index, node in ipairs(order) do
    keyed[#keyed + 1] = { node = node, index = index }
  end
  table.sort(keyed, function(a, b)
    local ra, rb = a.node.route == true, b.node.route == true
    if ra ~= rb then
      return ra
    end
    if ra then
      return a.index < b.index
    end
    local la, lb = number(a.node.r) or 1, number(b.node.r) or 1
    if la ~= lb then
      return la < lb
    end
    return (number(a.node.spell) or 0) < (number(b.node.spell) or 0)
  end)
  local out = {}
  for _, entry in ipairs(keyed) do
    out[#out + 1] = entry.node
  end
  return out
end

local function maxCraftable(node, counts)
  local craft = craftModule()
  if craft and type(craft.MaxCraftable) == "function" then
    return craft.MaxCraftable(node, counts)
  end
  return 0
end

--- The band's queue. counts is the bags { [itemId] = n }; known { [spell] = true } (nil: every
--- recipe known; only the open window rules one out, Craft.Known; brief PR24: no recipe the tab
--- shows locked, Craft.Locked, the same helper); vendorable says which items a
--- vendor sells. The materials are SHARED: what an earlier entry uses is gone for the later ones.
--- missing lists what one more craft of an entry lacks. A warning stands for each Recommended
--- recipe that vendor-bought reagents would let the player make more often: { spell, item, short
--- (to buy), more (crafts gained), node }. A recipe held back by a reagent no vendor sells gets
--- none. Brief PR21: one row a recipe; a recipe the band lists twice is merged into its first row
--- with the counts summed, and warned for once.
--- Brief PR27 (the owner: "craft as many recipes as possible in this band, preferring recommended
--- items, but only queue enough to get to the next level"): opts { rank, hi, colourOf } sizes each
--- entry by Craft.Size from the simulated rank (carried row to row) toward hi (default the band's
--- hi), stops adding entries once it reaches hi, and caps a warning's crafts at those still needed.
--- Without opts.rank each entry is as many as the bags allow. Answers { entries, warnings, reach,
--- hi } (reach the simulated rank, nil without a rank). Pure.
function Queue.Build(track, bandIndex, counts, known, vendorable, opts)
  opts = type(opts) == "table" and opts or EMPTY
  local entries, warnings = {}, {}
  local bySpell, warned, claimed = {}, {}, {}
  local remaining = {}
  for itemId, have in pairs(type(counts) == "table" and counts or EMPTY) do
    remaining[itemId] = number(have) or 0
  end
  local craft = craftModule()
  local locked = craft and type(craft.Locked) == "function" and craft.Locked or nil
  local size = craft and type(craft.Size) == "function" and craft.Size or nil
  local colourAt = craft and type(craft.ColourAt) == "function" and craft.ColourAt or nil
  local bands = type(track) == "table" and type(track.bands) == "table" and track.bands or EMPTY
  local band = bands[number(bandIndex) or 0]
  local rank = size and number(opts.rank) or nil
  local hi = number(opts.hi) or (type(band) == "table" and number(band.hi)) or nil
  for _, node in ipairs(ordered(track, bandIndex)) do
    if rank ~= nil and hi ~= nil and rank >= hi then
      break
    end
    -- Brief PR24: the tab's own lock rule (Craft.Locked): nothing it shows with a padlock is queued.
    local knows
    if locked then
      knows = locked(node, known) == nil
    else
      knows = node.colour ~= "unlearnable" and (known == nil or (type(known) == "table" and known[node.spell] == true))
    end
    if knows then
      local reagents = reagentsOf(node)
      local n = maxCraftable(node, remaining)
      local colour = colourAt and colourAt(opts.colourOf, node) or nil
      if n >= 1 and rank ~= nil then
        local reach
        n, reach = size(node, rank, hi, n, colour)
        if n >= 1 then
          rank = reach
        end
      end
      if n >= 1 then
        for _, reagent in ipairs(reagents) do
          remaining[reagent.item] = (remaining[reagent.item] or 0) - reagent.need * n
        end
        local missing = {}
        for _, reagent in ipairs(reagents) do
          local have = remaining[reagent.item] or 0
          if have < reagent.need then
            missing[#missing + 1] = {
              item = reagent.item,
              need = reagent.need - have,
              vendor = Queue.IsVendor(vendorable, reagent.item),
            }
          end
        end
        local entry = bySpell[node.spell]
        if entry then
          entry.n = entry.n + n
          entry.route = entry.route or node.route == true
          entry.missing = missing
        else
          entry = {
            spell = node.spell,
            n = n,
            route = node.route == true,
            missing = missing,
            node = node,
            done = 0,
            state = "queued",
          }
          bySpell[node.spell] = entry
          entries[#entries + 1] = entry
        end
      end
      if node.route == true and #reagents > 0 and not (rank ~= nil and hi ~= nil and rank >= hi) then
        -- The crafts the reagents no vendor sells still allow; nil where every reagent is sold.
        local cap, sold = nil, false
        for _, reagent in ipairs(reagents) do
          if Queue.IsVendor(vendorable, reagent.item) then
            sold = true
          else
            -- Brief PR35: less what an earlier warning already counts on (claimed), so two recipes
            -- never both plan on the same leftover leather.
            local left = math.max((remaining[reagent.item] or 0) - (claimed[reagent.item] or 0), 0)
            local makes = math.floor(left / reagent.need)
            if cap == nil or makes < cap then
              cap = makes
            end
          end
        end
        if cap and rank ~= nil then
          -- Brief PR27: never more than the crafts still needed to reach hi.
          local still = size(node, rank, hi, math.huge, colour)
          cap = math.min(cap, still)
        end
        if sold and cap and cap > 0 then
          local warnedHere = false
          for _, reagent in ipairs(reagents) do
            if Queue.IsVendor(vendorable, reagent.item) then
              -- Brief PR35: what the bags still hold counts once across warnings, so the shopping
              -- list's merged count (Queue.ShoppingList) is the whole buy, not the leftover twice.
              local want = cap * reagent.need
              local spare = math.max((remaining[reagent.item] or 0) - (claimed[reagent.item] or 0), 0)
              local short = want - spare
              local key = tostring(node.spell) .. ":" .. tostring(reagent.item)
              if short > 0 and not warned[key] then
                claimed[reagent.item] = (claimed[reagent.item] or 0) + math.min(want, spare)
                warned[key] = true
                warnedHere = true
                warnings[#warnings + 1] =
                  { spell = node.spell, item = reagent.item, short = short, more = cap, node = node }
              end
            end
          end
          if warnedHere then
            for _, reagent in ipairs(reagents) do
              if not Queue.IsVendor(vendorable, reagent.item) then
                claimed[reagent.item] = (claimed[reagent.item] or 0) + cap * reagent.need
              end
            end
          end
        end
      end
    end
  end
  return { entries = entries, warnings = warnings, reach = rank, hi = hi }
end

local LIVE = { queued = true, crafting = true }

--- Brief PR35: the group an entry belongs to: its own (entry.group), else the run itself, which is
--- how a run with no groups (one built by hand, the shape before PR35) is its own one group. Pure.
function Queue.GroupOf(run, entry)
  if type(entry) == "table" and type(entry.group) == "table" then
    return entry.group
  end
  return run
end
local groupOf = Queue.GroupOf

--- Brief PR35: the run's groups in the order added, or the run alone where it has none. Pure.
function Queue.Groups(run)
  if type(run) ~= "table" then
    return {}
  end
  if type(run.groups) == "table" then
    return run.groups
  end
  return { run }
end

--- Brief PR35: a group's entries in queue order (the same entry tables, in a new list). Pure.
function Queue.GroupEntries(run, group)
  local out = {}
  for _, entry in ipairs(type(run) == "table" and type(run.entries) == "table" and run.entries or EMPTY) do
    if groupOf(run, entry) == group then
      out[#out + 1] = entry
    end
  end
  return out
end

local function isGroup(run, group)
  for _, candidate in ipairs(Queue.Groups(run)) do
    if candidate == group then
      return true
    end
  end
  return false
end

--- The entry to craft next, its index and (brief PR35) its group: the row a craft is under way on
--- (or waiting on its start) first, else the first unfinished row of the first unfinished group.
--- Brief PR39 (the owner: "we should rearrange the queue based on the last 'Craft all' gets
--- added"): the groups are newest first (Queue.AddGroup), so the next row is the top group's; brief
--- PR38's open profession first rule is gone, and where the top group's window is not the one that
--- shows the main button offers "Switch to Cooking". Pure.
function Queue.Current(run)
  local entries = type(run) == "table" and type(run.entries) == "table" and run.entries or EMPTY
  for index, entry in ipairs(entries) do
    if LIVE[entry.state] and (entry.state == "crafting" or entry.pending == true) then
      return entry, index, groupOf(run, entry)
    end
  end
  for index, entry in ipairs(entries) do
    if LIVE[entry.state] then
      return entry, index, groupOf(run, entry)
    end
  end
  return nil
end

--- Brief PR35: the group the queue is working in: the one a craft is under way in, else the
--- current row's, else the last one crafted in (run.active), else the last added (brief PR39: the
--- top one). Pure.
function Queue.ActiveGroup(run)
  if type(run) ~= "table" then
    return nil
  end
  local flight = run.inFlight
  if type(flight) == "table" and type(flight.entry) == "table" then
    local group = groupOf(run, flight.entry)
    if isGroup(run, group) then
      return group
    end
  end
  local entry, _, group = Queue.Current(run)
  if entry then
    return group
  end
  if run.active ~= nil and isGroup(run, run.active) then
    return run.active
  end
  return Queue.Groups(run)[1]
end

--- Brief PR35: whether a group has nothing left to make (every row done or skipped, or none at
--- all). Pure.
function Queue.GroupFinished(run, group)
  for _, entry in ipairs(Queue.GroupEntries(run, group)) do
    if LIVE[entry.state] then
      return false
    end
  end
  return true
end

-- Brief PR35: run.entries in place as the groups' entries in group order, the given group's being
-- given ones where fresh is a list.
local function restack(run, group, fresh)
  local byGroup = {}
  for _, entry in ipairs(type(run.entries) == "table" and run.entries or EMPTY) do
    local owner = groupOf(run, entry)
    byGroup[owner] = byGroup[owner] or {}
    byGroup[owner][#byGroup[owner] + 1] = entry
  end
  if group ~= nil then
    byGroup[group] = fresh or {}
  end
  local entries = type(run.entries) == "table" and run.entries or {}
  for index = #entries, 1, -1 do
    entries[index] = nil
  end
  for _, owner in ipairs(Queue.Groups(run)) do
    for _, entry in ipairs(byGroup[owner] or EMPTY) do
      entries[#entries + 1] = entry
    end
  end
  run.entries = entries
end

-- Brief PR39 item B: a count the player set on a row of the old group (its "+" or "-") carried to
-- the new row of the same recipe: the crafts it still had to make, marked set (Queue.Resize keeps
-- it, lowered only where the materials no longer cover it).
local function carrySet(oldEntries, entries)
  local bySpell = {}
  for _, entry in ipairs(oldEntries) do
    if entry.set and LIVE[entry.state] then
      bySpell[entry.spell] = math.max((number(entry.n) or 0) - (number(entry.done) or 0), 1)
    end
  end
  local carried = false
  for _, entry in ipairs(type(entries) == "table" and entries or EMPTY) do
    local left = bySpell[entry.spell]
    if left then
      entry.n = (number(entry.done) or 0) + left
      entry.set = true
      carried = true
    end
  end
  return carried
end

--- Brief PR35: Craft all on a band adds its rows as the profession's group, or, where the
--- profession (skill line) already has one, a refresh of it, its old rows replaced (no
--- duplicates). Every other group keeps its rows and progress. entries are Queue.Build's; each is
--- given the group. Answers the group in the run, "added" or "refreshed", and (brief PR39) whether a
--- count the player set was carried over. Brief PR38 (the owner: "+1 skill: First Aid 27 to 28" read
--- "+0 skill: First Aid 28 to 28" after a band was added): a group's start rank and crafted count
--- hold from when it was first queued until the queue is cleared, so a refresh keeps the old
--- group's. Brief PR39 (the owner: "we should rearrange the queue based on the last 'Craft all'
--- gets added"): the group goes to the TOP, a new one and a refreshed one alike (its progress
--- kept), and so is the group crafted next (Queue.Current). Pure.
function Queue.AddGroup(run, group, entries)
  if type(run) ~= "table" or type(group) ~= "table" then
    return nil
  end
  run.groups = type(run.groups) == "table" and run.groups or {}
  run.entries = type(run.entries) == "table" and run.entries or {}
  local mode, carried = "added", false
  for index, old in ipairs(run.groups) do
    if number(old.line) ~= nil and number(old.line) == number(group.line) then
      mode = "refreshed"
      local start, was = number(old.startRank), number(group.startRank)
      if start ~= nil and (was == nil or start < was) then
        group.startRank = start
      end
      group.crafted = (number(group.crafted) or 0) + (number(old.crafted) or 0)
      carried = carrySet(Queue.GroupEntries(run, old), entries)
      -- The rows of the old group leave with it.
      restack(run, old, {})
      if type(run.inFlight) == "table" and groupOf(run, run.inFlight.entry) == old then
        run.inFlight.entry.group = group
      end
      if run.active == old then
        run.active = group
      end
      table.remove(run.groups, index)
      break
    end
  end
  table.insert(run.groups, 1, group)
  group.crafted = number(group.crafted) or 0
  for _, entry in ipairs(type(entries) == "table" and entries or EMPTY) do
    entry.group = group
  end
  restack(run, group, entries)
  run.cleared = nil
  return group, mode, carried
end

--- Brief PR35 (the owner: "a profession level queue clear at the UI element for the different
--- profession"): takes one group and its rows off the queue; the others stay. A craft under way in
--- it is let go (the client finishes it; nothing follows). With no group left the queue is
--- emptied (Queue.Clear). Answers whether it went. Pure.
function Queue.ClearGroup(run, group)
  if type(run) ~= "table" or type(run.groups) ~= "table" then
    return false
  end
  local at = nil
  for index, candidate in ipairs(run.groups) do
    if candidate == group then
      at = index
    end
  end
  if not at then
    return false
  end
  restack(run, group, {})
  table.remove(run.groups, at)
  if type(run.inFlight) == "table" and groupOf(run, run.inFlight.entry) == group then
    run.inFlight, run.ready = nil, false
  end
  if run.active == group then
    run.active = nil
  end
  if type(run.blocked) == "table" and run.blocked.group == group then
    if run.reason == run.blocked.reason then
      run.reason = nil
    end
    run.blocked = nil
  end
  if #run.groups == 0 then
    Queue.Clear(run)
  end
  return true
end

--- Takes the entry at index off the queue. The one crafting now stays (its craft is under way).
--- Brief PR35: a group left with no rows goes too. Answers whether it went. Pure.
function Queue.Remove(run, index)
  local entries = type(run) == "table" and run.entries or nil
  local entry = type(entries) == "table" and entries[number(index) or 0] or nil
  if not entry or entry.state == "crafting" or entry.pending == true then
    return false
  end
  table.remove(entries, number(index))
  local group = groupOf(run, entry)
  if group ~= run and #Queue.GroupEntries(run, group) == 0 then
    Queue.ClearGroup(run, group)
  end
  -- The last row removed by hand: an emptied queue the player chose, not one with a reason.
  if #entries == 0 then
    run.cleared = true
  end
  return true
end

--- Empties the queue: its entries, groups, warnings and removal notes (brief PR22: an emptied
--- queue is empty, not finished). Pure.
function Queue.Clear(run)
  if type(run) ~= "table" then
    return false
  end
  run.entries, run.warnings, run.removed, run.cleared = {}, {}, {}, true
  if type(run.groups) == "table" then
    run.groups = {}
  end
  run.inFlight, run.ready, run.waitingWindow = nil, false, false
  run.paused, run.reason, run.active, run.blocked = false, nil, nil, nil
  run.levelDone = nil
  return true
end

--- Skips the current entry: it stays in the list, marked, and the next one is up. Pure.
function Queue.Skip(run)
  local entry = Queue.Current(run)
  if not entry then
    return false
  end
  entry.state = "skipped"
  entry.pending = nil
  if type(run.inFlight) == "table" and run.inFlight.entry == entry then
    run.inFlight = nil
  end
  run.ready = false
  return true
end

--- Brief PR27: between presses, the rows still to make sized again from the player's real rank
--- (Craft.Size toward run.hi, the simulated rank carried row to row, counts the bags now shared in
--- order), so each row only covers what the rows before it do not. A queued row's count only
--- shrinks; one with none left once the simulated rank reaches hi becomes Done. With grow (nothing
--- is left to make but the rank is still short, an unlucky run of yellow or green) a row may get
--- more again, and a done row come back, as far as the bags allow. A row crafting, skipped, going
--- grey (left for the grey rule) or with no materials (left for the craft step) is not touched.
--- colourOf(node) is the client's colour (nil: the data's). Answers the simulated rank reached, or
--- nil (no rank or no hi). Brief PR39 item B: a row whose count the player set (its "+" or "-",
--- entry.set) keeps it, lowered only where the bags no longer cover it; the band's sizing never
--- touches it. Pure.
function Queue.Resize(run, rank, counts, colourOf, grow, group)
  local craft = craftModule()
  rank = number(rank)
  -- Brief PR35: one group's rows toward its own hi (default: the run as its own group).
  if group == nil then
    group = run
  end
  local hi = type(group) == "table" and number(group.hi) or nil
  if type(run) ~= "table" or rank == nil or hi == nil or not (craft and type(craft.Size) == "function") then
    return nil
  end
  local remaining = {}
  for itemId, have in pairs(type(counts) == "table" and counts or EMPTY) do
    remaining[itemId] = number(have) or 0
  end
  local colourAt = type(craft.ColourAt) == "function" and craft.ColourAt or nil
  for _, entry in ipairs(Queue.GroupEntries(run, group)) do
    local busy = entry.state == "crafting" or entry.pending == true
    if entry.set and entry.state == "queued" and not busy then
      local done = number(entry.done) or 0
      local left = math.max((number(entry.n) or 0) - done, 0)
      local most = maxCraftable(entry.node, remaining)
      if most >= 1 and most < left then
        left = most
        entry.n = done + left
      end
      for _, reagent in ipairs(reagentsOf(entry.node)) do
        remaining[reagent.item] = (remaining[reagent.item] or 0) - reagent.need * left
      end
      if left >= 1 and rank < hi then
        local colour = colourAt and colourAt(colourOf, entry.node) or nil
        local _, reach = craft.Size(entry.node, rank, hi, left, colour)
        rank = math.max(rank, number(reach) or rank)
      end
    elseif (entry.state == "queued" or (grow and entry.state == "done")) and not busy then
      local done = number(entry.done) or 0
      if rank >= hi then
        if entry.state == "queued" then
          entry.n, entry.state = done, "done"
        end
      else
        local most = maxCraftable(entry.node, remaining)
        if not grow then
          most = math.min(most, math.max((number(entry.n) or 0) - done, 0))
        end
        local colour = colourAt and colourAt(colourOf, entry.node) or nil
        local n, reach, why = craft.Size(entry.node, rank, hi, most, colour)
        if n >= 1 then
          entry.n, entry.state = done + n, "queued"
          for _, reagent in ipairs(reagentsOf(entry.node)) do
            remaining[reagent.item] = (remaining[reagent.item] or 0) - reagent.need * n
          end
          rank = reach
        elseif why == "reached" and entry.state == "queued" then
          entry.n, entry.state = done, "done"
        end
      end
    end
  end
  return rank
end

--- Brief PR27 (the owner: "We can prevent most over-crafting by calculating ahead of time"): one
--- press's batch. A craft gives at most su skill points (1 where the data says nothing), so a batch
--- is never more than ceil((hi - rank) / su): left (the row's count still to make), can (what the
--- bags make now) and that. Answers the count and whether the points left capped it. Pure.
function Queue.BatchSize(left, can, rank, hi, su)
  local want = math.min(number(left) or 0, number(can) or 0)
  rank, hi = number(rank), number(hi)
  if want < 1 or rank == nil or hi == nil then
    return math.max(want, 0), false
  end
  su = number(su)
  if su == nil or su < 1 then
    su = 1
  end
  local most = math.max(math.ceil((hi - rank) / su), 0)
  if want > most then
    return most, true
  end
  return want, false
end

--- Brief PR39 item B: the most crafts a row may hold now, its whole count (made ones included): what
--- it has made, plus the fewer of what the bags make of it once every OTHER row still to make has
--- taken its reagents (counts { [itemId] = n }, the rows in queue order), and the crafts it still
--- needs to take rank to its group's hi (Craft.Size with no materials limit, the band's cap a Craft
--- all sizes by; no cap where rank or hi is not known). colourOf(node) the client's colour. Pure.
function Queue.RowMost(run, entry, counts, rank, colourOf)
  if type(run) ~= "table" or type(entry) ~= "table" then
    return 0
  end
  local remaining = {}
  for itemId, have in pairs(type(counts) == "table" and counts or EMPTY) do
    remaining[itemId] = number(have) or 0
  end
  for _, other in ipairs(type(run.entries) == "table" and run.entries or EMPTY) do
    if other ~= entry and LIVE[other.state] then
      local left = math.max((number(other.n) or 0) - (number(other.done) or 0), 0)
      for _, reagent in ipairs(reagentsOf(other.node)) do
        remaining[reagent.item] = (remaining[reagent.item] or 0) - reagent.need * left
      end
    end
  end
  local most = maxCraftable(entry.node, remaining)
  local craft = craftModule()
  local group = groupOf(run, entry)
  local hi = type(group) == "table" and number(group.hi) or nil
  rank = number(rank)
  if rank ~= nil and hi ~= nil and craft and type(craft.Size) == "function" then
    local colour = type(craft.ColourAt) == "function" and craft.ColourAt(colourOf, entry.node) or nil
    local need = craft.Size(entry.node, rank, hi, math.huge, colour)
    most = math.min(most, math.max(need, 0))
  end
  return (number(entry.done) or 0) + math.max(most, 0)
end

--- Brief PR39 item B (the owner: "Where the 'x' is now add a '+' and on the other side of the x12 add
--- a '-'"): a row's count moved by one. delta 1 adds a craft up to most (Queue.RowMost); -1 takes
--- one off down to one still to make (never the row itself: its X removes it). Only a row still to
--- make and not crafting now. The count is then the player's (entry.set). Answers whether it moved.
--- Pure.
function Queue.StepRow(run, index, delta, most)
  local entries = type(run) == "table" and type(run.entries) == "table" and run.entries or EMPTY
  local entry = entries[number(index) or 0]
  if type(entry) ~= "table" or entry.state ~= "queued" or entry.pending == true then
    return false
  end
  local n, done = number(entry.n) or 0, number(entry.done) or 0
  delta = number(delta) or 0
  if delta > 0 then
    if n + 1 > (number(most) or n) then
      return false
    end
    entry.n = n + 1
  elseif delta < 0 then
    if n - 1 - done < 1 then
      return false
    end
    entry.n = n - 1
  else
    return false
  end
  entry.set = true
  return true
end

--- Brief PR39 item B: whether a row's "+" and "-" can move it now: { plus, minus }, from its count,
--- what it has made and most (Queue.RowMost). Pure.
function Queue.RowSteps(entry, most)
  if type(entry) ~= "table" or entry.state ~= "queued" or entry.pending == true then
    return { plus = false, minus = false, shown = false }
  end
  local n, done = number(entry.n) or 0, number(entry.done) or 0
  return { plus = n + 1 <= (number(most) or n), minus = n - done > 1, shown = true }
end

--- Brief PR22: whether a recipe still gives skill by the client's own TradeSkillRecipeInfo: false
--- where the client calls it trivial, or gives it no skill ups while not calling it orange or
--- yellow (a zero beside an orange or yellow mark is taken as the client not filling the field);
--- true where it says otherwise; nil where it has said nothing. Pure.
function Queue.GivesSkill(info)
  if type(info) ~= "table" then
    return nil
  end
  local difficulty = number(info.relativeDifficulty)
  if difficulty == Queue.DIFFICULTY_TRIVIAL then
    return false
  end
  local ups = number(info.numSkillUps)
  if ups == 0 and difficulty ~= Queue.DIFFICULTY_OPTIMAL and difficulty ~= Queue.DIFFICULTY_MEDIUM then
    return false
  end
  if difficulty ~= nil or ups ~= nil then
    return true
  end
  return nil
end

--- Drops every queued entry whose recipe no longer gives skill (the owner's rule: once an item goes
--- grey it leaves the queue). Brief PR22: the client's word wins where infoOf(spell) has one (its
--- TradeSkillRecipeInfo, read while the window is open, Queue.GivesSkill); else the data's colour at
--- rank, colourOf(node, rank) (default Model.Colour), says grey. The entry crafting now finishes its
--- batch and goes after it (dropAfter). Answers the entries dropped. Pure over colourOf and infoOf.
function Queue.DropUseless(entries, rank, colourOf, infoOf)
  if type(colourOf) ~= "function" then
    local model = modelModule()
    colourOf = model and type(model.Colour) == "function" and model.Colour or nil
  end
  local dropped = {}
  if type(entries) ~= "table" then
    return dropped
  end
  rank = number(rank)
  local index = 1
  while index <= #entries do
    local entry = entries[index]
    local useless = false
    local gives = nil
    if type(infoOf) == "function" then
      local ok, info = pcall(infoOf, entry.spell)
      if ok then
        gives = Queue.GivesSkill(info)
      end
    end
    if gives ~= nil then
      useless = gives == false
    elseif colourOf and rank then
      local ok, colour = pcall(colourOf, entry.node, rank)
      useless = ok and colour == "grey"
    end
    -- Brief PR22: an entry whose craft call waits for its start event counts as crafting.
    local busy = entry.state == "crafting" or entry.pending == true
    if useless and entry.state == "queued" and not busy then
      table.remove(entries, index)
      dropped[#dropped + 1] = entry
    else
      if useless and busy then
        entry.dropAfter = true
      end
      index = index + 1
    end
  end
  return dropped
end

--- The data's grey rule alone (Queue.DropUseless with no client word). Answers the spells dropped.
--- Pure over colourOf.
function Queue.DropGrey(entries, rank, colourOf)
  local spells = {}
  if not number(rank) then
    return spells
  end
  for _, entry in ipairs(Queue.DropUseless(entries, rank, colourOf, nil)) do
    spells[#spells + 1] = entry.spell
  end
  return spells
end

--- Brief PR22: whether the run is over: nothing left to craft, and something was crafted, finished,
--- skipped or removed on the way (an emptied queue is not finished, only empty). Pure.
function Queue.Finished(run)
  if type(run) ~= "table" or run.cleared or Queue.Current(run) then
    return false
  end
  if (number(run.crafted) or 0) > 0 or (type(run.removed) == "table" and #run.removed > 0) then
    return true
  end
  for _, entry in ipairs(type(run.entries) == "table" and run.entries or EMPTY) do
    if entry.state == "done" or entry.state == "skipped" then
      return true
    end
  end
  return false
end

--- Brief PR40 item F: "3 of 12 crafts done", and ", 2 recipes" after it where more than one recipe
--- is queued. The crafts are every row's count (entry.n, what it makes in all); done is what the
--- rows have made (entry.done, never past n). A skipped row counts only what it made, since the
--- rest will not be made. A run that is over says "Queue finished: 12 crafted." (run.crafted).
--- Pure.
function Queue.Progress(run)
  local entries = type(run) == "table" and type(run.entries) == "table" and run.entries or EMPTY
  local crafted = type(run) == "table" and number(run.crafted) or 0
  if Queue.Finished(run) then
    -- Brief PR22: never "0 of 0"; a run that is over says so.
    return string.format(Queue.WORDS.queueFinished, crafted or 0)
  end
  if #entries == 0 then
    return ""
  end
  local all, done = 0, 0
  for _, entry in ipairs(entries) do
    local n = math.max(number(entry.n) or 0, 0)
    local made = math.min(math.max(number(entry.done) or 0, 0), n)
    if entry.state == "skipped" then
      n = made
    end
    all, done = all + n, done + made
  end
  if #entries > 1 then
    return string.format(Queue.WORDS.progressRecipes, done, all, #entries)
  end
  return string.format(Queue.WORDS.progress, done, all)
end

local function nameOf(names, node)
  local craft = craftModule()
  if craft and type(craft.Name) == "function" then
    return craft.Name(names, node)
  end
  return tostring(type(node) == "table" and node.spell or "")
end

local function itemName(names, itemId)
  local name = type(names) == "table" and names[itemId] or nil
  if type(name) == "string" and name ~= "" then
    return name
  end
  local craft = craftModule()
  local words = craft and craft.WORDS and craft.WORDS.item or "Item %d"
  return string.format(words, itemId)
end

--- Brief PR35 item 8 (the owner, 2026-10-02): the vendor shopping list from a group's warnings
--- (Queue.Build: only vendor-bought reagents, only where buying them lets a Recommended recipe be
--- made more often). One line an item in the order first warned, the same reagent merged across
--- recipes: { { item, count (all to buy), fors = { { spell, node, more } } } }. Pure.
function Queue.ShoppingList(warnings)
  local list, byItem = {}, {}
  for _, warning in ipairs(type(warnings) == "table" and warnings or EMPTY) do
    local itemId = type(warning) == "table" and number(warning.item) or nil
    local short = itemId and number(warning.short) or 0
    if itemId and short > 0 then
      local line = byItem[itemId]
      if not line then
        line = { item = itemId, count = 0, fors = {} }
        byItem[itemId] = line
        list[#list + 1] = line
      end
      line.count = line.count + short
      line.fors[#line.fors + 1] = {
        spell = warning.spell,
        node = warning.node or { spell = warning.spell },
        more = number(warning.more) or 0,
      }
    end
  end
  return list
end

--- Brief PR35 item 8: a shopping line's hover lines under the item tooltip: "For 3 more Light
--- Armor Kit" a recipe, then "Sold by vendors" (the vendor's kind is not known). Pure.
function Queue.ShoppingLines(line, names)
  local out = {}
  for _, use in ipairs(type(line) == "table" and type(line.fors) == "table" and line.fors or EMPTY) do
    out[#out + 1] = string.format(Queue.WORDS.shopFor, number(use.more) or 0, nameOf(names, use.node))
  end
  out[#out + 1] = Queue.WORDS.shopSold
  return out
end

-- The owner, 2026-10-02: what blocked each recipe of an empty queue, in this order.
Queue.WHY_ORDER = { unlearnt = 1, rank = 2, materials = 3, grey = 4 }
Queue.WHY_SHOWN = 2

--- Why a band's item recipes made no queue: { { node, kind, item, need, have } }, kind "unlearnt"
--- (learnt false), "rank" (r above the rank), "materials" (the first reagent short of one craft,
--- with need and have), else "grey" (grey, or giving no skill); sorted by that order, then the
--- band's own. Craft.LockState is the lock rule. learntOf(spell) answers true, false or nil;
--- colourOf(node) the client's colour where it has one. Pure.
function Queue.EmptyBlockers(nodes, counts, learntOf, colourOf)
  local craft = craftModule()
  local lockState = craft and type(craft.LockState) == "function" and craft.LockState or nil
  counts = type(counts) == "table" and counts or EMPTY
  local out = {}
  for index, node in ipairs(type(nodes) == "table" and nodes or EMPTY) do
    if type(node) == "table" and node.out ~= nil then
      local colour = node.colour
      if type(colourOf) == "function" then
        local ok, answer = pcall(colourOf, node)
        if ok and type(answer) == "string" then
          colour = answer
        end
      end
      local learnt = nil
      if type(learntOf) == "function" then
        local ok, answer = pcall(learntOf, node.spell)
        if ok then
          learnt = answer
        end
      end
      local lock = lockState and lockState(colour, learnt) or nil
      local why = { node = node, index = index }
      if lock == "locked" then
        why.kind = "unlearnt"
      elseif lock == "future" then
        why.kind = "rank"
      else
        for _, reagent in ipairs(reagentsOf(node)) do
          local have = number(counts[reagent.item]) or 0
          if have < reagent.need then
            why.kind, why.item, why.need, why.have = "materials", reagent.item, reagent.need, have
            break
          end
        end
        why.kind = why.kind or "grey"
      end
      out[#out + 1] = why
    end
  end
  table.sort(out, function(a, b)
    local ka, kb = Queue.WHY_ORDER[a.kind], Queue.WHY_ORDER[b.kind]
    if ka ~= kb then
      return ka < kb
    end
    return a.index < b.index
  end)
  return out
end

--- One line for an empty queue from Queue.EmptyBlockers: "Nothing to craft: A isn't learnt; B
--- needs 8 Light Leather, you have 7." with at most WHY_SHOWN recipes, then "and N more". nil for
--- no blockers. Pure.
function Queue.EmptyText(blockers, names)
  if type(blockers) ~= "table" or #blockers == 0 then
    return nil
  end
  local parts = {}
  for index = 1, math.min(#blockers, Queue.WHY_SHOWN) do
    local why = blockers[index]
    local name = nameOf(names, why.node)
    if why.kind == "unlearnt" then
      parts[#parts + 1] = string.format(Queue.WORDS.whyUnlearnt, name)
    elseif why.kind == "rank" then
      parts[#parts + 1] = string.format(Queue.WORDS.whyRank, name, number(why.node.r) or 1)
    elseif why.kind == "materials" then
      parts[#parts + 1] = string.format(
        Queue.WORDS.whyMaterials,
        name,
        number(why.need) or 1,
        itemName(names, why.item),
        number(why.have) or 0
      )
    else
      parts[#parts + 1] = string.format(Queue.WORDS.whyGrey, name)
    end
  end
  local text = table.concat(parts, "; ")
  if #blockers > Queue.WHY_SHOWN then
    text = string.format(Queue.WORDS.whyMore, text, #blockers - Queue.WHY_SHOWN)
  end
  return string.format(Queue.WORDS.emptyWhy, text)
end

--- An entry's count words: the count still to make, "x 16" then "x 15" as crafts complete (brief
--- PR25), "Skipped", or "Done" once none is left. Pure.
function Queue.CountText(entry)
  if type(entry) ~= "table" then
    return ""
  end
  if entry.state == "skipped" then
    return Queue.WORDS.skipped
  end
  local left = (number(entry.n) or 0) - (number(entry.done) or 0)
  if entry.state == "done" or ((number(entry.done) or 0) > 0 and left <= 0) then
    return Queue.WORDS.finished
  end
  return string.format(Queue.WORDS.toMake, math.max(left, 0))
end

--- The tray's rows: one row per entry in queue order (brief PR21: the current one marked, and a
--- finished one marked done; brief PR35: each with its group, the warnings now the groups'
--- shopping lists). Pure.
function Queue.Rows(run, names)
  local rows = {}
  if type(run) ~= "table" then
    return rows
  end
  local current = Queue.Current(run)
  for index, entry in ipairs(type(run.entries) == "table" and run.entries or EMPTY) do
    rows[#rows + 1] = {
      kind = "entry",
      group = groupOf(run, entry),
      index = index,
      spell = entry.spell,
      item = type(entry.node) == "table" and number(entry.node.out) or nil,
      name = nameOf(names, entry.node or { spell = entry.spell }),
      count = Queue.CountText(entry),
      route = entry.route == true,
      removable = entry.state ~= "crafting" and entry.pending ~= true,
      -- Brief PR39 item B: the entry itself, for its "+" and "-".
      entry = entry,
      current = entry == current,
      finished = entry.state == "done" or entry.state == "skipped",
      node = entry.node,
      reagents = Queue.ReagentNeeds(entry),
    }
  end
  return rows
end

--- Brief PR38 (the owner: "play buttons always change to pause its weird they are two"): what the
--- one main button does now, its label and whether it can be pressed, from the run, the mode
--- ("auto" or "press") and switchTo: the next row's profession name where a profession window
--- shows another line (true where the name is not known), else nil. In order:
---   nothing left to make: "start", "Start craft queue", not pressable (the button is hidden once
---     the queue is finished);
---   a craft or batch under way: "pause", "Pause" (not pressable once asked, or paused for combat);
---   the next row's profession window is not the one that shows: "switch", "Switch to Cooking";
---   paused or interrupted: "resume", "Resume";
---   not started: "start", "Start craft queue"; else "next", "Craft next".
--- A press does what the action says (Queue.Press decides it the same way, in the click). Pure.
function Queue.Action(run, _mode, switchTo)
  if type(run) ~= "table" or not Queue.Current(run) then
    return "start", Queue.WORDS.start, false
  end
  -- Brief PR42: the developer's pretend professions cannot craft; the button reads "Demo", inert.
  -- The queue demo (run.demo) keeps its own made up presses.
  if not run.demo and Queue.Pretend() then
    return "pretend", Queue.WORDS.pretend, false
  end
  local flight = run.inFlight
  if type(flight) == "table" and not flight.stopped then
    return "pause", Queue.WORDS.pause, not flight.pauseAsked and not run.paused
  end
  if switchTo then
    if type(switchTo) == "string" and switchTo ~= "" then
      return "switch", string.format(Queue.WORDS.switchButton, switchTo), true
    end
    return "switch", Queue.WORDS.switchButtonAny, true
  end
  if run.paused then
    return "resume", Queue.WORDS.resume, true
  end
  if not run.started then
    return "start", Queue.WORDS.start, true
  end
  return "next", Queue.WORDS.nextUp, true
end

--- The main button's words and whether it can be pressed (Queue.Action's label and answer). Pure.
function Queue.Primary(run, mode, switchTo)
  local _, label, can = Queue.Action(run, mode, switchTo)
  return label, can
end

--- Brief PR38: the hint under the button while it reads "Switch to Cooking": "Next up is Cooking.
--- Press Switch to Cooking." Pure.
function Queue.SwitchHint(switchTo)
  if type(switchTo) == "string" and switchTo ~= "" then
    return string.format(Queue.WORDS.switchHint, switchTo, switchTo)
  end
  return Queue.WORDS.switchHintAny
end

--- Brief PR22: one line a recipe that left the queue because it no longer gives skill: "First Aid
--- Kit removed: it no longer gives skill." Brief PR25 (the owner: "you just don't add it in the
--- first place"): only rows that leave after the first press are noted, and a recipe the window
--- says is not learnt never is. Pure.
function Queue.RemovedLines(run, names)
  local lines = {}
  for _, removed in ipairs(type(run) == "table" and type(run.removed) == "table" and run.removed or EMPTY) do
    lines[#lines + 1] = string.format(Queue.WORDS.removed, nameOf(names, removed.node or { spell = removed.spell }))
  end
  return lines
end

--- Brief PR24: drops every queued entry the open window now says is not learnt (knowsOf(spell)
--- answers false; Craft.KnowsRecipe with the window open), never the one crafting or waiting on its
--- start. Answers the entries dropped. Pure over knowsOf.
function Queue.DropUnlearnt(entries, knowsOf)
  local dropped = {}
  if type(entries) ~= "table" or type(knowsOf) ~= "function" then
    return dropped
  end
  local index = 1
  while index <= #entries do
    local entry = entries[index]
    local busy = entry.state == "crafting" or entry.pending == true
    local ok, knows = pcall(knowsOf, entry.spell)
    if ok and knows == false and entry.state == "queued" and not busy then
      table.remove(entries, index)
      dropped[#dropped + 1] = entry
    else
      index = index + 1
    end
  end
  return dropped
end

-- Brief PR25: the client's TradeSkill requirement kinds (Enum.RecipeRequirementType, forever).
Queue.REQ_FOCUS = 0
Queue.REQ_TOOL = 1
Queue.REQ_AREA = 2
Queue.REQ_SHOWN = 4
Queue.REQ_NAMES = 2

--- Brief PR25: the Requirements box's lines, for the rows still to make only, in the order the
--- rows need them: one line a requirement (its kind and name), with the rows that need it:
--- { { name, type, met, nodes = { node } } }. met is false where any row's word is false, true
--- where every row's is true, else nil (not known). reqOf(entry) answers an entry's
--- { { name, met, type, check } }. Brief PR35: with group, that group's rows only (each group's box
--- lists its own). Brief PR39 item I: check, where a row's word says only its profession's own
--- window can tell (Craft.Requirements), makes the line say so instead of met or not. Pure over
--- reqOf.
function Queue.Requirements(run, reqOf, group)
  local lines, byKey = {}, {}
  if type(run) ~= "table" or type(reqOf) ~= "function" then
    return lines
  end
  local rows = group ~= nil and Queue.GroupEntries(run, group) or run.entries
  for _, entry in ipairs(type(rows) == "table" and rows or EMPTY) do
    local left = (number(entry.n) or 0) - (number(entry.done) or 0)
    if LIVE[entry.state] and left > 0 then
      local ok, list = pcall(reqOf, entry)
      for _, req in ipairs(ok and type(list) == "table" and list or EMPTY) do
        if type(req) == "table" and type(req.name) == "string" and req.name ~= "" then
          local kind = number(req.type) or Queue.REQ_FOCUS
          local key = tostring(kind) .. ":" .. req.name
          local line = byKey[key]
          if not line then
            line = { name = req.name, type = kind, met = req.met, nodes = {}, check = req.check == true or nil }
            byKey[key] = line
            lines[#lines + 1] = line
          elseif req.check == true then
            line.check, line.met = true, nil
          elseif line.check then
            line.met = nil
          elseif line.met == false or req.met == false then
            line.met = false
          elseif not (line.met == true and req.met == true) then
            line.met = nil
          end
          line.nodes[#line.nodes + 1] = entry.node or { spell = entry.spell }
        end
      end
    end
  end
  return lines
end

local function requirementState(line, lineName)
  local met = line.met
  if line.check and met == nil then
    if type(lineName) == "string" and lineName ~= "" then
      return string.format(Queue.WORDS.reqCheck, "%s", (lineName:gsub("%%", "%%%%")))
    end
    return Queue.WORDS.reqCheckAny
  end
  if met == nil then
    return Queue.WORDS.reqUnknown
  end
  if line.type == Queue.REQ_TOOL then
    return met and Queue.WORDS.toolMet or Queue.WORDS.toolUnmet
  end
  if line.type == Queue.REQ_AREA then
    return met and Queue.WORDS.areaMet or Queue.WORDS.areaUnmet
  end
  return met and Queue.WORDS.focusMet or Queue.WORDS.focusUnmet
end

--- Brief PR25: a requirement line in words, "Cooking Fire: not near one. For Charred Wolf Meat."
--- (two names, then "and 3 more"). Brief PR39 item I: a need only the profession's own window can
--- check, while it is not the one that shows: "Cooking Fire: open Cooking to check. For ...", the
--- profession named by lineName. Pure.
function Queue.RequirementText(line, names, lineName)
  if type(line) ~= "table" then
    return ""
  end
  local text = string.format(requirementState(line, lineName), line.name or "")
  local named = {}
  for index, node in ipairs(type(line.nodes) == "table" and line.nodes or EMPTY) do
    if index > Queue.REQ_NAMES then
      break
    end
    named[#named + 1] = nameOf(names, node)
  end
  if #named == 0 then
    return text
  end
  local more = #line.nodes - #named
  local list = table.concat(named, ", ")
  if more > 0 then
    return text .. ". " .. string.format(Queue.WORDS.neededForMore, list, more)
  end
  return text .. ". " .. string.format(Queue.WORDS.neededFor, list)
end

--- Brief PR35 item 4 (the owner: "Make the border red if one requirement isn't met, and the current
--- yellow if all requirements are met"): the Requirements box's edge colour key. Pure.
function Queue.RequirementBorder(lines)
  for _, line in ipairs(type(lines) == "table" and lines or EMPTY) do
    if type(line) == "table" and line.met == false then
      return Queue.REQ_UNMET
    end
  end
  return Queue.REQ_MET
end

--- Brief PR25: the first requirement an entry does not meet now (met false), or nil. Pure over reqOf.
function Queue.Blocking(entry, reqOf)
  if type(entry) ~= "table" or type(reqOf) ~= "function" then
    return nil
  end
  local ok, list = pcall(reqOf, entry)
  for _, req in ipairs(ok and type(list) == "table" and list or EMPTY) do
    if type(req) == "table" and req.met == false and type(req.name) == "string" then
      return req
    end
  end
  return nil
end

--- Brief PR25: the pre-check's words, naming the button to press: "Charred Wolf Meat needs a
--- Cooking Fire. Stand near one, then press Craft next." Pure.
function Queue.NeedsText(entry, req, names, button)
  local name = nameOf(names, type(entry) == "table" and (entry.node or { spell = entry.spell }) or {})
  local kind = type(req) == "table" and number(req.type) or Queue.REQ_FOCUS
  local words = Queue.WORDS.needsFocus
  if kind == Queue.REQ_TOOL then
    words = Queue.WORDS.needsTool
  elseif kind == Queue.REQ_AREA then
    words = Queue.WORDS.needsArea
  end
  return string.format(words, name, type(req) == "table" and req.name or "", button or Queue.WORDS.nextUp)
end

--- Brief PR25: a failed craft's words with the client's own error where one was heard: "The craft
--- failed: Requires Cooking Fire." Pure.
function Queue.FailedText(err)
  if type(err) ~= "string" or err == "" then
    return Queue.WORDS.failed
  end
  if not err:find("[%.!?]$") then
    err = err .. "."
  end
  return string.format(Queue.WORDS.failedWith, err)
end

-- Brief PR38 (the owner's screenshot: "Queue finished: 1 crafted." under "Interrupted. Press
-- Resume to go on."): the run's reason while it still fits the state. Once the queue is finished
-- only a level done or out of materials line stays (run.doneReason, run.outReason); while the
-- button reads Switch, a prompt naming another button gives way to the switch hint (the switch
-- line of a press that is waiting on the window, and the combat line, stay). Pure.
local function liveReason(run, switchTo)
  local reason = run.reason
  if type(reason) ~= "string" or reason == "" then
    return nil
  end
  if Queue.Finished(run) then
    if reason == run.doneReason or reason == run.outReason then
      return reason
    end
    return nil
  end
  local flight = run.inFlight
  local flying = type(flight) == "table" and not flight.stopped
  if switchTo and not flying and reason ~= run.switchReason and reason ~= Queue.WORDS.combat then
    return nil
  end
  return reason
end
Queue.LiveReason = liveReason

-- The status line itself, before the removal lines.
local function statusLine(run, mode, names, switchTo)
  local reason = liveReason(run, switchTo)
  if reason then
    return reason
  end
  if Queue.Finished(run) then
    return nil
  end
  local entries = type(run.entries) == "table" and run.entries or EMPTY
  if #entries == 0 then
    -- The owner, 2026-10-02: why, where Craft all came out empty; plain words where the player
    -- emptied it.
    if not run.cleared and type(run.emptyWhy) == "string" then
      return run.emptyWhy
    end
    return Queue.WORDS.empty
  end
  local flight = run.inFlight
  if type(flight) == "table" and not flight.stopped then
    -- Brief PR22: "Crafting" only once the client said the craft began.
    return string.format(
      flight.started and Queue.WORDS.crafting or Queue.WORDS.starting,
      nameOf(names, flight.entry and flight.entry.node or { spell = flight.spell })
    )
  end
  if not Queue.Current(run) then
    return Queue.WORDS.allDone
  end
  if switchTo then
    return Queue.SwitchHint(switchTo)
  end
  if not run.started then
    return Queue.WORDS.ready
  end
  if mode == "auto" then
    return Queue.WORDS.autoMode
  end
  return Queue.WORDS.pressMode
end

--- The status lines: the run's reason where it still fits (brief PR38, liveReason), what is
--- crafting, else all done, else (brief PR38) the switch hint where the button reads Switch, else
--- (brief PR21) the press that starts it, else how the queue moves on in this mode; then (brief
--- PR22) a line for each recipe removed because it no longer gives skill. A finished run with
--- nothing else to say reads "All done". switchTo is Queue.Action's. Pure.
function Queue.Status(run, mode, names, switchTo)
  if type(run) ~= "table" then
    return Queue.WORDS.empty
  end
  local lines = {}
  local first = statusLine(run, mode, names, switchTo)
  if first then
    lines[1] = first
  end
  for _, line in ipairs(Queue.RemovedLines(run, names)) do
    lines[#lines + 1] = line
  end
  if #lines == 0 then
    return Queue.WORDS.allDone
  end
  return table.concat(lines, "\n")
end

--- The tray's title: "Craft all queue", or "Demo: Craft all queue" for the developer's demo. Pure.
function Queue.TitleText(run)
  if type(run) == "table" and run.demo then
    return string.format(Queue.WORDS.demo, Queue.WORDS.title)
  end
  return Queue.WORDS.title
end

--- Brief PR35 item 9 (the owner: "The craft failed: Requires Cooking Fire." read grey): the status
--- line's colour key. A failure or block (a failed craft, a missing requirement, out of materials,
--- a craft that did not start, an empty Craft all's reason) is red, the Craft all hover's own; a
--- done line (all done, the level done) green; any other prompt muted. A reason is a failure or
--- done line where it is the one the run set as such (run.failReason, run.doneReason). Brief PR38:
--- only a reason that still fits the state counts (liveReason). Pure.
function Queue.StatusColour(run, switchTo)
  if type(run) ~= "table" then
    return Queue.STATUS_NEUTRAL
  end
  local reason = liveReason(run, switchTo)
  if reason then
    if reason == run.failReason then
      return Queue.STATUS_FAIL
    end
    if reason == run.doneReason then
      return Queue.STATUS_DONE
    end
    return Queue.STATUS_NEUTRAL
  end
  local entries = type(run.entries) == "table" and run.entries or EMPTY
  if #entries == 0 then
    if not run.cleared and type(run.emptyWhy) == "string" then
      return Queue.STATUS_FAIL
    end
    return Queue.STATUS_NEUTRAL
  end
  local removed = type(run.removed) == "table" and #run.removed or 0
  if removed == 0 and not Queue.Current(run) and type(run.inFlight) ~= "table" then
    return Queue.STATUS_DONE
  end
  return Queue.STATUS_NEUTRAL
end

local function lineWord(lineName)
  if type(lineName) == "string" and lineName ~= "" then
    return lineName
  end
  local craft = craftModule()
  return craft and craft.WORDS and craft.WORDS.profession or "Profession"
end

--- Brief PR35 item 10 (the owner): a group's level summary from the rank it had when added
--- (group.startRank), its rank now (group.rank) and its band's end (group.hi). Running: "Cooking
--- 16 of 50", then "Leatherworking 38 to 44 of 45", with fraction the bar's fill from the start to
--- hi. Finished (nothing left to make): "+7 skill: Leatherworking 38 to 45 (level done)", "+5 skill:
--- Cooking 16 to 21 of 50 (out of materials)" or "+3 skill: Cooking 16 to 19 of 50", then ", 33
--- crafted". Answers { kind ("running", "level", "out" or "done"), text, gained, fraction }, or nil
--- without a start rank and hi. Plain "to": the client's fonts carry no arrow glyph. Pure.
function Queue.Summary(group, lineName, finished)
  if type(group) ~= "table" then
    return nil
  end
  local start, hi = number(group.startRank), number(group.hi)
  if not (start and hi) then
    return nil
  end
  local rank = math.max(number(group.rank) or start, start)
  local name = lineWord(lineName)
  local gained = rank - start
  local span = hi - start
  local fraction = 1
  if span > 0 then
    fraction = math.max(math.min((rank - start) / span, 1), 0)
  end
  local out = { gained = gained, fraction = fraction, start = start, rank = rank, hi = hi }
  if group.levelDone or (finished and rank >= hi) then
    out.kind = "level"
    out.text = string.format(Queue.WORDS.summaryLevel, gained, name, start, rank)
  elseif finished and group.stop == "out" then
    out.kind = "out"
    out.text = string.format(Queue.WORDS.summaryOut, gained, name, start, rank, hi)
  elseif finished then
    out.kind = "done"
    out.text = string.format(Queue.WORDS.summaryDone, gained, name, start, rank, hi)
  else
    out.kind = "running"
    if rank == start then
      out.text = string.format(Queue.WORDS.summaryAt, name, rank, hi)
    else
      out.text = string.format(Queue.WORDS.summaryRunning, name, start, rank, hi)
    end
    return out
  end
  local crafted = number(group.crafted) or 0
  if crafted > 0 then
    out.text = out.text .. ", " .. string.format(Queue.WORDS.summaryCrafted, crafted)
  end
  return out
end

--- Brief PR35 item 10: the whole queue's total once more than one profession is queued, "+12 skill
--- across 2 professions": nil with one group, or before the first press with nothing gained. Pure.
function Queue.TotalText(run)
  local groups = Queue.Groups(run)
  if type(run) ~= "table" or type(run.groups) ~= "table" or #groups < 2 then
    return nil
  end
  local gained = 0
  for _, group in ipairs(groups) do
    local start = number(group.startRank)
    local rank = number(group.rank) or start
    if start and rank and rank > start then
      gained = gained + rank - start
    end
  end
  if gained == 0 and not run.started then
    return nil
  end
  return string.format(Queue.WORDS.total, gained, #groups)
end

--- Brief PR35 item 11: the band after a group's own, { index, lo, hi }, or nil at the last. Pure.
function Queue.NextBand(group)
  local track = type(group) == "table" and group.track or nil
  local bands = type(track) == "table" and type(track.bands) == "table" and track.bands or EMPTY
  local index = (type(group) == "table" and number(group.band) or 0) + 1
  local band = bands[index]
  if type(band) == "table" and number(band.lo) and number(band.hi) then
    return { index = index, lo = number(band.lo), hi = number(band.hi) }
  end
  return nil
end

--- Brief PR36 (the owner: "I don't like the double-up of 'Cooking 16 of 50' below the '1 to 50'
--- above. Just put 'Cooking (16) - 1 to 50' and remove the second line."): a group's header words,
--- its rank now (group.rank, else the rank it had when added) in the brackets and its band after
--- an ASCII hyphen. Either part is left out where it is not known. Pure.
function Queue.HeaderText(group, lineName)
  local name = lineWord(lineName)
  if type(group) ~= "table" then
    return name
  end
  local rank = number(group.rank) or number(group.startRank)
  local track = type(group.track) == "table" and group.track or nil
  local band = track and type(track.bands) == "table" and track.bands[number(group.band) or 0] or nil
  local lo = type(band) == "table" and number(band.lo) or nil
  local hi = type(band) == "table" and number(band.hi) or nil
  if rank and lo and hi then
    return string.format(Queue.WORDS.headerFull, name, rank, lo, hi)
  elseif lo and hi then
    return string.format(Queue.WORDS.headerBand, name, lo, hi)
  elseif rank then
    return string.format(Queue.WORDS.headerRank, name, rank)
  end
  return name
end

--- Brief PR36 (the owner: "Hovering the i icon doesn't bring up a tooltip related to what we spoke
--- about"): the info mark's own tooltip lines under the item's name: "For 6 more Herb Baked Egg" a
--- recipe, "Sold by vendors", then "Click to see where to buy it". Pure.
function Queue.InfoLines(line, names)
  local out = Queue.ShoppingLines(line, names)
  out[#out + 1] = Queue.WORDS.shopClick
  return out
end

--- Brief PR36: the canvas column of a band, by its lo and hi (the Professions tab's track is built
--- afresh, so its index may differ from the queue's), else by index. nil where none. Pure.
function Queue.BandColumn(columns, band)
  if type(columns) ~= "table" or type(band) ~= "table" then
    return nil
  end
  for index, column in ipairs(columns) do
    local data = type(column) == "table" and column.band or nil
    if type(data) == "table" and number(data.lo) == band.lo and number(data.hi) == band.hi then
      return index
    end
  end
  local index = number(band.index)
  if index and columns[index] then
    return index
  end
  return nil
end

--- Brief PR35 item 5: the dividers a group of count rows draws, one between each two. Pure.
function Queue.Dividers(count)
  return math.max((number(count) or 0) - 1, 0)
end

--- Brief PR35 item 6: how far the groups can scroll, contentH tall in a viewH window. Pure.
function Queue.ScrollRange(contentH, viewH)
  return math.max((number(contentH) or 0) - (number(viewH) or 0), 0)
end

--- Brief PR35 item 6: an offset held between the top and the last full window. Pure.
function Queue.ClampScroll(offset, contentH, viewH)
  return math.max(math.min(number(offset) or 0, Queue.ScrollRange(contentH, viewH)), 0)
end

--- Brief PR35 item 6: the tray's most height, TRAY_MAX_H or the screen less SCREEN_MARGIN,
--- whichever is smaller (the screen in the tray's units; SCREEN_H where it cannot be read). Pure.
function Queue.TrayHeight(screenH)
  screenH = number(screenH)
  if not screenH or screenH <= 0 then
    screenH = Queue.SCREEN_H
  end
  return math.max(math.min(Queue.TRAY_MAX_H, screenH - Queue.SCREEN_MARGIN), Queue.ROW_H * 3)
end

--- Brief PR35 item 6: the scroll area's height under topH px of controls: the groups' height, held
--- to what the tray's most height leaves. Pure.
function Queue.ViewHeight(topH, contentH, screenH)
  local room = Queue.TrayHeight(screenH) - (number(topH) or 0) - Queue.INNER
  return math.max(math.min(number(contentH) or 0, room), 0)
end

-- ItemTree's own scroll thumb maths (UI/ZoneItems.lua, brief Z1), in pixels here, or nil where the
-- main addon has not loaded it.
local function zoneItems()
  local ui = ItemTree.UI
  local found = type(ui) == "table" and ui.ZoneItems or nil
  if type(found) == "table" and type(found.ThumbSpan) == "function" and type(found.ThumbTop) == "function" then
    return found
  end
  return nil
end

--- Brief PR35 item 6: the slim bar's thumb for contentH px shown viewH at a time down a trackH
--- track at offset: { top, tall }, or nil where it all fits. ZoneItems' thumb maths (the item list's
--- own bar) where loaded, the same sums here otherwise. Pure.
function Queue.Thumb(contentH, viewH, offset, trackH)
  contentH, viewH = math.floor(number(contentH) or 0), math.max(math.floor(number(viewH) or 1), 1)
  trackH = math.max(number(trackH) or viewH, 1)
  if contentH <= viewH then
    return nil
  end
  local helper = zoneItems()
  if helper then
    local span = helper.ThumbSpan(contentH, viewH, trackH, Queue.THUMB_MIN)
    if type(span) == "table" then
      return { top = helper.ThumbTop(span, offset, contentH, viewH), tall = span.tall, travel = span.travel }
    end
  end
  local tall = math.min(trackH, math.max(Queue.THUMB_MIN, trackH * viewH / contentH))
  local travel = math.max(trackH - tall, 0)
  local most = math.max(contentH - viewH, 1)
  local at = math.max(math.min(number(offset) or 0, most), 0)
  return { top = travel * at / most, tall = tall, travel = travel }
end

--- Brief PR35 item 6: the offset a thumb dragged down px (up where negative) from startOffset gives.
--- Pure.
function Queue.DragOffset(startOffset, down, contentH, viewH, trackH)
  local thumb = Queue.Thumb(contentH, viewH, startOffset, trackH)
  if not thumb or thumb.travel <= 0 then
    return Queue.ClampScroll(startOffset, contentH, viewH)
  end
  local range = Queue.ScrollRange(contentH, viewH)
  local offset = (number(startOffset) or 0) + (number(down) or 0) * range / thumb.travel
  return Queue.ClampScroll(math.floor(offset + 0.5), contentH, viewH)
end

--- Brief PR21: which side of the profession window the tray docks on, all in screen pixels: the
--- right where it fits on screen, else the left where that fits, else the right. Pure.
function Queue.DockSide(windowLeft, windowRight, screenRight, w, gap)
  windowLeft, windowRight, screenRight = number(windowLeft), number(windowRight), number(screenRight)
  w, gap = number(w) or Queue.W, number(gap) or Queue.GAP
  if not (windowRight and screenRight) or windowRight + gap + w <= screenRight then
    return "right"
  end
  if windowLeft and windowLeft - gap - w >= 0 then
    return "left"
  end
  return "right"
end

--- Brief PR22: the reagents a row still needs for its whole remaining count: { { item, need, per } }
--- (per is one craft's need, need is per times the crafts left). Pure.
function Queue.ReagentNeeds(entry)
  local out = {}
  if type(entry) ~= "table" then
    return out
  end
  local left = math.max((number(entry.n) or 0) - (number(entry.done) or 0), 0)
  if left < 1 then
    return out
  end
  for _, reagent in ipairs(reagentsOf(entry.node)) do
    if #out >= Queue.REAGENT_MAX then
      break
    end
    out[#out + 1] = { item = reagent.item, need = reagent.need * left, per = reagent.need }
  end
  return out
end

--- Brief PR25 (the owner's format): a reagent's words, "5/5 (3 per craft)", and "(1 per craft)"
--- too. Pure.
function Queue.ReagentText(have, need, per)
  return string.format(Queue.WORDS.reagent, number(have) or 0, number(need) or 0, number(per) or 1)
end

--- Brief PR25: a reagent slot's width from its words' width (measured, else estimated from the
--- letters): the icon, a 3 px gap, the words and a 6 px gap after. Pure.
function Queue.ReagentWidth(measured, text)
  local words = number(measured)
  if not (words and words > 0) then
    words = #tostring(text or "") * Queue.REAGENT_CHAR_W
  end
  return Queue.REAGENT + 3 + math.ceil(words) + 6
end

--- Brief PR22: where a row's words go, from the text column's left and the row's top: the name,
--- then the reagents flowing left to right over room px and wrapping to a new line (brief PR25:
--- one a line where two do not fit). reagents is a count (each REAGENT_W wide) or a list of slot
--- widths (Queue.ReagentWidth). Brief PR40 item D: the Recommended badge sits on the name's line
--- (tagged no longer adds a line; out.tag is always nil). Brief PR40 item C: a row is at least as
--- tall as its right hand column (Queue.RowControls: the X, then the count line under it).
--- Answers { h, tag, reagents = { { x, y } } }, h at least ROW_H. Pure.
function Queue.EntryLayout(reagents, tagged, room)
  local _ = tagged
  local widths = {}
  if type(reagents) == "table" then
    for index = 1, math.min(#reagents, Queue.REAGENT_MAX) do
      widths[index] = number(reagents[index]) or Queue.REAGENT_W
    end
  else
    for index = 1, math.max(math.min(number(reagents) or 0, Queue.REAGENT_MAX), 0) do
      widths[index] = Queue.REAGENT_W
    end
  end
  room = number(room) or 0
  local out = { reagents = {} }
  local y = 3 + Queue.LINE_H
  if #widths > 0 then
    y = y + Queue.REAGENT_GAP
    local x, line = 0, 0
    for index, w in ipairs(widths) do
      if x > 0 and x + w > room then
        x, line = 0, line + 1
      end
      out.reagents[index] = { x = x, y = y + line * (Queue.REAGENT + Queue.REAGENT_GAP) }
      x = x + w
    end
    local rows = line + 1
    y = y + rows * Queue.REAGENT + (rows - 1) * Queue.REAGENT_GAP
  end
  out.h = math.max(Queue.ROW_H, y + 5, Queue.RowControls().h)
  return out
end

--- Brief PR22: a row's text column: left of the icon, right of the count words and the remove X.
function Queue.TextLeft()
  return 3 + Queue.ICON + Queue.GAP + 2
end

--- Brief PR35: the scroll area's width, the tray's inside less the slim bar and its gap.
function Queue.ListW()
  return Queue.W - Queue.INNER * 2 - Queue.BAR_W - Queue.BAR_GAP
end

--- Brief PR40 item C (the owner: "Make quantity right align with the craft queue area (like the 'x'
--- button of the line items) but make sure the 'x' and '+' dont collide"): the row's right hand
--- column, every offset in px from the row's right edge and top. The X (REMOVE square) in the top
--- right corner; under it, COUNT_GAP px down, the count line: the "+" at the right edge (brief PR41:
--- REMOVE_ART_INSET px in, under the X's visible ring), the count
--- words (COUNT_W wide, wide enough for x999) left of it, the "-" left of those, 2 px apart. The
--- count line starts below the X, so the two never overlap whatever the count. With no "-" and "+"
--- (steps false: a done, skipped or crafting row) the words take the whole line, right aligned.
--- Answers { remove = { right, top, size }, plus, minus = { right, top, size }, count = { right,
--- centre (its middle's y), w, justify }, lineTop, w (the column's width), h (its height) }. Pure.
function Queue.RowControls(steps)
  steps = steps ~= false
  local lineTop = Queue.REMOVE + Queue.COUNT_GAP
  local lineH = math.max(Queue.STEP, Queue.COUNT_LINE_H)
  local stepTop = lineTop + math.floor((lineH - Queue.STEP) / 2)
  local groupW = Queue.STEP + 2 + Queue.COUNT_W + 2 + Queue.STEP
  -- Brief PR41 item 1: the count line stands in by the X's own visible padding.
  local pad = Queue.REMOVE_INSET + Queue.REMOVE_ART_INSET
  local out = {
    remove = { right = Queue.REMOVE_INSET, top = 0, size = Queue.REMOVE },
    plus = { right = pad, top = stepTop, size = Queue.STEP },
    minus = { right = pad + Queue.STEP + 2 + Queue.COUNT_W + 2, top = stepTop, size = Queue.STEP },
    lineTop = lineTop,
    w = math.max(Queue.REMOVE_INSET + Queue.REMOVE, pad + groupW),
    h = lineTop + lineH + 4,
  }
  if steps then
    out.count = { right = pad + Queue.STEP + 2, centre = lineTop + lineH / 2, w = Queue.COUNT_W, justify = "CENTER" }
  else
    out.count = { right = pad, centre = lineTop + lineH / 2, w = groupW, justify = "RIGHT" }
  end
  return out
end

-- Brief PR39 item B, brief PR40 item C: the row's right hand column's width (Queue.RowControls).
function Queue.ControlsW()
  return Queue.RowControls().w
end

function Queue.TextRoom()
  return Queue.ListW() - Queue.TextLeft() - Queue.ControlsW() - Queue.GAP
end

--- Brief PR40 item D: the Recommended badge's width, one letter (measured, else estimated) and
--- BADGE_PAD, never narrower than it is tall. Pure.
function Queue.BadgeWidth(measured, text)
  measured = number(measured)
  if not (measured and measured > 0) then
    measured = #tostring(text or "") * Queue.TAG_CHAR_W
  end
  return math.max(math.floor(measured + Queue.BADGE_PAD + 0.5), Queue.BADGE_H)
end

--- Brief PRX (PR45): where the badge sits on its row card, from the row's left: x (the text column
--- plus BadgePlace's badgeX) and right (x + badgeW), with the card's room for it (the row's width
--- less the X column and its gap: Queue.TextLeft() + Queue.TextRoom()). Answers x, right, limit.
--- Pure.
function Queue.BadgeRect(nameMeasured, badgeW)
  local _, badgeX = Queue.BadgePlace(nameMeasured, Queue.TextRoom(), badgeW)
  local limit = Queue.TextLeft() + Queue.TextRoom()
  if not badgeX then
    return nil, nil, limit
  end
  local x = Queue.TextLeft() + badgeX
  return x, x + (number(badgeW) or 0), limit
end

--- Brief PR41 item 2: how far the badge's letter (measured px wide, else estimated) stands in from
--- the badge's sides, the letter centred in a badge w px wide (Queue.BadgeWidth). Pure.
function Queue.BadgeLetterInset(w, measured, text)
  measured = number(measured)
  if not (measured and measured > 0) then
    measured = #tostring(text or "") * Queue.TAG_CHAR_W
  end
  return math.floor(((number(w) or 0) - measured) / 2)
end

--- Brief PR40 item D: the name and its badge on one line of room px: the name's width (its measured
--- width, held so the badge still fits) and the badge's x, BADGE_GAP px after the name's words,
--- both from the text column's left. With no badge the name has the whole room. Answers nameW,
--- badgeX (nil with no badge). Pure.
function Queue.BadgePlace(nameMeasured, room, badgeW)
  room = number(room) or 0
  badgeW = number(badgeW)
  if not badgeW then
    return room, nil
  end
  local most = math.max(room - badgeW - Queue.BADGE_GAP, 0)
  local nameW = number(nameMeasured)
  if not (nameW and nameW > 0) or nameW > most then
    nameW = most
  end
  nameW = math.ceil(nameW)
  return nameW, nameW + Queue.BADGE_GAP
end

--- Brief PR40 item E (the owner: "make the text left align (no icon gap) in that state"): where a
--- Requirements line's words start, from the line's left: past the tick or cross where one is
--- drawn, at the line's left (the box's padding) where none is (the "open Cooking to check" and
--- the plain "needed" states). Pure.
function Queue.RequirementTextX(hasIcon)
  if hasIcon then
    return Queue.REQ_ICON + 4
  end
  return 0
end

--- Brief PR22: the right edge the tray docks beside, in screen pixels: the furthest right of the
--- profession window and its shown side tabs (tabRights, a list); where the tabs could not be found
--- (tabRights nil) the window's right edge plus fallback (the tabs' width). Nil with no window edge.
--- Brief PR25 (the owner: "a little more snug"): a tab's frame runs margin px past its visible art,
--- so a tab's edge counts margin px short (never short of the window's own edge). Pure.
function Queue.DockRight(windowRight, tabRights, fallback, margin)
  local edge = number(windowRight)
  if not edge then
    return nil
  end
  margin = number(margin) or 0
  if type(tabRights) ~= "table" then
    return edge + math.max((number(fallback) or 0) - margin, 0)
  end
  local base = edge
  for _, right in ipairs(tabRights) do
    right = number(right)
    if right and right - margin > edge then
      edge = right - margin
    end
  end
  return math.max(edge, base)
end

--- The Recommended tag's width: the measured words with TAG_PAD round them, else an estimate from
--- the letters. Pure.
function Queue.TagWidth(measured, text)
  measured = number(measured)
  if measured and measured > 0 then
    return math.floor(measured + Queue.TAG_PAD + 0.5)
  end
  return math.floor(#tostring(text or "") * Queue.TAG_CHAR_W + Queue.TAG_PAD + 0.5)
end

--------------------------------------------------------------------------------
--- Brief PR38 (the owner: "The items getting crafted should have hover tooltip as normal"), brief
--- PR39 item F2 (the owner: the tooltip sat a tray's width from the icon he hovered): a row's
--- tooltip sits beside the hovered element itself (the recipe's icon or name, a reagent), as an
--- item button's does: on its right, TIP_GAP px off, or on its left where the screen has no room
--- (Queue.TipSide). Its top is level with the element's, dropped by drop px where the element's
--- top is above the scroll area's (a part scrolled row), so it may cover the row and the rows
--- under it but never the element or the tray's buttons above the list. The tray's own 1 px
--- anchor frame is set at point to the element's relative, and the tooltip hangs from it by
--- anchor. Pure.
function Queue.TipPlacement(side, drop)
  local y = -math.max(number(drop) or 0, 0)
  if side == "left" then
    return { point = "TOPRIGHT", relative = "TOPLEFT", x = -Queue.TIP_GAP, y = y, anchor = "ANCHOR_BOTTOMLEFT" }
  end
  return { point = "TOPLEFT", relative = "TOPRIGHT", x = Queue.TIP_GAP, y = y, anchor = "ANCHOR_BOTTOMRIGHT" }
end

--- Brief PR39 item F2: which side of the hovered element its tooltip goes: "right" where the
--- element's right edge, TIP_GAP and a tooltip TIP_W wide fit inside the screen's right edge (all in
--- one unit), else "left"; "right" where an edge is not known. Pure.
function Queue.TipSide(elementRight, screenRight, tipW)
  elementRight, screenRight = number(elementRight), number(screenRight)
  if not (elementRight and screenRight) then
    return "right"
  end
  if elementRight + Queue.TIP_GAP + (number(tipW) or Queue.TIP_W) <= screenRight then
    return "right"
  end
  return "left"
end

--- Brief PR39 item F2: how far a tooltip's top drops below the element's top so it starts no
--- higher than the scroll area's top (both tops in one unit, larger is higher): 0 where the
--- element is inside the list, or where either is not known. Pure.
function Queue.TipDrop(elementTop, listTop)
  elementTop, listTop = number(elementTop), number(listTop)
  if not (elementTop and listTop) or elementTop <= listTop then
    return 0
  end
  return elementTop - listTop
end

--- Brief PR39 item A: whether the main button's /stopcasting is wanted now (brief PR40: and the
--- craft is being cast, Queue.Armed): a real run (not the demo) with a craft or batch under way that
--- the player has not yet asked to pause, the run not paused, and at least PAUSE_GRACE seconds
--- since the press that started it (so a double click never crafts and cancels in one go; a craft
--- chained from an event has no press time). at is the clock now (nil: no clock, no grace to wait
--- out). Pure.
function Queue.StopWanted(run, at)
  if type(run) ~= "table" or run.demo or run.paused then
    return false
  end
  local flight = run.inFlight
  if type(flight) ~= "table" or flight.stopped or flight.pauseAsked then
    return false
  end
  local pressed = number(flight.pressedAt)
  at = number(at)
  if pressed and at and at - pressed < Queue.PAUSE_GRACE then
    return false
  end
  return true
end

--- Brief PR40 item B: whether the main button's secure action is "/stopcasting" now: the stop is
--- wanted (Queue.StopWanted) and the client says the player is casting (casting: the spell id from
--- UNIT_SPELLCAST_START, Craft.Casting) the craft the queue started (flight.spell, where both are
--- known). At every other time the button has no secure action. Pure.
function Queue.Armed(run, at, casting)
  if not casting or not Queue.StopWanted(run, at) then
    return false
  end
  local spell, cast = number(run.inFlight.spell), number(casting)
  if spell and cast and spell ~= cast then
    return false
  end
  return true
end

--- Brief PR40 item B: the main button hears both halves of a press (RegisterForClicks "AnyDown" and
--- "AnyUp", so its secure action runs whichever half the client's ActionButtonUseKeyDown setting
--- picks); our own handling runs once a press, on that same half: the down where the setting is on
--- (keyDown true), else the up. down is the click's own third value. Pure.
function Queue.ActsOn(down, keyDown)
  return (down == true) == (keyDown == true)
end

--- Brief PR39 item A: the rectangle that covers a target frame, in a frame on UIParent's own units:
--- the target's left, bottom, width and height (its own units) times its effective scale over
--- UIParent's. Answers { x, y, w, h } (x and y from UIParent's bottom left), or nil where any is
--- missing. Pure.
function Queue.CoverRect(left, bottom, w, h, targetScale, parentScale)
  left, bottom, w, h = number(left), number(bottom), number(w), number(h)
  if not (left and bottom and w and h) then
    return nil
  end
  targetScale, parentScale = number(targetScale) or 1, number(parentScale) or 1
  if targetScale <= 0 or parentScale <= 0 then
    return nil
  end
  local k = targetScale / parentScale
  return { x = left * k, y = bottom * k, w = w * k, h = h * k }
end

--- Brief PB1 addendum: whether a client error is a craft refused for full bags. errorType and
--- message are UI_ERROR_MESSAGE's payload; name is the client's own name for that type
--- (GetGameMessageInfo, "ERR_INV_FULL"); known maps each of Queue.FULL_ERRORS to what the client
--- holds for it, { type = LE_GAME_ERR_INV_FULL, text = ERR_INV_FULL } (its own words, in its own
--- language). The name, the type or the words matching any of them counts. Pure.
function Queue.IsFullError(errorType, message, name, known)
  for _, full in ipairs(Queue.FULL_ERRORS) do
    if name ~= nil and name == full then
      return true
    end
    local held = type(known) == "table" and known[full] or nil
    if type(held) == "table" then
      if errorType ~= nil and held.type ~= nil and errorType == held.type then
        return true
      end
      if type(message) == "string" and message ~= "" and message == held.text then
        return true
      end
    end
  end
  return false
end

--- Brief PB1 addendum: the free slots a crafted item can go in, from each bag's answer
--- { free, family } (the client's GetContainerNumFreeSlots): only a bag of no special family (0,
--- or none said) counts, since a quiver or a herb bag takes no crafted gloves. nil where no bag
--- answered. Pure.
function Queue.RoomIn(answers)
  local total, answered = 0, false
  for _, answer in ipairs(type(answers) == "table" and answers or EMPTY) do
    local free = type(answer) == "table" and number(answer[1]) or nil
    if free then
      answered = true
      local family = number(answer[2]) or 0
      if family == 0 and free > 0 then
        total = total + free
      end
    end
  end
  if not answered then
    return nil
  end
  return total
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

-- The queue in hand: { line, band, track, entries, warnings, crafted, started, paused, reason,
-- inFlight = { entry, spell, n, made, started, stopped, chained }, ready, waitingWindow }.
Queue.run = nil
-- Per session: { [itemId] = true or false } for vendor sales, and the loaded vendor sources.
Queue.vendorCache = {}

function Queue.ResetState()
  Queue.run = nil
  Queue.roomPending = false
  Queue.vendorCache = {}
  Queue.sources = nil
  Queue.offset = 0
  Queue.scrollTo, Queue.drag = nil, nil
end

local globalFn = ItemTree.Util.GlobalFn
local assets = ItemTree.ProfessionsKit.Assets
local skin = ItemTree.ProfessionsKit.Skin

local function trainers()
  local found = ItemTree.ProfessionsTrainers
  return type(found) == "table" and found or nil
end

local pane = ItemTree.ProfessionsKit.Pane

local function names()
  local tracks = ItemTree.ProfessionTracks
  return type(tracks) == "table" and type(tracks.names) == "table" and tracks.names or EMPTY
end

-- The client's clock in seconds, or nil.
local function clock()
  local fn = rawget(_G, "GetTime")
  if type(fn) ~= "function" then
    return nil
  end
  local ok, answer = pcall(fn)
  return ok and tonumber(answer) or nil
end

local function after(delay, fn)
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    return (pcall(timer.After, delay, fn))
  end
  return false
end

--- "auto" where crafts may chain from events (Craft.AutoChain() is true), else "press".
function Queue.Mode()
  local craft = craftModule()
  if craft and type(craft.AutoChain) == "function" and craft.AutoChain() == true then
    return "auto"
  end
  return "press"
end

--- Which of the given recipes' reagents a vendor sells, from our data: the client's own vendor
--- list first, then the original game's (Trainers.Vendors). Loads ItemTree_Data on first use, which
--- is the Create all click, never the tab's show. Kept per item for the session.
function Queue.Vendorable(order)
  local panel = trainers()
  if not (panel and type(panel.Load) == "function" and type(panel.Vendors) == "function") then
    return {}
  end
  if not Queue.sources then
    local ok, sources = pcall(panel.Load)
    Queue.sources = ok and type(sources) == "table" and sources or nil
  end
  local out = {}
  if not Queue.sources then
    return out
  end
  for _, node in ipairs(type(order) == "table" and order or EMPTY) do
    for _, reagent in ipairs(reagentsOf(node)) do
      local itemId = reagent.item
      if Queue.vendorCache[itemId] == nil then
        local ok, grouped = pcall(panel.Vendors, itemId, Queue.sources, nil)
        local sold = false
        if ok and type(grouped) == "table" then
          sold = grouped.unnamed == true
            or (type(grouped.own) == "table" and #grouped.own > 0)
            or (type(grouped.other) == "table" and #grouped.other > 0)
        end
        Queue.vendorCache[itemId] = sold == true
      end
      out[itemId] = Queue.vendorCache[itemId] or nil
    end
  end
  return out
end

local refresh
local ensureEvents
local releaseEvents

local function inCombat()
  local craft = craftModule()
  return craft and type(craft.InCombat) == "function" and craft.InCombat() == true
end

-- Whether the profession window shows a holder's line: a group's (brief PR35), or a run built
-- before groups, which holds its own line.
local function windowOpen(holder)
  local craft = craftModule()
  if type(holder) ~= "table" or not (craft and type(craft.IsOpen) == "function") then
    return false
  end
  local lineName = type(craft.LineName) == "function" and craft.LineName(holder.line) or nil
  local ok, open = pcall(craft.IsOpen, holder.line, lineName)
  return ok and open == true
end

local function needsWindow()
  local craft = craftModule()
  if craft and type(craft.NeedsWindow) == "function" then
    return craft.NeedsWindow() ~= false
  end
  return true
end

local professionWindow

-- Brief PR22: the developer's craft trace (/itemtree queuetrace on, not packaged): each step of a
-- press, the call and its answer, and the events heard. Nothing is printed unless it is on.
-- A trace value in words: "nil" for a missing value, never tostring() on an empty vararg (which
-- errors, unlike tostring(nil)).
local function safe(v)
  if v == nil then
    return "nil"
  end
  local ok, text = pcall(tostring, v)
  return ok and text or "?"
end
Queue.TraceSafe = safe

local function traceLine(text, ...)
  local count = select("#", ...)
  local args = { ... }
  for i = 1, count do
    args[i] = safe(args[i])
  end
  local ok, line = pcall(string.format, safe(text), unpack(args, 1, count))
  Queue.TraceLine(ok and line or safe(text))
end

-- A trace failure never breaks the caller (an event handler, a press).
local function trace(text, ...)
  if Queue.tracing and type(Queue.TraceLine) == "function" then
    pcall(traceLine, text, ...)
  end
end
Queue.TraceStep = trace

-- Brief PR35 item 9: a status line that is a failure or block (red), or a done line (green).
local function fail(run, text)
  run.reason = text
  run.failReason = text
  return text
end

local function doneLine(run, text)
  run.reason = text
  run.doneReason = text
  return text
end

-- Brief PR38: the out of materials line, a failure that may outlive the queue's end (liveReason).
local function outLine(run, text)
  fail(run, text)
  run.outReason = text
  return text
end

-- Brief PR22: a profession window shows, but on another line than the group's (the Skinning window
-- up while the next row is a First Aid recipe).
local function wrongLine(run, holder)
  holder = holder or Queue.ActiveGroup(run) or run
  return professionWindow() ~= nil and not windowOpen(holder)
end

local function runLineName(holder)
  local craft = craftModule()
  return craft and type(craft.LineName) == "function" and type(holder) == "table" and craft.LineName(holder.line) or nil
end

-- Brief PR38: the line the profession window shows (run.openLine): a queued group's line, false
-- where a window shows a line the queue does not hold, nil where no window shows. Read only. Brief
-- PR39: Queue.Current no longer reads it (newest group first); it is kept for the trace and the
-- demo's made up window.
local function openLineNow(run)
  if professionWindow() == nil then
    return nil
  end
  for _, group in ipairs(Queue.Groups(run)) do
    if group ~= run and windowOpen(group) then
      return number(group.line)
    end
  end
  return false
end

-- Brief PR38: notes the line that shows on the run. The demo keeps its own made up line.
local function noteOpen(run)
  if type(run) == "table" and not run.demo then
    run.openLine = openLineNow(run)
  end
  return run
end
Queue.NoteOpen = noteOpen

-- Brief PR38: the next row's profession where a profession window shows another line, the main
-- button's "Switch to Cooking" (Queue.Action's switchTo): its name, true where it has none, else
-- nil. Nothing while a craft is under way. The demo reads its own made up line (run.openLine).
local function switchTarget(run)
  if type(run) ~= "table" or (type(run.inFlight) == "table" and not run.inFlight.stopped) then
    return nil
  end
  local entry, _, group = Queue.Current(run)
  if not entry or type(group) ~= "table" then
    return nil
  end
  if run.demo then
    local open = number(run.openLine)
    if open and number(group.line) and number(group.line) ~= open then
      return group.name or true
    end
    return nil
  end
  if not wrongLine(run, group) then
    return nil
  end
  local name = runLineName(group)
  if type(name) == "string" and name ~= "" then
    return name
  end
  return true
end
Queue.SwitchTarget = switchTarget

-- Brief PR25: the main button's words now (Queue.Primary), for a line that says what to press.
-- Brief PR38: afterSwitch, the words it will read once the window it is switching to shows.
local function buttonWord(run, afterSwitch)
  return (Queue.Primary(run, Queue.Mode(), not afterSwitch and switchTarget(run) or nil))
end

-- Brief PR22: a line's words for the switch lines: withName filled with the line's name, else the
-- plain words. Brief PR25: the button to press goes in too, after the name. Brief PR35: the line is
-- holder's (a group), else the active group's. Brief PR38: the button as it reads once the window
-- shows the line (the switch press is what these lines follow).
local function lineWords(run, withName, plain, holder)
  holder = holder or Queue.ActiveGroup(run) or run
  local name = runLineName(holder)
  local button = buttonWord(run, true)
  if type(name) == "string" and name ~= "" then
    return string.format(withName, name, button)
  end
  return string.format(plain, button)
end

-- The player's rank in a holder's line now (brief PR27: Craft.Rank, the client's own profession
-- info where its window shows the line, else the model's facts), the window's skill cache dropped
-- first (a skill up is exactly when it is stale).
local function rankNow(holder)
  if type(holder) ~= "table" then
    return nil
  end
  local craft = craftModule()
  if craft and type(craft.Rank) == "function" then
    local ok, rank = pcall(craft.Rank, holder.line, true)
    if ok and number(rank) then
      return number(rank)
    end
  end
  local ui = ItemTree.UI
  local window = type(ui) == "table" and ui.Frame or nil
  if type(window) == "table" and type(window.InvalidateSkills) == "function" then
    pcall(window.InvalidateSkills)
  end
  local model = modelModule()
  if not (model and type(model.Facts) == "function") then
    return nil
  end
  local ok, skills = pcall(model.Facts)
  local skill = ok and type(skills) == "table" and skills[number(holder.line)] or nil
  return type(skill) == "table" and number(skill.rank) or nil
end
Queue.RankNow = rankNow

-- Brief PR27: the client's colour for a recipe while its window shows the holder's line, else nil.
local function clientColours(run, holder)
  local craft = craftModule()
  if run.demo or not (craft and type(craft.ColourOf) == "function") then
    return nil
  end
  return craft.ColourOf(windowOpen(holder or run))
end

-- The owner, 2026-10-02: why a band made no queue (Queue.EmptyText), from the band's item recipes,
-- the bags for their reagents (local counts) and Craft.KnowsRecipe as it stands. src holds the
-- band: { line, band, track }.
local function bandWhy(run, src)
  local craft = craftModule()
  if not craft or type(src) ~= "table" then
    return nil
  end
  local bands = type(src.track) == "table" and type(src.track.bands) == "table" and src.track.bands or EMPTY
  local band = bands[number(src.band) or 0]
  local nodes = type(band) == "table" and band.nodes or nil
  if type(nodes) ~= "table" then
    return nil
  end
  local counts = type(craft.Counts) == "function" and craft.Counts(nodes) or {}
  local open = windowOpen(src)
  local learntOf = nil
  if type(craft.KnowsRecipe) == "function" then
    learntOf = function(spell)
      return craft.KnowsRecipe(spell, open)
    end
  end
  return Queue.EmptyText(Queue.EmptyBlockers(nodes, counts, learntOf, clientColours(run, src)), Queue.Names(run))
end

-- The empty queue's reason: nil for a run with rows, one the player emptied, or a demo. Brief
-- PR35: the band is the one the last Craft all asked for (run.emptyFor), else the run's own.
local function emptyWhy(run)
  local craft = craftModule()
  if type(run) ~= "table" or run.demo or run.cleared or not craft then
    return nil
  end
  if type(run.entries) == "table" and #run.entries > 0 then
    return nil
  end
  return bandWhy(run, type(run.emptyFor) == "table" and run.emptyFor or run)
end
Queue.EmptyWhy = emptyWhy

-- Brief PR27: the bags now for a group's rows' reagents.
local function liveCounts(run, group)
  local craft = craftModule()
  local order = {}
  for _, entry in ipairs(Queue.GroupEntries(run, group)) do
    order[#order + 1] = entry.node
  end
  if craft and type(craft.Counts) == "function" then
    return craft.Counts(order)
  end
  return {}
end

-- Takes the given entries out of run.entries.
local function removeEntries(run, gone)
  if #gone == 0 then
    return
  end
  local leaving = {}
  for _, entry in ipairs(gone) do
    leaving[entry] = true
  end
  local index = 1
  while index <= #run.entries do
    if leaving[run.entries[index]] then
      table.remove(run.entries, index)
    else
      index = index + 1
    end
  end
end

-- Brief PR27: a group's rows sized again from the real rank (Queue.Resize). Answers the reach.
local function resize(run, group, rank, grow)
  if run.demo or type(group) ~= "table" or not number(group.hi) or not number(rank) then
    return nil
  end
  return Queue.Resize(run, rank, liveCounts(run, group), clientColours(run, group), grow, group)
end

-- Brief PR27: the player is at a group's band end: every row of it still to make is Done, nothing
-- more of it is crafted. Brief PR35 item 11: the group's celebration card says so, in place of the
-- plain status line; where another group follows, the status says to press on. Pressed again with
-- nothing left: "This level is done. Use Craft all on 50 to 100."
local function levelReached(run, group, rank)
  for _, entry in ipairs(Queue.GroupEntries(run, group)) do
    if entry.state == "queued" and entry.pending ~= true then
      entry.n, entry.state = number(entry.done) or 0, "done"
    end
  end
  local craft = craftModule()
  group.levelDone = true
  group.stop = "reached"
  group.rank = number(rank) or group.rank
  run.paused, run.ready, run.waitingWindow = false, false, false
  if group.levelAnnounced then
    if Queue.Current(run) then
      run.reason = Queue.WORDS.pressNext
    else
      doneLine(run, craft and craft.DoneText(group.track, group.band) or nil)
    end
  else
    group.levelAnnounced = true
    run.reason = Queue.Current(run) and Queue.WORDS.pressNext or nil
  end
  trace("level end: rank %s of %s", safe(rank), safe(group.hi))
  refresh()
end
Queue.LevelReached = levelReached

-- Brief PR27: whether materials are what stops a group short of its band's end: no row taken off
-- by Skip, and a row still there would still give skill from rank (Craft.Size with no materials
-- limit). Rows gone grey or removed are not materials.
local function materialsShort(run, group, rank)
  local craft = craftModule()
  if not (craft and type(craft.Size) == "function") then
    return false
  end
  local colourOf = clientColours(run, group)
  local short = false
  for _, entry in ipairs(Queue.GroupEntries(run, group)) do
    if entry.state == "skipped" and not entry.outOf then
      return false
    end
    local colour = type(craft.ColourAt) == "function" and craft.ColourAt(colourOf, entry.node) or nil
    if not short and craft.Size(entry.node, rank, group.hi, math.huge, colour) >= 1 then
      short = true
    end
  end
  return short
end

-- Brief PR27: a group against the real rank, on a skill event and when a batch ends. Mid batch at
-- the band's end, the batch's repeats are stopped where the client allows it from an event
-- (Craft.StopRepeat(true), once a batch; ADDON_ACTION_BLOCKED naming it gives that up for the
-- session) and the group stops when the batch ends. With no batch: at the band's end the group
-- stops (levelReached); with nothing left to make below it, its rows are sized again (more
-- materials may have come) and, where still nothing, it is out of materials ("Out of materials for
-- this level: Cooking 43 of 50." where no other group follows). Answers "batch", "done", "out" or
-- nil.
local function settle(run, group, rank)
  rank = number(rank)
  if type(run) ~= "table" then
    return nil
  end
  group = group or Queue.ActiveGroup(run)
  local hi = type(group) == "table" and number(group.hi) or nil
  if run.demo or run.cleared or not hi or not rank then
    return nil
  end
  group.rank = rank
  local craft = craftModule()
  local flight = run.inFlight
  if type(flight) == "table" and not flight.stopped then
    if groupOf(run, flight.entry) ~= group then
      return nil
    end
    if rank >= hi and not flight.levelTried then
      flight.levelTried = true
      group.levelReached = true
      if (number(flight.n) or 0) - (number(flight.made) or 0) > 0 then
        local took, name = false, nil
        if craft and type(craft.StopRepeat) == "function" then
          flight.stopFrom = "event"
          local ok, answer, called = pcall(craft.StopRepeat, true)
          took, name = ok and answer == true, ok and called or nil
        end
        flight.levelStop = took or nil
        trace("level end mid batch: stop %s answered %s", safe(name), safe(took))
      end
      return "batch"
    end
    return nil
  end
  if rank >= hi then
    if not group.levelDone then
      levelReached(run, group, rank)
    end
    return "done"
  end
  if run.started and Queue.GroupFinished(run, group) and materialsShort(run, group, rank) then
    resize(run, group, rank, true)
    local words
    if not Queue.GroupFinished(run, group) then
      group.stop = nil
      words = Queue.WORDS.pressNext
    else
      group.stop = "out"
      if Queue.Current(run) then
        words = Queue.WORDS.pressNext
      else
        words = craft and craft.OutOfText(runLineName(group), rank, hi) or Queue.WORDS.outOf
      end
    end
    if run.reason ~= words then
      if words == Queue.WORDS.pressNext then
        run.reason = words
      else
        outLine(run, words)
      end
      refresh()
    end
    return "out"
  end
  return nil
end
Queue.Settle = settle

-- Brief PR27: before a craft call, the real rank of the group's line: at its band's end nothing is
-- crafted (the group stops), else its rows are sized again from it. Answers whether a craft may go
-- ahead.
local function gate(run, group)
  group = group or Queue.ActiveGroup(run)
  if run.demo or type(group) ~= "table" or not number(group.hi) then
    return true
  end
  local rank = rankNow(group)
  if not rank then
    return true
  end
  group.rank = rank
  if rank >= group.hi then
    levelReached(run, group, rank)
    return false
  end
  local reach = resize(run, group, rank, Queue.GroupFinished(run, group))
  trace("rank %s of %s: rows sized to reach %s", safe(rank), safe(group.hi), safe(reach))
  return true
end
Queue.Gate = gate

-- Brief PR22: the client's own TradeSkillRecipeInfo for a queued recipe, read only, or nil.
local function recipeInfo(spell)
  local api = rawget(_G, "C_TradeSkillUI")
  if type(api) ~= "table" or type(api.GetRecipeInfo) ~= "function" then
    return nil
  end
  local ok, info = pcall(api.GetRecipeInfo, spell)
  if ok and type(info) == "table" then
    return info
  end
  return nil
end

-- Brief PR22: notes a recipe that left the queue because it no longer gives skill, once. Brief
-- PR25: only once the player has pressed; before that a row that goes is simply not there.
local function noteRemoved(run, entry)
  if not run.started then
    return
  end
  run.removed = type(run.removed) == "table" and run.removed or {}
  for _, removed in ipairs(run.removed) do
    if removed.spell == entry.spell then
      return
    end
  end
  run.removed[#run.removed + 1] = { spell = entry.spell, node = entry.node }
end

-- Brief PR22: drops a group's queued recipes that no longer give skill: by the client's word while
-- the window shows its line (only the queued recipes are asked), else by the data's colour at rank
-- (nil: the data is not asked). Answers how many went.
local function trim(run, rank, group)
  group = group or run
  local infoOf = windowOpen(group) and recipeInfo or nil
  if not infoOf and not rank then
    return 0
  end
  local dropped = Queue.DropUseless(Queue.GroupEntries(run, group), rank, nil, infoOf)
  removeEntries(run, dropped)
  for _, entry in ipairs(dropped) do
    noteRemoved(run, entry)
  end
  return #dropped
end
Queue.Trim = trim

-- Brief PR35: trim over every group, each at its own line's rank where withRank (a skill event),
-- the rank kept for its summary. Answers how many went and whether a group's rank moved.
local function trimAll(run, withRank)
  local total, moved = 0, false
  for _, group in ipairs(Queue.Groups(run)) do
    local rank = nil
    if withRank then
      rank = rankNow(group)
      if rank and rank ~= number(group.rank) then
        group.rank = rank
        moved = true
      end
    end
    total = total + trim(run, rank, group)
  end
  return total, moved
end

-- Brief PR24: whether nothing of a group has moved yet: no craft made or under way in it, no row
-- of it done, skipped or crafting, and (a run built before groups) no press yet.
local function untouched(run, group)
  group = group or run
  if group == run then
    if run.started or (number(run.crafted) or 0) > 0 or type(run.inFlight) == "table" then
      return false
    end
  else
    if type(run.inFlight) == "table" and groupOf(run, run.inFlight.entry) == group then
      return false
    end
    if (number(group.crafted) or 0) > 0 then
      return false
    end
  end
  for _, entry in ipairs(Queue.GroupEntries(run, group)) do
    if entry.state ~= "queued" or entry.pending == true or (number(entry.done) or 0) > 0 then
      return false
    end
  end
  return true
end

-- Brief PR24: Create all asked with the window shut, which cannot say a recipe is not learnt; once
-- the window shows a group's line (TRADE_SKILL_SHOW, TRADE_SKILL_LIST_UPDATE), every queued recipe
-- of it the window says is not learnt leaves the queue. Brief PR25: silently, never as a removal
-- line. A group nothing has moved in yet is built again from the bags and the window's word, so
-- the materials a dropped row held go to the rows after it. Answers how many went.
local function dropUnlearnt(run)
  local craft = craftModule()
  if run.demo or not (craft and type(craft.KnowsRecipe) == "function") then
    return 0
  end
  local knowsOf = function(spell)
    return craft.KnowsRecipe(spell, true)
  end
  local total = 0
  for _, group in ipairs(Queue.Groups(run)) do
    if windowOpen(group) then
      local fresh = untouched(run, group)
      local dropped = Queue.DropUnlearnt(Queue.GroupEntries(run, group), knowsOf)
      removeEntries(run, dropped)
      total = total + #dropped
      if #dropped > 0 and fresh and type(group.track) == "table" and type(craft.Order) == "function" then
        local order = craft.Order(group.track, group.band)
        local counts = type(craft.Counts) == "function" and craft.Counts(order) or {}
        local known = type(craft.Known) == "function" and craft.Known(order, true) or nil
        local opts = { rank = rankNow(group), hi = group.hi, colourOf = clientColours(run, group) }
        local built = Queue.Build(group.track, group.band, counts, known, group.vendorable, opts)
        if group ~= run then
          for _, entry in ipairs(built.entries) do
            entry.group = group
          end
        end
        restack(run, group, built.entries)
        group.warnings = built.warnings
      end
    end
  end
  return total
end
Queue.DropUnlearntNow = dropUnlearnt

-- Brief PR22: after Create all's open (and on each window event), redraws the tray where the window
-- shows another line than the current row's group, and again once it shows the right one. Brief
-- PR38: the button's "Switch to Cooking" and the hint under it are read from the state as it is
-- drawn (switchTarget, Queue.SwitchHint), so no words are kept on the run for it. Answers true
-- (the right line), false (another) or nil (no window, or a craft under way).
local function checkLine(run)
  if not run or run.demo or (type(run.inFlight) == "table" and not run.inFlight.stopped) then
    return nil
  end
  if professionWindow() == nil then
    return nil
  end
  noteOpen(run)
  local group = Queue.ActiveGroup(run) or run
  if wrongLine(run, group) then
    if not run.wrongLine then
      run.wrongLine = true
      refresh()
    end
    return false
  end
  if run.wrongLine then
    run.wrongLine = false
    refresh()
  end
  return true
end
Queue.CheckLine = checkLine

--- Pauses the run with a reason. A craft under way runs on; nothing follows it.
function Queue.Pause(reason)
  local run = Queue.run
  if not run then
    return false
  end
  run.paused = true
  run.ready = false
  run.reason = reason or Queue.WORDS.paused
  refresh()
  return true
end

-- Brief PR25: the paused line once a paused batch is over: "Paused after 3 of 16." while the row
-- has crafts left, else the plain paused line.
local function pausedWords(entry)
  local n, done = number(type(entry) == "table" and entry.n) or 0, number(type(entry) == "table" and entry.done) or 0
  if type(entry) == "table" and done < n then
    return string.format(Queue.WORDS.pausedAfter, done, n)
  end
  return Queue.WORDS.paused
end
Queue.PausedWords = pausedWords

--- Brief PR25 (the owner: "The Pause button should instantly pause, not at the next stop"): the
--- tray's Pause click, a hardware event, so the stop runs synchronously inside it. With a batch
--- under way it stops the batch's repeats where the client allows it (Craft.StopRepeat; the craft
--- being cast always finishes, since SpellStopCasting is protected): "Paused: this one finishes,
--- then it stops.", then "Paused after N of 16." once it has. Where no stop is allowed the batch
--- runs on ("Paused: this batch finishes, then it stops.") and nothing follows it. Answers
--- "stopped", "batch" (no stop allowed), "last" (the craft under way is the batch's last) or
--- "paused" (nothing under way), or nil with no run.
function Queue.PauseClick()
  local run = Queue.run
  if not run then
    return nil
  end
  local flight = run.inFlight
  if run.demo or type(flight) ~= "table" or flight.stopped then
    if run.demo then
      -- Brief PR38: the demo's made up craft under way stops at once; nothing reaches the client.
      run.inFlight = nil
    end
    Queue.Pause(Queue.WORDS.paused)
    return "paused"
  end
  flight.pauseAsked = true
  local stopped, name = false, nil
  local repeats = (number(flight.n) or 0) - (number(flight.made) or 0) > 1
  if repeats then
    local craft = craftModule()
    if craft and type(craft.StopRepeat) == "function" then
      flight.stopFrom = "click"
      local ok, took, called = pcall(craft.StopRepeat)
      stopped, name = ok and took == true, ok and called or nil
    end
    local last = craft and type(craft.state) == "table" and craft.state.lastStop or nil
    trace(
      "pause: stop %s answered %s%s",
      safe(name),
      safe(stopped),
      type(last) == "table" and last.left and (", repeats left " .. safe(last.left)) or ""
    )
  end
  flight.pauseStop = stopped or nil
  run.paused = true
  run.ready = false
  if stopped or not repeats then
    run.reason = Queue.WORDS.pausing
  else
    run.reason = Queue.WORDS.pausingBatch
  end
  refresh()
  if stopped then
    return "stopped"
  end
  return repeats and "batch" or "last"
end

--- Brief PR39 item A (the owner: "Can we make it stop it DURING the current cast? Pause should pause
--- instantly"), brief PR40 item B: the main button's PostClick on a press made while its secure
--- action was "/stopcasting", after the client's secure click handler has run it inside the same
--- press (the cast under way is cancelled). The queue pauses as Pause does (Queue.PauseClick: the
--- batch's repeats stopped too), and says the cast is being stopped; the client's interrupted event
--- then reads "Paused after 3 of 16". Answers PauseClick's answer, or nil where nothing was under
--- way.
function Queue.StopClick()
  local run = Queue.run
  local answer = nil
  local flight = type(run) == "table" and run.inFlight or nil
  if type(flight) == "table" and not flight.stopped and not run.demo and not flight.pauseAsked then
    flight.castStop = true
    trace("pause: the main button's press ran /stopcasting")
    answer = Queue.PauseClick()
    if Queue.run == run and run.inFlight == flight then
      run.reason = Queue.WORDS.pausingNow
      refresh()
    end
  end
  Queue.SyncStop()
  return answer
end

local chainFailed

-- Brief PR25: an entry's needs beyond reagents: the demo's own (entry.reqs), else the client's word
-- while the window shows the entry's group's line (Craft.Requirements), else our data's tools.
local function requirementsOf(run)
  if type(run) ~= "table" then
    return nil
  end
  local craft = craftModule()
  local opens = {}
  return function(entry)
    if type(entry) == "table" and type(entry.reqs) == "table" then
      return entry.reqs
    end
    if run.demo or not (craft and type(craft.Requirements) == "function") or type(entry) ~= "table" then
      return EMPTY
    end
    local group = groupOf(run, entry)
    if opens[group] == nil then
      opens[group] = windowOpen(group)
    end
    return craft.Requirements(entry.spell, opens[group])
  end
end
Queue.RequirementsOf = requirementsOf

-- Brief PR25: the pre-check. The current entry needs something it does not have now (a Cooking
-- Fire, a Blacksmith Hammer): no craft call; the status says what and which button to press after,
-- and the box's line for it lights up once. Answers whether the entry is blocked.
local function blockedBy(run, entry)
  local req = Queue.Blocking(entry, requirementsOf(run))
  if not req then
    run.blocked = nil
    return false
  end
  fail(run, Queue.NeedsText(entry, req, Queue.Names(run), buttonWord(run)))
  run.blocked = {
    name = req.name,
    type = number(req.type) or Queue.REQ_FOCUS,
    pulse = true,
    reason = run.reason,
    group = groupOf(run, entry),
  }
  trace("pre-check: %s needs %s", safe(entry.spell), safe(req.name))
  refresh()
  return true
end
Queue.BlockedBy = blockedBy

-- One craft call for the current entry: as many as it still wants and the bags allow now. An entry
-- the bags can no longer make is passed over; with none left in its group the group stops, out of
-- materials (brief PR35: the next group's row waits for the press that switches to it). chained
-- says the call comes from an event, not a press. Answers "craft" or nil.
local function step(chained)
  local run = Queue.run
  local craft = craftModule()
  if not run or not craft then
    return nil
  end
  run.ready = false
  local first = nil
  while true do
    local entry, _, group = Queue.Current(run)
    if not entry then
      run.reason = nil
      refresh()
      return nil
    end
    if first == nil then
      first = group
    elseif group ~= first then
      -- Brief PR35: the next row is another profession's; the next press switches to it.
      run.reason = Queue.WORDS.pressNext
      refresh()
      return nil
    end
    local counts = type(craft.Counts) == "function" and craft.Counts({ entry.node }) or {}
    local can = maxCraftable(entry.node, counts)
    local left = (number(entry.n) or 0) - (number(entry.done) or 0)
    -- Brief PR27: never more in one batch than the points still to the band's end (Queue.BatchSize).
    local su = type(entry.node) == "table" and entry.node.su or nil
    local want, capped = Queue.BatchSize(left, can, group.rank, group.hi, su)
    if want >= 1 and run.single then
      -- Brief PR22: a batch call that never started; one craft a press from then on.
      want = 1
    end
    if want >= 1 and blockedBy(run, entry) then
      return nil
    end
    if want >= 1 then
      local made = type(craft.CraftCall) == "function" and craft.CraftCall(entry.spell, want) or false
      local last = type(craft.state) == "table" and craft.state.lastCall or nil
      trace(
        "call CraftRecipe(%s, %s) answered %s%s",
        safe(entry.spell),
        safe(want),
        safe(made),
        type(last) == "table" and last.err and (", error: " .. safe(last.err)) or ""
      )
      if not made then
        if chained then
          chainFailed(false)
          return nil
        end
        run.paused = true
        fail(run, Queue.WORDS.noStart)
        refresh()
        return nil
      end
      local flight = { entry = entry, spell = entry.spell, n = want, made = 0, chained = chained == true }
      -- Brief PR38: when the press that made the call was, for the one button's Pause grace.
      flight.pressedAt = not chained and clock() or nil
      flight.capped = (capped and want < left) or nil
      run.inFlight = flight
      run.started = true
      run.active = group
      run.paused, run.reason, run.lastError = false, nil, nil
      run.bagsFull = nil
      entry.pending = true
      -- Brief PR22: the row reads "crafting" only once a start event says so (Queue.OnEvent); a call
      -- that starts nothing in START_WAIT seconds goes back to ready and says so.
      after(chained and Queue.CHAIN_WAIT or Queue.START_WAIT, function()
        if Queue.run == run and run.inFlight == flight and not flight.started and flight.made == 0 then
          if chained then
            chainFailed(false)
          else
            Queue.NoStart(run, flight)
          end
        end
      end)
      refresh()
      return "craft"
    end
    entry.state = (number(entry.done) or 0) > 0 and "done" or "skipped"
    entry.outOf = true
    if Queue.GroupFinished(run, group) then
      group.stop = "out"
      if not Queue.Current(run) then
        local rank, hi = number(group.rank), number(group.hi)
        local words = Queue.WORDS.outOf
        if rank and hi and rank < hi then
          -- Brief PR27: "Out of materials for this level: Cooking 43 of 50."
          words = craft.OutOfText(runLineName(group), rank, hi)
        end
        outLine(run, words)
        refresh()
        return nil
      end
    end
  end
end
Queue.Step = step

--- Brief PR22: a pressed craft that never started: the run goes back to ready, the row back to
--- queued, and the status says nothing started (with the client's error where one was heard). A
--- batch call is not tried again: one craft a press from then on (run.single).
function Queue.NoStart(run, flight)
  if not run or run.inFlight ~= flight then
    return false
  end
  trace("no start event in %s seconds", safe(Queue.START_WAIT))
  run.inFlight = nil
  run.ready = false
  if type(flight) == "table" then
    if flight.entry then
      flight.entry.pending = nil
      if flight.entry.state == "crafting" then
        flight.entry.state = "queued"
      end
    end
    if (number(flight.n) or 0) > 1 and not flight.pauseAsked then
      run.single = true
    end
  end
  if type(flight) == "table" and flight.pauseAsked then
    -- Brief PR25: paused before the craft began: nothing was made, and Resume crafts the row.
    run.paused = true
    run.reason = Queue.WORDS.paused
    refresh()
    return true
  end
  local words = Queue.WORDS.nothingStarted
  if type(run.lastError) == "string" and run.lastError ~= "" then
    words = words .. " " .. run.lastError
  end
  fail(run, words)
  refresh()
  return true
end

-- A chained craft that did not start: back to one press a recipe. saved: the client said it was
-- blocked, so the answer is kept; otherwise for this session only.
chainFailed = function(saved)
  local run = Queue.run
  local craft = craftModule()
  if craft and type(craft.SetAutoChain) == "function" then
    craft.SetAutoChain(false, saved == true)
  end
  if run then
    local flight = run.inFlight
    if type(flight) == "table" and flight.entry and flight.made == 0 then
      flight.entry.state = "queued"
      flight.entry.pending = nil
    end
    run.inFlight = nil
    run.ready = false
    run.reason = Queue.WORDS.pressNext
  end
  refresh()
end

-- Brief PR27, PR35: a press with nothing current. The run's Craft all landed on a finished band
-- (run.levelDone), or the active group stopped at its band's end: say so, craft nothing (the
-- demo's too). Else each group still short of its end gets its rows sized again from the real
-- rank, as far as the bags allow. Answers "level", "more" (a row is up again) or nil.
local function pressIdle(run)
  local active = Queue.ActiveGroup(run)
  local craft = craftModule()
  if run.levelDone then
    doneLine(run, craft and craft.DoneText(run.levelTrack, run.levelBand) or nil)
    refresh()
    return "level"
  end
  if type(active) == "table" and active.levelDone then
    doneLine(run, craft and craft.DoneText(active.track, active.band) or nil)
    trace("press after the level end")
    refresh()
    return "level"
  end
  if run.demo or run.cleared or run.inFlight ~= nil then
    return nil
  end
  local reached, tried = false, nil
  for _, group in ipairs(Queue.Groups(run)) do
    if number(group.hi) and not group.levelDone then
      tried = group
      if not gate(run, group) then
        reached = true
      elseif Queue.Current(run) then
        return "more"
      end
    end
  end
  if reached then
    return "level"
  end
  if tried then
    settle(run, tried, tried.rank)
  end
  return nil
end

--- The hardware path: the tray's main button and the key binding (brief PR21: never the Create all
--- click). Starts or resumes the run: opens the profession window first where a craft needs it
--- (and crafts in the same press where it is open at once), then makes ONE craft call for the
--- current entry's remaining count. Brief PR35: where the current row belongs to a profession whose
--- window does not show, the press switches the window to it (Craft.Open(line, true)) and crafts
--- nothing: "Switched to Cooking. Press Craft next to go on." Brief PR38: the one main button, so
--- with a craft or batch under way the press is Pause (Queue.PauseClick, its stop inside this same
--- press), the action decided here in the click as the label was (Queue.Action); a press within
--- PAUSE_GRACE seconds of the press that started the craft does nothing. Answers "craft", "open",
--- "switch", "pause", "level" or nil ("demo" in the demo).
function Queue.Press()
  local run = Queue.run
  trace("press")
  if not run then
    return nil
  end
  -- Brief PR42: nothing is crafted, opened or stopped for a pretend profession.
  if not run.demo and Queue.Pretend() then
    return nil
  end
  -- Brief PW1 (QA item 238 d): the queue's press (its button or the key binding) brings the
  -- profession window in front of ItemTree's.
  Queue.TellWindow(true)
  noteOpen(run)
  local flying = run.inFlight
  if type(flying) == "table" and not flying.stopped then
    local at, pressed = clock(), number(flying.pressedAt)
    if flying.pauseAsked or run.paused or (at and pressed and at - pressed < Queue.PAUSE_GRACE) then
      return nil
    end
    Queue.PauseClick()
    return "pause"
  end
  if not Queue.Current(run) then
    local idle = pressIdle(run)
    if idle ~= "more" then
      return idle
    end
  end
  if run.demo then
    -- The developer's demo (/itemtree queuedemo): its fake rows step on; nothing reaches the client.
    if type(Queue.DemoPress) == "function" then
      return Queue.DemoPress(run)
    end
    return nil
  end
  local flight = run.inFlight
  if type(flight) == "table" and not flight.stopped then
    return nil
  end
  if type(flight) == "table" then
    -- A batch the client stopped: what it made is counted; the rest goes again.
    if flight.entry then
      flight.entry.pending = nil
      if flight.entry.state == "crafting" then
        flight.entry.state = "queued"
      end
    end
    run.inFlight = nil
  end
  if inCombat() then
    Queue.Pause(Queue.WORDS.combat)
    return nil
  end
  run.paused, run.reason = false, nil
  run.failedAt = nil
  -- Brief PB1 addendum: a new try; full bags refuse it again where they still are.
  run.bagsFull = nil
  ensureEvents()
  -- Brief PR27: the real rank first: at a group's band end nothing of it is crafted (brief PR35:
  -- its card shows and the next group is up), else its rows are sized again from it.
  local reached = false
  for _ = 1, #Queue.Groups(run) do
    local entry, _, group = Queue.Current(run)
    if not entry or gate(run, group) then
      break
    end
    reached = true
  end
  local entry, _, group = Queue.Current(run)
  if not entry then
    if reached then
      return "level"
    end
    settle(run, Queue.ActiveGroup(run), (Queue.ActiveGroup(run) or EMPTY).rank)
    return nil
  end
  if wrongLine(run, group) then
    -- Brief PR22: the window shows another profession. This press switches it to the row's line
    -- (one open call, the gap skipped: it is the player's own press) and crafts nothing, since the
    -- row's recipe is not in the window until it shows.
    local craft = craftModule()
    local opened = craft and type(craft.Open) == "function" and craft.Open(group.line, true) or false
    run.waitingWindow = true
    run.wrongLine = false
    if opened then
      run.switched = true
      -- Brief PR35: once the queue has started, the switch to the next profession says go on.
      run.switchWords = run.started and Queue.WORDS.switchedOn or Queue.WORDS.switched
      run.reason = lineWords(run, run.switchWords, Queue.WORDS.switchedAny, group)
      run.switchReason = run.reason
      refresh()
      return "switch"
    end
    run.reason = string.format(Queue.WORDS.pressAgain, buttonWord(run))
    refresh()
    return nil
  end
  run.switched = nil
  if needsWindow() and not windowOpen(group) then
    local craft = craftModule()
    local opened = craft and type(craft.Open) == "function" and craft.Open(group.line) or false
    if not windowOpen(group) then
      run.waitingWindow = true
      if opened and Queue.Mode() == "auto" then
        run.reason = Queue.WORDS.opening
      else
        run.reason = string.format(Queue.WORDS.pressAgain, buttonWord(run, true))
      end
      refresh()
      if opened then
        return "open"
      end
      return nil
    end
  end
  run.waitingWindow = false
  return step(false)
end

--- The key binding's press (ItemTree's Bindings.xml, through ProfessionsStub.CraftNext): one press.
function Queue.Binding()
  if not Queue.run then
    return nil
  end
  return Queue.Press()
end

-- Chains the next craft from an event where the client allows it and nothing holds the run.
local function chain()
  local run = Queue.run
  if not run or not run.ready or run.paused or Queue.Mode() ~= "auto" then
    return false
  end
  if inCombat() then
    Queue.Pause(Queue.WORDS.combat)
    return false
  end
  local _, _, group = Queue.Current(run)
  if needsWindow() and not windowOpen(group or run) then
    run.ready = false
    run.reason = Queue.WORDS.pressNext
    refresh()
    return false
  end
  if not gate(run, group) then
    return false
  end
  return step(true) == "craft"
end
Queue.Chain = chain

-- The entry's batch is over: done where it made all it wanted, else back in the queue; an entry
-- that went grey while crafting leaves the queue now.
local function finishFlight(run, flight)
  local entry = flight.entry
  run.inFlight = nil
  if not entry then
    return
  end
  entry.pending = nil
  if entry.dropAfter and (number(entry.done) or 0) >= (number(entry.n) or 0) then
    -- Brief PR22: it made all it was asked for, then went grey: it is done, not removed.
    entry.state = "done"
  elseif entry.dropAfter then
    removeEntries(run, { entry })
    noteRemoved(run, entry)
  elseif entry.state == "crafting" then
    if (number(entry.done) or 0) >= (number(entry.n) or 0) then
      entry.state = "done"
    else
      entry.state = "queued"
    end
  end
end

-- Brief PB1 addendum: whether a UI_ERROR_MESSAGE's payload is a craft refused for full bags
-- (Queue.IsFullError over the client's own name for the type, its LE_GAME_ERR_ constants and its
-- words). The payload has been through canRead (Queue.OnEvent) before it reaches here.
local function fullError(errorType, message)
  local known = {}
  for _, full in ipairs(Queue.FULL_ERRORS) do
    local text = rawget(_G, full)
    known[full] = { type = rawget(_G, "LE_GAME_" .. full), text = type(text) == "string" and text or nil }
  end
  local name = nil
  local info = globalFn("GetGameMessageInfo")
  if info and errorType ~= nil then
    local ok, answer = pcall(info, errorType)
    if ok and type(answer) == "string" and canRead(answer) then
      name = answer
    end
  end
  return Queue.IsFullError(errorType, message, name, known)
end
Queue.FullErrorNow = fullError

-- Brief PB1 addendum: the free slots in the backpack and the NUM_BAG_SLOTS bags a crafted item can
-- go in (Queue.RoomIn; the reagent bag is not among them), the modern C_Container call first, then
-- the classic global. Five local reads, never an item query. nil where the client will not say.
local function freeSlots()
  local container = rawget(_G, "C_Container")
  local ask = type(container) == "table" and container.GetContainerNumFreeSlots or nil
  if type(ask) ~= "function" then
    ask = globalFn("GetContainerNumFreeSlots")
  end
  if type(ask) ~= "function" then
    return nil
  end
  local bags = number(rawget(_G, "NUM_BAG_SLOTS")) or 4
  local answers = {}
  for bag = 0, bags do
    local ok, free, family = pcall(ask, bag)
    if ok and canRead(free) and canRead(family) then
      answers[#answers + 1] = { free, family }
    end
  end
  return Queue.RoomIn(answers)
end
Queue.FreeSlotsNow = freeSlots

--- Brief PB1 addendum (owner QA 2026-10-09, 1.60.1.70291: the bags filled during a Craft all run,
--- "1 of 2 crafts done"; he emptied them, opened the queue again, and it still said the inventory
--- was full): a stop for full bags (run.bagsFull, set where the client's error said so) is looked at
--- again once the bags may have room: a bag event (Queue.RoomEvent) and the tray shown again
--- (Queue.Show). With a free slot the full error is let go, and where the status still says it,
--- "Your bags have room again. Press Resume to go on." stands instead, paused, so the one button
--- reads Resume. It never crafts: the next craft is the player's press, as ever. With no room yet,
--- or a craft under way, nothing changes. Answers whether the stop was cleared.
function Queue.CheckRoom()
  local run = Queue.run
  if type(run) ~= "table" or run.demo or not run.bagsFull then
    return false
  end
  local flight = run.inFlight
  if type(flight) == "table" and not flight.stopped then
    return false
  end
  local free = freeSlots()
  if not free or free < 1 then
    return false
  end
  run.bagsFull = nil
  run.lastError, run.failedAt = nil, nil
  trace("bags have room again (%s free): the full bags stop is cleared", safe(free))
  if run.reason ~= nil and run.reason == run.failReason then
    run.paused, run.ready = true, false
    run.reason = Queue.WORDS.roomAgain
    run.failReason = nil
  end
  refresh()
  return true
end

--- Brief PB1 addendum: a bag event while a stop for full bags stands: one Queue.CheckRoom ROOM_GAP
--- seconds on, however many events come in between; nothing at all while no such stop stands.
--- Answers whether a look was booked, or made where the client has no timer.
function Queue.RoomEvent()
  local run = Queue.run
  if type(run) ~= "table" or not run.bagsFull or Queue.roomPending then
    return false
  end
  Queue.roomPending = true
  local booked = after(Queue.ROOM_GAP, function()
    Queue.roomPending = false
    Queue.CheckRoom()
  end)
  if booked then
    return true
  end
  Queue.roomPending = false
  return Queue.CheckRoom()
end

local SKILL_EVENTS = { CHAT_MSG_SKILL = true, SKILL_LINES_CHANGED = true, TRADE_SKILL_LIST_UPDATE = true }
local WINDOW_EVENTS =
  { TRADE_SKILL_SHOW = true, TRADE_SKILL_DATA_SOURCE_CHANGED = true, TRADE_SKILL_LIST_UPDATE = true }

-- The run's craft events (a start, a success, an interruption or failure, the client's error and
-- its blocked call). Answers whether the run moved, or nil where the event is not one of these.
local function onCraftEvent(run, event, a, ...)
  local flight = run.inFlight
  local unitEvent = type(event) == "string" and event:find("^UNIT_SPELLCAST_") ~= nil
  if event == "UNIT_SPELLCAST_START" or event == "TRADE_SKILL_CRAFT_BEGIN" then
    if type(flight) == "table" and (unitEvent or number(a) == flight.spell) then
      if flight.pauseStop and flight.stopped and unitEvent then
        -- Brief PR25: another craft of the batch began after the stop: it did not take.
        flight.stopped, flight.pauseStop = false, nil
        run.reason = Queue.WORDS.pausingBatch
        trace("pause: the batch went on after the stop")
      end
      flight.started = true
      if flight.entry and flight.entry.state == "queued" then
        flight.entry.state = "crafting"
      end
      refresh()
      if flight.chained then
        local craft = craftModule()
        if craft and type(craft.AutoChain) == "function" and craft.AutoChain() ~= true then
          craft.SetAutoChain(true, true)
        end
      end
    end
    return true
  end
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    flight.started = true
    flight.made = flight.made + 1
    local entry = flight.entry
    local group = groupOf(run, entry)
    if entry and entry.state == "queued" then
      entry.state = "crafting"
    end
    if entry then
      entry.done = (number(entry.done) or 0) + 1
    end
    run.crafted = (number(run.crafted) or 0) + 1
    if group ~= run and type(group) == "table" then
      -- Brief PR35 item 10: each group counts its own crafts.
      group.crafted = (number(group.crafted) or 0) + 1
    end
    if flight.made >= flight.n then
      finishFlight(run, flight)
      run.ready = true
      if flight.capped and entry and entry.state == "queued" and not flight.pauseAsked then
        -- Brief PR27: the batch was held to the points left; the row goes on with the next press.
        run.reason = string.format(Queue.WORDS.capped, flight.n)
      end
      if group.levelReached or not Queue.Current(run) or Queue.GroupFinished(run, group) then
        -- Brief PR27: the band's end reached mid batch, or nothing left: the group says why.
        settle(run, group, rankNow(group))
      end
      if group.levelDone then
        refresh()
        return true
      end
      if flight.pauseAsked then
        -- Brief PR25: paused during the batch's last craft; the queue holds at the next row.
        run.paused, run.ready = true, false
        run.reason = pausedWords(entry)
      elseif flight.stopped then
        -- The client's stop came before the last craft's success: it all went through after all.
        run.paused, run.reason = false, nil
      end
    elseif flight.levelStop and not flight.pauseAsked then
      -- Brief PR27: the stop at the band's end took, so this craft was the batch's last.
      finishFlight(run, flight)
      settle(run, group, rankNow(group))
    elseif flight.pauseAsked and (flight.pauseStop or flight.stopped) then
      -- Brief PR25: Pause stopped the repeats, so this craft was the batch's last; the row keeps
      -- its count still to make, and Resume crafts that.
      flight.stopped = true
      if entry and entry.state == "crafting" then
        entry.state = "queued"
      end
      run.paused, run.ready = true, false
      run.reason = pausedWords(entry)
    end
    refresh()
    return true
  end
  if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
    finishFlight(run, flight)
    run.paused = true
    if type(flight) == "table" and flight.pauseAsked then
      -- Brief PR39 item A: the player's Pause cancelled the cast (the main button's /stopcasting):
      -- paused, not interrupted; the row keeps its count still to make, and Resume crafts that.
      run.reason = pausedWords(flight.entry)
      trace("pause: the cast was cancelled (%s)", safe(event))
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
      run.reason = Queue.WORDS.interrupted
    else
      -- Brief PR25: the client's own error, "The craft failed: Requires Cooking Fire."
      fail(run, Queue.FailedText(run.lastError))
      if run.lastError == nil then
        run.failedAt = clock()
      end
    end
    refresh()
    return true
  end
  if event == "UI_ERROR_MESSAGE" then
    if type(flight) ~= "table" then
      -- Brief PR25: the client's error after its failed event: the failed line takes its words.
      local late = select(1, ...)
      local at, now = run.failedAt, clock()
      if at and now and now - at <= Queue.ERROR_WAIT and run.paused and type(late) == "string" and late ~= "" then
        run.failedAt = nil
        run.lastError = late
        -- Brief PB1 addendum: a craft refused for full bags is noted, for Queue.CheckRoom.
        run.bagsFull = fullError(a, late) or nil
        fail(run, Queue.FailedText(late))
        refresh()
        return true
      end
      return false
    end
    local message = select(1, ...)
    -- Brief PB1 addendum: a craft refused for full bags is noted, for Queue.CheckRoom.
    run.bagsFull = fullError(a, message) or nil
    if run.bagsFull then
      trace("bags full: the craft was refused")
    end
    message = type(message) == "string" and message ~= "" and message or Queue.WORDS.failed
    run.lastError = message
    if not flight.started then
      -- The craft never began: stop here and say why.
      finishFlight(run, flight)
      run.paused = true
      fail(run, message)
      refresh()
    end
    return true
  end
  if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    local b = select(1, ...)
    local ours = type(a) == "string" and a:find("^ItemTree") ~= nil
    local craft = craftModule()
    local fromEvent = type(flight) == "table" and flight.stopFrom == "event"
    if ours and craft and type(craft.StopBlocked) == "function" and craft.StopBlocked(b, fromEvent) then
      if fromEvent then
        -- Brief PR27: the stop at the band's end was refused: not tried from an event again this
        -- session; the batch finishes and the queue stops after it.
        trace("level end: the stop call was blocked (%s)", safe(event))
        flight.levelStop = nil
        return true
      end
      -- Brief PR25: the client refused the batch stop: never again this session, and the batch
      -- runs on.
      trace("pause: the stop call was blocked (%s)", safe(event))
      if type(flight) == "table" and flight.pauseStop then
        flight.pauseStop = nil
        if not flight.stopped then
          run.reason = Queue.WORDS.pausingBatch
        end
        refresh()
      end
      return true
    end
    if ours and type(flight) == "table" and flight.chained then
      chainFailed(true)
      return true
    end
    return false
  end
  return nil
end

--- The run's events. Answers whether the run moved.
function Queue.OnEvent(event, ...)
  local run = Queue.run
  if not run or run.demo then
    return false
  end
  -- Brief PR38: the line the window shows now, so the open profession's group goes first.
  noteOpen(run)
  if event == "TRADE_SKILL_CLOSE" then
    -- Brief PR22: the queue closes with the profession window; the run is kept.
    Queue.HideWithWindow()
    return true
  end
  if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
    -- Brief PR21: the profession window the click opened is up now; the tray docks beside it.
    -- Brief PR22: again when the window changes profession (its side tabs may come or go), and a
    -- tray that closed with the window comes back with it on a queued profession's line.
    Queue.Dock()
  end
  if WINDOW_EVENTS[event] then
    Queue.Restore()
  end
  local a, b, c = ...
  local unitEvent = type(event) == "string" and event:find("^UNIT_SPELLCAST_") ~= nil
  -- Brief SV1: a cast with a payload value the client keeps secret is not looked at; any other
  -- event (CHAT_MSG_SKILL's text carries no NeverSecret mark) still counts, without its payload.
  local scrubbed = not (canRead(a) and canRead(b) and canRead(c))
  if scrubbed then
    if unitEvent then
      return false
    end
    a, b, c = nil, nil, nil
  end
  if Queue.tracing then
    trace("event %s %s %s %s", safe(event), safe(a), safe(b), safe(c))
  end
  local flight = run.inFlight
  if unitEvent and a == "player" then
    -- Brief PR40 item B: the player's cast as the client tells it (Craft.NoteCast), so the main
    -- button's "/stopcasting" is set only while the queue's craft is being cast.
    local craft = craftModule()
    if craft and type(craft.NoteCast) == "function" then
      craft.NoteCast(event, a, c)
    end
    pcall(Queue.SyncStop)
  end
  if unitEvent and (a ~= "player" or type(flight) ~= "table" or number(c) ~= flight.spell) then
    return false
  end
  local answer
  if scrubbed then
    answer = onCraftEvent(run, event, nil)
  else
    answer = onCraftEvent(run, event, a, select(2, ...))
  end
  if answer ~= nil then
    return answer
  end
  if event == "PLAYER_REGEN_DISABLED" then
    -- Brief PR39 item A: the client fires this just before its combat lockdown starts, so the
    -- pause's redraw still clears the main button's "/stopcasting" (Queue.SyncStop); nothing
    -- touches the button itself after.
    Queue.Pause(Queue.WORDS.combat)
    return true
  end
  if event == "PLAYER_REGEN_ENABLED" then
    -- Brief PR39 item A: lockdown is over; the main button follows the queue's state again.
    Queue.SyncStop()
    return false
  end
  local moved = false
  if event == "UPDATE_TRADESKILL_CAST_STOPPED" and type(flight) == "table" then
    local group = groupOf(run, flight.entry)
    if flight.made < flight.n and group.levelReached and not flight.pauseAsked then
      -- Brief PR27: the batch stopped at the band's end: the group stops with its card.
      finishFlight(run, flight)
      settle(run, group, rankNow(group) or group.rank)
      refresh()
      return true
    end
    if flight.made < flight.n then
      flight.stopped = true
      if flight.entry and flight.entry.state == "crafting" then
        flight.entry.state = "queued"
      end
      run.paused = true
      if flight.pauseAsked then
        run.reason = pausedWords(flight.entry)
      elseif run.lastError then
        fail(run, run.lastError)
      else
        run.reason = string.format(Queue.WORDS.stoppedAfter, flight.made, flight.n)
      end
      refresh()
      return true
    end
  end
  if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
    -- Brief PR24: the rows the window now says are not learnt leave the queue.
    if dropUnlearnt(run) > 0 then
      moved = true
      refresh()
    end
  end
  if SKILL_EVENTS[event] or WINDOW_EVENTS[event] then
    -- Brief PR22: the client's word on each queued recipe while its window shows, else the data's.
    -- Brief PR35: each group at its own line's rank.
    local withRank = SKILL_EVENTS[event] == true
    local dropped, ranked = trimAll(run, withRank)
    if dropped > 0 or ranked then
      -- Brief PR35 item 10: a skill up moves the group's summary too.
      moved = moved or dropped > 0
      refresh()
    end
    local active = Queue.ActiveGroup(run)
    if withRank and type(active) == "table" and settle(run, active, active.rank) then
      -- Brief PR27: the band's end, or nothing left below it.
      moved = true
    end
  end
  if event == "TRADE_SKILL_SHOW" then
    -- Brief PR27: the window is up before any press: a group's rows sized again with the client's
    -- colours.
    for _, group in ipairs(Queue.Groups(run)) do
      if windowOpen(group) and untouched(run, group) and resize(run, group, rankNow(group)) then
        moved = true
        refresh()
      end
    end
  end
  if WINDOW_EVENTS[event] then
    checkLine(run)
  end
  local active = Queue.ActiveGroup(run) or run
  if WINDOW_EVENTS[event] and run.waitingWindow and windowOpen(active) then
    run.waitingWindow = false
    if Queue.Mode() == "auto" and not run.paused then
      run.ready = true
    elseif run.switched then
      -- Brief PR25: the switch line names the button the tray shows now the window is up.
      if run.switchReason ~= nil and run.reason == run.switchReason then
        run.reason = lineWords(run, run.switchWords or Queue.WORDS.switched, Queue.WORDS.switchedAny, active)
        run.switchReason = run.reason
      end
      refresh()
    elseif not run.paused then
      -- Brief PR25: the window is up; the press still to make is Craft next once started, else the
      -- ready line's Start craft queue.
      run.reason = run.started and Queue.WORDS.pressNext or nil
      refresh()
    end
    moved = true
  end
  if
    (event == "BAG_UPDATE_DELAYED" or event == "UPDATE_TRADESKILL_CAST_STOPPED" or WINDOW_EVENTS[event])
    and run.ready
  then
    moved = chain() or moved
  end
  if event == "BAG_UPDATE_DELAYED" then
    -- Brief PB1 addendum: a stop for full bags looks at the free slots again, once per burst.
    Queue.RoomEvent()
  end
  if event == "BAG_UPDATE_DELAYED" or event == "TRADE_SKILL_LIST_UPDATE" then
    -- Brief PR25: a tool in or out of the bags, or the window's own update: the box reads again.
    refresh()
  elseif WINDOW_EVENTS[event] and Queue.tray and rawget(Queue.tray, "shown") then
    -- Brief PR38: the player changed the window's profession: the button says what a press does now.
    local primary = rawget(Queue.tray, "primary")
    if type(primary) == "table" and rawget(primary, "labelText") ~= buttonWord(run) then
      refresh()
    end
  end
  return moved
end

Queue.EVENTS = {
  "BAG_UPDATE_DELAYED",
  "UPDATE_TRADESKILL_CAST_STOPPED",
  "TRADE_SKILL_CRAFT_BEGIN",
  "TRADE_SKILL_SHOW",
  "TRADE_SKILL_CLOSE",
  "TRADE_SKILL_LIST_UPDATE",
  "TRADE_SKILL_DATA_SOURCE_CHANGED",
  "UI_ERROR_MESSAGE",
  "ADDON_ACTION_BLOCKED",
  "ADDON_ACTION_FORBIDDEN",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
  "CHAT_MSG_SKILL",
  "SKILL_LINES_CHANGED",
}
Queue.UNIT_EVENTS = {
  "UNIT_SPELLCAST_START",
  "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_SUCCEEDED",
  "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_FAILED",
}

local function eventFrame()
  if Queue.frame then
    return Queue.frame
  end
  local create = globalFn("CreateFrame")
  if not create then
    return nil
  end
  local ok, frame = pcall(create, "Frame")
  if not ok or type(frame) ~= "table" or type(frame.RegisterEvent) ~= "function" then
    return nil
  end
  if type(frame.SetScript) == "function" then
    pcall(frame.SetScript, frame, "OnEvent", function(_, event, ...)
      Queue.OnEvent(event, ...)
    end)
  end
  Queue.frame = frame
  return frame
end

ensureEvents = function()
  if Queue.listening then
    return true
  end
  local frame = eventFrame()
  if not frame then
    return false
  end
  for _, event in ipairs(Queue.EVENTS) do
    pcall(frame.RegisterEvent, frame, event)
  end
  for _, event in ipairs(Queue.UNIT_EVENTS) do
    local done = false
    if type(frame.RegisterUnitEvent) == "function" then
      done = pcall(frame.RegisterUnitEvent, frame, event, "player")
    end
    if not done then
      pcall(frame.RegisterEvent, frame, event)
    end
  end
  Queue.listening = true
  return true
end

releaseEvents = function()
  local frame = Queue.frame
  if not Queue.listening or not frame then
    return false
  end
  -- Brief PR40 item B: no cast is heard from here, so none is taken as under way.
  local craft = craftModule()
  if craft and type(craft.NoteCast) == "function" then
    craft.NoteCast("UNIT_SPELLCAST_STOP", "player", nil)
  end
  if type(frame.UnregisterAllEvents) == "function" then
    pcall(frame.UnregisterAllEvents, frame)
  end
  Queue.listening = false
  return true
end

-- Brief PR35: whether a run takes another group: a real run that still has a group.
local function addable(run)
  return type(run) == "table" and not run.demo and not run.cleared and type(run.groups) == "table" and #run.groups > 0
end

--- The Create all click (Craft.Click). Brief PR21: builds the band's queue, opens the profession
--- window (out of combat, where it is shut) and shows the tray docked beside the profession window;
--- brief PR39: the ItemTree window stays open where it is. It crafts nothing: the tray waits for the
--- player's press. Brief PR35: the band's rows are ADDED to the queue as the profession's group
--- (brief PR39: at the top, refreshing the group it already has); the other professions' groups and
--- their progress stay. Answers "queue" (the tray shows) or nil.
function Queue.OpenFor(skillLine, bandIndex, track)
  local craft = craftModule()
  if not craft then
    return nil
  end
  skillLine = number(skillLine)
  track = type(craft.TrackFor) == "function" and craft.TrackFor(skillLine, track) or track
  if type(track) ~= "table" then
    return nil
  end
  local order = type(craft.Order) == "function" and craft.Order(track, bandIndex) or {}
  local counts = type(craft.Counts) == "function" and craft.Counts(order) or {}
  local lineName = type(craft.LineName) == "function" and craft.LineName(skillLine) or nil
  local open = type(craft.IsOpen) == "function" and craft.IsOpen(skillLine, lineName) or false
  local known = type(craft.Known) == "function" and craft.Known(order, open) or nil
  local vendorable = Queue.Vendorable(order)
  -- Brief PR27: only enough to reach the band's end, from the real rank.
  local rank = type(craft.Rank) == "function" and craft.Rank(skillLine, true) or nil
  local colourOf = type(craft.ColourOf) == "function" and craft.ColourOf(open) or nil
  local built = Queue.Build(track, bandIndex, counts, known, vendorable, { rank = rank, colourOf = colourOf })
  local old = Queue.run
  local run = old
  local fresh = not addable(old)
  if fresh then
    run = { groups = {}, entries = {}, crafted = 0 }
    if old and not old.demo and type(old.inFlight) == "table" and not old.inFlight.stopped then
      -- A craft is under way from the last queue: the new one waits for a press.
      run.reason = Queue.WORDS.pressNext
      run.started = true
    end
  end
  local busy = type(run.inFlight) == "table" and not run.inFlight.stopped
  local finishedBand = number(rank) and number(built.hi) and rank >= built.hi
  local group = nil
  if finishedBand or #built.entries == 0 then
    -- Nothing to add for this band: the group the profession had goes with its old rows.
    for _, candidate in ipairs(Queue.Groups(run)) do
      if candidate ~= run and number(candidate.line) == skillLine then
        Queue.ClearGroup(run, candidate)
        run.cleared = nil
        break
      end
    end
    local src = { line = skillLine, band = number(bandIndex), track = track }
    if finishedBand then
      -- Brief PR27: Create all on a band already finished.
      run.levelDone, run.levelTrack, run.levelBand = true, track, number(bandIndex)
      doneLine(run, type(craft.DoneText) == "function" and craft.DoneText(track, bandIndex) or nil)
    elseif type(run.groups) == "table" and #run.groups > 0 then
      local why = bandWhy(run, src)
      if why then
        fail(run, why)
      end
    else
      run.emptyFor = src
    end
  else
    group = {
      line = skillLine,
      band = number(bandIndex),
      track = track,
      hi = built.hi,
      rank = rank,
      startRank = rank,
      warnings = built.warnings,
      vendorable = vendorable,
    }
    local added, _, carried = Queue.AddGroup(run, group, built.entries)
    group = added
    if carried then
      -- Brief PR39 item B: a count the player set is kept, lowered only where the bags fall short.
      resize(run, group, rank)
    end
    run.levelDone, run.emptyFor = nil, nil
    if not fresh and not busy and not run.paused then
      run.reason = nil
    end
    Queue.scrollTo = group
  end
  Queue.run = run
  if fresh then
    Queue.offset = 0
  end
  ensureEvents()
  if inCombat() then
    run.paused, run.reason = true, Queue.WORDS.combat
  elseif not open and group and type(craft.Open) == "function" then
    craft.Open(skillLine)
    -- Brief PR22: the window must show the current row's line; a moment on (the client's own show
    -- handler first), the tray says so where it shows another.
    after(Queue.CONFIRM_WAIT, function()
      if Queue.run == run then
        checkLine(run)
      end
    end)
  end
  if open and group then
    -- Brief PR22: the client's own word on each queued recipe while its window shows.
    trim(run, nil, group)
  end
  -- Brief PR39 item D (the owner: "Clicking 'Craft all' should not close the itemtree window"): the
  -- ItemTree window stays where it is. What closed it was this function's own call to the window's
  -- Hide (brief PR21), not the client's panel manager: the window is not one of the client's UI
  -- panels (no UIPanelWindows entry, so ShowUIPanel never makes room by closing it), and the
  -- profession window's open (C_TradeSkillUI.OpenTradeSkill) runs no CloseSpecialWindows.
  if Queue.tray then
    Queue.tray.moved = nil
  end
  -- Brief PW1 (QA item 238 d): Craft all brings the profession window in front of ItemTree's where
  -- it already shows (a window still opening takes the front as it shows, UI/Frame.lua).
  Queue.TellWindow(true)
  Queue.Show()
  return "queue"
end

-- Brief PR39 item B: the demo's made up room for a row's "+": a few more than it holds.
Queue.DEMO_SPARE = 3

-- Brief PR39 item B: the most a row may hold now (Queue.RowMost): the bags for every live row's
-- reagents, the row's group's rank and the client's colours while its window shows. The demo's
-- rows get DEMO_SPARE more than they hold, and ask the bags nothing.
local function rowMost(run, entry, counts)
  if type(run) ~= "table" or type(entry) ~= "table" then
    return 0
  end
  if run.demo then
    return (number(entry.n) or 0) + Queue.DEMO_SPARE
  end
  if counts == nil then
    local craft = craftModule()
    local nodes = {}
    for _, other in ipairs(type(run.entries) == "table" and run.entries or EMPTY) do
      if LIVE[other.state] then
        nodes[#nodes + 1] = other.node
      end
    end
    counts = craft and type(craft.Counts) == "function" and craft.Counts(nodes) or {}
  end
  local group = groupOf(run, entry)
  local rank = type(group) == "table" and number(group.rank) or nil
  if rank == nil and group ~= run then
    rank = rankNow(group)
  end
  return Queue.RowMost(run, entry, counts, rank, clientColours(run, group))
end
Queue.RowMostNow = rowMost

--- Brief PR39 item B: a row's "+" (delta 1) or "-" (delta -1) clicked: the count moves by one
--- (Queue.StepRow) within what the row may hold now, and the tray is drawn again. Answers whether it
--- moved.
function Queue.StepClick(index, delta)
  local run = Queue.run
  local entries = type(run) == "table" and type(run.entries) == "table" and run.entries or EMPTY
  local entry = entries[number(index) or 0]
  if not entry then
    return false
  end
  local most = delta and number(delta) and number(delta) > 0 and rowMost(run, entry) or nil
  if not Queue.StepRow(run, index, delta, most) then
    return false
  end
  trace("row %s set to %s", safe(entry.spell), safe(entry.n))
  refresh()
  return true
end

--- Empties the queue and lets the events go once nothing is under way.
function Queue.ClearRun()
  local run = Queue.run
  if not run then
    return false
  end
  Queue.Clear(run)
  releaseEvents()
  refresh()
  return true
end

--- Brief PR35 item 2: a group header's own Clear: that profession's group goes, the others stay; the
--- last one going empties the queue as the top Clear does.
function Queue.ClearGroupRun(group)
  local run = Queue.run
  if not run or not Queue.ClearGroup(run, group) then
    return false
  end
  if type(run.groups) == "table" and #run.groups == 0 then
    releaseEvents()
  end
  refresh()
  return true
end

--- Brief PR36 (the owner: "instead of the Craft all button, just say 'View X to Y', which takes you
--- back to the Professions tab in ItemTree"): the celebration card's "View 45 to 55". The pane is
--- told the group's line (Pane.selected) with its remembered view let go, the window opens on the
--- Professions tab (Queue.BackToItemTree: Frame.Open, Frame.SelectTab), and once the pane has drawn
--- the line (Pane.Refresh, Pane.chosen) its view is the PR15 view rule (Pane.DefaultView) on the
--- next band's column (Queue.BandColumn), drawn again through Pane.Refresh. It builds no queue and crafts nothing; a
--- demo run's button does the same. Answers "view" where the window took it, else nil.
function Queue.ViewBandClick(group)
  local nextBand = Queue.NextBand(group)
  if not nextBand then
    return nil
  end
  local line = number(group.line)
  local p = pane()
  if p and line then
    p.selected = line
    if type(p.views) == "table" then
      p.views[line] = nil
    end
  end
  if not Queue.BackToItemTree() then
    return nil
  end
  -- The tab may already have been up on another line: drawn again on this one first.
  if p and type(p.Refresh) == "function" then
    pcall(p.Refresh)
  end
  local chosen = p and type(p.chosen) == "table" and p.chosen or nil
  if chosen and line and number(chosen.line) == line then
    local layout = type(p.layout) == "table" and p.layout or nil
    local index = layout and Queue.BandColumn(layout.columns, nextBand) or nil
    local viewport = p.viewport
    if index and type(p.DefaultView) == "function" and type(viewport) == "table" then
      local okW, vw = pcall(viewport.GetWidth, viewport)
      local okH, vh = pcall(viewport.GetHeight, viewport)
      local focus = { columns = layout.columns, current = index, width = layout.width, height = layout.height }
      local ok, zoom, panX, panY =
        pcall(p.DefaultView, focus, nil, okW and tonumber(vw) or 0, okH and tonumber(vh) or 0)
      if ok and type(p.views) == "table" then
        p.views[line] = { zoom = zoom, panX = panX, panY = panY }
        if type(p.Refresh) == "function" then
          pcall(p.Refresh)
        end
      end
    end
  end
  return "view"
end

--------------------------------------------------------------------------------
-- The tray
--------------------------------------------------------------------------------

local function newFrame(kind, parent)
  local create = globalFn("CreateFrame")
  if not create then
    return nil
  end
  local ok, frame = pcall(create, kind, nil, parent)
  if ok and type(frame) == "table" then
    return frame
  end
  return nil
end

-- Brief PM1 (brief G1 reaching the Professions code): every script body set through setScript
-- runs under ItemTree.Guard.Run, the boundary main's panes use, so a fault in one is handed to the
-- client's error handler once and the rest of the tab keeps working. Only ItemTree's own handlers
-- on ItemTree's own frames are wrapped. raw sets the handler as it is: the hardware event craft
-- path (the Craft all button's click, the queue's press and pause) stays exactly as proven in game.
local guardScript = ItemTree.ProfessionsKit.GuardScript

local function setScript(frame, script, handler, raw)
  if type(frame) ~= "table" or type(frame.SetScript) ~= "function" then
    return false
  end
  if type(frame.HasScript) == "function" then
    local ok, has = pcall(frame.HasScript, frame, script)
    if not ok or not has then
      return false
    end
  end
  if not raw then
    handler = guardScript("Professions.Queue." .. tostring(script), handler)
  end
  return (pcall(frame.SetScript, frame, script, handler))
end

local setShown = ItemTree.ProfessionsKit.SetShown
local tint = ItemTree.ProfessionsKit.Tint
local textColour = ItemTree.ProfessionsKit.TextColour
local applyAsset = ItemTree.ProfessionsKit.ApplyAsset
local newTexture = ItemTree.ProfessionsKit.NewTexture
local wash = ItemTree.ProfessionsKit.Wash

-- Four hairline edges, the flat fallback where the card will not draw.
local edges = ItemTree.ProfessionsKit.Edges

-- Font safety (UI/Sidebar.lua's shape): a template first, the font checked, and a client font
-- object put on before any SetText. Brief PR21: the tray's words keep the client font object's own
-- face and size (GameFontNormal, GameFontHighlight), not a small Arial Narrow.
local function fallbackFont(fontString, fallbacks)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(fallbacks or Queue.FONT_FALLBACKS) do
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

local function ensureFont(fontString, fallbacks)
  if hasFont(fontString) then
    return true
  end
  return fallbackFont(fontString, fallbacks)
end

-- A FontString in the named client font object (its template, then the object itself put on), with
-- fallbacks where the client has neither. The object's own shadow is kept.
local function newText(parent, fontName, colourKey, justify, wrap, fallbacks)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY", fontName)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY")
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  local object = rawget(_G, fontName)
  if object ~= nil and type(fontString.SetFontObject) == "function" then
    pcall(fontString.SetFontObject, fontString, object)
  end
  ensureFont(fontString, fallbacks)
  fontString.fontName = fontName
  if type(fontString.SetJustifyH) == "function" then
    pcall(fontString.SetJustifyH, fontString, justify or "LEFT")
  end
  if type(fontString.SetWordWrap) == "function" then
    pcall(fontString.SetWordWrap, fontString, wrap == true)
  end
  textColour(fontString, colourKey)
  return fontString
end

local function setText(fontString, text)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  ensureFont(fontString, rawget(fontString, "fallbacks"))
  return (pcall(fontString.SetText, fontString, text or ""))
end

local function measure(fontString, method)
  if type(fontString) ~= "table" or type(fontString[method]) ~= "function" then
    return nil
  end
  local ok, value = pcall(fontString[method], fontString)
  value = ok and tonumber(value) or nil
  if value and value > 0 then
    return value
  end
  return nil
end

local hideTooltip = ItemTree.ProfessionsKit.HideTooltip

local function textTooltip(owner, title, lines)
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  pcall(tooltip.SetOwner, tooltip, owner, "ANCHOR_RIGHT")
  if type(tooltip.SetText) == "function" then
    pcall(tooltip.SetText, tooltip, title or "")
  end
  for _, line in ipairs(lines or EMPTY) do
    if type(tooltip.AddLine) == "function" then
      pcall(tooltip.AddLine, tooltip, line, 1, 1, 1, true)
    end
  end
  if type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  return true
end

local function enable(button, enabled)
  if type(button) ~= "table" then
    return
  end
  button.canPress = enabled == true
  -- Brief PR40 item B: the secure main button is never enabled, disabled or faded itself (each is
  -- refused in combat lockdown); its art child (our plain frame) fades, and its PostClick reads
  -- canPress.
  local art = rawget(button, "secure") and rawget(button, "art") or nil
  if art then
    if type(art.SetAlpha) == "function" then
      pcall(art.SetAlpha, art, enabled and 1 or 0.5)
    end
  else
    if type(button.SetEnabled) == "function" then
      pcall(button.SetEnabled, button, enabled == true)
    end
    if type(button.SetAlpha) == "function" then
      pcall(button.SetAlpha, button, enabled and 1 or 0.5)
    end
  end
  local s = skin()
  if s and type(s.PaintPlate) == "function" and rawget(button, "plated") then
    pcall(s.PaintPlate, button, "normal")
  end
end

-- A labelled button: the Professions plate (Skin.PlateButton) where the window has one, else a
-- flat face with a hairline edge. onClick runs inside the click, so it is a hardware event.
-- raw: the click is the hardware event craft path, set with no boundary (setScript).
local function newButton(parent, w, onClick, hint, raw)
  local s = skin()
  local button = nil
  if s and type(s.PlateButton) == "function" then
    local ok, made = pcall(s.PlateButton, parent, w, Queue.BUTTON_H)
    button = ok and type(made) == "table" and made or nil
  end
  local labelParent = button and (rawget(button, "labelParent") or button) or nil
  if not button then
    button = newFrame("Button", parent)
    if not button then
      return nil
    end
    button:SetSize(w, Queue.BUTTON_H)
    button.face = wash(button, "BACKGROUND", Queue.FACE)
    if button.face then
      button.face:SetAllPoints(button)
    end
    button.edges = edges(button, Queue.BORDER)
    button.hover = wash(button, "HIGHLIGHT", Queue.HOVER)
    if button.hover then
      button.hover:SetAllPoints(button)
    end
    labelParent = button
  end
  button.label = newText(labelParent, Queue.FONT_TITLE, Queue.PLATE_WORD, "CENTER")
  if button.label then
    button.label:SetPoint("LEFT", button, "LEFT", 4, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -4, 0)
  end
  if type(button.RegisterForClicks) == "function" then
    pcall(button.RegisterForClicks, button, "LeftButtonUp")
  end
  local function onEnter(self)
    local words = rawget(self, "hint")
    if words then
      textTooltip(self, rawget(self, "tipTitle") or rawget(self, "labelText") or "", { words })
    end
  end
  if rawget(button, "plated") and s and type(s.PlateScripts) == "function" then
    s.PlateScripts(button, setScript, { OnEnter = onEnter, OnLeave = hideTooltip })
  else
    setScript(button, "OnEnter", onEnter)
    setScript(button, "OnLeave", hideTooltip)
  end
  setScript(button, "OnClick", function()
    onClick()
  end, raw)
  button.hint = hint
  button:Show()
  return button
end

local function setLabel(button, text)
  if type(button) ~= "table" then
    return
  end
  button.labelText = text
  setText(button.label, text)
end

-- The owner, 2026-10-02: a material clicked in the tray (a warning's item, an ingredient) opens
-- straight on its Sources view, through the pane's ClickMaterial (modified clicks first, E6); a
-- pane without it gets OpenKey with the view.
local function openMaterial(itemId, button)
  local p = pane()
  itemId = number(itemId)
  if not itemId or not p then
    return false
  end
  local key = "item:" .. itemId
  if type(p.ClickMaterial) == "function" then
    return (pcall(p.ClickMaterial, key, button))
  end
  if type(p.OpenKey) == "function" then
    return (pcall(p.OpenKey, key, { view = "sources" }))
  end
  return false
end
Queue.OpenMaterial = openMaterial

-- A frame's edge in screen pixels: its own GetLeft or GetRight times its effective scale.
local function screenEdge(frame, method)
  if type(frame) ~= "table" or type(frame[method]) ~= "function" then
    return nil
  end
  local ok, value = pcall(frame[method], frame)
  value = ok and tonumber(value) or nil
  if not value then
    return nil
  end
  local scale = 1
  if type(frame.GetEffectiveScale) == "function" then
    local fine, answer = pcall(frame.GetEffectiveScale, frame)
    scale = fine and tonumber(answer) or 1
  end
  return value * scale
end

local function effectiveScale(frame)
  if type(frame) == "table" and type(frame.GetEffectiveScale) == "function" then
    local ok, answer = pcall(frame.GetEffectiveScale, frame)
    answer = ok and tonumber(answer) or nil
    if answer and answer > 0 then
      return answer
    end
  end
  return 1
end

-- Brief PR38: the tray's own 1 px anchor for a row's tooltip. Brief PR39 item F2: placed beside
-- the hovered element itself (Queue.TipPlacement, Queue.TipSide, Queue.TipDrop), read in screen
-- pixels. Answers the owner and the anchor word for SetOwner.
local function tipAnchor(element)
  local tray = Queue.tray
  if type(tray) ~= "table" then
    return element, "ANCHOR_RIGHT"
  end
  local anchor = rawget(tray, "tipAnchor")
  if not anchor then
    anchor = newFrame("Frame", tray)
    if not anchor then
      return element, "ANCHOR_RIGHT"
    end
    anchor:SetSize(1, 1)
    tray.tipAnchor = anchor
  end
  local scale = effectiveScale(element)
  local side =
    Queue.TipSide(screenEdge(element, "GetRight"), screenEdge(rawget(_G, "UIParent"), "GetRight"), Queue.TIP_W * scale)
  local drop = Queue.TipDrop(screenEdge(element, "GetTop"), screenEdge(rawget(tray, "scroll"), "GetTop")) / scale
  local place = Queue.TipPlacement(side, drop)
  anchor:ClearAllPoints()
  anchor:SetPoint(place.point, element, place.relative, place.x, place.y)
  anchor:Show()
  return anchor, place.anchor
end

-- Brief PR38: a row's tooltip, the client's own for the crafted item or the reagent (SetItemByID,
-- else the item link; a recipe with no item its spell), so ItemTree's own tooltip lines come with
-- it as on a tree row or a Professions card; the name alone where none draws. extra lines follow
-- in the client's green hint colour. Beside the tray, never over its buttons (tipAnchor).
local function itemTip(row, itemId, spell, name, extra)
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  local owner, where = tipAnchor(row)
  pcall(tooltip.SetOwner, tooltip, owner, where)
  local drawn = false
  itemId, spell = number(itemId), number(spell)
  if itemId then
    drawn = type(tooltip.SetItemByID) == "function" and pcall(tooltip.SetItemByID, tooltip, itemId) or false
    if not drawn and type(tooltip.SetHyperlink) == "function" then
      drawn = pcall(tooltip.SetHyperlink, tooltip, "item:" .. itemId)
    end
  elseif spell then
    drawn = type(tooltip.SetSpellByID) == "function" and pcall(tooltip.SetSpellByID, tooltip, spell) or false
  end
  if not drawn and type(tooltip.AddLine) == "function" then
    pcall(tooltip.AddLine, tooltip, name or "")
  end
  for _, line in ipairs(extra or EMPTY) do
    if type(tooltip.AddLine) == "function" then
      pcall(tooltip.AddLine, tooltip, line, 0.1, 1, 0.1, true)
    end
  end
  if type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  return true
end
Queue.ItemTip = itemTip

-- A hit area of a row: a highlight on hover where lit, mouse over for its tooltip, and a drag from
-- it moves the tray, as a drag from the tray does (the click that ends a drag is swallowed).
local function buildHit(row, lit)
  local hit = newFrame("Button", row)
  if not hit then
    return nil
  end
  hit.row = row
  if lit then
    hit.hover = wash(hit, "HIGHLIGHT", Queue.HOVER)
    if hit.hover then
      hit.hover:SetAllPoints(hit)
    end
  end
  if type(hit.RegisterForDrag) == "function" then
    pcall(hit.RegisterForDrag, hit, "LeftButton")
  end
  setScript(hit, "OnDragStart", function(self)
    self.dragged = true
    local tray = Queue.tray
    if type(tray) == "table" and type(tray.StartMoving) == "function" then
      pcall(tray.StartMoving, tray)
    end
  end)
  setScript(hit, "OnDragStop", function()
    local tray = Queue.tray
    if type(tray) == "table" and type(tray.StopMovingOrSizing) == "function" then
      pcall(tray.StopMovingOrSizing, tray)
      tray.moved = true
    end
  end)
  setScript(hit, "OnLeave", hideTooltip)
  return hit
end

-- Brief PR38: the crafted item's hit area over a row's icon or its name: the item's own tooltip.
local function buildRecipeHit(row)
  local hit = buildHit(row, false)
  if not hit then
    return nil
  end
  setScript(hit, "OnEnter", function(self)
    itemTip(self, rawget(self, "item"), rawget(self, "spell"), rawget(self, "name"), nil)
  end)
  return hit
end

-- One ingredient's hit area over its icon and words: a highlight on hover, the item tooltip with
-- the hint (brief PR38: beside the tray, as the crafted item's), and a click that opens the item on
-- its Sources view.
local function buildIngredient(row)
  local hit = buildHit(row, true)
  if not hit then
    return nil
  end
  if type(hit.RegisterForClicks) == "function" then
    pcall(hit.RegisterForClicks, hit, "LeftButtonUp")
  end
  setScript(hit, "OnEnter", function(self)
    local itemId = number(rawget(self, "item"))
    if itemId then
      itemTip(self, itemId, nil, rawget(self, "name"), { Queue.WORDS.warningHint })
    end
  end)
  setScript(hit, "OnClick", function(self, button)
    if rawget(self, "dragged") then
      self.dragged = nil
      return
    end
    openMaterial(rawget(self, "item"), button)
  end)
  return hit
end

--- Brief PRX (PR45): sizes the badge to its letter as the client measures it now (Queue.BadgeWidth),
--- and draws its gold to that width: at build, and again each time a row is filled, so a letter
--- measured late (the font not ready when the tray was built) never sits past the gold's edge.
--- Answers the badge's width.
function Queue.FitTag(tag)
  if type(tag) ~= "table" then
    return nil
  end
  local w = Queue.BadgeWidth(measure(tag.text, "GetStringWidth"), Queue.WORDS.badge)
  if rawget(tag, "w") == w and rawget(tag, "fitted") then
    return w
  end
  tag.w = w
  tag.fitted = true
  tag:SetWidth(w)
  local s = skin()
  local drawn = s
      and type(s.Card) == "function"
      and s.Card(tag, w, Queue.BADGE_H, {
        fill = Queue.TAG_GOLD,
        edge = Queue.TAG_GOLD,
        thickness = 1,
        chamfer = Queue.BADGE_CHAMFER,
        -- Brief PR41 item 2: the flat gold chamfer, never the client's border art (whose corners
        -- filled the small badge and hid its letter).
        art = false,
        store = "tagPieces",
      })
    or false
  setShown(tag.fill, not drawn)
  return w
end

--- Brief PR21: the Recommended tag, the cards' own (UI/Pane.lua buildTag): dark words in the
--- client's Friz Quadrata font object GameFontBlackSmall, no shadow, on solid card gold with a
--- small chamfer (Skin.Card); a square gold fill where that will not draw. Brief PR40 item D: a
--- BADGE_H px badge holding the one letter "R" (Queue.BadgeWidth), set beside the recipe's name, its
--- hover saying what it means. Brief PR41 item 2: 20 px, the flat gold chamfer, the letter in
--- GameFontBlack inset BADGE_INSET px or more. Answers the badge frame, its width set from its measured letter.
function Queue.NewTag(parent)
  local tag = newFrame("Frame", parent)
  if not tag then
    return nil
  end
  tag:SetHeight(Queue.BADGE_H)
  tag.fill = wash(tag, "BACKGROUND", Queue.TAG_GOLD)
  if tag.fill then
    tag.fill:SetAllPoints(tag)
  end
  tag.text = newText(tag, Queue.BADGE_FONT, Queue.TAG_WORD, "CENTER", false, Queue.BADGE_FONTS)
  if tag.text then
    tag.text.fallbacks = Queue.BADGE_FONTS
    tag.text:SetPoint("CENTER", tag, "CENTER", 0, 0)
    -- Brief PR20 (the owner), as PR19 did on the cards: the dark words on the gold read clearly
    -- without a shadow.
    if type(tag.text.SetShadowOffset) == "function" then
      pcall(tag.text.SetShadowOffset, tag.text, 0, 0)
    end
    if type(tag.text.SetShadowColor) == "function" then
      pcall(tag.text.SetShadowColor, tag.text, 0, 0, 0, 0)
    end
    setText(tag.text, Queue.WORDS.badge)
    textColour(tag.text, Queue.TAG_WORD)
  end
  Queue.FitTag(tag)
  -- The hover: what the letter means.
  if type(tag.EnableMouse) == "function" then
    pcall(tag.EnableMouse, tag, true)
  end
  setScript(tag, "OnEnter", function(self)
    textTooltip(self, Queue.WORDS.badgeTip, nil)
  end)
  setScript(tag, "OnLeave", hideTooltip)
  return tag
end

-- One queue row: the current row's wash, a 32 px icon, the name with the "R" badge beside it
-- (brief PR40 item D) and the reagents under it (brief PR22); at the right the X in the top
-- corner and the count line under it (brief PR40 item C, Queue.RowControls).
local function buildEntry(tray)
  local row = newFrame("Frame", tray)
  if not row then
    return nil
  end
  row:SetHeight(Queue.ROW_H)
  row.mark = wash(row, "BACKGROUND", Queue.CURRENT)
  if row.mark then
    row.mark:SetAllPoints(row)
    row.mark:Hide()
  end
  row.icon = newTexture(row, "ARTWORK")
  if row.icon then
    row.icon:SetSize(Queue.ICON, Queue.ICON)
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -3)
  end
  local controls = Queue.RowControls(true)
  row.remove = newFrame("Button", row)
  if row.remove then
    -- Brief PR39 item B: in the row card's top right corner, 1.5 times its old size.
    row.remove:SetSize(controls.remove.size, controls.remove.size)
    row.remove:SetPoint("TOPRIGHT", row, "TOPRIGHT", -controls.remove.right, -controls.remove.top)
    row.remove.icon = newTexture(row.remove, "ARTWORK")
    if row.remove.icon then
      row.remove.icon:SetAllPoints(row.remove)
      applyAsset(row.remove.icon, "BUTTON_CLOSE")
    end
    if type(row.remove.RegisterForClicks) == "function" then
      pcall(row.remove.RegisterForClicks, row.remove, "LeftButtonUp")
    end
    setScript(row.remove, "OnClick", function(self)
      local index = rawget(self, "index")
      if Queue.run and index and Queue.Remove(Queue.run, index) then
        refresh()
      end
    end)
    setScript(row.remove, "OnEnter", function(self)
      textTooltip(self, Queue.WORDS.remove, nil)
    end)
    setScript(row.remove, "OnLeave", hideTooltip)
  end
  row.tag = Queue.NewTag(row)
  local left = Queue.TextLeft()
  row.name = newText(row, Queue.FONT_TEXT, Queue.NAME_WORD, "LEFT")
  if row.name then
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", left, -3)
  end
  -- Brief PR39 item B, brief PR40 item C: "- x12 +" on the line under the X, right aligned with it
  -- (Queue.RowControls), small STEP px plates in the red the tray's buttons wear.
  row.plus = newButton(row, Queue.STEP, function()
    Queue.StepClick(rawget(row, "index"), 1)
  end, Queue.WORDS.plusHint)
  row.minus = newButton(row, Queue.STEP, function()
    Queue.StepClick(rawget(row, "index"), -1)
  end, Queue.WORDS.minusHint)
  local stepButtons = {
    { row.plus, Queue.WORDS.plus, Queue.WORDS.plusTip, controls.plus },
    { row.minus, Queue.WORDS.minus, Queue.WORDS.minusTip, controls.minus },
  }
  for _, pair in ipairs(stepButtons) do
    local button, at = pair[1], pair[4]
    if button then
      button:SetSize(at.size, at.size)
      button:ClearAllPoints()
      button:SetPoint("TOPRIGHT", row, "TOPRIGHT", -at.right, -at.top)
      -- A STEP px plate has no room for the label's 4 px insets: the sign sits at its centre.
      if button.label then
        button.label:ClearAllPoints()
        button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
      end
      setLabel(button, pair[2])
      button.tipTitle = pair[3]
      if type(button.SetMotionScriptsWhileDisabled) == "function" then
        pcall(button.SetMotionScriptsWhileDisabled, button, true)
      end
    end
  end
  row.count = newText(row, Queue.FONT_COUNT, Queue.MUTED_WORD, "CENTER", false, Queue.COUNT_FONTS)
  if row.count then
    row.count.fallbacks = Queue.COUNT_FONTS
    row.count:SetPoint("RIGHT", row, "TOPRIGHT", -controls.count.right, -controls.count.centre)
    if type(row.count.SetWidth) == "function" then
      pcall(row.count.SetWidth, row.count, controls.count.w)
    end
  end
  row.reagents = {}
  for index = 1, Queue.REAGENT_MAX do
    local slot = {}
    slot.icon = newTexture(row, "ARTWORK")
    if slot.icon then
      slot.icon:SetSize(Queue.REAGENT, Queue.REAGENT)
    end
    slot.count = newText(row, Queue.FONT_TEXT, Queue.NAME_WORD, "LEFT")
    if slot.count and type(slot.count.SetWidth) == "function" then
      pcall(slot.count.SetWidth, slot.count, Queue.REAGENT_COUNT_W)
    end
    slot.hit = buildIngredient(row)
    setShown(slot.hit, false)
    row.reagents[index] = slot
  end
  -- Brief PR38: the crafted item's tooltip from the icon and from the name; the count and the
  -- remove X at the right are left uncovered.
  row.iconHit = buildRecipeHit(row)
  if row.iconHit then
    row.iconHit:SetSize(Queue.ICON, Queue.ICON)
    row.iconHit:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -3)
  end
  row.nameHit = buildRecipeHit(row)
  if row.nameHit then
    row.nameHit:SetSize(Queue.TextRoom(), Queue.LINE_H)
    row.nameHit:SetPoint("TOPLEFT", row, "TOPLEFT", left, -3)
  end
  return row
end

local function itemIcon(texture, itemId)
  local a = assets()
  local icon = nil
  if itemId and a and type(a.ItemIcon) == "function" then
    local ok, answer = pcall(a.ItemIcon, itemId)
    icon = ok and answer or nil
  end
  if icon and type(texture.SetTexture) == "function" then
    pcall(texture.SetTexture, texture, icon)
    texture:Show()
  else
    setShown(texture, applyAsset(texture, "ICON_QUESTIONMARK"))
  end
end

-- Fills a row from its data and the bag counts of the shown rows' reagents; answers its height.
local function fillEntry(row, data, counts)
  setText(row.name, data.name)
  setText(row.count, data.count)
  textColour(row.name, data.finished and Queue.MUTED_WORD or Queue.NAME_WORD)
  setShown(row.mark, data.current == true)
  local left = Queue.TextLeft()
  local room = Queue.TextRoom()
  local reagents = type(data.reagents) == "table" and data.reagents or EMPTY
  -- Brief PR25: each reagent's words first ("5/5 (3 per craft)"), measured, so the slots flow and
  -- wrap by their real widths.
  local widths = {}
  for index, slot in ipairs(row.reagents or EMPTY) do
    local reagent = reagents[index]
    if reagent and slot.count then
      local have = type(counts) == "table" and number(counts[reagent.item]) or 0
      local text = Queue.ReagentText(have, reagent.need, reagent.per)
      if type(slot.count.SetWidth) == "function" then
        pcall(slot.count.SetWidth, slot.count, 0)
      end
      setText(slot.count, text)
      local measured = measure(slot.count, "GetStringWidth")
      widths[index] = Queue.ReagentWidth(measured, text)
      if type(slot.count.SetWidth) == "function" then
        local w = math.min(widths[index] - Queue.REAGENT - 3, room - Queue.REAGENT - 3)
        pcall(slot.count.SetWidth, slot.count, w)
      end
      textColour(slot.count, have >= reagent.need and Queue.NAME_WORD or Queue.SHORT_WORD)
    elseif reagent then
      widths[index] = Queue.REAGENT_W
    end
  end
  local layout = Queue.EntryLayout(widths, data.route, room)
  -- Brief PR40 item D: the "R" badge right after the name's words, on its line; the name gives up
  -- room so the badge always fits.
  local badged = data.route == true and row.tag ~= nil
  local nameW, badgeX = room, nil
  if badged then
    if row.name and type(row.name.SetWidth) == "function" then
      pcall(row.name.SetWidth, row.name, 0)
    end
    -- Brief PRX (PR45): the badge measured again, so the room reserved is its real width.
    local badgeW = Queue.FitTag(row.tag)
    nameW, badgeX = Queue.BadgePlace(measure(row.name, "GetStringWidth"), room, badgeW)
  end
  if row.name and type(row.name.SetWidth) == "function" then
    pcall(row.name.SetWidth, row.name, nameW)
  end
  row.nameW = nameW
  if row.tag then
    setShown(row.tag, badged)
    if badged then
      row.tag:ClearAllPoints()
      -- Brief PR41 item 2: centred on the name's line, the badge's middle on the name's own.
      if row.name then
        row.tag:SetPoint("LEFT", row.name, "LEFT", badgeX, 0)
      else
        row.tag:SetPoint("LEFT", row, "TOPLEFT", left + badgeX, -(3 + Queue.LINE_H / 2))
      end
      row.tag.x = badgeX
    end
  end
  if row.nameHit then
    -- The name's hover stops where the badge's own begins.
    row.nameHit:SetSize(nameW, Queue.LINE_H)
  end
  for index, slot in ipairs(row.reagents or EMPTY) do
    local reagent = reagents[index]
    local at = layout.reagents[index]
    if reagent and at then
      if slot.icon then
        slot.icon:ClearAllPoints()
        slot.icon:SetPoint("TOPLEFT", row, "TOPLEFT", left + at.x, -at.y)
        itemIcon(slot.icon, reagent.item)
      end
      if slot.count then
        slot.count:ClearAllPoints()
        slot.count:SetPoint("TOPLEFT", row, "TOPLEFT", left + at.x + Queue.REAGENT + 3, -(at.y + 1))
        slot.count:Show()
      end
      local hit = slot.hit
      if hit then
        hit.item = reagent.item
        hit.name = itemName(names(), reagent.item)
        hit.dragged = nil
        hit:ClearAllPoints()
        hit:SetPoint("TOPLEFT", row, "TOPLEFT", left + at.x, -at.y)
        hit:SetSize(math.max((widths[index] or Queue.REAGENT_W) - 6, Queue.REAGENT), Queue.REAGENT)
        hit:Show()
      end
    else
      setShown(slot.icon, false)
      setShown(slot.count, false)
      setShown(slot.hit, false)
    end
  end
  if row.remove then
    row.remove.index = data.index
    setShown(row.remove, data.removable)
  end
  -- Brief PR39 item B: the "+" and "-" on a row still to make (data.steps, Queue.RowSteps); a done,
  -- skipped or crafting row has none, and its count words take their room.
  row.index = data.index
  local steps = type(data.steps) == "table" and data.steps or EMPTY
  setShown(row.plus, steps.shown == true)
  setShown(row.minus, steps.shown == true)
  enable(row.plus, steps.plus == true)
  enable(row.minus, steps.minus == true)
  if row.count and type(row.count.SetWidth) == "function" then
    -- Brief PR40 item C: on the line under the X; with no "-" and "+" the words take the line,
    -- right aligned with the X.
    local at = Queue.RowControls(steps.shown == true).count
    pcall(row.count.SetWidth, row.count, at.w)
    if type(row.count.SetJustifyH) == "function" then
      pcall(row.count.SetJustifyH, row.count, at.justify)
    end
    row.count:ClearAllPoints()
    row.count:SetPoint("RIGHT", row, "TOPRIGHT", -at.right, -at.centre)
  end
  for _, hit in ipairs({ row.iconHit, row.nameHit }) do
    if hit then
      hit.item, hit.spell, hit.name = data.item, data.spell, data.name
      hit:Show()
    end
  end
  if row.icon then
    itemIcon(row.icon, data.item)
  end
  row:SetHeight(layout.h)
  row.h = layout.h
  return layout.h
end

-- The client's profession window that shows now (ProfessionsFrame, else the classic TradeSkillFrame;
-- Craft.WINDOWS), read only, or nil.
professionWindow = function()
  local craft = craftModule()
  local windows = craft and type(craft.WINDOWS) == "table" and craft.WINDOWS or nil
  for _, name in ipairs(windows or { "ProfessionsFrame", "TradeSkillFrame" }) do
    local window = rawget(_G, name)
    if type(window) == "table" and type(window.IsShown) == "function" then
      local ok, shown = pcall(window.IsShown, window)
      if ok and shown == true then
        return window
      end
    end
  end
  return nil
end

-- Brief PR39 item A: whether the client's combat lockdown is on, when no secure frame may be shown,
-- hidden, moved or given an attribute.
local function lockdown()
  return inCombat()
end

-- A frame's number from one of its getters, pcalled, or nil.
local function frameNumber(frame, method)
  if type(frame) ~= "table" or type(frame[method]) ~= "function" then
    return nil
  end
  local ok, value = pcall(frame[method], frame)
  return ok and tonumber(value) or nil
end

-- Whether a frame is on screen: shown and, where the client says, visible.
local function onScreen(frame)
  if type(frame) ~= "table" then
    return false
  end
  if type(frame.IsShown) == "function" then
    local ok, shown = pcall(frame.IsShown, frame)
    if ok and shown == false then
      return false
    end
  end
  if type(frame.IsVisible) == "function" then
    local ok, visible = pcall(frame.IsVisible, frame)
    if ok and visible == false then
      return false
    end
  end
  return true
end

-- Brief PR40 item B: the client's ActionButtonUseKeyDown, read as its own secure buttons read it
-- (GetCVarBool), under pcall; false (act on the up) where it cannot be read.
local function keyDownSetting()
  local fn = globalFn("GetCVarBool")
  if not fn then
    return false
  end
  local ok, answer = pcall(fn, Queue.KEY_DOWN_CVAR)
  return ok and answer == true
end
Queue.KeyDownSetting = keyDownSetting

-- Brief PR40 item B: the spell the client says the player is casting now (Craft.Casting, from the
-- player's UNIT_SPELLCAST events), or nil.
local function castingNow()
  local craft = craftModule()
  if craft and type(craft.Casting) == "function" then
    local ok, spell = pcall(craft.Casting)
    if ok then
      return spell
    end
  end
  return nil
end

-- An attribute of our own secure button, read back (GetAttribute), or nil.
local function attribute(button, key)
  if type(button) ~= "table" or type(button.GetAttribute) ~= "function" then
    return nil
  end
  local ok, value = pcall(button.GetAttribute, button, key)
  if ok then
    return value
  end
  return nil
end
Queue.Attribute = attribute

-- Brief PR40 item B: the main button's hover: with "/stopcasting" set, the click stops now and the
-- key after the craft under way; else the button's own hint.
local function primaryEnter(self)
  -- The plate's highlight belongs to the art child, which takes no mouse, so its HIGHLIGHT layer
  -- would never draw: while the pointer is on the button it draws on ARTWORK (Skin.PaintPlate puts
  -- it back on the next paint, and hides it at rest).
  local glow = rawget(self, "plated") and rawget(self, "highlight") or nil
  if type(glow) == "table" and type(glow.SetDrawLayer) == "function" then
    pcall(glow.SetDrawLayer, glow, "ARTWORK")
  end
  if rawget(self, "armed") then
    textTooltip(self, rawget(self, "labelText") or Queue.WORDS.pause, { Queue.WORDS.pauseNow, Queue.WORDS.pauseKey })
    return
  end
  local words = rawget(self, "hint")
  if words then
    textTooltip(self, rawget(self, "tipTitle") or rawget(self, "labelText") or "", { words })
  end
end

--- Brief PR40 item B: what one press of the main button does, after the client's secure action (if
--- any) has run in the same press: where "/stopcasting" was set when the press began
--- (button.pressArmed, noted in PreClick), the pause (Queue.StopClick); else Queue.Press (Start,
--- Craft next, Pause, Resume or Switch). Nothing where the tray is not up (a button left on screen
--- through combat lockdown) or the button reads as not pressable. Answers "stop", "press" or nil.
function Queue.PrimaryAct(button)
  local tray = Queue.tray
  if type(tray) ~= "table" or not rawget(tray, "shown") or type(button) ~= "table" then
    return nil
  end
  if rawget(button, "canPress") == false then
    return nil
  end
  if rawget(button, "pressArmed") then
    Queue.StopClick()
    return "stop"
  end
  Queue.Press()
  return "press"
end

-- The main button's PreClick, raw, before the client's own secure OnClick in the same half of the
-- press: notes whether "/stopcasting" is set for this half, and the developer's probe.
local function primaryPre(self, mouse, down)
  self.pressArmed = attribute(self, "type") == "macro"
  local probe = rawget(Queue, "ProbePre")
  if Queue.stopProbe and type(probe) == "function" then
    pcall(probe, self, mouse, down)
  end
end

-- The main button's PostClick, raw (no boundary: Queue.Press makes its craft, open or stop call
-- synchronously inside the player's press): our own handling on the one half the client's setting
-- makes the secure action use (Queue.ActsOn), so it runs once a press.
local function primaryPost(self, mouse, down)
  local acts = Queue.ActsOn(down, keyDownSetting())
  local what = nil
  if acts then
    what = Queue.PrimaryAct(self)
  end
  self.pressArmed = nil
  local probe = rawget(Queue, "ProbePost")
  if Queue.stopProbe and type(probe) == "function" then
    pcall(probe, self, mouse, down, acts, what)
  end
end
Queue.PrimaryPre, Queue.PrimaryPost = primaryPre, primaryPost

-- Brief PR40 item B: the main button's look, on a child of our secure button (a child takes no
-- part in its protection, so it may be shown, hidden and faded in combat): the Professions plate
-- (Skin.PlateButton) with the plate's textures mirrored onto the button so Skin.PaintPlate paints
-- them from the button's own scripts, else the flat face with a hairline edge. The child takes no
-- mouse: every press and hover is the button's. Answers the child and where the label goes.
local function primaryArt(button)
  local s = skin()
  local art = nil
  if s and type(s.PlateButton) == "function" then
    local ok, made = pcall(s.PlateButton, button, Queue.PRIMARY_W, Queue.BUTTON_H)
    art = ok and type(made) == "table" and made or nil
  end
  if art then
    button.plated = true
    button.plate = rawget(art, "plate")
    button.highlight = rawget(art, "highlight")
    button.glyphFrame = rawget(art, "glyphFrame")
  else
    art = newFrame("Frame", button)
    if not art then
      return nil, button
    end
    art.face = wash(art, "BACKGROUND", Queue.FACE)
    if art.face then
      art.face:SetAllPoints(art)
    end
    art.edges = edges(art, Queue.BORDER)
    art.hover = wash(art, "ARTWORK", Queue.HOVER)
    if art.hover then
      art.hover:SetAllPoints(art)
      art.hover:Hide()
    end
  end
  if type(art.ClearAllPoints) == "function" then
    pcall(art.ClearAllPoints, art)
  end
  if type(art.SetAllPoints) == "function" then
    pcall(art.SetAllPoints, art, button)
  end
  if type(art.EnableMouse) == "function" then
    pcall(art.EnableMouse, art, false)
  end
  setShown(art, true)
  return art, rawget(art, "labelParent") or art
end

-- Brief PR40 item B (the owner: "Craft does not stop midcast"; PR39's separate stop button over the
-- main button did not stop the cast in his test): the ONE main button is the client's own secure
-- action button template (Blizzard_FrameXML/SecureTemplates.xml SecureActionButtonTemplate, read on
-- the forever branch), made once with the tray and only out of combat lockdown, on UIParent (never a
-- child of the tray or anchored to any frame but UIParent, so no frame of ours or the client's
-- becomes protected through it) and laid over the tray's primarySlot (Queue.SyncStop). It has no
-- secure action until a craft is being cast (Queue.Armed): then type "macro" and macrotext
-- STOP_MACRO, which SecureActionButton_OnClick runs through C_Macro.RunMacroText inside the
-- player's own press. RegisterForClicks("AnyDown", "AnyUp") with no useOnKeyDown attribute, so the
-- action fires on whichever half the client's ActionButtonUseKeyDown setting says; our own PreClick
-- and PostClick are raw and run once a press (Queue.ActsOn). The template's own OnClick is never
-- replaced. Nil where the client makes no such button (the tray then has a plain main button whose
-- Pause stops after the craft under way, as before PR39).
local function buildPrimary()
  if lockdown() then
    return nil
  end
  local create = globalFn("CreateFrame")
  local parent = rawget(_G, "UIParent")
  if not create or type(parent) ~= "table" then
    return nil
  end
  local ok, button = pcall(create, "Button", nil, parent, "SecureActionButtonTemplate")
  if not ok or type(button) ~= "table" or type(button.SetAttribute) ~= "function" then
    return nil
  end
  if type(button.Hide) == "function" then
    pcall(button.Hide, button)
  end
  if not pcall(button.SetAttribute, button, "type", nil) then
    return nil
  end
  -- Brief PW1: the main button belongs with the profession window too (Queue.Companion).
  Queue.Companion(button)
  if type(button.SetSize) == "function" then
    pcall(button.SetSize, button, Queue.PRIMARY_W, Queue.BUTTON_H)
  end
  if type(button.RegisterForClicks) == "function" then
    pcall(button.RegisterForClicks, button, "AnyDown", "AnyUp")
  end
  local art, labelParent = primaryArt(button)
  button.art = art
  button.label = newText(labelParent, Queue.FONT_TITLE, Queue.PLATE_WORD, "CENTER")
  if button.label then
    button.label:SetPoint("LEFT", button, "LEFT", 4, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -4, 0)
  end
  local s = skin()
  if rawget(button, "plated") and s and type(s.PlateScripts) == "function" then
    s.PlateScripts(button, setScript, { OnEnter = primaryEnter, OnLeave = hideTooltip })
  else
    setScript(button, "OnEnter", function(self)
      setShown(rawget(rawget(self, "art") or EMPTY, "hover"), true)
      primaryEnter(self)
    end)
    setScript(button, "OnLeave", function(self)
      setShown(rawget(rawget(self, "art") or EMPTY, "hover"), false)
      hideTooltip()
    end)
  end
  setScript(button, "PreClick", primaryPre, true)
  setScript(button, "PostClick", primaryPost, true)
  button.secure = true
  button.up, button.armed = false, false
  return button
end
Queue.BuildPrimary = buildPrimary

-- Brief PR40 item B: puts the main button exactly over the tray's primarySlot, in UIParent's units
-- (Queue.CoverRect), at the tray's strata and STOP_LEVEL levels above the tray. Moved only when the
-- place changed. Answers whether it could (the slot is measured once the client has laid it out).
local function coverSlot(button, tray)
  local slot = rawget(tray, "primarySlot")
  local parent = rawget(_G, "UIParent")
  if type(slot) ~= "table" or type(parent) ~= "table" then
    return false
  end
  local rect = Queue.CoverRect(
    frameNumber(slot, "GetLeft"),
    frameNumber(slot, "GetBottom"),
    frameNumber(slot, "GetWidth"),
    frameNumber(slot, "GetHeight"),
    effectiveScale(slot),
    effectiveScale(parent)
  )
  if not rect or rect.w <= 0 or rect.h <= 0 then
    return false
  end
  local strata = nil
  if type(tray.GetFrameStrata) == "function" then
    local ok, answer = pcall(tray.GetFrameStrata, tray)
    strata = ok and type(answer) == "string" and answer or nil
  end
  local level = (frameNumber(tray, "GetFrameLevel") or 0) + Queue.STOP_LEVEL
  local key = table.concat({
    math.floor(rect.x + 0.5),
    math.floor(rect.y + 0.5),
    math.floor(rect.w + 0.5),
    math.floor(rect.h + 0.5),
    tostring(strata),
    level,
  }, ":")
  if rawget(button, "placed") == key then
    return true
  end
  pcall(button.ClearAllPoints, button)
  pcall(button.SetPoint, button, "BOTTOMLEFT", parent, "BOTTOMLEFT", rect.x, rect.y)
  pcall(button.SetSize, button, rect.w, rect.h)
  if strata and type(button.SetFrameStrata) == "function" then
    pcall(button.SetFrameStrata, button, strata)
  end
  if type(button.SetFrameLevel) == "function" then
    pcall(button.SetFrameLevel, button, level)
  end
  button.placed = key
  return true
end

--- Brief PR40 item B: the secure main button follows the tray: its look (the art child) shows while
--- the tray is up and the run is not finished (tray.primaryWanted), at once, in or out of combat;
--- out of combat lockdown only, the button itself is laid over the tray's slot and shown or hidden,
--- and its secure action set: type "macro" with STOP_MACRO while the queue's craft is being cast
--- and the stop is wanted (Queue.Armed), type cleared at every other time. In lockdown nothing of
--- the button itself is touched; PLAYER_REGEN_ENABLED syncs it again (a stray /stopcasting meanwhile
--- is harmless). Answers whether the secure action is "/stopcasting" now.
function Queue.SyncStop()
  local tray = Queue.tray
  local button = type(tray) == "table" and rawget(tray, "primary") or nil
  if type(button) ~= "table" or not rawget(button, "secure") then
    return false
  end
  local want = rawget(tray, "shown") == true and onScreen(tray) and rawget(tray, "primaryWanted") ~= false
  button.wanted = want
  setShown(rawget(button, "art"), want)
  if lockdown() then
    return rawget(button, "armed") == true
  end
  local armed = false
  if want then
    armed = Queue.Armed(Queue.run, clock(), castingNow())
  end
  if armed ~= (rawget(button, "armed") == true) then
    local set
    if armed then
      set = pcall(button.SetAttribute, button, "type", "macro")
        and pcall(button.SetAttribute, button, "macrotext", Queue.STOP_MACRO)
    else
      set = pcall(button.SetAttribute, button, "type", nil)
    end
    if set then
      button.armed = armed
    end
  end
  if want and coverSlot(button, tray) then
    if not rawget(button, "up") then
      pcall(button.Show, button)
      button.up = true
    end
  elseif rawget(button, "up") then
    pcall(button.Hide, button)
    button.up = false
  end
  return rawget(button, "armed") == true
end

Queue.TAB_KEYS = {
  "ProfessionsOverviewTab",
  "Professions1Tab",
  "Professions2Tab",
  "Professions3Tab",
  "Professions4Tab",
  "Professions5Tab",
  "Professions6Tab",
  "Professions7Tab",
}

-- Brief PR22: the right edges (screen pixels) of the side tabs that show on ProfessionsFrame, the
-- Forever client's Camelot layer (Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.xml:
-- ProfessionsOverviewTab and Professions1Tab to Professions7Tab, also the rightProfessionTabs array,
-- anchored off the window's TOPRIGHT). Read only: rawget for the keys, then IsShown and GetRight.
-- Answers nil where none of them is there to read (the fallback width then stands in).
local function tabRights(window)
  if window ~= rawget(_G, "ProfessionsFrame") then
    return {}
  end
  local tabs, seen = {}, {}
  local function add(tab)
    if type(tab) == "table" and not seen[tab] and type(tab.IsShown) == "function" then
      seen[tab] = true
      tabs[#tabs + 1] = tab
    end
  end
  for _, key in ipairs(Queue.TAB_KEYS) do
    add(rawget(window, key))
  end
  local list = rawget(window, "rightProfessionTabs")
  for _, tab in ipairs(type(list) == "table" and list or EMPTY) do
    add(tab)
  end
  if #tabs == 0 then
    return nil
  end
  local rights = {}
  for _, tab in ipairs(tabs) do
    local ok, shown = pcall(tab.IsShown, tab)
    if ok and shown == true then
      rights[#rights + 1] = screenEdge(tab, "GetRight")
    end
  end
  return rights
end

-- Brief PR21: docks the tray beside the profession window with SetPoint on the TRAY only (the
-- client's frame is only read), on its right where the screen has room, else on its left; centred
-- on UIParent where no window shows. A tray the player dragged stays put until the next Create all.
-- Brief PR22: on the right it sits beside the window's side tabs (Queue.DockRight), its top in line
-- with the window's top. Brief PR25: DOCK_GAP px past the tabs' visible art.
-- Brief PR40 item A (the owner's QA: an ADDON_ACTION_FORBIDDEN on SetPreferredGamepadInteractTarget
-- raised from the client's own profession window code after a craft): PR39 item E made the tray a
-- CHILD of the profession window, so the client's gamepad code walked that window's frame tree into
-- our tray and its execution was tainted. The tray is on UIParent at HIGH, always, as before PR39:
-- SetParent and SetFrameStrata are called on the tray only, our own frame, and never with a client
-- frame; nothing is called on the client's window (no Raise). The tray hides with the window
-- through TRADE_SKILL_CLOSE and its watch (Queue.HideWithWindow), never through parenting.
-- Answers whether it could.
local function holdTray(tray)
  local uiParent = rawget(_G, "UIParent")
  if type(tray) ~= "table" or type(uiParent) ~= "table" or type(tray.SetParent) ~= "function" then
    return false
  end
  local current = nil
  if type(tray.GetParent) == "function" then
    local ok, answer = pcall(tray.GetParent, tray)
    current = ok and answer or nil
  end
  if current ~= uiParent then
    pcall(tray.SetParent, tray, uiParent)
  end
  if type(tray.SetFrameStrata) == "function" then
    pcall(tray.SetFrameStrata, tray, "HIGH")
  end
  return true
end
Queue.HoldTray = holdTray

--- Brief PR39 item E2: tells the ItemTree window (UI/Frame.lua Frame.SetProfessionsUp, its own
--- public call) whether the tray is on screen. Brief PW1: told true, the window gives the client's
--- profession window (with this tray) the front over ItemTree's; Craft all and the queue's press
--- tell it too. Answers whether it was told.
function Queue.TellWindow(up)
  local ui = ItemTree.UI
  local window = type(ui) == "table" and ui.Frame or nil
  if type(window) == "table" and type(window.SetProfessionsUp) == "function" then
    return (pcall(window.SetProfessionsUp, up == true))
  end
  return false
end

--- Brief PW1 (QA item 238 d): one of our frames that belongs with the profession window (the tray,
--- its main button), so a click on it gives that window the front and a click on ItemTree's window
--- puts ItemTree over it (UI/Frame.lua Frame.AddProfessionsCompanion). Answers whether it was taken.
function Queue.Companion(frame)
  local ui = ItemTree.UI
  local window = type(ui) == "table" and ui.Frame or nil
  if type(frame) == "table" and type(window) == "table" and type(window.AddProfessionsCompanion) == "function" then
    local ok, taken = pcall(window.AddProfessionsCompanion, frame)
    return ok and taken == true
  end
  return false
end

local function placeTray(tray)
  local window = professionWindow()
  tray.dockedTo = window
  holdTray(tray)
  if rawget(tray, "moved") then
    return tray.dock
  end
  local parent = rawget(_G, "UIParent")
  tray:ClearAllPoints()
  if window then
    local scale = effectiveScale(parent)
    local windowRight = screenEdge(window, "GetRight")
    local windowScale = effectiveScale(window)
    local right =
      Queue.DockRight(windowRight, tabRights(window), Queue.TAB_W * windowScale, Queue.TAB_ART_MARGIN * windowScale)
    local side = Queue.DockSide(
      screenEdge(window, "GetLeft"),
      right,
      screenEdge(parent, "GetRight"),
      Queue.W * scale,
      Queue.GAP * scale
    )
    if side == "left" then
      tray:SetPoint("TOPRIGHT", window, "TOPLEFT", -Queue.GAP, 0)
    else
      -- The tabs' overhang, from screen pixels into the tray's own units.
      local extra = (right and windowRight) and (right - windowRight) / effectiveScale(tray) or 0
      tray:SetPoint("TOPLEFT", window, "TOPRIGHT", Queue.DOCK_GAP + extra, 0)
    end
    tray.dock = side
  else
    tray:SetPoint("CENTER", parent or tray:GetParent(), "CENTER", 0, 0)
    tray.dock = "centre"
  end
  return tray.dock
end

--- Docks the shown tray again (the profession window has just opened), now and once more a frame
--- later, after the client's own show handler has run. Answers the side, or nil.
function Queue.Dock()
  local tray = Queue.tray
  if not tray or not rawget(tray, "shown") then
    return nil
  end
  after(0, function()
    if Queue.tray and rawget(Queue.tray, "shown") then
      placeTray(Queue.tray)
      pcall(Queue.SyncStop)
    end
  end)
  return placeTray(tray)
end

--- Brief PR22: the queue closes with the profession window it docked beside (TRADE_SKILL_CLOSE, or
--- that window no longer shows). The run and its events are kept, so the tray comes back when the
--- window opens again on the run's line (Queue.Restore). Answers whether the tray went.
function Queue.HideWithWindow()
  local tray = Queue.tray
  if not tray or not rawget(tray, "shown") or rawget(tray, "dockedTo") == nil then
    return false
  end
  tray.shown = false
  tray.closedWithWindow = true
  tray:Hide()
  hideTooltip()
  pcall(Queue.SyncStop)
  return true
end

--- Brief PR22: shows again the tray that closed with the profession window, once the window shows
--- a queued line (brief PR35: any profession that has a group). Answers whether it came back.
function Queue.Restore()
  local tray = Queue.tray
  local run = Queue.run
  if not tray or not rawget(tray, "closedWithWindow") or rawget(tray, "shown") or not run or run.demo then
    return false
  end
  for _, group in ipairs(Queue.Groups(run)) do
    if windowOpen(group) then
      return Queue.Show()
    end
  end
  return false
end

-- Brief PR22: the shown tray's own OnUpdate, every WATCH_GAP seconds: the window it docked beside
-- no longer shows (read only, IsShown), so the tray closes with it.
local function watchWindow(self, elapsed)
  self.watchElapsed = (rawget(self, "watchElapsed") or 0) + (tonumber(elapsed) or 0)
  -- Brief PR25: no client event says the player walked up to a Cooking Fire (the Professions UI
  -- reads its own list again on each refresh), so while the box shows, its lines are read again
  -- every REQ_GAP seconds and the tray redrawn only when one changed.
  self.reqElapsed = (rawget(self, "reqElapsed") or 0) + (tonumber(elapsed) or 0)
  if self.reqElapsed >= Queue.REQ_GAP then
    self.reqElapsed = 0
    local run = Queue.run
    if rawget(self, "shown") and rawget(self, "reqShown") and run then
      if Queue.RequirementsSignatureOf(run) ~= rawget(self, "reqSig") then
        refresh()
      end
    end
  end
  if rawget(self, "dragging") then
    -- Brief PR40 item B: the main button keeps over its slot while the player drags the tray.
    pcall(Queue.SyncStop)
  end
  if self.watchElapsed < Queue.WATCH_GAP then
    return
  end
  self.watchElapsed = 0
  -- Brief PR40 item B: the main button's "/stopcasting" is set once the press's PAUSE_GRACE has
  -- passed and the cast is under way, and it follows its slot (Queue.SyncStop); only our own frames
  -- are shown or moved from here.
  pcall(Queue.SyncStop)
  local window = rawget(self, "dockedTo")
  if not rawget(self, "shown") or type(window) ~= "table" or type(window.IsShown) ~= "function" then
    return
  end
  local ok, shown = pcall(window.IsShown, window)
  if ok and shown == false then
    Queue.HideWithWindow()
  end
end
Queue.WatchWindow = watchWindow

--- The "Back to ItemTree" link: opens the ItemTree window again on the Professions tab, through the
--- window's own public Open and SelectTab. The tray stays. Answers whether the window took it.
function Queue.BackToItemTree()
  local ui = ItemTree.UI
  local window = type(ui) == "table" and ui.Frame or nil
  if type(window) ~= "table" or type(window.Open) ~= "function" then
    return false
  end
  local ok = pcall(window.Open)
  local stub = type(ui) == "table" and ui.Professions or nil
  local tab = type(stub) == "table" and stub.TAB_NAME or "Professions"
  if type(window.SelectTab) == "function" then
    pcall(window.SelectTab, tab)
  end
  return ok
end

local function buildLink(tray)
  local link = newFrame("Button", tray)
  if not link then
    return nil
  end
  link:SetSize(Queue.LINK_W, Queue.TITLE_H)
  link.text = newText(link, Queue.FONT_TEXT, Queue.LINK_WORD, "RIGHT")
  if link.text then
    link.text:SetPoint("RIGHT", link, "RIGHT", 0, 0)
    setText(link.text, Queue.WORDS.back)
    local w = measure(link.text, "GetStringWidth")
    if w then
      link:SetWidth(math.floor(w + 4.5))
    end
  end
  link.hover = wash(link, "HIGHLIGHT", Queue.HOVER)
  if link.hover then
    link.hover:SetAllPoints(link)
  end
  if type(link.RegisterForClicks) == "function" then
    pcall(link.RegisterForClicks, link, "LeftButtonUp")
  end
  setScript(link, "OnClick", function()
    Queue.BackToItemTree()
  end)
  setScript(link, "OnEnter", function(self)
    textColour(rawget(self, "text"), Queue.PLATE_WORD)
  end)
  setScript(link, "OnLeave", function(self)
    textColour(rawget(self, "text"), Queue.LINK_WORD)
  end)
  return link
end

-- Brief PR35 item 6: the scroll area's offset put on the ScrollFrame and the slim bar's thumb moved
-- to match, with no redraw (the wheel and the thumb's drag).
local function applyScroll(tray)
  local contentH, viewH = number(rawget(tray, "contentH")) or 0, number(rawget(tray, "viewH")) or 0
  Queue.offset = Queue.ClampScroll(Queue.offset, contentH, viewH)
  local scroll = rawget(tray, "scroll")
  if type(scroll) == "table" and type(scroll.SetVerticalScroll) == "function" then
    pcall(scroll.SetVerticalScroll, scroll, Queue.offset)
  end
  local bar = rawget(tray, "bar")
  local thumb = Queue.Thumb(contentH, viewH, Queue.offset, viewH)
  tray.thumb = thumb
  if type(bar) == "table" then
    setShown(bar, thumb ~= nil)
    if thumb and bar.thumb then
      bar.thumb:ClearAllPoints()
      bar.thumb:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -math.floor(thumb.top + 0.5))
      bar.thumb:SetSize(Queue.BAR_W, math.floor(thumb.tall + 0.5))
    end
  end
  return Queue.offset
end

--- Brief PR35 item 6: scrolls the groups by px (down where positive), held to the scroll range.
--- Answers the offset.
function Queue.Scroll(px)
  local tray = Queue.tray
  Queue.offset = (Queue.offset or 0) + (number(px) or 0)
  if not tray then
    return Queue.offset
  end
  return applyScroll(tray)
end

local function onWheel(_, delta)
  delta = tonumber(delta) or 0
  if delta ~= 0 then
    Queue.Scroll(delta > 0 and -Queue.WHEEL_STEP or Queue.WHEEL_STEP)
  end
end

-- The cursor's height in a frame's units, or nil.
local function cursorY(frame)
  local get = rawget(_G, "GetCursorPosition")
  if type(get) ~= "function" then
    return nil
  end
  local ok, _, y = pcall(get)
  y = ok and tonumber(y) or nil
  if not y then
    return nil
  end
  return y / effectiveScale(frame)
end

local function stopDrag(bar)
  Queue.drag = nil
  setScript(bar, "OnUpdate", nil)
end

-- Brief PR35 item 6: the thumb follows the cursor while the button is held (ZoneItems' shape).
local function onDragUpdate(bar)
  local drag = Queue.drag
  local tray = Queue.tray
  local y = cursorY(bar)
  if not drag or not tray or not y then
    return stopDrag(bar)
  end
  Queue.offset =
    Queue.DragOffset(drag.offset, drag.y - y, rawget(tray, "contentH"), rawget(tray, "viewH"), rawget(tray, "viewH"))
  applyScroll(tray)
end

-- Brief PR35 item 6: a press on the bar: on the thumb it starts a drag, above or below it the
-- groups move a window's height that way.
local function onBarDown(bar, button)
  local tray = Queue.tray
  if (button ~= nil and button ~= "LeftButton") or not tray then
    return
  end
  local thumb = rawget(tray, "thumb")
  local y = cursorY(bar)
  local top = type(bar.GetTop) == "function" and tonumber(bar:GetTop()) or nil
  if not (thumb and y and top) then
    return
  end
  local down = top - y
  local view = number(rawget(tray, "viewH")) or 0
  if down < thumb.top then
    Queue.Scroll(-view)
  elseif down > thumb.top + thumb.tall then
    Queue.Scroll(view)
  else
    Queue.drag = { y = y, offset = Queue.offset or 0 }
    setScript(bar, "OnUpdate", onDragUpdate)
  end
end

-- Brief PR35 item 6: the scroll area (a ScrollFrame of our own, no template) and its child, and the
-- slim bar of our own frames beside it: a dark track and a gold thumb.
local function buildScroll(tray)
  local scroll = newFrame("ScrollFrame", tray)
  local content = newFrame("Frame", scroll or tray)
  if scroll and content and type(scroll.SetScrollChild) == "function" then
    pcall(scroll.SetScrollChild, scroll, content)
  end
  if scroll then
    if type(scroll.EnableMouseWheel) == "function" then
      pcall(scroll.EnableMouseWheel, scroll, true)
    end
    setScript(scroll, "OnMouseWheel", onWheel)
  end
  tray.scroll, tray.content = scroll, content
  local bar = newFrame("Frame", tray)
  if bar then
    bar:SetWidth(Queue.BAR_W)
    bar.track = wash(bar, "BACKGROUND", Queue.TRACK)
    if bar.track then
      bar.track:SetAllPoints(bar)
    end
    bar.thumb = wash(bar, "ARTWORK", Queue.THUMB)
    if type(bar.EnableMouse) == "function" then
      pcall(bar.EnableMouse, bar, true)
    end
    if type(bar.EnableMouseWheel) == "function" then
      pcall(bar.EnableMouseWheel, bar, true)
    end
    setScript(bar, "OnMouseDown", onBarDown)
    setScript(bar, "OnMouseUp", stopDrag)
    setScript(bar, "OnHide", stopDrag)
    setScript(bar, "OnMouseWheel", onWheel)
    bar:Hide()
  end
  tray.bar = bar
end

local function buildTray()
  if Queue.tray then
    return Queue.tray
  end
  local parent = rawget(_G, "UIParent")
  local tray = newFrame("Frame", parent)
  if not tray then
    return nil
  end
  -- Brief PW1: the tray belongs with the profession window (Queue.Companion).
  Queue.Companion(tray)
  -- Brief PR38 (fault D): a size from the start, so a first draw that stops part way (its fault
  -- handed to the error handler) never leaves a tray with no size, which shows nothing at all.
  if type(tray.SetSize) == "function" then
    pcall(tray.SetSize, tray, Queue.W, Queue.INNER * 2 + Queue.TITLE_H + Queue.GAP + Queue.BUTTON_H)
  end
  if type(tray.SetFrameStrata) == "function" then
    pcall(tray.SetFrameStrata, tray, "HIGH")
  end
  -- Brief PR39 item E2, brief PW1: the tray showing gives the profession window the front over the
  -- ItemTree window (UI/Frame.lua Frame.SetProfessionsUp, which moves only ItemTree's window). (Brief
  -- PR40 item A: the tray no longer raises the client's window; nothing is called on it.)
  setScript(tray, "OnShow", function()
    Queue.TellWindow(true)
  end)
  setScript(tray, "OnHide", function()
    Queue.TellWindow(false)
  end)
  if type(tray.SetClampedToScreen) == "function" then
    pcall(tray.SetClampedToScreen, tray, true)
  end
  tray.fill = wash(tray, "BACKGROUND", Queue.PANEL_FILL, -7)
  if tray.fill then
    tray.fill:SetAllPoints(tray)
  end
  tray.edges = edges(tray, Queue.BORDER)
  if type(tray.EnableMouse) == "function" then
    pcall(tray.EnableMouse, tray, true)
  end
  -- Movable by its own frame; it keeps where the player put it until the next Create all.
  if type(tray.SetMovable) == "function" and type(tray.RegisterForDrag) == "function" then
    pcall(tray.SetMovable, tray, true)
    pcall(tray.RegisterForDrag, tray, "LeftButton")
    setScript(tray, "OnDragStart", function(self)
      pcall(self.StartMoving, self)
      -- Brief PR40 item B: the main button (on UIParent) follows the tray every frame while dragged.
      self.dragging = true
    end)
    setScript(tray, "OnDragStop", function(self)
      pcall(self.StopMovingOrSizing, self)
      self.moved = true
      self.dragging = nil
      pcall(Queue.SyncStop)
    end)
  end
  if type(tray.EnableMouseWheel) == "function" then
    pcall(tray.EnableMouseWheel, tray, true)
  end
  setScript(tray, "OnMouseWheel", onWheel)
  tray.title = newText(tray, Queue.FONT_TITLE, Queue.TITLE_WORD, "LEFT")
  if tray.title then
    tray.title:SetPoint("TOPLEFT", tray, "TOPLEFT", Queue.INNER, -(Queue.INNER + 3))
  end
  local close = newFrame("Button", tray)
  if close then
    close:SetSize(Queue.CLOSE, Queue.CLOSE)
    close:SetPoint("TOPRIGHT", tray, "TOPRIGHT", -Queue.INNER / 2, -Queue.INNER / 2)
    close.icon = newTexture(close, "ARTWORK")
    if close.icon then
      close.icon:SetAllPoints(close)
      applyAsset(close.icon, "BUTTON_CLOSE")
    end
    if type(close.RegisterForClicks) == "function" then
      pcall(close.RegisterForClicks, close, "LeftButtonUp")
    end
    -- Brief PR21: the close hides the tray only; it never reopens the ItemTree window.
    setScript(close, "OnClick", function()
      Queue.Hide()
    end)
    setScript(close, "OnEnter", function(self)
      textTooltip(self, Queue.WORDS.close, nil)
    end)
    setScript(close, "OnLeave", hideTooltip)
  end
  tray.close = close
  tray.back = buildLink(tray)
  if tray.back then
    tray.back:SetPoint("TOPRIGHT", tray, "TOPRIGHT", -(Queue.INNER / 2 + Queue.CLOSE + Queue.GAP), -Queue.INNER)
  end
  tray.progress = newText(tray, Queue.FONT_TEXT, Queue.NAME_WORD, "LEFT")
  tray.total = newText(tray, Queue.FONT_TEXT, Queue.STATUS_DONE, "LEFT")
  tray.status = newText(tray, Queue.FONT_TITLE, Queue.MUTED_WORD, "LEFT", true)
  -- Brief PR38: the one main button (Start craft queue, Craft next, Pause, Resume or Switch to
  -- Cooking), its click the hardware event path, raw: Queue.Press makes the one craft, open or stop
  -- call synchronously inside it. Brief PR40 item B: the secure button of our own on UIParent
  -- (buildPrimary), laid over primarySlot, the tray's own empty frame where the button belongs;
  -- where the client makes none (or the tray is first made in combat) a plain button in the slot's
  -- place, its raw OnClick Queue.Press.
  tray.primarySlot = newFrame("Frame", tray)
  if tray.primarySlot then
    tray.primarySlot:SetSize(Queue.PRIMARY_W, Queue.BUTTON_H)
  end
  local primary = buildPrimary()
  if not primary then
    primary = newButton(tray, Queue.PRIMARY_W, function()
      Queue.Press()
    end, nil, true)
  end
  tray.primary = primary
  tray.skip = newButton(tray, Queue.SMALL_W, function()
    if Queue.run and Queue.Skip(noteOpen(Queue.run)) then
      refresh()
    end
  end, Queue.WORDS.skipHint)
  tray.clear = newButton(tray, Queue.SMALL_W, function()
    Queue.ClearRun()
  end, Queue.WORDS.clearHint)
  setLabel(tray.skip, Queue.WORDS.skip)
  setLabel(tray.clear, Queue.WORDS.clear)
  buildScroll(tray)
  tray.entries, tray.dividers, tray.groupFrames = {}, {}, {}
  setScript(tray, "OnUpdate", watchWindow)
  tray:Hide()
  Queue.tray = tray
  return tray
end

local function pooled(list, index, build, parent)
  if not list[index] then
    list[index] = build(parent)
  end
  return list[index]
end

local function place(object, tray, y, w)
  if type(object) ~= "table" then
    return
  end
  object:ClearAllPoints()
  object:SetPoint("TOPLEFT", tray, "TOPLEFT", Queue.INNER, -y)
  if w and type(object.SetWidth) == "function" then
    object:SetWidth(w)
  end
end

-- Brief PR35: a frame at x, y down its parent (the scroll area's child, or a group block).
local function placeIn(object, parent, x, y, w)
  if type(object) ~= "table" then
    return
  end
  object:ClearAllPoints()
  object:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
  if w and type(object.SetWidth) == "function" then
    object:SetWidth(w)
  end
end

-- Brief PR25: one line of the Requirements box: a tick or a cross (Assets ICON_CHECK, ICON_REDX),
-- the words wrapping under it, and a wash that lights up once when the pre-check stops on it.
local function buildRequirement(box)
  local line = newFrame("Frame", box)
  if not line then
    return nil
  end
  line.glow = wash(line, "BACKGROUND", Queue.HOVER)
  if line.glow then
    line.glow:SetAllPoints(line)
    line.glow:Hide()
  end
  line.icon = newTexture(line, "ARTWORK")
  if line.icon then
    line.icon:SetSize(Queue.REQ_ICON, Queue.REQ_ICON)
    line.icon:SetPoint("TOPLEFT", line, "TOPLEFT", 0, -1)
  end
  line.text = newText(line, Queue.FONT_TEXT, Queue.NAME_WORD, "LEFT", true)
  if line.text then
    line.text:SetPoint("TOPLEFT", line, "TOPLEFT", Queue.REQ_ICON + 4, 0)
  end
  return line
end

-- Brief PR35 item 4 (the owner: "Make the requirements stand out a little more: small bevel corner
-- plus a different background colour, maybe darker"): the darker fill (REQ_FILL) under a small
-- chamfered card, its edge red or gold by state; flat hairlines where the card will not draw.
local function buildRequirementBox(parent)
  local box = newFrame("Frame", parent)
  if not box then
    return nil
  end
  box.fill = wash(box, "BACKGROUND", Queue.REQ_FILL, -7)
  if box.fill then
    box.fill:SetAllPoints(box)
  end
  box.edges = edges(box, Queue.REQ_MET)
  box.title = newText(box, Queue.FONT_TITLE, Queue.TITLE_WORD, "LEFT")
  if box.title then
    box.title:SetPoint("TOPLEFT", box, "TOPLEFT", Queue.REQ_PAD, -Queue.REQ_PAD)
    setText(box.title, Queue.WORDS.requirements)
  end
  box.lines = {}
  return box
end

-- Brief PR25: a signature of the box's lines (name, kind and met), so the tray's watch redraws only
-- when one changes.
local function requirementSignature(lines)
  local parts = {}
  for _, line in ipairs(lines or EMPTY) do
    parts[#parts + 1] = tostring(line.type) .. ":" .. tostring(line.name) .. ":" .. tostring(line.met)
  end
  return table.concat(parts, "|")
end
Queue.RequirementSignature = requirementSignature

-- Brief PR35: each group's requirement lines, in group order.
local function groupRequirements(run)
  local out = {}
  if type(run) ~= "table" then
    return out
  end
  local reqOf = requirementsOf(run)
  for index, group in ipairs(Queue.Groups(run)) do
    out[index] = Queue.Requirements(run, reqOf, group)
  end
  return out
end

local function allSignature(byGroup)
  local parts = {}
  for index, lines in ipairs(byGroup) do
    parts[index] = requirementSignature(lines)
  end
  return table.concat(parts, "#")
end

--- Brief PR35: the signature of every group's Requirements box, for the tray's watch.
function Queue.RequirementsSignatureOf(run)
  return allSignature(groupRequirements(run))
end

-- Brief PR35: a group's profession name: the demo's own, else Keep's skill name.
local function groupName(group)
  if type(group) ~= "table" then
    return nil
  end
  if type(group.name) == "string" and group.name ~= "" then
    return group.name
  end
  return runLineName(group)
end

-- Brief PR25: a group's Requirements box, sized to its lines, or hidden where its rows still to
-- make need nothing. Brief PR35: directly under the group's header and summary. Answers the y
-- under it.
local function drawRequirements(box, run, group, lines, rowNames, y, w, parent)
  if #lines == 0 or not box then
    setShown(box, false)
    return y
  end
  local inside = Queue.REQ_PAD + Queue.LINE_H + 2
  local blocked = type(run) == "table" and run.blocked or nil
  for index = 1, math.max(math.min(#lines, Queue.REQ_SHOWN), #box.lines) do
    local data = index <= Queue.REQ_SHOWN and lines[index] or nil
    local line = data and pooled(box.lines, index, buildRequirement, box) or box.lines[index]
    if line then
      if data then
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", box, "TOPLEFT", Queue.REQ_PAD, -inside)
        setText(line.text, Queue.RequirementText(data, rowNames, groupName(group)))
        textColour(line.text, data.met == false and Queue.SHORT_WORD or Queue.NAME_WORD)
        local key = nil
        if data.met == true then
          key = "ICON_CHECK"
        elseif data.met == false then
          key = "ICON_REDX"
        end
        local iconShown = key ~= nil and applyAsset(line.icon, key)
        setShown(line.icon, iconShown)
        -- Brief PR40 item E: with no tick or cross the words start at the box's padding, and take
        -- the icon's room too.
        local textX = Queue.RequirementTextX(iconShown)
        if line.text then
          line.text:ClearAllPoints()
          line.text:SetPoint("TOPLEFT", line, "TOPLEFT", textX, 0)
          if type(line.text.SetWidth) == "function" then
            pcall(line.text.SetWidth, line.text, w - Queue.REQ_PAD * 2 - textX)
          end
        end
        line.textX = textX
        local h = math.max(measure(line.text, "GetStringHeight") or Queue.LINE_H, Queue.LINE_H)
        line:SetSize(w - Queue.REQ_PAD * 2, h)
        line.data = data
        -- The pre-check stopped on this one: it lights up once.
        local lit = type(blocked) == "table"
          and blocked.pulse
          and blocked.name == data.name
          and (blocked.group == nil or blocked.group == group)
        setShown(line.glow, lit)
        if lit then
          blocked.pulse = false
          after(Queue.PULSE, function()
            setShown(line.glow, false)
          end)
        end
        line:Show()
        inside = inside + h + 2
      else
        line:Hide()
      end
    end
  end
  inside = inside + Queue.REQ_PAD - 2
  placeIn(box, parent, 0, y, w)
  box:SetHeight(inside)
  local border = Queue.RequirementBorder(lines)
  box.border = border
  local s = skin()
  local carded = s
      and type(s.Card) == "function"
      and s.Card(box, w, inside, {
        fill = Queue.REQ_FILL,
        edge = border,
        thickness = 1,
        chamfer = Queue.CARD_CHAMFER,
        art = false,
      })
    or false
  setShown(box.fill, not carded)
  for _, edge in ipairs(box.edges or EMPTY) do
    tint(edge, border)
    setShown(edge, not carded)
  end
  box:Show()
  box.y = y
  return y + inside + Queue.GAP
end

--- The names the tray draws with: the demo's own, else the data's.
function Queue.Names(run)
  if type(run) == "table" and type(run.names) == "table" then
    return run.names
  end
  return names()
end

-- Brief PR36: words written on the parchment: dark ink, never the client font's black shadow.
local function inkText(fontString, colourKey)
  if type(fontString) ~= "table" then
    return
  end
  textColour(fontString, colourKey)
  if type(fontString.SetShadowColor) == "function" then
    pcall(fontString.SetShadowColor, fontString, 0, 0, 0, 0)
  end
  if type(fontString.SetShadowOffset) == "function" then
    pcall(fontString.SetShadowOffset, fontString, 0, 0)
  end
end

-- Brief PR35 item 3 (the owner: "a thin strip with the profession title and icon"), brief PR36 (the
-- owner: "It looks too much like the top queued item. Make it a darker grey with a textured
-- background; it should seem more like grey metal or gunmetal. Make the header text a little
-- bigger, bevel the corners, and a little more padding top and bottom."): the group's header, a
-- HEADER_H gunmetal strip (Skin.ArtCard: the client's dark plate metal, tinted, on a chamfered card
-- with a steel edge; a flat gunmetal wash with hairline edges where the skin will not draw), the
-- skill line's glyph (Assets.skillGlyphs), "Cooking (16) - 1 to 50" (Queue.HeaderText) in the
-- client's next size up, a slim bar along its bottom edge while the group runs, and the group's own
-- Clear (the close X) at the right.
local function buildHeader(parent)
  local header = newFrame("Frame", parent)
  if not header then
    return nil
  end
  header:SetHeight(Queue.HEADER_H)
  header.fill = wash(header, "BACKGROUND", Queue.HEADER_FILL, -7)
  if header.fill then
    header.fill:SetAllPoints(header)
  end
  header.edges = edges(header, Queue.METAL_EDGE)
  header.icon = newTexture(header, "ARTWORK")
  if header.icon then
    header.icon:SetSize(Queue.HEADER_ICON, Queue.HEADER_ICON)
    header.icon:SetPoint("LEFT", header, "LEFT", Queue.HEADER_INSET, 0)
  end
  header.name = newText(header, Queue.FONT_HEADER, Queue.PLATE_WORD, "LEFT", false, Queue.HEADER_FONTS)
  if header.name then
    header.name.fallbacks = Queue.HEADER_FONTS
    header.name:SetPoint("LEFT", header, "LEFT", Queue.HEADER_INSET + Queue.HEADER_ICON + 6, 0)
  end
  header.track = wash(header, "BORDER", "ITEMTREE_COLOR_PROFESSION_BAR_EMPTY", 1)
  header.bar = wash(header, "BORDER", "ITEMTREE_COLOR_PROFESSION_BAR_DEFAULT", 2)
  local clear = newFrame("Button", header)
  if clear then
    clear:SetSize(Queue.GROUP_CLEAR, Queue.GROUP_CLEAR)
    -- Brief PR41 item 3: the row's X inset (REMOVE_INSET), not the words' HEADER_INSET.
    clear:SetPoint("RIGHT", header, "RIGHT", -Queue.REMOVE_INSET, 0)
    clear.icon = newTexture(clear, "ARTWORK")
    if clear.icon then
      clear.icon:SetAllPoints(clear)
      applyAsset(clear.icon, Queue.CLEAR_KEY)
    end
    if type(clear.RegisterForClicks) == "function" then
      pcall(clear.RegisterForClicks, clear, "LeftButtonUp")
    end
    setScript(clear, "OnClick", function(self)
      Queue.ClearGroupRun(rawget(self, "group"))
    end)
    setScript(clear, "OnEnter", function(self)
      textTooltip(self, string.format(Queue.WORDS.groupClear, rawget(self, "groupName") or ""), {
        Queue.WORDS.groupClearHint,
      })
    end)
    setScript(clear, "OnLeave", hideTooltip)
  end
  header.clear = clear
  return header
end

-- The flat bar colour of a skill line (UI/Bar.lua's fallback token for its fill art).
local function barToken(line)
  local a = assets()
  local kits = a and type(a.professionBarKits) == "table" and a.professionBarKits or EMPTY
  local kit = kits[number(line)]
  return "ITEMTREE_COLOR_PROFESSION_BAR_" .. (kit and kit:upper() or "DEFAULT")
end

-- Brief PR36: the strip's gunmetal (Skin.ArtCard), else its flat wash and hairline edges. Answers
-- "art", "flat" or "wash".
local function paintHeader(header, w)
  local s = skin()
  local look = false
  if s and type(s.ArtCard) == "function" then
    local ok, answer = pcall(s.ArtCard, header, w, Queue.HEADER_H, {
      fill = Queue.HEADER_FILL,
      edge = Queue.METAL_EDGE,
      thickness = 1,
      chamfer = Queue.HEADER_CHAMFER,
      art = Queue.METAL_KEY,
      tint = Queue.METAL_TINT,
      store = "metalPieces",
    })
    look = ok and answer or false
  end
  setShown(header.fill, not look)
  for _, edge in ipairs(header.edges or EMPTY) do
    setShown(edge, not look)
  end
  return look or "wash"
end

-- Brief PR36 item 4: the slim bar along the strip's bottom edge, inside its bevel, from the rank at
-- queue start to the band's end, in the profession's own bar colour, while the group runs. Brief
-- PR40 item C: not drawn while Queue.HEADER_BAR is false (the owner: "lets hide the progress bars
-- underneath the profession"); both its textures stay hidden.
local function drawHeaderBar(header, group, data, w)
  local running = Queue.HEADER_BAR == true and type(data) == "table" and data.kind == "running"
  local inset = Queue.HEADER_CHAMFER + 1
  local barW = math.max(w - 2 * inset, 0)
  local top = -(Queue.HEADER_H - 1 - Queue.HEADER_BAR_H)
  if running and header.track then
    header.track:ClearAllPoints()
    header.track:SetPoint("TOPLEFT", header, "TOPLEFT", inset, top)
    header.track:SetSize(barW, Queue.HEADER_BAR_H)
  end
  setShown(header.track, running)
  local fillW = running and math.floor(barW * (number(data.fraction) or 0)) or 0
  if header.bar then
    if fillW >= 1 then
      header.bar:ClearAllPoints()
      header.bar:SetPoint("TOPLEFT", header, "TOPLEFT", inset, top)
      header.bar:SetSize(fillW, Queue.HEADER_BAR_H)
      if not tint(header.bar, barToken(group.line)) then
        tint(header.bar, "ITEMTREE_COLOR_PROFESSION_BAR_DEFAULT")
      end
      header.bar:Show()
    else
      header.bar:Hide()
    end
  end
  header.barW = running and barW or nil
  header.fillW = running and fillW or nil
end

local function drawHeader(header, group, data, y, w, parent)
  if not header then
    return y
  end
  local name = groupName(group) or ""
  header.text = Queue.HeaderText(group, groupName(group))
  if header.name and type(header.name.SetWidth) == "function" then
    pcall(
      header.name.SetWidth,
      header.name,
      w - (Queue.HEADER_INSET + Queue.HEADER_ICON + 6) - (Queue.GROUP_CLEAR + 12)
    )
  end
  setText(header.name, header.text)
  local a = assets()
  local key = a and type(a.skillGlyphs) == "table" and a.skillGlyphs[number(group.line)] or nil
  setShown(header.icon, key ~= nil and applyAsset(header.icon, key))
  if header.clear then
    header.clear.group = group
    header.clear.groupName = name
  end
  placeIn(header, parent, 0, y, w)
  header:SetHeight(Queue.HEADER_H)
  header.look = paintHeader(header, w)
  drawHeaderBar(header, group, data, w)
  header:Show()
  header.y = y
  return y + Queue.HEADER_H + Queue.HEADER_PAD
end

-- Brief PR35 item 10: the group's level summary line. Brief PR36: shown only once the group has
-- finished short of its band's end ("+5 skill: Cooking 16 to 21 of 50 (out of materials)"); while
-- it runs the header says the rank and the bar under it the progress.
local function buildSummary(parent)
  local summary = newFrame("Frame", parent)
  if not summary then
    return nil
  end
  summary.text = newText(summary, Queue.FONT_TEXT, Queue.NAME_WORD, "LEFT", true)
  if summary.text then
    summary.text:SetPoint("TOPLEFT", summary, "TOPLEFT", 0, 0)
  end
  return summary
end

local SUMMARY_COLOUR = {
  running = Queue.NAME_WORD,
  level = Queue.STATUS_DONE,
  done = Queue.STATUS_DONE,
  out = Queue.STATUS_FAIL,
}

local function drawSummary(summary, data, y, w, parent)
  if not summary or type(data) ~= "table" or data.kind == "running" then
    setShown(summary, false)
    return y
  end
  if summary.text and type(summary.text.SetWidth) == "function" then
    pcall(summary.text.SetWidth, summary.text, w)
  end
  setText(summary.text, data.text)
  textColour(summary.text, SUMMARY_COLOUR[data.kind] or Queue.NAME_WORD)
  local h = math.max(measure(summary.text, "GetStringHeight") or Queue.LINE_H, Queue.LINE_H)
  placeIn(summary, parent, 0, y, w)
  summary:SetHeight(h)
  summary:Show()
  summary.data = data
  return y + h + Queue.SUMMARY_PAD
end

-- Brief PR36: a mask texture on frame in an Assets key's shape, put on texture; nil where the
-- client will not.
local function circleMask(frame, texture)
  if type(frame) ~= "table" or type(frame.CreateMaskTexture) ~= "function" then
    return nil
  end
  if type(texture) ~= "table" or type(texture.AddMaskTexture) ~= "function" then
    return nil
  end
  local ok, mask = pcall(frame.CreateMaskTexture, frame)
  if not ok or type(mask) ~= "table" or not applyAsset(mask, Queue.CARD_MASK_KEY) then
    return nil
  end
  if type(mask.SetAllPoints) == "function" then
    pcall(mask.SetAllPoints, mask, texture)
  end
  if not pcall(texture.AddMaskTexture, texture, mask) then
    return nil
  end
  return mask
end

-- Brief PR35 item 11: the celebration card at a group's band end: "You reached Leatherworking 45"
-- in large gold, "Queue stopped so you don't waste materials", and where the next band exists a
-- button. Brief PR36: the icon is the profession's own glyph cut round inside the talent tree's
-- gold ring with a gold tick on its lower right; the summary is kept but not shown
-- (Queue.CARD_SUMMARY); the button is "View 45 to 55" (Queue.ViewBandClick).
local function buildCard(parent)
  local card = newFrame("Frame", parent)
  if not card then
    return nil
  end
  card.fill = wash(card, "BACKGROUND", Queue.CARD_FILL, -7)
  if card.fill then
    card.fill:SetAllPoints(card)
  end
  card.edges = edges(card, Queue.CARD_EDGE)
  card.ring = newTexture(card, "ARTWORK", 2)
  if card.ring then
    card.ring:SetSize(Queue.CARD_ICON, Queue.CARD_ICON)
    card.ring:SetPoint("TOPLEFT", card, "TOPLEFT", Queue.CARD_PAD, -Queue.CARD_PAD)
  end
  card.icon = newTexture(card, "ARTWORK", 1)
  card.mask = circleMask(card, card.icon)
  card.tick = newTexture(card, "OVERLAY")
  if card.tick then
    card.tick:SetSize(Queue.CARD_TICK, Queue.CARD_TICK)
    if card.ring then
      card.tick:SetPoint("CENTER", card.ring, "BOTTOMRIGHT", -4, 4)
    end
  end
  card.title = newText(card, Queue.FONT_LARGE, Queue.CARD_WORD, "LEFT", true, Queue.LARGE_FONTS)
  if card.title then
    card.title.fallbacks = Queue.LARGE_FONTS
  end
  card.why = newText(card, Queue.FONT_SMALL, Queue.MUTED_WORD, "LEFT", true, Queue.SMALL_FONTS)
  if card.why then
    card.why.fallbacks = Queue.SMALL_FONTS
  end
  card.summary = newText(card, Queue.FONT_TEXT, Queue.STATUS_DONE, "LEFT", true)
  card.next = newButton(card, Queue.NEXT_W, function()
    Queue.ViewBandClick(rawget(card, "group"))
  end, Queue.WORDS.viewBandHint)
  return card
end

-- Brief PR36: the card's icon: "ring" (the glyph cut round in the gold ring, with the tick),
-- "glyph" (the square glyph with the tick, where the ring or its mask will not draw) or "check"
-- (the plain tick, where the line has no glyph).
local function drawCardIcon(card, group)
  local a = assets()
  local key = a and type(a.skillGlyphs) == "table" and a.skillGlyphs[number(group.line)] or nil
  local glyph = key ~= nil and card.icon ~= nil and applyAsset(card.icon, key)
  local ringed = glyph
    and rawget(card, "mask") ~= nil
    and card.ring ~= nil
    and applyAsset(card.ring, Queue.CARD_RING_KEY)
  local look = "check"
  if ringed then
    look = "ring"
  elseif glyph then
    look = "glyph"
  end
  if card.icon then
    card.icon:ClearAllPoints()
    if look == "ring" then
      card.icon:SetSize(Queue.CARD_GLYPH, Queue.CARD_GLYPH)
      card.icon:SetPoint("CENTER", card.ring, "CENTER", 0, 0)
    else
      card.icon:SetSize(Queue.CARD_ICON, Queue.CARD_ICON)
      card.icon:SetPoint("TOPLEFT", card, "TOPLEFT", Queue.CARD_PAD, -Queue.CARD_PAD)
    end
    if look == "check" then
      setShown(card.icon, applyAsset(card.icon, Queue.CARD_ICON_FALLBACK))
    else
      card.icon:Show()
    end
  end
  setShown(card.ring, look == "ring")
  setShown(card.tick, look ~= "check" and applyAsset(card.tick, Queue.CARD_ICON_FALLBACK))
  card.iconLook = look
  return look
end

local function cardText(fontString, card, x, y, w)
  if not fontString then
    return 0
  end
  fontString:ClearAllPoints()
  fontString:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
  if type(fontString.SetWidth) == "function" then
    pcall(fontString.SetWidth, fontString, w)
  end
  return math.max(measure(fontString, "GetStringHeight") or Queue.LINE_H, Queue.LINE_H)
end

local function drawCard(card, group, data, y, w, parent)
  if not card then
    return y
  end
  card.group = group
  local x = Queue.CARD_PAD + Queue.CARD_ICON + 8
  local textW = w - x - Queue.CARD_PAD
  drawCardIcon(card, group)
  local rank = number(group.rank) or number(group.hi) or 0
  setText(card.title, string.format(Queue.WORDS.reached, groupName(group) or lineWord(nil), rank))
  local inside = Queue.CARD_PAD
  inside = inside + cardText(card.title, card, x, inside, textW) + 2
  setText(card.why, Queue.WORDS.reachedWhy)
  inside = inside + cardText(card.why, card, x, inside, textW) + 2
  -- Brief PR36 (the owner: "Let's hide the levels gained for now, it's just a bit too much"): the
  -- summary's words are still written, but shown only where Queue.CARD_SUMMARY says so.
  local summaryText = type(data) == "table" and data.text or nil
  setText(card.summary, summaryText or "")
  local showSummary = Queue.CARD_SUMMARY == true and summaryText ~= nil
  setShown(card.summary, showSummary)
  if showSummary then
    inside = inside + cardText(card.summary, card, x, inside, textW)
  end
  inside = math.max(inside, Queue.CARD_PAD + Queue.CARD_ICON)
  local nextBand = Queue.NextBand(group)
  if card.next then
    if nextBand then
      setLabel(card.next, string.format(Queue.WORDS.viewBand, nextBand.lo, nextBand.hi))
      local labelW = measure(card.next.label, "GetStringWidth")
      if labelW and type(card.next.SetWidth) == "function" then
        card.next:SetWidth(math.max(math.floor(labelW + 24.5), Queue.SMALL_W))
      end
      card.next:ClearAllPoints()
      card.next:SetPoint("TOPLEFT", card, "TOPLEFT", x, -(inside + 4))
      card.next:Show()
      inside = inside + 4 + Queue.BUTTON_H
    else
      card.next:Hide()
    end
  end
  card.nextBand = nextBand
  inside = inside + Queue.CARD_PAD
  placeIn(card, parent, 0, y, w)
  card:SetHeight(inside)
  local s = skin()
  local carded = s
      and type(s.Card) == "function"
      and s.Card(card, w, inside, {
        fill = Queue.CARD_FILL,
        edge = Queue.CARD_EDGE,
        thickness = 1,
        chamfer = Queue.CARD_CHAMFER,
        art = false,
      })
    or false
  setShown(card.fill, not carded)
  for _, edge in ipairs(card.edges or EMPTY) do
    setShown(edge, not carded)
  end
  card:Show()
  card.y = y
  return y + inside + Queue.GAP
end

-- Brief PR35 item 8: the shopping line's hover: the item's tooltip (the pane's, with its "Click to
-- see where to get it"), then what it is for and "Sold by vendors".
local function shopTooltip(self)
  local itemId = number(rawget(self, "item"))
  if not itemId then
    return
  end
  local lines = rawget(self, "lines") or EMPTY
  local p = pane()
  local shown = false
  if p and type(p.MaterialTooltip) == "function" then
    local ok, answer = pcall(p.MaterialTooltip, self, "item:" .. itemId, rawget(self, "nameText"))
    shown = ok and answer ~= false
  end
  local tooltip = rawget(_G, "GameTooltip")
  if shown and type(tooltip) == "table" and type(tooltip.AddLine) == "function" then
    for _, line in ipairs(lines) do
      pcall(tooltip.AddLine, tooltip, line, 1, 1, 1, true)
    end
    if type(tooltip.Show) == "function" then
      pcall(tooltip.Show, tooltip)
    end
    return
  end
  local all = {}
  for _, line in ipairs(lines) do
    all[#all + 1] = line
  end
  all[#all + 1] = Queue.WORDS.warningHint
  textTooltip(self, rawget(self, "nameText") or "", all)
end

-- Brief PR36 item 5: the info mark's own tooltip (never the item's): the item's name, what it is
-- for, "Sold by vendors" and "Click to see where to buy it" (Queue.InfoLines).
local function infoTooltip(self)
  local row = rawget(self, "row")
  if type(row) ~= "table" or not number(rawget(row, "item")) then
    return
  end
  textTooltip(self, rawget(row, "nameText") or "", rawget(row, "infoLines") or EMPTY)
end

-- One shopping line: [item icon] Coarse Thread ........ x 3 [i], the whole line the hover and the
-- click (the item on its Sources view, PR30's ClickMaterial, so Show nearest is one click away).
-- Brief PR36: the words in dark ink on the parchment, an ink hover, and the info mark a button of
-- its own over the line, so its hover is its own tooltip; its click opens the item as the line's
-- does.
local function buildShopRow(parent)
  local row = newFrame("Button", parent)
  if not row then
    return nil
  end
  row:SetHeight(Queue.SHOP_ROW_H)
  row.hover = wash(row, "HIGHLIGHT", Queue.INK_HOVER)
  if row.hover then
    row.hover:SetAllPoints(row)
  end
  row.icon = newTexture(row, "ARTWORK")
  if row.icon then
    row.icon:SetSize(Queue.SHOP_ICON, Queue.SHOP_ICON)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
  end
  local info = newFrame("Button", row)
  if info then
    info:SetSize(Queue.SHOP_INFO + 4, Queue.SHOP_INFO + 4)
    info:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    info.row = row
    info.icon = newTexture(info, "ARTWORK")
    if info.icon then
      info.icon:SetSize(Queue.SHOP_INFO, Queue.SHOP_INFO)
      info.icon:SetPoint("CENTER", info, "CENTER", 0, 0)
      setShown(info.icon, applyAsset(info.icon, Queue.INFO_KEY))
    end
    if type(info.EnableMouse) == "function" then
      pcall(info.EnableMouse, info, true)
    end
    if type(info.RegisterForClicks) == "function" then
      pcall(info.RegisterForClicks, info, "LeftButtonUp")
    end
    setScript(info, "OnEnter", infoTooltip)
    setScript(info, "OnLeave", hideTooltip)
    setScript(info, "OnClick", function(self, button)
      openMaterial(rawget(rawget(self, "row") or EMPTY, "item"), button)
    end)
    info:Show()
  end
  row.info = info
  row.count = newText(row, Queue.FONT_TEXT, Queue.INK, "RIGHT")
  inkText(row.count, Queue.INK)
  if row.count then
    row.count:SetPoint("RIGHT", row, "RIGHT", -(2 + Queue.SHOP_INFO + 6), 0)
  end
  row.name = newText(row, Queue.FONT_TEXT, Queue.INK, "LEFT")
  inkText(row.name, Queue.INK)
  if row.name then
    row.name:SetPoint("LEFT", row, "LEFT", 2 + Queue.SHOP_ICON + 5, 0)
  end
  if type(row.RegisterForClicks) == "function" then
    pcall(row.RegisterForClicks, row, "LeftButtonUp")
  end
  setScript(row, "OnClick", function(self, button)
    openMaterial(rawget(self, "item"), button)
  end)
  setScript(row, "OnEnter", shopTooltip)
  setScript(row, "OnLeave", hideTooltip)
  return row
end

-- Brief PR35 item 8, brief PR36 items 1 and 2: the vendor shopping list in a card of its own, a
-- parchment (Skin.NineSlice of Assets PROFESSION_PARCHMENT, its own torn edges; a warm flat card
-- with a brown edge, or a wash, where that will not draw), SHOP_INNER px inside and SHOP_MARGIN px
-- from the tray's fill; its title larger (GameFontNormalLarge) with its icon, and every word in ink.
local function buildShop(parent)
  local shop = newFrame("Frame", parent)
  if not shop then
    return nil
  end
  shop.fill = wash(shop, "BACKGROUND", Queue.PARCHMENT_FILL, -7)
  if shop.fill then
    shop.fill:SetAllPoints(shop)
  end
  shop.edges = edges(shop, Queue.PARCHMENT_EDGE)
  local top = Queue.SHOP_INNER + Queue.SHOP_PAD_Y
  shop.icon = newTexture(shop, "ARTWORK")
  if shop.icon then
    shop.icon:SetSize(Queue.SHOP_TITLE_ICON, Queue.SHOP_TITLE_ICON)
    shop.icon:SetPoint("TOPLEFT", shop, "TOPLEFT", Queue.SHOP_INNER, -(top + 1))
    setShown(shop.icon, applyAsset(shop.icon, Queue.SHOP_ICON_KEY))
  end
  shop.title = newText(shop, Queue.FONT_LARGE, Queue.INK, "LEFT", false, Queue.LARGE_FONTS)
  if shop.title then
    shop.title.fallbacks = Queue.LARGE_FONTS
    inkText(shop.title, Queue.INK)
    shop.title:SetPoint("LEFT", shop, "TOPLEFT", Queue.SHOP_INNER + Queue.SHOP_TITLE_ICON + 6, -(top + 11))
    setText(shop.title, Queue.WORDS.shopTitle)
  end
  shop.hint = newText(shop, Queue.FONT_TEXT, Queue.INK_MUTED, "LEFT", true)
  inkText(shop.hint, Queue.INK_MUTED)
  shop.rows, shop.dividers = {}, {}
  return shop
end

local function newDivider(parent, colourKey)
  local line = wash(parent, "ARTWORK", colourKey or Queue.DIVIDER)
  if line then
    line:SetHeight(1)
  end
  return line
end

-- Places a divider DIVIDER_PAD px under y (x px in) and answers the y past it.
local function drawDivider(divider, parent, y, w, x)
  local at = y + Queue.DIVIDER_PAD
  if divider then
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, -at)
    divider:SetSize(w, 1)
    divider:Show()
    divider.y = at
  end
  return at + 1 + Queue.DIVIDER_PAD
end

-- Brief PR36: the shopping card's parchment, else its flat card, else its wash. Answers
-- "parchment", "card" or "wash".
local function paintShop(shop, w, h)
  local s = skin()
  local look = "wash"
  if s and type(s.NineSlice) == "function" then
    local ok, drawn =
      pcall(s.NineSlice, shop, Queue.PARCHMENT_KEY, w, h, { size = Queue.SHOP_EDGE, store = "parchment" })
    if ok and drawn then
      look = "parchment"
    end
  end
  if look == "wash" and s and type(s.Card) == "function" then
    local ok, drawn = pcall(s.Card, shop, w, h, {
      fill = Queue.PARCHMENT_FILL,
      edge = Queue.PARCHMENT_EDGE,
      thickness = 1,
      chamfer = Queue.CARD_CHAMFER,
      art = false,
      store = "shopCard",
    })
    if ok and drawn then
      look = "card"
    end
  end
  if look ~= "card" and s and type(s.HideCard) == "function" then
    pcall(s.HideCard, shop, "shopCard")
  end
  setShown(shop.fill, look == "wash")
  for _, edge in ipairs(shop.edges or EMPTY) do
    setShown(edge, look == "wash")
  end
  return look
end

local function drawShop(shop, group, rowNames, y, w, parent)
  local list = Queue.ShoppingList(type(group) == "table" and group.warnings or nil)
  if not shop or #list == 0 then
    setShown(shop, false)
    return y
  end
  local cardW = w - 2 * Queue.SHOP_MARGIN
  local innerW = cardW - 2 * Queue.SHOP_INNER
  local inside = Queue.SHOP_INNER + Queue.SHOP_PAD_Y + Queue.SHOP_TITLE_H + 2
  if shop.hint then
    shop.hint:ClearAllPoints()
    shop.hint:SetPoint("TOPLEFT", shop, "TOPLEFT", Queue.SHOP_INNER, -inside)
    if type(shop.hint.SetWidth) == "function" then
      pcall(shop.hint.SetWidth, shop.hint, innerW)
    end
    setText(shop.hint, Queue.WORDS.shopHint)
    inside = inside + math.max(measure(shop.hint, "GetStringHeight") or Queue.LINE_H, Queue.LINE_H) + 4
  end
  local nameW = innerW - (2 + Queue.SHOP_ICON + 5) - (2 + Queue.SHOP_INFO + 6) - 56
  for index = 1, math.max(#list, #shop.rows) do
    local line = list[index]
    local row = line and pooled(shop.rows, index, buildShopRow, shop) or shop.rows[index]
    local divider = shop.dividers[index - 1]
    if line and index > 1 then
      shop.dividers[index - 1] = divider or newDivider(shop, Queue.INK_DIVIDER)
      inside = drawDivider(shop.dividers[index - 1], shop, inside, innerW, Queue.SHOP_INNER)
    elseif divider and index > 1 then
      divider:Hide()
    end
    if row then
      if line then
        placeIn(row, shop, Queue.SHOP_INNER, inside, innerW)
        row.item = line.item
        row.nameText = itemName(rowNames, line.item)
        row.lines = Queue.ShoppingLines(line, rowNames)
        row.infoLines = Queue.InfoLines(line, rowNames)
        row.amount = line.count
        if row.name and type(row.name.SetWidth) == "function" then
          pcall(row.name.SetWidth, row.name, nameW)
        end
        setText(row.name, row.nameText)
        setText(row.count, string.format(Queue.WORDS.toMake, line.count))
        if row.icon then
          itemIcon(row.icon, line.item)
        end
        row:Show()
        inside = inside + Queue.SHOP_ROW_H
      else
        row:Hide()
      end
    end
  end
  inside = inside + Queue.SHOP_INNER + Queue.SHOP_PAD_Y
  local top = y + Queue.SHOP_MARGIN
  placeIn(shop, parent, Queue.SHOP_MARGIN, top, cardW)
  shop:SetHeight(inside)
  shop.look = paintShop(shop, cardW, inside)
  shop:Show()
  shop.y = top
  shop.listed = #list
  return top + inside + Queue.SHOP_MARGIN + Queue.GAP
end

-- Brief PR35: one group's frames (header, summary, card, Requirements box, shopping list), built
-- once a slot and reused.
local function groupFrames(tray, index, parent)
  local frames = tray.groupFrames[index]
  if not frames then
    frames = {
      header = buildHeader(parent),
      summary = buildSummary(parent),
      card = buildCard(parent),
      reqBox = buildRequirementBox(parent),
      shop = buildShop(parent),
    }
    tray.groupFrames[index] = frames
  end
  return frames
end

local function hideGroup(frames)
  frames.group, frames.y = nil, nil
  for _, key in ipairs({ "header", "summary", "card", "reqBox", "shop" }) do
    setShown(frames[key], false)
  end
end

-- The screen's height in the tray's units (UIParent's), or nil.
local function screenHeight()
  local parent = rawget(_G, "UIParent")
  if type(parent) == "table" and type(parent.GetHeight) == "function" then
    local ok, h = pcall(parent.GetHeight, parent)
    return ok and tonumber(h) or nil
  end
  return nil
end

-- Brief PR35 item 6: the groups and their rows inside the scroll area's child, from y 0 down.
-- Answers the content's height and the rows drawn.
local function drawGroups(tray, run, rowNames, rows, reqByGroup, w)
  local content = tray.content
  local craft = craftModule()
  local nodes = {}
  for _, data in ipairs(rows) do
    if type(data.node) == "table" and #(data.reagents or EMPTY) > 0 then
      nodes[#nodes + 1] = data.node
    end
  end
  local counts = {}
  if type(run) == "table" and run.demo then
    -- Brief PR25: the demo's made up bag counts; it asks the bags nothing.
    counts = type(run.counts) == "table" and run.counts or {}
  elseif #nodes > 0 and craft and type(craft.Counts) == "function" then
    local ok, answer = pcall(craft.Counts, nodes)
    counts = ok and type(answer) == "table" and answer or {}
  end
  -- Brief PR39 item B: whether each row's "+" and "-" can move it, from the same bag counts.
  for _, data in ipairs(rows) do
    local entry = data.entry
    if type(entry) == "table" and entry.state == "queued" and entry.pending ~= true then
      local ok, most = pcall(rowMost, run, entry, counts)
      data.steps = Queue.RowSteps(entry, ok and most or nil)
    else
      data.steps = Queue.RowSteps(nil)
    end
  end
  local groups = type(run) == "table" and Queue.Groups(run) or {}
  local y, slot, lines = 0, 0, 0
  local current = type(run) == "table" and Queue.Current(run) or nil
  tray.currentRow = nil
  for index, group in ipairs(groups) do
    local frames = groupFrames(tray, index, content)
    frames.group = group
    frames.y = y
    local finished = Queue.GroupFinished(run, group)
    local real = type(run.groups) == "table"
    -- Brief PR36: the header carries the rank and, while the group runs, its bar; the summary
    -- line shows only once the group finished short of its end.
    local summary = real and Queue.Summary(group, groupName(group), finished) or nil
    if real then
      y = drawHeader(frames.header, group, summary, y, w, content)
    else
      setShown(frames.header, false)
    end
    if real and group.levelDone then
      setShown(frames.summary, false)
      y = drawCard(frames.card, group, summary, y, w, content)
    else
      setShown(frames.card, false)
      y = drawSummary(frames.summary, summary, y, w, content)
    end
    y = drawRequirements(frames.reqBox, run, group, reqByGroup[index] or EMPTY, rowNames, y, w, content)
    y = drawShop(frames.shop, group, rowNames, y, w, content)
    local count = 0
    for _, data in ipairs(rows) do
      if data.group == group then
        count = count + 1
        if count > 1 then
          lines = lines + 1
          tray.dividers[lines] = tray.dividers[lines] or newDivider(content)
          y = drawDivider(tray.dividers[lines], content, y, w)
        end
        slot = slot + 1
        local frame = pooled(tray.entries, slot, buildEntry, content)
        if frame then
          placeIn(frame, content, 0, y, w)
          frame.y = y
          local h = fillEntry(frame, data, counts)
          frame:Show()
          if data.current then
            tray.currentRow = { y = y, h = tonumber(h) or Queue.ROW_H, entry = current }
          end
          y = y + (tonumber(h) or Queue.ROW_H)
        end
      end
    end
    frames.rows = count
    y = y + Queue.GROUP_GAP
  end
  for index = #groups + 1, #tray.groupFrames do
    hideGroup(tray.groupFrames[index])
  end
  for index = slot + 1, #tray.entries do
    setShown(tray.entries[index], false)
  end
  for index = lines + 1, #tray.dividers do
    setShown(tray.dividers[index], false)
  end
  tray.dividersShown = lines
  return math.max(y - Queue.GROUP_GAP, 0), slot
end

--- Draws the tray from the run (brief PR21, top to bottom): the title row, the controls, the
--- progress, total and status lines, then (brief PR35) the groups in their scroll area, each with
--- its header, summary or card, Requirements box, shopping list and rows. Answers the rows drawn.
function Queue.Draw()
  local tray = Queue.tray
  if not tray or not rawget(tray, "shown") then
    return 0
  end
  local run = Queue.run
  noteOpen(run)
  local mode = Queue.Mode()
  local rowNames = Queue.Names(run)
  local rows = Queue.Rows(run, rowNames)
  local inner = Queue.W - Queue.INNER * 2
  setText(tray.title, Queue.TitleText(run))
  local y = Queue.INNER + Queue.TITLE_H + Queue.GAP
  -- The controls, above the list. Brief PR38: one main button, its label what a press does now
  -- (Queue.Action), Pause while a craft or batch is under way.
  local switchTo = switchTarget(run)
  local action, label, can = Queue.Action(run, mode, switchTo)
  setLabel(tray.primary, label)
  if tray.primary then
    tray.primary.action = action
    if action == "pause" then
      -- Brief PR25: the hover says what Pause can do on this client. Brief PR40 item B: while the
      -- main button's /stopcasting is set, its hover says the click stops now.
      local craft = craftModule()
      local canStop = craft and type(craft.CanStopRepeat) == "function" and craft.CanStopRepeat() == true
      tray.primary.hint = canStop and Queue.WORDS.pauseHint or Queue.WORDS.pauseNoStop
    elseif action == "switch" then
      tray.primary.hint = Queue.WORDS.switchTip
    elseif action == "pretend" then
      tray.primary.hint = Queue.WORDS.pretendTip
    else
      tray.primary.hint = mode == "auto" and Queue.WORDS.autoMode or Queue.WORDS.pressMode
    end
  end
  local demo = type(run) == "table" and run.demo == true
  enable(tray.primary, can and (demo or action == "pause" or not inCombat()))
  local live = run and Queue.Current(run) ~= nil
  enable(tray.skip, live)
  -- Brief PR22: a finished run keeps only Clear (and the close); the main button and Skip go.
  local finished = Queue.Finished(run)
  -- Brief PR40 item B: the secure main button is shown and hidden by Queue.SyncStop (refresh calls
  -- it after this draw), only out of combat lockdown; a plain one here.
  tray.primaryWanted = not finished
  if not rawget(tray.primary or EMPTY, "secure") then
    setShown(tray.primary, not finished)
  end
  setShown(tray.skip, not finished)
  local removed = run and type(run.removed) == "table" and #run.removed or 0
  enable(tray.clear, run ~= nil and (#(run.entries or EMPTY) > 0 or removed > 0 or finished))
  local x = Queue.INNER
  for _, button in ipairs({ tray.primary, tray.skip, tray.clear }) do
    if button and (button == tray.clear or not finished) then
      -- Brief PR40 item B: the secure main button is never anchored to the tray; its slot is.
      local target = button
      if button == tray.primary and rawget(button, "secure") then
        target = rawget(tray, "primarySlot")
      end
      if target then
        target:ClearAllPoints()
        target:SetPoint("TOPLEFT", tray, "TOPLEFT", x, -y)
        button.y = y
        x = x + (tonumber(target.GetWidth and target:GetWidth()) or Queue.SMALL_W) + Queue.GAP
      end
    end
  end
  tray.controlsY = y
  y = y + Queue.BUTTON_H + Queue.GAP
  -- Brief PR25: the requirements of the rows still to make, a box a group (brief PR35); a
  -- pre-check line whose need is met now goes.
  local reqByGroup = groupRequirements(run)
  local blocked = type(run) == "table" and run.blocked or nil
  if type(blocked) == "table" then
    for _, lines in ipairs(reqByGroup) do
      for _, line in ipairs(lines) do
        if line.name == blocked.name and line.met == true then
          if run.reason ~= nil and run.reason == blocked.reason then
            run.reason = nil
          end
          run.blocked = nil
        end
      end
    end
  end
  local any = false
  for _, lines in ipairs(reqByGroup) do
    any = any or #lines > 0
  end
  tray.reqSig = allSignature(reqByGroup)
  tray.reqShown = any
  -- The progress, the whole queue's total (brief PR35 item 10) and the status lines.
  place(tray.progress, tray, y, inner)
  setText(tray.progress, Queue.Progress(run))
  textColour(tray.progress, finished and Queue.STATUS_DONE or Queue.NAME_WORD)
  y = y + Queue.LINE_H
  local total = type(run) == "table" and Queue.TotalText(run) or nil
  if tray.total then
    if total then
      place(tray.total, tray, y, inner)
      setText(tray.total, total)
      tray.total:Show()
      y = y + Queue.LINE_H
    else
      tray.total:Hide()
    end
  end
  place(tray.status, tray, y, inner)
  if type(run) == "table" then
    run.emptyWhy = emptyWhy(run)
  end
  setText(tray.status, Queue.Status(run, mode, rowNames, switchTo))
  -- Brief PR35 item 9: red for a failure or block, green for done, muted for a prompt.
  tray.statusColour = Queue.StatusColour(run, switchTo)
  textColour(tray.status, tray.statusColour)
  y = y + math.max(measure(tray.status, "GetStringHeight") or Queue.LINE_H, Queue.LINE_H) + Queue.GAP
  -- Brief PR35 item 6: the groups scroll inside a fixed most height.
  local listW = Queue.ListW()
  local contentH, drawn = 0, 0
  if tray.content then
    contentH, drawn = drawGroups(tray, run, rowNames, rows, reqByGroup, listW)
    if type(tray.content.SetSize) == "function" then
      tray.content:SetSize(listW, math.max(contentH, 1))
    end
  end
  local viewH = Queue.ViewHeight(y, contentH, screenHeight())
  tray.contentH, tray.viewH, tray.listY = contentH, viewH, y
  -- A group just added comes into view; else the current row, when it changes.
  local target = Queue.scrollTo
  Queue.scrollTo = nil
  if target ~= nil then
    for _, frames in ipairs(tray.groupFrames) do
      if frames.group == target and number(frames.y) then
        Queue.offset = frames.y
      end
    end
  else
    local row = rawget(tray, "currentRow")
    if row and row.entry ~= rawget(tray, "lastCurrent") then
      local offset = Queue.offset or 0
      if row.y < offset then
        Queue.offset = row.y
      elseif row.y + row.h > offset + viewH then
        Queue.offset = row.y + row.h - viewH
      end
    end
  end
  tray.lastCurrent = (rawget(tray, "currentRow") or EMPTY).entry
  if tray.scroll then
    place(tray.scroll, tray, y, nil)
    tray.scroll:SetSize(listW, math.max(viewH, 1))
    setShown(tray.scroll, viewH > 0)
  elseif tray.content then
    place(tray.content, tray, y, nil)
  end
  if tray.bar then
    tray.bar:ClearAllPoints()
    tray.bar:SetPoint("TOPLEFT", tray, "TOPLEFT", Queue.INNER + listW + Queue.BAR_GAP, -y)
    tray.bar:SetSize(Queue.BAR_W, math.max(viewH, 1))
  end
  applyScroll(tray)
  y = y + viewH + Queue.INNER
  tray:SetSize(Queue.W, y)
  local s = skin()
  local carded = s
      and type(s.Card) == "function"
      and s.Card(tray, Queue.W, y, { fill = Queue.PANEL_FILL, edge = Queue.BORDER, thickness = 1 })
    or false
  setShown(tray.fill, not carded)
  for _, edge in ipairs(tray.edges or EMPTY) do
    setShown(edge, not carded)
  end
  return drawn
end

refresh = function()
  if Queue.tray and rawget(Queue.tray, "shown") then
    Queue.Draw()
  end
  -- Brief PR40 item B: the main button follows every change of state, the tray shown or not.
  pcall(Queue.SyncStop)
end
Queue.Refresh = refresh

-- Brief PM1 (brief G1 reaching the Professions code): the tray's draw runs under
-- ItemTree.Guard.Run, so a fault in it (a recipe or item the data does not hold) is handed to the
-- client's error handler once and the tray and the queue run on; it was a silent pcall. The tray
-- is not in the ItemTree window, so no empty page. The draw only paints: the craft call itself is
-- never inside it.
do
  local body = Queue.Draw
  Queue.unguardedDraw = body
  Queue.Draw = function(...)
    local Guard = ItemTree.Guard
    if type(Guard) == "table" and type(Guard.Run) == "function" then
      local ok, drawn = Guard.Run("Professions.Queue.Draw", body, ...)
      if ok then
        return drawn
      end
      return false
    end
    return body(...)
  end
end

--- Shows the tray, docked beside the profession window (brief PR21), drawn from the run.
function Queue.Show()
  local tray = buildTray()
  if not tray then
    return false
  end
  -- Brief PB1 addendum: a stop for full bags is looked at again as the tray comes up, so it never
  -- says the bags are full after they were emptied with the tray shut.
  Queue.CheckRoom()
  tray.shown = true
  tray.closedWithWindow = nil
  placeTray(tray)
  tray:Show()
  Queue.Draw()
  pcall(Queue.SyncStop)
  -- Brief PR40 item B: once the client has laid the tray out, the main button goes over its slot.
  after(0, function()
    pcall(Queue.SyncStop)
  end)
  return true
end

--- Hides the tray. A craft under way runs on and is counted; with nothing under way the events go.
--- Brief PR21: it never reopens the ItemTree window.
function Queue.Hide()
  local tray = Queue.tray
  if tray then
    tray.shown = false
    tray.closedWithWindow = nil
    tray:Hide()
  end
  hideTooltip()
  pcall(Queue.SyncStop)
  local run = Queue.run
  if not (run and type(run.inFlight) == "table") then
    releaseEvents()
  end
  return true
end


return Queue
