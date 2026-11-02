local addon = ForeverNameplates
local panel, navigation = addon.OptionsPanel, addon.OptionsNavigation
if not panel or not navigation or not addon.OptionsContentRoot then return end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local GOLD, TEXT = {0.88, 0.66, 0.24}, {0.92, 0.90, 0.84}
local subButtons, sidebarEnabled = {}, nil
local function CreateMainButton(text)
    local button=CreateFrame("Button",nil,addon.OptionsContentInset)
    button.btpOptionsSurface="navigationButton"
    button:SetNormalTexture(WHITE)
    button:GetNormalTexture():SetVertexColor(0.055,0.065,0.08,1)
    button:SetHighlightTexture(WHITE)
    button:GetHighlightTexture():SetVertexColor(0.12,0.13,0.15,0.65)
    local label=button:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    label.btpOptionsTextRole="navigation"
    label:SetText(text)
    button:SetFontString(label)
    return button
end
local general,advanced=CreateMainButton("General"),CreateMainButton("Advanced")
navigation.general,navigation.advanced=general,advanced
local dev = addon.OpenDevOptionsWindow and CreateMainButton("Dev Only")
if dev then navigation.dev = dev end
local function DevEnabled() return dev and addon.IsDevOptionsEnabled and addon:IsDevOptionsEnabled() end
local sidebar = CreateFrame("Frame", nil, panel)
-- Equal 24-unit outer margins; keep 7-unit padding within the sidebar outline.
-- The outline extends 10 above the buttons, matching every page's Y -70 edge.
sidebar:SetPoint("TOPLEFT", panel, "TOPLEFT", 31, -80)
sidebar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 31, 70)
sidebar:SetWidth(150)
sidebar:SetFrameLevel(panel:GetFrameLevel() + 8)
local navigationBorder = CreateFrame("Frame", nil, sidebar, "BackdropTemplate")
navigationBorder.btpOptionsSurface="sidebar"
navigationBorder:SetPoint("TOPLEFT", sidebar, "TOPLEFT", -7, 10)
navigationBorder:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 7, 10)
navigationBorder:SetFrameLevel(sidebar:GetFrameLevel())
navigationBorder:EnableMouse(false)
navigationBorder:SetBackdrop({bgFile=WHITE, edgeFile=WHITE, edgeSize=1})
navigationBorder:SetBackdropColor(0.055, 0.063, 0.075, 1)
navigationBorder:SetBackdropBorderColor(0.20, 0.23, 0.27, 1)
local groupDivider = navigationBorder:CreateTexture(nil, "ARTWORK")
groupDivider:SetHeight(1)
groupDivider:SetColorTexture(0.20, 0.23, 0.27, 1)
groupDivider.btpOptionsTextureRole="border"
groupDivider.btpOptionsTextureMethod="SetColorTexture"
groupDivider.btpOptionsTextureColor={0.20,0.23,0.27,1}
groupDivider:Hide()

local function PaintSelection(button, selected)
    if button.btpDisabled then
        button:GetFontString():SetTextColor(0.45,0.47,0.50)
        if button.btpModernUnderline then button.btpModernUnderline:Hide() end
        return
    end
    button:GetFontString():SetTextColor(unpack(selected and GOLD or TEXT))
    if button.btpModernUnderline then button.btpModernUnderline:SetShown(selected) end
end

local function PaintGroupBorder(button)
    local color = button.btpGroupHovered and GOLD or {0.20, 0.23, 0.27}
    button.btpGroupBorder:SetBackdropBorderColor(unpack(color))
end

local function PaintGroup(button,selected)
    button.btpSidebarSelected=selected and true or false
    PaintSelection(button,false)
    button:GetNormalTexture():SetVertexColor(0.085, 0.097, 0.115, 1)
    if button.btpModernUnderline then button.btpModernUnderline:SetShown(false) end
    if not button.btpGroupBorder then
        local border=CreateFrame("Frame",nil,button,"BackdropTemplate")
        border:SetAllPoints(button)
        border:EnableMouse(false)
        button.btpGroupBorder=border
        border.btpOptionsSurface="navigationButton"
        button:HookScript("OnEnter", function(self)
            self.btpGroupHovered = true
            PaintGroupBorder(self)
        end)
        button:HookScript("OnLeave", function(self)
            self.btpGroupHovered = nil
            PaintGroupBorder(self)
        end)
        button:HookScript("OnHide", function(self)
            self.btpGroupHovered = nil
            PaintGroupBorder(self)
        end)
    end
    local border=button.btpGroupBorder
    border:SetFrameLevel(button:GetFrameLevel()+1)
    border:SetBackdrop({edgeFile=WHITE,edgeSize=1})
    PaintGroupBorder(button)
    border:Show()
end

local function CreateSubButton(text, destination, category, disabled)
    category = category or "nameplates"
    local button = CreateFrame("Button", nil, sidebar)
    button.btpDisabled=disabled and true or false
    button.btpPersistentNew=destination=="style" or destination=="auras" or destination=="comboPoints" or destination=="borders" or (category=="colors" and destination=="colors")
    button.btpOptionsSurface="navigationButton"
    button:SetSize(138, 28)
    button:SetNormalTexture(WHITE)
    button:GetNormalTexture():SetVertexColor(0.095, 0.105, 0.12, 0)
    button:SetHighlightTexture(WHITE)
    button:GetHighlightTexture():SetVertexColor(0.12, 0.13, 0.15, 0.65)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label.btpOptionsTextRole="navigation"
    label.btpOptionsFontSizeOffset=1
    local face,size,flags=label:GetFont()
    label:SetFont(face,size+1,flags)
    -- Keep label indentation while centering the highlight within the sidebar.
    label:SetPoint("LEFT", 18, 0)
    label:SetWidth(0)
    label:SetWordWrap(false)
    label:SetText(text)
    button:SetFontString(label)
    if disabled then
        button:SetHeight(42)
        button:SetEnabled(false)
        label:ClearAllPoints()
        label:SetPoint("LEFT",18,7)
        label.btpDevExclude=true
        label:SetTextColor(0.45,0.47,0.50)
        local note=button:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        note.btpDevExclude=true
        note:SetFont(face,size-1,flags)
        note:SetPoint("TOPLEFT",label,"BOTTOMLEFT",0,-2)
        note:SetText("(Still Testing)")
        note:SetTextColor(0.45,0.47,0.50)
        button.btpDisabledNote=note
        button:GetHighlightTexture():SetVertexColor(0,0,0,0)
    end
    if destination == "comboPoints" or destination == "colors" or destination == "players" or destination == "display" or destination == "borders" or destination == "auras" or destination == "style" or destination == "questIcons" then
        -- Follow the actual label width so the longer Enemy Debuffs caption
        -- always has a gap before NEW, independent of the button's highlight.
        -- Threat Display needs the same template-inset compensation as the
        -- nameplate badges, so its visible NEW text sits beside the caption.
        button.btpNewFeatureTag = addon:CreateOptionsNewFeatureTag(button, label, "LEFT", "RIGHT", (destination == "colors" or destination == "display" or destination == "borders") and -8 or 6, 0)
    end
    local mark = button:CreateTexture(nil, "OVERLAY")
    mark:SetPoint("TOPLEFT", 0, -5)
    mark:SetPoint("BOTTOMLEFT", 0, 5)
    mark:SetWidth(2)
    mark:SetColorTexture(unpack(GOLD))
    mark.btpOptionsTextureRole="accent"
    mark.btpOptionsTextureMethod="SetColorTexture"
    mark.btpOptionsTextureColor=GOLD
    button.btpModernUnderline = mark
    button:SetScript("OnClick", function()
        if button.btpDisabled then return end
        if addon:GetOptionsPage() ~= category then addon.SelectOptionsPage(category) end
        if category == "colors" then addon:ShowModernThreatView(destination)
        else addon:ShowModernNameplateView(destination) end
    end)
    subButtons[destination] = button
    return button
end

local sections = {
    {"style", "Style"}, {"castbar", "Castbar"},
    {"auras", "Enemy Debuffs"}, {"target", "Target of Target"},
    {"comboPoints", "Combo Points"},
    {"questIcons", "Quest Icons"},
}
for _, section in ipairs(sections) do CreateSubButton(section[2], section[1]) end
-- Share a badge column with a small gap after the longest caption.
-- Compensate for the template's leading inset without crowding Style's text.
local nameplateTagX = 18 + math.max(subButtons.style:GetFontString():GetStringWidth(),
    subButtons.auras:GetFontString():GetStringWidth(),subButtons.questIcons:GetFontString():GetStringWidth()) - 8
for _, key in ipairs({"style", "auras", "questIcons", "comboPoints"}) do
    local button = subButtons[key]
    -- Position in the button's coordinates; NEW itself is scaled to 80%.
    local anchor = button:CreateTexture(nil, "BACKGROUND")
    anchor:SetSize(1, 1)
    button.btpNewFeatureNearLabel=key=="style" or key=="comboPoints"
    anchor:SetPoint("LEFT", button, "LEFT", button.btpNewFeatureNearLabel and (18+button:GetFontString():GetStringWidth()-2) or nameplateTagX, 0)
    button.btpNewFeatureAnchor = anchor
    button.btpNewFeatureTag:ClearAllPoints()
    button.btpNewFeatureTag:SetPoint("LEFT", anchor, "LEFT", 0, 0)
end
local threatSections = {
    {"colors", "Threat Colors"}, {"players", "Player Colors"},
    {"display", "Threat Display"}, {"tanking", "Tanking Tools"},
}
if addon.CreateBorderOptions and addon.GetNameplateBorderMode then
    table.insert(threatSections,3,{"borders","Border Colors"})
end
for _, section in ipairs(threatSections) do CreateSubButton(section[2], section[1], "colors", section[3]) end

local navigationKeys = {"general","colors","nameplates","target","advanced"}
if dev then navigationKeys[#navigationKeys+1] = "dev" end
for _,key in ipairs(navigationKeys) do
    local destination=key
    navigation[key]:SetScript("OnClick",function()
        if destination=="dev" then
            addon:OpenDevOptionsWindow()
        elseif ForeverNameplatesDB and ForeverNameplatesDB.useLegacyNameplateOptions then
            addon.SelectOptionsPage(destination)
        elseif destination=="general" then
            addon.SelectOptionsPage(destination)
        elseif destination=="colors" then
            addon.SelectOptionsPage("colors")
            addon:ShowModernThreatView("colors")
        else
            addon.SelectOptionsPage("nameplates")
            addon:ShowModernNameplateView(destination=="advanced" and "advanced" or (destination=="target" and "target" or "style"))
        end
    end)
end

local visitPending
local function VisibleMenu()
    local page=addon:GetOptionsPage()
    if page=="colors" or page=="roles" then
        return "colors",addon.GetModernThreatView and addon:GetModernThreatView() or "colors"
    end
    local view=addon:GetModernNameplateView()
    if page=="nameplates" and view~="advanced" then
        return "nameplates",(view=="pve" or view=="pvp") and "auras" or view
    end
end
local function RefreshRows()
    if not sidebarEnabled then return end
    local category,destination=VisibleMenu()
    local visitedButton=destination and subButtons[destination]
    local hasNewChild=visitedButton and visitedButton.btpNewFeatureTag and not visitedButton.btpPersistentNew and addon:IsOptionsMenuNew(category,destination)
    if panel:IsShown() and category and (addon:IsOptionsMenuNew(category) or hasNewChild) and not visitPending then
        visitPending=true
        -- Navigation can briefly restore a saved subsection before selecting
        -- its destination. Record only the final page shown on the next frame.
        C_Timer.After(0,function()
            visitPending=nil
            if not panel:IsShown() or not sidebarEnabled then return end
            local group,section=VisibleMenu()
            if not group then return end
            addon:MarkOptionsMenuSeen(group)
            local child=section and subButtons[section]
            if child and child.btpNewFeatureTag and not child.btpPersistentNew then addon:MarkOptionsMenuSeen(group,section) end
            RefreshRows()
        end)
    end
    local page, view = addon:GetOptionsPage(), addon:GetModernNameplateView()
    local expanded = page == "nameplates" and view ~= "advanced"
    local advancedSelected = page == "nameplates" and view == "advanced"
    local threatExpanded = page == "colors" or page == "roles"
    local threatView = addon.GetModernThreatView and addon:GetModernThreatView() or "colors"
    local selectedSection = (view == "pve" or view == "pvp") and "auras" or (view=="liquidThreat" and "style" or view)
    general:SetShown(page == "general")
    if dev then dev:SetShown(DevEnabled() and true or false) end
    groupDivider:SetShown(page ~= "general")
    local groupOrder = {"colors", "nameplates", "advanced"}
    if DevEnabled() then groupOrder[#groupOrder+1] = "dev" end
    if page == "general" then
        table.insert(groupOrder, 1, "general")
    else
        local selectedGroup = threatExpanded and "colors" or (advancedSelected and "advanced" or "nameplates")
        for index, key in ipairs(groupOrder) do
            if key == selectedGroup then table.remove(groupOrder, index); break end
        end
        table.insert(groupOrder, 1, selectedGroup)
    end
    local y = 0
    for groupIndex, key in ipairs(groupOrder) do
        local button = navigation[key]
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, y)
        -- The color editor is a child of Colors & Threat; its parent remains
        -- available as a direct way back from the role palette.
        local selected = key == "general" and page == "general" or key == "colors" and threatExpanded
            or key == "nameplates" and expanded or key == "advanced" and advancedSelected
        -- Active groups remain clickable and return to their first section.
        button:SetEnabled(true)
        PaintGroup(button, selected)
        if key == "colors" or key == "nameplates" then
            if not button.btpNewFeatureTag then
                button.btpNewFeatureTag=addon:CreateOptionsNewFeatureTag(button,button,"RIGHT","RIGHT",key == "colors" and -1 or -5,0)
            end
            button.btpNewFeatureTag:SetShown(not selected and addon:IsOptionsMenuNew(key))
        end
        y = y - 38
        local children = key == "colors" and threatSections or (key == "nameplates" and sections)
        local open = key == "colors" and threatExpanded or (key == "nameplates" and expanded)
        if children then
            local childY=y
            for index, section in ipairs(children) do
                local destination, child = section[1], subButtons[section[1]]
                child:ClearAllPoints()
                child:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 6, childY)
                childY=childY-(child.btpDisabled and 44 or 30)
                child:SetShown(open and true or false)
                local chosen = not child.btpDisabled and destination == (key == "colors" and threatView or selectedSection)
                child:SetEnabled(not child.btpDisabled)
                PaintSelection(child, chosen)
                if child.btpNewFeatureTag then
                    child.btpNewFeatureTag:SetShown(child.btpPersistentNew or (not chosen and addon:IsOptionsMenuNew(key,destination)))
                end
                child:GetNormalTexture():SetVertexColor(0.12, 0.135, 0.16, chosen and 1 or 0)
            end
            if open then y = childY - 8 end
        end
        if groupIndex == 1 and page ~= "general" then
            -- Keep inactive groups in their own lower section. Longer future
            -- submenus can push the divider down rather than overlap it.
            local dividerY = math.min(-250, y - 12)
            groupDivider:ClearAllPoints()
            groupDivider:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, dividerY)
            groupDivider:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, dividerY)
            y = dividerY - 18
        end
    end
    -- End the outline beneath the final group rather than at the window footer.
    navigationBorder:SetHeight(10 - y)
    navigation.nameplates.btpSidebarChevron:SetText(expanded and "v" or "")
    navigation.colors.btpSidebarChevron:SetText(threatExpanded and "v" or "")
end

function addon:RefreshOptionsLayout()
    local enabled = not (ForeverNameplatesDB and ForeverNameplatesDB.useLegacyNameplateOptions)
    self:SetOptionsSidebarLayout(enabled)
    sidebar:SetShown(enabled)
    if sidebarEnabled ~= enabled then
        sidebarEnabled = enabled
        for index, key in ipairs({"colors", "nameplates", "target"}) do
            local button = navigation[key]
            button.btpOptionsSurface="navigationButton"
            button:SetParent(enabled and sidebar or addon.OptionsContentInset)
            button:SetSize(enabled and 150 or 174, enabled and 30 or 26)
            button:SetFrameLevel(enabled and sidebar:GetFrameLevel() + 1
                or addon.OptionsContentInset:GetFrameLevel() + 1)
            button:ClearAllPoints()
            local label = button:GetFontString()
            label.btpOptionsTextRole="navigation"
            label:ClearAllPoints()
            label:SetJustifyH(enabled and "LEFT" or "CENTER")
            if enabled then label:SetPoint("LEFT", 10, 0)
            else
                label:SetPoint("CENTER")
                button:SetPoint("TOPLEFT", panel, "TOPLEFT", 38 + (index - 1) * 184, -70)
            end
            local mark = button.btpModernUnderline
            if mark then
                mark:ClearAllPoints()
                if enabled then
                    mark:SetPoint("TOPLEFT", 0, -5)
                    mark:SetPoint("BOTTOMLEFT", 0, 5)
                    mark:SetWidth(2)
                else
                    mark:SetPoint("BOTTOMLEFT", 6, 1)
                    mark:SetPoint("BOTTOMRIGHT", -6, 1)
                    mark:SetHeight(2)
                end
            end
        end
        for _,button in ipairs({general,advanced,dev}) do
            button:SetParent(sidebar)
            button:SetSize(150,30)
            button:SetFrameLevel(sidebar:GetFrameLevel()+1)
            local label=button:GetFontString()
            label:ClearAllPoints()
            label:SetPoint("LEFT",10,0)
            label:SetJustifyH("LEFT")
        end
    end
    navigation.target:SetShown(not enabled)
    advanced:SetShown(enabled)
    general:SetShown(enabled and self:GetOptionsPage() == "general")
    if dev then dev:SetShown(enabled and DevEnabled() and true or false) end
    for _,key in ipairs({"general","colors","nameplates","advanced"}) do
        if not enabled then navigation[key].btpSidebarSelected=nil end
        local border=navigation[key].btpGroupBorder
        if border then border:SetShown(enabled) end
        if not enabled and navigation[key].btpNewFeatureTag then navigation[key].btpNewFeatureTag:Hide() end
    end
    if dev and not enabled then
        dev.btpSidebarSelected = nil
        if dev.btpGroupBorder then dev.btpGroupBorder:Hide() end
    end
    for _, key in ipairs({"colors", "nameplates"}) do
        local button = navigation[key]
        if not button.btpSidebarChevron then
            local arrow = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            arrow:SetPoint("RIGHT", -8, 0)
            arrow:SetTextColor(unpack(GOLD))
            button.btpSidebarChevron = arrow
        end
        button.btpSidebarChevron:SetShown(enabled)
    end
    if not enabled then
        local page = self:GetOptionsPage()
        for key, button in pairs(navigation) do
            local selected=key==page or (key=="colors" and page=="roles")
            button:SetEnabled(not selected)
            PaintSelection(button,selected)
        end
    end
    local page=self:GetOptionsPage()
    if page == "dev" then
        addon.SelectOptionsPage(enabled and "general" or "colors")
    elseif enabled and page=="target" then
        addon.SelectOptionsPage("nameplates")
        addon:ShowModernNameplateView("target")
    elseif not enabled and page=="general" then
        addon.SelectOptionsPage("colors")
    elseif not enabled and page=="nameplates" and self:GetModernNameplateView()=="target" then
        addon.SelectOptionsPage("target")
    end
    if addon.RefreshModernThreatLayout then addon:RefreshModernThreatLayout() end
    RefreshRows()
end

function addon:GetOptionsInitialPage()
    -- All entry points share OptionsPanel.OnShow, including /btp and minimap.
    if ForeverNameplatesDB then ForeverNameplatesDB.optionsLastThreatView="colors" end
    return ForeverNameplatesDB and ForeverNameplatesDB.useLegacyNameplateOptions and "colors" or "general"
end

function addon:OnOptionsPageChanged(key)
    if key=="target" and not (ForeverNameplatesDB and ForeverNameplatesDB.useLegacyNameplateOptions) then
        addon.SelectOptionsPage("nameplates")
        addon:ShowModernNameplateView("target")
        return
    end
    if key ~= "dev" and panel:IsShown() and ForeverNameplatesDB and not ForeverNameplatesDB.useLegacyNameplateOptions then
        ForeverNameplatesDB.optionsLastPage = key == "roles" and "colors" or key
    end
    if addon.RefreshModernThreatLayout then addon:RefreshModernThreatLayout() end
    RefreshRows()
end

function addon:OnModernNameplateViewChanged() RefreshRows() end
function addon:OnModernThreatViewChanged() RefreshRows() end

-- SavedVariables are available by first open, including a saved legacy choice.
panel:HookScript("OnShow", function() addon:RefreshOptionsLayout() end)
addon:RefreshOptionsLayout()
