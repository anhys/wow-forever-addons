-- ForeverLFG
-- Copyright (c) 2026 Forever. All rights reserved.
-- Custom license: see LICENSE for permissions and earlier MIT releases.
-- Permission requests: wow@werko.dev or https://werko.dev/addons/feedback/

local addonName, NS = ...
local frame = CreateFrame("Frame")
local pending, issuing, hooked, externalPending, uncertain, timedOut
local lastSearch, externalID = -math.huge, 0
local viewGeneration = 0
local confirmedKey

local Say = NS.Say
local BuildRequest
local function RequestKey(run)
    local activities, languages = {}, {}
    for _, id in ipairs(run.activityIDs or {}) do activities[#activities+1] = id end
    for code, selected in pairs(run.languages or {}) do if selected then languages[#languages+1] = code end end
    table.sort(activities); table.sort(languages)
    return tostring(run.categoryID) .. ":" .. table.concat(activities, ",") .. ":" .. (run.languages and table.concat(languages, ",") or "default")
end
function NS.SearchSelectionIsCurrent()
    if not confirmedKey or NS.IsPending() then return false end
    local ok, run = pcall(BuildRequest, NS.Mode())
    return ok and run ~= nil and RequestKey(run) == confirmedKey
end

function NS.SetStatus(key, detail, kind, run)
    local message = NS.English(key)
    NS.statusKey, NS.status, NS.detail, NS.statusKind = key, message, detail or message, kind or "info"
    local isError = kind == "error" or kind == "validation"
    NS.Log(isError and "Error" or "Search", detail and detail ~= message and message .. ": " .. detail or message, isError, run)
    if NS.UpdateUI then NS.UpdateUI() end
end

function NS.IsPending() return pending ~= nil or externalPending end
function NS.SearchTimedOut() return timedOut == true and not NS.IsPending() end

function NS.CooldownRemaining() return math.max(0, math.ceil(5 - (GetTime() - lastSearch))) end

function NS.ShortStatus()
    -- Проверяем поля при наведении без поиска и записи в журнал.
    local run, _, key = BuildRequest(NS.Mode())
    if not run then return NS.Text(key), false end
    if InCombatLockdown() then return NS.Text("OUT_OF_COMBAT"), true end
    if NS.IsPending() then return NS.Text("SEARCHING"), true end
    if NS.statusKind == "cooldown" then
        local remaining = NS.CooldownRemaining()
        return remaining > 0 and NS.Text("RETRY_IN", remaining) or NS.Text("READY"), true
    end
    if NS.statusKind == "validation" then return NS.Text("READY"), true end
    return NS.Text(NS.statusKey or "START_SEARCH"), true
end

-- Доступность нашего пункта меню. Проверка не пишет в журнал и не отправляет запрос.
function NS.SearchButtonState()
    local ok, run, _, key = pcall(BuildRequest, NS.Mode())
    if not ok then return false, "SEARCH_UNAVAILABLE" end
    if not run then return false, key end
    if InCombatLockdown() then return false, "OUT_OF_COMBAT" end
    if NS.IsPending() then return false, "WAIT_CURRENT" end
    for _, name in ipairs({ "Search", "GetSearchResults", "GetFilteredSearchResults", "GetSearchResultInfo" }) do
        if not C_LFGList or type(C_LFGList[name]) ~= "function" then return false, "SEARCH_UNAVAILABLE" end
    end
    local remaining = NS.CooldownRemaining()
    if remaining > 0 then return false, "RETRY_IN", remaining end
    return true, "APPLY_LANGUAGES"
end

local Describe, ReadOptional, Context, Summary = NS.Describe, NS.ReadOptional, NS.Context, NS.Summary

local function ObserveView(run)
    local generation = viewGeneration
    -- Отложено только чтение: штатные обработчики события должны закончить обновление.
    -- Новый запрос отменяет наблюдение, чтобы не приписать его дерево прежнему ответу.
    C_Timer.After(0, function()
        if generation ~= viewGeneration or not NS.Filters or not NS.Filters.BrowseSummary then return end
        local ok, detail = pcall(NS.Filters.BrowseSummary)
        NS.Log("View", (run.requestID and "#" .. run.requestID .. " " or "") .. run.mode .. "; "
            .. (ok and detail or "snapshot unavailable: " .. tostring(detail)))
    end)
end

local function CountResults(total, ids)
    assert(type(ids) == "table", "API did not return a result table")
    local result = { total = total, count = #ids, solo = 0, groups = 0, self = 0, delisted = 0, missing = 0 }
    for _, id in ipairs(ids) do
        local info = C_LFGList.GetSearchResultInfo(id)
        if not info then result.missing = result.missing + 1
        elseif info.isDelisted then result.delisted = result.delisted + 1
        elseif info.hasSelf then result.self = result.self + 1
        elseif info.numMembers <= 1 then result.solo = result.solo + 1
        else result.groups = result.groups + 1 end
    end
    return result
end

local function Finish(status, reason)
    if not pending then return end
    local run = pending
    pending = nil
    NS.resultCounts = run.filtered
    confirmedKey = status == "response" and not run.attributionUncertain and run.filtered and RequestKey(run) or nil
    run.status, run.reason = status, reason and tostring(reason) or nil
    run.elapsed = GetTime() - run.started
    -- Не записываем флаги Blizzard и не вызываем его UpdateResults/UpdateButtonState.
    if run.diagnostic then Say(Summary(run)) end
    if run.filtered then
        local detail = Summary(run)
        if run.attributionUncertain then
            detail = detail .. "\nThe response cannot be matched to a request after an earlier failure. This is the shared result list; the selected language is not confirmed."
        elseif run.mode ~= NS.Mode() then
            detail = detail .. "\nA different language is selected. Click Refresh to search again."
        end
        local short = "SEARCH_COMPLETE"
        if run.attributionUncertain then short = "LANGUAGE_UNCONFIRMED"
        elseif run.mode ~= NS.Mode() then short = "REFRESH_LANGUAGE" end
        NS.SetStatus(short, detail, (run.attributionUncertain or run.mode ~= NS.Mode()) and "info" or "success", run)
        ObserveView(run)
    else
        NS.SetStatus("SEARCH_INCOMPLETE", Summary(run) .. "\nRetry manually using Refresh.", "error", run)
    end
end

local function EnsureHook()
    if hooked then return true end
    local ok = pcall(hooksecurefunc, C_LFGList, "Search", function(category, filter, preferred, languages, crossFaction, advanced, activities)
        lastSearch = GetTime()
        if issuing then return end
        confirmedKey = nil
        timedOut = nil
        viewGeneration = viewGeneration + 1
        NS.resultCounts = nil
        if externalPending then
            NS.Log("Search", "#" .. externalPending.requestID .. " replaced by another external request; response attribution is uncertain")
            uncertain = true
        end
        externalPending = { requestID = NS.NextRequestID(), mode = "native/other", started = GetTime() }
        externalID = externalID + 1
        local token = externalID
        if pending then
            uncertain = true
            Finish("superseded", "The response cannot be attributed to the selected language")
        end
        local requestID = externalPending.requestID
        NS.SetStatus("NATIVE_SEARCHING", "#" .. requestID .. " native/other: " .. NS.SearchParameters(category, filter, preferred, languages, crossFaction, advanced, activities))
        C_Timer.After(30, function()
            if token == externalID and externalPending then
                externalPending, uncertain, timedOut = nil, true, true
                NS.SetStatus("NO_RESPONSE", "#" .. requestID .. " native/other: timeout after 30 s; a late response may change the shared list.", "error")
            end
        end)
    end)
    hooked = ok
    return ok
end

BuildRequest = function(mode, wide, diagnostic, source)
    local browse = LFGBrowseFrame
    if not browse or not browse:IsShown() or not browse.CategoryDropdown or not browse.ActivityDropdown then
        return nil, NS.English("OPEN_SEARCH"), "OPEN_SEARCH"
    end
    local dropdown = browse.CategoryDropdown
    if type(dropdown.GetValue) ~= "function" then return nil, "Category selector method unavailable", "SELECT_CATEGORY" end
    local ok, categoryID = pcall(dropdown.GetValue, dropdown)
    if not ok then return nil, "Category read failed: " .. tostring(categoryID), "READ_CATEGORY_FAILED" end
    if type(categoryID) ~= "number" or categoryID <= 0 then return nil, NS.English("SELECT_CATEGORY"), "SELECT_CATEGORY" end
    local languages, canonical, err, key = NS.LanguageFilter(mode)
    if not canonical then return nil, err, key end
    local activities
    if not wide then
        local values = browse.ActivityDropdown.selectedValues
        if type(values) ~= "table" then return nil, "Unknown activity filter", "READ_FILTERS_FAILED" end
        if #values == 0 then
            if type(LFGUtil_GetFilteredActivities) ~= "function" then return nil, "Activity list function unavailable", "ACTIVITIES_UNAVAILABLE" end
            local ok, result = pcall(LFGUtil_GetFilteredActivities, categoryID)
            if not ok or type(result) ~= "table" then return nil, "Could not retrieve activities", "ACTIVITIES_UNAVAILABLE" end
            values = result
        end
        activities = {}
        for i, id in ipairs(values) do activities[i] = id end
        if #activities == 0 then return nil, "No activities for the selected filters", "NO_ACTIVITIES" end
    end
    return { mode = canonical, wide = wide, diagnostic = diagnostic, source = source or "click",
        categoryID = categoryID, activityIDs = activities, languages = languages }
end

-- Пользовательский запуск идёт из клика по глобусу/меню. Команды диагностики и таймеры не запускают Search.
function NS.Request(mode, wide, diagnostic, source)
    NS.Log("Action", NS.SourceLabel(source) .. "; language=" .. tostring(mode or NS.Mode()) .. (wide and "; wide" or ""))
    local ok, run, err, short = pcall(BuildRequest, mode or NS.Mode(), wide, diagnostic, source)
    if not ok then NS.SetStatus("READ_FILTERS_FAILED", "Search context unavailable", "error"); return false end
    if not run then
        NS.resultCounts = nil
        NS.SetStatus(short, err, "validation")
        if diagnostic then Say(err) end
        return false
    end
    if InCombatLockdown() then NS.SetStatus("OUT_OF_COMBAT", nil, "validation"); return false end
    if NS.IsPending() then
        NS.SetStatus("WAIT_CURRENT", "No search was queued. Right-click the globe after the response.")
        return false
    end
    for _, name in ipairs({ "Search", "GetSearchResults", "GetFilteredSearchResults", "GetSearchResultInfo" }) do
        if not C_LFGList or type(C_LFGList[name]) ~= "function" then NS.SetStatus("SEARCH_UNAVAILABLE", "Missing C_LFGList." .. name, "error"); return false end
    end
    if not EnsureHook() then NS.SetStatus("SEARCH_UNAVAILABLE", "Could not install the search observer", "error"); return false end
    local delay = 5 - (GetTime() - lastSearch)
    if delay > 0 then
        NS.SetStatus("WAIT_RETRY", "Request not sent: cooldown between searches. Retry manually.", "cooldown")
        return false
    end
    run.requestID = NS.NextRequestID()
    run.context, run.timestamp, run.started = Context(), time(), GetTime()
    run.attributionUncertain = uncertain or nil
    run.availableLanguages = ReadOptional("GetAvailableLanguageSearchFilter")
    run.defaultLanguages = ReadOptional("GetDefaultLanguageSearchFilter")
    run.savedLanguages = ReadOptional("GetLanguageSearchFilter")
    NS.resultCounts = nil
    pending, issuing, lastSearch, confirmedKey = run, true, GetTime(), nil
    viewGeneration = viewGeneration + 1
    NS.SetStatus("SEARCHING", "#" .. run.requestID .. " language=" .. run.mode .. "; " .. NS.SearchParameters(run.categoryID, 0, 0, run.languages, false, nil, run.activityIDs)
        .. "; available=" .. Describe(run.availableLanguages) .. "; default=" .. Describe(run.defaultLanguages) .. "; saved API=" .. Describe(run.savedLanguages))
    if run.diagnostic then Say("Request " .. run.mode .. "; category=" .. run.categoryID .. "; activities=" .. (run.activityIDs and table.concat(run.activityIDs, ",") or "nil")) end
    local ok, failure = pcall(C_LFGList.Search, run.categoryID, 0, 0, run.languages, false, nil, run.activityIDs)
    issuing = false
    -- BLOCKED/FORBIDDEN могут завершить попытку событием без Lua-исключения.
    if not ok then
        if pending == run then Finish("call-error", failure) end
        return false
    end
    if pending ~= run then return run.status == "response" or run.status == "response-unmatched" end
    C_Timer.After(30, function()
        if pending == run then
            uncertain, timedOut = true, true
            Finish("timeout", "No response within 30 seconds; this is not an empty result")
        end
    end)
    return true
end

function NS.SelectLanguage(mode)
    local _, canonical, err, key = NS.LanguageFilter(mode)
    -- Пустой набор сохраняем после снятия последней галочки, но поиск с ним запрещён.
    if mode == "" then canonical = "" end
    if canonical == nil then NS.SetStatus(key, err, "validation"); return false end
    if canonical == NS.Mode() then return true end
    local previous = NS.Mode()
    NS.Database().settings.language = canonical
    NS.Log("Language", (previous ~= "" and previous or "(none)") .. " -> " .. (canonical ~= "" and canonical or "(none)") .. "; saved; search not sent")
    NS.SetStatus(canonical == "" and "SELECT_SEARCH_LANGUAGES" or "REFRESH_LANGUAGE")
    return true
end

local function RecordBlocked(event, owner, functionName)
    if owner ~= addonName and not issuing then return end
    NS.blockedActionEpoch = (NS.blockedActionEpoch or 0) + 1
    local detail = event .. ": " .. tostring(owner) .. " / " .. tostring(functionName)
    local operation = type(functionName) == "string" and functionName:gsub("%(%)$", "") or nil
    -- Снятие объявления/приглашение не являются отказом текущего поиска.
    -- Epoch нужен действиям строк даже тогда, когда поиск продолжает ожидание.
    if operation ~= "C_LFGList.Search" and operation ~= "Search" then
        NS.Log("Error", detail .. "; search state unchanged", true)
        return
    end
    -- Реальный запрет Search возвращает целиком штатное окно, без боковой панели.
    if NS.DisableBrowseLayout then NS.DisableBrowseLayout("search operation blocked")
    elseif NS.DisableCustomRefresh then NS.DisableCustomRefresh("search operation blocked") end
    if pending then Finish("blocked", detail)
    else NS.SetStatus("OPERATION_BLOCKED", detail, "error") end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
frame:RegisterEvent("LFG_LIST_SEARCH_FAILED")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == addonName then
            NS.InitializeLog()
            NS.Log("Session", Describe(Context()) .. "; selected language=" .. NS.Mode())
            if C_LFGList and type(C_LFGList.Search) == "function" then EnsureHook() end
        end
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        RecordBlocked(event, ...)
    elseif event == "LFG_LIST_SEARCH_FAILED" or event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
        timedOut = nil
        local external = externalPending
        externalPending = nil
        externalID = externalID + 1
        if not pending then
            confirmedKey = nil
            local run = external or { mode = "unsolicited response" }
            run.elapsed = run.started and GetTime() - run.started or nil
            NS.resultCounts = nil
            if event == "LFG_LIST_SEARCH_FAILED" then
                run.status, run.reason = "failed", tostring((...) or "reason not provided")
                NS.SetStatus("NATIVE_FAILED", Summary(run), "error")
            else
                local ok, raw, filtered = pcall(function()
                    return CountResults(C_LFGList.GetSearchResults()), CountResults(C_LFGList.GetFilteredSearchResults())
                end)
                if ok then
                    run.status = (uncertain or not external) and "response-unmatched" or "response"
                    run.raw, run.filtered = raw, filtered
                    NS.resultCounts = filtered
                    NS.SetStatus("NATIVE_COMPLETE", Summary(run) .. "; use Refresh to search using the selected language")
                    ObserveView(run)
                else
                    run.status, run.reason = "read-error", tostring(raw)
                    NS.SetStatus("READ_RESULTS_FAILED", Summary(run), "error")
                end
            end
            return
        end
        if event == "LFG_LIST_SEARCH_FAILED" then Finish("failed", (...) or "reason not provided"); return end
        local ok, raw, filtered = pcall(function()
            return CountResults(C_LFGList.GetSearchResults()), CountResults(C_LFGList.GetFilteredSearchResults())
        end)
        if ok then
            pending.raw, pending.filtered = raw, filtered
            Finish(pending.attributionUncertain and "response-unmatched" or "response")
        else Finish("read-error", raw) end
    end
end)
