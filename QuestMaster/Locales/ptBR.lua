-- QuestMaster Portuguese (Brazilian) Localization
local addonName, QM = ...
if GetLocale() ~= "ptBR" then return end

local L = QM.L

-- ============================================================================
-- General
-- ============================================================================
L["ADDON_NAME"] = "QuestMaster"
L["ADDON_LOADED"] = "QuestMaster carregado. Digite /qm para opções."
L["VERSION"] = "Versão"
L["ENABLED"] = "Ativado"
L["DISABLED"] = "Desativado"
L["YES"] = "Sim"
L["NO"] = "Não"
L["DEFAULT"] = "Padrão"
L["RESET"] = "Resetar"
L["CLOSE"] = "Fechar"
L["SAVE"] = "Salvar"
L["CANCEL"] = "Cancelar"
L["DELETE"] = "Excluir"
L["UNKNOWN"] = "Desconhecido"
L["NONE"] = "Nenhum"
L["GO"] = "Ir"
L["SEARCH"] = "Buscar"
L["REFRESHED"] = "Atualizado"

-- ============================================================================
-- Tabs
-- ============================================================================
L["TAB_GENERAL"] = "Geral"
L["TAB_GENERAL_DESC"] = "Configurações principais"
L["TAB_TRACKER"] = "Rastreador"
L["TAB_TRACKER_DESC"] = "Lista de missões"
L["TAB_ARROW"] = "Seta"
L["TAB_ARROW_DESC"] = "Navegação"
L["TAB_MAP"] = "Mapa"
L["TAB_MAP_DESC"] = "Marcadores"
L["TAB_STATISTICS"] = "Estatísticas"
L["TAB_STATISTICS_DESC"] = "Rastreamento de XP"
L["TAB_DASHBOARD"] = "Painel"
L["TAB_DASHBOARD_DESC"] = "Estatísticas e histórico"
L["TAB_AUTOMATION"] = "Automação"
L["TAB_AUTOMATION_DESC"] = "Recursos automáticos"
L["TAB_ADVANCED"] = "Avançado"
L["TAB_ADVANCED_DESC"] = "Especialista"
L["TAB_CREDITS"] = "Créditos"
L["TAB_CREDITS_DESC"] = "Sobre & Links"

-- ============================================================================
-- Settings Header
-- ============================================================================
L["SETTINGS"] = "Configurações"
L["SETTINGS_TITLE"] = "Configurações do QuestMaster"

-- ============================================================================
-- General Settings
-- ============================================================================
L["MAIN_SETTINGS"] = "Configurações Principais"
L["ENABLE_ADDON"] = "Ativar QuestMaster"
L["ENABLE_ADDON_DESC"] = "Interruptor principal para todos os recursos"
L["LOCK_FRAMES"] = "Travar Posição dos Quadros"
L["LOCK_FRAMES_DESC"] = "Prevenir arrasto"
L["SHOW_MINIMAP_BUTTON"] = "Mostrar Botão no Minimapa"
L["SHOW_MINIMAP_BUTTON_DESC"] = "Botão no minimapa"

-- ============================================================================
-- Sounds
-- ============================================================================
L["SOUNDS"] = "Efeitos Sonoros"
L["QUEST_PROGRESS_SOUND"] = "Som de Progresso da Missão"
L["QUEST_PROGRESS_SOUND_DESC"] = "Som ao progredir"
L["QUEST_COMPLETE_SOUND"] = "Som de Missão Completa"
L["QUEST_COMPLETE_SOUND_DESC"] = "Som ao completar"

-- ============================================================================
-- Announcements
-- ============================================================================
L["QUEST_ANNOUNCEMENTS"] = "Anúncios de Missão"
L["ANNOUNCE_ACCEPT"] = "Anunciar Aceitação de Missão"
L["ANNOUNCE_ACCEPT_DESC"] = "Para grupo/guilda"
L["ACCEPT_CHANNEL"] = "Canal de Aceitação"
L["ANNOUNCE_DONE"] = "Anunciar Missão Concluída"
L["ANNOUNCE_DONE_DESC"] = "Para grupo/guilda"
L["COMPLETE_CHANNEL"] = "Canal de Conclusão"
L["CHANNEL_PARTY"] = "Grupo"
L["CHANNEL_GUILD"] = "Guilda"
L["CHANNEL_EMOTE"] = "Emote (/me)"
L["CHANNEL_DISABLED"] = "Desativado"

-- Level Up
L["LEVEL_UP_ANNOUNCEMENTS"] = "Anúncios de Subida de Nível"
L["ANNOUNCE_LEVEL_UP"] = "Anunciar Subida de Nível"
L["ANNOUNCE_LEVEL_UP_DESC"] = "Para emote/grupo"
L["LEVEL_UP_CHANNEL"] = "Canal de Subida de Nível"

-- ============================================================================
-- Quick Actions
-- ============================================================================
L["QUICK_ACTIONS"] = "Ações Rápidas"
L["RESET_POSITIONS"] = "Resetar Posições"
L["REFRESH_DATA"] = "Atualizar Dados"

-- ============================================================================
-- Quest Tracker
-- ============================================================================
L["QUEST_TRACKER"] = "Rastreador de Missões"
L["ENABLE_TRACKER"] = "Ativar Rastreador"
L["ENABLE_TRACKER_DESC"] = "Mostrar painel de missões"
L["FONT_SIZE"] = "Tamanho da Fonte"
L["BACKGROUND_OPACITY"] = "Opacidade do Fundo"
L["TRACKER_TITLE"] = "QuestMaster"
L["ACTIVE_QUESTS"] = "Missões Ativas"
L["READY_FOR_TURNIN"] = "Pronto para Entregar"
L["NO_ACTIVE_QUESTS"] = "Nenhuma missão ativa"

-- Display Options
L["DISPLAY_OPTIONS"] = "Opções de Exibição"
L["SHOW_QUEST_LEVEL"] = "Mostrar Nível da Missão"
L["SHOW_QUEST_LEVEL_DESC"] = "Nível entre colchetes"
L["SHOW_DISTANCE"] = "Mostrar Distância"
L["SHOW_DISTANCE_DESC"] = "Distância até o objetivo"
L["COLOR_BY_DIFFICULTY"] = "Colorir por Dificuldade"
L["COLOR_BY_DIFFICULTY_DESC"] = "Cores baseadas no nível"
L["SHOW_PROGRESS_BARS"] = "Mostrar Barras de Progresso"
L["SHOW_PROGRESS_BARS_DESC"] = "Barras sob os objetivos"
L["SHOW_COMPLETED"] = "Mostrar Missões Completas"
L["SHOW_COMPLETED_DESC"] = "Exibir missões finalizadas"
L["MAX_QUESTS"] = "Máximo de Missões Mostradas"

-- Default Tracker
L["HIDE_BLIZZARD_TRACKER"] = "Ocultar rastreador de missões padrão"
L["HIDE_BLIZZARD_TRACKER_DESC"] = "Ocultar o rastreador de missões padrão da Blizzard"
L["HIDE_BLIZZARD_TRACKER_COMBAT"] = "Não é possível alternar o rastreador padrão durante o combate."
L["HIDE_BLIZZARD_TRACKER_RELOAD"] = "Reativar o rastreador padrão requer recarregar a interface. Recarregar agora?"

-- Sorting
L["SORTING"] = "Ordenação"
L["SORT_BY"] = "Ordenar Por"
L["SORT_QUESTS_BY"] = "Ordenar Missões Por"
L["SORT_DISTANCE"] = "Distância"
L["SORT_LEVEL"] = "Nível"
L["CURRENT"] = "Atual"

-- Tracker Buttons
L["SORT"] = "Ordenar"
L["NAVIGATE_TO_NEAREST"] = "Navegar para o Mais Próximo"
L["CLICK_TO_SET_WAYPOINT"] = "Clique para definir ponto de referência"
L["NAVIGATE_TO_TURNIN"] = "Navegar para Entrega"
L["NEAREST_COMPLETED_QUEST"] = "Missão completa mais próxima"

-- ============================================================================
-- Arrow
-- ============================================================================
L["NAVIGATION_ARROW"] = "Seta de Navegação"
L["ENABLE_ARROW"] = "Ativar Seta"
L["ENABLE_ARROW_DESC"] = "Mostrar seta de navegação"
L["ARROW_SIZE"] = "Tamanho da Seta"
L["ARROW_OPACITY"] = "Opacidade da Seta"
L["ARRIVAL_DISTANCE"] = "Distância de Chegada"

-- Arrow Display
L["DISPLAY"] = "Exibição"
L["SHOW_OBJECTIVE"] = "Mostrar Objetivo"
L["SHOW_OBJECTIVE_DESC"] = "Texto do objetivo"
L["SHOW_ETA"] = "Mostrar Tempo Estimado"
L["SHOW_ETA_DESC"] = "Estimativa de tempo"

-- Arrow Status
L["ARRIVED"] = "Chegou!"
L["NO_ACTIVE_OBJECTIVE"] = "Nenhum objetivo ativo"
L["QUEST_OBJECTIVE"] = "Objetivo da Missão"
L["YARDS"] = "jardas"
L["KILOMETERS"] = "km"

-- Arrow Tooltip
L["ARROW_NAVIGATION"] = "Navegação"
L["OBJECTIVE"] = "Objetivo"
L["LEFT_CLICK_DRAG"] = "Clique esquerdo + arraste para mover"
L["RIGHT_CLICK_OPTIONS"] = "Clique direito para opções"

-- Arrow Context Menu
L["HIDE_ARROW"] = "Esconder Seta"
L["CLEAR_WAYPOINT"] = "Limpar Ponto de Referência"
L["FIND_NEAREST_AUTO"] = "Encontrar Mais Próximo (Auto)"
L["OPEN_SETTINGS"] = "Abrir Configurações"

-- ETA
L["ETA"] = "Tempo Estimado"
L["ETA_SECONDS"] = "TE: %ds"
L["ETA_MINUTES"] = "TE: %dm %ds"
L["ETA_HOURS"] = "TE: %dh %dm"
L["MOVE_TO_CALCULATE"] = "(Mova-se para calcular o tempo estimado)"

-- ============================================================================
-- Map
-- ============================================================================
L["WORLD_MAP"] = "Mapa-Múndi"
L["ENABLE_MAP_PINS"] = "Ativar Marcadores no Mapa"
L["ENABLE_MAP_PINS_DESC"] = "Mostrar marcadores de missão"
L["PIN_SIZE"] = "Tamanho do Marcador"
L["PIN_OPACITY"] = "Opacidade do Marcador"

-- Pin Types
L["PIN_TYPES"] = "Tipos de Marcador"
L["OBJECTIVE_PINS"] = "Marcadores de Objetivo"
L["OBJECTIVE_PINS_DESC"] = "Objetivos de missão"
L["QUEST_AREAS"] = "Áreas de Missão"
L["QUEST_AREAS_DESC"] = "Destacar áreas"
L["TURNIN_PINS"] = "Marcadores de Entrega (?)"
L["TURNIN_PINS_DESC"] = "Marcadores ? amarelos"
L["AVAILABLE_QUESTS"] = "Missões Disponíveis (!)"
L["AVAILABLE_QUESTS_DESC"] = "Marcadores ! amarelos"
L["PATROL_PATHS"] = "Rotas de Patrulha de NPCs"
L["PATROL_PATHS_DESC"] = "Mostrar rotas de patrulha"

-- ============================================================================
-- Statistics Tab
-- ============================================================================
L["QUEST_TIMER"] = "Cronômetro de Missão"
L["ENABLE_TIMER"] = "Ativar Cronômetro"
L["ENABLE_TIMER_DESC"] = "Rastrear tempo de missão"
L["SHOW_IN_TRACKER"] = "Mostrar no Rastreador"
L["SHOW_IN_TRACKER_DESC"] = "Exibir no rastreador"

L["XP_PER_HOUR"] = "XP/Hora"
L["ENABLE_XP_TRACKER"] = "Ativar Rastreador de XP"
L["ENABLE_XP_TRACKER_DESC"] = "Calcular taxa de XP"
L["RESET_XP"] = "Resetar XP"

L["RESTED_XP"] = "XP Descansado"
L["ENABLE_RESTED_DISPLAY"] = "Ativar Exibição de XP Descansado"
L["ENABLE_RESTED_DISPLAY_DESC"] = "Mostrar XP descansado"
L["SHOW_BONUS_INDICATOR"] = "Mostrar Bônus +50%"
L["SHOW_BONUS_INDICATOR_DESC"] = "Mostrar indicador de bônus"

L["LEVEL_TIME"] = "Tempo por Nível"
L["ENABLE_LEVEL_TIMER"] = "Ativar Cronômetro de Nível"
L["ENABLE_LEVEL_TIMER_DESC"] = "Rastrear tempo por nível"
L["SHOW_AVERAGE"] = "Mostrar Média"
L["SHOW_AVERAGE_DESC"] = "Exibir tempo médio"

L["REMINDERS"] = "Lembretes"
L["ENABLE_REMINDERS"] = "Ativar Lembretes"
L["ENABLE_REMINDERS_DESC"] = "Avisos de bolsas e reparos"
L["BAG_SPACE_WARNING"] = "Aviso de Espaço nas Bolsas"
L["BAG_SPACE_WARNING_DESC"] = "Avisar quando bolsas cheias"
L["BAG_THRESHOLD"] = "Limite de Bolsa"
L["REPAIR_WARNING"] = "Aviso de Reparo"
L["REPAIR_WARNING_DESC"] = "Avisar durabilidade baixa"

L["ZONE_PROGRESS"] = "Progresso por Zona"
L["ENABLE_ZONE_PROGRESS"] = "Ativar Progresso por Zona"
L["ENABLE_ZONE_PROGRESS_DESC"] = "Rastrear por zona"

L["REPUTATION"] = "Reputação"
L["ENABLE_REP_TRACKER"] = "Ativar Rastreador de Reputação"
L["ENABLE_REP_TRACKER_DESC"] = "Rastrear facção observada"

-- Quest Statistics
L["QUEST_STATISTICS"] = "Estatísticas de Missão"
L["TOTAL_STATISTICS"] = "Estatísticas Totais"
L["QUESTS_COMPLETED"] = "Missões Completadas"
L["TOTAL_XP_GAINED"] = "XP Total Ganho"
L["AVG_QUEST_TIME"] = "Tempo Médio por Missão"
L["QUESTS_PER_HOUR"] = "Missões por Hora"
L["CURRENT_LEVEL"] = "Nível Atual"
L["TIME_ON_LEVEL"] = "Tempo no Nível"
L["SESSION_QUESTS"] = "Missões da Sessão"
L["SESSION_XP"] = "XP da Sessão"
L["REFRESH_STATS"] = "Atualizar Estatísticas"
L["RESET_SESSION"] = "Resetar Sessão"

-- Quest Search
L["QUEST_SEARCH"] = "Busca de Missão"
L["SEARCH_PLACEHOLDER"] = "Digite o nome ou ID da missão..."
L["CLICK_RESULT_HINT"] = "Clique em um resultado para definir ponto de referência no local inicial da missão"
L["NO_QUESTS_FOUND"] = "Nenhuma missão encontrada correspondendo:"
L["WAYPOINT_SET_TO_QUEST"] = "Ponto de referência definido para missão:"
L["NO_LOCATION_DATA"] = "Sem dados de localização para:"
L["QUEST_LABEL"] = "Missão:"
L["OBJECTIVES_LABEL"] = "Objetivos:"

-- Manual Waypoint
L["MANUAL_WAYPOINT"] = "Ponto de Referência Manual"
L["WAYPOINT"] = "Ponto de Referência"
L["MANUAL"] = "[Manual]"
L["CURRENT_WAYPOINT"] = "Atual:"
L["NO_WAYPOINT_SET"] = "Nenhum ponto de referência definido"
L["X_COORD"] = "X:"
L["Y_COORD"] = "Y:"
L["SET"] = "Definir"
L["INVALID_COORDINATES"] = "Coordenadas inválidas (0-100)"
L["COORD_HINT"] = "Digite coordenadas como 45.5 e 67.2 (valores 0-100)"
L["CLEAR_WAYPOINT"] = "Limpar Ponto de Referência"

-- ============================================================================
-- Automation Tab
-- ============================================================================
L["QUEST_AUTOMATION"] = "Automação de Missões"
L["AUTO_ACCEPT"] = "Auto-Aceitar Missões"
L["AUTO_ACCEPT_DESC"] = "Shift para pular"
L["AUTO_COMPLETE"] = "Auto-Completar Missões"
L["AUTO_COMPLETE_DESC"] = "Shift para pular"
L["SKIP_REWARD_CHOICE"] = "Pular Escolha de Recompensa"
L["SKIP_REWARD_CHOICE_DESC"] = "Aguardar seleção"
L["AUTO_SHARE"] = "Auto-Compartilhar Missões"
L["AUTO_SHARE_DESC"] = "Compartilhar com grupo"

L["WAYPOINT_AUTO"] = "Ponto de Referência Automático"
L["AUTO_SET_WAYPOINT"] = "Auto-Definir Ponto de Referência"
L["AUTO_SET_WAYPOINT_DESC"] = "Missão mais próxima"
L["AUTO_ADVANCE"] = "Auto-Avançar"
L["AUTO_ADVANCE_DESC"] = "Próxima ao completar"
L["PRIORITIZE_TURNINS"] = "Priorizar Entregas"
L["PRIORITIZE_TURNINS_DESC"] = "Entregas primeiro"

L["QUEST_FILTERS"] = "Filtros de Missão"
L["SHOW_DUNGEON"] = "Mostrar Missões de Masmorra"
L["SHOW_DUNGEON_DESC"] = "Incluir missões de masmorra"
L["SHOW_RAID"] = "Mostrar Missões de Raide"
L["SHOW_RAID_DESC"] = "Incluir missões de raide"
L["SHOW_GROUP"] = "Mostrar Missões de Grupo"
L["SHOW_GROUP_DESC"] = "Incluir missões de grupo"
L["SHOW_PVP"] = "Mostrar Missões PvP"
L["SHOW_PVP_DESC"] = "Incluir missões PvP"
L["SHOW_LOW_LEVEL"] = "Mostrar Missões de Nível Baixo"
L["SHOW_LOW_LEVEL_DESC"] = "Incluir missões cinzas"

-- ============================================================================
-- Advanced Tab
-- ============================================================================
L["THEME"] = "Tema"
L["COLOR_THEME"] = "Tema de Cor"
L["THEME_GOLD"] = "Dourado (Padrão)"
L["THEME_BLUE"] = "Azul"
L["THEME_GREEN"] = "Verde"
L["THEME_RED"] = "Vermelho"
L["THEME_PURPLE"] = "Roxo"
L["THEME_ORANGE"] = "Laranja"
L["THEME_TEAL"] = "Cerceta"
L["THEME_PINK"] = "Rosa"
L["THEME_SILVER"] = "Prateado"
L["THEME_BRONZE"] = "Bronze"

L["PERFORMANCE"] = "Desempenho"
L["UPDATE_INTERVAL"] = "Intervalo de Atualização"
L["UPDATE_THROTTLE"] = "Limitação de Atualização"
L["REDUCE_MAP_UPDATES"] = "Reduzir Atualizações do Mapa"
L["REDUCE_MAP_UPDATES_DESC"] = "Atualizações preguiçosas"

L["QUEST_NOTES"] = "Notas de Missão"
L["MAX_NOTE_LENGTH"] = "Comprimento Máximo da Nota"

L["DEBUG_TOOLS"] = "Depuração e Ferramentas"
L["DEBUG_MODE"] = "Modo de Depuração"
L["DEBUG_MODE_DESC"] = "Info de depuração no chat"
L["RESET_SETTINGS"] = "Resetar Configurações"
L["RELOAD_UI"] = "Recarregar Interface"
L["RESET_CONFIRM"] = "Resetar todas as configurações do QuestMaster?"

-- ============================================================================
-- Credits Tab
-- ============================================================================
L["CREDITS_VERSION"] = "Versão 1.2"
L["CREDITS_EDITION"] = "Edição All-in-One"
L["CREDITS_DESCRIPTION"] = "Addon premium de rastreamento de missões com setas de navegação, marcadores de mapa, estatísticas e recursos de automação."
L["DEVELOPER"] = "Desenvolvedor"
L["ALSO_KNOWN_AS"] = "também conhecido como"
L["DEVELOPER_BIO"] = "Desenvolvedor de addons para WoW e criador de conteúdo. Transmitindo ao vivo em Twitch.tv/Novi_Live"
L["CONNECT"] = "Conectar"
L["TWITCH"] = "Twitch"
L["DISCORD"] = "Discord"
L["CURSEFORGE"] = "CurseForge"
L["DOWNLOADS_BUGS"] = "Downloads e Relatórios de Bugs"
L["CHANGELOG"] = "Registro de Mudanças"
L["SPECIAL_THANKS"] = "Agradecimentos Especiais"
L["THANKS_MESSAGE"] = "Para todos os espectadores, testadores e apoiadores na Twitch! Seu feedback ajuda a tornar o QuestMaster melhor."

-- ============================================================================
-- Info Bar Tooltip
-- ============================================================================
L["SESSION_STATISTICS"] = "Estatísticas da Sessão"
L["CURRENT_XP"] = "XP Atual:"
L["XP_REMAINING"] = "XP Restante:"
L["XP_PER_HOUR_LABEL"] = "XP por Hora:"
L["TIME_TO_LEVEL"] = "Tempo para Subir de Nível:"
L["SESSION_TIME"] = "Tempo de Sessão:"
L["RESTED_AMOUNT"] = "Quantidade Descansada:"
L["RESTED_BUBBLES"] = "Bolhas Descansadas:"
L["BONUS_XP"] = "XP Bônus:"
L["BONUS_UNTIL_DEPLETED"] = "+50% até esgotar"
L["CURRENT_LEVEL_LABEL"] = "Nível Atual:"
L["AVERAGE_PER_LEVEL"] = "Média por Nível:"
L["PROGRESS"] = "Progresso:"
L["STATUS"] = "Status"
L["BAG_SPACE"] = "Espaço nas Bolsas:"
L["FREE"] = "livre"
L["DURABILITY"] = "Durabilidade:"
L["LOWEST"] = "menor"
L["TRACKED_REPUTATIONS"] = "Reputações Rastreadas"
L["CLICK_TO_RESET_XP"] = "Clique para resetar rastreador de XP"

-- ============================================================================
-- Quest Display
-- ============================================================================
L["COMPLETE"] = "COMPLETA"
L["DONE"] = "FEITO"
L["TURN_IN"] = "Entregar"
L["TURN_IN_SUFFIX"] = " (Entregar)"
L["TIME_ON_QUEST"] = "Tempo na Missão:"
L["NOTE"] = "Nota:"
L["CLICK_SET_WAYPOINT"] = "Clique esquerdo: Definir ponto de referência"
L["CLICK_OPEN_QUESTLOG"] = "Shift+Clique esquerdo: Abrir registro de missões"
L["CLICK_MORE_OPTIONS"] = "Clique direito: Mais opções"
L["DISTANCE_TO_OBJECTIVE"] = "Distância até o objetivo mais próximo"

-- Context Menu
L["SET_WAYPOINT"] = "Definir Ponto de Referência"
L["SHOW_ON_MAP"] = "Mostrar no Mapa"
L["EXPAND_QUEST"] = "Expandir Missão"
L["COLLAPSE_QUEST"] = "Recolher Missão"
L["EDIT_NOTE"] = "Editar Nota"
L["ADD_NOTE"] = "Adicionar Nota"
L["SHARE_QUEST"] = "Compartilhar Missão"
L["ABANDON_QUEST"] = "Abandonar missão"

-- ============================================================================
-- Chat Messages
-- ============================================================================
L["MSG_PREFIX"] = "|cFF00FF00QuestMaster:|r"
L["MSG_ADDON_LOADED"] = "|cFFFFD700QuestMaster|r carregado! criado por |cFF00FF00JugoBetrugoTV|r aka |cFFFF8800Novi_Live|r"
L["MSG_TWITCH"] = "|cFF9146FF  Twitch.tv/Novi_Live|r - Venha dar uma olhada!"
L["MSG_BUGS"] = "|cFF888888  Bugs? Reporte no CurseForge ou|r |cFF5865F2Discord.gg/rv2BsbE|r"

L["MSG_QUEST_ACCEPTED"] = "Missão aceita:"
L["MSG_ACCEPTED_QUEST"] = "Aceitou missão:"
L["MSG_QUEST_COMPLETED"] = "Missão completada:"
L["MSG_QUEST_READY"] = "Missão pronta para entregar:"
L["MSG_OBJECTIVE_COMPLETE"] = "Objetivo completo:"
L["MSG_ABANDONED"] = "Abandonada:"
L["MSG_SHARED"] = "Compartilhada:"
L["MSG_CANNOT_SHARE"] = "Esta missão não pode ser compartilhada"
L["MSG_QUEST_NOT_FOUND"] = "Não foi possível encontrar a missão no registro"

L["MSG_LEVEL_UP"] = "|cFFFFD700SUBIU DE NÍVEL!|r Você alcançou o nível |cFF00FF00%d|r!"
L["MSG_TIME_FROM_LEVEL"] = "Tempo do nível %d ao %d:"
L["MSG_REACHED_LEVEL"] = "Alcançou o nível %d!"
L["MSG_REACHED_LEVEL_TIME"] = "Alcançou o nível %d! (%s do nível %d)"

L["MSG_WAYPOINT_SET"] = "Ponto de referência definido para %.1f, %.1f - %s"
L["MSG_WAYPOINT_CORPSE"] = "Ponto de referência definido para a localização do seu corpo"
L["MSG_WAYPOINT_RESTORED"] = "Ponto de referência anterior restaurado"
L["MSG_NAVIGATING_TO"] = "Navegando para:"
L["MSG_AUTO_NAV_TURNIN"] = "Auto-navegando para entrega"
L["MSG_AUTO_NAV_TO"] = "Auto-navegando para:"
L["MSG_NO_QUESTS_NAV"] = "Nenhuma missão para navegar"
L["MSG_TURNIN"] = "Entregar:"
L["MSG_NO_COMPLETED"] = "Nenhuma missão completada para entregar"

L["MSG_XP_RESET"] = "Rastreador de XP/Hora resetado"
L["MSG_HISTORY_CLEARED"] = "Histórico de missões limpo"
L["MSG_SESSION_RESET"] = "Estatísticas da sessão resetadas"
L["MSG_NOTE_SAVED"] = "Nota salva para:"
L["MSG_NOTE_DELETED"] = "Nota excluída para:"

L["MSG_COORDS_INVALID"] = "Coordenadas devem estar entre 0 e 100"
L["MSG_NO_MAP"] = "Incapaz de determinar o mapa atual"
L["MSG_INVALID_COORDS"] = "Coordenadas inválidas. Use: /qm way 45.2 67.8"
L["MSG_DB_FAIL"] = "Falha ao inicializar banco de dados:"
L["MSG_DB_WARNING"] = "Aviso: Perfil de banco de dados não disponível"
L["MSG_INIT_FAIL"] = "Falha ao inicializar %s:"
L["MSG_SETTINGS_NOT_READY"] = "Configurações não prontas"
L["MSG_UNKNOWN_CMD"] = "Comando desconhecido. Digite /qm help para uma lista de comandos."

-- Help
L["HELP_USAGE"] = "Uso:"
L["HELP_SEARCH"] = "Uso: /qm search <nome ou id da missão>"
L["HELP_WAY"] = "Uso: /qm way <x> <y> [descrição]"
L["HELP_WAY_EXAMPLE"] = "  Exemplo: /qm way 45.2 67.8 Ponto de encontro"
L["HELP_CREDITS"] = "/qm credits - Mostrar créditos"
L["HELP_STATS"] = "/qm stats - Mostrar estatísticas de missão"
L["HELP_SEARCH_CMD"] = "/qm search <nome> - Buscar banco de dados de missões"
L["HELP_WAY_CMD"] = "/qm way <x> <y> [desc] - Definir ponto de referência manual"

-- Statistics Print
L["STATS_HEADER"] = "========== Estatísticas de Missão =========="
L["STATS_TOTAL_COMPLETED"] = "Total Completadas: %d missões"
L["STATS_TOTAL_XP"] = "XP Total de Missões:"
L["STATS_AVG_TIME"] = "Tempo Médio por Missão:"
L["STATS_QUESTS_HOUR"] = "Missões/Hora: %.1f"
L["STATS_FASTEST"] = "Missão Mais Rápida: %s (%s)"
L["STATS_SLOWEST"] = "Missão Mais Lenta: %s (%s)"
L["STATS_SESSION_HEADER"] = "--- Estatísticas da Sessão ---"
L["STATS_SESSION_COMPLETED"] = "Completadas nesta sessão: %d missões"
L["STATS_SESSION_XP"] = "XP desta sessão:"
L["STATS_TOP_ZONES"] = "--- Principais Zonas ---"

-- Search Results
L["SEARCH_NO_RESULTS"] = "Nenhuma missão encontrada para '%s'"
L["SEARCH_HEADER"] = "=== Busca de Missão: '%s' (%d resultados) ==="
L["SEARCH_COMPLETED"] = "[Completada]"
L["SEARCH_IN_PROGRESS"] = "[Em Progresso]"

-- Waypoint
L["WAYPOINT_FORMAT"] = "Ponto de Referência (%.1f, %.1f)"
L["YOUR_CORPSE"] = "Seu Corpo"

-- Tooltip
L["QUEST_ITEM"] = "Item de Missão"
L["DROP_RATE_NOTE"] = "(Taxa de queda estimada varia)"
L["QUEST_NOTE"] = "Nota de Missão"

-- Time Format
L["TIME_HOURS_MINS"] = "%dh %dmin"
L["TIME_HOURS"] = "%dh"
L["TIME_MINS"] = "%d min"
L["TIME_ZERO"] = "0 min"
L["AVG_FORMAT"] = "(média: %s)"
L["LVL_PREFIX"] = "Nível:"
L["XP_HOUR_PREFIX"] = "XP/h:"
L["RESTED_PREFIX"] = "Descansado:"

-- Responsive Layout
L["QM_SHORT"] = "QM"
L["QUESTS_SHORT"] = "Missões"

-- Quest Type Tags
L["DUNGEON_TAG"] = "D"
L["RAID_TAG"] = "R"
L["GROUP_TAG"] = "G"
L["DUNGEON_QUESTS"] = "Missões de masmorra"
L["RAID_QUESTS"] = "Missões de raide"
L["BEST"] = "Melhor"
L["MSG_NEW_BEST_TIME"] = "Novo recorde em %s: %s (anterior: %s)"

-- Party Quest Sync
L["PARTY_SYNC"] = "Sincronização de grupo"
L["ENABLE_PARTY_SYNC"] = "Ativar sync de grupo"
L["ENABLE_PARTY_SYNC_DESC"] = "Compartilhar progresso com o grupo"
L["PARTY_SHOW_PROGRESS"] = "Mostrar progresso do grupo"
L["PARTY_SHOW_PROGRESS_DESC"] = "Exibir no rastreador"
L["PARTY_SHOW_INDICATOR"] = "Indicador de grupo"
L["PARTY_SHOW_INDICATOR_DESC"] = "Ícone em missões compartilhadas"
L["PARTY_SYNC_ICON"] = "G"

-- Statistics Dashboard
L["DASHBOARD_TITLE"] = "Painel"
L["DASH_TITLE"] = "Painel de estatísticas"
L["OPEN_DASHBOARD"] = "Abrir painel"
L["DASH_OVERVIEW"] = "Visão geral"
L["DASH_ZONES"] = "Progresso por zona"
L["DASH_HISTORY"] = "Histórico de missões"
L["DASH_DETAILED_STATS"] = "Estatísticas detalhadas"
L["DASH_FASTEST_QUEST"] = "Missão mais rápida"
L["DASH_SLOWEST_QUEST"] = "Missão mais lenta"
L["DASH_TOP_ZONES"] = "Melhores zonas de missões"
L["DASH_OVERALL_PROGRESS"] = "Progresso geral"
L["DASH_NO_ZONE_DATA"] = "Sem dados de zona ainda"
L["DASH_NO_HISTORY"] = "Sem histórico de missões"
L["DASH_SHOWING_ENTRIES"] = "Mostrando %d de %d entradas"
L["DASH_MORE_ENTRIES"] = "... e mais %d entradas"
L["DASH_SORT_TIME"] = "Hora"
L["DASH_SORT_NAME"] = "Nome"
L["DASH_SORT_LEVEL"] = "Nível"
L["DASH_SORT_DURATION"] = "Duração"
L["DASH_COL_QUEST"] = "Missão"
L["DASH_COL_LEVEL"] = "Nív"
L["DASH_COL_XP"] = "XP"
L["DASH_COL_TIME"] = "Tempo"
L["DASH_COL_DATE"] = "Data"

-- Zone Filter & Minimap Tooltip
L["ZONE_FILTER"] = "Apenas zona atual"
L["ZONE_FILTER_DESC"] = "Mostrar apenas missões da zona atual"
L["MINIMAP_ACTIVE_QUESTS"] = "Missões ativas:"
L["MINIMAP_COMPLETED"] = "Completadas:"
L["MINIMAP_IN_ZONE"] = "Na zona:"
L["MINIMAP_CURRENT_WAYPOINT"] = "Ponto de rota atual:"
L["MINIMAP_NO_WAYPOINT"] = "Sem ponto de rota ativo"
L["MINIMAP_LEFT_CLICK"] = "Clique esquerdo: Abrir configurações"
L["MINIMAP_SHIFT_CLICK"] = "Shift+Clique esquerdo: Alternar rastreador"
L["MINIMAP_RIGHT_CLICK"] = "Clique direito: Alternar seta"
L["MINIMAP_MIDDLE_CLICK"] = "Clique do meio: Limpar ponto de rota"
