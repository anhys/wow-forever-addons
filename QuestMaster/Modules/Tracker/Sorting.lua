--[[
    QuestMaster Quest Tracker - Sorting Module
    Quest sorting and filtering functions
]]

local addonName, QM = ...
local Tracker = QM.Tracker

-- ============================================================================
-- Sort Comparators (defined once to avoid closure allocation)
-- ============================================================================

-- Sort by level (ascending), then by title
local function SortByLevel(a, b)
    local lvlA = tonumber(a.level) or 0
    local lvlB = tonumber(b.level) or 0
    if lvlA ~= lvlB then
        return lvlA < lvlB
    end
    return (a.title or "") < (b.title or "")
end

-- Sort by objective distance (ascending), then by title
local function SortByObjectiveDistance(a, b)
    local distA = tonumber(a.objectiveDistance) or 999999
    local distB = tonumber(b.objectiveDistance) or 999999
    if distA ~= distB then
        return distA < distB
    end
    return (a.title or "") < (b.title or "")
end

-- Sort by turn-in distance (ascending), then by title
local function SortByTurnInDistance(a, b)
    local distA = tonumber(a.turnInDistance) or 999999
    local distB = tonumber(b.turnInDistance) or 999999
    if distA ~= distB then
        return distA < distB
    end
    return (a.title or "") < (b.title or "")
end

-- ============================================================================
-- Get Incomplete Quests (sorted)
-- ============================================================================

function QM:GetIncompleteQuests()
    local quests = {}

    for _, quest in pairs(self.activeQuests or {}) do
        -- Check filters
        local isTracked = true
        if QM.db and QM.db.profile and QM.db.profile.filter then
            if quest.isRaid and not QM.db.profile.filter.showRaid then
                isTracked = false
            elseif quest.isDungeon and not QM.db.profile.filter.showDungeon then
                isTracked = false
            elseif quest.isGroup and not QM.db.profile.filter.showGroup then
                isTracked = false
            end
        end

        -- Check if quest is watched
        if quest.logIndex and IsQuestWatched then
            local watched = IsQuestWatched(quest.logIndex)
            if not watched and QM.db and QM.db.profile and QM.db.profile.tracker.onlyShowWatched then
                isTracked = false
            end
        end

        -- Exclude completed quests
        if isTracked and not quest.isComplete then
            -- Calculate distance to QUEST OBJECTIVES (not turn-in!)
            local dist = 999999

            if QM.DB then
                -- First try: Quest objective locations (most relevant for incomplete quests)
                local objLocs = self:GetQuestObjectiveLocationsFixed(quest.id)
                if objLocs then
                    for _, objLocList in pairs(objLocs) do
                        if objLocList then
                            for _, loc in ipairs(objLocList) do
                                local d = self:GetDistanceToPoint(loc.x, loc.y, loc.mapId)
                                if d and d < dist then dist = d end
                            end
                        end
                    end
                end

                -- Fallback: Quest start NPC location
                if dist == 999999 then
                    local dbQuest = QM.DB:GetQuest(quest.id)
                    if dbQuest and dbQuest.startedBy and dbQuest.startedBy[1] then
                        local npcId = dbQuest.startedBy[1][1]
                        if npcId then
                            local spawns = QM.DB:GetNPCSpawnLocations(npcId)
                            if spawns and spawns[1] then
                                local d = self:GetDistanceToPoint(spawns[1].x, spawns[1].y, spawns[1].mapId)
                                if d then dist = d end
                            end
                        end
                    end
                end

                -- Last fallback: Turn-in NPC location
                if dist == 999999 then
                    local turnInLocs = QM.DB:GetQuestTurnInLocations(quest.id)
                    if turnInLocs and turnInLocs[1] then
                        local d = self:GetDistanceToPoint(turnInLocs[1].x, turnInLocs[1].y, turnInLocs[1].mapId)
                        if d then dist = d end
                    end
                end
            end

            quest.objectiveDistance = dist
            table.insert(quests, quest)
        end
    end

    -- Get sort preference
    local sortBy = (QM.db and QM.db.profile and QM.db.profile.tracker and QM.db.profile.tracker.sortBy) or "distance"

    -- Sort quests (using pre-defined comparators)
    if sortBy == "level" then
        table.sort(quests, SortByLevel)
    else
        table.sort(quests, SortByObjectiveDistance)
    end

    return quests
end

-- ============================================================================
-- Get Completed Quests (sorted)
-- ============================================================================

function QM:GetCompletedQuests()
    local completed = {}

    for _, quest in pairs(self.activeQuests or {}) do
        if quest.isComplete then
            -- Calculate turn-in distance
            local turnInDist = 999999
            if QM.DB then
                local locs = QM.DB:GetQuestTurnInLocations(quest.id)
                if locs and locs[1] then
                    local d = self:GetDistanceToPoint(locs[1].x, locs[1].y, locs[1].mapId)
                    if d then turnInDist = d end
                end
            end
            quest.turnInDistance = turnInDist
            table.insert(completed, quest)
        end
    end

    -- Get sort preference
    local sortBy = (QM.db and QM.db.profile and QM.db.profile.tracker and QM.db.profile.tracker.sortBy) or "distance"

    -- Sort quests (using pre-defined comparators)
    if sortBy == "level" then
        table.sort(completed, SortByLevel)
    else
        table.sort(completed, SortByTurnInDistance)
    end

    return completed
end

-- ============================================================================
-- Get All Sorted Quests (legacy compatibility)
-- ============================================================================

local _sortedQuests = {}
function QM:GetSortedQuests()
    local quests = _sortedQuests
    wipe(quests)

    for _, quest in pairs(self.activeQuests or {}) do
        quests[#quests + 1] = quest
    end

    local sortBy = (QM.db and QM.db.profile and QM.db.profile.tracker and QM.db.profile.tracker.sortBy) or "distance"

    -- Sort quests (using pre-defined comparators)
    if sortBy == "level" then
        table.sort(quests, SortByLevel)
    else
        table.sort(quests, SortByObjectiveDistance)
    end

    return quests
end
