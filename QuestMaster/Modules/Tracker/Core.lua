--[[
    QuestMaster Quest Tracker - Core Module
    Shared state, constants, and initialization
]]

local addonName, QM = ...

-- ============================================================================
-- Shared State (accessible via QM.Tracker)
-- ============================================================================

QM.Tracker = QM.Tracker or {}
local Tracker = QM.Tracker

-- Main frame reference
Tracker.frame = nil

-- Frame pools
Tracker.questFramePool = {}
Tracker.objectiveFramePool = {}
Tracker.zoneHeaderPool = {}

-- Collapse state storage
Tracker.collapsedZones = {}
Tracker.collapsedQuests = {}

-- ============================================================================
-- Constants
-- ============================================================================

Tracker.ZONE_HEADER_HEIGHT = 20
Tracker.QUEST_HEIGHT = 16
Tracker.OBJECTIVE_HEIGHT = 14
Tracker.PADDING = 3

-- Compact mode constants
Tracker.COMPACT_QUEST_HEIGHT = 14
Tracker.COMPACT_OBJECTIVE_HEIGHT = 12
Tracker.COMPACT_PADDING = 2

-- Font sizes
Tracker.FONT_HEADER = 11
Tracker.FONT_ZONE = 10
Tracker.FONT_QUEST = 9
Tracker.FONT_OBJECTIVE = 9
Tracker.FONT_SMALL = 8
Tracker.FONT_COMPACT = 8

-- Colors
Tracker.COLORS = {
    background = {0.05, 0.05, 0.08, 0.85},
    border = {0.3, 0.25, 0.15, 0.9},
    headerBg = {0.08, 0.06, 0.04, 1},
    accent = {0.7, 0.5, 0.1, 0.9},
    questNormal = {0.9, 0.85, 0.65},
    questComplete = {0.3, 1, 0.3},
    questFailed = {1, 0.3, 0.3},
    objectiveComplete = {0.3, 0.9, 0.3},
    objectiveIncomplete = {0.85, 0.85, 0.85},
    objectiveFailed = {0.9, 0.3, 0.3},
    zoneText = {0.9, 0.8, 0.5},
    highlight = {0.3, 0.3, 0.15, 0.5},
    selected = {0.2, 0.4, 0.2, 0.6},
}

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Get scaled value based on screen resolution
function Tracker:GetScaledValue(baseValue)
    local screenHeight = select(2, GetPhysicalScreenSize()) or 1080
    if screenHeight > 1440 then
        return math.floor(baseValue * (screenHeight / 1440) + 0.5)
    end
    return baseValue
end

-- Dynamic font size from settings
function Tracker:GetFontSize()
    if QM.db and QM.db.profile and QM.db.profile.tracker then
        return QM.db.profile.tracker.fontSize or 9
    end
    return 9
end

-- Update background alpha from settings
function Tracker:UpdateBackgroundAlpha()
    if not self.frame then return end
    local alpha = 0.85
    if QM.db and QM.db.profile and QM.db.profile.tracker then
        alpha = QM.db.profile.tracker.alpha or 0.85
    end
    self.COLORS.background[4] = alpha
end

-- ============================================================================
-- Backwards Compatibility (expose on QM for existing code)
-- ============================================================================

-- Make TrackerFrame accessible
function QM:GetTrackerFrame()
    return QM.Tracker.frame
end
