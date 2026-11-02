--[[
    QuestMaster Quest Tracker - Distance Module
    Distance calculations for quests and objectives
]]

local addonName, QM = ...
local Tracker = QM.Tracker

-- ============================================================================
-- Get Nearest Objective Distance
-- ============================================================================

function QM:GetNearestObjectiveDistance(questId)
    local minDist = math.huge

    -- Try objective locations first
    local locs = self:GetQuestObjectiveLocationsFixed(questId)
    if locs then
        for _, objLocs in pairs(locs) do
            if objLocs then
                for _, loc in ipairs(objLocs) do
                    local d = self:GetDistanceToPoint(loc.x, loc.y, loc.mapId)
                    if d and d < minDist then minDist = d end
                end
            end
        end
    end

    -- Fallback: Try quest start NPC location
    if minDist == math.huge and QM.DB then
        local dbQuest = QM.DB:GetQuest(questId)
        if dbQuest and dbQuest.startedBy and dbQuest.startedBy[1] then
            local npcId = dbQuest.startedBy[1][1]
            if npcId then
                local spawns = QM.DB:GetNPCSpawnLocations(npcId)
                if spawns and spawns[1] then
                    local d = self:GetDistanceToPoint(spawns[1].x, spawns[1].y, spawns[1].mapId)
                    if d and d < minDist then minDist = d end
                end
            end
        end
    end

    -- Fallback: Try turn-in NPC location
    if minDist == math.huge and QM.DB then
        local turnInLocs = QM.DB:GetQuestTurnInLocations(questId)
        if turnInLocs and turnInLocs[1] then
            local d = self:GetDistanceToPoint(turnInLocs[1].x, turnInLocs[1].y, turnInLocs[1].mapId)
            if d and d < minDist then minDist = d end
        end
    end

    return minDist < math.huge and minDist or nil
end

-- ============================================================================
-- Get Quest Turn-In Location
-- ============================================================================

function QM:GetQuestTurnInLocation(questId)
    if not QM.DB then return nil end
    return QM.DB:GetQuestTurnInLocations(questId)
end

-- ============================================================================
-- Update Quest Distances (continuous update)
-- ============================================================================

function QM:UpdateQuestDistances()
    local TrackerFrame = Tracker.frame
    if not TrackerFrame or not TrackerFrame:IsShown() then return end

    local distDisplay = QM.db.profile.tracker.distanceDisplay or "quest"
    local hideClose = QM.db.profile.tracker.hideDistanceWhenClose
    local compactNums = QM.db.profile.tracker.compactNumbers

    for _, f in ipairs(Tracker.questFramePool) do
        if f.inUse and f.questData and f.distance then
            if distDisplay == "none" then
                f.distance:Hide()
            else
                local dist
                if f.questData.isComplete then
                    -- Completed quests: turn-in distance
                    local locs = QM.DB:GetQuestTurnInLocations(f.questData.id)
                    if locs and locs[1] then
                        dist = self:GetDistanceToPoint(locs[1].x, locs[1].y, locs[1].mapId)
                    end
                else
                    -- Incomplete quests: objective distance
                    dist = self:GetNearestObjectiveDistance(f.questData.id)
                end

                if dist and dist < 99999 then
                    if hideClose and dist < 100 then
                        f.distance:SetText("")
                        f.distance:Hide()
                    else
                        local r, g, b = Tracker:GetDistanceColor(dist)
                        local distText
                        if compactNums then
                            distText = Tracker:FormatDistanceCompact(dist)
                        else
                            distText = Tracker:FormatDistanceFull(dist)
                        end
                        f.distance:SetText(distText)
                        f.distance:SetTextColor(r, g, b)
                        f.distance:Show()
                    end
                else
                    f.distance:SetText("")
                    f.distance:Hide()
                end
            end
        end
    end
end
