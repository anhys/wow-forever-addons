-- QuestMaster Russian Localization
local addonName, QM = ...
if GetLocale() ~= "ruRU" then return end

local L = QM.L

-- ============================================================================
-- General
-- ============================================================================
L["ADDON_NAME"] = "QuestMaster"
L["ADDON_LOADED"] = "QuestMaster загружен. Введите /qm для настроек."
L["VERSION"] = "Версия"
L["ENABLED"] = "Включено"
L["DISABLED"] = "Выключено"
L["YES"] = "Да"
L["NO"] = "Нет"
L["DEFAULT"] = "По умолчанию"
L["RESET"] = "Сброс"
L["CLOSE"] = "Закрыть"
L["SAVE"] = "Сохранить"
L["CANCEL"] = "Отмена"
L["DELETE"] = "Удалить"
L["UNKNOWN"] = "Неизвестно"
L["NONE"] = "Нет"
L["GO"] = "Вперёд"
L["SEARCH"] = "Поиск"
L["REFRESHED"] = "Обновлено"

-- ============================================================================
-- Tabs
-- ============================================================================
L["TAB_GENERAL"] = "Основные"
L["TAB_GENERAL_DESC"] = "Основные настройки"
L["TAB_TRACKER"] = "Трекер"
L["TAB_TRACKER_DESC"] = "Список заданий"
L["TAB_ARROW"] = "Стрелка"
L["TAB_ARROW_DESC"] = "Навигация"
L["TAB_MAP"] = "Карта"
L["TAB_MAP_DESC"] = "Метки на карте"
L["TAB_STATISTICS"] = "Статистика"
L["TAB_STATISTICS_DESC"] = "Отслеживание опыта"
L["TAB_DASHBOARD"] = "Панель"
L["TAB_DASHBOARD_DESC"] = "Статистика и история"
L["TAB_AUTOMATION"] = "Автоматизация"
L["TAB_AUTOMATION_DESC"] = "Автофункции"
L["TAB_ADVANCED"] = "Дополнительно"
L["TAB_ADVANCED_DESC"] = "Эксперт"
L["TAB_CREDITS"] = "Авторы"
L["TAB_CREDITS_DESC"] = "О дополнении"

-- ============================================================================
-- Settings Header
-- ============================================================================
L["SETTINGS"] = "Настройки"
L["SETTINGS_TITLE"] = "Настройки QuestMaster"

-- ============================================================================
-- General Settings
-- ============================================================================
L["MAIN_SETTINGS"] = "Основные настройки"
L["ENABLE_ADDON"] = "Включить QuestMaster"
L["ENABLE_ADDON_DESC"] = "Главный переключатель всех функций"
L["LOCK_FRAMES"] = "Заблокировать позиции окон"
L["LOCK_FRAMES_DESC"] = "Предотвратить перетаскивание"
L["SHOW_MINIMAP_BUTTON"] = "Показывать кнопку на миникарте"
L["SHOW_MINIMAP_BUTTON_DESC"] = "Кнопка на миникарте"

-- ============================================================================
-- Sounds
-- ============================================================================
L["SOUNDS"] = "Звуковые эффекты"
L["QUEST_PROGRESS_SOUND"] = "Звук прогресса задания"
L["QUEST_PROGRESS_SOUND_DESC"] = "Звук при прогрессе"
L["QUEST_COMPLETE_SOUND"] = "Звук завершения задания"
L["QUEST_COMPLETE_SOUND_DESC"] = "Звук при завершении"

-- ============================================================================
-- Announcements
-- ============================================================================
L["QUEST_ANNOUNCEMENTS"] = "Объявления о заданиях"
L["ANNOUNCE_ACCEPT"] = "Объявлять взятие заданий"
L["ANNOUNCE_ACCEPT_DESC"] = "Группе/гильдии"
L["ACCEPT_CHANNEL"] = "Канал взятия"
L["ANNOUNCE_DONE"] = "Объявлять завершение заданий"
L["ANNOUNCE_DONE_DESC"] = "Группе/гильдии"
L["COMPLETE_CHANNEL"] = "Канал завершения"
L["CHANNEL_PARTY"] = "Группа"
L["CHANNEL_GUILD"] = "Гильдия"
L["CHANNEL_EMOTE"] = "Эмоция (/me)"
L["CHANNEL_DISABLED"] = "Выключено"

-- Level Up
L["LEVEL_UP_ANNOUNCEMENTS"] = "Объявления повышения уровня"
L["ANNOUNCE_LEVEL_UP"] = "Объявлять повышение уровня"
L["ANNOUNCE_LEVEL_UP_DESC"] = "Эмоцией/группе"
L["LEVEL_UP_CHANNEL"] = "Канал повышения уровня"

-- ============================================================================
-- Quick Actions
-- ============================================================================
L["QUICK_ACTIONS"] = "Быстрые действия"
L["RESET_POSITIONS"] = "Сбросить позиции"
L["REFRESH_DATA"] = "Обновить данные"

-- ============================================================================
-- Quest Tracker
-- ============================================================================
L["QUEST_TRACKER"] = "Трекер заданий"
L["ENABLE_TRACKER"] = "Включить трекер"
L["ENABLE_TRACKER_DESC"] = "Показывать панель заданий"
L["FONT_SIZE"] = "Размер шрифта"
L["BACKGROUND_OPACITY"] = "Прозрачность фона"
L["TRACKER_TITLE"] = "QuestMaster"
L["ACTIVE_QUESTS"] = "Активные задания"
L["READY_FOR_TURNIN"] = "Готовы к сдаче"
L["NO_ACTIVE_QUESTS"] = "Нет активных заданий"

-- Display Options
L["DISPLAY_OPTIONS"] = "Опции отображения"
L["SHOW_QUEST_LEVEL"] = "Показывать уровень задания"
L["SHOW_QUEST_LEVEL_DESC"] = "Уровень в скобках"
L["SHOW_DISTANCE"] = "Показывать расстояние"
L["SHOW_DISTANCE_DESC"] = "Расстояние до цели"
L["COLOR_BY_DIFFICULTY"] = "Цвет по сложности"
L["COLOR_BY_DIFFICULTY_DESC"] = "Цвета по уровню"
L["SHOW_PROGRESS_BARS"] = "Показывать полосы прогресса"
L["SHOW_PROGRESS_BARS_DESC"] = "Полосы под целями"
L["SHOW_COMPLETED"] = "Показывать завершённые задания"
L["SHOW_COMPLETED_DESC"] = "Отображать законченные задания"
L["MAX_QUESTS"] = "Макс. показываемых заданий"

-- Default Tracker
L["HIDE_BLIZZARD_TRACKER"] = "Скрыть стандартный трекер заданий"
L["HIDE_BLIZZARD_TRACKER_DESC"] = "Скрыть встроенный трекер заданий Blizzard"
L["HIDE_BLIZZARD_TRACKER_COMBAT"] = "Нельзя переключить стандартный трекер в бою."
L["HIDE_BLIZZARD_TRACKER_RELOAD"] = "Повторное включение стандартного трекера требует перезагрузки интерфейса. Перезагрузить сейчас?"

-- Sorting
L["SORTING"] = "Сортировка"
L["SORT_BY"] = "Сортировать по"
L["SORT_QUESTS_BY"] = "Сортировать задания по"
L["SORT_DISTANCE"] = "Расстоянию"
L["SORT_LEVEL"] = "Уровню"
L["CURRENT"] = "Текущее"

-- Tracker Buttons
L["SORT"] = "Сортировка"
L["NAVIGATE_TO_NEAREST"] = "К ближайшей цели"
L["CLICK_TO_SET_WAYPOINT"] = "Нажмите для установки метки"
L["NAVIGATE_TO_TURNIN"] = "К сдаче задания"
L["NEAREST_COMPLETED_QUEST"] = "Ближайшее завершённое задание"

-- ============================================================================
-- Arrow
-- ============================================================================
L["NAVIGATION_ARROW"] = "Навигационная стрелка"
L["ENABLE_ARROW"] = "Включить стрелку"
L["ENABLE_ARROW_DESC"] = "Показывать навигационную стрелку"
L["ARROW_SIZE"] = "Размер стрелки"
L["ARROW_OPACITY"] = "Прозрачность стрелки"
L["ARRIVAL_DISTANCE"] = "Расстояние прибытия"

-- Arrow Display
L["DISPLAY"] = "Отображение"
L["SHOW_OBJECTIVE"] = "Показывать цель"
L["SHOW_OBJECTIVE_DESC"] = "Текст цели"
L["SHOW_ETA"] = "Показывать время прибытия"
L["SHOW_ETA_DESC"] = "Примерное время"

-- Arrow Status
L["ARRIVED"] = "Прибыли!"
L["NO_ACTIVE_OBJECTIVE"] = "Нет активной цели"
L["QUEST_OBJECTIVE"] = "Цель задания"
L["YARDS"] = "м"
L["KILOMETERS"] = "км"

-- Arrow Tooltip
L["ARROW_NAVIGATION"] = "Навигация"
L["OBJECTIVE"] = "Цель"
L["LEFT_CLICK_DRAG"] = "ЛКМ + перетащить для перемещения"
L["RIGHT_CLICK_OPTIONS"] = "ПКМ для настроек"

-- Arrow Context Menu
L["HIDE_ARROW"] = "Скрыть стрелку"
L["CLEAR_WAYPOINT"] = "Очистить метку"
L["FIND_NEAREST_AUTO"] = "Найти ближайшую (авто)"
L["OPEN_SETTINGS"] = "Открыть настройки"

-- ETA
L["ETA"] = "Время прибытия"
L["ETA_SECONDS"] = "Время: %dс"
L["ETA_MINUTES"] = "Время: %dм %dс"
L["ETA_HOURS"] = "Время: %dч %dм"
L["MOVE_TO_CALCULATE"] = "(Двигайтесь для расчёта времени)"

-- ============================================================================
-- Map
-- ============================================================================
L["WORLD_MAP"] = "Карта мира"
L["ENABLE_MAP_PINS"] = "Включить метки на карте"
L["ENABLE_MAP_PINS_DESC"] = "Показывать метки заданий"
L["PIN_SIZE"] = "Размер меток"
L["PIN_OPACITY"] = "Прозрачность меток"

-- Pin Types
L["PIN_TYPES"] = "Типы меток"
L["OBJECTIVE_PINS"] = "Метки целей"
L["OBJECTIVE_PINS_DESC"] = "Цели заданий"
L["QUEST_AREAS"] = "Зоны заданий"
L["QUEST_AREAS_DESC"] = "Подсветка зон"
L["TURNIN_PINS"] = "Метки сдачи (?)"
L["TURNIN_PINS_DESC"] = "Жёлтые метки ?"
L["AVAILABLE_QUESTS"] = "Доступные задания (!)"
L["AVAILABLE_QUESTS_DESC"] = "Жёлтые метки !"
L["PATROL_PATHS"] = "Маршруты патрулей NPC"
L["PATROL_PATHS_DESC"] = "Показывать пути патрулирования"

-- ============================================================================
-- Statistics Tab
-- ============================================================================
L["QUEST_TIMER"] = "Таймер заданий"
L["ENABLE_TIMER"] = "Включить таймер"
L["ENABLE_TIMER_DESC"] = "Отслеживать время заданий"
L["SHOW_IN_TRACKER"] = "Показывать в трекере"
L["SHOW_IN_TRACKER_DESC"] = "Отображать в трекере"

L["XP_PER_HOUR"] = "Опыт/час"
L["ENABLE_XP_TRACKER"] = "Включить трекер опыта"
L["ENABLE_XP_TRACKER_DESC"] = "Рассчитывать скорость получения опыта"
L["RESET_XP"] = "Сбросить опыт"

L["RESTED_XP"] = "Бодрость"
L["ENABLE_RESTED_DISPLAY"] = "Показывать бодрость"
L["ENABLE_RESTED_DISPLAY_DESC"] = "Показывать накопленную бодрость"
L["SHOW_BONUS_INDICATOR"] = "Показывать +50% бонус"
L["SHOW_BONUS_INDICATOR_DESC"] = "Показывать индикатор бонуса"

L["LEVEL_TIME"] = "Время уровня"
L["ENABLE_LEVEL_TIMER"] = "Включить таймер уровня"
L["ENABLE_LEVEL_TIMER_DESC"] = "Отслеживать время на уровень"
L["SHOW_AVERAGE"] = "Показывать среднее"
L["SHOW_AVERAGE_DESC"] = "Отображать среднее время"

L["REMINDERS"] = "Напоминания"
L["ENABLE_REMINDERS"] = "Включить напоминания"
L["ENABLE_REMINDERS_DESC"] = "Предупреждения о сумках и ремонте"
L["BAG_SPACE_WARNING"] = "Предупреждение о месте в сумках"
L["BAG_SPACE_WARNING_DESC"] = "Предупреждать когда сумки заполнены"
L["BAG_THRESHOLD"] = "Порог заполнения сумок"
L["REPAIR_WARNING"] = "Предупреждение о ремонте"
L["REPAIR_WARNING_DESC"] = "Предупреждать о низкой прочности"

L["ZONE_PROGRESS"] = "Прогресс по зонам"
L["ENABLE_ZONE_PROGRESS"] = "Включить прогресс по зонам"
L["ENABLE_ZONE_PROGRESS_DESC"] = "Отслеживать по зонам"

L["REPUTATION"] = "Репутация"
L["ENABLE_REP_TRACKER"] = "Включить трекер репутации"
L["ENABLE_REP_TRACKER_DESC"] = "Отслеживать выбранную фракцию"

-- Quest Statistics
L["QUEST_STATISTICS"] = "Статистика заданий"
L["TOTAL_STATISTICS"] = "Общая статистика"
L["QUESTS_COMPLETED"] = "Заданий завершено"
L["TOTAL_XP_GAINED"] = "Всего получено опыта"
L["AVG_QUEST_TIME"] = "Среднее время задания"
L["QUESTS_PER_HOUR"] = "Заданий в час"
L["CURRENT_LEVEL"] = "Текущий уровень"
L["TIME_ON_LEVEL"] = "Время на уровне"
L["SESSION_QUESTS"] = "Заданий за сессию"
L["SESSION_XP"] = "Опыт за сессию"
L["REFRESH_STATS"] = "Обновить статистику"
L["RESET_SESSION"] = "Сбросить сессию"

-- Quest Search
L["QUEST_SEARCH"] = "Поиск заданий"
L["SEARCH_PLACEHOLDER"] = "Введите название или ID задания..."
L["CLICK_RESULT_HINT"] = "Нажмите на результат для установки метки к началу задания"
L["NO_QUESTS_FOUND"] = "Заданий не найдено:"
L["WAYPOINT_SET_TO_QUEST"] = "Метка установлена на задание:"
L["NO_LOCATION_DATA"] = "Нет данных о местоположении для:"
L["QUEST_LABEL"] = "Задание:"
L["OBJECTIVES_LABEL"] = "Цели:"

-- Manual Waypoint
L["MANUAL_WAYPOINT"] = "Ручная метка"
L["WAYPOINT"] = "Метка"
L["MANUAL"] = "[Ручная]"
L["CURRENT_WAYPOINT"] = "Текущая:"
L["NO_WAYPOINT_SET"] = "Метка не установлена"
L["X_COORD"] = "X:"
L["Y_COORD"] = "Y:"
L["SET"] = "Установить"
L["INVALID_COORDINATES"] = "Неверные координаты (0-100)"
L["COORD_HINT"] = "Введите координаты вроде 45.5 и 67.2 (значения 0-100)"
L["CLEAR_WAYPOINT"] = "Очистить метку"

-- ============================================================================
-- Automation Tab
-- ============================================================================
L["QUEST_AUTOMATION"] = "Автоматизация заданий"
L["AUTO_ACCEPT"] = "Автопринятие заданий"
L["AUTO_ACCEPT_DESC"] = "Shift для пропуска"
L["AUTO_COMPLETE"] = "Автозавершение заданий"
L["AUTO_COMPLETE_DESC"] = "Shift для пропуска"
L["SKIP_REWARD_CHOICE"] = "Пропускать выбор награды"
L["SKIP_REWARD_CHOICE_DESC"] = "Ждать выбора"
L["AUTO_SHARE"] = "Автошеринг заданий"
L["AUTO_SHARE_DESC"] = "Делиться с группой"

L["WAYPOINT_AUTO"] = "Авто-метки"
L["AUTO_SET_WAYPOINT"] = "Автоустановка меток"
L["AUTO_SET_WAYPOINT_DESC"] = "На ближайшее задание"
L["AUTO_ADVANCE"] = "Автосмена цели"
L["AUTO_ADVANCE_DESC"] = "Следующая при завершении"
L["PRIORITIZE_TURNINS"] = "Приоритет сдачи заданий"
L["PRIORITIZE_TURNINS_DESC"] = "Сдача заданий в первую очередь"

L["QUEST_FILTERS"] = "Фильтры заданий"
L["SHOW_DUNGEON"] = "Показывать подземелья"
L["SHOW_DUNGEON_DESC"] = "Включая задания подземелий"
L["SHOW_RAID"] = "Показывать рейды"
L["SHOW_RAID_DESC"] = "Включая рейдовые задания"
L["SHOW_GROUP"] = "Показывать групповые"
L["SHOW_GROUP_DESC"] = "Включая групповые задания"
L["SHOW_PVP"] = "Показывать PvP"
L["SHOW_PVP_DESC"] = "Включая PvP задания"
L["SHOW_LOW_LEVEL"] = "Показывать низкоуровневые"
L["SHOW_LOW_LEVEL_DESC"] = "Включая серые задания"

-- ============================================================================
-- Advanced Tab
-- ============================================================================
L["THEME"] = "Тема"
L["COLOR_THEME"] = "Цветовая тема"
L["THEME_GOLD"] = "Золотая (по умолчанию)"
L["THEME_BLUE"] = "Синяя"
L["THEME_GREEN"] = "Зелёная"
L["THEME_RED"] = "Красная"
L["THEME_PURPLE"] = "Фиолетовая"
L["THEME_ORANGE"] = "Оранжевая"
L["THEME_TEAL"] = "Бирюзовая"
L["THEME_PINK"] = "Розовая"
L["THEME_SILVER"] = "Серебряная"
L["THEME_BRONZE"] = "Бронзовая"

L["PERFORMANCE"] = "Производительность"
L["UPDATE_INTERVAL"] = "Интервал обновления"
L["UPDATE_THROTTLE"] = "Ограничение обновлений"
L["REDUCE_MAP_UPDATES"] = "Уменьшить обновления карты"
L["REDUCE_MAP_UPDATES_DESC"] = "Ленивые обновления"

L["QUEST_NOTES"] = "Заметки о заданиях"
L["MAX_NOTE_LENGTH"] = "Макс. длина заметки"

L["DEBUG_TOOLS"] = "Отладка и инструменты"
L["DEBUG_MODE"] = "Режим отладки"
L["DEBUG_MODE_DESC"] = "Отладочная информация в чат"
L["RESET_SETTINGS"] = "Сбросить настройки"
L["RELOAD_UI"] = "Перезагрузить UI"
L["RESET_CONFIRM"] = "Сбросить все настройки QuestMaster?"

-- ============================================================================
-- Credits Tab
-- ============================================================================
L["CREDITS_VERSION"] = "Версия 1.2"
L["CREDITS_EDITION"] = "All-in-One Edition"
L["CREDITS_DESCRIPTION"] = "Премиум дополнение для отслеживания заданий с навигационными стрелками, метками на карте, статистикой и функциями автоматизации."
L["DEVELOPER"] = "Разработчик"
L["ALSO_KNOWN_AS"] = "также известный как"
L["DEVELOPER_BIO"] = "Разработчик дополнений WoW и создатель контента. Стримы на Twitch.tv/Novi_Live"
L["CONNECT"] = "Связаться"
L["TWITCH"] = "Twitch"
L["DISCORD"] = "Discord"
L["CURSEFORGE"] = "CurseForge"
L["DOWNLOADS_BUGS"] = "Загрузки и баг-репорты"
L["CHANGELOG"] = "История изменений"
L["SPECIAL_THANKS"] = "Особая благодарность"
L["THANKS_MESSAGE"] = "Всем зрителям, тестерам и поддерживающим на Twitch! Ваши отзывы помогают делать QuestMaster лучше."

-- ============================================================================
-- Info Bar Tooltip
-- ============================================================================
L["SESSION_STATISTICS"] = "Статистика сессии"
L["CURRENT_XP"] = "Текущий опыт:"
L["XP_REMAINING"] = "Осталось опыта:"
L["XP_PER_HOUR_LABEL"] = "Опыт в час:"
L["TIME_TO_LEVEL"] = "Время до уровня:"
L["SESSION_TIME"] = "Время сессии:"
L["RESTED_AMOUNT"] = "Накопленная бодрость:"
L["RESTED_BUBBLES"] = "Пузырьков бодрости:"
L["BONUS_XP"] = "Бонусный опыт:"
L["BONUS_UNTIL_DEPLETED"] = "+50% пока не израсходуется"
L["CURRENT_LEVEL_LABEL"] = "Текущий уровень:"
L["AVERAGE_PER_LEVEL"] = "В среднем за уровень:"
L["PROGRESS"] = "Прогресс:"
L["STATUS"] = "Статус"
L["BAG_SPACE"] = "Место в сумках:"
L["FREE"] = "свободно"
L["DURABILITY"] = "Прочность:"
L["LOWEST"] = "самая низкая"
L["TRACKED_REPUTATIONS"] = "Отслеживаемая репутация"
L["CLICK_TO_RESET_XP"] = "Нажмите для сброса трекера опыта"

-- ============================================================================
-- Quest Display
-- ============================================================================
L["COMPLETE"] = "ЗАВЕРШЕНО"
L["DONE"] = "ГОТОВО"
L["TURN_IN"] = "Сдать"
L["TURN_IN_SUFFIX"] = " (Сдать)"
L["TIME_ON_QUEST"] = "Время на задании:"
L["NOTE"] = "Заметка:"
L["CLICK_SET_WAYPOINT"] = "ЛКМ: Установить метку"
L["CLICK_OPEN_QUESTLOG"] = "Shift+ЛКМ: Открыть журнал заданий"
L["CLICK_MORE_OPTIONS"] = "ПКМ: Больше опций"
L["DISTANCE_TO_OBJECTIVE"] = "Расстояние до ближайшей цели"

-- Context Menu
L["SET_WAYPOINT"] = "Установить метку"
L["SHOW_ON_MAP"] = "Показать на карте"
L["EXPAND_QUEST"] = "Развернуть задание"
L["COLLAPSE_QUEST"] = "Свернуть задание"
L["EDIT_NOTE"] = "Редактировать заметку"
L["ADD_NOTE"] = "Добавить заметку"
L["SHARE_QUEST"] = "Поделиться заданием"
L["ABANDON_QUEST"] = "Отказаться от задания"

-- ============================================================================
-- Chat Messages
-- ============================================================================
L["MSG_PREFIX"] = "|cFF00FF00QuestMaster:|r"
L["MSG_ADDON_LOADED"] = "|cFFFFD700QuestMaster|r загружен! создан |cFF00FF00JugoBetrugoTV|r aka |cFFFF8800Novi_Live|r"
L["MSG_TWITCH"] = "|cFF9146FF  Twitch.tv/Novi_Live|r - Заходите в гости!"
L["MSG_BUGS"] = "|cFF888888  Баги? Сообщайте на CurseForge или|r |cFF5865F2Discord.gg/rv2BsbE|r"

L["MSG_QUEST_ACCEPTED"] = "Задание принято:"
L["MSG_ACCEPTED_QUEST"] = "Принято задание:"
L["MSG_QUEST_COMPLETED"] = "Задание завершено:"
L["MSG_QUEST_READY"] = "Задание готово к сдаче:"
L["MSG_OBJECTIVE_COMPLETE"] = "Цель выполнена:"
L["MSG_ABANDONED"] = "Отказ:"
L["MSG_SHARED"] = "Поделились:"
L["MSG_CANNOT_SHARE"] = "Нельзя поделиться этим заданием"
L["MSG_QUEST_NOT_FOUND"] = "Не удалось найти задание в журнале"

L["MSG_LEVEL_UP"] = "|cFFFFD700НОВЫЙ УРОВЕНЬ!|r Вы достигли уровня |cFF00FF00%d|r!"
L["MSG_TIME_FROM_LEVEL"] = "Время с уровня %d до %d:"
L["MSG_REACHED_LEVEL"] = "Достигнут уровень %d!"
L["MSG_REACHED_LEVEL_TIME"] = "Достигнут уровень %d! (%s с уровня %d)"

L["MSG_WAYPOINT_SET"] = "Метка установлена на %.1f, %.1f - %s"
L["MSG_WAYPOINT_CORPSE"] = "Метка установлена на местоположение вашего трупа"
L["MSG_WAYPOINT_RESTORED"] = "Предыдущая метка восстановлена"
L["MSG_NAVIGATING_TO"] = "Навигация к:"
L["MSG_AUTO_NAV_TURNIN"] = "Автонавигация к сдаче задания"
L["MSG_AUTO_NAV_TO"] = "Автонавигация к:"
L["MSG_NO_QUESTS_NAV"] = "Нет заданий для навигации"
L["MSG_TURNIN"] = "Сдать:"
L["MSG_NO_COMPLETED"] = "Нет завершённых заданий для сдачи"

L["MSG_XP_RESET"] = "Трекер опыт/час сброшен"
L["MSG_HISTORY_CLEARED"] = "История заданий очищена"
L["MSG_SESSION_RESET"] = "Статистика сессии сброшена"
L["MSG_NOTE_SAVED"] = "Заметка сохранена для:"
L["MSG_NOTE_DELETED"] = "Заметка удалена для:"

L["MSG_COORDS_INVALID"] = "Координаты должны быть от 0 до 100"
L["MSG_NO_MAP"] = "Не удалось определить текущую карту"
L["MSG_INVALID_COORDS"] = "Неверные координаты. Используйте: /qm way 45.2 67.8"
L["MSG_DB_FAIL"] = "Не удалось инициализировать базу данных:"
L["MSG_DB_WARNING"] = "Предупреждение: Профиль базы данных недоступен"
L["MSG_INIT_FAIL"] = "Не удалось инициализировать %s:"
L["MSG_SETTINGS_NOT_READY"] = "Настройки не готовы"
L["MSG_UNKNOWN_CMD"] = "Неизвестная команда. Введите /qm help для списка команд."

-- Help
L["HELP_USAGE"] = "Использование:"
L["HELP_SEARCH"] = "Использование: /qm search <название или id задания>"
L["HELP_WAY"] = "Использование: /qm way <x> <y> [описание]"
L["HELP_WAY_EXAMPLE"] = "  Пример: /qm way 45.2 67.8 Место встречи"
L["HELP_CREDITS"] = "/qm credits - Показать авторов"
L["HELP_STATS"] = "/qm stats - Показать статистику заданий"
L["HELP_SEARCH_CMD"] = "/qm search <название> - Поиск в базе заданий"
L["HELP_WAY_CMD"] = "/qm way <x> <y> [описание] - Установить ручную метку"

-- Statistics Print
L["STATS_HEADER"] = "========== Статистика заданий =========="
L["STATS_TOTAL_COMPLETED"] = "Всего завершено: %d заданий"
L["STATS_TOTAL_XP"] = "Всего опыта с заданий:"
L["STATS_AVG_TIME"] = "Среднее время задания:"
L["STATS_QUESTS_HOUR"] = "Заданий/час: %.1f"
L["STATS_FASTEST"] = "Самое быстрое задание: %s (%s)"
L["STATS_SLOWEST"] = "Самое медленное задание: %s (%s)"
L["STATS_SESSION_HEADER"] = "--- Статистика сессии ---"
L["STATS_SESSION_COMPLETED"] = "Завершено за сессию: %d заданий"
L["STATS_SESSION_XP"] = "Опыт за сессию:"
L["STATS_TOP_ZONES"] = "--- Топ зон ---"

-- Search Results
L["SEARCH_NO_RESULTS"] = "Заданий не найдено для '%s'"
L["SEARCH_HEADER"] = "=== Поиск заданий: '%s' (результатов: %d) ==="
L["SEARCH_COMPLETED"] = "[Завершено]"
L["SEARCH_IN_PROGRESS"] = "[В процессе]"

-- Waypoint
L["WAYPOINT_FORMAT"] = "Метка (%.1f, %.1f)"
L["YOUR_CORPSE"] = "Ваш труп"

-- Tooltip
L["QUEST_ITEM"] = "Квестовый предмет"
L["DROP_RATE_NOTE"] = "(Примерный шанс выпадения варьируется)"
L["QUEST_NOTE"] = "Заметка о задании"

-- Time Format
L["TIME_HOURS_MINS"] = "%dч %dмин"
L["TIME_HOURS"] = "%dч"
L["TIME_MINS"] = "%d мин"
L["TIME_ZERO"] = "0 мин"
L["AVG_FORMAT"] = "(среднее: %s)"
L["LVL_PREFIX"] = "Ур:"
L["XP_HOUR_PREFIX"] = "Опыт/ч:"
L["RESTED_PREFIX"] = "Бодрость:"

-- Responsive Layout
L["QM_SHORT"] = "QM"
L["QUESTS_SHORT"] = "Задания"

-- Quest Type Tags
L["DUNGEON_TAG"] = "П"
L["RAID_TAG"] = "Р"
L["GROUP_TAG"] = "Г"
L["DUNGEON_QUESTS"] = "Задания подземелий"
L["RAID_QUESTS"] = "Рейдовые задания"
L["BEST"] = "Лучшее"
L["MSG_NEW_BEST_TIME"] = "Новый рекорд %s: %s (предыдущий: %s)"

-- Party Quest Sync
L["PARTY_SYNC"] = "Синхронизация группы"
L["ENABLE_PARTY_SYNC"] = "Включить синхронизацию"
L["ENABLE_PARTY_SYNC_DESC"] = "Делиться прогрессом с группой"
L["PARTY_SHOW_PROGRESS"] = "Показать прогресс группы"
L["PARTY_SHOW_PROGRESS_DESC"] = "Отображать в трекере"
L["PARTY_SHOW_INDICATOR"] = "Индикатор группы"
L["PARTY_SHOW_INDICATOR_DESC"] = "Значок на общих заданиях"
L["PARTY_SYNC_ICON"] = "Г"

-- Statistics Dashboard
L["DASHBOARD_TITLE"] = "Панель"
L["DASH_TITLE"] = "Панель статистики"
L["OPEN_DASHBOARD"] = "Открыть панель"
L["DASH_OVERVIEW"] = "Обзор"
L["DASH_ZONES"] = "Прогресс по зонам"
L["DASH_HISTORY"] = "История заданий"
L["DASH_DETAILED_STATS"] = "Подробная статистика"
L["DASH_FASTEST_QUEST"] = "Самое быстрое задание"
L["DASH_SLOWEST_QUEST"] = "Самое медленное задание"
L["DASH_TOP_ZONES"] = "Лучшие зоны заданий"
L["DASH_OVERALL_PROGRESS"] = "Общий прогресс"
L["DASH_NO_ZONE_DATA"] = "Нет данных о зонах"
L["DASH_NO_HISTORY"] = "Нет истории заданий"
L["DASH_SHOWING_ENTRIES"] = "Показано %d из %d записей"
L["DASH_MORE_ENTRIES"] = "... и ещё %d записей"
L["DASH_SORT_TIME"] = "Время"
L["DASH_SORT_NAME"] = "Имя"
L["DASH_SORT_LEVEL"] = "Уровень"
L["DASH_SORT_DURATION"] = "Длительность"
L["DASH_COL_QUEST"] = "Задание"
L["DASH_COL_LEVEL"] = "Ур"
L["DASH_COL_XP"] = "Опыт"
L["DASH_COL_TIME"] = "Время"
L["DASH_COL_DATE"] = "Дата"

-- Zone Filter & Minimap Tooltip
L["ZONE_FILTER"] = "Только текущая зона"
L["ZONE_FILTER_DESC"] = "Показывать только задания текущей зоны"
L["MINIMAP_ACTIVE_QUESTS"] = "Активные задания:"
L["MINIMAP_COMPLETED"] = "Завершённые:"
L["MINIMAP_IN_ZONE"] = "В зоне:"
L["MINIMAP_CURRENT_WAYPOINT"] = "Текущая точка маршрута:"
L["MINIMAP_NO_WAYPOINT"] = "Нет активной точки маршрута"
L["MINIMAP_LEFT_CLICK"] = "ЛКМ: Открыть настройки"
L["MINIMAP_SHIFT_CLICK"] = "Shift+ЛКМ: Переключить трекер"
L["MINIMAP_RIGHT_CLICK"] = "ПКМ: Переключить стрелку"
L["MINIMAP_MIDDLE_CLICK"] = "СКМ: Очистить точку маршрута"
