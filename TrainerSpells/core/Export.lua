local _, TrainerSpells = ...
local exportFrame
local exportBox
local function SortNumberKeys(data)
    local keys = {}
    for key in pairs(data or {}) do
        if type(key) == "number" then table.insert(keys, key) end
    end
    table.sort(keys)
    return keys
end

local function BuildLevelExport(levelData)
    local lines = {}
    for _, level in ipairs(SortNumberKeys(levelData)) do
        local spells = levelData[level]
        for _, spellID in ipairs(SortNumberKeys(spells)) do
            local entry = spells[spellID]
            local cost = type(entry) == "table" and entry.cost or entry
            local rank = type(entry) == "table" and entry.rank or nil
            local requires = type(entry) == "table" and entry.requires or nil
            local requirementText = ""
            if type(requires) == "table" then
                local requirementIDs = {}
                for _, requiredSpellID in ipairs(requires) do
                    table.insert(requirementIDs, tostring(requiredSpellID))
                end
                requirementText = table.concat(requirementIDs, "|")
            end
            table.insert(lines, table.concat({level, spellID, cost or 0, rank or "", requirementText}, ";"))
        end
    end
    return table.concat(lines, "\n"), #lines
end

local function BuildClassExport(classToken)
    local classData = TrainerSpells_Data and TrainerSpells_Data[classToken]
    return BuildLevelExport(classData)
end

local function BuildRequirementText(requires)
    if type(requires) ~= "table" then return "" end
    local requirementIDs = {}
    for _, requiredSpellID in ipairs(requires) do
        table.insert(requirementIDs, tostring(requiredSpellID))
    end
    return table.concat(requirementIDs, "|")
end

local function SanitizeExportText(value)
    return tostring(value or ""):gsub("[;\r\n]", " ")
end

local function BuildProfessionExport()
    local sections = {}
    local totalCount = 0
    local professionKeys = {}
    for professionKey in pairs(TrainerSpells_ProfessionData or {}) do
        table.insert(professionKeys, professionKey)
    end
    table.sort(professionKeys)

    for _, professionKey in ipairs(professionKeys) do
        local lines = {}
        local professionData = TrainerSpells_ProfessionData[professionKey]
        for _, skillReq in ipairs(SortNumberKeys(professionData)) do
            local recipes = {}
            for name, entry in pairs(professionData[skillReq] or {}) do
                table.insert(recipes, {name = name, entry = entry})
            end
            table.sort(recipes, function(left, right)
                local leftID = tonumber(left.entry and left.entry.spellID) or math.huge
                local rightID = tonumber(right.entry and right.entry.spellID) or math.huge
                if leftID ~= rightID then return leftID < rightID end
                return tostring(left.name) < tostring(right.name)
            end)
            for _, recipe in ipairs(recipes) do
                local entry = recipe.entry or {}
                table.insert(lines, table.concat({
                    skillReq,
                    entry.spellID or "",
                    entry.cost or 0,
                    entry.icon or "",
                    entry.rankRow and 1 or "",
                    BuildRequirementText(entry.requires),
                    SanitizeExportText(entry.faction),
                    SanitizeExportText(entry.race),
                    SanitizeExportText(recipe.name)
                }, ";"))
            end
        end
        if #lines > 0 then
            table.insert(sections, ("[%s]\n%s"):format(professionKey, table.concat(lines, "\n")))
            totalCount = totalCount + #lines
        end
    end
    return table.concat(sections, "\n\n"), totalCount
end

local WARLOCK_PETS = {
    {token = "Imp", spellID = 688},
    {token = "Voidwalker", spellID = 697},
    {token = "Succubus", spellID = 712},
    {token = "Incubus", spellID = 101822},
    {token = "Felhunter", spellID = 691},
    {token = "Felguard", spellID = 30146}
}

local function MergePetData(token, localizedName)
    local merged = {}
    local keys = {token}
    if localizedName and localizedName ~= token then table.insert(keys, localizedName) end
    for _, key in ipairs(keys) do
        local levels = TrainerSpells_PetData and TrainerSpells_PetData[key]
        for level, spells in pairs(levels or {}) do
            merged[level] = merged[level] or {}
            for spellID, entry in pairs(spells) do
                merged[level][spellID] = entry
            end
        end
    end
    return merged
end

local function BuildWarlockPetExport()
    local sections = {}
    local count = 0
    for _, pet in ipairs(WARLOCK_PETS) do
        local localizedName = TrainerSpells:GetPetNameById(pet.spellID)
        local text, petCount = BuildLevelExport(MergePetData(pet.token, localizedName))
        if petCount > 0 then
            table.insert(sections, ("[%s]\n%s"):format(pet.token, text))
            count = count + petCount
        end
    end
    return table.concat(sections, "\n\n"), count
end

local function CreateExportFrame()
    local frame = CreateFrame("Frame", "TrainerSpellsExportFrame", UIParent, "BackdropTemplate")
    frame:SetSize(720, 520)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    frame.Title = title

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 24, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -46, 24)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(640)
    editBox:SetMaxLetters(0)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    scrollFrame:SetScrollChild(editBox)

    exportFrame = frame
    exportBox = editBox
end

local function ShowExport(title, text, count)
    if not exportFrame then CreateExportFrame() end
    local lineCount = text == "" and 1 or select(2, text:gsub("\n", "\n")) + 1
    exportFrame.Title:SetText(title)
    exportBox:SetText(text)
    exportBox:SetHeight(math.max(440, lineCount * 14 + 12))
    exportFrame:Show()
    exportBox:SetFocus()
    exportBox:HighlightText()
end

function TrainerSpells:ShowClassExport()
    local localizedClass, classToken = UnitClass("player")
    if not classToken then
        TrainerSpells:MSG(TrainerSpells:Trans("LID_CLASSUNKNOWN"))
        return
    end

    local text, count = BuildClassExport(classToken)
    ShowExport(("TrainerSpells: %s (%s)"):format(localizedClass or classToken, TrainerSpells:Trans("LID_ENTRIESCOUNT"):format(count)), text, count)
    if count == 0 then TrainerSpells:MSG(TrainerSpells:Trans("LID_NOCLASSDATA")) end
end

function TrainerSpells:ShowPetExport()
    local localizedClass, classToken = UnitClass("player")
    local text, count
    if classToken == "HUNTER" then
        text, count = BuildLevelExport(TrainerSpells_PetTrainerData and TrainerSpells_PetTrainerData.HUNTER)
    elseif classToken == "WARLOCK" then
        text, count = BuildWarlockPetExport()
    else
        TrainerSpells:MSG(TrainerSpells:Trans("LID_PETEXPORTONLY"))
        return
    end

    ShowExport(("TrainerSpells %s: %s (%s)"):format(TrainerSpells:Trans("LID_PETTRAINING"), localizedClass or classToken, TrainerSpells:Trans("LID_ENTRIESCOUNT"):format(count)), text, count)
    if count == 0 then TrainerSpells:MSG(TrainerSpells:Trans("LID_NOPETDATA")) end
end

function TrainerSpells:ShowProfessionExport()
    local text, count = BuildProfessionExport()
    ShowExport(("TrainerSpells %s (%s)"):format(TrainerSpells:Trans("LID_PROFESSIONS"), TrainerSpells:Trans("LID_ENTRIESCOUNT"):format(count)), text, count)
    if count == 0 then TrainerSpells:MSG(TrainerSpells:Trans("LID_NOPROFESSIONDATA")) end
end

function TrainerSpells:EnableTrainerDebugFilters()
    if not GetTrainerServiceTypeFilter or not SetTrainerServiceTypeFilter then return false end
    local changed = false
    for _, filter in ipairs({"available", "unavailable", "used"}) do
        if not GetTrainerServiceTypeFilter(filter) then
            SetTrainerServiceTypeFilter(filter, true)
            changed = true
        end
    end
    return changed
end

SLASH_TRAINERSPELLSDUMP1 = "/tsdump"
SLASH_TRAINERSPELLSDUMP2 = "/trainerspellsdump"
SlashCmdList.TRAINERSPELLSDUMP = function()
    TrainerSpells:ShowClassExport()
end

SLASH_TRAINERSPELLSPETDUMP1 = "/tspetdump"
SLASH_TRAINERSPELLSPETDUMP2 = "/trainerspellspetdump"
SlashCmdList.TRAINERSPELLSPETDUMP = function()
    TrainerSpells:ShowPetExport()
end

SLASH_TRAINERSPELLSPROFDUMP1 = "/tsprofdump"
SLASH_TRAINERSPELLSPROFDUMP2 = "/trainerspellsprofdump"
SlashCmdList.TRAINERSPELLSPROFDUMP = function()
    TrainerSpells:ShowProfessionExport()
end

SLASH_TRAINERSPELLSDEBUG1 = "/tsdebug"
SlashCmdList.TRAINERSPELLSDEBUG = function(input)
    input = tostring(input or ""):lower():match("^%s*(.-)%s*$")
    if input == "on" then
        TrainerSpells.DebugTrainerEnabled = true
    elseif input == "off" then
        TrainerSpells.DebugTrainerEnabled = false
    else
        TrainerSpells.DebugTrainerEnabled = not TrainerSpells.DebugTrainerEnabled
    end

    if TrainerSpells.DebugTrainerEnabled then
        TrainerSpells:EnableTrainerDebugFilters()
        TrainerSpells:MSG(TrainerSpells:Trans("LID_TRAINERDEBUGON"))
        if ClassTrainerFrame and ClassTrainerFrame:IsShown() then
            C_Timer.After(0.1, function() TrainerSpells:CaptureTrainer() end)
        end
    else
        TrainerSpells:MSG(TrainerSpells:Trans("LID_TRAINERDEBUGOFF"))
    end
end
