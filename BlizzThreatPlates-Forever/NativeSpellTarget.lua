local addon = ForeverNameplates
local cvar = "nameplateCastBarDisplay"
local updating = false
local ready = false

local function SpellTargetIndex()
    return Enum and Enum.NamePlateCastBarDisplay and Enum.NamePlateCastBarDisplay.SpellTarget or 3
end

function addon:SyncNativeSpellTarget()
    if not ready or updating or not ForeverNameplatesDB then return end
    updating = true
    local db = ForeverNameplatesDB
    local index = SpellTargetIndex()
    if self:GetTargetNamesEnabled() then
        local enabled = self:IsNameplateBitfieldEnabled(cvar, index)
        -- Keep the preference in SavedVariables so a reload during a combat
        -- queue cannot lose it. An external attempt to enable it is remembered.
        if db.nativeSpellTargetPreference == nil or enabled then
            db.nativeSpellTargetPreference = enabled
        end
        if enabled then self:SetNameplateBitfieldIndex(cvar, index, false) end
    elseif db.nativeSpellTargetPreference ~= nil then
        -- Retain the backup until the restoration actually reaches the game.
        if self:SetNameplateBitfieldIndex(cvar, index, db.nativeSpellTargetPreference) then
            db.nativeSpellTargetPreference = nil
        end
    end
    updating = false
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("CVAR_UPDATE")
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        ready = true
    elseif event == "CVAR_UPDATE" and name ~= cvar then
        return
    end
    addon:SyncNativeSpellTarget()
end)
