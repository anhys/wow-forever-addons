local myname, ns = ...

local HandyNotes = LibStub("AceAddon-3.0"):GetAddon("HandyNotes")

local function ApplyHandyNotesTextureSpec(texture, iconpath)
    -- This should be kept roughly in sync with HandyNotesWorldMapPinMixin:OnAcquired for my own ease of use...
    local scale, alpha = 1, 1
    if type(iconpath) == "table" then
        scale = iconpath.scale or 1
        alpha = iconpath.alpha or 1
    end

    local size = 18 * HandyNotes.db.profile.icon_scale * scale
    texture:SetSize(size, size)
    texture:SetAlpha(min(max(HandyNotes.db.profile.icon_alpha * alpha, 0), 1))

    if type(iconpath) == "table" then
        if iconpath.tCoordLeft then
            texture:SetTexCoord(iconpath.tCoordLeft, iconpath.tCoordRight, iconpath.tCoordTop, iconpath.tCoordBottom)
        else
            texture:SetTexCoord(0, 1, 0, 1)
        end
        if iconpath.r then
            texture:SetVertexColor(iconpath.r, iconpath.g, iconpath.b, iconpath.a)
        else
            texture:SetVertexColor(1, 1, 1, 1)
        end
        texture:SetTexture(iconpath.icon)
    else
        texture:SetTexCoord(0, 1, 0, 1)
        texture:SetVertexColor(1, 1, 1, 1)
        texture:SetTexture(iconpath)
    end
end

-- Advertising the event behind a point that names an areaPoi: green while it
-- runs, gold while it is close enough to set off for. Anything further out gets
-- nothing, so the map does not light up with things you cannot act on. A point
-- naming several takes the most interesting of them.
--
-- The atlas comes from the shortlist below, and is one Blizzard's own code still
-- uses: SetAtlas fails silently on a name that has gone, which would stop the
-- decoration without saying so.
local EVENT_GLOW_ATLAS = "groupfinder-eye-backglow"
local function event_glow_color(point)
    if not point.areaPoi then return end
    local status = ns.areaPoi.GetBestStatus(point.areaPoi, point._uiMapID)
    if not status then return end
    -- .active alone doesn't mean it's a tracked event; see ns.areaPoi's .timed
    if status.active then return status.timed and GREEN_FONT_COLOR or nil end
    if status.secondsUntil <= ns.areaPoi.Soon() then return NORMAL_FONT_COLOR end
end

local highlights = {}
local hovered

local pointcache = {}

local provider = {}
provider.data = {}

function provider:OnRefresh()
    table.wipe(self.data)

    if HandyNotes.db.profile.enabledPlugins[myname:gsub("HandyNotes_", "")] == false or not HandyNotes.db.profile.enabled then
        return
    end

    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return end
    if not ns.points[mapID] then return end

    for coord, point in pairs(ns.points[mapID]) do
        if ns.should_show_point(coord, point, mapID, false) then
            table.insert(self.data, coord)
        end
    end
end

function provider.OnPinCreated(pin)
    pin:SetScalingLimits(1, 1.0, 1.2)
    pin:SetMouseMotionEnabled(false)

    pin.glow = pin:CreateTexture(nil, "BACKGROUND")
    pin.glow:SetAllPoints()

    -- Separate from the glow above, which belongs to hovering: with one texture
    -- between them, mousing off a pin would clear what it was advertising.
    pin.eventGlow = pin:CreateTexture(nil, "BACKGROUND")
    pin.eventGlow:SetAllPoints()

    pin.backdrop = pin:CreateTexture(nil, "BACKGROUND")
    pin.backdrop:SetPoint("CENTER")

    pin.border = pin:CreateTexture(nil, "BORDER")
    pin.border:SetPoint("CENTER")

    pin.highlight = pin:CreateTexture(nil, "ARTWORK") -- HIGHLIGHT does enter/leave behavior...
    pin.highlight:SetAllPoints()
    pin.highlight:SetBlendMode("ADD")
    pin.highlight:SetAlpha(0.4)
end

local default_backdrop
function provider.OnPinAcquire(pin, coord)
    local mapID = WorldMapFrame:GetMapID()
    local point = ns.points[mapID] and ns.points[mapID][coord]
    if not point then return end
    pin.point = point

    if not InCombatLockdown() then
        pin:SetPropagateMouseMotion(true)
        pin:SetPropagateMouseClicks(true)
    end

    pin:Show()
    pin:SetID(coord)
    pin:SetSize(30, 30)

    -- This is below normal handynotes pins, which is kind of the whole point
    -- Handynotes is at PIN_FRAME_LEVEL_AREA_POI
    pin:SetFrameLevel(ns.MapSystem.GetWorldMapFrameLevelByType("PIN_FRAME_LEVEL_AREA_POI") - 1)

    -- Useful textures:
    -- worldquest-questmarker-abilityhighlight
    -- worldquest-questmarker-glow
    -- plunderstorm-glues-logo-backglow
    -- groupfinder-eye-backglow
    -- titleprestige-starglow
    -- services-ring-large-glowspin
    -- UI-QuestPoi-OuterGlow
    -- UI-QuestPoi-QuestNumber
    -- Waypoint-MapPin-Highlight
    -- common-roundhighlight
    if not default_backdrop then
        default_backdrop = ns.atlas_texture("worldquest-questmarker-epic")
    end
    local base = ns.work_out_texture(point)
    pin.base_texture = base
    if point.backdrop then
        -- TODO: let it color-modify
        ApplyHandyNotesTextureSpec(pin.backdrop, ns.xtype(point.backdrop) ~= "boolean" and point.backdrop or default_backdrop)
        -- self.backdrop:SetAtlas(ns.xtype(point.backdrop) == "string" and point.backdrop or "worldquest-questmarker-epic")
        pin.backdrop:Show()
    end
    if point.border then
        ApplyHandyNotesTextureSpec(pin.border, point.border)
        pin.border:Show()
    end
    pin.highlight:SetAtlas(ns.xtype(point.highlight) == "string" and point.highlight or "UI-QuestPoi-QuestNumber-SuperTracked")
    if highlights[point] or highlights[point._main] then
        pin.highlight:Show()
    end
    pin.glow:SetAtlas(point.glow or "plunderstorm-glues-logo-backglow")
    pin.glow:SetVertexColor(base.r or 1, base.g or 1, base.b or 1)
    if hovered and (point == hovered or point._main == hovered._main) then
        pin.glow:Show()
    end
    local eventColor = event_glow_color(point)
    if eventColor then
        pin.eventGlow:SetAtlas(EVENT_GLOW_ATLAS)
        pin.eventGlow:SetVertexColor(eventColor:GetRGB())
        pin.eventGlow:Show()
    end

    return mapID, HandyNotes:getXY(coord)
end

function provider.OnPinReset(pin)
    -- This will be called before onload has been called because framepools.
    -- The pin itself will have been hidden already by the base pool releaser.
    if pin.glow then
        pin.glow:Hide()
        pin.eventGlow:Hide()
        pin.backdrop:Hide()
        pin.border:Hide()
        pin.highlight:Hide()
    end
    pin.point = nil
end

provider.Proxy = {
    Enter = function(self, _, point, mapID, coord)
        local pin = self:GetPinByID(coord)
        if not pin then return end
        hovered = point
        pin.glow:Show()
    end,
    Leave = function(self, _, point, mapID, coord)
        local pin = self:GetPinByID(coord)
        if not pin then return end
        hovered = nil
        pin.glow:Hide()
    end,
    Click = function(self, _, point, mapID, coord)
        local pin = self:GetPinByID(coord)
        if not pin then return end
        local mapID = WorldMapFrame:GetMapID()
        local point = pin.point
        highlights[point._main] = not highlights[point._main]
        pin.highlight:SetShown(highlights[point._main])

        if point.route and ns.points[mapID] and ns.points[mapID][point.route] then
            highlights[ns.points[mapID][point.route]] = highlights[point._main]
            local routePin = pin.provider:GetPinByID(point.route)
            if routePin then
                routePin.highlight:SetShown(highlights[point._main])
            end
        end
    end,
}

ns.MapSystem:AddProvider(provider)
