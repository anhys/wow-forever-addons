-- Classic Era (1.15.x) dataset/compatibility isolation.
-- Keep the original ForeverDungeonJournal folder for its bundled texture paths.
--
-- This build is derived from the TBC Anniversary edition. IS_TBC_ANNIVERSARY
-- stays TRUE on purpose: every file that checks it means "a client with the
-- real Classic database, as opposed to the Forever realm" (quest-log APIs,
-- on-demand portraits, no Forever XP tables, TBCVanillaDungeons.lua and the
-- Vanilla raid files all gate on it). IS_CLASSIC_ERA is the flag for the few
-- places where Era differs from TBC Anniversary: no Outland content, no
-- heroic mode, only the Vanilla + Raids galleries, Era boss levels and quest
-- levels (Data/ClassicEraBossLevels.lua, Data/ClassicEraQuestFixes.lua).
local ADDON_NAME, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS
FDJ.IS_TBC_ANNIVERSARY = true
FDJ.IS_CLASSIC_ERA = true
FDJ.CLIENT_FLAVOR = "Classic Era"

-- Season of Discovery runs on the same client but with its own levels, loot
-- and runes. The journal still opens there; the data is Classic Era's.
do
    local seasonID
    if type(C_Seasons) == "table" and type(C_Seasons.GetActiveSeason) == "function" then
        local ok, id = pcall(C_Seasons.GetActiveSeason)
        if ok and type(id) == "number" then seasonID = id end
    end
    local sod = 2 -- Enum.SeasonID.SeasonOfDiscovery
    if type(Enum) == "table" and type(Enum.SeasonID) == "table"
        and type(Enum.SeasonID.SeasonOfDiscovery) == "number" then
        sod = Enum.SeasonID.SeasonOfDiscovery
    end
    FDJ.IS_SEASON_OF_DISCOVERY = (seasonID ~= nil and seasonID == sod)
end

-- Only dungeons that actually exist in this client are shown. The remaining
-- original 1.6.5 data contains Forever-only raids, item IDs and quests.
local valid = {
    ["Ragefire Chasm"] = true, ["The Deadmines"] = true,
    ["Wailing Caverns"] = true, ["Shadowfang Keep"] = true,
    ["Blackfathom Deeps"] = true, ["The Stockade"] = true,
    ["Gnomeregan"] = true, ["Razorfen Kraul"] = true,
    ["Scarlet Monastery: Graveyard"] = true,
    ["Scarlet Monastery: Library"] = true,
}

-- IDs in the 200,000+ space and 90,000+ quest space are added by Forever,
-- not part of the TBC Anniversary database. Handle nested item lists by ID
-- rather than names, retaining authentic Classic loot and reward choices.
local function CleanItemList(list)
    if type(list) ~= "table" then return end
    for i = #list, 1, -1 do
        local item = list[i]
        if type(item) ~= "table" or type(item[1]) ~= "number"
            or item[1] <= 0 or item[1] >= 200000 then
            table.remove(list, i)
        end
    end
end

local function CleanSingleItem(entry, key)
    local item = entry[key]
    if type(item) == "table" and type(item[1]) == "number" and item[1] >= 200000 then
        entry[key] = nil
    end
end

local function CleanQuest(q)
    for _, key in ipairs({"rewardItems", "additionalRewardItems", "noteRewardItems", "requiredItems"}) do
        CleanItemList(q[key])
    end
    for _, key in ipairs({"rewardItem", "requiredItem", "startItem", "noteItem", "providedItem"}) do
        CleanSingleItem(q, key)
    end
    -- In TBC, this quest grants the Ghostly Mantle directly. Forever added
    -- two custom choices which are absent on Anniversary realms.
    if q.id == 1098 then
        q.rewardItems = {{3324, "Ghostly Mantle", 3}}
        q.rewardChoice = nil
    end
    if q.rewardChoice and #(q.rewardItems or {}) < 2 then
        q.rewardChoice = nil
    end
    -- XP, money and reputation supplied by Forever are not TBC rewards.
    -- The client can supply money once the quest is active; do not invent XP.
    q.liveXPFallback = nil
    q.rewards = nil
    q.rewardSummary = nil
    if type(q.note) == "string" and (q.note:find("Forever", 1, true) or q.note:find("forever", 1, true)) then
        q.note = nil
    end
    if type(q.warning) == "string" and q.warning:find("Forever", 1, true) then
        q.warning = nil
    end
end

for name, dungeon in pairs(FDJ.DB or {}) do
    if not valid[name] then
        FDJ.DB[name] = nil
    else
        for i = #(dungeon.quests or {}), 1, -1 do
            local quest = dungeon.quests[i]
            if type(quest) ~= "table"
                or (not quest.id and not quest.name and not quest.objective)
                or (type(quest.id) == "number" and quest.id >= 90000) then
                table.remove(dungeon.quests, i)
            else
                CleanQuest(quest)
            end
        end
        for i = #(dungeon.bosses or {}), 1, -1 do
            local boss = dungeon.bosses[i]
            CleanItemList(boss.loot)
            -- In Classic/TBC the Scarlet Key is found in Doan's Strongbox
            -- behind Arcanist Doan; it is not a direct boss drop.
            if name == "Scarlet Monastery: Library" and boss.name == "Arcanist Doan" then
                for j = #(boss.loot or {}), 1, -1 do
                    if boss.loot[j][1] == 7146 then table.remove(boss.loot, j) end
                end
            end
            if boss.trash and #(boss.loot or {}) == 0 then
                table.remove(dungeon.bosses, i)
            end
        end
    end
end

local order = {}
for _, name in ipairs(FDJ.ORDER or {}) do
    if FDJ.DB[name] then order[#order + 1] = name end
end
FDJ.ORDER = order

-- Remove invalid Forever-only prerequisite chains and quest reward fallbacks.
for _, field in ipairs({"QUEST_PREREQ_CHAINS", "QUEST_PREREQ_DETAILS",
                      "PREREQ_REWARD_ITEMS_FALLBACK", "PREREQ_REWARD_MONEY_FALLBACK"}) do
    local data = FDJ[field]
    if type(data) == "table" then
        for questID, entry in pairs(data) do
            if type(questID) == "number" and questID >= 90000 then
                data[questID] = nil
            elseif field == "QUEST_PREREQ_CHAINS" and type(entry) == "table" then
                for i = #entry, 1, -1 do
                    if type(entry[i]) == "table" and type(entry[i].id) == "number" and entry[i].id >= 90000 then
                        table.remove(entry, i)
                    end
                end
            elseif field == "PREREQ_REWARD_ITEMS_FALLBACK" and type(entry) == "table" then
                CleanItemList(entry.items)
            elseif field == "QUEST_PREREQ_DETAILS" and type(entry) == "table" then
                CleanQuest(entry)
            end
        end
    end
end

-- These figures are the Forever realm's rewards; never use them on TBC.
FDJ.FOREVER_QUEST_XP_FALLBACK = {}
FDJ.FOREVER_QUEST_BASE_XP = {}
-- Forever's item-shareability audit is realm specific (TBC can test quests
-- the player actually has through GetQuestLogPushable).
FDJ.QUEST_SHAREABILITY_AUDIT = {}
