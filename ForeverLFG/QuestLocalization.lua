-- ForeverLFG quest and diagnostics UI translations.
local _, NS = ...
local strings = {
    enUS = {
        QUEST_SETTINGS_SECTION = "Partners for group and elite quests",
        QUEST_SETTINGS_DESCRIPTION = "Find players in your zone with the same quests and team up.",
        QUEST_DEBUG_ON = "Quest debug enabled: all active unfinished quests are shared. Saved for this character.",
        QUEST_DEBUG_OFF = "Normal quest mode: only group and elite quests are shared.",
        QUEST_DEBUG_USAGE = "Usage: /flfg debug q 1 - all quests; /flfg debug q 0 - group and elite quests.",
        QUEST_OPEN_MATCHES = "Partners for group and elite quests",
        CHANNEL_TITLE = "ForeverLFG - ChannelBus",
        CHANNEL_FILTER_ALL = "All",
        CHANNEL_FILTER_QUESTS = "Quests",
        CHANNEL_FILTER_TRADE = "Trade",
        CHANNEL_FILTER_MATCHES = "Matches",
        QUEST_WRITE = "Write",
        QUEST_INVITE = "Invite",
        CHANNEL_CLEAR = "Clear log",
        CHANNEL_NEWEST = "Newest",
        CHANNEL_READY = "Connected",
        CHANNEL_JOINING = "Joining channel...",
        CHANNEL_UNAVAILABLE = "Exchange unavailable",
        CHANNEL_RECORDS = "Records: %d",
        CHANNEL_SCROLL_HINT = "Mouse wheel: scroll",
        QUEST_GROUP = "Party: %d",
        QUEST_SOLO = "Solo",
        QUEST_PLAYER = "Level %d : %s",
        CHANNEL_SENT = "Sent",
        CHANNEL_RECEIVED = "Received",
        CHANNEL_ERROR = "Error",
        CHANNEL_SELF = "You",
        QUEST_NO_MATCHES = "No shared quests yet. Checking party and raid members, plus data from other addon users.",
        CHANNEL_EMPTY = "No messages yet. Trade appears when a compatible addon sends trade data.",
        QUEST_FOUND = "Shared group quest",
        QUEST_FOUND_TEXT = "%s has the same active quest: %s.",
    },
    ruRU = {
        QUEST_SETTINGS_SECTION = "Напарники для групповых и элитных заданий",
        QUEST_SETTINGS_DESCRIPTION = "Найдите игроков с такими же заданиями в вашей зоне и объединитесь в группу.",
        QUEST_DEBUG_ON = "Отладка заданий включена: передаются все активные незавершённые задания. Режим сохранён для этого персонажа.",
        QUEST_DEBUG_OFF = "Обычный режим заданий: передаются только групповые и элитные задания.",
        QUEST_DEBUG_USAGE = "Команды: /flfg debug q 1 — все задания; /flfg debug q 0 — групповые и элитные.",
        QUEST_OPEN_MATCHES = "Напарники для групповых и элитных заданий",
        CHANNEL_TITLE = "ForeverLFG — ChannelBus",
        CHANNEL_FILTER_ALL = "Все",
        CHANNEL_FILTER_QUESTS = "Квесты",
        CHANNEL_FILTER_TRADE = "Торговля",
        CHANNEL_FILTER_MATCHES = "Совпадения",
        QUEST_WRITE = "Написать",
        QUEST_INVITE = "Пригласить",
        CHANNEL_CLEAR = "Очистить журнал",
        CHANNEL_NEWEST = "Новые",
        CHANNEL_READY = "Подключено",
        CHANNEL_JOINING = "Подключение к каналу…",
        CHANNEL_UNAVAILABLE = "Обмен недоступен",
        CHANNEL_RECORDS = "Записей: %d",
        CHANNEL_SCROLL_HINT = "Колесо мыши: прокрутка",
        QUEST_GROUP = "Группа: %d",
        QUEST_SOLO = "Соло",
        QUEST_PLAYER = "Уровень %d - %s",
        CHANNEL_SENT = "Отправлено",
        CHANNEL_RECEIVED = "Получено",
        CHANNEL_ERROR = "Ошибка",
        CHANNEL_SELF = "Вы",
        QUEST_NO_MATCHES = "Совпадений пока нет. Проверяем группу и рейд, а также данные от других пользователей аддона.",
        CHANNEL_EMPTY = "Сообщений пока нет. Торговля появится, когда совместимый аддон передаст торговые данные.",
        QUEST_FOUND = "Общий групповой квест",
        QUEST_FOUND_TEXT = "У %s есть такое же активное задание: %s.",
    },
    deDE = {
        QUEST_SETTINGS_SECTION = "Mitspieler für Gruppen- und Elitequests",
        QUEST_SETTINGS_DESCRIPTION = "Finde Spieler mit denselben Quests in deiner Zone und bilde eine Gruppe.",
        QUEST_DEBUG_ON = "Questdebug aktiviert: Alle aktiven, unvollständigen Quests werden geteilt. Für diesen Charakter gespeichert.",
        QUEST_DEBUG_OFF = "Normaler Questmodus: Nur Gruppen- und Elitequests werden geteilt.",
        QUEST_DEBUG_USAGE = "Befehle: /flfg debug q 1 - alle Quests; /flfg debug q 0 - Gruppen- und Elitequests.",
        QUEST_OPEN_MATCHES = "Mitspieler für Gruppen- und Elitequests",
        CHANNEL_TITLE = "ForeverLFG — ChannelBus",
        CHANNEL_FILTER_ALL = "Alle",
        CHANNEL_FILTER_QUESTS = "Quests",
        CHANNEL_FILTER_TRADE = "Handel",
        CHANNEL_FILTER_MATCHES = "Treffer",
        QUEST_WRITE = "Schreiben",
        QUEST_INVITE = "Einladen",
        CHANNEL_CLEAR = "Protokoll leeren",
        CHANNEL_NEWEST = "Neueste",
        CHANNEL_READY = "Verbunden",
        CHANNEL_JOINING = "Kanal wird betreten…",
        CHANNEL_UNAVAILABLE = "Austausch nicht verfügbar",
        CHANNEL_RECORDS = "Einträge: %d",
        CHANNEL_SCROLL_HINT = "Mausrad: scrollen",
        QUEST_GROUP = "Gruppe: %d",
        QUEST_SOLO = "Solo",
        QUEST_PLAYER = "Stufe %d - %s",
        CHANNEL_SENT = "Gesendet",
        CHANNEL_RECEIVED = "Empfangen",
        CHANNEL_ERROR = "Fehler",
        CHANNEL_SELF = "Du",
        QUEST_NO_MATCHES = "Noch keine gemeinsamen Quests. Gruppen- und Schlachtzugsmitglieder sowie Daten anderer Addon-Nutzer werden geprüft.",
        CHANNEL_EMPTY = "Noch keine Nachrichten. Handel erscheint, wenn ein kompatibles Addon Handelsdaten sendet.",
        QUEST_FOUND = "Gemeinsame Gruppenquest",
        QUEST_FOUND_TEXT = "%s hat dieselbe aktive Quest: %s.",
    },
    frFR = {
        QUEST_SETTINGS_SECTION = "Partenaires pour les quêtes de groupe et d’élite",
        QUEST_SETTINGS_DESCRIPTION = "Trouvez des joueurs de votre zone qui ont les mêmes quêtes et formez un groupe.",
        QUEST_DEBUG_ON = "Débogage activé : toutes les quêtes actives non terminées sont partagées. Enregistré pour ce personnage.",
        QUEST_DEBUG_OFF = "Mode normal : seules les quêtes de groupe et élites sont partagées.",
        QUEST_DEBUG_USAGE = "Commandes : /flfg debug q 1 - toutes les quêtes ; /flfg debug q 0 - quêtes de groupe et élites.",
        QUEST_OPEN_MATCHES = "Partenaires pour les quêtes de groupe et d’élite",
        CHANNEL_TITLE = "ForeverLFG — ChannelBus",
        CHANNEL_FILTER_ALL = "Tous",
        CHANNEL_FILTER_QUESTS = "Quêtes",
        CHANNEL_FILTER_TRADE = "Commerce",
        CHANNEL_FILTER_MATCHES = "Correspondances",
        QUEST_WRITE = "Écrire",
        QUEST_INVITE = "Inviter",
        CHANNEL_CLEAR = "Effacer le journal",
        CHANNEL_NEWEST = "Récents",
        CHANNEL_READY = "Connecté",
        CHANNEL_JOINING = "Connexion au canal…",
        CHANNEL_UNAVAILABLE = "Échange indisponible",
        CHANNEL_RECORDS = "Entrées : %d",
        CHANNEL_SCROLL_HINT = "Molette : défiler",
        QUEST_GROUP = "Groupe : %d",
        QUEST_SOLO = "Solo",
        QUEST_PLAYER = "Niveau %d - %s",
        CHANNEL_SENT = "Envoyé",
        CHANNEL_RECEIVED = "Reçu",
        CHANNEL_ERROR = "Erreur",
        CHANNEL_SELF = "Vous",
        QUEST_NO_MATCHES = "Aucune quête commune pour le moment. Vérification du groupe, du raid et des données des autres utilisateurs de l’addon.",
        CHANNEL_EMPTY = "Aucun message. Le commerce apparaît lorsqu’un addon compatible envoie ces données.",
        QUEST_FOUND = "Quête de groupe commune",
        QUEST_FOUND_TEXT = "%s a la même quête active : %s.",
    },
    esES = {
        QUEST_SETTINGS_SECTION = "Compañeros para misiones de grupo y élite",
        QUEST_SETTINGS_DESCRIPTION = "Encuentra jugadores de tu zona con las mismas misiones y forma un grupo.",
        QUEST_DEBUG_ON = "Depuración activada: se comparten todas las misiones activas sin completar. Guardado para este personaje.",
        QUEST_DEBUG_OFF = "Modo normal: solo se comparten misiones de grupo y élite.",
        QUEST_DEBUG_USAGE = "Comandos: /flfg debug q 1 - todas las misiones; /flfg debug q 0 - misiones de grupo y élite.",
        QUEST_OPEN_MATCHES = "Compañeros para misiones de grupo y élite",
        CHANNEL_TITLE = "ForeverLFG — ChannelBus",
        CHANNEL_FILTER_ALL = "Todos",
        CHANNEL_FILTER_QUESTS = "Misiones",
        CHANNEL_FILTER_TRADE = "Comercio",
        CHANNEL_FILTER_MATCHES = "Coincidencias",
        QUEST_WRITE = "Escribir",
        QUEST_INVITE = "Invitar",
        CHANNEL_CLEAR = "Borrar registro",
        CHANNEL_NEWEST = "Recientes",
        CHANNEL_READY = "Conectado",
        CHANNEL_JOINING = "Entrando al canal…",
        CHANNEL_UNAVAILABLE = "Intercambio no disponible",
        CHANNEL_RECORDS = "Registros: %d",
        CHANNEL_SCROLL_HINT = "Rueda del ratón: desplazar",
        QUEST_GROUP = "Grupo: %d",
        QUEST_SOLO = "Solo",
        QUEST_PLAYER = "Nivel %d - %s",
        CHANNEL_SENT = "Enviado",
        CHANNEL_RECEIVED = "Recibido",
        CHANNEL_ERROR = "Error",
        CHANNEL_SELF = "Tú",
        QUEST_NO_MATCHES = "Aún no hay misiones comunes. Comprobamos el grupo, la banda y los datos de otros usuarios del addon.",
        CHANNEL_EMPTY = "Aún no hay mensajes. El comercio aparece cuando un addon compatible envía datos comerciales.",
        QUEST_FOUND = "Misión de grupo común",
        QUEST_FOUND_TEXT = "%s tiene la misma misión activa: %s.",
    },
    zhCN = {
        QUEST_SETTINGS_SECTION = "寻找组队与精英任务队友",
        QUEST_SETTINGS_DESCRIPTION = "寻找同一区域内拥有相同任务的玩家，组队一起完成任务。",
        QUEST_DEBUG_ON = "任务调试已开启：分享所有当前未完成的任务。设置为当前角色保存。",
        QUEST_DEBUG_OFF = "普通任务模式：只分享小队和精英任务。",
        QUEST_DEBUG_USAGE = "命令：/flfg debug q 1 — 所有任务；/flfg debug q 0 — 小队和精英任务。",
        QUEST_OPEN_MATCHES = "寻找组队与精英任务队友",
        CHANNEL_TITLE = "ForeverLFG — ChannelBus",
        CHANNEL_FILTER_ALL = "全部",
        CHANNEL_FILTER_QUESTS = "任务",
        CHANNEL_FILTER_TRADE = "交易",
        CHANNEL_FILTER_MATCHES = "匹配",
        QUEST_WRITE = "密语",
        QUEST_INVITE = "邀请",
        CHANNEL_CLEAR = "清空记录",
        CHANNEL_NEWEST = "最新",
        CHANNEL_READY = "已连接",
        CHANNEL_JOINING = "正在加入频道…",
        CHANNEL_UNAVAILABLE = "交换不可用",
        CHANNEL_RECORDS = "记录：%d",
        CHANNEL_SCROLL_HINT = "鼠标滚轮：滚动",
        QUEST_GROUP = "队伍：%d",
        QUEST_SOLO = "单人",
        QUEST_PLAYER = "等级 %d - %s",
        CHANNEL_SENT = "已发送",
        CHANNEL_RECEIVED = "已接收",
        CHANNEL_ERROR = "错误",
        CHANNEL_SELF = "你",
        QUEST_NO_MATCHES = "暂无共同任务。正在检查小队和团队成员，以及其他插件用户分享的数据。",
        CHANNEL_EMPTY = "暂无消息。兼容插件发送交易数据后会显示。",
        QUEST_FOUND = "相同小队任务",
        QUEST_FOUND_TEXT = "%s 拥有相同的当前任务：%s。",
    },
    zhTW = {
        QUEST_SETTINGS_SECTION = "尋找組隊與精英任務隊友",
        QUEST_SETTINGS_DESCRIPTION = "尋找同一區域內擁有相同任務的玩家，一起組隊完成任務。",
        QUEST_DEBUG_ON = "任務偵錯已開啟：分享所有目前未完成的任務。設定為目前角色儲存。",
        QUEST_DEBUG_OFF = "一般任務模式：只分享隊伍和精英任務。",
        QUEST_DEBUG_USAGE = "指令：/flfg debug q 1 — 所有任務；/flfg debug q 0 — 隊伍和精英任務。",
        QUEST_OPEN_MATCHES = "尋找組隊與精英任務隊友",
        CHANNEL_TITLE = "ForeverLFG — ChannelBus",
        CHANNEL_FILTER_ALL = "全部",
        CHANNEL_FILTER_QUESTS = "任務",
        CHANNEL_FILTER_TRADE = "交易",
        CHANNEL_FILTER_MATCHES = "配對",
        QUEST_WRITE = "密語",
        QUEST_INVITE = "邀請",
        CHANNEL_CLEAR = "清空紀錄",
        CHANNEL_NEWEST = "最新",
        CHANNEL_READY = "已連線",
        CHANNEL_JOINING = "正在加入頻道…",
        CHANNEL_UNAVAILABLE = "交換無法使用",
        CHANNEL_RECORDS = "紀錄：%d",
        CHANNEL_SCROLL_HINT = "滑鼠滾輪：捲動",
        QUEST_GROUP = "隊伍：%d",
        QUEST_SOLO = "單人",
        QUEST_PLAYER = "等級 %d - %s",
        CHANNEL_SENT = "已傳送",
        CHANNEL_RECEIVED = "已接收",
        CHANNEL_ERROR = "錯誤",
        CHANNEL_SELF = "你",
        QUEST_NO_MATCHES = "尚無共同任務。正在檢查小隊與團隊成員，以及其他插件使用者分享的資料。",
        CHANNEL_EMPTY = "暫無訊息。相容插件傳送交易資料後會顯示。",
        QUEST_FOUND = "相同隊伍任務",
        QUEST_FOUND_TEXT = "%s 擁有相同的目前任務：%s。",
    },
}
for key,value in pairs(strings.enUS) do NS.english[key]=value end
local selected = strings[NS.clientLocale == "esMX" and "esES" or NS.clientLocale]
if selected and NS.translation then
    for key,value in pairs(selected) do NS.translation[key]=value end
end
local copyStrings={
    enUS={CHANNEL_COPY="Copy tab",CHANNEL_COPY_TITLE="Copy: %s",CHANNEL_SELECT_ALL="Select all",
        CHANNEL_COPY_HINT="All retained entries in this tab are selected. Press Ctrl+C (Mac: Cmd+C), then Escape to close. This snapshot does not change when new messages arrive."},
    ruRU={CHANNEL_COPY="Копировать вкладку",CHANNEL_COPY_TITLE="Копирование: %s",CHANNEL_SELECT_ALL="Выделить всё",
        CHANNEL_COPY_HINT="Выделены все сохранённые записи вкладки. Нажмите Ctrl+C (Mac: Cmd+C), затем Escape для закрытия. Новые сообщения не меняют этот снимок."},
    deDE={CHANNEL_COPY="Tab kopieren",CHANNEL_COPY_TITLE="Kopieren: %s",CHANNEL_SELECT_ALL="Alles auswählen",
        CHANNEL_COPY_HINT="Alle gespeicherten Einträge dieses Tabs sind ausgewählt. Strg+C (Mac: Cmd+C) kopiert, Escape schließt. Neue Nachrichten ändern diese Momentaufnahme nicht."},
    frFR={CHANNEL_COPY="Copier l’onglet",CHANNEL_COPY_TITLE="Copier : %s",CHANNEL_SELECT_ALL="Tout sélectionner",
        CHANNEL_COPY_HINT="Toutes les entrées conservées de cet onglet sont sélectionnées. Appuyez sur Ctrl+C (Mac : Cmd+C), puis Échap pour fermer. Les nouveaux messages ne modifient pas cet instantané."},
    esES={CHANNEL_COPY="Copiar pestaña",CHANNEL_COPY_TITLE="Copiar: %s",CHANNEL_SELECT_ALL="Seleccionar todo",
        CHANNEL_COPY_HINT="Todas las entradas guardadas de esta pestaña están seleccionadas. Pulsa Ctrl+C (Mac: Cmd+C) y luego Escape para cerrar. Los mensajes nuevos no cambian esta captura."},
    zhCN={CHANNEL_COPY="复制当前标签",CHANNEL_COPY_TITLE="复制：%s",CHANNEL_SELECT_ALL="全选",
        CHANNEL_COPY_HINT="已选中此标签保留的全部记录。按 Ctrl+C（Mac：Cmd+C）复制，再按 Escape 关闭。新消息不会改变此快照。"},
    zhTW={CHANNEL_COPY="複製目前分頁",CHANNEL_COPY_TITLE="複製：%s",CHANNEL_SELECT_ALL="全選",
        CHANNEL_COPY_HINT="已選取此分頁保留的全部紀錄。按 Ctrl+C（Mac：Cmd+C）複製，再按 Escape 關閉。新訊息不會改變此快照。"},
}
for key,value in pairs(copyStrings.enUS) do NS.english[key]=value end
local copyLocale=copyStrings[NS.clientLocale=="esMX" and "esES" or NS.clientLocale]
if copyLocale and NS.translation then for key,value in pairs(copyLocale) do NS.translation[key]=value end end
local whispers = {
    enUS = "Hi! Would you like to team up for %s?",
    ruRU = "Привет! Пройдём %s вместе?",
    deDE = "Hallo! Wollen wir %s zusammen machen?",
    frFR = "Salut ! Ça te dit de faire %s ensemble ?",
    esES = "¡Hola! ¿Hacemos %s juntos?",
    ptBR = "Olá! Vamos fazer %s juntos?",
    itIT = "Ciao! Ti va di fare %s insieme?",
    koKR = "안녕하세요! %s 같이 하실래요?",
    zhCN = "你好！要一起做 %s 吗？",
    zhTW = "你好！要一起做 %s 嗎？",
}
local shortWhispers = {
    enUS="Group up for %s?", ruRU="В группу на %s?", deDE="Gruppe für %s?",
    frFR="Un groupe pour %s ?", esES="¿Grupo para %s?", ptBR="Grupo para %s?",
    itIT="Gruppo per %s?", koKR="%s 함께 할까요?", zhCN="一起做 %s？", zhTW="一起做 %s？",
}
function NS.QuestWhisper(locale,id)
    local recipientLocale=locale
    locale=locale=="esMX" and "esES" or locale
    local fallbackReason
    if not whispers[locale] then
        locale="enUS";fallbackReason="unknown-recipient-locale"
    end
    local reference="#"..id
    if type(GetQuestLink)=="function" then
        local ok,link=pcall(GetQuestLink,id)
        if ok and not (issecretvalue and issecretvalue(link)) and type(link)=="string"
            and not link:find("[%z\1-\31]") then
            local linkedID=link:match("|Hquest:(%d+)[^|]*|h.-|h")
            if tonumber(linkedID)==id then reference=link end
        end
    end
    local function result(message,form)
        return message,{recipientLocale=recipientLocale,templateLocale=locale,clientLocale=NS.clientLocale,
            fallbackReason=fallbackReason,referenceKind=reference:sub(1,1)=="#" and "quest-id" or "native-link",
            bytes=message and #message or 0,form=form}
    end
    -- Keep the complete native link, including its localized title, unchanged for chat delivery.
    local message=string.format(whispers[locale] or whispers.enUS,reference)
    if #message<=255 then return result(message,"full") end
    message=string.format(shortWhispers[locale] or shortWhispers.enUS,reference)
    if #message<=255 then return result(message,"short") end
    if #reference<=255 then return result(reference,"link-only") end
    return result(nil,"too-long")
end

-- Private drafts and quest information.
local listStrings = {
    enUS = {
        QUEST_WHISPER_TOO_LONG="The quest link is too long for a private message. No message was sent.",
        QUEST_WHISPER_TITLE="Private message",
        QUEST_WHISPER_TO="To: %s",
        QUEST_WHISPER_COMPOSE_HINT="Edit your private draft. Send with the button or Enter.",
        QUEST_WHISPER_SEND="Send private message",
        QUEST_WHISPER_FAILED="Could not prepare a private message. No message was sent.",
        QUEST_OPEN_HINT="Click the quest title to open it in your journal.",
        QUEST_ID="Quest #%d", QUEST_LEVEL="Level %d", QUEST_REQUIRED_GROUP="Recommended party: %d",
        QUEST_LOCATION="Location: %s", QUEST_PLAYERS_LOCATION="Players in: %s",
    },
    ruRU = {
        QUEST_WHISPER_TOO_LONG="Ссылка квеста слишком длинная для личного сообщения. Сообщение не отправлено.",
        QUEST_WHISPER_TITLE="Личное сообщение",
        QUEST_WHISPER_TO="Кому: %s",
        QUEST_WHISPER_COMPOSE_HINT="Редактируйте черновик. Отправка — по кнопке или Enter.",
        QUEST_WHISPER_SEND="Отправить в личку",
        QUEST_WHISPER_FAILED="Не удалось подготовить личное сообщение. Сообщение не отправлено.",
        QUEST_OPEN_HINT="Нажмите название квеста, чтобы открыть его в журнале.",
        QUEST_ID="Квест #%d", QUEST_LEVEL="Уровень %d", QUEST_REQUIRED_GROUP="Рекомендуемая группа: %d",
        QUEST_LOCATION="Место: %s", QUEST_PLAYERS_LOCATION="Игроки в: %s",
    },
    deDE = {
        QUEST_WHISPER_TOO_LONG="Der Questlink ist zu lang für eine private Nachricht. Es wurde nichts gesendet.",
        QUEST_WHISPER_TITLE="Private Nachricht",
        QUEST_WHISPER_TO="An: %s",
        QUEST_WHISPER_COMPOSE_HINT="Entwurf bearbeiten. Mit der Schaltfläche oder Enter senden.",
        QUEST_WHISPER_SEND="Privat senden",
        QUEST_WHISPER_FAILED="Die private Nachricht konnte nicht vorbereitet werden. Es wurde nichts gesendet.",
        QUEST_OPEN_HINT="Questtitel anklicken, um die Quest im Log zu öffnen.",
        QUEST_ID="Quest #%d", QUEST_LEVEL="Stufe %d", QUEST_REQUIRED_GROUP="Empfohlene Gruppe: %d",
        QUEST_LOCATION="Ort: %s", QUEST_PLAYERS_LOCATION="Spieler in: %s",
    },
    frFR = {
        QUEST_WHISPER_TOO_LONG="Le lien de quête est trop long pour un message privé. Aucun message envoyé.",
        QUEST_WHISPER_TITLE="Message privé",
        QUEST_WHISPER_TO="À : %s",
        QUEST_WHISPER_COMPOSE_HINT="Modifiez le brouillon. Envoyez avec le bouton ou Entrée.",
        QUEST_WHISPER_SEND="Envoyer en privé",
        QUEST_WHISPER_FAILED="Impossible de préparer le message privé. Aucun message envoyé.",
        QUEST_OPEN_HINT="Cliquez sur le titre pour ouvrir la quête dans le journal.",
        QUEST_ID="Quête #%d", QUEST_LEVEL="Niveau %d", QUEST_REQUIRED_GROUP="Groupe conseillé : %d",
        QUEST_LOCATION="Lieu : %s", QUEST_PLAYERS_LOCATION="Joueurs à : %s",
    },
    esES = {
        QUEST_WHISPER_TOO_LONG="El enlace de misión es demasiado largo para un mensaje privado. No se envió nada.",
        QUEST_WHISPER_TITLE="Mensaje privado",
        QUEST_WHISPER_TO="Para: %s",
        QUEST_WHISPER_COMPOSE_HINT="Edita el borrador. Envía con el botón o Intro.",
        QUEST_WHISPER_SEND="Enviar en privado",
        QUEST_WHISPER_FAILED="No se pudo preparar el mensaje privado. No se envió ningún mensaje.",
        QUEST_OPEN_HINT="Pulsa el título para abrir la misión en tu diario.",
        QUEST_ID="Misión #%d", QUEST_LEVEL="Nivel %d", QUEST_REQUIRED_GROUP="Grupo recomendado: %d",
        QUEST_LOCATION="Lugar: %s", QUEST_PLAYERS_LOCATION="Jugadores en: %s",
    },
    zhCN = {
        QUEST_WHISPER_TOO_LONG="任务链接过长，无法放入私聊消息。未发送任何消息。",
        QUEST_WHISPER_TITLE="私聊消息",
        QUEST_WHISPER_TO="收件人：%s",
        QUEST_WHISPER_COMPOSE_HINT="编辑私聊草稿。点击按钮或按回车发送。",
        QUEST_WHISPER_SEND="发送私聊",
        QUEST_WHISPER_FAILED="无法准备私聊消息。未发送任何消息。",
        QUEST_OPEN_HINT="点击任务名称，在日志中打开任务。",
        QUEST_ID="任务 #%d", QUEST_LEVEL="等级 %d", QUEST_REQUIRED_GROUP="建议队伍人数：%d",
        QUEST_LOCATION="地点：%s", QUEST_PLAYERS_LOCATION="玩家位置：%s",
    },
    zhTW = {
        QUEST_WHISPER_TOO_LONG="任務連結過長，無法放入私訊。未傳送任何訊息。",
        QUEST_WHISPER_TITLE="私訊",
        QUEST_WHISPER_TO="收件人：%s",
        QUEST_WHISPER_COMPOSE_HINT="編輯私訊草稿。點擊按鈕或按 Enter 傳送。",
        QUEST_WHISPER_SEND="傳送私訊",
        QUEST_WHISPER_FAILED="無法準備私訊。未傳送任何訊息。",
        QUEST_OPEN_HINT="點擊任務名稱，在日誌中開啟任務。",
        QUEST_ID="任務 #%d", QUEST_LEVEL="等級 %d", QUEST_REQUIRED_GROUP="建議隊伍人數：%d",
        QUEST_LOCATION="地點：%s", QUEST_PLAYERS_LOCATION="玩家位置：%s",
    },
}
for key,value in pairs(listStrings.enUS) do NS.english[key]=value end
local selectedList=listStrings[NS.clientLocale=="esMX" and "esES" or NS.clientLocale]
if selectedList and NS.translation then for key,value in pairs(selectedList) do NS.translation[key]=value end end

local browserStrings={
    enUS={
        QUEST_BROWSER_TITLE="Partners for group and elite quests", QUEST_BROWSER_SUBTITLE="Find players in your zone with the same quests and team up.",
        QUEST_BROWSER_COUNT="Shared quests: %d of %d - Players: %d", QUEST_BROWSER_QUESTS="Shared quests (%d)",
        QUEST_BROWSER_PLAYERS="Players with this quest (%d)", QUEST_MATCH_PLAYERS="Players: %d",
        QUEST_COLLAPSE_LIST="Collapse quest list", QUEST_EXPAND_LIST="Expand quest list",
        QUEST_EXPAND_HINT="Click a quest row to show or hide its players.",
    },
    ruRU={
        QUEST_BROWSER_TITLE="Напарники для групповых и элитных заданий", QUEST_BROWSER_SUBTITLE="Найдите игроков с такими же заданиями в вашей зоне и объединитесь в группу.",
        QUEST_BROWSER_COUNT="Общие задания: %d из %d - Игроки: %d", QUEST_BROWSER_QUESTS="Общие задания (%d)",
        QUEST_BROWSER_PLAYERS="Игроки с этим заданием (%d)", QUEST_MATCH_PLAYERS="Игроков: %d",
        QUEST_COLLAPSE_LIST="Свернуть список заданий", QUEST_EXPAND_LIST="Развернуть список заданий",
        QUEST_EXPAND_HINT="Нажмите строку задания, чтобы раскрыть или свернуть игроков.",
    },
    deDE={
        QUEST_BROWSER_TITLE="Mitspieler für Gruppen- und Elitequests", QUEST_BROWSER_SUBTITLE="Finde Spieler mit denselben Quests in deiner Zone und bilde eine Gruppe.",
        QUEST_BROWSER_COUNT="Gemeinsame Quests: %d von %d - Spieler: %d", QUEST_BROWSER_QUESTS="Gemeinsame Quests (%d)",
        QUEST_BROWSER_PLAYERS="Spieler mit dieser Quest (%d)", QUEST_MATCH_PLAYERS="Spieler: %d",
        QUEST_COLLAPSE_LIST="Questliste einklappen", QUEST_EXPAND_LIST="Questliste ausklappen",
        QUEST_EXPAND_HINT="Questzeile anklicken, um Spieler ein- oder auszublenden.",
    },
    frFR={
        QUEST_BROWSER_TITLE="Partenaires pour les quêtes de groupe et d’élite", QUEST_BROWSER_SUBTITLE="Trouvez des joueurs de votre zone qui ont les mêmes quêtes et formez un groupe.",
        QUEST_BROWSER_COUNT="Quêtes communes : %d sur %d - Joueurs : %d", QUEST_BROWSER_QUESTS="Quêtes communes (%d)",
        QUEST_BROWSER_PLAYERS="Joueurs avec cette quête (%d)", QUEST_MATCH_PLAYERS="Joueurs : %d",
        QUEST_COLLAPSE_LIST="Réduire la liste des quêtes", QUEST_EXPAND_LIST="Développer la liste des quêtes",
        QUEST_EXPAND_HINT="Cliquez sur une ligne de quête pour afficher ou masquer les joueurs.",
    },
    esES={
        QUEST_BROWSER_TITLE="Compañeros para misiones de grupo y élite", QUEST_BROWSER_SUBTITLE="Encuentra jugadores de tu zona con las mismas misiones y forma un grupo.",
        QUEST_BROWSER_COUNT="Misiones comunes: %d de %d - Jugadores: %d", QUEST_BROWSER_QUESTS="Misiones comunes (%d)",
        QUEST_BROWSER_PLAYERS="Jugadores con esta misión (%d)", QUEST_MATCH_PLAYERS="Jugadores: %d",
        QUEST_COLLAPSE_LIST="Contraer lista de misiones", QUEST_EXPAND_LIST="Expandir lista de misiones",
        QUEST_EXPAND_HINT="Haz clic en una fila de misión para mostrar u ocultar sus jugadores.",
    },
    zhCN={
        QUEST_BROWSER_TITLE="寻找组队与精英任务队友", QUEST_BROWSER_SUBTITLE="寻找同一区域内拥有相同任务的玩家，组队一起完成任务。",
        QUEST_BROWSER_COUNT="共同任务：%d/%d - 玩家：%d", QUEST_BROWSER_QUESTS="共同任务（%d）",
        QUEST_BROWSER_PLAYERS="拥有此任务的玩家（%d）", QUEST_MATCH_PLAYERS="玩家：%d",
        QUEST_COLLAPSE_LIST="收起任务列表", QUEST_EXPAND_LIST="展开任务列表",
        QUEST_EXPAND_HINT="点击任务行展开或收起玩家列表。",
    },
    zhTW={
        QUEST_BROWSER_TITLE="尋找組隊與精英任務隊友", QUEST_BROWSER_SUBTITLE="尋找同一區域內擁有相同任務的玩家，一起組隊完成任務。",
        QUEST_BROWSER_COUNT="共同任務：%d/%d - 玩家：%d", QUEST_BROWSER_QUESTS="共同任務（%d）",
        QUEST_BROWSER_PLAYERS="擁有此任務的玩家（%d）", QUEST_MATCH_PLAYERS="玩家：%d",
        QUEST_COLLAPSE_LIST="收起任務清單", QUEST_EXPAND_LIST="展開任務清單",
        QUEST_EXPAND_HINT="點擊任務列展開或收起玩家列表。",
    },
}
for key,value in pairs(browserStrings.enUS) do NS.english[key]=value end
local browserLocale=browserStrings[NS.clientLocale=="esMX" and "esES" or NS.clientLocale]
if browserLocale and NS.translation then for key,value in pairs(browserLocale) do NS.translation[key]=value end end
local playerCounts={
    enUS={QUEST_PLAYERS_ONE="%d player",QUEST_PLAYERS_MANY="%d players"},
    ruRU={QUEST_PLAYERS_ONE="%d игрок",QUEST_PLAYERS_FEW="%d игрока",QUEST_PLAYERS_MANY="%d игроков"},
    deDE={QUEST_PLAYERS_ONE="%d Spieler",QUEST_PLAYERS_MANY="%d Spieler"},
    frFR={QUEST_PLAYERS_ONE="%d joueur",QUEST_PLAYERS_MANY="%d joueurs"},
    esES={QUEST_PLAYERS_ONE="%d jugador",QUEST_PLAYERS_MANY="%d jugadores"},
    zhCN={QUEST_PLAYERS_ONE="%d 位玩家",QUEST_PLAYERS_MANY="%d 位玩家"},
    zhTW={QUEST_PLAYERS_ONE="%d 位玩家",QUEST_PLAYERS_MANY="%d 位玩家"},
}
for _,counts in pairs(playerCounts) do counts.QUEST_PLAYERS_FEW=counts.QUEST_PLAYERS_FEW or counts.QUEST_PLAYERS_MANY end
for key,value in pairs(playerCounts.enUS) do NS.english[key]=value end
local countsLocale=playerCounts[NS.clientLocale=="esMX" and "esES" or NS.clientLocale]
if countsLocale and NS.translation then for key,value in pairs(countsLocale) do NS.translation[key]=value end end

local actionStrings={
    enUS={
        QUEST_INVITE_SAME_GROUP="This player is already in your party or raid.",
        QUEST_PLAYER_SHORT="Lv. %d - %s", QUEST_WRITE_HINT="Prepare an editable private message with the quest link.",
        QUEST_INVITE_HINT="Invite this player to your party.", QUEST_ACTION_COMBAT="This action is unavailable during combat.",
        QUEST_ACTION_STALE="This match is no longer available.", QUEST_INVITE_IN_GROUP="This player is already in a party. Write to them to discuss joining.",
        QUEST_INVITE_LEADER="Only the party leader can invite players.", QUEST_INVITE_FULL="Your party is full.",
        QUEST_INVITE_RAID="Quest party invitations are unavailable while you are in a raid.", QUEST_ACTION_UNAVAILABLE="Party information is not available yet.",
    },
    ruRU={
        QUEST_INVITE_SAME_GROUP="Этот игрок уже в вашей группе или рейде.",
        QUEST_PLAYER_SHORT="Ур. %d - %s", QUEST_WRITE_HINT="Подготовить редактируемое личное сообщение со ссылкой на задание.",
        QUEST_INVITE_HINT="Пригласить этого игрока в вашу группу.", QUEST_ACTION_COMBAT="Это действие недоступно в бою.",
        QUEST_ACTION_STALE="Это совпадение больше недоступно.", QUEST_INVITE_IN_GROUP="Игрок уже в группе. Напишите ему, чтобы договориться об объединении.",
        QUEST_INVITE_LEADER="Приглашать игроков может только лидер группы.", QUEST_INVITE_FULL="В вашей группе нет свободных мест.",
        QUEST_INVITE_RAID="Приглашения для группового задания недоступны, пока вы в рейде.", QUEST_ACTION_UNAVAILABLE="Информация о группе пока недоступна.",
    },
    deDE={
        QUEST_INVITE_SAME_GROUP="Dieser Spieler ist bereits in deiner Gruppe oder deinem Schlachtzug.",
        QUEST_PLAYER_SHORT="St. %d - %s", QUEST_WRITE_HINT="Eine bearbeitbare Flüsternachricht mit dem Questlink vorbereiten.",
        QUEST_INVITE_HINT="Diesen Spieler in deine Gruppe einladen.", QUEST_ACTION_COMBAT="Diese Aktion ist im Kampf nicht verfügbar.",
        QUEST_ACTION_STALE="Dieser Treffer ist nicht mehr verfügbar.", QUEST_INVITE_IN_GROUP="Dieser Spieler ist bereits in einer Gruppe. Schreibe ihm, um euch abzusprechen.",
        QUEST_INVITE_LEADER="Nur der Gruppenanführer kann Spieler einladen.", QUEST_INVITE_FULL="Deine Gruppe ist voll.",
        QUEST_INVITE_RAID="Questeinladungen sind in einem Schlachtzug nicht verfügbar.", QUEST_ACTION_UNAVAILABLE="Gruppeninformationen sind noch nicht verfügbar.",
    },
    frFR={
        QUEST_INVITE_SAME_GROUP="Ce joueur est déjà dans votre groupe ou votre raid.",
        QUEST_PLAYER_SHORT="Niv. %d - %s", QUEST_WRITE_HINT="Préparer un message privé modifiable avec le lien de quête.",
        QUEST_INVITE_HINT="Inviter ce joueur dans votre groupe.", QUEST_ACTION_COMBAT="Cette action est indisponible en combat.",
        QUEST_ACTION_STALE="Cette correspondance n’est plus disponible.", QUEST_INVITE_IN_GROUP="Ce joueur est déjà en groupe. Écrivez-lui pour en discuter.",
        QUEST_INVITE_LEADER="Seul le chef de groupe peut inviter des joueurs.", QUEST_INVITE_FULL="Votre groupe est complet.",
        QUEST_INVITE_RAID="Les invitations de quête sont indisponibles en raid.", QUEST_ACTION_UNAVAILABLE="Les informations du groupe ne sont pas encore disponibles.",
    },
    esES={
        QUEST_INVITE_SAME_GROUP="Este jugador ya está en tu grupo o banda.",
        QUEST_PLAYER_SHORT="Nv. %d - %s", QUEST_WRITE_HINT="Preparar un mensaje privado editable con el enlace de la misión.",
        QUEST_INVITE_HINT="Invitar a este jugador a tu grupo.", QUEST_ACTION_COMBAT="Esta acción no está disponible en combate.",
        QUEST_ACTION_STALE="Esta coincidencia ya no está disponible.", QUEST_INVITE_IN_GROUP="Este jugador ya está en un grupo. Escríbele para poneros de acuerdo.",
        QUEST_INVITE_LEADER="Solo el líder del grupo puede invitar jugadores.", QUEST_INVITE_FULL="Tu grupo está lleno.",
        QUEST_INVITE_RAID="Las invitaciones para misiones no están disponibles en una banda.", QUEST_ACTION_UNAVAILABLE="La información del grupo aún no está disponible.",
    },
    zhCN={
        QUEST_INVITE_SAME_GROUP="这名玩家已在你的小队或团队中。",
        QUEST_PLAYER_SHORT="%d级 - %s", QUEST_WRITE_HINT="准备包含任务链接的可编辑私聊消息。",
        QUEST_INVITE_HINT="邀请此玩家加入你的小队。", QUEST_ACTION_COMBAT="战斗中无法执行此操作。",
        QUEST_ACTION_STALE="此匹配已失效。", QUEST_INVITE_IN_GROUP="此玩家已在小队中，请先私聊协商。",
        QUEST_INVITE_LEADER="只有队长可以邀请玩家。", QUEST_INVITE_FULL="你的小队已满。",
        QUEST_INVITE_RAID="团队中无法邀请任务小队成员。", QUEST_ACTION_UNAVAILABLE="小队信息暂不可用。",
    },
    zhTW={
        QUEST_INVITE_SAME_GROUP="這名玩家已在你的小隊或團隊中。",
        QUEST_PLAYER_SHORT="%d級 - %s", QUEST_WRITE_HINT="準備包含任務連結的可編輯私聊訊息。",
        QUEST_INVITE_HINT="邀請此玩家加入你的隊伍。", QUEST_ACTION_COMBAT="戰鬥中無法執行此操作。",
        QUEST_ACTION_STALE="此配對已失效。", QUEST_INVITE_IN_GROUP="此玩家已在隊伍中，請先私聊協商。",
        QUEST_INVITE_LEADER="只有隊長可以邀請玩家。", QUEST_INVITE_FULL="你的隊伍已滿。",
        QUEST_INVITE_RAID="團隊中無法邀請任務隊伍成員。", QUEST_ACTION_UNAVAILABLE="隊伍資訊暫不可用。",
    },
}
for key,value in pairs(actionStrings.enUS) do NS.english[key]=value end
local actionLocale=actionStrings[NS.clientLocale=="esMX" and "esES" or NS.clientLocale]
if actionLocale and NS.translation then for key,value in pairs(actionLocale) do NS.translation[key]=value end end

local launcherStrings={
    enUS={QUEST_LAUNCHER_TITLE="Group & elite quests",QUEST_LAUNCHER_QUEST_ONE="%d quest",QUEST_LAUNCHER_QUEST_FEW="%d quests",QUEST_LAUNCHER_QUEST_MANY="%d quests",QUEST_LAUNCHER_COUNTS="Shared quests: %d\nPlayers: %d",QUEST_LAUNCHER_HINT="Left-click to open or close the quest browser. Drag with the left mouse button to move this bar; its position is saved for this character."},
    ruRU={QUEST_LAUNCHER_TITLE="Групповые и элитные задания",QUEST_LAUNCHER_QUEST_ONE="%d задание",QUEST_LAUNCHER_QUEST_FEW="%d задания",QUEST_LAUNCHER_QUEST_MANY="%d заданий",QUEST_LAUNCHER_COUNTS="Общие задания: %d\nИгроки: %d",QUEST_LAUNCHER_HINT="Левая кнопка: открыть или закрыть список заданий и игроков. Перетащите строку левой кнопкой мыши, чтобы переместить её; положение сохраняется для персонажа."},
    deDE={QUEST_LAUNCHER_TITLE="Gruppen- und Elitequests",QUEST_LAUNCHER_QUEST_ONE="%d Quest",QUEST_LAUNCHER_QUEST_FEW="%d Quests",QUEST_LAUNCHER_QUEST_MANY="%d Quests",QUEST_LAUNCHER_COUNTS="Gemeinsame Quests: %d\nSpieler: %d",QUEST_LAUNCHER_HINT="Linksklick: die Questübersicht öffnen oder schließen. Mit der linken Maustaste ziehen, um diese Leiste zu verschieben; die Position wird für diesen Charakter gespeichert."},
    frFR={QUEST_LAUNCHER_TITLE="Quêtes de groupe et d’élite",QUEST_LAUNCHER_QUEST_ONE="%d quête",QUEST_LAUNCHER_QUEST_FEW="%d quêtes",QUEST_LAUNCHER_QUEST_MANY="%d quêtes",QUEST_LAUNCHER_COUNTS="Quêtes communes : %d\nJoueurs : %d",QUEST_LAUNCHER_HINT="Clic gauche : ouvrir ou fermer la liste des quêtes et des joueurs. Faites glisser cette barre avec le bouton gauche pour la déplacer ; sa position est enregistrée pour ce personnage."},
    esES={QUEST_LAUNCHER_TITLE="Misiones de grupo y élite",QUEST_LAUNCHER_QUEST_ONE="%d misión",QUEST_LAUNCHER_QUEST_FEW="%d misiones",QUEST_LAUNCHER_QUEST_MANY="%d misiones",QUEST_LAUNCHER_COUNTS="Misiones comunes: %d\nJugadores: %d",QUEST_LAUNCHER_HINT="Clic izquierdo: abrir o cerrar la lista de misiones y jugadores. Arrastra esta barra con el botón izquierdo para moverla; su posición se guarda para este personaje."},
    zhCN={QUEST_LAUNCHER_TITLE="组队与精英任务",QUEST_LAUNCHER_QUEST_ONE="%d个任务",QUEST_LAUNCHER_QUEST_FEW="%d个任务",QUEST_LAUNCHER_QUEST_MANY="%d个任务",QUEST_LAUNCHER_COUNTS="共同任务：%d\n玩家：%d",QUEST_LAUNCHER_HINT="左键：打开或关闭任务和玩家列表。按住左键拖动此栏可调整位置；位置会为当前角色保存。"},
    zhTW={QUEST_LAUNCHER_TITLE="組隊與精英任務",QUEST_LAUNCHER_QUEST_ONE="%d個任務",QUEST_LAUNCHER_QUEST_FEW="%d個任務",QUEST_LAUNCHER_QUEST_MANY="%d個任務",QUEST_LAUNCHER_COUNTS="共同任務：%d\n玩家：%d",QUEST_LAUNCHER_HINT="左鍵：開啟或關閉任務和玩家清單。按住左鍵拖曳此列可調整位置；位置會為目前角色儲存。"},
}
for key,value in pairs(launcherStrings.enUS) do NS.english[key]=value end
local launcherLocale=launcherStrings[NS.clientLocale=="esMX" and "esES" or NS.clientLocale]
if launcherLocale and NS.translation then for key,value in pairs(launcherLocale) do NS.translation[key]=value end end

local attentionStrings={
    enUS={
        QUEST_NEW_MATCHES="New matches: %d. Open the list to view them.",
        QUEST_MATCH_ANIMATION="Highlight new quest matches", QUEST_MATCH_ANIMATION_HINT="The whole minimap icon glows briefly; the bar uses a light sweep. The unread mark stays until you open the list. Repeated updates do not alert again.",
        QUEST_MATCH_SOUND="Sound for new quest matches", QUEST_MATCH_SOUND_HINT="A subdued game chime, enabled by default. Nearby arrivals share one cue, with at least 30 seconds between sounds. No cue when the list is already open. Uses the game's sound settings.",
        QUEST_SOUND_PREVIEW="Test sound", QUEST_SOUND_PREVIEW_HINT="Play the cue once, even if automatic sound is disabled. This does not change the sound setting or the automatic cue cooldown.",
        QUEST_ANIMATION_PREVIEW="Test animation", QUEST_ANIMATION_PREVIEW_HINT="Preview the animation on the selected icon or bar, even if automatic animation is disabled. Counts and unread marks stay unchanged.",
        QUEST_ANIMATION_UNAVAILABLE="The icon or bar is unavailable for a preview. If you are in combat, try again after combat.",
        QUEST_SOUND_UNAVAILABLE="Could not confirm sound playback. Check your sound settings.",
    },
    ruRU={
        QUEST_NEW_MATCHES="Новых совпадений: %d. Откройте список, чтобы посмотреть их.",
        QUEST_MATCH_ANIMATION="Подсветка новых совпадений", QUEST_MATCH_ANIMATION_HINT="Иконка у миникарты ненадолго светится целиком; на баннере проходит полоса света. Отметка остаётся до открытия списка. Повторная синхронизация не повторяет сигнал.",
        QUEST_MATCH_SOUND="Звук новых совпадений", QUEST_MATCH_SOUND_HINT="Приглушённый торжественный игровой сигнал, включён по умолчанию. Несколько близких событий дают один звук, с паузой не менее 30 секунд. При открытом списке звука нет. Учитываются звуковые настройки игры.",
        QUEST_SOUND_PREVIEW="Проверить звук", QUEST_SOUND_PREVIEW_HINT="Проиграть сигнал один раз, даже если автоматический звук выключен. Проверка не меняет настройку и паузу автоматических сигналов.",
        QUEST_ANIMATION_PREVIEW="Проверить анимацию", QUEST_ANIMATION_PREVIEW_HINT="Показать анимацию выбранной иконки или баннера, даже если автоматическая анимация выключена. Счётчик и отметка новых совпадений не изменятся.",
        QUEST_ANIMATION_UNAVAILABLE="Иконка или баннер недоступны для проверки. Если вы в бою, повторите после его окончания.",
        QUEST_SOUND_UNAVAILABLE="Воспроизведение звука не подтверждено. Проверьте звуковые настройки.",
    },
    deDE={
        QUEST_NEW_MATCHES="Neue Treffer: %d. Öffne die Liste, um sie anzusehen.",
        QUEST_MATCH_ANIMATION="Neue Questtreffer hervorheben", QUEST_MATCH_ANIMATION_HINT="Das ganze Minikartensymbol leuchtet kurz; über die Leiste läuft ein Lichtschein. Die Markierung bleibt bis zum Öffnen der Liste. Wiederholte Aktualisierungen lösen keinen Hinweis aus.",
        QUEST_MATCH_SOUND="Ton bei neuen Questtreffern", QUEST_MATCH_SOUND_HINT="Ein dezenter Spielklang, standardmäßig aktiviert. Nahe Ereignisse teilen einen Ton, mit mindestens 30 Sekunden Abstand. Kein Ton bei geöffneter Liste. Verwendet die Toneinstellungen des Spiels.",
        QUEST_SOUND_PREVIEW="Ton testen", QUEST_SOUND_PREVIEW_HINT="Spielt den Ton einmal ab, auch wenn automatische Töne deaktiviert sind. Einstellung und Wartezeit für automatische Töne bleiben unverändert.",
        QUEST_ANIMATION_PREVIEW="Animation testen", QUEST_ANIMATION_PREVIEW_HINT="Zeigt die Animation am gewählten Symbol oder an der Leiste, auch wenn automatische Animationen deaktiviert sind. Zähler und Markierung bleiben unverändert.",
        QUEST_ANIMATION_UNAVAILABLE="Symbol oder Leiste sind für die Vorschau nicht verfügbar. Versuche es nach dem Kampf erneut, falls du im Kampf bist.",
        QUEST_SOUND_UNAVAILABLE="Die Tonwiedergabe konnte nicht bestätigt werden. Prüfe deine Toneinstellungen.",
    },
    frFR={
        QUEST_NEW_MATCHES="Nouvelles correspondances : %d. Ouvrez la liste pour les voir.",
        QUEST_MATCH_ANIMATION="Signaler les nouvelles correspondances", QUEST_MATCH_ANIMATION_HINT="Toute l’icône de minicarte s’illumine brièvement ; un reflet parcourt la barre. La marque reste jusqu’à l’ouverture de la liste. Les mises à jour répétées ne relancent pas le signal.",
        QUEST_MATCH_SOUND="Son pour les nouvelles correspondances", QUEST_MATCH_SOUND_HINT="Un son discret du jeu, activé par défaut. Les arrivées proches partagent un signal, espacés d'au moins 30 secondes. Aucun son si la liste est ouverte. Respecte les réglages audio du jeu.",
        QUEST_SOUND_PREVIEW="Tester le son", QUEST_SOUND_PREVIEW_HINT="Joue le son une fois, même si les sons automatiques sont désactivés. Le réglage et le délai des sons automatiques restent inchangés.",
        QUEST_ANIMATION_PREVIEW="Tester l'animation", QUEST_ANIMATION_PREVIEW_HINT="Afficher l’animation de l’icône ou de la barre choisie, même si les animations automatiques sont désactivées. Le compteur et la marque restent inchangés.",
        QUEST_ANIMATION_UNAVAILABLE="L’icône ou la barre est indisponible pour l’aperçu. Si vous êtes en combat, réessayez après le combat.",
        QUEST_SOUND_UNAVAILABLE="La lecture du son n'a pas pu être confirmée. Vérifiez vos réglages audio.",
    },
    esES={
        QUEST_NEW_MATCHES="Nuevas coincidencias: %d. Abre la lista para verlas.",
        QUEST_MATCH_ANIMATION="Resaltar nuevas coincidencias", QUEST_MATCH_ANIMATION_HINT="Todo el icono del minimapa se ilumina brevemente; la barra muestra un reflejo. La marca permanece hasta abrir la lista. Las actualizaciones repetidas no repiten el aviso.",
        QUEST_MATCH_SOUND="Sonido para nuevas coincidencias", QUEST_MATCH_SOUND_HINT="Un sonido discreto del juego, activado por defecto. Las llegadas cercanas comparten un aviso, con al menos 30 segundos entre sonidos. No suena si la lista está abierta. Usa los ajustes de sonido del juego.",
        QUEST_SOUND_PREVIEW="Probar sonido", QUEST_SOUND_PREVIEW_HINT="Reproduce el sonido una vez, incluso con los avisos automáticos desactivados. No cambia el ajuste ni la pausa de los sonidos automáticos.",
        QUEST_ANIMATION_PREVIEW="Probar animación", QUEST_ANIMATION_PREVIEW_HINT="Mostrar la animación del icono o la barra seleccionados, aunque la animación automática esté desactivada. El contador y la marca no cambian.",
        QUEST_ANIMATION_UNAVAILABLE="El icono o la barra no están disponibles para la prueba. Si estás en combate, inténtalo al terminar.",
        QUEST_SOUND_UNAVAILABLE="No se pudo confirmar la reproducción del sonido. Revisa los ajustes de sonido.",
    },
    zhCN={
        QUEST_NEW_MATCHES="新匹配：%d。打开列表查看。",
        QUEST_MATCH_ANIMATION="突出显示新的任务匹配", QUEST_MATCH_ANIMATION_HINT="整个小地图图标会短暂发光；任务栏使用扫光效果。未读标记保留到打开列表。重复更新不会再次提示。",
        QUEST_MATCH_SOUND="新匹配提示音", QUEST_MATCH_SOUND_HINT="默认开启柔和的游戏提示音。短时间内的匹配合并提示，声音间隔至少30秒。列表已打开时不播放。遵循游戏声音设置。",
        QUEST_SOUND_PREVIEW="测试声音", QUEST_SOUND_PREVIEW_HINT="播放一次提示音，即使自动提示音已关闭。不会更改设置或自动提示音的间隔。",
        QUEST_ANIMATION_PREVIEW="测试动画", QUEST_ANIMATION_PREVIEW_HINT="预览所选图标或任务栏的动画，即使自动动画已关闭。计数和未读标记保持不变。",
        QUEST_ANIMATION_UNAVAILABLE="图标或任务栏暂不可用于预览。如果正在战斗，请在脱战后重试。",
        QUEST_SOUND_UNAVAILABLE="无法确认提示音播放，请检查声音设置。",
    },
    zhTW={
        QUEST_NEW_MATCHES="新配對：%d。開啟清單查看。",
        QUEST_MATCH_ANIMATION="突顯新的任務配對", QUEST_MATCH_ANIMATION_HINT="整個小地圖圖示會短暫發光；任務列使用掃光效果。未讀標記保留到開啟清單。重複更新不會再次提示。",
        QUEST_MATCH_SOUND="新配對提示音", QUEST_MATCH_SOUND_HINT="預設開啟柔和的遊戲提示音。短時間內的配對合併提示，聲音間隔至少30秒。清單已開啟時不播放。遵循遊戲聲音設定。",
        QUEST_SOUND_PREVIEW="測試聲音", QUEST_SOUND_PREVIEW_HINT="播放一次提示音，即使自動提示音已關閉。不會更改設定或自動提示音的間隔。",
        QUEST_ANIMATION_PREVIEW="測試動畫", QUEST_ANIMATION_PREVIEW_HINT="預覽所選圖示或任務列的動畫，即使自動動畫已關閉。計數和未讀標記維持不變。",
        QUEST_ANIMATION_UNAVAILABLE="圖示或任務列暫時無法預覽。如果正在戰鬥，請在脫戰後重試。",
        QUEST_SOUND_UNAVAILABLE="無法確認提示音播放，請檢查聲音設定。",
    },
}
for key,value in pairs(attentionStrings.enUS) do NS.english[key]=value end
local attentionLocale=attentionStrings[NS.clientLocale=="esMX" and "esES" or NS.clientLocale]
if attentionLocale and NS.translation then for key,value in pairs(attentionLocale) do NS.translation[key]=value end end

function NS.QuestCountText(n)
    local form=n==1 and "ONE" or "MANY"
    if NS.clientLocale=="frFR" and n==0 then form="ONE" end
    if NS.clientLocale=="ruRU" then
        local ending=n%100
        if ending<11 or ending>14 then
            if n%10==1 then form="ONE" elseif n%10>=2 and n%10<=4 then form="FEW" end
        end
    end
    return NS.Text("QUEST_LAUNCHER_QUEST_"..form,n)
end

local minimapStrings={
    enUS={
        QUEST_MINIMAP_MODE="Use a minimap icon instead of the bar",
        QUEST_MINIMAP_MODE_HINT="The icon shows the number of shared quests. Drag it around the minimap; position is saved for this character. Turn this off to restore the bar. Changes during combat apply after combat.",
        QUEST_MINIMAP_HINT="Left-click to open or close the quest browser. Drag with the left mouse button around the minimap; position is saved for this character.",
    },
    ruRU={
        QUEST_MINIMAP_MODE="Иконка у миникарты вместо баннера",
        QUEST_MINIMAP_MODE_HINT="Иконка показывает число общих заданий. Перетаскивайте её по краю миникарты; положение сохраняется для персонажа. Снимите галочку, чтобы вернуть баннер. В бою смена применяется после его окончания.",
        QUEST_MINIMAP_HINT="Левая кнопка: открыть или закрыть список заданий и игроков. Перетащите иконку левой кнопкой по краю миникарты; положение сохраняется для персонажа.",
    },
    deDE={
        QUEST_MINIMAP_MODE="Minikartensymbol statt Leiste verwenden",
        QUEST_MINIMAP_MODE_HINT="Das Symbol zeigt die Anzahl gemeinsamer Quests. Ziehe es um die Minikarte; die Position wird für diesen Charakter gespeichert. Deaktivieren, um die Leiste wiederherzustellen. Änderungen im Kampf gelten danach.",
        QUEST_MINIMAP_HINT="Linksklick: die Questübersicht öffnen oder schließen. Mit der linken Maustaste um die Minikarte ziehen; die Position wird für diesen Charakter gespeichert.",
    },
    frFR={
        QUEST_MINIMAP_MODE="Utiliser une icône de minicarte au lieu de la barre",
        QUEST_MINIMAP_MODE_HINT="L’icône indique le nombre de quêtes communes. Faites-la glisser autour de la minicarte ; sa position est enregistrée pour ce personnage. Désactivez pour retrouver la barre. Les changements en combat s’appliquent ensuite.",
        QUEST_MINIMAP_HINT="Clic gauche : ouvrir ou fermer la liste des quêtes et des joueurs. Faites glisser l’icône autour de la minicarte avec le bouton gauche ; sa position est enregistrée pour ce personnage.",
    },
    esES={
        QUEST_MINIMAP_MODE="Usar un icono de minimapa en lugar de la barra",
        QUEST_MINIMAP_MODE_HINT="El icono muestra el número de misiones comunes. Arrástralo alrededor del minimapa; la posición se guarda para este personaje. Desactiva para recuperar la barra. Los cambios durante el combate se aplican al terminar.",
        QUEST_MINIMAP_HINT="Clic izquierdo: abrir o cerrar la lista de misiones y jugadores. Arrastra el icono alrededor del minimapa con el botón izquierdo; la posición se guarda para este personaje.",
    },
    zhCN={
        QUEST_MINIMAP_MODE="使用小地图图标代替任务栏",
        QUEST_MINIMAP_MODE_HINT="图标显示共同任务数量。按住左键沿小地图边缘拖动；位置为当前角色保存。取消勾选可恢复任务栏。战斗中的更改会在脱战后生效。",
        QUEST_MINIMAP_HINT="左键：打开或关闭任务和玩家列表。按住左键沿小地图边缘拖动图标；位置会为当前角色保存。",
    },
    zhTW={
        QUEST_MINIMAP_MODE="使用小地圖圖示取代任務列",
        QUEST_MINIMAP_MODE_HINT="圖示顯示共同任務數量。按住左鍵沿小地圖邊緣拖曳；位置為目前角色儲存。取消勾選可恢復任務列。戰鬥中的變更會在脫戰後生效。",
        QUEST_MINIMAP_HINT="左鍵：開啟或關閉任務和玩家清單。按住左鍵沿小地圖邊緣拖曳圖示；位置會為目前角色儲存。",
    },
}
for key,value in pairs(minimapStrings.enUS) do NS.english[key]=value end
local minimapLocale=minimapStrings[NS.clientLocale=="esMX" and "esES" or NS.clientLocale]
if minimapLocale and NS.translation then for key,value in pairs(minimapLocale) do NS.translation[key]=value end end
