-- The Professions tab's pane (brief PR7, dressed in the client's own art by brief PR13): the
-- player's professions down the left, and on the right the chosen line's rank bar over a canvas of
-- its levelling bands, zoomed and panned the way the Item chain tab's canvas is.
--
-- Anatomy:
--   The strip     one row per profession the player has (Frame.PlayerSkills), with its glyph,
--                 its name and rank/max, in the sidebar's style. Clicking one selects it, and the
--                 choice is remembered for the session. A line the data holds no route for is
--                 still listed, and says so in plain words when chosen.
--   The rank bar  across the top of the canvas, fixed in height while it pans and zooms
--                 (UI\Bar.lua). Brief PR16: it is the canvas's own axis, so it pans and zooms with
--                 the bands under it: the player's rank in the profession's own fill, the empty
--                 stretch to the cap, the locked stretch past it, the tier ticks and the
--                 specialisation marks. One bordered tag ("Leatherworking 37/75") stands at the
--                 player's rank, on top of the "you are here" line. The zoom controls sit at its
--                 right.
--   The line      brief PR16: the "you are here" line, at the player's rank, down the canvas from
--                 the tag's stem. Brief PR17: drawn over the cards (the owner reversed "behind"),
--                 on a mouseless frame above them, 2 screen px wide. Brief PR23: a white core
--                 with a pale blue glow on its left only, fading out to the left (the way the
--                 player has come), 32 screen px at any zoom. The top strip has no frame, only
--                 its dark fill and a gold hairline at its foot (brief PR25).
--   The canvas    the bands as columns, left to right (UI\Layout.lua). A band's header is one
--                 short row in a warmer strip: "50 to 100" (the profession is in the strip and the
--                 tag), a tick once the player is past it, a small info mark whose hover carries the
--                 band's note (PR10's classic route note, or not yet checked), and the Craft all
--                 button (Core\Craft.lua, briefs PR14 and PR16; brief PR17: the window's red plate
--                 button). The player's own band wears a gold edge and a notch at the rank's place
--                 along it. Under it every recipe of the band as a flat card with a small chamfer
--                 (UI\Skin.lua Skin.Card): the recommended ones first, edged in gold with a solid
--                 gold Recommended tag on the top edge at the left (brief PR17), then the rest,
--                 with a "Show N more" row past the first few. Each card draws its item's icon, its
--                 name, the client's own difficulty arrows for the player's rank (orange triple,
--                 yellow double, green single, grey, a pale gold padlock where it cannot be learnt;
--                 brief PR19: dimmed whole where its rank is above the player's, on a red tinted
--                 card only where it is in range but the open profession window says it is not
--                 learnt), and its reagents with the bag count, wrapping to a
--                 second row rather than overlapping. A gold arrow joins each band's first
--                 recommended recipe to the next band's. Brief PR17, the owner's exception to the
--                 no dim rule: a grey recipe's card and a done band's header and cards are faded,
--                 and keep every hover, click and drag. A gathering line draws the same bands with
--                 the places to gather in each; a zone opens its zone page. Brief PR19: every fade
--                 is one SetAlpha on the element's own frame (a card, a header, a block), never on
--                 a piece inside it, so the whole element fades together. Brief PR37 (the owner,
--                 2026-10-02): the band the player's rank is in never fades, whatever a card's
--                 colour or lock, and on its cards a reagent short for one craft reads red. A
--                 gathering line's zone opens on its Map tab with the line's own group open and
--                 its first item picked (Pane.ZoneOpenOpts). Brief SC1: every recipe card has a
--                 Show craft button, Craft all's red plate at its bottom right (brief LF1: inside
--                 the card, which is taller to hold it), that opens the client's profession window
--                 on the line (Craft.ShowCraft).
--   The hints     brief LF1: one floating panel over the canvas's bottom right corner, a picture
--                 of each hotkey's input with its action's icon and word under it (zoom, pan,
--                 scroll), taking no mouse.
--   The warning   brief PR19: at a cap below 300, a strip under the rank bar says to visit a
--                 trainer, with a button that opens the Trainers & vendors panel; the canvas moves
--                 down under it. /itemtree profdemo cap (developer only, not packaged) shows it.
--
-- The zoom (brief PR16) runs from 10% to 200%. It is the canvas's SetScale, the chain tab's way;
-- everything on the canvas is flat colour, client icons and words, which the client draws sharp
-- at any scale (the bitmap card art and glow that blurred are gone). Below Pane.LOD_ZOOM the cards
-- and headers are drawn as plain coloured blocks with their icons, a few textures on one frame
-- and no frames per card, so the whole route on screen at 10% stays cheap.
--
-- Hover a recipe or a reagent for the client's own item tooltip; click one to open it in the Tree
-- tab (Frame.Open, then Frame.SelectTab, the Boss loot tab's OpenKey). A material (a reagent, a
-- gathered item, the queue tray's ingredients) opens on its Sources view, the owner's 2026-10-02
-- ask, through Frame.Open's opts.view; a recipe card keeps the default view. The dress up and chat link
-- clicks go to UI/ItemClick.lua first, through the chain tab's Chain.ModifiedClick (E6). A press
-- that moves past a few pixels before it lets go is a pan, wherever it started, and its click is
-- swallowed.
--
-- The hard rule: no item query in bulk. Only the nodes on screen get frames, and only those ask
-- the client for an icon (Assets.ItemIcon: our data, then the client's local icon calls, then the
-- question mark) and for a bag count (GetItemCount). Both are local reads; nothing here ever asks
-- the server to load an item.
--
-- The pane contract, as UI/BossLoot.lua's: Attach(region) once, Show() whenever the tab is
-- selected, Refresh(), Hide(). The core's stub (UI/ProfessionsStub.lua) forwards each call here
-- once this folder has loaded. While the tab is hidden the pane does no work at all: its skill
-- and bag events are unregistered and nothing is drawn.
--
-- Brief PB1: the reagent counts follow the bags while the tab is up. A bag or bank event redraws
-- the count words (and their colour, and the "N more for one craft" a reagent's hover says) on
-- the cards on screen, and nothing else (Pane.RefreshCounts), once per burst; a cards pass or a
-- pan reads them fresh as ever, and showing the tab again draws it from scratch.
--
-- Everything above the "Client side" divider is pure and runs under busted with no WoW API.
local _, ItemTree = ...
-- ItemTree_Professions is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Modules) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end

local Professions = ItemTree.Professions
if type(Professions) ~= "table" then
  Professions = {}
  ItemTree.Professions = Professions
end
local Pane = Professions.pane
if type(Pane) ~= "table" then
  Pane = {}
  Professions.pane = Pane
end

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

local themeSizes = ItemTree.ProfessionsKit.ThemeSizes

local function themeFontSizes()
  local theme = ItemTree.Theme
  return type(theme) == "table" and type(theme.fontSizes) == "table" and theme.fontSizes or EMPTY
end

local SIZES, FONTS = themeSizes(), themeFontSizes()

-- Sizes, from the Theme tokens where one exists.
Pane.STRIP_W = SIZES.ITEMTREE_LIST_COL_SIDEBAR or 180
Pane.ROW_H = SIZES.ITEMTREE_LIST_ROW_H or 22
Pane.ROW_ICON = SIZES.ITEMTREE_ICON_CATEGORY or 16
Pane.GUTTER = SIZES.ITEMTREE_LIST_GUTTER or 6
Pane.PAD = SIZES.ITEMTREE_SPACE_2 or 8
Pane.SMALL_PAD = SIZES.ITEMTREE_SPACE_1 or 4
-- Brief PR13: a card is wide enough for three reagents with three digit counts on one row.
Pane.COL_W = SIZES.ITEMTREE_PROFESSION_CARD_W or 244
Pane.NODE_H = SIZES.ITEMTREE_PROFESSION_CARD_H or 46
Pane.SPOT_H = 42
-- Brief PR17: the gap between stacked cards (the stack gap token), so the Recommended tag on a card's
-- top edge stands clear of the card above. Brief PR21: 17 px, for the taller tag.
Pane.CARD_GAP = SIZES.ITEMTREE_PROFESSION_CARD_STACK_GAP or 17
Pane.CANVAS_PAD = 10
-- Brief PR16: the padding between a card's edge and its icon, words and reagents.
Pane.CARD_INSET = 8
Pane.NODE_ICON = SIZES.ITEMTREE_ICON_BAGSLOT_MIN or 30
Pane.NAME_H = 14
-- Brief PR49c (owner QA 2026-10-05): the Changed badge right of a recipe card's name, where the
-- recipe goes grey at a different rank on Classic Era. The frame is the list badge size, its
-- medallion one step up the badge ladder (UI/Badges.lua ArtSize), the gap the badges' own.
Pane.BADGE = SIZES.ITEMTREE_BADGE_SIZE_LIST or 12
Pane.BADGE_ART = SIZES.ITEMTREE_BADGE_SIZE_TOOLTIP or 14
Pane.BADGE_GAP = 3
Pane.DIFF_W, Pane.DIFF_H = 13, 15
Pane.REAGENT = SIZES.ITEMTREE_PROFESSION_REAGENT or 16
-- The owner, 2026-10-02: room for "274/274 (12)", the have/need and one craft's count, at the
-- small font. Two reagents to a row on a card; a third wraps to the next.
Pane.COUNT_W = 72
Pane.REAGENT_W = Pane.REAGENT + 2 + Pane.COUNT_W + 4
Pane.REAGENT_ROW_GAP = 3
Pane.REAGENT_MAX = 4
-- The Recommended tag: a small pill straddling the card's top edge, its bottom TAG_IN px inside,
-- so it stands TAG_H - TAG_IN px proud, inside the CARD_GAP above. Brief PR17: at the card's top
-- left, TAG_LEFT px in, solid gold with dark words and a TAG_CHAMFER px bevel at each corner.
-- Brief PR21 (the owner): 2 px more above and below the words (18 px, up from 14), and the words
-- RECOMMENDED in the client's Friz Quadrata font object GameFontBlackSmall, the heavier face the
-- client offers for Latin text (it has no bold weight; FontStyles.xml, branch forever), which also
-- carries no shadow. Its bottom stays TAG_IN px inside the card, clear of the icon and the name,
-- so it stands TAG_H - TAG_IN = 11 px proud into the 17 px CARD_GAP and clears the card above by
-- 6 px, as the 14 px tag did in its 13 px gap.
Pane.TAG_H = SIZES.ITEMTREE_PROFESSION_TAG_H or 18
Pane.TAG_IN = 7
Pane.TAG_LEFT = 10
Pane.TAG_CHAMFER = 3
Pane.TAG_CHAR_W = 7.2
Pane.TAG_PAD = 12
Pane.TAG_FONT = "GameFontBlackSmall"
Pane.TAG_FONTS = { "GameFontBlackSmall", "GameFontNormalSmall", "GameFontHighlightSmall" }
-- The room a route arrow keeps from the cards it joins.
Pane.LINK_CLEAR = 4
Pane.ROUTE_BORDER = SIZES.ITEMTREE_PROFESSION_ROUTE_BORDER or 2
Pane.HAIRLINE = SIZES.ITEMTREE_BORDER_HAIRLINE or 1
Pane.HERE_W = SIZES.ITEMTREE_PROFESSION_HERE_W or 2
-- Brief PR23: the line's soft glow, this many screen px to the left of the line, none to its right.
-- Brief PR24: 60% of PR23's 32.
Pane.HERE_GLOW_W = SIZES.ITEMTREE_PROFESSION_HERE_GLOW_W or 19
-- Brief PR24 (the owner): at this rank or below the line has no glow, only its white core (at
-- Fishing 1/75 the glow spilled over the profession list).
Pane.HERE_GLOW_MIN_RANK = 5
-- Brief PR13: one short header row; PR10's note moved to the info mark's hover.
Pane.HEADER_H = SIZES.ITEMTREE_PROFESSION_HEADER_H or 30
-- Brief PR48: the muted suggestion line under a gathering band's header row ("Mine Copper Ore 1 to
-- 65, Smelt Copper 1 to 65"), and the muted word lines under a smelt card's reagents.
Pane.NOTE_H = 14
-- Brief G1b: a gathering heading names at most this many arriving items, and the cards' points
-- end no later than this.
Pane.GATHER_NAMED = 3
Pane.GATHER_MAX = 300
-- Brief BQ24 (QA item 35): the strip row's red gem, the Discoveries tab's gem art (UI/Assets.lua
-- BUBBLE_NOTIFICATION) at this size, in the window's alert tint (UI/Frame.lua Frame.ALERT_TINT).
Pane.GEM_ASSET = "BUBBLE_NOTIFICATION"
Pane.GEM_SIZE = 18
Pane.GEM_TINT = "ITEMTREE_COLOR_SEMANTIC_REMOVED"
Pane.WORD_LINE_H = 13
-- Brief G1c (owner, 2026-10-06): the margin between a card's last reagent row and its first muted
-- word line; the card grows by it wherever it has word lines.
Pane.WORD_GAP = 4
-- Brief PR49b: the most muted word lines a card draws (a smelt card's two, a crafting card's
-- route lines: no points, grey, pattern, specialisation, Season of Discovery, cooldown).
Pane.WORD_LINES = 6
Pane.TICK = SIZES.ITEMTREE_ICON_CATEGORY or 16
Pane.INFO = 14
Pane.NOTCH = 10
Pane.CRAFT_H = 18
Pane.CRAFT_FADED = 0.5
-- Brief SC1 (QA item 212, the owner: "a 'Show craft' button bottom right (small standard red
-- button)"): Craft all's red plate button on every recipe card, at the bottom right; SHOW_W where
-- the client will not measure the words. Brief LF1 (QA item 239b, the owner: "Show craft should
-- extend the card height not sit half in/half out like the recommendation"): SC1 stood it across the
-- card's bottom edge; it now sits inside the card, on a row of its own under everything else on it
-- (the reagents and any word lines), SHOW_GAP px under the last of them and the card's own
-- CARD_INSET from its right and bottom edges. A recipe card is SHOW_ROOM px taller for it
-- (Pane.NodeHeight), so the layout, the arrows and the band columns follow the taller cards.
Pane.SHOW_H = Pane.CRAFT_H
Pane.SHOW_GAP = 4
Pane.SHOW_RIGHT = Pane.CARD_INSET
Pane.SHOW_BOTTOM = Pane.CARD_INSET
Pane.SHOW_ROOM = Pane.SHOW_GAP + Pane.SHOW_H
Pane.SHOW_W = 70
-- Brief SC5 (QA items 284 and 289): the button reads "Show craft" or "Find recipe" by the window's
-- state, and keeps the width "Show craft" gives it either way, so the card never moves. Its words sit
-- SHOW_PAD px in from each end (buildShowButton); words wider than the room left take the font
-- SHOW_FONT_STEP smaller (Pane.ShowFontSize), never a wider button.
Pane.SHOW_PAD = 4
Pane.SHOW_FONT_STEP = 1
-- Brief PR17 (the owner's exception to the no dim rule, QA round 3): a grey recipe's card draws at
-- GREY_ALPHA, and a done band's header and cards at DONE_ALPHA. Hover, click and drag still work.
Pane.GREY_ALPHA = 0.45
Pane.DONE_ALPHA = 0.55
-- Brief PR19 (QA round 4): a recipe above the player's rank (not learnable yet, out of range) is
-- dimmed whole at FUTURE_ALPHA. Brief PR21 (QA round 5) corrects PR19: it is the red locked card
-- as well, dimmed. Every fade is one SetAlpha on the card's, the
-- header's or the block's own frame; nothing inside it carries an alpha of its own.
Pane.FUTURE_ALPHA = 0.45
-- Brief PR19: the Recommended tag's thin border corner, smaller than a card's.
Pane.TAG_CORNER = 5
-- Brief PR19: the trainer warning strip under the rank bar, at a cap below 300.
Pane.WARN_H = 28
Pane.WARN_ICON = 18
Pane.WARN_FILL = "ITEMTREE_COLOR_PROFESSION_WARN_FILL"
Pane.WARN_EDGE = "ITEMTREE_COLOR_PROFESSION_WARN_EDGE"
Pane.WARN_WORD = "ITEMTREE_COLOR_PROFESSION_WARN_WORD"
-- Brief PR17: the "you are here" line's frame stands this many levels above the canvas, over every
-- card (a card's tag sits 3 above the card, the card 1 above the canvas) and under the Trainers &
-- vendors panel (20 above the board).
Pane.HERE_LEVEL = 8
Pane.ARROW_HEAD = 8
-- Brief PR23: the route arrow's head, the talent tree's own (Assets PROFESSION_ROUTE_ARROW): drawn
-- at the atlas's own 14 by 12 and turned a quarter (it points down in its art) to point right,
-- so it reaches ARROW_ATLAS_H along the shaft. The old chevron (ARROW_HEAD square) where the client
-- has no such atlas or cannot turn a texture.
Pane.ARROW_ATLAS_W = 14
Pane.ARROW_ATLAS_H = 12
Pane.ARROW_KEY = "PROFESSION_ROUTE_ARROW"
-- The owner, 2026-10-02: the yellow head, preferred; desaturated, then tinted the route gold, so
-- its colour is the shaft's token rather than the grey art darkened by the tint.
Pane.ARROW_YELLOW_KEY = "PROFESSION_ROUTE_ARROW_YELLOW"
Pane.ARROW_FALLBACK_KEY = "ICON_CHEVRON_EXPAND"
Pane.GAP = (SIZES.ITEMTREE_CHAIN_GAP or 20) + (SIZES.ITEMTREE_CHAIN_ARROW or 24)
Pane.COLLAPSE = 6
Pane.TOP_H = SIZES.ITEMTREE_PROFESSION_TOP_H or 56
-- Brief PR23 framed the top strip (the rank tag, the bar, the Trainers button and the zoom
-- controls) as one; brief PR25 (the owner) drops the frame: only the dark fill and one gold hairline
-- at its foot, with the tag, the bar and the controls kept TOP_INSET px in from the strip's ends and
-- Bar.TAG_Y from its top.
Pane.TOP_INSET = 6
-- The one line kept, along the strip's foot: the window's inner edge gold (UI\Frame.lua bodyEdges).
Pane.TOP_RULE = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
-- Brief PR24 (the owner: "make the background area of the header darker"): one dark fill of its
-- own, no longer the info column's inset and gold wash.
Pane.TOP_FILL = "ITEMTREE_COLOR_PROFESSION_TOP_FILL"
-- The rank tag's and the controls' top inside the strip (UI\Bar.lua Bar.TAG_Y).
Pane.TOP_CONTROLS_Y = 7
Pane.CONTROL_H = SIZES.ITEMTREE_CONTROL_H_SM or 20
Pane.FONT_MD = FONTS.ITEMTREE_FONTSIZE_BODY_MD or 12
Pane.FONT_SM = FONTS.ITEMTREE_FONTSIZE_BODY_SM or 11
Pane.FONT_TEMPLATE = "GameFontNormalSmall"
Pane.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }
-- The zoom, the chain tab's steps, down to 10% (brief PR16, the whole route on screen) and up to
-- twice (a card blown up past that reads as a mistake). Below LOD_ZOOM the cards are drawn as
-- blocks (the header). A press moving past DRAG_THRESHOLD, in the viewport's own units, is a pan.
Pane.ZOOM_MIN = 0.1
Pane.ZOOM_MAX = 2.0
Pane.LOD_ZOOM = 0.45
Pane.ZOOM_STEP = 1.25
Pane.DRAG_THRESHOLD = 5
-- Brief UI15 (QA item 213, the owner's version of Tom's ask): holding Shift turns the wheel from zoom
-- into scroll, a notch moving the view SCROLL_STEP viewport px (a card and the gap under it), up and
-- down, or sideways where the canvas's whole height already shows (Pane.ScrollAxis). The pointer is
-- the client's four way move arrow (PAN_CURSOR) while a press pans and while it is over bare canvas.
Pane.SCROLL_STEP = Pane.NODE_H + Pane.CARD_GAP
Pane.PAN_CURSOR = "UI_MOVE_CURSOR"
-- Brief LF1 (QA item 240c, the owner: "Instead of a bottom bar I'd prefer a floating panel bottom
-- right and instead of text I want icon + text underneath for each one (keep them all with one semi
-- transparent background panel with a thin border dividing each hotkey"; "To the left of each word
-- action (e.g. Pan) have a relevant icon like the 4 way arrows (small and to the left of th text)"):
-- UI15's strip of words under the canvas is gone. The hints float in one panel over the canvas's
-- bottom right corner, HINT_MARGIN px in from it: the card art (Skin.Card, the thin bevelled border
-- in HINT_EDGE) over HINT_FILL, the top strip's dark at 78 percent, cut into one cell per hotkey by a
-- 1 px HINT_EDGE divider HINT_DIVIDER_IN px short of the panel's top and bottom. A cell is a picture
-- of the input, HINT_ART_H tall, and under it HINT_ROW_GAP px the action's icon (HINT_ICON px, tinted
-- the words' colour) HINT_ICON_GAP px left of its word, HINT_PAD_X and HINT_PAD_Y px inside the cell,
-- never narrower than HINT_CELL_MIN. The pictures are our own drawing (Art/hint-keys.tga, built by
-- scripts/build-art.py from the marketing animator's mouse): the mouse HINT_MOUSE_W by HINT_ART_H
-- with its wheel lit yellow for zoom, with its left button lit for pan, and for scroll a Shift
-- keycap (HINT_KEY_H tall, its word drawn by the client, at least HINT_KEY_W wide) and a "+" before
-- the wheel lit mouse, HINT_JOIN_GAP px apart. The icons: a magnifier for zoom, the four way arrows
-- for pan, an up and down arrow for scroll. The panel takes no mouse, so a press, a drag or the
-- wheel over it reaches the canvas and the card under it; it stands HINT_LEVEL levels over the
-- canvas, above the cards and the "you are here" line and under the Trainers & vendors panel. And
-- the pan keeps the panel's room (Pane.HintReserve) clear under the route's foot: a route taller
-- than the view less that room scrolls far enough for its lowest card and its "Show N more" to come
-- up above the panel, and one shorter never reaches it.
Pane.HINT_MARGIN = 8
Pane.HINT_PAD_X = 8
Pane.HINT_PAD_Y = 6
Pane.HINT_ART_H = 30
Pane.HINT_MOUSE_W = 20
Pane.HINT_KEY_W = 32
Pane.HINT_KEY_H = 20
Pane.HINT_KEY_PAD = 5
Pane.HINT_JOIN_GAP = 3
Pane.HINT_ICON = 12
Pane.HINT_ICON_GAP = 3
Pane.HINT_LINE_H = 12
Pane.HINT_ROW_GAP = 3
Pane.HINT_CELL_MIN = 48
Pane.HINT_DIVIDER_IN = 6
Pane.HINT_CLEAR = 4
Pane.HINT_LEVEL = 12
Pane.HINT_FILL = "ITEMTREE_COLOR_PROFESSION_HINT_FILL"
Pane.HINT_EDGE = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
Pane.HINT_WORD = "ITEMTREE_COLOR_TEXT_BODY"
-- The three hotkeys in the owner's order: the word's Pane.WORDS key, the input picture's art keys
-- (the keycap, where it has one, then the mouse) and the action icon's key.
Pane.HINTS = {
  { name = "zoom", word = "hintZoom", mouse = "PROFESSION_HINT_MOUSE_WHEEL", icon = "PROFESSION_HINT_ZOOM" },
  { name = "pan", word = "hintPan", mouse = "PROFESSION_HINT_MOUSE_LEFT", icon = "PROFESSION_HINT_PAN" },
  {
    name = "scroll",
    word = "hintScroll",
    key = "PROFESSION_HINT_KEYCAP",
    mouse = "PROFESSION_HINT_MOUSE_WHEEL",
    icon = "PROFESSION_HINT_SCROLL",
  },
}
-- Seconds a burst of skill events is folded into one redraw, the model's own throttle.
Pane.THROTTLE = 1
Pane.EVENTS = { "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "LEARNED_SPELL_IN_TAB" }
-- Brief PB1 (owner QA 2026-10-09, 1.60.1.70291: a stack of Coarse Thread bought with the tab open
-- left every card at "0/2 (2)"): the events that move a reagent count, heard only while the tab is
-- shown. The bags settling (never BAG_UPDATE, which fires once per bag per change), and the bank
-- opening or changing, because a plan's need counts the bank too. Both bank events are in the
-- forever branch's Blizzard_APIDocumentationGenerated/BankDocumentation.lua (2026-10-09); there is
-- no reagent bank event there. A burst is folded into one counts pass COUNT_THROTTLE seconds on.
Pane.COUNT_EVENTS = { "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED" }
Pane.COUNT_THROTTLE = 0.25

-- Colours, all Theme keys.
Pane.ROUTE_GOLD = "ITEMTREE_COLOR_PROFESSION_ROUTE_GOLD"
Pane.CARD_GOLD = "ITEMTREE_COLOR_PROFESSION_CARD_GOLD"
Pane.CARD_FILL = "ITEMTREE_COLOR_PROFESSION_CARD_FILL"
Pane.CARD_EDGE = "ITEMTREE_COLOR_PROFESSION_CARD_EDGE"
Pane.HEADER_FILL = "ITEMTREE_COLOR_PROFESSION_HEADER_FILL"
Pane.HEADER_EDGE = "ITEMTREE_COLOR_PROFESSION_HEADER_EDGE"
Pane.HERE = "ITEMTREE_COLOR_PROFESSION_HERE"
-- Brief PR23: the line's crisp white core and its pale blue glow.
Pane.HERE_CORE = "ITEMTREE_COLOR_PROFESSION_HERE_CORE"
Pane.HERE_GLOW = "ITEMTREE_COLOR_PROFESSION_HERE_GLOW"
Pane.PLAIN_BORDER = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
Pane.SURFACE = "ITEMTREE_COLOR_SURFACE_INSET"
Pane.NODE_FACE = "ITEMTREE_COLOR_BUTTON_FACE"
Pane.HOVER = "ITEMTREE_COLOR_STATE_HOVER"
Pane.SELECTED = "ITEMTREE_LIST_STATE_SELECTED"
Pane.BAND_WORD = "ITEMTREE_COLOR_BAND_WORD"
Pane.NAME_WORD = "ITEMTREE_COLOR_TEXT_BODY"
Pane.MUTED_WORD = "ITEMTREE_COLOR_TEXT_MUTED"
Pane.SELECTED_WORD = "ITEMTREE_COLOR_TEXT_SELECTED"
Pane.DONE_TICK = "ITEMTREE_COLOR_KEEP_YES"
-- Brief PR17: the locked card, the tag's dark words, the plate buttons' words and the padlock.
Pane.LOCKED_FILL = "ITEMTREE_COLOR_PROFESSION_LOCKED_FILL"
Pane.LOCKED_EDGE = "ITEMTREE_COLOR_PROFESSION_LOCKED_EDGE"
Pane.LOCKED_GOLD = "ITEMTREE_COLOR_PROFESSION_LOCKED_GOLD"
Pane.TAG_WORD = "ITEMTREE_COLOR_PROFESSION_TAG_WORD"
Pane.PLATE_WORD = "ITEMTREE_COLOR_TEXT_TITLE"
Pane.LOCK_TINT = "ITEMTREE_COLOR_PROFESSION_LOCK_ICON"
-- Brief PR37 (the owner, 2026-10-02): on a card of the player's own band, a reagent the bags (and
-- the bank, where the have count reads it) hold too few of for ONE craft reads in the warning red
-- the craft queue's unmet requirements wear (UI\Queue.lua Queue.REQ_UNMET).
Pane.SHORT_WORD = "ITEMTREE_COLOR_KEEP_NO"
-- Brief PR37 (the owner, 2026-10-02): a gathering line's zone spot opens the zone's Map tab on the
-- group of its items that line gathers, its first item picked. By skill line, the zone list's
-- group ids (Core\ViewModel.lua GROUP_IDS) in order of preference: Skinning (393) the skinned
-- group, Mining (186) the mined group, Herbalism (182) the herb gathering group, Fishing (356) the
-- fished group. A line not here opens the zone page as it always has.
Pane.GATHER_GROUPS = {
  [393] = { "skinned" },
  [186] = { "minedfrom", "minedin" },
  [182] = { "gathered", "gatheredin" },
  [356] = { "fishedin", "fished" },
}

-- Brief PR13: the client's recipe difficulty arrows, by the model's colour, with the text and the
-- colour drawn where the arrow art will not draw.
Pane.DIFFICULTY = {
  orange = { key = "PROFESSION_SKILL_HIGH", text = ">>>", colour = "ITEMTREE_COLOR_SKILL_ORANGE" },
  yellow = { key = "PROFESSION_SKILL_MEDIUM", text = ">>", colour = "ITEMTREE_COLOR_SKILL_YELLOW" },
  green = { key = "PROFESSION_SKILL_LOW", text = ">", colour = "ITEMTREE_COLOR_SKILL_GREEN" },
  grey = { key = "PROFESSION_SKILL_LOW", text = ">", colour = "ITEMTREE_COLOR_SKILL_GREY", grey = true },
  -- Brief PR17: the padlock (and its text fallback) in a pale gold that reads on the red card.
  unlearnable = { key = "PROFESSION_LOCK", text = "x", colour = "ITEMTREE_COLOR_PROFESSION_LOCK_ICON", lock = true },
}

-- A spot's glyph where it has no item icon of its own.
Pane.SPOT_ICONS = { zone = "PROFESSION_ZONE", creature = "CAT_DROPS", node = "CAT_MINING" }

-- Every word the pane draws.
Pane.WORDS = {
  band = L["%d to %d"],
  bandTitle = L["%s %d to %d"],
  untested = L["Not yet checked on this client."],
  classic = L["This route is from the original game and may not be the best path here. New recipes still show below."],
  recommended = L["RECOMMENDED"],
  empty = L["Learn a profession to see its levelling route here."],
  noRoute = L["There is no levelling route for %s yet."],
  more = L["Show %d more"],
  fewer = L["Show fewer"],
  profession = L["Profession"],
  item = L["Item %d"],
  undiscovered = L["Undiscovered item"],
  spell = L["Spell %d"],
  zone = L["Zone %d"],
  creature = L["Creature %d"],
  object = L["Object"],
  openZone = L["Click to open the zone page"],
  -- The owner, 2026-10-02: a material opens straight on its Sources view.
  seeSources = L["Click to see where to get it"],
  -- The owner, 2026-10-02: a locked card opens where to learn its recipe.
  seeLearn = L["Click to see where to learn it"],
  -- The owner, 2026-10-02: a reagent's have/need, then one craft's count in brackets.
  reagentCount = L["%d/%d (%d)"],
  -- Brief PR37: a short reagent's hover (brief PRX, PR43: on every card).
  shortForOne = L["%d more for one craft"],
  -- Brief PRX (PR44): an alternative's hover, what it would take on its own to the band's end.
  aloneHead = L["On its own, %d crafts to reach %d:"],
  aloneItem = L["%d x %s"],
  -- Brief PR48 (owner QA, 2026-10-05): a gathering band's suggestion and a smelt card's words.
  noteMine = L["Mine %s %d to %d, %s %d to %d"],
  noteMineAny = L["Mine %d to %d, %s %d to %d"],
  reagentPart = L["%s x%d"],
  makes = L["%s -> %s"],
  -- Brief G1c (owner, 2026-10-06): "Guaranteed" where it said "Sure".
  windowBoth = L["Guaranteed points to %d, likely to %d"],
  windowSure = L["Guaranteed points to %d"],
  windowLikely = L["Likely points to %d"],
  -- Brief G1b (owner, 2026-10-05): a planned gathering band's item cards and its heading note.
  -- Brief G1c (owner, 2026-10-06): the card line simplified, "Gather from 275 - 300", "Gather to 285".
  gatherFrom = L["Gather from %d - %d"],
  gatherTo = L["Gather to %d"],
  -- Brief TB14 (owner, Black Lotus): "Gather at 300" where the two numbers are one.
  gatherAt = L["Gather at %d"],
  -- Brief TB14: the New badge's hover where ItemTree's Badges is not there to ask (UI/Badges.lua
  -- TITLE.new and MEANING.new, the words the main window's New badge says).
  newTitle = L["New in Forever"],
  newMeaning = L["Compared with Classic Era"],
  gatherNote = L["Gather %s"],
  gatherItem = L["%s from %d"],
  gatherMore = L["%s and %d more"],
  gatherCarry = L["%s still gives points to %d"],
  gatherCarryJoin = L["%s; %s"],
  noteJoin = L["%s. %s"],
  -- Brief PR19: the trainer warning strip, and the word a developer's demo of it carries.
  capWarning = L["You have hit the %s cap (%d/%d). Visit a trainer to learn %s."],
  showTrainers = L["Show trainers"],
  demo = L["Demo: %s"],
  zoomIn = L["Zoom in"],
  zoomOut = L["Zoom out"],
  reset = L["Reset"],
  resetHint = L["Reset the zoom and centre on your current level"],
  -- Brief LF1 (QA item 240c): each hotkey's action word under its picture in the floating panel
  -- (UI15's line said "Mouse wheel: zoom", "Click and drag: pan", "Shift + wheel: scroll"), the
  -- Shift keycap's word and the "+" before the mouse.
  hintZoom = L["Zoom"],
  hintPan = L["Pan"],
  hintScroll = L["Scroll"],
  hintShift = L["Shift"],
  hintPlus = L["+"],
  -- Brief PR49b: a recipe card's route lines, the band heading's hover, and the live re-rank.
  noPoints = L["No points here on this client"],
  greyAt = L["Goes grey at %d (Classic Era %d)"],
  -- Brief PR49c: a dropped pattern can be bought on the auction house (the owner's words).
  learnDrop = L["Pattern must be found or bought on AH"],
  learnVendor = L["Pattern sold by a vendor"],
  learnReputation = L["Pattern from a reputation vendor"],
  learnSpec = L["Needs the %s specialisation"],
  learnSpecAny = L["Needs a specialisation"],
  sod = L["Season of Discovery recipe"],
  wasOne = L["Classic guides use %s (grey here)"],
  wasMany = L["Classic guides use %s (grey here)"],
  nameJoin = L["%s and %s"],
  cooldown = L["needs %d %s, about %d days of cooldowns"],
  cooldownDay = L["needs %d %s, about a day of cooldowns"],
  costPoint = L["About %s a point at your auction prices"],
  costBest = L["Cheapest at your auction prices: about %s a point"],
  reranked = L["Reordered by your auction prices"],
  -- The owner, 2026-10-02: what Craft all does, the hover's one body paragraph.
  -- luacheck: push ignore 631
  craftHow = L["This will add as many items as possible into a crafting queue, up to the amount it takes to level up to the next profession band. Recommended items are prioritised."],
  -- luacheck: pop
}

--------------------------------------------------------------------------------
-- Pure
--------------------------------------------------------------------------------

--- "50 to 100": the band header (brief PR16: the profession is already in the strip and the tag,
--- and the longer words did not fit). Pure.
function Pane.BandText(band)
  band = type(band) == "table" and band or EMPTY
  return string.format(Pane.WORDS.band, tonumber(band.lo) or 0, tonumber(band.hi) or 0)
end

--- "Cooking 50 to 100": the band's full name, for its hovers. Pure.
function Pane.BandTitle(name, band)
  band = type(band) == "table" and band or EMPTY
  return string.format(
    Pane.WORDS.bandTitle,
    tostring(name or Pane.WORDS.profession),
    tonumber(band.lo) or 0,
    tonumber(band.hi) or 0
  )
end

--- The band's note, or nil. A band from the original game's route (brief PR10, from = "classic")
--- says so, and that recipes new to this client still show; it never names where the route came
--- from. A band that is only untested says it is not yet checked. A band that is both shows just
--- the classic note. Brief PR13: shown on the header's info mark's hover, never in the header.
--- Pure.
function Pane.BandNote(band)
  if type(band) ~= "table" then
    return nil
  end
  if band.from == "classic" then
    return Pane.WORDS.classic
  end
  if band.untested == true then
    return Pane.WORDS.untested
  end
  return nil
end

--- Brief PR48: whether any band of a track carries a gathering note (Model.Track's note). Brief
--- G1c: only a smelting note (mine and smelt) counts, the one the heading draws; a gather note
--- alone (Herbalism) leaves the heading one short row. Pure.
function Pane.HasNotes(track)
  local bands = type(track) == "table" and track.bands or nil
  for _, band in ipairs(type(bands) == "table" and bands or EMPTY) do
    local note = type(band) == "table" and band.note or nil
    if type(note) == "table" and type(note.mine) == "table" and type(note.smelt) == "table" then
      return true
    end
  end
  return false
end

--- The header height for a line's bands. Brief PR13: one short row whatever the notes, which
--- live in the info mark's hover now (PR10 grew it to fit them). Brief PR48: a track whose bands
--- carry a gathering note (Mining) gains one muted line under the row, on every band alike. Pure.
function Pane.HeaderHeight(track)
  if Pane.HasNotes(track) then
    return Pane.HEADER_H + Pane.NOTE_H
  end
  return Pane.HEADER_H
end

--- Brief PR48: a gathering band's suggestion in one line, "Mine Copper Ore 1 to 65, Smelt
--- Copper 1 to 65": the band's first item spot (the ore), the note's mine range, the smelt's name
--- and its range. band is Model.Track's (spots, note). nil without a note. Pure.
function Pane.NoteText(names, band)
  local note = type(band) == "table" and band.note or nil
  if type(note) ~= "table" or type(note.mine) ~= "table" or type(note.smelt) ~= "table" then
    return nil
  end
  local smelt = Pane.NodeName(names, { spell = note.smelt[1] }, nil)
  local mineLo, mineHi = tonumber(note.mine[1]) or 0, tonumber(note.mine[2]) or 0
  local from, to = tonumber(note.smelt[2]) or 0, tonumber(note.smelt[3]) or 0
  for _, spot in ipairs(type(band.spots) == "table" and band.spots or EMPTY) do
    if type(spot) == "table" and spot.k == "item" and tonumber(spot.id) then
      local ore = Pane.ItemName(names, tonumber(spot.id), false)
      return string.format(Pane.WORDS.noteMine, ore, mineLo, mineHi, smelt, from, to)
    end
  end
  return string.format(Pane.WORDS.noteMineAny, mineLo, mineHi, smelt, from, to)
end

--- Brief G1b: where gathered points end, g clamped to 300 (the data clamps it to the line's max;
--- a hand edit or older pipeline might not). nil without a number. Pure.
function Pane.GatherGrey(g)
  g = tonumber(g)
  if not g then
    return nil
  end
  return math.min(g, Pane.GATHER_MAX)
end

--- Brief G1b: the muted line under a planned gathering band's item card. Brief G1c (owner,
--- 2026-10-06): "Gather from 205 - 300" for an item arriving in the band (s at or above its lo),
--- "Gather to 285" for a carry (s below lo). nil for a spot without both s and g (older data, zone
--- spots). Brief TB14 (owner, Black Lotus): "Gather at 300" where s and g are one number. Pure.
function Pane.SpotWords(spot, lo)
  if type(spot) ~= "table" or spot.k ~= "item" then
    return nil
  end
  local s, g = tonumber(spot.s), Pane.GatherGrey(spot.g)
  if not (s and g) then
    return nil
  end
  if tonumber(lo) and s < tonumber(lo) then
    return string.format(Pane.WORDS.gatherTo, g)
  end
  if s == g then
    return string.format(Pane.WORDS.gatherAt, g)
  end
  return string.format(Pane.WORDS.gatherFrom, s, g)
end

--- Brief G1b: a planned gathering band's heading note from note.gather (Model.GatherNote): "Gather
--- Firebloom from 205, Purple Lotus from 210" for the items arriving in the band (s at or above its
--- lo, in s order, at most three named then "and N more"), then "; Khadgar's Whisker still gives
--- points to 285" for the freshest carry still giving points at lo. Each item's s and g come from
--- the band's item spots; an item with no such spot is left out. band is Model.Track's (lo, spots,
--- note). nil without a gather note or with nothing to say. Pure.
function Pane.GatherText(names, band)
  local note = type(band) == "table" and band.note or nil
  local gather = type(note) == "table" and note.gather or nil
  if type(gather) ~= "table" or type(gather.items) ~= "table" then
    return nil
  end
  local lo = tonumber(band.lo) or tonumber(gather.lo) or 0
  local spotOf = {}
  for _, spot in ipairs(type(band.spots) == "table" and band.spots or EMPTY) do
    if type(spot) == "table" and spot.k == "item" and tonumber(spot.id) and tonumber(spot.s) then
      spotOf[tonumber(spot.id)] = spotOf[tonumber(spot.id)] or spot
    end
  end
  local arrivals, carry = {}, nil
  for index, id in ipairs(gather.items) do
    local spot = tonumber(id) and spotOf[tonumber(id)] or nil
    if spot then
      local s, g = tonumber(spot.s), Pane.GatherGrey(spot.g)
      if s >= lo then
        arrivals[#arrivals + 1] = { id = tonumber(id), s = s, index = index }
      elseif g and g > lo and (carry == nil or s > carry.s) then
        carry = { id = tonumber(id), s = s, g = g }
      end
    end
  end
  table.sort(arrivals, function(a, b)
    if a.s ~= b.s then
      return a.s < b.s
    end
    return a.index < b.index
  end)
  local text = nil
  if #arrivals > 0 then
    local parts = {}
    for index = 1, math.min(#arrivals, Pane.GATHER_NAMED) do
      local item = arrivals[index]
      parts[#parts + 1] = string.format(Pane.WORDS.gatherItem, Pane.ItemName(names, item.id, false), item.s)
    end
    text = table.concat(parts, ", ")
    if #arrivals > Pane.GATHER_NAMED then
      text = string.format(Pane.WORDS.gatherMore, text, #arrivals - Pane.GATHER_NAMED)
    end
    text = string.format(Pane.WORDS.gatherNote, text)
  end
  if carry then
    local carried = string.format(Pane.WORDS.gatherCarry, Pane.ItemName(names, carry.id, false), carry.g)
    if text then
      text = string.format(Pane.WORDS.gatherCarryJoin, text, carried)
    else
      text = carried
    end
  end
  return text
end

--- Brief G1b: the band heading's muted line. Brief G1c (owner, 2026-10-06): the smelting sentence
--- (Pane.NoteText) alone; the gather words (Pane.GatherText) are never drawn in the heading or its
--- hover, the item cards carry them. nil without a smelting note. Pure.
function Pane.HeadingNote(names, band)
  return Pane.NoteText(names, band)
end

--- Brief PR48: a smelt card's skill window, "Guaranteed points to 25, likely to 70" (tl, th): sure
--- up to yellow, a chance up to grey. "Guaranteed points to 175" where tl reaches th, "Likely points to 70"
--- without a tl; nil without either. Pure.
--- Brief TR1 addendum 4 (owner ruling 2026-10-11, the higher smelts' tables are not properly
--- released: learnt = yellow = grey): an empty stretch is never printed. A yellow (tl) not above
--- the learn rank r gives no guaranteed stretch, so the line is "Likely points to <th>" where the
--- grey is above r (Smelt Tin 65 / 65 / 75), and no line at all where it is not either (a flat
--- window: Smelt Truesilver 230, Smelt Thorium 250). A node with no r is read as learnt at 0.
function Pane.WindowText(node)
  if type(node) ~= "table" then
    return nil
  end
  local r = tonumber(node.r) or 0
  local tl, th = tonumber(node.tl), tonumber(node.th)
  if tl and tl <= r then
    tl = nil
  end
  if th and th <= r then
    th = nil
  end
  if tl and th and th > tl then
    return string.format(Pane.WORDS.windowBoth, tl, th)
  end
  if tl then
    return string.format(Pane.WORDS.windowSure, tl)
  end
  if th then
    return string.format(Pane.WORDS.windowLikely, th)
  end
  return nil
end

--- Brief PR48: a smelt card's reagent line, "Copper Ore x1 -> Copper Bar" (each reagent and its
--- count, then what it makes). nil for a recipe with no reagents. Pure.
function Pane.MakesText(names, node)
  if type(node) ~= "table" or type(node.re) ~= "table" then
    return nil
  end
  local parts = {}
  for _, reagent in ipairs(node.re) do
    local itemId = type(reagent) == "table" and tonumber(reagent[1]) or nil
    if itemId then
      parts[#parts + 1] =
        string.format(Pane.WORDS.reagentPart, Pane.ItemName(names, itemId, false), tonumber(reagent[2]) or 1)
    end
  end
  if #parts == 0 then
    return nil
  end
  local text = table.concat(parts, ", ")
  if tonumber(node.out) then
    return string.format(Pane.WORDS.makes, text, Pane.ItemName(names, tonumber(node.out), false))
  end
  return text
end

--- Brief PR49b: a specialisation's name, through Core/Keep.lua Keep.RecipeName (the shipped
--- SpellNames), else the tracks' names table (-spellId), else nil. Pure over the data tables.
function Pane.SpecName(names, spell)
  spell = tonumber(spell)
  if not spell then
    return nil
  end
  local keep = ItemTree.Keep
  if type(keep) == "table" and type(keep.RecipeName) == "function" then
    local ok, name = pcall(keep.RecipeName, spell)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end
  local held = type(names) == "table" and names[-spell] or nil
  if type(held) == "string" and held ~= "" then
    return held
  end
  return nil
end

--- Brief PR49b: a cooldown reagent's card line, "needs 8 Mooncloth, about 32 days of cooldowns":
--- cd is the node's { item, per, days } (days a unit), crafts the card's crafts (one craft where
--- nil). Days are rounded up; a day or less says "about a day". nil without a cd. Pure.
function Pane.CooldownText(names, cd, crafts)
  if type(cd) ~= "table" or not tonumber(cd.item) then
    return nil
  end
  local count = (tonumber(crafts) or 1) * (tonumber(cd.per) or 1)
  local days = math.ceil(count * (tonumber(cd.days) or 0) - 1e-9)
  local name = Pane.ItemName(names, tonumber(cd.item), false)
  if days <= 1 then
    return string.format(Pane.WORDS.cooldownDay, count, name)
  end
  return string.format(Pane.WORDS.cooldown, count, name, days)
end

--- Brief PR49c: a recipe card's Changed badge sentence, "Goes grey at 275 (Classic Era 300)"
--- (PR49d wording), where the recipe goes grey (th) at another rank on Classic Era (cth); nil where they
--- agree, either is missing, or the node is a gathering spot. The badge's hover says exactly this.
--- Pure.
function Pane.GreyText(node)
  if type(node) ~= "table" or type(node.spot) == "table" then
    return nil
  end
  local th, cth = tonumber(node.th), tonumber(node.cth)
  if th and cth and cth ~= th then
    return string.format(Pane.WORDS.greyAt, th, cth)
  end
  return nil
end

--- Brief TB14 (owner QA 2026-10-05): the New mark a card wears, by the test the main window's rows
--- and tooltip use (Core/Diff.lua Diff.Badges, its New kinds through Diff.IsNewBadge): "new", or
--- "sod" for a Season of Discovery item (the same mark in purple, as the main window draws it), or
--- nil. A recipe card asks for its recipe (the spell, Diff kind "recipes") and then the item it
--- makes; a gathering card for its item; a zone or creature spot is never new. Pure over the data.
function Pane.NewKind(node)
  local Diff = ItemTree.Diff
  if type(node) ~= "table" or type(Diff) ~= "table" or type(Diff.Badges) ~= "function" then
    return nil
  end
  local asks
  if type(node.spot) == "table" then
    if node.spot.k ~= "item" then
      return nil
    end
    asks = { { "items", tonumber(node.spot.id) } }
  else
    asks = { { "recipes", tonumber(node.spell) }, { "items", tonumber(node.out) } }
  end
  for _, ask in ipairs(asks) do
    if ask[2] then
      local ok, kinds = pcall(Diff.Badges, ask[1], ask[2])
      for _, kind in ipairs(ok and type(kinds) == "table" and kinds or EMPTY) do
        local isNew = kind == "new" or kind == "sod"
        if type(Diff.IsNewBadge) == "function" then
          isNew = Diff.IsNewBadge(kind) == true
        end
        if isNew then
          return kind
        end
      end
    end
  end
  return nil
end

--- Brief TB14: the New badge's hover, the main window's heading and meaning for the kind
--- (UI/Badges.lua Title and Meaning): "New in Forever", then "Compared with Classic Era" muted.
--- Answers the title and the lines textTooltip draws. Pure.
function Pane.NewHover(kind)
  local Badges = ItemTree.Badges
  local title, meaning = nil, nil
  if type(Badges) == "table" and type(Badges.Title) == "function" and type(Badges.Meaning) == "function" then
    title, meaning = Badges.Title(kind), Badges.Meaning(kind)
  end
  title = type(title) == "string" and title or Pane.WORDS.newTitle
  meaning = type(meaning) == "string" and meaning or Pane.WORDS.newMeaning
  return title, { { text = meaning, colour = "ITEMTREE_COLOR_TEXT_MUTED", wrap = true } }
end

--- Brief PR49c: a card name's rect and its Changed badge's beside it, in the card's coordinates:
--- the name runs as wide as its words (textW, the full rect where the client will not measure),
--- never past the room the badge and its gap leave, and the badge sits the gap right of it,
--- centred on the name row. A narrow card truncates the name; the badge is never dropped. Pure.
--- Brief TB14: count badges (1 where nil) in a row, each the gap right of the one before: the name
--- leaves room for them all, and the answer is the name's rect then one rect per badge.
function Pane.NameBadgeRects(name, textW, size, gap, count)
  size = tonumber(size) or Pane.BADGE
  gap = tonumber(gap) or Pane.BADGE_GAP
  count = math.max(math.floor(tonumber(count) or 1), 1)
  local room = math.max((tonumber(name.w) or 0) - count * (size + gap), 0)
  local w = tonumber(textW)
  if not w or w > room then
    w = room
  end
  w = math.max(math.ceil(w), 0)
  local out = { x = name.x, y = name.y, w = w, h = name.h }
  local y = name.y + ((tonumber(name.h) or size) - size) / 2
  local badges = {}
  for index = 1, count do
    badges[index] = { x = name.x + w + gap + (index - 1) * (size + gap), y = y, w = size, h = size }
  end
  return out, unpack(badges)
end

--- Brief TB14: a gathering card's name row as a rect in the card's coordinates (w by h the card),
--- where its New badge has to stand beside it: right of the icon to the card's inset, one name row
--- high, sitting on the card's middle where a spot line is under it (worded), else centred. Pure.
function Pane.SpotNameRect(w, h, worded)
  local inset = Pane.CARD_INSET
  local textLeft = inset * 2 + Pane.NODE_ICON
  w, h = tonumber(w) or Pane.COL_W, tonumber(h) or Pane.SPOT_H
  local y = (h - Pane.NAME_H) / 2
  if worded then
    y = h / 2 - 1 - Pane.NAME_H
  end
  return { x = textLeft, y = y, w = math.max(w - inset - textLeft, 0), h = Pane.NAME_H }
end

--- Brief PR49b: the muted lines under a crafting card from the re-planned routes' fields, in the
--- brief's order where they apply: no points here (a route recipe grey at its band's start), how
--- the pattern is learnt (drop, vendor, reputation), the specialisation (spec), Season of
--- Discovery (sod), then the cooldown reagent's line (Pane.CooldownText, crafts the card's). An
--- older tracks file's node has none. Brief PR49c: the "Goes grey at" line left the body for the
--- Changed badge's hover beside the name (Pane.GreyText). Pure.
function Pane.RouteWords(names, node, crafts)
  local out = {}
  if type(node) ~= "table" or type(node.spot) == "table" then
    return out
  end
  if node.noPoints == true then
    out[#out + 1] = Pane.WORDS.noPoints
  end
  if node.learn == "drop" then
    out[#out + 1] = Pane.WORDS.learnDrop
  elseif node.learn == "vendor" then
    out[#out + 1] = Pane.WORDS.learnVendor
  elseif node.learn == "reputation" then
    out[#out + 1] = Pane.WORDS.learnReputation
  end
  if tonumber(node.spec) or node.learn == "spec" then
    local name = Pane.SpecName(names, node.spec)
    out[#out + 1] = name and string.format(Pane.WORDS.learnSpec, name) or Pane.WORDS.learnSpecAny
  end
  if node.sod == true then
    out[#out + 1] = Pane.WORDS.sod
  end
  local cooldown = Pane.CooldownText(names, node.cd, crafts)
  if cooldown then
    out[#out + 1] = cooldown
  end
  return out
end

--- Brief PR48: the muted lines under a gathering band's recipe card: its reagent line, then its
--- window (Pane.MakesText, Pane.WindowText), those it has. Brief PR49b: a crafting card's lines
--- from the re-planned routes' fields (Pane.RouteWords; crafts handed through). A gathering spot
--- has none. Pure.
function Pane.CardWords(names, node, crafts)
  local out = {}
  if type(node) ~= "table" then
    return out
  end
  if node.gatherCard ~= true then
    return Pane.RouteWords(names, node, crafts)
  end
  out[#out + 1] = Pane.MakesText(names, node)
  out[#out + 1] = Pane.WindowText(node)
  return out
end

--- Brief PR49b: a re-planned band's heading hover line, what the Classic guide used instead:
--- "Classic guides use Dense Sharpening Stone (grey here)" from band.was
--- (names joined "A, B and C"). nil for a band with no was. Pure.
function Pane.WasText(names, band)
  local was = type(band) == "table" and band.was or nil
  if type(was) ~= "table" or #was == 0 then
    return nil
  end
  local list = {}
  for _, spell in ipairs(was) do
    if tonumber(spell) then
      list[#list + 1] = Pane.NodeName(names, { spell = tonumber(spell) }, nil)
    end
  end
  if #list == 0 then
    return nil
  end
  local joined = list[#list]
  if #list > 1 then
    joined = string.format(Pane.WORDS.nameJoin, table.concat(list, ", ", 1, #list - 1), list[#list])
  end
  return string.format(#list == 1 and Pane.WORDS.wasOne or Pane.WORDS.wasMany, joined)
end

--- Brief PR49b: copper as "1g 20s" (Core/Keep.lua Keep.MoneyWords), else "<n>c". Pure.
function Pane.MoneyText(copper)
  copper = math.floor((tonumber(copper) or 0) + 0.5)
  local keep = ItemTree.Keep
  if type(keep) == "table" and type(keep.MoneyWords) == "function" then
    local ok, text = pcall(keep.MoneyWords, copper)
    if ok and type(text) == "string" then
      return text
    end
  end
  return copper .. "c"
end

--- Brief PR49b: a re-ranked card's hover line, its cost per expected point (Model.RouteCost):
--- "Cheapest at your auction prices: about 1g 20s a point" on the band's Recommended card,
--- "About 3g a point at your auction prices" on the others (PR49d wording). nil
--- without a priced cost. Pure.
function Pane.CostText(cost, best)
  if type(cost) ~= "table" or cost.priced ~= true or not tonumber(cost.perPoint) then
    return nil
  end
  local money = Pane.MoneyText(cost.perPoint)
  if best == true then
    return string.format(Pane.WORDS.costBest, money)
  end
  return string.format(Pane.WORDS.costPoint, money)
end

--- Brief PR49b: a card's hover lines from its route lines (muted) and its cost line (Pane.CostText,
--- best where the card is Recommended): { { text, colour } }, or nil where it has none. Pure.
function Pane.RouteHover(words, cost, best)
  local out = {}
  for _, text in ipairs(type(words) == "table" and words or EMPTY) do
    out[#out + 1] = { text = text, colour = Pane.MUTED_WORD }
  end
  local costLine = Pane.CostText(cost, best)
  if costLine then
    out[#out + 1] = { text = costLine, colour = Pane.NAME_WORD }
  end
  if #out == 0 then
    return nil
  end
  return out
end

--- Brief PR49b: a card's hover extras: the alone lines (Pane.AloneLines), then its route lines
--- (Pane.RouteHover). The alone lines themselves where there is nothing to add. Pure.
function Pane.HoverLines(alone, routeLines)
  if type(routeLines) ~= "table" or #routeLines == 0 then
    return alone
  end
  local out = {}
  for _, line in ipairs(type(alone) == "table" and alone or EMPTY) do
    out[#out + 1] = line
  end
  for _, line in ipairs(routeLines) do
    out[#out + 1] = line
  end
  return out
end

--- Brief PR49b: a band heading's hover lines under its title: the gathering suggestion (PR48),
--- the Classic steps gone grey here (Pane.WasText) and the re-rank's reason, those it has; nil
--- for none. Pure.
function Pane.HeaderLines(smelt, was, reranked)
  local out = {}
  for _, text in ipairs({ smelt or false, was or false, reranked or false }) do
    if type(text) == "string" and text ~= "" then
      out[#out + 1] = text
    end
  end
  if #out == 0 then
    return nil
  end
  return out
end

--- Brief PR49b: a re-planned band's live order applied to its Model.Track entry: costs is
--- { [spell] = Model.RouteCost }, for the band's pick, route and alt cards with points. Where
--- Model.Rerank moves them, the cheapest wears Recommended alone and they are drawn in that order
--- (where the first of them stood), every other card where it was; band.reranked says the order
--- changed. Every card with a priced cost keeps it (node.cost) for its hover, where an auction
--- addon answered any of the band's. The route, the
--- needs and the queue are untouched. Answers whether the order changed. Pure.
function Pane.ApplyRerank(band, costs)
  if type(band) ~= "table" or type(band.nodes) ~= "table" or type(costs) ~= "table" then
    return false
  end
  local entries, slots, auction = {}, {}, false
  for index, node in ipairs(band.nodes) do
    if type(node) == "table" and node.noPoints ~= true and (node.route == true or node.alt == true) then
      local cost = costs[node.spell]
      auction = auction or (type(cost) == "table" and cost.auction == true)
      entries[#entries + 1] = { spell = node.spell, cost = cost, node = node }
      slots[#slots + 1] = index
    end
  end
  -- Each priced card keeps its cost for its hover, where an auction addon answered in the band.
  for _, entry in ipairs(entries) do
    local cost = entry.cost
    entry.node.cost = auction and type(cost) == "table" and cost.priced == true and cost or nil
  end
  if #entries < 2 then
    return false
  end
  local model = ItemTree.ProfessionsModel
  if type(model) ~= "table" or type(model.Rerank) ~= "function" then
    return false
  end
  local order, changed = model.Rerank(entries)
  if not changed then
    return false
  end
  for index, entry in ipairs(order) do
    band.nodes[slots[index]] = entry.node
    entry.node.recommended = index == 1
  end
  band.reranked = true
  return true
end

--- Brief G1c (owner, 2026-10-06): a band's cards with the ones the player knows above the locked
--- ones. With keepRecommended, the Recommended cards (Layout's rule: node.recommended where the
--- model says, else on the route) come first whatever their lock; then the known cards; then the
--- locked ones (isLocked(node) true: Pane.LockState's "locked" or "future"), each group in the
--- order it came in, so a no points card stays last within its group. A new list; nodes is not
--- changed. Pure.
function Pane.KnownFirst(nodes, isLocked, keepRecommended)
  local first, known, locked = {}, {}, {}
  for _, node in ipairs(type(nodes) == "table" and nodes or EMPTY) do
    local recommended = false
    if keepRecommended == true and type(node) == "table" then
      if node.recommended ~= nil then
        recommended = node.recommended == true
      else
        recommended = node.route == true
      end
    end
    if recommended then
      first[#first + 1] = node
    elseif type(isLocked) == "function" and isLocked(node) == true then
      locked[#locked + 1] = node
    else
      known[#known + 1] = node
    end
  end
  for _, list in ipairs({ known, locked }) do
    for _, node in ipairs(list) do
      first[#first + 1] = node
    end
  end
  return first
end

local function sameOrder(a, b)
  if #a ~= #b then
    return false
  end
  for index = 1, #a do
    if a[index] ~= b[index] then
      return false
    end
  end
  return true
end

--- Brief PR48: what the layout is handed for a line. A gathering line with no recipe on any band
--- (older data, Herbalism) is the track itself. A gathering band with recipe nodes (Mining's
--- smelts) lays out as a view (kind "gatherCards"): brief G1c, its item spots as rows, then its
--- recipe cards (known above locked, Pane.KnownFirst), then its other spots (zones and the rest),
--- each card a copy marked gatherCard and held on screen however many spots the band has (the
--- layout keeps a node marked route; render takes the mark off once laid out, so no card is
--- Recommended and no arrow joins them). Brief G1c: a crafting line whose cards move under
--- Pane.KnownFirst (the Recommended first, then known, then locked) is a view of the same kind
--- with each band a copy holding the new order; else the track itself. isLocked(node) answers
--- whether a recipe card is locked (nil: none is). The track's own bands are never changed. Pure.
function Pane.LayoutTrack(track, isLocked)
  if type(track) ~= "table" or type(track.bands) ~= "table" then
    return track
  end
  if track.kind ~= "gather" then
    local view, moved = { kind = track.kind, max = track.max, bands = {} }, false
    for index, band in ipairs(track.bands) do
      view.bands[index] = band
      if type(band) == "table" and type(band.nodes) == "table" then
        local order = Pane.KnownFirst(band.nodes, isLocked, true)
        if not sameOrder(order, band.nodes) then
          local copy = {}
          for key, value in pairs(band) do
            copy[key] = value
          end
          copy.nodes = order
          view.bands[index] = copy
          moved = true
        end
      end
    end
    if not moved then
      return track
    end
    for key, value in pairs(track) do
      if view[key] == nil then
        view[key] = value
      end
    end
    return view
  end
  local any = false
  for _, band in ipairs(track.bands) do
    if type(band) == "table" and type(band.nodes) == "table" and #band.nodes > 0 then
      any = true
      break
    end
  end
  if not any then
    return track
  end
  local view = { kind = "gatherCards", max = track.max, bands = {} }
  for index, band in ipairs(track.bands) do
    local copy = {}
    for key, value in pairs(band) do
      copy[key] = value
    end
    local items, places = {}, {}
    for _, spot in ipairs(type(band.spots) == "table" and band.spots or EMPTY) do
      if type(spot) == "table" then
        local list = spot.k == "item" and items or places
        list[#list + 1] = { spot = spot, route = false }
      end
    end
    local cards = items
    for _, node in ipairs(Pane.KnownFirst(band.nodes, isLocked, false)) do
      if type(node) == "table" then
        local card = {}
        for key, value in pairs(node) do
          card[key] = value
        end
        card.route, card.gatherCard = true, true
        cards[#cards + 1] = card
      end
    end
    for _, place in ipairs(places) do
      cards[#cards + 1] = place
    end
    copy.nodes = cards
    view.bands[index] = copy
  end
  return view
end

--- Brief PR48: a laid out gathering view made plain again: no card on the route and no arrows.
--- Answers the layout. Pure.
function Pane.SettleGatherLayout(layout)
  if type(layout) ~= "table" then
    return layout
  end
  for _, column in ipairs(type(layout.columns) == "table" and layout.columns or EMPTY) do
    for _, rect in ipairs(type(column.nodes) == "table" and column.nodes or EMPTY) do
      if type(rect.node) == "table" and rect.node.gatherCard == true then
        rect.route, rect.recommended = false, false
        rect.node.route = false
      end
    end
  end
  layout.links = {}
  return layout
end

--- Brief PR13: the difficulty mark for a recipe colour: { key, text, colour, grey, lock }, or
--- nil. Pure.
function Pane.DifficultyFor(colour)
  return Pane.DIFFICULTY[colour]
end

--- The border a node's reagents wear: the route gold and its thickness for a route node, the plain
--- hairline for every other. Pure.
function Pane.BorderFor(isRoute)
  if isRoute == true then
    return Pane.ROUTE_GOLD, Pane.ROUTE_BORDER
  end
  return Pane.PLAIN_BORDER, Pane.HAIRLINE
end

--- How many reagents fit on one row of a card w wide. Pure.
function Pane.PerRow(w)
  local textLeft = Pane.CARD_INSET * 2 + Pane.NODE_ICON
  local room = (tonumber(w) or Pane.COL_W) - textLeft - Pane.CARD_INSET + 4
  return math.max(math.floor(room / Pane.REAGENT_W), 1)
end

--- Brief PR13: where everything on a recipe card sits, in the card's own coordinates (y down
--- from its top left): { h, icon, name, difficulty, tag (route cards only), reagents = { { icon,
--- count } } }. The name runs to the difficulty mark; the reagents start under the name and wrap
--- to a further row past PerRow; the Recommended tag straddles the top edge at the left (brief
--- PR17), its bottom TAG_IN px inside, above the icon's, the name's and the mark's top. None of
--- them meet. Pure.
function Pane.CardRects(count, w, isRoute, tagW)
  w = tonumber(w) or Pane.COL_W
  count = math.max(math.min(tonumber(count) or 0, Pane.REAGENT_MAX), 0)
  local inset = Pane.CARD_INSET
  local textLeft = inset * 2 + Pane.NODE_ICON
  local out = {
    icon = { x = inset, y = inset, w = Pane.NODE_ICON, h = Pane.NODE_ICON },
    difficulty = { x = w - inset - Pane.DIFF_W, y = inset, w = Pane.DIFF_W, h = Pane.DIFF_H },
    reagents = {},
  }
  out.name = { x = textLeft, y = inset, w = out.difficulty.x - 4 - textLeft, h = Pane.NAME_H }
  local perRow = Pane.PerRow(w)
  local top = inset + Pane.NAME_H + 4
  local rows = math.max(math.ceil(count / perRow), 1)
  for index = 1, count do
    local row = math.floor((index - 1) / perRow)
    local col = (index - 1) % perRow
    local x = textLeft + col * Pane.REAGENT_W
    local y = top + row * (Pane.REAGENT + Pane.REAGENT_ROW_GAP)
    out.reagents[index] = {
      icon = { x = x, y = y, w = Pane.REAGENT, h = Pane.REAGENT },
      count = { x = x + Pane.REAGENT + 2, y = y, w = Pane.COUNT_W, h = Pane.REAGENT },
    }
  end
  out.h = top + rows * Pane.REAGENT + (rows - 1) * Pane.REAGENT_ROW_GAP + inset
  if out.h < Pane.NODE_H then
    out.h = Pane.NODE_H
  end
  if isRoute == true then
    tagW = tonumber(tagW) or Pane.TagWidth(Pane.WORDS.recommended)
    out.tag = { x = Pane.TAG_LEFT, y = Pane.TAG_IN - Pane.TAG_H, w = tagW, h = Pane.TAG_H }
  end
  return out
end

--- The Recommended tag's width for its words, where the client will not measure them. Pure.
function Pane.TagWidth(text)
  return math.floor(#tostring(text or "") * Pane.TAG_CHAR_W + Pane.TAG_PAD + 0.5)
end

--- Whether two rects meet. Pure.
function Pane.Overlaps(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return false
  end
  return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

--- Brief LF1 (QA item 239b): whether a node's card carries the Show craft row: a recipe card (one
--- with a spell; never a gathering spot), the cards UI\Pane.lua fillShow draws the button on. Pure.
function Pane.HasShowRow(node)
  return type(node) == "table" and type(node.spot) ~= "table" and tonumber(node.spell) ~= nil
end

--- A node's height on the canvas: a gathering spot's fixed row, else its card's. Pure.
function Pane.NodeHeight(node)
  if type(node) ~= "table" then
    return Pane.NODE_H
  end
  if type(node.spot) == "table" then
    return Pane.SPOT_H
  end
  local count = type(node.re) == "table" and #node.re or 0
  local h = Pane.CardRects(count, Pane.COL_W, node.recommended ~= false and node.route == true).h
  -- Brief PR48: a gathering band's recipe card adds its muted word lines under the reagents.
  -- Brief PR49b: and a crafting card its route lines (Pane.RouteWords).
  local words = math.min(#Pane.CardWords(nil, node), Pane.WORD_LINES)
  if words > 0 then
    h = h + Pane.WORD_GAP + words * Pane.WORD_LINE_H
  end
  -- Brief LF1 (QA item 239b): and a recipe card its Show craft row, at the foot.
  if Pane.HasShowRow(node) then
    h = h + Pane.SHOW_ROOM
  end
  return h
end

--- A card reagent's words: have/need, then one craft's count in brackets, "7/274 (3)", "(1)"
--- included. Pure.
function Pane.ReagentText(have, need, per)
  return string.format(Pane.WORDS.reagentCount, tonumber(have) or 0, tonumber(need) or 0, tonumber(per) or 1)
end

--- Brief PR37 (the owner, 2026-10-02): how many more of a reagent ONE craft needs: per less have
--- where have is below per, else nil. Brief PRX (PR43, the owner 2026-10-04): the same rule on every
--- card whatever its band (it was the player's own band only, so one recipe Recommended in two bands
--- drew the same missing reagent red on one card and white on the other). Pure.
function Pane.ReagentShort(have, per)
  have = tonumber(have) or 0
  per = tonumber(per) or 1
  if have < per then
    return per - have
  end
  return nil
end

--- Brief PR37: the colour a card reagent's "have/need (N)" words draw in: the warning red where
--- it is short for one craft (Pane.ReagentShort), else the card's own word colour, on every card
--- (brief PRX, PR43). Pure.
function Pane.ReagentColour(short)
  if tonumber(short) and tonumber(short) > 0 then
    return Pane.SHORT_WORD
  end
  return Pane.NAME_WORD
end

--- Brief PRX (PR44): a card reagent's need: the crafts x one craft's count, where crafts is the
--- plan's (Model.PlanCrafts) on its band's plan pick, and brief PR46 the recipe's own crafts alone
--- in its band (Model.AloneCrafts) on an alternative, the figure its hover explains; the route-wide
--- need is the tooltip's Keep line (Model.RouteNeed). nil for no crafts (a done band, any other
--- recipe): that card shows one craft's count. Pure.
function Pane.CardNeed(planCrafts, per)
  planCrafts = tonumber(planCrafts)
  if not planCrafts or planCrafts <= 0 then
    return nil
  end
  return planCrafts * (tonumber(per) or 1)
end

--- Brief PRX (PR44): an alternative's hover lines, the "alone" figure: "On its own, 8 crafts to
--- reach 40:", then each reagent "8 x Peacebloom" (crafts x one craft's count). crafts is
--- Model.Crafts for the recipe alone from max(rank, lo) to hi. Answers nil where crafts is not above
--- 0 (a done band, a grey recipe). Each line is { text, colour }. Pure.
function Pane.AloneLines(names, node, crafts, hi)
  crafts = tonumber(crafts)
  if type(node) ~= "table" or not crafts or crafts <= 0 then
    return nil
  end
  local lines = { { text = string.format(Pane.WORDS.aloneHead, crafts, tonumber(hi) or 0), colour = Pane.NAME_WORD } }
  for _, reagent in ipairs(type(node.re) == "table" and node.re or EMPTY) do
    local itemId = type(reagent) == "table" and tonumber(reagent[1]) or nil
    if itemId then
      local n = crafts * (tonumber(reagent[2]) or 1)
      local name = Pane.ItemName(names, itemId, false)
      lines[#lines + 1] = { text = string.format(Pane.WORDS.aloneItem, n, name), colour = Pane.MUTED_WORD }
    end
  end
  return lines
end

--- Brief PR37: a short reagent's hover line, "2 more for one craft". Pure.
function Pane.ShortText(short)
  return string.format(Pane.WORDS.shortForOne, tonumber(short) or 0)
end

--- Brief PR37: the Map view's key (Edges.MAP), "map" where Core has not said. Pure.
function Pane.MapView()
  local found = type(ItemTree.Edges) == "table" and ItemTree.Edges.MAP or nil
  if type(found) == "string" then
    return found
  end
  return "map"
end

--- Brief PR37 (the owner, 2026-10-02): what a click on a gathering line's zone spot hands the
--- window's open (UI\Frame.lua Frame.Open): the zone's Map tab, the line's groups
--- (Pane.GATHER_GROUPS) and pick first, { view, zoneGroups, pickFirst = true }. nil for anything
--- that is not a zone key, or a line with no group of its own, which opens as it always has. The
--- window keeps its own fallback: a zone that holds none of the groups opens as it always has. Pure.
function Pane.ZoneOpenOpts(line, key)
  if type(key) ~= "string" or not key:match("^zone:%d+$") then
    return nil
  end
  local groups = Pane.GATHER_GROUPS[tonumber(line) or 0]
  if type(groups) ~= "table" then
    return nil
  end
  local copy = {}
  for index, id in ipairs(groups) do
    copy[index] = id
  end
  return { view = Pane.MapView(), zoneGroups = copy, pickFirst = true }
end

--- The owner, 2026-10-02: where a click on a LOCKED card goes, to learn the recipe rather than see
--- the item. The recipe's own page on its Sources view where our data has it (hasRecipe: its
--- teaching items and trainers are listed there), else its first teaching item (by, the pattern
--- or recipe item) on Sources, else the Trainers & vendors panel. Answers { key = ... } or
--- { trainers = true }. Pure.
function Pane.LearnTarget(spell, by, hasRecipe)
  spell = tonumber(spell)
  if spell and hasRecipe == true then
    return { key = "spell:" .. spell }
  end
  local teacher = type(by) == "table" and tonumber(by[1]) or tonumber(by)
  if teacher then
    return { key = "item:" .. teacher }
  end
  return { trainers = true }
end

--- Whether a card's lock (Pane.LockState) is one of the two locks. Pure.
function Pane.IsLocked(lock)
  return lock == "locked" or lock == "future"
end

--- The name an item id goes by: the data's names table, else "Undiscovered item" where the
--- client withholds it, else "Item 1234". Pure.
function Pane.ItemName(names, itemId, undiscovered)
  local name = type(names) == "table" and names[itemId] or nil
  if type(name) == "string" and name ~= "" then
    return name
  end
  if undiscovered == true then
    return Pane.WORDS.undiscovered
  end
  return string.format(Pane.WORDS.item, tonumber(itemId) or 0)
end

--- The name a recipe node is drawn with: the recipe's own name (the names table keys spells by
--- negative id), else what it makes, else "Spell 1234". isUndiscovered(itemId) answers whether
--- the client withholds an item. Pure.
function Pane.NodeName(names, node, isUndiscovered)
  if type(node) ~= "table" then
    return nil
  end
  names = type(names) == "table" and names or EMPTY
  local spell = tonumber(node.spell)
  local own = spell and names[-spell] or nil
  if type(own) == "string" and own ~= "" then
    return own
  end
  if node.out then
    local undiscovered = type(isUndiscovered) == "function" and isUndiscovered(node.out) == true
    return Pane.ItemName(names, node.out, undiscovered)
  end
  return string.format(Pane.WORDS.spell, spell or 0)
end

--- The name a gathering spot is drawn with. zoneName and otherName are what the client or our
--- data say for a zone, a node or a creature, if anything. Pure.
function Pane.SpotName(names, spot, zoneName, otherName)
  if type(spot) ~= "table" then
    return nil
  end
  local id = tonumber(spot.id) or 0
  if spot.k == "item" then
    return Pane.ItemName(names, id, false)
  end
  if type(otherName) == "string" and otherName ~= "" then
    return otherName
  end
  if spot.k == "zone" then
    if type(zoneName) == "string" and zoneName ~= "" then
      return zoneName
    end
    return string.format(Pane.WORDS.zone, id)
  end
  if spot.k == "creature" then
    return string.format(Pane.WORDS.creature, id)
  end
  return Pane.WORDS.object .. " " .. tostring(id)
end

--- The page a node opens: its item, else its recipe; a spot's item or its zone page (brief PR13);
--- nil for anything else (a creature or a node spot has no page of ours). Pure.
function Pane.NodeKey(node)
  if type(node) ~= "table" then
    return nil
  end
  if type(node.spot) == "table" then
    local id = tonumber(node.spot.id)
    if node.spot.k == "item" and id then
      return "item:" .. id
    end
    if node.spot.k == "zone" and id and id > 0 then
      return "zone:" .. id
    end
    return nil
  end
  if tonumber(node.out) then
    return "item:" .. tonumber(node.out)
  end
  if tonumber(node.spell) then
    return "spell:" .. tonumber(node.spell)
  end
  return nil
end

--- Brief BQ24 (owner QA 2026-10-10 item 35): whether a profession's row wears the red gem: its
--- rank at its cap with a further rank to train, a band of its route ending above the cap or a cap
--- below the last (Core/Skills.lua Skills.CanTrainFurther). bands is the route's. Pure.
function Pane.Trainable(rank, max, bands)
  local Skills = ItemTree.Skills
  if type(Skills) ~= "table" or type(Skills.CanTrainFurther) ~= "function" then
    return false
  end
  local top = nil
  for _, band in ipairs(type(bands) == "table" and bands or EMPTY) do
    local hi = type(band) == "table" and tonumber(band.hi) or nil
    if hi and (top == nil or hi > top) then
      top = hi
    end
  end
  return Skills.CanTrainFurther(rank, max, top) == true
end

--- Brief BQ24: the hover lines of a row's red gem: "Skinning can be levelled up", and under it,
--- muted, the nearest trainer's line where one is known (nearest, Core/Nearest.lua's result text).
--- Each { text, colour }. Pure.
function Pane.TrainableLines(row, nearest)
  if type(row) ~= "table" or not row.trainable then
    return nil
  end
  local lines = { { text = string.format(L["%s can be levelled up"], tostring(row.name or "")) } }
  if type(nearest) == "string" and nearest ~= "" then
    lines[2] = { text = nearest, colour = Pane.MUTED_WORD }
  end
  return lines
end

--- The strip's rows: every profession the player has that the data holds or that ItemTree draws a
--- glyph for, by name. skills is Frame.PlayerSkills()'s answer, glyphs Assets.skillGlyphs, and
--- nameOf(line) the line's name. Each row: { line, rank, max, name, hasRoute, specialisations }.
--- Brief TP1: a tracked profession (its skill marked tracked, the model's Facts) is not one the
--- player has: UI\Track.lua draws those under these rows. Pure.
function Pane.StripRows(tracks, skills, glyphs, nameOf)
  local lines = type(tracks) == "table" and type(tracks.lines) == "table" and tracks.lines or EMPTY
  glyphs = type(glyphs) == "table" and glyphs or EMPTY
  local rows = {}
  for line, skill in pairs(type(skills) == "table" and skills or EMPTY) do
    local own = type(skill) == "table" and skill.tracked ~= true
    if type(line) == "number" and own and (lines[line] ~= nil or glyphs[line] ~= nil) then
      local data = lines[line]
      local bands = type(data) == "table" and type(data.bands) == "table" and data.bands or EMPTY
      local name = type(nameOf) == "function" and nameOf(line) or nil
      rows[#rows + 1] = {
        line = line,
        rank = tonumber(skill.rank) or 0,
        max = tonumber(skill.max) or (type(data) == "table" and tonumber(data.max)) or nil,
        name = (type(name) == "string" and name ~= "") and name or (Pane.WORDS.profession .. " " .. line),
        hasRoute = #bands > 0,
        specialisations = type(skill.specialisations) == "table" and skill.specialisations or nil,
        -- Brief BQ24 (QA item 35): at its cap with a further rank to train (the red gem).
        trainable = Pane.Trainable(skill.rank, skill.max, bands),
      }
    end
  end
  table.sort(rows, function(a, b)
    if a.name ~= b.name then
      return a.name < b.name
    end
    return a.line < b.line
  end)
  return rows
end

--- "120/300", or the rank alone with no max. Pure.
function Pane.RankText(row)
  if type(row) ~= "table" then
    return ""
  end
  if row.max then
    return string.format("%d/%d", row.rank or 0, row.max)
  end
  return tostring(row.rank or 0)
end

--- The line to show: the one remembered if the player still has it, else the first with a
--- route, else the first. nil with no rows. Pure.
function Pane.Pick(rows, remembered)
  rows = type(rows) == "table" and rows or EMPTY
  for _, row in ipairs(rows) do
    if row.line == remembered then
      return row
    end
  end
  for _, row in ipairs(rows) do
    if row.hasRoute then
      return row
    end
  end
  return rows[1]
end

--- The pan, held inside the content at a zoom: the top left edge where the scaled content fits on
--- that axis, else no further than the far edge. Viewport pixels; the pan is where the canvas's
--- top left sits, so it runs from 0 down to viewport minus content. Pure.
function Pane.ClampPan(panX, panY, contentW, contentH, viewportW, viewportH, zoom)
  zoom = tonumber(zoom) or 1
  if zoom <= 0 then
    zoom = 1
  end
  local function axis(pan, content, view)
    pan, content, view = tonumber(pan) or 0, (tonumber(content) or 0) * zoom, tonumber(view) or 0
    if content <= view then
      return 0
    end
    if pan > 0 then
      return 0
    end
    if pan < view - content then
      return view - content
    end
    return pan
  end
  return axis(panX, contentW, viewportW), axis(panY, contentH, viewportH)
end

--- The owner's view rule (brief PR15, 2026-10-01): a line's default view is the natural zoom (1,
--- Reset's), panned so the band holding the player's rank (layout.current, Layout.CurrentIndex) is
--- centred across the viewport, with the top of the columns in view. A rank below the first band (a
--- brand new line) centres the first band; a rank at or past the last band's top (300), or any
--- other rank no band holds, centres the last. Answers zoom, panX, panY, clamped. Pure.
function Pane.DefaultView(layout, rank, viewportW, viewportH)
  local zoom = 1
  local columns = type(layout) == "table" and type(layout.columns) == "table" and layout.columns or EMPTY
  if #columns == 0 then
    return zoom, 0, 0
  end
  local index = tonumber(layout.current)
  if not index or not columns[index] then
    local first = columns[1]
    local firstLo = tonumber(first.band and first.band.lo) or 0
    rank = tonumber(rank) or 0
    if rank <= 0 or rank < firstLo then
      index = 1
    else
      index = #columns
    end
  end
  local column = columns[index]
  local centre = (tonumber(column.x) or 0) + (tonumber(column.w) or 0) / 2
  viewportW, viewportH = tonumber(viewportW) or 0, tonumber(viewportH) or 0
  local panX, panY =
    Pane.ClampPan(viewportW / 2 - centre * zoom, 0, layout.width, layout.height, viewportW, viewportH, zoom)
  return zoom, panX, panY
end

--- Whether a rect on the canvas shows in the viewport at this pan and zoom. Pure.
function Pane.Visible(rect, panX, panY, viewportW, viewportH, zoom)
  viewportW, viewportH = tonumber(viewportW) or 0, tonumber(viewportH) or 0
  zoom = tonumber(zoom) or 1
  if type(rect) ~= "table" or viewportW <= 0 or viewportH <= 0 then
    return false
  end
  local left, top = (panX or 0) + rect.x * zoom, (panY or 0) + rect.y * zoom
  return left + rect.w * zoom > 0 and left < viewportW and top + rect.h * zoom > 0 and top < viewportH
end

--- Whether a press has moved far enough to be a pan. Pure.
function Pane.PastThreshold(dx, dy, threshold)
  dx, dy = tonumber(dx) or 0, tonumber(dy) or 0
  threshold = tonumber(threshold) or Pane.DRAG_THRESHOLD
  return dx * dx + dy * dy > threshold * threshold
end

--- A zoom stepped by a factor, held to the pane's floor and ceiling. Pure.
function Pane.StepZoom(zoom, factor)
  local value = (tonumber(zoom) or 1) * (tonumber(factor) or 1)
  if value < Pane.ZOOM_MIN then
    return Pane.ZOOM_MIN
  end
  if value > Pane.ZOOM_MAX then
    return Pane.ZOOM_MAX
  end
  return value
end

--- Brief LF1 (QA item 240c): the Shift keycap's width for its word's (wordW, the client's measure):
--- the word with HINT_KEY_PAD each side, never under HINT_KEY_W. Pure.
function Pane.HintKeyWidth(wordW)
  return math.max(math.ceil((tonumber(wordW) or 0) + Pane.HINT_KEY_PAD * 2), Pane.HINT_KEY_W)
end

--- Brief LF1: the input picture's width for one hotkey (an entry of Pane.HINTS): the mouse alone,
--- or the keycap (keyW), the "+" (plusW) and the mouse, HINT_JOIN_GAP apart. Pure.
function Pane.HintArtWidth(hint, keyW, plusW)
  if type(hint) == "table" and hint.key then
    return (tonumber(keyW) or Pane.HINT_KEY_W)
      + Pane.HINT_JOIN_GAP
      + (tonumber(plusW) or 0)
      + Pane.HINT_JOIN_GAP
      + Pane.HINT_MOUSE_W
  end
  return Pane.HINT_MOUSE_W
end

--- Brief LF1: the floating hint panel's layout, from each cell's { art (the picture's width), word
--- (the word's width) }: { w, h, cells = { { x, w } }, dividers = { x } }, x from the panel's left.
--- A cell holds the wider of its picture and its icon, gap and word, HINT_PAD_X each side, never
--- narrower than HINT_CELL_MIN; a 1 px divider stands between two cells. Pure.
function Pane.HintLayout(cells)
  local out = {
    cells = {},
    dividers = {},
    h = Pane.HINT_PAD_Y * 2 + Pane.HINT_ART_H + Pane.HINT_ROW_GAP + Pane.HINT_LINE_H,
  }
  local x = 0
  for index, cell in ipairs(type(cells) == "table" and cells or EMPTY) do
    if index > 1 then
      out.dividers[#out.dividers + 1] = x
      x = x + Pane.HAIRLINE
    end
    local label = Pane.HINT_ICON + Pane.HINT_ICON_GAP + math.max(tonumber(cell.word) or 0, 0)
    local content = math.max(tonumber(cell.art) or 0, label)
    local w = math.max(math.ceil(content + Pane.HINT_PAD_X * 2), Pane.HINT_CELL_MIN)
    out.cells[index] = { x = x, w = w }
    x = x + w
  end
  out.w = x
  return out
end

--- Brief LF1: the room the pan keeps clear under the route's foot for a hint panel h px tall: the
--- panel, its HINT_MARGIN under it and HINT_CLEAR over it; 0 where no panel shows (h nil). Pure.
function Pane.HintReserve(h)
  h = tonumber(h)
  if not h or h <= 0 then
    return 0
  end
  return h + Pane.HINT_MARGIN + Pane.HINT_CLEAR
end

--- Brief LF1: the viewport height the pan and the Shift + wheel scroll hold the route inside: the
--- view less the hint panel's room (Pane.HintReserve), never under 0. Pure.
function Pane.PanHeight(viewportH, reserve)
  return math.max((tonumber(viewportH) or 0) - (tonumber(reserve) or 0), 0)
end

--- Brief UI15: which way a Shift + wheel notch scrolls at this zoom: "y" (up and down) where the
--- scaled content is taller than the viewport, else "x" (sideways) where it is wider, else nil (it
--- all shows, and the notch moves nothing). Pure.
function Pane.ScrollAxis(contentW, contentH, viewportW, viewportH, zoom)
  zoom = tonumber(zoom) or 1
  if zoom <= 0 then
    zoom = 1
  end
  local function over(content, view)
    return (tonumber(content) or 0) * zoom > (tonumber(view) or 0) + 0.5
  end
  if over(contentH, viewportH) then
    return "y"
  end
  if over(contentW, viewportW) then
    return "x"
  end
  return nil
end

--- Brief UI15: the pan after one Shift + wheel notch on an axis. The wheel turned up (delta above 0)
--- shows what is above (or to the left), so the canvas moves down (or right) step viewport px a
--- notch; down the other way. Unheld: Pane.SetPan keeps it inside the content. Pure.
function Pane.ScrollPan(panX, panY, delta, axis, step)
  panX, panY = tonumber(panX) or 0, tonumber(panY) or 0
  local move = (tonumber(delta) or 0) * (tonumber(step) or Pane.SCROLL_STEP)
  if axis == "y" then
    return panX, panY + move
  end
  if axis == "x" then
    return panX + move, panY
  end
  return panX, panY
end

--- Brief UI15: whether the pointer wears the pan cursor: while a press pans (it has moved past the
--- threshold, or it began on bare canvas, which pans from its first pixel), else while it is over
--- bare canvas (the viewport itself: no card, reagent, header or button under it). Pure.
function Pane.WantsPanCursor(overCanvas, press)
  if type(press) == "table" and (press.dragging == true or press.immediate == true) then
    return true
  end
  return overCanvas == true
end

-- Brief PR13: the zoom arithmetic is the chain tab's own (UI/Chain.lua); this copy is only what a
-- build without the chain tab falls back on.
local LOCAL_HELPERS = {
  ZoomAbout = function(zoom, newZoom, pointer, pan)
    zoom, newZoom = tonumber(zoom) or 1, tonumber(newZoom) or 1
    pointer, pan = tonumber(pointer) or 0, tonumber(pan) or 0
    if zoom <= 0 then
      return pan
    end
    return pointer - (pointer - pan) * (newZoom / zoom)
  end,
  ViewportPoint = function(cursorX, cursorY, left, top, scale)
    cursorX, cursorY, left, top = tonumber(cursorX), tonumber(cursorY), tonumber(left), tonumber(top)
    scale = tonumber(scale) or 1
    if not (cursorX and cursorY and left and top) or scale <= 0 then
      return nil
    end
    return cursorX / scale - left, top - cursorY / scale
  end,
  ZoomText = function(zoom)
    return string.format("%d%%", math.floor((tonumber(zoom) or 1) * 100 + 0.5))
  end,
}

--- The chain tab's helper of that name where the chain tab is loaded, else the pane's own copy.
function Pane.Helper(name)
  local ui = ItemTree.UI
  local chain = type(ui) == "table" and ui.Chain or nil
  if type(chain) == "table" and type(chain[name]) == "function" then
    return chain[name]
  end
  return LOCAL_HELPERS[name]
end

--- Brief PR16: the card's own look: { fill, edge, thickness } as Theme keys and px, for a
--- recommended card (gold), any other card, the player's own band's header (gold) and any other
--- header (the warmer strip). Brief PR17: a card the player cannot learn yet ("locked") is red
--- tinted with a red edge, and a recommended one ("routeLocked") keeps the red fill with its gold
--- edge tinted toward orange red. Pure.
function Pane.CardStyle(kind)
  if kind == "route" then
    return { fill = Pane.CARD_FILL, edge = Pane.CARD_GOLD, thickness = Pane.ROUTE_BORDER }
  end
  if kind == "routeLocked" then
    return { fill = Pane.LOCKED_FILL, edge = Pane.LOCKED_GOLD, thickness = Pane.ROUTE_BORDER }
  end
  if kind == "locked" then
    return { fill = Pane.LOCKED_FILL, edge = Pane.LOCKED_EDGE, thickness = Pane.HAIRLINE }
  end
  if kind == "current" then
    return { fill = Pane.HEADER_FILL, edge = Pane.ROUTE_GOLD, thickness = Pane.ROUTE_BORDER }
  end
  if kind == "header" then
    return { fill = Pane.HEADER_FILL, edge = Pane.HEADER_EDGE, thickness = Pane.HAIRLINE }
  end
  return { fill = Pane.CARD_FILL, edge = Pane.CARD_EDGE, thickness = Pane.HAIRLINE }
end

--- Brief PR19 (the owner, QA round 4): a recipe's lock at the player's rank, from its colour (the
--- model's, "unlearnable" where the rank is below its r) and whether the player has learnt it
--- (true, false, or nil where nothing the client holds can say; Craft's open window rule):
---   "future"   r above the rank: not learnable yet, out of range. Brief PR21: the red locked
---              card AND dimmed whole (Pane.CardKind, Pane.CardAlpha).
---   "locked"   r at or below the rank but not learnt: the red locked card, not dimmed.
---   nil        learnt, or unknown: drawn as normal.
--- Both carry the padlock. Brief PR24: Core\Craft.lua's Craft.LockState is THE rule, shared with
--- everything Create all queues, so the tab and the queue never disagree; this copy stands in only
--- where that file has not loaded. Pure.
function Pane.LockState(colour, learnt)
  local craft = type(ItemTree) == "table" and rawget(ItemTree, "ProfessionsCraft") or nil
  if type(craft) == "table" and type(craft.LockState) == "function" then
    return craft.LockState(colour, learnt)
  end
  if colour == "unlearnable" then
    return "future"
  end
  if colour ~= nil and learnt == false then
    return "locked"
  end
  return nil
end

--- Brief PR17: a recipe card's kind for Pane.CardStyle, by whether it is recommended and its lock
--- (Pane.LockState): "routeLocked", "route", "locked" or "card". Brief PR21 (the owner: "We lost
--- the red for the locked state"), correcting PR19: both locks are red, the out of range one
--- ("future") dimmed as well by Pane.CardAlpha; a Recommended locked card keeps the orange-gold
--- edge on the red. Pure.
function Pane.CardKind(isRoute, lock)
  local locked = lock == "locked" or lock == "future"
  if isRoute == true then
    return locked and "routeLocked" or "route"
  end
  return locked and "locked" or "card"
end

--- Brief PR17 (the owner, QA round 3): how opaque a card draws. A grey recipe (the player's rank
--- at or past its grey level) draws at GREY_ALPHA, a card in a done band at DONE_ALPHA, the lower
--- where both hold, and every other card at full strength. Brief PR19: a recipe above the rank
--- ("unlearnable", lock "future") at FUTURE_ALPHA. Brief PR37 (the owner, 2026-10-02): every card
--- of the band the player's rank is in (current true) draws at full strength, whatever its colour
--- or lock: a locked card is still the red card with its padlock, a grey one keeps its grey arrow.
--- The one alpha the card's frame takes; the card keeps every interaction. Pure.
function Pane.CardAlpha(colour, done, current)
  if current == true then
    return 1
  end
  local alpha = 1
  if done == true then
    alpha = Pane.DONE_ALPHA
  end
  if colour == "grey" and Pane.GREY_ALPHA < alpha then
    alpha = Pane.GREY_ALPHA
  end
  if colour == "unlearnable" and Pane.FUTURE_ALPHA < alpha then
    alpha = Pane.FUTURE_ALPHA
  end
  return alpha
end

--- Brief PR19: the Create all button's own alpha inside its header: faded where it cannot craft,
--- but never on top of a faded header (a done band), which already fades it with everything else
--- on the header. Pure.
function Pane.CraftAlpha(enabled, headerAlpha)
  if (tonumber(headerAlpha) or 1) < 1 then
    return 1
  end
  if enabled == true then
    return 1
  end
  return Pane.CRAFT_FADED
end

--- The Craft all hover's lines under its title (the owner, 2026-10-02): what it does, one wrapped
--- paragraph in the tooltip's own colour, then a blank line and the state's one status line
--- (Craft.State's status, { text, colour } with colour a Theme key), coloured by state. Each line is
--- { text, colour (a Theme key or nil), wrap }. Pure.
function Pane.CraftTooltipLines(state)
  local lines = { { text = Pane.WORDS.craftHow, wrap = true } }
  -- Brief SC1 (QA item 212): then, where the band has them, that the recipes making no item
  -- (enchants) are left out (Craft.State's note), its own wrapped paragraph.
  local note = type(state) == "table" and state.note or nil
  if note ~= nil and tostring(note) ~= "" then
    lines[#lines + 1] = { text = " " }
    lines[#lines + 1] = { text = tostring(note), wrap = true }
  end
  local status = type(state) == "table" and state.status or nil
  if type(status) == "table" and status.text ~= nil and tostring(status.text) ~= "" then
    lines[#lines + 1] = { text = " " }
    lines[#lines + 1] = { text = tostring(status.text), colour = status.colour }
  end
  return lines
end

--- Brief SC1 (QA item 212): where a card's Show craft button sits, in the card's own coordinates
--- (y down from its top left), for a card w by h (Pane.NodeHeight's, its Show craft row included)
--- and a button bw wide (SHOW_W where nil). Brief LF1 (QA item 239b): inside the card, its right
--- edge SHOW_RIGHT in from the card's and its bottom SHOW_BOTTOM above the card's bottom edge, in
--- the SHOW_ROOM the card grew by, so it never crosses the edge. { x, y, w, h }. Pure.
function Pane.ShowRect(w, h, bw)
  w, h = tonumber(w) or Pane.COL_W, tonumber(h) or Pane.NODE_H
  bw = tonumber(bw) or Pane.SHOW_W
  return { x = w - Pane.SHOW_RIGHT - bw, y = h - Pane.SHOW_BOTTOM - Pane.SHOW_H, w = bw, h = Pane.SHOW_H }
end

--- Brief SC5 (QA items 284 and 289): the Show craft label's font size for words tw px wide on a button
--- bw px wide (sized for "Show craft"): FONT_SM where they fit between the label's SHOW_PAD insets, else
--- SHOW_FONT_STEP smaller. The canvas zooms as one (its scale), so a fit holds at every zoom. Pure.
function Pane.ShowFontSize(tw, bw)
  tw, bw = tonumber(tw), tonumber(bw)
  if tw and bw and tw > bw - 2 * Pane.SHOW_PAD then
    return Pane.FONT_SM - Pane.SHOW_FONT_STEP
  end
  return Pane.FONT_SM
end

--- Brief SC1: the Show craft hover's lines under its title (Craft.ShowState's state), Craft all's
--- shape: what a click does, one wrapped line, then a blank line and the one red reason it cannot,
--- where it cannot. Pure.
function Pane.ShowTooltipLines(state)
  local lines = {}
  if type(state) ~= "table" then
    return lines
  end
  if state.body ~= nil and tostring(state.body) ~= "" then
    lines[#lines + 1] = { text = tostring(state.body), wrap = true }
  end
  local status = state.status
  if type(status) == "table" and status.text ~= nil and tostring(status.text) ~= "" then
    lines[#lines + 1] = { text = " " }
    lines[#lines + 1] = { text = tostring(status.text), colour = status.colour }
  end
  return lines
end

--- Brief PR19 (the owner, QA round 4): the trainer warning for a line, or nil. Shown only at a cap
--- below 300 with a rank still to train (UI\Trainers.lua Trainers.AtCap), and never at the top:
--- "You have hit the Journeyman cap (150/150). Visit a trainer to learn Expert Cooking." A demo
--- (the developer's /itemtree profdemo cap) says "Demo:" first. trainers is UI\Trainers.lua's
--- table. Answers { text, tier, nextTier }. Pure.
function Pane.CapWarning(chosen, trainers, demo)
  if type(chosen) ~= "table" or type(trainers) ~= "table" then
    return nil
  end
  if type(trainers.AtCap) ~= "function" or not trainers.AtCap(chosen.rank, chosen.max) then
    return nil
  end
  local nextTier = trainers.NextTier(chosen.max)
  local tier = nil
  for _, candidate in ipairs(trainers.TIERS or EMPTY) do
    if candidate.cap == tonumber(chosen.max) then
      tier = candidate
    end
  end
  if not nextTier then
    return nil
  end
  local tierName = tier and tier.name or tostring(chosen.max)
  local text = string.format(
    Pane.WORDS.capWarning,
    tierName,
    tonumber(chosen.rank) or 0,
    tonumber(chosen.max) or 0,
    trainers.RankName(nextTier, chosen.name)
  )
  if demo == true then
    text = string.format(Pane.WORDS.demo, text)
  end
  return { text = text, tier = tier, nextTier = nextTier, demo = demo == true }
end

--- Brief PR19: the height of the strip over the canvas: the rank bar's, and the warning strip's
--- under it where one shows. Pure.
function Pane.TopHeight(warning)
  if warning then
    return Pane.TOP_H + Pane.WARN_H + Pane.SMALL_PAD
  end
  return Pane.TOP_H
end

--- Brief PR19: the demo of the cap (the developer's /itemtree profdemo cap): the chosen line as
--- if its rank were at its max, a copy with demo = true; a line at 300 or with no max shows the
--- Journeyman cap, 150/150. Only the pane draws it: the strip row, the model, Keep and the bag
--- icons never see it. Pure.
function Pane.DemoChosen(chosen)
  if type(chosen) ~= "table" then
    return chosen
  end
  local out = {}
  for key, value in pairs(chosen) do
    out[key] = value
  end
  local max = tonumber(chosen.max)
  if not max or max >= 300 then
    max = 150
  end
  out.max, out.rank, out.demo = max, max, true
  return out
end

--- Brief PR17: how opaque a band's header draws: DONE_ALPHA once the band is done (its tick shown),
--- else full strength. Pure.
function Pane.HeaderAlpha(band)
  if type(band) == "table" and band.state == "done" then
    return Pane.DONE_ALPHA
  end
  return 1
end

--- Brief PR16: the rank's x along the canvas's axis, in viewport px from its left edge, at a pan
--- and zoom: the canvas x Layout.MarkerX gives the rank among the columns, scaled and panned. The
--- rank bar and the "you are here" line both use it, so they meet. Pure.
function Pane.AxisX(layout, rank, panX, zoom)
  local columns = type(layout) == "table" and layout.columns or nil
  local layoutApi = ItemTree.ProfessionsLayout
  if type(columns) ~= "table" or type(layoutApi) ~= "table" or type(layoutApi.MarkerX) ~= "function" then
    return nil
  end
  local x = layoutApi.MarkerX(columns, rank)
  if not x then
    return nil
  end
  return (tonumber(panX) or 0) + x * (tonumber(zoom) or 1)
end

--- The axis as a function, rank to viewport x, for UI\Bar.lua. nil with no columns. Pure.
function Pane.Axis(layout, panX, zoom)
  if Pane.AxisX(layout, 1, panX, zoom) == nil then
    return nil
  end
  return function(rank)
    return Pane.AxisX(layout, rank, panX, zoom)
  end
end

--- Brief PR16: the "you are here" line's rect on the canvas, in canvas units: centred on the
--- marker, HERE_W screen px wide whatever the zoom. Brief PR24 (the owner: "all the way to the
--- bottom of its window, always"): given the viewport's height (screen px) and the pan, it runs
--- from the viewport's top to its bottom, whatever the content's height; without a viewport height
--- it is the content's full height. nil with no marker. Pure.
function Pane.HereRect(layout, zoom, panY, viewportH)
  local marker = type(layout) == "table" and layout.marker or nil
  if type(marker) ~= "table" then
    return nil
  end
  zoom = tonumber(zoom) or 1
  if zoom <= 0 then
    zoom = 1
  end
  local w = Pane.HERE_W / zoom
  viewportH = tonumber(viewportH)
  if viewportH and viewportH > 0 then
    -- The canvas's top sits panY screen px below the viewport's top (panY is 0 or less).
    local top = -(tonumber(panY) or 0) / zoom
    return { x = marker.x - w / 2, y = top, w = w, h = viewportH / zoom }
  end
  return { x = marker.x - w / 2, y = 0, w = w, h = tonumber(layout.height) or 0 }
end

--- Brief PR24: whether the line wears its glow at this rank: not at HERE_GLOW_MIN_RANK or below
--- (nil, an unknown rank, keeps it). Pure.
function Pane.HereGlowShown(rank)
  rank = tonumber(rank)
  if rank == nil then
    return true
  end
  return rank > Pane.HERE_GLOW_MIN_RANK
end

--- Brief PR23: the line's glow rect on the canvas, in canvas units: from HERE_GLOW_W screen px left
--- of the line's left edge up to it, as tall as the line, nothing to the right. The glow fades out
--- to the left (Skin.GlowStops), so it shows the way the player has come. nil with no marker, and
--- (brief PR24) nil at a rank Pane.HereGlowShown rules out. Pure.
function Pane.HereGlowRect(layout, zoom, panY, viewportH, rank)
  local line = Pane.HereRect(layout, zoom, panY, viewportH)
  if not line or not Pane.HereGlowShown(rank) then
    return nil
  end
  zoom = tonumber(zoom) or 1
  if zoom <= 0 then
    zoom = 1
  end
  local w = Pane.HERE_GLOW_W / zoom
  return { x = line.x - w, y = line.y, w = w, h = line.h }
end

--- Brief PR23: how the route arrow's head is drawn: the talent tree's head turned to point right
--- where the client has that atlas (hasAtlas) and can turn a texture (canTurn), else the old
--- chevron. The owner, 2026-10-02: the yellow head where the client has it (hasYellow), drawn
--- desaturated (desaturate = true) so the route gold tint lands at full brightness. Answers { key,
--- w, h, rotation (nil for none), reach (its length along the shaft), desaturate }. Pure.
function Pane.ArrowHeadStyle(hasAtlas, canTurn, hasYellow)
  if hasYellow == true and canTurn == true then
    return {
      key = Pane.ARROW_YELLOW_KEY,
      w = Pane.ARROW_ATLAS_W,
      h = Pane.ARROW_ATLAS_H,
      rotation = math.pi / 2,
      reach = Pane.ARROW_ATLAS_H,
      desaturate = true,
    }
  end
  if hasAtlas == true and canTurn == true then
    return {
      key = Pane.ARROW_KEY,
      w = Pane.ARROW_ATLAS_W,
      h = Pane.ARROW_ATLAS_H,
      rotation = math.pi / 2,
      reach = Pane.ARROW_ATLAS_H,
    }
  end
  return { key = Pane.ARROW_FALLBACK_KEY, w = Pane.ARROW_HEAD, h = Pane.ARROW_HEAD, reach = Pane.ARROW_HEAD }
end

--- Whether a zoom draws the cards as blocks. Pure.
function Pane.IsBlocks(zoom)
  return (tonumber(zoom) or 1) < Pane.LOD_ZOOM
end

--- The Layout sizes the pane draws at. Pure.
function Pane.LayoutSizes(track)
  return {
    colW = Pane.COL_W,
    gap = Pane.GAP,
    header = Pane.HeaderHeight(track),
    nodeH = Pane.NODE_H,
    nodeGap = Pane.CARD_GAP,
    pad = Pane.CANVAS_PAD,
    moreH = Pane.ROW_H,
    collapse = Pane.COLLAPSE,
  }
end

--- Brief PB1: whether an event is one of Pane.COUNT_EVENTS (a reagent count may have moved), as
--- against a skill event. Pure.
function Pane.IsCountEvent(event)
  for _, name in ipairs(Pane.COUNT_EVENTS) do
    if name == event then
      return true
    end
  end
  return false
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

local globalFn = ItemTree.Util.GlobalFn
local theme = ItemTree.ProfessionsKit.Theme
local assets = ItemTree.ProfessionsKit.Assets
local skin = ItemTree.ProfessionsKit.Skin

local function barModule()
  local found = ItemTree.ProfessionsBar
  return type(found) == "table" and type(found.Build) == "function" and found or nil
end

local function frameModule()
  local ui = ItemTree.UI
  local found = type(ui) == "table" and ui.Frame or nil
  return type(found) == "table" and found or nil
end

local function model()
  local found = ItemTree.ProfessionsModel
  return type(found) == "table" and found or nil
end

local function craftModule()
  local found = Professions.craft
  if type(found) == "table" and type(found.ButtonState) == "function" and type(found.Click) == "function" then
    return found
  end
  return nil
end

-- Brief PR15: the Trainers & vendors button and panel (UI\Trainers.lua).
local function trainersModule()
  local found = ItemTree.ProfessionsTrainers
  return type(found) == "table" and type(found.BuildButton) == "function" and found or nil
end

local function layoutModule()
  local found = ItemTree.ProfessionsLayout
  return type(found) == "table" and type(found.Bands) == "function" and found or nil
end

local function tracks()
  local found = ItemTree.ProfessionTracks
  return type(found) == "table" and found or nil
end

local colourOf = ItemTree.ProfessionsKit.ColourOf

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

local hasScript = ItemTree.Util.HasScript

-- Brief PM1 (brief G1 reaching the Professions code): every script body set through setScript
-- runs under ItemTree.Guard.Run, the boundary main's panes use, so a fault in one is handed to the
-- client's error handler once and the rest of the tab keeps working. Only ItemTree's own handlers
-- on ItemTree's own frames are wrapped. raw sets the handler as it is: the hardware event craft
-- path (the Craft all button's click, the queue's press and pause) stays exactly as proven in game.
local guardScript = ItemTree.ProfessionsKit.GuardScript

local function setScript(frame, script, handler, raw)
  if type(frame) ~= "table" or type(frame.SetScript) ~= "function" or not hasScript(frame, script) then
    return false
  end
  if not raw then
    handler = guardScript("Professions.Pane." .. tostring(script), handler)
  end
  return (pcall(frame.SetScript, frame, script, handler))
end

local setShown = ItemTree.ProfessionsKit.SetShown

-- A texture tinted a Theme colour at the colour's own alpha. Washes only: nothing that carries a
-- node's art or words is ever given an alpha (the no dim rule).
local tint = ItemTree.ProfessionsKit.Tint

-- Brief PR17: a frame's own opacity (a grey card, a done band). The frame keeps its mouse.
local function setAlpha(frame, alpha)
  if type(frame) == "table" and type(frame.SetAlpha) == "function" then
    pcall(frame.SetAlpha, frame, alpha)
  end
end

local textColour = ItemTree.ProfessionsKit.TextColour

local function at(object, parent, rect)
  object:ClearAllPoints()
  object:SetPoint("TOPLEFT", parent, "TOPLEFT", rect.x, -rect.y)
  object:SetSize(math.max(rect.w, 0.01), math.max(rect.h, 0.01))
end

--------------------------------------------------------------------------------
-- Font safety (UI/Sidebar.lua and UI/Chain.lua's shape)
--------------------------------------------------------------------------------

local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(Pane.FONT_FALLBACKS) do
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

local function ensureFont(fontString)
  if hasFont(fontString) then
    return true
  end
  return fallbackFont(fontString)
end

local function newText(parent, fontSize, colourKey, justify)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY", Pane.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY")
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  local t = theme()
  local face = t and t.fonts and t.fonts.ITEMTREE_FONT_BODY
  if face and type(fontString.SetFont) == "function" then
    local set, applied = pcall(fontString.SetFont, fontString, face, fontSize, "")
    if not set or applied == false then
      fallbackFont(fontString)
    end
  end
  ensureFont(fontString)
  local outline = t and t.text and t.text.ITEMTREE_TEXT_OUTLINE
  if outline and type(fontString.SetShadowOffset) == "function" then
    pcall(fontString.SetShadowOffset, fontString, outline.x, outline.y)
    if type(fontString.SetShadowColor) == "function" then
      pcall(fontString.SetShadowColor, fontString, outline.r, outline.g, outline.b, outline.a)
    end
  end
  if type(fontString.SetJustifyH) == "function" then
    pcall(fontString.SetJustifyH, fontString, justify or "LEFT")
  end
  if type(fontString.SetWordWrap) == "function" then
    pcall(fontString.SetWordWrap, fontString, false)
  end
  textColour(fontString, colourKey)
  return fontString
end

local function setText(fontString, text)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  ensureFont(fontString)
  return (pcall(fontString.SetText, fontString, text or ""))
end

local stringWidth = ItemTree.ProfessionsKit.StringWidth

-- Brief PR21: the Recommended tag's words, RECOMMENDED in the client font object Pane.TAG_FONT (Friz
-- Quadrata, no shadow) at its own size, dark, with no shadow (brief PR19); the other small client
-- fonts where that object is missing, and the font safety rule as everywhere else.
local function newTagText(parent)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY", Pane.TAG_FONT)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY")
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  if not hasFont(fontString) and type(fontString.SetFontObject) == "function" then
    for _, name in ipairs(Pane.TAG_FONTS) do
      local object = rawget(_G, name)
      if object ~= nil then
        local set, applied = pcall(fontString.SetFontObject, fontString, object)
        if set and applied ~= false then
          break
        end
      end
    end
  end
  ensureFont(fontString)
  fontString.fontName = Pane.TAG_FONT
  if type(fontString.SetJustifyH) == "function" then
    pcall(fontString.SetJustifyH, fontString, "CENTER")
  end
  if type(fontString.SetWordWrap) == "function" then
    pcall(fontString.SetWordWrap, fontString, false)
  end
  if type(fontString.SetShadowOffset) == "function" then
    pcall(fontString.SetShadowOffset, fontString, 0, 0)
  end
  if type(fontString.SetShadowColor) == "function" then
    pcall(fontString.SetShadowColor, fontString, 0, 0, 0, 0)
  end
  textColour(fontString, Pane.TAG_WORD)
  return fontString
end

--------------------------------------------------------------------------------
-- Textures
--------------------------------------------------------------------------------

local applyAsset = ItemTree.ProfessionsKit.ApplyAsset
local newTexture = ItemTree.ProfessionsKit.NewTexture
local wash = ItemTree.ProfessionsKit.Wash

-- Four edges drawn by hand, the chain tab's inset border, whose colour and thickness can change
-- as the frame is reused. The card's flat fallback where the card art will not draw.
local function edges(frame)
  local out = {}
  for index = 1, 4 do
    out[index] = wash(frame, "BORDER", Pane.PLAIN_BORDER)
    if not out[index] then
      return nil
    end
  end
  return out
end

local function paintEdges(frame, list, colourKey, thickness)
  if type(list) ~= "table" then
    return false
  end
  local top, bottom, left, right = list[1], list[2], list[3], list[4]
  for _, edge in ipairs(list) do
    edge:ClearAllPoints()
    tint(edge, colourKey)
    edge:Show()
  end
  top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  top:SetHeight(thickness)
  bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(thickness)
  -- Brief PR19: the sides run between the top and the bottom, so no two edges overlap and a faded
  -- frame fades its corners as evenly as its sides.
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -thickness)
  left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, thickness)
  left:SetWidth(thickness)
  right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -thickness)
  right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, thickness)
  right:SetWidth(thickness)
  frame.borderKey = colourKey
  return true
end

local function hideEdges(list)
  for _, edge in ipairs(type(list) == "table" and list or EMPTY) do
    edge:Hide()
  end
end

-- The card (brief PR16): flat colour with a thin chamfered edge (UI\Skin.lua Skin.Card), gold
-- edged where recommended; the flat face and square edges where that will not draw. kind is
-- Pane.CardStyle's. Answers "art" or "flat".
local function paintCard(frame, w, h, kind)
  local s = skin()
  local style = Pane.CardStyle(kind)
  local drawn = s and type(s.Card) == "function" and s.Card(frame, w, h, style) or false
  frame.borderKey = style.edge
  frame.cardKind = kind
  if drawn then
    setShown(frame.face, false)
    hideEdges(frame.edges)
  else
    if s and type(s.HideCard) == "function" then
      s.HideCard(frame)
    end
    tint(frame.face, style.fill)
    setShown(frame.face, true)
    paintEdges(frame, frame.edges, style.edge, style.thickness)
  end
  frame.skinned = drawn == true
  return drawn and "art" or "flat"
end

local function applyIconFile(texture, file, fallbackKey)
  if type(texture) ~= "table" then
    return false
  end
  if file and type(texture.SetTexture) == "function" and pcall(texture.SetTexture, texture, file) then
    if type(texture.SetTexCoord) == "function" then
      pcall(texture.SetTexCoord, texture, 0, 1, 0, 1)
    end
    if type(texture.SetVertexColor) == "function" then
      texture:SetVertexColor(1, 1, 1, 1)
    end
    return true
  end
  if applyAsset(texture, fallbackKey or "ICON_QUESTIONMARK") then
    if type(texture.SetVertexColor) == "function" then
      texture:SetVertexColor(1, 1, 1, 1)
    end
    return true
  end
  return false
end

--------------------------------------------------------------------------------
-- What the client knows, asked only for what is on screen
--------------------------------------------------------------------------------

-- An item's icon: our data, then the client's local icon calls, then the question mark
-- (Assets.ItemIcon). Never a request to load the item.
local function itemIcon(itemId)
  local a = assets()
  if a and type(a.ItemIcon) == "function" then
    local ok, icon = pcall(a.ItemIcon, itemId)
    if ok and icon then
      return icon
    end
  end
  return nil
end

-- A recipe's own spell icon, for a recipe that makes no item (an enchant). A local read.
local function spellIcon(spellId)
  local spellApi = rawget(_G, "C_Spell")
  if type(spellApi) == "table" and type(spellApi.GetSpellTexture) == "function" then
    local ok, icon = pcall(spellApi.GetSpellTexture, spellId)
    if ok and icon then
      return icon
    end
  end
  local legacy = globalFn("GetSpellTexture")
  if legacy then
    local ok, icon = pcall(legacy, spellId)
    if ok and icon then
      return icon
    end
  end
  return nil
end

-- How many the player carries: the client's bag count, a local read. withBank counts the bank
-- too (brief PR9, the route's count, as the tooltip reads it).
local function bagCount(itemId, withBank)
  local itemApi = rawget(_G, "C_Item")
  local count = nil
  if type(itemApi) == "table" and type(itemApi.GetItemCount) == "function" then
    local ok, answer = pcall(itemApi.GetItemCount, itemId, withBank == true)
    count = ok and tonumber(answer) or nil
  end
  if count == nil then
    local legacy = globalFn("GetItemCount")
    if legacy then
      local ok, answer = pcall(legacy, itemId, withBank == true)
      count = ok and tonumber(answer) or nil
    end
  end
  return count or 0
end

-- Brief PRX (PR44): the player's plan crafts for a card, where it is its band's plan pick (the
-- model's PlanCrafts, a lookup in its cached pass), else nil.
local function planCrafts(lo, spell)
  local m = model()
  if not m or type(m.PlanCrafts) ~= "function" or Pane.selected == nil then
    return nil
  end
  local ok, crafts = pcall(m.PlanCrafts, Pane.selected, lo, spell)
  return ok and tonumber(crafts) or nil
end

-- Brief PR46: a route card's crafts alone in its band (the model's AloneCrafts, a lookup in its
-- cached pass, the band part the Keep line sums), nil for a done band or any other recipe.
local function bandAloneCrafts(lo, spell)
  local m = model()
  if not m or type(m.AloneCrafts) ~= "function" or Pane.selected == nil then
    return nil
  end
  local ok, crafts = pcall(m.AloneCrafts, Pane.selected, lo, spell)
  return ok and tonumber(crafts) or nil
end

-- Brief PRX (PR44): an alternative card's "alone" hover lines (Pane.AloneLines), from the model's
-- Crafts for the recipe alone over the band's points left at the player's rank; nil for a done band.
-- Brief PR46: a route alternative passes its card's crafts, so the hover words the card's number.
local function aloneLines(node, lo, hi, known)
  if tonumber(known) and tonumber(hi) then
    return Pane.AloneLines(Pane.names, node, known, hi)
  end
  local m = model()
  if not m or type(m.Crafts) ~= "function" or not tonumber(hi) then
    return nil
  end
  local rank = type(Pane.chosen) == "table" and tonumber(Pane.chosen.rank) or 0
  local ok, crafts = pcall(m.Crafts, node, math.max(rank, tonumber(lo) or 0), hi)
  if not ok then
    return nil
  end
  return Pane.AloneLines(Pane.names, node, crafts, hi)
end

local function isUndiscovered(itemId)
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.IsUndiscovered) ~= "function" then
    return false
  end
  local ok, answer = pcall(data.IsUndiscovered, data, itemId)
  return ok and answer == true
end

local function zoneName(areaId)
  local mapApi = rawget(_G, "C_Map")
  if type(mapApi) ~= "table" or type(mapApi.GetAreaInfo) ~= "function" then
    return nil
  end
  local ok, name = pcall(mapApi.GetAreaInfo, areaId)
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- A node's or a creature's name from what ItemTree already holds (Graph.Name reads names the
-- graph has been told and loads nothing), or nil.
local function graphName(kind, id)
  local graph = ItemTree.Graph
  if type(graph) ~= "table" or type(graph.Name) ~= "function" then
    return nil
  end
  local ok, name = pcall(graph.Name, kind .. ":" .. tostring(id))
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

local function spotText(names, spot)
  if spot.k == "zone" then
    return Pane.SpotName(names, spot, zoneName(spot.id), graphName("zone", spot.id))
  end
  if spot.k == "creature" then
    return Pane.SpotName(names, spot, nil, graphName("npc", spot.id))
  end
  if spot.k == "node" then
    return Pane.SpotName(names, spot, nil, graphName("object", spot.id))
  end
  return Pane.SpotName(names, spot)
end

local function skillName(line)
  local keep = ItemTree.Keep
  if type(keep) == "table" and type(keep.SkillName) == "function" then
    local ok, name = pcall(keep.SkillName, line)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end
  return nil
end

local function playerSkills()
  local window = frameModule()
  if not window or type(window.PlayerSkills) ~= "function" then
    return {}
  end
  local ok, skills = pcall(window.PlayerSkills)
  if ok and type(skills) == "table" then
    return skills
  end
  return {}
end

local function facts()
  local m = model()
  if m and type(m.Facts) == "function" then
    local ok, skills, faction, signature = pcall(m.Facts)
    if ok and type(skills) == "table" then
      return skills, faction, signature
    end
  end
  return playerSkills(), nil, nil
end

-- Brief TP1 (QA item 210): the tracked professions' rows and drawing (UI\Track.lua), each nil or
-- empty where that file did not load.
local function trackModule()
  local found = ItemTree.ProfessionsTrack
  if type(found) == "table" and type(found.Rows) == "function" and type(found.Draw) == "function" then
    return found
  end
  return nil
end

local function trackedRows(data, skills)
  local track = trackModule()
  if not track then
    return {}
  end
  local ok, rows = pcall(track.Rows, data, track.List(), skills, skillName)
  return ok and type(rows) == "table" and rows or {}
end

-- The frame the strip's rows anchor to: UI\Track.lua's host, which the wheel scrolls once tracked
-- professions run past the strip's foot; the strip itself without it.
local function stripHost()
  local track = trackModule()
  if track and type(track.Host) == "function" then
    local ok, host = pcall(track.Host, Pane.strip)
    if ok and type(host) == "table" then
      return host
    end
  end
  return Pane.strip
end

--------------------------------------------------------------------------------
-- Opening, hovering
--------------------------------------------------------------------------------

--- Opens a page key in the Tree tab, the Boss loot tab's way (UIBossLoot.OpenKey): Frame.Open,
--- which loads ItemTree_Data on demand as it always has, then the Tree tab. opts, optional, is
--- handed to Frame.Open as is ({ view = ... } lands on that view). Answers whether the window
--- took it.
function Pane.OpenKey(key, opts)
  local window = frameModule()
  if type(key) ~= "string" or not window or type(window.Open) ~= "function" then
    return false
  end
  local ok
  if type(opts) == "table" then
    ok = pcall(window.Open, key, opts)
  else
    ok = pcall(window.Open, key)
  end
  if type(window.SelectTab) == "function" then
    pcall(window.SelectTab, "Tree")
  end
  return ok
end

-- E6: the dress up and chat link clicks, the chain tab's own call (Chain.ModifiedClick), and
-- UI/ItemClick.lua's HandleKey where this build has no chain tab.
local function modifiedClick(key, button)
  if button ~= nil and button ~= "LeftButton" then
    return false
  end
  local ui = ItemTree.UI
  local chain = type(ui) == "table" and ui.Chain or nil
  if type(chain) == "table" and type(chain.ModifiedClick) == "function" then
    local ok, handled = pcall(chain.ModifiedClick, key, button)
    return ok and handled == true
  end
  local helper = ItemTree.ItemClick
  if type(helper) == "table" and type(helper.HandleKey) == "function" then
    local ok, handled = pcall(helper.HandleKey, key)
    return ok and handled == true
  end
  return false
end

--- The Sources view's key (Edges.SOURCES), "sources" where Core has not said. Pure.
function Pane.SourcesView()
  local found = type(ItemTree.Edges) == "table" and ItemTree.Edges.SOURCES or nil
  if type(found) == "string" then
    return found
  end
  return "sources"
end

--- A click on a node or a reagent: the client's modified click first, else the page in the Tree
--- tab, on opts.view where opts says one. Only the left button opens. Answers "modified", "open"
--- or "none".
function Pane.Click(key, button, opts)
  if type(key) ~= "string" then
    return "none"
  end
  if modifiedClick(key, button) then
    return "modified"
  end
  if button ~= nil and button ~= "LeftButton" then
    return "none"
  end
  if Pane.OpenKey(key, opts) then
    return "open"
  end
  return "none"
end

--- The owner, 2026-10-02: a click on a material (a reagent, a gathered item, a queue ingredient)
--- opens it straight on its Sources view. Modified clicks are Pane.Click's, unchanged.
function Pane.ClickMaterial(key, button)
  return Pane.Click(key, button, { view = Pane.SourcesView() })
end

-- Whether our data has the recipe (Data:GetRecipe, which loads ItemTree_Data on demand), asked on
-- a click only.
local function recipeKnown(spell)
  local data = ItemTree.Data
  spell = tonumber(spell)
  if not spell or type(data) ~= "table" or type(data.GetRecipe) ~= "function" then
    return false
  end
  local ok, recipe = pcall(data.GetRecipe, data, spell)
  return ok and type(recipe) == "table"
end

-- A recipe's teaching items from the tracks (the node carries no by of its own).
local function teachersOf(spell)
  local t = tracks()
  local line = t and type(t.lines) == "table" and t.lines[Pane.selected] or nil
  local recipes = type(line) == "table" and line.recipes or nil
  local recipe = type(recipes) == "table" and recipes[tonumber(spell) or 0] or nil
  return type(recipe) == "table" and recipe.by or nil
end

--- The owner, 2026-10-02: a click on a LOCKED card. A modified click is E6's on the card's key,
--- as ever; a plain left click opens where to learn the recipe (Pane.LearnTarget) on its Sources
--- view, or the Trainers & vendors panel. Answers "modified", "open", "trainers" or "none".
function Pane.ClickLocked(key, spell, button)
  if type(key) == "string" and modifiedClick(key, button) then
    return "modified"
  end
  if button ~= nil and button ~= "LeftButton" then
    return "none"
  end
  local target = Pane.LearnTarget(spell, teachersOf(spell), recipeKnown(spell))
  if target.key then
    if Pane.OpenKey(target.key, { view = Pane.SourcesView() }) then
      return "open"
    end
    return "none"
  end
  if Pane.OpenTrainers() then
    return "trainers"
  end
  return "none"
end

local hideTooltip = ItemTree.ProfessionsKit.HideTooltip

local function dragging()
  local press = Pane.press
  return type(press) == "table" and press.dragging == true
end

-- A plain tooltip: a title and lines.
local function textTooltip(owner, title, lines)
  local tooltip = rawget(_G, "GameTooltip")
  if dragging() or type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  pcall(tooltip.SetOwner, tooltip, owner, "ANCHOR_RIGHT")
  if type(tooltip.SetText) == "function" then
    pcall(tooltip.SetText, tooltip, title or "")
  elseif type(tooltip.AddLine) == "function" then
    pcall(tooltip.AddLine, tooltip, title or "")
  end
  for _, line in ipairs(lines or EMPTY) do
    if type(tooltip.AddLine) == "function" then
      if type(line) == "table" then
        -- A line with its own colour (a Theme key) and wrap; white where the key will not resolve.
        local c = colourOf(line.colour) or EMPTY
        pcall(tooltip.AddLine, tooltip, line.text, c.r or 1, c.g or 1, c.b or 1, line.wrap == true)
      else
        pcall(tooltip.AddLine, tooltip, line, 1, 1, 1, true)
      end
    end
  end
  if type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  return true
end

-- A hint line's colour: { text, colour = Theme key } in that colour (white where the key will not
-- resolve), a bare string in the client's green hint colour. Answers the text and r, g, b.
local function extraLook(line)
  if type(line) == "table" then
    local c = colourOf(line.colour) or EMPTY
    return line.text, c.r or 1, c.g or 1, c.b or 1
  end
  return line, 0.1, 1, 0.1
end

-- Brief K18: hands the material's own lines to ItemTree's tooltip block (UI/Tooltip.lua
-- SetOwnerContext) for this owner and item, with no "Ctrl + right click" hint, so they go on in
-- the block's one pass and come back with every data refresh. Answers the context, or nil where
-- that file is not there to take it (and the owner's old context is let go on every other path).
local function materialContext(owner, id, extra, noHint)
  local tip = ItemTree.Tooltip
  if type(tip) ~= "table" or type(tip.SetOwnerContext) ~= "function" then
    return nil
  end
  if not noHint or not id then
    pcall(tip.SetOwnerContext, owner, nil)
    return nil
  end
  local lines = {}
  for _, line in ipairs(extra or EMPTY) do
    local text, r, g, b = extraLook(line)
    if type(text) == "string" then
      lines[#lines + 1] = { text = text, r = r, g = g, b = b }
    end
  end
  local context = { itemId = id, noHint = true, lines = lines, drawn = false }
  local ok, set = pcall(tip.SetOwnerContext, owner, context)
  if ok and set then
    return context
  end
  return nil
end

-- The client's own tooltip for an item or a recipe, the chain tab's path: SetItemByID, else the
-- item link; a recipe with no item takes SetSpellByID, else the spell link; failing all of those
-- the name alone. A zone says its name and that a click opens its page. Brief K18: noHint is the
-- material's tooltip (Pane.MaterialTooltip), whose lines ride ItemTree's block where it draws.
local function showTooltip(owner, key, name, extra, noHint)
  local tooltip = rawget(_G, "GameTooltip")
  if dragging() or type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  if type(key) ~= "string" then
    return textTooltip(owner, name, nil)
  end
  local kind, id = key:match("^(%a+):(%d+)$")
  id = tonumber(id)
  if kind == "zone" then
    return textTooltip(owner, name, { Pane.WORDS.openZone })
  end
  pcall(tooltip.SetOwner, tooltip, owner, "ANCHOR_RIGHT")
  local context = materialContext(owner, kind == "item" and id or nil, extra, noHint)
  local drawn = false
  if kind == "item" and id then
    drawn = type(tooltip.SetItemByID) == "function" and pcall(tooltip.SetItemByID, tooltip, id) or false
    if not drawn and type(tooltip.SetHyperlink) == "function" then
      drawn = pcall(tooltip.SetHyperlink, tooltip, "item:" .. id)
    end
  elseif kind == "spell" and id then
    drawn = type(tooltip.SetSpellByID) == "function" and pcall(tooltip.SetSpellByID, tooltip, id) or false
    if not drawn and type(tooltip.SetHyperlink) == "function" then
      drawn = pcall(tooltip.SetHyperlink, tooltip, "spell:" .. id)
    end
  end
  if not drawn and type(tooltip.AddLine) == "function" then
    pcall(tooltip.AddLine, tooltip, name or key)
  end
  -- A material's hint under the item tooltip, in the client's green hint colour. Brief PR37: a
  -- line given as { text, colour } draws in that Theme colour instead. Brief K18: not again where
  -- ItemTree's block already put them on in its own pass.
  if not (context and context.drawn) then
    for _, line in ipairs(extra or EMPTY) do
      if type(tooltip.AddLine) == "function" then
        local text, r, g, b = extraLook(line)
        pcall(tooltip.AddLine, tooltip, text, r, g, b, true)
      end
    end
  end
  if type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  return true
end

--- A material's tooltip: the client's item tooltip, then "Click to see where to get it". The
--- queue tray's ingredients use it too. Brief PR37: short, where given, is how many more ONE craft
--- needs (a reagent of a card in the player's own band, Pane.ReagentShort), said in the warning red
--- above the hint. Answers whether a tooltip was drawn.
---
--- Brief K18: a plain click opens the item here and the last line says so, so ItemTree's block
--- leaves out its "Ctrl + right click ... for the full tree" hint on this tooltip alone (the bound
--- key still works), and takes these lines into its own pass (UI/Tooltip.lua SetOwnerContext).
function Pane.MaterialTooltip(owner, key, name, short)
  local extra = {}
  if tonumber(short) and tonumber(short) > 0 then
    extra[#extra + 1] = { text = Pane.ShortText(short), colour = Pane.SHORT_WORD }
  end
  extra[#extra + 1] = Pane.WORDS.seeSources
  return showTooltip(owner, key, name, extra, true)
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

-- Brief PR19: the strip over the canvas as drawn now, the rank bar's and the trainer warning's
-- under it where one shows. UI\Trainers.lua opens its panel under it.
function Pane.TopOffset()
  return tonumber(Pane.topH) or Pane.TOP_H
end

-- Session state: the chosen line, and which bands are open, per line. Nothing is saved.
Pane.selected = Pane.selected
Pane.expanded = Pane.expanded or {}
-- nil until a line is drawn: the first draw opens on the player's own band.
Pane.panX, Pane.panY = nil, nil
Pane.zoom = Pane.zoom or 1
-- Brief PR15 (the owner's view rule): each line's own zoom and pan, { zoom, panX, panY } by skill
-- line, kept while the ItemTree window stays open (across line and tab switches and skill up
-- redraws) and let go when the window closes (Pane.ForgetViews). Nothing is saved.
Pane.views = Pane.views or {}

local hideBlocks

local function releasePool(pool)
  for _, frame in ipairs(pool.used) do
    frame:Hide()
    frame.rect = nil
    pool.free[#pool.free + 1] = frame
  end
  pool.used = {}
end

local function newPool()
  return { used = {}, free = {} }
end

local function acquire(pool, build)
  local frame = table.remove(pool.free)
  if not frame then
    frame = build()
    if not frame then
      return nil
    end
  end
  pool.used[#pool.used + 1] = frame
  return frame
end

--------------------------------------------------------------------------------
-- The strip
--------------------------------------------------------------------------------

local render

-- Brief BQ24: the nearest trainer's line for a row's gem hover (Core/TrainerSearch.lua
-- FindNearest over the line's kind), or nil where none is known. Asked on the hover only.
function Pane.NearestTrainerText(data)
  local search = ItemTree.TrainerSearch
  if type(data) ~= "table" or not data.trainable or type(search) ~= "table" then
    return nil
  end
  if type(search.LineKind) ~= "function" or type(search.FindNearest) ~= "function" then
    return nil
  end
  local kind = search.LineKind(data.line)
  if not kind then
    return nil
  end
  local side = nil
  local read = rawget(_G, "UnitFactionGroup")
  if type(read) == "function" then
    local ok, answer = pcall(read, "player")
    side = ok and answer or nil
  end
  local ok, found = pcall(search.FindNearest, kind, side)
  if ok and type(found) == "table" and type(found.key) == "string" then
    return found.text
  end
  return nil
end

local function buildStripRow()
  local strip = Pane.strip
  local row = newFrame("Button", strip)
  if not row then
    return nil
  end
  row:SetHeight(Pane.ROW_H)
  row.selected = wash(row, "BACKGROUND", Pane.SELECTED)
  if row.selected then
    row.selected:SetAllPoints(row)
  end
  row.hover = wash(row, "HIGHLIGHT", Pane.HOVER)
  if row.hover then
    row.hover:SetAllPoints(row)
  end
  row.icon = newTexture(row, "ARTWORK")
  if row.icon then
    row.icon:SetSize(Pane.ROW_ICON, Pane.ROW_ICON)
    row.icon:SetPoint("LEFT", row, "LEFT", Pane.GUTTER, 0)
  end
  row.rank = newText(row, Pane.FONT_SM, Pane.MUTED_WORD, "RIGHT")
  if row.rank then
    row.rank:SetPoint("RIGHT", row, "RIGHT", -Pane.GUTTER, 0)
  end
  -- Brief BQ24 (QA item 35): the red gem left of the rank, the Discoveries tab's gem art, smaller.
  row.gem = newTexture(row, "OVERLAY")
  if row.gem then
    row.gem:SetSize(Pane.GEM_SIZE, Pane.GEM_SIZE)
    if row.rank then
      row.gem:SetPoint("RIGHT", row.rank, "LEFT", -Pane.SMALL_PAD, 0)
    else
      row.gem:SetPoint("RIGHT", row, "RIGHT", -Pane.GUTTER, 0)
    end
    row.gem:Hide()
  end
  setScript(row, "OnEnter", function(self)
    local data = rawget(self, "data")
    local lines = Pane.TrainableLines(data, Pane.NearestTrainerText(data))
    if lines then
      local first = table.remove(lines, 1)
      textTooltip(self, first.text, lines)
    end
  end)
  setScript(row, "OnLeave", function()
    local tooltip = rawget(_G, "GameTooltip")
    if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
      pcall(tooltip.Hide, tooltip)
    end
  end)
  row.label = newText(row, Pane.FONT_MD, Pane.NAME_WORD, "LEFT")
  if row.label then
    row.label:SetPoint("LEFT", row, "LEFT", Pane.GUTTER * 2 + Pane.ROW_ICON, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -(Pane.GUTTER + 56), 0)
  end
  if type(row.RegisterForClicks) == "function" then
    pcall(row.RegisterForClicks, row, "LeftButtonUp")
  end
  setScript(row, "OnClick", function(self)
    local line = rawget(self, "line")
    if line and line ~= Pane.selected then
      -- The line being left keeps its view in Pane.views (applyPan wrote it); the new one opens
      -- on its own remembered view, or its default one.
      Pane.selected = line
      render()
    end
  end)
  return row
end

local function drawStrip(rows, chosen)
  local pool = Pane.stripPool
  releasePool(pool)
  local a = assets()
  -- Brief TP1: on the strip's host, which scrolls with the tracked rows under these (UI\Track.lua).
  local host = stripHost()
  for index, data in ipairs(rows) do
    local row = acquire(pool, buildStripRow)
    if row then
      row.line = data.line
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -(index - 1) * Pane.ROW_H - Pane.SMALL_PAD)
      row:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -(index - 1) * Pane.ROW_H - Pane.SMALL_PAD)
      local isChosen = chosen ~= nil and data.line == chosen.line
      setShown(row.selected, isChosen)
      if row.icon then
        local glyph = a and type(a.ForSkill) == "function" and a.ForSkill(data.line) or nil
        setShown(row.icon, applyIconFile(row.icon, nil, glyph))
      end
      setText(row.label, data.name)
      textColour(row.label, isChosen and Pane.SELECTED_WORD or Pane.NAME_WORD)
      setText(row.rank, Pane.RankText(data))
      -- Brief BQ24: the red gem where the profession can be levelled up (Pane.Trainable).
      row.data = data
      if row.gem then
        local shown = data.trainable == true and applyAsset(row.gem, Pane.GEM_ASSET)
        if shown then
          local c = colourOf(Pane.GEM_TINT)
          if c and type(row.gem.SetVertexColor) == "function" then
            row.gem:SetVertexColor(c.r or 1, c.g or 0.25, c.b or 0.25, 1)
          end
        end
        setShown(row.gem, shown and true or false)
        -- The name stops short of the gem where it shows.
        if row.label and type(row.label.SetPoint) == "function" then
          local right = Pane.GUTTER + 56
          if shown then
            right = right + Pane.GEM_SIZE + Pane.SMALL_PAD
          end
          row.label:ClearAllPoints()
          row.label:SetPoint("LEFT", row, "LEFT", Pane.GUTTER * 2 + Pane.ROW_ICON, 0)
          row.label:SetPoint("RIGHT", row, "RIGHT", -right, 0)
        end
      end
      row:Show()
    end
  end
end

--------------------------------------------------------------------------------
-- Measuring, the zoom and the pan
--------------------------------------------------------------------------------

local function number(frame, method)
  if type(frame) ~= "table" or type(frame[method]) ~= "function" then
    return nil
  end
  local ok, value = pcall(frame[method], frame)
  return ok and tonumber(value) or nil
end

local function viewportSize()
  local function measure(frame, method)
    local value = number(frame, method)
    if value and value > 0 then
      return value
    end
    return nil
  end
  local width = measure(Pane.viewport, "GetWidth")
  local height = measure(Pane.viewport, "GetHeight")
  if not width then
    width = (measure(Pane.region, "GetWidth") or 0) - Pane.STRIP_W - Pane.HAIRLINE * 3
  end
  if not height then
    -- Brief LF1: the hints float over the canvas now, so the view runs to the board's foot.
    height = (measure(Pane.region, "GetHeight") or 0) - Pane.HAIRLINE * 2 - Pane.TopOffset()
  end
  return math.max(width, 0), math.max(height, 0)
end
Pane.ViewportSize = viewportSize

-- Brief LF1 (QA item 240c): the height the pan and the Shift + wheel scroll hold the route inside,
-- the viewport's less the floating hint panel's room while it shows (Pane.HintReserve).
local function panHeight(height)
  local hints = Pane.hints
  local reserve = 0
  if type(hints) == "table" and rawget(hints, "shownHints") then
    reserve = Pane.HintReserve(rawget(hints, "layoutH"))
  end
  return Pane.PanHeight(height, reserve)
end

-- The cursor in the viewport's own units, GetCursorPosition's screen pixels over the viewport's
-- effective scale (the window's own SetScale and UIParent's, together).
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
  local scale = number(Pane.viewport, "GetEffectiveScale") or 1
  if scale <= 0 then
    scale = 1
  end
  return x / scale, y / scale
end

-- The pointer inside the viewport from its top left, the chain tab's arithmetic, or nil.
local function pointerOffsets()
  local viewport = Pane.viewport
  local get = globalFn("GetCursorPosition")
  if not viewport or not get then
    return nil
  end
  local ok, x, y = pcall(get)
  if not ok then
    return nil
  end
  local scale = number(viewport, "GetEffectiveScale") or 1
  return Pane.Helper("ViewportPoint")(x, y, number(viewport, "GetLeft"), number(viewport, "GetTop"), scale)
end

local place

local function updateZoomLabel()
  local controls = Pane.controls
  if controls and controls.label then
    setText(controls.label, Pane.Helper("ZoomText")(Pane.zoom))
  end
end

-- Pushes the zoom and the pan onto the canvas, the chain tab's way: SetScale makes the icons and
-- the words grow together, and the anchor offsets are in the canvas's own scaled units, so the
-- viewport pixels are divided by the zoom on the way in.
local function applyPan(panX, panY)
  local layout = Pane.layout
  if not (layout and Pane.canvas and Pane.viewport) then
    return false
  end
  local zoom = Pane.zoom or 1
  if zoom <= 0 then
    zoom = 1
    Pane.zoom = zoom
  end
  local width, height = viewportSize()
  -- Brief LF1: held so the route's foot can come up clear of the hint panel.
  Pane.panX, Pane.panY = Pane.ClampPan(panX, panY, layout.width, layout.height, width, panHeight(height), zoom)
  if type(Pane.canvas.SetScale) == "function" then
    pcall(Pane.canvas.SetScale, Pane.canvas, zoom)
  end
  Pane.canvas:ClearAllPoints()
  Pane.canvas:SetPoint("TOPLEFT", Pane.viewport, "TOPLEFT", Pane.panX / zoom, -Pane.panY / zoom)
  -- Brief PR15: the line's view, remembered for this window session.
  if Pane.selected ~= nil then
    Pane.views[Pane.selected] = { zoom = zoom, panX = Pane.panX, panY = Pane.panY }
  end
  updateZoomLabel()
  -- Brief PR16: the "you are here" line at this zoom, and the bar, which follows the canvas.
  -- Brief PR24: the line and its glow span the viewport, top to bottom, at any zoom or pan.
  local here = Pane.here
  local rect = Pane.HereRect(layout, zoom, Pane.panY, height)
  Pane.hereRect = rect
  if here then
    if rect then
      here:ClearAllPoints()
      here:SetPoint("TOPLEFT", Pane.canvas, "TOPLEFT", rect.x, -rect.y)
      here:SetSize(math.max(rect.w, 0.01), math.max(rect.h, 0.01))
      here:Show()
    else
      here:Hide()
    end
  end
  -- Brief PR23: the glow on the line's left, HERE_GLOW_W screen px whatever the zoom. Brief PR24:
  -- none at a low rank.
  local glow = Pane.hereGlow
  if glow then
    local rank = type(Pane.chosen) == "table" and Pane.chosen.rank or nil
    local glowRect = rect and Pane.HereGlowRect(layout, zoom, Pane.panY, height, rank) or nil
    Pane.hereGlowRect = glowRect
    if glowRect then
      glow:ClearAllPoints()
      glow:SetPoint("TOPLEFT", Pane.canvas, "TOPLEFT", glowRect.x, -glowRect.y)
      glow:SetSize(math.max(glowRect.w, 0.01), math.max(glowRect.h, 0.01))
      glow:Show()
    else
      glow:Hide()
    end
  end
  Pane.DrawBar()
  place()
  return true
end
Pane.SetPan = applyPan

--- Zooms by a factor about a point in the viewport (the pointer, else the middle), the chain
--- tab's ZoomAbout on both axes. Answers the zoom now in force.
function Pane.ZoomBy(factor, pointerX, pointerY)
  local zoom = Pane.zoom or 1
  local newZoom = Pane.StepZoom(zoom, factor)
  local width, height = viewportSize()
  pointerX = tonumber(pointerX) or width / 2
  pointerY = tonumber(pointerY) or height / 2
  local about = Pane.Helper("ZoomAbout")
  local panX = about(zoom, newZoom, pointerX, Pane.panX or 0)
  local panY = about(zoom, newZoom, pointerY, Pane.panY or 0)
  Pane.zoom = newZoom
  applyPan(panX, panY)
  return newZoom
end

--- Back to the line's default view (Pane.DefaultView): the natural size, the player's own band
--- centred, the top of the columns in view.
function Pane.ResetZoom()
  local layout = Pane.layout
  if not layout then
    Pane.zoom = 1
    updateZoomLabel()
    return false
  end
  local width, height = viewportSize()
  local zoom, panX, panY = Pane.DefaultView(layout, Pane.chosen and Pane.chosen.rank, width, height)
  Pane.zoom = zoom
  applyPan(panX, panY)
  return true
end

--- Brief UI15 (QA item 213): one Shift + wheel notch: the canvas moves SCROLL_STEP viewport px on
--- Pane.ScrollAxis's axis at the zoom in force, held inside the content. Answers the axis, or nil
--- where nothing could move.
function Pane.ScrollBy(delta)
  local layout = Pane.layout
  delta = tonumber(delta) or 0
  if not layout or delta == 0 then
    return nil
  end
  local width, height = viewportSize()
  local axis = Pane.ScrollAxis(layout.width, layout.height, width, panHeight(height), Pane.zoom or 1)
  if not axis then
    return nil
  end
  applyPan(Pane.ScrollPan(Pane.panX, Pane.panY, delta, axis, Pane.SCROLL_STEP))
  return axis
end

-- Brief UI15: whether the player holds Shift now, one read of the client's own key state
-- (IsShiftKeyDown, Blizzard_APIDocumentationGenerated/InputDocumentation.lua:236, branch forever).
-- Only read: never bound, hooked or consumed. False where the client will not say.
local function shiftHeld()
  -- Brief E2E-1 (the e2e plan's addition 6): the developer only e2e run's pretend Shift, for the
  -- length of one Pane.Wheel call.
  if Pane.pretendShift == true then
    return true
  end
  local read = globalFn("IsShiftKeyDown")
  if not read then
    return false
  end
  local ok, held = pcall(read)
  return ok and held ~= nil and held ~= false
end

--------------------------------------------------------------------------------
-- Brief UI15 (QA item 213): the pan cursor
--------------------------------------------------------------------------------

-- The client's named cursors: SetCursor takes a cursor name or nil and ResetCursor puts the arrow
-- back (Blizzard_APIDocumentationGenerated/GameCursorDocumentation.lua:98 and :106). The name is the
-- one Blizzard's own drag bar wears while its frame is moved, the four way move arrow, set to nil
-- after (PanelDragBarMixin:UpdateCursor, Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:1627
-- to 1632; the map canvas resets with ResetCursor, Blizzard_MapCanvas.lua:1120 to 1133; branch
-- forever at 1.60.1.70425). Only a cursor this pane set is ever put back, so another frame's cursor
-- is never taken away. Answers whether the cursor changed.
local function setPanCursor(on)
  on = on == true
  if on == (Pane.cursorSet == true) then
    return false
  end
  if on then
    local set = globalFn("SetCursor")
    if not set or not pcall(set, Pane.PAN_CURSOR) then
      return false
    end
    Pane.cursorSet = true
    return true
  end
  Pane.cursorSet = nil
  local reset = globalFn("ResetCursor")
  if reset and pcall(reset) then
    return true
  end
  local set = globalFn("SetCursor")
  return set ~= nil and (pcall(set, nil))
end
Pane.SetPanCursor = setPanCursor

-- Whether the pointer is on the viewport itself now, no card, reagent, header or button over it:
-- our own frame's IsMouseMotionFocus (SimpleScriptRegionAPIDocumentation.lua:493, branch forever),
-- read through Util.CanRead (bible B10), else what its OnEnter and OnLeave last said.
local function pointerOnCanvas()
  local viewport = Pane.viewport
  if type(viewport) == "table" and type(viewport.IsMouseMotionFocus) == "function" then
    local ok, focus = pcall(viewport.IsMouseMotionFocus, viewport)
    local util = ItemTree.Util
    local readable = type(util) ~= "table" or type(util.CanRead) ~= "function" or util.CanRead(focus)
    if ok and readable and type(focus) == "boolean" then
      Pane.overCanvas = focus
    end
  end
  return Pane.overCanvas == true
end

--- Brief UI15: puts the pointer in the pan cursor, or back, by Pane.WantsPanCursor, while the tab
--- shows a canvas. fresh asks the client where the pointer is (a press has just let go). Answers
--- whether the pan cursor is on.
function Pane.SyncCursor(fresh)
  local over = Pane.overCanvas == true
  if fresh then
    over = pointerOnCanvas()
  end
  setPanCursor(Pane.shown == true and Pane.layout ~= nil and Pane.WantsPanCursor(over, Pane.press))
  return Pane.cursorSet == true
end

-- The viewport's own hover, from our frame's OnEnter and OnLeave.
local function onViewportEnter()
  Pane.overCanvas = true
  Pane.SyncCursor()
end

local function onViewportLeave()
  Pane.overCanvas = false
  Pane.SyncCursor()
end

--------------------------------------------------------------------------------
-- A press: a click, or a pan once it moves (the owner's rule, 2026-10-01)
--------------------------------------------------------------------------------

local function enableButton(frame, on)
  local method = on and frame.Enable or frame.Disable
  if type(method) == "function" then
    pcall(method, frame)
  end
end

-- After a pan the frame's own click is swallowed; a frame whose release landed elsewhere is let
-- go of on the next frame, and a Craft button a pan disabled is given back its own state then.
local function settle(frame)
  local function clear()
    frame.swallow = nil
    if rawget(frame, "craftHeld") then
      frame.craftHeld = nil
      enableButton(frame, rawget(frame, "wantEnabled") ~= false)
    end
  end
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" and pcall(timer.After, 0, clear) then
    return true
  end
  clear()
  return false
end

local function mouseDown()
  local isDown = globalFn("IsMouseButtonDown")
  if not isDown then
    return true
  end
  local ok, down = pcall(isDown, "LeftButton")
  return not ok or down ~= false
end

local function endPress()
  local press = Pane.press
  Pane.press = nil
  if Pane.canvas then
    setScript(Pane.canvas, "OnUpdate", nil)
  end
  if press and press.dragging and type(press.frame) == "table" and press.frame ~= Pane.viewport then
    settle(press.frame)
  end
  -- Brief UI15: the pan cursor stays only where the pointer was let go over bare canvas.
  Pane.SyncCursor(true)
  return press
end
Pane.EndPress = endPress

local function onPressUpdate()
  local press = Pane.press
  if not press then
    return endPress()
  end
  if not mouseDown() then
    return endPress()
  end
  local x, y = cursorPoint()
  if not x then
    return false
  end
  local dx, dy = x - press.x, y - press.y
  if not press.dragging and (press.immediate or Pane.PastThreshold(dx, dy, Pane.DRAG_THRESHOLD)) then
    press.dragging = true
    hideTooltip()
    local frame = press.frame
    if type(frame) == "table" and frame ~= Pane.viewport then
      frame.swallow = true
      if rawget(frame, "isCraft") then
        frame.craftHeld = true
        enableButton(frame, false)
      end
    end
    -- Brief UI15: a press that has become a pan wears the pan cursor, wherever it started.
    Pane.SyncCursor()
  end
  if press.dragging then
    -- Screen y runs up and the pan runs down, so the vertical delta is taken the other way.
    applyPan(press.panX + dx, press.panY - dy)
  end
  return true
end
Pane.OnPressUpdate = onPressUpdate

--- A left press on one of the pane's own frames (a card, a reagent, a header, the Craft button)
--- or on bare canvas (immediate: a pan from the first pixel). Watches the cursor from the canvas's
--- OnUpdate until it lets go.
function Pane.BeginPress(frame, button, immediate)
  if button and button ~= "LeftButton" then
    return false
  end
  local x, y = cursorPoint()
  if not x or not Pane.canvas then
    return false
  end
  if type(frame) == "table" and frame ~= Pane.viewport then
    frame.swallow = nil
  end
  Pane.press = {
    frame = frame,
    x = x,
    y = y,
    panX = Pane.panX or 0,
    panY = Pane.panY or 0,
    immediate = immediate == true,
  }
  setScript(Pane.canvas, "OnUpdate", onPressUpdate)
  -- Brief UI15: a press on bare canvas pans from its first pixel, so it wears the pan cursor now.
  Pane.SyncCursor()
  return true
end

local function onFrameMouseDown(self, button)
  Pane.BeginPress(self, button)
end

local function onFrameMouseUp()
  endPress()
end

-- The shared press handlers on one of our frames.
local function pressable(frame)
  setScript(frame, "OnMouseDown", onFrameMouseDown)
  setScript(frame, "OnMouseUp", onFrameMouseUp)
end

-- Whether a click is the tail of a pan, and so swallowed. Clears the mark as it reads it.
local function swallowed(frame)
  if rawget(frame, "swallow") then
    frame.swallow = nil
    return true
  end
  return false
end

--------------------------------------------------------------------------------
-- The canvas
--------------------------------------------------------------------------------

-- Brief PR21 (the owner: "Tell the user simply what it does"): the button's label as the title.
-- The owner, 2026-10-02: then what it does and the one coloured status line
-- (Pane.CraftTooltipLines). Shown on a disabled button too (SetMotionScriptsWhileDisabled).
local function craftTooltip(owner)
  local state = rawget(owner, "craftState")
  if type(state) ~= "table" then
    return false
  end
  return textTooltip(owner, tostring(state.label or ""), Pane.CraftTooltipLines(state))
end

-- Brief PR17: the Create all button is the window's red plate button (UI\Skin.lua Skin.PlateButton
-- over Frame.NewPlateButton, the Recent button's art), its words on the plate's child frame above
-- the additive highlight; the flat face and hairline edges where the window has no plate helper.
local function buildCraftButton(parent)
  local s = skin()
  local button = s and type(s.PlateButton) == "function" and s.PlateButton(parent, 40, Pane.CRAFT_H) or nil
  if not button then
    button = newFrame("Button", parent)
    if not button then
      return nil
    end
    button:SetHeight(Pane.CRAFT_H)
    button.face = wash(button, "BACKGROUND", Pane.NODE_FACE)
    if button.face then
      button.face:SetAllPoints(button)
    end
    button.edges = edges(button)
    if button.edges then
      paintEdges(button, button.edges, Pane.PLAIN_BORDER, Pane.HAIRLINE)
    end
    button.hover = wash(button, "HIGHLIGHT", Pane.HOVER)
    if button.hover then
      button.hover:SetAllPoints(button)
    end
    if type(button.RegisterForClicks) == "function" then
      pcall(button.RegisterForClicks, button, "LeftButtonUp")
    end
  end
  button.isCraft = true
  button.canPress = true
  -- Brief PR23: a disabled Button fires no OnEnter or OnLeave unless told to, and the faded
  -- Create all is a real Disable(), so its hover (why it cannot) needs this. Our own frame.
  if type(button.SetMotionScriptsWhileDisabled) == "function" then
    pcall(button.SetMotionScriptsWhileDisabled, button, true)
  end
  button.label = newText(rawget(button, "labelParent") or button, Pane.FONT_SM, Pane.PLATE_WORD, "CENTER")
  if button.label then
    button.label:SetPoint("LEFT", button, "LEFT", 4, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -4, 0)
  end
  -- Brief PR14's contract: the click is a hardware event and Craft.Click is the first call in it.
  -- A pan that started on the button disables it until the release has passed (settle), so a
  -- drag never crafts.
  setScript(button, "OnClick", function(self)
    local craft = Professions.craft
    if type(craft) == "table" and type(craft.Click) == "function" then
      craft.Click(rawget(self, "line"), rawget(self, "bandIndex"), Pane.track)
    end
  end, true)
  if button.plated and type(s.PlateScripts) == "function" then
    -- The plate paints its own states first, then the press (a pan from the button) and the hover.
    s.PlateScripts(button, setScript, {
      OnMouseDown = onFrameMouseDown,
      OnMouseUp = onFrameMouseUp,
      OnEnter = craftTooltip,
      OnLeave = hideTooltip,
    })
  else
    pressable(button)
    setScript(button, "OnEnter", craftTooltip)
    setScript(button, "OnLeave", hideTooltip)
  end
  return button
end

local function buildHeader()
  local frame = newFrame("Frame", Pane.canvas)
  if not frame then
    return nil
  end
  frame.face = wash(frame, "BACKGROUND", Pane.HEADER_FILL)
  if frame.face then
    frame.face:SetAllPoints(frame)
  end
  frame.edges = edges(frame)
  frame.label = newText(frame, Pane.FONT_MD, Pane.BAND_WORD, "LEFT")
  -- Brief PR48: a gathering band's suggestion, one muted line under the row.
  frame.smeltLine = newText(frame, Pane.FONT_SM, Pane.MUTED_WORD, "LEFT")
  setShown(frame.smeltLine, false)
  frame.tick = newTexture(frame, "OVERLAY")
  if frame.tick then
    frame.tick:SetSize(Pane.TICK, Pane.TICK)
  end
  frame.notch = newTexture(frame, "OVERLAY", 2)
  -- The info mark: its own hover carries the band's note (brief PR13), so the note takes no height.
  local info = newFrame("Frame", frame)
  if info then
    info:SetSize(Pane.INFO, Pane.INFO)
    info.icon = newTexture(info, "OVERLAY")
    if info.icon then
      info.icon:SetAllPoints(info)
    end
    if type(info.EnableMouse) == "function" then
      pcall(info.EnableMouse, info, true)
    end
    setScript(info, "OnEnter", function(self)
      local note = rawget(self, "note")
      if note then
        textTooltip(self, rawget(self, "title"), { note })
      end
    end)
    setScript(info, "OnLeave", hideTooltip)
    pressable(info)
  end
  frame.info = info
  frame.craft = buildCraftButton(frame)
  if type(frame.EnableMouse) == "function" then
    pcall(frame.EnableMouse, frame, true)
  end
  -- The band's full name on hover; brief PR48: and its suggestion in full, where it has one.
  -- Brief PR49b: and a re-planned band's Classic steps gone grey here, and why its order changed.
  setScript(frame, "OnEnter", function(self)
    local lines = Pane.HeaderLines(rawget(self, "smeltText"), rawget(self, "wasText"), rawget(self, "rerankText"))
    textTooltip(self, rawget(self, "titleText"), lines)
  end)
  setScript(frame, "OnLeave", hideTooltip)
  pressable(frame)
  return frame
end

-- The Craft button's state for a band from PR14's module, or nil where there is no module.
local function craftState(line, index)
  local craft = craftModule()
  if not craft then
    return nil
  end
  -- Brief TP1: a tracked profession is browsed, never crafted: the character does not have it.
  if type(Pane.chosen) == "table" and Pane.chosen.tracked == true then
    return nil
  end
  local ok, state = pcall(craft.ButtonState, line, index, Pane.track)
  if ok and type(state) == "table" then
    return state
  end
  return nil
end

-- Brief PR48: anchors a region by its right edge on the header's row, x px in from the right: the
-- header's middle as ever, or the top row's middle where the header is tall with a note line.
local function rowPoint(region, frame, x)
  if rawget(frame, "tall") then
    region:SetPoint("RIGHT", frame, "TOPRIGHT", -x, -Pane.HEADER_H / 2)
  else
    region:SetPoint("RIGHT", frame, "RIGHT", -x, 0)
  end
end

local function fillCraft(frame, column)
  local button = frame.craft
  if not button then
    return 0
  end
  local state = craftState(Pane.selected, column.index)
  button.craftState = state
  button.line, button.bandIndex = Pane.selected, column.index
  if not state or state.shown ~= true then
    button:Hide()
    return 0
  end
  setText(button.label, state.label or "")
  -- Brief PR16: the label always fits ("Craft all"); never cut.
  local width = (stringWidth(button.label) or #tostring(state.label or "") * 6) + 16
  width = math.max(width, 40)
  button:SetWidth(width)
  button:ClearAllPoints()
  rowPoint(button, frame, Pane.CARD_INSET)
  button.wantEnabled = state.enabled == true
  if not rawget(button, "craftHeld") then
    enableButton(button, state.enabled == true)
  end
  textColour(button.label, state.enabled and Pane.PLATE_WORD or Pane.MUTED_WORD)
  -- Brief PR16: faded while it cannot craft, its hover still saying why (the owner asked for the
  -- fade; the no dim rule is about the recipes and their words). Brief PR17: the faded plate
  -- never lights or goes down under the pointer.
  button.canPress = state.enabled == true
  local s = skin()
  if button.plated and s and type(s.PaintPlate) == "function" then
    s.PaintPlate(button, "normal")
  end
  -- Brief PR19: never faded twice; a done band's header already fades its button.
  button.craftAlpha = Pane.CraftAlpha(state.enabled == true, rawget(frame, "headerAlpha"))
  if type(button.SetAlpha) == "function" then
    pcall(button.SetAlpha, button, button.craftAlpha)
  end
  button:Show()
  return width + Pane.SMALL_PAD
end

local function fillHeader(frame, column)
  local band = column.band
  local rect = column.header
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", Pane.canvas, "TOPLEFT", rect.x, -rect.y)
  frame:SetSize(rect.w, rect.h)
  -- Brief PR48: a header taller than one row (a gathering line with notes) keeps its row on top
  -- and draws the band's suggestion under it.
  frame.tall = rect.h > Pane.HEADER_H or nil
  local current = column.current == true
  frame.isCurrent = current
  paintCard(frame, rect.w, rect.h, current and "current" or "header")
  -- Brief PR17: a done band's header is faded with its cards; its hovers and Create all still work.
  frame.headerAlpha = Pane.HeaderAlpha(band)
  setAlpha(frame, frame.headerAlpha)
  -- Brief PR16: "30 to 45" on the header; the full "Leatherworking 30 to 45" on its hovers.
  frame.labelText = Pane.BandText(band)
  frame.titleText = Pane.BandTitle(Pane.lineName, band)
  setText(frame.label, frame.labelText)
  -- The right hand side, right to left: the Craft button, the done tick, the info mark.
  local right = Pane.CARD_INSET + fillCraft(frame, column)
  local done = band.state == "done"
  frame.done = done
  if frame.tick then
    local drawn = done and applyAsset(frame.tick, "ICON_CHECK")
    if drawn then
      tint(frame.tick, Pane.DONE_TICK)
      frame.tick:ClearAllPoints()
      rowPoint(frame.tick, frame, right)
      right = right + Pane.TICK + Pane.SMALL_PAD
    end
    setShown(frame.tick, drawn == true)
  end
  local note = Pane.BandNote(band)
  -- Brief PR49b: a re-planned band's Classic steps gone grey here, on the heading's hover and on
  -- the info mark's where the band has no other note.
  frame.wasText = Pane.WasText(Pane.names, band)
  frame.rerankText = band.reranked == true and Pane.WORDS.reranked or nil
  local info = frame.info
  if info then
    info.note, info.title = note or frame.wasText, frame.titleText
    if info.note and applyAsset(info.icon, "BADGE_INFO") then
      info:ClearAllPoints()
      rowPoint(info, frame, right)
      right = right + Pane.INFO + Pane.SMALL_PAD
      info:Show()
    else
      info:Hide()
    end
  end
  frame.noteText = note
  if frame.label then
    frame.label:ClearAllPoints()
    if frame.tall then
      frame.label:SetPoint("LEFT", frame, "TOPLEFT", Pane.CARD_INSET, -Pane.HEADER_H / 2)
    else
      frame.label:SetPoint("LEFT", frame, "LEFT", Pane.CARD_INSET, 0)
    end
    rowPoint(frame.label, frame, right)
  end
  -- Brief PR48: the gathering band's suggestion, the full words on the header's hover too.
  -- Brief G1c: the smelting sentence only, never the gather words.
  frame.smeltText = Pane.HeadingNote(Pane.names, band)
  local line = frame.smeltLine
  if line then
    if frame.tall and frame.smeltText then
      line:ClearAllPoints()
      line:SetPoint("TOPLEFT", frame, "TOPLEFT", Pane.CARD_INSET, -Pane.HEADER_H + 2)
      line:SetPoint("RIGHT", frame, "RIGHT", -Pane.CARD_INSET, 0)
      setText(line, frame.smeltText)
      line:Show()
    else
      setShown(line, false)
    end
  end
  -- The player's place along the current band: a small notch on the header's bottom edge.
  if frame.notch then
    if current and column.tickX and applyAsset(frame.notch, "ICON_CHEVRON_COLLAPSE") then
      tint(frame.notch, Pane.ROUTE_GOLD)
      local x = math.min(math.max(column.tickX - rect.x, Pane.NOTCH / 2), rect.w - Pane.NOTCH / 2)
      frame.notch:ClearAllPoints()
      frame.notch:SetSize(Pane.NOTCH, Pane.NOTCH)
      frame.notch:SetPoint("CENTER", frame, "BOTTOMLEFT", x, 1)
      frame.notchX = x
      frame.notch:Show()
    else
      frame.notchX = nil
      frame.notch:Hide()
    end
  end
  frame:Show()
end

local function buildReagent(parent)
  local slot = newFrame("Button", parent)
  if not slot then
    return nil
  end
  slot:SetSize(Pane.REAGENT, Pane.REAGENT)
  slot.icon = newTexture(slot, "ARTWORK")
  if slot.icon then
    slot.icon:SetAllPoints(slot)
  end
  slot.edges = edges(slot)
  -- The owner, 2026-10-02: a highlight on hover, so the icon reads as clickable.
  slot.hover = wash(slot, "HIGHLIGHT", Pane.HOVER)
  if slot.hover then
    slot.hover:SetAllPoints(slot)
  end
  slot.count = newText(parent, Pane.FONT_SM, Pane.NAME_WORD, "LEFT")
  if slot.count then
    slot.count:SetWidth(Pane.COUNT_W)
  end
  if type(slot.RegisterForClicks) == "function" then
    pcall(slot.RegisterForClicks, slot, "LeftButtonUp", "RightButtonUp")
  end
  setScript(slot, "OnEnter", function(self)
    local key = rawget(self, "key")
    if key then
      Pane.MaterialTooltip(self, key, rawget(self, "name"), rawget(self, "short"))
    end
  end)
  setScript(slot, "OnLeave", hideTooltip)
  setScript(slot, "OnClick", function(self, button)
    if swallowed(self) then
      return
    end
    Pane.ClickMaterial(rawget(self, "key"), button)
  end)
  pressable(slot)
  return slot
end

local function buildTag(parent)
  local tag = newFrame("Frame", parent)
  if not tag then
    return nil
  end
  if type(tag.SetFrameLevel) == "function" and type(parent.GetFrameLevel) == "function" then
    local ok, level = pcall(parent.GetFrameLevel, parent)
    if ok and tonumber(level) then
      pcall(tag.SetFrameLevel, tag, tonumber(level) + 3)
    end
  end
  -- Brief PR17: solid card gold, the flat fill where the chamfered card will not draw.
  tag.fill = wash(tag, "BACKGROUND", Pane.CARD_GOLD)
  if tag.fill then
    tag.fill:SetAllPoints(tag)
  end
  tag.text = newTagText(tag)
  if tag.text then
    tag.text:SetPoint("CENTER", tag, "CENTER", 0, 0)
  end
  return tag
end

-- Brief PR49c: the Changed badge right of a recipe card's name: our own frame on our own card,
-- motion only (clicks pass through to the card, as the item rows' badges do: UI/Badges.lua
-- enableHover's shape, SetPropagateMouseClicks booked after combat through Badges.PropagateClicks
-- where ItemTree's Badges is loaded). Its hover is the one sentence it stands for.
local function propagateClicks(frame)
  local badges = ItemTree.Badges
  if type(badges) == "table" and type(badges.PropagateClicks) == "function" then
    pcall(badges.PropagateClicks, frame)
    return
  end
  local lockdown = rawget(_G, "InCombatLockdown")
  if type(lockdown) == "function" then
    local ok, locked = pcall(lockdown)
    if not ok or locked then
      return
    end
  end
  if type(frame.SetPropagateMouseClicks) == "function" then
    pcall(frame.SetPropagateMouseClicks, frame, true)
  end
end

local function buildBadge(parent)
  local badge = newFrame("Frame", parent)
  if not badge then
    return nil
  end
  badge:SetSize(Pane.BADGE, Pane.BADGE)
  badge.art = newTexture(badge, "ARTWORK")
  if badge.art then
    badge.art:SetPoint("CENTER", badge, "CENTER", 0, 0)
    badge.art:SetSize(Pane.BADGE_ART, Pane.BADGE_ART)
  end
  local mouse = { { "EnableMouse", true }, { "SetMouseMotionEnabled", true }, { "SetMouseClickEnabled", false } }
  for _, call in ipairs(mouse) do
    local method = badge[call[1]]
    if type(method) == "function" then
      pcall(method, badge, call[2])
    end
  end
  propagateClicks(badge)
  setScript(badge, "OnEnter", function(self)
    local text = rawget(self, "greyText")
    if text then
      textTooltip(self, text)
      return
    end
    -- Brief TB14: the New badge says what the main window's New badge says.
    local kind = rawget(self, "newKind")
    if kind then
      textTooltip(self, Pane.NewHover(kind))
    end
  end)
  setScript(badge, "OnLeave", hideTooltip)
  badge:Hide()
  return badge
end

-- Brief TB14: whether the player keeps New badges on (ItemTree's "Show New badges", the setting
-- the main window's rows read), on where nothing says.
local function newBadgesOn()
  local db = ItemTree.db
  local settings = type(db) == "table" and type(db.settings) == "table" and db.settings or EMPTY
  return settings.badgesNew ~= false
end

-- Brief PR49c: the badge after the name's words where the recipe goes grey at another rank on
-- Classic Era (Pane.GreyText), the name cut short to leave it room; hidden on every other card.
-- Brief TB14: and the New badge (Pane.NewKind) on a recipe or gathering card that is new in
-- Forever, New first, then Changed beside it, the name cut short to leave both their room. rects
-- is the card's (Pane.CardRects) or a gathering card's { name = Pane.SpotNameRect(...) }.
local function fillBadge(frame, node, rects)
  local badge, newBadge = frame.badge, frame.newBadge
  local text = node and Pane.GreyText(node) or nil
  local newKind = node and newBadgesOn() and Pane.NewKind(node) or nil
  frame.greyText = text
  frame.newKind = newKind
  frame.badgeRect, frame.newBadgeRect = nil, nil
  if badge then
    badge.greyText = text
  end
  if newBadge then
    newBadge.newKind = newKind
  end
  local drawGrey = text ~= nil and badge ~= nil
  local drawNew = newKind ~= nil and newBadge ~= nil
  local nameRect = type(rects) == "table" and rects.name or nil
  if not nameRect or not frame.name then
    drawGrey, drawNew = false, false
  end
  if not drawGrey then
    setShown(badge, false)
  end
  if not drawNew then
    setShown(newBadge, false)
  end
  if not (drawGrey or drawNew) then
    return
  end
  local count = (drawGrey and 1 or 0) + (drawNew and 1 or 0)
  local placed, first, second = Pane.NameBadgeRects(nameRect, stringWidth(frame.name), nil, nil, count)
  at(frame.name, frame, placed)
  if drawNew then
    local art = newKind == "sod" and "BADGE_ART_SOD" or "BADGE_ART_NEW"
    setShown(newBadge.art, applyAsset(newBadge.art, art))
    at(newBadge, frame, first)
    frame.newBadgeRect = first
    newBadge:Show()
  end
  if drawGrey then
    local spot = drawNew and second or first
    setShown(badge.art, applyAsset(badge.art, "BADGE_ART_CHANGED"))
    at(badge, frame, spot)
    frame.badgeRect = spot
    badge:Show()
  end
end

-- Brief SC1 (QA item 212): the Show craft button's state for a card now, from Craft's contract
-- (Core\Craft.lua Craft.ShowButton): the line on screen, the card's lock and its name. nil where
-- Craft has no Show craft contract.
local function showState(card)
  local craft = Professions.craft
  if type(craft) ~= "table" or type(craft.ShowButton) ~= "function" or type(craft.ShowCraft) ~= "function" then
    return nil
  end
  -- Brief SC2: and the card's spell, for the fill's checks (Craft.FillCheck).
  local ok, state =
    pcall(craft.ShowButton, Pane.selected, rawget(card, "lock"), rawget(card, "nameText"), rawget(card, "spell"))
  if ok and type(state) == "table" then
    return state
  end
  return nil
end

-- Brief SC1: its hover, Craft all's shape (the label as the title, what it does, then why not),
-- asked afresh each time, so combat and the window read as they are now. Shown on a faded button
-- too (SetMotionScriptsWhileDisabled).
local function showCraftTooltip(owner)
  local card = rawget(owner, "card")
  local state = type(card) == "table" and showState(card) or nil
  if not state then
    return false
  end
  return textTooltip(owner, tostring(state.label or ""), Pane.ShowTooltipLines(state))
end

-- Brief SC1: the card's Show craft button, built with the card (never lazily): the window's red
-- plate button as Craft all's (Skin.PlateButton), its words on the plate's child frame above the
-- additive highlight; the flat face and hairline edges where the window has no plate helper. A
-- pan that starts on it disables it until the release has passed (isCraft, settle), as Craft
-- all's, so a drag never opens a window.
local function buildShowButton(parent)
  local s = skin()
  local button = s and type(s.PlateButton) == "function" and s.PlateButton(parent, Pane.SHOW_W, Pane.SHOW_H) or nil
  if not button then
    button = newFrame("Button", parent)
    if not button then
      return nil
    end
    button:SetSize(Pane.SHOW_W, Pane.SHOW_H)
    button.face = wash(button, "BACKGROUND", Pane.NODE_FACE)
    if button.face then
      button.face:SetAllPoints(button)
    end
    button.edges = edges(button)
    if button.edges then
      paintEdges(button, button.edges, Pane.PLAIN_BORDER, Pane.HAIRLINE)
    end
    button.hover = wash(button, "HIGHLIGHT", Pane.HOVER)
    if button.hover then
      button.hover:SetAllPoints(button)
    end
    if type(button.RegisterForClicks) == "function" then
      pcall(button.RegisterForClicks, button, "LeftButtonUp")
    end
  end
  button.card = parent
  button.isCraft = true
  button.canPress = true
  if type(button.SetMotionScriptsWhileDisabled) == "function" then
    pcall(button.SetMotionScriptsWhileDisabled, button, true)
  end
  button.label = newText(rawget(button, "labelParent") or button, Pane.FONT_SM, Pane.PLATE_WORD, "CENTER")
  if button.label then
    button.label:SetPoint("LEFT", button, "LEFT", 4, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -4, 0)
  end
  -- Brief PR14's contract, kept for this button: the click is a hardware event and
  -- Craft.ShowCraft is the first call in it.
  setScript(button, "OnClick", function(self)
    local craft = Professions.craft
    if type(craft) == "table" and type(craft.ShowCraft) == "function" then
      -- Brief PW1 (QA item 239 c): the card's recipe too, for the window's search.
      local card = rawget(self, "card") or EMPTY
      craft.ShowCraft(rawget(self, "line"), rawget(card, "spell"), rawget(card, "nameText"))
    end
  end, true)
  if button.plated and type(s.PlateScripts) == "function" then
    s.PlateScripts(button, setScript, {
      OnMouseDown = onFrameMouseDown,
      OnMouseUp = onFrameMouseUp,
      OnEnter = showCraftTooltip,
      OnLeave = hideTooltip,
    })
  else
    pressable(button)
    setScript(button, "OnEnter", showCraftTooltip)
    setScript(button, "OnLeave", hideTooltip)
  end
  button:Hide()
  return button
end

local function buildNode()
  local frame = newFrame("Button", Pane.canvas)
  if not frame then
    return nil
  end
  frame.face = wash(frame, "BACKGROUND", Pane.CARD_FILL)
  if frame.face then
    frame.face:SetAllPoints(frame)
  end
  frame.edges = edges(frame)
  frame.hover = wash(frame, "HIGHLIGHT", Pane.HOVER)
  if frame.hover then
    frame.hover:SetAllPoints(frame)
  end
  frame.icon = newTexture(frame, "ARTWORK")
  frame.difficulty = newTexture(frame, "OVERLAY")
  frame.difficultyText = newText(frame, Pane.FONT_SM, Pane.NAME_WORD, "RIGHT")
  frame.name = newText(frame, Pane.FONT_MD, Pane.NAME_WORD, "LEFT")
  -- Brief PR48: a gathering band's smelt card's muted word lines, hidden on every other card.
  frame.words = {}
  for index = 1, Pane.WORD_LINES do
    local line = newText(frame, Pane.FONT_SM, Pane.MUTED_WORD, "LEFT")
    setShown(line, false)
    frame.words[index] = line
  end
  frame.tag = buildTag(frame)
  frame.badge = buildBadge(frame)
  -- Brief TB14: the New badge, built with the card like the Changed one, never lazily.
  frame.newBadge = buildBadge(frame)
  frame.reagents = {}
  for index = 1, Pane.REAGENT_MAX do
    local slot = buildReagent(frame)
    if slot then
      slot:Hide()
      if slot.count then
        slot.count:Hide()
      end
    end
    frame.reagents[index] = slot
  end
  -- Brief SC1: the Show craft button, built with the card like its badges, never lazily.
  frame.showButton = buildShowButton(frame)
  if type(frame.RegisterForClicks) == "function" then
    pcall(frame.RegisterForClicks, frame, "LeftButtonUp", "RightButtonUp")
  end
  setScript(frame, "OnEnter", function(self)
    if rawget(self, "material") then
      Pane.MaterialTooltip(self, rawget(self, "key"), rawget(self, "nameText"))
    elseif Pane.IsLocked(rawget(self, "lock")) then
      showTooltip(self, rawget(self, "key"), rawget(self, "nameText"), { Pane.WORDS.seeLearn })
    else
      -- Brief PRX (PR44): an alternative's hover adds what it would take on its own. Brief PR49b:
      -- and the card's route lines and its cost at auction house prices, where it has them.
      local extra = Pane.HoverLines(rawget(self, "alone"), rawget(self, "routeLines"))
      showTooltip(self, rawget(self, "key"), rawget(self, "nameText"), extra)
    end
  end)
  setScript(frame, "OnLeave", hideTooltip)
  setScript(frame, "OnClick", function(self, button)
    if swallowed(self) then
      return
    end
    -- A gathered item's row is a material: its Sources view. A recipe card keeps the default.
    -- A locked card opens where to learn its recipe (the owner, 2026-10-02).
    if rawget(self, "material") then
      Pane.ClickMaterial(rawget(self, "key"), button)
    elseif Pane.IsLocked(rawget(self, "lock")) then
      Pane.ClickLocked(rawget(self, "key"), rawget(self, "spell"), button)
    else
      -- Brief PR37: a gathering line's zone spot opens on its Map tab's group (Pane.ZoneOpenOpts).
      Pane.Click(rawget(self, "key"), button, rawget(self, "openOpts"))
    end
  end)
  pressable(frame)
  return frame
end

-- Brief PB1: one reagent slot's count words, read from the client now: against the card's need
-- (slot.need), bags and bank, where it has one (brief PR9), else against one craft's count
-- (slot.per), bags only. Brief PR37: the have count against one craft's sets the colour and the
-- short its hover says; brief PRX (PR43): on every card. Answers whether the words changed since
-- the slot was last drawn (false for a slot that holds no reagent).
local function drawCount(slot)
  local itemId = type(slot) == "table" and tonumber(rawget(slot, "itemId")) or nil
  if not itemId then
    return false
  end
  local per = tonumber(rawget(slot, "per")) or 1
  local need = tonumber(rawget(slot, "need"))
  local have
  if need then
    have = bagCount(itemId, true)
  else
    have = bagCount(itemId)
  end
  local text = Pane.ReagentText(have, need or per, per)
  local changed = rawget(slot, "countText") ~= text
  setText(slot.count, text)
  slot.countText = text
  slot.short = Pane.ReagentShort(have, per)
  slot.countColour = Pane.ReagentColour(slot.short)
  textColour(slot.count, slot.countColour)
  return changed
end

-- Brief PRX (PR44): crafts is the card's plan crafts (planCrafts); brief PR46 an alternative's
-- crafts alone in its band (bandAloneCrafts); nil for any other card. PR43: a reagent short for
-- one craft reads red on every card.
local function fillReagents(frame, node, isRoute, rects, crafts)
  local list = type(node.re) == "table" and node.re or EMPTY
  local colourKey = Pane.BorderFor(isRoute)
  local names = Pane.names
  for index = 1, Pane.REAGENT_MAX do
    local slot = frame.reagents[index]
    local reagent = list[index]
    local rect = rects and rects[index] or nil
    if slot then
      if rect and type(reagent) == "table" and tonumber(reagent[1]) then
        local itemId = tonumber(reagent[1])
        slot.key = "item:" .. itemId
        slot.name = Pane.ItemName(names, itemId, false)
        applyIconFile(slot.icon, itemIcon(itemId))
        paintEdges(slot, slot.edges, colourKey, Pane.HAIRLINE)
        slot.route = isRoute
        slot.rect = rect.icon
        at(slot, frame, rect.icon)
        -- Brief PR9: a route recipe's reagent shows its need, bags and bank; any other recipe's
        -- shows one craft's, from the bags. Brief PRX (PR44): the need is the band plan's (the
        -- plan pick's crafts x one craft's count), never the route's whole need, which only the
        -- tooltip's Keep line gives. Brief PR46: an alternative (several route recipes share the
        -- band) shows its own crafts alone x one craft's count, which its hover explains.
        -- The owner, 2026-10-02: one craft's count after it in brackets.
        -- Brief PB1: what the count is read against is kept on the slot, so a bag event redraws
        -- the words alone (Pane.RefreshCounts).
        slot.itemId = itemId
        slot.per = tonumber(reagent[2]) or 1
        slot.need = Pane.CardNeed(crafts, slot.per)
        slot.countText = nil
        drawCount(slot)
        if slot.count then
          slot.count:ClearAllPoints()
          slot.count:SetPoint("TOPLEFT", frame, "TOPLEFT", rect.count.x, -rect.count.y)
          slot.count:SetSize(rect.count.w, rect.count.h)
          slot.countRect = rect.count
        end
        slot:Show()
        setShown(slot.count, true)
      else
        slot.key, slot.name, slot.route, slot.rect, slot.countRect = nil, nil, nil, nil, nil
        slot.short, slot.countColour = nil, nil
        slot.itemId, slot.per, slot.need, slot.countText = nil, nil, nil, nil
        slot:Hide()
        setShown(slot.count, false)
      end
    end
  end
end

local function fillDifficulty(frame, colour, rect)
  local mark = Pane.DifficultyFor(colour)
  frame.difficultyKey = mark and mark.key or nil
  frame.difficultyRect = mark and rect or nil
  local texture, words = frame.difficulty, frame.difficultyText
  if not mark then
    setShown(texture, false)
    setShown(words, false)
    return nil
  end
  local s = skin()
  local isAtlas = mark.key ~= "PROFESSION_LOCK"
  local drawn = false
  if texture and (not isAtlas or (s and s.Has(mark.key))) then
    drawn = applyAsset(texture, mark.key)
  end
  if drawn then
    at(texture, frame, rect)
    if type(texture.SetDesaturated) == "function" then
      pcall(texture.SetDesaturated, texture, mark.grey == true or mark.lock == true)
    end
    if mark.grey then
      tint(texture, mark.colour)
    elseif mark.lock then
      -- Brief PR17: the padlock lifted to a pale gold, so it reads on the red card. Brief PR19: no
      -- alpha of its own; a dimmed card fades it with everything else on the card.
      if type(texture.SetDesaturated) == "function" then
        pcall(texture.SetDesaturated, texture, true)
      end
      tint(texture, Pane.LOCK_TINT)
    elseif type(texture.SetVertexColor) == "function" then
      texture:SetVertexColor(1, 1, 1, 1)
    end
    texture:Show()
    setShown(words, false)
    frame.difficultyDrawn = "art"
    return "art"
  end
  setShown(texture, false)
  if words then
    words:ClearAllPoints()
    words:SetPoint("TOPRIGHT", frame, "TOPLEFT", rect.x + rect.w, -rect.y)
    setText(words, mark.text)
    textColour(words, mark.colour)
    words:Show()
  end
  frame.difficultyDrawn = "text"
  return "text"
end

local function fillTag(frame, rect)
  local tag = frame.tag
  if not tag then
    return
  end
  if not rect then
    tag:Hide()
    frame.tagRect = nil
    return
  end
  setText(tag.text, Pane.WORDS.recommended)
  textColour(tag.text, Pane.TAG_WORD)
  frame.tagRect = rect
  at(tag, frame, rect)
  -- Brief PR17: the whole tag in the card's gold, dark words, a small bevel at each corner (the
  -- cards' own chamfer pieces, UI\Skin.lua Skin.Card); a square gold fill where that will not draw.
  -- Brief PR19: the client's thin border at a 5 px corner where it has the art.
  local s = skin()
  local drawn = s
      and type(s.Card) == "function"
      and s.Card(tag, rect.w, rect.h, {
        fill = Pane.CARD_GOLD,
        edge = Pane.CARD_GOLD,
        thickness = Pane.HAIRLINE,
        chamfer = Pane.TAG_CHAMFER,
        corner = Pane.TAG_CORNER,
        store = "tagPieces",
      })
    or false
  tag.skinned = drawn == true
  tag.fillKey = Pane.CARD_GOLD
  if not drawn then
    tint(tag.fill, Pane.CARD_GOLD)
  end
  setShown(tag.fill, not drawn)
  tag:Show()
end

-- Brief PR19: whether the player has learnt a recipe, by Craft's own rule (Core\Craft.lua
-- KnowsRecipe, then Known's open window list): true, false only where the open profession window
-- says not learnt, nil where nothing can say. Asked only for the cards drawn, and kept until the
-- next draw or until the window opens or shuts (Pane.windowOpen).
local function learntOf(spell)
  spell = tonumber(spell)
  local craft = Professions.craft
  if not spell or type(craft) ~= "table" or type(craft.KnowsRecipe) ~= "function" then
    return nil
  end
  Pane.learnt = type(Pane.learnt) == "table" and Pane.learnt or {}
  local hit = Pane.learnt[spell]
  if hit == "unknown" then
    return nil
  end
  if hit ~= nil then
    return hit
  end
  local open = Pane.windowOpen == true
  local answer = nil
  local ok, said = pcall(craft.KnowsRecipe, spell, open)
  if ok and (said == true or said == false) then
    answer = said
  end
  if answer == nil and open and type(craft.Known) == "function" then
    local fine, known = pcall(craft.Known, { { spell = spell } }, true)
    if fine and type(known) == "table" then
      answer = known[spell] == true
    end
  end
  if answer == nil then
    Pane.learnt[spell] = "unknown"
  else
    Pane.learnt[spell] = answer
  end
  return answer
end
Pane.LearntOf = learntOf

-- Brief PR19: a recipe node's lock (Pane.LockState), the learnt check asked only where the recipe
-- is in range.
local function lockOf(node)
  if type(node) ~= "table" or type(node.spot) == "table" or node.colour == nil then
    return nil
  end
  -- Brief PR24: the learnt check asked only where the recipe is in range.
  if node.colour == "unlearnable" then
    return Pane.LockState(node.colour, nil)
  end
  return Pane.LockState(node.colour, learntOf(node.spell))
end

-- Brief PR19: whether the profession window is open on the chosen line (Craft.IsOpen), which is
-- when a "not learnt" answer is believed. Answers whether it changed.
local function checkWindow()
  local craft = Professions.craft
  local open = false
  if type(craft) == "table" and type(craft.IsOpen) == "function" and Pane.selected ~= nil then
    local ok, answer = pcall(craft.IsOpen, Pane.selected, Pane.lineName)
    open = ok and answer == true
  end
  local changed = open ~= (Pane.windowOpen == true)
  Pane.windowOpen = open
  if changed then
    Pane.learnt = {}
  end
  return changed
end

-- Brief PR48: a gathering band's smelt card's muted lines (Pane.CardWords) under its reagents,
-- inside the extra height Pane.NodeHeight gave it; hidden on every other card. Brief G1c: WORD_GAP
-- below the reagents.
local function fillWords(frame, node, rects, crafts)
  local lines = node and Pane.CardWords(Pane.names, node, crafts) or EMPTY
  frame.wordsText = #lines > 0 and lines or nil
  local top = rects and (rects.h - Pane.CARD_INSET + Pane.WORD_GAP) or 0
  local textLeft = Pane.CARD_INSET * 2 + Pane.NODE_ICON
  for index, line in ipairs(type(frame.words) == "table" and frame.words or EMPTY) do
    local text = lines[index]
    if line and text then
      line:ClearAllPoints()
      line:SetPoint("TOPLEFT", frame, "TOPLEFT", textLeft, -(top + (index - 1) * Pane.WORD_LINE_H))
      line:SetPoint("RIGHT", frame, "RIGHT", -Pane.CARD_INSET, 0)
      setText(line, text)
      line:Show()
    else
      setShown(line, false)
    end
  end
end

-- Brief SC5: the Show craft label's font at size (Pane.ShowFontSize), the theme's body face as newText
-- set it; a call only where the size changes (newText made it at FONT_SM). Where the client will not
-- take the font, the label keeps the one it has.
local function showLabelSize(fontString, size)
  if type(fontString) ~= "table" or type(fontString.SetFont) ~= "function" then
    return
  end
  if (rawget(fontString, "showSize") or Pane.FONT_SM) == size then
    return
  end
  local t = theme()
  local face = t and t.fonts and t.fonts.ITEMTREE_FONT_BODY
  if not face then
    return
  end
  local ok, applied = pcall(fontString.SetFont, fontString, face, size, "")
  if ok and applied ~= false then
    fontString.showSize = size
  end
  ensureFont(fontString)
end

-- Brief SC1 (QA item 212): a card's Show craft button, on a recipe card (one with a spell; never a
-- gathering spot) where Craft has the contract: its state from Craft.ShowButton, faded with its
-- reason where it cannot (Pane.CraftAlpha: never faded twice on a faded card), as wide as its
-- words, at the card's bottom right (Pane.ShowRect; brief LF1: inside the card, in the row
-- Pane.NodeHeight adds for it). Hidden on every other card. Answers the state, or nil where hidden.
-- Brief SC5: its words say what this click does (Craft.ShowState's label: "Show craft" or "Find
-- recipe", the same on every card of the line), redrawn as the window's show, close and page change
-- relabel the pane (Craft's OnChange); its width stays the one "Show craft" gives.
local function fillShow(frame, rect)
  local button = rawget(frame, "showButton")
  if not button then
    return nil
  end
  local state = nil
  if rawget(frame, "spell") ~= nil and type(rect) == "table" then
    state = showState(frame)
  end
  button.showState = state
  button.line = Pane.selected
  if not state or state.shown ~= true then
    button:Hide()
    frame.showRect, button.showSeen = nil, nil
    return nil
  end
  -- Craft's OnChange runs on every settled bag move too: a button whose look would not change is
  -- left as it is.
  local status = type(state.status) == "table" and state.status.text or ""
  local seen = table.concat({
    tostring(state.label),
    tostring(state.enabled),
    tostring(status),
    tostring(Pane.selected),
    tostring(rect.w),
    tostring(rect.h),
    tostring(rawget(frame, "cardAlpha")),
  }, "|")
  if rawget(button, "showSeen") == seen and frame.showRect then
    return state
  end
  button.showSeen = seen
  -- Brief SC5: as wide as "Show craft" (state.base) whatever the words now ("Find recipe"), so the
  -- card never moves; words wider than its room take the font a step smaller (Pane.ShowFontSize).
  local base = state.base or state.label or ""
  showLabelSize(button.label, Pane.FONT_SM)
  setText(button.label, base)
  local width = (stringWidth(button.label) or #tostring(base) * 6) + 16
  width = math.max(width, 40)
  setText(button.label, state.label or "")
  local words = stringWidth(button.label) or #tostring(state.label or "") * 6
  showLabelSize(button.label, Pane.ShowFontSize(words, width))
  local spot = Pane.ShowRect(rect.w, rect.h, width)
  frame.showRect = spot
  at(button, frame, spot)
  local enabled = state.enabled == true
  button.wantEnabled = enabled
  if not rawget(button, "craftHeld") then
    enableButton(button, enabled)
  end
  textColour(button.label, enabled and Pane.PLATE_WORD or Pane.MUTED_WORD)
  button.canPress = enabled
  local s = skin()
  if button.plated and s and type(s.PaintPlate) == "function" then
    s.PaintPlate(button, "normal")
  end
  button.showAlpha = Pane.CraftAlpha(enabled, rawget(frame, "cardAlpha"))
  setAlpha(button, button.showAlpha)
  button:Show()
  return state
end

local function fillNode(frame, rect)
  local node = rect.node
  local names = Pane.names
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", Pane.canvas, "TOPLEFT", rect.x, -rect.y)
  frame:SetSize(rect.w, rect.h)
  -- Brief PR49b: the Recommended tag, the gold card and the gold reagent edges follow the model's
  -- recommended (a re-planned band's pick, never a recipe with no points); the plan's crafts
  -- follow the route as ever, and a re-planned band's alternatives (alt) count theirs alone.
  local isRoute = rect.recommended == true or (rect.recommended == nil and rect.route == true)
  local onPlan = rect.route == true or (type(node) == "table" and node.alt == true)
  frame.route = isRoute
  frame.key = Pane.NodeKey(node)
  frame.material = type(node.spot) == "table" and node.spot.k == "item" and frame.key ~= nil or nil
  frame.swallow = nil
  -- Brief PR17: a locked recipe's card is red tinted; a grey one and every card of a done band
  -- are faded, still hovered, clicked and dragged as ever. Brief PR21 (correcting PR19): red where
  -- the recipe is in range but not learnt, and red AND dimmed whole where it is above the rank.
  -- The fade is the card frame's one alpha: its art, tag, icons, words and padlock are children at
  -- full strength.
  local lock = lockOf(node)
  frame.lock = lock
  frame.spell = nil
  if type(node.spot) ~= "table" then
    frame.spell = tonumber(node.spell)
  end
  local kind = type(node.spot) == "table" and "card" or Pane.CardKind(isRoute, lock)
  paintCard(frame, rect.w, rect.h, kind)
  frame.cardAlpha =
    Pane.CardAlpha(type(node.spot) == "table" and nil or node.colour, rect.done == true, rect.current == true)
  -- Brief PR37: what a click on a zone spot hands the window's open, by the line on screen.
  frame.openOpts = nil
  if type(node.spot) == "table" then
    frame.openOpts = Pane.ZoneOpenOpts(Pane.selected, frame.key)
  end
  setAlpha(frame, frame.cardAlpha)
  local inset = Pane.CARD_INSET
  local textLeft = inset * 2 + Pane.NODE_ICON
  if type(node.spot) == "table" then
    local spot = node.spot
    frame.nameText = spotText(names, spot)
    if frame.icon then
      at(frame.icon, frame, { x = inset, y = (rect.h - Pane.NODE_ICON) / 2, w = Pane.NODE_ICON, h = Pane.NODE_ICON })
    end
    if spot.k == "item" then
      applyIconFile(frame.icon, itemIcon(spot.id))
    else
      applyIconFile(frame.icon, nil, Pane.SPOT_ICONS[spot.k] or "PROFESSION_ZONE")
    end
    frame.iconKey = spot.k ~= "item" and (Pane.SPOT_ICONS[spot.k] or "PROFESSION_ZONE") or nil
    -- Brief G1b: a planned band's item card says where its points start and end, one muted line
    -- under the name; a spot without s and g is drawn as ever, its name centred.
    local spotWords = Pane.SpotWords(spot, rect.bandLo)
    frame.spotText = spotWords
    if frame.name then
      frame.name:ClearAllPoints()
      if spotWords then
        frame.name:SetPoint("BOTTOMLEFT", frame, "LEFT", textLeft, 1)
        frame.name:SetPoint("BOTTOMRIGHT", frame, "RIGHT", -inset, 1)
      else
        frame.name:SetPoint("LEFT", frame, "LEFT", textLeft, 0)
        frame.name:SetPoint("RIGHT", frame, "RIGHT", -inset, 0)
      end
    end
    -- Brief PR13: a creature or a node has no page of ours, so it is neither clickable nor lit.
    setShown(frame.hover, frame.key ~= nil)
    setShown(frame.difficulty, false)
    setShown(frame.difficultyText, false)
    frame.difficultyKey, frame.difficultyRect = nil, nil
    fillTag(frame, nil)
    fillReagents(frame, EMPTY, false, nil, nil)
    fillWords(frame, nil, nil)
    local spotLine = type(frame.words) == "table" and frame.words[1] or nil
    if spotLine and spotWords then
      spotLine:ClearAllPoints()
      spotLine:SetPoint("TOPLEFT", frame, "LEFT", textLeft, -1)
      spotLine:SetPoint("TOPRIGHT", frame, "RIGHT", -inset, -1)
      setText(spotLine, spotWords)
      spotLine:Show()
    end
    frame.alone, frame.routeLines = nil, nil
    frame.cardRects = nil
    setText(frame.name, frame.nameText)
    -- Brief TB14: a gathering card new in Forever wears the New badge right of its name.
    fillBadge(frame, node, { name = Pane.SpotNameRect(rect.w, rect.h, spotWords ~= nil) })
  else
    frame.nameText = Pane.NodeName(names, node, isUndiscovered)
    local count = type(node.re) == "table" and #node.re or 0
    local tagW = nil
    if isRoute and frame.tag and frame.tag.text then
      setText(frame.tag.text, Pane.WORDS.recommended)
      local measured = stringWidth(frame.tag.text)
      tagW = measured and math.floor(measured + Pane.TAG_PAD + 0.5) or nil
    end
    local rects = Pane.CardRects(count, rect.w, isRoute, tagW)
    frame.cardRects = rects
    if frame.icon then
      at(frame.icon, frame, rects.icon)
    end
    if node.out then
      applyIconFile(frame.icon, itemIcon(node.out))
    else
      applyIconFile(frame.icon, spellIcon(node.spell), "CAT_ENCHANTING")
    end
    frame.iconKey = nil
    if frame.name then
      frame.name:ClearAllPoints()
      frame.name:SetPoint("TOPLEFT", frame, "TOPLEFT", rects.name.x, -rects.name.y)
      frame.name:SetSize(rects.name.w, rects.name.h)
    end
    setShown(frame.hover, frame.key ~= nil)
    -- Brief PR19: the padlock on both locks, out of range and not learnt.
    fillDifficulty(frame, lock and "unlearnable" or node.colour, rects.difficulty)
    fillTag(frame, rects.tag)
    -- Brief PRX (PR44): the band plan's crafts where this card is the pick, else the alone hover.
    -- Brief PR46: an alternative's card counts its own crafts alone, the number the hover explains.
    local crafts, alone = nil, nil
    if onPlan and not rect.done then
      crafts = planCrafts(rect.bandLo, node.spell)
      if not crafts then
        alone = bandAloneCrafts(rect.bandLo, node.spell)
      end
    end
    fillReagents(frame, node, isRoute, rects.reagents, crafts or alone)
    fillWords(frame, node, rects, crafts or alone)
    frame.alone = nil
    if not crafts and not rect.done and lock == nil then
      frame.alone = aloneLines(node, rect.bandLo, rect.bandHi, alone)
    end
    -- Brief PR49b: the card's route lines in full on its hover (a long one can be cut on the
    -- card), then its cost per point where the band was re-ranked on auction house prices.
    frame.routeLines = Pane.RouteHover(frame.wordsText, node.cost, isRoute)
    -- Brief PR49c: the name's words first, so the Changed badge can stand right after them.
    setText(frame.name, frame.nameText)
    fillBadge(frame, node, rects)
  end
  -- Brief SC1: the Show craft button, a recipe card's only (hidden on a gathering spot).
  fillShow(frame, rect)
  frame:Show()
end

local function buildMore()
  local frame = newFrame("Button", Pane.canvas)
  if not frame then
    return nil
  end
  frame.face = wash(frame, "BACKGROUND", Pane.NODE_FACE)
  if frame.face then
    frame.face:SetAllPoints(frame)
  end
  frame.hover = wash(frame, "HIGHLIGHT", Pane.HOVER)
  if frame.hover then
    frame.hover:SetAllPoints(frame)
  end
  frame.label = newText(frame, Pane.FONT_SM, Pane.MUTED_WORD, "CENTER")
  if frame.label then
    frame.label:SetPoint("CENTER", frame, "CENTER", 0, 0)
  end
  if type(frame.RegisterForClicks) == "function" then
    pcall(frame.RegisterForClicks, frame, "LeftButtonUp")
  end
  setScript(frame, "OnClick", function(self)
    if swallowed(self) then
      return
    end
    local index = rawget(self, "bandIndex")
    local line = Pane.selected
    if index and line then
      Pane.expanded[line] = Pane.expanded[line] or {}
      Pane.expanded[line][index] = not Pane.expanded[line][index] or nil
      render()
    end
  end)
  pressable(frame)
  return frame
end

local function fillMore(frame, column)
  local more = column.more
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", Pane.canvas, "TOPLEFT", more.x, -more.y)
  frame:SetSize(more.w, more.h)
  frame.bandIndex = column.index
  frame.swallow = nil
  if more.expanded then
    setText(frame.label, Pane.WORDS.fewer)
  else
    setText(frame.label, string.format(Pane.WORDS.more, more.count))
  end
  frame:Show()
end

local function buildLink()
  local frame = newFrame("Frame", Pane.canvas)
  if not frame then
    return nil
  end
  frame.shaft = wash(frame, "ARTWORK", Pane.ROUTE_GOLD)
  frame.head = newTexture(frame, "OVERLAY")
  if frame.head then
    -- Brief PR23: the talent tree's arrow head, turned to point right and tinted the route gold,
    -- where the client has it; the old chevron where it has not.
    local s = skin()
    local hasAtlas = s and type(s.Has) == "function" and s.Has(Pane.ARROW_KEY) == true or false
    local hasYellow = s and type(s.Has) == "function" and s.Has(Pane.ARROW_YELLOW_KEY) == true or false
    local style = Pane.ArrowHeadStyle(hasAtlas, type(frame.head.SetRotation) == "function", hasYellow)
    local drawn = applyAsset(frame.head, style.key)
    if drawn and style.rotation then
      drawn = pcall(frame.head.SetRotation, frame.head, style.rotation)
      if not drawn then
        style = Pane.ArrowHeadStyle(false, false)
        drawn = applyAsset(frame.head, style.key)
      end
    end
    if drawn then
      if style.desaturate and type(frame.head.SetDesaturated) == "function" then
        pcall(frame.head.SetDesaturated, frame.head, true)
      end
      tint(frame.head, Pane.ROUTE_GOLD)
      frame.head:SetSize(style.w, style.h)
      frame.headStyle = style
    else
      frame.head:Hide()
      frame.head = nil
    end
  end
  return frame
end

-- A link's own rect: from the right edge of one band's first recommended node to the left edge of
-- the next's, level with the first node's icon, a little clear of both cards.
local function linkRect(link)
  local fromX = link.from.x + link.from.w + Pane.LINK_CLEAR
  local y = link.from.y + Pane.CARD_INSET + Pane.NODE_ICON / 2
  local toX = link.to.x - Pane.LINK_CLEAR
  return { x = fromX, y = y - Pane.ARROW_HEAD / 2, w = math.max(toX - fromX, 1), h = Pane.ARROW_HEAD }
end

local function fillLink(frame, rect)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", Pane.canvas, "TOPLEFT", rect.x, -rect.y)
  frame:SetSize(rect.w, rect.h)
  if frame.shaft then
    frame.shaft:ClearAllPoints()
    frame.shaft:SetPoint("LEFT", frame, "LEFT", 0, 0)
    local reach = frame.head and (rawget(frame, "headStyle") or EMPTY).reach or 0
    frame.shaft:SetSize(math.max(rect.w - (reach > 0 and reach - 2 or 0), 1), Pane.ROUTE_BORDER)
    frame.shaft:Show()
  end
  if frame.head then
    -- A turned head's box keeps its own width while its art turns about the centre, so its tip
    -- lands half the difference in from the box's right edge; the box moves out by that much.
    local style = rawget(frame, "headStyle") or EMPTY
    local out = style.rotation and ((style.w or 0) - (style.reach or 0)) / 2 or 0
    frame.head:ClearAllPoints()
    frame.head:SetPoint("RIGHT", frame, "RIGHT", out, 0)
    frame.head:Show()
  end
  frame:Show()
end

-- Brief PR16: the blocks drawn below LOD_ZOOM. Brief PR19: each block is one small frame on the
-- blocks layer (Pane.blocks), pooled, with its face and its icon, so a block fades as one by its
-- own SetAlpha, as a card does. The frames take no mouse and are reused as the view moves.
local function buildBlock()
  local frame = newFrame("Frame", Pane.blocks or Pane.canvas)
  if not frame then
    return nil
  end
  frame.face = newTexture(frame, "ARTWORK", 0)
  frame.icon = newTexture(frame, "ARTWORK", 1)
  if type(frame.EnableMouse) == "function" then
    pcall(frame.EnableMouse, frame, false)
  end
  return frame
end

hideBlocks = function()
  local pool = Pane.blockPool
  if type(pool) == "table" then
    releasePool(pool)
  end
end

-- A block at rect on the canvas, its face in a Theme colour, at one alpha.
local function block(rect, colourKey, alpha)
  local pool = Pane.blockPool
  if type(pool) ~= "table" then
    return nil
  end
  local frame = acquire(pool, buildBlock)
  if not frame then
    return nil
  end
  frame.rect = rect
  at(frame, Pane.canvas, rect)
  local face = frame.face
  if face then
    applyAsset(face, "FILL_WHITE8X8")
    if type(face.SetTexCoord) == "function" then
      pcall(face.SetTexCoord, face, 0, 1, 0, 1)
    end
    tint(face, colourKey)
    face:ClearAllPoints()
    face:SetAllPoints(frame)
    face:Show()
  end
  setShown(frame.icon, false)
  setShown(frame.tag, false)
  frame.tagRect = nil
  frame.faceKey = colourKey
  frame.blockAlpha = alpha or 1
  setAlpha(frame, frame.blockAlpha)
  frame:Show()
  return frame
end

-- A card drawn as a block: its fill (gold where recommended, brief PR17: the locked colours where
-- it is in range but not learnt) and its icon, nothing else, at the card's own fade.
local function blockNode(rect)
  local node = rect.node
  local colour = type(node.spot) == "table" and nil or node.colour
  local recommended = rect.recommended == true or (rect.recommended == nil and rect.route == true)
  local kind = type(node.spot) == "table" and "card" or Pane.CardKind(recommended, lockOf(node))
  local key = Pane.CARD_FILL
  if kind == "route" then
    key = Pane.CARD_GOLD
  elseif kind == "routeLocked" then
    key = Pane.LOCKED_GOLD
  elseif kind == "locked" then
    key = Pane.LOCKED_FILL
  end
  local frame = block(rect, key, Pane.CardAlpha(colour, rect.done == true, rect.current == true))
  if frame and recommended and type(node.spot) ~= "table" then
    -- Brief PR21: the same RECOMMENDED tag as the card's, at the card's place on the block's top
    -- edge, faded with the block by its one alpha. Built the first time a pooled block needs one.
    if not frame.tag then
      frame.tag = buildTag(frame)
    end
    if frame.tag and frame.tag.text then
      setText(frame.tag.text, Pane.WORDS.recommended)
    end
    local measured = frame.tag and stringWidth(frame.tag.text) or nil
    local tagW = measured and math.floor(measured + Pane.TAG_PAD + 0.5) or Pane.TagWidth(Pane.WORDS.recommended)
    fillTag(frame, { x = Pane.TAG_LEFT, y = Pane.TAG_IN - Pane.TAG_H, w = tagW, h = Pane.TAG_H })
  end
  local icon = frame and frame.icon or nil
  if not icon then
    return frame
  end
  local file
  if type(node.spot) == "table" then
    file = node.spot.k == "item" and itemIcon(node.spot.id) or nil
  elseif node.out then
    file = itemIcon(node.out)
  else
    file = spellIcon(node.spell)
  end
  local inset = Pane.CARD_INSET
  local side = math.min(Pane.NODE_ICON, rect.h - inset * 2)
  if not applyIconFile(icon, file, "ICON_QUESTIONMARK") or side <= 0 then
    icon:Hide()
    return frame
  end
  at(icon, frame, { x = inset, y = (rect.h - side) / 2, w = side, h = side })
  icon:Show()
  return frame
end

-- Brief PR49b: the price of one item for the live re-rank, through Core/Prices.lua (its cache
-- answers again within REFRESH_SECONDS, so a redraw never re-asks an auction addon), asked once a
-- draw: seen holds this draw's answers. Pane.priceCalls counts the asks, for the spec.
local function priceOf(seen, itemId)
  local held = seen[itemId]
  if held then
    return held.copper, held.source
  end
  local prices = ItemTree.Prices
  local copper, source = nil, nil
  if type(prices) == "table" and type(prices.Value) == "function" then
    Pane.priceCalls = (Pane.priceCalls or 0) + 1
    local ok, answer, from = pcall(prices.Value, itemId)
    if ok then
      copper, source = tonumber(answer), from
    end
  end
  seen[itemId] = { copper = copper, source = source }
  return copper, source
end

-- Brief PR49b: whether an auction addon Core/Prices.lua reads is installed. Without one the
-- compile's order stands and nothing is asked.
local function auctionInstalled()
  local prices = ItemTree.Prices
  local sources = type(prices) == "table" and prices.SOURCES or nil
  for _, source in ipairs(type(sources) == "table" and sources or EMPTY) do
    if type(source) == "table" and type(source.global) == "string" and type(rawget(_G, source.global)) == "table" then
      return true
    end
  end
  return false
end

--- Brief PR49b (the owner, 2026-10-05): the live re-rank. The player's own band, where it is
--- re-planned for this client (from = "forever"), has its pick and alternatives costed at the
--- installed auction addon's prices (Model.RouteCost: reagents, an unlearnt pattern, the days of
--- cooldowns) and re-ordered by cost per expected point (Pane.ApplyRerank). One price ask per
--- item of the band's candidate cards a draw, through Core/Prices.lua's cache; no other band is
--- asked about. Answers whether any order changed.
function Pane.RerankTrack(track, data, line, rank)
  if type(track) ~= "table" or type(track.bands) ~= "table" or not auctionInstalled() then
    return false
  end
  local m = model()
  if not m or type(m.RouteCost) ~= "function" or type(m.CooldownDays) ~= "function" then
    return false
  end
  local lines = type(data) == "table" and data.lines or nil
  local held = type(lines) == "table" and lines[tonumber(line)] or nil
  local recipes = type(held) == "table" and type(held.recipes) == "table" and held.recipes or nil
  if not recipes then
    return false
  end
  local changed = false
  local seen = {}
  local function ask(itemId)
    return priceOf(seen, itemId)
  end
  for _, band in ipairs(track.bands) do
    if type(band) == "table" and band.from == "forever" and band.state == "current" then
      local from = math.max(tonumber(rank) or 0, tonumber(band.lo) or 0)
      local cooldowns = m.CooldownDays(recipes)
      local costs = {}
      for _, node in ipairs(type(band.nodes) == "table" and band.nodes or EMPTY) do
        if type(node) == "table" and node.noPoints ~= true and (node.route == true or node.alt == true) then
          local recipe = recipes[node.spell]
          local ok, cost = pcall(m.RouteCost, recipe, from, band.hi, {
            priceOf = ask,
            known = learntOf(node.spell) == true,
            cooldowns = cooldowns,
          })
          if ok and type(cost) == "table" then
            costs[node.spell] = cost
          end
        end
      end
      if Pane.ApplyRerank(band, costs) then
        changed = true
      end
    end
  end
  return changed
end

-- Hands frames to what is on screen at the pan and zoom in force and takes them back from what is
-- not. Frames sit on the canvas at their own canvas place, so a pan moves the canvas alone and
-- only the items crossing the viewport's edge are filled or let go. The "you are here" line is on
-- its own frame over every card (brief PR17). Below LOD_ZOOM (brief PR16) the headers and the cards
-- are blocks instead, and every header, card and more row frame is let go.
place = function()
  local layout = Pane.layout
  if not layout or not Pane.canvas then
    return false
  end
  local width, height = viewportSize()
  local panX, panY, zoom = Pane.panX or 0, Pane.panY or 0, Pane.zoom or 1
  local function visible(rect)
    return Pane.Visible(rect, panX, panY, width, height, zoom)
  end
  local function sweep(pool, wanted, fill)
    local keep, still = {}, {}
    for _, frame in ipairs(pool.used) do
      if frame.rect and wanted[frame.rect] then
        still[frame.rect] = true
        keep[#keep + 1] = frame
      else
        frame:Hide()
        frame.rect = nil
        pool.free[#pool.free + 1] = frame
      end
    end
    pool.used = keep
    for _, entry in ipairs(wanted.list) do
      if not still[entry.rect] then
        local frame = acquire(pool, entry.build)
        if frame then
          frame.rect = entry.rect
          fill(frame, entry.item)
        end
      end
    end
  end
  local headers, nodes, mores, links = { list = {} }, { list = {} }, { list = {} }, { list = {} }
  local function want(set, rect, item, build)
    set[rect] = true
    set.list[#set.list + 1] = { rect = rect, item = item, build = build }
  end
  hideBlocks()
  local blocks = Pane.IsBlocks(zoom)
  Pane.drawnAsBlocks = blocks
  for _, column in ipairs(layout.columns) do
    -- Brief PR17: each card knows whether its band is done, for its fade. Brief PR37: and whether
    -- it is the player's own band, whose cards never fade and whose short reagents read red.
    local done = type(column.band) == "table" and column.band.state == "done"
    local current = type(column.band) == "table" and column.band.state == "current"
    -- Brief PRX (PR44): and its band's ends, for the plan's crafts and the alone hover.
    local band = type(column.band) == "table" and column.band or EMPTY
    for _, rect in ipairs(column.nodes) do
      rect.done = done
      rect.current = current
      rect.bandLo, rect.bandHi = tonumber(band.lo), tonumber(band.hi)
    end
    if blocks then
      if visible(column.header) then
        block(column.header, column.current and Pane.ROUTE_GOLD or Pane.HEADER_FILL, Pane.HeaderAlpha(column.band))
      end
      for _, rect in ipairs(column.nodes) do
        if visible(rect) then
          blockNode(rect)
        end
      end
    else
      if visible(column.header) then
        want(headers, column.header, column, buildHeader)
      end
      for _, rect in ipairs(column.nodes) do
        if visible(rect) then
          want(nodes, rect, rect, buildNode)
        end
      end
      if column.more and visible(column.more) then
        want(mores, column.more, column, buildMore)
      end
    end
  end
  for _, link in ipairs(layout.links) do
    link.rect = link.rect or linkRect(link)
    if visible(link.rect) then
      want(links, link.rect, link.rect, buildLink)
    end
  end
  sweep(Pane.headerPool, headers, fillHeader)
  sweep(Pane.nodePool, nodes, fillNode)
  sweep(Pane.morePool, mores, fillMore)
  sweep(Pane.linkPool, links, fillLink)
  return true
end

-- The Craft buttons on the headers on screen, relabelled (PR14's OnChange; throttled there).
local function refreshCraft()
  if not Pane.shown or not Pane.layout or not Pane.headerPool then
    return false
  end
  -- Brief SC2 (QA item 263): View profession follows combat and the window too.
  Pane.UpdateView(Pane.chosen)
  -- Brief PR19: the profession window opening or shutting changes what "not learnt" can be
  -- believed, so the cards on screen are drawn again.
  if checkWindow() and Pane.nodePool then
    for _, frame in ipairs(Pane.nodePool.used) do
      if frame.rect then
        fillNode(frame, frame.rect)
      end
    end
    if Pane.drawnAsBlocks then
      place()
    end
  end
  for _, frame in ipairs(Pane.headerPool.used) do
    local column = nil
    for _, candidate in ipairs(Pane.layout.columns) do
      if candidate.header == frame.rect then
        column = candidate
      end
    end
    if column then
      fillHeader(frame, column)
    end
  end
  -- Brief SC1: the cards' Show craft buttons follow combat and the window too (PR14's OnChange
  -- hears PLAYER_REGEN_DISABLED and _ENABLED and the window's show and close).
  if Pane.nodePool then
    for _, frame in ipairs(Pane.nodePool.used) do
      if frame.rect then
        fillShow(frame, frame.rect)
      end
    end
  end
  return true
end
Pane.RefreshCraft = refreshCraft

local function watchCraft(on)
  local craft = craftModule()
  if not craft then
    return false
  end
  if on and not Pane.craftListening and type(craft.OnChange) == "function" then
    Pane.craftListening = pcall(craft.OnChange, refreshCraft) == true
  end
  if type(craft.Watch) == "function" then
    pcall(craft.Watch, on == true)
  end
  return true
end

-- Brief PB1: whether the tab is up on screen: shown (Pane.Show, not yet Pane.Hide) and its root
-- visible. The ItemTree window can close with this tab still the chosen one, and its root then
-- answers false to IsVisible, so nothing is read; the window's OnShow draws it again (watchWindow).
-- Only an explicit false counts: a client that will not answer leaves the shown flag to decide.
local function onScreen()
  local root = Pane.root
  if not Pane.shown or Pane.fallback or type(root) ~= "table" then
    return false
  end
  if type(root.IsVisible) == "function" then
    local ok, answer = pcall(root.IsVisible, root)
    if ok and answer == false then
      return false
    end
  end
  return true
end

-- Brief PB1: whether the game tooltip is up and owned by this frame of ours now.
local function tooltipOn(owner)
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.IsOwned) ~= "function" then
    return false
  end
  local ok, owned = pcall(tooltip.IsOwned, tooltip, owner)
  if not ok or owned ~= true then
    return false
  end
  if type(tooltip.IsShown) == "function" then
    local asked, shown = pcall(tooltip.IsShown, tooltip)
    if asked and shown == false then
      return false
    end
  end
  return true
end

--- Brief PB1: the reagent counts on the cards on screen read again (drawCount), and nothing else
--- drawn again: no card, header, icon or layout. Where a reagent's words moved while its own
--- hover is up, the hover is drawn again, so its "N more for one craft" and ItemTree's Keep count
--- under the item move with it. One GetItemCount per reagent on screen, a local read, never an
--- item data request. Answers how many counts changed, or false where the tab is not up.
function Pane.RefreshCounts()
  local pool = Pane.nodePool
  if not onScreen() or type(pool) ~= "table" then
    return false
  end
  local changed, hovered = 0, nil
  for _, frame in ipairs(pool.used) do
    local slots = rawget(frame, "rect") and rawget(frame, "reagents") or nil
    for index = 1, Pane.REAGENT_MAX do
      local slot = type(slots) == "table" and slots[index] or nil
      if slot and drawCount(slot) then
        changed = changed + 1
        if not hovered and tooltipOn(slot) then
          hovered = slot
        end
      end
    end
  end
  if hovered then
    Pane.MaterialTooltip(hovered, rawget(hovered, "key"), rawget(hovered, "name"), rawget(hovered, "short"))
  end
  return changed
end

--- Brief PB1: a bag or bank event while the tab is up: one counts pass (Pane.RefreshCounts)
--- COUNT_THROTTLE seconds on, however many events come in between (a stack bought, a loot of
--- several), and nothing at all while the tab is hidden or the window closed. A pass booked
--- before the tab was hidden is let go (Pane.Hide moves the token on). Answers whether a pass was
--- booked, or made where the client has no timer.
function Pane.OnBagEvent()
  if Pane.countsPending or not onScreen() then
    return false
  end
  local token = (tonumber(Pane.countsToken) or 0) + 1
  Pane.countsToken = token
  local function check()
    if Pane.countsToken ~= token then
      return false
    end
    Pane.countsPending = false
    return Pane.RefreshCounts()
  end
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    Pane.countsPending = true
    if pcall(timer.After, Pane.COUNT_THROTTLE, guardScript("Professions.Pane.RefreshCounts", check)) then
      return true
    end
    Pane.countsPending = false
  end
  return check() ~= false
end

local function onViewportMouseDown(_, button)
  return Pane.BeginPress(Pane.viewport, button, true)
end

-- The wheel zooms about the pointer, the chain tab's way. Brief UI15 (QA item 213): with Shift held
-- it scrolls instead (Pane.ScrollBy).
local function onViewportWheel(_, delta)
  delta = tonumber(delta) or 0
  if delta == 0 or not Pane.layout then
    return false
  end
  if shiftHeld() then
    return Pane.ScrollBy(delta) ~= nil
  end
  local factor = delta > 0 and Pane.ZOOM_STEP or (1 / Pane.ZOOM_STEP)
  local pointerX, pointerY = pointerOffsets()
  Pane.ZoomBy(factor, pointerX, pointerY)
  return true
end

--- Brief E2E-1 (the e2e plan's addition 6): the route's wheel made reachable for the developer only
--- e2e run, with a pretend Shift for this one call (shiftHeld asks Pane.pretendShift first). Answers
--- what the wheel answered.
function Pane.Wheel(delta, shift)
  local was = Pane.pretendShift
  Pane.pretendShift = shift == true or nil
  local ok, answer = pcall(onViewportWheel, nil, delta)
  Pane.pretendShift = was
  return ok and answer == true
end

--------------------------------------------------------------------------------
-- The zoom controls, the chain tab's own buttons (Chain.ControlButton) where it is loaded
--------------------------------------------------------------------------------

local function localControlButton(parent, text, width, hint, onClick)
  local button = newFrame("Button", parent)
  if not button then
    return nil
  end
  button:SetSize(width, Pane.CONTROL_H)
  button.face = wash(button, "BACKGROUND", Pane.NODE_FACE)
  if button.face then
    button.face:SetAllPoints(button)
  end
  button.edges = edges(button)
  if button.edges then
    paintEdges(button, button.edges, Pane.PLAIN_BORDER, Pane.HAIRLINE)
  end
  button.hover = wash(button, "HIGHLIGHT", Pane.HOVER)
  if button.hover then
    button.hover:SetAllPoints(button)
  end
  button.label = newText(button, Pane.FONT_SM, Pane.NAME_WORD, "CENTER")
  if button.label then
    button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
    setText(button.label, text)
  end
  if type(button.RegisterForClicks) == "function" then
    pcall(button.RegisterForClicks, button, "LeftButtonUp")
  end
  setScript(button, "OnClick", onClick)
  setScript(button, "OnEnter", function(self)
    textTooltip(self, hint, nil)
  end)
  setScript(button, "OnLeave", hideTooltip)
  return button
end

local function controlButton(parent, text, width, hint, onClick)
  local ui = ItemTree.UI
  local chain = type(ui) == "table" and ui.Chain or nil
  if type(chain) == "table" and type(chain.ControlButton) == "function" then
    local ok, button = pcall(chain.ControlButton, parent, text, width, hint, onClick)
    if ok and type(button) == "table" then
      return button
    end
  end
  return localControlButton(parent, text, width, hint, onClick)
end

Pane.RESET_W = 44
Pane.LABEL_W = 40

local function buildControls(parent)
  local bar = newFrame("Frame", parent)
  if not bar then
    return nil
  end
  bar:SetHeight(Pane.CONTROL_H)
  local controls = { bar = bar }
  controls.reset = controlButton(bar, Pane.WORDS.reset, Pane.RESET_W, Pane.WORDS.resetHint, function()
    Pane.ResetZoom()
  end)
  controls.plus = controlButton(bar, "+", Pane.CONTROL_H, Pane.WORDS.zoomIn, function()
    Pane.ZoomBy(Pane.ZOOM_STEP)
  end)
  controls.minus = controlButton(bar, "-", Pane.CONTROL_H, Pane.WORDS.zoomOut, function()
    Pane.ZoomBy(1 / Pane.ZOOM_STEP)
  end)
  controls.label = newText(bar, Pane.FONT_SM, Pane.MUTED_WORD, "RIGHT")
  local width, previous = 0, nil
  for _, entry in ipairs({
    { controls.reset, Pane.RESET_W },
    { controls.plus, Pane.CONTROL_H },
    { controls.minus, Pane.CONTROL_H },
  }) do
    local button, w = entry[1], entry[2]
    if button then
      button:ClearAllPoints()
      if previous then
        button:SetPoint("RIGHT", previous, "LEFT", -Pane.SMALL_PAD, 0)
      else
        button:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
      end
      width = width + w + (previous and Pane.SMALL_PAD or 0)
      previous = button
    end
  end
  if controls.label then
    controls.label:SetWidth(Pane.LABEL_W)
    if previous then
      controls.label:SetPoint("RIGHT", previous, "LEFT", -Pane.SMALL_PAD, 0)
    else
      controls.label:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    end
    width = width + Pane.LABEL_W + Pane.SMALL_PAD
  end
  bar:SetWidth(math.max(width, Pane.CONTROL_H))
  controls.width = width
  return controls
end

--------------------------------------------------------------------------------
-- Building
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Brief SC2 (QA item 263): View profession, left of Trainers & vendors
--------------------------------------------------------------------------------
-- The owner: "To the left of trainers and vendors add a button that says "View profession" to open
-- the native profession tab to that profession (standard open not to a specific place) and make it
-- the same as the red trainers and vendors button". The window's red plate (Skin.PlateButton), the
-- Trainers button's height (Pane.CONTROL_H is its ITEMTREE_CONTROL_H_SM), font size and word colour,
-- as wide as its words with VIEW_PAD each side. Built once with the pane, never lazily. What a click
-- does, its faded look and its hover are Craft's (Core\Craft.lua Craft.ViewButton and
-- Craft.ViewProfession).

Pane.VIEW_PAD = 12
-- The Trainers button's width a character where the client will not measure (Trainers.CHAR_W).
Pane.VIEW_CHAR_W = 6.2

--- Brief SC2: the View profession button's width for its words, measured where the client measures
--- them, else VIEW_CHAR_W a character. Pure.
function Pane.ViewWidth(text, measured)
  local w = tonumber(measured)
  if not w or w <= 0 then
    w = math.floor(#tostring(text or "") * Pane.VIEW_CHAR_W + 0.5)
  end
  return w + Pane.VIEW_PAD * 2
end

-- Brief SC2: the button's state for a line now (Craft.ViewButton), or nil without a line or where
-- Craft has no View profession contract.
local function viewState(line)
  local craft = Professions.craft
  if type(craft) ~= "table" or type(craft.ViewButton) ~= "function" or type(craft.ViewProfession) ~= "function" then
    return nil
  end
  if line == nil then
    return nil
  end
  local ok, state = pcall(craft.ViewButton, line)
  if ok and type(state) == "table" then
    return state
  end
  return nil
end

-- Its hover, Show craft's shape, asked afresh each time (combat and the window as they are now),
-- shown on the faded button too.
local function viewTooltip(owner)
  local state = viewState(rawget(owner, "line"))
  if not state then
    return false
  end
  return textTooltip(owner, tostring(state.label or ""), Pane.ShowTooltipLines(state))
end

local function buildViewButton(parent)
  local s = skin()
  local button = s and type(s.PlateButton) == "function" and s.PlateButton(parent, 96, Pane.CONTROL_H) or nil
  if not button then
    button = newFrame("Button", parent)
    if not button then
      return nil
    end
    button:SetSize(96, Pane.CONTROL_H)
    button.face = wash(button, "BACKGROUND", Pane.NODE_FACE)
    if button.face then
      button.face:SetAllPoints(button)
    end
    button.edges = edges(button)
    if button.edges then
      paintEdges(button, button.edges, Pane.PLAIN_BORDER, Pane.HAIRLINE)
    end
    button.hover = wash(button, "HIGHLIGHT", Pane.HOVER)
    if button.hover then
      button.hover:SetAllPoints(button)
    end
    if type(button.RegisterForClicks) == "function" then
      pcall(button.RegisterForClicks, button, "LeftButtonUp")
    end
  end
  button.canPress = true
  if type(button.SetMotionScriptsWhileDisabled) == "function" then
    pcall(button.SetMotionScriptsWhileDisabled, button, true)
  end
  button.label = newText(rawget(button, "labelParent") or button, Pane.FONT_SM, Pane.PLATE_WORD, "CENTER")
  if button.label then
    button.label:SetPoint("LEFT", button, "LEFT", 4, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -4, 0)
  end
  -- Show craft's contract, kept for this button: the click is a hardware event and
  -- Craft.ViewProfession is the first call in it.
  setScript(button, "OnClick", function(self)
    local craft = Professions.craft
    if type(craft) == "table" and type(craft.ViewProfession) == "function" then
      craft.ViewProfession(rawget(self, "line"))
    end
  end, true)
  if button.plated and s and type(s.PlateScripts) == "function" then
    s.PlateScripts(button, setScript, { OnEnter = viewTooltip, OnLeave = hideTooltip })
  else
    setScript(button, "OnEnter", viewTooltip)
    setScript(button, "OnLeave", hideTooltip)
  end
  button:Hide()
  return button
end

--- Brief SC2: sets the View profession button for the chosen line (nil hides it): its words, its
--- width, and the faded look with Craft.ViewButton's reason where it cannot (a line the character
--- only tracks, combat, the demo, a line with no recipes). Answers { shown, enabled, width }, kept as
--- Pane.viewState for the bar's room (Pane.DrawBar).
function Pane.UpdateView(chosen)
  local button = Pane.viewButton
  local out = { shown = false, width = 0 }
  Pane.viewState = out
  if not button then
    return out
  end
  button.line = type(chosen) == "table" and chosen.line or nil
  local state = viewState(button.line)
  if not state or state.shown ~= true then
    button:Hide()
    return out
  end
  setText(button.label, state.label or "")
  local width = Pane.ViewWidth(state.label, stringWidth(button.label))
  button:SetWidth(width)
  local enabled = state.enabled == true
  button.wantEnabled = enabled
  enableButton(button, enabled)
  textColour(button.label, enabled and Pane.PLATE_WORD or Pane.MUTED_WORD)
  button.canPress = enabled
  local s = skin()
  if button.plated and s and type(s.PaintPlate) == "function" then
    s.PaintPlate(button, "normal")
  end
  setAlpha(button, Pane.CraftAlpha(enabled))
  -- Shown unless the last bar drew it aside for want of room (Pane.DrawBar decides again).
  setShown(button, Pane.viewFits ~= false)
  out.shown, out.enabled, out.width = true, enabled, width
  return out
end

--------------------------------------------------------------------------------
-- Brief PR19: the trainer warning strip, under the rank bar at a cap below 300
--------------------------------------------------------------------------------

local paintWarning

local function openTrainers()
  local trainers = trainersModule()
  if trainers and type(trainers.Open) == "function" and not trainers.open then
    pcall(trainers.Open)
  end
end

--- Opens the Trainers & vendors panel (a locked card with nowhere else to learn it). Answers
--- whether there is a panel to open.
function Pane.OpenTrainers()
  local trainers = trainersModule()
  if not (trainers and type(trainers.Open) == "function") then
    return false
  end
  openTrainers()
  return true
end

-- The strip: the warning's own card (Skin.Card: the thin border in the warning colours), the
-- client's trainer glyph, the words, and a plate button that opens the Trainers & vendors panel.
-- Made once, hidden until a cap shows it.
local function buildWarning(parent)
  local strip = newFrame("Frame", parent)
  if not strip then
    return nil
  end
  strip:SetPoint("TOPLEFT", parent, "TOPLEFT", Pane.PAD, -Pane.TOP_H)
  strip:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -Pane.PAD, -Pane.TOP_H)
  strip:SetHeight(Pane.WARN_H)
  strip.face = wash(strip, "BACKGROUND", Pane.WARN_FILL)
  if strip.face then
    strip.face:SetAllPoints(strip)
  end
  strip.edges = edges(strip)
  strip.icon = newTexture(strip, "ARTWORK")
  if strip.icon then
    strip.icon:SetSize(Pane.WARN_ICON, Pane.WARN_ICON)
    strip.icon:SetPoint("LEFT", strip, "LEFT", Pane.CARD_INSET, 0)
  end
  local s = skin()
  local button = s and type(s.PlateButton) == "function" and s.PlateButton(strip, 96, Pane.CONTROL_H) or nil
  if not button then
    button = newFrame("Button", strip)
    if button then
      button:SetSize(96, Pane.CONTROL_H)
      button.face = wash(button, "BACKGROUND", Pane.NODE_FACE)
      if button.face then
        button.face:SetAllPoints(button)
      end
      button.edges = edges(button)
      if button.edges then
        paintEdges(button, button.edges, Pane.PLAIN_BORDER, Pane.HAIRLINE)
      end
      button.hover = wash(button, "HIGHLIGHT", Pane.HOVER)
      if button.hover then
        button.hover:SetAllPoints(button)
      end
    end
  end
  if button then
    button.canPress = true
    if type(button.RegisterForClicks) == "function" then
      pcall(button.RegisterForClicks, button, "LeftButtonUp")
    end
    button.label = newText(rawget(button, "labelParent") or button, Pane.FONT_SM, Pane.PLATE_WORD, "CENTER")
    if button.label then
      button.label:SetPoint("LEFT", button, "LEFT", 4, 0)
      button.label:SetPoint("RIGHT", button, "RIGHT", -4, 0)
      setText(button.label, Pane.WORDS.showTrainers)
    end
    local width = math.max((stringWidth(button.label) or #Pane.WORDS.showTrainers * 6) + 24, 96)
    button:SetWidth(width)
    button.width = width
    button:ClearAllPoints()
    button:SetPoint("RIGHT", strip, "RIGHT", -Pane.CARD_INSET, 0)
    setScript(button, "OnClick", openTrainers)
    if button.plated and s and type(s.PlateScripts) == "function" then
      s.PlateScripts(button, setScript, {})
      if type(s.PaintPlate) == "function" then
        s.PaintPlate(button, "normal")
      end
    end
  end
  strip.button = button
  strip.text = newText(strip, Pane.FONT_MD, Pane.WARN_WORD, "LEFT")
  if strip.text then
    strip.text:SetPoint("LEFT", strip, "LEFT", Pane.CARD_INSET * 2 + Pane.WARN_ICON, 0)
    if button then
      strip.text:SetPoint("RIGHT", button, "LEFT", -Pane.CARD_INSET, 0)
    else
      strip.text:SetPoint("RIGHT", strip, "RIGHT", -Pane.CARD_INSET, 0)
    end
  end
  setScript(strip, "OnSizeChanged", function(self)
    if rawget(self, "warningText") and Pane.warning then
      paintWarning(self)
    end
  end)
  strip:Hide()
  return strip
end

-- Moves the viewport's top to the strip's foot, the rank bar's alone or with the warning under it.
local function setTop(height)
  Pane.topH = height
  local viewport, host = Pane.viewport, Pane.board or Pane.root
  if not viewport or not host then
    return
  end
  viewport:ClearAllPoints()
  viewport:SetPoint("TOPLEFT", host, "TOPLEFT", Pane.HAIRLINE, -height)
  -- Brief LF1: down to the board's foot; the hints float over it (UI15's strip is gone).
  viewport:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -Pane.HAIRLINE, Pane.HAIRLINE)
end

--- Brief PR19: shows the trainer warning for the chosen line where it is at a cap below 300
--- (Pane.CapWarning), else hides it, and moves the canvas under it. Answers the warning or nil.
function Pane.UpdateWarning(chosen)
  local warning = Pane.CapWarning(chosen, ItemTree.ProfessionsTrainers, type(chosen) == "table" and chosen.demo)
  Pane.warning = warning
  local strip = Pane.warn
  setTop(Pane.TopHeight(warning ~= nil and strip ~= nil))
  if not strip then
    return warning
  end
  if not warning then
    strip:Hide()
    return nil
  end
  paintWarning(strip)
  if strip.icon then
    setShown(strip.icon, applyAsset(strip.icon, "CAT_TRAINER"))
  end
  setText(strip.text, warning.text)
  strip.warningText = warning.text
  strip:Show()
  return warning
end

-- The strip's card at its width now (the board's, less the padding, before the client has laid
-- it out).
paintWarning = function(strip)
  local w = number(strip, "GetWidth") or 0
  if w <= 0 then
    w = math.max(viewportSize() - Pane.PAD * 2, 1)
  end
  local s = skin()
  local drawn = s
      and type(s.Card) == "function"
      and s.Card(strip, w, Pane.WARN_H, { fill = Pane.WARN_FILL, edge = Pane.WARN_EDGE, thickness = Pane.ROUTE_BORDER })
    or false
  strip.skinned = drawn == true
  if drawn then
    setShown(strip.face, false)
    hideEdges(strip.edges)
  else
    tint(strip.face, Pane.WARN_FILL)
    setShown(strip.face, true)
    paintEdges(strip, strip.edges, Pane.WARN_EDGE, Pane.ROUTE_BORDER)
  end
  strip.paintedW = w
  return drawn
end

local function raise(frame, over, by)
  if type(frame.SetFrameLevel) == "function" then
    local level = number(over, "GetFrameLevel")
    if level then
      pcall(frame.SetFrameLevel, frame, level + by)
    end
  end
end

-- Brief PR25 (the owner, after seeing a thin border: "remove the full border and bevel edges, and
-- instead just have the current dark brown background"): the top strip draws no frame, no nine
-- slice or corners, only PR24's dark fill (Pane.TOP_FILL) across the whole strip, on a
-- mouseless frame at the strip's own level, under the bar, the tag, the stem and the buttons.
local function buildTopFrame(top)
  local frame = newFrame("Frame", top)
  if not frame then
    return nil
  end
  frame:SetAllPoints(top)
  raise(frame, top, 0)
  if type(frame.EnableMouse) == "function" then
    pcall(frame.EnableMouse, frame, false)
  end
  frame.fillKey = Pane.TOP_FILL
  frame.background = wash(frame, "BACKGROUND", Pane.TOP_FILL)
  if frame.background then
    frame.background:SetAllPoints(frame)
  end
  -- Brief PR25 (the owner: "just add a simple bottom yellow border like we have around the edge"):
  -- one hairline along the strip's foot only, in the window's own inner edge gold (UI\Frame.lua's
  -- body outline), on BORDER over the fill. No other edge.
  frame.rule = wash(frame, "BORDER", Pane.TOP_RULE)
  if frame.rule then
    frame.rule:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.rule:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.rule:SetHeight(Pane.HAIRLINE)
  end
  return frame
end

--- Brief PR25: how far in from the top strip's left and right edges the bar, the tag and the
--- controls keep (Pane.TOP_INSET), so they sit clear of the strip's ends with no frame drawn.
function Pane.TopInset()
  return Pane.TOP_INSET
end

-- Brief LF1 (QA item 240c): one hotkey's cell on the hint panel, every piece on the panel itself
-- (textures and words, no frame of their own): the keycap's art and its word and the "+" where the
-- hotkey has a key, the mouse, the action icon (tinted the words' colour) and the word.
local function buildHintCell(panel, hint)
  local cell = { hint = hint }
  if hint.key then
    cell.key = newTexture(panel, "ARTWORK")
    setShown(cell.key, cell.key ~= nil and applyAsset(cell.key, hint.key))
    cell.keyText = newText(panel, Pane.FONT_SM, Pane.HINT_WORD, "CENTER")
    setText(cell.keyText, Pane.WORDS.hintShift)
    cell.plus = newText(panel, Pane.FONT_SM, Pane.HINT_WORD, "CENTER")
    setText(cell.plus, Pane.WORDS.hintPlus)
  end
  cell.mouse = newTexture(panel, "ARTWORK")
  setShown(cell.mouse, cell.mouse ~= nil and applyAsset(cell.mouse, hint.mouse))
  cell.icon = newTexture(panel, "ARTWORK")
  if cell.icon then
    local drawn = applyAsset(cell.icon, hint.icon)
    if drawn then
      tint(cell.icon, Pane.HINT_WORD)
    end
    setShown(cell.icon, drawn)
  end
  cell.word = newText(panel, Pane.FONT_SM, Pane.HINT_WORD, "LEFT")
  setText(cell.word, Pane.WORDS[hint.word] or "")
  return cell
end

-- Brief LF1: the hint panel, built with the pane (never lazily) on the board, its bottom right
-- corner HINT_MARGIN px in from the viewport's, HINT_LEVEL levels over the canvas. It takes no
-- mouse and no wheel, so whatever is under it keeps every press, drag and notch.
local function buildHints(parent, viewport, over)
  local panel = newFrame("Frame", parent)
  if not panel then
    return nil
  end
  if viewport then
    panel:SetPoint("BOTTOMRIGHT", viewport, "BOTTOMRIGHT", -Pane.HINT_MARGIN, Pane.HINT_MARGIN)
  end
  if type(panel.EnableMouse) == "function" then
    pcall(panel.EnableMouse, panel, false)
  end
  if type(panel.EnableMouseWheel) == "function" then
    pcall(panel.EnableMouseWheel, panel, false)
  end
  raise(panel, over or viewport or parent, Pane.HINT_LEVEL)
  -- The flat face and square edges, where the card art will not draw.
  panel.face = wash(panel, "BACKGROUND", Pane.HINT_FILL)
  if panel.face then
    panel.face:SetAllPoints(panel)
    panel.face:Hide()
  end
  panel.edges = edges(panel)
  hideEdges(panel.edges)
  panel.dividers = {}
  panel.cells = {}
  for index, hint in ipairs(Pane.HINTS) do
    panel.cells[index] = buildHintCell(panel, hint)
  end
  panel:Hide()
  return panel
end

-- A word's drawn width, the client's measure, or a rough one where it will not say.
local function wordWidth(fontString, text)
  return stringWidth(fontString) or #tostring(text or "") * 6
end

-- Brief LF1: lays the hint panel out for its words as the client draws them (Pane.HintLayout): its
-- size, the card art (or the flat face and edges), the dividers and each cell's pieces, every x on
-- a whole pixel. Answers the layout, or nil without a panel.
local function layoutHints()
  local panel = Pane.hints
  if type(panel) ~= "table" then
    return nil
  end
  local cells = rawget(panel, "cells") or EMPTY
  local sizes = {}
  for index, cell in ipairs(cells) do
    local art = Pane.HINT_MOUSE_W
    if cell.hint.key then
      cell.keyW = Pane.HintKeyWidth(wordWidth(cell.keyText, Pane.WORDS.hintShift))
      cell.plusW = math.ceil(wordWidth(cell.plus, Pane.WORDS.hintPlus))
      art = Pane.HintArtWidth(cell.hint, cell.keyW, cell.plusW)
    end
    sizes[index] = { art = art, word = math.ceil(wordWidth(cell.word, Pane.WORDS[cell.hint.word])) }
  end
  local layout = Pane.HintLayout(sizes)
  panel:SetSize(layout.w, layout.h)
  panel.layoutW, panel.layoutH = layout.w, layout.h
  local s = skin()
  local drawn = s
      and type(s.Card) == "function"
      and s.Card(panel, layout.w, layout.h, { fill = Pane.HINT_FILL, edge = Pane.HINT_EDGE })
    or false
  if drawn then
    setShown(panel.face, false)
    hideEdges(panel.edges)
  else
    if s and type(s.HideCard) == "function" then
      s.HideCard(panel)
    end
    setShown(panel.face, true)
    paintEdges(panel, panel.edges, Pane.HINT_EDGE, Pane.HAIRLINE)
  end
  for index, x in ipairs(layout.dividers) do
    local line = panel.dividers[index]
    if not line then
      line = wash(panel, "BORDER", Pane.HINT_EDGE)
      panel.dividers[index] = line
    end
    if line then
      at(line, panel, { x = x, y = Pane.HINT_DIVIDER_IN, w = Pane.HAIRLINE, h = layout.h - Pane.HINT_DIVIDER_IN * 2 })
      line:Show()
    end
  end
  for index = #layout.dividers + 1, #panel.dividers do
    setShown(panel.dividers[index], false)
  end
  local artTop = Pane.HINT_PAD_Y
  local artMiddle = artTop + Pane.HINT_ART_H / 2
  local rowTop = artTop + Pane.HINT_ART_H + Pane.HINT_ROW_GAP
  for index, cell in ipairs(cells) do
    local slot, size = layout.cells[index], sizes[index]
    local left = math.floor(slot.x + (slot.w - size.art) / 2 + 0.5)
    if cell.hint.key then
      if cell.key then
        at(cell.key, panel, {
          x = left,
          y = artTop + (Pane.HINT_ART_H - Pane.HINT_KEY_H) / 2,
          w = cell.keyW,
          h = Pane.HINT_KEY_H,
        })
      end
      -- The keycap's face sits a little above its middle, over its darker lip.
      if cell.keyText then
        cell.keyText:ClearAllPoints()
        cell.keyText:SetPoint("CENTER", panel, "TOPLEFT", left + cell.keyW / 2, -(artMiddle - 1))
      end
      left = left + cell.keyW + Pane.HINT_JOIN_GAP
      if cell.plus then
        cell.plus:ClearAllPoints()
        cell.plus:SetPoint("CENTER", panel, "TOPLEFT", left + cell.plusW / 2, -artMiddle)
      end
      left = left + cell.plusW + Pane.HINT_JOIN_GAP
    end
    if cell.mouse then
      at(cell.mouse, panel, { x = left, y = artTop, w = Pane.HINT_MOUSE_W, h = Pane.HINT_ART_H })
    end
    local labelW = Pane.HINT_ICON + Pane.HINT_ICON_GAP + size.word
    local labelLeft = math.floor(slot.x + (slot.w - labelW) / 2 + 0.5)
    if cell.icon then
      at(cell.icon, panel, {
        x = labelLeft,
        y = rowTop + (Pane.HINT_LINE_H - Pane.HINT_ICON) / 2,
        w = Pane.HINT_ICON,
        h = Pane.HINT_ICON,
      })
    end
    if cell.word then
      cell.word:ClearAllPoints()
      cell.word:SetPoint(
        "LEFT",
        panel,
        "TOPLEFT",
        labelLeft + Pane.HINT_ICON + Pane.HINT_ICON_GAP,
        -(rowTop + Pane.HINT_LINE_H / 2)
      )
    end
  end
  return layout
end

--- Brief LF1 (QA item 240c): shows the floating hint panel, laid out for its words, or hides it (no
--- canvas, no hints). The pan holds its room while it shows (panHeight). Answers whether it shows.
function Pane.ShowHints(on)
  local panel = Pane.hints
  if type(panel) ~= "table" then
    return false
  end
  if on then
    layoutHints()
    panel.shownHints = true
    panel:Show()
    return true
  end
  panel.shownHints = false
  panel:Hide()
  return false
end

local function build()
  if Pane.root then
    return Pane.root
  end
  local region = Pane.region
  if type(region) ~= "table" then
    return nil
  end
  local root = newFrame("Frame", region)
  if not root then
    return nil
  end
  root:SetAllPoints(region)
  Pane.root = root

  local strip = newFrame("Frame", root)
  if strip then
    strip:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    strip:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, 0)
    strip:SetWidth(Pane.STRIP_W)
    local surface = wash(strip, "BACKGROUND", Pane.SURFACE)
    if surface then
      surface:SetAllPoints(strip)
    end
    local rule = wash(strip, "BORDER", Pane.PLAIN_BORDER)
    if rule then
      rule:SetPoint("TOPRIGHT", strip, "TOPRIGHT", 0, 0)
      rule:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", 0, 0)
      rule:SetWidth(Pane.HAIRLINE)
    end
  end
  Pane.strip = strip

  local board = newFrame("Frame", root)
  if board then
    board:SetPoint("TOPLEFT", root, "TOPLEFT", Pane.STRIP_W + Pane.HAIRLINE, 0)
    board:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0)
    local surface = wash(board, "BACKGROUND", Pane.SURFACE)
    if surface then
      surface:SetAllPoints(board)
    end
  end
  Pane.board = board

  -- The rank bar and the zoom controls, over the canvas and fixed while it moves.
  local top = newFrame("Frame", board or root)
  if top then
    top:SetPoint("TOPLEFT", board or root, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", board or root, "TOPRIGHT", 0, 0)
    top:SetHeight(Pane.TOP_H)
  end
  Pane.top = top
  -- Brief PR23: the strip's frame and surface first, under everything else on it.
  Pane.topFrame = top and buildTopFrame(top) or nil
  local topInset = Pane.TopInset()
  local barApi = barModule()
  if top and barApi then
    local ok, rankBar = pcall(barApi.Build, top)
    if ok and type(rankBar) == "table" then
      -- Brief PR16: the bar lines up with the viewport, whose x it shares with the canvas axis.
      rankBar:SetPoint("TOPLEFT", top, "TOPLEFT", Pane.HAIRLINE, 0)
      Pane.rankBar = rankBar
    end
  end
  Pane.controls = top and buildControls(top) or nil
  if Pane.controls and Pane.controls.bar then
    Pane.controls.bar:SetPoint("TOPRIGHT", top, "TOPRIGHT", -(Pane.PAD + topInset), -Pane.TOP_CONTROLS_Y)
    raise(Pane.controls.bar, top, 10)
  end
  -- Brief PR15: the Trainers & vendors button, beside the rank tag, left of the zoom controls. Its
  -- panel opens over the board; nothing it reads is loaded until it is clicked.
  local trainers = trainersModule()
  if top and trainers then
    local ok, button = pcall(trainers.BuildButton, top, board or root)
    if ok and type(button) == "table" then
      if Pane.controls and Pane.controls.bar then
        button:SetPoint("TOPRIGHT", Pane.controls.bar, "TOPLEFT", -Pane.PAD, 0)
      else
        button:SetPoint("TOPRIGHT", top, "TOPRIGHT", -(Pane.PAD + topInset), -Pane.TOP_CONTROLS_Y)
      end
      raise(button, top, 10)
      Pane.trainersButton = button
    end
  end
  -- Brief SC2 (QA item 263): View profession, immediately left of Trainers & vendors (of the zoom
  -- controls where the window has no Trainers button), built once here.
  local view = top and buildViewButton(top) or nil
  if view then
    local anchor = Pane.trainersButton or (Pane.controls and Pane.controls.bar) or nil
    if anchor then
      view:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -Pane.PAD, 0)
    else
      view:SetPoint("TOPRIGHT", top, "TOPRIGHT", -(Pane.PAD + topInset), -Pane.TOP_CONTROLS_Y)
    end
    raise(view, top, 10)
  end
  Pane.viewButton = view

  Pane.warn = buildWarning(board or root)

  local viewport = newFrame("Frame", board or root)
  if viewport then
    viewport:SetPoint("TOPLEFT", board or root, "TOPLEFT", Pane.HAIRLINE, -Pane.TOP_H)
    viewport:SetPoint("BOTTOMRIGHT", board or root, "BOTTOMRIGHT", -Pane.HAIRLINE, Pane.HAIRLINE)
    if type(viewport.EnableMouse) == "function" then
      pcall(viewport.EnableMouse, viewport, true)
    end
    if type(viewport.EnableMouseWheel) == "function" then
      pcall(viewport.EnableMouseWheel, viewport, true)
    end
    if type(viewport.SetClipsChildren) == "function" then
      pcall(viewport.SetClipsChildren, viewport, true)
    end
    setScript(viewport, "OnMouseDown", onViewportMouseDown)
    setScript(viewport, "OnMouseUp", function()
      endPress()
    end)
    setScript(viewport, "OnMouseWheel", onViewportWheel)
    -- Brief UI15: the viewport's own hover, for the pan cursor.
    setScript(viewport, "OnEnter", onViewportEnter)
    setScript(viewport, "OnLeave", onViewportLeave)
    setScript(viewport, "OnHide", function()
      endPress()
      -- Brief UI15: the cursor is let go with the canvas.
      Pane.overCanvas = false
      setPanCursor(false)
    end)
    setScript(viewport, "OnSizeChanged", function()
      if Pane.layout and Pane.shown then
        applyPan(Pane.panX, Pane.panY)
      end
    end)
  end
  Pane.viewport = viewport

  local canvas = viewport and newFrame("Frame", viewport) or nil
  if canvas then
    canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)
    canvas:SetSize(1, 1)
  end
  Pane.canvas = canvas
  -- The frame the blocks are drawn on below LOD_ZOOM.
  local blocks = canvas and newFrame("Frame", canvas) or nil
  if blocks then
    blocks:SetAllPoints(canvas)
  end
  Pane.blocks = blocks
  -- Brief PR17 (the owner reversed PR16's "behind"): the "you are here" line draws over the cards,
  -- on its own frame HERE_LEVEL levels above the canvas, which takes no mouse, so every card under
  -- it is still hovered and clicked. The rank tag sits on the bar above the viewport, so the line
  -- never covers it.
  local overlay = canvas and newFrame("Frame", canvas) or nil
  if overlay then
    overlay:SetAllPoints(canvas)
    raise(overlay, canvas, Pane.HERE_LEVEL)
    if type(overlay.EnableMouse) == "function" then
      pcall(overlay.EnableMouse, overlay, false)
    end
  end
  Pane.hereFrame = overlay
  -- Brief PR23: a crisp white core over a pale blue glow on its left only (Skin.Glow, a gradient
  -- fading out to the left); no glow at all where the client cannot shade one.
  Pane.here = overlay and wash(overlay, "OVERLAY", Pane.HERE_CORE, 2) or nil
  local glow = overlay and newTexture(overlay, "OVERLAY", 1) or nil
  local s = skin()
  if glow and not (s and type(s.Glow) == "function" and s.Glow(glow, Pane.HERE_GLOW)) then
    glow:Hide()
    glow = nil
  end
  Pane.hereGlow = glow
  -- Brief LF1 (QA item 240c): the floating hint panel over the canvas's bottom right corner.
  Pane.hints = buildHints(board or root, viewport, canvas)

  Pane.message = newText(board or root, Pane.FONT_MD, Pane.MUTED_WORD, "LEFT")
  if Pane.message then
    Pane.message:SetPoint("TOPLEFT", board or root, "TOPLEFT", Pane.PAD, -Pane.PAD)
    Pane.message:SetPoint("TOPRIGHT", board or root, "TOPRIGHT", -Pane.PAD, -Pane.PAD)
    if type(Pane.message.SetWordWrap) == "function" then
      pcall(Pane.message.SetWordWrap, Pane.message, true)
    end
    Pane.message:Hide()
  end

  Pane.stripPool, Pane.headerPool, Pane.nodePool = newPool(), newPool(), newPool()
  Pane.morePool, Pane.linkPool, Pane.blockPool = newPool(), newPool(), newPool()

  -- The skill events, heard only while the tab is shown (Show registers them, Hide lets go).
  -- Brief PB1: and the bag and bank events, which redraw the reagent counts alone.
  local events = newFrame("Frame", root)
  if events then
    setScript(events, "OnEvent", function(_, event)
      if Pane.IsCountEvent(event) then
        Pane.OnBagEvent()
      else
        Pane.OnSkillEvent()
      end
    end)
  end
  Pane.events = events
  return root
end

local function clearCanvas()
  for _, pool in ipairs({ Pane.headerPool, Pane.nodePool, Pane.morePool, Pane.linkPool }) do
    if pool then
      releasePool(pool)
    end
  end
  hideBlocks()
  setShown(Pane.here, false)
  setShown(Pane.hereGlow, false)
  Pane.layout = nil
end

-- Brief PR15: the Trainers & vendors button for the chosen line (nil hides it and closes its panel).
local function updateTrainers(chosen)
  local trainers = trainersModule()
  if not trainers or type(trainers.Update) ~= "function" then
    Pane.trainersState = nil
    return nil
  end
  local ok, state = pcall(trainers.Update, chosen)
  Pane.trainersState = ok and type(state) == "table" and state or nil
  return Pane.trainersState
end

local function showMessage(text)
  updateTrainers(nil)
  Pane.UpdateView(nil)
  Pane.UpdateWarning(nil)
  clearCanvas()
  setShown(Pane.canvas, false)
  setShown(Pane.top, false)
  -- Brief UI15: no canvas, so no hints and no pan cursor.
  Pane.ShowHints(false)
  Pane.SyncCursor()
  if Pane.message then
    setText(Pane.message, text)
    Pane.message:Show()
  end
end

--- Draws the rank bar for the chosen line along the viewport, on the canvas's axis at the pan and
--- zoom in force, its tag kept clear of the zoom controls. Answers Bar.Draw's state, or nil.
function Pane.DrawBar()
  local barApi, rankBar, chosen = barModule(), Pane.rankBar, Pane.chosen
  if not (barApi and rankBar and chosen) then
    return nil
  end
  -- Brief PR16: the viewport's width, the bar following the canvas's axis at its pan and zoom.
  local width = math.max(viewportSize(), 1)
  local inset = Pane.TopInset()
  local reserve = ((Pane.controls and Pane.controls.width) or 0) + Pane.PAD + inset
  -- Brief PR15: and the Trainers & vendors button's room beside them.
  local trainersWidth = type(Pane.trainersState) == "table" and tonumber(Pane.trainersState.width) or 0
  if trainersWidth > 0 then
    reserve = reserve + trainersWidth + Pane.PAD
  end
  -- Brief SC2 (QA item 263): and View profession's, left of it.
  local viewWidth = type(Pane.viewState) == "table" and Pane.viewState.shown and tonumber(Pane.viewState.width) or 0
  local function draw(kept)
    local ok, state = pcall(barApi.Draw, rankBar, {
      line = chosen.line,
      name = chosen.name,
      rank = chosen.rank,
      max = chosen.max,
      known = chosen.specialisations,
      -- Brief TP1: a tracked profession's tag says what it tracks, never a rank (UI\Track.lua Track.Tag).
      tag = chosen.tag,
      width = width,
      reserve = kept,
      inset = inset,
      axis = Pane.Axis(Pane.layout, Pane.panX or 0, Pane.zoom or 1),
    })
    return ok and state or nil
  end
  local state = nil
  if viewWidth > 0 then
    state = draw(reserve + viewWidth + Pane.PAD)
  end
  -- Brief SC2: where the tag cannot fit beside it (a tracked line's long tag, "Leatherworking
  -- (tracking 200 to 300)", at the window's narrowest), View profession steps aside for this draw
  -- rather than lie under the tag (Pane.ViewFits); it is back once there is room.
  local fits = viewWidth > 0 and Pane.ViewFits(state, width, reserve + viewWidth + Pane.PAD)
  if viewWidth > 0 then
    Pane.viewFits = fits
  end
  setShown(Pane.viewButton, fits)
  if not fits then
    state = draw(reserve)
  end
  Pane.barState = state
  return Pane.barState
end

--- Brief SC2: whether the drawn tag (Bar.Draw's state: tagX, tagW) stays clear of the room kept at
--- the strip's right (reserve px of width), View profession's included. Pure.
function Pane.ViewFits(state, width, reserve)
  if type(state) ~= "table" or not tonumber(state.tagX) then
    return true
  end
  local right = (tonumber(width) or 0) - (tonumber(reserve) or 0)
  return tonumber(state.tagX) + (tonumber(state.tagW) or 0) <= right
end

--- Draws the pane from scratch: the strip, then the chosen line's bar and bands. Answers whether
--- it drew.
render = function()
  if not build() then
    return false
  end
  local skills, faction, signature = facts()
  Pane.signature = signature
  local data = tracks()
  local a = assets()
  local rows = Pane.StripRows(data, skills, a and a.skillGlyphs, skillName)
  -- Brief TP1 (QA item 210): the professions the character tracks, under its own, each chosen and
  -- browsed like them (UI\Track.lua).
  local tracked = trackedRows(data, skills)
  local trackApi = trackModule()
  local all = trackApi and trackApi.JoinRows(rows, tracked) or rows
  Pane.rows = all
  local chosen = Pane.Pick(all, Pane.selected)
  if chosen then
    Pane.selected = chosen.line
  end
  -- Brief PR19: the developer's cap demo draws the line as if at its cap; nothing else sees it.
  if chosen and Pane.demo == "cap" and not chosen.tracked then
    chosen = Pane.DemoChosen(chosen)
  end
  Pane.chosen = chosen
  drawStrip(rows, chosen)
  if trackApi then
    pcall(trackApi.Draw, {
      strip = Pane.strip,
      top = Pane.SMALL_PAD,
      realCount = #rows,
      rows = tracked,
      chosen = chosen,
      tracks = data,
      skills = skills,
      nameOf = skillName,
      width = Pane.STRIP_W,
    })
  end
  if not chosen then
    showMessage(Pane.WORDS.empty)
    return true
  end
  local m, layoutApi = model(), layoutModule()
  local track = nil
  if chosen.hasRoute and m and type(m.Track) == "function" then
    local ok, answer = pcall(m.Track, data, chosen.line, chosen.rank, faction)
    track = ok and type(answer) == "table" and answer or nil
  end
  if not track or #(track.bands or EMPTY) == 0 or not layoutApi then
    showMessage(string.format(Pane.WORDS.noRoute, chosen.name))
    return true
  end
  setShown(Pane.message, false)
  setShown(Pane.top, true)
  -- Brief LF1 (QA item 240c): the floating hint panel, laid out before the pan below holds its room.
  Pane.ShowHints(true)
  Pane.names = type(data.names) == "table" and data.names or EMPTY
  Pane.lineName = chosen.name
  clearCanvas()
  Pane.track = track
  -- Brief PR19: what the player has learnt is asked again for this draw.
  Pane.learnt = {}
  checkWindow()
  -- Brief TP1: the Trainers & vendors panel and its Show nearest see the character's own skill, none
  -- for a tracked profession (UI\Track.lua Track.TrainersView).
  updateTrainers(trackApi and trackApi.TrainersView(chosen) or chosen)
  -- Brief SC2 (QA item 263): View profession, for the line itself (a tracked one shows faded).
  Pane.UpdateView(chosen)
  Pane.UpdateWarning(chosen)
  -- Brief PR49b: the player's own re-planned band re-ranked on auction house prices, where an
  -- auction addon is installed; the compile's order otherwise.
  pcall(Pane.RerankTrack, track, data, chosen.line, chosen.rank)
  -- Brief PR48: a gathering line with recipe cards (Mining's smelts) is laid out as a view of
  -- its spots then its cards (Pane.LayoutTrack), made plain again once laid out. Brief G1c: the
  -- cards the player knows above the locked ones, on every line (the Recommended first).
  local laid = Pane.LayoutTrack(track, function(node)
    local lock = lockOf(node)
    return lock == "locked" or lock == "future"
  end)
  Pane.layout = layoutApi.Bands(laid, Pane.LayoutSizes(track), {
    rank = chosen.rank,
    expanded = Pane.expanded[chosen.line],
    heightOf = Pane.NodeHeight,
  })
  if type(laid) == "table" and laid.kind == "gatherCards" then
    Pane.SettleGatherLayout(Pane.layout)
  end
  if Pane.canvas then
    Pane.canvas:SetSize(math.max(Pane.layout.width, 1), math.max(Pane.layout.height, 1))
    Pane.canvas:Show()
  end
  -- Brief PR15: the line's own view where this window session has one (a line or tab switch, a
  -- skill up redraw), else its default view.
  local view = Pane.views[chosen.line]
  local panX, panY
  if type(view) == "table" then
    Pane.zoom, panX, panY = view.zoom or 1, view.panX, view.panY
  else
    local width, height = viewportSize()
    Pane.zoom, panX, panY = Pane.DefaultView(Pane.layout, chosen.rank, width, height)
  end
  Pane.resetPending = false
  applyPan(panX, panY)
  -- Brief UI15: a redraw under a still pointer keeps the pan cursor where it was.
  Pane.SyncCursor()
  return true
end

--------------------------------------------------------------------------------
-- The pane contract
--------------------------------------------------------------------------------

function Pane.Attach(region)
  Pane.region = region
  return true
end

-- Where the pane cannot be built (no client frames, or the layout file did not load), the stub's
-- plain line stands in, as the placeholder pane drew it.
local function stub()
  local found = ItemTree.UI and ItemTree.UI.ProfessionsStub
  if type(found) == "table" then
    return found
  end
  return nil
end

local function fallbackLine()
  local core = stub()
  if not core or type(core.DrawMessage) ~= "function" then
    return false
  end
  local words = type(core.WORDS) == "table" and core.WORDS.placeholder or nil
  local ok, line = pcall(core.DrawMessage, Pane.region, words, Pane.line)
  if ok and line then
    Pane.line = line
    return true
  end
  return false
end

local function listen(on)
  local events = Pane.events
  if not events then
    return false
  end
  local method = on and events.RegisterEvent or events.UnregisterEvent
  if type(method) ~= "function" then
    return false
  end
  -- Brief PB1: the count events with the skill ones, each under its own pcall.
  for _, list in ipairs({ Pane.EVENTS, Pane.COUNT_EVENTS }) do
    for _, event in ipairs(list) do
      pcall(method, events, event)
    end
  end
  return true
end

--- A skill event while the tab is up: one redraw THROTTLE seconds on, however many come in
--- between, and only where the player's professions or ranks actually moved.
function Pane.OnSkillEvent()
  if not Pane.shown or Pane.pending then
    return false
  end
  local function check()
    Pane.pending = false
    if not Pane.shown then
      return false
    end
    local _, _, signature = facts()
    if signature ~= nil and signature == Pane.signature then
      return false
    end
    return render()
  end
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    Pane.pending = true
    if pcall(timer.After, Pane.THROTTLE, check) then
      return true
    end
    Pane.pending = false
  end
  return check()
end

--- Brief PR15: lets go of every line's view, so each opens on its default view again. Called when
--- the ItemTree window itself closes (not when the tab is left).
function Pane.ForgetViews()
  Pane.views = {}
  Pane.panX, Pane.panY = nil, nil
  Pane.zoom = 1
  Pane.resetPending = true
  return true
end

-- Brief PR15: the ItemTree window's own frame (UI/Frame.lua Frame.frame, never a Blizzard frame),
-- hooked once: its OnHide forgets the views, whichever way it closed (the X, Escape, a toggle),
-- and its OnShow redraws the tab on its default view where it is still the tab up.
local function watchWindow()
  local window = frameModule()
  local frame = window and window.frame or nil
  if type(frame) ~= "table" or Pane.windowHooked == frame or type(frame.HookScript) ~= "function" then
    return false
  end
  if type(frame.HasScript) == "function" then
    local ok, has = pcall(frame.HasScript, frame, "OnHide")
    if not ok or not has then
      return false
    end
  end
  Pane.windowHooked = frame
  pcall(frame.HookScript, frame, "OnHide", function()
    Pane.ForgetViews()
  end)
  pcall(frame.HookScript, frame, "OnShow", function()
    if Pane.shown and Pane.resetPending and not Pane.fallback then
      render()
    end
  end)
  return true
end

function Pane.Show()
  watchWindow()
  if not layoutModule() or not build() then
    Pane.fallback = true
    return fallbackLine()
  end
  Pane.fallback = false
  Pane.shown = true
  Pane.root:Show()
  listen(true)
  watchCraft(true)
  return render()
end

function Pane.Refresh()
  if Pane.fallback then
    return fallbackLine()
  end
  if not Pane.shown then
    return false
  end
  return render()
end

function Pane.Hide()
  Pane.shown = false
  Pane.pending = false
  -- Brief PB1: a counts pass still booked is let go; Show draws the counts fresh.
  Pane.countsPending = false
  Pane.countsToken = (tonumber(Pane.countsToken) or 0) + 1
  local core = stub()
  if Pane.line and core and type(core.HideMessage) == "function" then
    pcall(core.HideMessage, Pane.line)
  end
  if not Pane.root then
    return Pane.line ~= nil
  end
  listen(false)
  watchCraft(false)
  endPress()
  -- Brief UI15: the pan cursor goes with the tab.
  Pane.overCanvas = false
  setPanCursor(false)
  hideTooltip()
  Pane.root:Hide()
  return true
end

-- Brief PM1 (brief G1 reaching the Professions code): the pane's draw runs under the window's
-- boundary (Frame.Guarded, as UI/BossLoot.lua's place and boss draws do), so a draw that raises
-- (a route whose spell or item the data does not hold) leaves the empty page and the error with
-- the client's handler, and the window stays usable. A draw the window started (the tab's Show
-- and Refresh, through UI/ProfessionsStub.lua) is already inside the boundary and runs straight;
-- the ones that start here (a skill event's timer, the window's OnShow, the demo, a click) come
-- through it. With no window module, a straight call.
do
  local body = render
  render = function(...)
    local frame = frameModule()
    if frame and type(frame.Guarded) == "function" then
      return frame.Guarded("Professions.Pane.Render", body, ...)
    end
    return body(...)
  end
end


return Pane
