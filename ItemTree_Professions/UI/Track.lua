-- Brief TP1 (the owner's QA item 210, Tom's feedback via Chris, 2026-10-17): track another
-- profession per character, on the Professions tab's profession list (UI\Pane.lua's strip).
--
-- The owner's words: "Even though we show the users professions by default we should allow a user to
-- add a profession to their list (permanent filter addition per character)". The list, top to bottom:
--   The player's own professions, as the strip always drew them (UI\Pane.lua drawStrip). They have no
--                 remove button: "cant remove their real professions from the list".
--   The tracked   each profession the character tracks, in the order added, drawn "similar to an
--                 existing profession" (its glyph and name, selected and hovered the same way)
--                 "except the right hand side has a standard red button with an 'X' icon" that
--                 takes it off the list (brief LF1: the craft queue's own red close button, its X
--                 yellow). "Below that profession and indented slightly" a dropdown: "No level
--                 tracking" ("Not tracking items") or a range of its route (the bands
--                 ItemTree_Professions' ProfessionTracks ships for it).
--   The button    "an empty state button below the last profession": a gold dotted border, a "+" and
--                 "Track another profession", centred. It drops down the professions the character
--                 does not have and does not track yet; a pick adds one (at None) and selects it.
--
-- Brief LF1 (the owner's QA item 240, 2026-10-18, look and feel): the bar's tag reads "Enchanting
-- (tracking 20 to 70)" or "Enchanting (not tracking)", a qualifier in brackets, never after a comma;
-- the red X is the craft queue's close art, yellow at rest and under the pointer; the add button's
-- dotted border is thinner with rounded corners over a faint, lighter, translucent fill; the range
-- dropdown is darker; its empty choice says "No level tracking"; and a row and its dropdown stand
-- as far apart as the add button stands from the row above it.
--
-- Brief LF2 (the owner's QA item 264, 2026-10-18 night: "Lets try a version of these UI elements
-- where the dropbox in inline between the profession name and X button (fill the gap with a bit of
-- margin between) and the boxes text gets ... if the text gets cut off"): the dropdown moved onto the
-- tracked row's own line, between the name and the X (Track.InlineLayout), its words and a name too
-- long for the room cut with "..." (Track.Ellipsis); a tracked row is one line now, BLOCK_GAP under
-- the one before. The open list, the words, the hovers, the X and the dark field are as they were.
-- A tracked profession is browsed like a real one: the pane draws its route and recipes at the
-- range's bottom (none: from the start) and its bar's tag says what it tracks, never a rank the
-- character holds (Track.Tag). Its Trainers & vendors panel and Show nearest see the character's
-- own skill, which is none (Track.TrainersView), and it has no Craft all.
--
-- The store and what tracking keeps: Core/TrackedProfessions.lua. Each change goes through it
-- (Tracked.Add, Tracked.Remove, Tracked.SetRange: Keep, the route and the API are told there) and
-- the pane draws again.
--
-- The dropdown lists are this file's own frames, never UIDropDownMenu (it is global, shared with the
-- client's menus and taints easily), built the way UI/Map.lua builds its zone list: a row picks on the
-- PRESS (brief E29: a row waiting for the release raced every closer and lost), a press anywhere
-- outside the list closes it (GLOBAL_MOUSE_DOWN, asking first whether the pointer is over the list
-- or the control it drops from, as the client's own MenuManagerMixin:ContainsCursor does,
-- Blizzard_Menu/Menu.lua on the forever branch), and the list is raised over everything on every
-- open. Escape is not taken: the list takes no keyboard at all, so it never swallows a key (and never
-- asks for the keyboard in combat, bible E91 in UI/Map.lua). Every frame here is ours, on the pane's
-- own strip or root (no Blizzard frame parenting).
--
-- Everything above the "Client side" divider is pure and runs under busted with no WoW API.
local _, ItemTree = ...
-- ItemTree_Professions is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Modules) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end

local Track = {}
ItemTree.ProfessionsTrack = Track

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

local Kit = ItemTree.ProfessionsKit
local SIZES = Kit.ThemeSizes()

-- Sizes, from the Theme tokens where one exists. ROW_H, ICON and GUTTER are the strip's own
-- (UI\Pane.lua ROW_H, ROW_ICON, GUTTER), so a tracked row lines up with the rows above it.
Track.ROW_H = SIZES.ITEMTREE_LIST_ROW_H or 22
Track.ICON = SIZES.ITEMTREE_ICON_CATEGORY or 16
Track.GUTTER = SIZES.ITEMTREE_LIST_GUTTER or 6
Track.PAD = SIZES.ITEMTREE_SPACE_1 or 4
-- The range dropdown: a small control's height. Brief LF2 (the owner's QA item 264, 2026-10-18: "Lets
-- try a version of these UI elements where the dropbox in inline between the profession name and X
-- button (fill the gap with a bit of margin between) and the boxes text gets ... if the text gets
-- cut off"): it sits on the tracked row's own line, centred in it, between the name and the red X,
-- FIELD_GAP px from each (the strip's small space, the gap the add button's "+" keeps from its
-- words), never narrower than FIELD_MIN. The name is cut to leave it that, and FIELD_MIN (a knob) is
-- set so the name keeps its words and the box's are the ones cut, as the owner put it: in the 180 px
-- strip the room left for a name is 80 px, about what the longest, Leatherworking, takes at the
-- client's 12 px font, and a dropdown keeps room for "No..." at least. Inside it the words start
-- FIELD_PAD px in and stop short of a FIELD_CHEVRON px chevron FIELD_PAD / 2 px from its right edge,
-- cut with ELLIPSIS where they do not fit (Track.Ellipsis); CHAR_W is the width a character is taken
-- to be where the client will not measure. LF1 drew it on a line of its own, indented to the name
-- (INDENT).
Track.RANGE_H = SIZES.ITEMTREE_CONTROL_H_SM or 20
Track.INDENT = Track.GUTTER * 2 + Track.ICON
Track.FIELD_GAP = Track.PAD
Track.FIELD_MIN = 44
Track.FIELD_PAD = Track.PAD
Track.FIELD_CHEVRON = 12
Track.ELLIPSIS = "..."
Track.CHAR_W = 6
-- The red X button's side. Brief LF1 (QA item 240b): the craft queue's close art at the tray's own
-- close size (UI\Queue.lua Queue.CLOSE), whose round button sits REMOVE_ART_INSET px inside its
-- square (Queue.REMOVE_ART_INSET, 6 of 30, at this size), so the button stands that much further
-- right to keep the ring GUTTER px from the row's edge; under the pointer the art is laid over
-- itself additively at REMOVE_LIT.
Track.REMOVE = 22
Track.REMOVE_ART_INSET = 4
Track.REMOVE_LIT = 0.4
-- The gap after the player's own rows. Brief LF1 (QA item 240g, the owner: "We need a little space
-- between the skill and tracking dropdown similar to the 'Track another...' and the profession above
-- it"): the add button stands ADD_GAP (two GAPs) under the row above it. Brief LF2 (QA item 264):
-- with the dropdown on the row's own line there is no gap under a row for it; one tracked row stands
-- BLOCK_GAP (one GAP, so their fields never touch) under the one before, and the add button keeps
-- its ADD_GAP under the last.
Track.GAP = 4
Track.ADD_GAP = Track.GAP * 2
Track.BLOCK_GAP = Track.GAP
-- The add button, and its gold dotted border: DOT px dots every DOT + DOT_GAP px. Brief LF1 (QA
-- item 240d, the owner: "The dotted yellow line is too thick and has no bevels. Add a slightly
-- lighter bg to that area (transluscent"): 1 px dots (PR TP1's were 2) round corners of ADD_RADIUS
-- px, over a rounded fill in ADD_FILL, a faint gold wash.
Track.ADD_H = 24
Track.DOT = 1
Track.DOT_GAP = 2
Track.ADD_RADIUS = 4
Track.PLUS = 12
-- The lists.
Track.MENU_ROW_H = SIZES.ITEMTREE_LIST_ROW_H or 22
Track.MENU_MAX_ROWS = 12
Track.MENU_W = 168
Track.MENU_SCROLLER_W = 4
Track.MENU_STRATA = "FULLSCREEN_DIALOG"
-- How far over everything the list is raised, the step the client's own menus take
-- (Blizzard_Menu/Menu.lua MenuManagerMixin:OpenMenu, forever branch), as UI/Map.lua takes it.
Track.MENU_LEVEL_STEP = 500
Track.FONT_MD = 12
Track.FONT_SM = 11
Track.FONT_TEMPLATE = "GameFontNormalSmall"
Track.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }

-- Theme colour keys (the strip's own where the strip has one) and Assets keys.
Track.SELECTED = "ITEMTREE_LIST_STATE_SELECTED"
Track.HOVER = "ITEMTREE_COLOR_STATE_HOVER"
Track.NAME_WORD = "ITEMTREE_COLOR_TEXT_BODY"
Track.SELECTED_WORD = "ITEMTREE_COLOR_TEXT_SELECTED"
Track.MUTED_WORD = "ITEMTREE_COLOR_TEXT_MUTED"
Track.TITLE_WORD = "ITEMTREE_COLOR_TEXT_TITLE"
Track.GOLD = "ITEMTREE_COLOR_BORDER_GOLD"
Track.FACE = "ITEMTREE_COLOR_BUTTON_FACE"
Track.FACE_HOVER = "ITEMTREE_COLOR_BUTTON_FACE_HOVER"
Track.EDGE = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
Track.MENU_FILL = "ITEMTREE_COLOR_SURFACE_STICKY"
-- Brief LF1 (QA item 240e, the owner: "Make the tracking dorpdown fields darker bg rather than the
-- lighter brown bg"): the dropdown's face is its open list's own dark fill, not the button brown.
Track.FIELD_FILL = Track.MENU_FILL
Track.ADD_FILL = "ITEMTREE_COLOR_PROFESSION_ADD_FILL"
Track.TRACK_COLOUR = "ITEMTREE_COLOR_BORDER_DIVIDER"
Track.PLUS_KEY = "PLUS"
Track.REMOVE_KEY = "BUTTON_CLOSE"
Track.CHEVRON_KEY = "ICON_CHEVRON_COLLAPSE"
Track.TICK_KEY = "ICON_CHECK"

Track.WORDS = {
  add = L["Track another profession"],
  addHint = L["Add a profession you do not have. Pick a range under it and ItemTree keeps its items as if you had it."],
  -- Brief LF1 (QA item 240f, the owner: "Instead of a tracking option being just 'None' it should be
  -- 'No level tracking' (to give the hint what the dropdown does"): the field's and the list's words.
  none = L["No level tracking"],
  -- The owner's words for None.
  noneTip = L["Not tracking items"],
  range = L["%d to %d"],
  -- The owner's option A (2026-10-17): the range alone.
  rangeTip = L["Keeps the items %s needs from %d to %d, as if you had it"],
  remove = L["Stop tracking %s"],
  rowTip = L["Tracked: you do not have %s"],
  -- Brief LF1 (QA item 240a, the owner: "[Profession] (tracking X to Y) or [Profession] (not
  -- tracking)"): the qualifier in brackets, never after a comma.
  tagRange = L["%s (tracking %d to %d)"],
  tagNone = L["%s (not tracking)"],
  profession = L["Profession"],
}

--------------------------------------------------------------------------------
-- Pure
--------------------------------------------------------------------------------

--- "55 to 80" for a range, Track.WORDS.none ("No level tracking") for none. Pure.
function Track.RangeText(lo, hi)
  lo, hi = tonumber(lo), tonumber(hi)
  if lo == nil or hi == nil then
    return Track.WORDS.none
  end
  return string.format(Track.WORDS.range, lo, hi)
end

--- The bar tag's words for a tracked profession: "Tailoring (tracking 55 to 80)", or "Tailoring (not
--- tracking)" for none (brief LF1; TP1's were "Tailoring, tracking 55 to 80" and "Tailoring, not
--- tracking items"). Never "55/75": the character holds no rank in it. Pure.
function Track.Tag(name, lo, hi)
  name = tostring(name or Track.WORDS.profession)
  lo, hi = tonumber(lo), tonumber(hi)
  if lo == nil or hi == nil then
    return string.format(Track.WORDS.tagNone, name)
  end
  return string.format(Track.WORDS.tagRange, name, lo, hi)
end

-- Whether skills (the pane's facts, Frame.PlayerSkills with the tracked joined) hold a line as the
-- character's own: an entry that is not marked tracked. Pure.
local function heldOwn(skills, line)
  local skill = type(skills) == "table" and skills[line] or nil
  return type(skill) == "table" and skill.tracked ~= true
end

-- A line's route data in tracks (the ProfessionTracks table), or nil. Pure.
local function lineData(tracks, line)
  local lines = type(tracks) == "table" and type(tracks.lines) == "table" and tracks.lines or EMPTY
  local data = lines[line]
  return type(data) == "table" and data or nil
end

--- The tracked rows the strip draws under the player's own, in the order they were added: one per
--- entry of list (Tracked.List's { { line, lo, hi } }) the character does not hold for real
--- (skills, the pane's facts). Each row is the strip's own shape (UI\Pane.lua StripRows: line,
--- name, rank, max, hasRoute, trainable) with tracked = true, lo and hi (nil for none) and tag (the
--- bar's words); rank is the range's bottom, 0 for none (browsed from the start), max nil and
--- trainable false (no rank of the character's, so no cap and no gem). nameOf(line) the line's name.
--- Pure.
function Track.Rows(tracks, list, skills, nameOf)
  local rows = {}
  for _, entry in ipairs(type(list) == "table" and list or EMPTY) do
    local line = type(entry) == "table" and tonumber(entry.line) or nil
    if line and not heldOwn(skills, line) then
      local data = lineData(tracks, line)
      local bands = data and type(data.bands) == "table" and data.bands or EMPTY
      local name = type(nameOf) == "function" and nameOf(line) or nil
      if type(name) ~= "string" or name == "" then
        name = Track.WORDS.profession .. " " .. line
      end
      local lo, hi = tonumber(entry.lo), tonumber(entry.hi)
      if lo == nil or hi == nil then
        lo, hi = nil, nil
      end
      rows[#rows + 1] = {
        line = line,
        name = name,
        rank = lo or 0,
        max = nil,
        hasRoute = #bands > 0,
        trainable = false,
        tracked = true,
        lo = lo,
        hi = hi,
        tag = Track.Tag(name, lo, hi),
      }
    end
  end
  return rows
end

--- The strip's rows in one list: the player's own (rows), then the tracked. Pure: a new list.
function Track.JoinRows(rows, tracked)
  local out = {}
  for _, list in ipairs({ rows, tracked }) do
    for _, row in ipairs(type(list) == "table" and list or EMPTY) do
      out[#out + 1] = row
    end
  end
  return out
end

--- The range list of one tracked line: None first ("No level tracking", "Not tracking items" its
--- hover), then every band
--- of its route in order, "1 to 30", "30 to 55". Each { text, lo, hi, none, tip, current }, current
--- the one the line tracks now (lo, hi; nil for none). Pure.
function Track.RangeEntries(tracks, line, lo, hi)
  lo, hi = tonumber(lo), tonumber(hi)
  local entries = {
    { text = Track.WORDS.none, none = true, tip = Track.WORDS.noneTip, current = lo == nil or hi == nil },
  }
  local data = lineData(tracks, tonumber(line))
  for _, band in ipairs(data and type(data.bands) == "table" and data.bands or EMPTY) do
    local bandLo, bandHi = tonumber(band.lo), tonumber(band.hi)
    if bandLo and bandHi and bandLo < bandHi then
      entries[#entries + 1] = {
        text = Track.RangeText(bandLo, bandHi),
        lo = bandLo,
        hi = bandHi,
        current = bandLo == lo and bandHi == hi,
      }
    end
  end
  return entries
end

--- The professions the add button offers: every line the route data holds that the character does
--- not have (skills, the pane's facts) and does not track yet (list), by name. Each { text, line,
--- glyph }, glyph the line's Assets key (glyphs, Assets.skillGlyphs). Pure.
function Track.Candidates(tracks, list, skills, nameOf, glyphs)
  local lines = type(tracks) == "table" and type(tracks.lines) == "table" and tracks.lines or EMPTY
  local tracked = {}
  for _, entry in ipairs(type(list) == "table" and list or EMPTY) do
    local line = type(entry) == "table" and tonumber(entry.line) or nil
    if line then
      tracked[line] = true
    end
  end
  local out = {}
  for line, data in pairs(lines) do
    if type(line) == "number" and type(data) == "table" and not heldOwn(skills, line) and not tracked[line] then
      local name = type(nameOf) == "function" and nameOf(line) or nil
      if type(name) ~= "string" or name == "" then
        name = Track.WORDS.profession .. " " .. line
      end
      out[#out + 1] = { text = name, line = line, glyph = type(glyphs) == "table" and glyphs[line] or nil }
    end
  end
  table.sort(out, function(a, b)
    if a.text ~= b.text then
      return a.text < b.text
    end
    return a.line < b.line
  end)
  return out
end

--- Where everything sits in the strip, from its top: the player's own rows (realCount of them, at
--- top + (index - 1) * ROW_H, UI\Pane.lua drawStrip's rule), then a GAP, then each tracked row (its
--- dropdown inline on it, brief LF2) and BLOCK_GAP after each, then the add button, ADD_GAP under
--- the row above it (brief LF1, QA item 240g). top is the strip's own top pad. Answers { rows = {
--- { y } }, addY, height }, every y down from the strip's top. Pure.
function Track.Layout(realCount, trackedCount, top)
  local y = (tonumber(top) or Track.PAD) + (tonumber(realCount) or 0) * Track.ROW_H
  if (tonumber(realCount) or 0) > 0 then
    y = y + Track.GAP
  end
  local out = { rows = {} }
  local count = tonumber(trackedCount) or 0
  for index = 1, count do
    out.rows[index] = { y = y }
    y = y + Track.ROW_H + Track.BLOCK_GAP
  end
  -- The last block's BLOCK_GAP is already the add button's ADD_GAP; under the player's own rows (or
  -- at the top) it is their GAP and one more.
  if count > 0 then
    out.addY = y + Track.ADD_GAP - Track.BLOCK_GAP
  else
    out.addY = y + Track.ADD_GAP - Track.GAP
  end
  out.height = out.addY + Track.ADD_H + Track.PAD
  return out
end

--- Brief LF2 (QA item 264): where a tracked row's pieces sit on its one line, x from the row's left,
--- for a row rowW wide whose name is nameW wide as drawn: { name = { x, w }, field = { x, w }, remove
--- = { x, w } }. The red X keeps its place at the right (its ring GUTTER px from the edge, the button
--- REMOVE_ART_INSET px outside it); the field fills from FIELD_GAP after the name to FIELD_GAP short
--- of the X's ring; the name keeps its own width unless that would leave the field under FIELD_MIN,
--- and is cut to the room left (Track.Ellipsis) where it would. Pure.
function Track.InlineLayout(rowW, nameW)
  rowW = tonumber(rowW) or 0
  local removeX = rowW - (Track.GUTTER - Track.REMOVE_ART_INSET) - Track.REMOVE
  local fieldRight = removeX + Track.REMOVE_ART_INSET - Track.FIELD_GAP
  local nameX = Track.INDENT
  local nameRoom = math.max(fieldRight - Track.FIELD_MIN - Track.FIELD_GAP - nameX, 0)
  local nameWidth = math.min(math.max(tonumber(nameW) or 0, 0), nameRoom)
  local fieldX = nameX + nameWidth + Track.FIELD_GAP
  return {
    name = { x = nameX, w = nameWidth },
    field = { x = fieldX, w = math.max(fieldRight - fieldX, 0) },
    remove = { x = removeX, w = Track.REMOVE },
  }
end

--- Brief LF2: the room a field fieldW wide leaves its words: less FIELD_PAD before them, and the
--- chevron and its FIELD_PAD / 2 each side after them. Never under 0. Pure.
function Track.FieldTextRoom(fieldW)
  return math.max((tonumber(fieldW) or 0) - Track.FIELD_PAD - Track.FIELD_CHEVRON - Track.FIELD_PAD, 0)
end

-- The end of a whole character at or before byte n of text (never inside a UTF-8 sequence).
local function charEnd(text, n)
  while n > 0 and n < #text do
    local nextByte = text:byte(n + 1)
    if not nextByte or nextByte < 0x80 or nextByte >= 0xC0 then
      break
    end
    n = n - 1
  end
  return n
end

--- Brief LF2 (QA item 264, the owner: "the boxes text gets ... if the text gets cut off"): text as it
--- fits in room px, widthOf(words) the drawn width: the whole text where it fits, else the longest
--- start of it (cut on a whole character, a trailing space dropped) with ELLIPSIS after it that fits,
--- the dots alone where no letter does, "" where not even they do. Never wraps or spills. Pure (given
--- a pure widthOf).
function Track.Ellipsis(text, room, widthOf)
  text = tostring(text or "")
  room = tonumber(room) or 0
  if type(widthOf) ~= "function" or text == "" then
    return text
  end
  if (tonumber(widthOf(text)) or 0) <= room then
    return text
  end
  local dots = Track.ELLIPSIS
  local best = nil
  local lo, hi = 1, #text - 1
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    local cut = charEnd(text, mid)
    local candidate = text:sub(1, cut):gsub("%s+$", "") .. dots
    if cut > 0 and (tonumber(widthOf(candidate)) or 0) <= room then
      best = candidate
      lo = mid + 1
    else
      hi = mid - 1
    end
  end
  if best then
    return best
  end
  if (tonumber(widthOf(dots)) or 0) <= room then
    return dots
  end
  return ""
end

--- The strip's scroll, held inside its content: 0 at the top, never past the content's foot. Pure.
function Track.ClampScroll(offset, contentH, viewH)
  local most = math.max((tonumber(contentH) or 0) - (tonumber(viewH) or 0), 0)
  offset = tonumber(offset) or 0
  if offset < 0 then
    return 0
  end
  if offset > most then
    return most
  end
  return offset
end

--- The chosen row as the Trainers & vendors panel and its Show nearest take it: a tracked row with
--- no rank and no cap (the character holds none: "Show nearest" looks for an Apprentice trainer),
--- every other row as it is. Pure: a copy for a tracked row.
function Track.TrainersView(chosen)
  if type(chosen) ~= "table" or chosen.tracked ~= true then
    return chosen
  end
  local out = {}
  for key, value in pairs(chosen) do
    out[key] = value
  end
  out.rank, out.max = nil, nil
  return out
end

-- The point dist px along a rounded rect's outline, clockwise from the top edge's left end (where
-- the top left corner's arc ends): the outline's box from (left, top), pw by ph, corners of radius
-- r. Pure.
local function outlinePoint(dist, left, top, pw, ph, r)
  local straightW, straightH = pw - 2 * r, ph - 2 * r
  local arc = math.pi * r / 2
  local right, bottom = left + pw, top + ph
  local function corner(cx, cy, from, along)
    local angle = from + (r > 0 and along / r or 0)
    return cx + r * math.cos(angle), cy + r * math.sin(angle)
  end
  -- The top, the top right arc, the right, the bottom right arc, the bottom, the bottom left arc,
  -- the left and the top left arc, each { length, the point along it }; y runs down, so an angle of
  -- -pi/2 is a corner's top.
  local legs = {
    {
      straightW,
      function(d)
        return left + r + d, top
      end,
    },
    {
      arc,
      function(d)
        return corner(right - r, top + r, -math.pi / 2, d)
      end,
    },
    {
      straightH,
      function(d)
        return right, top + r + d
      end,
    },
    {
      arc,
      function(d)
        return corner(right - r, bottom - r, 0, d)
      end,
    },
    {
      straightW,
      function(d)
        return right - r - d, bottom
      end,
    },
    {
      arc,
      function(d)
        return corner(left + r, bottom - r, math.pi / 2, d)
      end,
    },
    {
      straightH,
      function(d)
        return left, bottom - r - d
      end,
    },
    {
      arc,
      function(d)
        return corner(left + r, top + r, math.pi, d)
      end,
    },
  }
  for _, leg in ipairs(legs) do
    if dist <= leg[1] then
      return leg[2](dist)
    end
    dist = dist - leg[1]
  end
  return left + r, top
end

--- The dots of a gold dotted border round a w by h box with corners rounded to radius px: { x, y,
--- w, h } squares of side dot whose centres run along the outline half a dot in from the box's edge,
--- evenly spaced about dot + gap px apart all the way round (so no two crowd where the walk closes),
--- each on whole pixels. Brief LF1 (QA item 240d): 1 px dots round 4 px corners (TP1 drew 2 px
--- dots on square corners). radius 0 (or nil) gives square corners. Pure.
function Track.Dots(w, h, dot, gap, radius)
  w, h = tonumber(w) or 0, tonumber(h) or 0
  dot, gap = tonumber(dot) or Track.DOT, tonumber(gap) or Track.DOT_GAP
  local out = {}
  if w < dot or h < dot or dot <= 0 then
    return out
  end
  local pw, ph = w - dot, h - dot
  local r = math.max(math.min(tonumber(radius) or 0, pw / 2, ph / 2), 0)
  local length = 2 * (pw - 2 * r) + 2 * (ph - 2 * r) + 2 * math.pi * r
  if length <= 0 then
    out[1] = { x = 0, y = 0, w = dot, h = dot }
    return out
  end
  local count = math.max(math.floor(length / (dot + math.max(gap, 0)) + 0.5), 1)
  local step = length / count
  local half = dot / 2
  for index = 0, count - 1 do
    local cx, cy = outlinePoint(index * step, half, half, pw, ph, r)
    local x = math.max(math.min(math.floor(cx - half + 0.5), w - dot), 0)
    local y = math.max(math.min(math.floor(cy - half + 0.5), h - dot), 0)
    out[#out + 1] = { x = x, y = y, w = dot, h = dot }
  end
  return out
end

--- A w by h fill with its corners rounded to radius px, as whole pixel rows that never overlap (so
--- one translucent colour lies evenly): a row for each pixel line of the corners, each inset to the
--- circle there, rows of the same inset joined, and the middle as one. Brief LF1 (QA item 240d): the
--- add button's faint fill and its hover, inside the rounded dotted border. Pure.
function Track.RoundFill(w, h, radius)
  w, h = tonumber(w) or 0, tonumber(h) or 0
  local out = {}
  if w <= 0 or h <= 0 then
    return out
  end
  local r = math.max(math.floor(math.min(tonumber(radius) or 0, w / 2, h / 2)), 0)
  local insets = {}
  for row = 0, r - 1 do
    local dy = r - row - 0.5
    insets[row] = math.floor(r - math.sqrt(math.max(r * r - dy * dy, 0)) + 0.5)
  end
  -- The top corners' rows down, then the middle, then the bottom corners' rows down: each run of
  -- one inset is one rect.
  local rows = {}
  for row = 0, r - 1 do
    rows[#rows + 1] = { y = row, inset = insets[row] }
  end
  for row = r, h - r - 1 do
    rows[#rows + 1] = { y = row, inset = 0 }
  end
  for row = h - r, h - 1 do
    rows[#rows + 1] = { y = row, inset = insets[h - 1 - row] }
  end
  for _, row in ipairs(rows) do
    local last = out[#out]
    if last and last.inset == row.inset and last.y + last.h == row.y then
      last.h = last.h + 1
    else
      out[#out + 1] = { x = row.inset, y = row.y, w = w - 2 * row.inset, h = 1, inset = row.inset }
    end
  end
  for _, rect in ipairs(out) do
    rect.inset = nil
  end
  return out
end

--- The first entry a list opens on: 0, or where the current entry would sit below the rows shown,
--- far enough down to show it. Pure.
function Track.MenuStart(entries, rows)
  rows = tonumber(rows) or Track.MENU_MAX_ROWS
  local count = type(entries) == "table" and #entries or 0
  for index, entry in ipairs(type(entries) == "table" and entries or EMPTY) do
    if entry.current and index > rows then
      return math.min(index - rows, math.max(count - rows, 0))
    end
  end
  return 0
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

local globalFn = ItemTree.Util.GlobalFn
local hasScript = ItemTree.Util.HasScript
local setShown = Kit.SetShown
local tint = Kit.Tint
local textColour = Kit.TextColour
local applyAsset = Kit.ApplyAsset
local newTexture = Kit.NewTexture
local wash = Kit.Wash
local hideTooltip = Kit.HideTooltip

local function tracked()
  local found = ItemTree.TrackedProfessions
  return type(found) == "table" and found or nil
end

local function pane()
  return Kit.Pane()
end

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

-- Brief PM1's boundary, as every file of the tab sets its scripts.
local function setScript(frame, script, handler)
  if type(frame) ~= "table" or type(frame.SetScript) ~= "function" or not hasScript(frame, script) then
    return false
  end
  return (pcall(frame.SetScript, frame, script, Kit.GuardScript("Professions.Track." .. tostring(script), handler)))
end

local function number(frame, method)
  if type(frame) ~= "table" or type(frame[method]) ~= "function" then
    return nil
  end
  local ok, value = pcall(frame[method], frame)
  return ok and tonumber(value) or nil
end

local function playCue(cue)
  local ui = ItemTree.UI
  local sound = type(ui) == "table" and ui.Sound or nil
  if type(sound) == "table" and type(sound.PlayCue) == "function" then
    pcall(sound.PlayCue, cue)
  end
end

local function setStrata(frame, strata)
  if type(frame) == "table" and type(frame.SetFrameStrata) == "function" then
    pcall(frame.SetFrameStrata, frame, strata)
  end
end

-- Font safety (UI/Sidebar.lua's shape, as UI\Pane.lua copies it): a template made FontString, the
-- client's font objects where the face will not set, and never a SetText without a font.
local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(Track.FONT_FALLBACKS) do
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
  return ok and face ~= nil and face ~= ""
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
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY", Track.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY")
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  local t = Kit.Theme()
  local face = t and t.fonts and t.fonts.ITEMTREE_FONT_BODY
  if face and type(fontString.SetFont) == "function" then
    local set, applied = pcall(fontString.SetFont, fontString, face, fontSize, "")
    if not set or applied == false then
      fallbackFont(fontString)
    end
  end
  ensureFont(fontString)
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

-- A plain tooltip: a title and white lines.
local function textTooltip(owner, title, lines)
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
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
      pcall(tooltip.AddLine, tooltip, line, 1, 1, 1, true)
    end
  end
  if type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  return true
end

local function registerClicks(frame, ...)
  if type(frame) == "table" and type(frame.RegisterForClicks) == "function" then
    return (pcall(frame.RegisterForClicks, frame, ...))
  end
  return false
end

-- A face and four hairline edges, the zone dropdown's plate (UI/Map.lua's plate): a flat fill in
-- faceKey and gold dim edges.
local function plate(frame, faceKey)
  frame.face = wash(frame, "BACKGROUND", faceKey or Track.FACE)
  if frame.face then
    frame.face:SetAllPoints(frame)
  end
  frame.edges = Kit.Edges(frame, Track.EDGE)
  return frame
end

--------------------------------------------------------------------------------
-- The changes, through Core/TrackedProfessions.lua, then the pane drawn again
--------------------------------------------------------------------------------

local function redraw(select)
  local p = pane()
  if not p then
    return false
  end
  if select ~= nil then
    p.selected = select
  end
  if type(p.Refresh) == "function" then
    pcall(p.Refresh)
  end
  return true
end

--- Adds a profession (at None) and selects it. Answers whether it was added.
function Track.AddLine(line)
  local store = tracked()
  if not store or type(store.Add) ~= "function" then
    return false
  end
  local ok, added = pcall(store.Add, line)
  if ok and added then
    redraw(tonumber(line))
    return true
  end
  return false
end

--- Takes a tracked profession off the list. Answers whether it was there.
function Track.RemoveLine(line)
  local store = tracked()
  if not store or type(store.Remove) ~= "function" then
    return false
  end
  local ok, removed = pcall(store.Remove, line)
  if ok and removed then
    redraw(nil)
    return true
  end
  return false
end

--- Sets a tracked profession's range (lo nil for None) and selects it. Answers whether it changed.
function Track.SetRange(line, lo, hi)
  local store = tracked()
  if not store or type(store.SetRange) ~= "function" then
    return false
  end
  local ok, changed = pcall(store.SetRange, line, lo, hi)
  if ok and changed then
    redraw(tonumber(line))
    return true
  end
  return false
end

--------------------------------------------------------------------------------
-- The lists (the range dropdown's and the add button's)
--------------------------------------------------------------------------------

Track.menuRows = {}
Track.menuEntries = nil
Track.menuOffset = 0
Track.menuOwner = nil
Track.menuPick = nil
Track.globalMouse = false

--- Whether the pointer is over the open list, one of its rows, or the control it drops from (a
--- press there is the control folding the list away, which it answers itself). false where the
--- client will not say.
function Track.MenuHasCursor()
  local menu = Track.menu
  if not (menu and rawget(menu, "shownMenu")) then
    return false
  end
  local frames = { menu, Track.menuOwner }
  for _, row in ipairs(Track.menuRows) do
    frames[#frames + 1] = row
  end
  for _, frame in ipairs(frames) do
    if type(frame) == "table" and type(frame.IsShown) == "function" and type(frame.IsMouseOver) == "function" then
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

--- Hides the open list. voiced is the player putting it away (a press outside it, or on its
--- control again): menuClose, and only where a list was open.
function Track.CloseMenu(voiced)
  local menu = Track.menu
  local wasOpen = (menu and rawget(menu, "shownMenu")) and true or false
  if menu then
    menu.shownMenu = false
    setShown(menu, false)
  end
  for _, row in ipairs(Track.menuRows) do
    setShown(row, false)
  end
  Track.menuEntries, Track.menuOffset = nil, 0
  Track.menuOwner, Track.menuPick = nil, nil
  if voiced and wasOpen then
    playCue("menuClose")
  end
  return wasOpen
end

--- A press anywhere: closes the open list unless it landed on the list or its control.
function Track.OnGlobalMouseDown(button)
  if button ~= nil and button ~= "LeftButton" and button ~= "RightButton" then
    return false
  end
  local menu = Track.menu
  if not (menu and rawget(menu, "shownMenu")) or Track.MenuHasCursor() then
    return false
  end
  return Track.CloseMenu(true)
end

-- Listens for the press itself, once per session, on a frame of our own with no parent. A client that
-- has never heard of the event refuses it; the list then closes on a pick, on its control, and with
-- the pane.
local function watchGlobalMouse()
  if Track.globalMouse then
    return true
  end
  local watcher = Track.watcher
  if not watcher then
    watcher = newFrame("Frame", nil)
    if not watcher then
      return false
    end
    Track.watcher = watcher
    setScript(watcher, "OnEvent", function(_, event, button)
      if event == "GLOBAL_MOUSE_DOWN" then
        Track.OnGlobalMouseDown(button)
      end
    end)
  end
  if type(watcher.RegisterEvent) ~= "function" then
    return false
  end
  local ok, registered = pcall(watcher.RegisterEvent, watcher, "GLOBAL_MOUSE_DOWN")
  if not ok or registered == false then
    return false
  end
  Track.globalMouse = true
  return true
end

-- One row of a list: an optional glyph, the words, and a tick on the current entry. THE PICK IS
-- TAKEN ON THE PRESS (brief E29, UI/Map.lua's block on its zone list).
local function newMenuRow(parent)
  local row = newFrame("Button", parent)
  if not row then
    return nil
  end
  row:SetHeight(Track.MENU_ROW_H)
  if type(row.EnableMouse) == "function" then
    pcall(row.EnableMouse, row, true)
  end
  row.hover = wash(row, "HIGHLIGHT", Track.HOVER)
  if row.hover then
    row.hover:SetAllPoints(row)
  end
  row.icon = newTexture(row, "ARTWORK")
  if row.icon then
    row.icon:SetSize(Track.ICON, Track.ICON)
    row.icon:SetPoint("LEFT", row, "LEFT", Track.GUTTER, 0)
  end
  row.tick = newTexture(row, "OVERLAY")
  if row.tick then
    row.tick:SetSize(Track.ICON, Track.ICON)
    row.tick:SetPoint("RIGHT", row, "RIGHT", -Track.GUTTER, 0)
  end
  row.label = newText(row, Track.FONT_SM, Track.NAME_WORD, "LEFT")
  if not registerClicks(row, "LeftButtonDown") then
    registerClicks(row, "AnyDown")
  end
  setScript(row, "OnClick", function(self, button)
    if button ~= nil and button ~= "LeftButton" then
      return
    end
    local entry, pick = rawget(self, "entry"), Track.menuPick
    playCue("click")
    Track.CloseMenu()
    if type(pick) == "function" and type(entry) == "table" then
      pick(entry)
    end
  end)
  setScript(row, "OnEnter", function(self)
    local entry = rawget(self, "entry")
    if type(entry) == "table" and type(entry.tip) == "string" then
      textTooltip(self, entry.tip)
    end
  end)
  setScript(row, "OnLeave", hideTooltip)
  row:Hide()
  return row
end

local function applyMenuRow(row, entry)
  row.entry = entry
  local glyph = entry.glyph
  local shown = glyph ~= nil and row.icon ~= nil and applyAsset(row.icon, glyph)
  setShown(row.icon, shown and true or false)
  if row.label then
    row.label:ClearAllPoints()
    local left = Track.GUTTER + (shown and (Track.ICON + Track.PAD) or 0)
    row.label:SetPoint("LEFT", row, "LEFT", left, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -(Track.GUTTER * 2 + Track.ICON), 0)
    setText(row.label, entry.text)
    textColour(row.label, entry.current and Track.TITLE_WORD or Track.NAME_WORD)
  end
  local ticked = entry.current == true and row.tick ~= nil and applyAsset(row.tick, Track.TICK_KEY)
  if ticked then
    tint(row.tick, Track.TITLE_WORD)
  end
  setShown(row.tick, ticked and true or false)
  return row
end

local function buildMenu(root)
  local menu = newFrame("Frame", root)
  if not menu then
    return nil
  end
  menu.face = wash(menu, "BACKGROUND", Track.MENU_FILL)
  if menu.face then
    menu.face:SetAllPoints(menu)
  end
  menu.edges = Kit.Edges(menu, Track.EDGE)
  setStrata(menu, Track.MENU_STRATA)
  if type(menu.EnableMouse) == "function" then
    pcall(menu.EnableMouse, menu, true)
  end
  if type(menu.EnableMouseWheel) == "function" then
    pcall(menu.EnableMouseWheel, menu, true)
  end
  if type(menu.SetClampedToScreen) == "function" then
    pcall(menu.SetClampedToScreen, menu, true)
  end
  setScript(menu, "OnMouseWheel", function(_, delta)
    Track.ScrollMenu(delta)
  end)
  menu.track = wash(menu, "ARTWORK", Track.TRACK_COLOUR)
  if menu.track then
    menu.track:SetWidth(Track.MENU_SCROLLER_W)
    menu.track:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1, -1)
    menu.track:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -1, 1)
    menu.track:Hide()
  end
  menu.thumb = wash(menu, "OVERLAY", Track.GOLD)
  if menu.thumb then
    menu.thumb:SetWidth(Track.MENU_SCROLLER_W)
    menu.thumb:Hide()
  end
  -- Whatever hid the list (the pane going with the window, a redraw), it is no longer open.
  setScript(menu, "OnHide", function(self)
    self.shownMenu = false
  end)
  menu:Hide()
  return menu
end

-- The thumb on the scroll track: how far through a long list the pointer is.
local function applyScroller(count, offset)
  local menu = Track.menu
  local trackTexture, thumb = menu and menu.track, menu and menu.thumb
  if not (trackTexture and thumb) then
    return false
  end
  local rows = Track.MENU_MAX_ROWS
  if count <= rows then
    trackTexture:Hide()
    thumb:Hide()
    return false
  end
  local height = rows * Track.MENU_ROW_H
  local run = math.max(math.floor(height * rows / count + 0.5), Track.MENU_ROW_H)
  local most = math.max(count - rows, 1)
  local down = math.floor((height - run) * offset / most + 0.5)
  thumb:ClearAllPoints()
  thumb:SetHeight(run)
  thumb:SetPoint("TOPRIGHT", trackTexture, "TOPRIGHT", 0, -down)
  trackTexture:Show()
  thumb:Show()
  return true
end

local function fillMenu(entries, offset)
  local menu = Track.menu
  local count = #entries
  local rows = math.min(count, Track.MENU_MAX_ROWS)
  local scroller = count > rows and Track.MENU_SCROLLER_W or 0
  local level = number(menu, "GetFrameLevel")
  local shown = 0
  for index = 1, rows do
    local row = Track.menuRows[index]
    if not row then
      row = newMenuRow(menu)
      Track.menuRows[index] = row
    end
    if row then
      shown = index
      if level and type(row.SetFrameLevel) == "function" then
        pcall(row.SetFrameLevel, row, level + 1)
      end
      applyMenuRow(row, entries[offset + index])
      row:ClearAllPoints()
      local top = 1 + (index - 1) * Track.MENU_ROW_H
      row:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -top)
      row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -(1 + scroller), -top)
      row:Show()
    end
  end
  for index = shown + 1, #Track.menuRows do
    setShown(Track.menuRows[index], false)
  end
  applyScroller(count, offset)
  return shown
end

--- Scrolls an open list by whole rows; delta is the wheel's own sign (up is towards the start).
function Track.ScrollMenu(delta)
  local entries, menu = Track.menuEntries, Track.menu
  if not (entries and menu and rawget(menu, "shownMenu")) then
    return false
  end
  local most = math.max(#entries - Track.MENU_MAX_ROWS, 0)
  local offset = math.max(0, math.min(most, (Track.menuOffset or 0) - (tonumber(delta) or 0)))
  if offset == Track.menuOffset then
    return false
  end
  Track.menuOffset = offset
  fillMenu(entries, offset)
  return true
end

--- Opens a list under owner (a control of ours), entries Track.RangeEntries' or Track.Candidates'
--- shape, pick(entry) on a row's press. A second press on the same control folds it away. Answers
--- whether a list is open after.
function Track.OpenMenu(owner, entries, pick)
  if Track.menu and rawget(Track.menu, "shownMenu") and Track.menuOwner == owner then
    Track.CloseMenu(true)
    return false
  end
  Track.CloseMenu()
  local p = pane()
  local root = p and p.root or nil
  if type(root) ~= "table" or type(owner) ~= "table" or type(entries) ~= "table" or #entries == 0 then
    return false
  end
  if not Track.menu then
    Track.menu = buildMenu(root)
  end
  local menu = Track.menu
  if not menu then
    return false
  end
  watchGlobalMouse()
  -- Raised over everything on every open, before its rows are levelled against it.
  setStrata(menu, Track.MENU_STRATA)
  if type(menu.SetFrameLevel) == "function" then
    local level = math.max(number(owner, "GetFrameLevel") or 0, number(root, "GetFrameLevel") or 0)
    pcall(menu.SetFrameLevel, menu, level + Track.MENU_LEVEL_STEP)
  end
  local offset = Track.MenuStart(entries, Track.MENU_MAX_ROWS)
  Track.menuEntries, Track.menuOffset = entries, offset
  Track.menuOwner, Track.menuPick = owner, pick
  local shown = fillMenu(entries, offset)
  if shown == 0 then
    Track.CloseMenu()
    return false
  end
  local width = math.max(number(owner, "GetWidth") or 0, Track.MENU_W)
  menu:SetSize(width, shown * Track.MENU_ROW_H + 2)
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -Track.PAD)
  menu.shownMenu = true
  menu:Show()
  playCue("menuOpen")
  return true
end

--------------------------------------------------------------------------------
-- The strip's host and its scroll
--------------------------------------------------------------------------------

-- Moves the host to the scroll held in Track.scroll, inside the content.
local function placeHost()
  local host, strip = Track.host, Track.strip
  if not (host and strip) then
    return false
  end
  Track.scroll = Track.ClampScroll(Track.scroll, Track.contentH, number(strip, "GetHeight"))
  host:ClearAllPoints()
  host:SetPoint("TOPLEFT", strip, "TOPLEFT", 0, Track.scroll)
  host:SetPoint("TOPRIGHT", strip, "TOPRIGHT", 0, Track.scroll)
  host:SetHeight(math.max(tonumber(Track.contentH) or 1, 1))
  return true
end

--- Scrolls the strip by whole rows under the wheel (up is towards the top), where its rows run past
--- its foot. Answers whether it moved.
function Track.Scroll(delta)
  local before = Track.scroll or 0
  Track.scroll = before - (tonumber(delta) or 0) * Track.ROW_H
  placeHost()
  return Track.scroll ~= before
end

--- The frame every strip row is anchored to (UI\Pane.lua drawStrip and this file's rows): a frame of
--- ours on the strip, moved up and down by the wheel, the strip clipping what runs past its foot.
--- Made once per strip; the strip itself where it cannot be made.
function Track.Host(strip)
  if type(strip) ~= "table" then
    return nil
  end
  if Track.host and Track.strip == strip then
    return Track.host
  end
  local host = newFrame("Frame", strip)
  if not host then
    return strip
  end
  Track.host, Track.strip, Track.scroll = host, strip, 0
  if type(strip.SetClipsChildren) == "function" then
    pcall(strip.SetClipsChildren, strip, true)
  end
  if type(strip.EnableMouseWheel) == "function" then
    pcall(strip.EnableMouseWheel, strip, true)
  end
  setScript(strip, "OnMouseWheel", function(_, delta)
    Track.Scroll(delta)
  end)
  -- Whatever hides the strip (the tab, the window) takes an open list with it.
  setScript(strip, "OnHide", function()
    Track.CloseMenu()
  end)
  placeHost()
  return host
end

--------------------------------------------------------------------------------
-- The tracked rows, their dropdowns and the add button
--------------------------------------------------------------------------------

Track.rowFrames = {}
Track.rangeFrames = {}

-- The red X button. Brief LF1 (QA item 240b, the owner: "The X is grey for both hover and standard
-- state"; it should read yellow, as the craft queue's red X does): TP1 drew the window's red plate
-- (Frame.NewPlateButton) under the client's red X glyph desaturated and tinted gold, and a tint only
-- darkens, so the X landed a dull grey. It is now the craft queue's own close art (Assets
-- BUTTON_CLOSE, the client's red round button with its yellow X), drawn the way UI\Queue.lua draws
-- the tray's close and each row's X: one texture over the whole button, untinted, so the X keeps the
-- art's own yellow. Under the pointer the same art lies over itself additively (the HIGHLIGHT layer,
-- REMOVE_LIT), so the button brightens and the X stays yellow, never greyed.
local function buildRemove(row)
  local button = newFrame("Button", row)
  if not button then
    return nil
  end
  button:SetSize(Track.REMOVE, Track.REMOVE)
  button.icon = newTexture(button, "ARTWORK")
  if button.icon then
    button.icon:SetAllPoints(button)
    applyAsset(button.icon, Track.REMOVE_KEY)
  end
  button.lit = newTexture(button, "HIGHLIGHT")
  if button.lit then
    button.lit:SetAllPoints(button)
    if applyAsset(button.lit, Track.REMOVE_KEY) then
      if type(button.lit.SetBlendMode) == "function" then
        pcall(button.lit.SetBlendMode, button.lit, "ADD")
      end
      if type(button.lit.SetAlpha) == "function" then
        pcall(button.lit.SetAlpha, button.lit, Track.REMOVE_LIT)
      end
    else
      setShown(button.lit, false)
    end
  end
  registerClicks(button, "LeftButtonUp")
  button:ClearAllPoints()
  button:SetPoint("RIGHT", row, "RIGHT", -(Track.GUTTER - Track.REMOVE_ART_INSET), 0)
  setScript(button, "OnEnter", function(self)
    local data = rawget(row, "data")
    local name = type(data) == "table" and data.name or Track.WORDS.profession
    textTooltip(self, string.format(Track.WORDS.remove, tostring(name)))
  end)
  setScript(button, "OnLeave", hideTooltip)
  setScript(button, "OnClick", function()
    local data = rawget(row, "data")
    if type(data) == "table" then
      playCue("click")
      Track.RemoveLine(data.line)
    end
  end)
  button:Show()
  return button
end

local buildRange

-- One tracked row: the strip row's look (UI\Pane.lua buildStripRow), the red X on its right and
-- (brief LF2, QA item 264) its range dropdown between the name and the X, built on the row itself so
-- it stands over the row's own washes; Track.Draw lays the name and the dropdown out for the name's
-- width (Track.InlineLayout).
local function buildRow(host)
  local row = newFrame("Button", host)
  if not row then
    return nil
  end
  row:SetHeight(Track.ROW_H)
  row.selected = wash(row, "BACKGROUND", Track.SELECTED)
  if row.selected then
    row.selected:SetAllPoints(row)
  end
  row.hover = wash(row, "HIGHLIGHT", Track.HOVER)
  if row.hover then
    row.hover:SetAllPoints(row)
  end
  row.icon = newTexture(row, "ARTWORK")
  if row.icon then
    row.icon:SetSize(Track.ICON, Track.ICON)
    row.icon:SetPoint("LEFT", row, "LEFT", Track.GUTTER, 0)
  end
  row.label = newText(row, Track.FONT_MD, Track.NAME_WORD, "LEFT")
  if row.label then
    row.label:SetPoint("LEFT", row, "LEFT", Track.INDENT, 0)
  end
  row.remove = buildRemove(row)
  row.range = buildRange(row)
  registerClicks(row, "LeftButtonUp")
  setScript(row, "OnClick", function(self)
    local data = rawget(self, "data")
    local p = pane()
    if type(data) == "table" and p and data.line ~= p.selected then
      redraw(data.line)
    end
  end)
  setScript(row, "OnEnter", function(self)
    local data = rawget(self, "data")
    if type(data) == "table" then
      textTooltip(self, tostring(data.name or ""), { string.format(Track.WORDS.rowTip, tostring(data.name or "")) })
    end
  end)
  setScript(row, "OnLeave", hideTooltip)
  return row
end

-- The range dropdown: a plate, the range's words, the down chevron on its right. Brief LF1 (QA item
-- 240e): the plate's face is the dark FIELD_FILL, its open list's own. Brief LF2 (QA item 264): on
-- the row's own line, so its words start FIELD_PAD in and its chevron is FIELD_CHEVRON px,
-- FIELD_PAD / 2 from its right edge; Track.Draw sizes the words to the room left
-- (Track.FieldTextRoom) and cuts them with an ellipsis (Track.Ellipsis).
buildRange = function(row)
  local button = newFrame("Button", row)
  if not button then
    return nil
  end
  button:SetHeight(Track.RANGE_H)
  plate(button, Track.FIELD_FILL)
  button.hover = wash(button, "HIGHLIGHT", Track.HOVER)
  if button.hover then
    button.hover:SetAllPoints(button)
  end
  button.chevron = newTexture(button, "OVERLAY")
  if button.chevron then
    button.chevron:SetSize(Track.FIELD_CHEVRON, Track.FIELD_CHEVRON)
    button.chevron:SetPoint("RIGHT", button, "RIGHT", -Track.FIELD_PAD / 2, 0)
    setShown(button.chevron, applyAsset(button.chevron, Track.CHEVRON_KEY))
    tint(button.chevron, Track.NAME_WORD)
  end
  button.label = newText(button, Track.FONT_SM, Track.NAME_WORD, "LEFT")
  if button.label then
    button.label:SetPoint("LEFT", button, "LEFT", Track.FIELD_PAD, 0)
  end
  -- The control answers the release, as the zone dropdown does, so a second press folds its list.
  registerClicks(button, "LeftButtonUp")
  setScript(button, "OnClick", function(self)
    local data = rawget(self, "data")
    if type(data) ~= "table" then
      return
    end
    local tracks = (Track.args or EMPTY).tracks or ItemTree.ProfessionTracks
    local line = data.line
    Track.OpenMenu(self, Track.RangeEntries(tracks, line, data.lo, data.hi), function(entry)
      if entry.none then
        Track.SetRange(line, nil, nil)
      else
        Track.SetRange(line, entry.lo, entry.hi)
      end
    end)
  end)
  setScript(button, "OnEnter", function(self)
    local data = rawget(self, "data")
    if type(data) ~= "table" then
      return
    end
    if data.lo == nil then
      textTooltip(self, Track.WORDS.noneTip)
    else
      local name, lo, hi = tostring(data.name or ""), tonumber(data.lo) or 0, tonumber(data.hi) or 0
      textTooltip(self, string.format(Track.WORDS.rangeTip, name, lo, hi))
    end
  end)
  setScript(button, "OnLeave", hideTooltip)
  return button
end

-- The add button: the gold dotted border, the "+" and the words, centred. Brief LF1 (QA item 240d):
-- its faint fill and its hover wash are drawn rounded, with the border, for the button's width
-- (paintDots), so neither shows a square corner past the dots.
local function buildAdd(host)
  local button = newFrame("Button", host)
  if not button then
    return nil
  end
  button:SetHeight(Track.ADD_H)
  button.fills, button.hovers = {}, {}
  button.dots = {}
  button.label = newText(button, Track.FONT_SM, Track.TITLE_WORD, "CENTER")
  if button.label then
    -- Centred as a group with the "+": the words shift right by half the glyph and its gap.
    button.label:SetPoint("CENTER", button, "CENTER", (Track.PLUS + Track.PAD) / 2, 0)
    setText(button.label, Track.WORDS.add)
  end
  button.plus = newTexture(button, "ARTWORK")
  if button.plus then
    button.plus:SetSize(Track.PLUS, Track.PLUS)
    if button.label then
      button.plus:SetPoint("RIGHT", button.label, "LEFT", -Track.PAD, 0)
    else
      button.plus:SetPoint("CENTER", button, "CENTER", 0, 0)
    end
    setShown(button.plus, applyAsset(button.plus, Track.PLUS_KEY))
  end
  registerClicks(button, "LeftButtonUp")
  setScript(button, "OnClick", function(self)
    local args = Track.args or EMPTY
    local a = Kit.Assets()
    local entries = Track.Candidates(args.tracks, Track.List(), args.skills, args.nameOf, a and a.skillGlyphs or nil)
    Track.OpenMenu(self, entries, function(entry)
      Track.AddLine(entry.line)
    end)
  end)
  setScript(button, "OnEnter", function(self)
    textTooltip(self, Track.WORDS.add, { Track.WORDS.addHint })
  end)
  setScript(button, "OnLeave", hideTooltip)
  return button
end

-- Lays rects (the button's own coordinates, y down) as washes of colourKey on layer, reusing the
-- textures in pool and hiding the ones left over. Answers how many it laid.
local function paintRects(button, pool, rects, layer, colourKey)
  for index, rect in ipairs(rects) do
    local texture = pool[index]
    if not texture then
      texture = wash(button, layer, colourKey)
      pool[index] = texture
    end
    if texture then
      texture:ClearAllPoints()
      texture:SetPoint("TOPLEFT", button, "TOPLEFT", rect.x, -rect.y)
      texture:SetSize(rect.w, rect.h)
      texture:Show()
    end
  end
  for index = #rects + 1, #pool do
    setShown(pool[index], false)
  end
  return #rects
end

-- The dotted border drawn for the add button's width (once per width: the strip's is fixed), and
-- (brief LF1) the rounded faint fill under it and the rounded hover wash.
local function paintDots(button, w)
  if rawget(button, "dotsW") == w then
    return #button.dots
  end
  local fill = Track.RoundFill(w, Track.ADD_H, Track.ADD_RADIUS)
  paintRects(button, button.fills, fill, "BACKGROUND", Track.ADD_FILL)
  paintRects(button, button.hovers, fill, "HIGHLIGHT", Track.HOVER)
  local count = paintRects(
    button,
    button.dots,
    Track.Dots(w, Track.ADD_H, Track.DOT, Track.DOT_GAP, Track.ADD_RADIUS),
    "BORDER",
    Track.GOLD
  )
  button.dotsW = w
  return count
end

--- The character's tracked list (Core/TrackedProfessions.lua Tracked.List), or {}.
function Track.List()
  local store = tracked()
  if store and type(store.List) == "function" then
    local ok, list = pcall(store.List)
    if ok and type(list) == "table" then
      return list
    end
  end
  return {}
end

-- Brief LF2: words as the client draws them at no width of their own, for Track.Ellipsis: the
-- FontString let go of its width first (0 is none), then its unbounded width where the client has the
-- call, its string width, or CHAR_W a character where it will say neither.
local function wordsWidth(fontString, text)
  if type(fontString) == "table" and type(fontString.SetWidth) == "function" then
    pcall(fontString.SetWidth, fontString, 0)
  end
  setText(fontString, text)
  if type(fontString) ~= "table" then
    return #tostring(text or "") * Track.CHAR_W
  end
  if type(fontString.GetUnboundedStringWidth) == "function" then
    local ok, width = pcall(fontString.GetUnboundedStringWidth, fontString)
    width = ok and tonumber(width) or nil
    if width and width > 0 then
      return width
    end
  end
  return Kit.StringWidth(fontString) or #tostring(text or "") * Track.CHAR_W
end

-- Brief LF2: text set on fontString cut to room px with an ellipsis (Track.Ellipsis), the
-- FontString held to that width so the client never wraps or spills it either. Answers the words
-- drawn.
local function fitText(fontString, text, room)
  if type(fontString) ~= "table" then
    return nil
  end
  local fitted = Track.Ellipsis(text, room, function(words)
    return wordsWidth(fontString, words)
  end)
  setText(fontString, fitted)
  if type(fontString.SetWidth) == "function" then
    pcall(fontString.SetWidth, fontString, math.max(room, 1))
  end
  return fitted
end

local function placeAt(frame, host, x, y, h)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", host, "TOPLEFT", x, -y)
  frame:SetPoint("TOPRIGHT", host, "TOPRIGHT", -Track.GUTTER, -y)
  frame:SetHeight(h)
end

--- Draws the tracked rows, their dropdowns and the add button under the player's own rows.
--- args = { strip, top (the strip's top pad), realCount, rows (Track.Rows' answer), chosen, tracks,
--- skills, nameOf, width }. Answers the layout drawn (Track.Layout), or nil where nothing could be.
function Track.Draw(args)
  if type(args) ~= "table" then
    return nil
  end
  Track.args = args
  local host = Track.Host(args.strip)
  if type(host) ~= "table" then
    return nil
  end
  local rows = type(args.rows) == "table" and args.rows or EMPTY
  local layout = Track.Layout(args.realCount, #rows, args.top)
  local a = Kit.Assets()
  local chosen = args.chosen
  local p = pane()
  local stripW = tonumber(args.width) or (p and tonumber(p.STRIP_W)) or 180
  for index, data in ipairs(rows) do
    local place = layout.rows[index]
    local row = Track.rowFrames[index]
    if not row then
      row = buildRow(host)
      Track.rowFrames[index] = row
    end
    if row then
      row.data = data
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -place.y)
      row:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -place.y)
      local isChosen = type(chosen) == "table" and chosen.line == data.line
      setShown(row.selected, isChosen)
      if row.icon then
        local glyph = a and type(a.ForSkill) == "function" and a.ForSkill(data.line) or nil
        setShown(row.icon, glyph ~= nil and applyAsset(row.icon, glyph))
      end
      -- Brief LF2 (QA item 264): the name at its own width, cut where the dropdown needs the room,
      -- and the dropdown filling the gap to the X, its words cut with an ellipsis to fit.
      local inline = Track.InlineLayout(stripW, wordsWidth(row.label, data.name))
      row.inline = inline
      if row.label then
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", inline.name.x, 0)
        fitText(row.label, data.name, inline.name.w)
      end
      textColour(row.label, isChosen and Track.SELECTED_WORD or Track.NAME_WORD)
      setShown(row.remove, true)
      row:Show()
      local range = rawget(row, "range")
      Track.rangeFrames[index] = range
      if range then
        range.data = data
        range:ClearAllPoints()
        range:SetPoint("LEFT", row, "LEFT", inline.field.x, 0)
        range:SetSize(math.max(inline.field.w, 1), Track.RANGE_H)
        range.fullText = Track.RangeText(data.lo, data.hi)
        fitText(range.label, range.fullText, Track.FieldTextRoom(inline.field.w))
        textColour(range.label, data.lo == nil and Track.MUTED_WORD or Track.NAME_WORD)
        range:Show()
      end
    end
  end
  for index = #rows + 1, #Track.rowFrames do
    setShown(Track.rowFrames[index], false)
  end
  for index = #rows + 1, #Track.rangeFrames do
    setShown(Track.rangeFrames[index], false)
  end
  if not Track.add then
    Track.add = buildAdd(host)
  end
  local add = Track.add
  if add then
    placeAt(add, host, Track.GUTTER, layout.addY, Track.ADD_H)
    paintDots(add, math.max(stripW - Track.GUTTER * 2, Track.DOT))
    -- Shown while there is still a profession to add.
    local left = Track.Candidates(args.tracks, Track.List(), args.skills, args.nameOf)
    setShown(add, #left > 0)
  end
  Track.contentH = layout.height
  placeHost()
  -- A list whose control went with this draw (its row taken off) goes too.
  local owner = Track.menuOwner
  if type(owner) == "table" and type(owner.IsShown) == "function" and not owner:IsShown() then
    Track.CloseMenu()
  end
  return layout
end

return Track
