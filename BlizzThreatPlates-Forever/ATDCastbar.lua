local addon = ForeverNameplates
local SOLID = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"

local function SmoothTexture(texture)
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
end

function addon:GetATDCastbarLayout()
    local settings = self:GetATDCastbarSettings()
    local scale = 1 + (self:GetNameplateSize() - 2) * 0.10
    return {
        width = (settings.width or 130) * scale * self:GetNameplateWidthPercent() / 100,
        height = (settings.height or 13) * scale,
        offsetY = (settings.offsetY or -3) * scale,
    }
end

local function Native(frame)
    local container = frame.CastBarsContainer or frame.castBarsContainer
    return container or frame.castBar or frame.CastBar
end

local function Restore(frame)
    local decor = frame.btpATDOverlay
    local cast = decor and decor.cast
    if not cast then return end
    cast.duration = nil
    cast:Hide()
    if cast.native then
        cast.native:SetAlpha(cast.nativeAlpha)
        cast.native = nil
    end
end

function addon:RestoreATDCastbar(frame) Restore(frame) end

function addon:GetATDCastBar(plate)
    if not self:IsATDStyle() then return end
    local decor = plate and plate.UnitFrame and plate.UnitFrame.btpATDOverlay
    local cast = decor and decor.cast
    if cast and cast.native then return cast end
end

local function Create(decor)
    local cast = CreateFrame("StatusBar", nil, decor.anchor)
    cast:SetPoint("TOPLEFT", decor.bar, "BOTTOMLEFT", 0, -3)
    cast:SetSize(130, 13)
    cast:SetStatusBarTexture(SOLID)
    SmoothTexture(cast:GetStatusBarTexture())
    cast:SetStatusBarColor(0.68, 0.55, 0.06, 1)
    local bg = cast:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(cast)
    bg:SetColorTexture(0.02, 0.02, 0.02, 1)
    cast.background = bg
    SmoothTexture(bg)
    -- Keep the rim outside the fill, as in the preview. An inner overlay
    -- obscures the first column of gold and creates a visible horizontal inset.
    local border = cast:CreateTexture(nil, "BACKGROUND", nil, -1)
    border:SetColorTexture(0, 0, 0, 1)
    border:SetPoint("TOPLEFT", cast, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", cast, "BOTTOMRIGHT", 1, -1)
    SmoothTexture(border)
    cast.border = border
    cast.text = cast:CreateFontString(nil, "OVERLAY")
    cast.text:SetFont(FONT, 9, "OUTLINE")
    cast.text:SetPoint("LEFT", cast, "LEFT", 2, 0)
    cast.text:SetJustifyH("LEFT")
    cast.text:SetWordWrap(false)
    cast.text:SetNonSpaceWrap(false)
    cast.time = cast:CreateFontString(nil, "OVERLAY")
    cast.time:SetFont(FONT, 8, "OUTLINE")
    cast.time:SetPoint("RIGHT", cast, "RIGHT", -3, 0)
    cast.time:SetWidth(26)
    cast.time:SetJustifyH("RIGHT")
    cast.text:SetPoint("RIGHT", cast.time, "LEFT", -3, 0)
    -- Blizzard animates the bar. Only the displayed numeric countdown needs
    -- refreshing; secret seconds go directly into the native FontString sink.
    cast:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.1 then return end
        self.elapsed = 0
        if self.duration then
            self.time:SetFormattedText("%.1f", self.duration:GetRemainingDuration())
        end
    end)
    cast:Hide()
    decor.cast = cast
    return cast
end

local function SuppressNative(frame, cast)
    local native = Native(frame)
    if native then
        if not cast.native then cast.nativeAlpha = native:GetAlpha(); cast.native = native end
        native:SetAlpha(0)
    end
end

function addon:UpdateATDCastbar(frame, decor, unit)
    if not UnitCastingDuration or not UnitChannelDuration or not UnitCastingInfo
        or not UnitChannelInfo or not Enum.StatusBarTimerDirection then return end
    local cast = decor.cast or Create(decor)
    if not cast.SetTimerDuration or cast.unsupported then return end
    local settings = self:GetATDCastbarSettings()
    local layout = self:GetATDCastbarLayout()
    local creatorStyle = self.GetDevNameplateStyle and self:GetDevNameplateStyle(decor)
    local offsetX = 0
    if decor.targetBorder and decor.targetBorder:IsShown() then
        -- The addon-owned outline ignores parent scale. Convert its known
        -- outset into the castbar's coordinate space; never measure live bounds.
        offsetX = -(decor.outlineOutset or 0) * decor.targetBorder:GetEffectiveScale() / cast:GetEffectiveScale()
    end
    local layoutSignature = table.concat({layout.width, layout.height,
        layout.offsetY, offsetX, settings.nameSize or 9, settings.timeSize or 8,
        tostring(settings.showName ~= false), tostring(settings.showTime ~= false)}, ":")
    if cast.layoutSignature ~= layoutSignature then
        cast.layoutSignature = layoutSignature
        cast:ClearAllPoints()
        cast:SetPoint("TOPLEFT", decor.bar, "BOTTOMLEFT", offsetX, layout.offsetY)
        cast:SetSize(layout.width, layout.height)
        cast.text:SetFont(FONT, settings.nameSize or 9, "OUTLINE")
        cast.time:SetFont(FONT, settings.timeSize or 8, "OUTLINE")
        cast.text:SetShown(settings.showName ~= false)
        cast.time:SetShown(settings.showTime ~= false)
        cast.text:ClearAllPoints()
        cast.text:SetPoint("LEFT", cast, "LEFT", 2, 0)
        if settings.showTime ~= false then
            cast.text:SetPoint("RIGHT", cast.time, "LEFT", -3, 0)
        else
            cast.text:SetPoint("RIGHT", cast, "RIGHT", -3, 0)
        end
    end
    if settings.enabled == false and not (creatorStyle and creatorStyle.cast.enabled) then
        cast.duration = nil
        cast:Hide()
        SuppressNative(frame, cast)
        return
    end

    local duration = UnitCastingDuration(unit)
    local channel = false
    if issecretvalue and issecretvalue(duration) then Restore(frame); return end
    if not duration then
        duration = UnitChannelDuration(unit)
        channel = true
    end
    if issecretvalue and issecretvalue(duration) then Restore(frame); return end
    if not duration then
        -- Hide only our finished cast. Blizzard's completion flash/fade can
        -- outlive UnitCastingDuration; keep its visuals suppressed until ATD
        -- is disabled, this plate is removed, or compatibility fallback occurs.
        cast.duration = nil
        cast:Hide()
        if cast.native then cast.native:SetAlpha(0) end
        return
    end
    local direction = channel and Enum.StatusBarTimerDirection.RemainingTime
        or Enum.StatusBarTimerDirection.ElapsedTime
    -- Do not suppress Blizzard's bar unless this client accepts the duration
    -- object. This is a compatibility fallback, not a secret-value workaround.
    local ok = pcall(cast.SetTimerDuration, cast, duration, Enum.StatusBarInterpolation.Immediate, direction)
    if not ok then
        Restore(frame)
        cast.unsupported = true
        print("BlizzThreatPlates: ATD cast timer unavailable; keeping Blizzard's castbar.")
        return
    end
    cast.duration = duration
    local name, _, _, _, _, _, _, notInterruptible
    if channel then
        name, _, _, _, _, _, notInterruptible = UnitChannelInfo(unit)
    else
        name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
    end
    cast.text:SetText(name)
    cast.btpNotInterruptible = not (issecretvalue and issecretvalue(notInterruptible)) and notInterruptible == true
    if not (issecretvalue and issecretvalue(notInterruptible)) and notInterruptible then
        local color = settings.protectedColor or {0.5, 0.5, 0.5}
        cast:SetStatusBarColor(color[1], color[2], color[3], 1)
    else
        local color = settings.interruptibleColor or {0.68, 0.55, 0.06}
        cast:SetStatusBarColor(color[1], color[2], color[3], 1)
    end
    cast.time:SetFormattedText("%.1f", duration:GetRemainingDuration())
    SuppressNative(frame, cast)
    cast:Show()
end
