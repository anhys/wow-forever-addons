-- TBC Anniversary database/UI cleanup (v1.6.6.1)
-- Loaded AFTER TBCVanillaDungeons.lua and BEFORE Journal.lua.
local _, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS
if not FDJ or not FDJ.IS_TBC_ANNIVERSARY then return end
local db = FDJ.DB or {}

-- These named encounters have no unique equippable loot: only quest objectives
-- or instance progression objects. Keep their associated quests in the journal.
local questOnlyBosses = {
    ["Uldaman"] = { ["Obsidian Sentinel"] = true },
    ["Zul'Farrak"] = {
        ["Theka the Martyr"] = true,
        ["Nekrum Gutchewer"] = true,
        ["Sandfury Executioner"] = true,
        ["Sergeant Bly"] = true,
        ["Hydromancer Velratha"] = true,
    },
    ["Stratholme: Living"] = { ["Malor the Zealous"] = true },
}

-- Quest-bound objects are tracked on the quest page, not as gear drops.
-- Other loot from these bosses remains visible.
local questLoot = {
    [8053] = true,   -- Obsidian Power Source (Uldaman mage quest)
    [10660] = true,  -- First Mosh'aru Tablet
    [10661] = true,  -- Second Mosh'aru Tablet
    [9471] = true,   -- Nekrum's Medallion
    [8548] = true,   -- Divino-matic Rod
    [9234] = true,   -- Tiara of the Deep
    [8444] = true,   -- Executioner's Key
    [12845] = true,  -- Medallion of Faith (in Malor's Strongbox, not his drop)
    [10420] = true,  -- Skull of the Coldbringer
}
for dungeonName, dungeon in pairs(db) do
    -- The incomplete-data warning was specific to development; remove it from
    -- every TBC Anniversary dungeon/wing (including the original ten).
    dungeon.fullItemsTBD = nil
    dungeon.itemsTBD = nil
    local excluded = questOnlyBosses[dungeonName]
    for i = #(dungeon.bosses or {}), 1, -1 do
        local boss = dungeon.bosses[i]
        if excluded and excluded[boss.name] then
            table.remove(dungeon.bosses, i)
        else
            for j = #(boss.loot or {}), 1, -1 do
                local item = boss.loot[j]
                if item and questLoot[item[1]] then table.remove(boss.loot, j) end
            end
        end
    end
end

-- Herod (NPC 3975) is a human Scarlet Champion, CreatureDisplayID 2041.
-- Use Blizzard's actual live 2D NPC portrait generated from the correct model,
-- never the temporary screenshot-based image or saved stale goblin cache.
local armory = db["Scarlet Monastery: Armory"]
if armory then
    for _, boss in ipairs(armory.bosses or {}) do
        if boss.npcID == 3975 then
            boss.customIcon = nil
            boss.displayID = 2041
        end
    end
end
FDJ.STATIC_DISPLAY_IDS[3975] = 2041
if type(_G.ForeverDungeonJournalDB) == "table" then
    local saved = _G.ForeverDungeonJournalDB
    if type(saved.displayIDCache) == "table" then saved.displayIDCache[3975] = nil end
    if type(saved.portraitTexturesByNpcID) == "table" then saved.portraitTexturesByNpcID[3975] = nil end
end

-- Real gameobject (Gordok Tribute, object ID 179564), not an NPC.
-- After King Gordok dies, Mizzle the Crafty places this chest. Its contents
-- depend on the Tribute Run: ONE item from the tribute pool for each of the
-- five bosses still alive (Guard Mol'dar, Guard Fengus, Guard Slip'kik,
-- Captain Kromcrush, Cho'Rush the Observer), so a clean run yields five
-- items and every kill removes one. Stomper Kreeg does not count. The four
-- consumables are always inside; with all five bosses dead they are all the
-- chest holds. The items are not tied to particular survivors.
local north = db["Dire Maul: North"]
if north then
    local TRIBUTE_POOL = {
        {18538, "Treant's Bane", "Item", 4},
        {18499, "Barrier Shield", "Item", 3},
        {18537, "Counterattack Lodestone", "Item", 3},
        {18528, "Cyclone Spaulders", "Item", 3},
        {18529, "Elemental Plate Girdle", "Item", 3},
        {18533, "Gordok Bracers of Power", "Item", 3},
        {18532, "Mindsurge Robe", "Item", 3},
        {18530, "Ogre Forged Hauberk", "Item", 3},
        {18495, "Redoubt Cloak", "Item", 3},
        {18534, "Rod of the Ogre Magi", "Item", 3},
        {18500, "Tarnished Elven Ring", "Item", 3},
        {18531, "Unyielding Maul", "Item", 3},
        {18479, "Carrion Scorpid Helm", "Item", 3},
        {18478, "Hyena Hide Jerkin", "Item", 3},
        {18476, "Mud Stained Boots", "Item", 3},
        {18475, "Oddly Magical Belt", "Item", 3},
        {18482, "Ogre Toothpick Shooter", "Item", 3},
        {18480, "Scarab Plate Helm", "Item", 3},
        {18655, "Schematic: Major Recombobulator", "Item", 3},
        {18477, "Shaggy Leggings", "Item", 3},
        {18481, "Skullcracking Mace", "Item", 3},
    }
    local ALWAYS = {
        {13446, "Major Healing Potion", "Item", 1},
        {13444, "Major Mana Potion", "Item", 1},
        {8766, "Morning Glory Dew", "Item", 1},
        {8952, "Roasted Quail", "Item", 1},
    }
    local poolIDs, alwaysIDs, loot = {}, {}, {}
    for _, item in ipairs(TRIBUTE_POOL) do loot[#loot + 1] = item; poolIDs[#poolIDs + 1] = item[1] end
    for _, item in ipairs(ALWAYS) do loot[#loot + 1] = item; alwaysIDs[#alwaysIDs + 1] = item[1] end
    local chest = {
        name = "Gordok Tribute Chest",
        treasureChest = true,
        chestLabel = "Treasure Chest | 1 item per boss left alive (up to 5)",
        customIcon = "Interface\\Icons\\INV_Box_01",
        loot = loot,
        lootSections = {
            { title = "One per guard left alive", ids = poolIDs },
            { title = "Always inside (all you get if every boss is dead)", ids = alwaysIDs },
        },
    }
    local replaced = false
    for i, boss in ipairs(north.bosses or {}) do
        if boss.name == chest.name then north.bosses[i] = chest; replaced = true; break end
    end
    if not replaced then table.insert(north.bosses, chest) end
end
