local addon = ForeverNameplates

-- Native-style CC displays: an opt-in broad secure CC row, plus the original
-- Concussion Blow-only fallback when that workaround is off. Both leave aura
-- selection and durations inside the engine rather than inspecting aura data.
local CONCUSSION_BLOW_SPELL_ID = 12809
local GROUP_KEY = "BTPConcussionBlow"
local ICON_SIZE = 30
local activeByUnit = {}
local workaroundByUnit = {}
local framesByUnit = {}
local suppressed = setmetatable({}, {__mode="k"})

function addon:GetNativeCCWorkaround()
    if self.GetCompatibilityFeatureEnabled and self:GetCompatibilityMode() then return self:GetCompatibilityFeatureEnabled("enemyDebuffs") end
    return ForeverNameplatesDB and ForeverNameplatesDB.nativeCCWorkaround == true or false
end

function addon:SetNativeCCWorkaround(enabled)
    if InCombatLockdown() then return false end
    if self.SetCompatibilityFeatureEnabled and self:SetCompatibilityFeatureEnabled("enemyDebuffs",enabled) then return true end
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    ForeverNameplatesDB.nativeCCWorkaround = enabled and true or false
    if not enabled and not self:IsATDStyle() and self.SetATDAuraPreview and self:IsATDAuraPreviewActive() then self:SetATDAuraPreview(false) end
    self:RefreshNativeCCFallbacks()
    return true
end

if C_AddOns and C_AddOns.LoadAddOn then
    pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
end

local function SetContainerActive(container, unit, active)
    if not container then return end
    if active then
        if container:GetUnit() ~= unit then container:SetUnit(unit) end
        container:SetEnabled(true)
        container:Show()
    else
        container:SetEnabled(false)
        container:Hide()
        if not container.SetAuraGroupMaxFrameCount or not container.SetAuraGroupLayout then return end
    end
end

local function CanAccessAuraButton(button)
    -- IsForbidden only covers an explicit forbidden flag. Custom aura buttons
    -- can also deny tainted access conditionally while aura data is secret.
    if button.CanBeAccessedInContext then
        local allowed=button:CanBeAccessedInContext()
        return not (issecretvalue and issecretvalue(allowed)) and allowed==true
    end
    -- Compatibility for clients without the newer context-access query.
    local forbidden=button:IsForbidden()
    return not (issecretvalue and issecretvalue(forbidden)) and not forbidden
end

local function InitializeAuraButton(button)
    button:SetSize(ICON_SIZE, ICON_SIZE)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button:SetIcon(icon)

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawSwipe(true)
    cooldown:SetReverse(true)
    button:SetDurationCooldown(cooldown)

    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetColorTexture(0.12, 0.12, 0.12, 1)
        if side == "TOP" or side == "BOTTOM" then
            border:SetPoint(side.."LEFT", button, side.."LEFT")
            border:SetPoint(side.."RIGHT", button, side.."RIGHT")
            border:SetHeight(1)
        else
            border:SetPoint("TOP"..side, button, "TOP"..side)
            border:SetPoint("BOTTOM"..side, button, "BOTTOM"..side)
            border:SetWidth(1)
        end
    end
end

local function EnsureContainer(frame, lossOfControlFrame)
    if frame.btpConcussionBlowContainer then
        return frame.btpConcussionBlowContainer
    end
    if not CreateFrame or not C_AddOns or not C_AddOns.IsAddOnLoaded
        or not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        return nil
    end

    -- Parenting to Blizzard's slot inherits its scale, visibility, and
    -- placement without reading protected frame measurements.
    local parent = lossOfControlFrame
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    if not ok or not container then return nil end

    container:SetSize(1, 1)
    container:SetPoint("LEFT", lossOfControlFrame, "LEFT")
    container:SetFrameLevel((lossOfControlFrame:GetFrameLevel() or 0) + 2)
    if container.SetFlowLayoutAnchorPoint then container:SetFlowLayoutAnchorPoint("LEFT") end
    if container.SetFlowLayoutGrowthDirection then container:SetFlowLayoutGrowthDirection(1, 1) end
    if container.SetFlowLayoutMaximumLineSize then container:SetFlowLayoutMaximumLineSize(ICON_SIZE) end

    local added = pcall(container.AddAuraGroup, container, GROUP_KEY, "HARMFUL", {
        maxFrameCount = 1,
        candidateFilters = {includeSpellIDs = {[CONCUSSION_BLOW_SPELL_ID] = true}},
        initializeFrame = InitializeAuraButton,
    })
    if not added then
        SetContainerActive(container, nil, false)
        return nil
    end

    frame.btpConcussionBlowContainer = container
    return container
end

local function NativeFallbackEnabled()
    return (not addon:GetCompatibilityMode() or (addon.GetCompatibilityFeatureEnabled
        and addon:GetCompatibilityFeatureEnabled("enemyDebuffs"))) and not addon:IsATDStyle()
end

local function SuppressNativeCC(frame, enabled)
    local auras = frame.AurasFrame
    if not auras or auras:IsForbidden() then return end
    for _, key in ipairs({"CrowdControlListFrame", "LossOfControlFrame", "DebuffListFrame", "BuffListFrame"}) do
        local slot = auras[key]
        if slot and not slot:IsForbidden() then
            if enabled then
                if suppressed[slot] == nil then suppressed[slot] = {alpha=slot:GetAlpha()} end
                slot:SetAlpha(0)
            elseif suppressed[slot] ~= nil then
                slot:SetAlpha(suppressed[slot].alpha)
                suppressed[slot] = nil
            end
        end
    end
end

local function EnsureWorkaroundContainer(frame)
    if frame.btpNativeAuraDisplay then return frame.btpNativeAuraDisplay end
    if not C_AddOns or not C_AddOns.IsAddOnLoaded
        or not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then return end
    -- Independent of the native aura slots: their empty/hidden state must not
    -- suppress the replacement. The engine owns matching and aura lifetimes.
    local display = {buttons={cc={},debuffs={}}}
    local function Container(anchor, direction)
        local ok, container = pcall(CreateFrame, "AuraContainer", nil, frame, "CustomAuraContainerTemplate")
        if not ok or not container then return end
        container:SetEnabled(false)
        container:Hide()
        container:SetSize(1, 1)
        container:SetFrameLevel(frame:GetFrameLevel() + 12)
        container:SetFlowLayoutAnchorPoint(anchor)
        container:SetFlowLayoutGrowthDirection(direction, 1)
        return container
    end
    display.side, display.top = Container("RIGHT", -1), Container("BOTTOMLEFT", 1)
    if not display.side or not display.top then return end
    local function Group(container, key, filter, kind)
        return pcall(container.AddAuraGroup, container, key, filter, {
            maxFrameCount = 0,
            initializeFrame = function(button)
                InitializeAuraButton(button)
                if container==display.side and addon.TrackLeftCCButton then addon:TrackLeftCCButton(button,container) end
                display.buttons[kind][#display.buttons[kind]+1] = button
            end,
            layout = {elementSpacing=2, lineSpacing=2, groupSpacing=2},
        })
    end
    -- PvE CC shares the top row by default, with an optional personal split.
    -- PvP keeps separately configured own/other CC groups on the left.
    if not Group(display.top,"BTPSharedCrowdControl","HARMFUL|CROWD_CONTROL","cc")
        or not Group(display.side,"BTPOwnCrowdControl","HARMFUL|CROWD_CONTROL|PLAYER","cc")
        or not Group(display.side,"BTPOtherCrowdControl","HARMFUL|CROWD_CONTROL|!PLAYER","cc")
        or not Group(display.top,"BTPOwnDebuffs","HARMFUL|PLAYER|!CROWD_CONTROL","debuffs") then return end
    frame.btpNativeAuraDisplay = display
    frame.btpSharedCCContainer = display.top
    return display
end

local function ConfigureWorkaround(display, frame, context)
    local settings = addon:GetNativeAuraSettings(context)
    local enabled = settings.enabled ~= false
    local debuffs = enabled and settings.ownDebuffs ~= false and settings.maxDebuffs or 0
    local shared = enabled and context == "pve" and settings.crowdControl ~= false and settings.maxCrowdControl or 0
    local splitOwn=context=="pve" and settings.ownCrowdControl==true
    local filter=splitOwn and "HARMFUL|CROWD_CONTROL|!PLAYER" or "HARMFUL|CROWD_CONTROL"
    if display.topFilter~=filter then
        local setter=display.top.SetAuraGroupFilterString
        if setter and pcall(setter,display.top,"BTPSharedCrowdControl",filter) then display.topFilter=filter end
    end
    splitOwn=display.topFilter=="HARMFUL|CROWD_CONTROL|!PLAYER"
    local own = enabled and ((context=="pvp" and settings.ownCrowdControl~=false) or (context=="pve" and splitOwn))
        and (settings.maxOwnCrowdControl or 3) or 0
    local other = enabled and context == "pvp" and settings.otherCrowdControl ~= false and settings.maxOtherCrowdControl or 0
    local spacing, ccSize, iconSize = settings.spacing, settings.crowdControlSize, settings.iconSize
    local geometry = addon:GetNameplatePreviewGeometry()
    local anchor = frame.healthBar or frame
    local aboveName = addon:GetNameplateStyleFamily() == (Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.Thin)
        and addon:GetMobNameFontSize()+4 or 0
    local signature = table.concat({context,debuffs,shared,own,other,spacing,ccSize,iconSize,geometry.width,aboveName,tostring(splitOwn)},":")
    if display.signature == signature and display.anchor == anchor then return own+other > 0, shared+debuffs > 0 end
    local function Group(container, key, count)
        container:SetAuraGroupMaxFrameCount(key, count)
        container:SetAuraGroupLayout(key, {elementSpacing=spacing,lineSpacing=spacing,groupSpacing=spacing})
    end
    Group(display.top,"BTPSharedCrowdControl",shared)
    Group(display.side,"BTPOwnCrowdControl",own)
    Group(display.side,"BTPOtherCrowdControl",other)
    Group(display.top,"BTPOwnDebuffs",debuffs)
    -- Expanding a group can allocate new buttons; resize after configuring it.
    -- Engine-owned children may deny access even when IsForbidden is false.
    -- Leave those at their existing size and continue updating editable icons.
    for _,button in ipairs(display.buttons.cc) do
        if CanAccessAuraButton(button) then button:SetSize(ccSize,ccSize) end
    end
    for _,button in ipairs(display.buttons.debuffs) do
        if CanAccessAuraButton(button) then button:SetSize(iconSize,iconSize) end
    end
    local gap = 6
    local count = math.max(1,shared+own+other)
    display.side:SetFlowLayoutMaximumLineSize(count*ccSize+(count-1)*spacing)
    display.top:SetFlowLayoutMaximumLineSize(geometry.width)
    display.side:ClearAllPoints()
    display.side.btpSideAttachment=nil
    if addon.AnchorLeftAuraContainer then addon:AnchorLeftAuraContainer(display.side,frame.namePlateFrame or frame:GetParent())
    else display.side:SetPoint("RIGHT",anchor,"LEFT",-gap,0) end
    display.top:ClearAllPoints()
    display.top:SetPoint("BOTTOMLEFT",anchor,"TOPLEFT",0,gap+aboveName)
    display.signature,display.anchor = signature,anchor
    return own+other > 0, shared+debuffs > 0
end

local function RefreshUnit(unit)
    if type(unit) ~= "string" or (issecretvalue and issecretvalue(unit)) then return end
    local plate = addon:GetPlate(unit)
    if not plate or plate:IsForbidden() then return end
    local frame = plate and plate.UnitFrame
    if not frame or frame:IsForbidden() then return end
    local assignedUnit = frame.unit or frame.displayedUnit
    if (issecretvalue and issecretvalue(assignedUnit)) or assignedUnit ~= unit then return end
    framesByUnit[unit] = frame

    local hostile = UnitCanAttack("player", unit)
    local player = UnitIsPlayer(unit)
    local context = (not issecretvalue or not issecretvalue(player)) and (player and "pvp" or "pve")
    local workaround = NativeFallbackEnabled() and addon:GetNativeCCWorkaround()
        and context and (not issecretvalue or not issecretvalue(hostile)) and hostile
    local display = frame.btpNativeAuraDisplay
    if workaround then display = EnsureWorkaroundContainer(frame) end
    workaround = workaround and display ~= nil
    local showSide, showTop
    if workaround then
        showSide,showTop = ConfigureWorkaround(display,frame,context)
    end
    if display then
        if addon.AnchorLeftAuraContainer then addon:AnchorLeftAuraContainer(display.side,plate) end
        display.unit = unit
        SetContainerActive(display.side, unit, workaround and showSide)
        SetContainerActive(display.top, unit, workaround and showTop)
        if addon.SetLeftCCLayout then
            local settings=addon:GetNativeAuraSettings(context or "pve")
            addon:SetLeftCCLayout(display.side,plate,settings.crowdControlSize,settings.spacing,workaround and showSide)
        end
    end
    if addon.UpdateNativeAuraPreview then addon:UpdateNativeAuraPreview(frame,plate,context or "pve",workaround==true) end
    workaroundByUnit[unit] = workaround and display or nil
    SuppressNativeCC(frame, workaround)

    local auras = frame.AurasFrame
    local lossOfControlFrame = auras and not auras:IsForbidden() and auras.LossOfControlFrame
    if lossOfControlFrame and lossOfControlFrame:IsForbidden() then lossOfControlFrame = nil end
    local shouldEnable = NativeFallbackEnabled() and not workaround and lossOfControlFrame
        and lossOfControlFrame:IsShown()
    local container = frame.btpConcussionBlowContainer
    if shouldEnable then container = EnsureContainer(frame, lossOfControlFrame) end

    SetContainerActive(container, unit, shouldEnable and container ~= nil)
    activeByUnit[unit] = shouldEnable and container or nil
end

function addon:RefreshNativeCCFallbacks()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local frame = plate and not plate:IsForbidden() and plate.UnitFrame
        if frame and frame:IsForbidden() then frame = nil end
        local unit = frame and (frame.unit or frame.displayedUnit)
        if unit and (not issecretvalue or not issecretvalue(unit)) then
            RefreshUnit(unit)
        elseif frame then
            SetContainerActive(frame.btpConcussionBlowContainer, nil, false)
            if frame.btpNativeAuraDisplay then
                SetContainerActive(frame.btpNativeAuraDisplay.side,nil,false)
                SetContainerActive(frame.btpNativeAuraDisplay.top,nil,false)
                if addon.ClearLeftCCLayout then addon:ClearLeftCCLayout(frame.btpNativeAuraDisplay.side) end
            end
            if frame.btpNativeAuraPreview then
                frame.btpNativeAuraPreview.anchor:Hide()
                if addon.ClearLeftCCLayout and frame.btpNativeAuraPreview.auraPreview then addon:ClearLeftCCLayout(frame.btpNativeAuraPreview.auraPreview.sideFrame) end
            end
            SuppressNativeCC(frame, false)
        end
    end
end

-- Keep Blizzard's UpdateShownState method untouched. The replacement aura
-- containers already track their effects internally; only the old one-spell
-- fallback needs an event refresh after native aura visibility has updated.
local pendingRefresh={}
local function ScheduleRefresh(unit)
    if type(unit)~="string" or (issecretvalue and issecretvalue(unit)) then return end
    if pendingRefresh[unit] then return end
    pendingRefresh[unit]=true
    local function Run()
        pendingRefresh[unit]=nil
        RefreshUnit(unit)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0,Run) else Run() end
end

local function ScheduleTrackedRefresh()
    for unit in pairs(framesByUnit) do ScheduleRefresh(unit) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("CVAR_UPDATE")
events:RegisterEvent("UNIT_FACTION")
events:RegisterEvent("UNIT_AURA")
events:RegisterEvent("LOSS_OF_CONTROL_UPDATE")
events:RegisterEvent("LOSS_OF_CONTROL_ADDED")
events:SetScript("OnEvent", function(_, event, unitOrCVar)
    if event == "NAME_PLATE_UNIT_ADDED" then
        RefreshUnit(unitOrCVar)
        ScheduleRefresh(unitOrCVar)
    elseif event == "UNIT_AURA" or event == "LOSS_OF_CONTROL_UPDATE" or event == "LOSS_OF_CONTROL_ADDED" then
        if not NativeFallbackEnabled() or addon:GetNativeCCWorkaround() then return end
        if not (issecretvalue and issecretvalue(unitOrCVar)) and type(unitOrCVar)=="string"
            and unitOrCVar:match("^nameplate%d+$") then
            ScheduleRefresh(unitOrCVar)
        elseif event~="UNIT_AURA" then
            for unit in pairs(framesByUnit) do ScheduleRefresh(unit) end
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if (issecretvalue and issecretvalue(unitOrCVar)) or type(unitOrCVar)~="string" then return end
        local container = activeByUnit[unitOrCVar]
        activeByUnit[unitOrCVar] = nil
        if container and container:GetUnit() == unitOrCVar then SetContainerActive(container, nil, false) end
        local replacement = workaroundByUnit[unitOrCVar]
        if replacement then
            for _,container in ipairs({replacement.side,replacement.top}) do
                if container:GetUnit() == unitOrCVar then SetContainerActive(container, nil, false) end
            end
        end
        workaroundByUnit[unitOrCVar] = nil
        local frame = framesByUnit[unitOrCVar]
        framesByUnit[unitOrCVar] = nil
        if frame and not frame:IsForbidden()
            and (not frame.btpNativeAuraDisplay or frame.btpNativeAuraDisplay.unit == unitOrCVar) then
            SuppressNativeCC(frame, false)
        end
    elseif event == "UNIT_FACTION" then
        if not (issecretvalue and issecretvalue(unitOrCVar)) and type(unitOrCVar) == "string"
            and unitOrCVar:match("^nameplate%d+$") then
            RefreshUnit(unitOrCVar)
            ScheduleRefresh(unitOrCVar)
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event=="PLAYER_TARGET_CHANGED" then
        addon:RefreshNativeCCFallbacks()
        ScheduleTrackedRefresh()
    elseif not (issecretvalue and issecretvalue(unitOrCVar)) and type(unitOrCVar) == "string"
        and unitOrCVar:lower():match("^nameplate") then
        addon:RefreshNativeCCFallbacks()
        ScheduleTrackedRefresh()
    end
end)
