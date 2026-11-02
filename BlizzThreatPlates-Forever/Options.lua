local addonName = ...
local addon = ForeverNameplates

-- Options typography is separate from nameplate fonts and previews.
function addon:StyleOptionsFont(label, size)
    local path = "Interface\\AddOns\\" .. (addonName or "BlizzThreatPlates-Forever") .. "\\media\\Lato-Regular.ttf"
    self:SetFontWithFallback(label, path, size or 12, "", "Fonts\\ARIALN.TTF")
    label:SetShadowOffset(0, 0)
end

-- Adapt Blizzard's stepped slider to the options' existing slider interface.
local function CreateOptionsSlider(name, parent)
    if not MinimalSliderWithSteppersMixin then
        return CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    end
    local control = CreateFrame("Frame", name, parent, "MinimalSliderWithSteppersTemplate")
    control:SetHeight(20)
    control:Init(0, 0, 1, 1)
    for _, method in ipairs({"SetMinMaxValues", "GetMinMaxValues", "SetValueStep", "GetValueStep",
        "SetObeyStepOnDrag", "GetValue"}) do
        local sliderMethod = method
        control[sliderMethod] = function(self, ...)
            return self.Slider[sliderMethod](self.Slider, ...)
        end
    end
    local setScript = control.SetScript
    control.SetScript = function(self, event, handler)
        if event == "OnValueChanged" then self.btpValueChanged = handler
        else setScript(self, event, handler) end
    end
    control:RegisterCallback("OnValueChanged", function(self, value)
        if self.btpValueChanged then self.btpValueChanged(self, value) end
    end, control)
    -- Retain the existing min/max captions and external current-value labels.
    for suffix, label in pairs({Low=control.MinText, High=control.MaxText, Text=control.TopText}) do
        _G[name..suffix] = label
        label:Show()
    end
    control.MinText:ClearAllPoints()
    control.MinText:SetPoint("TOPLEFT", control.Slider, "BOTTOMLEFT", 0, -1)
    control.MaxText:ClearAllPoints()
    control.MaxText:SetPoint("TOPRIGHT", control.Slider, "BOTTOMRIGHT", 0, -1)
    control.MinText:SetFontObject(GameFontHighlightSmall)
    control.MaxText:SetFontObject(GameFontHighlightSmall)
    return control
end

local MAIN_PANEL_HEIGHT = 644
local MAIN_CONTENT_WIDTH = 620
-- Sidebar outline ends at X=188. The content shell begins 24 units into
-- contentRoot, giving it the same 24-unit gap as the outer margins.
-- Grow only the outer window; retain the content area's original width.
local SIDEBAR_WIDTH = 188
local panel = CreateFrame("Frame", "ForeverNameplatesOptions", UIParent, "BackdropTemplate")
-- Frames start shown. Hide during construction so the first user-open runs
-- OnShow below and loads slider values/check states after saved settings load.
panel:Hide()
panel:SetSize(MAIN_CONTENT_WIDTH, MAIN_PANEL_HEIGHT)
panel:SetScale(0.90)
-- Preserve the previous top edge while extending the footer 10 units down.
panel:SetPoint("CENTER", 0, -5)
panel:SetFrameStrata("DIALOG")
panel:SetClampedToScreen(true)
panel:EnableMouse(true)
panel:SetMovable(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
-- Flat options shell. Keep the existing content coordinates and sizing so
-- changing the window's appearance does not move any of its option controls.
local SHELL_WHITE = "Interface\\Buttons\\WHITE8X8"
panel:SetBackdrop({edgeFile=SHELL_WHITE, edgeSize=1})
panel:SetBackdropBorderColor(0.22, 0.25, 0.29, 0.70)

local header = CreateFrame("Frame", nil, panel, "BackdropTemplate")
header:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
header:SetHeight(45)
header:SetBackdrop({bgFile=SHELL_WHITE})
header:SetBackdropColor(14/255, 16/255, 19/255, 1)
local headerLine = header:CreateTexture(nil, "ARTWORK")
headerLine:SetPoint("BOTTOMLEFT")
headerLine:SetPoint("BOTTOMRIGHT")
headerLine:SetHeight(1)
headerLine:SetColorTexture(0.20, 0.22, 0.25, 1)
headerLine.btpOptionsTextureRole="border"
headerLine.btpOptionsTextureMethod="SetColorTexture"
headerLine.btpOptionsTextureColor={0.20,0.22,0.25,1}
-- Approved Threat Signal mark. Keep it separate from the live title text so
-- the lettering stays crisp at the options window's scale.
local headerLogo = header:CreateTexture(nil, "ARTWORK")
headerLogo.btpDevExclude = true
headerLogo:SetTexture("Interface\\AddOns\\" .. (addonName or "BlizzThreatPlates-Forever") .. "\\media\\ThreatSignal.tga")
headerLogo:SetTexCoord(0.12, 0.88, 0.23, 0.82)
headerLogo:SetSize(30, 20)
headerLogo:SetPoint("LEFT", header, "LEFT", 22, 0)
local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
addon:StyleOptionsFont(title, 18)
title.btpOptionsTextRole="windowTitle"
title:SetPoint("LEFT", headerLogo, "RIGHT", 10, 0)
title:SetText("BlizzThreatPlates")
title:SetTextColor(238/255, 235/255, 221/255)

local close = CreateFrame("Button", nil, panel, "BackdropTemplate")
close:SetSize(24, 24)
close:SetPoint("TOPRIGHT", -14, -12)
close:SetBackdrop({bgFile=SHELL_WHITE})
close:SetBackdropColor(0.085, 0.097, 0.115, 0)
close:SetHighlightTexture(SHELL_WHITE)
close:GetHighlightTexture():SetVertexColor(0.30, 0.34, 0.40, 0.45)
local closeLabel = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
addon:StyleOptionsFont(closeLabel, 22)
closeLabel:SetPoint("CENTER")
closeLabel:SetText("×")
closeLabel:SetTextColor(0.80, 0.82, 0.86)
close:SetFrameStrata("TOOLTIP")
close:SetFrameLevel(panel:GetFrameLevel() + 100)
close:SetScript("OnClick", function() panel:Hide() end)

local footer = CreateFrame("Frame", nil, panel, "BackdropTemplate")
footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 1, 1)
footer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 1)
footer:SetHeight(45)
footer:SetBackdrop({bgFile=SHELL_WHITE})
footer:SetBackdropColor(14/255, 16/255, 19/255, 1)
local footerLine = footer:CreateTexture(nil, "ARTWORK")
footerLine:SetPoint("TOPLEFT")
footerLine:SetPoint("TOPRIGHT")
footerLine:SetHeight(1)
footerLine:SetColorTexture(0.20, 0.22, 0.25, 1)
footerLine.btpOptionsTextureRole="border"
footerLine.btpOptionsTextureMethod="SetColorTexture"
footerLine.btpOptionsTextureColor={0.20,0.22,0.25,1}

-- Keep the body fill strictly between the chrome bars. A fill on the entire
-- parent panel would show through (and tint) transparent headers and footers.
local background = CreateFrame("Frame", nil, panel, "BackdropTemplate")
background:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
background:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
background:SetFrameLevel(panel:GetFrameLevel())
background:EnableMouse(false)
background:SetBackdrop({bgFile=SHELL_WHITE})
-- Promote the chosen developer appearance into production: 10% background
-- transparency, opaque header/footer. Controls and content stay independent.
background:SetBackdropColor(14/255, 16/255, 19/255, 0.90)

local contentInset = CreateFrame("Frame", nil, panel, "BackdropTemplate")
contentInset:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -58)
contentInset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 58)
contentInset:SetFrameLevel(panel:GetFrameLevel() + 1)
contentInset:SetBackdrop({bgFile=SHELL_WHITE})
contentInset:SetBackdropColor(0.055, 0.063, 0.075, 0)

-- Optional developer tools can tune these surfaces without fading controls.
addon.OptionsChrome = {background=background, header=header, footer=footer}

-- Keep existing controls in their original coordinate system when the outer
-- window grows to accommodate navigation. The footer belongs to the shell.
local contentRoot = CreateFrame("Frame", nil, contentInset)
contentRoot:SetWidth(MAIN_CONTENT_WIDTH)
contentRoot:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
contentRoot:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 10)

function addon:SetOptionsSidebarLayout(enabled)
    panel:SetWidth(MAIN_CONTENT_WIDTH + (enabled and SIDEBAR_WIDTH or 0))
    contentRoot:ClearAllPoints()
    contentRoot:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, enabled and 34 or 0)
    contentRoot:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 10)
end

-- Separate page parents keep navigation and the native frame visible.
local function CreatePage()
    local page = CreateFrame("Frame", nil, contentInset)
    page:SetAllPoints(contentRoot)
    page:Hide()
    return page
end
local nameplatesPage = CreatePage()
local colorsPage = CreatePage()
local targetPage = CreatePage()
local activePage = "colors"
local SelectPage

local function CreateSectionHeader(parent, text, y)
    local header = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    header:SetPoint("TOPLEFT", contentRoot, "TOPLEFT", 38, y)
    header:SetPoint("TOPRIGHT", contentRoot, "TOPRIGHT", -38, y)
    header:SetHeight(30)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = {left=2, right=2, top=2, bottom=2},
    })
    header:SetBackdropColor(0.055, 0.045, 0.035, 0.92)
    header:SetBackdropBorderColor(0.30, 0.24, 0.16, 1.0)

    local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text)
    label:SetTextColor(0.94, 0.84, 0.67)
    local r, g, b, a = label:GetTextColor()
    header.btpTitleTextColor = {r, g, b, a}
    return header
end

local threatHeader = CreateSectionHeader(colorsPage, "Colors & Threat", -110)
local mainSectionTitleColor = threatHeader.btpTitleTextColor

local rows = {
    {"secure",  "Default Aggro",      -161},
    {"warning", "Default Warning",    -197},
    {"lost",    "Default Lost Aggro", -233},
}

local swatches = {}
local mainOptionTextColor = nil


local function RefreshSwatches()
    for kind, button in pairs(swatches) do
        local r, g, b = addon:GetThreatColor(kind)
        button.tex:SetColorTexture(r, g, b, 1)
    end
end


local function OpenPicker(kind)
    local r, g, b = addon:GetThreatColor(kind)

    local function ApplyColor(nr, ng, nb)
        addon:SetThreatColor(kind, nr, ng, nb)
        local swatch = swatches[kind]
        if swatch then swatch.tex:SetColorTexture(nr, ng, nb, 1) end
        if addon.RefreshThreatColors then addon:RefreshThreatColors() end
    end

    local function Changed()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        ApplyColor(nr, ng, nb)
    end

    local function Cancelled(previous)
        if previous then
            local pr = previous.r or previous[1] or r
            local pg = previous.g or previous[2] or g
            local pb = previous.b or previous[3] or b
            ApplyColor(pr, pg, pb)
        else
            ApplyColor(r, g, b)
        end
    end

    -- Newer Blizzard API.
    if ColorPickerFrame.SetupColorPickerAndShow then
        local info = {
            r = r, g = g, b = b,
            hasOpacity = false,
            swatchFunc = Changed,
            cancelFunc = Cancelled,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
        return
    end

    -- Forever/Classic compatibility path. Some builds do not expose
    -- ColorPickerFrame:SetColorRGB, so use the ColorSelect child when present.
    ColorPickerFrame.func = Changed
    ColorPickerFrame.opacityFunc = nil
    ColorPickerFrame.cancelFunc = Cancelled
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame.previousValues = {r=r, g=g, b=b}

    if ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker
       and ColorPickerFrame.Content.ColorPicker.SetColorRGB then
        ColorPickerFrame.Content.ColorPicker:SetColorRGB(r, g, b)
    elseif ColorPickerFrame.ColorPicker and ColorPickerFrame.ColorPicker.SetColorRGB then
        ColorPickerFrame.ColorPicker:SetColorRGB(r, g, b)
    elseif ColorPickerFrame.SetColorRGB then
        ColorPickerFrame:SetColorRGB(r, g, b)
    end

    ColorPickerFrame:Show()
end

for _, row in ipairs(rows) do
    local kind, text, y = unpack(row)

    local label = colorsPage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 45, y)
    label:SetText(text)
    if kind == "secure" then
        local r, g, b, a = label:GetTextColor()
        mainOptionTextColor = {r, g, b, a}
    end

    local button = CreateFrame("Button", nil, colorsPage, "BackdropTemplate")
    button:SetSize(54, 24)
    button:SetPoint("TOPLEFT", 175, y + 6)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = {left=2,right=2,top=2,bottom=2}
    })
    local tex = button:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 3, -3)
    tex:SetPoint("BOTTOMRIGHT", -3, 3)
    local r,g,b = addon:GetThreatColor(kind)
    tex:SetColorTexture(r,g,b,1)
    button.tex = tex
    button:SetScript("OnClick", function() OpenPicker(kind) end)
    swatches[kind] = button

    local defaultButton = CreateFrame("Button", nil, colorsPage, "UIPanelButtonTemplate")
    defaultButton:SetSize(58, 22)
    defaultButton:SetPoint("LEFT", button, "RIGHT", 10, 0)
    defaultButton:SetText("Default")
    defaultButton:SetNormalFontObject(GameFontNormalSmall)
    defaultButton:SetHighlightFontObject(GameFontHighlightSmall)
    defaultButton:SetScript("OnClick", function()
        local c = addon.defaults.threat[kind]
        addon:SetThreatColor(kind, c[1], c[2], c[3])
        button.tex:SetColorTexture(c[1], c[2], c[3], 1)
        if addon.RefreshThreatColors then addon:RefreshThreatColors() end
    end)
end

local dungeonRaidLabel = colorsPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dungeonRaidLabel:SetPoint("TOP", colorsPage, "TOPLEFT", 455, -362)
dungeonRaidLabel:SetText("Dungeon & Raid Threat Colors")

local dungeonRaidCustomize = CreateFrame("Button", nil, colorsPage, "UIPanelButtonTemplate")
dungeonRaidCustomize:SetSize(128, 26)
dungeonRaidCustomize:SetPoint("TOP", dungeonRaidLabel, "BOTTOM", 0, -14)
dungeonRaidCustomize:SetText("Customize")
dungeonRaidCustomize:SetNormalFontObject(GameFontNormal)
dungeonRaidCustomize:SetHighlightFontObject(GameFontHighlight)

local RIGHT_OPTIONS_CENTER = 455
local RIGHT_OPTIONS_LABEL_X = RIGHT_OPTIONS_CENTER - 126
local RIGHT_OPTIONS_SWATCH_X = RIGHT_OPTIONS_LABEL_X + 130
local function CreateExtraColorRow(text, key, getter, y)
    local label = colorsPage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", RIGHT_OPTIONS_LABEL_X, y)
    label:SetText(text)
    local button = CreateFrame("Button", nil, colorsPage, "BackdropTemplate")
    button:SetSize(54, 24)
    button:SetPoint("TOPLEFT", RIGHT_OPTIONS_SWATCH_X, y + 6)
    button:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=12, insets={left=2,right=2,top=2,bottom=2}})
    local texture = button:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", 3, -3)
    texture:SetPoint("BOTTOMRIGHT", -3, 3)
    local function Refresh()
        local r, g, b = getter()
        texture:SetColorTexture(r, g, b, 1)
    end
    local function Apply(r, g, b)
        ForeverNameplatesDB[key] = {r,g,b}
        Refresh()
        addon:RefreshThreatColors()
        if addon.RefreshATDStyle then addon:RefreshATDStyle() end
    end
    button:SetScript("OnShow", Refresh)
    button:SetScript("OnClick", function()
        local r,g,b = getter()
        local function Changed() Apply(ColorPickerFrame:GetColorRGB()) end
        local function Cancelled() Apply(r,g,b) end
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({r=r,g=g,b=b,hasOpacity=false,swatchFunc=Changed,cancelFunc=Cancelled})
        else
            ColorPickerFrame.func, ColorPickerFrame.cancelFunc = Changed, Cancelled
            ColorPickerFrame.hasOpacity = false
            local picker = ColorPickerFrame.ColorPicker or (ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker) or ColorPickerFrame
            if picker.SetColorRGB then picker:SetColorRGB(r,g,b) end
            ColorPickerFrame:Show()
        end
    end)
    local reset = CreateFrame("Button", nil, colorsPage, "UIPanelButtonTemplate")
    reset:SetSize(58, 22)
    reset:SetPoint("LEFT", button, "RIGHT", 10, 0)
    reset:SetText("Default")
    reset:SetNormalFontObject(GameFontNormalSmall)
    reset:SetHighlightFontObject(GameFontHighlightSmall)
    reset:SetScript("OnClick", function()
        local color = addon.defaults[key]
        Apply(color[1],color[2],color[3])
    end)
end
CreateExtraColorRow("Quest Color", "questColor", function() return addon:GetQuestColor() end, -161)
CreateExtraColorRow("PvP Combat", "pvpColor", function() return addon:GetPvPColor() end, -197)
local pvpClassCheck = CreateFrame("CheckButton", nil, colorsPage, "UICheckButtonTemplate")
pvpClassCheck:SetSize(24, 24)
pvpClassCheck:SetPoint("TOPLEFT", RIGHT_OPTIONS_SWATCH_X + 15, -263)
pvpClassCheck.Text:SetText("Use Class Colors (PvP)")
pvpClassCheck.Text:SetFontObject(GameFontNormalSmall)
pvpClassCheck.Text:ClearAllPoints()
pvpClassCheck.Text:SetPoint("TOPLEFT", colorsPage, "TOPLEFT", RIGHT_OPTIONS_LABEL_X, -269)
pvpClassCheck:SetScript("OnShow", function(self) self:SetChecked(addon:GetEnemyPlayerClassColors()) end)
pvpClassCheck:SetScript("OnClick", function(self)
    addon:SetEnemyPlayerClassColors(self:GetChecked())
end)
local pvpClassEvents = CreateFrame("Frame")
pvpClassEvents:RegisterEvent("CVAR_UPDATE")
pvpClassEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
pvpClassEvents:SetScript("OnEvent", function()
    if colorsPage:IsShown() then pvpClassCheck:SetChecked(addon:GetEnemyPlayerClassColors()) end
end)
local questMarkerCheck = CreateFrame("CheckButton", nil, colorsPage, "UICheckButtonTemplate")
questMarkerCheck:SetSize(24, 24)
questMarkerCheck:SetPoint("TOPLEFT", RIGHT_OPTIONS_SWATCH_X + 15, -227)
questMarkerCheck.Text:SetText("Quest Objective Icons")
questMarkerCheck.Text:SetFontObject(GameFontNormalSmall)
questMarkerCheck.Text:ClearAllPoints()
questMarkerCheck.Text:SetPoint("TOPLEFT", colorsPage, "TOPLEFT", RIGHT_OPTIONS_LABEL_X, -233)
questMarkerCheck:SetScript("OnShow", function(self) self:SetChecked(addon:GetQuestMarkersEnabled()) end)
questMarkerCheck:SetScript("OnClick", function(self)
    addon:SetQuestMarkersEnabled(self:GetChecked())
end)

-- Second view: replaces the contents of this same options window.
local dungeonRaidView = CreatePage()
dungeonRaidView:SetAllPoints(contentRoot)
dungeonRaidView:SetFrameLevel(panel:GetFrameLevel() + 10)
dungeonRaidView:Hide()

local drTitle = CreateSectionHeader(dungeonRaidView, "Dungeon & Raid Threat Colors", -110)

local drNote = dungeonRaidView:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
drNote:SetPoint("TOP", drTitle, "BOTTOM", 0, -12)
drNote:SetText("Your assigned group role determines which colors are used.")

local disableRoleColorsNote = dungeonRaidView:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
disableRoleColorsNote:SetPoint("TOPLEFT", dungeonRaidView, "TOPLEFT", 76, -505)
disableRoleColorsNote:SetWidth(480)
disableRoleColorsNote:SetJustifyH("LEFT")
disableRoleColorsNote:SetText("Use your default threat colors in dungeons and raids instead.")

local disableRoleColorsCheck = CreateFrame("CheckButton", nil, dungeonRaidView, "UICheckButtonTemplate")
disableRoleColorsCheck:SetSize(26, 26)
disableRoleColorsCheck:SetPoint("TOPLEFT", dungeonRaidView, "TOPLEFT", 46, -475)
disableRoleColorsCheck.text = disableRoleColorsCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
disableRoleColorsCheck.text:SetPoint("LEFT", disableRoleColorsCheck, "RIGHT", 4, 0)
disableRoleColorsCheck.text:SetText("Disable Role Colors")
disableRoleColorsCheck:SetScript("OnClick", function(self)
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    ForeverNameplatesDB.disableRoleColors = self:GetChecked() and true or false
    if addon.RefreshThreatColors then addon:RefreshThreatColors() end
end)
disableRoleColorsCheck:SetScript("OnShow", function(self)
    local db = ForeverNameplatesDB or addon.defaults
    self:SetChecked(db.disableRoleColors and true or false)
end)

local drBack = CreateFrame("Button", nil, dungeonRaidView, "UIPanelButtonTemplate")
drBack:SetSize(190, 26)
drBack:SetPoint("TOP", dungeonRaidView, "TOP", 0, -535)
drBack:SetText("< Back to Colors & Threat")

local drSwatches = {}
local function DRKey(profile, kind) return profile .. ":" .. kind end

local function RefreshDRSwatches()
    for key, button in pairs(drSwatches) do
        local profile, kind = key:match("([^:]+):(.+)")
        local r,g,b = addon:GetDungeonRaidThreatColor(profile,kind)
        button.tex:SetColorTexture(r,g,b,1)
    end
end

local function OpenDRPicker(profile,kind)
    local r,g,b=addon:GetDungeonRaidThreatColor(profile,kind)
    local function Apply(nr,ng,nb)
        addon:SetDungeonRaidThreatColor(profile,kind,nr,ng,nb)
        local sw=drSwatches[DRKey(profile,kind)]
        if sw then sw.tex:SetColorTexture(nr,ng,nb,1) end
    end
    local function Changed()
        local nr,ng,nb=ColorPickerFrame:GetColorRGB()
        Apply(nr,ng,nb)
    end
    local function Cancelled(previous)
        if previous then
            Apply(previous.r or previous[1] or r,
                  previous.g or previous[2] or g,
                  previous.b or previous[3] or b)
        else Apply(r,g,b) end
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r=r,g=g,b=b,hasOpacity=false,swatchFunc=Changed,cancelFunc=Cancelled
        })
    else
        ColorPickerFrame.func=Changed
        ColorPickerFrame.opacityFunc=nil
        ColorPickerFrame.cancelFunc=Cancelled
        ColorPickerFrame.hasOpacity=false
        ColorPickerFrame.previousValues={r=r,g=g,b=b}
        if ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker
           and ColorPickerFrame.Content.ColorPicker.SetColorRGB then
            ColorPickerFrame.Content.ColorPicker:SetColorRGB(r,g,b)
        elseif ColorPickerFrame.ColorPicker and ColorPickerFrame.ColorPicker.SetColorRGB then
            ColorPickerFrame.ColorPicker:SetColorRGB(r,g,b)
        elseif ColorPickerFrame.SetColorRGB then
            ColorPickerFrame:SetColorRGB(r,g,b)
        end
        ColorPickerFrame:Show()
    end
end

-- Two equal columns keep both role palettes visible without stacked title bars.
local function MakeDRSection(profile,title,x,rows)
    local heading = dungeonRaidView:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", x, -205)
    heading:SetText(title)
    heading:SetTextColor(0.94, 0.84, 0.67)

    local divider = dungeonRaidView:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.30, 0.24, 0.16, 0.7)
    divider:SetPoint("TOPLEFT", x, -233)
    divider:SetSize(240, 1)

    for index,row in ipairs(rows) do
        local kind,text=row[1],row[2]
        local ry=-259-(index-1)*56

        local label=dungeonRaidView:CreateFontString(nil,"OVERLAY","GameFontNormal")
        label:SetPoint("TOPLEFT",x,ry)
        label:SetText(text)

        local button=CreateFrame("Button",nil,dungeonRaidView,"BackdropTemplate")
        button:SetSize(54,24)
        button:SetPoint("TOPLEFT",x+116,ry+6)
        button:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8X8",
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize=12,insets={left=2,right=2,top=2,bottom=2}
        })
        local tex=button:CreateTexture(nil,"ARTWORK")
        tex:SetPoint("TOPLEFT",3,-3)
        tex:SetPoint("BOTTOMRIGHT",-3,3)
        button.tex=tex
        button:SetScript("OnClick",function() OpenDRPicker(profile,kind) end)
        drSwatches[DRKey(profile,kind)]=button

        local reset=CreateFrame("Button",nil,dungeonRaidView,"UIPanelButtonTemplate")
        reset:SetSize(58,22)
        reset:SetPoint("TOPLEFT",x+182,ry+5)
        reset:SetText("Default")
        reset:SetScript("OnClick",function()
            local c=addon.defaults.dungeonRaidThreat[profile][kind]
            addon:SetDungeonRaidThreatColor(profile,kind,c[1],c[2],c[3])
            button.tex:SetColorTexture(c[1],c[2],c[3],1)
        end)
    end
end

MakeDRSection("tank","Tank",48,{
    {"secure","Have Aggro"},
    {"warning","Warning"},
    {"lost","Lost Aggro"},
})
MakeDRSection("nonTank","DPS / Healer",332,{
    {"secure","Have Aggro"},
    {"warning","Warning"},
    {"lost","No Aggro"},
})

-- Preview only: deliberately excluded from saved palettes and color handlers.
local offTankLabel = dungeonRaidView:CreateFontString(nil, "OVERLAY", "GameFontDisable")
offTankLabel:SetPoint("TOPLEFT", 48, -427)
offTankLabel:SetText("Off-Tank Aggro")
local offTankSwatch = CreateFrame("Frame", nil, dungeonRaidView, "BackdropTemplate")
offTankSwatch:SetSize(54, 24)
offTankSwatch:SetPoint("TOPLEFT", 164, -421)
offTankSwatch:SetBackdrop({
    bgFile="Interface\\Buttons\\WHITE8X8",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize=12, insets={left=2,right=2,top=2,bottom=2},
})
offTankSwatch:SetBackdropColor(0.54, 0.81, 0.94, 0.45)
offTankSwatch:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.5)
local offTankDefault = CreateFrame("Button", nil, dungeonRaidView, "UIPanelButtonTemplate")
offTankDefault:SetSize(58, 22)
offTankDefault:SetPoint("TOPLEFT", 230, -422)
offTankDefault:SetText("Default")
offTankDefault:Disable()
local offTankNote = dungeonRaidView:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
offTankNote:SetPoint("TOPLEFT", 48, -448)
offTankNote:SetText("(Still testing)")



dungeonRaidCustomize:SetScript("OnClick", function() SelectPage("roles") end)
drBack:SetScript("OnClick", function() SelectPage("colors") end)
-- Target of Target / Nameplate Appearance ----------------------------------
local appearanceHeader = CreateSectionHeader(nameplatesPage, "Nameplate Options", -110)

local compatibilityCheck = CreateFrame("CheckButton", nil, nameplatesPage, "UICheckButtonTemplate")
compatibilityCheck:SetSize(26, 26)
compatibilityCheck:SetPoint("TOPLEFT", 280, -515)
compatibilityCheck.Text:SetText("Compatibility mode (Plater/Platynator/etc)")
compatibilityCheck.Text:ClearAllPoints()
compatibilityCheck.Text:SetPoint("LEFT", compatibilityCheck, "RIGHT", 8, 0)
compatibilityCheck.Text:SetWidth(245)
compatibilityCheck.Text:SetJustifyH("LEFT")
local compatibilityNote = nameplatesPage:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
compatibilityNote:SetPoint("TOPLEFT", 314, -542)
compatibilityNote:SetWidth(245)
compatibilityNote:SetJustifyH("LEFT")
compatibilityNote:SetText("Disables BTP styling so other nameplate addons can control their appearance.")
compatibilityCheck:SetScript("OnShow", function(self) self:SetChecked(addon:GetCompatibilityMode()) end)
compatibilityCheck:SetScript("OnClick", function(self)
    addon:SetCompatibilityMode(self:GetChecked())
    if addon.RefreshStyleOptions then addon:RefreshStyleOptions() end
end)

local appearanceSizeLabel=nameplatesPage:CreateFontString(nil,"OVERLAY","GameFontNormal")
appearanceSizeLabel:SetPoint("TOPLEFT",45,-260)
appearanceSizeLabel:SetText("Nameplate Size")

local appearanceSizeValue=nameplatesPage:CreateFontString(nil,"OVERLAY","GameFontHighlight")
appearanceSizeValue:SetPoint("LEFT",appearanceSizeLabel,"RIGHT",10,0)

local appearanceSizeSlider=CreateOptionsSlider("BTPNameplateSizeSlider", nameplatesPage)
appearanceSizeSlider:SetPoint("TOPLEFT",45,-284)
appearanceSizeSlider:SetWidth(230)
appearanceSizeSlider:SetMinMaxValues(1,5)
appearanceSizeSlider:SetValueStep(1)
appearanceSizeSlider:SetObeyStepOnDrag(true)
_G[appearanceSizeSlider:GetName().."Low"]:SetText("1")
_G[appearanceSizeSlider:GetName().."High"]:SetText("5")
_G[appearanceSizeSlider:GetName().."Text"]:SetText("")
appearanceSizeSlider:SetScript("OnValueChanged",function(_,value)
    value=math.floor(value+.5)
    appearanceSizeValue:SetText(value)
    addon:SetNameplateSize(value)
end)

local appearanceSizeDefault=CreateFrame("Button",nil,nameplatesPage,"UIPanelButtonTemplate")
appearanceSizeDefault:SetSize(58,22)
appearanceSizeDefault:SetPoint("LEFT",appearanceSizeSlider,"RIGHT",12,0)
appearanceSizeDefault:SetText("Default")
appearanceSizeDefault:SetScript("OnClick",function()
    local atdSize = addon:GetATDStyleDefaults()
    appearanceSizeSlider:SetValue(addon:IsATDStyle() and atdSize or addon.defaults.appearance.size)
end)

local nameSizeLabel=nameplatesPage:CreateFontString(nil,"OVERLAY","GameFontNormal")
nameSizeLabel:SetPoint("TOPLEFT",45,-315)
nameSizeLabel:SetText("Enemy Name Size")

local nameSizeValue=nameplatesPage:CreateFontString(nil,"OVERLAY","GameFontHighlight")
nameSizeValue:SetPoint("LEFT",nameSizeLabel,"RIGHT",10,0)

local nameSizeSlider=CreateOptionsSlider("BTPEnemyNameSizeSlider", nameplatesPage)
nameSizeSlider:SetPoint("TOPLEFT",45,-339)
nameSizeSlider:SetWidth(230)
nameSizeSlider:SetMinMaxValues(5,18)
nameSizeSlider:SetValueStep(1)
nameSizeSlider:SetObeyStepOnDrag(true)
_G[nameSizeSlider:GetName().."Low"]:SetText("5")
_G[nameSizeSlider:GetName().."High"]:SetText("18")
_G[nameSizeSlider:GetName().."Text"]:SetText("")
nameSizeSlider:SetScript("OnValueChanged",function(_,value)
    value=math.floor(value+.5)
    nameSizeValue:SetText(value.." px")
    addon:SetMobNameFontSize(value)
end)

local nameSizeDefault=CreateFrame("Button",nil,nameplatesPage,"UIPanelButtonTemplate")
nameSizeDefault:SetSize(58,22)
nameSizeDefault:SetPoint("LEFT",nameSizeSlider,"RIGHT",12,0)
nameSizeDefault:SetText("Default")
nameSizeDefault:SetScript("OnClick",function()
    local _, atdName = addon:GetATDStyleDefaults()
    nameSizeSlider:SetValue(addon:IsATDStyle() and atdName or addon.defaults.mobName.fontSize)
end)

local percentSizeLabel=nameplatesPage:CreateFontString(nil,"OVERLAY","GameFontNormal")
percentSizeLabel:SetPoint("TOPLEFT",45,-370)
percentSizeLabel:SetText("Health Percentage Size")
local percentSizeValue=nameplatesPage:CreateFontString(nil,"OVERLAY","GameFontHighlight")
percentSizeValue:SetPoint("LEFT",percentSizeLabel,"RIGHT",10,0)
local percentSizeSlider=CreateOptionsSlider("BTPHealthPercentSizeSlider", nameplatesPage)
percentSizeSlider:SetPoint("TOPLEFT",45,-394)
percentSizeSlider:SetWidth(230)
percentSizeSlider:SetMinMaxValues(5,18)
percentSizeSlider:SetValueStep(1)
percentSizeSlider:SetObeyStepOnDrag(true)
_G[percentSizeSlider:GetName().."Low"]:SetText("5")
_G[percentSizeSlider:GetName().."High"]:SetText("18")
_G[percentSizeSlider:GetName().."Text"]:SetText("")
percentSizeSlider:SetScript("OnValueChanged",function(_,value)
    value=math.floor(value+.5)
    percentSizeValue:SetText(value.." px")
    addon:SetHealthPercentFontSize(value)
end)

local percentSizeDefault=CreateFrame("Button",nil,nameplatesPage,"UIPanelButtonTemplate")
percentSizeDefault:SetSize(58,22)
percentSizeDefault:SetPoint("LEFT",percentSizeSlider,"RIGHT",12,0)
percentSizeDefault:SetText("Default")
percentSizeDefault:SetScript("OnClick",function()
    local _, _, atdPercent = addon:GetATDStyleDefaults()
    percentSizeSlider:SetValue(addon:IsATDStyle() and atdPercent or addon.defaults.healthText.percentSize)
end)

local valueSizeLabel=nameplatesPage:CreateFontString(nil,"OVERLAY","GameFontNormal")
valueSizeLabel:SetPoint("TOPLEFT",45,-430)
valueSizeLabel:SetText("Health Value Size")
local valueSizeValue=nameplatesPage:CreateFontString(nil,"OVERLAY","GameFontHighlight")
valueSizeValue:SetPoint("LEFT",valueSizeLabel,"RIGHT",10,0)
local valueSizeSlider=CreateOptionsSlider("BTPHealthValueSizeSlider", nameplatesPage)
valueSizeSlider:SetPoint("TOPLEFT",45,-454)
valueSizeSlider:SetWidth(230)
valueSizeSlider:SetMinMaxValues(5,18)
valueSizeSlider:SetValueStep(1)
valueSizeSlider:SetObeyStepOnDrag(true)
_G[valueSizeSlider:GetName().."Low"]:SetText("5")
_G[valueSizeSlider:GetName().."High"]:SetText("18")
_G[valueSizeSlider:GetName().."Text"]:SetText("")
valueSizeSlider:SetScript("OnValueChanged",function(_,value)
    value=math.floor(value+.5)
    valueSizeValue:SetText(value.." px")
    addon:SetHealthValueFontSize(value)
end)

local valueSizeDefault=CreateFrame("Button",nil,nameplatesPage,"UIPanelButtonTemplate")
valueSizeDefault:SetSize(58,22)
valueSizeDefault:SetPoint("LEFT",valueSizeSlider,"RIGHT",12,0)
valueSizeDefault:SetText("Default")
valueSizeDefault:SetScript("OnClick",function()
    local _, _, _, atdValue = addon:GetATDStyleDefaults()
    valueSizeSlider:SetValue(addon:IsATDStyle() and atdValue or addon.defaults.healthText.valueSize)
end)

local styleLabel = nameplatesPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
styleLabel:SetPoint("TOPLEFT", 80, -155)
styleLabel:SetText("Style:")

local stylePicker = CreateFrame("Frame", "BTPNameplateStyleDropdown", nameplatesPage, "UIDropDownMenuTemplate")
stylePicker:SetPoint("TOPLEFT", 65, -175)
UIDropDownMenu_SetWidth(stylePicker, 165)
UIDropDownMenu_JustifyText(stylePicker, "LEFT")

local function SelectStyle(_, id)
    addon:SetNameplateStyle(id)
    CloseDropDownMenus()
end

UIDropDownMenu_Initialize(stylePicker, function(_, level)
    for _, style in ipairs(addon:GetNameplateStyles()) do
        if style.key == "Modern" or style.key == "Thin" or style.key == "ATD" or style.key == "DevDraft" or style.key=="JUNDIES" or style.id == addon:GetNameplateStyleFamily() then
        local info = UIDropDownMenu_CreateInfo()
        info.text = style.name
        info.value = style.id
        info.checked = style.id == addon:GetNameplateStyleFamily()
        info.disabled = InCombatLockdown()
        info.func = SelectStyle
        info.arg1 = style.id
        UIDropDownMenu_AddButton(info, level)
        end
    end
end)

local castStyleLabel = nameplatesPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
castStyleLabel:SetPoint("TOPLEFT", 355, -155)
castStyleLabel:SetText("Blizzard Castbar Style:")
local castStylePicker = CreateFrame("Frame", "BTPCastbarStyleDropdown", nameplatesPage, "UIDropDownMenuTemplate")
castStylePicker:SetPoint("TOPLEFT", 340, -175)
UIDropDownMenu_SetWidth(castStylePicker, 165)
UIDropDownMenu_JustifyText(castStylePicker, "LEFT")
UIDropDownMenu_Initialize(castStylePicker, function(_, level)
    for _, choice in ipairs({{name="Skinny", thick=false}, {name="Thick", thick=true}}) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = choice.name
        info.checked = addon:GetCastbarThick() == choice.thick
        info.disabled = InCombatLockdown()
        info.arg1 = choice.thick
        info.func = function(_, thick)
            addon:SetCastbarThick(thick)
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

local styleNote = nameplatesPage:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
styleNote:SetPoint("TOPLEFT", nameplatesPage, "TOPLEFT", 80, -217)
styleNote:SetWidth(475)
styleNote:SetJustifyH("LEFT")
styleNote:SetText("Each style remembers its own size and text settings.")

local auraPreviewLabel = nameplatesPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
auraPreviewLabel:SetPoint("TOPLEFT", 390, -260)
auraPreviewLabel:SetText("ATD Aura Layout")

local auraPreviewButton = CreateFrame("Button", nil, nameplatesPage, "UIPanelButtonTemplate")
auraPreviewButton:SetSize(130, 24)
auraPreviewButton:SetPoint("TOPLEFT", 389, -282)
auraPreviewButton:SetText("Preview on Target")
auraPreviewButton:SetScript("OnClick", function()
    addon:SetATDAuraPreview(not addon:IsATDAuraPreviewActive())
end)

function addon:RefreshATDAuraPreviewControl()
    local active = self:IsATDAuraPreviewActive()
    auraPreviewButton:SetText(active and "Stop Preview" or "Preview on Target")
    auraPreviewButton:SetEnabled(self:IsATDStyle() and not InCombatLockdown())
end

local RefreshHealthSliderAvailability
function addon:RefreshStyleOptions()
    if not nameplatesPage:IsShown() then return end
    local id = self:GetNameplateStyleFamily()
    local selected
    for _, style in ipairs(self:GetNameplateStyles()) do if style.id == id then selected = style end end
    UIDropDownMenu_SetText(stylePicker, selected and selected.name or ("Style "..id))
    local hasCastbarChoices = id == Enum.NamePlateStyle.Modern or id == Enum.NamePlateStyle.Thin
    UIDropDownMenu_SetText(castStylePicker, id == "ATD" and "ATD" or
        (hasCastbarChoices and (self:GetCastbarThick() and "Thick" or "Skinny") or "Native"))
    local compatibility = self:GetCompatibilityMode()
    if InCombatLockdown() or compatibility then
        UIDropDownMenu_DisableDropDown(stylePicker)
        UIDropDownMenu_DisableDropDown(castStylePicker)
    else
        UIDropDownMenu_EnableDropDown(stylePicker)
        if hasCastbarChoices then UIDropDownMenu_EnableDropDown(castStylePicker)
        else UIDropDownMenu_DisableDropDown(castStylePicker) end
    end
    for _, control in ipairs({appearanceSizeSlider, appearanceSizeDefault, nameSizeSlider, nameSizeDefault,
        percentSizeSlider, percentSizeDefault, valueSizeSlider, valueSizeDefault}) do
        control:SetEnabled(not compatibility)
    end
    self:RefreshATDAuraPreviewControl()
    appearanceSizeSlider:SetValue(self:GetNameplateSize())
    nameSizeSlider:SetValue(self:GetMobNameFontSize())
    percentSizeSlider:SetValue(self:GetHealthPercentFontSize())
    valueSizeSlider:SetValue(self:GetHealthValueFontSize())
    if RefreshHealthSliderAvailability then RefreshHealthSliderAvailability() end
end
nameplatesPage:SetScript("OnShow", function() addon:RefreshStyleOptions() end)

-- Keep non-target nameplates bright.
-- Blizzard normally reapplies its deselected treatment when target state changes.
-- When enabled, neutralize that treatment after Blizzard has updated the plates.
ForeverNameplatesDB = ForeverNameplatesDB or {}
local brightness = {overlays=setmetatable({}, {__mode="k"})}
function addon:GetNonTargetsBright()
    if addon:GetCompatibilityMode() and addon.GetCompatibilityFeatureEnabled then
        return addon:GetCompatibilityFeatureEnabled("brightness")
    end
    local saved = ForeverNameplatesDB and ForeverNameplatesDB.keepNonTargetsBright
    if saved ~= nil then return saved == true end
    return true
end

local function ApplyNonTargetBrightMode()
    if addon:GetCompatibilityMode() and not addon:GetNonTargetsBright() then
        -- Relinquish once; repeated events must not overwrite another addon.
        if brightness.owned then
            addon:SetNameplateCVar("nameplateNotSelectedAlpha", brightness.baseline or -1)
            brightness.owned = nil
            for overlay, shown in pairs(brightness.overlays) do overlay:SetShown(shown); brightness.overlays[overlay]=nil end
        end
        return
    end
    if not brightness.owned then
        brightness.baseline = tonumber(GetCVar("nameplateNotSelectedAlpha")) or -1
        brightness.owned = true
    end
    local active = addon:GetNonTargetsBright()
    addon:SetNameplateCVar("nameplateNotSelectedAlpha", active and 1 or -1)
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local bar = plate and plate.UnitFrame and plate.UnitFrame.healthBar
        local overlay = bar and bar.deselectedOverlay
        if overlay then
            if brightness.overlays[overlay] == nil then
                local shown = overlay:IsShown()
                if not (issecretvalue and issecretvalue(shown)) then brightness.overlays[overlay] = shown == true end
            end
            if active or plate == addon:GetPlate("target") then overlay:Hide() else overlay:Show() end
        end
    end
end

addon.ApplyNonTargetBrightMode = ApplyNonTargetBrightMode
function addon:SetNonTargetsBright(enabled)
    if addon.SetCompatibilityFeatureEnabled and addon:SetCompatibilityFeatureEnabled("brightness",enabled) then return end
    ForeverNameplatesDB.keepNonTargetsBright = enabled == true
    ApplyNonTargetBrightMode()
end

local toolsHeading = colorsPage:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
toolsHeading:SetPoint("TOPLEFT", 45, -298)
toolsHeading:SetText("Tanking Tools")
toolsHeading:SetTextColor(unpack(mainSectionTitleColor))
local toolsDivider = colorsPage:CreateTexture(nil, "ARTWORK")
toolsDivider:SetPoint("TOPLEFT", 45, -301)
toolsDivider:SetSize(530, 1)
toolsDivider:SetColorTexture(0.45, 0.36, 0.20, 0.65)
local function AlignSectionDivider(divider, y)
    if PixelUtil then
        divider:ClearAllPoints()
        PixelUtil.SetPoint(divider, "TOPLEFT", colorsPage, "TOPLEFT", 45, y)
        PixelUtil.SetHeight(divider, 1)
    end
end
AlignSectionDivider(toolsDivider, -321)
local brightCheck = CreateFrame("CheckButton", nil, colorsPage, "UICheckButtonTemplate")
brightCheck:SetSize(26, 26)
brightCheck:SetPoint("TOPLEFT", 34, -332)
brightCheck.Text:SetText("Keep Non-Target Nameplates Bright")
brightCheck.Text:ClearAllPoints()
brightCheck.Text:SetPoint("LEFT", brightCheck, "RIGHT", 8, 0)

local function SetToggleTooltip(toggle, title, description)
    toggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(description, 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    toggle:HookScript("OnHide", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
end
SetToggleTooltip(brightCheck, "Keep Non-Target Nameplates Bright",
    "Keeps other enemies bright so their threat colors stay easy to see.")

brightCheck:SetScript("OnShow", function(self)
    self:SetChecked(addon:GetNonTargetsBright())
end)
brightCheck:SetScript("OnClick", function(self)
    addon:SetNonTargetsBright(self:GetChecked())
end)

C_Timer.After(0, ApplyNonTargetBrightMode)

local nonTargetPlateWatcher = CreateFrame("Frame")
nonTargetPlateWatcher:RegisterEvent("NAME_PLATE_UNIT_ADDED")
nonTargetPlateWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
nonTargetPlateWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
nonTargetPlateWatcher:RegisterEvent("GROUP_ROSTER_UPDATE")
nonTargetPlateWatcher:RegisterEvent("PLAYER_ROLES_ASSIGNED")
nonTargetPlateWatcher:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_TARGET_CHANGED" then
        C_Timer.After(0, ApplyNonTargetBrightMode)
    else
        ApplyNonTargetBrightMode()
    end
end)

local flashCheck = CreateFrame("CheckButton", nil, colorsPage, "UICheckButtonTemplate")
flashCheck:SetSize(26, 26)
flashCheck:SetPoint("TOPLEFT", 34, -362)
flashCheck.Text:SetText("Flash Border When Losing Aggro")
flashCheck.Text:ClearAllPoints()
flashCheck.Text:SetPoint("LEFT", flashCheck, "RIGHT", 8, 0)
flashCheck:SetScript("OnShow", function(self) self:SetChecked(addon:GetThreatFlashEnabled()) end)
flashCheck:SetScript("OnClick", function(self) addon:SetThreatFlashEnabled(self:GetChecked()) end)
SetToggleTooltip(flashCheck, "Flash Border When Losing Aggro",
    "Flashes on non-target enemies when secure aggro becomes warning or lost.")


local diffHeading = colorsPage:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
diffHeading:SetPoint("TOPLEFT", 45, -423)
diffHeading:SetText("Threat Display")
diffHeading:SetTextColor(unpack(mainSectionTitleColor))
local diffDivider = colorsPage:CreateTexture(nil, "ARTWORK")
diffDivider:SetPoint("TOPLEFT", 45, -446)
diffDivider:SetSize(530, 1)
diffDivider:SetColorTexture(0.45, 0.36, 0.20, 0.65)
AlignSectionDivider(diffDivider, -446)
local diffCheck = CreateFrame("CheckButton", nil, colorsPage, "UICheckButtonTemplate")
diffCheck:SetSize(26, 26)
diffCheck:SetPoint("TOPLEFT", 34, -480)
diffCheck.Text:SetText("Turn Off Threat Display")
diffCheck.Text:ClearAllPoints()
diffCheck.Text:SetPoint("LEFT", diffCheck, "RIGHT", 8, 0)
diffCheck:SetScript("OnShow", function(self) self:SetChecked(not addon:GetThreatDifferentialEnabled()) end)
diffCheck:SetScript("OnClick", function(self) addon:SetThreatDifferentialEnabled(not self:GetChecked()) end)
local tankOnlyCheck = CreateFrame("CheckButton", nil, colorsPage, "UICheckButtonTemplate")
tankOnlyCheck:SetSize(26, 26)
tankOnlyCheck:SetPoint("TOPLEFT", 34, -507)
tankOnlyCheck.Text:SetText("Only When Assigned Tank")
tankOnlyCheck.Text:ClearAllPoints()
tankOnlyCheck.Text:SetPoint("LEFT", tankOnlyCheck, "RIGHT", 8, 0)
local snapshotButton, snapshotSlider, snapshotDefault
local function RefreshTankOnlyControl()
    local enabled = addon:GetThreatDifferentialEnabled()
    tankOnlyCheck:SetChecked(addon:GetThreatDifferentialTankOnly())
    tankOnlyCheck:SetEnabled(enabled)
    tankOnlyCheck.Text:SetAlpha(enabled and 1 or 0.5)
    local timerEnabled = enabled and addon:GetThreatDisplayMode() == "differential"
    if snapshotButton then snapshotButton:SetEnabled(timerEnabled) end
    if snapshotSlider then snapshotSlider:SetEnabled(timerEnabled) end
    if snapshotDefault then snapshotDefault:SetEnabled(timerEnabled) end
end
tankOnlyCheck:SetScript("OnShow", RefreshTankOnlyControl)
tankOnlyCheck:SetScript("OnClick", function(self)
    addon:SetThreatDifferentialTankOnly(self:GetChecked())
end)
diffCheck:HookScript("OnClick", RefreshTankOnlyControl)
snapshotButton = CreateFrame("Button", nil, colorsPage, "UIPanelButtonTemplate")
snapshotButton:SetSize(112, 22)
snapshotButton:SetPoint("TOPLEFT", 45, -539)
snapshotButton:SetText("Snapshot")

local diffSizePreview = colorsPage:CreateFontString(nil, "OVERLAY")
diffSizePreview:SetFont(STANDARD_TEXT_FONT, addon:GetThreatDifferentialSize(), "OUTLINE")
diffSizePreview:SetTextColor(0, 1, 0)
diffSizePreview:SetText(addon:GetThreatDisplayMode() == "percentage" and "125%" or "+125")
local diffSizeLabel = colorsPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
diffSizeLabel:SetPoint("TOP", colorsPage, "TOPLEFT", 357, -467)
diffSizeLabel:SetText("Display Size:")
diffSizePreview:SetPoint("CENTER", colorsPage, "TOPLEFT", 515, -500)
local diffSizeSlider = CreateOptionsSlider("BTPDifferentialSizeSlider", colorsPage)
diffSizeSlider:SetPoint("TOPLEFT", 267, -492)
diffSizeSlider:SetWidth(180)
diffSizeSlider:SetMinMaxValues(10, 32)
diffSizeSlider:SetValueStep(1)
diffSizeSlider:SetObeyStepOnDrag(true)
_G[diffSizeSlider:GetName().."Low"]:SetText("10")
_G[diffSizeSlider:GetName().."High"]:SetText("32")
_G[diffSizeSlider:GetName().."Text"]:SetText("")
local function RefreshDifferentialSizePreview()
    local size = addon:GetThreatDifferentialSize()
    diffSizePreview:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
    diffSizePreview:SetText(addon:GetThreatDisplayMode() == "percentage" and "125%" or "+125")
end
diffSizeSlider:SetScript("OnValueChanged", function(_, value)
    addon:SetThreatDifferentialSize(value)
    RefreshDifferentialSizePreview()
end)
diffSizeSlider:SetScript("OnShow", function(self)
    self:SetValue(addon:GetThreatDifferentialSize())
    RefreshDifferentialSizePreview()
end)
local diffSizeDefault = CreateFrame("Button", nil, colorsPage, "UIPanelButtonTemplate")
diffSizeDefault:SetSize(58, 22)
diffSizeDefault:SetPoint("TOP", diffSizeSlider, "BOTTOM", 0, -17)
diffSizeDefault:SetText("Default")
diffSizeDefault:SetScript("OnClick", function() diffSizeSlider:SetValue(addon.defaults.threatDifferentialSize) end)

-- Size is presented with position and a live plate preview in the dedicated
-- overlay window below, rather than crowding the main threat section.
diffSizeLabel:Hide()
diffSizePreview:Hide()
diffSizeSlider:Hide()
diffSizeDefault:Hide()

local snapshotWindow = CreateFrame("Frame", "BTPSnapshotTimerOptions", colorsPage, "BackdropTemplate")
snapshotWindow:Hide()
snapshotWindow:SetSize(430, 300)
snapshotWindow:SetPoint("CENTER", panel, "CENTER")
snapshotWindow:SetFrameLevel(panel:GetFrameLevel() + 20)
snapshotWindow:EnableMouse(true)
snapshotWindow:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=16, insets={left=4,right=4,top=4,bottom=4}})
snapshotWindow:SetBackdropColor(0.04, 0.035, 0.025, 1)
snapshotWindow:SetBackdropBorderColor(0.65, 0.5, 0.2, 1)
local snapshotClose = CreateFrame("Button", nil, snapshotWindow, "UIPanelCloseButton")
snapshotClose:SetPoint("TOPRIGHT", -2, -2)
snapshotClose:SetScript("OnClick", function() snapshotWindow:Hide() end)
local snapshotTitle = snapshotWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
snapshotTitle:SetPoint("TOP", 0, -18)
snapshotTitle:SetText("Snapshot")
local snapshotExplanation = snapshotWindow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
snapshotExplanation:SetPoint("TOPLEFT", 30, -166)
snapshotExplanation:SetWidth(370)
snapshotExplanation:SetJustifyH("LEFT")
snapshotExplanation:SetText("Snapshots keep the last known threat difference on enemies you switch away from, marked with *, then blink and fade. They do not update live. Retarget an enemy to refresh its number.")
local snapshotValue = snapshotWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
snapshotValue:SetPoint("TOP", 0, -58)
snapshotSlider = CreateOptionsSlider("BTPThreatSnapshotSlider", snapshotWindow)
snapshotSlider:SetPoint("TOP", 0, -86)
snapshotSlider:SetWidth(350)
snapshotSlider:SetMinMaxValues(3, 10)
snapshotSlider:SetValueStep(1)
snapshotSlider:SetObeyStepOnDrag(true)
_G[snapshotSlider:GetName().."Low"]:SetText("3 sec")
_G[snapshotSlider:GetName().."High"]:SetText("10 sec")
_G[snapshotSlider:GetName().."Text"]:SetText("")
local snapshotNote = snapshotWindow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
snapshotNote:SetPoint("TOPLEFT", 30, -122)
snapshotNote:SetWidth(370)
snapshotNote:SetJustifyH("LEFT")
snapshotSlider:SetScript("OnValueChanged", function(_, value)
    addon:SetThreatSnapshotSeconds(value)
    local seconds = addon:GetThreatSnapshotSeconds()
    snapshotValue:SetText("Snapshot Timer: "..seconds.." seconds total")
    snapshotNote:SetText("Stays bright for 2 seconds, then blinks and fades for "..(seconds-2).." seconds.")
end)
snapshotDefault = CreateFrame("Button", nil, snapshotWindow, "UIPanelButtonTemplate")
snapshotDefault:SetSize(90, 22)
snapshotDefault:SetPoint("BOTTOM", 0, 15)
snapshotDefault:SetText("Default")
snapshotDefault:SetScript("OnClick", function() snapshotSlider:SetValue(addon.defaults.threatSnapshotSeconds) end)
snapshotButton:SetScript("OnClick", function()
    snapshotSlider:SetValue(addon:GetThreatSnapshotSeconds())
    RefreshTankOnlyControl()
    snapshotWindow:SetShown(not snapshotWindow:IsShown())
end)
colorsPage:HookScript("OnHide", function() snapshotWindow:Hide() end)

local positionButton = CreateFrame("Button", nil, colorsPage, "UIPanelButtonTemplate")
positionButton:SetSize(145, 26)
positionButton:SetPoint("TOP", colorsPage, "TOPLEFT", 455, -502)
positionButton:SetText("Position & Size")

local positionSummary = colorsPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
positionSummary:SetPoint("TOP", colorsPage, "TOPLEFT", 455, -474)
positionSummary:SetText("Preview & Modify Threat Display")
positionSummary:SetTextColor(GameFontNormal:GetTextColor())

local positionWindow = CreateFrame("Frame", "BTPOverlayPositionOptions", panel, "DefaultPanelTemplate")
positionWindow:Hide()
positionWindow:SetSize(520, 345)
positionWindow:SetPoint("CENTER", panel, "CENTER")
positionWindow:SetFrameLevel(panel:GetFrameLevel() + 20)
positionWindow:EnableMouse(true)
positionWindow.TitleContainer.TitleText:SetText("Position & Size")
local positionClose = CreateFrame("Button", nil, positionWindow, "UIPanelCloseButton")
positionClose:SetPoint("TOPRIGHT", -5, 0)
positionClose:SetFrameStrata("TOOLTIP")
positionClose:SetFrameLevel(positionWindow:GetFrameLevel() + 100)
positionClose:SetScript("OnClick", function() positionWindow:Hide() end)
local positionInset = CreateFrame("Frame", nil, positionWindow, "InsetFrameTemplate")
positionInset:SetPoint("TOPLEFT", 14, -35)
positionInset:SetPoint("BOTTOMRIGHT", -14, 14)
positionInset:SetFrameLevel(positionWindow:GetFrameLevel())
local positionNote = positionWindow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
positionNote:SetPoint("TOP", 0, -44)
positionNote:SetText("Adjust threat size and position using the sample nameplate.")

local positionPreview = CreateFrame("Frame", nil, positionWindow, "BackdropTemplate")
positionPreview:SetPoint("TOPLEFT", 25, -67)
positionPreview:SetPoint("TOPRIGHT", -25, -67)
positionPreview:SetHeight(105)
positionPreview:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=12, insets={left=3,right=3,top=3,bottom=3}})
positionPreview:SetBackdropColor(0, 0, 0, 1)
positionPreview:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)

local positionPreviewContent = CreateFrame("Frame", nil, positionPreview)
positionPreviewContent:SetSize(1, 1)
positionPreviewContent:SetPoint("CENTER", 28, 8)
local positionPreviewBar = CreateFrame("Frame", nil, positionPreviewContent, "BackdropTemplate")
positionPreviewBar:SetSize(250, 30)
positionPreviewBar:SetPoint("CENTER")
positionPreviewBar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=10, insets={left=3,right=3,top=3,bottom=3}})
positionPreviewBar:SetBackdropColor(0.025, 0.02, 0.015, 1)
positionPreviewBar:SetBackdropBorderColor(0.92, 0.92, 0.92, 1)
local positionPreviewFill = positionPreviewBar:CreateTexture(nil, "ARTWORK")
positionPreviewFill:SetPoint("TOPLEFT", 4, -4)
positionPreviewFill:SetPoint("BOTTOM", positionPreviewBar, "BOTTOM", 0, 4)
positionPreviewFill:SetWidth(155)
positionPreviewFill:SetColorTexture(0.18, 0.85, 0.08, 1)
local positionPreviewName = positionPreviewBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
positionPreviewName:SetFont("Fonts\\2002.TTF", 14, "OUTLINE")
positionPreviewName:SetShadowColor(0, 0, 0, 1)
positionPreviewName:SetShadowOffset(1, -1)
positionPreviewName:SetPoint("LEFT", 9, 0)
positionPreviewName:SetText("Young Wolf")
local positionPreviewHealth = positionPreviewBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
positionPreviewHealth:SetPoint("RIGHT", -9, 0)
positionPreviewHealth:SetText("63%")
local positionPreviewThreat = positionPreviewContent:CreateFontString(nil, "OVERLAY")
positionPreviewThreat:SetJustifyH("RIGHT")
positionPreviewThreat:SetTextColor(0, 1, 0)
positionPreviewThreat:SetFont(STANDARD_TEXT_FONT, addon:GetThreatDifferentialSize(), "OUTLINE")
positionPreviewThreat:SetText("+420")
local RefreshPositionPreview

local positionSliders = {}
local syncingPositions = false
local function CreatePositionSlider(name, labelText, kind, axis, x, y)
    local label = positionWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(labelText)
    local valueText = positionWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("LEFT", label, "RIGHT", 8, 0)
    local slider = CreateOptionsSlider(name, positionWindow)
    slider:SetPoint("TOPLEFT", x, y - 24)
    slider:SetWidth(170)
    slider:SetMinMaxValues(-100, 100)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    _G[name.."Low"]:SetText("-100")
    _G[name.."High"]:SetText("100")
    _G[name.."Text"]:SetText("")
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        valueText:SetText(value.." px")
        if syncingPositions then return end
        local currentX, currentY = addon:GetOverlayPosition(kind)
        addon:SetOverlayPosition(kind, axis == "x" and value or currentX, axis == "y" and value or currentY)
        if RefreshPositionPreview then RefreshPositionPreview() end
    end)
    positionSliders[#positionSliders + 1] = {slider=slider, value=valueText, kind=kind, axis=axis}
end
CreatePositionSlider("BTPThreatPositionX", "Threat X", "threat", "x", 35, -255)
CreatePositionSlider("BTPThreatPositionY", "Threat Y", "threat", "y", 285, -255)

diffSizeLabel:SetParent(positionWindow)
diffSizeLabel:ClearAllPoints()
diffSizeLabel:SetPoint("TOPLEFT", 118, -188)
diffSizeLabel:SetText("Threat Size")
diffSizeLabel:Show()
diffSizeSlider:SetParent(positionWindow)
diffSizeSlider:ClearAllPoints()
diffSizeSlider:SetPoint("TOPLEFT", 118, -212)
diffSizeSlider:SetWidth(235)
diffSizeSlider:Show()
diffSizeDefault:SetParent(positionWindow)
diffSizeDefault:ClearAllPoints()
diffSizeDefault:SetPoint("LEFT", diffSizeSlider, "RIGHT", 13, 0)
diffSizeDefault:Show()

RefreshPositionPreview = function()
    local geometry = addon:GetNameplatePreviewGeometry()
    positionPreviewContent:SetScale(addon:GetNameplatePreviewRenderScale(positionPreview:GetEffectiveScale()))
    positionPreviewBar:SetSize(geometry.width, geometry.height)
    positionPreviewFill:SetWidth(math.max(1, geometry.width - 8) * 0.63)
    positionPreviewName:SetFont("Fonts\\2002.TTF", addon:GetMobNameFontSize(), "OUTLINE")
    positionPreviewHealth:SetFont(STANDARD_TEXT_FONT, addon:GetHealthPercentFontSize(), "OUTLINE")
    positionPreviewName:SetPoint("RIGHT", positionPreviewHealth, "LEFT", -2, 0)
    positionPreviewName:SetWordWrap(false)
    positionPreviewName:SetJustifyH("LEFT")
    local threatX, threatY = addon:GetOverlayPosition("threat")
    positionPreviewThreat:ClearAllPoints()
    positionPreviewThreat:SetPoint("RIGHT", positionPreviewBar, "LEFT", threatX, threatY)
    positionPreviewThreat:SetFont(STANDARD_TEXT_FONT, addon:GetThreatDifferentialSize(), "OUTLINE")
    positionPreviewThreat:SetText(addon:GetThreatDisplayMode() == "percentage" and "125%" or "+420")
end
diffSizeSlider:SetScript("OnValueChanged", function(_, value)
    addon:SetThreatDifferentialSize(value)
    RefreshDifferentialSizePreview()
    if RefreshPositionPreview then RefreshPositionPreview() end
end)

local function RefreshPositionSliders()
    syncingPositions = true
    for _, item in ipairs(positionSliders) do
        local x, y = addon:GetOverlayPosition(item.kind)
        local value = item.axis == "x" and x or y
        item.slider:SetValue(value)
        item.value:SetText(value.." px")
    end
    syncingPositions = false
    RefreshPositionPreview()
end
diffSizeDefault:SetScript("OnClick", function()
    addon:SetOverlayPosition("threat", -8, -1)
    diffSizeSlider:SetValue(addon.defaults.threatDifferentialSize)
    RefreshPositionSliders()
end)
positionButton:SetNormalFontObject(GameFontNormal)
positionButton:SetHighlightFontObject(GameFontHighlight)
positionButton:SetScript("OnClick", function()
    RefreshPositionSliders()
    positionWindow:SetShown(not positionWindow:IsShown())
end)
colorsPage:HookScript("OnHide", function() positionWindow:Hide() end)

-- Match the threat editor's shell, preview, and slider layout.
local questCustomize = CreateFrame("Button", nil, colorsPage, "UIPanelButtonTemplate")
questCustomize:SetSize(58, 22)
questCustomize:SetPoint("CENTER", colorsPage, "TOPLEFT", RIGHT_OPTIONS_SWATCH_X + 93, -239)
questCustomize:SetText("Custom")
questCustomize:SetNormalFontObject(GameFontNormalSmall)
questCustomize:SetHighlightFontObject(GameFontHighlightSmall)
local questWindow = CreateFrame("Frame", "BTPQuestIconOptions", panel, "DefaultPanelTemplate")
questWindow:Hide()
questWindow:SetSize(520, 345)
questWindow:SetPoint("CENTER", panel, "CENTER")
questWindow:SetFrameLevel(panel:GetFrameLevel() + 20)
questWindow:EnableMouse(true)
questWindow.TitleContainer.TitleText:SetText("Position & Size")
local questClose = CreateFrame("Button", nil, questWindow, "UIPanelCloseButton")
questClose:SetPoint("TOPRIGHT", -5, 0)
questClose:SetFrameStrata("TOOLTIP")
questClose:SetFrameLevel(questWindow:GetFrameLevel() + 100)
questClose:SetScript("OnClick", function() questWindow:Hide() end)
local questInset = CreateFrame("Frame", nil, questWindow, "InsetFrameTemplate")
questInset:SetPoint("TOPLEFT", 14, -35)
questInset:SetPoint("BOTTOMRIGHT", -14, 14)
questInset:SetFrameLevel(questWindow:GetFrameLevel())
local questNote = questWindow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
questNote:SetPoint("TOP", 0, -44)
questNote:SetText("Adjust quest icon size and position using the sample nameplate.")
local questPreview = CreateFrame("Frame", nil, questWindow, "BackdropTemplate")
questPreview:SetPoint("TOPLEFT", 25, -67)
questPreview:SetPoint("TOPRIGHT", -25, -67)
questPreview:SetHeight(105)
questPreview:SetBackdrop(positionPreview:GetBackdrop())
questPreview:SetBackdropColor(0, 0, 0, 1)
questPreview:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
local questPreviewContent = CreateFrame("Frame", nil, questPreview)
questPreviewContent:SetSize(1, 1)
questPreviewContent:SetPoint("CENTER", 0, 0)
local questPreviewBar = CreateFrame("Frame", nil, questPreviewContent, "BackdropTemplate")
questPreviewBar:SetSize(250, 30)
questPreviewBar:SetPoint("CENTER", questPreviewContent, "CENTER")
questPreviewBar:SetBackdrop(positionPreviewBar:GetBackdrop())
questPreviewBar:SetBackdropColor(0.025, 0.02, 0.015, 1)
questPreviewBar:SetBackdropBorderColor(0.92, 0.92, 0.92, 1)
local questFill = questPreviewBar:CreateTexture(nil, "ARTWORK")
questFill:SetPoint("TOPLEFT", 4, -4)
questFill:SetPoint("BOTTOM", questPreviewBar, "BOTTOM", 0, 4)
questFill:SetWidth(155)
questFill:SetColorTexture(addon:GetQuestColor())
local questName = questPreviewBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
questName:SetFont("Fonts\\2002.TTF", 14, "OUTLINE")
questName:SetShadowColor(0, 0, 0, 1)
questName:SetShadowOffset(1, -1)
questName:SetPoint("LEFT", 9, 0)
questName:SetText("Young Wolf")
local questHealth = questPreviewBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
questHealth:SetPoint("RIGHT", -9, 0)
questHealth:SetText("63%")
local questLevelBox = CreateFrame("Frame", nil, questPreviewContent, "BackdropTemplate")
questLevelBox:SetAlpha(0) -- Reserve the badge's layout space without overlapping the icon.
questLevelBox:SetBackdrop(questPreviewBar:GetBackdrop())
questLevelBox:SetBackdropColor(0.025, 0.02, 0.015, 1)
questLevelBox:SetBackdropBorderColor(0.92, 0.82, 0.35, 1)
local questLevelText = questLevelBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
questLevelText:SetPoint("CENTER")
questLevelText:SetText("1")
local questPreviewIconFrame = CreateFrame("Frame", nil, questPreviewContent)
questPreviewIconFrame:SetFrameLevel(questPreviewBar:GetFrameLevel() + 5)
local questPreviewIcon = questPreviewIconFrame:CreateTexture(nil, "OVERLAY")
questPreviewIcon:SetAllPoints()
local function RefreshQuestPreview()
    local size = addon:GetQuestIconSettings()
    local geometry = addon:GetQuestIconPreviewGeometry()
    local width, height = geometry.width, geometry.height
    local x, y, level = geometry.x, geometry.y, geometry.level
    -- Magnify the complete sample so icon size and offsets keep the same
    -- proportions as the nameplate rather than stretching only the bar.
    questPreviewContent:SetScale(1.5 * addon:GetNameplatePreviewRenderScale(questPreview:GetEffectiveScale()))
    questPreviewBar:SetSize(width, height)
    if addon:IsATDStyle() then
        questPreviewBar:SetBackdropBorderColor(0.92, 0.92, 0.92, 1)
    else
        questPreviewBar:SetBackdropBorderColor(0.92, 0.82, 0.35, 1)
    end
    questPreviewBar:ClearAllPoints()
    local extraWidth = level and (level.x + level.width) or 0
    questPreviewBar:SetPoint("CENTER", questPreviewContent, "CENTER", -extraWidth/2, 0)
    questLevelBox:SetShown(level ~= nil)
    if level then
        questLevelBox:SetSize(level.width, level.height)
        questLevelBox:ClearAllPoints()
        questLevelBox:SetPoint("LEFT", questPreviewBar, "RIGHT", level.x, level.y)
    end
    questFill:SetWidth(math.max(1, (width - 8) * 0.63))
    questName:SetFont("Fonts\\2002.TTF", addon:GetMobNameFontSize(), "OUTLINE")
    questName:SetPoint("RIGHT", questHealth, "LEFT", -2, 0)
    questName:SetWordWrap(false)
    questName:SetJustifyH("LEFT")
    questHealth:SetFont(STANDARD_TEXT_FONT, addon:GetHealthPercentFontSize(), "OUTLINE")
    questPreviewIconFrame:SetSize(size, size)
    questPreviewIconFrame:ClearAllPoints()
    questPreviewIconFrame:SetPoint("RIGHT", questPreviewBar, "LEFT", x, y)
    addon:SetQuestObjectiveIcon(questPreviewIcon, "incomplete")
    if addon:GetQuestColorEnabled() then questFill:SetColorTexture(addon:GetQuestColor())
    else questFill:SetColorTexture(0.72,0.74,0.04,1) end
end
local questPreviewElapsed = 0
questWindow:SetScript("OnUpdate", function(_, elapsed)
    questPreviewElapsed = questPreviewElapsed + elapsed
    if questPreviewElapsed < 0.25 then return end
    questPreviewElapsed = 0
    RefreshQuestPreview()
end)
local questControls = {}
local syncingQuest = false
local function CreateQuestSlider(name, text, key, x, y, width, low, high)
    local label = questWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)
    local valueText = questWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("LEFT", label, "RIGHT", 8, 0)
    local slider = CreateOptionsSlider(name, questWindow)
    slider:SetPoint("TOPLEFT", x, y - 24)
    slider:SetWidth(width)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    _G[name.."Low"]:SetText(low)
    _G[name.."High"]:SetText(high)
    _G[name.."Text"]:SetText("")
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        valueText:SetText(value.." px")
        if syncingQuest then return end
        if key == "size" then ForeverNameplatesDB.questIconSize = value
        else
            ForeverNameplatesDB.questIconPosition = ForeverNameplatesDB.questIconPosition or {x=-6,y=0}
            ForeverNameplatesDB.questIconPosition[key] = value
        end
        addon:RefreshQuestMarkers()
        RefreshQuestPreview()
    end)
    questControls[#questControls+1] = {slider=slider,key=key,value=valueText}
    return slider
end
local questSizeSlider = CreateQuestSlider("BTPQuestIconSize", "Icon Size", "size", 118, -188, 235, 12, 48)
CreateQuestSlider("BTPQuestIconX", "Icon X", "x", 35, -255, 195, -200, 200)
CreateQuestSlider("BTPQuestIconY", "Icon Y", "y", 285, -255, 195, -100, 100)
local function SyncQuestSliders()
    syncingQuest = true
    local size, x, y = addon:GetQuestIconSettings()
    for _, control in ipairs(questControls) do
        local value = control.key == "size" and size or (control.key == "x" and x or y)
        control.slider:SetValue(value)
        control.value:SetText(value.." px")
    end
    syncingQuest = false
    RefreshQuestPreview()
end
local questDefault = CreateFrame("Button", nil, questWindow, "UIPanelButtonTemplate")
questDefault:SetSize(58, 22)
questDefault:SetPoint("LEFT", questSizeSlider, "RIGHT", 13, 0)
questDefault:SetText("Default")
questDefault:SetScript("OnClick", function()
    ForeverNameplatesDB.questIconSize = addon.defaults.questIconSize
    ForeverNameplatesDB.questIconPosition = {x=-6,y=0}
    SyncQuestSliders()
    addon:RefreshQuestMarkers()
end)
questCustomize:SetScript("OnClick", function()
    SyncQuestSliders()
    questWindow:SetShown(not questWindow:IsShown())
end)
colorsPage:HookScript("OnHide", function() questWindow:Hide() end)


local displayModes = {
    {value="differential", text="Threat Differential", tooltip="Shows your current threat difference on your selected target. Other enemies show a temporary snapshot of their last known difference when you switch targets. Snapshots do not update live."},
    {value="percentage", text="Threat Percentage", tooltip="Shows a live threat percentage supplied by Blizzard on your selected target and other enemies. Percentages continue updating when you switch targets."},
    {value="mixed", text="Mixed", tooltip="Shows the live threat-point difference on your selected target and live percentages on other enemies. Uses a percentage on your target when its difference is unavailable. No snapshots."},
}
local displayPicker = CreateFrame("Frame", "BTPThreatDisplayDropdown", colorsPage, "UIDropDownMenuTemplate")
displayPicker:SetPoint("TOPLEFT", 29, -453)
UIDropDownMenu_SetWidth(displayPicker, 175)
UIDropDownMenu_JustifyText(displayPicker, "LEFT")
local function RefreshDisplayPicker()
    local mode = addon:GetThreatDisplayMode()
    UIDropDownMenu_SetText(displayPicker, mode == "mixed" and "Mixed" or mode == "percentage" and "Threat Percentage" or "Threat Differential")
    RefreshTankOnlyControl()
    RefreshDifferentialSizePreview()
    if mode ~= "differential" or not addon:GetThreatDifferentialEnabled() then snapshotWindow:Hide() end
end
UIDropDownMenu_Initialize(displayPicker, function(_, level)
    for _, mode in ipairs(displayModes) do
        local info = UIDropDownMenu_CreateInfo()
        info.text, info.value = mode.text, mode.value
        info.checked = addon:GetThreatDisplayMode() == mode.value
        info.tooltipTitle, info.tooltipText = mode.text, mode.tooltip
        info.tooltipOnButton = true
        info.func = function(_, value)
            addon:SetThreatDisplayMode(value)
            RefreshDisplayPicker()
            CloseDropDownMenus()
        end
        info.arg1 = mode.value
        UIDropDownMenu_AddButton(info, level)
    end
end)
displayPicker:SetScript("OnShow", RefreshDisplayPicker)
diffCheck:HookScript("OnClick", RefreshDisplayPicker)

local fullNameCheck = CreateFrame("CheckButton", nil, targetPage, "UICheckButtonTemplate")
fullNameCheck:SetPoint("TOPLEFT", 105, -480)
fullNameCheck:SetSize(26, 26)

local fullNameLabel = targetPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
fullNameLabel:SetPoint("LEFT", fullNameCheck, "RIGHT", 4, 0)
fullNameLabel:SetText("Show Last Name")

fullNameCheck:SetScript("OnClick", function(self)
    addon:SetFullTargetNames(self:GetChecked())
end)




-- Selected Target Border color is temporarily disabled for Forever compatibility.

local percentUnavailableNote=nameplatesPage:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
percentUnavailableNote:SetPoint("TOPLEFT",45,-417)
percentUnavailableNote:SetText("Not available - enable Health Percentage in Options > Nameplates")

percentUnavailableNote:Hide()

local valueUnavailableNote=nameplatesPage:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
valueUnavailableNote:SetPoint("TOPLEFT",45,-477)
valueUnavailableNote:SetText("Not available - enable Health Value in Options > Nameplates")

valueUnavailableNote:Hide()

RefreshHealthSliderAvailability = function()
    if not panel:IsShown() then return end

    -- Nameplate events can fire on any page; warnings belong to Nameplates.
    if activePage ~= "nameplates" then
        percentUnavailableNote:Hide()
        valueUnavailableNote:Hide()
        return
    end

    if addon:GetCompatibilityMode() then
        percentSizeSlider:SetEnabled(false)
        percentSizeDefault:SetEnabled(false)
        valueSizeSlider:SetEnabled(false)
        valueSizeDefault:SetEnabled(false)
        percentUnavailableNote:Hide()
        valueUnavailableNote:Hide()
        _G[percentSizeSlider:GetName().."Low"]:Hide()
        _G[percentSizeSlider:GetName().."High"]:Hide()
        _G[valueSizeSlider:GetName().."Low"]:Hide()
        _G[valueSizeSlider:GetName().."High"]:Hide()
        return
    end

    local _,valueOn=addon:GetNameplateHealthInfoFlags()

    percentSizeSlider:SetEnabled(true)
    percentSizeDefault:SetEnabled(true)
    _G[percentSizeSlider:GetName().."Low"]:Show()
    _G[percentSizeSlider:GetName().."High"]:Show()
    percentUnavailableNote:Hide()

    valueSizeSlider:SetEnabled(valueOn)
    valueSizeDefault:SetEnabled(valueOn)
    _G[valueSizeSlider:GetName().."Low"]:SetShown(valueOn)
    _G[valueSizeSlider:GetName().."High"]:SetShown(valueOn)
    if valueOn then valueUnavailableNote:Hide() else valueUnavailableNote:Show() end
end

-- Shared footer -----------------------------------------------------------


local brandVersion = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
addon:StyleOptionsFont(brandVersion, 11)
brandVersion.btpOptionsTextRole="footer"
brandVersion:SetTextColor(0.48, 0.51, 0.56)
brandVersion:SetPoint("RIGHT", footer, "RIGHT", -18, 0)
local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local version = getMetadata and getMetadata(addonName or "BlizzThreatPlates-Forever", "Version")
brandVersion:SetText("Version " .. (version or "Unknown"))

local minimapCheck = CreateFrame("CheckButton", nil, footer, "BackdropTemplate")
minimapCheck.btpOptionsSurface="control"
minimapCheck:SetPoint("LEFT", footer, "LEFT", 22, 0)
minimapCheck:SetSize(16, 16)
minimapCheck:SetBackdrop({bgFile=SHELL_WHITE, edgeFile=SHELL_WHITE, edgeSize=1})
minimapCheck:SetBackdropColor(0.035, 0.040, 0.050, 1)
minimapCheck:SetBackdropBorderColor(0.32, 0.35, 0.39, 1)
local minimapMark = minimapCheck:CreateTexture(nil, "ARTWORK")
minimapMark:SetPoint("TOPLEFT", 4, -4)
minimapMark:SetPoint("BOTTOMRIGHT", -4, 4)
minimapMark:SetColorTexture(0.88, 0.66, 0.24, 1)
minimapMark.btpOptionsTextureRole="accent"
minimapMark.btpOptionsTextureMethod="SetColorTexture"
minimapMark.btpOptionsTextureColor={0.88,0.66,0.24,1}
minimapCheck:SetCheckedTexture(minimapMark)
minimapCheck:SetHighlightTexture(SHELL_WHITE)
minimapCheck:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)

local minimapLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
addon:StyleOptionsFont(minimapLabel, 12)
minimapLabel.btpOptionsTextRole="footer"
minimapLabel:SetTextColor(0.78, 0.80, 0.84)
minimapLabel:SetPoint("LEFT", minimapCheck, "RIGHT", 8, 0)
minimapLabel:SetText("Minimap Button")

minimapCheck:SetScript("OnClick", function(self)
    addon:SetMinimapVisible(self:GetChecked())
end)

local targetHeader = CreateSectionHeader(targetPage, "Target of Target", -110)

local targetSizeLabel = targetPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
targetSizeLabel:SetPoint("TOPLEFT", 110, -285)
targetSizeLabel:SetText("ToT Name Size")
local targetSizeValue = targetPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
targetSizeValue:SetPoint("LEFT", targetSizeLabel, "RIGHT", 10, 0)

local targetSizeSlider = CreateOptionsSlider("BTPTargetNameSizeSlider", targetPage)
targetSizeSlider:SetPoint("TOPLEFT", 110, -309)
targetSizeSlider:SetWidth(280)
targetSizeSlider:SetMinMaxValues(8, 24)
targetSizeSlider:SetValueStep(1)
targetSizeSlider:SetObeyStepOnDrag(true)
_G[targetSizeSlider:GetName().."Low"]:SetText("8")
_G[targetSizeSlider:GetName().."High"]:SetText("24")
_G[targetSizeSlider:GetName().."Text"]:SetText("")

local targetSizeDefault = CreateFrame("Button", nil, targetPage, "UIPanelButtonTemplate")
targetSizeDefault:SetSize(58, 22)
targetSizeDefault:SetPoint("LEFT", targetSizeSlider, "RIGHT", 12, 0)
targetSizeDefault:SetText("Default")

local previewNote = targetPage:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
previewNote:SetPoint("TOP", targetPage, "TOP", 0, -190)
previewNote:SetText("Sample nameplate")

-- Decorative sample only; independent of live unit names and health.
local previewBar = CreateFrame("Frame", nil, targetPage, "BackdropTemplate")
previewBar:SetSize(250, 30)
previewBar:SetPoint("TOP", targetPage, "TOP", 0, -220)
previewBar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12, insets = {left=3, right=3, top=3, bottom=3},
})
previewBar:SetBackdropColor(0.025, 0.02, 0.015, 1)
previewBar:SetBackdropBorderColor(1, 1, 1, 1)
local previewFill = previewBar:CreateTexture(nil, "ARTWORK")
previewFill:SetPoint("TOPLEFT", 4, -4)
previewFill:SetSize(128, 22)
previewFill:SetColorTexture(0.18, 0.95, 0.05, 1)
local previewMob = previewBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
previewMob:SetFont("Fonts\\2002.TTF", 14, "OUTLINE")
previewMob:SetShadowColor(0, 0, 0, 1)
previewMob:SetShadowOffset(1, -1)
previewMob:SetPoint("LEFT", 10, 0)
previewMob:SetText("Young Wolf")
local previewHealth = previewBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
previewHealth:SetPoint("RIGHT", -10, 0)
previewHealth:SetText("53%")
local previewTargetAnchor = CreateFrame("Frame", nil, previewBar)
previewTargetAnchor:SetSize(1, 1)
previewTargetAnchor:SetPoint("TOPRIGHT", previewBar, "BOTTOMRIGHT", 0, -5)
local previewTarget = previewTargetAnchor:CreateFontString(nil, "OVERLAY")
previewTarget:SetFontObject(SystemFont_NamePlate or GameFontNormal)
previewTarget:SetPoint("TOPRIGHT", previewTargetAnchor, "TOPRIGHT", 0, 0)
previewTarget:SetJustifyH("RIGHT")
previewTarget:SetTextColor(0.78, 0.61, 0.43)
previewTarget:SetShadowColor(0, 0, 0, 1)
previewTarget:SetShadowOffset(1, -1)

local function CreateTargetToggle(text, y)
    local check = CreateFrame("CheckButton", nil, targetPage, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check:SetPoint("TOPLEFT", 105, y)
    check.label = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    check.label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    check.label:SetText(text)
    return check
end
local targetEnabledCheck = CreateTargetToggle("Disable Target of Target", -510)

local function RefreshTargetPreviewScale()
    local scale = addon:GetTargetNamePreviewScale() / previewBar:GetEffectiveScale()
    if previewTargetAnchor:GetScale() ~= scale then
        previewTargetAnchor:SetScale(scale)
    end
end

local function RefreshTargetPreview()
    RefreshTargetPreviewScale()
    local size = addon:GetTargetNameFontSize()
    addon:ApplyTargetNameFont(previewTarget,size)
    previewTarget:SetText(addon:GetFullTargetNames() and "Preview Name" or "Preview")
    previewTarget:SetShown(addon:GetTargetNamesEnabled())
    targetSizeValue:SetText(size.." px")
    local x, y = addon:GetOverlayPosition("target")
    previewTargetAnchor:ClearAllPoints()
    previewTargetAnchor:SetPoint("TOPRIGHT", previewBar, "BOTTOMRIGHT", x, (addon:IsATDStyle() and -1.5 or -5) + y)
end

local targetPositionControls = {}
local syncingTargetPosition = false
for index, axis in ipairs({"x", "y"}) do
    local axisKey = axis
    local y = -345 - (index - 1) * 60
    local label = targetPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 110, y)
    label:SetText(axisKey == "x" and "Horizontal Position" or "Vertical Position")
    local valueText = targetPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("LEFT", label, "RIGHT", 10, 0)
    local slider = CreateOptionsSlider("BTPTargetPosition"..axisKey:upper(), targetPage)
    slider:SetPoint("TOPLEFT", 110, y - 24)
    slider:SetWidth(280)
    slider:SetMinMaxValues(-100, 100)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    _G[slider:GetName().."Low"]:SetText("-100")
    _G[slider:GetName().."High"]:SetText("100")
    _G[slider:GetName().."Text"]:SetText("")
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        valueText:SetText(value.." px")
        if syncingTargetPosition then return end
        local x, yOffset = addon:GetOverlayPosition("target")
        addon:SetOverlayPosition("target", axisKey == "x" and value or x, axisKey == "y" and value or yOffset)
        RefreshTargetPreview()
    end)
    local reset = CreateFrame("Button", nil, targetPage, "UIPanelButtonTemplate")
    reset:SetSize(58, 22)
    reset:SetPoint("LEFT", slider, "RIGHT", 12, 0)
    reset:SetText("Default")
    reset:SetScript("OnClick", function()
        local _,x,y=addon:GetTargetNameDefaults()
        slider:SetValue(axisKey == "x" and x or y)
    end)
    targetPositionControls[index] = {slider=slider, reset=reset, value=valueText, axis=axisKey}
end
local syncingTargetSize = false
local function RefreshTargetControls()
    syncingTargetSize = true
    targetSizeSlider:SetValue(addon:GetTargetNameFontSize())
    syncingTargetSize = false
    fullNameCheck:SetChecked(addon:GetFullTargetNames())
    local enabled = addon:GetTargetNamesEnabled()
    syncingTargetPosition = true
    local x, y = addon:GetOverlayPosition("target")
    for _, control in ipairs(targetPositionControls) do
        local value = control.axis == "x" and x or y
        control.slider:SetValue(value)
        control.value:SetText(value.." px")
        control.slider:SetEnabled(enabled)
        control.reset:SetEnabled(enabled)
    end
    syncingTargetPosition = false
    targetEnabledCheck:SetChecked(not enabled)
    targetSizeSlider:SetEnabled(enabled)
    targetSizeDefault:SetEnabled(enabled)
    fullNameCheck:SetEnabled(enabled)
    fullNameLabel:SetAlpha(enabled and 1 or 0.5)
    RefreshTargetPreview()
end
targetEnabledCheck:SetScript("OnClick", function(self)
    addon:SetTargetNamesEnabled(not self:GetChecked())
    RefreshTargetControls()
end)
targetSizeSlider:SetScript("OnValueChanged", function(_, value)
    if syncingTargetSize then return end
    addon:SetTargetNameFontSize(value)
    RefreshTargetPreview()
end)
targetSizeDefault:SetScript("OnClick", function()
    addon:SetTargetNameFontSize(nil)
    RefreshTargetControls()
end)
fullNameCheck:HookScript("OnClick", RefreshTargetPreview)
targetPage:SetScript("OnShow", RefreshTargetControls)
-- Follow UI-scale changes while open, without sampling live nameplates.
local previewScaleElapsed = 0
targetPage:SetScript("OnUpdate", function(_, elapsed)
    previewScaleElapsed = previewScaleElapsed + elapsed
    if previewScaleElapsed < 0.2 then return end
    previewScaleElapsed = 0
    RefreshTargetPreviewScale()
end)

local pages = {nameplates = nameplatesPage, colors = colorsPage, target = targetPage, roles = dungeonRaidView}
local navigation = {}
SelectPage = function(key)
    key = pages[key] and key or "colors"
    activePage = key
    for pageKey, page in pairs(pages) do page:SetShown(pageKey == key) end
    for pageKey, button in pairs(navigation) do
        button:SetEnabled(pageKey ~= key and not (pageKey == "colors" and key == "roles"))
    end
    if key == "colors" then RefreshSwatches() end
    if key == "roles" then RefreshDRSwatches() end
    RefreshHealthSliderAvailability()
    if addon.OnOptionsPageChanged then addon:OnOptionsPageChanged(key) end
end

for index, entry in ipairs({
    {"colors", "Colors & Threat"},
    {"nameplates", "Nameplates"},
    {"target", "Target of Target"},
}) do
    local key = entry[1]
    local button = CreateFrame("Button", nil, contentInset, "UIPanelButtonTemplate")
    button:SetSize(174, 26)
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", 38 + (index - 1) * 184, -70)
    button:SetScript("OnClick", function() SelectPage(key) end)
    button:SetText(entry[2])
    navigation[key] = button
end
addon.OptionsPanel = panel
addon.OptionsContentRoot = contentRoot
addon.OptionsContentInset = contentInset
addon.OptionsPages = pages
addon.OptionsNavigation = navigation
addon.SelectOptionsPage = function(key) SelectPage(key) end
addon.GetOptionsPage = function() return activePage end
-- Modern pages share the existing quest editor and non-target brightness state.
addon.ThreatOptionsActions = {
    OpenQuestEditor = function()
        if addon.OpenModernQuestIconOptions and not ForeverNameplatesDB.useLegacyNameplateOptions then
            addon:OpenModernQuestIconOptions()
            return
        end
        questWindow:SetFrameLevel(panel:GetFrameLevel() + 80)
        questCustomize:Click()
    end,
    GetNonTargetsBright = function() return addon:GetNonTargetsBright() end,
    SetNonTargetsBright = function(enabled) addon:SetNonTargetsBright(enabled) end,
    CloseEditors = function()
        snapshotWindow:Hide()
        positionWindow:Hide()
        questWindow:Hide()
        if addon.CloseModernThreatDisplayOptions then addon:CloseModernThreatDisplayOptions() end
    end,
}
SelectPage("colors")
panel:SetScript("OnShow", function()
    SelectPage(addon.GetOptionsInitialPage and addon:GetOptionsInitialPage() or "colors")
    RefreshSwatches()
    minimapCheck:SetChecked(addon:GetMinimapVisible())
    fullNameCheck:SetChecked(addon:GetFullTargetNames())
    local size=addon:GetMobNameFontSize()
    nameSizeSlider:SetValue(size)
    nameSizeValue:SetText(size.." px")
    local ps=addon:GetHealthPercentFontSize()
    percentSizeSlider:SetValue(ps)
    percentSizeValue:SetText(ps.." px")
    local vs=addon:GetHealthValueFontSize()
    valueSizeSlider:SetValue(vs)
    valueSizeValue:SetText(vs.." px")
    local nps=addon:GetNameplateSize()
    appearanceSizeSlider:SetValue(nps)
    appearanceSizeValue:SetText(nps)
end)


function addon:ToggleOptions()
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

-- Quick UI command.
SLASH_BLIZZ_TANK_PLATES_FOREVER1 = "/btp"
SlashCmdList["BLIZZ_TANK_PLATES_FOREVER"] = function()
    addon:ToggleOptions()
end


panel:HookScript("OnShow",RefreshHealthSliderAvailability)

local btpHealthAvailabilityEvents=CreateFrame("Frame")
btpHealthAvailabilityEvents:RegisterEvent("CVAR_UPDATE")
btpHealthAvailabilityEvents:SetScript("OnEvent",function(_, _, name)
    if name and (name:lower()=="nameplateinfodisplay" or name:lower()=="nameplatestyle") then
        RefreshHealthSliderAvailability()
    end
end)
