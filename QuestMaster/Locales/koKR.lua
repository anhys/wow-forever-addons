-- QuestMaster Korean Localization
local addonName, QM = ...
if GetLocale() ~= "koKR" then return end

local L = QM.L

-- ============================================================================
-- General
-- ============================================================================
L["ADDON_LOADED"] = "QuestMaster 로드됨. /qm 입력하여 옵션 확인."
L["VERSION"] = "버전"
L["ENABLED"] = "활성화됨"
L["DISABLED"] = "비활성화됨"
L["YES"] = "예"
L["NO"] = "아니오"
L["DEFAULT"] = "기본값"
L["RESET"] = "초기화"
L["CLOSE"] = "닫기"
L["SAVE"] = "저장"
L["CANCEL"] = "취소"
L["DELETE"] = "삭제"
L["UNKNOWN"] = "알 수 없음"
L["NONE"] = "없음"
L["GO"] = "이동"
L["SEARCH"] = "검색"
L["REFRESHED"] = "새로고침됨"

-- ============================================================================
-- Tabs
-- ============================================================================
L["TAB_GENERAL"] = "일반"
L["TAB_GENERAL_DESC"] = "핵심 설정"
L["TAB_TRACKER"] = "추적기"
L["TAB_TRACKER_DESC"] = "퀘스트 목록"
L["TAB_ARROW"] = "화살표"
L["TAB_ARROW_DESC"] = "내비게이션"
L["TAB_MAP"] = "지도"
L["TAB_MAP_DESC"] = "핀과 마커"
L["TAB_STATISTICS"] = "통계"
L["TAB_STATISTICS_DESC"] = "경험치 추적"
L["TAB_DASHBOARD"] = "대시보드"
L["TAB_DASHBOARD_DESC"] = "통계 및 기록"
L["TAB_AUTOMATION"] = "자동화"
L["TAB_AUTOMATION_DESC"] = "자동 기능"
L["TAB_ADVANCED"] = "고급"
L["TAB_ADVANCED_DESC"] = "전문가"
L["TAB_CREDITS"] = "크레딧"
L["TAB_CREDITS_DESC"] = "정보 및 링크"

-- ============================================================================
-- Settings Header
-- ============================================================================
L["SETTINGS"] = "설정"
L["SETTINGS_TITLE"] = "QuestMaster 설정"

-- ============================================================================
-- General Settings
-- ============================================================================
L["MAIN_SETTINGS"] = "주요 설정"
L["ENABLE_ADDON"] = "QuestMaster 활성화"
L["ENABLE_ADDON_DESC"] = "모든 기능의 마스터 스위치"
L["LOCK_FRAMES"] = "프레임 위치 잠금"
L["LOCK_FRAMES_DESC"] = "드래그 방지"
L["SHOW_MINIMAP_BUTTON"] = "미니맵 버튼 표시"
L["SHOW_MINIMAP_BUTTON_DESC"] = "미니맵에 버튼 표시"

-- ============================================================================
-- Sounds
-- ============================================================================
L["SOUNDS"] = "소리 효과"
L["QUEST_PROGRESS_SOUND"] = "퀘스트 진행 소리"
L["QUEST_PROGRESS_SOUND_DESC"] = "진행 시 소리"
L["QUEST_COMPLETE_SOUND"] = "퀘스트 완료 소리"
L["QUEST_COMPLETE_SOUND_DESC"] = "완료 시 소리"

-- ============================================================================
-- Announcements
-- ============================================================================
L["QUEST_ANNOUNCEMENTS"] = "퀘스트 알림"
L["ANNOUNCE_ACCEPT"] = "퀘스트 수락 알림"
L["ANNOUNCE_ACCEPT_DESC"] = "파티/길드에"
L["ACCEPT_CHANNEL"] = "수락 채널"
L["ANNOUNCE_DONE"] = "퀘스트 완료 알림"
L["ANNOUNCE_DONE_DESC"] = "파티/길드에"
L["COMPLETE_CHANNEL"] = "완료 채널"
L["CHANNEL_PARTY"] = "파티"
L["CHANNEL_GUILD"] = "길드"
L["CHANNEL_EMOTE"] = "감정표현 (/me)"
L["CHANNEL_DISABLED"] = "비활성화됨"

-- Level Up
L["LEVEL_UP_ANNOUNCEMENTS"] = "레벨업 알림"
L["ANNOUNCE_LEVEL_UP"] = "레벨업 알림"
L["ANNOUNCE_LEVEL_UP_DESC"] = "감정표현/파티에"
L["LEVEL_UP_CHANNEL"] = "레벨업 채널"

-- ============================================================================
-- Quick Actions
-- ============================================================================
L["QUICK_ACTIONS"] = "빠른 작업"
L["RESET_POSITIONS"] = "위치 초기화"
L["REFRESH_DATA"] = "데이터 새로고침"

-- ============================================================================
-- Quest Tracker
-- ============================================================================
L["QUEST_TRACKER"] = "퀘스트 추적기"
L["ENABLE_TRACKER"] = "추적기 활성화"
L["ENABLE_TRACKER_DESC"] = "퀘스트 패널 표시"
L["FONT_SIZE"] = "글꼴 크기"
L["BACKGROUND_OPACITY"] = "배경 투명도"
L["TRACKER_TITLE"] = "QuestMaster"
L["ACTIVE_QUESTS"] = "진행 중인 퀘스트"
L["READY_FOR_TURNIN"] = "제출 준비 완료"
L["NO_ACTIVE_QUESTS"] = "진행 중인 퀘스트 없음"

-- Display Options
L["DISPLAY_OPTIONS"] = "표시 옵션"
L["SHOW_QUEST_LEVEL"] = "퀘스트 레벨 표시"
L["SHOW_QUEST_LEVEL_DESC"] = "괄호 안에 레벨"
L["SHOW_DISTANCE"] = "거리 표시"
L["SHOW_DISTANCE_DESC"] = "목표까지 거리"
L["COLOR_BY_DIFFICULTY"] = "난이도별 색상"
L["COLOR_BY_DIFFICULTY_DESC"] = "레벨 기반 색상"
L["SHOW_PROGRESS_BARS"] = "진행률 바 표시"
L["SHOW_PROGRESS_BARS_DESC"] = "목표 아래 바"
L["SHOW_COMPLETED"] = "완료된 퀘스트 표시"
L["SHOW_COMPLETED_DESC"] = "완료된 퀘스트 표시"
L["MAX_QUESTS"] = "최대 퀘스트 표시"

-- Default Tracker
L["HIDE_BLIZZARD_TRACKER"] = "기본 퀘스트 추적기 숨기기"
L["HIDE_BLIZZARD_TRACKER_DESC"] = "블리자드 기본 퀘스트 추적기 숨기기"
L["HIDE_BLIZZARD_TRACKER_COMBAT"] = "전투 중에는 기본 추적기를 전환할 수 없습니다."
L["HIDE_BLIZZARD_TRACKER_RELOAD"] = "기본 추적기를 다시 활성화하려면 UI를 다시 로드해야 합니다. 지금 다시 로드하시겠습니까?"

-- Sorting
L["SORTING"] = "정렬"
L["SORT_BY"] = "정렬 기준"
L["SORT_QUESTS_BY"] = "퀘스트 정렬 기준"
L["SORT_DISTANCE"] = "거리"
L["SORT_LEVEL"] = "레벨"
L["CURRENT"] = "현재"

-- Tracker Buttons
L["SORT"] = "정렬"
L["NAVIGATE_TO_NEAREST"] = "가장 가까운 곳으로 이동"
L["CLICK_TO_SET_WAYPOINT"] = "클릭하여 경로점 설정"
L["NAVIGATE_TO_TURNIN"] = "제출 NPC로 이동"
L["NEAREST_COMPLETED_QUEST"] = "가장 가까운 완료된 퀘스트"

-- ============================================================================
-- Arrow
-- ============================================================================
L["NAVIGATION_ARROW"] = "내비게이션 화살표"
L["ENABLE_ARROW"] = "화살표 활성화"
L["ENABLE_ARROW_DESC"] = "내비게이션 화살표 표시"
L["ARROW_SIZE"] = "화살표 크기"
L["ARROW_OPACITY"] = "화살표 투명도"
L["ARRIVAL_DISTANCE"] = "도착 거리"

-- Arrow Display
L["DISPLAY"] = "표시"
L["SHOW_OBJECTIVE"] = "목표 표시"
L["SHOW_OBJECTIVE_DESC"] = "목표 텍스트"
L["SHOW_ETA"] = "도착 예정 표시"
L["SHOW_ETA_DESC"] = "예상 시간"

-- Arrow Status
L["ARRIVED"] = "도착!"
L["NO_ACTIVE_OBJECTIVE"] = "활성 목표 없음"
L["QUEST_OBJECTIVE"] = "퀘스트 목표"
L["YARDS"] = "야드"
L["KILOMETERS"] = "km"

-- Arrow Tooltip
L["ARROW_NAVIGATION"] = "내비게이션"
L["OBJECTIVE"] = "목표"
L["LEFT_CLICK_DRAG"] = "좌클릭 + 드래그로 이동"
L["RIGHT_CLICK_OPTIONS"] = "우클릭으로 옵션"

-- Arrow Context Menu
L["HIDE_ARROW"] = "화살표 숨기기"
L["CLEAR_WAYPOINT"] = "경로점 제거"
L["FIND_NEAREST_AUTO"] = "가장 가까운 찾기 (자동)"
L["OPEN_SETTINGS"] = "설정 열기"

-- ETA
L["ETA"] = "도착 예정"
L["ETA_SECONDS"] = "도착: %d초"
L["ETA_MINUTES"] = "도착: %d분 %d초"
L["ETA_HOURS"] = "도착: %d시간 %d분"
L["MOVE_TO_CALCULATE"] = "(이동하여 ETA 계산)"

-- ============================================================================
-- Map
-- ============================================================================
L["WORLD_MAP"] = "세계 지도"
L["ENABLE_MAP_PINS"] = "지도 핀 활성화"
L["ENABLE_MAP_PINS_DESC"] = "퀘스트 핀 표시"
L["PIN_SIZE"] = "핀 크기"
L["PIN_OPACITY"] = "핀 투명도"

-- Pin Types
L["PIN_TYPES"] = "핀 유형"
L["OBJECTIVE_PINS"] = "목표 핀"
L["OBJECTIVE_PINS_DESC"] = "퀘스트 목표"
L["QUEST_AREAS"] = "퀘스트 영역"
L["QUEST_AREAS_DESC"] = "영역 강조"
L["TURNIN_PINS"] = "제출 핀 (?)"
L["TURNIN_PINS_DESC"] = "노란색 ? 핀"
L["AVAILABLE_QUESTS"] = "이용 가능한 퀘스트 (!)"
L["AVAILABLE_QUESTS_DESC"] = "노란색 ! 핀"
L["PATROL_PATHS"] = "NPC 순찰 경로"
L["PATROL_PATHS_DESC"] = "순찰 경로 표시"

-- ============================================================================
-- Statistics Tab
-- ============================================================================
L["QUEST_TIMER"] = "퀘스트 타이머"
L["ENABLE_TIMER"] = "타이머 활성화"
L["ENABLE_TIMER_DESC"] = "퀘스트 시간 추적"
L["SHOW_IN_TRACKER"] = "추적기에 표시"
L["SHOW_IN_TRACKER_DESC"] = "추적기에 표시"

L["XP_PER_HOUR"] = "시간당 경험치"
L["ENABLE_XP_TRACKER"] = "경험치 추적기 활성화"
L["ENABLE_XP_TRACKER_DESC"] = "경험치 비율 계산"
L["RESET_XP"] = "경험치 초기화"

L["RESTED_XP"] = "휴식 경험치"
L["ENABLE_RESTED_DISPLAY"] = "휴식 표시 활성화"
L["ENABLE_RESTED_DISPLAY_DESC"] = "휴식 경험치 표시"
L["SHOW_BONUS_INDICATOR"] = "+50% 보너스 표시"
L["SHOW_BONUS_INDICATOR_DESC"] = "보너스 표시기 표시"

L["LEVEL_TIME"] = "레벨 시간"
L["ENABLE_LEVEL_TIMER"] = "레벨 타이머 활성화"
L["ENABLE_LEVEL_TIMER_DESC"] = "레벨당 시간 추적"
L["SHOW_AVERAGE"] = "평균 표시"
L["SHOW_AVERAGE_DESC"] = "평균 시간 표시"

L["REMINDERS"] = "알림"
L["ENABLE_REMINDERS"] = "알림 활성화"
L["ENABLE_REMINDERS_DESC"] = "가방 및 수리 경고"
L["BAG_SPACE_WARNING"] = "가방 공간 경고"
L["BAG_SPACE_WARNING_DESC"] = "가방 가득 차면 경고"
L["BAG_THRESHOLD"] = "가방 임계값"
L["REPAIR_WARNING"] = "수리 경고"
L["REPAIR_WARNING_DESC"] = "내구도 낮으면 경고"

L["ZONE_PROGRESS"] = "지역 진행도"
L["ENABLE_ZONE_PROGRESS"] = "지역 진행도 활성화"
L["ENABLE_ZONE_PROGRESS_DESC"] = "지역별 추적"

L["REPUTATION"] = "평판"
L["ENABLE_REP_TRACKER"] = "평판 추적기 활성화"
L["ENABLE_REP_TRACKER_DESC"] = "감시 진영 추적"

-- Quest Statistics
L["QUEST_STATISTICS"] = "퀘스트 통계"
L["TOTAL_STATISTICS"] = "전체 통계"
L["QUESTS_COMPLETED"] = "완료한 퀘스트"
L["TOTAL_XP_GAINED"] = "총 획득 경험치"
L["AVG_QUEST_TIME"] = "평균 퀘스트 시간"
L["QUESTS_PER_HOUR"] = "시간당 퀘스트"
L["CURRENT_LEVEL"] = "현재 레벨"
L["TIME_ON_LEVEL"] = "레벨 소요 시간"
L["SESSION_QUESTS"] = "세션 퀘스트"
L["SESSION_XP"] = "세션 경험치"
L["REFRESH_STATS"] = "통계 새로고침"
L["RESET_SESSION"] = "세션 초기화"

-- Quest Search
L["QUEST_SEARCH"] = "퀘스트 검색"
L["SEARCH_PLACEHOLDER"] = "퀘스트 이름 또는 ID 입력..."
L["CLICK_RESULT_HINT"] = "결과를 클릭하여 퀘스트 시작 위치로 경로점 설정"
L["NO_QUESTS_FOUND"] = "일치하는 퀘스트 없음:"
L["WAYPOINT_SET_TO_QUEST"] = "퀘스트로 경로점 설정됨:"
L["NO_LOCATION_DATA"] = "위치 데이터 없음:"
L["QUEST_LABEL"] = "퀘스트:"
L["OBJECTIVES_LABEL"] = "목표:"

-- Manual Waypoint
L["MANUAL_WAYPOINT"] = "수동 경로점"
L["WAYPOINT"] = "경로점"
L["MANUAL"] = "[수동]"
L["CURRENT_WAYPOINT"] = "현재:"
L["NO_WAYPOINT_SET"] = "경로점 설정 없음"
L["X_COORD"] = "X:"
L["Y_COORD"] = "Y:"
L["SET"] = "설정"
L["INVALID_COORDINATES"] = "잘못된 좌표 (0-100)"
L["COORD_HINT"] = "좌표 입력 예: 45.5 및 67.2 (값 0-100)"

-- ============================================================================
-- Automation Tab
-- ============================================================================
L["QUEST_AUTOMATION"] = "퀘스트 자동화"
L["AUTO_ACCEPT"] = "퀘스트 자동 수락"
L["AUTO_ACCEPT_DESC"] = "Shift로 건너뛰기"
L["AUTO_COMPLETE"] = "퀘스트 자동 완료"
L["AUTO_COMPLETE_DESC"] = "Shift로 건너뛰기"
L["SKIP_REWARD_CHOICE"] = "보상 선택 건너뛰기"
L["SKIP_REWARD_CHOICE_DESC"] = "선택 대기"
L["AUTO_SHARE"] = "퀘스트 자동 공유"
L["AUTO_SHARE_DESC"] = "파티와 공유"

L["WAYPOINT_AUTO"] = "경로점 자동"
L["AUTO_SET_WAYPOINT"] = "경로점 자동 설정"
L["AUTO_SET_WAYPOINT_DESC"] = "가장 가까운 퀘스트"
L["AUTO_ADVANCE"] = "자동 진행"
L["AUTO_ADVANCE_DESC"] = "완료 시 다음"
L["PRIORITIZE_TURNINS"] = "제출 우선"
L["PRIORITIZE_TURNINS_DESC"] = "제출 먼저"

L["QUEST_FILTERS"] = "퀘스트 필터"
L["SHOW_DUNGEON"] = "던전 퀘스트 표시"
L["SHOW_DUNGEON_DESC"] = "던전 퀘스트 포함"
L["SHOW_RAID"] = "공격대 퀘스트 표시"
L["SHOW_RAID_DESC"] = "공격대 퀘스트 포함"
L["SHOW_GROUP"] = "파티 퀘스트 표시"
L["SHOW_GROUP_DESC"] = "파티 퀘스트 포함"
L["SHOW_PVP"] = "PvP 퀘스트 표시"
L["SHOW_PVP_DESC"] = "PvP 퀘스트 포함"
L["SHOW_LOW_LEVEL"] = "저레벨 퀘스트 표시"
L["SHOW_LOW_LEVEL_DESC"] = "회색 퀘스트 포함"

-- ============================================================================
-- Advanced Tab
-- ============================================================================
L["THEME"] = "테마"
L["COLOR_THEME"] = "색상 테마"
L["THEME_GOLD"] = "골드 (기본값)"
L["THEME_BLUE"] = "파랑"
L["THEME_GREEN"] = "초록"
L["THEME_RED"] = "빨강"
L["THEME_PURPLE"] = "보라"
L["THEME_ORANGE"] = "주황"
L["THEME_TEAL"] = "청록"
L["THEME_PINK"] = "분홍"
L["THEME_SILVER"] = "은색"
L["THEME_BRONZE"] = "청동"

L["PERFORMANCE"] = "성능"
L["UPDATE_INTERVAL"] = "업데이트 간격"
L["UPDATE_THROTTLE"] = "업데이트 제한"
L["REDUCE_MAP_UPDATES"] = "지도 업데이트 줄이기"
L["REDUCE_MAP_UPDATES_DESC"] = "지연 업데이트"

L["QUEST_NOTES"] = "퀘스트 메모"
L["MAX_NOTE_LENGTH"] = "최대 메모 길이"

L["DEBUG_TOOLS"] = "디버그 및 도구"
L["DEBUG_MODE"] = "디버그 모드"
L["DEBUG_MODE_DESC"] = "채팅 디버그 정보"
L["RESET_SETTINGS"] = "설정 초기화"
L["RELOAD_UI"] = "UI 새로고침"
L["RESET_CONFIRM"] = "모든 QuestMaster 설정을 초기화하시겠습니까?"

-- ============================================================================
-- Credits Tab
-- ============================================================================
L["CREDITS_VERSION"] = "버전 1.3"
L["CREDITS_EDITION"] = "올인원 에디션"
L["CREDITS_DESCRIPTION"] = "내비게이션 화살표, 지도 핀, 통계 및 자동화 기능이 포함된 프리미엄 퀘스트 추적 애드온."
L["DEVELOPER"] = "개발자"
L["ALSO_KNOWN_AS"] = "또한 알려진"
L["DEVELOPER_BIO"] = "WoW 애드온 개발자 및 콘텐츠 크리에이터. Twitch.tv/Novi_Live에서 실시간 스트리밍"
L["CONNECT"] = "연결"
L["TWITCH"] = "Twitch"
L["DISCORD"] = "Discord"
L["CURSEFORGE"] = "CurseForge"
L["DOWNLOADS_BUGS"] = "다운로드 및 버그 신고"
L["CHANGELOG"] = "변경 내역"
L["SPECIAL_THANKS"] = "특별한 감사"
L["THANKS_MESSAGE"] = "Twitch의 모든 시청자, 테스터 및 후원자분들께! 여러분의 피드백이 QuestMaster를 더 좋게 만듭니다."

-- ============================================================================
-- Info Bar Tooltip
-- ============================================================================
L["SESSION_STATISTICS"] = "세션 통계"
L["CURRENT_XP"] = "현재 경험치:"
L["XP_REMAINING"] = "남은 경험치:"
L["XP_PER_HOUR_LABEL"] = "시간당 경험치:"
L["TIME_TO_LEVEL"] = "레벨업까지 시간:"
L["SESSION_TIME"] = "세션 시간:"
L["RESTED_AMOUNT"] = "휴식 양:"
L["RESTED_BUBBLES"] = "휴식 버블:"
L["BONUS_XP"] = "보너스 경험치:"
L["BONUS_UNTIL_DEPLETED"] = "소진될 때까지 +50%"
L["CURRENT_LEVEL_LABEL"] = "현재 레벨:"
L["AVERAGE_PER_LEVEL"] = "레벨당 평균:"
L["PROGRESS"] = "진행도:"
L["STATUS"] = "상태"
L["BAG_SPACE"] = "가방 공간:"
L["FREE"] = "비어있음"
L["DURABILITY"] = "내구도:"
L["LOWEST"] = "최저"
L["TRACKED_REPUTATIONS"] = "추적 평판"
L["CLICK_TO_RESET_XP"] = "경험치 추적기 초기화하려면 클릭"

-- ============================================================================
-- Quest Display
-- ============================================================================
L["COMPLETE"] = "완료"
L["DONE"] = "완료됨"
L["TURN_IN"] = "제출"
L["TURN_IN_SUFFIX"] = " (제출)"
L["TIME_ON_QUEST"] = "퀘스트 소요 시간:"
L["NOTE"] = "메모:"
L["CLICK_SET_WAYPOINT"] = "좌클릭: 경로점 설정"
L["CLICK_OPEN_QUESTLOG"] = "Shift+좌클릭: 퀘스트 로그 열기"
L["CLICK_MORE_OPTIONS"] = "우클릭: 더 많은 옵션"
L["DISTANCE_TO_OBJECTIVE"] = "가장 가까운 목표까지의 거리"

-- Context Menu
L["SET_WAYPOINT"] = "경로점 설정"
L["SHOW_ON_MAP"] = "지도에 표시"
L["EXPAND_QUEST"] = "퀘스트 펼치기"
L["COLLAPSE_QUEST"] = "퀘스트 접기"
L["EDIT_NOTE"] = "메모 편집"
L["ADD_NOTE"] = "메모 추가"
L["SHARE_QUEST"] = "퀘스트 공유"
L["ABANDON_QUEST"] = "퀘스트 포기"

-- ============================================================================
-- Chat Messages
-- ============================================================================
L["MSG_PREFIX"] = "|cFF00FF00QuestMaster:|r"
L["MSG_ADDON_LOADED"] = "|cFFFFD700QuestMaster|r 로드됨! |cFF00FF00JugoBetrugoTV|r 또는 |cFFFF8800Novi_Live|r가 제작"
L["MSG_TWITCH"] = "|cFF9146FF  Twitch.tv/Novi_Live|r - 놀러 오세요!"
L["MSG_BUGS"] = "|cFF888888  버그? CurseForge 또는|r |cFF5865F2Discord.gg/rv2BsbE|r에 신고"

L["MSG_QUEST_ACCEPTED"] = "퀘스트 수락:"
L["MSG_ACCEPTED_QUEST"] = "퀘스트 수락됨:"
L["MSG_QUEST_COMPLETED"] = "퀘스트 완료:"
L["MSG_QUEST_READY"] = "퀘스트 제출 준비됨:"
L["MSG_OBJECTIVE_COMPLETE"] = "목표 완료:"
L["MSG_ABANDONED"] = "포기함:"
L["MSG_SHARED"] = "공유함:"
L["MSG_CANNOT_SHARE"] = "이 퀘스트는 공유할 수 없습니다"
L["MSG_QUEST_NOT_FOUND"] = "로그에서 퀘스트를 찾을 수 없습니다"

L["MSG_LEVEL_UP"] = "|cFFFFD700레벨업!|r |cFF00FF00%d|r 레벨에 도달했습니다!"
L["MSG_TIME_FROM_LEVEL"] = "%d 레벨에서 %d 레벨까지 시간:"
L["MSG_REACHED_LEVEL"] = "%d 레벨에 도달했습니다!"
L["MSG_REACHED_LEVEL_TIME"] = "%d 레벨에 도달했습니다! (%d 레벨에서 %s)"

L["MSG_WAYPOINT_SET"] = "경로점 설정됨: %.1f, %.1f - %s"
L["MSG_WAYPOINT_CORPSE"] = "시체 위치로 경로점 설정됨"
L["MSG_WAYPOINT_RESTORED"] = "이전 경로점 복원됨"
L["MSG_NAVIGATING_TO"] = "다음으로 이동 중:"
L["MSG_AUTO_NAV_TURNIN"] = "제출로 자동 이동"
L["MSG_AUTO_NAV_TO"] = "자동 이동 중:"
L["MSG_NO_QUESTS_NAV"] = "이동할 퀘스트 없음"
L["MSG_TURNIN"] = "제출:"
L["MSG_NO_COMPLETED"] = "제출할 완료된 퀘스트 없음"

L["MSG_XP_RESET"] = "시간당 경험치 추적기 초기화됨"
L["MSG_HISTORY_CLEARED"] = "퀘스트 기록 삭제됨"
L["MSG_SESSION_RESET"] = "세션 통계 초기화됨"
L["MSG_NOTE_SAVED"] = "다음에 대한 메모 저장됨:"
L["MSG_NOTE_DELETED"] = "다음에 대한 메모 삭제됨:"

L["MSG_COORDS_INVALID"] = "좌표는 0에서 100 사이여야 합니다"
L["MSG_NO_MAP"] = "현재 지도를 확인할 수 없습니다"
L["MSG_INVALID_COORDS"] = "잘못된 좌표입니다. 사용법: /qm way 45.2 67.8"
L["MSG_DB_FAIL"] = "데이터베이스 초기화 실패:"
L["MSG_DB_WARNING"] = "경고: 데이터베이스 프로필을 사용할 수 없습니다"
L["MSG_INIT_FAIL"] = "%s 초기화 실패:"
L["MSG_SETTINGS_NOT_READY"] = "설정이 준비되지 않았습니다"
L["MSG_UNKNOWN_CMD"] = "알 수 없는 명령어입니다. /qm help를 입력하여 명령어 목록을 확인하세요."

-- Help
L["HELP_USAGE"] = "사용법:"
L["HELP_SEARCH"] = "사용법: /qm search <퀘스트 이름 또는 ID>"
L["HELP_WAY"] = "사용법: /qm way <x> <y> [설명]"
L["HELP_WAY_EXAMPLE"] = "  예: /qm way 45.2 67.8 만남의 장소"
L["HELP_CREDITS"] = "/qm credits - 크레딧 표시"
L["HELP_STATS"] = "/qm stats - 퀘스트 통계 표시"
L["HELP_SEARCH_CMD"] = "/qm search <이름> - 퀘스트 데이터베이스 검색"
L["HELP_WAY_CMD"] = "/qm way <x> <y> [설명] - 수동 경로점 설정"

-- Statistics Print
L["STATS_HEADER"] = "========== 퀘스트 통계 =========="
L["STATS_TOTAL_COMPLETED"] = "총 완료: %d 퀘스트"
L["STATS_TOTAL_XP"] = "퀘스트 총 경험치:"
L["STATS_AVG_TIME"] = "평균 퀘스트 시간:"
L["STATS_QUESTS_HOUR"] = "시간당 퀘스트: %.1f"
L["STATS_FASTEST"] = "가장 빠른 퀘스트: %s (%s)"
L["STATS_SLOWEST"] = "가장 느린 퀘스트: %s (%s)"
L["STATS_SESSION_HEADER"] = "--- 세션 통계 ---"
L["STATS_SESSION_COMPLETED"] = "이번 세션 완료: %d 퀘스트"
L["STATS_SESSION_XP"] = "이번 세션 경험치:"
L["STATS_TOP_ZONES"] = "--- 인기 지역 ---"

-- Search Results
L["SEARCH_NO_RESULTS"] = "'%s'에 대한 퀘스트를 찾을 수 없습니다"
L["SEARCH_HEADER"] = "=== 퀘스트 검색: '%s' (%d개 결과) ==="
L["SEARCH_COMPLETED"] = "[완료됨]"
L["SEARCH_IN_PROGRESS"] = "[진행 중]"

-- Waypoint
L["WAYPOINT_FORMAT"] = "경로점 (%.1f, %.1f)"
L["YOUR_CORPSE"] = "당신의 시체"

-- Tooltip
L["QUEST_ITEM"] = "퀘스트 아이템"
L["DROP_RATE_NOTE"] = "(예상 드롭률은 다를 수 있음)"
L["QUEST_NOTE"] = "퀘스트 메모"

-- Time Format
L["TIME_HOURS_MINS"] = "%d시간 %d분"
L["TIME_HOURS"] = "%d시간"
L["TIME_MINS"] = "%d분"
L["TIME_ZERO"] = "0분"
L["AVG_FORMAT"] = "(평균: %s)"
L["LVL_PREFIX"] = "레벨:"
L["XP_HOUR_PREFIX"] = "경험치/시:"
L["RESTED_PREFIX"] = "휴식:"

-- Responsive Layout
L["QM_SHORT"] = "QM"
L["QUESTS_SHORT"] = "퀘스트"

-- ============================================================================
-- Quest Type Tags (Dungeon/Group/Raid)
-- ============================================================================
L["DUNGEON_TAG"] = "던"
L["RAID_TAG"] = "레"
L["GROUP_TAG"] = "파"
L["DUNGEON_QUESTS"] = "던전 퀘스트"
L["RAID_QUESTS"] = "공격대 퀘스트"

-- Best Time
L["BEST"] = "최고"
L["MSG_NEW_BEST_TIME"] = "%s 신기록: %s (이전: %s)"

-- ============================================================================
-- Party Quest Sync
-- ============================================================================
L["PARTY_SYNC"] = "파티 퀘스트 동기화"
L["ENABLE_PARTY_SYNC"] = "파티 동기화 활성화"
L["ENABLE_PARTY_SYNC_DESC"] = "파티와 퀘스트 진행상황 공유"
L["PARTY_SHOW_PROGRESS"] = "파티 진행상황 표시"
L["PARTY_SHOW_PROGRESS_DESC"] = "추적기에 표시"
L["PARTY_SHOW_INDICATOR"] = "파티 표시기"
L["PARTY_SHOW_INDICATOR_DESC"] = "공유 퀘스트 아이콘"
L["PARTY_SYNC_ICON"] = "파"

-- ============================================================================
-- Statistics Dashboard
-- ============================================================================
L["DASHBOARD_TITLE"] = "대시보드"
L["DASH_TITLE"] = "통계 대시보드"
L["OPEN_DASHBOARD"] = "대시보드 열기"
L["DASH_OVERVIEW"] = "개요"
L["DASH_ZONES"] = "지역 진행도"
L["DASH_HISTORY"] = "퀘스트 기록"
L["DASH_DETAILED_STATS"] = "상세 통계"
L["DASH_FASTEST_QUEST"] = "가장 빠른 퀘스트"
L["DASH_SLOWEST_QUEST"] = "가장 느린 퀘스트"
L["DASH_TOP_ZONES"] = "인기 퀘스트 지역"
L["DASH_OVERALL_PROGRESS"] = "전체 지역 진행도"
L["DASH_NO_ZONE_DATA"] = "지역 진행 데이터 없음"
L["DASH_NO_HISTORY"] = "퀘스트 기록 없음"
L["DASH_SHOWING_ENTRIES"] = "%d / %d 항목 표시"
L["DASH_MORE_ENTRIES"] = "... 그리고 %d개 더"
L["DASH_SORT_TIME"] = "시간"
L["DASH_SORT_NAME"] = "이름"
L["DASH_SORT_LEVEL"] = "레벨"
L["DASH_SORT_DURATION"] = "소요시간"
L["DASH_COL_QUEST"] = "퀘스트"
L["DASH_COL_LEVEL"] = "레벨"
L["DASH_COL_XP"] = "경험치"
L["DASH_COL_TIME"] = "시간"
L["DASH_COL_DATE"] = "날짜"

-- ============================================================================
-- Zone Filter
-- ============================================================================
L["ZONE_FILTER"] = "현재 지역만"
L["ZONE_FILTER_DESC"] = "현재 지역의 퀘스트만 표시"

-- ============================================================================
-- Enhanced Minimap Tooltip
-- ============================================================================
L["MINIMAP_ACTIVE_QUESTS"] = "진행 중인 퀘스트:"
L["MINIMAP_COMPLETED"] = "완료됨:"
L["MINIMAP_IN_ZONE"] = "지역 내:"
L["MINIMAP_CURRENT_WAYPOINT"] = "현재 경로점:"
L["MINIMAP_NO_WAYPOINT"] = "활성 경로점 없음"
L["MINIMAP_LEFT_CLICK"] = "좌클릭: 설정 열기"
L["MINIMAP_SHIFT_CLICK"] = "Shift+좌클릭: 추적기 전환"
L["MINIMAP_RIGHT_CLICK"] = "우클릭: 화살표 전환"
L["MINIMAP_MIDDLE_CLICK"] = "휠클릭: 경로점 제거"
