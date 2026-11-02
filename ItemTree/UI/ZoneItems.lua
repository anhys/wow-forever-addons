-- The item column of a zone's Map view (brief Z2).
--
-- While a zone page's Map view is up, the column the category list takes on the Here view holds
-- the zone's ITEMS instead: one row per item per kind of source, under the Here view's own
-- headers ("Dropped here", "Mined here"), each with the item's icon, its name in its quality's
-- colour and a muted count of its sources in the zone ("8 creatures", "6 nodes"). The search box
-- on the view tab row filters the rows by name. Pressing a row picks it and the map beside it pins
-- that item's creatures, nodes or vendors (UI/Map.lua Map.DrawZoneItem); pressing a header opens or
-- closes its group.
--
-- Core builds the list (Core/ViewModel.lua ViewModel.ZoneItemList, when this column is first shown
-- for a zone, never at login and never on the Here view) and holds the pick for the session
-- (ViewModel.ZoneItemPick). This file only draws them.
--
-- Pure, and read by tests/spec/ui_zoneitems_spec.lua with no client at all:
--   ZoneItems.RowModel(row, selectedKey)      what one row draws
--   ZoneItems.Window(count, offset, capacity) which rows a list that tall shows, and the offset
--   ZoneItems.OffsetFor(rows, key, offset, capacity) the offset that keeps a row on screen
--   ZoneItems.CountTexts(rows)                every distinct count text a list of rows draws
--   ZoneItems.CountWidth(widths)              the count column's width for those texts measured
--   ZoneItems.TipLines(model)                 what a hovered item row's tooltip says
--   ZoneItems.Density()                       "compact" or "default", the tree's own read
--   ZoneItems.RowHeight(density)              how tall a row is drawn at a density
--   ZoneItems.EyeLayout(density)              the eye button's size, gap and right hand offset
--   ZoneItems.EyeTip(model)                   the eye button's tooltip ("View Linen Cap")
--   ZoneItems.SplitWidths(room, nameW, countW, gap) the name's and the count's share of a row
--   ZoneItems.ThumbSpan(count, room, height)  how tall the scroll thumb is and how far it travels
--   ZoneItems.ThumbTop(span, offset, count, room) how far down its track the thumb sits
--   ZoneItems.TrackHit(y, top, tall)          whether a press on the track is above, on or below it
--   ZoneItems.DragOffset(start, down, count, room, height) the offset a thumb dragged down gives
--
-- Brief Z1: the name is what the row is for, so it gets the room. The count or place text beside
-- it keeps its full width only while the name fits too; otherwise it yields first, down to a third
-- of the row ("3 cr..."), and only then is the name cut short. The scroll thumb takes a mouse drag
-- (the same press, OnUpdate and GetCursorPosition shape UI/Chain.lua pans its canvas with), and a
-- press on the track above or below it pages the list.
--
-- Brief Z3: every item row carries a square eye button at its right edge that opens the item's
-- page (the same Frame.Open a Sources row re-roots with); pressing the rest of the row still picks
-- the item for the map. Headers carry none. The rows follow the Compact rows setting, and the
-- button follows the row.
--
-- Brief Z2 (2026-09-30, the owner's QA): every group starts CLOSED, per zone for the session. A
-- pick the column did not make itself (the item the player arrived from, a source picked on the Here
-- tab) opens its own group, and the row is scrolled into view. While the search box holds words
-- every group is drawn open, so a search shows its matches. After the item groups come "Creatures
-- here" and "NPCs here" (Core/ViewModel.lua ViewModel.ZonePeopleGroups): one row per name, its
-- level or type beside it and its places or its role at the right, the eye opening its page.
--   ZoneItems.ClosedGroups(list, state, search) which groups a draw closes
--   ZoneItems.LabelText(model)                the name and, muted, the words beside it
--
-- Brief PR37 (the owner, 2026-10-02): a gathering line's zone on the Professions tab opens this
-- column on the group of its items the line gathers (skinned, mined, herbs, fished), with the
-- group's first item picked so the map pins it. The window asks for it on its open
-- (UI/Frame.lua Frame.ZoneGroupOpts, opts.zoneGroups), which is the only caller:
--   ZoneItems.MatchGroup(list, ids)           the first of those group ids the list holds items in
--   ZoneItems.FirstOfGroup(list, groupId)     that group's first item row, as the column draws it
--   ZoneItems.ArriveOnGroup(rootKey, groupId) the next Show of that zone opens on it, once
--
-- Contract with the window (UI/Frame.lua):
--   ZoneItems.Show(region, rootKey, opts, fromKey, mapRegion) draws the column for a zone root
--   ZoneItems.Hide() hides it
-- Both guarded, and no ops with no client.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local ZoneItems = {}
ItemTree.UI.ZoneItems = ZoneItems

local Theme = ItemTree.Theme
local Assets = ItemTree.Assets
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

local size = Theme.Size

ZoneItems.ROW_H = size("ITEMTREE_LIST_ROW_H", 22)
ZoneItems.ICON = size("ITEMTREE_ICON_CATEGORY", 16)
ZoneItems.CHEVRON = size("ITEMTREE_LIST_CHEVRON", 12)
ZoneItems.GUTTER = size("ITEMTREE_LIST_GUTTER", 6)
ZoneItems.INDENT = size("ITEMTREE_SPACE_3", 12)
-- Brief Q9b: the count column is as wide as the widest count text the list draws, measured once
-- per build of the list, never under COUNT_MIN_W and never over COUNT_W (the fixed width it had),
-- so the name column only ever gains room and the column, the window and the map never move.
ZoneItems.COUNT_W = 84
ZoneItems.COUNT_MIN_W = 56
-- Roughly how wide one character of the small body face is, as a share of its size, where nothing
-- can measure a font (the same estimate UI/Map.lua keeps).
ZoneItems.CHAR_W = 0.55
ZoneItems.EDGE_W = size("ITEMTREE_BORDER_HAIRLINE", 1)
ZoneItems.THUMB_W = size("ITEMTREE_SPACE_1", 4)
ZoneItems.WHEEL_STEP = 3
ZoneItems.ROW_H_COMPACT = size("ITEMTREE_LIST_ROW_H_COMPACT", 18)
-- Brief Z3: the eye button is square, EYE_GAP left of it is the count column, and it sits where
-- the count used to end. Brief BL31: it is the Boss loot place row's red plate button (UI/Frame.lua
-- Frame.NewPlateButton), EYE_SIZE (the category glyph's 16) on default rows and the row's height
-- less EYE_INSET at the top and at the bottom where that is smaller (a Compact row's 14), at full
-- strength in every state. The glyph is the plate less EYE_BEVEL each side (UI/Frame.lua
-- Frame.PLATE_BEVEL), so it scales with the plate.
ZoneItems.EYE_INSET = 2
ZoneItems.EYE_GAP = size("ITEMTREE_SPACE_1", 4)
ZoneItems.EYE_SIZE = size("ITEMTREE_ICON_CATEGORY", 16)
ZoneItems.EYE_BEVEL = 3
-- Brief BL30: the flat one colour eye (the owner's ruling, the same glyph as the Boss loot place
-- row's map button), else the flat "go to" arrow where the client will not draw it.
ZoneItems.EYE_ASSET = "ICON_VIEW_FLAT"
ZoneItems.EYE_FALLBACK = "ICON_VIEW_GO"
-- Brief Z1: the most of a row the count or place text keeps once the name no longer fits, and the
-- grab strip down the right hand edge the thumb is drawn in (the gutter and the thumb, which is the
-- room the rows already leave there), raised this many levels over the rows so it takes the press.
ZoneItems.COUNT_SHARE = 1 / 3
ZoneItems.GRAB_W = ZoneItems.GUTTER + ZoneItems.THUMB_W
ZoneItems.TRACK_LEVEL = 10

ZoneItems.SURFACE = "ITEMTREE_COLOR_SURFACE_INSET"
ZoneItems.BORDER = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
ZoneItems.COLOR_TITLE = "ITEMTREE_COLOR_TEXT_TITLE"
ZoneItems.COLOR_BODY = "ITEMTREE_COLOR_TEXT_BODY"
ZoneItems.COLOR_MUTED = "ITEMTREE_COLOR_TEXT_MUTED"
ZoneItems.COLOR_HOVER = "ITEMTREE_COLOR_STATE_HOVER"
ZoneItems.COLOR_SELECTED = "ITEMTREE_COLOR_STATE_SELECTED"
ZoneItems.COLOR_EDGE = "ITEMTREE_COLOR_BORDER_GOLD"
ZoneItems.COLOR_THUMB = "ITEMTREE_COLOR_BORDER_DIVIDER"

ZoneItems.FONT_TEMPLATE = "GameFontNormalSmall"
ZoneItems.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }

-- The session's own state, per zone root: { [group id] = false } for a group opened (by the player
-- or by an arrival) and true for one the player closed again; a group not in it is closed. Never
-- saved.
ZoneItems.collapsed = {}
-- The pick each zone root's column last showed, so only a pick it did not make opens a group.
ZoneItems.shownPicks = {}
-- Brief PR37: the group each zone root's next Show opens on with its first item picked
-- (ZoneItems.ArriveOnGroup), taken by that Show. Never saved.
ZoneItems.groupArrivals = {}

--------------------------------------------------------------------------------
-- Pure
--------------------------------------------------------------------------------

-- The colour an item's name is written in: its quality's, or muted for an item this build withholds
-- and nobody has named. Theme keeps the quality table, so the key comes from there.
local function nameColour(entry)
  if entry.undiscovered and not entry.discovered then
    return ZoneItems.COLOR_MUTED
  end
  if Theme and type(Theme.QualityKey) == "function" and entry.quality ~= nil then
    return Theme.QualityKey(entry.quality)
  end
  return ZoneItems.COLOR_BODY
end

--- What one row of ViewModel.ZoneItemRows draws:
---   { kind, key, text, countText, colorKey, countColor, iconAsset or iconFile, chevronAsset,
---     indent, selected, id (a header's group), entry (an item's row) }
--- A header wears its group's glyph and the tree's chevron; an item its own icon, indented one step.
function ZoneItems.RowModel(row, selectedKey)
  if type(row) ~= "table" then
    return nil
  end
  if row.kind == "category" then
    local icon = row.icon
    if not (type(icon) == "string" and Assets and Assets.Has(icon)) then
      icon = "CAT_NOTE"
    end
    return {
      kind = "category",
      key = row.key,
      id = row.id,
      text = tostring(row.label or ""),
      countText = string.format("(%d)", tonumber(row.count) or 0),
      colorKey = ZoneItems.COLOR_TITLE,
      countColor = ZoneItems.COLOR_MUTED,
      iconAsset = icon,
      chevronAsset = row.collapsed and "ICON_CHEVRON_EXPAND" or "ICON_CHEVRON_COLLAPSE",
      indent = 0,
      selected = false,
    }
  end
  local entry = type(row.entry) == "table" and row.entry or EMPTY
  local model = {
    kind = "item",
    key = row.key,
    entry = entry,
    text = tostring(entry.name or ""),
    countText = tostring(entry.countText or ""),
    colorKey = nameColour(entry),
    countColor = ZoneItems.COLOR_MUTED,
    indent = ZoneItems.INDENT,
    selected = selectedKey ~= nil and row.key == selectedKey,
    -- Brief Z3: the page the row's eye button opens.
    viewKey = type(entry.item) == "string" and entry.item or nil,
    -- Brief Z2 (2026-09-30): a creature's level beside its name, and a creature's or an NPC's
    -- tooltip lines under it.
    detail = type(entry.detail) == "string" and entry.detail ~= "" and entry.detail or nil,
    tips = type(entry.tips) == "table" and entry.tips or nil,
  }
  local icon = entry.icon
  if type(icon) == "string" and Assets and Assets.Has(icon) then
    model.iconAsset = icon
  elseif icon ~= nil then
    model.iconFile = icon
  else
    model.iconAsset = "ICON_QUESTIONMARK"
  end
  return model
end

--- Brief Z2 (2026-09-30): the set of group ids a draw closes: every group of the list whose state is
--- not false (so a group nobody opened is closed), and none at all while search holds words. Pure.
function ZoneItems.ClosedGroups(list, state, search)
  local closed = {}
  if type(search) == "string" and search:match("%S") then
    return closed
  end
  state = type(state) == "table" and state or EMPTY
  for _, group in ipairs(type(list) == "table" and list.groups or EMPTY) do
    if group.id ~= nil and state[group.id] ~= false then
      closed[group.id] = true
    end
  end
  return closed
end

--- Brief Z2 (2026-09-30): what a row's label says: the name, and the words beside it (a creature's
--- level) muted after it. Pure.
function ZoneItems.LabelText(model)
  if type(model) ~= "table" then
    return ""
  end
  local text = tostring(model.text or "")
  if type(model.detail) ~= "string" or model.detail == "" then
    return text
  end
  local detail = model.detail
  if Theme and type(Theme.Colorise) == "function" and type(Theme.ColorTable) == "function" then
    if Theme.ColorTable(ZoneItems.COLOR_MUTED) then
      detail = Theme.Colorise(ZoneItems.COLOR_MUTED, detail)
    end
  end
  return text .. "  " .. detail
end

--- Which rows a list of count rows shows capacity at a time from offset: the first and last index,
--- and the offset clamped so the list never scrolls past its own end. Pure.
function ZoneItems.Window(count, offset, capacity)
  count = math.max(0, math.floor(tonumber(count) or 0))
  capacity = math.max(1, math.floor(tonumber(capacity) or 1))
  local most = math.max(0, count - capacity)
  offset = math.max(0, math.min(most, math.floor(tonumber(offset) or 0)))
  return offset + 1, math.min(count, offset + capacity), offset
end

--- The offset that puts the row with key on screen, moving as little as it can: the offset it was
--- where the row is already shown, else the row at the top or the bottom. Pure.
function ZoneItems.OffsetFor(rows, key, offset, capacity)
  offset = math.max(0, math.floor(tonumber(offset) or 0))
  capacity = math.max(1, math.floor(tonumber(capacity) or 1))
  if key == nil then
    return offset
  end
  for index, row in ipairs(type(rows) == "table" and rows or EMPTY) do
    if row.key == key then
      if index <= offset then
        return index - 1
      end
      if index > offset + capacity then
        return index - capacity
      end
      return offset
    end
  end
  return offset
end

--- Brief Q9b: every distinct count text a list of ViewModel.ZoneItemRows rows draws, in first seen
--- order: an item's "8 creatures" and a header's "(12)". Pure.
function ZoneItems.CountTexts(rows)
  local out, seen = {}, {}
  for _, row in ipairs(type(rows) == "table" and rows or EMPTY) do
    local model = ZoneItems.RowModel(row, nil)
    local text = model and model.countText or nil
    if type(text) == "string" and text ~= "" and not seen[text] then
      seen[text] = true
      out[#out + 1] = text
    end
  end
  return out
end

--- Roughly how wide a text is at one font size where the client cannot measure it. Pure.
function ZoneItems.TextWidth(text, fontSize)
  if type(text) ~= "string" or text == "" then
    return 0
  end
  return math.ceil(#text * (tonumber(fontSize) or 11) * ZoneItems.CHAR_W)
end

--- Brief Q9b: the count column's width for the measured widths of the texts it draws: the widest,
--- rounded up, held between ZoneItems.COUNT_MIN_W and ZoneItems.COUNT_W. Pure.
function ZoneItems.CountWidth(widths)
  local widest = 0
  for _, width in ipairs(type(widths) == "table" and widths or EMPTY) do
    local at = tonumber(width) or 0
    if at > widest then
      widest = at
    end
  end
  widest = math.ceil(widest)
  if widest < ZoneItems.COUNT_MIN_W then
    return ZoneItems.COUNT_MIN_W
  end
  if widest > ZoneItems.COUNT_W then
    return ZoneItems.COUNT_W
  end
  return widest
end

--- Brief Q9b: what a hovered item row's tooltip says, the name in full (the column may have cut it
--- short) in the name's own colour and the count words under it, muted. nil for a header or a row
--- with nothing to say. Pure: { { text, colorKey } }.
function ZoneItems.TipLines(model)
  if type(model) ~= "table" or model.kind ~= "item" then
    return nil
  end
  local out = {}
  if type(model.text) == "string" and model.text ~= "" then
    out[#out + 1] = { text = model.text, colorKey = model.colorKey or ZoneItems.COLOR_BODY }
  end
  -- Brief Z2 (2026-09-30): a creature's kind or an NPC's title and roles, which say the rest.
  if type(model.tips) == "table" then
    for _, line in ipairs(model.tips) do
      if type(line) == "string" and line ~= "" then
        out[#out + 1] = { text = line, colorKey = ZoneItems.COLOR_MUTED }
      end
    end
    return #out > 0 and out or nil
  end
  if type(model.countText) == "string" and model.countText ~= "" then
    out[#out + 1] = { text = model.countText, colorKey = ZoneItems.COLOR_MUTED }
  end
  if #out == 0 then
    return nil
  end
  return out
end

--- The row density the tree draws at: "compact" where the settings say so, else "default". The
--- same read as UI/Tree.lua Tree.Density. Pure over ItemTree.db.
function ZoneItems.Density()
  local settings = ItemTree.db and ItemTree.db.settings
  if type(settings) == "table" and settings.density == "compact" then
    return "compact"
  end
  return "default"
end

--- How tall every row of the column is drawn at a density: the tree's own 22, or 18 compact. Pure.
function ZoneItems.RowHeight(density)
  if density == "compact" then
    return ZoneItems.ROW_H_COMPACT
  end
  return ZoneItems.ROW_H
end

--- Brief Z3: the eye button at a density, { size, glyph, gap, right }: a square of EYE_SIZE, or
--- the row's height less EYE_INSET above and below where that is smaller (brief BL31), the glyph
--- on it (the plate less EYE_BEVEL each side), the gap left of it to the count column, and how
--- far its right edge sits in from the row's (the gutter and the scroll thumb's room). Pure.
function ZoneItems.EyeLayout(density)
  local height = ZoneItems.RowHeight(density)
  local side = math.max(1, math.min(ZoneItems.EYE_SIZE, height - 2 * ZoneItems.EYE_INSET))
  return {
    size = side,
    glyph = math.max(1, side - 2 * ZoneItems.EYE_BEVEL),
    gap = ZoneItems.EYE_GAP,
    right = ZoneItems.GUTTER + ZoneItems.THUMB_W,
  }
end

--- Brief Z3: what the eye button's tooltip says, "View <item name>". nil for a header or an item
--- row with no page to open. Pure.
function ZoneItems.EyeTip(model)
  if type(model) ~= "table" or model.kind ~= "item" or type(model.viewKey) ~= "string" then
    return nil
  end
  local name = type(model.text) == "string" and model.text or ""
  return string.format(L["View %s"], name)
end

--- Brief Z1: how a row's room splits between the name and the count or place text right of it,
--- gap apart. Where both fit, the count keeps its full width and the name has the rest. Where they
--- do not, the count yields first: it keeps what the name leaves it, but never less than
--- COUNT_SHARE of the room (nor more than it needs), and the name has what is left. Pure: answers
--- nameWidth, countWidth, whole pixels, never below 0.
function ZoneItems.SplitWidths(room, nameWidth, countWidth, gap)
  room = math.max(0, math.floor(tonumber(room) or 0))
  nameWidth = math.max(0, math.ceil(tonumber(nameWidth) or 0))
  countWidth = math.max(0, math.ceil(tonumber(countWidth) or 0))
  gap = math.max(0, tonumber(gap) or 0)
  local count = countWidth
  if nameWidth + gap + countWidth > room then
    local floorShare = math.floor(room * ZoneItems.COUNT_SHARE)
    count = math.min(countWidth, math.max(floorShare, room - gap - nameWidth))
  end
  count = math.max(0, math.floor(count))
  return math.max(0, math.floor(room - gap - count)), count
end

--- Brief Z1: the scroll thumb for count rows shown room at a time down a track height tall:
--- { tall, travel }, the thumb never shorter than minTall (a row) and travel the distance its top
--- can move. nil where every row fits. Pure.
function ZoneItems.ThumbSpan(count, room, height, minTall)
  count = math.max(0, math.floor(tonumber(count) or 0))
  room = math.max(1, math.floor(tonumber(room) or 1))
  if count <= room then
    return nil
  end
  height = math.max(1, tonumber(height) or 1)
  local tall = math.min(height, math.max(tonumber(minTall) or ZoneItems.ROW_H, height * room / count))
  return { tall = tall, travel = math.max(0, height - tall) }
end

--- Brief Z1: how far down the track the thumb's top sits at a scroll offset. Pure.
function ZoneItems.ThumbTop(span, offset, count, room)
  if type(span) ~= "table" then
    return 0
  end
  local most = math.max(1, (tonumber(count) or 0) - (tonumber(room) or 0))
  local at = math.max(0, math.min(most, tonumber(offset) or 0))
  return span.travel * at / most
end

--- Brief Z1: where a press y pixels down the track lands against a thumb whose top is top down
--- and tall long: "above", "thumb" or "below". Pure.
function ZoneItems.TrackHit(y, top, tall)
  y, top, tall = tonumber(y) or 0, tonumber(top) or 0, tonumber(tall) or 0
  if y < top then
    return "above"
  end
  if y > top + tall then
    return "below"
  end
  return "thumb"
end

--- Brief Z1: the scroll offset a thumb dragged down pixels (up where negative) from where it was
--- at startOffset gives: the rows its travel stands for, rounded to the nearest row and held
--- between the top and the last full window. Pure.
function ZoneItems.DragOffset(startOffset, down, count, room, height, minTall)
  startOffset = math.max(0, math.floor(tonumber(startOffset) or 0))
  local span = ZoneItems.ThumbSpan(count, room, height, minTall)
  if not span or span.travel <= 0 then
    return startOffset
  end
  local most = math.max(0, math.floor(tonumber(count) or 0) - math.max(1, math.floor(tonumber(room) or 1)))
  local offset = math.floor(startOffset + (tonumber(down) or 0) * most / span.travel + 0.5)
  return math.max(0, math.min(most, offset))
end

--- Brief PR37: the first of ids (group ids, in order of preference) that list (Core's
--- ViewModel.ZoneItemList) holds a group of with at least one item, or nil. Pure.
function ZoneItems.MatchGroup(list, ids)
  if type(list) ~= "table" or type(ids) ~= "table" then
    return nil
  end
  for _, wanted in ipairs(ids) do
    for _, group in ipairs(list.groups or EMPTY) do
      if group.id ~= nil and group.id == wanted and type(group.items) == "table" and group.items[1] ~= nil then
        return group.id
      end
    end
  end
  return nil
end

--- Brief PR37: the first item row of one group of list, the top row the column draws under its
--- header, or nil where the list has no such group or it is empty. Pure.
function ZoneItems.FirstOfGroup(list, groupId)
  if type(list) ~= "table" or groupId == nil then
    return nil
  end
  for _, group in ipairs(list.groups or EMPTY) do
    if group.id == groupId and type(group.items) == "table" then
      local first = group.items[1]
      return type(first) == "table" and first or nil
    end
  end
  return nil
end

--- Brief PR37: asks one zone root's next Show to open groupId with its first item picked. Answers
--- whether it was kept.
function ZoneItems.ArriveOnGroup(rootKey, groupId)
  if type(rootKey) ~= "string" or groupId == nil then
    return false
  end
  ZoneItems.groupArrivals[rootKey] = groupId
  return true
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

local function newFrame(kind, parent)
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, kind, nil, parent)
  if ok and type(frame) == "table" then
    return frame
  end
  return nil
end

local function tint(texture, key)
  local colour = Theme and type(Theme.ColorTable) == "function" and Theme.ColorTable(key) or nil
  if not colour or type(texture) ~= "table" or type(texture.SetVertexColor) ~= "function" then
    return false
  end
  texture:SetVertexColor(colour.r, colour.g, colour.b)
  if type(texture.SetAlpha) == "function" then
    texture:SetAlpha(colour.a or 1)
  end
  return true
end

local function textColour(fontString, key)
  local colour = Theme and type(Theme.ColorTable) == "function" and Theme.ColorTable(key) or nil
  if colour and type(fontString) == "table" and type(fontString.SetTextColor) == "function" then
    fontString:SetTextColor(colour.r, colour.g, colour.b, colour.a or 1)
    return true
  end
  return false
end

local function wash(parent, layer, key)
  if type(parent) ~= "table" or type(parent.CreateTexture) ~= "function" then
    return nil
  end
  local ok, texture = pcall(parent.CreateTexture, parent, nil, layer)
  if not ok or type(texture) ~= "table" then
    return nil
  end
  pcall(Assets.Apply, texture, "FILL_WHITE8X8")
  tint(texture, key)
  return texture
end

-- A font string is never left fontless: made from a client font object, and on a client that
-- refuses the Theme face, handed one of the fallbacks before anything writes to it.
local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(ZoneItems.FONT_FALLBACKS) do
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

local function newFontString(parent, fontSize, justify)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY", ZoneItems.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY")
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  local face = Theme and Theme.fonts and Theme.fonts.ITEMTREE_FONT_BODY
  if face and type(fontString.SetFont) == "function" then
    local set, applied = pcall(fontString.SetFont, fontString, face, fontSize, "")
    if not set or applied == false then
      fallbackFont(fontString)
    end
  end
  ensureFont(fontString)
  if type(fontString.SetJustifyH) == "function" then
    fontString:SetJustifyH(justify)
  end
  if type(fontString.SetWordWrap) == "function" then
    fontString:SetWordWrap(false)
  end
  if type(fontString.SetMaxLines) == "function" then
    pcall(fontString.SetMaxLines, fontString, 1)
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

local function heightOf(frame)
  if type(frame) ~= "table" or type(frame.GetHeight) ~= "function" then
    return 0
  end
  local ok, height = pcall(frame.GetHeight, frame)
  return (ok and tonumber(height)) or 0
end

local function widthOf(frame)
  if type(frame) ~= "table" or type(frame.GetWidth) ~= "function" then
    return 0
  end
  local ok, width = pcall(frame.GetWidth, frame)
  return (ok and tonumber(width)) or 0
end

local function number(frame, method)
  local fn = type(frame) == "table" and frame[method] or nil
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, frame)
  return ok and tonumber(value) or nil
end

local function fontSizeOf(key, fallback)
  local sizes = Theme and Theme.fontSizes or EMPTY
  return sizes[key] or fallback
end

-- Brief Z1: one hidden ruler per font size, in the rows' own face, for how wide a text draws with
-- nothing cutting it short. The estimate where the client answers nothing.
local function measure(text, fontSize)
  if type(text) ~= "string" or text == "" then
    return 0
  end
  ZoneItems.rulers = ZoneItems.rulers or {}
  local ruler = ZoneItems.rulers[fontSize]
  if not ruler and ZoneItems.region then
    ruler = newFontString(ZoneItems.region, fontSize, "LEFT")
    if ruler and type(ruler.Hide) == "function" then
      ruler:Hide()
    end
    ZoneItems.rulers[fontSize] = ruler
  end
  if ruler and setText(ruler, text) then
    for _, method in ipairs({ "GetUnboundedStringWidth", "GetStringWidth" }) do
      local width = number(ruler, method)
      if width and width > 0 then
        return width
      end
    end
  end
  return ZoneItems.TextWidth(text, fontSize)
end

local function viewModel()
  local ViewModel = ItemTree.ViewModel
  if type(ViewModel) ~= "table" then
    return nil
  end
  return ViewModel
end

local function treeModule()
  local ui = ItemTree.UI
  local Tree = type(ui) == "table" and ui.Tree or nil
  return type(Tree) == "table" and Tree or nil
end

-- How many rows the pane has room for.
local function capacity()
  local height = heightOf(ZoneItems.region)
  if height <= 0 then
    return 20
  end
  return math.max(1, math.floor(height / (ZoneItems.rowH or ZoneItems.ROW_H)))
end

-- Brief Q9b: the full name and the count words of a hovered item row, in the client's own tooltip.
local function showTip(row)
  local lines = ZoneItems.TipLines(rawget(row, "model"))
  local tooltip = rawget(_G, "GameTooltip")
  if not lines or type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  if not pcall(tooltip.SetOwner, tooltip, row, "ANCHOR_RIGHT") then
    return false
  end
  for _, line in ipairs(lines) do
    local colour = Theme and type(Theme.ColorTable) == "function" and Theme.ColorTable(line.colorKey) or nil
    if type(tooltip.AddLine) == "function" then
      if colour then
        pcall(tooltip.AddLine, tooltip, line.text, colour.r, colour.g, colour.b)
      else
        pcall(tooltip.AddLine, tooltip, line.text)
      end
    end
  end
  if type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  row.itemTreeTip = true
  return true
end

local function hideTip(row)
  if not rawget(row, "itemTreeTip") then
    return false
  end
  row.itemTreeTip = nil
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    pcall(tooltip.Hide, tooltip)
  end
  return true
end

local function onRowEnter(row)
  if row.hoverWash then
    row.hoverWash:Show()
  end
  showTip(row)
end

local function onRowLeave(row)
  if row.hoverWash then
    row.hoverWash:Hide()
  end
  hideTip(row)
end

local function frameModule()
  local ui = ItemTree.UI
  local Frame = type(ui) == "table" and ui.Frame or nil
  return type(Frame) == "table" and Frame or nil
end

--- Brief Z3: opens an item row's page, the same Frame.Open a Sources row re-roots with. Never
--- picks the row. Answers whether the window took the key.
function ZoneItems.OpenItem(model)
  local key = type(model) == "table" and model.kind == "item" and model.viewKey or nil
  local Frame = frameModule()
  if type(key) ~= "string" or not Frame or type(Frame.Open) ~= "function" then
    return false
  end
  local ok, opened = pcall(Frame.Open, key)
  return ok and opened ~= false
end

-- Brief BL31: the shared red plate button (UI/Frame.lua, loaded before this file). The module is
-- held at load so a stand in for the window cannot hide it, and read again where it was not there.
local plateModule = ItemTree.UI and ItemTree.UI.Frame or nil

local function plateApi()
  for _, candidate in ipairs({ plateModule, frameModule() }) do
    if type(candidate) == "table" and type(candidate.NewPlateButton) == "function" then
      return candidate
    end
  end
  return nil
end

-- Paints the eye's plate: "normal" at rest, "hover" under the pointer. The glyph shows in both.
local function paintEye(eye, state)
  local api = plateApi()
  if api and type(api.PaintPlateButton) == "function" then
    pcall(api.PaintPlateButton, eye, state)
  end
end

local function eyeRest(eye)
  paintEye(eye, "normal")
end

local function onEyeEnter(eye)
  paintEye(eye, "hover")
  local row = rawget(eye, "row")
  local text = ZoneItems.EyeTip(row and rawget(row, "model"))
  local tooltip = rawget(_G, "GameTooltip")
  if not text or type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  if not pcall(tooltip.SetOwner, tooltip, eye, "ANCHOR_RIGHT") then
    return false
  end
  if type(tooltip.SetText) == "function" then
    pcall(tooltip.SetText, tooltip, text)
  elseif type(tooltip.AddLine) == "function" then
    pcall(tooltip.AddLine, tooltip, text)
  end
  if type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  eye.itemTreeTip = true
  return true
end

local function onEyeLeave(eye)
  eyeRest(eye)
  hideTip(eye)
end

local function onEyeClick(eye)
  local row = rawget(eye, "row")
  return ZoneItems.OpenItem(row and rawget(row, "model"))
end

-- Brief Z3: the eye button, a child of the row so a press on it is the button's and never the
-- row's pick. Brief BL31: it is the Boss loot place row's red plate button with the flat eye
-- (Frame.NewPlateButton), the plate's own highlight under the pointer and the glyph always shown.
-- Brief BL30's bare eye sat at EYE_ALPHA under an OVERLAY hover wash drawn on top of it; neither
-- is left.
local function newEye(row)
  local api = plateApi()
  if not api then
    return nil
  end
  local layout = ZoneItems.EyeLayout(ZoneItems.density)
  local ok, eye = pcall(api.NewPlateButton, row, ZoneItems.EYE_ASSET, ZoneItems.EYE_FALLBACK, layout.size)
  if not ok or type(eye) ~= "table" then
    return nil
  end
  eye.row = row
  if type(eye.EnableMouse) == "function" then
    eye:EnableMouse(true)
  end
  eyeRest(eye)
  eye:SetScript("OnEnter", onEyeEnter)
  eye:SetScript("OnLeave", onEyeLeave)
  eye:SetScript("OnClick", onEyeClick)
  eye:Hide()
  return eye
end

local function onRowClick(row)
  local model = type(row) == "table" and rawget(row, "model") or nil
  if type(model) ~= "table" then
    return false
  end
  if model.kind == "category" then
    return ZoneItems.Toggle(model.id)
  end
  return ZoneItems.Pick(model.key)
end

local function newRow(index)
  local region = ZoneItems.region
  local row = newFrame("Button", region)
  if not row then
    return nil
  end
  row:SetHeight(ZoneItems.rowH or ZoneItems.ROW_H)
  if type(row.EnableMouse) == "function" then
    row:EnableMouse(true)
  end
  if type(row.RegisterForClicks) == "function" then
    pcall(row.RegisterForClicks, row, "LeftButtonUp")
  end
  row.selectedWash = wash(row, "BACKGROUND", ZoneItems.COLOR_SELECTED)
  if row.selectedWash then
    row.selectedWash:SetAllPoints(row)
    row.selectedWash:Hide()
  end
  row.selectedEdge = wash(row, "BORDER", ZoneItems.COLOR_EDGE)
  if row.selectedEdge then
    row.selectedEdge:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.selectedEdge:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.selectedEdge:SetWidth(ZoneItems.EDGE_W * 2)
    row.selectedEdge:Hide()
  end
  row.hoverWash = wash(row, "BACKGROUND", ZoneItems.COLOR_HOVER)
  if row.hoverWash then
    row.hoverWash:SetAllPoints(row)
    row.hoverWash:Hide()
  end
  if type(row.CreateTexture) == "function" then
    row.chevron = row:CreateTexture(nil, "ARTWORK")
    row.icon = row:CreateTexture(nil, "ARTWORK")
  end
  local fontSizes = Theme and Theme.fontSizes or EMPTY
  row.label = newFontString(row, fontSizes.ITEMTREE_FONTSIZE_BODY_MD or 12, "LEFT")
  row.count = newFontString(row, fontSizes.ITEMTREE_FONTSIZE_BODY_SM or 11, "RIGHT")
  if row.count then
    row.count:SetPoint("RIGHT", row, "RIGHT", -ZoneItems.GUTTER - ZoneItems.THUMB_W, 0)
    row.count:SetWidth(ZoneItems.countW or ZoneItems.COUNT_W)
  end
  row.eye = newEye(row)
  row:SetScript("OnEnter", onRowEnter)
  row:SetScript("OnLeave", onRowLeave)
  row:SetScript("OnClick", onRowClick)
  ZoneItems.rows[index] = row
  return row
end

-- Brief Z1: the count column's width in one row: the room between the name's left edge and the
-- count's right edge split by ZoneItems.SplitWidths over both texts measured. The list's measured
-- column where the row's width is not known yet.
local function countWidthFor(model, left, layout, showsEye)
  local column = ZoneItems.countW or ZoneItems.COUNT_W
  local rowW = ZoneItems.rowW
  if type(rowW) ~= "number" or rowW <= 0 then
    return column
  end
  local right = layout.right
  if showsEye then
    right = right + layout.size + layout.gap
  end
  local countText = measure(model.countText, fontSizeOf("ITEMTREE_FONTSIZE_BODY_SM", 11))
  local nameText = measure(ZoneItems.LabelText(model), fontSizeOf("ITEMTREE_FONTSIZE_BODY_MD", 12))
  local _, width = ZoneItems.SplitWidths(rowW - left - right, nameText, math.min(column, countText), ZoneItems.GUTTER)
  return math.max(1, width)
end

-- Draws one model into one pooled row at one place down the pane.
local function drawRow(row, model, slot)
  local region = ZoneItems.region
  local rowH = ZoneItems.rowH or ZoneItems.ROW_H
  row.model = model
  row:ClearAllPoints()
  row:SetHeight(rowH)
  row:SetPoint("TOPLEFT", region, "TOPLEFT", ZoneItems.EDGE_W, -((slot - 1) * rowH + ZoneItems.EDGE_W))
  row:SetPoint("TOPRIGHT", region, "TOPRIGHT", -ZoneItems.EDGE_W, -((slot - 1) * rowH + ZoneItems.EDGE_W))
  -- Brief Z3: an item row's eye button at the right edge, the count column moved left of it by
  -- the button and its gap. A header has none and its count keeps the edge.
  local layout = ZoneItems.EyeLayout(ZoneItems.density)
  local eye = row.eye
  local showsEye = eye ~= nil and model.kind == "item" and model.viewKey ~= nil
  if eye then
    eye:ClearAllPoints()
    if showsEye then
      local api = plateApi()
      if api and type(api.SizePlateButton) == "function" then
        pcall(api.SizePlateButton, eye, layout.size)
      else
        eye:SetSize(layout.size, layout.size)
      end
      eye:SetPoint("RIGHT", row, "RIGHT", -layout.right, 0)
      eyeRest(eye)
      eye:Show()
    else
      hideTip(eye)
      eye:Hide()
    end
  end
  if row.count then
    row.count:ClearAllPoints()
    if showsEye then
      row.count:SetPoint("RIGHT", eye, "LEFT", -layout.gap, 0)
    else
      row.count:SetPoint("RIGHT", row, "RIGHT", -layout.right, 0)
    end
  end
  local left = ZoneItems.GUTTER + (model.indent or 0)
  if row.chevron then
    row.chevron:ClearAllPoints()
    if model.chevronAsset then
      row.chevron:SetSize(ZoneItems.CHEVRON, ZoneItems.CHEVRON)
      row.chevron:SetPoint("LEFT", row, "LEFT", left, 0)
      pcall(Assets.Apply, row.chevron, model.chevronAsset)
      tint(row.chevron, ZoneItems.COLOR_MUTED)
      row.chevron:Show()
      left = left + ZoneItems.CHEVRON + ZoneItems.GUTTER
    else
      row.chevron:Hide()
    end
  end
  if row.icon then
    row.icon:ClearAllPoints()
    row.icon:SetSize(ZoneItems.ICON, ZoneItems.ICON)
    row.icon:SetPoint("LEFT", row, "LEFT", left, 0)
    if model.iconFile ~= nil and type(row.icon.SetTexture) == "function" then
      pcall(row.icon.SetTexture, row.icon, model.iconFile)
    elseif model.iconAsset then
      pcall(Assets.Apply, row.icon, model.iconAsset)
    end
    if type(row.icon.SetVertexColor) == "function" then
      row.icon:SetVertexColor(1, 1, 1)
    end
    row.icon:Show()
    left = left + ZoneItems.ICON + ZoneItems.GUTTER
  end
  if row.label then
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row, "LEFT", left, 0)
    if row.count then
      row.label:SetPoint("RIGHT", row.count, "LEFT", -ZoneItems.GUTTER, 0)
    end
    setText(row.label, ZoneItems.LabelText(model))
    textColour(row.label, model.colorKey)
  end
  if row.count then
    -- Brief Q9b: never wider than the column this build of the list measured. Brief Z1: and where
    -- the row is narrow, only what the name leaves it (ZoneItems.SplitWidths). Set on every draw of
    -- a pooled row.
    if type(row.count.SetWidth) == "function" then
      row.count:SetWidth(countWidthFor(model, left, layout, showsEye))
    end
    setText(row.count, model.countText)
    textColour(row.count, model.countColor)
  end
  if row.selectedWash then
    if model.selected then
      row.selectedWash:Show()
    else
      row.selectedWash:Hide()
    end
  end
  if row.selectedEdge then
    if model.selected then
      row.selectedEdge:Show()
    else
      row.selectedEdge:Hide()
    end
  end
  row:Show()
  return true
end

-- Brief Z1: the thumb's drag, the shape UI/Chain.lua pans its canvas with: a press on the thumb
-- keeps where the cursor and the list were, an OnUpdate on our own track frame follows the cursor
-- while the button is held, and the release (or the track hiding) lets go.
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
  local scale = number(frame, "GetEffectiveScale") or 1
  if scale <= 0 then
    scale = 1
  end
  return y / scale
end

local function trackScript(track, script, handler)
  if type(track) == "table" and type(track.SetScript) == "function" then
    return (pcall(track.SetScript, track, script, handler))
  end
  return false
end

local function stopDrag()
  ZoneItems.drag = nil
  trackScript(ZoneItems.track, "OnUpdate", nil)
  return true
end

local function trackHeight()
  return math.max(1, heightOf(ZoneItems.region) - 2 * ZoneItems.EDGE_W)
end

local function onDragUpdate(track)
  local drag = ZoneItems.drag
  if not drag or not ZoneItems.shown then
    return stopDrag()
  end
  local y = cursorY(track)
  if not y then
    return false
  end
  -- Screen y runs up and the list runs down, so a drag down is the start less where it is now.
  local offset =
    ZoneItems.DragOffset(drag.offset, drag.y - y, ZoneItems.drawnCount, ZoneItems.room, trackHeight(), ZoneItems.rowH)
  if offset == ZoneItems.offset then
    return false
  end
  ZoneItems.offset = offset
  return ZoneItems.Draw()
end

--- Brief Z1: a press on the track: on the thumb it starts a drag, above or below it the list moves
--- a page that way. Only the left button.
function ZoneItems.TrackPress(track, button)
  if button ~= nil and button ~= "LeftButton" then
    return false
  end
  if not ZoneItems.thumbShown then
    return false
  end
  local y = cursorY(track)
  local top = number(track, "GetTop")
  local where = "thumb"
  if y and top then
    where = ZoneItems.TrackHit(top - y, ZoneItems.thumbTop, ZoneItems.thumbTall)
  end
  if where == "above" then
    return ZoneItems.Scroll(-(ZoneItems.room or 1))
  end
  if where == "below" then
    return ZoneItems.Scroll(ZoneItems.room or 1)
  end
  if not y then
    return false
  end
  ZoneItems.drag = { y = y, offset = ZoneItems.offset or 0 }
  trackScript(track, "OnUpdate", onDragUpdate)
  return true
end

-- Brief Z1: our own frame down the pane's right hand edge, as wide as the room the rows leave
-- there, raised over the rows so it takes the press. It carries the thumb and the wheel too.
local function buildTrack(region)
  local track = newFrame("Frame", region)
  if not track then
    return nil
  end
  track:SetPoint("TOPRIGHT", region, "TOPRIGHT", -ZoneItems.EDGE_W, -ZoneItems.EDGE_W)
  track:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -ZoneItems.EDGE_W, ZoneItems.EDGE_W)
  track:SetWidth(ZoneItems.GRAB_W)
  local level = number(region, "GetFrameLevel")
  if level and type(track.SetFrameLevel) == "function" then
    pcall(track.SetFrameLevel, track, level + ZoneItems.TRACK_LEVEL)
  end
  if type(track.EnableMouse) == "function" then
    pcall(track.EnableMouse, track, true)
  end
  if type(track.EnableMouseWheel) == "function" then
    pcall(track.EnableMouseWheel, track, true)
  end
  trackScript(track, "OnMouseDown", ZoneItems.TrackPress)
  trackScript(track, "OnMouseUp", stopDrag)
  trackScript(track, "OnHide", stopDrag)
  trackScript(track, "OnMouseWheel", function(_, delta)
    ZoneItems.Scroll(-(tonumber(delta) or 0) * ZoneItems.WHEEL_STEP)
  end)
  track:Hide()
  return track
end

-- The pane's own surface, border and scroll thumb, built once per region.
local function build(region)
  if ZoneItems.region == region and ZoneItems.built then
    return true
  end
  if type(region) ~= "table" or type(region.CreateTexture) ~= "function" then
    return false
  end
  ZoneItems.region = region
  ZoneItems.rows = {}
  ZoneItems.offset = 0
  local surface = wash(region, "BACKGROUND", ZoneItems.SURFACE)
  if surface then
    surface:SetAllPoints(region)
    surface:Show()
  end
  local edges = {}
  for index = 1, 4 do
    local line = wash(region, "BORDER", ZoneItems.BORDER)
    if line then
      edges[index] = line
      line:Show()
    end
  end
  if edges[1] and edges[2] and edges[3] and edges[4] then
    edges[1]:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
    edges[1]:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, 0)
    edges[1]:SetHeight(ZoneItems.EDGE_W)
    edges[2]:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, 0)
    edges[2]:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, 0)
    edges[2]:SetHeight(ZoneItems.EDGE_W)
    edges[3]:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
    edges[3]:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, 0)
    edges[3]:SetWidth(ZoneItems.EDGE_W)
    edges[4]:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, 0)
    edges[4]:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, 0)
    edges[4]:SetWidth(ZoneItems.EDGE_W)
  end
  -- Brief Z1: the grab strip the thumb is drawn in, over the rows, so a press on it is the
  -- scrollbar's. A client that makes no frame keeps the thumb on the pane, to read only.
  ZoneItems.track = buildTrack(region)
  ZoneItems.thumb = wash(ZoneItems.track or region, "ARTWORK", ZoneItems.COLOR_THUMB)
  if ZoneItems.thumb then
    ZoneItems.thumb:SetWidth(ZoneItems.THUMB_W)
    ZoneItems.thumb:Hide()
  end
  if type(region.EnableMouseWheel) == "function" then
    pcall(region.EnableMouseWheel, region, true)
  end
  if type(region.SetScript) == "function" then
    pcall(region.SetScript, region, "OnMouseWheel", function(_, delta)
      ZoneItems.Scroll(-(tonumber(delta) or 0) * ZoneItems.WHEEL_STEP)
    end)
    pcall(region.SetScript, region, "OnSizeChanged", function()
      if ZoneItems.shown then
        ZoneItems.Draw()
      end
    end)
  end
  ZoneItems.built = true
  return true
end

-- The thumb down the right hand edge that says where in a long list the pane is. Brief Z1: the
-- wheel scrolls it, and the thumb can be dragged and the track pressed (ZoneItems.TrackPress).
local function drawThumb(count, first, room)
  local thumb = ZoneItems.thumb
  local track = ZoneItems.track
  ZoneItems.drawnCount, ZoneItems.room = count, room
  local span = ZoneItems.ThumbSpan(count, room, trackHeight(), ZoneItems.rowH or ZoneItems.ROW_H)
  ZoneItems.thumbShown = false
  if not thumb then
    return false
  end
  if not span then
    thumb:Hide()
    if track then
      stopDrag()
      track:Hide()
    end
    return false
  end
  local top = ZoneItems.ThumbTop(span, first - 1, count, room)
  ZoneItems.thumbTop, ZoneItems.thumbTall = top, span.tall
  thumb:ClearAllPoints()
  thumb:SetPoint("TOPRIGHT", ZoneItems.region, "TOPRIGHT", -ZoneItems.EDGE_W, -(ZoneItems.EDGE_W + top))
  thumb:SetHeight(span.tall)
  thumb:Show()
  if track then
    track:Show()
  end
  ZoneItems.thumbShown = true
  return true
end

-- Brief Q9b: the count column's width for the list just built, measured once: every distinct count
-- text through one hidden ruler in the rows' own face, and the estimate where the client answers
-- nothing. The list is Core's, so this runs once per ZoneItems.Show and never per draw.
local function measureCounts()
  local ViewModel = viewModel()
  if not ViewModel or type(ViewModel.ZoneItemRows) ~= "function" or not ZoneItems.list then
    return ZoneItems.COUNT_W
  end
  local ok, rows = pcall(ViewModel.ZoneItemRows, ZoneItems.list, "", nil)
  if not ok or type(rows) ~= "table" then
    return ZoneItems.COUNT_W
  end
  local fontSize = fontSizeOf("ITEMTREE_FONTSIZE_BODY_SM", 11)
  local widths = {}
  for _, text in ipairs(ZoneItems.CountTexts(rows)) do
    widths[#widths + 1] = measure(text, fontSize)
  end
  return ZoneItems.CountWidth(widths)
end

-- The search text the tree pane's box holds, which is the box this column is filtered by.
local function searchText()
  local Tree = treeModule()
  local text = Tree and Tree.searchText or nil
  return type(text) == "string" and text or ""
end

-- The box's keystrokes redraw this column too while it is up. Hooked once per box: the pane's own
-- handler stays, and this only reads the words back.
local function hookSearch()
  local Tree = treeModule()
  local box = Tree and Tree.search or nil
  if type(box) ~= "table" or rawget(box, "itemTreeZoneHooked") then
    return false
  end
  if type(box.HasScript) == "function" then
    local ok, has = pcall(box.HasScript, box, "OnTextChanged")
    if ok and has == false then
      return false
    end
  end
  local handler = function(self)
    if not ZoneItems.shown then
      return
    end
    local text = type(self.GetText) == "function" and self:GetText() or ""
    ZoneItems.SetSearch(type(text) == "string" and text or "")
  end
  local hooked = type(box.HookScript) == "function" and pcall(box.HookScript, box, "OnTextChanged", handler)
  if hooked then
    box.itemTreeZoneHooked = true
  end
  return hooked and true or false
end

--- Draws the rows the list, the search and the closed groups leave, from the current offset.
function ZoneItems.Draw()
  if not ZoneItems.region or not ZoneItems.rows then
    return false
  end
  local ViewModel = viewModel()
  local rows = {}
  if ViewModel and type(ViewModel.ZoneItemRows) == "function" and ZoneItems.list then
    local closed = ZoneItems.ClosedGroups(ZoneItems.list, ZoneItems.collapsed[ZoneItems.root], ZoneItems.search)
    rows = ViewModel.ZoneItemRows(ZoneItems.list, ZoneItems.search, closed)
  end
  ZoneItems.drawn = rows
  -- The Compact rows setting, read on every draw so the footer's box takes effect on the next one.
  ZoneItems.density = ZoneItems.Density()
  ZoneItems.rowH = ZoneItems.RowHeight(ZoneItems.density)
  -- Brief Z1: how wide every row is, which is the pane less its two edges, read once per draw.
  ZoneItems.rowW = widthOf(ZoneItems.region) - 2 * ZoneItems.EDGE_W
  local room = capacity()
  if ZoneItems.follow then
    ZoneItems.offset = ZoneItems.OffsetFor(rows, ZoneItems.selected, ZoneItems.offset, room)
    ZoneItems.follow = false
  end
  local first, last, offset = ZoneItems.Window(#rows, ZoneItems.offset, room)
  ZoneItems.offset = offset
  local slot = 0
  for index = first, last do
    local model = ZoneItems.RowModel(rows[index], ZoneItems.selected)
    if model then
      slot = slot + 1
      local row = ZoneItems.rows[slot] or newRow(slot)
      if row then
        drawRow(row, model, slot)
      end
    end
  end
  for index = slot + 1, #ZoneItems.rows do
    ZoneItems.rows[index]:Hide()
    ZoneItems.rows[index].model = nil
  end
  drawThumb(#rows, first, room)
  return true
end

--- The wheel: moves the list by step rows and redraws.
function ZoneItems.Scroll(step)
  ZoneItems.offset = (ZoneItems.offset or 0) + (tonumber(step) or 0)
  return ZoneItems.Draw()
end

--- A keystroke in the search box: the list is filtered by it from the top.
function ZoneItems.SetSearch(text)
  text = type(text) == "string" and text or ""
  if text == ZoneItems.search then
    return false
  end
  ZoneItems.search = text
  ZoneItems.offset = 0
  ZoneItems.Draw()
  return true
end

--- Opens or closes one group. The player's for this zone, for the session. Brief Z2 (2026-09-30):
--- a group nobody has opened is closed, so the first press opens it.
function ZoneItems.Toggle(groupId)
  local root = ZoneItems.root
  if root == nil or groupId == nil then
    return false
  end
  local set = ZoneItems.collapsed[root] or {}
  ZoneItems.collapsed[root] = set
  if set[groupId] == false then
    set[groupId] = true
  else
    set[groupId] = false
  end
  ZoneItems.Draw()
  return true
end

--- Brief Z2 (2026-09-30): opens one group of one zone's column without drawing, for a pick the
--- column did not make itself.
function ZoneItems.OpenGroup(rootKey, groupId)
  if rootKey == nil or groupId == nil then
    return false
  end
  local set = ZoneItems.collapsed[rootKey] or {}
  ZoneItems.collapsed[rootKey] = set
  set[groupId] = false
  return true
end

--- Picks one item row: Core keeps the pick, the row takes the highlight and the map beside it is
--- drawn again with that item's pins. The one click costs one pin decode per named source.
function ZoneItems.Pick(key)
  local ViewModel = viewModel()
  local root = ZoneItems.root
  if not ViewModel or type(ViewModel.PickZoneItem) ~= "function" or root == nil then
    return false
  end
  local ok, kept = pcall(ViewModel.PickZoneItem, root, key)
  if not ok or not kept then
    return false
  end
  ZoneItems.selected = key
  ZoneItems.shownPicks[root] = key
  -- Brief G1: the redraw a pick starts runs under the window's boundary.
  local frame = ItemTree.UI and ItemTree.UI.Frame
  if type(frame) == "table" and type(frame.GuardedRun) == "function" then
    return (frame.GuardedRun("ZoneItems.Pick", ZoneItems.DrawPick, root))
  end
  ZoneItems.DrawPick(root)
  return true
end

--- The column and the map beside it, drawn again for a pick (ZoneItems.Pick).
function ZoneItems.DrawPick(root)
  ZoneItems.Draw()
  local Tree = treeModule()
  if Tree and type(Tree.ShowMap) == "function" and ZoneItems.mapRegion then
    Tree.ShowMap(ZoneItems.mapRegion, root)
  end
  return true
end

--- Draws the column for one zone root into the region the window hands over: builds (or reads the
--- kept) item list, settles which row is picked, and draws. fromKey is the page the player came from,
--- which is the arrival pick; mapRegion is the map beside it, drawn again on a pick.
function ZoneItems.Show(region, rootKey, opts, fromKey, mapRegion)
  if type(region) ~= "table" or type(rootKey) ~= "string" then
    return false
  end
  local ViewModel = viewModel()
  if not ViewModel or type(ViewModel.ZoneItemList) ~= "function" then
    return false
  end
  if not build(region) then
    return false
  end
  if ZoneItems.root ~= rootKey then
    ZoneItems.offset = 0
  end
  ZoneItems.root = rootKey
  ZoneItems.mapRegion = mapRegion
  local ok, list = pcall(ViewModel.ZoneItemList, rootKey, opts)
  local built = ok and type(list) == "table" and list or nil
  if built ~= ZoneItems.list or not ZoneItems.countW then
    ZoneItems.list = built
    ZoneItems.countW = measureCounts()
  end
  -- Brief PR37: a gathering line's zone opens on its group, the group's first item picked, once.
  local groupArrival = ZoneItems.groupArrivals[rootKey]
  ZoneItems.groupArrivals[rootKey] = nil
  local chosen = ZoneItems.FirstOfGroup(built, groupArrival)
  local arriving
  if chosen and type(ViewModel.PickZoneItem) == "function" then
    local kept, held = pcall(ViewModel.PickZoneItem, rootKey, chosen.key)
    if not kept or not held then
      chosen = nil
    end
  else
    chosen = nil
  end
  if chosen then
    arriving = true
    -- Held as an arrival from the page the player came from, so a redraw keeps it.
    local picks = type(ViewModel.zoneItemPicks) == "table" and ViewModel.zoneItemPicks or EMPTY
    local held = picks[rootKey]
    if type(held) == "table" and held.key == chosen.key then
      held.from = fromKey
    end
  else
    -- Brief M15: an item a Sources row asked this zone to open on opens its group even where it
    -- was the pick shown last time.
    local arrivals = type(ViewModel.zoneItemArrivals) == "table" and ViewModel.zoneItemArrivals or EMPTY
    arriving = arrivals[rootKey] ~= nil
    local picked, entry = pcall(ViewModel.ZoneItemPick, rootKey, opts, fromKey)
    chosen = picked and type(entry) == "table" and entry or nil
  end
  ZoneItems.selected = chosen and chosen.key or nil
  -- Brief Z2 (2026-09-30): the item the player came from (or the source they picked on the Here
  -- tab) opens its own group; a pick the player made here leaves the groups as they left them.
  if chosen and (arriving or ZoneItems.shownPicks[rootKey] ~= chosen.key) then
    ZoneItems.OpenGroup(rootKey, chosen.group)
  end
  ZoneItems.shownPicks[rootKey] = ZoneItems.selected
  ZoneItems.search = searchText()
  ZoneItems.follow = true
  hookSearch()
  ZoneItems.shown = true
  if type(region.Show) == "function" then
    region:Show()
  end
  return ZoneItems.Draw()
end

--- Hides the column. The list and the pick stay with Core for the next time the Map view is up.
function ZoneItems.Hide()
  ZoneItems.shown = false
  stopDrag()
  local region = ZoneItems.region
  if type(region) == "table" and type(region.Hide) == "function" then
    region:Hide()
  end
  return true
end

return ZoneItems
