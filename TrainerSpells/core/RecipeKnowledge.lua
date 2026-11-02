local _, TrainerSpells = ...
TrainerSpells_Global = TrainerSpells_Global or {}
TrainerSpells_Global.characters = TrainerSpells_Global.characters or {}
local RECIPE_ITEM_CLASS = Enum and Enum.ItemClass and Enum.ItemClass.Recipe or 9
local RECIPE_SUBCLASS_TO_PROFESSION = {
    [1] = "Leatherworking",
    [2] = "Tailoring",
    [3] = "Engineering",
    [4] = "Blacksmithing",
    [5] = "Cooking",
    [6] = "Alchemy",
    [7] = "First Aid",
    [8] = "Enchanting",
    [9] = "Fishing",
    [10] = "Jewelcrafting",
    [11] = "Inscription"
}

local function GetRealm()
    if GetNormalizedRealmName then
        local realm = GetNormalizedRealmName()
        if realm and realm ~= "" then return realm end
    end
    return GetRealmName and GetRealmName() or ""
end

local function GetCharacterRecord()
    local name = UnitName("player")
    if not name then return nil end
    local realm = GetRealm()
    local key = name .. "-" .. realm
    local record = TrainerSpells_Global.characters[key] or {}
    TrainerSpells_Global.characters[key] = record
    record.name = name
    record.realm = realm
    record.class = select(2, UnitClass("player"))
    record.professions = record.professions or {}
    record.updatedAt = time and time() or nil
    return record, key
end

local function UpdateProfessionRecord(record, professionKey, professionName, skillLevel, maxSkillLevel)
    if not record or not professionKey then return nil end
    local profession = record.professions[professionKey] or {}
    record.professions[professionKey] = profession
    profession.name = professionName or TrainerSpells:GetProfessionName(professionKey)
    profession.skillLevel = skillLevel or profession.skillLevel or 0
    profession.maxSkillLevel = maxSkillLevel or profession.maxSkillLevel or 0
    profession.recipes = profession.recipes or {}
    return profession
end

local function SyncProfessionRoster()
    if not GetProfessions or not GetProfessionInfo then return end
    local record = GetCharacterRecord()
    if not record then return end
    local professionIndices = {GetProfessions()}
    local seen = {}
    local found = false
    for slot = 1, 6 do
        local professionIndex = professionIndices[slot]
        if professionIndex then
            local professionName, _, skillLevel, maxSkillLevel = GetProfessionInfo(professionIndex)
            local professionKey = professionName and TrainerSpells:GetProfessionKey(professionName)
            if professionKey then
                UpdateProfessionRecord(record, professionKey, professionName, skillLevel, maxSkillLevel)
                seen[professionKey] = true
                found = true
            end
        end
    end

    if found then
        for professionKey in pairs(record.professions) do
            if not seen[professionKey] then record.professions[professionKey] = nil end
        end
    end
end

local function GetOpenProfession()
    local professionInfo = C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    if type(professionInfo) == "table" then
        local professionName = professionInfo.parentProfessionName or professionInfo.professionName or professionInfo.name
        local professionKey = professionName and TrainerSpells:GetProfessionKey(professionName)
        if professionKey then return professionKey, professionName, professionInfo.skillLevel, professionInfo.maxSkillLevel, professionInfo end
    end

    if GetTradeSkillLine then
        local professionName, skillLevel, maxSkillLevel = GetTradeSkillLine()
        if professionName and professionName ~= "" then return TrainerSpells:GetProfessionKey(professionName), professionName, skillLevel, maxSkillLevel end
    end
end

local function GetModernKnownRecipes(professionInfo)
    if not C_TradeSkillUI then return nil end
    if C_TradeSkillUI.GetProfessionSpells and professionInfo and professionInfo.profession and professionInfo.professionID then
        local ok, knownSpells = pcall(C_TradeSkillUI.GetProfessionSpells, professionInfo.profession, professionInfo.professionID)
        if ok and type(knownSpells) == "table" and next(knownSpells) then
            local known = {}
            for _, recipeID in pairs(knownSpells) do
                known[recipeID] = true
            end
            return known
        end
    end

    if not C_TradeSkillUI.GetAllRecipeIDs or not C_TradeSkillUI.GetRecipeInfo then return nil end
    local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
    if type(recipeIDs) ~= "table" or not next(recipeIDs) then return nil end
    local known = {}
    for _, recipeID in pairs(recipeIDs) do
        local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
        if recipeInfo and recipeInfo.learned then known[recipeID] = true end
    end
    return known
end

local function GetLegacyKnownRecipes()
    if not GetNumTradeSkills or not GetTradeSkillInfo or not GetTradeSkillRecipeLink then return nil end
    local known = {}
    local found = false
    for index = 1, GetNumTradeSkills() do
        local _, skillType = GetTradeSkillInfo(index)
        if skillType and skillType ~= "header" and skillType ~= "subheader" then
            local link = GetTradeSkillRecipeLink(index)
            local recipeID = link and tonumber(link:match("enchant:(%d+)") or link:match("spell:(%d+)"))
            if recipeID then
                known[recipeID] = true
                found = true
            end
        end
    end
    return found and known or nil
end

function TrainerSpells:SyncOpenProfessionRecipes()
    SyncProfessionRoster()
    local professionKey, professionName, skillLevel, maxSkillLevel, professionInfo = GetOpenProfession()
    if not professionKey then return end
    local knownRecipes = GetModernKnownRecipes(professionInfo) or GetLegacyKnownRecipes()
    if not knownRecipes then return end
    local record = GetCharacterRecord()
    local profession = UpdateProfessionRecord(record, professionKey, professionName, skillLevel, maxSkillLevel)
    profession.recipes = knownRecipes
    profession.recipesScanned = true
    profession.updatedAt = time and time() or nil
end

local function GetRecipeSpellID(tooltipData, itemLink)
    local learnLineType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemSpellTriggerLearn or 38
    for _, line in ipairs(tooltipData and tooltipData.lines or {}) do
        if line.type == learnLineType then
            if line.spellID then return line.spellID end
            for _, argument in ipairs(line.args or {}) do
                if argument.field == "spellID" and argument.intVal then return argument.intVal end
            end
        end
    end

    local _, spellID
    if C_Item and C_Item.GetItemSpell then
        _, spellID = C_Item.GetItemSpell(itemLink)
    elseif GetItemSpell then
        _, spellID = GetItemSpell(itemLink)
    end
    return spellID
end

local function GetItemClass(itemLink)
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, _, itemClassID, itemSubclassID = C_Item.GetItemInfoInstant(itemLink)
        return itemClassID, itemSubclassID
    end

    if GetItemInfoInstant then
        local _, _, _, _, _, itemClassID, itemSubclassID = GetItemInfoInstant(itemLink)
        return itemClassID, itemSubclassID
    end
end

local function GetRecipeProfession(recipeID, itemSubclassID)
    if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLineForRecipe then
        local _, _, professionName = pcall(C_TradeSkillUI.GetTradeSkillLineForRecipe, recipeID)
        local professionKey = professionName and TrainerSpells:GetProfessionKey(professionName)
        if professionKey then return professionKey end
    end

    for professionKey, levels in pairs(TrainerSpells_RecipeData or {}) do
        for _, recipes in pairs(levels) do
            if recipes[recipeID] then return professionKey end
        end
    end
    return RECIPE_SUBCLASS_TO_PROFESSION[itemSubclassID]
end

local function GetCharacterDisplayName(character)
    if character.realm and character.realm ~= "" and character.realm ~= GetRealm() then return character.name .. "-" .. character.realm end
    return character.name
end

local function IsCurrentCharacterRecipeKnown(characterKey, recipeID)
    local name = UnitName("player")
    if not name or characterKey ~= name .. "-" .. GetRealm() then return nil end
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local ok, recipeInfo = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        if ok and recipeInfo then return recipeInfo.learned and true or false end
    end

    if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(recipeID) and true or nil end
    if IsSpellKnown then return IsSpellKnown(recipeID) and true or nil end
end

local function AddRecipeKnowledgeToTooltip(tooltip, tooltipData)
    local itemLink = tooltipData and tooltipData.hyperlink
    if not itemLink and tooltip.GetItem then _, itemLink = tooltip:GetItem() end
    if not itemLink then return end
    local itemClassID, itemSubclassID = GetItemClass(itemLink)
    if itemClassID ~= RECIPE_ITEM_CLASS then return end
    local recipeID = GetRecipeSpellID(tooltipData, itemLink)
    if not recipeID then return end
    local professionKey = GetRecipeProfession(recipeID, itemSubclassID)
    if not professionKey then return end
    local missing = {}
    for characterKey, character in pairs(TrainerSpells_Global.characters) do
        local profession = character.professions and character.professions[professionKey]
        local liveKnown = IsCurrentCharacterRecipeKnown(characterKey, recipeID)
        local known = liveKnown
        if known == nil and profession and profession.recipes then known = profession.recipes[recipeID] and true or false end
        if profession and profession.recipesScanned and known == false then table.insert(missing, GetCharacterDisplayName(character)) end
    end

    if #missing == 0 then return end
    table.sort(missing)
    tooltip:AddLine(" ")
    tooltip:AddLine(TrainerSpells:Trans("LID_RECIPE_NOT_LEARNED_BY") .. ": " .. table.concat(missing, ", "), 1, 0.82, 0, true)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddRecipeKnowledgeToTooltip)
elseif GameTooltip and GameTooltip:HasScript("OnTooltipSetItem") then
    GameTooltip:HookScript("OnTooltipSetItem", function(tooltip) AddRecipeKnowledgeToTooltip(tooltip) end)
end

local eventFrame = CreateFrame("Frame")
local professionSyncScheduled = false
local function ScheduleOpenProfessionSync()
    if professionSyncScheduled then return end
    if C_Timer then
        professionSyncScheduled = true
        C_Timer.After(0, function()
            professionSyncScheduled = false
            TrainerSpells:SyncOpenProfessionRecipes()
        end)
    else
        TrainerSpells:SyncOpenProfessionRecipes()
    end
end

for _, event in ipairs({"PLAYER_LOGIN", "SKILL_LINES_CHANGED", "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "LEARNED_SPELL_IN_TAB", "PLAYER_LOGOUT", "NEW_RECIPE_LEARNED"}) do
    TrainerSpells:RegisterEvent(eventFrame, event)
end

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        if C_Timer then
            C_Timer.After(1, SyncProfessionRoster)
        else
            SyncProfessionRoster()
        end
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
        ScheduleOpenProfessionSync()
    elseif event == "NEW_RECIPE_LEARNED" or event == "LEARNED_SPELL_IN_TAB" then
        local recipeID = tonumber(arg1)
        local professionKey = recipeID and GetRecipeProfession(recipeID)
        if professionKey then
            SyncProfessionRoster()
            local record = GetCharacterRecord()
            local profession = record and UpdateProfessionRecord(record, professionKey)
            if profession then profession.recipes[recipeID] = true end
        end

        ScheduleOpenProfessionSync()
    else
        SyncProfessionRoster()
    end
end)
