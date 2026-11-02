local myname, ns = ...

local HandyNotes = LibStub("AceAddon-3.0"):GetAddon("HandyNotes")

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

local function OnPinReleased(pinPool, pin)
    (_G.FramePool_HideAndClearAnchors or _G.Pool_HideAndClearAnchors)(pinPool, pin)
    if pin.OnReleased then
        -- pins only get the mixin when they're first acquired
        pin:OnReleased()
    end

    pin.provider = nil
end

local dataProvider = {
    facing = GetPlayerFacing(),
    pins = {},
    pinPool = CreateFramePool("FRAME", Minimap, nil, OnPinReleased),
}
ns.RouteMiniMapDataProvider = dataProvider

function dataProvider:RefreshAllData()
    -- if we're here really early for some reason
    if not ns.db then return end

    HBDPins:RemoveAllMinimapIcons(self)
    self:ReleaseAllPins()

    if HandyNotes.db.profile.enabledPlugins[myname:gsub("HandyNotes_", "")] == false or not HandyNotes.db.profile.enabled then
        return
    end

    if not ns.db.show_routes then return end

    -- if we either can't display anything meaningful, or are disabled
    if GetCVar('rotateMinimap') == '1' and self.facing == nil then return end

    local uiMapID = HBD:GetPlayerZone()
    if not uiMapID then return end
    if not ns.points[uiMapID] then return end

    -- Route coords belong to the map the point was registered on, so a point
    -- translated here from elsewhere can't draw them. And a point registered
    -- at several coords only wants its routes drawn once.
    local drawn = {}
    for coord, point in pairs(ns.points[uiMapID]) do
        if point.routes and point._uiMapID == uiMapID and not drawn[point] and ns.should_show_point(coord, point, uiMapID, true) then
            drawn[point] = true
            for _, route in ipairs(point.routes) do
                self:DrawRoute(route, point, uiMapID)
            end
        end
    end
end

function dataProvider:RefreshAllRotations()
    for pin in self.pinPool:EnumerateActive() do
        if pin.UpdateRotation then
            pin:UpdateRotation()
        end
    end
end

function dataProvider:AcquirePin(...)
    local pin, newPin = self.pinPool:Acquire()

    pin.provider = self

    if newPin then
        Mixin(pin, ns.MinimapRoutePinMixin)
        pin:OnLoad()
    end

    pin:Show()
    pin:OnAcquired(...)

    return pin
end

function dataProvider:ReleaseAllPins()
    self.pinPool:ReleaseAll()
end

local f = CreateFrame("Frame")
f:RegisterEvent("MINIMAP_UPDATE_ZOOM")
f:RegisterEvent("CVAR_UPDATE")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "MINIMAP_UPDATE_ZOOM" then
        dataProvider:UpdateMinimapRoutes()
    elseif event == "CVAR_UPDATE" then
        local varname = ...
        if varname == "ROTATE_MINIMAP" then
            dataProvider:UpdateMinimapRoutes()
        end
    end
end)
f:SetScript("OnUpdate", function(self)
    if GetCVar("rotateMinimap") == "1" then
        local facing = GetPlayerFacing()
        if facing ~= dataProvider.facing then
            dataProvider.facing = facing
            dataProvider:RefreshAllRotations()
        end
    end
end)

function dataProvider:DrawRoute(route, point, uiMapID)
    if route.highlightOnly then
        return
    end
    local related = point.related and point.related[route[1]] and ns.points[uiMapID][route[1]]
    if related and not ns.should_show_point(related._coord, related, related._uiMapID, false) then
        return
    end
    for i=1, #route - 1 do
        self:DrawSegment(route[i], route[i+1], uiMapID, point, route)
    end
    if route.loop and #route > 1 then
        self:DrawSegment(route[1], route[#route], uiMapID, point, route)
    end
end

-- Segments are cut to a length in screen pixels, so how many of them a leg needs
-- follows the minimap zoom. Each piece stays short enough that hiding the ones
-- whose midpoint leaves the minimap reads as the route being clipped to the
-- edge, and square enough that rotating its texture doesn't distort it.
local SEGMENT_LENGTH = 16

local function screenLength(worldDistance)
    return Minimap:GetWidth() * (worldDistance / dataProvider:GetMinimapViewDiameter())
end

local function onScreenLength(x1, y1, x2, y2, uiMapID)
    local wx1, wy1 = HBD:GetWorldCoordinatesFromZone(x1, y1, uiMapID)
    local wx2, wy2 = HBD:GetWorldCoordinatesFromZone(x2, y2, uiMapID)
    if not (wx1 and wx2) then return 0 end
    return screenLength(math.sqrt((wx2-wx1)^2 + (wy2-wy1)^2))
end

local segmented = {}
function dataProvider:DrawSegment(coord1, coord2, uiMapID, ...)
    wipe(segmented)
    local x1, y1 = HandyNotes:getXY(coord1)
    local x2, y2 = HandyNotes:getXY(coord2)

    local segments = max(ceil(onScreenLength(x1, y1, x2, y2, uiMapID) / SEGMENT_LENGTH), 1)

    for i=0, segments do
        segmented[#segmented + 1] = HandyNotes:getCoord(
            x1 + (x2-x1) / segments * i,
            y1 + (y2-y1) / segments * i
        )
    end
    for i=1, #segmented - 1 do
        self:AcquirePin(segmented[i], segmented[i + 1], uiMapID, ...)
    end
end

--

ns.MinimapRoutePinMixin = {}
function ns.MinimapRoutePinMixin:OnLoad()
    self:SetParent(Minimap)
    self:SetFrameStrata(Minimap:GetFrameStrata())
    self:SetFrameLevel(Minimap:GetFrameLevel() + 3)

    self:SetSize(12, 12)
    self.texture = self:CreateTexture(nil, "BACKGROUND")
    self.texture:SetAllPoints()
    self.texture:SetTexelSnappingBias(0)
    self.texture:SetSnapToPixelGrid(false)

    if ns.CLASSIC then
        self.texture:SetAtlas("_UI-Taxi-Line-horizontal")
    else
        self.texture:SetAtlas("_AnimaChannel-Channel-Line-horizontal")
    end

    self.minimap = true
end

function ns.MinimapRoutePinMixin:OnAcquired(coord1, coord2, uiMapID, point, route)
    -- print("OnAcquired", coord1, coord2, uiMapID)
    local x1, y1 = HandyNotes:getXY(coord1)
    local x2, y2 = HandyNotes:getXY(coord2)

    local wx1, wy1 = HBD:GetWorldCoordinatesFromZone(x1, y1, uiMapID)
    local wx2, wy2 = HBD:GetWorldCoordinatesFromZone(x2, y2, uiMapID)
    self.rotation = -math.atan2(wy2-wy1, wx2-wx1)

    self:SetSize(onScreenLength(x1, y1, x2, y2, uiMapID), SEGMENT_LENGTH)
    self.texture:SetRotation(self.rotation)

    self.texture:SetVertexColor(route.r or 1, route.g or 1, route.b or 1, route.a or 0.6)

    local x, y = (x1+x2)/2, (y1+y2)/2
    HBDPins:AddMinimapIconMap(dataProvider, self, uiMapID, x, y)

    if GetCVar('rotateMinimap') == '1' then self:UpdateRotation() end
end
function ns.MinimapRoutePinMixin:OnReleased()
    self.texture:SetRotation(0)
    self.texture:SetTexCoord(0, 1, 0, 1)
    self.texture:SetVertexColor(1, 1, 1, 1)
    self.rotation = nil
    self:SetAlpha(1)
    if self.SetScalingLimits then -- world map
        self:SetScalingLimits(nil, nil, nil)
    end
end
function ns.MinimapRoutePinMixin:UpdateRotation()
    if self.rotation == nil or self.provider.facing == nil then return end
    self.texture:SetRotation(self.rotation + math.pi*2 - self.provider.facing)
end

--

do
    local APIfallback = not (C_Minimap and C_Minimap.GetViewRadius)
    local indoors, zoom
    function dataProvider:UpdateMinimapRoutes()
        -- on PlayerZoneChanged
        if APIfallback then
            zoom = Minimap:GetZoom()
            indoors = GetCVar("minimapZoom")+0 == zoom and "outdoor" or "indoor"
        end
        dataProvider:RefreshAllData()
    end
    -- this table is from HereBeDragons:
    local minimap_size = {
        indoor = {
            [0] = 300, -- scale
            [1] = 240, -- 1.25
            [2] = 180, -- 5/3
            [3] = 120, -- 2.5
            [4] = 80,  -- 3.75
            [5] = 50,  -- 6
        },
        outdoor = {
            [0] = 466 + 2/3, -- scale
            [1] = 400,       -- 7/6
            [2] = 333 + 1/3, -- 1.4
            [3] = 266 + 2/6, -- 1.75
            [4] = 200,       -- 7/3
            [5] = 133 + 1/3, -- 3.5
        },
    }
    function dataProvider:GetMinimapViewDiameter()
        if APIfallback then
            return minimap_size[indoors][zoom]
        end
        return C_Minimap.GetViewRadius() * 2
    end
end
