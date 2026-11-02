-- ForeverLFG
-- Copyright (c) 2026 Forever. All rights reserved.
-- Custom license: see LICENSE for permissions and earlier MIT releases.
-- Permission requests: wow@werko.dev or https://werko.dev/addons/feedback/

local _, NS = ...

function NS.Describe(value)
    if type(value) ~= "table" then return tostring(value) end
    local parts = {}
    for key, item in pairs(value) do parts[#parts + 1] = tostring(key) .. "=" .. tostring(item) end
    table.sort(parts)
    return "{" .. table.concat(parts, ", ") .. "}"
end

function NS.ReadOptional(name)
    local fn = C_LFGList and C_LFGList[name]
    if type(fn) ~= "function" then return "function unavailable" end
    local ok, value = pcall(fn)
    if ok then return value end
    return "call-error"
end

function NS.Context()
    local version, build, buildDate, interface = GetBuildInfo()
    local region = GetCurrentRegionName and GetCurrentRegionName()
    return {
        addonVersion = "0.7.29", version = version, build = build, buildDate = buildDate, interface = interface,
        locale = GetLocale(), region = region and region ~= "" and region or "unknown",
        level = UnitLevel("player"), faction = UnitFactionGroup("player"),
        ignoreSuggestedLevel = GetCVar("disableSuggestedLevelActivityFilter"),
    }
end

function NS.Summary(run)
    local prefix = (run.requestID and "#" .. run.requestID .. " " or "") .. run.mode .. (run.wide and " wide" or "") .. ": " .. run.status
    if type(run.elapsed) == "number" then prefix = prefix .. string.format(" (%.1f s)", run.elapsed) end
    if not run.raw then return prefix .. (run.reason and " - " .. run.reason or "") end
    return string.format("%s; received=%d (API total=%s), filtered=%d (API total=%s); players=%d, groups=%d, self=%d, delisted=%d, missing=%d",
        prefix, run.raw.count, tostring(run.raw.total), run.filtered.count, tostring(run.filtered.total),
        run.filtered.solo, run.filtered.groups, run.filtered.self, run.filtered.delisted, run.filtered.missing)
end

local LIMIT = 50
local sources = {
    ["language-menu"] = "Search after language selection",
    ["globe-right-click"] = "Globe right-click",
    ["search-menu"] = "Search menu item",
    ["refresh-button"] = "Refresh button",
    slash = "Search command", click = "Manual search",
}

-- Внешняя ошибка может быть локализована движком. Сохраняем её байты без потери данных.
function NS.DiagnosticText(value)
    return (tostring(value):gsub("[\128-\255]", function(byte) return string.format("\\x%02X", byte:byte()) end))
end

local function DiagnosticValue(value)
    if type(value) == "string" then return NS.DiagnosticText(value) end
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[DiagnosticValue(key)] = DiagnosticValue(item) end
    return copy
end

function NS.Say(message) print("|cff80dfffForeverLFG:|r " .. NS.DiagnosticText(message)) end
function NS.SourceLabel(source) return sources[source or "click"] or tostring(source) end

function NS.NextRequestID()
    local db = NS.Database()
    db.nextRequestID = (tonumber(db.nextRequestID) or 0) + 1
    return db.nextRequestID
end

function NS.SearchParameters(category, filter, preferred, languages, crossFaction, advanced, activities)
    return "category=" .. tostring(category) .. "; activities=" .. NS.Describe(activities)
        .. "; languages=" .. NS.Describe(languages) .. "; filter=" .. tostring(filter)
        .. "; preferred=" .. tostring(preferred) .. "; crossFaction=" .. tostring(crossFaction)
        .. "; advanced=" .. NS.Describe(advanced)
end

-- Только для миграции: статусы новых запросов всегда содержат английские коды.
local legacyStatus = {
    ["ответ"] = "response", ["ответ без точного сопоставления"] = "response-unmatched",
    ["тайм-аут"] = "timeout", ["ошибка вызова"] = "call-error", ["ошибка чтения"] = "read-error",
    ["вызов заблокирован"] = "blocked", ["отказ"] = "failed", ["заменён другим поиском"] = "superseded",
}
local legacyKind = {
    ["Архив"] = "Legacy", ["Поиск"] = "Search", ["Ошибка"] = "Error",
    ["Действие"] = "Action", ["Язык"] = "Language", ["Сессия"] = "Session",
}
local function LegacyRun(run)
    if type(run) ~= "table" then return nil end
    local copy = DiagnosticValue(run)
    copy.status = legacyStatus[run.status] or copy.status
    if run.mode == "штатный/другой" then copy.mode = "native/other" end
    return copy
end

local function Trim(journal)
    while #journal > LIMIT do table.remove(journal, 1) end
end

function NS.Log(kind, text, isError, run)
    local db = NS.Database()
    if type(db.journal) ~= "table" then db.journal = {} end
    db.journal[#db.journal + 1] = { timestamp = time(), kind = NS.DiagnosticText(kind), text = NS.DiagnosticText(text), isError = isError or nil, run = DiagnosticValue(run) }
    Trim(db.journal)
end

function NS.InitializeLog()
    local db = NS.Database()
    if type(db.journal) ~= "table" then db.journal = {} end
    if db.journalVersion ~= 1 and db.journalVersion ~= 2 then
        local history = {}
        for _, oldRun in ipairs(db.runs or {}) do
            local run = LegacyRun(oldRun)
            local text = NS.Summary(run)
            if run.categoryID then text = text .. "; category=" .. tostring(run.categoryID) .. "; activities=" .. NS.Describe(run.activityIDs) end
            history[#history + 1] = { timestamp = run.timestamp, kind = "Legacy", text = text, run = run,
                isError = run.status ~= "response" and run.status ~= "response-unmatched" or nil }
        end
        for _, action in ipairs(db.blockedActions or {}) do
            history[#history + 1] = { timestamp = action.timestamp, kind = "Legacy", isError = true,
                text = tostring(action.event) .. ": " .. tostring(action.owner) .. " / " .. tostring(action.functionName) }
        end
        for i, entry in ipairs(history) do entry.order = i end
        table.sort(history, function(a, b)
            local first, second = a.timestamp or 0, b.timestamp or 0
            return first == second and a.order < b.order or first < second
        end)
        for _, entry in ipairs(history) do entry.order = nil; db.journal[#db.journal + 1] = entry end
    end
    if db.journalVersion ~= 2 then
        for _, entry in ipairs(db.journal) do
            entry.kind = legacyKind[entry.kind] or NS.DiagnosticText(entry.kind)
            local text = tostring(entry.text)
            entry.text = text:find("[\128-\255]") and ("Legacy message (UTF-8 bytes escaped): " .. NS.DiagnosticText(text)) or text
            entry.run = LegacyRun(entry.run)
        end
        db.journalVersion = 2
    end
    -- После миграции остаётся только единый ограниченный журнал.
    db.runs, db.blockedActions = nil, nil
    Trim(db.journal)
end

function NS.PrintLog(option)
    local db = NS.Database()
    if option == "clear" then
        db.journal, db.runs, db.blockedActions = {}, nil, nil
        db.journalVersion = 2
        NS.Say("Log cleared. Language setting preserved.")
        return
    end
    local errorsOnly = option == "errors"
    if option ~= "" and not errorsOnly then
        NS.Say("Usage: /flfg log [errors|clear]. The last 50 events are retained.")
        return
    end
    local entries = {}
    for _, entry in ipairs(db.journal or {}) do
        if not errorsOnly or entry.isError then entries[#entries + 1] = entry end
    end
    if #entries == 0 then NS.Say(errorsOnly and "No errors in the log." or "Log is empty."); return end
    NS.Say(string.format("%s: %d entries from the last 50 events.", errorsOnly and "Errors" or "Log", #entries))
    for i = 1, #entries do
        local entry = entries[i]
        local stamp = type(entry.timestamp) == "number" and date("%d.%m %H:%M:%S", entry.timestamp) or "time unknown"
        NS.Say("[" .. stamp .. "] " .. entry.kind .. ": " .. entry.text)
    end
end

SLASH_FOREVERLFG1 = "/flfg"
local function PlayerSay(key) print("ForeverLFG: " .. NS.Text(key)) end
SlashCmdList.FOREVERLFG = function(message)
    local mode, option, value = message:match("^%s*(%S*)%s*(%S*)%s*(%S*)%s*$")
    if not mode then PlayerSay("HELP_USAGE"); return end
    mode, option = mode:lower(), option:lower()
    if mode == "debug" then
        if option == "q" and (value == "1" or value == "0") then
            NS.Quests:SetDebugAll(value == "1")
            print("ForeverLFG: "..NS.Text(value == "1" and "QUEST_DEBUG_ON" or "QUEST_DEBUG_OFF"))
        else print("ForeverLFG: "..NS.Text("QUEST_DEBUG_USAGE")) end
        return
    end
    if value ~= "" then PlayerSay("HELP_USAGE"); return end
    if mode == "tutorial" and option == "" then NS.OpenQuestTutorial()
    elseif mode == "quests" and option == "" then NS.OpenQuestMatches()
    elseif mode == "dchanel" and option == "" then NS.OpenQuestWindow("all")
    elseif mode == "settings" and option == "" then
        NS.EnsureAddonSettings()
        if NS.AddonSettingsCategory and Settings.OpenToCategory then Settings.OpenToCategory(NS.AddonSettingsCategory:GetID()) end
    elseif mode == "log" then NS.PrintLog(option)
    elseif mode == "info" and option == "" then
        NS.Say("Client: " .. NS.Describe(NS.Context()) .. "; selected language=" .. NS.Mode())
        for _, name in ipairs({ "GetAvailableLanguageSearchFilter", "GetDefaultLanguageSearchFilter", "GetLanguageSearchFilter" }) do
            NS.Say(name .. ": " .. NS.Describe(NS.ReadOptional(name)))
        end
    elseif (mode == "" or mode == "help") and option == "" then
        PlayerSay("HELP_COMMANDS")
        PlayerSay("HELP_HELP")
        PlayerSay("HELP_SEARCH")
    else
        PlayerSay("HELP_UNKNOWN")
    end
end
