-- QuestMaster Traditional Chinese Localization
local addonName, QM = ...
if GetLocale() ~= "zhTW" then return end

local L = QM.L

-- ============================================================================
-- General
-- ============================================================================
L["ADDON_LOADED"] = "QuestMaster 已載入。輸入 /qm 查看選項。"
L["VERSION"] = "版本"
L["ENABLED"] = "已啟用"
L["DISABLED"] = "已停用"
L["YES"] = "是"
L["NO"] = "否"
L["DEFAULT"] = "預設"
L["RESET"] = "重置"
L["CLOSE"] = "關閉"
L["SAVE"] = "儲存"
L["CANCEL"] = "取消"
L["DELETE"] = "刪除"
L["UNKNOWN"] = "未知"
L["NONE"] = "無"
L["GO"] = "前往"
L["SEARCH"] = "搜尋"
L["REFRESHED"] = "已重新整理"

-- ============================================================================
-- Tabs
-- ============================================================================
L["TAB_GENERAL"] = "一般"
L["TAB_GENERAL_DESC"] = "核心設定"
L["TAB_TRACKER"] = "追蹤器"
L["TAB_TRACKER_DESC"] = "任務列表"
L["TAB_ARROW"] = "箭頭"
L["TAB_ARROW_DESC"] = "導航"
L["TAB_MAP"] = "地圖"
L["TAB_MAP_DESC"] = "標記和圖釘"
L["TAB_STATISTICS"] = "統計"
L["TAB_STATISTICS_DESC"] = "經驗追蹤"
L["TAB_DASHBOARD"] = "儀表板"
L["TAB_DASHBOARD_DESC"] = "統計與歷史"
L["TAB_AUTOMATION"] = "自動化"
L["TAB_AUTOMATION_DESC"] = "自動功能"
L["TAB_ADVANCED"] = "進階"
L["TAB_ADVANCED_DESC"] = "專家"
L["TAB_CREDITS"] = "製作人員"
L["TAB_CREDITS_DESC"] = "關於和連結"

-- ============================================================================
-- Settings Header
-- ============================================================================
L["SETTINGS"] = "設定"
L["SETTINGS_TITLE"] = "QuestMaster 設定"

-- ============================================================================
-- General Settings
-- ============================================================================
L["MAIN_SETTINGS"] = "主要設定"
L["ENABLE_ADDON"] = "啟用 QuestMaster"
L["ENABLE_ADDON_DESC"] = "所有功能的主開關"
L["LOCK_FRAMES"] = "鎖定視窗位置"
L["LOCK_FRAMES_DESC"] = "防止拖動"
L["SHOW_MINIMAP_BUTTON"] = "顯示小地圖按鈕"
L["SHOW_MINIMAP_BUTTON_DESC"] = "在小地圖上顯示按鈕"

-- ============================================================================
-- Sounds
-- ============================================================================
L["SOUNDS"] = "音效"
L["QUEST_PROGRESS_SOUND"] = "任務進度音效"
L["QUEST_PROGRESS_SOUND_DESC"] = "進度時播放音效"
L["QUEST_COMPLETE_SOUND"] = "任務完成音效"
L["QUEST_COMPLETE_SOUND_DESC"] = "完成時播放音效"

-- ============================================================================
-- Announcements
-- ============================================================================
L["QUEST_ANNOUNCEMENTS"] = "任務通知"
L["ANNOUNCE_ACCEPT"] = "通知接受任務"
L["ANNOUNCE_ACCEPT_DESC"] = "向隊伍/公會"
L["ACCEPT_CHANNEL"] = "接受頻道"
L["ANNOUNCE_DONE"] = "通知任務完成"
L["ANNOUNCE_DONE_DESC"] = "向隊伍/公會"
L["COMPLETE_CHANNEL"] = "完成頻道"
L["CHANNEL_PARTY"] = "隊伍"
L["CHANNEL_GUILD"] = "公會"
L["CHANNEL_EMOTE"] = "表情 (/me)"
L["CHANNEL_DISABLED"] = "已停用"

-- Level Up
L["LEVEL_UP_ANNOUNCEMENTS"] = "升級通知"
L["ANNOUNCE_LEVEL_UP"] = "通知升級"
L["ANNOUNCE_LEVEL_UP_DESC"] = "向表情/隊伍"
L["LEVEL_UP_CHANNEL"] = "升級頻道"

-- ============================================================================
-- Quick Actions
-- ============================================================================
L["QUICK_ACTIONS"] = "快捷操作"
L["RESET_POSITIONS"] = "重置位置"
L["REFRESH_DATA"] = "重新整理資料"

-- ============================================================================
-- Quest Tracker
-- ============================================================================
L["QUEST_TRACKER"] = "任務追蹤器"
L["ENABLE_TRACKER"] = "啟用追蹤器"
L["ENABLE_TRACKER_DESC"] = "顯示任務面板"
L["FONT_SIZE"] = "字型大小"
L["BACKGROUND_OPACITY"] = "背景透明度"
L["TRACKER_TITLE"] = "QuestMaster"
L["ACTIVE_QUESTS"] = "進行中的任務"
L["READY_FOR_TURNIN"] = "準備交付"
L["NO_ACTIVE_QUESTS"] = "無進行中的任務"

-- Display Options
L["DISPLAY_OPTIONS"] = "顯示選項"
L["SHOW_QUEST_LEVEL"] = "顯示任務等級"
L["SHOW_QUEST_LEVEL_DESC"] = "括號中的等級"
L["SHOW_DISTANCE"] = "顯示距離"
L["SHOW_DISTANCE_DESC"] = "到目標的距離"
L["COLOR_BY_DIFFICULTY"] = "按難度著色"
L["COLOR_BY_DIFFICULTY_DESC"] = "基於等級的顏色"
L["SHOW_PROGRESS_BARS"] = "顯示進度條"
L["SHOW_PROGRESS_BARS_DESC"] = "目標下方的進度條"
L["SHOW_COMPLETED"] = "顯示已完成任務"
L["SHOW_COMPLETED_DESC"] = "顯示已完成的任務"
L["MAX_QUESTS"] = "最大顯示任務數"

-- Default Tracker
L["HIDE_BLIZZARD_TRACKER"] = "隱藏預設任務追蹤器"
L["HIDE_BLIZZARD_TRACKER_DESC"] = "隱藏暴雪內建的任務追蹤器"
L["HIDE_BLIZZARD_TRACKER_COMBAT"] = "戰鬥中無法切換預設追蹤器。"
L["HIDE_BLIZZARD_TRACKER_RELOAD"] = "重新啟用預設追蹤器需要重新載入介面。是否立即重新載入？"

-- Sorting
L["SORTING"] = "排序"
L["SORT_BY"] = "排序方式"
L["SORT_QUESTS_BY"] = "任務排序方式"
L["SORT_DISTANCE"] = "距離"
L["SORT_LEVEL"] = "等級"
L["CURRENT"] = "目前"

-- Tracker Buttons
L["SORT"] = "排序"
L["NAVIGATE_TO_NEAREST"] = "導航到最近"
L["CLICK_TO_SET_WAYPOINT"] = "點擊設定路徑點"
L["NAVIGATE_TO_TURNIN"] = "導航到交任務NPC"
L["NEAREST_COMPLETED_QUEST"] = "最近的已完成任務"

-- ============================================================================
-- Arrow
-- ============================================================================
L["NAVIGATION_ARROW"] = "導航箭頭"
L["ENABLE_ARROW"] = "啟用箭頭"
L["ENABLE_ARROW_DESC"] = "顯示導航箭頭"
L["ARROW_SIZE"] = "箭頭大小"
L["ARROW_OPACITY"] = "箭頭透明度"
L["ARRIVAL_DISTANCE"] = "到達距離"

-- Arrow Display
L["DISPLAY"] = "顯示"
L["SHOW_OBJECTIVE"] = "顯示目標"
L["SHOW_OBJECTIVE_DESC"] = "目標文字"
L["SHOW_ETA"] = "顯示預計到達時間"
L["SHOW_ETA_DESC"] = "時間估算"

-- Arrow Status
L["ARRIVED"] = "已到達！"
L["NO_ACTIVE_OBJECTIVE"] = "無活動目標"
L["QUEST_OBJECTIVE"] = "任務目標"
L["YARDS"] = "碼"
L["KILOMETERS"] = "公里"

-- Arrow Tooltip
L["ARROW_NAVIGATION"] = "導航"
L["OBJECTIVE"] = "目標"
L["LEFT_CLICK_DRAG"] = "左鍵拖動移動"
L["RIGHT_CLICK_OPTIONS"] = "右鍵開啟選項"

-- Arrow Context Menu
L["HIDE_ARROW"] = "隱藏箭頭"
L["CLEAR_WAYPOINT"] = "清除路徑點"
L["FIND_NEAREST_AUTO"] = "尋找最近（自動）"
L["OPEN_SETTINGS"] = "開啟設定"

-- ETA
L["ETA"] = "預計到達"
L["ETA_SECONDS"] = "預計: %d秒"
L["ETA_MINUTES"] = "預計: %d分%d秒"
L["ETA_HOURS"] = "預計: %d小時%d分"
L["MOVE_TO_CALCULATE"] = "（移動以計算預計時間）"

-- ============================================================================
-- Map
-- ============================================================================
L["WORLD_MAP"] = "世界地圖"
L["ENABLE_MAP_PINS"] = "啟用地圖標記"
L["ENABLE_MAP_PINS_DESC"] = "顯示任務標記"
L["PIN_SIZE"] = "標記大小"
L["PIN_OPACITY"] = "標記透明度"

-- Pin Types
L["PIN_TYPES"] = "標記類型"
L["OBJECTIVE_PINS"] = "目標標記"
L["OBJECTIVE_PINS_DESC"] = "任務目標"
L["QUEST_AREAS"] = "任務區域"
L["QUEST_AREAS_DESC"] = "高亮區域"
L["TURNIN_PINS"] = "交任務標記 (?)"
L["TURNIN_PINS_DESC"] = "黃色問號標記"
L["AVAILABLE_QUESTS"] = "可接任務 (!)"
L["AVAILABLE_QUESTS_DESC"] = "黃色驚嘆號標記"
L["PATROL_PATHS"] = "NPC巡邏路線"
L["PATROL_PATHS_DESC"] = "顯示巡邏路線"

-- ============================================================================
-- Statistics Tab
-- ============================================================================
L["QUEST_TIMER"] = "任務計時器"
L["ENABLE_TIMER"] = "啟用計時器"
L["ENABLE_TIMER_DESC"] = "追蹤任務時間"
L["SHOW_IN_TRACKER"] = "在追蹤器中顯示"
L["SHOW_IN_TRACKER_DESC"] = "在追蹤器中顯示"

L["XP_PER_HOUR"] = "每小時經驗"
L["ENABLE_XP_TRACKER"] = "啟用經驗追蹤器"
L["ENABLE_XP_TRACKER_DESC"] = "計算經驗速率"
L["RESET_XP"] = "重置經驗"

L["RESTED_XP"] = "休息經驗"
L["ENABLE_RESTED_DISPLAY"] = "啟用休息顯示"
L["ENABLE_RESTED_DISPLAY_DESC"] = "顯示休息經驗"
L["SHOW_BONUS_INDICATOR"] = "顯示+50%加成"
L["SHOW_BONUS_INDICATOR_DESC"] = "顯示加成指示器"

L["LEVEL_TIME"] = "等級時間"
L["ENABLE_LEVEL_TIMER"] = "啟用等級計時器"
L["ENABLE_LEVEL_TIMER_DESC"] = "追蹤每級時間"
L["SHOW_AVERAGE"] = "顯示平均"
L["SHOW_AVERAGE_DESC"] = "顯示平均時間"

L["REMINDERS"] = "提醒"
L["ENABLE_REMINDERS"] = "啟用提醒"
L["ENABLE_REMINDERS_DESC"] = "背包和修理警告"
L["BAG_SPACE_WARNING"] = "背包空間警告"
L["BAG_SPACE_WARNING_DESC"] = "背包滿時警告"
L["BAG_THRESHOLD"] = "背包閾值"
L["REPAIR_WARNING"] = "修理警告"
L["REPAIR_WARNING_DESC"] = "耐久度低時警告"

L["ZONE_PROGRESS"] = "區域進度"
L["ENABLE_ZONE_PROGRESS"] = "啟用區域進度"
L["ENABLE_ZONE_PROGRESS_DESC"] = "按區域追蹤"

L["REPUTATION"] = "聲望"
L["ENABLE_REP_TRACKER"] = "啟用聲望追蹤器"
L["ENABLE_REP_TRACKER_DESC"] = "追蹤監視陣營"

-- Quest Statistics
L["QUEST_STATISTICS"] = "任務統計"
L["TOTAL_STATISTICS"] = "總計統計"
L["QUESTS_COMPLETED"] = "已完成任務"
L["TOTAL_XP_GAINED"] = "總獲得經驗"
L["AVG_QUEST_TIME"] = "平均任務時間"
L["QUESTS_PER_HOUR"] = "每小時任務"
L["CURRENT_LEVEL"] = "目前等級"
L["TIME_ON_LEVEL"] = "目前等級時間"
L["SESSION_QUESTS"] = "本次任務"
L["SESSION_XP"] = "本次經驗"
L["REFRESH_STATS"] = "重新整理統計"
L["RESET_SESSION"] = "重置本次"

-- Quest Search
L["QUEST_SEARCH"] = "任務搜尋"
L["SEARCH_PLACEHOLDER"] = "輸入任務名稱或ID..."
L["CLICK_RESULT_HINT"] = "點擊結果設定路徑點到任務起始位置"
L["NO_QUESTS_FOUND"] = "未找到符合的任務:"
L["WAYPOINT_SET_TO_QUEST"] = "路徑點已設定到任務:"
L["NO_LOCATION_DATA"] = "無位置資料:"
L["QUEST_LABEL"] = "任務:"
L["OBJECTIVES_LABEL"] = "目標:"

-- Manual Waypoint
L["MANUAL_WAYPOINT"] = "手動路徑點"
L["WAYPOINT"] = "路徑點"
L["MANUAL"] = "[手動]"
L["CURRENT_WAYPOINT"] = "目前:"
L["NO_WAYPOINT_SET"] = "未設定路徑點"
L["X_COORD"] = "X:"
L["Y_COORD"] = "Y:"
L["SET"] = "設定"
L["INVALID_COORDINATES"] = "無效座標 (0-100)"
L["COORD_HINT"] = "輸入座標如 45.5 和 67.2（值 0-100）"

-- ============================================================================
-- Automation Tab
-- ============================================================================
L["QUEST_AUTOMATION"] = "任務自動化"
L["AUTO_ACCEPT"] = "自動接受任務"
L["AUTO_ACCEPT_DESC"] = "按住Shift跳過"
L["AUTO_COMPLETE"] = "自動完成任務"
L["AUTO_COMPLETE_DESC"] = "按住Shift跳過"
L["SKIP_REWARD_CHOICE"] = "跳過獎勵選擇"
L["SKIP_REWARD_CHOICE_DESC"] = "等待選擇"
L["AUTO_SHARE"] = "自動分享任務"
L["AUTO_SHARE_DESC"] = "與隊伍分享"

L["WAYPOINT_AUTO"] = "路徑點自動"
L["AUTO_SET_WAYPOINT"] = "自動設定路徑點"
L["AUTO_SET_WAYPOINT_DESC"] = "最近的任務"
L["AUTO_ADVANCE"] = "自動前進"
L["AUTO_ADVANCE_DESC"] = "完成後下一個"
L["PRIORITIZE_TURNINS"] = "優先交任務"
L["PRIORITIZE_TURNINS_DESC"] = "先交任務"

L["QUEST_FILTERS"] = "任務過濾"
L["SHOW_DUNGEON"] = "顯示副本任務"
L["SHOW_DUNGEON_DESC"] = "包含副本任務"
L["SHOW_RAID"] = "顯示團隊任務"
L["SHOW_RAID_DESC"] = "包含團隊任務"
L["SHOW_GROUP"] = "顯示組隊任務"
L["SHOW_GROUP_DESC"] = "包含組隊任務"
L["SHOW_PVP"] = "顯示PvP任務"
L["SHOW_PVP_DESC"] = "包含PvP任務"
L["SHOW_LOW_LEVEL"] = "顯示低等級任務"
L["SHOW_LOW_LEVEL_DESC"] = "包含灰色任務"

-- ============================================================================
-- Advanced Tab
-- ============================================================================
L["THEME"] = "主題"
L["COLOR_THEME"] = "顏色主題"
L["THEME_GOLD"] = "金色（預設）"
L["THEME_BLUE"] = "藍色"
L["THEME_GREEN"] = "綠色"
L["THEME_RED"] = "紅色"
L["THEME_PURPLE"] = "紫色"
L["THEME_ORANGE"] = "橙色"
L["THEME_TEAL"] = "青色"
L["THEME_PINK"] = "粉色"
L["THEME_SILVER"] = "銀色"
L["THEME_BRONZE"] = "青銅色"

L["PERFORMANCE"] = "效能"
L["UPDATE_INTERVAL"] = "更新間隔"
L["UPDATE_THROTTLE"] = "更新節流"
L["REDUCE_MAP_UPDATES"] = "減少地圖更新"
L["REDUCE_MAP_UPDATES_DESC"] = "延遲更新"

L["QUEST_NOTES"] = "任務筆記"
L["MAX_NOTE_LENGTH"] = "最大筆記長度"

L["DEBUG_TOOLS"] = "除錯和工具"
L["DEBUG_MODE"] = "除錯模式"
L["DEBUG_MODE_DESC"] = "聊天除錯資訊"
L["RESET_SETTINGS"] = "重置設定"
L["RELOAD_UI"] = "重新載入介面"
L["RESET_CONFIRM"] = "重置所有 QuestMaster 設定？"

-- ============================================================================
-- Credits Tab
-- ============================================================================
L["CREDITS_VERSION"] = "版本 1.3"
L["CREDITS_EDITION"] = "全合一版"
L["CREDITS_DESCRIPTION"] = "具有導航箭頭、地圖標記、統計和自動化功能的進階任務追蹤插件。"
L["DEVELOPER"] = "開發者"
L["ALSO_KNOWN_AS"] = "又名"
L["DEVELOPER_BIO"] = "WoW 插件開發者和內容創作者。在 Twitch.tv/Novi_Live 直播"
L["CONNECT"] = "聯繫"
L["TWITCH"] = "Twitch"
L["DISCORD"] = "Discord"
L["CURSEFORGE"] = "CurseForge"
L["DOWNLOADS_BUGS"] = "下載和錯誤報告"
L["CHANGELOG"] = "更新日誌"
L["SPECIAL_THANKS"] = "特別感謝"
L["THANKS_MESSAGE"] = "感謝 Twitch 上所有的觀眾、測試者和支持者！你們的回饋讓 QuestMaster 變得更好。"

-- ============================================================================
-- Info Bar Tooltip
-- ============================================================================
L["SESSION_STATISTICS"] = "本次統計"
L["CURRENT_XP"] = "目前經驗:"
L["XP_REMAINING"] = "剩餘經驗:"
L["XP_PER_HOUR_LABEL"] = "每小時經驗:"
L["TIME_TO_LEVEL"] = "升級時間:"
L["SESSION_TIME"] = "本次時間:"
L["RESTED_AMOUNT"] = "休息量:"
L["RESTED_BUBBLES"] = "休息氣泡:"
L["BONUS_XP"] = "獎勵經驗:"
L["BONUS_UNTIL_DEPLETED"] = "+50% 直到耗盡"
L["CURRENT_LEVEL_LABEL"] = "目前等級:"
L["AVERAGE_PER_LEVEL"] = "每級平均:"
L["PROGRESS"] = "進度:"
L["STATUS"] = "狀態"
L["BAG_SPACE"] = "背包空間:"
L["FREE"] = "空閒"
L["DURABILITY"] = "耐久度:"
L["LOWEST"] = "最低"
L["TRACKED_REPUTATIONS"] = "追蹤聲望"
L["CLICK_TO_RESET_XP"] = "點擊重置經驗追蹤器"

-- ============================================================================
-- Quest Display
-- ============================================================================
L["COMPLETE"] = "完成"
L["DONE"] = "已完成"
L["TURN_IN"] = "交任務"
L["TURN_IN_SUFFIX"] = "（交任務）"
L["TIME_ON_QUEST"] = "任務用時:"
L["NOTE"] = "筆記:"
L["CLICK_SET_WAYPOINT"] = "左鍵點擊: 設定路徑點"
L["CLICK_OPEN_QUESTLOG"] = "Shift+左鍵: 開啟任務日誌"
L["CLICK_MORE_OPTIONS"] = "右鍵點擊: 更多選項"
L["DISTANCE_TO_OBJECTIVE"] = "到最近目標的距離"

-- Context Menu
L["SET_WAYPOINT"] = "設定路徑點"
L["SHOW_ON_MAP"] = "在地圖上顯示"
L["EXPAND_QUEST"] = "展開任務"
L["COLLAPSE_QUEST"] = "摺疊任務"
L["EDIT_NOTE"] = "編輯筆記"
L["ADD_NOTE"] = "新增筆記"
L["SHARE_QUEST"] = "分享任務"
L["ABANDON_QUEST"] = "放棄任務"

-- ============================================================================
-- Chat Messages
-- ============================================================================
L["MSG_PREFIX"] = "|cFF00FF00QuestMaster:|r"
L["MSG_ADDON_LOADED"] = "|cFFFFD700QuestMaster|r 已載入！由 |cFF00FF00JugoBetrugoTV|r 又名 |cFFFF8800Novi_Live|r 製作"
L["MSG_TWITCH"] = "|cFF9146FF  Twitch.tv/Novi_Live|r - 來一起玩吧！"
L["MSG_BUGS"] = "|cFF888888  有bug？在 CurseForge 或|r |cFF5865F2Discord.gg/rv2BsbE|r 回報"

L["MSG_QUEST_ACCEPTED"] = "任務已接受:"
L["MSG_ACCEPTED_QUEST"] = "已接受任務:"
L["MSG_QUEST_COMPLETED"] = "任務已完成:"
L["MSG_QUEST_READY"] = "任務準備交付:"
L["MSG_OBJECTIVE_COMPLETE"] = "目標完成:"
L["MSG_ABANDONED"] = "已放棄:"
L["MSG_SHARED"] = "已分享:"
L["MSG_CANNOT_SHARE"] = "此任務無法分享"
L["MSG_QUEST_NOT_FOUND"] = "在任務日誌中找不到任務"

L["MSG_LEVEL_UP"] = "|cFFFFD700升級了！|r 你達到了 |cFF00FF00%d|r 級！"
L["MSG_TIME_FROM_LEVEL"] = "從 %d 級到 %d 級用時:"
L["MSG_REACHED_LEVEL"] = "達到了 %d 級！"
L["MSG_REACHED_LEVEL_TIME"] = "達到了 %d 級！（從 %d 級用時 %s）"

L["MSG_WAYPOINT_SET"] = "路徑點設定到 %.1f, %.1f - %s"
L["MSG_WAYPOINT_CORPSE"] = "路徑點設定到你的屍體位置"
L["MSG_WAYPOINT_RESTORED"] = "已恢復之前的路徑點"
L["MSG_NAVIGATING_TO"] = "正在導航到:"
L["MSG_AUTO_NAV_TURNIN"] = "自動導航到交任務NPC"
L["MSG_AUTO_NAV_TO"] = "自動導航到:"
L["MSG_NO_QUESTS_NAV"] = "沒有可導航的任務"
L["MSG_TURNIN"] = "交任務:"
L["MSG_NO_COMPLETED"] = "沒有已完成的任務可交"

L["MSG_XP_RESET"] = "每小時經驗追蹤器已重置"
L["MSG_HISTORY_CLEARED"] = "任務歷史已清除"
L["MSG_SESSION_RESET"] = "本次統計已重置"
L["MSG_NOTE_SAVED"] = "筆記已儲存:"
L["MSG_NOTE_DELETED"] = "筆記已刪除:"

L["MSG_COORDS_INVALID"] = "座標必須在 0 到 100 之間"
L["MSG_NO_MAP"] = "無法確定目前地圖"
L["MSG_INVALID_COORDS"] = "無效座標。使用: /qm way 45.2 67.8"
L["MSG_DB_FAIL"] = "資料庫初始化失敗:"
L["MSG_DB_WARNING"] = "警告: 資料庫設定檔不可用"
L["MSG_INIT_FAIL"] = "初始化 %s 失敗:"
L["MSG_SETTINGS_NOT_READY"] = "設定未就緒"
L["MSG_UNKNOWN_CMD"] = "未知指令。輸入 /qm help 查看指令列表。"

-- Help
L["HELP_USAGE"] = "用法:"
L["HELP_SEARCH"] = "用法: /qm search <任務名稱或ID>"
L["HELP_WAY"] = "用法: /qm way <x> <y> [描述]"
L["HELP_WAY_EXAMPLE"] = "  例如: /qm way 45.2 67.8 集合點"
L["HELP_CREDITS"] = "/qm credits - 顯示製作人員"
L["HELP_STATS"] = "/qm stats - 顯示任務統計"
L["HELP_SEARCH_CMD"] = "/qm search <名稱> - 搜尋任務資料庫"
L["HELP_WAY_CMD"] = "/qm way <x> <y> [描述] - 設定手動路徑點"

-- Statistics Print
L["STATS_HEADER"] = "========== 任務統計 =========="
L["STATS_TOTAL_COMPLETED"] = "總完成: %d 個任務"
L["STATS_TOTAL_XP"] = "任務總經驗:"
L["STATS_AVG_TIME"] = "平均任務時間:"
L["STATS_QUESTS_HOUR"] = "每小時任務: %.1f"
L["STATS_FASTEST"] = "最快任務: %s (%s)"
L["STATS_SLOWEST"] = "最慢任務: %s (%s)"
L["STATS_SESSION_HEADER"] = "--- 本次統計 ---"
L["STATS_SESSION_COMPLETED"] = "本次完成: %d 個任務"
L["STATS_SESSION_XP"] = "本次經驗:"
L["STATS_TOP_ZONES"] = "--- 熱門區域 ---"

-- Search Results
L["SEARCH_NO_RESULTS"] = "未找到 '%s' 的任務"
L["SEARCH_HEADER"] = "=== 任務搜尋: '%s' (%d 個結果) ==="
L["SEARCH_COMPLETED"] = "[已完成]"
L["SEARCH_IN_PROGRESS"] = "[進行中]"

-- Waypoint
L["WAYPOINT_FORMAT"] = "路徑點 (%.1f, %.1f)"
L["YOUR_CORPSE"] = "你的屍體"

-- Tooltip
L["QUEST_ITEM"] = "任務物品"
L["DROP_RATE_NOTE"] = "（估計掉落率有所不同）"
L["QUEST_NOTE"] = "任務筆記"

-- Time Format
L["TIME_HOURS_MINS"] = "%d小時 %d分鐘"
L["TIME_HOURS"] = "%d小時"
L["TIME_MINS"] = "%d分鐘"
L["TIME_ZERO"] = "0分鐘"
L["AVG_FORMAT"] = "（平均: %s）"
L["LVL_PREFIX"] = "等級:"
L["XP_HOUR_PREFIX"] = "經驗/小時:"
L["RESTED_PREFIX"] = "休息:"

-- Responsive Layout
L["QM_SHORT"] = "QM"
L["QUESTS_SHORT"] = "任務"

-- ============================================================================
-- Quest Type Tags (Dungeon/Group/Raid)
-- ============================================================================
L["DUNGEON_TAG"] = "副"
L["RAID_TAG"] = "團"
L["GROUP_TAG"] = "組"
L["DUNGEON_QUESTS"] = "副本任務"
L["RAID_QUESTS"] = "團隊任務"

-- Best Time
L["BEST"] = "最佳"
L["MSG_NEW_BEST_TIME"] = "%s 新紀錄: %s (之前: %s)"

-- ============================================================================
-- Party Quest Sync
-- ============================================================================
L["PARTY_SYNC"] = "隊伍任務同步"
L["ENABLE_PARTY_SYNC"] = "啟用隊伍同步"
L["ENABLE_PARTY_SYNC_DESC"] = "與隊伍共享任務進度"
L["PARTY_SHOW_PROGRESS"] = "顯示隊伍進度"
L["PARTY_SHOW_PROGRESS_DESC"] = "在追蹤器中顯示"
L["PARTY_SHOW_INDICATOR"] = "隊伍指示器"
L["PARTY_SHOW_INDICATOR_DESC"] = "共享任務圖示"
L["PARTY_SYNC_ICON"] = "隊"

-- ============================================================================
-- Statistics Dashboard
-- ============================================================================
L["DASHBOARD_TITLE"] = "儀表板"
L["DASH_TITLE"] = "統計儀表板"
L["OPEN_DASHBOARD"] = "開啟儀表板"
L["DASH_OVERVIEW"] = "概覽"
L["DASH_ZONES"] = "區域進度"
L["DASH_HISTORY"] = "任務歷史"
L["DASH_DETAILED_STATS"] = "詳細統計"
L["DASH_FASTEST_QUEST"] = "最快任務"
L["DASH_SLOWEST_QUEST"] = "最慢任務"
L["DASH_TOP_ZONES"] = "熱門任務區域"
L["DASH_OVERALL_PROGRESS"] = "總體區域進度"
L["DASH_NO_ZONE_DATA"] = "暫無區域進度資料"
L["DASH_NO_HISTORY"] = "暫無任務歷史"
L["DASH_SHOWING_ENTRIES"] = "顯示 %d / %d 筆記錄"
L["DASH_MORE_ENTRIES"] = "... 還有 %d 筆記錄"
L["DASH_SORT_TIME"] = "時間"
L["DASH_SORT_NAME"] = "名稱"
L["DASH_SORT_LEVEL"] = "等級"
L["DASH_SORT_DURATION"] = "耗時"
L["DASH_COL_QUEST"] = "任務"
L["DASH_COL_LEVEL"] = "等級"
L["DASH_COL_XP"] = "經驗"
L["DASH_COL_TIME"] = "耗時"
L["DASH_COL_DATE"] = "日期"

-- ============================================================================
-- Zone Filter
-- ============================================================================
L["ZONE_FILTER"] = "僅當前區域"
L["ZONE_FILTER_DESC"] = "僅顯示當前區域的任務"

-- ============================================================================
-- Enhanced Minimap Tooltip
-- ============================================================================
L["MINIMAP_ACTIVE_QUESTS"] = "進行中的任務:"
L["MINIMAP_COMPLETED"] = "已完成:"
L["MINIMAP_IN_ZONE"] = "本區域:"
L["MINIMAP_CURRENT_WAYPOINT"] = "目前路徑點:"
L["MINIMAP_NO_WAYPOINT"] = "無活動路徑點"
L["MINIMAP_LEFT_CLICK"] = "左鍵點擊: 開啟設定"
L["MINIMAP_SHIFT_CLICK"] = "Shift+左鍵: 切換追蹤器"
L["MINIMAP_RIGHT_CLICK"] = "右鍵點擊: 切換箭頭"
L["MINIMAP_MIDDLE_CLICK"] = "中鍵點擊: 清除路徑點"
