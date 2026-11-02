local _, TrainerSpells = ...
local classFrame = TrainerSpells.ClassFrame
local function GetCurrentProfessionSkill(professionName)
    if ProfessionsFrame then
        local professionInfo = ProfessionsFrame.GetProfessionInfo and ProfessionsFrame:GetProfessionInfo() or ProfessionsFrame.professionInfo
        if type(professionInfo) == "table" and professionInfo.skillLevel then return professionInfo.skillLevel end
    end

    if not GetNumSkillLines or not GetSkillLineInfo or not professionName then return 0 end
    for i = 1, GetNumSkillLines() do
        local skillName, isHeader, _, skillRank = GetSkillLineInfo(i)
        if not isHeader and skillName == professionName then return skillRank or 0 end
    end
    return 0
end

local professionFrame = CreateFrame("Frame", "TrainerSpellsProfessionFrame", UIParent)
professionFrame:SetSize(420, 480)
professionFrame:SetFrameStrata("HIGH")
professionFrame:SetFrameLevel(500)
professionFrame:EnableMouse(true)
professionFrame:Hide()
local professionSearchBox = CreateFrame("EditBox", "TrainerSpellsProfessionSearchBox", professionFrame, "SearchBoxTemplate")
professionSearchBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 8, -24)
professionSearchBox:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -8, -24)
professionSearchBox:SetHeight(20)
professionSearchBox:SetAutoFocus(false)
professionSearchBox:SetScript("OnTextChanged", function(self)
    if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(self) end
    TrainerSpells_ProfessionSearchText = self:GetText() or ""
    TrainerSpells_ProfessionRefresh()
end)

TrainerSpells.ProfessionRowHeight = (TrainerSpells_Character and TrainerSpells_Character.professionRowHeight) or 16
TrainerSpells.ProfessionRowHeight = math.max(TrainerSpells.MinRowHeight, math.min(TrainerSpells.MaxRowHeight, TrainerSpells.ProfessionRowHeight))
local professionRowHeightSlider = CreateFrame("Slider", "TrainerSpellsProfessionRowHeightSlider", professionFrame, "MinimalSliderWithSteppersTemplate")
TrainerSpells.ProfessionRowHeightSlider = professionRowHeightSlider
professionRowHeightSlider:SetPoint("TOPLEFT", professionSearchBox, "BOTTOMLEFT", -8, -9)
professionRowHeightSlider:SetPoint("TOPRIGHT", professionSearchBox, "BOTTOMRIGHT", -24, -14)
professionRowHeightSlider:SetScale(0.75)
professionRowHeightSlider:SetHeight(10)
professionRowHeightSlider:Init(TrainerSpells.ProfessionRowHeight, TrainerSpells.MinRowHeight, TrainerSpells.MaxRowHeight, TrainerSpells.MaxRowHeight - TrainerSpells.MinRowHeight, {
    [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return WHITE_FONT_COLOR:WrapTextInColorCode(tostring(math.floor(value + 0.5))) end)
})

if professionRowHeightSlider.MinText then professionRowHeightSlider.MinText:Hide() end
if professionRowHeightSlider.MaxText then professionRowHeightSlider.MaxText:Hide() end
local professionScrollBox = CreateFrame("Frame", "TrainerSpellsProfessionScrollBox", professionFrame, "WowScrollBoxList")
professionScrollBox.tsScrollTarget = professionScrollBox.ScrollTarget
professionScrollBox.ScrollTarget = nil
function professionScrollBox:GetScrollTarget() return self.tsScrollTarget end
professionScrollBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 8, -4)
professionScrollBox:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", -26, 12)
local professionListBg = professionFrame:CreateTexture("TrainerSpellsProfessionBackground", "BACKGROUND")
local professionScrollBar = CreateFrame("EventFrame", "TrainerSpellsProfessionScrollBar", professionFrame, "MinimalScrollBar")
professionScrollBar:SetPoint("TOPLEFT", professionScrollBox, "TOPRIGHT", 4, -2)
professionScrollBar:SetPoint("BOTTOMLEFT", professionScrollBox, "BOTTOMRIGHT", 4, 2)
local professionScrollView = CreateScrollBoxListLinearView()
function professionScrollView:RefreshSmartNav() end
professionScrollView:SetElementExtentCalculator(function(_, elementData)
    if elementData.isHeader then return TrainerSpells.HeaderHeight + TrainerSpells.HeaderExtraGap end
    return TrainerSpells.ProfessionRowHeight
end)

professionScrollView:SetPadding(0, 0, 0, 0, TrainerSpells.RowSpacing)
professionScrollView:SetElementInitializer("Frame", function(rowFrame, elementData)
    TrainerSpells:InitScrollRow(rowFrame, elementData, TrainerSpells.ProfessionRowHeight)
    TrainerSpells:ApplyRowStripe(rowFrame, elementData)
    TrainerSpells:ApplyRowInteraction(rowFrame)
    TrainerSpells:PrepareGamepadNavigation(rowFrame)
end)
ScrollUtil.InitScrollBoxListWithScrollBar(professionScrollBox, professionScrollBar, professionScrollView)
professionRowHeightSlider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
    value = math.floor(value + 0.5)
    if value == TrainerSpells.ProfessionRowHeight then return end
    TrainerSpells.ProfessionRowHeight = value
    if TrainerSpells_Character then TrainerSpells_Character.professionRowHeight = TrainerSpells.ProfessionRowHeight end
    TrainerSpells_ProfessionRefresh()
end)

local function GetOpenProfession()
    if GetTradeSkillLine then
        local skillLineName = GetTradeSkillLine()
        if skillLineName and skillLineName ~= "" then return TrainerSpells:GetProfessionKey(skillLineName), skillLineName end
    end

    local professionInfo = ProfessionsFrame and (ProfessionsFrame.GetProfessionInfo and ProfessionsFrame:GetProfessionInfo() or ProfessionsFrame.professionInfo)
    if not professionInfo and C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then professionInfo = C_TradeSkillUI.GetBaseProfessionInfo() end
    if type(professionInfo) ~= "table" then return nil, nil end
    local professionName = professionInfo.parentProfessionName
    local professionKey = professionName and TrainerSpells:GetProfessionKey(professionName)
    if professionKey then return professionKey, professionName end
    professionName = professionInfo.professionName
    professionKey = professionName and TrainerSpells:GetProfessionKey(professionName)
    if professionKey then return professionKey, professionName end
    professionName = professionInfo.name
    professionKey = professionName and TrainerSpells:GetProfessionKey(professionName)
    if professionKey then return professionKey, professionName end
    return nil, professionInfo.parentProfessionName or professionInfo.professionName or professionInfo.name
end

local PROFESSION_VIEW_SKILL = "skill"
local PROFESSION_VIEW_RECIPES = "recipes"
local PROFESSION_VIEW_TRAINERS = "trainers"
local PROFESSION_SUB_VIEWS = {
    {mode = PROFESSION_VIEW_SKILL, icon = "Interface\\Icons\\INV_Misc_Book_09", title = "LID_PROFESSION_FROMTRAINER", desc = "LID_PROFESSION_FROMTRAINER_DESC"},
    {mode = PROFESSION_VIEW_RECIPES, icon = "Interface\\Icons\\INV_Scroll_03", title = "LID_PROFESSION_OTHERRECIPES", desc = "LID_PROFESSION_OTHERRECIPES_DESC"},
    {mode = PROFESSION_VIEW_TRAINERS, icon = 134269, title = "LID_PROFESSION_FINDTRAINER", desc = "LID_PROFESSION_FINDTRAINER_DESC"},
}
local PROFESSION_ALL_VIEWS = PROFESSION_SUB_VIEWS
PROFESSION_SUB_VIEWS = TrainerSpells:FilterTabViews(PROFESSION_ALL_VIEWS, "profession_")
local professionViewMode = PROFESSION_SUB_VIEWS[1] and PROFESSION_SUB_VIEWS[1].mode or PROFESSION_VIEW_SKILL
local function IsProfessionViewEnabled(mode)
    return TrainerSpells:IsTabEnabled("profession_" .. mode)
end
function TrainerSpells:IsProfessionRecipeViewActive()
    return professionViewMode == PROFESSION_VIEW_RECIPES
end

local function MarkProfessionEntries(groups, professionKey, isRecipe)
    for _, groupName in ipairs({"available", "soon", "higher", "missingTalents", "ignored", "known"}) do
        for _, entry in ipairs(groups[groupName]) do
            entry.professionKey = professionKey
            entry.isProfessionRecipe = isRecipe
        end
    end
end

local professionPicker = {}
function professionPicker.GetOwned()
    local owned = {}
    if not GetProfessions or not GetProfessionInfo then return owned end
    local professionIndices = {GetProfessions()}
    for slot = 1, 10 do
        local professionIndex = professionIndices[slot]
        if professionIndex then
            local professionName, icon, rank, maxRank = GetProfessionInfo(professionIndex)
            local professionKey = professionName and TrainerSpells:GetProfessionKey(professionName)
            if professionKey then table.insert(owned, {key = professionKey, name = professionName, icon = icon, rank = rank or 0, maxRank = maxRank or 0, owned = true}) end
        end
    end
    return owned
end

function professionPicker.GetSources()
    return {TrainerSpells_ProfessionData, TrainerSpells_RecipeData, TrainerSpellsProfessionTrainers}
end

function professionPicker.HasData(professionKey)
    for _, source in ipairs(professionPicker.GetSources()) do
        local data = source and source[professionKey]
        if type(data) == "table" and next(data) then return true end
    end
    return false
end

function professionPicker.GetLists()
    local owned = {}
    local seen = {}
    for _, info in ipairs(professionPicker.GetOwned()) do
        seen[info.key] = true
        if professionPicker.HasData(info.key) then table.insert(owned, info) end
    end

    local others = {}
    for _, source in ipairs(professionPicker.GetSources()) do
        for professionKey in pairs(source or {}) do
            local professionName = TrainerSpells:GetProfessionName(professionKey)
            if professionName and not seen[professionKey] and professionPicker.HasData(professionKey) then
                seen[professionKey] = true
                table.insert(others, {key = professionKey, name = professionName, icon = TrainerSpells:GetProfessionIcon(professionKey), rank = 0, maxRank = 0})
            end
        end
    end

    table.sort(others, function(a, b) return a.name < b.name end)
    return owned, others
end

function professionPicker.GetInfo(professionKey)
    for _, info in ipairs(professionPicker.GetOwned()) do
        if info.key == professionKey then return info end
    end
    return {key = professionKey, name = TrainerSpells:GetProfessionName(professionKey) or professionKey, icon = TrainerSpells:GetProfessionIcon(professionKey), rank = 0, maxRank = 0}
end

function professionPicker.GetLabel(info)
    local icon = info.icon and ("|T" .. info.icon .. ":16:16|t ") or ""
    if info.owned then return icon .. info.name .. "  |cffaaaaaa" .. info.rank .. "/" .. info.maxRank .. "|r" end
    return icon .. "|cff9d9d9d" .. info.name .. "|r"
end

function professionPicker.GetActive()
    if not professionPicker.dropdown or not professionPicker.key then
        local professionKey, skillLineName = GetOpenProfession()
        return professionKey, skillLineName, GetCurrentProfessionSkill(skillLineName)
    end

    local info = professionPicker.GetInfo(professionPicker.key)
    return info.key, info.name, info.rank
end

function professionPicker.UpdateWidth(dropdown, measure)
    dropdown = dropdown or professionPicker.dropdown
    measure = measure or professionPicker.measure
    if not dropdown or not measure or not dropdown.Text then return end
    local font, size, flags = dropdown.Text:GetFont()
    if not font then return end
    measure:SetFont(font, size, flags)
    local widest = 0
    for _, group in ipairs({professionPicker.GetLists()}) do
        for _, info in ipairs(group) do
            measure:SetText(professionPicker.GetLabel(info))
            widest = math.max(widest, measure:GetUnboundedStringWidth())
        end
    end

    dropdown:SetWidth(math.max(180, math.ceil(widest) + 50))
end

function professionPicker.UpdateText()
    if professionPicker.dropdown and professionPicker.key then
        local label = professionPicker.GetLabel(professionPicker.GetInfo(professionPicker.key))
        professionPicker.dropdown:SetText(label)
    end
    professionPicker.UpdateWidth()
    professionPicker.UpdateHeader()
end

function professionPicker.GetNativeHeader()
    if not ProfessionsFrame or not ProfessionsFrame.GetTitleText or not ProfessionsFrame.GetPortrait then return nil, nil end
    return ProfessionsFrame:GetTitleText(), ProfessionsFrame:GetPortrait()
end

function professionPicker.SetHeaderActive(active)
    local nativeTitle, nativePortrait = professionPicker.GetNativeHeader()
    if not nativeTitle or not nativePortrait then return end
    local header = professionPicker.header
    if not header then
        if not active then return end
        local titleContainer = ProfessionsFrame.TitleContainer
        local portraitContainer = ProfessionsFrame.PortraitContainer
        header = TrainerSpells.CreateDetachedFrame("Frame", ProfessionsFrame)
        header:SetAllPoints(ProfessionsFrame)
        header:SetFrameLevel((titleContainer or ProfessionsFrame):GetFrameLevel() + 5)
        header.portraitFrame = TrainerSpells.CreateDetachedFrame("Frame", ProfessionsFrame)
        header.portraitFrame:SetAllPoints(nativePortrait)
        header.portraitFrame:SetFrameLevel((portraitContainer or ProfessionsFrame):GetFrameLevel() + 1)
        header.portrait = header.portraitFrame:CreateTexture(nil, "ARTWORK")
        header.portrait:SetAllPoints(header.portraitFrame)
        header.portraitMask = header.portraitFrame:CreateMaskTexture()
        header.portraitMask:SetPoint("TOPLEFT", header.portrait, "TOPLEFT", 2, 0)
        header.portraitMask:SetPoint("BOTTOMRIGHT", header.portrait, "BOTTOMRIGHT", -2, 4)
        header.portraitMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        header.portrait:AddMaskTexture(header.portraitMask)
        header.title = header:CreateFontString(nil, "OVERLAY")
        header.title:SetFontObject(nativeTitle:GetFontObject() or GameFontNormal)
        header.title:SetWordWrap(false)
        if titleContainer then
            header.title:SetPoint("TOPLEFT", titleContainer, "TOPLEFT", 0, -5)
            header.title:SetPoint("TOPRIGHT", titleContainer, "TOPRIGHT", 0, -5)
        else
            header.title:SetPoint("TOPLEFT", ProfessionsFrame, "TOPLEFT", 58, -6)
            header.title:SetPoint("TOPRIGHT", ProfessionsFrame, "TOPRIGHT", -24, -6)
        end
        professionPicker.header = header
    end

    professionPicker.headerActive = active
    nativeTitle:SetAlpha(active and 0 or 1)
    nativePortrait:SetAlpha(active and 0 or 1)
    header:SetShown(active)
    header.portraitFrame:SetShown(active)
    if active then professionPicker.UpdateHeader() end
end

function professionPicker.UpdateHeader()
    local header = professionPicker.header
    if not header or not professionPicker.headerActive or not professionPicker.key then return end
    local info = professionPicker.GetInfo(professionPicker.key)
    header.title:SetText(TRADE_SKILL_TITLE and TRADE_SKILL_TITLE:format(info.name) or info.name)
    header.portrait:SetTexture(info.icon or TrainerSpells:GetProfessionIcon(info.key))
end

function professionPicker.Reset()
    local openKey = GetOpenProfession()
    local owned = professionPicker.GetLists()
    professionPicker.key = openKey or (owned[1] and owned[1].key)
    professionPicker.UpdateText()
end

function professionPicker.Select(professionKey)
    professionPicker.key = professionKey
    TrainerSpells_ProfessionRefresh()
end

function professionPicker.Create()
    if professionPicker.dropdown or not (MenuUtil and MenuUtil.CreateRootMenuDescription) then return end
    local dropdown = CreateFrame("DropdownButton", "TrainerSpellsProfessionPicker", nil, "WowStyle1DropdownTemplate")
    dropdown:SetParent(professionFrame)
    dropdown:SetSize(180, 26)
    professionPicker.menuGenerator = function(_, rootDescription)
        for groupIndex, group in ipairs({professionPicker.GetLists()}) do
            if #group > 0 then
                rootDescription:CreateTitle(TrainerSpells:Trans(groupIndex == 1 and "LID_YOURPROFESSIONS" or "LID_OTHERPROFESSIONS"))
                for _, info in ipairs(group) do
                    local professionKey = info.key
                    rootDescription:CreateRadio(professionPicker.GetLabel(info), function() return professionPicker.key == professionKey end, function() professionPicker.Select(professionKey) end)
                end
            end
        end
    end

    dropdown:SetupMenu(professionPicker.menuGenerator)
    professionPicker.dropdown = dropdown
    professionPicker.measure = dropdown:CreateFontString(nil, "ARTWORK")
    professionPicker.measure:SetPoint("TOPLEFT")
    professionPicker.measure:SetAlpha(0)
end

function professionPicker.SelectNext()
    local owned, others = professionPicker.GetLists()
    local keys = {}
    for _, info in ipairs(owned) do table.insert(keys, info.key) end
    for _, info in ipairs(others) do table.insert(keys, info.key) end
    if #keys == 0 then return end
    local current = professionPicker.GetActive()
    local nextIndex = 1
    for index, key in ipairs(keys) do
        if key == current then nextIndex = index % #keys + 1 end
    end

    professionPicker.Select(keys[nextIndex])
end

function professionPicker.ApplyInputMode()
    local dropdown = professionPicker.dropdown
    if not dropdown then return end
    dropdown:Show()
    if TrainerSpells.IsGamepadNavActive() then
        dropdown:ClearMenuState()
        dropdown:SetScript("OnMouseDown", professionPicker.SelectNext)
    else
        dropdown:SetScript("OnMouseDown", nil)
        dropdown:SetupMenu(professionPicker.menuGenerator)
    end

    professionPicker.UpdateText()
end

function professionPicker.GetRankRange(rank)
    return rank == 1 and 1 or rank * 75 - 100, rank * 75
end

function professionPicker.GetRankTrainers(trainers, minRank, exactRank)
    local result = {}
    for _, trainer in ipairs(trainers) do
        if (exactRank and trainer.rank == exactRank) or (not exactRank and trainer.rank >= minRank) then table.insert(result, trainer) end
    end
    return result
end

function professionPicker.GetNearestTrainer(trainers, rank)
    return TrainerSpells.TrainerLocations.FindNearest(TrainerSpells:GetTrainerLocationEntries(professionPicker.GetRankTrainers(trainers, rank), "", true))
end

function professionPicker.AddTrainerItems(items, professionKey, trainers, searchText)
    local maxRank = 0
    for _, trainer in ipairs(trainers) do maxRank = math.max(maxRank, trainer.rank or 1) end
    local professionIcon = TrainerSpells:GetProfessionIcon(professionKey)
    for rank = 1, maxRank do
        local entries = TrainerSpells:GetTrainerLocationEntries(professionPicker.GetRankTrainers(trainers, rank, rank), searchText)
        if #entries > 0 then
            local rankName = TrainerSpells:Trans("LID_PROFRANK_" .. rank)
            local minSkill, maxSkill = professionPicker.GetRankRange(rank)
            local groupPrefix = "profession_trainer_" .. professionKey .. "_rank" .. rank .. "_"
            TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_PROFTRAINER_RANKHEADER"):format(rankName, minSkill, maxSkill), "|cffffd100", nil, groupPrefix .. "group")
            if not TrainerSpells:IsGroupCollapsed(groupPrefix .. "group") then
                table.insert(items, {isNearestTrainer = true, rowDepth = 1, rank = rank, rankName = rankName, icon = professionIcon, nearest = professionPicker.GetNearestTrainer(trainers, rank), findNearest = function() return professionPicker.GetNearestTrainer(trainers, rank) end})
                for _, entry in ipairs(entries) do
                    if not entry.displayID then entry.icon = professionIcon end
                end
                TrainerSpells:AddTrainerLocationItems(items, entries, groupPrefix, 1)
            end
        end
    end
    professionPicker.AddSpecTrainerItems(items, professionKey, searchText, professionIcon)
end

function professionPicker.GetSpecName(spec)
    for _, spellID in ipairs(spec.spells) do
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if spellInfo and spellInfo.name and spellInfo.name ~= "" then return spellInfo.name end
    end
    return spec.name
end

function professionPicker.AddSpecTrainerItems(items, professionKey, searchText, professionIcon)
    local specs = TrainerSpellsProfessionSpecTrainers and TrainerSpellsProfessionSpecTrainers[professionKey]
    if not specs then return end
    for _, spec in ipairs(specs) do
        local entries = TrainerSpells:GetTrainerLocationEntries(spec.trainers, searchText)
        if #entries > 0 then
            local specName = professionPicker.GetSpecName(spec)
            local groupPrefix = "profession_trainer_" .. professionKey .. "_spec" .. spec.spells[1] .. "_"
            TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_PROFTRAINER_SPECHEADER"):format(specName), "|cffff8000", nil, groupPrefix .. "group")
            if not TrainerSpells:IsGroupCollapsed(groupPrefix .. "group") then
                local function FindNearest()
                    return TrainerSpells.TrainerLocations.FindNearest(TrainerSpells:GetTrainerLocationEntries(spec.trainers, "", true))
                end
                table.insert(items, {isNearestTrainer = true, rowDepth = 1, rankName = specName, icon = professionIcon, nearest = FindNearest(), findNearest = FindNearest})
                for _, entry in ipairs(entries) do
                    if not entry.displayID then entry.icon = professionIcon end
                end
                TrainerSpells:AddTrainerLocationItems(items, entries, groupPrefix, 1)
            end
        end
    end
end

TrainerSpells.TrainerLocations.AddResolveListener(function()
    if professionFrame:IsVisible() and professionViewMode == PROFESSION_VIEW_TRAINERS then TrainerSpells_ProfessionRefresh() end
end)

function TrainerSpells:BuildProfessionViewItems(viewMode, searchText, professionKey, skillLineName, currentSkill)
    searchText = (searchText or ""):lower()
    local items = {}
    if viewMode == PROFESSION_VIEW_RECIPES then
        local data = professionKey and TrainerSpells_RecipeData and TrainerSpells_RecipeData[professionKey]
        if data and next(data) then
            local groups = TrainerSpells:ClassifyEntries(data, searchText, currentSkill, true, professionKey)
            MarkProfessionEntries(groups, professionKey, true)
            TrainerSpells:AppendGroupItems(items, groups, "tradeskillrecipe_", nil, TrainerSpells:Trans("LID_SKILL"), nil, nil, "skill")
        end

        if #items == 0 then TrainerSpells:AddHeaderItem(items, skillLineName and TrainerSpells:Trans("LID_NORECIPEDATAFOR"):format(skillLineName) or TrainerSpells:Trans("LID_NOPROFESSIONDETECTED"), "|cffaaaaaa") end
    elseif viewMode == PROFESSION_VIEW_TRAINERS then
        local trainers = professionKey and TrainerSpellsProfessionTrainers and TrainerSpellsProfessionTrainers[professionKey]
        if trainers then professionPicker.AddTrainerItems(items, professionKey, trainers, searchText) end
        if #items == 0 then TrainerSpells:AddHeaderItem(items, skillLineName and TrainerSpells:Trans("LID_NOTRAINERDATAFOR"):format(skillLineName) or TrainerSpells:Trans("LID_NOPROFESSIONDETECTED"), "|cffaaaaaa") end
    else
        local data = professionKey and TrainerSpells_ProfessionData and TrainerSpells_ProfessionData[professionKey]
        if data and next(data) then
            local groups = TrainerSpells:ClassifyEntries(data, searchText, currentSkill, true, professionKey)
            MarkProfessionEntries(groups, professionKey, false)
            TrainerSpells:AppendGroupItems(items, groups, "tradeskillprofession_", nil, TrainerSpells:Trans("LID_SKILL"), nil, nil, "skill")
        end

        if #items == 0 then TrainerSpells:AddHeaderItem(items, skillLineName and TrainerSpells:Trans("LID_NODATAFOR"):format(skillLineName) or TrainerSpells:Trans("LID_NOPROFESSIONDETECTED"), "|cffaaaaaa") end
    end

    TrainerSpells:AddCostColumn(items)
    return items
end

function TrainerSpells_ProfessionRefresh()
    local key, name, rank = professionPicker.GetActive()
    professionScrollBox:SetDataProvider(CreateDataProvider(TrainerSpells:BuildProfessionViewItems(professionViewMode, TrainerSpells_ProfessionSearchText, key, name, rank)), ScrollBoxConstants.RetainScrollPosition)
    if TrainerSpells.CompendiumProfessionView then TrainerSpells.CompendiumProfessionView:Refresh() end
    professionPicker.UpdateText()
end

local professionSubTabs = {}
function professionSubTabs.GetSavedView()
    local saved = TrainerSpells_Character and TrainerSpells_Character.professionView
    for _, view in ipairs(PROFESSION_SUB_VIEWS) do
        if view.mode == saved then return saved end
    end
    return PROFESSION_SUB_VIEWS[1] and PROFESSION_SUB_VIEWS[1].mode or PROFESSION_VIEW_SKILL
end

function professionSubTabs.Update()
    if not professionSubTabs.bar then return end
    for index, view in ipairs(PROFESSION_ALL_VIEWS) do
        if view.mode == professionViewMode then
            professionSubTabs.bar:SetTabVisuallySelected(index)
            professionSubTabs.title:SetText(TrainerSpells:Trans(view.title))
            professionSubTabs.desc:SetText(TrainerSpells:Trans(view.desc))
        end
    end
end

function professionSubTabs.Select(mode)
    professionViewMode = mode
    if TrainerSpells_Character then TrainerSpells_Character.professionView = mode end
    professionSubTabs.Update()
    if professionSubTabs.UpdateModeTabs then professionSubTabs.UpdateModeTabs() end
    if professionFrame.compendiumHost then TrainerSpells:PositionCompendiumProfessions() end
    TrainerSpells_ProfessionRefresh()
end

function professionSubTabs.Create()
    if professionSubTabs.bar then return end
    local bar = CreateFrame("Frame", "TrainerSpellsProfessionSubTabs", professionFrame, "TabSystemTemplate")
    professionSubTabs.bar = bar
    bar:SetTabSelectedCallback(function(tabID)
        local view = PROFESSION_ALL_VIEWS[tabID]
        if view then professionSubTabs.Select(view.mode) end
        return true
    end)

    for index, view in ipairs(PROFESSION_ALL_VIEWS) do
        bar:AddTab(nil, view.icon)
        bar:GetTabButton(index):SetTooltipText(TrainerSpells:Trans(view.title) .. "\n|cffffffff" .. TrainerSpells:Trans(view.desc) .. "|r")
        bar:SetTabShown(index, IsProfessionViewEnabled(view.mode))
    end

    bar:Layout()
    local panel = CreateFrame("Frame", nil, professionFrame)
    TrainerSpells:AddContentBorder(panel, professionFrame)
    professionSubTabs.panel = panel
    local title = professionFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    professionSubTabs.title = title
    local desc = professionFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(false)
    desc:SetTextColor(0.75, 0.75, 0.75)
    professionSubTabs.desc = desc
    professionSubTabs.spoilerFree = TrainerSpells:CreateSpoilerFreeCheckbox(professionFrame, "professionSpoilerFree", "LID_PROFSPOILERFREE_DESC", TrainerSpells_ProfessionRefresh)
    professionSubTabs.Update()
end

function professionSubTabs.InstallGamepadFocus()
    if not IsKeyDown then return end
    local driver = CreateFrame("Frame", nil, professionFrame)
    local focused, gamepadState, scrolledTo
    local function SetFocused(current)
        if current == focused then return end
        if focused and focused.tsOnLeave then focused.tsOnLeave(focused) end
        focused = current
        if focused and focused.tsOnEnter then focused.tsOnEnter(focused) end
    end

    driver:SetScript("OnShow", function()
        gamepadState = TrainerSpells.IsGamepadNavActive()
        TrainerSpells:PrepareGamepadNavigation(professionFrame, gamepadState)
    end)

    driver:SetScript("OnHide", function()
        scrolledTo = nil
        SetFocused(nil)
    end)

    driver:SetScript("OnUpdate", function()
        local gamepad = TrainerSpells.IsGamepadNavActive()
        if gamepad ~= gamepadState then
            gamepadState = gamepad
            TrainerSpells:PrepareGamepadNavigation(professionFrame, gamepad)
            if professionPicker.dropdown and professionPicker.dropdown:IsShown() then professionPicker.ApplyInputMode() end
            TrainerSpells_ProfessionRefresh()
        end

        local current = gamepad and SmartNavigation:GetCurrentButton() or nil
        if current ~= scrolledTo then
            scrolledTo = current
            local row = current and current.tsRow
            if row and row.GetElementData and row:GetParent() == professionScrollBox:GetScrollTarget() then professionScrollBox:ScrollToElementData(row:GetElementData(), ScrollBoxConstants.AlignNearest) end
        end

        SetFocused(current and current.tsFocusStripped and current or nil)
    end)
end

professionSubTabs.InstallGamepadFocus()
function professionSubTabs.PrewarmRows()
    if professionFrame.compendiumHost or professionFrame:IsShown() then return end
    TrainerSpells.RunDetached(professionFrame, function()
        local rowHeight = TrainerSpells.ProfessionRowHeight
        TrainerSpells.ProfessionRowHeight = TrainerSpells.MinRowHeight
        professionScrollBox:ClearAllPoints()
        professionScrollBox:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        professionScrollBox:SetSize(420, 1200)
        local items = {}
        for index = 1, math.ceil(1200 / TrainerSpells.MinRowHeight) + 2 do
            items[index] = {
                entry = {
                    name = ""
                }
            }
        end

        professionFrame:Show()
        professionScrollBox:SetDataProvider(CreateDataProvider(items))
        professionFrame:Hide()
        professionScrollBox:RemoveDataProvider()
        TrainerSpells.ProfessionRowHeight = rowHeight
        professionScrollBox:ClearAllPoints()
        professionScrollBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 8, -4)
        professionScrollBox:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", -26, 12)
    end)
end

function TrainerSpells:PositionCompendiumProfessions()
    local host = professionFrame.compendiumHost
    if not host then return end
    local panel = professionSubTabs.panel
    professionFrame:ClearAllPoints()
    professionFrame:SetAllPoints(host)
    panel:ClearAllPoints()
    panel:SetAllPoints(host)
    professionSubTabs.bar:Hide()
    professionSubTabs.spoilerFree:Hide()
    professionSubTabs.title:ClearAllPoints()
    professionSubTabs.title:SetPoint("BOTTOMLEFT", host.professionTabs[#host.professionTabs], "BOTTOMRIGHT", 12, 17)
    professionSubTabs.title:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", -180, 17)
    professionSubTabs.desc:ClearAllPoints()
    professionSubTabs.desc:SetPoint("TOPLEFT", professionSubTabs.title, "BOTTOMLEFT", 0, -3)
    professionSubTabs.desc:SetPoint("TOPRIGHT", professionSubTabs.title, "BOTTOMRIGHT", 0, -3)
    professionSubTabs.title:Show()
    professionSubTabs.desc:Show()
    for index, tab in ipairs(host.professionTabs) do
        tab:SetTabSelected(tab.mode == professionViewMode)
        AzerothCompendiumAPI.PositionContentTab(tab, host, host.professionTabs[index - 1])
    end
    if professionPicker.dropdown then
        professionPicker.dropdown:ClearAllPoints()
        professionPicker.dropdown:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", 0, 2)
    end
    professionSearchBox:Hide()
    AzerothCompendiumAPI.PositionHeaderSlider(professionRowHeightSlider)
    professionScrollBox:ClearAllPoints()
    professionScrollBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -4)
    professionScrollBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -20, 0)
    professionScrollBar:ClearAllPoints()
    professionScrollBar:SetPoint("TOPLEFT", panel, "TOPRIGHT", -16, -6)
    professionScrollBar:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", -16, 8)
    panel.borderFrame:SetFrameLevel(professionScrollBox:GetFrameLevel() + 20)
    professionScrollBar:SetFrameLevel(panel.borderFrame:GetFrameLevel() + 1)
    panel:Show()
end

local function PositionProfessionFrame()
    if professionFrame.compendiumHost then TrainerSpells:PositionCompendiumProfessions(); return end
    professionFrame:ClearAllPoints()
    if professionFrame.compendiumHost then
        professionFrame:SetScale(1)
        professionFrame:SetAllPoints(professionFrame.compendiumHost)
    elseif ProfessionsFrame and ProfessionsFrame:IsShown() then
        professionFrame:SetScale(1)
        professionFrame:SetPoint("TOPLEFT", ProfessionsFrame, "TOPLEFT", 3, -21)
        professionFrame:SetPoint("BOTTOMRIGHT", ProfessionsFrame, "BOTTOMRIGHT", -3, 3)
    elseif TradeSkillFrame and TradeSkillFrame:IsShown() then
        if TrainerSpells:IsDragonflightUIEnabled() and DragonflightUIProfessionFrame and DragonflightUIProfessionFrame:IsShown() then
            professionFrame:SetScale(DragonflightUIProfessionFrame:GetScale())
            professionFrame:SetPoint("TOPLEFT", DragonflightUIProfessionFrame, "TOPLEFT", -4, -24)
            professionFrame:SetPoint("BOTTOMRIGHT", DragonflightUIProfessionFrame, "BOTTOMRIGHT", -4, 4)
        elseif TrainerSpells:IsLeatrixWideProfessionEnabled() then
            professionFrame:SetScale(TradeSkillFrame:GetScale())
            professionFrame:SetPoint("TOPLEFT", TradeSkillFrame, "TOPLEFT", 14, -70)
            professionFrame:SetPoint("BOTTOMRIGHT", TradeSkillFrame, "BOTTOMRIGHT", -36, 70)
        else
            professionFrame:SetScale(TradeSkillFrame:GetScale())
            professionFrame:SetPoint("TOPLEFT", TradeSkillFrame, "TOPLEFT", 14, -70)
            professionFrame:SetPoint("BOTTOMRIGHT", TradeSkillFrame, "BOTTOMRIGHT", -36, 70)
        end
    else
        professionFrame:SetScale(1)
        professionFrame:SetPoint("CENTER")
    end

    professionSearchBox:ClearAllPoints()
    professionScrollBox:ClearAllPoints()
    if professionFrame.compendiumHost or (ProfessionsFrame and ProfessionsFrame:IsShown()) then
        local panel = professionSubTabs.panel
        if panel then
            local tabsLayout = not professionFrame.compendiumHost and TrainerSpells:GetTabLayout("professionLayout") == "tabs"
            panel:Show()
            professionSubTabs.bar:SetShown(not tabsLayout)
            professionSubTabs.title:Show()
            professionSubTabs.desc:Show()
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 8, -52)
            panel:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", -8, 8)
            professionSubTabs.bar:ClearAllPoints()
            professionSubTabs.bar:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 56, -2)
            professionSubTabs.title:ClearAllPoints()
            professionSubTabs.title:SetPoint("TOPLEFT", professionSubTabs.bar, tabsLayout and "TOPLEFT" or "TOPRIGHT", tabsLayout and 0 or 12, 6)
            if professionPicker.dropdown then
                professionPicker.dropdown:ClearAllPoints()
                professionPicker.dropdown:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -2, 9)
                professionSubTabs.title:SetPoint("TOPRIGHT", professionPicker.dropdown, "TOPLEFT", -12, 1)
            else
                professionSubTabs.title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, 36)
            end
            professionSubTabs.desc:ClearAllPoints()
            professionSubTabs.desc:SetPoint("TOPLEFT", professionSubTabs.title, "BOTTOMLEFT", 0, -3)
            professionSubTabs.desc:SetPoint("TOPRIGHT", professionSubTabs.title, "BOTTOMRIGHT", 0, -3)
            local sliderScale = professionRowHeightSlider:GetScale()
            professionSearchBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -8)
            professionSearchBox:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -300, -8)
            local spoilerFree = professionSubTabs.spoilerFree
            spoilerFree:ClearAllPoints()
            spoilerFree:SetPoint("LEFT", professionSearchBox, "RIGHT", 10, 0)
            spoilerFree:SetChecked(TrainerSpells_Character.professionSpoilerFree and true or false)
            spoilerFree:Show()
            professionRowHeightSlider:ClearAllPoints()
            professionRowHeightSlider:SetPoint("LEFT", spoilerFree.text, "RIGHT", 10 / sliderScale, 0)
            professionRowHeightSlider:SetPoint("RIGHT", panel, "TOPRIGHT", -30 / sliderScale, -18 / sliderScale)
            professionScrollBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -34)
            professionScrollBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -20, 0)
            professionScrollBar:ClearAllPoints()
            professionScrollBar:SetPoint("TOPLEFT", panel, "TOPRIGHT", -16, -36)
            professionScrollBar:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", -16, 8)
            panel.borderFrame:SetFrameLevel(professionScrollBox:GetFrameLevel() + 20)
            professionScrollBar:SetFrameLevel(panel.borderFrame:GetFrameLevel() + 1)
            if professionFrame.compendiumHost then
                professionSearchBox:Hide()
                spoilerFree:Hide()
                professionRowHeightSlider:ClearAllPoints()
                professionRowHeightSlider:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -24, -12)
                professionRowHeightSlider:SetWidth(168 / sliderScale)
                professionScrollBox:ClearAllPoints()
                professionScrollBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -4)
                professionScrollBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -20, 0)
                professionScrollBar:ClearAllPoints()
                professionScrollBar:SetPoint("TOPLEFT", panel, "TOPRIGHT", -16, -6)
                professionScrollBar:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", -16, 8)
            end
        else
            professionSearchBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 64, -6)
            professionSearchBox:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -10, -6)
            professionRowHeightSlider:ClearAllPoints()
            professionRowHeightSlider:SetPoint("TOPLEFT", professionSearchBox, "BOTTOMLEFT", 0, -9)
            professionRowHeightSlider:SetPoint("TOPRIGHT", professionSearchBox, "BOTTOMRIGHT", -24, -14)
            professionScrollBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 8, -54)
            professionScrollBox:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", -26, 12)
        end
    elseif TrainerSpells:IsDragonflightUIEnabled() and DragonflightUIProfessionFrame and DragonflightUIProfessionFrame:IsShown() then
        professionSearchBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 80, 0)
        professionSearchBox:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -10, 0)
        professionScrollBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 8, -64)
        professionScrollBox:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", -26, 12)
    elseif TrainerSpells:IsLeatrixWideProfessionEnabled() then
        local titleText = TradeSkillFrame and _G["TradeSkillFrameTitleText"]
        if titleText and professionFrame:GetTop() and titleText:GetBottom() then
            local topOffset = titleText:GetBottom() - professionFrame:GetTop() - 4
            professionSearchBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 66, topOffset)
            professionSearchBox:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -4, topOffset)
        else
            professionSearchBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 10, -6)
            professionSearchBox:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -30, -10)
        end

        professionScrollBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 0, -4)
        professionScrollBox:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", -26, -12)
    else
        local titleText = TradeSkillFrame and _G["TradeSkillFrameTitleText"]
        if titleText and professionFrame:GetTop() and titleText:GetBottom() then
            local topOffset = titleText:GetBottom() - professionFrame:GetTop() - 4
            professionSearchBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 66, topOffset)
            professionSearchBox:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -4, topOffset)
        else
            professionSearchBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 10, -6)
            professionSearchBox:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -30, -6)
        end

        professionScrollBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 8, -4)
        professionScrollBox:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", -26, 12)
    end
end

if TradeSkillFrame then hooksecurefunc(TradeSkillFrame, "SetScale", function() if classFrame:IsShown() then PositionProfessionFrame() end end) end
local function CreateTradeSkillTab(name, icon)
    local tab = CreateFrame("Button", name, UIParent)
    tab:SetSize(32, 32)
    tab:SetNormalTexture(icon)
    tab:SetHighlightTexture(130718, "ADD")
    tab:SetFrameStrata("HIGH")
    tab:SetFrameLevel(500)
    tab:Hide()
    local border = tab:CreateTexture(name .. "Border", "BACKGROUND")
    border:SetSize(64, 64)
    border:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
    border:SetTexture(136831)
    local glow = tab:CreateTexture(nil, "OVERLAY")
    glow:SetSize(32, 32)
    glow:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    glow:SetTexture(130724)
    glow:SetBlendMode("ADD")
    glow:Hide()
    return tab, glow
end

local nativeTab, nativeTabGlow = CreateTradeSkillTab("TrainerSpellsTradeSkillNativeTab", "Interface\\Icons\\ability_kick")
local professionTab, professionTabGlow = CreateTradeSkillTab("TrainerSpellsTradeSkillProfessionTab", "Interface\\Icons\\INV_Misc_Book_09")
local recipeTab, recipeTabGlow = CreateTradeSkillTab("TrainerSpellsTradeSkillRecipeTab", "Interface\\Icons\\INV_Scroll_03")
local function PositionTradeSkillTabs()
    C_Timer.After(TrainerSpells:IsDragonflightUIEnabled() and 0.1 or 0, function()
        if TrainerSpells:IsDragonflightUIEnabled() and DragonflightUIProfessionFrame and DragonflightUIProfessionFrame:IsShown() then
            local scale = DragonflightUIProfessionFrame:GetScale()
            nativeTab:SetScale(scale)
            professionTab:SetScale(scale)
            recipeTab:SetScale(scale)
            nativeTab:ClearAllPoints()
            nativeTab:SetPoint("TOPLEFT", DragonflightUIProfessionFrame, "TOPRIGHT", 0, -60)
            professionTab:ClearAllPoints()
            professionTab:SetPoint("TOPLEFT", nativeTab, "BOTTOMLEFT", 0, -36)
            recipeTab:ClearAllPoints()
            recipeTab:SetPoint("TOPLEFT", TrainerSpells:IsTabEnabled("profession_skill") and professionTab or nativeTab, "BOTTOMLEFT", 0, -36)
        else
            if TradeSkillFrame then
                local scale = TradeSkillFrame:GetScale()
                nativeTab:SetScale(scale)
                professionTab:SetScale(scale)
                recipeTab:SetScale(scale)
                nativeTab:ClearAllPoints()
                nativeTab:SetPoint("TOPLEFT", TradeSkillFrame, "TOPRIGHT", -33, -60)
                professionTab:ClearAllPoints()
                professionTab:SetPoint("TOPLEFT", nativeTab, "BOTTOMLEFT", 0, -36)
                recipeTab:ClearAllPoints()
                recipeTab:SetPoint("TOPLEFT", TrainerSpells:IsTabEnabled("profession_skill") and professionTab or nativeTab, "BOTTOMLEFT", 0, -36)
            end
        end
    end)
end

local NATIVE_TRADESKILL_WIDGETS = {"TradeSkillSubClassDropdown", "TradeSkillInvSlotDropdown", "TradeSkillRankFrame", "TradeSkillRankFrameBorder"}
local function HideNativeTradeSkillWidgets()
    for _, name in ipairs(NATIVE_TRADESKILL_WIDGETS) do
        local widget = _G[name]
        if widget then widget:Hide() end
    end
end

local function ShowNativeTradeSkillWidgets()
    for _, name in ipairs(NATIVE_TRADESKILL_WIDGETS) do
        local widget = _G[name]
        if widget then widget:Show() end
    end
end

local function SetTradeSkillView(mode)
    if professionFrame.compendiumHost then TrainerSpells:UndockCompendiumFrame(professionFrame) end
    if mode == PROFESSION_VIEW_SKILL or mode == PROFESSION_VIEW_RECIPES then
        professionViewMode = mode
        C_Timer.After(TrainerSpells:IsDragonflightUIEnabled() and 0.1 or 0, function()
            if professionFrame.compendiumHost then ShowNativeTradeSkillWidgets(); return end
            if TrainerSpells:IsDragonflightUIEnabled() and DragonflightUIProfessionFrame and DragonflightUIProfessionFrame:IsShown() then
                professionListBg:ClearAllPoints()
                professionListBg:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 4, -32)
                professionListBg:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", 4, -2)
                professionListBg:SetColorTexture(0, 0, 0, 1)
                if DragonflightUIProfessionRankFrame then DragonflightUIProfessionRankFrame:Hide() end
            elseif TrainerSpells:IsLeatrixWideProfessionEnabled() then
                professionListBg:ClearAllPoints()
                professionListBg:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 0, -2)
                professionListBg:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", -2, -16)
                professionListBg:SetColorTexture(0, 0, 0, 1)
            else
                professionListBg:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 4, -2)
                professionListBg:SetTexture("Interface\\AddOns\\TrainerSpells\\media\\inset")
                if TradeSkillFrameAvailableFilterCheckButton then TradeSkillFrameAvailableFilterCheckButton:Hide() end
                if TradeSearchInputBox then TradeSearchInputBox:Hide() end
            end

            PositionProfessionFrame()
            professionFrame:Show()
            nativeTabGlow:Hide()
            if mode == PROFESSION_VIEW_RECIPES then
                recipeTabGlow:Show()
                professionTabGlow:Hide()
            else
                professionTabGlow:Show()
                recipeTabGlow:Hide()
            end

            HideNativeTradeSkillWidgets()
            TrainerSpells_ProfessionRefresh()
        end)
    else
        professionFrame:Hide()
        professionTabGlow:Hide()
        recipeTabGlow:Hide()
        nativeTabGlow:Show()
        ShowNativeTradeSkillWidgets()
    end
end

nativeTab:SetScript("OnClick", function() SetTradeSkillView("native") end)
nativeTab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText((GetTradeSkillLine and GetTradeSkillLine()) or TrainerSpells:Trans("LID_PROFESSIONS"))
    GameTooltip:Show()
end)

nativeTab:SetScript("OnLeave", GameTooltip_Hide)
professionTab:SetScript("OnClick", function() SetTradeSkillView(PROFESSION_VIEW_SKILL) end)
professionTab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(TrainerSpells:Trans("LID_SKILL"))
    GameTooltip:Show()
end)

professionTab:SetScript("OnLeave", GameTooltip_Hide)
recipeTab:SetScript("OnClick", function() SetTradeSkillView(PROFESSION_VIEW_RECIPES) end)
recipeTab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(TrainerSpells:Trans("LID_RECIPES"))
    GameTooltip:Show()
end)

recipeTab:SetScript("OnLeave", GameTooltip_Hide)
local tradeSkillHooksInstalled = false
local function EnsureTradeSkillHooksInstalled()
    if tradeSkillHooksInstalled or not TradeSkillFrame then return end
    tradeSkillHooksInstalled = true
    TradeSkillFrame:HookScript("OnShow", function()
        PositionTradeSkillTabs()
        nativeTab:SetShown(TrainerSpells:IsTabEnabled("professions") and (TrainerSpells:IsTabEnabled("profession_skill") or TrainerSpells:IsTabEnabled("profession_recipes")))
        professionTab:SetShown(nativeTab:IsShown() and TrainerSpells:IsTabEnabled("profession_skill"))
        recipeTab:SetShown(nativeTab:IsShown() and TrainerSpells:IsTabEnabled("profession_recipes"))
        SetTradeSkillView("native")
    end)

    TradeSkillFrame:HookScript("OnHide", function()
        if professionFrame.compendiumHost then return end
        professionFrame:Hide()
        professionTabGlow:Hide()
        recipeTabGlow:Hide()
        nativeTabGlow:Hide()
        nativeTab:Hide()
        professionTab:Hide()
        recipeTab:Hide()
        ShowNativeTradeSkillWidgets()
    end)

    hooksecurefunc(TradeSkillFrame, "SetScale", function()
        PositionTradeSkillTabs()
        if professionFrame:IsShown() then PositionProfessionFrame() end
    end)

    if TradeSkillFrame:IsShown() then
        PositionTradeSkillTabs()
        nativeTab:SetShown(TrainerSpells:IsTabEnabled("professions") and (TrainerSpells:IsTabEnabled("profession_skill") or TrainerSpells:IsTabEnabled("profession_recipes")))
        professionTab:SetShown(nativeTab:IsShown() and TrainerSpells:IsTabEnabled("profession_skill"))
        recipeTab:SetShown(nativeTab:IsShown() and TrainerSpells:IsTabEnabled("profession_recipes"))
        SetTradeSkillView("native")
    end

    C_Timer.After(4, function()
        for i = 1, 4 do
            local t = _G["DragonflightUIProfessionFrameTabButton" .. i]
            if t then t:HookScript("OnClick", function() SetTradeSkillView("native") end) end
        end

        if DragonflightUIProfessionFrame then hooksecurefunc(DragonflightUIProfessionFrame, "SetScale", function() if professionFrame:IsShown() then PositionProfessionFrame() end end) end
    end)
end

local professionsFrameHooksInstalled = false
local professionsModeTabContainer
local professionsModeTabs = {}
local professionsViewTabs = {}
local professionsModeActive = false
local professionsFrameUsesSideTabs = false
local professionsClosePending = false
local professionsRestorePending = false
local function IsProfessionsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function IsProfessionsTabsLayout()
    return TrainerSpells:GetTabLayout("professionLayout") == "tabs"
end

local function GetProfessionsActiveTabs()
    local tabs = {}
    if IsProfessionsTabsLayout() then
        for _, view in ipairs(PROFESSION_ALL_VIEWS) do
            if professionsViewTabs[view.mode] and IsProfessionViewEnabled(view.mode) then table.insert(tabs, professionsViewTabs[view.mode]) end
        end
    elseif professionsModeTabs.addon then
        table.insert(tabs, professionsModeTabs.addon)
    end
    return tabs
end

local function UpdateProfessionsTabsCombatState()
    local locked = IsProfessionsCombatLocked()
    for _, list in ipairs({professionsModeTabs, professionsViewTabs}) do
        for _, tab in pairs(list) do
            tab.combatLocked = locked
            tab:SetAlpha(locked and 0.5 or 1)
            if tab.Icon and tab.Icon.SetDesaturated then tab.Icon:SetDesaturated(locked) end
        end
    end
end

function professionSubTabs.IsOwnSideTab(frame, depth)
    if not frame or depth > 10 then return false end
    if frame == professionsModeTabs.addon then return true end
    for _, tab in pairs(professionsViewTabs) do
        if frame == tab then return true end
    end
    if not frame.GetNumPoints then return false end
    for index = 1, frame:GetNumPoints() do
        local _, relativeTo = frame:GetPoint(index)
        if relativeTo and relativeTo ~= ProfessionsFrame and professionSubTabs.IsOwnSideTab(relativeTo, depth + 1) then return true end
    end
    return false
end

function professionSubTabs.FindForeignSideTab(lastTab)
    local refLeft, floor = lastTab:GetLeft(), lastTab:GetBottom()
    if not refLeft or not floor then return nil end
    local found, foundBottom = nil, floor
    for _, parent in ipairs({ProfessionsFrame, ProfessionsFrameTabSideBar}) do
        for _, child in ipairs({parent:GetChildren()}) do
            if child ~= lastTab and child:IsShown() then
                local left, bottom, width, height = child:GetLeft(), child:GetBottom(), child:GetWidth(), child:GetHeight()
                if left and bottom and math.abs(left - refLeft) <= 8 and width <= 64 and height <= 64 and bottom < foundBottom and not professionSubTabs.IsOwnSideTab(child, 0) then found, foundBottom = child, bottom end
            end
        end
    end
    return found
end

local function PositionProfessionsFrameModeTabs()
    if not ProfessionsFrame then return end
    if not professionsModeTabs.addon then return end
    for _, list in ipairs({professionsModeTabs, professionsViewTabs}) do
        for _, tab in pairs(list) do tab:ClearAllPoints() end
    end
    local previous = nil
    if professionsFrameUsesSideTabs then
        local lastTab = ProfessionsFrame.ProfessionsOverviewTab
        for _, tab in ipairs(ProfessionsFrame.rightProfessionTabs) do
            if tab:IsShown() then lastTab = tab end
        end

        lastTab = professionSubTabs.FindForeignSideTab(lastTab) or lastTab
        for _, tab in ipairs(GetProfessionsActiveTabs()) do
            if previous then
                tab:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -2)
            else
                tab:SetPoint("TOPLEFT", lastTab, "BOTTOMLEFT", 0, -16)
            end
            previous = tab
        end
    else
        professionsModeTabContainer:ClearAllPoints()
        professionsModeTabContainer:SetPoint("LEFT", ProfessionsFrame.TabSystem, "RIGHT", 20, 0)
        for _, tab in ipairs(GetProfessionsActiveTabs()) do
            if previous then
                tab:SetPoint("LEFT", previous, "RIGHT", 1, 0)
            else
                tab:SetPoint("LEFT", professionsModeTabContainer, "LEFT", 0, 0)
            end
            previous = tab
        end
    end
end

local function SetProfessionsModeTabSelected(tab, selected)
    if tab.SetTabSelected then
        tab:SetTabSelected(selected)
    else
        tab:SetChecked(selected)
    end
end

local function UpdateProfessionsViewTabSelection()
    for mode, tab in pairs(professionsViewTabs) do
        SetProfessionsModeTabSelected(tab, professionsModeActive and professionViewMode == mode)
    end
end
professionSubTabs.UpdateModeTabs = UpdateProfessionsViewTabSelection

local function CloseProfessionsFrameView()
    if professionFrame.compendiumHost then return end
    if IsProfessionsCombatLocked() then
        if professionsModeActive or professionFrame:IsShown() then professionsClosePending = true end
        return
    end

    professionsClosePending = false
    professionsModeActive = false
    professionPicker.SetHeaderActive(false)
    professionFrame:Hide()
    for _, tab in pairs(professionsModeTabs) do
        SetProfessionsModeTabSelected(tab, false)
    end
    UpdateProfessionsViewTabSelection()
end

local function RestoreProfessionsFramePage()
    if not professionsModeActive then return end
    if IsProfessionsCombatLocked() then
        professionsRestorePending = true
        return
    end

    professionsRestorePending = false
    if professionsFrameUsesSideTabs then
        if ProfessionsFrame.BookPage then ProfessionsFrame.BookPage:Hide() end
        if ProfessionsFrame.CraftingPage then ProfessionsFrame.CraftingPage:Show() end
    elseif ProfessionsFrame.GetTab and ProfessionsFrame.GetElementsForTab then
        local tabID = ProfessionsFrame:GetTab()
        for _, page in ipairs(tabID and ProfessionsFrame:GetElementsForTab(tabID) or {}) do
            page:Show()
        end
    end
end

local professionsCombatWatcher = CreateFrame("Frame")
professionsCombatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
professionsCombatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
professionsCombatWatcher:SetScript("OnEvent", function(_, event)
    UpdateProfessionsTabsCombatState()
    if event ~= "PLAYER_REGEN_ENABLED" then return end
    if professionsRestorePending then RestoreProfessionsFramePage() end
    if professionsClosePending then CloseProfessionsFrameView() end
end)

local function OpenProfessionsFrameView(mode)
    if professionFrame.compendiumHost then TrainerSpells:UndockCompendiumFrame(professionFrame) end
    if IsProfessionsCombatLocked() then
        if UIErrorsFrame and ERR_NOT_IN_COMBAT then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
        return
    end

    if mode and TrainerSpells_Character then TrainerSpells_Character.professionView = mode end
    professionViewMode = professionSubTabs.GetSavedView()
    professionPicker.Reset()
    professionsModeActive = true
    if ProfessionsFrame.Pages then
        for _, page in ipairs(ProfessionsFrame.Pages) do
            page:Hide()
        end
    else
        if ProfessionsFrame.BookPage then ProfessionsFrame.BookPage:Hide() end
        if ProfessionsFrame.CraftingPage then ProfessionsFrame.CraftingPage:Hide() end
    end

    if professionsFrameUsesSideTabs or professionSubTabs.panel then
        professionListBg:Hide()
    else
        professionListBg:ClearAllPoints()
        professionListBg:SetAllPoints(professionFrame)
        professionListBg:SetColorTexture(0, 0, 0, 1)
        professionListBg:Show()
    end

    PositionProfessionFrame()
    professionFrame:Show()
    for _, tab in pairs(professionsModeTabs) do
        SetProfessionsModeTabSelected(tab, true)
    end
    UpdateProfessionsViewTabSelection()

    if professionsFrameUsesSideTabs then
        ProfessionsFrame.ProfessionsOverviewTab:SetChecked(false)
        for _, tab in ipairs(ProfessionsFrame.rightProfessionTabs) do
            tab:SetChecked(false)
        end
    elseif ProfessionsFrame.TabSystem.SetTabVisuallySelected then
        ProfessionsFrame.TabSystem:SetTabVisuallySelected(0)
    end

    professionPicker.SetHeaderActive(true)
    if professionPicker.dropdown then
        professionPicker.dropdown:SetFrameLevel(professionFrame:GetFrameLevel() + 50)
        professionPicker.ApplyInputMode()
    end

    professionSubTabs.Update()
    TrainerSpells_ProfessionRefresh()
end

local function IsTradeSkillAddonEnabled()
    return TrainerSpells:IsTabEnabled("professions") and (IsProfessionViewEnabled(PROFESSION_VIEW_SKILL) or IsProfessionViewEnabled(PROFESSION_VIEW_RECIPES))
end

local function IsProfessionsFrameAddonEnabled()
    return TrainerSpells:IsTabEnabled("professions") and TrainerSpells:HasProfessionTabs()
end

local function ShowTradeSkillTabs()
    local enabled = IsTradeSkillAddonEnabled()
    nativeTab:SetShown(enabled)
    professionTab:SetShown(enabled and IsProfessionViewEnabled(PROFESSION_VIEW_SKILL))
    recipeTab:SetShown(enabled and IsProfessionViewEnabled(PROFESSION_VIEW_RECIPES))
end

local function ShowProfessionsModeTabs()
    local enabled = IsProfessionsFrameAddonEnabled() and ProfessionsFrame ~= nil and ProfessionsFrame:IsShown()
    local tabsLayout = IsProfessionsTabsLayout()
    if professionsModeTabs.addon then professionsModeTabs.addon:SetShown(enabled and not tabsLayout) end
    for mode, tab in pairs(professionsViewTabs) do
        tab:SetShown(enabled and tabsLayout and IsProfessionViewEnabled(mode))
    end
end

local function ApplyProfessionTabSettings()
    PROFESSION_SUB_VIEWS = TrainerSpells:FilterTabViews(PROFESSION_ALL_VIEWS, "profession_")
    if professionSubTabs.bar then
        for index, view in ipairs(PROFESSION_ALL_VIEWS) do
            professionSubTabs.bar:SetTabShown(index, IsProfessionViewEnabled(view.mode))
        end
    end

    local modeEnabled = IsProfessionViewEnabled(professionViewMode)
    if not modeEnabled and PROFESSION_SUB_VIEWS[1] then professionViewMode = PROFESSION_SUB_VIEWS[1].mode end
    if TradeSkillFrame and TradeSkillFrame:IsShown() then
        PositionTradeSkillTabs()
        ShowTradeSkillTabs()
        if professionFrame:IsShown() and not professionFrame.compendiumHost and (not IsTradeSkillAddonEnabled() or not modeEnabled) then SetTradeSkillView("native") end
    end

    local professionsEnabled = IsProfessionsFrameAddonEnabled()
    ShowProfessionsModeTabs()
    if ProfessionsFrame and professionsFrameHooksInstalled then PositionProfessionsFrameModeTabs() end
    if professionsModeActive then
        if not professionsEnabled then
            RestoreProfessionsFramePage()
            CloseProfessionsFrameView()
        else
            PositionProfessionFrame()
            UpdateProfessionsViewTabSelection()
            if not modeEnabled then TrainerSpells_ProfessionRefresh() end
        end
    end

    professionSubTabs.Update()
end

TrainerSpells:OnTabSettingsChanged(ApplyProfessionTabSettings)
local function CreateProfessionsFrameSystemTab(tabID, text, icon, mode)
    local tab = CreateFrame("Button", nil, professionsModeTabContainer, "TabSystemButtonTemplate")
    tab.GetTabSystem = function() return ProfessionsFrame.TabSystem end
    tab:Init(tabID, nil, icon)
    tab:SetTooltipText(text)
    tab:SetScript("OnClick", function(self) if not self.combatLocked then OpenProfessionsFrameView(mode) end end)
    tab:Show()
    if mode then professionsViewTabs[mode] = tab else professionsModeTabs.addon = tab end
    return tab
end

local function CreateProfessionsFrameSideTab(name, text, icon, mode)
    local tab = CreateFrame("Frame", name, ProfessionsFrame, "LargeSideTabButtonTemplate")
    tab:SetFrameLevel(ProfessionsFrame:GetFrameLevel() + 200)
    tab:EnableMouse(true)
    tab.Icon:SetTexture(icon)
    tab.Icon:SetSize(30, 30)
    tab.Icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
    tab.tooltipText = text
    tab:SetFillToInterior(true)
    tab:SetChecked(false)
    tab:SetCustomOnMouseUpHandler(function(self, button, upInside) if button == "LeftButton" and upInside and not self.combatLocked then OpenProfessionsFrameView(mode) end end)
    tab:Show()
    if mode then professionsViewTabs[mode] = tab else professionsModeTabs.addon = tab end
    return tab
end

local function InstallProfessionsFrameShoulderTabs()
    local indicators = ProfessionsFrame.TabIndicators
    if not (indicators and indicators.RightTabButton and IsKeyDown) then return end
    local driver = TrainerSpells.CreateDetachedFrame("Frame", ProfessionsFrame)
    local leftButton = CreateFrame("Button", "TrainerSpellsProfessionsShoulderLeft", UIParent)
    leftButton:SetSize(1, 1)
    leftButton:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10, 10)
    leftButton:EnableMouse(false)
    leftButton:RegisterForClicks("AnyDown")
    leftButton:SetScript("OnClick", function()
        if not professionsModeActive or IsProfessionsCombatLocked() then return end
        if IsProfessionsTabsLayout() then
            for index, view in ipairs(PROFESSION_SUB_VIEWS) do
                if view.mode == professionViewMode and index > 1 then
                    OpenProfessionsFrameView(PROFESSION_SUB_VIEWS[index - 1].mode)
                    return
                end
            end
        end
        local tab = indicators.visibleTabs and indicators.visibleTabs[indicators.currentIndex]
        if tab and tab == ProfessionsFrame.ProfessionsOverviewTab then
            if ProfessionsFrame.CraftingPage then ProfessionsFrame.CraftingPage:Hide() end
            if ProfessionsFrame.BookPage then ProfessionsFrame.BookPage:Show() end
        else
            RestoreProfessionsFramePage()
        end

        CloseProfessionsFrameView()
        if tab and tab.SetChecked then tab:SetChecked(true) end
    end)

    local leftBinding = "CLICK TrainerSpellsProfessionsShoulderLeft:LeftButton"
    local leftBound = false
    local function UpdateLeftBinding(active)
        if InCombatLockdown() then return end
        if active then
            if GetBindingAction("PADLSHOULDER", true) ~= leftBinding then SetOverrideBindingClick(leftButton, true, "PADLSHOULDER", leftButton:GetName(), "LeftButton") end
            leftBound = true
        elseif leftBound then
            ClearOverrideBindings(leftButton)
            leftBound = false
        end
    end

    driver:SetScript("OnHide", function() UpdateLeftBinding(false) end)
    local rightHeld, previousIndex = false, nil
    driver:SetScript("OnShow", function()
        rightHeld = IsKeyDown("PADRSHOULDER") and true or false
        previousIndex = nil
    end)

    driver:SetScript("OnUpdate", function()
        local down = IsKeyDown("PADRSHOULDER") and true or false
        local pressed = down and not rightHeld
        rightHeld = down
        local indexBefore = previousIndex
        previousIndex = indicators.currentIndex
        local activeTabs = GetProfessionsActiveTabs()
        local firstTab, lastTab = activeTabs[1], activeTabs[#activeTabs]
        local visible = firstTab and firstTab:IsShown() and indicators:IsVisible()
        UpdateLeftBinding(visible and professionsModeActive)
        if not visible then return end
        local rightButton = indicators.RightTabButton
        if select(2, rightButton:GetPoint(1)) ~= lastTab then
            rightButton:ClearAllPoints()
            rightButton:SetPoint("TOP", lastTab, "BOTTOM", 0, 0)
        end

        local tabsLayout = IsProfessionsTabsLayout()
        if pressed and professionsModeActive and tabsLayout and not firstTab.combatLocked then
            for index, view in ipairs(PROFESSION_SUB_VIEWS) do
                if view.mode == professionViewMode and PROFESSION_SUB_VIEWS[index + 1] then
                    OpenProfessionsFrameView(PROFESSION_SUB_VIEWS[index + 1].mode)
                    break
                end
            end
            return
        end

        local lastIndex = indicators.visibleTabs and #indicators.visibleTabs or 0
        if pressed and not professionsModeActive and not indicators.isLocked and lastIndex > 0 and indexBefore == lastIndex and indicators.currentIndex == lastIndex then
            C_Timer.After(0.05, function()
                if indicators.currentIndex == indexBefore and not professionsModeActive and ProfessionsFrame:IsVisible() and not firstTab.combatLocked then
                    OpenProfessionsFrameView(tabsLayout and PROFESSION_SUB_VIEWS[1] and PROFESSION_SUB_VIEWS[1].mode or nil)
                end
            end)
        end
    end)
end

local function InstallProfessionsFrameIntegration()
    if professionsFrameHooksInstalled or not ProfessionsFrame or professionFrame.compendiumHost then return end
    professionsFrameUsesSideTabs = ProfessionsFrame.ProfessionsOverviewTab and ProfessionsFrame.rightProfessionTabs and true or false
    if not professionsFrameUsesSideTabs and not ProfessionsFrame.TabSystem then return end
    professionsFrameHooksInstalled = true
    professionFrame:SetParent(ProfessionsFrame)
    professionFrame:SetFrameStrata(ProfessionsFrame:GetFrameStrata())
    professionFrame:SetFrameLevel(ProfessionsFrame:GetFrameLevel() + 300)
    TrainerSpells.RunDetached(professionFrame, function()
        professionSubTabs.Create()
        professionPicker.Create()
    end)

    professionSubTabs.PrewarmRows()
    if professionsFrameUsesSideTabs then
        CreateProfessionsFrameSideTab("TrainerSpellsProfessionsTab", "TrainerSpells", TrainerSpells:GetAddonIcon())
        for index, view in ipairs(PROFESSION_ALL_VIEWS) do
            CreateProfessionsFrameSideTab("TrainerSpellsProfessionsViewTab" .. index, TrainerSpells:Trans(view.title), view.icon, view.mode)
        end
        hooksecurefunc(ProfessionsFrame, "RefreshRightTabs", function()
            PositionProfessionsFrameModeTabs()
            C_Timer.After(0, PositionProfessionsFrameModeTabs)
        end)
        hooksecurefunc(ProfessionsFrame, "RightTabSelected", CloseProfessionsFrameView)
        InstallProfessionsFrameShoulderTabs()
    else
        professionsModeTabContainer = CreateFrame("Frame", "TrainerSpellsProfessionsModeTabs", ProfessionsFrame)
        professionsModeTabContainer:SetSize(260, math.max(32, ProfessionsFrame.TabSystem:GetHeight()))
        professionsModeTabContainer:SetFrameLevel(ProfessionsFrame.TabSystem:GetFrameLevel() + 200)
        CreateProfessionsFrameSystemTab(1001, "TrainerSpells", TrainerSpells:GetAddonIcon())
        for index, view in ipairs(PROFESSION_ALL_VIEWS) do
            CreateProfessionsFrameSystemTab(1001 + index, TrainerSpells:Trans(view.title), view.icon, view.mode)
        end
        hooksecurefunc(ProfessionsFrame, "SetTab", CloseProfessionsFrameView)
        if ProfessionsFrame.UpdateTabs then hooksecurefunc(ProfessionsFrame, "UpdateTabs", PositionProfessionsFrameModeTabs) end
    end

    UpdateProfessionsTabsCombatState()
    PositionProfessionsFrameModeTabs()
    ProfessionsFrame:HookScript("OnShow", function()
        RestoreProfessionsFramePage()
        ShowProfessionsModeTabs()
        PositionProfessionsFrameModeTabs()
        CloseProfessionsFrameView()
        C_Timer.After(0, PositionProfessionsFrameModeTabs)
    end)

    ProfessionsFrame:HookScript("OnHide", function()
        RestoreProfessionsFramePage()
        CloseProfessionsFrameView()
    end)

    hooksecurefunc(ProfessionsFrame, "SetScale", function() if professionFrame:IsShown() then PositionProfessionFrame() end end)
    ApplyProfessionTabSettings()
end

if ProfessionsFrame then
    InstallProfessionsFrameIntegration()
else
    local professionsFrameLoader = CreateFrame("Frame")
    professionsFrameLoader:RegisterEvent("ADDON_LOADED")
    professionsFrameLoader:SetScript("OnEvent", function(self, _, addonName)
        if addonName ~= "Blizzard_Professions" then return end
        self:UnregisterEvent("ADDON_LOADED")
        InstallProfessionsFrameIntegration()
    end)
end

local tradeSkillWatcher = CreateFrame("Frame")
for _, event in ipairs({"TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE", "PLAYER_MONEY", "UPDATE_FACTION"}) do
    TrainerSpells:RegisterEvent(tradeSkillWatcher, event)
end

tradeSkillWatcher:SetScript("OnEvent", function(_, event)
    EnsureTradeSkillHooksInstalled()
    InstallProfessionsFrameIntegration()
    if event == "TRADE_SKILL_SHOW" and professionsFrameHooksInstalled then C_Timer.After(0, PositionProfessionsFrameModeTabs) end
    if (event == "TRADE_SKILL_UPDATE" or event == "TRADE_SKILL_LIST_UPDATE") and professionFrame:IsShown() then
        TrainerSpells_ProfessionRefresh()
        if not professionFrame.compendiumHost then HideNativeTradeSkillWidgets() end
    elseif (event == "PLAYER_MONEY" or event == "UPDATE_FACTION") and professionFrame:IsShown() then
        TrainerSpells_ProfessionRefresh()
    end
end)

function professionPicker.PopulateCompendiumMenu(view, menu)
    for index, group in ipairs({professionPicker.GetLists()}) do
        if #group > 0 then
            menu:CreateTitle(TrainerSpells:Trans(index == 1 and "LID_YOURPROFESSIONS" or "LID_OTHERPROFESSIONS"))
            for _, info in ipairs(group) do
                local key = info.key
                menu:CreateRadio(professionPicker.GetLabel(info), function() return view.professionKey == key end, function() view.professionKey = key; view:Refresh() end)
            end
        end
    end
end

function TrainerSpells:CreateCompendiumProfessions(host)
    local view = self:CreateCompendiumListView(host, PROFESSION_ALL_VIEWS, professionSubTabs.GetSavedView(), self.ProfessionRowHeight, function(entry) return IsProfessionViewEnabled(entry.mode) end)
    self.CompendiumProfessionView = view
    view:AddSpoilerFreeCheckbox("professionSpoilerFree", "LID_PROFSPOILERFREE_DESC")
    view.BuildItems = function(current)
        if not current.professionKey then
            local owned, others = professionPicker.GetLists()
            current.professionKey = owned[1] and owned[1].key or others[1] and others[1].key
        end
        local info = current.professionKey and professionPicker.GetInfo(current.professionKey)
        if current.dropdown then
            current.dropdown:SetText(info and professionPicker.GetLabel(info) or TrainerSpells:Trans("LID_PROFESSIONS"))
            professionPicker.UpdateWidth(current.dropdown, current.measure)
            current.title:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", -current.dropdown:GetWidth() - 10, 17)
        end
        return TrainerSpells:BuildProfessionViewItems(current.mode, host.searchText, current.professionKey, info and info.name, info and info.rank or 0)
    end
    if MenuUtil and MenuUtil.CreateRootMenuDescription then
        view.dropdown = CreateFrame("DropdownButton", nil, host, "WowStyle1DropdownTemplate")
        view.dropdown:SetSize(180, 26)
        view.measure = view.dropdown:CreateFontString(nil, "ARTWORK")
        view.measure:SetPoint("TOPLEFT")
        view.measure:SetAlpha(0)
        view.dropdown:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", 0, 2)
        view.title:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", -190, 17)
        view.dropdown:SetupMenu(function(_, menu) professionPicker.PopulateCompendiumMenu(view, menu) end)
    end
    host:SetScript("OnShow", function() view:Refresh() end)
end