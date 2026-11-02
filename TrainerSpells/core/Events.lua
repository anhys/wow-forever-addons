local _, TrainerSpells = ...
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("TRAINER_SHOW")
f:RegisterEvent("TRAINER_UPDATE")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_UPDATE")
f:RegisterEvent("UNIT_PET")
f:RegisterEvent("SPELLS_CHANGED")
local captureScheduled = false
local merchantCaptureScheduled = false
local petSyncScheduled = false
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "TrainerSpells" then
        TrainerSpells_Data = TrainerSpells_Data or {}
        TrainerSpells_Ignored = TrainerSpells_Ignored or {}
        TrainerSpells_IgnoredNames = TrainerSpells_IgnoredNames or {}
        TrainerSpells_Character = TrainerSpells_Character or {}
        TrainerSpells_Character.collapsedGroups = TrainerSpells_Character.collapsedGroups or {}
        TrainerSpells_Character.learnedSpellsPet = TrainerSpells_Character.learnedSpellsPet or {}
        if TrainerSpells_Character.showIgnoredInTrainer == nil then TrainerSpells_Character.showIgnoredInTrainer = false end
        TrainerSpells_Character.rowHeight = TrainerSpells_Character.rowHeight or 16
        TrainerSpells_PetData = TrainerSpells_PetData or {}
        TrainerSpells_PetTrainerData = TrainerSpells_PetTrainerData or {}
        TrainerSpells_ProfessionData = TrainerSpells_ProfessionData or {}
        TrainerSpells_RecipeData = TrainerSpells_RecipeData or {}
        TrainerSpells:SetVersion()
        TrainerSpells:InitializeSettings()
        TrainerSpells:MergeBuiltinData()
        TrainerSpells:RemoveNonClassSpellsFromClassData()
        TrainerSpells_IgnoredProfessions = TrainerSpells_IgnoredProfessions or {}
        _G.TrainerSpells_ToggleIgnoreProfessionSpell = TrainerSpells_ToggleIgnoreProfessionSpell
        _G.TrainerSpells_IsProfessionSpellIgnored = TrainerSpells_IsProfessionSpellIgnored
        TrainerSpells:MigrateLegacyProfessionIgnores()
    elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
        if TrainerSpells.DebugTrainerEnabled then TrainerSpells:EnableTrainerDebugFilters() end
        do
            local isTradeskill = IsTradeskillTrainer and IsTradeskillTrainer()
            local professionKey, professionSkillLine
            if isTradeskill then professionKey, professionSkillLine = TrainerSpells:DetectTrainerProfession() end
            TrainerSpells:DebugTrainer("Event %s: npcName=%s npcGUID=%s isTradeskill=%s professionKey=%s professionSkillLine=%s", event, tostring(UnitName("npc")), tostring(UnitGUID and UnitGUID("npc")), tostring(isTradeskill), tostring(professionKey), tostring(professionSkillLine))
        end

        TrainerSpells:EnsureTrainerUpdateOverrideInstalled()
        TrainerSpells:EnsureTrainerFilterHookInstalled()
        if TrainerSpells.DebugTrainerEnabled and ClassTrainerFrame and TrainerSpellsScanButton == nil then
            local scanButton = CreateFrame("Button", "TrainerSpellsScanButton", ClassTrainerFrame, "UIPanelButtonTemplate")
            scanButton:SetSize(80, 22)
            scanButton:SetText("Scannen")
            scanButton:SetPoint("BOTTOMLEFT", ClassTrainerFrame, "TOPRIGHT", 0, 0)
            scanButton:SetScript("OnClick", function()
                local ok, err = pcall(function() TrainerSpells:ScanAllTrainerRequirements() end)
                if not ok then TrainerSpells:MSG("|cffff5555TrainerSpells Fehler:|r " .. tostring(err)) end
            end)
        end

        if C_Timer then
            if not captureScheduled then
                captureScheduled = true
                C_Timer.After(0.1, function()
                    captureScheduled = false
                    TrainerSpells:CaptureTrainer()
                    TrainerSpells:CaptureTrainerRequirements()
                end)
            end
        else
            TrainerSpells:CaptureTrainer()
            TrainerSpells:CaptureTrainerRequirements()
        end
    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
        if C_Timer then
            if not merchantCaptureScheduled then
                merchantCaptureScheduled = true
                C_Timer.After(0.1, function()
                    merchantCaptureScheduled = false
                    TrainerSpells:CaptureMerchant()
                end)
            end
        else
            TrainerSpells:CaptureMerchant()
        end
    elseif event == "SPELLS_CHANGED" or (event == "UNIT_PET" and arg1 == "player") then
        if C_Timer then
            if not petSyncScheduled then
                petSyncScheduled = true
                C_Timer.After(1, function()
                    petSyncScheduled = false
                    TrainerSpells:SyncKnownPetSpellsForActivePet()
                end)
            end
        else
            TrainerSpells:SyncKnownPetSpellsForActivePet()
        end
    end
end)

TrainerSpells_Capture = function() TrainerSpells:CaptureTrainer() end
TrainerSpells_CaptureMerchant = function() TrainerSpells:CaptureMerchant() end
TrainerSpells_SyncPetSpells = function() TrainerSpells:SyncKnownPetSpellsForActivePet() end
