--[[
    QuestMaster Options Module
    Premium settings panel inspired by SWTOR, GW2, and modern MMO UIs
    Clean, elegant design with proper spacing and boundaries
]]

local addonName, QM = ...
local L = QM.L

local SettingsFrame = nil
local activeMenus = {}

-- ============================================================================
-- Design System - SWTOR/GW2 Inspired Colors
-- ============================================================================

local COLORS = {
    -- Primary - Theme accent colors (will be updated by ApplyTheme)
    gold = {0.95, 0.78, 0.25},
    goldBright = {1, 0.88, 0.45},
    goldDark = {0.65, 0.50, 0.15},

    -- Secondary - Cool Blue (SWTOR inspired)
    blue = {0.35, 0.65, 0.95},
    blueDark = {0.2, 0.4, 0.7},

    -- Backgrounds - Deep & Clean
    bgDarkest = {0.04, 0.04, 0.05},
    bgDark = {0.06, 0.06, 0.07},
    bgMedium = {0.09, 0.09, 0.11},
    bgLight = {0.13, 0.13, 0.15},
    bgCard = {0.075, 0.075, 0.09},

    -- Sidebar
    sidebarBg = {0.03, 0.03, 0.035},
    sidebarHover = {0.09, 0.08, 0.07},
    sidebarActive = {0.11, 0.09, 0.06},

    -- Text
    textBright = {1, 1, 1},
    textWhite = {0.92, 0.92, 0.92},
    textGray = {0.65, 0.65, 0.65},
    textMuted = {0.45, 0.45, 0.45},
    textDark = {0.3, 0.3, 0.3},

    -- Status
    enabled = {0.35, 0.85, 0.45},
    enabledDark = {0.2, 0.5, 0.25},
    disabled = {0.35, 0.35, 0.4},
    error = {0.95, 0.35, 0.35},

    -- Borders
    border = {0.22, 0.20, 0.18},
    borderLight = {0.32, 0.28, 0.24},
    borderGold = {0.55, 0.45, 0.2},
}

-- Table to store theme-dependent elements for refresh
local themedElements = {}

-- Register themed element for refresh (forward declaration)
local function RegisterThemedElement(element, elemType, alpha)
    table.insert(themedElements, {element = element, type = elemType, alpha = alpha})
end

-- Layout Constants
local CONTENT_WIDTH = 480
local TOGGLE_WIDTH = 44
local TOGGLE_HEIGHT = 22
local CARD_PADDING = 12
local ITEM_SPACING = 42

-- Fonts
local FONT = "Fonts\\FRIZQT__.TTF"
local FONT_SIZES = {
    huge = 20,
    large = 14,
    title = 12,
    normal = 11,
    small = 10,
    tiny = 9,
}

-- Tab Configuration
local TABS = {
    {id = "general", name = L["TAB_GENERAL"], icon = "Interface\\Icons\\INV_Misc_Gear_01", desc = L["TAB_GENERAL_DESC"]},
    {id = "tracker", name = L["TAB_TRACKER"], icon = "Interface\\Icons\\INV_Misc_Note_01", desc = L["TAB_TRACKER_DESC"]},
    {id = "arrow", name = L["TAB_ARROW"], icon = "Interface\\Icons\\Ability_Hunter_Pathfinding", desc = L["TAB_ARROW_DESC"]},
    {id = "map", name = L["TAB_MAP"], icon = "Interface\\WorldMap\\UI-World-Icon", desc = L["TAB_MAP_DESC"]},
    {id = "stats", name = L["TAB_STATISTICS"], icon = "Interface\\Icons\\INV_Misc_PocketWatch_02", desc = L["TAB_STATISTICS_DESC"]},
    {id = "dashboard", name = L["TAB_DASHBOARD"], icon = "Interface\\Icons\\INV_Misc_Book_09", desc = L["TAB_DASHBOARD_DESC"]},
    {id = "auto", name = L["TAB_AUTOMATION"], icon = "Interface\\Icons\\Spell_Nature_TimeStop", desc = L["TAB_AUTOMATION_DESC"]},
    {id = "advanced", name = L["TAB_ADVANCED"], icon = "Interface\\Icons\\Trade_Engineering", desc = L["TAB_ADVANCED_DESC"]},
    {id = "credits", name = L["TAB_CREDITS"], icon = "Interface\\Icons\\INV_Misc_Note_06", desc = L["TAB_CREDITS_DESC"]},
}

-- ============================================================================
-- Utility Functions
-- ============================================================================

local function CloseAllMenus()
    for _, menu in pairs(activeMenus) do
        if menu and menu:IsShown() then menu:Hide() end
    end
    wipe(activeMenus)
end

-- ============================================================================
-- UI Components with Fixed Boundaries
-- ============================================================================

-- Section Card with proper sizing
local function CreateCard(parent, y, title, iconPath, contentHeight)
    local cardHeight = contentHeight + 44  -- Header + padding

    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(CONTENT_WIDTH, cardHeight)
    card:SetPoint("TOPLEFT", 8, y)
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    card:SetBackdropColor(COLORS.bgCard[1], COLORS.bgCard[2], COLORS.bgCard[3], 0.95)
    card:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], 0.7)

    -- Gold top accent (register for theme updates)
    local accent = card:CreateTexture(nil, "ARTWORK", nil, 1)
    accent:SetHeight(2)
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.5)
    RegisterThemedElement(accent, "accent", 0.5)

    -- Header bar
    local headerBar = card:CreateTexture(nil, "BACKGROUND", nil, 1)
    headerBar:SetHeight(30)
    headerBar:SetPoint("TOPLEFT", 1, -1)
    headerBar:SetPoint("TOPRIGHT", -1, -1)
    headerBar:SetColorTexture(0, 0, 0, 0.25)

    -- Icon
    if iconPath then
        local icon = card:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("TOPLEFT", 10, -8)
        icon:SetTexture(iconPath)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    -- Title (register for theme updates)
    local titleText = card:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(FONT, FONT_SIZES.title, "")
    titleText:SetPoint("TOPLEFT", iconPath and 34 or 10, -10)
    titleText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    titleText:SetText(title)
    RegisterThemedElement(titleText, "title")

    -- Content area with fixed width
    card.content = CreateFrame("Frame", nil, card)
    card.content:SetPoint("TOPLEFT", CARD_PADDING, -36)
    card.content:SetPoint("BOTTOMRIGHT", -CARD_PADDING, CARD_PADDING)
    card.contentWidth = CONTENT_WIDTH - (CARD_PADDING * 2)

    return card, y - cardHeight - 10
end

-- Toggle Switch with FIXED boundaries
local function CreateToggle(parent, y, label, desc, getValue, setValue)
    local rowHeight = 38
    local contentWidth = parent.contentWidth or (parent:GetWidth() - 24)
    local textWidth = contentWidth - TOGGLE_WIDTH - 20  -- Space for toggle + gap

    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(contentWidth, rowHeight)
    row:SetPoint("TOPLEFT", 0, y)

    -- Label (left side, constrained width)
    local labelText = row:CreateFontString(nil, "OVERLAY")
    labelText:SetFont(FONT, FONT_SIZES.normal, "")
    labelText:SetPoint("TOPLEFT", 0, -4)
    labelText:SetWidth(textWidth)
    labelText:SetJustifyH("LEFT")
    labelText:SetText(label)
    labelText:SetTextColor(COLORS.textWhite[1], COLORS.textWhite[2], COLORS.textWhite[3])

    -- Description (left side, constrained width)
    if desc then
        local descText = row:CreateFontString(nil, "OVERLAY")
        descText:SetFont(FONT, FONT_SIZES.small, "")
        descText:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 0, -2)
        descText:SetWidth(textWidth)
        descText:SetJustifyH("LEFT")
        descText:SetText(desc)
        descText:SetTextColor(COLORS.textMuted[1], COLORS.textMuted[2], COLORS.textMuted[3])
    end

    -- Toggle track (right side, fixed position)
    local track = CreateFrame("Frame", nil, row, "BackdropTemplate")
    track:SetSize(TOGGLE_WIDTH, TOGGLE_HEIGHT)
    track:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    track:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    -- Knob
    local knob = CreateFrame("Frame", nil, track, "BackdropTemplate")
    knob:SetSize(18, 18)
    knob:SetFrameLevel(track:GetFrameLevel() + 1)
    knob:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    local function UpdateState(enabled)
        if enabled then
            track:SetBackdropColor(COLORS.enabled[1] * 0.4, COLORS.enabled[2] * 0.4, COLORS.enabled[3] * 0.4, 1)
            track:SetBackdropBorderColor(COLORS.enabled[1] * 0.6, COLORS.enabled[2] * 0.6, COLORS.enabled[3] * 0.6, 1)
            knob:ClearAllPoints()
            knob:SetPoint("RIGHT", track, "RIGHT", -2, 0)
            knob:SetBackdropColor(COLORS.enabled[1], COLORS.enabled[2], COLORS.enabled[3], 1)
            knob:SetBackdropBorderColor(COLORS.enabled[1] * 1.1, COLORS.enabled[2] * 1.1, COLORS.enabled[3] * 1.1, 1)
        else
            track:SetBackdropColor(COLORS.disabled[1], COLORS.disabled[2], COLORS.disabled[3], 1)
            track:SetBackdropBorderColor(0.28, 0.28, 0.32, 1)
            knob:ClearAllPoints()
            knob:SetPoint("LEFT", track, "LEFT", 2, 0)
            knob:SetBackdropColor(0.55, 0.55, 0.6, 1)
            knob:SetBackdropBorderColor(0.65, 0.65, 0.7, 1)
        end
    end

    UpdateState(getValue())

    local function OnClick()
        local newVal = not getValue()
        setValue(newVal)
        UpdateState(newVal)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end

    track:EnableMouse(true)
    track:SetScript("OnMouseUp", OnClick)
    row:EnableMouse(true)
    row:SetScript("OnMouseUp", OnClick)

    return y - rowHeight - 4
end

-- Slider with FIXED boundaries
local function CreateSlider(parent, y, label, minVal, maxVal, step, getValue, setValue, formatFunc)
    local rowHeight = 52
    local contentWidth = parent.contentWidth or (parent:GetWidth() - 24)

    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(contentWidth, rowHeight)
    row:SetPoint("TOPLEFT", 0, y)

    -- Label
    local labelText = row:CreateFontString(nil, "OVERLAY")
    labelText:SetFont(FONT, FONT_SIZES.normal, "")
    labelText:SetPoint("TOPLEFT", 0, 0)
    labelText:SetText(label)
    labelText:SetTextColor(COLORS.textWhite[1], COLORS.textWhite[2], COLORS.textWhite[3])

    -- Value
    local valueText = row:CreateFontString(nil, "OVERLAY")
    valueText:SetFont(FONT, FONT_SIZES.normal, "")
    valueText:SetPoint("TOPRIGHT", 0, 0)
    local dv = formatFunc and formatFunc(getValue()) or string.format("%.1f", getValue())
    valueText:SetText("|cFFFFD700" .. dv .. "|r")

    -- Track background
    local trackBg = CreateFrame("Frame", nil, row, "BackdropTemplate")
    trackBg:SetSize(contentWidth, 8)
    trackBg:SetPoint("TOP", 0, -20)
    trackBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    trackBg:SetBackdropColor(0.08, 0.08, 0.1, 1)
    trackBg:SetBackdropBorderColor(0.18, 0.18, 0.2, 1)

    -- Fill bar
    local fill = trackBg:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("LEFT", 1, 0)
    fill:SetHeight(6)
    fill:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.85)

    -- Slider
    local slider = CreateFrame("Slider", nil, row)
    slider:SetSize(contentWidth, 16)
    slider:SetPoint("TOP", 0, -16)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetValue(getValue())
    slider:EnableMouse(true)

    -- Thumb
    local thumb = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    thumb:SetSize(14, 14)
    thumb:SetFrameLevel(slider:GetFrameLevel() + 5)
    thumb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    thumb:SetBackdropColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
    thumb:SetBackdropBorderColor(COLORS.goldBright[1], COLORS.goldBright[2], COLORS.goldBright[3], 1)

    -- Invisible native thumb
    local nativeThumb = slider:CreateTexture(nil, "OVERLAY")
    nativeThumb:SetSize(1, 1)
    nativeThumb:SetColorTexture(0, 0, 0, 0)
    slider:SetThumbTexture(nativeThumb)

    local function UpdateSlider()
        local val = slider:GetValue()
        local pct = (val - minVal) / (maxVal - minVal)
        local w = trackBg:GetWidth() - 2
        fill:SetWidth(math.max(1, pct * w))
        thumb:ClearAllPoints()
        thumb:SetPoint("CENTER", trackBg, "LEFT", pct * w + 1, 0)
    end
    UpdateSlider()

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        valueText:SetText("|cFFFFD700" .. (formatFunc and formatFunc(value) or string.format("%.1f", value)) .. "|r")
        UpdateSlider()
        setValue(value)
    end)

    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        local v = math.max(minVal, math.min(maxVal, self:GetValue() + delta * step))
        self:SetValue(v)
    end)

    -- Min/Max labels
    local minText = row:CreateFontString(nil, "OVERLAY")
    minText:SetFont(FONT, FONT_SIZES.tiny, "")
    minText:SetPoint("TOPLEFT", trackBg, "BOTTOMLEFT", 0, -2)
    minText:SetText(formatFunc and formatFunc(minVal) or tostring(minVal))
    minText:SetTextColor(COLORS.textDark[1], COLORS.textDark[2], COLORS.textDark[3])

    local maxText = row:CreateFontString(nil, "OVERLAY")
    maxText:SetFont(FONT, FONT_SIZES.tiny, "")
    maxText:SetPoint("TOPRIGHT", trackBg, "BOTTOMRIGHT", 0, -2)
    maxText:SetText(formatFunc and formatFunc(maxVal) or tostring(maxVal))
    maxText:SetTextColor(COLORS.textDark[1], COLORS.textDark[2], COLORS.textDark[3])

    return y - rowHeight - 4
end

-- Dropdown with FIXED boundaries
local function CreateDropdown(parent, y, label, options, getValue, setValue)
    local rowHeight = 50
    local contentWidth = parent.contentWidth or (parent:GetWidth() - 24)
    local dropdownWidth = math.min(200, contentWidth)

    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(contentWidth, rowHeight)
    row:SetPoint("TOPLEFT", 0, y)

    -- Label
    local labelText = row:CreateFontString(nil, "OVERLAY")
    labelText:SetFont(FONT, FONT_SIZES.normal, "")
    labelText:SetPoint("TOPLEFT", 0, 0)
    labelText:SetText(label)
    labelText:SetTextColor(COLORS.textWhite[1], COLORS.textWhite[2], COLORS.textWhite[3])

    -- Dropdown button
    local dropdown = CreateFrame("Frame", nil, row, "BackdropTemplate")
    dropdown:SetSize(dropdownWidth, 26)
    dropdown:SetPoint("TOPLEFT", 0, -18)
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dropdown:SetBackdropColor(COLORS.bgLight[1], COLORS.bgLight[2], COLORS.bgLight[3], 1)
    dropdown:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], 1)

    local currentText = dropdown:CreateFontString(nil, "OVERLAY")
    currentText:SetFont(FONT, FONT_SIZES.normal, "")
    currentText:SetPoint("LEFT", 10, 0)
    currentText:SetPoint("RIGHT", -24, 0)
    currentText:SetJustifyH("LEFT")
    currentText:SetTextColor(COLORS.textWhite[1], COLORS.textWhite[2], COLORS.textWhite[3])

    local arrow = dropdown:CreateFontString(nil, "OVERLAY")
    arrow:SetFont(FONT, 8, "")
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetText("v")
    arrow:SetTextColor(COLORS.textGray[1], COLORS.textGray[2], COLORS.textGray[3])

    local function UpdateDisplay()
        local val = getValue()
        for _, opt in ipairs(options) do
            if opt.value == val then
                currentText:SetText(opt.text)
                return
            end
        end
        currentText:SetText(options[1] and options[1].text or "")
    end
    UpdateDisplay()

    local menu = nil

    dropdown:EnableMouse(true)
    dropdown:SetScript("OnMouseUp", function()
        CloseAllMenus()

        if not menu then
            menu = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
            menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
            menu:SetSize(dropdownWidth, #options * 24 + 6)
            menu:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            menu:SetBackdropColor(COLORS.bgMedium[1], COLORS.bgMedium[2], COLORS.bgMedium[3], 0.98)
            menu:SetBackdropBorderColor(COLORS.gold[1] * 0.5, COLORS.gold[2] * 0.5, COLORS.gold[3] * 0.5, 1)
            menu:SetFrameStrata("TOOLTIP")

            for i, opt in ipairs(options) do
                local btn = CreateFrame("Button", nil, menu)
                btn:SetSize(dropdownWidth - 4, 22)
                btn:SetPoint("TOPLEFT", 2, -2 - (i-1) * 24)

                local bg = btn:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0, 0, 0, 0)
                btn.bg = bg

                local txt = btn:CreateFontString(nil, "OVERLAY")
                txt:SetFont(FONT, FONT_SIZES.normal, "")
                txt:SetPoint("LEFT", 8, 0)
                txt:SetText(opt.text)
                txt:SetTextColor(COLORS.textWhite[1], COLORS.textWhite[2], COLORS.textWhite[3])

                btn:SetScript("OnEnter", function()
                    bg:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.15)
                    txt:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
                end)
                btn:SetScript("OnLeave", function()
                    bg:SetColorTexture(0, 0, 0, 0)
                    txt:SetTextColor(COLORS.textWhite[1], COLORS.textWhite[2], COLORS.textWhite[3])
                end)
                btn:SetScript("OnClick", function()
                    setValue(opt.value)
                    UpdateDisplay()
                    menu:Hide()
                    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                end)
            end
        end

        menu:Show()
        table.insert(activeMenus, menu)
    end)

    dropdown:SetScript("OnEnter", function()
        dropdown:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.7)
    end)
    dropdown:SetScript("OnLeave", function()
        dropdown:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], 1)
    end)

    return y - rowHeight - 4
end

-- Button with proper sizing
local function CreateButton(parent, y, text, onClick)
    local contentWidth = parent.contentWidth or (parent:GetWidth() - 24)

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(140, 28)
    btn:SetPoint("TOPLEFT", 0, y)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(COLORS.bgLight[1], COLORS.bgLight[2], COLORS.bgLight[3], 1)
    btn:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], 1)

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetFont(FONT, FONT_SIZES.normal, "")
    btnText:SetPoint("CENTER")
    btnText:SetText(text)
    btnText:SetTextColor(COLORS.textWhite[1], COLORS.textWhite[2], COLORS.textWhite[3])

    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(COLORS.gold[1] * 0.2, COLORS.gold[2] * 0.2, COLORS.gold[3] * 0.2, 1)
        btn:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.7)
        btnText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(COLORS.bgLight[1], COLORS.bgLight[2], COLORS.bgLight[3], 1)
        btn:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], 1)
        btnText:SetTextColor(COLORS.textWhite[1], COLORS.textWhite[2], COLORS.textWhite[3])
    end)
    btn:SetScript("OnClick", function()
        onClick()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    return y - 36
end

-- Input field with label
local function CreateInput(parent, y, label, width, placeholder, getValue, setValue)
    local contentWidth = parent.contentWidth or (parent:GetWidth() - 24)

    local labelText = parent:CreateFontString(nil, "OVERLAY")
    labelText:SetFont(FONT, FONT_SIZES.small, "")
    labelText:SetPoint("TOPLEFT", 0, y)
    labelText:SetText(label)
    labelText:SetTextColor(COLORS.textGray[1], COLORS.textGray[2], COLORS.textGray[3])

    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetSize(width or 80, 20)
    input:SetPoint("LEFT", labelText, "RIGHT", 8, 0)
    input:SetAutoFocus(false)
    input:SetMaxLetters(50)

    if placeholder then
        input:SetText(getValue and getValue() or "")
    end

    input:SetScript("OnEnterPressed", function(self)
        if setValue then setValue(self:GetText()) end
        self:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    return input, y - 28
end

-- Multiline text display
local function CreateTextDisplay(parent, y, height)
    local display = parent:CreateFontString(nil, "OVERLAY")
    display:SetFont(FONT, FONT_SIZES.small, "")
    display:SetPoint("TOPLEFT", 0, y)
    display:SetPoint("TOPRIGHT", -8, y)
    display:SetJustifyH("LEFT")
    display:SetJustifyV("TOP")
    display:SetSpacing(2)
    display:SetTextColor(COLORS.textWhite[1], COLORS.textWhite[2], COLORS.textWhite[3])

    return display, y - height
end

-- ============================================================================
-- Main Panel
-- ============================================================================

function QM:CreateSettingsPanel()
    if SettingsFrame then return SettingsFrame end

    -- Update colors from current theme before creating UI
    if QM.currentTheme then
        COLORS.gold = QM.currentTheme.accent
        COLORS.goldBright = QM.currentTheme.accentBright
        COLORS.goldDark = QM.currentTheme.accentDark
    end

    -- Clear themed elements list
    wipe(themedElements)

    local PANEL_WIDTH = 700
    local PANEL_HEIGHT = 540
    local SIDEBAR_WIDTH = 170

    -- Main Frame
    SettingsFrame = CreateFrame("Frame", "QuestMasterSettings", UIParent, "BackdropTemplate")
    SettingsFrame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    SettingsFrame:SetPoint("CENTER")
    SettingsFrame:SetFrameStrata("DIALOG")
    SettingsFrame:SetFrameLevel(100)
    SettingsFrame:SetMovable(true)
    SettingsFrame:EnableMouse(true)
    SettingsFrame:SetClampedToScreen(true)
    SettingsFrame:RegisterForDrag("LeftButton")
    SettingsFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    SettingsFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    SettingsFrame:SetScript("OnMouseDown", CloseAllMenus)

    SettingsFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    SettingsFrame:SetBackdropColor(COLORS.bgDarkest[1], COLORS.bgDarkest[2], COLORS.bgDarkest[3], 0.98)
    SettingsFrame:SetBackdropBorderColor(0.28, 0.25, 0.2, 1)

    -- ========== HEADER ==========
    local header = CreateFrame("Frame", nil, SettingsFrame)
    header:SetHeight(52)
    header:SetPoint("TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", -4, -4)
    SettingsFrame.header = header  -- Store reference for theme updates

    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(COLORS.bgMedium[1], COLORS.bgMedium[2], COLORS.bgMedium[3], 1)

    -- Top gold line (store for theme updates)
    header.accentTop = header:CreateTexture(nil, "ARTWORK")
    header.accentTop:SetHeight(1)
    header.accentTop:SetPoint("TOPLEFT", 0, 0)
    header.accentTop:SetPoint("TOPRIGHT", 0, 0)
    header.accentTop:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.4)

    -- Bottom gold line (store for theme updates)
    header.accent = header:CreateTexture(nil, "ARTWORK")
    header.accent:SetHeight(2)
    header.accent:SetPoint("BOTTOMLEFT", 0, 0)
    header.accent:SetPoint("BOTTOMRIGHT", 0, 0)
    header.accent:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.6)

    -- Icon
    local icon = header:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("LEFT", 14, 0)
    icon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")

    -- Title
    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, FONT_SIZES.huge, "")
    title:SetPoint("LEFT", icon, "RIGHT", 12, 3)
    title:SetText("|cFFFFD700Quest|r|cFFFFFFFFMaster|r")

    -- Subtitle
    local subtitle = header:CreateFontString(nil, "OVERLAY")
    subtitle:SetFont(FONT, FONT_SIZES.small, "")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -1)
    subtitle:SetText("|cFF666666" .. L["SETTINGS"] .. "|r")

    -- Version badge
    local badge = CreateFrame("Frame", nil, header, "BackdropTemplate")
    badge:SetSize(42, 16)
    badge:SetPoint("LEFT", title, "RIGHT", 8, 0)
    badge:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    badge:SetBackdropColor(COLORS.gold[1] * 0.25, COLORS.gold[2] * 0.25, COLORS.gold[3] * 0.25, 0.9)

    local badgeText = badge:CreateFontString(nil, "OVERLAY")
    badgeText:SetFont(FONT, FONT_SIZES.tiny, "")
    badgeText:SetPoint("CENTER")
    badgeText:SetText("|cFFFFD700v1.3|r")

    -- Close button (using texture, not unicode)
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("RIGHT", -6, 0)

    local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
    closeBg:SetAllPoints()
    closeBg:SetColorTexture(0, 0, 0, 0)
    closeBtn.bg = closeBg

    -- X using lines (not unicode)
    local xLine1 = closeBtn:CreateTexture(nil, "ARTWORK")
    xLine1:SetSize(12, 2)
    xLine1:SetPoint("CENTER")
    xLine1:SetColorTexture(0.5, 0.5, 0.5, 1)
    xLine1:SetRotation(math.rad(45))

    local xLine2 = closeBtn:CreateTexture(nil, "ARTWORK")
    xLine2:SetSize(12, 2)
    xLine2:SetPoint("CENTER")
    xLine2:SetColorTexture(0.5, 0.5, 0.5, 1)
    xLine2:SetRotation(math.rad(-45))

    closeBtn:SetScript("OnEnter", function()
        closeBg:SetColorTexture(COLORS.error[1], COLORS.error[2], COLORS.error[3], 0.25)
        xLine1:SetColorTexture(COLORS.error[1], COLORS.error[2], COLORS.error[3], 1)
        xLine2:SetColorTexture(COLORS.error[1], COLORS.error[2], COLORS.error[3], 1)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeBg:SetColorTexture(0, 0, 0, 0)
        xLine1:SetColorTexture(0.5, 0.5, 0.5, 1)
        xLine2:SetColorTexture(0.5, 0.5, 0.5, 1)
    end)
    closeBtn:SetScript("OnClick", function()
        SettingsFrame:Hide()
        CloseAllMenus()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    end)

    -- ========== SIDEBAR ==========
    local sidebar = CreateFrame("Frame", nil, SettingsFrame, "BackdropTemplate")
    sidebar:SetWidth(SIDEBAR_WIDTH)
    sidebar:SetPoint("TOPLEFT", 4, -56)
    sidebar:SetPoint("BOTTOMLEFT", 4, 4)
    sidebar:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    sidebar:SetBackdropColor(COLORS.sidebarBg[1], COLORS.sidebarBg[2], COLORS.sidebarBg[3], 1)

    -- Right border
    local sidebarBorder = sidebar:CreateTexture(nil, "ARTWORK")
    sidebarBorder:SetWidth(1)
    sidebarBorder:SetPoint("TOPRIGHT", 0, 0)
    sidebarBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    sidebarBorder:SetColorTexture(COLORS.border[1], COLORS.border[2], COLORS.border[3], 0.5)

    SettingsFrame.tabs = {}
    SettingsFrame.currentTab = "general"

    for i, tabData in ipairs(TABS) do
        local tab = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
        tab:SetSize(SIDEBAR_WIDTH - 8, 44)
        tab:SetPoint("TOPLEFT", 4, -4 - (i-1) * 48)
        tab:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
        tab:SetBackdropColor(0, 0, 0, 0)

        -- Indicator
        tab.indicator = tab:CreateTexture(nil, "ARTWORK")
        tab.indicator:SetSize(3, 32)
        tab.indicator:SetPoint("LEFT", 0, 0)
        tab.indicator:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
        tab.indicator:Hide()

        -- Icon
        tab.icon = tab:CreateTexture(nil, "ARTWORK")
        tab.icon:SetSize(22, 22)
        tab.icon:SetPoint("LEFT", 12, 0)
        tab.icon:SetTexture(tabData.icon)
        tab.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tab.icon:SetDesaturated(true)
        tab.icon:SetVertexColor(0.5, 0.5, 0.5)

        -- Name
        tab.name = tab:CreateFontString(nil, "OVERLAY")
        tab.name:SetFont(FONT, FONT_SIZES.normal, "")
        tab.name:SetPoint("LEFT", tab.icon, "RIGHT", 8, 3)
        tab.name:SetText(tabData.name)
        tab.name:SetTextColor(COLORS.textGray[1], COLORS.textGray[2], COLORS.textGray[3])

        -- Desc
        tab.desc = tab:CreateFontString(nil, "OVERLAY")
        tab.desc:SetFont(FONT, FONT_SIZES.tiny, "")
        tab.desc:SetPoint("TOPLEFT", tab.name, "BOTTOMLEFT", 0, -1)
        tab.desc:SetText(tabData.desc)
        tab.desc:SetTextColor(COLORS.textDark[1], COLORS.textDark[2], COLORS.textDark[3])

        tab.id = tabData.id

        tab:SetScript("OnEnter", function(self)
            if SettingsFrame.currentTab ~= self.id then
                self:SetBackdropColor(COLORS.sidebarHover[1], COLORS.sidebarHover[2], COLORS.sidebarHover[3], 1)
                self.icon:SetDesaturated(false)
                self.icon:SetVertexColor(0.8, 0.8, 0.8)
            end
        end)

        tab:SetScript("OnLeave", function(self)
            if SettingsFrame.currentTab ~= self.id then
                self:SetBackdropColor(0, 0, 0, 0)
                self.icon:SetDesaturated(true)
                self.icon:SetVertexColor(0.5, 0.5, 0.5)
            end
        end)

        tab:SetScript("OnClick", function(self)
            CloseAllMenus()
            QM:SelectTab(self.id)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end)

        SettingsFrame.tabs[tabData.id] = tab
    end

    -- ========== CONTENT ==========
    local contentArea = CreateFrame("Frame", nil, SettingsFrame, "BackdropTemplate")
    contentArea:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 1, 0)
    contentArea:SetPoint("BOTTOMRIGHT", -4, 4)
    contentArea:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    contentArea:SetBackdropColor(COLORS.bgDark[1], COLORS.bgDark[2], COLORS.bgDark[3], 1)

    local scrollFrame = CreateFrame("ScrollFrame", nil, contentArea, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 6)
    SettingsFrame.scrollFrame = scrollFrame

    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 2, -16)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 2, 16)
    end

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(CONTENT_WIDTH + 16, 900)
    scrollFrame:SetScrollChild(content)
    SettingsFrame.content = content

    self:SelectTab("general")

    SettingsFrame:Hide()
    return SettingsFrame
end

-- ============================================================================
-- Tab Selection
-- ============================================================================

function QM:SelectTab(tabId)
    if not SettingsFrame then return end

    SettingsFrame.currentTab = tabId

    for id, tab in pairs(SettingsFrame.tabs) do
        if id == tabId then
            tab:SetBackdropColor(COLORS.sidebarActive[1], COLORS.sidebarActive[2], COLORS.sidebarActive[3], 1)
            tab.icon:SetDesaturated(false)
            tab.icon:SetVertexColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            tab.name:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            tab.desc:SetTextColor(COLORS.textMuted[1], COLORS.textMuted[2], COLORS.textMuted[3])
            tab.indicator:Show()
        else
            tab:SetBackdropColor(0, 0, 0, 0)
            tab.icon:SetDesaturated(true)
            tab.icon:SetVertexColor(0.5, 0.5, 0.5)
            tab.name:SetTextColor(COLORS.textGray[1], COLORS.textGray[2], COLORS.textGray[3])
            tab.desc:SetTextColor(COLORS.textDark[1], COLORS.textDark[2], COLORS.textDark[3])
            tab.indicator:Hide()
        end
    end

    local content = SettingsFrame.content
    for _, child in pairs({content:GetChildren()}) do child:Hide(); child:SetParent(nil) end
    for _, region in pairs({content:GetRegions()}) do region:Hide(); region:SetParent(nil) end

    local tabFuncs = {
        general = self.CreateGeneralTab,
        tracker = self.CreateTrackerTab,
        arrow = self.CreateArrowTab,
        map = self.CreateMapTab,
        stats = self.CreateStatsTab,
        dashboard = self.CreateDashboardTab,
        auto = self.CreateAutomationTab,
        advanced = self.CreateAdvancedTab,
        credits = self.CreateCreditsTab,
    }

    if tabFuncs[tabId] then tabFuncs[tabId](self, content) end
    SettingsFrame.scrollFrame:SetVerticalScroll(0)
end

-- ============================================================================
-- Tab Content Functions
-- ============================================================================

function QM:CreateGeneralTab(content)
    local y = -8
    local card, cy

    card, y = CreateCard(content, y, L["MAIN_SETTINGS"], "Interface\\Icons\\INV_Misc_Gear_01", 130)
    cy = -4
    cy = CreateToggle(card.content, cy, L["ENABLE_ADDON"], L["ENABLE_ADDON_DESC"],
        function() return QM.db.profile.enabled end,
        function(v) QM.db.profile.enabled = v; if QM.UpdateArrowVisibility then QM:UpdateArrowVisibility() end end)
    cy = CreateToggle(card.content, cy, L["LOCK_FRAMES"], L["LOCK_FRAMES_DESC"],
        function() return QM.db.profile.lockFrames end,
        function(v)
            QM.db.profile.lockFrames = v
            -- Update lock indicator on tracker
            if QM.TrackerFrame and QM.TrackerFrame.header and QM.TrackerFrame.header.lockIcon then
                QM.TrackerFrame.header.lockIcon:SetAlpha(v and 0.8 or 0)
            end
        end)
    cy = CreateToggle(card.content, cy, L["SHOW_MINIMAP_BUTTON"], L["SHOW_MINIMAP_BUTTON_DESC"],
        function() return not QM.db.profile.minimapButton.hide end,
        function(v) QM.db.profile.minimapButton.hide = not v; if QM.UpdateMinimapButton then QM:UpdateMinimapButton() end end)

    card, y = CreateCard(content, y, L["SOUNDS"], "Interface\\Icons\\Spell_Holy_PowerInfusion", 88)
    cy = -4
    cy = CreateToggle(card.content, cy, L["QUEST_PROGRESS_SOUND"], L["QUEST_PROGRESS_SOUND_DESC"],
        function() return QM.db.profile.sounds.progress ~= false end,
        function(v) QM.db.profile.sounds.progress = v end)
    cy = CreateToggle(card.content, cy, L["QUEST_COMPLETE_SOUND"], L["QUEST_COMPLETE_SOUND_DESC"],
        function() return QM.db.profile.sounds.complete ~= false end,
        function(v) QM.db.profile.sounds.complete = v end)

    card, y = CreateCard(content, y, L["QUEST_ANNOUNCEMENTS"], "Interface\\Icons\\INV_Letter_15", 210)
    cy = -4
    cy = CreateToggle(card.content, cy, L["ANNOUNCE_ACCEPT"], L["ANNOUNCE_ACCEPT_DESC"],
        function() return QM.db.profile.announce.accept end,
        function(v) QM.db.profile.announce.accept = v end)
    cy = CreateDropdown(card.content, cy, L["ACCEPT_CHANNEL"],
        {
            {value = "PARTY", text = L["CHANNEL_PARTY"]},
            {value = "GUILD", text = L["CHANNEL_GUILD"]},
            {value = "NONE", text = L["CHANNEL_DISABLED"]},
        },
        function() return QM.db.profile.announce.acceptChannel or "PARTY" end,
        function(v) QM.db.profile.announce.acceptChannel = v end)
    cy = CreateToggle(card.content, cy, L["ANNOUNCE_DONE"], L["ANNOUNCE_DONE_DESC"],
        function() return QM.db.profile.announce.complete end,
        function(v) QM.db.profile.announce.complete = v end)
    cy = CreateDropdown(card.content, cy, L["COMPLETE_CHANNEL"],
        {
            {value = "PARTY", text = L["CHANNEL_PARTY"]},
            {value = "GUILD", text = L["CHANNEL_GUILD"]},
            {value = "NONE", text = L["CHANNEL_DISABLED"]},
        },
        function() return QM.db.profile.announce.completeChannel or "PARTY" end,
        function(v) QM.db.profile.announce.completeChannel = v end)

    card, y = CreateCard(content, y, L["LEVEL_UP_ANNOUNCEMENTS"], "Interface\\Icons\\Spell_Holy_ProclaimChampion", 100)
    cy = -4
    cy = CreateToggle(card.content, cy, L["ANNOUNCE_LEVEL_UP"], L["ANNOUNCE_LEVEL_UP_DESC"],
        function() return QM.db.profile.announce.levelUpChat ~= false end,
        function(v) QM.db.profile.announce.levelUpChat = v end)
    cy = CreateDropdown(card.content, cy, L["LEVEL_UP_CHANNEL"],
        {
            {value = "EMOTE", text = L["CHANNEL_EMOTE"]},
            {value = "PARTY", text = L["CHANNEL_PARTY"]},
            {value = "GUILD", text = L["CHANNEL_GUILD"]},
            {value = "NONE", text = L["CHANNEL_DISABLED"]},
        },
        function() return QM.db.profile.announce.levelUpChannel or "EMOTE" end,
        function(v) QM.db.profile.announce.levelUpChannel = v end)

    card, y = CreateCard(content, y, L["QUICK_ACTIONS"], "Interface\\Icons\\Ability_Rogue_Sprint", 80)
    cy = -4
    cy = CreateButton(card.content, cy, L["RESET_POSITIONS"], function()
        if QM.ResetFramePositions then QM:ResetFramePositions() end
        print("|cFF00FF00QuestMaster:|r Reset")
    end)
    cy = CreateButton(card.content, cy, L["REFRESH_DATA"], function()
        if QM.UpdateAllQuests then QM:UpdateAllQuests() end
        print("|cFF00FF00QuestMaster:|r " .. L["REFRESHED"])
    end)

    content:SetHeight(math.abs(y) + 20)
end

function QM:CreateTrackerTab(content)
    local y = -8
    local card, cy

    card, y = CreateCard(content, y, L["QUEST_TRACKER"], "Interface\\Icons\\INV_Misc_Note_01", 215)
    cy = -4
    cy = CreateToggle(card.content, cy, L["ENABLE_TRACKER"], L["ENABLE_TRACKER_DESC"],
        function() return QM.db.profile.tracker.enabled end,
        function(v) QM.db.profile.tracker.enabled = v; if QM.UpdateTrackerVisibility then QM:UpdateTrackerVisibility() end end)
    cy = CreateToggle(card.content, cy, L["HIDE_BLIZZARD_TRACKER"], L["HIDE_BLIZZARD_TRACKER_DESC"],
        function() return QM.db.profile.tracker.hideBlizzardTracker end,
        function(v) QM:SetHideBlizzardTracker(v) end)
    cy = CreateSlider(card.content, cy, L["FONT_SIZE"], 8, 14, 1,
        function() return QM.db.profile.tracker.fontSize or 9 end,
        function(v) QM.db.profile.tracker.fontSize = v; if QM.UpdateTracker then QM:UpdateTracker() end end,
        function(v) return string.format("%d", v) end)
    cy = CreateSlider(card.content, cy, L["BACKGROUND_OPACITY"], 0, 1, 0.05,
        function() return QM.db.profile.tracker.alpha or 0.9 end,
        function(v) QM.db.profile.tracker.alpha = v; if QM.UpdateTracker then QM:UpdateTracker() end end,
        function(v) return string.format("%.0f%%", v * 100) end)
    cy = CreateToggle(card.content, cy, L["SHOW_BORDER"], L["SHOW_BORDER_DESC"],
        function() return QM.db.profile.tracker.showBorder ~= false end,
        function(v) QM.db.profile.tracker.showBorder = v; if QM.UpdateTracker then QM:UpdateTracker() end end)

    card, y = CreateCard(content, y, L["DISPLAY_OPTIONS"], "Interface\\Icons\\INV_Misc_Eye_02", 350)
    cy = -4
    cy = CreateToggle(card.content, cy, L["SHOW_QUEST_LEVEL"], L["SHOW_QUEST_LEVEL_DESC"],
        function() return QM.db.profile.tracker.showQuestLevel end,
        function(v) QM.db.profile.tracker.showQuestLevel = v; if QM.UpdateTracker then QM:UpdateTracker() end end)
    cy = CreateToggle(card.content, cy, L["SHOW_DISTANCE"], L["SHOW_DISTANCE_DESC"],
        function() return QM.db.profile.tracker.showDistance ~= false end,
        function(v) QM.db.profile.tracker.showDistance = v; if QM.UpdateTracker then QM:UpdateTracker() end end)
    cy = CreateToggle(card.content, cy, L["COLOR_BY_DIFFICULTY"], L["COLOR_BY_DIFFICULTY_DESC"],
        function() return QM.db.profile.tracker.colorByDifficulty ~= false end,
        function(v) QM.db.profile.tracker.colorByDifficulty = v; if QM.UpdateTracker then QM:UpdateTracker() end end)
    cy = CreateToggle(card.content, cy, L["SHOW_PROGRESS_BARS"], L["SHOW_PROGRESS_BARS_DESC"],
        function() return QM.db.profile.tracker.showProgressBar ~= false end,
        function(v) QM.db.profile.tracker.showProgressBar = v; if QM.UpdateTracker then QM:UpdateTracker() end end)
    cy = CreateToggle(card.content, cy, L["SHOW_ITEM_BUTTONS"], L["SHOW_ITEM_BUTTONS_DESC"],
        function() return QM.db.profile.tracker.showItemButtons ~= false end,
        function(v) QM.db.profile.tracker.showItemButtons = v; if QM.UpdateTracker then QM:UpdateTracker() end end)
    cy = CreateToggle(card.content, cy, L["SHOW_COMPLETED"], L["SHOW_COMPLETED_DESC"],
        function() return QM.db.profile.tracker.showCompleted ~= false end,
        function(v) QM.db.profile.tracker.showCompleted = v; if QM.UpdateTracker then QM:UpdateTracker() end end)
    cy = CreateToggle(card.content, cy, L["ZONE_FILTER"], L["ZONE_FILTER_DESC"],
        function() return QM.db.profile.tracker.zoneFilter end,
        function(v) QM.db.profile.tracker.zoneFilter = v; if QM.UpdateTracker then QM:UpdateTracker() end end)
    card, y = CreateCard(content, y, L["SORTING"], "Interface\\Icons\\INV_Misc_Note_06", 60)
    cy = -4
    cy = CreateDropdown(card.content, cy, L["SORT_QUESTS_BY"],
        {{value = "distance", text = L["SORT_DISTANCE"]}, {value = "level", text = L["SORT_LEVEL"]}},
        function() return QM.db.profile.tracker.sortBy or "distance" end,
        function(v) QM.db.profile.tracker.sortBy = v; if QM.UpdateTracker then QM:UpdateTracker() end end)

    content:SetHeight(math.abs(y) + 20)
end

function QM:CreateArrowTab(content)
    local y = -8
    local card, cy

    card, y = CreateCard(content, y, L["NAVIGATION_ARROW"], "Interface\\Icons\\Ability_Hunter_Pathfinding", 235)
    cy = -4
    cy = CreateToggle(card.content, cy, L["ENABLE_ARROW"], L["ENABLE_ARROW_DESC"],
        function() return QM.db.profile.arrow.enabled end,
        function(v) QM.db.profile.arrow.enabled = v; if QM.UpdateArrowVisibility then QM:UpdateArrowVisibility() end end)
    cy = CreateSlider(card.content, cy, L["ARROW_SIZE"], 0.5, 2.5, 0.1,
        function() return QM.db.profile.arrow.scale or 1.0 end,
        function(v) QM.db.profile.arrow.scale = v; if QM.UpdateArrowSettings then QM:UpdateArrowSettings() end end,
        function(v) return string.format("%.0f%%", v * 100) end)
    cy = CreateSlider(card.content, cy, L["ARROW_OPACITY"], 0.3, 1.0, 0.05,
        function() return QM.db.profile.arrow.alpha or 1.0 end,
        function(v) QM.db.profile.arrow.alpha = v; if QM.UpdateArrowSettings then QM:UpdateArrowSettings() end end,
        function(v) return string.format("%.0f%%", v * 100) end)
    cy = CreateSlider(card.content, cy, L["ARRIVAL_DISTANCE"], 5, 30, 1,
        function() return QM.db.profile.arrow.arrivalDist or 10 end,
        function(v) QM.db.profile.arrow.arrivalDist = v end,
        function(v) return string.format("%d yd", v) end)

    card, y = CreateCard(content, y, L["DISPLAY"], "Interface\\Icons\\Spell_Holy_MindVision", 130)
    cy = -4
    cy = CreateToggle(card.content, cy, L["SHOW_DISTANCE"], L["SHOW_DISTANCE_DESC"],
        function() return QM.db.profile.arrow.showDistance ~= false end,
        function(v) QM.db.profile.arrow.showDistance = v; if QM.UpdateArrowSettings then QM:UpdateArrowSettings() end end)
    cy = CreateToggle(card.content, cy, L["SHOW_OBJECTIVE"], L["SHOW_OBJECTIVE_DESC"],
        function() return QM.db.profile.arrow.showObjective ~= false end,
        function(v) QM.db.profile.arrow.showObjective = v; if QM.UpdateArrowSettings then QM:UpdateArrowSettings() end end)
    cy = CreateToggle(card.content, cy, L["SHOW_ETA"], L["SHOW_ETA_DESC"],
        function() return QM.db.profile.arrow.showETA end,
        function(v) QM.db.profile.arrow.showETA = v; if QM.UpdateArrowSettings then QM:UpdateArrowSettings() end end)

    content:SetHeight(math.abs(y) + 20)
end

function QM:CreateMapTab(content)
    local y = -8
    local card, cy

    card, y = CreateCard(content, y, L["WORLD_MAP"], "Interface\\WorldMap\\UI-World-Icon", 175)
    cy = -4
    cy = CreateToggle(card.content, cy, L["ENABLE_MAP_PINS"], L["ENABLE_MAP_PINS_DESC"],
        function() return QM.db.profile.map.enableWorldMap end,
        function(v) QM.db.profile.map.enableWorldMap = v; if QM.UpdateMapPins then QM:UpdateMapPins() end end)
    cy = CreateSlider(card.content, cy, L["PIN_SIZE"], 0.5, 2.0, 0.1,
        function() return QM.db.profile.map.pinScale or 1.0 end,
        function(v) QM.db.profile.map.pinScale = v; if QM.UpdateMapPinSettings then QM:UpdateMapPinSettings() end end,
        function(v) return string.format("%.0f%%", v * 100) end)
    cy = CreateSlider(card.content, cy, L["PIN_OPACITY"], 0.4, 1.0, 0.05,
        function() return QM.db.profile.map.pinAlpha or 1.0 end,
        function(v) QM.db.profile.map.pinAlpha = v; if QM.UpdateMapPinSettings then QM:UpdateMapPinSettings() end end,
        function(v) return string.format("%.0f%%", v * 100) end)

    card, y = CreateCard(content, y, L["PIN_TYPES"], "Interface\\Minimap\\Tracking\\QuestBlob", 215)
    cy = -4
    cy = CreateToggle(card.content, cy, L["OBJECTIVE_PINS"], L["OBJECTIVE_PINS_DESC"],
        function() return QM.db.profile.map.showObjectivePins ~= false end,
        function(v) QM.db.profile.map.showObjectivePins = v; if QM.UpdateMapPins then QM:UpdateMapPins() end end)
    cy = CreateToggle(card.content, cy, L["QUEST_AREAS"], L["QUEST_AREAS_DESC"],
        function() return QM.db.profile.map.showAreaBlobs ~= false end,
        function(v) QM.db.profile.map.showAreaBlobs = v; if QM.UpdateMapPins then QM:UpdateMapPins() end end)
    cy = CreateToggle(card.content, cy, L["TURNIN_PINS"], L["TURNIN_PINS_DESC"],
        function() return QM.db.profile.map.showTurnInPins ~= false end,
        function(v) QM.db.profile.map.showTurnInPins = v; if QM.UpdateMapPins then QM:UpdateMapPins() end end)
    cy = CreateToggle(card.content, cy, L["AVAILABLE_QUESTS"], L["AVAILABLE_QUESTS_DESC"],
        function() return QM.db.profile.map.showAvailablePins ~= false end,
        function(v) QM.db.profile.map.showAvailablePins = v; if QM.UpdateMapPins then QM:UpdateMapPins() end end)
    cy = CreateToggle(card.content, cy, L["PATROL_PATHS"], L["PATROL_PATHS_DESC"],
        function() return QM.db.profile.map.showPatrolPaths end,
        function(v) QM.db.profile.map.showPatrolPaths = v; if QM.UpdateMapPins then QM:UpdateMapPins() end end)

    content:SetHeight(math.abs(y) + 20)
end

function QM:CreateStatsTab(content)
    local y = -8
    local card, cy

    card, y = CreateCard(content, y, L["QUEST_TIMER"], "Interface\\Icons\\INV_Misc_PocketWatch_02", 88)
    cy = -4
    cy = CreateToggle(card.content, cy, L["ENABLE_TIMER"], L["ENABLE_TIMER_DESC"],
        function() return QM.db.profile.questTimer.enabled end,
        function(v) QM.db.profile.questTimer.enabled = v; if QM.UpdateTracker then QM:UpdateTracker() end end)
    cy = CreateToggle(card.content, cy, L["SHOW_IN_TRACKER"], L["SHOW_IN_TRACKER_DESC"],
        function() return QM.db.profile.questTimer.showInTracker end,
        function(v) QM.db.profile.questTimer.showInTracker = v; if QM.UpdateTracker then QM:UpdateTracker() end end)

    card, y = CreateCard(content, y, L["XP_PER_HOUR"], "Interface\\Icons\\Spell_Holy_ChampionsBond", 130)
    cy = -4
    cy = CreateToggle(card.content, cy, L["ENABLE_XP_TRACKER"], L["ENABLE_XP_TRACKER_DESC"],
        function() return QM.db.profile.xpTracker.enabled end,
        function(v) QM.db.profile.xpTracker.enabled = v; if QM.UpdateInfoBar then QM:UpdateInfoBar() end end)
    cy = CreateToggle(card.content, cy, L["SHOW_IN_TRACKER"], L["SHOW_IN_TRACKER_DESC"],
        function() return QM.db.profile.xpTracker.showInTracker end,
        function(v) QM.db.profile.xpTracker.showInTracker = v; if QM.UpdateInfoBar then QM:UpdateInfoBar() end end)
    cy = CreateButton(card.content, cy, L["RESET_XP"], function()
        if QM.ResetXPTracker then QM:ResetXPTracker() end
    end)

    card, y = CreateCard(content, y, L["RESTED_XP"], "Interface\\Icons\\Spell_Nature_Sleep", 130)
    cy = -4
    cy = CreateToggle(card.content, cy, L["ENABLE_RESTED_DISPLAY"], L["ENABLE_RESTED_DISPLAY_DESC"],
        function() return QM.db.profile.restedXP and QM.db.profile.restedXP.enabled end,
        function(v) if QM.db.profile.restedXP then QM.db.profile.restedXP.enabled = v end; if QM.UpdateInfoBar then QM:UpdateInfoBar() end end)
    cy = CreateToggle(card.content, cy, L["SHOW_IN_TRACKER"], L["SHOW_IN_TRACKER_DESC"],
        function() return QM.db.profile.restedXP and QM.db.profile.restedXP.showInTracker end,
        function(v) if QM.db.profile.restedXP then QM.db.profile.restedXP.showInTracker = v end; if QM.UpdateInfoBar then QM:UpdateInfoBar() end end)
    cy = CreateToggle(card.content, cy, L["SHOW_BONUS_INDICATOR"], L["SHOW_BONUS_INDICATOR_DESC"],
        function() return QM.db.profile.restedXP and QM.db.profile.restedXP.showBonus end,
        function(v) if QM.db.profile.restedXP then QM.db.profile.restedXP.showBonus = v end; if QM.UpdateInfoBar then QM:UpdateInfoBar() end end)

    card, y = CreateCard(content, y, L["LEVEL_TIME"], "Interface\\Icons\\Spell_Holy_BorrowedTime", 88)
    cy = -4
    cy = CreateToggle(card.content, cy, L["ENABLE_LEVEL_TIMER"], L["ENABLE_LEVEL_TIMER_DESC"],
        function() return QM.db.profile.levelTime and QM.db.profile.levelTime.enabled end,
        function(v) if QM.db.profile.levelTime then QM.db.profile.levelTime.enabled = v end; if QM.UpdateInfoBar then QM:UpdateInfoBar() end end)
    cy = CreateToggle(card.content, cy, L["SHOW_AVERAGE"], L["SHOW_AVERAGE_DESC"],
        function() return QM.db.profile.levelTime and QM.db.profile.levelTime.showAverage end,
        function(v) if QM.db.profile.levelTime then QM.db.profile.levelTime.showAverage = v end; if QM.UpdateInfoBar then QM:UpdateInfoBar() end end)

    card, y = CreateCard(content, y, L["REMINDERS"], "Interface\\Icons\\INV_Misc_Bell_01", 185)
    cy = -4
    cy = CreateToggle(card.content, cy, L["ENABLE_REMINDERS"], L["ENABLE_REMINDERS_DESC"],
        function() return QM.db.profile.reminders and QM.db.profile.reminders.enabled end,
        function(v) if QM.db.profile.reminders then QM.db.profile.reminders.enabled = v end; if QM.UpdateInfoBar then QM:UpdateInfoBar() end end)
    cy = CreateToggle(card.content, cy, L["BAG_SPACE_WARNING"], L["BAG_SPACE_WARNING_DESC"],
        function() return QM.db.profile.reminders and QM.db.profile.reminders.bagsFull end,
        function(v) if QM.db.profile.reminders then QM.db.profile.reminders.bagsFull = v end; if QM.UpdateInfoBar then QM:UpdateInfoBar() end end)
    cy = CreateSlider(card.content, cy, L["BAG_THRESHOLD"], 1, 10, 1,
        function() return QM.db.profile.reminders and QM.db.profile.reminders.bagsThreshold or 4 end,
        function(v) if QM.db.profile.reminders then QM.db.profile.reminders.bagsThreshold = v end end,
        function(v) return string.format("%d slots", v) end)
    cy = CreateToggle(card.content, cy, L["REPAIR_WARNING"], L["REPAIR_WARNING_DESC"],
        function() return QM.db.profile.reminders and QM.db.profile.reminders.repairNeeded end,
        function(v) if QM.db.profile.reminders then QM.db.profile.reminders.repairNeeded = v end; if QM.UpdateInfoBar then QM:UpdateInfoBar() end end)

    card, y = CreateCard(content, y, L["ZONE_PROGRESS"], "Interface\\Icons\\Achievement_Zone_Stranglethorn_01", 46)
    cy = -4
    cy = CreateToggle(card.content, cy, L["ENABLE_ZONE_PROGRESS"], L["ENABLE_ZONE_PROGRESS_DESC"],
        function() return QM.db.profile.zoneProgress.enabled end,
        function(v) QM.db.profile.zoneProgress.enabled = v; if QM.UpdateInfoBar then QM:UpdateInfoBar() end end)

    card, y = CreateCard(content, y, L["REPUTATION"], "Interface\\Icons\\INV_Misc_Note_02", 88)
    cy = -4
    cy = CreateToggle(card.content, cy, L["ENABLE_REP_TRACKER"], L["ENABLE_REP_TRACKER_DESC"],
        function() return QM.db.profile.reputation and QM.db.profile.reputation.enabled end,
        function(v) if QM.db.profile.reputation then QM.db.profile.reputation.enabled = v end; if QM.UpdateInfoBar then QM:UpdateInfoBar() end end)
    cy = CreateToggle(card.content, cy, L["SHOW_IN_TRACKER"], L["SHOW_IN_TRACKER_DESC"],
        function() return QM.db.profile.reputation and QM.db.profile.reputation.showInTracker end,
        function(v) if QM.db.profile.reputation then QM.db.profile.reputation.showInTracker = v end; if QM.UpdateInfoBar then QM:UpdateInfoBar() end end)

    -- Quest Statistics Display
    local statsCard
    statsCard, y = CreateCard(content, y, L["QUEST_STATISTICS"], "Interface\\Icons\\INV_Misc_Note_02", 200)
    cy = -4

    -- Stats display text (formatted as table)
    statsCard.statsDisplay = statsCard.content:CreateFontString(nil, "OVERLAY")
    statsCard.statsDisplay:SetFont(FONT, FONT_SIZES.small, "")
    statsCard.statsDisplay:SetPoint("TOPLEFT", 0, cy)
    statsCard.statsDisplay:SetPoint("TOPRIGHT", -8, cy)
    statsCard.statsDisplay:SetJustifyH("LEFT")
    statsCard.statsDisplay:SetSpacing(3)
    statsCard.statsDisplay:SetTextColor(COLORS.textWhite[1], COLORS.textWhite[2], COLORS.textWhite[3])

    -- Update stats display
    local function UpdateStatsDisplay()
        local summary = QM:GetStatsSummary()
        local levelTime = QM:GetCurrentLevelTime() or 0
        local lines = {}

        -- Format as clean table
        table.insert(lines, "|cFFFFD700" .. L["TOTAL_STATISTICS"] .. "|r")
        table.insert(lines, string.format("  " .. L["QUESTS_COMPLETED"] .. ":  |cFF00FF00%d|r", summary.totalCompleted or 0))
        table.insert(lines, string.format("  " .. L["TOTAL_XP_GAINED"] .. ":   |cFF00FF00%s|r", QM:FormatNumber(summary.totalXP or 0)))
        table.insert(lines, string.format("  " .. L["AVG_QUEST_TIME"] .. ":    |cFF00FF00%s|r", QM:FormatPlayTime(summary.averageTime or 0)))
        table.insert(lines, string.format("  " .. L["QUESTS_PER_HOUR"] .. ":   |cFF00FF00%.1f|r", summary.questsPerHour or 0))
        table.insert(lines, "")
        table.insert(lines, "|cFFFFD700" .. L["CURRENT_LEVEL"] .. "|r")
        table.insert(lines, string.format("  " .. L["TIME_ON_LEVEL"] .. " %d:  |cFF4169E1%s|r", UnitLevel("player"), QM:FormatPlayTime(levelTime)))
        table.insert(lines, string.format("  " .. L["SESSION_QUESTS"] .. ":    |cFF4169E1%d|r", summary.sessionCompleted or 0))
        table.insert(lines, string.format("  " .. L["SESSION_XP"] .. ":        |cFF4169E1%s|r", QM:FormatNumber(summary.sessionXP or 0)))

        statsCard.statsDisplay:SetText(table.concat(lines, "\n"))
    end

    UpdateStatsDisplay()
    cy = cy - 135

    cy = CreateButton(statsCard.content, cy, L["REFRESH_STATS"], UpdateStatsDisplay)
    cy = CreateButton(statsCard.content, cy - 4, L["RESET_SESSION"], function()
        QM:ResetSessionStats()
        UpdateStatsDisplay()
    end)

    -- Quest Search with clickable results
    local searchCard
    searchCard, y = CreateCard(content, y, L["QUEST_SEARCH"], "Interface\\Icons\\INV_Misc_Spyglass_02", 200)
    cy = -4

    -- Search input
    local searchLabel = searchCard.content:CreateFontString(nil, "OVERLAY")
    searchLabel:SetFont(FONT, FONT_SIZES.small, "")
    searchLabel:SetPoint("TOPLEFT", 0, cy)
    searchLabel:SetText(L["SEARCH"] .. ":")
    searchLabel:SetTextColor(COLORS.textGray[1], COLORS.textGray[2], COLORS.textGray[3])

    local searchInput = CreateFrame("EditBox", nil, searchCard.content, "InputBoxTemplate")
    searchInput:SetSize(200, 20)
    searchInput:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
    searchInput:SetAutoFocus(false)
    searchInput:SetMaxLetters(50)

    local searchBtn = CreateFrame("Button", nil, searchCard.content, "UIPanelButtonTemplate")
    searchBtn:SetSize(50, 22)
    searchBtn:SetPoint("LEFT", searchInput, "RIGHT", 6, 0)
    searchBtn:SetText(L["GO"])

    cy = cy - 28

    -- Info text
    local infoText = searchCard.content:CreateFontString(nil, "OVERLAY")
    infoText:SetFont(FONT, FONT_SIZES.tiny, "")
    infoText:SetPoint("TOPLEFT", 0, cy)
    infoText:SetText("|cFF888888" .. L["CLICK_RESULT_HINT"] .. "|r")
    cy = cy - 14

    -- Results container (clickable buttons)
    local resultButtons = {}
    for i = 1, 5 do
        local btn = CreateFrame("Button", nil, searchCard.content)
        btn:SetSize(searchCard.contentWidth or 400, 18)
        btn:SetPoint("TOPLEFT", 0, cy - (i-1) * 20)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.2, 0.2, 0.2, 0)

        btn.text = btn:CreateFontString(nil, "OVERLAY")
        btn.text:SetFont(FONT, FONT_SIZES.small, "")
        btn.text:SetPoint("LEFT", 4, 0)
        btn.text:SetPoint("RIGHT", -4, 0)
        btn.text:SetJustifyH("LEFT")
        btn.text:SetTextColor(COLORS.textGray[1], COLORS.textGray[2], COLORS.textGray[3])

        btn:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(0.3, 0.3, 0.2, 0.5)
            self.text:SetTextColor(1, 0.85, 0.3)
        end)
        btn:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(0.2, 0.2, 0.2, 0)
            self.text:SetTextColor(COLORS.textWhite[1], COLORS.textWhite[2], COLORS.textWhite[3])
        end)

        btn:Hide()
        resultButtons[i] = btn
    end

    -- No results text
    local noResultText = searchCard.content:CreateFontString(nil, "OVERLAY")
    noResultText:SetFont(FONT, FONT_SIZES.small, "")
    noResultText:SetPoint("TOPLEFT", 0, cy)
    noResultText:SetText("|cFF888888" .. L["SEARCH_PLACEHOLDER"] .. "|r")
    noResultText:SetTextColor(COLORS.textGray[1], COLORS.textGray[2], COLORS.textGray[3])

    local function DoSearch()
        local term = searchInput:GetText()
        if not term or term == "" then
            noResultText:SetText("|cFF888888" .. L["SEARCH_PLACEHOLDER"] .. "|r")
            noResultText:Show()
            for _, btn in ipairs(resultButtons) do btn:Hide() end
            return
        end

        local results = QM:SearchQuests(term, {maxResults = 5})

        -- Hide all buttons first
        for _, btn in ipairs(resultButtons) do btn:Hide() end

        if #results == 0 then
            noResultText:SetText("|cFFFF8888" .. L["NO_QUESTS_FOUND"] .. " |r" .. term)
            noResultText:Show()
        else
            noResultText:Hide()

            for i, quest in ipairs(results) do
                local btn = resultButtons[i]
                if btn then
                    local status = ""
                    if quest.isCompleted then status = "|cFF00FF00✓|r "
                    elseif quest.isActive then status = "|cFFFFFF00►|r "
                    else status = "|cFF888888○|r "
                    end
                    local lvl = quest.level and string.format("|cFF666666[%d]|r ", quest.level) or ""
                    local name = quest.name or "Unknown"
                    if #name > 40 then name = name:sub(1, 38) .. "..." end

                    btn.text:SetText(status .. lvl .. "|cFFFFFFFF" .. name .. "|r")
                    btn.questData = quest

                    btn:SetScript("OnClick", function(self)
                        local q = self.questData
                        if not q then return end

                        -- Get quest start location from database
                        local startLocs = QM.DB and QM.DB:GetQuestStartLocations(q.id)
                        if startLocs and startLocs[1] then
                            local loc = startLocs[1]
                            QM.currentWaypoint = {
                                questId = q.id,
                                objectiveIndex = 0,
                                x = loc.x,
                                y = loc.y,
                                mapId = loc.mapId,
                                description = q.name .. " (Start)",
                                isManual = true,
                            }
                            QM.manualWaypoint = true
                            QM:UpdateArrow()
                            print("|cFF00FF00QuestMaster:|r Waypoint set to quest: " .. q.name)
                        else
                            print("|cFFFF8800QuestMaster:|r No location data for: " .. q.name)
                        end

                        -- Show quest info in chat
                        print("|cFFFFD700Quest:|r " .. (q.name or "Unknown") .. " |cFF888888[" .. (q.level or "?") .. "]|r")
                        if q.objectives then
                            print("|cFFFFD700Objectives:|r")
                            for _, obj in ipairs(q.objectives) do
                                print("  - " .. (obj or ""))
                            end
                        end
                    end)

                    btn:Show()
                end
            end
        end
    end

    searchInput:SetScript("OnEnterPressed", function(self)
        DoSearch()
        self:ClearFocus()
    end)
    searchBtn:SetScript("OnClick", DoSearch)

    -- Manual Waypoint
    local waypointCard
    waypointCard, y = CreateCard(content, y, L["MANUAL_WAYPOINT"], "Interface\\Icons\\Ability_Hunter_Pathfinding", 120)
    cy = -4

    -- Current waypoint display
    local waypointText = waypointCard.content:CreateFontString(nil, "OVERLAY")
    waypointText:SetFont(FONT, FONT_SIZES.small, "")
    waypointText:SetPoint("TOPLEFT", 0, cy)
    waypointText:SetTextColor(COLORS.textGray[1], COLORS.textGray[2], COLORS.textGray[3])

    local function UpdateWaypointDisplay()
        if QM.currentWaypoint then
            local wp = QM.currentWaypoint
            local desc = wp.description or L["WAYPOINT"]
            if #desc > 30 then desc = desc:sub(1, 28) .. "..." end
            local coords = string.format("%.1f, %.1f", (wp.x or 0) * 100, (wp.y or 0) * 100)
            local manualTag = QM.manualWaypoint and " |cFF00FF00" .. L["MANUAL"] .. "|r" or ""
            waypointText:SetText("|cFFFFD700" .. L["CURRENT_WAYPOINT"] .. "|r " .. desc .. " (" .. coords .. ")" .. manualTag)
        else
            waypointText:SetText("|cFF888888" .. L["NO_WAYPOINT_SET"] .. "|r")
        end
    end

    UpdateWaypointDisplay()
    cy = cy - 22

    -- Coordinate inputs (larger fields)
    local xLabel = waypointCard.content:CreateFontString(nil, "OVERLAY")
    xLabel:SetFont(FONT, FONT_SIZES.small, "")
    xLabel:SetPoint("TOPLEFT", 0, cy)
    xLabel:SetText(L["X_COORD"])
    xLabel:SetTextColor(COLORS.textGray[1], COLORS.textGray[2], COLORS.textGray[3])

    local xInput = CreateFrame("EditBox", nil, waypointCard.content, "InputBoxTemplate")
    xInput:SetSize(70, 22)
    xInput:SetPoint("LEFT", xLabel, "RIGHT", 6, 0)
    xInput:SetAutoFocus(false)
    xInput:SetMaxLetters(10)

    local yLabel = waypointCard.content:CreateFontString(nil, "OVERLAY")
    yLabel:SetFont(FONT, FONT_SIZES.small, "")
    yLabel:SetPoint("LEFT", xInput, "RIGHT", 16, 0)
    yLabel:SetText(L["Y_COORD"])
    yLabel:SetTextColor(COLORS.textGray[1], COLORS.textGray[2], COLORS.textGray[3])

    local yInput = CreateFrame("EditBox", nil, waypointCard.content, "InputBoxTemplate")
    yInput:SetSize(70, 22)
    yInput:SetPoint("LEFT", yLabel, "RIGHT", 6, 0)
    yInput:SetAutoFocus(false)
    yInput:SetMaxLetters(10)

    local setBtn = CreateFrame("Button", nil, waypointCard.content, "UIPanelButtonTemplate")
    setBtn:SetSize(50, 22)
    setBtn:SetPoint("LEFT", yInput, "RIGHT", 12, 0)
    setBtn:SetText(L["SET"])
    setBtn:SetScript("OnClick", function()
        local x = tonumber(xInput:GetText())
        local yCoord = tonumber(yInput:GetText())
        if x and yCoord and x >= 0 and x <= 100 and yCoord >= 0 and yCoord <= 100 then
            QM:HandleWayCommand(string.format("%.1f %.1f", x, yCoord))
            UpdateWaypointDisplay()
        else
            print("|cFFFF0000QuestMaster:|r " .. L["INVALID_COORDINATES"])
        end
    end)

    cy = cy - 32

    -- Help text
    local helpText = waypointCard.content:CreateFontString(nil, "OVERLAY")
    helpText:SetFont(FONT, FONT_SIZES.tiny, "")
    helpText:SetPoint("TOPLEFT", 0, cy)
    helpText:SetText("|cFF666666" .. L["COORD_HINT"] .. "|r")
    cy = cy - 16

    local clearBtn = CreateFrame("Button", nil, waypointCard.content, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 22)
    clearBtn:SetPoint("TOPLEFT", 0, cy)
    clearBtn:SetText(L["CLEAR_WAYPOINT"])
    clearBtn:SetScript("OnClick", function()
        QM:ClearWaypoint()
        QM.manualWaypoint = false
        UpdateWaypointDisplay()
    end)

    -- Party Quest Sync Card
    card, y = CreateCard(content, y, L["PARTY_SYNC"], "Interface\\Icons\\Ability_Warrior_RallyingCry", 130)
    cy = -4
    cy = CreateToggle(card.content, cy, L["ENABLE_PARTY_SYNC"], L["ENABLE_PARTY_SYNC_DESC"],
        function() return QM.db.profile.partySync and QM.db.profile.partySync.enabled end,
        function(v) if QM.db.profile.partySync then QM.db.profile.partySync.enabled = v end end)
    cy = CreateToggle(card.content, cy, L["PARTY_SHOW_PROGRESS"], L["PARTY_SHOW_PROGRESS_DESC"],
        function() return QM.db.profile.partySync and QM.db.profile.partySync.showInTracker end,
        function(v) if QM.db.profile.partySync then QM.db.profile.partySync.showInTracker = v end; if QM.UpdateTracker then QM:UpdateTracker() end end)
    cy = CreateToggle(card.content, cy, L["PARTY_SHOW_INDICATOR"], L["PARTY_SHOW_INDICATOR_DESC"],
        function() return QM.db.profile.partySync and QM.db.profile.partySync.showPartyIndicator end,
        function(v) if QM.db.profile.partySync then QM.db.profile.partySync.showPartyIndicator = v end; if QM.UpdateTracker then QM:UpdateTracker() end end)

    content:SetHeight(math.abs(y) + 20)
end

function QM:CreateAutomationTab(content)
    local y = -8
    local card, cy

    card, y = CreateCard(content, y, L["QUEST_AUTOMATION"], "Interface\\Icons\\Spell_Nature_TimeStop", 172)
    cy = -4
    cy = CreateToggle(card.content, cy, L["AUTO_ACCEPT"], L["AUTO_ACCEPT_DESC"],
        function() return QM.db.profile.auto.acceptQuests end,
        function(v) QM.db.profile.auto.acceptQuests = v end)
    cy = CreateToggle(card.content, cy, L["AUTO_COMPLETE"], L["AUTO_COMPLETE_DESC"],
        function() return QM.db.profile.auto.completeQuests end,
        function(v) QM.db.profile.auto.completeQuests = v end)
    cy = CreateToggle(card.content, cy, L["SKIP_REWARD_CHOICE"], L["SKIP_REWARD_CHOICE_DESC"],
        function() return QM.db.profile.auto.skipRewardChoice ~= false end,
        function(v) QM.db.profile.auto.skipRewardChoice = v end)
    cy = CreateToggle(card.content, cy, L["AUTO_SHARE"], L["AUTO_SHARE_DESC"],
        function() return QM.db.profile.auto.shareQuests end,
        function(v) QM.db.profile.auto.shareQuests = v end)

    card, y = CreateCard(content, y, L["WAYPOINT_AUTO"], "Interface\\Icons\\Ability_Hunter_Pathfinding", 130)
    cy = -4
    cy = CreateToggle(card.content, cy, L["AUTO_SET_WAYPOINT"], L["AUTO_SET_WAYPOINT_DESC"],
        function() return QM.db.profile.auto.waypoint ~= false end,
        function(v) QM.db.profile.auto.waypoint = v end)
    cy = CreateToggle(card.content, cy, L["AUTO_ADVANCE"], L["AUTO_ADVANCE_DESC"],
        function() return QM.db.profile.auto.advanceWaypoint ~= false end,
        function(v) QM.db.profile.auto.advanceWaypoint = v end)
    cy = CreateToggle(card.content, cy, L["PRIORITIZE_TURNINS"], L["PRIORITIZE_TURNINS_DESC"],
        function() return QM.db.profile.auto.prioritizeTurnIn end,
        function(v) QM.db.profile.auto.prioritizeTurnIn = v end)

    card, y = CreateCard(content, y, L["QUEST_FILTERS"], "Interface\\Icons\\INV_Misc_Note_05", 215)
    cy = -4
    cy = CreateToggle(card.content, cy, L["SHOW_DUNGEON"], L["SHOW_DUNGEON_DESC"],
        function() return QM.db.profile.filter.showDungeon ~= false end,
        function(v) QM.db.profile.filter.showDungeon = v; if QM.UpdateTracker then QM:UpdateTracker() end end)
    cy = CreateToggle(card.content, cy, L["SHOW_RAID"], L["SHOW_RAID_DESC"],
        function() return QM.db.profile.filter.showRaid ~= false end,
        function(v) QM.db.profile.filter.showRaid = v; if QM.UpdateTracker then QM:UpdateTracker() end end)
    cy = CreateToggle(card.content, cy, L["SHOW_GROUP"], L["SHOW_GROUP_DESC"],
        function() return QM.db.profile.filter.showGroup ~= false end,
        function(v) QM.db.profile.filter.showGroup = v; if QM.UpdateTracker then QM:UpdateTracker() end end)
    cy = CreateToggle(card.content, cy, L["SHOW_PVP"], L["SHOW_PVP_DESC"],
        function() return QM.db.profile.filter.showPvP ~= false end,
        function(v) QM.db.profile.filter.showPvP = v; if QM.UpdateTracker then QM:UpdateTracker() end end)
    cy = CreateToggle(card.content, cy, L["SHOW_LOW_LEVEL"], L["SHOW_LOW_LEVEL_DESC"],
        function() return QM.db.profile.filter.showLowLevel end,
        function(v) QM.db.profile.filter.showLowLevel = v; if QM.UpdateTracker then QM:UpdateTracker() end end)

    content:SetHeight(math.abs(y) + 20)
end

function QM:CreateAdvancedTab(content)
    local y = -8
    local card, cy

    card, y = CreateCard(content, y, L["THEME"], "Interface\\Icons\\INV_Misc_Gem_Variety_02", 60)
    cy = -4
    cy = CreateDropdown(card.content, cy, L["COLOR_THEME"],
        {
            {value = "gold", text = L["THEME_GOLD"]},
            {value = "blue", text = L["THEME_BLUE"]},
            {value = "green", text = L["THEME_GREEN"]},
            {value = "red", text = L["THEME_RED"]},
            {value = "purple", text = L["THEME_PURPLE"]},
            {value = "orange", text = L["THEME_ORANGE"]},
            {value = "teal", text = L["THEME_TEAL"]},
            {value = "pink", text = L["THEME_PINK"]},
            {value = "silver", text = L["THEME_SILVER"]},
            {value = "bronze", text = L["THEME_BRONZE"]},
        },
        function() return QM.db.profile.theme or "gold" end,
        function(v) QM.db.profile.theme = v; if QM.ApplyTheme then QM:ApplyTheme(v) end; if QM.UpdateTracker then QM:UpdateTracker() end end)

    card, y = CreateCard(content, y, L["PERFORMANCE"], "Interface\\Icons\\Spell_Nature_Thunderclap", 165)
    cy = -4
    cy = CreateSlider(card.content, cy, L["UPDATE_INTERVAL"], 0.5, 3.0, 0.25,
        function() return QM.db.profile.performance.updateInterval or 1.0 end,
        function(v) QM.db.profile.performance.updateInterval = v end,
        function(v) return string.format("%.2fs", v) end)
    cy = CreateSlider(card.content, cy, L["UPDATE_THROTTLE"], 0.05, 0.5, 0.05,
        function() return QM.db.profile.performance.updateThrottle or 0.1 end,
        function(v) QM.db.profile.performance.updateThrottle = v end,
        function(v) return string.format("%.2fs", v) end)
    cy = CreateToggle(card.content, cy, L["REDUCE_MAP_UPDATES"], L["REDUCE_MAP_UPDATES_DESC"],
        function() return QM.db.profile.performance.lazyMapUpdates end,
        function(v) QM.db.profile.performance.lazyMapUpdates = v end)

    card, y = CreateCard(content, y, L["QUEST_NOTES"], "Interface\\Icons\\INV_Misc_Note_03", 60)
    cy = -4
    cy = CreateSlider(card.content, cy, L["MAX_NOTE_LENGTH"], 50, 500, 50,
        function() return QM.db.profile.advanced and QM.db.profile.advanced.maxNoteLength or 200 end,
        function(v)
            if not QM.db.profile.advanced then QM.db.profile.advanced = {} end
            QM.db.profile.advanced.maxNoteLength = v
        end,
        function(v) return string.format("%d chars", v) end)

    card, y = CreateCard(content, y, L["DEBUG_TOOLS"], "Interface\\Icons\\Trade_Engineering", 125)
    cy = -4
    cy = CreateToggle(card.content, cy, L["DEBUG_MODE"], L["DEBUG_MODE_DESC"],
        function() return QM.db.profile.debug end,
        function(v) QM.db.profile.debug = v end)
    cy = CreateButton(card.content, cy, L["RESET_SETTINGS"], function() StaticPopup_Show("QUESTMASTER_RESET_CONFIRM") end)
    cy = CreateButton(card.content, cy, L["RELOAD_UI"], function() ReloadUI() end)

    content:SetHeight(math.abs(y) + 20)
end

-- ============================================================================
-- Dashboard Tab - Statistics Overview, Zone Progress, Quest History
-- ============================================================================

-- Helper: create a small progress bar inside a card
local function CreateProgressBarWidget(parent, width, height)
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetSize(width, height)
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bar:SetBackdropColor(0.1, 0.1, 0.12, 1)
    bar:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], 0.5)

    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetPoint("TOPLEFT", 1, -1)
    bar.fill:SetHeight(height - 2)
    bar.fill:SetTexture("Interface\\Buttons\\WHITE8x8")
    bar.fill:SetVertexColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.85)

    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.text:SetFont(FONT, 8, "")
    bar.text:SetPoint("CENTER")
    bar.text:SetTextColor(COLORS.textWhite[1], COLORS.textWhite[2], COLORS.textWhite[3])

    function bar:SetProgress(current, total, label)
        local pct = total > 0 and (current / total) or 0
        pct = math.min(pct, 1)
        self.fill:SetWidth(math.max((self:GetWidth() - 2) * pct, 1))
        self.text:SetText(label or string.format("%d/%d (%.0f%%)", current, total, pct * 100))
    end

    function bar:SetBarColor(r, g, b)
        self.fill:SetVertexColor(r, g, b, 0.85)
    end

    return bar
end

function QM:CreateDashboardTab(content)
    local y = -8
    local card, cy

    -- ===== OVERVIEW CARD =====
    local summary = self:GetStatsSummary()

    card, y = CreateCard(content, y, L["DASH_OVERVIEW"], "Interface\\Icons\\INV_Misc_PocketWatch_02", 170)
    cy = -4

    -- 3 stat boxes side by side
    local boxWidth = math.floor((card.contentWidth - 12) / 3)

    local function CreateMiniStatBox(parent, xOff, yOff, value, label, color)
        local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        box:SetSize(boxWidth, 50)
        box:SetPoint("TOPLEFT", xOff, yOff)
        box:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
        box:SetBackdropColor(COLORS.bgDark[1], COLORS.bgDark[2], COLORS.bgDark[3], 1)

        local valText = box:CreateFontString(nil, "OVERLAY")
        valText:SetFont(FONT, FONT_SIZES.huge, "")
        valText:SetPoint("TOP", 0, -6)
        valText:SetTextColor(color[1], color[2], color[3])
        valText:SetText(value)

        local lblText = box:CreateFontString(nil, "OVERLAY")
        lblText:SetFont(FONT, FONT_SIZES.tiny, "")
        lblText:SetPoint("TOP", 0, -30)
        lblText:SetTextColor(COLORS.textMuted[1], COLORS.textMuted[2], COLORS.textMuted[3])
        lblText:SetText(label)
    end

    CreateMiniStatBox(card.content, 0, cy, tostring(summary.totalCompleted or 0),
        L["QUESTS_COMPLETED"], COLORS.enabled)
    CreateMiniStatBox(card.content, boxWidth + 6, cy,
        QM:FormatNumber(summary.totalXP or 0), L["TOTAL_XP_GAINED"], COLORS.blue)
    CreateMiniStatBox(card.content, (boxWidth + 6) * 2, cy,
        string.format("%.1f", summary.questsPerHour or 0), L["QUESTS_PER_HOUR"], {1, 0.75, 0.3})

    cy = cy - 58

    -- Detail lines
    local function AddDetailLine(parent, yPos, label, value)
        local lbl = parent:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(FONT, FONT_SIZES.small, "")
        lbl:SetPoint("TOPLEFT", 4, yPos)
        lbl:SetTextColor(COLORS.textGray[1], COLORS.textGray[2], COLORS.textGray[3])
        lbl:SetText(label)

        local val = parent:CreateFontString(nil, "OVERLAY")
        val:SetFont(FONT, FONT_SIZES.small, "")
        val:SetPoint("TOPRIGHT", -4, yPos)
        val:SetTextColor(COLORS.textWhite[1], COLORS.textWhite[2], COLORS.textWhite[3])
        val:SetText(value)

        return yPos - 16
    end

    cy = AddDetailLine(card.content, cy, L["AVG_QUEST_TIME"],
        QM:FormatPlayTime(summary.averageTime or 0))
    cy = AddDetailLine(card.content, cy, L["SESSION_QUESTS"],
        tostring(summary.sessionCompleted or 0))
    cy = AddDetailLine(card.content, cy, L["SESSION_XP"],
        QM:FormatNumber(summary.sessionXP or 0))

    if summary.fastestQuest then
        cy = AddDetailLine(card.content, cy, L["DASH_FASTEST_QUEST"],
            string.format("%s (%s)", summary.fastestQuest.title or "?",
                QM:FormatPlayTime(summary.fastestQuest.duration or 0)))
    end
    if summary.slowestQuest then
        cy = AddDetailLine(card.content, cy, L["DASH_SLOWEST_QUEST"],
            string.format("%s (%s)", summary.slowestQuest.title or "?",
                QM:FormatPlayTime(summary.slowestQuest.duration or 0)))
    end

    -- ===== TOP ZONES CARD =====
    local topZones = summary.topZones or {}
    if #topZones > 0 then
        local zoneCardHeight = 4 + (#topZones * 18)
        card, y = CreateCard(content, y, L["DASH_TOP_ZONES"],
            "Interface\\Icons\\Achievement_Zone_Stranglethorn_01", zoneCardHeight)
        cy = -4

        for i, zone in ipairs(topZones) do
            local rank = card.content:CreateFontString(nil, "OVERLAY")
            rank:SetFont(FONT, FONT_SIZES.small, "")
            rank:SetPoint("TOPLEFT", 0, cy)
            rank:SetTextColor(COLORS.textMuted[1], COLORS.textMuted[2], COLORS.textMuted[3])
            rank:SetText(string.format("#%d", i))

            local zName = card.content:CreateFontString(nil, "OVERLAY")
            zName:SetFont(FONT, FONT_SIZES.small, "")
            zName:SetPoint("TOPLEFT", 22, cy)
            zName:SetTextColor(COLORS.textWhite[1], COLORS.textWhite[2], COLORS.textWhite[3])
            zName:SetText(zone.name)

            local zCount = card.content:CreateFontString(nil, "OVERLAY")
            zCount:SetFont(FONT, FONT_SIZES.small, "")
            zCount:SetPoint("TOPRIGHT", -4, cy)
            zCount:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            zCount:SetText(tostring(zone.count))

            cy = cy - 18
        end
    end

    -- ===== ZONE PROGRESS CARD =====
    local completedByZone = self.db.char.completedQuestsByZone or {}
    local zoneData = {}
    for zoneName, quests in pairs(completedByZone) do
        local completed = 0
        for _ in pairs(quests) do completed = completed + 1 end
        local total = self:GetTotalZoneQuests(zoneName)
        local pct = total > 0 and (completed / total * 100) or 0
        table.insert(zoneData, {name = zoneName, completed = completed, total = total, percent = pct})
    end
    table.sort(zoneData, function(a, b) return a.percent > b.percent end)

    if #zoneData > 0 then
        -- Show max 10 zones to keep card manageable
        local maxZones = math.min(#zoneData, 10)
        local zoneCardHeight = 28 + (maxZones * 30)

        card, y = CreateCard(content, y, L["DASH_ZONES"],
            "Interface\\Icons\\INV_Misc_Map_01", zoneCardHeight)
        cy = -4

        -- Overall progress bar
        local totalCompleted, totalQuests = 0, 0
        for _, z in ipairs(zoneData) do
            totalCompleted = totalCompleted + z.completed
            totalQuests = totalQuests + z.total
        end

        local overallBar = CreateProgressBarWidget(card.content, card.contentWidth, 14)
        overallBar:SetPoint("TOPLEFT", 0, cy)
        overallBar:SetProgress(totalCompleted, totalQuests,
            string.format(L["DASH_OVERALL_PROGRESS"] .. ": %d/%d (%.0f%%)",
                totalCompleted, totalQuests,
                totalQuests > 0 and (totalCompleted / totalQuests * 100) or 0))
        cy = cy - 22

        for i = 1, maxZones do
            local zone = zoneData[i]

            local zName = card.content:CreateFontString(nil, "OVERLAY")
            zName:SetFont(FONT, FONT_SIZES.small, "")
            zName:SetPoint("TOPLEFT", 0, cy)
            zName:SetWidth(200)
            zName:SetJustifyH("LEFT")
            zName:SetTextColor(COLORS.textWhite[1], COLORS.textWhite[2], COLORS.textWhite[3])
            zName:SetText(zone.name)

            local pctText = card.content:CreateFontString(nil, "OVERLAY")
            pctText:SetFont(FONT, FONT_SIZES.tiny, "")
            pctText:SetPoint("TOPRIGHT", -4, cy)
            if zone.percent >= 100 then
                pctText:SetTextColor(COLORS.enabled[1], COLORS.enabled[2], COLORS.enabled[3])
            elseif zone.percent >= 50 then
                pctText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            else
                pctText:SetTextColor(COLORS.textGray[1], COLORS.textGray[2], COLORS.textGray[3])
            end
            pctText:SetText(string.format("%.0f%%", zone.percent))

            local bar = CreateProgressBarWidget(card.content, card.contentWidth, 8)
            bar:SetPoint("TOPLEFT", 0, cy - 14)
            bar:SetProgress(zone.completed, zone.total,
                string.format("%d/%d", zone.completed, zone.total))
            bar.text:SetFont(FONT, 7, "")

            if zone.percent >= 100 then
                bar:SetBarColor(COLORS.enabled[1], COLORS.enabled[2], COLORS.enabled[3])
            elseif zone.percent >= 75 then
                bar:SetBarColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            elseif zone.percent >= 50 then
                bar:SetBarColor(COLORS.blue[1], COLORS.blue[2], COLORS.blue[3])
            end

            cy = cy - 30
        end
    end

    -- ===== QUEST HISTORY CARD =====
    local history = self:GetQuestHistory()

    if #history > 0 then
        local maxDisplay = math.min(#history, 15)
        local histCardHeight = 24 + (maxDisplay * 18) + 8

        card, y = CreateCard(content, y, L["DASH_HISTORY"],
            "Interface\\Icons\\INV_Misc_Note_01", histCardHeight)
        cy = -2

        -- Column headers
        local hQuest = card.content:CreateFontString(nil, "OVERLAY")
        hQuest:SetFont(FONT, FONT_SIZES.tiny, "")
        hQuest:SetPoint("TOPLEFT", 0, cy)
        hQuest:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        hQuest:SetText(L["DASH_COL_QUEST"])

        local hLvl = card.content:CreateFontString(nil, "OVERLAY")
        hLvl:SetFont(FONT, FONT_SIZES.tiny, "")
        hLvl:SetPoint("TOPLEFT", 230, cy)
        hLvl:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        hLvl:SetText(L["DASH_COL_LEVEL"])

        local hXP = card.content:CreateFontString(nil, "OVERLAY")
        hXP:SetFont(FONT, FONT_SIZES.tiny, "")
        hXP:SetPoint("TOPLEFT", 268, cy)
        hXP:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        hXP:SetText(L["DASH_COL_XP"])

        local hDur = card.content:CreateFontString(nil, "OVERLAY")
        hDur:SetFont(FONT, FONT_SIZES.tiny, "")
        hDur:SetPoint("TOPLEFT", 330, cy)
        hDur:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        hDur:SetText(L["DASH_COL_TIME"])

        local hDate = card.content:CreateFontString(nil, "OVERLAY")
        hDate:SetFont(FONT, FONT_SIZES.tiny, "")
        hDate:SetPoint("TOPLEFT", 396, cy)
        hDate:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        hDate:SetText(L["DASH_COL_DATE"])

        cy = cy - 14

        -- Separator
        local sep = card.content:CreateTexture(nil, "ARTWORK")
        sep:SetSize(card.contentWidth, 1)
        sep:SetPoint("TOPLEFT", 0, cy)
        sep:SetColorTexture(COLORS.border[1], COLORS.border[2], COLORS.border[3], 0.4)
        cy = cy - 6

        for i = 1, maxDisplay do
            local entry = history[i]

            -- Alternating row bg
            if i % 2 == 0 then
                local rowBg = card.content:CreateTexture(nil, "BACKGROUND")
                rowBg:SetSize(card.contentWidth, 16)
                rowBg:SetPoint("TOPLEFT", 0, cy + 2)
                rowBg:SetColorTexture(1, 1, 1, 0.02)
            end

            local rTitle = card.content:CreateFontString(nil, "OVERLAY")
            rTitle:SetFont(FONT, FONT_SIZES.tiny, "")
            rTitle:SetPoint("TOPLEFT", 0, cy)
            rTitle:SetWidth(225)
            rTitle:SetJustifyH("LEFT")
            rTitle:SetWordWrap(false)
            rTitle:SetTextColor(COLORS.textWhite[1], COLORS.textWhite[2], COLORS.textWhite[3])
            rTitle:SetText(entry.title or "?")

            local rLvl = card.content:CreateFontString(nil, "OVERLAY")
            rLvl:SetFont(FONT, FONT_SIZES.tiny, "")
            rLvl:SetPoint("TOPLEFT", 230, cy)
            rLvl:SetTextColor(COLORS.textGray[1], COLORS.textGray[2], COLORS.textGray[3])
            rLvl:SetText(tostring(entry.level or "?"))

            local rXP = card.content:CreateFontString(nil, "OVERLAY")
            rXP:SetFont(FONT, FONT_SIZES.tiny, "")
            rXP:SetPoint("TOPLEFT", 268, cy)
            rXP:SetTextColor(COLORS.blue[1], COLORS.blue[2], COLORS.blue[3])
            rXP:SetText(QM:FormatNumber(entry.xp or 0))

            local rDur = card.content:CreateFontString(nil, "OVERLAY")
            rDur:SetFont(FONT, FONT_SIZES.tiny, "")
            rDur:SetPoint("TOPLEFT", 330, cy)
            rDur:SetTextColor(COLORS.textGray[1], COLORS.textGray[2], COLORS.textGray[3])
            rDur:SetText(QM:FormatPlayTime(entry.duration or 0))

            local rDate = card.content:CreateFontString(nil, "OVERLAY")
            rDate:SetFont(FONT, FONT_SIZES.tiny, "")
            rDate:SetPoint("TOPLEFT", 396, cy)
            rDate:SetTextColor(COLORS.textMuted[1], COLORS.textMuted[2], COLORS.textMuted[3])
            rDate:SetText(entry.timestamp and date("%m/%d %H:%M", entry.timestamp) or "-")

            cy = cy - 18
        end

        if #history > maxDisplay then
            local moreText = card.content:CreateFontString(nil, "OVERLAY")
            moreText:SetFont(FONT, FONT_SIZES.tiny, "")
            moreText:SetPoint("TOPLEFT", 4, cy)
            moreText:SetTextColor(COLORS.textMuted[1], COLORS.textMuted[2], COLORS.textMuted[3])
            moreText:SetText(string.format(L["DASH_MORE_ENTRIES"], #history - maxDisplay))
        end
    else
        card, y = CreateCard(content, y, L["DASH_HISTORY"],
            "Interface\\Icons\\INV_Misc_Note_01", 30)
        cy = -4

        local noHist = card.content:CreateFontString(nil, "OVERLAY")
        noHist:SetFont(FONT, FONT_SIZES.small, "")
        noHist:SetPoint("TOPLEFT", 4, cy)
        noHist:SetTextColor(COLORS.textMuted[1], COLORS.textMuted[2], COLORS.textMuted[3])
        noHist:SetText(L["DASH_NO_HISTORY"])
    end

    -- Open full dashboard button (opens standalone popup with search/sort)
    card, y = CreateCard(content, y, L["DASH_TITLE"], "Interface\\Icons\\INV_Misc_Book_09", 46)
    cy = -4
    cy = CreateButton(card.content, cy, L["OPEN_DASHBOARD"], function()
        QM:ToggleDashboard()
    end)

    content:SetHeight(math.abs(y) + 20)
end

function QM:CreateCreditsTab(content)
    local y = -8

    -- ===== ADDON INFO =====
    local headerCard = CreateFrame("Frame", nil, content, "BackdropTemplate")
    headerCard:SetSize(CONTENT_WIDTH, 140)
    headerCard:SetPoint("TOPLEFT", 8, y)
    headerCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    headerCard:SetBackdropColor(COLORS.bgCard[1], COLORS.bgCard[2], COLORS.bgCard[3], 0.95)
    headerCard:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], 0.7)

    -- Gold accent
    local headerAccent = headerCard:CreateTexture(nil, "ARTWORK", nil, 1)
    headerAccent:SetHeight(3)
    headerAccent:SetPoint("TOPLEFT", 1, -1)
    headerAccent:SetPoint("TOPRIGHT", -1, -1)
    headerAccent:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.7)
    RegisterThemedElement(headerAccent, "accent", 0.7)

    -- Large Icon
    local bigIcon = headerCard:CreateTexture(nil, "ARTWORK")
    bigIcon:SetSize(64, 64)
    bigIcon:SetPoint("LEFT", 20, 0)
    bigIcon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")

    -- Icon glow
    local iconGlow = headerCard:CreateTexture(nil, "BACKGROUND")
    iconGlow:SetSize(80, 80)
    iconGlow:SetPoint("CENTER", bigIcon, "CENTER", 0, 0)
    iconGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
    iconGlow:SetVertexColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.1)
    iconGlow:SetBlendMode("ADD")

    -- Addon Name
    local addonName = headerCard:CreateFontString(nil, "OVERLAY")
    addonName:SetFont(FONT, 22, "")
    addonName:SetPoint("TOPLEFT", bigIcon, "TOPRIGHT", 20, -8)
    addonName:SetText("|cFFFFD700Quest|r|cFFFFFFFFMaster|r")

    -- Version
    local versionText = headerCard:CreateFontString(nil, "OVERLAY")
    versionText:SetFont(FONT, 12, "")
    versionText:SetPoint("TOPLEFT", addonName, "BOTTOMLEFT", 0, -4)
    versionText:SetText("|cFF888888" .. L["CREDITS_VERSION"] .. "|r |cFF555555-|r |cFF666666" .. L["CREDITS_EDITION"] .. "|r")

    -- Description
    local descText = headerCard:CreateFontString(nil, "OVERLAY")
    descText:SetFont(FONT, 10, "")
    descText:SetPoint("TOPLEFT", versionText, "BOTTOMLEFT", 0, -12)
    descText:SetWidth(360)
    descText:SetJustifyH("LEFT")
    descText:SetText("|cFFAAAAAA" .. L["CREDITS_DESCRIPTION"] .. "|r")

    y = y - 150

    -- ===== DEVELOPER =====
    local card, cy
    card, y = CreateCard(content, y, L["DEVELOPER"], "Interface\\Icons\\Achievement_Character_Human_Male", 100)
    cy = -8

    local devName = card.content:CreateFontString(nil, "OVERLAY")
    devName:SetFont(FONT, 14, "")
    devName:SetPoint("TOPLEFT", 8, cy)
    devName:SetText("|cFF00FF00JugoBetrugoTV|r")
    cy = cy - 18

    local devAka = card.content:CreateFontString(nil, "OVERLAY")
    devAka:SetFont(FONT, 11, "")
    devAka:SetPoint("TOPLEFT", 8, cy)
    devAka:SetText("|cFF666666" .. L["ALSO_KNOWN_AS"] .. "|r |cFFFF8800Novi_Live|r")
    cy = cy - 24

    local devDesc = card.content:CreateFontString(nil, "OVERLAY")
    devDesc:SetFont(FONT, 9, "")
    devDesc:SetPoint("TOPLEFT", 8, cy)
    devDesc:SetWidth(card.contentWidth - 16)
    devDesc:SetJustifyH("LEFT")
    devDesc:SetText("|cFF888888" .. L["DEVELOPER_BIO"] .. "|r")

    -- ===== SOCIAL LINKS =====
    card, y = CreateCard(content, y, L["CONNECT"], "Interface\\Icons\\INV_Misc_GroupNeedMore", 110)
    cy = -8

    -- Twitch
    local twitchIcon = card.content:CreateTexture(nil, "ARTWORK")
    twitchIcon:SetSize(18, 18)
    twitchIcon:SetPoint("TOPLEFT", 8, cy)
    twitchIcon:SetTexture("Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon")
    twitchIcon:SetVertexColor(0.6, 0.3, 1)

    local twitchText = card.content:CreateFontString(nil, "OVERLAY")
    twitchText:SetFont(FONT, 11, "")
    twitchText:SetPoint("LEFT", twitchIcon, "RIGHT", 10, 0)
    twitchText:SetText("|cFF9146FF" .. L["TWITCH"] .. "|r |cFF555555-|r |cFFDDDDDDtwitch.tv/Novi_Live|r")
    cy = cy - 26

    -- Discord
    local discordIcon = card.content:CreateTexture(nil, "ARTWORK")
    discordIcon:SetSize(18, 18)
    discordIcon:SetPoint("TOPLEFT", 8, cy)
    discordIcon:SetTexture("Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon")
    discordIcon:SetVertexColor(0.35, 0.4, 0.95)

    local discordText = card.content:CreateFontString(nil, "OVERLAY")
    discordText:SetFont(FONT, 11, "")
    discordText:SetPoint("LEFT", discordIcon, "RIGHT", 10, 0)
    discordText:SetText("|cFF5865F2" .. L["DISCORD"] .. "|r |cFF555555-|r |cFFDDDDDDdiscord.gg/rv2BsbE|r")
    cy = cy - 26

    -- CurseForge
    local curseIcon = card.content:CreateTexture(nil, "ARTWORK")
    curseIcon:SetSize(18, 18)
    curseIcon:SetPoint("TOPLEFT", 8, cy)
    curseIcon:SetTexture("Interface\\Icons\\INV_Misc_EngGizmos_27")
    curseIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local curseText = card.content:CreateFontString(nil, "OVERLAY")
    curseText:SetFont(FONT, 11, "")
    curseText:SetPoint("LEFT", curseIcon, "RIGHT", 10, 0)
    curseText:SetText("|cFFFF8800" .. L["CURSEFORGE"] .. "|r |cFF555555-|r |cFFDDDDDD" .. L["DOWNLOADS_BUGS"] .. "|r")

    -- ===== CHANGELOG =====
    card, y = CreateCard(content, y, L["CHANGELOG"], "Interface\\Icons\\INV_Scroll_02", 320)
    cy = -4

    local changelogText = card.content:CreateFontString(nil, "OVERLAY")
    changelogText:SetFont(FONT, 9, "")
    changelogText:SetPoint("TOPLEFT", 8, cy)
    changelogText:SetWidth(card.contentWidth - 16)
    changelogText:SetJustifyH("LEFT")
    changelogText:SetSpacing(2)
    changelogText:SetText(
        "|cFFFFD700v1.3|r |cFF888888- Localization & Fixes|r\n" ..
        "  |cFF00FF00+|r Complete localization (DE, FR, ES, RU, PT)\n" ..
        "  |cFF00FF00+|r Quest Statistics/Search/Waypoint in Settings\n" ..
        "  |cFFFF8800*|r Fixed progress display, waypoint override, level time\n\n" ..
        "|cFFFFD700v1.2|r |cFF888888- Theme System & Tracking|r\n" ..
        "  |cFF00FF00+|r 10 color themes for UI customization\n" ..
        "  |cFF00FF00+|r XP/Hour, Rested XP, Level Time trackers\n" ..
        "  |cFF00FF00+|r Bag/Repair reminders, Zone progress\n" ..
        "  |cFF00FF00+|r Reputation tracker, Quest notes, NPC patrols\n\n" ..
        "|cFFFFD700v1.1|r |cFF888888- UI Improvements|r\n" ..
        "  |cFF00FF00+|r Info bar with combined status display\n" ..
        "  |cFF00FF00+|r Quest timer for individual quests\n" ..
        "  |cFF00AAFFo|r Redesigned tracker with premium styling\n\n" ..
        "|cFFFFD700v1.0|r |cFF888888- Initial Release|r\n" ..
        "  |cFF00FF00+|r Navigation arrow with distance & ETA\n" ..
        "  |cFF00FF00+|r Quest tracker with zone grouping\n" ..
        "  |cFF00FF00+|r World map pins, Quest automation\n" ..
        "  |cFF00FF00+|r Comprehensive TBC quest database\n\n" ..
        "|cFF666666Full changelog: CHANGELOG.md|r"
    )

    -- ===== SPECIAL THANKS =====
    card, y = CreateCard(content, y, L["SPECIAL_THANKS"], "Interface\\Icons\\INV_ValentinesCandy", 70)
    cy = -8

    local thanksText = card.content:CreateFontString(nil, "OVERLAY")
    thanksText:SetFont(FONT, 10, "")
    thanksText:SetPoint("TOPLEFT", 8, cy)
    thanksText:SetWidth(card.contentWidth - 16)
    thanksText:SetJustifyH("LEFT")
    thanksText:SetSpacing(2)
    thanksText:SetText("|cFFDDDDDD" .. L["THANKS_MESSAGE"] .. "|r")

    content:SetHeight(math.abs(y) + 20)
end

-- ============================================================================
-- Public Functions
-- ============================================================================

function QM:ToggleSettings()
    if not QM.db or not QM.db.profile then
        print("|cFFFF0000QuestMaster:|r " .. L["MSG_SETTINGS_NOT_READY"])
        return
    end

    if not SettingsFrame then self:CreateSettingsPanel() end

    if SettingsFrame:IsShown() then
        SettingsFrame:Hide()
        CloseAllMenus()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    else
        SettingsFrame:Show()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
    end
end

function QM:IsSettingsOpen()
    return SettingsFrame and SettingsFrame:IsShown()
end

function QM:InitializeOptions()
    StaticPopupDialogs["QUESTMASTER_RESET_CONFIRM"] = {
        text = L["RESET_CONFIRM"],
        button1 = L["YES"],
        button2 = L["NO"],
        OnAccept = function() QM.db:ResetProfile(); ReloadUI() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

function QM:ShowQuestHistoryWindow()
    print("|cFFFFD700QuestMaster:|r /qm history")
end

-- ============================================================================
-- Theme System Integration
-- ============================================================================

-- Update COLORS from current theme
local function UpdateColorsFromTheme()
    if QM.currentTheme then
        COLORS.gold = QM.currentTheme.accent
        COLORS.goldBright = QM.currentTheme.accentBright
        COLORS.goldDark = QM.currentTheme.accentDark
        COLORS.borderGold = {
            QM.currentTheme.accentDark[1] * 0.85,
            QM.currentTheme.accentDark[2] * 0.85,
            QM.currentTheme.accentDark[3] * 0.85
        }
    end
end

-- Refresh all themed elements in Settings
function QM:RefreshSettingsTheme()
    UpdateColorsFromTheme()

    -- Update all stored themed elements
    for _, elem in ipairs(themedElements) do
        if elem.element and elem.element:IsObjectType("Texture") then
            if elem.type == "accent" then
                elem.element:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], elem.alpha or 0.5)
            elseif elem.type == "fill" then
                elem.element:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], elem.alpha or 0.85)
            end
        elseif elem.element and elem.element:IsObjectType("FontString") then
            if elem.type == "title" then
                elem.element:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            end
        elseif elem.element and elem.type == "sidebar" then
            -- Sidebar active state
            if elem.element.isActive then
                elem.element.bg:SetColorTexture(COLORS.gold[1] * 0.15, COLORS.gold[2] * 0.12, COLORS.gold[3] * 0.08, 1)
                elem.element.accent:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
                elem.element.text:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            end
        end
    end

    -- Update header if exists
    if SettingsFrame and SettingsFrame.header then
        if SettingsFrame.header.accent then
            SettingsFrame.header.accent:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.7)
        end
        if SettingsFrame.header.accentTop then
            SettingsFrame.header.accentTop:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.3)
        end
    end
end

