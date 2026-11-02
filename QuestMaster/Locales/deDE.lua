-- QuestMaster German Localization
local addonName, QM = ...
if GetLocale() ~= "deDE" then return end

local L = QM.L

-- ============================================================================
-- General
-- ============================================================================
L["ADDON_NAME"] = "QuestMaster"
L["ADDON_LOADED"] = "QuestMaster geladen. Tippe /qm für Optionen."
L["VERSION"] = "Version"
L["ENABLED"] = "Aktiviert"
L["DISABLED"] = "Deaktiviert"
L["YES"] = "Ja"
L["NO"] = "Nein"
L["DEFAULT"] = "Standard"
L["RESET"] = "Zurücksetzen"
L["CLOSE"] = "Schließen"
L["SAVE"] = "Speichern"
L["CANCEL"] = "Abbrechen"
L["DELETE"] = "Löschen"
L["UNKNOWN"] = "Unbekannt"
L["NONE"] = "Keine"
L["GO"] = "Los"
L["SEARCH"] = "Suchen"
L["REFRESHED"] = "Aktualisiert"

-- ============================================================================
-- Tabs
-- ============================================================================
L["TAB_GENERAL"] = "Allgemein"
L["TAB_GENERAL_DESC"] = "Haupteinstellungen"
L["TAB_TRACKER"] = "Questliste"
L["TAB_TRACKER_DESC"] = "Questliste"
L["TAB_ARROW"] = "Pfeil"
L["TAB_ARROW_DESC"] = "Navigation"
L["TAB_MAP"] = "Karte"
L["TAB_MAP_DESC"] = "Pins & Markierungen"
L["TAB_STATISTICS"] = "Statistiken"
L["TAB_STATISTICS_DESC"] = "EP-Verfolgung"
L["TAB_DASHBOARD"] = "Dashboard"
L["TAB_DASHBOARD_DESC"] = "Statistiken & Verlauf"
L["TAB_AUTOMATION"] = "Automatisierung"
L["TAB_AUTOMATION_DESC"] = "Auto-Funktionen"
L["TAB_ADVANCED"] = "Erweitert"
L["TAB_ADVANCED_DESC"] = "Experte"
L["TAB_CREDITS"] = "Credits"
L["TAB_CREDITS_DESC"] = "Info & Links"

-- ============================================================================
-- Settings Header
-- ============================================================================
L["SETTINGS"] = "Einstellungen"
L["SETTINGS_TITLE"] = "QuestMaster Einstellungen"

-- ============================================================================
-- General Settings
-- ============================================================================
L["MAIN_SETTINGS"] = "Haupteinstellungen"
L["ENABLE_ADDON"] = "QuestMaster aktivieren"
L["ENABLE_ADDON_DESC"] = "Hauptschalter für alle Funktionen"
L["LOCK_FRAMES"] = "Fenster fixieren"
L["LOCK_FRAMES_DESC"] = "Verschieben verhindern"
L["SHOW_MINIMAP_BUTTON"] = "Minikarten-Button anzeigen"
L["SHOW_MINIMAP_BUTTON_DESC"] = "Button an der Minikarte"

-- ============================================================================
-- Sounds
-- ============================================================================
L["SOUNDS"] = "Soundeffekte"
L["QUEST_PROGRESS_SOUND"] = "Quest-Fortschritt Sound"
L["QUEST_PROGRESS_SOUND_DESC"] = "Sound bei Fortschritt"
L["QUEST_COMPLETE_SOUND"] = "Quest-Abschluss Sound"
L["QUEST_COMPLETE_SOUND_DESC"] = "Sound bei Abschluss"

-- ============================================================================
-- Announcements
-- ============================================================================
L["QUEST_ANNOUNCEMENTS"] = "Quest-Ankündigungen"
L["ANNOUNCE_ACCEPT"] = "Quest-Annahme ankündigen"
L["ANNOUNCE_ACCEPT_DESC"] = "An Gruppe/Gilde"
L["ACCEPT_CHANNEL"] = "Annahme-Kanal"
L["ANNOUNCE_DONE"] = "Quest-Abschluss ankündigen"
L["ANNOUNCE_DONE_DESC"] = "An Gruppe/Gilde"
L["COMPLETE_CHANNEL"] = "Abschluss-Kanal"
L["CHANNEL_PARTY"] = "Gruppe"
L["CHANNEL_GUILD"] = "Gilde"
L["CHANNEL_EMOTE"] = "Emote (/me)"
L["CHANNEL_DISABLED"] = "Deaktiviert"

-- Level Up
L["LEVEL_UP_ANNOUNCEMENTS"] = "Levelaufstieg-Ankündigungen"
L["ANNOUNCE_LEVEL_UP"] = "Levelaufstieg ankündigen"
L["ANNOUNCE_LEVEL_UP_DESC"] = "An Emote/Gruppe"
L["LEVEL_UP_CHANNEL"] = "Levelaufstieg-Kanal"

-- ============================================================================
-- Quick Actions
-- ============================================================================
L["QUICK_ACTIONS"] = "Schnellaktionen"
L["RESET_POSITIONS"] = "Positionen zurücksetzen"
L["REFRESH_DATA"] = "Daten aktualisieren"

-- ============================================================================
-- Quest Tracker
-- ============================================================================
L["QUEST_TRACKER"] = "Quest-Tracker"
L["ENABLE_TRACKER"] = "Tracker aktivieren"
L["ENABLE_TRACKER_DESC"] = "Quest-Panel anzeigen"
L["FONT_SIZE"] = "Schriftgröße"
L["BACKGROUND_OPACITY"] = "Hintergrundtransparenz"
L["TRACKER_TITLE"] = "QuestMaster"
L["ACTIVE_QUESTS"] = "Aktive Quests"
L["READY_FOR_TURNIN"] = "Bereit zur Abgabe"
L["NO_ACTIVE_QUESTS"] = "Keine aktiven Quests"

-- Display Options
L["DISPLAY_OPTIONS"] = "Anzeigeoptionen"
L["SHOW_QUEST_LEVEL"] = "Quest-Level anzeigen"
L["SHOW_QUEST_LEVEL_DESC"] = "Level in Klammern"
L["SHOW_DISTANCE"] = "Entfernung anzeigen"
L["SHOW_DISTANCE_DESC"] = "Entfernung zum Ziel"
L["COLOR_BY_DIFFICULTY"] = "Nach Schwierigkeit einfärben"
L["COLOR_BY_DIFFICULTY_DESC"] = "Levelbasierte Farben"
L["SHOW_PROGRESS_BARS"] = "Fortschrittsbalken anzeigen"
L["SHOW_PROGRESS_BARS_DESC"] = "Balken unter Zielen"
L["SHOW_ITEM_BUTTONS"] = "Item-Buttons anzeigen"
L["SHOW_ITEM_BUTTONS_DESC"] = "Zeige nutzbare Quest-Items"
L["CLICK_TO_USE_ITEM"] = "Klicken um Item zu benutzen"
L["SHOW_COMPLETED"] = "Abgeschlossene Quests anzeigen"
L["SHOW_COMPLETED_DESC"] = "Fertige Quests anzeigen"
L["MAX_QUESTS"] = "Max. angezeigte Quests"

-- Default Tracker
L["HIDE_BLIZZARD_TRACKER"] = "Standard-Questtracker ausblenden"
L["HIDE_BLIZZARD_TRACKER_DESC"] = "Den Standard-Blizzard-Questtracker ausblenden"
L["HIDE_BLIZZARD_TRACKER_COMBAT"] = "Der Standard-Tracker kann im Kampf nicht umgeschaltet werden."
L["HIDE_BLIZZARD_TRACKER_RELOAD"] = "Das Reaktivieren des Standard-Trackers erfordert ein UI-Neuladen. Jetzt neu laden?"

-- Sorting
L["SORTING"] = "Sortierung"
L["SORT_BY"] = "Sortieren nach"
L["SORT_QUESTS_BY"] = "Quests sortieren nach"
L["SORT_DISTANCE"] = "Entfernung"
L["SORT_LEVEL"] = "Level"
L["CURRENT"] = "Aktuell"

-- Tracker Buttons
L["SORT"] = "Sortieren"
L["NAVIGATE_TO_NEAREST"] = "Zum Nächsten navigieren"
L["CLICK_TO_SET_WAYPOINT"] = "Klicken um Wegpunkt zu setzen"
L["NAVIGATE_TO_TURNIN"] = "Zur Abgabe navigieren"
L["NEAREST_COMPLETED_QUEST"] = "Nächste abgeschlossene Quest"

-- ============================================================================
-- Arrow
-- ============================================================================
L["NAVIGATION_ARROW"] = "Navigationspfeil"
L["ENABLE_ARROW"] = "Pfeil aktivieren"
L["ENABLE_ARROW_DESC"] = "Nav-Pfeil anzeigen"
L["ARROW_SIZE"] = "Pfeilgröße"
L["ARROW_OPACITY"] = "Pfeiltransparenz"
L["ARRIVAL_DISTANCE"] = "Ankunftsentfernung"

-- Arrow Display
L["DISPLAY"] = "Anzeige"
L["SHOW_OBJECTIVE"] = "Ziel anzeigen"
L["SHOW_OBJECTIVE_DESC"] = "Zieltext"
L["SHOW_ETA"] = "Ankunftszeit anzeigen"
L["SHOW_ETA_DESC"] = "Zeitschätzung"

-- Arrow Status
L["ARRIVED"] = "Angekommen!"
L["NO_ACTIVE_OBJECTIVE"] = "Kein aktives Ziel"
L["QUEST_OBJECTIVE"] = "Quest-Ziel"
L["YARDS"] = "m"
L["KILOMETERS"] = "km"

-- Arrow Tooltip
L["ARROW_NAVIGATION"] = "Navigation"
L["OBJECTIVE"] = "Ziel"
L["LEFT_CLICK_DRAG"] = "Linksklick + ziehen zum Verschieben"
L["RIGHT_CLICK_OPTIONS"] = "Rechtsklick für Optionen"

-- Arrow Context Menu
L["HIDE_ARROW"] = "Pfeil ausblenden"
L["CLEAR_WAYPOINT"] = "Wegpunkt entfernen"
L["FIND_NEAREST_AUTO"] = "Nächsten finden (Auto)"
L["OPEN_SETTINGS"] = "Einstellungen öffnen"

-- ETA
L["ETA"] = "Ankunft"
L["ETA_SECONDS"] = "Ankunft: %ds"
L["ETA_MINUTES"] = "Ankunft: %dm %ds"
L["ETA_HOURS"] = "Ankunft: %dh %dm"
L["MOVE_TO_CALCULATE"] = "(Bewegen um Ankunftszeit zu berechnen)"

-- ============================================================================
-- Map
-- ============================================================================
L["WORLD_MAP"] = "Weltkarte"
L["ENABLE_MAP_PINS"] = "Karten-Pins aktivieren"
L["ENABLE_MAP_PINS_DESC"] = "Quest-Pins anzeigen"
L["PIN_SIZE"] = "Pin-Größe"
L["PIN_OPACITY"] = "Pin-Transparenz"

-- Pin Types
L["PIN_TYPES"] = "Pin-Typen"
L["OBJECTIVE_PINS"] = "Ziel-Pins"
L["OBJECTIVE_PINS_DESC"] = "Quest-Ziele"
L["QUEST_AREAS"] = "Quest-Bereiche"
L["QUEST_AREAS_DESC"] = "Bereiche hervorheben"
L["TURNIN_PINS"] = "Abgabe-Pins (?)"
L["TURNIN_PINS_DESC"] = "Gelbe ? Pins"
L["AVAILABLE_QUESTS"] = "Verfügbare Quests (!)"
L["AVAILABLE_QUESTS_DESC"] = "Gelbe ! Pins"
L["PATROL_PATHS"] = "NPC-Patrouillenrouten"
L["PATROL_PATHS_DESC"] = "Patrouillenrouten anzeigen"

-- ============================================================================
-- Statistics Tab
-- ============================================================================
L["QUEST_TIMER"] = "Quest-Timer"
L["ENABLE_TIMER"] = "Timer aktivieren"
L["ENABLE_TIMER_DESC"] = "Quest-Zeit verfolgen"
L["SHOW_IN_TRACKER"] = "Im Tracker anzeigen"
L["SHOW_IN_TRACKER_DESC"] = "Im Tracker anzeigen"

L["XP_PER_HOUR"] = "EP/Stunde"
L["ENABLE_XP_TRACKER"] = "EP-Tracker aktivieren"
L["ENABLE_XP_TRACKER_DESC"] = "EP-Rate berechnen"
L["RESET_XP"] = "EP zurücksetzen"

L["RESTED_XP"] = "Erholt-EP"
L["ENABLE_RESTED_DISPLAY"] = "Erholt-Anzeige aktivieren"
L["ENABLE_RESTED_DISPLAY_DESC"] = "Erholt-EP anzeigen"
L["SHOW_BONUS_INDICATOR"] = "+50% Bonus anzeigen"
L["SHOW_BONUS_INDICATOR_DESC"] = "Bonus-Indikator anzeigen"

L["LEVEL_TIME"] = "Levelzeit"
L["ENABLE_LEVEL_TIMER"] = "Level-Timer aktivieren"
L["ENABLE_LEVEL_TIMER_DESC"] = "Zeit pro Level verfolgen"
L["SHOW_AVERAGE"] = "Durchschnitt anzeigen"
L["SHOW_AVERAGE_DESC"] = "Durchschnittszeit anzeigen"

L["REMINDERS"] = "Erinnerungen"
L["ENABLE_REMINDERS"] = "Erinnerungen aktivieren"
L["ENABLE_REMINDERS_DESC"] = "Taschen- & Reparaturwarnungen"
L["BAG_SPACE_WARNING"] = "Taschenplatz-Warnung"
L["BAG_SPACE_WARNING_DESC"] = "Warnen wenn Taschen voll"
L["BAG_THRESHOLD"] = "Taschenschwellenwert"
L["REPAIR_WARNING"] = "Reparatur-Warnung"
L["REPAIR_WARNING_DESC"] = "Warnen bei niedriger Haltbarkeit"

L["ZONE_PROGRESS"] = "Zonenfortschritt"
L["ENABLE_ZONE_PROGRESS"] = "Zonenfortschritt aktivieren"
L["ENABLE_ZONE_PROGRESS_DESC"] = "Pro Zone verfolgen"

L["REPUTATION"] = "Ruf"
L["ENABLE_REP_TRACKER"] = "Ruf-Tracker aktivieren"
L["ENABLE_REP_TRACKER_DESC"] = "Beobachtete Fraktion verfolgen"

-- Quest Statistics
L["QUEST_STATISTICS"] = "Quest-Statistiken"
L["TOTAL_STATISTICS"] = "Gesamtstatistiken"
L["QUESTS_COMPLETED"] = "Abgeschlossene Quests"
L["TOTAL_XP_GAINED"] = "Gesamt-EP erhalten"
L["AVG_QUEST_TIME"] = "Ø Quest-Zeit"
L["QUESTS_PER_HOUR"] = "Quests pro Stunde"
L["CURRENT_LEVEL"] = "Aktuelles Level"
L["TIME_ON_LEVEL"] = "Zeit auf Level"
L["SESSION_QUESTS"] = "Sitzungs-Quests"
L["SESSION_XP"] = "Sitzungs-EP"
L["REFRESH_STATS"] = "Statistiken aktualisieren"
L["RESET_SESSION"] = "Sitzung zurücksetzen"

-- Quest Search
L["QUEST_SEARCH"] = "Quest-Suche"
L["SEARCH_PLACEHOLDER"] = "Quest-Name oder ID eingeben..."
L["CLICK_RESULT_HINT"] = "Klicke auf ein Ergebnis um Wegpunkt zum Quest-Startort zu setzen"
L["NO_QUESTS_FOUND"] = "Keine Quests gefunden:"
L["WAYPOINT_SET_TO_QUEST"] = "Wegpunkt zur Quest gesetzt:"
L["NO_LOCATION_DATA"] = "Keine Ortsdaten für:"
L["QUEST_LABEL"] = "Quest:"
L["OBJECTIVES_LABEL"] = "Ziele:"

-- Manual Waypoint
L["MANUAL_WAYPOINT"] = "Manueller Wegpunkt"
L["WAYPOINT"] = "Wegpunkt"
L["MANUAL"] = "[Manuell]"
L["CURRENT_WAYPOINT"] = "Aktuell:"
L["NO_WAYPOINT_SET"] = "Kein Wegpunkt gesetzt"
L["X_COORD"] = "X:"
L["Y_COORD"] = "Y:"
L["SET"] = "Setzen"
L["INVALID_COORDINATES"] = "Ungültige Koordinaten (0-100)"
L["COORD_HINT"] = "Koordinaten wie 45.5 und 67.2 eingeben (Werte 0-100)"
L["CLEAR_WAYPOINT"] = "Wegpunkt entfernen"

-- ============================================================================
-- Automation Tab
-- ============================================================================
L["QUEST_AUTOMATION"] = "Quest-Automatisierung"
L["AUTO_ACCEPT"] = "Quests automatisch annehmen"
L["AUTO_ACCEPT_DESC"] = "Umschalt zum Überspringen"
L["AUTO_COMPLETE"] = "Quests automatisch abschließen"
L["AUTO_COMPLETE_DESC"] = "Umschalt zum Überspringen"
L["SKIP_REWARD_CHOICE"] = "Belohnungsauswahl überspringen"
L["SKIP_REWARD_CHOICE_DESC"] = "Auf Auswahl warten"
L["AUTO_SHARE"] = "Quests automatisch teilen"
L["AUTO_SHARE_DESC"] = "Mit Gruppe teilen"

L["WAYPOINT_AUTO"] = "Wegpunkt-Auto"
L["AUTO_SET_WAYPOINT"] = "Wegpunkt automatisch setzen"
L["AUTO_SET_WAYPOINT_DESC"] = "Nächste Quest"
L["AUTO_ADVANCE"] = "Automatisch weitergehen"
L["AUTO_ADVANCE_DESC"] = "Nächste bei Abschluss"
L["PRIORITIZE_TURNINS"] = "Abgaben priorisieren"
L["PRIORITIZE_TURNINS_DESC"] = "Abgaben zuerst"

L["QUEST_FILTERS"] = "Quest-Filter"
L["SHOW_DUNGEON"] = "Dungeon-Quests anzeigen"
L["SHOW_DUNGEON_DESC"] = "Dungeon-Quests einbeziehen"
L["SHOW_RAID"] = "Schlachtzug-Quests anzeigen"
L["SHOW_RAID_DESC"] = "Schlachtzug-Quests einbeziehen"
L["SHOW_GROUP"] = "Gruppen-Quests anzeigen"
L["SHOW_GROUP_DESC"] = "Gruppen-Quests einbeziehen"
L["SHOW_PVP"] = "PvP-Quests anzeigen"
L["SHOW_PVP_DESC"] = "PvP-Quests einbeziehen"
L["SHOW_LOW_LEVEL"] = "Niedrigstufige Quests anzeigen"
L["SHOW_LOW_LEVEL_DESC"] = "Graue Quests einbeziehen"

-- ============================================================================
-- Advanced Tab
-- ============================================================================
L["THEME"] = "Thema"
L["COLOR_THEME"] = "Farbthema"
L["THEME_GOLD"] = "Gold (Standard)"
L["THEME_BLUE"] = "Blau"
L["THEME_GREEN"] = "Grün"
L["THEME_RED"] = "Rot"
L["THEME_PURPLE"] = "Violett"
L["THEME_ORANGE"] = "Orange"
L["THEME_TEAL"] = "Türkis"
L["THEME_PINK"] = "Rosa"
L["THEME_SILVER"] = "Silber"
L["THEME_BRONZE"] = "Bronze"

L["PERFORMANCE"] = "Leistung"
L["UPDATE_INTERVAL"] = "Aktualisierungsintervall"
L["UPDATE_THROTTLE"] = "Aktualisierungsdrosselung"
L["REDUCE_MAP_UPDATES"] = "Karten-Updates reduzieren"
L["REDUCE_MAP_UPDATES_DESC"] = "Verzögerte Updates"

L["QUEST_NOTES"] = "Quest-Notizen"
L["MAX_NOTE_LENGTH"] = "Max. Notizlänge"

L["DEBUG_TOOLS"] = "Debug & Tools"
L["DEBUG_MODE"] = "Debug-Modus"
L["DEBUG_MODE_DESC"] = "Chat-Debug-Info"
L["RESET_SETTINGS"] = "Einstellungen zurücksetzen"
L["RELOAD_UI"] = "UI neu laden"
L["RESET_CONFIRM"] = "Alle QuestMaster-Einstellungen zurücksetzen?"

-- ============================================================================
-- Credits Tab
-- ============================================================================
L["CREDITS_VERSION"] = "Version 1.3"
L["CREDITS_EDITION"] = "All-in-One Edition"
L["CREDITS_DESCRIPTION"] = "Premium Quest-Tracking-Addon mit Navigationspfeilen, Karten-Pins, Statistiken und Automatisierungsfunktionen."
L["DEVELOPER"] = "Entwickler"
L["ALSO_KNOWN_AS"] = "auch bekannt als"
L["DEVELOPER_BIO"] = "WoW-Addon-Entwickler und Content-Creator. Live auf Twitch.tv/Novi_Live"
L["CONNECT"] = "Verbinden"
L["TWITCH"] = "Twitch"
L["DISCORD"] = "Discord"
L["CURSEFORGE"] = "CurseForge"
L["DOWNLOADS_BUGS"] = "Downloads & Fehlerberichte"
L["CHANGELOG"] = "Änderungsprotokoll"
L["SPECIAL_THANKS"] = "Besonderer Dank"
L["THANKS_MESSAGE"] = "An alle Zuschauer, Tester und Unterstützer auf Twitch! Euer Feedback hilft, QuestMaster zu verbessern."

-- ============================================================================
-- Info Bar Tooltip
-- ============================================================================
L["SESSION_STATISTICS"] = "Sitzungsstatistiken"
L["CURRENT_XP"] = "Aktuelle EP:"
L["XP_REMAINING"] = "Verbleibende EP:"
L["XP_PER_HOUR_LABEL"] = "EP pro Stunde:"
L["TIME_TO_LEVEL"] = "Zeit bis Level:"
L["SESSION_TIME"] = "Sitzungszeit:"
L["RESTED_AMOUNT"] = "Erholt-Betrag:"
L["RESTED_BUBBLES"] = "Erholt-Blasen:"
L["BONUS_XP"] = "Bonus-EP:"
L["BONUS_UNTIL_DEPLETED"] = "+50% bis aufgebraucht"
L["CURRENT_LEVEL_LABEL"] = "Aktuelles Level:"
L["AVERAGE_PER_LEVEL"] = "Durchschnitt pro Level:"
L["PROGRESS"] = "Fortschritt:"
L["STATUS"] = "Status"
L["BAG_SPACE"] = "Taschenplatz:"
L["FREE"] = "frei"
L["DURABILITY"] = "Haltbarkeit:"
L["LOWEST"] = "niedrigste"
L["TRACKED_REPUTATIONS"] = "Verfolgte Rufwerte"
L["CLICK_TO_RESET_XP"] = "Klicken um EP-Tracker zurückzusetzen"

-- ============================================================================
-- Quest Display
-- ============================================================================
L["COMPLETE"] = "ABGESCHLOSSEN"
L["DONE"] = "FERTIG"
L["TURN_IN"] = "Abgeben"
L["TURN_IN_SUFFIX"] = " (Abgeben)"
L["TIME_ON_QUEST"] = "Zeit an Quest:"
L["NOTE"] = "Notiz:"
L["CLICK_SET_WAYPOINT"] = "Linksklick: Wegpunkt setzen"
L["CLICK_OPEN_QUESTLOG"] = "Shift+Linksklick: Questlog öffnen"
L["CLICK_MORE_OPTIONS"] = "Rechtsklick: Weitere Optionen"
L["DISTANCE_TO_OBJECTIVE"] = "Entfernung zum nächsten Ziel"

-- Context Menu
L["SET_WAYPOINT"] = "Wegpunkt setzen"
L["SHOW_ON_MAP"] = "Auf Karte anzeigen"
L["EXPAND_QUEST"] = "Quest ausklappen"
L["COLLAPSE_QUEST"] = "Quest einklappen"
L["EDIT_NOTE"] = "Notiz bearbeiten"
L["ADD_NOTE"] = "Notiz hinzufügen"
L["SHARE_QUEST"] = "Quest teilen"
L["ABANDON_QUEST"] = "Quest aufgeben"

-- ============================================================================
-- Chat Messages
-- ============================================================================
L["MSG_PREFIX"] = "|cFF00FF00QuestMaster:|r"
L["MSG_ADDON_LOADED"] = "|cFFFFD700QuestMaster|r geladen! erstellt von |cFF00FF00JugoBetrugoTV|r alias |cFFFF8800Novi_Live|r"
L["MSG_TWITCH"] = "|cFF9146FF  Twitch.tv/Novi_Live|r - Komm vorbei!"
L["MSG_BUGS"] = "|cFF888888  Fehler? Melde auf CurseForge oder|r |cFF5865F2Discord.gg/rv2BsbE|r"

L["MSG_QUEST_ACCEPTED"] = "Quest angenommen:"
L["MSG_ACCEPTED_QUEST"] = "Quest angenommen:"
L["MSG_QUEST_COMPLETED"] = "Quest abgeschlossen:"
L["MSG_QUEST_READY"] = "Quest bereit zur Abgabe:"
L["MSG_OBJECTIVE_COMPLETE"] = "Ziel abgeschlossen:"
L["MSG_ABANDONED"] = "Aufgegeben:"
L["MSG_SHARED"] = "Geteilt:"
L["MSG_CANNOT_SHARE"] = "Diese Quest kann nicht geteilt werden"
L["MSG_QUEST_NOT_FOUND"] = "Quest nicht im Logbuch gefunden"

L["MSG_LEVEL_UP"] = "|cFFFFD700LEVELAUFSTIEG!|r Du hast Level |cFF00FF00%d|r erreicht!"
L["MSG_TIME_FROM_LEVEL"] = "Zeit von Level %d bis %d:"
L["MSG_REACHED_LEVEL"] = "Level %d erreicht!"
L["MSG_REACHED_LEVEL_TIME"] = "Level %d erreicht! (%s von Level %d)"

L["MSG_WAYPOINT_SET"] = "Wegpunkt gesetzt auf %.1f, %.1f - %s"
L["MSG_WAYPOINT_CORPSE"] = "Wegpunkt auf deine Leiche gesetzt"
L["MSG_WAYPOINT_RESTORED"] = "Vorheriger Wegpunkt wiederhergestellt"
L["MSG_NAVIGATING_TO"] = "Navigiere zu:"
L["MSG_AUTO_NAV_TURNIN"] = "Auto-Navigation zur Abgabe"
L["MSG_AUTO_NAV_TO"] = "Auto-Navigation zu:"
L["MSG_NO_QUESTS_NAV"] = "Keine Quests zur Navigation"
L["MSG_TURNIN"] = "Abgeben:"
L["MSG_NO_COMPLETED"] = "Keine abgeschlossenen Quests zum Abgeben"

L["MSG_XP_RESET"] = "EP/Stunde-Tracker zurückgesetzt"
L["MSG_HISTORY_CLEARED"] = "Quest-Historie gelöscht"
L["MSG_SESSION_RESET"] = "Sitzungsstatistiken zurückgesetzt"
L["MSG_NOTE_SAVED"] = "Notiz gespeichert für:"
L["MSG_NOTE_DELETED"] = "Notiz gelöscht für:"

L["MSG_COORDS_INVALID"] = "Koordinaten müssen zwischen 0 und 100 liegen"
L["MSG_NO_MAP"] = "Aktuelle Karte kann nicht bestimmt werden"
L["MSG_INVALID_COORDS"] = "Ungültige Koordinaten. Verwende: /qm way 45.2 67.8"
L["MSG_DB_FAIL"] = "Datenbank konnte nicht initialisiert werden:"
L["MSG_DB_WARNING"] = "Warnung: Datenbankprofil nicht verfügbar"
L["MSG_INIT_FAIL"] = "%s konnte nicht initialisiert werden:"
L["MSG_SETTINGS_NOT_READY"] = "Einstellungen nicht bereit"
L["MSG_UNKNOWN_CMD"] = "Unbekannter Befehl. Tippe /qm help für eine Liste der Befehle."

-- Help
L["HELP_USAGE"] = "Verwendung:"
L["HELP_SEARCH"] = "Verwendung: /qm search <Quest-Name oder ID>"
L["HELP_WAY"] = "Verwendung: /qm way <x> <y> [Beschreibung]"
L["HELP_WAY_EXAMPLE"] = "  Beispiel: /qm way 45.2 67.8 Treffpunkt"
L["HELP_CREDITS"] = "/qm credits - Credits anzeigen"
L["HELP_STATS"] = "/qm stats - Quest-Statistiken anzeigen"
L["HELP_SEARCH_CMD"] = "/qm search <Name> - Quest-Datenbank durchsuchen"
L["HELP_WAY_CMD"] = "/qm way <x> <y> [Beschr.] - Manuellen Wegpunkt setzen"

-- Statistics Print
L["STATS_HEADER"] = "========== Quest-Statistiken =========="
L["STATS_TOTAL_COMPLETED"] = "Gesamt abgeschlossen: %d Quests"
L["STATS_TOTAL_XP"] = "Gesamt-EP von Quests:"
L["STATS_AVG_TIME"] = "Durchschnittliche Quest-Zeit:"
L["STATS_QUESTS_HOUR"] = "Quests/Stunde: %.1f"
L["STATS_FASTEST"] = "Schnellste Quest: %s (%s)"
L["STATS_SLOWEST"] = "Langsamste Quest: %s (%s)"
L["STATS_SESSION_HEADER"] = "--- Sitzungsstatistiken ---"
L["STATS_SESSION_COMPLETED"] = "Diese Sitzung abgeschlossen: %d Quests"
L["STATS_SESSION_XP"] = "EP diese Sitzung:"
L["STATS_TOP_ZONES"] = "--- Top-Zonen ---"

-- Search Results
L["SEARCH_NO_RESULTS"] = "Keine Quests gefunden für '%s'"
L["SEARCH_HEADER"] = "=== Quest-Suche: '%s' (%d Ergebnisse) ==="
L["SEARCH_COMPLETED"] = "[Abgeschlossen]"
L["SEARCH_IN_PROGRESS"] = "[In Bearbeitung]"

-- Waypoint
L["WAYPOINT_FORMAT"] = "Wegpunkt (%.1f, %.1f)"
L["YOUR_CORPSE"] = "Deine Leiche"

-- Tooltip
L["QUEST_ITEM"] = "Quest-Gegenstand"
L["DROP_RATE_NOTE"] = "(Geschätzte Droprate variiert)"
L["QUEST_NOTE"] = "Quest-Notiz"

-- Time Format
L["TIME_HOURS_MINS"] = "%dh %dmin"
L["TIME_HOURS"] = "%dh"
L["TIME_MINS"] = "%d min"
L["TIME_ZERO"] = "0 min"
L["AVG_FORMAT"] = "(Ø: %s)"
L["LVL_PREFIX"] = "Lvl:"
L["XP_HOUR_PREFIX"] = "EP/h:"
L["RESTED_PREFIX"] = "Erholt:"

-- Responsive Layout
L["QM_SHORT"] = "QM"
L["QUESTS_SHORT"] = "Quests"

-- ============================================================================
-- Quest Type Tags (Dungeon/Group/Raid)
-- ============================================================================
L["DUNGEON_TAG"] = "D"
L["RAID_TAG"] = "R"
L["GROUP_TAG"] = "G"
L["DUNGEON_QUESTS"] = "Dungeon-Quests"
L["RAID_QUESTS"] = "Schlachtzug-Quests"

-- Best Time
L["BEST"] = "Beste"
L["MSG_NEW_BEST_TIME"] = "Neue Bestzeit für %s: %s (vorher: %s)"

-- Party Quest Sync
L["PARTY_SYNC"] = "Gruppen-Quest-Sync"
L["ENABLE_PARTY_SYNC"] = "Gruppen-Sync aktivieren"
L["ENABLE_PARTY_SYNC_DESC"] = "Quest-Fortschritt mit Gruppe teilen"
L["PARTY_SHOW_PROGRESS"] = "Gruppen-Fortschritt anzeigen"
L["PARTY_SHOW_PROGRESS_DESC"] = "Im Tracker anzeigen"
L["PARTY_SHOW_INDICATOR"] = "Gruppen-Anzeige"
L["PARTY_SHOW_INDICATOR_DESC"] = "Symbol bei geteilten Quests"
L["PARTY_SYNC_ICON"] = "G"

-- Statistics Dashboard
L["DASHBOARD_TITLE"] = "Dashboard"
L["DASH_TITLE"] = "Statistik-Dashboard"
L["OPEN_DASHBOARD"] = "Dashboard öffnen"
L["DASH_OVERVIEW"] = "Übersicht"
L["DASH_ZONES"] = "Gebiets-Fortschritt"
L["DASH_HISTORY"] = "Quest-Verlauf"
L["DASH_DETAILED_STATS"] = "Detaillierte Statistiken"
L["DASH_FASTEST_QUEST"] = "Schnellste Quest"
L["DASH_SLOWEST_QUEST"] = "Langsamste Quest"
L["DASH_TOP_ZONES"] = "Top Quest-Gebiete"
L["DASH_OVERALL_PROGRESS"] = "Gesamtfortschritt"
L["DASH_NO_ZONE_DATA"] = "Noch keine Gebiets-Daten vorhanden"
L["DASH_NO_HISTORY"] = "Noch kein Quest-Verlauf vorhanden"
L["DASH_SHOWING_ENTRIES"] = "%d von %d Einträgen"
L["DASH_MORE_ENTRIES"] = "... und %d weitere Einträge"
L["DASH_SORT_TIME"] = "Zeit"
L["DASH_SORT_NAME"] = "Name"
L["DASH_SORT_LEVEL"] = "Stufe"
L["DASH_SORT_DURATION"] = "Dauer"
L["DASH_COL_QUEST"] = "Quest"
L["DASH_COL_LEVEL"] = "Stf"
L["DASH_COL_XP"] = "EP"
L["DASH_COL_TIME"] = "Zeit"
L["DASH_COL_DATE"] = "Datum"

-- Zone Filter
L["ZONE_FILTER"] = "Nur aktuelle Zone"
L["ZONE_FILTER_DESC"] = "Nur Quests der aktuellen Zone anzeigen"

-- Enhanced Minimap Tooltip
L["MINIMAP_ACTIVE_QUESTS"] = "Aktive Quests:"
L["MINIMAP_COMPLETED"] = "Abgeschlossen:"
L["MINIMAP_IN_ZONE"] = "In Zone:"
L["MINIMAP_CURRENT_WAYPOINT"] = "Aktueller Wegpunkt:"
L["MINIMAP_NO_WAYPOINT"] = "Kein aktiver Wegpunkt"
L["MINIMAP_LEFT_CLICK"] = "Linksklick: Einstellungen öffnen"
L["MINIMAP_SHIFT_CLICK"] = "Shift+Linksklick: Tracker umschalten"
L["MINIMAP_RIGHT_CLICK"] = "Rechtsklick: Pfeil umschalten"
L["MINIMAP_MIDDLE_CLICK"] = "Mittelklick: Wegpunkt löschen"
