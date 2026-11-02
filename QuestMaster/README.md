# QuestMaster

**The Ultimate Quest Helper for WoW Classic**

QuestMaster is a comprehensive, standalone quest helper addon designed specifically for World of Warcraft Classic (1.15.8 - Season of Discovery). It provides everything you need to efficiently complete quests: a navigation arrow, distance tracking, world map pins, and an enhanced quest tracker.

---

## Features

### 🎯 Navigation Arrow
A clean, minimal navigation arrow that points you toward your current objective.

- **Real-time Distance**: See exactly how far you are from your target in yards
- **ETA Display**: Estimated time of arrival based on your current movement speed
- **Auto-Select Nearest**: Automatically points to your closest quest objective
- **Manual Waypoints**: Click on the map to set a waypoint that won't be overridden
- **Arrival Detection**: Arrow hides or shows "Arrived!" when you reach your destination
- **Fully Customizable**: Adjust size, transparency, and behavior

### 📋 Quest Tracker
A modern, customizable quest tracking panel that replaces the default tracker.

- **Zone Grouping**: Organize quests under zone headers
- **Smart Sorting**: Sort by distance, level, progress, or alphabetically
- **Difficulty Colors**: Quest names colored by level difficulty (gray → green → yellow → orange → red)
- **Collapse Objectives**: Hide completed objectives to reduce clutter
- **Adjustable Display**: Configure scale, transparency, and maximum quests shown
- **Draggable**: Position the tracker anywhere on your screen

### 🗺️ World Map Pins
Rich map integration showing exactly where to go for each quest.

- **Objective Pins**: See kill targets, loot locations, and interaction points
- **Quest Areas**: Colored circles highlighting where objectives can be found
- **Turn-in Markers**: Yellow "?" icons showing where to complete quests
- **Available Quests**: Yellow "!" icons for NPCs with new quests
- **Danger Zones**: Orange highlights warning of elite mob areas
- **Click to Navigate**: Click any pin to set it as your waypoint

### ⚡ Automation
Save time with intelligent quest automation features.

- **Auto-Accept**: Automatically accept quests from NPCs (hold Shift to skip)
- **Auto-Complete**: Automatically turn in completed quests (hold Shift to skip)
- **Smart Rewards**: Optionally skip auto-complete when you need to choose a reward
- **Auto-Share**: Share new quests with your party automatically
- **Auto-Track**: New quests are automatically tracked
- **Waypoint Automation**: Automatically advance to the next objective

### 🔊 Audio & Chat
Stay informed without watching the screen.

- **Progress Sounds**: Audio cues when making progress on objectives
- **Completion Sounds**: Know instantly when a quest is ready to turn in
- **Chat Announcements**: Optional messages for quest accept, complete, and progress

### 🌍 Multi-Language Support
QuestMaster is fully translated into 10 languages:

- 🇺🇸 English (Default)
- 🇩🇪 German (Deutsch)
- 🇫🇷 French (Français)
- 🇪🇸 Spanish (Español)
- 🇷🇺 Russian (Русский)
- 🇨🇳 Simplified Chinese (简体中文)
- 🇹🇼 Traditional Chinese (繁體中文)
- 🇰🇷 Korean (한국어)
- 🇧🇷 Brazilian Portuguese (Português)

The addon automatically detects your game client language and displays in your language.

---

## Installation

1. Download the latest release
2. Extract the `QuestMaster` folder to your `World of Warcraft\_classic_\Interface\AddOns\` directory
3. Restart WoW or `/reload` if already in-game
4. Type `/qm` to open settings

---

## Slash Commands

| Command | Description |
|---------|-------------|
| `/qm` | Open settings panel |
| `/qm arrow` | Toggle navigation arrow |
| `/qm tracker` | Toggle quest tracker |
| `/qm waypoint` | Clear current waypoint |
| `/qm reset` | Reset frame positions |

---

## Settings

QuestMaster offers extensive customization through six settings tabs:

### General
- Enable/disable the entire addon
- Lock frame positions
- Minimap button visibility
- Sound options
- Chat announcement settings

### Tracker
- Enable/disable tracker
- Scale and transparency
- Display options (level, distance, completed quests)
- Sorting preferences
- Zone grouping

### Arrow
- Enable/disable arrow
- Size and transparency
- Objective text display
- ETA display
- Auto-select behavior
- Arrival distance threshold

### Map
- World map pin settings
- Pin types (objectives, turn-ins, available quests, danger zones)
- Pin size and transparency
- Minimap pin options

### Automation
- Quest accept/complete automation
- Waypoint automation
- Quest tracking preferences

### Advanced
- Quest filtering (dungeon, raid, group, PvP, low-level)
- Tooltip enhancements
- Performance settings
- Debug mode

---

## Features Overview

| Feature | QuestMaster |
|---------|-------------|
| Navigation Arrow | ✅ Clean minimal design |
| Quest Tracker | ✅ Highly customizable |
| Map Pins | ✅ Full featured |
| Standalone | ✅ No dependencies |
| Multi-language | ✅ 10 languages |
| TBC Classic 2.5.5 | ✅ Optimized |
| Free | ✅ Completely free |

---

## FAQ

**Q: Does QuestMaster work with TBC Classic Anniversary Edition?**
A: Yes! QuestMaster is built specifically for WoW TBC Classic 2.5.5 (Anniversary Edition).

**Q: Does it conflict with other quest addons?**
A: QuestMaster is designed to be standalone. You can use it alongside other addons, but it's recommended to disable overlapping features.

**Q: How do I set a manual waypoint?**
A: Open your world map and click on any quest pin, or Ctrl+click anywhere on the map to set a waypoint. Manual waypoints won't be overridden by auto-select.

**Q: Can I hide the default Blizzard quest tracker?**
A: QuestMaster works alongside the default tracker. You can minimize the default tracker in the Blizzard interface options.

**Q: The arrow points to the wrong location?**
A: Some quests have multiple valid locations. You can click on the tracker or map to select a different objective location.

**Q: How do I report a bug?**
A: Please report issues on our GitHub page with your WoW version and steps to reproduce.

---

## Credits

- **Development**: QuestMaster Team
- **Libraries**: Ace3, HereBeDragons, LibDBIcon
- **Quest Data**: Community-sourced Classic WoW database
- **Translations**: Community contributors

---

## License

QuestMaster is open source and free to use. See LICENSE file for details.

---

## Support

- **GitHub**: Report issues and request features
- **Discord**: Join our community for help and discussion
- **CurseForge**: Rate and review to help others find us!

---

*Happy questing!* 🎮
