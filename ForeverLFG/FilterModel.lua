-- ForeverLFG
-- Copyright (c) 2026 Forever. All rights reserved.
-- Custom license: see LICENSE for permissions and earlier MIT releases.
-- Permission requests: wow@werko.dev or https://werko.dev/addons/feedback/

local _, NS = ...
local F = { roles = { "TANK", "HEALER", "DAMAGER" }, targets = { TANK = 1, HEALER = 1, DAMAGER = 3 } }
NS.Filters = F

-- Доступность данных проверяется до сравнения/форматирования secret values.
function F.Plain(value, kind)
    if issecretvalue and issecretvalue(value) then error("Restricted group data") end
    if kind and type(value) ~= kind then error("Group data unavailable") end
    return value
end
local P = F.Plain
local function Call(fn, ...)
    if type(fn) ~= "function" then error("Group API unavailable") end
    return P(fn(...))
end

function F.Settings()
    if type(ForeverLFGCharacterDB) ~= "table" then ForeverLFGCharacterDB = {} end
    local s = ForeverLFGCharacterDB
    if s.mode ~= "seek" and s.mode ~= "recruit" and s.mode ~= "off" then s.mode = "off" end
    if type(s.auto) ~= "boolean" then s.auto = true end
    if type(s.seek) ~= "table" then s.seek = {} end
    if type(s.recruit) ~= "table" then s.recruit = {} end
    s.showLocation = nil -- Местоположение теперь показывается всегда.
    if s.orderGroups ~= "name" and s.orderGroups ~= "size" then s.orderGroups = "native" end
    if s.orderPlayers ~= "name" and s.orderPlayers ~= "level" then s.orderPlayers = "native" end
    if type(s.presets) ~= "table" then s.presets = {} end
    if type(s.activePreset) ~= "string" or type(s.presets[s.activePreset]) ~= "table" then s.activePreset = nil end
    if type(s.classes) ~= "table" then s.classes = nil end
    for _, key in ipairs({"levelMin", "levelMax"}) do
        local value = s[key]
        if type(value) ~= "number" or value < 1 or value > 9999 or value ~= math.floor(value) then s[key] = nil end
    end
    if s.levelMin and s.levelMax and s.levelMin > s.levelMax then s.levelMin, s.levelMax = nil, nil end
    if type(s.style) ~= "number" or s.style < 0 or s.style > 4 or s.style ~= math.floor(s.style) then s.style = nil end
    s.friendsFirst = s.friendsFirst == true
    return s
end

function F.DungeonContext()
    local browse = LFGBrowseFrame
    local ids = browse and browse.ActivityDropdown and browse.ActivityDropdown.selectedValues
    P(ids, "table")
    if #ids == 0 then
        local category = Call(browse.CategoryDropdown.GetValue, browse.CategoryDropdown)
        if type(category) ~= "number" or category <= 0 then return false end
        ids = P(Call(LFGUtil_GetFilteredActivities, category), "table")
    end
    if #ids == 0 then return false end
    for _, id in ipairs(ids) do
        local info = P(Call(C_LFGList.GetActivityInfoTable, P(id, "number")), "table")
        if P(info.useDungeonRoleExpectations) ~= true or P(info.maxNumPlayers, "number") ~= 5 then return false end
    end
    return true
end

function F.Roster()
    if IsInRaid and Call(IsInRaid, LE_PARTY_CATEGORY_HOME) then return nil, "FILTER_OTHER_ACTIVITY" end
    local n = P(Call(GetNumGroupMembers, LE_PARTY_CATEGORY_HOME), "number")
    if n > 5 then return nil, "FILTER_OTHER_ACTIVITY" end
    local counts = { TANK = 0, HEALER = 0, DAMAGER = 0, unknown = 0, size = math.max(1, n) }
    for i = 1, counts.size do
        local role = Call(UnitGroupRolesAssigned, i == 1 and "player" or "party" .. (i - 1))
        -- У одиночки назначенной party-роли может не быть. Несколько заявленных ролей
        -- нельзя считать несколькими занятыми местами: оставляем неизвестность.
        if n == 0 and not F.targets[role] then
            local selected = P(Call(C_LFGListRoles and C_LFGListRoles.GetRoles), "table")
            local only, total = nil, 0
            for key, token in pairs({ tank = "TANK", healer = "HEALER", dps = "DAMAGER" }) do
                if P(selected[key]) == true then only, total = token, total + 1 end
            end
            if total == 1 then role = only end
        end
        if F.targets[role] then counts[role] = counts[role] + 1 else counts.unknown = counts.unknown + 1 end
    end
    counts.missing = {}
    for _, role in ipairs(F.roles) do counts.missing[role] = math.max(0, F.targets[role] - counts[role]) end
    return counts
end

function F.Context()
    local s = F.Settings()
    local c = { settings = s, roles = s.mode == "recruit" and s.recruit or s.seek }
    if s.mode == "off" then c.reason = "FILTER_OFF"; return c end
    -- Контекст пятёрки нужен только для расчёта своего состава 1/1/3.
    -- Ручной поиск читает готовые *_REMAINING у каждой найденной группы.
    if s.mode == "recruit" and s.auto then
        local ok, dungeon = pcall(F.DungeonContext)
        if not ok then c.reason = "FILTER_DATA_UNAVAILABLE"; c.bypass = true; return c end
        if not dungeon then c.reason = "FILTER_OTHER_ACTIVITY"; c.bypass = true; return c end
    end
    if s.mode == "recruit" and s.auto then
        local ok, roster, reason = pcall(F.Roster)
        if not ok or not roster then
            c.reason, c.bypass = reason or "FILTER_DATA_UNAVAILABLE", true
        else
            c.roster = roster
            c.roles = {}
            if roster.size >= 5 then c.full, c.reason = true, "FILTER_FULL"
            elseif roster.unknown > 0 then c.reason, c.bypass = "FILTER_UNKNOWN_ROSTER", true
            else
                for _, role in ipairs(F.roles) do c.roles[role] = roster.missing[role] > 0 end
                c.reason = "FILTER_AUTO_ACTIVE"
            end
        end
    else c.reason = s.mode == "seek" and "FILTER_SEEK_HINT" or "FILTER_MANUAL_HINT" end
    return c
end

local function Selected(roles)
    for _, role in ipairs(F.roles) do if roles[role] == true then return true end end
    return false
end

-- nil/неизвестные роли не превращаются в «не подходит».
local function MatchRoles(id, info, c)
    if P(info.hasSelf) then return true end
    if P(info.isDelisted) then return false end
    local solo = P(info.numMembers, "number") <= 1
    if c.settings.mode == "off" or c.bypass then return true end
    if c.settings.mode == "seek" then
        if solo or not Selected(c.roles) then return true end
        local counts = P(Call(C_LFGList.GetSearchResultMemberCounts, id), "table")
        local unknown = false
        for _, role in ipairs(F.roles) do
            if c.roles[role] then
                local remaining = P(counts[role .. "_REMAINING"])
                if type(remaining) ~= "number" then unknown = true
                elseif remaining > 0 then return true end
            end
        end
        return unknown, unknown
    end
    if not solo then return true end -- Чужие группы сворачиваются, но доступны вручную.
    if c.full then return false end
    if not Selected(c.roles) then return true end
    local member = Call(C_LFGList.GetSearchResultPlayerInfo, id, 1)
    if not member then return true, true end
    local roles = P(P(member, "table").lfgRoles)
    if type(roles) ~= "table" then return true, true end
    local any = false
    for key, role in pairs({ tank = "TANK", healer = "HEALER", dps = "DAMAGER" }) do
        if P(roles[key]) == true then
            any = true
            if c.roles[role] then return true end
        end
    end
    return not any, not any
end

-- Дополнительные условия относятся только к полученной выдаче. Ни один setter
-- фильтра не меняет реальные роли персонажа и не запускает C_LFGList.Search.
function F.Match(id, info, c)
    if P(info.hasSelf) then return true end
    if P(info.isDelisted) then return false end
    local s, unsure = c.settings, false
    if s.mode == "off" then return true end
    if s.style ~= nil then
        local style = P(info.generalPlaystyle)
        if style == nil then unsure = true elseif style ~= s.style then return false end
    end
    if s.mode == "recruit" and P(info.numMembers, "number") <= 1 then
        if s.classes and not next(s.classes) then return false end
        if s.levelMin or s.levelMax or s.classes then
            local member = P(Call(C_LFGList.GetSearchResultPlayerInfo, id, 1))
            if not member then unsure = true else
                P(member, "table")
                if s.classes then
                    local class = P(member.classFilename)
                    if not class or class == "" then unsure = true
                    elseif not s.classes[class] then return false end
                end
                if s.levelMin or s.levelMax then
                    local level = P(member.level)
                    if type(level) ~= "number" then unsure = true
                    elseif (s.levelMin and level < s.levelMin) or (s.levelMax and level > s.levelMax) then return false end
                end
            end
        end
    end
    local keep, unknownRole = MatchRoles(id, info, c)
    if not keep then return false end
    return true, unknownRole or unsure, unsure and "data" or (unknownRole and "role" or nil)
end

function F.Changed()
    F.Settings().activePreset = nil
    if F.Refresh then F.Refresh() end
end

function F.SetLevels(low, high)
    local function Parse(value)
        if value == nil or value == "" then return nil, true end
        local n = tonumber(value)
        return n, n ~= nil and n == math.floor(n) and n >= 1 and n <= 9999
    end
    local lo, validLo = Parse(low)
    local hi, validHi = Parse(high)
    if not validLo or not validHi or (lo and hi and lo > hi) then return false end
    local s = F.Settings()
    if s.levelMin == lo and s.levelMax == hi then return true end
    s.levelMin, s.levelMax = lo, hi
    F.Changed(); return true
end

function F.Reset()
    local s = F.Settings()
    if F.ClearLevelDraft then F.ClearLevelDraft() end
    s.style = nil
    if s.mode == "recruit" then s.auto, s.recruit, s.levelMin, s.levelMax, s.classes = false, {}, nil, nil, nil
    elseif s.mode == "seek" then s.seek = {} end
    F.Changed()
end

function F.HasConditions()
    local s = F.Settings()
    if s.mode == "off" then return false end
    return s.style ~= nil or Selected(s.mode == "recruit" and s.recruit or s.seek)
        or (s.mode == "recruit" and (s.auto or s.levelMin ~= nil or s.levelMax ~= nil or s.classes ~= nil))
end

function F.ClassList()
    local result = {}
    for _, token in ipairs(CLASS_SORT_ORDER or {}) do
        result[#result + 1] = {token = token, name = (LOCALIZED_CLASS_NAMES_MALE or {})[token] or token}
    end
    return result
end

function F.SortRows(rows, kind)
    local s = F.Settings()
    local order = kind == "groups" and s.orderGroups or s.orderPlayers
    if order == "native" and not s.friendsFirst then return end
    local keys = {}
    for i, row in ipairs(rows) do
        local info = P(Call(C_LFGList.GetSearchResultInfo, row.resultID), "table")
        local level
        if kind ~= "groups" and order == "level" then
            local member = P(Call(C_LFGList.GetSearchResultPlayerInfo, row.resultID, 1))
            level = member and P(member.level)
        end
        keys[row] = {index = i, friend = (P(info.numBNetFriends) or 0) + (P(info.numCharFriends) or 0) + (P(info.numGuildMates) or 0) > 0,
            name = P(info.leaderName), value = kind == "groups" and P(info.numMembers) or level}
    end
    table.sort(rows, function(a, b)
        local x, y = keys[a], keys[b]
        if s.friendsFirst and x.friend ~= y.friend then return x.friend end
        if order == "name" and x.name ~= y.name then
            if type(x.name) ~= "string" then return false end
            if type(y.name) ~= "string" then return true end
            return x.name < y.name
        elseif (order == "size" or order == "level") and x.value ~= y.value then
            if type(x.value) ~= "number" then return false end
            if type(y.value) ~= "number" then return true end
            return x.value > y.value
        end
        return x.index < y.index
    end)
end

function F.SelectMode(mode)
    if mode ~= "seek" and mode ~= "recruit" and mode ~= "off" then return end
    if F.Settings().mode == mode then return end
    F.Settings().mode = mode
    F.Settings().activePreset = nil
    F.resetCollapse = true
    NS.Log("Filter", "Mode selected: " .. mode)
    if F.Refresh then F.Refresh() end
end

function F.SelectRole(role)
    if not F.targets[role] then return end
    local s = F.Settings()
    if s.mode == "recruit" and s.auto then s.auto = false; s.recruit = { [role] = true }
    else
        local selected = s.mode == "recruit" and s.recruit or s.seek
        selected[role] = not selected[role]
    end
    NS.Log("Filter", "Role selected: " .. role .. "; mode=" .. s.mode .. "; auto=" .. tostring(s.auto))
    F.Changed()
end
