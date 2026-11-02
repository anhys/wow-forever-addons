local _, TrainerSpells = ...
local function IsTrainerTaught(profession, name)
    local levels = TrainerSpells_ProfessionData and TrainerSpells_ProfessionData[profession]
    if not levels then return false end
    for _, entries in pairs(levels) do
        if entries[name] then return true end
    end
    return false
end

local function MergeProfessionEntry(target, source)
    for field, value in pairs(source) do
        if target[field] == nil then target[field] = value end
    end
end

local function RelocalizeProfessionData()
    if not TrainerSpells_ProfessionData then return end
    for profession, skillLevels in pairs(TrainerSpells_ProfessionData) do
        local builtinLevels = TrainerSpellsBuiltin_Profession and TrainerSpellsBuiltin_Profession[profession]
        for skillReq, bucket in pairs(skillLevels) do
            local renames = {}
            local builtinIcons = {}
            local builtin = builtinLevels and builtinLevels[skillReq]
            if builtin then
                for spellID, data in pairs(builtin) do
                    local spellInfo = C_Spell.GetSpellInfo(spellID)
                    if spellInfo and spellInfo.name and data.icon then builtinIcons[data.icon] = builtinIcons[data.icon] == nil and spellInfo.name or false end
                end
            end
            for name, entry in pairs(bucket) do
                local localized
                if type(entry) ~= "table" or entry.rankRow then
                    localized = nil
                elseif entry.spellID then
                    local spellInfo = C_Spell.GetSpellInfo(entry.spellID)
                    localized = spellInfo and spellInfo.name
                elseif entry.icon and builtinIcons[entry.icon] and bucket[builtinIcons[entry.icon]] then
                    localized = builtinIcons[entry.icon]
                end
                if localized and localized ~= name then renames[name] = localized end
            end
            for oldName, newName in pairs(renames) do
                local entry = bucket[oldName]
                bucket[oldName] = nil
                if bucket[newName] then
                    MergeProfessionEntry(bucket[newName], entry)
                else
                    bucket[newName] = entry
                end
            end
        end
    end
end

function TrainerSpells:MergeBuiltinData()
    RelocalizeProfessionData()
    if TrainerSpellsBuiltin then
        for class, levels in pairs(TrainerSpellsBuiltin) do
            for level, spells in pairs(levels) do
                local bucket = TrainerSpells:EnsurePath(class, level)
                for spellID, data in pairs(spells) do
                    if bucket[spellID] == nil then
                        bucket[spellID] = {
                            cost = data.cost or 0,
                            rank = data.rank,
                            faction = data.faction,
                            race = data.race
                        }
                    else
                        if data.cost then bucket[spellID].cost = data.cost end
                        if data.faction and bucket[spellID].faction == nil then bucket[spellID].faction = data.faction end
                        if data.race and bucket[spellID].race == nil then bucket[spellID].race = data.race end
                    end
                    if data.cost and data.cost > 0 then
                        bucket[spellID].baseCost = data.cost
                        bucket[spellID].baseCostEstimated = nil
                    end
                end
            end
        end
    end

    if TrainerSpellsBuiltin_WarlockPet then
        for pet, levels in pairs(TrainerSpellsBuiltin_WarlockPet) do
            for level, spells in pairs(levels) do
                local bucket = TrainerSpells:EnsurePetPath(pet, level)
                for spellID, data in pairs(spells) do
                    if bucket[spellID] == nil then
                        bucket[spellID] = {
                            cost = data.cost or 0,
                            rank = data.rank,
                            faction = data.faction
                        }
                    else
                        if data.cost then bucket[spellID].cost = data.cost end
                        if data.faction and bucket[spellID].faction == nil then bucket[spellID].faction = data.faction end
                    end
                end
            end
        end
    end

    if TrainerSpellsBuiltin_HunterPet then
        for level, spells in pairs(TrainerSpellsBuiltin_HunterPet) do
            local bucket = TrainerSpells:EnsurePetTrainerPath("HUNTER", level)
            for spellID, data in pairs(spells) do
                if bucket[spellID] == nil then
                    bucket[spellID] = {
                        cost = data.cost or 0,
                        rank = data.rank,
                        faction = data.faction
                    }
                else
                    if data.cost then bucket[spellID].cost = data.cost end
                    if data.faction and bucket[spellID].faction == nil then bucket[spellID].faction = data.faction end
                end
            end
        end
    end

    if TrainerSpellsBuiltin_Profession then
        for profession, skillLevels in pairs(TrainerSpellsBuiltin_Profession) do
            for skillReq, recipes in pairs(skillLevels) do
                local bucket = TrainerSpells:EnsureProfessionPath(profession, skillReq)
                for spellID, data in pairs(recipes) do
                    local spellInfo = C_Spell.GetSpellInfo(spellID)
                    local name = spellInfo and spellInfo.name
                    if name then
                        if bucket[name] == nil then
                            bucket[name] = {
                                cost = data.cost or 0,
                                spellID = spellID,
                                icon = data.icon,
                                requires = data.requires,
                                faction = data.faction
                            }
                        else
                            if data.cost then bucket[name].cost = data.cost end
                            if bucket[name].spellID == nil then bucket[name].spellID = spellID end
                            if data.icon and bucket[name].icon == nil then bucket[name].icon = data.icon end
                            if data.requires and bucket[name].requires == nil then bucket[name].requires = data.requires end
                            if data.faction and bucket[name].faction == nil then bucket[name].faction = data.faction end
                        end
                    end
                end
            end
        end
    end

    if TrainerSpellsBuiltin_ProfessionRecipe then
        for profession, skillLevels in pairs(TrainerSpellsBuiltin_ProfessionRecipe) do
            for skillReq, recipes in pairs(skillLevels) do
                local bucket = TrainerSpells:EnsureRecipePath(profession, skillReq)
                for spellID, data in pairs(recipes) do
                    local spellInfo = C_Spell.GetSpellInfo(spellID)
                    local name = spellInfo and spellInfo.name
                    if name and not IsTrainerTaught(profession, name) then
                        if bucket[name] == nil then
                            bucket[name] = {
                                spellID = spellID,
                                icon = data.icon,
                                requires = data.requires,
                                faction = data.faction,
                                source = data.source,
                                sourceLocations = data.sourceLocations
                            }
                        else
                            if bucket[name].spellID == nil then bucket[name].spellID = spellID end
                            if data.icon and bucket[name].icon == nil then bucket[name].icon = data.icon end
                            if data.requires and bucket[name].requires == nil then bucket[name].requires = data.requires end
                            if data.faction and bucket[name].faction == nil then bucket[name].faction = data.faction end
                            if data.source and bucket[name].source == nil then bucket[name].source = data.source end
                            if data.sourceLocations and bucket[name].sourceLocations == nil then bucket[name].sourceLocations = data.sourceLocations end
                        end
                    end
                end
            end
        end
    end
end
