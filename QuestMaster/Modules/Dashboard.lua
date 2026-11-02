--[[
    QuestMaster Statistics Dashboard Module
    Standalone popup window with zone progress, quest history, and statistics
]]

local addonName, QM = ...
local L = QM.L

local DashboardFrame = nil

-- Design constants matching main UI
local DESIGN = {
    gold = {0.95, 0.78, 0.25},
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
    blue = {0.35, 0.65, 0.95},
}

local FONT = "Fonts\\FRIZQT__.TTF"

-- Active tab in the dashboard
local activeTab = "overview"

-- History filter state
local historyFilter = {
    search = "",
    sortBy = "time",  -- "time", "name", "level", "duration"
    sortDesc = true,
}

-- ============================================================================
-- Helper Functions
-- ============================================================================

local function FormatTime(seconds)
    if not seconds or seconds <= 0 then return "0m" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then
        return string.format("%dh %dm", h, m)
    elseif m > 0 then
        return string.format("%dm %ds", m, s)
    else
        return string.format("%ds", s)
    end
end

local function FormatNumber(n)
    if not n then return "0" end
    if n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
    end
    return tostring(math.floor(n))
end

local function CreateProgressBar(parent, width, height)
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetSize(width, height)
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bar:SetBackdropColor(0.1, 0.1, 0.12, 1)
    bar:SetBackdropBorderColor(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.5)

    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetPoint("TOPLEFT", 1, -1)
    bar.fill:SetHeight(height - 2)
    bar.fill:SetTexture("Interface\\Buttons\\WHITE8x8")
    bar.fill:SetVertexColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.85)

    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.text:SetFont(FONT, 9, "")
    bar.text:SetPoint("CENTER")
    bar.text:SetTextColor(DESIGN.textWhite[1], DESIGN.textWhite[2], DESIGN.textWhite[3])

    function bar:SetProgress(current, total, label)
        local pct = total > 0 and (current / total) or 0
        pct = math.min(pct, 1)
        self.fill:SetWidth(math.max((self:GetWidth() - 2) * pct, 1))
        if label then
            self.text:SetText(label)
        else
            self.text:SetText(string.format("%d / %d  (%.0f%%)", current, total, pct * 100))
        end
    end

    function bar:SetBarColor(r, g, b)
        self.fill:SetVertexColor(r, g, b, 0.85)
    end

    return bar
end

-- ============================================================================
-- Dashboard Frame Creation
-- ============================================================================

function QM:InitializeDashboard()
    if DashboardFrame then return end

    DashboardFrame = CreateFrame("Frame", "QuestMasterDashboardFrame", UIParent, "BackdropTemplate")
    DashboardFrame:SetSize(520, 480)
    DashboardFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    DashboardFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    DashboardFrame:SetMovable(true)
    DashboardFrame:EnableMouse(true)
    DashboardFrame:RegisterForDrag("LeftButton")
    DashboardFrame:SetClampedToScreen(true)

    -- Dark background
    DashboardFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    DashboardFrame:SetBackdropColor(DESIGN.bgDarkest[1], DESIGN.bgDarkest[2], DESIGN.bgDarkest[3], 0.98)
    DashboardFrame:SetBackdropBorderColor(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.9)

    -- Drag
    DashboardFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    DashboardFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- ===== HEADER =====
    local header = CreateFrame("Frame", nil, DashboardFrame, "BackdropTemplate")
    header:SetHeight(36)
    header:SetPoint("TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", -4, -4)
    header:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    header:SetBackdropColor(DESIGN.bgMedium[1], DESIGN.bgMedium[2], DESIGN.bgMedium[3], 1)

    -- Gold accent top
    local accentTop = header:CreateTexture(nil, "ARTWORK")
    accentTop:SetHeight(2)
    accentTop:SetPoint("TOPLEFT", 0, 0)
    accentTop:SetPoint("TOPRIGHT", 0, 0)
    accentTop:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.6)

    -- Gold accent bottom
    local accent = header:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(2)
    accent:SetPoint("BOTTOMLEFT", 0, 0)
    accent:SetPoint("BOTTOMRIGHT", 0, 0)
    accent:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.4)

    -- Header icon
    local hIcon = header:CreateTexture(nil, "ARTWORK")
    hIcon:SetSize(22, 22)
    hIcon:SetPoint("LEFT", 10, 0)
    hIcon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_02")
    hIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Title
    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 13, "")
    title:SetPoint("LEFT", hIcon, "RIGHT", 8, 0)
    title:SetText("|cFFFFD700Quest|r|cFFFFFFFFMaster|r |cFF888888" .. L["DASHBOARD_TITLE"] .. "|r")

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
    closeBtn:SetScript("OnClick", function() DashboardFrame:Hide() end)
    closeBtn:SetScript("OnEnter", function(self)
        self.line1:SetColorTexture(0.9, 0.3, 0.3, 1)
        self.line2:SetColorTexture(0.9, 0.3, 0.3, 1)
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self.line1:SetColorTexture(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3], 1)
        self.line2:SetColorTexture(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3], 1)
    end)

    -- ===== TAB BAR =====
    local tabBar = CreateFrame("Frame", nil, DashboardFrame, "BackdropTemplate")
    tabBar:SetHeight(28)
    tabBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    tabBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
    tabBar:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    tabBar:SetBackdropColor(DESIGN.bgDark[1], DESIGN.bgDark[2], DESIGN.bgDark[3], 1)

    local tabs = {
        {id = "overview", label = L["DASH_OVERVIEW"]},
        {id = "zones", label = L["DASH_ZONES"]},
        {id = "history", label = L["DASH_HISTORY"]},
    }

    DashboardFrame.tabButtons = {}
    local tabWidth = 170
    for i, tab in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, tabBar)
        btn:SetSize(tabWidth, 26)
        btn:SetPoint("LEFT", (i - 1) * tabWidth + 6, 0)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0, 0, 0, 0)

        btn.text = btn:CreateFontString(nil, "OVERLAY")
        btn.text:SetFont(FONT, 10, "")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(tab.label)
        btn.text:SetTextColor(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3])

        btn.underline = btn:CreateTexture(nil, "ARTWORK")
        btn.underline:SetHeight(2)
        btn.underline:SetPoint("BOTTOMLEFT", 4, 0)
        btn.underline:SetPoint("BOTTOMRIGHT", -4, 0)
        btn.underline:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0)

        btn.tabId = tab.id
        btn:SetScript("OnClick", function(self)
            QM:SelectDashboardTab(self.tabId)
        end)
        btn:SetScript("OnEnter", function(self)
            if activeTab ~= self.tabId then
                self.bg:SetColorTexture(DESIGN.bgLight[1], DESIGN.bgLight[2], DESIGN.bgLight[3], 0.5)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if activeTab ~= self.tabId then
                self.bg:SetColorTexture(0, 0, 0, 0)
            end
        end)

        DashboardFrame.tabButtons[tab.id] = btn
    end

    -- ===== CONTENT AREA with scroll =====
    local contentContainer = CreateFrame("Frame", nil, DashboardFrame)
    contentContainer:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 4, -4)
    contentContainer:SetPoint("BOTTOMRIGHT", DashboardFrame, "BOTTOMRIGHT", -4, 4)

    local scrollFrame = CreateFrame("ScrollFrame", nil, contentContainer)
    scrollFrame:SetAllPoints()
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self.content:GetHeight() - self:GetHeight()
        if maxScroll < 0 then maxScroll = 0 end
        local newScroll = math.max(0, math.min(current - (delta * 30), maxScroll))
        self:SetVerticalScroll(newScroll)
    end)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth() or 504)
    content:SetHeight(800)
    scrollFrame:SetScrollChild(content)
    scrollFrame.content = content

    -- Update content width when parent resizes
    contentContainer:SetScript("OnSizeChanged", function(self, w, h)
        scrollFrame:SetSize(w, h)
        content:SetWidth(w)
    end)

    DashboardFrame.scrollFrame = scrollFrame
    DashboardFrame.content = content

    DashboardFrame:Hide()
    tinsert(UISpecialFrames, "QuestMasterDashboardFrame")
    QM.DashboardFrame = DashboardFrame
end

-- ============================================================================
-- Tab Selection
-- ============================================================================

function QM:SelectDashboardTab(tabId)
    activeTab = tabId

    -- Update tab button visuals
    for id, btn in pairs(DashboardFrame.tabButtons) do
        if id == tabId then
            btn.text:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
            btn.bg:SetColorTexture(DESIGN.bgMedium[1], DESIGN.bgMedium[2], DESIGN.bgMedium[3], 0.8)
            btn.underline:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.8)
        else
            btn.text:SetTextColor(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3])
            btn.bg:SetColorTexture(0, 0, 0, 0)
            btn.underline:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0)
        end
    end

    -- Clear content
    local content = DashboardFrame.content
    for _, child in pairs({content:GetChildren()}) do child:Hide(); child:SetParent(nil) end
    for _, region in pairs({content:GetRegions()}) do region:Hide(); region:SetParent(nil) end

    -- Render selected tab
    if tabId == "overview" then
        self:RenderOverviewTab(content)
    elseif tabId == "zones" then
        self:RenderZonesTab(content)
    elseif tabId == "history" then
        self:RenderHistoryTab(content)
    end

    DashboardFrame.scrollFrame:SetVerticalScroll(0)
end

-- ============================================================================
-- Overview Tab - Statistics Summary
-- ============================================================================

function QM:RenderOverviewTab(content)
    local y = -8
    local summary = self:GetStatsSummary()
    local contentWidth = content:GetWidth() - 16

    -- ===== Summary Cards Row =====
    local cardWidth = (contentWidth - 12) / 3

    -- Quests Completed card
    local function CreateStatCard(parent, x, yPos, w, label, value, color)
        local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        card:SetSize(w, 60)
        card:SetPoint("TOPLEFT", x, yPos)
        card:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        card:SetBackdropColor(DESIGN.bgCard[1], DESIGN.bgCard[2], DESIGN.bgCard[3], 1)
        card:SetBackdropBorderColor(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.5)

        local accentLine = card:CreateTexture(nil, "ARTWORK")
        accentLine:SetHeight(2)
        accentLine:SetPoint("TOPLEFT", 1, -1)
        accentLine:SetPoint("TOPRIGHT", -1, -1)
        accentLine:SetColorTexture(color[1], color[2], color[3], 0.7)

        local valText = card:CreateFontString(nil, "OVERLAY")
        valText:SetFont(FONT, 18, "")
        valText:SetPoint("TOP", 0, -12)
        valText:SetTextColor(color[1], color[2], color[3])
        valText:SetText(value)

        local lblText = card:CreateFontString(nil, "OVERLAY")
        lblText:SetFont(FONT, 9, "")
        lblText:SetPoint("TOP", 0, -36)
        lblText:SetTextColor(DESIGN.textMuted[1], DESIGN.textMuted[2], DESIGN.textMuted[3])
        lblText:SetText(label)

        return card
    end

    CreateStatCard(content, 8, y, cardWidth,
        L["QUESTS_COMPLETED"], tostring(summary.totalCompleted or 0), DESIGN.success)
    CreateStatCard(content, 8 + cardWidth + 6, y, cardWidth,
        L["TOTAL_XP_GAINED"], FormatNumber(summary.totalXP or 0), DESIGN.blue)
    CreateStatCard(content, 8 + (cardWidth + 6) * 2, y, cardWidth,
        L["QUESTS_PER_HOUR"], string.format("%.1f", summary.questsPerHour or 0), DESIGN.warning)

    y = y - 70

    -- ===== Detailed Stats Section =====
    local detailCard = CreateFrame("Frame", nil, content, "BackdropTemplate")
    detailCard:SetSize(contentWidth, 130)
    detailCard:SetPoint("TOPLEFT", 8, y)
    detailCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    detailCard:SetBackdropColor(DESIGN.bgCard[1], DESIGN.bgCard[2], DESIGN.bgCard[3], 1)
    detailCard:SetBackdropBorderColor(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.5)

    local detailAccent = detailCard:CreateTexture(nil, "ARTWORK")
    detailAccent:SetHeight(2)
    detailAccent:SetPoint("TOPLEFT", 1, -1)
    detailAccent:SetPoint("TOPRIGHT", -1, -1)
    detailAccent:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.5)

    local detailTitle = detailCard:CreateFontString(nil, "OVERLAY")
    detailTitle:SetFont(FONT, 11, "")
    detailTitle:SetPoint("TOPLEFT", 10, -10)
    detailTitle:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
    detailTitle:SetText(L["DASH_DETAILED_STATS"])

    local dy = -30
    local function AddStatLine(label, value, valueColor)
        local lbl = detailCard:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(FONT, 10, "")
        lbl:SetPoint("TOPLEFT", 14, dy)
        lbl:SetTextColor(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3])
        lbl:SetText(label)

        local val = detailCard:CreateFontString(nil, "OVERLAY")
        val:SetFont(FONT, 10, "")
        val:SetPoint("TOPRIGHT", -14, dy)
        val:SetTextColor(unpack(valueColor or DESIGN.textWhite))
        val:SetText(value)

        dy = dy - 18
    end

    AddStatLine(L["AVG_QUEST_TIME"], FormatTime(summary.averageTime or 0), DESIGN.textWhite)
    AddStatLine(L["SESSION_QUESTS"], tostring(summary.sessionCompleted or 0), DESIGN.success)
    AddStatLine(L["SESSION_XP"], FormatNumber(summary.sessionXP or 0), DESIGN.blue)

    if summary.fastestQuest then
        AddStatLine(L["DASH_FASTEST_QUEST"],
            string.format("%s (%s)", summary.fastestQuest.title or "?", FormatTime(summary.fastestQuest.duration)),
            DESIGN.success)
    end
    if summary.slowestQuest then
        AddStatLine(L["DASH_SLOWEST_QUEST"],
            string.format("%s (%s)", summary.slowestQuest.title or "?", FormatTime(summary.slowestQuest.duration)),
            DESIGN.warning)
    end

    y = y - 140

    -- ===== Top Zones Section =====
    local topZones = summary.topZones or {}
    if #topZones > 0 then
        local zonesCard = CreateFrame("Frame", nil, content, "BackdropTemplate")
        local zonesHeight = 32 + (#topZones * 24)
        zonesCard:SetSize(contentWidth, zonesHeight)
        zonesCard:SetPoint("TOPLEFT", 8, y)
        zonesCard:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        zonesCard:SetBackdropColor(DESIGN.bgCard[1], DESIGN.bgCard[2], DESIGN.bgCard[3], 1)
        zonesCard:SetBackdropBorderColor(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.5)

        local zAccent = zonesCard:CreateTexture(nil, "ARTWORK")
        zAccent:SetHeight(2)
        zAccent:SetPoint("TOPLEFT", 1, -1)
        zAccent:SetPoint("TOPRIGHT", -1, -1)
        zAccent:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.5)

        local zTitle = zonesCard:CreateFontString(nil, "OVERLAY")
        zTitle:SetFont(FONT, 11, "")
        zTitle:SetPoint("TOPLEFT", 10, -10)
        zTitle:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
        zTitle:SetText(L["DASH_TOP_ZONES"])

        local zy = -32
        for i, zone in ipairs(topZones) do
            local rank = zonesCard:CreateFontString(nil, "OVERLAY")
            rank:SetFont(FONT, 10, "")
            rank:SetPoint("TOPLEFT", 14, zy)
            rank:SetTextColor(DESIGN.textMuted[1], DESIGN.textMuted[2], DESIGN.textMuted[3])
            rank:SetText(string.format("#%d", i))

            local zName = zonesCard:CreateFontString(nil, "OVERLAY")
            zName:SetFont(FONT, 10, "")
            zName:SetPoint("TOPLEFT", 36, zy)
            zName:SetTextColor(DESIGN.textWhite[1], DESIGN.textWhite[2], DESIGN.textWhite[3])
            zName:SetText(zone.name)

            local zCount = zonesCard:CreateFontString(nil, "OVERLAY")
            zCount:SetFont(FONT, 10, "")
            zCount:SetPoint("TOPRIGHT", -14, zy)
            zCount:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
            zCount:SetText(tostring(zone.count) .. " " .. L["QUESTS_COMPLETED"]:lower())

            zy = zy - 24
        end

        y = y - zonesHeight - 10
    end

    content:SetHeight(math.abs(y) + 20)
end

-- ============================================================================
-- Zones Tab - Zone Progress with Percentage Bars
-- ============================================================================

function QM:RenderZonesTab(content)
    local y = -8
    local contentWidth = content:GetWidth() - 16

    -- Collect all zone data
    local zoneData = {}
    local completedByZone = self.db.char.completedQuestsByZone or {}

    for zoneName, quests in pairs(completedByZone) do
        local completed = 0
        for _ in pairs(quests) do completed = completed + 1 end
        local total = self:GetTotalZoneQuests(zoneName)
        local pct = total > 0 and (completed / total * 100) or 0
        table.insert(zoneData, {
            name = zoneName,
            completed = completed,
            total = total,
            percent = pct,
        })
    end

    -- Sort by percentage descending
    table.sort(zoneData, function(a, b) return a.percent > b.percent end)

    -- Overall progress card
    local totalCompleted = 0
    local totalQuests = 0
    for _, z in ipairs(zoneData) do
        totalCompleted = totalCompleted + z.completed
        totalQuests = totalQuests + z.total
    end

    local overallCard = CreateFrame("Frame", nil, content, "BackdropTemplate")
    overallCard:SetSize(contentWidth, 55)
    overallCard:SetPoint("TOPLEFT", 8, y)
    overallCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    overallCard:SetBackdropColor(DESIGN.bgCard[1], DESIGN.bgCard[2], DESIGN.bgCard[3], 1)
    overallCard:SetBackdropBorderColor(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.5)

    local overallAccent = overallCard:CreateTexture(nil, "ARTWORK")
    overallAccent:SetHeight(2)
    overallAccent:SetPoint("TOPLEFT", 1, -1)
    overallAccent:SetPoint("TOPRIGHT", -1, -1)
    overallAccent:SetColorTexture(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3], 0.5)

    local overallTitle = overallCard:CreateFontString(nil, "OVERLAY")
    overallTitle:SetFont(FONT, 11, "")
    overallTitle:SetPoint("TOPLEFT", 10, -8)
    overallTitle:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
    overallTitle:SetText(L["DASH_OVERALL_PROGRESS"])

    local overallBar = CreateProgressBar(overallCard, contentWidth - 20, 16)
    overallBar:SetPoint("TOPLEFT", 10, -30)
    overallBar:SetProgress(totalCompleted, totalQuests)

    y = y - 65

    -- Per-zone progress
    if #zoneData == 0 then
        local noData = content:CreateFontString(nil, "OVERLAY")
        noData:SetFont(FONT, 11, "")
        noData:SetPoint("TOP", 0, y - 20)
        noData:SetTextColor(DESIGN.textMuted[1], DESIGN.textMuted[2], DESIGN.textMuted[3])
        noData:SetText(L["DASH_NO_ZONE_DATA"])
        y = y - 60
    else
        for _, zone in ipairs(zoneData) do
            local row = CreateFrame("Frame", nil, content)
            row:SetSize(contentWidth, 32)
            row:SetPoint("TOPLEFT", 8, y)

            local zName = row:CreateFontString(nil, "OVERLAY")
            zName:SetFont(FONT, 10, "")
            zName:SetPoint("TOPLEFT", 4, -2)
            zName:SetWidth(200)
            zName:SetJustifyH("LEFT")
            zName:SetTextColor(DESIGN.textWhite[1], DESIGN.textWhite[2], DESIGN.textWhite[3])
            zName:SetText(zone.name)

            local pctText = row:CreateFontString(nil, "OVERLAY")
            pctText:SetFont(FONT, 9, "")
            pctText:SetPoint("TOPRIGHT", -4, -2)
            if zone.percent >= 100 then
                pctText:SetTextColor(DESIGN.success[1], DESIGN.success[2], DESIGN.success[3])
            elseif zone.percent >= 50 then
                pctText:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
            else
                pctText:SetTextColor(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3])
            end
            pctText:SetText(string.format("%.0f%%", zone.percent))

            local bar = CreateProgressBar(row, contentWidth - 8, 10)
            bar:SetPoint("TOPLEFT", 4, -16)
            bar:SetProgress(zone.completed, zone.total,
                string.format("%d / %d", zone.completed, zone.total))
            bar.text:SetFont(FONT, 7, "")

            -- Color the bar based on progress
            if zone.percent >= 100 then
                bar:SetBarColor(DESIGN.success[1], DESIGN.success[2], DESIGN.success[3])
            elseif zone.percent >= 75 then
                bar:SetBarColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
            elseif zone.percent >= 50 then
                bar:SetBarColor(DESIGN.blue[1], DESIGN.blue[2], DESIGN.blue[3])
            end

            y = y - 34
        end
    end

    content:SetHeight(math.abs(y) + 20)
end

-- ============================================================================
-- History Tab - Quest History with Filters
-- ============================================================================

function QM:RenderHistoryTab(content)
    local y = -8
    local contentWidth = content:GetWidth() - 16

    -- Filter bar
    local filterBar = CreateFrame("Frame", nil, content, "BackdropTemplate")
    filterBar:SetSize(contentWidth, 32)
    filterBar:SetPoint("TOPLEFT", 8, y)
    filterBar:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    filterBar:SetBackdropColor(DESIGN.bgMedium[1], DESIGN.bgMedium[2], DESIGN.bgMedium[3], 0.8)

    -- Search box
    local searchBox = CreateFrame("EditBox", nil, filterBar, "InputBoxTemplate")
    searchBox:SetSize(160, 20)
    searchBox:SetPoint("LEFT", 8, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(40)
    searchBox:SetText(historyFilter.search or "")
    searchBox:SetScript("OnTextChanged", function(self)
        historyFilter.search = self:GetText()
        QM:SelectDashboardTab("history")
    end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Sort buttons
    local sortOptions = {
        {id = "time", label = L["DASH_SORT_TIME"]},
        {id = "name", label = L["DASH_SORT_NAME"]},
        {id = "level", label = L["DASH_SORT_LEVEL"]},
        {id = "duration", label = L["DASH_SORT_DURATION"]},
    }

    local sx = 180
    for _, opt in ipairs(sortOptions) do
        local btn = CreateFrame("Button", nil, filterBar)
        btn:SetSize(60, 20)
        btn:SetPoint("LEFT", sx, 0)

        btn.text = btn:CreateFontString(nil, "OVERLAY")
        btn.text:SetFont(FONT, 9, "")
        btn.text:SetPoint("CENTER")

        if historyFilter.sortBy == opt.id then
            local arrow = historyFilter.sortDesc and " v" or " ^"
            btn.text:SetText("|cFFFFD700" .. opt.label .. arrow .. "|r")
        else
            btn.text:SetText("|cFF888888" .. opt.label .. "|r")
        end

        btn:SetScript("OnClick", function()
            if historyFilter.sortBy == opt.id then
                historyFilter.sortDesc = not historyFilter.sortDesc
            else
                historyFilter.sortBy = opt.id
                historyFilter.sortDesc = true
            end
            QM:SelectDashboardTab("history")
        end)

        sx = sx + 64
    end

    y = y - 38

    -- Get and filter history
    local history = self:GetQuestHistory()
    local filtered = {}

    local searchLower = (historyFilter.search or ""):lower()
    for _, entry in ipairs(history) do
        local match = true
        if searchLower ~= "" then
            if not entry.title or not entry.title:lower():find(searchLower, 1, true) then
                match = false
            end
        end
        if match then
            table.insert(filtered, entry)
        end
    end

    -- Sort
    local sortKey = historyFilter.sortBy or "time"
    local sortDesc = historyFilter.sortDesc
    table.sort(filtered, function(a, b)
        local va, vb
        if sortKey == "time" then
            va, vb = a.timestamp or 0, b.timestamp or 0
        elseif sortKey == "name" then
            va, vb = a.title or "", b.title or ""
        elseif sortKey == "level" then
            va, vb = a.level or 0, b.level or 0
        elseif sortKey == "duration" then
            va, vb = a.duration or 0, b.duration or 0
        else
            va, vb = a.timestamp or 0, b.timestamp or 0
        end
        if sortDesc then
            return va > vb
        else
            return va < vb
        end
    end)

    -- Count label
    local countLabel = content:CreateFontString(nil, "OVERLAY")
    countLabel:SetFont(FONT, 9, "")
    countLabel:SetPoint("TOPLEFT", 12, y)
    countLabel:SetTextColor(DESIGN.textMuted[1], DESIGN.textMuted[2], DESIGN.textMuted[3])
    countLabel:SetText(string.format(L["DASH_SHOWING_ENTRIES"], #filtered, #history))
    y = y - 16

    -- History entries
    if #filtered == 0 then
        local noData = content:CreateFontString(nil, "OVERLAY")
        noData:SetFont(FONT, 11, "")
        noData:SetPoint("TOP", 0, y - 20)
        noData:SetTextColor(DESIGN.textMuted[1], DESIGN.textMuted[2], DESIGN.textMuted[3])
        noData:SetText(L["DASH_NO_HISTORY"])
        y = y - 60
    else
        -- Column headers
        local headerRow = CreateFrame("Frame", nil, content)
        headerRow:SetSize(contentWidth, 18)
        headerRow:SetPoint("TOPLEFT", 8, y)

        local hQuest = headerRow:CreateFontString(nil, "OVERLAY")
        hQuest:SetFont(FONT, 9, "")
        hQuest:SetPoint("TOPLEFT", 4, 0)
        hQuest:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
        hQuest:SetText(L["DASH_COL_QUEST"])

        local hLevel = headerRow:CreateFontString(nil, "OVERLAY")
        hLevel:SetFont(FONT, 9, "")
        hLevel:SetPoint("TOPLEFT", 260, 0)
        hLevel:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
        hLevel:SetText(L["DASH_COL_LEVEL"])

        local hXP = headerRow:CreateFontString(nil, "OVERLAY")
        hXP:SetFont(FONT, 9, "")
        hXP:SetPoint("TOPLEFT", 310, 0)
        hXP:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
        hXP:SetText(L["DASH_COL_XP"])

        local hTime = headerRow:CreateFontString(nil, "OVERLAY")
        hTime:SetFont(FONT, 9, "")
        hTime:SetPoint("TOPLEFT", 370, 0)
        hTime:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
        hTime:SetText(L["DASH_COL_TIME"])

        local hDate = headerRow:CreateFontString(nil, "OVERLAY")
        hDate:SetFont(FONT, 9, "")
        hDate:SetPoint("TOPLEFT", 435, 0)
        hDate:SetTextColor(DESIGN.gold[1], DESIGN.gold[2], DESIGN.gold[3])
        hDate:SetText(L["DASH_COL_DATE"])

        y = y - 20

        -- Separator
        local sep = content:CreateTexture(nil, "ARTWORK")
        sep:SetSize(contentWidth, 1)
        sep:SetPoint("TOPLEFT", 8, y)
        sep:SetColorTexture(DESIGN.border[1], DESIGN.border[2], DESIGN.border[3], 0.5)
        y = y - 4

        -- Render entries (max 50 for performance)
        local maxDisplay = math.min(#filtered, 50)
        for i = 1, maxDisplay do
            local entry = filtered[i]

            local row = CreateFrame("Frame", nil, content)
            row:SetSize(contentWidth, 18)
            row:SetPoint("TOPLEFT", 8, y)

            -- Alternate row background
            if i % 2 == 0 then
                local rowBg = row:CreateTexture(nil, "BACKGROUND")
                rowBg:SetAllPoints()
                rowBg:SetColorTexture(1, 1, 1, 0.02)
            end

            local rTitle = row:CreateFontString(nil, "OVERLAY")
            rTitle:SetFont(FONT, 9, "")
            rTitle:SetPoint("TOPLEFT", 4, -2)
            rTitle:SetWidth(250)
            rTitle:SetJustifyH("LEFT")
            rTitle:SetWordWrap(false)
            rTitle:SetTextColor(DESIGN.textWhite[1], DESIGN.textWhite[2], DESIGN.textWhite[3])
            rTitle:SetText(entry.title or "?")

            local rLevel = row:CreateFontString(nil, "OVERLAY")
            rLevel:SetFont(FONT, 9, "")
            rLevel:SetPoint("TOPLEFT", 260, -2)
            rLevel:SetTextColor(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3])
            rLevel:SetText(tostring(entry.level or "?"))

            local rXP = row:CreateFontString(nil, "OVERLAY")
            rXP:SetFont(FONT, 9, "")
            rXP:SetPoint("TOPLEFT", 310, -2)
            rXP:SetTextColor(DESIGN.blue[1], DESIGN.blue[2], DESIGN.blue[3])
            rXP:SetText(FormatNumber(entry.xp or 0))

            local rDuration = row:CreateFontString(nil, "OVERLAY")
            rDuration:SetFont(FONT, 9, "")
            rDuration:SetPoint("TOPLEFT", 370, -2)
            rDuration:SetTextColor(DESIGN.textGray[1], DESIGN.textGray[2], DESIGN.textGray[3])
            rDuration:SetText(FormatTime(entry.duration or 0))

            local rDate = row:CreateFontString(nil, "OVERLAY")
            rDate:SetFont(FONT, 9, "")
            rDate:SetPoint("TOPLEFT", 435, -2)
            rDate:SetTextColor(DESIGN.textMuted[1], DESIGN.textMuted[2], DESIGN.textMuted[3])
            if entry.timestamp then
                rDate:SetText(date("%m/%d %H:%M", entry.timestamp))
            else
                rDate:SetText("-")
            end

            y = y - 18
        end

        if #filtered > maxDisplay then
            local moreText = content:CreateFontString(nil, "OVERLAY")
            moreText:SetFont(FONT, 9, "")
            moreText:SetPoint("TOPLEFT", 12, y - 4)
            moreText:SetTextColor(DESIGN.textMuted[1], DESIGN.textMuted[2], DESIGN.textMuted[3])
            moreText:SetText(string.format(L["DASH_MORE_ENTRIES"], #filtered - maxDisplay))
            y = y - 22
        end
    end

    content:SetHeight(math.abs(y) + 20)
end

-- ============================================================================
-- Toggle / Show Dashboard
-- ============================================================================

function QM:ToggleDashboard()
    if not DashboardFrame then
        self:InitializeDashboard()
    end

    if DashboardFrame:IsShown() then
        DashboardFrame:Hide()
    else
        DashboardFrame:Show()
        DashboardFrame:Raise()
        self:SelectDashboardTab(activeTab)
    end
end

function QM:ShowDashboard()
    if not DashboardFrame then
        self:InitializeDashboard()
    end
    DashboardFrame:Show()
    DashboardFrame:Raise()
    self:SelectDashboardTab(activeTab)
end
