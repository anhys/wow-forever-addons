local addon = ForeverNameplates

-- Addon-owned ATD presentation. Native geometry and aura tracking stay intact.
-- Never mutate Blizzard's native health StatusBar or its TextStatusBar strings.
-- Health data is obtained through Blizzard's Midnight-safe heal prediction
-- calculator and is passed directly to our own StatusBar sinks.

local ATD_WIDTH = 130
local ATD_HEIGHT = 15
local tracked = {}
local NAME_FONT = "Fonts\\2002.TTF"
local HEALTH_FONT = "Fonts\\FRIZQT__.TTF" -- DorisPP unavailable; wider reference-like numerals
local SOLID = "Interface\\Buttons\\WHITE8X8"
local ATD_AURA_SIZE = 24
local ATD_CC_AURA_SIZE = 30
local ATD_AURA_GAP = 6
local ATD_AURA_SPACING = 2
local ATD_MAX_AURAS = 6
local ATD_MAX_CC_AURAS = 3
local ATD_MAX_EXTERNAL_CC_AURAS = 3
local auraPreviewActive = false
local auraPreviewGeneration = 0

-- Let our border textures follow the moving plate at subpixel positions.
-- Independently snapping thin strips can make their thickness jump in motion.
local function SmoothBorderTexture(texture)
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
end

local function AnchorOverlay(anchor, frame)
    -- The old layout reserved width for the level badge, placing the native
    -- bar left of center. The wider layout no longer needs that correction.
    local x, y = 19, -3
    if addon:UsesUpdatedNameplateLayout() then x, y = 0, -6 end
    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER", frame.healthBar or frame, "CENTER", x, y)
end

local previewAuras = {
    {kind = "ownCC", large = true, texture = "Interface\\Icons\\Ability_WarStomp", count = "2"},
    {kind = "ownCC", large = true, texture = "Interface\\Icons\\Spell_Shadow_Possession", count = "4"},
    {kind = "otherCC", large = true, texture = "Interface\\Icons\\Spell_Frost_FrostNova", count = "3"},
    {kind = "debuff", texture = "Interface\\Icons\\Ability_Warrior_WarCry", count = "18"},
    {kind = "debuff", texture = "Interface\\Icons\\Spell_Nature_ThunderClap", count = "8"},
}

local function LayoutAuraPreview(preview, lineWidth, useSideCC, settings, context)
    local leftOffset,sideCount,topCount,debuffCount = 0,0,0,0
    local spacing=settings.spacing or ATD_AURA_SPACING
    local topLimit=context=="pvp" and (settings.otherCrowdControl~=false and settings.maxOtherCrowdControl or 0)
        or (settings.crowdControl~=false and settings.maxCrowdControl or 0)
    local sideLimit=useSideCC and (context~="pvp" or settings.ownCrowdControl~=false) and (settings.maxOwnCrowdControl or 3) or 0
    local x, rowY, rowHeight = 0, ATD_AURA_GAP+(preview.btpTopGap or 0), 0
    for _, entry in ipairs(preview.btpIcons) do
        local placement = useSideCC and entry.kind == "ownCC" and "left" or "top"
        local shown=settings.enabled~=false
        if entry.kind=="debuff" then
            debuffCount=debuffCount+1
            shown=shown and settings.ownDebuffs~=false and debuffCount<=(settings.maxDebuffs or 0)
        elseif placement=="left" then
            sideCount=sideCount+1; shown=shown and sideCount<=sideLimit
        else
            if context=="pvp" and entry.kind=="ownCC" then shown=false
            else topCount=topCount+1; shown=shown and topCount<=(topLimit or 0) end
        end
        entry.size=entry.kind=="debuff" and (settings.iconSize or ATD_AURA_SIZE) or (settings.crowdControlSize or ATD_CC_AURA_SIZE)
        entry.frame:SetSize(entry.size,entry.size)
        entry.frame:ClearAllPoints()
        if placement == "left" then
            entry.btpLayout=nil
            entry.frame:SetPoint("RIGHT", preview.sideFrame, "RIGHT", -leftOffset, 0)
            if shown then leftOffset = leftOffset + entry.size + spacing end
        else
            if x > 0 and x + entry.size > lineWidth then
                x, rowY, rowHeight = 0, rowY + rowHeight + spacing, 0
            end
            local anchor=preview:GetParent()
            -- Retain our own requested layout. Measuring these sample Frames
            -- can be restricted when they inherit a live nameplate hierarchy.
            entry.btpLayout={anchor=anchor,x=x,y=rowY}
            entry.frame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", x, rowY)
            if shown then x = x + entry.size + spacing; rowHeight = math.max(rowHeight, entry.size) end
        end
        entry.frame:SetShown(shown)
    end
end

local function EnsureAuraPreview(decor, lineWidth, useSideCC, settings, context)
    if decor.auraPreview then
        decor.auraPreview.btpTopGap=decor.previewTopGap
        LayoutAuraPreview(decor.auraPreview, lineWidth, useSideCC,settings,context)
        return decor.auraPreview
    end
    local preview = CreateFrame("Frame", nil, decor.anchor)
    preview:SetAllPoints(decor.anchor)
    preview:SetFrameLevel(decor.anchor:GetFrameLevel() + 13)
    preview.btpIcons = {}
    preview.btpTopGap=decor.previewTopGap
    preview.sideFrame=CreateFrame("Frame",nil,preview)
    preview.sideFrame:SetSize(1,1)
    preview.sideFrame:SetPoint("RIGHT",decor.anchor,"LEFT",-ATD_AURA_GAP,0)
    for _, sample in ipairs(previewAuras) do
        local size = sample.large and ATD_CC_AURA_SIZE or ATD_AURA_SIZE
        local iconFrame = CreateFrame("Frame", nil, preview)
        if sample.kind=="ownCC" and addon.TrackLeftCCButton then addon:TrackLeftCCButton(iconFrame,preview.sideFrame,true) end
        iconFrame:SetSize(size, size)
        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(iconFrame)
        icon:SetTexture(sample.texture)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local edge = iconFrame:CreateTexture(nil, "OVERLAY")
            edge:SetColorTexture(0.12, 0.12, 0.12, 1)
            if side == "TOP" or side == "BOTTOM" then
                edge:SetPoint(side.."LEFT", iconFrame, side.."LEFT")
                edge:SetPoint(side.."RIGHT", iconFrame, side.."RIGHT")
                edge:SetHeight(1)
            else
                edge:SetPoint("TOP"..side, iconFrame, "TOP"..side)
                edge:SetPoint("BOTTOM"..side, iconFrame, "BOTTOM"..side)
                edge:SetWidth(1)
            end
        end
        local countdown = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countdown:SetPoint("CENTER")
        countdown:SetText(sample.count)
        countdown:SetTextColor(1, 1, 1, 1)
        preview.btpIcons[#preview.btpIcons + 1] = {
            frame = iconFrame,
            size = size,
            kind = sample.kind,
        }
    end
    LayoutAuraPreview(preview, lineWidth, useSideCC,settings,context)
    preview:Hide()
    decor.auraPreview = preview
    return preview
end

local function UpdateAuraPreview(decor, lineWidth, useSideCC, context, allowed)
    context=context or (useSideCC and "pvp" or "pve")
    local settings=decor.nativePreview and addon:GetNativeAuraSettings(context) or addon:GetATDAuraSettings(context)
    local show = auraPreviewActive and allowed~=false and not InCombatLockdown()
        and decor.plate == addon:GetPlate("target")
    if show then EnsureAuraPreview(decor, lineWidth, useSideCC,settings,context):Show()
    elseif decor.auraPreview then decor.auraPreview:Hide() end
    if decor.auraPreview and addon.SetLeftCCLayout then
        local side=decor.auraPreview.sideFrame
        addon:AnchorLeftAuraContainer(side,decor.plate)
        addon:SetLeftCCLayout(side,decor.plate,settings.crowdControlSize or ATD_CC_AURA_SIZE,settings.spacing or ATD_AURA_SPACING,show and useSideCC)
    end
end
function addon:UpdateNativeAuraPreview(frame,plate,context,allowed)
    local decor=frame.btpNativeAuraPreview
    if not decor and not (auraPreviewActive and allowed) then return end
    if not decor then
        local anchor=CreateFrame("Frame",nil,plate)
        anchor:SetFrameLevel(frame:GetFrameLevel()+12)
        decor={anchor=anchor,plate=plate,nativePreview=true}; frame.btpNativeAuraPreview=decor
    end
    if decor.plate~=plate then decor.anchor:SetParent(plate); decor.plate=plate end
    local geometry=self:GetNameplatePreviewGeometry()
    decor.anchor:SetSize(geometry.width,geometry.height)
    decor.anchor:ClearAllPoints(); decor.anchor:SetPoint("CENTER",frame.healthBar or frame,"CENTER")
    decor.previewTopGap=self.GetNameplateStyleFamily and Enum and Enum.NamePlateStyle
        and self:GetNameplateStyleFamily()==Enum.NamePlateStyle.Thin and self:GetMobNameFontSize()+4 or 0
    local settings=self:GetNativeAuraSettings(context)
    local side=context=="pvp" or settings.ownCrowdControl==true
    UpdateAuraPreview(decor,geometry.width,side,context,allowed)
end

-- Midnight 12.1 sanctioned aura-display path. AuraContainer keeps secret aura
-- data inside Blizzard code; we never enumerate/read AuraData ourselves.
if C_AddOns and C_AddOns.LoadAddOn then
    pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
end

-- Shared ATD border renderer: original and configurable borders keep the same
-- dark inset, pixel-sized outer stroke, and restrained glow.
function addon:CreateATDTargetBorder(bar)
    -- A parent's OVERLAY textures still sit below its child StatusBar. Give
    -- the selected outline its own frame above the bar, with four crisp edges.
    local targetBorder = CreateFrame("Frame", nil, bar)
    targetBorder:SetIgnoreParentScale(true)
    targetBorder:SetAllPoints(bar)
    targetBorder:SetFrameLevel(bar:GetFrameLevel() + 2)
    targetBorder:EnableMouse(false)
    -- Reference: health fill, dark inset, then a distinct white outer stroke.
    -- These strips stay outside the fill and do not tint the text/health color.
    local stroke = 1
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        stroke = PixelUtil.GetNearestPixelSize(1, targetBorder:GetEffectiveScale(), 1)
    end
    local outer = 2 * stroke
    targetBorder.edges, targetBorder.insets, targetBorder.glows = {}, {}, {}
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local inset = targetBorder:CreateTexture(nil, "BACKGROUND")
        targetBorder.insets[#targetBorder.insets+1] = inset
        inset:SetColorTexture(0.06, 0.06, 0.06, 1)
        SmoothBorderTexture(inset)
        local edge = targetBorder:CreateTexture(nil, "OVERLAY")
        targetBorder.edges[#targetBorder.edges+1] = edge
        edge:SetColorTexture(1, 1, 1, 1)
        SmoothBorderTexture(edge)
        if side == "TOP" or side == "BOTTOM" then
            local y = side == "TOP" and outer or -outer
            inset:SetPoint(side.."LEFT", bar, side.."LEFT", -outer, y)
            inset:SetPoint(side.."RIGHT", bar, side.."RIGHT", outer, y)
            inset:SetHeight(outer)
            edge:SetPoint(side.."LEFT", bar, side.."LEFT", -outer, y)
            edge:SetPoint(side.."RIGHT", bar, side.."RIGHT", outer, y)
            edge:SetHeight(stroke)
        else
            local x = side == "LEFT" and -outer or outer
            inset:SetPoint("TOP"..side, bar, "TOP"..side, x, outer)
            inset:SetPoint("BOTTOM"..side, bar, "BOTTOM"..side, x, -outer)
            inset:SetWidth(outer)
            edge:SetPoint("TOP"..side, bar, "TOP"..side, x, outer)
            edge:SetPoint("BOTTOM"..side, bar, "BOTTOM"..side, x, -outer)
            edge:SetWidth(stroke)
        end
    end
    -- Original, power-of-two alpha texture: glow peaks at the horizontal
    -- midpoint and fades towards the ends. The bar interior stays untouched.
    for _, side in ipairs({"TOP", "BOTTOM"}) do
        local glow = targetBorder:CreateTexture(nil, "ARTWORK")
        targetBorder.glows[#targetBorder.glows+1] = glow
        glow:SetTexture("Interface\\AddOns\\BlizzThreatPlates-Forever\\media\\ATDTargetGlowFeather.tga")
        -- Keep the oval halo subordinate to the crisp white outline. With
        -- additive rendering, attenuate RGB so scenery remains visible.
        glow:SetVertexColor(0.75, 0.75, 0.75, 1)
        -- Each half of the mask fades OUTWARD from the white stroke. Keeping
        -- it outside the outline preserves the dark inset instead of washing
        -- it out with a glow centered over the health bar's edge.
        local from = side == "TOP" and "BOTTOM" or "TOP"
        local y = side == "TOP" and outer or -outer
        glow:SetPoint(from.."LEFT", bar, side.."LEFT", -outer, y)
        glow:SetPoint(from.."RIGHT", bar, side.."RIGHT", outer, y)
        if side == "TOP" then glow:SetTexCoord(0, 1, 0, 1)
        else glow:SetTexCoord(0, 1, 1, 0) end
        glow:SetHeight(6)
        -- Like Plater's rendering method: black contributes nothing and the
        -- RGB intensity carries the falloff. This is original generated art,
        -- not the previous all-white RGB / alpha-only mask.
        glow:SetBlendMode("ADD")
        SmoothBorderTexture(glow)
    end
    targetBorder:Hide()
    targetBorder.stroke, targetBorder.outer = stroke, outer
    function targetBorder:PaintColor(r,g,b)
        for _,edge in ipairs(self.edges) do edge:SetColorTexture(r,g,b,1) end
        for _,glow in ipairs(self.glows) do glow:SetVertexColor(r*0.75,g*0.75,b*0.75,1) end
        self:Show()
    end
    return targetBorder, outer
end

local function GetDecor(frame)
    if not frame or frame:IsForbidden() then return nil end
    -- Store addon state on the addon-owned anchor rather than Blizzard healthBar.
    local decor = frame.btpATDOverlay
    if decor then return decor end

    local plate = frame:GetParent()
    if not plate then return nil end
    -- Parent our replacement directly to the nameplate root. This keeps it
    -- visible even when the Blizzard UnitFrame is hidden.
    local anchor = CreateFrame("Frame", nil, plate)
    anchor:SetSize(ATD_WIDTH, ATD_HEIGHT)
    -- Anchor to the native health bar itself: this is the actual visual position
    -- Blizzard computed for this unit. We only READ its anchor; we never mutate
    -- the secret-bearing StatusBar, its values, size, points, or text.
    AnchorOverlay(anchor, frame)
    anchor:SetFrameLevel((plate:GetFrameLevel() or 0) + 20)

    -- Match Blizzard's border-frame approach: follow the plate's bounds while
    -- keeping border thickness independent of the nameplate parent's scale.
    local blackBorder = CreateFrame("Frame", nil, anchor)
    blackBorder:SetIgnoreParentScale(true)
    blackBorder:SetAllPoints(anchor)
    blackBorder:SetFrameLevel(anchor:GetFrameLevel())
    blackBorder:EnableMouse(false)
    local shadow = blackBorder:CreateTexture(nil, "BACKGROUND", nil, -7)
    shadow:SetTexture(SOLID)
    shadow:SetVertexColor(0, 0, 0, 1)
    SmoothBorderTexture(shadow)
    shadow:SetPoint("TOPLEFT", blackBorder, "TOPLEFT", -1, 1)
    shadow:SetPoint("BOTTOMRIGHT", blackBorder, "BOTTOMRIGHT", 1, -1)

    local bar = CreateFrame("StatusBar", nil, anchor)
    bar:SetAllPoints(anchor)
    bar:SetStatusBarTexture(SOLID)
    SmoothBorderTexture(bar:GetStatusBarTexture())
    bar:SetStatusBarColor(0.15, 0.75, 0.15, 1)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture(SOLID)
    bg:SetVertexColor(0.0431372, 0.0431372, 0.0431372, 1)
    SmoothBorderTexture(bg)

    local name = bar:CreateFontString(nil, "OVERLAY")
    name:SetFont(NAME_FONT, addon:GetMobNameFontSize(), "OUTLINE")
    name:SetPoint("LEFT", bar, "LEFT", 2, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetNonSpaceWrap(false)
    name:SetTextColor(1, 1, 1, 1)

    local percent = bar:CreateFontString(nil, "OVERLAY")
    percent:SetFont(HEALTH_FONT, addon:GetHealthPercentFontSize(), "OUTLINE")
    percent:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
    percent:SetJustifyH("RIGHT")
    percent:SetTextColor(1, 1, 1, 1)
    percent:SetWordWrap(false)
    name:SetPoint("RIGHT", percent, "LEFT", -4, 0)

    local value = bar:CreateFontString(nil, "OVERLAY")
    value:SetFont(HEALTH_FONT, addon:GetHealthValueFontSize(), "OUTLINE")
    value:SetJustifyH("RIGHT")
    value:SetTextColor(1, 1, 1, 1)
    value:SetWordWrap(false)
    value:Hide()

    local targetBorder, outer = addon:CreateATDTargetBorder(bar)

    -- Secure ATD aura display. Unlike TEST46, this does NOT call UnitAura or
    -- C_UnitAuras. Blizzard's AuraContainer owns selection/update of secret
    -- auras and only hands us each AuraButton during its legal init window.
    local auraContainer, ccAuraContainer
    local auraButtons = {debuffs = {}, topCC = {}, sideCC = {}}
    if CreateFrame and C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        local function CreateAuraInitializer(size, storage, sideContainer)
            return function(button)
                button:SetSize(size, size)
                storage[#storage + 1] = button
                if sideContainer and addon.TrackLeftCCButton then addon:TrackLeftCCButton(button,sideContainer) end
                local icon = button:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints(button)
                icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                button:SetIcon(icon)

                local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
                cd:SetAllPoints(button)
                cd:SetDrawEdge(false)
                cd:SetDrawSwipe(true)
                cd:SetReverse(true)
                button:SetDurationCooldown(cd)

                -- Thin inset edges instead of the bulky beveled debuff atlas.
                for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
                    local border = button:CreateTexture(nil, "OVERLAY")
                    border:SetColorTexture(0.12, 0.12, 0.12, 1)
                    if side == "TOP" or side == "BOTTOM" then
                        border:SetPoint(side.."LEFT", button, side.."LEFT", 0, 0)
                        border:SetPoint(side.."RIGHT", button, side.."RIGHT", 0, 0)
                        border:SetHeight(1)
                    else
                        border:SetPoint("TOP"..side, button, "TOP"..side, 0, 0)
                        border:SetPoint("BOTTOM"..side, button, "BOTTOM"..side, 0, 0)
                        border:SetWidth(1)
                    end
                end
            end
        end

        local function CreateAuraContainer(point, relativePoint, x, y, flowAnchor, horizontalDirection, maximumLineSize)
            local ok, container = pcall(CreateFrame, "AuraContainer", nil, anchor, "CustomAuraContainerTemplate")
            if not ok or not container then return nil end
            container:SetSize(1, 1)
            container:SetPoint(point, anchor, relativePoint, x, y)
            container:SetFrameLevel(anchor:GetFrameLevel() + 12)
            if container.SetFlowLayoutAnchorPoint then container:SetFlowLayoutAnchorPoint(flowAnchor) end
            if container.SetFlowLayoutGrowthDirection then container:SetFlowLayoutGrowthDirection(horizontalDirection, 1) end
            if container.SetFlowLayoutMaximumLineSize then container:SetFlowLayoutMaximumLineSize(maximumLineSize) end
            return container
        end

        -- Blizzard classifies auras inside two secure containers. PvE keeps
        -- all CC above by default; its optional personal-CC split excludes
        -- PLAYER from the top group and enables the same left-side container.
        local topContainer = CreateAuraContainer("BOTTOMLEFT", "TOPLEFT", 0, ATD_AURA_GAP,
            "BOTTOMLEFT", 1, ATD_WIDTH)
        local sideLineSize = (ATD_MAX_CC_AURAS * ATD_CC_AURA_SIZE)
            + ((ATD_MAX_CC_AURAS - 1) * ATD_AURA_SPACING)
        local sideContainer = CreateAuraContainer("RIGHT", "LEFT", -ATD_AURA_GAP, 0,
            "RIGHT", -1, sideLineSize)
        if topContainer and sideContainer then
            local okCC = pcall(sideContainer.AddAuraGroup, sideContainer, "ATDOwnCrowdControl",
                "HARMFUL|CROWD_CONTROL|PLAYER", {
                maxFrameCount = ATD_MAX_CC_AURAS,
                initializeFrame = CreateAuraInitializer(ATD_CC_AURA_SIZE, auraButtons.sideCC, sideContainer),
                layout = { elementSpacing = ATD_AURA_SPACING, lineSpacing = ATD_AURA_SPACING },
            })
            local okTopCC = pcall(topContainer.AddAuraGroup, topContainer, "ATDTopCrowdControl",
                "HARMFUL|CROWD_CONTROL", {
                maxFrameCount = ATD_MAX_EXTERNAL_CC_AURAS,
                initializeFrame = CreateAuraInitializer(ATD_CC_AURA_SIZE, auraButtons.topCC),
                layout = { elementSpacing = ATD_AURA_SPACING, lineSpacing = ATD_AURA_SPACING },
            })
            local okDebuffs = pcall(topContainer.AddAuraGroup, topContainer, "ATDOwnDebuffs",
                "HARMFUL|PLAYER|!CROWD_CONTROL", {
                maxFrameCount = ATD_MAX_AURAS,
                initializeFrame = CreateAuraInitializer(ATD_AURA_SIZE, auraButtons.debuffs),
                layout = { elementSpacing = ATD_AURA_SPACING, lineSpacing = ATD_AURA_SPACING },
            })
            if okCC and okTopCC and okDebuffs then
                auraContainer = topContainer
                ccAuraContainer = sideContainer
            else
                topContainer:SetEnabled(false)
                topContainer:Hide()
                sideContainer:SetEnabled(false)
                sideContainer:Hide()
            end
        elseif topContainer then
            topContainer:SetEnabled(false)
            topContainer:Hide()
        elseif sideContainer then
            sideContainer:SetEnabled(false)
            sideContainer:Hide()
        end
    end

    decor = {anchor = anchor, bar = bar, background = bg, name = name, percent = percent, value = value, plate = plate, targetBorder = targetBorder, blackBorder = blackBorder, auraContainer = auraContainer, ccAuraContainer = ccAuraContainer, auraButtons = auraButtons, topCCFilter = auraContainer and "HARMFUL|CROWD_CONTROL" or nil, outlineOutset = outer}
    anchor.btpATDDecor = decor
    frame.btpATDOverlay = decor
    return decor
end

-- ATD-only anchor for the existing BTP Target-of-Target and threat-differential
-- modules. Other styles continue to use Blizzard's native health bar.
function addon:GetATDHealthBar(plate)
    if not addon:IsATDStyle() or not plate then return nil end
    local frame = plate.UnitFrame
    local decor = frame and frame.btpATDOverlay
    return decor and decor.bar or nil
end

local function GetNativeLevelCandidates(frame)
    -- Blizzard has moved the level badge between containers across nameplate
    -- layouts/builds. Keep this deliberately visual-only: we never read unit
    -- level/health values, we only suppress known level presentation widgets.
    local bar = frame and frame.healthBar
    local container = frame and frame.HealthBarsContainer
    local candidates = {
        -- Current Blizzard NamePlates.xml: the numbered level badge is PlayerLevelDiffFrame.
        frame and frame.PlayerLevelDiffFrame,
        frame and frame.LevelFrame, frame and frame.levelFrame,
        frame and frame.LevelText, frame and frame.levelText,
        frame and frame.Level, frame and frame.level,
        frame and frame.ClassificationFrame, frame and frame.classificationFrame,
        bar and bar.LevelFrame, bar and bar.levelFrame,
        bar and bar.LevelText, bar and bar.levelText,
        bar and bar.Level, bar and bar.level,
        bar and bar.ClassificationFrame, bar and bar.classificationFrame,
        container and container.LevelFrame, container and container.levelFrame,
        container and container.LevelText, container and container.levelText,
        container and container.Level, container and container.level,
        container and container.ClassificationFrame, container and container.classificationFrame,
    }
    return candidates
end

local function SuppressLevelWidget(widget)
    if type(widget) ~= "table" and type(widget) ~= "userdata" then return end
    if not widget or not widget.SetAlpha then return end
    if widget.btpATDOriginalAlpha == nil and widget.GetAlpha then
        widget.btpATDOriginalAlpha = widget:GetAlpha()
    end
    widget:SetAlpha(0)
    -- Blizzard may refresh the badge after our nameplate update. Hook only the
    -- visual Show path and re-apply alpha while ATD is selected; do not hide
    -- the owning UnitFrame or unregister any aura events.
    if not widget.btpATDLevelShowHooked and hooksecurefunc and widget.Show then
        widget.btpATDLevelShowHooked = true
        local function KeepSuppressed(self)
            if addon:IsATDStyle() or (self.btpNativeLevelWidget
                and not addon:GetCompatibilityMode() and not addon:GetMobLevelEnabled()) then
                self:SetAlpha(0)
            end
        end
        hooksecurefunc(widget, "Show", KeepSuppressed)
        if widget.SetShown then hooksecurefunc(widget, "SetShown", KeepSuppressed) end
    end
end

local function ApplyNativeLevelVisibility(frame)
    if not frame or frame:IsForbidden() or addon:IsATDStyle() then return end
    local unit = frame.unit or frame.displayedUnit
    if (issecretvalue and issecretvalue(unit)) or type(unit) ~= "string"
        or not unit:match("^nameplate%d+$") then return end
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or plate:IsForbidden() or plate.UnitFrame ~= frame then return end
    -- This is the numbered bubble in the current native layout. Leave the
    -- separate classification and PvP difficulty indicators alone.
    local widget = frame.PlayerLevelDiffFrame
    if not widget or (widget.IsForbidden and widget:IsForbidden()) then return end
    widget.btpNativeLevelWidget = true
    if not addon:GetCompatibilityMode() and not addon:GetMobLevelEnabled() then
        -- Share ATD's original-alpha cache so switching styles cannot capture
        -- our hidden alpha as the value to restore later.
        SuppressLevelWidget(widget)
    elseif widget.btpATDOriginalAlpha ~= nil then
        widget:SetAlpha(widget.btpATDOriginalAlpha)
    end
end

function addon:RefreshNativeLevelVisibility()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        if not plate:IsForbidden() then ApplyNativeLevelVisibility(plate.UnitFrame) end
    end
end

-- TEST43: do not reposition Blizzard's restricted aura frames at all.
-- ATD now leaves Blizzard's native aura geometry untouched so switching back
-- to Default/Large cannot inherit an ATD-specific DebuffListFrame anchor.

local function SetNativeAuraVisualsSuppressed(frame, suppressed)
    -- Visual alpha only. Blizzard controls this frame's visibility with
    -- SetShown; its local alpha is normally 1. Always restore that known native
    -- value instead of replaying a possibly transitional 0 captured when ATD
    -- was enabled. Never change points, size, unit, filters, or aura data.
    local auras = frame and frame.AurasFrame
    if not auras or not auras.SetAlpha then return end
    if suppressed then
        auras:SetAlpha(0)
    else
        auras:SetAlpha(1)
    end
end

local function SuppressNativeVisuals(frame)
    if not frame or frame:IsForbidden() then return end
    -- TEST37: keep the Blizzard UnitFrame itself shown. Native nameplate auras
    -- depend on that frame being alive. Only make the native health/level
    -- presentation transparent. SetAlpha does not read or transform health.
    local nativeBar = frame.healthBar
    if nativeBar and nativeBar.SetAlpha then
        if nativeBar.btpATDOriginalAlpha == nil then
            nativeBar.btpATDOriginalAlpha = nativeBar:GetAlpha()
        end
        nativeBar:SetAlpha(0)
    end

    -- The native name is a separate FontString owned by Blizzard's health bar;
    -- healthBar:SetAlpha(0) does not reliably suppress it. Hide only its visual
    -- alpha while ATD is active; leave the UnitFrame and aura machinery alive.
    local nativeName = nativeBar and nativeBar.unitNameFontString
    if nativeName and nativeName.SetAlpha then
        if nativeName.btpATDOriginalAlpha == nil then
            nativeName.btpATDOriginalAlpha = nativeName:GetAlpha()
        end
        nativeName:SetAlpha(0)
    end

    -- Current Blizzard NamePlates.xml names the numbered level badge
    -- PlayerLevelDiffFrame. Suppress that exact visual first, then keep the
    -- compatibility candidates for older layouts/builds.
    SuppressLevelWidget(frame.PlayerLevelDiffFrame)
    for _, levelWidget in pairs(GetNativeLevelCandidates(frame)) do
        SuppressLevelWidget(levelWidget)
    end
end

local function RestoreNativeVisuals(frame)
    if not frame or frame:IsForbidden() then return end
    if addon.RestoreATDCastbar then addon:RestoreATDCastbar(frame) end
    local nativeBar = frame.healthBar
    if nativeBar and nativeBar.SetAlpha and nativeBar.btpATDOriginalAlpha ~= nil then
        nativeBar:SetAlpha(nativeBar.btpATDOriginalAlpha)
    end
    local nativeName = nativeBar and nativeBar.unitNameFontString
    if nativeName and nativeName.SetAlpha and nativeName.btpATDOriginalAlpha ~= nil then
        nativeName:SetAlpha(nativeName.btpATDOriginalAlpha)
    end
    for _, levelWidget in pairs(GetNativeLevelCandidates(frame)) do
        if (type(levelWidget) == "table" or type(levelWidget) == "userdata")
            and levelWidget.SetAlpha and levelWidget.btpATDOriginalAlpha ~= nil then
            levelWidget:SetAlpha(levelWidget.btpATDOriginalAlpha)
        end
    end
    SetNativeAuraVisualsSuppressed(frame, false)
    local decor = frame.btpATDOverlay
    if decor and decor.auraContainer then
        decor.auraContainer:SetEnabled(false)
        decor.auraContainer:Hide()
    end
    if decor and decor.ccAuraContainer then
        decor.ccAuraContainer:SetEnabled(false)
        decor.ccAuraContainer:Hide()
        if addon.ClearLeftCCLayout then addon:ClearLeftCCLayout(decor.ccAuraContainer) end
    end
    if decor and decor.auraPreview and addon.ClearLeftCCLayout then addon:ClearLeftCCLayout(decor.auraPreview.sideFrame) end
end

local function UseSideCCLayout(frame, unit)
    -- Prefer the unit's public player classification. If Blizzard restricts
    -- that value, use its already-classified frame state, then the PvP instance
    -- type as a final conservative fallback.
    local isPlayer = UnitIsPlayer and UnitIsPlayer(unit)
    if issecretvalue and issecretvalue(isPlayer) then isPlayer = nil end
    if isPlayer == nil then
        isPlayer = frame and frame.isPlayer
        if issecretvalue and issecretvalue(isPlayer) then isPlayer = nil end
    end
    if isPlayer ~= nil then return isPlayer == true end
    local _, instanceType = IsInInstance()
    return instanceType == "pvp" or instanceType == "arena"
end

local function ConfigureTopCCFilter(decor, useSideCC)
    local desired = useSideCC and "HARMFUL|CROWD_CONTROL|!PLAYER"
        or "HARMFUL|CROWD_CONTROL"
    if decor.topCCFilter == desired then return useSideCC end
    local setter = decor.auraContainer and decor.auraContainer.SetAuraGroupFilterString
    local ok = setter and pcall(setter, decor.auraContainer, "ATDTopCrowdControl", desired)
    if ok then
        decor.topCCFilter = desired
        return useSideCC
    end
    -- Preserve the currently working split if the client rejects a runtime
    -- filter change: this avoids either duplicating or dropping the player's CC.
    return decor.topCCFilter == "HARMFUL|CROWD_CONTROL|!PLAYER"
end

local function ResizeAuraButtons(buttons, size)
    for _, button in ipairs(buttons or {}) do
        -- Like native workaround icons, these engine-owned children can deny
        -- access after initialization even while IsForbidden remains false.
        local allowed
        if button.CanBeAccessedInContext then
            allowed = button:CanBeAccessedInContext()
        else
            local forbidden = button:IsForbidden()
            allowed = not (issecretvalue and issecretvalue(forbidden)) and not forbidden
        end
        if not (issecretvalue and issecretvalue(allowed)) and allowed == true then
            button:SetSize(size, size)
        end
    end
end

local function ConfigureAuraGroup(container, groupKey, count, spacing)
    if not container then return end
    if container.SetAuraGroupMaxFrameCount then
        pcall(container.SetAuraGroupMaxFrameCount, container, groupKey, count)
    end
    if container.SetAuraGroupLayout then
        pcall(container.SetAuraGroupLayout, container, groupKey, {
            elementSpacing = spacing, lineSpacing = spacing,
        })
    end
end

local function ApplyAuraSettings(decor, useSideCC, scale, context)
    context = context or (useSideCC and "pvp" or "pve")
    local settings = addon:GetATDAuraSettings(context)
    local enabled = settings.enabled ~= false
    local debuffCount = enabled and settings.ownDebuffs ~= false and settings.maxDebuffs or 0
    local topCCCount, sideCCCount
    if context=="pvp" then
        topCCCount = enabled and settings.otherCrowdControl ~= false and settings.maxOtherCrowdControl or 0
        sideCCCount = enabled and settings.ownCrowdControl ~= false and settings.maxOwnCrowdControl or 0
    else
        topCCCount = enabled and settings.crowdControl ~= false and settings.maxCrowdControl or 0
        sideCCCount = enabled and useSideCC and (settings.maxOwnCrowdControl or 3) or 0
    end

    local spacing = settings.spacing or ATD_AURA_SPACING
    local iconSize = settings.iconSize or ATD_AURA_SIZE
    local ccSize = settings.crowdControlSize or ATD_CC_AURA_SIZE
    local signature = table.concat({context, tostring(enabled), debuffCount, topCCCount,
        sideCCCount, spacing, iconSize, ccSize, scale}, ":")
    if decor.auraSettingsSignature == signature then
        return decor.showTopAuras, decor.showSideAuras
    end
    decor.auraSettingsSignature = signature
    ConfigureAuraGroup(decor.auraContainer, "ATDOwnDebuffs", debuffCount, spacing)
    ConfigureAuraGroup(decor.auraContainer, "ATDTopCrowdControl", topCCCount, spacing)
    ConfigureAuraGroup(decor.ccAuraContainer, "ATDOwnCrowdControl", sideCCCount, spacing)
    -- Increasing a group's maximum can allocate additional buttons. Resize
    -- after updating the group so newly initialized buttons receive the saved
    -- size during the same refresh.
    ResizeAuraButtons(decor.auraButtons and decor.auraButtons.debuffs, iconSize)
    ResizeAuraButtons(decor.auraButtons and decor.auraButtons.topCC, ccSize)
    ResizeAuraButtons(decor.auraButtons and decor.auraButtons.sideCC, ccSize)

    if decor.auraContainer and decor.auraContainer.SetFlowLayoutMaximumLineSize then
        decor.auraContainer:SetFlowLayoutMaximumLineSize(ATD_WIDTH * scale)
    end
    if decor.ccAuraContainer and decor.ccAuraContainer.SetFlowLayoutMaximumLineSize then
        local count = math.max(1, sideCCCount)
        decor.ccAuraContainer:SetFlowLayoutMaximumLineSize((count * ccSize) + ((count - 1) * spacing))
    end
    decor.showTopAuras = enabled and (debuffCount > 0 or topCCCount > 0)
    decor.showSideAuras = enabled and sideCCCount > 0
    return decor.showTopAuras, decor.showSideAuras
end

local function UpdateHealthTextLayout(decor)
    local percentOn, valueOn = addon:GetNameplateHealthInfoFlags()
    decor.showHealthPercent, decor.showHealthValue = percentOn, valueOn
    decor.percent:SetFont(HEALTH_FONT, addon:GetHealthPercentFontSize(), "OUTLINE")
    decor.value:SetFont(HEALTH_FONT, addon:GetHealthValueFontSize(), "OUTLINE")
    -- Reserve public font-size-based space; never measure secret health text.
    decor.percent:SetWidth(addon:GetHealthPercentFontSize() * 3.5 + 2)
    decor.value:SetWidth(addon:GetHealthValueFontSize() * 5.5 + 2)
    decor.percent:SetShown(percentOn)
    decor.value:SetShown(valueOn)
    decor.percent:ClearAllPoints()
    decor.value:ClearAllPoints()
    decor.name:ClearAllPoints()
    decor.name:SetJustifyH("LEFT")
    if addon.GetNameplateNameEnabled then decor.name:SetShown(addon:GetNameplateNameEnabled()) end
    decor.percent:SetPoint("RIGHT", decor.bar, "RIGHT", -2, 0)
    if percentOn then decor.value:SetPoint("RIGHT", decor.percent, "LEFT", -4, 0)
    else decor.value:SetPoint("RIGHT", decor.bar, "RIGHT", -2, 0) end
    decor.name:SetPoint("LEFT", decor.bar, "LEFT", 2, 0)
    if valueOn then decor.name:SetPoint("RIGHT", decor.value, "LEFT", -4, 0)
    elseif percentOn then decor.name:SetPoint("RIGHT", decor.percent, "LEFT", -4, 0)
    else decor.name:SetPoint("RIGHT", decor.bar, "RIGHT", -2, 0) end
    if addon.ApplyNameplateTextAlignment then
        addon:ApplyNameplateTextAlignment(decor.bar,decor.percent,decor.value,percentOn,valueOn,decor.name)
    end
end

local function PaintHealthValue(label, current)
    if AbbreviateNumbers then
        local ok, abbreviated = pcall(AbbreviateNumbers, current)
        if ok and pcall(label.SetFormattedText, label, "%s", abbreviated) then return end
    end
    -- Older clients may not support secret-safe abbreviation. Pass the value
    -- directly to the native FontString sink, without Lua arithmetic/formatting.
    label:SetFormattedText("%.0f", current)
end

local function UpdateHealth(decor, unit)
    -- Calculator values may be secret; forward them directly to UI sinks.
    if not CreateUnitHealPredictionCalculator or not UnitGetDetailedHealPrediction then return end
    local calc = decor.calculator
    if not calc then
        calc = CreateUnitHealPredictionCalculator()
        decor.calculator = calc
    end
    UnitGetDetailedHealPrediction(unit, nil, calc)
    if calc.SetMaximumHealthMode then calc:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.Default) end
    local current, maximum = calc:GetCurrentHealth(), calc:GetMaximumHealth()
    decor.bar:SetMinMaxValues(0, maximum, Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or nil)
    decor.bar:SetValue(current, Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or nil)
    if decor.showHealthValue then PaintHealthValue(decor.value, current) end
    if decor.showHealthPercent and calc.EvaluateCurrentHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        decor.percent:SetFormattedText("%d%%", calc:EvaluateCurrentHealthPercent(CurveConstants.ScaleTo100))
    end
end

local function Update(frame)
    if not addon:IsATDStyle() then return end
    if not frame or frame:IsForbidden() then return end
    local unit = frame.unit or frame.displayedUnit
    if issecretvalue and issecretvalue(unit) then return end
    if not unit or not unit:match("^nameplate%d+$") then return end

    local decor = GetDecor(frame)
    if not decor then return end
    if addon.PrepareDevNameplateStyle then addon:PrepareDevNameplateStyle(decor) end
    if addon.PrepareJundiesStyle then addon:PrepareJundiesStyle(decor) end
    tracked[unit] = frame
    -- UnitFrames can be pooled and attached to a different nameplate root.
    local plate = frame:GetParent()
    if decor.plate ~= plate then
        decor.plate = plate
        decor.anchor:SetParent(plate)
        decor.anchor:SetFrameLevel(plate:GetFrameLevel() + 20)
    end
    -- Existing Nameplate Options drive the ATD-owned widgets too. Size 2 is
    -- the saved ATD 130x15 baseline; adjacent slider steps scale by 10%.
    local sizeStep = addon:GetNameplateSize()
    local scale = 1 + ((sizeStep - 2) * 0.10)
    decor.anchor:SetSize(ATD_WIDTH * scale * addon:GetNameplateWidthPercent() / 100,
        ATD_HEIGHT * scale * addon:GetNameplateHeightPercent() / 100)
    if addon.IsJundiesStyle and addon:IsJundiesStyle() then
        local layout=addon:GetJundiesStyleLayout()
        decor.anchor:SetSize(layout.width,layout.height); scale=layout.width/ATD_WIDTH
    end
    local creatorStyle=addon.GetDevNameplateStyle and addon:GetDevNameplateStyle(decor)
    if creatorStyle then
        scale=creatorStyle.bar.width*creatorStyle.bar.scale/ATD_WIDTH
        decor.anchor:SetSize(creatorStyle.bar.width*creatorStyle.bar.scale,creatorStyle.bar.height*creatorStyle.bar.scale)
    end
    -- Size changes must never change the plate's world-space position. Lock the
    -- ATD center to Blizzard's actual native health-bar center; only our addon-
    -- owned width/height changes. Do not ClearAllPoints/SetPoint on nativeBar.
    AnchorOverlay(decor.anchor, frame)
    decor.name:SetFont(NAME_FONT, addon:GetMobNameFontSize(), "OUTLINE")
    UpdateHealthTextLayout(decor)
    decor.anchor:Show()
    -- Selected-target highlight is cosmetic and entirely addon-owned.
    local isTarget = UnitIsUnit and UnitIsUnit(unit, "target")
    if issecretvalue and issecretvalue(isTarget) then isTarget = false end
    if decor.targetBorder then
        if isTarget then decor.targetBorder:Show() else decor.targetBorder:Hide() end
    end
    if addon.UpdateATDCastbar then addon:UpdateATDCastbar(frame, decor, unit) end

    SuppressNativeVisuals(frame)
    if decor.auraContainer and decor.ccAuraContainer then
        local context=UseSideCCLayout(frame,unit) and "pvp" or "pve"
        local settings=addon:GetATDAuraSettings(context)
        local useSideCC = ConfigureTopCCFilter(decor, context=="pvp" or settings.ownCrowdControl==true)
        local showTopAuras, showSideAuras = ApplyAuraSettings(decor, useSideCC, scale,context)
        if addon.AnchorLeftAuraContainer then addon:AnchorLeftAuraContainer(decor.ccAuraContainer,plate) end
        -- Groups are declared before SetUnit so both containers register their
        -- own UNIT_AURA tracking correctly. No addon aura inspection is needed.
        if decor.auraContainer:GetUnit() ~= unit then
            decor.auraContainer:SetUnit(unit)
        end
        decor.auraContainer:SetEnabled(showTopAuras)
        decor.auraContainer:SetShown(showTopAuras)
        if useSideCC and showSideAuras then
            if decor.ccAuraContainer:GetUnit() ~= unit then
                decor.ccAuraContainer:SetUnit(unit)
            end
            decor.ccAuraContainer:SetEnabled(true)
            decor.ccAuraContainer:Show()
        else
            decor.ccAuraContainer:SetEnabled(false)
            decor.ccAuraContainer:Hide()
        end
        if addon.SetLeftCCLayout then addon:SetLeftCCLayout(decor.ccAuraContainer,plate,settings.crowdControlSize or ATD_CC_AURA_SIZE,
            settings.spacing or ATD_AURA_SPACING,useSideCC and showSideAuras) end
        SetNativeAuraVisualsSuppressed(frame, true)
        UpdateAuraPreview(decor, ATD_WIDTH * scale, useSideCC,context)
    else
        SetNativeAuraVisualsSuppressed(frame, false)
        UpdateAuraPreview(decor, ATD_WIDTH * scale, false)
    end
    if addon.RefreshNameplateAttachments then addon:RefreshNameplateAttachments(plate,unit) end

    -- UnitName is not a secret health value; use our own label so we do not
    -- need to reposition Blizzard's native name FontString.
    local unitName = UnitName(unit)
    if (issecretvalue and issecretvalue(unitName)) or unitName then decor.name:SetText(unitName) end

    -- Preserve BTP's threat language on the addon-owned ATD bar only. This
    -- does not touch the native StatusBar and does not alter any other style.
    -- Tapped/tag-denied mobs should retain Blizzard's familiar gray identity
    -- instead of being recolored by our threat palette. Keep this as the
    -- highest-priority color rule for non-player units.
    local tapped = UnitIsTapDenied and UnitIsTapDenied(unit)
    if issecretvalue and issecretvalue(tapped) then tapped = false end

    -- Pet threat status can be nil here even while the mob is visibly attacking
    -- our pet. The mob's target token directly captures that case.
    local targetsPet = false
    if UnitExists and UnitIsUnit then
        local targetToken = unit .. "target"
        local exists = UnitExists(targetToken)
        if not (issecretvalue and issecretvalue(exists)) and exists then
            local ok, same = pcall(UnitIsUnit, targetToken, "pet")
            if ok and not (issecretvalue and issecretvalue(same)) then targetsPet = same and true or false end
        end
    end

    local status = UnitThreatSituation and UnitThreatSituation("player", unit)
    if not addon:IsThreatNPC(unit) then status = nil; targetsPet = false end
    local pvpR, pvpG, pvpB, pvpColored = addon:GetPvPColor(unit)
    local friendlyR, friendlyG, friendlyB, friendlyColored = addon:GetFriendlyPlayerColor(unit, true)
    if pvpColored then
        decor.bar:SetStatusBarColor(pvpR, pvpG, pvpB, 1)
    elseif friendlyColored then
        decor.bar:SetStatusBarColor(friendlyR, friendlyG, friendlyB, 1)
    elseif tapped then
        decor.bar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
    elseif addon:ShouldColorQuestMob(unit) then
        decor.bar:SetStatusBarColor(addon:GetQuestColor())
    elseif not (issecretvalue and issecretvalue(status)) then
        local kind
        if status == 3 then kind = "secure"
        elseif status == 1 or status == 2 then kind = "warning"
        elseif status == 0 then
            local fighting = UnitAffectingCombat(unit)
            if not (issecretvalue and issecretvalue(fighting)) and fighting then kind = "lost" end
        end
        if status ~= 3 and targetsPet then kind = "lost" end
        if kind and addon.GetThreatColor then
            local r, g, b = addon:GetThreatColor(kind)
            decor.bar:SetStatusBarColor(r, g, b, 1)
        else
            -- Player colors are handled above. NPCs retain reaction coloring.
            local colored = false
            if not colored and UnitReaction then
                local reaction = UnitReaction(unit, "player")
                if not (issecretvalue and issecretvalue(reaction)) and reaction then
                    if reaction <= 3 then decor.bar:SetStatusBarColor(1.0, 0.12, 0.12, 1)
                    elseif reaction == 4 then decor.bar:SetStatusBarColor(0.95, 0.82, 0.24, 1)
                    else decor.bar:SetStatusBarColor(0.15, 0.75, 0.15, 1) end
                    colored = true
                end
            end
            if not colored then decor.bar:SetStatusBarColor(0.95, 0.82, 0.24, 1) end
        end
    else
        -- Restricted threat cannot drive a palette. Forward the client's
        -- reaction color directly rather than retaining an old quest tint.
        decor.bar:SetStatusBarColor(UnitSelectionColor(unit))
    end

    if addon.ApplyJundiesStyle then addon:ApplyJundiesStyle(decor,isTarget) end
    if addon.ApplyDevNameplateStyle then addon:ApplyDevNameplateStyle(decor) end
    if addon.ApplyLiquidThreat then addon:ApplyLiquidThreat(decor,unit) end
    UpdateHealth(decor, unit)
end

function addon:IsATDAuraPreviewActive()
    return auraPreviewActive
end

function addon:SetATDAuraPreview(enabled)
    enabled = enabled and true or false
    if enabled then
        if not self:IsATDStyle() and not (self.GetNativeCCWorkaround and self:GetNativeCCWorkaround()) then
            print("BlizzThreatPlates: select a custom style or enable CC Display Workaround before previewing auras.")
            return false
        end
        if self:GetCompatibilityMode() then return false end
        if InCombatLockdown() then
            print("BlizzThreatPlates: aura preview is available outside combat.")
            return false
        end
        if not self:GetPlate("target") then
            print("BlizzThreatPlates: target a unit with a visible nameplate first.")
            return false
        end
    end
    auraPreviewActive = enabled
    auraPreviewGeneration = auraPreviewGeneration + 1
    local generation = auraPreviewGeneration
    self:RefreshATDStyle()
    if self.RefreshNativeCCFallbacks then self:RefreshNativeCCFallbacks() end
    if self.RefreshATDAuraPreviewControl then self:RefreshATDAuraPreviewControl() end
    if self.RefreshEnemyDebuffPreviewControls then self:RefreshEnemyDebuffPreviewControls() end
    if enabled then
        print("BlizzThreatPlates: showing the aura preview on your target for 20 seconds.")
        C_Timer.After(20, function()
            if auraPreviewActive and auraPreviewGeneration == generation then
                addon:SetATDAuraPreview(false)
            end
        end)
    end
    return auraPreviewActive
end

local function AccessibleUnitFrame(plate)
    if not plate or plate:IsForbidden() then return end
    local frame = plate.UnitFrame
    if frame and not frame:IsForbidden() then return frame end
end

function addon:RefreshATDStyle()
    if not addon:IsATDStyle() or not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local frame = AccessibleUnitFrame(plate)
        if frame then Update(frame) end
    end
end

function addon:RestoreATDStyle()
    if auraPreviewActive then
        auraPreviewActive = false
        auraPreviewGeneration = auraPreviewGeneration + 1
        if addon.RefreshATDAuraPreviewControl then addon:RefreshATDAuraPreviewControl() end
    end
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local frame = AccessibleUnitFrame(plate)
        local decor = frame and frame.btpATDOverlay
        if decor and decor.anchor then decor.anchor:Hide() end
        if frame then RestoreNativeVisuals(frame) end
    end
end

function addon:ApplyATDStyle(frame)
    if not frame or frame:IsForbidden() then return end
    if addon:IsATDStyle() then Update(frame)
    elseif frame and frame.btpATDOverlay and frame.btpATDOverlay.anchor then
        frame.btpATDOverlay.anchor:Hide()
        RestoreNativeVisuals(frame)
    end
    if not addon:IsATDStyle() then ApplyNativeLevelVisibility(frame) end
end

-- Level refreshes can follow the health/name updates on new or recycled plates.
hooksecurefunc("CompactUnitFrame_UpdateLevel", ApplyNativeLevelVisibility)

local events = CreateFrame("Frame")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("UNIT_HEALTH")
events:RegisterEvent("UNIT_MAXHEALTH")
events:RegisterEvent("UNIT_AURA")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
for _, event in ipairs({"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_REGEN_DISABLED" then
        if auraPreviewActive then addon:SetATDAuraPreview(false) end
        return
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if (issecretvalue and issecretvalue(unit)) or type(unit) ~= "string" then return end
        local frame = tracked[unit]
        if frame and not frame:IsForbidden() then
            local assigned = frame.unit
            if not (issecretvalue and issecretvalue(assigned)) and assigned == nil then assigned = frame.displayedUnit end
            if not (issecretvalue and issecretvalue(assigned)) and (assigned == nil or assigned == unit) then
                local decor = frame.btpATDOverlay
                if decor then decor.anchor:Hide() end
                RestoreNativeVisuals(frame)
            end
        end
        tracked[unit] = nil
        return
    elseif event == "PLAYER_TARGET_CHANGED" then
        addon:RefreshATDStyle()
        return
    end
    if not addon:IsATDStyle() or (issecretvalue and issecretvalue(unit))
        or type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    local frame = AccessibleUnitFrame(plate)
    if frame then Update(frame) end
end)
