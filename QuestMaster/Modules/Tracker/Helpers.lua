--[[
    QuestMaster Quest Tracker - Helper Functions
    Distance formatting, colors, progress calculations

    Note: Core distance/color functions are in QuestMaster.lua
    These are thin wrappers for backwards compatibility
]]

local addonName, QM = ...
local Tracker = QM.Tracker

-- ============================================================================
-- Distance Formatting (wrappers around QM functions)
-- ============================================================================

-- Format distance in compact form with unit
function Tracker:FormatDistanceCompact(yards)
    if not yards then return "" end
    return QM:FormatDistance(yards, true)  -- compact = true
end

-- Format distance with full unit (non-compact)
function Tracker:FormatDistanceFull(yards)
    if not yards then return "" end
    return QM:FormatDistance(yards, false)  -- compact = false
end

-- ============================================================================
-- Color Functions (wrapper around QM function)
-- ============================================================================

-- Get distance color based on proximity
function Tracker:GetDistanceColor(yards)
    return QM:GetDistanceColor(yards)
end

-- Get progress color based on completion percentage
function Tracker:GetProgressColor(current, required)
    if not current or not required or required == 0 then return 0.8, 0.8, 0.8 end
    local pct = current / required
    if pct >= 1 then
        return 0.3, 1, 0.3  -- Complete
    elseif pct >= 0.75 then
        return 0.6, 1, 0.3  -- Almost done
    elseif pct >= 0.5 then
        return 1, 1, 0.3    -- Halfway
    elseif pct >= 0.25 then
        return 1, 0.7, 0.2  -- Started
    else
        return 1, 0.5, 0.2  -- Just started
    end
end

-- Get quest color based on difficulty
function Tracker:GetQuestColor(quest)
    if not quest then return unpack(self.COLORS.questNormal) end

    if quest.isComplete then
        return unpack(self.COLORS.questComplete)
    end

    -- Color by difficulty if enabled
    if QM.db and QM.db.profile and QM.db.profile.tracker and QM.db.profile.tracker.colorByDifficulty then
        local playerLevel = UnitLevel("player")
        local questLevel = quest.level or playerLevel
        local diff = questLevel - playerLevel

        if diff >= 5 then
            return 1, 0.1, 0.1  -- Red - very hard
        elseif diff >= 3 then
            return 1, 0.5, 0.25 -- Orange - hard
        elseif diff >= -2 then
            return 1, 1, 0      -- Yellow - normal
        elseif diff >= -5 then
            return 0.25, 1, 0.25 -- Green - easy
        else
            return 0.5, 0.5, 0.5 -- Gray - trivial
        end
    end

    return unpack(self.COLORS.questNormal)
end

-- ============================================================================
-- Progress Calculations
-- ============================================================================

-- Get quest progress as percentage
function Tracker:GetQuestProgress(quest)
    if not quest or not quest.objectives then return 0 end
    if quest.isComplete then return 1 end

    local done = 0
    local total = 0

    for _, obj in ipairs(quest.objectives) do
        total = total + 1
        if obj.finished then
            done = done + 1
        elseif obj.current and obj.required and obj.required > 0 then
            done = done + (obj.current / obj.required)
        end
    end

    return total > 0 and (done / total) or 0
end

-- ============================================================================
-- Zone Functions
-- ============================================================================

-- Zone name cache
local ZONE_NAMES = {
    [1] = "Durotar",
    [12] = "Elwynn Forest",
    [14] = "Dun Morogh",
    [85] = "Tirisfal Glades",
    [141] = "Teldrassil",
    [215] = "Mulgore",
    [1497] = "Undercity",
    [1519] = "Stormwind City",
    [1537] = "Ironforge",
    [1637] = "Orgrimmar",
    [1638] = "Thunder Bluff",
    [1657] = "Darnassus",
}

-- Get quest zone name
function Tracker:GetQuestZone(quest)
    if not quest then return "Unknown", 0 end

    -- Try to get zone from quest objectives or turn-in location
    if QM.DB then
        local turnInLocs = QM.DB:GetQuestTurnInLocations(quest.id)
        if turnInLocs and turnInLocs[1] and turnInLocs[1].mapId then
            local mapInfo = C_Map.GetMapInfo(turnInLocs[1].mapId)
            if mapInfo then
                return mapInfo.name, turnInLocs[1].mapId
            end
        end
    end

    -- Fallback to current player zone
    local mapId = C_Map.GetBestMapForUnit("player")
    if mapId then
        local name = ZONE_NAMES[mapId]
        if not name and C_Map.GetMapInfo(mapId) then
            name = C_Map.GetMapInfo(mapId).name
        end
        return name or "Unknown", mapId
    end

    return "Unknown", 0
end
