local _, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS

-- Boss drops that roll a random "of the ..." enchant. Source: item_template
-- (RandomProperty / RandomSuffix), checked against every loot
-- table in the journal (31 Oct 2026). The tooltip shows the translated
-- "+Random Enchant" line (RANDOM_ENCHANT) above "Requires Level".
FDJ.RANDOM_ENCHANT_ITEMS = FDJ.RANDOM_ENCHANT_ITEMS or {}
for _, id in ipairs({
    9387, -- Revelosh's Boots (Revelosh, Uldaman)
    9388, -- Revelosh's Armguards (Revelosh, Uldaman)
    9389, -- Revelosh's Spaulders (Revelosh, Uldaman)
    9390, -- Revelosh's Gloves (Revelosh, Uldaman)
    9409, -- Ironaya's Bracers (Ironaya, Uldaman)
    9410, -- Cragfists (Ancient Stone Keeper, Uldaman)
    9455, -- Emissary Cuffs (Dark Iron Ambassador, Gnomeregan)
    9461, -- Charged Gear (Mekgineer Thermaplugg, Gnomeregan)
    9640, -- Vice Grips (Antu'sul, Zul'Farrak)
    10777, -- Arachnid Gloves (Tuten'kash, Razorfen Downs)
    10795, -- Drakeclaw Band (Dreamscythe, The Temple of Atal'Hakkar)
    10796, -- Drakestone (Dreamscythe, The Temple of Atal'Hakkar)
    10800, -- Darkwater Bracers (Atal'alarion, The Temple of Atal'Hakkar)
    10828, -- Dire Nail (Shade of Eranikus, The Temple of Atal'Hakkar)
    11118, -- Archaedic Stone (Archaedas, Uldaman)
    11764, -- Cinderhide Armsplints (Lord Incendius, Blackrock Depths)
    11765, -- Pyremail Wristguards (Lord Incendius, Blackrock Depths)
    11766, -- Flameweave Cuffs (Lord Incendius, Blackrock Depths)
    11767, -- Emberplate Armguards (Lord Incendius, Blackrock Depths)
    11934, -- Emperor's Seal (Emperor Dagran Thaurissan, Blackrock Depths)
    12926, -- Flaming Band (Pyroguard Emberseer, Upper Blackrock Spire)
    12952, -- Gyth's Skull (Gyth, Upper Blackrock Spire)
    12953, -- Dragoneye Coif (Gyth, Upper Blackrock Spire)
    12960, -- Tribal War Feathers (Gyth, Upper Blackrock Spire)
    13258, -- Slaghide Gauntlets (Urok Doomhowl, Lower Blackrock Spire)
    13386, -- Archivist Cape (Archivist Galford, Stratholme: Living)
    13387, -- Foresight Girdle (Archivist Galford, Stratholme: Living)
    13409, -- Tearfall Bracers (The Unforgiven, Stratholme: Living)
    18319, -- Fervent Helm (Zevrim Thornhoof, Dire Maul: East)
    18382, -- Fluctuating Cloak (Prince Tortheldrin, Dire Maul: West)
    18529, -- Elemental Plate Girdle (Gordok Tribute Chest, Dire Maul: North)
    19921, -- Zulian Hacker (Raid Trash, Zul'Gurub)
    22225, -- Dragonskin Cowl (Gyth, Upper Blackrock Spire)
}) do FDJ.RANDOM_ENCHANT_ITEMS[id] = true end

local function MarkLoot(list)
    for _, item in ipairs(list or {}) do
        if type(item) == "table" and FDJ.RANDOM_ENCHANT_ITEMS[item[1]] then
            item[5] = item[5] or ""
            item[6] = "RANDOM_ENCHANT"
        end
    end
end

local function MarkBosses(bosses)
    for _, boss in ipairs(bosses or {}) do
        MarkLoot(boss.loot)
        MarkLoot(boss.trashLoot)
    end
end

function FDJ.ApplyRandomEnchantHints()
    for _, dungeon in pairs(FDJ.DB or {}) do
        MarkBosses(dungeon.bosses)
        if type(dungeon.heroic) == "table" then MarkBosses(dungeon.heroic.bosses) end
    end
end

-- Runs after every Data file has loaded, and again at login in case a later
-- file rebuilt a loot table.
FDJ.ApplyRandomEnchantHints()
local f = CreateFrame and CreateFrame("Frame")
if f then
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function() pcall(FDJ.ApplyRandomEnchantHints) end)
end
