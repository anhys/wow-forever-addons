local myname, ns = ...

-- Working out which icon a point gets. Everything here hands back a table in
-- the shape HandyNotes wants -- an icon plus tex-coords, optionally r/g/b/a and
-- scale -- and those tables are shared between every point that asks for the
-- same one, so nothing may modify one after it has been handed out.

-- Because they're shared they're all built the first time something asks, so
-- each set of them below is a table you index rather than a function you call.
local function lazily(build)
    return setmetatable({}, {__index = function(self, key)
        self[key] = build(key)
        return self[key]
    end})
end

local atlas_texture = function(atlas, extra, left, right, top, bottom)
    local atlasInfo = C_Texture.GetAtlasInfo(atlas)
    if not atlasInfo then
        if ns.DEBUG then
            if not ns.DEBUG_missing_atlas_cache then ns.DEBUG_missing_atlas_cache = {} end
            if not ns.DEBUG_missing_atlas_cache[atlas] then
                print(("%s: missing atlas %s"):format(myname, atlas))
                ns.DEBUG_missing_atlas_cache[atlas] = true
            end
        end
        atlasInfo = C_Texture.GetAtlasInfo("QuestObjective") or C_Texture.GetAtlasInfo("VignetteLoot")
    end
    if type(extra) == "number" then
        extra = {scale=extra}
    end
    if left and not right then
        -- this is the "trim every side by this" path
        right = 1 - left
        top = left
        bottom = 1 - left
    end
    if left then
        -- An atlas is already cropped into a texture, so we need to treat something else as our 1
        local horizontal = atlasInfo.rightTexCoord - atlasInfo.leftTexCoord
        local vertical = atlasInfo.bottomTexCoord - atlasInfo.topTexCoord
        atlasInfo.rightTexCoord = atlasInfo.leftTexCoord + (right * horizontal)
        atlasInfo.leftTexCoord = atlasInfo.leftTexCoord + (left * horizontal)
        atlasInfo.bottomTexCoord = atlasInfo.topTexCoord + (bottom * vertical)
        atlasInfo.topTexCoord = atlasInfo.topTexCoord + (top * vertical)
    end
    return ns.merge({
        icon = atlasInfo.file,
        tCoordLeft = atlasInfo.leftTexCoord, tCoordRight = atlasInfo.rightTexCoord, tCoordTop = atlasInfo.topTexCoord, tCoordBottom = atlasInfo.bottomTexCoord,
    }, extra)
end
ns.atlas_texture = atlas_texture

local atlas_icons = lazily(atlas_texture)

-- An item or achievement's own icon, trimmed in to lose the border it's drawn
-- with.
local trimmed_icons = lazily(function(texture)
    return {
        icon = texture,
        tCoordLeft = 0.1,
        tCoordRight = 0.9,
        tCoordTop = 0.1,
        tCoordBottom = 0.9,
    }
end)

-- Whichever atlas the player picked for their default icon. The three offered
-- in the config each want their own scale; anything else gets a generic one.
--[[
note to self:
atlas_texture("delves-scenario-treasure-unavailable", nil, 0, 0.9, 0.1, 1)
atlas_texture("delves-scenario-treasure-available", nil, 0, 0.9, 0.05, 0.95)
--]]
local default_scales = {
    VignetteLoot = 1.1,
    VignetteLootElite = 1.2,
    Garr_TreasureIcon = 2.2,
}
local default_icons = lazily(function(atlas)
    return atlas_texture(atlas, default_scales[atlas] or 1.5)
end)

-- Icons that depend on nothing but what sort of point it is. They can't be
-- built up front because ns.CLASSIC isn't known until handler.lua has loaded.
local role_builders = {
    npc = function() return atlas_texture("DungeonSkull", 1) end,
    junk = function() return atlas_texture("VignetteLoot", 1) end,
    npc_notable = function()
        if ns.CLASSIC then return atlas_texture("DungeonSkull", {r=0.5, g=1, b=1, scale=1.1}) end
        return atlas_texture("nazjatar-nagaevent", {r=0.5, g=1, b=1}, 0.2)
    end,
    npc_lessnotable = function()
        if ns.CLASSIC then return atlas_texture("DungeonSkull", {r=1, g=0.3, b=1, scale=1.1}) end
        return atlas_texture("nazjatar-nagaevent", 1, 0.2)
    end,
}
local role_icons = lazily(function(role) return role_builders[role]() end)

local function work_out_texture(point)
    if point.texture then
        return point.texture
    end
    if point.atlas then
        return atlas_icons[point.atlas]
    end
    if point.icon then
        return trimmed_icons[point.icon]
    end
    -- Art belonging to the thing itself rather than a marker standing in for
    -- it. The achievement is what's left when neither is known. The label
    -- ladder deliberately runs the other way: an achievement names a point
    -- better than its loot does.
    if ns.db.icon_item then
        if point.loot and #point.loot > 0 then
            local texture = point.loot[1]:Icon()
            if texture then
                return trimmed_icons[texture]
            end
        end
        if point.achievement then
            local texture = select(10, GetAchievementInfo(point.achievement))
            if texture then
                return trimmed_icons[texture]
            end
        end
    end
    if point.npc then
        if ns.db.show_npcs_emphasizeNotable and ns.PointIsNotable(point, true) then
            if (not point.loot) or ns.hasNotableLoot(point.loot, true) then
                -- still notable without transmog
                return role_icons.npc_notable
            end
            if ns.db.notable_shared and point.loot_shared and ns.hasNotableLoot(point.loot_shared, true) then
                return role_icons.npc_notable
            end
            return role_icons.npc_lessnotable
        end
        return role_icons.npc
    end
    if point.junk then
        return role_icons.junk
    end
    return default_icons[ns.db.default_icon]
end
ns.work_out_texture = work_out_texture

-- A point you can't reach yet, or will be able to soon: the icon it would have
-- had, recoloured. Keyed on that icon, so they follow whatever it turned out
-- to be.
local inactive_icons = lazily(function(icon)
    local variant = CopyTable(icon)
    if variant.r then
        -- it's already coloured to mean something, so only fade it
        variant.a = 0.5
    else
        variant.r, variant.g, variant.b, variant.a = 0.5, 0.5, 0.5, 1
    end
    return variant
end)
local upcoming_icons = lazily(function(icon)
    local variant = CopyTable(icon)
    variant.r, variant.g, variant.b, variant.a = 1, 0, 0, 0.7
    return variant
end)
function ns.get_inactive_texture_variant(icon) return inactive_icons[icon] end
function ns.get_upcoming_texture_variant(icon) return upcoming_icons[icon] end
