--[[
    QuestMaster Map Pins Module
    Displays quest objective pins on the world map and minimap
    Shows available quests (!) and turn-in quests (?)
    Shows quest areas with colored blob overlays
    Shows danger zones (elite mobs, contested areas)
    Uses HereBeDragons for coordinate handling
]]

local addonName, QM = ...
local L = QM.L
local HBD = QM.HBD
local HBDPins = QM.HBDPins

-- Pin frame pools
local worldMapPinPool = {}
local minimapPinPool = {}
local areaBlobPool = {}
local dangerZonePool = {}
local patrolLinePool = {}

-- Active pins
local activeWorldPins = {}
local activeMinimapPins = {}
local activeAreaBlobs = {}
local activeDangerZones = {}
local activePatrolLines = {}

-- Quest objective location cache (invalidated on quest updates)
local questLocationCache = {}
local questLocationCacheTime = {}

-- Available quest pin cache (per mapId, invalidated on level up / quest changes)
local availableQuestCache = {}
local availableQuestCacheTime = {}
local AVAILABLE_QUEST_CACHE_TTL = 60  -- Cache for 60 seconds

-- Throttle for UpdateWorldMapPins
local lastWorldMapPinUpdate = 0
local WORLD_MAP_PIN_THROTTLE = 0.5  -- Max 2 updates per second

-- Pin sizes
local PIN_SIZE_OBJECTIVE = 16
local PIN_SIZE_AVAILABLE = 20
local PIN_SIZE_TURNIN = 20

-- Helper to get correct world map parent (TBC Classic vs Retail)
local function GetWorldMapParent()
    -- TBC Classic 2.5.5 uses WorldMapButton
    if WorldMapButton then
        return WorldMapButton
    end
    -- Retail uses ScrollContainer.Child
    if WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
        return WorldMapFrame.ScrollContainer.Child
    end
    -- Fallback
    return WorldMapFrame
end
local MINIMAP_PIN_SIZE = 12
local AREA_BLOB_BASE_SIZE = 100

-- Quest icon textures
local ICON_AVAILABLE_QUEST = "Interface\\GossipFrame\\AvailableQuestIcon"
local ICON_AVAILABLE_QUEST_TRIVIAL = "Interface\\GossipFrame\\AvailableLegendaryQuestIcon"
local ICON_TURNIN_QUEST = "Interface\\GossipFrame\\ActiveQuestIcon"
local ICON_OBJECTIVE_SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local ICON_OBJECTIVE_DOT = "Interface\\COMMON\\Indicator-Yellow"
local ICON_OBJECTIVE_ITEM = "Interface\\MINIMAP\\Tracking\\Banker"
local ICON_DANGER = "Interface\\TargetingFrame\\UI-TargetingFrame-Elite"

-- Colors for different objective types (like Retail WoW)
local AREA_COLORS = {
    kill = {r = 0.9, g = 0.2, b = 0.2, a = 0.35},      -- Red for kill quests
    item = {r = 0.9, g = 0.9, b = 0.2, a = 0.35},      -- Yellow for item collection
    interact = {r = 0.2, g = 0.6, b = 0.9, a = 0.35},  -- Blue for interaction
    explore = {r = 0.2, g = 0.9, b = 0.4, a = 0.35},   -- Green for exploration
    default = {r = 0.9, g = 0.7, b = 0.2, a = 0.35},   -- Gold default
    turnin = {r = 0.2, g = 0.9, b = 0.2, a = 0.4},     -- Bright green for turn-in
}

local DANGER_COLORS = {
    elite = {r = 1.0, g = 0.4, b = 0.1, a = 0.25},     -- Orange for elite areas
    pvp = {r = 0.8, g = 0.2, b = 0.2, a = 0.2},        -- Red for PvP areas
    dungeon = {r = 0.5, g = 0.2, b = 0.8, a = 0.3},    -- Purple for dungeon entrances
}

-- ============================================================================
-- Pin Frame Creation
-- ============================================================================

function QM:InitializeMapPins()
    worldMapPinPool = {}
    minimapPinPool = {}
    areaBlobPool = {}
    dangerZonePool = {}
    patrolLinePool = {}
    activeWorldPins = {}
    activeMinimapPins = {}
    activeAreaBlobs = {}
    activeDangerZones = {}
    activePatrolLines = {}

    -- Hook into world map opening
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function()
            QM:UpdateWorldMapPins()
        end)

        -- SetMapID hook (may not exist in all Classic versions)
        if WorldMapFrame.SetMapID then
            hooksecurefunc(WorldMapFrame, "SetMapID", function()
                C_Timer.After(0.1, function()
                    QM:UpdateWorldMapPins()
                end)
            end)
        end
    end

    self:UpdateMapPins()
end

-- ============================================================================
-- Area Blob Creation (Retail-style quest areas)
-- ============================================================================

function QM:CreateAreaBlob()
    local frame = CreateFrame("Frame", nil, GetWorldMapParent())
    frame:SetSize(AREA_BLOB_BASE_SIZE, AREA_BLOB_BASE_SIZE)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(10)

    -- Main area texture - circular gradient blob
    frame.texture = frame:CreateTexture(nil, "BACKGROUND")
    frame.texture:SetAllPoints()
    frame.texture:SetTexture("Interface\\AddOns\\QuestMaster\\Textures\\QuestArea")
    frame.texture:SetBlendMode("ADD")

    -- Fallback if custom texture doesn't exist
    if not frame.texture:GetTexture() then
        frame.texture:SetTexture("Interface\\GLUES\\Models\\UI_MainMenu_Cataclysm\\Circle")
    end

    -- Edge glow for better visibility
    frame.glow = frame:CreateTexture(nil, "ARTWORK")
    frame.glow:SetPoint("CENTER")
    frame.glow:SetSize(AREA_BLOB_BASE_SIZE + 20, AREA_BLOB_BASE_SIZE + 20)
    frame.glow:SetTexture("Interface\\GLUES\\Models\\UI_MainMenu_Cataclysm\\Circle")
    frame.glow:SetBlendMode("ADD")
    frame.glow:SetAlpha(0.15)

    -- Pulsing animation for active areas
    frame.animGroup = frame:CreateAnimationGroup()
    local pulse = frame.animGroup:CreateAnimation("Alpha")
    pulse:SetFromAlpha(0.8)
    pulse:SetToAlpha(1.0)
    pulse:SetDuration(1.5)
    pulse:SetSmoothing("IN_OUT")
    frame.animGroup:SetLooping("BOUNCE")

    frame:Hide()
    return frame
end

function QM:CreateDangerZone()
    local frame = CreateFrame("Frame", nil, GetWorldMapParent())
    frame:SetSize(AREA_BLOB_BASE_SIZE, AREA_BLOB_BASE_SIZE)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(5)

    -- Danger zone texture with hazard pattern
    frame.texture = frame:CreateTexture(nil, "BACKGROUND")
    frame.texture:SetAllPoints()
    frame.texture:SetTexture("Interface\\GLUES\\Models\\UI_MainMenu_Cataclysm\\Circle")
    frame.texture:SetBlendMode("ADD")

    -- Skull indicator for elite areas
    frame.skull = frame:CreateTexture(nil, "OVERLAY")
    frame.skull:SetSize(20, 20)
    frame.skull:SetPoint("CENTER")
    frame.skull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    frame.skull:SetAlpha(0.6)

    frame:Hide()
    return frame
end

-- ============================================================================
-- World Map Pin Creation
-- ============================================================================

function QM:CreateWorldMapPin()
    local frame = CreateFrame("Button", nil, GetWorldMapParent())
    frame:SetSize(PIN_SIZE_OBJECTIVE, PIN_SIZE_OBJECTIVE)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(100)
    frame:EnableMouse(true)
    if frame.RegisterForClicks then
        frame:RegisterForClicks("AnyUp", "AnyDown")
    end

    -- Background circle for better visibility
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetSize(frame:GetWidth() + 6, frame:GetHeight() + 6)
    frame.bg:SetPoint("CENTER")
    frame.bg:SetTexture("Interface\\COMMON\\Indicator-Gray")
    frame.bg:SetVertexColor(0, 0, 0, 0.6)

    -- Icon texture
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()

    -- Glow effect
    frame.glow = frame:CreateTexture(nil, "OVERLAY")
    frame.glow:SetSize(frame:GetWidth() + 12, frame:GetHeight() + 12)
    frame.glow:SetPoint("CENTER")
    frame.glow:SetTexture("Interface\\GLUES\\MODELS\\UI_MainMenu\\swordglow")
    frame.glow:SetBlendMode("ADD")
    frame.glow:SetAlpha(0)

    -- Count/progress text
    frame.count = frame:CreateFontString(nil, "OVERLAY")
    frame.count:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    frame.count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
    frame.count:SetTextColor(1, 1, 1, 1)

    -- Elite indicator
    frame.elite = frame:CreateTexture(nil, "OVERLAY")
    frame.elite:SetSize(12, 12)
    frame.elite:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
    frame.elite:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Elite")
    frame.elite:Hide()

    -- Tooltip
    frame:SetScript("OnEnter", function(self)
        self.glow:SetAlpha(0.6)
        if self.pinData then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

            if self.pinData.pinType == "available" then
                GameTooltip:AddLine(L["PIN_TOOLTIP_AVAILABLE_QUEST"], 1, 0.82, 0)
                GameTooltip:AddLine(self.pinData.title, 1, 1, 1)
                if self.pinData.level then
                    local color = QM:GetQuestDifficultyColor(self.pinData.level)
                    GameTooltip:AddLine(string.format(L["PIN_TOOLTIP_LEVEL"], self.pinData.level), color.r, color.g, color.b)
                end
                if self.pinData.isElite then
                    GameTooltip:AddLine("|cFFFF8800" .. L["PIN_TOOLTIP_ELITE_BADGE"] .. "|r", 1, 0.5, 0)
                end
            elseif self.pinData.pinType == "turnin" then
                GameTooltip:AddLine(L["PIN_TOOLTIP_TURNIN_QUEST"], 0, 1, 0)
                GameTooltip:AddLine(self.pinData.title, 1, 1, 1)
            elseif self.pinData.pinType == "danger" then
                GameTooltip:AddLine("|cFFFF4444" .. L["PIN_TOOLTIP_DANGER_ZONE"] .. "|r", 1, 0.3, 0.3)
                GameTooltip:AddLine(self.pinData.description or L["PIN_TOOLTIP_DANGER_ZONE_DESC"], 1, 0.7, 0.3)
            else
                GameTooltip:AddLine(self.pinData.title or L["PIN_TOOLTIP_QUEST_OBJECTIVE"], 1, 0.82, 0)
                if self.pinData.description then
                    GameTooltip:AddLine(self.pinData.description, 1, 1, 1, true)
                end
                if self.pinData.progress then
                    GameTooltip:AddLine(self.pinData.progress, 0.6, 0.9, 0.6)
                end
                if self.pinData.isElite then
                    GameTooltip:AddLine("|cFFFF8800" .. L["PIN_TOOLTIP_ELITE_ENEMY"] .. "|r", 1, 0.5, 0)
                end
            end

            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFF888888" .. L["PIN_TOOLTIP_CLICK_WAYPOINT"] .. "|r", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end
    end)

    frame:SetScript("OnLeave", function(self)
        self.glow:SetAlpha(0)
        GameTooltip:Hide()
    end)

    frame:SetScript("OnClick", function(self, button)
        if self.pinData and button == "LeftButton" then
            QM:SetWaypoint(
                self.pinData.questId,
                self.pinData.objectiveIndex or 0,
                self.pinData.x,
                self.pinData.y,
                self.pinData.mapId,
                self.pinData.description or self.pinData.title,
                true  -- isManual = true, prevents auto-select from overriding
            )
            if QM.ArrowFrame then
                QM.ArrowFrame:SetAlpha(0)
                UIFrameFadeIn(QM.ArrowFrame, 0.3, 0, 1)
            end
            print(L["MSG_PREFIX"] .. " " .. L["MSG_WAYPOINT_SET_MANUAL"])
        end
    end)

    frame:Hide()
    return frame
end

function QM:CreateMinimapPin()
    local frame = CreateFrame("Button", nil, Minimap)
    frame:SetSize(MINIMAP_PIN_SIZE, MINIMAP_PIN_SIZE)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(10)
    frame:EnableMouse(true)
    if frame.RegisterForClicks then
        frame:RegisterForClicks("AnyUp", "AnyDown")
    end

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()

    frame:SetScript("OnEnter", function(self)
        if self.pinData then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.pinData.title or L["PIN_TOOLTIP_QUEST_OBJECTIVE"], 1, 0.82, 0)
            if self.pinData.description then
                GameTooltip:AddLine(self.pinData.description, 1, 1, 1, true)
            end
            GameTooltip:Show()
        end
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    frame:SetScript("OnClick", function(self, button)
        if self.pinData and button == "LeftButton" then
            QM:SetWaypoint(
                self.pinData.questId,
                self.pinData.objectiveIndex or 0,
                self.pinData.x,
                self.pinData.y,
                self.pinData.mapId,
                self.pinData.description or self.pinData.title,
                true  -- isManual = true
            )
        end
    end)

    frame:Hide()
    return frame
end

-- ============================================================================
-- Pin Pool Management
-- ============================================================================

function QM:GetWorldMapPin()
    for _, pin in ipairs(worldMapPinPool) do
        if not pin.inUse then
            pin.inUse = true
            return pin
        end
    end
    local pin = self:CreateWorldMapPin()
    pin.inUse = true
    table.insert(worldMapPinPool, pin)
    return pin
end

function QM:ReleaseWorldMapPin(pin)
    pin.inUse = false
    pin:Hide()
    pin.pinData = nil
    pin.elite:Hide()
    if HBDPins then
        HBDPins:RemoveWorldMapIcon("QuestMaster", pin)
    end
end

function QM:GetMinimapPin()
    for _, pin in ipairs(minimapPinPool) do
        if not pin.inUse then
            pin.inUse = true
            return pin
        end
    end
    local pin = self:CreateMinimapPin()
    pin.inUse = true
    table.insert(minimapPinPool, pin)
    return pin
end

function QM:ReleaseMinimapPin(pin)
    pin.inUse = false
    pin:Hide()
    pin.pinData = nil
    if HBDPins then
        HBDPins:RemoveMinimapIcon("QuestMaster", pin)
    end
end

function QM:GetAreaBlob()
    for _, blob in ipairs(areaBlobPool) do
        if not blob.inUse then
            blob.inUse = true
            return blob
        end
    end
    local blob = self:CreateAreaBlob()
    blob.inUse = true
    table.insert(areaBlobPool, blob)
    return blob
end

function QM:ReleaseAreaBlob(blob)
    blob.inUse = false
    blob:Hide()
    blob.animGroup:Stop()
    if HBDPins then
        HBDPins:RemoveWorldMapIcon("QuestMasterArea", blob)
    end
end

function QM:GetDangerZone()
    for _, zone in ipairs(dangerZonePool) do
        if not zone.inUse then
            zone.inUse = true
            return zone
        end
    end
    local zone = self:CreateDangerZone()
    zone.inUse = true
    table.insert(dangerZonePool, zone)
    return zone
end

function QM:ReleaseDangerZone(zone)
    zone.inUse = false
    zone:Hide()
    if HBDPins then
        HBDPins:RemoveWorldMapIcon("QuestMasterDanger", zone)
    end
end

-- ============================================================================
-- Patrol Path Line Creation
-- ============================================================================

function QM:CreatePatrolLine()
    local frame = CreateFrame("Frame", nil, GetWorldMapParent())
    frame:SetSize(2, 2)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(8)

    -- Line texture
    frame.line = frame:CreateLine(nil, "BACKGROUND")
    frame.line:SetThickness(2)
    frame.line:SetColorTexture(0.4, 0.7, 1.0, 0.6)

    frame:Hide()
    return frame
end

function QM:GetPatrolLine()
    for _, line in ipairs(patrolLinePool) do
        if not line.inUse then
            line.inUse = true
            return line
        end
    end
    local line = self:CreatePatrolLine()
    line.inUse = true
    table.insert(patrolLinePool, line)
    return line
end

function QM:ReleasePatrolLine(line)
    line.inUse = false
    line:Hide()
end

-- ============================================================================
-- Quest Difficulty Colors
-- ============================================================================

-- GetQuestDifficultyColor is now defined in QuestMaster.lua

-- ============================================================================
-- Quest Availability Check
-- ============================================================================

function QM:CanAcceptQuest(questData, playerLevel, playerFaction, playerRace, playerClass)
    if not questData then return false end

    local DB = QM.DB
    if not DB then return false end

    local reqLevel = questData[DB.questKeys.requiredLevel] or 1
    local questLevel = questData[DB.questKeys.questLevel] or 1
    local requiredRaces = questData[DB.questKeys.requiredRaces]
    local requiredClasses = questData[DB.questKeys.requiredClasses]

    if playerLevel < reqLevel then return false end
    if questLevel > playerLevel + 10 then return false end
    if questLevel < playerLevel - 8 then return false end

    if requiredRaces and requiredRaces > 0 then
        local playerRaceMask = self:GetRaceMask(playerRace)
        if bit.band(requiredRaces, playerRaceMask) == 0 then
            return false
        end
    end

    if requiredClasses and requiredClasses > 0 then
        local playerClassMask = self:GetClassMask(playerClass)
        if bit.band(requiredClasses, playerClassMask) == 0 then
            return false
        end
    end

    return true
end

function QM:GetRaceMask(race)
    local raceMasks = {
        ["Human"] = 1, ["Orc"] = 2, ["Dwarf"] = 4, ["NightElf"] = 8,
        ["Undead"] = 16, ["Tauren"] = 32, ["Gnome"] = 64, ["Troll"] = 128,
    }
    return raceMasks[race] or 0
end

function QM:GetClassMask(class)
    local classMasks = {
        ["WARRIOR"] = 1, ["PALADIN"] = 2, ["HUNTER"] = 4, ["ROGUE"] = 8,
        ["PRIEST"] = 16, ["SHAMAN"] = 64, ["MAGE"] = 128, ["WARLOCK"] = 256, ["DRUID"] = 1024,
    }
    return classMasks[class] or 0
end

-- ============================================================================
-- Check if NPC is Elite
-- ============================================================================

function QM:IsNPCElite(npcId)
    if not npcId or not QM.DB then return false end
    local npcData = QM.DB.npcData and QM.DB.npcData[npcId]
    if npcData then
        local rank = npcData[QM.DB.npcKeys.rank]
        return rank and rank >= 1  -- 1 = Elite, 2 = Rare Elite, 3 = World Boss
    end
    return false
end

function QM:GetNPCLevel(npcId)
    if not npcId or not QM.DB then return nil end
    local npcData = QM.DB.npcData and QM.DB.npcData[npcId]
    if npcData then
        return npcData[QM.DB.npcKeys.minLevel], npcData[QM.DB.npcKeys.maxLevel]
    end
    return nil, nil
end

-- ============================================================================
-- Main Pin Updates
-- ============================================================================

function QM:UpdateMapPins()
    -- Lazy map updates: skip if map not visible and setting enabled
    if QM.db.profile.performance.lazyMapUpdates then
        local mapVisible = WorldMapFrame and WorldMapFrame:IsShown()
        if not mapVisible then
            return  -- Skip update when map is closed
        end
    end

    self:UpdateWorldMapPins()
    self:UpdateMinimapPins()
end

function QM:UpdateWorldMapPins()
    if not QM.db.profile.map.enableWorldMap then
        self:ClearWorldMapPins()
        return
    end

    -- Throttle updates to prevent FPS drops
    local now = GetTime()
    if now - lastWorldMapPinUpdate < WORLD_MAP_PIN_THROTTLE then
        return
    end
    lastWorldMapPinUpdate = now

    -- Release all current pins
    for _, pin in ipairs(activeWorldPins) do
        self:ReleaseWorldMapPin(pin)
    end
    wipe(activeWorldPins)

    for _, blob in ipairs(activeAreaBlobs) do
        self:ReleaseAreaBlob(blob)
    end
    wipe(activeAreaBlobs)

    for _, zone in ipairs(activeDangerZones) do
        self:ReleaseDangerZone(zone)
    end
    wipe(activeDangerZones)

    for _, line in ipairs(activePatrolLines) do
        self:ReleasePatrolLine(line)
    end
    wipe(activePatrolLines)

    if not WorldMapFrame:IsShown() then return end
    local currentMapId = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    if not currentMapId then return end

    local scale = QM.db.profile.map.pinScale or 1
    local alpha = QM.db.profile.map.pinAlpha or 1

    -- 1. Add danger zones first (background layer)
    if QM.db.profile.map.showDangerZones ~= false then
        self:AddDangerZones(currentMapId, scale)
    end

    -- 1.5. Add patrol paths for quest objective NPCs
    if QM.db.profile.map.showPatrolPaths then
        self:AddPatrolPaths(currentMapId)
    end

    -- 2. Add area blobs for quest objectives (like Retail WoW)
    if QM.db.profile.map.showAreaBlobs ~= false then
        self:AddQuestAreaBlobs(currentMapId, scale, alpha)
    end

    -- 3. Add objective pins and turn-in pins (single loop)
    local showObjectives = QM.db.profile.map.showObjectivePins ~= false
    local showTurnIns = QM.db.profile.map.showTurnInPins ~= false
    if showObjectives or showTurnIns then
        for questId, quest in pairs(self.activeQuests or {}) do
            if quest.isComplete then
                if showTurnIns then
                    self:AddTurnInPinForQuest(questId, quest, currentMapId, scale, alpha)
                end
            else
                if showObjectives then
                    self:AddObjectivePinsForQuest(questId, quest, currentMapId, scale, alpha)
                end
            end
        end
    end

    -- 5. Add available quest pins (NPCs with new quests)
    if QM.db.profile.map.showAvailablePins ~= false then
        self:AddAvailableQuestPins(currentMapId, scale, alpha)
    end
end

-- ============================================================================
-- Quest Area Blobs (Retail-style)
-- ============================================================================

function QM:AddQuestAreaBlobs(currentMapId, scale, alpha)
    local processedAreas = {}
    alpha = alpha or 1

    for questId, quest in pairs(self.activeQuests or {}) do
        if not quest.isComplete then
            local dbLocations = self:GetQuestObjectiveLocationsFixed(questId)
            if dbLocations then
                for i, objective in ipairs(quest.objectives) do
                    if not objective.finished then
                        local locs = dbLocations[i]
                        if locs then
                            -- Group nearby locations by their own mapId
                            local locsByMap = {}
                            for _, loc in ipairs(locs) do
                                if loc.mapId and loc.x and loc.y then
                                    if not locsByMap[loc.mapId] then
                                        locsByMap[loc.mapId] = {}
                                    end
                                    table.insert(locsByMap[loc.mapId], loc)
                                end
                            end

                            for mapId, mapLocs in pairs(locsByMap) do
                                local areaGroups = self:GroupLocationsByProximity(mapLocs, mapId, 0.08)

                                for _, group in ipairs(areaGroups) do
                                    local centerX, centerY = self:GetGroupCenter(group)
                                    local areaKey = string.format("%d_%.2f_%.2f", mapId, centerX, centerY)

                                    if not processedAreas[areaKey] then
                                        processedAreas[areaKey] = true

                                        local blob = self:GetAreaBlob()

                                        -- Determine color based on objective type
                                        local color = AREA_COLORS.default
                                        local objType = objective.type or ""
                                        if objType == "monster" or objType == "kill" then
                                            color = AREA_COLORS.kill
                                        elseif objType == "item" then
                                            color = AREA_COLORS.item
                                        elseif objType == "object" then
                                            color = AREA_COLORS.interact
                                        elseif objType == "event" or objType == "explore" then
                                            color = AREA_COLORS.explore
                                        end

                                        blob.texture:SetVertexColor(color.r, color.g, color.b, color.a * alpha)
                                        blob.glow:SetVertexColor(color.r, color.g, color.b, 0.2 * alpha)

                                        -- Scale based on number of spawns in group
                                        local areaScale = math.min(1.5, 0.8 + (#group * 0.1))
                                        blob:SetSize(AREA_BLOB_BASE_SIZE * areaScale, AREA_BLOB_BASE_SIZE * areaScale)
                                        blob.glow:SetSize((AREA_BLOB_BASE_SIZE + 20) * areaScale, (AREA_BLOB_BASE_SIZE + 20) * areaScale)
                                        blob:SetScale(scale)
                                        blob:SetAlpha(alpha)

                                        -- Start pulsing animation (only if not already playing)
                                        if blob.animGroup and not blob.animGroup:IsPlaying() then
                                            blob.animGroup:Play()
                                        end

                                        if HBDPins then
                                            HBDPins:AddWorldMapIconMap("QuestMasterArea", blob, mapId, centerX, centerY, 2)
                                        end

                                        blob:Show()
                                        table.insert(activeAreaBlobs, blob)
                                    end
                                end
                        end
                    end
                end
            end
        end
    end
end

function QM:GroupLocationsByProximity(locations, targetMapId, threshold)
    local groups = {}
    local used = {}

    for i, loc in ipairs(locations) do
        if loc.mapId == targetMapId and not used[i] then
            local group = {loc}
            used[i] = true

            -- Find all nearby locations
            for j, otherLoc in ipairs(locations) do
                if not used[j] and otherLoc.mapId == targetMapId then
                    local dx = loc.x - otherLoc.x
                    local dy = loc.y - otherLoc.y
                    local dist = math.sqrt(dx*dx + dy*dy)

                    if dist < threshold then
                        table.insert(group, otherLoc)
                        used[j] = true
                    end
                end
            end

            table.insert(groups, group)
        end
    end

    return groups
end

function QM:GetGroupCenter(group)
    local sumX, sumY = 0, 0
    for _, loc in ipairs(group) do
        sumX = sumX + loc.x
        sumY = sumY + loc.y
    end
    return sumX / #group, sumY / #group
end

-- ============================================================================
-- Danger Zones
-- ============================================================================

function QM:AddDangerZones(currentMapId, scale)
    -- Add danger zones for elite mobs in active quest areas
    for questId, quest in pairs(self.activeQuests or {}) do
        if not quest.isComplete then
            local dbQuest = QM.DB and QM.DB:GetQuest(questId)
            if dbQuest and dbQuest.objectives and dbQuest.objectives[1] then
                for _, obj in ipairs(dbQuest.objectives[1]) do
                    local creatureId = obj[1]
                    if creatureId and self:IsNPCElite(creatureId) then
                        local spawns = QM.DB:GetNPCSpawnLocations(creatureId)
                        if spawns then
                            local processedDanger = {}
                            for _, loc in ipairs(spawns) do
                                if loc.mapId and loc.x and loc.y then
                                    local key = string.format("%d_%.2f_%.2f", loc.mapId, loc.x, loc.y)
                                    if not processedDanger[key] then
                                        processedDanger[key] = true

                                        local zone = self:GetDangerZone()
                                        local color = DANGER_COLORS.elite

                                        zone.texture:SetVertexColor(color.r, color.g, color.b, color.a)
                                        zone:SetSize(AREA_BLOB_BASE_SIZE * 1.2, AREA_BLOB_BASE_SIZE * 1.2)
                                        zone:SetScale(scale)
                                        zone.skull:Show()

                                        if HBDPins then
                                            HBDPins:AddWorldMapIconMap("QuestMasterDanger", zone, loc.mapId, loc.x, loc.y, 2)
                                        end

                                        zone:Show()
                                        table.insert(activeDangerZones, zone)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- Patrol Paths
-- ============================================================================

function QM:AddPatrolPaths(currentMapId)
    if not QM.DB or not QM.DB.creatures then return end

    local patrolColor = QM.db.profile.map.patrolPathColor or {0.4, 0.7, 1.0}
    local patrolAlpha = QM.db.profile.map.patrolPathAlpha or 0.6
    local processedNPCs = {}

    -- Get the world map parent for coordinate conversion (TBC Classic compatible)
    local mapParent = GetWorldMapParent()
    if not mapParent then return end

    local mapWidth, mapHeight = mapParent:GetSize()
    if not mapWidth or mapWidth == 0 then return end

    -- Draw patrol paths for quest objective NPCs
    for questId, quest in pairs(self.activeQuests or {}) do
        if not quest.isComplete then
            local dbQuest = QM.DB:GetQuest(questId)
            if dbQuest and dbQuest.objectives and dbQuest.objectives[1] then
                for _, obj in ipairs(dbQuest.objectives[1]) do
                    local npcId = obj[1]
                    if npcId and not processedNPCs[npcId] then
                        processedNPCs[npcId] = true
                        self:DrawNPCPatrolPath(npcId, currentMapId, mapWidth, mapHeight, patrolColor, patrolAlpha)
                    end
                end
            end
        end
    end
end

function QM:DrawNPCPatrolPath(npcId, currentMapId, mapWidth, mapHeight, color, alpha)
    if not QM.DB then return end

    local npc = QM.DB:GetNPC(npcId)
    if not npc or not npc.waypoints then return end

    -- Waypoints format: {zoneId = {{x1, y1}, {x2, y2}, ...}, ...}
    for zoneId, coords in pairs(npc.waypoints) do
        local mapId = QM.DB:GetZoneMapId(zoneId)
        if mapId == currentMapId and coords and #coords >= 2 then
            -- Convert waypoint coordinates to map positions
            local waypoints = {}
            for _, coord in ipairs(coords) do
                if coord[1] and coord[2] then
                    table.insert(waypoints, {
                        x = coord[1] / 100,
                        y = coord[2] / 100,
                    })
                end
            end

            -- Draw lines connecting waypoints
            for i = 1, #waypoints - 1 do
                local wp1 = waypoints[i]
                local wp2 = waypoints[i + 1]

                local lineFrame = self:GetPatrolLine()

                -- Convert normalized coordinates (0-1) to map pixel positions
                local x1 = wp1.x * mapWidth
                local y1 = wp1.y * mapHeight
                local x2 = wp2.x * mapWidth
                local y2 = wp2.y * mapHeight

                -- Set line position and appearance
                lineFrame.line:SetStartPoint("TOPLEFT", GetWorldMapParent(), x1, -y1)
                lineFrame.line:SetEndPoint("TOPLEFT", GetWorldMapParent(), x2, -y2)
                lineFrame.line:SetColorTexture(color[1], color[2], color[3], alpha)
                lineFrame.line:SetThickness(2)

                lineFrame:SetAllPoints(GetWorldMapParent())
                lineFrame:Show()
                table.insert(activePatrolLines, lineFrame)
            end

            -- Draw closing line (patrol loop) if there are 3+ waypoints
            if #waypoints >= 3 then
                local wpFirst = waypoints[1]
                local wpLast = waypoints[#waypoints]

                local lineFrame = self:GetPatrolLine()

                local x1 = wpLast.x * mapWidth
                local y1 = wpLast.y * mapHeight
                local x2 = wpFirst.x * mapWidth
                local y2 = wpFirst.y * mapHeight

                lineFrame.line:SetStartPoint("TOPLEFT", GetWorldMapParent(), x1, -y1)
                lineFrame.line:SetEndPoint("TOPLEFT", GetWorldMapParent(), x2, -y2)
                lineFrame.line:SetColorTexture(color[1], color[2], color[3], alpha * 0.5)  -- Dimmer for return path
                lineFrame.line:SetThickness(1.5)

                lineFrame:SetAllPoints(GetWorldMapParent())
                lineFrame:Show()
                table.insert(activePatrolLines, lineFrame)
            end
        end
    end
end

-- ============================================================================
-- Objective Pins
-- ============================================================================

function QM:AddObjectivePinsForQuest(questId, quest, currentMapId, scale, alpha)
    local dbLocations = self:GetQuestObjectiveLocationsFixed(questId)
    if not dbLocations then return end

    local dbQuest = QM.DB and QM.DB:GetQuest(questId)

    for i, objective in ipairs(quest.objectives) do
        if not objective.finished then
            local locs = dbLocations[i]
            if locs then
                local shown = 0
                local maxPins = QM.db.profile.map.maxPinsPerObjective or 5

                -- Check if this objective involves elite mobs
                local isElite = false
                if dbQuest and dbQuest.objectives and dbQuest.objectives[1] then
                    for _, obj in ipairs(dbQuest.objectives[1]) do
                        if obj[1] and self:IsNPCElite(obj[1]) then
                            isElite = true
                            break
                        end
                    end
                end

                for _, loc in ipairs(locs) do
                    if shown >= maxPins then break end
                    if loc.mapId and loc.x and loc.y then
                        local pin = self:GetWorldMapPin()
                        pin:SetSize(PIN_SIZE_OBJECTIVE, PIN_SIZE_OBJECTIVE)
                        pin.pinData = {
                            questId = questId,
                            objectiveIndex = i,
                            x = loc.x,
                            y = loc.y,
                            mapId = loc.mapId,
                            title = quest.title,
                            description = objective.text,
                            progress = objective.current and objective.required and
                                string.format("%d/%d", objective.current, objective.required) or nil,
                            pinType = "objective",
                            isElite = isElite,
                        }

                        -- Set icon based on objective type
                        local objType = objective.type or ""
                        if objType == "monster" or objType == "kill" then
                            pin.icon:SetTexture(ICON_OBJECTIVE_SKULL)
                            pin.icon:SetVertexColor(1, 0.3, 0.3, 1)
                        elseif objType == "item" then
                            pin.icon:SetTexture(ICON_OBJECTIVE_ITEM)
                            pin.icon:SetVertexColor(1, 1, 0.5, 1)
                        else
                            pin.icon:SetTexture(ICON_OBJECTIVE_DOT)
                            pin.icon:SetVertexColor(1, 1, 0, 1)
                        end

                        -- Show elite indicator
                        if isElite then
                            pin.elite:Show()
                        end

                        pin:SetScale(scale)
                        pin:SetAlpha(alpha)

                        if HBDPins then
                            HBDPins:AddWorldMapIconMap("QuestMaster", pin, loc.mapId, loc.x, loc.y, 3)
                        end

                        pin:Show()
                        table.insert(activeWorldPins, pin)
                        shown = shown + 1
                    end
                end
            end
        end
    end
end

function QM:AddTurnInPinForQuest(questId, quest, currentMapId, scale, alpha)
    local turnInLocs = QM.DB and QM.DB:GetQuestTurnInLocations(questId)
    if not turnInLocs then return end
    alpha = alpha or 1

    for _, loc in ipairs(turnInLocs) do
        if loc.mapId and loc.x and loc.y then
            -- Add turn-in area blob
            local blob = self:GetAreaBlob()
            local color = AREA_COLORS.turnin
            blob.texture:SetVertexColor(color.r, color.g, color.b, color.a * alpha)
            blob.glow:SetVertexColor(color.r, color.g, color.b, 0.3 * alpha)
            blob:SetSize(60, 60)
            blob:SetScale(scale)
            blob:SetAlpha(alpha)
            blob.animGroup:Play()

            if HBDPins then
                HBDPins:AddWorldMapIconMap("QuestMasterArea", blob, loc.mapId, loc.x, loc.y, 2)
            end
            blob:Show()
            table.insert(activeAreaBlobs, blob)

            -- Add turn-in pin
            local pin = self:GetWorldMapPin()
            pin:SetSize(PIN_SIZE_TURNIN, PIN_SIZE_TURNIN)
            pin.pinData = {
                questId = questId,
                objectiveIndex = 0,
                x = loc.x,
                y = loc.y,
                mapId = loc.mapId,
                title = quest.title,
                description = "Turn in quest",
                pinType = "turnin",
            }

            pin.icon:SetTexture(ICON_TURNIN_QUEST)
            pin.icon:SetVertexColor(1, 1, 1, 1)
            pin.icon:SetTexCoord(0, 1, 0, 1)

            pin:SetScale(scale * 1.2)
            pin:SetAlpha(alpha)

            if HBDPins then
                HBDPins:AddWorldMapIconMap("QuestMaster", pin, loc.mapId, loc.x, loc.y, 3)
            end

            pin:Show()
            table.insert(activeWorldPins, pin)
            break
        end
    end
end

-- Continent to child zone mappings for continent-level available quest display
local CONTINENT_ZONES = {
    [13] = {  -- Eastern Kingdoms
        1415, 1416, 1417, 1418, 1419, 1420, 1421, 1422, 1423, 1424, 1425, 1426,
        1427, 1428, 1429, 1430, 1431, 1432, 1433, 1434, 1435, 1436, 1437, 1438,
        1439, 1440, 1441, 1442, 1443, 1444, 1445, 1446, 1447, 1448, 1449, 1450,
        1451, 1452, 1453, 1454, 1455, 1456, 1457, 1458, 1459, 1460, 1461, 1462, 1463,
    },
    [12] = {  -- Kalimdor
        1411, 1412, 1413, 1414,
    },
    [101] = {  -- Outland
        100, 102, 104, 105, 107, 108, 109, 111,
    },
    [113] = { -- Northrend
        114, 115, 116, 117, 118, 119, 120, 121, 123, 125, 127,
    },
}

-- Build reverse lookup: zone mapId -> continent mapId
local ZONE_TO_CONTINENT = {}
for continentId, zones in pairs(CONTINENT_ZONES) do
    for _, zoneId in ipairs(zones) do
        ZONE_TO_CONTINENT[zoneId] = continentId
    end
end

-- Check if a zone mapId belongs to the currently viewed map (or is a child of it)
local function IsMapIdVisibleOn(locMapId, viewedMapId)
    if locMapId == viewedMapId then return true end
    -- Check if viewedMapId is a continent containing locMapId
    local zones = CONTINENT_ZONES[viewedMapId]
    if zones then
        for _, z in ipairs(zones) do
            if z == locMapId then return true end
        end
    end
    return false
end

-- Scan NPC database for available quests on a given map (expensive, results are cached)
function QM:ScanAvailableQuestsForMap(currentMapId)
    local DB = QM.DB
    if not DB or not DB.npcData then return {} end

    local playerLevel = UnitLevel("player")
    local playerFaction = UnitFactionGroup("player")
    local factionLetter = playerFaction == "Alliance" and "A" or "H"
    local playerRace = select(2, UnitRace("player"))
    local playerClass = select(2, UnitClass("player"))

    local results = {}
    local addedQuests = {}

    for npcId, npcData in pairs(DB.npcData) do
        local questStarts = npcData[DB.npcKeys.questStarts]
        if questStarts then
            local spawns = npcData[DB.npcKeys.spawns]
            local friendly = npcData[DB.npcKeys.friendlyToFaction]

            if not friendly or friendly:find(factionLetter) then
                if spawns then
                    for zoneId, coords in pairs(spawns) do
                        local mapId = DB:GetZoneMapId(zoneId)
                        if IsMapIdVisibleOn(mapId, currentMapId) and coords[1] then
                            for _, questId in ipairs(questStarts) do
                                if not addedQuests[questId] then
                                    local questData = DB.questData[questId]
                                    if questData and not self:IsQuestCompleted(questId) and not self:IsQuestActive(questId) then
                                        if self:CanAcceptQuest(questData, playerLevel, playerFaction, playerRace, playerClass) then
                                            local questLevel = questData[DB.questKeys.questLevel] or 1
                                            local coord = coords[1]
                                            table.insert(results, {
                                                questId = questId,
                                                x = coord[1] / 100,
                                                y = coord[2] / 100,
                                                mapId = mapId,
                                                title = questData[DB.questKeys.name] or "Unknown Quest",
                                                level = questLevel,
                                            })
                                            addedQuests[questId] = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return results
end

function QM:InvalidateAvailableQuestCache()
    wipe(availableQuestCache)
    wipe(availableQuestCacheTime)
end

function QM:AddAvailableQuestPins(currentMapId, scale, alpha)
    -- Use cached scan results to avoid iterating all NPCs every update
    local now = GetTime()
    local cached = availableQuestCache[currentMapId]
    if not cached or not availableQuestCacheTime[currentMapId]
       or (now - availableQuestCacheTime[currentMapId]) > AVAILABLE_QUEST_CACHE_TTL then
        cached = self:ScanAvailableQuestsForMap(currentMapId)
        availableQuestCache[currentMapId] = cached
        availableQuestCacheTime[currentMapId] = now
    end

    for _, data in ipairs(cached) do
        -- Re-check dynamic state (quest may have been accepted since cache)
        if not self:IsQuestCompleted(data.questId) and not self:IsQuestActive(data.questId) then
            local pin = self:GetWorldMapPin()
            pin:SetSize(PIN_SIZE_AVAILABLE, PIN_SIZE_AVAILABLE)
            pin.pinData = {
                questId = data.questId,
                x = data.x,
                y = data.y,
                mapId = data.mapId,
                title = data.title,
                level = data.level,
                pinType = "available",
            }

            pin.icon:SetTexture(ICON_AVAILABLE_QUEST)
            pin.icon:SetVertexColor(1, 1, 1, 1)
            pin.icon:SetTexCoord(0, 1, 0, 1)

            pin:SetScale(scale * 1.1)
            pin:SetAlpha(alpha)

            if HBDPins then
                HBDPins:AddWorldMapIconMap("QuestMaster", pin, data.mapId, data.x, data.y, 3)
            end

            pin:Show()
            table.insert(activeWorldPins, pin)
        end
    end
end

-- ============================================================================
-- Fixed Quest Objective Location Retrieval
-- ============================================================================

-- Cache invalidation function (call when quest objectives change)
function QM:InvalidateQuestLocationCache(questId)
    if questId then
        questLocationCache[questId] = nil
        questLocationCacheTime[questId] = nil
    else
        -- Clear entire cache
        wipe(questLocationCache)
        wipe(questLocationCacheTime)
    end
end

function QM:GetQuestObjectiveLocationsFixed(questId)
    if not questId then return nil end
    if not self.databaseReady then return nil end

    local quest = self.activeQuests and self.activeQuests[questId]
    if not quest then return nil end

    -- Check cache first (valid for 30 seconds)
    local now = GetTime()
    if questLocationCache[questId] and questLocationCacheTime[questId] then
        if now - questLocationCacheTime[questId] < 30 then
            return questLocationCache[questId]
        end
    end

    local dbQuest = QM.DB and QM.DB:GetQuest(questId)
    if not dbQuest then
        local result = QM.DB and QM.DB:GetQuestObjectiveLocations(questId)
        questLocationCache[questId] = result
        questLocationCacheTime[questId] = now
        return result
    end

    local locations = {}
    local dbObjectives = dbQuest.objectives

    local allCreatureSpawns = {}
    local allObjectSpawns = {}
    local allItemSpawns = {}

    if dbObjectives then
        if dbObjectives[1] then
            for _, obj in ipairs(dbObjectives[1]) do
                local creatureId = obj[1]
                if creatureId then
                    local spawns = QM.DB:GetNPCSpawnLocations(creatureId)
                    if spawns and #spawns > 0 then
                        table.insert(allCreatureSpawns, {spawns = spawns, used = false, id = creatureId})
                    end
                end
            end
        end

        if dbObjectives[2] then
            for _, obj in ipairs(dbObjectives[2]) do
                local objectId = obj[1]
                if objectId then
                    local spawns = QM.DB:GetObjectSpawnLocations(objectId)
                    if spawns and #spawns > 0 then
                        table.insert(allObjectSpawns, {spawns = spawns, used = false, id = objectId})
                    end
                end
            end
        end

        if dbObjectives[3] then
            for _, obj in ipairs(dbObjectives[3]) do
                local itemId = obj[1]
                if itemId then
                    local spawns = QM.DB:GetItemSourceLocations(itemId)
                    if spawns and #spawns > 0 then
                        table.insert(allItemSpawns, {spawns = spawns, used = false, id = itemId})
                    end
                end
            end
        end
    end

    for i, gameObj in ipairs(quest.objectives) do
        local objType = gameObj.type

        if objType == "monster" or objType == "kill" then
            for _, entry in ipairs(allCreatureSpawns) do
                if not entry.used and entry.spawns and #entry.spawns > 0 then
                    locations[i] = entry.spawns
                    entry.used = true
                    break
                end
            end
        elseif objType == "object" then
            for _, entry in ipairs(allObjectSpawns) do
                if not entry.used and entry.spawns and #entry.spawns > 0 then
                    locations[i] = entry.spawns
                    entry.used = true
                    break
                end
            end
        elseif objType == "item" then
            for _, entry in ipairs(allItemSpawns) do
                if not entry.used and entry.spawns and #entry.spawns > 0 then
                    locations[i] = entry.spawns
                    entry.used = true
                    break
                end
            end
        end

        -- Fallbacks
        if not locations[i] or #locations[i] == 0 then
            for _, entry in ipairs(allItemSpawns) do
                if not entry.used and entry.spawns and #entry.spawns > 0 then
                    locations[i] = entry.spawns
                    entry.used = true
                    break
                end
            end
        end

        if not locations[i] or #locations[i] == 0 then
            for _, entry in ipairs(allCreatureSpawns) do
                if not entry.used and entry.spawns and #entry.spawns > 0 then
                    locations[i] = entry.spawns
                    entry.used = true
                    break
                end
            end
        end

        if not locations[i] or #locations[i] == 0 then
            for _, entry in ipairs(allObjectSpawns) do
                if not entry.used and entry.spawns and #entry.spawns > 0 then
                    locations[i] = entry.spawns
                    entry.used = true
                    break
                end
            end
        end
    end

    -- Check triggerEnd
    if dbQuest.triggerEnd and dbQuest.triggerEnd[2] then
        local triggerLocs = {}
        for zoneId, coords in pairs(dbQuest.triggerEnd[2]) do
            local mapId = QM.DB:GetZoneMapId(zoneId)
            if mapId and coords then
                for _, coord in ipairs(coords) do
                    if coord[1] and coord[2] then
                        table.insert(triggerLocs, {x = coord[1] / 100, y = coord[2] / 100, mapId = mapId})
                    end
                end
            end
        end
        if #triggerLocs > 0 then
            for i = 1, #quest.objectives do
                if not locations[i] or #locations[i] == 0 then
                    locations[i] = triggerLocs
                end
            end
        end
    end

    -- Check extraObjectives
    if dbQuest.extraObjectives then
        for _, extra in ipairs(dbQuest.extraObjectives) do
            if extra[1] then
                local extraLocs = {}
                for zoneId, coords in pairs(extra[1]) do
                    local mapId = QM.DB:GetZoneMapId(zoneId)
                    if mapId and coords then
                        for _, coord in ipairs(coords) do
                            if coord[1] and coord[2] then
                                table.insert(extraLocs, {x = coord[1] / 100, y = coord[2] / 100, mapId = mapId})
                            end
                        end
                    end
                end
                if #extraLocs > 0 then
                    for i = 1, #quest.objectives do
                        if not locations[i] or #locations[i] == 0 then
                            locations[i] = extraLocs
                            break
                        end
                    end
                end
            end
        end
    end

    -- Final fallback
    local hasAnyLocations = false
    for i = 1, #quest.objectives do
        if locations[i] and #locations[i] > 0 then
            hasAnyLocations = true
            break
        end
    end

    if not hasAnyLocations then
        local startLocs = QM.DB:GetQuestStartLocations(questId)
        if startLocs and #startLocs > 0 then
            for i = 1, #quest.objectives do
                if not locations[i] or #locations[i] == 0 then
                    locations[i] = startLocs
                end
            end
        end
    end

    -- Cache the result
    questLocationCache[questId] = locations
    questLocationCacheTime[questId] = now

    return locations
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

function QM:IsQuestCompleted(questId)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(questId)
    end
    if IsQuestFlaggedCompleted then
        return IsQuestFlaggedCompleted(questId)
    end
    return false
end

function QM:IsQuestActive(questId)
    return self.activeQuests and self.activeQuests[questId] ~= nil
end

-- ============================================================================
-- Minimap Pins
-- ============================================================================

function QM:UpdateMinimapPins()
    if not QM.db.profile.map.enableMinimap then
        self:ClearMinimapPins()
        return
    end

    for _, pin in ipairs(activeMinimapPins) do
        self:ReleaseMinimapPin(pin)
    end
    wipe(activeMinimapPins)

    local scale = (QM.db.profile.map.pinScale or 1) * 0.7
    local alpha = QM.db.profile.map.pinAlpha or 1

    for questId, quest in pairs(self.activeQuests or {}) do
        if not quest.isComplete then
            local dbLocations = self:GetQuestObjectiveLocationsFixed(questId)
            if dbLocations then
                for i, objective in ipairs(quest.objectives) do
                    if not objective.finished and dbLocations[i] then
                        local closestLoc, closestDist = nil, math.huge

                        for _, loc in ipairs(dbLocations[i]) do
                            local dist = self:GetDistanceToPoint(loc.x, loc.y, loc.mapId)
                            if dist and dist < closestDist then
                                closestDist = dist
                                closestLoc = loc
                            end
                        end

                        if closestLoc then
                            local pin = self:GetMinimapPin()
                            pin:SetSize(MINIMAP_PIN_SIZE, MINIMAP_PIN_SIZE)
                            pin.pinData = {
                                questId = questId,
                                objectiveIndex = i,
                                x = closestLoc.x,
                                y = closestLoc.y,
                                mapId = closestLoc.mapId,
                                title = quest.title,
                                description = objective.text,
                            }

                            if objective.type == "monster" or objective.type == "kill" then
                                pin.icon:SetTexture(ICON_OBJECTIVE_SKULL)
                                pin.icon:SetVertexColor(1, 0.3, 0.3, 1)
                            else
                                pin.icon:SetTexture(ICON_OBJECTIVE_DOT)
                                pin.icon:SetVertexColor(1, 1, 0, 1)
                            end

                            pin:SetScale(scale)
                            pin:SetAlpha(alpha)

                            if HBDPins then
                                HBDPins:AddMinimapIconMap("QuestMaster", pin, closestLoc.mapId, closestLoc.x, closestLoc.y, false, false)
                            end

                            pin:Show()
                            table.insert(activeMinimapPins, pin)
                        end
                    end
                end
            end
        else
            local turnInLocs = QM.DB and QM.DB:GetQuestTurnInLocations(questId)
            if turnInLocs and turnInLocs[1] then
                local loc = turnInLocs[1]
                local pin = self:GetMinimapPin()
                pin:SetSize(MINIMAP_PIN_SIZE + 2, MINIMAP_PIN_SIZE + 2)
                pin.pinData = {
                    questId = questId,
                    x = loc.x,
                    y = loc.y,
                    mapId = loc.mapId,
                    title = quest.title .. " (Turn In)",
                    description = "Turn in quest",
                }

                pin.icon:SetTexture(ICON_TURNIN_QUEST)
                pin.icon:SetVertexColor(1, 1, 1, 1)

                pin:SetScale(scale)
                pin:SetAlpha(alpha)

                if HBDPins then
                    HBDPins:AddMinimapIconMap("QuestMaster", pin, loc.mapId, loc.x, loc.y, false, false)
                end

                pin:Show()
                table.insert(activeMinimapPins, pin)
            end
        end
    end
end

-- ============================================================================
-- Cleanup
-- ============================================================================

function QM:ClearWorldMapPins()
    for _, pin in ipairs(activeWorldPins) do
        self:ReleaseWorldMapPin(pin)
    end
    wipe(activeWorldPins)

    for _, blob in ipairs(activeAreaBlobs) do
        self:ReleaseAreaBlob(blob)
    end
    wipe(activeAreaBlobs)

    for _, zone in ipairs(activeDangerZones) do
        self:ReleaseDangerZone(zone)
    end
    wipe(activeDangerZones)

    for _, line in ipairs(activePatrolLines) do
        self:ReleasePatrolLine(line)
    end
    wipe(activePatrolLines)
end

function QM:ClearMinimapPins()
    for _, pin in ipairs(activeMinimapPins) do
        self:ReleaseMinimapPin(pin)
    end
    wipe(activeMinimapPins)
end

function QM:ClearAllMapPins()
    self:ClearWorldMapPins()
    self:ClearMinimapPins()
end

function QM:UpdateMapPinSettings()
    self:UpdateMapPins()
end
