-- Short search introduction. Screenshot language follows the client.
local _,NS=...
local strings={
    enUS={
        QUEST_TUTORIAL_SEARCH_TITLE="Find a group or build your own",
        QUEST_TUTORIAL_SEARCH_LEAD="Open Group Finder with the magnifying glass. Choose activities and languages, then click %s.",
        QUEST_TUTORIAL_SEARCH_SEEK_BODY="In the %s list, choose %s. Select your roles and use %s beside a suitable group.",
        QUEST_TUTORIAL_SEARCH_RECRUIT_BODY="In the %s list, choose %s. Select the roles you need and use %s beside a suitable player.",
        QUEST_TUTORIAL_SEARCH_LISTING_HINT="Create a listing on the eye tab so others can find your party.",
    },
    ruRU={
        QUEST_TUTORIAL_SEARCH_TITLE="Найди группу или собери свою",
        QUEST_TUTORIAL_SEARCH_LEAD="Открой поиск по лупе, выбери занятия и языки. Затем нажми «%s».",
        QUEST_TUTORIAL_SEARCH_SEEK_BODY="В списке «%s» выбери «%s». Отметь подходящие роли и нажми «%s» рядом с нужной группой.",
        QUEST_TUTORIAL_SEARCH_RECRUIT_BODY="В списке «%s» выбери «%s». Укажи нужные роли и приглашай игроков кнопкой «%s».",
        QUEST_TUTORIAL_SEARCH_LISTING_HINT="Объявление на вкладке с глазом позволит другим найти твою группу.",
    },
    deDE={
        QUEST_TUTORIAL_SEARCH_TITLE="Gruppe finden oder selbst bilden",
        QUEST_TUTORIAL_SEARCH_LEAD="Öffne die Suche über die Lupe. Wähle Aktivitäten und Sprachen, dann %s.",
        QUEST_TUTORIAL_SEARCH_SEEK_BODY="Wähle unter %s die Option %s. Wähle passende Rollen und kontaktiere eine Gruppe mit %s.",
        QUEST_TUTORIAL_SEARCH_RECRUIT_BODY="Wähle unter %s die Option %s. Wähle die gesuchten Rollen und lade passende Spieler mit %s ein.",
        QUEST_TUTORIAL_SEARCH_LISTING_HINT="Erstelle über den Augen-Reiter einen Eintrag, damit andere deine Gruppe finden.",
    },
    koKR={
        QUEST_TUTORIAL_SEARCH_TITLE="파티를 찾거나 직접 모으세요",
        QUEST_TUTORIAL_SEARCH_LEAD="돋보기로 파티 찾기를 여세요. 활동과 언어를 고른 뒤 %s을 누르세요.",
        QUEST_TUTORIAL_SEARCH_SEEK_BODY="%s에서 %s를 고르세요. 가능한 역할을 선택한 뒤 원하는 파티 옆의 %s로 연락하세요.",
        QUEST_TUTORIAL_SEARCH_RECRUIT_BODY="%s에서 %s을 고르세요. 필요한 역할을 선택하고 원하는 플레이어 옆의 %s를 누르세요.",
        QUEST_TUTORIAL_SEARCH_LISTING_HINT="눈 모양 탭에서 등록하면 다른 플레이어도 내 파티를 찾을 수 있어요.",
    },
    frFR={
        QUEST_TUTORIAL_SEARCH_TITLE="Trouvez un groupe ou formez le vôtre",
        QUEST_TUTORIAL_SEARCH_LEAD="Ouvrez la recherche avec la loupe. Choisissez les activités et les langues, puis %s.",
        QUEST_TUTORIAL_SEARCH_SEEK_BODY="Dans %s, choisissez %s. Sélectionnez vos rôles et contactez un groupe avec %s.",
        QUEST_TUTORIAL_SEARCH_RECRUIT_BODY="Dans %s, choisissez %s. Sélectionnez les rôles recherchés et invitez les joueurs avec %s.",
        QUEST_TUTORIAL_SEARCH_LISTING_HINT="Créez une annonce via l’onglet en forme d’œil pour que les autres trouvent votre groupe.",
    },
    esES={
        QUEST_TUTORIAL_SEARCH_TITLE="Busca un grupo o forma el tuyo",
        QUEST_TUTORIAL_SEARCH_LEAD="Abre el buscador con la lupa. Elige actividades e idiomas y pulsa %s.",
        QUEST_TUTORIAL_SEARCH_SEEK_BODY="En %s, elige %s. Marca tus funciones y usa %s junto al grupo que te interese.",
        QUEST_TUTORIAL_SEARCH_RECRUIT_BODY="En %s, elige %s. Marca las funciones que necesitas y usa %s junto a un jugador adecuado.",
        QUEST_TUTORIAL_SEARCH_LISTING_HINT="Crea un anuncio en la pestaña del ojo para que otros encuentren tu grupo.",
    },
    zhCN={
        QUEST_TUTORIAL_SEARCH_TITLE="寻找队伍或自行组队",
        QUEST_TUTORIAL_SEARCH_LEAD="点击放大镜打开队伍查找器。选择活动和交流语言，然后点击%s。",
        QUEST_TUTORIAL_SEARCH_SEEK_BODY="在%s列表中选择%s。勾选适合的职责，点击目标队伍旁的%s。",
        QUEST_TUTORIAL_SEARCH_RECRUIT_BODY="在%s列表中选择%s。选择所需职责，点击合适玩家旁的%s。",
        QUEST_TUTORIAL_SEARCH_LISTING_HINT="在眼睛图标页签发布招募，让其他玩家也能找到你的队伍。",
    },
    zhTW={
        QUEST_TUTORIAL_SEARCH_TITLE="尋找隊伍或自行組隊",
        QUEST_TUTORIAL_SEARCH_LEAD="點擊放大鏡開啟隊伍搜尋器。選擇活動和交流語言，然後點擊%s。",
        QUEST_TUTORIAL_SEARCH_SEEK_BODY="在%s清單中選擇%s。勾選適合的職責，點擊目標隊伍旁的%s。",
        QUEST_TUTORIAL_SEARCH_RECRUIT_BODY="在%s清單中選擇%s。選擇所需職責，點擊合適玩家旁的%s。",
        QUEST_TUTORIAL_SEARCH_LISTING_HINT="在眼睛圖示分頁刊登招募，讓其他玩家也能找到你的隊伍。",
    },
    ptBR={
        QUEST_TUTORIAL_SEARCH_TITLE="Encontre um grupo ou forme o seu",
        QUEST_TUTORIAL_SEARCH_LEAD="Abra a busca pela lupa. Escolha atividades e idiomas e clique em %s.",
        QUEST_TUTORIAL_SEARCH_SEEK_BODY="Em %s, escolha %s. Marque suas funções e use %s ao lado de um grupo adequado.",
        QUEST_TUTORIAL_SEARCH_RECRUIT_BODY="Em %s, escolha %s. Marque as funções necessárias e use %s ao lado de um jogador adequado.",
        QUEST_TUTORIAL_SEARCH_LISTING_HINT="Crie um anúncio na aba do olho para que outros encontrem seu grupo.",
    },
    itIT={
        QUEST_TUTORIAL_SEARCH_TITLE="Trova un gruppo o forma il tuo",
        QUEST_TUTORIAL_SEARCH_LEAD="Apri la ricerca con la lente. Scegli attività e lingue, poi clicca su %s.",
        QUEST_TUTORIAL_SEARCH_SEEK_BODY="In %s, scegli %s. Seleziona i tuoi ruoli e usa %s accanto al gruppo desiderato.",
        QUEST_TUTORIAL_SEARCH_RECRUIT_BODY="In %s, scegli %s. Seleziona i ruoli necessari e usa %s accanto a un giocatore adatto.",
        QUEST_TUTORIAL_SEARCH_LISTING_HINT="Crea un annuncio nella scheda con l’occhio perché altri trovino il tuo gruppo.",
    },
}
for key,value in pairs(strings.enUS) do NS.english[key]=value end
local localized=strings[NS.clientLocale=="esMX" and "esES" or NS.clientLocale]
if localized and NS.translation then for key,value in pairs(localized) do NS.translation[key]=value end end
