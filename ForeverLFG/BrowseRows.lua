-- ForeverLFG -- Copyright (c) 2026 Forever. All rights reserved. See LICENSE.
local _, NS = ...
local F, P, T = NS.Filters, NS.Filters.Plain, NS.Text
local events = CreateFrame("Frame")
local installed, refreshing
local rows = setmetatable({}, {__mode = "k"})
local function Points(frame)
    local points = {}; for i = 1, frame:GetNumPoints() do points[i] = {frame:GetPoint(i)} end; return points
end
local function SetPoints(frame, points)
    frame:ClearAllPoints(); for _, point in ipairs(points) do frame:SetPoint(unpack(point)) end
end

-- Возвращённое действие никогда не хранится в строке: при нажатии читаем текущий
-- resultID и заново проверяем адресата/состояние. Нижнее выделение не используется.
function F.RowAction(id, execute)
    local ok, label, reason, action = pcall(function()
        if InCombatLockdown() then return nil, "BROWSE_ACTION_COMBAT" end
        if NS.IsPending() then return nil, "WAIT_CURRENT" end
        local info = P(C_LFGList.GetSearchResultInfo(P(id, "number")))
        if not info or P(info.isDelisted) or P(info.hasSelf) then return nil, "BROWSE_STALE" end
        local members = P(info.numMembers, "number")
        if members < 1 then return nil, "BROWSE_STALE" end
        local solo = members == 1
        local title = solo and "BROWSE_INVITE" or "BROWSE_WRITE"
        local name = P(info.leaderName)
        if type(name) ~= "string" or name == "" then return title, "BROWSE_STALE" end
        if not solo then
            if not ChatFrameUtil or type(ChatFrameUtil.SendTell) ~= "function" then return title, "BROWSE_ACTION_UNAVAILABLE" end
            return title, nil, function() ChatFrameUtil.SendTell(name) end
        end
        if type(LFGBrowseUtil_GetInviteActionForResult) ~= "function" then return title, "BROWSE_ACTION_UNAVAILABLE" end
        local _, invite = LFGBrowseUtil_GetInviteActionForResult(id)
        if not invite then return title, "BROWSE_NO_RIGHTS" end
        return title, nil, invite
    end)
    if not ok then return nil, "BROWSE_ACTION_UNAVAILABLE" end
    if execute and action then
        local before = NS.blockedActionEpoch
        local done = pcall(action)
        if not done or before ~= NS.blockedActionEpoch then return label, "BROWSE_ACTION_UNAVAILABLE" end
    end
    return label, reason, action ~= nil
end

local function Restore(row, state)
    state.Button:Hide()
    state.Zone:Hide()
    if state.Count then state.Count:Hide() end
    if not NS.CanChangeFrame(row) then return end
    if row.DataDisplay then
        SetPoints(row.DataDisplay, state.dataPoints); row.DataDisplay:SetWidth(state.dataWidth)
        if state.rolesText and state.rolesLabel then state.rolesText:SetText(state.rolesLabel) end
    end
    for icon, points in pairs(state.rolePoints) do SetPoints(icon, points) end
    row.NameMaxWidth = state.nameWidth
    if row.Name then
        local limit = state.nameWidth or 228
        if row.DiscordIcon and row.DiscordIcon:IsShown() then limit = limit - row.DiscordIcon:GetWidth() - 4 end
        row.Name:SetWidth(0); if row.Name:GetWidth() > limit then row.Name:SetWidth(limit) end
    end
    if row.ActivityName and state.baseActivity then
        SetPoints(row.ActivityName, state.activityPoints)
        row.ActivityName:SetText(state.baseActivity); row.ActivityName:SetWidth(state.activityWidth)
    end
    if state.activityWrap ~= nil then row.ActivityName:SetWordWrap(state.activityWrap) end
    if row.PlaystyleLabel and state.stylePoints then
        SetPoints(row.PlaystyleLabel, state.stylePoints); row.PlaystyleLabel:SetWidth(state.styleWidth)
    end
end
local function Create(row)
    if not row.DataDisplay or not row.ActivityName or not row.Name or not NS.CanChangeFrame(row) then return end
    local state = {dataPoints = Points(row.DataDisplay), dataWidth = row.DataDisplay:GetWidth(),
        nameWidth = row.NameMaxWidth, activityWidth = 0, activityPoints = Points(row.ActivityName), rolePoints = {}}
    if row.PlaystyleLabel then state.stylePoints, state.styleWidth = Points(row.PlaystyleLabel), 0 end
    if row.ActivityName.CanWordWrap then state.activityWrap = P(row.ActivityName:CanWordWrap()) end
    if row.DataDisplay.Solo and row.DataDisplay.Solo.RolesText then
        state.rolesText = row.DataDisplay.Solo.RolesText; state.rolesLabel = state.rolesText:GetText()
    end
    for _, icon in ipairs(row.DataDisplay.Solo and row.DataDisplay.Solo.Roles or {}) do state.rolePoints[icon] = Points(icon) end
    local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    state.Button = button; row.ForeverLFGAction = button
    state.Count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    state.Count:SetPoint("RIGHT", row.DataDisplay, "RIGHT", -4, 0)
    state.Zone = row:CreateFontString(nil, "OVERLAY", "GameFontDisableLeft")
    row.ForeverLFGLocation = state.Zone
    state.Zone:SetHeight(14); state.Zone:SetWordWrap(false); state.Zone:SetJustifyH("LEFT"); state.Zone:Hide()
    button:SetSize(86, 24); button:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -9)
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnClick", function()
        if not NS.BrowseLayoutActive() then return end
        local _, reason = F.RowAction(row.resultID, true)
        if reason then NS.BrowseHelp(button, T(reason)) end
    end)
    button:SetScript("OnEnter", function()
        local label, reason = F.RowAction(row.resultID)
        local ok, name = pcall(function()
            local info = P(C_LFGList.GetSearchResultInfo(row.resultID))
            return info and P(info.leaderName, "string")
        end)
        NS.BrowseHelp(button, T(label or "BROWSE_ACTION_UNAVAILABLE"), ok and name or nil)
        if reason then GameTooltip:AddLine(T(reason), 1, .6, .4, true) end
        if state.zoneText then GameTooltip:AddLine(state.zoneText, .8, .8, .8, true) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[row] = state
    return state
end
local function Decorate(row, nativeUpdated)
    local state = rows[row]
    if not NS.BrowseLayoutActive() then if state then Restore(row, state) end; return end
    if not NS.CanChangeFrame(row) or not row.resultID then
        if state then
            if state.id == row.resultID and row.resultID then state.Button:SetEnabled(false) else state.Button:Hide() end
        end
        return
    end
    local info = P(C_LFGList.GetSearchResultInfo(P(row.resultID, "number")))
    if not info then if state then state.Button:Hide(); state.Count:Hide(); state.Zone:Hide() end; return end
    state = state or Create(row)
    if not state then return end
    local activityText = row.ActivityName:GetText()
    if nativeUpdated or state.id ~= row.resultID or not state.baseActivity or activityText ~= state.lastRendered then state.baseActivity = activityText end
    state.id = row.resultID
    local solo, own = P(info.numMembers, "number") <= 1, P(info.hasSelf)
    if own then Restore(row, state); return end
    state.Count:Hide()
    if not solo then
        local ids = P(info.activityIDs or {}, "table")
        local maximum = #ids > 0 and 5 or nil
        for _, activityID in ipairs(ids) do
            local activity = P(C_LFGList.GetActivityInfoTable(P(activityID, "number")))
            if not activity or P(activity.useDungeonRoleExpectations) ~= true or P(activity.maxNumPlayers) ~= 5 then maximum = nil; break end
        end
        if maximum then state.Count:SetText(P(info.numMembers, "number") .. "/" .. maximum); state.Count:Show() end
    end
    local roleCount = 0
    local soloRoles = row.DataDisplay.Solo and row.DataDisplay.Solo.Roles or {}
    if row.DataDisplay.Solo and row.DataDisplay.Solo:IsShown() then
        for _, icon in ipairs(soloRoles) do if icon:IsShown() then roleCount = roleCount + 1 end end
    end
    local index = 0
    for _, icon in ipairs(soloRoles) do
        if roleCount > 0 and icon:IsShown() then
            index = index + 1
            icon:ClearAllPoints(); icon:SetPoint("RIGHT", row.DataDisplay.Solo, "RIGHT", -(roleCount-index)*25, 0)
        end
    end
    local displayWidth = state.dataWidth
    if solo and not (row.DataDisplay.Comment and row.DataDisplay.Comment:IsShown()) then displayWidth = math.max(1,roleCount*25)
    elseif row.DataDisplay.Enumerate and row.DataDisplay.Enumerate:IsShown() then displayWidth = math.min(state.dataWidth,176) end
    row.DataDisplay:ClearAllPoints(); row.DataDisplay:SetPoint("TOPRIGHT", row, "TOPRIGHT", -104, -5)
    row.DataDisplay:SetWidth(displayWidth)
    if state.rolesText then state.rolesText:SetText(solo and "" or state.rolesLabel) end
    local nameWidth = math.max(75, row:GetWidth() - 104 - displayWidth - 34)
    local decorations = 0
    for _, key in ipairs({"Level", "ClassIcon", "DiscordIcon", "NewPlayerFriendlyIcon"}) do
        local item = row[key]
        if item and item:IsShown() then decorations = decorations + P(item:GetWidth(), "number") + 4 end
    end
    row.NameMaxWidth = math.min(state.nameWidth or 228, math.max(60, nameWidth - decorations))
    row.Name:SetWidth(0)
    if row.Name:GetWidth() > row.NameMaxWidth then row.Name:SetWidth(row.NameMaxWidth) end
    local textWidth = math.max(75,row:GetWidth()-44)
    row.ActivityName:ClearAllPoints(); row.ActivityName:SetPoint("TOPLEFT", row.Name, "BOTTOMLEFT", 0, -9)
    row.ActivityName:SetWidth(textWidth)
    if state.activityWrap ~= nil then row.ActivityName:SetWordWrap(false) end
    local ok, area = pcall(function()
        local member
        if solo then member = P(C_LFGList.GetSearchResultPlayerInfo(row.resultID, 1))
        elseif C_LFGList.GetSearchResultLeaderInfo then member = P(C_LFGList.GetSearchResultLeaderInfo(row.resultID)) end
        return member and P(member.areaName)
    end)
    if not ok then area = nil end
    if type(area) ~= "string" or area == "" then area = T("BROWSE_ZONE_UNKNOWN") end
    state.zoneText = T(solo and "BROWSE_ZONE" or "BROWSE_LEADER_ZONE", area)
    state.Zone:Hide()
    local footer = row.PlaystyleLabel and row:GetHeight() >= 68
    if footer then
        local style = row.PlaystyleLabel
        -- A pooled native label can retain the previous result's text when style is absent.
        if P(info.generalPlaystyle) == nil then style:SetText("") end
        local styleWidth = math.min(textWidth*.4,style:GetUnboundedStringWidth())
        if state.zoneText then
            style:ClearAllPoints(); style:SetPoint("TOPRIGHT", row.ActivityName, "BOTTOMRIGHT", 0, -3)
            style:SetWidth(styleWidth)
        else SetPoints(style,state.stylePoints); style:SetWidth(state.styleWidth) end
        state.Zone:ClearAllPoints(); state.Zone:SetPoint("TOPLEFT", row.ActivityName, "BOTTOMLEFT", 0, -3)
        state.Zone:SetWidth(math.max(40,textWidth-(styleWidth>0 and styleWidth+10 or 0)))
        if state.zoneText then state.Zone:SetText(state.zoneText); state.Zone:Show() end
    end
    state.lastRendered = (state.baseActivity or "") .. (not footer and state.zoneText and " - " .. state.zoneText or "")
    row.ActivityName:SetText(state.lastRendered)
    local label, reason = F.RowAction(row.resultID)
    state.Button:SetText(T(label or (solo and "BROWSE_INVITE" or "BROWSE_WRITE")))
    state.Button:SetShown(not P(info.isDelisted)); state.Button:SetEnabled(reason == nil and label ~= nil)
end
local function Update(row, nativeUpdated)
    if rows[row] and rows[row].released then return end
    local ok, err = pcall(Decorate, row, nativeUpdated)
    if not ok then
        local state = rows[row]
        if state then
            pcall(Restore, row, state)
            if not state.logged then NS.Log("Error", "Browse row decoration unavailable: " .. tostring(err), true); state.logged = true end
        end
    end
end
function F.RefreshRows()
    if refreshing then return end
    refreshing = true
    for row in pairs(rows) do Update(row, false) end
    refreshing = false
end
local function Install()
    if installed or InCombatLockdown() or not LFGBrowseFrame or not LFGBrowseFrame.ScrollBox or not ScrollUtil or not ScrollUtil.AddInitializedFrameCallback then return end
    local scroll = LFGBrowseFrame.ScrollBox
    ScrollUtil.AddInitializedFrameCallback(scroll, function(_, row, node)
        if node and node.data and node.data.resultID then
            if rows[row] then rows[row].released = nil end
            Update(row, false)
        end
    end, events)
    if ScrollUtil.AddReleasedFrameCallback then
        ScrollUtil.AddReleasedFrameCallback(scroll, function(_, row)
            local state = rows[row]
            if state then
                state.Button:Hide(); state.Count:Hide(); state.Zone:Hide(); state.released = true
                state.id, state.baseActivity, state.zoneText, state.lastRendered = nil, nil, nil, nil
            end
        end, events)
    end
    if type(LFGBrowseSearchEntry_Update) == "function" then hooksecurefunc("LFGBrowseSearchEntry_Update", function(row) Update(row, true) end) end
    if type(scroll.ForEachFrame) == "function" then scroll:ForEachFrame(function(row) if row.resultID then Update(row, true) end end) end
    installed = true
end
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "LFG_LIST_SEARCH_RESULT_UPDATED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function() Install(); F.RefreshRows() end)
