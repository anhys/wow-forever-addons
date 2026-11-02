-- Dungeon Journal - Classic Era: creature levels of the Vanilla dungeon bosses.
-- Generated from the Classic Era (1.15) creature database on 2026-10-30 and
-- cross-checked against the TBC Anniversary values the TBC edition ships:
-- patch 2.3 lowered most Vanilla dungeon bosses by one to seven levels, so
-- the TBC file (Data/TBCBossLevels.lua) must NOT be used on Era.
-- Raid bosses keep the "??" badge set by Data/VanillaRaids.lua. Upper
-- Blackrock Spire's 10-player bosses keep "??" as in the TBC edition.
-- These are NPC levels, not dungeon level ranges. Loaded after
-- TBCBossLevels.lua so every Vanilla entry below replaces the TBC value.
local _, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS
if not FDJ or not FDJ.IS_CLASSIC_ERA then return end
FDJ.BOSS_LEVELS = FDJ.BOSS_LEVELS or {}

-- Ragefire Chasm
FDJ.BOSS_LEVELS["Ragefire Chasm"] = {
    ["Oggleflint"] = "16", -- npc 11517
    ["Taragaman the Hungerer"] = "16", -- npc 11520
    ["Jergosh the Invoker"] = "16", -- npc 11518
    ["Bazzalan"] = "16", -- npc 11519
    ["Zelemar the Wrathful"] = "20", -- carried over from TBC file (not in boss list)
}

-- The Deadmines
FDJ.BOSS_LEVELS["The Deadmines"] = {
    ["Rhahk'Zor"] = "19", -- npc 644
    ["Miner Johnson"] = "19", -- npc 3586
    ["Sneed's Shredder"] = "20", -- npc 642
    ["Sneed"] = "20", -- npc 643
    ["Gilnid"] = "20", -- npc 1763
    ["Mr. Smite"] = "20", -- npc 646
    ["Captain Greenskin"] = "20", -- npc 647
    ["Edwin VanCleef"] = "21", -- npc 639, TBC 20
    ["Cookie"] = "20", -- npc 645
}

-- Wailing Caverns
FDJ.BOSS_LEVELS["Wailing Caverns"] = {
    ["Lord Cobrahn"] = "20", -- npc 3669
    ["Lady Anacondra"] = "20", -- npc 3671
    ["Kresh"] = "20", -- npc 3653
    ["Lord Pythas"] = "21", -- npc 3670, TBC 20
    ["Skum"] = "21", -- npc 3674, TBC 20
    ["Lord Serpentis"] = "21", -- npc 3673, TBC 20
    ["Verdan the Everliving"] = "21", -- npc 5775, TBC 20
    ["Mutanus the Devourer"] = "22", -- npc 3654, TBC 20
    ["Deviate Faerie Dragon"] = "20", -- npc 5912, TBC 19
}

-- Shadowfang Keep
FDJ.BOSS_LEVELS["Shadowfang Keep"] = {
    ["Rethilgore"] = "20", -- npc 3914
    ["Razorclaw the Butcher"] = "22", -- npc 3886, TBC 20
    ["Baron Silverlaine"] = "24", -- npc 3887, TBC 20
    ["Commander Springvale"] = "24", -- npc 4278, TBC 20
    ["Odo the Blindwatcher"] = "24", -- npc 4279, TBC 21
    ["Deathsworn Captain"] = "25", -- npc 3872, TBC 21
    ["Fenrus the Devourer"] = "25", -- npc 4274, TBC 21
    ["Wolf Master Nandos"] = "25", -- npc 3927, TBC 21
    ["Archmage Arugal"] = "26", -- npc 4275, TBC 21
}

-- Blackfathom Deeps
FDJ.BOSS_LEVELS["Blackfathom Deeps"] = {
    ["Ghamoo-ra"] = "25", -- npc 4887, TBC 23
    ["Lady Sarevess"] = "25", -- npc 4831, TBC 23
    ["Gelihast"] = "26", -- npc 6243, TBC 24
    ["Lorgus Jett"] = "26", -- npc 12902, TBC 24
    ["Old Serra'kis"] = "26", -- npc 4830, TBC 24
    ["Twilight Lord Kelris"] = "27", -- npc 4832, TBC 24
    ["Aku'mai"] = "28", -- npc 4829, TBC 24
    ["Baron Aquanis"] = "24", -- carried over from TBC file (not in boss list)
}

-- The Stockade
FDJ.BOSS_LEVELS["The Stockade"] = {
    ["Targorr the Dread"] = "24", -- npc 1696
    ["Kam Deepfury"] = "27", -- npc 1666, TBC 25
    ["Hamhock"] = "28", -- npc 1717, TBC 25
    ["Dextren Ward"] = "26", -- npc 1663, TBC 25
    ["Bazil Thredd"] = "29", -- npc 1716, TBC 25
    ["Bruegal Ironknuckle"] = "26", -- npc 1720, TBC 25
}

-- Gnomeregan
FDJ.BOSS_LEVELS["Gnomeregan"] = {
    ["Grubbis"] = "32", -- npc 7361, TBC 28
    ["Viscous Fallout"] = "30", -- npc 7079, TBC 28
    ["Electrocutioner 6000"] = "32", -- npc 6235, TBC 28
    ["Crowd Pummeler 9-60"] = "32", -- npc 6229, TBC 28
    ["Mekgineer Thermaplugg"] = "34", -- npc 7800, TBC 28
    ["Dark Iron Ambassador"] = "33", -- npc 6228, TBC 28
    ["Techbot"] = "26", -- carried over from TBC file (not in boss list)
}

-- Razorfen Kraul
FDJ.BOSS_LEVELS["Razorfen Kraul"] = {
    ["Roogug"] = "28", -- npc 6168, TBC 26
    ["Aggem Thorncurse"] = "30", -- npc 4424, TBC 27
    ["Death Speaker Jargba"] = "30", -- npc 4428, TBC 27
    ["Overlord Ramtusk"] = "32", -- npc 4420, TBC 27
    ["Agathelos the Raging"] = "33", -- npc 4422, TBC 27
    ["Charlga Razorflank"] = "33", -- npc 4421, TBC 27
    ["Blind Hunter"] = "32", -- npc 4425, TBC 27
    ["Earthcaller Halmgar"] = "32", -- npc 4842, TBC 27
}

-- Scarlet Monastery: Graveyard
FDJ.BOSS_LEVELS["Scarlet Monastery: Graveyard"] = {
    ["Interrogator Vishas"] = "32", -- npc 3983
    ["Azshir the Sleepless"] = "33", -- npc 6490, TBC 32
    ["Fallen Champion"] = "33", -- npc 6488, TBC 32
    ["Ironspine"] = "33", -- npc 6489, TBC 32
    ["Bloodmage Thalnos"] = "34", -- npc 4543, TBC 32
}

-- Scarlet Monastery: Library
FDJ.BOSS_LEVELS["Scarlet Monastery: Library"] = {
    ["Houndmaster Loksey"] = "34", -- npc 3974
    ["Arcanist Doan"] = "37", -- npc 6487, TBC 35
}

-- Scarlet Monastery: Armory
FDJ.BOSS_LEVELS["Scarlet Monastery: Armory"] = {
    ["Herod"] = "40", -- npc 3975, TBC 37
}

-- Scarlet Monastery: Cathedral
FDJ.BOSS_LEVELS["Scarlet Monastery: Cathedral"] = {
    ["High Inquisitor Fairbanks"] = "40", -- npc 4542
    ["Scarlet Commander Mograine"] = "42", -- npc 3976, TBC 40
    ["High Inquisitor Whitemane"] = "42", -- npc 3977, TBC 40
}

-- Razorfen Downs
FDJ.BOSS_LEVELS["Razorfen Downs"] = {
    ["Tuten'kash"] = "40", -- npc 7355, TBC 37
    ["Mordresh Fire Eye"] = "39", -- npc 7357, TBC 37
    ["Glutton"] = "40", -- npc 8567, TBC 37
    ["Ragglesnout"] = "40", -- npc 7354, TBC 37
    ["Amnennar the Coldbringer"] = "41", -- npc 7358, TBC 37
    ["Plaguemaw the Rotting"] = "40", -- npc 7356, TBC 37
}

-- Uldaman
FDJ.BOSS_LEVELS["Uldaman"] = {
    ["Eric \"The Swift\""] = "40", -- npc 6907, TBC 39
    ["Baelog"] = "41", -- npc 6906, TBC 39
    ["Olaf"] = "40", -- npc 6908, TBC 39
    ["Revelosh"] = "40", -- npc 6910, TBC 39
    ["Ironaya"] = "40", -- npc 7228, TBC 39
    ["Ancient Stone Keeper"] = "44", -- npc 7206, TBC 40
    ["Galgann Firehammer"] = "45", -- npc 7291, TBC 40
    ["Grimlok"] = "45", -- npc 4854, TBC 40
    ["Archaedas"] = "47", -- npc 2748, TBC 40
    ["Obsidian Sentinel"] = "40", -- carried over from TBC file (not in boss list)
}

-- Zul'Farrak
FDJ.BOSS_LEVELS["Zul'Farrak"] = {
    ["Antu'sul"] = "48", -- npc 8127, TBC 46
    ["Witch Doctor Zum'rah"] = "46", -- npc 7271
    ["Shadowpriest Sezz'ziz"] = "47", -- npc 7275, TBC 46
    ["Dustwraith"] = "45", -- npc 10081, TBC 46
    ["Gahz'rilla"] = "46", -- npc 7273
    ["Chief Ukorz Sandscalp"] = "48", -- npc 7267, TBC 46
    ["Zerillis"] = "45", -- npc 10082
    ["Nekrum Gutchewer"] = "46", -- carried over from TBC file (not in boss list)
    ["Theka the Martyr"] = "46", -- carried over from TBC file (not in boss list)
    ["Hydromancer Velratha"] = "46", -- carried over from TBC file (not in boss list)
    ["Ruuzlu"] = "46", -- carried over from TBC file (not in boss list)
    ["Sergeant Bly"] = "45", -- carried over from TBC file (not in boss list)
    ["Sandarr Dunereaver"] = "45", -- carried over from TBC file (not in boss list)
}

-- Maraudon
FDJ.BOSS_LEVELS["Maraudon"] = {
    ["Noxxion"] = "48", -- npc 13282, TBC 46
    ["Razorlash"] = "48", -- npc 12258, TBC 46
    ["Lord Vyletongue"] = "47", -- npc 12236, TBC 44
    ["Meshlok the Harvester"] = "48", -- npc 12237, TBC 46
    ["Celebras the Cursed"] = "49", -- npc 12225, TBC 46
    ["Landslide"] = "50", -- npc 12203, TBC 48
    ["Tinkerer Gizlock"] = "50", -- npc 13601, TBC 48
    ["Rotgrip"] = "50", -- npc 13596, TBC 48
    ["Princess Theradras"] = "51", -- npc 12201, TBC 48
    ["Isalien"] = "60", -- carried over from TBC file (not in boss list)
}

-- The Temple of Atal'Hakkar
FDJ.BOSS_LEVELS["The Temple of Atal'Hakkar"] = {
    ["Atal'alarion"] = "50", -- npc 8580, TBC 49
    ["Avatar of Hakkar"] = "50", -- npc 8443
    ["Jammal'an the Prophet"] = "54", -- npc 5710, TBC 50
    ["Ogom the Wretched"] = "53", -- npc 5711, TBC 49
    ["Dreamscythe"] = "53", -- npc 5721, TBC 50
    ["Weaver"] = "51", -- npc 5720, TBC 50
    ["Hazzas"] = "53", -- npc 5722, TBC 50
    ["Morphaz"] = "52", -- npc 5719, TBC 50
    ["Shade of Eranikus"] = "55", -- npc 5709, TBC 50
    ["Mijan"] = "49", -- carried over from TBC file (not in boss list)
    ["Zolo"] = "49", -- carried over from TBC file (not in boss list)
    ["Zul'Lor"] = "49", -- carried over from TBC file (not in boss list)
    ["Hukku"] = "49", -- carried over from TBC file (not in boss list)
    ["Loro"] = "49", -- carried over from TBC file (not in boss list)
    ["Gasher"] = "49", -- carried over from TBC file (not in boss list)
}

-- Blackrock Depths
FDJ.BOSS_LEVELS["Blackrock Depths"] = {
    ["Lord Roccor"] = "51", -- npc 9025
    ["High Interrogator Gerstahn"] = "52", -- npc 9018
    ["Houndmaster Grebmar"] = "52", -- npc 9319
    ["Gorosh the Dervish"] = "56", -- npc 9027, TBC 52
    ["Grizzle"] = "54", -- npc 9028, TBC 52
    ["Eviscerator"] = "54", -- npc 9029, TBC 52
    ["Ok'thor the Breaker"] = "53", -- npc 9030, TBC 52
    ["Anub'shiah"] = "54", -- npc 9031, TBC 52
    ["Hedrum the Creeper"] = "53", -- npc 9032, TBC 52
    ["Pyromancer Loregrain"] = "52", -- npc 9024
    ["Bael'Gar"] = "54", -- npc 9016, TBC 52
    ["Lord Incendius"] = "55", -- npc 9017, TBC 53
    ["Fineous Darkvire"] = "54", -- npc 9056, TBC 53
    ["Warder Stilgiss"] = "56", -- npc 9041, TBC 54
    ["General Angerforge"] = "57", -- npc 9033, TBC 55
    ["Golem Lord Argelmach"] = "57", -- npc 8983, TBC 55
    ["Plugger Spazzring"] = "55", -- npc 9499
    ["Phalanx"] = "55", -- npc 9502
    ["Ribbly Screwspigot"] = "53", -- npc 9543
    ["Hurley Blackbreath"] = "55", -- npc 9537
    ["Ambassador Flamelash"] = "57", -- npc 9156, TBC 55
    ["Panzor the Invincible"] = "57", -- npc 8923, TBC 56
    ["Magmus"] = "57", -- npc 9938, TBC 56
    ["Princess Moira Bronzebeard"] = "58", -- npc 8929, TBC 55
    ["Emperor Dagran Thaurissan"] = "59", -- npc 9019, TBC 56
    ["Verek"] = "53", -- carried over from TBC file (not in boss list)
    ["Gloom'rel"] = "56", -- carried over from TBC file (not in boss list)
    ["Doom'rel"] = "56", -- carried over from TBC file (not in boss list)
    ["Hate'rel"] = "55", -- carried over from TBC file (not in boss list)
    ["Seeth'rel"] = "56", -- carried over from TBC file (not in boss list)
    ["Anger'rel"] = "55", -- carried over from TBC file (not in boss list)
    ["Theldren"] = "60", -- carried over from TBC file (not in boss list)
    ["Vile'rel"] = "55", -- carried over from TBC file (not in boss list)
    ["Watchman Doomgrip"] = "54", -- carried over from TBC file (not in boss list)
    ["Dope'rel"] = "56", -- carried over from TBC file (not in boss list)
}

-- Lower Blackrock Spire
FDJ.BOSS_LEVELS["Lower Blackrock Spire"] = {
    ["Burning Felguard"] = "56-57", -- npc 10263
    ["Spirestone Butcher"] = "57", -- npc 9219
    ["Highlord Omokk"] = "59", -- npc 9196, TBC 57
    ["Shadow Hunter Vosh'gajin"] = "58", -- npc 9236
    ["War Master Voone"] = "58", -- npc 9237
    ["Bannok Grimaxe"] = "59", -- npc 9596
    ["Mother Smolderweb"] = "59", -- npc 10596
    ["Urok Doomhowl"] = "60", -- npc 10584
    ["Quartermaster Zigris"] = "59", -- npc 9736
    ["Halycon"] = "59", -- npc 10220
    ["Gizrul the Slavener"] = "60", -- npc 10268
    ["Overlord Wyrmthalak"] = "60", -- npc 9568
    ["Spirestone Battle Lord"] = "58", -- npc 9218
    ["Spirestone Lord Magus"] = "58", -- npc 9217
    ["Crystal Fang"] = "60", -- npc 10376
    ["Ghok Bashguud"] = "59", -- npc 9718
    ["Mor Grayhoof"] = "60", -- carried over from TBC file (not in boss list)
}

-- Upper Blackrock Spire
FDJ.BOSS_LEVELS["Upper Blackrock Spire"] = {
    ["Pyroguard Emberseer"] = "??", -- npc 9816
    ["Solakar Flamewreath"] = "60", -- npc 10264
    ["Jed Runewatcher"] = "59", -- npc 10509
    ["Goraluk Anvilcrack"] = "61", -- npc 10899
    ["Gyth"] = "62", -- npc 10339
    ["Warchief Rend Blackhand"] = "??", -- npc 10429
    ["The Beast"] = "??", -- npc 10430
    ["General Drakkisath"] = "??", -- npc 10363
    ["Lord Valthalak"] = "??", -- carried over from TBC file (not in boss list)
}

-- Dire Maul: East
FDJ.BOSS_LEVELS["Dire Maul: East"] = {
    ["Pusillin"] = "57", -- npc 14354
    ["Zevrim Thornhoof"] = "57", -- npc 11490
    ["Hydrospawn"] = "57", -- npc 13280
    ["Lethtendris"] = "57", -- npc 14327
    ["Alzzin the Wildshaper"] = "58", -- npc 11492
    ["Isalien"] = "60", -- carried over from TBC file (not in boss list)
}

-- Dire Maul: West
FDJ.BOSS_LEVELS["Dire Maul: West"] = {
    ["Tendris Warpwood"] = "60", -- npc 11489
    ["Illyanna Ravenoak"] = "60", -- npc 11488
    ["Magister Kalendris"] = "60", -- npc 11487
    ["Tsu'zee"] = "59", -- npc 11467
    ["Immol'thar"] = "61", -- npc 11496
    ["Prince Tortheldrin"] = "61", -- npc 11486
    ["Lord Hel'nurath"] = "62", -- npc 14506
}

-- Dire Maul: North
FDJ.BOSS_LEVELS["Dire Maul: North"] = {
    ["Guard Mol'dar"] = "59", -- npc 14326
    ["Stomper Kreeg"] = "59", -- npc 14322
    ["Guard Fengus"] = "59", -- npc 14321
    ["Guard Slip'kik"] = "59", -- npc 14323
    ["Captain Kromcrush"] = "61", -- npc 14325
    ["Cho'Rush the Observer"] = "60", -- npc 14324
    ["King Gordok"] = "62", -- npc 11501
}

-- Scholomance
FDJ.BOSS_LEVELS["Scholomance"] = {
    ["Kirtonos the Herald"] = "60", -- npc 10506
    ["Jandice Barov"] = "61", -- npc 10503
    ["Rattlegore"] = "61", -- npc 11622
    ["Marduk Blackpool"] = "58", -- npc 10433
    ["Vectus"] = "60", -- npc 10432
    ["Ras Frostwhisper"] = "62", -- npc 10508
    ["Instructor Malicia"] = "60", -- npc 10505
    ["Doctor Theolen Krastinov"] = "60", -- npc 11261
    ["Lorekeeper Polkelt"] = "60", -- npc 10901
    ["The Ravenian"] = "60", -- npc 10507
    ["Lord Alexei Barov"] = "60", -- npc 10504
    ["Lady Illucia Barov"] = "60", -- npc 10502
    ["Darkmaster Gandling"] = "61", -- npc 1853
    ["Death Knight Darkreaver"] = "62", -- npc 14516
    ["Kormok"] = "60", -- carried over from TBC file (not in boss list)
    ["Blood Steward of Kirtonos"] = "57", -- carried over from TBC file (not in boss list)
}

-- Stratholme: Living
FDJ.BOSS_LEVELS["Stratholme: Living"] = {
    ["Skul"] = "58", -- npc 10393
    ["The Unforgiven"] = "57", -- npc 10516
    ["Hearthsinger Forresten"] = "57", -- npc 10558
    ["Timmy the Cruel"] = "58", -- npc 10808
    ["Cannon Master Willey"] = "60", -- npc 10997
    ["Archivist Galford"] = "60", -- npc 10811
    ["Balnazzar"] = "62", -- npc 10813
    ["Postmaster Malown"] = "60", -- npc 11143
    ["Grand Crusader Dathrohan / Balnazzar"] = "62", -- carried over from TBC file (not in boss list)
    ["Malor the Zealous"] = "60", -- carried over from TBC file (not in boss list)
    ["Ezra Grimm"] = "60", -- carried over from TBC file (not in boss list)
    ["Sothos"] = "60", -- carried over from TBC file (not in boss list)
    ["Crimson Hammersmith"] = "60", -- carried over from TBC file (not in boss list)
    ["Jarien"] = "60", -- carried over from TBC file (not in boss list)
}

-- Stratholme: Undead
FDJ.BOSS_LEVELS["Stratholme: Undead"] = {
    ["Stonespine"] = "60", -- npc 10809
    ["Baroness Anastari"] = "59", -- npc 10436
    ["Nerub'enkan"] = "60", -- npc 10437
    ["Maleki the Pallid"] = "61", -- npc 10438
    ["Magistrate Barthilas"] = "58", -- npc 10435
    ["Ramstein the Gorger"] = "61", -- npc 10439
    ["Baron Rivendare"] = "62", -- npc 10440
    ["Black Guard Swordsmith"] = "61-62", -- carried over from TBC file (not in boss list)
}
