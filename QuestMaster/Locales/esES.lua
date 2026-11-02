-- QuestMaster Spanish Localization
local addonName, QM = ...
local locale = GetLocale()
if locale ~= "esES" and locale ~= "esMX" then return end

local L = QM.L

-- ============================================================================
-- General
-- ============================================================================
L["ADDON_NAME"] = "QuestMaster"
L["ADDON_LOADED"] = "QuestMaster cargado. Escribe /qm para opciones."
L["VERSION"] = "Versión"
L["ENABLED"] = "Activado"
L["DISABLED"] = "Desactivado"
L["YES"] = "Sí"
L["NO"] = "No"
L["DEFAULT"] = "Predeterminado"
L["RESET"] = "Reiniciar"
L["CLOSE"] = "Cerrar"
L["SAVE"] = "Guardar"
L["CANCEL"] = "Cancelar"
L["DELETE"] = "Eliminar"
L["UNKNOWN"] = "Desconocido"
L["NONE"] = "Ninguno"
L["GO"] = "Ir"
L["SEARCH"] = "Buscar"
L["REFRESHED"] = "Actualizado"

-- ============================================================================
-- Tabs
-- ============================================================================
L["TAB_GENERAL"] = "General"
L["TAB_GENERAL_DESC"] = "Configuración principal"
L["TAB_TRACKER"] = "Rastreador"
L["TAB_TRACKER_DESC"] = "Lista de misiones"
L["TAB_ARROW"] = "Flecha"
L["TAB_ARROW_DESC"] = "Navegación"
L["TAB_MAP"] = "Mapa"
L["TAB_MAP_DESC"] = "Pines y marcadores"
L["TAB_STATISTICS"] = "Estadísticas"
L["TAB_STATISTICS_DESC"] = "Seguimiento de EXP"
L["TAB_DASHBOARD"] = "Panel"
L["TAB_DASHBOARD_DESC"] = "Estadísticas e historial"
L["TAB_AUTOMATION"] = "Automatización"
L["TAB_AUTOMATION_DESC"] = "Funciones automáticas"
L["TAB_ADVANCED"] = "Avanzado"
L["TAB_ADVANCED_DESC"] = "Experto"
L["TAB_CREDITS"] = "Créditos"
L["TAB_CREDITS_DESC"] = "Acerca de y Enlaces"

-- ============================================================================
-- Settings Header
-- ============================================================================
L["SETTINGS"] = "Configuración"
L["SETTINGS_TITLE"] = "Configuración de QuestMaster"

-- ============================================================================
-- General Settings
-- ============================================================================
L["MAIN_SETTINGS"] = "Configuración Principal"
L["ENABLE_ADDON"] = "Activar QuestMaster"
L["ENABLE_ADDON_DESC"] = "Interruptor maestro para todas las funciones"
L["LOCK_FRAMES"] = "Bloquear Posición de Marcos"
L["LOCK_FRAMES_DESC"] = "Evitar arrastre"
L["SHOW_MINIMAP_BUTTON"] = "Mostrar Botón del Minimapa"
L["SHOW_MINIMAP_BUTTON_DESC"] = "Botón en el minimapa"

-- ============================================================================
-- Sounds
-- ============================================================================
L["SOUNDS"] = "Efectos de Sonido"
L["QUEST_PROGRESS_SOUND"] = "Sonido de Progreso de Misión"
L["QUEST_PROGRESS_SOUND_DESC"] = "Sonido al progresar"
L["QUEST_COMPLETE_SOUND"] = "Sonido de Misión Completada"
L["QUEST_COMPLETE_SOUND_DESC"] = "Sonido al completar"

-- ============================================================================
-- Announcements
-- ============================================================================
L["QUEST_ANNOUNCEMENTS"] = "Anuncios de Misiones"
L["ANNOUNCE_ACCEPT"] = "Anunciar Aceptación de Misión"
L["ANNOUNCE_ACCEPT_DESC"] = "Al grupo/hermandad"
L["ACCEPT_CHANNEL"] = "Canal de Aceptación"
L["ANNOUNCE_DONE"] = "Anunciar Misión Completada"
L["ANNOUNCE_DONE_DESC"] = "Al grupo/hermandad"
L["COMPLETE_CHANNEL"] = "Canal de Completado"
L["CHANNEL_PARTY"] = "Grupo"
L["CHANNEL_GUILD"] = "Hermandad"
L["CHANNEL_EMOTE"] = "Emoticono (/me)"
L["CHANNEL_DISABLED"] = "Desactivado"

-- Level Up
L["LEVEL_UP_ANNOUNCEMENTS"] = "Anuncios de Subida de Nivel"
L["ANNOUNCE_LEVEL_UP"] = "Anunciar Subida de Nivel"
L["ANNOUNCE_LEVEL_UP_DESC"] = "A emoticono/grupo"
L["LEVEL_UP_CHANNEL"] = "Canal de Subida de Nivel"

-- ============================================================================
-- Quick Actions
-- ============================================================================
L["QUICK_ACTIONS"] = "Acciones Rápidas"
L["RESET_POSITIONS"] = "Reiniciar Posiciones"
L["REFRESH_DATA"] = "Actualizar Datos"

-- ============================================================================
-- Quest Tracker
-- ============================================================================
L["QUEST_TRACKER"] = "Rastreador de Misiones"
L["ENABLE_TRACKER"] = "Activar Rastreador"
L["ENABLE_TRACKER_DESC"] = "Mostrar panel de misiones"
L["FONT_SIZE"] = "Tamaño de Fuente"
L["BACKGROUND_OPACITY"] = "Opacidad del Fondo"
L["TRACKER_TITLE"] = "QuestMaster"
L["ACTIVE_QUESTS"] = "Misiones Activas"
L["READY_FOR_TURNIN"] = "Listo para Entregar"
L["NO_ACTIVE_QUESTS"] = "No hay misiones activas"

-- Display Options
L["DISPLAY_OPTIONS"] = "Opciones de Visualización"
L["SHOW_QUEST_LEVEL"] = "Mostrar Nivel de Misión"
L["SHOW_QUEST_LEVEL_DESC"] = "Nivel entre corchetes"
L["SHOW_DISTANCE"] = "Mostrar Distancia"
L["SHOW_DISTANCE_DESC"] = "Distancia al objetivo"
L["COLOR_BY_DIFFICULTY"] = "Colorear por Dificultad"
L["COLOR_BY_DIFFICULTY_DESC"] = "Colores basados en nivel"
L["SHOW_PROGRESS_BARS"] = "Mostrar Barras de Progreso"
L["SHOW_PROGRESS_BARS_DESC"] = "Barras bajo objetivos"
L["SHOW_COMPLETED"] = "Mostrar Misiones Completadas"
L["SHOW_COMPLETED_DESC"] = "Mostrar misiones finalizadas"
L["MAX_QUESTS"] = "Máximo de Misiones Mostradas"

-- Default Tracker
L["HIDE_BLIZZARD_TRACKER"] = "Ocultar rastreador de misiones predeterminado"
L["HIDE_BLIZZARD_TRACKER_DESC"] = "Ocultar el rastreador de misiones de Blizzard"
L["HIDE_BLIZZARD_TRACKER_COMBAT"] = "No se puede cambiar el rastreador predeterminado durante el combate."
L["HIDE_BLIZZARD_TRACKER_RELOAD"] = "Reactivar el rastreador predeterminado requiere recargar la interfaz. ¿Recargar ahora?"

-- Sorting
L["SORTING"] = "Ordenamiento"
L["SORT_BY"] = "Ordenar Por"
L["SORT_QUESTS_BY"] = "Ordenar Misiones Por"
L["SORT_DISTANCE"] = "Distancia"
L["SORT_LEVEL"] = "Nivel"
L["CURRENT"] = "Actual"

-- Tracker Buttons
L["SORT"] = "Ordenar"
L["NAVIGATE_TO_NEAREST"] = "Navegar a la Más Cercana"
L["CLICK_TO_SET_WAYPOINT"] = "Clic para establecer punto de ruta"
L["NAVIGATE_TO_TURNIN"] = "Navegar a Entrega"
L["NEAREST_COMPLETED_QUEST"] = "Misión completada más cercana"

-- ============================================================================
-- Arrow
-- ============================================================================
L["NAVIGATION_ARROW"] = "Flecha de Navegación"
L["ENABLE_ARROW"] = "Activar Flecha"
L["ENABLE_ARROW_DESC"] = "Mostrar flecha de navegación"
L["ARROW_SIZE"] = "Tamaño de Flecha"
L["ARROW_OPACITY"] = "Opacidad de Flecha"
L["ARRIVAL_DISTANCE"] = "Distancia de Llegada"

-- Arrow Display
L["DISPLAY"] = "Visualización"
L["SHOW_OBJECTIVE"] = "Mostrar Objetivo"
L["SHOW_OBJECTIVE_DESC"] = "Texto del objetivo"
L["SHOW_ETA"] = "Mostrar Tiempo Estimado"
L["SHOW_ETA_DESC"] = "Estimación de tiempo"

-- Arrow Status
L["ARRIVED"] = "¡Llegaste!"
L["NO_ACTIVE_OBJECTIVE"] = "No hay objetivo activo"
L["QUEST_OBJECTIVE"] = "Objetivo de Misión"
L["YARDS"] = "m"
L["KILOMETERS"] = "km"

-- Arrow Tooltip
L["ARROW_NAVIGATION"] = "Navegación"
L["OBJECTIVE"] = "Objetivo"
L["LEFT_CLICK_DRAG"] = "Clic izquierdo + arrastrar para mover"
L["RIGHT_CLICK_OPTIONS"] = "Clic derecho para opciones"

-- Arrow Context Menu
L["HIDE_ARROW"] = "Ocultar Flecha"
L["CLEAR_WAYPOINT"] = "Limpiar Punto de Ruta"
L["FIND_NEAREST_AUTO"] = "Encontrar Más Cercano (Auto)"
L["OPEN_SETTINGS"] = "Abrir Configuración"

-- ETA
L["ETA"] = "Tiempo Estimado"
L["ETA_SECONDS"] = "Tiempo Estimado: %ds"
L["ETA_MINUTES"] = "Tiempo Estimado: %dm %ds"
L["ETA_HOURS"] = "Tiempo Estimado: %dh %dm"
L["MOVE_TO_CALCULATE"] = "(Muévete para calcular tiempo estimado)"

-- ============================================================================
-- Map
-- ============================================================================
L["WORLD_MAP"] = "Mapa del Mundo"
L["ENABLE_MAP_PINS"] = "Activar Pines en Mapa"
L["ENABLE_MAP_PINS_DESC"] = "Mostrar pines de misiones"
L["PIN_SIZE"] = "Tamaño de Pin"
L["PIN_OPACITY"] = "Opacidad de Pin"

-- Pin Types
L["PIN_TYPES"] = "Tipos de Pines"
L["OBJECTIVE_PINS"] = "Pines de Objetivos"
L["OBJECTIVE_PINS_DESC"] = "Objetivos de misiones"
L["QUEST_AREAS"] = "Áreas de Misiones"
L["QUEST_AREAS_DESC"] = "Resaltar áreas"
L["TURNIN_PINS"] = "Pines de Entrega (?)"
L["TURNIN_PINS_DESC"] = "Pines ? amarillos"
L["AVAILABLE_QUESTS"] = "Misiones Disponibles (!)"
L["AVAILABLE_QUESTS_DESC"] = "Pines ! amarillos"
L["PATROL_PATHS"] = "Rutas de Patrulla de NPCs"
L["PATROL_PATHS_DESC"] = "Mostrar rutas de patrulla"

-- ============================================================================
-- Statistics Tab
-- ============================================================================
L["QUEST_TIMER"] = "Temporizador de Misiones"
L["ENABLE_TIMER"] = "Activar Temporizador"
L["ENABLE_TIMER_DESC"] = "Rastrear tiempo de misión"
L["SHOW_IN_TRACKER"] = "Mostrar en Rastreador"
L["SHOW_IN_TRACKER_DESC"] = "Mostrar en rastreador"

L["XP_PER_HOUR"] = "EXP/Hora"
L["ENABLE_XP_TRACKER"] = "Activar Rastreador de EXP"
L["ENABLE_XP_TRACKER_DESC"] = "Calcular tasa de EXP"
L["RESET_XP"] = "Reiniciar EXP"

L["RESTED_XP"] = "EXP Descansada"
L["ENABLE_RESTED_DISPLAY"] = "Activar Visualización de Descanso"
L["ENABLE_RESTED_DISPLAY_DESC"] = "Mostrar EXP descansada"
L["SHOW_BONUS_INDICATOR"] = "Mostrar Bonificación +50%"
L["SHOW_BONUS_INDICATOR_DESC"] = "Mostrar indicador de bonificación"

L["LEVEL_TIME"] = "Tiempo por Nivel"
L["ENABLE_LEVEL_TIMER"] = "Activar Temporizador de Nivel"
L["ENABLE_LEVEL_TIMER_DESC"] = "Rastrear tiempo por nivel"
L["SHOW_AVERAGE"] = "Mostrar Promedio"
L["SHOW_AVERAGE_DESC"] = "Mostrar tiempo promedio"

L["REMINDERS"] = "Recordatorios"
L["ENABLE_REMINDERS"] = "Activar Recordatorios"
L["ENABLE_REMINDERS_DESC"] = "Avisos de bolsas y reparación"
L["BAG_SPACE_WARNING"] = "Aviso de Espacio en Bolsas"
L["BAG_SPACE_WARNING_DESC"] = "Avisar cuando bolsas llenas"
L["BAG_THRESHOLD"] = "Umbral de Bolsas"
L["REPAIR_WARNING"] = "Aviso de Reparación"
L["REPAIR_WARNING_DESC"] = "Avisar durabilidad baja"

L["ZONE_PROGRESS"] = "Progreso por Zona"
L["ENABLE_ZONE_PROGRESS"] = "Activar Progreso por Zona"
L["ENABLE_ZONE_PROGRESS_DESC"] = "Rastrear por zona"

L["REPUTATION"] = "Reputación"
L["ENABLE_REP_TRACKER"] = "Activar Rastreador de Reputación"
L["ENABLE_REP_TRACKER_DESC"] = "Rastrear facción observada"

-- Quest Statistics
L["QUEST_STATISTICS"] = "Estadísticas de Misiones"
L["TOTAL_STATISTICS"] = "Estadísticas Totales"
L["QUESTS_COMPLETED"] = "Misiones Completadas"
L["TOTAL_XP_GAINED"] = "EXP Total Ganada"
L["AVG_QUEST_TIME"] = "Tiempo Promedio por Misión"
L["QUESTS_PER_HOUR"] = "Misiones por Hora"
L["CURRENT_LEVEL"] = "Nivel Actual"
L["TIME_ON_LEVEL"] = "Tiempo en Nivel"
L["SESSION_QUESTS"] = "Misiones de Sesión"
L["SESSION_XP"] = "EXP de Sesión"
L["REFRESH_STATS"] = "Actualizar Estadísticas"
L["RESET_SESSION"] = "Reiniciar Sesión"

-- Quest Search
L["QUEST_SEARCH"] = "Búsqueda de Misiones"
L["SEARCH_PLACEHOLDER"] = "Ingresa nombre o ID de misión..."
L["CLICK_RESULT_HINT"] = "Haz clic en un resultado para establecer punto de ruta al inicio de la misión"
L["NO_QUESTS_FOUND"] = "No se encontraron misiones que coincidan con:"
L["WAYPOINT_SET_TO_QUEST"] = "Punto de ruta establecido para misión:"
L["NO_LOCATION_DATA"] = "No hay datos de ubicación para:"
L["QUEST_LABEL"] = "Misión:"
L["OBJECTIVES_LABEL"] = "Objetivos:"

-- Manual Waypoint
L["MANUAL_WAYPOINT"] = "Punto de Ruta Manual"
L["WAYPOINT"] = "Punto de Ruta"
L["MANUAL"] = "[Manual]"
L["CURRENT_WAYPOINT"] = "Actual:"
L["NO_WAYPOINT_SET"] = "No hay punto de ruta establecido"
L["X_COORD"] = "X:"
L["Y_COORD"] = "Y:"
L["SET"] = "Establecer"
L["INVALID_COORDINATES"] = "Coordenadas inválidas (0-100)"
L["COORD_HINT"] = "Ingresa coordenadas como 45.5 y 67.2 (valores 0-100)"
L["CLEAR_WAYPOINT"] = "Limpiar Punto de Ruta"

-- ============================================================================
-- Automation Tab
-- ============================================================================
L["QUEST_AUTOMATION"] = "Automatización de Misiones"
L["AUTO_ACCEPT"] = "Aceptar Misiones Automáticamente"
L["AUTO_ACCEPT_DESC"] = "Mayús para omitir"
L["AUTO_COMPLETE"] = "Completar Misiones Automáticamente"
L["AUTO_COMPLETE_DESC"] = "Mayús para omitir"
L["SKIP_REWARD_CHOICE"] = "Omitir Elección de Recompensa"
L["SKIP_REWARD_CHOICE_DESC"] = "Esperar selección"
L["AUTO_SHARE"] = "Compartir Misiones Automáticamente"
L["AUTO_SHARE_DESC"] = "Compartir con grupo"

L["WAYPOINT_AUTO"] = "Punto de Ruta Automático"
L["AUTO_SET_WAYPOINT"] = "Establecer Punto de Ruta Automáticamente"
L["AUTO_SET_WAYPOINT_DESC"] = "Misión más cercana"
L["AUTO_ADVANCE"] = "Avance Automático"
L["AUTO_ADVANCE_DESC"] = "Siguiente al completar"
L["PRIORITIZE_TURNINS"] = "Priorizar Entregas"
L["PRIORITIZE_TURNINS_DESC"] = "Entregas primero"

L["QUEST_FILTERS"] = "Filtros de Misiones"
L["SHOW_DUNGEON"] = "Mostrar Misiones de Mazmorra"
L["SHOW_DUNGEON_DESC"] = "Incluir misiones de mazmorra"
L["SHOW_RAID"] = "Mostrar Misiones de Banda"
L["SHOW_RAID_DESC"] = "Incluir misiones de banda"
L["SHOW_GROUP"] = "Mostrar Misiones de Grupo"
L["SHOW_GROUP_DESC"] = "Incluir misiones de grupo"
L["SHOW_PVP"] = "Mostrar Misiones JcJ"
L["SHOW_PVP_DESC"] = "Incluir misiones JcJ"
L["SHOW_LOW_LEVEL"] = "Mostrar Misiones de Nivel Bajo"
L["SHOW_LOW_LEVEL_DESC"] = "Incluir misiones grises"

-- ============================================================================
-- Advanced Tab
-- ============================================================================
L["THEME"] = "Tema"
L["COLOR_THEME"] = "Tema de Color"
L["THEME_GOLD"] = "Dorado (Predeterminado)"
L["THEME_BLUE"] = "Azul"
L["THEME_GREEN"] = "Verde"
L["THEME_RED"] = "Rojo"
L["THEME_PURPLE"] = "Púrpura"
L["THEME_ORANGE"] = "Naranja"
L["THEME_TEAL"] = "Verde Azulado"
L["THEME_PINK"] = "Rosa"
L["THEME_SILVER"] = "Plateado"
L["THEME_BRONZE"] = "Bronce"

L["PERFORMANCE"] = "Rendimiento"
L["UPDATE_INTERVAL"] = "Intervalo de Actualización"
L["UPDATE_THROTTLE"] = "Limitación de Actualización"
L["REDUCE_MAP_UPDATES"] = "Reducir Actualizaciones de Mapa"
L["REDUCE_MAP_UPDATES_DESC"] = "Actualizaciones perezosas"

L["QUEST_NOTES"] = "Notas de Misiones"
L["MAX_NOTE_LENGTH"] = "Longitud Máxima de Nota"

L["DEBUG_TOOLS"] = "Depuración y Herramientas"
L["DEBUG_MODE"] = "Modo de Depuración"
L["DEBUG_MODE_DESC"] = "Información de depuración en chat"
L["RESET_SETTINGS"] = "Reiniciar Configuración"
L["RELOAD_UI"] = "Recargar Interfaz"
L["RESET_CONFIRM"] = "¿Reiniciar toda la configuración de QuestMaster?"

-- ============================================================================
-- Credits Tab
-- ============================================================================
L["CREDITS_VERSION"] = "Versión 1.2"
L["CREDITS_EDITION"] = "Edición All-in-One"
L["CREDITS_DESCRIPTION"] = "Addon premium de rastreo de misiones con flechas de navegación, pines en mapa, estadísticas y funciones de automatización."
L["DEVELOPER"] = "Desarrollador"
L["ALSO_KNOWN_AS"] = "también conocido como"
L["DEVELOPER_BIO"] = "Desarrollador de addons de WoW y creador de contenido. Transmitiendo en vivo en Twitch.tv/Novi_Live"
L["CONNECT"] = "Conectar"
L["TWITCH"] = "Twitch"
L["DISCORD"] = "Discord"
L["CURSEFORGE"] = "CurseForge"
L["DOWNLOADS_BUGS"] = "Descargas y Reportes de Errores"
L["CHANGELOG"] = "Registro de Cambios"
L["SPECIAL_THANKS"] = "Agradecimientos Especiales"
L["THANKS_MESSAGE"] = "¡A todos los espectadores, probadores y seguidores en Twitch! Su retroalimentación ayuda a mejorar QuestMaster."

-- ============================================================================
-- Info Bar Tooltip
-- ============================================================================
L["SESSION_STATISTICS"] = "Estadísticas de Sesión"
L["CURRENT_XP"] = "EXP Actual:"
L["XP_REMAINING"] = "EXP Restante:"
L["XP_PER_HOUR_LABEL"] = "EXP por Hora:"
L["TIME_TO_LEVEL"] = "Tiempo hasta Nivel:"
L["SESSION_TIME"] = "Tiempo de Sesión:"
L["RESTED_AMOUNT"] = "Cantidad Descansada:"
L["RESTED_BUBBLES"] = "Burbujas Descansadas:"
L["BONUS_XP"] = "EXP Bonificada:"
L["BONUS_UNTIL_DEPLETED"] = "+50% hasta agotarse"
L["CURRENT_LEVEL_LABEL"] = "Nivel Actual:"
L["AVERAGE_PER_LEVEL"] = "Promedio por Nivel:"
L["PROGRESS"] = "Progreso:"
L["STATUS"] = "Estado"
L["BAG_SPACE"] = "Espacio en Bolsas:"
L["FREE"] = "libre"
L["DURABILITY"] = "Durabilidad:"
L["LOWEST"] = "más bajo"
L["TRACKED_REPUTATIONS"] = "Reputaciones Rastreadas"
L["CLICK_TO_RESET_XP"] = "Clic para reiniciar rastreador de EXP"

-- ============================================================================
-- Quest Display
-- ============================================================================
L["COMPLETE"] = "COMPLETADA"
L["DONE"] = "HECHO"
L["TURN_IN"] = "Entregar"
L["TURN_IN_SUFFIX"] = " (Entregar)"
L["TIME_ON_QUEST"] = "Tiempo en Misión:"
L["NOTE"] = "Nota:"
L["CLICK_SET_WAYPOINT"] = "Clic izquierdo: Establecer punto de ruta"
L["CLICK_OPEN_QUESTLOG"] = "Shift+Clic izquierdo: Abrir registro de misiones"
L["CLICK_MORE_OPTIONS"] = "Clic derecho: Más opciones"
L["DISTANCE_TO_OBJECTIVE"] = "Distancia al objetivo más cercano"

-- Context Menu
L["SET_WAYPOINT"] = "Establecer Punto de Ruta"
L["SHOW_ON_MAP"] = "Mostrar en Mapa"
L["EXPAND_QUEST"] = "Expandir Misión"
L["COLLAPSE_QUEST"] = "Contraer Misión"
L["EDIT_NOTE"] = "Editar Nota"
L["ADD_NOTE"] = "Agregar Nota"
L["SHARE_QUEST"] = "Compartir Misión"
L["ABANDON_QUEST"] = "Abandonar misión"

-- ============================================================================
-- Chat Messages
-- ============================================================================
L["MSG_PREFIX"] = "|cFF00FF00QuestMaster:|r"
L["MSG_ADDON_LOADED"] = "|cFFFFD700QuestMaster|r cargado! creado por |cFF00FF00JugoBetrugoTV|r alias |cFFFF8800Novi_Live|r"
L["MSG_TWITCH"] = "|cFF9146FF  Twitch.tv/Novi_Live|r - ¡Ven a pasar el rato!"
L["MSG_BUGS"] = "|cFF888888  ¿Errores? Reporta en CurseForge o|r |cFF5865F2Discord.gg/rv2BsbE|r"

L["MSG_QUEST_ACCEPTED"] = "Misión aceptada:"
L["MSG_ACCEPTED_QUEST"] = "Misión aceptada:"
L["MSG_QUEST_COMPLETED"] = "Misión completada:"
L["MSG_QUEST_READY"] = "Misión lista para entregar:"
L["MSG_OBJECTIVE_COMPLETE"] = "Objetivo completado:"
L["MSG_ABANDONED"] = "Abandonado:"
L["MSG_SHARED"] = "Compartido:"
L["MSG_CANNOT_SHARE"] = "Esta misión no se puede compartir"
L["MSG_QUEST_NOT_FOUND"] = "No se pudo encontrar la misión en el registro"

L["MSG_LEVEL_UP"] = "|cFFFFD700¡SUBISTE DE NIVEL!|r ¡Alcanzaste el nivel |cFF00FF00%d|r!"
L["MSG_TIME_FROM_LEVEL"] = "Tiempo desde nivel %d al %d:"
L["MSG_REACHED_LEVEL"] = "¡Alcanzaste el nivel %d!"
L["MSG_REACHED_LEVEL_TIME"] = "¡Alcanzaste el nivel %d! (%s desde nivel %d)"

L["MSG_WAYPOINT_SET"] = "Punto de ruta establecido en %.1f, %.1f - %s"
L["MSG_WAYPOINT_CORPSE"] = "Punto de ruta establecido a la ubicación de tu cadáver"
L["MSG_WAYPOINT_RESTORED"] = "Punto de ruta anterior restaurado"
L["MSG_NAVIGATING_TO"] = "Navegando hacia:"
L["MSG_AUTO_NAV_TURNIN"] = "Auto-navegando a entrega"
L["MSG_AUTO_NAV_TO"] = "Auto-navegando a:"
L["MSG_NO_QUESTS_NAV"] = "No hay misiones a las que navegar"
L["MSG_TURNIN"] = "Entregar:"
L["MSG_NO_COMPLETED"] = "No hay misiones completadas para entregar"

L["MSG_XP_RESET"] = "Rastreador de EXP/Hora reiniciado"
L["MSG_HISTORY_CLEARED"] = "Historial de misiones limpiado"
L["MSG_SESSION_RESET"] = "Estadísticas de sesión reiniciadas"
L["MSG_NOTE_SAVED"] = "Nota guardada para:"
L["MSG_NOTE_DELETED"] = "Nota eliminada para:"

L["MSG_COORDS_INVALID"] = "Las coordenadas deben estar entre 0 y 100"
L["MSG_NO_MAP"] = "No se puede determinar el mapa actual"
L["MSG_INVALID_COORDS"] = "Coordenadas inválidas. Usa: /qm way 45.2 67.8"
L["MSG_DB_FAIL"] = "Error al inicializar base de datos:"
L["MSG_DB_WARNING"] = "Advertencia: Perfil de base de datos no disponible"
L["MSG_INIT_FAIL"] = "Error al inicializar %s:"
L["MSG_SETTINGS_NOT_READY"] = "Configuración no está lista"
L["MSG_UNKNOWN_CMD"] = "Comando desconocido. Escribe /qm help para una lista de comandos."

-- Help
L["HELP_USAGE"] = "Uso:"
L["HELP_SEARCH"] = "Uso: /qm search <nombre o id de misión>"
L["HELP_WAY"] = "Uso: /qm way <x> <y> [descripción]"
L["HELP_WAY_EXAMPLE"] = "  Ejemplo: /qm way 45.2 67.8 Punto de encuentro"
L["HELP_CREDITS"] = "/qm credits - Mostrar créditos"
L["HELP_STATS"] = "/qm stats - Mostrar estadísticas de misiones"
L["HELP_SEARCH_CMD"] = "/qm search <nombre> - Buscar en base de datos de misiones"
L["HELP_WAY_CMD"] = "/qm way <x> <y> [desc] - Establecer punto de ruta manual"

-- Statistics Print
L["STATS_HEADER"] = "========== Estadísticas de Misiones =========="
L["STATS_TOTAL_COMPLETED"] = "Total Completadas: %d misiones"
L["STATS_TOTAL_XP"] = "EXP Total de Misiones:"
L["STATS_AVG_TIME"] = "Tiempo Promedio por Misión:"
L["STATS_QUESTS_HOUR"] = "Misiones/Hora: %.1f"
L["STATS_FASTEST"] = "Misión Más Rápida: %s (%s)"
L["STATS_SLOWEST"] = "Misión Más Lenta: %s (%s)"
L["STATS_SESSION_HEADER"] = "--- Estadísticas de Sesión ---"
L["STATS_SESSION_COMPLETED"] = "Completadas esta sesión: %d misiones"
L["STATS_SESSION_XP"] = "EXP de esta sesión:"
L["STATS_TOP_ZONES"] = "--- Mejores Zonas ---"

-- Search Results
L["SEARCH_NO_RESULTS"] = "No se encontraron misiones para '%s'"
L["SEARCH_HEADER"] = "=== Búsqueda de Misiones: '%s' (%d resultados) ==="
L["SEARCH_COMPLETED"] = "[Completada]"
L["SEARCH_IN_PROGRESS"] = "[En Progreso]"

-- Waypoint
L["WAYPOINT_FORMAT"] = "Punto de Ruta (%.1f, %.1f)"
L["YOUR_CORPSE"] = "Tu Cadáver"

-- Tooltip
L["QUEST_ITEM"] = "Objeto de Misión"
L["DROP_RATE_NOTE"] = "(La tasa de caída estimada varía)"
L["QUEST_NOTE"] = "Nota de Misión"

-- Time Format
L["TIME_HOURS_MINS"] = "%dh %dmin"
L["TIME_HOURS"] = "%dh"
L["TIME_MINS"] = "%d min"
L["TIME_ZERO"] = "0 min"
L["AVG_FORMAT"] = "(promedio: %s)"
L["LVL_PREFIX"] = "Nvl:"
L["XP_HOUR_PREFIX"] = "EXP/h:"
L["RESTED_PREFIX"] = "Descansado:"

-- Responsive Layout
L["QM_SHORT"] = "QM"
L["QUESTS_SHORT"] = "Misiones"

-- Quest Type Tags
L["DUNGEON_TAG"] = "D"
L["RAID_TAG"] = "R"
L["GROUP_TAG"] = "G"
L["DUNGEON_QUESTS"] = "Misiones de mazmorra"
L["RAID_QUESTS"] = "Misiones de banda"
L["BEST"] = "Mejor"
L["MSG_NEW_BEST_TIME"] = "Nuevo récord en %s: %s (anterior: %s)"

-- Party Quest Sync
L["PARTY_SYNC"] = "Sincronización de grupo"
L["ENABLE_PARTY_SYNC"] = "Activar sync de grupo"
L["ENABLE_PARTY_SYNC_DESC"] = "Compartir progreso con el grupo"
L["PARTY_SHOW_PROGRESS"] = "Mostrar progreso del grupo"
L["PARTY_SHOW_PROGRESS_DESC"] = "Mostrar en el rastreador"
L["PARTY_SHOW_INDICATOR"] = "Indicador de grupo"
L["PARTY_SHOW_INDICATOR_DESC"] = "Icono en misiones compartidas"
L["PARTY_SYNC_ICON"] = "G"

-- Statistics Dashboard
L["DASHBOARD_TITLE"] = "Panel"
L["DASH_TITLE"] = "Panel de estadísticas"
L["OPEN_DASHBOARD"] = "Abrir panel"
L["DASH_OVERVIEW"] = "Resumen"
L["DASH_ZONES"] = "Progreso por zona"
L["DASH_HISTORY"] = "Historial de misiones"
L["DASH_DETAILED_STATS"] = "Estadísticas detalladas"
L["DASH_FASTEST_QUEST"] = "Misión más rápida"
L["DASH_SLOWEST_QUEST"] = "Misión más lenta"
L["DASH_TOP_ZONES"] = "Mejores zonas de misiones"
L["DASH_OVERALL_PROGRESS"] = "Progreso general"
L["DASH_NO_ZONE_DATA"] = "Sin datos de zona aún"
L["DASH_NO_HISTORY"] = "Sin historial de misiones"
L["DASH_SHOWING_ENTRIES"] = "Mostrando %d de %d entradas"
L["DASH_MORE_ENTRIES"] = "... y %d entradas más"
L["DASH_SORT_TIME"] = "Hora"
L["DASH_SORT_NAME"] = "Nombre"
L["DASH_SORT_LEVEL"] = "Nivel"
L["DASH_SORT_DURATION"] = "Duración"
L["DASH_COL_QUEST"] = "Misión"
L["DASH_COL_LEVEL"] = "Niv"
L["DASH_COL_XP"] = "XP"
L["DASH_COL_TIME"] = "Tiempo"
L["DASH_COL_DATE"] = "Fecha"

-- Zone Filter & Minimap Tooltip
L["ZONE_FILTER"] = "Solo zona actual"
L["ZONE_FILTER_DESC"] = "Mostrar solo misiones de la zona actual"
L["MINIMAP_ACTIVE_QUESTS"] = "Misiones activas:"
L["MINIMAP_COMPLETED"] = "Completadas:"
L["MINIMAP_IN_ZONE"] = "En zona:"
L["MINIMAP_CURRENT_WAYPOINT"] = "Punto de ruta actual:"
L["MINIMAP_NO_WAYPOINT"] = "Sin punto de ruta activo"
L["MINIMAP_LEFT_CLICK"] = "Clic izquierdo: Abrir ajustes"
L["MINIMAP_SHIFT_CLICK"] = "Shift+Clic izquierdo: Alternar rastreador"
L["MINIMAP_RIGHT_CLICK"] = "Clic derecho: Alternar flecha"
L["MINIMAP_MIDDLE_CLICK"] = "Clic central: Borrar punto de ruta"
