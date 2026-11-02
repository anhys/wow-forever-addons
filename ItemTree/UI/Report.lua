-- The /itemtree report window: every diagnostic line in one selectable edit box, so the state
-- can be pasted into an issue instead of screenshotted out of chat.
--
-- Report.Text is the whole report as one string: Slash.DebugLines, a blank line, then the trace
-- lines UI/Tooltip.lua remembered. It is pure and unit tested, so what the window shows is
-- decided with no client present and only the frame is guarded.
--
-- The window is built once, lazily, the first time it is asked for. A title bar drags it, the
-- close button and Escape close it, and on every show the text is refreshed, the edit box takes
-- focus and all of it is highlighted, so copying is one keystroke. The edit box is read only in
-- effect: it takes the player's text back out from under them rather than being disabled, since
-- a disabled edit box on these clients will not hand its selection to the clipboard.
--
-- Nothing here is written to saved variables, and nothing here reads character, realm or
-- account data: the report is build ids, module counts, settings, counters and item ids.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local Report = {}
ItemTree.UI.Report = Report

local Assets = ItemTree.Assets
local Theme = ItemTree.Theme
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

Report.WIDTH = 560
Report.HEIGHT = 360
Report.FRAME_NAME = "ItemTreeReportFrame"

-- Everything /itemtree debug prints, a blank line, then the remembered trace lines oldest
-- first. Each source is read through a type check and a pcall, so a half loaded addon reports
-- what it has rather than raising in the middle of a slash command. Pure.
function Report.Text()
  local lines = {}

  local slash = ItemTree.Slash
  if slash and type(slash.DebugLines) == "function" then
    local ok, debugLines = pcall(slash.DebugLines)
    if ok and type(debugLines) == "table" then
      for _, line in ipairs(debugLines) do
        lines[#lines + 1] = tostring(line)
      end
    end
  end

  lines[#lines + 1] = ""

  local tooltip = ItemTree.Tooltip
  if tooltip and type(tooltip.RecentLines) == "function" then
    local ok, recent = pcall(tooltip.RecentLines)
    if ok and type(recent) == "table" then
      for _, line in ipairs(recent) do
        lines[#lines + 1] = tostring(line)
      end
    end
  end

  return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- One CreateFrame call, pcall'd. A client that does not carry the template still gets its
-- frame, without the art; a client with no CreateFrame at all gets nothing, which is what
-- leaves Show returning false under busted.
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

-- A texture path through UI/Assets.lua, or nil. Assets.Get raises on an unknown key, so the
-- key is asked for first and the answer is only ever used as a backdrop file.
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

-- Theme.Color raises on an unknown key, so the table is read instead and a missing key leaves
-- the client's own colour alone. Same idiom as UI/Tooltip.lua.
local function themeColor(key)
  local color = Theme and type(Theme.ColorTable) == "function" and Theme.ColorTable(key) or nil
  if not color then
    return nil
  end
  return color.r, color.g, color.b
end

-- The client's tooltip border and background, which every client since Classic Era carries.
-- BackdropTemplate is what puts SetBackdrop on the frame; a client without it simply has no
-- border, and the window still works.
local function applyBackdrop(frame)
  if type(frame.SetBackdrop) ~= "function" then
    return false
  end
  local ok = pcall(frame.SetBackdrop, frame, {
    bgFile = assetPath("TOOLTIP_BACKGROUND"),
    edgeFile = assetPath("TOOLTIP_BORDER"),
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  if ok and type(frame.SetBackdropColor) == "function" then
    pcall(frame.SetBackdropColor, frame, 0, 0, 0, 0.92)
  end
  return ok
end

-- Escape closes the window. UISpecialFrames is keyed by frame name, so the frame is created
-- with one, and the name is only added once however often the window is rebuilt.
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

-- Sets the text without the read only guard treating our own write as the player typing. The
-- flag is ours rather than the client's user input argument, because a client that does not
-- pass that argument would leave SetText calling the guard calling SetText for ever.
local filling = false

local function fill(editBox, text)
  filling = true
  editBox:SetText(text or "")
  filling = false
end

local function titleBar(frame)
  local bar = newFrame("Frame", nil, frame)
  if not bar then
    return nil
  end
  bar:SetHeight(26)
  bar:SetPoint("TOPLEFT", 6, -6)
  bar:SetPoint("TOPRIGHT", -6, -6)
  bar:EnableMouse(true)
  if type(bar.RegisterForDrag) == "function" and type(frame.StartMoving) == "function" then
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function()
      frame:StartMoving()
    end)
    bar:SetScript("OnDragStop", function()
      frame:StopMovingOrSizing()
    end)
  end

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", bar, "TOP", 0, -4)
  title:SetText(L["ItemTree report"])
  local r, g, b = themeColor("ITEMTREE_COLOR_TEXT_TITLE")
  if r and type(title.SetTextColor) == "function" then
    title:SetTextColor(r, g, b)
  end
  return bar
end

-- The client's own close button where it has one, and a labelled button where it does not.
local function closeButton(frame)
  local button = newFrame("Button", nil, frame, "UIPanelCloseButton")
  if button and type(button.GetNormalTexture) == "function" and button:GetNormalTexture() then
    button:SetPoint("TOPRIGHT", -4, -4)
  else
    button = newFrame("Button", nil, frame, "UIPanelButtonTemplate")
    if not button then
      return nil
    end
    button:SetSize(90, 22)
    button:SetPoint("BOTTOMRIGHT", -12, 10)
    if type(button.SetText) == "function" then
      button:SetText(L["Close"])
    end
  end
  button:SetScript("OnClick", function()
    Report.Hide()
  end)
  return button
end

local function reportEditBox(scroll)
  local editBox = newFrame("EditBox", nil, scroll)
  if not editBox then
    return nil
  end
  editBox:SetMultiLine(true)
  editBox:SetAutoFocus(false)
  editBox:SetWidth(Report.WIDTH - 60)
  -- The chat font is the one the player already reads pasted text in. A client with neither
  -- font object keeps whatever the edit box came with, rather than being handed nothing.
  local font = rawget(_G, "ChatFontNormal") or rawget(_G, "GameFontHighlightSmall")
  if font then
    editBox:SetFontObject(font)
  end
  -- Read only in effect: the player's write is taken straight back out, rather than the box
  -- being disabled, since a disabled edit box will not hand its selection to the clipboard.
  editBox:SetScript("OnTextChanged", function(self)
    if filling then
      return
    end
    fill(self, Report.text)
    self:HighlightText()
  end)
  editBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    Report.Hide()
  end)
  return editBox
end

-- Builds the window once. Returns nil outside the client, or on a client that will not give us
-- an edit box to put the report in, which leaves /itemtree report printing to chat instead.
function Report.Build()
  if Report.frame then
    return Report.frame
  end
  local parent = rawget(_G, "UIParent")
  local frame = newFrame("Frame", Report.FRAME_NAME, parent, "BackdropTemplate")
  if not frame then
    return nil
  end
  frame:SetSize(Report.WIDTH, Report.HEIGHT)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:Hide()
  applyBackdrop(frame)
  titleBar(frame)
  closeButton(frame)

  local scroll = newFrame("ScrollFrame", Report.FRAME_NAME .. "Scroll", frame, "UIPanelScrollFrameTemplate")
  local editBox = scroll and reportEditBox(scroll) or nil
  if not editBox then
    frame:Hide()
    return nil
  end
  scroll:SetPoint("TOPLEFT", 14, -36)
  scroll:SetPoint("BOTTOMRIGHT", -34, 40)
  scroll:SetScrollChild(editBox)

  local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", 16, 16)
  hint:SetText(L["Everything is selected: copy with Ctrl C or Cmd C"])

  registerEscape(Report.FRAME_NAME)
  Report.frame = frame
  Report.scroll = scroll
  Report.editBox = editBox
  return frame
end

-- Shows the window on a fresh report, with every line selected so the player only has to copy.
--
-- text is optional. With nothing handed in the window shows Report.Text, which is what
-- /itemtree report asks for. Another module can hand its own string in instead and reuse this
-- one copy window rather than building a second: it is the read only edit box, the select all
-- and the Escape handling that are worth sharing, and none of that is about the report.
--
-- Returns false where there is no client to build a window on, which is what tells the slash
-- command to print the lines instead.
function Report.Show(text)
  local frame = Report.frame or Report.Build()
  if not frame then
    return false
  end
  if type(text) == "string" then
    Report.text = text
  else
    Report.text = Report.Text()
  end
  local editBox = Report.editBox
  if editBox then
    fill(editBox, Report.text)
    if type(editBox.SetCursorPosition) == "function" then
      pcall(editBox.SetCursorPosition, editBox, 0)
    end
    pcall(editBox.SetFocus, editBox)
    pcall(editBox.HighlightText, editBox)
  end
  if Report.scroll and type(Report.scroll.SetVerticalScroll) == "function" then
    pcall(Report.scroll.SetVerticalScroll, Report.scroll, 0)
  end
  frame:Show()
  return true
end

function Report.Hide()
  local frame = Report.frame
  if not frame or type(frame.Hide) ~= "function" then
    return false
  end
  local editBox = Report.editBox
  if editBox and type(editBox.ClearFocus) == "function" then
    editBox:ClearFocus()
  end
  frame:Hide()
  return true
end

return Report
