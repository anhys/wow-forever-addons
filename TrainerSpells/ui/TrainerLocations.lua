local _, TrainerSpells = ...
local TrainerLocations = {}
TrainerSpells.TrainerLocations = TrainerLocations
local localeAliases = {enGB = "enUS"}
local factionTokens = {Alliance = "A", Horde = "H"}
local creatureInfo = {cache = {}, tries = {}, listeners = {}, scheduled = false}

function TrainerLocations.AddResolveListener(callback)
    table.insert(creatureInfo.listeners, callback)
end

local function IsUsableText(text)
    if issecretvalue and issecretvalue(text) then return false end
    return type(text) == "string" and text ~= "" and text ~= RETRIEVING_DATA and text ~= RETRIEVING_ITEM_INFO
end

local function ReadCreatureTooltip(npcID)
    local link = "unit:Creature-0-0-0-0-" .. npcID .. "-0000000000"
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
        local lines = ok and type(data) == "table" and data.lines
        if lines and lines[1] then return lines[1].leftText, lines[2] and lines[2].leftText end
    end

    if not creatureInfo.tooltip then creatureInfo.tooltip = CreateFrame("GameTooltip", "TrainerSpellsCreatureScanTooltip", UIParent, "GameTooltipTemplate") end
    local tooltip = creatureInfo.tooltip
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:ClearLines()
    pcall(tooltip.SetHyperlink, tooltip, link)
    local first = _G.TrainerSpellsCreatureScanTooltipTextLeft1
    local second = _G.TrainerSpellsCreatureScanTooltipTextLeft2
    local name = first and first:GetText()
    local subtitle = second and second:GetText()
    tooltip:Hide()
    return name, subtitle
end

local function ScheduleRetry()
    if creatureInfo.scheduled or not C_Timer then return end
    creatureInfo.scheduled = true
    C_Timer.After(1, function()
        creatureInfo.scheduled = false
        for _, callback in ipairs(creatureInfo.listeners) do callback() end
    end)
end

function TrainerLocations.GetCreatureInfo(npcID)
    if type(npcID) ~= "number" then return nil end
    local cached = creatureInfo.cache[npcID]
    if cached then return cached end
    if IsInInstance() then return nil end
    local tries = creatureInfo.tries[npcID] or 0
    if tries >= 3 then return nil end
    creatureInfo.tries[npcID] = tries + 1
    local name, subtitle = ReadCreatureTooltip(npcID)
    if not IsUsableText(name) then
        ScheduleRetry()
        return nil
    end

    if not IsUsableText(subtitle) or subtitle:find("%d") then subtitle = nil end
    cached = {name = name, subtitle = subtitle}
    creatureInfo.cache[npcID] = cached
    return cached
end

local function GetLocalized(values)
    if not values then return nil end
    local locale = localeAliases[GetLocale()] or GetLocale()
    return values[locale] or values.enUS
end

local function GetTrainerName(trainer)
    local info = TrainerLocations.GetCreatureInfo(trainer.npcID)
    return info and info.name or GetLocalized(trainer.names)
end

local function GetTrainerTag(trainer)
    if not trainer.tags then return nil end
    local info = TrainerLocations.GetCreatureInfo(trainer.npcID)
    return info and info.subtitle or GetLocalized(trainer.tags)
end

local continentCache = {}
local function GetContinent(uiMapID)
    if continentCache[uiMapID] then return continentCache[uiMapID] end
    local continentType = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
    local stopType = Enum and Enum.UIMapType and Enum.UIMapType.World or 1
    local info = C_Map.GetMapInfo(uiMapID)
    local fallback = info
    while info do
        if info.mapType == continentType then break end
        local parent = info.parentMapID and info.parentMapID ~= 0 and C_Map.GetMapInfo(info.parentMapID)
        if not parent or parent.mapType <= stopType then
            info = nil
        else
            fallback = parent
            info = parent
        end
    end
    local continent = info or fallback
    local result = {id = continent and continent.mapID or uiMapID, name = continent and continent.name or tostring(uiMapID)}
    continentCache[uiMapID] = result
    return result
end

local function BuildEntry(trainer, location, petLabel)
    local continent = GetContinent(location.uiMapID)
    return {
        continentID = continent.id,
        continentName = continent.name,
        displayID = trainer.displayID,
        location = location,
        name = GetTrainerName(trainer),
        npcID = trainer.npcID,
        starter = trainer.starter,
        petLabel = petLabel or GetTrainerTag(trainer),
        rank = trainer.rank,
        zoneName = C_Map.GetAreaInfo(location.areaID) or tostring(location.areaID),
    }
end

function TrainerLocations.AddEntries(entries, trainers, searchText, usableOnly, petLabel)
    local faction = factionTokens[UnitFactionGroup("player")]
    local level = UnitLevel("player") or 1
    local hideStarter = TrainerSpells_Character.hideStarterClassTrainers
    for _, trainer in ipairs(trainers or {}) do
        local matchesFaction = faction and trainer.faction:find(faction, 1, true)
        local isUsable = not trainer.starter or level < 8
        local isVisible = usableOnly or not hideStarter or not trainer.starter
        if matchesFaction and isVisible and (not usableOnly or isUsable) then
            for _, location in ipairs(trainer.locations) do
                local entry = BuildEntry(trainer, location, petLabel)
                local searchable = (entry.name .. " " .. entry.zoneName .. " " .. entry.continentName .. " " .. (entry.petLabel or "")):lower()
                if searchText == "" or searchable:find(searchText, 1, true) then table.insert(entries, entry) end
            end
        end
    end
end

function TrainerLocations.SortEntries(entries)
    table.sort(entries, function(a, b)
        if a.continentName ~= b.continentName then return a.continentName < b.continentName end
        if a.continentID ~= b.continentID then return a.continentID < b.continentID end
        if a.zoneName ~= b.zoneName then return a.zoneName < b.zoneName end
        if (a.petLabel ~= nil) ~= (b.petLabel ~= nil) then return a.petLabel == nil end
        return a.name < b.name
    end)
    return entries
end

function TrainerSpells:GetTrainerLocationEntries(trainers, searchText, usableOnly)
    local entries = {}
    TrainerLocations.AddEntries(entries, trainers, searchText, usableOnly)
    return TrainerLocations.SortEntries(entries)
end

function TrainerSpells:AddTrainerLocationItems(items, entries, groupPrefix, baseDepth)
    baseDepth = baseDepth or 0
    local lastContinentID
    local lastAreaID
    for _, entry in ipairs(entries) do
        local continentKey = groupPrefix .. "continent_" .. entry.continentID
        if entry.continentID ~= lastContinentID then
            lastContinentID = entry.continentID
            lastAreaID = nil
            TrainerSpells:AddHeaderItem(items, entry.continentName, baseDepth == 0 and "|cffffd100" or "|cffffffff", nil, continentKey, nil, nil, baseDepth > 0 and baseDepth or nil)
        end
        if not TrainerSpells:IsGroupCollapsed(continentKey) then
            if entry.location.areaID ~= lastAreaID then
                lastAreaID = entry.location.areaID
                TrainerSpells:AddHeaderItem(items, entry.zoneName, baseDepth == 0 and "|cffffffff" or "|cffcccccc", nil, groupPrefix .. lastAreaID, nil, nil, baseDepth + 1)
            end
            if not TrainerSpells:IsGroupCollapsed(groupPrefix .. lastAreaID) then
                table.insert(items, {isClassTrainer = true, entry = entry, rowDepth = baseDepth + 1})
            end
        end
    end
end

local function GetWorldPosition(uiMapID, x, y)
    if not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return nil end
    local continentID, position = C_Map.GetWorldPosFromMapPos(uiMapID, CreateVector2D(x / 100, y / 100))
    if not continentID or not position then return nil end
    return continentID, position
end

function TrainerLocations.FindNearest(entries)
    if not C_Map.GetWorldPosFromMapPos then return nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    local mapPosition = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not mapID or not mapPosition then return nil end
    local playerContinent, playerWorld = C_Map.GetWorldPosFromMapPos(mapID, mapPosition)
    local nearest
    local nearestDistance
    for _, entry in ipairs(entries) do
        local location = entry.location
        local continentID, worldPosition = GetWorldPosition(location.uiMapID, location.x, location.y)
        if playerWorld and continentID == playerContinent and worldPosition then
            local dx = worldPosition.x - playerWorld.x
            local dy = worldPosition.y - playerWorld.y
            local distance = dx * dx + dy * dy
            if not nearestDistance or distance < nearestDistance then
                nearest = entry
                nearestDistance = distance
            end
        end
    end
    return nearest
end

function TrainerSpells:SetClassTrainerWaypoint(entry)
    if not entry or not entry.location then return false end
    local location = entry.location
    return TrainerSpells:SetMapWaypoint({
        uiMapID = location.uiMapID,
        x = location.x,
        y = location.y,
        npcName = entry.name,
    })
end

function TrainerLocations.SetNearestWaypoint(entry, noneKey)
    if entry and TrainerSpells:SetClassTrainerWaypoint(entry) then
        TrainerSpells:MSG((TrainerSpells:Trans("LID_WAYPOINTFOR")):format(entry.name, entry.zoneName, entry.location.x, entry.location.y))
    else
        TrainerSpells:MSG(TrainerSpells:Trans(noneKey))
    end
end
