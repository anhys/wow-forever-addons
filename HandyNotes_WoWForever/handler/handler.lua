local myname, ns = ...
local _, myfullname = C_AddOns.GetAddOnInfo(myname)

local HandyNotes = LibStub("AceAddon-3.0"):GetAddon("HandyNotes")
local HL = LibStub("AceAddon-3.0"):NewAddon(myname, "AceEvent-3.0")
-- local L = LibStub("AceLocale-3.0"):GetLocale(myname, true)
ns.HL = HL

local HBD = LibStub("HereBeDragons-2.0")

ns.DEBUG = C_AddOns.GetAddOnMetadata(myname, "Version") == '@'..'project-version@'

-- Forever has its own project ID, but the retail client's UI and APIs
ns.FOREVER = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
ns.CLASSIC = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE and not ns.FOREVER
ns.CLASSICERA = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC -- forever vanilla

---------------------------------------------------------
-- All the utility code

local mob_name = ns.mob_name
local render_string, cache_string = ns.render_string, ns.cache_string
local work_out_texture = ns.work_out_texture
local get_inactive_texture_variant = ns.get_inactive_texture_variant
local get_upcoming_texture_variant = ns.get_upcoming_texture_variant
local function cache_loot(loot)
    if not loot then return end
    for _, item in ipairs(loot) do
        item:Cache()
    end
end

local function work_out_label(point)
    local fallback
    if point.label then
        return (render_string(point.label, point))
    end
    if point.achievement and point.criteria and point.criteria ~= true then
        -- one criteria is the same as a list of one, and naming them is
        -- all-or-nothing: a partial list would read as a shorter point
        local ids = type(point.criteria) == "table" and point.criteria or {point.criteria}
        local named = {}
        for _, criteriaid in ipairs(ids) do
            local criteria = ns.GetCriteria(point.achievement, criteriaid)
            if criteria then
                table.insert(named, criteria)
            end
        end
        if #named == #ids then
            return string.join(', ', unpack(named))
        end
        fallback = 'achievement:'..point.achievement..'.'..string.join('+', unpack(ids))
    end
    if point.npc then
        local name = mob_name(point.npc)
        if name then
            return name
        end
        fallback = 'npc:'..point.npc
    end
    if point.loot and #point.loot > 0 then
        -- handle multiples?
        local name = point.loot[1]:Name(true)
        if name then
            return name
        end
        fallback = 'item:'..point.loot[1].id
    end
    if point.achievement and (not point.criteria or point.criteria == true) then
        local _, achievement = GetAchievementInfo(point.achievement)
        if achievement then
            return achievement
        end
        fallback = 'achievement:'..point.achievement
    end
    return fallback or UNKNOWN
end
ns.work_out_label = work_out_label
ns.point_active = function(point)
    if point.IsActive and not point:IsActive() then
        return false
    end
    if not point.active then
        return true
    end
    return ns.conditions.check(point.active)
end
ns.point_upcoming = function(point)
    if point.hide_before and not ns.conditions.check(point.hide_before) then
        return true
    end
    return false
end
local get_point_info = function(point, isMinimap)
    if point then
        local label = work_out_label(point)
        local icon = work_out_texture(point)
        if not ns.point_active(point) then
            icon = get_inactive_texture_variant(icon)
        elseif ns.point_upcoming(point) then
            icon = get_upcoming_texture_variant(icon)
        end
        if not isMinimap then
            cache_string(point.label, point)
            cache_string(point.note, point)
            cache_loot(point.loot)
            cache_loot(point.loot_shared)
        end
        return label, icon, point.scale, point.alpha or 1
    end
end
local get_point_info_by_coord = function(uiMapID, coord)
    return get_point_info(ns.points[uiMapID] and ns.points[uiMapID][coord])
end

do
    local currentPoint
    local function is_valid_related_point(basePoint, point)
        if not (basePoint and point) then return false end
        if basePoint.group and basePoint.group == point.group then return true end
        if basePoint.achievement and basePoint.achievement == point.achievement then return true end
        return false
    end
    local function iter(t, prestate)
        if not t then return nil end
        local state, point = next(t, prestate)
        while state do -- Have we reached the end of this zone?
            if is_valid_related_point(currentPoint, point) then
                return state, point
            end
            state, point = next(t, state) -- Get next data
        end
        return
    end
    function ns.IterateRelatedPointsInZone(uiMapID, point)
        currentPoint = point
        return iter, ns.points[uiMapID], nil
    end
    function ns.PointHasRelatedPointsInZone(uiMapID, point)
        for _, rpoint in ns.IterateRelatedPointsInZone(uiMapID, point) do
            if rpoint ~= point then
                return true
            end
        end
    end
end

---------------------------------------------------------
-- Plugin Handlers to HandyNotes
local HLHandler = {}

function HLHandler:OnEnter(uiMapID, coord)
    local point = ns.points[uiMapID] and ns.points[uiMapID][coord]
    if point and ns.MapSystem then
        ns.MapSystem:ProxyEvent("Enter", point, uiMapID, coord)
    end
    local tooltip = GameTooltip
    tooltip:ClearAllPoints()
    if ns.db.tooltip_pointanchor or self:GetParent() == Minimap then
        if self:GetCenter() > UIParent:GetCenter() then -- compare X coordinate
            tooltip:SetOwner(self, "ANCHOR_LEFT")
        else
            tooltip:SetOwner(self, "ANCHOR_RIGHT")
        end
    else
        tooltip:SetOwner(WorldMapFrame.ScrollContainer, "ANCHOR_NONE")
        local x, y = HandyNotes:getXY(coord)
        if y < 0.5 then
            tooltip:SetPoint("BOTTOMLEFT", WorldMapFrame.ScrollContainer)
        else
            tooltip:SetPoint("TOPLEFT", WorldMapFrame.ScrollContainer)
        end
    end
    ns.handle_tooltip_by_coord(tooltip, uiMapID, coord)
end

local function showAchievement(achievement)
    if ShowAchievementFrameForAchievement then
        ShowAchievementFrameForAchievement(achievement)
    elseif OpenAchievementFrameToAchievement then
        -- 12.1 renamed it; the old name stays while some regions are on 12.0
        OpenAchievementFrameToAchievement(achievement)
    else
        -- probably classic
        if ( not AchievementFrame ) then
            AchievementFrame_LoadUI()
        end
        if ( not AchievementFrame:IsShown() ) then
            AchievementFrame_ToggleAchievementFrame()
        end
        AchievementFrame_SelectAchievement(achievement)
    end
end

local function createWaypoint(uiMapID, coord)
    local x, y = HandyNotes:getXY(coord)
    if MapPinEnhanced and MapPinEnhanced.AddPin then
        MapPinEnhanced:AddPin{
            mapID = uiMapID,
            x = x,
            y = y,
            setTracked = true,
            title = get_point_info_by_coord(uiMapID, coord),
        }
    elseif TomTom then
        TomTom:AddWaypoint(uiMapID, x, y, {
            title = get_point_info_by_coord(uiMapID, coord),
            persistent = nil,
            minimap = true,
            world = true
        })
    elseif C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(uiMapID) then
        local uiMapPoint = UiMapPoint.CreateFromCoordinates(uiMapID, x, y)
        C_Map.SetUserWaypoint(uiMapPoint)
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
end
local createWaypointForAll
do
    local function getDistance(x1, y1, x2, y2)
        local deltaX, deltaY = x2 - x1, y2 - y1
        return ((deltaX ^ 2) + (deltaY ^ 2)) ^ 0.5
    end
    -- World coordinates, because the map being clicked needn't be the one the
    -- player is standing in
    local function sortByDistance(points, uiMapID)
        local px, py, pinstance = HBD:GetPlayerWorldPosition()
        if not px then return end
        local distances = {}
        for _, rcoord in ipairs(points) do
            local x, y = HandyNotes:getXY(rcoord)
            local wx, wy, instance = HBD:GetWorldCoordinatesFromZone(x, y, uiMapID)
            distances[rcoord] = (wx and instance == pinstance) and getDistance(px, py, wx, wy) or math.huge
        end
        table.sort(points, function(lhs, rhs) return distances[lhs] > distances[rhs] end)
    end
    function createWaypointForAll(uiMapID, coord)
        if not TomTom then return end
        local point = ns.points[uiMapID] and ns.points[uiMapID][coord]
        if not point then return end
        local points = {}
        for rcoord, rpoint in ns.IterateRelatedPointsInZone(uiMapID, point) do
            if ns.should_show_point(rcoord, rpoint, uiMapID, false) then
                table.insert(points, rcoord)
            end
        end
        -- Add waypoints in a useful order so we wind up with the closest one
        -- on the arrow. Not just doing TomTom:SetClosestWaypoint because I
        -- want to respect the crazy-arrow settings, and that forces it on.
        sortByDistance(points, uiMapID)
        for _, rcoord in ipairs(points) do
            local x, y = HandyNotes:getXY(rcoord)
            TomTom:AddWaypoint(uiMapID, x, y, {
                title = get_point_info_by_coord(uiMapID, rcoord),
                persistent = nil,
                minimap = true,
                world = true
            })
        end
    end
end

local function hideNode(uiMapID, coord)
    ns.hidden[uiMapID][coord] = true
    HL:Refresh()
end
local function hideAchievement(achievement)
    ns.db.achievementsHidden[achievement] = true
    HL:Refresh()
end
local function hideGroup(uiMapID, coord)
    local point = ns.points[uiMapID] and ns.points[uiMapID][coord]
    if not (point and point.group) then return end
    ns.db.groupsHidden[point.group] = true
    HL:Refresh()
end
local function hideGroupZone(uiMapID, coord)
    local point = ns.points[uiMapID] and ns.points[uiMapID][coord]
    if not (point and point.group) then return end
    ns.db.groupsHiddenByZone[uiMapID][point.group] = true
    HL:Refresh()
end

local function sendToChat(uiMapID, coord)
    local title = get_point_info_by_coord(uiMapID, coord)
    local x, y = HandyNotes:getXY(coord)
    local message = ("%s|cffffff00|Hworldmap:%d:%d:%d|h[%s]|h|r"):format(
        title and (title .. " ") or "",
        uiMapID,
        x * 10000,
        y * 10000,
        -- Can't do this:
        -- core:GetMobLabel(self.data.id) or UNKNOWN
        -- WoW seems to filter out anything which isn't the standard MAP_PIN_HYPERLINK
        MAP_PIN_HYPERLINK
    )
    PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_CHAT_SHARE)
    -- if you have an open editbox, just paste to it
    if not ChatEdit_InsertLink(message) then
        -- open the chat to whatever it was on and add the text
        ChatFrame_OpenChat(message)
    end
end

do
    local generateMenu = function(owner, rootDescription, uiMapID, coord, point)
        rootDescription:SetTag("MENU_WORLD_MAP_CONTEXT_"..myname)
        rootDescription:CreateTitle(myfullname)
        if point.achievement then
            rootDescription:CreateButton(OBJECTIVES_VIEW_ACHIEVEMENT, showAchievement, point.achievement)
        end
        if TomTom or (C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(uiMapID)) then
            rootDescription:CreateButton("Create waypoint", function() createWaypoint(uiMapID, coord) end)
        end
        -- Specifically for TomTom, since it supports multiples:
        if TomTom and ns.PointHasRelatedPointsInZone(uiMapID, point) then
            rootDescription:CreateButton(
                render_string(("Create waypoint for all %s"):format(point.group and (ns.groups[point.group] or point.group) or ("{achievement:%d}"):format(point.achievement)), point),
                function() createWaypointForAll(uiMapID, coord) end
            )
        end
        if _G.MAP_PIN_HYPERLINK then
            -- Link to chat
            rootDescription:CreateButton(COMMUNITIES_INVITE_MANAGER_LINK_TO_CHAT, function() sendToChat(uiMapID, coord) end)
        end
        -- Hide menu item
        if not ns.hiddenConfig.unhide then
            rootDescription:CreateButton("Hide this point", function() hideNode(uiMapID, coord) end)
        end
        if point.achievement then
            rootDescription:CreateButton(render_string("Hide {achievement:" .. point.achievement .. "}", point), hideAchievement, point.achievement)
        end
        if point.group then
            if not ns.hiddenConfig.groupsHiddenByZone then
                rootDescription:CreateButton(
                    render_string(("Hide %s only in {zone:%s}"):format(ns.groups[point.group] or point.group, uiMapID), point),
                    function() hideGroupZone(uiMapID, coord) end
                )
            end
            if not ns.hiddenConfig.groupsHidden then
                rootDescription:CreateButton(
                    render_string((ns.hiddenConfig.groupsHiddenByZone and "Hide all %s" or "Hide %s in all zones"):format(ns.groups[point.group] or point.group), point),
                    function() hideGroup(uiMapID, coord) end
                )
            end
        end
        -- Close menu item
        rootDescription:CreateButton(CLOSE, function() return MenuResponse.CloseAll end)
    end

    function HLHandler:OnClick(button, down, uiMapID, coord)
        if down then return end
        -- given we're in a click handler, this really *should* exist, but just in case...
        local point = ns.points[uiMapID] and ns.points[uiMapID][coord]
        if point then
            if button == "RightButton" then
                if point.OnRightClick then
                    if point:OnRightClick(button, uiMapID, coord) then
                        return
                    end
                end
                MenuUtil.CreateContextMenu(nil, generateMenu, uiMapID, coord, point)
                return
            end
            if button == "LeftButton" and IsShiftKeyDown() and _G.MAP_PIN_HYPERLINK then
                sendToChat(uiMapID, coord)
                return
            end
            if point.OnClick then
                point:OnClick(button, uiMapID, coord)
            end
            if ns.MapSystem then
                ns.MapSystem:ProxyEvent("Click", point, uiMapID, coord)
            end
        end
    end
end

function HLHandler:OnLeave(uiMapID, coord)
    GameTooltip:Hide()
    if _G[myname.."ComparisonTooltip"] then _G[myname.."ComparisonTooltip"]:Hide() end

    local point = ns.points[uiMapID] and ns.points[uiMapID][coord]
    if point and ns.MapSystem then
        ns.MapSystem:ProxyEvent("Leave", point, uiMapID, coord)
    end
end

do
    -- This is a custom iterator we use to iterate over every node in a given zone
    local currentZone, isMinimap
    local function iter(t, prestate)
        if not t then return nil end
        local state, value = next(t, prestate)
        while state do -- Have we reached the end of this zone?
            if value and ns.should_show_point(state, value, currentZone, isMinimap) then
                local _, icon, scale, alpha = get_point_info(value, isMinimap)
                scale = (scale or 1) * (icon and icon.scale or 1) * ns.db.icon_scale
                return state, nil, icon, scale, ns.db.icon_alpha * alpha
            end
            state, value = next(t, state) -- Get next data
        end
        return nil, nil, nil, nil
    end
    function HLHandler:GetNodes2(uiMapID, minimap)
        -- Debug("GetNodes2", uiMapID, minimap)
        for _, cache in pairs(ns.run_caches) do
            table.wipe(cache)
        end
        HL:RefreshProviders()
        currentZone = uiMapID
        isMinimap = minimap
        return iter, ns.points[uiMapID], nil
    end
end

---------------------------------------------------------
-- Addon initialization, enabling and disabling

function HL:OnInitialize()
    -- Set up our database
    if ns.defaultsOverride then
        ns.merge(ns.defaults.profile, ns.defaultsOverride)
    end
    self.db = LibStub("AceDB-3.0"):New(myname.."DB", ns.defaults)
    ns.db = self.db.profile
    ns.hidden = self.db.char.hidden
    -- Quick upgrade-cycle:
    if ns.db.show_npcs_onlynotable then
        ns.db.show_npcs_filter = "notable"
        ns.db.show_npcs_onlynotable = nil
    end

    -- Initialize our database with HandyNotes
    HandyNotes:RegisterPluginDB(myname:gsub("HandyNotes_", ""), HLHandler, ns.options)

    -- Watch for events... but mitigate spammy events by bucketing in Refresh
    self:RegisterEvent("LOOT_CLOSED", "RefreshOnEvent")
    self:RegisterEvent("ZONE_CHANGED_INDOORS", "RefreshOnEvent")
    self:RegisterEvent("CRITERIA_EARNED", "RefreshOnEvent")
    self:RegisterEvent("BAG_UPDATE", "RefreshOnEvent")
    self:RegisterEvent("QUEST_TURNED_IN", "RefreshOnEvent")
    if not ns.CLASSIC then
        self:RegisterEvent("SHOW_LOOT_TOAST", "RefreshOnEvent")
        self:RegisterEvent("GARRISON_FOLLOWER_ADDED", "RefreshOnEvent")
        self:RegisterEvent("UNIT_ENTERING_VEHICLE", "RefreshOnUnitEvent", "player")
        self:RegisterEvent("UNIT_EXITED_VEHICLE", "RefreshOnUnitEvent", "player")
        self:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", "RefreshIfUnrestricted")
    end
    -- This is sometimes spammy, but is the only thing that tends to get us casts:
    self:RegisterEvent("CRITERIA_UPDATE", "RefreshOnEvent")

    -- ns.areaPoi watches the POI and scheduler events itself. This covers what
    -- they don't: an event ending, or coming close enough to point out, which
    -- happen with nothing but the passage of time.
    ns.areaPoi.RegisterCallback(function()
        self:RefreshOnEvent()
    end)

    if ns.SetupMapOverlay then
        ns.SetupMapOverlay()
    end

    self:FillCaches()
end

do
    local bucket = CreateFrame("Frame")
    bucket.elapsed = 0
    bucket:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed > 1.5 then
            self.elapsed = 0
            self:Hide()
            HL:Refresh()
        end
    end)
    function HL:Refresh()
        HL:SendMessage("HandyNotes_NotifyUpdate", (myname:gsub("HandyNotes_", "")))
    end
    function HL:RefreshOnEvent(event)
        self:FillCaches()
        bucket:Show()
    end
    function HL:RefreshOnUnitEvent(requiredUnit, event, unit)
        if unit == requiredUnit then
            bucket:Show()
        end
    end
    function HL:RefreshIfUnrestricted(event, restrictionType, restrictionState)
        if restrictionState == Enum.AddOnRestrictionState.Activating then
            -- "a restriction is about to become active, but won't be enforced
            --  until event dispatch has completed" -- so getting valid data
            --  right away seems good.
            self:Refresh()
        elseif restrictionState == Enum.AddOnRestrictionState.Inactive then
            -- the restriction lifted, so what it hid is readable again
            bucket:Show()
        end
    end
    function HL:RefreshProviders()
        if ns.RouteMiniMapDataProvider then
            ns.RouteMiniMapDataProvider:UpdateMinimapRoutes()
        end
        if ns.MapSystem then
            ns.MapSystem:UpdateProviders()
        end
    end
end

function HL:FillCaches()
    if self.cachingStarted then return end
    if not (ns.points[C_Map.GetBestMapForUnit("player") or -1] or ns.points[WorldMapFrame and WorldMapFrame.mapID or -1]) then return end
    self.cachingStarted = true
    local CacheWalker = coroutine.wrap(function()
        local count = 0
        for uiMapID, coords in pairs(ns.points) do
            for coord, point in pairs(coords) do
                if point.loot then
                    for _, item in pairs(point.loot) do
                        item:Cache()
                    end
                    count = count + 1
                    -- only the caching is worth spreading out; this test used to
                    -- sit outside the check above, where a point with no loot
                    -- could spend an interval too
                    if count % 10 == 0 then
                        coroutine.yield(count, false)
                    end
                end
            end
        end
        coroutine.yield(count, true)
    end)
    if ns.DEBUG then print(("%s: starting caching"):format(myname)) end
    local ticker
    ticker = C_Timer.NewTicker(0.1, function()
        local count, finished = CacheWalker()
        if finished then
            ticker:Cancel()
            if ns.DEBUG then print(("%s: done caching %d points"):format(myname, count)) end
        end
    end)
end
