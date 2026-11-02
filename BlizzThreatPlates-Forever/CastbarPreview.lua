local addon = ForeverNameplates
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function Atlas(texture, name)
    if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(name) then return false end
    return pcall(texture.SetAtlas, texture, name, false)
end

local function Font(text, object, size, outlined)
    text:SetFontObject(object or GameFontHighlightSmall)
    local path, _, flags = text:GetFont()
    if path then text:SetFont(path, size, outlined and "OUTLINE" or flags) end
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
end

function addon:CreateCastbarPreview(preview, viewport, caption, plate)
    -- Detached artwork only. Never create a native casting/nameplate template,
    -- simulate a cast on a protected frame, or query a real unit's cast data.
    local bar = CreateFrame("StatusBar", nil, plate.content)
    bar:SetStatusBarTexture(WHITE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0.62)
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", 1, 0)
    background:SetPoint("BOTTOMRIGHT", -1, 0)
    local border = bar:CreateTexture(nil, "OVERLAY", nil, -1)
    local icon = bar:CreateTexture(nil, "OVERLAY", nil, 1)
    icon:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowBolt")
    local shield = bar:CreateTexture(nil, "OVERLAY", nil, 1)
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetBlendMode("ADD")
    local important = bar:CreateTexture(nil, "OVERLAY")
    local targeted = bar:CreateTexture(nil, "OVERLAY")
    local name = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetText("Shadow Bolt")
    name:SetWordWrap(false)
    name:SetJustifyH("LEFT")
    local target = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    target:SetText("You")
    target:SetJustifyH("RIGHT")
    local time = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    time:SetPoint("RIGHT", -3, 0)
    time:SetWidth(26)
    time:SetJustifyH("RIGHT")
    local data = {bar=bar, plate=plate, icon=icon, shield=shield, spark=spark,
        name=name, target=target, time=time, important=important, targeted=targeted,
        elapsed=1.55, protected=false}
    preview.btpCastbarPreview = data

    local function Enabled(key, fallback)
        local enum = Enum and Enum.NamePlateCastBarDisplay or {}
        return addon:IsNameplateBitfieldEnabled("nameplateCastBarDisplay", enum[key] or fallback)
    end

    preview.Refresh = function()
        plate.followHealthInfo = true
        plate:Refresh()
        local atd, geometry = addon:IsATDStyle(), plate.geometry
        local setup, constants = NamePlateSetupOptions or {}, NamePlateConstants or {}
        local settings = addon:GetATDCastbarSettings()
        local vertical, horizontal = setup.verticalScale or 1, setup.horizontalScale or 1
        local width, height, offsetY, x = geometry.width, setup.castBarHeight or 10 * vertical, 0, 0
        local iconWidth, iconHeight = setup.castIconWidth or 12 * vertical, setup.castIconHeight or 12 * vertical
        local inside = setup.spellNameInsideCastBar
        if inside == nil then inside = addon:GetCastbarThick() end
        local classic = not atd and setup.useClassicCastBar
        local showName, showIcon, showTarget, showTime, showCast
        local nameSize, timeSize = setup.castBarFontHeight or 10 * vertical, 8
        if atd then
            local layout = addon:GetATDCastbarLayout()
            width, height, offsetY = layout.width, layout.height, layout.offsetY
            x = 0 -- ATD width changes extend right from the health bar's left edge.
            nameSize, timeSize = settings.nameSize or 9, settings.timeSize or 8
            showName, showTime, showCast = settings.showName ~= false, settings.showTime ~= false, settings.enabled ~= false
            showIcon, showTarget, inside = false, false, true
        else
            -- Cast containers span both insets. Only the old layout reserves
            -- badge width from the health bar; the castbar keeps that space.
            if not geometry.edgeAnchoredLevel and geometry.level then width = width + geometry.level.width + geometry.level.x end
            if classic then x = 17.25 * horizontal end
            offsetY = -(setup.castBarToHealthBarSpacing or constants.CAST_BAR_TO_HEALTH_BAR_SPACING or 2)
            showName, showIcon, showTarget = Enabled("SpellName", 1), Enabled("SpellIcon", 2), Enabled("SpellTarget", 3)
            if data.protected and setup.hideIconWhenNotInterruptible ~= false then showIcon = false end
            showTime, showCast = false, true -- Native nameplate template has no countdown label.
        end
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", plate.bar, "BOTTOMLEFT", x, offsetY)
        bar:SetSize(width, height)
        bar:SetShown(showCast)
        data.width = width
        background:SetTexture(WHITE)
        background:SetVertexColor(1, 1, 1, 1)
        border:ClearAllPoints()
        border:Hide()
        local fill = bar:GetStatusBarTexture()
        fill:SetTexture(WHITE)
        fill:SetVertexColor(1, 1, 1, 1)
        if atd then
            background:SetColorTexture(0.02, 0.02, 0.02, 1)
            local color = data.protected and settings.protectedColor or settings.interruptibleColor
            color = color or (data.protected and {0.55, 0.55, 0.55} or {0.68, 0.55, 0.06})
            bar:SetStatusBarColor(color[1], color[2], color[3], 1)
            border:SetTexture(WHITE)
            border:SetVertexColor(0, 0, 0, 1)
            border:SetPoint("TOPLEFT", -1, 1)
            border:SetPoint("BOTTOMRIGHT", 1, -1)
            -- A background rim, rather than an overlay covering the fill.
            border:SetDrawLayer("BACKGROUND", -1)
            border:Show()
        elseif classic then
            background:SetColorTexture(0, 0, 0, 0.5)
            fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
            bar:SetStatusBarColor(data.protected and 0.6 or 1, data.protected and 0.6 or 0.7, data.protected and 0.6 or 0, 1)
            border:SetDrawLayer("OVERLAY", -1)
            border:SetTexture("Interface\\Tooltips\\Nameplate-Border-Castbar")
            border:SetTexCoord(0, 1, 0.5, 1)
            border:SetVertexColor(1, 1, 1, 1)
            border:SetSize(setup.castBarBorderWidth or 128 * horizontal, setup.castBarBorderHeight or 16 * vertical)
            border:SetPoint("CENTER", bar, "CENTER", -8.625 * horizontal, -0.5 * vertical)
            border:Show()
        else
            Atlas(background, "ui-castingbar-background")
            local types = CastingBarTypeInfo or {}
            local info = types[data.protected and "uninterruptable" or "standard"] or {}
            local atlas = info.filling or (data.protected and "ui-castingbar-uninterruptable" or "ui-castingbar-filling-standard")
            if Atlas(fill, atlas) then bar:SetStatusBarColor(1, 1, 1, 1)
            else bar:SetStatusBarColor(data.protected and 0.6 or 1, data.protected and 0.6 or 0.7, data.protected and 0.6 or 0, 1) end
        end
        icon:ClearAllPoints()
        icon:SetSize(iconWidth, iconHeight)
        if classic then icon:SetPoint("CENTER", border, "LEFT", 11.5 * horizontal, 0)
        elseif inside then icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
        else icon:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0) end
        icon:SetShown(showCast and showIcon)
        name:ClearAllPoints()
        target:ClearAllPoints()
        Font(name, atd and GameFontHighlightSmall or SystemFont_NamePlateCastBar, nameSize, atd)
        Font(target, SystemFont_NamePlateCastBar, nameSize, false)
        Font(time, GameFontHighlightSmall, timeSize, true)
        if atd then
            name:SetPoint("LEFT", bar, "LEFT", 2, 0)
            name:SetPoint("RIGHT", showTime and time or bar, showTime and "LEFT" or "RIGHT", -3, 0)
        elseif classic then
            name:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -vertical)
            name:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, -vertical)
            target:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0)
        else
            name:SetPoint("LEFT", icon, "RIGHT", 2, 0)
            -- Limit sample text without reading any unit/cast text dimensions.
            name:SetWidth(math.max(1, width - iconWidth - 6 - (showTarget and nameSize * 4 or 0)))
            target:SetPoint("LEFT", name, "RIGHT", 2, 0)
            target:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        end
        name:SetShown(showCast and showName)
        target:SetShown(showCast and showTarget)
        time:SetShown(showCast and showTime)
        if addon.IsJundiesStyle and addon:IsJundiesStyle() then addon:ApplyJundiesCastbarFonts(name,time) end
        shield:ClearAllPoints()
        if classic then
            shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Small-Shield")
            shield:SetPoint("TOPLEFT", bar, "TOPLEFT", -20 * horizontal, 11 * vertical)
            shield:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 13 * horizontal, -13 * vertical)
        else
            Atlas(shield, "nameplates-InterruptShield")
            shield:SetSize(setup.castBarShieldWidth or 10 * vertical, setup.castBarShieldHeight or 12 * vertical)
            shield:SetPoint("RIGHT", icon, "RIGHT", 0, 0)
        end
        shield:SetShown(showCast and not atd and data.protected)
        spark:ClearAllPoints()
        if classic then spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark"); spark:SetSize(32, 32)
        else Atlas(spark, "ui-castingbar-pip"); spark:SetSize(4, 12) end
        spark:SetShown(showCast and not atd)
        local importantOn = not atd and Enabled("HighlightImportantCasts", 4)
        local targetedOn = not atd and Enabled("HighlightWhenCastTarget", 5)
        Atlas(important, "ui-hud-nameplates-importantcast")
        Atlas(targeted, "ui-hud-nameplates-targetedbyenemy")
        important:ClearAllPoints()
        local edge = addon:GetNameplateSize() < 2 and 20 or 26
        important:SetPoint("TOPLEFT", bar, "TOPLEFT", -edge, 3)
        important:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", edge == 26 and 25 or edge, -3)
        important:SetShown(showCast and importantOn)
        targeted:ClearAllPoints()
        targeted:SetPoint("TOPLEFT", bar, "TOPLEFT", -4, 4)
        targeted:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 4, -4)
        targeted:SetShown(showCast and targetedOn)

        local bounds = plate.bounds
        local left, right, top, bottom = bounds.left, bounds.right, bounds.top, bounds.bottom
        if showCast then
            local castLeft = -geometry.width / 2 + x
            local castTop = -geometry.height / 2 + offsetY
            local pad = classic and 20 * horizontal or (importantOn and edge or (targetedOn and 4 or 2))
            left, right = math.min(left, castLeft - pad), math.max(right, castLeft + width + pad)
            top, bottom = math.max(top, castTop + 4), math.max(bottom, -castTop + height + (atd and 1 or 6))
            if not inside and (showIcon or showName or showTarget or data.protected) then
                bottom = math.max(bottom, -castTop + height + math.max(iconHeight, nameSize) + 2)
            elseif classic and showTarget then bottom = math.max(bottom, -castTop + height + nameSize) end
            if classic and data.protected then bottom = math.max(bottom, -castTop + height + 13 * vertical) end
        end
        local scale, fraction = addon:FitNameplatePreviewScale(addon:GetNameplatePreviewRenderScale(preview:GetEffectiveScale()),
            right - left + 4, top + bottom + 4, viewport:GetWidth(), viewport:GetHeight())
        data.bounds = {left=left, right=right, top=top, bottom=bottom}
        plate.content:SetScale(scale)
        plate.bar:ClearAllPoints()
        plate.bar:SetPoint("CENTER", plate.content, "CENTER", -(left + right) / 2, (bottom - top) / 2)
        caption:SetText(fraction < 0.995 and string.format("Preview (%d%% scale)", math.floor(fraction * 100 + 0.5)) or "Preview")
    end
    preview:SetScript("OnUpdate", function(_, elapsed)
        data.elapsed = (data.elapsed + elapsed) % 2.5
        local fraction = data.elapsed / 2.5
        bar:SetValue(fraction)
        time:SetFormattedText("%.1f", 2.5 - data.elapsed)
        spark:ClearAllPoints()
        spark:SetPoint("CENTER", bar, "LEFT", (data.width or 1) * fraction, 0)
        local pulse = 0.5 + 0.5 * math.sin(data.elapsed * 4)
        important:SetAlpha(pulse)
        targeted:SetAlpha(pulse)
    end)
    preview.SetProtectedSample = function(_, protected)
        data.protected = protected and true or false
        preview:Refresh()
    end
    return preview
end
