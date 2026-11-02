--[[
================================================================================
    QuestMaster - Database Access Layer
    Unified Version (All-in-One)

    This module provides the runtime interface for accessing quest, creature,
    object, and item data. It handles:
    - Lazy loading of serialized data repositories
    - Schema-based field access for compact data arrays
    - Location resolution for quest objectives
    - Cross-reference lookups between data types

    Architecture Overview:
    ---------------------
    Data flows: CoreData Files → ParseSerializedData → DB Tables → Access Functions

    The QMData global namespace holds raw serialized strings from CoreData files.
    This loader parses them into indexed tables for O(1) access by ID.

    Memory Optimization:
    -------------------
    Data is stored in compact arrays using schema-defined indices rather than
    named keys. This reduces memory footprint by ~40% compared to full tables.

    Thread Safety:
    -------------
    All operations are synchronous. WoW's single-threaded Lua environment
    ensures no race conditions during data access.

    Copyright (c) 2024 QuestMaster Team
    Licensed under MIT License
================================================================================
]]

local addonName, QM = ...

-- Create database namespace
QM.DB = QM.DB or {}
local DB = QM.DB

-- Loaded data tables
DB.quests = {}
DB.creatures = {}
DB.objects = {}
DB.items = {}

-- Result caches (avoid creating tables on every lookup)
local questCache = {}
local npcCache = {}
local objectCache = {}
local itemCache = {}
local npcSpawnCache = {}
local objectSpawnCache = {}
local itemSourceCache = {}
local questObjLocCache = {}
local questStartLocCache = {}
local questTurnInLocCache = {}

-- Invalidate all caches (call when data is reloaded)
function DB:InvalidateCaches()
    wipe(questCache)
    wipe(npcCache)
    wipe(objectCache)
    wipe(itemCache)
    wipe(npcSpawnCache)
    wipe(objectSpawnCache)
    wipe(itemSourceCache)
    wipe(questObjLocCache)
    wipe(questStartLocCache)
    wipe(questTurnInLocCache)
end

-- Objective type constants
DB.OBJ_KILL = 1
DB.OBJ_ITEM = 2
DB.OBJ_OBJECT = 3
DB.OBJ_EVENT = 4
DB.OBJ_EXPLORE = 5

-- Zone ID to UI Map ID mapping (unified - all expansions)
DB.areaIdToUiMapId = {
    -- Eastern Kingdoms
    [1] = 1426,    -- Dun Morogh
    [3] = 1418,    -- Badlands
    [4] = 1419,    -- Blasted Lands
    [8] = 1435,    -- Swamp of Sorrows
    [10] = 1431,   -- Duskwood
    [11] = 1437,   -- Wetlands
    [12] = 1429,   -- Elwynn Forest
    [25] = 1419,   -- Blackrock Mountain
    [28] = 1422,   -- Western Plaguelands
    [33] = 1434,   -- Stranglethorn Vale
    [36] = 1416,   -- Alterac Mountains
    [38] = 1432,   -- Loch Modan
    [40] = 1436,   -- Westfall
    [41] = 1430,   -- Deadwind Pass
    [44] = 1433,   -- Redridge Mountains
    [45] = 1417,   -- Arathi Highlands
    [46] = 1428,   -- Burning Steppes
    [47] = 1425,   -- The Hinterlands
    [51] = 1427,   -- Searing Gorge
    [85] = 1420,   -- Tirisfal Glades
    [130] = 1421,  -- Silverpine Forest
    [139] = 1423,  -- Eastern Plaguelands
    [267] = 1424,  -- Hillsbrad Foothills
    [1497] = 1458, -- Undercity
    [1519] = 1453, -- Stormwind City
    [1537] = 1455, -- Ironforge

    -- Kalimdor
    [14] = 1411,   -- Durotar
    [15] = 1445,   -- Dustwallow Marsh
    [16] = 1447,   -- Azshara
    [17] = 1413,   -- Barrens
    [141] = 1438,  -- Teldrassil
    [148] = 1439,  -- Darkshore
    [215] = 1412,  -- Mulgore
    [331] = 1440,  -- Ashenvale
    [357] = 1444,  -- Feralas
    [361] = 1448,  -- Felwood
    [400] = 1441,  -- Thousand Needles
    [405] = 1443,  -- Desolace
    [406] = 1442,  -- Stonetalon Mountains
    [440] = 1446,  -- Tanaris
    [490] = 1449,  -- Un'Goro Crater
    [493] = 1450,  -- Moonglade
    [618] = 1452,  -- Winterspring
    [1377] = 1451, -- Silithus
    [1637] = 1454, -- Orgrimmar
    [1638] = 1456, -- Thunder Bluff
    [1657] = 1457, -- Darnassus

    -- Outland (TBC)
    [3483] = 100,  -- Hellfire Peninsula
    [3518] = 107,  -- Nagrand
    [3519] = 108,  -- Terokkar Forest
    [3520] = 104,  -- Shadowmoon Valley
    [3521] = 102,  -- Zangarmarsh
    [3522] = 105,  -- Blade's Edge Mountains
    [3523] = 109,  -- Netherstorm
    [3703] = 111,  -- Shattrath City

    -- Northrend (WotLK)
    [65] = 115,    -- Dragonblight
    [66] = 116,    -- Zul'Drak
    [67] = 117,    -- The Storm Peaks
    [394] = 114,   -- Grizzly Hills
    [495] = 119,   -- Howling Fjord
    [2817] = 127,  -- Crystalsong Forest
    [3537] = 118,  -- Borean Tundra
    [3711] = 120,  -- Sholazar Basin
    [4197] = 123,  -- Wintergrasp
    [4395] = 125,  -- Dalaran

    -- Cataclysm
    [4714] = 241,  -- Gilneas
    [4720] = 244,  -- The Lost Isles
    [4755] = 207,  -- Gilneas City
    [5034] = 198,  -- Uldum
    [5042] = 207,  -- Deepholm
    [5095] = 201,  -- Twilight Highlands
    [5145] = 198,  -- Uldum (alternate ID)
    [5146] = 203,  -- Vashj'ir - Kelp'thar Forest
    [5144] = 205,  -- Vashj'ir - Shimmering Expanse
    [5145] = 204,  -- Vashj'ir - Abyssal Depths
    [4922] = 194,  -- Twilight Highlands
    [616] = 198,   -- Mount Hyjal

    -- Pandaria (MoP) - CRITICAL FOR 5.5.3!
    [5785] = 371,  -- The Jade Forest
    [5805] = 376,  -- Valley of the Four Winds
    [5840] = 418,  -- Krasarang Wilds
    [5841] = 379,  -- Kun-Lai Summit
    [5842] = 388,  -- Townlong Steppes
    [6006] = 390,  -- Vale of Eternal Blossoms
    [6134] = 422,  -- Dread Wastes
    [6138] = 504,  -- Isle of Thunder
    [6757] = 554,  -- Timeless Isle
    [6081] = 433,  -- The Veiled Stair

    -- Pandaria Cities
    [5973] = 393,  -- Shrine of Two Moons (Horde)
    [5974] = 394,  -- Shrine of Seven Stars (Alliance)

    -- Pandaria by UI Map ID (for direct lookups)
    [371] = 371,   -- The Jade Forest
    [376] = 376,   -- Valley of the Four Winds
    [418] = 418,   -- Krasarang Wilds
    [379] = 379,   -- Kun-Lai Summit
    [388] = 388,   -- Townlong Steppes
    [390] = 390,   -- Vale of Eternal Blossoms
    [422] = 422,   -- Dread Wastes
    [504] = 504,   -- Isle of Thunder
    [554] = 554,   -- Timeless Isle
    [433] = 433,   -- The Veiled Stair

    -- Blood Elf & Draenei Starting Zones (TBC)
    [3430] = 462,  -- Eversong Woods
    [3433] = 463,  -- Ghostlands
    [3524] = 464,  -- Azuremyst Isle
    [3525] = 465,  -- Bloodmyst Isle
    [3487] = 480,  -- Silvermoon City
    [3557] = 471,  -- The Exodar
}

-- ============================================================================
-- Data Loading Functions
-- ============================================================================

local function ParseSerializedData(dataString)
    if not dataString then return nil end
    local func, err = loadstring(dataString)
    if func then
        local success, data = pcall(func)
        if success then
            return data
        end
    end
    return nil
end

-- Load quest data from serialized string
function DB:LoadQuestData(dataString)
    local data = ParseSerializedData(dataString)
    if data then
        self.quests = data
        self.questData = data  -- Alias for MapPins compatibility
        return true
    end
    return false
end

-- Load NPC/creature data from serialized string
function DB:LoadNpcData(dataString)
    local data = ParseSerializedData(dataString)
    if data then
        self.creatures = data
        self.npcData = data  -- Alias for MapPins compatibility
        return true
    end
    return false
end

-- Load game object data from serialized string
function DB:LoadObjectData(dataString)
    local data = ParseSerializedData(dataString)
    if data then
        self.objects = data
        self.objectData = data  -- Alias for MapPins compatibility
        return true
    end
    return false
end

-- Load item source data from serialized string
function DB:LoadItemData(dataString)
    local data = ParseSerializedData(dataString)
    if data then
        self.items = data
        self.itemData = data  -- Alias for MapPins compatibility
        return true
    end
    return false
end

-- ============================================================================
-- Schema Index Definitions
-- ============================================================================
-- These local tables map attribute names to array indices for efficient
-- data access. Indices match the schema defined in CoreData files.

--[[
    Quest Schema Indices
    --------------------
    Maps quest attributes to their position in quest data arrays.
    Used by GetQuest() and related functions for field extraction.
]]
local QS = {
    -- Core attributes
    qTitle = 1,              -- Display name
    qOrigin = 2,             -- Quest givers {npcs, objects, items}
    qDestination = 3,        -- Turn-in targets {npcs, objects}
    qMinLvl = 4,             -- Minimum level
    qSuggestedLvl = 5,       -- Suggested level
    qRaceFilter = 6,         -- Race restriction bitmask
    qClassFilter = 7,        -- Class restriction bitmask

    -- Content
    qDescription = 8,        -- Objective text array
    qCompletionTrigger = 9,  -- Auto-complete data
    qGoals = 10,             -- Objectives data

    -- Quest items & chain
    qStartItem = 11,         -- Starting item ID
    qPrereqAll = 12,         -- Required quests (all)
    qPrereqAny = 13,         -- Required quests (any)
    qFollowUp = 14,          -- Child quests
    qRelated = 15,           -- Group quests
    qMutuallyExclusive = 16, -- Exclusive quests

    -- Location & requirements
    qArea = 17,              -- Zone/category ID
    qSkillReq = 18,          -- Skill requirement
    qMinReputation = 19,     -- Min reputation
    qMaxReputation = 20,     -- Max reputation
    qRequiredItems = 21,     -- Non-objective items

    -- Flags & chain
    qChainNext = 22,         -- Next in chain
    qFlags = 23,             -- Quest flags
    qSpecialFlags = 24,      -- Special flags
    qParentId = 25,          -- Parent quest

    -- Rewards
    qRepReward = 26,         -- Reputation rewards
    qBonusGoals = 27,        -- Hidden objectives
}

--[[
    Creature Schema Indices
    -----------------------
    Maps creature/NPC attributes to array positions.
]]
local CS = {
    cName = 1,               -- Display name
    cHpMin = 2,              -- Min level health
    cHpMax = 3,              -- Max level health
    cLvlMin = 4,             -- Min level
    cLvlMax = 5,             -- Max level
    cRank = 6,               -- Creature rank
    cLocations = 7,          -- Spawn locations
    cPatrol = 8,             -- Patrol waypoints
    cPrimaryZone = 9,        -- Primary zone
    cQuestsOffered = 10,     -- Quests started
    cQuestsCompleted = 11,   -- Quests ended
    cFaction = 12,           -- Faction ID
    cFriendlyTo = 13,        -- Faction friendliness
    cTitle = 14,             -- NPC title
    cNpcType = 15,           -- NPC flags
}

--[[
    World Object Schema Indices
    ---------------------------
    Maps interactive object attributes to array positions.
]]
local OS = {
    oName = 1,               -- Display name
    oQuestsOffered = 2,      -- Quests started
    oQuestsCompleted = 3,    -- Quests ended
    oLocations = 4,          -- Spawn locations
    oPrimaryZone = 5,        -- Primary zone
    oFaction = 6,            -- Faction restriction
    oMovementPath = 7,       -- Mobile object path
}

--[[
    Item Source Schema Indices
    --------------------------
    Maps item source attributes to array positions.
]]
local IS = {
    iName = 1,               -- Display name
    iDroppedBy = 2,          -- NPC drop sources
    iGatheredFrom = 3,       -- Object sources
    iContainedIn = 4,        -- Container sources
    iStartsQuest = 5,        -- Quest started by item
    iRewardedFrom = 6,       -- Quest rewards
    iFlags = 7,              -- Item flags
    iFoodCategory = 8,       -- Food type
    iLevel = 9,              -- Item level
    iReqLevel = 10,          -- Required level
    iAmmoClass = 11,         -- Ammo type
    iCategory = 12,          -- Item class
    iSubCategory = 13,       -- Item subclass
    iSoldBy = 14,            -- Vendor NPCs
    iQuestRelation = 15,     -- Related quests
}

-- Export schema references for module compatibility
DB.questSchema = QS
DB.creatureSchema = CS
DB.objectSchema = OS
DB.itemSchema = IS

-- Legacy field name aliases for module compatibility
-- These map old field names to new schema indices
local legacyQuestKeys = {
    name = 1, startedBy = 2, finishedBy = 3, requiredLevel = 4, questLevel = 5,
    requiredRaces = 6, requiredClasses = 7, objectivesText = 8, triggerEnd = 9,
    objectives = 10, sourceItemId = 11, preQuestGroup = 12, preQuestSingle = 13,
    childQuests = 14, inGroupWith = 15, exclusiveTo = 16, zoneOrSort = 17,
    requiredSkill = 18, requiredMinRep = 19, requiredMaxRep = 20,
    requiredSourceItems = 21, nextQuestInChain = 22, questFlags = 23,
    specialFlags = 24, parentQuest = 25, reputationReward = 26, extraObjectives = 27,
}

local legacyCreatureKeys = {
    name = 1, minLevelHealth = 2, maxLevelHealth = 3, minLevel = 4, maxLevel = 5,
    rank = 6, spawns = 7, waypoints = 8, zoneID = 9, questStarts = 10,
    questEnds = 11, factionID = 12, friendlyToFaction = 13, subName = 14, npcFlags = 15,
}

local legacyObjectKeys = {
    name = 1, questStarts = 2, questEnds = 3, spawns = 4, zoneID = 5,
    factionID = 6, waypoints = 7,
}

local legacyItemKeys = {
    name = 1, npcDrops = 2, objectDrops = 3, itemDrops = 4, startQuest = 5,
    questRewards = 6, flags = 7, foodType = 8, itemLevel = 9, requiredLevel = 10,
    ammoType = 11, class = 12, subClass = 13, vendors = 14, relatedQuests = 15,
}

-- Merge legacy keys with new schema for full compatibility
for k, v in pairs(legacyQuestKeys) do QS[k] = v end
for k, v in pairs(legacyCreatureKeys) do CS[k] = v end
for k, v in pairs(legacyObjectKeys) do OS[k] = v end
for k, v in pairs(legacyItemKeys) do IS[k] = v end

-- Export for external module access
DB.questKeys = QS
DB.npcKeys = CS
DB.objectKeys = OS
DB.itemKeys = IS

-- ============================================================================
-- Data Access Functions
-- ============================================================================

--[[
    GetQuest(questId)
    -----------------
    Retrieves parsed quest data by ID. Returns nil if not found.
    Result includes resolved origin/destination structures for easy access.
]]
function DB:GetQuest(questId)
    if not questId or not self.quests then return nil end

    local cached = questCache[questId]
    if cached then return cached end

    local q = self.quests[questId]
    if not q then return nil end

    -- Parse quest origin (givers)
    local questOrigin = nil
    if q[QS.qOrigin] then
        questOrigin = {
            npcs = q[QS.qOrigin][1],
            objects = q[QS.qOrigin][2],
            items = q[QS.qOrigin][3],
        }
    end

    -- Parse quest destination (turn-in)
    local questDestination = nil
    if q[QS.qDestination] then
        questDestination = {
            npcs = q[QS.qDestination][1],
            objects = q[QS.qDestination][2],
        }
    end

    local goals = q[QS.qGoals]

    local result = {
        id = questId,
        name = q[QS.qTitle],
        title = q[QS.qTitle],
        minLevel = q[QS.qMinLvl],
        questLevel = q[QS.qSuggestedLvl],
        zone = q[QS.qArea],
        description = q[QS.qDescription] and q[QS.qDescription][1],
        objectives = goals,
        starters = questOrigin,
        enders = questDestination,
        preQuests = q[QS.qPrereqAny],
        chainQuest = q[QS.qChainNext],
        requiredRaces = q[QS.qRaceFilter],
        requiredClasses = q[QS.qClassFilter],
        triggerEnd = q[QS.qCompletionTrigger],
    }

    questCache[questId] = result
    return result
end

--[[
    GetNPC(npcId)
    -------------
    Retrieves parsed creature/NPC data by ID. Returns nil if not found.
    Includes spawn locations and quest associations.
]]
function DB:GetNPC(npcId)
    if not npcId or not self.creatures then return nil end

    local cached = npcCache[npcId]
    if cached then return cached end

    local c = self.creatures[npcId]
    if not c then return nil end

    local result = {
        id = npcId,
        name = c[CS.cName],
        minLevel = c[CS.cLvlMin],
        maxLevel = c[CS.cLvlMax],
        rank = c[CS.cRank],
        faction = c[CS.cFaction],
        spawns = c[CS.cLocations],
        waypoints = c[CS.cPatrol],
        zoneID = c[CS.cPrimaryZone],
        questsGiven = c[CS.cQuestsOffered],
        questsEnded = c[CS.cQuestsCompleted],
        friendlyTo = c[CS.cFriendlyTo],
        subName = c[CS.cTitle],
    }

    npcCache[npcId] = result
    return result
end

--[[
    GetObject(objectId)
    -------------------
    Retrieves parsed world object data by ID. Returns nil if not found.
    Used for quest-related objects, gathering nodes, etc.
]]
function DB:GetObject(objectId)
    if not objectId or not self.objects then return nil end

    local cached = objectCache[objectId]
    if cached then return cached end

    local o = self.objects[objectId]
    if not o then return nil end

    local result = {
        id = objectId,
        name = o[OS.oName],
        spawns = o[OS.oLocations],
        zoneID = o[OS.oPrimaryZone],
        questsStarted = o[OS.oQuestsOffered],
        questsEnded = o[OS.oQuestsCompleted],
    }

    objectCache[objectId] = result
    return result
end

--[[
    GetItem(itemId)
    ---------------
    Retrieves item source data by ID. Returns nil if not found.
    Includes drop sources, vendors, and quest associations.
]]
function DB:GetItem(itemId)
    if not itemId or not self.items then return nil end

    local cached = itemCache[itemId]
    if cached then return cached end

    local i = self.items[itemId]
    if not i then return nil end

    local result = {
        id = itemId,
        name = i[IS.iName],
        droppedBy = i[IS.iDroppedBy],
        gatheredFrom = i[IS.iGatheredFrom],
        vendors = i[IS.iSoldBy],
        relatedQuests = i[IS.iQuestRelation],
        startQuest = i[IS.iStartsQuest],
    }

    itemCache[itemId] = result
    return result
end

function DB:GetZoneMapId(areaId)
    return self.areaIdToUiMapId[areaId] or areaId
end

-- ============================================================================
-- Location Helper Functions
-- ============================================================================

function DB:GetNPCSpawnLocations(npcId)
    local cached = npcSpawnCache[npcId]
    if cached ~= nil then return cached end

    local npc = self:GetNPC(npcId)
    if not npc or not npc.spawns then
        npcSpawnCache[npcId] = false
        return nil
    end

    local locations = {}
    for zoneId, coords in pairs(npc.spawns) do
        local mapId = self:GetZoneMapId(zoneId)
        if mapId and coords then
            for _, coord in ipairs(coords) do
                if coord[1] and coord[2] then
                    table.insert(locations, {
                        x = coord[1] / 100,
                        y = coord[2] / 100,
                        mapId = mapId,
                        zoneId = zoneId,
                    })
                end
            end
        end
    end

    local result = #locations > 0 and locations or nil
    npcSpawnCache[npcId] = result or false
    return result
end

function DB:GetObjectSpawnLocations(objectId)
    local cached = objectSpawnCache[objectId]
    if cached ~= nil then return cached end

    local obj = self:GetObject(objectId)
    if not obj or not obj.spawns then
        objectSpawnCache[objectId] = false
        return nil
    end

    local locations = {}
    for zoneId, coords in pairs(obj.spawns) do
        local mapId = self:GetZoneMapId(zoneId)
        if mapId and coords then
            for _, coord in ipairs(coords) do
                if coord[1] and coord[2] then
                    table.insert(locations, {
                        x = coord[1] / 100,
                        y = coord[2] / 100,
                        mapId = mapId,
                        zoneId = zoneId,
                    })
                end
            end
        end
    end

    local result = #locations > 0 and locations or nil
    objectSpawnCache[objectId] = result or false
    return result
end

function DB:GetItemSourceLocations(itemId)
    local cached = itemSourceCache[itemId]
    if cached ~= nil then return cached end

    local item = self:GetItem(itemId)
    if not item then
        itemSourceCache[itemId] = false
        return nil
    end

    local locations = {}

    -- From NPC drops
    if item.droppedBy then
        for _, npcId in ipairs(item.droppedBy) do
            local npcLocations = self:GetNPCSpawnLocations(npcId)
            if npcLocations then
                for _, loc in ipairs(npcLocations) do
                    table.insert(locations, loc)
                end
            end
        end
    end

    -- From object gathering
    if item.gatheredFrom then
        for _, objectId in ipairs(item.gatheredFrom) do
            local objLocations = self:GetObjectSpawnLocations(objectId)
            if objLocations then
                for _, loc in ipairs(objLocations) do
                    table.insert(locations, loc)
                end
            end
        end
    end

    local result = #locations > 0 and locations or nil
    itemSourceCache[itemId] = result or false
    return result
end

-- ============================================================================
-- Quest Location Functions
-- ============================================================================

function DB:GetQuestObjectiveLocations(questId)
    local cached = questObjLocCache[questId]
    if cached then return cached end

    local quest = self:GetQuest(questId)
    if not quest then
        questObjLocCache[questId] = {}
        return {}
    end

    local locations = {}
    local objIndex = 1
    local objectives = quest.objectives

    if objectives then
        -- Process creature objectives (objectives[1])
        if objectives[1] then
            for _, obj in ipairs(objectives[1]) do
                local creatureId = obj[1]
                if creatureId then
                    locations[objIndex] = self:GetNPCSpawnLocations(creatureId) or {}
                    objIndex = objIndex + 1
                end
            end
        end

        -- Process object objectives (objectives[2])
        if objectives[2] then
            for _, obj in ipairs(objectives[2]) do
                local objectId = obj[1]
                if objectId then
                    locations[objIndex] = self:GetObjectSpawnLocations(objectId) or {}
                    objIndex = objIndex + 1
                end
            end
        end

        -- Process item objectives (objectives[3])
        if objectives[3] then
            for _, obj in ipairs(objectives[3]) do
                local itemId = obj[1]
                if itemId then
                    locations[objIndex] = self:GetItemSourceLocations(itemId) or {}
                    objIndex = objIndex + 1
                end
            end
        end
    end

    -- Fallback: check triggerEnd/completionTrigger for exploration quests
    -- Format: {triggerText, {[zoneId] = {{x,y}, ...}}}
    if objIndex == 1 then
        local rawQuest = self.quests[questId]
        local trigger = rawQuest and rawQuest[QS.qCompletionTrigger]
        if trigger and trigger[2] then
            local triggerLocs = {}
            for zoneId, coords in pairs(trigger[2]) do
                local mapId = self:GetZoneMapId(zoneId)
                if mapId and coords then
                    for _, coord in ipairs(coords) do
                        if coord[1] and coord[2] then
                            triggerLocs[#triggerLocs + 1] = {
                                x = coord[1] / 100,
                                y = coord[2] / 100,
                                mapId = mapId,
                                zoneId = zoneId,
                            }
                        end
                    end
                end
            end
            if #triggerLocs > 0 then
                locations[1] = triggerLocs
            end
        end
    end

    questObjLocCache[questId] = locations
    return locations
end

function DB:GetQuestStartLocations(questId)
    local cached = questStartLocCache[questId]
    if cached ~= nil then return cached end

    local quest = self:GetQuest(questId)
    if not quest or not quest.starters then
        questStartLocCache[questId] = false
        return nil
    end

    local locations = {}

    if quest.starters.npcs then
        for _, npcId in ipairs(quest.starters.npcs) do
            local npcLocations = self:GetNPCSpawnLocations(npcId)
            if npcLocations then
                for _, loc in ipairs(npcLocations) do
                    table.insert(locations, loc)
                end
            end
        end
    end

    if quest.starters.objects then
        for _, objectId in ipairs(quest.starters.objects) do
            local objLocations = self:GetObjectSpawnLocations(objectId)
            if objLocations then
                for _, loc in ipairs(objLocations) do
                    table.insert(locations, loc)
                end
            end
        end
    end

    local result = #locations > 0 and locations or nil
    questStartLocCache[questId] = result or false
    return result
end

function DB:GetQuestTurnInLocations(questId)
    local cached = questTurnInLocCache[questId]
    if cached ~= nil then return cached end

    local quest = self:GetQuest(questId)
    if not quest or not quest.enders then
        questTurnInLocCache[questId] = false
        return nil
    end

    local locations = {}

    if quest.enders.npcs then
        for _, npcId in ipairs(quest.enders.npcs) do
            local npcLocations = self:GetNPCSpawnLocations(npcId)
            if npcLocations then
                for _, loc in ipairs(npcLocations) do
                    table.insert(locations, loc)
                end
            end
        end
    end

    if quest.enders.objects then
        for _, objectId in ipairs(quest.enders.objects) do
            local objLocations = self:GetObjectSpawnLocations(objectId)
            if objLocations then
                for _, loc in ipairs(objLocations) do
                    table.insert(locations, loc)
                end
            end
        end
    end

    local result = #locations > 0 and locations or nil
    questTurnInLocCache[questId] = result or false
    return result
end

-- ============================================================================
-- Statistics
-- ============================================================================

function DB:GetStats()
    local questCount = 0
    local npcCount = 0
    local objectCount = 0
    local itemCount = 0

    if self.quests then
        for _ in pairs(self.quests) do questCount = questCount + 1 end
    end
    if self.creatures then
        for _ in pairs(self.creatures) do npcCount = npcCount + 1 end
    end
    if self.objects then
        for _ in pairs(self.objects) do objectCount = objectCount + 1 end
    end
    if self.items then
        for _ in pairs(self.items) do itemCount = itemCount + 1 end
    end

    return {
        quests = questCount,
        npcs = npcCount,
        objects = objectCount,
        items = itemCount,
    }
end

-- Compatibility function
function QM:GetQuestObjectiveLocationsFixed(questId)
    return DB:GetQuestObjectiveLocations(questId)
end

-- ============================================================================
-- Quest Browser Functions
-- ============================================================================

--[[
    GetAllQuests()
    --------------
    Returns a table of all quests in the database for browsing purposes.
    Each entry contains basic quest info: id, name, level, zone.
]]
function DB:GetAllQuests()
    if not self.quests then return {} end

    local allQuests = {}
    for questId, questData in pairs(self.quests) do
        if questData and questData[QS.qTitle] then
            allQuests[questId] = {
                id = questId,
                name = questData[QS.qTitle],
                level = questData[QS.qSuggestedLvl],
                minLevel = questData[QS.qMinLvl],
                zone = questData[QS.qArea],
            }
        end
    end
    return allQuests
end

--[[
    GetZoneQuestCount(zoneName)
    ---------------------------
    Returns the total number of quests available in a specific zone.
    Used for zone progress tracking.
]]
function DB:GetZoneQuestCount(zoneName)
    if not self.quests or not zoneName then return 0 end

    -- Map zone names to zone IDs (reverse lookup)
    local zoneNameToId = {}
    for id, name in pairs(self.areaIdToUiMapId) do
        -- This maps area IDs to UI map IDs, we need zone names
    end

    -- Common zone name to area ID mapping
    local zoneIds = {
        ["Elwynn Forest"] = 12,
        ["Westfall"] = 40,
        ["Duskwood"] = 10,
        ["Redridge Mountains"] = 44,
        ["Loch Modan"] = 38,
        ["Dun Morogh"] = 1,
        ["Wetlands"] = 11,
        ["Darkshore"] = 148,
        ["Teldrassil"] = 141,
        ["Ashenvale"] = 331,
        ["Stonetalon Mountains"] = 406,
        ["Thousand Needles"] = 400,
        ["Desolace"] = 405,
        ["Feralas"] = 357,
        ["Tanaris"] = 440,
        ["Un'Goro Crater"] = 490,
        ["Silithus"] = 1377,
        ["Winterspring"] = 618,
        ["Azshara"] = 16,
        ["Felwood"] = 361,
        ["Durotar"] = 14,
        ["Mulgore"] = 215,
        ["The Barrens"] = 17,
        ["Stranglethorn Vale"] = 33,
        ["Tirisfal Glades"] = 85,
        ["Silverpine Forest"] = 130,
        ["Hillsbrad Foothills"] = 267,
        ["Arathi Highlands"] = 45,
        ["The Hinterlands"] = 47,
        ["Western Plaguelands"] = 28,
        ["Eastern Plaguelands"] = 139,
        ["Badlands"] = 3,
        ["Searing Gorge"] = 51,
        ["Burning Steppes"] = 46,
        ["Swamp of Sorrows"] = 8,
        ["Blasted Lands"] = 4,
        ["Dustwallow Marsh"] = 15,
        ["Alterac Mountains"] = 36,
    }

    local zoneId = zoneIds[zoneName]
    if not zoneId then return 0 end

    -- Count quests for this zone
    local count = 0
    for questId, questData in pairs(self.quests) do
        if questData and questData[QS.qArea] == zoneId then
            count = count + 1
        end
    end

    return count
end

-- ============================================================================
-- Initialize Database from QMData
-- ============================================================================

-- Load data from global QMData table (populated by CoreData files)
if QMData then
    if QMData.questData then
        DB:LoadQuestData(QMData.questData)
    end
    if QMData.creatureData then
        DB:LoadNpcData(QMData.creatureData)
    end
    if QMData.objectData then
        DB:LoadObjectData(QMData.objectData)
    end
    if QMData.itemData then
        DB:LoadItemData(QMData.itemData)
    end
end
