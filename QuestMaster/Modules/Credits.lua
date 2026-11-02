--[[
    QuestMaster Credits Module
    Displays credits and links in a beautiful separate window
]]

local addonName, QM = ...

local CreditsFrame = nil

-- Design constants matching main UI
local DESIGN = {
    gold = {0.95, 0.78, 0.25},
    bgDarkest = {0.04, 0.04, 0.05},
    bgDark = {0.06, 0.06, 0.07},
    bgMedium = {0.09, 0.09, 0.11},
    bgLight = {0.13, 0.13, 0.15},
    border = {0.22, 0.20, 0.18},
    textWhite = {0.92, 0.92, 0.92},
    textGray = {0.65, 0.65, 0.65},
    textMuted = {0.45, 0.45, 0.45},
}

-- ============================================================================
-- Credits Window Creation
-- ============================================================================

function QM:InitializeCredits()
    if CreditsFrame then return end

    CreditsFrame = CreateFrame("Frame", "QuestMasterCreditsFrame", UIParent, "BackdropTemplate")
    CreditsFrame:SetSize(340, 320)
    CreditsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    CreditsFrame:SetFrameStrata("DIALOG")
    CreditsFrame:SetMovable(true)
    CreditsFrame:EnableMouse(true)
    CreditsFrame:RegisterForDrag("LeftButton")
    CreditsFrame:SetClampedToScreen(true)

    -- Premium dark background
    CreditsFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    CreditsFrame:SetBackdropColor(DESIGN.bgDarkest[1], DESIGN.bgDarkest[2], DESIGN.bgDarkest[3], 0.98)
    CreditsFrame:SetBackdropBorderColor(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.9)

    -- Drag functionality
    CreditsFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    CreditsFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Header
    local header = CreateFrame("Frame", nil, CreditsFrame, "BackdropTemplate")
    header:SetHeight(36)
    header:SetPoint("TOPLEFT", CreditsFrame, "TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", CreditsFrame, "TOPRIGHT", -4, -4)
    header:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    header:SetBackdropColor(DESIGN.bgMedium[1], DESIGN.bgMedium[2], DESIGN.bgMedium[3], 1)

    -- Gold accent line top
    local accentTop = header:CreateTexture(nil, "ARTWORK")
    accentTop:SetHeight(2)
    accentTop:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    accentTop:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
    accentTop:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.6)

    -- Gold accent line bottom
    local accent = header:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(2)
    accent:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    accent:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    accent:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.4)

    -- Header icon
    local hIcon = header:CreateTexture(nil, "ARTWORK")
    hIcon:SetSize(22, 22)
    hIcon:SetPoint("LEFT", 10, 0)
    hIcon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")

    -- Title
    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
    title:SetPoint("LEFT", hIcon, "RIGHT", 8, 0)
    title:SetText("|cFFFFD700Quest|r|cFFFFFFFFMaster|r |cFF888888Credits|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("RIGHT", -8, 0)
    closeBtn.line1 = closeBtn:CreateTexture(nil, "ARTWORK")
    closeBtn.line1:SetSize(12, 2)
    closeBtn.line1:SetPoint("CENTER")
    closeBtn.line1:SetColorTexture(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3], 1)
    closeBtn.line1:SetRotation(math.rad(45))
    closeBtn.line2 = closeBtn:CreateTexture(nil, "ARTWORK")
    closeBtn.line2:SetSize(12, 2)
    closeBtn.line2:SetPoint("CENTER")
    closeBtn.line2:SetColorTexture(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3], 1)
    closeBtn.line2:SetRotation(math.rad(-45))
    closeBtn:SetScript("OnClick", function() CreditsFrame:Hide() end)
    closeBtn:SetScript("OnEnter", function(self)
        self.line1:SetColorTexture(0.9, 0.3, 0.3, 1)
        self.line2:SetColorTexture(0.9, 0.3, 0.3, 1)
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self.line1:SetColorTexture(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3], 1)
        self.line2:SetColorTexture(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3], 1)
    end)

    -- Content area
    local content = CreateFrame("Frame", nil, CreditsFrame, "BackdropTemplate")
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 8, -12)
    content:SetPoint("BOTTOMRIGHT", CreditsFrame, "BOTTOMRIGHT", -12, 12)

    local y = 0

    -- Logo/Icon with glow effect
    local iconGlow = content:CreateTexture(nil, "BACKGROUND")
    iconGlow:SetSize(70, 70)
    iconGlow:SetPoint("TOP", 0, y)
    iconGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
    iconGlow:SetVertexColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.08)
    iconGlow:SetBlendMode("ADD")

    local icon = content:CreateTexture(nil, "ARTWORK")
    icon:SetSize(52, 52)
    icon:SetPoint("TOP", 0, y - 9)
    icon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
    y = y - 65

    -- Addon name
    local addonTitle = content:CreateFontString(nil, "OVERLAY")
    addonTitle:SetFont("Fonts\\FRIZQT__.TTF", 16, "")
    addonTitle:SetPoint("TOP", 0, y)
    addonTitle:SetText("|cFFFFD700Quest|r|cFFFFFFFFMaster|r")
    y = y - 20

    -- Version
    local version = content:CreateFontString(nil, "OVERLAY")
    version:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    version:SetPoint("TOP", 0, y)
    -- Dynamic edition text based on detected game version
    local editionText = "All-in-One Edition"
    if QM.gameVersion == "Classic" then
        editionText = "Classic Era"
    elseif QM.gameVersion == "TBC" then
        editionText = "TBC Classic Edition"
    elseif QM.gameVersion == "Wrath" then
        editionText = "Wrath Titan Reforged Edition"
    elseif QM.gameVersion == "MoP" then
        editionText = "Mists of Pandaria Edition"
    end
    version:SetText("|cFF666666" .. editionText .. "|r")
    y = y - 28

    -- Divider
    local divider1 = content:CreateTexture(nil, "ARTWORK")
    divider1:SetSize(220, 1)
    divider1:SetPoint("TOP", 0, y)
    divider1:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.3)
    y = y - 18

    -- Created by section
    local createdLabel = content:CreateFontString(nil, "OVERLAY")
    createdLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
    createdLabel:SetPoint("TOP", 0, y)
    createdLabel:SetText("|cFF888888Developed by|r")
    y = y - 18

    local authorName = content:CreateFontString(nil, "OVERLAY")
    authorName:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
    authorName:SetPoint("TOP", 0, y)
    authorName:SetText("|cFF00FF00JugoBetrugoTV|r")
    y = y - 16

    local authorAka = content:CreateFontString(nil, "OVERLAY")
    authorAka:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    authorAka:SetPoint("TOP", 0, y)
    authorAka:SetText("|cFF666666also known as|r |cFFFF8800Novi_Live|r")
    y = y - 28

    -- Divider
    local divider2 = content:CreateTexture(nil, "ARTWORK")
    divider2:SetSize(220, 1)
    divider2:SetPoint("TOP", 0, y)
    divider2:SetColorTexture(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.5)
    y = y - 18

    -- Social links
    local linksLabel = content:CreateFontString(nil, "OVERLAY")
    linksLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
    linksLabel:SetPoint("TOP", 0, y)
    linksLabel:SetText("|cFF888888Connect|r")
    y = y - 20

    -- Twitch
    local twitchRow = content:CreateFontString(nil, "OVERLAY")
    twitchRow:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    twitchRow:SetPoint("TOP", 0, y)
    twitchRow:SetText("|cFF9146FFTwitch|r  |cFFDDDDDDtwitch.tv/Novi_Live|r")
    y = y - 18

    -- Discord
    local discordRow = content:CreateFontString(nil, "OVERLAY")
    discordRow:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    discordRow:SetPoint("TOP", 0, y)
    discordRow:SetText("|cFF5865F2Discord|r  |cFFDDDDDDdiscord.gg/rv2BsbE|r")
    y = y - 28

    -- Bug reports
    local bugLabel = content:CreateFontString(nil, "OVERLAY")
    bugLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
    bugLabel:SetPoint("TOP", 0, y)
    bugLabel:SetText("|cFFFF8800Bug Reports|r |cFF666666via CurseForge or Discord|r")

    CreditsFrame:Hide()
    QM.CreditsFrame = CreditsFrame
end

-- ============================================================================
-- Toggle Credits Window
-- ============================================================================

function QM:ToggleCredits()
    if not CreditsFrame then
        self:InitializeCredits()
    end

    if CreditsFrame:IsShown() then
        CreditsFrame:Hide()
    else
        CreditsFrame:Show()
    end
end

function QM:ShowCredits()
    if not CreditsFrame then
        self:InitializeCredits()
    end
    CreditsFrame:Show()
end
