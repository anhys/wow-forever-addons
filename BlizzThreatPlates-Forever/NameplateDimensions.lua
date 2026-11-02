local addon = ForeverNameplates
local rootOwned
local changedFrames = setmetatable({}, {__mode="k"})

local function DimensionProfile(create)
    local appearance = ForeverNameplatesDB and ForeverNameplatesDB.appearance
    if not appearance then return end
    local key = addon:GetNameplateStyleFamily()
    if create then
        appearance.dimensions = appearance.dimensions or {}
        appearance.dimensions[key] = appearance.dimensions[key] or {}
    end
    return appearance.dimensions and appearance.dimensions[key]
end

local function Percent(value)
    return math.max(50, math.min(150, math.floor((tonumber(value) or 100) + 0.5)))
end

function addon:GetNameplateDimensionDefaults()
    if self:GetNameplateStyleFamily()=="JUNDIES" then return 84,104 end
    return 100,100
end

function addon:GetNameplateWidthPercent()
    local profile = DimensionProfile()
    local width = self:GetNameplateDimensionDefaults()
    return Percent(profile and profile.width or width)
end

function addon:GetNameplateHeightPercent()
    local profile = DimensionProfile()
    local _,height = self:GetNameplateDimensionDefaults()
    return Percent(profile and profile.height or height)
end

function addon:GetNativeNameplateBaseSize()
    local driver = NamePlateDriverFrame
    if not driver or not driver.GetNamePlateScale or not driver.GetNamePlateWidth
        or not driver.GetNamePlateHeight then return end
    local style = self:GetNameplateStyle()
    local scale = driver:GetNamePlateScale(style)
    -- These getters calculate public layout values, not live frame bounds.
    return driver:GetNamePlateWidth(style, scale), driver:GetNamePlateHeight(style, scale)
end

local function ApplyHeight(frame)
    if not frame or frame:IsForbidden() then return end
    if InCombatLockdown() and frame:IsProtected() then return end
    local container = frame.HealthBarsContainer
    local baseHeight = NamePlateSetupOptions and NamePlateSetupOptions.healthBarHeight
    if not container or not baseHeight then return end
    if container:IsForbidden() or (InCombatLockdown() and container:IsProtected()) then return end
    local enabled = not addon:GetCompatibilityMode() and not addon:IsATDStyle()
    local factor = enabled and addon:GetNameplateHeightPercent() / 100 or 1
    if factor ~= 1 or changedFrames[frame] then
        -- Keep native anchors: the bar, badge, auras, and name follow this
        -- container. Never change shared Blizzard setup tables or hit points.
        container:SetHeight(baseHeight * factor)
        changedFrames[frame] = factor ~= 1 or nil
    end
end

local function RefreshHeights()
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            if not plate:IsForbidden() then ApplyHeight(plate.UnitFrame) end
        end
    end
end

function addon:ApplyNameplateDimensions()
    if not ForeverNameplatesDB then return end
    local enabled = not self:GetCompatibilityMode() and not self:IsATDStyle()
    local width = enabled and self:GetNameplateWidthPercent() / 100 or 1
    local height = enabled and self:GetNameplateHeightPercent() / 100 or 1
    if not InCombatLockdown() and (width ~= 1 or height ~= 1 or rootOwned)
        and C_NamePlate and C_NamePlate.SetNamePlateSize then
        local baseWidth, baseHeight = self:GetNativeNameplateBaseSize()
        if baseWidth and baseHeight then
            local geometry = self:GetNameplatePreviewGeometry(true)
            -- The engine's full plate also reserves auras, names, and castbars.
            -- Adjust only the bar's contribution, preserving that space.
            C_NamePlate.SetNamePlateSize(baseWidth + geometry.width * (width - 1),
                baseHeight + geometry.height * (height - 1))
            rootOwned = width ~= 1 or height ~= 1 or nil
        end
    end
    RefreshHeights()
    if self:IsATDStyle() and self.RefreshATDStyle then self:RefreshATDStyle() end
    if self.RefreshNativeCCFallbacks then self:RefreshNativeCCFallbacks() end
end

local function SetDimension(key, value)
    -- Shape changes include an engine size update, which is protected in combat.
    if InCombatLockdown() or addon:GetCompatibilityMode() then return end
    local profile = DimensionProfile(true)
    if not profile then return end
    profile[key] = Percent(value)
    addon:ApplyNameplateDimensions()
end

function addon:SetNameplateWidthPercent(value) SetDimension("width", value) end
function addon:SetNameplateHeightPercent(value) SetDimension("height", value) end

function addon:ResetNameplateDimensions()
    if InCombatLockdown() or self:GetCompatibilityMode() then return end
    local profile = DimensionProfile()
    if profile then profile.width, profile.height = nil, nil end
    self:ApplyNameplateDimensions()
end

-- Finish after Blizzard's event handlers have laid out the plates, without
-- hooking methods on its pooled UnitFrames or nameplate driver. Coalesce the
-- events from one layout change; target/faction changes need only bar heights.
local refreshPending,rootPending
local function ScheduleRefresh(updateRoot)
    rootPending=rootPending or updateRoot
    if refreshPending then return end
    refreshPending=true
    local function Run()
        local applyRoot=rootPending
        refreshPending,rootPending=nil,nil
        if applyRoot then addon:ApplyNameplateDimensions() else RefreshHeights() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0,Run) else Run() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("CVAR_UPDATE")
events:RegisterEvent("UNIT_FACTION")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_FOCUS_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:RegisterEvent("UI_SCALE_CHANGED")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate and not plate:IsForbidden() then ApplyHeight(plate.UnitFrame) end
        ScheduleRefresh(false)
    elseif event == "CVAR_UPDATE" then
        if type(unit)=="string" and unit:lower():match("^nameplate") then ScheduleRefresh(true) end
    elseif event == "UNIT_FACTION" then
        if not (issecretvalue and issecretvalue(unit)) and type(unit)=="string"
            and unit:match("^nameplate%d+$") then ScheduleRefresh(false) end
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        ScheduleRefresh(false)
    else
        addon:ApplyNameplateDimensions()
        ScheduleRefresh(true)
    end
end)
