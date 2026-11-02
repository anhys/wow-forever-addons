ForeverNameplates = ForeverNameplates or {}
ForeverNameplates.plates = ForeverNameplates.plates or {}

local addon = ForeverNameplates

addon.defaults = {
    appearance = {
        size = 1,
        style = 0, -- Last selected native style
        initialized = false,
    },
    threat = {
        secure  = {25/255, 1.00, 0.00}, -- #19FF00
        warning = {1.00, 0.75, 0.00},
        lost    = {1.00, 29/255, 29/255}, -- #FF1D1D
    },
    disableRoleColors = true, -- Auto-Switch Role Colors starts off on fresh installs.
    keepNonTargetsBright = true,
    threatDifferential = true,
    threatDisplayMode = "differential",
    threatDifferentialTankOnly = false,
    threatFlash = true,
    threatSnapshotSeconds = 5,
    threatDifferentialSize = 23,
    compatibilityMode = false,
    showMobLevel = true,
    nativeCCWorkaround = true,
    questColor = {1, 156/255, 0}, -- #FF9C00
    disableQuestColor = false,
    pvpColor = {1, 29/255, 29/255}, -- #FF1D1D
    pvpClassColors = true,
    questMarker = true,
    questIconSize = 24,
    questIconPosition = {x = -6, y = 0},
    threatPosition = {x = -8, y = -1},
    targetPosition = {x = -5, y = 2},
    dungeonRaidThreat = {
        tank = {
            secure  = {25/255, 1.00, 0.00}, -- #19FF00
            warning = {1.00, 220/255, 0.00}, -- #FFDC00
            lost    = {1.00, 29/255, 29/255}, -- #FF1D1D
        },
        nonTank = {
            secure  = {0.55, 0.20, 0.80}, -- Have Aggro = purple
            warning = {1.00, 0.75, 0.00}, -- Warning = yellow
            lost    = {1.00, 29/255, 29/255}, -- No Aggro = #FF1D1D
        },
    },
    targetBorder = {1.00, 1.00, 1.00}, -- untinted Blizzard Selected-yellow artwork
    minimap = {
        angle = 225,
        visible = true,
    },
    targetNames = {
        fullName = false,
        enabled = true,
        friendly = true,
    },
    mobName = {
        fontSize = 11,
        enabled = true,
    },
    healthText = {
        percentSize = 12,
        valueSize = 12,
        percentEnabled = true,
        valueEnabled = true,
    },
    atdHealthText = {
        percentEnabled = true,
        valueEnabled = false,
    },
    castbar = {
        enabled = true,
        width = 130,
        height = 13,
        offsetY = -3,
        nameSize = 9,
        timeSize = 8,
        showName = true,
        showTime = true,
        interruptibleColor = {0.68, 0.55, 0.06},
        protectedColor = {0.50, 0.50, 0.50},
    },
    auras = {
        pve = {
            enabled = true,
            ownDebuffs = true,
            crowdControl = true,
            ownCrowdControl = false,
            iconSize = 24,
            crowdControlSize = 30,
            maxDebuffs = 6,
            maxCrowdControl = 3,
            maxOwnCrowdControl = 3,
            spacing = 2,
        },
        pvp = {
            enabled = true,
            ownDebuffs = true,
            ownCrowdControl = true,
            otherCrowdControl = true,
            iconSize = 24,
            crowdControlSize = 30,
            maxDebuffs = 6,
            maxOwnCrowdControl = 3,
            maxOtherCrowdControl = 3,
            spacing = 2,
        },
    },
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end


local pendingCVars = {}
local cvarRetry
function addon:GetNameplateCVar(name)
    if pendingCVars[name] ~= nil then return pendingCVars[name] end
    return GetCVar(name)
end
function addon:SetNameplateCVar(name, value)
    if InCombatLockdown() then
        pendingCVars[name] = value
        if not cvarRetry then
            cvarRetry = CreateFrame("Frame")
            cvarRetry:SetScript("OnEvent", function(self)
                if InCombatLockdown() then return end
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                for key, desired in pairs(pendingCVars) do
                    pendingCVars[key] = nil
                    addon:SetNameplateCVar(key, desired)
                end
            end)
        end
        cvarRetry:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    pendingCVars[name] = nil
    if tonumber(GetCVar(name)) ~= tonumber(value) then SetCVar(name, value) end
end

local function ClampNumber(value, low, high, fallback)
    value = tonumber(value) or fallback
    return math.max(low, math.min(high, value))
end

function addon:GetATDCastbarSettings()
    local db = ForeverNameplatesDB or addon.defaults
    if self.IsJundiesStyle and self:IsJundiesStyle() then
        local settings=db.jundiesCastbar or {}
        CopyDefaults(self:GetJundiesCastbarDefaults(),settings)
        if ForeverNameplatesDB then ForeverNameplatesDB.jundiesCastbar=settings end
        return settings
    end
    return db.castbar or addon.defaults.castbar
end

function addon:SetATDCastbarSetting(key, value)
    if InCombatLockdown() then return false end
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    local settings = ForeverNameplatesDB.castbar
    local defaults=addon.defaults.castbar
    if self.IsJundiesStyle and self:IsJundiesStyle() then
        defaults=self:GetJundiesCastbarDefaults()
        ForeverNameplatesDB.jundiesCastbar=ForeverNameplatesDB.jundiesCastbar or {}
        settings=ForeverNameplatesDB.jundiesCastbar; CopyDefaults(defaults,settings)
    end
    if key == "enabled" or key == "showName" or key == "showTime" then
        settings[key] = value and true or false
    elseif key == "width" then settings[key] = ClampNumber(value, 90, 220, defaults.width)
    elseif key == "height" then settings[key] = ClampNumber(value, 8, 24, defaults.height)
    elseif key == "offsetY" then settings[key] = ClampNumber(value, -20, 10, defaults.offsetY)
    elseif key == "nameSize" then settings[key] = ClampNumber(value, 7, 18, defaults.nameSize)
    elseif key == "timeSize" then settings[key] = ClampNumber(value, 7, 18, defaults.timeSize)
    elseif key == "interruptibleColor" or key == "protectedColor" then
        if type(value) == "table" then settings[key] = {value[1] or 1, value[2] or 1, value[3] or 1} end
    else return end
    if self.RefreshATDStyle then self:RefreshATDStyle() end
    return true
end

function addon:ResetATDCastbarSettings()
    if InCombatLockdown() then return false end
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    local key=self.IsJundiesStyle and self:IsJundiesStyle() and "jundiesCastbar" or "castbar"
    ForeverNameplatesDB[key] = {}
    CopyDefaults(key=="jundiesCastbar" and self:GetJundiesCastbarDefaults() or addon.defaults.castbar, ForeverNameplatesDB[key])
    if self.RefreshATDStyle then self:RefreshATDStyle() end
    return true
end

function addon:GetATDAuraSettings(context)
    context = context == "pvp" and "pvp" or "pve"
    local db = ForeverNameplatesDB or addon.defaults
    local auras = db.auras or addon.defaults.auras
    return auras[context] or addon.defaults.auras[context]
end

function addon:GetNativeAuraSettings(context)
    context = context == "pvp" and "pvp" or "pve"
    local settings = ForeverNameplatesDB and ForeverNameplatesDB.nativeAuras
    local saved=settings and settings[context]
    if saved then CopyDefaults(addon.defaults.auras[context],saved) end
    return saved or addon.defaults.auras[context]
end

function addon:SetNativeAuraSetting(context, key, value)
    if InCombatLockdown() then return false end
    context = context == "pvp" and "pvp" or "pve"
    local booleans = context == "pvp"
        and {enabled=true,ownDebuffs=true,ownCrowdControl=true,otherCrowdControl=true}
        or {enabled=true,ownDebuffs=true,crowdControl=true,ownCrowdControl=true}
    local bounds = {iconSize={16,36},crowdControlSize={20,44},spacing={0,10},
        maxDebuffs={0,12},maxCrowdControl={0,6},maxOwnCrowdControl={0,6},maxOtherCrowdControl={0,6}}
    if not booleans[key] and (not bounds[key] or addon.defaults.auras[context][key] == nil) then return false end
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    ForeverNameplatesDB.nativeAuras = ForeverNameplatesDB.nativeAuras or {}
    ForeverNameplatesDB.nativeAuras[context] = ForeverNameplatesDB.nativeAuras[context] or {}
    local settings = ForeverNameplatesDB.nativeAuras[context]
    CopyDefaults(addon.defaults.auras[context], settings)
    if booleans[key] then settings[key] = value and true or false
    else settings[key] = ClampNumber(value, bounds[key][1], bounds[key][2], addon.defaults.auras[context][key]) end
    if self.RefreshNativeCCFallbacks then self:RefreshNativeCCFallbacks() end
    return true
end

function addon:ResetNativeAuraSettings(context)
    if InCombatLockdown() then return false end
    context = context == "pvp" and "pvp" or "pve"
    if ForeverNameplatesDB and ForeverNameplatesDB.nativeAuras then ForeverNameplatesDB.nativeAuras[context] = nil end
    if self.RefreshNativeCCFallbacks then self:RefreshNativeCCFallbacks() end
    return true
end

function addon:SetATDAuraSetting(context, key, value)
    if InCombatLockdown() then return false end
    context = context == "pvp" and "pvp" or "pve"
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    local settings = ForeverNameplatesDB.auras[context]
    local booleanKeys = context == "pvp"
        and {enabled=true, ownDebuffs=true, ownCrowdControl=true, otherCrowdControl=true}
        or {enabled=true, ownDebuffs=true, crowdControl=true,ownCrowdControl=true}
    if booleanKeys[key] then settings[key] = value and true or false
    elseif key == "iconSize" then settings[key] = ClampNumber(value, 16, 36, addon.defaults.auras[context].iconSize)
    elseif key == "crowdControlSize" then settings[key] = ClampNumber(value, 20, 44, addon.defaults.auras[context].crowdControlSize)
    elseif key == "spacing" then settings[key] = ClampNumber(value, 0, 10, addon.defaults.auras[context].spacing)
    elseif key == "maxDebuffs" then settings[key] = ClampNumber(value, 0, 12, addon.defaults.auras[context].maxDebuffs)
    elseif key == "maxCrowdControl" then settings[key] = ClampNumber(value, 0, 6, addon.defaults.auras.pve.maxCrowdControl)
    elseif key == "maxOwnCrowdControl" then settings[key] = ClampNumber(value, 0, 6, addon.defaults.auras[context].maxOwnCrowdControl)
    elseif key == "maxOtherCrowdControl" then settings[key] = ClampNumber(value, 0, 6, addon.defaults.auras.pvp.maxOtherCrowdControl)
    else return end
    if self.RefreshATDStyle then self:RefreshATDStyle() end
    return true
end

function addon:ResetATDAuraSettings(context)
    if InCombatLockdown() then return false end
    context = context == "pvp" and "pvp" or "pve"
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    ForeverNameplatesDB.auras[context] = {}
    CopyDefaults(addon.defaults.auras[context], ForeverNameplatesDB.auras[context])
    if self.RefreshATDStyle then self:RefreshATDStyle() end
    return true
end

function addon:GetPlate(unit)
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        return C_NamePlate.GetNamePlateForUnit(unit)
    end
end

function addon:IsThreatNPC(unit)
    local player = UnitIsPlayer(unit)
    local controlled = UnitPlayerControlled and UnitPlayerControlled(unit)
    if issecretvalue and (issecretvalue(player) or issecretvalue(controlled)) then return false end
    return player == false and not controlled
end

local questObjectiveSources = {}
local emptyQuestSources = {}
local questLogSnapshot
local function IsSecretQuestValue(value)
    return issecretvalue and issecretvalue(value)
end

local function GetQuestLogSnapshot()
    local now = GetTime()
    if questLogSnapshot and now - questLogSnapshot.time < 5 then return questLogSnapshot end
    local titles, quests = {}, {}
    local count = 0
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then count = C_QuestLog.GetNumQuestLogEntries()
    elseif GetNumQuestLogEntries then count = GetNumQuestLogEntries() end
    if IsSecretQuestValue(count) or type(count) ~= "number" then count = 0 end
    for i = 1, count do
        local title, header, complete, questID
        if C_QuestLog and C_QuestLog.GetInfo then
            local info = C_QuestLog.GetInfo(i)
            if not IsSecretQuestValue(info) and type(info) == "table" then
                title, header, complete, questID = info.title, info.isHeader, info.isComplete, info.questID
            end
        elseif GetQuestLogTitle then
            local level, tag, collapsed
            title, level, tag, header, collapsed, complete = GetQuestLogTitle(i)
        end
        if not IsSecretQuestValue(title) and type(title) == "string"
            and not IsSecretQuestValue(header) and not header and not IsSecretQuestValue(complete) then
            if IsSecretQuestValue(questID) then questID = nil end
            local quest = {index=i, complete=complete == true or complete == 1, questID=questID}
            titles[title] = quest
            quests[#quests+1] = quest
        end
    end
    -- Only retain NPC associations for quests still in the log.
    for npc, known in pairs(questObjectiveSources) do
        for title in pairs(known) do if not titles[title] then known[title] = nil end end
        if not next(known) then questObjectiveSources[npc] = nil end
    end
    questLogSnapshot = {titles=titles, quests=quests, time=now}
    return questLogSnapshot
end

local function GetSnapshotObjectives(quest)
    if quest.objectives then return quest.objectives end
    local entries = quest.questID and C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(quest.questID)
    if IsSecretQuestValue(entries) then entries = {} end
    if entries ~= nil and type(entries) ~= "table" then entries = {} end
    if not entries then
        entries = {}
        local count = 0
        if GetNumQuestLeaderBoards then count = GetNumQuestLeaderBoards(quest.index) end
        if IsSecretQuestValue(count) or type(count) ~= "number" then count = 0 end
        for i=1,count do
            local text, objectiveType, done = GetQuestLogLeaderBoard(i, quest.index)
            entries[i] = {text=text, finished=done}
        end
    end
    quest.objectives = entries
    return entries
end

local function GetObjectiveState(quest, objective)
    if quest.complete then return "complete" end
    for _, entry in ipairs(GetSnapshotObjectives(quest)) do
        if not IsSecretQuestValue(entry) and type(entry) == "table" then
            local description, done = entry.text, entry.finished
            if not IsSecretQuestValue(description) and type(description) == "string"
                and not IsSecretQuestValue(done) and objective ~= ""
                and description:find(objective, 1, true) then
                if done == true or done == 1 then return "complete" end
                if done == false or done == 0 then return "incomplete" end
            end
        end
    end
end

local function TooltipHasQuestObjective(unit)
    local titles = GetQuestLogSnapshot().titles
    if not next(titles) then return false end
    local lines = {}
    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
        if ok and not IsSecretQuestValue(data) and type(data) == "table"
            and not IsSecretQuestValue(data.lines) and type(data.lines) == "table" then
            for _, line in ipairs(data.lines) do
                if not IsSecretQuestValue(line) and type(line) == "table"
                    and not IsSecretQuestValue(line.leftText) and type(line.leftText) == "string" then
                    lines[#lines + 1] = line.leftText
                end
            end
        end
    end
    -- Never render a scanning tooltip as a fallback. GameTooltip:SetUnit runs
    -- Blizzard's health-bar post-call, which can pass a secret GUID into
    -- SetWatch from addon execution. pcall does not prevent that taint error.
    -- Missing/restricted text leaves the quest-log and unit-query fallbacks
    -- below available without creating any tooltip widgets.
    local guid = UnitGUID(unit)
    local npc = not IsSecretQuestValue(guid) and type(guid) == "string" and guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    local known = npc and questObjectiveSources[npc] or emptyQuestSources
    local ownQuest
    local finished = false
    for _, value in ipairs(lines) do
        local text = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        if titles[text] then ownQuest = text end
        if ownQuest then
            local current, total = text:match("(%d+)%s*/%s*(%d+)")
            if current and total then
                local objective = text:gsub("%d+%s*/%s*%d+", ""):gsub("^%s*", ""):gsub("[%s:]+$", "")
                if known == emptyQuestSources then
                    known = {}
                    if npc then questObjectiveSources[npc] = known end
                end
                known[ownQuest] = known[ownQuest] or {}
                known[ownQuest][objective] = true
                -- Quest-log progress takes priority over a tooltip that has
                -- not yet caught up with completion on this frame.
                local state = GetObjectiveState(titles[ownQuest], objective)
                if state == "incomplete" then return state end
                if state ~= "complete" and tonumber(current) < tonumber(total) then return "incomplete" end
                finished = true
            end
        end
    end
    -- Tooltips often stop listing an objective once it is complete. Keep the
    -- NPC/objective associations learned this session and consult the quest log.
    for title, objectives in pairs(known) do
        local quest = titles[title]
        if quest then
            for objective in pairs(objectives) do
                local state = GetObjectiveState(quest, objective)
                if state == "incomplete" then return state end
                if state == "complete" then finished = true end
            end
        end
    end
    return finished and "complete" or false
end

local questMobCache = {}
function addon:ClearQuestMobCache(unit)
    if unit then questMobCache[unit] = nil
    else
        for key in pairs(questMobCache) do questMobCache[key] = nil end
        questLogSnapshot = nil
    end
end

function addon:GetQuestObjectiveState(unit)
    local cached = questMobCache[unit]
    local now = GetTime()
    local ok,guid=pcall(UnitGUID,unit)
    if not ok or IsSecretQuestValue(guid) or type(guid)~="string" then guid=nil end
    -- Unit tokens are recycled, especially "target". Never let one mob's
    -- cached quest status follow that token onto a different creature.
    if cached and guid and cached.guid==guid and now - cached.time < (cached.value and 5 or 1) then return cached.value end
    local value = self:DetectQuestMob(unit)
    cached = cached or {}
    cached.value, cached.time, cached.guid = value, now, guid
    questMobCache[unit] = cached
    return value
end

function addon:IsQuestMob(unit)
    return self:GetQuestObjectiveState(unit) == "incomplete"
end

function addon:DetectQuestMob(unit)
    if not self:IsThreatNPC(unit) then return false end
    local snapshot = GetQuestLogSnapshot()
    if not next(snapshot.titles) then return false end
    local tooltipState = TooltipHasQuestObjective(unit)
    if tooltipState then return tooltipState end
    if UnitIsQuestBoss then
        local ok, value = pcall(UnitIsQuestBoss, unit)
        if ok and not (issecretvalue and issecretvalue(value)) and value == true then return "incomplete" end
    end
    if C_QuestLog and C_QuestLog.IsUnitOnQuest then
        for _, quest in ipairs(snapshot.quests) do
            if not quest.complete and quest.questID then
                local ok, value = pcall(C_QuestLog.IsUnitOnQuest, unit, quest.questID)
                if ok and not (issecretvalue and issecretvalue(value)) and value == true then return "incomplete" end
            end
        end
    end
    return false
end

function addon:GetQuestColorEnabled()
    if self.GetCompatibilityFeatureEnabled and self:GetCompatibilityMode() then return self:GetCompatibilityFeatureEnabled("questColor") end
    return not (ForeverNameplatesDB and ForeverNameplatesDB.disableQuestColor == true)
end

function addon:SetQuestColorEnabled(enabled)
    if self.SetCompatibilityFeatureEnabled and self:SetCompatibilityFeatureEnabled("questColor", enabled) then return end
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    ForeverNameplatesDB.disableQuestColor = not enabled
    if self.RefreshThreatColors then self:RefreshThreatColors() end
    if self.RefreshATDStyle then self:RefreshATDStyle() end
end

function addon:ShouldColorQuestMob(unit)
    if not self:GetQuestColorEnabled() then return false end
    local fighting = UnitAffectingCombat(unit)
    if IsSecretQuestValue(fighting) or fighting then return false end
    return self:IsQuestMob(unit)
end

local questEvents = CreateFrame("Frame")
local questRefreshPending
questEvents:RegisterEvent("QUEST_LOG_UPDATE")
questEvents:RegisterEvent("QUEST_ACCEPTED")
questEvents:RegisterEvent("QUEST_REMOVED")
questEvents:RegisterEvent("QUEST_TURNED_IN")
questEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
questEvents:SetScript("OnEvent", function(_,event)
    if event=="PLAYER_TARGET_CHANGED" then addon:ClearQuestMobCache("target"); return end
    addon:ClearQuestMobCache()
    -- Several quest events can occur together. Refresh once next frame, after
    -- Blizzard updates its quest log and tooltip data, even with icons off.
    if questRefreshPending then return end
    questRefreshPending = true
    C_Timer.After(0, function()
        questRefreshPending = nil
        addon:ClearQuestMobCache()
        if addon.RefreshThreatColors then addon:RefreshThreatColors() end
        if addon.RefreshATDStyle and addon:IsATDStyle() then addon:RefreshATDStyle() end
        if addon.RefreshQuestMarkers then addon:RefreshQuestMarkers() end
    end)
end)

function addon:GetQuestColor()
    local color = ForeverNameplatesDB and ForeverNameplatesDB.questColor or self.defaults.questColor
    return color[1], color[2], color[3]
end

function addon:GetUnitClassColor(unit)
    local _, class = UnitClass(unit)
    local secret = issecretvalue and issecretvalue(class)
    if not secret and type(class) ~= "string" then return end
    if C_ClassColor and C_ClassColor.GetClassColor then
        -- This native API accepts secret class tokens. Keep both the token
        -- and resulting RGB channels out of Lua table lookups/comparisons.
        local ok, color = pcall(C_ClassColor.GetClassColor, class)
        if ok and not (issecretvalue and issecretvalue(color)) and color then
            local r, g, b = color:GetRGB()
            return r, g, b, true
        end
    end
    if not secret then
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color then return color.r, color.g, color.b, true end
    end
end

function addon:GetEnemyPlayerClassColors()
    if self:IsATDStyle() then
        local db = ForeverNameplatesDB or self.defaults
        if db.pvpClassColors ~= nil then return db.pvpClassColors == true end
        return self.defaults.pvpClassColors == true
    end
    return tonumber(self:GetNameplateCVar("nameplateShowClassColor")) == 1
end

function addon:SetEnemyPlayerClassColors(enabled)
    if self:IsATDStyle() then
        ForeverNameplatesDB = ForeverNameplatesDB or {}
        ForeverNameplatesDB.pvpClassColors = enabled and true or false
    else
        -- Blizzard's Enemy Players choice. Its Friendly Players CVar is separate.
        self:SetNameplateCVar("nameplateShowClassColor", enabled and 1 or 0)
    end
    if self.RefreshThreatColors then self:RefreshThreatColors() end
    if self.RefreshATDStyle then self:RefreshATDStyle() end
end

function addon:GetPvPColor(unit)
    if unit then
        local player = UnitIsPlayer(unit)
        local hostile = UnitCanAttack("player", unit)
        if (issecretvalue and (issecretvalue(player) or issecretvalue(hostile))) or not player or not hostile then return end
        local classColors = self:GetEnemyPlayerClassColors()
        if not self:IsATDStyle() then
            -- UI may show a queued choice; live paints follow the applied CVar.
            classColors = tonumber(GetCVar("nameplateShowClassColor")) == 1
        end
        if classColors then
            -- Let Blizzard paint its own player class colors for native styles.
            if not self:IsATDStyle() then return end
            local r, g, b, colored = self:GetUnitClassColor(unit)
            if colored then return r, g, b, true end
        end
    end
    local color = ForeverNameplatesDB and ForeverNameplatesDB.pvpColor or self.defaults.pvpColor
    return color[1], color[2], color[3], true
end

function addon:GetCompatibilityMode()
    return ForeverNameplatesDB and ForeverNameplatesDB.compatibilityMode == true
end

function addon:GetCompatibilityFeatureEnabled(key)
    if not self:GetCompatibilityMode() then return true end
    local choices = ForeverNameplatesDB.compatibilityFeatures
    return type(choices) == "table" and choices[key] == true
end

function addon:GetCompatibilityFeatureState(key)
    if self:GetCompatibilityMode() then return self:GetCompatibilityFeatureEnabled(key) end
    -- The optional-feature switches also describe the normal mode after it
    -- is restored; permission to run is different from a saved enable choice.
    local readers = {targetNames="GetTargetNamesEnabled",questColor="GetQuestColorEnabled",
        questIcons="GetQuestMarkersEnabled",comboPoints="GetComboPointsEnabled",
        brightness="GetNonTargetsBright",threatFlash="GetThreatFlashEnabled",enemyDebuffs="GetNativeCCWorkaround"}
    if key == "enemyDebuffs" and self:IsATDStyle() and self.GetATDAuraSettings then
        return self:GetATDAuraSettings("pve").enabled == true or self:GetATDAuraSettings("pvp").enabled == true
    end
    local method = readers[key]
    if method and self[method] then return self[method](self) == true end
    return key == "threatColors" or key == "playerColors"
end

function addon:RefreshCompatibilityFeatures()
    for _, method in ipairs({"SyncNativeSpellTarget", "RefreshTargetNames", "RefreshQuestMarkers", "RefreshThreatColors",
        "RefreshATDStyle", "RefreshNativeCCFallbacks", "RefreshNameplateAttachments",
        "RefreshComboPoints", "ApplyFriendlyPlayerClassColors", "RefreshPlayerColors", "RefreshModernThreatControls"}) do
        if self[method] then self[method](self) end
    end
    if self.ApplyNonTargetBrightMode then self.ApplyNonTargetBrightMode() end
end

function addon:SetCompatibilityFeatureEnabled(key, enabled)
    if not self:GetCompatibilityMode() then return false end
    ForeverNameplatesDB.compatibilityFeatures = ForeverNameplatesDB.compatibilityFeatures or {}
    ForeverNameplatesDB.compatibilityFeatures[key] = enabled == true
    self:RefreshCompatibilityFeatures()
    return true
end

function addon:GetQuestMarkersEnabled()
    if self:GetCompatibilityMode() then return self:GetCompatibilityFeatureEnabled("questIcons") end
    return not ForeverNameplatesDB or ForeverNameplatesDB.questMarker ~= false
end

function addon:SetQuestMarkersEnabled(enabled)
    if self:SetCompatibilityFeatureEnabled("questIcons", enabled) then return end
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    ForeverNameplatesDB.questMarker = enabled == true
    if self.RefreshQuestMarkers then self:RefreshQuestMarkers() end
end

function addon:GetTargetNameDefaults()
    if self:IsATDStyle() then return 13, 3, 0 end
    return 12, -5, 2
end

local function TargetNameProfile(create)
    local names = ForeverNameplatesDB and ForeverNameplatesDB.targetNames
    if not names then return end
    local key = addon:IsATDStyle() and "ATD" or "Blizzard"
    if create then
        names.styleProfiles = names.styleProfiles or {}
        names.styleProfiles[key] = names.styleProfiles[key] or {}
    end
    return names.styleProfiles and names.styleProfiles[key]
end

function addon:GetOverlayPosition(kind)
    local saved, defaultX, defaultY
    if kind == "target" then
        local _
        _, defaultX, defaultY = self:GetTargetNameDefaults()
        saved = TargetNameProfile()
    else
        saved = ForeverNameplatesDB and ForeverNameplatesDB.threatPosition
        defaultX, defaultY = addon.defaults.threatPosition.x, addon.defaults.threatPosition.y
    end
    local x = saved and tonumber(saved.x) or defaultX
    local y = saved and tonumber(saved.y) or defaultY
    return math.max(-200, math.min(200, x)), math.max(-200, math.min(200, y))
end

function addon:SetOverlayPosition(kind, x, y)
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    local saved = kind == "target" and TargetNameProfile(true) or ForeverNameplatesDB.threatPosition
    saved.x = math.max(-200, math.min(200, tonumber(x) or 0))
    saved.y = math.max(-200, math.min(200, tonumber(y) or 0))
    if kind == "target" and self.RefreshTargetNames then self:RefreshTargetNames() end
    if kind ~= "target" then
        if self.RefreshThreatPercentages then self:RefreshThreatPercentages() end
        if self.RefreshThreatDifferential then self:RefreshThreatDifferential() end
    end
end

function addon:SetCompatibilityMode(enabled)
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    local wasEnabled = self:GetCompatibilityMode()
    if enabled and not wasEnabled then
        if self.CaptureCompatibilityStyle then self:CaptureCompatibilityStyle() end
        ForeverNameplatesDB.compatibilityFeatures = {}
    end
    ForeverNameplatesDB.compatibilityMode = enabled and true or false
    if not enabled and wasEnabled and self.RestoreCompatibilityStyle then self:RestoreCompatibilityStyle() end
    if enabled and self.RestoreNativeTextSizes then self:RestoreNativeTextSizes() end
    if enabled and self.RestoreATDStyle then self:RestoreATDStyle() end
    if self.ApplyNameplateDimensions then self:ApplyNameplateDimensions() end
    if self.ApplyNonTargetBrightMode then self.ApplyNonTargetBrightMode() end
    if self.ApplyNativeTextSizes then self:ApplyNativeTextSizes() end
    if self.RefreshNativeLevelVisibility then self:RefreshNativeLevelVisibility() end
    if self.RefreshThreatColors then self:RefreshThreatColors() end
    if self.RefreshTargetNames then self:RefreshTargetNames() end
    if self.RefreshThreatPercentages then self:RefreshThreatPercentages() end
    if self.RefreshNativeCCFallbacks then self:RefreshNativeCCFallbacks() end
    if self.RefreshNameplateAttachments then self:RefreshNameplateAttachments() end
    self:RefreshCompatibilityFeatures()
    if self.RefreshStyleOptions then self:RefreshStyleOptions() end
end


function addon:GetMobLevelEnabled()
    return not ForeverNameplatesDB or ForeverNameplatesDB.showMobLevel ~= false
end

function addon:SetMobLevelEnabled(enabled)
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    ForeverNameplatesDB.showMobLevel = enabled and true or false
    if self.RefreshNativeLevelVisibility then self:RefreshNativeLevelVisibility() end
end

function addon:GetMinimapVisible()
    local db = ForeverNameplatesDB or addon.defaults
    if db.minimap and db.minimap.visible ~= nil then
        return db.minimap.visible
    end
    return true
end

function addon:SetMinimapVisible(visible)
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    ForeverNameplatesDB.minimap.visible = visible and true or false
    local button = _G.ForeverNameplatesMinimapButton
    if button then
        if ForeverNameplatesDB.minimap.visible then button:Show() else button:Hide() end
    end
end

function addon:GetThreatColor(kind)
    local db = ForeverNameplatesDB or addon.defaults
    local c = db.threat and db.threat[kind] or addon.defaults.threat[kind]
    return c[1], c[2], c[3]
end

function addon:GetDungeonRaidThreatColor(profile, kind)
    local db = ForeverNameplatesDB or addon.defaults
    local section = db.dungeonRaidThreat and db.dungeonRaidThreat[profile]
    local defaults = addon.defaults.dungeonRaidThreat[profile]
    local c = section and section[kind] or defaults[kind]
    return c[1], c[2], c[3]
end

function addon:SetDungeonRaidThreatColor(profile, kind, r, g, b)
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    ForeverNameplatesDB.dungeonRaidThreat[profile][kind] = {r, g, b}
    if addon.RefreshThreatColors then addon:RefreshThreatColors() end
end

function addon:GetDungeonRaidThreatProfile()
    local db = ForeverNameplatesDB or addon.defaults
    if db.disableRoleColors then
        return nil
    end

    local inInstance, instanceType = IsInInstance()
    if not inInstance or (instanceType ~= "party" and instanceType ~= "raid") then
        return nil
    end

    local role = UnitGroupRolesAssigned("player")
    if role == "TANK" then return "tank" end
    if role == "DAMAGER" or role == "HEALER" then return "nonTank" end
    return nil
end

function addon:GetMobNameEnabled()
    local db = ForeverNameplatesDB or addon.defaults
    if db.mobName and db.mobName.enabled ~= nil then return db.mobName.enabled end
    return true
end

function addon:SetMobNameEnabled(enabled)
    if not ForeverNameplatesDB then ForeverNameplatesDB = {} end
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    ForeverNameplatesDB.mobName.enabled = enabled and true or false
    if addon.ApplyNativeTextSizes then addon:ApplyNativeTextSizes() end
end

function addon:GetHealthPercentEnabled()
    local db = ForeverNameplatesDB or addon.defaults
    if db.healthText and db.healthText.percentEnabled ~= nil then return db.healthText.percentEnabled end
    return true
end

function addon:SetHealthPercentEnabled(enabled)
    if not ForeverNameplatesDB then ForeverNameplatesDB = {} end
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    ForeverNameplatesDB.healthText.percentEnabled = enabled and true or false
    if addon.ApplyNativeTextSizes then addon:ApplyNativeTextSizes() end
end

function addon:GetHealthValueEnabled()
    local db = ForeverNameplatesDB or addon.defaults
    if db.healthText and db.healthText.valueEnabled ~= nil then return db.healthText.valueEnabled end
    return true
end

function addon:SetHealthValueEnabled(enabled)
    if not ForeverNameplatesDB then ForeverNameplatesDB = {} end
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    ForeverNameplatesDB.healthText.valueEnabled = enabled and true or false
    if addon.ApplyNativeTextSizes then addon:ApplyNativeTextSizes() end
end

function addon:GetMobNameFontSize()
    local db = ForeverNameplatesDB or addon.defaults
    local size = tonumber(db.mobName and db.mobName.fontSize) or addon.defaults.mobName.fontSize
    return math.max(5, math.min(18, size))
end

function addon:SetMobNameFontSize(size)
    if not ForeverNameplatesDB then ForeverNameplatesDB = {} end
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    size = math.max(5, math.min(18, tonumber(size) or addon.defaults.mobName.fontSize))
    ForeverNameplatesDB.mobName.fontSize = size
    if addon.ApplyMobNameFontSize then addon:ApplyMobNameFontSize() end
    if addon.RefreshNativeCCFallbacks then addon:RefreshNativeCCFallbacks() end
end

function addon:GetHealthPercentFontSize()
    local db = ForeverNameplatesDB or addon.defaults
    local size = tonumber(db.healthText and db.healthText.percentSize) or addon.defaults.healthText.percentSize
    return math.max(5, math.min(18, size))
end

function addon:SetHealthPercentFontSize(size)
    if not ForeverNameplatesDB then ForeverNameplatesDB = {} end
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    size = math.max(5, math.min(18, tonumber(size) or addon.defaults.healthText.percentSize))
    ForeverNameplatesDB.healthText.percentSize = size
    if addon.ApplyNativeTextSizes then addon:ApplyNativeTextSizes("percent") end
end

function addon:GetHealthValueFontSize()
    local db = ForeverNameplatesDB or addon.defaults
    local size = tonumber(db.healthText and db.healthText.valueSize) or addon.defaults.healthText.valueSize
    return math.max(5, math.min(18, size))
end

function addon:SetHealthValueFontSize(size)
    if not ForeverNameplatesDB then ForeverNameplatesDB = {} end
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    size = math.max(5, math.min(18, tonumber(size) or addon.defaults.healthText.valueSize))
    ForeverNameplatesDB.healthText.valueSize = size
    if addon.ApplyNativeTextSizes then addon:ApplyNativeTextSizes("value") end
end

function addon:GetTargetNamesEnabled()
    if self.GetCompatibilityFeatureEnabled and not self:GetCompatibilityFeatureEnabled("targetNames") then return false end
    if self.GetCompatibilityMode and self:GetCompatibilityMode() then return true end
    local db = ForeverNameplatesDB or addon.defaults
    return not db.targetNames or db.targetNames.enabled ~= false
end


function addon:SetTargetNamesEnabled(enabled)
    if self.SetCompatibilityFeatureEnabled and self:SetCompatibilityFeatureEnabled("targetNames", enabled) then return end
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    ForeverNameplatesDB.targetNames.enabled = enabled and true or false
    if self.SyncNativeSpellTarget then self:SyncNativeSpellTarget() end
    if self.RefreshTargetNames then self:RefreshTargetNames() end
end

function addon:GetFriendlyTargetNamesEnabled()
    local names = ForeverNameplatesDB and ForeverNameplatesDB.targetNames
    return not names or names.friendly ~= false
end

function addon:SetFriendlyTargetNamesEnabled(enabled)
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    ForeverNameplatesDB.targetNames.friendly = enabled == true
    if self.RefreshTargetNames then self:RefreshTargetNames() end
end


function addon:GetFullTargetNames()
    local db = ForeverNameplatesDB or addon.defaults
    if db.targetNames and db.targetNames.fullName ~= nil then
        return db.targetNames.fullName
    end
    return addon.defaults.targetNames.fullName
end

function addon:GetDefaultTargetNameFontSize()
    local size = self:GetTargetNameDefaults()
    return size
end

function addon:GetTargetNameFontSize()
    local profile = TargetNameProfile()
    local size = profile and tonumber(profile.fontSize)
    return size and math.max(8, math.min(24, math.floor(size + 0.5)))
        or self:GetDefaultTargetNameFontSize()
end

function addon:SetTargetNameFontSize(size)
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    -- An unset override follows the current style's default.
    TargetNameProfile(true).fontSize = size and
        math.max(8, math.min(24, math.floor(size + 0.5))) or nil
end

function addon:SetFullTargetNames(enabled)
    if not ForeverNameplatesDB then ForeverNameplatesDB = {} end
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    ForeverNameplatesDB.targetNames.fullName = enabled and true or false
end



function addon:SetThreatColor(kind, r, g, b)
    if not ForeverNameplatesDB then ForeverNameplatesDB = {} end
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    ForeverNameplatesDB.threat[kind] = {r, g, b}
end

function addon:GetTargetBorderColor()
    local db = ForeverNameplatesDB or addon.defaults
    local c = db.targetBorder or addon.defaults.targetBorder
    return c[1], c[2], c[3]
end

function addon:SetTargetBorderColor(r, g, b)
    if not ForeverNameplatesDB then ForeverNameplatesDB = {} end
    CopyDefaults(addon.defaults, ForeverNameplatesDB)
    ForeverNameplatesDB.targetBorder = {r, g, b}
    if addon.RefreshTargetBorders then addon:RefreshTargetBorders() end
end

function addon:GetNameplateSize()
    local v=tonumber(GetCVar("nameplateSize"))
    if not v then return addon.defaults.appearance.size end
    return math.max(1,math.min(5,math.floor(v+0.5)))
end

function addon:SetNameplateSize(v)
    v=math.max(1,math.min(5,math.floor((tonumber(v) or addon.defaults.appearance.size)+0.5)))
    self:SetNameplateCVar("nameplateSize",v)
    ForeverNameplatesDB=ForeverNameplatesDB or {}
    CopyDefaults(addon.defaults,ForeverNameplatesDB)
    ForeverNameplatesDB.appearance.size=v
    if self.ApplyNameplateDimensions then self:ApplyNameplateDimensions() end
    if addon:IsATDStyle() and addon.RefreshATDStyle then addon:RefreshATDStyle() end
end

local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:SetScript("OnEvent", function(self, _, name)
    if name ~= "BlizzThreatPlates-Forever" and name ~= "ForeverNameplates" then return end

    -- ADDON_LOADED fires after SavedVariables have been restored. Detect an
    -- existing install HERE, before CopyDefaults can create any missing keys.
    local hadSavedSettings =
        type(ForeverNameplatesDB) == "table"
        and (
            (type(ForeverNameplatesDB.appearance) == "table" and ForeverNameplatesDB.appearance.initialized == true)
            or type(ForeverNameplatesDB.threat) == "table"
        )

    -- Snapshot settings before adding any new defaults.
    local oldAggroColor = ForeverNameplatesDB and ForeverNameplatesDB.threat and ForeverNameplatesDB.threat.secure
    local oldAppearanceSize = ForeverNameplatesDB and ForeverNameplatesDB.appearance and ForeverNameplatesDB.appearance.size
    local oldMobNameSize = ForeverNameplatesDB and ForeverNameplatesDB.mobName and ForeverNameplatesDB.mobName.fontSize
    local oldPercentSize = ForeverNameplatesDB and ForeverNameplatesDB.healthText and ForeverNameplatesDB.healthText.percentSize
    local oldValueSize = ForeverNameplatesDB and ForeverNameplatesDB.healthText and ForeverNameplatesDB.healthText.valueSize
    local oldTargetPosition = ForeverNameplatesDB and ForeverNameplatesDB.targetPosition
    local oldTargetFontSize = ForeverNameplatesDB and ForeverNameplatesDB.targetNames and ForeverNameplatesDB.targetNames.fontSize

    ForeverNameplatesDB = ForeverNameplatesDB or {}
    -- Auto-Switch reuses the old Dungeon & Raid Role Colors preference.
    -- Preserve both saved booleans. Older existing settings without the key
    -- retain the previous implicit on default; only new installs start off.
    if hadSavedSettings and ForeverNameplatesDB.disableRoleColors == nil then
        ForeverNameplatesDB.disableRoleColors = false
    end
    CopyDefaults(addon.defaults, ForeverNameplatesDB)

    -- Initialize the border rollout after SavedVariables have been restored.
    if addon.InitializeNameplateBorderDefaults then addon:InitializeNameplateBorderDefaults() end

    -- Preserve the previous shared target placement for its active style.
    -- Other styles start with their own defaults; future edits remain separate.
    -- Keep this marker out of defaults so existing installs migrate once.
    if ForeverNameplatesDB.targetNameStyleDefaults110 ~= 1 then
        if hadSavedSettings and (oldTargetPosition or oldTargetFontSize) then
            local profile = TargetNameProfile(true)
            if oldTargetPosition then
                if profile.x == nil then profile.x = oldTargetPosition.x end
                if profile.y == nil then profile.y = oldTargetPosition.y end
            end
            if profile.fontSize == nil then profile.fontSize = oldTargetFontSize end
        end
        ForeverNameplatesDB.targetNameStyleDefaults110 = 1
    end

    -- Only replace the former default. Deliberate custom cast widths survive.
    if ForeverNameplatesDB.atdCastbarWidthMigration ~= 1 then
        if ForeverNameplatesDB.castbar.width == 134 then ForeverNameplatesDB.castbar.width = 130 end
        ForeverNameplatesDB.atdCastbarWidthMigration = 1
    end

    -- Enable quest icons once for the 1.0.27 rollout. Keep this marker out of
    -- defaults so older installs migrate, then preserve subsequent choices.
    if ForeverNameplatesDB.questObjectiveIconsMigration ~= 1 then
        ForeverNameplatesDB.questMarker = true
        ForeverNameplatesDB.questObjectiveIconsMigration = 1
    end

    if hadSavedSettings then
        if oldAppearanceSize ~= nil then ForeverNameplatesDB.appearance.size = oldAppearanceSize end
        if oldMobNameSize ~= nil then ForeverNameplatesDB.mobName.fontSize = oldMobNameSize end
        if oldPercentSize ~= nil then ForeverNameplatesDB.healthText.percentSize = oldPercentSize end
        if oldValueSize ~= nil then ForeverNameplatesDB.healthText.valueSize = oldValueSize end
    end

    -- One-time migration for the new context-based threat palettes.
    -- This marker is intentionally not part of defaults, so CopyDefaults
    -- cannot make an older install appear already migrated.
    if ForeverNameplatesDB.questingPaletteMigration ~= 1 then
        ForeverNameplatesDB.threat.secure  = {0.90, 0.10, 0.10}
        ForeverNameplatesDB.threat.warning = {1.00, 0.75, 0.00}
        ForeverNameplatesDB.threat.lost    = {0.55, 0.20, 0.80}
        ForeverNameplatesDB.dungeonRaidThreat.nonTank.secure  = {0.90, 0.10, 0.10}
        ForeverNameplatesDB.dungeonRaidThreat.nonTank.warning = {1.00, 0.75, 0.00}
        ForeverNameplatesDB.dungeonRaidThreat.nonTank.lost    = {0.55, 0.20, 0.80}
        ForeverNameplatesDB.questingPaletteMigration = 1
    end

    -- test13: correct DPS/Healer dungeon palette.
    if ForeverNameplatesDB.nonTankPaletteMigration ~= 1 then
        ForeverNameplatesDB.dungeonRaidThreat.nonTank.secure  = {0.55, 0.20, 0.80}
        ForeverNameplatesDB.dungeonRaidThreat.nonTank.warning = {1.00, 0.75, 0.00}
        ForeverNameplatesDB.dungeonRaidThreat.nonTank.lost    = {0.90, 0.10, 0.10}
        ForeverNameplatesDB.nonTankPaletteMigration = 1
    end

    -- 1.0.19-test24: requested dungeon/raid tank palette defaults.
    -- Apply once so existing test installs see the same defaults as fresh installs.
    if ForeverNameplatesDB.tankPaletteBrightMigration ~= 1 then
        ForeverNameplatesDB.dungeonRaidThreat.tank.secure  = {25/255, 1.00, 0.00} -- #19FF00
        ForeverNameplatesDB.dungeonRaidThreat.tank.warning = {1.00, 220/255, 0.00} -- #FFDC00
        ForeverNameplatesDB.dungeonRaidThreat.tank.lost    = {1.00, 29/255, 29/255} -- #FF1D1D
        ForeverNameplatesDB.tankPaletteBrightMigration = 1
    end

    -- test17: update only the former defaults to exact #FF1D1D. Preserve
    -- any other value as a user-selected custom color.
    if ForeverNameplatesDB.exactRedPaletteMigration ~= 1 then
        local function IsColor(color, r, g, b)
            return color and color[1] == r and color[2] == g and color[3] == b
        end
        if IsColor(ForeverNameplatesDB.threat.secure, 0.90, 0.10, 0.10) then
            ForeverNameplatesDB.threat.secure = {1.00, 29/255, 29/255}
        end
        if IsColor(ForeverNameplatesDB.threat.lost, 0.55, 0.20, 0.80) then
            ForeverNameplatesDB.threat.lost = {1.00, 29/255, 29/255}
        end
        local nonTank = ForeverNameplatesDB.dungeonRaidThreat.nonTank
        if IsColor(nonTank.lost, 0.90, 0.10, 0.10) or IsColor(nonTank.lost, 0.55, 0.20, 0.80) then
            nonTank.lost = {1.00, 29/255, 29/255}
        end
        ForeverNameplatesDB.exactRedPaletteMigration = 1
    end

    -- TEST 34 migration: TEST 33 used a gold tint as its default. Only migrate
    -- that exact old default; any user-selected custom border color is preserved.
    local oldBorder = ForeverNameplatesDB.targetBorder
    if oldBorder and oldBorder[1] == 1.00 and oldBorder[2] == 0.82 and oldBorder[3] == 0.00 then
        ForeverNameplatesDB.targetBorder = {1.00, 1.00, 1.00}
    end

    -- Preserve existing aggro choices even when upgrading from older palette
    -- migrations; only fresh installs receive the new green default.
    if oldAggroColor then
        ForeverNameplatesDB.threat.secure = oldAggroColor
    elseif not hadSavedSettings then
        ForeverNameplatesDB.threat.secure = {25/255, 1.00, 0.00}
    end

    -- test40: adopt the currently selected Blizzard style and reset only that
    -- style's size/shape once. Never put this marker in CopyDefaults.
    if ForeverNameplatesDB.nativeSizingDefaults40 ~= 1 then
        local appearance=ForeverNameplatesDB.appearance
        local nativeStyle=tonumber(GetCVar("nameplateStyle")) or addon.defaults.appearance.style
        local styles=Enum and Enum.NamePlateStyle or {}
        local family=nativeStyle
        if nativeStyle==styles.Block then family=styles.Modern or nativeStyle
        elseif nativeStyle==styles.CastFocus then family=styles.Thin or nativeStyle end
        appearance.customStyle=nil
        appearance.style=nativeStyle
        appearance.size=addon.defaults.appearance.size
        appearance.dimensions=appearance.dimensions or {}
        appearance.dimensions[family]=appearance.dimensions[family] or {}
        appearance.dimensions[family].width=100
        appearance.dimensions[family].height=100
        local profile=appearance.styleProfiles and appearance.styleProfiles[nativeStyle]
        if profile then profile.size=addon.defaults.appearance.size end
        ForeverNameplatesDB.nativeSizingDefaults40=1
    end

    -- Release 1.1.0: enable these two choices once for new installs and upgrades.
    -- Keep the marker out of defaults so later opt-outs are never reset.
    if ForeverNameplatesDB.classColorDefaults110 ~= 1 then
        ForeverNameplatesDB.friendlyPlayerClassColors = ForeverNameplatesDB.friendlyPlayerClassColors or {}
        ForeverNameplatesDB.friendlyPlayerClassColors.world = true
        ForeverNameplatesDB.pvpClassColors = true
        addon:SetNameplateCVar("nameplateShowClassColor", 1)
        ForeverNameplatesDB.classColorDefaults110 = 1
    end

    -- Enable the experimental native debuff display once for fresh installs
    -- and this rollout's updates. Keep this marker out of CopyDefaults so
    -- opting out later survives reloads and future builds.
    if ForeverNameplatesDB.nativeCCDefaults110 ~= 1 then
        ForeverNameplatesDB.nativeCCWorkaround = true
        ForeverNameplatesDB.nativeCCDefaults110 = 1
    end

    -- Release rollout: Disable Mob Level starts unchecked once for everyone.
    -- This marker stays outside defaults so later choices survive updates.
    if ForeverNameplatesDB.mobLevelDefaults110 ~= 1 then
        ForeverNameplatesDB.showMobLevel = true
        ForeverNameplatesDB.mobLevelDefaults110 = 1
    end

    if not hadSavedSettings then
        -- Fresh install defaults. Retain the selected Blizzard style; subsequent
        -- reloads preserve the user's size/text choices after the rollout reset.
        -- Seed only missing new-install choices. Keep this out of CopyDefaults
        -- so upgrades/reloads never turn a user's disabled option back on.
        ForeverNameplatesDB.friendlyPlayerClassColors = ForeverNameplatesDB.friendlyPlayerClassColors or {}
        for context, enabled in pairs({world = true, pvp = false, party = false, raid = false}) do
            if ForeverNameplatesDB.friendlyPlayerClassColors[context] == nil then
                ForeverNameplatesDB.friendlyPlayerClassColors[context] = enabled
            end
        end
        addon:SetNameplateCVar("nameplateSize",addon.defaults.appearance.size)
        addon:SetNameplateCVar("nameplateAuraScale",1)
        addon:SetNameplateBitfieldMask("nameplateInfoDisplay",1)
        ForeverNameplatesDB.appearance.size=addon.defaults.appearance.size
        ForeverNameplatesDB.mobName.fontSize=addon.defaults.mobName.fontSize
        ForeverNameplatesDB.healthText.percentSize=addon.defaults.healthText.percentSize
        ForeverNameplatesDB.healthText.valueSize=addon.defaults.healthText.valueSize
    else
        -- Existing install: SavedVariables are the source of truth.
        -- Restore the user's saved nameplate size to Blizzard's CVar instead of
        -- overwriting their saved preference with the current CVar.
        local savedSize = tonumber(ForeverNameplatesDB.appearance and ForeverNameplatesDB.appearance.size)
        if savedSize then
            addon:SetNameplateSize(savedSize)
        end
    end
    -- Adopt the native selection after fresh defaults or saved sizing apply.
    if addon.InitializeNameplateStyles then addon:InitializeNameplateStyles() end
    ForeverNameplatesDB.appearance.initialized=true
    ForeverNameplatesDB.settingsVersion = 1
    self:UnregisterEvent("ADDON_LOADED")
end)
