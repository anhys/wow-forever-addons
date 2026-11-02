-- The History overlay: recently viewed and pinned pages, raised over the window. Brief SR1: a row
-- is any page the window opened (an item, a creature, a quest, a zone, a node, a set), by its node
-- key, and a page that is not an item says its kind in a muted column beside its name.
--
-- History is not a tab. The rewind button in the title bar calls ItemTree.UI.History.Toggle(frame)
-- with the window as its argument, and this file raises a modal over the window body: a scrim that
-- takes the mouse so nothing under it can be clicked, and a centred dialog on top of it. Closing
-- the window closes the overlay, because UI/Frame.lua's Hide calls ours.
--
-- Note the two names. ItemTree.History (Core/History.lua) is the model. ItemTree.UI.History, this
-- file, is the pane that draws it.
--
-- Design: harness/src/render-panes.tsx HistoryModal, over design/components/tree/HistoryList.jsx,
-- drawn on DialogFrame the way the design's own overlays are
-- (design/ui_kits/itemtree_addon/ScreensOther.jsx).
--
-- Anatomy (Theme.sizes):
--   ITEMTREE_LIST_ROW_H 22 item rows, ITEMTREE_LIST_CATEGORY_H 24 for the Pinned and Recent sub
--   group headers, ITEMTREE_LIST_ICON 20 item icon, ITEMTREE_ICON_TOGGLE 12 pin toggle,
--   ITEMTREE_CONTROL_H_SM 20 for the Clear history button, ITEMTREE_SCROLLBAR_W 16 for the bar,
--   ITEMTREE_LIST_COL_COUNT 36 for the ago column.
--   The dialog is the design's own 420 by 320, centred on the window body.
--
-- Data: ItemTree.History owns ItemTree.db.history and is the only module that writes it.
-- History.Items(now) returns { key, kind, id, name, quality, icon, asset, kindText, pinned, ago }
-- (id an item's alone) with the pins first in pin
-- order and then recent newest first, History.Toggle pins and unpins, and History.Clear empties
-- recent and keeps the pins. This file never touches the saved variable itself, and it never opens
-- a second window: a row re-roots the one window through ItemTree.UI.Frame.Open.
--
-- Escape: the window is in UISpecialFrames, and the client's CloseSpecialWindows hides every shown
-- frame in that list, so registering the overlay there as well would close both at once. The scrim
-- takes the keyboard instead and eats Escape: OnKeyDown calls SetPropagateKeyboardInput(false) for
-- that one key and hides the overlay, so the client never sees the keystroke, and propagates every
-- other key so no binding is swallowed while the overlay is up. The keyboard is handed back with
-- EnableKeyboard(false) the moment the overlay hides, which is what lets Escape close the window
-- again.
--
-- Client APIs: ScrollBox with CreateScrollBoxListLinearView plus CreateDataProvider over
-- History.Items(time()), with a plain frame pool where the client carries no ScrollBox;
-- UIPanelCloseButton for the dialog's close button, behind a pcall with a plain button as the
-- fallback; GameTooltip:SetItemByID for the row tooltips; Assets.Apply for every texture.
--
-- Contract with the window (UI/Frame.lua owns both):
--   Toggle(frame) raises the overlay over that window, or hides it when it is already up.
--   Show(frame), Hide(), IsShown(), Refresh(), Init(). All idempotent, all no ops with no client.
--
-- UIHistory.Rows, UIHistory.RowModel, UIHistory.HeaderRow, UIHistory.RowHeight,
-- UIHistory.Interpret, UIHistory.FooterText, UIHistory.CanClear, UIHistory.ListHeight,
-- UIHistory.Overflows and UIHistory.BodyInsets are pure and run under busted. Everything that
-- touches a frame is guarded, so this file loads with no WoW API present.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local UIHistory = {}
ItemTree.UI.History = UIHistory

local Theme = ItemTree.Theme
local Assets = ItemTree.Assets
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

-- Theme loads before this file, but every size is read through a fallback anyway so the module
-- still loads if it is ever asked for on its own.
local size = Theme.Size

UIHistory.ROW_H = size("ITEMTREE_LIST_ROW_H", 22)
UIHistory.HEADER_H = size("ITEMTREE_LIST_CATEGORY_H", 24)
UIHistory.ICON_SIZE = size("ITEMTREE_LIST_ICON", 20)
UIHistory.TOGGLE_SIZE = size("ITEMTREE_ICON_TOGGLE", 12)
UIHistory.BUTTON_H = size("ITEMTREE_CONTROL_H_SM", 20)
UIHistory.SCROLLBAR_W = size("ITEMTREE_SCROLLBAR_W", 16)
UIHistory.EDGE_W = size("ITEMTREE_BORDER_HAIRLINE", 1)
UIHistory.GUTTER = size("ITEMTREE_LIST_GUTTER", 6)
UIHistory.PAD = size("ITEMTREE_SPACE_2", 8)
UIHistory.AGO_W = size("ITEMTREE_LIST_COL_COUNT", 36)
-- Brief SR1: the kind word column of a page that is not an item, wide enough for "Fishing pool" at
-- the small body size.
UIHistory.KIND_W = 72

-- The window's own anatomy, so the scrim covers the body and leaves the title bar alone. The
-- window states it through Frame.BodyInsets; these are the fallback for a Frame that does not
-- carry it, which is a harness or a spec that loaded this file on its own. The border and the
-- title bar are Theme's, and the 6px the title bar sits in from the top of the frame art is
-- UI/Frame.lua's own number (layout().titleTop).
UIHistory.BORDER = size("ITEMTREE_FRAME_BORDER", 16)
UIHistory.TITLE_BAR = size("ITEMTREE_CHROME_TITLEBAR_H", 28)
UIHistory.TITLE_TOP = 6

-- What the scrim is measured in by, from the window where it states them. Each side is taken
-- on its own, so a Frame that answers with a part of the shape still moves the scrim by it.
--
-- The window states two shapes. Frame.BodyInsets is its inner edge, and the top tab band sits
-- above that, in the grey chrome: a scrim anchored to the body starts under the tabs and leaves
-- them, the toggles and the search box uncovered, with the top of the tabs poking out above the
-- modal. Frame.OverlayInsets is the same shape with the band included, so that is asked for
-- first; a window that carries only the body is still answered from.
function UIHistory.BodyInsets()
  local fallback = {
    left = UIHistory.BORDER,
    right = UIHistory.BORDER,
    top = UIHistory.TITLE_TOP + UIHistory.TITLE_BAR,
    bottom = UIHistory.BORDER,
  }
  local Frame = ItemTree.UI and ItemTree.UI.Frame
  if type(Frame) ~= "table" then
    return fallback
  end
  local ask = Frame.OverlayInsets
  if type(ask) ~= "function" then
    ask = Frame.BodyInsets
  end
  if type(ask) ~= "function" then
    return fallback
  end
  local ok, insets = pcall(ask)
  if not ok or type(insets) ~= "table" then
    return fallback
  end
  for _, side in ipairs({ "left", "right", "top", "bottom" }) do
    local value = tonumber(insets[side])
    if value then
      fallback[side] = value
    end
  end
  return fallback
end

-- The dialog, at the size HistoryModal draws it, and its own header and footer rows.
UIHistory.DIALOG_W = 420
UIHistory.DIALOG_H = 320
UIHistory.HEADER_ROW_H = size("ITEMTREE_CONTROL_H_MD", 24)
UIHistory.FOOTER_ROW_H = UIHistory.BUTTON_H + size("ITEMTREE_SPACE_1", 4)

-- The scrim is the frame surface at 70 percent, which is the design's rgba(5,4,3,0.7) over the
-- body. Dark enough that the panes read as out of reach, light enough to still see them.
UIHistory.SCRIM_ALPHA = 0.7

-- The ScrollBox builds rows from a real XML template and the addon ships no XML, so the rows are
-- BackdropTemplate frames with the mouse enabled by hand, the way UI/Sidebar.lua does it.
UIHistory.ROW_TEMPLATE = "BackdropTemplate"
UIHistory.CLOSE_TEMPLATE = "UIPanelCloseButton"

-- A font string made with the two argument CreateFontString has no font at all, and the next
-- SetText raises inside the client ("FontString:SetText(): Font not set"). The template is
-- asked for at creation where the client takes one, and the rest are what a client that
-- refused the template is offered instead. Same list and same rule as UI/Sidebar.lua.
UIHistory.FONT_TEMPLATE = "GameFontNormalSmall"
UIHistory.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }

UIHistory.KIND_HEADER = "header"
UIHistory.KIND_ITEM = "item"
UIHistory.GROUP_PINNED = "pinned"
UIHistory.GROUP_RECENT = "recent"

-- What a click asks for, and the part of a row it was made on.
UIHistory.REGION_ROW = "row"
UIHistory.REGION_PIN = "pin"
UIHistory.ACTION_OPEN = "open"
UIHistory.ACTION_PIN = "pin"
UIHistory.ACTION_NONE = "none"

-- How tall a row model draws. Pure.
function UIHistory.RowHeight(model)
  if type(model) == "table" and model.kind == UIHistory.KIND_HEADER then
    return UIHistory.HEADER_H
  end
  return UIHistory.ROW_H
end

-- One sub group header. The design gives the group its own 24px row over the rows in it. Pure.
function UIHistory.HeaderRow(group)
  local label = (group == UIHistory.GROUP_PINNED) and L["Pinned"] or L["Recent"]
  return {
    kind = UIHistory.KIND_HEADER,
    group = group,
    label = label,
    name = label,
    height = UIHistory.HEADER_H,
  }
end

-- One page row, from one entry of History.Items(now). An entry with neither an item id nor a node
-- key is not a row: it has nothing to open or pin. An item row keeps its id; any other page keeps
-- its key, its kind word (kindText) and the Assets glyph its rows wear in the tree (asset). The
-- row's kind stays KIND_ITEM for every page, because it is the row the list draws, as against a
-- header. Pure.
function UIHistory.RowModel(item, group)
  if type(item) ~= "table" then
    return nil
  end
  local id = tonumber(item.id)
  local key = type(item.key) == "string" and item.key ~= "" and item.key or nil
  if not id and not key then
    return nil
  end
  if id and not key then
    key = "item:" .. tostring(id)
  end
  local ago = type(item.ago) == "string" and item.ago or nil
  local kindText = nil
  if not id and type(item.kindText) == "string" and item.kindText ~= "" then
    kindText = item.kindText
  end
  return {
    kind = UIHistory.KIND_ITEM,
    group = group or (item.pinned and UIHistory.GROUP_PINNED or UIHistory.GROUP_RECENT),
    id = id,
    key = key,
    kindText = kindText,
    asset = not id and type(item.asset) == "string" and item.asset or nil,
    name = tostring(item.name or ""),
    quality = tonumber(item.quality),
    icon = item.icon,
    pinned = item.pinned and true or false,
    ago = ago,
    -- A pinned item that was never viewed has no elapsed time, and the column stays empty rather
    -- than guessing one.
    agoText = ago or "",
    height = UIHistory.ROW_H,
  }
end

-- Every row the list draws: the Pinned header and the pinned rows, then the Recent header and the
-- recent rows. The headers only appear once something is pinned, which is what HistoryList does:
-- with no pins there is one group and nothing to tell apart. The order inside each group is the
-- model's own, so pins stay in pin order and recent stays newest first. Pure.
function UIHistory.Rows(items)
  local pinnedRows, recentRows = {}, {}
  for _, item in ipairs(items or EMPTY) do
    local isPinned = type(item) == "table" and item.pinned and true or false
    local group = isPinned and UIHistory.GROUP_PINNED or UIHistory.GROUP_RECENT
    local model = UIHistory.RowModel(item, group)
    if model then
      local bucket = isPinned and pinnedRows or recentRows
      bucket[#bucket + 1] = model
    end
  end

  local rows = {}
  if #pinnedRows > 0 then
    rows[#rows + 1] = UIHistory.HeaderRow(UIHistory.GROUP_PINNED)
  end
  for _, model in ipairs(pinnedRows) do
    rows[#rows + 1] = model
  end
  if #pinnedRows > 0 and #recentRows > 0 then
    rows[#rows + 1] = UIHistory.HeaderRow(UIHistory.GROUP_RECENT)
  end
  for _, model in ipairs(recentRows) do
    rows[#rows + 1] = model
  end
  return rows
end

-- What a click on this part of this row asks for: "open" re-roots the window on the page, "pin"
-- toggles the pin and leaves the overlay up, "none" is a header or anything without an id or a
-- key. The item id (or, for any other page, its node key) comes back with it so the caller never
-- has to read the model again. Pure.
function UIHistory.Interpret(rowModel, region)
  if type(rowModel) ~= "table" or rowModel.kind ~= UIHistory.KIND_ITEM then
    return UIHistory.ACTION_NONE, nil
  end
  local id = tonumber(rowModel.id)
  if not id and type(rowModel.key) == "string" and rowModel.key ~= "" then
    id = rowModel.key
  end
  if not id then
    return UIHistory.ACTION_NONE, nil
  end
  if region == UIHistory.REGION_PIN then
    return UIHistory.ACTION_PIN, id
  end
  return UIHistory.ACTION_OPEN, id
end

local function counts(items)
  local pinned, recent = 0, 0
  for _, item in ipairs(items or EMPTY) do
    if type(item) == "table" then
      if item.pinned then
        pinned = pinned + 1
      else
        recent = recent + 1
      end
    end
  end
  return pinned, recent
end

-- The muted line in the footer: "3 pinned, 12 recent". A group with nothing in it is left out
-- rather than written as a zero, and an empty history says nothing at all, because the list is
-- already saying it. Pure.
function UIHistory.FooterText(items)
  local pinned, recent = counts(items)
  if pinned > 0 and recent > 0 then
    return string.format(L["%d pinned, %d recent"], pinned, recent)
  end
  if pinned > 0 then
    return string.format(L["%d pinned"], pinned)
  end
  if recent > 0 then
    return string.format(L["%d recent"], recent)
  end
  return ""
end

-- Whether Clear history has anything to clear. Pins are not recent, so a history that is nothing
-- but pins cannot be cleared and the button reads as disabled. Pure.
function UIHistory.CanClear(items)
  local _, recent = counts(items)
  return recent > 0
end

-- How tall the rows are together, headers and all. Pure.
function UIHistory.ListHeight(rows)
  local total = 0
  for _, model in ipairs(rows or EMPTY) do
    total = total + UIHistory.RowHeight(model)
  end
  return total
end

-- Whether these rows need a scrollbar in a list this tall. A height of nothing is a list the
-- client has not laid out yet, which reads as fitting: an unwanted bar is worse than a late one,
-- and every Refresh asks again. Pure.
function UIHistory.Overflows(rows, height)
  local available = tonumber(height) or 0
  if available <= 0 then
    return false
  end
  return UIHistory.ListHeight(rows) > available
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

UIHistory.pool = {}

-- One interface cue, by name. UI/Sound.lua decides what a cue sounds like and whether cues are
-- on; this is the one line a call site writes, and it is looked up at call time so a build or a
-- spec without the module costs the cue and nothing else.
local playCue = ItemTree.UI.Sound.PlayCue

local function newFrame(kind, parent)
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, kind, nil, parent)
  if ok and frame then
    return frame
  end
  return nil
end

-- A frame that is only worth having with its template: the ScrollBox parts and the close button.
-- CreateFrame raises on a template the client does not carry, so nothing here is taken without a
-- pcall and every caller has a plain fallback behind it.
local function newTemplatedFrame(kind, parent, template)
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, kind, nil, parent, template)
  if ok and frame then
    return frame
  end
  return nil
end

-- Theme.Color raises on an unknown key, so the table is read instead and a missing key leaves the
-- client's own colour alone. Same idiom as UI/Sidebar.lua.
local function themeColor(key)
  return Theme and type(Theme.ColorTable) == "function" and Theme.ColorTable(key) or nil
end

local function tint(texture, key, alpha)
  local color = themeColor(key)
  if not color or type(texture) ~= "table" or type(texture.SetVertexColor) ~= "function" then
    return false
  end
  texture:SetVertexColor(color.r, color.g, color.b)
  if type(texture.SetAlpha) == "function" then
    texture:SetAlpha(alpha or color.a or 1)
  end
  return true
end

local function colourText(fontString, key)
  local color = themeColor(key)
  if type(fontString) == "table" and color and type(fontString.SetTextColor) == "function" then
    fontString:SetTextColor(color.r, color.g, color.b, color.a or 1)
  end
end

-- A flat fill in one Theme colour. Every texture goes through Assets so the path lives in one
-- table and the harness can report it.
local function wash(parent, layer, colorKey, alpha)
  if type(parent) ~= "table" or type(parent.CreateTexture) ~= "function" then
    return nil
  end
  local texture = parent:CreateTexture(nil, layer)
  if not texture then
    return nil
  end
  if Assets and type(Assets.Apply) == "function" then
    pcall(Assets.Apply, texture, "FILL_WHITE8X8")
  end
  tint(texture, colorKey, alpha)
  texture:Hide()
  return texture
end

-- The design's InsetPanel edge: four hairlines in one Theme colour, drawn by hand. Not a nine
-- slice, for the reason UI/Sidebar.lua gives.
local function insetBorder(frame, colorKey)
  local edges = {}
  for index = 1, 4 do
    local edge = wash(frame, "BORDER", colorKey)
    if not edge then
      return nil
    end
    edge:Show()
    edges[index] = edge
  end
  local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
  top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  top:SetHeight(UIHistory.EDGE_W)
  bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(UIHistory.EDGE_W)
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  left:SetWidth(UIHistory.EDGE_W)
  right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  right:SetWidth(UIHistory.EDGE_W)
  return { top = top, bottom = bottom, left = left, right = right, edges = edges }
end

local function tintEdges(border, colorKey)
  if type(border) ~= "table" then
    return false
  end
  for _, edge in ipairs(border.edges or EMPTY) do
    tint(edge, colorKey)
  end
  return true
end

-- Hands the font string one of the client's own font objects. Nothing here can raise, and a
-- client carrying none of them answers false, which is as far as this file can go.
local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(UIHistory.FONT_FALLBACKS) do
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

-- Body face, 1px shadow, one line. A font string that does not wrap and is anchored on both sides
-- is what makes the client truncate a long item name rather than push the ago column out.
-- SetFont answers false rather than raising where the client cannot load the face, so the answer
-- is read and a font object put back: a font string that lost its font raises from inside the
-- next SetText.
local function styleText(fontString, fontSize, colorKey, justify, fontKey)
  if type(fontString) ~= "table" then
    return nil
  end
  local fonts = Theme and Theme.fonts
  local face
  if fonts then
    face = fonts[fontKey or "ITEMTREE_FONT_BODY"]
  end
  if face and type(fontString.SetFont) == "function" then
    local ok, applied = pcall(fontString.SetFont, fontString, face, fontSize, "")
    if not ok or applied == false then
      fallbackFont(fontString)
    end
  end
  ensureFont(fontString)
  local outline = Theme and Theme.text and Theme.text.ITEMTREE_TEXT_OUTLINE
  if outline and type(fontString.SetShadowOffset) == "function" then
    fontString:SetShadowOffset(outline.x, outline.y)
    if type(fontString.SetShadowColor) == "function" then
      fontString:SetShadowColor(outline.r, outline.g, outline.b, outline.a)
    end
  end
  if type(fontString.SetJustifyH) == "function" then
    fontString:SetJustifyH(justify or "LEFT")
  end
  if type(fontString.SetWordWrap) == "function" then
    fontString:SetWordWrap(false)
  end
  if type(fontString.SetMaxLines) == "function" then
    pcall(fontString.SetMaxLines, fontString, 1)
  end
  colourText(fontString, colorKey)
  return fontString
end

-- A font string that is never fontless. The client's own font object is asked for at creation,
-- through the template argument where the client takes one and by hand where it does not, so a
-- SetText is never the first thing to touch the font.
local function newFontString(parent, fontSize, colorKey, justify, fontKey)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY", UIHistory.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY")
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  return styleText(fontString, fontSize, colorKey, justify, fontKey)
end

-- Every word this pane draws goes through here. The font is put back first, and the write itself
-- is pcalled, so a client that can give a font string no font at all costs the pane a blank
-- label rather than the whole draw.
local function setText(fontString, text)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  ensureFont(fontString)
  return (pcall(fontString.SetText, fontString, text or ""))
end

--------------------------------------------------------------------------------
-- What the model and the window are asked to do
--------------------------------------------------------------------------------

-- ItemTree.History, looked up at call time: this file must not hold a reference to a model that
-- was replaced, and a half loaded addon must not break a click.
local function model()
  local store = ItemTree.History
  return type(store) == "table" and store or nil
end

-- The rows the model says to draw. now is the clock the model stamps ages against; left out, the
-- model reads the client's own time.
function UIHistory.Items(now)
  local store = model()
  if not store or type(store.Items) ~= "function" then
    return EMPTY
  end
  local ok, items = pcall(store.Items, now)
  if ok and type(items) == "table" then
    return items
  end
  return EMPTY
end

-- Pins or unpins through the model, which is the only thing that writes the saved variable.
-- Toggle is what the model carries; Pin and Unpin are the fallback for a model without one.
function UIHistory.TogglePin(itemId)
  local store = model()
  if not store or not (tonumber(itemId) or type(itemId) == "string") then
    return false
  end
  if type(store.Toggle) == "function" then
    return (pcall(store.Toggle, itemId))
  end
  local pinned = type(store.IsPinned) == "function" and select(2, pcall(store.IsPinned, itemId)) or false
  local call = pinned and store.Unpin or store.Pin
  if type(call) ~= "function" then
    return false
  end
  return (pcall(call, itemId))
end

-- Clear history: the model empties recent and keeps the pins, and the list is redrawn in place.
-- The overlay stays up, which is what the footer button in HistoryModal does.
function UIHistory.ClearRecent()
  local store = model()
  if not store or type(store.Clear) ~= "function" then
    return false
  end
  local cleared = pcall(store.Clear)
  UIHistory.Refresh()
  return cleared
end

-- Re-roots the one window on an item. UI/Frame.lua and Core/Graph.lua are both looked up at call
-- time and both guarded, so a window that is still a stub costs the click and nothing else. This
-- never opens a second window: the window re-roots the one it already built.
--
-- Frame.OpenPicked is asked for first. This panel is one of the two dropdowns in the window's
-- header, and a pick from either is a jump to an item rather than a step through the graph, so
-- the window lands on its Tree tab rather than leaving the player on a tab that draws something
-- else. Frame.Open is the fallback for a build of UI/Frame.lua that predates that rule, which
-- opens the item exactly as this always did.
-- Brief SR1: a row of any other page hands its node key rather than an item id, and it is opened
-- as it stands.
function UIHistory.OpenItem(itemId)
  local Frame = ItemTree.UI and ItemTree.UI.Frame
  local Graph = ItemTree.Graph
  if type(Frame) ~= "table" or type(Frame.Open) ~= "function" then
    return false
  end
  local key
  if type(itemId) == "string" and not tonumber(itemId) then
    key = itemId
  else
    if type(Graph) ~= "table" or type(Graph.Key) ~= "function" then
      return false
    end
    local made, madeKey = pcall(Graph.Key, "item", itemId)
    if not made or type(madeKey) ~= "string" then
      return false
    end
    key = madeKey
  end
  local open = Frame.Open
  if type(Frame.OpenPicked) == "function" then
    open = Frame.OpenPicked
  end
  -- Brief G1: no pcall here. The window's own opens run under its boundary (Frame.Guarded), which
  -- hands an error to the client's handler and draws the empty page; a pcall here would only hide
  -- a raise from the specs, which run with the boundary off.
  open(key)
  return true
end

-- One click, from the row model and the part of the row it landed on. Opening re-roots the window
-- and then takes the overlay down; pinning leaves it up and redraws the list.
function UIHistory.Activate(rowModel, region)
  local action, id = UIHistory.Interpret(rowModel, region)
  if action == UIHistory.ACTION_OPEN then
    UIHistory.OpenItem(id)
    UIHistory.Hide()
  elseif action == UIHistory.ACTION_PIN then
    -- The pin is the one click here that leaves the panel up, so it is the one that needs a cue
    -- of its own: opening a row takes the panel down and the close cue says so.
    playCue("click")
    UIHistory.TogglePin(id)
    UIHistory.Refresh()
  end
  return action, id
end

--------------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------------

local function tooltipFrame()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return nil
  end
  return tooltip
end

function UIHistory.HideRowTooltip()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    tooltip:Hide()
    return true
  end
  return false
end

-- The client's own item tooltip on hover. SetItemByID is the modern call and the item link is the
-- older one; a client with neither just shows the hover wash.
function UIHistory.ShowRowTooltip(row)
  local rowModel = type(row) == "table" and row.rowModel or nil
  local itemId = type(rowModel) == "table" and rowModel.kind == UIHistory.KIND_ITEM and tonumber(rowModel.id) or nil
  local other = not itemId and type(rowModel) == "table" and rowModel.kind == UIHistory.KIND_ITEM and rowModel.key
  local tooltip = (itemId or other) and tooltipFrame() or nil
  if not tooltip then
    return false
  end
  tooltip:SetOwner(row, "ANCHOR_RIGHT")
  -- Brief SR1: any other page has no link the client draws, so it is its name and its kind word.
  if not itemId then
    if type(tooltip.SetText) == "function" then
      tooltip:SetText(rowModel.name or "")
    end
    if rowModel.kindText and type(tooltip.AddLine) == "function" then
      local color = themeColor("ITEMTREE_COLOR_TEXT_MUTED")
      if color then
        tooltip:AddLine(rowModel.kindText, color.r, color.g, color.b)
      else
        tooltip:AddLine(rowModel.kindText)
      end
    end
    if type(tooltip.Show) == "function" then
      tooltip:Show()
    end
    return true
  end
  local shown = false
  if type(tooltip.SetItemByID) == "function" then
    shown = pcall(tooltip.SetItemByID, tooltip, itemId) and true or false
  end
  if not shown and type(tooltip.SetHyperlink) == "function" then
    shown = pcall(tooltip.SetHyperlink, tooltip, "item:" .. tostring(itemId)) and true or false
  end
  if not shown and type(tooltip.SetText) == "function" then
    tooltip:SetText(rowModel.name or "")
    shown = true
  end
  if shown and type(tooltip.Show) == "function" then
    tooltip:Show()
  end
  return shown
end

-- A plain text tooltip, for the pin toggle and the close button.
local function showHintTooltip(owner, text)
  local tooltip = tooltipFrame()
  if not tooltip or type(text) ~= "string" then
    return false
  end
  tooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if type(tooltip.SetText) == "function" then
    tooltip:SetText(text)
  elseif type(tooltip.AddLine) == "function" then
    tooltip:AddLine(text)
  end
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
  return true
end

local function showHover(row, shown)
  if type(row) == "table" and row.hoverWash then
    if shown then
      row.hoverWash:Show()
    else
      row.hoverWash:Hide()
    end
  end
end

local function onRowEnter(row)
  showHover(row, true)
  UIHistory.ShowRowTooltip(row)
end

local function onRowLeave(row)
  showHover(row, false)
  UIHistory.HideRowTooltip()
end

-- E6: the standard modified clicks. A left click with the client's dress up or chat link
-- modifier on an item row goes to UI/ItemClick.lua first, and answers true when the client took
-- it (the item is on in the Dressing Room, or its link is in the chat box); the row then opens
-- nothing and the panel stays up. Every other click, and a row that opens nothing, answers false.
function UIHistory.ModifiedClick(rowModel, button)
  if button ~= nil and button ~= "LeftButton" then
    return false
  end
  local action, id = UIHistory.Interpret(rowModel, UIHistory.REGION_ROW)
  -- Only an item takes the dress up and chat link clicks; any other page opens.
  if action ~= UIHistory.ACTION_OPEN or type(id) ~= "number" then
    return false
  end
  local helper = ItemTree.ItemClick
  if type(helper) ~= "table" or type(helper.Handle) ~= "function" then
    return false
  end
  local ok, handled = pcall(helper.Handle, id)
  return ok and handled == true
end

local function onRowClick(row, button)
  local rowModel = type(row) == "table" and row.rowModel or nil
  if UIHistory.ModifiedClick(rowModel, button) then
    return
  end
  UIHistory.Activate(rowModel, UIHistory.REGION_ROW)
end

-- The pin toggle sits inside the row, so entering it takes the mouse off the row and fires the
-- row's own OnLeave. The wash is put back by hand, which is what keeps the row lit while the
-- cursor is on the toggle.
local function onPinEnter(pin)
  local row = type(pin) == "table" and pin.row or nil
  showHover(row, true)
  local rowModel = type(row) == "table" and row.rowModel or nil
  local pinned = type(rowModel) == "table" and rowModel.pinned
  showHintTooltip(pin, pinned and L["Unpin"] or L["Pin"])
end

local function onPinLeave(pin)
  showHover(type(pin) == "table" and pin.row or nil, false)
  UIHistory.HideRowTooltip()
end

local function onPinClick(pin)
  local row = type(pin) == "table" and pin.row or nil
  UIHistory.Activate(type(row) == "table" and row.rowModel or nil, UIHistory.REGION_PIN)
end

local function buildPinToggle(row)
  local pin = newFrame("Button", row)
  if not pin then
    return nil
  end
  pin:SetSize(UIHistory.TOGGLE_SIZE, UIHistory.TOGGLE_SIZE)
  pin:SetPoint("RIGHT", row, "RIGHT", -UIHistory.GUTTER, 0)
  if type(pin.EnableMouse) == "function" then
    pin:EnableMouse(true)
  end
  pin.border = insetBorder(pin, "ITEMTREE_COLOR_BORDER_GOLD_DIM")
  pin.fill = wash(pin, "ARTWORK", "ITEMTREE_COLOR_TEXT_TITLE")
  if pin.fill then
    pin.fill:SetPoint("TOPLEFT", pin, "TOPLEFT", 3, -3)
    pin.fill:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", -3, 3)
  end
  pin.row = row
  pin:SetScript("OnMouseUp", onPinClick)
  pin:SetScript("OnEnter", onPinEnter)
  pin:SetScript("OnLeave", onPinLeave)
  return pin
end

-- Builds the widgets of one row, once. The ScrollBox hands back bare frames it made itself, so
-- this has to work on a frame this file did not create.
function UIHistory.DecorateRow(row)
  if type(row) ~= "table" or row.itemTreeHistoryRow then
    return row
  end
  row.itemTreeHistoryRow = true
  row:SetHeight(UIHistory.ROW_H)
  if type(row.EnableMouse) == "function" then
    row:EnableMouse(true)
  end

  -- A sub group header is the same frame drawn differently: the sticky surface with a divider
  -- under it, which is how HistoryList separates Pinned from Recent.
  row.headerFill = wash(row, "BACKGROUND", "ITEMTREE_COLOR_SURFACE_STICKY")
  if row.headerFill then
    row.headerFill:SetAllPoints(row)
  end
  row.headerEdge = wash(row, "BORDER", "ITEMTREE_COLOR_BORDER_DIVIDER")
  if row.headerEdge then
    row.headerEdge:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.headerEdge:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.headerEdge:SetHeight(UIHistory.EDGE_W)
  end
  row.hoverWash = wash(row, "BORDER", "ITEMTREE_COLOR_STATE_HOVER")
  if row.hoverWash then
    row.hoverWash:SetAllPoints(row)
  end

  row.icon = type(row.CreateTexture) == "function" and row:CreateTexture(nil, "ARTWORK") or nil
  if row.icon then
    row.icon:SetSize(UIHistory.ICON_SIZE, UIHistory.ICON_SIZE)
    row.icon:SetPoint("LEFT", row, "LEFT", UIHistory.GUTTER, 0)
  end

  row.pin = buildPinToggle(row)

  row.ago = newFontString(row, size("ITEMTREE_FONTSIZE_BODY_SM", 11), "ITEMTREE_COLOR_TEXT_MUTED", "RIGHT")
  if row.ago then
    row.ago:SetWidth(UIHistory.AGO_W)
    if row.pin then
      row.ago:SetPoint("RIGHT", row.pin, "LEFT", -UIHistory.GUTTER, 0)
    else
      row.ago:SetPoint("RIGHT", row, "RIGHT", -UIHistory.GUTTER, 0)
    end
  end

  row.name = newFontString(row, size("ITEMTREE_FONTSIZE_BODY_MD", 12), "ITEMTREE_COLOR_TEXT_BODY", "LEFT")

  -- Brief SR1: the muted kind word of a page that is not an item ("Quest", "Zone"), right aligned
  -- just left of the ago column.
  row.kindText = newFontString(row, size("ITEMTREE_FONTSIZE_BODY_SM", 11), "ITEMTREE_COLOR_TEXT_MUTED", "RIGHT")
  if row.kindText then
    row.kindText:SetWidth(UIHistory.KIND_W)
    if row.ago then
      row.kindText:SetPoint("RIGHT", row.ago, "LEFT", -UIHistory.GUTTER, 0)
    else
      row.kindText:SetPoint("RIGHT", row, "RIGHT", -UIHistory.GUTTER, 0)
    end
  end

  row:SetScript("OnEnter", onRowEnter)
  row:SetScript("OnLeave", onRowLeave)
  row:SetScript("OnMouseUp", onRowClick)
  return row
end

-- The icon the row draws: the one the model carried, the data's own otherwise, and the question
-- mark for an item nothing has heard of.
local function applyRowIcon(texture, rowModel)
  if type(texture) ~= "table" then
    return false
  end
  local icon = rowModel.icon
  -- Brief SR1: a page with no art of its own wears its kind's glyph, the one its rows wear in the
  -- tree, through Assets like every texture.
  if icon == nil and rowModel.asset and Assets and type(Assets.Apply) == "function" then
    if pcall(Assets.Apply, texture, rowModel.asset) then
      texture:Show()
      return true
    end
  end
  if icon == nil and tonumber(rowModel.id) and Assets and type(Assets.ItemIcon) == "function" then
    local ok, resolved = pcall(Assets.ItemIcon, rowModel.id)
    icon = ok and resolved or nil
  end
  if icon ~= nil and type(texture.SetTexCoord) == "function" then
    -- A pooled row that last wore a cropped glyph gets the whole icon back.
    pcall(texture.SetTexCoord, texture, 0, 1, 0, 1)
  end
  if icon ~= nil and type(texture.SetTexture) == "function" and pcall(texture.SetTexture, texture, icon) then
    texture:Show()
    return true
  end
  if Assets and type(Assets.Apply) == "function" and pcall(Assets.Apply, texture, "ICON_QUESTIONMARK") then
    texture:Show()
    return true
  end
  texture:Hide()
  return false
end

local function applyPinState(row, pinned)
  local pin = row.pin
  if not pin then
    return false
  end
  pin.rowModel = row.rowModel
  tintEdges(pin.border, pinned and "ITEMTREE_COLOR_BORDER_GOLD" or "ITEMTREE_COLOR_BORDER_GOLD_DIM")
  if pin.fill then
    if pinned then
      pin.fill:Show()
    else
      pin.fill:Hide()
    end
  end
  pin:Show()
  return true
end

-- Draws one row model into a row frame. Headers and item rows share the frame, so the ScrollBox
-- needs one template and the pool needs one kind of row.
function UIHistory.InitRow(row, rowModel)
  if type(row) ~= "table" then
    return false
  end
  UIHistory.DecorateRow(row)
  row.rowModel = rowModel
  if type(rowModel) ~= "table" then
    row:Hide()
    return false
  end
  row:SetHeight(UIHistory.RowHeight(rowModel))

  local isHeader = rowModel.kind == UIHistory.KIND_HEADER
  if row.headerFill then
    if isHeader then
      row.headerFill:Show()
    else
      row.headerFill:Hide()
    end
  end
  if row.headerEdge then
    if isHeader then
      row.headerEdge:Show()
    else
      row.headerEdge:Hide()
    end
  end

  if row.kindText then
    setText(row.kindText, (not isHeader and rowModel.kindText) or "")
  end

  if isHeader then
    if row.icon then
      row.icon:Hide()
    end
    if row.pin then
      row.pin:Hide()
    end
    if row.ago then
      setText(row.ago, "")
    end
    if row.name then
      row.name:ClearAllPoints()
      row.name:SetPoint("LEFT", row, "LEFT", UIHistory.GUTTER, 0)
      row.name:SetPoint("RIGHT", row, "RIGHT", -UIHistory.GUTTER, 0)
      setText(row.name, rowModel.label)
      colourText(row.name, "ITEMTREE_COLOR_TEXT_BODY")
    end
    onRowLeave(row)
    row:Show()
    return true
  end

  if row.icon then
    applyRowIcon(row.icon, rowModel)
  end
  if row.ago then
    setText(row.ago, rowModel.agoText)
  end
  applyPinState(row, rowModel.pinned)
  if row.name then
    row.name:ClearAllPoints()
    if row.icon then
      row.name:SetPoint("LEFT", row.icon, "RIGHT", UIHistory.GUTTER, 0)
    else
      row.name:SetPoint("LEFT", row, "LEFT", UIHistory.GUTTER, 0)
    end
    if rowModel.kindText and row.kindText then
      row.name:SetPoint("RIGHT", row.kindText, "LEFT", -UIHistory.GUTTER, 0)
    elseif row.ago then
      row.name:SetPoint("RIGHT", row.ago, "LEFT", -UIHistory.GUTTER, 0)
    else
      row.name:SetPoint("RIGHT", row, "RIGHT", -UIHistory.GUTTER, 0)
    end
    setText(row.name, rowModel.name)
    local key = Theme and type(Theme.QualityKey) == "function" and Theme.QualityKey(rowModel.quality) or nil
    colourText(row.name, key or "ITEMTREE_COLOR_TEXT_BODY")
  end
  onRowLeave(row)
  row:Show()
  return true
end

--------------------------------------------------------------------------------
-- The list: a ScrollBox where the client carries one, a frame pool where it does not
--------------------------------------------------------------------------------

local function scrollAvailable()
  local scrollUtil = rawget(_G, "ScrollUtil")
  if type(rawget(_G, "CreateScrollBoxListLinearView")) ~= "function" then
    return false
  end
  if type(rawget(_G, "CreateDataProvider")) ~= "function" then
    return false
  end
  if type(scrollUtil) ~= "table" then
    return false
  end
  return type(scrollUtil.InitScrollBoxListWithScrollBar) == "function"
    or type(scrollUtil.InitScrollBoxList) == "function"
end

local function newLinearView()
  local create = rawget(_G, "CreateScrollBoxListLinearView")
  local ok, view = pcall(create)
  if not ok or type(view) ~= "table" then
    return nil
  end
  -- Two row heights, so the extent is asked for per row where the client can; a client that only
  -- takes one extent gets the item row height and the headers draw a little tight.
  if type(view.SetElementExtentCalculator) == "function" then
    pcall(view.SetElementExtentCalculator, view, function(_, element)
      return UIHistory.RowHeight(element)
    end)
  elseif type(view.SetElementExtent) == "function" then
    pcall(view.SetElementExtent, view, UIHistory.ROW_H)
  end
  if type(view.SetElementInitializer) ~= "function" then
    return nil
  end
  local initialised = pcall(view.SetElementInitializer, view, UIHistory.ROW_TEMPLATE, function(row, element)
    UIHistory.InitRow(row, element)
  end)
  if not initialised then
    return nil
  end
  return view
end

-- Lays the scroll box out inside its host, giving the width back when the bar is not drawn.
local function anchorScrollBox(withBar)
  local box, host = UIHistory.scrollBox, UIHistory.scrollHost
  if not (box and host and type(box.ClearAllPoints) == "function") then
    return false
  end
  box:ClearAllPoints()
  box:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
  box:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", withBar and -UIHistory.SCROLLBAR_W or 0, 0)
  return true
end

local function buildScrollBox(parent)
  if not scrollAvailable() then
    return false
  end
  local box = newTemplatedFrame("Frame", parent, "WowScrollBoxList")
  if not box then
    return false
  end
  local bar = newTemplatedFrame("EventFrame", parent, "MinimalScrollBar")
    or newTemplatedFrame("Frame", parent, "MinimalScrollBar")
  local view = newLinearView()
  local scrollUtil = rawget(_G, "ScrollUtil")
  local ok = false
  if view and bar and type(scrollUtil.InitScrollBoxListWithScrollBar) == "function" then
    ok = pcall(scrollUtil.InitScrollBoxListWithScrollBar, box, bar, view)
  elseif view and type(scrollUtil.InitScrollBoxList) == "function" then
    ok = pcall(scrollUtil.InitScrollBoxList, box, view)
  end
  if not ok then
    box:Hide()
    if bar then
      bar:Hide()
    end
    return false
  end

  UIHistory.scrollBox, UIHistory.scrollBar, UIHistory.view, UIHistory.scrollHost = box, bar, view, parent
  anchorScrollBox(false)
  if bar then
    bar:SetWidth(UIHistory.SCROLLBAR_W)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    -- Hidden until the rows say otherwise, so a short list never opens beside a full height bar.
    bar:Hide()
  end
  return true
end

local function heightOf(frame)
  if type(frame) ~= "table" or type(frame.GetHeight) ~= "function" then
    return 0
  end
  local ok, height = pcall(frame.GetHeight, frame)
  return (ok and tonumber(height)) or 0
end

-- The bar is drawn only while the rows overflow the list, and the list takes the width back when
-- it goes. The frame pool has no bar of its own, so this is the scroll path's alone.
function UIHistory.UpdateScrollBar(rows)
  local bar = UIHistory.scrollBar
  if not bar then
    return false
  end
  local overflow = UIHistory.Overflows(rows, heightOf(UIHistory.scrollHost or UIHistory.list))
  if overflow then
    bar:Show()
  else
    bar:Hide()
  end
  anchorScrollBox(overflow)
  return overflow
end

local function drawScroll(rows)
  local box = UIHistory.scrollBox
  local create = rawget(_G, "CreateDataProvider")
  if not box or type(box.SetDataProvider) ~= "function" or type(create) ~= "function" then
    return false
  end
  local ok, provider = pcall(create, rows)
  if not ok or not provider then
    return false
  end
  return (pcall(box.SetDataProvider, box, provider))
end

local function poolRow(index)
  local row = UIHistory.pool[index]
  if row then
    return row
  end
  row = newFrame("Button", UIHistory.content)
  if not row then
    return nil
  end
  UIHistory.DecorateRow(row)
  local above = UIHistory.pool[index - 1]
  if above then
    row:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, 0)
    row:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, 0)
  else
    row:SetPoint("TOPLEFT", UIHistory.content, "TOPLEFT", 0, 0)
    row:SetPoint("TOPRIGHT", UIHistory.content, "TOPRIGHT", 0, 0)
  end
  UIHistory.pool[index] = row
  return row
end

local function drawPool(rows)
  if not UIHistory.content then
    return false
  end
  local drawn = 0
  for index, rowModel in ipairs(rows) do
    local row = poolRow(index)
    if not row then
      break
    end
    UIHistory.InitRow(row, rowModel)
    drawn = index
  end
  for index = drawn + 1, #UIHistory.pool do
    UIHistory.pool[index]:Hide()
  end
  return true
end

--------------------------------------------------------------------------------
-- The overlay itself
--------------------------------------------------------------------------------

local function onScrimClick()
  UIHistory.Hide()
end

-- Brief E91: SetPropagateKeyboardInput is refused in combat lockdown on the Forever client, so a
-- scrim deciding per key in combat would keep whatever it decided last, which could be Escape
-- swallowed for good. The rule: the scrim takes the keyboard only out of combat, with propagation
-- on, lets it go on PLAYER_REGEN_DISABLED (before the lockdown, through UI/Frame.lua's
-- Frame.OnCombatStart), and takes it back as combat ends. Escape in combat therefore reaches the
-- client's CloseSpecialWindows, which closes the window, overlay and all.
local function inCombat()
  local lockdown = rawget(_G, "InCombatLockdown")
  if type(lockdown) ~= "function" then
    return false
  end
  local ok, locked = pcall(lockdown)
  return (ok and locked) and true or false
end

-- Propagation, never in combat. Answers whether it was set.
local function setPropagate(scrim, propagate)
  if inCombat() or type(scrim.SetPropagateKeyboardInput) ~= "function" then
    return false
  end
  return (pcall(scrim.SetPropagateKeyboardInput, scrim, propagate))
end

local function enableKeyboard(scrim, on)
  if type(scrim.EnableKeyboard) == "function" then
    pcall(scrim.EnableKeyboard, scrim, on)
  end
end

-- Takes the keyboard for a shown overlay, out of combat only, with every key passing through
-- until one is answered. Answers whether the scrim holds it.
local function takeKeyboard(scrim)
  if inCombat() then
    enableKeyboard(scrim, false)
    return false
  end
  setPropagate(scrim, true)
  enableKeyboard(scrim, true)
  return true
end

-- Escape closes the overlay and nothing else. The key is swallowed for this one press so the
-- client's CloseSpecialWindows never runs and the window stays open; every other key is passed
-- straight through, so nothing the player has bound is lost while the overlay is up. In combat
-- nothing is decided here (see above) and Escape still takes the overlay down.
local function onScrimKeyDown(scrim, key)
  local propagate = key ~= "ESCAPE"
  setPropagate(scrim, propagate)
  if not propagate then
    UIHistory.Hide()
  end
end

-- The combat edges, registered once with the window's registry where it is loaded.
local function registerCombat()
  local ui = ItemTree.UI
  local Frame = type(ui) == "table" and ui.Frame or nil
  if type(Frame) ~= "table" or type(Frame.OnCombatStart) ~= "function" then
    return false
  end
  return Frame.OnCombatStart("History", function()
    local scrim = UIHistory.frame
    if type(scrim) == "table" then
      setPropagate(scrim, true)
      enableKeyboard(scrim, false)
    end
  end, function()
    local scrim = UIHistory.frame
    if type(scrim) == "table" and UIHistory.IsShown() then
      takeKeyboard(scrim)
    end
  end)
end

local function raiseOver(frame, parent, step)
  if type(frame.SetFrameStrata) == "function" then
    pcall(frame.SetFrameStrata, frame, "DIALOG")
  end
  local level = nil
  if type(parent) == "table" and type(parent.GetFrameLevel) == "function" then
    local ok, value = pcall(parent.GetFrameLevel, parent)
    level = ok and tonumber(value) or nil
  end
  if level and type(frame.SetFrameLevel) == "function" then
    pcall(frame.SetFrameLevel, frame, level + step)
  end
  return frame
end

local function buildScrim(parent)
  local scrim = newFrame("Frame", parent)
  if not scrim then
    return nil
  end
  -- The window body: everything under the title bar, inside the frame art, measured by the
  -- window itself. The title bar is left alone so the close button and the rewind button are
  -- still there to be used.
  local insets = UIHistory.BodyInsets()
  scrim:SetPoint("TOPLEFT", parent, "TOPLEFT", insets.left, -insets.top)
  scrim:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -insets.right, insets.bottom)
  raiseOver(scrim, parent, 30)
  if type(scrim.EnableMouse) == "function" then
    scrim:EnableMouse(true)
  end
  scrim.fill = wash(scrim, "BACKGROUND", "ITEMTREE_COLOR_SURFACE_FRAME", UIHistory.SCRIM_ALPHA)
  if scrim.fill then
    scrim.fill:SetAllPoints(scrim)
    scrim.fill:Show()
  end
  scrim:SetScript("OnMouseUp", onScrimClick)
  scrim:SetScript("OnKeyDown", onScrimKeyDown)
  scrim:Hide()
  return scrim
end

local function buildCloseButton(dialog)
  local button = newTemplatedFrame("Button", dialog, UIHistory.CLOSE_TEMPLATE)
  if not button then
    button = newFrame("Button", dialog)
    if not button then
      return nil
    end
    button:SetSize(UIHistory.BUTTON_H, UIHistory.BUTTON_H)
    local glyph = type(button.CreateTexture) == "function" and button:CreateTexture(nil, "ARTWORK") or nil
    if glyph then
      glyph:SetSize(UIHistory.BUTTON_H - 6, UIHistory.BUTTON_H - 6)
      glyph:SetPoint("CENTER")
      if Assets and type(Assets.Apply) == "function" and pcall(Assets.Apply, glyph, "BUTTON_CLOSE") then
        tint(glyph, "ITEMTREE_COLOR_TEXT_TITLE")
      else
        glyph:Hide()
      end
      button.glyph = glyph
    end
  end
  button:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -UIHistory.EDGE_W, -UIHistory.EDGE_W)
  -- A Button fires OnClick on its own, so the close button needs no OnMouseUp of its own.
  button:SetScript("OnClick", onScrimClick)
  button:SetScript("OnEnter", function(self)
    showHintTooltip(self, L["Close"])
  end)
  button:SetScript("OnLeave", function()
    UIHistory.HideRowTooltip()
  end)
  return button
end

local function onClearClick(button)
  if type(button) == "table" and button.enabled == false then
    return
  end
  UIHistory.ClearRecent()
end

-- The footer's text button, at the design's 20px control height: a flat face, a hairline edge and
-- one body line, which is Button variant secondary in the ui kit.
local function buildClearButton(footer)
  local button = newFrame("Button", footer)
  if not button then
    return nil
  end
  button:SetHeight(UIHistory.BUTTON_H)
  button:SetWidth(96)
  button:SetPoint("RIGHT", footer, "RIGHT", 0, 0)
  button.face = wash(button, "BACKGROUND", "ITEMTREE_COLOR_BUTTON_FACE")
  if button.face then
    button.face:SetAllPoints(button)
    button.face:Show()
  end
  button.border = insetBorder(button, "ITEMTREE_COLOR_BORDER_GOLD_DIM")
  button.label = newFontString(button, size("ITEMTREE_FONTSIZE_BODY_SM", 11), "ITEMTREE_COLOR_TEXT_BODY", "CENTER")
  if button.label then
    button.label:SetPoint("CENTER")
    setText(button.label, L["Clear history"])
  end
  button.enabled = true
  button:SetScript("OnClick", onClearClick)
  return button
end

-- The design's InsetPanel at pad 0: the inset fill, a 1px border, and a content frame held inside
-- the border so no row is drawn over it.
local function buildListPanel(dialog, below, above)
  local panel = newFrame("Frame", dialog)
  if not panel then
    return nil, nil
  end
  panel:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -UIHistory.PAD)
  panel:SetPoint("TOPRIGHT", below, "BOTTOMRIGHT", 0, -UIHistory.PAD)
  panel:SetPoint("BOTTOMLEFT", above, "TOPLEFT", 0, UIHistory.GUTTER)
  panel:SetPoint("BOTTOMRIGHT", above, "TOPRIGHT", 0, UIHistory.GUTTER)
  panel.fill = wash(panel, "BACKGROUND", "ITEMTREE_COLOR_SURFACE_INSET")
  if panel.fill then
    panel.fill:SetAllPoints(panel)
    panel.fill:Show()
  end
  panel.border = insetBorder(panel, "ITEMTREE_COLOR_BORDER_GOLD_DIM")

  local content = newFrame("Frame", panel)
  if not content then
    return panel, panel
  end
  content:SetPoint("TOPLEFT", panel, "TOPLEFT", UIHistory.EDGE_W, -UIHistory.EDGE_W)
  content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -UIHistory.EDGE_W, UIHistory.EDGE_W)
  return panel, content
end

local function buildDialog(scrim)
  local dialog = newFrame("Frame", scrim)
  if not dialog then
    return nil
  end
  dialog:SetSize(UIHistory.DIALOG_W, UIHistory.DIALOG_H)
  dialog:SetPoint("CENTER", scrim, "CENTER", 0, 0)
  raiseOver(dialog, scrim, 10)
  -- The dialog takes the mouse itself, so a click inside it is never a click on the scrim.
  if type(dialog.EnableMouse) == "function" then
    dialog:EnableMouse(true)
  end
  dialog.fill = wash(dialog, "BACKGROUND", "ITEMTREE_COLOR_SURFACE_FRAME", 1)
  if dialog.fill then
    dialog.fill:SetAllPoints(dialog)
    dialog.fill:Show()
  end
  dialog.border = insetBorder(dialog, "ITEMTREE_COLOR_BORDER_GOLD")
  UIHistory.dialog = dialog

  local header = newFrame("Frame", dialog)
  if not header then
    return nil
  end
  header:SetHeight(UIHistory.HEADER_ROW_H)
  header:SetPoint("TOPLEFT", dialog, "TOPLEFT", UIHistory.PAD, -UIHistory.PAD)
  header:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -UIHistory.PAD, -UIHistory.PAD)
  UIHistory.header = header

  UIHistory.title = newFontString(
    header,
    size("ITEMTREE_FONTSIZE_TITLE_SM", 14),
    "ITEMTREE_COLOR_TEXT_TITLE",
    "LEFT",
    "ITEMTREE_FONT_TITLE"
  )
  if UIHistory.title then
    UIHistory.title:SetPoint("LEFT", header, "LEFT", 0, 0)
    setText(UIHistory.title, L["Recently viewed"])
  end
  UIHistory.divider = wash(header, "ARTWORK", "ITEMTREE_COLOR_BORDER_DIVIDER")
  if UIHistory.divider then
    UIHistory.divider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    UIHistory.divider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    UIHistory.divider:SetHeight(UIHistory.EDGE_W)
    UIHistory.divider:Show()
  end
  UIHistory.closeButton = buildCloseButton(dialog)

  local footer = newFrame("Frame", dialog)
  if not footer then
    return nil
  end
  footer:SetHeight(UIHistory.FOOTER_ROW_H)
  footer:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", UIHistory.PAD, UIHistory.PAD)
  footer:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -UIHistory.PAD, UIHistory.PAD)
  UIHistory.footer = footer
  UIHistory.clearButton = buildClearButton(footer)
  UIHistory.countText =
    newFontString(footer, size("ITEMTREE_FONTSIZE_BODY_SM", 11), "ITEMTREE_COLOR_TEXT_MUTED", "LEFT")
  if UIHistory.countText then
    UIHistory.countText:SetPoint("LEFT", footer, "LEFT", 0, 0)
    if UIHistory.clearButton then
      UIHistory.countText:SetPoint("RIGHT", UIHistory.clearButton, "LEFT", -UIHistory.PAD, 0)
    end
  end

  UIHistory.listPanel, UIHistory.list = buildListPanel(dialog, header, footer)
  local host = UIHistory.list or dialog
  if buildScrollBox(host) then
    UIHistory.mode = "scroll"
  else
    UIHistory.mode = "pool"
    UIHistory.content = host
  end

  -- An empty history is one muted line in the middle of the list, not a row.
  UIHistory.emptyText =
    newFontString(host, size("ITEMTREE_FONTSIZE_BODY_MD", 12), "ITEMTREE_COLOR_TEXT_MUTED", "CENTER")
  if UIHistory.emptyText then
    UIHistory.emptyText:SetPoint("CENTER", host, "CENTER", 0, 0)
    setText(UIHistory.emptyText, L["Nothing viewed yet"])
    UIHistory.emptyText:Hide()
  end
  return dialog
end

-- Builds the overlay once, parented to the window. Idempotent for the same window; a different
-- window rebuilds, which nothing but a spec ever does. Returns nil with no client.
function UIHistory.Build(parent)
  if UIHistory.frame and (parent == nil or parent == UIHistory.parent) then
    return UIHistory.frame
  end
  if type(rawget(_G, "CreateFrame")) ~= "function" then
    return nil
  end
  parent = parent or UIHistory.parent
  if type(parent) ~= "table" then
    return nil
  end
  UIHistory.frame, UIHistory.dialog, UIHistory.mode = nil, nil, nil
  UIHistory.pool = {}
  UIHistory.scrollBox, UIHistory.scrollBar, UIHistory.view = nil, nil, nil
  UIHistory.scrollHost, UIHistory.content, UIHistory.list = nil, nil, nil

  local scrim = buildScrim(parent)
  if not scrim then
    return nil
  end
  UIHistory.parent, UIHistory.frame = parent, scrim
  if not buildDialog(scrim) then
    -- A client that would not give us a dialog leaves no half built overlay behind: the next
    -- Toggle tries again rather than raising a scrim with nothing on it.
    scrim:Hide()
    UIHistory.frame, UIHistory.dialog = nil, nil
    return nil
  end
  return scrim
end

local function setClearEnabled(enabled)
  local button = UIHistory.clearButton
  if not button then
    return false
  end
  button.enabled = enabled and true or false
  if enabled then
    if type(button.Enable) == "function" then
      pcall(button.Enable, button)
    end
    colourText(button.label, "ITEMTREE_COLOR_TEXT_BODY")
  else
    if type(button.Disable) == "function" then
      pcall(button.Disable, button)
    end
    colourText(button.label, "ITEMTREE_COLOR_TEXT_DISABLED")
  end
  return button.enabled
end

-- Re-reads the model and redraws. Does not show the overlay: an overlay that is down stays down,
-- which is what lets the window refresh without raising it.
function UIHistory.Refresh(now)
  if not UIHistory.frame then
    return false
  end
  local items = UIHistory.Items(now)
  local rows = UIHistory.Rows(items)
  UIHistory.items, UIHistory.rows = items, rows

  if UIHistory.countText then
    setText(UIHistory.countText, UIHistory.FooterText(items))
  end
  setClearEnabled(UIHistory.CanClear(items))
  if UIHistory.emptyText then
    if #rows == 0 then
      UIHistory.emptyText:Show()
    else
      UIHistory.emptyText:Hide()
    end
  end

  UIHistory.UpdateScrollBar(rows)
  if UIHistory.mode == "scroll" then
    if drawScroll(rows) then
      return true
    end
    -- A client that took the ScrollBox but will not take a data provider falls back for good,
    -- rather than leaving the list blank.
    UIHistory.mode = "pool"
    UIHistory.content = UIHistory.list or UIHistory.dialog
    if UIHistory.scrollBox then
      UIHistory.scrollBox:Hide()
    end
    if UIHistory.scrollBar then
      UIHistory.scrollBar:Hide()
    end
  end
  return drawPool(rows)
end

-- Raises the overlay over the window, building it the first time. Returns false where there is no
-- client to build one on.
function UIHistory.Show(parent)
  local scrim = UIHistory.Build(parent)
  if not scrim then
    return false
  end
  UIHistory.Refresh()
  registerCombat()
  takeKeyboard(scrim)
  local wasShown = UIHistory.IsShown()
  scrim:Show()
  -- A side panel going up, which is the pair the client plays for the character sheet's own
  -- right pane (Blizzard_UIPanels_Game/Camelot/CharacterFrame.lua:298 on the forever branch).
  -- Silent where it was already up, so a refresh over an open panel says nothing.
  if not wasShown then
    playCue("open")
  end
  return true
end

-- Takes the overlay down and hands the keyboard back, so Escape closes the window again. A no op
-- on an overlay that was never built.
function UIHistory.Hide()
  local scrim = UIHistory.frame
  if not scrim or type(scrim.Hide) ~= "function" then
    return false
  end
  -- Only when there was something to take down. This is called from the button, from the scrim,
  -- from Escape and from the window closing, and the last of those has already played the same
  -- cue, which UI/Sound.lua's throttle folds back into one sound.
  if UIHistory.IsShown() then
    playCue("close")
  end
  enableKeyboard(scrim, false)
  UIHistory.HideRowTooltip()
  scrim:Hide()
  return true
end

function UIHistory.IsShown()
  local scrim = UIHistory.frame
  if not scrim or type(scrim.IsShown) ~= "function" then
    return false
  end
  return scrim:IsShown() and true or false
end

-- What the rewind button in the title bar calls. Returns true when the overlay went up.
function UIHistory.Toggle(parent)
  if UIHistory.IsShown() then
    UIHistory.Hide()
    return false
  end
  return UIHistory.Show(parent)
end

-- The window raises the overlay, so there is nothing to do at load.
function UIHistory.Init() end

return UIHistory
