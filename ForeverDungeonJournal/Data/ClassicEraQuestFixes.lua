-- Dungeon Journal - Classic Era: quest levels and level requirements.
-- The TBC edition carries the TBC Anniversary values (patch 2.3 changed many
-- Vanilla dungeon quests). This file restores the Classic Era (1.15) values,
-- generated from the Era quest database on 2026-10-30 and applied to the
-- dungeon quest lists, chain steps and quest detail pages after all quest
-- data has loaded. Quests that do not exist on Era are removed.
-- Load after Data/TBCQuestListConsolidation.lua and before Core/Journal.lua.
local _, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS
if not FDJ or not FDJ.IS_CLASSIC_ERA then return end

-- [questID] = { level = questLevel, requires = minimum player level }
-- Only the fields that differ from the TBC edition are listed.
local FIX = {
    [378] = { requires = 22 }, -- The Fury Runs Deep (TBC database: level 27, requires 25)
    [914] = { requires = 11 }, -- Leaders of the Fang (TBC database: level 22, requires 10)
    [1100] = { level = 34, requires = 29 }, -- Lonebrow's Journal (TBC database: level 27, requires 23)
    [1475] = { requires = 41 }, -- Into The Temple of Atal'Hakkar (TBC database: level 50, requires 38)
    [1489] = { requires = 12 }, -- Hamuul Runetotem (TBC database: level 16, requires 10)
    [1490] = { requires = 12 }, -- Nara Wildmane (TBC database: level 16, requires 10)
    [2280] = { requires = 40 }, -- The Platinum Discs (TBC database: level 47, requires 40)
    [3528] = { level = 53 }, -- The God Hakkar (TBC database: level 53, requires 40)
    [3636] = { requires = 39 }, -- Bring the Light (TBC database: level 37, requires 32)
    [4082] = { requires = 50 }, -- KILL ON SIGHT: High Ranking Dark Iron Officials (TBC database: level 54, requires 52)
    [4264] = { requires = 50 }, -- A Crumpled Up Note (TBC database: level 58, requires 50)
    [4282] = { requires = 50 }, -- A Shred of Hope (TBC database: level 58, requires 52)
    [4322] = { requires = 50 }, -- Jail Break! (TBC database: level 58, requires 52)
    [4764] = { level = 60 }, -- Doomrigger's Clasp (TBC database: level 60, requires 57)
    [4788] = { level = 58 }, -- The Final Tablets (TBC database: level 58, requires 55)
    [5047] = { requires = 55 }, -- Pip Quickwit, At Your Service! (TBC database: level 60, requires 59)
    [5529] = { level = 58 }, -- Plagued Hatchlings (TBC database: level 58, requires 55)
    [6569] = { requires = 55 }, -- Oculus Illusions (TBC database: level 60, requires 55)
    [6602] = { requires = 55 }, -- Blood of the Black Dragon Champion (TBC database: level 60, requires 60)
    [6821] = { requires = 56 }, -- Eye of the Emberseer (TBC database: level 60, requires 58)
    [6822] = { requires = 57 }, -- The Molten Core (TBC database: level 60, requires 58)
    [6823] = { requires = 60 }, -- Agent of Hydraxis (TBC database: level 60, requires 60)
    [6824] = { requires = 60 }, -- Hands of the Enemy (TBC database: level 60, requires 60)
    [7066] = { requires = 45 }, -- Seed of Life (TBC database: level 51, requires 39)
    [7441] = { level = 58 }, -- Pusillin and the Elder Azj'Tordin (TBC database: level 58, requires 54)
    [7486] = { requires = 60 }, -- A Hero's Reward (TBC database: level 60, requires 60)
    [8041] = { requires = 60 }, -- Strength of Mount Mugamba (TBC database: level 60, requires 58)
    [8042] = { requires = 60 }, -- Strength of Mount Mugamba (TBC database: level 60, requires 58)
    [8043] = { requires = 60 }, -- Strength of Mount Mugamba (TBC database: level 60, requires 58)
    [8044] = { requires = 60 }, -- The Rage of Mugamba (TBC database: level 60, requires 58)
    [8045] = { requires = 60 }, -- The Heathen's Brand (TBC database: level 60, requires 58)
    [8046] = { requires = 60 }, -- The Heathen's Brand (TBC database: level 60, requires 58)
    [8047] = { requires = 60 }, -- The Heathen's Brand (TBC database: level 60, requires 58)
    [8048] = { requires = 60 }, -- The Hero's Brand (TBC database: level 60, requires 58)
    [8049] = { requires = 60 }, -- The Eye of Zuldazar (TBC database: level 60, requires 58)
    [8050] = { requires = 60 }, -- The Eye of Zuldazar (TBC database: level 60, requires 58)
    [8051] = { requires = 60 }, -- The Eye of Zuldazar (TBC database: level 60, requires 58)
    [8052] = { requires = 60 }, -- The All-Seeing Eye of Zuldazar (TBC database: level 60, requires 58)
    [8053] = { level = 61, requires = 60 }, -- Paragons of Power: The Freethinker's Armguards (TBC database: level 60, requires 58)
    [8054] = { level = 61, requires = 60 }, -- Paragons of Power: The Freethinker's Belt (TBC database: level 60, requires 58)
    [8055] = { level = 61, requires = 60 }, -- Paragons of Power: The Freethinker's Breastplate (TBC database: level 60, requires 58)
    [8056] = { requires = 60 }, -- Paragons of Power: The Augur's Bracers (TBC database: level 60, requires 58)
    [8057] = { requires = 60 }, -- Paragons of Power: The Haruspex's Bracers (TBC database: level 60, requires 58)
    [8058] = { requires = 60 }, -- Paragons of Power: The Vindicator's Armguards (TBC database: level 60, requires 58)
    [8059] = { requires = 60 }, -- Paragons of Power: The Demoniac's Wraps (TBC database: level 60, requires 58)
    [8060] = { requires = 60 }, -- Paragons of Power: The Illusionist's Wraps (TBC database: level 60, requires 58)
    [8061] = { requires = 60 }, -- Paragons of Power: The Confessor's Wraps (TBC database: level 60, requires 58)
    [8062] = { requires = 60 }, -- Paragons of Power: The Predator's Bracers (TBC database: level 60, requires 58)
    [8063] = { requires = 60 }, -- Paragons of Power: The Madcap's Bracers (TBC database: level 60, requires 58)
    [8064] = { requires = 60 }, -- Paragons of Power: The Haruspex's Belt (TBC database: level 60, requires 58)
    [8065] = { requires = 60 }, -- Paragons of Power: The Haruspex's Tunic (TBC database: level 60, requires 58)
    [8066] = { requires = 60 }, -- Paragons of Power: The Predator's Belt (TBC database: level 60, requires 58)
    [8067] = { requires = 60 }, -- Paragons of Power: The Predator's Mantle (TBC database: level 60, requires 58)
    [8068] = { requires = 60 }, -- Paragons of Power: The Illusionist's Mantle (TBC database: level 60, requires 58)
    [8069] = { requires = 60 }, -- Paragons of Power: The Illusionist's Robes (TBC database: level 60, requires 58)
    [8070] = { requires = 60 }, -- Paragons of Power: The Confessor's Bindings (TBC database: level 60, requires 58)
    [8071] = { requires = 60 }, -- Paragons of Power: The Confessor's Mantle (TBC database: level 60, requires 58)
    [8072] = { requires = 60 }, -- Paragons of Power: The Madcap's Mantle (TBC database: level 60, requires 58)
    [8073] = { requires = 60 }, -- Paragons of Power: The Madcap's Tunic (TBC database: level 60, requires 58)
    [8074] = { requires = 60 }, -- Paragons of Power: The Augur's Belt (TBC database: level 60, requires 58)
    [8075] = { requires = 60 }, -- Paragons of Power: The Augur's Hauberk (TBC database: level 60, requires 58)
    [8076] = { requires = 60 }, -- Paragons of Power: The Demoniac's Mantle (TBC database: level 60, requires 58)
    [8077] = { requires = 60 }, -- Paragons of Power: The Demoniac's Robes (TBC database: level 60, requires 58)
    [8078] = { requires = 60 }, -- Paragons of Power: The Vindicator's Belt (TBC database: level 60, requires 58)
    [8079] = { requires = 60 }, -- Paragons of Power: The Vindicator's Breastplate (TBC database: level 60, requires 58)
    [8101] = { requires = 60 }, -- The Pebble of Kajaro (TBC database: level 60, requires 58)
    [8102] = { requires = 60 }, -- The Pebble of Kajaro (TBC database: level 60, requires 58)
    [8103] = { requires = 60 }, -- The Pebble of Kajaro (TBC database: level 60, requires 58)
    [8104] = { requires = 60 }, -- The Jewel of Kajaro (TBC database: level 60, requires 58)
    [8106] = { requires = 60 }, -- Kezan's Taint (TBC database: level 60, requires 58)
    [8107] = { requires = 60 }, -- Kezan's Taint (TBC database: level 60, requires 58)
    [8108] = { requires = 60 }, -- Kezan's Taint (TBC database: level 60, requires 58)
    [8109] = { requires = 60 }, -- Kezan's Unstoppable Taint (TBC database: level 60, requires 58)
    [8110] = { requires = 60 }, -- Enchanted South Seas Kelp (TBC database: level 60, requires 58)
    [8111] = { requires = 60 }, -- Enchanted South Seas Kelp (TBC database: level 60, requires 58)
    [8112] = { requires = 60 }, -- Enchanted South Seas Kelp (TBC database: level 60, requires 58)
    [8113] = { requires = 60 }, -- Pristine Enchanted South Seas Kelp (TBC database: level 60, requires 58)
    [8116] = { requires = 60 }, -- Vision of Voodress (TBC database: level 60, requires 58)
    [8117] = { requires = 60 }, -- Vision of Voodress (TBC database: level 60, requires 58)
    [8118] = { requires = 60 }, -- Vision of Voodress (TBC database: level 60, requires 58)
    [8119] = { requires = 60 }, -- The Unmarred Vision of Voodress (TBC database: level 60, requires 58)
    [8141] = { requires = 60 }, -- Zandalarian Shadow Talisman (TBC database: level 60, requires 58)
    [8142] = { requires = 60 }, -- Zandalarian Shadow Talisman (TBC database: level 60, requires 58)
    [8143] = { requires = 60 }, -- Zandalarian Shadow Talisman (TBC database: level 60, requires 58)
    [8144] = { requires = 60 }, -- Zandalarian Shadow Mastery Talisman (TBC database: level 60, requires 58)
    [8145] = { requires = 60 }, -- The Maelstrom's Tendril (TBC database: level 60, requires 58)
    [8146] = { requires = 60 }, -- The Maelstrom's Tendril (TBC database: level 60, requires 58)
    [8147] = { requires = 60 }, -- The Maelstrom's Tendril (TBC database: level 60, requires 58)
    [8148] = { requires = 60 }, -- Maelstrom's Wrath (TBC database: level 60, requires 58)
    [8258] = { requires = 60 }, -- The Darkreaver Menace (TBC database: level 60, requires 58)
    [9208] = { requires = 60 }, -- The Savage Guard - Arcanum of Protection (TBC database: level 60, requires 58)
    [9209] = { requires = 60 }, -- The Savage Guard - Arcanum of Rapidity (TBC database: level 60, requires 58)
    [9210] = { requires = 60 }, -- The Savage Guard - Arcanum of Focus (TBC database: level 60, requires 58)
}

-- Quests that only exist on TBC Anniversary (holiday or 2.x additions).
local REMOVE = {
    [9737] = true, -- True Masters of the Light
    [12062] = true, -- Insult Coren Direbrew
}

local function Apply(q)
    if type(q) ~= "table" or type(q.id) ~= "number" then return end
    local fx = FIX[q.id]
    if not fx then return end
    if fx.level and q.level ~= nil then q.level = fx.level end
    if fx.requires and q.requires ~= nil then q.requires = fx.requires end
end

for name, dungeon in pairs(FDJ.DB or {}) do
    local quests = dungeon.quests
    if type(quests) == "table" then
        for i = #quests, 1, -1 do
            local q = quests[i]
            if type(q) == "table" and REMOVE[q.id] then
                table.remove(quests, i)
            else
                Apply(q)
            end
        end
    end
end

for questID, entry in pairs(FDJ.QUEST_PREREQ_DETAILS or {}) do
    if REMOVE[questID] then
        FDJ.QUEST_PREREQ_DETAILS[questID] = nil
    else
        Apply(entry)
    end
end

for questID, chain in pairs(FDJ.QUEST_PREREQ_CHAINS or {}) do
    if REMOVE[questID] then
        FDJ.QUEST_PREREQ_CHAINS[questID] = nil
    elseif type(chain) == "table" then
        for i = #chain, 1, -1 do
            local step = chain[i]
            if type(step) == "table" and REMOVE[step.id] then
                table.remove(chain, i)
            else
                Apply(step)
            end
        end
    end
end

for _, field in ipairs({ "QUEST_SHAREABILITY_AUDIT", "CLASSIC_ERA_QUEST_SHAREABILITY_AUDIT",
                         "PREREQ_REWARD_ITEMS_FALLBACK", "PREREQ_REWARD_MONEY_FALLBACK" }) do
    local t = FDJ[field]
    if type(t) == "table" then
        for questID in pairs(REMOVE) do t[questID] = nil end
    end
end

FDJ.CLASSIC_ERA_QUEST_FIXES = FIX

-- The Barrens was not split into Northern/Southern Barrens until Cataclysm.
for _, name in ipairs({ "Wailing Caverns", "Razorfen Downs" }) do
    if FDJ.DB and FDJ.DB[name] then FDJ.DB[name].location = "The Barrens" end
end
