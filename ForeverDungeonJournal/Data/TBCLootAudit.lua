-- Dungeon Journal: TBC Anniversary loot audit (v1.6.14.5).
-- Boss drops found missing by comparing every boss against AtlasLootClassic
-- (TBC). Quest items, keys, holiday drops and quest-starting items are left
-- out on purpose. Only adds an item if the boss does not already list it.
local _, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS
if not FDJ or not FDJ.IS_TBC_ANNIVERSARY or not FDJ.DB then return end

local ADD = {
    { "Blackrock Depths", "Lord Roccor", {
        {11813, "Formula: Smoking Heart of the Mountain", "Item", 3},
    } },
    { "Blackrock Depths", "Grizzle", {
        {11610, "Plans: Dark Iron Pulverizer", "Item", 3},
    } },
    { "Blackrock Depths", "Lord Incendius", {
        {19268, "Ace of Elementals", "Item", 3},
    } },
    { "Blackrock Depths", "Fineous Darkvire", {
        {11840, "Master Builder's Shirt", "Item", 3},
    } },
    { "Blackrock Depths", "General Angerforge", {
        {11841, "Senior Designer's Pantaloons", "Item", 3},
    } },
    { "Blackrock Depths", "Ambassador Flamelash", {
        {23320, "Tablet of Flame Shock VI", "Item", 3},
    } },
    { "Blackrock Depths", "Emperor Dagran Thaurissan", {
        {12033, "Thaurissan Family Jewels", "Item", 3},
    } },
    { "Dire Maul: North", "King Gordok", {
        {19258, "Ace of Warlords", "Item", 3},
    } },
    { "Dire Maul: North", "Guard Mol'dar", {
        {18450, "Robe of Combustion", "Item", 3},
        {18458, "Modest Armguards", "Item", 3},
        {18459, "Gallant's Wristguards", "Item", 3},
        {18451, "Hyena Hide Belt", "Item", 3},
        {18462, "Jagged Bone Fist", "Item", 3},
        {18463, "Ogre Pocket Knife", "Item", 3},
        {18464, "Gordok Nose Ring", "Item", 3},
        {18460, "Unsophisticated Hand Cannon", "Item", 3},
    } },
    { "Dire Maul: North", "Guard Fengus", {
        {18464, "Gordok Nose Ring", "Item", 3},
        {18460, "Unsophisticated Hand Cannon", "Item", 3},
    } },
    { "Dire Maul: North", "Guard Slip'kik", {
        {18464, "Gordok Nose Ring", "Item", 3},
        {18460, "Unsophisticated Hand Cannon", "Item", 3},
    } },
    { "Dire Maul: West", "Magister Kalendris", {
        {22309, "Pattern: Big Bag of Enchantment", "Item", 3},
    } },
    { "Gnomeregan", "Mekgineer Thermaplugg", {
        {4415, "Schematic: Craftsman's Monocle", "Item", 3},
        {4413, "Schematic: Discombobulator Ray", "Item", 3},
        {4411, "Schematic: Flame Deflector", "Item", 3},
        {7742, "Schematic: Gnomish Cloaking Device", "Item", 3},
        {11828, "Schematic: Pet Bombling", "Item", 3},
    } },
    { "Scholomance", "Ras Frostwhisper", {
        {13521, "Recipe: Flask of Supreme Power", "Item", 3},
    } },
    { "Scholomance", "Darkmaster Gandling", {
        {19276, "Ace of Portals", "Item", 3},
        {13501, "Recipe: Major Mana Potion", "Item", 3},
    } },
    { "Stratholme: Living", "Cannon Master Willey", {
        {12839, "Plans: Heartseeker", "Item", 3},
    } },
    { "Stratholme: Living", "Archivist Galford", {
        {22897, "Tome of Conjure Food VII", "Item", 3},
    } },
    { "Stratholme: Living", "Balnazzar", {
        {13520, "Recipe: Flask of Distilled Wisdom", "Item", 3},
    } },
    { "Stratholme: Undead", "Maleki the Pallid", {
        {12833, "Plans: Hammer of the Titans", "Item", 3},
    } },
    { "Stratholme: Undead", "Baron Rivendare", {
        {16732, "Legplates of Valor", "Item", 3},
    } },
    { "The Temple of Atal'Hakkar", "Dreamscythe", {
        {12463, "Drakefang Butcher", "Item", 3},
        {12243, "Smoldering Claw", "Item", 3},
        {10795, "Drakeclaw Band", "Item", 3},
        {10796, "Drakestone", "Item", 3},
    } },
    { "The Temple of Atal'Hakkar", "Hazzas", {
        {12463, "Drakefang Butcher", "Item", 3},
        {12243, "Smoldering Claw", "Item", 3},
        {10795, "Drakeclaw Band", "Item", 3},
        {10796, "Drakestone", "Item", 3},
    } },
    { "The Temple of Atal'Hakkar", "Weaver", {
        {12465, "Nightfall Drape", "Item", 3},
        {12466, "Dawnspire Cord", "Item", 3},
        {12464, "Bloodfire Talons", "Item", 3},
        {10797, "Firebreather", "Item", 3},
    } },
    { "The Temple of Atal'Hakkar", "Morphaz", {
        {12465, "Nightfall Drape", "Item", 3},
        {12466, "Dawnspire Cord", "Item", 3},
        {12464, "Bloodfire Talons", "Item", 3},
        {10797, "Firebreather", "Item", 3},
    } },
    { "Uldaman", "Eric \"The Swift\"", {
        {2459, "Swiftness Potion", "Item", 3},
    } },
    { "Uldaman", "Olaf", {
        {1177, "Oil of Olaf", "Item", 3},
    } },
    { "Upper Blackrock Spire", "Pyroguard Emberseer", {
        {23320, "Tablet of Flame Shock VI", "Item", 3},
    } },
    { "Upper Blackrock Spire", "Solakar Flamewreath", {
        {18657, "Schematic: Hyper-Radiant Flame Reflector", "Item", 3},
    } },
    { "Upper Blackrock Spire", "Goraluk Anvilcrack", {
        {12696, "Plans: Demon Forged Breastplate", "Item", 3},
    } },
    { "Upper Blackrock Spire", "Gyth", {
        {13522, "Recipe: Flask of Chromatic Resistance", "Item", 3},
    } },
    { "Upper Blackrock Spire", "The Beast", {
        {24101, "Book of Ferocious Bite V", "Item", 3},
        {19227, "Ace of Beasts", "Item", 3},
    } },
}

for _, entry in ipairs(ADD) do
    local d = FDJ.DB[entry[1]]
    for _, boss in ipairs(d and d.bosses or {}) do
        if boss.name == entry[2] then
            boss.loot = boss.loot or {}
            local have = {}
            for _, item in ipairs(boss.loot) do have[item[1]] = true end
            for _, item in ipairs(entry[3]) do
                if not have[item[1]] then boss.loot[#boss.loot + 1] = item; have[item[1]] = true end
            end
        end
    end
end

-- Bosses with no boss-specific drops in TBC (they only drop random world items).
FDJ.NO_UNIQUE_LOOT = FDJ.NO_UNIQUE_LOOT or {}
for _, key in ipairs({
    "Ragefire Chasm|Oggleflint", "Ragefire Chasm|Bazzalan", "Blackfathom Deeps|Lorgus Jett",
    "Razorfen Kraul|Roogug", "The Stockade|Targorr the Dread", "The Stockade|Hamhock",
    "The Stockade|Dextren Ward", "The Stockade|Bazil Thredd",
}) do FDJ.NO_UNIQUE_LOOT[key] = true end

-- Mob-specific trash drops: an item that only drops from certain trash goes in
-- that dungeon's "Trash Drops" list with the mob names as its source line,
-- and is removed from every other list (same logic as Ruins of Lordaeron).
do
    local MOB_ONLY = {
        -- [itemID] = { dungeon, mob names }
        [10329] = { "Scarlet Monastery: Armory", "Scarlet Defender / Scarlet Myrmidon" }, -- Scarlet Belt
    }
    for itemID, rule in pairs(MOB_ONLY) do
        local entry
        for _, dungeon in pairs(FDJ.DB or {}) do
            for _, boss in ipairs(dungeon.bosses or {}) do
                local loot = boss.loot or {}
                for i = #loot, 1, -1 do
                    if loot[i][1] == itemID then
                        entry = entry or loot[i]
                        table.remove(loot, i)
                    end
                end
            end
        end
        local target = FDJ.DB and FDJ.DB[rule[1]]
        if target and entry then
            local trash
            for _, boss in ipairs(target.bosses or {}) do
                if boss.trash then trash = boss end
            end
            if not trash then
                trash = { name = "Trash Drops", trash = true, loot = {} }
                target.bosses = target.bosses or {}
                table.insert(target.bosses, trash)
            end
            trash.loot = trash.loot or {}
            table.insert(trash.loot, { entry[1], entry[2], entry[3], entry[4], rule[2] })
        end
    end
end
