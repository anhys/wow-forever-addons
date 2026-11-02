local myname, ns = ...
local _, myfullname = C_AddOns.GetAddOnInfo(myname)

local HandyNotes = LibStub("AceAddon-3.0"):GetAddon("HandyNotes")
local HBD = LibStub("HereBeDragons-2.0")

-- The point data model, and the registration calls the zone files make into it.
-- Nothing here draws anything or knows that HandyNotes exists: handler.lua is
-- what turns these into pins and tooltips.

-- flags for whether to show minimap icons in some zones, if Blizzard ever does the treasure-map thing again
ns.map_spellids = ns.map_spellids or {
    -- zone = spellid
}

-- for fallbacks
ns.covenants = ns.merge({
    [Enum.CovenantType.Kyrian] = "Kyrian",
    [Enum.CovenantType.Necrolord] = "Necrolords",
    [Enum.CovenantType.NightFae] = "NightFae",
    [Enum.CovenantType.Venthyr] = "Venthyr",
}, ns.covenants)

ns.groups = ns.merge(ns.groups or {}, {
    maplinks = QUEST_HUB_TOOLTIP_TRAVEL_HEADER or TUTORIAL_TITLE35 or "Travel",
    junk = BAG_FILTER_JUNK or "Junk",
})

ns.hiddenConfig = ns.hiddenConfig or {}

-- [uiMapID][coord] = point. What a point can hold is registerPoint below and
-- the keys ns.foldConditions folds; there was a list here, but it documented
-- keys that get deleted at registration and missed most of the ones in use.
ns.points = {}
ns.POIsToPoints = {}
ns.VignetteIDsToPoints = {}
ns.WorldQuestsToPoints = {}
local function intotable(dest, value_or_table, point)
    if not value_or_table then return end
    if type(value_or_table) == "table" then
        for _, value in ipairs(value_or_table) do
            dest[value] = point
        end
        return
    end
    dest[value_or_table] = point
end
-- The two things every point gets regardless of how it was registered: its
-- loot turned into reward objects, and an entry in each id lookup it names.
local function indexPoint(point)
    point.loot = ns.upgradeloot(point.loot)
    point.loot_shared = ns.upgradeloot(point.loot_shared)
    intotable(ns.POIsToPoints, point.areaPoi, point)
    intotable(ns.VignetteIDsToPoints, point.vignette, point)
    intotable(ns.WorldQuestsToPoints, point.worldquest, point)
end
-- What a path point looks like, whether it came from a path= key on another
-- point or from a zone file building one itself with ns.path.
local pathDefaults = {
    label = "Path to treasure",
    atlas = "poi-door", -- 'PortalPurple' / 'PortalRed'?
    minimap = true,
    scale = 0.9,
}
do
    -- path, nearby and related all hang an extra point off this one, and only
    -- really differ in what it looks like. The spec table carries the shared
    -- options in its hash part; anything it doesn't set falls through
    -- proxy_meta to the parent, so the defaults here are only for the keys
    -- where the parent's value would be the wrong answer.
    local inherited = {
        "label", "atlas", "color", "scale", "minimap", "worldmap",
        "active", "requires", "hide_before",
    }
    local function satellite(spec, proxy_meta, defaults)
        local made = {}
        for _, key in ipairs(inherited) do
            local value = spec[key]
            if value == nil then value = defaults[key] end
            made[key] = value
        end
        -- ...and these are the ones inheriting is always wrong for. The
        -- parent's note describes the treasure rather than the way to it, its
        -- texture belongs to its own atlas, and its satellites have been
        -- registered already -- picking them up again would recurse. Its routes
        -- are drawn once for it, and a satellite inheriting them would draw
        -- them again for every satellite.
        -- id lookups have to belong to whichever point actually names the id:
        -- these get indexed by ns.RegisterPoints, and a satellite inheriting one
        -- through the metatable would win the lookup over the point that owns it.
        made.vignette, made.areaPoi, made.worldquest = spec.vignette or false, spec.areaPoi or false, spec.worldquest or false
        made.note = spec.note or false
        made.texture = spec.texture or false
        made.path, made.nearby, made.related = spec.path or false, spec.nearby or false, spec.related or false
        made.routes = false
        made.loot = ns.upgradeloot(spec.loot)
        if made.atlas and made.color then
            made.texture = ns.atlas_texture(made.atlas, made.color)
        end
        return setmetatable(made, proxy_meta)
    end
    local function registerPoint(zone, coord, point)
        indexPoint(point)
        ns.foldConditions(zone, point)
        if ns.DEBUG and ns.points[zone][coord] then
            print(myname, "point collision", zone, coord)
        end
        ns.points[zone][coord] = point
        point._coord = coord
        point._uiMapID = zone
        point._main = point
        if point.atlas and point.color then
            point.texture = ns.atlas_texture(point.atlas, point.color)
        end
        local proxy_meta
        if point.path or point.nearby or point.related then
            proxy_meta = {__index=point}
        end
        if point.path then
            -- copy rather than prepending into the data table itself, which
            -- would accumulate coords if the same path is reused
            local route = type(point.path) == "table" and CopyTable(point.path, true) or {point.path}
            table.insert(route, 1, coord)
            local pathPoint = satellite(route, proxy_meta, setmetatable({
                label = point.npc and ("Path to {npc:%s}"):format(point.npc) or nil,
            }, {__index = pathDefaults}))
            pathPoint.routes = {route}
            pathPoint._coord, pathPoint._uiMapID = route[#route], zone
            -- deliberately not registerPoint: that would give it its own _main,
            -- where inheriting the parent's is what groups the two for highlighting
            ns.points[zone][route[#route]] = pathPoint
            -- highlight
            point.route = point.route or route[#route]
        end
        if point.nearby then
            local nearby = type(point.nearby) == "table" and point.nearby or {point.nearby}
            for _, ncoord in ipairs(nearby) do
                registerPoint(zone, ncoord, satellite(nearby, proxy_meta, {
                    label = point.npc and "Related to nearby NPC" or "Related to nearby treasure",
                    atlas = "playerpartyblip", scale = 0.9, minimap = true,
                }))
            end
        end
        if point.related then
            local shared = satellite(point.related, proxy_meta, {
                label = point.npc and "Related to nearby NPC" or "Related to nearby treasure",
                atlas = "playerpartyblip",
            })
            shared.route = coord
            local relatedNode = ns.nodeMaker(shared)
            for rcoord, related in pairs(point.related) do
                if type(rcoord) == "number" then -- defaults are mixed in on this table...
                    if not point.routes then point.routes = {} end
                    -- _related marks this as a generated cluster route, so the
                    -- provider can drop it when that related point is filtered out
                    table.insert(point.routes, {rcoord, coord, highlightOnly=true, _related=rcoord})
                    registerPoint(zone, rcoord, relatedNode(related))
                end
            end
        end
        -- and then variations on "also register this elsewhere":
        if point.translate or point.parent or point.levels then
            local translateTo = {}
            if point.translate then
                for tzone in pairs(point.translate) do
                    if tzone ~= zone then
                        translateTo[tzone] = true
                    end
                end
            end
            if point.parent then
                local mapinfo = C_Map.GetMapInfo(zone)
                if mapinfo and mapinfo.parentMapID and mapinfo.parentMapID ~= 0 then
                    local pzone = mapinfo.parentMapID
                    translateTo[pzone] = true
                end
            end
            if point.levels then
                -- Show on other levels of the same zone
                local groupID = C_Map.GetMapGroupID(zone)
                if groupID then
                    local members = C_Map.GetMapGroupMembersInfo(groupID)
                    if members then
                        for _, member in pairs(members) do
                            if member.mapID ~= zone then
                                translateTo[member.mapID] = true
                            end
                        end
                    end
                end
            end
            local x, y = HandyNotes:getXY(coord)
            for tzone in pairs(translateTo) do
                local tx, ty = HBD:TranslateZoneCoordinates(x, y, zone, tzone)
                if not tx then
                    -- try a fallback
                    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(zone, tzone)
                    if minX and minX ~= 0 then
                        tx = Lerp(minX, maxX, x)
                        ty = Lerp(minY, maxY, y)
                    end
                    if ns.DEBUG then
                        print(myname, "fell back", zone, coord, tzone, tx, ty)
                    end
                end
                if tx and ty then
                    if not ns.points[tzone] then
                        ns.points[tzone] = {}
                    end
                    local tcoord = HandyNotes:getCoord(tx, ty)
                    if ns.DEBUG and ns.points[tzone][tcoord] then
                        print(myname, "translate point collision", zone, coord, "to", tzone, tcoord)
                    end
                    ns.points[tzone][tcoord] = point
                elseif ns.DEBUG then
                    print(myname, "translation failed", x, y, zone, tzone)
                end
            end
        end
        if point.additional then
            -- Extra coordinates to register. This is equivalent to just
            -- registering the same table multiple times on the input, and
            -- should only be used for simple cases -- related points are
            -- going to fall apart here.
            for _,acoord in pairs(point.additional) do
                if ns.DEBUG and ns.points[zone][acoord] then
                    print(myname, "point collision", zone, acoord)
                end
                ns.points[zone][acoord] = point
            end
        end
    end
    function ns.RegisterPoints(zone, points, defaults)
        if not ns.points[zone] then
            ns.points[zone] = {}
        end
        if defaults then
            local nodeType = ns.nodeMaker(defaults)
            for coord, point in pairs(points) do
                points[coord] = nodeType(point)
            end
        end
        for coord, point in pairs(points) do
            registerPoint(zone, coord, point)
        end
    end
end
function ns.RegisterVignettes(zone, vignettes, defaults)
    if defaults then
        defaults = ns.nodeMaker(defaults)
    end
    for vignetteID, point in pairs(vignettes) do
        point = defaults and defaults(point) or point

        point._coord = point._coord or 0
        point._uiMapID = zone
        point.vignette = vignetteID
        point.always = true
        point.label = false

        indexPoint(point)
    end
end

ns.nodeMaker = function(defaults)
    local meta = {__index = defaults}
    return function(details)
        details = details or {}
        if details.note and defaults.note then
            details.note = details.note .. "\n" .. defaults.note
        end
        if rawget(details, "loot") and defaults.loot then
            tAppendAll(details.loot, defaults.loot)
        end
        local meta2 = getmetatable(details)
        if meta2 and meta2.__index then
            return setmetatable(details, {__index = ns.merge(CopyTable(defaults, true), meta2.__index)})
        end
        return setmetatable(details, meta)
    end
end

ns.path = ns.nodeMaker(pathDefaults)

-- This is essentially a version of MapLinkPinMixin; it should be
-- called like ns.mapLink{link=1234}
ns.mapLink = ns.nodeMaker{
    label = function(point) return ("{zone:%d}"):format(point.link) end,
    atlas = "CaveUnderground-Down", -- `-Up`
    scale = 2.5,
    OnTooltipShow = function(point, tooltip)
        GameTooltip_AddColoredLine(tooltip, MAP_LINK_POI_TOOLTIP_INSTRUCTION_LINE, GREEN_FONT_COLOR, true)
        tooltip:AddDoubleLine(" ", myfullname:gsub("HandyNotes: ", ""), 0, 1, 1, 0, 1, 1)
    end,
    OnRightClick = function(point, button, uiMapID, coord)
        if not point.link then return end
        -- escape the current click-hander because Blizzard data providers get in the way
        C_Timer.After(0, function()
            -- Classic *has* OpenWorldMap, but it's broken because it doesn't have this:
            if WorldMapFrame.HandleUserActionOpenSelf then
                OpenWorldMap(point.link)
            else
                -- Classic
                if not WorldMapFrame:IsVisible() then
                    ToggleWorldMap()
                end
                WorldMapFrame:SetMapID(point.link)
            end
        end)
        return true
    end,
    group="maplinks",
}
