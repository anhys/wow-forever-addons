local _, TrainerSpells = ...
local function ResolveTalentSpellIDByName(name)
    if not GetNumTalentTabs or not GetNumTalents or not GetTalentInfo or not GetTalentLink then return nil end
    for tab = 1, GetNumTalentTabs() do
        for i = 1, GetNumTalents(tab) do
            local talentName = GetTalentInfo(tab, i)
            if talentName == name then
                local link = GetTalentLink(tab, i)
                if link then
                    local scanTooltip = TrainerSpells.ScanTooltip
                    scanTooltip:ClearLines()
                    scanTooltip:SetHyperlink(link)
                    local spellID = TrainerSpells:GetTooltipSpellID(scanTooltip)
                    if TrainerSpells:IsSaneSpellID(spellID) then return spellID end
                end
                return nil
            end
        end
    end
end

local function ResolveRequirementSpellID(name)
    local _, _, _, _, _, _, spellID = TrainerSpells:GetSpellInfo(name)
    if TrainerSpells:IsSaneSpellID(spellID) then return spellID end
    spellID = ResolveTalentSpellIDByName(name)
    if TrainerSpells:IsSaneSpellID(spellID) then return spellID end
    local baseName = name:match("^(.-)%s*%b()$")
    if baseName then
        _, _, _, _, _, _, spellID = TrainerSpells:GetSpellInfo(baseName)
        if TrainerSpells:IsSaneSpellID(spellID) then return spellID end
        spellID = ResolveTalentSpellIDByName(baseName)
        if TrainerSpells:IsSaneSpellID(spellID) then return spellID end
    end
end

local function ParseRequirementText(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local colonPos = text:find(":")
    local reqText = colonPos and text:sub(colonPos + 1) or text
    local spellIDs = {}
    for part in reqText:gmatch("[^,]+") do
        part = part:match("^%s*(.-)%s*$")
        if part ~= "" then
            local spellID = ResolveRequirementSpellID(part)
            if spellID then table.insert(spellIDs, spellID) end
        end
    end

    if #spellIDs == 0 then return nil end
    return spellIDs
end

local function ReadRequirementsFromAPI(i)
    if not GetTrainerServiceNumAbilityReq or not GetTrainerServiceAbilityReq then return nil end
    local spellIDs = {}
    for r = 1, GetTrainerServiceNumAbilityReq(i) or 0 do
        local ability = GetTrainerServiceAbilityReq(i, r)
        local spellID = ability and ResolveRequirementSpellID(ability)
        if spellID then table.insert(spellIDs, spellID) end
    end

    if #spellIDs == 0 then return nil end
    return spellIDs
end

local function AddSeen(seen, value)
    if not value then return seen end
    seen = seen or {}
    seen[value] = true
    return seen
end

local function IsNonClassTrainer(numServices)
    for i = 1, numServices do
        local spellID = TrainerSpells:GetSpellIDForService(i)
        if TrainerSpells:IsRidingSpell(spellID) or TrainerSpells:IsWeaponSkillSpell(spellID) then return true end
    end
    return false
end

local function GetTrainerNPCID()
    local guid = UnitGUID and UnitGUID("npc")
    if type(guid) ~= "string" then return nil end
    return tonumber(guid:match("^[^-]+%-[^-]+%-[^-]+%-[^-]+%-[^-]+%-(%d+)"))
end

local function IsListedClassTrainer(classToken)
    if not TrainerSpellsClassTrainers then return nil end
    local npcID = GetTrainerNPCID()
    if not npcID then return false end
    for _, trainer in ipairs(TrainerSpellsClassTrainers[classToken] or {}) do
        if trainer.npcID == npcID then return true end
    end
    return false
end

local function TrainerTitleMatchesClass(className)
    if not C_TooltipInfo or not C_TooltipInfo.GetUnit or not className then return false end
    local ok, data = pcall(C_TooltipInfo.GetUnit, "npc")
    if not ok or not data or not data.lines then return false end
    for i = 2, #data.lines do
        local text = data.lines[i].leftText
        if type(text) == "string" and text:find(className, 1, true) then return true end
    end
    return false
end

local function IsCurrentClassTrainer(className, classToken)
    local listed = IsListedClassTrainer(classToken)
    if listed == nil then return true end
    return listed or TrainerTitleMatchesClass(className)
end

local function IsPetTrainer(numServices)
    for i = 1, numServices do
        local skillLine = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(i)
        if TrainerSpells:IsPetTrainerSkillLine(skillLine) then return true end
    end
    return false
end

local function CaptureTrainerInner()
    local className, classToken = UnitClass("player")
    local isTradeskill = IsTradeskillTrainer and IsTradeskillTrainer()
    local professionKey, professionSkillLine
    if isTradeskill then professionKey, professionSkillLine = TrainerSpells:DetectTrainerProfession() end
    TrainerSpells:DebugTrainer("CaptureTrainerInner: npcName=%s npcGUID=%s classToken=%s isTradeskill=%s professionKey=%s professionSkillLine=%s", tostring(UnitName("npc")), tostring(UnitGUID and UnitGUID("npc")), tostring(classToken), tostring(isTradeskill), tostring(professionKey), tostring(professionSkillLine))
    if not classToken then
        TrainerSpells:MSG("UnitClass(\"player\") lieferte keinen Klassen-Token.")
        return
    end

    if not GetNumTrainerServices then
        TrainerSpells:ERR(TrainerSpells:Trans("LID_NOTRAINERAPI"))
        return
    end

    TrainerSpells:ExpandAllTrainerHeaders()
    local numServices = GetNumTrainerServices()
    TrainerSpells:DebugTrainer("CaptureTrainerInner: numServices=%d", numServices)
    if IsNonClassTrainer(numServices) then
        TrainerSpells:DebugTrainer("CaptureTrainerInner: riding or weapon trainer ignored")
        return
    end
    if not professionKey and not IsPetTrainer(numServices) and not IsCurrentClassTrainer(className, classToken) then
        TrainerSpells:DebugTrainer("CaptureTrainerInner: trainer does not match player class")
        return
    end
    local neu = 0
    local neuPet = 0
    local neuProf = 0
    local rankFound = false
    local lastDebugSkillLine
    local readRequirementsFromAPI = _G["ClassTrainerSkill1"] == nil
    local isPetTrainer = C_Trainer and C_Trainer.GetTrainerType and Enum.TrainerType and Enum.TrainerType.Pet ~= nil and C_Trainer.GetTrainerType() == Enum.TrainerType.Pet
    local playerFaction = TrainerSpells:GetPlayerFaction()
    local playerRace = TrainerSpells:GetPlayerRace()
    for i = 1, numServices do
        local _, _, sType = TrainerSpells:GetTrainerServiceInfo(i)
        if sType == "available" or sType == "unavailable" or sType == "used" then
            rankFound = true
            break
        end
    end

    TrainerSpells:DebugTrainer("CaptureTrainerInner: rankFound=%s", tostring(rankFound))
    if not rankFound then return end
    for i = 1, numServices do
        local name, rankText, sType, levelReq, icon = TrainerSpells:GetTrainerServiceInfo(i)
        local rank = rankText and tonumber(rankText:match("%d+"))
        if (rank ~= nil or levelReq ~= nil) and (sType == "available" or sType == "unavailable" or sType == "used") then
            local cost, isProfessionService = 0
            if GetTrainerServiceCost then cost, isProfessionService = GetTrainerServiceCost(i) end
            cost = cost or 0
            local skillLine = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(i)
            if name and professionKey then
                local spellID = TrainerSpells:GetSpellIDForService(i)
                local skillReq = TrainerSpells:GetSkillReqForService(i)
                local bucket = TrainerSpells:EnsureProfessionPath(professionKey, skillReq)
                local existing = bucket[name]
                local baseCost, baseCostEstimated = TrainerSpells.Pricing.CaptureBaseCost(cost, existing)
                if existing == nil then neuProf = neuProf + 1 end
                local requires = existing and existing.requires
                if readRequirementsFromAPI then requires = ReadRequirementsFromAPI(i) or requires end
                bucket[name] = {
                    spellID = spellID,
                    rankRow = (isProfessionService == true) or (GetTrainerServiceStepIndex and GetTrainerServiceStepIndex() == i) or (existing and existing.rankRow) or nil,
                    icon = icon,
                    cost = cost,
                    baseCost = baseCost,
                    baseCostEstimated = baseCostEstimated,
                    rank = rank,
                    status = sType,
                    levelReq = (levelReq and levelReq > 0) and levelReq or nil,
                    requires = requires,
                    faction = existing and existing.faction,
                    race = existing and existing.race,
                    seenFactions = AddSeen(existing and existing.seenFactions, playerFaction),
                    seenRaces = AddSeen(existing and existing.seenRaces, playerRace)
                }
            else
                local spellID = TrainerSpells:GetSpellIDForService(i)
                if spellID then
                    if not levelReq or levelReq == 0 then levelReq = TrainerSpells:GetSpellLevelLearned(spellID) or levelReq end
                    local isPetTraining = isPetTrainer or TrainerSpells:IsPetTrainerSkillLine(skillLine)
                    if skillLine ~= lastDebugSkillLine then
                        lastDebugSkillLine = skillLine
                        TrainerSpells:DebugTrainer("CaptureTrainerInner: skillLine=%s isPetTraining=%s classToken=%s", tostring(skillLine), tostring(isPetTraining), tostring(classToken))
                    end

                    if isPetTraining then
                        local oldBucket = TrainerSpells_Data[classToken] and TrainerSpells_Data[classToken][levelReq or 0]
                        if oldBucket then oldBucket[spellID] = nil end
                    end

                    local bucket = isPetTraining and TrainerSpells:EnsurePetTrainerPath(classToken, levelReq or 0) or TrainerSpells:EnsurePath(classToken, levelReq or 0)
                    local existing = bucket[spellID]
                    local baseCost, baseCostEstimated
                    if not isPetTraining then baseCost, baseCostEstimated = TrainerSpells.Pricing.CaptureBaseCost(cost, existing) end
                    if existing == nil then
                        if isPetTraining then
                            neuPet = neuPet + 1
                        else
                            neu = neu + 1
                        end
                    end

                    local requires = existing and existing.requires
                    if readRequirementsFromAPI then requires = ReadRequirementsFromAPI(i) or requires end
                    bucket[spellID] = {
                        cost = cost,
                        baseCost = baseCost,
                        baseCostEstimated = baseCostEstimated,
                        rank = rank,
                        status = sType,
                        requires = requires,
                        faction = existing and existing.faction,
                        race = existing and existing.race,
                        seenFactions = AddSeen(existing and existing.seenFactions, playerFaction),
                        seenRaces = AddSeen(existing and existing.seenRaces, playerRace)
                    }
                end
            end
        end
    end

    if TrainerSpells.DebugTrainerEnabled then
        if neu > 0 then TrainerSpells:MSG("|cff33ff99TrainerSpells:|r " .. TrainerSpells:Trans("LID_NEWSPELLS"):format(neu, classToken)) end
        if neuPet > 0 then TrainerSpells:MSG("|cff33ff99TrainerSpells:|r " .. TrainerSpells:Trans("LID_NEWPETTRAINERSKILLS"):format(neuPet, classToken)) end
        if neuProf > 0 then TrainerSpells:MSG("|cff33ff99TrainerSpells:|r " .. TrainerSpells:Trans("LID_NEWRECIPES"):format(neuProf, professionSkillLine or TrainerSpells:Trans("LID_PROFESSION"))) end
    end
end

function TrainerSpells:CaptureTrainer()
    local ok, err = pcall(CaptureTrainerInner)
    if not ok then TrainerSpells:ERR("|cffff5555TrainerSpells Fehler:|r " .. tostring(err)) end
end

local function OnTrainerServiceSelectedInner(id)
    local _, classToken = UnitClass("player")
    if not classToken or not id then return end
    local fs = _G["ClassTrainerSkillRequirements"]
    local text = fs and fs:GetText()
    local requires = text and ParseRequirementText(text)
    if not requires then return end
    local isTradeskill = IsTradeskillTrainer and IsTradeskillTrainer()
    local professionKey
    if isTradeskill then professionKey = TrainerSpells:DetectTrainerProfession() end
    local bucket, key
    if professionKey then
        local name = GetTrainerServiceInfo(id)
        local skillReq = TrainerSpells:GetSkillReqForService(id)
        local profession = TrainerSpells_ProfessionData[professionKey]
        bucket = profession and profession[skillReq]
        key = name
    else
        local spellID = TrainerSpells:GetSpellIDForService(id)
        if not spellID then return end
        local skillLine = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(id)
        local levelReq = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(id) or 0
        local isPetTraining = TrainerSpells:IsPetTrainerSkillLine(skillLine)
        local levels = isPetTraining and TrainerSpells_PetTrainerData[classToken] or TrainerSpells_Data[classToken]
        bucket = levels and levels[levelReq]
        key = spellID
    end

    if bucket and key and bucket[key] then
        bucket[key].requires = requires
        if TrainerSpells_Refresh then TrainerSpells_Refresh() end
        if TrainerSpells_ProfessionRefresh then TrainerSpells_ProfessionRefresh() end
    end
end

local function OnTrainerServiceButtonClicked(self)
    local id = self:GetID()
    local ok, err = pcall(OnTrainerServiceSelectedInner, id)
    if not ok then TrainerSpells:MSG("|cffff5555TrainerSpells Fehler:|r " .. tostring(err)) end
end

local hookedTrainerButtons = {}
function TrainerSpells:CaptureTrainerRequirements()
    local i = 1
    while _G["ClassTrainerSkill" .. i] do
        local button = _G["ClassTrainerSkill" .. i]
        if not hookedTrainerButtons[button] then
            hookedTrainerButtons[button] = true
            button:HookScript("OnClick", OnTrainerServiceButtonClicked)
        end

        i = i + 1
    end
end
