--[[
    QuestMaster - A comprehensive quest helper addon (All-in-One)
    Supports: Classic, TBC, WotLK, MoP
    Features:
    - Navigation arrow pointing to quest objectives
    - Distance display in yards/meters
    - Quest objective tracker with real-time updates
    - Map pins for quest objectives
    - Comprehensive options panel
]]

local addonName, QM = ...

-- Create main addon object using Ace3
QM.addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
local addon = QM.addon

-- Libraries
local AceDB = LibStub("AceDB-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

-- Store references in QM namespace
QM.HBD = HBD
QM.HBDPins = HBDPins
QM.LDB = LDB
QM.LDBIcon = LDBIcon

-- Localization
local L = QM.L

-- Default database settings
local defaults = {
    profile = {
        -- General
        enabled = true,
        lockFrames = false,
        debug = false,
        minimapButton = {
            hide = false,
        },

        -- Sound settings
        sounds = {
            progress = true,
            complete = true,
            objectiveComplete = true,
        },

        -- Chat announcements
        announce = {
            accept = false,  -- Disabled by default
            acceptChannel = "PARTY",  -- PARTY, GUILD, or NONE (SAY requires hardware event)
            complete = false,  -- Disabled by default
            completeChannel = "PARTY",  -- PARTY, GUILD, or NONE (SAY requires hardware event)
            progress = false,
            levelUp = true,
            levelUpChat = false,  -- Disabled by default (EMOTE works)
            levelUpChannel = "EMOTE",  -- EMOTE, PARTY, GUILD, or NONE
        },

        -- Quest Timer settings
        questTimer = {
            enabled = true,
            showInTracker = true,
            showInTooltip = true,
        },

        -- XP/Hour Tracker settings
        xpTracker = {
            enabled = true,
            showInTracker = true,
        },

        -- Rested XP Display
        restedXP = {
            enabled = true,
            showInTracker = true,
            showBonus = true,  -- Show +50% bonus indicator
        },

        -- Level Time Tracker
        levelTime = {
            enabled = true,
            showInTracker = true,
            showAverage = true,  -- Show average time per level
        },

        -- Reminders (bags full, repair needed)
        reminders = {
            enabled = true,
            bagsFull = true,      -- Warn when bags are nearly full
            bagsThreshold = 4,    -- Free slots threshold
            repairNeeded = true,  -- Warn when durability is low
            repairThreshold = 25, -- Durability percentage threshold
        },

        -- Reputation Tracker (TBC factions)
        reputation = {
            enabled = false,
            showInTracker = false,
            trackedFactions = {},  -- List of faction IDs to track
        },

        -- Party Quest Sync
        partySync = {
            enabled = true,
            showInTracker = true,       -- Show party member progress in tracker
            broadcastProgress = true,   -- Send your progress to party
            showPartyIndicator = true,  -- Show party icon on shared quests
        },

        -- Zone Progress settings
        zoneProgress = {
            enabled = true,
            showInTracker = true,
            showPercentage = true,
        },

        -- Quest History settings
        questHistory = {
            enabled = true,
            maxEntries = 50,
        },

        -- Arrow settings
        arrow = {
            enabled = true,
            scale = 1.0,
            alpha = 0.75,
            showDistance = true,
            showObjective = true,
            showETA = false,
            autoSelect = true,
            arrivalDist = 10,
            color = "gold",
            distanceUnit = "yards",
            x = 0,
            y = -150,
            point = "TOP",
        },

        -- Tracker settings
        tracker = {
            enabled = true,
            scale = 1.0,
            alpha = 0.9,
            fontSize = 9,
            showCompleted = true,
            autoTrack = true,
            showQuestLevel = true,
            showDistance = true,
            collapseCompleted = false,
            groupByZone = true,
            colorByDifficulty = true,
            sortBy = "distance",
            x = -20,
            y = -200,
            point = "TOPRIGHT",
            width = 250,
            height = 400,
            -- New display options
            displayMode = "normal",          -- "compact", "normal", "detailed"
            showProgressBar = true,          -- Show progress bars under objectives
            showProgressText = true,         -- Show progress text (3/8)
            distanceDisplay = "quest",       -- "quest" (only on quest line), "objective" (on objectives too), "none"
            compactNumbers = true,           -- Use shorter number format (1.2k instead of 1234)
            hideDistanceWhenClose = false,   -- Hide distance when < 100 yards
            progressStyle = "colored",       -- "plain", "colored", "icon"
            hideBlizzardTracker = false,     -- Hide the default Blizzard quest tracker
            zoneFilter = false,              -- Only show quests for current zone
            showBorder = true,               -- Show tracker border
        },

        -- Map settings
        map = {
            enableWorldMap = true,
            enableMinimap = true,
            pinScale = 1.0,
            pinAlpha = 0.9,
            showObjectivePins = true,
            showTurnInPins = true,
            showAvailablePins = true,
            showAreaBlobs = true,
            showDangerZones = true,
            maxPinsPerObjective = 5,
            minimapTracking = false,
            -- Patrol path settings
            showPatrolPaths = true,
            patrolPathAlpha = 0.6,
            patrolPathColor = {0.4, 0.7, 1.0},  -- Light blue
        },

        -- Automation settings
        auto = {
            acceptQuests = true,
            completeQuests = true,
            skipRewardChoice = true,
            shareQuests = false,
            waypoint = true,
            advanceWaypoint = true,
            prioritizeTurnIn = false,
            corpseWaypoint = true,  -- Auto-set waypoint to corpse on death
        },

        -- Quest statistics settings
        statistics = {
            enabled = true,
            trackCompletionTimes = true,
            trackXPGained = true,
        },

        -- Quest filtering
        filter = {
            showDungeon = true,
            showRaid = true,
            showGroup = true,
            showPvP = true,
            showLowLevel = false,
        },

        -- Tooltip settings
        tooltips = {
            enabled = true,
            showObjectives = true,
            showDropRates = false,
        },

        -- Performance settings
        performance = {
            updateInterval = 1.0,
            updateThrottle = 0.25,  -- Minimum seconds between full updates
            lazyMapUpdates = false,
        },

        -- Advanced settings
        advanced = {
            maxNoteLength = 200,  -- Maximum characters for quest notes
        },

        -- Colors
        colors = {
            questTitle = {1, 0.82, 0, 1},
            objectiveIncomplete = {1, 1, 1, 1},
            objectiveComplete = {0, 1, 0, 1},
            objectiveFailed = {1, 0, 0, 1},
            distance = {1, 0.82, 0, 1},
            arrowArrived = {0, 1, 0, 1},
        },
    },
    char = {
        trackedQuests = {},
        -- Quest Timer data (per quest)
        questStartTimes = {},
        -- Quest History data
        questHistory = {},
        -- XP Tracking data
        xpData = {
            sessionStart = 0,
            sessionStartXP = 0,
            questsCompleted = 0,
            xpGained = 0,
        },
        -- Quest Statistics data
        questStats = {
            totalCompleted = 0,
            totalAbandoned = 0,
            totalXPFromQuests = 0,
            questTimes = {},           -- {questId = completionTimeSeconds, ...}
            fastestQuests = {},        -- Top 5 fastest quests
            slowestQuests = {},        -- Top 5 slowest quests
            questsPerZone = {},        -- {zoneName = count, ...}
            questsPerHour = {},        -- Hourly breakdown
            levelingTimes = {},        -- Time spent per level
            sessionStats = {
                started = 0,
                completed = 0,
                xpGained = 0,
                timeStarted = 0,
            },
        },
        -- Zone Progress data
        completedQuestsByZone = {},
        -- Quest Notes (user-added notes per quest)
        questNotes = {},
        -- Quest Best Times
        questBestTimes = {},
        -- Saved waypoint for persistence across sessions
        savedWaypoint = nil,
    },
}

-- Current state
QM.currentWaypoint = nil
QM.activeQuests = {}
QM.questObjectives = {}
QM.trackedQuestIds = {}

-- Level tracking state
QM.levelStartTime = nil
QM.lastLevel = nil

-- XP/Hour Tracker state
QM.sessionXPStart = 0
QM.sessionStartTime = 0
QM.lastXPUpdate = 0
QM.xpPerHour = 0

-- Quest Timer state (runtime cache)
QM.questStartTimes = {}

-- Update throttling (prevents excessive updates)
local pendingUpdate = false
local lastFullUpdate = 0

-- Dirty flags for selective updates
local dirtyFlags = {
    quests = false,
    tracker = false,
    map = false,
    arrow = false,
}

-- Get update throttle from settings (with fallback)
local function GetUpdateThrottle()
    return QM.db and QM.db.profile.performance.updateThrottle or 0.1
end

-- Perform updates based on dirty flags
local function DoUpdates(all)
    if all or dirtyFlags.quests then
        QM:UpdateAllQuests()
        dirtyFlags.quests = false
    end
    if all or dirtyFlags.tracker then
        QM:UpdateTracker()
        dirtyFlags.tracker = false
    end
    if all or dirtyFlags.map then
        QM:UpdateMapPins()
        dirtyFlags.map = false
    end
    if all or dirtyFlags.arrow then
        QM:UpdateArrowTarget()
        dirtyFlags.arrow = false
    end
end

-- Consolidated update function with throttling
-- flags: optional table {quests=bool, tracker=bool, map=bool, arrow=bool}
-- If no flags provided, updates everything
local function ScheduleUpdate(flags)
    -- Set dirty flags
    if flags then
        for k, v in pairs(flags) do
            if v then dirtyFlags[k] = true end
        end
    else
        -- No flags = update all
        dirtyFlags.quests = true
        dirtyFlags.tracker = true
        dirtyFlags.map = true
        dirtyFlags.arrow = true
    end

    if pendingUpdate then return end
    local now = GetTime()
    local throttle = GetUpdateThrottle()
    if now - lastFullUpdate < throttle then
        pendingUpdate = true
        C_Timer.After(throttle, function()
            pendingUpdate = false
            lastFullUpdate = GetTime()
            DoUpdates(false)
        end)
    else
        lastFullUpdate = now
        DoUpdates(false)
    end
end
QM.ScheduleUpdate = ScheduleUpdate

-- Version info (compatible with all WoW versions)
local function GetAddonVersion()
    -- Try C_AddOns API first (Retail/modern Classic)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addonName, "Version")
    -- Try legacy GetAddOnMetadata (older clients)
    elseif GetAddOnMetadata then
        return GetAddOnMetadata(addonName, "Version")
    end
    return "1.0.0"
end
QM.version = GetAddonVersion()

-- ============================================================================
-- Addon Initialization
-- ============================================================================

function addon:OnInitialize()
    -- Initialize database (use QuestMasterSavedDB to avoid conflict with internal DB)
    local success, err = pcall(function()
        self.db = AceDB:New("QuestMasterSavedDB", defaults, true)
    end)

    if not success then
        print(string.format("|cFFFF0000QuestMaster:|r %s %s", L["MSG_DB_FAIL"], tostring(err)))
        -- Create fallback database
        self.db = {profile = defaults.profile}
    end

    QM.db = self.db

    -- Debug: confirm database loaded
    if QM.db and QM.db.profile then
        -- print("|cFF00FF00QuestMaster:|r Database initialized successfully")
    else
        print("|cFFFF0000QuestMaster:|r " .. L["MSG_DB_WARNING"])
    end

    -- Initialize character database
    if not QuestMasterCharDB then
        QuestMasterCharDB = {}
    end
    QM.charDB = QuestMasterCharDB

    -- Register callbacks for profile changes (only if AceDB loaded correctly)
    if self.db.RegisterCallback then
        self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
        self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
        self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
    end

    -- Initialize modules with error protection
    local function SafeInit(name, func)
        local ok, initErr = pcall(func)
        if not ok then
            print(string.format("|cFFFF0000QuestMaster:|r " .. L["MSG_INIT_FAIL"], name, tostring(initErr)))
        end
    end

    SafeInit("Database", function() QM:InitializeDatabase() end)
    SafeInit("Arrow", function() QM:InitializeArrow() end)
    SafeInit("Tracker", function() QM:InitializeTracker() end)
    SafeInit("MapPins", function() QM:InitializeMapPins() end)
    SafeInit("MinimapButton", function() QM:InitializeMinimapButton() end)
    SafeInit("Options", function() QM:InitializeOptions() end)

    -- Register slash commands
    self:RegisterChatCommand("qm", "SlashCommand")
    self:RegisterChatCommand("questmaster", "SlashCommand")
end

function addon:OnEnable()
    -- Register events
    self:RegisterEvent("QUEST_ACCEPTED")
    self:RegisterEvent("QUEST_REMOVED")
    self:RegisterEvent("QUEST_LOG_UPDATE")
    self:RegisterEvent("QUEST_WATCH_UPDATE")
    self:RegisterEvent("QUEST_TURNED_IN")
    self:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self:RegisterEvent("ZONE_CHANGED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Register automation events
    self:RegisterEvent("QUEST_DETAIL")
    self:RegisterEvent("QUEST_PROGRESS")
    self:RegisterEvent("QUEST_COMPLETE")
    self:RegisterEvent("GOSSIP_SHOW")

    -- Register level up event for tracking
    self:RegisterEvent("PLAYER_LEVEL_UP")

    -- Register XP tracking event
    self:RegisterEvent("PLAYER_XP_UPDATE")

    -- Register death/corpse events for corpse waypoint
    self:RegisterEvent("PLAYER_DEAD")
    self:RegisterEvent("PLAYER_ALIVE")
    self:RegisterEvent("PLAYER_UNGHOST")

    -- Register combat end event to apply deferred Blizzard tracker visibility
    self:RegisterEvent("PLAYER_REGEN_ENABLED")

    -- Register party sync events
    self:RegisterEvent("CHAT_MSG_ADDON")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")

    -- Initialize Party Quest Sync
    QM:InitializePartySync()

    -- Register tooltip hook
    QM:InitializeTooltipHooks()

    -- Initialize level tracking
    QM.lastLevel = UnitLevel("player")
    QM.levelStartTime = GetTime()

    -- Initialize XP/Hour Tracker
    QM.sessionStartTime = GetTime()
    QM.sessionXPStart = UnitXP("player")
    QM.lastXPUpdate = GetTime()

    -- Load quest start times from saved data
    if QM.db.char.questStartTimes then
        QM.questStartTimes = QM.db.char.questStartTimes
    end

    -- Initial update
    self:ScheduleTimer(function()
        QM:UpdateAllQuests()
        QM:UpdateTracker()
        QM:UpdateMapPins()
        QM:InitializeQuestTimers()
        -- Restore saved waypoint from previous session
        QM:RestoreWaypoint()
    end, 1)

    -- XP/Hour update timer (every 5 seconds)
    self:ScheduleRepeatingTimer(function()
        QM:UpdateXPPerHour()
    end, 5)

    -- Quest Timer UI update (every 10 seconds to keep timers live without excessive updates)
    self:ScheduleRepeatingTimer(function()
        if QM.db.profile.questTimer.enabled and QM.db.profile.questTimer.showInTracker then
            QM:RefreshQuestTimerDisplay()
        end
    end, 10)

    -- Print loaded message
    if L then
        print("|cFF00FF00" .. L["ADDON_LOADED"] .. "|r")
    end
end

function addon:OnDisable()
    -- Save current waypoint for persistence
    QM:SaveWaypoint()

    -- Unregister events
    self:UnregisterAllEvents()

    -- Hide UI elements
    if QM.ArrowFrame then
        QM.ArrowFrame:Hide()
    end
    if QM.TrackerFrame then
        QM.TrackerFrame:Hide()
    end

    QM:ClearAllMapPins()
end

-- ============================================================================
-- Waypoint Persistence
-- ============================================================================

function QM:SaveWaypoint()
    if self.currentWaypoint and self.db and self.db.char then
        -- Only save manual waypoints for persistence
        if self.manualWaypoint then
            self.db.char.savedWaypoint = {
                questId = self.currentWaypoint.questId,
                objectiveIndex = self.currentWaypoint.objectiveIndex,
                x = self.currentWaypoint.x,
                y = self.currentWaypoint.y,
                mapId = self.currentWaypoint.mapId,
                description = self.currentWaypoint.description,
            }
        else
            self.db.char.savedWaypoint = nil
        end
    end
end

function QM:RestoreWaypoint()
    if self.db and self.db.char and self.db.char.savedWaypoint then
        local saved = self.db.char.savedWaypoint
        -- Validate saved waypoint before restoring
        if saved.x and saved.y and saved.mapId then
            local success = self:SetWaypoint(
                saved.questId,
                saved.objectiveIndex,
                saved.x,
                saved.y,
                saved.mapId,
                saved.description,
                true  -- isManual = true
            )
            if success then
                print(L["MSG_PREFIX"] .. " " .. L["MSG_WAYPOINT_RESTORED"])
            end
        end
        -- Clear saved waypoint after restore attempt
        self.db.char.savedWaypoint = nil
    end
end

function addon:RefreshConfig()
    -- Refresh all modules when profile changes
    if QM.ApplyAllSettings then
        QM:ApplyAllSettings()
    end
    ScheduleUpdate()
end

-- ============================================================================
-- Slash Command Handler
-- ============================================================================

function addon:SlashCommand(input)
    local cmd = string.lower(input or "")

    if cmd == "" or cmd == "config" or cmd == "options" then
        -- Open custom settings panel
        QM:ToggleSettings()
    elseif cmd == "arrow" then
        -- Toggle arrow
        QM.db.profile.arrow.enabled = not QM.db.profile.arrow.enabled
        QM:UpdateArrowVisibility()
        print(L["MSG_PREFIX"] .. " Arrow " .. (QM.db.profile.arrow.enabled and L["ENABLED"] or L["DISABLED"]))
    elseif cmd == "tracker" then
        -- Toggle tracker
        QM.db.profile.tracker.enabled = not QM.db.profile.tracker.enabled
        QM:UpdateTrackerVisibility()
        print(L["MSG_PREFIX"] .. " Tracker " .. (QM.db.profile.tracker.enabled and L["ENABLED"] or L["DISABLED"]))
    elseif cmd == "reset" then
        -- Reset frame positions
        QM:ResetFramePositions()
        print(L["MSG_PREFIX"] .. " " .. L["MSG_FRAMES_RESET"])
    elseif cmd == "credits" then
        -- Show credits window
        QM:ToggleCredits()
    elseif cmd == "stats" then
        -- Show quest statistics
        QM:PrintStatsSummary()
    elseif cmd == "dashboard" or cmd == "dash" then
        -- Show statistics dashboard
        QM:ToggleDashboard()
    elseif cmd:sub(1, 6) == "search" then
        -- Search quests: /qm search <term>
        local searchTerm = cmd:sub(8)
        if searchTerm and searchTerm ~= "" then
            QM:PrintQuestSearch(searchTerm)
        else
            print(L["MSG_PREFIX"] .. " " .. L["HELP_USAGE"] .. " /qm search <quest name or id>")
        end
    elseif cmd:sub(1, 3) == "way" then
        -- Set waypoint: /qm way <x> <y> [description]
        local args = cmd:sub(5)
        QM:HandleWayCommand(args)
    elseif cmd == "help" then
        print("|cFF00FF00QuestMaster|r " .. L["SLASH_HELP"])
        print("  " .. L["SLASH_CONFIG"])
        print("  " .. L["SLASH_ARROW"])
        print("  " .. L["SLASH_TRACKER"])
        print("  " .. L["SLASH_RESET"])
        print("  |cFFFFD700/qm credits|r - " .. L["HELP_CREDITS"])
        print("  |cFFFFD700/qm stats|r - " .. L["HELP_STATS"])
        print("  |cFFFFD700/qm search <name>|r - " .. L["HELP_SEARCH"])
        print("  |cFFFFD700/qm way <x> <y> [desc]|r - " .. L["HELP_WAYPOINT"])
    else
        print(L["MSG_PREFIX"] .. " " .. L["MSG_UNKNOWN_CMD"])
    end
end

-- Print stats summary to chat
function QM:PrintStatsSummary()
    local summary = self:GetStatsSummary()

    print("|cFFFFD700" .. L["STATS_HEADER"] .. "|r")
    print(string.format("|cFF00FF00" .. L["STATS_TOTAL_COMPLETED"] .. ":|r %d " .. L["QUESTS"], summary.totalCompleted))
    print(string.format("|cFF00FF00" .. L["STATS_TOTAL_XP"] .. ":|r %s", self:FormatNumber(summary.totalXP)))
    print(string.format("|cFF00FF00" .. L["STATS_AVG_TIME"] .. ":|r %s", self:FormatPlayTime(summary.averageTime)))
    print(string.format("|cFF00FF00" .. L["STATS_QUESTS_HOUR"] .. ":|r %.1f", summary.questsPerHour))

    if summary.fastestQuest then
        print(string.format("|cFF4169E1" .. L["STATS_FASTEST"] .. ":|r %s (%s)",
            summary.fastestQuest.title, self:FormatPlayTime(summary.fastestQuest.duration)))
    end
    if summary.slowestQuest then
        print(string.format("|cFFFF8800" .. L["STATS_SLOWEST"] .. ":|r %s (%s)",
            summary.slowestQuest.title, self:FormatPlayTime(summary.slowestQuest.duration)))
    end

    print("|cFFFFD700--- " .. L["STATS_SESSION"] .. " ---|r")
    print(string.format("|cFF00FF00" .. L["STATS_SESSION_COMPLETED"] .. ":|r %d " .. L["QUESTS"], summary.sessionCompleted))
    print(string.format("|cFF00FF00" .. L["STATS_SESSION_XP"] .. ":|r %s", self:FormatNumber(summary.sessionXP)))

    if #summary.topZones > 0 then
        print("|cFFFFD700--- " .. L["STATS_TOP_ZONES"] .. " ---|r")
        for i, zone in ipairs(summary.topZones) do
            print(string.format("  %d. %s: %d " .. L["QUESTS"], i, zone.name, zone.count))
        end
    end
end

-- Print quest search results to chat
function QM:PrintQuestSearch(searchTerm)
    local results = self:SearchQuests(searchTerm, {maxResults = 10})

    if #results == 0 then
        print(string.format(L["MSG_PREFIX"] .. " " .. L["MSG_NO_QUESTS_FOUND"], searchTerm))
        return
    end

    print(string.format("|cFFFFD700=== " .. L["SEARCH_RESULTS"] .. ": '%s' (%d " .. L["RESULTS"] .. ") ===|r", searchTerm, #results))
    for _, quest in ipairs(results) do
        local status = ""
        if quest.isCompleted then
            status = " |cFF00FF00[" .. L["COMPLETED"] .. "]|r"
        elseif quest.isActive then
            status = " |cFFFFFF00[" .. L["IN_PROGRESS"] .. "]|r"
        end

        local levelStr = quest.level and string.format("[%d]", quest.level) or ""
        print(string.format("  |cFFFFD700%s|r %s%s (" .. L["ID"] .. ": %d)", levelStr, quest.name, status, quest.id))
    end
end

-- Handle /way command for manual waypoints
function QM:HandleWayCommand(args)
    if not args or args == "" then
        print(L["MSG_PREFIX"] .. " " .. L["HELP_USAGE"] .. " /qm way <x> <y> [description]")
        print("  " .. L["EXAMPLE"] .. ": /qm way 45.2 67.8 Meeting spot")
        return
    end

    -- Parse coordinates
    local x, y, desc = args:match("([%d%.]+)%s+([%d%.]+)%s*(.*)")
    if not x or not y then
        print(L["MSG_PREFIX"] .. " " .. L["MSG_INVALID_COORDS"] .. " " .. L["USE"] .. ": /qm way 45.2 67.8")
        return
    end

    x = tonumber(x)
    y = tonumber(y)

    if not x or not y or x < 0 or x > 100 or y < 0 or y > 100 then
        print(L["MSG_PREFIX"] .. " " .. L["MSG_COORDS_INVALID"])
        return
    end

    -- Get current map
    local mapId = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapId then
        print(L["MSG_PREFIX"] .. " " .. L["MSG_NO_MAP"])
        return
    end

    -- Set waypoint
    local description = desc and desc ~= "" and desc or string.format(L["WAYPOINT"] .. " (%.1f, %.1f)", x, y)
    self.currentWaypoint = {
        questId = 0,
        objectiveIndex = 0,
        x = x / 100,
        y = y / 100,
        mapId = mapId,
        description = description,
        isManual = true,
    }
    self.manualWaypoint = true

    print(string.format(L["MSG_PREFIX"] .. " " .. L["MSG_WAYPOINT_SET"] .. " %.1f, %.1f - %s", x, y, description))
    self:UpdateArrow()
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function addon:PLAYER_ENTERING_WORLD()
    -- Get current level
    local currentLevel = UnitLevel("player")
    QM.lastLevel = currentLevel

    -- Restore level start time from saved data (persistent across logins)
    -- We store the real-world timestamp when the level started
    local savedLevelData = QM.db.char.levelTimeData or {}

    if savedLevelData.level == currentLevel and savedLevelData.startTime then
        -- Same level - calculate elapsed time since level start
        local elapsedRealTime = time() - savedLevelData.startTime
        -- Convert to GetTime() base: current GetTime() minus elapsed seconds
        QM.levelStartTime = GetTime() - elapsedRealTime
    else
        -- New level or first login - start fresh and save
        QM.levelStartTime = GetTime()
        QM.db.char.levelTimeData = {
            level = currentLevel,
            startTime = time(),  -- Unix timestamp
        }
    end

    -- Apply all saved settings to frames
    self:ScheduleTimer(function()
        -- Apply settings after frames are created
        if QM.ApplyAllSettingsOnLoad then
            QM:ApplyAllSettingsOnLoad()
        end

        -- Hide the default Blizzard tracker if the user opted in
        if QM.ApplyBlizzardTrackerVisibility then
            QM:ApplyBlizzardTrackerVisibility()
        end

        QM:UpdateAllQuests()
        QM:UpdateTracker()
        QM:UpdateMapPins()
    end, 2)

    -- Startup message (only once per session)
    if not QM.startupMessageShown then
        QM.startupMessageShown = true
        self:ScheduleTimer(function()
            print(L["MSG_ADDON_LOADED"])
            print(L["MSG_TWITCH"])
            print(L["MSG_BUGS"])
        end, 4)
    end
end

function addon:QUEST_ACCEPTED(event, questIndex)
    local questTitle, _, _, _, _, _, _, questId = GetQuestLogTitle(questIndex)
    -- Fallback for clients where GetQuestLogTitle doesn't return questId
    if not questId and GetQuestID then
        SelectQuestLogEntry(questIndex)
        questId = GetQuestID()
    end

    -- Auto-track if enabled
    if QM.db.profile.tracker.autoTrack and questId then
        QM:TrackQuest(questId)
    end

    -- Start quest timer (save real time for persistence)
    if questId and QM.db.profile.questTimer.enabled then
        QM.questStartTimes[questId] = GetTime()
        QM.db.char.questStartTimes[questId] = time()
    end

    -- Announce quest accept
    if QM.db.profile.announce.accept and questTitle then
        -- Print locally
        print(string.format(L["MSG_PREFIX"] .. " " .. L["MSG_QUEST_ACCEPTED"] .. " |cFFFFD700%s|r", questTitle))
        -- Send to chat channel (PARTY/GUILD work, SAY requires hardware event)
        local channel = QM.db.profile.announce.acceptChannel or "PARTY"
        if channel ~= "NONE" then
            SendChatMessage(string.format(L["MSG_QUEST_ACCEPTED"] .. " %s", questTitle), channel)
        end
    end

    -- Auto-share quest with party if enabled
    if QM.db.profile.auto.shareQuests and questIndex then
        local numParty = GetNumGroupMembers and GetNumGroupMembers() or (GetNumPartyMembers and GetNumPartyMembers() or 0)
        if numParty > 0 then
            SelectQuestLogEntry(questIndex)
            if QuestLogPushQuest then
                QuestLogPushQuest()
            end
        end
    end

    -- Broadcast quest accepted to party
    if questId and questTitle then
        QM:BroadcastQuestAccepted(questId, questTitle)
    end

    -- Invalidate available quest pin cache (quest no longer available)
    if QM.InvalidateAvailableQuestCache then
        QM:InvalidateAvailableQuestCache()
    end

    ScheduleUpdate()
end

function addon:QUEST_REMOVED(event, questId)
    QM:UntrackQuest(questId)
    -- Invalidate available quest pin cache (quest may be available again)
    if QM.InvalidateAvailableQuestCache then
        QM:InvalidateAvailableQuestCache()
    end
    ScheduleUpdate()
end

function addon:QUEST_LOG_UPDATE()
    -- Quest log changes typically need quest data + tracker + arrow, but not always map
    ScheduleUpdate({quests = true, tracker = true, arrow = true})

    -- Broadcast updated quest list to party (throttled internally)
    QM:BroadcastQuestList()
end

function addon:QUEST_WATCH_UPDATE(event, questIndex)
    QM:UpdateQuestObjectives(questIndex)
    QM:UpdateTracker()
    -- Immediately update arrow when objectives change (e.g., quest completed)
    QM:UpdateArrowTarget()
end

-- Party Quest Sync: receive addon messages from party members
function addon:CHAT_MSG_ADDON(event, prefix, message, channel, sender)
    QM:OnPartySyncMessage(prefix, message, channel, sender)
end

-- Party Quest Sync: handle group roster changes
function addon:GROUP_ROSTER_UPDATE()
    if GetNumGroupMembers() > 0 then
        QM:CleanupPartyData()
        -- Broadcast quest list to new party members
        C_Timer.After(3, function()
            QM:BroadcastQuestList()
        end)
    else
        QM:OnGroupLeft()
    end
end

function addon:QUEST_TURNED_IN(event, questId, xpReward, moneyReward)
    -- Get quest info before untracking
    local quest = QM.activeQuests[questId]
    local questTitle = quest and quest.title or L["UNKNOWN_QUEST"]
    local questLevel = quest and quest.level or 0

    -- Calculate quest duration for history
    local duration = 0
    if QM.questStartTimes[questId] then
        duration = GetTime() - QM.questStartTimes[questId]
    end

    -- Add to quest history
    if QM.db.profile.questHistory.enabled then
        QM:AddToQuestHistory(questId, questTitle, questLevel, xpReward or 0, duration)
    end

    -- Track best time for this quest
    if duration > 0 then
        QM:UpdateQuestBestTime(questId, questTitle, duration)
    end

    -- Track zone progress
    if quest then
        local zoneName = QM:GetQuestZone(quest)
        QM:UpdateZoneProgress(zoneName, questId)
    end

    -- Announce quest completion in chat (PARTY/GUILD work, SAY requires hardware event)
    if QM.db.profile.announce.complete then
        local channel = QM.db.profile.announce.completeChannel or "PARTY"
        if channel ~= "NONE" then
            local sayMsg = L["MSG_QUEST_COMPLETED"] .. " " .. questTitle
            if duration > 60 then
                sayMsg = sayMsg .. " (" .. QM:FormatPlayTime(duration) .. ")"
            end
            SendChatMessage(sayMsg, channel)
        end
    end

    -- Broadcast quest completion to party
    QM:BroadcastQuestComplete(questId, questTitle)

    -- Invalidate available quest pin cache
    if QM.InvalidateAvailableQuestCache then
        QM:InvalidateAvailableQuestCache()
    end

    -- Clear quest timer
    QM.questStartTimes[questId] = nil
    if QM.db.char.questStartTimes then
        QM.db.char.questStartTimes[questId] = nil
    end

    -- Track XP for XP/Hour
    if xpReward and xpReward > 0 and QM.db.char.xpData then
        QM.db.char.xpData.questsCompleted = (QM.db.char.xpData.questsCompleted or 0) + 1
        QM.db.char.xpData.xpGained = (QM.db.char.xpData.xpGained or 0) + xpReward
    end

    -- Track quest statistics
    if QM.db.profile.statistics.enabled then
        QM:TrackQuestCompletion(questId, questTitle, questLevel, xpReward or 0, duration, quest)
    end

    QM:UntrackQuest(questId)
    ScheduleUpdate()
end

function addon:UNIT_QUEST_LOG_CHANGED(event, unit)
    if unit == "player" then
        -- Typically objective progress, needs quest + tracker + arrow
        ScheduleUpdate({quests = true, tracker = true, arrow = true})
    end
end

function addon:ZONE_CHANGED_NEW_AREA()
    -- Invalidate position cache on zone change
    QM:InvalidatePlayerPositionCache()
    -- Zone changed, update map pins
    QM:UpdateMapPins()
    QM:UpdateArrowTarget()
end

function addon:ZONE_CHANGED()
    -- Invalidate position cache on subzone change
    QM:InvalidatePlayerPositionCache()
    -- Subzone changed
    QM:UpdateArrowTarget()
end

function addon:PLAYER_LEVEL_UP(event, newLevel)
    -- Announce level up with time played at this level
    if QM.db.profile.announce.levelUp then
        local timeSpent = 0
        if QM.levelStartTime then
            timeSpent = GetTime() - QM.levelStartTime
        end

        -- Format time for level up (hours and minutes only)
        local timeStr = QM:FormatLevelUpTime(timeSpent)
        local oldLevel = QM.lastLevel or (newLevel - 1)

        -- Print to player's chat frame
        print(string.format(L["MSG_PREFIX"] .. " |cFFFFD700" .. L["MSG_LEVEL_UP"] .. "|r " .. L["MSG_REACHED_LEVEL"], newLevel))
        if timeSpent > 60 then
            print(string.format(L["MSG_PREFIX"] .. " " .. L["MSG_TIME_FROM_LEVEL"] .. " |cFFFFD700%s|r", oldLevel, newLevel, timeStr))
        end

        -- Send to chat if enabled (EMOTE/PARTY/GUILD work without hardware event)
        if QM.db.profile.announce.levelUpChat then
            local channel = QM.db.profile.announce.levelUpChannel or "EMOTE"
            if channel ~= "NONE" then
                local chatMsg
                if timeSpent > 60 then
                    chatMsg = string.format(L["MSG_REACHED_LEVEL"] .. " (%s from level %d)", newLevel, timeStr, oldLevel)
                else
                    chatMsg = string.format(L["MSG_REACHED_LEVEL"], newLevel)
                end
                SendChatMessage(chatMsg, channel)
            end
        end
    end

    -- Invalidate available quest pin cache (new quests may be available at new level)
    if QM.InvalidateAvailableQuestCache then
        QM:InvalidateAvailableQuestCache()
    end

    -- Reset timer for next level and save to database
    QM.lastLevel = newLevel
    QM.levelStartTime = GetTime()
    QM.db.char.levelTimeData = {
        level = newLevel,
        startTime = time(),  -- Unix timestamp when this level started
    }
end

-- ============================================================================
-- Automation Event Handlers
-- ============================================================================

function addon:QUEST_DETAIL()
    -- Auto-accept quests if enabled
    if QM.db.profile.auto.acceptQuests and not IsShiftKeyDown() then
        AcceptQuest()

        -- Announce if enabled
        if QM.db.profile.announce.accept then
            local questTitle = GetTitleText()
            print(L["MSG_PREFIX"] .. " " .. L["MSG_ACCEPTED_QUEST"] .. " " .. questTitle)
        end
    end
end

function addon:QUEST_PROGRESS()
    -- Auto-continue quest dialog if quest is complete
    if QM.db.profile.auto.completeQuests and not IsShiftKeyDown() then
        if IsQuestCompletable() then
            CompleteQuest()
        end
    end
end

function addon:QUEST_COMPLETE()
    -- Auto-complete quest if enabled
    if QM.db.profile.auto.completeQuests and not IsShiftKeyDown() then
        -- Check if there's reward choice
        local numRewards = GetNumQuestChoices()
        if numRewards > 1 and QM.db.profile.auto.skipRewardChoice then
            -- Don't auto-complete if player needs to pick a reward
            return
        end

        -- Complete the quest
        if numRewards <= 1 then
            GetQuestReward(1)
        end
    end
end

function addon:GOSSIP_SHOW()
    -- Auto-accept available quests from gossip
    if QM.db.profile.auto.acceptQuests and not IsShiftKeyDown() then
        -- Check for new C_GossipInfo API first (TBC Anniversary), fallback to classic API
        if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
            local availableQuests = C_GossipInfo.GetAvailableQuests()
            if availableQuests and #availableQuests > 0 then
                C_GossipInfo.SelectAvailableQuest(availableQuests[1].questID)
                return
            end

            -- Check for active quests to turn in
            local activeQuests = C_GossipInfo.GetActiveQuests()
            if activeQuests then
                for _, quest in ipairs(activeQuests) do
                    if quest.isComplete then
                        C_GossipInfo.SelectActiveQuest(quest.questID)
                        return
                    end
                end
            end
        elseif GetGossipAvailableQuests then
            -- TBC Classic API: GetGossipAvailableQuests returns packed values
            -- title, level, isTrivial, isDaily, isRepeatable, ...
            local availableQuests = {GetGossipAvailableQuests()}
            local numAvailable = #availableQuests / 5  -- 5 values per quest in TBC

            if numAvailable > 0 then
                -- Select first available quest
                SelectGossipAvailableQuest(1)
                return
            end

            -- Check for active quests to turn in
            -- TBC Classic API: GetGossipActiveQuests returns packed values
            -- title, level, isComplete, isLegendary, ...
            local activeQuests = {GetGossipActiveQuests()}
            local numActive = #activeQuests / 4  -- 4 values per quest in TBC

            for i = 1, numActive do
                local offset = (i - 1) * 4
                local isComplete = activeQuests[offset + 3]
                if isComplete then
                    SelectGossipActiveQuest(i)
                    return
                end
            end
        end
    end
end

-- ============================================================================
-- Dungeon Zone Detection
-- ============================================================================

-- Known TBC dungeon zone IDs (mapId -> dungeon name)
local DUNGEON_ZONES = {
    -- Classic Dungeons
    [1581] = "Deadmines",
    [1583] = "Blackfathom Deeps",
    [1584] = "Blackrock Depths",
    [1585] = "Blackrock Spire",
    [1580] = "Gnomeregan",
    [1586] = "Dire Maul",
    [1587] = "Maraudon",
    [1588] = "Uldaman",
    [1589] = "Razorfen Kraul",
    [1590] = "Razorfen Downs",
    [1591] = "Scarlet Monastery",
    [1592] = "Scholomance",
    [1593] = "Shadowfang Keep",
    [1594] = "Stratholme",
    [1595] = "Sunken Temple",
    [1596] = "Wailing Caverns",
    [1597] = "Zul'Farrak",
    -- TBC Dungeons
    [1944] = "Hellfire Ramparts",
    [1945] = "The Blood Furnace",
    [1946] = "The Shattered Halls",
    [1947] = "The Slave Pens",
    [1948] = "The Underbog",
    [1949] = "The Steamvault",
    [1950] = "Mana-Tombs",
    [1951] = "Auchenai Crypts",
    [1952] = "Sethekk Halls",
    [1953] = "Shadow Labyrinth",
    [1954] = "Old Hillsbrad Foothills",
    [1955] = "The Black Morass",
    [1956] = "The Mechanar",
    [1957] = "The Botanica",
    [1958] = "The Arcatraz",
    [1959] = "Magisters' Terrace",
    -- TBC Raids
    [1960] = "Karazhan",
    [1961] = "Gruul's Lair",
    [1962] = "Magtheridon's Lair",
    [1963] = "Serpentshrine Cavern",
    [1964] = "Tempest Keep",
    [1965] = "Hyjal Summit",
    [1966] = "Black Temple",
    [1967] = "Sunwell Plateau",
    [1968] = "Zul'Aman",
}

-- Reverse lookup: quest start NPC zone -> is it a dungeon?
function QM:IsQuestInDungeon(questId)
    if not QM.DB then return false end
    local dbQuest = QM.DB:GetQuest(questId)
    if not dbQuest then return false end

    -- Check if any quest objective creatures/objects are in dungeon zones
    if dbQuest.objectives then
        -- Check creature goals (goals[1])
        if dbQuest.objectives[1] then
            for _, goal in ipairs(dbQuest.objectives[1]) do
                local npcId = goal[1]
                if npcId then
                    local spawns = QM.DB:GetNPCSpawnLocations(npcId)
                    if spawns then
                        for _, spawn in ipairs(spawns) do
                            if spawn.mapId and DUNGEON_ZONES[spawn.mapId] then
                                return true
                            end
                        end
                    end
                end
            end
        end
        -- Check object goals (goals[2])
        if dbQuest.objectives[2] then
            for _, goal in ipairs(dbQuest.objectives[2]) do
                local objId = goal[1]
                if objId then
                    local spawns = QM.DB:GetObjectSpawnLocations(objId)
                    if spawns then
                        for _, spawn in ipairs(spawns) do
                            if spawn.mapId and DUNGEON_ZONES[spawn.mapId] then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

-- Get dungeon name for a quest (if it's a dungeon quest)
function QM:GetQuestDungeonName(questId)
    if not QM.DB then return nil end
    local dbQuest = QM.DB:GetQuest(questId)
    if not dbQuest or not dbQuest.objectives then return nil end

    -- Check creature goals
    if dbQuest.objectives[1] then
        for _, goal in ipairs(dbQuest.objectives[1]) do
            local npcId = goal[1]
            if npcId then
                local spawns = QM.DB:GetNPCSpawnLocations(npcId)
                if spawns then
                    for _, spawn in ipairs(spawns) do
                        if spawn.mapId and DUNGEON_ZONES[spawn.mapId] then
                            return DUNGEON_ZONES[spawn.mapId]
                        end
                    end
                end
            end
        end
    end
    -- Check object goals
    if dbQuest.objectives[2] then
        for _, goal in ipairs(dbQuest.objectives[2]) do
            local objId = goal[1]
            if objId then
                local spawns = QM.DB:GetObjectSpawnLocations(objId)
                if spawns then
                    for _, spawn in ipairs(spawns) do
                        if spawn.mapId and DUNGEON_ZONES[spawn.mapId] then
                            return DUNGEON_ZONES[spawn.mapId]
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- ============================================================================
-- Quest Management
-- ============================================================================

function QM:UpdateAllQuests()
    -- Re-entry guard: prevent double-wipe when ExpandQuestHeader triggers QUEST_LOG_UPDATE
    -- Safety: auto-reset after 2 seconds in case of Lua error during scan
    if self._scanningQuestLog then
        if self._scanStartTime and (GetTime() - self._scanStartTime) < 2 then
            return
        end
    end
    self._scanningQuestLog = true
    self._scanStartTime = GetTime()

    wipe(self.activeQuests)
    wipe(self.questObjectives)

    -- Collapsed quest log headers hide their child quests from the API.
    -- We must expand all headers before scanning, then restore collapsed state.
    local collapsedHeaders = {}
    local needsRestore = false
    local numEntries = GetNumQuestLogEntries()

    -- Record which headers are collapsed (by title, since indices shift)
    if ExpandQuestHeader then
        for i = 1, numEntries do
            local title, _, _, isHeader, isCollapsed = GetQuestLogTitle(i)
            if isHeader and isCollapsed then
                collapsedHeaders[title] = true
                needsRestore = true
            end
        end

        -- Expand all headers at once (index 0 = expand all)
        if needsRestore then
            ExpandQuestHeader(0)
            numEntries = GetNumQuestLogEntries()

            -- Verify expansion worked; if not, expand individually
            if numEntries == 0 then
                numEntries = GetNumQuestLogEntries()
            end
        end
    end

    local currentHeaderZone = ""
    for i = 1, numEntries do
        local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questId = GetQuestLogTitle(i)

        if isHeader then
            -- Quest log headers are zone names - track for zone filter
            currentHeaderZone = title or ""
        end

        -- Fallback: if questId is nil, try to get it from SelectQuestLogEntry + GetQuestID
        if not isHeader and not questId then
            if GetQuestID then
                SelectQuestLogEntry(i)
                questId = GetQuestID()
            end
        end

        if not isHeader and questId and questId ~= 0 then
            -- Determine quest type from suggestedGroup
            local isDungeon = false
            local isRaid = false
            local isGroup = false
            if suggestedGroup then
                if type(suggestedGroup) == "string" then
                    local sg = suggestedGroup:lower()
                    if sg == "raid" then
                        isRaid = true
                    elseif sg == "dungeon" then
                        isDungeon = true
                        isGroup = true
                    elseif sg ~= "" then
                        isGroup = true
                    end
                elseif type(suggestedGroup) == "number" then
                    if suggestedGroup >= 5 then
                        isRaid = true
                    elseif suggestedGroup >= 2 then
                        isGroup = true
                        isDungeon = self:IsQuestInDungeon(questId)
                    end
                end
            end

            local quest = {
                id = questId,
                title = title,
                level = level,
                index = i,
                logIndex = i,
                isComplete = isComplete,
                suggestedGroup = suggestedGroup or 0,
                isDungeon = isDungeon,
                isRaid = isRaid,
                isGroup = isGroup,
                zone = currentHeaderZone,
                objectives = {},
            }

            -- Get objectives
            local numObjectives = GetNumQuestLeaderBoards(i)
            for j = 1, numObjectives do
                local text, objectiveType, finished = GetQuestLogLeaderBoard(j, i)
                if text then
                    local current, required, description = self:ParseObjectiveText(text)

                    table.insert(quest.objectives, {
                        index = j,
                        text = text,
                        type = objectiveType,
                        finished = finished,
                        current = current,
                        required = required,
                        description = description,
                    })
                end
            end

            self.activeQuests[questId] = quest
            self.questObjectives[questId] = quest.objectives

            -- Check for progress changes (sounds/announcements)
            self:CheckQuestProgress(questId, quest)
        end
    end

    -- Restore originally collapsed headers
    if needsRestore and CollapseQuestHeader then
        numEntries = GetNumQuestLogEntries()
        for i = numEntries, 1, -1 do
            local title, _, _, isHeader = GetQuestLogTitle(i)
            if isHeader and collapsedHeaders[title] then
                CollapseQuestHeader(i)
            end
        end
    end

    self._scanningQuestLog = false
end

function QM:ParseObjectiveText(text)
    if not text then return nil, nil, text end

    local current, required, description

    -- Try to parse "X/Y Description" format (e.g., "3/8 Kill Boars")
    current, required, description = text:match("^(%d+)/(%d+)%s+(.+)")
    if current and required then
        return tonumber(current), tonumber(required), description
    end

    -- Try to parse "X/Y" at the end (e.g., "Boars slain: 3/8" or "Eber getötet: 3/8")
    description, current, required = text:match("(.+):%s*(%d+)/(%d+)%s*$")
    if current and required then
        return tonumber(current), tonumber(required), description
    end

    -- Try to parse "Description (X/Y)" format
    description, current, required = text:match("(.+)%s*%((%d+)/(%d+)%)")
    if current and required then
        return tonumber(current), tonumber(required), description
    end

    -- Try to find any X/Y pattern in the text
    current, required = text:match("(%d+)/(%d+)")
    if current and required then
        -- Remove the X/Y from description
        description = text:gsub("%d+/%d+", ""):gsub("^%s*:%s*", ""):gsub("%s*:%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if description == "" then description = text end
        return tonumber(current), tonumber(required), description
    end

    return nil, nil, text
end

function QM:UpdateQuestObjectives(questIndex)
    local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questId = GetQuestLogTitle(questIndex)

    -- Fallback for clients where GetQuestLogTitle doesn't return questId
    if not isHeader and not questId and GetQuestID then
        SelectQuestLogEntry(questIndex)
        questId = GetQuestID()
    end

    if not isHeader and questId and self.activeQuests[questId] then
        local quest = self.activeQuests[questId]
        quest.isComplete = isComplete
        wipe(quest.objectives)

        local numObjectives = GetNumQuestLeaderBoards(questIndex)
        for j = 1, numObjectives do
            local text, objectiveType, finished = GetQuestLogLeaderBoard(j, questIndex)
            if text then
                local current, required, description = self:ParseObjectiveText(text)

                table.insert(quest.objectives, {
                    index = j,
                    text = text,
                    type = objectiveType,
                    finished = finished,
                    current = current,
                    required = required,
                    description = description,
                })
            end
        end

        self.questObjectives[questId] = quest.objectives

        -- Invalidate location cache for this quest
        if self.InvalidateQuestLocationCache then
            self:InvalidateQuestLocationCache(questId)
        end
    end
end

function QM:TrackQuest(questId)
    if not self.trackedQuestIds[questId] then
        self.trackedQuestIds[questId] = true
        self.db.char.trackedQuests[questId] = true
    end
end

function QM:UntrackQuest(questId)
    self.trackedQuestIds[questId] = nil
    self.db.char.trackedQuests[questId] = nil

    -- Clear waypoint if this quest was targeted
    if self.currentWaypoint and self.currentWaypoint.questId == questId then
        self.currentWaypoint = nil
        self:UpdateArrow()
    end
end

function QM:IsQuestTracked(questId)
    return self.trackedQuestIds[questId] or false
end

function QM:SetWaypoint(questId, objectiveIndex, x, y, mapId, description, isManual)
    -- Validate coordinates
    if not x or not y or not mapId then
        return false
    end

    -- Validate coordinate ranges (0-100 for zone coordinates)
    if x < 0 or x > 100 or y < 0 or y > 100 then
        return false
    end

    -- Validate mapId is a valid number
    if type(mapId) ~= "number" or mapId <= 0 then
        return false
    end

    self.currentWaypoint = {
        questId = questId,
        objectiveIndex = objectiveIndex,
        x = x,
        y = y,
        mapId = mapId,
        description = description or L["QUEST_OBJECTIVE"],
    }

    -- Mark as manual waypoint if user clicked on map/tracker
    -- This prevents auto-select from overriding it
    self.manualWaypoint = isManual or false

    self:UpdateArrow()
    -- Update tracker to refresh quest highlighting
    if self.UpdateTracker then
        self:UpdateTracker()
    end

    return true
end

function QM:ClearWaypoint()
    self.currentWaypoint = nil
    self.manualWaypoint = false
    self:UpdateArrow()
end

function QM:ResetFramePositions()
    -- Reset arrow position
    self.db.profile.arrow.x = 0
    self.db.profile.arrow.y = -150
    self.db.profile.arrow.point = "TOP"

    -- Reset tracker position
    self.db.profile.tracker.x = -20
    self.db.profile.tracker.y = -200
    self.db.profile.tracker.point = "TOPRIGHT"

    -- Update frames
    self:UpdateArrowSettings()
    self:UpdateTrackerSettings()
end

-- ============================================================================
-- Utility Functions
-- ============================================================================

-- Player position cache (reduces C_Map calls by ~90%)
local cachedPlayerX, cachedPlayerY, cachedPlayerMapId
local lastPlayerPosUpdate = 0
local PLAYER_POS_CACHE_TTL = 0.15  -- Update every 0.15 seconds max

-- World coordinate cache for static target locations (avoids repeated HBD conversions)
local worldCoordCache = {}

-- Player world coordinate cache (same within a single update cycle)
local cachedPlayerWorldX, cachedPlayerWorldY, lastPlayerWorldUpdate = nil, nil, 0

function QM:GetPlayerPosition(forceRefresh)
    local now = GetTime()

    -- Return cached position if still valid
    if not forceRefresh and cachedPlayerX and (now - lastPlayerPosUpdate) < PLAYER_POS_CACHE_TTL then
        return cachedPlayerX, cachedPlayerY, cachedPlayerMapId
    end

    -- Refresh cache
    local mapId = C_Map.GetBestMapForUnit("player")
    if not mapId then return nil, nil, nil end

    local position = C_Map.GetPlayerMapPosition(mapId, "player")
    if not position then return nil, nil, mapId end

    -- Update cache
    cachedPlayerX, cachedPlayerY, cachedPlayerMapId = position.x, position.y, mapId
    lastPlayerPosUpdate = now

    return cachedPlayerX, cachedPlayerY, cachedPlayerMapId
end

-- Invalidate player position cache (call on zone change)
function QM:InvalidatePlayerPositionCache()
    cachedPlayerX, cachedPlayerY, cachedPlayerMapId = nil, nil, nil
    cachedPlayerWorldX, cachedPlayerWorldY = nil, nil
    lastPlayerPosUpdate = 0
    lastPlayerWorldUpdate = 0
end

function QM:GetDistanceToPoint(x, y, mapId)
    if not x or not y or not mapId then return nil end

    local playerX, playerY, playerMapId = self:GetPlayerPosition()
    if not playerX or not playerY then return nil end

    -- Cache player world coordinates within same update cycle
    local now = lastPlayerPosUpdate  -- Use same timestamp as position cache
    if now ~= lastPlayerWorldUpdate or not cachedPlayerWorldX then
        cachedPlayerWorldX, cachedPlayerWorldY = HBD:GetWorldCoordinatesFromZone(playerX, playerY, playerMapId)
        lastPlayerWorldUpdate = now
    end
    if not cachedPlayerWorldX then return nil end

    -- Cache world coordinates for static target locations
    local cacheKey = mapId * 100000000 + math.floor(x * 10000) * 10000 + math.floor(y * 10000)
    local cached = worldCoordCache[cacheKey]
    local targetWorldX, targetWorldY
    if cached then
        targetWorldX, targetWorldY = cached[1], cached[2]
    else
        targetWorldX, targetWorldY = HBD:GetWorldCoordinatesFromZone(x, y, mapId)
        if targetWorldX then
            worldCoordCache[cacheKey] = {targetWorldX, targetWorldY}
        end
    end

    if not targetWorldX then return nil end

    -- Inline distance calculation (avoid HBD function call overhead)
    local dx = cachedPlayerWorldX - targetWorldX
    local dy = cachedPlayerWorldY - targetWorldY
    return (dx * dx + dy * dy) ^ 0.5
end

function QM:GetAngleToPoint(x, y, mapId)
    if not x or not y or not mapId then return nil end

    local playerX, playerY, playerMapId = self:GetPlayerPosition()
    if not playerX or not playerY then return nil end

    local playerWorldX, playerWorldY = HBD:GetWorldCoordinatesFromZone(playerX, playerY, playerMapId)
    local targetWorldX, targetWorldY = HBD:GetWorldCoordinatesFromZone(x, y, mapId)

    if not playerWorldX or not targetWorldX then return nil end

    local angle = math.atan2(targetWorldY - playerWorldY, targetWorldX - playerWorldX)
    return angle
end

function QM:FormatDistance(yards, compact)
    if not yards then return "?" end

    local unit = self.db and self.db.profile.arrow.distanceUnit or "yards"

    if unit == "meters" then
        local value = yards * 0.9144 -- Convert yards to meters
        if compact and value >= 1000 then
            return string.format("%.1fk m", value / 1000)
        end
        return string.format("%.0f %s", value, L and L["METERS"] or "m")
    else
        if compact and yards >= 1000 then
            return string.format("%.1fk yd", yards / 1000)
        end
        return string.format("%.0f %s", yards, L and L["YARDS"] or "yd")
    end
end

-- Get color based on distance (consolidated from Tracker:GetDistanceColor)
function QM:GetDistanceColor(yards)
    if not yards then return 0.6, 0.6, 0.6 end
    if yards < 50 then
        return 0.3, 1, 0.3      -- Green - very close
    elseif yards < 150 then
        return 0.6, 1, 0.3      -- Yellow-green - close
    elseif yards < 500 then
        return 1, 0.9, 0.3      -- Yellow - medium
    elseif yards < 1000 then
        return 1, 0.6, 0.2      -- Orange - far
    else
        return 0.8, 0.4, 0.2    -- Red-orange - very far
    end
end

function QM:FormatPlayTime(seconds)
    if not seconds or seconds < 0 then return "0s" end

    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    if hours > 0 then
        return string.format("%dh %dm %ds", hours, mins, secs)
    elseif mins > 0 then
        return string.format("%dm %ds", mins, secs)
    else
        return string.format("%ds", secs)
    end
end

-- Format time for level up announcements (hours and minutes only)
function QM:FormatLevelUpTime(seconds)
    if not seconds or seconds < 0 then return "0 min" end

    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)

    if hours > 0 then
        if mins > 0 then
            return string.format("%dh %dmin", hours, mins)
        else
            return string.format("%dh", hours)
        end
    else
        return string.format("%d min", mins)
    end
end

-- Format large numbers with k/m suffix
function QM:FormatNumber(num)
    if not num then return "0" end
    if num >= 1000000 then
        return string.format("%.1fm", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fk", num / 1000)
    else
        return tostring(math.floor(num))
    end
end

-- Get color code for reputation standing
function QM:GetStandingColor(standingId)
    local colors = {
        [1] = "|cFFCC0000",  -- Hated (red)
        [2] = "|cFFFF0000",  -- Hostile (red)
        [3] = "|cFFFF4400",  -- Unfriendly (orange-red)
        [4] = "|cFFFFFF00",  -- Neutral (yellow)
        [5] = "|cFF00FF00",  -- Friendly (green)
        [6] = "|cFF00FF88",  -- Honored (teal)
        [7] = "|cFF00AAFF",  -- Revered (blue)
        [8] = "|cFFFF00FF",  -- Exalted (purple/magenta)
    }
    return colors[standingId] or "|cFFFFFFFF"
end

-- Difficulty color cache (invalidated on level up)
local difficultyColorCache = {}
local cachedPlayerLevel = 0

-- Invalidate difficulty color cache (call on level up)
function QM:InvalidateDifficultyColorCache()
    wipe(difficultyColorCache)
    cachedPlayerLevel = 0
end

-- Unified quest difficulty color function (with caching)
function QM:GetQuestDifficultyColor(questLevel)
    local playerLevel = UnitLevel("player")

    -- Invalidate cache if player leveled up
    if playerLevel ~= cachedPlayerLevel then
        wipe(difficultyColorCache)
        cachedPlayerLevel = playerLevel
    end

    -- Return cached color if available
    local cacheKey = questLevel or 0
    if difficultyColorCache[cacheKey] then
        return difficultyColorCache[cacheKey]
    end

    -- Calculate color
    local diff = (questLevel or playerLevel) - playerLevel
    local greenRange = GetQuestGreenRange and GetQuestGreenRange() or 8
    local color

    if diff >= 5 then
        color = {r = 1, g = 0.1, b = 0.1}      -- Red
    elseif diff >= 3 then
        color = {r = 1, g = 0.5, b = 0.25}     -- Orange
    elseif diff >= -2 then
        color = {r = 1, g = 1, b = 0}          -- Yellow
    elseif diff >= -greenRange then
        color = {r = 0.25, g = 0.75, b = 0.25} -- Green
    else
        color = {r = 0.5, g = 0.5, b = 0.5}    -- Gray
    end

    -- Cache and return
    difficultyColorCache[cacheKey] = color
    return color
end

-- Wrapper for backwards compatibility (returns r,g,b instead of table)
function QM:GetQuestColor(quest)
    if not quest then return 1, 1, 1 end
    local color = self:GetQuestDifficultyColor(quest.level)
    return color.r, color.g, color.b
end

function QM:GetObjectiveIcon(objectiveType)
    if objectiveType == "monster" or objectiveType == "kill" then
        return "Interface\\Icons\\Ability_Dualwield"
    elseif objectiveType == "item" or objectiveType == "loot" then
        return "Interface\\Icons\\INV_Misc_Bag_08"
    elseif objectiveType == "object" then
        return "Interface\\Icons\\INV_Misc_EngGizmos_20"
    elseif objectiveType == "event" then
        return "Interface\\Icons\\Spell_Holy_MindVision"
    else
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end
end

-- ============================================================================
-- Sound Functions
-- ============================================================================

-- Sound file IDs for different events
local SOUNDS = {
    progress = SOUNDKIT.UI_BONUS_EVENT_SYSTEM_VIGNETTES or 888,   -- Quest progress
    complete = SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12867,           -- Quest ready to turn in
    objectiveComplete = SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01 or 618, -- Objective done
}

function QM:PlayProgressSound()
    if QM.db.profile.sounds.progress then
        PlaySound(SOUNDS.progress, "Master")
    end
end

function QM:PlayCompleteSound()
    if QM.db.profile.sounds.complete then
        PlaySound(SOUNDS.complete, "Master")
    end
end

function QM:PlayObjectiveCompleteSound()
    if QM.db.profile.sounds.objectiveComplete then
        PlaySound(SOUNDS.objectiveComplete, "Master")
    end
end

-- ============================================================================
-- Tooltip Functions
-- ============================================================================

function QM:InitializeTooltipHooks()
    -- Hook GameTooltip to add quest info
    if QM.db.profile.tooltips.enabled then
        GameTooltip:HookScript("OnTooltipSetUnit", function(self)
            QM:OnTooltipSetUnit(self)
        end)

        GameTooltip:HookScript("OnTooltipSetItem", function(self)
            QM:OnTooltipSetItem(self)
        end)
    end
end

function QM:OnTooltipSetUnit(tooltip)
    if not QM.db.profile.tooltips.enabled then return end

    local name, unit = tooltip:GetUnit()
    if not unit then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    -- Get NPC ID from GUID
    local npcId = select(6, strsplit("-", guid))
    npcId = tonumber(npcId)
    if not npcId then return end

    -- Check if this NPC is needed for any quest
    local questsNeedingNPC = {}
    if not self.activeQuests then return end
    for questId, quest in pairs(self.activeQuests) do
        local locs = self:GetQuestObjectiveLocationsFixed(questId)
        if locs then
            for i, obj in ipairs(quest.objectives) do
                if not obj.finished and obj.type == "monster" then
                    -- Check if objective mentions this NPC
                    if obj.description and name and obj.description:lower():find(name:lower()) then
                        table.insert(questsNeedingNPC, {
                            quest = quest,
                            objective = obj,
                        })
                    end
                end
            end
        end
    end

    -- Add quest info to tooltip
    if #questsNeedingNPC > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cFFFFD700QuestMaster|r", 1, 0.82, 0)
        for _, info in ipairs(questsNeedingNPC) do
            local questTitle = info.quest.title
            local objText = info.objective.text or info.objective.description or ""
            tooltip:AddLine("|cFF00FF00" .. questTitle .. "|r", 0, 1, 0)
            if QM.db.profile.tooltips.showObjectives then
                tooltip:AddLine("  " .. objText, 0.8, 0.8, 0.8)
            end
        end
        tooltip:Show()
    end
end

function QM:OnTooltipSetItem(tooltip)
    if not QM.db.profile.tooltips.enabled then return end

    local itemName, itemLink = tooltip:GetItem()
    if not itemName then return end

    -- Check if this item is needed for any quest
    local questsNeedingItem = {}
    if not self.activeQuests then return end
    for questId, quest in pairs(self.activeQuests) do
        for i, obj in ipairs(quest.objectives) do
            if not obj.finished and (obj.type == "item" or obj.type == "object") then
                if obj.description and obj.description:lower():find(itemName:lower()) then
                    table.insert(questsNeedingItem, {
                        quest = quest,
                        objective = obj,
                    })
                end
            end
        end
    end

    -- Add quest info to tooltip
    if #questsNeedingItem > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cFFFFD700Quest Item|r", 1, 0.82, 0)
        for _, info in ipairs(questsNeedingItem) do
            local questTitle = info.quest.title
            local objText = info.objective.text or ""
            local progress = ""
            if info.objective.current and info.objective.required then
                progress = string.format(" (%d/%d)", info.objective.current, info.objective.required)
            end
            tooltip:AddLine("|cFF00FF00" .. questTitle .. "|r" .. progress, 0, 1, 0)

            -- Show drop rate if enabled
            if QM.db.profile.tooltips.showDropRates then
                tooltip:AddLine("  |cFFAAAAAA(Estimated drop rate varies)|r", 0.6, 0.6, 0.6)
            end
        end
        tooltip:Show()
    end
end

-- ============================================================================
-- Quest Progress Tracking (for sounds and announcements)
-- ============================================================================

-- Store previous objective states
QM.previousObjectives = {}

function QM:CheckQuestProgress(questId, quest)
    if not self.previousObjectives[questId] then
        self.previousObjectives[questId] = {}
        return
    end

    local prevObjs = self.previousObjectives[questId]

    for i, obj in ipairs(quest.objectives) do
        local prevObj = prevObjs[i]
        if prevObj then
            -- Check if objective just completed
            if obj.finished and not prevObj.finished then
                self:PlayObjectiveCompleteSound()

                if QM.db.profile.announce.progress then
                    print(string.format(L["MSG_PREFIX"] .. " " .. L["MSG_OBJECTIVE_COMPLETE"] .. " %s", obj.text or ""))
                end

                -- Auto-advance waypoint if enabled AND current waypoint is NOT manual
                if QM.db.profile.auto.advanceWaypoint and not self.manualWaypoint then
                    self:AutoSelectBestWaypoint(true)
                end
            end
            -- Check if progress was made
            if obj.current and prevObj.current and obj.current > prevObj.current then
                self:PlayProgressSound()
            end
        end

        -- Store current state
        prevObjs[i] = {
            finished = obj.finished,
            current = obj.current,
            required = obj.required,
        }
    end

    -- Check if quest just completed
    if quest.isComplete and not self.previousObjectives[questId].questComplete then
        self:PlayCompleteSound()

        if QM.db.profile.announce.complete then
            print(L["MSG_PREFIX"] .. " " .. L["MSG_QUEST_READY"] .. " " .. quest.title)
        end

        -- Auto-navigate to turn-in or nearest quest (if not manual waypoint)
        if QM.db.profile.auto.advanceWaypoint and not self.manualWaypoint then
            self:AutoNavigateAfterCompletion(questId)
        end
    end
    self.previousObjectives[questId].questComplete = quest.isComplete
end

-- Auto-navigate to best target after quest completion
function QM:AutoNavigateAfterCompletion(completedQuestId)
    -- Get turn-in location for completed quest
    local turnInLoc = self:GetQuestTurnInLocation(completedQuestId)
    local turnInDist = math.huge

    if turnInLoc then
        turnInDist = self:GetDistanceToPoint(turnInLoc.x, turnInLoc.y, turnInLoc.mapId) or math.huge
    end

    -- Find nearest incomplete quest
    local nearestQuest, nearestQuestDist = nil, math.huge
    for questId, quest in pairs(self.activeQuests) do
        if not quest.isComplete and questId ~= completedQuestId then
            local dist = self:GetNearestObjectiveDistance(questId)
            if dist and dist < nearestQuestDist then
                nearestQuestDist = dist
                nearestQuest = quest
            end
        end
    end

    -- Choose closer target: turn-in or next quest
    if turnInDist <= nearestQuestDist and turnInLoc then
        -- Navigate to turn-in
        self:SetWaypointForQuest(completedQuestId)
        if QM.db.profile.debug then
            print(L["MSG_PREFIX"] .. " " .. L["MSG_AUTO_NAV_TURNIN"])
        end
    elseif nearestQuest then
        -- Navigate to nearest incomplete quest
        self:SetWaypointForQuest(nearestQuest.id)
        if QM.db.profile.debug then
            print(L["MSG_PREFIX"] .. " " .. L["MSG_AUTO_NAV_TO"] .. " " .. nearestQuest.title)
        end
    end
end

-- ============================================================================
-- Quest Timer Functions
-- ============================================================================

function QM:InitializeQuestTimers()
    -- Initialize timers for existing quests if not already tracked
    -- Use real time (time()) for persistence across sessions
    local now = time()
    for questId, _ in pairs(self.activeQuests) do
        if not self.questStartTimes[questId] then
            -- Quest was already in log before addon loaded - use saved time or current
            if self.db.char.questStartTimes and self.db.char.questStartTimes[questId] then
                -- Convert saved real time to GetTime offset
                local savedRealTime = self.db.char.questStartTimes[questId]
                local elapsed = now - savedRealTime
                self.questStartTimes[questId] = GetTime() - elapsed
            else
                -- No saved time, start from now
                self.questStartTimes[questId] = GetTime()
                self.db.char.questStartTimes[questId] = now
            end
        end
    end
end

function QM:GetQuestDuration(questId)
    if not questId or not self.questStartTimes[questId] then
        return nil
    end
    local duration = GetTime() - self.questStartTimes[questId]
    -- Sanity check - don't return negative or huge values
    if duration < 0 or duration > 604800 then -- 7 days max
        return nil
    end
    return duration
end

function QM:FormatQuestDuration(seconds)
    if not seconds or seconds < 0 then return "0s" end

    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    if hours > 0 then
        return string.format("%dh %dm", hours, mins)
    elseif mins > 0 then
        return string.format("%dm %ds", mins, secs)
    else
        return string.format("%ds", secs)
    end
end

-- ============================================================================
-- Quest Best Time Tracking
-- ============================================================================

function QM:UpdateQuestBestTime(questId, questTitle, duration)
    if not questId or not duration or duration <= 0 then return end

    -- Initialize best times table if needed
    if not self.db.char.questBestTimes then
        self.db.char.questBestTimes = {}
    end

    local existing = self.db.char.questBestTimes[questId]
    local isNewBest = false

    if not existing or duration < existing.duration then
        self.db.char.questBestTimes[questId] = {
            title = questTitle,
            duration = duration,
            date = time(),
        }
        isNewBest = existing ~= nil -- Only flag as "new best" if there was a previous time
    end

    -- Announce best time if it's a new personal record
    if isNewBest and self.db.profile.questTimer.enabled then
        local oldTime = QM:FormatQuestDuration(existing.duration)
        local newTime = QM:FormatQuestDuration(duration)
        print(string.format(
            L["MSG_PREFIX"] .. " " .. L["MSG_NEW_BEST_TIME"],
            questTitle, newTime, oldTime
        ))
    end
end

function QM:GetQuestBestTime(questId)
    if not questId or not self.db.char.questBestTimes then return nil end
    return self.db.char.questBestTimes[questId]
end

-- Refresh only the timer text elements in the tracker (lightweight, no full redraw)
function QM:RefreshQuestTimerDisplay()
    if not QM.Tracker then return end
    -- Trigger a tracker-only update to refresh timer text
    ScheduleUpdate({tracker = true})
end

-- ============================================================================
-- XP/Hour Tracker Functions
-- ============================================================================

function addon:PLAYER_XP_UPDATE()
    QM:UpdateXPPerHour()
end

function QM:UpdateXPPerHour()
    if not self.db.profile.xpTracker.enabled then return end

    local currentXP = UnitXP("player")
    local currentTime = GetTime()
    local sessionDuration = currentTime - self.sessionStartTime

    if sessionDuration > 0 then
        local xpGained = currentXP - self.sessionXPStart

        -- Account for level ups (XP resets)
        if xpGained < 0 then
            -- Level up occurred, adjust
            xpGained = currentXP + (UnitXPMax("player") - self.sessionXPStart)
            self.sessionXPStart = 0
        end

        -- Calculate XP per hour
        local hoursPlayed = sessionDuration / 3600
        if hoursPlayed > 0 then
            self.xpPerHour = math.floor(xpGained / hoursPlayed)
        end
    end

    self.lastXPUpdate = currentTime
end

function QM:GetXPPerHour()
    return self.xpPerHour or 0
end

function QM:GetTimeToLevel()
    local xpNeeded = UnitXPMax("player") - UnitXP("player")
    if self.xpPerHour and self.xpPerHour > 0 then
        local hoursToLevel = xpNeeded / self.xpPerHour
        return hoursToLevel * 3600 -- Return in seconds
    end
    return nil
end

function QM:FormatTimeToLevel()
    local seconds = self:GetTimeToLevel()
    if not seconds then return "N/A" end

    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)

    if hours > 0 then
        return string.format("%dh %dm", hours, mins)
    else
        return string.format("%dm", mins)
    end
end

function QM:ResetXPTracker()
    self.sessionStartTime = GetTime()
    self.sessionXPStart = UnitXP("player")
    self.xpPerHour = 0
    print(L["MSG_PREFIX"] .. " " .. L["MSG_XP_RESET"])
end

-- ============================================================================
-- Corpse Recovery Waypoint
-- ============================================================================

-- Store last known position before death
QM.lastAlivePosition = nil
QM.corpseWaypointSet = false

function addon:PLAYER_DEAD()
    if not QM.db.profile.auto.corpseWaypoint then return end

    -- Get player's death location
    local mapId = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapId then return end

    local pos = C_Map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapId, "player")
    if pos then
        local x, y = pos:GetXY()
        if x and y and x > 0 and y > 0 then
            QM.lastAlivePosition = {
                x = x,
                y = y,
                mapId = mapId,
                time = GetTime(),
            }

            -- Set waypoint to corpse
            QM:SetCorpseWaypoint()
        end
    end
end

function addon:PLAYER_ALIVE()
    -- Player released to graveyard - keep corpse waypoint active
end

function addon:PLAYER_UNGHOST()
    -- Player resurrected - clear corpse waypoint
    QM:ClearCorpseWaypoint()
end

function addon:PLAYER_REGEN_ENABLED()
    -- Combat ended - apply deferred Blizzard tracker visibility if needed
    if QM.db.profile.tracker.hideBlizzardTracker and QM.ApplyBlizzardTrackerVisibility then
        QM:ApplyBlizzardTrackerVisibility()
    end
end

function QM:SetCorpseWaypoint()
    if not self.lastAlivePosition then return end

    local pos = self.lastAlivePosition
    self.corpseWaypointSet = true

    -- Store current waypoint to restore later
    self.previousWaypoint = self.currentWaypoint

    -- Set waypoint to corpse
    self.currentWaypoint = {
        questId = 0,
        objectiveIndex = 0,
        x = pos.x,
        y = pos.y,
        mapId = pos.mapId,
        description = L["YOUR_CORPSE"],
        isCorpse = true,
    }

    print("|cFFFF0000QuestMaster:|r " .. L["MSG_WAYPOINT_CORPSE"])
    self:UpdateArrow()
end

function QM:ClearCorpseWaypoint()
    if not self.corpseWaypointSet then return end

    self.corpseWaypointSet = false
    self.lastAlivePosition = nil

    -- Restore previous waypoint if exists
    if self.previousWaypoint then
        self.currentWaypoint = self.previousWaypoint
        self.previousWaypoint = nil
        print(L["MSG_PREFIX"] .. " " .. L["MSG_WAYPOINT_RESTORED"])
    else
        self.currentWaypoint = nil
    end

    self:UpdateArrow()
end

-- ============================================================================
-- Rested XP Functions
-- ============================================================================

function QM:GetRestedXPInfo()
    local restedXP = GetXPExhaustion() or 0
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local isRested = restedXP > 0

    -- Calculate how much XP the rested bonus covers
    local restedPercent = 0
    if maxXP > 0 then
        restedPercent = math.floor((restedXP / maxXP) * 100)
    end

    -- Calculate bubbles (20 bubbles = 1 level, each bubble = 5%)
    local bubbles = math.floor(restedPercent / 5)

    return {
        amount = restedXP,
        percent = restedPercent,
        bubbles = bubbles,
        isRested = isRested,
        bonusMultiplier = isRested and 2 or 1,  -- Rested = 200% XP from kills
    }
end

function QM:FormatRestedXP()
    local info = self:GetRestedXPInfo()
    if not info.isRested then
        return nil  -- No rested XP
    end

    if info.amount >= 1000 then
        return string.format("%.1fk (%d%%)", info.amount / 1000, info.percent)
    else
        return string.format("%d (%d%%)", info.amount, info.percent)
    end
end

-- ============================================================================
-- Level Time Tracker Functions
-- ============================================================================

-- Store level times in char DB
QM.levelTimes = {}

function QM:GetLevelTimeData()
    if not self.db or not self.db.char then return {} end

    if not self.db.char.levelTimes then
        self.db.char.levelTimes = {}
    end

    return self.db.char.levelTimes
end

function QM:RecordLevelTime(level, timeSpent)
    local levelTimes = self:GetLevelTimeData()
    levelTimes[level] = {
        time = timeSpent,
        timestamp = time(),
    }
end

function QM:GetAverageLevelTime()
    local levelTimes = self:GetLevelTimeData()
    local total = 0
    local count = 0

    for _, data in pairs(levelTimes) do
        if data.time and data.time > 60 then  -- Only count levels > 1 minute
            total = total + data.time
            count = count + 1
        end
    end

    if count > 0 then
        return total / count
    end
    return nil
end

function QM:GetCurrentLevelTime()
    if self.levelStartTime then
        return GetTime() - self.levelStartTime
    end
    return 0
end

function QM:FormatLevelTime(seconds)
    if not seconds or seconds <= 0 then return "0m" end

    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)

    if hours > 0 then
        return string.format("%dh %dm", hours, mins)
    else
        return string.format("%dm", mins)
    end
end

-- ============================================================================
-- Reminder Functions (Bags, Repair)
-- ============================================================================

function QM:GetBagSpaceInfo()
    local freeSlots = 0
    local totalSlots = 0

    -- Check all bags (0 = backpack, 1-4 = equipped bags)
    for bag = 0, 4 do
        local numSlots
        if C_Container and C_Container.GetContainerNumSlots then
            numSlots = C_Container.GetContainerNumSlots(bag)
        else
            numSlots = GetContainerNumSlots(bag)
        end

        if numSlots then
            totalSlots = totalSlots + numSlots
            for slot = 1, numSlots do
                local hasItem
                if C_Container and C_Container.GetContainerItemInfo then
                    local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                    hasItem = itemInfo and itemInfo.itemID
                else
                    -- TBC Classic returns: texture, itemCount, locked, quality, readable, lootable, itemLink
                    local texture = GetContainerItemInfo(bag, slot)
                    hasItem = texture ~= nil
                end

                if not hasItem then
                    freeSlots = freeSlots + 1
                end
            end
        end
    end

    return freeSlots, totalSlots
end

function QM:GetDurabilityInfo()
    local minDurability = 100
    local totalCurrent = 0
    local totalMax = 0

    -- Check all equipment slots
    for slot = 1, 18 do
        local current, max = GetInventoryItemDurability(slot)
        if current and max and max > 0 then
            totalCurrent = totalCurrent + current
            totalMax = totalMax + max
            local percent = (current / max) * 100
            if percent < minDurability then
                minDurability = percent
            end
        end
    end

    local avgDurability = 100
    if totalMax > 0 then
        avgDurability = (totalCurrent / totalMax) * 100
    end

    return math.floor(minDurability), math.floor(avgDurability)
end

function QM:CheckReminders()
    local warnings = {}

    if not self.db.profile.reminders.enabled then
        return warnings
    end

    -- Check bag space
    if self.db.profile.reminders.bagsFull then
        local freeSlots = self:GetBagSpaceInfo()
        local threshold = self.db.profile.reminders.bagsThreshold or 4
        if freeSlots <= threshold then
            table.insert(warnings, {
                type = "bags",
                icon = "Interface\\Icons\\INV_Misc_Bag_08",
                text = string.format("|cFFFF6600%d " .. L["SLOTS"] .. "|r", freeSlots),
                priority = freeSlots == 0 and 1 or 2,
            })
        end
    end

    -- Check durability
    if self.db.profile.reminders.repairNeeded then
        local minDura = self:GetDurabilityInfo()
        local threshold = self.db.profile.reminders.repairThreshold or 25
        if minDura <= threshold then
            local color = minDura <= 10 and "FF0000" or "FF6600"
            table.insert(warnings, {
                type = "repair",
                icon = "Interface\\Icons\\Trade_BlackSmithing",
                text = string.format("|cFF%s%d%%|r", color, minDura),
                priority = minDura <= 10 and 1 or 2,
            })
        end
    end

    return warnings
end

-- ============================================================================
-- Reputation Tracker Functions (TBC Factions)
-- ============================================================================

-- TBC Reputation faction IDs
QM.TBC_FACTIONS = {
    -- Outland Factions
    {id = 942, name = "Cenarion Expedition"},
    {id = 935, name = "The Sha'tar"},
    {id = 1011, name = "Lower City"},
    {id = 933, name = "The Consortium"},
    {id = 989, name = "Keepers of Time"},
    {id = 990, name = "The Scale of the Sands"},
    {id = 1015, name = "Netherwing"},
    {id = 1031, name = "Sha'tari Skyguard"},
    {id = 1038, name = "Ogri'la"},
    {id = 978, name = "Kurenai"},        -- Alliance
    {id = 941, name = "The Mag'har"},    -- Horde
    {id = 967, name = "The Violet Eye"},
    {id = 1077, name = "Shattered Sun Offensive"},
    -- Aldor/Scryers
    {id = 932, name = "The Aldor"},
    {id = 934, name = "The Scryers"},
    -- Honor Hold/Thrallmar
    {id = 946, name = "Honor Hold"},     -- Alliance
    {id = 947, name = "Thrallmar"},      -- Horde
}

function QM:GetFactionStanding(factionId)
    local name, description, standingId, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfoByID(factionId)

    if not name then return nil end

    local standingText = GetText("FACTION_STANDING_LABEL" .. standingId, UnitSex("player"))
    local currentRep = barValue - barMin
    local maxRep = barMax - barMin

    return {
        name = name,
        standingId = standingId,
        standingText = standingText,
        current = currentRep,
        max = maxRep,
        percent = maxRep > 0 and math.floor((currentRep / maxRep) * 100) or 0,
        isWatched = isWatched,
    }
end

function QM:GetTrackedReputations()
    local reps = {}

    if not self.db.profile.reputation.enabled then
        return reps
    end

    -- Standing names
    local standingNames = {
        [1] = "Hated",
        [2] = "Hostile",
        [3] = "Unfriendly",
        [4] = "Neutral",
        [5] = "Friendly",
        [6] = "Honored",
        [7] = "Revered",
        [8] = "Exalted",
    }

    -- Get watched faction from Blizzard UI
    for i = 1, GetNumFactions() do
        local name, _, standingId, barMin, barMax, barValue, _, _, _, _, _, isWatched = GetFactionInfo(i)
        if isWatched and name then
            local currentRep = barValue - barMin
            local maxRep = barMax - barMin
            table.insert(reps, {
                name = name,
                standingId = standingId,
                standing = standingNames[standingId] or "Unknown",
                current = currentRep,
                max = maxRep,
                percent = maxRep > 0 and math.floor((currentRep / maxRep) * 100) or 0,
            })
        end
    end

    return reps
end

function QM:FormatReputation(rep)
    if not rep then return "" end

    local standingColors = {
        [1] = "CC0000",  -- Hated
        [2] = "FF0000",  -- Hostile
        [3] = "FF6600",  -- Unfriendly
        [4] = "FFFF00",  -- Neutral
        [5] = "00FF00",  -- Friendly
        [6] = "00FF88",  -- Honored
        [7] = "00FFFF",  -- Revered
        [8] = "FF00FF",  -- Exalted
    }

    local color = standingColors[rep.standingId] or "FFFFFF"
    return string.format("|cFF%s%d/%d|r", color, rep.current, rep.max)
end

-- ============================================================================
-- Quest History Functions
-- ============================================================================

local MAX_HISTORY_ENTRIES = 500  -- Hard cap on quest history size

function QM:AddToQuestHistory(questId, title, level, xpReward, duration)
    if not self.db.char.questHistory then
        self.db.char.questHistory = {}
    end

    local entry = {
        id = questId,
        title = title,
        level = level,
        xp = xpReward,
        duration = duration,
        timestamp = time(),
    }

    table.insert(self.db.char.questHistory, 1, entry)

    -- Trim to max entries (enforce hard cap)
    local maxEntries = math.min(self.db.profile.questHistory.maxEntries or 50, MAX_HISTORY_ENTRIES)
    while #self.db.char.questHistory > maxEntries do
        table.remove(self.db.char.questHistory)
    end
end

function QM:GetQuestHistory()
    return self.db.char.questHistory or {}
end

function QM:ClearQuestHistory()
    self.db.char.questHistory = {}
    print(L["MSG_PREFIX"] .. " " .. L["MSG_HISTORY_CLEARED"])
end

-- ============================================================================
-- Zone Progress Functions
-- ============================================================================

function QM:UpdateZoneProgress(zoneName, questId)
    if not zoneName or not questId then return end

    if not self.db.char.completedQuestsByZone then
        self.db.char.completedQuestsByZone = {}
    end

    if not self.db.char.completedQuestsByZone[zoneName] then
        self.db.char.completedQuestsByZone[zoneName] = {}
    end

    self.db.char.completedQuestsByZone[zoneName][questId] = true
end

function QM:GetZoneProgress(zoneName)
    if not zoneName then return 0, 0 end

    local completed = 0
    if self.db.char.completedQuestsByZone and self.db.char.completedQuestsByZone[zoneName] then
        for _ in pairs(self.db.char.completedQuestsByZone[zoneName]) do
            completed = completed + 1
        end
    end

    -- Get total quests for zone from database
    local total = self:GetTotalZoneQuests(zoneName)

    return completed, total
end

function QM:GetTotalZoneQuests(zoneName)
    -- Try to get from quest database
    if QM.DB and QM.DB.GetZoneQuestCount then
        return QM.DB:GetZoneQuestCount(zoneName) or 0
    end
    -- Fallback - estimate based on zone
    local zoneTotals = {
        -- Eastern Kingdoms
        ["Elwynn Forest"] = 45,
        ["Westfall"] = 55,
        ["Duskwood"] = 45,
        ["Redridge Mountains"] = 35,
        ["Loch Modan"] = 40,
        ["Dun Morogh"] = 50,
        ["Wetlands"] = 45,
        ["Stranglethorn Vale"] = 65,
        ["Hillsbrad Foothills"] = 40,
        ["Arathi Highlands"] = 35,
        ["Badlands"] = 25,
        ["Burning Steppes"] = 30,
        ["Eastern Plaguelands"] = 55,
        ["Western Plaguelands"] = 45,
        ["The Hinterlands"] = 35,
        ["Searing Gorge"] = 25,
        ["Silverpine Forest"] = 35,
        ["Tirisfal Glades"] = 45,
        ["Swamp of Sorrows"] = 20,
        ["Blasted Lands"] = 30,
        -- Kalimdor
        ["Darkshore"] = 50,
        ["Teldrassil"] = 35,
        ["Ashenvale"] = 55,
        ["Stonetalon Mountains"] = 35,
        ["Thousand Needles"] = 30,
        ["Desolace"] = 35,
        ["Feralas"] = 40,
        ["Tanaris"] = 50,
        ["Un'Goro Crater"] = 35,
        ["Silithus"] = 30,
        ["Winterspring"] = 35,
        ["Azshara"] = 25,
        ["Felwood"] = 30,
        ["Durotar"] = 45,
        ["Mulgore"] = 40,
        ["The Barrens"] = 80,
        ["Dustwallow Marsh"] = 40,
        -- TBC Starting Zones
        ["Eversong Woods"] = 50,
        ["Ghostlands"] = 55,
        ["Azuremyst Isle"] = 45,
        ["Bloodmyst Isle"] = 50,
        -- Outland
        ["Hellfire Peninsula"] = 90,
        ["Zangarmarsh"] = 55,
        ["Terokkar Forest"] = 70,
        ["Nagrand"] = 75,
        ["Blade's Edge Mountains"] = 60,
        ["Netherstorm"] = 80,
        ["Shadowmoon Valley"] = 90,
        -- Isle of Quel'Danas
        ["Isle of Quel'Danas"] = 25,
    }
    return zoneTotals[zoneName] or 30
end

-- ============================================================================
-- Nearest Quest Button Function
-- ============================================================================

function QM:GetNearestQuest()
    local nearestQuest = nil
    local nearestDist = math.huge

    for questId, quest in pairs(self.activeQuests) do
        if not quest.isComplete then
            local dist = self:GetNearestObjectiveDistance(questId)
            if dist and dist < nearestDist then
                nearestDist = dist
                nearestQuest = quest
            end
        end
    end

    -- If all quests complete, find nearest turn-in
    if not nearestQuest then
        for questId, quest in pairs(self.activeQuests) do
            if quest.isComplete then
                local loc = self:GetQuestTurnInLocation(questId)
                if loc then
                    local dist = self:GetDistanceToPoint(loc.x, loc.y, loc.mapId)
                    if dist and dist < nearestDist then
                        nearestDist = dist
                        nearestQuest = quest
                    end
                end
            end
        end
    end

    return nearestQuest, nearestDist
end

function QM:NavigateToNearestQuest()
    local quest, dist = self:GetNearestQuest()
    if quest then
        self:SetWaypointForQuest(quest.id)
        local distText = dist and (" (" .. self:FormatDistance(dist) .. ")") or ""
        print(L["MSG_PREFIX"] .. " " .. L["MSG_NAVIGATING_TO"] .. " |cFFFFD700" .. quest.title .. "|r" .. distText)
    else
        print("|cFFFFFF00QuestMaster:|r " .. L["MSG_NO_QUESTS_NAV"])
    end
end

function QM:NavigateToNearestTurnIn()
    local nearestQuest = nil
    local nearestDist = math.huge

    -- Find nearest completed quest
    for questId, quest in pairs(self.activeQuests or {}) do
        if quest.isComplete and QM.DB then
            local locs = QM.DB:GetQuestTurnInLocations(questId)
            if locs and locs[1] then
                local dist = self:GetDistanceToPoint(locs[1].x, locs[1].y, locs[1].mapId)
                if dist and dist < nearestDist then
                    nearestDist = dist
                    nearestQuest = quest
                end
            end
        end
    end

    if nearestQuest then
        self:SetWaypointForQuest(nearestQuest.id)
        local distText = nearestDist < math.huge and (" (" .. self:FormatDistance(nearestDist) .. ")") or ""
        print(L["MSG_PREFIX"] .. " " .. L["MSG_TURN_IN"] .. " |cFFFFD700" .. nearestQuest.title .. "|r" .. distText)
    else
        print(L["MSG_PREFIX"] .. " " .. L["MSG_NO_COMPLETED"])
    end
end

-- ============================================================================
-- Quest Notes Functions
-- ============================================================================

function QM:GetQuestNote(questId)
    if not self.db.char.questNotes then
        self.db.char.questNotes = {}
    end
    return self.db.char.questNotes[questId]
end

-- Get max note length from settings (with fallback)
local function GetMaxNoteLength()
    return QM.db and QM.db.profile.advanced and QM.db.profile.advanced.maxNoteLength or 200
end

function QM:SetQuestNote(questId, note)
    if not self.db.char.questNotes then
        self.db.char.questNotes = {}
    end
    if note and note ~= "" then
        -- Limit note length to prevent excessive storage
        local maxLen = GetMaxNoteLength()
        if #note > maxLen then
            note = note:sub(1, maxLen)
        end
        self.db.char.questNotes[questId] = note
    else
        self.db.char.questNotes[questId] = nil
    end
end

function QM:HasQuestNote(questId)
    return self.db.char.questNotes and self.db.char.questNotes[questId] ~= nil
end

-- Quest Note Edit Dialog
function QM:ShowQuestNoteDialog(questId, questTitle)
    if not self.noteDialog then
        local dialog = CreateFrame("Frame", "QMNoteDialog", UIParent, "BackdropTemplate")
        dialog:SetSize(350, 180)
        dialog:SetPoint("CENTER")
        dialog:SetFrameStrata("DIALOG")
        dialog:SetMovable(true)
        dialog:EnableMouse(true)
        dialog:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4}
        })
        dialog:SetBackdropColor(0.08, 0.08, 0.1, 0.98)
        dialog:SetBackdropBorderColor(0.8, 0.6, 0.2, 1)
        dialog:SetScript("OnMouseDown", function(self) self:StartMoving() end)
        dialog:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
        dialog:Hide()

        -- Title
        dialog.title = dialog:CreateFontString(nil, "OVERLAY")
        dialog.title:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        dialog.title:SetPoint("TOP", 0, -12)

        -- Close button
        local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -2, -2)
        closeBtn:SetScript("OnClick", function() dialog:Hide() end)

        -- Quest name display
        dialog.questName = dialog:CreateFontString(nil, "OVERLAY")
        dialog.questName:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
        dialog.questName:SetPoint("TOP", 0, -35)
        dialog.questName:SetWidth(320)
        dialog.questName:SetTextColor(1, 0.82, 0)

        -- Edit box container
        local editContainer = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
        editContainer:SetSize(320, 70)
        editContainer:SetPoint("TOP", 0, -55)
        editContainer:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
        editContainer:SetBackdropColor(0.05, 0.05, 0.08, 1)

        -- Scrollframe for editbox
        local scrollFrame = CreateFrame("ScrollFrame", nil, editContainer, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 5, -5)
        scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)

        -- Edit box
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(GameFontHighlight)
        editBox:SetWidth(285)
        editBox:SetMaxLetters(GetMaxNoteLength())  -- Limit input based on settings
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scrollFrame:SetScrollChild(editBox)
        dialog.editBox = editBox

        -- Save button
        local saveBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        saveBtn:SetSize(80, 24)
        saveBtn:SetPoint("BOTTOMRIGHT", -80, 12)
        saveBtn:SetText("Save")
        saveBtn:SetScript("OnClick", function()
            QM:SetQuestNote(dialog.questId, dialog.editBox:GetText())
            print(L["MSG_PREFIX"] .. " " .. L["MSG_NOTE_SAVED"] .. " |cFFFFD700" .. (dialog.questTitle or L["QUEST"]) .. "|r")
            dialog:Hide()
            QM:UpdateTracker()
        end)

        -- Delete button
        local deleteBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        deleteBtn:SetSize(80, 24)
        deleteBtn:SetPoint("BOTTOMLEFT", 80, 12)
        deleteBtn:SetText("Delete")
        deleteBtn:SetScript("OnClick", function()
            QM:SetQuestNote(dialog.questId, nil)
            print(L["MSG_PREFIX"] .. " " .. L["MSG_NOTE_DELETED"] .. " |cFFFFD700" .. (dialog.questTitle or L["QUEST"]) .. "|r")
            dialog:Hide()
            QM:UpdateTracker()
        end)

        self.noteDialog = dialog
    end

    -- Setup dialog for this quest
    self.noteDialog.questId = questId
    self.noteDialog.questTitle = questTitle
    self.noteDialog.title:SetText("|cFFFFD700Quest Note|r")
    self.noteDialog.questName:SetText(questTitle or L["UNKNOWN_QUEST"])
    self.noteDialog.editBox:SetText(self:GetQuestNote(questId) or "")
    self.noteDialog:Show()
    self.noteDialog.editBox:SetFocus()
end

-- ============================================================================
-- Quest Statistics Functions
-- ============================================================================

function QM:GetQuestStats()
    -- Use profile storage for persistent stats across sessions
    if not self.db.profile.questStats then
        self.db.profile.questStats = {
            totalCompleted = 0,
            totalAbandoned = 0,
            totalXPFromQuests = 0,
            questTimes = {},
            fastestQuests = {},
            slowestQuests = {},
            questsPerZone = {},
            questsPerHour = {},
            levelingTimes = {},
            sessionStats = {
                started = 0,
                completed = 0,
                xpGained = 0,
                timeStarted = 0,
            },
        }
    end
    return self.db.profile.questStats
end

function QM:TrackQuestCompletion(questId, questTitle, questLevel, xpReward, duration, quest)
    local stats = self:GetQuestStats()

    -- Increment totals
    stats.totalCompleted = (stats.totalCompleted or 0) + 1
    stats.totalXPFromQuests = (stats.totalXPFromQuests or 0) + (xpReward or 0)

    -- Track quest time
    if duration and duration > 0 then
        stats.questTimes = stats.questTimes or {}
        stats.questTimes[questId] = {
            title = questTitle,
            level = questLevel,
            duration = duration,
            xp = xpReward,
            timestamp = time(),
        }

        -- Update fastest/slowest quests
        self:UpdateQuestTimeRankings(questId, questTitle, duration)
    end

    -- Track quests per zone
    if quest then
        local zoneName = self:GetQuestZone(quest) or "Unknown"
        stats.questsPerZone = stats.questsPerZone or {}
        stats.questsPerZone[zoneName] = (stats.questsPerZone[zoneName] or 0) + 1
    end

    -- Track hourly stats
    local hour = date("%Y-%m-%d %H:00")
    stats.questsPerHour = stats.questsPerHour or {}
    stats.questsPerHour[hour] = (stats.questsPerHour[hour] or 0) + 1

    -- Update session stats
    stats.sessionStats = stats.sessionStats or {}
    stats.sessionStats.completed = (stats.sessionStats.completed or 0) + 1
    stats.sessionStats.xpGained = (stats.sessionStats.xpGained or 0) + (xpReward or 0)
end

function QM:UpdateQuestTimeRankings(questId, questTitle, duration)
    local stats = self:GetQuestStats()

    -- Update fastest quests (top 5)
    stats.fastestQuests = stats.fastestQuests or {}
    table.insert(stats.fastestQuests, {
        id = questId,
        title = questTitle,
        duration = duration,
    })
    table.sort(stats.fastestQuests, function(a, b) return a.duration < b.duration end)
    while #stats.fastestQuests > 5 do
        table.remove(stats.fastestQuests)
    end

    -- Update slowest quests (top 5)
    stats.slowestQuests = stats.slowestQuests or {}
    table.insert(stats.slowestQuests, {
        id = questId,
        title = questTitle,
        duration = duration,
    })
    table.sort(stats.slowestQuests, function(a, b) return a.duration > b.duration end)
    while #stats.slowestQuests > 5 do
        table.remove(stats.slowestQuests)
    end
end

function QM:GetStatsSummary()
    local stats = self:GetQuestStats()

    -- Calculate averages
    local totalTime = 0
    local questCount = 0
    for _, data in pairs(stats.questTimes or {}) do
        if data.duration then
            totalTime = totalTime + data.duration
            questCount = questCount + 1
        end
    end
    local avgTime = questCount > 0 and (totalTime / questCount) or 0

    -- Calculate quests per hour rate
    local sessionTime = GetTime() - (self.sessionStartTime or GetTime())
    local questsPerHour = sessionTime > 0 and ((stats.sessionStats.completed or 0) / (sessionTime / 3600)) or 0

    return {
        totalCompleted = stats.totalCompleted or 0,
        totalAbandoned = stats.totalAbandoned or 0,
        totalXP = stats.totalXPFromQuests or 0,
        averageTime = avgTime,
        questsPerHour = questsPerHour,
        fastestQuest = stats.fastestQuests and stats.fastestQuests[1] or nil,
        slowestQuest = stats.slowestQuests and stats.slowestQuests[1] or nil,
        topZones = self:GetTopQuestZones(5),
        sessionCompleted = stats.sessionStats and stats.sessionStats.completed or 0,
        sessionXP = stats.sessionStats and stats.sessionStats.xpGained or 0,
    }
end

function QM:GetTopQuestZones(limit)
    local stats = self:GetQuestStats()
    local zones = {}

    for zone, count in pairs(stats.questsPerZone or {}) do
        table.insert(zones, {name = zone, count = count})
    end

    table.sort(zones, function(a, b) return a.count > b.count end)

    local result = {}
    for i = 1, math.min(limit, #zones) do
        result[i] = zones[i]
    end
    return result
end

function QM:ResetSessionStats()
    local stats = self:GetQuestStats()
    stats.sessionStats = {
        started = 0,
        completed = 0,
        xpGained = 0,
        timeStarted = GetTime(),
    }
    print(L["MSG_PREFIX"] .. " " .. L["MSG_SESSION_RESET"])
end

-- ============================================================================
-- Quest Database Search Functions
-- ============================================================================

function QM:SearchQuests(searchTerm, options)
    if not self.DB or not self.DB.quests then return {} end

    options = options or {}
    local results = {}
    local searchLower = searchTerm:lower()
    local maxResults = options.maxResults or 50
    local playerLevel = UnitLevel("player")

    for questId, questData in pairs(self.DB.quests) do
        if #results >= maxResults then break end

        local quest = self.DB:GetQuest(questId)
        if quest and quest.name then
            local nameLower = quest.name:lower()
            local match = false

            -- Name search
            if nameLower:find(searchLower, 1, true) then
                match = true
            end

            -- Quest ID search
            if tonumber(searchTerm) and questId == tonumber(searchTerm) then
                match = true
            end

            -- Apply filters
            if match and options.minLevel and quest.minLevel then
                if quest.minLevel < options.minLevel then match = false end
            end
            if match and options.maxLevel and quest.questLevel then
                if quest.questLevel > options.maxLevel then match = false end
            end
            if match and options.zoneId and quest.zone then
                if quest.zone ~= options.zoneId then match = false end
            end
            if match and options.hideCompleted then
                if self:IsQuestCompleted(questId) then match = false end
            end

            if match then
                table.insert(results, {
                    id = questId,
                    name = quest.name,
                    level = quest.questLevel,
                    minLevel = quest.minLevel,
                    zone = quest.zone,
                    isCompleted = self:IsQuestCompleted(questId),
                    isActive = self:IsQuestActive(questId),
                })
            end
        end
    end

    -- Sort by level
    table.sort(results, function(a, b)
        if a.level and b.level then
            return a.level < b.level
        end
        return (a.name or "") < (b.name or "")
    end)

    return results
end

function QM:GetQuestsForZone(zoneId)
    if not self.DB or not self.DB.quests then return {} end

    local results = {}
    local playerLevel = UnitLevel("player")

    for questId, _ in pairs(self.DB.quests) do
        local quest = self.DB:GetQuest(questId)
        if quest and quest.zone == zoneId then
            local levelDiff = (quest.questLevel or 0) - playerLevel
            -- Only show quests within reasonable level range
            if levelDiff >= -10 and levelDiff <= 5 then
                table.insert(results, {
                    id = questId,
                    name = quest.name,
                    level = quest.questLevel,
                    minLevel = quest.minLevel,
                    isCompleted = self:IsQuestCompleted(questId),
                    isActive = self:IsQuestActive(questId),
                })
            end
        end
    end

    table.sort(results, function(a, b)
        return (a.level or 0) < (b.level or 0)
    end)

    return results
end

function QM:IsQuestCompleted(questId)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(questId)
    end
    if IsQuestFlaggedCompleted then
        return IsQuestFlaggedCompleted(questId)
    end
    return false
end

-- Make addon accessible globally for debugging
_G["QuestMaster"] = QM
