-- Brief UI15 (QA item 209, Tom's ask through the owner, 2026-10-17): "Top right of each profession
-- window (native window) show a small 'View in ItemTree' button (maybe use the standard red button
-- style but tint the red to a dark green so it matches our itemtree logo colour)". A click opens
-- ItemTree's Professions tab on the profession that window shows.
--
-- The taint rule binds (the addon bible A1 to A3; briefs PR39 and PR40, where a tray parented to this
-- very window had the gamepad UI refuse SetPreferredGamepadInteractTarget as ItemTree):
--   * the button is ours, built whole as this folder loads (at login when the tab is on, or the moment
--     the player turns it on), on UIParent, never on the client's window; nothing is set, hooked or
--     called on that window, which is only read (IsShown, GetFrameStrata, GetEffectiveScale);
--   * the window is followed through the client's own event bus only: ProfessionsMixin:OnShow and
--     OnHide end with EventRegistry:TriggerEvent("ProfessionsFrame.Show") and
--     ("ProfessionsFrame.Hide") (Blizzard_Professions/Blizzard_ProfessionsFrame.lua:522 and :541,
--     branch forever at 1.60.1.70425), and each callback only books the work for the next tick, the
--     way UI/Frame.lua follows the settings panel (brief TX1);
--   * the button is anchored to the window's top right (SetPoint on OUR frame, the window only named
--     as the anchor, as UI/Queue.lua docks the tray) and placed and shown out of combat lockdown only;
--     a window opened in combat gets its button on PLAYER_REGEN_ENABLED if it still shows (bible A3);
--   * its strata is one above the window's, read through Util.CanRead (brief UI1: from 1.60.1.70425
--     GetFrameStrata can answer a secret), else HIGH, the tray's.
--
-- Where it sits: on Forever the window is ProfessionsFrame (Camelot/Blizzard_ProfessionsFrame.xml:10,
-- PortraitFrameTemplate). Its close button is 28 px square at the top right corner
-- (Blizzard_SharedXML/Camelot/SharedUIPanelTemplates.lua:1 to 5) and its title bar 21 px tall (the
-- template's background starts 21 px down, Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:627
-- to 632), so the button stands in the title bar, RIGHT px in from the window's right edge, clear of
-- the close button. The camelot layer puts no Maximise button there (the one at
-- Blizzard_Professions/Mainline/Blizzard_ProfessionsFrame.xml:7 is the Mainline layer's alone).
--
-- The look: the window's shared red plate button (UI/Frame.lua Frame.NewPlateButton through
-- UI/Skin.lua Skin.PlateButton, the art Craft all and Show trainers wear), its plate turned from red to
-- the logo's green (Button.Tint, Theme ITEMTREE_COLOR_LOGO_GREEN). Brief PW1 (QA item 238 b, the
-- owner: "Button should use standard button font and weight"): its words wear the client's own button
-- fonts, the ones the profession window's Create All wears on Forever: SharedButtonSmallTemplate
-- (the camelot layer's ProfessionsCraftingPageMixin:GetButtonTemplate,
-- Blizzard_Professions/Camelot/Blizzard_ProfessionsCrafting.lua:28-30) declares NormalFont
-- GameFontNormal, HighlightFont GameFontHighlight and DisabledFont GameFontDisable
-- (Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.xml:87-92, origin/forever 1.60.1.70450),
-- swapped here on hover as a client button swaps them (Button.PaintWords). Brief PW1 (238 c): the
-- plate is drawn in the client's three slices (Frame.SlicePlate), so its ends are not stretched.
--
-- Brief PW1 (238 a): a click opens ItemTree even when it has not been opened yet this session
-- (openTab). Brief PW1 (238 d): the button is one of the profession window's companions
-- (UI/Frame.lua Frame.AddProfessionsCompanion): a click on ItemTree's window puts ItemTree over the
-- button, and a click on the button gives the profession window the front.
--
-- Everything above the "Client side" divider is pure and runs under busted with no WoW API.
local _, ItemTree = ...
-- ItemTree_Professions is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Modules) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end

local Button = {}
ItemTree.ProfessionsWindowButton = Button
if type(ItemTree.Professions) == "table" then
  ItemTree.Professions.windowButton = Button
end

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

Button.WORD = L["View in ItemTree"]
-- The client's events for the window (see the head of the file).
Button.SHOW_EVENT = "ProfessionsFrame.Show"
Button.HIDE_EVENT = "ProfessionsFrame.Hide"
Button.WINDOW = "ProfessionsFrame"
-- The button: 18 px tall in the 21 px title bar, TOP px down from the window's top, RIGHT px in from
-- its right edge (the 28 px close button and a 4 px gap), the words PAD px in from each end.
Button.H = 18
Button.TOP = 2
Button.RIGHT = 32
Button.PAD = 10
Button.MIN_W = 80
-- Brief PW1 (238 b): the client's button fonts, by state (see the head of the file), and the ones
-- tried where those will not load.
Button.FONTS = { normal = "GameFontNormal", hover = "GameFontHighlight", disabled = "GameFontDisable" }
Button.FONT_TEMPLATE = Button.FONTS.normal
Button.FONT_FALLBACKS = { "GameFontNormal", "GameFontNormalSmall", "GameFontHighlight", "GameFontHighlightSmall" }
Button.GREEN = "ITEMTREE_COLOR_LOGO_GREEN"
-- The strata, lowest first, and the one taken where the window's cannot be read. Never TOOLTIP.
Button.STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
Button.STRATA_FALLBACK = "HIGH"
-- The client's panel button art (Assets BUTTON_UP, its coords an 80 by 22 texel region) is a grey rim
-- round a red body: 4 texels of rim at each end and at the top, 3 at the bottom. The body is about
-- RGB 95, 2, 3, a luminance near 0.11, which is what desaturating it leaves. Measured off the
-- extracted art (ItemTree-Data assets/blizzard/textures, 2026-10-17).
Button.ART_W, Button.ART_H = 80, 22
Button.RIM = { side = 4, top = 4, bottom = 3 }
Button.BODY_GREY = 0.11
-- The scale ratio's clamp (Button.ScaleFor).
Button.SCALE_MIN, Button.SCALE_MAX = 0.5, 2

--- The button's width for its words drawn this wide: PAD each side, never under MIN_W. Pure.
function Button.Width(textWidth)
  local w = tonumber(textWidth) or 0
  if w <= 0 then
    w = #Button.WORD * 6
  end
  return math.max(Button.MIN_W, math.floor(w + Button.PAD * 2 + 0.5))
end

--- The strata one above the given one, so the button draws over the window; never TOOLTIP (the
--- client's tooltips stay on top), and STRATA_FALLBACK for anything not a strata name. Pure.
function Button.StrataAbove(strata)
  for index, name in ipairs(Button.STRATA) do
    if name == strata then
      return Button.STRATA[math.min(index + 1, #Button.STRATA - 1)]
    end
  end
  return Button.STRATA_FALLBACK
end

--- The body wash's insets on a plate w by h: the art's rim (Button.RIM, in texels of the 80 by 22
--- art) stretched to the plate, to whole pixels. Brief PW1: on a plate drawn in three slices
--- (sliced, Frame.SlicePlate) the side rim is in the end caps, which keep the art's shape at the
--- plate's height, so it is the height's share as the top and bottom are. Answers left, right, top,
--- bottom. Pure.
function Button.FillInsets(w, h, sliced)
  w, h = tonumber(w) or 0, tonumber(h) or 0
  local side = math.floor(w * Button.RIM.side / Button.ART_W + 0.5)
  if sliced then
    side = math.floor(h * Button.RIM.side / Button.ART_H + 0.5)
  end
  local top = math.floor(h * Button.RIM.top / Button.ART_H + 0.5)
  local bottom = math.floor(h * Button.RIM.bottom / Button.ART_H + 0.5)
  return side, side, top, bottom
end

--- What the body wash adds (ADD blend) to the desaturated body's grey so the sum is the target
--- colour: each channel the target less the grey, never below 0. Answers r, g, b. Pure.
function Button.AddColour(target, grey)
  target = type(target) == "table" and target or EMPTY
  grey = tonumber(grey) or Button.BODY_GREY
  local function channel(value)
    return math.max(0, (tonumber(value) or 0) - grey)
  end
  return channel(target.r), channel(target.g), channel(target.b)
end

--- The button's scale against its parent's so it reads at the window's own size: the window's
--- effective scale over the parent's, held to SCALE_MIN and SCALE_MAX, 1 where either is unknown.
--- Pure.
function Button.ScaleFor(windowScale, parentScale)
  windowScale, parentScale = tonumber(windowScale), tonumber(parentScale)
  if not windowScale or not parentScale or windowScale <= 0 or parentScale <= 0 then
    return 1
  end
  local ratio = windowScale / parentScale
  return math.max(Button.SCALE_MIN, math.min(Button.SCALE_MAX, ratio))
end

--- The skill lines the window may be showing, most specific first: the child profession's id and
--- its parent's, then the base profession's (C_TradeSkillUI's ProfessionInfo; Core\Craft.lua's
--- Craft.IsOpen matches either id the same way). Numbers above 0, each once. Pure.
function Button.Candidates(base, child)
  local out, seen = {}, {}
  local infos = { child, base }
  for index = 1, 2 do
    local info = infos[index]
    if type(info) == "table" then
      for _, key in ipairs({ "professionID", "parentProfessionID" }) do
        local id = tonumber(info[key])
        if id and id > 0 and not seen[id] then
          seen[id] = true
          out[#out + 1] = id
        end
      end
    end
  end
  return out
end

--- The line to open the tab on: the first candidate the player has (skills, Frame.PlayerSkills'
--- shape, keyed by skill line), else the first the route data holds (lines), else nil (the tab
--- opens on the line it last showed). Pure.
function Button.PickLine(candidates, skills, lines)
  skills = type(skills) == "table" and skills or EMPTY
  lines = type(lines) == "table" and lines or EMPTY
  for _, pool in ipairs({ skills, lines }) do
    for _, id in ipairs(type(candidates) == "table" and candidates or EMPTY) do
      if pool[id] ~= nil then
        return id
      end
    end
  end
  return nil
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

local globalFn = ItemTree.Util.GlobalFn
local Kit = ItemTree.ProfessionsKit
local colourOf = Kit.ColourOf
local setShown = Kit.SetShown
local newTexture = Kit.NewTexture
local applyAsset = Kit.ApplyAsset

-- Whether a client value may be compared (bible B10). Asked at call time, so a spec's fake answers.
local function canRead(value)
  local util = ItemTree.Util
  if type(util) ~= "table" or type(util.CanRead) ~= "function" then
    return true
  end
  local ok, readable = pcall(util.CanRead, value)
  return ok and readable == true
end

local function inCombat()
  local ask = globalFn("InCombatLockdown")
  if not ask then
    return false
  end
  local ok, locked = pcall(ask)
  return ok and locked == true
end

-- One CreateFrame call of ours, on UIParent or with no parent at all.
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

local function setScript(frame, script, handler)
  if type(frame) ~= "table" or type(frame.SetScript) ~= "function" then
    return false
  end
  return (pcall(frame.SetScript, frame, script, Kit.GuardScript("Professions.WindowButton." .. script, handler)))
end

-- A number a client frame's getter answers, readable and above 0, or nil.
local function readNumber(frame, method)
  if type(frame) ~= "table" or type(frame[method]) ~= "function" then
    return nil
  end
  local ok, value = pcall(frame[method], frame)
  if not ok or not canRead(value) then
    return nil
  end
  value = tonumber(value)
  if value and value > 0 then
    return value
  end
  return nil
end

-- The client's profession window when it shows, or nil. Read only.
local function shownWindow()
  local window = rawget(_G, Button.WINDOW)
  if type(window) ~= "table" or type(window.IsShown) ~= "function" then
    return nil
  end
  local ok, shown = pcall(window.IsShown, window)
  if ok and canRead(shown) and shown == true then
    return window
  end
  return nil
end

-- Whether the Professions tab is on and its folder loaded (UI/ProfessionsStub.lua Active), which is
-- when ItemTree has a tab to open. True where the stub is not there to ask.
local function tabOn()
  local ui = ItemTree.UI
  local stub = type(ui) == "table" and ui.ProfessionsStub or nil
  if type(stub) ~= "table" or type(stub.Active) ~= "function" then
    return true
  end
  local ok, on = pcall(stub.Active)
  return ok and on == true
end

-- Runs fn on the next frame tick, or straight away on a client with no C_Timer.
local function nextTick(fn)
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" and pcall(timer.After, 0, fn) then
    return true
  end
  fn()
  return false
end

-- Font safety (UI/Sidebar.lua's shape): a FontString with no font raises "Font not set" on SetText,
-- and SetFont answers false rather than raising when the face will not load, so the answer is read and
-- a client font object put on before any SetText.
local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(Button.FONT_FALLBACKS) do
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

-- Brief PW1 (238 b): the words in the client's own button font for a state ("normal", "hover" or
-- "disabled", Button.FONTS), its colour the font object's own (gold, white, grey), as the client's
-- Button swaps its Normal, Highlight and Disabled fonts. Answers whether the font went on.
function Button.PaintWords(state)
  local button = Button.frame
  local fontString = type(button) == "table" and rawget(button, "label") or nil
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  if state ~= "disabled" and type(button.IsEnabled) == "function" then
    local ok, enabled = pcall(button.IsEnabled, button)
    if ok and enabled == false then
      state = "disabled"
    end
  end
  local object = rawget(_G, Button.FONTS[state] or Button.FONTS.normal)
  if object == nil then
    return ensureFont(fontString)
  end
  local ok, applied = pcall(fontString.SetFontObject, fontString, object)
  ensureFont(fontString)
  return ok and applied ~= false
end

local function newLabel(parent)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY", Button.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY")
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  -- Brief PW1 (238 b): the client's GameFontNormal, face, size and gold alike, where ItemTree's
  -- body font used to be set over it.
  local object = rawget(_G, Button.FONTS.normal)
  if object ~= nil and type(fontString.SetFontObject) == "function" then
    pcall(fontString.SetFontObject, fontString, object)
  end
  ensureFont(fontString)
  if type(fontString.SetJustifyH) == "function" then
    pcall(fontString.SetJustifyH, fontString, "CENTER")
  end
  if type(fontString.SetWordWrap) == "function" then
    pcall(fontString.SetWordWrap, fontString, false)
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

--- The plate in the logo's green. A tint only darkens, and the red body has almost no green in it,
--- so the red cannot be tinted green as it is: the plate's normal and pushed art is desaturated (its
--- rim stays the grey it already is, its body goes a dark grey near BODY_GREY) and a flat wash inside
--- the rim (Button.FillInsets) adds the rest of the logo's green (ADD, Button.AddColour), so the body
--- reads the logo's green and keeps the art's own shading; the pushed art, darker, reads a darker
--- green. The highlight keeps the client's gold glow. Where the window drew its own flat plate
--- instead (no client art), its face takes the green as it is. Answers "art", "flat" or false.
function Button.Tint(button)
  if type(button) ~= "table" then
    return false
  end
  local green = colourOf(Button.GREEN)
  if not green then
    return false
  end
  local plate = rawget(button, "plate")
  if type(plate) ~= "table" then
    local face = rawget(button, "background")
    if type(face) == "table" and type(face.SetVertexColor) == "function" then
      pcall(face.SetVertexColor, face, green.r, green.g, green.b, 1)
      return "flat"
    end
    return false
  end
  local caps = type(plate.caps) == "table" and plate.caps or EMPTY
  for _, key in ipairs({ "normal", "pushed" }) do
    -- Brief PW1: a sliced plate's end caps (Frame.SlicePlate) go green with their middle.
    local pair = type(caps[key]) == "table" and caps[key] or EMPTY
    for _, texture in ipairs({ plate[key], pair.left, pair.right }) do
      if type(texture) == "table" and type(texture.SetDesaturated) == "function" then
        pcall(texture.SetDesaturated, texture, true)
      end
    end
  end
  local wash = rawget(button, "greenWash") or newTexture(button, "BACKGROUND", 1)
  if not wash or not applyAsset(wash, "FILL_WHITE8X8") then
    return false
  end
  button.greenWash = wash
  if type(wash.SetBlendMode) == "function" then
    pcall(wash.SetBlendMode, wash, "ADD")
  end
  local r, g, b = Button.AddColour(green, Button.BODY_GREY)
  pcall(wash.SetVertexColor, wash, r, g, b, 1)
  local w = readNumber(button, "GetWidth") or Button.MIN_W
  local left, right, top, bottom = Button.FillInsets(w, Button.H, rawget(plate, "cap") ~= nil)
  pcall(wash.ClearAllPoints, wash)
  pcall(wash.SetPoint, wash, "TOPLEFT", button, "TOPLEFT", left, -top)
  pcall(wash.SetPoint, wash, "BOTTOMRIGHT", button, "BOTTOMRIGHT", -right, bottom)
  setShown(wash, true)
  return "art"
end

-- The opening itself: the line the window shows picked on the pane, then the ItemTree window on the
-- Professions tab (UI/Frame.lua's own public Open and SelectTab, as UI/Queue.lua's "Back to
-- ItemTree" link does), then the pane drawn again where it was already up on another line.
-- Brief PW1 (QA item 238 a, the owner: "Button does nothing when clicked if itemtree has not been
-- opened yet"): Frame.Open with no item reopens the page the window last showed, and before the
-- first open of a session there is none (UI/Frame.lua Frame.Open answers false at
-- `if not (frame and key)`), so nothing showed. Then the window opens on the page its key binding
-- opens with nothing pointed at (Frame.OpenDefaultPage: a New in Forever item), and the tab follows.
local function openTab(line)
  local professions = ItemTree.Professions
  local pane = type(professions) == "table" and professions.pane or nil
  if line and type(pane) == "table" then
    pane.selected = line
  end
  local ui = ItemTree.UI
  local window = type(ui) == "table" and ui.Frame or nil
  if type(window) ~= "table" or type(window.Open) ~= "function" then
    return false
  end
  local called, opened = pcall(window.Open)
  local ok = called and opened ~= false
  if not ok and type(window.OpenDefaultPage) == "function" then
    called, opened = pcall(window.OpenDefaultPage)
    ok = called and opened == true
  end
  local stub = type(ui) == "table" and ui.ProfessionsStub or nil
  local tab = type(stub) == "table" and stub.TAB_NAME or "Professions"
  if type(window.SelectTab) == "function" then
    pcall(window.SelectTab, tab)
  end
  if type(pane) == "table" and type(pane.Refresh) == "function" then
    pcall(pane.Refresh)
  end
  return ok
end

-- The profession the client's window holds now, read only: C_TradeSkillUI's base and child
-- profession info, each value read through Util.CanRead.
local function windowCandidates()
  local api = rawget(_G, "C_TradeSkillUI")
  if type(api) ~= "table" then
    return {}
  end
  local function info(name)
    if type(api[name]) ~= "function" then
      return nil
    end
    local ok, answer = pcall(api[name])
    if not ok or type(answer) ~= "table" then
      return nil
    end
    local out = {}
    for _, key in ipairs({ "professionID", "parentProfessionID" }) do
      local value = answer[key]
      if canRead(value) then
        out[key] = value
      end
    end
    return out
  end
  return Button.Candidates(info("GetBaseProfessionInfo"), info("GetChildProfessionInfo"))
end

local function playerSkills()
  local model = ItemTree.ProfessionsModel
  if type(model) == "table" and type(model.Facts) == "function" then
    local ok, skills = pcall(model.Facts)
    if ok and type(skills) == "table" then
      return skills
    end
  end
  local ui = ItemTree.UI
  local window = type(ui) == "table" and ui.Frame or nil
  if type(window) == "table" and type(window.PlayerSkills) == "function" then
    local ok, skills = pcall(window.PlayerSkills)
    if ok and type(skills) == "table" then
      return skills
    end
  end
  return {}
end

--- A click: ItemTree's Professions tab on the profession the window shows (Button.PickLine over the
--- player's skills, then the route data's lines), else on the line it last showed. Answers the line
--- picked (or true where none was) when the window opened, else false.
function Button.Click()
  local tracks = ItemTree.ProfessionTracks
  local lines = type(tracks) == "table" and type(tracks.lines) == "table" and tracks.lines or nil
  local line = Button.PickLine(windowCandidates(), playerSkills(), lines)
  if not openTab(line) then
    return false
  end
  return line or true
end

-- Books Button.Place for PLAYER_REGEN_ENABLED, on our own event frame. Answers whether it booked.
local function bookAfterCombat()
  local events = Button.events
  if type(events) ~= "table" or type(events.RegisterEvent) ~= "function" then
    return false
  end
  Button.pending = true
  return (pcall(events.RegisterEvent, events, "PLAYER_REGEN_ENABLED"))
end

local function letGoOfCombat()
  Button.pending = false
  local events = Button.events
  if type(events) == "table" and type(events.UnregisterEvent) == "function" then
    pcall(events.UnregisterEvent, events, "PLAYER_REGEN_ENABLED")
  end
end

--- Places and shows the button at the window's top right, one strata over it, while the window
--- shows and the tab is on; hides it otherwise. In combat lockdown nothing is placed or shown and
--- the work is booked for PLAYER_REGEN_ENABLED. Answers "shown", "hidden" or "combat".
function Button.Place()
  local button = Button.frame
  local window = shownWindow()
  if type(button) ~= "table" or not window or not tabOn() then
    letGoOfCombat()
    setShown(button, false)
    return "hidden"
  end
  if inCombat() then
    bookAfterCombat()
    return "combat"
  end
  letGoOfCombat()
  local parent = rawget(_G, "UIParent")
  local scale = Button.ScaleFor(readNumber(window, "GetEffectiveScale"), readNumber(parent, "GetEffectiveScale"))
  if type(button.SetScale) == "function" then
    pcall(button.SetScale, button, scale)
  end
  pcall(button.ClearAllPoints, button)
  pcall(button.SetPoint, button, "TOPRIGHT", window, "TOPRIGHT", -Button.RIGHT, -Button.TOP)
  -- Brief UI1's guard: an unreadable strata is never compared; the fallback stands in.
  local strata = nil
  if type(window.GetFrameStrata) == "function" then
    local ok, answer = pcall(window.GetFrameStrata, window)
    if ok and canRead(answer) and type(answer) == "string" then
      strata = answer
    end
  end
  if type(button.SetFrameStrata) == "function" then
    pcall(button.SetFrameStrata, button, Button.StrataAbove(strata))
  end
  setShown(button, true)
  return "shown"
end

--- The window has shown: the button is placed a tick later, after the client's own show has run.
function Button.OnWindowShown()
  return nextTick(Button.Place)
end

--- The window has gone: the button goes with it (our own frame on UIParent; a plain Hide is never
--- refused) and any booking for the end of combat is let go.
function Button.OnWindowHidden()
  letGoOfCombat()
  return setShown(Button.frame, false)
end

-- The client's event bus, EventRegistry (Blizzard_SharedXML, loaded before any addon), with this
-- table as the callbacks' owner. Answers whether both were taken.
local function watch()
  local registry = rawget(_G, "EventRegistry")
  if type(registry) ~= "table" or type(registry.RegisterCallback) ~= "function" then
    return false
  end
  if Button.registry == registry then
    return true
  end
  local okShow = pcall(registry.RegisterCallback, registry, Button.SHOW_EVENT, function()
    Button.OnWindowShown()
  end, Button)
  local okHide = pcall(registry.RegisterCallback, registry, Button.HIDE_EVENT, function()
    Button.OnWindowHidden()
  end, Button)
  if okShow and okHide then
    Button.registry = registry
  end
  return Button.registry == registry
end
Button.Watch = watch

--- Builds the button whole, hidden, on UIParent, once, and starts following the window. Answers the
--- button, or nil where the client makes no frame.
function Button.Build()
  if Button.frame then
    return Button.frame
  end
  local parent = rawget(_G, "UIParent")
  local skin = Kit.Skin()
  local button = nil
  if skin and type(skin.PlateButton) == "function" then
    local ok, made = pcall(skin.PlateButton, parent, Button.MIN_W, Button.H)
    button = ok and type(made) == "table" and made or nil
  end
  if not button then
    button = newFrame("Button", parent)
    if not button then
      return nil
    end
    button.background = newTexture(button, "BACKGROUND")
    if button.background then
      applyAsset(button.background, "FILL_WHITE8X8")
      pcall(button.background.SetAllPoints, button.background, button)
    end
    if type(button.RegisterForClicks) == "function" then
      pcall(button.RegisterForClicks, button, "LeftButtonUp")
    end
  end
  button.canPress = true
  button.label = newLabel(rawget(button, "labelParent") or button)
  if button.label then
    setText(button.label, Button.WORD)
    pcall(button.label.SetPoint, button.label, "CENTER", button, "CENTER", 0, 0)
  end
  local width = Button.Width(Kit.StringWidth(button.label))
  pcall(button.SetSize, button, width, Button.H)
  Button.Tint(button)
  -- Brief PW1 (238 b): the words swap to the client's highlight font under the pointer.
  local words = {
    OnEnter = function()
      Button.PaintWords("hover")
    end,
    OnLeave = function()
      Button.PaintWords("normal")
    end,
    OnHide = function()
      Button.PaintWords("normal")
    end,
  }
  if rawget(button, "plated") and skin and type(skin.PlateScripts) == "function" then
    pcall(skin.PlateScripts, button, setScript, words)
    if type(skin.PaintPlate) == "function" then
      pcall(skin.PaintPlate, button, "normal")
    end
  else
    setScript(button, "OnEnter", words.OnEnter)
    setScript(button, "OnLeave", words.OnLeave)
  end
  setScript(button, "OnClick", function()
    Button.Click()
  end)
  pcall(button.Hide, button)
  Button.frame = button
  Button.PaintWords("normal")
  -- Brief PW1 (238 d): the button belongs with the profession window: a click on it gives that
  -- window the front over ItemTree's (UI/Frame.lua Frame.AddProfessionsCompanion).
  local main = type(ItemTree.UI) == "table" and ItemTree.UI.Frame or nil
  if type(main) == "table" and type(main.AddProfessionsCompanion) == "function" then
    pcall(main.AddProfessionsCompanion, button)
  end
  local events = newFrame("Frame")
  if events then
    setScript(events, "OnEvent", function(_, event)
      if event == "PLAYER_REGEN_ENABLED" and Button.pending then
        Button.Place()
      end
    end)
    Button.events = events
  end
  watch()
  -- The Professions tab turned off or on while the window shows: the button follows at once. An
  -- addon callback UI/Options.lua fires after every setting change (the stub listens the same way).
  if type(ItemTree.RegisterCallback) == "function" then
    pcall(ItemTree.RegisterCallback, Button, "ITEMTREE_SETTING_CHANGED", function(_, key)
      local ui = ItemTree.UI
      local stub = type(ui) == "table" and ui.ProfessionsStub or nil
      if key == (type(stub) == "table" and stub.SETTING or "showProfessions") then
        Button.Place()
      end
    end)
  end
  -- The window may already show (the tab turned on with it open): placed now, the same way.
  if shownWindow() then
    Button.OnWindowShown()
  end
  return button
end

Button.Build()

return Button
