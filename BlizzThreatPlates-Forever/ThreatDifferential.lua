local addon = ForeverNameplates
local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

-- Text colors are independent of the health-bar palette.
function addon:ApplyThreatNumberColor(label, mob, fallbackValue, mode)
    local ok, status = pcall(UnitThreatSituation, "player", mob)
    local kind
    if ok and not IsSecret(status) and type(status) == "number" then
        if status == 3 then
            kind = "secure"
        elseif status == 1 or status == 2 then
            kind = "warning"
        else
            kind = "lost"
        end
    else
        -- Retain the differential sign fallback when the state is unavailable.
        kind = not IsSecret(fallbackValue) and type(fallbackValue) == "number" and fallbackValue >= 0 and "secure" or "lost"
    end
    local r,g,b = self:GetThreatTextColor(kind, mode)
    label:SetTextColor(r,g,b,1)
end

local function ReadThreat(unit, mob)
    if not UnitDetailedThreatSituation then return nil, "API unavailable" end
    local ok, tanking, status, scaled, raw, threat = pcall(UnitDetailedThreatSituation, unit, mob)
    if not ok then return nil, "API call blocked" end
    -- Inspect secrecy BEFORE nil checks, formatting, comparisons or arithmetic.
    if IsSecret(threat) then return nil, "secret" end
    if type(threat) ~= "number" then return nil, "no threat data" end
    return threat, "readable"
end

local function ComparisonUnits()
    local units = {"pet"}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            units[#units+1] = "raid"..i
            units[#units+1] = "raidpet"..i
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            units[#units+1] = "party"..i
            units[#units+1] = "partypet"..i
        end
    end
    return units
end

function addon:GetThreatDifferentialForUnit(mob)
    if not UnitExists(mob) then return nil, "Unit unavailable" end
    local mine, reason = ReadThreat("player", mob)
    if not mine then return nil, "Player threat: "..reason end
    local highest
    for _, unit in ipairs(ComparisonUnits()) do
        if UnitExists(unit) then
            local self = UnitIsUnit(unit, "player")
            if IsSecret(self) then return nil, "Unit identity restricted" end
            if not self then
                local value, state = ReadThreat(unit, mob)
                if state == "secret" or state == "API call blocked" then
                    return nil, "Comparison threat restricted"
                end
                if value and (not highest or value > highest) then highest = value end
            end
        end
    end
    if not highest then return nil, "Need another player/pet with threat" end
    -- A roster differential, not the aggro-pull threshold (110%/130%).
    return mine - highest, "Player minus highest group/pet raw threat"
end

function addon:GetSelectedThreatDifferential()
    if not UnitExists("target") then return nil, "Select an enemy" end
    return self:GetThreatDifferentialForUnit("target")
end

function addon:ProbeThreatAccess()
    local version, build = GetBuildInfo()
    print("BTP threat probe: client "..version.." build "..build)
    local mobs = {"target"}
    -- Compare the target alias with three visible nameplate tokens. Never
    -- read names or GUIDs to identify secret units; print the public tokens.
    local count = 0
    for i = 1, 40 do
        local unit = "nameplate"..i
        if self:GetPlate(unit) then
            mobs[#mobs+1] = unit
            count = count + 1
            if count == 3 then break end
        end
    end
    for _, mob in ipairs(mobs) do
        local value, state = ReadThreat("player", mob)
        print(mob.." / player: "..state..(value and (" ("..string.format("%.0f", value)..")") or ""))
        local differential, reason = self:GetThreatDifferentialForUnit(mob)
        print(mob.." / differential: "..(differential and string.format("%+.0f", differential) or reason))
    end
    for _, unit in ipairs(ComparisonUnits()) do
        if UnitExists(unit) then
            local value, state = ReadThreat(unit, "target")
            print("target / "..unit..": "..state..(value and (" ("..string.format("%.2f", value).." raw threat)") or ""))
        end
    end
    local value, state = self:GetSelectedThreatDifferential()
    print("Differential: "..(value and string.format("%+.0f raw threat", value) or state))
end

local display = CreateFrame("Frame", nil, UIParent)
display:SetSize(90, 24)
display:Hide()

-- Threat Differential on Nameplates-inspired presentation:
-- large outlined number on the LEFT side of the selected nameplate.
local text = display:CreateFontString(nil, "OVERLAY")
text:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE")
-- Natural text bounds let left-side icons follow the actual number width.
text:SetPoint("RIGHT",display,"RIGHT",0,0)
text:SetJustifyH("RIGHT")
text:SetJustifyV("MIDDLE")
local liveThreatPlate
local function PublishLiveThreat(plate)
    if addon.SetNameplateThreatAttachment then
        if liveThreatPlate and liveThreatPlate~=plate then
            addon:SetNameplateThreatAttachment(liveThreatPlate,text,"differential",false)
        end
        if plate then addon:SetNameplateThreatAttachment(plate,text,"differential",true) end
    end
    liveThreatPlate=plate
end

function addon:GetThreatOverlayAnchor(plate)
    if not plate then return nil end
    if self:IsATDStyle() and self.GetATDHealthBar then
        local bar = self:GetATDHealthBar(plate)
        if bar then return bar end
    end
    local frame = plate.unitFrame
    local bar = frame and (frame.healthBar or frame.HealthBar or frame.healthbar)
    if bar and bar.GetObjectType then return bar end
    frame = plate.UnitFrame
    bar = frame and (frame.healthBar or frame.HealthBar or frame.healthbar)
    if bar and bar.GetObjectType then return bar end
    return plate
end

local function AnchorThreat(region, bar, unit, plate, label)
    local x, y = addon:GetOverlayPosition("threat")
    x = addon:GetThreatDisplayX(unit, x, plate, label or region, y)
    region:ClearAllPoints()
    region:SetPoint("RIGHT", bar, "LEFT", x, y)
end

-- Session-only snapshots, keyed by a readable nameplate token and its current
-- frame assignment. Removal/addition events invalidate recycled assignments.
local snapshots, freeLabels = {}, {}
function addon:GetThreatDifferentialSize()
    local value = ForeverNameplatesDB and ForeverNameplatesDB.threatDifferentialSize
    if type(value) ~= "number" or value ~= value then value = self.defaults.threatDifferentialSize end
    return math.max(10, math.min(32, math.floor(value + 0.5)))
end
function addon:SetThreatDifferentialSize(value)
    if type(value) ~= "number" or value ~= value then return end
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    ForeverNameplatesDB.threatDifferentialSize = math.max(10, math.min(32, math.floor(value + 0.5)))
    local size = self:GetThreatDifferentialSize()
    text:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
    display:SetSize(math.max(90, size * 6), math.max(24, size + 4))
    for _, entry in pairs(snapshots) do entry.label:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
end
local SNAPSHOT_HOLD_SECONDS = 2
function addon:GetThreatSnapshotSeconds()
    local value = ForeverNameplatesDB and ForeverNameplatesDB.threatSnapshotSeconds
    if type(value) ~= "number" or value ~= value then value = addon.defaults.threatSnapshotSeconds end
    return math.max(3, math.min(10, math.floor(value + 0.5)))
end
function addon:SetThreatSnapshotSeconds(value)
    if type(value) ~= "number" or value ~= value then return end
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    ForeverNameplatesDB.threatSnapshotSeconds = math.max(3, math.min(10, math.floor(value + 0.5)))
end
local function ForgetSnapshot(unit)
    local entry = snapshots[unit]
    if not entry then return end
    if addon.SetNameplateThreatAttachment then addon:SetNameplateThreatAttachment(entry.plate,entry.label,"differential",false) end
    entry.label:SetText("")
    entry.label:Hide()
    entry.label:ClearAllPoints()
    entry.label:SetParent(UIParent)
    freeLabels[#freeLabels + 1] = entry.label
    snapshots[unit] = nil
end
local function ClearSnapshots()
    for unit in pairs(snapshots) do ForgetSnapshot(unit) end
end
local function SnapshotToken(plate)
    local token = plate and plate.UnitFrame and plate.UnitFrame.unit
    if IsSecret(token) or type(token) ~= "string" then return nil end
    if not token:match("^nameplate%d+$") then return nil end
    if addon:GetPlate(token) ~= plate then return nil end
    return token
end
local function Remember(plate, value, now)
    -- Readable threat can exist while only a pet is fighting. Snapshot
    -- eligibility follows valid threat data, not the player's UI lockdown.
    local token = SnapshotToken(plate)
    if not token then return end
    local entry = snapshots[token]
    if entry and entry.plate ~= plate then ForgetSnapshot(token); entry = nil end
    if not entry then
        local label = table.remove(freeLabels) or UIParent:CreateFontString(nil, "OVERLAY")
        label:SetParent(plate)
        label:SetFont(STANDARD_TEXT_FONT, addon:GetThreatDifferentialSize(), "OUTLINE")
        label:SetJustifyH("RIGHT")
        -- Native non-target dimming must not dim the two-second hold.
        if label.SetIgnoreParentAlpha then label:SetIgnoreParentAlpha(true) end
        entry = {plate = plate, label = label}
        snapshots[token] = entry
    end
    entry.value, entry.sampledAt = value, now
    entry.departedAt = nil
end
local function RefreshSnapshots(selected, now)
    local duration = addon:GetThreatSnapshotSeconds()
    for unit, entry in pairs(snapshots) do
        if entry.plate ~= selected and not entry.departedAt then entry.departedAt = now end
        local age = entry.departedAt and (now - entry.departedAt) or 0
        if age >= duration or addon:GetPlate(unit) ~= entry.plate
            or not entry.plate:IsShown() then
            ForgetSnapshot(unit)
        elseif entry.plate == selected then
            entry.departedAt = nil
            entry.label:Hide()
            if addon.SetNameplateThreatAttachment then addon:SetNameplateThreatAttachment(entry.plate,entry.label,"differential",false) end
        else
            local bar = addon:GetThreatOverlayAnchor(entry.plate)
            entry.label:SetText(string.format("*%+.0f", entry.value))
            AnchorThreat(entry.label, bar, unit, entry.plate)
            addon:ApplyThreatNumberColor(entry.label, unit, entry.value)
            local alpha = 1
            if age > SNAPSHOT_HOLD_SECONDS then
                local fading = age - SNAPSHOT_HOLD_SECONDS
                local remaining = 1 - fading / (duration - SNAPSHOT_HOLD_SECONDS)
                local blink = 0.65 + 0.35 * math.cos(fading * math.pi * 4)
                alpha = remaining * blink
            end
            entry.label:SetAlpha(alpha)
            entry.label:Show()
            if addon.SetNameplateThreatAttachment then addon:SetNameplateThreatAttachment(entry.plate,entry.label,"differential",true) end
        end
    end
end

local function Refresh()
    local mode = addon:GetThreatDisplayMode()
    if mode == "percentage" or not addon:IsThreatDifferentialActive() then
        PublishLiveThreat(nil)
        text:SetText("")
        ClearSnapshots()
        return
    end
    local plate = addon:GetPlate("target")
    local now = GetTime()
    if mode == "mixed" then ClearSnapshots() else RefreshSnapshots(plate, now) end
    if not plate then PublishLiveThreat(nil); text:SetText(""); return end
    local bar = addon:GetThreatOverlayAnchor(plate)

    local value = addon:GetSelectedThreatDifferential()
    if value then
        if mode == "differential" then Remember(plate, value, now) end
        addon:ApplyThreatNumberColor(text, "target", value, "differential")
        text:SetText(string.format("%+.0f", value))
        AnchorThreat(display, bar, "target", plate, text)
        PublishLiveThreat(plate)
    else
        PublishLiveThreat(nil)
        local token = SnapshotToken(plate)
        if token then ForgetSnapshot(token) end
        -- API status and missing-comparison messages belong in the manual
        -- probe only. The nameplate display stays empty until a number exists.
        text:SetText("")
    end
end
function addon:IsLiveThreatDifferentialShown(plate)
    return plate ~= nil and liveThreatPlate == plate
end
-- Resolve the target number first, then let percentages fill the remaining
-- plates (including the target if its raw comparison is unavailable).
function addon:RefreshThreatDisplays()
    Refresh()
    if self.RefreshThreatPercentages then self:RefreshThreatPercentages() end
end
function addon:RefreshThreatDifferential() self:RefreshThreatDisplays() end
function addon:GetThreatDisplayMode()
    local mode = ForeverNameplatesDB and ForeverNameplatesDB.threatDisplayMode
    -- Retire the experimental mode without resetting other saved choices.
    if mode == "total" then ForeverNameplatesDB.threatDisplayMode = "differential" end
    return (mode == "percentage" or mode == "mixed") and mode or "differential"
end
function addon:SetThreatDisplayMode(mode)
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    ForeverNameplatesDB.threatDisplayMode = (mode == "percentage" or mode == "mixed") and mode or "differential"
    ClearSnapshots()
    self:RefreshThreatDisplays()
end
function addon:GetThreatDifferentialEnabled()
    if ForeverNameplatesDB and ForeverNameplatesDB.threatDifferential ~= nil then
        return ForeverNameplatesDB.threatDifferential == true
    end
    return addon.defaults.threatDifferential == true
end
function addon:GetThreatDifferentialTankOnly()
    if ForeverNameplatesDB and ForeverNameplatesDB.threatDifferentialTankOnly ~= nil then
        return ForeverNameplatesDB.threatDifferentialTankOnly == true
    end
    return addon.defaults.threatDifferentialTankOnly == true
end
function addon:IsThreatDifferentialActive()
    if not self:GetThreatDifferentialEnabled() then return false end
    if not self:GetThreatDifferentialTankOnly() then return true end
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    if IsSecret(role) or type(role) ~= "string" then return false end
    return role == "TANK"
end
function addon:SetThreatDifferentialEnabled(enabled)
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    ForeverNameplatesDB.threatDifferential = enabled and true or false
    local active = self:IsThreatDifferentialActive()
    display:SetShown(active)
    self:RefreshThreatDisplays()
end
function addon:SetThreatDifferentialTankOnly(enabled)
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    ForeverNameplatesDB.threatDifferentialTankOnly = enabled and true or false
    local active = self:IsThreatDifferentialActive()
    display:SetShown(active)
    self:RefreshThreatDisplays()
end
local elapsed = 0
display:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.25 then return end
    elapsed = 0
    addon:RefreshThreatDisplays()
end)
display:RegisterEvent("PLAYER_ENTERING_WORLD")
display:RegisterEvent("PLAYER_TARGET_CHANGED")
display:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
display:RegisterEvent("NAME_PLATE_UNIT_ADDED")
display:RegisterEvent("PLAYER_REGEN_ENABLED")
display:RegisterEvent("GROUP_ROSTER_UPDATE")
display:RegisterEvent("PLAYER_ROLES_ASSIGNED")
display:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_REMOVED" or event == "NAME_PLATE_UNIT_ADDED" then
        if not IsSecret(unit) and type(unit) == "string" then ForgetSnapshot(unit) end
        if event == "NAME_PLATE_UNIT_REMOVED" then PublishLiveThreat(nil); text:SetText(""); return end
    elseif event == "PLAYER_REGEN_ENABLED" then
        ClearSnapshots()
    end
    if event == "PLAYER_ENTERING_WORLD" then
        ClearSnapshots()
        addon:SetThreatDifferentialSize(addon:GetThreatDifferentialSize())
        display:SetShown(addon:IsThreatDifferentialActive())
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
        local active = addon:IsThreatDifferentialActive()
        display:SetShown(active)
        if not active then PublishLiveThreat(nil); text:SetText(""); ClearSnapshots() end
    end
    addon:RefreshThreatDisplays()
end)
SLASH_BTPTHREATPROBE1 = "/btpthreat"
SlashCmdList.BTPTHREATPROBE = function() addon:ProbeThreatAccess() end
