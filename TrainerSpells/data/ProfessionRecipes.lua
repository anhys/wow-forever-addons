TrainerSpellsBuiltin_ProfessionRecipe = TrainerSpellsBuiltin_ProfessionRecipe or {}
function TrainerSpellsBuiltin_AddProfessionRecipes(profession, recipes)
    local existing = TrainerSpellsBuiltin_ProfessionRecipe[profession]
    if not existing then
        TrainerSpellsBuiltin_ProfessionRecipe[profession] = recipes

        return
    end

    for skillReq, entries in pairs(recipes) do
        local bucket = existing[skillReq]
        if not bucket then
            existing[skillReq] = entries
        else
            for spellID, data in pairs(entries) do
                if bucket[spellID] == nil then
                    bucket[spellID] = data
                end
            end
        end
    end
end
