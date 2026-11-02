local _, TrainerSpells = ...
local function DetectPetFromTooltip(tooltip)
    for i = 1, tooltip:NumLines() do
        local fs = _G[tooltip:GetName() .. "TextLeft" .. i]
        local text = fs and fs:GetText()
        local petWord = text and text:match("Teaches%s+(%S+)") or text and text:match("Lehrt%s+(%S+)")
        if petWord then
            for _, pet in pairs(TrainerSpells.PetNames) do
                if petWord:lower() == pet:lower() then return pet end
            end
        end
    end
end

local GetItemInfoCompat = GetItemInfo or (C_Item and C_Item.GetItemInfo)
local function GetMerchantItemPrice(i)
    if GetMerchantItemInfo then
        local _, _, price = GetMerchantItemInfo(i)
        return price
    end

    local info = C_MerchantFrame and C_MerchantFrame.GetItemInfo and C_MerchantFrame.GetItemInfo(i)
    return info and info.price
end

local function CaptureMerchantInner()
    if not GetMerchantNumItems or not GetItemInfoCompat then return end
    local numItems = GetMerchantNumItems()
    local neu = 0
    local scanTooltip = TrainerSpells.ScanTooltip
    for i = 1, numItems do
        local itemLink = GetMerchantItemLink(i)
        if itemLink then
            local itemName, _, _, _, itemMinLevel = GetItemInfoCompat(itemLink)
            if itemMinLevel then
                scanTooltip:ClearLines()
                scanTooltip:SetMerchantItem(i)
                local pet = DetectPetFromTooltip(scanTooltip)
                if pet then
                    local spellID = TrainerSpells:GetTooltipSpellID(scanTooltip)
                    if TrainerSpells:IsSaneSpellID(spellID) then
                        local price = GetMerchantItemPrice(i)
                        local rankNum = itemName and tonumber(itemName:match("%(.-(%d+)%)"))
                        local bucket = TrainerSpells:EnsurePetPath(pet, itemMinLevel)
                        if bucket[spellID] == nil then neu = neu + 1 end
                        bucket[spellID] = {
                            cost = price or 0,
                            rank = rankNum,
                        }
                    end
                end
            end
        end
    end

    if neu > 0 then TrainerSpells:MSG("|cff33ff99TrainerSpells:|r " .. TrainerSpells:Trans("LID_NEWPETSKILLS"):format(neu)) end
end

function TrainerSpells:CaptureMerchant()
    local ok, err = pcall(CaptureMerchantInner)
    if not ok then TrainerSpells:MSG("|cffff5555TrainerSpells Fehler:|r " .. tostring(err)) end
end

function TrainerSpells:IsPetSpellKnown(spellID, pet)
    if spellID == nil then return nil end
    spellID = tonumber(spellID)
    if pet and TrainerSpells_Character and TrainerSpells_Character.learnedSpellsPet and TrainerSpells_Character.learnedSpellsPet[pet] and TrainerSpells_Character.learnedSpellsPet[pet][spellID] ~= nil then return TrainerSpells_Character.learnedSpellsPet[pet][spellID] end
    if TrainerSpells_Character and TrainerSpells_Character.learnedSpellsPet then
        for i, data in pairs(TrainerSpells_Character.learnedSpellsPet) do
            if data[spellID] ~= nil then return data[spellID] end
        end
    end
    return nil
end

local function FindPetSpellIDByNameAndRank(pet, spellName, rankNum)
    if not spellName then return nil end
    local levels = TrainerSpells_PetData and TrainerSpells_PetData[pet]
    if not levels then return nil end
    for _, spells in pairs(levels) do
        for spellID, data in pairs(spells) do
            local name = TrainerSpells:GetSpellInfo(spellID)
            local rank = (GetSpellSubtext or C_Spell.GetSpellSubtext)(spellID)
            local dbRankNum = rank and tonumber(rank:match("%d+"))
            if name == spellName then
                if dbRankNum and rankNum then
                    if dbRankNum == rankNum then return spellID end
                else
                    return spellID
                end
            end
        end
    end
end

local function OnTooltipSetItem(self)
    local pet = DetectPetFromTooltip(self)
    local family = UnitCreatureFamily("pet")
    if not pet then return end
    local itemName, itemLink = self:GetItem()
    local rankNum = itemName and tonumber(itemName:match("%(.-(%d+)%)"))
    local spellName = itemLink and C_Item and C_Item.GetItemSpell(itemLink)
    local spellID = FindPetSpellIDByNameAndRank(pet, spellName, rankNum)
    if not spellID then return end
    local isPetSpellKnown = TrainerSpells:IsPetSpellKnown(spellID, family)
    if isPetSpellKnown == true then
        if pet ~= family then self:AddLine(TrainerSpells:Trans("LID_ALREADYKNOWN"), 0.9, 0.2, 0.2) end
    elseif isPetSpellKnown == false then
        self:AddLine(TrainerSpells:Trans("LID_NOTLEARNEDYET"), 0.2, 0.9, 0.2)
    else
        self:AddLine(TrainerSpells:Trans("LID_NOTSCANNEDYET"), 0.9, 0.9, 0.2)
    end

    self:Show()
end

if GameTooltip:HasScript("OnTooltipSetItem") then GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem) end

local function MarkKnownPetSpells(pet, dataTable)
    if not UnitExists("pet") then return end
    local health = UnitHealth("pet")
    if TrainerSpells:IsSecret(health) or health <= 0 then return end
    local petSpells = {}
    local i = 1
    while true do
        local name, rank = GetSpellBookItemName(i, BOOKTYPE_PET)
        if not name then break end
        local rankNum = rank and tonumber(rank:match("%d+"))
        petSpells[name] = math.max(petSpells[name] or 0, rankNum or 1)
        i = i + 1
    end

    TrainerSpells_Character.learnedSpellsPet[pet] = TrainerSpells_Character.learnedSpellsPet[pet] or {}
    local changed = false
    for _, spells in pairs(dataTable) do
        for spellID, data in pairs(spells) do
            spellID = tonumber(spellID)
            local info = C_Spell.GetSpellInfo(spellID)
            local name = info and info.name
            local rankNum = type(data) == "table" and tonumber(data.rank)
            local maxKnown = name and petSpells[name]
            if not maxKnown then
                TrainerSpells_Character.learnedSpellsPet[pet][spellID] = false
                changed = true
            elseif rankNum then
                TrainerSpells_Character.learnedSpellsPet[pet][spellID] = rankNum <= maxKnown
                changed = true
            end
        end
    end
    return changed
end

function TrainerSpells:SyncKnownPetSpellsForActivePet()
    if not GetSpellInfo or not UnitCreatureFamily then return end
    local family = UnitCreatureFamily("pet")
    local petData = family and TrainerSpells_PetData[family]
    if not petData then return end
    local changed = MarkKnownPetSpells(family, petData)
    if changed and TrainerSpells_Refresh then TrainerSpells_Refresh() end
end
