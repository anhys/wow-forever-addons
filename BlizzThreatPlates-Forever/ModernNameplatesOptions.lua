local addon = ForeverNameplates
local panel = addon.OptionsPanel
local contentRoot = addon.OptionsContentRoot or panel
local nameplatesPage = addon.OptionsPages and addon.OptionsPages.nameplates
if not panel or not nameplatesPage then return end

-- The same localized text, cyan glow, and pulse used by Blizzard Settings.
-- Each marker belongs to our own UI and follows its parent's visibility.
function addon:CreateOptionsNewFeatureTag(parent, anchor, point, relativePoint, x, y)
    local tag = CreateFrame("Frame", nil, parent, "NewFeatureLabelTemplate")
    tag.btpDevExclude = true
    tag:SetScale(0.8)
    tag:SetPoint(point or "LEFT", anchor, relativePoint or "RIGHT", x or 6, y or 0)
    tag:EnableMouse(false)
    tag:Show()
    return tag
end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local GOLD = {0.88, 0.66, 0.24}
local TEXT = {0.92, 0.90, 0.84}
local MUTED = {0.56, 0.57, 0.58}
local PANEL = {0.065, 0.075, 0.090, 1}
local CARD = {0.085, 0.097, 0.115, 1}
local CARD_HOVER = {0.12, 0.135, 0.16, 1}
local BORDER = {0.20, 0.23, 0.27, 1}
local views, activeView, refreshAll = {}, "style", nil
local pendingCVars = {}

local function Backdrop(frame, color, border)
    frame.btpOptionsSurface = color and color[1]==0.065 and color[2]==0.075 and "main" or "card"
    frame:SetBackdrop({bgFile=WHITE, edgeFile=WHITE, edgeSize=1})
    frame:SetBackdropColor(unpack(color or CARD))
    frame:SetBackdropBorderColor(unpack(border or BORDER))
end

local shell = CreateFrame("Frame", nil, nameplatesPage, "BackdropTemplate")
shell:SetPoint("TOPLEFT", contentRoot, "TOPLEFT", 24, -104)
shell:SetPoint("BOTTOMRIGHT", contentRoot, "BOTTOMRIGHT", -24, 60)
shell:SetFrameLevel(nameplatesPage:GetFrameLevel() + 30)
shell:EnableMouse(true)
Backdrop(shell, PANEL, BORDER)

local function RestyleNavigation()
    local navigation = addon.OptionsNavigation or {}
    local function RefreshButton(button)
        -- Sidebar group labels stay neutral; gold marks the selected submenu.
        local active = button.btpSidebarSelected == nil and not button:IsEnabled()
        local font = button:GetFontString()
        if font then font:SetTextColor(unpack(active and GOLD or TEXT)) end
        if button.btpModernUnderline then button.btpModernUnderline:SetShown(active and button.btpSidebarSelected==nil) end
    end
    for _, button in pairs(navigation) do
        button:SetNormalTexture(WHITE)
        button:SetPushedTexture(WHITE)
        button:SetDisabledTexture(WHITE)
        button:SetHighlightTexture(WHITE)
        button:GetNormalTexture():SetVertexColor(0.085, 0.097, 0.115, 1)
        button:GetPushedTexture():SetVertexColor(0.09, 0.10, 0.12, 1)
        button:GetDisabledTexture():SetVertexColor(0.07, 0.08, 0.095, 1)
        button:GetHighlightTexture():SetVertexColor(0.12, 0.13, 0.15, 0.65)
        local underline = button:CreateTexture(nil, "OVERLAY")
        underline:SetTexture(WHITE)
        underline:SetHeight(2)
        underline:SetPoint("BOTTOMLEFT", 6, 1)
        underline:SetPoint("BOTTOMRIGHT", -6, 1)
        underline:SetVertexColor(unpack(GOLD))
        button.btpModernUnderline = underline
        button:HookScript("OnEnable", function(self) RefreshButton(self) end)
        button:HookScript("OnDisable", function(self) RefreshButton(self) end)
        button:HookScript("OnClick", function()
            C_Timer.After(0, function()
                for _, other in pairs(navigation) do RefreshButton(other) end
            end)
        end)
        RefreshButton(button)
    end
end
RestyleNavigation()

local function Font(parent, template, text, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY", template)
    label.btpOptionsTextRole = template:find("Large") and "heading" or (template:find("Disable") and "muted" or "body")
    label:SetPoint("TOPLEFT", x, y)
    if width then label:SetWidth(width); label:SetJustifyH("LEFT") end
    label:SetText(text or "")
    return label
end

local function StyleButton(button, selected)
    button:SetBackdropColor(unpack(selected and CARD_HOVER or CARD))
    button:SetBackdropBorderColor(unpack(selected and GOLD or BORDER))
end

local function Button(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    Backdrop(button)
    button.btpOptionsSurface = "control"
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label.btpOptionsTextRole = "button"
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    button.label:SetTextColor(unpack(TEXT))
    button:SetScript("OnEnter", function(self) StyleButton(self, true) end)
    button:SetScript("OnLeave", function(self) StyleButton(self, false) end)
    return button
end

local function OpenColorPicker(color, apply, cancel)
    local r, g, b = color[1], color[2], color[3]
    local function Changed()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        apply({nr, ng, nb})
        if refreshAll then refreshAll() end
    end
    local function Cancelled(previous)
        (cancel or apply)({previous and (previous.r or previous[1]) or r,
            previous and (previous.g or previous[2]) or g,
            previous and (previous.b or previous[3]) or b})
        if refreshAll then refreshAll() end
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({r=r, g=g, b=b, hasOpacity=false,
            swatchFunc=Changed, cancelFunc=Cancelled})
    else
        ColorPickerFrame.func = Changed
        ColorPickerFrame.cancelFunc = Cancelled
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = {r=r, g=g, b=b}
        local picker = ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker or ColorPickerFrame.ColorPicker
        if picker and picker.SetColorRGB then picker:SetColorRGB(r, g, b)
        elseif ColorPickerFrame.SetColorRGB then ColorPickerFrame:SetColorRGB(r, g, b) end
        ColorPickerFrame:Show()
    end
end

local function SetControlEnabled(control, enabled)
    control:SetEnabled(enabled)
    control:SetAlpha(enabled and 1 or 0.42)
end

local function CreateView(key, title, description)
    local view = CreateFrame("Frame", nil, shell)
    view:SetAllPoints(shell)
    view:Hide()
    views[key] = view

    local titleX = 20
    local heading = Font(view, "GameFontNormalLarge", title, titleX, -14, 420)
    heading:SetTextColor(unpack(TEXT))
    if title == "Enemy Debuffs" then
        heading:SetWordWrap(false)
        heading:SetWidth(0)
        addon:CreateOptionsNewFeatureTag(view,heading,"LEFT","RIGHT",4,0)
    end
    local note = Font(view, "GameFontDisableSmall", description, titleX, -34, 495)
    note:SetTextColor(unpack(MUTED))
    local line = view:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(BORDER))
    line.btpOptionsTextureRole="border"
    line.btpOptionsTextureMethod="SetColorTexture"
    line.btpOptionsTextureColor=BORDER
    line:SetPoint("TOPLEFT", 18, -54)
    line:SetPoint("TOPRIGHT", -18, -54)
    line:SetHeight(1)
    return view
end

local function SectionLabel(parent, text, y)
    local label = Font(parent, "GameFontHighlightSmall", string.upper(text), 44, y, 480)
    label:SetTextColor(unpack(GOLD))
    return label
end

local function HighlightSelectorButton(button)
    local function Paint(hovered)
        button:SetBackdropColor(unpack(hovered and {0.17, 0.13, 0.065, 1} or {0.10, 0.085, 0.045, 1}))
        button:SetBackdropBorderColor(unpack(hovered and GOLD or {0.67, 0.50, 0.21, 1}))
    end
    button:SetScript("OnEnter", function() Paint(true) end)
    button:SetScript("OnLeave", function() Paint(false) end)
    Paint(false)
end

local menuFrame = CreateFrame("Frame", "BTPModernNameplateMenu", UIParent, "UIDropDownMenuTemplate")
local modernPopupCount=0
local function Selector(parent, labelText, y, choicesFunc, getValue, setValue, prominent, compactWidth)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(compactWidth or 480, compactWidth and 24 or 32)
    row:SetPoint("TOPLEFT", 44, y)
    Backdrop(row)
    if compactWidth then
        row:SetBackdrop(nil)
    else
        local label = Font(row, "GameFontHighlightSmall", labelText, 12, -10, prominent and 180 or 215)
        label:SetTextColor(unpack(TEXT))
    end
    local button = Button(row, "", compactWidth or (prominent and 260 or 210), (compactWidth or prominent) and 24 or 22)
    if compactWidth then button:SetPoint("CENTER") else button:SetPoint("RIGHT", -8, 0) end
    button.value = button.label
    local arrow = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetText("v")
    arrow:SetTextColor(unpack(GOLD))
    button.value:ClearAllPoints()
    button.value:SetPoint("LEFT", 10, 0)
    button.value:SetPoint("RIGHT", arrow, "LEFT", -8, 0)
    button.value:SetJustifyH("LEFT")
    if prominent then
        button.value:SetTextColor(1,1,1)
        HighlightSelectorButton(button)
    end
    local popup,menu,items
    local function OpenModernMenu()
        if popup and popup:IsShown() then popup:Hide(); return end
        CloseDropDownMenus()
        if not popup then
            modernPopupCount=modernPopupCount+1
            -- An invisible click catcher closes the menu without changing the
            -- page beneath it. Parenting to the row preserves UI scale/theme.
            popup=CreateFrame("Button","BTPModernSelectorPopup"..modernPopupCount,row)
            popup:SetAllPoints(UIParent)
            popup:SetFrameStrata("FULLSCREEN_DIALOG")
            popup:SetFrameLevel(panel:GetFrameLevel()+200)
            popup:SetScript("OnClick",function() popup:Hide() end)
            popup:Hide()
            UISpecialFrames=UISpecialFrames or {}
            table.insert(UISpecialFrames,popup:GetName())
            menu=CreateFrame("Frame",nil,popup,"BackdropTemplate")
            menu.btpOptionsSurface="control"
            menu:EnableMouse(true)
            menu:SetClampedToScreen(true)
            Backdrop(menu,{14/255,16/255,19/255,1},BORDER)
            menu:SetFrameLevel(popup:GetFrameLevel()+1)
            items={}
            row:HookScript("OnHide",function() popup:Hide() end)
        end
        local choices=choicesFunc()
        local width=button:GetWidth()
        for index,choice in ipairs(choices) do
            local item=items[index]
            if not item then
                item=Button(menu,"",width-8,26)
                item.label:ClearAllPoints()
                item.label:SetPoint("LEFT",12,0)
                item.label:SetJustifyH("LEFT")
                local function PaintItem()
                    item:SetBackdropColor(unpack(item.hovered and {0.17,0.13,0.065,1} or {14/255,16/255,19/255,1}))
                    item:SetBackdropBorderColor(unpack(item.hovered and GOLD or {14/255,16/255,19/255,0}))
                    item.label:SetTextColor(unpack(item.selected and GOLD or TEXT))
                end
                item:SetScript("OnEnter",function() item.hovered=true; PaintItem() end)
                item:SetScript("OnLeave",function() item.hovered=nil; PaintItem() end)
                item:HookScript("OnHide",function() item.hovered=nil end)
                item.Paint=PaintItem
                items[index]=item
            end
            local value=choice.value
            item.selected=value==getValue()
            item.hovered=nil
            item.label:SetText(choice.text)
            width=math.max(width,item.label:GetStringWidth()+32)
            item:SetEnabled(not choice.disabled)
            item:SetAlpha(choice.disabled and 0.45 or 1)
            item:SetScript("OnClick",function()
                popup:Hide()
                setValue(value)
                row:Refresh()
                if refreshAll then refreshAll() end
            end)
            item:Show()
            item.Paint()
        end
        for index,item in ipairs(items) do
            item:SetShown(index<=#choices)
            item:SetSize(width-8,26)
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT",4,-4-(index-1)*26)
        end
        menu:SetSize(width,#choices*26+8)
        menu:ClearAllPoints()
        if row.openUpward then menu:SetPoint("BOTTOMRIGHT",button,"TOPRIGHT",0,6)
        else menu:SetPoint("TOPRIGHT",button,"BOTTOMRIGHT",0,-6) end
        popup:Show()
    end
    button:SetScript("OnClick", function(self)
        if row.useModernMenu then OpenModernMenu(); return end
        -- Forever exposes Blizzard's legacy UIDropDownMenu functions, but not
        -- the EasyMenu convenience wrapper available on some other clients.
        UIDropDownMenu_Initialize(menuFrame, function(_, level)
            if level ~= 1 then return end
            for _, choice in ipairs(choicesFunc()) do
                local item = choice
                local info = UIDropDownMenu_CreateInfo()
                info.text = item.text
                info.checked = item.value == getValue()
                info.disabled = item.disabled
                info.func = function()
                    setValue(item.value)
                    CloseDropDownMenus()
                    if refreshAll then refreshAll() end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end, "MENU")
        ToggleDropDownMenu(1, nil, menuFrame, self, 0, 0)
    end)
    row.Refresh = function(self)
        arrow:SetText(self.openUpward and "^" or "v")
        local value = getValue()
        local text = tostring(value)
        for _, choice in ipairs(choicesFunc()) do if choice.value == value then text = choice.shortText or choice.text end end
        button.value:SetText(text)
    end
    row.SetEnabled = function(_, enabled)
        if prominent then
            button:SetEnabled(enabled)
            row:SetAlpha(enabled and 1 or 0.42)
        else SetControlEnabled(button, enabled) end
    end
    return row
end

local function Toggle(parent, text, x, y, getValue, setValue, width)
    local check = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    check:SetSize(16, 16)
    check:SetPoint("TOPLEFT", x, y)
    Backdrop(check, {0.025, 0.030, 0.038, 1}, BORDER)
    check.btpOptionsSurface = "control"
    local mark = check:CreateTexture(nil, "OVERLAY")
    mark:SetTexture(WHITE)
    mark:SetPoint("TOPLEFT", 4, -4)
    mark:SetPoint("BOTTOMRIGHT", -4, 4)
    mark:SetVertexColor(unpack(GOLD))
    mark.btpOptionsTextureRole = "accent"
    check:SetCheckedTexture(mark)
    check.label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    check.label.btpOptionsTextRole = "body"
    check.label:SetPoint("LEFT", check, "RIGHT", 7, 0)
    check.label:SetWidth(width or 210)
    check.label:SetJustifyH("LEFT")
    check.label:SetText(text)
    check:SetScript("OnClick", function(self)
        setValue(self:GetChecked() and true or false)
        if refreshAll then refreshAll() end
    end)
    check.Refresh = function(self) self:SetChecked(getValue() and true or false) end
    return check
end

local function SliderRow(parent, labelText, x, y, width, low, high, step, getValue, setValue, suffix, newFeature)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, 46)
    row:SetPoint("TOPLEFT", x, y)
    local caption = labelText:gsub("%-", " "):gsub("(%a)([%w']*)", function(first, rest)
        return first:upper()..rest
    end):gsub(":$", "")..":"
    local label = Font(row, "GameFontHighlightSmall", caption, 0, 0, width - 50)
    local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value.btpOptionsTextRole = "value"
    for _, text in ipairs({label, value}) do
        local face, size, flags = text:GetFont()
        if face then text:SetFont(face, size + 1, flags) end
    end
    if newFeature then
        label:SetWidth(0)
        addon:CreateOptionsNewFeatureTag(row, label)
    end
    value:SetPoint("TOPRIGHT", 0, 0)
    value:SetTextColor(unpack(GOLD))
    local slider = CreateFrame("Slider", nil, row, "BackdropTemplate")
    slider:SetPoint("TOPLEFT", 0, -15)
    slider:SetSize(width, 22)
    slider:SetHitRectInsets(-5, -5, -2, -2)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    -- Keep the artwork slim while giving the mouse a generous grab area.
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(5)
    track:SetColorTexture(0.20, 0.20, 0.20, 1)
    local trackFill = slider:CreateTexture(nil, "BORDER")
    trackFill:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1)
    trackFill:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", -1, 1)
    trackFill:SetColorTexture(0.025, 0.030, 0.038, 1)
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(WHITE)
    thumb:SetSize(12, 18)
    thumb:SetVertexColor(unpack(GOLD))
    thumb.btpOptionsTextureRole = "accent"
    slider:SetThumbTexture(thumb)
    local function ValueText(number)
        if step < 1 then return string.format("%.2f", number)..(suffix or "") end
        return tostring(number)..(suffix or "")
    end
    slider:SetScript("OnValueChanged", function(self, raw)
        local rounded = math.floor((raw / step) + 0.5) * step
        value:SetText(ValueText(rounded))
        if not self.btpSync then
            setValue(rounded)
            if row.OnUserValueChanged then row:OnUserValueChanged(rounded) end
        end
    end)
    row.Refresh = function()
        slider.btpSync = true
        slider:SetValue(getValue())
        slider.btpSync = false
        value:SetText(ValueText(getValue()))
    end
    local notches = {}
    row.SetEnabled = function(_, enabled)
        slider:SetEnabled(enabled)
        for _, notch in ipairs(notches) do notch:SetEnabled(enabled) end
        row:SetAlpha(enabled and 1 or 0.42)
    end
    row.AddNotches = function(_, positions)
        row:SetHeight(58)
        for _, number in ipairs(positions) do
            local target = number
            local notch = CreateFrame("Button", nil, row)
            notch:SetSize(28, 22)
            notch:SetPoint("TOP", slider, "BOTTOMLEFT", (target - low) / (high - low) * width, 2)
            local tick = notch:CreateTexture(nil, "ARTWORK")
            tick:SetColorTexture(0.45, 0.40, 0.30, 1)
            tick:SetSize(1, 4)
            tick:SetPoint("TOP", 0, 0)
            local text = notch:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("TOP", 0, -6)
            text:SetText(tostring(target))
            text:SetTextColor(unpack(MUTED))
            notch:SetScript("OnClick", function() slider:SetValue(target) end)
            notch:SetScript("OnEnter", function() text:SetTextColor(unpack(GOLD)) end)
            notch:SetScript("OnLeave", function() text:SetTextColor(unpack(MUTED)) end)
            notches[#notches + 1] = notch
        end
    end
    row.slider = slider
    return row
end

local function PreviewCard(parent, height, y)
    local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    preview:SetSize(480, height)
    preview:SetPoint("TOPLEFT", 44, y or -66)
    if preview.SetClipsChildren then preview:SetClipsChildren(true) end
    Backdrop(preview, {0.055, 0.063, 0.075, 1}, {0.20, 0.23, 0.27, 1})
    preview.btpOptionsSurface = "preview"
    return preview
end

local function PreviewNumber(value, fallback)
    if issecretvalue and issecretvalue(value) then return fallback end
    return type(value) == "number" and value > 0 and value or fallback
end

local function GetStylePreviewGeometry()
    local geometry = addon:GetNameplatePreviewGeometry()
    local level = geometry.level
    geometry.levelWidth = level and level.width or 0
    geometry.levelHeight = level and level.height or 0
    geometry.levelGap = level and level.x or 0
    geometry.levelFontSize = geometry.levelFontSize or 10
    return geometry
end

local function GetStylePreviewRenderScale(panelScale)
    -- Nameplates are rendered in world-frame coordinates; UIParent may use a
    -- different UI scale. The sample represents a selected target, including
    -- its selected-target multiplier and the same native dimensions/fonts.
    return addon:GetNameplatePreviewRenderScale(panelScale)
end

local function SetPreviewAtlas(texture, atlas)
    if not texture or not texture.SetAtlas then return false end
    if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(atlas) then return false end
    local ok = pcall(texture.SetAtlas, texture, atlas, false)
    if not ok then ok = pcall(texture.SetAtlas, texture, atlas) end
    return ok
end

local function SetPreviewFont(fontString, fontObject, size)
    fontString:SetFontObject(fontObject or GameFontHighlight)
    local path, _, flags = fontString:GetFont()
    if not flags or not flags:find("OUTLINE", 1, true) then
        flags = flags and flags ~= "" and ("OUTLINE, "..flags) or "OUTLINE"
    end
    if path then fontString:SetFont(path, size, flags or "OUTLINE") end
    -- SetFontObject also replaces shadow properties, so apply these afterward.
    fontString:SetShadowColor(0, 0, 0, 1)
    fontString:SetShadowOffset(1, -1)
end

-- Nameplate style ---------------------------------------------------------
local styleView = CreateView("style", "Style", "")
local styleSelector = Selector(styleView, "Style", -66, function()
    local choices = {}
    for _, style in ipairs(addon:GetNameplateStyles()) do
        if style.key == "Modern" or style.key == "Thin" or style.key == "ATD" or style.key == "DevDraft" or style.key=="JUNDIES"
            or style.id == addon:GetNameplateStyleFamily() then
            choices[#choices + 1] = {text=style.name, value=style.id, disabled=InCombatLockdown()}
        end
    end
    return choices
end, function() return addon:GetNameplateStyleFamily() end, function(value) addon:SetNameplateStyle(value) end, true)

-- This is an addon-owned reconstruction. It uses Blizzard's public layout
-- constants and artwork, but never creates or measures a protected nameplate.
local stylePreview = PreviewCard(styleView, 64, -134)
local stylePreviewCaption = Font(styleView, "GameFontDisableSmall", "Preview", 44, -119, 240)
stylePreviewCaption:SetTextColor(unpack(MUTED))
local stylePreviewViewport = CreateFrame("Frame", nil, stylePreview)
stylePreviewViewport:SetPoint("TOPLEFT", 8, -6)
stylePreviewViewport:SetPoint("BOTTOMRIGHT", -8, 6)
if stylePreviewViewport.SetClipsChildren then stylePreviewViewport:SetClipsChildren(true) end
local function CreateNameplateSample(stylePreview, stylePreviewViewport, stylePreviewCaption, displayScale)
    local sample = {}
    local stylePreviewContent = CreateFrame("Frame", nil, stylePreviewViewport)
    stylePreviewContent.btpDevExclude = true
    stylePreviewContent:SetSize(1, 1)
    stylePreviewContent:SetPoint("CENTER", stylePreviewViewport, "CENTER", 0, 0)

    local stylePreviewBar = CreateFrame("StatusBar", nil, stylePreviewContent, "BackdropTemplate")
    stylePreviewBar:SetStatusBarTexture(WHITE)
    stylePreviewBar:SetMinMaxValues(0, 1)
    stylePreviewBar:SetValue(1)
    Backdrop(stylePreviewBar, {0.015, 0.015, 0.015, 1}, {0.82, 0.64, 0.20, 1})

    local stylePreviewBackground = stylePreviewBar:CreateTexture(nil, "BACKGROUND")
    stylePreviewBackground:SetPoint("TOPLEFT", 1, -1)
    stylePreviewBackground:SetPoint("BOTTOMRIGHT", -1, 1)
    stylePreviewBackground:SetTexture(WHITE)
    stylePreviewBackground:SetVertexColor(0.035, 0.035, 0.035, 1)

    local stylePreviewFill = stylePreviewBar:GetStatusBarTexture()
    stylePreviewFill:SetTexture(WHITE)
    stylePreviewFill:SetVertexColor(1, 0.55, 0.02, 1)

    local stylePreviewSelection = stylePreviewBar:CreateTexture(nil, "OVERLAY", nil, 2)
    stylePreviewSelection:SetPoint("TOPLEFT", -4, 4)
    stylePreviewSelection:SetPoint("BOTTOMRIGHT", 4, -4)

    local stylePreviewName = stylePreviewBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stylePreviewName:SetText("Young Wolf")
    stylePreviewName:SetTextColor(1, 1, 1, 1)
    stylePreviewName:SetShadowColor(0, 0, 0, 1)
    stylePreviewName:SetShadowOffset(1, -1)

    local stylePreviewPercent = stylePreviewBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stylePreviewPercent:SetText("100%")
    stylePreviewPercent:SetTextColor(1, 1, 1, 1)
    stylePreviewPercent:SetShadowColor(0, 0, 0, 1)
    stylePreviewPercent:SetShadowOffset(1, -1)
    local stylePreviewValue = stylePreviewBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stylePreviewValue:SetText("1.2K")
    stylePreviewValue:SetTextColor(1, 1, 1, 1)
    stylePreviewName:SetWordWrap(false)
    stylePreviewName:SetJustifyH("LEFT")

    local stylePreviewLevel = CreateFrame("Frame", nil, stylePreviewContent, "BackdropTemplate")
    Backdrop(stylePreviewLevel, {0.01, 0.01, 0.01, 1}, {0.82, 0.64, 0.20, 1})
    local stylePreviewLevelBackground = stylePreviewLevel:CreateTexture(nil, "BACKGROUND")
    stylePreviewLevelBackground:SetAllPoints()
    local stylePreviewLevelSelection = stylePreviewLevel:CreateTexture(nil, "OVERLAY", nil, 1)
    stylePreviewLevelSelection:SetPoint("TOPLEFT", -3, 4)
    stylePreviewLevelSelection:SetPoint("BOTTOMRIGHT", 3, -4)
    local stylePreviewLevelText = stylePreviewLevel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stylePreviewLevelText:SetPoint("CENTER")
    stylePreviewLevelText:SetText("1")
    stylePreviewLevelText:SetTextColor(0.35, 1, 0.25, 1)

    sample.Refresh = function()
        if addon.ResetDevNameplateStylePreview then addon:ResetDevNameplateStylePreview(stylePreviewBar,stylePreviewName) end
        if addon.ResetJundiesStylePreview then addon:ResetJundiesStylePreview(stylePreviewBar) end
        local atd = addon:IsATDStyle()
        local thinID = Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.Thin
        local thin = not atd and thinID ~= nil and addon:GetNameplateStyleFamily() == thinID
        local geometry = GetStylePreviewGeometry()
        local setup, constants = NamePlateSetupOptions or {}, NamePlateConstants or {}
        local borderOffsets = constants.SELECTED_BORDER_OFFSETS
            or {topLeftX=-3, topLeftY=2, bottomRightX=0, bottomRightY=2}
        local width, height = geometry.width, geometry.height

        -- Keep a single transform for the complete sample; independent bar, font,
        -- and badge multipliers distort the native layout's proportions.
        local desiredScale = GetStylePreviewRenderScale(stylePreview:GetEffectiveScale())

        -- Forever's visible badge is PlayerLevelDiffFrame, not the smaller legacy
        -- LevelFrame whose levelIconWidth/Height are used by the quest editor.
        local levelWidth, levelHeight, levelGap = geometry.levelWidth, geometry.levelHeight, geometry.levelGap
        local showLevel = not atd and (addon:GetCompatibilityMode() or addon:GetMobLevelEnabled())
        local extraWidth = showLevel and levelGap + levelWidth or 0

        stylePreviewBar:ClearAllPoints()
        stylePreviewBar:SetPoint("CENTER", stylePreviewContent, "CENTER", -extraWidth / 2, 0)
        stylePreviewBar:SetSize(width, height)
        stylePreviewBar:SetStatusBarColor(0.72, 0.74, 0.04, 1)

        stylePreviewFill:SetTexture(WHITE)
        stylePreviewFill:SetVertexColor(0.72, 0.74, 0.04, 1)
        stylePreviewBackground:SetTexture(WHITE)
        stylePreviewBackground:SetVertexColor(0.035, 0.035, 0.035, 1)
        stylePreviewSelection:SetTexture(nil)
        stylePreviewLevelSelection:SetTexture(nil)
        stylePreviewLevelBackground:SetTexture(nil)
        stylePreviewBar:SetBackdropColor(0.015, 0.015, 0.015, 1)
        stylePreviewBar:SetBackdropBorderColor(0.82, 0.64, 0.20, 1)
        stylePreviewLevel:SetBackdropColor(0.01, 0.01, 0.01, 1)
        stylePreviewLevel:SetBackdropBorderColor(0.82, 0.64, 0.20, 1)
        stylePreviewBackground:ClearAllPoints()
        stylePreviewSelection:ClearAllPoints()
        if not atd then
            -- These are the same background and selection anchors as Forever's
            -- NamePlateUnitFrameMixin. The background includes the dark rim.
            stylePreviewBackground:SetPoint("TOPLEFT", stylePreviewBar, "TOPLEFT", -2, 3)
            stylePreviewBackground:SetPoint("BOTTOMRIGHT", stylePreviewBar, "BOTTOMRIGHT", 6, -6)
            if SetPreviewAtlas(stylePreviewFill, "UI-HUD-CoolDownManager-Bar") then
                stylePreviewFill:SetVertexColor(0.72, 0.74, 0.04, 1)
            end
            if SetPreviewAtlas(stylePreviewBackground, "UI-HUD-CoolDownManager-Bar-BG") then
                stylePreviewBackground:SetVertexColor(1, 1, 1, 1)
                stylePreviewBar:SetBackdropColor(0, 0, 0, 0)
                stylePreviewBar:SetBackdropBorderColor(0, 0, 0, 0)
            end
            stylePreviewSelection:SetPoint("TOPLEFT", stylePreviewBackground, "TOPLEFT", borderOffsets.topLeftX, borderOffsets.topLeftY)
            stylePreviewSelection:SetPoint("BOTTOMRIGHT", stylePreviewBackground, "BOTTOMRIGHT", borderOffsets.bottomRightX, borderOffsets.bottomRightY)
            if SetPreviewAtlas(stylePreviewSelection, constants.SELECTED_BORDER_ATLAS or "UI-HUD-CoolDownManager-Selected-yellow") then
                stylePreviewSelection:SetVertexColor(1, 1, 1, 1)
            end
            if SetPreviewAtlas(stylePreviewLevelBackground, "ui-hud-nameplates-levelindicator") then
                stylePreviewLevel:SetBackdropColor(0, 0, 0, 0)
                stylePreviewLevel:SetBackdropBorderColor(0, 0, 0, 0)
            end
            if SetPreviewAtlas(stylePreviewLevelSelection, "ui-hud-nameplates-levelindicator-rectangle-selected") then
                stylePreviewLevelSelection:SetVertexColor(1, 1, 1, 1)
            end
        else
            stylePreviewBar:SetBackdropColor(0.015, 0.015, 0.015, 1)
            stylePreviewBar:SetBackdropBorderColor(0.92, 0.92, 0.92, 1)
            stylePreviewBackground:SetPoint("TOPLEFT", 1, -1)
            stylePreviewBackground:SetPoint("BOTTOMRIGHT", -1, 1)
        end

        local plateFont = SystemFont_NamePlate_Outlined or SystemFont_NamePlate or GameFontHighlight
        SetPreviewFont(stylePreviewName, plateFont, addon:GetMobNameFontSize())
        local nameOn = not addon.GetNameplateNameEnabled or addon:GetNameplateNameEnabled()
        stylePreviewName:SetShown(nameOn)
        SetPreviewFont(stylePreviewPercent, plateFont, addon:GetHealthPercentFontSize())
        SetPreviewFont(stylePreviewValue, plateFont, addon:GetHealthValueFontSize())
        SetPreviewFont(stylePreviewLevelText, SystemFont_NamePlateLevel or GameFontHighlightSmall,
            geometry.levelFontSize > 0 and geometry.levelFontSize or 10)

        stylePreviewName:ClearAllPoints()
        stylePreviewPercent:ClearAllPoints()
        stylePreviewValue:ClearAllPoints()
        local percentOn, valueOn = addon:GetNameplateHealthInfoFlags()
        stylePreviewPercent:SetShown(percentOn)
        stylePreviewValue:SetShown(valueOn)
        stylePreviewPercent:SetWidth(atd and addon:GetHealthPercentFontSize() * 3.5 + 2 or 0)
        stylePreviewValue:SetWidth(atd and addon:GetHealthValueFontSize() * 5.5 + 2 or 0)
        stylePreviewPercent:SetPoint("RIGHT", stylePreviewBar, "RIGHT", atd and -2 or -4, 0)
        if percentOn then stylePreviewValue:SetPoint("RIGHT", stylePreviewPercent, "LEFT", atd and -4 or -2, 0)
        else stylePreviewValue:SetPoint("RIGHT", stylePreviewBar, "RIGHT", atd and -2 or -4, 0) end
        if thin then
            stylePreviewName:SetJustifyH("CENTER")
            stylePreviewName:SetPoint("BOTTOM", stylePreviewBar, "TOP", 0,
                PreviewNumber(setup.healthBarToNameAboveSpacing, 2))
            stylePreviewPercent:SetPoint("RIGHT", stylePreviewBar, "RIGHT", -5, 0)
        else
            stylePreviewName:SetJustifyH("LEFT")
            stylePreviewName:SetPoint("LEFT", stylePreviewBar, "LEFT", atd and 2 or 4, 0)
            if valueOn then stylePreviewName:SetPoint("RIGHT", stylePreviewValue, "LEFT", atd and -4 or -2, 0)
            elseif percentOn then stylePreviewName:SetPoint("RIGHT", stylePreviewPercent, "LEFT", atd and -4 or -2, 0)
            else stylePreviewName:SetPoint("RIGHT", stylePreviewBar, "RIGHT", atd and -2 or -4, 0) end
        end

        stylePreviewLevel:ClearAllPoints()
        stylePreviewLevel:SetSize(levelWidth, levelHeight)
        stylePreviewLevel:SetPoint("LEFT", stylePreviewBar, "RIGHT", levelGap,
            geometry.level and geometry.level.y or 0)
        stylePreviewLevelSelection:ClearAllPoints()
        stylePreviewLevelSelection:SetPoint("TOPLEFT", -3,
            geometry.level and geometry.level.selectionTop or 4)
        stylePreviewLevelSelection:SetPoint("BOTTOMRIGHT", 3, -4)
        stylePreviewLevel:SetShown(showLevel)

        -- Include border artwork, the whole badge, and above-bar text in the
        -- fitting bounds. Scale the complete sample uniformly, never the bar alone.
        -- These strings contain only our sample text and belong to detached,
        -- addon-owned frames. Their real line height is safe to measure. The old
        -- 1.5x estimate reserved empty space above Thin and pushed its bar down.
        local nameHeight = nameOn and PreviewNumber(stylePreviewName:GetStringHeight(), addon:GetMobNameFontSize()) or 0
        local healthHeight = math.max(
            percentOn and PreviewNumber(stylePreviewPercent:GetStringHeight(), addon:GetHealthPercentFontSize()) or 0,
            valueOn and PreviewNumber(stylePreviewValue:GetStringHeight(), addon:GetHealthValueFontSize()) or 0)
        local fontHeight = math.max(thin and 0 or nameHeight, healthHeight)
        local top = math.max(height / 2 + 6, fontHeight / 2 + 1)
        local bottom = top
        if showLevel and geometry.level then
            top = math.max(top, geometry.level.y + levelHeight / 2 + geometry.level.selectionTop)
            bottom = math.max(bottom, levelHeight / 2 - geometry.level.y + 4)
        end
        if thin and nameOn then
            top = math.max(top, height / 2 + PreviewNumber(setup.healthBarToNameAboveSpacing, 2)
                + nameHeight + 1)
        end
        -- Center the visible artwork, including its asymmetric borders. The native
        -- bar's selection reaches farther left than the badge's border reaches
        -- right; centering just the bar and badge leaves a small leftward offset.
        local left, right = -width / 2 - 1, width / 2 + 1
        if not atd then
            left = -width / 2 + math.min(-2, -2 + borderOffsets.topLeftX)
            right = width / 2 + math.max(6, 6 + borderOffsets.bottomRightX, showLevel and extraWidth + 3 or 0)
        end
        local draftBounds=addon.RenderDevNameplateStylePreview and addon:RenderDevNameplateStylePreview(
            stylePreviewBar,stylePreviewBackground,stylePreviewName,stylePreviewPercent,stylePreviewValue)
        if draftBounds then
            left,right,top,bottom=draftBounds.left,draftBounds.right,draftBounds.top,draftBounds.bottom
        elseif addon.IsJundiesStyle and addon:IsJundiesStyle() then
            addon:ApplyJundiesStylePreview(stylePreviewBar,stylePreviewBackground,stylePreviewName,stylePreviewPercent,stylePreviewValue)
        end
        if not draftBounds and addon.ApplyNameplateTextAlignment then
            addon:ApplyNameplateTextAlignment(stylePreviewBar,stylePreviewPercent,stylePreviewValue,
                percentOn,valueOn,not thin and stylePreviewName or nil)
            if thin then addon:ApplyNameplateNameAlignment(stylePreviewName,stylePreviewBar,true) end
        end
        if sample.ExtendBounds then left,right,top,bottom=sample.ExtendBounds(left,right,top,bottom) end
        local fitScale, fraction = addon:FitNameplatePreviewScale(desiredScale,
            math.max(width + extraWidth + 12, right - left + 4), top + bottom,
            PreviewNumber(stylePreviewViewport:GetWidth(), 464),
            PreviewNumber(stylePreviewViewport:GetHeight(), 52))
        -- Optional presentation reduction for the Style page only. Scale the
        -- entire fitted sample together, without changing saved nameplate size.
        fitScale, fraction = fitScale * (displayScale or 1), fraction * (displayScale or 1)
        stylePreviewContent:SetScale(fitScale)
        stylePreviewBar:ClearAllPoints()
        stylePreviewBar:SetPoint("CENTER", stylePreviewContent, "CENTER", -(left + right) / 2, (bottom - top) / 2)
        stylePreviewCaption:SetText(fraction < 0.995
            and string.format("Preview (%d%% scale)", math.floor(fraction * 100 + 0.5)) or "Preview")
        sample.geometry = geometry
        sample.bounds = {left=left, right=right, top=top, bottom=bottom}
    end
    sample.content, sample.bar = stylePreviewContent, stylePreviewBar
    sample.name, sample.percent, sample.level = stylePreviewName, stylePreviewPercent, stylePreviewLevel
    sample.value = stylePreviewValue
    sample.selection, sample.levelSelection = stylePreviewSelection, stylePreviewLevelSelection
    return sample
end
local styleSample = CreateNameplateSample(stylePreview, stylePreviewViewport, stylePreviewCaption, 0.75)
stylePreview.Refresh = function() styleSample:Refresh() end

local styleTools = CreateFrame("Frame", nil, styleView, "BackdropTemplate")
styleTools:SetSize(480, 154)
styleTools:SetPoint("TOPLEFT", 44, -254)
Backdrop(styleTools, {0.035, 0.043, 0.055, 1}, BORDER)
local shapeGroup = CreateFrame("Frame", nil, styleTools)
shapeGroup:SetAllPoints(styleTools)
local textGroup = CreateFrame("Frame", nil, styleTools)
textGroup:SetAllPoints(styleTools)
local styleTabButtons = {}
local function ShowStyleTab(selected)
    shapeGroup:SetShown(selected == "shape")
    textGroup:SetShown(selected == "text")
    styleTools:SetHeight(selected == "text" and 184 or 154)
    for key, button in pairs(styleTabButtons) do
        StyleButton(button, key == selected)
        button.label:SetTextColor(unpack(key == selected and GOLD or TEXT))
        button:SetScript("OnLeave", function(self) StyleButton(self, key == selected) end)
    end
end
for index, tab in ipairs({{key="shape",label="Size & Shape"},{key="text",label="Text Size"}}) do
    local key = tab.key
    local button = Button(styleView, tab.label, 118, 24)
    button:SetPoint("TOPLEFT", index == 1 and 44 or 168, -218)
    button:SetScript("OnClick", function() ShowStyleTab(key) end)
    styleTabButtons[key] = button
end
ShowStyleTab("shape")

-- Normal controls remain available for local creator designs as well. The
-- optional bridge edits their saved fields; public builds use the usual APIs.
local styleOptions={}
function styleOptions.Get(key,fallback)
    local value=addon.GetDevNameplateStyleOption and addon:GetDevNameplateStyleOption(key)
    if value~=nil then return value end
    return fallback()
end
function styleOptions.Set(key,value,fallback)
    if addon.SetDevNameplateStyleOption then addon:SetDevNameplateStyleOption(key,value) end
    fallback(value)
end
function styleOptions.Health()
    local percent,value=addon:GetNameplateHealthInfoFlags()
    return styleOptions.Get("percentEnabled",function() return percent end),
        styleOptions.Get("valueEnabled",function() return value end)
end
function styleOptions.Cast()
    local result={}
    for key,value in pairs(addon:GetATDCastbarSettings()) do
        result[key]=styleOptions.Get("cast."..key,function() return value end)
    end
    return result
end
function styleOptions.SetCast(key,value)
    styleOptions.Set("cast."..key,value,function(v) addon:SetATDCastbarSetting(key,v) end)
end
local styleSliders = {
    SliderRow(shapeGroup, "Nameplate size", 16, -14, 448, 1, 5, 1,
        function() return addon:GetNameplateSize() end, function(v) styleOptions.Set("size",v,function(n) addon:SetNameplateSize(n) end) end, ""),
    SliderRow(textGroup, "Enemy name size", 16, -14, 186, 5, 18, 1,
        function() return styleOptions.Get("name",function() return addon:GetMobNameFontSize() end) end, function(v) styleOptions.Set("name",v,function(n) addon:SetMobNameFontSize(n) end) end, " px"),
    SliderRow(textGroup, "Health percentage size", 16, -70, 186, 5, 18, 1,
        function() return styleOptions.Get("percent",function() return addon:GetHealthPercentFontSize() end) end, function(v) styleOptions.Set("percent",v,function(n) addon:SetHealthPercentFontSize(n) end) end, " px"),
    SliderRow(textGroup, "Health value size", 16, -126, 186, 5, 18, 1,
        function() return styleOptions.Get("value",function() return addon:GetHealthValueFontSize() end) end, function(v) styleOptions.Set("value",v,function(n) addon:SetHealthValueFontSize(n) end) end, " px"),
    SliderRow(shapeGroup, "Width", 16, -82, 198, 50, 150, 1,
        function() return styleOptions.Get("width",function() return addon:GetNameplateWidthPercent() end) end, function(v) styleOptions.Set("width",v,function(n) addon:SetNameplateWidthPercent(n) end) end, "%", true),
    SliderRow(shapeGroup, "Height", 266, -82, 198, 50, 150, 1,
        function() return styleOptions.Get("height",function() return addon:GetNameplateHeightPercent() end) end, function(v) styleOptions.Set("height",v,function(n) addon:SetNameplateHeightPercent(n) end) end, "%", true),
}
styleSliders[1]:AddNotches({1, 2, 3, 4, 5})
styleSliders[5]:AddNotches({50, 100, 150})
styleSliders[6]:AddNotches({50, 100, 150})
for _, control in ipairs(styleSliders) do
    control.OnUserValueChanged = function() stylePreview:Refresh() end
end
local showEnemyName = Toggle(textGroup, "Enemy Name", 334, -36,
    function() return addon:GetNameplateNameEnabled() end,
    function(enabled) addon:SetNameplateNameEnabled(enabled) end,107)
local showHealthPercent = Toggle(textGroup, "Health Percentage", 334, -92,
    function() local percent = styleOptions.Health(); return percent end,
    function(enabled) styleOptions.Set("percentEnabled",enabled,function(v) addon:SetNameplateHealthInfoEnabled("percent", v) end) end, 107)
local showHealthValue = Toggle(textGroup, "Health Value", 334, -148,
    function() local _, value = styleOptions.Health(); return value end,
    function(enabled) styleOptions.Set("valueEnabled",enabled,function(v) addon:SetNameplateHealthInfoEnabled("value", v) end) end, 107)
local alignmentSelectors = {}
for index, item in ipairs({{kind="name",label="Enemy name alignment"},{kind="percent",label="Percentage alignment"},{kind="value",label="Value alignment"}}) do
    local kind = item.kind
    local y = -14-(index-1)*56
    Font(textGroup,"GameFontHighlightSmall","Alignment",222,y,96)
    local selector = Selector(textGroup,item.label,y-18,function()
        return {{text="Default",value="DEFAULT"},{text="Left",value="LEFT"},
            {text="Center",value="CENTER"},{text="Right",value="RIGHT"}}
    end,function() return addon:GetNameplateTextAlignment(kind) end,
        function(v) addon:SetNameplateTextAlignment(kind,v) end,false,96)
    selector:ClearAllPoints(); selector:SetPoint("TOPLEFT",222,y-18)
    selector.useModernMenu = true
    alignmentSelectors[#alignmentSelectors+1] = selector
end
local disableMobLevel = Toggle(shapeGroup, "Disable Mob Level", 44, -424,
    function() return not addon:GetMobLevelEnabled() end,
    function(disabled) addon:SetMobLevelEnabled(not disabled) end, 220)
disableMobLevel:ClearAllPoints()
disableMobLevel:SetPoint("TOPLEFT", styleTools, "BOTTOMLEFT", 0, -16)
disableMobLevel.label:SetWidth(0)
disableMobLevel.label:SetWordWrap(false)
addon:CreateOptionsNewFeatureTag(disableMobLevel, disableMobLevel.label)
local styleReset = Button(styleView, "Reset", 66, 24)
styleReset:SetPoint("TOPLEFT", 458, -218)
styleReset:SetScript("OnClick", function()
    local size, name, percent, value = addon.defaults.appearance.size, addon.defaults.mobName.fontSize,
        addon.defaults.healthText.percentSize, addon.defaults.healthText.valueSize
    if addon:IsATDStyle() then size, name, percent, value = addon:GetATDStyleDefaults() end
    styleOptions.Set("size",size,function(v) addon:SetNameplateSize(v) end)
    styleOptions.Set("name",name,function(v) addon:SetMobNameFontSize(v) end)
    styleOptions.Set("percent",percent,function(v) addon:SetHealthPercentFontSize(v) end)
    styleOptions.Set("value",value,function(v) addon:SetHealthValueFontSize(v) end)
    if addon.SetDevNameplateStyleOption then
        local width,height=addon:GetNameplateDimensionDefaults()
        addon:SetDevNameplateStyleOption("width",width); addon:SetDevNameplateStyleOption("height",height)
    end
    addon:ResetNameplateDimensions()
    if addon.SetNameplateTextAlignment then
        addon:SetNameplateTextAlignment("name","DEFAULT")
        addon:SetNameplateTextAlignment("percent","DEFAULT")
        addon:SetNameplateTextAlignment("value","DEFAULT")
    end
    refreshAll()
end)

-- Castbar ----------------------------------------------------------------
local castView = CreateView("castbar", "Castbar Style", "")
local castPreview = PreviewCard(castView, 116, -134)
local castPreviewCaption = Font(castView, "GameFontDisableSmall", "Preview", 44, -119, 240)
castPreviewCaption:SetTextColor(unpack(MUTED))
local castViewport = CreateFrame("Frame", nil, castPreview)
castViewport:SetPoint("TOPLEFT", 8, -6)
castViewport:SetPoint("BOTTOMRIGHT", -8, 6)
if castViewport.SetClipsChildren then castViewport:SetClipsChildren(true) end
local castPlate = CreateNameplateSample(castPreview, castViewport, castPreviewCaption)
addon:CreateCastbarPreview(castPreview, castViewport, castPreviewCaption, castPlate)
local castModes = {}
for index, mode in ipairs({{text="Interruptible",protected=false},{text="Protected",protected=true}}) do
    local protected = mode.protected
    local button = Button(castView, mode.text, index == 1 and 92 or 76, 20)
    button:SetPoint("TOPLEFT", index == 1 and 350 or 448, -112)
    button:SetScript("OnClick", function()
        castPreview:SetProtectedSample(protected)
        for _, other in ipairs(castModes) do StyleButton(other, other.btpProtected == protected) end
    end)
    button.btpProtected = protected
    button:SetScript("OnLeave", function(self)
        StyleButton(self, self.btpProtected == castPreview.btpCastbarPreview.protected)
    end)
    StyleButton(button, not protected)
    castModes[#castModes + 1] = button
end

local castSelector = Selector(castView, "Style", -66, function()
    if addon:IsATDStyle() then return {{text=addon.IsJundiesStyle and addon:IsJundiesStyle() and "Jundies Custom" or "ATD Custom",value="custom"},{text="Hidden",value="hidden"}} end
    local family, styles = addon:GetNameplateStyleFamily(), Enum.NamePlateStyle
    if family ~= styles.Modern and family ~= styles.Thin then return {{text="Blizzard", value="native", disabled=true}} end
    return {{text="Skinny",value="skinny",disabled=InCombatLockdown()},{text="Thick",value="thick",disabled=InCombatLockdown()}}
end, function()
    if addon:IsATDStyle() then return styleOptions.Cast().enabled == false and "hidden" or "custom" end
    local family, styles = addon:GetNameplateStyleFamily(), Enum.NamePlateStyle
    if family ~= styles.Modern and family ~= styles.Thin then return "native" end
    return addon:GetCastbarThick() and "thick" or "skinny"
end, function(value)
    if addon:IsATDStyle() then styleOptions.SetCast("enabled", value ~= "hidden")
    else addon:SetCastbarThick(value == "thick") end
end, true)

local showCastName = Toggle(castView, "Spell name", 44, -270,
    function() return styleOptions.Cast().showName ~= false end,
    function(v) styleOptions.SetCast("showName", v) end, 120)
local showCastTime = Toggle(castView, "Cast time", 210, -270,
    function() return styleOptions.Cast().showTime ~= false end,
    function(v) styleOptions.SetCast("showTime", v) end, 120)
local castSliders = {
    SliderRow(castView, "Width", 44, -306, 210, 90, 220, 1,
        function() return styleOptions.Cast().width end, function(v) styleOptions.SetCast("width", v) end, " px"),
    SliderRow(castView, "Height", 300, -306, 210, 8, 24, 1,
        function() return styleOptions.Cast().height end, function(v) styleOptions.SetCast("height", v) end, " px"),
    SliderRow(castView, "Vertical position", 44, -352, 210, -20, 10, 1,
        function() return styleOptions.Cast().offsetY end, function(v) styleOptions.SetCast("offsetY", v) end, " px"),
    SliderRow(castView, "Spell-name size", 300, -352, 210, 7, 18, 1,
        function() return styleOptions.Cast().nameSize end, function(v) styleOptions.SetCast("nameSize", v) end, " px"),
    SliderRow(castView, "Cast-time size", 44, -398, 210, 7, 18, 1,
        function() return styleOptions.Cast().timeSize end, function(v) styleOptions.SetCast("timeSize", v) end, " px"),
}
for _, control in ipairs(castSliders) do
    control.OnUserValueChanged = function() castPreview:Refresh() end
end
local castColors = CreateFrame("Frame", nil, castView)
castColors:SetSize(210, 42)
castColors:SetPoint("TOPLEFT", 300, -398)
local castColorLabel = Font(castColors, "GameFontHighlightSmall", "Colors", 0, 0, 210)
local function CastColorButton(text, x, key)
    local button = Button(castColors, text, 100, 22)
    button:SetPoint("TOPLEFT", x, -18)
    button.swatch = button:CreateTexture(nil, "OVERLAY")
    button.swatch:SetTexture(WHITE)
    button.swatch:SetSize(12, 12)
    button.swatch:SetPoint("LEFT", 8, 0)
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", 26, 0)
    button:SetScript("OnClick", function()
        OpenColorPicker(styleOptions.Cast()[key], function(color)
            styleOptions.SetCast(key, color)
        end)
    end)
    button.Refresh = function(self)
        local color = styleOptions.Cast()[key]
        self.swatch:SetVertexColor(color[1], color[2], color[3], 1)
    end
    return button
end
local castInterruptibleColor = CastColorButton("Cast", 0, "interruptibleColor")
local castProtectedColor = CastColorButton("Protected", 110, "protectedColor")
local castReset = Button(castView, "Reset", 66, 26)
castReset:SetPoint("TOPRIGHT", -18, -17)
castReset:SetScript("OnClick", function()
    if addon:ResetATDCastbarSettings() ~= false and addon.SetDevNameplateStyleOption then
        for key,value in pairs(addon:GetATDCastbarSettings()) do addon:SetDevNameplateStyleOption("cast."..key,value) end
    end
    refreshAll()
end)

-- CVar bitfields ---------------------------------------------------------
local function EnumIndex(tableName, key, fallback)
    local enumTable = Enum and Enum[tableName]
    return enumTable and enumTable[key] or fallback
end

local function BitForIndex(index) return index and index > 0 and (2 ^ (index - 1)) or 0 end
local function GetMask(name)
    return addon:GetNameplateBitfieldMask(name)
end
local function GetCVarNumber(name, fallback)
    local value = pendingCVars[name]
    if value == nil then value = GetCVar(name) end
    return tonumber(value) or fallback
end
local function SetCVarValue(name, value)
    pendingCVars[name] = value
    addon:SetNameplateCVar(name, value)
end
local function HasMaskIndex(name, index)
    local bitValue = BitForIndex(index)
    return bitValue > 0 and math.floor(GetMask(name) / bitValue) % 2 == 1
end
local function SetMaskIndex(name, index, enabled)
    addon:SetNameplateBitfieldIndex(name, index, enabled)
end
local function SetMask(name, mask)
    addon:SetNameplateBitfieldMask(name, mask)
end

local castNativeGroup = CreateFrame("Frame", nil, castView)
castNativeGroup:SetAllPoints(castView)
local castInformation = CreateFrame("Frame", nil, castNativeGroup, "BackdropTemplate")
castInformation:SetSize(480, 32)
castInformation:SetPoint("TOPLEFT", 44, -270)
Backdrop(castInformation)
castInformation.label = Font(castInformation, "GameFontHighlightSmall", "Cast Bar Information", 12, -10)
addon:CreateOptionsNewFeatureTag(castInformation, castInformation.label)
local castInformationButton = Button(castInformation, "", 254, 24)
HighlightSelectorButton(castInformationButton)
castInformationButton:SetPoint("RIGHT", -8, 0)
castInformationButton.label:ClearAllPoints()
castInformationButton.label:SetPoint("LEFT", 10, 0)
castInformationButton.label:SetPoint("RIGHT", -25, 0)
castInformationButton.label:SetJustifyH("LEFT")
castInformationButton.label:SetWordWrap(false)
local castInfoArrow = Font(castInformationButton, "GameFontNormal", "v", 238, -6)
castInfoArrow:SetTextColor(unpack(GOLD))
local castInformationChoices = {
    {key="SpellName", index=1, text=UNIT_NAMEPLATES_CAST_BAR_DISPLAY_SPELL_NAME or "Spell Name"},
    {key="SpellIcon", index=2, text=UNIT_NAMEPLATES_CAST_BAR_DISPLAY_SPELL_ICON or "Spell Icon"},
    {key="SpellTarget", index=3, text=UNIT_NAMEPLATES_CAST_BAR_DISPLAY_SPELL_TARGET or "Spell Target"},
    {key="HighlightImportantCasts", index=4, text=UNIT_NAMEPLATES_CAST_BAR_DISPLAY_HIGHLIGHT_IMPORTANT_CASTS or "Highlight Important Casts"},
    {key="HighlightWhenCastTarget", index=5, text=UNIT_NAMEPLATES_CAST_BAR_DISPLAY_HIGHLIGHT_WHEN_CAST_TARGET or "Flash When Targeted by Enemy"},
}
castInformationButton:SetScript("OnClick", function(self)
    UIDropDownMenu_Initialize(menuFrame, function(_, level)
        if level ~= 1 then return end
        for _, choice in ipairs(castInformationChoices) do
            local item = choice
            local index = EnumIndex("NamePlateCastBarDisplay", item.key, item.index)
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.isNotRadio, info.keepShownOnClick = item.text, true, true
            info.disabled = item.key == "SpellTarget" and addon:GetTargetNamesEnabled()
            if info.disabled then
                info.tooltipTitle = item.text
                info.tooltipText = "Disable BTP's Target of Target to use Blizzard's Spell Target label."
                info.tooltipOnButton = true
            end
            info.checked = function() return HasMaskIndex("nameplateCastBarDisplay", index) end
            info.func = function()
                if item.key == "SpellTarget" and addon:GetTargetNamesEnabled() then return end
                SetMaskIndex("nameplateCastBarDisplay", index, not HasMaskIndex("nameplateCastBarDisplay", index))
                refreshAll()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")
    ToggleDropDownMenu(1, nil, menuFrame, self, 0, 0)
end)
local castNativeNote = Font(castNativeGroup, "GameFontDisableSmall", "", 44, -316, 480)
castNativeNote:SetTextColor(unpack(MUTED))
castInformation.Refresh = function()
    local selected = {}
    for _, choice in ipairs(castInformationChoices) do
        if HasMaskIndex("nameplateCastBarDisplay", EnumIndex("NamePlateCastBarDisplay", choice.key, choice.index)) then
            selected[#selected + 1] = choice.text
        end
    end
    castInformationButton.label:SetText(#selected == 0 and (NONE or "None")
        or (#selected <= 2 and table.concat(selected, ", ") or string.format("%d Selected", #selected)))
    castNativeNote:SetText(addon:HasPendingNameplateBitfield("nameplateCastBarDisplay")
        and "Changes apply when combat ends." or "")
end

-- Enemy debuffs ----------------------------------------------------------
local debuffUI = {
    CreateView=CreateView, Font=Font, PreviewCard=PreviewCard,
    CreateNameplateSample=CreateNameplateSample, Backdrop=Backdrop, Button=Button,
    HighlightSelectorButton=HighlightSelectorButton,
    Toggle=Toggle, SliderRow=SliderRow, Selector=Selector, EnumIndex=EnumIndex, menuFrame=menuFrame,
    GetNumber=GetCVarNumber, SetNumber=SetCVarValue, SetControlEnabled=SetControlEnabled,
    HasPendingNumber=function(name) return InCombatLockdown() and pendingCVars[name] ~= nil end,
    Refresh=function() if refreshAll then refreshAll() end end,
}
-- An in-panel detail page, reached through the Style button rather than a
-- separate window or an extra sidebar category.
local liquidView=CreateView("liquidThreat","Liquid Threat Animation","")
local liquidOptions=addon:CreateLiquidThreatOptions(liquidView,debuffUI)
local liquidButton=Button(shapeGroup,"Liquid Threat Animation",210,26)
liquidButton:SetPoint("TOPLEFT",styleTools,"BOTTOMLEFT",0,-18)
HighlightSelectorButton(liquidButton)
addon:CreateOptionsNewFeatureTag(shapeGroup,liquidButton,"LEFT","RIGHT",6,0)
liquidButton:SetScript("OnClick",function() addon:ShowModernNameplateView("liquidThreat") end)
local pveDebuffs = addon:CreateEnemyDebuffOptions(debuffUI, "pve")
local pvpDebuffs = addon:CreateEnemyDebuffOptions(debuffUI, "pvp")
local pveView, pvpView = pveDebuffs.view, pvpDebuffs.view

-- Both aura contexts share one sidebar destination; switch context in place.
for _, entry in ipairs({{view=pveView, key="pve"}, {view=pvpView, key="pvp"}}) do
    for index, context in ipairs({{key="pve", text="PvE"}, {key="pvp", text="PvP"}}) do
        local key = context.key
        local tab = Button(entry.view, context.text, 52, 24)
        tab:SetPoint("TOPLEFT", 414 + (index - 1) * 58, -100)
        StyleButton(tab, entry.key == key)
        tab.label:SetTextColor(unpack(entry.key == key and GOLD or TEXT))
        tab:SetScript("OnLeave", function(self) StyleButton(self, entry.key == key) end)
        tab:SetScript("OnClick", function() addon:ShowModernNameplateView(key) end)
    end
end

-- Target of Target -------------------------------------------------------
local targetView = CreateView("target", "Target of Target", "")
local targetOptions = addon:CreateTargetOfTargetOptions(targetView, {
    Font=Font, Backdrop=Backdrop, Button=Button, Toggle=Toggle, SliderRow=SliderRow,
    SetControlEnabled=SetControlEnabled, CreateNameplateSample=CreateNameplateSample,
    PreviewCard=PreviewCard,
})

-- Quest icons ------------------------------------------------------------
local questIconsView=CreateView("questIcons","Quest Icons","Quest markers are independent of quest colors.")
local questIconOptions=addon:CreateQuestIconOptions(questIconsView,{
    Font=Font,Backdrop=Backdrop,Button=Button,Toggle=Toggle,SliderRow=SliderRow,
    CreateNameplateSample=CreateNameplateSample,PreviewCard=PreviewCard,
})

-- Advanced ---------------------------------------------------------------
local advancedView = CreateView("advanced", "Compatibility & Blizzard Settings", "Direct mirrors of Blizzard controls plus addon ownership.")
local compatibilityCard = CreateFrame("Frame", nil, advancedView, "BackdropTemplate")
compatibilityCard:SetSize(480, 64)
compatibilityCard:SetPoint("TOPLEFT", 44, -66)
Backdrop(compatibilityCard)
local compatibilityToggle = Toggle(compatibilityCard, "Compatibility Mode", 14, -15,
    function() return addon:GetCompatibilityMode() end,
    function(v) addon:SetCompatibilityMode(v) end, 220)
local compatibilityNote = Font(compatibilityCard, "GameFontDisableSmall",
    "Starts with threat text only. Other BTP features are optional.", 14, -39, 450)
compatibilityNote:SetTextColor(unpack(MUTED))
local compatibilityFeaturesButton = Button(compatibilityCard,"Optional Features",142,24)
compatibilityFeaturesButton:SetPoint("TOPRIGHT",-14,-10)
compatibilityFeaturesButton:SetScript("OnClick",function() addon:ShowModernNameplateView("compatibility") end)
local compatibilityView = CreateView("compatibility","Compatibility Features","")
local compatibilityBack = Button(compatibilityView,"Back",90,24)
compatibilityBack:SetPoint("TOPRIGHT",-20,-14)
compatibilityBack:SetScript("OnClick",function() addon:ShowModernNameplateView("advanced") end)
local compatibilityInfo = Font(compatibilityView,"GameFontDisableSmall",
    "Choose which BTP features to add alongside your other nameplate addon.\nStyle, size and text replacement stay with your other addon.",44,-76,480)
compatibilityInfo:SetHeight(38)
local compatibilityControls = {}
for index, feature in ipairs({
    {"targetNames","Target of Target"},{"questColor","Quest Colors"},
    {"questIcons","Quest Icons"},{"comboPoints","Combo Points"},
    {"threatColors","Threat Colors"},{"playerColors","Player Colors"},
    {"brightness","Non-Target Brightness"},{"threatFlash","Aggro Flash"},
    {"enemyDebuffs","Enemy Debuffs"},
}) do
    local key = feature[1]
    local control = Toggle(compatibilityView,feature[2],index%2==1 and 44 or 300,
        -136-math.floor((index-1)/2)*46,function()
            return addon:GetCompatibilityFeatureState(key)
        end,function(v) addon:SetCompatibilityFeatureEnabled(key,v) end,220)
    compatibilityControls[#compatibilityControls+1]=control
end

SectionLabel(advancedView, "Blizzard behavior", -146)
local allPersonal = Toggle(advancedView, "Show all personal auras", 44, -168,
    function() return GetCVarNumber("nameplateShowAllPersonalAuras", 0) == 1 end,
    function(v) SetCVarValue("nameplateShowAllPersonalAuras", v and 1 or 0) end, 220)
local enemyStacking = Toggle(advancedView, "Stack enemy nameplates", 300, -168,
    function() return HasMaskIndex("nameplateStackingTypes", EnumIndex("NamePlateStackType", "Enemy", 1)) end,
    function(v) SetMaskIndex("nameplateStackingTypes", EnumIndex("NamePlateStackType", "Enemy", 1), v) end, 220)
local recommendedBoth = Button(advancedView, "Enable recommended Blizzard auras", 238, 24)
recommendedBoth:SetPoint("TOPLEFT", 44, -206)
recommendedBoth:SetScript("OnClick", function()
    SetMask("nameplateEnemyNpcAuraDisplay", 6)
    SetMask("nameplateEnemyPlayerAuraDisplay", 6)
    refreshAll()
end)
local combatMessage = Font(advancedView, "GameFontDisableSmall", "", 44, -248, 480)
combatMessage:SetTextColor(unpack(MUTED))

local legacyReturn = Button(nameplatesPage, "Use Modern Layout", 140, 24)
legacyReturn:SetPoint("TOPRIGHT", contentRoot, "TOPRIGHT", -35, -108)
legacyReturn:SetFrameLevel(nameplatesPage:GetFrameLevel() + 31)
legacyReturn:SetScript("OnClick", function()
    addon:SetModernNameplateOptionsEnabled(true)
end)

local allRefreshables = {styleSelector, stylePreview, showEnemyName, showHealthPercent, showHealthValue, disableMobLevel,
    castSelector, castPreview, showCastName, showCastTime,
    castInterruptibleColor, castProtectedColor,
    pveDebuffs, pvpDebuffs, compatibilityToggle, allPersonal, enemyStacking,
    castInformation, targetOptions, questIconOptions}
local function AppendControls(controls)
    for _, control in ipairs(controls) do allRefreshables[#allRefreshables + 1] = control end
end
AppendControls(styleSliders)
AppendControls(castSliders)
AppendControls(alignmentSelectors)
AppendControls(compatibilityControls)

refreshAll = function()
    liquidOptions:Refresh()
    for _, control in ipairs(allRefreshables) do if control and control.Refresh then control:Refresh() end end
    local styleEnabled = not addon:GetCompatibilityMode() and not InCombatLockdown()
    styleSelector:SetEnabled(styleEnabled)
    for _, control in ipairs(styleSliders) do control:SetEnabled(not addon:GetCompatibilityMode()) end
    styleSliders[5]:SetEnabled(styleEnabled)
    styleSliders[6]:SetEnabled(styleEnabled)
    local percentOn, valueOn = styleOptions.Health()
    styleSliders[3]:SetEnabled(not addon:GetCompatibilityMode() and percentOn)
    styleSliders[4]:SetEnabled(not addon:GetCompatibilityMode() and valueOn)
    SetControlEnabled(showHealthPercent, not addon:GetCompatibilityMode())
    SetControlEnabled(showHealthValue, not addon:GetCompatibilityMode())
    local nameOn = addon:GetNameplateNameEnabled()
    styleSliders[2]:SetEnabled(not addon:GetCompatibilityMode() and nameOn)
    SetControlEnabled(showEnemyName,not addon:GetCompatibilityMode())
    alignmentSelectors[1]:SetEnabled(not addon:GetCompatibilityMode() and nameOn)
    alignmentSelectors[2]:SetEnabled(not addon:GetCompatibilityMode() and percentOn)
    alignmentSelectors[3]:SetEnabled(not addon:GetCompatibilityMode() and valueOn)
    for _, control in ipairs(compatibilityControls) do SetControlEnabled(control,addon:GetCompatibilityMode() and not InCombatLockdown()) end
    SetControlEnabled(compatibilityFeaturesButton,addon:GetCompatibilityMode())
    local atd = addon:IsATDStyle()
    -- Native styles keep Disable Mob Level on this row. Custom styles have
    -- no level checkbox, leaving the requested left position available.
    liquidButton:ClearAllPoints()
    liquidButton:SetPoint("TOPLEFT",styleTools,"BOTTOMLEFT",atd and 0 or 230,-18)
    disableMobLevel:SetShown(not atd)
    SetControlEnabled(disableMobLevel, not addon:GetCompatibilityMode())
    local editableATD = atd and not InCombatLockdown()
    showCastName:SetShown(atd)
    showCastTime:SetShown(atd)
    castColors:SetShown(atd)
    castNativeGroup:SetShown(not atd)
    SetControlEnabled(showCastName, editableATD)
    SetControlEnabled(showCastTime, editableATD)
    SetControlEnabled(castInterruptibleColor, editableATD)
    SetControlEnabled(castProtectedColor, editableATD)
    for _, control in ipairs(castSliders) do control:SetShown(atd); control:SetEnabled(editableATD) end
    castSelector:SetEnabled(not InCombatLockdown())
    castReset:SetShown(atd)
    SetControlEnabled(castReset, editableATD)
    SetControlEnabled(styleReset, not InCombatLockdown() and not addon:GetCompatibilityMode())
    if addon.RefreshDevSavedStyleOptions then addon:RefreshDevSavedStyleOptions(styleView,styleTools,styleTabButtons,styleReset) end
    SetControlEnabled(compatibilityToggle, not InCombatLockdown())
    combatMessage:SetText(InCombatLockdown()
        and "Protected Blizzard changes are queued and will apply when combat ends."
        or "Changes here mirror Blizzard's own nameplate settings.")

end

function addon:ShowModernNameplateView(key)
    if key == "auras" then
        key = ForeverNameplatesDB and ForeverNameplatesDB.optionsLastAuraView or "pve"
        if key ~= "pvp" then key = "pve" end
    end
    key = views[key] and key or "style"
    activeView = key
    for viewKey, view in pairs(views) do view:SetShown(viewKey == key) end
    if addon.ThreatOptionsActions then addon.ThreatOptionsActions.CloseEditors() end
    if panel:IsShown() and ForeverNameplatesDB then
        ForeverNameplatesDB.optionsLastNameplateView = key
        if key == "pve" or key == "pvp" then ForeverNameplatesDB.optionsLastAuraView = key end
    end
    refreshAll()
    if self.OnModernNameplateViewChanged then self:OnModernNameplateViewChanged(key) end
end

function addon:GetModernNameplateView() return activeView end

local function ApplyLayoutPreference()
    local modern = not (ForeverNameplatesDB and ForeverNameplatesDB.useLegacyNameplateOptions)
    shell:SetShown(modern)
    legacyReturn:SetShown(not modern)
    if addon.RefreshOptionsLayout then addon:RefreshOptionsLayout() end
    if modern then
        addon:ShowModernNameplateView(ForeverNameplatesDB and ForeverNameplatesDB.optionsLastNameplateView or activeView)
    end
end

function addon:SetModernNameplateOptionsEnabled(enabled)
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    ForeverNameplatesDB.useLegacyNameplateOptions = not enabled
    ApplyLayoutPreference()
end

nameplatesPage:HookScript("OnShow", ApplyLayoutPreference)

SLASH_BTP_MODERN_NAMEPLATES1 = "/btpui"
SlashCmdList.BTP_MODERN_NAMEPLATES = function()
    local modern = ForeverNameplatesDB and ForeverNameplatesDB.useLegacyNameplateOptions
    addon:SetModernNameplateOptionsEnabled(modern and true or false)
    print("BlizzThreatPlates: "..(modern and "modern" or "original").." Nameplates options layout enabled.")
end

local events = CreateFrame("Frame")
events:RegisterEvent("CVAR_UPDATE")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function(_, event, cvar)
    if event == "CVAR_UPDATE" and cvar then
        local changed = string.lower(cvar)
        for key in pairs(pendingCVars) do
            if string.lower(key) == changed then pendingCVars[key] = nil end
        end
    end
    if event == "PLAYER_REGEN_ENABLED" then
        C_Timer.After(0, function()
            for key in pairs(pendingCVars) do pendingCVars[key] = nil end
            if shell:IsShown() then refreshAll() end
        end)
    elseif shell:IsShown() then refreshAll() end
end)

addon.ModernOptionsUI = {
    CreateView=CreateView,
    Font=Font, Backdrop=Backdrop, Button=Button, Toggle=Toggle, SliderRow=SliderRow,
    Selector=Selector, OpenColorPicker=OpenColorPicker, SetControlEnabled=SetControlEnabled,
    CreateNameplateSample=CreateNameplateSample, PreviewCard=PreviewCard,
    StyleSample=styleSample,
}
ApplyLayoutPreference()
