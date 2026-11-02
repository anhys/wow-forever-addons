local addon = ForeverNameplates
local pendingMasks = {}
local retry = CreateFrame("Frame")

local function ReadIndex(name, index)
    if C_CVar and C_CVar.GetCVarBitfield then return C_CVar.GetCVarBitfield(name, index) end
    if GetCVarBitfield then return GetCVarBitfield(name, index) end
    return false
end

function addon:IsNameplateBitfieldEnabled(name, index, applied)
    local mask = not applied and pendingMasks[name] or nil
    if mask ~= nil then return math.floor(mask / 2 ^ (index - 1)) % 2 == 1 end
    return ReadIndex(name, index) and true or false
end

function addon:GetNameplateBitfieldMask(name)
    if pendingMasks[name] ~= nil then return pendingMasks[name] end
    -- These settings store encoded strings, not decimal masks. Read through
    -- the native API, retaining other bits when one checkbox is changed.
    local mask = 0
    for index = 1, 32 do
        if ReadIndex(name, index) then mask = mask + 2 ^ (index - 1) end
    end
    return mask
end

function addon:HasPendingNameplateBitfield(name) return pendingMasks[name] ~= nil end

function addon:SetNameplateBitfieldMask(name, mask)
    mask = math.max(0, math.floor(tonumber(mask) or 0))
    if InCombatLockdown() then
        pendingMasks[name] = mask
        retry:RegisterEvent("PLAYER_REGEN_ENABLED")
        return false
    end
    pendingMasks[name] = nil
    if self:GetNameplateBitfieldMask(name) == mask then return true end
    -- Let the engine preserve/encode the setting. Do not write a decimal
    -- string into a bitfield CVar or move protected Settings widgets.
    local setter = C_CVar and C_CVar.SetCVarBitfield or SetCVarBitfield
    if setter then
        for index = 1, 32 do
            local enabled = math.floor(mask / 2 ^ (index - 1)) % 2 == 1
            if ReadIndex(name, index) ~= enabled then setter(name, index, enabled) end
        end
    elseif CVarCallbackRegistry and CVarCallbackRegistry.SetCVarBitfieldMask then
        CVarCallbackRegistry:SetCVarBitfieldMask(name, mask)
    else
        return false
    end
    return true
end

function addon:SetNameplateBitfieldIndex(name, index, enabled)
    local mask, bitValue = self:GetNameplateBitfieldMask(name), 2 ^ (index - 1)
    local active = math.floor(mask / bitValue) % 2 == 1
    if active ~= enabled then mask = enabled and mask + bitValue or mask - bitValue end
    return self:SetNameplateBitfieldMask(name, mask)
end

retry:SetScript("OnEvent", function(self)
    if InCombatLockdown() then return end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    for name, mask in pairs(pendingMasks) do addon:SetNameplateBitfieldMask(name, mask) end
end)
