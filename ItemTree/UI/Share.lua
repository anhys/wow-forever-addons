-- Brief SH1, redesigned by brief SH5 (the owner's first QA of the share feature): the share window
-- ("Help make ItemTree better"), the yellow text link on the main window that opens it, and the
-- link's ping after an update.
--
-- The window is built in the spirit of itemtree.net: a dark surface in a gold edge, the logo mark,
-- the title in gold over a thin gold rule, one line of thanks, then two numbered steps in the
-- order the player takes them. Step 1 says to open the site and holds its address in a one line
-- box, selected on click (an addon cannot open a browser). Step 2 says to copy the text and paste
-- it there with the copy key (Ctrl+C, or Cmd+C on a Mac) over a gold edged box holding the text
-- (Core/Share.lua) read only, all of it selected on a click (owner QA 2026-10-04 took the Select all
-- button away). A muted footer says only game information goes. The counts of
-- what is in the text live in the box's tooltip and nowhere else.
--
-- Brief SH2: a text longer than Share.PART_BYTES comes in parts, newest first. The window then
-- shows "Part 1 of 3" with Previous and Next under the box and a line saying to copy this part,
-- paste it, then press Next; with one part none of that shows and the window is that much shorter
-- (UIShare.Layout stacks the rows).
--
-- Brief SH3: the Credit my character box, now the smallest row under the box: the tick box and its
-- words, the explanation only in its tooltip. Off by default and remembered in
-- settings.shareCredit. Ticked, the text carries this character's name and realm and the footer
-- says so. UIShare.CREDIT_BOX = false hides the row and keeps every name out of the text.
--
-- The link: "Help make ItemTree better" in yellow, one point smaller than the tab words, with a
-- round "!" medallion to its left (brief SH8, the owner's picture: a filled gold disc drawn through
-- the round portrait mask with a dark brown "!" centred on it), top left of the main window,
-- centred in the gap between the title bar and the tab row (UI/Frame.lua anchors it at
-- Frame.ShareLinkSpot). The first time the main window opens after the addon's version changed
-- (Share.PulseDue: never on a fresh install's first load, once after each update), it plays once:
-- two gold rings ping out of the medallion and fade, staggered, while a glow under the words and
-- the medallion pulses three times and settles. About four seconds (owner QA 2026-10-04 doubled
-- it), no sound, and a click on the link ends it at once.
--
-- Brief TY1 (owner item 235): the thank you note, a once off popover hanging under the link with a
-- notch at its top pointing up at it and the client's red X top right. It shows from the first open
-- after an update (the same version check as the ping, never on a fresh install) on every open until
-- the player closes it with the X or a click on the link; a closed message id is remembered account
-- wide (Core/Share.lua Share.NoticeDue), so alts never see it again, and a new UIShare.NOTICE_ID is a
-- new message. The ping is untouched and plays beside it (the owner, 2026-10-18). No setting.
-- Brief TY2 (owner item 311, his QA of TY1): the note is centred under the link and kept inside the
-- window, its words in the smaller body font with room between the lines, under a heading "Thanks
-- for your support" with ItemTree's mark before it and the red X beside it. Its edge and its notch's
-- outline are whole screen pixels of one weight (NOTICE_EDGE_PIXELS), so they meet cleanly. The
-- developer commands /itemtree demo share due and /itemtree demo share reset test the real once only
-- path in game (UIShare.NoticeCommand).
-- Brief FF1 (the owner, 2026-10-24): no note on the live client, where every player is a fresh
-- install and would see "during the beta" at their first update. UIShare.NOTICE_ID is nil, so no
-- update makes a note due; the feature stays (the words, the art, Share.NoticeDue and CloseNotice)
-- for a later, better timed ask ("maybe at the 1 month mark"). /itemtree demo share still shows it.
--
-- The addon sends nothing anywhere: no network, no addon message, no chat line. The text is built
-- only when the window opens or the box is ticked, under Guard.Run, and lives only in the box.
--
-- Focus (gamepad taint, 2026-10-03): opening the window never gives anything the keyboard focus.
-- Only the player's own click focuses a box (a click on a box, Previous and Next).
-- A slash command books its open for the next tick (UI/Slash.lua), so nothing here runs inside
-- the chat edit box's send path.
--
-- Own frames only: nothing here sets a script or a field on a client frame, and the one client
-- table written is UISpecialFrames, our own name appended once, so Escape closes the window.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local UIShare = {}
ItemTree.UI.Share = UIShare

local Assets = ItemTree.Assets
local Theme = ItemTree.Theme
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

UIShare.FRAME_NAME = "ItemTreeShareFrame"
UIShare.WIDTH = 460
-- The side padding, and the room above the first row and under the last.
UIShare.PAD = 24
UIShare.TOP_PAD = 18
UIShare.BOTTOM_PAD = 18
-- The footer's line, and the most lines it may take; it wraps rather than run off the window.
UIShare.FOOTER_LINE = 14
UIShare.FOOTER_LINES = 3
UIShare.LOGO = 40
UIShare.BOX_H = 140
UIShare.ADDRESS_H = 22
UIShare.BUTTON_H = 24
UIShare.PART_BUTTON_W = 84
-- The Credit my character row (brief SH3). Hidden for now (owner ruling 2026-10-04), code kept: false hides
-- the row and keeps every name out of the text.
UIShare.CREDIT_BOX = false
UIShare.CHECK_SIZE = 22

-- The link: its height (the words' line, so it fits the gap it is centred in), the medallion's
-- side and the room between the medallion and the words. Owner QA 2026-10-04: the medallion and
-- its "!" at 75 percent (16 to 12, MARK_SIZE 12 to 9); both stay centred on the link's middle.
UIShare.LINK_H = 16
UIShare.LINK_ICON = 12
UIShare.LINK_GAP = 5
-- Brief SH8: the words are drawn in the tab words' own font object, LINK_FONT_STEP points smaller
-- and never under LINK_FONT_MIN; LINK_FONT_FALLBACK is the size where the client reports none.
UIShare.LINK_FONT_OBJECT = "GameFontNormalSmall"
UIShare.LINK_FONT_STEP = 1
UIShare.LINK_FONT_MIN = 9
UIShare.LINK_FONT_FALLBACK = 10
-- Brief SH8: the medallion, a filled disc in the title gold with the "!" in a dark brown ink,
-- MARK_SIZE points, drawn once on a whole pixel. Brief SH11 (owner QA 2026-10-04: the outlined "!"
-- looked blobby): plain text, no outline flag, with the theme's 1px drop shadow (MARK_SHADOW where
-- the theme has none).
UIShare.DISC_COLOR = "ITEMTREE_COLOR_TEXT_TITLE"
UIShare.MARK_COLOR = "ITEMTREE_COLOR_PROFESSION_QUEUE_INK"
UIShare.MARK_SIZE = 9
UIShare.MARK_FLAGS = ""
UIShare.MARK_SHADOW = { x = 1, y = -1, r = 0, g = 0, b = 0, a = 0.8 }
-- Brief SH11: how the "!" is drawn. "text" (the default) is the font string above; "shape" draws
-- it as two flat textures in the mark's colour, a bar MARK_BAR_W by MARK_BAR_H over a square dot
-- MARK_DOT on a side, MARK_DOT_GAP apart, sized for a MARK_SHAPE_DISC disc and scaled with the
-- disc, no font involved. Flip this one line to switch.
UIShare.MARK_STYLE = "text"
UIShare.MARK_SHAPE_DISC = 12
UIShare.MARK_BAR_W = 2
UIShare.MARK_BAR_H = 5
UIShare.MARK_DOT = 2
UIShare.MARK_DOT_GAP = 1
-- The ping: each ring grows from the medallion's size to PING_SCALE times it and fades from
-- PING_ALPHA to nothing over PING_SECONDS; the second starts PING_STAGGER later. The glow under
-- the words rises to GLOW_HIGH and falls back GLOW_PULSES times, GLOW_PULSE_SECONDS each. Owner
-- QA 2026-10-04 doubled every duration and the stagger.
UIShare.PING_SECONDS = 3
UIShare.PING_SCALE = 3
UIShare.PING_ALPHA = 0.9
UIShare.PING_STAGGER = 0.8
UIShare.GLOW_PULSES = 3
UIShare.GLOW_PULSE_SECONDS = 1
UIShare.GLOW_HIGH = 0.8
-- The art: the ping ring is the composed badges' own ring (BADGE_RING, the client's ping
-- texture), the glow the panel button's highlight, the medallion's disc a flat fill drawn through
-- the portrait mask.
UIShare.RING_ART = "BADGE_RING"
UIShare.GLOW_ART = "BUTTON_HIGHLIGHT"
UIShare.MASK_ART = "PORTRAIT_MASK"
UIShare.LOGO_ART = "LOGO_MARK"
UIShare.MARK = "!"

-- Brief TY1: the thank you note. NOTICE_ID names the message: a closed id never shows again, and a
-- new id (with new words in UIShare.NoticeText) is a new message for everyone who updates; nil shows
-- none. Its surface and edge colours.
-- Brief FF1 (the owner, 2026-10-24: "we'll be strategic at which points we ask more directly for
-- data"): nil, so no note shows on live. To turn a future ask on, set a NEW id (never "beta-thanks",
-- which every beta player who closed it has remembered as closed) and give it new words in
-- UIShare.NoticeText: the words there now are the beta's alone.
UIShare.NOTICE_ID = nil
UIShare.NOTICE_SURFACE = "ITEMTREE_COLOR_SURFACE_TOOLTIP_OPAQUE"
UIShare.NOTICE_EDGE_COLOR = "ITEMTREE_COLOR_BORDER_GOLD"
UIShare.NOTICE_FILL_ART = "FILL_WHITE8X8"
-- Brief TY2 (owner item 311: "The font is huge and hard to read because its cramped"): 240 wide (TY1
-- 260), the room inside its edge (TY1 12 a side, 10 over, 12 under), and the heading row: ItemTree's
-- mark NOTICE_ICON on a side, NOTICE_ICON_GAP before "Thanks for your support" in NOTICE_HEAD_FONT,
-- the red X (NOTICE_CLOSE on a side, NOTICE_CLOSE_INSET in from the right edge) centred on the row,
-- and NOTICE_HEAD_GAP down to the words. The words run the note's whole width under the row in
-- NOTICE_FONT (TY1: GameFontHighlight beside the X), NOTICE_SPACING between their lines.
UIShare.NOTICE_WIDTH = 240
UIShare.NOTICE_PAD = 14
UIShare.NOTICE_TOP_PAD = 10
UIShare.NOTICE_BOTTOM_PAD = 14
UIShare.NOTICE_ICON = 16
UIShare.NOTICE_ICON_GAP = 6
UIShare.NOTICE_HEAD_GAP = 7
UIShare.NOTICE_HEAD_FONT = "GameFontNormal"
UIShare.NOTICE_FONT = "GameFontHighlightSmall"
UIShare.NOTICE_SPACING = 3
UIShare.NOTICE_CLOSE = 22
UIShare.NOTICE_CLOSE_INSET = 4
UIShare.NOTICE_CLOSE_ROOM = 28
-- Brief TY2 (owner item 311: the notch "slightly over the border causing a weird partial cut ... its
-- border is skinnier than the main tooltip"): the edge is NOTICE_EDGE_PIXELS whole screen pixels
-- (TY1 one unit, which at the owner's 1.2 pixels a unit can draw one pixel or two), nearer the weight
-- of the tooltip's edge, and the notch's outline is the same weight across its slope. NOTICE_NOTCH is how far the
-- notch's inside stands above the note and NOTICE_GAP the room between its tip and the link, both
-- rounded to whole screen pixels, and NOTICE_NOTCH_MARGIN the least room between it and either end.
UIShare.NOTICE_EDGE_PIXELS = 2
UIShare.NOTICE_NOTCH = 8
UIShare.NOTICE_GAP = 3
UIShare.NOTICE_NOTCH_MARGIN = 16
-- Brief TY2: the least room between the note and the window's left or right edge, so centring it
-- under the link never pushes it off the window.
UIShare.NOTICE_WINDOW_MARGIN = 12
-- How many levels over the main window it draws, so it lies on the tabs and the panes under the link.
UIShare.NOTICE_LEVEL = 100
-- The words' line with its spacing, and how many lines are assumed where the client measures none.
UIShare.NOTICE_LINE = 13
UIShare.NOTICE_LINES = 5

local function core()
  return ItemTree.Share
end

--- The address the window shows: Share.URL, else the developer demo's placeholder, else "". Pure.
function UIShare.Address()
  local share = core()
  local url = share and share.URL or nil
  if type(url) == "string" and url ~= "" then
    return url
  end
  if type(UIShare.demoAddress) == "string" then
    return UIShare.demoAddress
  end
  return ""
end

--- The muted footer: that only game information goes. creditState "on" (brief SH3, ticked and
--- named) says the text holds the character's name; anything else says no personal data. failed
--- says the text could not be built instead. Pure.
function UIShare.Footer(creditState, failed)
  if failed then
    return L["The text could not be built. The details are in /itemtree debug."]
  end
  if creditState == "on" then
    return L["ItemTree sends nothing by itself. The text holds what you recorded and your character's name."]
  end
  return L["Only game information is exported. No personal data is included."]
end

--- The thanks line under the title. Pure.
function UIShare.Thanks()
  return L["Sharing what you find on your journeys helps make ItemTree's data more accurate."]
end

--- Step 2's words, naming the copy key: Cmd+C when mac is true, Ctrl+C otherwise. Pure.
function UIShare.CopyStep(mac)
  if mac == true then
    return L["2. Copy this text with Cmd+C, then paste it there"]
  end
  return L["2. Copy this text with Ctrl+C, then paste it there"]
end

--- The footer row's height for the footer's measured text height: whole lines, at least one and at
--- most UIShare.FOOTER_LINES; two lines where the client gave no height. Pure.
function UIShare.FooterHeight(measured)
  local line = UIShare.FOOTER_LINE
  local height = tonumber(measured)
  if not height or height <= 0 then
    return 2 * line
  end
  local lines = math.max(1, math.min(math.ceil(height / line - 0.01), UIShare.FOOTER_LINES))
  return lines * line
end

--- Brief SH3: what the box does, for its tooltip. Pure.
function UIShare.CreditTip()
  -- luacheck: push ignore 631
  return L["Adds this character's name and realm to the text, so it can be listed on the ItemTree site among the players who helped. Off leaves every name out."]
  -- luacheck: pop
end

--- Brief SH3: the tooltip's lines under its heading: what the box does, and for creditState
--- "missing" (ticked, but the client gave no name) that the text holds none. Pure.
function UIShare.CreditTipLines(creditState)
  local lines = { UIShare.CreditTip() }
  if creditState == "missing" then
    lines[#lines + 1] = L["This character's name could not be read, so the text holds no name."]
  end
  return lines
end

--- The text box's tooltip: Share.Summary's counts line, its size and, for several parts, how
--- many. nil where the text could not be built. Pure.
function UIShare.BoxTipLines(summary)
  if type(summary) ~= "table" or not summary.line then
    return nil
  end
  local lines = { summary.line }
  if summary.sizeLine then
    lines[#lines + 1] = summary.sizeLine
  end
  local parts = tonumber(summary.parts) or 0
  if parts > 1 then
    lines[#lines + 1] = string.format(L["%d parts, newest first"], parts)
  end
  return lines
end

--- "Part 1 of 3" for a text in several parts, nil for one in a single part. Pure.
function UIShare.PartLabel(index, count)
  count = tonumber(count) or 0
  if count <= 1 then
    return nil
  end
  return string.format(L["Part %d of %d"], tonumber(index) or 1, count)
end

--- The window's rows top to bottom, each { name, height, gap above }. The parts rows come only
--- with several parts, the credit row only while UIShare.CREDIT_BOX is on. footerHeight is the
--- footer row's (UIShare.FooterHeight), one line when not given. Pure.
function UIShare.Rows(several, credit, footerHeight)
  local rows = {
    { "logo", UIShare.LOGO, 0 },
    { "title", 18, 8 },
    { "rule", 1, 10 },
    { "thanks", 30, 10 },
    { "step1", 14, 14 },
    { "address", UIShare.ADDRESS_H, 6 },
    { "step2", 14, 16 },
    { "box", UIShare.BOX_H, 6 },
  }
  if several then
    rows[#rows + 1] = { "parts", UIShare.BUTTON_H, 6 }
    rows[#rows + 1] = { "partHint", 14, 4 }
  end
  if credit then
    rows[#rows + 1] = { "credit", UIShare.CHECK_SIZE, 6 }
  end
  rows[#rows + 1] = { "footer", tonumber(footerHeight) or UIShare.FOOTER_LINE, 10 }
  return rows
end

--- Where each row starts below the window's top edge, by name, the order they stack in, and the
--- window's height, which leaves UIShare.BOTTOM_PAD under the footer row. Pure.
function UIShare.Layout(several, credit, footerHeight)
  local top, order = {}, {}
  local y = UIShare.TOP_PAD
  for _, row in ipairs(UIShare.Rows(several, credit, footerHeight)) do
    y = y + row[3]
    top[row[1]] = y
    order[#order + 1] = row[1]
    y = y + row[2]
  end
  return { top = top, order = order, height = y + UIShare.BOTTOM_PAD }
end

--- Brief TY1: the thank you note's words, in one key so a change is one line. Pure. Brief FF1: they
--- are the beta's ("beta-thanks"), shown now only by the developer demo while NOTICE_ID is nil; a
--- future ask gets new words with its new id.
function UIShare.NoticeText()
  -- luacheck: push ignore 631
  return L["If you enjoyed ItemTree during the beta, please help make it better by sending your game data through the link above. Thank you for trying ItemTree, and for your feedback."]
  -- luacheck: pop
end

--- Brief TY2 (owner item 311, "Maybe we need a "Thanks for your support" + an icon"): the note's
--- heading, after ItemTree's mark. Pure.
function UIShare.NoticeHeading()
  return L["Thanks for your support"]
end

--- Brief TY2 (owner item 311, "Centre it underneath better"; TY1 hung it NOTICE_OUTSET left of the
--- link, so it ran far past the link's right end): where the note sits for a link linkWidth wide whose
--- left edge is linkLeft in from the window's left edge (Frame.ShareLinkSpot), in a window
--- windowWidth wide. The note is centred on the middle of the link, then moved only as far as keeps
--- it NOTICE_WINDOW_MARGIN inside the window (a linkLeft or windowWidth not given is not checked).
--- Answers x, the note's left edge measured from the link's left edge, and notch, the notch's tip
--- measured from the note's left edge (under the middle of the link, and never nearer either end of
--- the note than NOTICE_NOTCH_MARGIN). Whole units. Pure.
function UIShare.NoticePlace(linkLeft, linkWidth, windowWidth)
  local width = UIShare.NOTICE_WIDTH
  local linkW = tonumber(linkWidth)
  if not linkW or linkW < 0 then
    linkW = 0
  end
  local middle = math.floor(linkW / 2 + 0.5)
  local x = middle - math.floor(width / 2 + 0.5)
  local left = tonumber(linkLeft)
  if left then
    local margin = UIShare.NOTICE_WINDOW_MARGIN
    local wide = tonumber(windowWidth)
    if wide and wide >= width + 2 * margin then
      x = math.min(x, math.floor(wide - margin - width - left))
    end
    x = math.max(x, math.ceil(margin - left))
  end
  local least = UIShare.NOTICE_NOTCH_MARGIN
  local notch = math.max(least, math.min(middle - x, width - least))
  return x, notch
end

--- Brief TY1: the note's height for its words' measured height. Brief TY2: the heading row (the mark's
--- height) and its gap over the words, then the words with the room above and below; NOTICE_LINES
--- lines where the client measured none. Pure.
function UIShare.NoticeHeight(measured)
  local height = tonumber(measured)
  if not height or height <= 0 then
    height = UIShare.NOTICE_LINES * UIShare.NOTICE_LINE
  end
  return UIShare.NOTICE_TOP_PAD
    + UIShare.NOTICE_ICON
    + UIShare.NOTICE_HEAD_GAP
    + math.ceil(height)
    + UIShare.NOTICE_BOTTOM_PAD
end

--- Brief TY1: the notch is two squares, each turned 45 degrees into a diamond and centred on the
--- note's top edge, so half of each stands above the note. The gold one (outer) lies under the note's
--- surface, the inner one in the surface's colour over it, so the notch keeps a gold outline. Brief
--- TY2: the top edge stops at the notch's mouth from either side (TY1 painted the inner square over
--- a whole edge, the owner's "weird partial cut"), and every size is whole screen pixels,
--- unitsPerPixel being one screen pixel in the note's units (Core/Util.lua Util.ScreenPixel; one
--- unit where the client will not say), so the diamonds' corners land on whole pixels and their
--- outline steps evenly. The edge is NOTICE_EDGE_PIXELS; the outline across the slope is as heavy,
--- its tip being that many pixels times the square root of two (rounded) above the inner tip.
--- Answers the units for: pixel (one screen pixel), edge (the edge's thickness), inner and outer
--- (the squares' sides before the turn), mouth (half the notch's opening where it meets the note's
--- top edge, so the edge stops there), rise (how far the gold tip stands above the note's top edge)
--- and gap (between the tip and the link). Pure.
function UIShare.NoticeNotch(unitsPerPixel)
  local pixel = tonumber(unitsPerPixel)
  if not pixel or pixel <= 0 then
    pixel = 1
  end
  local function whole(units, least)
    return math.max(least, math.floor(units / pixel + 0.5))
  end
  local edgePixels = math.max(1, math.floor(tonumber(UIShare.NOTICE_EDGE_PIXELS) or 1))
  local band = math.max(1, math.floor(edgePixels * math.sqrt(2) + 0.5))
  local inner = whole(UIShare.NOTICE_NOTCH, 2)
  local outer = inner + band
  return {
    pixel = pixel,
    edge = edgePixels * pixel,
    inner = inner * math.sqrt(2) * pixel,
    outer = outer * math.sqrt(2) * pixel,
    mouth = inner * pixel,
    rise = outer * pixel,
    gap = whole(UIShare.NOTICE_GAP, 0) * pixel,
  }
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

local function newFrame(kind, name, parent, template)
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  if template then
    local ok, frame = pcall(create, kind, name, parent, template)
    if ok and frame then
      return frame
    end
  end
  local ok, frame = pcall(create, kind, name, parent)
  if ok and frame then
    return frame
  end
  return nil
end

local function call(object, name, ...)
  if type(object) == "table" and type(object[name]) == "function" then
    local ok, answer = pcall(object[name], object, ...)
    if ok then
      return answer
    end
  end
  return nil
end

local function themeColor(key)
  local color = Theme and type(Theme.ColorTable) == "function" and Theme.ColorTable(key) or nil
  if not color then
    return nil
  end
  return color.r, color.g, color.b
end

local function assetPath(key)
  if not (Assets and type(Assets.Has) == "function" and Assets.Has(key)) then
    return nil
  end
  local ok, entry = pcall(Assets.Get, key)
  if ok and type(entry) == "table" then
    return entry.path
  end
  return nil
end

-- Puts an asset on a texture. Answers whether it drew.
local function applyArt(texture, key)
  if type(texture) ~= "table" or not (Assets and type(Assets.Apply) == "function") then
    return false
  end
  if type(Assets.Has) == "function" and not Assets.Has(key) then
    return false
  end
  local ok, drew = pcall(Assets.Apply, texture, key)
  return ok and drew ~= false
end

local function tint(texture, colorKey, alpha)
  local r, g, b = themeColor(colorKey)
  if r then
    call(texture, "SetVertexColor", r, g, b, alpha or 1)
  end
end

-- The client's font objects, tried in order where a font string has none.
UIShare.FONT_FALLBACKS = { "GameFontHighlightSmall", "GameFontNormalSmall", "GameFontNormal", "ChatFontNormal" }

local function hasFont(fontString)
  if type(fontString) ~= "table" or type(fontString.GetFont) ~= "function" then
    return false
  end
  local ok, face = pcall(fontString.GetFont, fontString)
  return ok and face ~= nil and face ~= ""
end

local function ensureFont(fontString)
  if hasFont(fontString) then
    return true
  end
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(UIShare.FONT_FALLBACKS) do
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

-- A font string made with a template (pcalled), and a client font object put on it where it still
-- has none, so a SetText never meets a string with no font.
local function newText(parent, template, colorKey)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY", template or "GameFontHighlightSmall")
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY")
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  local r, g, b = themeColor(colorKey or "ITEMTREE_COLOR_TEXT_BODY")
  if r then
    call(fontString, "SetTextColor", r, g, b)
  end
  return fontString
end

local function setText(fontString, text)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  ensureFont(fontString)
  return (pcall(fontString.SetText, fontString, text or ""))
end

local function textWidth(fontString, fallback)
  local width = tonumber(call(fontString, "GetStringWidth"))
  if width and width > 0 then
    return width
  end
  return fallback or 0
end

-- The window's surface: the tooltip art, near black, in a gold edge like the site's panels.
local function applyBackdrop(frame, edgeSize, alpha)
  if type(frame) ~= "table" or type(frame.SetBackdrop) ~= "function" then
    return false
  end
  local inset = math.floor(edgeSize / 4)
  local ok = pcall(frame.SetBackdrop, frame, {
    bgFile = assetPath("TOOLTIP_BACKGROUND"),
    edgeFile = assetPath("TOOLTIP_BORDER"),
    tile = true,
    tileSize = 16,
    edgeSize = edgeSize,
    insets = { left = inset, right = inset, top = inset, bottom = inset },
  })
  if ok then
    call(frame, "SetBackdropColor", 0, 0, 0, alpha)
    local r, g, b = themeColor("ITEMTREE_COLOR_BORDER_GOLD")
    if r then
      call(frame, "SetBackdropBorderColor", r, g, b, 1)
    end
  end
  return ok
end

-- Escape closes the window: our own name appended once to the client's list.
local function registerEscape(name)
  local special = rawget(_G, "UISpecialFrames")
  if type(special) ~= "table" then
    return false
  end
  for _, existing in ipairs(special) do
    if existing == name then
      return true
    end
  end
  special[#special + 1] = name
  return true
end

--- Step 2's words for this client: the Cmd+C wording where IsMacClient answers true, the Ctrl+C
--- wording otherwise (no client, an error or nil).
function UIShare.CopyStepHere()
  local isMac = rawget(_G, "IsMacClient")
  local mac = false
  if type(isMac) == "function" then
    local ok, answer = pcall(isMac)
    if ok and answer == true then
      mac = true
    end
  end
  return UIShare.CopyStep(mac)
end

-- Writes a box's text without the read only guard taking it for the player's typing.
UIShare.filling = false

local function fill(editBox, value)
  UIShare.filling = true
  call(editBox, "SetText", value or "")
  UIShare.filling = false
end

-- The player's own click: the box takes the focus and all of its text is selected.
local function selectAll(editBox)
  call(editBox, "SetFocus")
  call(editBox, "HighlightText")
end

-- A box that holds one text and gives it back however it is typed at: a change is undone at once,
-- and a click or the focus selects all of it. Escape closes the window.
local function readOnly(editBox, current)
  call(editBox, "SetAutoFocus", false)
  call(editBox, "SetScript", "OnTextChanged", function(self)
    if UIShare.filling then
      return
    end
    fill(self, current())
    call(self, "HighlightText")
  end)
  call(editBox, "SetScript", "OnEditFocusGained", function(self)
    call(self, "HighlightText")
  end)
  call(editBox, "SetScript", "OnMouseUp", function(self)
    selectAll(self)
  end)
  call(editBox, "SetScript", "OnEscapePressed", function(self)
    call(self, "ClearFocus")
    UIShare.Hide()
  end)
end

local function button(parent, label, width, onClick)
  local made = newFrame("Button", nil, parent, "UIPanelButtonTemplate")
  if not made then
    return nil
  end
  call(made, "SetSize", width, UIShare.BUTTON_H)
  call(made, "SetText", label)
  call(made, "SetScript", "OnClick", onClick)
  return made
end

local function gameTooltip()
  local tip = rawget(_G, "GameTooltip")
  if type(tip) ~= "table" or type(tip.SetOwner) ~= "function" then
    return nil
  end
  return tip
end

-- A tooltip with a gold heading and body lines under it. Answers whether one showed.
local function showTip(owner, anchor, heading, lines)
  local tip = gameTooltip()
  if not tip then
    return false
  end
  call(tip, "SetOwner", owner, anchor)
  local r, g, b = themeColor("ITEMTREE_COLOR_TEXT_TITLE")
  call(tip, "SetText", heading, r or 1, g or 0.82, b or 0)
  local mr, mg, mb = themeColor("ITEMTREE_COLOR_TEXT_BODY")
  for _, line in ipairs(lines or {}) do
    call(tip, "AddLine", line, mr or 1, mg or 1, mb or 1, true)
  end
  call(tip, "Show")
  return true
end

local function hideTip()
  call(gameTooltip(), "Hide")
end

--- Brief SH3: the box's tooltip, its label and what it does. Answers whether one showed.
function UIShare.ShowCreditTip(owner)
  return showTip(owner, "ANCHOR_TOP", L["Credit my character"], UIShare.CreditTipLines(UIShare.creditState))
end

function UIShare.HideCreditTip()
  hideTip()
end

--- The text box's tooltip: what the text holds (UIShare.BoxTipLines). Answers whether one showed.
function UIShare.ShowBoxTip(owner)
  local lines = UIShare.BoxTipLines(UIShare.summary)
  if not lines then
    return false
  end
  local heading = table.remove(lines, 1)
  return showTip(owner, "ANCHOR_RIGHT", heading, lines)
end

-- Puts every row of the window where UIShare.Layout says, for one part or several, and sizes the
-- window to match. The footer's row is as tall as its wrapped text, so it never runs off the
-- window's bottom edge.
local function arrange(several)
  local frame = UIShare.frame
  if not frame then
    return nil
  end
  local credit = UIShare.CREDIT_BOX == true and UIShare.creditBox ~= nil
  local footerHeight = UIShare.FooterHeight(call(UIShare.footer, "GetStringHeight"))
  local layout = UIShare.Layout(several, credit, footerHeight)
  local top, pad, width = layout.top, UIShare.PAD, UIShare.WIDTH
  local function place(control, point, x, y)
    if control then
      call(control, "ClearAllPoints")
      call(control, "SetPoint", point, frame, point, x, -y)
    end
  end
  local function span(control, y, height)
    if control then
      call(control, "ClearAllPoints")
      call(control, "SetPoint", "TOPLEFT", frame, "TOPLEFT", pad, -y)
      call(control, "SetPoint", "TOPRIGHT", frame, "TOPRIGHT", -pad, -y)
      if height then
        call(control, "SetHeight", height)
      end
    end
  end
  place(UIShare.logo, "TOP", 0, top.logo)
  place(UIShare.title, "TOP", 0, top.title)
  span(UIShare.rule, top.rule, 1)
  span(UIShare.thanks, top.thanks, 30)
  place(UIShare.step1, "TOPLEFT", pad, top.step1)
  -- The input box's own art reaches a few pixels left of its edge.
  place(UIShare.addressBox, "TOPLEFT", pad + 6, top.address)
  call(UIShare.addressBox, "SetSize", width - 2 * pad - 6, UIShare.ADDRESS_H)
  place(UIShare.step2, "TOPLEFT", pad, top.step2)
  span(UIShare.boxFrame, top.box, UIShare.BOX_H)
  if several then
    place(UIShare.nextButton, "TOPRIGHT", -pad, top.parts)
    place(UIShare.partLabel, "TOPLEFT", pad, top.parts + 5)
    place(UIShare.partHint, "TOPLEFT", pad, top.partHint)
  end
  if credit then
    place(UIShare.creditBox, "TOPLEFT", pad - 4, top.credit)
  end
  -- No fixed height on the footer: it keeps its whole wrapped text and the row is made to fit.
  span(UIShare.footer, top.footer)
  call(frame, "SetHeight", layout.height)
  UIShare.layout = layout
  return layout
end

--- Builds the window once. nil outside the client.
function UIShare.Build()
  if UIShare.frame then
    return UIShare.frame
  end
  local frame = newFrame("Frame", UIShare.FRAME_NAME, rawget(_G, "UIParent"), "BackdropTemplate")
  if not frame then
    return nil
  end
  call(frame, "Hide")
  call(frame, "SetWidth", UIShare.WIDTH)
  call(frame, "SetPoint", "CENTER")
  call(frame, "SetFrameStrata", "DIALOG")
  call(frame, "SetToplevel", true)
  call(frame, "EnableMouse", true)
  call(frame, "SetMovable", true)
  call(frame, "SetClampedToScreen", true)
  if type(frame.RegisterForDrag) == "function" then
    call(frame, "RegisterForDrag", "LeftButton")
    call(frame, "SetScript", "OnDragStart", function(self)
      call(self, "StartMoving")
    end)
    call(frame, "SetScript", "OnDragStop", function(self)
      call(self, "StopMovingOrSizing")
    end)
  end
  applyBackdrop(frame, 16, 0.94)
  UIShare.frame = frame

  local logo = call(frame, "CreateTexture", nil, "ARTWORK")
  if type(logo) == "table" then
    call(logo, "SetSize", UIShare.LOGO, UIShare.LOGO)
    if not applyArt(logo, UIShare.LOGO_ART) then
      call(logo, "Hide")
    end
  end
  local title = newText(frame, "GameFontNormalLarge", "ITEMTREE_COLOR_TEXT_TITLE")
  setText(title, L["Help make ItemTree better"])
  local rule = call(frame, "CreateTexture", nil, "ARTWORK")
  if type(rule) == "table" then
    local r, g, b = themeColor("ITEMTREE_COLOR_BORDER_GOLD")
    call(rule, "SetColorTexture", r or 0.79, g or 0.65, b or 0.36, 0.7)
  end
  local thanks = newText(frame, "GameFontHighlight")
  call(thanks, "SetJustifyH", "CENTER")
  call(thanks, "SetJustifyV", "TOP")
  call(thanks, "SetWordWrap", true)

  local close = newFrame("Button", nil, frame, "UIPanelCloseButton")
  if close then
    call(close, "SetPoint", "TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    call(close, "SetScript", "OnClick", function()
      UIShare.Hide()
    end)
  end

  -- Step 1: the site, its address in a one line box selected on click.
  local step1 = newText(frame, "GameFontHighlight")
  setText(step1, L["1. Open itemtree.net in your browser"])
  local addressBox = newFrame("EditBox", nil, frame, "InputBoxTemplate")
  if addressBox then
    readOnly(addressBox, function()
      return UIShare.Address()
    end)
  end

  -- Step 2: the copy key for this client, then the gold edged box; a click in it selects it all.
  local step2 = newText(frame, "GameFontHighlight")
  setText(step2, UIShare.CopyStepHere())
  local boxFrame = newFrame("Frame", nil, frame, "BackdropTemplate")
  applyBackdrop(boxFrame, 12, 0.6)
  local scroll = newFrame("ScrollFrame", UIShare.FRAME_NAME .. "Scroll", frame, "UIPanelScrollFrameTemplate")
  local editBox = scroll and newFrame("EditBox", nil, scroll) or nil
  if scroll and boxFrame then
    call(scroll, "SetPoint", "TOPLEFT", boxFrame, "TOPLEFT", 8, -8)
    call(scroll, "SetPoint", "BOTTOMRIGHT", boxFrame, "BOTTOMRIGHT", -28, 8)
    call(scroll, "SetFrameLevel", (tonumber(call(boxFrame, "GetFrameLevel")) or 1) + 2)
  end
  if editBox then
    call(editBox, "SetMultiLine", true)
    call(editBox, "SetMaxLetters", 0)
    call(editBox, "SetWidth", UIShare.WIDTH - 2 * UIShare.PAD - 40)
    local font = rawget(_G, "ChatFontNormal") or rawget(_G, "GameFontHighlightSmall")
    if font then
      call(editBox, "SetFontObject", font)
    end
    readOnly(editBox, function()
      return UIShare.text or ""
    end)
    call(editBox, "SetScript", "OnEnter", function(self)
      UIShare.ShowBoxTip(self)
    end)
    call(editBox, "SetScript", "OnLeave", function()
      hideTip()
    end)
    call(scroll, "SetScrollChild", editBox)
  end

  -- Brief SH2: the parts row and its line, shown only for a text in several parts.
  local nextButton = button(frame, L["Next"], UIShare.PART_BUTTON_W, function()
    UIShare.ShowPart((UIShare.part or 1) + 1, true)
  end)
  local previousButton = button(frame, L["Previous"], UIShare.PART_BUTTON_W, function()
    UIShare.ShowPart((UIShare.part or 1) - 1, true)
  end)
  if previousButton and nextButton then
    call(previousButton, "SetPoint", "RIGHT", nextButton, "LEFT", -6, 0)
  end
  local partLabel = newText(frame, "GameFontNormal", "ITEMTREE_COLOR_TEXT_TITLE")
  local partHint = newText(frame, "GameFontHighlightSmall", "ITEMTREE_COLOR_TEXT_MUTED")

  -- Brief SH3: the Credit my character row, the box and its words; the rest is in its tooltip.
  local creditBox, creditLabel
  if UIShare.CREDIT_BOX == true then
    creditBox = newFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  end
  if creditBox then
    call(creditBox, "SetSize", UIShare.CHECK_SIZE, UIShare.CHECK_SIZE)
    call(creditBox, "SetScript", "OnClick", function()
      UIShare.SetCredit(not UIShare.CreditOn())
    end)
    call(creditBox, "SetScript", "OnEnter", function(self)
      UIShare.ShowCreditTip(self)
    end)
    call(creditBox, "SetScript", "OnLeave", function()
      UIShare.HideCreditTip()
    end)
    creditLabel = newText(frame, "GameFontHighlightSmall")
    if creditLabel then
      call(creditLabel, "SetPoint", "LEFT", creditBox, "RIGHT", 2, 0)
      setText(creditLabel, L["Credit my character on itemtree.net"])
      -- The words are part of the box: a click on them ticks it and hovering them explains it.
      call(creditBox, "SetHitRectInsets", 0, -(textWidth(creditLabel, 200) + 4), 0, 0)
    end
  end

  local footer = newText(frame, "GameFontHighlightSmall", "ITEMTREE_COLOR_TEXT_MUTED")
  call(footer, "SetJustifyH", "CENTER")
  call(footer, "SetJustifyV", "TOP")
  call(footer, "SetWordWrap", true)
  -- Its width is known before it is anchored, so its measured height is the wrapped one.
  call(footer, "SetWidth", UIShare.WIDTH - 2 * UIShare.PAD)

  registerEscape(UIShare.FRAME_NAME)
  UIShare.logo = logo
  UIShare.title = title
  UIShare.rule = rule
  UIShare.thanks = thanks
  UIShare.step1 = step1
  UIShare.addressBox = addressBox
  UIShare.step2 = step2
  UIShare.boxFrame = boxFrame
  UIShare.scroll = scroll
  UIShare.editBox = editBox
  UIShare.partLabel = partLabel
  UIShare.partHint = partHint
  UIShare.previousButton = previousButton
  UIShare.nextButton = nextButton
  UIShare.creditBox = creditBox
  UIShare.creditLabel = creditLabel
  UIShare.footer = footer
  arrange(false)
  return frame
end

-- The texts (every part), their snapshot's summary and the credit's state, built now. Run under
-- Guard.Run by Open. The developer parts demo stands in for the real text while it is on.
local function buildText()
  if type(UIShare.demoTexts) == "table" then
    return UIShare.demoTexts, nil, UIShare.CreditOn() and "on" or "off"
  end
  local share = core()
  if not (share and type(share.Build) == "function") then
    return nil
  end
  local text, snapshot, _, texts, creditState = share.Build(ItemTree.db)
  if type(text) ~= "string" then
    return nil
  end
  if type(texts) ~= "table" or #texts == 0 then
    texts = { text }
  end
  return texts, share.Summary(snapshot, texts), creditState
end

local function showControl(control, shown)
  call(control, shown and "Show" or "Hide")
end

local function enable(control, enabled)
  call(control, enabled and "Enable" or "Disable")
end

--- Puts part index (clamped to the parts there are) in the box with all of it selected, and sets
--- the parts rows: the label, the buttons and the line under them, hidden for a single part, the
--- window as tall as the rows it shows. focus is true only for the player's own click (Previous,
--- Next): opening the window gives nothing the focus. Answers the part shown.
function UIShare.ShowPart(index, focus)
  local parts = type(UIShare.parts) == "table" and UIShare.parts or { UIShare.text or "" }
  local count = math.max(#parts, 1)
  index = math.max(1, math.min(tonumber(index) or 1, count))
  UIShare.part = index
  UIShare.text = parts[index] or ""
  local label = UIShare.PartLabel(index, count)
  local several = label ~= nil
  setText(UIShare.partLabel, label or "")
  setText(UIShare.partHint, several and L["Copy this part, paste it, then press Next"] or "")
  for _, control in ipairs({ UIShare.partLabel, UIShare.partHint, UIShare.previousButton, UIShare.nextButton }) do
    showControl(control, several)
  end
  enable(UIShare.previousButton, index > 1)
  enable(UIShare.nextButton, index < count)
  arrange(several)
  if UIShare.editBox then
    fill(UIShare.editBox, UIShare.text)
    call(UIShare.editBox, "SetCursorPosition", 0)
    if focus then
      selectAll(UIShare.editBox)
    else
      call(UIShare.editBox, "HighlightText")
    end
  end
  call(UIShare.scroll, "SetVerticalScroll", 0)
  return index
end

-- Brief SH3: the box ticked as the setting says.
local function showCredit()
  call(UIShare.creditBox, "SetChecked", UIShare.CreditOn())
end

-- Shows the window on texts (one per part) with thanks (the line under the title) and footer.
local function present(frame, texts, thanks, footer)
  UIShare.parts = texts
  setText(UIShare.thanks, thanks)
  setText(UIShare.footer, footer)
  local address = UIShare.Address()
  if UIShare.addressBox then
    fill(UIShare.addressBox, address)
    showControl(UIShare.addressBox, address ~= "")
  end
  call(frame, "Show")
  UIShare.ShowPart(1)
end

-- Builds the text afresh under the boundary and shows it, ticking the credit box to match.
local function rebuild(frame, label)
  local db = ItemTree.db
  -- With the row hidden (UIShare.CREDIT_BOX false) nobody can see the tick, so no name goes.
  if UIShare.CREDIT_BOX ~= true and type(db) == "table" and type(db.settings) == "table" then
    if db.settings.shareCredit then
      db.settings.shareCredit = false
    end
  end
  local guard = ItemTree.Guard
  local ok, texts, summary, creditState
  if guard and type(guard.Run) == "function" then
    ok, texts, summary, creditState = guard.Run(label, buildText)
  else
    ok, texts, summary, creditState = pcall(buildText)
  end
  local failed = not ok or type(texts) ~= "table"
  if failed then
    texts, summary, creditState = { "" }, nil, nil
  end
  UIShare.summary = summary
  UIShare.creditState = creditState
  showCredit()
  present(frame, texts, UIShare.Thanks(), UIShare.Footer(creditState, failed))
end

--- Opens the window on a freshly built text with all of it selected and nothing focused: part 1
--- where it comes in parts. Answers whether a window showed.
function UIShare.Open()
  local frame = UIShare.Build()
  if not frame then
    return false
  end
  UIShare.StopPing()
  rebuild(frame, "Share.Open")
  return true
end

--- Brief SH3: whether Credit my character is ticked (settings.shareCredit), and never while the
--- row is hidden.
function UIShare.CreditOn()
  if UIShare.CREDIT_BOX ~= true then
    return false
  end
  local share = core()
  if share and type(share.CreditOn) == "function" then
    return share.CreditOn(ItemTree.db)
  end
  return false
end

--- Brief SH3: ticks or clears Credit my character, saves it, and rebuilds the text (and its parts)
--- at once where the window is up. Answers the setting as saved.
function UIShare.SetCredit(on)
  local db = ItemTree.db
  if type(db) ~= "table" then
    return false
  end
  if type(db.settings) ~= "table" then
    db.settings = {}
  end
  local value = false
  if on and UIShare.CREDIT_BOX == true then
    value = true
  end
  db.settings.shareCredit = value
  local sound = ItemTree.UI and ItemTree.UI.Sound
  if sound and type(sound.Play) == "function" then
    pcall(sound.Play, value and "checkOn" or "checkOff")
  end
  if UIShare.frame and call(UIShare.frame, "IsShown") then
    rebuild(UIShare.frame, "Share.Credit")
  else
    call(UIShare.creditBox, "SetChecked", value)
  end
  return value
end

function UIShare.Hide()
  if UIShare.frame then
    call(UIShare.frame, "Hide")
  end
end

function UIShare.Toggle()
  if UIShare.frame and call(UIShare.frame, "IsShown") then
    UIShare.Hide()
    return false
  end
  return UIShare.Open()
end

--------------------------------------------------------------------------------
-- The link and its ping
--------------------------------------------------------------------------------

-- One ping ring over the medallion: the ring art in gold, additive, invisible at rest, and its
-- animation group growing it and fading it out once. delay staggers the second ring.
local function newPingRing(link, anchor, delay)
  local ring = call(link, "CreateTexture", nil, "OVERLAY")
  if type(ring) ~= "table" or not applyArt(ring, UIShare.RING_ART) then
    return nil
  end
  call(ring, "SetSize", UIShare.LINK_ICON, UIShare.LINK_ICON)
  call(ring, "SetPoint", "CENTER", anchor, "CENTER", 0, 0)
  call(ring, "SetBlendMode", "ADD")
  tint(ring, "ITEMTREE_COLOR_TEXT_TITLE")
  call(ring, "SetAlpha", 0)
  local group = call(ring, "CreateAnimationGroup")
  if type(group) ~= "table" then
    return ring
  end
  local grow = call(group, "CreateAnimation", "Scale")
  if type(grow) == "table" then
    if type(grow.SetScaleTo) == "function" then
      call(grow, "SetScaleFrom", 1, 1)
      call(grow, "SetScaleTo", UIShare.PING_SCALE, UIShare.PING_SCALE)
    else
      call(grow, "SetScale", UIShare.PING_SCALE, UIShare.PING_SCALE)
    end
    call(grow, "SetOrigin", "CENTER", 0, 0)
    call(grow, "SetDuration", UIShare.PING_SECONDS)
    call(grow, "SetStartDelay", delay)
    call(grow, "SetSmoothing", "OUT")
  end
  local fade = call(group, "CreateAnimation", "Alpha")
  if type(fade) == "table" then
    call(fade, "SetFromAlpha", UIShare.PING_ALPHA)
    call(fade, "SetToAlpha", 0)
    call(fade, "SetDuration", UIShare.PING_SECONDS)
    call(fade, "SetStartDelay", delay)
    call(fade, "SetSmoothing", "OUT")
  end
  ring.pingGroup = group
  return ring
end

-- The glow under the words and the medallion: the panel button's highlight in gold, additive,
-- invisible at rest, and its group rising and falling GLOW_PULSES times in order, then nothing.
local function newGlow(link)
  local glow = call(link, "CreateTexture", nil, "BACKGROUND")
  if type(glow) ~= "table" or not applyArt(glow, UIShare.GLOW_ART) then
    return nil
  end
  call(glow, "SetPoint", "TOPLEFT", link, "TOPLEFT", -10, 7)
  call(glow, "SetPoint", "BOTTOMRIGHT", link, "BOTTOMRIGHT", 10, -7)
  call(glow, "SetBlendMode", "ADD")
  tint(glow, "ITEMTREE_COLOR_TEXT_TITLE")
  call(glow, "SetAlpha", 0)
  local group = call(glow, "CreateAnimationGroup")
  if type(group) ~= "table" then
    return glow
  end
  local half = UIShare.GLOW_PULSE_SECONDS / 2
  for pulse = 1, UIShare.GLOW_PULSES do
    local up = call(group, "CreateAnimation", "Alpha")
    if type(up) == "table" then
      call(up, "SetFromAlpha", 0)
      call(up, "SetToAlpha", UIShare.GLOW_HIGH)
      call(up, "SetDuration", half)
      call(up, "SetOrder", pulse * 2 - 1)
      call(up, "SetSmoothing", "IN_OUT")
    end
    local down = call(group, "CreateAnimation", "Alpha")
    if type(down) == "table" then
      call(down, "SetFromAlpha", UIShare.GLOW_HIGH)
      call(down, "SetToAlpha", 0)
      call(down, "SetDuration", half)
      call(down, "SetOrder", pulse * 2)
      call(down, "SetSmoothing", "IN_OUT")
    end
  end
  glow.pingGroup = group
  return glow
end

-- The size the link's words are drawn at: points (the tab words' size, read off the client's font
-- object) less LINK_FONT_STEP, never under LINK_FONT_MIN. Pure.
function UIShare.LinkFontSize(points)
  points = tonumber(points)
  if not points or points <= 0 then
    points = UIShare.LINK_FONT_FALLBACK
  end
  return math.max(UIShare.LINK_FONT_MIN, math.floor(points + 0.5) - UIShare.LINK_FONT_STEP)
end

-- The face, size and flags of a client font object, or nil.
local function fontOf(name)
  local object = rawget(_G, name)
  if type(object) ~= "table" or type(object.GetFont) ~= "function" then
    return nil
  end
  local ok, face, points, flags = pcall(object.GetFont, object)
  if ok and type(face) == "string" and face ~= "" then
    return face, points, flags
  end
  return nil
end

-- Puts face at points on a font string, keeping the font it had where the client will not load it.
local function setFont(fontString, face, points, flags)
  if type(face) ~= "string" or type(fontString) ~= "table" or type(fontString.SetFont) ~= "function" then
    return false
  end
  local ok, applied = pcall(fontString.SetFont, fontString, face, points, flags or "")
  if not ok or applied == false then
    ensureFont(fontString)
    return false
  end
  return true
end

-- The mark's drop shadow: the theme's text shadow, or MARK_SHADOW where the theme has none.
local function markShadow()
  local shadow = Theme and Theme.text and Theme.text.ITEMTREE_TEXT_OUTLINE
  if type(shadow) ~= "table" then
    shadow = UIShare.MARK_SHADOW
  end
  return shadow
end

-- The medallion's "!" as text (brief SH11): the dark brown ink in a plain face (no outline flag)
-- with a 1px drop shadow, centred on the disc with no offset so it lands on a whole pixel.
local function newMark(link, backing)
  local mark = newText(link, "GameFontNormal", UIShare.MARK_COLOR)
  if not mark then
    return nil
  end
  local face = (Theme and Theme.fonts and Theme.fonts.ITEMTREE_FONT_TITLE) or fontOf("GameFontNormal")
  setFont(mark, face, UIShare.MARK_SIZE, UIShare.MARK_FLAGS)
  local r, g, b = themeColor(UIShare.MARK_COLOR)
  call(mark, "SetTextColor", r or 0.17, g or 0.10, b or 0.04, 1)
  local shadow = markShadow()
  call(mark, "SetShadowColor", shadow.r or 0, shadow.g or 0, shadow.b or 0, shadow.a or 0.8)
  call(mark, "SetShadowOffset", shadow.x or 1, shadow.y or -1)
  call(mark, "SetJustifyH", "CENTER")
  call(mark, "SetJustifyV", "MIDDLE")
  call(mark, "SetPoint", "CENTER", backing, "CENTER", 0, 0)
  setText(mark, UIShare.MARK)
  return mark
end

--- The shape style's "!" for a disc `disc` pixels across (brief SH11): whole pixel sizes scaled
--- from MARK_SHAPE_DISC, each at least 1, and the half height of the whole mark, so the bar's top
--- sits `half` above the disc's centre and the dot's bottom `half` below it. Pure. Answers
--- { barW, barH, dot, gap, half }.
function UIShare.MarkShape(disc)
  disc = tonumber(disc)
  if not disc or disc <= 0 then
    disc = UIShare.MARK_SHAPE_DISC
  end
  local scale = disc / UIShare.MARK_SHAPE_DISC
  local function px(value)
    return math.max(1, math.floor(value * scale + 0.5))
  end
  local shape = {
    barW = px(UIShare.MARK_BAR_W),
    barH = px(UIShare.MARK_BAR_H),
    dot = px(UIShare.MARK_DOT),
    gap = px(UIShare.MARK_DOT_GAP),
  }
  -- A whole number, so both ends sit on whole pixels; an odd total keeps the extra pixel below.
  shape.half = math.floor((shape.barH + shape.gap + shape.dot) / 2)
  return shape
end

-- The medallion's "!" as two flat textures in the mark's colour (brief SH11): the bar's top and the
-- dot's bottom anchored a whole number of pixels from the disc's centre, no font.
local function newMarkShape(link, backing)
  local shape = UIShare.MarkShape(UIShare.LINK_ICON)
  local r, g, b = themeColor(UIShare.MARK_COLOR)
  local function piece(width, height, point, y)
    local texture = call(link, "CreateTexture", nil, "OVERLAY")
    if type(texture) ~= "table" then
      return nil
    end
    call(texture, "SetColorTexture", r or 0.17, g or 0.10, b or 0.04, 1)
    call(texture, "SetSize", width, height)
    call(texture, "SetPoint", point, backing, "CENTER", 0, y)
    return texture
  end
  local bar = piece(shape.barW, shape.barH, "TOP", shape.half)
  local dot = piece(shape.dot, shape.dot, "BOTTOM", shape.half - (shape.barH + shape.gap + shape.dot))
  return { bar = bar, dot = dot }
end

-- The round "!" medallion (brief SH8, the owner's picture): a filled gold disc, a flat fill drawn
-- through the round portrait mask, and a dark brown "!" centred on it (text or shape, MARK_STYLE). No ring.
local function newMedallion(link)
  local size = UIShare.LINK_ICON
  local backing = call(link, "CreateTexture", nil, "ARTWORK")
  if type(backing) ~= "table" then
    return nil
  end
  call(backing, "SetSize", size, size)
  call(backing, "SetPoint", "LEFT", link, "LEFT", 0, 0)
  local r, g, b = themeColor(UIShare.DISC_COLOR)
  local disc = { r or 1, g or 0.82, b or 0 }
  call(backing, "SetColorTexture", disc[1], disc[2], disc[3], 1)
  local maskPath = assetPath(UIShare.MASK_ART)
  local mask = maskPath and call(link, "CreateMaskTexture") or nil
  if type(mask) == "table" then
    local wrap = "CLAMPTOBLACKADDITIVE"
    if call(mask, "SetTexture", maskPath, wrap, wrap) ~= false then
      call(mask, "SetAllPoints", backing)
      call(backing, "AddMaskTexture", mask)
    end
  end
  if UIShare.MARK_STYLE == "shape" then
    return { backing = backing, disc = disc, mask = mask, shape = newMarkShape(link, backing) }
  end
  local mark = newMark(link, backing)
  return { backing = backing, disc = disc, mask = mask, mark = mark }
end

local function paintLabel(hover)
  local key = hover and "ITEMTREE_COLOR_TEXT_BODY" or "ITEMTREE_COLOR_TEXT_TITLE"
  local r, g, b = themeColor(key)
  if r then
    call(UIShare.linkLabel, "SetTextColor", r, g, b)
  end
end

local function pingParts()
  local link = UIShare.link
  if type(link) ~= "table" then
    return {}
  end
  local parts = {}
  for _, part in ipairs({
    link.shareGlow,
    link.sharePings and link.sharePings[1],
    link.sharePings and link.sharePings[2],
  }) do
    if type(part) == "table" then
      parts[#parts + 1] = part
    end
  end
  return parts
end

--- Plays the ping once on the link: the two rings and the glow. Answers whether it started.
function UIShare.StartPing()
  local parts = pingParts()
  if #parts == 0 then
    return false
  end
  UIShare.pinging = true
  UIShare.pingLeft = 0
  for _, part in ipairs(parts) do
    if type(part.pingGroup) == "table" then
      call(part.pingGroup, "Stop")
      call(part.pingGroup, "Play")
      UIShare.pingLeft = UIShare.pingLeft + 1
    end
  end
  UIShare.pinged = (UIShare.pinged or 0) + 1
  return true
end

--- Ends the ping at once and leaves nothing showing. Answers true.
function UIShare.StopPing()
  UIShare.pinging = false
  UIShare.pingLeft = 0
  for _, part in ipairs(pingParts()) do
    call(part.pingGroup, "Stop")
    call(part, "SetAlpha", 0)
  end
  return true
end

-- One of the ping's groups finished; the last one done ends the ping.
local function pingFinished()
  UIShare.pingLeft = math.max(0, (UIShare.pingLeft or 0) - 1)
  if UIShare.pingLeft == 0 and UIShare.pinging then
    UIShare.StopPing()
  end
end

--------------------------------------------------------------------------------
-- The thank you note (brief TY1)
--------------------------------------------------------------------------------

-- A theme colour, or the fallback where the theme has none.
local function noticeColor(key, fallback)
  local r, g, b = themeColor(key)
  if r then
    return r, g, b
  end
  return fallback[1], fallback[2], fallback[3]
end

-- One flat piece of the note on frame: the plain white fill in a theme colour, or the colour as a
-- flat block where the client will not draw the fill, which is the same thing.
local function noticePiece(frame, layer, subLevel, colorKey, fallback)
  local texture = call(frame, "CreateTexture", nil, layer, nil, subLevel)
  if type(texture) ~= "table" then
    return nil
  end
  local r, g, b = noticeColor(colorKey, fallback)
  if applyArt(texture, UIShare.NOTICE_FILL_ART) then
    call(texture, "SetVertexColor", r, g, b, 1)
  else
    call(texture, "SetColorTexture", r, g, b, 1)
  end
  return texture
end

-- Turns a square piece 45 degrees into a diamond. Answers whether the client turned it.
local function turn(piece)
  if type(piece) ~= "table" or type(piece.SetRotation) ~= "function" then
    return false
  end
  return (pcall(piece.SetRotation, piece, math.pi / 4))
end

local NOTICE_SURFACE_FALLBACK = { 0.04, 0.04, 0.08 }
local NOTICE_EDGE_FALLBACK = { 0.79, 0.65, 0.36 }

-- Brief TY2: one screen pixel in the note's units (Core/Util.lua Util.ScreenPixel), nil where the
-- client will not say.
local function noticePixel(frame)
  local util = ItemTree.Util
  if type(util) ~= "table" or type(util.ScreenPixel) ~= "function" then
    return nil
  end
  local ok, pixel = pcall(util.ScreenPixel, frame)
  if ok then
    return pixel
  end
  return nil
end

-- Brief TY2: how far the link's left edge sits in from the main window's left edge, the window's
-- own anchor for it (UI/Frame.lua Frame.ShareLinkSpot), nil without the window's file.
local function noticeLinkLeft()
  local frameApi = ItemTree.UI and ItemTree.UI.Frame
  if type(frameApi) ~= "table" or type(frameApi.ShareLinkSpot) ~= "function" then
    return nil
  end
  local ok, x = pcall(frameApi.ShareLinkSpot)
  if ok then
    return tonumber(x)
  end
  return nil
end

-- Brief TY2: places the note centred under the link (UIShare.NoticePlace) with its notch under the
-- middle of the link, and sizes its edge and its notch in whole screen pixels (UIShare.NoticeNotch)
-- for the scale it shows at. The top edge runs to the notch's mouth from either side. link is the
-- Share link (UIShare.link where not given).
local function placeNotice(frame, link)
  local sides = UIShare.NoticeNotch(noticePixel(frame))
  link = link or UIShare.link
  local parent = UIShare.noticeParent
  local x, notchX = UIShare.NoticePlace(noticeLinkLeft(), call(link, "GetWidth"), call(parent, "GetWidth"))
  local tip = math.floor(notchX / sides.pixel + 0.5) * sides.pixel
  call(frame, "ClearAllPoints")
  call(frame, "SetPoint", "TOPLEFT", link or parent, "BOTTOMLEFT", x, -(sides.gap + sides.rise))
  local notch = UIShare.noticeNotch or {}
  for _, pair in ipairs({ { notch.outer or false, sides.outer }, { notch.inner or false, sides.inner } }) do
    local piece = pair[1]
    if piece then
      call(piece, "SetSize", pair[2], pair[2])
      call(piece, "ClearAllPoints")
      call(piece, "SetPoint", "CENTER", frame, "TOPLEFT", tip, 0)
    end
  end
  local edges = UIShare.noticeEdges or {}
  local width = UIShare.NOTICE_WIDTH
  local leftTop, rightTop = width, 0
  if notch.turned then
    leftTop = tip - sides.mouth
    rightTop = width - tip - sides.mouth
  end
  call(edges[1], "SetSize", leftTop, sides.edge)
  call(edges[2], "SetSize", rightTop, sides.edge)
  if rightTop > 0 then
    call(edges[2], "Show")
  else
    call(edges[2], "Hide")
  end
  call(edges[3], "SetHeight", sides.edge)
  call(edges[4], "SetWidth", sides.edge)
  call(edges[5], "SetWidth", sides.edge)
  UIShare.noticeX = tip
  UIShare.noticeLeft = x
  UIShare.noticeSides = sides
end

-- Brief TY1: the note, built once with the link and hidden: at login behind the loading screen,
-- since the link is built with the main window (UI/Frame.lua Frame.BuildAtLogin), never lazily
-- under an open client panel. It is made on parent, the main window (one of our own frames, on
-- UIParent), so it scales, stacks and hides with the window and touches no client frame; it draws
-- NOTICE_LEVEL levels over it. It hangs under link with its notch pointing up at it. The surface is
-- opaque, so the gold square under it shows only where it stands above the note.
local function buildNotice(parent, link)
  local frame = newFrame("Frame", nil, parent)
  if not frame then
    return nil
  end
  call(frame, "Hide")
  call(frame, "SetWidth", UIShare.NOTICE_WIDTH)
  call(frame, "SetHeight", UIShare.NoticeHeight(nil))
  -- It takes the mouse, so a click on it never reaches the tab or the pane under it.
  call(frame, "EnableMouse", true)
  local surface, edgeColor = UIShare.NOTICE_SURFACE, UIShare.NOTICE_EDGE_COLOR
  local body = noticePiece(frame, "BACKGROUND", 0, surface, NOTICE_SURFACE_FALLBACK)
  call(body, "SetAllPoints", frame)
  -- The gold edge: the top in two pieces, left and right of the notch (brief TY2: the edge stops at
  -- the notch rather than being painted over, so no sliver of it can show across the notch's mouth),
  -- then the bottom, the left and the right. placeNotice sizes them in whole screen pixels.
  local edges = {}
  for index, spot in ipairs({
    { "TOPLEFT" },
    { "TOPRIGHT" },
    { "BOTTOMLEFT", "BOTTOMRIGHT" },
    { "TOPLEFT", "BOTTOMLEFT" },
    { "TOPRIGHT", "BOTTOMRIGHT" },
  }) do
    local line = noticePiece(frame, "BORDER", 0, edgeColor, NOTICE_EDGE_FALLBACK)
    if line then
      for _, point in ipairs(spot) do
        call(line, "SetPoint", point, frame, point, 0, 0)
      end
    end
    edges[index] = line
  end
  -- The notch: the gold square under the surface, the surface's own over it. Where the client will
  -- not turn a texture the note has no notch rather than two squares, and its top edge is whole.
  local outer = noticePiece(frame, "BACKGROUND", -1, edgeColor, NOTICE_EDGE_FALLBACK)
  local inner = noticePiece(frame, "BACKGROUND", 1, surface, NOTICE_SURFACE_FALLBACK)
  local turned = turn(outer) and turn(inner)
  if not turned then
    call(outer, "Hide")
    call(inner, "Hide")
  end
  -- Brief TY2: the heading row, ItemTree's mark then "Thanks for your support" in the title gold.
  local inset = UIShare.NOTICE_PAD
  local headY = -(UIShare.NOTICE_TOP_PAD + UIShare.NOTICE_ICON / 2)
  local icon = call(frame, "CreateTexture", nil, "ARTWORK")
  if type(icon) == "table" then
    call(icon, "SetSize", UIShare.NOTICE_ICON, UIShare.NOTICE_ICON)
    call(icon, "SetPoint", "LEFT", frame, "TOPLEFT", inset, headY)
    if applyArt(icon, UIShare.LOGO_ART) then
      inset = inset + UIShare.NOTICE_ICON + UIShare.NOTICE_ICON_GAP
    else
      call(icon, "Hide")
    end
  end
  local heading = newText(frame, UIShare.NOTICE_HEAD_FONT, "ITEMTREE_COLOR_TEXT_TITLE")
  call(heading, "SetJustifyH", "LEFT")
  call(heading, "SetWordWrap", false)
  call(heading, "SetWidth", UIShare.NOTICE_WIDTH - inset - UIShare.NOTICE_CLOSE_ROOM)
  call(heading, "SetPoint", "LEFT", frame, "TOPLEFT", inset, headY)
  setText(heading, UIShare.NoticeHeading())
  -- The words under it, the note's whole width, in the smaller body font with room between lines.
  local words = newText(frame, UIShare.NOTICE_FONT, "ITEMTREE_COLOR_TEXT_BODY")
  call(words, "SetJustifyH", "LEFT")
  call(words, "SetJustifyV", "TOP")
  call(words, "SetWordWrap", true)
  call(words, "SetSpacing", UIShare.NOTICE_SPACING)
  -- Its width is known before it is written, so its measured height is the wrapped one.
  call(words, "SetWidth", UIShare.NOTICE_WIDTH - 2 * UIShare.NOTICE_PAD)
  local wordsY = UIShare.NOTICE_TOP_PAD + UIShare.NOTICE_ICON + UIShare.NOTICE_HEAD_GAP
  call(words, "SetPoint", "TOPLEFT", frame, "TOPLEFT", UIShare.NOTICE_PAD, -wordsY)
  -- The client's red X, right, centred on the heading row; its click closes the note for good.
  local close = newFrame("Button", nil, frame, "UIPanelCloseButton")
  if close then
    call(close, "SetSize", UIShare.NOTICE_CLOSE, UIShare.NOTICE_CLOSE)
    call(close, "SetPoint", "RIGHT", frame, "TOPRIGHT", -UIShare.NOTICE_CLOSE_INSET, headY)
    call(close, "SetScript", "OnClick", function()
      UIShare.CloseNotice()
    end)
  end
  UIShare.notice = frame
  UIShare.noticeParent = parent
  UIShare.noticeFill = body
  UIShare.noticeEdges = edges
  UIShare.noticeNotch = { outer = outer, inner = inner, turned = turned }
  UIShare.noticeIcon = icon
  UIShare.noticeHeading = heading
  UIShare.noticeText = words
  UIShare.noticeClose = close
  UIShare.noticeShowing = nil
  placeNotice(frame, link)
  return frame
end

--- Brief TY1: shows the note under the link: its words, its height fitted to them, NOTICE_LEVEL
--- levels over the main window, and its notch under the middle of the link. Brief TY2: centred under
--- the link (placeNotice). id is the message it shows, the one a close remembers. Answers whether it
--- showed.
function UIShare.ShowNotice(id)
  local frame = UIShare.notice
  if type(frame) ~= "table" then
    return false
  end
  local words = UIShare.noticeText
  setText(words, UIShare.NoticeText())
  call(frame, "SetHeight", UIShare.NoticeHeight(call(words, "GetStringHeight")))
  local level = tonumber(call(UIShare.noticeParent, "GetFrameLevel"))
  if level then
    call(frame, "SetFrameLevel", level + UIShare.NOTICE_LEVEL)
  end
  placeNotice(frame)
  UIShare.noticeShowing = id or true
  call(frame, "Show")
  return true
end

--- Brief TY1: the note's red X, or a click on the link while the note shows: the note goes, and its
--- id is remembered as closed for the whole account (Core/Share.lua Share.CloseNotice), so it never
--- shows again. The developer demo remembers nothing. Answers whether a note was closed.
function UIShare.CloseNotice()
  local showing = UIShare.noticeShowing
  if not showing then
    return false
  end
  UIShare.noticeShowing = nil
  call(UIShare.notice, "Hide")
  if UIShare.noticeDemo then
    UIShare.noticeDemo = nil
    return true
  end
  local share = core()
  if type(showing) == "string" and share and type(share.CloseNotice) == "function" then
    share.CloseNotice(ItemTree.db, showing)
  end
  return true
end

--- Brief TY1: the main window's first open this session decides the note: updated is that open's
--- update check (Share.PulseDue, never forced). It shows while its id is due and not closed
--- (Share.NoticeDue), or for the developer demo. A note left open goes and comes back with the
--- window, being one of its children. Answers whether it showed.
function UIShare.CheckNotice(updated)
  local share = core()
  local id = UIShare.NOTICE_ID
  local due = false
  if share and type(share.NoticeDue) == "function" then
    due = share.NoticeDue(ItemTree.db, id, updated) == true
  end
  if due or UIShare.noticeDemo then
    return UIShare.ShowNotice(id)
  end
  return false
end

--- The main window came up. The first time this session, decides the ping (Share.PulseDue) and
--- notes the version seen, so it plays once per update. Brief TY1: and the thank you note, from the
--- same check unforced, before the version is noted.
function UIShare.OnMainShown()
  if UIShare.checked then
    return false
  end
  UIShare.checked = true
  local share = core()
  if not (share and type(share.PulseDue) == "function") then
    return false
  end
  local db = ItemTree.db
  local savedState = ItemTree.state and ItemTree.state.savedDb or nil
  local address = UIShare.Address()
  local due = share.PulseDue(db, ItemTree.version, savedState, address, UIShare.forcePulse)
  local updated = share.PulseDue(db, ItemTree.version, savedState, address, nil)
  share.NoteVersion(db, ItemTree.version)
  UIShare.CheckNotice(updated)
  if due then
    return UIShare.StartPing()
  end
  return false
end

--- The main window went down: the ping ends and does not come back this session.
function UIShare.OnMainHidden()
  if UIShare.pinging then
    UIShare.StopPing()
  end
  UIShare.forcePulse = nil
end

local function hook(frame, script, handler)
  if type(frame) ~= "table" or type(frame.HookScript) ~= "function" then
    return false
  end
  if type(frame.HasScript) == "function" then
    local ok, has = pcall(frame.HasScript, frame, script)
    if not ok or not has then
      return false
    end
  end
  return (pcall(frame.HookScript, frame, script, handler))
end

--- The link on parent (one of the main window's own frames): the medallion, the words, the glow
--- and the two ping rings. window is the main window, whose show and hide it hooks for the ping.
--- The caller anchors it. Answers the link, shown, or nil. Brief TY1: the thank you note is built
--- here too, hidden, on the window (on parent where there is none), hanging under the link.
function UIShare.BuildLink(parent, window)
  local link = newFrame("Button", nil, parent)
  if not link then
    return nil
  end
  call(link, "SetHeight", UIShare.LINK_H)
  link.shareGlow = newGlow(link)
  local medallion = newMedallion(link)
  local label = newText(link, UIShare.LINK_FONT_OBJECT, "ITEMTREE_COLOR_TEXT_TITLE")
  if label then
    -- Brief SH8: one point under the tab words, which are drawn in this same font object.
    local face, points, flags = fontOf(UIShare.LINK_FONT_OBJECT)
    if not face and type(label.GetFont) == "function" then
      local ok
      ok, face, points, flags = pcall(label.GetFont, label)
      if not ok then
        face = nil
      end
    end
    setFont(label, face, UIShare.LinkFontSize(points), flags)
    call(label, "SetPoint", "LEFT", link, "LEFT", UIShare.LINK_ICON + UIShare.LINK_GAP, 0)
    call(label, "SetJustifyH", "LEFT")
    setText(label, L["Help make ItemTree better"])
  end
  local anchor = medallion and medallion.backing or link
  link.sharePings = {}
  for index, delay in ipairs({ 0, UIShare.PING_STAGGER }) do
    link.sharePings[index] = newPingRing(link, anchor, delay)
  end
  local labelW = textWidth(label, 160)
  call(link, "SetWidth", UIShare.LINK_ICON + UIShare.LINK_GAP + labelW)
  UIShare.link = link
  UIShare.linkLabel = label
  UIShare.linkMedallion = medallion
  for _, part in ipairs(pingParts()) do
    call(part.pingGroup, "SetScript", "OnFinished", pingFinished)
  end
  -- Brief TY1 (the owner, 2026-10-18): a click on the link closes the thank you note for good too.
  call(link, "SetScript", "OnClick", function()
    UIShare.StopPing()
    UIShare.CloseNotice()
    UIShare.Toggle()
  end)
  call(link, "SetScript", "OnEnter", function()
    paintLabel(true)
  end)
  call(link, "SetScript", "OnLeave", function()
    paintLabel(false)
  end)
  UIShare.shownHooked = hook(window, "OnShow", function()
    UIShare.OnMainShown()
  end)
  hook(window, "OnHide", function()
    UIShare.OnMainHidden()
  end)
  buildNotice(window or parent, link)
  call(link, "Show")
  return link
end


return UIShare
