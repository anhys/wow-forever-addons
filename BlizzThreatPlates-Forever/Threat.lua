local addon = ForeverNameplates
local plates = {}
local frame = CreateFrame("Frame")
local elapsed = 0
local UPDATE_INTERVAL = 0.10
local flashFrames = setmetatable({}, {__mode = "k"})
local FLASH_SECONDS = 1.2

function addon:GetThreatFlashEnabled()
    if self.GetCompatibilityFeatureEnabled and self:GetCompatibilityMode() then return self:GetCompatibilityFeatureEnabled("threatFlash") end
    if ForeverNameplatesDB and ForeverNameplatesDB.threatFlash ~= nil then
        return ForeverNameplatesDB.threatFlash == true
    end
    return addon.defaults.threatFlash == true
end

local function StopFlash(data)
    data.flashStarted = nil
    if data.flash then data.flash:Hide() end
end

function addon:SetThreatFlashEnabled(enabled)
    if self.SetCompatibilityFeatureEnabled and self:SetCompatibilityFeatureEnabled("threatFlash",enabled) then return end
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    ForeverNameplatesDB.threatFlash = enabled and true or false
    for _, data in pairs(plates) do
        data.lastKind = nil
        StopFlash(data)
    end
end

local function GetFlash(bar)
    if flashFrames[bar] then return flashFrames[bar] end
    local border = CreateFrame("Frame", nil, bar)
    border:SetPoint("TOPLEFT", bar, "TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 3, -3)
    if border.SetIgnoreParentAlpha then border:SetIgnoreParentAlpha(true) end
    border.edges = {}
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local edge = border:CreateTexture(nil, "OVERLAY")
        if side == "TOP" or side == "BOTTOM" then
            edge:SetPoint(side.."LEFT")
            edge:SetPoint(side.."RIGHT")
            edge:SetHeight(3)
        else
            edge:SetPoint("TOP"..side)
            edge:SetPoint("BOTTOM"..side)
            edge:SetWidth(3)
        end
        border.edges[#border.edges + 1] = edge
    end
    flashFrames[bar] = border
    return border
end

local function FindNativeHealthBar(plate)
    local uf = plate and plate.UnitFrame
    if not uf then return end

    local candidates = {uf.healthBar, uf.HealthBar, uf.healthbar, uf.Health}
    for _, bar in ipairs(candidates) do
        if bar and not (bar.IsForbidden and bar:IsForbidden())
            and bar.GetObjectType and bar:GetObjectType() == "StatusBar"
            and bar.GetStatusBarTexture and bar:GetStatusBarTexture() then
            return bar
        end
    end
end

local function EnsureData(unit)
    local plate = addon:GetPlate(unit)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
    local unitFrame = plate.UnitFrame
    if unitFrame and unitFrame.IsForbidden and unitFrame:IsForbidden() then return end

    local data = plates[unit]
    if not data or data.plate ~= plate then
        if data then StopFlash(data) end
        data = {plate = plate}
        plates[unit] = data
    end

    if not data.bar then
        data.bar = FindNativeHealthBar(plate)
    end
    if data.bar and data.bar.IsForbidden and data.bar:IsForbidden() then return end
    return data
end

local function GetColor(kind)
    local profile = addon:GetDungeonRaidThreatProfile()
    if profile then
        return addon:GetDungeonRaidThreatColor(profile, kind)
    end
    return addon:GetThreatColor(kind)
end

local function PaintNative(bar, kind)
    if addon.GetCompatibilityFeatureEnabled and not addon:GetCompatibilityFeatureEnabled("threatColors") then return end
    local r, g, b = GetColor(kind)
    bar.btpThreatColored = true
    bar:SetStatusBarColor(r, g, b, 1)
end

local function RestorePlayerColor(data)
    if not data.playerColored then return end
    -- Clear first: Blizzard's update calls our hook again.
    data.playerColored = nil
    if CompactUnitFrame_UpdateHealthColor then
        CompactUnitFrame_UpdateHealthColor(data.plate.UnitFrame)
    end
end

local function UpdateUnit(unit)
    local data = EnsureData(unit)
    if not data or not data.bar then return end

    local compatibility = addon:GetCompatibilityMode()
    local optional = compatibility and addon.GetCompatibilityFeatureEnabled
    if optional and not addon:GetCompatibilityFeatureEnabled("threatColors")
        and not addon:GetCompatibilityFeatureEnabled("questColor") and (data.questColored or data.bar.btpThreatColored) then
        data.questColored, data.bar.btpThreatColored = nil, nil
        if CompactUnitFrame_UpdateHealthColor then CompactUnitFrame_UpdateHealthColor(data.plate.UnitFrame) end
    end
    if compatibility and (not optional or not (addon:GetCompatibilityFeatureEnabled("threatColors")
        or addon:GetCompatibilityFeatureEnabled("questColor") or addon:GetCompatibilityFeatureEnabled("playerColors")
        or addon:GetCompatibilityFeatureEnabled("threatFlash"))) then
        data.lastKind = nil
        StopFlash(data)
        RestorePlayerColor(data)
        if data.questColored or data.bar.btpThreatColored then
            data.questColored, data.bar.btpThreatColored = nil, nil
            if CompactUnitFrame_UpdateHealthColor then CompactUnitFrame_UpdateHealthColor(data.plate.UnitFrame) end
        end
        return
    end
    if not addon:IsThreatNPC(unit) then
        data.lastKind = nil
        StopFlash(data)
        if not addon:IsATDStyle() and (not compatibility or (optional and addon:GetCompatibilityFeatureEnabled("playerColors"))) then
            local r, g, b, colored = addon:GetFriendlyPlayerColor(unit, false)
            if colored then
                data.playerColored = true
                data.bar:SetStatusBarColor(r, g, b, 1)
                return
            end
        end
        -- Resetting an override must repaint an idle ally immediately.
        RestorePlayerColor(data)
        if compatibility and (not optional or not addon:GetCompatibilityFeatureEnabled("playerColors")) then return end
        local r, g, b, colored = addon:GetPvPColor(unit)
        if colored then data.playerColored = true; data.bar:SetStatusBarColor(r, g, b, 1) end
        return
    end

    local flashBar = data.bar
    if addon:IsATDStyle() then
        flashBar = addon:GetATDHealthBar(data.plate)
    end
    if data.flashBar ~= flashBar then
        StopFlash(data)
        data.flashBar = flashBar
    end

    local tapped = UnitIsTapDenied and UnitIsTapDenied(unit)
    local questColored = not (issecretvalue and issecretvalue(tapped))
        and not tapped and addon:ShouldColorQuestMob(unit)
    if questColored then
        data.bar:SetStatusBarColor(addon:GetQuestColor())
    elseif data.questColored then
        -- Removing the quest override needs an explicit repaint: Blizzard
        -- may not update the native reaction color again on an idle mob.
        local r, g, b = UnitSelectionColor(unit)
        if not (issecretvalue and issecretvalue(tapped)) and tapped then r, g, b = 0.9, 0.9, 0.9 end
        data.bar:SetStatusBarColor(r, g, b, 1)
    end
    data.questColored = questColored

    local status = UnitThreatSituation("player", unit)
    -- A restricted status cannot safely drive transitions or comparisons.
    if issecretvalue and issecretvalue(status) then
        data.lastKind = nil
        StopFlash(data)
        return
    end
    local kind
    if status == 3 then
        kind = "secure"
    elseif status == 1 or status == 2 then
        kind = "warning"
    elseif status == 0 then
        local fighting = UnitAffectingCombat(unit)
        if not (issecretvalue and issecretvalue(fighting)) and fighting then kind = "lost" end
    end
    if not questColored and kind then PaintNative(data.bar, kind)
    end
    if not addon:GetThreatFlashEnabled() then
        data.lastKind = nil
        StopFlash(data)
        return
    end
    if data.plate == addon:GetPlate("target") then
        data.lastKind = kind
        StopFlash(data)
        return
    end
    if flashBar and data.lastKind == "secure" and (kind == "warning" or kind == "lost") then
        data.flash = GetFlash(flashBar)
        data.flashStarted = GetTime()
    end
    data.lastKind = kind
    if not kind or kind == "secure" then StopFlash(data) end
    if data.flashStarted then
        local age = GetTime() - data.flashStarted
        if age >= FLASH_SECONDS then
            StopFlash(data)
        else
            local r, g, b = GetColor(kind)
            for _, edge in ipairs(data.flash.edges) do edge:SetColorTexture(r, g, b, 1) end
            data.flash:SetAlpha(0.25 + 0.75 * (0.5 + 0.5 * math.cos(age * math.pi * 5)))
            data.flash:Show()
        end
    end
end


-- Blizzard can repaint its native health-bar color during health updates.
-- Reapply our threat color immediately afterward so the bar does not flash
-- back to Blizzard's default enemy red between updates.
local function ReapplyNativeThreatColor(frame)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
    local frameBar = frame.healthBar or frame.HealthBar or frame.healthbar or frame.Health
    if not frameBar then return end
    for unit, data in pairs(plates) do
        if data and data.bar == frameBar then
            UpdateUnit(unit)
            return
        end
    end
end

if hooksecurefunc and CompactUnitFrame_UpdateHealthColor then
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", ReapplyNativeThreatColor)
end

function addon:RefreshThreatColors()
    for unit in pairs(plates) do
        UpdateUnit(unit)
    end
end

local function RemoveUnit(unit)
    if plates[unit] then StopFlash(plates[unit]) end
    plates[unit] = nil
end

frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")

frame:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        -- Paint during creation instead of allowing the reaction color to
        -- remain visible until the old delayed initialization callback.
        addon:ClearQuestMobCache(unit)
        UpdateUnit(unit)
        local addedPlate = addon:GetPlate(unit)
        C_Timer.After(0, function()
            if UnitExists(unit) and addon:GetPlate(unit) == addedPlate then
                addon:ClearQuestMobCache(unit)
                UpdateUnit(unit)
            end
        end)
        -- Retain a readiness retry for clients that attach the health bar or
        -- quest tooltip later. This is no longer the first paint.
        C_Timer.After(0.15, function()
            if UnitExists(unit) and addon:GetPlate(unit) == addedPlate then
                addon:ClearQuestMobCache(unit)
                UpdateUnit(unit)
            end
        end)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        RemoveUnit(unit)
    elseif event == "PLAYER_TARGET_CHANGED" then
        addon:RefreshThreatColors()
    elseif event == "PLAYER_REGEN_ENABLED" then
        for _, data in pairs(plates) do data.lastKind = nil; StopFlash(data) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        for u in pairs(plates) do RemoveUnit(u) end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED"
        or event == "ZONE_CHANGED_NEW_AREA" then
        addon:RefreshThreatColors()
    elseif unit and plates[unit] then
        UpdateUnit(unit)
    end
end)

frame:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < UPDATE_INTERVAL then return end
    elapsed = 0
    for unit in pairs(plates) do UpdateUnit(unit) end
end)
