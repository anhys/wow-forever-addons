local _, TrainerSpells = ...
function TrainerSpells_ToggleIgnoreSpell(spellID)
    spellID = tonumber(spellID)
    local _, classToken = UnitClass("player")
    if not classToken or not spellID then return end
    TrainerSpells_Ignored[classToken] = TrainerSpells_Ignored[classToken] or {}
    local ignored = TrainerSpells_Ignored[classToken]
    if ignored[spellID] then
        ignored[spellID] = nil
    else
        ignored[spellID] = true
    end
end

function TrainerSpells_ToggleIgnoreName(name)
    local _, classToken = UnitClass("player")
    if not classToken or not name then return end
    TrainerSpells_IgnoredNames[classToken] = TrainerSpells_IgnoredNames[classToken] or {}
    local ignored = TrainerSpells_IgnoredNames[classToken]
    if ignored[name] then
        ignored[name] = nil
        local ignoredSpells = TrainerSpells_Ignored[classToken]
        if ignoredSpells then
            for spellID in pairs(ignoredSpells) do
                if TrainerSpells:GetSpellInfo(spellID) == name then ignoredSpells[spellID] = nil end
            end
        end
    else
        ignored[name] = true
    end
end

function TrainerSpells_IsSpellIgnored(spellID)
    spellID = tonumber(spellID)
    local _, classToken = UnitClass("player")
    if not classToken or not spellID then return false end
    return TrainerSpells_Ignored[classToken] and TrainerSpells_Ignored[classToken][spellID] or false
end

function TrainerSpells_IsNameIgnored(name)
    local _, classToken = UnitClass("player")
    if not classToken or not name then return false end
    return TrainerSpells_IgnoredNames[classToken] and TrainerSpells_IgnoredNames[classToken][name] or false
end

function TrainerSpells_IsIgnored(spellID, name)
    return TrainerSpells_IsSpellIgnored(spellID) or TrainerSpells_IsNameIgnored(name)
end

function TrainerSpells_IsProfessionSpellIgnored(spellID, professionKey)
    spellID = tonumber(spellID)
    local _, classToken = UnitClass("player")
    if not classToken or not spellID then return false end
    professionKey = professionKey or TrainerSpells:DetectTrainerProfession()
    if not professionKey then return false end
    TrainerSpells_IgnoredProfessions[professionKey] = TrainerSpells_IgnoredProfessions[professionKey] or {}
    local ignored = TrainerSpells_IgnoredProfessions[professionKey]
    return ignored[spellID] or false
end

function TrainerSpells_ToggleIgnoreProfessionSpell(spellID, professionKey)
    spellID = tonumber(spellID)
    local _, classToken = UnitClass("player")
    if not classToken or not spellID then return end
    professionKey = professionKey or TrainerSpells:DetectTrainerProfession()
    if not professionKey then return end
    TrainerSpells_IgnoredProfessions[professionKey] = TrainerSpells_IgnoredProfessions[professionKey] or {}
    local ignored = TrainerSpells_IgnoredProfessions[professionKey]
    if ignored[spellID] then
        ignored[spellID] = nil
    else
        ignored[spellID] = true
    end

    if TrainerSpells_ProfessionRefresh then TrainerSpells_ProfessionRefresh() end
end

function TrainerSpells:MigrateLegacyProfessionIgnores()
    if TrainerSpells_Data.migratedProfessionIgnoresV1 then return end
    TrainerSpells_Data.migratedProfessionIgnoresV1 = true
    local _, classToken = UnitClass("player")
    if not classToken then return end
    local ignoredSpells = TrainerSpells_Ignored[classToken]
    local ignoredNames = TrainerSpells_IgnoredNames[classToken]
    if not ignoredSpells and not ignoredNames then return end
    for _, dataStore in ipairs({TrainerSpells_ProfessionData, TrainerSpells_RecipeData}) do
        for professionKey, byLevel in pairs(dataStore or {}) do
            for _, spells in pairs(byLevel) do
                for key, data in pairs(spells) do
                    local spellID = (type(key) == "number" and key) or (type(data) == "table" and data.spellID)
                    if spellID then
                        local name = TrainerSpells:GetSpellInfo(spellID)
                        local nameIgnored = ignoredNames and name and ignoredNames[name]
                        if (ignoredSpells and ignoredSpells[spellID]) or nameIgnored then
                            TrainerSpells_IgnoredProfessions[professionKey] = TrainerSpells_IgnoredProfessions[professionKey] or {}
                            TrainerSpells_IgnoredProfessions[professionKey][spellID] = true
                            if ignoredSpells then ignoredSpells[spellID] = nil end
                            if nameIgnored then ignoredNames[name] = nil end
                        end
                    end
                end
            end
        end
    end
end
