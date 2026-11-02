--[[
    QuestMaster Quest Tracker Module
    Displays tracked quests grouped by zone
    Collapsible zones and quests
    Modern premium design matching Settings UI
]]

local addonName, QM = ...
local L = QM.L

local TrackerFrame = nil

-- Frame pools
local questFramePool = {}
local objectiveFramePool = {}
local zoneHeaderPool = {}

-- Collapse state storage
local collapsedZones = {}
local collapsedQuests = {}

-- ============================================================================
-- Design System - Matching Settings UI
-- ============================================================================

local DESIGN = {
    -- Colors matching Settings UI
    gold = {0.95, 0.78, 0.25},
    goldDark = {0.65, 0.50, 0.15},
    bgDarkest = {0.04, 0.04, 0.05},
    bgDark = {0.06, 0.06, 0.07},
    bgMedium = {0.09, 0.09, 0.11},
    bgLight = {0.13, 0.13, 0.15},
    bgCard = {0.075, 0.075, 0.09},
    border = {0.22, 0.20, 0.18},
    textWhite = {0.92, 0.92, 0.92},
    textGray = {0.65, 0.65, 0.65},
    textMuted = {0.45, 0.45, 0.45},
    success = {0.35, 0.85, 0.45},
    warning = {1, 0.75, 0.3},
    error = {0.95, 0.35, 0.35},
}

-- Theme color presets (expanded)
local THEMES = {
    gold = {accent = {0.95, 0.78, 0.25}, accentDark = {0.65, 0.50, 0.15}, accentBright = {1, 0.88, 0.45}},
    blue = {accent = {0.35, 0.65, 0.95}, accentDark = {0.2, 0.4, 0.7}, accentBright = {0.5, 0.8, 1}},
    green = {accent = {0.35, 0.85, 0.45}, accentDark = {0.2, 0.55, 0.3}, accentBright = {0.5, 1, 0.6}},
    red = {accent = {0.95, 0.35, 0.35}, accentDark = {0.65, 0.2, 0.2}, accentBright = {1, 0.5, 0.5}},
    purple = {accent = {0.7, 0.45, 0.95}, accentDark = {0.45, 0.25, 0.65}, accentBright = {0.85, 0.6, 1}},
    orange = {accent = {1, 0.55, 0.15}, accentDark = {0.7, 0.35, 0.1}, accentBright = {1, 0.7, 0.3}},
    teal = {accent = {0.25, 0.85, 0.8}, accentDark = {0.15, 0.55, 0.5}, accentBright = {0.4, 1, 0.95}},
    pink = {accent = {0.95, 0.45, 0.7}, accentDark = {0.65, 0.25, 0.45}, accentBright = {1, 0.6, 0.8}},
    silver = {accent = {0.75, 0.78, 0.82}, accentDark = {0.5, 0.52, 0.55}, accentBright = {0.9, 0.92, 0.95}},
    bronze = {accent = {0.8, 0.55, 0.3}, accentDark = {0.55, 0.35, 0.18}, accentBright = {0.95, 0.7, 0.45}},
}

-- Make themes accessible globally for other modules
QM.THEMES = THEMES

-- Apply theme colors and refresh all UI elements
function QM:ApplyTheme(themeName)
    local theme = THEMES[themeName] or THEMES.gold
    DESIGN.gold = theme.accent
    DESIGN.goldDark = theme.accentDark

    -- Store current theme colors globally for other modules
    QM.currentTheme = {
        accent = theme.accent,
        accentDark = theme.accentDark,
        accentBright = theme.accentBright or theme.accent,
    }

    -- Refresh TrackerFrame elements if it exists
    if TrackerFrame then
        -- Header accents
        if TrackerFrame.accentTop then
            TrackerFrame.accentTop:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.4)
        end
        if TrackerFrame.accent then
            TrackerFrame.accent:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.6)
        end
        if TrackerFrame.iconGlow then
            TrackerFrame.iconGlow:SetVertexColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.1)
        end

        -- Info bar zone text
        if TrackerFrame.infoBar and TrackerFrame.infoBar.zoneText then
            TrackerFrame.infoBar.zoneText:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
        end

        -- Update zone headers
        for _, f in ipairs(zoneHeaderPool) do
            if f.accent then
                f.accent:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.7)
            end
            if f.name then
                f.name:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
            end
        end

        -- Update quest frames
        for _, f in ipairs(questFramePool) do
            if f.highlight then
                f.highlight:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.05)
            end
            if f.selectedGlow then
                f.selectedGlow:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.12)
            end
            if f.turnInIcon then
                f.turnInIcon:SetVertexColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
            end
        end
    end

    -- Refresh Arrow if it exists
    if QM.RefreshArrowTheme then
        QM:RefreshArrowTheme()
    end

    -- Refresh Map pins if function exists
    if QM.RefreshMapTheme then
        QM:RefreshMapTheme()
    end

    -- Refresh Settings panel if it exists
    if QM.RefreshSettingsTheme then
        QM:RefreshSettingsTheme()
    end
end

-- Get scaled value based on screen resolution (only for very high res)
local function GetScaledValue(baseValue)
    local screenHeight = select(2, GetPhysicalScreenSize()) or 1080
    if screenHeight > 1440 then
        return math.floor(baseValue * (screenHeight / 1440) + 0.5)
    end
    return baseValue
end

-- Constants (increased spacing for better readability)
local ZONE_HEADER_HEIGHT = 24
local QUEST_HEIGHT = 22
local OBJECTIVE_HEIGHT = 18
local PADDING = 6

-- Compact mode constants
local COMPACT_QUEST_HEIGHT = 15
local COMPACT_OBJECTIVE_HEIGHT = 13
local COMPACT_PADDING = 2

-- Font sizes
local FONT_HEADER = 12
local FONT_ZONE = 10
local FONT_QUEST = 10
local FONT_OBJECTIVE = 9
local FONT_SMALL = 9
local FONT_COMPACT = 8

-- Dynamic font size from settings (used for runtime updates)
local function GetFontSize()
    if QM.db and QM.db.profile and QM.db.profile.tracker then
        return QM.db.profile.tracker.fontSize or 9
    end
    return 9
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Distance formatting functions are in Tracker/Helpers.lua
-- Use Tracker:FormatDistanceCompact(), Tracker:FormatDistanceFull(), Tracker:GetDistanceColor()

-- Get progress color based on completion percentage
local function GetProgressColor(current, required)
    if not current or not required or required == 0 then return 0.8, 0.8, 0.8 end
    local pct = current / required
    if pct >= 1 then
        return 0.3, 1, 0.3  -- Green - complete
    elseif pct >= 0.75 then
        return 0.6, 1, 0.3  -- Yellow-green - almost done
    elseif pct >= 0.5 then
        return 1, 0.9, 0.3  -- Yellow - halfway
    elseif pct >= 0.25 then
        return 1, 0.6, 0.2  -- Orange - started
    else
        return 0.8, 0.4, 0.2  -- Red-orange - just started
    end
end

-- Colors (using design system)
local COLORS = {
    header = {DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 1},
    zoneHeader = {DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 1},
    zoneBg = {DESIGN.bgMedium[1], DESIGN.bgMedium[2], DESIGN.bgMedium[3], 0.95},
    questTitle = {DESIGN.textWhite[1], DESIGN.textWhite[2], DESIGN.textWhite[3], 1},
    questComplete = {DESIGN.success[1], DESIGN.success[2], DESIGN.success[3], 1},
    objectiveText = {DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3], 1},
    objectiveComplete = {DESIGN.success[1] * 0.8, DESIGN.success[2] * 0.8, DESIGN.success[3] * 0.8, 1},
    background = {DESIGN.bgDarkest[1], DESIGN.bgDarkest[2], DESIGN.bgDarkest[3], 0.95},
    distance = {0.5, 0.75, 1, 1},
}

-- Update background alpha from settings
local function UpdateBackgroundAlpha()
    if QM.db and QM.db.profile and QM.db.profile.tracker then
        -- Support both alpha and bgAlpha for compatibility
        local alpha = QM.db.profile.tracker.alpha or QM.db.profile.tracker.bgAlpha or 0.9
        COLORS.background[4] = alpha
    end
end

local function UpdateBorderVisibility()
    if not TrackerFrame or not QM.db or not QM.db.profile then return end
    local showBorder = QM.db.profile.tracker.showBorder ~= false
    if showBorder then
        TrackerFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = {left = 2, right = 2, top = 2, bottom = 2}
        })
        TrackerFrame:SetBackdropColor(DESIGN.bgDarkest[1], DESIGN.bgDarkest[2], DESIGN.bgDarkest[3], COLORS.background[4] or 0.97)
        TrackerFrame:SetBackdropBorderColor(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.8)
    else
        TrackerFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            insets = {left = 0, right = 0, top = 0, bottom = 0}
        })
        TrackerFrame:SetBackdropColor(DESIGN.bgDarkest[1], DESIGN.bgDarkest[2], DESIGN.bgDarkest[3], COLORS.background[4] or 0.97)
    end
end

-- Zone names
local ZONE_NAMES = {
    [1429] = "Elwynn Forest", [1430] = "Westfall", [1431] = "Duskwood",
    [1432] = "Redridge Mountains", [1433] = "Loch Modan", [1434] = "Dun Morogh",
    [1435] = "Wetlands", [1436] = "Darkshore", [1437] = "Teldrassil",
    [1438] = "Ashenvale", [1439] = "Stonetalon Mountains", [1440] = "Thousand Needles",
    [1441] = "Desolace", [1442] = "Feralas", [1443] = "Tanaris",
    [1444] = "Un'Goro Crater", [1445] = "Silithus", [1446] = "Winterspring",
    [1447] = "Azshara", [1448] = "Felwood", [1449] = "Durotar",
    [1450] = "Mulgore", [1451] = "The Barrens", [1452] = "Stranglethorn Vale",
    [1453] = "Stormwind City", [1454] = "Orgrimmar", [1455] = "Ironforge",
    [1456] = "Thunder Bluff", [1457] = "Darnassus", [1458] = "Undercity",
    [1459] = "Alterac Mountains", [1460] = "Arathi Highlands", [1461] = "Badlands",
    [1462] = "Blasted Lands", [1463] = "Burning Steppes", [1464] = "Deadwind Pass",
    [1465] = "Dustwallow Marsh", [1466] = "Eastern Plaguelands", [1467] = "Hillsbrad Foothills",
    [1468] = "The Hinterlands", [1469] = "Searing Gorge", [1470] = "Silverpine Forest",
    [1471] = "Swamp of Sorrows", [1472] = "Tirisfal Glades", [1473] = "Western Plaguelands",
}

-- ============================================================================
-- Tracker Frame Creation
-- ============================================================================

function QM:InitializeTracker()
    -- Screen-relative default sizing
    local screenWidth, screenHeight = GetPhysicalScreenSize()
    local defaultWidth = math.min(260, screenWidth * 0.2)
    local defaultHeight = math.min(320, screenHeight * 0.35)

    TrackerFrame = CreateFrame("Frame", "QuestMasterTrackerFrame", UIParent, "BackdropTemplate")
    TrackerFrame:SetSize(QM.db.profile.tracker.width or defaultWidth, QM.db.profile.tracker.height or defaultHeight)
    TrackerFrame:SetPoint(
        QM.db.profile.tracker.point or "RIGHT", UIParent,
        QM.db.profile.tracker.point or "RIGHT",
        QM.db.profile.tracker.x or -30, QM.db.profile.tracker.y or 50
    )
    TrackerFrame:SetFrameStrata("MEDIUM")
    TrackerFrame:SetClampedToScreen(true)
    TrackerFrame:EnableMouse(true)
    TrackerFrame:SetMovable(true)
    TrackerFrame:RegisterForDrag("LeftButton")

    -- Premium dark background with subtle border
    TrackerFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    TrackerFrame:SetBackdropColor(DESIGN.bgDarkest[1], DESIGN.bgDarkest[2], DESIGN.bgDarkest[3], 0.97)
    TrackerFrame:SetBackdropBorderColor(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.8)

    -- Header (premium style)
    TrackerFrame.header = CreateFrame("Frame", nil, TrackerFrame, "BackdropTemplate")
    TrackerFrame.header:SetHeight(32)
    TrackerFrame.header:SetPoint("TOPLEFT", TrackerFrame, "TOPLEFT", 3, -3)
    TrackerFrame.header:SetPoint("TOPRIGHT", TrackerFrame, "TOPRIGHT", -3, -3)
    TrackerFrame.header:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    TrackerFrame.header:SetBackdropColor(DESIGN.bgMedium[1], DESIGN.bgMedium[2], DESIGN.bgMedium[3], 1)

    -- Top gold accent line (save reference for theme updates)
    TrackerFrame.accentTop = TrackerFrame.header:CreateTexture(nil, "ARTWORK", nil, 1)
    TrackerFrame.accentTop:SetHeight(1)
    TrackerFrame.accentTop:SetPoint("TOPLEFT", 0, 0)
    TrackerFrame.accentTop:SetPoint("TOPRIGHT", 0, 0)
    TrackerFrame.accentTop:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.4)

    -- Bottom gold accent line (save reference for theme updates)
    TrackerFrame.accent = TrackerFrame.header:CreateTexture(nil, "ARTWORK", nil, 1)
    TrackerFrame.accent:SetHeight(2)
    TrackerFrame.accent:SetPoint("BOTTOMLEFT", TrackerFrame.header, "BOTTOMLEFT", 0, 0)
    TrackerFrame.accent:SetPoint("BOTTOMRIGHT", TrackerFrame.header, "BOTTOMRIGHT", 0, 0)
    TrackerFrame.accent:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.6)

    -- Header icon with glow (save reference for theme updates)
    TrackerFrame.iconGlow = TrackerFrame.header:CreateTexture(nil, "ARTWORK", nil, 1)
    TrackerFrame.iconGlow:SetSize(26, 26)
    TrackerFrame.iconGlow:SetPoint("LEFT", 6, 0)
    TrackerFrame.iconGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
    TrackerFrame.iconGlow:SetVertexColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.1)
    TrackerFrame.iconGlow:SetBlendMode("ADD")

    local hIcon = TrackerFrame.header:CreateTexture(nil, "ARTWORK", nil, 2)
    hIcon:SetSize(20, 20)
    hIcon:SetPoint("LEFT", 9, 0)
    hIcon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")

    -- Title
    TrackerFrame.header.title = TrackerFrame.header:CreateFontString(nil, "OVERLAY")
    TrackerFrame.header.title:SetFont("Fonts\\FRIZQT__.TTF", FONT_HEADER, "")
    TrackerFrame.header.title:SetPoint("LEFT", hIcon, "RIGHT", 6, 0)
    TrackerFrame.header.title:SetText("|cFFFFD700" .. L["TRACKER_TITLE"] .. "|r")

    -- Quest count badge
    TrackerFrame.header.count = TrackerFrame.header:CreateFontString(nil, "OVERLAY")
    TrackerFrame.header.count:SetFont("Fonts\\FRIZQT__.TTF", FONT_SMALL, "")
    TrackerFrame.header.count:SetPoint("LEFT", TrackerFrame.header.title, "RIGHT", 5, 0)
    TrackerFrame.header.count:SetTextColor(DESIGN.textMuted[1], DESIGN.textMuted[2], DESIGN.textMuted[3])
    TrackerFrame.header.count:SetText("(0)")

    -- Minimize button (far right) - using line approach for +/-
    local minBtn = CreateFrame("Button", nil, TrackerFrame.header)
    minBtn:SetSize(18, 18)
    minBtn:SetPoint("RIGHT", -6, 0)
    -- Horizontal line (always visible)
    minBtn.line = minBtn:CreateTexture(nil, "ARTWORK")
    minBtn.line:SetSize(10, 2)
    minBtn.line:SetPoint("CENTER")
    minBtn.line:SetColorTexture(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3], 1)
    -- Vertical line (only for + sign when minimized)
    minBtn.line2 = minBtn:CreateTexture(nil, "ARTWORK")
    minBtn.line2:SetSize(2, 10)
    minBtn.line2:SetPoint("CENTER")
    minBtn.line2:SetColorTexture(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3], 1)
    minBtn.line2:Hide()
    minBtn:SetScript("OnClick", function() QM:ToggleTrackerMinimized() end)
    minBtn:SetScript("OnEnter", function(s)
        s.line:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 1)
        s.line2:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 1)
    end)
    minBtn:SetScript("OnLeave", function(s)
        s.line:SetColorTexture(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3], 1)
        s.line2:SetColorTexture(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3], 1)
    end)
    TrackerFrame.header.minimize = minBtn

    -- Nearest Quest button (compass icon)
    local nearestBtn = CreateFrame("Button", nil, TrackerFrame.header)
    nearestBtn:SetSize(16, 16)
    nearestBtn:SetPoint("RIGHT", minBtn, "LEFT", -4, 0)
    nearestBtn.tex = nearestBtn:CreateTexture(nil, "ARTWORK")
    nearestBtn.tex:SetAllPoints()
    nearestBtn.tex:SetTexture("Interface\\Minimap\\Tracking\\None")
    nearestBtn.tex:SetVertexColor(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3])
    nearestBtn:SetScript("OnClick", function() QM:NavigateToNearestQuest() end)
    nearestBtn:SetScript("OnEnter", function(s)
        s.tex:SetVertexColor(DESIGN.success[1], DESIGN.success[2], DESIGN.success[3])
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:AddLine("|cFFFFD700" .. L["NAVIGATE_TO_NEAREST"] .. "|r")
        GameTooltip:AddLine(L["CLICK_TO_SET_WAYPOINT"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    nearestBtn:SetScript("OnLeave", function(s)
        s.tex:SetVertexColor(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3])
        GameTooltip:Hide()
    end)
    TrackerFrame.header.nearestBtn = nearestBtn

    -- Nearest Turn-in button (checkmark icon)
    local turnInBtn = CreateFrame("Button", nil, TrackerFrame.header)
    turnInBtn:SetSize(16, 16)
    turnInBtn:SetPoint("RIGHT", nearestBtn, "LEFT", -2, 0)
    turnInBtn.tex = turnInBtn:CreateTexture(nil, "ARTWORK")
    turnInBtn.tex:SetAllPoints()
    turnInBtn.tex:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    turnInBtn.tex:SetVertexColor(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3])
    turnInBtn:SetScript("OnClick", function() QM:NavigateToNearestTurnIn() end)
    turnInBtn:SetScript("OnEnter", function(s)
        s.tex:SetVertexColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:AddLine("|cFFFFD700" .. L["NAVIGATE_TO_TURNIN"] .. "|r")
        GameTooltip:AddLine(L["NEAREST_COMPLETED_QUEST"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    turnInBtn:SetScript("OnLeave", function(s)
        s.tex:SetVertexColor(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3])
        GameTooltip:Hide()
    end)
    TrackerFrame.header.turnInBtn = turnInBtn

    -- Sort By button
    local sortBtn = CreateFrame("Button", nil, TrackerFrame.header)
    sortBtn:SetSize(36, 16)
    sortBtn:SetPoint("RIGHT", turnInBtn, "LEFT", -3, 0)
    sortBtn.text = sortBtn:CreateFontString(nil, "OVERLAY")
    sortBtn.text:SetFont("Fonts\\FRIZQT__.TTF", FONT_SMALL - 1, "")
    sortBtn.text:SetPoint("CENTER", 0, 0)
    sortBtn.text:SetText("|cFF888888" .. L["SORT"] .. "|r")
    sortBtn:SetScript("OnClick", function(s) QM:ShowSortDropdown(s) end)
    sortBtn:SetScript("OnEnter", function(s)
        s.text:SetText("|cFFFFD700" .. L["SORT"] .. "|r")
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        local currentSort = QM.db.profile.tracker.sortBy or "distance"
        local sortNames = {distance = L["SORT_DISTANCE"], level = L["SORT_LEVEL"]}
        GameTooltip:AddLine("|cFFFFD700" .. L["SORT_QUESTS_BY"] .. "|r")
        GameTooltip:AddLine(L["CURRENT"] .. ": " .. (sortNames[currentSort] or currentSort), 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    sortBtn:SetScript("OnLeave", function(s)
        s.text:SetText("|cFF888888" .. L["SORT"] .. "|r")
        GameTooltip:Hide()
    end)
    TrackerFrame.header.sortBtn = sortBtn

    -- Settings button (gear icon)
    local setBtn = CreateFrame("Button", nil, TrackerFrame.header)
    setBtn:SetSize(16, 16)
    setBtn:SetPoint("RIGHT", sortBtn, "LEFT", -3, 0)
    setBtn.tex = setBtn:CreateTexture(nil, "ARTWORK")
    setBtn.tex:SetSize(14, 14)
    setBtn.tex:SetPoint("CENTER")
    setBtn.tex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    setBtn.tex:SetVertexColor(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3])
    setBtn:SetScript("OnClick", function() QM:ToggleSettings() end)
    setBtn:SetScript("OnEnter", function(s)
        s.tex:SetVertexColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:AddLine("|cFFFFD700" .. L["SETTINGS"] .. "|r")
        GameTooltip:Show()
    end)
    setBtn:SetScript("OnLeave", function(s)
        s.tex:SetVertexColor(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3])
        GameTooltip:Hide()
    end)
    TrackerFrame.header.settingsBtn = setBtn

    -- Lock indicator (shows when frames are locked)
    local lockIcon = TrackerFrame.header:CreateTexture(nil, "ARTWORK")
    lockIcon:SetSize(12, 12)
    lockIcon:SetPoint("RIGHT", setBtn, "LEFT", -4, 0)
    lockIcon:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
    lockIcon:SetVertexColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.8)
    lockIcon:SetAlpha(QM.db.profile.lockFrames and 0.8 or 0)
    TrackerFrame.header.lockIcon = lockIcon

    -- Info bar (XP/Hour + Zone Progress) - premium styling
    TrackerFrame.infoBar = CreateFrame("Frame", nil, TrackerFrame, "BackdropTemplate")
    TrackerFrame.infoBar:SetHeight(20)
    TrackerFrame.infoBar:SetPoint("TOPLEFT", TrackerFrame.header, "BOTTOMLEFT", 0, -1)
    TrackerFrame.infoBar:SetPoint("TOPRIGHT", TrackerFrame.header, "BOTTOMRIGHT", 0, -1)
    TrackerFrame.infoBar:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    TrackerFrame.infoBar:SetBackdropColor(DESIGN.bgDark[1], DESIGN.bgDark[2], DESIGN.bgDark[3], 0.95)

    -- Subtle separator line
    local infoSep = TrackerFrame.infoBar:CreateTexture(nil, "ARTWORK")
    infoSep:SetHeight(1)
    infoSep:SetPoint("BOTTOMLEFT", 0, 0)
    infoSep:SetPoint("BOTTOMRIGHT", 0, 0)
    infoSep:SetColorTexture(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.4)

    -- XP/Hour text (left side) - constrained width to prevent overlap
    TrackerFrame.infoBar.xpText = TrackerFrame.infoBar:CreateFontString(nil, "OVERLAY")
    TrackerFrame.infoBar.xpText:SetFont("Fonts\\FRIZQT__.TTF", FONT_SMALL, "")
    TrackerFrame.infoBar.xpText:SetPoint("LEFT", 8, 0)
    TrackerFrame.infoBar.xpText:SetPoint("RIGHT", TrackerFrame.infoBar, "CENTER", -4, 0)
    TrackerFrame.infoBar.xpText:SetJustifyH("LEFT")
    TrackerFrame.infoBar.xpText:SetWordWrap(false)
    TrackerFrame.infoBar.xpText:SetTextColor(0.4, 0.75, 1)
    TrackerFrame.infoBar.xpText:SetText(L["XP_HOUR_PREFIX"] .. " 0")

    -- Zone Progress text (right side) - constrained width to prevent overlap
    TrackerFrame.infoBar.zoneText = TrackerFrame.infoBar:CreateFontString(nil, "OVERLAY")
    TrackerFrame.infoBar.zoneText:SetFont("Fonts\\FRIZQT__.TTF", FONT_SMALL, "")
    TrackerFrame.infoBar.zoneText:SetPoint("RIGHT", -8, 0)
    TrackerFrame.infoBar.zoneText:SetPoint("LEFT", TrackerFrame.infoBar, "CENTER", 4, 0)
    TrackerFrame.infoBar.zoneText:SetJustifyH("RIGHT")
    TrackerFrame.infoBar.zoneText:SetWordWrap(false)
    TrackerFrame.infoBar.zoneText:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
    TrackerFrame.infoBar.zoneText:SetText("")

    -- Tooltip for info bar
    TrackerFrame.infoBar:EnableMouse(true)
    TrackerFrame.infoBar:SetScript("OnEnter", function(self)
        -- Don't show tooltip if sort dropdown is open
        if QM.sortDropdown and QM.sortDropdown:IsShown() then return end

        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("|cFFFFD700" .. L["SESSION_STATISTICS"] .. "|r")
        GameTooltip:AddLine(" ")

        -- XP info
        local xpPerHour = QM:GetXPPerHour()
        local ttl = QM:FormatTimeToLevel()
        local currentXP = UnitXP("player")
        local maxXP = UnitXPMax("player")
        local xpRemaining = maxXP - currentXP
        GameTooltip:AddDoubleLine(L["CURRENT_XP"], string.format("|cFF00FF00%s / %s|r", QM:FormatNumber(currentXP), QM:FormatNumber(maxXP)), 1, 1, 1)
        GameTooltip:AddDoubleLine(L["XP_REMAINING"], string.format("|cFFFFFFFF%s|r", QM:FormatNumber(xpRemaining)), 1, 1, 1)
        GameTooltip:AddDoubleLine(L["XP_PER_HOUR_LABEL"], string.format("|cFF00FF00%s|r", QM:FormatNumber(xpPerHour)), 1, 1, 1)
        GameTooltip:AddDoubleLine(L["TIME_TO_LEVEL"], "|cFFFFD700" .. ttl .. "|r", 1, 1, 1)

        -- Session time
        local sessionTime = GetTime() - (QM.sessionStartTime or GetTime())
        GameTooltip:AddDoubleLine(L["SESSION_TIME"], "|cFF88CCFF" .. QM:FormatPlayTime(sessionTime) .. "|r", 1, 1, 1)

        -- Rested XP info
        if QM.db.profile.restedXP and QM.db.profile.restedXP.enabled then
            local restedInfo = QM:GetRestedXPInfo()
            if restedInfo and restedInfo.isRested then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cFF4169E1" .. L["RESTED_XP"] .. "|r")
                GameTooltip:AddDoubleLine(L["RESTED_AMOUNT"], string.format("|cFF4169E1%s|r", QM:FormatNumber(restedInfo.amount)), 1, 1, 1)
                GameTooltip:AddDoubleLine(L["RESTED_BUBBLES"], string.format("|cFF4169E1%.1f|r", restedInfo.bubbles), 1, 1, 1)
                GameTooltip:AddDoubleLine(L["BONUS_XP"], "|cFF00FF00" .. L["BONUS_UNTIL_DEPLETED"] .. "|r", 1, 1, 1)
            end
        end

        -- Level time info
        if QM.db.profile.levelTime and QM.db.profile.levelTime.enabled then
            local currentTime = QM:GetCurrentLevelTime()
            local avgTime = QM:GetAverageLevelTime()
            if currentTime then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cFF00FF00" .. L["LEVEL_TIME"] .. "|r")
                GameTooltip:AddDoubleLine(L["CURRENT_LEVEL_LABEL"], "|cFFFFFFFF" .. QM:FormatLevelTime(currentTime) .. "|r", 1, 1, 1)
                if avgTime then
                    GameTooltip:AddDoubleLine(L["AVERAGE_PER_LEVEL"], "|cFF888888" .. QM:FormatLevelTime(avgTime) .. "|r", 1, 1, 1)
                end
            end
        end

        -- Zone progress
        local zoneName = GetRealZoneText() or L["UNKNOWN"]
        local completed, total = QM:GetZoneProgress(zoneName)
        if total > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(zoneName .. " " .. L["PROGRESS"], string.format("|cFFFFD700%d/%d|r", completed, total), 1, 1, 1)
        end

        -- Reminders status
        if QM.db.profile.reminders and QM.db.profile.reminders.enabled then
            local freeSlots, totalSlots = QM:GetBagSpaceInfo()
            local minDura, avgDura = QM:GetDurabilityInfo()
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFFFF8800" .. L["STATUS"] .. "|r")
            local bagColor = freeSlots <= 4 and "|cFFFF4444" or "|cFF00FF00"
            GameTooltip:AddDoubleLine(L["BAG_SPACE"], string.format("%s%d/%d " .. L["FREE"] .. "|r", bagColor, freeSlots, totalSlots), 1, 1, 1)
            local duraColor = minDura <= 25 and "|cFFFF4444" or "|cFF00FF00"
            GameTooltip:AddDoubleLine(L["DURABILITY"], string.format("%s%d%%|r (" .. L["LOWEST"] .. ")", duraColor, minDura), 1, 1, 1)
        end

        -- Reputation tracking
        if QM.db.profile.reputation and QM.db.profile.reputation.enabled then
            local reps = QM:GetTrackedReputations()
            if #reps > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cFFFFFFFF" .. L["TRACKED_REPUTATIONS"] .. "|r")
                for _, rep in ipairs(reps) do
                    local standingColor = QM:GetStandingColor(rep.standingId)
                    GameTooltip:AddDoubleLine(rep.name, string.format("%s%s|r (%d/%d)", standingColor, rep.standing, rep.current, rep.max), 1, 1, 1)
                end
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF888888" .. L["CLICK_TO_RESET_XP"] .. "|r")
        GameTooltip:Show()
    end)
    TrackerFrame.infoBar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    TrackerFrame.infoBar:SetScript("OnMouseUp", function()
        QM:ResetXPTracker()
    end)

    -- Scroll frame (directly below infoBar)
    TrackerFrame.scrollFrame = CreateFrame("ScrollFrame", nil, TrackerFrame, "UIPanelScrollFrameTemplate")
    TrackerFrame.scrollFrame:SetPoint("TOPLEFT", TrackerFrame.infoBar, "BOTTOMLEFT", 2, -2)
    TrackerFrame.scrollFrame:SetPoint("BOTTOMRIGHT", TrackerFrame, "BOTTOMRIGHT", -18, 4)

    -- Store reference to scrollbar for auto-hide
    TrackerFrame.scrollBar = TrackerFrame.scrollFrame.ScrollBar
    if TrackerFrame.scrollBar then
        TrackerFrame.scrollBar:SetAlpha(0)  -- Hidden by default
    end

    TrackerFrame.content = CreateFrame("Frame", nil, TrackerFrame.scrollFrame)
    TrackerFrame.content:SetSize(TrackerFrame.scrollFrame:GetWidth(), 1)
    TrackerFrame.scrollFrame:SetScrollChild(TrackerFrame.content)

    -- Drag
    TrackerFrame:SetScript("OnDragStart", function(s)
        if not QM.db.profile.lockFrames then s:StartMoving() end
    end)
    TrackerFrame:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local p, _, _, x, y = s:GetPoint()
        QM.db.profile.tracker.point = p
        QM.db.profile.tracker.x = x
        QM.db.profile.tracker.y = y
    end)

    -- Resize (bounds relative to screen)
    TrackerFrame:SetResizable(true)
    local maxW = math.min(350, screenWidth * 0.3)
    local maxH = math.min(500, screenHeight * 0.5)
    TrackerFrame:SetResizeBounds(180, 100, maxW, maxH)

    local resizeBtn = CreateFrame("Button", nil, TrackerFrame)
    resizeBtn:SetSize(20, 20)  -- Larger clickable area
    resizeBtn:SetPoint("BOTTOMRIGHT", 2, -2)  -- Extend outside frame slightly for easier clicking
    resizeBtn.tex = resizeBtn:CreateTexture(nil, "ARTWORK")
    resizeBtn.tex:SetSize(16, 16)
    resizeBtn.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeBtn.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn.tex:SetAlpha(0.4)
    resizeBtn:SetScript("OnEnter", function(s)
        s.tex:SetAlpha(1)
        s.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    end)
    resizeBtn:SetScript("OnLeave", function(s)
        s.tex:SetAlpha(0.4)
        s.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    end)
    resizeBtn:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" and not QM.db.profile.lockFrames then
            TrackerFrame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeBtn:SetScript("OnMouseUp", function()
        TrackerFrame:StopMovingOrSizing()
        local newWidth = TrackerFrame:GetWidth()
        local newHeight = TrackerFrame:GetHeight()
        QM.db.profile.tracker.width = newWidth
        QM.db.profile.tracker.height = newHeight

        -- Full resize update
        QM:UpdateTrackerLayout(newWidth, newHeight)

        -- Refresh tracker display
        QM:UpdateTracker()
    end)
    TrackerFrame.resizeButton = resizeBtn

    -- Live resize updates for smooth feedback
    TrackerFrame:SetScript("OnSizeChanged", function(self, width, height)
        QM:UpdateTrackerLayout(width, height)
    end)

    QM.TrackerFrame = TrackerFrame
    TrackerFrame.minimized = false

    -- Distance and info update timer (reduced frequency for CPU savings)
    TrackerFrame.lastDistanceUpdate = 0
    TrackerFrame.lastInfoUpdate = 0
    TrackerFrame.lastTimerUpdate = 0
    TrackerFrame:SetScript("OnUpdate", function(self, elapsed)
        self.lastDistanceUpdate = self.lastDistanceUpdate + elapsed
        self.lastInfoUpdate = self.lastInfoUpdate + elapsed
        self.lastTimerUpdate = self.lastTimerUpdate + elapsed

        -- Update distances every 3 seconds (was 1.0 - huge CPU savings)
        if self.lastDistanceUpdate >= 3.0 then
            self.lastDistanceUpdate = 0
            QM:UpdateQuestDistances()
        end

        -- Update quest timers every 1 second
        if self.lastTimerUpdate >= 1.0 then
            self.lastTimerUpdate = 0
            QM:UpdateQuestTimerDisplays()
        end

        -- Update info bar every 10 seconds
        if self.lastInfoUpdate >= 10.0 then
            self.lastInfoUpdate = 0
            QM:UpdateInfoBar()
        end
    end)

    self:InitializeFramePools()
    self:UpdateTrackerVisibility()
end

-- ============================================================================
-- Distance Updates (continuous)
-- ============================================================================

function QM:UpdateQuestDistances()
    if not TrackerFrame or not TrackerFrame:IsShown() then return end

    -- Check both showDistance boolean and distanceDisplay string setting
    local showDist = QM.db.profile.tracker.showDistance
    local distDisplay = QM.db.profile.tracker.distanceDisplay or "quest"
    if showDist == false or distDisplay == "none" then
        -- Fast path: hide all distances, don't calculate anything
        for _, f in ipairs(questFramePool) do
            if f.inUse and f.distance then
                f.distance:Hide()
            end
        end
        return
    end

    local hideClose = QM.db.profile.tracker.hideDistanceWhenClose
    local compactNums = QM.db.profile.tracker.compactNumbers

    for _, f in ipairs(questFramePool) do
        if f.inUse and f.questData and f.distance then
            local dist
            if f.questData.isComplete then
                -- Use cached turn-in distance from GetCompletedQuests
                dist = f.questData.turnInDistance
                -- Recalculate if not cached
                if not dist or dist == 999999 then
                    local locs = QM.DB and QM.DB:GetQuestTurnInLocations(f.questData.id)
                    if locs and locs[1] then
                        dist = self:GetDistanceToPoint(locs[1].x, locs[1].y, locs[1].mapId)
                    end
                end
            else
                -- Use cached objective distance from GetIncompleteQuests
                dist = f.questData.objectiveDistance
                -- Only recalculate if not cached
                if not dist or dist == 999999 then
                    dist = self:GetNearestObjectiveDistance(f.questData.id)
                end
            end

            if dist and dist < 99999 then
                if hideClose and dist < 100 then
                    f.distance:SetText("")
                    f.distance:Hide()
                else
                    local r, g, b = QM.Tracker:GetDistanceColor(dist)
                    local distText
                    if compactNums then
                        distText = QM.Tracker:FormatDistanceCompact(dist)
                    else
                        distText = QM.Tracker:FormatDistanceFull(dist)
                    end
                    f.distance:SetText(distText)
                    f.distance:SetTextColor(r, g, b)
                    f.distance:Show()
                end
            else
                f.distance:SetText("")
                f.distance:Hide()
            end
        end
    end
end

-- ============================================================================
-- Frame Pools
-- ============================================================================

function QM:InitializeFramePools()
    questFramePool = {}
    objectiveFramePool = {}
    zoneHeaderPool = {}
end

local function GetOrCreateFrame(pool, createFunc)
    for _, f in ipairs(pool) do
        if not f.inUse then
            f.inUse = true
            f:Show()
            return f
        end
    end
    local f = createFunc()
    f.inUse = true
    table.insert(pool, f)
    return f
end

local function ReleaseFrame(f)
    f.inUse = false
    -- Protected frames (quest frames with item buttons) cannot be hidden/moved in combat
    if f:IsProtected() and InCombatLockdown() then
        return
    end
    f:Hide()
    f:ClearAllPoints()
end

function QM:GetZoneHeaderFrame()
    return GetOrCreateFrame(zoneHeaderPool, function() return self:CreateZoneHeaderFrame() end)
end

function QM:GetQuestFrame()
    return GetOrCreateFrame(questFramePool, function() return self:CreateQuestFrame() end)
end

function QM:GetObjectiveFrame()
    return GetOrCreateFrame(objectiveFramePool, function() return self:CreateObjectiveFrame() end)
end

function QM:CreateZoneHeaderFrame()
    -- Use a unique global name for each zone header Button for reliable click handling
    local btnName = "QuestMasterZoneHeader" .. (QM.zoneHeaderCounter or 0)
    QM.zoneHeaderCounter = (QM.zoneHeaderCounter or 0) + 1

    local f = CreateFrame("Button", btnName, TrackerFrame.content, "BackdropTemplate")
    f:SetSize(TrackerFrame.content:GetWidth() - 2, ZONE_HEADER_HEIGHT)
    f:EnableMouse(true)
    f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    f:SetBackdropColor(DESIGN.bgMedium[1], DESIGN.bgMedium[2], DESIGN.bgMedium[3], 0.9)

    -- Register for all click types to ensure MoP Classic compatibility
    if f.RegisterForClicks then
        f:RegisterForClicks("AnyUp", "AnyDown")
    end

    -- Left accent bar
    f.accent = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.accent:SetWidth(2)
    f.accent:SetPoint("TOPLEFT", 0, 0)
    f.accent:SetPoint("BOTTOMLEFT", 0, 0)
    f.accent:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.7)

    -- Bottom separator
    f.separator = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.separator:SetHeight(1)
    f.separator:SetPoint("BOTTOMLEFT", 0, 0)
    f.separator:SetPoint("BOTTOMRIGHT", 0, 0)
    f.separator:SetColorTexture(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.4)

    -- Collapse indicator (arrow style)
    f.collapse = f:CreateFontString(nil, "OVERLAY")
    f.collapse:SetFont("Fonts\\FRIZQT__.TTF", FONT_SMALL, "")
    f.collapse:SetPoint("LEFT", 6, 0)
    f.collapse:SetText("[-]")
    f.collapse:SetTextColor(DESIGN.textMuted[1], DESIGN.textMuted[2], DESIGN.textMuted[3])

    -- Zone name
    f.name = f:CreateFontString(nil, "OVERLAY")
    f.name:SetFont("Fonts\\FRIZQT__.TTF", FONT_ZONE, "")
    f.name:SetPoint("LEFT", f.collapse, "RIGHT", 5, 0)
    f.name:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])

    -- Quest count badge
    f.count = f:CreateFontString(nil, "OVERLAY")
    f.count:SetFont("Fonts\\FRIZQT__.TTF", FONT_SMALL, "")
    f.count:SetPoint("RIGHT", -6, 0)
    f.count:SetTextColor(DESIGN.textMuted[1], DESIGN.textMuted[2], DESIGN.textMuted[3])

    -- Toggle collapse helper (used by multiple handlers for reliability)
    local function ToggleZoneCollapse(frame)
        local zone = frame.zoneName
        if not zone then return end
        -- Debounce: prevent double-firing from OnClick + OnMouseUp
        local now = GetTime()
        if frame._lastToggle and (now - frame._lastToggle) < 0.3 then return end
        frame._lastToggle = now
        collapsedZones[zone] = not collapsedZones[zone]
        local ok, err = pcall(QM.UpdateTracker, QM)
        if not ok and QM.DebugLog then
            QM:DebugLog("UpdateTracker error: " .. tostring(err))
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end

    -- Click anywhere on the bar to collapse/expand
    -- Use BOTH OnClick (for Button) and OnMouseDown (for Frame fallback)
    f:SetScript("OnClick", function(self) ToggleZoneCollapse(self) end)
    f:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then ToggleZoneCollapse(self) end
    end)

    f:SetScript("OnEnter", function(self)
        self:SetBackdropColor(DESIGN.bgLight[1], DESIGN.bgLight[2], DESIGN.bgLight[3], 1)
        self.name:SetTextColor(1, 0.9, 0.5)
        self.accent:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 1)
    end)
    f:SetScript("OnLeave", function(self)
        self:SetBackdropColor(DESIGN.bgMedium[1], DESIGN.bgMedium[2], DESIGN.bgMedium[3], 0.9)
        self.name:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
        self.accent:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.7)
    end)

    return f
end

function QM:CreateQuestFrame()
    local f = CreateFrame("Button", nil, TrackerFrame.content, "BackdropTemplate")
    f:SetSize(TrackerFrame.content:GetWidth() - 4, QUEST_HEIGHT)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Subtle background for hover effect
    f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    f:SetBackdropColor(0, 0, 0, 0)

    -- Collapse button (arrow style)
    f.collapseBtn = CreateFrame("Button", nil, f)
    f.collapseBtn:SetSize(12, 12)
    f.collapseBtn:RegisterForClicks("LeftButtonUp")
    f.collapseBtn:SetPoint("LEFT", 4, 0)
    f.collapseBtn.text = f.collapseBtn:CreateFontString(nil, "OVERLAY")
    f.collapseBtn.text:SetFont("Fonts\\FRIZQT__.TTF", FONT_SMALL - 1, "")
    f.collapseBtn.text:SetAllPoints()
    f.collapseBtn.text:SetText("[-]")
    f.collapseBtn.text:SetTextColor(DESIGN.textMuted[1], DESIGN.textMuted[2], DESIGN.textMuted[3])
    f.collapseBtn:SetScript("OnClick", function(self)
        local qid = self:GetParent().questId
        if qid then
            collapsedQuests[qid] = not collapsedQuests[qid]
            local ok, err = pcall(QM.UpdateTracker, QM)
            if not ok and QM.DebugLog then QM:DebugLog("UpdateTracker error: " .. tostring(err)) end
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    f.collapseBtn:SetScript("OnEnter", function(self)
        self.text:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
    end)
    f.collapseBtn:SetScript("OnLeave", function(self)
        self.text:SetTextColor(DESIGN.textMuted[1], DESIGN.textMuted[2], DESIGN.textMuted[3])
    end)

    -- Status dot (cleaner circle)
    f.status = f:CreateTexture(nil, "ARTWORK")
    f.status:SetSize(6, 6)
    f.status:SetPoint("LEFT", f.collapseBtn, "RIGHT", 3, 0)
    f.status:SetTexture("Interface\\COMMON\\Indicator-Yellow")

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY")
    f.title:SetFont("Fonts\\FRIZQT__.TTF", FONT_QUEST, "")
    f.title:SetPoint("LEFT", f.status, "RIGHT", 4, 0)
    f.title:SetPoint("RIGHT", f, "RIGHT", -55, 0) -- More space for distance/icons
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)
    f.title:SetTextColor(DESIGN.textWhite[1], DESIGN.textWhite[2], DESIGN.textWhite[3])

    -- Distance text
    f.distance = f:CreateFontString(nil, "OVERLAY")
    f.distance:SetFont("Fonts\\FRIZQT__.TTF", FONT_SMALL, "")
    f.distance:SetPoint("RIGHT", -4, 0)
    f.distance:SetWidth(50) -- Fixed width to prevent overlap
    f.distance:SetJustifyH("RIGHT")
    f.distance:SetTextColor(unpack(COLORS.distance))

    -- Highlight (subtle gold tint)
    f.highlight = f:CreateTexture(nil, "HIGHLIGHT")
    f.highlight:SetAllPoints()
    f.highlight:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.05)

    -- Selected/Active indicator (shown when waypoint is set for this quest)
    f.selectedGlow = f:CreateTexture(nil, "BACKGROUND")
    f.selectedGlow:SetAllPoints()
    f.selectedGlow:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.12)
    f.selectedGlow:Hide()

    -- Turn-in indicator (gold question mark for completed quests)
    f.turnInIcon = f:CreateTexture(nil, "ARTWORK")
    f.turnInIcon:SetSize(12, 12)
    f.turnInIcon:SetPoint("RIGHT", f.distance, "LEFT", -2, 0)
    f.turnInIcon:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
    f.turnInIcon:SetVertexColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
    f.turnInIcon:Hide()

    -- Complete text badge
    f.completeText = f:CreateFontString(nil, "OVERLAY")
    f.completeText:SetFont("Fonts\\FRIZQT__.TTF", FONT_SMALL - 1, "")
    f.completeText:SetPoint("RIGHT", f.turnInIcon, "LEFT", -2, 0)
    f.completeText:SetText("|cFF" .. string.format("%02X%02X%02X", DESIGN.success[1]*255, DESIGN.success[2]*255, DESIGN.success[3]*255) .. L["COMPLETE"] .. "|r")
    f.completeText:Hide()

    -- Quest Timer text (below title, only visible in detailed mode or tooltip)
    f.timerText = f:CreateFontString(nil, "OVERLAY")
    f.timerText:SetFont("Fonts\\FRIZQT__.TTF", FONT_SMALL, "")
    f.timerText:SetPoint("LEFT", f.status, "RIGHT", 4, -8)
    f.timerText:SetTextColor(DESIGN.textMuted[1], DESIGN.textMuted[2], DESIGN.textMuted[3])
    f.timerText:Hide()

    -- Note icon (shown when quest has a note)
    f.noteIcon = f:CreateTexture(nil, "ARTWORK")
    f.noteIcon:SetSize(10, 10)
    f.noteIcon:SetPoint("LEFT", f.status, "RIGHT", 2, 0)
    f.noteIcon:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    f.noteIcon:SetVertexColor(0.4, 0.7, 1)
    f.noteIcon:Hide()

    -- Quest Item Button (SecureActionButton for usable quest items)
    -- Using unique global name for each button to ensure proper functionality
    local itemBtnName = "QuestMasterItemBtn" .. (QM.itemButtonCounter or 0)
    QM.itemButtonCounter = (QM.itemButtonCounter or 0) + 1
    f.itemButton = CreateFrame("Button", itemBtnName, f, "SecureActionButtonTemplate")
    f.itemButton:SetSize(20, 20)
    f.itemButton:SetPoint("RIGHT", f, "RIGHT", -58, 0)
    f.itemButton:SetAttribute("type", "item")
    f.itemButton:RegisterForClicks("AnyUp")

    -- Item button background
    f.itemButton.bg = f.itemButton:CreateTexture(nil, "BACKGROUND")
    f.itemButton.bg:SetAllPoints()
    f.itemButton.bg:SetColorTexture(0, 0, 0, 0.6)

    -- Item button icon
    f.itemButton.icon = f.itemButton:CreateTexture(nil, "ARTWORK")
    f.itemButton.icon:SetSize(18, 18)
    f.itemButton.icon:SetPoint("CENTER")
    f.itemButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Item button border (highlight on hover)
    f.itemButton.border = f.itemButton:CreateTexture(nil, "OVERLAY")
    f.itemButton.border:SetSize(22, 22)
    f.itemButton.border:SetPoint("CENTER")
    f.itemButton.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    f.itemButton.border:SetBlendMode("ADD")
    f.itemButton.border:SetAlpha(0)

    -- Cooldown frame for item cooldowns
    f.itemButton.cooldown = CreateFrame("Cooldown", nil, f.itemButton, "CooldownFrameTemplate")
    f.itemButton.cooldown:SetAllPoints(f.itemButton.icon)
    f.itemButton.cooldown:SetDrawEdge(false)
    f.itemButton.cooldown:SetHideCountdownNumbers(false)

    f.itemButton:SetScript("OnEnter", function(self)
        self.border:SetAlpha(0.8)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFF00FF00" .. L["CLICK_TO_USE_ITEM"] .. "|r")
            GameTooltip:Show()
        end
    end)
    f.itemButton:SetScript("OnLeave", function(self)
        self.border:SetAlpha(0)
        GameTooltip:Hide()
    end)
    f.itemButton:Hide()

    f:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            local q = self.questData
            if q then
                if IsShiftKeyDown() then
                    -- Shift+Left Click = Link quest in chat
                    QM:LinkQuestToChat(q.id)
                else
                    -- Left Click = Set waypoint
                    QM:SetWaypointForQuest(q.id)
                end
            end
        elseif btn == "RightButton" then
            QM:ShowQuestContextMenu(self)
        end
    end)

    f:SetScript("OnEnter", function(self)
        if self.questData then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("quest:" .. self.questData.id)

            -- Add quest timer to tooltip
            if QM.db.profile.questTimer.enabled and QM.db.profile.questTimer.showInTooltip then
                local duration = QM:GetQuestDuration(self.questData.id)
                if duration then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddDoubleLine(L["TIME_ON_QUEST"], "|cFFFFD700" .. QM:FormatQuestDuration(duration) .. "|r", 1, 1, 1)
                end
            end

            -- Add distance info to tooltip
            local dist = QM:GetNearestObjectiveDistance(self.questData.id)
            if dist and dist < 99999 then
                GameTooltip:AddLine(" ")
                local distLabel = L["DISTANCE_TO_OBJECTIVE"]
                local distText = string.format("|cFFAAD4FF%s:|r %d %s",
                    distLabel,
                    math.floor(dist),
                    L["YARDS"])
                GameTooltip:AddLine(distText)
            end
            -- Add quest note if present
            local note = QM:GetQuestNote(self.questData.id)
            if note and note ~= "" then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cFF88CCFF" .. L["NOTE"] .. "|r")
                GameTooltip:AddLine("|cFFFFFFFF" .. note .. "|r", 1, 1, 1, true)
            end

            -- Add helpful hint about click
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFF888888" .. L["CLICK_SET_WAYPOINT"] .. "|r")
            GameTooltip:AddLine("|cFF888888" .. L["CLICK_LINK_QUEST"] .. "|r")
            GameTooltip:AddLine("|cFF888888" .. L["CLICK_MORE_OPTIONS"] .. "|r")
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return f
end

function QM:CreateObjectiveFrame()
    local f = CreateFrame("Button", nil, TrackerFrame.content)
    f:SetSize(TrackerFrame.content:GetWidth() - 8, OBJECTIVE_HEIGHT)

    -- Bullet
    f.bullet = f:CreateFontString(nil, "OVERLAY")
    f.bullet:SetFont("Fonts\\FRIZQT__.TTF", FONT_SMALL, "")
    f.bullet:SetPoint("LEFT", 20, 0)
    f.bullet:SetText("-")
    f.bullet:SetTextColor(DESIGN.textMuted[1], DESIGN.textMuted[2], DESIGN.textMuted[3])

    -- Text
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetFont("Fonts\\FRIZQT__.TTF", FONT_OBJECTIVE, "")
    f.text:SetPoint("LEFT", f.bullet, "RIGHT", 4, 0)
    f.text:SetPoint("RIGHT", f, "RIGHT", -50, 0)  -- More space for progress numbers
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(false)
    f.text:SetTextColor(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3])

    -- Progress (e.g. "18/30")
    f.progress = f:CreateFontString(nil, "OVERLAY")
    f.progress:SetFont("Fonts\\FRIZQT__.TTF", FONT_SMALL, "")
    f.progress:SetPoint("RIGHT", -4, 0)
    f.progress:SetWidth(44)  -- Enough for "999/999"
    f.progress:SetJustifyH("RIGHT")

    -- Progress bar (improved styling)
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetSize(f:GetWidth() - 28, 2)
    f.bar:SetPoint("BOTTOMLEFT", 20, 1)
    f.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    f.bar:SetStatusBarColor(DESIGN.success[1], DESIGN.success[2], DESIGN.success[3], 0.7)
    f.bar:SetMinMaxValues(0, 1)
    f.bar:Hide()

    f.bar.bg = f.bar:CreateTexture(nil, "BACKGROUND")
    f.bar.bg:SetAllPoints()
    f.bar.bg:SetColorTexture(DESIGN.bgDarkest[1], DESIGN.bgDarkest[2], DESIGN.bgDarkest[3], 0.8)

    f:SetScript("OnClick", function(self)
        if self.objectiveData then
            QM:SetWaypointForObjective(self.questId, self.objectiveData.index)
        end
    end)

    f:SetScript("OnEnter", function(self)
        if self.objectiveData and not self.objectiveData.finished then
            self.text:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
        end
    end)
    f:SetScript("OnLeave", function(self)
        QM:UpdateObjectiveColor(self)
    end)

    return f
end

-- ============================================================================
-- Zone Helpers
-- ============================================================================

function QM:GetQuestZone(quest)
    if not quest then return L["UNKNOWN"], 0 end

    local dbQuest = QM.DB and QM.DB:GetQuest(quest.id)
    if dbQuest and dbQuest.startedBy and dbQuest.startedBy[1] then
        local npcId = dbQuest.startedBy[1][1]
        if npcId and QM.DB then
            local spawns = QM.DB:GetNPCSpawnLocations(npcId)
            if spawns and spawns[1] and spawns[1].mapId then
                local mapId = spawns[1].mapId
                local name = ZONE_NAMES[mapId]
                if not name and C_Map.GetMapInfo(mapId) then
                    name = C_Map.GetMapInfo(mapId).name
                end
                return name or L["UNKNOWN"], mapId
            end
        end
    end

    local mapId = C_Map.GetBestMapForUnit("player")
    if mapId then
        local name = ZONE_NAMES[mapId]
        if not name and C_Map.GetMapInfo(mapId) then
            name = C_Map.GetMapInfo(mapId).name
        end
        return name or L["UNKNOWN"], mapId
    end

    return L["UNKNOWN"], 0
end

-- Reusable tables for quest sorting (avoid GC pressure)
local _incompleteQuests = {}
local _completedQuests = {}

-- Distance cache: only recalculate distances every DIST_RECALC_INTERVAL seconds
local DIST_RECALC_INTERVAL = 2.0
local lastDistRecalcTime = 0
local questDistCache = {}  -- [questId] = distance

-- Pre-defined sort comparators (avoid creating closures every call)
local function SortByLevel(a, b)
    local lvlA = tonumber(a.level) or 0
    local lvlB = tonumber(b.level) or 0
    if lvlA ~= lvlB then return lvlA < lvlB end
    return (a.title or "") < (b.title or "")
end

local function SortByObjDistance(a, b)
    local distA = tonumber(a.objectiveDistance) or 999999
    local distB = tonumber(b.objectiveDistance) or 999999
    if distA ~= distB then return distA < distB end
    return (a.title or "") < (b.title or "")
end

local function SortByTurnInDistance(a, b)
    local distA = tonumber(a.turnInDistance) or 999999
    local distB = tonumber(b.turnInDistance) or 999999
    if distA ~= distB then return distA < distB end
    return (a.title or "") < (b.title or "")
end

function QM:GetIncompleteQuests()
    -- Reuse table, clear it
    local quests = _incompleteQuests
    wipe(quests)

    local filter = QM.db and QM.db.profile and QM.db.profile.filter
    local onlyWatched = QM.db and QM.db.profile and QM.db.profile.tracker and QM.db.profile.tracker.onlyShowWatched
    local zoneFilter = QM.db and QM.db.profile and QM.db.profile.tracker and QM.db.profile.tracker.zoneFilter
    local currentZone, currentSubZone
    if zoneFilter then
        currentZone = GetZoneText() or ""
        currentSubZone = GetSubZoneText() or ""
    end

    -- Only recalculate distances every DIST_RECALC_INTERVAL seconds
    local now = GetTime()
    local needDistRecalc = (now - lastDistRecalcTime) >= DIST_RECALC_INTERVAL
    if needDistRecalc then
        lastDistRecalcTime = now
    end

    for _, quest in pairs(self.activeQuests or {}) do
        -- Check filters (optional)
        local isTracked = true
        if filter then
            if quest.isRaid and not filter.showRaid then
                isTracked = false
            elseif quest.isDungeon and not filter.showDungeon then
                isTracked = false
            elseif quest.isGroup and not filter.showGroup then
                isTracked = false
            end
        end

        -- Check if quest is watched in Classic (use logIndex)
        if isTracked and onlyWatched and quest.logIndex and IsQuestWatched then
            if not IsQuestWatched(quest.logIndex) then
                isTracked = false
            end
        end

        -- Zone filter: Only show quests for current zone
        if isTracked and zoneFilter then
            if quest.zone and quest.zone ~= "" and quest.zone ~= currentZone then
                if quest.zone ~= currentSubZone then
                    isTracked = false
                end
            end
        end

        -- Exclude completed quests - they go in separate section
        if isTracked and not quest.isComplete then
            local dist

            if needDistRecalc then
                -- Full distance recalculation
                dist = 999999

                if QM.DB then
                    -- First try: Quest objective locations
                    local objLocs = self:GetQuestObjectiveLocationsFixed(quest.id)
                    if objLocs then
                        for _, objLocList in pairs(objLocs) do
                            if objLocList then
                                for _, loc in ipairs(objLocList) do
                                    local d = self:GetDistanceToPoint(loc.x, loc.y, loc.mapId)
                                    if d and d < dist then dist = d end
                                end
                            end
                        end
                    end

                    -- Fallback: Quest start NPC location
                    if dist == 999999 then
                        local dbQuest = QM.DB:GetQuest(quest.id)
                        if dbQuest and dbQuest.starters and dbQuest.starters.npcs and dbQuest.starters.npcs[1] then
                            local npcId = dbQuest.starters.npcs[1]
                            local spawns = QM.DB:GetNPCSpawnLocations(npcId)
                            if spawns and spawns[1] then
                                local d = self:GetDistanceToPoint(spawns[1].x, spawns[1].y, spawns[1].mapId)
                                if d then dist = d end
                            end
                        end
                    end

                    -- Last fallback: Turn-in NPC location
                    if dist == 999999 then
                        local turnInLocs = QM.DB:GetQuestTurnInLocations(quest.id)
                        if turnInLocs and turnInLocs[1] then
                            local d = self:GetDistanceToPoint(turnInLocs[1].x, turnInLocs[1].y, turnInLocs[1].mapId)
                            if d then dist = d end
                        end
                    end
                end

                questDistCache[quest.id] = dist
            else
                -- Use cached distance
                dist = questDistCache[quest.id] or quest.objectiveDistance or 999999
            end

            quest.objectiveDistance = dist
            quests[#quests + 1] = quest
        end
    end

    -- Get sort preference (with safe access)
    local sortBy = (QM.db and QM.db.profile and QM.db.profile.tracker and QM.db.profile.tracker.sortBy) or "distance"

    if sortBy == "level" then
        table.sort(quests, SortByLevel)
    else
        table.sort(quests, SortByObjDistance)
    end

    return quests
end

-- Get completed quests sorted based on sort preference
function QM:GetCompletedQuests()
    -- Reuse table, clear it
    local completed = _completedQuests
    wipe(completed)

    local zoneFilter = QM.db and QM.db.profile and QM.db.profile.tracker and QM.db.profile.tracker.zoneFilter
    local currentZone, currentSubZone
    if zoneFilter then
        currentZone = GetZoneText() or ""
        currentSubZone = GetSubZoneText() or ""
    end

    -- Use same distance recalc interval as incomplete quests
    local now = GetTime()
    local needDistRecalc = (now - lastDistRecalcTime) < 0.5  -- Recalc was recent, data is fresh

    for _, quest in pairs(self.activeQuests or {}) do
        if quest.isComplete then
            -- Zone filter: Only show quests for current zone (if enabled)
            local passesZoneFilter = true
            if zoneFilter then
                if quest.zone and quest.zone ~= "" and quest.zone ~= currentZone and quest.zone ~= currentSubZone then
                    passesZoneFilter = false
                end
            end

            if passesZoneFilter then
                local turnInDist

                if needDistRecalc or not quest.turnInDistance then
                    -- Calculate turn-in distance
                    turnInDist = 999999
                    if QM.DB then
                        local locs = QM.DB:GetQuestTurnInLocations(quest.id)
                        if locs and locs[1] then
                            local d = self:GetDistanceToPoint(locs[1].x, locs[1].y, locs[1].mapId)
                            if d then turnInDist = d end
                        end
                    end
                else
                    turnInDist = quest.turnInDistance
                end

                quest.turnInDistance = turnInDist
                completed[#completed + 1] = quest
            end
        end
    end

    -- Get sort preference (with safe access)
    local sortBy = (QM.db and QM.db.profile and QM.db.profile.tracker and QM.db.profile.tracker.sortBy) or "distance"

    if sortBy == "level" then
        table.sort(completed, SortByLevel)
    else
        table.sort(completed, SortByTurnInDistance)
    end

    return completed
end

-- ============================================================================
-- Tracker Updates
-- ============================================================================

function QM:UpdateTracker()
    if not TrackerFrame or not TrackerFrame.content then return end
    if not QM.db.profile.tracker.enabled then
        if not InCombatLockdown() then
            TrackerFrame:Hide()
        end
        return
    end

    -- Defer tracker updates during combat when protected frames are involved
    if InCombatLockdown() and TrackerFrame:IsProtected() then
        -- Schedule update for when combat ends
        if not self.pendingTrackerUpdate then
            self.pendingTrackerUpdate = true
            local frame = CreateFrame("Frame")
            frame:RegisterEvent("PLAYER_REGEN_ENABLED")
            frame:SetScript("OnEvent", function(f)
                f:UnregisterAllEvents()
                f:SetScript("OnEvent", nil)
                self.pendingTrackerUpdate = false
                self:UpdateTracker()
            end)
        end
        return
    end

    -- Update background alpha and border from settings
    UpdateBackgroundAlpha()
    UpdateBorderVisibility()
    TrackerFrame:SetBackdropColor(COLORS.background[1], COLORS.background[2], COLORS.background[3], COLORS.background[4])

    -- Release frames
    for _, f in ipairs(zoneHeaderPool) do ReleaseFrame(f) end
    for _, f in ipairs(questFramePool) do ReleaseFrame(f) end
    for _, f in ipairs(objectiveFramePool) do ReleaseFrame(f) end

    -- Get display mode settings
    local displayMode = QM.db.profile.tracker.displayMode or "normal"
    local questHeight = displayMode == "compact" and COMPACT_QUEST_HEIGHT or QUEST_HEIGHT
    local objectiveHeight = displayMode == "compact" and COMPACT_OBJECTIVE_HEIGHT or OBJECTIVE_HEIGHT
    local padding = displayMode == "compact" and COMPACT_PADDING or PADDING

    local incompleteQuests = self:GetIncompleteQuests()
    local completedQuests = self:GetCompletedQuests()
    local y = 0
    local total = 0
    local displayed = 0

    for _ in pairs(self.activeQuests or {}) do total = total + 1 end

    TrackerFrame.header.count:SetText("(" .. total .. ")")

    -- Determine if quest timer adds extra height
    local timerExtraHeight = 0
    if QM.db.profile.questTimer.enabled and QM.db.profile.questTimer.showInTracker
       and displayMode ~= "compact" then
        timerExtraHeight = 10
    end

    -- Helper to render a single quest row
    local function RenderQuest(quest)

        local isQuestCollapsed = collapsedQuests[quest.id]

        -- Quest frame
        local qf = self:GetQuestFrame()
        qf:SetParent(TrackerFrame.content)
        qf:SetPoint("TOPLEFT", 2, -y)
        qf:SetWidth(TrackerFrame.content:GetWidth() - 4)
        local effectiveHeight = questHeight
        -- Add extra height for timer row (only for active quests with timer visible)
        if timerExtraHeight > 0 and not quest.isComplete then
            local duration = QM:GetQuestDuration(quest.id)
            if duration then
                effectiveHeight = questHeight + timerExtraHeight
            end
        end
        qf:SetHeight(effectiveHeight)
        qf.questData = quest
        qf.questId = quest.id

        -- Update quest display
        self:UpdateQuestFrame(qf, quest, isQuestCollapsed)

        y = y + effectiveHeight
        displayed = displayed + 1

        -- Objectives (if not collapsed)
        if not isQuestCollapsed then
            for i, obj in ipairs(quest.objectives) do
                if QM.db.profile.tracker.collapseCompleted and obj.finished then
                    -- skip completed objectives
                else
                    local of = self:GetObjectiveFrame()
                    of:SetParent(TrackerFrame.content)
                    of:SetPoint("TOPLEFT", 4, -y)
                    of:SetWidth(TrackerFrame.content:GetWidth() - 8)
                    of:SetHeight(objectiveHeight)
                    of.questId = quest.id
                    of.objectiveData = obj
                    of.objectiveData.index = i

                    self:UpdateObjectiveFrame(of, obj)
                    y = y + objectiveHeight
                end
            end

            -- Show party member progress below objectives
            if QM.db.profile.partySync and QM.db.profile.partySync.enabled
               and QM.db.profile.partySync.showInTracker then
                local partyProgress = QM:GetPartyQuestProgress(quest.id)
                for _, member in ipairs(partyProgress) do
                    local pf = self:GetObjectiveFrame()
                    pf:SetParent(TrackerFrame.content)
                    pf:SetPoint("TOPLEFT", 4, -y)
                    pf:SetWidth(TrackerFrame.content:GetWidth() - 8)
                    pf:SetHeight(objectiveHeight)

                    -- Build party member status text
                    local statusText
                    if member.isComplete then
                        statusText = "|cFF44FF44" .. member.name .. ": " .. L["COMPLETE"] .. "|r"
                    else
                        -- Show objective progress summary
                        local objParts = {}
                        for _, obj in ipairs(member.objectives) do
                            if obj.numNeeded > 0 then
                                local color = obj.finished and "44FF44" or "AAAAAA"
                                table.insert(objParts, string.format("|cFF%s%d/%d|r", color, obj.numGot, obj.numNeeded))
                            end
                        end
                        local progress = #objParts > 0 and table.concat(objParts, " ") or "..."
                        statusText = "|cFF88AAFF" .. member.name .. "|r |cFF666666" .. progress .. "|r"
                    end

                    if pf.bullet then
                        pf.bullet:SetText("")
                    end
                    if pf.text then
                        pf.text:SetFont("Fonts\\FRIZQT__.TTF", GetFontSize() - 2, "")
                        pf.text:SetText("  " .. statusText)
                    end
                    pf:Show()
                    y = y + objectiveHeight
                end
            end
        end

        y = y + padding
    end

    -- Separate dungeon/raid quests from normal quests (reuse tables)
    self._normalQuests = self._normalQuests or {}
    self._dungeonQuests = self._dungeonQuests or {}
    local normalQuests = self._normalQuests
    local dungeonQuests = self._dungeonQuests
    wipe(normalQuests)
    -- Clear dungeon quest sub-tables
    for k, v in pairs(dungeonQuests) do wipe(v) end
    local dungeonQuestCount = 0

    for _, quest in ipairs(incompleteQuests) do
        if quest.isDungeon or quest.isRaid then
            local dungeonName = QM:GetQuestDungeonName(quest.id)
            if not dungeonName then
                if quest.isRaid then
                    dungeonName = L["RAID_QUESTS"]
                else
                    dungeonName = L["DUNGEON_QUESTS"]
                end
            end
            if not dungeonQuests[dungeonName] then
                dungeonQuests[dungeonName] = {}
            end
            dungeonQuests[dungeonName][#dungeonQuests[dungeonName] + 1] = quest
            dungeonQuestCount = dungeonQuestCount + 1
        else
            table.insert(normalQuests, quest)
        end
    end

    -- ========== ACTIVE QUESTS SECTION (Incomplete - at top) ==========
    if #normalQuests > 0 then
        local isActiveCollapsed = collapsedZones["__ACTIVE__"]

        -- Active section header
        local zf = self:GetZoneHeaderFrame()
        zf:SetParent(TrackerFrame.content)
        zf:SetPoint("TOPLEFT", 1, -y)
        zf:SetWidth(TrackerFrame.content:GetWidth() - 2)
        zf.zoneName = "__ACTIVE__"
        zf.name:SetText("|cFFFFD700" .. L["ACTIVE_QUESTS"] .. "|r")
        zf.count:SetText("(" .. #normalQuests .. ")")
        zf.collapse:SetText(isActiveCollapsed and "[+]" or "[-]")

        y = y + ZONE_HEADER_HEIGHT + 1

        if not isActiveCollapsed then
            for _, quest in ipairs(normalQuests) do
                RenderQuest(quest)
            end
        end

        y = y + 4 -- Extra space after active section
    end

    -- Dungeon/raid and completed quests section

    -- ========== DUNGEON / RAID QUESTS SECTION ==========
    if dungeonQuestCount > 0 then
        for dungeonName, quests in pairs(dungeonQuests) do
            local sectionKey = "__DUNGEON_" .. dungeonName .. "__"
            local isDungeonCollapsed = collapsedZones[sectionKey]

            -- Dungeon section header
            local zf = self:GetZoneHeaderFrame()
            zf:SetParent(TrackerFrame.content)
            zf:SetPoint("TOPLEFT", 1, -y)
            zf:SetWidth(TrackerFrame.content:GetWidth() - 2)
            zf.zoneName = sectionKey

            -- Color-coded header: blue for dungeons, red for raids
            local isRaidSection = quests[1] and quests[1].isRaid
            if isRaidSection then
                zf.name:SetText("|cFFFF4444" .. dungeonName .. "|r")
                zf.accent:SetColorTexture(0.95, 0.35, 0.35, 0.7)
            else
                zf.name:SetText("|cFF44AAFF" .. dungeonName .. "|r")
                zf.accent:SetColorTexture(0.35, 0.65, 0.95, 0.7)
            end
            zf.count:SetText("(" .. #quests .. ")")
            zf.collapse:SetText(isDungeonCollapsed and "[+]" or "[-]")

            y = y + ZONE_HEADER_HEIGHT + 1

            if not isDungeonCollapsed then
                for _, quest in ipairs(quests) do
                    RenderQuest(quest)
                end
            end

            y = y + 4
        end
    end

    -- ========== READY FOR TURN-IN SECTION (Completed - at bottom) ==========
    if #completedQuests > 0 then
        local isCompletedCollapsed = collapsedZones["__COMPLETED__"]

        -- Completed section header
        local zf = self:GetZoneHeaderFrame()
        zf:SetParent(TrackerFrame.content)
        zf:SetPoint("TOPLEFT", 1, -y)
        zf:SetWidth(TrackerFrame.content:GetWidth() - 2)
        zf.zoneName = "__COMPLETED__"
        zf.name:SetText("|cFF00FF00" .. L["READY_FOR_TURNIN"] .. "|r")
        zf.count:SetText("(" .. #completedQuests .. ")")
        zf.collapse:SetText(isCompletedCollapsed and "[+]" or "[-]")

        y = y + ZONE_HEADER_HEIGHT + 1

        if not isCompletedCollapsed then
            for _, quest in ipairs(completedQuests) do
                local qf = self:GetQuestFrame()
                qf:SetParent(TrackerFrame.content)
                qf:SetPoint("TOPLEFT", 2, -y)
                qf:SetWidth(TrackerFrame.content:GetWidth() - 4)
                qf:SetHeight(questHeight)
                qf.questData = quest
                qf.questId = quest.id

                self:UpdateQuestFrame(qf, quest, false)

                y = y + questHeight + padding
                displayed = displayed + 1
            end
        end
    end

    TrackerFrame.content:SetHeight(math.max(y, 40))

    -- Auto-show/hide scrollbar based on content height
    if TrackerFrame.scrollBar then
        local contentHeight = TrackerFrame.content:GetHeight()
        local frameHeight = TrackerFrame.scrollFrame:GetHeight()
        if contentHeight > frameHeight then
            -- Content overflows - show scrollbar on hover
            TrackerFrame.scrollFrame:SetScript("OnEnter", function()
                TrackerFrame.scrollBar:SetAlpha(0.6)
            end)
            TrackerFrame.scrollFrame:SetScript("OnLeave", function()
                TrackerFrame.scrollBar:SetAlpha(0)
            end)
            TrackerFrame.scrollBar:SetScript("OnEnter", function()
                TrackerFrame.scrollBar:SetAlpha(0.6)
            end)
            TrackerFrame.scrollBar:SetScript("OnLeave", function()
                TrackerFrame.scrollBar:SetAlpha(0)
            end)
        else
            -- Content fits - hide scrollbar completely
            TrackerFrame.scrollBar:SetAlpha(0)
            TrackerFrame.scrollFrame:SetScript("OnEnter", nil)
            TrackerFrame.scrollFrame:SetScript("OnLeave", nil)
        end
    end

    -- Empty message
    if displayed == 0 then
        if not TrackerFrame.emptyText then
            TrackerFrame.emptyText = TrackerFrame.content:CreateFontString(nil, "OVERLAY")
            TrackerFrame.emptyText:SetFont("Fonts\\FRIZQT__.TTF", FONT_QUEST, "")
            TrackerFrame.emptyText:SetPoint("CENTER", 0, 10)
            TrackerFrame.emptyText:SetTextColor(0.4, 0.4, 0.4)
        end
        TrackerFrame.emptyText:SetText(L["NO_ACTIVE_QUESTS"])
        TrackerFrame.emptyText:Show()
    elseif TrackerFrame.emptyText then
        TrackerFrame.emptyText:Hide()
    end
end

-- Shared click/hover handlers (defined once, avoid closure allocation per frame)
local function QuestFrame_OnClick(self, btn)
    if btn == "LeftButton" then
        local q = self.questData
        if q then
            if IsShiftKeyDown() then
                -- Shift+Left Click = Link quest in chat
                QM:LinkQuestToChat(q.id)
            else
                QM:SetWaypointForQuest(q.id)
            end
        end
    elseif btn == "RightButton" then
        QM:ShowQuestContextMenu(self)
    end
end

local function QuestFrame_OnEnter(self)
    if self.questData then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("quest:" .. self.questData.id)
        if QM.db.profile.questTimer.enabled and QM.db.profile.questTimer.showInTooltip then
            local duration = QM:GetQuestDuration(self.questData.id)
            if duration then
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine(L["TIME_ON_QUEST"], "|cFFFFD700" .. QM:FormatQuestDuration(duration) .. "|r", 1, 1, 1)
            end
        end
        local dist = QM:GetNearestObjectiveDistance(self.questData.id)
        if dist and dist < 99999 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format("|cFFAAD4FF%s:|r %d %s", L["DISTANCE_TO_OBJECTIVE"], math.floor(dist), L["YARDS"]))
        end
        local note = QM:GetQuestNote(self.questData.id)
        if note and note ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFF88CCFF" .. L["NOTE"] .. "|r")
            GameTooltip:AddLine("|cFFFFFFFF" .. note .. "|r", 1, 1, 1, true)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF888888" .. L["CLICK_SET_WAYPOINT"] .. "|r")
        GameTooltip:AddLine("|cFF888888" .. L["CLICK_LINK_QUEST"] .. "|r")
        GameTooltip:AddLine("|cFF888888" .. L["CLICK_MORE_OPTIONS"] .. "|r")
        GameTooltip:Show()
    end
end

local function QuestFrame_OnLeave() GameTooltip:Hide() end

local function CollapseBtn_OnClick(self)
    local qid = self:GetParent().questId
    if qid then
        collapsedQuests[qid] = not collapsedQuests[qid]
        local ok, err = pcall(QM.UpdateTracker, QM)
        if not ok and QM.DebugLog then QM:DebugLog("UpdateTracker error: " .. tostring(err)) end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
end

function QM:UpdateQuestFrame(f, quest, isCollapsed)
    if not f or not quest then return end

    local displayMode = QM.db.profile.tracker.displayMode or "normal"
    local showDist = QM.db.profile.tracker.showDistance
    local distDisplay = QM.db.profile.tracker.distanceDisplay or "quest"
    local compactNums = QM.db.profile.tracker.compactNumbers
    local hideClose = QM.db.profile.tracker.hideDistanceWhenClose

    -- Set shared handlers (no closure allocation)
    f:SetScript("OnClick", QuestFrame_OnClick)
    f:SetScript("OnEnter", QuestFrame_OnEnter)
    f:SetScript("OnLeave", QuestFrame_OnLeave)
    f.collapseBtn:SetScript("OnClick", CollapseBtn_OnClick)

    -- Apply current font size
    local fontSize = GetFontSize()
    f.title:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "")
    f.distance:SetFont("Fonts\\FRIZQT__.TTF", fontSize - 1, "")
    f.collapseBtn.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize - 1, "")

    -- Collapse button (hide in compact mode)
    if displayMode == "compact" then
        f.collapseBtn:Hide()
        f.status:SetPoint("LEFT", 2, 0)
    else
        f.collapseBtn:Show()
        f.collapseBtn.text:SetText(isCollapsed and "[+]" or "[-]")
        f.status:SetPoint("LEFT", f.collapseBtn, "RIGHT", 3, 0)
    end

    -- Selected/Active quest glow - highlight quest that arrow is tracking
    if f.selectedGlow then
        local isTracked = QM.currentWaypoint and QM.currentWaypoint.questId == quest.id
        if isTracked then
            f.selectedGlow:Show()
        else
            f.selectedGlow:Hide()
        end
    end

    -- Turn-in indicator for completed quests (yellow question mark + COMPLETE badge)
    local hasItemButton = false
    if f.turnInIcon then
        if quest.isComplete then
            f.turnInIcon:Show()
            if f.completeText then
                f.completeText:Show()
            end
            -- Adjust title right margin to make room for turn-in icon and complete text
            f.title:SetPoint("RIGHT", f, "RIGHT", -100, 0)
        else
            f.turnInIcon:Hide()
            if f.completeText then
                f.completeText:Hide()
            end
            -- Wider margin to prevent overlap with distance text
            f.title:SetPoint("RIGHT", f, "RIGHT", -55, 0)
        end
    end

    -- Quest Item Button (for usable quest items like collection tools)
    if f.itemButton then
        local showItemButtons = QM.db.profile.tracker.showItemButtons
        local showItem = false
        if showItemButtons ~= false then
            -- Get the quest log index for this quest
            local logIndex = quest.logIndex or quest.index
            if logIndex then
                -- Check if quest has a usable item
                local link, item, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
                if link and (not quest.isComplete or showItemWhenComplete) then
                    showItem = true
                    hasItemButton = true

                    -- Get item info from the link
                    local itemID, _, _, _, itemTexture
                    if GetItemInfoInstant then
                        itemID, _, _, _, itemTexture = GetItemInfoInstant(link)
                    end
                    if not itemID then
                        itemID = tonumber(link:match("item:(%d+)"))
                    end
                    if not itemTexture then
                        itemTexture = item  -- fallback to GetQuestLogSpecialItemInfo icon
                    end

                    -- Only modify protected button attributes outside combat
                    if not InCombatLockdown() then
                        f.itemButton:SetAttribute("item", link)
                    end
                    f.itemButton.itemLink = link
                    f.itemButton.icon:SetTexture(itemTexture)

                    -- Update cooldown using item ID (not link)
                    if itemID then
                        local getCD = (C_Container and C_Container.GetItemCooldown) or (C_Item and C_Item.GetItemCooldown) or GetItemCooldown
                        if getCD then
                            local start, duration, enable = getCD(itemID)
                            if start and duration and duration > 0 then
                                f.itemButton.cooldown:SetCooldown(start, duration)
                            else
                                f.itemButton.cooldown:Clear()
                            end
                        end
                    end

                    -- Position the item button (anchor to frame, not fontstring)
                    -- Distance text is 50px wide at RIGHT -4, so place button at -58
                    if not InCombatLockdown() then
                        f.itemButton:SetPoint("RIGHT", f, "RIGHT", -58, 0)
                        f.itemButton:Show()
                    end

                    -- Adjust title right margin to make room for item button
                    f.title:SetPoint("RIGHT", f, "RIGHT", -80, 0)
                end
            end
        end
        if not showItem and not InCombatLockdown() then
            f.itemButton:Hide()
        end
    end

    -- Quest Timer display (in tracker)
    if f.timerText then
        if QM.db.profile.questTimer.enabled and QM.db.profile.questTimer.showInTracker
           and not quest.isComplete and displayMode ~= "compact" then
            local duration = QM:GetQuestDuration(quest.id)
            if duration then
                local timerStr = QM:FormatQuestDuration(duration)
                -- Check for best time
                local bestTime = QM:GetQuestBestTime(quest.id)
                if bestTime then
                    timerStr = timerStr .. " |cFF888888(" .. L["BEST"] .. ": " .. QM:FormatQuestDuration(bestTime.duration) .. ")|r"
                end
                f.timerText:SetText("|cFFAAAA88" .. timerStr .. "|r")
                f.timerText:Show()
            else
                f.timerText:Hide()
            end
        else
            f.timerText:Hide()
        end
    end

    -- Hide distance text if showDistance is disabled
    if showDist == false or distDisplay == "none" then
        f.distance:Hide()
    end

    -- Note icon (show if quest has a note)
    if f.noteIcon then
        if QM:HasQuestNote(quest.id) then
            f.noteIcon:Show()
            -- Adjust title to make room for note icon
            if displayMode == "compact" then
                f.title:SetPoint("LEFT", f.noteIcon, "RIGHT", 4, 0)
            else
                f.title:SetPoint("LEFT", f.noteIcon, "RIGHT", 4, 0)
            end
        else
            f.noteIcon:Hide()
            f.title:SetPoint("LEFT", f.status, "RIGHT", 4, 0)
        end
    end

    -- Status indicator
    if quest.isComplete then
        f.status:SetTexture("Interface\\COMMON\\Indicator-Green")
    else
        local r, g, b = self:GetQuestColor(quest)
        if r > 0.9 and g < 0.5 then
            f.status:SetTexture("Interface\\COMMON\\Indicator-Red")
        elseif r > 0.8 and g > 0.4 then
            f.status:SetTexture("Interface\\COMMON\\Indicator-Yellow")
        else
            f.status:SetTexture("Interface\\COMMON\\Indicator-Green")
        end
    end

    -- Title with quest type badge
    -- Check tracker width for responsive badges
    local trackerWidth = TrackerFrame and TrackerFrame:GetWidth() or 250
    local isNarrowTracker = trackerWidth < 220
    local isVeryNarrowTracker = trackerWidth < 190

    local txt = quest.title or L["UNKNOWN"]

    -- Only show level badge if not very narrow
    if QM.db.profile.tracker.showQuestLevel and quest.level and not isVeryNarrowTracker then
        txt = "|cFF777777[" .. quest.level .. "]|r " .. txt
    end

    -- Add quest type indicator (Dungeon/Group/Raid) - hide in very narrow mode
    if not isVeryNarrowTracker then
        if quest.isRaid then
            txt = "|cFFFF4444[" .. L["RAID_TAG"] .. "]|r " .. txt
        elseif quest.isDungeon then
            txt = "|cFF44AAFF[" .. L["DUNGEON_TAG"] .. "]|r " .. txt
        elseif quest.isGroup and quest.suggestedGroup then
            local groupSize = type(quest.suggestedGroup) == "number" and quest.suggestedGroup or ""
            txt = "|cFFFFAA44[" .. L["GROUP_TAG"] .. groupSize .. "]|r " .. txt
        end
    end

    -- Add party sync indicator - hide in narrow mode
    if not isNarrowTracker then
        if QM.db.profile.partySync and QM.db.profile.partySync.enabled
           and QM.db.profile.partySync.showPartyIndicator
           and QM:IsQuestSharedWithParty(quest.id) then
            local partyMembers = QM:GetPartyMembersWithQuest(quest.id)
            local memberCount = #partyMembers
            if memberCount > 0 then
                txt = "|cFF44FF44[" .. L["PARTY_SYNC_ICON"] .. memberCount .. "]|r " .. txt
            end
        end
    end

    -- Add "Turn in!" text for completed quests - use shorter text in narrow mode
    if quest.isComplete then
        if isVeryNarrowTracker then
            txt = txt .. " |cFF00FF00*|r"
        elseif isNarrowTracker then
            txt = txt .. " |cFF00FF00(!)|r"
        else
            txt = txt .. " |cFF00FF00(" .. L["TURN_IN"] .. ")|r"
        end
    end
    f.title:SetText(txt)

    if quest.isComplete then
        f.title:SetTextColor(unpack(COLORS.questComplete))
    else
        local r, g, b = self:GetQuestColor(quest)
        f.title:SetTextColor(r, g, b)
    end

    -- Distance to objective or turn-in
    if distDisplay == "none" then
        f.distance:Hide()
    else
        local dist
        if quest.isComplete then
            -- For completed quests, show turn-in distance
            dist = quest.turnInDistance
            if not dist and QM.DB then
                local locs = QM.DB:GetQuestTurnInLocations(quest.id)
                if locs and locs[1] then
                    dist = self:GetDistanceToPoint(locs[1].x, locs[1].y, locs[1].mapId)
                end
            end
        else
            -- For incomplete quests, show objective distance
            dist = self:GetNearestObjectiveDistance(quest.id)
        end

        if dist and dist < 99999 then
            -- Hide if close and setting is enabled
            if hideClose and dist < 100 then
                f.distance:Hide()
            else
                local r, g, b = QM.Tracker:GetDistanceColor(dist)
                local distText
                if compactNums then
                    distText = QM.Tracker:FormatDistanceCompact(dist)
                else
                    distText = QM.Tracker:FormatDistanceFull(dist)
                end
                f.distance:SetText(distText)
                f.distance:SetTextColor(r, g, b)
                f.distance:Show()
            end
        else
            f.distance:Hide()
        end
    end
end

function QM:UpdateObjectiveFrame(f, obj)
    if not f or not obj then return end

    local displayMode = QM.db.profile.tracker.displayMode or "normal"
    local showProgressBar = QM.db.profile.tracker.showProgressBar
    local showProgressText = QM.db.profile.tracker.showProgressText
    local progressStyle = QM.db.profile.tracker.progressStyle or "colored"

    -- Apply current font size
    local fontSize = GetFontSize()
    f.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize - 1, "")
    f.progress:SetFont("Fonts\\FRIZQT__.TTF", fontSize - 1, "")

    -- Bullet
    if obj.finished then
        f.bullet:SetText("+")
        f.bullet:SetTextColor(DESIGN.success[1], DESIGN.success[2], DESIGN.success[3])
    else
        f.bullet:SetText("-")
        f.bullet:SetTextColor(DESIGN.textMuted[1], DESIGN.textMuted[2], DESIGN.textMuted[3])
    end

    -- Text - clean up and truncate for compact mode
    local txt = obj.text or ""
    txt = txt:gsub("%s*:%s*%d+/%d+$", ""):gsub("%s*%d+/%d+$", "")
    if displayMode == "compact" and #txt > 25 then
        txt = txt:sub(1, 22) .. "..."
    end
    f.text:SetText(txt)

    -- Progress
    if obj.current and obj.required and obj.required > 0 and showProgressText ~= false then
        -- Cap display value so we don't show things like "7/1"
        local displayCurrent = math.min(obj.current, obj.required)
        local pct = obj.current / obj.required
        local pTxt = displayCurrent .. "/" .. obj.required

        if progressStyle == "colored" or progressStyle == "icon" then
            local r, g, b = GetProgressColor(obj.current, obj.required)
            if obj.finished or pct >= 1 then
                f.progress:SetText(pTxt)
                f.progress:SetTextColor(0.3, 1, 0.3)
            else
                f.progress:SetText(pTxt)
                f.progress:SetTextColor(r, g, b)
            end
        else
            -- Plain style
            f.progress:SetText(pTxt)
            f.progress:SetTextColor(0.8, 0.8, 0.8)
        end
        f.progress:Show()

        -- Progress bar
        if showProgressBar ~= false and not obj.finished and displayMode ~= "compact" then
            f.bar:SetMinMaxValues(0, obj.required)
            f.bar:SetValue(displayCurrent)
            local r, g, b = GetProgressColor(displayCurrent, obj.required)
            f.bar:SetStatusBarColor(r, g, b, 0.5)
            f.bar:Show()
        else
            f.bar:Hide()
        end
    else
        f.progress:Hide()
        f.bar:Hide()
    end

    self:UpdateObjectiveColor(f)
end

function QM:UpdateObjectiveColor(f)
    if not f or not f.objectiveData then return end
    if f.objectiveData.finished then
        f.text:SetTextColor(unpack(COLORS.objectiveComplete))
    else
        f.text:SetTextColor(unpack(COLORS.objectiveText))
    end
end

function QM:GetQuestColor(quest)
    if not quest then return 1, 1, 1 end

    -- Check if color by difficulty is enabled
    if QM.db and QM.db.profile and QM.db.profile.tracker and
       QM.db.profile.tracker.colorByDifficulty == false then
        return 1, 1, 1  -- White if disabled
    end

    local pLvl = UnitLevel("player") or 1
    local qLvl = quest.level or pLvl
    local diff = qLvl - pLvl

    if diff >= 5 then return 1, 0.2, 0.2      -- Red (impossible)
    elseif diff >= 3 then return 1, 0.5, 0.2  -- Orange (very hard)
    elseif diff >= -2 then return 1, 1, 0.2   -- Yellow (normal)
    elseif diff >= -5 then return 0.3, 1, 0.3 -- Green (easy)
    else return 0.6, 0.6, 0.6 end             -- Gray (trivial)
end

function QM:GetQuestProgress(quest)
    if not quest or not quest.objectives then return 0 end
    if quest.isComplete then return 1 end

    local total, done = 0, 0
    for _, obj in ipairs(quest.objectives) do
        if obj.required and obj.required > 0 then
            total = total + obj.required
            done = done + (obj.current or 0)
        elseif obj.finished then
            total = total + 1
            done = done + 1
        else
            total = total + 1
        end
    end

    return total > 0 and (done / total) or 0
end

function QM:GetNearestObjectiveDistance(questId)
    -- Fast path: return cached distance if available and recent
    local cached = questDistCache[questId]
    if cached and cached < 999999 then
        return cached
    end

    local minDist = math.huge

    -- Try objective locations first
    local locs = self:GetQuestObjectiveLocationsFixed(questId)
    if locs then
        for _, objLocs in pairs(locs) do
            if objLocs then
                for _, loc in ipairs(objLocs) do
                    local d = self:GetDistanceToPoint(loc.x, loc.y, loc.mapId)
                    if d and d < minDist then minDist = d end
                end
            end
        end
    end

    -- If no objective location found, try quest start NPC location as fallback
    if minDist == math.huge and QM.DB then
        local dbQuest = QM.DB:GetQuest(questId)
        if dbQuest and dbQuest.starters and dbQuest.starters.npcs and dbQuest.starters.npcs[1] then
            local npcId = dbQuest.starters.npcs[1]
            local spawns = QM.DB:GetNPCSpawnLocations(npcId)
            if spawns and spawns[1] then
                local d = self:GetDistanceToPoint(spawns[1].x, spawns[1].y, spawns[1].mapId)
                if d and d < minDist then minDist = d end
            end
        end
    end

    -- If still no location, try turn-in NPC location
    if minDist == math.huge and QM.DB then
        local turnInLocs = QM.DB:GetQuestTurnInLocations(questId)
        if turnInLocs and turnInLocs[1] then
            local d = self:GetDistanceToPoint(turnInLocs[1].x, turnInLocs[1].y, turnInLocs[1].mapId)
            if d and d < minDist then minDist = d end
        end
    end

    return minDist < math.huge and minDist or nil
end

-- ============================================================================
-- Visibility and Settings
-- ============================================================================

function QM:UpdateTrackerVisibility()
    if not TrackerFrame then return end
    -- Cannot show/hide protected frames during combat lockdown
    if InCombatLockdown() and TrackerFrame:IsProtected() then return end
    if QM.db.profile.tracker.enabled and QM.db.profile.enabled then
        TrackerFrame:Show()
    else
        TrackerFrame:Hide()
    end
end

function QM:UpdateTrackerSettings()
    if not TrackerFrame then return end
    -- Font size changes are applied via UpdateTracker
    self:UpdateTracker()
end

function QM:ToggleTrackerMinimized()
    if not TrackerFrame then return end
    TrackerFrame.minimized = not TrackerFrame.minimized

    if TrackerFrame.minimized then
        TrackerFrame.scrollFrame:Hide()
        TrackerFrame.infoBar:Hide()
        TrackerFrame.resizeButton:Hide()
        TrackerFrame:SetHeight(36)
        -- Show plus sign (vertical line visible)
        if TrackerFrame.header.minimize.line2 then
            TrackerFrame.header.minimize.line2:Show()
        end
    else
        TrackerFrame.scrollFrame:Show()
        TrackerFrame.infoBar:Show()
        TrackerFrame.resizeButton:Show()
        TrackerFrame:SetHeight(QM.db.profile.tracker.height or 320)
        -- Show minus sign (hide vertical line)
        if TrackerFrame.header.minimize.line2 then
            TrackerFrame.header.minimize.line2:Hide()
        end
    end
end

-- ============================================================================
-- Blizzard Default Tracker Visibility
-- ============================================================================

-- Static popup for confirming ReloadUI when re-enabling the default tracker
StaticPopupDialogs["QUESTMASTER_RELOADUI_BLIZZARD_TRACKER"] = {
    text = L["HIDE_BLIZZARD_TRACKER_RELOAD"],
    button1 = L["YES"],
    button2 = L["NO"],
    OnAccept = function()
        ReloadUI()
    end,
    OnCancel = function()
        -- Revert the setting since user declined the reload
        QM.db.profile.tracker.hideBlizzardTracker = true
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Apply the Blizzard tracker visibility based on the current setting.
-- Must only be called out of combat (QuestWatchFrame contains protected usable
-- quest-item buttons, so hiding/showing it in combat would taint the frame).
function QM:ApplyBlizzardTrackerVisibility()
    if InCombatLockdown() then return end

    local frame = QuestWatchFrame or WatchFrame
    if not frame then return end

    if QM.db.profile.tracker.hideBlizzardTracker then
        frame:Hide()
        -- Prevent the default UI from re-showing it
        frame:SetScript("OnShow", function(self) self:Hide() end)
    end
    -- Re-enabling is handled via ReloadUI, so no else branch needed
end

-- Called from the settings toggle. Wraps the value change with a combat check
-- and, when the user is re-enabling the default tracker, prompts for ReloadUI.
function QM:SetHideBlizzardTracker(newValue)
    if InCombatLockdown() then
        print(L["MSG_PREFIX"] .. " " .. L["HIDE_BLIZZARD_TRACKER_COMBAT"])
        return
    end

    if newValue then
        -- Hiding the Blizzard tracker – can be done live
        QM.db.profile.tracker.hideBlizzardTracker = true
        self:ApplyBlizzardTrackerVisibility()
    else
        -- Re-enabling – the OnShow hook and lost event registrations mean we
        -- need a full UI reload to restore the default tracker properly.
        QM.db.profile.tracker.hideBlizzardTracker = false
        StaticPopup_Show("QUESTMASTER_RELOADUI_BLIZZARD_TRACKER")
    end
end

-- ============================================================================
-- Waypoint Functions
-- ============================================================================

function QM:SetWaypointForQuest(questId)
    local quest = self.activeQuests[questId]
    if not quest then return end

    for i, obj in ipairs(quest.objectives) do
        if not obj.finished then
            self:SetWaypointForObjective(questId, i)
            return
        end
    end

    local loc = self:GetQuestTurnInLocation(questId)
    if loc then
        -- isManual = true to prevent auto-select from overriding user choice
        self:SetWaypoint(questId, 0, loc.x, loc.y, loc.mapId, quest.title .. " (Turn In)", true)
    end
end

function QM:SetWaypointForObjective(questId, objIndex)
    local quest = self.activeQuests[questId]
    if not quest then return end

    local obj = quest.objectives[objIndex]
    if not obj then return end

    local locs = self:GetQuestObjectiveLocationsFixed(questId)
    if locs and locs[objIndex] and #locs[objIndex] > 0 then
        local closest, minDist = nil, math.huge
        for _, loc in ipairs(locs[objIndex]) do
            local d = self:GetDistanceToPoint(loc.x, loc.y, loc.mapId)
            if d and d < minDist then
                minDist = d
                closest = loc
            end
        end

        if closest then
            -- isManual = true to prevent auto-select from overriding user choice
            self:SetWaypoint(questId, objIndex, closest.x, closest.y, closest.mapId, obj.text, true)
            print(L["MSG_PREFIX"] .. " " .. L["WAYPOINT"] .. ": " .. (obj.text or L["OBJECTIVE"]))
        end
    else
        if not quest.noLocationWarned then
            print(L["MSG_PREFIX"] .. " " .. L["NO_LOCATION_DATA"] .. " " .. quest.title)
            quest.noLocationWarned = true
        end
    end
end

function QM:GetQuestTurnInLocation(questId)
    if not QM.DB then return nil end
    local locs = QM.DB:GetQuestTurnInLocations(questId)
    return locs and locs[1]
end

function QM:ShowQuestContextMenu(qf)
    if not qf or not qf.questData then return end
    local q = qf.questData

    -- Create simple context menu without EasyMenu (premium styled)
    if not QM.contextMenu then
        QM.contextMenu = CreateFrame("Frame", "QMContextMenu", UIParent, "BackdropTemplate")
        QM.contextMenu:SetFrameStrata("FULLSCREEN_DIALOG")
        QM.contextMenu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = {left = 2, right = 2, top = 2, bottom = 2}
        })
        QM.contextMenu:SetBackdropColor(DESIGN.bgDarkest[1], DESIGN.bgDarkest[2], DESIGN.bgDarkest[3], 0.98)
        QM.contextMenu:SetBackdropBorderColor(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.9)
        QM.contextMenu:EnableMouse(true)
        QM.contextMenu:Hide()

        QM.contextMenu:SetScript("OnLeave", function(self)
            C_Timer.After(0.1, function()
                if QM.contextMenu and not QM.contextMenu:IsMouseOver() then
                    QM.contextMenu:Hide()
                end
            end)
        end)
    end

    local menu = QM.contextMenu

    -- Clear old buttons
    if menu.buttons then
        for _, btn in ipairs(menu.buttons) do
            btn:Hide()
        end
    end
    menu.buttons = {}

    local hasNote = QM:HasQuestNote(q.id)
    local items = {
        {text = q.title, isTitle = true},
        {text = L["SET_WAYPOINT"], func = function() QM:SetWaypointForQuest(q.id) end},
        {text = L["SHOW_ON_MAP"], func = function() if WorldMapFrame then WorldMapFrame:Show() end end},
        {text = collapsedQuests[q.id] and L["EXPAND_QUEST"] or L["COLLAPSE_QUEST"], func = function()
            collapsedQuests[q.id] = not collapsedQuests[q.id]
            pcall(QM.UpdateTracker, QM)
        end},
        {text = hasNote and L["EDIT_NOTE"] or L["ADD_NOTE"], isNote = true, func = function()
            QM:ShowQuestNoteDialog(q.id, q.title)
        end},
        {text = L["SHARE_QUEST"], func = function() QM:ShareQuest(q.id) end},
        {text = L["ABANDON_QUEST"], isDanger = true, func = function() QM:AbandonQuest(q.id) end},
    }

    local width = 150
    local height = #items * 22 + 16
    menu:SetSize(width, height)

    for i, item in ipairs(items) do
        local btn = CreateFrame("Button", nil, menu, "BackdropTemplate")
        btn:SetSize(width - 12, 20)
        btn:SetPoint("TOP", 0, -6 - (i-1) * 22)
        btn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
        btn:SetBackdropColor(0, 0, 0, 0)

        btn.text = btn:CreateFontString(nil, "OVERLAY")
        btn.text:SetFont("Fonts\\FRIZQT__.TTF", FONT_QUEST, "")
        btn.text:SetPoint("LEFT", 8, 0)

        if item.isTitle then
            btn.text:SetText("|cFFFFD700" .. item.text .. "|r")
            btn:Disable()
            -- Add separator after title
            local sep = btn:CreateTexture(nil, "ARTWORK")
            sep:SetHeight(1)
            sep:SetPoint("BOTTOMLEFT", 4, -2)
            sep:SetPoint("BOTTOMRIGHT", -4, -2)
            sep:SetColorTexture(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.5)
        else
            if item.isDanger then
                btn.text:SetText("|cFFFF5555" .. item.text .. "|r")
            elseif item.isNote then
                btn.text:SetText("|cFF88CCFF" .. item.text .. "|r")
            else
                btn.text:SetText(item.text)
                btn.text:SetTextColor(DESIGN.textWhite[1], DESIGN.textWhite[2], DESIGN.textWhite[3])
            end
            btn:SetScript("OnClick", function()
                menu:Hide()
                if item.func then item.func() end
            end)
            btn:SetScript("OnEnter", function(self)
                self:SetBackdropColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.15)
                if not item.isDanger and not item.isNote then
                    self.text:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
                end
            end)
            btn:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0, 0, 0, 0)
                if not item.isDanger and not item.isNote then
                    self.text:SetTextColor(DESIGN.textWhite[1], DESIGN.textWhite[2], DESIGN.textWhite[3])
                end
            end)
        end

        table.insert(menu.buttons, btn)
    end

    -- Position at cursor
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x/scale, y/scale)
    menu:Show()
end

-- Sort Dropdown Menu (premium styled)
function QM:ShowSortDropdown(anchor)
    if not QM.sortDropdown then
        local dropdown = CreateFrame("Frame", "QMSortDropdown", UIParent, "BackdropTemplate")
        dropdown:SetSize(110, 72)
        dropdown:SetFrameStrata("FULLSCREEN_DIALOG")
        dropdown:SetFrameLevel(100)
        dropdown:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = {left = 2, right = 2, top = 2, bottom = 2}
        })
        dropdown:SetBackdropColor(DESIGN.bgDarkest[1], DESIGN.bgDarkest[2], DESIGN.bgDarkest[3], 0.98)
        dropdown:SetBackdropBorderColor(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.9)
        dropdown:Hide()

        -- Close on click outside (not on mouseleave to avoid info bar conflict)
        dropdown:SetScript("OnShow", function(self)
            self:SetScript("OnUpdate", function(s)
                if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
                    if not s:IsMouseOver() then
                        s:Hide()
                    end
                end
            end)
        end)

        local sortOptions = {
            {key = "distance", label = L["SORT_DISTANCE"]},
            {key = "level", label = L["SORT_LEVEL"]},
        }

        local title = dropdown:CreateFontString(nil, "OVERLAY")
        title:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
        title:SetPoint("TOP", 0, -8)
        title:SetText("|cFFFFD700" .. L["SORT_BY"] .. "|r")

        -- Separator under title
        local sep = dropdown:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", 6, -20)
        sep:SetPoint("TOPRIGHT", -6, -20)
        sep:SetColorTexture(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.5)

        dropdown.buttons = {}
        for i, opt in ipairs(sortOptions) do
            local btn = CreateFrame("Button", nil, dropdown, "BackdropTemplate")
            btn:SetSize(100, 20)
            btn:SetPoint("TOP", 0, -22 - (i-1) * 22)
            btn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
            btn:SetBackdropColor(0, 0, 0, 0)

            -- Check indicator (dot style)
            btn.check = btn:CreateTexture(nil, "ARTWORK")
            btn.check:SetSize(6, 6)
            btn.check:SetPoint("LEFT", 8, 0)
            btn.check:SetTexture("Interface\\COMMON\\Indicator-Green")
            btn.check:Hide()

            btn.text = btn:CreateFontString(nil, "OVERLAY")
            btn.text:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
            btn.text:SetPoint("LEFT", 18, 0)
            btn.text:SetText(opt.label)
            btn.text:SetTextColor(DESIGN.textWhite[1], DESIGN.textWhite[2], DESIGN.textWhite[3])

            btn.sortKey = opt.key
            btn:SetScript("OnClick", function(self)
                QM.db.profile.tracker.sortBy = self.sortKey
                QM:UpdateTracker()
                dropdown:Hide()
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end)
            btn:SetScript("OnEnter", function(self)
                self:SetBackdropColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.15)
                self.text:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
            end)
            btn:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0, 0, 0, 0)
                local isSelected = QM.db.profile.tracker.sortBy == self.sortKey
                if isSelected then
                    self.text:SetTextColor(DESIGN.success[1], DESIGN.success[2], DESIGN.success[3])
                else
                    self.text:SetTextColor(DESIGN.textWhite[1], DESIGN.textWhite[2], DESIGN.textWhite[3])
                end
            end)

            dropdown.buttons[opt.key] = btn
        end

        QM.sortDropdown = dropdown
    end

    -- Update checkmarks
    local currentSort = QM.db.profile.tracker.sortBy or "distance"
    for key, btn in pairs(QM.sortDropdown.buttons) do
        if key == currentSort then
            btn.check:Show()
            btn.text:SetTextColor(DESIGN.success[1], DESIGN.success[2], DESIGN.success[3])
        else
            btn.check:Hide()
            btn.text:SetTextColor(DESIGN.textWhite[1], DESIGN.textWhite[2], DESIGN.textWhite[3])
        end
    end

    -- Position below anchor
    QM.sortDropdown:ClearAllPoints()
    QM.sortDropdown:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
    QM.sortDropdown:Show()
end

-- Find quest log index by quest ID (indices change when quests are added/removed)
-- Expands collapsed headers temporarily to find quests hidden under them
function QM:FindQuestLogIndex(questId)
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local _, _, _, isHeader, _, _, _, qId = GetQuestLogTitle(i)
        -- Fallback: use GetQuestID if GetQuestLogTitle doesn't return questId
        if not isHeader and not qId and GetQuestID then
            SelectQuestLogEntry(i)
            qId = GetQuestID()
        end
        if not isHeader and qId == questId then
            return i
        end
    end

    -- Quest not found - it may be under a collapsed header
    if ExpandQuestHeader then
        local collapsedHeaders = {}
        for i = 1, numEntries do
            local title, _, _, isHeader, isCollapsed = GetQuestLogTitle(i)
            if isHeader and isCollapsed then
                collapsedHeaders[title] = true
            end
        end
        if next(collapsedHeaders) then
            ExpandQuestHeader(0)
            numEntries = GetNumQuestLogEntries()
            local foundIndex = nil
            for i = 1, numEntries do
                local _, _, _, isHeader, _, _, _, qId = GetQuestLogTitle(i)
                if not isHeader and not qId and GetQuestID then
                    SelectQuestLogEntry(i)
                    qId = GetQuestID()
                end
                if not isHeader and qId == questId then
                    foundIndex = i
                    break
                end
            end
            -- Restore collapsed headers
            if CollapseQuestHeader then
                numEntries = GetNumQuestLogEntries()
                for i = numEntries, 1, -1 do
                    local title, _, _, isHeader = GetQuestLogTitle(i)
                    if isHeader and collapsedHeaders[title] then
                        CollapseQuestHeader(i)
                    end
                end
            end
            return foundIndex
        end
    end

    return nil
end

function QM:AbandonQuest(questId)
    local q = self.activeQuests[questId]
    if not q then return end

    local logIndex = self:FindQuestLogIndex(questId)
    if logIndex then
        SelectQuestLogEntry(logIndex)
        SetAbandonQuest()
        AbandonQuest()
        print(L["MSG_PREFIX"] .. " " .. L["MSG_ABANDONED"] .. " " .. (q.title or L["QUEST_LABEL"]))
    else
        print(L["MSG_PREFIX"] .. " " .. L["MSG_QUEST_NOT_FOUND"])
    end
end

function QM:ShareQuest(questId)
    local q = self.activeQuests[questId]
    if not q then return end

    local logIndex = self:FindQuestLogIndex(questId)
    if logIndex then
        SelectQuestLogEntry(logIndex)
        if GetQuestLogPushable() then
            QuestLogPushQuest()
            print(L["MSG_PREFIX"] .. " " .. L["MSG_SHARED"] .. " " .. (q.title or L["QUEST_LABEL"]))
        else
            print(L["MSG_PREFIX"] .. " " .. L["MSG_CANNOT_SHARE"])
        end
    else
        print(L["MSG_PREFIX"] .. " " .. L["MSG_QUEST_NOT_FOUND"])
    end
end

function QM:GetSortedQuests()
    local sorted = {}
    for _, q in pairs(self.activeQuests or {}) do
        table.insert(sorted, q)
    end
    table.sort(sorted, function(a, b)
        if a.isComplete ~= b.isComplete then return not a.isComplete end
        return (a.level or 0) < (b.level or 0)
    end)
    return sorted
end

-- ============================================================================
-- Info Bar Updates
-- ============================================================================

function QM:UpdateInfoBar()
    if not TrackerFrame or not TrackerFrame.infoBar then return end

    -- InfoBar Show/Hide affects the protected TrackerFrame layout, skip in combat
    if InCombatLockdown() and TrackerFrame:IsProtected() then return end

    local infoTexts = {}

    -- XP/Hour tracker
    if QM.db.profile.xpTracker.enabled and QM.db.profile.xpTracker.showInTracker then
        local xpPerHour = self:GetXPPerHour()
        if xpPerHour >= 1000 then
            table.insert(infoTexts, string.format("|cFFFFD700" .. L["XP_HOUR_PREFIX"] .. "|r %.1fk", xpPerHour / 1000))
        else
            table.insert(infoTexts, string.format("|cFFFFD700" .. L["XP_HOUR_PREFIX"] .. "|r %d", xpPerHour))
        end
    end

    -- Rested XP display
    if QM.db.profile.restedXP and QM.db.profile.restedXP.enabled and QM.db.profile.restedXP.showInTracker then
        local restedStr = self:FormatRestedXP()
        if restedStr then
            local bonusText = QM.db.profile.restedXP.showBonus and " |cFF00FF00+50%|r" or ""
            table.insert(infoTexts, string.format("|cFF4169E1" .. L["RESTED_PREFIX"] .. "|r %s%s", restedStr, bonusText))
        end
    end

    -- Level time tracker
    if QM.db.profile.levelTime and QM.db.profile.levelTime.enabled and QM.db.profile.levelTime.showInTracker then
        local currentTime = self:GetCurrentLevelTime()
        local timeStr = self:FormatLevelTime(currentTime)
        local avgStr = ""
        if QM.db.profile.levelTime.showAverage then
            local avgTime = self:GetAverageLevelTime()
            if avgTime then
                avgStr = string.format(" |cFF888888" .. L["AVG_FORMAT"] .. "|r", self:FormatLevelTime(avgTime))
            end
        end
        table.insert(infoTexts, string.format("|cFF00FF00" .. L["LVL_PREFIX"] .. "|r %s%s", timeStr, avgStr))
    end

    -- Reminders (bags/repair)
    if QM.db.profile.reminders and QM.db.profile.reminders.enabled then
        local warnings = self:CheckReminders()
        for _, warn in ipairs(warnings) do
            table.insert(infoTexts, warn.text)
        end
    end

    -- Reputation tracker
    if QM.db.profile.reputation and QM.db.profile.reputation.enabled and QM.db.profile.reputation.showInTracker then
        local reps = self:GetTrackedReputations()
        for _, rep in ipairs(reps) do
            local shortName = rep.name:sub(1, 12)
            if #rep.name > 12 then shortName = shortName .. "..." end
            table.insert(infoTexts, string.format("|cFFFFFFFF%s:|r %s", shortName, self:FormatReputation(rep)))
        end
    end

    -- Update XP text element with combined info
    if TrackerFrame.infoBar.xpText then
        if #infoTexts > 0 then
            TrackerFrame.infoBar.xpText:SetText(table.concat(infoTexts, "  |cFF555555||r  "))
            TrackerFrame.infoBar.xpText:Show()
        else
            TrackerFrame.infoBar.xpText:Hide()
        end
    end

    -- Zone Progress (separate line)
    if QM.db.profile.zoneProgress.enabled and QM.db.profile.zoneProgress.showInTracker then
        local zoneName = GetRealZoneText() or "Unknown"
        local completed, total = self:GetZoneProgress(zoneName)
        if total > 0 then
            if QM.db.profile.zoneProgress.showPercentage then
                local pct = math.floor((completed / total) * 100)
                TrackerFrame.infoBar.zoneText:SetText(string.format("%s: %d%%", zoneName, pct))
            else
                TrackerFrame.infoBar.zoneText:SetText(string.format("%s: %d/%d", zoneName, completed, total))
            end
        else
            TrackerFrame.infoBar.zoneText:SetText(zoneName)
        end
        TrackerFrame.infoBar.zoneText:Show()
    else
        TrackerFrame.infoBar.zoneText:Hide()
    end

    -- Show/hide entire info bar based on settings
    local showInfoBar = #infoTexts > 0 or
                        (QM.db.profile.zoneProgress.enabled and QM.db.profile.zoneProgress.showInTracker)
    if showInfoBar then
        TrackerFrame.infoBar:Show()
        TrackerFrame.scrollFrame:SetPoint("TOPLEFT", TrackerFrame.infoBar, "BOTTOMLEFT", 2, -2)
    else
        TrackerFrame.infoBar:Hide()
        TrackerFrame.scrollFrame:SetPoint("TOPLEFT", TrackerFrame.header, "BOTTOMLEFT", 2, -2)
    end
end

-- ============================================================================
-- Quest Timer Display Updates
-- ============================================================================

function QM:UpdateQuestTimerDisplays()
    if not TrackerFrame then return end

    -- Hide all timers if timer is disabled
    local showTimer = QM.db.profile.questTimer.enabled and QM.db.profile.questTimer.showInTracker

    for _, f in ipairs(questFramePool) do
        if f.inUse and f.timerText then
            if not showTimer then
                f.timerText:Hide()
            elseif f.questData then
                local duration = self:GetQuestDuration(f.questData.id)
                if duration and duration > 0 then
                    local timerStr = self:FormatQuestDuration(duration)
                    f.timerText:SetText("|cFF888888" .. timerStr .. "|r")
                    f.timerText:Show()
                else
                    f.timerText:Hide()
                end
            else
                f.timerText:Hide()
            end
        end
    end
end

-- ============================================================================
-- Tracker Layout Update (for resize)
-- ============================================================================

function QM:UpdateTrackerLayout(width, height)
    if not TrackerFrame then return end

    -- Size thresholds for responsive layout
    local isNarrow = width < 220
    local isVeryNarrow = width < 190
    local isShort = height < 150

    -- Header and info bar use anchor points, so they auto-resize
    if TrackerFrame.header then
        -- Show/hide header buttons based on width
        local header = TrackerFrame.header
        if header.nearestBtn then
            if isVeryNarrow then
                header.nearestBtn:Hide()
            else
                header.nearestBtn:Show()
            end
        end

        if header.sortBtn then
            if isVeryNarrow then
                header.sortBtn:Hide()
            else
                header.sortBtn:Show()
            end
        end

        if header.settingsBtn then
            if isVeryNarrow then
                header.settingsBtn:Hide()
            elseif isNarrow then
                header.settingsBtn:Show()
            else
                header.settingsBtn:Show()
            end
        end

        -- Truncate title if narrow
        if header.title then
            if isVeryNarrow then
                header.title:SetText("|cFFFFD700" .. L["QM_SHORT"] .. "|r")
            elseif isNarrow then
                header.title:SetText("|cFFFFD700" .. L["QUESTS_SHORT"] .. "|r")
            else
                header.title:SetText("|cFFFFD700" .. L["TRACKER_TITLE"] .. "|r")
            end
        end
    end

    -- Update info bar (width auto-adjusts via anchor points)
    if TrackerFrame.infoBar then
        -- Hide zone text if too narrow, only show XP/h
        if TrackerFrame.infoBar.zoneText then
            if isNarrow then
                TrackerFrame.infoBar.zoneText:Hide()
            elseif QM.db.profile.zoneProgress.enabled and QM.db.profile.zoneProgress.showInTracker then
                TrackerFrame.infoBar.zoneText:Show()
            end
        end

        -- Compact XP text if very narrow
        if TrackerFrame.infoBar.xpText then
            local xpPerHour = self:GetXPPerHour()
            if isVeryNarrow then
                if xpPerHour >= 1000 then
                    TrackerFrame.infoBar.xpText:SetText(string.format("%.0fk", xpPerHour / 1000))
                else
                    TrackerFrame.infoBar.xpText:SetText(string.format("%d", xpPerHour))
                end
            else
                if xpPerHour >= 1000 then
                    TrackerFrame.infoBar.xpText:SetText(string.format(L["XP_HOUR_PREFIX"] .. " %.1fk", xpPerHour / 1000))
                else
                    TrackerFrame.infoBar.xpText:SetText(string.format(L["XP_HOUR_PREFIX"] .. " %d", xpPerHour))
                end
            end
        end

        -- Hide entire info bar if very short
        if isShort then
            TrackerFrame.infoBar:Hide()
            if TrackerFrame.scrollFrame then
                TrackerFrame.scrollFrame:SetPoint("TOPLEFT", TrackerFrame.header, "BOTTOMLEFT", 2, -2)
            end
        else
            local showInfoBar = (QM.db.profile.xpTracker.enabled and QM.db.profile.xpTracker.showInTracker) or
                                (QM.db.profile.zoneProgress.enabled and QM.db.profile.zoneProgress.showInTracker)
            if showInfoBar then
                TrackerFrame.infoBar:Show()
                if TrackerFrame.scrollFrame then
                    TrackerFrame.scrollFrame:SetPoint("TOPLEFT", TrackerFrame.infoBar, "BOTTOMLEFT", 2, -2)
                end
            end
        end
    end

    -- Update scroll frame and content width
    if TrackerFrame.scrollFrame then
        TrackerFrame.scrollFrame:SetPoint("BOTTOMRIGHT", TrackerFrame, "BOTTOMRIGHT", -18, 4)
        if TrackerFrame.content then
            TrackerFrame.content:SetWidth(TrackerFrame.scrollFrame:GetWidth() - 8)
        end
    end

    -- Update quest frame widths
    local contentWidth = TrackerFrame.content and TrackerFrame.content:GetWidth() or (width - 30)
    for _, f in ipairs(questFramePool) do
        if f.inUse then
            f:SetWidth(contentWidth)

            -- Truncate quest title based on available width
            if f.title then
                local rightMargin = isVeryNarrow and 20 or (isNarrow and 35 or 55)
                f.title:SetWidth(contentWidth - rightMargin)
                -- Reduce font size slightly when very narrow
                if isVeryNarrow then
                    f.title:SetFont("Fonts\\FRIZQT__.TTF", FONT_QUEST - 1, "")
                else
                    f.title:SetFont("Fonts\\FRIZQT__.TTF", FONT_QUEST, "")
                end
            end

            -- Hide distance text if very narrow
            if f.distance then
                if isVeryNarrow then
                    f.distance:Hide()
                else
                    f.distance:Show()
                end
            end

            -- Hide timer text if narrow
            if f.timerText then
                if isNarrow then
                    f.timerText:Hide()
                end
            end

            -- Hide collapse button if very narrow
            if f.collapseBtn then
                if isVeryNarrow then
                    f.collapseBtn:Hide()
                    if f.status then
                        f.status:SetPoint("LEFT", 2, 0)
                    end
                else
                    f.collapseBtn:Show()
                    if f.status then
                        f.status:SetPoint("LEFT", f.collapseBtn, "RIGHT", 3, 0)
                    end
                end
            end
        end
    end

    -- Update objective frame widths
    for _, f in ipairs(objectiveFramePool) do
        if f.inUse then
            f:SetWidth(contentWidth - 8)

            -- Adjust objective text width
            if f.text then
                local objRightMargin = isVeryNarrow and 8 or (isNarrow and 15 or 30)
                f.text:SetWidth(contentWidth - 30 - objRightMargin)
                -- Reduce font size when very narrow
                if isVeryNarrow then
                    f.text:SetFont("Fonts\\FRIZQT__.TTF", FONT_OBJECTIVE - 1, "")
                else
                    f.text:SetFont("Fonts\\FRIZQT__.TTF", FONT_OBJECTIVE, "")
                end
            end

            -- Hide objective distance if narrow
            if f.distance then
                if isNarrow then
                    f.distance:Hide()
                else
                    f.distance:Show()
                end
            end
        end
    end

    -- Refresh background alpha and border
    UpdateBackgroundAlpha()
    UpdateBorderVisibility()
    TrackerFrame:SetBackdropColor(COLORS.background[1], COLORS.background[2], COLORS.background[3], COLORS.background[4])
end
