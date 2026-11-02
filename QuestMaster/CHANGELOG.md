# QuestMaster Changelog

All notable changes to QuestMaster will be documented in this file.

---

## [2.0.0] - 2026-03-07 — "All-in-One"

> **Major Release** — Multi-expansion support, Statistics Dashboard, Party Sync,
> Quest Item Buttons, Floating Objective Frame, modular Tracker architecture,
> and a redesigned premium UI.

---

### Added

- **Multi-Expansion Support**: Single addon for all Classic expansions
  - Classic Era / Season of Discovery (Interface 11500+)
  - TBC Classic (Interface 20505)
  - Wrath Classic (Interface 30800)
  - MoP Remix / Classic (Interface 50503)
  - Automatic game version detection via `VersionDetect.lua`
  - Per-expansion quest databases (Classic, TBC, Wrath, MoP)
  - Unified TOC files per expansion with shared module structure
  - Feature flags: `hasOutland`, `hasNorthrend`, `hasCataZones`, `hasPandaria`

- **Statistics Dashboard** (`/qm dashboard`)
  - Standalone popup window with three tabs: Overview, Zones, History
  - **Overview**: Total quests, XP gained, average completion time, quests/hour
  - **Zones**: Per-zone progress bars showing completed/total quests
  - **History**: Full quest completion log with search, sort (time/name/level/duration), and filtering
  - Progress bars with percentage display
  - Premium dark UI matching the main Settings panel

- **Party Quest Sync** (PartySync module)
  - Real-time quest progress broadcasting to party members via addon messages
  - Displays party member quest progress in tracker
  - Message types: quest list, quest update, quest completed, quest accepted
  - Throttled broadcasting (2s cooldown) to prevent message spam
  - Toggle in Settings: enable/disable, show in tracker, party indicator icons

- **Quest Item Buttons** (SecureActionButton)
  - Usable quest items displayed directly in the tracker (e.g. collection tools, quest gadgets)
  - Click-to-use via secure action button framework
  - Cooldown display with countdown
  - Tooltip on hover showing item info
  - Supports `showItemWhenComplete` flag
  - Toggle on/off in Tracker settings

- **Floating Objective Frame** (ObjectiveFrame module)
  - Heads-up display showing current quest objective below the navigation arrow
  - Quest icon, title, and objective text with progress
  - Built-in progress bar with percentage
  - Pulse animation for active objectives
  - Draggable, movable position
  - Auto-hides when no active objective

- **Turn-in Indicators**
  - Yellow question mark icon on completed quests in the tracker
  - "COMPLETE" badge text next to turn-in indicator
  - Visual clarity for quests ready to hand in

- **Active Quest Glow**
  - Subtle gold highlight on the quest currently tracked by the navigation arrow
  - Instantly shows which quest the arrow is pointing to

- **Dungeon/Raid Quest Grouping**
  - Dungeon and raid quests automatically grouped in separate tracker sections
  - Grouped by dungeon name with distinct zone headers
  - Keeps the main quest list focused on outdoor quests

- **Hide Blizzard Quest Tracker**
  - Option to hide the default Blizzard objective tracker
  - Prevents UI clutter when using QuestMaster's tracker
  - Toggleable in Tracker settings

- **Modular Tracker Architecture** (Modules/Tracker/)
  - `Core.lua` — Shared state, constants, frame pools, color definitions
  - `Helpers.lua` — Utility functions for tracker rendering
  - `Sorting.lua` — Quest sorting algorithms (distance, level, progress, name)
  - `Distance.lua` — Distance calculation and color gradients
  - `Actions.lua` — Click handlers, quest interaction logic
  - `Menu.lua` — Right-click context menu system

### Changed

- **Redesigned Premium UI**
  - Unified dark design system across all modules (Tracker, Settings, Dashboard, Arrow)
  - Consistent color palette: dark backgrounds, gold accents, muted text hierarchy
  - Theme system applies to tracker elements (selected glow, turn-in icons, zone headers)
  - Improved font sizing hierarchy (Header 11, Zone 10, Quest 9, Small 8)
  - Refined spacing and padding for compact and normal display modes

- **Version Bump to 2.0.0** across all TOC files
  - QuestMaster.toc (MoP — Interface 50503)
  - QuestMaster_TBC.toc (TBC — Interface 20505)
  - QuestMaster_Wrath.toc (Wrath — Interface 30800)
  - QuestMaster_Vanilla.toc (Classic — Interface 20505)

- **Quest Database**: Expanded from TBC-only to full multi-expansion coverage
  - Separate data files per expansion: QuestData, CreatureData, GameObjectData, ItemSourceData
  - `DatabaseLoader.lua` loads the correct dataset based on detected game version

- **Settings Panel**: Added Dashboard tab for quick statistics access

### Fixed

- **Protected Frame Errors**: Fixed `SetPoint` crash when anchoring SecureActionButton (itemButton) to a FontString
  - Item buttons now correctly anchor to parent frame instead of distance FontString
  - Equivalent visual positioning maintained (frame RIGHT -58 vs fontstring offset)

- **Quest Item Cooldown API**: Fixed `GetItemCooldown` not existing in MoP Classic
  - Now uses `C_Container.GetItemCooldown` (preferred) with proper fallback chain
  - Passes item ID instead of item link to cooldown API
  - Uses `GetItemInfoInstant(link)` for reliable item ID and texture retrieval

- **Combat Lockdown Protection**: Fixed `ADDON_ACTION_BLOCKED` errors during combat
  - `UpdateTracker()` defers to `PLAYER_REGEN_ENABLED` when tracker contains protected frames
  - `UpdateInfoBar()` skips layout changes during combat lockdown
  - `UpdateTrackerVisibility()` skips Show/Hide during combat
  - `ReleaseFrame()` skips Hide/ClearAllPoints on protected quest frames in combat
  - Item button Show/Hide/SetAttribute operations guarded by `InCombatLockdown()`

- **showItemWhenComplete**: Quest items now respect the 4th return value of `GetQuestLogSpecialItemInfo`
  - Items that should remain visible after quest completion now stay visible

---

## [1.3.0] - 2026-01-25

### Added
- **Complete Localization System**: Full UI translation support
  - German (deDE) - Complete translation
  - French (frFR) - Complete translation
  - Spanish (esES/esMX) - Complete translation
  - Russian (ruRU) - Complete translation
  - Portuguese Brazilian (ptBR) - Complete translation
  - 300+ localization keys covering entire interface
  - All settings, tooltips, messages, and UI elements now translatable

- **Quest Statistics Panel** (moved from tracker to Settings)
  - Total quests completed
  - Total XP gained from quests
  - Average quest completion time
  - Quests per hour rate
  - Fastest/slowest quest tracking
  - Session statistics (quests, XP since level-up)
  - Time on current level

- **Quest Search Feature** (moved from tracker to Settings)
  - Search quest database by name or ID
  - Clickable results that set waypoint to quest start
  - Shows quest objectives in tooltip
  - Indicates completed/in-progress status

- **Manual Waypoint Card** (moved from tracker to Settings)
  - Enter X/Y coordinates manually
  - Larger input fields for better usability
  - Set/Clear waypoint buttons
  - Current waypoint display

### Changed
- **Settings Reorganization**: Moved Stats/Search/Waypoint from tracker toolbar to Settings panel
  - Cleaner tracker interface without toolbar clutter
  - Statistics tab now contains all tracking features
  - Better organization of related features

- **UI Improvements**
  - Larger settings cards for better readability (200px height)
  - Bigger input fields for coordinates (70px)
  - Clickable search results with quest info tooltips
  - Improved button spacing and layout
  - Fixed overlapping elements in tracker header

### Fixed
- **Quest Progress Display**: Fixed objectives showing incorrect numbers (e.g., "7/1")
  - Progress values now properly capped at required amount
  - Improved objective text parsing for German and other language formats
  - Added fallback pattern to find X/Y in any text format

- **Manual Waypoint Override**: Fixed waypoints being overwritten by auto-waypoint
  - Manual waypoints with questId=0 or isManual flag now persist
  - Coordinates entered manually no longer get replaced
  - Auto-waypoint respects user-set coordinates

- **Level Time Tracking**: Fixed time resetting on login/reload
  - Now correctly tracks time since actual level-up
  - Persists across game sessions using Unix timestamps
  - Stored in db.char.levelTimeData for persistence

- **Statistics Persistence**: Fixed quest stats being reset
  - Changed from db.char to db.profile for proper persistence
  - Session stats now linked to level data
  - Properly resets on level-up

- **Toolbar Layout**: Fixed buttons overlapping with "Active Quests" header
  - Increased toolbar height and spacing
  - Fixed SetPoint syntax errors causing empty tracker

- **Progress Text Width**: Fixed numbers being truncated (18/3 instead of 18/30)
  - Increased progress text width to 44px
  - Adjusted text offset from -35px to -50px for proper display

- **Reputation Tracker**: Fixed tooltip display
  - Added standing name to reputation data
  - Properly shows faction progress in info bar tooltip

- **Localization Key Errors**: Fixed missing localization keys
  - MSG_XP_RESET properly referenced

## [1.2.0] - 2026-01-20

### Added
- **Theme System**: 10 color themes for UI customization
  - Gold (Default), Blue, Green, Red, Purple
  - Orange, Teal, Pink, Silver, Bronze
  - Live theme updates across all panels
  - Dedicated Credits tab with developer info

- **XP/Hour Tracker**: Real-time XP rate calculation
  - Shows XP gained per hour
  - Time to level estimate
  - Displays in tracker info bar

- **Rested XP Display**: Show rested bonus in info bar
  - Rested amount and bubbles
  - +50% bonus indicator
  - Color-coded display

- **Level Time Tracker**: Track time spent per level
  - Current level time
  - Average time per level
  - Persists across sessions

- **Reminders System**: Bag space and repair warnings
  - Configurable bag space threshold
  - Low durability warnings
  - Non-intrusive notifications

- **Zone Progress Tracker**: Track quest completion per zone
  - Shows completed/total quests
  - Percentage display option
  - Updates in info bar

- **Reputation Tracker**: Display watched faction progress
  - Shows in tracker info bar
  - Detailed tooltip with standing
  - Color-coded by reputation level

- **Quest Notes**: Add personal notes to quests
  - Right-click menu to add/edit notes
  - Notes display in quest tooltip
  - Configurable max note length

- **NPC Patrol Paths**: Visualize NPC movement routes on map
  - Toggle in map settings
  - Configurable opacity
  - Light blue patrol lines

### Changed
- Premium styling for tracker and settings panels
- Improved visual consistency across all UI elements
- Redesigned quest tracker with better spacing
- ASCII icons for better font compatibility

### Fixed
- Quest timer persistence across sessions
- Various UI alignment issues
- Improved quest sorting algorithms

## [1.1.0] - 2026-01-15

### Added
- **Info Bar**: Combined status display above quest list
  - XP per hour
  - Rested XP indicator
  - Level time
  - Zone progress
  - Reputation (when watched)

- **Quest Timer**: Track time spent on individual quests
  - Shows duration in quest tooltip
  - Persists across sessions
  - Rankings for fastest/slowest

### Changed
- Redesigned quest tracker header with navigation buttons
- Improved settings panel organization
- Better sort dropdown styling

### Fixed
- Quest objective updates not triggering properly
- Map pin positions on zone change
- Memory optimization for large quest databases

## [1.0.0] - 2026-01-12

### Added
- **Navigation Arrow**: Clean, minimal arrow design pointing to quest objectives
  - Real-time distance display in yards
  - ETA (Estimated Time of Arrival) based on movement speed
  - Automatic selection of nearest objective
  - Manual waypoint support (click on map to set waypoint that won't be overridden)
  - Configurable arrival distance threshold
  - Hide on arrival option
  - Draggable position

- **Quest Tracker**: Custom quest tracking panel
  - Draggable and scalable interface
  - Group quests by zone option
  - Sort by distance, level, progress, or alphabetically
  - Color-coded quest difficulty (gray/green/yellow/orange/red)
  - Collapse completed objectives
  - Show/hide completed quests
  - Maximum quests display limit
  - Configurable background transparency
  - Click to navigate, right-click for menu

- **World Map Integration**: Quest pins on the world map
  - Objective location pins (kill/loot/interact targets)
  - Quest area highlighting with colored circles
  - Turn-in NPC pins (yellow ?)
  - Available quest pins (yellow !)
  - Danger zone indicators for elite areas
  - Configurable pin size and transparency
  - Click pins to set manual waypoint

- **Minimap Integration**
  - Minimap button for quick access to settings
  - Minimap objective pins
  - Quest giver tracking icons

- **Quest Automation**
  - Auto-accept quests from NPCs (hold Shift to skip)
  - Auto-complete quests (hold Shift to skip)
  - Skip auto-complete when reward choice required
  - Auto-share quests with party members

- **Waypoint Automation**
  - Auto-set waypoint to nearest quest objective
  - Auto-advance to next objective on completion
  - Prioritize turn-in NPCs over new objectives
  - Corpse waypoint on death

- **Quest Tracking Features**
  - Auto-track new quests on accept
  - Auto-untrack quests after completion
  - Track party member quests

- **Quest Filtering**
  - Filter dungeon/raid/group/PvP quests
  - Show/hide low-level (gray) quests

- **Tooltip Enhancements**
  - Quest info in NPC/item tooltips
  - Objective progress display
  - Estimated drop rates for quest items

- **Sound Options**
  - Quest progress sound
  - Quest complete sound
  - Objective complete sound

- **Chat Announcements**
  - Announce quest accept (to party/guild)
  - Announce quest complete (to party/guild)
  - Announce level up (to emote/party/guild)
  - Announce objective progress

- **Multi-Language Support**
  - English (enUS) - Default
  - German (deDE)
  - French (frFR)
  - Spanish (esES/esMX)
  - Russian (ruRU)
  - Simplified Chinese (zhCN)
  - Traditional Chinese (zhTW)
  - Korean (koKR)
  - Brazilian Portuguese (ptBR)

- **Comprehensive Quest Database**
  - Full TBC Classic quest data
  - NPC spawn locations with coordinates
  - Object spawn locations
  - Item drop sources
  - Quest chains and prerequisites

- **Settings Panel**
  - Organized tabs: General, Tracker, Arrow, Map, Statistics, Automation, Advanced, Credits
  - All features fully configurable
  - Reset to defaults option
  - Frame position reset
  - Profile support via AceDB

- **Slash Commands**
  - /qm - Open settings
  - /qm arrow - Toggle arrow
  - /qm tracker - Toggle tracker
  - /qm way X Y [desc] - Set manual waypoint
  - /qm search [name] - Search quest database
  - /qm stats - Show quest statistics
  - /qm credits - Show credits
  - /qm reset - Reset frame positions

### Technical
- Built for all WoW Classic expansions (Classic Era through MoP Remix)
- Automatic version detection with per-expansion feature flags
- Uses Ace3 framework (AceDB, AceEvent, AceTimer, AceConfig, AceGUI)
- HereBeDragons-2.0 for map coordinate handling
- LibDBIcon for minimap button
- LibDataBroker for data display
- Efficient frame pooling for map pins and tracker elements
- SecureActionButton framework for quest item buttons
- Combat lockdown awareness for protected frame operations
- Profile-based settings with character-specific options
- Modular code architecture with split Tracker subsystem

---

**Created by JugoBetrugoTV (Novi_Live)**
- Twitch: twitch.tv/Novi_Live
- Discord: discord.gg/rv2BsbE

For bug reports and feature requests, please visit CurseForge or Discord.
