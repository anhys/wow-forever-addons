local _, TrainerSpells = ...
local classFrame = TrainerSpells.ClassFrame
TrainerSpells.ClassView = TrainerSpells.ClassView or "class"
local searchBox = CreateFrame("EditBox", "TrainerSpellsSearchBox", classFrame, "SearchBoxTemplate")
TrainerSpells.SearchBox = searchBox
searchBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", -60, -6)
searchBox:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -10, -6)
searchBox:SetHeight(20)
searchBox:SetAutoFocus(false)
searchBox:SetScript("OnTextChanged", function(self)
    if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(self) end
    TrainerSpells_SearchText = self:GetText() or ""
    TrainerSpells_Refresh()
end)

local rowHeightSlider = CreateFrame("Slider", "TrainerSpellsRowHeightSlider", classFrame, "MinimalSliderWithSteppersTemplate")
TrainerSpells.RowHeightSlider = rowHeightSlider
rowHeightSlider:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -8, -5)
rowHeightSlider:SetPoint("TOPRIGHT", searchBox, "BOTTOMRIGHT", -24, -14)
rowHeightSlider:SetScale(0.75)
rowHeightSlider:SetHeight(10)
rowHeightSlider:Init(TrainerSpells.RowHeight, TrainerSpells.MinRowHeight, TrainerSpells.MaxRowHeight, TrainerSpells.MaxRowHeight - TrainerSpells.MinRowHeight, {
    [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return WHITE_FONT_COLOR:WrapTextInColorCode(tostring(math.floor(value + 0.5))) end)
})

if rowHeightSlider.MinText then rowHeightSlider.MinText:Hide() end
if rowHeightSlider.MaxText then rowHeightSlider.MaxText:Hide() end
local scrollBox = CreateFrame("Frame", "TrainerSpellsScrollBox", classFrame, "WowScrollBoxList")
TrainerSpells.ClassScrollBox = scrollBox
TrainerSpells.ClassScrollTarget = scrollBox.ScrollTarget
scrollBox.ScrollTarget = nil
function scrollBox:GetScrollTarget() return TrainerSpells.ClassScrollTarget end
scrollBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 6, -4)
scrollBox:SetPoint("BOTTOMRIGHT", classFrame, "BOTTOMRIGHT", -24, 13)
local listBg = classFrame:CreateTexture("TrainerSpellsFrameBackground", "BACKGROUND")
TrainerSpells.ClassListBackground = listBg
local scrollBar = CreateFrame("EventFrame", "TrainerSpellsScrollBar", classFrame, "MinimalScrollBar")
scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, -2)
scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 2)
local scrollView = CreateScrollBoxListLinearView()
function scrollView:RefreshSmartNav() end
scrollView:SetElementExtentCalculator(function(_, elementData)
    if elementData.isHeader then return TrainerSpells.HeaderHeight + TrainerSpells.HeaderExtraGap end
    return TrainerSpells.RowHeight
end)

scrollView:SetPadding(0, 0, 0, 0, TrainerSpells.RowSpacing)
scrollView:SetElementInitializer("Frame", function(rowFrame, elementData)
    TrainerSpells:InitScrollRow(rowFrame, elementData, TrainerSpells.RowHeight)
    TrainerSpells:ApplyRowStripe(rowFrame, elementData)
    TrainerSpells:ApplyRowInteraction(rowFrame)
    TrainerSpells:PrepareGamepadNavigation(rowFrame)
end)
ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, scrollView)
rowHeightSlider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
    value = math.floor(value + 0.5)
    if value == TrainerSpells.RowHeight then return end
    TrainerSpells.RowHeight = value
    if TrainerSpells_Character then TrainerSpells_Character.rowHeight = TrainerSpells.RowHeight end
    if TrainerSpells_Refresh then TrainerSpells_Refresh() end
end)

function TrainerSpells:BuildClassViewItems(viewMode, searchText)
    searchText = (searchText or ""):lower()
    local selectedLevel = UnitLevel("player") or 1
    local selectedClass = select(2, UnitClass("player"))
    local classData = selectedClass and TrainerSpells_Data and TrainerSpells_Data[selectedClass]
    local items = {}
    if viewMode == "class" and classData then
        local groups = TrainerSpells:ClassifyEntries(classData, searchText, selectedLevel)
        TrainerSpells:AppendGroupItems(items, groups, "")
    end

    if viewMode == "pet" then
        if selectedClass == "WARLOCK" then TrainerSpells:AppendPetAbilities(items, searchText, selectedLevel) end
        if selectedClass == "HUNTER" then TrainerSpells:AppendPetTrainerAbilities(items, searchText, selectedLevel, selectedClass) end
    end

    if viewMode == "weapons" and TrainerSpells.BuildWeaponSkillItems then
        TrainerSpells:BuildWeaponSkillItems(items, searchText, selectedLevel)
    end

    if viewMode == "trainers" and TrainerSpells.BuildClassTrainerItems then
        TrainerSpells:BuildClassTrainerItems(items, searchText)
    end

    if #items == 0 then
        if viewMode == "weapons" or viewMode == "trainers" then
            TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_NOENTRIES"), "|cffaaaaaa")
        elseif not classData then
            TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_NODATAFORCLASS"):format(tostring(selectedClass)), "|cffff5555")
        else
            TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_NOENTRIES"), "|cffaaaaaa")
        end
    end

    TrainerSpells:AddCostColumn(items)
    return items
end

function TrainerSpells_Refresh()
    TrainerSpells.RunDetached(classFrame, function()
        scrollBox:SetDataProvider(CreateDataProvider(TrainerSpells:BuildClassViewItems(TrainerSpells.ClassView, TrainerSpells_SearchText)), ScrollBoxConstants.RetainScrollPosition)
        if ScrollBoxConstants.UpdateImmediately then scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately) end
    end)

    if TrainerSpells.CompendiumClassView then TrainerSpells.CompendiumClassView:Refresh() end
end

function TrainerSpells:HasPetClassData(classToken)
    if classToken == "HUNTER" then
        local data = TrainerSpells_PetTrainerData and TrainerSpells_PetTrainerData[classToken]
        if data and next(data) ~= nil then return true end
        return TrainerSpellsBuiltin_HunterPet and next(TrainerSpellsBuiltin_HunterPet) ~= nil
    end

    if classToken == "WARLOCK" then
        for _, petGroup in ipairs(TrainerSpells.PetGroups) do
            for _, key in ipairs(petGroup.keys) do
                local data = TrainerSpells_PetData and TrainerSpells_PetData[key]
                if data and next(data) then return true end
                local builtinData = TrainerSpellsBuiltin_WarlockPet and TrainerSpellsBuiltin_WarlockPet[key]
                if builtinData and next(builtinData) then return true end
            end
        end
    end

    return false
end

function TrainerSpells:SetClassView(view)
    if view == "pet" then
        local classToken = select(2, UnitClass("player"))
        if not TrainerSpells:HasPetClassData(classToken) then view = "class" end
    end

    TrainerSpells.ClassView = view
    if TrainerSpells_Character then TrainerSpells_Character.classView = view end
    if TrainerSpells.UpdateClassViewTabs then TrainerSpells:UpdateClassViewTabs() end
    if TrainerSpells_Refresh then TrainerSpells_Refresh() end
end

classFrame:SetScript("OnShow", function()
    if TrainerSpells_SyncPetSpells then TrainerSpells_SyncPetSpells() end
    TrainerSpells_Refresh()
end)

classFrame:RegisterEvent("PLAYER_LEVEL_UP")
classFrame:RegisterEvent("SPELLS_CHANGED")
classFrame:RegisterEvent("PLAYER_MONEY")
classFrame:RegisterEvent("UPDATE_FACTION")
classFrame:HookScript("OnEvent", function(self, event)
    if event == "PLAYER_LEVEL_UP" or event == "SPELLS_CHANGED" or event == "PLAYER_MONEY" or event == "UPDATE_FACTION" then TrainerSpells_Refresh() end
end)
