-- ForeverLFG
-- Copyright (c) 2026 Forever. All rights reserved.
-- Custom license: see LICENSE for permissions and earlier MIT releases.
-- Permission requests: wow@werko.dev or https://werko.dev/addons/feedback/

local _, NS = ...
local F, P = NS.Filters, NS.Filters.Plain
local events = CreateFrame("Frame")
local browse, source, entries, shownNodes, applying, lastSummary, unsupported, layoutKey
local collapsed = {}

function F.EmptyReason()
    if not F.counts or not shownNodes or NS.IsPending() then return end
    local s = F.Settings()
    if s.mode == "off" then return end
    local primary = s.mode == "seek" and "groups" or "solo"
    local section = shownNodes[primary]
    if not section or section:IsCollapsed() or #section:GetNodes() > 0 then return end
    for kind, node in pairs(shownNodes) do
        if kind ~= primary and not node:IsCollapsed() and #node:GetNodes() > 0 then return end
    end
    return s.mode == "recruit" and s.classes and not next(s.classes) and "BROWSE_EMPTY_CLASSES" or "BROWSE_EMPTY"
end

local function RememberCollapse()
    if shownNodes then
        for kind, node in pairs(shownNodes) do collapsed[kind] = not not node:IsCollapsed() end
    end
    if F.resetCollapse then
        collapsed = { groups = F.Settings().mode == "recruit", solo = F.Settings().mode == "seek", unknown = false }
        F.resetCollapse = nil
    end
end

local function ReadProvider(provider)
    if type(provider.GetRootNode) ~= "function" then error("Unsupported browse data provider") end
    local rows, seen = {}, {}
    local function Visit(node)
        for _, child in ipairs(node:GetNodes()) do
            local data = P(child.data, "table")
            if P(data.resultID) then
                local id = P(data.resultID, "number")
                if not seen[id] then
                    local index = P(data.index)
                    if index ~= nil then P(index, "number") end
                    rows[#rows + 1] = { resultID = id, index = index }; seen[id] = true
                end
            elseif not P(data.dividerType) then error("Unsupported browse row") end
            Visit(child)
        end
    end
    Visit(provider:GetRootNode())
    return rows
end

-- Снимок представления только для журнала: чтение дерева не меняет фильтры/выделение.
-- expanded считает строки в раскрытых разделах, а не только видимую область прокрутки.
function F.BrowseSummary()
    local frame = LFGBrowseFrame
    if not frame or not frame:IsShown() then return "window=hidden" end
    local scroll = frame.ScrollBox
    if not scroll or type(scroll.GetDataProvider) ~= "function" then return "provider=unavailable" end
    local provider = scroll:GetDataProvider()
    local rows = provider and ReadProvider(provider) or {}
    local expanded = 0
    local function Visit(node, hidden)
        for _, child in ipairs(node:GetNodes()) do
            local data = P(child.data, "table")
            if not hidden and P(data.resultID) then expanded = expanded + 1 end
            local closed = type(child.IsCollapsed) == "function" and P(child:IsCollapsed())
            Visit(child, hidden or closed)
        end
    end
    if provider then Visit(provider:GetRootNode(), false) end
    local _, ids = C_LFGList.GetFilteredSearchResults()
    P(ids, "table")
    local api, tree = {}, {}
    for _, id in ipairs(ids) do api[P(id, "number")] = true end
    local counts = {groups = 0, solo = 0, self = 0, missing = 0}
    for _, row in ipairs(rows) do
        tree[row.resultID] = true
        local info = P(C_LFGList.GetSearchResultInfo(row.resultID))
        if not info then counts.missing = counts.missing + 1
        else
            P(info, "table")
            if P(info.hasSelf) then counts.self = counts.self + 1
            elseif P(info.numMembers, "number") > 1 then counts.groups = counts.groups + 1
            else counts.solo = counts.solo + 1 end
        end
    end
    local apiOnly, treeOnly = 0, 0
    for id in pairs(api) do if not tree[id] then apiOnly = apiOnly + 1 end end
    for id in pairs(tree) do if not api[id] then treeOnly = treeOnly + 1 end end
    local settings = type(ForeverLFGCharacterDB) == "table" and ForeverLFGCharacterDB
    return string.format("local mode=%s; API rows=%d; source rows=%s; tree rows=%d; expanded rows=%d; groups=%d; players=%d; self=%d; missing=%d; API-only=%d; tree-only=%d",
        tostring(settings and settings.mode or "unavailable"), #ids, entries and #entries or "unavailable", #rows, expanded,
        counts.groups, counts.solo, counts.self, counts.missing, apiOnly, treeOnly)
end

local function Apply()
    RememberCollapse()
    F.context = F.Context()
    F.counts = nil
    if unsupported then F.context.reason, F.context.bypass = "FILTER_DATA_UNAVAILABLE", true end
    if not entries or not source or not browse:IsShown() then return end
    if InCombatLockdown() then F.context.reason = "FILTER_COMBAT"; return end
    local enhanced = NS.BrowseLayoutActive and NS.BrowseLayoutActive()
    if (F.Settings().mode == "off" and not enhanced) or (NS.BrowseLayoutFailed and NS.BrowseLayoutFailed()) then
        if browse.ScrollBox:GetDataProvider() ~= source then
            if browse.selectionBehavior then browse.selectionBehavior:ClearSelections() end
            browse.ScrollBox:SetDataProvider(source, ScrollBoxConstants.RetainScrollPosition)
        end
        shownNodes, layoutKey = nil, nil
        return
    end
    local groups, solo, own, unknown, unknownData, unknownGroups = {}, {}, {}, {}, {}, {}
    local counts = { groups = 0, solo = 0, totalGroups = 0, totalSolo = 0, unknown = 0, missing = 0, source = #entries }
    for _, row in ipairs(entries) do
        local info = P(C_LFGList.GetSearchResultInfo(row.resultID))
        if info then
            P(info, "table")
            local isGroup = P(info.numMembers, "number") > 1
            if not P(info.hasSelf) and not P(info.isDelisted) then
                if isGroup then counts.totalGroups = counts.totalGroups + 1 else counts.totalSolo = counts.totalSolo + 1 end
            end
            local keep, unsure, unknownKind = F.Match(row.resultID, info, F.context)
            if keep then
                local target
                if P(info.hasSelf) then target = own
                elseif isGroup then
                    target = unsure and unknownGroups or groups
                    if not unsure then counts.groups = counts.groups + 1 end
                else
                    target = unsure and (unknownKind == "data" and unknownData or unknown) or solo
                    if not unsure then counts.solo = counts.solo + 1 end
                end
                if unsure then counts.unknown = counts.unknown + 1 end
                target[#target + 1] = row
            end
        else counts.missing = counts.missing + 1 end
    end
    F.SortRows(groups, "groups"); F.SortRows(unknownGroups, "groups")
    F.SortRows(solo, "players"); F.SortRows(unknown, "players"); F.SortRows(unknownData, "players")
    local parts = {tostring(enhanced), counts.totalGroups, counts.totalSolo}
    for _, rows in ipairs({own, groups, unknownGroups, solo, unknown, unknownData}) do
        parts[#parts + 1] = "/"
        for _, row in ipairs(rows) do parts[#parts + 1] = row.resultID .. ":" .. tostring(row.index) end
    end
    parts[#parts + 1] = tostring(collapsed.groups) .. ":" .. tostring(collapsed.solo) .. ":" .. tostring(collapsed.unknown)
    local key = table.concat(parts, ",")
    local provider, nodes = CreateTreeDataProvider(), {}
    for _, row in ipairs(own) do provider:Insert({resultID = row.resultID, index = row.index}) end
    local function Section(kind, rows, divider, title, total)
        if #rows == 0 and not (enhanced and (kind == "groups" or kind == "solo")) then return end
        local node = provider:Insert({dividerType = divider, foreverLFGUnknownRoles = kind == "unknown",
            foreverLFGTitle = enhanced and title or nil, foreverLFGShown = #rows, foreverLFGTotal = total or #rows})
        nodes[kind] = node
        for _, row in ipairs(rows) do node:Insert({resultID = row.resultID, index = row.index, category = divider}) end
        node:SetCollapsed(collapsed[kind] == true, false, true)
    end
    Section("groups", groups, LFGVanillaBrowseDividerType.CategoryGroup, "BROWSE_GROUPS", counts.totalGroups)
    Section("unknownGroups", unknownGroups, LFGVanillaBrowseDividerType.CategoryGroup, "BROWSE_DATA_UNKNOWN")
    Section("solo", solo, LFGVanillaBrowseDividerType.CategorySolo, "BROWSE_PLAYERS", counts.totalSolo)
    Section("unknown", unknown, LFGVanillaBrowseDividerType.CategorySolo, "FILTER_UNKNOWN_HEADER")
    Section("unknownData", unknownData, LFGVanillaBrowseDividerType.CategorySolo, "BROWSE_DATA_UNKNOWN")
    -- Только представление списка. results/totalResults и флаги поиска Blizzard не меняются.
    -- Событие без изменения состава списка не сбрасывает выбранного кандидата.
    if key ~= layoutKey then
        if browse.selectionBehavior then browse.selectionBehavior:ClearSelections() end
        browse.ScrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
        shownNodes, layoutKey = nodes, key
    end
    F.counts = counts
    local summary = F.Settings().mode .. "; state=" .. tostring(F.context.reason)
        .. "; groups=" .. counts.groups .. "; players=" .. counts.solo
        .. "; unknown=" .. counts.unknown .. "; stale=" .. counts.missing
    local roster = F.context.roster
    if roster then summary = summary .. "; roster=" .. roster.TANK .. "/" .. roster.HEALER .. "/" .. roster.DAMAGER .. "; unassigned=" .. roster.unknown end
    if summary ~= lastSummary then NS.Log("Filter", summary); lastSummary = summary end
end

function F.Refresh()
    if applying then return end
    applying = true
    local ok, err = pcall(Apply)
    if not ok then
        F.context = { reason = "FILTER_DATA_UNAVAILABLE", settings = F.Settings(), roles = {}, bypass = true }
        F.counts = nil
        -- При отказе вернуть полную исходную выдачу, не оставлять прежний строгий отбор.
        if browse and source and not InCombatLockdown() and browse.ScrollBox:GetDataProvider() ~= source then
            pcall(function()
                if browse.selectionBehavior then browse.selectionBehavior:ClearSelections() end
                browse.ScrollBox:SetDataProvider(source, ScrollBoxConstants.RetainScrollPosition)
            end)
        end
        shownNodes, layoutKey = nil, nil
        if lastSummary ~= "unavailable" then NS.Log("Error", "Local filtering suspended: " .. tostring(err), true); lastSummary = "unavailable" end
    end
    applying = false
    if F.UpdateUI then F.UpdateUI() end
    if F.RefreshRows then F.RefreshRows() end
    if NS.UpdateUI then NS.UpdateUI() end
end

local function Install()
    if browse or InCombatLockdown() then return end
    local frame = LFGBrowseFrame
    if not frame or not frame.ScrollBox or type(frame.ScrollBox.SetDataProvider) ~= "function"
        or type(frame.ScrollBox.GetDataProvider) ~= "function" or type(frame.ScrollBox.RemoveDataProvider) ~= "function" or not CreateTreeDataProvider
        or not LFGVanillaBrowseDividerType or not ScrollBoxConstants then return end
    browse = frame
    F.resetCollapse = true
    local function Capture(_, provider)
        if applying then return end
        RememberCollapse()
        source, entries, shownNodes, unsupported, layoutKey = provider, nil, nil, nil, nil
        if provider then
            local ok, rows = pcall(ReadProvider, provider)
            if ok then entries = rows
            else
                unsupported = true
                F.context = {reason = "FILTER_DATA_UNAVAILABLE", bypass = true}; F.counts = nil
                NS.Log("Error", "Browse provider cannot be filtered: " .. tostring(rows), true)
                if F.UpdateUI then F.UpdateUI() end
                return
            end
        end
        F.Refresh()
    end
    hooksecurefunc(browse.ScrollBox, "SetDataProvider", Capture)
    hooksecurefunc(browse.ScrollBox, "RemoveDataProvider", function()
        if not applying then
            RememberCollapse(); source, entries, shownNodes, F.counts, unsupported, layoutKey = nil, nil, nil, nil, nil, nil
            if F.UpdateUI then F.UpdateUI() end
        end
    end)
    -- Штатный initializer заголовка не обновляет значки для заранее свёрнутого узла.
    if ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
        ScrollUtil.AddInitializedFrameCallback(browse.ScrollBox, function(_, row, node)
            if InCombatLockdown() or not node or not node.data.dividerType then return end
            if row.ExpandIcon and row.CollapseIcon then
                row.ExpandIcon:SetShown(node:IsCollapsed())
                row.CollapseIcon:SetShown(not node:IsCollapsed())
            end
            if node.data.foreverLFGTitle and row.CategoryLabel then
                local title, shown, total = NS.Text(node.data.foreverLFGTitle), node.data.foreverLFGShown, node.data.foreverLFGTotal
                row.CategoryLabel:SetText(shown == total and (title .. " - " .. shown) or NS.Text("BROWSE_COUNT", title, shown, total))
                row.CategoryLabel:Show()
            elseif node.data.foreverLFGUnknownRoles and row.CategoryLabel then
                row.CategoryLabel:SetText(NS.Text("FILTER_UNKNOWN_HEADER"))
                row.CategoryLabel:Show()
            end
            if row.HookScript and not row.foreverLFGCollapseHook then
                row.foreverLFGCollapseHook = true
                row:HookScript("OnClick", function() if F.UpdateUI then F.UpdateUI() end end)
            end
        end, events)
    end
    if browse.HookScript then browse:HookScript("OnShow", F.Refresh) end
    Capture(browse.ScrollBox, browse.ScrollBox:GetDataProvider())
end

for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE",
    "PLAYER_ROLES_ASSIGNED", "LFG_LIST_ROLE_UPDATE", "LFG_LIST_ACTIVE_ENTRY_UPDATE", "PARTY_LEADER_CHANGED",
    "LFG_LIST_SEARCH_RESULT_UPDATED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event)
    Install()
    if browse then F.Refresh() end
end)
