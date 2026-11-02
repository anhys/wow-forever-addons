-- ForeverLFG
-- Copyright (c) 2026 Forever. All rights reserved.
-- Custom license: see LICENSE for permissions and earlier MIT releases.
-- Permission requests: wow@werko.dev or https://werko.dev/addons/feedback/

local _, NS = ...
-- Переводы интерфейса независимы от списка языков поиска, который возвращает API.
NS.clientLocale = GetLocale()
NS.english = {
    TITLE = "Group Finder",
    LANGUAGE = "Selected languages",
    GROUPS = "Groups: %d",
    PLAYERS = "Players: %d",
    LEFT_CLICK = "Left-click",
    RIGHT_CLICK = "Right-click",
    SELECT_LANGUAGE = "Choose language",
    REPEAT_SEARCH = "Repeat search",
    LOG_HINT = "Log: /flfg log",
    LANGUAGE_MENU = "Search languages",
    SEARCH_FOR = "Search: %s",
    ALL_LANGUAGES = "All languages",
    GAME_DEFAULT = "Game default",
    NO_LANGUAGES_SELECTED = "None selected",
    SELECT_SEARCH_LANGUAGES = "Choose at least one language",
    LANGUAGES_UNAVAILABLE = "Language list unavailable. Use Game default.",
    LANGUAGES_FAILED = "Could not retrieve languages",
    LANGUAGES_EMPTY = "No languages available yet. Use Game default.",
    LANGUAGE_UNAVAILABLE = "Selected language unavailable",
    OPEN_SEARCH = "Open the group search tab",
    SELECT_CATEGORY = "Select a category",
    READ_CATEGORY_FAILED = "Could not read category",
    READ_FILTERS_FAILED = "Could not read filters",
    ACTIVITIES_UNAVAILABLE = "Activities unavailable",
    NO_ACTIVITIES = "No matching activities",
    OUT_OF_COMBAT = "Search available out of combat",
    SEARCHING = "Searching...",
    RETRY_IN = "Retry in %d s",
    READY = "Ready to search",
    START_SEARCH = "Choose a language and start searching",
    SEARCH_COMPLETE = "Search complete",
    LANGUAGE_UNCONFIRMED = "List updated; language unconfirmed",
    REFRESH_LANGUAGE = "Language selected. Search again",
    SEARCH_INCOMPLETE = "Search did not complete",
    NATIVE_SEARCHING = "Default search in progress...",
    NO_RESPONSE = "No response. Try again",
    WAIT_CURRENT = "Wait for the current search",
    SEARCH_UNAVAILABLE = "Search unavailable",
    WAIT_RETRY = "Wait before searching again",
    OPERATION_BLOCKED = "Operation blocked",
    NATIVE_FAILED = "Another search failed",
    READ_RESULTS_FAILED = "Could not read results",
    NATIVE_COMPLETE = "Game search complete. Use Refresh for your selected languages",
    HELP_COMMANDS = "/flfg quests - shared quest players; /flfg tutorial - introduction; /flfg settings - addon settings.",
    HELP_HELP = "/flfg help - help.",
    HELP_SEARCH = "Group Finder: choose filters and use Refresh. The default refresh button uses Blizzard rules.",
    HELP_UNKNOWN = "Use Group Finder filters and Refresh. Commands: /flfg quests, /flfg tutorial, /flfg settings, /flfg help.",
    HELP_USAGE = "Help: /flfg help",
}

local function Format(strings, key, ...)
    local value = strings[key] or NS.english[key]
    assert(value, "Unknown localization key: " .. tostring(key))
    if select("#", ...) > 0 then return string.format(value, ...) end
    return value
end

function NS.Text(key, ...) return Format(NS.translation or NS.english, key, ...) end
function NS.English(key, ...) return Format(NS.english, key, ...) end
