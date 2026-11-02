-- The toast: one short banner near the top centre of the screen, in the client's own toast look,
-- that fades in, holds and fades away by itself.
--
-- Brief UX1 (QA item 402, the owner, 2026-10-23): "When you click on a way point to add it you
-- should get a toast notification, in the wow style (Waypoint added and some VERY basic info about
-- what it was for (not the co-ords))". UI/Map.lua Map.SetWaypoint, the one place every waypoint
-- ItemTree sets goes through (a pin on a Map tab, the Set waypoint button and the coordinates on a
-- page, Show nearest), calls Toast.ShowWaypoint with what the waypoint is for once the client has
-- taken it: "Hogger", "Copper Vein", "Marshal Dughan, turn in for Wanted: Hogger". Never the
-- coordinates: Toast.Detail drops a coordinate pair from the words should one ever be handed in.
--
-- OUR OWN FRAME. The client's toasts belong to its AlertFrame system, which this file never uses,
-- parents to, hooks or calls: the banner is a plain frame of ours on UIParent, drawn with the
-- client's own toast art by path (UI/Assets.lua TOAST_FRAME, TOAST_ICON_BG, TOAST_FLASH and
-- TOAST_WAYPOINT, the sheet the client's small toasts draw from), and it takes no mouse, so it
-- never stands in the way of a click. Where that art will not draw, the banner is the window's own
-- dark fill in a gold edge instead.
--
-- One toast at a time: a second Show while one is up writes the new words on the same frame and
-- starts its time again, so the new one replaces the old. No sound: the waypoint press already
-- plays its click (UI/Map.lua), and the client's own toasts each play the sound of their own kind
-- rather than one of the toast system's, so there is none to copy. No setting.
--
-- The timeline (Toast.Alpha, Toast.Offset, Toast.FlashAlpha) is pure and runs under busted; the
-- frame is driven by its own OnUpdate, which the client only runs while the frame is shown, so a
-- toast costs nothing once it has gone. Everything that touches the client is below the divider
-- and guarded, so this file loads with no WoW API present.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local Toast = {}
ItemTree.UI.Toast = Toast

local Assets = ItemTree.Assets
local Theme = ItemTree.Theme
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

-- The banner is the art's own size, so the toast art is drawn one to one.
Toast.WIDTH = 311
Toast.HEIGHT = 78

-- Where it stands: top centre, this far under the screen's top edge, which keeps it over the
-- client's red error lines (UIErrorsFrame, from 122 down) rather than on them.
Toast.TOP_GAP = 48

-- Over the window (Frame.STRATA, HIGH) and its search dropdown (DIALOG).
Toast.STRATA = "FULLSCREEN_DIALOG"

-- The timeline, in seconds: in, held, out. It slides down Toast.SLIDE pixels while it fades in.
-- Brief AT5 (QA item 412, "the toast lingers a tiny bit too long"): held a second less, so it is
-- gone 3.75 seconds after it went up rather than 4.75.
Toast.FADE_IN = 0.25
Toast.HOLD = 2.5
Toast.FADE_OUT = 1
Toast.SLIDE = 16

-- The flash over the art as it arrives, the client's own toast shine: added light at this alpha,
-- gone after Toast.FLASH seconds.
Toast.FLASH = 0.6
Toast.FLASH_ALPHA = 0.7

-- The layout inside the banner: the round icon plate on the left, the words to its right.
Toast.ICON_BG_W = 47
Toast.ICON_BG_H = 52
Toast.ICON_BG_X = 16
Toast.ICON = 30
Toast.TEXT_GAP = 10
Toast.TEXT_RIGHT = 18
Toast.LINE_GAP = 3
-- The detail line wraps onto a second line rather than running off the banner.
Toast.DETAIL_LINES = 2

-- The fallback banner's edge, where the toast art will not draw.
Toast.EDGE = 1

--------------------------------------------------------------------------------
-- Pure. The timeline and the words
--------------------------------------------------------------------------------

--- How long a toast is up, from the first frame to gone.
function Toast.Duration()
  return Toast.FADE_IN + Toast.HOLD + Toast.FADE_OUT
end

--- The banner's alpha t seconds after it was shown: rising to 1 over Toast.FADE_IN, 1 while held,
--- falling to 0 over Toast.FADE_OUT, then 0. Pure.
function Toast.Alpha(t)
  t = tonumber(t) or 0
  if t <= 0 then
    return 0
  end
  if t < Toast.FADE_IN then
    return t / Toast.FADE_IN
  end
  local outFrom = Toast.FADE_IN + Toast.HOLD
  if t < outFrom then
    return 1
  end
  if t < outFrom + Toast.FADE_OUT then
    return 1 - (t - outFrom) / Toast.FADE_OUT
  end
  return 0
end

--- How far above its resting place the banner is t seconds after it was shown, in pixels: it
--- slides down from Toast.SLIDE to 0 while it fades in and rests there after. Pure.
function Toast.Offset(t)
  t = tonumber(t) or 0
  if t <= 0 then
    return Toast.SLIDE
  end
  if t < Toast.FADE_IN then
    return Toast.SLIDE * (1 - t / Toast.FADE_IN)
  end
  return 0
end

--- The arrival flash's alpha t seconds after the banner was shown: Toast.FLASH_ALPHA at once,
--- falling to nothing over Toast.FLASH. Pure.
function Toast.FlashAlpha(t)
  t = tonumber(t) or 0
  if t < 0 or t >= Toast.FLASH then
    return 0
  end
  return Toast.FLASH_ALPHA * (1 - t / Toast.FLASH)
end

--- Whether a toast shown t seconds ago is over. Pure.
function Toast.Done(t)
  return (tonumber(t) or 0) >= Toast.Duration()
end

--- The detail line as the toast writes it: trimmed, with any coordinate pair ("42.5, 71.7") and the
--- separator it leaves behind taken out, because the owner's rule is that a toast never says where
--- in numbers. nil for nothing left to say. Pure.
function Toast.Detail(text)
  if type(text) ~= "string" then
    return nil
  end
  text = text:gsub("%d+%.%d+%s*,%s*%d+%.%d+", "")
  text = text:gsub("%s+", " ")
  text = text:gsub("^[%s,;:]+", ""):gsub("[%s,;:]+$", "")
  if text == "" then
    return nil
  end
  return text
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
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

-- One method on a client object, under pcall: its first answer, or nil where it is missing or
-- raises.
local function call(object, method, ...)
  if type(object) ~= "table" or type(object[method]) ~= "function" then
    return nil
  end
  local ok, answer = pcall(object[method], object, ...)
  if ok then
    return answer
  end
  return nil
end

local function themeColor(key)
  if Theme and type(Theme.ColorTable) == "function" then
    local ok, color = pcall(Theme.ColorTable, key)
    if ok and type(color) == "table" then
      return color
    end
  end
  return nil
end

local function applyAsset(texture, key)
  if type(texture) ~= "table" or not Assets or type(Assets.Apply) ~= "function" then
    return false
  end
  local ok, drew = pcall(Assets.Apply, texture, key)
  return ok and drew == true
end

local function newTexture(frame, layer)
  local texture = call(frame, "CreateTexture", nil, layer)
  if type(texture) == "table" then
    return texture
  end
  return nil
end

-- A flat fill in one Theme colour, for the banner the toast art could not draw.
local function fill(frame, layer, colorKey)
  local texture = newTexture(frame, layer)
  if not texture then
    return nil
  end
  applyAsset(texture, "FILL_WHITE8X8")
  local color = themeColor(colorKey)
  if color then
    call(texture, "SetVertexColor", color.r, color.g, color.b, color.a or 1)
  end
  return texture
end

-- Hands the font string one of the client's own font objects, where its own face will not load.
local FONT_OBJECTS = { "GameFontNormal", "GameFontHighlight", "GameFontNormalSmall" }

local function fallbackFont(fontString)
  for _, name in ipairs(FONT_OBJECTS) do
    local object = rawget(_G, name)
    if object ~= nil and call(fontString, "SetFontObject", object) ~= false then
      return true
    end
  end
  return false
end

-- A font string that is never fontless: made on the client's own font object (the template), then
-- given the window's title face at a Theme size, its answer read, and a font object put back where
-- the face would not load. Coloured from a Theme token, with the window's one pixel shadow.
local function newText(frame, template, sizeKey, colorKey)
  local fontString = call(frame, "CreateFontString", nil, "OVERLAY", template)
  if type(fontString) ~= "table" then
    fontString = call(frame, "CreateFontString", nil, "OVERLAY")
  end
  if type(fontString) ~= "table" then
    return nil
  end
  local face = Theme and Theme.fonts and Theme.fonts.ITEMTREE_FONT_TITLE or nil
  local size = Theme and Theme.fontSizes and Theme.fontSizes[sizeKey] or 12
  if face and type(fontString.SetFont) == "function" then
    local ok, applied = pcall(fontString.SetFont, fontString, face, size, "")
    if not ok or applied == false then
      fallbackFont(fontString)
    end
  end
  local current = call(fontString, "GetFont")
  if current == nil or current == "" then
    fallbackFont(fontString)
  end
  local outline = Theme and Theme.text and Theme.text.ITEMTREE_TEXT_OUTLINE or nil
  if outline then
    call(fontString, "SetShadowOffset", outline.x, outline.y)
    call(fontString, "SetShadowColor", outline.r, outline.g, outline.b, outline.a)
  end
  local color = themeColor(colorKey)
  if color then
    call(fontString, "SetTextColor", color.r, color.g, color.b, color.a or 1)
  end
  call(fontString, "SetJustifyH", "LEFT")
  return fontString
end

local function setText(fontString, text)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  return (pcall(fontString.SetText, fontString, text or ""))
end

-- The fallback banner's gold edge: four hairlines.
local function edges(frame)
  local out = {}
  local sides = {
    { "TOPLEFT", "TOPRIGHT", "SetHeight" },
    { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
    { "TOPLEFT", "BOTTOMLEFT", "SetWidth" },
    { "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" },
  }
  for index, side in ipairs(sides) do
    local line = fill(frame, "BORDER", "ITEMTREE_COLOR_BORDER_GOLD")
    if line then
      call(line, "SetPoint", side[1], frame, side[1], 0, 0)
      call(line, "SetPoint", side[2], frame, side[2], 0, 0)
      call(line, side[3], Toast.EDGE)
      out[index] = line
    end
  end
  return out
end

-- Where the words start: right of the icon plate.
local function textLeft()
  return Toast.ICON_BG_X + Toast.ICON_BG_W + Toast.TEXT_GAP
end

-- The title stands just over the banner's middle with the detail just under it, so one line of
-- each sits centred; with no detail the title alone is centred rather than over an empty line.
local function placeTitle(frame, withDetail)
  local title = Toast.title
  if not title then
    return
  end
  call(title, "ClearAllPoints")
  if withDetail then
    call(title, "SetPoint", "BOTTOMLEFT", frame, "LEFT", textLeft(), Toast.LINE_GAP / 2)
  else
    call(title, "SetPoint", "LEFT", frame, "LEFT", textLeft(), 0)
  end
  call(title, "SetPoint", "RIGHT", frame, "RIGHT", -Toast.TEXT_RIGHT, 0)
end

-- Puts the banner where it stands t seconds in: its alpha, its slide and the flash.
local function paint(frame, t)
  call(frame, "SetAlpha", Toast.Alpha(t))
  local parent = rawget(_G, "UIParent")
  call(frame, "ClearAllPoints")
  call(frame, "SetPoint", "TOP", parent, "TOP", 0, -Toast.TOP_GAP + Toast.Offset(t))
  if Toast.flash then
    call(Toast.flash, "SetAlpha", Toast.FlashAlpha(t))
  end
end

--- Makes the banner the first time a toast is shown, and keeps it: the art (or the fallback fill
--- and edge), the icon on its plate, the two lines and the OnUpdate that runs its time. Answers the
--- frame, or nil where the client makes none.
function Toast.Build()
  if Toast.frame then
    return Toast.frame
  end
  local frame = newFrame("Frame", rawget(_G, "UIParent"))
  if not frame then
    return nil
  end
  call(frame, "SetSize", Toast.WIDTH, Toast.HEIGHT)
  call(frame, "SetFrameStrata", Toast.STRATA)
  call(frame, "EnableMouse", false)
  call(frame, "Hide")

  local art = newTexture(frame, "BACKGROUND")
  if art and applyAsset(art, "TOAST_FRAME") then
    call(art, "SetAllPoints", frame)
    Toast.art = art
  else
    if art then
      call(art, "Hide")
    end
    local background = fill(frame, "BACKGROUND", "ITEMTREE_COLOR_SURFACE_TOOLTIP")
    if background then
      call(background, "SetAllPoints", frame)
    end
    Toast.background = background
    Toast.edges = edges(frame)
  end

  local plate = newTexture(frame, "BORDER")
  if plate and applyAsset(plate, "TOAST_ICON_BG") then
    call(plate, "SetSize", Toast.ICON_BG_W, Toast.ICON_BG_H)
    call(plate, "SetPoint", "LEFT", frame, "LEFT", Toast.ICON_BG_X, 0)
  else
    -- No plate: the icon keeps the place the plate would have had.
    if plate then
      call(plate, "Hide")
    end
    plate = nil
  end
  Toast.plate = plate

  local icon = newTexture(frame, "ARTWORK")
  if icon and (applyAsset(icon, "TOAST_WAYPOINT") or applyAsset(icon, "MAP_PIN")) then
    call(icon, "SetSize", Toast.ICON, Toast.ICON)
    call(icon, "SetPoint", "CENTER", frame, "LEFT", Toast.ICON_BG_X + Toast.ICON_BG_W / 2, 0)
    Toast.icon = icon
  elseif icon then
    call(icon, "Hide")
  end

  local flash = newTexture(frame, "OVERLAY")
  if flash and applyAsset(flash, "TOAST_FLASH") then
    call(flash, "SetBlendMode", "ADD")
    call(flash, "SetPoint", "CENTER", frame, "CENTER", 0, 0)
    call(flash, "SetSize", Toast.WIDTH + 16, Toast.HEIGHT + 16)
    call(flash, "SetAlpha", 0)
    Toast.flash = flash
  elseif flash then
    call(flash, "Hide")
  end

  -- The words start right of the icon plate and stop short of the banner's right edge (the title is
  -- placed by each Show, placeTitle).
  local title = newText(frame, "GameFontNormal", "ITEMTREE_FONTSIZE_TITLE_SM", "ITEMTREE_COLOR_TEXT_TITLE")
  if title then
    call(title, "SetWordWrap", false)
    Toast.title = title
  end
  local detail = newText(frame, "GameFontHighlight", "ITEMTREE_FONTSIZE_BODY_MD", "ITEMTREE_COLOR_TEXT_BODY")
  if detail then
    call(detail, "SetPoint", "TOPLEFT", frame, "LEFT", textLeft(), -Toast.LINE_GAP / 2)
    call(detail, "SetPoint", "RIGHT", frame, "RIGHT", -Toast.TEXT_RIGHT, 0)
    call(detail, "SetWordWrap", true)
    call(detail, "SetMaxLines", Toast.DETAIL_LINES)
    Toast.detail = detail
  end

  if type(frame.SetScript) == "function" then
    pcall(frame.SetScript, frame, "OnUpdate", function(self, elapsed)
      Toast.Step(elapsed, self)
    end)
  end
  Toast.frame = frame
  return frame
end

--- Runs the shown toast's time on by elapsed seconds: the client's OnUpdate, and what a spec calls
--- in its place. Hides the banner once its time is up. Answers whether it is still up.
function Toast.Step(elapsed, frame)
  frame = frame or Toast.frame
  if type(frame) ~= "table" or not Toast.up then
    return false
  end
  Toast.elapsed = (Toast.elapsed or 0) + math.max(0, tonumber(elapsed) or 0)
  if Toast.Done(Toast.elapsed) then
    Toast.Hide()
    return false
  end
  paint(frame, Toast.elapsed)
  return true
end

--- Shows one toast: the title in gold and the detail under it (Toast.Detail's words, or none). A
--- toast already up is replaced, its words rewritten and its time started again. Answers whether it
--- is up.
function Toast.Show(title, detail)
  local frame = Toast.Build()
  if not frame then
    return false
  end
  local words = Toast.Detail(detail)
  setText(Toast.title, type(title) == "string" and title or "")
  setText(Toast.detail, words or "")
  if Toast.detail then
    if words then
      call(Toast.detail, "Show")
    else
      call(Toast.detail, "Hide")
    end
  end
  placeTitle(frame, words ~= nil)
  Toast.text = { title = title, detail = words }
  Toast.elapsed = 0
  Toast.up = true
  Toast.count = (Toast.count or 0) + 1
  paint(frame, 0)
  call(frame, "Show")
  return true
end

--- The waypoint's toast: "Waypoint added" over what the waypoint is for. Answers whether it is up.
function Toast.ShowWaypoint(detail)
  return Toast.Show(L["Waypoint added"], detail)
end

--- Puts the toast away at once. Answers whether one was up.
function Toast.Hide()
  local was = Toast.up == true
  Toast.up = nil
  Toast.elapsed = 0
  if Toast.frame then
    call(Toast.frame, "Hide")
  end
  return was
end

--- Whether a toast is up.
function Toast.Shown()
  return Toast.up == true and Toast.frame ~= nil
end
