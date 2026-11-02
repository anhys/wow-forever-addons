local myname, ns = ...

-- Whether a point belongs on the map at all. That is a different question from
-- whether it is worth your time -- the notability tests this leans on are in
-- notable.lua, shared with SilverDragon -- and a different one again from
-- whether a condition currently holds, which is conditions.lua.

-- The test primitives these are built on live in notable.lua, shared with
-- SilverDragon:
local allQuestsComplete, isAchieved = ns.allQuestsComplete, ns.isAchieved
local hasNotableLoot, hasKnowableLoot, allLootKnown = ns.hasNotableLoot, ns.hasKnowableLoot, ns.allLootKnown

local itemInBags = ns.testMaker(function(item) return C_Item.GetItemCount(item, true) > 0 end)

local function isNotable(point, lootable)
    -- A point is notable if it has loot you can use, or is tied to an
    -- achievement you can still earn
    if lootable and point.quest and allQuestsComplete(point.quest, point.accountquest) then
        -- asked for only notable points that are currently lootable, which
        -- means questless or quest-incomplete
        return false
    end
    if ns.db.achievement_notable and point.achievement and not isAchieved(point) then
        return true
    end
    if point.loot and hasNotableLoot(point.loot) then
        return true
    end
    if ns.db.notable_shared and point.loot_shared and hasNotableLoot(point.loot_shared) then
        return true
    end
end
ns.PointIsNotable = isNotable

local zoneHidden
zoneHidden = function(uiMapID)
    if ns.db.zonesHidden[uiMapID] then
        return true
    end
    local info = C_Map.GetMapInfo(uiMapID)
    if info and info.parentMapID then
        return zoneHidden(info.parentMapID)
    end
    return false
end
local achievementHidden = function(achievement)
    if not achievement then return false end
    return ns.db.achievementsHidden[achievement]
end

local function showOnMapType(point, uiMapID, isMinimap)
    -- nil means to respect the preferences, but points can override
    if isMinimap then
        if point.minimap ~= nil then
            if type(point.minimap) == "boolean" then
                return point.minimap
            elseif type(point.minimap) == "function" then
                return point.minimap(point, uiMapID)
            end
            return ns.conditions.check(point.minimap)
        end
        return ns.db.show_on_minimap
    end
    if point.worldmap ~= nil then return point.worldmap end
    return ns.db.show_on_world
end

-- false while any loot that might drop for this character is still missing,
-- true once it is all accounted for, and nil if there is none to judge by.
local function lootIsFound(loot)
    if not (loot and hasKnowableLoot(loot, true)) then return end
    return allLootKnown(loot, true)
end

local function PointIsFound(point)
    if ns.db.found or point.always then return false end

    -- these are overrides:
    if point.inbag and itemInBags(point.inbag) then
        return true
    end
    if point.onquest and C_QuestLog.IsOnQuest(type(point.onquest) == "number" and point.onquest or point.quest) then
        return true
    end
    if point.hide_quest and C_QuestLog.IsQuestFlaggedCompleted(point.hide_quest) then
        -- This is distinct from point.quest as it's supposed to be for
        -- other trackers that make the point not _complete_ but still
        -- hidden (Draenor treasure maps, so far):
        return true
    end

    -- from here on it's actually found:
    local found
    local lootFound = lootIsFound(point.loot)
    if lootFound ~= nil then
        if not lootFound then return false end
        found = true
    end
    -- A rare whose own loot is all in the shared pool would otherwise be found
    -- as soon as its achievement criterion was, which hides it while it can
    -- still drop you something.
    if ns.db.notable_shared then
        local sharedFound = lootIsFound(point.loot_shared)
        if sharedFound ~= nil then
            if not sharedFound then return false end
            found = true
        end
    end
    if point.achievement and not point.achievementNotFound then
        if not isAchieved(point) then
            return false
        end
        found = true
    end
    if point.quest then
        if not allQuestsComplete(point.quest, point.accountquest) then
            return false
        end
        found = true
    end
    if point.found then
        if not ns.conditions.check(point.found) then
            return false
        end
        found = true
    end
    return found, found ~= nil -- gets us a true/false/nil found/notfound/unfindable
end

ns.should_show_point = function(coord, point, currentZone, isMinimap)
    if not coord or coord < 0 then return false end
    if not showOnMapType(point, currentZone, isMinimap) then
        return false
    end
    if point.force ~= nil then
        return point.force
    end
    if ns.hidden[currentZone] and ns.hidden[currentZone][coord] then
        return false
    end
    if zoneHidden(currentZone) then
        return false
    end
    if achievementHidden(point.achievement) then
        return false
    end
    if point.group and ns.db.groupsHidden[point.group] or ns.db.groupsHiddenByZone[currentZone][point.group] then
        return false
    end
    if point.ShouldShow then
        local show = point:ShouldShow()
        if show ~= nil then
            return show
        end
    end
    if point.npc then
        -- only npcs that are questless or that have an uncompleted quest
        if not ns.db.show_npcs then
            return false
        end
        if ns.db.show_npcs_filter == "notable" and not isNotable(point) then
            -- notable npcs have loot you can use or have an incomplete achievement
            return point.always
        end
        if
            (ns.db.show_npcs_filter == "lootable" or ns.db.show_npcs_filter == "notable")
            -- rewarding npcs either have no affiliated quest, or their quest is incomplete
            and point.quest and allQuestsComplete(point.quest, point.accountquest) and not ns.db.found
        then
            return point.always
        end
    elseif point.loot then
        -- Not an NPC, must be treasure if it has some sort of loot
        if not ns.db.show_treasure then
            return false
        end
        if ns.db.show_treasure_filter == "notable" and not isNotable(point) then
            -- notable npcs have loot you can use or have an incomplete achievement
            return point.always
        end
        if
            (ns.db.show_treasure_filter == "lootable" or ns.db.show_treasure_filter == "notable")
            -- rewarding treasure either has no affiliated quest, or their quest is incomplete
            and point.quest and allQuestsComplete(point.quest, point.accountquest) and not ns.db.found
        then
            return point.always
        end
    end
    if not ns.db.found then
        local isFound = PointIsFound(point)
        local isFindable = isFound ~= nil
        if isFindable and isFound then
            return false
        end
    end
    if point.requires and not ns.conditions.check(point.requires) then
        return false
    end
    if not ns.db.upcoming or point.upcoming == false then
        if not ns.point_active(point) then
            return false
        end
        if ns.point_upcoming(point) then
            return false
        end
    end
    return true
end
