-- ForeverLFG
-- Copyright (c) 2026 Forever. All rights reserved.
-- Custom license: see LICENSE for permissions and earlier MIT releases.
-- Permission requests: wow@werko.dev or https://werko.dev/addons/feedback/

local _, NS = ...

-- Имя таблицы сохранено для совместимости с перенесённым файлом SavedVariables.
function NS.Database()
    if type(ForeverLFGProbeDB) ~= "table" then ForeverLFGProbeDB = {} end
    local db = ForeverLFGProbeDB
    if type(db.settings) ~= "table" then db.settings = {} end
    if type(db.settings.language) ~= "string" then db.settings.language = "all" end
    return db
end

function NS.Mode() return NS.Database().settings.language end

function NS.LanguageLabel(mode)
    if mode == "" then return NS.Text("NO_LANGUAGES_SELECTED") end
    if mode == "all" then return NS.Text("ALL_LANGUAGES") end
    if mode == "default" then return NS.Text("GAME_DEFAULT") end
    if mode:find(",", 1, true) then
        local labels = {}
        for code in mode:gmatch("[^,]+") do labels[#labels + 1] = NS.LanguageLabel(code) end
        return table.concat(labels, " + ")
    end
    local label = _G["LFG_LIST_LANGUAGE_" .. mode:upper()]
    return type(label) == "string" and label ~= "" and label or mode
end

function NS.AvailableLanguages()
    local fn = C_LFGList and C_LFGList.GetAvailableLanguageSearchFilter
    if type(fn) ~= "function" then return nil, NS.English("LANGUAGES_UNAVAILABLE"), "LANGUAGES_UNAVAILABLE" end
    local ok, values = pcall(fn)
    if not ok or type(values) ~= "table" then return nil, NS.English("LANGUAGES_FAILED"), "LANGUAGES_FAILED" end
    local result, seen = {}, {}
    for _, code in ipairs(values) do
        if type(code) == "string" and code ~= "" and not seen[code] then
            result[#result + 1], seen[code] = code, true
        end
    end
    if #result == 0 then return nil, NS.English("LANGUAGES_EMPTY"), "LANGUAGES_EMPTY" end
    return result
end

function NS.LanguageFilter(mode)
    local lower = mode:lower()
    if lower == "" then return nil, nil, NS.English("SELECT_SEARCH_LANGUAGES"), "SELECT_SEARCH_LANGUAGES" end
    if lower == "default" then return nil, "default" end
    local available, err, key = NS.AvailableLanguages()
    if not available then return nil, nil, err, key end
    local filter, requested, found = {}, {}, {}
    for code in lower:gmatch("[^,]+") do requested[code] = true end
    for _, code in ipairs(available) do
        filter[code] = lower == "all" or requested[code:lower()] == true
        if requested[code:lower()] then found[#found + 1] = code; requested[code:lower()] = nil end
    end
    if lower ~= "all" and (next(requested) or #found == 0) then
        return nil, nil, "Language unavailable: " .. mode, "LANGUAGE_UNAVAILABLE"
    end
    table.sort(found)
    local selected = lower == "all" and "all" or table.concat(found, ",")
    return filter, selected
end
