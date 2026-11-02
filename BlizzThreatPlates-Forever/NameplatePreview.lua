local addon = ForeverNameplates

local function LayoutNumber(value, fallback, allowZero)
    if issecretvalue and issecretvalue(value) then return fallback end
    if type(value) ~= "number" then return fallback end
    if value > 0 or (allowZero and value == 0) then return value end
    return fallback
end

function addon:UsesUpdatedNameplateLayout()
    local _, build
    if GetBuildInfo then _, build = GetBuildInfo() end
    -- 70425 changed the badge from a RIGHT anchor to TOPRIGHT/BOTTOMRIGHT.
    -- Unknown builds use the current layout; known older builds retain theirs.
    return not tonumber(build) or tonumber(build) >= 70425
end

function addon:GetNameplatePreviewGeometry(ignoreDimensions)
    -- Only public configuration is read here. No live frame is inspected.
    local result = {scale=UIParent:GetEffectiveScale()}
    if self:IsATDStyle() then
        local draft=self.GetSavedDevNameplateStyle and self:GetSavedDevNameplateStyle()
        if draft then
            result.width,result.height=draft.bar.width*draft.bar.scale,draft.bar.height*draft.bar.scale
            return result
        end
        if self.IsJundiesStyle and self:IsJundiesStyle() then
            local layout=self:GetJundiesStyleLayout(ignoreDimensions)
            result.width,result.height=layout.width,layout.height
            return result
        end
        local factor = 1 + ((self:GetNameplateSize() - 2) * 0.10)
        result.width, result.height = 130 * factor, 15 * factor
        if not ignoreDimensions and self.GetNameplateWidthPercent then
            result.width = result.width * self:GetNameplateWidthPercent() / 100
            result.height = result.height * self:GetNameplateHeightPercent() / 100
        end
        return result
    end

    local setup, constants = NamePlateSetupOptions or {}, NamePlateConstants or {}
    local horizontal = LayoutNumber(setup.horizontalScale, 1)
    local baseWidth = setup.useClassicHealthBar
        and (constants.CLASSIC_NAME_PLATE_WIDTH or constants.CLASSIC_NAMEPLATE_WIDTH)
        or (constants.NAME_PLATE_WIDTH or constants.NAMEPLATE_WIDTH)
    local plateWidth = LayoutNumber(baseWidth, 190) * horizontal
    if C_NamePlate and C_NamePlate.GetNamePlateSize then
        local ok, configuredWidth = pcall(C_NamePlate.GetNamePlateSize)
        if ok then plateWidth = LayoutNumber(configuredWidth, plateWidth) end
    end
    if self.GetNativeNameplateBaseSize then
        plateWidth = LayoutNumber(self:GetNativeNameplateBaseSize(), plateWidth)
    end

    local inset = LayoutNumber(setup.insetWidth,
        LayoutNumber(constants.HORIZONTAL_INSET, 12) * horizontal, true)
    local classification = LayoutNumber(setup.classificationScale, 1)
    result.height = LayoutNumber(setup.healthBarHeight, 20)
    result.levelFontSize = LayoutNumber(setup.levelFontHeight, 10)
    result.edgeAnchoredLevel = self:UsesUpdatedNameplateLayout()
    result.level = {
        width=LayoutNumber(setup.playerLevelDiffWidth,
            LayoutNumber(constants.LEVEL_INDICATOR_WIDTH, 28) * classification),
        height=LayoutNumber(setup.playerLevelDiffHeight, 23),
        x=5, y=0, selectionTop=4,
    }
    result.width = plateWidth - 2 * inset
    if not result.edgeAnchoredLevel then
        result.width = result.width - result.level.width - result.level.x
    end
    if setup.useClassicHealthBar then result.width = result.width - 24.25 * horizontal end
    if not ignoreDimensions and self.GetNameplateWidthPercent and not self:GetCompatibilityMode() then
        result.width = result.width * self:GetNameplateWidthPercent() / 100
        result.height = result.height * self:GetNameplateHeightPercent() / 100
    end
    if result.edgeAnchoredLevel then
        -- In 70425 the native RIGHT-only reservation no longer applies to the
        -- badge's TOPRIGHT anchor. Its two anchors make it bar-height + 5.
        result.level.height = result.height + 5
        result.level.y = 0.5
        result.level.selectionTop = 3
    end
    result.width = math.max(1, result.width)
    return result
end

local function CVarScale(name)
    if not GetCVar then return 1 end
    local ok, value = pcall(GetCVar, name)
    if not ok or (issecretvalue and issecretvalue(value)) then return 1 end
    return LayoutNumber(tonumber(value), 1)
end

function addon:GetNameplatePreviewRenderScale(panelScale)
    local root = WorldFrame or UIParent
    local worldScale = LayoutNumber(root and root:GetEffectiveScale(), 1)
    return worldScale * CVarScale("nameplateGlobalScale")
        * CVarScale("nameplateSelectedScale") / LayoutNumber(panelScale, 1)
end

function addon:FitNameplatePreviewScale(desiredScale, width, height, availableWidth, availableHeight)
    desiredScale = LayoutNumber(desiredScale, 1)
    width, height = LayoutNumber(width, 1), LayoutNumber(height, 1)
    local fraction = math.min(1,
        LayoutNumber(availableWidth, 1) / (width * desiredScale),
        LayoutNumber(availableHeight, 1) / (height * desiredScale))
    return desiredScale * fraction, fraction
end
