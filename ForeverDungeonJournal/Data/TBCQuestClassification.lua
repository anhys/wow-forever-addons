-- TBC Anniversary v1.6.12.4: one-time dungeon quest listing and start origins.
-- Loaded after all Vanilla/Outland quest additions and heroic data, before UI.
-- Both the Vanilla and heroic/normal TBC quest views use FDJ.DB quests.
local _, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS
if not FDJ or not FDJ.IS_TBC_ANNIVERSARY then return end

-- Repeatable TURN-INS do not belong in the one-time dungeon quest browser.
-- One-time introductory quests stay (e.g. #9715 and #9765).
-- Keep prerequisite DATA intact so chained one-time quests still have context.
local REPEATABLE = {
    [4295]  = true, -- Rocknot's Ale (bar event)
    [5518]  = true, -- The Gordok Ogre Suit
    [5525]  = true, -- Free Knot!
    [7483]  = true, -- Libram of Rapidity
    [7484]  = true, -- Libram of Focus
    [7485]  = true, -- Libram of Protection
    [9714]  = true, -- Bring Me Another Shrubbery!
    [9766]  = true, -- Coilfang Armaments
    [10981] = true, -- Nexus-Prince Shaffar's Personal Chamber
}

-- Non-instanced hubs (even when underground), and known false flags in the
-- original database. NB the quest's *turn-in* being in an instance does not
-- make the *start* an in-instance pickup.
local STARTS_OUTSIDE = {
    [2280] = true, [2948] = true, [2950] = true,
    [10277] = true, [10282] = true,
}

-- Quests picked up from NPCs, game objects or dropped items *inside* a
-- dungeon. Needed when descriptions omit the literal word "inside".
local STARTS_INSIDE = {
    [373] = true,   -- VanCleef's Unsent Letter / Deadmines
    [6981] = true,  -- Mutanus' Glowing Shard / Wailing Caverns
    [6922] = true,  -- Baron Aquanis' Strange Water Globe / BFD
    [2201] = true,  -- Remains of a Paladin / Uldaman
    [2240] = true,  -- Baelog / Uldaman
    [2278] = true,  -- Discs of Norgannon / Uldaman
    [2951] = true,  -- first Sparklematic quest / Gnomeregan
    [3523] = true, [3525] = true, -- Belnistrasz / RFD
    [3982] = true,  -- Gor'shak / BRD
    [4083] = true,  -- Gloom'rel / BRD
    [4201] = true,  -- Mistress Nagmara / BRD
    [4264] = true,  -- Crumpled Up Note drop / BRD
    [4282] = true, [4322] = true, -- Marshal Windsor / BRD
    [4742] = true,  -- Vaelan / LBRS
    [5089] = true,  -- Drakkisath's Command drop / LBRS
    [5262] = true,  -- Balnazzar's Head / Stratholme Living
    [7046] = true,  -- Celebras the Redeemed / Maraudon
    [7463] = true,  -- Lorekeeper Lydros / Dire Maul Athenaeum
    [7507] = true,  -- Nostro's Compendium / Dire Maul
    [7604] = true,  -- Lokhtos / BRD
    [8949] = true, [8950] = true, -- Falrin Treeshaper / Athenaeum
    [9587] = true, [9588] = true, -- Ominous Letter / Hellfire Ramparts
    [9764] = true,  -- Orders from Lady Vashj / Steamvault
    [10285] = true, -- Erozion after escort / Old Hillsbrad
    [11972] = true, -- Shards of Ahune / Slave Pens
}

-- Only item IDs validated as quest starting items; do not replace existing
-- item cards on other quests with speculative data.
local QUEST_START_ITEMS = {
    [9587]  = {23890, "Ominous Letter", 1, "Loot from Vazruden in Hellfire Ramparts (Alliance); right-click to begin Dark Tidings."},
    [9588]  = {23892, "Ominous Letter", 1, "Loot from Vazruden in Hellfire Ramparts (Horde); right-click to begin Dark Tidings."},
    [9764]  = {24367, "Orders from Lady Vashj", 1, "Dropped by Steamvault naga; right-click to begin the quest."},
    [11972] = {35723, "Shards of Ahune", 1, "First-time drop from Ahune during Midsummer in Slave Pens; right-click to begin."},
    [4264]  = {11446, "A Crumpled Up Note", 1, "Dropped inside Blackrock Depths after Abandoned Hope."},
    [5089]  = {12780, "General Drakkisath's Command", 1, "Dropped by Overlord Wyrmthalak in Lower Blackrock Spire."},
}

-- Additional locations that look like an interior in written quest data but
-- lie outside an actual instance (public approach zones).
local PUBLIC_HUB_PATTERNS = {
    "inside caverns of time",
    "inside the caverns of time",
    "inside coilfang entrance cavern",
    "inside the coilfang entrance cavern",
}

local function StartsInInstance(entry)
    if type(entry) ~= "table" then return false end
    local questID = entry.id
    if STARTS_OUTSIDE[questID] then return false end
    if STARTS_INSIDE[questID] then return true end
    local pickup = type(entry.pickup) == "string" and entry.pickup:lower() or ""
    for i = 1, #PUBLIC_HUB_PATTERNS do
        if pickup:find(PUBLIC_HUB_PATTERNS[i], 1, true) then return false end
    end
    if pickup:find("inside ", 1, true) then return true end
    -- Respect an existing explicit classification if the quest's text is terse.
    return entry.startsInDungeon == true
end

FDJ.TBCRepeatableQuestIDs = REPEATABLE
FDJ.QuestStartsInDungeon = function(entry)
    -- Entries are classified once, after the DB has loaded. Their final flag
    -- must be authoritative when rendered in the quest list/page.
    if not entry then return false end
    if entry.startsInDungeon ~= nil then return entry.startsInDungeon == true end
    return StartsInInstance(entry)
end

local function Classify(entry, id)
    if type(entry) ~= "table" then return end
    -- Some prerequisite details are keyed by questID but have no .id field.
    -- Carry the key so explicit item-start/boss-origin classification applies.
    if not entry.id and type(id) == "number" then entry.id = id end
    entry.startsInDungeon = StartsInInstance(entry)
    local item = QUEST_START_ITEMS[entry.id]
    if item and not entry.startObject then entry.startItem = item end
end

-- Keep all existing dungeon names, bosses, loot and heroic difficulty data.
for _, dungeon in pairs(FDJ.DB or {}) do
    if type(dungeon.quests) == "table" then
        for i = #dungeon.quests, 1, -1 do
            local quest = dungeon.quests[i]
            if type(quest) == "table" and REPEATABLE[quest.id] then
                table.remove(dungeon.quests, i)
            else
                Classify(quest)
            end
        end
    end
end

for questID, step in pairs(FDJ.QUEST_PREREQ_DETAILS or {}) do
    Classify(step, questID)
end
