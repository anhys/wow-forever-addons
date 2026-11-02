--[[
    QuestMaster Database Module
    Provides quest objective location data from built-in database
]]

local addonName, QM = ...
local L = QM.L

-- Reference to database
local DB = QM.DB

-- Caches
local questLocationCache = {}
local questLocationCacheTime = {}
local npcLocationCache = {}
local objectLocationCache = {}

-- Cache expiry time in seconds (5 minutes for database lookups)
local CACHE_EXPIRY = 300

-- ============================================================================
-- Database Initialization
-- ============================================================================

function QM:InitializeDatabase()
    -- Clear caches
    questLocationCache = {}
    questLocationCacheTime = {}
    npcLocationCache = {}
    objectLocationCache = {}

    -- Initialize the database loader
    if QM.DB then
        -- Load quest data
        if QMData and QMData.quests then
            local success = QM.DB:LoadQuestData(QMData.quests)
            if success then
                print("|cFF00FF00QuestMaster:|r Quest database loaded")
            end
        end

        -- Load creature data
        if QMData and QMData.creatures then
            local success = QM.DB:LoadNpcData(QMData.creatures)
            if success then
                print("|cFF00FF00QuestMaster:|r Creature database loaded")
            end
        end

        -- Load game object data
        if QMData and QMData.gameObjects then
            local success = QM.DB:LoadObjectData(QMData.gameObjects)
            if success then
                print("|cFF00FF00QuestMaster:|r GameObject database loaded")
            end
        end

        -- Load item source data
        if QMData and QMData.itemSources then
            local success = QM.DB:LoadItemData(QMData.itemSources)
            if success then
                print("|cFF00FF00QuestMaster:|r Item source database loaded")
            end
        end

        -- Print stats
        local stats = QM.DB:GetStats()
        print(string.format("|cFF00FF00QuestMaster:|r Loaded %d quests, %d creatures, %d objects, %d items",
            stats.quests, stats.npcs, stats.objects, stats.items))
    end

    self.databaseReady = true
end

-- ============================================================================
-- Quest Location Retrieval
-- ============================================================================

function QM:GetQuestObjectiveLocations(questId)
    if not questId then return nil end
    if not self.databaseReady then return nil end

    local now = GetTime()

    -- Check cache with expiry
    if questLocationCache[questId] and questLocationCacheTime[questId] then
        if now - questLocationCacheTime[questId] < CACHE_EXPIRY then
            return questLocationCache[questId]
        end
    end

    -- Get from database
    local locations = QM.DB:GetQuestObjectiveLocations(questId)

    if locations and next(locations) then
        questLocationCache[questId] = locations
        questLocationCacheTime[questId] = now
    end

    return locations
end

function QM:GetQuestTurnInLocation(questId)
    if not questId then return nil end
    if not self.databaseReady then return nil end

    local locations = QM.DB:GetQuestTurnInLocations(questId)
    if locations and locations[1] then
        return locations[1]
    end

    return nil
end

function QM:GetQuestStartLocations(questId)
    if not questId then return nil end
    if not self.databaseReady then return nil end

    return QM.DB:GetQuestStartLocations(questId)
end

function QM:GetNPCLocations(npcId)
    if not npcId then return nil end
    if not self.databaseReady then return nil end

    -- Check cache
    if npcLocationCache[npcId] then
        return npcLocationCache[npcId]
    end

    local locations = QM.DB:GetNPCSpawnLocations(npcId)

    if locations and #locations > 0 then
        npcLocationCache[npcId] = locations
    end

    return locations
end

function QM:GetObjectLocations(objectId)
    if not objectId then return nil end
    if not self.databaseReady then return nil end

    -- Check cache
    if objectLocationCache[objectId] then
        return objectLocationCache[objectId]
    end

    local locations = QM.DB:GetObjectSpawnLocations(objectId)

    if locations and #locations > 0 then
        objectLocationCache[objectId] = locations
    end

    return locations
end

function QM:GetItemSourceLocations(itemId)
    if not itemId then return nil end
    if not self.databaseReady then return nil end

    return QM.DB:GetItemSourceLocations(itemId)
end

-- ============================================================================
-- Quest Info Retrieval
-- ============================================================================

function QM:GetQuestInfo(questId)
    if not questId then return nil end
    if not self.databaseReady then return nil end

    return QM.DB:GetQuest(questId)
end

function QM:GetNPCInfo(npcId)
    if not npcId then return nil end
    if not self.databaseReady then return nil end

    return QM.DB:GetNPC(npcId)
end

function QM:GetObjectInfo(objectId)
    if not objectId then return nil end
    if not self.databaseReady then return nil end

    return QM.DB:GetObject(objectId)
end

function QM:GetItemInfo(itemId)
    if not itemId then return nil end
    if not self.databaseReady then return nil end

    return QM.DB:GetItem(itemId)
end

-- ============================================================================
-- Zone Conversion
-- ============================================================================

function QM:ZoneToMapId(zoneId)
    if not zoneId then return nil end
    if not self.databaseReady then return zoneId end

    return QM.DB:GetZoneMapId(zoneId)
end

-- ============================================================================
-- Cache Management
-- ============================================================================

function QM:ClearLocationCache()
    wipe(questLocationCache)
    wipe(questLocationCacheTime)
    wipe(npcLocationCache)
    wipe(objectLocationCache)
end

function QM:ClearQuestCache(questId)
    questLocationCache[questId] = nil
    questLocationCacheTime[questId] = nil
end
