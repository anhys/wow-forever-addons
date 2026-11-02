local myname, ns = ...

local HandyNotes = LibStub("AceAddon-3.0"):GetAddon("HandyNotes")

local provider = {}
provider.data = {}

local highlights = {}
local routecache = {}
local already = {}

-- Points in a cluster carry a route back to the main point they highlight as.
local function GetMainPoint(point, mapID)
    if point.route and ns.points[mapID][point.route] then
        point = ns.points[mapID][point.route]
    end
    if point._uiMapID ~= mapID then return end
    return point
end

-- A `related` cluster registers one route per related point, back to the main
-- one, each tagged with _related. Don't draw one whose related point is
-- currently filtered out. Routes without the tag -- paths, and any route
-- written by hand in the data -- are always drawn, since a hidden endpoint
-- there doesn't imply the route is unwanted.
local function routeShown(route, mapID)
    if not route._related then return true end
    local rpoint = ns.points[mapID][route._related]
    return not rpoint or ns.should_show_point(route._related, rpoint, mapID, false)
end

function provider:OnRefresh()
    table.wipe(self.data)

    if HandyNotes.db.profile.enabledPlugins[myname:gsub("HandyNotes_", "")] == false or not HandyNotes.db.profile.enabled then
        return
    end

    if not ns.db.show_routes then return end

    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return end
    if not ns.points[mapID] then return end

    -- A path on a related point holds its own routes, so the point holding them
    -- is not always the main one. Visibility is that point's own; only the
    -- highlighting belongs to the main point.
    for _, point in pairs(ns.points[mapID]) do
        if point.routes and not already[point] and ns.should_show_point(point._coord, point, mapID, false) then
            already[point] = true
            local main = GetMainPoint(point, mapID)
            if main then
                for _, route in ipairs(point.routes) do
                    if routeShown(route, mapID) then
                        if not routecache[route] then
                            routecache[route] = {
                                route = route,
                                point = main,
                                coord = point._coord,
                                mapID = mapID,
                            }
                        end
                        table.insert(self.data, routecache[route])
                    end
                end
            end
        end
    end
    table.wipe(already)
end

function provider.OnPinReset(pin)
    pin.line = nil
    pin.routedata = nil
end

function provider:ConnectPins(pin1, pin2, routedata)
    local route = routedata.route
    local line = ns.MapSystem:AttachLine(pin1, pin2)
    line.baseThickness = line:GetThickness()
    -- line:SetColorTexture(route.r or 1, route.g or 1, route.b or 1, route.a or 0.6)
    line:SetVertexColor(route.r or 1, route.g or 1, route.b or 1, route.a or 0.6)
    if route.highlightOnly and not highlights[routedata.point] then
        line:Hide()
    end
    return line
end

function provider:HandleData(routedata)
    local route = routedata.route
    local mapID = routedata.mapID
    local prevPin, firstPin
    for _, coord in ipairs(route) do
        local pin, isNew = self:AcquirePin()
        pin:SetID(coord)
        pin:SetSize(1, 1) -- needs a size or the route can't connect
        if pin:SetPosition(mapID, HandyNotes:getXY(coord)) then
            pin.routedata = routedata
            pin:Show()
            if prevPin then
                pin.line = self:ConnectPins(prevPin, pin, routedata)
            end
            prevPin = pin
            firstPin = firstPin or pin
        else
            -- match the generic pin path's release-on-failure
            self:ReleasePin(pin)
        end
    end
    if route.loop and firstPin and prevPin ~= firstPin then
        firstPin.line = self:ConnectPins(prevPin, firstPin, routedata)
    end
end

function provider:HighlightRoutes(point, state)
    for pin in self:EnumeratePins() do
        if pin.line and pin.routedata and pin.routedata.point == point then
            pin.line:SetThickness(pin.line.baseThickness * (state and 1.5 or 1))
            if pin.routedata.route.highlightOnly then
                pin.line:SetShown(state)
            end
        end
    end
end

provider.Proxy = {
    Enter = function(self, _, point, mapID, coord)
        point = GetMainPoint(point, mapID)
        if point then
            if highlights[point] then return end
            self:HighlightRoutes(point, true)
        end
    end,
    Leave = function(self, _, point, mapID, coord)
        point = GetMainPoint(point, mapID)
        if point then
            if highlights[point] then return end
            self:HighlightRoutes(point, false)
        end
    end,
    Click = function(self, _, point, mapID, coord)
        point = GetMainPoint(point, mapID)
        if point then
            highlights[point] = not highlights[point]
            self:HighlightRoutes(point, highlights[point])
        end
    end,
}

ns.MapSystem:AddProvider(provider)
