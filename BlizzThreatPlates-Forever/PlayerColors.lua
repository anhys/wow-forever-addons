local addon = ForeverNameplates
local FRIENDLY_CLASS_CVAR = "nameplateShowFriendlyClassColor"
local contexts = {
    world = "Open World", pvp = "Battlegrounds", party = "Dungeons", raid = "Raids",
}
-- Forever 1.60.1.70425 HighlightColor.db2, EndColor:
-- PlayerExtended (type 6), PartyPvPInBG (31), Party (7).
-- These are the unobserved-location baselines. A live selection-color sample
-- takes precedence because PvP flags and group relationships can vary them.
local nativeDefaults = {
    world = {96/255, 96/255, 1},
    pvp = {0, 153/255, 0},
    party = {170/255, 170/255, 1},
    raid = {170/255, 170/255, 1},
}
local sampledUnit
local applyingClassColor, expectedClassColor
local classColorOwnership = {}

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

function addon:GetFriendlyPlayerDefaultColor(context)
    if not contexts[context] then return end
    local samples = ForeverNameplatesDB and ForeverNameplatesDB.friendlyPlayerDefaultSamples
    local color = samples and samples[context] or nativeDefaults[context]
    return color[1], color[2], color[3]
end

function addon:ObserveFriendlyPlayerDefaultColor(unit)
    -- Sample the native relationship API, never an addon-painted health bar.
    -- Lock to one ally until the location/roster/faction changes so a crowd
    -- containing different relationship colors cannot flicker the swatch.
    if sampledUnit and sampledUnit ~= unit then return end
    local player, friend = UnitIsPlayer(unit), UnitIsFriend("player", unit)
    if IsSecret(player) or IsSecret(friend) or not player or not friend then return end
    if UnitIsDeadOrGhost then
        local dead = UnitIsDeadOrGhost(unit)
        if IsSecret(dead) or dead then return end
    end
    if UnitIsConnected then
        local connected = UnitIsConnected(unit)
        if IsSecret(connected) or not connected then return end
    end
    local r, g, b = UnitSelectionColor(unit, true)
    for _, channel in ipairs({r, g, b}) do
        if IsSecret(channel) or type(channel) ~= "number" or channel ~= channel or channel < 0 or channel > 1 then return end
    end
    if r == nil or g == nil or b == nil then return end
    sampledUnit = unit
    local context = self:GetFriendlyPlayerColorContext()
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    local samples = ForeverNameplatesDB.friendlyPlayerDefaultSamples or {}
    ForeverNameplatesDB.friendlyPlayerDefaultSamples = samples
    local old = samples[context]
    if old and old[1] == r and old[2] == g and old[3] == b then return end
    samples[context] = {r, g, b}
    if self.RefreshPlayerColorSwatches then self:RefreshPlayerColorSwatches() end
end

function addon:GetFriendlyPlayerColorContext()
    local _, kind = IsInInstance()
    if kind == "pvp" or kind == "arena" then return "pvp" end
    if kind == "party" or kind == "raid" then return kind end
    return "world"
end

function addon:GetFriendlyPlayerColorContextLabel()
    return contexts[self:GetFriendlyPlayerColorContext()]
end

function addon:GetFriendlyPlayerClassColors(context)
    context = context or self:GetFriendlyPlayerColorContext()
    if not contexts[context] then return false end
    local choices = ForeverNameplatesDB and ForeverNameplatesDB.friendlyPlayerClassColors
    if choices and choices[context] ~= nil then return choices[context] == true end
    -- Read-only before SavedVariables are ready. Migration adopts the previous
    -- global setting for all locations without changing any existing choices.
    return tonumber(self:GetNameplateCVar(FRIENDLY_CLASS_CVAR)) == 1
end

local function InitializeClassColors()
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    local choices = ForeverNameplatesDB.friendlyPlayerClassColors or {}
    ForeverNameplatesDB.friendlyPlayerClassColors = choices
    local previous = tonumber(addon:GetNameplateCVar(FRIENDLY_CLASS_CVAR)) == 1
    for context in pairs(contexts) do
        if choices[context] == nil then choices[context] = previous end
    end
    return choices
end

function addon:ApplyFriendlyPlayerClassColors()
    if self.GetCompatibilityFeatureEnabled and not self:GetCompatibilityFeatureEnabled("playerColors") then
        if classColorOwnership.owned then
            classColorOwnership.owned = nil
            expectedClassColor = classColorOwnership.baseline
            applyingClassColor = true
            self:SetNameplateCVar(FRIENDLY_CLASS_CVAR, classColorOwnership.baseline)
            applyingClassColor = nil
        end
        return
    end
    if not classColorOwnership.owned then
        classColorOwnership.baseline = tonumber(GetCVar(FRIENDLY_CLASS_CVAR)) or 0
        classColorOwnership.owned = true
    end
    InitializeClassColors()
    local desired = self:GetFriendlyPlayerClassColors() and 1 or 0
    expectedClassColor = desired
    applyingClassColor = true
    -- Always set the current choice, even when the live value matches: this
    -- also replaces a stale combat-queued value after another zone change.
    self:SetNameplateCVar(FRIENDLY_CLASS_CVAR, desired)
    applyingClassColor = nil
end

function addon:RefreshPlayerColors()
    if self.RefreshThreatColors then self:RefreshThreatColors() end
    if self.RefreshATDStyle then self:RefreshATDStyle() end
end

function addon:SetFriendlyPlayerClassColors(enabled, context)
    context = context or self:GetFriendlyPlayerColorContext()
    if not contexts[context] then return end
    InitializeClassColors()[context] = enabled and true or false
    if context == self:GetFriendlyPlayerColorContext() then self:ApplyFriendlyPlayerClassColors() end
    self:RefreshPlayerColors()
    if self.RefreshPlayerColorSwatches then self:RefreshPlayerColorSwatches() end
end

function addon:GetFriendlyPlayerColorSettings(context)
    if not contexts[context] then return end
    local settings = ForeverNameplatesDB and ForeverNameplatesDB.friendlyPlayerColors
    local row = settings and settings[context]
    if row and row.color then
        return row.color[1], row.color[2], row.color[3], row.useDefault ~= false
    end
    local r, g, b = self:GetFriendlyPlayerDefaultColor(context)
    return r, g, b, true
end

function addon:GetFriendlyPlayerColorSwatch(context)
    local r, g, b, useDefault = self:GetFriendlyPlayerColorSettings(context)
    if useDefault then return self:GetFriendlyPlayerDefaultColor(context) end
    return r, g, b
end

function addon:SetFriendlyPlayerColor(context, r, g, b, useDefault)
    if not contexts[context] then return end
    local color = {r, g, b}
    for i = 1, 3 do
        if IsSecret(color[i]) or type(color[i]) ~= "number" or color[i] ~= color[i] then return end
        color[i] = math.max(0, math.min(1, color[i]))
    end
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    ForeverNameplatesDB.friendlyPlayerColors = ForeverNameplatesDB.friendlyPlayerColors or {}
    ForeverNameplatesDB.friendlyPlayerColors[context] = {color = color, useDefault = useDefault == true}
    self:RefreshPlayerColors()
end

function addon:ResetFriendlyPlayerColor(context)
    local r, g, b = self:GetFriendlyPlayerColorSettings(context)
    if r then self:SetFriendlyPlayerColor(context, r, g, b, true) end
end

function addon:GetFriendlyPlayerColor(unit, includeDefault)
    if self.GetCompatibilityFeatureEnabled and not self:GetCompatibilityFeatureEnabled("playerColors") then return end
    local player = UnitIsPlayer(unit)
    local friend = UnitIsFriend("player", unit)
    if IsSecret(player) or IsSecret(friend) or not player or not friend then return end
    self:ObserveFriendlyPlayerDefaultColor(unit)
    -- Live rendering follows the applied CVar, not a choice queued in combat.
    if tonumber(GetCVar(FRIENDLY_CLASS_CVAR)) == 1 then
        if not includeDefault then return end -- Native class rendering belongs to Blizzard.
        local r, g, b, colored = self:GetUnitClassColor(unit)
        if colored then return r, g, b, true end
    else
        local r, g, b, useDefault = self:GetFriendlyPlayerColorSettings(self:GetFriendlyPlayerColorContext())
        if not useDefault then return r, g, b, true end
    end
    if includeDefault then
        -- ATD uses the same extended relationship colors as Large/Default.
        -- Forward possible secret channels directly to the StatusBar.
        local r, g, b = UnitSelectionColor(unit, true)
        return r, g, b, true
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({"CVAR_UPDATE", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "GROUP_ROSTER_UPDATE", "UNIT_FACTION", "PLAYER_REGEN_ENABLED", "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED", "FORBIDDEN_NAME_PLATE_UNIT_ADDED", "FORBIDDEN_NAME_PLATE_UNIT_REMOVED",
    "ADDON_LOADED"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, cvar)
    if event == "ADDON_LOADED" then
        if cvar ~= "BlizzThreatPlates-Forever" and cvar ~= "ForeverNameplates" then return end
        addon:ApplyFriendlyPlayerClassColors()
        return
    end
    if event == "NAME_PLATE_UNIT_ADDED" or event == "FORBIDDEN_NAME_PLATE_UNIT_ADDED" then
        addon:ObserveFriendlyPlayerDefaultColor(cvar)
        return
    elseif event == "NAME_PLATE_UNIT_REMOVED" or event == "FORBIDDEN_NAME_PLATE_UNIT_REMOVED" then
        if sampledUnit == cvar then sampledUnit = nil end
        return
    elseif event ~= "CVAR_UPDATE" and event ~= "PLAYER_REGEN_ENABLED" then
        sampledUnit = nil
    end
    if event == "CVAR_UPDATE" then
        if type(cvar) ~= "string" then return end
        local name = cvar:lower()
        if name ~= FRIENDLY_CLASS_CVAR:lower() and name ~= "nameplateshowclasscolor" then return end
        if name == FRIENDLY_CLASS_CVAR:lower() then
            local applied = tonumber(GetCVar(FRIENDLY_CLASS_CVAR)) or 0
            if applied == expectedClassColor then
                expectedClassColor = nil
            elseif not applyingClassColor
                and not (addon.GetCompatibilityMode and addon:GetCompatibilityMode())
                and tonumber(addon:GetNameplateCVar(FRIENDLY_CLASS_CVAR)) == applied then
                -- A change in Blizzard's menu updates only the active location.
                -- Our own zone writes and pending combat choices are not edits
                -- to another location's saved preference.
                InitializeClassColors()[addon:GetFriendlyPlayerColorContext()] = applied == 1
                expectedClassColor = nil
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA"
        or event == "PLAYER_REGEN_ENABLED" then
        addon:ApplyFriendlyPlayerClassColors()
    end
    addon:RefreshPlayerColors()
    if addon.RefreshPlayerColorSwatches then addon:RefreshPlayerColorSwatches() end
end)
