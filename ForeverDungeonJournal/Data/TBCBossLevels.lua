-- Dungeon Journal v1.6.10: TBC Anniversary creature levels.
-- Vanilla levels are transcribed from TBC_Vanilla_Dungeons_All_Boss_Levels.pdf
-- (20 October 2026, 11 pages). These are NPC levels, not dungeon ranges.
-- Outland values are NORMAL difficulty; do not substitute Heroic level 72.
-- Bosses hidden because they are quest-only remain hidden. Chest/trash
-- entries intentionally have no boss-level badge.
local _, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS
if not FDJ or not FDJ.IS_TBC_ANNIVERSARY then return end
FDJ.BOSS_LEVELS = FDJ.BOSS_LEVELS or {}

-- Vanilla: Ragefire Chasm
FDJ.BOSS_LEVELS["Ragefire Chasm"] = {
    ["Oggleflint"] = "16",
    ["Taragaman the Hungerer"] = "16",
    ["Jergosh the Invoker"] = "16",
    ["Bazzalan"] = "16",
    ["Zelemar the Wrathful"] = "20",
}

-- Vanilla: Wailing Caverns
FDJ.BOSS_LEVELS["Wailing Caverns"] = {
    ["Lady Anacondra"] = "20",
    ["Lord Cobrahn"] = "20",
    ["Lord Pythas"] = "20",
    ["Lord Serpentis"] = "20",
    ["Kresh"] = "20",
    ["Skum"] = "20",
    ["Verdan the Everliving"] = "20",
    ["Mutanus the Devourer"] = "20",
    ["Deviate Faerie Dragon"] = "19",
}

-- Vanilla: The Deadmines
FDJ.BOSS_LEVELS["The Deadmines"] = {
    ["Rhahk'Zor"] = "19",
    ["Sneed's Shredder"] = "20",
    ["Sneed"] = "20",
    ["Gilnid"] = "20",
    ["Mr. Smite"] = "20",
    ["Captain Greenskin"] = "20",
    ["Cookie"] = "20",
    ["Edwin VanCleef"] = "20",
    ["Miner Johnson"] = "19",
}

-- Vanilla: Shadowfang Keep
FDJ.BOSS_LEVELS["Shadowfang Keep"] = {
    ["Rethilgore"] = "20",
    ["Razorclaw the Butcher"] = "20",
    ["Baron Silverlaine"] = "20",
    ["Commander Springvale"] = "20",
    ["Odo the Blindwatcher"] = "21",
    ["Fenrus the Devourer"] = "21",
    ["Wolf Master Nandos"] = "21",
    ["Archmage Arugal"] = "21",
    ["Deathsworn Captain"] = "21",
}

-- Vanilla: Blackfathom Deeps
FDJ.BOSS_LEVELS["Blackfathom Deeps"] = {
    ["Ghamoo-ra"] = "23",
    ["Lady Sarevess"] = "23",
    ["Gelihast"] = "24",
    ["Lorgus Jett"] = "24",
    ["Twilight Lord Kelris"] = "24",
    ["Old Serra'kis"] = "24",
    ["Aku'mai"] = "24",
    ["Baron Aquanis"] = "24",
}

-- Vanilla: The Stockade
FDJ.BOSS_LEVELS["The Stockade"] = {
    ["Targorr the Dread"] = "24",
    ["Kam Deepfury"] = "25",
    ["Hamhock"] = "25",
    ["Dextren Ward"] = "25",
    ["Bazil Thredd"] = "25",
    ["Bruegal Ironknuckle"] = "25",
}

-- Vanilla: Razorfen Kraul
FDJ.BOSS_LEVELS["Razorfen Kraul"] = {
    ["Roogug"] = "26",
    ["Aggem Thorncurse"] = "27",
    ["Death Speaker Jargba"] = "27",
    ["Overlord Ramtusk"] = "27",
    ["Agathelos the Raging"] = "27",
    ["Charlga Razorflank"] = "27",
    ["Blind Hunter"] = "27",
    ["Earthcaller Halmgar"] = "27",
}

-- Vanilla: Gnomeregan
FDJ.BOSS_LEVELS["Gnomeregan"] = {
    ["Grubbis"] = "28",
    ["Viscous Fallout"] = "28",
    ["Electrocutioner 6000"] = "28",
    ["Crowd Pummeler 9-60"] = "28",
    ["Mekgineer Thermaplugg"] = "28",
    ["Dark Iron Ambassador"] = "28",
    ["Techbot"] = "26",
}

-- Vanilla: Scarlet Monastery: Graveyard
FDJ.BOSS_LEVELS["Scarlet Monastery: Graveyard"] = {
    ["Interrogator Vishas"] = "32",
    ["Bloodmage Thalnos"] = "32",
    ["Ironspine"] = "32",
    ["Azshir the Sleepless"] = "32",
    ["Fallen Champion"] = "32",
}

-- Vanilla: Scarlet Monastery: Library
FDJ.BOSS_LEVELS["Scarlet Monastery: Library"] = {
    ["Houndmaster Loksey"] = "34",
    ["Arcanist Doan"] = "35",
}

-- Vanilla: Scarlet Monastery: Armory
FDJ.BOSS_LEVELS["Scarlet Monastery: Armory"] = {
    ["Herod"] = "37",
}

-- Vanilla: Scarlet Monastery: Cathedral
FDJ.BOSS_LEVELS["Scarlet Monastery: Cathedral"] = {
    ["Scarlet Commander Mograine"] = "40",
    ["High Inquisitor Whitemane"] = "40",
    ["High Inquisitor Fairbanks"] = "40",
}

-- Vanilla: Razorfen Downs
FDJ.BOSS_LEVELS["Razorfen Downs"] = {
    ["Tuten'kash"] = "37",
    ["Mordresh Fire Eye"] = "37",
    ["Glutton"] = "37",
    ["Amnennar the Coldbringer"] = "37",
    ["Ragglesnout"] = "37",
    ["Plaguemaw the Rotting"] = "37",
}

-- Vanilla: Uldaman
FDJ.BOSS_LEVELS["Uldaman"] = {
    ["Revelosh"] = "39",
    ["Baelog"] = "39",
    ["Eric \"The Swift\""] = "39",
    ["Olaf"] = "39",
    ["Ironaya"] = "39",
    ["Obsidian Sentinel"] = "40",
    ["Ancient Stone Keeper"] = "40",
    ["Galgann Firehammer"] = "40",
    ["Grimlok"] = "40",
    ["Archaedas"] = "40",
}

-- Vanilla: Zul'Farrak
FDJ.BOSS_LEVELS["Zul'Farrak"] = {
    ["Antu'sul"] = "46",
    ["Theka the Martyr"] = "46",
    ["Witch Doctor Zum'rah"] = "46",
    ["Nekrum Gutchewer"] = "46",
    ["Shadowpriest Sezz'ziz"] = "46",
    ["Hydromancer Velratha"] = "46",
    ["Gahz'rilla"] = "46",
    ["Ruuzlu"] = "46",
    ["Chief Ukorz Sandscalp"] = "46",
    ["Sergeant Bly"] = "45",
    ["Sandarr Dunereaver"] = "45",
    ["Zerillis"] = "45",
    ["Dustwraith"] = "46",
}

-- Vanilla: Maraudon
FDJ.BOSS_LEVELS["Maraudon"] = {
    ["Lord Vyletongue"] = "44",
    ["Noxxion"] = "46",
    ["Razorlash"] = "46",
    ["Celebras the Cursed"] = "46",
    ["Meshlok the Harvester"] = "46",
    ["Landslide"] = "48",
    ["Tinkerer Gizlock"] = "48",
    ["Rotgrip"] = "48",
    ["Princess Theradras"] = "48",
    ["Isalien"] = "60",
}

-- Vanilla: The Temple of Atal'Hakkar
FDJ.BOSS_LEVELS["The Temple of Atal'Hakkar"] = {
    ["Atal'alarion"] = "49",
    ["Gasher"] = "49",
    ["Hukku"] = "49",
    ["Loro"] = "49",
    ["Mijan"] = "49",
    ["Zolo"] = "49",
    ["Zul'Lor"] = "49",
    ["Ogom the Wretched"] = "49",
    ["Jammal'an the Prophet"] = "50",
    ["Dreamscythe"] = "50",
    ["Weaver"] = "50",
    ["Hazzas"] = "50",
    ["Morphaz"] = "50",
    ["Avatar of Hakkar"] = "50",
    ["Shade of Eranikus"] = "50",
}

-- Vanilla: Blackrock Depths
FDJ.BOSS_LEVELS["Blackrock Depths"] = {
    ["Lord Roccor"] = "51",
    ["High Interrogator Gerstahn"] = "52",
    ["Houndmaster Grebmar"] = "52",
    ["Bael'Gar"] = "52",
    ["Pyromancer Loregrain"] = "52",
    ["Gorosh the Dervish"] = "52",
    ["Grizzle"] = "52",
    ["Eviscerator"] = "52",
    ["Ok'thor the Breaker"] = "52",
    ["Anub'shiah"] = "52",
    ["Hedrum the Creeper"] = "52",
    ["Lord Incendius"] = "53",
    ["Fineous Darkvire"] = "53",
    ["Ribbly Screwspigot"] = "53",
    ["Verek"] = "53",
    ["Warder Stilgiss"] = "54",
    ["Watchman Doomgrip"] = "54",
    ["General Angerforge"] = "55",
    ["Golem Lord Argelmach"] = "55",
    ["Hurley Blackbreath"] = "55",
    ["Plugger Spazzring"] = "55",
    ["Phalanx"] = "55",
    ["Ambassador Flamelash"] = "55",
    ["Hate'rel"] = "55",
    ["Anger'rel"] = "55",
    ["Vile'rel"] = "55",
    ["Gloom'rel"] = "56",
    ["Seeth'rel"] = "56",
    ["Dope'rel"] = "56",
    ["Doom'rel"] = "56",
    ["Panzor the Invincible"] = "56",
    ["Magmus"] = "56",
    ["Princess Moira Bronzebeard"] = "55",
    ["Emperor Dagran Thaurissan"] = "56",
    ["Theldren"] = "60",
}

-- Vanilla: Lower Blackrock Spire
FDJ.BOSS_LEVELS["Lower Blackrock Spire"] = {
    ["Highlord Omokk"] = "57",
    ["Shadow Hunter Vosh'gajin"] = "58",
    ["War Master Voone"] = "58",
    ["Mother Smolderweb"] = "59",
    ["Quartermaster Zigris"] = "59",
    ["Halycon"] = "59",
    ["Urok Doomhowl"] = "60",
    ["Gizrul the Slavener"] = "60",
    ["Overlord Wyrmthalak"] = "60",
    ["Mor Grayhoof"] = "60",
    ["Burning Felguard"] = "56-57",
    ["Spirestone Butcher"] = "57",
    ["Spirestone Battle Lord"] = "58",
    ["Spirestone Lord Magus"] = "58",
    ["Bannok Grimaxe"] = "59",
    ["Ghok Bashguud"] = "59",
    ["Crystal Fang"] = "60",
}

-- Vanilla: Upper Blackrock Spire
FDJ.BOSS_LEVELS["Upper Blackrock Spire"] = {
    ["Pyroguard Emberseer"] = "??",
    ["Solakar Flamewreath"] = "60",
    ["Jed Runewatcher"] = "59",
    ["Goraluk Anvilcrack"] = "61",
    ["Gyth"] = "62",
    ["Warchief Rend Blackhand"] = "??",
    ["The Beast"] = "??",
    ["General Drakkisath"] = "??",
    ["Lord Valthalak"] = "??",
}

-- Vanilla: Dire Maul: East
FDJ.BOSS_LEVELS["Dire Maul: East"] = {
    ["Pusillin"] = "57",
    ["Lethtendris"] = "57",
    ["Hydrospawn"] = "57",
    ["Zevrim Thornhoof"] = "57",
    ["Alzzin the Wildshaper"] = "58",
    ["Isalien"] = "60",
}

-- Vanilla: Dire Maul: West
FDJ.BOSS_LEVELS["Dire Maul: West"] = {
    ["Tendris Warpwood"] = "60",
    ["Illyanna Ravenoak"] = "60",
    ["Magister Kalendris"] = "60",
    ["Tsu'zee"] = "59",
    ["Immol'thar"] = "61",
    ["Prince Tortheldrin"] = "61",
    ["Lord Hel'nurath"] = "62",
}

-- Vanilla: Dire Maul: North
FDJ.BOSS_LEVELS["Dire Maul: North"] = {
    ["Guard Mol'dar"] = "59",
    ["Stomper Kreeg"] = "59",
    ["Guard Fengus"] = "59",
    ["Guard Slip'kik"] = "59",
    ["Captain Kromcrush"] = "61",
    ["Cho'Rush the Observer"] = "60",
    ["King Gordok"] = "62",
}

-- Vanilla: Scholomance
FDJ.BOSS_LEVELS["Scholomance"] = {
    ["Blood Steward of Kirtonos"] = "57",
    ["Kirtonos the Herald"] = "60",
    ["Jandice Barov"] = "61",
    ["Rattlegore"] = "61",
    ["Marduk Blackpool"] = "58",
    ["Vectus"] = "60",
    ["Ras Frostwhisper"] = "62",
    ["Instructor Malicia"] = "60",
    ["Doctor Theolen Krastinov"] = "60",
    ["Lorekeeper Polkelt"] = "60",
    ["The Ravenian"] = "60",
    ["Lord Alexei Barov"] = "60",
    ["Lady Illucia Barov"] = "60",
    ["Darkmaster Gandling"] = "61",
    ["Kormok"] = "60",
    ["Death Knight Darkreaver"] = "62",
}

-- Vanilla: Stratholme: Living
FDJ.BOSS_LEVELS["Stratholme: Living"] = {
    ["The Unforgiven"] = "57",
    ["Timmy the Cruel"] = "58",
    ["Malor the Zealous"] = "60",
    ["Cannon Master Willey"] = "60",
    ["Archivist Galford"] = "60",
    ["Grand Crusader Dathrohan / Balnazzar"] = "62",
    ["Hearthsinger Forresten"] = "57",
    ["Skul"] = "58",
    ["Postmaster Malown"] = "60",
    ["Ezra Grimm"] = "60",
    ["Crimson Hammersmith"] = "60",
    ["Jarien"] = "60",
    ["Sothos"] = "60",
    ["Balnazzar"] = "62",
}

-- Vanilla: Stratholme: Undead
FDJ.BOSS_LEVELS["Stratholme: Undead"] = {
    ["Magistrate Barthilas"] = "58",
    ["Baroness Anastari"] = "59",
    ["Nerub'enkan"] = "60",
    ["Maleki the Pallid"] = "61",
    ["Ramstein the Gorger"] = "61",
    ["Baron Rivendare"] = "62",
    ["Stonespine"] = "60",
    ["Black Guard Swordsmith"] = "61-62",
}

-- Outland normal: Hellfire Ramparts
FDJ.BOSS_LEVELS["Hellfire Ramparts"] = {
    ["Watchkeeper Gargolmar"] = "62",
    ["Omor the Unscarred"] = "62",
    ["Vazruden and Nazan"] = "62",
}

-- Outland normal: The Blood Furnace
FDJ.BOSS_LEVELS["The Blood Furnace"] = {
    ["The Maker"] = "62",
    ["Broggok"] = "63",
    ["Keli'dan the Breaker"] = "63",
}

-- Outland normal: The Slave Pens
FDJ.BOSS_LEVELS["The Slave Pens"] = {
    ["Mennu the Betrayer"] = "64",
    ["Rokmar the Crackler"] = "64",
    ["Quagmirran"] = "64",
}

-- Outland normal: The Underbog
FDJ.BOSS_LEVELS["The Underbog"] = {
    ["Hungarfen"] = "65",
    ["Ghaz'an"] = "65",
    ["Swamplord Musel'ek"] = "65",
    ["The Black Stalker"] = "65",
}

-- Outland normal: Mana-Tombs
FDJ.BOSS_LEVELS["Mana-Tombs"] = {
    ["Pandemonius"] = "66",
    ["Tavarok"] = "66",
    ["Nexus-Prince Shaffar"] = "66",
}

-- Outland normal: Auchenai Crypts
FDJ.BOSS_LEVELS["Auchenai Crypts"] = {
    ["Shirrak the Dead Watcher"] = "67",
    ["Exarch Maladaar"] = "67",
}

-- Outland normal: Old Hillsbrad Foothills
FDJ.BOSS_LEVELS["Old Hillsbrad Foothills"] = {
    ["Lieutenant Drake"] = "68",
    ["Captain Skarloc"] = "68",
    ["Epoch Hunter"] = "68",
}

-- Outland normal: Sethekk Halls
FDJ.BOSS_LEVELS["Sethekk Halls"] = {
    ["Darkweaver Syth"] = "69",
    ["Talon King Ikiss"] = "69",
}

-- Outland normal: The Shattered Halls
FDJ.BOSS_LEVELS["The Shattered Halls"] = {
    ["Grand Warlock Nethekurse"] = "71",
    ["Warbringer O'mrogg"] = "72",
    ["Warchief Kargath Bladefist"] = "72",
}

-- Outland normal: The Steamvault
FDJ.BOSS_LEVELS["The Steamvault"] = {
    ["Hydromancer Thespia"] = "72",
    ["Mekgineer Steamrigger"] = "72",
    ["Warlord Kalithresh"] = "71",
}

-- Outland normal: Shadow Labyrinth
FDJ.BOSS_LEVELS["Shadow Labyrinth"] = {
    ["Ambassador Hellmaw"] = "72",
    ["Blackheart the Inciter"] = "72",
    ["Grandmaster Vorpil"] = "72",
    ["Murmur"] = "72",
}

-- Outland normal: The Black Morass
FDJ.BOSS_LEVELS["The Black Morass"] = {
    ["Chrono Lord Deja"] = "72",
    ["Temporus"] = "72",
    ["Aeonus"] = "72",
}

-- Outland normal: The Mechanar
FDJ.BOSS_LEVELS["The Mechanar"] = {
    ["Mechano-Lord Capacitus"] = "72",
    ["Nethermancer Sepethrea"] = "72",
    ["Pathaleon the Calculator"] = "72",
}

-- Outland normal: The Botanica
FDJ.BOSS_LEVELS["The Botanica"] = {
    ["Commander Sarannis"] = "72",
    ["High Botanist Freywinn"] = "72",
    ["Thorngrin the Tender"] = "72",
    ["Laj"] = "72",
    ["Warp Splinter"] = "72",
}

-- Outland normal: The Arcatraz
FDJ.BOSS_LEVELS["The Arcatraz"] = {
    ["Zereketh the Unbound"] = "72",
    ["Dalliah the Doomsayer"] = "72",
    ["Wrath-Scryer Soccothrates"] = "72",
    ["Harbinger Skyriss"] = "72",
}

-- Outland normal: Magisters' Terrace
FDJ.BOSS_LEVELS["Magisters' Terrace"] = {
    ["Selin Fireheart"] = "70",
    ["Vexallus"] = "71",
    ["Priestess Delrissa"] = "70",
    ["Kael'thas Sunstrider"] = "72",
}
