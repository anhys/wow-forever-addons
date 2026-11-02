-- QuestMaster French Localization
local addonName, QM = ...
if GetLocale() ~= "frFR" then return end

local L = QM.L

-- ============================================================================
-- General
-- ============================================================================
L["ADDON_NAME"] = "QuestMaster"
L["ADDON_LOADED"] = "QuestMaster chargé. Tapez /qm pour les options."
L["VERSION"] = "Version"
L["ENABLED"] = "Activé"
L["DISABLED"] = "Désactivé"
L["YES"] = "Oui"
L["NO"] = "Non"
L["DEFAULT"] = "Par défaut"
L["RESET"] = "Réinitialiser"
L["CLOSE"] = "Fermer"
L["SAVE"] = "Sauvegarder"
L["CANCEL"] = "Annuler"
L["DELETE"] = "Supprimer"
L["UNKNOWN"] = "Inconnu"
L["NONE"] = "Aucun"
L["GO"] = "Aller"
L["SEARCH"] = "Rechercher"
L["REFRESHED"] = "Actualisé"

-- ============================================================================
-- Tabs
-- ============================================================================
L["TAB_GENERAL"] = "Général"
L["TAB_GENERAL_DESC"] = "Paramètres principaux"
L["TAB_TRACKER"] = "Suivi"
L["TAB_TRACKER_DESC"] = "Liste de quêtes"
L["TAB_ARROW"] = "Flèche"
L["TAB_ARROW_DESC"] = "Navigation"
L["TAB_MAP"] = "Carte"
L["TAB_MAP_DESC"] = "Épingles et marqueurs"
L["TAB_STATISTICS"] = "Statistiques"
L["TAB_STATISTICS_DESC"] = "Suivi d'XP"
L["TAB_DASHBOARD"] = "Tableau de bord"
L["TAB_DASHBOARD_DESC"] = "Stats & Historique"
L["TAB_AUTOMATION"] = "Automatisation"
L["TAB_AUTOMATION_DESC"] = "Fonctions auto"
L["TAB_ADVANCED"] = "Avancé"
L["TAB_ADVANCED_DESC"] = "Expert"
L["TAB_CREDITS"] = "Crédits"
L["TAB_CREDITS_DESC"] = "À propos et liens"

-- ============================================================================
-- Settings Header
-- ============================================================================
L["SETTINGS"] = "Paramètres"
L["SETTINGS_TITLE"] = "Paramètres de QuestMaster"

-- ============================================================================
-- General Settings
-- ============================================================================
L["MAIN_SETTINGS"] = "Paramètres principaux"
L["ENABLE_ADDON"] = "Activer QuestMaster"
L["ENABLE_ADDON_DESC"] = "Interrupteur principal pour toutes les fonctions"
L["LOCK_FRAMES"] = "Verrouiller les fenêtres"
L["LOCK_FRAMES_DESC"] = "Empêcher le déplacement"
L["SHOW_MINIMAP_BUTTON"] = "Afficher le bouton de la minicarte"
L["SHOW_MINIMAP_BUTTON_DESC"] = "Bouton sur la minicarte"

-- ============================================================================
-- Sounds
-- ============================================================================
L["SOUNDS"] = "Effets sonores"
L["QUEST_PROGRESS_SOUND"] = "Son de progression de quête"
L["QUEST_PROGRESS_SOUND_DESC"] = "Son lors de la progression"
L["QUEST_COMPLETE_SOUND"] = "Son de quête terminée"
L["QUEST_COMPLETE_SOUND_DESC"] = "Son lors de l'achèvement"

-- ============================================================================
-- Announcements
-- ============================================================================
L["QUEST_ANNOUNCEMENTS"] = "Annonces de quête"
L["ANNOUNCE_ACCEPT"] = "Annoncer l'acceptation de quête"
L["ANNOUNCE_ACCEPT_DESC"] = "Au groupe/guilde"
L["ACCEPT_CHANNEL"] = "Canal d'acceptation"
L["ANNOUNCE_DONE"] = "Annoncer quête terminée"
L["ANNOUNCE_DONE_DESC"] = "Au groupe/guilde"
L["COMPLETE_CHANNEL"] = "Canal d'achèvement"
L["CHANNEL_PARTY"] = "Groupe"
L["CHANNEL_GUILD"] = "Guilde"
L["CHANNEL_EMOTE"] = "Émote (/me)"
L["CHANNEL_DISABLED"] = "Désactivé"

-- Level Up
L["LEVEL_UP_ANNOUNCEMENTS"] = "Annonces de montée de niveau"
L["ANNOUNCE_LEVEL_UP"] = "Annoncer la montée de niveau"
L["ANNOUNCE_LEVEL_UP_DESC"] = "En émote/groupe"
L["LEVEL_UP_CHANNEL"] = "Canal de montée de niveau"

-- ============================================================================
-- Quick Actions
-- ============================================================================
L["QUICK_ACTIONS"] = "Actions rapides"
L["RESET_POSITIONS"] = "Réinitialiser les positions"
L["REFRESH_DATA"] = "Actualiser les données"

-- ============================================================================
-- Quest Tracker
-- ============================================================================
L["QUEST_TRACKER"] = "Suivi de quête"
L["ENABLE_TRACKER"] = "Activer le suivi"
L["ENABLE_TRACKER_DESC"] = "Afficher le panneau de quêtes"
L["FONT_SIZE"] = "Taille de police"
L["BACKGROUND_OPACITY"] = "Opacité du fond"
L["TRACKER_TITLE"] = "QuestMaster"
L["ACTIVE_QUESTS"] = "Quêtes actives"
L["READY_FOR_TURNIN"] = "Prêtes à rendre"
L["NO_ACTIVE_QUESTS"] = "Aucune quête active"

-- Display Options
L["DISPLAY_OPTIONS"] = "Options d'affichage"
L["SHOW_QUEST_LEVEL"] = "Afficher le niveau de quête"
L["SHOW_QUEST_LEVEL_DESC"] = "Niveau entre crochets"
L["SHOW_DISTANCE"] = "Afficher la distance"
L["SHOW_DISTANCE_DESC"] = "Distance jusqu'à l'objectif"
L["COLOR_BY_DIFFICULTY"] = "Colorer par difficulté"
L["COLOR_BY_DIFFICULTY_DESC"] = "Couleurs basées sur le niveau"
L["SHOW_PROGRESS_BARS"] = "Afficher les barres de progression"
L["SHOW_PROGRESS_BARS_DESC"] = "Barres sous les objectifs"
L["SHOW_COMPLETED"] = "Afficher les quêtes terminées"
L["SHOW_COMPLETED_DESC"] = "Afficher les quêtes finies"
L["MAX_QUESTS"] = "Nombre max de quêtes affichées"

-- Default Tracker
L["HIDE_BLIZZARD_TRACKER"] = "Masquer le suivi de quêtes par défaut"
L["HIDE_BLIZZARD_TRACKER_DESC"] = "Masquer le suivi de quêtes Blizzard intégré"
L["HIDE_BLIZZARD_TRACKER_COMBAT"] = "Impossible de basculer le suivi par défaut en combat."
L["HIDE_BLIZZARD_TRACKER_RELOAD"] = "Réactiver le suivi par défaut nécessite un rechargement de l'interface. Recharger maintenant ?"

-- Sorting
L["SORTING"] = "Tri"
L["SORT_BY"] = "Trier par"
L["SORT_QUESTS_BY"] = "Trier les quêtes par"
L["SORT_DISTANCE"] = "Distance"
L["SORT_LEVEL"] = "Niveau"
L["CURRENT"] = "Actuel"

-- Tracker Buttons
L["SORT"] = "Trier"
L["NAVIGATE_TO_NEAREST"] = "Naviguer vers le plus proche"
L["CLICK_TO_SET_WAYPOINT"] = "Cliquer pour définir un point de cheminement"
L["NAVIGATE_TO_TURNIN"] = "Naviguer vers le rendu"
L["NEAREST_COMPLETED_QUEST"] = "Quête terminée la plus proche"

-- ============================================================================
-- Arrow
-- ============================================================================
L["NAVIGATION_ARROW"] = "Flèche de navigation"
L["ENABLE_ARROW"] = "Activer la flèche"
L["ENABLE_ARROW_DESC"] = "Afficher la flèche de navigation"
L["ARROW_SIZE"] = "Taille de la flèche"
L["ARROW_OPACITY"] = "Opacité de la flèche"
L["ARRIVAL_DISTANCE"] = "Distance d'arrivée"

-- Arrow Display
L["DISPLAY"] = "Affichage"
L["SHOW_OBJECTIVE"] = "Afficher l'objectif"
L["SHOW_OBJECTIVE_DESC"] = "Texte de l'objectif"
L["SHOW_ETA"] = "Afficher l'heure d'arrivée"
L["SHOW_ETA_DESC"] = "Estimation du temps"

-- Arrow Status
L["ARRIVED"] = "Arrivé !"
L["NO_ACTIVE_OBJECTIVE"] = "Aucun objectif actif"
L["QUEST_OBJECTIVE"] = "Objectif de quête"
L["YARDS"] = "m"
L["KILOMETERS"] = "km"

-- Arrow Tooltip
L["ARROW_NAVIGATION"] = "Navigation"
L["OBJECTIVE"] = "Objectif"
L["LEFT_CLICK_DRAG"] = "Clic gauche + glisser pour déplacer"
L["RIGHT_CLICK_OPTIONS"] = "Clic droit pour les options"

-- Arrow Context Menu
L["HIDE_ARROW"] = "Masquer la flèche"
L["CLEAR_WAYPOINT"] = "Effacer le point de cheminement"
L["FIND_NEAREST_AUTO"] = "Trouver le plus proche (Auto)"
L["OPEN_SETTINGS"] = "Ouvrir les paramètres"

-- ETA
L["ETA"] = "Arrivée"
L["ETA_SECONDS"] = "Arrivée : %ds"
L["ETA_MINUTES"] = "Arrivée : %dm %ds"
L["ETA_HOURS"] = "Arrivée : %dh %dm"
L["MOVE_TO_CALCULATE"] = "(Déplacez-vous pour calculer l'arrivée)"

-- ============================================================================
-- Map
-- ============================================================================
L["WORLD_MAP"] = "Carte du monde"
L["ENABLE_MAP_PINS"] = "Activer les épingles de carte"
L["ENABLE_MAP_PINS_DESC"] = "Afficher les épingles de quête"
L["PIN_SIZE"] = "Taille des épingles"
L["PIN_OPACITY"] = "Opacité des épingles"

-- Pin Types
L["PIN_TYPES"] = "Types d'épingles"
L["OBJECTIVE_PINS"] = "Épingles d'objectif"
L["OBJECTIVE_PINS_DESC"] = "Objectifs de quête"
L["QUEST_AREAS"] = "Zones de quête"
L["QUEST_AREAS_DESC"] = "Surbrillance des zones"
L["TURNIN_PINS"] = "Épingles de rendu (?)"
L["TURNIN_PINS_DESC"] = "Épingles ? jaunes"
L["AVAILABLE_QUESTS"] = "Quêtes disponibles (!)"
L["AVAILABLE_QUESTS_DESC"] = "Épingles ! jaunes"
L["PATROL_PATHS"] = "Routes de patrouille des PNJ"
L["PATROL_PATHS_DESC"] = "Afficher les itinéraires de patrouille"

-- ============================================================================
-- Statistics Tab
-- ============================================================================
L["QUEST_TIMER"] = "Chronomètre de quête"
L["ENABLE_TIMER"] = "Activer le chronomètre"
L["ENABLE_TIMER_DESC"] = "Suivre le temps de quête"
L["SHOW_IN_TRACKER"] = "Afficher dans le suivi"
L["SHOW_IN_TRACKER_DESC"] = "Afficher dans le suivi"

L["XP_PER_HOUR"] = "XP/Heure"
L["ENABLE_XP_TRACKER"] = "Activer le suivi d'XP"
L["ENABLE_XP_TRACKER_DESC"] = "Calculer le taux d'XP"
L["RESET_XP"] = "Réinitialiser l'XP"

L["RESTED_XP"] = "XP de repos"
L["ENABLE_RESTED_DISPLAY"] = "Activer l'affichage du repos"
L["ENABLE_RESTED_DISPLAY_DESC"] = "Afficher l'XP de repos"
L["SHOW_BONUS_INDICATOR"] = "Afficher le bonus +50%"
L["SHOW_BONUS_INDICATOR_DESC"] = "Afficher l'indicateur de bonus"

L["LEVEL_TIME"] = "Temps par niveau"
L["ENABLE_LEVEL_TIMER"] = "Activer le chronomètre de niveau"
L["ENABLE_LEVEL_TIMER_DESC"] = "Suivre le temps par niveau"
L["SHOW_AVERAGE"] = "Afficher la moyenne"
L["SHOW_AVERAGE_DESC"] = "Afficher le temps moyen"

L["REMINDERS"] = "Rappels"
L["ENABLE_REMINDERS"] = "Activer les rappels"
L["ENABLE_REMINDERS_DESC"] = "Avertissements sacs et réparation"
L["BAG_SPACE_WARNING"] = "Avertissement d'espace de sac"
L["BAG_SPACE_WARNING_DESC"] = "Avertir quand les sacs sont pleins"
L["BAG_THRESHOLD"] = "Seuil de sac"
L["REPAIR_WARNING"] = "Avertissement de réparation"
L["REPAIR_WARNING_DESC"] = "Avertir faible durabilité"

L["ZONE_PROGRESS"] = "Progression de zone"
L["ENABLE_ZONE_PROGRESS"] = "Activer la progression de zone"
L["ENABLE_ZONE_PROGRESS_DESC"] = "Suivre par zone"

L["REPUTATION"] = "Réputation"
L["ENABLE_REP_TRACKER"] = "Activer le suivi de réputation"
L["ENABLE_REP_TRACKER_DESC"] = "Suivre la faction surveillée"

-- Quest Statistics
L["QUEST_STATISTICS"] = "Statistiques de quête"
L["TOTAL_STATISTICS"] = "Statistiques totales"
L["QUESTS_COMPLETED"] = "Quêtes terminées"
L["TOTAL_XP_GAINED"] = "XP totale gagnée"
L["AVG_QUEST_TIME"] = "Temps moyen par quête"
L["QUESTS_PER_HOUR"] = "Quêtes par heure"
L["CURRENT_LEVEL"] = "Niveau actuel"
L["TIME_ON_LEVEL"] = "Temps sur le niveau"
L["SESSION_QUESTS"] = "Quêtes de session"
L["SESSION_XP"] = "XP de session"
L["REFRESH_STATS"] = "Actualiser les statistiques"
L["RESET_SESSION"] = "Réinitialiser la session"

-- Quest Search
L["QUEST_SEARCH"] = "Recherche de quête"
L["SEARCH_PLACEHOLDER"] = "Entrez le nom ou l'ID de quête..."
L["CLICK_RESULT_HINT"] = "Cliquez sur un résultat pour définir un point de cheminement vers le début de la quête"
L["NO_QUESTS_FOUND"] = "Aucune quête trouvée correspondant à :"
L["WAYPOINT_SET_TO_QUEST"] = "Point de cheminement défini pour la quête :"
L["NO_LOCATION_DATA"] = "Aucune donnée de localisation pour :"
L["QUEST_LABEL"] = "Quête :"
L["OBJECTIVES_LABEL"] = "Objectifs :"

-- Manual Waypoint
L["MANUAL_WAYPOINT"] = "Point de cheminement manuel"
L["WAYPOINT"] = "Point de cheminement"
L["MANUAL"] = "[Manuel]"
L["CURRENT_WAYPOINT"] = "Actuel :"
L["NO_WAYPOINT_SET"] = "Aucun point de cheminement défini"
L["X_COORD"] = "X :"
L["Y_COORD"] = "Y :"
L["SET"] = "Définir"
L["INVALID_COORDINATES"] = "Coordonnées invalides (0-100)"
L["COORD_HINT"] = "Entrez des coordonnées comme 45.5 et 67.2 (valeurs 0-100)"
L["CLEAR_WAYPOINT"] = "Effacer le point de cheminement"

-- ============================================================================
-- Automation Tab
-- ============================================================================
L["QUEST_AUTOMATION"] = "Automatisation des quêtes"
L["AUTO_ACCEPT"] = "Accepter automatiquement les quêtes"
L["AUTO_ACCEPT_DESC"] = "Maj pour ignorer"
L["AUTO_COMPLETE"] = "Terminer automatiquement les quêtes"
L["AUTO_COMPLETE_DESC"] = "Maj pour ignorer"
L["SKIP_REWARD_CHOICE"] = "Ignorer le choix de récompense"
L["SKIP_REWARD_CHOICE_DESC"] = "Attendre la sélection"
L["AUTO_SHARE"] = "Partager automatiquement les quêtes"
L["AUTO_SHARE_DESC"] = "Partager avec le groupe"

L["WAYPOINT_AUTO"] = "Point de cheminement auto"
L["AUTO_SET_WAYPOINT"] = "Définir automatiquement le point de cheminement"
L["AUTO_SET_WAYPOINT_DESC"] = "Quête la plus proche"
L["AUTO_ADVANCE"] = "Avancement automatique"
L["AUTO_ADVANCE_DESC"] = "Suivant à l'achèvement"
L["PRIORITIZE_TURNINS"] = "Prioriser les rendus"
L["PRIORITIZE_TURNINS_DESC"] = "Rendus en premier"

L["QUEST_FILTERS"] = "Filtres de quête"
L["SHOW_DUNGEON"] = "Afficher les quêtes de donjon"
L["SHOW_DUNGEON_DESC"] = "Inclure les quêtes de donjon"
L["SHOW_RAID"] = "Afficher les quêtes de raid"
L["SHOW_RAID_DESC"] = "Inclure les quêtes de raid"
L["SHOW_GROUP"] = "Afficher les quêtes de groupe"
L["SHOW_GROUP_DESC"] = "Inclure les quêtes de groupe"
L["SHOW_PVP"] = "Afficher les quêtes JcJ"
L["SHOW_PVP_DESC"] = "Inclure les quêtes JcJ"
L["SHOW_LOW_LEVEL"] = "Afficher les quêtes de bas niveau"
L["SHOW_LOW_LEVEL_DESC"] = "Inclure les quêtes grises"

-- ============================================================================
-- Advanced Tab
-- ============================================================================
L["THEME"] = "Thème"
L["COLOR_THEME"] = "Thème de couleur"
L["THEME_GOLD"] = "Or (par défaut)"
L["THEME_BLUE"] = "Bleu"
L["THEME_GREEN"] = "Vert"
L["THEME_RED"] = "Rouge"
L["THEME_PURPLE"] = "Violet"
L["THEME_ORANGE"] = "Orange"
L["THEME_TEAL"] = "Sarcelle"
L["THEME_PINK"] = "Rose"
L["THEME_SILVER"] = "Argent"
L["THEME_BRONZE"] = "Bronze"

L["PERFORMANCE"] = "Performance"
L["UPDATE_INTERVAL"] = "Intervalle de mise à jour"
L["UPDATE_THROTTLE"] = "Limitation de mise à jour"
L["REDUCE_MAP_UPDATES"] = "Réduire les mises à jour de carte"
L["REDUCE_MAP_UPDATES_DESC"] = "Mises à jour différées"

L["QUEST_NOTES"] = "Notes de quête"
L["MAX_NOTE_LENGTH"] = "Longueur max de note"

L["DEBUG_TOOLS"] = "Débogage et outils"
L["DEBUG_MODE"] = "Mode débogage"
L["DEBUG_MODE_DESC"] = "Info de débogage en chat"
L["RESET_SETTINGS"] = "Réinitialiser les paramètres"
L["RELOAD_UI"] = "Recharger l'interface"
L["RESET_CONFIRM"] = "Réinitialiser tous les paramètres de QuestMaster ?"

-- ============================================================================
-- Credits Tab
-- ============================================================================
L["CREDITS_VERSION"] = "Version 1.3"
L["CREDITS_EDITION"] = "Édition All-in-One"
L["CREDITS_DESCRIPTION"] = "Extension premium de suivi de quêtes avec flèches de navigation, épingles de carte, statistiques et fonctions d'automatisation."
L["DEVELOPER"] = "Développeur"
L["ALSO_KNOWN_AS"] = "aussi connu sous le nom de"
L["DEVELOPER_BIO"] = "Développeur d'extensions WoW et créateur de contenu. En direct sur Twitch.tv/Novi_Live"
L["CONNECT"] = "Connexion"
L["TWITCH"] = "Twitch"
L["DISCORD"] = "Discord"
L["CURSEFORGE"] = "CurseForge"
L["DOWNLOADS_BUGS"] = "Téléchargements et rapports de bugs"
L["CHANGELOG"] = "Journal des modifications"
L["SPECIAL_THANKS"] = "Remerciements spéciaux"
L["THANKS_MESSAGE"] = "À tous les spectateurs, testeurs et supporters sur Twitch ! Vos retours aident à améliorer QuestMaster."

-- ============================================================================
-- Info Bar Tooltip
-- ============================================================================
L["SESSION_STATISTICS"] = "Statistiques de session"
L["CURRENT_XP"] = "XP actuelle :"
L["XP_REMAINING"] = "XP restante :"
L["XP_PER_HOUR_LABEL"] = "XP par heure :"
L["TIME_TO_LEVEL"] = "Temps jusqu'au niveau :"
L["SESSION_TIME"] = "Temps de session :"
L["RESTED_AMOUNT"] = "Montant de repos :"
L["RESTED_BUBBLES"] = "Bulles de repos :"
L["BONUS_XP"] = "XP bonus :"
L["BONUS_UNTIL_DEPLETED"] = "+50% jusqu'à épuisement"
L["CURRENT_LEVEL_LABEL"] = "Niveau actuel :"
L["AVERAGE_PER_LEVEL"] = "Moyenne par niveau :"
L["PROGRESS"] = "Progression :"
L["STATUS"] = "Statut"
L["BAG_SPACE"] = "Espace de sac :"
L["FREE"] = "libre"
L["DURABILITY"] = "Durabilité :"
L["LOWEST"] = "la plus basse"
L["TRACKED_REPUTATIONS"] = "Réputations suivies"
L["CLICK_TO_RESET_XP"] = "Cliquer pour réinitialiser le suivi d'XP"

-- ============================================================================
-- Quest Display
-- ============================================================================
L["COMPLETE"] = "TERMINÉE"
L["DONE"] = "FAIT"
L["TURN_IN"] = "Rendre"
L["TURN_IN_SUFFIX"] = " (Rendre)"
L["TIME_ON_QUEST"] = "Temps sur la quête :"
L["NOTE"] = "Note :"
L["CLICK_SET_WAYPOINT"] = "Clic gauche : Définir un point de cheminement"
L["CLICK_OPEN_QUESTLOG"] = "Shift+Clic gauche : Ouvrir le journal de quêtes"
L["CLICK_MORE_OPTIONS"] = "Clic droit : Plus d'options"
L["DISTANCE_TO_OBJECTIVE"] = "Distance jusqu'à l'objectif le plus proche"

-- Context Menu
L["SET_WAYPOINT"] = "Définir un point de cheminement"
L["SHOW_ON_MAP"] = "Afficher sur la carte"
L["EXPAND_QUEST"] = "Développer la quête"
L["COLLAPSE_QUEST"] = "Réduire la quête"
L["EDIT_NOTE"] = "Modifier la note"
L["ADD_NOTE"] = "Ajouter une note"
L["SHARE_QUEST"] = "Partager la quête"
L["ABANDON_QUEST"] = "Abandonner la quête"

-- ============================================================================
-- Chat Messages
-- ============================================================================
L["MSG_PREFIX"] = "|cFF00FF00QuestMaster:|r"
L["MSG_ADDON_LOADED"] = "|cFFFFD700QuestMaster|r chargé ! créé par |cFF00FF00JugoBetrugoTV|r alias |cFFFF8800Novi_Live|r"
L["MSG_TWITCH"] = "|cFF9146FF  Twitch.tv/Novi_Live|r - Venez traîner !"
L["MSG_BUGS"] = "|cFF888888  Bugs ? Signalez sur CurseForge ou|r |cFF5865F2Discord.gg/rv2BsbE|r"

L["MSG_QUEST_ACCEPTED"] = "Quête acceptée :"
L["MSG_ACCEPTED_QUEST"] = "Quête acceptée :"
L["MSG_QUEST_COMPLETED"] = "Quête terminée :"
L["MSG_QUEST_READY"] = "Quête prête à rendre :"
L["MSG_OBJECTIVE_COMPLETE"] = "Objectif terminé :"
L["MSG_ABANDONED"] = "Abandonné :"
L["MSG_SHARED"] = "Partagé :"
L["MSG_CANNOT_SHARE"] = "Cette quête ne peut pas être partagée"
L["MSG_QUEST_NOT_FOUND"] = "Impossible de trouver la quête dans le journal"

L["MSG_LEVEL_UP"] = "|cFFFFD700MONTÉE DE NIVEAU !|r Vous avez atteint le niveau |cFF00FF00%d|r !"
L["MSG_TIME_FROM_LEVEL"] = "Temps du niveau %d au niveau %d :"
L["MSG_REACHED_LEVEL"] = "Niveau %d atteint !"
L["MSG_REACHED_LEVEL_TIME"] = "Niveau %d atteint ! (%s depuis le niveau %d)"

L["MSG_WAYPOINT_SET"] = "Point de cheminement défini à %.1f, %.1f - %s"
L["MSG_WAYPOINT_CORPSE"] = "Point de cheminement défini à l'emplacement de votre cadavre"
L["MSG_WAYPOINT_RESTORED"] = "Point de cheminement précédent restauré"
L["MSG_NAVIGATING_TO"] = "Navigation vers :"
L["MSG_AUTO_NAV_TURNIN"] = "Auto-navigation vers le rendu"
L["MSG_AUTO_NAV_TO"] = "Auto-navigation vers :"
L["MSG_NO_QUESTS_NAV"] = "Aucune quête vers laquelle naviguer"
L["MSG_TURNIN"] = "Rendre :"
L["MSG_NO_COMPLETED"] = "Aucune quête terminée à rendre"

L["MSG_XP_RESET"] = "Suivi d'XP/Heure réinitialisé"
L["MSG_HISTORY_CLEARED"] = "Historique de quêtes effacé"
L["MSG_SESSION_RESET"] = "Statistiques de session réinitialisées"
L["MSG_NOTE_SAVED"] = "Note sauvegardée pour :"
L["MSG_NOTE_DELETED"] = "Note supprimée pour :"

L["MSG_COORDS_INVALID"] = "Les coordonnées doivent être entre 0 et 100"
L["MSG_NO_MAP"] = "Impossible de déterminer la carte actuelle"
L["MSG_INVALID_COORDS"] = "Coordonnées invalides. Utilisez : /qm way 45.2 67.8"
L["MSG_DB_FAIL"] = "Échec de l'initialisation de la base de données :"
L["MSG_DB_WARNING"] = "Avertissement : Profil de base de données non disponible"
L["MSG_INIT_FAIL"] = "Échec de l'initialisation de %s :"
L["MSG_SETTINGS_NOT_READY"] = "Paramètres non prêts"
L["MSG_UNKNOWN_CMD"] = "Commande inconnue. Tapez /qm help pour une liste de commandes."

-- Help
L["HELP_USAGE"] = "Utilisation :"
L["HELP_SEARCH"] = "Utilisation : /qm search <nom ou id de quête>"
L["HELP_WAY"] = "Utilisation : /qm way <x> <y> [description]"
L["HELP_WAY_EXAMPLE"] = "  Exemple : /qm way 45.2 67.8 Point de rencontre"
L["HELP_CREDITS"] = "/qm credits - Afficher les crédits"
L["HELP_STATS"] = "/qm stats - Afficher les statistiques de quête"
L["HELP_SEARCH_CMD"] = "/qm search <nom> - Rechercher dans la base de quêtes"
L["HELP_WAY_CMD"] = "/qm way <x> <y> [desc] - Définir un point de cheminement manuel"

-- Statistics Print
L["STATS_HEADER"] = "========== Statistiques de quête =========="
L["STATS_TOTAL_COMPLETED"] = "Total terminées : %d quêtes"
L["STATS_TOTAL_XP"] = "XP totale des quêtes :"
L["STATS_AVG_TIME"] = "Temps moyen par quête :"
L["STATS_QUESTS_HOUR"] = "Quêtes/Heure : %.1f"
L["STATS_FASTEST"] = "Quête la plus rapide : %s (%s)"
L["STATS_SLOWEST"] = "Quête la plus lente : %s (%s)"
L["STATS_SESSION_HEADER"] = "--- Statistiques de session ---"
L["STATS_SESSION_COMPLETED"] = "Terminées cette session : %d quêtes"
L["STATS_SESSION_XP"] = "XP de cette session :"
L["STATS_TOP_ZONES"] = "--- Meilleures zones ---"

-- Search Results
L["SEARCH_NO_RESULTS"] = "Aucune quête trouvée pour '%s'"
L["SEARCH_HEADER"] = "=== Recherche de quête : '%s' (%d résultats) ==="
L["SEARCH_COMPLETED"] = "[Terminée]"
L["SEARCH_IN_PROGRESS"] = "[En cours]"

-- Waypoint
L["WAYPOINT_FORMAT"] = "Point de cheminement (%.1f, %.1f)"
L["YOUR_CORPSE"] = "Votre cadavre"

-- Tooltip
L["QUEST_ITEM"] = "Objet de quête"
L["DROP_RATE_NOTE"] = "(Le taux de drop estimé varie)"
L["QUEST_NOTE"] = "Note de quête"

-- Time Format
L["TIME_HOURS_MINS"] = "%dh %dmin"
L["TIME_HOURS"] = "%dh"
L["TIME_MINS"] = "%d min"
L["TIME_ZERO"] = "0 min"
L["AVG_FORMAT"] = "(moy : %s)"
L["LVL_PREFIX"] = "Niv :"
L["XP_HOUR_PREFIX"] = "XP/h :"
L["RESTED_PREFIX"] = "Repos :"

-- Responsive Layout
L["QM_SHORT"] = "QM"
L["QUESTS_SHORT"] = "Quêtes"

-- Quest Type Tags
L["DUNGEON_TAG"] = "D"
L["RAID_TAG"] = "R"
L["GROUP_TAG"] = "G"
L["DUNGEON_QUESTS"] = "Quêtes de donjon"
L["RAID_QUESTS"] = "Quêtes de raid"
L["BEST"] = "Meilleur"
L["MSG_NEW_BEST_TIME"] = "Nouveau record pour %s: %s (précédent: %s)"

-- Party Quest Sync
L["PARTY_SYNC"] = "Sync de groupe"
L["ENABLE_PARTY_SYNC"] = "Activer la sync de groupe"
L["ENABLE_PARTY_SYNC_DESC"] = "Partager la progression avec le groupe"
L["PARTY_SHOW_PROGRESS"] = "Afficher la progression du groupe"
L["PARTY_SHOW_PROGRESS_DESC"] = "Afficher dans le tracker"
L["PARTY_SHOW_INDICATOR"] = "Indicateur de groupe"
L["PARTY_SHOW_INDICATOR_DESC"] = "Icône sur les quêtes partagées"
L["PARTY_SYNC_ICON"] = "G"

-- Statistics Dashboard
L["DASHBOARD_TITLE"] = "Tableau de bord"
L["DASH_TITLE"] = "Tableau de bord statistiques"
L["OPEN_DASHBOARD"] = "Ouvrir le tableau de bord"
L["DASH_OVERVIEW"] = "Aperçu"
L["DASH_ZONES"] = "Progression par zone"
L["DASH_HISTORY"] = "Historique des quêtes"
L["DASH_DETAILED_STATS"] = "Statistiques détaillées"
L["DASH_FASTEST_QUEST"] = "Quête la plus rapide"
L["DASH_SLOWEST_QUEST"] = "Quête la plus lente"
L["DASH_TOP_ZONES"] = "Meilleures zones de quêtes"
L["DASH_OVERALL_PROGRESS"] = "Progression globale"
L["DASH_NO_ZONE_DATA"] = "Aucune donnée de zone disponible"
L["DASH_NO_HISTORY"] = "Aucun historique de quêtes"
L["DASH_SHOWING_ENTRIES"] = "%d sur %d entrées"
L["DASH_MORE_ENTRIES"] = "... et %d entrées de plus"
L["DASH_SORT_TIME"] = "Heure"
L["DASH_SORT_NAME"] = "Nom"
L["DASH_SORT_LEVEL"] = "Niveau"
L["DASH_SORT_DURATION"] = "Durée"
L["DASH_COL_QUEST"] = "Quête"
L["DASH_COL_LEVEL"] = "Niv"
L["DASH_COL_XP"] = "XP"
L["DASH_COL_TIME"] = "Durée"
L["DASH_COL_DATE"] = "Date"

-- Zone Filter & Minimap Tooltip
L["ZONE_FILTER"] = "Zone actuelle uniquement"
L["ZONE_FILTER_DESC"] = "Afficher uniquement les quêtes de la zone actuelle"
L["MINIMAP_ACTIVE_QUESTS"] = "Quêtes actives:"
L["MINIMAP_COMPLETED"] = "Terminées:"
L["MINIMAP_IN_ZONE"] = "Dans la zone:"
L["MINIMAP_CURRENT_WAYPOINT"] = "Point de passage actuel:"
L["MINIMAP_NO_WAYPOINT"] = "Aucun point de passage actif"
L["MINIMAP_LEFT_CLICK"] = "Clic gauche: Ouvrir les paramètres"
L["MINIMAP_SHIFT_CLICK"] = "Shift+Clic gauche: Basculer le tracker"
L["MINIMAP_RIGHT_CLICK"] = "Clic droit: Basculer la flèche"
L["MINIMAP_MIDDLE_CLICK"] = "Clic milieu: Effacer le point de passage"
