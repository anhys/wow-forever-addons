local _, TrainerSpells = ...
local trainerData = TrainerSpellsClassTrainers
if not trainerData then return end
local extraTrainerData = {}
for classToken, trainers in pairs(TrainerSpellsPetTrainers or {}) do extraTrainerData[classToken] = trainers end
for classToken, trainers in pairs(TrainerSpellsPortalTrainers or {}) do extraTrainerData[classToken] = trainers end
local TrainerLocations = TrainerSpells.TrainerLocations
local AddEntries = TrainerLocations.AddEntries
local SortEntries = TrainerLocations.SortEntries
local FindNearest = TrainerLocations.FindNearest
local SetNearestWaypoint = TrainerLocations.SetNearestWaypoint

local classFrame = TrainerSpells.ClassFrame
local petTrainerTexts = {
    HUNTER = {label = "LID_PETTRAINER", nearest = "LID_NEARESTPETTRAINER", desc = "LID_NEARESTPETTRAINER_DESC", none = "LID_NOPETTRAINER"},
    WARLOCK = {label = "LID_DEMONTRAINER", nearest = "LID_NEARESTDEMONTRAINER", desc = "LID_NEARESTDEMONTRAINER_DESC", none = "LID_NODEMONTRAINER"},
    MAGE = {label = "LID_PORTALTRAINER", nearest = "LID_NEARESTPORTALTRAINER", desc = "LID_NEARESTPORTALTRAINER_DESC", none = "LID_NOPORTALTRAINER"},
}

local function GetPlayerClassToken()
    return select(2, UnitClass("player"))
end

local function GetPetTrainerLabel(classToken)
    local texts = petTrainerTexts[classToken]
    return texts and TrainerSpells:Trans(texts.label)
end

local function GetEntries(searchText, usableOnly)
    local entries = {}
    AddEntries(entries, trainerData[GetPlayerClassToken()], searchText, usableOnly)
    return SortEntries(entries)
end

local function GetPetEntries(searchText, usableOnly)
    local entries = {}
    local classToken = GetPlayerClassToken()
    AddEntries(entries, extraTrainerData[classToken], searchText, usableOnly, GetPetTrainerLabel(classToken))
    return SortEntries(entries)
end

function TrainerSpells:BuildClassTrainerItems(items, searchText)
    local entries = GetEntries(searchText, false)
    for _, entry in ipairs(GetPetEntries(searchText, false)) do table.insert(entries, entry) end
    TrainerSpells:AddTrainerLocationItems(items, SortEntries(entries), "class_trainer_")
end

function TrainerSpells:GetNearestClassTrainer()
    return FindNearest(GetEntries("", true))
end

function TrainerSpells:GetNearestPetTrainer()
    return FindNearest(GetPetEntries("", true))
end

function TrainerSpells.CreateClassTrainerControls(addon, parent)
local controls = CreateFrame("Frame", nil, parent)
controls:SetHeight(36)
controls:Hide()
TrainerLocations.AddResolveListener(function()
    if controls:IsVisible() then TrainerSpells_Refresh() end
end)
local nearestButton = CreateFrame("Button", nil, controls, "MainMenuFrameButtonTemplate")
nearestButton:SetPoint("LEFT")
nearestButton:SetSize(200, 36)
nearestButton:SetText(TrainerSpells:Trans("LID_NEARESTCLASSTRAINER"))
nearestButton:SetWidth(math.max(200, nearestButton:GetTextWidth() + 40))
nearestButton:SetScript("OnClick", function()
    SetNearestWaypoint(TrainerSpells:GetNearestClassTrainer(), "LID_NOCLASSTRAINER")
end)
nearestButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(TrainerSpells:Trans("LID_NEARESTCLASSTRAINER"))
    GameTooltip:AddLine(TrainerSpells:Trans("LID_NEARESTCLASSTRAINER_DESC"), 1, 1, 1, true)
    if not self:IsEnabled() and ERR_NOT_IN_COMBAT then GameTooltip:AddLine(ERR_NOT_IN_COMBAT, 1, 0.2, 0.2, true) end
    GameTooltip:Show()
end)
nearestButton:SetScript("OnLeave", GameTooltip_Hide)
local nearestPetButton = CreateFrame("Button", nil, controls, "MainMenuFrameButtonTemplate")
nearestPetButton:SetPoint("LEFT", nearestButton, "RIGHT", 8, 0)
nearestPetButton:SetSize(200, 36)
nearestPetButton:Hide()
nearestPetButton:SetScript("OnClick", function()
    local texts = petTrainerTexts[GetPlayerClassToken()]
    if texts then SetNearestWaypoint(TrainerSpells:GetNearestPetTrainer(), texts.none) end
end)
nearestPetButton:SetScript("OnEnter", function(self)
    local texts = petTrainerTexts[GetPlayerClassToken()]
    if not texts then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(TrainerSpells:Trans(texts.nearest))
    GameTooltip:AddLine(TrainerSpells:Trans(texts.desc), 1, 1, 1, true)
    if not self:IsEnabled() and ERR_NOT_IN_COMBAT then GameTooltip:AddLine(ERR_NOT_IN_COMBAT, 1, 0.2, 0.2, true) end
    GameTooltip:Show()
end)
nearestPetButton:SetScript("OnLeave", GameTooltip_Hide)
local hideStarter = CreateFrame("CheckButton", nil, controls, "UICheckButtonTemplate")
hideStarter:SetSize(24, 24)
hideStarter:SetChecked(TrainerSpells_Character.hideStarterClassTrainers)
local hideStarterText = controls:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
hideStarterText:SetPoint("LEFT", hideStarter, "RIGHT", 2, 0)
hideStarterText:SetText(TrainerSpells:Trans("LID_HIDESTARTERTRAINERS"))
hideStarter:SetScript("OnClick", function(self)
    TrainerSpells_Character.hideStarterClassTrainers = self:GetChecked() and true or false
    TrainerSpells_Refresh()
end)
local function UpdateNearestButtons(inCombat)
    if inCombat == nil then inCombat = InCombatLockdown and InCombatLockdown() end
    nearestButton:SetEnabled(not inCombat)
    nearestPetButton:SetEnabled(not inCombat)
end
controls:RegisterEvent("PLAYER_REGEN_DISABLED")
controls:RegisterEvent("PLAYER_REGEN_ENABLED")
controls:SetScript("OnEvent", function(_, event)
    UpdateNearestButtons(event == "PLAYER_REGEN_DISABLED")
end)
controls:SetScript("OnShow", function()
    UpdateNearestButtons()
    hideStarter:SetChecked(TrainerSpells_Character.hideStarterClassTrainers)
    local texts = petTrainerTexts[GetPlayerClassToken()]
    local showPetButton = texts and extraTrainerData[GetPlayerClassToken()] and true or false
    nearestPetButton:SetShown(showPetButton)
    if showPetButton then
        nearestPetButton:SetText(TrainerSpells:Trans(texts.nearest))
        nearestPetButton:SetWidth(math.max(200, nearestPetButton:GetTextWidth() + 40))
    end
    hideStarter:ClearAllPoints()
    hideStarter:SetPoint("LEFT", showPetButton and nearestPetButton or nearestButton, "RIGHT", 12, 0)
end)

return controls
end
TrainerSpells.ClassTrainerControls = TrainerSpells:CreateClassTrainerControls(classFrame)
