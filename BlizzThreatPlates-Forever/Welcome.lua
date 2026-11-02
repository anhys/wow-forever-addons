local addonName = ...
local addon = ForeverNameplates
-- One-time public Mixed rollout for fresh and existing users. Keep this
-- revision fixed for subsequent builds so acknowledged introductions stay closed.
local INTRO_REVISION = 4
local window, resumeAfterCombat
local events = CreateFrame("Frame")
local PANEL = {14/255, 16/255, 19/255, 1}
local CARD = {0.055, 0.063, 0.071, 1}
local BORDER = {0.20, 0.23, 0.27, 1}
local GOLD = {0.88, 0.66, 0.24, 1}
local TEXT = {0.93, 0.92, 0.87, 1}
local MUTED = {0.56, 0.57, 0.58, 1}

local function BuildWindow()
    local ui = addon.ModernOptionsUI
    local function Text(parent, value, size, x, y, width, color)
        local label = ui.Font(parent, "GameFontHighlight", value, x, y, width)
        addon:StyleOptionsFont(label, size)
        label:SetTextColor(unpack(color or TEXT))
        label:SetJustifyH("LEFT")
        return label
    end
    local function Button(parent, value, width, height)
        local button = ui.Button(parent, value, width, height)
        addon:StyleOptionsFont(button.label, 12)
        return button
    end
    local f = CreateFrame("Frame", "BTPThreatWelcome", UIParent, "BackdropTemplate")
    f:Hide()
    f:SetSize(960, 560)
    f:SetScale(0.9)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    ui.Backdrop(f, {PANEL[1], PANEL[2], PANEL[3], 0.9}, BORDER)
    local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(45)
    ui.Backdrop(header, PANEL, BORDER)
    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\" .. (addonName or "BlizzThreatPlates-Forever") .. "\\media\\ThreatSignal.tga")
    logo:SetTexCoord(0.12, 0.88, 0.23, 0.82)
    logo:SetSize(30, 20)
    logo:SetPoint("LEFT", 22, 0)
    Text(header, "BlizzThreatPlates", 18, 62, -12, 420)
    local close = Button(header, "×", 24, 24)
    addon:StyleOptionsFont(close.label, 22)
    close:SetPoint("TOPRIGHT", -13, -10)
    close:SetScript("OnClick", function() f:Hide() end)
    UISpecialFrames[#UISpecialFrames + 1] = "BTPThreatWelcome"
    Text(f, "Choose your threat display", 20, 24, -68, 700)
    Text(f, "Compare your lead on one enemy, watch the whole fight, or use both.", 13, 24, -98, 700, MUTED)
    local turnOff = Button(f, "Turn off", 140, 28)
    turnOff:SetPoint("TOPRIGHT", -24, -64)
    local turnOffNote = Text(f, "(I don't plan on tanking)", 11, 754, -100, 182, MUTED)
    turnOffNote:SetJustifyH("RIGHT")
    turnOff:SetScript("OnClick", function()
        addon:SetThreatDifferentialEnabled(false)
        if addon.RefreshModernThreatLayout then addon:RefreshModernThreatLayout() end
        f:Hide()
    end)
    f.turnOffButton = turnOff

    local modes = {
        {id="percentage", title="Percentage", tagline="Watch every enemy live",
         values={"168%", "142%", "87%"},
         description="Live threat percentages on your target and other enemies. Values can exceed 100%.",
         note="Every displayed value updates live.", button="Use Percentage"},
        {id="differential", title="Differential", tagline="Know your lead in threat points",
         values={"+420", "*+260", "*-85"},
         description="Live threat points ahead (+) or behind (-) on your selected target.",
         note="* marks an old snapshot on other enemies. Snapshots fade until you target them again.", button="Use Differential"},
        {id="mixed", title="Mixed", tagline="Target difference + live percentages",
         values={"+420", "142%", "87%"},
         description="A live threat-point difference on your target, with live percentages on other enemies.",
         note="Uses percentage if the target's difference is unavailable. No snapshots.", button="Use Mixed"},
    }
    f.modeButtons, f.modeCards = {}, {}
    local hoveredMode
    local function RefreshCardBorders()
        local selected = addon:GetThreatDifferentialEnabled() and addon:GetThreatDisplayMode()
        for mode, entry in pairs(f.modeCards) do
            entry.frame:SetBackdropBorderColor(unpack(mode == hoveredMode and mode ~= selected and GOLD or BORDER))
        end
    end
    for index, mode in ipairs(modes) do
        local card = CreateFrame("Frame", nil, f, "BackdropTemplate")
        card:SetPoint("TOPLEFT", 24 + (index - 1) * 312, -132)
        card:SetSize(288, 384)
        ui.Backdrop(card, CARD, BORDER)
        -- Dim the selected option's contents without fading its gold status
        -- label or the border used to highlight the hovered option.
        local content = CreateFrame("Frame", nil, card)
        content:SetAllPoints(card)
        Text(content, mode.title, 18, 16, -16, 140)
        local current = Text(card, "Currently Selected", 11, 160, -20, 112, GOLD)
        Text(content, mode.tagline, 12, 16, -44, 256, MUTED)
        local preview = CreateFrame("Frame", nil, content, "BackdropTemplate")
        preview:SetPoint("TOPLEFT", 16, -76)
        preview:SetSize(256, 148)
        ui.Backdrop(preview, PANEL, BORDER)
        Text(preview, "Selected target", 10, 84, -10, 158, GOLD)
        local names = {"Young Wolf", "Stonetusk Boar", "Forest Spider"}
        -- Fixed illustrative samples only; no live unit data or secret reads.
        for row = 1, 3 do
            local bar = CreateFrame("Frame", nil, preview, "BackdropTemplate")
            bar:SetPoint("TOPLEFT", 84, -28 - (row - 1) * 37)
            bar:SetSize(158, 23)
            ui.Backdrop(bar, PANEL, row == 1 and GOLD or BORDER)
            local fill = bar:CreateTexture(nil, "ARTWORK")
            fill:SetPoint("TOPLEFT", 2, -2)
            fill:SetSize(154 * (0.90 - (row - 1) * 0.13), 19)
            fill:SetColorTexture(row == 3 and 0.7 or 0.04, row == 3 and 0.08 or 0.48, 0.06, 1)
            Text(bar, names[row], 11, 6, -5, 146)
            local value = preview:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            addon:StyleOptionsFont(value, 17)
            value:SetPoint("RIGHT", bar, "LEFT", -8, 0)
            value:SetText(mode.values[row])
            value:SetTextColor(row == 3 and 1 or 0.15, row == 3 and 0.18 or 1, 0.10, 1)
            if mode.id == "differential" and row > 1 then value:SetAlpha(0.65) end
        end
        Text(content, mode.description, 13, 16, -240, 256)
        Text(content, mode.note, 12, 16, -291, 256, MUTED)
        local button = Button(content, mode.button, 256, 28)
        button:SetPoint("BOTTOM", 0, 14)
        button:SetScript("OnClick", function()
            addon:SetThreatDisplayMode(mode.id)
            addon:SetThreatDifferentialEnabled(true)
            if addon.RefreshModernThreatLayout then addon:RefreshModernThreatLayout() end
            f:Hide()
        end)
        f.modeButtons[mode.id] = button
        f.modeCards[mode.id] = {frame=card, content=content, current=current}
        local function Enter()
            hoveredMode = mode.id
            RefreshCardBorders()
        end
        local function Leave()
            -- Moving into the card's button still counts as hovering this
            -- option. An older leave event must not clear another card's hover.
            if hoveredMode == mode.id and not card:IsMouseOver() then
                hoveredMode = nil
                RefreshCardBorders()
            end
        end
        card:EnableMouse(true)
        card:SetScript("OnEnter", Enter)
        card:SetScript("OnLeave", Leave)
        button:HookScript("OnEnter", Enter)
        button:HookScript("OnLeave", Leave)
    end
    Text(f, "Change anytime: Colors & Threat > Threat Display. Values appear when Blizzard supplies threat data.", 12, 24, -528, 912, MUTED)
    f:SetScript("OnShow", function()
        hoveredMode = nil
        for mode, entry in pairs(f.modeCards) do
            local selected = addon:GetThreatDifferentialEnabled() and addon:GetThreatDisplayMode() == mode
            entry.current:SetShown(selected)
            entry.content:SetAlpha(selected and 0.42 or 1)
        end
        RefreshCardBorders()
    end)
    f:SetScript("OnHide", function()
        -- A combat interruption is not a dismissal; resume when it is safe.
        if not resumeAfterCombat and ForeverNameplatesDB then
            ForeverNameplatesDB.threatWelcomeRevision = INTRO_REVISION
        end
    end)
    return f
end

function addon:ShowThreatWelcome()
    if not ForeverNameplatesDB or InCombatLockdown() then return end
    window = window or BuildWindow()
    window:Show()
end
local function ShowIfNeeded()
    if not ForeverNameplatesDB or ForeverNameplatesDB.threatWelcomeRevision == INTRO_REVISION then return end
    addon:ShowThreatWelcome()
end
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if window and window:IsShown() then resumeAfterCombat = true; window:Hide() end
    elseif resumeAfterCombat then
        resumeAfterCombat = nil
        addon:ShowThreatWelcome()
    else ShowIfNeeded() end
end)
SLASH_BTPWELCOME1 = "/btpwelcome"
SlashCmdList.BTPWELCOME = function() addon:ShowThreatWelcome() end
