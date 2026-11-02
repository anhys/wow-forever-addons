-- ForeverLFG -- Copyright (c) 2026 Forever. All rights reserved. See LICENSE.
local _, NS = ...
local en = {
    BROWSE_MODE = "Mode", BROWSE_LANGUAGES = "Languages", BROWSE_STYLE = "Playstyle", BROWSE_ANY = "Any", BROWSE_ANY_STYLE = "Any",
    BROWSE_GROUP_FILTERS = "Group filters", BROWSE_PLAYER_FILTERS = "Player filters", BROWSE_FREE_ROLE = "Free slot:",
    BROWSE_LEVEL = "Level", BROWSE_CLASSES = "Classes", BROWSE_ALL_CLASSES = "All classes", BROWSE_CLASS_COUNT = "%d selected",
    BROWSE_SELECT_ALL = "Select all", BROWSE_CLEAR = "Clear selection", BROWSE_RESET = "Clear conditions",
    BROWSE_VIEW = "List display", BROWSE_ORDER = "Order", BROWSE_NATIVE = "Game order", BROWSE_NAME = "Name",
    BROWSE_SIZE = "Party size", BROWSE_LEVEL_ORDER = "Level", BROWSE_FRIENDS = "Friends and guild first",
    BROWSE_ZONE = "Zone: %s", BROWSE_LEADER_ZONE = "Leader zone: %s", BROWSE_ZONE_UNKNOWN = "Unknown",
    BROWSE_PRESET = "Preset", BROWSE_CUSTOM = "Custom settings", BROWSE_SAVE = "Save preset...", BROWSE_SAVE_OK = "Save",
    BROWSE_CANCEL = "Cancel", BROWSE_REPLACE = "Replace preset?", BROWSE_REPLACE_HINT = "A preset with this name already exists. Click Save again to replace it.",
    BROWSE_PRESET_NAME = "Preset name", BROWSE_BAD_NAME = "Enter a name (up to 40 characters).", BROWSE_PRESET_LIMIT = "Maximum 30 presets. Replace an existing preset.",
    BROWSE_REFRESH = "Refresh", BROWSE_REFRESH_HINT = "Search again with the selected languages.", BROWSE_REFRESH_DIRTY = "Languages changed. Click to apply the selection.",
    BROWSE_NATIVE_REFRESH = "Game search is active. The selected languages are not confirmed.", BROWSE_SEARCH_FAILED = "Search did not complete. Click Refresh to try again.",
    BROWSE_INVITE = "Invite", BROWSE_WRITE = "Write", BROWSE_NO_RIGHTS = "You do not have permission to invite.",
    BROWSE_STALE = "This listing is no longer available.", BROWSE_ACTION_COMBAT = "Available out of combat.", BROWSE_ACTION_UNAVAILABLE = "Action unavailable.",
    BROWSE_ALL_LEVELS="Show activities of all levels", BROWSE_ALL_LEVELS_HINT="Show activities outside your recommended level, including hidden categories. Shared by search and listing creation. Entry requirements still apply; category and activity choices may reset.",
    BROWSE_RECOMMENDED = "Recommended level", BROWSE_LEVEL_ERROR = "Enter positive whole levels; minimum cannot exceed maximum. The previous filter is kept.",
    BROWSE_MISSING = "Missing: %s", BROWSE_AUTO_PAUSED = "Automatic matching paused: party roles unavailable.", BROWSE_OR_ROLES = "Matches any selected role",
    BROWSE_DATA_UNKNOWN = "Data unavailable", BROWSE_COUNT = "%s - %d of %d", BROWSE_GROUPS = "Groups", BROWSE_PLAYERS = "Players",
    BROWSE_EMPTY = "No matching listings. Clear conditions or change filters.", BROWSE_EMPTY_CLASSES = "No classes selected.",
    BROWSE_STYLE_0 = "Not specified", BROWSE_STYLE_1 = "Learning", BROWSE_STYLE_2 = "Relaxed", BROWSE_STYLE_3 = "Serious", BROWSE_STYLE_4 = "Expert",
}
local ru = {
    BROWSE_MODE = "Режим", BROWSE_LANGUAGES = "Языки", BROWSE_STYLE = "Стиль", BROWSE_ANY = "Любая", BROWSE_ANY_STYLE = "Любой",
    BROWSE_GROUP_FILTERS = "Фильтры групп", BROWSE_PLAYER_FILTERS = "Фильтры игроков", BROWSE_FREE_ROLE = "Свободное место:",
    BROWSE_LEVEL = "Уровень", BROWSE_CLASSES = "Классы", BROWSE_ALL_CLASSES = "Все классы", BROWSE_CLASS_COUNT = "Выбрано: %d",
    BROWSE_SELECT_ALL = "Выбрать все", BROWSE_CLEAR = "Снять выбор", BROWSE_RESET = "Снять условия",
    BROWSE_VIEW = "Вид списка", BROWSE_ORDER = "Порядок", BROWSE_NATIVE = "Как в игре", BROWSE_NAME = "По имени",
    BROWSE_SIZE = "По размеру группы", BROWSE_LEVEL_ORDER = "По уровню", BROWSE_FRIENDS = "Друзья и гильдия первыми",
    BROWSE_ZONE = "Зона: %s", BROWSE_LEADER_ZONE = "Зона лидера: %s", BROWSE_ZONE_UNKNOWN = "неизвестна",
    BROWSE_PRESET = "Шаблон", BROWSE_CUSTOM = "Свои настройки", BROWSE_SAVE = "Сохранить шаблон...", BROWSE_SAVE_OK = "Сохранить",
    BROWSE_CANCEL = "Отмена", BROWSE_REPLACE = "Заменить шаблон?", BROWSE_REPLACE_HINT = "Шаблон с таким именем уже есть. Нажмите «Сохранить» ещё раз для замены.",
    BROWSE_PRESET_NAME = "Название шаблона", BROWSE_BAD_NAME = "Введите название (до 40 символов).", BROWSE_PRESET_LIMIT = "Не более 30 шаблонов. Можно заменить существующий.",
    BROWSE_REFRESH = "Обновить", BROWSE_REFRESH_HINT = "Повторить поиск с выбранными языками.", BROWSE_REFRESH_DIRTY = "Языки изменены. Нажмите, чтобы применить выбор.",
    BROWSE_NATIVE_REFRESH = "Работает штатный поиск. Выбранные языки не подтверждены.", BROWSE_SEARCH_FAILED = "Поиск не завершён. Нажмите «Обновить», чтобы повторить.",
    BROWSE_INVITE = "Пригласить", BROWSE_WRITE = "Написать", BROWSE_NO_RIGHTS = "Недостаточно прав для приглашения.",
    BROWSE_STALE = "Объявление больше недоступно.", BROWSE_ACTION_COMBAT = "Доступно вне боя.", BROWSE_ACTION_UNAVAILABLE = "Действие недоступно.",
    BROWSE_ALL_LEVELS="Показывать занятия всех уровней", BROWSE_ALL_LEVELS_HINT="Показывать занятия вне рекомендуемого уровня, включая скрытые категории. Настройка общая для поиска и создания объявления. Требования входа сохраняются; выбор категории и занятий может сброситься.",
    BROWSE_RECOMMENDED = "Рек. ур.", BROWSE_LEVEL_ERROR = "Нужны целые положительные уровни; минимум не может быть выше максимума. Прежний фильтр сохранён.",
    BROWSE_MISSING = "Не хватает: %s", BROWSE_AUTO_PAUSED = "Автоотбор приостановлен: роли группы неизвестны.", BROWSE_OR_ROLES = "Любая из выбранных ролей",
    BROWSE_DATA_UNKNOWN = "Данные не указаны", BROWSE_COUNT = "%s - %d из %d", BROWSE_GROUPS = "Группы", BROWSE_PLAYERS = "Игроки",
    BROWSE_EMPTY = "Нет совпадений. Снимите условия или измените фильтры.", BROWSE_EMPTY_CLASSES = "Не выбраны классы.",
    BROWSE_STYLE_0 = "Не указан", BROWSE_STYLE_1 = "Обучение", BROWSE_STYLE_2 = "Спокойно", BROWSE_STYLE_3 = "Серьёзно", BROWSE_STYLE_4 = "Для опытных",
    ROLE_HEALER = "Лекарь", ROLE_DAMAGE = "Боец",
}
for key, value in pairs(en) do NS.english[key] = value end
if NS.clientLocale == "ruRU" then for key, value in pairs(ru) do NS.translation[key] = value end end
-- Новые подписи переведены независимо от языков поиска; esMX использует esES.
local extra = {
    deDE = {
        BROWSE_MODE="Modus", BROWSE_LANGUAGES="Sprachen", BROWSE_STYLE="Spielstil", BROWSE_ANY="Beliebig", BROWSE_ANY_STYLE="Beliebig",
        BROWSE_GROUP_FILTERS="Gruppenfilter", BROWSE_PLAYER_FILTERS="Spielerfilter", BROWSE_FREE_ROLE="Freier Platz:",
        BROWSE_LEVEL="Stufe", BROWSE_CLASSES="Klassen", BROWSE_ALL_CLASSES="Alle Klassen", BROWSE_CLASS_COUNT="%d gewählt",
        BROWSE_SELECT_ALL="Alle auswählen", BROWSE_CLEAR="Auswahl aufheben", BROWSE_RESET="Bedingungen löschen",
        BROWSE_VIEW="Listenansicht", BROWSE_ORDER="Sortierung", BROWSE_NATIVE="Wie im Spiel", BROWSE_NAME="Nach Name", BROWSE_SIZE="Gruppengröße", BROWSE_LEVEL_ORDER="Nach Stufe",
        BROWSE_FRIENDS="Freunde und Gilde zuerst", BROWSE_ZONE="Gebiet: %s", BROWSE_LEADER_ZONE="Gebiet des Leiters: %s", BROWSE_ZONE_UNKNOWN="Unbekannt",
        BROWSE_PRESET="Vorlage", BROWSE_CUSTOM="Eigene Einstellungen", BROWSE_SAVE="Vorlage speichern...", BROWSE_SAVE_OK="Speichern", BROWSE_CANCEL="Abbrechen",
        BROWSE_REPLACE="Vorlage ersetzen?", BROWSE_REPLACE_HINT="Dieser Name ist bereits vergeben. Klicke erneut auf Speichern, um die Vorlage zu ersetzen.",
        BROWSE_PRESET_NAME="Name der Vorlage", BROWSE_BAD_NAME="Gib einen Namen mit höchstens 40 Zeichen ein.", BROWSE_PRESET_LIMIT="Höchstens 30 Vorlagen. Ersetze eine vorhandene Vorlage.",
        BROWSE_REFRESH="Aktualisieren", BROWSE_REFRESH_HINT="Mit den gewählten Sprachen erneut suchen.", BROWSE_REFRESH_DIRTY="Sprachen geändert. Klicke, um die Auswahl anzuwenden.",
        BROWSE_NATIVE_REFRESH="Die Spielsuche ist aktiv. Gewählte Sprachen sind nicht bestätigt.", BROWSE_SEARCH_FAILED="Suche nicht abgeschlossen. Klicke auf Aktualisieren, um es erneut zu versuchen.",
        BROWSE_INVITE="Einladen", BROWSE_WRITE="Schreiben", BROWSE_NO_RIGHTS="Du darfst keine Spieler einladen.", BROWSE_STALE="Dieser Eintrag ist nicht mehr verfügbar.",
        BROWSE_ACTION_COMBAT="Außerhalb des Kampfes verfügbar.", BROWSE_ACTION_UNAVAILABLE="Aktion nicht verfügbar.", BROWSE_ALL_LEVELS="Aktivitäten aller Stufen anzeigen",
        BROWSE_ALL_LEVELS_HINT="Zeigt Aktivitäten außerhalb der empfohlenen Stufe, auch ausgeblendete Kategorien. Gilt für Suche und eigene Einträge. Zugangsvoraussetzungen bleiben bestehen; die Auswahl kann zurückgesetzt werden.",
        BROWSE_RECOMMENDED="Empf. Stufe", BROWSE_LEVEL_ERROR="Ganze positive Stufen eingeben; das Minimum darf nicht größer als das Maximum sein. Der bisherige Filter bleibt erhalten.",
        BROWSE_MISSING="Es fehlt: %s", BROWSE_AUTO_PAUSED="Automatische Auswahl pausiert: Gruppenrollen unbekannt.", BROWSE_OR_ROLES="Mindestens eine gewählte Rolle passt",
        BROWSE_DATA_UNKNOWN="Daten unbekannt", BROWSE_COUNT="%s - %d von %d", BROWSE_GROUPS="Gruppen", BROWSE_PLAYERS="Spieler",
        BROWSE_EMPTY="Keine Treffer. Bedingungen löschen oder Filter ändern.", BROWSE_EMPTY_CLASSES="Keine Klassen gewählt.",
        BROWSE_STYLE_0="Nicht angegeben", BROWSE_STYLE_1="Lernen", BROWSE_STYLE_2="Entspannt", BROWSE_STYLE_3="Ernsthaft", BROWSE_STYLE_4="Erfahren",
    },
    frFR = {
        BROWSE_MODE="Mode", BROWSE_LANGUAGES="Langues", BROWSE_STYLE="Style", BROWSE_ANY="Tous", BROWSE_ANY_STYLE="Tous",
        BROWSE_GROUP_FILTERS="Filtres des groupes", BROWSE_PLAYER_FILTERS="Filtres des joueurs", BROWSE_FREE_ROLE="Place libre :",
        BROWSE_LEVEL="Niveau", BROWSE_CLASSES="Classes", BROWSE_ALL_CLASSES="Toutes les classes", BROWSE_CLASS_COUNT="%d sélectionnées",
        BROWSE_SELECT_ALL="Tout sélectionner", BROWSE_CLEAR="Tout désélectionner", BROWSE_RESET="Effacer les conditions",
        BROWSE_VIEW="Affichage", BROWSE_ORDER="Tri", BROWSE_NATIVE="Ordre du jeu", BROWSE_NAME="Par nom", BROWSE_SIZE="Taille du groupe", BROWSE_LEVEL_ORDER="Par niveau",
        BROWSE_FRIENDS="Amis et guilde en premier", BROWSE_ZONE="Zone : %s", BROWSE_LEADER_ZONE="Zone du chef : %s", BROWSE_ZONE_UNKNOWN="Inconnue",
        BROWSE_PRESET="Modèle", BROWSE_CUSTOM="Réglages personnels", BROWSE_SAVE="Enregistrer un modèle...", BROWSE_SAVE_OK="Enregistrer", BROWSE_CANCEL="Annuler",
        BROWSE_REPLACE="Remplacer le modèle ?", BROWSE_REPLACE_HINT="Ce nom existe déjà. Cliquez encore sur Enregistrer pour remplacer le modèle.",
        BROWSE_PRESET_NAME="Nom du modèle", BROWSE_BAD_NAME="Saisissez un nom de 40 caractères maximum.", BROWSE_PRESET_LIMIT="30 modèles maximum. Remplacez un modèle existant.",
        BROWSE_REFRESH="Actualiser", BROWSE_REFRESH_HINT="Relancer la recherche avec les langues sélectionnées.", BROWSE_REFRESH_DIRTY="Langues modifiées. Cliquez pour appliquer la sélection.",
        BROWSE_NATIVE_REFRESH="La recherche du jeu est active. Les langues choisies ne sont pas confirmées.", BROWSE_SEARCH_FAILED="Recherche inachevée. Cliquez sur Actualiser pour réessayer.",
        BROWSE_INVITE="Inviter", BROWSE_WRITE="Écrire", BROWSE_NO_RIGHTS="Vous n'avez pas le droit d'inviter.", BROWSE_STALE="Cette annonce n'est plus disponible.",
        BROWSE_ACTION_COMBAT="Disponible hors combat.", BROWSE_ACTION_UNAVAILABLE="Action indisponible.", BROWSE_ALL_LEVELS="Afficher les activités de tous niveaux",
        BROWSE_ALL_LEVELS_HINT="Affiche les activités hors du niveau conseillé, y compris les catégories masquées. Commun à la recherche et à la création d’annonces. Les conditions d’accès restent applicables ; la sélection peut être réinitialisée.",
        BROWSE_RECOMMENDED="Niv. conseillé", BROWSE_LEVEL_ERROR="Saisissez des niveaux entiers positifs ; le minimum ne peut pas dépasser le maximum. Le filtre précédent est conservé.",
        BROWSE_MISSING="Il manque : %s", BROWSE_AUTO_PAUSED="Sélection automatique suspendue : rôles du groupe inconnus.", BROWSE_OR_ROLES="Au moins un des rôles choisis",
        BROWSE_DATA_UNKNOWN="Données inconnues", BROWSE_COUNT="%s - %d sur %d", BROWSE_GROUPS="Groupes", BROWSE_PLAYERS="Joueurs",
        BROWSE_EMPTY="Aucun résultat. Effacez les conditions ou modifiez les filtres.", BROWSE_EMPTY_CLASSES="Aucune classe sélectionnée.",
        BROWSE_STYLE_0="Non précisé", BROWSE_STYLE_1="Apprentissage", BROWSE_STYLE_2="Détendu", BROWSE_STYLE_3="Sérieux", BROWSE_STYLE_4="Expert",
    },
    esES = {
        BROWSE_MODE="Modo", BROWSE_LANGUAGES="Idiomas", BROWSE_STYLE="Estilo", BROWSE_ANY="Cualquiera", BROWSE_ANY_STYLE="Cualquiera",
        BROWSE_GROUP_FILTERS="Filtros de grupos", BROWSE_PLAYER_FILTERS="Filtros de jugadores", BROWSE_FREE_ROLE="Plaza libre:",
        BROWSE_LEVEL="Nivel", BROWSE_CLASSES="Clases", BROWSE_ALL_CLASSES="Todas las clases", BROWSE_CLASS_COUNT="%d seleccionadas",
        BROWSE_SELECT_ALL="Seleccionar todas", BROWSE_CLEAR="Borrar selección", BROWSE_RESET="Quitar condiciones",
        BROWSE_VIEW="Vista de lista", BROWSE_ORDER="Orden", BROWSE_NATIVE="Como en el juego", BROWSE_NAME="Por nombre", BROWSE_SIZE="Tamaño del grupo", BROWSE_LEVEL_ORDER="Por nivel",
        BROWSE_FRIENDS="Amigos y hermandad primero", BROWSE_ZONE="Zona: %s", BROWSE_LEADER_ZONE="Zona del líder: %s", BROWSE_ZONE_UNKNOWN="Desconocida",
        BROWSE_PRESET="Plantilla", BROWSE_CUSTOM="Ajustes propios", BROWSE_SAVE="Guardar plantilla...", BROWSE_SAVE_OK="Guardar", BROWSE_CANCEL="Cancelar",
        BROWSE_REPLACE="¿Reemplazar plantilla?", BROWSE_REPLACE_HINT="Ya existe este nombre. Pulsa Guardar otra vez para reemplazar la plantilla.",
        BROWSE_PRESET_NAME="Nombre de plantilla", BROWSE_BAD_NAME="Introduce un nombre de hasta 40 caracteres.", BROWSE_PRESET_LIMIT="Máximo 30 plantillas. Reemplaza una existente.",
        BROWSE_REFRESH="Actualizar", BROWSE_REFRESH_HINT="Repetir búsqueda con los idiomas seleccionados.", BROWSE_REFRESH_DIRTY="Idiomas cambiados. Pulsa para aplicar la selección.",
        BROWSE_NATIVE_REFRESH="Está activa la búsqueda del juego. Los idiomas elegidos no están confirmados.", BROWSE_SEARCH_FAILED="La búsqueda no se completó. Pulsa Actualizar para volver a intentarlo.",
        BROWSE_INVITE="Invitar", BROWSE_WRITE="Escribir", BROWSE_NO_RIGHTS="No tienes permiso para invitar.", BROWSE_STALE="Este anuncio ya no está disponible.",
        BROWSE_ACTION_COMBAT="Disponible fuera de combate.", BROWSE_ACTION_UNAVAILABLE="Acción no disponible.", BROWSE_ALL_LEVELS="Mostrar actividades de todos los niveles",
        BROWSE_ALL_LEVELS_HINT="Muestra actividades fuera del nivel recomendado, incluidas las categorías ocultas. Se comparte entre la búsqueda y la creación de anuncios. Se mantienen los requisitos de acceso; la selección puede restablecerse.",
        BROWSE_RECOMMENDED="Nivel recom.", BROWSE_LEVEL_ERROR="Introduce niveles enteros positivos; el mínimo no puede superar el máximo. Se conserva el filtro anterior.",
        BROWSE_MISSING="Falta: %s", BROWSE_AUTO_PAUSED="Selección automática pausada: roles del grupo desconocidos.", BROWSE_OR_ROLES="Cualquiera de los roles elegidos",
        BROWSE_DATA_UNKNOWN="Datos desconocidos", BROWSE_COUNT="%s - %d de %d", BROWSE_GROUPS="Grupos", BROWSE_PLAYERS="Jugadores",
        BROWSE_EMPTY="No hay coincidencias. Quita condiciones o cambia los filtros.", BROWSE_EMPTY_CLASSES="No se han seleccionado clases.",
        BROWSE_STYLE_0="Sin especificar", BROWSE_STYLE_1="Aprendizaje", BROWSE_STYLE_2="Relajado", BROWSE_STYLE_3="Serio", BROWSE_STYLE_4="Experto",
    },
    zhCN = {
        BROWSE_MODE="模式", BROWSE_LANGUAGES="语言", BROWSE_STYLE="风格", BROWSE_ANY="不限", BROWSE_ANY_STYLE="不限",
        BROWSE_GROUP_FILTERS="队伍筛选", BROWSE_PLAYER_FILTERS="玩家筛选", BROWSE_FREE_ROLE="空缺职责：",
        BROWSE_LEVEL="等级", BROWSE_CLASSES="职业", BROWSE_ALL_CLASSES="所有职业", BROWSE_CLASS_COUNT="已选 %d 项",
        BROWSE_SELECT_ALL="全部选择", BROWSE_CLEAR="清除选择", BROWSE_RESET="清除条件",
        BROWSE_VIEW="列表显示", BROWSE_ORDER="排序", BROWSE_NATIVE="游戏默认", BROWSE_NAME="按名称", BROWSE_SIZE="按队伍人数", BROWSE_LEVEL_ORDER="按等级",
        BROWSE_FRIENDS="好友和公会成员优先", BROWSE_ZONE="区域：%s", BROWSE_LEADER_ZONE="队长区域：%s", BROWSE_ZONE_UNKNOWN="未知",
        BROWSE_PRESET="预设", BROWSE_CUSTOM="自定义设置", BROWSE_SAVE="保存预设...", BROWSE_SAVE_OK="保存", BROWSE_CANCEL="取消",
        BROWSE_REPLACE="替换预设？", BROWSE_REPLACE_HINT="此名称已存在。再次点击保存以替换预设。",
        BROWSE_PRESET_NAME="预设名称", BROWSE_BAD_NAME="请输入不超过40个字符的名称。", BROWSE_PRESET_LIMIT="最多保存30个预设。请替换已有预设。",
        BROWSE_REFRESH="刷新", BROWSE_REFRESH_HINT="使用所选语言重新搜索。", BROWSE_REFRESH_DIRTY="语言已更改。点击应用选择。",
        BROWSE_NATIVE_REFRESH="正在使用游戏搜索。所选语言尚未确认。", BROWSE_SEARCH_FAILED="搜索未完成。点击刷新以重试。",
        BROWSE_INVITE="邀请", BROWSE_WRITE="密语", BROWSE_NO_RIGHTS="你没有邀请权限。", BROWSE_STALE="此招募已不可用。",
        BROWSE_ACTION_COMBAT="脱离战斗后可用。", BROWSE_ACTION_UNAVAILABLE="操作不可用。", BROWSE_ALL_LEVELS="显示所有等级的活动",
        BROWSE_ALL_LEVELS_HINT="显示推荐等级范围外的活动，包括隐藏的类别。搜索与创建招募共用此设置。进入条件仍然有效；类别和活动选择可能被重置。",
        BROWSE_RECOMMENDED="推荐等级", BROWSE_LEVEL_ERROR="请输入正整数等级；最低等级不能高于最高等级。保留之前的筛选条件。",
        BROWSE_MISSING="缺少：%s", BROWSE_AUTO_PAUSED="自动匹配已暂停：队伍职责未知。", BROWSE_OR_ROLES="匹配任一所选职责",
        BROWSE_DATA_UNKNOWN="资料未知", BROWSE_COUNT="%s - %d / %d", BROWSE_GROUPS="队伍", BROWSE_PLAYERS="玩家",
        BROWSE_EMPTY="没有匹配结果。请清除条件或修改筛选。", BROWSE_EMPTY_CLASSES="未选择职业。",
        BROWSE_STYLE_0="未指定", BROWSE_STYLE_1="学习", BROWSE_STYLE_2="休闲", BROWSE_STYLE_3="认真", BROWSE_STYLE_4="精通",
    },
    zhTW = {
        BROWSE_MODE="模式", BROWSE_LANGUAGES="語言", BROWSE_STYLE="風格", BROWSE_ANY="不限", BROWSE_ANY_STYLE="不限",
        BROWSE_GROUP_FILTERS="隊伍篩選", BROWSE_PLAYER_FILTERS="玩家篩選", BROWSE_FREE_ROLE="空缺職責：",
        BROWSE_LEVEL="等級", BROWSE_CLASSES="職業", BROWSE_ALL_CLASSES="所有職業", BROWSE_CLASS_COUNT="已選 %d 項",
        BROWSE_SELECT_ALL="全部選擇", BROWSE_CLEAR="清除選擇", BROWSE_RESET="清除條件",
        BROWSE_VIEW="清單顯示", BROWSE_ORDER="排序", BROWSE_NATIVE="遊戲預設", BROWSE_NAME="依名稱", BROWSE_SIZE="依隊伍人數", BROWSE_LEVEL_ORDER="依等級",
        BROWSE_FRIENDS="好友和公會成員優先", BROWSE_ZONE="區域：%s", BROWSE_LEADER_ZONE="隊長區域：%s", BROWSE_ZONE_UNKNOWN="未知",
        BROWSE_PRESET="預設", BROWSE_CUSTOM="自訂設定", BROWSE_SAVE="儲存預設...", BROWSE_SAVE_OK="儲存", BROWSE_CANCEL="取消",
        BROWSE_REPLACE="取代預設？", BROWSE_REPLACE_HINT="此名稱已存在。再次點擊儲存以取代預設。",
        BROWSE_PRESET_NAME="預設名稱", BROWSE_BAD_NAME="請輸入不超過40個字元的名稱。", BROWSE_PRESET_LIMIT="最多儲存30個預設。請取代現有預設。",
        BROWSE_REFRESH="重新整理", BROWSE_REFRESH_HINT="使用所選語言重新搜尋。", BROWSE_REFRESH_DIRTY="語言已變更。點擊套用選擇。",
        BROWSE_NATIVE_REFRESH="正在使用遊戲搜尋。所選語言尚未確認。", BROWSE_SEARCH_FAILED="搜尋未完成。點擊重新整理以重試。",
        BROWSE_INVITE="邀請", BROWSE_WRITE="密語", BROWSE_NO_RIGHTS="你沒有邀請權限。", BROWSE_STALE="此招募已無法使用。",
        BROWSE_ACTION_COMBAT="脫離戰鬥後可用。", BROWSE_ACTION_UNAVAILABLE="無法執行此操作。", BROWSE_ALL_LEVELS="顯示所有等級的活動",
        BROWSE_ALL_LEVELS_HINT="顯示建議等級範圍外的活動，包括隱藏的類別。搜尋與建立招募共用此設定。進入條件仍然有效；類別和活動選擇可能會重設。",
        BROWSE_RECOMMENDED="建議等級", BROWSE_LEVEL_ERROR="請輸入正整數等級；最低等級不能高於最高等級。保留原有篩選條件。",
        BROWSE_MISSING="缺少：%s", BROWSE_AUTO_PAUSED="自動配對已暫停：隊伍職責未知。", BROWSE_OR_ROLES="符合任一所選職責",
        BROWSE_DATA_UNKNOWN="資料未知", BROWSE_COUNT="%s - %d / %d", BROWSE_GROUPS="隊伍", BROWSE_PLAYERS="玩家",
        BROWSE_EMPTY="沒有符合的結果。請清除條件或修改篩選。", BROWSE_EMPTY_CLASSES="未選擇職業。",
        BROWSE_STYLE_0="未指定", BROWSE_STYLE_1="學習", BROWSE_STYLE_2="休閒", BROWSE_STYLE_3="認真", BROWSE_STYLE_4="熟練",
    },
}
local translated = extra[NS.clientLocale == "esMX" and "esES" or NS.clientLocale]
if translated then for key, value in pairs(translated) do NS.translation[key] = value end end
local compact = {
    enUS={BROWSE_AUTO_PARTY="By party composition",BROWSE_ROLE_MANUAL="Choosing a role turns off Auto",BROWSE_IMMEDIATE="Instant",BROWSE_PAUSED="Paused"},
    ruRU={BROWSE_AUTO_PARTY="По составу группы",BROWSE_ROLE_MANUAL="Выбор роли отключит авто",BROWSE_IMMEDIATE="Сразу",BROWSE_PAUSED="Пауза"},
    deDE={BROWSE_AUTO_PARTY="Nach Gruppenrollen",BROWSE_ROLE_MANUAL="Rollenwahl schaltet Auto aus",BROWSE_IMMEDIATE="Sofort",BROWSE_PAUSED="Pausiert"},
    frFR={BROWSE_AUTO_PARTY="Selon le groupe",BROWSE_ROLE_MANUAL="Choisir un rôle désactive Auto",BROWSE_IMMEDIATE="Immédiat",BROWSE_PAUSED="En pause"},
    esES={BROWSE_AUTO_PARTY="Según el grupo",BROWSE_ROLE_MANUAL="Elegir un rol desactiva Auto",BROWSE_IMMEDIATE="Al instante",BROWSE_PAUSED="En pausa"},
    zhCN={BROWSE_AUTO_PARTY="按队伍配置",BROWSE_ROLE_MANUAL="选择职责将关闭自动匹配",BROWSE_IMMEDIATE="即时",BROWSE_PAUSED="已暂停"},
    zhTW={BROWSE_AUTO_PARTY="依隊伍配置",BROWSE_ROLE_MANUAL="選擇職責會關閉自動配對",BROWSE_IMMEDIATE="即時",BROWSE_PAUSED="已暫停"},
}
for key,value in pairs(compact.enUS) do NS.english[key]=value end
local labels=compact[NS.clientLocale=="esMX" and "esES" or NS.clientLocale]
if labels and NS.translation then for key,value in pairs(labels) do NS.translation[key]=value end end

-- Ручной фильтр вакансий не зависит от автоотбора по собственной группе.
local seekRoles = {
    enUS = {
        BROWSE_SEEK_ROLE="Group needs:", BROWSE_SEEK_ANY="All groups, without a role filter.",
        BROWSE_SEEK_TANK="A tank slot is open.", BROWSE_SEEK_HEALER="A healer slot is open.", BROWSE_SEEK_DAMAGER="A damage slot is open.",
        BROWSE_SEEK_MULTIPLE="A slot for any selected role.",
        BROWSE_SEEK_HELP_ANY="Show all groups, regardless of open roles. Other filters still apply.",
        BROWSE_SEEK_HELP_TANK="Show groups with a tank slot open. In a standard dungeon party, this means no tank yet.",
        BROWSE_SEEK_HELP_HEALER="Show groups with a healer slot open. In a standard dungeon party, this means no healer yet.",
        BROWSE_SEEK_HELP_DAMAGER="Show groups with at least one damage slot open, even if they already have damage dealers.",
    },
    ruRU = {
        BROWSE_SEEK_ROLE="Группе нужен:", BROWSE_SEEK_ANY="Все группы, без отбора по роли.",
        BROWSE_SEEK_TANK="Есть место для танка.", BROWSE_SEEK_HEALER="Есть место для лекаря.", BROWSE_SEEK_DAMAGER="Есть место для бойца.",
        BROWSE_SEEK_MULTIPLE="Нужна любая из выбранных ролей.",
        BROWSE_SEEK_HELP_ANY="Показывать все группы независимо от свободных ролей. Остальные фильтры сохраняются.",
        BROWSE_SEEK_HELP_TANK="Показывать группы со свободным местом для танка. В обычной группе подземелья это группы без танка.",
        BROWSE_SEEK_HELP_HEALER="Показывать группы со свободным местом для лекаря. В обычной группе подземелья это группы без лекаря.",
        BROWSE_SEEK_HELP_DAMAGER="Показывать группы хотя бы с одним свободным местом для бойца, даже если другие бойцы уже есть.",
    },
    deDE = {
        BROWSE_SEEK_ROLE="Gruppe sucht:", BROWSE_SEEK_ANY="Alle Gruppen, ohne Rollenfilter.",
        BROWSE_SEEK_TANK="Ein Tankplatz ist frei.", BROWSE_SEEK_HEALER="Ein Heilerplatz ist frei.", BROWSE_SEEK_DAMAGER="Ein Schadensplatz ist frei.",
        BROWSE_SEEK_MULTIPLE="Platz für eine der gewählten Rollen.",
        BROWSE_SEEK_HELP_ANY="Alle Gruppen unabhängig von freien Rollen anzeigen. Andere Filter gelten weiterhin.",
        BROWSE_SEEK_HELP_TANK="Gruppen mit freiem Tankplatz anzeigen. In einer normalen Dungeongruppe fehlt dann noch der Tank.",
        BROWSE_SEEK_HELP_HEALER="Gruppen mit freiem Heilerplatz anzeigen. In einer normalen Dungeongruppe fehlt dann noch der Heiler.",
        BROWSE_SEEK_HELP_DAMAGER="Gruppen mit mindestens einem freien Schadensplatz anzeigen, auch wenn bereits Schadensklassen dabei sind.",
    },
    frFR = {
        BROWSE_SEEK_ROLE="Le groupe cherche :", BROWSE_SEEK_ANY="Tous les groupes, sans filtre de rôle.",
        BROWSE_SEEK_TANK="Une place de tank est libre.", BROWSE_SEEK_HEALER="Une place de soigneur est libre.", BROWSE_SEEK_DAMAGER="Une place de dégâts est libre.",
        BROWSE_SEEK_MULTIPLE="Une place pour l'un des rôles choisis.",
        BROWSE_SEEK_HELP_ANY="Afficher tous les groupes, quels que soient les rôles libres. Les autres filtres restent actifs.",
        BROWSE_SEEK_HELP_TANK="Afficher les groupes avec une place de tank libre. Dans un groupe de donjon standard, le tank manque encore.",
        BROWSE_SEEK_HELP_HEALER="Afficher les groupes avec une place de soigneur libre. Dans un groupe de donjon standard, le soigneur manque encore.",
        BROWSE_SEEK_HELP_DAMAGER="Afficher les groupes avec au moins une place de dégâts libre, même s'ils ont déjà des personnages de dégâts.",
    },
    esES = {
        BROWSE_SEEK_ROLE="El grupo busca:", BROWSE_SEEK_ANY="Todos los grupos, sin filtro de rol.",
        BROWSE_SEEK_TANK="Hay plaza para tanque.", BROWSE_SEEK_HEALER="Hay plaza para sanador.", BROWSE_SEEK_DAMAGER="Hay plaza para daño.",
        BROWSE_SEEK_MULTIPLE="Plaza para uno de los roles elegidos.",
        BROWSE_SEEK_HELP_ANY="Mostrar todos los grupos sin importar los roles libres. Los demás filtros siguen activos.",
        BROWSE_SEEK_HELP_TANK="Mostrar grupos con plaza de tanque libre. En un grupo de mazmorra normal, aún no hay tanque.",
        BROWSE_SEEK_HELP_HEALER="Mostrar grupos con plaza de sanador libre. En un grupo de mazmorra normal, aún no hay sanador.",
        BROWSE_SEEK_HELP_DAMAGER="Mostrar grupos con al menos una plaza de daño libre, aunque ya tengan otros personajes de daño.",
    },
    zhCN = {
        BROWSE_SEEK_ROLE="队伍需要：", BROWSE_SEEK_ANY="显示所有队伍，不按职责筛选。",
        BROWSE_SEEK_TANK="有坦克空位。", BROWSE_SEEK_HEALER="有治疗空位。", BROWSE_SEEK_DAMAGER="有输出空位。",
        BROWSE_SEEK_MULTIPLE="任一所选职责有空位即可。",
        BROWSE_SEEK_HELP_ANY="显示所有队伍，不考虑职责空位。其他筛选条件仍然生效。",
        BROWSE_SEEK_HELP_TANK="显示有坦克空位的队伍。对标准地下城小队而言，表示队伍尚无坦克。",
        BROWSE_SEEK_HELP_HEALER="显示有治疗空位的队伍。对标准地下城小队而言，表示队伍尚无治疗。",
        BROWSE_SEEK_HELP_DAMAGER="显示至少有一个输出空位的队伍，即使队伍已有其他输出。",
    },
    zhTW = {
        BROWSE_SEEK_ROLE="隊伍需要：", BROWSE_SEEK_ANY="顯示所有隊伍，不依職責篩選。",
        BROWSE_SEEK_TANK="有坦克空位。", BROWSE_SEEK_HEALER="有治療空位。", BROWSE_SEEK_DAMAGER="有輸出空位。",
        BROWSE_SEEK_MULTIPLE="任一所選職責有空位即可。",
        BROWSE_SEEK_HELP_ANY="顯示所有隊伍，不考慮職責空位。其他篩選條件仍然生效。",
        BROWSE_SEEK_HELP_TANK="顯示有坦克空位的隊伍。對標準地城小隊而言，表示隊伍尚無坦克。",
        BROWSE_SEEK_HELP_HEALER="顯示有治療空位的隊伍。對標準地城小隊而言，表示隊伍尚無治療。",
        BROWSE_SEEK_HELP_DAMAGER="顯示至少有一個輸出空位的隊伍，即使隊伍已有其他輸出。",
    },
}
for key, value in pairs(seekRoles.enUS) do NS.english[key] = value end
local seekLabels = seekRoles[NS.clientLocale == "esMX" and "esES" or NS.clientLocale]
if seekLabels and NS.translation then for key, value in pairs(seekLabels) do NS.translation[key] = value end end

-- Явная галочка находится под выбором категории и занятий.
local activityOptions={
    enUS={BROWSE_LEVELS_HIDDEN_HINT="Some activities are hidden by your level.\nEnable all levels below the activity selectors."},
    ruRU={BROWSE_LEVELS_HIDDEN_HINT="Часть занятий скрыта из-за вашего уровня.\nВключите показ всех уровней под выбором занятий."},
    deDE={BROWSE_LEVELS_HIDDEN_HINT="Einige Aktivitäten sind wegen deiner Stufe ausgeblendet.\nAktiviere alle Stufen unter der Aktivitätsauswahl."},
    frFR={BROWSE_LEVELS_HIDDEN_HINT="Certaines activités sont masquées à cause de votre niveau.\nActivez tous les niveaux sous les sélecteurs d’activités."},
    esES={BROWSE_LEVELS_HIDDEN_HINT="Algunas actividades están ocultas por tu nivel.\nActiva todos los niveles debajo de los selectores de actividades."},
    zhCN={BROWSE_LEVELS_HIDDEN_HINT="部分活动因您的等级而隐藏。\n请在活动选择栏下方启用所有等级。"},
    zhTW={BROWSE_LEVELS_HIDDEN_HINT="部分活動因您的等級而隱藏。\n請在活動選擇列下方啟用所有等級。"},
    koKR={BROWSE_LEVELS_HIDDEN_HINT="레벨 때문에 일부 활동이 숨겨져 있습니다.\n활동 선택 아래에서 모든 레벨 표시를 켜세요."},
    ptBR={BROWSE_LEVELS_HIDDEN_HINT="Algumas atividades estão ocultas pelo seu nível.\nAtive todos os níveis abaixo dos seletores de atividades."},
    itIT={BROWSE_LEVELS_HIDDEN_HINT="Alcune attività sono nascoste a causa del tuo livello.\nAttiva tutti i livelli sotto i selettori delle attività."},
}
for key,value in pairs(activityOptions.enUS) do NS.english[key]=value end
local activityLabels=activityOptions[NS.clientLocale=="esMX" and "esES" or NS.clientLocale]
if activityLabels and NS.translation then for key,value in pairs(activityLabels) do NS.translation[key]=value end end

local levelHelp={
    enUS={
        BROWSE_LEVEL_MIN="Minimum player level", BROWSE_LEVEL_MAX="Maximum player level",
        BROWSE_LEVEL_HELP="Left: minimum player level. Right: maximum. Both limits are inclusive.\nAn empty field leaves that side unrestricted. Both empty: no level filter.\nExample: 20 and blank means level 20 or higher.\nEnter or leaving the field applies the filter. Tab switches fields.",
    },
    ruRU={
        BROWSE_LEVEL_MIN="Минимальный уровень игрока", BROWSE_LEVEL_MAX="Максимальный уровень игрока",
        BROWSE_LEVEL_HELP="Слева — минимальный уровень игрока, справа — максимальный. Границы включены.\nПустое поле снимает ограничение с этой стороны. Оба пустые — без отбора по уровню.\nПример: 20 и пусто — от 20-го уровня.\nEnter или выход из поля применяет фильтр. Tab переключает поля.",
    },
    deDE={
        BROWSE_LEVEL_MIN="Mindeststufe der Spieler", BROWSE_LEVEL_MAX="Höchststufe der Spieler",
        BROWSE_LEVEL_HELP="Links: Mindeststufe der Spieler. Rechts: Höchststufe. Beide Grenzen sind eingeschlossen.\nEin leeres Feld hebt die Begrenzung dieser Seite auf. Beide leer: kein Stufenfilter.\nBeispiel: 20 und leer bedeutet Stufe 20 oder höher.\nEnter oder das Verlassen des Felds wendet den Filter an. Tab wechselt zwischen den Feldern.",
    },
    frFR={
        BROWSE_LEVEL_MIN="Niveau minimum des joueurs", BROWSE_LEVEL_MAX="Niveau maximum des joueurs",
        BROWSE_LEVEL_HELP="À gauche : niveau minimum des joueurs. À droite : maximum. Les deux limites sont incluses.\nUn champ vide enlève la limite de ce côté. Les deux vides : aucun filtre de niveau.\nExemple : 20 puis un champ vide signifie niveau 20 ou plus.\nEntrée ou quitter le champ applique le filtre. Tab passe d’un champ à l’autre.",
    },
    esES={
        BROWSE_LEVEL_MIN="Nivel mínimo de los jugadores", BROWSE_LEVEL_MAX="Nivel máximo de los jugadores",
        BROWSE_LEVEL_HELP="Izquierda: nivel mínimo de los jugadores. Derecha: máximo. Ambos límites están incluidos.\nUn campo vacío elimina el límite de ese lado. Ambos vacíos: sin filtro de nivel.\nEjemplo: 20 y vacío significa nivel 20 o superior.\nIntro o salir del campo aplica el filtro. Tab cambia de campo.",
    },
    zhCN={
        BROWSE_LEVEL_MIN="玩家最低等级", BROWSE_LEVEL_MAX="玩家最高等级",
        BROWSE_LEVEL_HELP="左侧为玩家最低等级，右侧为最高等级，包含上下限。\n留空表示该侧不设限制。两项都为空时，不按等级筛选。\n例如：左侧填20，右侧留空，表示20级及以上。\n按回车或离开输入框即可应用筛选。Tab可切换输入框。",
    },
    zhTW={
        BROWSE_LEVEL_MIN="玩家最低等級", BROWSE_LEVEL_MAX="玩家最高等級",
        BROWSE_LEVEL_HELP="左側為玩家最低等級，右側為最高等級，包含上下限。\n留空表示該側不設限制。兩項皆空時，不依等級篩選。\n例如：左側填20，右側留空，表示20級及以上。\n按Enter或離開輸入欄即可套用篩選。Tab可切換輸入欄。",
    },
    koKR={
        BROWSE_LEVEL_MIN="플레이어 최소 레벨", BROWSE_LEVEL_MAX="플레이어 최대 레벨",
        BROWSE_LEVEL_HELP="왼쪽은 플레이어 최소 레벨, 오른쪽은 최대 레벨이며 두 경계를 포함합니다.\n비워 둔 쪽은 제한하지 않습니다. 둘 다 비우면 레벨로 필터링하지 않습니다.\n예: 왼쪽에 20을 입력하고 오른쪽을 비우면 20레벨 이상입니다.\nEnter를 누르거나 입력란을 벗어나면 적용됩니다. Tab으로 입력란을 전환합니다.",
    },
    ptBR={
        BROWSE_LEVEL_MIN="Nível mínimo dos jogadores", BROWSE_LEVEL_MAX="Nível máximo dos jogadores",
        BROWSE_LEVEL_HELP="À esquerda: nível mínimo dos jogadores. À direita: máximo. Os dois limites são incluídos.\nUm campo vazio remove o limite desse lado. Ambos vazios: sem filtro de nível.\nExemplo: 20 e vazio significa nível 20 ou superior.\nEnter ou sair do campo aplica o filtro. Tab alterna entre os campos.",
    },
    itIT={
        BROWSE_LEVEL_MIN="Livello minimo dei giocatori", BROWSE_LEVEL_MAX="Livello massimo dei giocatori",
        BROWSE_LEVEL_HELP="A sinistra: livello minimo dei giocatori. A destra: massimo. Entrambi i limiti sono inclusi.\nUn campo vuoto rimuove il limite da quel lato. Entrambi vuoti: nessun filtro di livello.\nEsempio: 20 e vuoto significa livello 20 o superiore.\nInvio o uscire dal campo applica il filtro. Tab cambia campo.",
    },
}
for key,value in pairs(levelHelp.enUS) do NS.english[key]=value end
local levelLabels=levelHelp[NS.clientLocale=="esMX" and "esES" or NS.clientLocale]
if levelLabels and NS.translation then for key,value in pairs(levelLabels) do NS.translation[key]=value end end
