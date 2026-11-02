-- ForeverLFG -- Copyright (c) 2026 Forever. All rights reserved. See LICENSE.
local _, NS = ...
local atlases = {
    ANY = "groupfinder-icon-emptyslot", TANK = "groupfinder-icon-role-large-tank",
    HEALER = "groupfinder-icon-role-large-heal", DAMAGER = "groupfinder-icon-role-large-dps",
}
local border = {edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8}
local hoverAlpha = .08

-- Один вид для ручных вакансий и подбора игроков. Постоянный выбор отделён
-- от наведения и короткого отклика; обновление выдачи не повторяет анимацию.
function NS.CreateFilterRoleButton(name, parent, role, label)
    local b = CreateFrame("Button", name, parent, "BackdropTemplate")
    b:SetSize(42, 42); b:SetHitRectInsets(-3, -3, 0, -16)
    b:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = border.edgeFile,
        edgeSize = border.edgeSize, insets = {left = 3, right = 3, top = 3, bottom = 3}})
    b:SetBackdropColor(.035, .03, .022, 1)
    b.Icon = b:CreateTexture(nil, "ARTWORK")
    b.Icon:SetAtlas(atlases[role]); b.Icon:SetSize(34, 34)
    b.Label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.Label:SetPoint("TOP", b, "BOTTOM", 0, -3); b.Label:SetText(label); b.Label:SetWordWrap(false)

    b.Selected = CreateFrame("Frame", nil, b, "BackdropTemplate")
    b.Selected:SetAllPoints(b); b.Selected:SetBackdrop(border)
    b.Selected:SetBackdropBorderColor(1, .82, .12, 1); b.Selected:Hide()
    local function Glow()
        local texture = b:CreateTexture(nil, "OVERLAY")
        texture:SetTexture("Interface\\Buttons\\CheckButtonHilight"); texture:SetBlendMode("ADD")
        texture:SetVertexColor(1, .82, .16, 1)
        texture:SetPoint("TOPLEFT", b, "TOPLEFT", -4, 4); texture:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 4, -4)
        texture:SetAlpha(0)
        return texture
    end
    b.SelectionGlow, b.PulseSurface = Glow(), Glow()
    -- Наведение не рисует ещё одну золотую рамку выбранной роли.
    b.Hover = b:CreateTexture(nil, "OVERLAY")
    b.Hover:SetColorTexture(1, 1, 1, 1)
    b.Hover:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -4)
    b.Hover:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 4)
    b.Hover:SetAlpha(0)
    local function Fade(texture, from, to, duration)
        local group = texture:CreateAnimationGroup()
        local alpha = group:CreateAnimation("Alpha")
        alpha:SetFromAlpha(from); alpha:SetToAlpha(to); alpha:SetDuration(duration)
        return group
    end
    b.Pulse = Fade(b.PulseSurface, .8, 0, .22)
    b.Pulse:SetScript("OnFinished", function() b.PulseSurface:SetAlpha(0) end)
    b.Pulse:SetScript("OnStop", function() b.PulseSurface:SetAlpha(0) end)
    b.HoverFade = Fade(b.Hover, 0, hoverAlpha, .12)
    b.HoverFade:SetScript("OnFinished", function() b.Hover:SetAlpha(b.hovered and b.filterEnabled and b:IsVisible() and hoverAlpha or 0) end)
    b.HoverFade:SetScript("OnStop", function() b.Hover:SetAlpha(0) end)
    local function ClearHover()
        b.HoverFade:Stop()
        -- Stop уже завершённой анимации не должен быть единственным сбросом.
        b.Hover:SetAlpha(0)
    end
    local function ClearPulse()
        b.Pulse:Stop(); b.PulseSurface:SetAlpha(0)
    end

    local function Paint()
        local enabled, selected = b.filterEnabled, b.selected
        b.Selected:SetShown(selected == true)
        b.Selected:SetAlpha(enabled and 1 or .35)
        b.SelectionGlow:SetAlpha(enabled and selected and .5 or 0)
        b:SetBackdropBorderColor(selected and .85 or .38, selected and .65 or .31, .16, 1)
        b.Icon:SetAlpha(enabled and (b.pressed and .72 or 1) or .35)
        b.Icon:ClearAllPoints(); b.Icon:SetPoint("CENTER", b, "CENTER", b.pressed and 1 or 0, b.pressed and -1 or 0)
        if not enabled then b.Label:SetTextColor(.5, .5, .5)
        elseif selected then b.Label:SetTextColor(1, .82, .2)
        else b.Label:SetTextColor(.9, .9, .9) end
    end
    function b:SetFilterState(selected, enabled)
        selected = selected == true
        local changed = self.selected ~= nil and self.selected ~= selected
        self.selected, self.filterEnabled = selected, enabled == true
        self:SetEnabled(self.filterEnabled)
        if not self.filterEnabled then
            self.hovered, self.pressed = false, false
            ClearHover(); ClearPulse()
        elseif changed and selected and self:IsVisible() then ClearPulse(); self.Pulse:Play()
        elseif not selected then ClearPulse() end
        Paint()
    end
    b:SetScript("OnEnter", function(self)
        self.hovered = self.filterEnabled and self:IsVisible() or false
        ClearHover()
        if self.hovered then self.HoverFade:Play() end
    end)
    b:SetScript("OnLeave", function(self)
        self.hovered, self.pressed = false, false
        ClearHover(); Paint()
    end)
    b:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and self.filterEnabled then self.pressed = true; Paint() end
    end)
    b:SetScript("OnMouseUp", function(self) self.pressed = false; Paint() end)
    b:SetScript("OnHide", function(self)
        self.hovered, self.pressed = false, false
        ClearHover(); ClearPulse(); Paint()
    end)
    b:SetFilterState(false, true)
    return b
end
