-- QuestMaster English Localization (Default)
local addonName, QM = ...

local L = {}
QM.L = L

-- ============================================================================
-- General
-- ============================================================================
L["ADDON_NAME"] = "QuestMaster"
L["ADDON_LOADED"] = "QuestMaster loaded. Type /qm for options."
L["VERSION"] = "Version"
L["ENABLED"] = "Enabled"
L["DISABLED"] = "Disabled"
L["YES"] = "Yes"
L["NO"] = "No"
L["DEFAULT"] = "Default"
L["RESET"] = "Reset"
L["CLOSE"] = "Close"
L["SAVE"] = "Save"
L["CANCEL"] = "Cancel"
L["DELETE"] = "Delete"
L["UNKNOWN"] = "Unknown"
L["NONE"] = "None"
L["GO"] = "Go"
L["SEARCH"] = "Search"
L["REFRESHED"] = "Refreshed"

-- ============================================================================
-- Tabs
-- ============================================================================
L["TAB_GENERAL"] = "General"
L["TAB_GENERAL_DESC"] = "Core settings"
L["TAB_TRACKER"] = "Tracker"
L["TAB_TRACKER_DESC"] = "Quest list"
L["TAB_ARROW"] = "Arrow"
L["TAB_ARROW_DESC"] = "Navigation"
L["TAB_MAP"] = "Map"
L["TAB_MAP_DESC"] = "Pins & markers"
L["TAB_STATISTICS"] = "Statistics"
L["TAB_STATISTICS_DESC"] = "XP tracking"
L["TAB_DASHBOARD"] = "Dashboard"
L["TAB_DASHBOARD_DESC"] = "Stats & History"
L["TAB_AUTOMATION"] = "Automation"
L["TAB_AUTOMATION_DESC"] = "Auto features"
L["TAB_ADVANCED"] = "Advanced"
L["TAB_ADVANCED_DESC"] = "Expert"
L["TAB_CREDITS"] = "Credits"
L["TAB_CREDITS_DESC"] = "About & Links"

-- ============================================================================
-- Settings Header
-- ============================================================================
L["SETTINGS"] = "Settings"
L["SETTINGS_TITLE"] = "QuestMaster Settings"

-- ============================================================================
-- General Settings
-- ============================================================================
L["MAIN_SETTINGS"] = "Main Settings"
L["ENABLE_ADDON"] = "Enable QuestMaster"
L["ENABLE_ADDON_DESC"] = "Master switch for all features"
L["LOCK_FRAMES"] = "Lock Frame Positions"
L["LOCK_FRAMES_DESC"] = "Prevent dragging"
L["SHOW_MINIMAP_BUTTON"] = "Show Minimap Button"
L["SHOW_MINIMAP_BUTTON_DESC"] = "Button on minimap"

-- ============================================================================
-- Sounds
-- ============================================================================
L["SOUNDS"] = "Sound Effects"
L["QUEST_PROGRESS_SOUND"] = "Quest Progress Sound"
L["QUEST_PROGRESS_SOUND_DESC"] = "Sound on progress"
L["QUEST_COMPLETE_SOUND"] = "Quest Complete Sound"
L["QUEST_COMPLETE_SOUND_DESC"] = "Sound on completion"

-- ============================================================================
-- Announcements
-- ============================================================================
L["QUEST_ANNOUNCEMENTS"] = "Quest Announcements"
L["ANNOUNCE_ACCEPT"] = "Announce Quest Accept"
L["ANNOUNCE_ACCEPT_DESC"] = "To party/guild"
L["ACCEPT_CHANNEL"] = "Accept Channel"
L["ANNOUNCE_DONE"] = "Announce Quest Done"
L["ANNOUNCE_DONE_DESC"] = "To party/guild"
L["COMPLETE_CHANNEL"] = "Complete Channel"
L["CHANNEL_PARTY"] = "Party"
L["CHANNEL_GUILD"] = "Guild"
L["CHANNEL_EMOTE"] = "Emote (/me)"
L["CHANNEL_DISABLED"] = "Disabled"

-- Level Up
L["LEVEL_UP_ANNOUNCEMENTS"] = "Level Up Announcements"
L["ANNOUNCE_LEVEL_UP"] = "Announce Level Up"
L["ANNOUNCE_LEVEL_UP_DESC"] = "To emote/party"
L["LEVEL_UP_CHANNEL"] = "Level Up Channel"

-- ============================================================================
-- Quick Actions
-- ============================================================================
L["QUICK_ACTIONS"] = "Quick Actions"
L["RESET_POSITIONS"] = "Reset Positions"
L["REFRESH_DATA"] = "Refresh Data"

-- ============================================================================
-- Quest Tracker
-- ============================================================================
L["QUEST_TRACKER"] = "Quest Tracker"
L["ENABLE_TRACKER"] = "Enable Tracker"
L["ENABLE_TRACKER_DESC"] = "Show quest panel"
L["FONT_SIZE"] = "Font Size"
L["BACKGROUND_OPACITY"] = "Background Opacity"
L["TRACKER_TITLE"] = "QuestMaster"
L["ACTIVE_QUESTS"] = "Active Quests"
L["READY_FOR_TURNIN"] = "Ready for Turn-In"
L["NO_ACTIVE_QUESTS"] = "No active quests"

-- Display Options
L["DISPLAY_OPTIONS"] = "Display Options"
L["SHOW_QUEST_LEVEL"] = "Show Quest Level"
L["SHOW_QUEST_LEVEL_DESC"] = "Level in brackets"
L["SHOW_DISTANCE"] = "Show Distance"
L["SHOW_DISTANCE_DESC"] = "Distance to objective"
L["COLOR_BY_DIFFICULTY"] = "Color by Difficulty"
L["COLOR_BY_DIFFICULTY_DESC"] = "Level-based colors"
L["SHOW_PROGRESS_BARS"] = "Show Progress Bars"
L["SHOW_PROGRESS_BARS_DESC"] = "Bars under objectives"
L["SHOW_ITEM_BUTTONS"] = "Show Item Buttons"
L["SHOW_ITEM_BUTTONS_DESC"] = "Show usable quest items"
L["CLICK_TO_USE_ITEM"] = "Click to use item"
L["SHOW_COMPLETED"] = "Show Completed Quests"
L["SHOW_COMPLETED_DESC"] = "Display finished quests"
L["MAX_QUESTS"] = "Max Quests Shown"

-- Default Tracker
L["HIDE_BLIZZARD_TRACKER"] = "Hide Default Quest Tracker"
L["HIDE_BLIZZARD_TRACKER_DESC"] = "Hide the built-in Blizzard quest tracker"
L["HIDE_BLIZZARD_TRACKER_COMBAT"] = "Cannot toggle the default tracker during combat."
L["HIDE_BLIZZARD_TRACKER_RELOAD"] = "Re-enabling the default tracker requires a UI reload. Reload now?"

-- Sorting
L["SORTING"] = "Sorting"
L["SORT_BY"] = "Sort By"
L["SORT_QUESTS_BY"] = "Sort Quests By"
L["SORT_DISTANCE"] = "Distance"
L["SORT_LEVEL"] = "Level"
L["CURRENT"] = "Current"

-- Tracker Buttons
L["SORT"] = "Sort"
L["NAVIGATE_TO_NEAREST"] = "Navigate to Nearest"
L["CLICK_TO_SET_WAYPOINT"] = "Click to set waypoint"
L["NAVIGATE_TO_TURNIN"] = "Navigate to Turn-in"
L["NEAREST_COMPLETED_QUEST"] = "Nearest completed quest"

-- ============================================================================
-- Arrow
-- ============================================================================
L["NAVIGATION_ARROW"] = "Navigation Arrow"
L["ENABLE_ARROW"] = "Enable Arrow"
L["ENABLE_ARROW_DESC"] = "Show nav arrow"
L["ARROW_SIZE"] = "Arrow Size"
L["ARROW_OPACITY"] = "Arrow Opacity"
L["ARRIVAL_DISTANCE"] = "Arrival Distance"

-- Arrow Display
L["DISPLAY"] = "Display"
L["SHOW_OBJECTIVE"] = "Show Objective"
L["SHOW_OBJECTIVE_DESC"] = "Objective text"
L["SHOW_ETA"] = "Show ETA"
L["SHOW_ETA_DESC"] = "Time estimate"

-- Arrow Status
L["ARRIVED"] = "Arrived!"
L["NO_ACTIVE_OBJECTIVE"] = "No active objective"
L["QUEST_OBJECTIVE"] = "Quest Objective"
L["YARDS"] = "yd"
L["KILOMETERS"] = "km"

-- Arrow Tooltip
L["ARROW_NAVIGATION"] = "Navigation"
L["OBJECTIVE"] = "Objective"
L["LEFT_CLICK_DRAG"] = "Left-click + drag to move"
L["RIGHT_CLICK_OPTIONS"] = "Right-click for options"

-- Arrow Context Menu
L["HIDE_ARROW"] = "Hide Arrow"
L["CLEAR_WAYPOINT"] = "Clear Waypoint"
L["FIND_NEAREST_AUTO"] = "Find Nearest (Auto)"
L["OPEN_SETTINGS"] = "Open Settings"

-- ETA
L["ETA"] = "ETA"
L["ETA_SECONDS"] = "ETA: %ds"
L["ETA_MINUTES"] = "ETA: %dm %ds"
L["ETA_HOURS"] = "ETA: %dh %dm"
L["MOVE_TO_CALCULATE"] = "(Move to calculate ETA)"

-- ============================================================================
-- Map
-- ============================================================================
L["WORLD_MAP"] = "World Map"
L["ENABLE_MAP_PINS"] = "Enable Map Pins"
L["ENABLE_MAP_PINS_DESC"] = "Show quest pins"
L["PIN_SIZE"] = "Pin Size"
L["PIN_OPACITY"] = "Pin Opacity"

-- Pin Types
L["PIN_TYPES"] = "Pin Types"
L["OBJECTIVE_PINS"] = "Objective Pins"
L["OBJECTIVE_PINS_DESC"] = "Quest objectives"
L["QUEST_AREAS"] = "Quest Areas"
L["QUEST_AREAS_DESC"] = "Highlight areas"
L["TURNIN_PINS"] = "Turn-in Pins (?)"
L["TURNIN_PINS_DESC"] = "Yellow ? pins"
L["AVAILABLE_QUESTS"] = "Available Quests (!)"
L["AVAILABLE_QUESTS_DESC"] = "Yellow ! pins"
L["PATROL_PATHS"] = "NPC Patrol Paths"
L["PATROL_PATHS_DESC"] = "Show patrol routes"

-- ============================================================================
-- Statistics Tab
-- ============================================================================
L["QUEST_TIMER"] = "Quest Timer"
L["ENABLE_TIMER"] = "Enable Timer"
L["ENABLE_TIMER_DESC"] = "Track quest time"
L["SHOW_IN_TRACKER"] = "Show in Tracker"
L["SHOW_IN_TRACKER_DESC"] = "Display in tracker"

L["XP_PER_HOUR"] = "XP/Hour"
L["ENABLE_XP_TRACKER"] = "Enable XP Tracker"
L["ENABLE_XP_TRACKER_DESC"] = "Calculate XP rate"
L["RESET_XP"] = "Reset XP"

L["RESTED_XP"] = "Rested XP"
L["ENABLE_RESTED_DISPLAY"] = "Enable Rested Display"
L["ENABLE_RESTED_DISPLAY_DESC"] = "Show rested XP"
L["SHOW_BONUS_INDICATOR"] = "Show +50% Bonus"
L["SHOW_BONUS_INDICATOR_DESC"] = "Show bonus indicator"

L["LEVEL_TIME"] = "Level Time"
L["ENABLE_LEVEL_TIMER"] = "Enable Level Timer"
L["ENABLE_LEVEL_TIMER_DESC"] = "Track time per level"
L["SHOW_AVERAGE"] = "Show Average"
L["SHOW_AVERAGE_DESC"] = "Display avg time"

L["REMINDERS"] = "Reminders"
L["ENABLE_REMINDERS"] = "Enable Reminders"
L["ENABLE_REMINDERS_DESC"] = "Bags & repair warnings"
L["BAG_SPACE_WARNING"] = "Bag Space Warning"
L["BAG_SPACE_WARNING_DESC"] = "Warn when bags full"
L["BAG_THRESHOLD"] = "Bag Threshold"
L["REPAIR_WARNING"] = "Repair Warning"
L["REPAIR_WARNING_DESC"] = "Warn low durability"

L["ZONE_PROGRESS"] = "Zone Progress"
L["ENABLE_ZONE_PROGRESS"] = "Enable Zone Progress"
L["ENABLE_ZONE_PROGRESS_DESC"] = "Track per zone"

L["REPUTATION"] = "Reputation"
L["ENABLE_REP_TRACKER"] = "Enable Rep Tracker"
L["ENABLE_REP_TRACKER_DESC"] = "Track watched faction"

-- Quest Statistics
L["QUEST_STATISTICS"] = "Quest Statistics"
L["TOTAL_STATISTICS"] = "Total Statistics"
L["QUESTS_COMPLETED"] = "Quests Completed"
L["TOTAL_XP_GAINED"] = "Total XP Gained"
L["AVG_QUEST_TIME"] = "Avg Quest Time"
L["QUESTS_PER_HOUR"] = "Quests per Hour"
L["CURRENT_LEVEL"] = "Current Level"
L["TIME_ON_LEVEL"] = "Time on Level"
L["SESSION_QUESTS"] = "Session Quests"
L["SESSION_XP"] = "Session XP"
L["REFRESH_STATS"] = "Refresh Stats"
L["RESET_SESSION"] = "Reset Session"

-- Quest Search
L["QUEST_SEARCH"] = "Quest Search"
L["SEARCH_PLACEHOLDER"] = "Enter quest name or ID..."
L["CLICK_RESULT_HINT"] = "Click a result to set waypoint to quest start location"
L["NO_QUESTS_FOUND"] = "No quests found matching:"
L["WAYPOINT_SET_TO_QUEST"] = "Waypoint set to quest:"
L["NO_LOCATION_DATA"] = "No location data for:"
L["QUEST_LABEL"] = "Quest:"
L["OBJECTIVES_LABEL"] = "Objectives:"

-- Manual Waypoint
L["MANUAL_WAYPOINT"] = "Manual Waypoint"
L["WAYPOINT"] = "Waypoint"
L["MANUAL"] = "[Manual]"
L["CURRENT_WAYPOINT"] = "Current:"
L["NO_WAYPOINT_SET"] = "No waypoint set"
L["X_COORD"] = "X:"
L["Y_COORD"] = "Y:"
L["SET"] = "Set"
L["INVALID_COORDINATES"] = "Invalid coordinates (0-100)"
L["COORD_HINT"] = "Enter coordinates like 45.5 and 67.2 (values 0-100)"
L["CLEAR_WAYPOINT"] = "Clear Waypoint"

-- ============================================================================
-- Automation Tab
-- ============================================================================
L["QUEST_AUTOMATION"] = "Quest Automation"
L["AUTO_ACCEPT"] = "Auto-Accept Quests"
L["AUTO_ACCEPT_DESC"] = "Shift to skip"
L["AUTO_COMPLETE"] = "Auto-Complete Quests"
L["AUTO_COMPLETE_DESC"] = "Shift to skip"
L["SKIP_REWARD_CHOICE"] = "Skip Reward Choice"
L["SKIP_REWARD_CHOICE_DESC"] = "Wait for selection"
L["AUTO_SHARE"] = "Auto-Share Quests"
L["AUTO_SHARE_DESC"] = "Share with party"

L["WAYPOINT_AUTO"] = "Waypoint Auto"
L["AUTO_SET_WAYPOINT"] = "Auto-Set Waypoint"
L["AUTO_SET_WAYPOINT_DESC"] = "Nearest quest"
L["AUTO_ADVANCE"] = "Auto-Advance"
L["AUTO_ADVANCE_DESC"] = "Next on complete"
L["PRIORITIZE_TURNINS"] = "Prioritize Turn-ins"
L["PRIORITIZE_TURNINS_DESC"] = "Turn-ins first"

L["QUEST_FILTERS"] = "Quest Filters"
L["SHOW_DUNGEON"] = "Show Dungeon Quests"
L["SHOW_DUNGEON_DESC"] = "Include dungeon quests"
L["SHOW_RAID"] = "Show Raid Quests"
L["SHOW_RAID_DESC"] = "Include raid quests"
L["SHOW_GROUP"] = "Show Group Quests"
L["SHOW_GROUP_DESC"] = "Include group quests"
L["SHOW_PVP"] = "Show PvP Quests"
L["SHOW_PVP_DESC"] = "Include PvP quests"
L["SHOW_LOW_LEVEL"] = "Show Low Level Quests"
L["SHOW_LOW_LEVEL_DESC"] = "Include gray quests"

-- ============================================================================
-- Advanced Tab
-- ============================================================================
L["THEME"] = "Theme"
L["COLOR_THEME"] = "Color Theme"
L["THEME_GOLD"] = "Gold (Default)"
L["THEME_BLUE"] = "Blue"
L["THEME_GREEN"] = "Green"
L["THEME_RED"] = "Red"
L["THEME_PURPLE"] = "Purple"
L["THEME_ORANGE"] = "Orange"
L["THEME_TEAL"] = "Teal"
L["THEME_PINK"] = "Pink"
L["THEME_SILVER"] = "Silver"
L["THEME_BRONZE"] = "Bronze"

L["PERFORMANCE"] = "Performance"
L["UPDATE_INTERVAL"] = "Update Interval"
L["UPDATE_THROTTLE"] = "Update Throttle"
L["REDUCE_MAP_UPDATES"] = "Reduce Map Updates"
L["REDUCE_MAP_UPDATES_DESC"] = "Lazy updates"

L["QUEST_NOTES"] = "Quest Notes"
L["MAX_NOTE_LENGTH"] = "Max Note Length"

L["DEBUG_TOOLS"] = "Debug & Tools"
L["DEBUG_MODE"] = "Debug Mode"
L["DEBUG_MODE_DESC"] = "Chat debug info"
L["RESET_SETTINGS"] = "Reset Settings"
L["RELOAD_UI"] = "Reload UI"
L["RESET_CONFIRM"] = "Reset all QuestMaster settings?"

-- ============================================================================
-- Credits Tab
-- ============================================================================
L["CREDITS_VERSION"] = "Version 1.3"
L["CREDITS_EDITION"] = "All-in-One Edition"
L["CREDITS_DESCRIPTION"] = "Premium quest tracking addon with navigation arrows, map pins, statistics, and automation features."
L["DEVELOPER"] = "Developer"
L["ALSO_KNOWN_AS"] = "also known as"
L["DEVELOPER_BIO"] = "WoW addon developer and content creator. Streaming live on Twitch.tv/Novi_Live"
L["CONNECT"] = "Connect"
L["TWITCH"] = "Twitch"
L["DISCORD"] = "Discord"
L["CURSEFORGE"] = "CurseForge"
L["DOWNLOADS_BUGS"] = "Downloads & Bug Reports"
L["CHANGELOG"] = "Changelog"
L["SPECIAL_THANKS"] = "Special Thanks"
L["THANKS_MESSAGE"] = "To all viewers, testers, and supporters on Twitch! Your feedback helps make QuestMaster better."

-- ============================================================================
-- Info Bar Tooltip
-- ============================================================================
L["SESSION_STATISTICS"] = "Session Statistics"
L["CURRENT_XP"] = "Current XP:"
L["XP_REMAINING"] = "XP Remaining:"
L["XP_PER_HOUR_LABEL"] = "XP per Hour:"
L["TIME_TO_LEVEL"] = "Time to Level:"
L["SESSION_TIME"] = "Session Time:"
L["RESTED_AMOUNT"] = "Rested Amount:"
L["RESTED_BUBBLES"] = "Rested Bubbles:"
L["BONUS_XP"] = "Bonus XP:"
L["BONUS_UNTIL_DEPLETED"] = "+50% until depleted"
L["CURRENT_LEVEL_LABEL"] = "Current Level:"
L["AVERAGE_PER_LEVEL"] = "Average per Level:"
L["PROGRESS"] = "Progress:"
L["STATUS"] = "Status"
L["BAG_SPACE"] = "Bag Space:"
L["FREE"] = "free"
L["DURABILITY"] = "Durability:"
L["LOWEST"] = "lowest"
L["TRACKED_REPUTATIONS"] = "Tracked Reputations"
L["CLICK_TO_RESET_XP"] = "Click to reset XP tracker"

-- ============================================================================
-- Quest Display
-- ============================================================================
L["COMPLETE"] = "COMPLETE"
L["DONE"] = "DONE"
L["TURN_IN"] = "Turn in"
L["TURN_IN_SUFFIX"] = " (Turn In)"
L["TIME_ON_QUEST"] = "Time on Quest:"
L["NOTE"] = "Note:"
L["CLICK_SET_WAYPOINT"] = "Left-click: Set waypoint"
L["CLICK_OPEN_QUESTLOG"] = "Shift+Left-click: Open Quest Log"
L["CLICK_LINK_QUEST"] = "Shift+Left-click: Link quest in chat"
L["CLICK_MORE_OPTIONS"] = "Right-click: More options"
L["SHOW_BORDER"] = "Show Border"
L["SHOW_BORDER_DESC"] = "Show or hide the tracker border"
L["DISTANCE_TO_OBJECTIVE"] = "Distance to nearest objective"

-- Context Menu
L["SET_WAYPOINT"] = "Set Waypoint"
L["SHOW_ON_MAP"] = "Show on Map"
L["EXPAND_QUEST"] = "Expand Quest"
L["COLLAPSE_QUEST"] = "Collapse Quest"
L["EDIT_NOTE"] = "Edit Note"
L["ADD_NOTE"] = "Add Note"
L["SHARE_QUEST"] = "Share Quest"
L["ABANDON_QUEST"] = "Abandon quest"

-- ============================================================================
-- Chat Messages
-- ============================================================================
L["MSG_PREFIX"] = "|cFF00FF00QuestMaster:|r"
L["MSG_ADDON_LOADED"] = "|cFFFFD700QuestMaster|r loaded! created by |cFF00FF00JugoBetrugoTV|r aka |cFFFF8800Novi_Live|r"
L["MSG_TWITCH"] = "|cFF9146FF  Twitch.tv/Novi_Live|r - Come hang out!"
L["MSG_BUGS"] = "|cFF888888  Bugs? Report on CurseForge or|r |cFF5865F2Discord.gg/rv2BsbE|r"

L["MSG_QUEST_ACCEPTED"] = "Quest accepted:"
L["MSG_ACCEPTED_QUEST"] = "Accepted quest:"
L["MSG_QUEST_COMPLETED"] = "Quest completed:"
L["MSG_QUEST_READY"] = "Quest ready to turn in:"
L["MSG_OBJECTIVE_COMPLETE"] = "Objective complete:"
L["MSG_ABANDONED"] = "Abandoned:"
L["MSG_SHARED"] = "Shared:"
L["MSG_CANNOT_SHARE"] = "This quest cannot be shared"
L["MSG_QUEST_NOT_FOUND"] = "Could not find quest in log"

L["MSG_LEVEL_UP"] = "|cFFFFD700LEVEL UP!|r You reached level |cFF00FF00%d|r!"
L["MSG_TIME_FROM_LEVEL"] = "Time from level %d to %d:"
L["MSG_REACHED_LEVEL"] = "Reached level %d!"
L["MSG_REACHED_LEVEL_TIME"] = "Reached level %d! (%s from level %d)"

L["MSG_WAYPOINT_SET"] = "Waypoint set to %.1f, %.1f - %s"
L["MSG_WAYPOINT_CORPSE"] = "Waypoint set to your corpse location"
L["MSG_WAYPOINT_RESTORED"] = "Restored previous waypoint"
L["MSG_NAVIGATING_TO"] = "Navigating to:"
L["MSG_AUTO_NAV_TURNIN"] = "Auto-navigating to turn-in"
L["MSG_AUTO_NAV_TO"] = "Auto-navigating to:"
L["MSG_NO_QUESTS_NAV"] = "No quests to navigate to"
L["MSG_TURNIN"] = "Turn in:"
L["MSG_NO_COMPLETED"] = "No completed quests to turn in"

L["MSG_XP_RESET"] = "XP/Hour tracker reset"
L["MSG_HISTORY_CLEARED"] = "Quest history cleared"
L["MSG_SESSION_RESET"] = "Session statistics reset"
L["MSG_NOTE_SAVED"] = "Note saved for:"
L["MSG_NOTE_DELETED"] = "Note deleted for:"

L["MSG_COORDS_INVALID"] = "Coordinates must be between 0 and 100"
L["MSG_NO_MAP"] = "Unable to determine current map"
L["MSG_INVALID_COORDS"] = "Invalid coordinates. Use: /qm way 45.2 67.8"
L["MSG_DB_FAIL"] = "Failed to initialize database:"
L["MSG_DB_WARNING"] = "Warning: Database profile not available"
L["MSG_INIT_FAIL"] = "Failed to initialize %s:"
L["MSG_SETTINGS_NOT_READY"] = "Settings not ready"
L["MSG_UNKNOWN_CMD"] = "Unknown command. Type /qm help for a list of commands."

-- Help
L["HELP_USAGE"] = "Usage:"
L["HELP_SEARCH"] = "Usage: /qm search <quest name or id>"
L["HELP_WAY"] = "Usage: /qm way <x> <y> [description]"
L["HELP_WAY_EXAMPLE"] = "  Example: /qm way 45.2 67.8 Meeting spot"
L["HELP_CREDITS"] = "/qm credits - Show credits"
L["HELP_STATS"] = "/qm stats - Show quest statistics"
L["HELP_SEARCH_CMD"] = "/qm search <name> - Search quest database"
L["HELP_WAY_CMD"] = "/qm way <x> <y> [desc] - Set manual waypoint"

-- Statistics Print
L["STATS_HEADER"] = "========== Quest Statistics =========="
L["STATS_TOTAL_COMPLETED"] = "Total Completed: %d quests"
L["STATS_TOTAL_XP"] = "Total XP from Quests:"
L["STATS_AVG_TIME"] = "Average Quest Time:"
L["STATS_QUESTS_HOUR"] = "Quests/Hour: %.1f"
L["STATS_FASTEST"] = "Fastest Quest: %s (%s)"
L["STATS_SLOWEST"] = "Slowest Quest: %s (%s)"
L["STATS_SESSION_HEADER"] = "--- Session Stats ---"
L["STATS_SESSION_COMPLETED"] = "Completed this session: %d quests"
L["STATS_SESSION_XP"] = "XP this session:"
L["STATS_TOP_ZONES"] = "--- Top Zones ---"

-- Search Results
L["SEARCH_NO_RESULTS"] = "No quests found for '%s'"
L["SEARCH_HEADER"] = "=== Quest Search: '%s' (%d results) ==="
L["SEARCH_COMPLETED"] = "[Completed]"
L["SEARCH_IN_PROGRESS"] = "[In Progress]"

-- Waypoint
L["WAYPOINT_FORMAT"] = "Waypoint (%.1f, %.1f)"
L["YOUR_CORPSE"] = "Your Corpse"

-- Tooltip
L["QUEST_ITEM"] = "Quest Item"
L["DROP_RATE_NOTE"] = "(Estimated drop rate varies)"
L["QUEST_NOTE"] = "Quest Note"

-- Time Format
L["TIME_HOURS_MINS"] = "%dh %dmin"
L["TIME_HOURS"] = "%dh"
L["TIME_MINS"] = "%d min"
L["TIME_ZERO"] = "0 min"
L["AVG_FORMAT"] = "(avg: %s)"
L["LVL_PREFIX"] = "Lvl:"
L["XP_HOUR_PREFIX"] = "XP/h:"
L["RESTED_PREFIX"] = "Rested:"

-- Responsive Layout
L["QM_SHORT"] = "QM"
L["QUESTS_SHORT"] = "Quests"

-- ============================================================================
-- Quest Type Tags (Dungeon/Group/Raid)
-- ============================================================================
L["DUNGEON_TAG"] = "D"
L["RAID_TAG"] = "R"
L["GROUP_TAG"] = "G"
L["DUNGEON_QUESTS"] = "Dungeon Quests"
L["RAID_QUESTS"] = "Raid Quests"

-- Best Time
L["BEST"] = "Best"
L["MSG_NEW_BEST_TIME"] = "New best time for %s: %s (previous: %s)"

-- ============================================================================
-- Party Quest Sync
-- ============================================================================
L["PARTY_SYNC"] = "Party Quest Sync"
L["ENABLE_PARTY_SYNC"] = "Enable Party Sync"
L["ENABLE_PARTY_SYNC_DESC"] = "Share quest progress with party"
L["PARTY_SHOW_PROGRESS"] = "Show Party Progress"
L["PARTY_SHOW_PROGRESS_DESC"] = "Display in tracker"
L["PARTY_SHOW_INDICATOR"] = "Show Party Indicator"
L["PARTY_SHOW_INDICATOR_DESC"] = "Icon on shared quests"
L["PARTY_SYNC_ICON"] = "P"

-- ============================================================================
-- Statistics Dashboard
-- ============================================================================
L["DASHBOARD_TITLE"] = "Dashboard"
L["DASH_TITLE"] = "Statistics Dashboard"
L["OPEN_DASHBOARD"] = "Open Dashboard"
L["DASH_OVERVIEW"] = "Overview"
L["DASH_ZONES"] = "Zone Progress"
L["DASH_HISTORY"] = "Quest History"
L["DASH_DETAILED_STATS"] = "Detailed Statistics"
L["DASH_FASTEST_QUEST"] = "Fastest Quest"
L["DASH_SLOWEST_QUEST"] = "Slowest Quest"
L["DASH_TOP_ZONES"] = "Top Quest Zones"
L["DASH_OVERALL_PROGRESS"] = "Overall Zone Progress"
L["DASH_NO_ZONE_DATA"] = "No zone progress data yet"
L["DASH_NO_HISTORY"] = "No quest history yet"
L["DASH_SHOWING_ENTRIES"] = "Showing %d of %d entries"
L["DASH_MORE_ENTRIES"] = "... and %d more entries"
L["DASH_SORT_TIME"] = "Time"
L["DASH_SORT_NAME"] = "Name"
L["DASH_SORT_LEVEL"] = "Level"
L["DASH_SORT_DURATION"] = "Duration"
L["DASH_COL_QUEST"] = "Quest"
L["DASH_COL_LEVEL"] = "Lvl"
L["DASH_COL_XP"] = "XP"
L["DASH_COL_TIME"] = "Time"
L["DASH_COL_DATE"] = "Date"

-- ============================================================================
-- Zone Filter
-- ============================================================================
L["ZONE_FILTER"] = "Current Zone Only"
L["ZONE_FILTER_DESC"] = "Only show quests for current zone"

-- ============================================================================
-- Enhanced Minimap Tooltip
-- ============================================================================
L["MINIMAP_ACTIVE_QUESTS"] = "Active Quests:"
L["MINIMAP_COMPLETED"] = "Completed:"
L["MINIMAP_IN_ZONE"] = "In Zone:"
L["MINIMAP_CURRENT_WAYPOINT"] = "Current Waypoint:"
L["MINIMAP_NO_WAYPOINT"] = "No active waypoint"
L["MINIMAP_LEFT_CLICK"] = "Left-Click: Open Settings"
L["MINIMAP_SHIFT_CLICK"] = "Shift+Left-Click: Toggle Tracker"
L["MINIMAP_RIGHT_CLICK"] = "Right-Click: Toggle Arrow"
L["MINIMAP_MIDDLE_CLICK"] = "Middle-Click: Clear Waypoint"

-- ============================================================================
-- Map Pin Tooltips
-- ============================================================================
L["PIN_TOOLTIP_AVAILABLE_QUEST"] = "Available Quest"
L["PIN_TOOLTIP_TURNIN_QUEST"] = "Turn In Quest"
L["PIN_TOOLTIP_DANGER_ZONE"] = "Danger Zone"
L["PIN_TOOLTIP_DANGER_ZONE_DESC"] = "Elite enemies in this area"
L["PIN_TOOLTIP_QUEST_OBJECTIVE"] = "Quest Objective"
L["PIN_TOOLTIP_ELITE_ENEMY"] = "Elite Enemy"
L["PIN_TOOLTIP_ELITE_BADGE"] = "[Elite]"
L["PIN_TOOLTIP_LEVEL"] = "Level %d"
L["PIN_TOOLTIP_CLICK_WAYPOINT"] = "Left-click: Set Waypoint"
L["MSG_WAYPOINT_SET_MANUAL"] = "Waypoint set (manual)"

-- ============================================================================
-- Debug Messages
-- ============================================================================
L["DEBUG_MESSAGE_TRUNCATED"] = "Party sync message truncated from %d to %d bytes"
