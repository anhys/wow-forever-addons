-- Live percentage display restored without diagnostic probes.
local addon = ForeverNameplates
local entries = {}
-- Public formatting rules only; Blizzard selects the rule and formats the value.
-- The final rule prevents its default small-number fallback exposing decimals.
local percentageFormat = {breakpointData = {
    {breakpoint=1000000000, abbreviation="b", significandDivisor=100000000, fractionDivisor=10, abbreviationIsGlobal=false},
    {breakpoint=1000000, abbreviation="m", significandDivisor=100000, fractionDivisor=10, abbreviationIsGlobal=false},
    {breakpoint=1000, abbreviation="K", significandDivisor=100, fractionDivisor=10, abbreviationIsGlobal=false},
    {breakpoint=0, abbreviation="", significandDivisor=1, fractionDivisor=1, abbreviationIsGlobal=false},
}}
local function PaintPercentage(label, percentage)
    -- Native abbreviation accepts secret numbers. Its output may also be secret:
    -- forward it to the native text sink without inspecting or concatenating it.
    if AbbreviateNumbers then
        local ok, compact = pcall(AbbreviateNumbers, percentage, percentageFormat)
        if ok then
            local secret = issecretvalue and issecretvalue(compact)
            if secret or type(compact) == "string" then
                local painted = pcall(label.SetFormattedText, label, "%s%%", compact)
                if painted then return true end
            end
        end
    end
    -- Older client or unsupported secret formatting: retain the full lead.
    return pcall(label.SetFormattedText, label, "%.0f%%", percentage)
end
local function HasThreat(source, mob)
    local ok, status = pcall(UnitThreatSituation, source, mob)
    if not ok or (issecretvalue and issecretvalue(status)) then return false end
    -- Status zero is a valid threat entry; nil is no entry.
    return type(status) == "number"
end
local comparisonUnits, comparisonKind, comparisonCount = {}, nil, nil
local function ComparisonUnits()
    local raid = IsInRaid()
    local kind = raid and "raid" or (IsInGroup() and "party" or "solo")
    local count = raid and GetNumGroupMembers() or (kind == "party" and GetNumSubgroupMembers() or 0)
    if kind == comparisonKind and count == comparisonCount then return comparisonUnits end
    for key in pairs(comparisonUnits) do comparisonUnits[key] = nil end
    comparisonKind, comparisonCount = kind, count
    local units = comparisonUnits
    units[1] = "pet"
    if raid then
        for i = 1, count do
            units[#units + 1] = "raid"..i
            units[#units + 1] = "raidpet"..i
        end
    elseif kind == "party" then
        for i = 1, count do
            units[#units + 1] = "party"..i
            units[#units + 1] = "partypet"..i
        end
    end
    return units
end
local function HasThreatComparison(mob, units)
    if not HasThreat("player", mob) then return false end
    for _, source in ipairs(units) do
        local ok, isPlayer = pcall(UnitIsUnit, source, "player")
        if ok and not (issecretvalue and issecretvalue(isPlayer)) and isPlayer == false then
            if HasThreat(source, mob) then return true end
        end
    end
    return false
end
local function ReadCombat(unit)
    local ok, fighting = pcall(UnitAffectingCombat, unit)
    if not ok or (issecretvalue and issecretvalue(fighting)) then return nil end
    return fighting == true
end
local function ApplyCombatVisibility(label, unit)
    local ok, fighting = pcall(UnitAffectingCombat, unit)
    if not ok then return false end
    if issecretvalue and issecretvalue(fighting) then
        if not C_CurveUtil or not C_CurveUtil.EvaluateColorValueFromBoolean then return false end
        return pcall(function()
            label:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(fighting, 1, 0))
        end)
    end
    label:SetAlpha(1)
    return fighting == true
end
local function Clear(unit)
    local entry = entries[unit]
    if entry and entry.visible then
        if addon.SetNameplateThreatAttachment then addon:SetNameplateThreatAttachment(entry.plate,entry.label,"percentage",false) end
        entry.label:SetText("")
        entry.label:Hide()
        entry.visible = false
    end
end
function addon:IsLiveThreatPercentageShown(unit)
    return entries[unit] and entries[unit].visible == true
end
local function Refresh()
    local mode = addon:GetThreatDisplayMode()
    local active = addon:IsThreatDifferentialActive() and (mode == "percentage" or mode == "mixed")
    active = active and (ReadCombat("player") or ReadCombat("pet"))
    if not active then
        for unit in pairs(entries) do Clear(unit) end
        return
    end
    local selected = addon:GetPlate("target")
    local comparisonUnits = ComparisonUnits()
    local fontSize = addon:GetThreatDifferentialSize()
    local x, y = addon:GetOverlayPosition("threat")
    for i = 1, 40 do
        local unit = "nameplate"..i
        -- Reuse this existing 0.25-second/event refresh; no second poller.

        local plate = active and addon:GetPlate(unit)
        local threatUnit = plate and plate == selected and "target" or unit
        if not plate or not plate:IsShown()
            or (mode == "mixed" and addon:IsLiveThreatDifferentialShown(plate))
            or not HasThreatComparison(threatUnit, comparisonUnits) then
            Clear(unit)
        else
            local entry = entries[unit]
            if not entry then
                entry = {
                    label = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal"),
                }
                entries[unit] = entry
                entry.label:SetJustifyH("RIGHT")
            end
            local label = entry.label
            if entry.plate and entry.plate~=plate and addon.SetNameplateThreatAttachment then
                addon:SetNameplateThreatAttachment(entry.plate,label,"percentage",false)
            end
            entry.plate=plate
            if label:GetParent() ~= plate then label:SetParent(plate) end
            if entry.fontSize ~= fontSize then
                label:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
                entry.fontSize = fontSize
            end
            local bar = addon:GetThreatOverlayAnchor(plate)
            local ok, percentage = pcall(UnitThreatPercentageOfLead, "player", threatUnit)
            -- Check secrecy first; only inspect nil/type on ordinary values.
            local secret = ok and issecretvalue and issecretvalue(percentage)
            if ok and (secret or type(percentage) == "number") then
                local painted = PaintPercentage(label, percentage)
                painted = painted and ApplyCombatVisibility(label, threatUnit)
                entry.visible = painted
                label:SetShown(painted)
                if painted then addon:ApplyThreatNumberColor(label, threatUnit, nil, "percentage") end
                if painted then
                    local unitX = addon:GetThreatDisplayX(unit, x, plate, label, y)
                    if entry.anchor ~= bar or entry.x ~= unitX or entry.y ~= y then
                        label:ClearAllPoints()
                        label:SetPoint("RIGHT", bar, "LEFT", unitX, y)
                        entry.anchor, entry.x, entry.y = bar, unitX, y
                    end
                end
                if not painted then label:SetText("") end
            else
                Clear(unit)
            end
            if addon.SetNameplateThreatAttachment then addon:SetNameplateThreatAttachment(plate,label,"percentage",entry.visible==true) end

        end
    end
end
function addon:RefreshThreatPercentages() Refresh() end
local driver = CreateFrame("Frame")
-- Periodic refresh is shared with ThreatDifferential.lua.
driver:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
driver:RegisterEvent("NAME_PLATE_UNIT_ADDED")
driver:RegisterEvent("PLAYER_TARGET_CHANGED")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
driver:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
driver:RegisterEvent("GROUP_ROSTER_UPDATE")
driver:RegisterEvent("UNIT_PET")
driver:RegisterEvent("PLAYER_ROLES_ASSIGNED")
driver:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_REMOVED" then
        Clear(unit)

    else addon:RefreshThreatDisplays() end
end)
