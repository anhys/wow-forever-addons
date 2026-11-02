local _, TrainerSpells = ...
local TRAINER_STATUS_FILTERS = {"available", "unavailable", "used"}

local function GetTrainerStatusSelections()
    local selections = TrainerSpells_Character.trainerStatusFilters
    if type(selections) ~= "table" then
        selections = {}
        for _, filter in ipairs(TRAINER_STATUS_FILTERS) do
            selections[filter] = not GetTrainerServiceTypeFilter or GetTrainerServiceTypeFilter(filter)
        end

        TrainerSpells_Character.trainerStatusFilters = selections
    end
    return selections
end

local function HasSelectedTrainerStatus()
    local selections = GetTrainerStatusSelections()
    for _, filter in ipairs(TRAINER_STATUS_FILTERS) do
        if selections[filter] then return true end
    end
    return false
end

local function ApplyNativeTrainerStatusFilters()
    if not GetTrainerServiceTypeFilter or not SetTrainerServiceTypeFilter then return end
    local selections = GetTrainerStatusSelections()
    local showAllForIgnoredOnly = TrainerSpells_Character.showIgnoredInTrainer and not HasSelectedTrainerStatus()
    for _, filter in ipairs(TRAINER_STATUS_FILTERS) do
        local selected = showAllForIgnoredOnly or selections[filter]
        if GetTrainerServiceTypeFilter(filter) ~= selected then SetTrainerServiceTypeFilter(filter, selected) end
    end
end

local function ServiceMatchesTrainerFilters(serviceType, isIgnored)
    if serviceType == "header" then return true end
    local selections = GetTrainerStatusSelections()
    local hasSelectedStatus = HasSelectedTrainerStatus()
    if isIgnored then
        return TrainerSpells_Character.showIgnoredInTrainer and (not hasSelectedStatus or selections[serviceType])
    end
    return hasSelectedStatus and selections[serviceType] or false
end

local function BuildCachedSpellIDLookup()
    local _, classToken = UnitClass("player")
    local lookup = {}
    local classData = classToken and TrainerSpells_Data[classToken]
    if not classData then return lookup end
    for _, spells in pairs(classData) do
        for id, data in pairs(spells) do
            local name = TrainerSpells:GetSpellInfo(id)
            if name then
                lookup[name] = lookup[name] or {}
                local rankNum = type(data) == "table" and tonumber(data.rank) or 0
                lookup[name][rankNum or 0] = id
            end
        end
    end
    return lookup
end

local function BuildVisibleTrainerIndexList()
    local total = GetNumTrainerServices()
    local cachedSpellIDs = BuildCachedSpellIDLookup()
    local list = {}
    for i = 1, total do
        local name, subText, serviceType = GetTrainerServiceInfo(i)
        local keep = serviceType == "header"
        if serviceType and serviceType ~= "header" and name then
            local rankNum = subText and tonumber(subText:match("%d+")) or 0
            local spellID = cachedSpellIDs[name] and cachedSpellIDs[name][rankNum]
            if not spellID then spellID = TrainerSpells:GetSpellIDForService(i) end
            keep = ServiceMatchesTrainerFilters(serviceType, TrainerSpells_IsIgnored(spellID, name))
        end

        if keep then table.insert(list, i) end
    end
    return list
end

local function TrainerSpells_ClassTrainerFrame_Update()
    SetPortraitTexture(ClassTrainerFramePortrait, "npc")
    ClassTrainerNameText:SetText(UnitName("npc"))
    ClassTrainerGreetingText:SetText(GetTrainerGreetingText())
    local visibleList = BuildVisibleTrainerIndexList()
    local numTrainerServices = #visibleList
    local skillOffset = FauxScrollFrame_GetOffset(ClassTrainerListScrollFrame)
    if numTrainerServices == 0 then
        ClassTrainerCollapseAllButton:Disable()
    else
        ClassTrainerCollapseAllButton:Enable()
    end

    if not ClassTrainerFrame.selectedService then ClassTrainer_HideSkillDetails() end
    if IsTradeskillTrainer() then
        ClassTrainer_SetToTradeSkillTrainer()
    else
        ClassTrainer_SetToClassTrainer()
    end

    FauxScrollFrame_Update(ClassTrainerListScrollFrame, numTrainerServices, CLASS_TRAINER_SKILLS_DISPLAYED, CLASS_TRAINER_SKILL_HEIGHT, nil, nil, nil, ClassTrainerSkillHighlightFrame, 293, 316)
    ClassTrainerMoneyFrame:Show()
    ClassTrainerSkillHighlightFrame:Hide()
    for i = 1, CLASS_TRAINER_SKILLS_DISPLAYED do
        local skillIndex = visibleList[i + skillOffset]
        local skillButton = _G["ClassTrainerSkill" .. i]
        local serviceName, serviceSubText, serviceType, isExpanded
        local moneyCost
        if skillIndex then
            serviceName, serviceSubText, serviceType, isExpanded = GetTrainerServiceInfo(skillIndex)
            if not serviceName then serviceName = UNKNOWN end
            if ClassTrainerListScrollFrame:IsVisible() then
                skillButton:SetWidth(293)
            else
                skillButton:SetWidth(323)
            end

            local skillSubText = _G["ClassTrainerSkill" .. i .. "SubText"]
            if serviceType == "header" then
                local skillText = _G["ClassTrainerSkill" .. i .. "Text"]
                skillText:SetText(serviceName)
                skillText:SetWidth(0)
                skillButton:SetNormalFontObject("GameFontNormal")
                skillSubText:Hide()
                if isExpanded then
                    skillButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
                else
                    skillButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                end

                _G["ClassTrainerSkill" .. i .. "Highlight"]:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
            else
                skillButton:ClearNormalTexture()
                _G["ClassTrainerSkill" .. i .. "Highlight"]:SetTexture("")
                local skillText = _G["ClassTrainerSkill" .. i .. "Text"]
                skillText:SetText("  " .. serviceName)
                if serviceSubText and serviceSubText ~= "" then
                    skillSubText:SetText(format(PARENS_TEMPLATE, serviceSubText))
                    skillSubText:SetPoint("LEFT", "ClassTrainerSkill" .. i .. "Text", "RIGHT", 10, 0)
                    skillSubText:Show()
                    skillText:SetWidth(0)
                else
                    skillSubText:Hide()
                    skillText:SetWidth(SKILL_TEXT_WIDTH)
                end

                local _
                moneyCost, _ = GetTrainerServiceCost(skillIndex)
                if serviceType == "available" then
                    skillButton:SetNormalFontObject("GameFontNormalLeftGreen")
                    ClassTrainer_SetSubTextColor(skillButton, 0, 0.6, 0)
                elseif serviceType == "used" then
                    skillButton:SetNormalFontObject("GameFontDisable")
                    ClassTrainer_SetSubTextColor(skillButton, 0.5, 0.5, 0.5)
                else
                    skillButton:SetNormalFontObject("GameFontNormalLeftRed")
                    ClassTrainer_SetSubTextColor(skillButton, 0.6, 0, 0)
                end
            end

            skillButton:SetID(skillIndex)
            skillButton:Show()
            if ClassTrainerFrame.selectedService and GetTrainerSelectionIndex() == skillIndex then
                ClassTrainerSkillHighlightFrame:SetPoint("TOPLEFT", "ClassTrainerSkill" .. i, "TOPLEFT", 0, 0)
                ClassTrainerSkillHighlightFrame:Show()
                skillButton:LockHighlight()
                ClassTrainer_SetSubTextColor(skillButton, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
                if moneyCost and moneyCost > 0 then ClassTrainerCostLabel:Show() end
            else
                skillButton:UnlockHighlight()
            end
        else
            skillButton:Hide()
        end
    end

    local numHeaders = 0
    local notExpanded = 0
    local showDetails = nil
    for i = 1, numTrainerServices do
        local realIndex = visibleList[i]
        local serviceName, _, serviceType, isExpanded = GetTrainerServiceInfo(realIndex)
        if serviceName and serviceType == "header" then
            numHeaders = numHeaders + 1
            if not isExpanded then notExpanded = notExpanded + 1 end
        end

        if ClassTrainerFrame.selectedService and GetTrainerSelectionIndex() == realIndex then showDetails = 1 end
    end

    if showDetails then
        ClassTrainer_ShowSkillDetails()
    else
        ClassTrainer_HideSkillDetails()
    end

    if notExpanded ~= numHeaders then
        ClassTrainerCollapseAllButton.collapsed = nil
        ClassTrainerCollapseAllButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
    else
        ClassTrainerCollapseAllButton.collapsed = 1
        ClassTrainerCollapseAllButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
    end
end

local trainerUpdateOverrideInstalled = false

function TrainerSpells:EnsureTrainerUpdateOverrideInstalled()
    if trainerUpdateOverrideInstalled then return end
    if not ClassTrainerFrame_Update then return end
    if not TrainerSpells_IsIgnored then return end
    if ClassTrainerFrame and ClassTrainerFrame.ScrollBox then return end
    if not ClassTrainerListScrollFrame then return end
    trainerUpdateOverrideInstalled = true
    ClassTrainerFrame_Update = TrainerSpells_ClassTrainerFrame_Update
    ClassTrainerFrame_Update()
end

local trainerFilterHookInstalled = false
function TrainerSpells:EnsureTrainerFilterHookInstalled()
    if trainerFilterHookInstalled or not trainerUpdateOverrideInstalled then return end
    if not ClassTrainerFrame or not ClassTrainerFrame.FilterDropdown then return end
    trainerFilterHookInstalled = true
    local function IsNativeFilterSelected(filter)
        return GetTrainerStatusSelections()[filter]
    end

    local function SetNativeFilterSelected(filter)
        ClassTrainerFrame.filterPending = true
        local selections = GetTrainerStatusSelections()
        selections[filter] = not selections[filter]
        ApplyNativeTrainerStatusFilters()
        if ClassTrainerFrame_Update then ClassTrainerFrame_Update() end
    end

    local function IsIgnoredFilterSelected()
        return TrainerSpells_Character.showIgnoredInTrainer
    end

    local function SetIgnoredFilterSelected()
        TrainerSpells_Character.showIgnoredInTrainer = not TrainerSpells_Character.showIgnoredInTrainer
        ApplyNativeTrainerStatusFilters()
        if ClassTrainerFrame_Update then ClassTrainerFrame_Update() end
    end

    local applyingOwnMenu = false
    local function ApplyOwnMenu()
        applyingOwnMenu = true
        ClassTrainerFrame.FilterDropdown:SetupMenu(function(dropdown, rootDescription)
            rootDescription:SetTag("MENU_TRAINER_FILTER")
            rootDescription:CreateCheckbox(GREEN_FONT_COLOR:WrapTextInColorCode(AVAILABLE), IsNativeFilterSelected, SetNativeFilterSelected, "available")
            rootDescription:CreateCheckbox(RED_FONT_COLOR:WrapTextInColorCode(UNAVAILABLE), IsNativeFilterSelected, SetNativeFilterSelected, "unavailable")
            rootDescription:CreateCheckbox(YELLOW_FONT_COLOR:WrapTextInColorCode(TrainerSpells:Trans("LID_IGNORED")), IsIgnoredFilterSelected, SetIgnoredFilterSelected)
            rootDescription:CreateCheckbox(GRAY_FONT_COLOR:WrapTextInColorCode(USED), IsNativeFilterSelected, SetNativeFilterSelected, "used")
        end)

        applyingOwnMenu = false
    end

    hooksecurefunc(ClassTrainerFrame.FilterDropdown, "SetupMenu", function()
        if applyingOwnMenu then return end
        ApplyOwnMenu()
    end)

    ApplyOwnMenu()
    ApplyNativeTrainerStatusFilters()
end

local function CountRealTrainerServices()
    local total = GetNumTrainerServices()
    local real = 0
    for i = 1, total do
        local _, _, category = GetTrainerServiceInfo(i)
        if category ~= "header" then real = real + 1 end
    end
    return real
end

local function ScanTrainerServicesStep(button, offset, maxOffset, targetCount, visited, visitedCount)
    if visitedCount >= targetCount or offset > maxOffset then
        FauxScrollFrame_SetOffset(ClassTrainerListScrollFrame, 0)
        ClassTrainerFrame_Update()
        TrainerSpells:MSG("|cff33ff99TrainerSpells:|r " .. TrainerSpells:Trans("LID_SCANFINISHED"):format(visitedCount, targetCount))
        return
    end

    FauxScrollFrame_SetOffset(ClassTrainerListScrollFrame, offset)
    ClassTrainerFrame_Update()
    local id = button:GetID()
    if button:IsShown() and id and id >= 1 and not visited[id] then
        local _, _, category = GetTrainerServiceInfo(id)
        if category ~= "header" then
            visited[id] = true
            visitedCount = visitedCount + 1
            button:Click()
        end
    end

    C_Timer.After(0.05, function() ScanTrainerServicesStep(button, offset + 1, maxOffset, targetCount, visited, visitedCount) end)
end

function TrainerSpells:ScanAllTrainerRequirements()
    if not GetNumTrainerServices or not GetTrainerServiceInfo or not ExpandTrainerSkillLine or not ClassTrainerListScrollFrame or not FauxScrollFrame_SetOffset or not ClassTrainerFrame_Update or not C_Timer then
        TrainerSpells:MSG("|cffff5555TrainerSpells:|r " .. TrainerSpells:Trans("LID_SCANNOAPI"))
        return
    end

    local button = _G["ClassTrainerSkill1"]
    if not button then
        TrainerSpells:MSG("|cffff5555TrainerSpells:|r " .. TrainerSpells:Trans("LID_SCANNOBUTTON"))
        return
    end

    TrainerSpells:ExpandAllTrainerHeaders()
    local targetCount = CountRealTrainerServices()
    local maxOffset = GetNumTrainerServices() + 200
    TrainerSpells:MSG("|cff33ff99TrainerSpells:|r " .. TrainerSpells:Trans("LID_SCANSTARTED"):format(targetCount))
    ScanTrainerServicesStep(button, 0, maxOffset, targetCount, {}, 0)
end
