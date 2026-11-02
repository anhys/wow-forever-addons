-- QuestMaster Simplified Chinese Localization
local addonName, QM = ...
if GetLocale() ~= "zhCN" then return end

local L = QM.L

-- ============================================================================
-- General
-- ============================================================================
L["ADDON_LOADED"] = "QuestMaster 已加载。输入 /qm 查看选项。"
L["VERSION"] = "版本"
L["ENABLED"] = "已启用"
L["DISABLED"] = "已禁用"
L["YES"] = "是"
L["NO"] = "否"
L["DEFAULT"] = "默认"
L["RESET"] = "重置"
L["CLOSE"] = "关闭"
L["SAVE"] = "保存"
L["CANCEL"] = "取消"
L["DELETE"] = "删除"
L["UNKNOWN"] = "未知"
L["NONE"] = "无"
L["GO"] = "前往"
L["SEARCH"] = "搜索"
L["REFRESHED"] = "已刷新"

-- ============================================================================
-- Tabs
-- ============================================================================
L["TAB_GENERAL"] = "常规"
L["TAB_GENERAL_DESC"] = "核心设置"
L["TAB_TRACKER"] = "追踪器"
L["TAB_TRACKER_DESC"] = "任务列表"
L["TAB_ARROW"] = "箭头"
L["TAB_ARROW_DESC"] = "导航"
L["TAB_MAP"] = "地图"
L["TAB_MAP_DESC"] = "标记和图钉"
L["TAB_STATISTICS"] = "统计"
L["TAB_STATISTICS_DESC"] = "经验追踪"
L["TAB_DASHBOARD"] = "仪表盘"
L["TAB_DASHBOARD_DESC"] = "统计与历史"
L["TAB_AUTOMATION"] = "自动化"
L["TAB_AUTOMATION_DESC"] = "自动功能"
L["TAB_ADVANCED"] = "高级"
L["TAB_ADVANCED_DESC"] = "专家"
L["TAB_CREDITS"] = "制作人员"
L["TAB_CREDITS_DESC"] = "关于和链接"

-- ============================================================================
-- Settings Header
-- ============================================================================
L["SETTINGS"] = "设置"
L["SETTINGS_TITLE"] = "QuestMaster 设置"

-- ============================================================================
-- General Settings
-- ============================================================================
L["MAIN_SETTINGS"] = "主要设置"
L["ENABLE_ADDON"] = "启用 QuestMaster"
L["ENABLE_ADDON_DESC"] = "所有功能的主开关"
L["LOCK_FRAMES"] = "锁定窗口位置"
L["LOCK_FRAMES_DESC"] = "防止拖动"
L["SHOW_MINIMAP_BUTTON"] = "显示小地图按钮"
L["SHOW_MINIMAP_BUTTON_DESC"] = "在小地图上显示按钮"

-- ============================================================================
-- Sounds
-- ============================================================================
L["SOUNDS"] = "音效"
L["QUEST_PROGRESS_SOUND"] = "任务进度音效"
L["QUEST_PROGRESS_SOUND_DESC"] = "进度时播放音效"
L["QUEST_COMPLETE_SOUND"] = "任务完成音效"
L["QUEST_COMPLETE_SOUND_DESC"] = "完成时播放音效"

-- ============================================================================
-- Announcements
-- ============================================================================
L["QUEST_ANNOUNCEMENTS"] = "任务通知"
L["ANNOUNCE_ACCEPT"] = "通知接受任务"
L["ANNOUNCE_ACCEPT_DESC"] = "向队伍/公会"
L["ACCEPT_CHANNEL"] = "接受频道"
L["ANNOUNCE_DONE"] = "通知任务完成"
L["ANNOUNCE_DONE_DESC"] = "向队伍/公会"
L["COMPLETE_CHANNEL"] = "完成频道"
L["CHANNEL_PARTY"] = "队伍"
L["CHANNEL_GUILD"] = "公会"
L["CHANNEL_EMOTE"] = "表情 (/me)"
L["CHANNEL_DISABLED"] = "已禁用"

-- Level Up
L["LEVEL_UP_ANNOUNCEMENTS"] = "升级通知"
L["ANNOUNCE_LEVEL_UP"] = "通知升级"
L["ANNOUNCE_LEVEL_UP_DESC"] = "向表情/队伍"
L["LEVEL_UP_CHANNEL"] = "升级频道"

-- ============================================================================
-- Quick Actions
-- ============================================================================
L["QUICK_ACTIONS"] = "快捷操作"
L["RESET_POSITIONS"] = "重置位置"
L["REFRESH_DATA"] = "刷新数据"

-- ============================================================================
-- Quest Tracker
-- ============================================================================
L["QUEST_TRACKER"] = "任务追踪器"
L["ENABLE_TRACKER"] = "启用追踪器"
L["ENABLE_TRACKER_DESC"] = "显示任务面板"
L["FONT_SIZE"] = "字体大小"
L["BACKGROUND_OPACITY"] = "背景透明度"
L["TRACKER_TITLE"] = "QuestMaster"
L["ACTIVE_QUESTS"] = "进行中的任务"
L["READY_FOR_TURNIN"] = "准备交付"
L["NO_ACTIVE_QUESTS"] = "无进行中的任务"

-- Display Options
L["DISPLAY_OPTIONS"] = "显示选项"
L["SHOW_QUEST_LEVEL"] = "显示任务等级"
L["SHOW_QUEST_LEVEL_DESC"] = "括号中的等级"
L["SHOW_DISTANCE"] = "显示距离"
L["SHOW_DISTANCE_DESC"] = "到目标的距离"
L["COLOR_BY_DIFFICULTY"] = "按难度着色"
L["COLOR_BY_DIFFICULTY_DESC"] = "基于等级的颜色"
L["SHOW_PROGRESS_BARS"] = "显示进度条"
L["SHOW_PROGRESS_BARS_DESC"] = "目标下方的进度条"
L["SHOW_COMPLETED"] = "显示已完成任务"
L["SHOW_COMPLETED_DESC"] = "显示已完成的任务"
L["MAX_QUESTS"] = "最大显示任务数"

-- Default Tracker
L["HIDE_BLIZZARD_TRACKER"] = "隐藏默认任务追踪器"
L["HIDE_BLIZZARD_TRACKER_DESC"] = "隐藏暴雪内置的任务追踪器"
L["HIDE_BLIZZARD_TRACKER_COMBAT"] = "战斗中无法切换默认追踪器。"
L["HIDE_BLIZZARD_TRACKER_RELOAD"] = "重新启用默认追踪器需要重载界面。是否立即重载？"

-- Sorting
L["SORTING"] = "排序"
L["SORT_BY"] = "排序方式"
L["SORT_QUESTS_BY"] = "任务排序方式"
L["SORT_DISTANCE"] = "距离"
L["SORT_LEVEL"] = "等级"
L["CURRENT"] = "当前"

-- Tracker Buttons
L["SORT"] = "排序"
L["NAVIGATE_TO_NEAREST"] = "导航到最近"
L["CLICK_TO_SET_WAYPOINT"] = "点击设置路径点"
L["NAVIGATE_TO_TURNIN"] = "导航到交任务NPC"
L["NEAREST_COMPLETED_QUEST"] = "最近的已完成任务"

-- ============================================================================
-- Arrow
-- ============================================================================
L["NAVIGATION_ARROW"] = "导航箭头"
L["ENABLE_ARROW"] = "启用箭头"
L["ENABLE_ARROW_DESC"] = "显示导航箭头"
L["ARROW_SIZE"] = "箭头大小"
L["ARROW_OPACITY"] = "箭头透明度"
L["ARRIVAL_DISTANCE"] = "到达距离"

-- Arrow Display
L["DISPLAY"] = "显示"
L["SHOW_OBJECTIVE"] = "显示目标"
L["SHOW_OBJECTIVE_DESC"] = "目标文本"
L["SHOW_ETA"] = "显示预计到达时间"
L["SHOW_ETA_DESC"] = "时间估算"

-- Arrow Status
L["ARRIVED"] = "已到达！"
L["NO_ACTIVE_OBJECTIVE"] = "无活动目标"
L["QUEST_OBJECTIVE"] = "任务目标"
L["YARDS"] = "码"
L["KILOMETERS"] = "公里"

-- Arrow Tooltip
L["ARROW_NAVIGATION"] = "导航"
L["OBJECTIVE"] = "目标"
L["LEFT_CLICK_DRAG"] = "左键拖动移动"
L["RIGHT_CLICK_OPTIONS"] = "右键打开选项"

-- Arrow Context Menu
L["HIDE_ARROW"] = "隐藏箭头"
L["CLEAR_WAYPOINT"] = "清除路径点"
L["FIND_NEAREST_AUTO"] = "查找最近（自动）"
L["OPEN_SETTINGS"] = "打开设置"

-- ETA
L["ETA"] = "预计到达"
L["ETA_SECONDS"] = "预计: %d秒"
L["ETA_MINUTES"] = "预计: %d分%d秒"
L["ETA_HOURS"] = "预计: %d小时%d分"
L["MOVE_TO_CALCULATE"] = "（移动以计算预计时间）"

-- ============================================================================
-- Map
-- ============================================================================
L["WORLD_MAP"] = "世界地图"
L["ENABLE_MAP_PINS"] = "启用地图标记"
L["ENABLE_MAP_PINS_DESC"] = "显示任务标记"
L["PIN_SIZE"] = "标记大小"
L["PIN_OPACITY"] = "标记透明度"

-- Pin Types
L["PIN_TYPES"] = "标记类型"
L["OBJECTIVE_PINS"] = "目标标记"
L["OBJECTIVE_PINS_DESC"] = "任务目标"
L["QUEST_AREAS"] = "任务区域"
L["QUEST_AREAS_DESC"] = "高亮区域"
L["TURNIN_PINS"] = "交任务标记 (?)"
L["TURNIN_PINS_DESC"] = "黄色问号标记"
L["AVAILABLE_QUESTS"] = "可接任务 (!)"
L["AVAILABLE_QUESTS_DESC"] = "黄色感叹号标记"
L["PATROL_PATHS"] = "NPC巡逻路线"
L["PATROL_PATHS_DESC"] = "显示巡逻路线"

-- ============================================================================
-- Statistics Tab
-- ============================================================================
L["QUEST_TIMER"] = "任务计时器"
L["ENABLE_TIMER"] = "启用计时器"
L["ENABLE_TIMER_DESC"] = "追踪任务时间"
L["SHOW_IN_TRACKER"] = "在追踪器中显示"
L["SHOW_IN_TRACKER_DESC"] = "在追踪器中显示"

L["XP_PER_HOUR"] = "每小时经验"
L["ENABLE_XP_TRACKER"] = "启用经验追踪器"
L["ENABLE_XP_TRACKER_DESC"] = "计算经验速率"
L["RESET_XP"] = "重置经验"

L["RESTED_XP"] = "休息经验"
L["ENABLE_RESTED_DISPLAY"] = "启用休息显示"
L["ENABLE_RESTED_DISPLAY_DESC"] = "显示休息经验"
L["SHOW_BONUS_INDICATOR"] = "显示+50%加成"
L["SHOW_BONUS_INDICATOR_DESC"] = "显示加成指示器"

L["LEVEL_TIME"] = "等级时间"
L["ENABLE_LEVEL_TIMER"] = "启用等级计时器"
L["ENABLE_LEVEL_TIMER_DESC"] = "追踪每级时间"
L["SHOW_AVERAGE"] = "显示平均"
L["SHOW_AVERAGE_DESC"] = "显示平均时间"

L["REMINDERS"] = "提醒"
L["ENABLE_REMINDERS"] = "启用提醒"
L["ENABLE_REMINDERS_DESC"] = "背包和修理警告"
L["BAG_SPACE_WARNING"] = "背包空间警告"
L["BAG_SPACE_WARNING_DESC"] = "背包满时警告"
L["BAG_THRESHOLD"] = "背包阈值"
L["REPAIR_WARNING"] = "修理警告"
L["REPAIR_WARNING_DESC"] = "耐久度低时警告"

L["ZONE_PROGRESS"] = "区域进度"
L["ENABLE_ZONE_PROGRESS"] = "启用区域进度"
L["ENABLE_ZONE_PROGRESS_DESC"] = "按区域追踪"

L["REPUTATION"] = "声望"
L["ENABLE_REP_TRACKER"] = "启用声望追踪器"
L["ENABLE_REP_TRACKER_DESC"] = "追踪监视阵营"

-- Quest Statistics
L["QUEST_STATISTICS"] = "任务统计"
L["TOTAL_STATISTICS"] = "总计统计"
L["QUESTS_COMPLETED"] = "已完成任务"
L["TOTAL_XP_GAINED"] = "总获得经验"
L["AVG_QUEST_TIME"] = "平均任务时间"
L["QUESTS_PER_HOUR"] = "每小时任务"
L["CURRENT_LEVEL"] = "当前等级"
L["TIME_ON_LEVEL"] = "当前等级时间"
L["SESSION_QUESTS"] = "本次任务"
L["SESSION_XP"] = "本次经验"
L["REFRESH_STATS"] = "刷新统计"
L["RESET_SESSION"] = "重置本次"

-- Quest Search
L["QUEST_SEARCH"] = "任务搜索"
L["SEARCH_PLACEHOLDER"] = "输入任务名称或ID..."
L["CLICK_RESULT_HINT"] = "点击结果设置路径点到任务起始位置"
L["NO_QUESTS_FOUND"] = "未找到匹配的任务:"
L["WAYPOINT_SET_TO_QUEST"] = "路径点已设置到任务:"
L["NO_LOCATION_DATA"] = "无位置数据:"
L["QUEST_LABEL"] = "任务:"
L["OBJECTIVES_LABEL"] = "目标:"

-- Manual Waypoint
L["MANUAL_WAYPOINT"] = "手动路径点"
L["WAYPOINT"] = "路径点"
L["MANUAL"] = "[手动]"
L["CURRENT_WAYPOINT"] = "当前:"
L["NO_WAYPOINT_SET"] = "未设置路径点"
L["X_COORD"] = "X:"
L["Y_COORD"] = "Y:"
L["SET"] = "设置"
L["INVALID_COORDINATES"] = "无效坐标 (0-100)"
L["COORD_HINT"] = "输入坐标如 45.5 和 67.2（值 0-100）"

-- ============================================================================
-- Automation Tab
-- ============================================================================
L["QUEST_AUTOMATION"] = "任务自动化"
L["AUTO_ACCEPT"] = "自动接受任务"
L["AUTO_ACCEPT_DESC"] = "按住Shift跳过"
L["AUTO_COMPLETE"] = "自动完成任务"
L["AUTO_COMPLETE_DESC"] = "按住Shift跳过"
L["SKIP_REWARD_CHOICE"] = "跳过奖励选择"
L["SKIP_REWARD_CHOICE_DESC"] = "等待选择"
L["AUTO_SHARE"] = "自动分享任务"
L["AUTO_SHARE_DESC"] = "与队伍分享"

L["WAYPOINT_AUTO"] = "路径点自动"
L["AUTO_SET_WAYPOINT"] = "自动设置路径点"
L["AUTO_SET_WAYPOINT_DESC"] = "最近的任务"
L["AUTO_ADVANCE"] = "自动前进"
L["AUTO_ADVANCE_DESC"] = "完成后下一个"
L["PRIORITIZE_TURNINS"] = "优先交任务"
L["PRIORITIZE_TURNINS_DESC"] = "先交任务"

L["QUEST_FILTERS"] = "任务过滤"
L["SHOW_DUNGEON"] = "显示副本任务"
L["SHOW_DUNGEON_DESC"] = "包含副本任务"
L["SHOW_RAID"] = "显示团队任务"
L["SHOW_RAID_DESC"] = "包含团队任务"
L["SHOW_GROUP"] = "显示组队任务"
L["SHOW_GROUP_DESC"] = "包含组队任务"
L["SHOW_PVP"] = "显示PvP任务"
L["SHOW_PVP_DESC"] = "包含PvP任务"
L["SHOW_LOW_LEVEL"] = "显示低等级任务"
L["SHOW_LOW_LEVEL_DESC"] = "包含灰色任务"

-- ============================================================================
-- Advanced Tab
-- ============================================================================
L["THEME"] = "主题"
L["COLOR_THEME"] = "颜色主题"
L["THEME_GOLD"] = "金色（默认）"
L["THEME_BLUE"] = "蓝色"
L["THEME_GREEN"] = "绿色"
L["THEME_RED"] = "红色"
L["THEME_PURPLE"] = "紫色"
L["THEME_ORANGE"] = "橙色"
L["THEME_TEAL"] = "青色"
L["THEME_PINK"] = "粉色"
L["THEME_SILVER"] = "银色"
L["THEME_BRONZE"] = "青铜色"

L["PERFORMANCE"] = "性能"
L["UPDATE_INTERVAL"] = "更新间隔"
L["UPDATE_THROTTLE"] = "更新节流"
L["REDUCE_MAP_UPDATES"] = "减少地图更新"
L["REDUCE_MAP_UPDATES_DESC"] = "延迟更新"

L["QUEST_NOTES"] = "任务笔记"
L["MAX_NOTE_LENGTH"] = "最大笔记长度"

L["DEBUG_TOOLS"] = "调试和工具"
L["DEBUG_MODE"] = "调试模式"
L["DEBUG_MODE_DESC"] = "聊天调试信息"
L["RESET_SETTINGS"] = "重置设置"
L["RELOAD_UI"] = "重载界面"
L["RESET_CONFIRM"] = "重置所有 QuestMaster 设置？"

-- ============================================================================
-- Credits Tab
-- ============================================================================
L["CREDITS_VERSION"] = "版本 1.3"
L["CREDITS_EDITION"] = "全合一版"
L["CREDITS_DESCRIPTION"] = "具有导航箭头、地图标记、统计和自动化功能的高级任务追踪插件。"
L["DEVELOPER"] = "开发者"
L["ALSO_KNOWN_AS"] = "又名"
L["DEVELOPER_BIO"] = "WoW 插件开发者和内容创作者。在 Twitch.tv/Novi_Live 直播"
L["CONNECT"] = "联系"
L["TWITCH"] = "Twitch"
L["DISCORD"] = "Discord"
L["CURSEFORGE"] = "CurseForge"
L["DOWNLOADS_BUGS"] = "下载和错误报告"
L["CHANGELOG"] = "更新日志"
L["SPECIAL_THANKS"] = "特别感谢"
L["THANKS_MESSAGE"] = "感谢 Twitch 上所有的观众、测试者和支持者！你们的反馈让 QuestMaster 变得更好。"

-- ============================================================================
-- Info Bar Tooltip
-- ============================================================================
L["SESSION_STATISTICS"] = "本次统计"
L["CURRENT_XP"] = "当前经验:"
L["XP_REMAINING"] = "剩余经验:"
L["XP_PER_HOUR_LABEL"] = "每小时经验:"
L["TIME_TO_LEVEL"] = "升级时间:"
L["SESSION_TIME"] = "本次时间:"
L["RESTED_AMOUNT"] = "休息量:"
L["RESTED_BUBBLES"] = "休息气泡:"
L["BONUS_XP"] = "奖励经验:"
L["BONUS_UNTIL_DEPLETED"] = "+50% 直到耗尽"
L["CURRENT_LEVEL_LABEL"] = "当前等级:"
L["AVERAGE_PER_LEVEL"] = "每级平均:"
L["PROGRESS"] = "进度:"
L["STATUS"] = "状态"
L["BAG_SPACE"] = "背包空间:"
L["FREE"] = "空闲"
L["DURABILITY"] = "耐久度:"
L["LOWEST"] = "最低"
L["TRACKED_REPUTATIONS"] = "追踪声望"
L["CLICK_TO_RESET_XP"] = "点击重置经验追踪器"

-- ============================================================================
-- Quest Display
-- ============================================================================
L["COMPLETE"] = "完成"
L["DONE"] = "已完成"
L["TURN_IN"] = "交任务"
L["TURN_IN_SUFFIX"] = "（交任务）"
L["TIME_ON_QUEST"] = "任务用时:"
L["NOTE"] = "笔记:"
L["CLICK_SET_WAYPOINT"] = "左键点击: 设置路径点"
L["CLICK_OPEN_QUESTLOG"] = "Shift+左键: 打开任务日志"
L["CLICK_MORE_OPTIONS"] = "右键点击: 更多选项"
L["DISTANCE_TO_OBJECTIVE"] = "到最近目标的距离"

-- Context Menu
L["SET_WAYPOINT"] = "设置路径点"
L["SHOW_ON_MAP"] = "在地图上显示"
L["EXPAND_QUEST"] = "展开任务"
L["COLLAPSE_QUEST"] = "折叠任务"
L["EDIT_NOTE"] = "编辑笔记"
L["ADD_NOTE"] = "添加笔记"
L["SHARE_QUEST"] = "分享任务"
L["ABANDON_QUEST"] = "放弃任务"

-- ============================================================================
-- Chat Messages
-- ============================================================================
L["MSG_PREFIX"] = "|cFF00FF00QuestMaster:|r"
L["MSG_ADDON_LOADED"] = "|cFFFFD700QuestMaster|r 已加载！由 |cFF00FF00JugoBetrugoTV|r 又名 |cFFFF8800Novi_Live|r 制作"
L["MSG_TWITCH"] = "|cFF9146FF  Twitch.tv/Novi_Live|r - 来一起玩吧！"
L["MSG_BUGS"] = "|cFF888888  有bug？在 CurseForge 或|r |cFF5865F2Discord.gg/rv2BsbE|r 报告"

L["MSG_QUEST_ACCEPTED"] = "任务已接受:"
L["MSG_ACCEPTED_QUEST"] = "已接受任务:"
L["MSG_QUEST_COMPLETED"] = "任务已完成:"
L["MSG_QUEST_READY"] = "任务准备交付:"
L["MSG_OBJECTIVE_COMPLETE"] = "目标完成:"
L["MSG_ABANDONED"] = "已放弃:"
L["MSG_SHARED"] = "已分享:"
L["MSG_CANNOT_SHARE"] = "此任务无法分享"
L["MSG_QUEST_NOT_FOUND"] = "在任务日志中找不到任务"

L["MSG_LEVEL_UP"] = "|cFFFFD700升级了！|r 你达到了 |cFF00FF00%d|r 级！"
L["MSG_TIME_FROM_LEVEL"] = "从 %d 级到 %d 级用时:"
L["MSG_REACHED_LEVEL"] = "达到了 %d 级！"
L["MSG_REACHED_LEVEL_TIME"] = "达到了 %d 级！（从 %d 级用时 %s）"

L["MSG_WAYPOINT_SET"] = "路径点设置到 %.1f, %.1f - %s"
L["MSG_WAYPOINT_CORPSE"] = "路径点设置到你的尸体位置"
L["MSG_WAYPOINT_RESTORED"] = "已恢复之前的路径点"
L["MSG_NAVIGATING_TO"] = "正在导航到:"
L["MSG_AUTO_NAV_TURNIN"] = "自动导航到交任务NPC"
L["MSG_AUTO_NAV_TO"] = "自动导航到:"
L["MSG_NO_QUESTS_NAV"] = "没有可导航的任务"
L["MSG_TURNIN"] = "交任务:"
L["MSG_NO_COMPLETED"] = "没有已完成的任务可交"

L["MSG_XP_RESET"] = "每小时经验追踪器已重置"
L["MSG_HISTORY_CLEARED"] = "任务历史已清除"
L["MSG_SESSION_RESET"] = "本次统计已重置"
L["MSG_NOTE_SAVED"] = "笔记已保存:"
L["MSG_NOTE_DELETED"] = "笔记已删除:"

L["MSG_COORDS_INVALID"] = "坐标必须在 0 到 100 之间"
L["MSG_NO_MAP"] = "无法确定当前地图"
L["MSG_INVALID_COORDS"] = "无效坐标。使用: /qm way 45.2 67.8"
L["MSG_DB_FAIL"] = "数据库初始化失败:"
L["MSG_DB_WARNING"] = "警告: 数据库配置文件不可用"
L["MSG_INIT_FAIL"] = "初始化 %s 失败:"
L["MSG_SETTINGS_NOT_READY"] = "设置未就绪"
L["MSG_UNKNOWN_CMD"] = "未知命令。输入 /qm help 查看命令列表。"

-- Help
L["HELP_USAGE"] = "用法:"
L["HELP_SEARCH"] = "用法: /qm search <任务名称或ID>"
L["HELP_WAY"] = "用法: /qm way <x> <y> [描述]"
L["HELP_WAY_EXAMPLE"] = "  例如: /qm way 45.2 67.8 集合点"
L["HELP_CREDITS"] = "/qm credits - 显示制作人员"
L["HELP_STATS"] = "/qm stats - 显示任务统计"
L["HELP_SEARCH_CMD"] = "/qm search <名称> - 搜索任务数据库"
L["HELP_WAY_CMD"] = "/qm way <x> <y> [描述] - 设置手动路径点"

-- Statistics Print
L["STATS_HEADER"] = "========== 任务统计 =========="
L["STATS_TOTAL_COMPLETED"] = "总完成: %d 个任务"
L["STATS_TOTAL_XP"] = "任务总经验:"
L["STATS_AVG_TIME"] = "平均任务时间:"
L["STATS_QUESTS_HOUR"] = "每小时任务: %.1f"
L["STATS_FASTEST"] = "最快任务: %s (%s)"
L["STATS_SLOWEST"] = "最慢任务: %s (%s)"
L["STATS_SESSION_HEADER"] = "--- 本次统计 ---"
L["STATS_SESSION_COMPLETED"] = "本次完成: %d 个任务"
L["STATS_SESSION_XP"] = "本次经验:"
L["STATS_TOP_ZONES"] = "--- 热门区域 ---"

-- Search Results
L["SEARCH_NO_RESULTS"] = "未找到 '%s' 的任务"
L["SEARCH_HEADER"] = "=== 任务搜索: '%s' (%d 个结果) ==="
L["SEARCH_COMPLETED"] = "[已完成]"
L["SEARCH_IN_PROGRESS"] = "[进行中]"

-- Waypoint
L["WAYPOINT_FORMAT"] = "路径点 (%.1f, %.1f)"
L["YOUR_CORPSE"] = "你的尸体"

-- Tooltip
L["QUEST_ITEM"] = "任务物品"
L["DROP_RATE_NOTE"] = "（估计掉落率有所不同）"
L["QUEST_NOTE"] = "任务笔记"

-- Time Format
L["TIME_HOURS_MINS"] = "%d小时 %d分钟"
L["TIME_HOURS"] = "%d小时"
L["TIME_MINS"] = "%d分钟"
L["TIME_ZERO"] = "0分钟"
L["AVG_FORMAT"] = "（平均: %s）"
L["LVL_PREFIX"] = "等级:"
L["XP_HOUR_PREFIX"] = "经验/小时:"
L["RESTED_PREFIX"] = "休息:"

-- Responsive Layout
L["QM_SHORT"] = "QM"
L["QUESTS_SHORT"] = "任务"

-- ============================================================================
-- Quest Type Tags (Dungeon/Group/Raid)
-- ============================================================================
L["DUNGEON_TAG"] = "副"
L["RAID_TAG"] = "团"
L["GROUP_TAG"] = "组"
L["DUNGEON_QUESTS"] = "副本任务"
L["RAID_QUESTS"] = "团队任务"

-- Best Time
L["BEST"] = "最佳"
L["MSG_NEW_BEST_TIME"] = "%s 新纪录: %s (之前: %s)"

-- ============================================================================
-- Party Quest Sync
-- ============================================================================
L["PARTY_SYNC"] = "队伍任务同步"
L["ENABLE_PARTY_SYNC"] = "启用队伍同步"
L["ENABLE_PARTY_SYNC_DESC"] = "与队伍共享任务进度"
L["PARTY_SHOW_PROGRESS"] = "显示队伍进度"
L["PARTY_SHOW_PROGRESS_DESC"] = "在追踪器中显示"
L["PARTY_SHOW_INDICATOR"] = "队伍指示器"
L["PARTY_SHOW_INDICATOR_DESC"] = "共享任务图标"
L["PARTY_SYNC_ICON"] = "队"

-- ============================================================================
-- Statistics Dashboard
-- ============================================================================
L["DASHBOARD_TITLE"] = "仪表盘"
L["DASH_TITLE"] = "统计仪表盘"
L["OPEN_DASHBOARD"] = "打开仪表盘"
L["DASH_OVERVIEW"] = "概览"
L["DASH_ZONES"] = "区域进度"
L["DASH_HISTORY"] = "任务历史"
L["DASH_DETAILED_STATS"] = "详细统计"
L["DASH_FASTEST_QUEST"] = "最快任务"
L["DASH_SLOWEST_QUEST"] = "最慢任务"
L["DASH_TOP_ZONES"] = "热门任务区域"
L["DASH_OVERALL_PROGRESS"] = "总体区域进度"
L["DASH_NO_ZONE_DATA"] = "暂无区域进度数据"
L["DASH_NO_HISTORY"] = "暂无任务历史"
L["DASH_SHOWING_ENTRIES"] = "显示 %d / %d 条记录"
L["DASH_MORE_ENTRIES"] = "... 还有 %d 条记录"
L["DASH_SORT_TIME"] = "时间"
L["DASH_SORT_NAME"] = "名称"
L["DASH_SORT_LEVEL"] = "等级"
L["DASH_SORT_DURATION"] = "耗时"
L["DASH_COL_QUEST"] = "任务"
L["DASH_COL_LEVEL"] = "等级"
L["DASH_COL_XP"] = "经验"
L["DASH_COL_TIME"] = "耗时"
L["DASH_COL_DATE"] = "日期"

-- ============================================================================
-- Zone Filter
-- ============================================================================
L["ZONE_FILTER"] = "仅当前区域"
L["ZONE_FILTER_DESC"] = "仅显示当前区域的任务"

-- ============================================================================
-- Enhanced Minimap Tooltip
-- ============================================================================
L["MINIMAP_ACTIVE_QUESTS"] = "进行中的任务:"
L["MINIMAP_COMPLETED"] = "已完成:"
L["MINIMAP_IN_ZONE"] = "本区域:"
L["MINIMAP_CURRENT_WAYPOINT"] = "当前路径点:"
L["MINIMAP_NO_WAYPOINT"] = "无活动路径点"
L["MINIMAP_LEFT_CLICK"] = "左键点击: 打开设置"
L["MINIMAP_SHIFT_CLICK"] = "Shift+左键: 切换追踪器"
L["MINIMAP_RIGHT_CLICK"] = "右键点击: 切换箭头"
L["MINIMAP_MIDDLE_CLICK"] = "中键点击: 清除路径点"
