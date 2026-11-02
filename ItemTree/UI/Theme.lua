-- Design tokens as Lua. Derived from design/tokens/*.css (ItemTree Design System export);
-- keys transliterate the CSS custom properties, so --itemtree-color-text-title is
-- ITEMTREE_COLOR_TEXT_TITLE. Colours are { r, g, b, a } in 0 to 1. Sizes are pixels.
-- No WoW API here: the browser harness reads this table too.
local _, ItemTree = ...

local Theme = {}
ItemTree.Theme = Theme

local function hex(value, alpha)
  local r = tonumber(value:sub(2, 3), 16) / 255
  local g = tonumber(value:sub(4, 5), 16) / 255
  local b = tonumber(value:sub(6, 7), 16) / 255
  return { r = r, g = g, b = b, a = alpha or 1, hex = value:sub(2) }
end

local function rgba(r, g, b, a)
  return { r = r / 255, g = g / 255, b = b / 255, a = a }
end

-- A colour already in 0 to 1, for a token that mirrors one of the Assets tint constants number
-- for number (the badge tints, brief E80), so the two can never drift apart by a rounding.
local function unit(r, g, b, a)
  return { r = r, g = g, b = b, a = a or 1 }
end

Theme.colors = {
  -- Surface
  ITEMTREE_COLOR_SURFACE_FRAME = hex("#0B0A08"),
  ITEMTREE_COLOR_SURFACE_FRAME_NOISE = rgba(122, 104, 72, 0.05),
  ITEMTREE_COLOR_SURFACE_TOOLTIP = rgba(10, 10, 20, 0.90),
  ITEMTREE_COLOR_SURFACE_TOOLTIP_OPAQUE = hex("#0A0A14"),
  ITEMTREE_COLOR_SURFACE_INSET = hex("#161311"),
  ITEMTREE_COLOR_SURFACE_STICKY = hex("#100E0B"),
  -- Border
  ITEMTREE_COLOR_BORDER_GOLD = hex("#C9A65C"),
  ITEMTREE_COLOR_BORDER_GOLD_DIM = hex("#8A7139"),
  ITEMTREE_COLOR_BORDER_DIVIDER = hex("#4A3D24"),
  -- Text
  ITEMTREE_COLOR_TEXT_TITLE = hex("#FFD100"),
  ITEMTREE_COLOR_TEXT_BODY = hex("#E6DDC6"),
  ITEMTREE_COLOR_TEXT_MUTED = hex("#9C917C"),
  ITEMTREE_COLOR_TEXT_DISABLED = hex("#5E5748"),
  ITEMTREE_COLOR_TEXT_HINT = hex("#7A7A7A"),
  -- A selected list row's words (brief BL8): the name in the gold the sidebar's selected category
  -- is written in, and a two line row's subtitle in a slightly darker shade of the same gold (80
  -- percent of it), so the pair reads as one selection and the subtitle still reads as the lesser
  -- line. Over ITEMTREE_LIST_STATE_SELECTED on the inset surface.
  ITEMTREE_COLOR_TEXT_SELECTED = hex("#FFD100"),
  ITEMTREE_COLOR_TEXT_SELECTED_MUTED = hex("#CCA700"),
  -- Item quality (Blizzard values, never retuned)
  ITEMTREE_COLOR_QUALITY_POOR = hex("#9D9D9D"),
  ITEMTREE_COLOR_QUALITY_COMMON = hex("#FFFFFF"),
  ITEMTREE_COLOR_QUALITY_UNCOMMON = hex("#1EFF00"),
  ITEMTREE_COLOR_QUALITY_RARE = hex("#0070DD"),
  ITEMTREE_COLOR_QUALITY_EPIC = hex("#A335EE"),
  ITEMTREE_COLOR_QUALITY_LEGENDARY = hex("#FF8000"),
  -- Semantic (badges and change text). New, Community note and Predicted wear Forever's colours
  -- (brief E80) and mirror the Assets tint constants, which are the knobs: UI/Assets.lua
  -- BADGE_NEW_TINT (silver blue, #78B8F5), BADGE_NOTE_TINT (light silver, #CCD4E0) and
  -- BADGE_PREDICTED_TOP (teal, #2EC4B5, at the alpha Predicted has always had). Change the
  -- constant and the token here together; tests/spec/ui_theme_spec.lua holds them equal.
  ITEMTREE_COLOR_SEMANTIC_NEW = unit(0.47, 0.72, 0.96),
  ITEMTREE_COLOR_SEMANTIC_CHANGED = hex("#FFA500"),
  ITEMTREE_COLOR_SEMANTIC_REMOVED = hex("#FF4040"),
  ITEMTREE_COLOR_SEMANTIC_UNVERIFIED = hex("#8C8C8C"),
  ITEMTREE_COLOR_SEMANTIC_NOTE = unit(0.80, 0.83, 0.88),
  ITEMTREE_COLOR_SEMANTIC_PREDICTED = unit(0.18, 0.77, 0.71, 0.60),
  -- Brief GS3: a guessed source (Core/GuessSources.lua), the owner's muted rose (#E08FB0,
  -- 2026-09-27), a hue no other badge wears, so a guess beside a Predicted Classic Era row never
  -- reads as the same thing. The Guesses tab reads it too. Mirrors Assets.BADGE_GUESS_TINT, the
  -- knob; tests/spec/ui_theme_spec.lua holds the two equal.
  ITEMTREE_COLOR_SEMANTIC_GUESS = hex("#E08FB0"),
  -- Brief BQ15 (QA 2026-10-10 item 5): the square behind a quest row's icon where the character has
  -- completed the quest, a pale green in place of the gold edge (ITEMTREE_COLOR_BORDER_GOLD_DIM),
  -- about as light, so the green check beside the name and the square read together.
  ITEMTREE_COLOR_QUEST_DONE = hex("#6E9A5C"),
  -- The wash behind a New quest's text on the quest panels (UI/QuestFlags.lua WashBands): the New
  -- badge's own silver blue at the top, turning to a parchment yellow as it fades out. The owner
  -- ruled blue on 2026-09-27 (brief Q6), to match the New medallion. The quest wash follows New:
  -- the same numbers as ITEMTREE_COLOR_SEMANTIC_NEW and Assets.BADGE_NEW_TINT, and
  -- tests/spec/ui_theme_spec.lua holds the three equal, so tune them together.
  ITEMTREE_COLOR_QUEST_WASH = unit(0.47, 0.72, 0.96),
  ITEMTREE_COLOR_QUEST_WASH_PARCHMENT = hex("#CCB359"),
  -- Money
  ITEMTREE_COLOR_MONEY_GOLD = hex("#FFD700"),
  ITEMTREE_COLOR_MONEY_SILVER = hex("#C7C7CF"),
  ITEMTREE_COLOR_MONEY_COPPER = hex("#EDA55D"),
  -- Interaction
  ITEMTREE_COLOR_STATE_HOVER = rgba(255, 255, 255, 0.12),
  ITEMTREE_COLOR_STATE_SELECTED = rgba(201, 166, 92, 0.18),
  ITEMTREE_COLOR_STATE_FOCUS = hex("#FFD100"),
  ITEMTREE_COLOR_STATE_PRESSED = rgba(0, 0, 0, 0.35),
  -- Buttons (classic red and gold)
  ITEMTREE_COLOR_BUTTON_FACE = hex("#2B1A16"),
  ITEMTREE_COLOR_BUTTON_FACE_HOVER = hex("#3A231D"),
  ITEMTREE_COLOR_BUTTON_ACCENT = hex("#8C1F1F"),
  ITEMTREE_COLOR_BUTTON_ACCENT_DIM = hex("#5C1616"),
  -- Frame ornament
  ITEMTREE_FRAME_ORNAMENT_OUTER = hex("#1A150E"),
  ITEMTREE_FRAME_ORNAMENT_INNER = hex("#8A7139"),
  -- Row list states and guides
  ITEMTREE_LIST_STATE_HOVER = rgba(230, 221, 198, 0.10),
  ITEMTREE_LIST_STATE_SELECTED = rgba(201, 166, 92, 0.18),
  ITEMTREE_LIST_GUIDE = hex("#4A3D24"),
  ITEMTREE_BADGE_BACKING = rgba(11, 10, 8, 0.85),
  ITEMTREE_EDITMODE_SELECTION = hex("#4FA3FF"),
  -- The item info column's own surface (brief E78): a gold wash over ITEMTREE_COLOR_SURFACE_INSET,
  -- so the column reads as a lighter, warmer surface than the panes to its right. Three strengths,
  -- lightest first; UI/InfoPanel.lua takes the lightest one whose composite over the inset fill
  -- keeps the body text at 4.5:1, the muted labels at 3:1 and the item quality names at 3:1
  -- (InfoPanel.ChooseFill, pinned in tests/spec/ui_theme_spec.lua). The alpha is the knob.
  ITEMTREE_COLOR_INFO_FILL_ALT = rgba(204, 179, 89, 0.16),
  ITEMTREE_COLOR_INFO_FILL = rgba(201, 166, 92, 0.12),
  ITEMTREE_COLOR_INFO_FILL_SOFT = rgba(201, 166, 92, 0.08),
  -- Brief BL10: the Boss loot place column's level band headers. The owner's knobs: the bar's fill,
  -- the bevel's dark bottom edge (and the keyline behind the glyph), and the words on it. Brief Q9b
  -- ("too highlighted, out of place") took the bar into the window's own palette: the frame's dark
  -- brown fill, a darker brown edge, and the words in the standard title gold (the value of
  -- ITEMTREE_COLOR_TEXT_TITLE). tests/spec/ui_theme_spec.lua holds the words at 7:1 or better on
  -- the fill with the sheen at its alpha over it.
  ITEMTREE_COLOR_BAND_FILL = hex("#4A3A1E"),
  ITEMTREE_COLOR_BAND_EDGE = hex("#2A2112"),
  ITEMTREE_COLOR_BAND_WORD = hex("#FFD100"),
  -- Brief BL11: the rank word ("Rare elite", "Rare") at the top of a Boss loot rare's tooltip, in
  -- the silver of the dragon crest beside its name. The owner's knob.
  ITEMTREE_COLOR_TEXT_RARE_SILVER = hex("#C0C0C0"),
  -- Brief T4: the Keep mark, the client's action button border glow drawn round a bag slot. The
  -- owner's knob: a warm gold, a touch deeper than the border gold so it reads as a glow, not a
  -- frame. Its alpha is ITEMTREE_KEEP_GLOW_ALPHA in Theme.sizes.
  ITEMTREE_COLOR_KEEP_GLOW = hex("#FFC23A"),
  -- Brief Q9a: the head of the Keep tooltip line. "Keep (lvl 12 to 19):" in a bright
  -- green, and "No need to keep (lvl 5 to 9):" in the Removed red. The description after the
  -- head is the tooltip's plain white (ITEMTREE_COLOR_QUALITY_COMMON). The owner's knobs.
  ITEMTREE_COLOR_KEEP_YES = hex("#3DDC84"),
  ITEMTREE_COLOR_KEEP_NO = hex("#FF4040"),
  -- Brief K7: the Keep tier colours the ramps below name that no other token carries. The owner's
  -- knobs: the brighter gold at the top of the Gold ramp, and the Heat ramp's orange and red.
  ITEMTREE_COLOR_KEEP_GOLD_BRIGHT = hex("#FFE680"),
  ITEMTREE_COLOR_KEEP_HEAT_ORANGE = hex("#FF8C1A"),
  ITEMTREE_COLOR_KEEP_HEAT_RED = hex("#FF2A1A"),
  -- Brief K13 addendum: the colour a valuable item (brief K9) wears its Keep look in, the client's
  -- legendary orange. Not a ramp tier: it sits above every ramp, whichever is chosen.
  ITEMTREE_COLOR_KEEP_VALUE = hex("#FF8000"),
  -- Brief BQ9 (the owner, 2026-10-10: "the blue means do this now"): the [Open] and [Use] tags and
  -- the bag's Use mark, the same hue as Jettison's Use rows (its Widgets.COLOURS.use) so the colour
  -- reads alike in both addons.
  ITEMTREE_COLOR_USE = hex("#4DA6FF"),
  -- Brief K15: the two Single colour picks (Theme.keepColors) no other token carries. The owner's
  -- knobs: a pink and a teal bright enough to read on a dark icon.
  ITEMTREE_COLOR_KEEP_PINK = hex("#FF6EC7"),
  ITEMTREE_COLOR_KEEP_TEAL = hex("#2EE6C8"),
  -- Brief K17: the Yellow pick, the valuable colour that ships. The owner's knob: a warm gold
  -- orange yellow near the client's gold coin, not a lemon.
  ITEMTREE_COLOR_KEEP_YELLOW = hex("#F5A623"),
  -- Faction tags (from the prototype data)
  ITEMTREE_COLOR_FACTION_HORDE = hex("#B30000"),
  ITEMTREE_COLOR_FACTION_ALLIANCE = hex("#0078FF"),
  -- Brief PR7: the Professions tab. The gold border and the "Recommended" tag on the route's
  -- recipes and their reagents, a warm gold in the family of the Keep glow (the owner's knob); the
  -- "you are here" line at the player's rank; and the recipe colour pips, the client's own trade
  -- skill colours (orange, yellow, green, grey) plus a muted red for a recipe not yet learnable.
  ITEMTREE_COLOR_PROFESSION_ROUTE_GOLD = hex("#FFC23A"),
  ITEMTREE_COLOR_PROFESSION_HERE = hex("#7FD4FF"),
  -- Brief PR23: the "you are here" line drawn as a crisp white core with a pale blue glow on its
  -- left only, fading from this alpha at the line to nothing (the glow's alpha is the knob).
  ITEMTREE_COLOR_PROFESSION_HERE_CORE = hex("#FFFFFF"),
  ITEMTREE_COLOR_PROFESSION_HERE_GLOW = rgba(160, 214, 255, 0.35),
  -- Brief PR24 (the owner): the framed top strip's background, darker than the item info column's
  -- inset and gold wash it reused in PR23.
  ITEMTREE_COLOR_PROFESSION_TOP_FILL = hex("#0B0908"),
  -- Brief UI15 (QA item 209): the ItemTree logo's dark green, the shield's field in
  -- docs/images/item-tree-logo.png (the median of its green pixels). The "View in ItemTree" button on
  -- the client's profession window wears it in place of the panel button's red.
  ITEMTREE_COLOR_LOGO_GREEN = hex("#244E2F"),
  ITEMTREE_COLOR_SKILL_ORANGE = hex("#FF8040"),
  ITEMTREE_COLOR_SKILL_YELLOW = hex("#FFFF00"),
  ITEMTREE_COLOR_SKILL_GREEN = hex("#40BF40"),
  ITEMTREE_COLOR_SKILL_GREY = hex("#808080"),
  ITEMTREE_COLOR_SKILL_UNLEARNABLE = hex("#A04040"),
  -- Brief PR13: the Professions tab's rank bar and cards. Each profession's flat fill, standing in
  -- where the client will not draw its fill art, in the colour of that art as the owner's
  -- close-ups show it (cooking cream, first aid green, leatherworking brown, skinning teal); the
  -- empty stretch to the cap, the locked stretch past it, the tier ticks and the specialisation
  -- marks; the gold a recommended card's frame is drawn in and its glow where the glow art will
  -- not draw; the Recommended tag's fill; and the current band's header wash.
  ITEMTREE_COLOR_PROFESSION_BAR_FIRSTAID = hex("#6CCB2E"),
  ITEMTREE_COLOR_PROFESSION_BAR_BLACKSMITHING = hex("#8E8E96"),
  ITEMTREE_COLOR_PROFESSION_BAR_LEATHERWORKING = hex("#9A6433"),
  ITEMTREE_COLOR_PROFESSION_BAR_ALCHEMY = hex("#7C55C8"),
  ITEMTREE_COLOR_PROFESSION_BAR_HERBALISM = hex("#5DA838"),
  ITEMTREE_COLOR_PROFESSION_BAR_COOKING = hex("#EAD2A8"),
  ITEMTREE_COLOR_PROFESSION_BAR_MINING = hex("#A08A6E"),
  ITEMTREE_COLOR_PROFESSION_BAR_TAILORING = hex("#C0504A"),
  ITEMTREE_COLOR_PROFESSION_BAR_ENGINEERING = hex("#B8893A"),
  ITEMTREE_COLOR_PROFESSION_BAR_ENCHANTING = hex("#A060D8"),
  ITEMTREE_COLOR_PROFESSION_BAR_FISHING = hex("#4F86BF"),
  ITEMTREE_COLOR_PROFESSION_BAR_SKINNING = hex("#4E9C8C"),
  ITEMTREE_COLOR_PROFESSION_BAR_DEFAULT = hex("#3A6FD1"),
  ITEMTREE_COLOR_PROFESSION_BAR_EMPTY = rgba(0, 0, 0, 0.85),
  ITEMTREE_COLOR_PROFESSION_BAR_LOCKED = rgba(70, 66, 60, 0.95),
  ITEMTREE_COLOR_PROFESSION_BAR_TICK = hex("#C8B89A"),
  ITEMTREE_COLOR_PROFESSION_BAR_SPEC = hex("#FFC23A"),
  ITEMTREE_COLOR_PROFESSION_BAR_SPEC_KNOWN = hex("#FFE680"),
  ITEMTREE_COLOR_PROFESSION_CARD_GOLD = hex("#FFD36B"),
  ITEMTREE_COLOR_PROFESSION_TAG_FILL = rgba(38, 26, 8, 0.96),
  -- Brief PR16: the flat cards. A lighter brown that stands clear of the canvas
  -- (ITEMTREE_COLOR_SURFACE_INSET) with a thin warm edge; the band headers a warmer, lighter strip
  -- with a brighter edge, so they read as headers over the cards; and the card's gold edge where
  -- recommended is ITEMTREE_COLOR_PROFESSION_CARD_GOLD.
  ITEMTREE_COLOR_PROFESSION_CARD_FILL = hex("#3F2D1E"),
  ITEMTREE_COLOR_PROFESSION_CARD_EDGE = hex("#6E5236"),
  ITEMTREE_COLOR_PROFESSION_HEADER_FILL = hex("#5E4220"),
  ITEMTREE_COLOR_PROFESSION_HEADER_EDGE = hex("#A27C42"),
  -- Brief PR15: the Trainers & vendors panel's own fill under its card frame, near opaque so the
  -- canvas does not show through its rows.
  ITEMTREE_COLOR_PROFESSION_PANEL_FILL = rgba(16, 12, 8, 0.97),
  -- Brief PR17 (QA round 3): a recipe the player cannot learn yet wears a red tinted card with a
  -- red edge; a recommended one keeps its gold edge tinted toward orange red. The Recommended tag
  -- is solid card gold with dark words, and the padlock is lifted to a pale gold that reads on the
  -- dark cards, the red ones and the bar's locked stretch.
  ITEMTREE_COLOR_PROFESSION_LOCKED_FILL = hex("#4A2220"),
  ITEMTREE_COLOR_PROFESSION_LOCKED_EDGE = hex("#B4453A"),
  ITEMTREE_COLOR_PROFESSION_LOCKED_GOLD = hex("#E08A3C"),
  ITEMTREE_COLOR_PROFESSION_TAG_WORD = hex("#2A1A08"),
  ITEMTREE_COLOR_PROFESSION_LOCK_ICON = hex("#F2E2B8"),
  -- Brief PR19 (QA round 4): the trainer warning strip under the rank bar at a cap below 300, in
  -- an amber warning family: a dark amber fill, a bright amber edge and light amber words.
  ITEMTREE_COLOR_PROFESSION_WARN_FILL = hex("#4A3410"),
  ITEMTREE_COLOR_PROFESSION_WARN_EDGE = hex("#FFA733"),
  ITEMTREE_COLOR_PROFESSION_WARN_WORD = hex("#FFE2A8"),
  -- Brief PR35 (the owner, 2026-10-02): the craft queue tray's profession group header, "a slightly
  -- different colour from the other elements (maybe a grey)", a neutral grey apart from the rows and
  -- the tray's fill; the Requirements box's darker fill under its red or gold edge; the slim scroll
  -- bar's track; and the warm fill of the card a group shows at its band's end.
  ITEMTREE_COLOR_PROFESSION_QUEUE_HEADER_FILL = hex("#2B2D31"),
  -- Brief PR38 item J (the owner: "Make the background colour of this red area slightly lighter
  -- (so the card lifts off the pages slightly)"): was rgba(5, 4, 3, 0.96), darker than the tray's
  -- PROFESSION_PANEL_FILL behind it; now a dark warm red brown a small step lighter than the tray,
  -- the same in the met and unmet states.
  ITEMTREE_COLOR_PROFESSION_QUEUE_REQ_FILL = rgba(40, 24, 20, 0.97),
  ITEMTREE_COLOR_PROFESSION_QUEUE_SCROLL_TRACK = rgba(0, 0, 0, 0.55),
  ITEMTREE_COLOR_PROFESSION_QUEUE_CARD_FILL = hex("#4A3618"),
  -- Brief PR36 (owner QA of PR35, 2026-10-02): the group strip as gunmetal, "a darker grey with a
  -- textured background; it should seem more like grey metal or gunmetal": a cool tint on the
  -- client's dark plate metal (Assets PROFESSION_METAL) and a steel edge along its bevelled
  -- corners; QUEUE_HEADER_FILL above, darkened to gunmetal, is its flat fill where the art will not
  -- draw. The vendor shopping list as a parchment card (Assets PROFESSION_PARCHMENT, or the warm
  -- flat fill and brown edge where it will not draw), with dark ink words, a muted ink, an ink
  -- divider and a faint ink hover.
  ITEMTREE_COLOR_PROFESSION_QUEUE_METAL_TINT = hex("#C9D1DC"),
  ITEMTREE_COLOR_PROFESSION_QUEUE_METAL_EDGE = hex("#6B717A"),
  ITEMTREE_COLOR_PROFESSION_QUEUE_PARCHMENT_FILL = hex("#D9C49B"),
  ITEMTREE_COLOR_PROFESSION_QUEUE_PARCHMENT_EDGE = hex("#7A5630"),
  ITEMTREE_COLOR_PROFESSION_QUEUE_INK = hex("#2B1A0B"),
  ITEMTREE_COLOR_PROFESSION_QUEUE_INK_MUTED = hex("#5A4024"),
  ITEMTREE_COLOR_PROFESSION_QUEUE_INK_DIVIDER = rgba(74, 50, 24, 0.35),
  ITEMTREE_COLOR_PROFESSION_QUEUE_INK_HOVER = rgba(90, 58, 20, 0.16),
  -- Brief LF1 (the owner's QA item 240, 2026-10-18): the "Track another profession" box's faint,
  -- lighter, translucent fill ("Add a slightly lighter bg to that area (transluscent"), the border
  -- gold at a low alpha over the list's inset surface; and the canvas's floating hotkey panel ("one
  -- semi transparent background panel"), the top strip's dark fill at 78 percent, so the route
  -- shows faintly through it. The alphas are the knobs.
  ITEMTREE_COLOR_PROFESSION_ADD_FILL = rgba(201, 166, 92, 0.08),
  ITEMTREE_COLOR_PROFESSION_HINT_FILL = rgba(11, 9, 8, 0.78),
}

-- Two stop vertical fades are the only permitted gradients: { top, bottom }.
Theme.fades = {
  ITEMTREE_FADE_HEADER = { hex("#1C1711"), hex("#0B0A08") },
  ITEMTREE_FADE_BUTTON = { hex("#3A231D"), hex("#1E120F") },
}

-- Client font faces. The design substitutes Marcellus and Archivo Narrow on the web.
Theme.fonts = {
  ITEMTREE_FONT_TITLE = "Fonts\\FRIZQT__.TTF",
  ITEMTREE_FONT_BODY = "Fonts\\ARIALN.TTF",
  ITEMTREE_FONT_NUMBER = "Fonts\\ARIALN.TTF",
}

Theme.fontSizes = {
  ITEMTREE_FONTSIZE_TITLE_LG = 16,
  ITEMTREE_FONTSIZE_TITLE_SM = 14,
  ITEMTREE_FONTSIZE_BODY_LG = 13,
  ITEMTREE_FONTSIZE_BODY_MD = 12,
  ITEMTREE_FONTSIZE_BODY_SM = 11,
}

Theme.lineHeights = {
  ITEMTREE_LINEHEIGHT_TIGHT = 1.0,
  ITEMTREE_LINEHEIGHT_ROW = 1.15,
  ITEMTREE_LINEHEIGHT_PROSE = 1.35,
}

-- Every font string carries a 1px dark shadow; bag quantities use the full outline flag.
Theme.text = {
  ITEMTREE_TEXT_OUTLINE = { x = 1, y = -1, r = 0, g = 0, b = 0, a = 1 },
  ITEMTREE_TEXT_OUTLINE_FULL = "OUTLINE",
}

Theme.sizes = {
  -- 4px scale
  ITEMTREE_SPACE_BASE = 4,
  ITEMTREE_SPACE_1 = 4,
  ITEMTREE_SPACE_2 = 8,
  ITEMTREE_SPACE_3 = 12,
  ITEMTREE_SPACE_4 = 16,
  ITEMTREE_SPACE_5 = 20,
  ITEMTREE_SPACE_6 = 24,
  ITEMTREE_PAD_TIGHT = 8,
  ITEMTREE_PAD_FRAME = 12,
  -- Rows (classic tree) and modern list rows
  ITEMTREE_ROW_TREE = 20,
  ITEMTREE_ROW_TREE_COMPACT = 18,
  ITEMTREE_ROW_CATEGORY = 24,
  ITEMTREE_TREE_INDENT = 16,
  ITEMTREE_LIST_ROW_H = 22,
  ITEMTREE_LIST_ROW_H_COMPACT = 18,
  ITEMTREE_LIST_CATEGORY_H = 24,
  ITEMTREE_LIST_CHANGE_H = 20,
  ITEMTREE_LIST_INDENT = 14,
  ITEMTREE_LIST_INDENT_COMPRESSED = 6,
  ITEMTREE_LIST_DEPTH_MAX = 6,
  ITEMTREE_LIST_CHEVRON = 12,
  ITEMTREE_LIST_ICON = 20,
  ITEMTREE_LIST_COL_QUANTITY = 40,
  ITEMTREE_LIST_COL_BADGES = 48,
  ITEMTREE_LIST_GUTTER = 6,
  ITEMTREE_LIST_COL_META = 104,
  ITEMTREE_LIST_COL_ZONE = 96,
  ITEMTREE_LIST_COL_RATE = 56,
  ITEMTREE_LIST_COL_COUNT = 36,
  -- The info and category columns down the left of the window. The design's three pane template
  -- (templates/bag-interaction) draws both at 150px and has no token for them. They went to
  -- 225 when at 150 an item name and a category name both ran out of room in the client, then
  -- the owner took them to 0.8 of that on 2026-09-26 (225 * 0.8 = 180) to give the tree back
  -- some room. The next nudge is this one number: 225 times the owner's factor, rounded.
  ITEMTREE_LIST_COL_SIDEBAR = 180,
  ITEMTREE_LIST_COL_INFO = 180,
  -- Icons
  -- The root's own art at the top of the info column, which is the primary item of the whole
  -- window: larger than a bag slot, because the design's info column draws it at 48 and 36 read
  -- as too small in the client. The rarity frame the column draws over it (Blizzard's own
  -- WhiteIconFrame, tinted) is square and sits exactly on the icon, so this is the whole
  -- header block's width as well as the icon's.
  ITEMTREE_ICON_HEADER = 40,
  ITEMTREE_ICON_BAGSLOT = 36,
  ITEMTREE_ICON_BAGSLOT_ALT = 32,
  ITEMTREE_ICON_BAGSLOT_MIN = 30,
  ITEMTREE_ICON_TREE = 20,
  ITEMTREE_ICON_CATEGORY = 16,
  ITEMTREE_ICON_BADGE = 12,
  ITEMTREE_ICON_TOGGLE = 12,
  -- Badges
  ITEMTREE_BADGE_SIZE_LIST = 12,
  ITEMTREE_BADGE_SIZE_TOOLTIP = 14,
  ITEMTREE_BADGE_SIZE_TREE = 16,
  ITEMTREE_BADGE_SIZE_SLOT = 18,
  -- Brief BQ14 (QA items 14 and 43): one rarity circle after a profession use line's count, in
  -- pixels high; the gap after each is a third of it (UI/Assets.lua QUALITY_DOT_GAP), 2 at 6.
  ITEMTREE_QUALITY_DOT_SIZE = 6,
  -- Brief T4: the Keep mark's glow. Its alpha (the owner's knob; brief K3 lifted it from 0.55 to
  -- 0.7 under the bevelled frame, still a halo rather than a fill), and its size as a multiple of
  -- the slot: the action button border's art is a 36px ring in a 64px file, so 1.6 times the slot
  -- puts the ring just outside the slot's own edge.
  ITEMTREE_KEEP_GLOW_ALPHA = 0.7,
  ITEMTREE_KEEP_GLOW_SCALE = 1.6,
  -- Brief K3: the Keep mark's bevelled gold frame (Assets KEEP_RING) as a multiple of the slot, so
  -- its dark outline lands just outside the slot's edge and its gold over the icon's own edge.
  ITEMTREE_KEEP_RING_SCALE = 1.06,
  -- Brief K7: the ten Keep looks' sizes, each a multiple of the slot's width unless it says pixels.
  -- The client atlases are drawn at their own size over the client's own 36px slot (the slot
  -- glows are 39px, the new item ribbon 44px, the flash 90px), so a bigger or smaller slot scales
  -- them with it. The bar is 3px tall on a 36px slot. Brief K12: the gem, ItemTree's own cut gem
  -- now, is 0.4 of the slot (it was a third), the flag a third, and the dashed frame the slot's
  -- own size.
  ITEMTREE_KEEP_SLOTGLOW_SCALE = 39 / 36,
  ITEMTREE_KEEP_BORDER_SCALE = 1,
  ITEMTREE_KEEP_INNERGLOW_SCALE = 1,
  ITEMTREE_KEEP_GEM_SCALE = 0.4,
  ITEMTREE_KEEP_FLAG_SCALE = 1 / 3,
  -- Brief K15: the flag sits this many pixels in from the slot's corner on a 36px slot, scaled
  -- with the slot, so it never touches the edge (the gem keeps the badges' 1px inset).
  ITEMTREE_KEEP_FLAG_INSET = 2,
  -- Brief UI15 (QA item 211, the owner: "make play icon smaller for 'use' items (so they are closer
  -- to the flags size) - 80% first pass"): the bag's Use mark (brief BQ9's play wedge, UI/Overlay.lua)
  -- at 80% of BQ9's 0.42 of the slot: 12 px on a 36 px slot (it was 15), the Flag's own size.
  ITEMTREE_USE_MARK_SCALE = 0.42 * 0.8,
  ITEMTREE_KEEP_DASH_SCALE = 1,
  -- Brief K12: the Dashed border's dashes march one period round the frame in this many seconds,
  -- in four quarter steps, and twice as fast at a ramp's top tier.
  ITEMTREE_KEEP_DASH_SECONDS = 0.6,
  ITEMTREE_KEEP_DASH_SECONDS_TOP = 0.3,
  ITEMTREE_KEEP_BAR_HEIGHT = 3,
  -- Brief K8: the bar runs the slot's whole width, in the tier colour for this share of its
  -- length from the left, then fades to the tier colour at this brightness at the right edge, so
  -- the stack count in the bottom right stays readable on it. Brief K12: 0.12, nearly black (it
  -- was 0.45), because the owner found the count still hard to read on the lighter end.
  ITEMTREE_KEEP_BAR_SPLIT = 2 / 3,
  ITEMTREE_KEEP_BAR_DARKEN = 0.12,
  ITEMTREE_KEEP_RIBBON_SCALE = 44 / 36,
  ITEMTREE_KEEP_COSMETIC_SCALE = 1,
  ITEMTREE_KEEP_FLASH_SCALE = 90 / 36,
  -- The Pulse look's alpha cycle: from full to this share of the tier's alpha and back, in
  -- ITEMTREE_KEEP_PULSE_SECONDS for the whole cycle.
  ITEMTREE_KEEP_PULSE_LOW = 0.35,
  ITEMTREE_KEEP_PULSE_SECONDS = 2,
  -- Brief K9: the flame on a valuable item's slot. Each flame is the slot's width and this share
  -- of its height, sits on the top edge reaching this share of its own height down over the
  -- icon, and drifts up this many pixels while it fades over the cycle; the second flame runs
  -- half a cycle behind the first.
  ITEMTREE_KEEP_FLAME_HEIGHT = 0.5,
  ITEMTREE_KEEP_FLAME_OVERLAP = 0.35,
  ITEMTREE_KEEP_FLAME_RISE = 4,
  ITEMTREE_KEEP_FLAME_SECONDS = 2,
  -- Frame
  -- 1000 by 560 is the three pane template's frame grown to suit the wider side columns, not
  -- Frame.jsx's 620 by 460: the window draws the info column as well as the sidebar and the
  -- tree, and 620 left the tree too narrow for a row. See docs/design-deviations.md.
  ITEMTREE_FRAME_DEFAULT_W = 1000,
  ITEMTREE_FRAME_DEFAULT_H = 560,
  -- The minimum still fits both 180px columns, the two tabs and the title bar controls beside
  -- them, with a usable tree in what is left. 840 rather than 820 since brief D2, the least
  -- 10px step that fits a fifth legend entry (Season of Discovery) in the footer.
  ITEMTREE_FRAME_MIN_W = 840,
  ITEMTREE_FRAME_MIN_H = 420,
  ITEMTREE_FRAME_BORDER = 16,
  -- Controls
  ITEMTREE_CONTROL_H_SM = 20,
  ITEMTREE_CONTROL_H_MD = 24,
  ITEMTREE_SCROLLBAR_W = 16,
  -- Chain view
  ITEMTREE_CHAIN_ICON = 36,
  ITEMTREE_CHAIN_GAP = 20,
  ITEMTREE_CHAIN_ARROW = 24,
  -- Modern chrome. The three portrait numbers are the client's own, measured from
  -- PortraitFrameTemplate in Interface/AddOns/Blizzard_SharedXML/Classic/SharedUIPanelTemplates.xml,
  -- which the classic_era and classic_beta branches of the wow-ui-source mirror ship identically:
  -- the round portrait is a 61 by 61 texture at (-6, 8) inside a 78 by 78 ring at (-14, 11), so
  -- the ring reaches 64px in from the left edge and 67px down from the top, and the rock
  -- background under the title tile starts 21px down. ITEMTREE_CHROME_PORTRAIT is the portrait
  -- we draw ourselves on a client with no such template.
  ITEMTREE_CHROME_PORTRAIT = 44,
  ITEMTREE_CHROME_PORTRAIT_INSET_X = 64,
  ITEMTREE_CHROME_PORTRAIT_INSET_Y = 68,
  ITEMTREE_CHROME_TITLE_ART_H = 21,
  ITEMTREE_CHROME_TITLEBAR_H = 28,
  ITEMTREE_CHROME_TAB_H = 24,
  ITEMTREE_CHROME_TAB_W = 86,
  ITEMTREE_CHROME_GRIP = 16,
  -- The client's own top tab, the one the Macro window wears for "General Macros": 32px tall in
  -- TabButtonTemplate, which PanelTopTabButtonTemplate inherits on both the classic_era and the
  -- classic_beta branch. The height is the template's, so the selected and the deselected tab
  -- are the same height and only the art moves.
  ITEMTREE_CHROME_TAB_TOP_H = 32,
  -- The glyph beside each word on a top tab. 14 read as too small against the client's own tab
  -- art in the beta, so the owner asked for the 16 the category glyph is drawn at.
  ITEMTREE_CHROME_TAB_ICON = 16,
  -- The even margin between the window's inner edge (the frame art on three sides, the top
  -- chrome above) and the dark body surface, and the padding inside the surface before anything
  -- is drawn in it. Both sides of every edge, so the dark panel is inset the same all round.
  ITEMTREE_CHROME_BODY_MARGIN = 8,
  -- The mark in the indent gap of a dependent row in the client's settings panel (brief U5):
  -- the side of the square glyph, and the room left between it and the row's label. The client
  -- indents such a row by 15px, so 10 plus 3 fits the gap with a pixel or two to spare.
  ITEMTREE_OPTIONS_CHILD_MARKER = 10,
  ITEMTREE_OPTIONS_CHILD_MARKER_GAP = 3,
  -- The item info column's frame (brief E78): the client's own "Dialog" nine slice layout, drawn at
  -- this scale (a ratio, not pixels) and hung this many pixels outside the column, so the gold rail
  -- sits a couple of pixels in from the column's edge and its transparent margin falls in the gap
  -- between the panes. 0.6 draws a rail about 5px thick with diamond studs at the corners.
  ITEMTREE_INFO_FRAME_SCALE = 0.6,
  ITEMTREE_INFO_FRAME_OUTSET = 5,
  -- The column's scroll thumb (brief E83): the clear gap between the thumb's right edge and the
  -- inner side of the gold rail, in the column's own units (a fraction: 0.35 is a quarter of the
  -- 1.4 it was, lifted to one screen pixel wherever 0.35 units comes to less than that), and
  -- the room between the thumb and the end of the text, kept whether or not the thumb shows so
  -- lines never reflow when it appears.
  ITEMTREE_INFO_SCROLL_GAP = 0.35,
  ITEMTREE_INFO_TEXT_TO_SCROLL = 8,
  -- Borders
  ITEMTREE_BORDER_HAIRLINE = 1,
  ITEMTREE_BORDER_RADIUS = 0,
  -- Brief PR7: the Professions tab's canvas. One band's column, a node's height, the recipe colour
  -- pip, a reagent's icon, the gold border's thickness and the "you are here" line's width.
  ITEMTREE_PROFESSION_COL_W = 200,
  ITEMTREE_PROFESSION_NODE_H = 50,
  ITEMTREE_PROFESSION_PIP = 8,
  ITEMTREE_PROFESSION_REAGENT = 16,
  ITEMTREE_PROFESSION_ROUTE_BORDER = 2,
  ITEMTREE_PROFESSION_HERE_W = 2,
  -- Brief PR13: the card's width (three reagents with three digit counts fit on one row), a card's
  -- height with one reagent row, the gap between two cards (room for the Recommended tag that
  -- straddles a card's top edge and for the glow), the shorter band header, and the rank bar strip
  -- over the canvas.
  ITEMTREE_PROFESSION_CARD_W = 244,
  -- Brief PR16: 8 px of padding inside a card makes one reagent row 50 high, and the gap between
  -- two cards is 8, room only for the Recommended tag that straddles a card's top edge.
  ITEMTREE_PROFESSION_CARD_H = 50,
  ITEMTREE_PROFESSION_CARD_GAP = 8,
  ITEMTREE_PROFESSION_HEADER_H = 30,
  ITEMTREE_PROFESSION_BAR_H = 18,
  -- Brief PR25: back to 56 (PR23 made it 64 for the info column's gold rail), the rank tag, the
  -- bar and the zoom controls on one dark strip with no frame.
  ITEMTREE_PROFESSION_TOP_H = 56,
  -- Brief PR23: how far the "you are here" line's glow reaches left of the line, in screen px.
  -- Brief PR24 (the owner): 60% of PR23's 32.
  ITEMTREE_PROFESSION_HERE_GLOW_W = 19,
  -- Brief PR15: the Trainers & vendors panel's width and one row's height.
  ITEMTREE_PROFESSION_TRAINERS_W = 330,
  ITEMTREE_PROFESSION_TRAINERS_ROW_H = 20,
  -- Brief PR17: the gap between two stacked cards, raised from ITEMTREE_PROFESSION_CARD_GAP's 8
  -- so the Recommended tag on a card's top edge never touches the card above it. Brief PR21: 17,
  -- for the taller tag below.
  ITEMTREE_PROFESSION_CARD_STACK_GAP = 17,
  -- Brief PR21 (QA round 5): the Recommended tag's height on the cards, the block view and the
  -- craft queue's rows (2 px more above and below its words than PR17's 14), and the craft queue
  -- tray's normal sized icons and plate buttons.
  ITEMTREE_PROFESSION_TAG_H = 18,
  ITEMTREE_PROFESSION_QUEUE_ICON = 32,
  ITEMTREE_PROFESSION_QUEUE_BUTTON_H = 24,
  -- Brief PR35: the craft queue tray's most height (the screen less a margin where that is
  -- smaller; the groups scroll inside it) and a profession group's header strip. Brief PR36: the
  -- strip is 30 tall, "a little more padding top and bottom" for its larger words.
  ITEMTREE_PROFESSION_QUEUE_MAX_H = 560,
  ITEMTREE_PROFESSION_QUEUE_HEADER_H = 30,
}

-- Brief K7: the Keep tier ramps, lowest tier first. The owner tunes these by eye. Each tier is a
-- colour token, the alpha it is drawn at, and the colour word of the client's own quality art
-- (bags-glow-<word> and auctionhouse-itemicon-border-<word>) the Slot glow and Thin border looks
-- draw for it. The word "white" is drawn tinted in the tier's colour, every other word in the
-- art's own colour at the tier's alpha. The top tier of every ramp is the loudest, because the
-- over 100 gold legendary mark (brief 155) will land there. Brief K8: hue is the colour in plain
-- words, which the demo's chat line names for the top tier. Brief K15: single, the Single colour
-- set, is one tier built from the player's keepColor by Theme.SingleRamp below.
Theme.keepRamps = {
  order = { "gold", "quality", "heat", "single" },
  gold = {
    name = "Gold",
    { color = "ITEMTREE_COLOR_KEEP_GLOW", alpha = 0.7, word = "artifact", hue = "gold" },
    { color = "ITEMTREE_COLOR_KEEP_GOLD_BRIGHT", alpha = 1, word = "artifact", hue = "bright gold" },
  },
  quality = {
    name = "Quality",
    { color = "ITEMTREE_COLOR_QUALITY_UNCOMMON", alpha = 0.75, word = "green", hue = "green" },
    { color = "ITEMTREE_COLOR_QUALITY_RARE", alpha = 0.8, word = "blue", hue = "blue" },
    { color = "ITEMTREE_COLOR_QUALITY_EPIC", alpha = 0.9, word = "purple", hue = "purple" },
    { color = "ITEMTREE_COLOR_QUALITY_LEGENDARY", alpha = 1, word = "orange", hue = "orange" },
  },
  heat = {
    name = "Heat",
    { color = "ITEMTREE_COLOR_KEEP_GLOW", alpha = 0.7, word = "artifact", hue = "gold" },
    { color = "ITEMTREE_COLOR_KEEP_HEAT_ORANGE", alpha = 0.85, word = "orange", hue = "orange" },
    { color = "ITEMTREE_COLOR_KEEP_HEAT_RED", alpha = 1, word = "white", hue = "red" },
  },
}

-- Brief K15: the Single colour set's palette, the quick picks of the Keep marks Colour row. Each is
-- a colour token, the alpha it is drawn at and its colour in plain words for the captions and the
-- demo's line. The owner tunes these by eye. "custom" is not a pick here: it is the player's own
-- colour from the colour picker (settings keepColorCustom), drawn at KEEP_CUSTOM_ALPHA.
-- Brief K17: Yellow first, the valuable colour that ships; Green, the colour that ships, is in the
-- list as before.
Theme.keepColors = {
  order = { "yellow", "gold", "orange", "red", "pink", "purple", "blue", "teal", "green", "white", "silver" },
  yellow = { color = "ITEMTREE_COLOR_KEEP_YELLOW", alpha = 0.9, hue = "yellow" },
  gold = { color = "ITEMTREE_COLOR_KEEP_GLOW", alpha = 0.85, hue = "gold" },
  orange = { color = "ITEMTREE_COLOR_KEEP_HEAT_ORANGE", alpha = 0.9, hue = "orange" },
  red = { color = "ITEMTREE_COLOR_KEEP_HEAT_RED", alpha = 0.9, hue = "red" },
  pink = { color = "ITEMTREE_COLOR_KEEP_PINK", alpha = 0.9, hue = "pink" },
  purple = { color = "ITEMTREE_COLOR_QUALITY_EPIC", alpha = 0.9, hue = "purple" },
  blue = { color = "ITEMTREE_COLOR_QUALITY_RARE", alpha = 0.9, hue = "blue" },
  teal = { color = "ITEMTREE_COLOR_KEEP_TEAL", alpha = 0.9, hue = "teal" },
  green = { color = "ITEMTREE_COLOR_QUALITY_UNCOMMON", alpha = 0.9, hue = "green" },
  white = { color = "ITEMTREE_COLOR_QUALITY_COMMON", alpha = 0.8, hue = "white" },
  silver = { color = "ITEMTREE_COLOR_TEXT_RARE_SILVER", alpha = 0.85, hue = "silver" },
}
-- Brief K17: green ships (settings keepColor), so anything unreadable reads as green too.
Theme.KEEP_COLOR_DEFAULT = "green"
Theme.KEEP_COLOR_CUSTOM = "custom"
Theme.KEEP_CUSTOM_ALPHA = 0.9

-- Collapsing rules (design patterns: Collapsing rules card).
Theme.rules = {
  DEFAULT_EXPAND_DEPTH = 2,
  GROUP_CHILD_LIMIT = 8,
  GROUP_OVERFLOW_HINT = 12,
}

local QUALITY_KEYS = {
  [0] = "ITEMTREE_COLOR_QUALITY_POOR",
  [1] = "ITEMTREE_COLOR_QUALITY_COMMON",
  [2] = "ITEMTREE_COLOR_QUALITY_UNCOMMON",
  [3] = "ITEMTREE_COLOR_QUALITY_RARE",
  [4] = "ITEMTREE_COLOR_QUALITY_EPIC",
  [5] = "ITEMTREE_COLOR_QUALITY_LEGENDARY",
}

Theme.QUALITY_NAMES = { [0] = "poor", "common", "uncommon", "rare", "epic", "legendary" }

-- Returns r, g, b, a for a colour key.
function Theme.Color(key)
  local c = Theme.colors[key]
  if not c then
    error("unknown theme colour " .. tostring(key), 2)
  end
  return c.r, c.g, c.b, c.a
end

function Theme.ColorTable(key)
  return Theme.colors[key]
end

-- "ffd100" style hex for |cff escapes. Alpha is dropped.
function Theme.Hex(key)
  local c = Theme.colors[key]
  if not c then
    error("unknown theme colour " .. tostring(key), 2)
  end
  if c.hex then
    return c.hex:lower()
  end
  return string.format(
    "%02x%02x%02x",
    math.floor(c.r * 255 + 0.5),
    math.floor(c.g * 255 + 0.5),
    math.floor(c.b * 255 + 0.5)
  )
end

-- Wraps text in a colour escape the client understands.
function Theme.Colorise(key, text)
  return "|cff" .. Theme.Hex(key) .. tostring(text) .. "|r"
end

-- The Theme colour key an item quality resolves to. A quality this table has no row for reads
-- as common, which is what the client does with an item it cannot resolve, and is the fallback
-- every caller wants. This is the one place the quality to key table is read, so no module has
-- to mirror it.
function Theme.QualityKey(quality)
  return QUALITY_KEYS[quality] or QUALITY_KEYS[1]
end

function Theme.QualityHex(quality)
  return Theme.Hex(Theme.QualityKey(quality))
end

-- The colour a translucent colour makes over an opaque one: { r, g, b } in 0 to 1, alpha 1. Pure,
-- so a spec can measure what a wash actually draws.
function Theme.Blend(top, bottom)
  local a = top.a or 1
  return {
    r = top.r * a + bottom.r * (1 - a),
    g = top.g * a + bottom.g * (1 - a),
    b = top.b * a + bottom.b * (1 - a),
    a = 1,
  }
end

local function channel(value)
  if value <= 0.03928 then
    return value / 12.92
  end
  return ((value + 0.055) / 1.055) ^ 2.4
end

-- WCAG relative luminance of a colour table.
function Theme.Luminance(color)
  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b)
end

-- The WCAG contrast ratio between two opaque colour tables, 1 to 21, either order.
function Theme.Contrast(first, second)
  local a, b = Theme.Luminance(first), Theme.Luminance(second)
  if a < b then
    a, b = b, a
  end
  return (a + 0.05) / (b + 0.05)
end

-- Brief K15: a stored keepColor as one of the palette's keys or "custom". Anything else is the
-- default (green since brief K17). Pure.
-- Brief K16: fallback is the key anything else reads as, the default unless given (the valuable
-- colour's is yellow since brief K17).
function Theme.KeepColorKey(value, fallback)
  local name = type(value) == "string" and value:lower() or nil
  if name == Theme.KEEP_COLOR_CUSTOM then
    return name
  end
  if name and name ~= "order" and type(Theme.keepColors[name]) == "table" then
    return name
  end
  return fallback or Theme.KEEP_COLOR_DEFAULT
end

local function channelOf(value)
  local number = tonumber(value)
  if number == nil or number ~= number then
    return nil
  end
  if number < 0 then
    return 0
  end
  if number > 1 then
    return 1
  end
  return number
end

-- Brief K15: a stored keepColorCustom as a fresh { r, g, b } in 0 to 1, each channel clamped. A
-- value that is not a table of three numbers reads as the keep gold, the setting's default. Pure.
-- Brief K16: fallbackToken is the colour token anything else reads as, the keep gold unless given
-- (the valuable colour's is the legendary orange).
function Theme.CustomColour(value, fallbackToken)
  if type(value) == "table" then
    local r, g, b = channelOf(value.r), channelOf(value.g), channelOf(value.b)
    if r and g and b then
      return { r = r, g = g, b = b }
    end
  end
  local fallback = Theme.colors[fallbackToken or "ITEMTREE_COLOR_KEEP_GLOW"] or Theme.colors.ITEMTREE_COLOR_KEEP_GLOW
  return { r = fallback.r, g = fallback.g, b = fallback.b }
end

-- Brief K15: the Single colour ramp, one tier in the colour keepColor names (the player's own
-- keepColorCustom for "custom"), in Theme.keepRamps' shape. A palette pick carries its token, the
-- custom colour its rgb and no token. The art word is "white" for every pick, so the looks that
-- pick the client's art by colour word (Slot glow, Thin border) draw the white art tinted. Pure:
-- a new table each call.
function Theme.SingleRamp(colorKey, custom)
  local key = Theme.KeepColorKey(colorKey)
  local entry
  if key == Theme.KEEP_COLOR_CUSTOM then
    entry = { rgb = Theme.CustomColour(custom), alpha = Theme.KEEP_CUSTOM_ALPHA, word = "white", hue = "custom" }
  else
    local pick = Theme.keepColors[key]
    entry = { color = pick.color, alpha = pick.alpha, word = "white", hue = pick.hue }
  end
  entry.key = key
  return { name = "Single colour", entry }
end

-- Built at draw time from the settings (UI/Overlay.lua Overlay.SyncSingle); the default until
-- then, so the ramp is always there to name.
Theme.keepRamps.single = Theme.SingleRamp(Theme.KEEP_COLOR_DEFAULT)

-- Brief K16: the colour a valuable item wears its look in while the Single colour set is chosen,
-- from the player's keepValueColor: the same palette and Custom (keepValueColorCustom). Orange is
-- the fixed valuable tint the Gold, Quality and Heat sets use: the legendary orange
-- (ITEMTREE_COLOR_KEEP_VALUE) at full alpha with the client's orange art. Every other pick is drawn
-- at full alpha, as the valuable tint always was, with the white art tinted. Answers { color or
-- rgb, alpha, word, hue, key }. Pure: a new table. Brief K17: Yellow ships (settings
-- keepValueColor), so anything unreadable reads as Yellow; the fixed orange is KEEP_VALUE_COLOR_FIXED.
Theme.KEEP_VALUE_COLOR_DEFAULT = "yellow"
Theme.KEEP_VALUE_COLOR_FIXED = "orange"
Theme.KEEP_VALUE_TOKEN = "ITEMTREE_COLOR_KEEP_VALUE"

function Theme.ValueColourEntry(colorKey, custom)
  local key = Theme.KeepColorKey(colorKey, Theme.KEEP_VALUE_COLOR_DEFAULT)
  local entry
  if key == Theme.KEEP_COLOR_CUSTOM then
    entry = { rgb = Theme.CustomColour(custom, Theme.KEEP_VALUE_TOKEN), alpha = 1, word = "white", hue = "custom" }
  elseif key == Theme.KEEP_VALUE_COLOR_FIXED then
    entry = { color = Theme.KEEP_VALUE_TOKEN, alpha = 1, word = "orange", hue = "orange" }
  else
    local pick = Theme.keepColors[key]
    entry = { color = pick.color, alpha = 1, word = "white", hue = pick.hue }
  end
  entry.key = key
  return entry
end

-- A size token's value, or fallback where the table has no row for it. Brief OPT4: the one copy of
-- the size(key, fallback) helper six panes each carried (UI/BossLoot, Discoveries, Guesses,
-- History, Sidebar and ZoneItems). It used to raise on an unknown key, and nothing called it then.
function Theme.Size(key, fallback)
  local value = Theme.sizes[key]
  return value or fallback
end

-- Row height for the current density.
function Theme.RowHeight(density)
  return density == "compact" and Theme.sizes.ITEMTREE_LIST_ROW_H_COMPACT or Theme.sizes.ITEMTREE_LIST_ROW_H
end

-- Indent compresses past depth 6 so deep chains stay readable in an 800px frame.
function Theme.Indent(depth)
  local step, max, compressed =
    Theme.sizes.ITEMTREE_LIST_INDENT, Theme.sizes.ITEMTREE_LIST_DEPTH_MAX, Theme.sizes.ITEMTREE_LIST_INDENT_COMPRESSED
  if depth <= max then
    return depth * step
  end
  return max * step + (depth - max) * compressed
end

return Theme
