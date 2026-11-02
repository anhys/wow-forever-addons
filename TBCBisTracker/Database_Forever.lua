-- TBCBisTracker WoW Forever database (GENERATED — do not edit by hand)
-- Source: web/scripts/forever-lvl30.json via web/scripts/build-forever-db.py
-- Generated: 2026-10-08
-- Beta data (level 30 cap): unverified until the game launches.

TBCBisTracker = TBCBisTracker or {}
TBCBisTracker.FOREVER_DB = {}

local DB = TBCBisTracker.FOREVER_DB

local function item(id, source, sourceType, note, faction)
    return { id = id, source = source, sourceType = sourceType or "dungeon", note = note, faction = faction }
end

-- ============================================================
-- WARRIOR
-- ============================================================
DB["WARRIOR"] = {}
-- Fury: foreverchanges.pro/bis/warrior: PvE DPS list (talented Arms on the site; one DPS list for the class); weapons: two-hander per site paperdoll; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["WARRIOR"]["Fury"] = { lvl30 = {
    head = {
        item(250498, "Blacksmithing (Veteran's Chain Helm)", "crafted", nil),
        item(6686, "Overlord Ramtusk, Razorfen Kraul (Tusken Helm)", "dungeon", nil),
        item(7420, "World drop, sold at the auction house (Phalanx Headguard of the Tiger)", "world", nil),
        item(14753, "World drop, sold at the auction house (Slayer's Skullcap)", "world", nil),
    },
    neck = {
        item(7731, "Azshir the Sleepless, Scarlet Monastery Graveyard (Ghostshard Talisman)", "dungeon", nil),
        item(12019, "World drop, sold at the auction house (Cerulean Talisman of the Tiger)", "world", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(274068, "Crowd Pummeler 9-60, Gnomeregan (Thermaplugg Medal of Honor)", "dungeon", nil),
    },
    shoulder = {
        item(2278, "World drop, sold at the auction house (Forest Tracker Epaulets)", "world", nil),
        item(15698, "Quest: Kodo Roundup (Wrangling Spaulders)", "quest", nil),
        item(15553, "World drop, sold at the auction house (Thick Scale Shoulder Pads of the Tiger)", "world", nil),
        item(7913, "Blacksmithing (135) (Barbaric Iron Shoulders)", "crafted", nil),
    },
    back = {
        item(271720, "A quest of the Excavation Site, in the Wetlands (Crocolisk Skin Gaiter)", "quest", nil),
        item(14210, "World drop, sold at the auction house (Vital Cape of the Tiger)", "world", nil),
        item(14593, "World drop, sold at the auction house (Hawkeye's Cloak)", "world", nil),
        item(282658, "Unknown source (not yet found in beta) (Dragonmaw Battle Shroud)", "world", nil),
    },
    chest = {
        item(6773, "Quest: Khan Hratha (Kolkar Marauder Chain)", "quest", nil),
        item(1488, "Trash mobs, Razorfen Kraul (Avenger's Armor)", "dungeon", nil),
        item(250518, "Blacksmithing (110) (Veteran's Silvered Chain Shirt)", "crafted", nil),
        item(2870, "Blacksmithing (Shining Silver Breastplate)", "crafted", nil),
    },
    wrist = {
        item(9428, "Trash mobs, Uldaman (Unearthed Bands of the Tiger)", "dungeon", nil),
        item(270080, "Wanted! Otto and Falconcrest, Refuge Pointe, Arathi Highlands (Alliance only) (Arathi Armbands)", "quest", nil, "Alliance"),
        item(4438, "Trash mobs, Razorfen Kraul (Pugilist Bracers)", "dungeon", nil),
        item(13012, "World drop, sold at the auction house (Yorgen Bracers)", "world", nil),
    },
    hands = {
        item(4107, "Quest: Tiger Mastery (Tiger Hunter Gloves)", "quest", nil),
        item(3341, "Boulderfist ogres, Arathi Highlands (Gauntlets of Ogre Strength)", "world", nil),
        item(16978, "Quest: Warsong Supplies (Horde only) (Warsong Gauntlets)", "quest", nil, "Horde"),
        item(4075, "World drop, sold at the auction house (Mail Combat Gauntlets)", "world", nil),
    },
    waist = {
        item(250556, "Blacksmithing (150) (Officer's Belt)", "crafted", nil),
        item(252459, "Leatherworking (150) (Prowler's Leather Belt)", "crafted", nil),
        item(9405, "World drop, sold at the auction house (Girdle of Golem Strength)", "world", nil),
        item(10403, "Captain Greenskin, The Deadmines (Blackened Defias Belt)", "dungeon", nil),
    },
    legs = {
        item(270074, "Quest: Solution to Doom (Doomcaller's Pants)", "quest", nil),
        item(250523, "Blacksmithing (125) (Veteran's Silvered Chain Leggings)", "crafted", nil),
        item(9624, "Quest: Rig Wars (Triprunner Dungarees)", "quest", nil),
        item(252516, "Leatherworking (125) (Brawler's Leather Legguards)", "crafted", nil),
    },
    feet = {
        item(284403, "A rare of northern Stonetalon Mountains, near the night elves (Horde only) (Shapeshifting Sentinel's Strides)", "world", nil, "Horde"),
        item(4464, "World drop, sold at the auction house (Trouncing Boots)", "world", nil),
        item(7417, "World drop, sold at the auction house (Phalanx Boots of the Tiger)", "world", nil),
        item(252439, "Leatherworking (85) (Brawler's Leather Boots)", "crafted", nil),
    },
    ring1 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(13097, "World drop, sold at the auction house (Thunderbrow Ring)", "world", nil),
        item(18585, "Quest: Service to the Horde (Band of Allegiance)", "quest", nil, "Horde"),
        item(270052, "Quest: Jarl Needs a Blade (Swamp Ring)", "quest", nil),
    },
    ring2 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(13097, "World drop, sold at the auction house (Thunderbrow Ring)", "world", nil),
        item(18585, "Quest: Service to the Horde (Band of Allegiance)", "quest", nil, "Horde"),
        item(270052, "Quest: Jarl Needs a Blade (Swamp Ring)", "quest", nil),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
    },
    mainhand = {
        item(271801, "Khan Jehn, a Gelkis quest in Desolace (Abandoned Ferocity)", "quest", nil),
        item(271800, "Khan Jehn, a Magram quest in Desolace (Scavenged Magram Armament)", "quest", nil),
        item(6975, "Quest: Whirlwind Weapon (Whirlwind Axe)", "quest", nil),
        item(13045, "World drop, sold at the auction house (Viscous Hammer)", "world", nil),
    },
    ranged = {
        item(277254, "Quest: Greater Friend of the Library, from level 30 (Truthseeker's Bow)", "quest", nil),
        item(9456, "Dark Iron Ambassador, Gnomeregan (Glass Shooter)", "dungeon", nil),
        item(17042, "Quest: An Unholy Alliance (Horde only) (Nail Spitter)", "quest", nil, "Horde"),
        item(274748, "Sold by Gezzy Gunkgear in Booty Bay (Booty Bay Bruiser's Buckshot)", "reputation", nil),
    },
} }
-- Protection: foreverchanges.pro/bis/warrior/tank: Tank list; weapons: 1H+shield per site paperdoll; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["WARRIOR"]["Protection"] = { lvl30 = {
    head = {
        item(250500, "Blacksmithing (Protector's Chain Helm)", "crafted", nil),
        item(250530, "Blacksmithing (95) (Protector's Silvered Chain Helm)", "crafted", nil),
        item(13127, "World drop, sold at the auction house (Frostreaver Crown)", "world", nil),
        item(250528, "Blacksmithing (95) (Veteran's Silvered Chain Helm)", "crafted", nil),
    },
    neck = {
        item(274749, "Sold by Gezzy Gunkgear in Booty Bay (Souvenir Sea Shell)", "reputation", nil),
        item(7731, "Azshir the Sleepless, Scarlet Monastery Graveyard (Ghostshard Talisman)", "dungeon", nil),
        item(13087, "World drop, sold at the auction house (River Pride Choker)", "world", nil),
        item(274068, "Crowd Pummeler 9-60, Gnomeregan (Thermaplugg Medal of Honor)", "dungeon", nil),
    },
    shoulder = {
        item(273028, "Relic Guardian, Excavation Site: Wetlands (Reliquary Mantle)", "dungeon", nil),
        item(13131, "World drop, sold at the auction house (Sparkleshell Mantle)", "world", nil),
        item(15698, "Quest: Kodo Roundup (Wrangling Spaulders)", "quest", nil),
        item(277041, "Blacksmithing (175) (Cloudy Skyforged Pauldrons)", "crafted", nil),
    },
    back = {
        item(6751, "Quest: Mortality Wanes (Alliance only) (Mourning Shawl)", "quest", nil, "Alliance"),
        item(4643, "Quest: Vorrel's Revenge (Horde only) (Grimsteel Cape)", "quest", nil, "Horde"),
        item(13108, "World drop, sold at the auction house (Tigerstrike Mantle)", "world", nil),
        item(271720, "A quest of the Excavation Site, in the Wetlands (Crocolisk Skin Gaiter)", "quest", nil),
    },
    chest = {
        item(7688, "Ironspine, Scarlet Monastery Graveyard (Ironspine's Ribcage)", "dungeon", nil),
        item(6972, "Quest: Furen's Armor (Alliance only) (Fire Hardened Hauberk)", "quest", nil, "Alliance"),
        item(7133, "Quest: Brutal Hauberk (Horde only)", "quest", nil, "Horde"),
        item(250519, "Blacksmithing (110) (Guard's Silvered Chain Shirt)", "crafted", nil),
    },
    wrist = {
        item(10358, "Quest: Power Stones (Duracin Bracers)", "quest", nil),
        item(3228, "Bruegal Ironknuckle, The Stockade (Alliance only) (Jimmied Handcuffs)", "dungeon", nil, "Alliance"),
        item(7003, "Quest: Researching the Corruption (Alliance only) (Beetle Clasps)", "quest", nil, "Alliance"),
        item(18948, "Leatherworking (130) (Barbaric Bracers)", "crafted", nil),
        item(3230, "Fenrus the Devourer, Shadowfang Keep (Black Wolf Bracers)", "dungeon", nil),
    },
    hands = {
        item(273810, "Hamhock, The Stockade (Alliance only) (Ogre Grips)", "dungeon", nil, "Alliance"),
        item(250509, "Blacksmithing (80) (Guard's Gloves)", "crafted", nil),
        item(9868, "World drop, sold at the auction house (Renegade Gauntlets of the Champion)", "world", nil),
        item(14764, "World drop, sold at the auction house (Enduring Gauntlets)", "world", nil),
    },
    waist = {
        item(250557, "Blacksmithing (150) (Sentinel's Belt)", "crafted", nil),
        item(252460, "Leatherworking (150) (Warden's Leather Belt)", "crafted", nil),
        item(9869, "World drop, sold at the auction house (Renegade Belt of the Champion)", "world", nil),
        item(277232, "Unknown source (not yet found in beta) (Jailer's Discarded Chain)", "world", nil),
    },
    legs = {
        item(250524, "Blacksmithing (125) (Guard's Silvered Chain Leggings)", "crafted", nil),
        item(250494, "Blacksmithing (Guard's Chain Leggings)", "crafted", nil),
        item(274161, "Overlord Ramtusk, Razorfen Kraul (Quillord Mail Leggings)", "dungeon", nil),
        item(13010, "World drop, sold at the auction house (Dreamsinger Legguards)", "world", nil),
    },
    feet = {
        item(10332, "Trash mobs, Scarlet Monastery Graveyard (Scarlet Boots)", "dungeon", nil),
        item(9510, "Trash mobs, Gnomeregan (Caverndeep Trudgers)", "dungeon", nil),
        item(13124, "World drop, sold at the auction house (Ravasaur Scale Boots)", "world", nil),
        item(250504, "Blacksmithing (85) (Guard's Boots)", "crafted", nil),
    },
    ring1 = {
        item(276899, "Quest: Past Due (Alliance only) (Knucklebound Thimble)", "quest", nil, "Alliance"),
        item(281320, "Alliance quest Gleaning Our Future, Wetlands, level 32 (Rune-Etched Ring)", "quest", nil, "Alliance"),
        item(9538, "Quest: Gnome Improvement (Alliance only) (Talvash's Gold Ring)", "quest", nil, "Alliance"),
        item(281634, "Quest: Greater Friend of the Library (Field Researcher's Loop)", "quest", nil),
        item(6414, "Quest: Arugal Must Die (Horde only) (Seal of Sylvanas)", "quest", nil, "Horde"),
        item(282283, "Nightveiled Rotheap, a patrol of the Wetlands (Alliance only) (Malignant Root)", "world", nil, "Alliance"),
    },
    ring2 = {
        item(281320, "Alliance quest Gleaning Our Future, Wetlands, level 32 (Rune-Etched Ring)", "quest", nil, "Alliance"),
        item(9538, "Quest: Gnome Improvement (Alliance only) (Talvash's Gold Ring)", "quest", nil, "Alliance"),
        item(281634, "Quest: Greater Friend of the Library (Field Researcher's Loop)", "quest", nil),
        item(6414, "Quest: Arugal Must Die (Horde only) (Seal of Sylvanas)", "quest", nil, "Horde"),
        item(282283, "Nightveiled Rotheap, a patrol of the Wetlands (Alliance only) (Malignant Root)", "world", nil, "Alliance"),
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
        item(273298, "Cookie, The Deadmines (Lookie's Spyglass)", "dungeon", nil),
    },
    trinket2 = {
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(273298, "Cookie, The Deadmines (Lookie's Spyglass)", "dungeon", nil),
    },
    mainhand = {
        item(271802, "Khan Jehn, a Gelkis quest in Desolace (Bludgeon of Betrayed Virtues)", "quest", nil),
        item(6804, "Quest: Final Passage (Horde only) (Windstorm Hammer)", "quest", nil, "Horde"),
        item(271664, "Quest: Horrors in the Highland (Alliance only) (Hornbeam Heft)", "quest", nil, "Alliance"),
        item(7687, "Ironspine, Scarlet Monastery Graveyard (Ironspine's Fist)", "dungeon", nil),
    },
    offhand = {
        item(4129, "Quest: Cracking Maury's Foot (Collection Plate)", "quest", nil),
        item(17508, "Quest: Compendium of the Fallen (Horde only) (Forcestone Buckler)", "quest", nil, "Horde"),
        item(7747, "Quest: Compendium of the Fallen (Horde only) (Vile Protector)", "quest", nil, "Horde"),
        item(9522, "Quest: Power Stones (Energized Stone Circle)", "quest", nil),
        item(6725, "Quest: A Vengeful Fate (Marbled Buckler)", "quest", nil),
    },
    ranged = {
        item(277254, "Quest: Greater Friend of the Library, from level 30 (Truthseeker's Bow)", "quest", nil),
        item(274748, "Sold by Gezzy Gunkgear in Booty Bay (Booty Bay Bruiser's Buckshot)", "reputation", nil),
        item(13137, "World drop, sold at the auction house (Ironweaver)", "world", nil),
        item(273843, "Lorgus Jett, Blackfathom Deeps (Fallenroot Longbow)", "dungeon", nil),
    },
} }

-- ============================================================
-- PALADIN
-- ============================================================
DB["PALADIN"] = {}
-- Holy: foreverchanges.pro/bis/paladin/holy: Holy PvE list; weapons: 1H+shield per site paperdoll; ranged slot holds the relic (libram/totem/idol) list; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["PALADIN"]["Holy"] = { lvl30 = {
    head = {
        item(2721, "World drop, sold at the auction house (Holy Shroud)", "world", nil),
        item(250501, "Blacksmithing (Acolyte's Chain Helm)", "crafted", nil),
        item(15550, "World drop, sold at the auction house (Thick Scale Crown of Healing)", "world", nil),
        item(284401, "Sorrow Wing, the rare of Stonetalon Mountains (Sorrow's Shroud)", "world", nil),
    },
    neck = {
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of the Physician)", "world", nil),
        item(7746, "Quest: Mythology of the Titans (Alliance only) (Explorers' League Commendation)", "quest", nil, "Alliance"),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(5003, "World drop, sold at the auction house (Crystal Starfire Medallion)", "world", nil),
    },
    shoulder = {
        item(15553, "World drop, sold at the auction house (Thick Scale Shoulder Pads of Healing)", "world", nil),
        item(4197, "Quest: A Vengeful Fate (Berylline Pads)", "quest", nil),
        item(7684, "Bloodmage Thalnos, Scarlet Monastery Graveyard (Bloodmage Mantle)", "dungeon", nil),
        item(6685, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Mantle)", "dungeon", nil),
    },
    back = {
        item(7436, "World drop, sold at the auction house (Twilight Cape of Healing)", "world", nil),
        item(9605, "Quest: Data Rescue (Alliance only) (Repairman's Cape)", "quest", nil, "Alliance"),
        item(7004, "Quest: Researching the Corruption (Alliance only) (Prelacy Cape)", "quest", nil, "Alliance"),
        item(273825, "Bazil Thredd, The Stockade (Alliance only) (Red Wool Cloak)", "dungeon", nil, "Alliance"),
        item(6901, "Old Serra'kis, Blackfathom Deeps (Glowing Thresher Cape)", "dungeon", nil),
        item(274149, "Roogug, Razorfen Kraul (Thornweaver Drape)", "dungeon", nil),
    },
    chest = {
        item(7418, "World drop, sold at the auction house (Phalanx Breastplate of Healing)", "world", nil),
        item(250521, "Blacksmithing (110) (Acolyte's Silvered Chain Shirt)", "crafted", nil),
        item(6682, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Robes)", "dungeon", nil),
        item(253961, "Tailoring (110) (Pristine Gown)", "crafted", nil),
    },
    wrist = {
        item(9428, "Trash mobs, Uldaman (Unearthed Bands of Healing)", "dungeon", nil),
        item(9448, "Electrocutioner 6000, Gnomeregan (Spidertank Oilrag)", "dungeon", nil),
        item(273808, "Kam Deepfury, The Stockade (Alliance only) (Bridgebreaker Bindings)", "dungeon", nil, "Alliance"),
        item(4744, "Quest: Wanted!  Marez Cowl (Alliance only) (Arcane Runed Bracers)", "quest", nil, "Alliance"),
        item(271740, "Quest: Open the Maw (Horde only) (Knife-Polishing Rag)", "quest", nil, "Horde"),
    },
    hands = {
        item(15560, "World drop, sold at the auction house (Pillager's Gloves of Healing)", "world", nil),
        item(270059, "Agmond's Fate, from Prospector Ironband in Loch Modan (Alliance only) (Restorer's Fine Gloves)", "quest", nil, "Alliance"),
        item(7049, "Tailoring (125) (Truefaith Gloves)", "crafted", nil),
        item(270025, "Quest: Twilight Falls (Alliance only) (Silvered Gauntlets)", "quest", nil, "Alliance"),
        item(888, "Lady Sarevess, Blackfathom Deeps (Naga Battle Gloves)", "dungeon", nil),
    },
    waist = {
        item(250559, "Blacksmithing (150) (Prefect's Belt)", "crafted", nil),
        item(252523, "Leatherworking (150) (Mender's Leather Belt)", "crafted", nil),
        item(9869, "World drop, sold at the auction house (Renegade Belt of Healing)", "world", nil),
        item(252522, "Leatherworking (150) (Skycaller's Leather Belt)", "crafted", nil),
    },
    legs = {
        item(250526, "Blacksmithing (125) (Acolyte's Silvered Chain Leggings)", "crafted", nil),
        item(253987, "Tailoring (125) (Pristine Leggings)", "crafted", nil),
        item(252519, "Leatherworking (125) (Wisdom's Leather Leggings)", "crafted", nil),
        item(253937, "Tailoring (100) (Filigreed Pristine Leggings)", "crafted", nil),
    },
    feet = {
        item(7417, "World drop, sold at the auction house (Phalanx Boots of Healing)", "world", nil),
        item(10359, "Quest: Power Stones (Everlast Boots)", "quest", nil),
        item(254001, "Tailoring (140) (Gilded Slippers)", "crafted", nil),
        item(271214, "Rath'mael, Ruins of Lordaeron (Rotmender's Treads)", "dungeon", nil),
    },
    ring1 = {
        item(274746, "Sold by Gezzy Gunkgear in Booty Bay (Sea Giant's Toe Ring)", "reputation", nil),
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(11985, "World drop, sold at the auction house (Cerulean Ring of the Physician)", "world", nil),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
    },
    ring2 = {
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(11985, "World drop, sold at the auction house (Cerulean Ring of the Physician)", "world", nil),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(271670, "Quest: Horrors in the Highland (Alliance only) (Curl of Life)", "quest", nil, "Alliance"),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    trinket2 = {
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    mainhand = {
        item(9457, "Dark Iron Ambassador, Gnomeregan (Royal Diplomatic Scepter)", "dungeon", nil),
        item(2816, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Scepter)", "dungeon", nil),
        item(17039, "Quest: An Unholy Alliance (Horde only) (Skullbreaker)", "quest", nil, "Horde"),
        item(272996, "Oggleflint, Ragefire Chasm (Horde only) (Trogg Scepter)", "dungeon", nil, "Horde"),
        item(3414, "Trash mobs, Blackfathom Deeps (Crested Scepter)", "dungeon", nil),
    },
    offhand = {
        item(6694, "Charlga Razorflank, Razorfen Kraul (Heart of Agamaggan)", "dungeon", nil),
        item(274290, "Interrogator Vishas, Scarlet Monastery Graveyard (Painwalker Buckler)", "dungeon", nil),
        item(7330, "World drop, sold at the auction house (Infiltrator Buckler of Healing)", "world", nil),
        item(273811, "Hamhock, The Stockade (Alliance only) (Repurposed Rack)", "dungeon", nil, "Alliance"),
    },
    ranged = {
        item(249397, "Enchanting (130) (Tenets of the Silver Hand)", "crafted", nil),
    },
} }
-- Protection: foreverchanges.pro/bis/paladin/tank: Tank list; weapons: 1H+shield per site paperdoll; ranged slot holds the relic (libram/totem/idol) list; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["PALADIN"]["Protection"] = { lvl30 = {
    head = {
        item(252456, "Gelihast, Blackfathom Deeps (Totemic Leather Helm)", "dungeon", nil),
        item(253985, "Tailoring (125) (Filigreed Shining Circlet)", "crafted", nil),
        item(250532, "Blacksmithing (95) (Crusader's Silvered Chain Helm)", "crafted", nil),
        item(253959, "Tailoring (100) (Shining Circlet)", "crafted", nil),
    },
    neck = {
        item(274749, "Sold by Gezzy Gunkgear in Booty Bay (Souvenir Sea Shell)", "reputation", nil),
        item(13087, "World drop, sold at the auction house (River Pride Choker)", "world", nil),
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of the Defender)", "world", nil),
        item(7746, "Quest: Mythology of the Titans (Alliance only) (Explorers' League Commendation)", "quest", nil, "Alliance"),
    },
    shoulder = {
        item(15553, "World drop, sold at the auction house (Thick Scale Shoulder Pads of Holy Wrath)", "world", nil),
        item(273028, "Relic Guardian, Excavation Site: Wetlands (Reliquary Mantle)", "dungeon", nil),
        item(13131, "World drop, sold at the auction house (Sparkleshell Mantle)", "world", nil),
        item(11884, "Quest: Return to Vahlarriel (Alliance only) (Moonlit Amice)", "quest", nil, "Alliance"),
    },
    back = {
        item(277205, "Paladin quest Return to Delgren, Alliance, from level 22 (Cloak of the Divine Storm)", "quest", nil, "Alliance"),
        item(6751, "Quest: Mortality Wanes (Alliance only) (Mourning Shawl)", "quest", nil, "Alliance"),
        item(7436, "World drop, sold at the auction house (Twilight Cape of Holy Wrath)", "world", nil),
        item(4643, "Quest: Vorrel's Revenge (Horde only) (Grimsteel Cape)", "quest", nil, "Horde"),
        item(13108, "World drop, sold at the auction house (Tigerstrike Mantle)", "world", nil),
    },
    chest = {
        item(250520, "Blacksmithing (110) (Protector's Silvered Chain Shirt)", "crafted", nil),
        item(250522, "Blacksmithing (110) (Crusader's Silvered Chain Shirt)", "crafted", nil),
        item(7418, "World drop, sold at the auction house (Phalanx Breastplate of Holy Wrath)", "world", nil),
        item(250519, "Blacksmithing (110) (Guard's Silvered Chain Shirt)", "crafted", nil),
    },
    wrist = {
        item(15566, "World drop, sold at the auction house (Marauder's Bracers of Holy Wrath)", "world", nil),
        item(10358, "Quest: Power Stones (Duracin Bracers)", "quest", nil),
        item(3228, "Bruegal Ironknuckle, The Stockade (Alliance only) (Jimmied Handcuffs)", "dungeon", nil, "Alliance"),
        item(7003, "Quest: Researching the Corruption (Alliance only) (Beetle Clasps)", "quest", nil, "Alliance"),
        item(18948, "Leatherworking (130) (Barbaric Bracers)", "crafted", nil),
    },
    hands = {
        item(4980, "Quest: Agmond's Fate (Alliance only) (Prospector Gloves)", "quest", nil, "Alliance"),
        item(9868, "World drop, sold at the auction house (Renegade Gauntlets of Holy Wrath)", "world", nil),
        item(270025, "Quest: Twilight Falls (Alliance only) (Silvered Gauntlets)", "quest", nil, "Alliance"),
        item(250510, "Blacksmithing (80) (Protector's Gloves)", "crafted", nil),
        item(9698, "Quest: Return to Vahlarriel (Alliance only) (Gloves of Insight)", "quest", nil, "Alliance"),
        item(273810, "Hamhock, The Stockade (Alliance only) (Ogre Grips)", "dungeon", nil, "Alliance"),
    },
    waist = {
        item(250558, "Blacksmithing (150) (Warder's Belt)", "crafted", nil),
        item(250560, "Blacksmithing (150) (Justicar's Belt)", "crafted", nil),
        item(250557, "Blacksmithing (150) (Sentinel's Belt)", "crafted", nil),
        item(252522, "Leatherworking (150) (Skycaller's Leather Belt)", "crafted", nil),
    },
    legs = {
        item(250525, "Blacksmithing (125) (Protector's Silvered Chain Leggings)", "crafted", nil),
        item(250527, "Blacksmithing (125) (Crusader's Silvered Chain Leggings)", "crafted", nil),
        item(250495, "Blacksmithing (Protector's Chain Leggings)", "crafted", nil),
        item(270031, "Quest: Blackfathom Villainy (Dark Ritual Leggings)", "quest", nil),
    },
    feet = {
        item(250505, "Blacksmithing (85) (Protector's Boots)", "crafted", nil),
        item(254011, "Tailoring (140) (Radiant Slippers)", "crafted", nil),
        item(9450, "Crowd Pummeler 9-60, Gnomeregan (Gnomebot Operating Boots)", "dungeon", nil),
        item(250507, "Blacksmithing (85) (Crusader's Boots)", "crafted", nil),
    },
    ring1 = {
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(271670, "Quest: Horrors in the Highland (Alliance only) (Curl of Life)", "quest", nil, "Alliance"),
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(282283, "Nightveiled Rotheap, a patrol of the Wetlands (Alliance only) (Malignant Root)", "world", nil, "Alliance"),
        item(278019, "Unknown source (not yet found in beta) (Apology Ring)", "world", nil),
    },
    ring2 = {
        item(271670, "Quest: Horrors in the Highland (Alliance only) (Curl of Life)", "quest", nil, "Alliance"),
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(282283, "Nightveiled Rotheap, a patrol of the Wetlands (Alliance only) (Malignant Root)", "world", nil, "Alliance"),
        item(278019, "Unknown source (not yet found in beta) (Apology Ring)", "world", nil),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
    },
    trinket2 = {
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
    },
    mainhand = {
        item(271804, "Khan Jehn, a Magram quest in Desolace (Soulsplatter Mace)", "quest", nil),
        item(17039, "Quest: An Unholy Alliance (Horde only) (Skullbreaker)", "quest", nil, "Horde"),
        item(3414, "Trash mobs, Blackfathom Deeps (Crested Scepter)", "dungeon", nil),
        item(273827, "Bazil Thredd, The Stockade (Alliance only) (Debt Collector)", "dungeon", nil, "Alliance"),
    },
    offhand = {
        item(9522, "Quest: Power Stones (Energized Stone Circle)", "quest", nil),
        item(6694, "Charlga Razorflank, Razorfen Kraul (Heart of Agamaggan)", "dungeon", nil),
        item(274290, "Interrogator Vishas, Scarlet Monastery Graveyard (Painwalker Buckler)", "dungeon", nil),
        item(273811, "Hamhock, The Stockade (Alliance only) (Repurposed Rack)", "dungeon", nil, "Alliance"),
    },
    ranged = {
        item(249397, "Enchanting (130) (Tenets of the Silver Hand)", "crafted", nil),
    },
} }
-- Retribution: foreverchanges.pro/bis/paladin: Retribution PvE list; weapons: two-hander per site paperdoll; ranged slot holds the relic (libram/totem/idol) list; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["PALADIN"]["Retribution"] = { lvl30 = {
    head = {
        item(252455, "Twilight Lord Kelris, Blackfathom Deeps (Defender's Leather Helm)", "dungeon", nil),
        item(250528, "Blacksmithing (95) (Veteran's Silvered Chain Helm)", "crafted", nil),
        item(6686, "Overlord Ramtusk, Razorfen Kraul (Tusken Helm)", "dungeon", nil),
        item(14753, "World drop, sold at the auction house (Slayer's Skullcap)", "world", nil),
    },
    neck = {
        item(7731, "Azshir the Sleepless, Scarlet Monastery Graveyard (Ghostshard Talisman)", "dungeon", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(13087, "World drop, sold at the auction house (River Pride Choker)", "world", nil),
        item(274068, "Crowd Pummeler 9-60, Gnomeregan (Thermaplugg Medal of Honor)", "dungeon", nil),
    },
    shoulder = {
        item(15698, "Quest: Kodo Roundup (Wrangling Spaulders)", "quest", nil),
        item(2278, "World drop, sold at the auction house (Forest Tracker Epaulets)", "world", nil),
        item(5964, "Leatherworking (Barbaric Shoulders)", "crafted", nil),
        item(3841, "Blacksmithing (150) (Golden Scale Shoulders)", "crafted", nil),
    },
    back = {
        item(271720, "A quest of the Excavation Site, in the Wetlands (Crocolisk Skin Gaiter)", "quest", nil),
        item(277205, "Paladin quest Return to Delgren, Alliance, from level 22 (Cloak of the Divine Storm)", "quest", nil, "Alliance"),
        item(7436, "World drop, sold at the auction house (Twilight Cape of Strength)", "world", nil),
        item(282658, "Unknown source (not yet found in beta) (Dragonmaw Battle Shroud)", "world", nil),
    },
    chest = {
        item(1488, "Trash mobs, Razorfen Kraul (Avenger's Armor)", "dungeon", nil),
        item(6773, "Quest: Khan Hratha (Kolkar Marauder Chain)", "quest", nil),
        item(2870, "Blacksmithing (Shining Silver Breastplate)", "crafted", nil),
        item(250518, "Blacksmithing (110) (Veteran's Silvered Chain Shirt)", "crafted", nil),
    },
    wrist = {
        item(9428, "Trash mobs, Uldaman (Unearthed Bands of Power)", "dungeon", nil),
        item(270080, "Wanted! Otto and Falconcrest, Refuge Pointe, Arathi Highlands (Alliance only) (Arathi Armbands)", "quest", nil, "Alliance"),
        item(4438, "Trash mobs, Razorfen Kraul (Pugilist Bracers)", "dungeon", nil),
        item(13012, "World drop, sold at the auction house (Yorgen Bracers)", "world", nil),
    },
    hands = {
        item(270075, "Quest: Solution to Doom (Fists of Impending Doom)", "quest", nil),
        item(16978, "Quest: Warsong Supplies (Horde only) (Warsong Gauntlets)", "quest", nil, "Horde"),
        item(720, "World drop, sold at the auction house (Brawler Gloves)", "world", nil),
        item(14764, "World drop, sold at the auction house (Enduring Gauntlets)", "world", nil),
    },
    waist = {
        item(250556, "Blacksmithing (150) (Officer's Belt)", "crafted", nil),
        item(252459, "Leatherworking (150) (Prowler's Leather Belt)", "crafted", nil),
        item(252461, "Leatherworking (150) (Skirmisher's Leather Belt)", "crafted", nil),
        item(252520, "Leatherworking (150) (Skulker's Leather Belt)", "crafted", nil),
    },
    legs = {
        item(250523, "Blacksmithing (125) (Veteran's Silvered Chain Leggings)", "crafted", nil),
        item(270074, "Quest: Solution to Doom (Doomcaller's Pants)", "quest", nil),
        item(250493, "Blacksmithing (Veteran's Chain Leggings)", "crafted", nil),
        item(9624, "Quest: Rig Wars (Triprunner Dungarees)", "quest", nil),
    },
    feet = {
        item(284403, "A rare of northern Stonetalon Mountains, near the night elves (Horde only) (Shapeshifting Sentinel's Strides)", "world", nil, "Horde"),
        item(4464, "World drop, sold at the auction house (Trouncing Boots)", "world", nil),
        item(273025, "Shadetooth, Excavation Site: Wetlands (Raptorclaw Greaves)", "dungeon", nil),
        item(250503, "Blacksmithing (85) (Veteran's Boots)", "crafted", nil),
    },
    ring1 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(18585, "Quest: Service to the Horde (Band of Allegiance)", "quest", nil, "Horde"),
        item(13097, "World drop, sold at the auction house (Thunderbrow Ring)", "world", nil),
        item(270052, "Quest: Jarl Needs a Blade (Swamp Ring)", "quest", nil),
    },
    ring2 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(18585, "Quest: Service to the Horde (Band of Allegiance)", "quest", nil, "Horde"),
        item(13097, "World drop, sold at the auction house (Thunderbrow Ring)", "world", nil),
        item(270052, "Quest: Jarl Needs a Blade (Swamp Ring)", "quest", nil),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    mainhand = {
        item(271801, "Khan Jehn, a Gelkis quest in Desolace (Abandoned Ferocity)", "quest", nil),
        item(271800, "Khan Jehn, a Magram quest in Desolace (Scavenged Magram Armament)", "quest", nil),
        item(4983, "Quest: Murdaloc (Alliance only) (Rock Pulverizer)", "quest", nil, "Alliance"),
        item(13045, "World drop, sold at the auction house (Viscous Hammer)", "world", nil),
    },
    ranged = {
        item(249397, "Enchanting (130) (Tenets of the Silver Hand)", "crafted", nil),
    },
} }

-- ============================================================
-- HUNTER
-- ============================================================
DB["HUNTER"] = {}
-- Marksmanship: foreverchanges.pro/bis/hunter: single Hunter PvE list for the class; weapons: two-hander per site paperdoll; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["HUNTER"]["Marksmanship"] = { lvl30 = {
    head = {
        item(7413, "World drop, sold at the auction house (Infiltrator Cap of Agility)", "world", nil),
        item(6204, "World drop, sold at the auction house (Tribal Worg Helm)", "world", nil),
        item(252512, "Gelihast, Blackfathom Deeps (Brawler's Leather Helm)", "dungeon", nil),
        item(6720, "Quest: Frostmaw (Horde only) (Spirit Hunter Headdress)", "quest", nil, "Horde"),
    },
    neck = {
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of Agility)", "world", nil),
        item(7731, "Azshir the Sleepless, Scarlet Monastery Graveyard (Ghostshard Talisman)", "dungeon", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(274068, "Crowd Pummeler 9-60, Gnomeregan (Thermaplugg Medal of Honor)", "dungeon", nil),
    },
    shoulder = {
        item(2278, "World drop, sold at the auction house (Forest Tracker Epaulets)", "world", nil),
        item(2264, "Trash mobs, Razorfen Kraul (Mantle of Thieves)", "dungeon", nil),
        item(15140, "World drop, sold at the auction house (Cutthroat's Mantle of Agility)", "world", nil),
        item(277043, "Leatherworking (175) (Cloudy Gustwoven Spaulders)", "crafted", nil),
    },
    back = {
        item(13108, "World drop, sold at the auction house (Tigerstrike Mantle)", "world", nil),
        item(7436, "World drop, sold at the auction house (Twilight Cape of Agility)", "world", nil),
        item(271716, "Quest: Lost Relic Carry (Alliance only) (Explorer's League Dustcover)", "quest", nil, "Alliance"),
        item(14593, "World drop, sold at the auction house (Hawkeye's Cloak)", "world", nil),
    },
    chest = {
        item(7374, "Leatherworking (Dusky Leather Armor)", "crafted", nil),
        item(7407, "World drop, sold at the auction house (Infiltrator Armor of Agility)", "world", nil),
        item(273026, "Shadetooth, Excavation Site: Wetlands (Garb of Florid Feathers)", "dungeon", nil),
        item(4255, "Leatherworking (130) (Green Leather Armor)", "crafted", nil),
    },
    wrist = {
        item(9428, "Trash mobs, Uldaman (Unearthed Bands of Agility)", "dungeon", nil),
        item(270055, "Quest: Power Stones (Charged Leather Bracers)", "quest", nil),
        item(14590, "World drop, sold at the auction house (Hawkeye's Bracers)", "world", nil),
        item(6198, "World drop, sold at the auction house (Jurassic Wristguards)", "world", nil),
    },
    hands = {
        item(270072, "Crushridge Warmongers, from Marshal Redpath in Southshore (Alliance only) (Alterac Assassin's Gloves)", "quest", nil, "Alliance"),
        item(15355, "World drop, sold at the auction house (Headhunter's Mitts of Agility)", "world", nil),
        item(6727, "Quest: Safety First (Razzeric's Racing Grips)", "quest", nil),
        item(7358, "Leatherworking (115) (Pilferer's Gloves)", "crafted", nil),
    },
    waist = {
        item(252521, "Leatherworking (150) (Stalker's Leather Belt)", "crafted", nil),
        item(252520, "Leatherworking (150) (Skulker's Leather Belt)", "crafted", nil),
        item(15148, "World drop, sold at the auction house (Ghostwalker Belt of Agility)", "world", nil),
        item(16659, "Quest: Je'neu of the Earthen Ring (Horde only) (Deftkin Belt)", "quest", nil, "Horde"),
    },
    legs = {
        item(9624, "Quest: Rig Wars (Triprunner Dungarees)", "quest", nil),
        item(6690, "Agathelos the Raging, Razorfen Kraul (Ferine Leggings)", "dungeon", nil),
        item(9509, "Trash mobs, Gnomeregan (Petrolspill Leggings)", "dungeon", nil),
        item(13114, "World drop, sold at the auction house (Troll's Bane Leggings)", "world", nil),
    },
    feet = {
        item(284403, "A rare of northern Stonetalon Mountains, near the night elves (Horde only) (Shapeshifting Sentinel's Strides)", "world", nil, "Horde"),
        item(7751, "Quest: Vorrel's Revenge (Horde only) (Vorrel's Boots)", "quest", nil, "Horde"),
        item(15350, "World drop, sold at the auction house (Headhunter's Slippers of Agility)", "world", nil),
        item(16977, "Quest: Warsong Supplies (Horde only) (Warsong Boots)", "quest", nil, "Horde"),
        item(4055, "World drop, sold at the auction house (Insignia Boots)", "world", nil),
        item(1121, "World drop, sold at the auction house (Feet of the Lynx)", "world", nil),
    },
    ring1 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(7686, "Ironspine, Scarlet Monastery Graveyard (Ironspine's Eye)", "dungeon", nil),
        item(270052, "Quest: Jarl Needs a Blade (Swamp Ring)", "quest", nil),
        item(281634, "Quest: Greater Friend of the Library (Field Researcher's Loop)", "quest", nil),
    },
    ring2 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(7686, "Ironspine, Scarlet Monastery Graveyard (Ironspine's Eye)", "dungeon", nil),
        item(270052, "Quest: Jarl Needs a Blade (Swamp Ring)", "quest", nil),
        item(281634, "Quest: Greater Friend of the Library (Field Researcher's Loop)", "quest", nil),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
    },
    mainhand = {
        item(3197, "World drop, sold at the auction house (Stonecutter Claymore of Agility)", "world", nil),
        item(6679, "Razorfen Spearhide, Razorfen Kraul (Armor Piercer)", "dungeon", nil),
        item(2280, "Kam Deepfury, The Stockade (Alliance only) (Kam's Walking Stick)", "dungeon", nil, "Alliance"),
        item(5200, "Captain Greenskin, The Deadmines (Impaling Harpoon)", "dungeon", nil),
    },
    ranged = {
        item(277254, "Quest: Greater Friend of the Library, from level 30 (Truthseeker's Bow)", "quest", nil),
        item(17042, "Quest: An Unholy Alliance (Horde only) (Nail Spitter)", "quest", nil, "Horde"),
        item(274084, "Quest: A Vengeful Fate (Horde only) (Quilboar Blaster)", "quest", nil, "Horde"),
        item(9456, "Dark Iron Ambassador, Gnomeregan (Glass Shooter)", "dungeon", nil),
        item(274748, "Sold by Gezzy Gunkgear in Booty Bay (Booty Bay Bruiser's Buckshot)", "reputation", nil),
    },
} }
-- Survival: foreverchanges.pro/bis/hunter: single Hunter PvE list for the class (reused); weapons: two-hander per site paperdoll; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["HUNTER"]["Survival"] = { lvl30 = {
    head = {
        item(7413, "World drop, sold at the auction house (Infiltrator Cap of Agility)", "world", nil),
        item(6204, "World drop, sold at the auction house (Tribal Worg Helm)", "world", nil),
        item(252512, "Gelihast, Blackfathom Deeps (Brawler's Leather Helm)", "dungeon", nil),
        item(6720, "Quest: Frostmaw (Horde only) (Spirit Hunter Headdress)", "quest", nil, "Horde"),
    },
    neck = {
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of Agility)", "world", nil),
        item(7731, "Azshir the Sleepless, Scarlet Monastery Graveyard (Ghostshard Talisman)", "dungeon", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(274068, "Crowd Pummeler 9-60, Gnomeregan (Thermaplugg Medal of Honor)", "dungeon", nil),
    },
    shoulder = {
        item(2278, "World drop, sold at the auction house (Forest Tracker Epaulets)", "world", nil),
        item(2264, "Trash mobs, Razorfen Kraul (Mantle of Thieves)", "dungeon", nil),
        item(15140, "World drop, sold at the auction house (Cutthroat's Mantle of Agility)", "world", nil),
        item(277043, "Leatherworking (175) (Cloudy Gustwoven Spaulders)", "crafted", nil),
    },
    back = {
        item(13108, "World drop, sold at the auction house (Tigerstrike Mantle)", "world", nil),
        item(7436, "World drop, sold at the auction house (Twilight Cape of Agility)", "world", nil),
        item(271716, "Quest: Lost Relic Carry (Alliance only) (Explorer's League Dustcover)", "quest", nil, "Alliance"),
        item(14593, "World drop, sold at the auction house (Hawkeye's Cloak)", "world", nil),
    },
    chest = {
        item(7374, "Leatherworking (Dusky Leather Armor)", "crafted", nil),
        item(7407, "World drop, sold at the auction house (Infiltrator Armor of Agility)", "world", nil),
        item(273026, "Shadetooth, Excavation Site: Wetlands (Garb of Florid Feathers)", "dungeon", nil),
        item(4255, "Leatherworking (130) (Green Leather Armor)", "crafted", nil),
    },
    wrist = {
        item(9428, "Trash mobs, Uldaman (Unearthed Bands of Agility)", "dungeon", nil),
        item(270055, "Quest: Power Stones (Charged Leather Bracers)", "quest", nil),
        item(14590, "World drop, sold at the auction house (Hawkeye's Bracers)", "world", nil),
        item(6198, "World drop, sold at the auction house (Jurassic Wristguards)", "world", nil),
    },
    hands = {
        item(270072, "Crushridge Warmongers, from Marshal Redpath in Southshore (Alliance only) (Alterac Assassin's Gloves)", "quest", nil, "Alliance"),
        item(15355, "World drop, sold at the auction house (Headhunter's Mitts of Agility)", "world", nil),
        item(6727, "Quest: Safety First (Razzeric's Racing Grips)", "quest", nil),
        item(7358, "Leatherworking (115) (Pilferer's Gloves)", "crafted", nil),
    },
    waist = {
        item(252521, "Leatherworking (150) (Stalker's Leather Belt)", "crafted", nil),
        item(252520, "Leatherworking (150) (Skulker's Leather Belt)", "crafted", nil),
        item(15148, "World drop, sold at the auction house (Ghostwalker Belt of Agility)", "world", nil),
        item(16659, "Quest: Je'neu of the Earthen Ring (Horde only) (Deftkin Belt)", "quest", nil, "Horde"),
    },
    legs = {
        item(9624, "Quest: Rig Wars (Triprunner Dungarees)", "quest", nil),
        item(6690, "Agathelos the Raging, Razorfen Kraul (Ferine Leggings)", "dungeon", nil),
        item(9509, "Trash mobs, Gnomeregan (Petrolspill Leggings)", "dungeon", nil),
        item(13114, "World drop, sold at the auction house (Troll's Bane Leggings)", "world", nil),
    },
    feet = {
        item(284403, "A rare of northern Stonetalon Mountains, near the night elves (Horde only) (Shapeshifting Sentinel's Strides)", "world", nil, "Horde"),
        item(7751, "Quest: Vorrel's Revenge (Horde only) (Vorrel's Boots)", "quest", nil, "Horde"),
        item(15350, "World drop, sold at the auction house (Headhunter's Slippers of Agility)", "world", nil),
        item(16977, "Quest: Warsong Supplies (Horde only) (Warsong Boots)", "quest", nil, "Horde"),
        item(4055, "World drop, sold at the auction house (Insignia Boots)", "world", nil),
        item(1121, "World drop, sold at the auction house (Feet of the Lynx)", "world", nil),
    },
    ring1 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(7686, "Ironspine, Scarlet Monastery Graveyard (Ironspine's Eye)", "dungeon", nil),
        item(270052, "Quest: Jarl Needs a Blade (Swamp Ring)", "quest", nil),
        item(281634, "Quest: Greater Friend of the Library (Field Researcher's Loop)", "quest", nil),
    },
    ring2 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(7686, "Ironspine, Scarlet Monastery Graveyard (Ironspine's Eye)", "dungeon", nil),
        item(270052, "Quest: Jarl Needs a Blade (Swamp Ring)", "quest", nil),
        item(281634, "Quest: Greater Friend of the Library (Field Researcher's Loop)", "quest", nil),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
    },
    mainhand = {
        item(3197, "World drop, sold at the auction house (Stonecutter Claymore of Agility)", "world", nil),
        item(6679, "Razorfen Spearhide, Razorfen Kraul (Armor Piercer)", "dungeon", nil),
        item(2280, "Kam Deepfury, The Stockade (Alliance only) (Kam's Walking Stick)", "dungeon", nil, "Alliance"),
        item(5200, "Captain Greenskin, The Deadmines (Impaling Harpoon)", "dungeon", nil),
    },
    ranged = {
        item(277254, "Quest: Greater Friend of the Library, from level 30 (Truthseeker's Bow)", "quest", nil),
        item(17042, "Quest: An Unholy Alliance (Horde only) (Nail Spitter)", "quest", nil, "Horde"),
        item(274084, "Quest: A Vengeful Fate (Horde only) (Quilboar Blaster)", "quest", nil, "Horde"),
        item(9456, "Dark Iron Ambassador, Gnomeregan (Glass Shooter)", "dungeon", nil),
        item(274748, "Sold by Gezzy Gunkgear in Booty Bay (Booty Bay Bruiser's Buckshot)", "reputation", nil),
    },
} }
-- Beast Mastery: foreverchanges.pro/bis/hunter: single Hunter PvE list for the class (reused); weapons: two-hander per site paperdoll; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["HUNTER"]["Beast Mastery"] = { lvl30 = {
    head = {
        item(7413, "World drop, sold at the auction house (Infiltrator Cap of Agility)", "world", nil),
        item(6204, "World drop, sold at the auction house (Tribal Worg Helm)", "world", nil),
        item(252512, "Gelihast, Blackfathom Deeps (Brawler's Leather Helm)", "dungeon", nil),
        item(6720, "Quest: Frostmaw (Horde only) (Spirit Hunter Headdress)", "quest", nil, "Horde"),
    },
    neck = {
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of Agility)", "world", nil),
        item(7731, "Azshir the Sleepless, Scarlet Monastery Graveyard (Ghostshard Talisman)", "dungeon", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(274068, "Crowd Pummeler 9-60, Gnomeregan (Thermaplugg Medal of Honor)", "dungeon", nil),
    },
    shoulder = {
        item(2278, "World drop, sold at the auction house (Forest Tracker Epaulets)", "world", nil),
        item(2264, "Trash mobs, Razorfen Kraul (Mantle of Thieves)", "dungeon", nil),
        item(15140, "World drop, sold at the auction house (Cutthroat's Mantle of Agility)", "world", nil),
        item(277043, "Leatherworking (175) (Cloudy Gustwoven Spaulders)", "crafted", nil),
    },
    back = {
        item(13108, "World drop, sold at the auction house (Tigerstrike Mantle)", "world", nil),
        item(7436, "World drop, sold at the auction house (Twilight Cape of Agility)", "world", nil),
        item(271716, "Quest: Lost Relic Carry (Alliance only) (Explorer's League Dustcover)", "quest", nil, "Alliance"),
        item(14593, "World drop, sold at the auction house (Hawkeye's Cloak)", "world", nil),
    },
    chest = {
        item(7374, "Leatherworking (Dusky Leather Armor)", "crafted", nil),
        item(7407, "World drop, sold at the auction house (Infiltrator Armor of Agility)", "world", nil),
        item(273026, "Shadetooth, Excavation Site: Wetlands (Garb of Florid Feathers)", "dungeon", nil),
        item(4255, "Leatherworking (130) (Green Leather Armor)", "crafted", nil),
    },
    wrist = {
        item(9428, "Trash mobs, Uldaman (Unearthed Bands of Agility)", "dungeon", nil),
        item(270055, "Quest: Power Stones (Charged Leather Bracers)", "quest", nil),
        item(14590, "World drop, sold at the auction house (Hawkeye's Bracers)", "world", nil),
        item(6198, "World drop, sold at the auction house (Jurassic Wristguards)", "world", nil),
    },
    hands = {
        item(270072, "Crushridge Warmongers, from Marshal Redpath in Southshore (Alliance only) (Alterac Assassin's Gloves)", "quest", nil, "Alliance"),
        item(15355, "World drop, sold at the auction house (Headhunter's Mitts of Agility)", "world", nil),
        item(6727, "Quest: Safety First (Razzeric's Racing Grips)", "quest", nil),
        item(7358, "Leatherworking (115) (Pilferer's Gloves)", "crafted", nil),
    },
    waist = {
        item(252521, "Leatherworking (150) (Stalker's Leather Belt)", "crafted", nil),
        item(252520, "Leatherworking (150) (Skulker's Leather Belt)", "crafted", nil),
        item(15148, "World drop, sold at the auction house (Ghostwalker Belt of Agility)", "world", nil),
        item(16659, "Quest: Je'neu of the Earthen Ring (Horde only) (Deftkin Belt)", "quest", nil, "Horde"),
    },
    legs = {
        item(9624, "Quest: Rig Wars (Triprunner Dungarees)", "quest", nil),
        item(6690, "Agathelos the Raging, Razorfen Kraul (Ferine Leggings)", "dungeon", nil),
        item(9509, "Trash mobs, Gnomeregan (Petrolspill Leggings)", "dungeon", nil),
        item(13114, "World drop, sold at the auction house (Troll's Bane Leggings)", "world", nil),
    },
    feet = {
        item(284403, "A rare of northern Stonetalon Mountains, near the night elves (Horde only) (Shapeshifting Sentinel's Strides)", "world", nil, "Horde"),
        item(7751, "Quest: Vorrel's Revenge (Horde only) (Vorrel's Boots)", "quest", nil, "Horde"),
        item(15350, "World drop, sold at the auction house (Headhunter's Slippers of Agility)", "world", nil),
        item(16977, "Quest: Warsong Supplies (Horde only) (Warsong Boots)", "quest", nil, "Horde"),
        item(4055, "World drop, sold at the auction house (Insignia Boots)", "world", nil),
        item(1121, "World drop, sold at the auction house (Feet of the Lynx)", "world", nil),
    },
    ring1 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(7686, "Ironspine, Scarlet Monastery Graveyard (Ironspine's Eye)", "dungeon", nil),
        item(270052, "Quest: Jarl Needs a Blade (Swamp Ring)", "quest", nil),
        item(281634, "Quest: Greater Friend of the Library (Field Researcher's Loop)", "quest", nil),
    },
    ring2 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(7686, "Ironspine, Scarlet Monastery Graveyard (Ironspine's Eye)", "dungeon", nil),
        item(270052, "Quest: Jarl Needs a Blade (Swamp Ring)", "quest", nil),
        item(281634, "Quest: Greater Friend of the Library (Field Researcher's Loop)", "quest", nil),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
    },
    mainhand = {
        item(3197, "World drop, sold at the auction house (Stonecutter Claymore of Agility)", "world", nil),
        item(6679, "Razorfen Spearhide, Razorfen Kraul (Armor Piercer)", "dungeon", nil),
        item(2280, "Kam Deepfury, The Stockade (Alliance only) (Kam's Walking Stick)", "dungeon", nil, "Alliance"),
        item(5200, "Captain Greenskin, The Deadmines (Impaling Harpoon)", "dungeon", nil),
    },
    ranged = {
        item(277254, "Quest: Greater Friend of the Library, from level 30 (Truthseeker's Bow)", "quest", nil),
        item(17042, "Quest: An Unholy Alliance (Horde only) (Nail Spitter)", "quest", nil, "Horde"),
        item(274084, "Quest: A Vengeful Fate (Horde only) (Quilboar Blaster)", "quest", nil, "Horde"),
        item(9456, "Dark Iron Ambassador, Gnomeregan (Glass Shooter)", "dungeon", nil),
        item(274748, "Sold by Gezzy Gunkgear in Booty Bay (Booty Bay Bruiser's Buckshot)", "reputation", nil),
    },
} }

-- ============================================================
-- ROGUE
-- ============================================================
DB["ROGUE"] = {}
-- Combat: foreverchanges.pro/bis/rogue: Combat PvE list; weapons: 1H+off-hand per site paperdoll; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["ROGUE"]["Combat"] = { lvl30 = {
    head = {
        item(7413, "World drop, sold at the auction house (Infiltrator Cap of the Tiger)", "world", nil),
        item(252512, "Gelihast, Blackfathom Deeps (Brawler's Leather Helm)", "dungeon", nil),
        item(6720, "Quest: Frostmaw (Horde only) (Spirit Hunter Headdress)", "quest", nil, "Horde"),
        item(252504, "Leatherworking (100) (Brawler's Leather Hood)", "crafted", nil),
    },
    neck = {
        item(7731, "Azshir the Sleepless, Scarlet Monastery Graveyard (Ghostshard Talisman)", "dungeon", nil),
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of Agility)", "world", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(274068, "Crowd Pummeler 9-60, Gnomeregan (Thermaplugg Medal of Honor)", "dungeon", nil),
    },
    shoulder = {
        item(2278, "World drop, sold at the auction house (Forest Tracker Epaulets)", "world", nil),
        item(2264, "Trash mobs, Razorfen Kraul (Mantle of Thieves)", "dungeon", nil),
        item(15140, "World drop, sold at the auction house (Cutthroat's Mantle of the Tiger)", "world", nil),
        item(5964, "Leatherworking (Barbaric Shoulders)", "crafted", nil),
    },
    back = {
        item(13108, "World drop, sold at the auction house (Tigerstrike Mantle)", "world", nil),
        item(14593, "World drop, sold at the auction house (Hawkeye's Cloak)", "world", nil),
        item(10518, "Engineering (225) (Parachute Cloak)", "crafted", nil),
        item(2805, "Quest: Bartolo's Yeti Fur Cloak (Alliance only)", "quest", nil, "Alliance"),
    },
    chest = {
        item(7374, "Leatherworking (Dusky Leather Armor)", "crafted", nil),
        item(7407, "World drop, sold at the auction house (Infiltrator Armor of Agility)", "world", nil),
        item(252508, "Leatherworking (110) (Brawler's Leather Tunic)", "crafted", nil),
        item(2041, "Quest: The Defias Brotherhood (Alliance only) (Tunic of Westfall)", "quest", nil, "Alliance"),
    },
    wrist = {
        item(9428, "Trash mobs, Uldaman (Unearthed Bands of Power)", "dungeon", nil),
        item(270080, "Wanted! Otto and Falconcrest, Refuge Pointe, Arathi Highlands (Alliance only) (Arathi Armbands)", "quest", nil, "Alliance"),
        item(14590, "World drop, sold at the auction house (Hawkeye's Bracers)", "world", nil),
        item(18948, "Leatherworking (130) (Barbaric Bracers)", "crafted", nil),
    },
    hands = {
        item(270072, "Crushridge Warmongers, from Marshal Redpath in Southshore (Alliance only) (Alterac Assassin's Gloves)", "quest", nil, "Alliance"),
        item(4107, "Quest: Tiger Mastery (Tiger Hunter Gloves)", "quest", nil),
        item(15355, "World drop, sold at the auction house (Headhunter's Mitts of the Tiger)", "world", nil),
        item(3754, "Quest: Costly Menace (Alliance only) (Shepherd's Gloves)", "quest", nil, "Alliance"),
        item(6408, "World drop, sold at the auction house (Insignia Gloves)", "world", nil),
    },
    waist = {
        item(252520, "Leatherworking (150) (Skulker's Leather Belt)", "crafted", nil),
        item(15148, "World drop, sold at the auction house (Ghostwalker Belt of the Tiger)", "world", nil),
        item(10403, "Captain Greenskin, The Deadmines (Blackened Defias Belt)", "dungeon", nil),
        item(16659, "Quest: Je'neu of the Earthen Ring (Horde only) (Deftkin Belt)", "quest", nil, "Horde"),
    },
    legs = {
        item(9624, "Quest: Rig Wars (Triprunner Dungarees)", "quest", nil),
        item(9509, "Trash mobs, Gnomeregan (Petrolspill Leggings)", "dungeon", nil),
        item(13114, "World drop, sold at the auction house (Troll's Bane Leggings)", "world", nil),
        item(252516, "Leatherworking (125) (Brawler's Leather Legguards)", "crafted", nil),
    },
    feet = {
        item(284403, "A rare of northern Stonetalon Mountains, near the night elves (Horde only) (Shapeshifting Sentinel's Strides)", "world", nil, "Horde"),
        item(7751, "Quest: Vorrel's Revenge (Horde only) (Vorrel's Boots)", "quest", nil, "Horde"),
        item(15350, "World drop, sold at the auction house (Headhunter's Slippers of the Tiger)", "world", nil),
        item(1121, "World drop, sold at the auction house (Feet of the Lynx)", "world", nil),
        item(16977, "Quest: Warsong Supplies (Horde only) (Warsong Boots)", "quest", nil, "Horde"),
        item(4055, "World drop, sold at the auction house (Insignia Boots)", "world", nil),
    },
    ring1 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(7686, "Ironspine, Scarlet Monastery Graveyard (Ironspine's Eye)", "dungeon", nil),
        item(270052, "Quest: Jarl Needs a Blade (Swamp Ring)", "quest", nil),
        item(277210, "Rogue quest The Horn of Xelthos, from level 20 (Pyrewood Signet Ring)", "quest", nil),
    },
    ring2 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(7686, "Ironspine, Scarlet Monastery Graveyard (Ironspine's Eye)", "dungeon", nil),
        item(270052, "Quest: Jarl Needs a Blade (Swamp Ring)", "quest", nil),
        item(277210, "Rogue quest The Horn of Xelthos, from level 20 (Pyrewood Signet Ring)", "quest", nil),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
    },
    mainhand = {
        item(13033, "World drop, sold at the auction house (Zealot Blade)", "world", nil),
        item(277246, "Rogue quest The Eye of Bhossca, Silverpine Forest, level 35 (Ruby-Adorned Blade)", "quest", nil),
        item(6804, "Quest: Final Passage (Horde only) (Windstorm Hammer)", "quest", nil, "Horde"),
        item(7687, "Ironspine, Scarlet Monastery Graveyard (Ironspine's Fist)", "dungeon", nil),
    },
    offhand = {
        item(271802, "Khan Jehn, a Gelkis quest in Desolace (Bludgeon of Betrayed Virtues)", "quest", nil),
        item(280805, "Quest: Changing Tastes (Horde only) (Serrated Raptor Claw)", "quest", nil, "Horde"),
        item(7682, "Interrogator Vishas, Scarlet Monastery Graveyard (Torturing Poker)", "dungeon", nil),
        item(7683, "Interrogator Vishas, Scarlet Monastery Graveyard (Bloody Brass Knuckles)", "dungeon", nil),
    },
    ranged = {
        item(277254, "Quest: Greater Friend of the Library, from level 30 (Truthseeker's Bow)", "quest", nil),
        item(9456, "Dark Iron Ambassador, Gnomeregan (Glass Shooter)", "dungeon", nil),
        item(273029, "Relic Guardian, Excavation Site: Wetlands (Golemsight Long Gun)", "dungeon", nil),
        item(274748, "Sold by Gezzy Gunkgear in Booty Bay (Booty Bay Bruiser's Buckshot)", "reputation", nil),
    },
} }
-- Assassination: foreverchanges.pro/bis/rogue/assassination: Assassination PvE list; weapons: 1H+main-hand per site paperdoll; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["ROGUE"]["Assassination"] = { lvl30 = {
    head = {
        item(7413, "World drop, sold at the auction house (Infiltrator Cap of the Tiger)", "world", nil),
        item(252512, "Gelihast, Blackfathom Deeps (Brawler's Leather Helm)", "dungeon", nil),
        item(6720, "Quest: Frostmaw (Horde only) (Spirit Hunter Headdress)", "quest", nil, "Horde"),
        item(252504, "Leatherworking (100) (Brawler's Leather Hood)", "crafted", nil),
    },
    neck = {
        item(7731, "Azshir the Sleepless, Scarlet Monastery Graveyard (Ghostshard Talisman)", "dungeon", nil),
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of Agility)", "world", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(274068, "Crowd Pummeler 9-60, Gnomeregan (Thermaplugg Medal of Honor)", "dungeon", nil),
    },
    shoulder = {
        item(2278, "World drop, sold at the auction house (Forest Tracker Epaulets)", "world", nil),
        item(2264, "Trash mobs, Razorfen Kraul (Mantle of Thieves)", "dungeon", nil),
        item(15140, "World drop, sold at the auction house (Cutthroat's Mantle of the Tiger)", "world", nil),
        item(5964, "Leatherworking (Barbaric Shoulders)", "crafted", nil),
    },
    back = {
        item(13108, "World drop, sold at the auction house (Tigerstrike Mantle)", "world", nil),
        item(14593, "World drop, sold at the auction house (Hawkeye's Cloak)", "world", nil),
        item(10518, "Engineering (225) (Parachute Cloak)", "crafted", nil),
        item(2805, "Quest: Bartolo's Yeti Fur Cloak (Alliance only)", "quest", nil, "Alliance"),
    },
    chest = {
        item(7374, "Leatherworking (Dusky Leather Armor)", "crafted", nil),
        item(7407, "World drop, sold at the auction house (Infiltrator Armor of Agility)", "world", nil),
        item(252508, "Leatherworking (110) (Brawler's Leather Tunic)", "crafted", nil),
        item(2041, "Quest: The Defias Brotherhood (Alliance only) (Tunic of Westfall)", "quest", nil, "Alliance"),
    },
    wrist = {
        item(9428, "Trash mobs, Uldaman (Unearthed Bands of Power)", "dungeon", nil),
        item(270080, "Wanted! Otto and Falconcrest, Refuge Pointe, Arathi Highlands (Alliance only) (Arathi Armbands)", "quest", nil, "Alliance"),
        item(14590, "World drop, sold at the auction house (Hawkeye's Bracers)", "world", nil),
        item(18948, "Leatherworking (130) (Barbaric Bracers)", "crafted", nil),
    },
    hands = {
        item(270072, "Crushridge Warmongers, from Marshal Redpath in Southshore (Alliance only) (Alterac Assassin's Gloves)", "quest", nil, "Alliance"),
        item(4107, "Quest: Tiger Mastery (Tiger Hunter Gloves)", "quest", nil),
        item(15355, "World drop, sold at the auction house (Headhunter's Mitts of the Tiger)", "world", nil),
        item(3754, "Quest: Costly Menace (Alliance only) (Shepherd's Gloves)", "quest", nil, "Alliance"),
        item(6408, "World drop, sold at the auction house (Insignia Gloves)", "world", nil),
    },
    waist = {
        item(252520, "Leatherworking (150) (Skulker's Leather Belt)", "crafted", nil),
        item(15148, "World drop, sold at the auction house (Ghostwalker Belt of the Tiger)", "world", nil),
        item(10403, "Captain Greenskin, The Deadmines (Blackened Defias Belt)", "dungeon", nil),
        item(16659, "Quest: Je'neu of the Earthen Ring (Horde only) (Deftkin Belt)", "quest", nil, "Horde"),
    },
    legs = {
        item(9624, "Quest: Rig Wars (Triprunner Dungarees)", "quest", nil),
        item(9509, "Trash mobs, Gnomeregan (Petrolspill Leggings)", "dungeon", nil),
        item(13114, "World drop, sold at the auction house (Troll's Bane Leggings)", "world", nil),
        item(252516, "Leatherworking (125) (Brawler's Leather Legguards)", "crafted", nil),
    },
    feet = {
        item(284403, "A rare of northern Stonetalon Mountains, near the night elves (Horde only) (Shapeshifting Sentinel's Strides)", "world", nil, "Horde"),
        item(7751, "Quest: Vorrel's Revenge (Horde only) (Vorrel's Boots)", "quest", nil, "Horde"),
        item(15350, "World drop, sold at the auction house (Headhunter's Slippers of the Tiger)", "world", nil),
        item(1121, "World drop, sold at the auction house (Feet of the Lynx)", "world", nil),
        item(16977, "Quest: Warsong Supplies (Horde only) (Warsong Boots)", "quest", nil, "Horde"),
        item(4055, "World drop, sold at the auction house (Insignia Boots)", "world", nil),
    },
    ring1 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(7686, "Ironspine, Scarlet Monastery Graveyard (Ironspine's Eye)", "dungeon", nil),
        item(270052, "Quest: Jarl Needs a Blade (Swamp Ring)", "quest", nil),
        item(277210, "Rogue quest The Horn of Xelthos, from level 20 (Pyrewood Signet Ring)", "quest", nil),
    },
    ring2 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(7686, "Ironspine, Scarlet Monastery Graveyard (Ironspine's Eye)", "dungeon", nil),
        item(270052, "Quest: Jarl Needs a Blade (Swamp Ring)", "quest", nil),
        item(277210, "Rogue quest The Horn of Xelthos, from level 20 (Pyrewood Signet Ring)", "quest", nil),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
    },
    mainhand = {
        item(9453, "Viscous Fallout, Gnomeregan (Toxic Revenger)", "dungeon", nil),
        item(9520, "Quest: Call to Arms (Horde only) (Silent Hunter)", "quest", nil, "Horde"),
        item(280805, "Quest: Changing Tastes (Horde only) (Serrated Raptor Claw)", "quest", nil, "Horde"),
        item(6681, "Aggem Thorncurse, Razorfen Kraul (Thornspike)", "dungeon", nil),
        item(7682, "Interrogator Vishas, Scarlet Monastery Graveyard (Torturing Poker)", "dungeon", nil),
    },
    offhand = {
        item(7682, "Interrogator Vishas, Scarlet Monastery Graveyard (Torturing Poker)", "dungeon", nil),
        item(9520, "Quest: Call to Arms (Horde only) (Silent Hunter)", "quest", nil, "Horde"),
        item(280805, "Quest: Changing Tastes (Horde only) (Serrated Raptor Claw)", "quest", nil, "Horde"),
        item(9453, "Viscous Fallout, Gnomeregan (Toxic Revenger)", "dungeon", nil),
        item(6681, "Aggem Thorncurse, Razorfen Kraul (Thornspike)", "dungeon", nil),
    },
    ranged = {
        item(277254, "Quest: Greater Friend of the Library, from level 30 (Truthseeker's Bow)", "quest", nil),
        item(9456, "Dark Iron Ambassador, Gnomeregan (Glass Shooter)", "dungeon", nil),
        item(273029, "Relic Guardian, Excavation Site: Wetlands (Golemsight Long Gun)", "dungeon", nil),
        item(274748, "Sold by Gezzy Gunkgear in Booty Bay (Booty Bay Bruiser's Buckshot)", "reputation", nil),
    },
} }

-- ============================================================
-- PRIEST
-- ============================================================
DB["PRIEST"] = {}
-- Holy: foreverchanges.pro/bis/priest/holy: Holy PvE list; weapons: 1H+held per site paperdoll; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["PRIEST"]["Holy"] = { lvl30 = {
    head = {
        item(2721, "World drop, sold at the auction house (Holy Shroud)", "world", nil),
        item(7691, "Fallen Champion, Scarlet Monastery Graveyard (Embalmed Shroud)", "dungeon", nil),
        item(14200, "World drop, sold at the auction house (Thistlefur Cap of Healing)", "world", nil),
        item(284401, "Sorrow Wing, the rare of Stonetalon Mountains (Sorrow's Shroud)", "world", nil),
    },
    neck = {
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of the Physician)", "world", nil),
        item(7746, "Quest: Mythology of the Titans (Alliance only) (Explorers' League Commendation)", "quest", nil, "Alliance"),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(281321, "Alliance quest Gleaning Our Future, Wetlands, level 32 (Giantstone Medallion)", "quest", nil, "Alliance"),
        item(5003, "World drop, sold at the auction house (Crystal Starfire Medallion)", "world", nil),
    },
    shoulder = {
        item(14201, "World drop, sold at the auction house (Thistlefur Mantle of Healing)", "world", nil),
        item(3324, "Quest: Deathstalkers in Shadowfang (Horde only) (Ghostly Mantle)", "quest", nil, "Horde"),
        item(7684, "Bloodmage Thalnos, Scarlet Monastery Graveyard (Bloodmage Mantle)", "dungeon", nil),
        item(4197, "Quest: A Vengeful Fate (Berylline Pads)", "quest", nil),
    },
    back = {
        item(7436, "World drop, sold at the auction house (Twilight Cape of Healing)", "world", nil),
        item(9605, "Quest: Data Rescue (Alliance only) (Repairman's Cape)", "quest", nil, "Alliance"),
        item(7004, "Quest: Researching the Corruption (Alliance only) (Prelacy Cape)", "quest", nil, "Alliance"),
        item(273825, "Bazil Thredd, The Stockade (Alliance only) (Red Wool Cloak)", "dungeon", nil, "Alliance"),
        item(6901, "Old Serra'kis, Blackfathom Deeps (Glowing Thresher Cape)", "dungeon", nil),
        item(274149, "Roogug, Razorfen Kraul (Thornweaver Drape)", "dungeon", nil),
    },
    chest = {
        item(9623, "Quest: Rig Wars (Civinad Robes)", "quest", nil),
        item(4746, "Quest: Solution to Doom (Doomsayer's Robe)", "quest", nil),
        item(7353, "World drop, sold at the auction house (Elder's Padded Armor of Healing)", "world", nil),
        item(6682, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Robes)", "dungeon", nil),
    },
    wrist = {
        item(9846, "World drop, sold at the auction house (Conjurer's Bracers of Healing)", "world", nil),
        item(9448, "Electrocutioner 6000, Gnomeregan (Spidertank Oilrag)", "dungeon", nil),
        item(271740, "Quest: Open the Maw (Horde only) (Knife-Polishing Rag)", "quest", nil, "Horde"),
        item(273808, "Kam Deepfury, The Stockade (Alliance only) (Bridgebreaker Bindings)", "dungeon", nil, "Alliance"),
    },
    hands = {
        item(270059, "Agmond's Fate, from Prospector Ironband in Loch Modan (Alliance only) (Restorer's Fine Gloves)", "quest", nil, "Alliance"),
        item(14211, "World drop, sold at the auction house (Vital Handwraps of Healing)", "world", nil),
        item(7049, "Tailoring (125) (Truefaith Gloves)", "crafted", nil),
        item(270030, "Horde quest The Book of Ur, from level 16 (Tattered Mittens)", "quest", nil, "Horde"),
    },
    waist = {
        item(9853, "World drop, sold at the auction house (Conjurer's Cinch of Healing)", "world", nil),
        item(253925, "Tailoring (85) (Pristine Sash)", "crafted", nil),
        item(6392, "Archmage Arugal, Shadowfang Keep (Belt of Arugal)", "dungeon", nil),
        item(16975, "Quest: Warsong Supplies (Horde only) (Warsong Sash)", "quest", nil, "Horde"),
    },
    legs = {
        item(14203, "World drop, sold at the auction house (Thistlefur Pants of Healing)", "world", nil),
        item(253937, "Tailoring (100) (Filigreed Pristine Leggings)", "crafted", nil),
        item(253987, "Tailoring (125) (Pristine Leggings)", "crafted", nil),
        item(253999, "Tailoring (140) (Earthen Leggings)", "crafted", nil),
    },
    feet = {
        item(10359, "Quest: Power Stones (Everlast Boots)", "quest", nil),
        item(254001, "Tailoring (140) (Gilded Slippers)", "crafted", nil),
        item(14214, "World drop, sold at the auction house (Vital Boots of Healing)", "world", nil),
        item(6998, "Quest: Twilight Falls (Alliance only) (Nimbus Boots)", "quest", nil, "Alliance"),
    },
    ring1 = {
        item(274746, "Sold by Gezzy Gunkgear in Booty Bay (Sea Giant's Toe Ring)", "reputation", nil),
        item(9447, "Electrocutioner 6000, Gnomeregan (Electrocutioner Lagnut)", "dungeon", nil),
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
    },
    ring2 = {
        item(9447, "Electrocutioner 6000, Gnomeregan (Electrocutioner Lagnut)", "dungeon", nil),
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(271670, "Quest: Horrors in the Highland (Alliance only) (Curl of Life)", "quest", nil, "Alliance"),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    trinket2 = {
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    mainhand = {
        item(9457, "Dark Iron Ambassador, Gnomeregan (Royal Diplomatic Scepter)", "dungeon", nil),
        item(2816, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Scepter)", "dungeon", nil),
        item(17039, "Quest: An Unholy Alliance (Horde only) (Skullbreaker)", "quest", nil, "Horde"),
        item(6691, "Agathelos the Raging, Razorfen Kraul (Swinetusk Shank)", "dungeon", nil),
    },
    offhand = {
        item(7609, "World drop, sold at the auction house (Elder's Amber Stave of Healing)", "world", nil),
        item(249395, "Enchanting (140) (Orb of Souls)", "crafted", nil),
        item(2943, "Quest: Cleansing the Eye (Alliance only) (Eye of Paleth)", "quest", nil, "Alliance"),
        item(13031, "World drop, sold at the auction house (Orb of Mistmantle)", "world", nil),
    },
    ranged = {
        item(7708, "Azshir the Sleepless, Scarlet Monastery Graveyard (Necrotic Wand)", "dungeon", nil),
        item(6806, "Quest: Final Passage (Horde only) (Dancing Flame)", "quest", nil, "Horde"),
        item(13062, "World drop, sold at the auction house (Thunderwood)", "world", nil),
        item(5214, "World drop, sold at the auction house (Wand of Eventide)", "world", nil),
    },
} }
-- Discipline: foreverchanges.pro/bis/priest/holy: Holy PvE healer list reused (site only has Discipline PvP); weapons: 1H+held per site paperdoll; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["PRIEST"]["Discipline"] = { lvl30 = {
    head = {
        item(2721, "World drop, sold at the auction house (Holy Shroud)", "world", nil),
        item(7691, "Fallen Champion, Scarlet Monastery Graveyard (Embalmed Shroud)", "dungeon", nil),
        item(14200, "World drop, sold at the auction house (Thistlefur Cap of Healing)", "world", nil),
        item(284401, "Sorrow Wing, the rare of Stonetalon Mountains (Sorrow's Shroud)", "world", nil),
    },
    neck = {
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of the Physician)", "world", nil),
        item(7746, "Quest: Mythology of the Titans (Alliance only) (Explorers' League Commendation)", "quest", nil, "Alliance"),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(281321, "Alliance quest Gleaning Our Future, Wetlands, level 32 (Giantstone Medallion)", "quest", nil, "Alliance"),
        item(5003, "World drop, sold at the auction house (Crystal Starfire Medallion)", "world", nil),
    },
    shoulder = {
        item(14201, "World drop, sold at the auction house (Thistlefur Mantle of Healing)", "world", nil),
        item(3324, "Quest: Deathstalkers in Shadowfang (Horde only) (Ghostly Mantle)", "quest", nil, "Horde"),
        item(7684, "Bloodmage Thalnos, Scarlet Monastery Graveyard (Bloodmage Mantle)", "dungeon", nil),
        item(4197, "Quest: A Vengeful Fate (Berylline Pads)", "quest", nil),
    },
    back = {
        item(7436, "World drop, sold at the auction house (Twilight Cape of Healing)", "world", nil),
        item(9605, "Quest: Data Rescue (Alliance only) (Repairman's Cape)", "quest", nil, "Alliance"),
        item(7004, "Quest: Researching the Corruption (Alliance only) (Prelacy Cape)", "quest", nil, "Alliance"),
        item(273825, "Bazil Thredd, The Stockade (Alliance only) (Red Wool Cloak)", "dungeon", nil, "Alliance"),
        item(6901, "Old Serra'kis, Blackfathom Deeps (Glowing Thresher Cape)", "dungeon", nil),
        item(274149, "Roogug, Razorfen Kraul (Thornweaver Drape)", "dungeon", nil),
    },
    chest = {
        item(9623, "Quest: Rig Wars (Civinad Robes)", "quest", nil),
        item(4746, "Quest: Solution to Doom (Doomsayer's Robe)", "quest", nil),
        item(7353, "World drop, sold at the auction house (Elder's Padded Armor of Healing)", "world", nil),
        item(6682, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Robes)", "dungeon", nil),
    },
    wrist = {
        item(9846, "World drop, sold at the auction house (Conjurer's Bracers of Healing)", "world", nil),
        item(9448, "Electrocutioner 6000, Gnomeregan (Spidertank Oilrag)", "dungeon", nil),
        item(271740, "Quest: Open the Maw (Horde only) (Knife-Polishing Rag)", "quest", nil, "Horde"),
        item(273808, "Kam Deepfury, The Stockade (Alliance only) (Bridgebreaker Bindings)", "dungeon", nil, "Alliance"),
    },
    hands = {
        item(270059, "Agmond's Fate, from Prospector Ironband in Loch Modan (Alliance only) (Restorer's Fine Gloves)", "quest", nil, "Alliance"),
        item(14211, "World drop, sold at the auction house (Vital Handwraps of Healing)", "world", nil),
        item(7049, "Tailoring (125) (Truefaith Gloves)", "crafted", nil),
        item(270030, "Horde quest The Book of Ur, from level 16 (Tattered Mittens)", "quest", nil, "Horde"),
    },
    waist = {
        item(9853, "World drop, sold at the auction house (Conjurer's Cinch of Healing)", "world", nil),
        item(253925, "Tailoring (85) (Pristine Sash)", "crafted", nil),
        item(6392, "Archmage Arugal, Shadowfang Keep (Belt of Arugal)", "dungeon", nil),
        item(16975, "Quest: Warsong Supplies (Horde only) (Warsong Sash)", "quest", nil, "Horde"),
    },
    legs = {
        item(14203, "World drop, sold at the auction house (Thistlefur Pants of Healing)", "world", nil),
        item(253937, "Tailoring (100) (Filigreed Pristine Leggings)", "crafted", nil),
        item(253987, "Tailoring (125) (Pristine Leggings)", "crafted", nil),
        item(253999, "Tailoring (140) (Earthen Leggings)", "crafted", nil),
    },
    feet = {
        item(10359, "Quest: Power Stones (Everlast Boots)", "quest", nil),
        item(254001, "Tailoring (140) (Gilded Slippers)", "crafted", nil),
        item(14214, "World drop, sold at the auction house (Vital Boots of Healing)", "world", nil),
        item(6998, "Quest: Twilight Falls (Alliance only) (Nimbus Boots)", "quest", nil, "Alliance"),
    },
    ring1 = {
        item(274746, "Sold by Gezzy Gunkgear in Booty Bay (Sea Giant's Toe Ring)", "reputation", nil),
        item(9447, "Electrocutioner 6000, Gnomeregan (Electrocutioner Lagnut)", "dungeon", nil),
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
    },
    ring2 = {
        item(9447, "Electrocutioner 6000, Gnomeregan (Electrocutioner Lagnut)", "dungeon", nil),
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(271670, "Quest: Horrors in the Highland (Alliance only) (Curl of Life)", "quest", nil, "Alliance"),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    trinket2 = {
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    mainhand = {
        item(9457, "Dark Iron Ambassador, Gnomeregan (Royal Diplomatic Scepter)", "dungeon", nil),
        item(2816, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Scepter)", "dungeon", nil),
        item(17039, "Quest: An Unholy Alliance (Horde only) (Skullbreaker)", "quest", nil, "Horde"),
        item(6691, "Agathelos the Raging, Razorfen Kraul (Swinetusk Shank)", "dungeon", nil),
    },
    offhand = {
        item(7609, "World drop, sold at the auction house (Elder's Amber Stave of Healing)", "world", nil),
        item(249395, "Enchanting (140) (Orb of Souls)", "crafted", nil),
        item(2943, "Quest: Cleansing the Eye (Alliance only) (Eye of Paleth)", "quest", nil, "Alliance"),
        item(13031, "World drop, sold at the auction house (Orb of Mistmantle)", "world", nil),
    },
    ranged = {
        item(7708, "Azshir the Sleepless, Scarlet Monastery Graveyard (Necrotic Wand)", "dungeon", nil),
        item(6806, "Quest: Final Passage (Horde only) (Dancing Flame)", "quest", nil, "Horde"),
        item(13062, "World drop, sold at the auction house (Thunderwood)", "world", nil),
        item(5214, "World drop, sold at the auction house (Wand of Eventide)", "world", nil),
    },
} }
-- Shadow: foreverchanges.pro/bis/priest: Shadow PvE list; weapons: two-hander per site paperdoll; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["PRIEST"]["Shadow"] = { lvl30 = {
    head = {
        item(253981, "Tailoring (125) (Filigreed Shadow Circlet)", "crafted", nil),
        item(14200, "World drop, sold at the auction house (Thistlefur Cap of Shadow Wrath)", "world", nil),
        item(253955, "Tailoring (100) (Shadow Circlet)", "crafted", nil),
        item(7050, "Tailoring (Silk Headband)", "crafted", nil),
    },
    neck = {
        item(274749, "Sold by Gezzy Gunkgear in Booty Bay (Souvenir Sea Shell)", "reputation", nil),
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of the Sorcerer)", "world", nil),
        item(7746, "Quest: Mythology of the Titans (Alliance only) (Explorers' League Commendation)", "quest", nil, "Alliance"),
        item(13087, "World drop, sold at the auction house (River Pride Choker)", "world", nil),
    },
    shoulder = {
        item(4197, "Quest: A Vengeful Fate (Berylline Pads)", "quest", nil),
        item(14201, "World drop, sold at the auction house (Thistlefur Mantle of Shadow Wrath)", "world", nil),
        item(7684, "Bloodmage Thalnos, Scarlet Monastery Graveyard (Bloodmage Mantle)", "dungeon", nil),
        item(9536, "Quest: A Fine Mess (Fairywing Mantle)", "quest", nil),
    },
    back = {
        item(277206, "Strahnbrad Mystery, a quest of Alterac Mountains (Brilliant Cloak)", "quest", nil),
        item(7436, "World drop, sold at the auction house (Twilight Cape of Shadow Wrath)", "world", nil),
        item(274149, "Roogug, Razorfen Kraul (Thornweaver Drape)", "dungeon", nil),
        item(3719, "Leatherworking (Hillman's Cloak)", "crafted", nil),
    },
    chest = {
        item(253967, "Tailoring (110) (Shadow Gown)", "crafted", nil),
        item(17043, "Quest: An Unholy Alliance (Horde only) (Zealot's Robe)", "quest", nil, "Horde"),
        item(7353, "World drop, sold at the auction house (Elder's Padded Armor of Shadow Wrath)", "world", nil),
        item(2292, "Trash mobs, Shadowfang Keep (Necrology Robes)", "dungeon", nil),
    },
    wrist = {
        item(9448, "Electrocutioner 6000, Gnomeregan (Spidertank Oilrag)", "dungeon", nil),
        item(9846, "World drop, sold at the auction house (Conjurer's Bracers of Shadow Wrath)", "world", nil),
        item(4744, "Quest: Wanted!  Marez Cowl (Alliance only) (Arcane Runed Bracers)", "quest", nil, "Alliance"),
        item(271740, "Quest: Open the Maw (Horde only) (Knife-Polishing Rag)", "quest", nil, "Horde"),
    },
    hands = {
        item(14211, "World drop, sold at the auction house (Vital Handwraps of Shadow Wrath)", "world", nil),
        item(270059, "Agmond's Fate, from Prospector Ironband in Loch Modan (Alliance only) (Restorer's Fine Gloves)", "quest", nil, "Alliance"),
        item(253919, "Tailoring (75) (Shadow Gloves)", "crafted", nil),
        item(7047, "Tailoring (120) (Hands of Darkness)", "crafted", nil),
    },
    waist = {
        item(16975, "Quest: Warsong Supplies (Horde only) (Warsong Sash)", "quest", nil, "Horde"),
        item(9853, "World drop, sold at the auction house (Conjurer's Cinch of Shadow Wrath)", "world", nil),
        item(6908, "Ghamoo-ra, Blackfathom Deeps (Ghamoo-ra's Bind)", "dungeon", nil),
        item(253931, "Tailoring (85) (Shadow Sash)", "crafted", nil),
    },
    legs = {
        item(2277, "World drop, sold at the auction house (Necromancer Leggings)", "world", nil),
        item(253993, "Tailoring (125) (Shadow Leggings)", "crafted", nil),
        item(7709, "Azshir the Sleepless, Scarlet Monastery Graveyard (Blighted Leggings)", "dungeon", nil),
        item(253943, "Tailoring (100) (Filigreed Shadow Leggings)", "crafted", nil),
    },
    feet = {
        item(14214, "World drop, sold at the auction house (Vital Boots of Shadow Wrath)", "world", nil),
        item(4320, "Tailoring (Spidersilk Boots)", "crafted", nil),
        item(254007, "Tailoring (140) (Black Slippers)", "crafted", nil),
        item(7027, "Tailoring (Boots of Darkness)", "crafted", nil),
    },
    ring1 = {
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(2043, "Quest: The Legend of Stalvan (Alliance only) (Ring of Forlorn Spirits)", "quest", nil, "Alliance"),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(271670, "Quest: Horrors in the Highland (Alliance only) (Curl of Life)", "quest", nil, "Alliance"),
        item(282283, "Nightveiled Rotheap, a patrol of the Wetlands (Alliance only) (Malignant Root)", "world", nil, "Alliance"),
    },
    ring2 = {
        item(2043, "Quest: The Legend of Stalvan (Alliance only) (Ring of Forlorn Spirits)", "quest", nil, "Alliance"),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(271670, "Quest: Horrors in the Highland (Alliance only) (Curl of Life)", "quest", nil, "Alliance"),
        item(282283, "Nightveiled Rotheap, a patrol of the Wetlands (Alliance only) (Malignant Root)", "world", nil, "Alliance"),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    mainhand = {
        item(271803, "Khan Jehn, a Magram quest in Desolace (Greatstaff of the Necrokhans)", "quest", nil),
        item(2549, "Trash mobs, Razorfen Kraul (Staff of the Shade)", "dungeon", nil),
        item(249392, "Enchanting (140) (Glimmering Staff)", "crafted", nil),
        item(274158, "Aggem Thorncurse, Razorfen Kraul (Death Prophet Spine)", "dungeon", nil),
    },
    ranged = {
        item(7708, "Azshir the Sleepless, Scarlet Monastery Graveyard (Necrotic Wand)", "dungeon", nil),
        item(6806, "Quest: Final Passage (Horde only) (Dancing Flame)", "quest", nil, "Horde"),
        item(13062, "World drop, sold at the auction house (Thunderwood)", "world", nil),
        item(13063, "World drop, sold at the auction house (Starfaller)", "world", nil),
    },
} }

-- ============================================================
-- SHAMAN
-- ============================================================
DB["SHAMAN"] = {}
-- Restoration: foreverchanges.pro/bis/shaman/restoration: Restoration list; weapons: 1H+shield per site paperdoll; ranged slot holds the relic (libram/totem/idol) list; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["SHAMAN"]["Restoration"] = { lvl30 = {
    head = {
        item(2721, "World drop, sold at the auction house (Holy Shroud)", "world", nil),
        item(7691, "Fallen Champion, Scarlet Monastery Graveyard (Embalmed Shroud)", "dungeon", nil),
        item(14200, "World drop, sold at the auction house (Thistlefur Cap of Healing)", "world", nil),
        item(284401, "Sorrow Wing, the rare of Stonetalon Mountains (Sorrow's Shroud)", "world", nil),
    },
    neck = {
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of the Physician)", "world", nil),
        item(7746, "Quest: Mythology of the Titans (Alliance only) (Explorers' League Commendation)", "quest", nil, "Alliance"),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(281321, "Alliance quest Gleaning Our Future, Wetlands, level 32 (Giantstone Medallion)", "quest", nil, "Alliance"),
        item(5003, "World drop, sold at the auction house (Crystal Starfire Medallion)", "world", nil),
    },
    shoulder = {
        item(15357, "World drop, sold at the auction house (Headhunter's Spaulders of Healing)", "world", nil),
        item(3324, "Quest: Deathstalkers in Shadowfang (Horde only) (Ghostly Mantle)", "quest", nil, "Horde"),
        item(7684, "Bloodmage Thalnos, Scarlet Monastery Graveyard (Bloodmage Mantle)", "dungeon", nil),
        item(4197, "Quest: A Vengeful Fate (Berylline Pads)", "quest", nil),
    },
    back = {
        item(7436, "World drop, sold at the auction house (Twilight Cape of Healing)", "world", nil),
        item(9605, "Quest: Data Rescue (Alliance only) (Repairman's Cape)", "quest", nil, "Alliance"),
        item(7004, "Quest: Researching the Corruption (Alliance only) (Prelacy Cape)", "quest", nil, "Alliance"),
        item(273825, "Bazil Thredd, The Stockade (Alliance only) (Red Wool Cloak)", "dungeon", nil, "Alliance"),
        item(6901, "Old Serra'kis, Blackfathom Deeps (Glowing Thresher Cape)", "dungeon", nil),
        item(274149, "Roogug, Razorfen Kraul (Thornweaver Drape)", "dungeon", nil),
    },
    chest = {
        item(9623, "Quest: Rig Wars (Civinad Robes)", "quest", nil),
        item(4746, "Quest: Solution to Doom (Doomsayer's Robe)", "quest", nil),
        item(7407, "World drop, sold at the auction house (Infiltrator Armor of Healing)", "world", nil),
        item(6682, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Robes)", "dungeon", nil),
    },
    wrist = {
        item(9428, "Trash mobs, Uldaman (Unearthed Bands of Healing)", "dungeon", nil),
        item(9448, "Electrocutioner 6000, Gnomeregan (Spidertank Oilrag)", "dungeon", nil),
        item(271740, "Quest: Open the Maw (Horde only) (Knife-Polishing Rag)", "quest", nil, "Horde"),
        item(273808, "Kam Deepfury, The Stockade (Alliance only) (Bridgebreaker Bindings)", "dungeon", nil, "Alliance"),
    },
    hands = {
        item(270059, "Agmond's Fate, from Prospector Ironband in Loch Modan (Alliance only) (Restorer's Fine Gloves)", "quest", nil, "Alliance"),
        item(14211, "World drop, sold at the auction house (Vital Handwraps of Healing)", "world", nil),
        item(7049, "Tailoring (125) (Truefaith Gloves)", "crafted", nil),
        item(888, "Lady Sarevess, Blackfathom Deeps (Naga Battle Gloves)", "dungeon", nil),
    },
    waist = {
        item(252523, "Leatherworking (150) (Mender's Leather Belt)", "crafted", nil),
        item(9853, "World drop, sold at the auction house (Conjurer's Cinch of Healing)", "world", nil),
        item(252522, "Leatherworking (150) (Skycaller's Leather Belt)", "crafted", nil),
        item(284382, "Unknown source (not yet found in beta) (Budding Leaf Belt)", "world", nil),
    },
    legs = {
        item(252519, "Leatherworking (125) (Wisdom's Leather Leggings)", "crafted", nil),
        item(253987, "Tailoring (125) (Pristine Leggings)", "crafted", nil),
        item(15358, "World drop, sold at the auction house (Headhunter's Woolies of Healing)", "world", nil),
        item(252503, "Leatherworking (Wisdom's Leather Pants)", "crafted", nil),
    },
    feet = {
        item(10359, "Quest: Power Stones (Everlast Boots)", "quest", nil),
        item(254001, "Tailoring (140) (Gilded Slippers)", "crafted", nil),
        item(14214, "World drop, sold at the auction house (Vital Boots of Healing)", "world", nil),
        item(6998, "Quest: Twilight Falls (Alliance only) (Nimbus Boots)", "quest", nil, "Alliance"),
    },
    ring1 = {
        item(274746, "Sold by Gezzy Gunkgear in Booty Bay (Sea Giant's Toe Ring)", "reputation", nil),
        item(9447, "Electrocutioner 6000, Gnomeregan (Electrocutioner Lagnut)", "dungeon", nil),
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
    },
    ring2 = {
        item(9447, "Electrocutioner 6000, Gnomeregan (Electrocutioner Lagnut)", "dungeon", nil),
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(271670, "Quest: Horrors in the Highland (Alliance only) (Curl of Life)", "quest", nil, "Alliance"),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    trinket2 = {
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    mainhand = {
        item(280605, "Shaman quest The Tempest's Weapons, from level 30 (Tidebringer's Claw)", "quest", nil),
        item(9457, "Dark Iron Ambassador, Gnomeregan (Royal Diplomatic Scepter)", "dungeon", nil),
        item(2816, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Scepter)", "dungeon", nil),
        item(17039, "Quest: An Unholy Alliance (Horde only) (Skullbreaker)", "quest", nil, "Horde"),
    },
    offhand = {
        item(6694, "Charlga Razorflank, Razorfen Kraul (Heart of Agamaggan)", "dungeon", nil),
        item(17508, "Quest: Compendium of the Fallen (Horde only) (Forcestone Buckler)", "quest", nil, "Horde"),
        item(274290, "Interrogator Vishas, Scarlet Monastery Graveyard (Painwalker Buckler)", "dungeon", nil),
        item(273811, "Hamhock, The Stockade (Alliance only) (Repurposed Rack)", "dungeon", nil, "Alliance"),
    },
    ranged = {
        item(249398, "Enchanting (130) (Polished Driftwood Icon)", "crafted", nil),
        item(263412, "Quest: Meddlesome Mages (Horde only) (Totem of Charged Flames)", "quest", nil, "Horde"),
    },
} }
-- Elemental: foreverchanges.pro/bis/shaman: Elemental PvE list; weapons: two-hander per site paperdoll; ranged slot holds the relic (libram/totem/idol) list; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["SHAMAN"]["Elemental"] = { lvl30 = {
    head = {
        item(7413, "World drop, sold at the auction house (Infiltrator Cap of Nature's Wrath)", "world", nil),
        item(270067, "Wanted! Marez Cowl, Refuge Pointe, Arathi Highlands (Alliance only) (Wild Headdress)", "quest", nil, "Alliance"),
        item(252456, "Gelihast, Blackfathom Deeps (Totemic Leather Helm)", "dungeon", nil),
        item(2721, "World drop, sold at the auction house (Holy Shroud)", "world", nil),
    },
    neck = {
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of the Sorcerer)", "world", nil),
        item(285331, "Humar the Pridelord, the rare black lion of the Barrens (Mark of the Pack Leader)", "world", nil),
        item(5003, "World drop, sold at the auction house (Crystal Starfire Medallion)", "world", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
    },
    shoulder = {
        item(15140, "World drop, sold at the auction house (Cutthroat's Mantle of Nature's Wrath)", "world", nil),
        item(7684, "Bloodmage Thalnos, Scarlet Monastery Graveyard (Bloodmage Mantle)", "dungeon", nil),
        item(4197, "Quest: A Vengeful Fate (Berylline Pads)", "quest", nil),
        item(6685, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Mantle)", "dungeon", nil),
    },
    back = {
        item(7436, "World drop, sold at the auction house (Twilight Cape of Nature's Wrath)", "world", nil),
        item(277206, "Strahnbrad Mystery, a quest of Alterac Mountains (Brilliant Cloak)", "quest", nil),
        item(284383, "Unknown source (not yet found in beta) (Faerie Dragon's Skin)", "world", nil),
        item(274149, "Roogug, Razorfen Kraul (Thornweaver Drape)", "dungeon", nil),
    },
    chest = {
        item(7407, "World drop, sold at the auction house (Infiltrator Armor of Nature's Wrath)", "world", nil),
        item(17043, "Quest: An Unholy Alliance (Horde only) (Zealot's Robe)", "quest", nil, "Horde"),
        item(277213, "Dro'zem the Blasphemous, a rare elite of the Redridge Mountains (Dro'zem's Tunic)", "world", nil),
        item(7065, "Tailoring (130) (Green Silk Armor)", "crafted", nil),
    },
    wrist = {
        item(9428, "Trash mobs, Uldaman (Unearthed Bands of Nature's Wrath)", "dungeon", nil),
        item(9448, "Electrocutioner 6000, Gnomeregan (Spidertank Oilrag)", "dungeon", nil),
        item(271740, "Quest: Open the Maw (Horde only) (Knife-Polishing Rag)", "quest", nil, "Horde"),
        item(1974, "Trash mobs, Shadowfang Keep (Mindthrust Bracers)", "dungeon", nil),
    },
    hands = {
        item(4980, "Quest: Agmond's Fate (Alliance only) (Prospector Gloves)", "quest", nil, "Alliance"),
        item(15355, "World drop, sold at the auction house (Headhunter's Mitts of Nature's Wrath)", "world", nil),
        item(16741, "Quest: The Lost Pages (Horde only) (Oilrag Handwraps)", "quest", nil, "Horde"),
        item(10654, "Quest: Horde Presence (Jutebraid Gloves)", "quest", nil, "Horde"),
        item(9698, "Quest: Return to Vahlarriel (Alliance only) (Gloves of Insight)", "quest", nil, "Alliance"),
    },
    waist = {
        item(252522, "Leatherworking (150) (Skycaller's Leather Belt)", "crafted", nil),
        item(15148, "World drop, sold at the auction house (Ghostwalker Belt of Nature's Wrath)", "world", nil),
        item(6911, "Aku'mai, Blackfathom Deeps (Moss Cinch)", "dungeon", nil),
        item(16975, "Quest: Warsong Supplies (Horde only) (Warsong Sash)", "quest", nil, "Horde"),
    },
    legs = {
        item(15358, "World drop, sold at the auction house (Headhunter's Woolies of Nature's Wrath)", "world", nil),
        item(270031, "Quest: Blackfathom Villainy (Dark Ritual Leggings)", "quest", nil),
        item(285338, "Brontus, a rare kodo of the Barrens (Kodohide Legguards)", "world", nil),
        item(252502, "Leatherworking (Stormrider's Leather Pants)", "crafted", nil),
    },
    feet = {
        item(15350, "World drop, sold at the auction house (Headhunter's Slippers of Nature's Wrath)", "world", nil),
        item(4320, "Tailoring (Spidersilk Boots)", "crafted", nil),
        item(254001, "Tailoring (140) (Gilded Slippers)", "crafted", nil),
        item(252443, "Leatherworking (85) (Stormrider's Leather Boots)", "crafted", nil),
    },
    ring1 = {
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(2043, "Quest: The Legend of Stalvan (Alliance only) (Ring of Forlorn Spirits)", "quest", nil, "Alliance"),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(274746, "Sold by Gezzy Gunkgear in Booty Bay (Sea Giant's Toe Ring)", "reputation", nil),
    },
    ring2 = {
        item(2043, "Quest: The Legend of Stalvan (Alliance only) (Ring of Forlorn Spirits)", "quest", nil, "Alliance"),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(274746, "Sold by Gezzy Gunkgear in Booty Bay (Sea Giant's Toe Ring)", "reputation", nil),
        item(1449, "Quest: WANTED: Chok'sul (Alliance only) (Minor Channeling Ring)", "quest", nil, "Alliance"),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    mainhand = {
        item(271803, "Khan Jehn, a Magram quest in Desolace (Greatstaff of the Necrokhans)", "quest", nil),
        item(281312, "Alliance quest Stopping the Cycle, Wetlands, level 34 (Fallen Dragon's Scepter)", "quest", nil, "Alliance"),
        item(249392, "Enchanting (140) (Glimmering Staff)", "crafted", nil),
        item(274158, "Aggem Thorncurse, Razorfen Kraul (Death Prophet Spine)", "dungeon", nil),
    },
    ranged = {
        item(249398, "Enchanting (130) (Polished Driftwood Icon)", "crafted", nil),
        item(263412, "Quest: Meddlesome Mages (Horde only) (Totem of Charged Flames)", "quest", nil, "Horde"),
    },
} }
-- Enhancement: foreverchanges.pro/bis/shaman/enhancement: Enhancement PvE list; weapons: two-hander per site paperdoll; ranged slot holds the relic (libram/totem/idol) list; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["SHAMAN"]["Enhancement"] = { lvl30 = {
    head = {
        item(252455, "Twilight Lord Kelris, Blackfathom Deeps (Defender's Leather Helm)", "dungeon", nil),
        item(7413, "World drop, sold at the auction house (Infiltrator Cap of the Gorilla)", "world", nil),
        item(277042, "Leatherworking (175) (Cloudy Gustwoven Hood)", "crafted", nil),
        item(277050, "Leatherworking (175) (Azure Gustwoven Hood)", "crafted", nil),
    },
    neck = {
        item(7731, "Azshir the Sleepless, Scarlet Monastery Graveyard (Ghostshard Talisman)", "dungeon", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(285331, "Humar the Pridelord, the rare black lion of the Barrens (Mark of the Pack Leader)", "world", nil),
        item(274068, "Crowd Pummeler 9-60, Gnomeregan (Thermaplugg Medal of Honor)", "dungeon", nil),
    },
    shoulder = {
        item(15140, "World drop, sold at the auction house (Cutthroat's Mantle of the Gorilla)", "world", nil),
        item(2278, "World drop, sold at the auction house (Forest Tracker Epaulets)", "world", nil),
        item(284399, "Sister Riven, the rare harpy of the Charred Vale (Seared Grove Shoulderpads)", "world", nil),
        item(5964, "Leatherworking (Barbaric Shoulders)", "crafted", nil),
    },
    back = {
        item(271716, "Quest: Lost Relic Carry (Alliance only) (Explorer's League Dustcover)", "quest", nil, "Alliance"),
        item(271720, "A quest of the Excavation Site, in the Wetlands (Crocolisk Skin Gaiter)", "quest", nil),
        item(7436, "World drop, sold at the auction house (Twilight Cape of Strength)", "world", nil),
        item(282658, "Unknown source (not yet found in beta) (Dragonmaw Battle Shroud)", "world", nil),
    },
    chest = {
        item(270054, "A Horde quest from Varimathras in Undercity (Cultist's Chestguard)", "quest", nil, "Horde"),
        item(7407, "World drop, sold at the auction house (Infiltrator Armor of Strength)", "world", nil),
        item(252451, "Leatherworking (110) (Totemic Leather Tunic)", "crafted", nil),
        item(270043, "Quest: Baron Aquanis (Horde only) (Dreamer's Chestguard)", "quest", nil, "Horde"),
        item(5782, "Leatherworking (145) (Thick Murloc Armor)", "crafted", nil),
    },
    wrist = {
        item(9428, "Trash mobs, Uldaman (Unearthed Bands of Power)", "dungeon", nil),
        item(270080, "Wanted! Otto and Falconcrest, Refuge Pointe, Arathi Highlands (Alliance only) (Arathi Armbands)", "quest", nil, "Alliance"),
        item(270042, "Quest: A Fine Mess (Technician's Bracers)", "quest", nil),
        item(13106, "World drop, sold at the auction house (Glowing Magical Bracelets)", "world", nil),
    },
    hands = {
        item(6744, "Quest: Alliance Relations (Horde only) (Gloves of Kapelan)", "quest", nil, "Horde"),
        item(4107, "Quest: Tiger Mastery (Tiger Hunter Gloves)", "quest", nil),
        item(15355, "World drop, sold at the auction house (Headhunter's Mitts of the Gorilla)", "world", nil),
        item(3754, "Quest: Costly Menace (Alliance only) (Shepherd's Gloves)", "quest", nil, "Alliance"),
    },
    waist = {
        item(252459, "Leatherworking (150) (Prowler's Leather Belt)", "crafted", nil),
        item(252461, "Leatherworking (150) (Skirmisher's Leather Belt)", "crafted", nil),
        item(252520, "Leatherworking (150) (Skulker's Leather Belt)", "crafted", nil),
        item(252460, "Leatherworking (150) (Warden's Leather Belt)", "crafted", nil),
    },
    legs = {
        item(6690, "Agathelos the Raging, Razorfen Kraul (Ferine Leggings)", "dungeon", nil),
        item(270074, "Quest: Solution to Doom (Doomcaller's Pants)", "quest", nil),
        item(252458, "Leatherworking (125) (Totemic Leather Leggings)", "crafted", nil),
        item(281295, "Alliance quest Packaged Pristine Pelts, level 31 (Pelt Pants)", "quest", nil, "Alliance"),
    },
    feet = {
        item(284403, "A rare of northern Stonetalon Mountains, near the night elves (Horde only) (Shapeshifting Sentinel's Strides)", "world", nil, "Horde"),
        item(15350, "World drop, sold at the auction house (Headhunter's Slippers of the Gorilla)", "world", nil),
        item(252439, "Leatherworking (85) (Brawler's Leather Boots)", "crafted", nil),
        item(1121, "World drop, sold at the auction house (Feet of the Lynx)", "world", nil),
    },
    ring1 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(18585, "Quest: Service to the Horde (Band of Allegiance)", "quest", nil, "Horde"),
        item(13097, "World drop, sold at the auction house (Thunderbrow Ring)", "world", nil),
        item(270052, "Quest: Jarl Needs a Blade (Swamp Ring)", "quest", nil),
    },
    ring2 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(18585, "Quest: Service to the Horde (Band of Allegiance)", "quest", nil, "Horde"),
        item(13097, "World drop, sold at the auction house (Thunderbrow Ring)", "world", nil),
        item(270052, "Quest: Jarl Needs a Blade (Swamp Ring)", "quest", nil),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    mainhand = {
        item(271801, "Khan Jehn, a Gelkis quest in Desolace (Abandoned Ferocity)", "quest", nil),
        item(280604, "Shaman quest The Tempest's Weapons, from level 30 (Rage of the Storm)", "quest", nil),
        item(13045, "World drop, sold at the auction house (Viscous Hammer)", "world", nil),
        item(9449, "Crowd Pummeler 9-60, Gnomeregan (Manual Crowd Pummeler)", "dungeon", nil),
    },
    ranged = {
        item(249398, "Enchanting (130) (Polished Driftwood Icon)", "crafted", nil),
        item(263412, "Quest: Meddlesome Mages (Horde only) (Totem of Charged Flames)", "quest", nil, "Horde"),
    },
} }

-- ============================================================
-- MAGE
-- ============================================================
DB["MAGE"] = {}
-- Arcane: foreverchanges.pro/bis/mage/arcane: Arcane PvE list; weapons: two-hander per site paperdoll; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["MAGE"]["Arcane"] = { lvl30 = {
    head = {
        item(14200, "World drop, sold at the auction house (Thistlefur Cap of Arcane Wrath)", "world", nil),
        item(253983, "Tailoring (125) (Filigreed Pearly Circlet)", "crafted", nil),
        item(253957, "Tailoring (100) (Pearly Circlet)", "crafted", nil),
        item(2721, "World drop, sold at the auction house (Holy Shroud)", "world", nil),
    },
    neck = {
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of the Sorcerer)", "world", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(5003, "World drop, sold at the auction house (Crystal Starfire Medallion)", "world", nil),
        item(285331, "Humar the Pridelord, the rare black lion of the Barrens (Mark of the Pack Leader)", "world", nil),
    },
    shoulder = {
        item(7684, "Bloodmage Thalnos, Scarlet Monastery Graveyard (Bloodmage Mantle)", "dungeon", nil),
        item(4197, "Quest: A Vengeful Fate (Berylline Pads)", "quest", nil),
        item(14201, "World drop, sold at the auction house (Thistlefur Mantle of Arcane Wrath)", "world", nil),
        item(6685, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Mantle)", "dungeon", nil),
    },
    back = {
        item(7436, "World drop, sold at the auction house (Twilight Cape of Arcane Wrath)", "world", nil),
        item(277206, "Strahnbrad Mystery, a quest of Alterac Mountains (Brilliant Cloak)", "quest", nil),
        item(274149, "Roogug, Razorfen Kraul (Thornweaver Drape)", "dungeon", nil),
        item(15468, "Quest: Free at Last (Horde only) (Windsong Drape)", "quest", nil, "Horde"),
    },
    chest = {
        item(17043, "Quest: An Unholy Alliance (Horde only) (Zealot's Robe)", "quest", nil, "Horde"),
        item(7353, "World drop, sold at the auction house (Elder's Padded Armor of Arcane Wrath)", "world", nil),
        item(253969, "Tailoring (110) (Pearly Gown)", "crafted", nil),
        item(284697, "Unknown source (not yet found in beta) (Arcane Charged Robes)", "world", nil),
    },
    wrist = {
        item(9448, "Electrocutioner 6000, Gnomeregan (Spidertank Oilrag)", "dungeon", nil),
        item(9846, "World drop, sold at the auction house (Conjurer's Bracers of Arcane Wrath)", "world", nil),
        item(4744, "Quest: Wanted!  Marez Cowl (Alliance only) (Arcane Runed Bracers)", "quest", nil, "Alliance"),
        item(271740, "Quest: Open the Maw (Horde only) (Knife-Polishing Rag)", "quest", nil, "Horde"),
    },
    hands = {
        item(14211, "World drop, sold at the auction house (Vital Handwraps of Arcane Wrath)", "world", nil),
        item(270029, "Quest: Crime and Punishment (Alliance only) (Town Clerk's Mittens)", "quest", nil, "Alliance"),
        item(253921, "Tailoring (75) (Pearly Gloves)", "crafted", nil),
        item(10654, "Quest: Horde Presence (Jutebraid Gloves)", "quest", nil, "Horde"),
    },
    waist = {
        item(9853, "World drop, sold at the auction house (Conjurer's Cinch of Arcane Wrath)", "world", nil),
        item(16975, "Quest: Warsong Supplies (Horde only) (Warsong Sash)", "quest", nil, "Horde"),
        item(6392, "Archmage Arugal, Shadowfang Keep (Belt of Arugal)", "dungeon", nil),
        item(253933, "Tailoring (85) (Pearly Sash)", "crafted", nil),
    },
    legs = {
        item(14203, "World drop, sold at the auction house (Thistlefur Pants of Arcane Wrath)", "world", nil),
        item(253945, "Tailoring (100) (Filigreed Pearly Leggings)", "crafted", nil),
        item(253995, "Tailoring (125) (Pearly Leggings)", "crafted", nil),
        item(6903, "Twilight Lord Kelris, Blackfathom Deeps (Gaze Dreamer Pants)", "dungeon", nil),
    },
    feet = {
        item(14214, "World drop, sold at the auction house (Vital Boots of Arcane Wrath)", "world", nil),
        item(4320, "Tailoring (Spidersilk Boots)", "crafted", nil),
        item(254009, "Tailoring (140) (Golden Slippers)", "crafted", nil),
        item(9454, "Viscous Fallout, Gnomeregan (Acidic Walkers)", "dungeon", nil),
    },
    ring1 = {
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(1449, "Quest: WANTED: Chok'sul (Alliance only) (Minor Channeling Ring)", "quest", nil, "Alliance"),
        item(271670, "Quest: Horrors in the Highland (Alliance only) (Curl of Life)", "quest", nil, "Alliance"),
    },
    ring2 = {
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(1449, "Quest: WANTED: Chok'sul (Alliance only) (Minor Channeling Ring)", "quest", nil, "Alliance"),
        item(271670, "Quest: Horrors in the Highland (Alliance only) (Curl of Life)", "quest", nil, "Alliance"),
        item(282283, "Nightveiled Rotheap, a patrol of the Wetlands (Alliance only) (Malignant Root)", "world", nil, "Alliance"),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    mainhand = {
        item(271803, "Khan Jehn, a Magram quest in Desolace (Greatstaff of the Necrokhans)", "quest", nil),
        item(281312, "Alliance quest Stopping the Cycle, Wetlands, level 34 (Fallen Dragon's Scepter)", "quest", nil, "Alliance"),
        item(249392, "Enchanting (140) (Glimmering Staff)", "crafted", nil),
        item(274158, "Aggem Thorncurse, Razorfen Kraul (Death Prophet Spine)", "dungeon", nil),
    },
    ranged = {
        item(11263, "Quest: Mage's Wand (Nether Force Wand)", "quest", nil),
        item(6806, "Quest: Final Passage (Horde only) (Dancing Flame)", "quest", nil, "Horde"),
        item(13063, "World drop, sold at the auction house (Starfaller)", "world", nil),
        item(13062, "World drop, sold at the auction house (Thunderwood)", "world", nil),
    },
} }
-- Fire: foreverchanges.pro/bis/mage/fire: Fire PvE list; weapons: two-hander per site paperdoll; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["MAGE"]["Fire"] = { lvl30 = {
    head = {
        item(14200, "World drop, sold at the auction house (Thistlefur Cap of Fiery Wrath)", "world", nil),
        item(253979, "Tailoring (125) (Filigreed Flame Circlet)", "crafted", nil),
        item(253953, "Tailoring (100) (Flame Circlet)", "crafted", nil),
        item(2721, "World drop, sold at the auction house (Holy Shroud)", "world", nil),
    },
    neck = {
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of the Sorcerer)", "world", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(5003, "World drop, sold at the auction house (Crystal Starfire Medallion)", "world", nil),
        item(285331, "Humar the Pridelord, the rare black lion of the Barrens (Mark of the Pack Leader)", "world", nil),
    },
    shoulder = {
        item(14201, "World drop, sold at the auction house (Thistlefur Mantle of Fiery Wrath)", "world", nil),
        item(7684, "Bloodmage Thalnos, Scarlet Monastery Graveyard (Bloodmage Mantle)", "dungeon", nil),
        item(4197, "Quest: A Vengeful Fate (Berylline Pads)", "quest", nil),
        item(6685, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Mantle)", "dungeon", nil),
    },
    back = {
        item(7436, "World drop, sold at the auction house (Twilight Cape of Fiery Wrath)", "world", nil),
        item(277206, "Strahnbrad Mystery, a quest of Alterac Mountains (Brilliant Cloak)", "quest", nil),
        item(274149, "Roogug, Razorfen Kraul (Thornweaver Drape)", "dungeon", nil),
        item(15468, "Quest: Free at Last (Horde only) (Windsong Drape)", "quest", nil, "Horde"),
    },
    chest = {
        item(17043, "Quest: An Unholy Alliance (Horde only) (Zealot's Robe)", "quest", nil, "Horde"),
        item(7353, "World drop, sold at the auction house (Elder's Padded Armor of Fiery Wrath)", "world", nil),
        item(253965, "Tailoring (110) (Flame Gown)", "crafted", nil),
        item(277213, "Dro'zem the Blasphemous, a rare elite of the Redridge Mountains (Dro'zem's Tunic)", "world", nil),
    },
    wrist = {
        item(9448, "Electrocutioner 6000, Gnomeregan (Spidertank Oilrag)", "dungeon", nil),
        item(9846, "World drop, sold at the auction house (Conjurer's Bracers of Fiery Wrath)", "world", nil),
        item(4744, "Quest: Wanted!  Marez Cowl (Alliance only) (Arcane Runed Bracers)", "quest", nil, "Alliance"),
        item(271740, "Quest: Open the Maw (Horde only) (Knife-Polishing Rag)", "quest", nil, "Horde"),
    },
    hands = {
        item(14211, "World drop, sold at the auction house (Vital Handwraps of Fiery Wrath)", "world", nil),
        item(4331, "Tailoring (100) (Phoenix Gloves)", "crafted", nil),
        item(253917, "Tailoring (75) (Flame Gloves)", "crafted", nil),
        item(270029, "Quest: Crime and Punishment (Alliance only) (Town Clerk's Mittens)", "quest", nil, "Alliance"),
    },
    waist = {
        item(9853, "World drop, sold at the auction house (Conjurer's Cinch of Fiery Wrath)", "world", nil),
        item(16975, "Quest: Warsong Supplies (Horde only) (Warsong Sash)", "quest", nil, "Horde"),
        item(6392, "Archmage Arugal, Shadowfang Keep (Belt of Arugal)", "dungeon", nil),
        item(253929, "Tailoring (85) (Flame Sash)", "crafted", nil),
    },
    legs = {
        item(14203, "World drop, sold at the auction house (Thistlefur Pants of Fiery Wrath)", "world", nil),
        item(253941, "Tailoring (100) (Filigreed Flame Leggings)", "crafted", nil),
        item(253991, "Tailoring (125) (Flame Leggings)", "crafted", nil),
        item(6903, "Twilight Lord Kelris, Blackfathom Deeps (Gaze Dreamer Pants)", "dungeon", nil),
    },
    feet = {
        item(14214, "World drop, sold at the auction house (Vital Boots of Fiery Wrath)", "world", nil),
        item(4320, "Tailoring (Spidersilk Boots)", "crafted", nil),
        item(254005, "Tailoring (140) (Fiery Slippers)", "crafted", nil),
        item(9454, "Viscous Fallout, Gnomeregan (Acidic Walkers)", "dungeon", nil),
    },
    ring1 = {
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(2043, "Quest: The Legend of Stalvan (Alliance only) (Ring of Forlorn Spirits)", "quest", nil, "Alliance"),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(1449, "Quest: WANTED: Chok'sul (Alliance only) (Minor Channeling Ring)", "quest", nil, "Alliance"),
    },
    ring2 = {
        item(2043, "Quest: The Legend of Stalvan (Alliance only) (Ring of Forlorn Spirits)", "quest", nil, "Alliance"),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(1449, "Quest: WANTED: Chok'sul (Alliance only) (Minor Channeling Ring)", "quest", nil, "Alliance"),
        item(271670, "Quest: Horrors in the Highland (Alliance only) (Curl of Life)", "quest", nil, "Alliance"),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    mainhand = {
        item(271803, "Khan Jehn, a Magram quest in Desolace (Greatstaff of the Necrokhans)", "quest", nil),
        item(281312, "Alliance quest Stopping the Cycle, Wetlands, level 34 (Fallen Dragon's Scepter)", "quest", nil, "Alliance"),
        item(249392, "Enchanting (140) (Glimmering Staff)", "crafted", nil),
        item(274158, "Aggem Thorncurse, Razorfen Kraul (Death Prophet Spine)", "dungeon", nil),
    },
    ranged = {
        item(7513, "Quest: Mage's Wand (Ragefire Wand)", "quest", nil),
        item(6806, "Quest: Final Passage (Horde only) (Dancing Flame)", "quest", nil, "Horde"),
        item(5213, "World drop, sold at the auction house (Scorching Wand)", "world", nil),
        item(13062, "World drop, sold at the auction house (Thunderwood)", "world", nil),
    },
} }
-- Frost: foreverchanges.pro/bis/mage: Frost PvE list; weapons: two-hander per site paperdoll; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["MAGE"]["Frost"] = { lvl30 = {
    head = {
        item(14200, "World drop, sold at the auction house (Thistlefur Cap of Frozen Wrath)", "world", nil),
        item(253977, "Tailoring (125) (Filigreed Silky Circlet)", "crafted", nil),
        item(253951, "Tailoring (100) (Silky Circlet)", "crafted", nil),
        item(7048, "Tailoring (Azure Silk Hood)", "crafted", nil),
    },
    neck = {
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of the Sorcerer)", "world", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(5003, "World drop, sold at the auction house (Crystal Starfire Medallion)", "world", nil),
        item(285331, "Humar the Pridelord, the rare black lion of the Barrens (Mark of the Pack Leader)", "world", nil),
    },
    shoulder = {
        item(14201, "World drop, sold at the auction house (Thistlefur Mantle of Frozen Wrath)", "world", nil),
        item(7684, "Bloodmage Thalnos, Scarlet Monastery Graveyard (Bloodmage Mantle)", "dungeon", nil),
        item(4197, "Quest: A Vengeful Fate (Berylline Pads)", "quest", nil),
        item(6685, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Mantle)", "dungeon", nil),
    },
    back = {
        item(7053, "Tailoring (140) (Azure Silk Cloak)", "crafted", nil),
        item(7436, "World drop, sold at the auction house (Twilight Cape of Frozen Wrath)", "world", nil),
        item(277206, "Strahnbrad Mystery, a quest of Alterac Mountains (Brilliant Cloak)", "quest", nil),
        item(274149, "Roogug, Razorfen Kraul (Thornweaver Drape)", "dungeon", nil),
    },
    chest = {
        item(17043, "Quest: An Unholy Alliance (Horde only) (Zealot's Robe)", "quest", nil, "Horde"),
        item(7353, "World drop, sold at the auction house (Elder's Padded Armor of Frozen Wrath)", "world", nil),
        item(253963, "Tailoring (110) (Silky Gown)", "crafted", nil),
        item(277213, "Dro'zem the Blasphemous, a rare elite of the Redridge Mountains (Dro'zem's Tunic)", "world", nil),
    },
    wrist = {
        item(9448, "Electrocutioner 6000, Gnomeregan (Spidertank Oilrag)", "dungeon", nil),
        item(9846, "World drop, sold at the auction house (Conjurer's Bracers of Frozen Wrath)", "world", nil),
        item(4744, "Quest: Wanted!  Marez Cowl (Alliance only) (Arcane Runed Bracers)", "quest", nil, "Alliance"),
        item(271740, "Quest: Open the Maw (Horde only) (Knife-Polishing Rag)", "quest", nil, "Horde"),
    },
    hands = {
        item(14211, "World drop, sold at the auction house (Vital Handwraps of Frozen Wrath)", "world", nil),
        item(4319, "Tailoring (120) (Azure Silk Gloves)", "crafted", nil),
        item(253915, "Tailoring (75) (Silky Gloves)", "crafted", nil),
        item(10654, "Quest: Horde Presence (Jutebraid Gloves)", "quest", nil, "Horde"),
    },
    waist = {
        item(9853, "World drop, sold at the auction house (Conjurer's Cinch of Frozen Wrath)", "world", nil),
        item(16975, "Quest: Warsong Supplies (Horde only) (Warsong Sash)", "quest", nil, "Horde"),
        item(6392, "Archmage Arugal, Shadowfang Keep (Belt of Arugal)", "dungeon", nil),
        item(253927, "Tailoring (85) (Silky Sash)", "crafted", nil),
    },
    legs = {
        item(14203, "World drop, sold at the auction house (Thistlefur Pants of Frozen Wrath)", "world", nil),
        item(253939, "Tailoring (100) (Filigreed Silky Leggings)", "crafted", nil),
        item(253989, "Tailoring (125) (Silky Leggings)", "crafted", nil),
        item(6903, "Twilight Lord Kelris, Blackfathom Deeps (Gaze Dreamer Pants)", "dungeon", nil),
    },
    feet = {
        item(14214, "World drop, sold at the auction house (Vital Boots of Frozen Wrath)", "world", nil),
        item(4320, "Tailoring (Spidersilk Boots)", "crafted", nil),
        item(254003, "Tailoring (140) (Frothing Slippers)", "crafted", nil),
        item(9454, "Viscous Fallout, Gnomeregan (Acidic Walkers)", "dungeon", nil),
    },
    ring1 = {
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(2043, "Quest: The Legend of Stalvan (Alliance only) (Ring of Forlorn Spirits)", "quest", nil, "Alliance"),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(1449, "Quest: WANTED: Chok'sul (Alliance only) (Minor Channeling Ring)", "quest", nil, "Alliance"),
    },
    ring2 = {
        item(2043, "Quest: The Legend of Stalvan (Alliance only) (Ring of Forlorn Spirits)", "quest", nil, "Alliance"),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(1449, "Quest: WANTED: Chok'sul (Alliance only) (Minor Channeling Ring)", "quest", nil, "Alliance"),
        item(271670, "Quest: Horrors in the Highland (Alliance only) (Curl of Life)", "quest", nil, "Alliance"),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    mainhand = {
        item(271803, "Khan Jehn, a Magram quest in Desolace (Greatstaff of the Necrokhans)", "quest", nil),
        item(281312, "Alliance quest Stopping the Cycle, Wetlands, level 34 (Fallen Dragon's Scepter)", "quest", nil, "Alliance"),
        item(249392, "Enchanting (140) (Glimmering Staff)", "crafted", nil),
        item(274158, "Aggem Thorncurse, Razorfen Kraul (Death Prophet Spine)", "dungeon", nil),
    },
    ranged = {
        item(7514, "Quest: Mage's Wand (Icefury Wand)", "quest", nil),
        item(6806, "Quest: Final Passage (Horde only) (Dancing Flame)", "quest", nil, "Horde"),
        item(7708, "Azshir the Sleepless, Scarlet Monastery Graveyard (Necrotic Wand)", "dungeon", nil),
        item(13062, "World drop, sold at the auction house (Thunderwood)", "world", nil),
    },
} }

-- ============================================================
-- WARLOCK
-- ============================================================
DB["WARLOCK"] = {}
-- Destruction: foreverchanges.pro/bis/warlock: single Warlock PvE list for the class; weapons: 1H+held per site paperdoll; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["WARLOCK"]["Destruction"] = { lvl30 = {
    head = {
        item(14200, "World drop, sold at the auction house (Thistlefur Cap of Shadow Wrath)", "world", nil),
        item(253981, "Tailoring (125) (Filigreed Shadow Circlet)", "crafted", nil),
        item(253955, "Tailoring (100) (Shadow Circlet)", "crafted", nil),
        item(4323, "Tailoring (135) (Shadow Hood)", "crafted", nil),
    },
    neck = {
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of the Sorcerer)", "world", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(5003, "World drop, sold at the auction house (Crystal Starfire Medallion)", "world", nil),
        item(285331, "Humar the Pridelord, the rare black lion of the Barrens (Mark of the Pack Leader)", "world", nil),
    },
    shoulder = {
        item(14201, "World drop, sold at the auction house (Thistlefur Mantle of Shadow Wrath)", "world", nil),
        item(7684, "Bloodmage Thalnos, Scarlet Monastery Graveyard (Bloodmage Mantle)", "dungeon", nil),
        item(4197, "Quest: A Vengeful Fate (Berylline Pads)", "quest", nil),
        item(6685, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Mantle)", "dungeon", nil),
    },
    back = {
        item(7436, "World drop, sold at the auction house (Twilight Cape of Shadow Wrath)", "world", nil),
        item(277206, "Strahnbrad Mystery, a quest of Alterac Mountains (Brilliant Cloak)", "quest", nil),
        item(274149, "Roogug, Razorfen Kraul (Thornweaver Drape)", "dungeon", nil),
        item(3719, "Leatherworking (Hillman's Cloak)", "crafted", nil),
    },
    chest = {
        item(17043, "Quest: An Unholy Alliance (Horde only) (Zealot's Robe)", "quest", nil, "Horde"),
        item(7353, "World drop, sold at the auction house (Elder's Padded Armor of Shadow Wrath)", "world", nil),
        item(253967, "Tailoring (110) (Shadow Gown)", "crafted", nil),
        item(2292, "Trash mobs, Shadowfang Keep (Necrology Robes)", "dungeon", nil),
    },
    wrist = {
        item(9448, "Electrocutioner 6000, Gnomeregan (Spidertank Oilrag)", "dungeon", nil),
        item(9846, "World drop, sold at the auction house (Conjurer's Bracers of Shadow Wrath)", "world", nil),
        item(4744, "Quest: Wanted!  Marez Cowl (Alliance only) (Arcane Runed Bracers)", "quest", nil, "Alliance"),
        item(271740, "Quest: Open the Maw (Horde only) (Knife-Polishing Rag)", "quest", nil, "Horde"),
    },
    hands = {
        item(14211, "World drop, sold at the auction house (Vital Handwraps of Shadow Wrath)", "world", nil),
        item(7047, "Tailoring (120) (Hands of Darkness)", "crafted", nil),
        item(253919, "Tailoring (75) (Shadow Gloves)", "crafted", nil),
        item(9609, "Quest: Gyrodrillmatic Excavationators (Alliance only) (Shilly Mitts)", "quest", nil, "Alliance"),
    },
    waist = {
        item(9853, "World drop, sold at the auction house (Conjurer's Cinch of Shadow Wrath)", "world", nil),
        item(16975, "Quest: Warsong Supplies (Horde only) (Warsong Sash)", "quest", nil, "Horde"),
        item(6392, "Archmage Arugal, Shadowfang Keep (Belt of Arugal)", "dungeon", nil),
        item(253931, "Tailoring (85) (Shadow Sash)", "crafted", nil),
    },
    legs = {
        item(7709, "Azshir the Sleepless, Scarlet Monastery Graveyard (Blighted Leggings)", "dungeon", nil),
        item(14203, "World drop, sold at the auction house (Thistlefur Pants of Shadow Wrath)", "world", nil),
        item(253993, "Tailoring (125) (Shadow Leggings)", "crafted", nil),
        item(2277, "World drop, sold at the auction house (Necromancer Leggings)", "world", nil),
    },
    feet = {
        item(14214, "World drop, sold at the auction house (Vital Boots of Shadow Wrath)", "world", nil),
        item(4320, "Tailoring (Spidersilk Boots)", "crafted", nil),
        item(254007, "Tailoring (140) (Black Slippers)", "crafted", nil),
        item(9454, "Viscous Fallout, Gnomeregan (Acidic Walkers)", "dungeon", nil),
    },
    ring1 = {
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(2043, "Quest: The Legend of Stalvan (Alliance only) (Ring of Forlorn Spirits)", "quest", nil, "Alliance"),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(1449, "Quest: WANTED: Chok'sul (Alliance only) (Minor Channeling Ring)", "quest", nil, "Alliance"),
    },
    ring2 = {
        item(2043, "Quest: The Legend of Stalvan (Alliance only) (Ring of Forlorn Spirits)", "quest", nil, "Alliance"),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(1449, "Quest: WANTED: Chok'sul (Alliance only) (Minor Channeling Ring)", "quest", nil, "Alliance"),
        item(271670, "Quest: Horrors in the Highland (Alliance only) (Curl of Life)", "quest", nil, "Alliance"),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    mainhand = {
        item(6691, "Agathelos the Raging, Razorfen Kraul (Swinetusk Shank)", "dungeon", nil),
        item(270069, "Call to Arms, a Horde chain at Hammerfall, Arathi Highlands (Mindslicer)", "quest", nil, "Horde"),
        item(273827, "Bazil Thredd, The Stockade (Alliance only) (Debt Collector)", "dungeon", nil, "Alliance"),
        item(2567, "Trash mobs, Blackfathom Deeps (Evocator's Blade)", "dungeon", nil),
    },
    offhand = {
        item(6898, "Quest: The Orb of Soran'ruk", "quest", nil),
        item(7609, "World drop, sold at the auction house (Elder's Amber Stave of Shadow Wrath)", "world", nil),
        item(249394, "Enchanting (140) (Orb of Mystic Insight)", "crafted", nil),
        item(2565, "World drop, sold at the auction house (Rod of Molten Fire)", "world", nil),
    },
    ranged = {
        item(7708, "Azshir the Sleepless, Scarlet Monastery Graveyard (Necrotic Wand)", "dungeon", nil),
        item(6806, "Quest: Final Passage (Horde only) (Dancing Flame)", "quest", nil, "Horde"),
        item(13062, "World drop, sold at the auction house (Thunderwood)", "world", nil),
        item(13063, "World drop, sold at the auction house (Starfaller)", "world", nil),
    },
} }
-- Affliction: foreverchanges.pro/bis/warlock: single Warlock PvE list for the class (reused); weapons: 1H+held per site paperdoll; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["WARLOCK"]["Affliction"] = { lvl30 = {
    head = {
        item(14200, "World drop, sold at the auction house (Thistlefur Cap of Shadow Wrath)", "world", nil),
        item(253981, "Tailoring (125) (Filigreed Shadow Circlet)", "crafted", nil),
        item(253955, "Tailoring (100) (Shadow Circlet)", "crafted", nil),
        item(4323, "Tailoring (135) (Shadow Hood)", "crafted", nil),
    },
    neck = {
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of the Sorcerer)", "world", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(5003, "World drop, sold at the auction house (Crystal Starfire Medallion)", "world", nil),
        item(285331, "Humar the Pridelord, the rare black lion of the Barrens (Mark of the Pack Leader)", "world", nil),
    },
    shoulder = {
        item(14201, "World drop, sold at the auction house (Thistlefur Mantle of Shadow Wrath)", "world", nil),
        item(7684, "Bloodmage Thalnos, Scarlet Monastery Graveyard (Bloodmage Mantle)", "dungeon", nil),
        item(4197, "Quest: A Vengeful Fate (Berylline Pads)", "quest", nil),
        item(6685, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Mantle)", "dungeon", nil),
    },
    back = {
        item(7436, "World drop, sold at the auction house (Twilight Cape of Shadow Wrath)", "world", nil),
        item(277206, "Strahnbrad Mystery, a quest of Alterac Mountains (Brilliant Cloak)", "quest", nil),
        item(274149, "Roogug, Razorfen Kraul (Thornweaver Drape)", "dungeon", nil),
        item(3719, "Leatherworking (Hillman's Cloak)", "crafted", nil),
    },
    chest = {
        item(17043, "Quest: An Unholy Alliance (Horde only) (Zealot's Robe)", "quest", nil, "Horde"),
        item(7353, "World drop, sold at the auction house (Elder's Padded Armor of Shadow Wrath)", "world", nil),
        item(253967, "Tailoring (110) (Shadow Gown)", "crafted", nil),
        item(2292, "Trash mobs, Shadowfang Keep (Necrology Robes)", "dungeon", nil),
    },
    wrist = {
        item(9448, "Electrocutioner 6000, Gnomeregan (Spidertank Oilrag)", "dungeon", nil),
        item(9846, "World drop, sold at the auction house (Conjurer's Bracers of Shadow Wrath)", "world", nil),
        item(4744, "Quest: Wanted!  Marez Cowl (Alliance only) (Arcane Runed Bracers)", "quest", nil, "Alliance"),
        item(271740, "Quest: Open the Maw (Horde only) (Knife-Polishing Rag)", "quest", nil, "Horde"),
    },
    hands = {
        item(14211, "World drop, sold at the auction house (Vital Handwraps of Shadow Wrath)", "world", nil),
        item(7047, "Tailoring (120) (Hands of Darkness)", "crafted", nil),
        item(253919, "Tailoring (75) (Shadow Gloves)", "crafted", nil),
        item(9609, "Quest: Gyrodrillmatic Excavationators (Alliance only) (Shilly Mitts)", "quest", nil, "Alliance"),
    },
    waist = {
        item(9853, "World drop, sold at the auction house (Conjurer's Cinch of Shadow Wrath)", "world", nil),
        item(16975, "Quest: Warsong Supplies (Horde only) (Warsong Sash)", "quest", nil, "Horde"),
        item(6392, "Archmage Arugal, Shadowfang Keep (Belt of Arugal)", "dungeon", nil),
        item(253931, "Tailoring (85) (Shadow Sash)", "crafted", nil),
    },
    legs = {
        item(7709, "Azshir the Sleepless, Scarlet Monastery Graveyard (Blighted Leggings)", "dungeon", nil),
        item(14203, "World drop, sold at the auction house (Thistlefur Pants of Shadow Wrath)", "world", nil),
        item(253993, "Tailoring (125) (Shadow Leggings)", "crafted", nil),
        item(2277, "World drop, sold at the auction house (Necromancer Leggings)", "world", nil),
    },
    feet = {
        item(14214, "World drop, sold at the auction house (Vital Boots of Shadow Wrath)", "world", nil),
        item(4320, "Tailoring (Spidersilk Boots)", "crafted", nil),
        item(254007, "Tailoring (140) (Black Slippers)", "crafted", nil),
        item(9454, "Viscous Fallout, Gnomeregan (Acidic Walkers)", "dungeon", nil),
    },
    ring1 = {
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(2043, "Quest: The Legend of Stalvan (Alliance only) (Ring of Forlorn Spirits)", "quest", nil, "Alliance"),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(1449, "Quest: WANTED: Chok'sul (Alliance only) (Minor Channeling Ring)", "quest", nil, "Alliance"),
    },
    ring2 = {
        item(2043, "Quest: The Legend of Stalvan (Alliance only) (Ring of Forlorn Spirits)", "quest", nil, "Alliance"),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(1449, "Quest: WANTED: Chok'sul (Alliance only) (Minor Channeling Ring)", "quest", nil, "Alliance"),
        item(271670, "Quest: Horrors in the Highland (Alliance only) (Curl of Life)", "quest", nil, "Alliance"),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    mainhand = {
        item(6691, "Agathelos the Raging, Razorfen Kraul (Swinetusk Shank)", "dungeon", nil),
        item(270069, "Call to Arms, a Horde chain at Hammerfall, Arathi Highlands (Mindslicer)", "quest", nil, "Horde"),
        item(273827, "Bazil Thredd, The Stockade (Alliance only) (Debt Collector)", "dungeon", nil, "Alliance"),
        item(2567, "Trash mobs, Blackfathom Deeps (Evocator's Blade)", "dungeon", nil),
    },
    offhand = {
        item(6898, "Quest: The Orb of Soran'ruk", "quest", nil),
        item(7609, "World drop, sold at the auction house (Elder's Amber Stave of Shadow Wrath)", "world", nil),
        item(249394, "Enchanting (140) (Orb of Mystic Insight)", "crafted", nil),
        item(2565, "World drop, sold at the auction house (Rod of Molten Fire)", "world", nil),
    },
    ranged = {
        item(7708, "Azshir the Sleepless, Scarlet Monastery Graveyard (Necrotic Wand)", "dungeon", nil),
        item(6806, "Quest: Final Passage (Horde only) (Dancing Flame)", "quest", nil, "Horde"),
        item(13062, "World drop, sold at the auction house (Thunderwood)", "world", nil),
        item(13063, "World drop, sold at the auction house (Starfaller)", "world", nil),
    },
} }
-- Demonology: foreverchanges.pro/bis/warlock: single Warlock PvE list for the class (reused); weapons: 1H+held per site paperdoll; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["WARLOCK"]["Demonology"] = { lvl30 = {
    head = {
        item(14200, "World drop, sold at the auction house (Thistlefur Cap of Shadow Wrath)", "world", nil),
        item(253981, "Tailoring (125) (Filigreed Shadow Circlet)", "crafted", nil),
        item(253955, "Tailoring (100) (Shadow Circlet)", "crafted", nil),
        item(4323, "Tailoring (135) (Shadow Hood)", "crafted", nil),
    },
    neck = {
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of the Sorcerer)", "world", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(5003, "World drop, sold at the auction house (Crystal Starfire Medallion)", "world", nil),
        item(285331, "Humar the Pridelord, the rare black lion of the Barrens (Mark of the Pack Leader)", "world", nil),
    },
    shoulder = {
        item(14201, "World drop, sold at the auction house (Thistlefur Mantle of Shadow Wrath)", "world", nil),
        item(7684, "Bloodmage Thalnos, Scarlet Monastery Graveyard (Bloodmage Mantle)", "dungeon", nil),
        item(4197, "Quest: A Vengeful Fate (Berylline Pads)", "quest", nil),
        item(6685, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Mantle)", "dungeon", nil),
    },
    back = {
        item(7436, "World drop, sold at the auction house (Twilight Cape of Shadow Wrath)", "world", nil),
        item(277206, "Strahnbrad Mystery, a quest of Alterac Mountains (Brilliant Cloak)", "quest", nil),
        item(274149, "Roogug, Razorfen Kraul (Thornweaver Drape)", "dungeon", nil),
        item(3719, "Leatherworking (Hillman's Cloak)", "crafted", nil),
    },
    chest = {
        item(17043, "Quest: An Unholy Alliance (Horde only) (Zealot's Robe)", "quest", nil, "Horde"),
        item(7353, "World drop, sold at the auction house (Elder's Padded Armor of Shadow Wrath)", "world", nil),
        item(253967, "Tailoring (110) (Shadow Gown)", "crafted", nil),
        item(2292, "Trash mobs, Shadowfang Keep (Necrology Robes)", "dungeon", nil),
    },
    wrist = {
        item(9448, "Electrocutioner 6000, Gnomeregan (Spidertank Oilrag)", "dungeon", nil),
        item(9846, "World drop, sold at the auction house (Conjurer's Bracers of Shadow Wrath)", "world", nil),
        item(4744, "Quest: Wanted!  Marez Cowl (Alliance only) (Arcane Runed Bracers)", "quest", nil, "Alliance"),
        item(271740, "Quest: Open the Maw (Horde only) (Knife-Polishing Rag)", "quest", nil, "Horde"),
    },
    hands = {
        item(14211, "World drop, sold at the auction house (Vital Handwraps of Shadow Wrath)", "world", nil),
        item(7047, "Tailoring (120) (Hands of Darkness)", "crafted", nil),
        item(253919, "Tailoring (75) (Shadow Gloves)", "crafted", nil),
        item(9609, "Quest: Gyrodrillmatic Excavationators (Alliance only) (Shilly Mitts)", "quest", nil, "Alliance"),
    },
    waist = {
        item(9853, "World drop, sold at the auction house (Conjurer's Cinch of Shadow Wrath)", "world", nil),
        item(16975, "Quest: Warsong Supplies (Horde only) (Warsong Sash)", "quest", nil, "Horde"),
        item(6392, "Archmage Arugal, Shadowfang Keep (Belt of Arugal)", "dungeon", nil),
        item(253931, "Tailoring (85) (Shadow Sash)", "crafted", nil),
    },
    legs = {
        item(7709, "Azshir the Sleepless, Scarlet Monastery Graveyard (Blighted Leggings)", "dungeon", nil),
        item(14203, "World drop, sold at the auction house (Thistlefur Pants of Shadow Wrath)", "world", nil),
        item(253993, "Tailoring (125) (Shadow Leggings)", "crafted", nil),
        item(2277, "World drop, sold at the auction house (Necromancer Leggings)", "world", nil),
    },
    feet = {
        item(14214, "World drop, sold at the auction house (Vital Boots of Shadow Wrath)", "world", nil),
        item(4320, "Tailoring (Spidersilk Boots)", "crafted", nil),
        item(254007, "Tailoring (140) (Black Slippers)", "crafted", nil),
        item(9454, "Viscous Fallout, Gnomeregan (Acidic Walkers)", "dungeon", nil),
    },
    ring1 = {
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(2043, "Quest: The Legend of Stalvan (Alliance only) (Ring of Forlorn Spirits)", "quest", nil, "Alliance"),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(1449, "Quest: WANTED: Chok'sul (Alliance only) (Minor Channeling Ring)", "quest", nil, "Alliance"),
    },
    ring2 = {
        item(2043, "Quest: The Legend of Stalvan (Alliance only) (Ring of Forlorn Spirits)", "quest", nil, "Alliance"),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(1449, "Quest: WANTED: Chok'sul (Alliance only) (Minor Channeling Ring)", "quest", nil, "Alliance"),
        item(271670, "Quest: Horrors in the Highland (Alliance only) (Curl of Life)", "quest", nil, "Alliance"),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    mainhand = {
        item(6691, "Agathelos the Raging, Razorfen Kraul (Swinetusk Shank)", "dungeon", nil),
        item(270069, "Call to Arms, a Horde chain at Hammerfall, Arathi Highlands (Mindslicer)", "quest", nil, "Horde"),
        item(273827, "Bazil Thredd, The Stockade (Alliance only) (Debt Collector)", "dungeon", nil, "Alliance"),
        item(2567, "Trash mobs, Blackfathom Deeps (Evocator's Blade)", "dungeon", nil),
    },
    offhand = {
        item(6898, "Quest: The Orb of Soran'ruk", "quest", nil),
        item(7609, "World drop, sold at the auction house (Elder's Amber Stave of Shadow Wrath)", "world", nil),
        item(249394, "Enchanting (140) (Orb of Mystic Insight)", "crafted", nil),
        item(2565, "World drop, sold at the auction house (Rod of Molten Fire)", "world", nil),
    },
    ranged = {
        item(7708, "Azshir the Sleepless, Scarlet Monastery Graveyard (Necrotic Wand)", "dungeon", nil),
        item(6806, "Quest: Final Passage (Horde only) (Dancing Flame)", "quest", nil, "Horde"),
        item(13062, "World drop, sold at the auction house (Thunderwood)", "world", nil),
        item(13063, "World drop, sold at the auction house (Starfaller)", "world", nil),
    },
} }

-- ============================================================
-- DRUID
-- ============================================================
DB["DRUID"] = {}
-- Balance: foreverchanges.pro/bis/druid/balance: Balance PvE list; weapons: two-hander per site paperdoll; ranged slot holds the relic (libram/totem/idol) list; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["DRUID"]["Balance"] = { lvl30 = {
    head = {
        item(14200, "World drop, sold at the auction house (Thistlefur Cap of Arcane Wrath)", "world", nil),
        item(270067, "Wanted! Marez Cowl, Refuge Pointe, Arathi Highlands (Alliance only) (Wild Headdress)", "quest", nil, "Alliance"),
        item(253983, "Tailoring (125) (Filigreed Pearly Circlet)", "crafted", nil),
        item(253957, "Tailoring (100) (Pearly Circlet)", "crafted", nil),
    },
    neck = {
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of the Sorcerer)", "world", nil),
        item(285331, "Humar the Pridelord, the rare black lion of the Barrens (Mark of the Pack Leader)", "world", nil),
        item(5003, "World drop, sold at the auction house (Crystal Starfire Medallion)", "world", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
    },
    shoulder = {
        item(15140, "World drop, sold at the auction house (Cutthroat's Mantle of Arcane Wrath)", "world", nil),
        item(7684, "Bloodmage Thalnos, Scarlet Monastery Graveyard (Bloodmage Mantle)", "dungeon", nil),
        item(4197, "Quest: A Vengeful Fate (Berylline Pads)", "quest", nil),
        item(6685, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Mantle)", "dungeon", nil),
    },
    back = {
        item(7436, "World drop, sold at the auction house (Twilight Cape of Arcane Wrath)", "world", nil),
        item(277206, "Strahnbrad Mystery, a quest of Alterac Mountains (Brilliant Cloak)", "quest", nil),
        item(274149, "Roogug, Razorfen Kraul (Thornweaver Drape)", "dungeon", nil),
        item(3719, "Leatherworking (Hillman's Cloak)", "crafted", nil),
    },
    chest = {
        item(7407, "World drop, sold at the auction house (Infiltrator Armor of Arcane Wrath)", "world", nil),
        item(17043, "Quest: An Unholy Alliance (Horde only) (Zealot's Robe)", "quest", nil, "Horde"),
        item(253969, "Tailoring (110) (Pearly Gown)", "crafted", nil),
        item(284697, "Unknown source (not yet found in beta) (Arcane Charged Robes)", "world", nil),
    },
    wrist = {
        item(9428, "Trash mobs, Uldaman (Unearthed Bands of Arcane Wrath)", "dungeon", nil),
        item(9448, "Electrocutioner 6000, Gnomeregan (Spidertank Oilrag)", "dungeon", nil),
        item(271740, "Quest: Open the Maw (Horde only) (Knife-Polishing Rag)", "quest", nil, "Horde"),
        item(1974, "Trash mobs, Shadowfang Keep (Mindthrust Bracers)", "dungeon", nil),
    },
    hands = {
        item(4980, "Quest: Agmond's Fate (Alliance only) (Prospector Gloves)", "quest", nil, "Alliance"),
        item(14211, "World drop, sold at the auction house (Vital Handwraps of Arcane Wrath)", "world", nil),
        item(16741, "Quest: The Lost Pages (Horde only) (Oilrag Handwraps)", "quest", nil, "Horde"),
        item(253921, "Tailoring (75) (Pearly Gloves)", "crafted", nil),
    },
    waist = {
        item(252522, "Leatherworking (150) (Skycaller's Leather Belt)", "crafted", nil),
        item(9853, "World drop, sold at the auction house (Conjurer's Cinch of Arcane Wrath)", "world", nil),
        item(6911, "Aku'mai, Blackfathom Deeps (Moss Cinch)", "dungeon", nil),
        item(16975, "Quest: Warsong Supplies (Horde only) (Warsong Sash)", "quest", nil, "Horde"),
    },
    legs = {
        item(15358, "World drop, sold at the auction house (Headhunter's Woolies of Arcane Wrath)", "world", nil),
        item(270031, "Quest: Blackfathom Villainy (Dark Ritual Leggings)", "quest", nil),
        item(253995, "Tailoring (125) (Pearly Leggings)", "crafted", nil),
        item(285338, "Brontus, a rare kodo of the Barrens (Kodohide Legguards)", "world", nil),
    },
    feet = {
        item(14214, "World drop, sold at the auction house (Vital Boots of Arcane Wrath)", "world", nil),
        item(4320, "Tailoring (Spidersilk Boots)", "crafted", nil),
        item(254009, "Tailoring (140) (Golden Slippers)", "crafted", nil),
        item(254001, "Tailoring (140) (Gilded Slippers)", "crafted", nil),
    },
    ring1 = {
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(2043, "Quest: The Legend of Stalvan (Alliance only) (Ring of Forlorn Spirits)", "quest", nil, "Alliance"),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(274746, "Sold by Gezzy Gunkgear in Booty Bay (Sea Giant's Toe Ring)", "reputation", nil),
    },
    ring2 = {
        item(2043, "Quest: The Legend of Stalvan (Alliance only) (Ring of Forlorn Spirits)", "quest", nil, "Alliance"),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(9622, "Quest: Jarl Needs a Blade (Reedknot Ring)", "quest", nil),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(274746, "Sold by Gezzy Gunkgear in Booty Bay (Sea Giant's Toe Ring)", "reputation", nil),
        item(1449, "Quest: WANTED: Chok'sul (Alliance only) (Minor Channeling Ring)", "quest", nil, "Alliance"),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    mainhand = {
        item(271803, "Khan Jehn, a Magram quest in Desolace (Greatstaff of the Necrokhans)", "quest", nil),
        item(281312, "Alliance quest Stopping the Cycle, Wetlands, level 34 (Fallen Dragon's Scepter)", "quest", nil, "Alliance"),
        item(249392, "Enchanting (140) (Glimmering Staff)", "crafted", nil),
        item(274158, "Aggem Thorncurse, Razorfen Kraul (Death Prophet Spine)", "dungeon", nil),
    },
    ranged = {
        item(249396, "Enchanting (130) (Mystic Mushroom)", "crafted", nil),
        item(263411, "Druid quest Aquatic Form, level 16, both factions (Idol of Shifting Tides)", "quest", nil),
    },
} }
-- Restoration: foreverchanges.pro/bis/druid/restoration: Restoration list; weapons: 1H+held per site paperdoll; ranged slot holds the relic (libram/totem/idol) list; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["DRUID"]["Restoration"] = { lvl30 = {
    head = {
        item(2721, "World drop, sold at the auction house (Holy Shroud)", "world", nil),
        item(7691, "Fallen Champion, Scarlet Monastery Graveyard (Embalmed Shroud)", "dungeon", nil),
        item(14200, "World drop, sold at the auction house (Thistlefur Cap of Healing)", "world", nil),
        item(284401, "Sorrow Wing, the rare of Stonetalon Mountains (Sorrow's Shroud)", "world", nil),
    },
    neck = {
        item(12029, "World drop, sold at the auction house (Greenstone Talisman of the Physician)", "world", nil),
        item(7746, "Quest: Mythology of the Titans (Alliance only) (Explorers' League Commendation)", "quest", nil, "Alliance"),
        item(281321, "Alliance quest Gleaning Our Future, Wetlands, level 32 (Giantstone Medallion)", "quest", nil, "Alliance"),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(5003, "World drop, sold at the auction house (Crystal Starfire Medallion)", "world", nil),
    },
    shoulder = {
        item(15357, "World drop, sold at the auction house (Headhunter's Spaulders of Healing)", "world", nil),
        item(3324, "Quest: Deathstalkers in Shadowfang (Horde only) (Ghostly Mantle)", "quest", nil, "Horde"),
        item(7684, "Bloodmage Thalnos, Scarlet Monastery Graveyard (Bloodmage Mantle)", "dungeon", nil),
        item(4197, "Quest: A Vengeful Fate (Berylline Pads)", "quest", nil),
    },
    back = {
        item(7436, "World drop, sold at the auction house (Twilight Cape of Healing)", "world", nil),
        item(9605, "Quest: Data Rescue (Alliance only) (Repairman's Cape)", "quest", nil, "Alliance"),
        item(7004, "Quest: Researching the Corruption (Alliance only) (Prelacy Cape)", "quest", nil, "Alliance"),
        item(273825, "Bazil Thredd, The Stockade (Alliance only) (Red Wool Cloak)", "dungeon", nil, "Alliance"),
        item(6901, "Old Serra'kis, Blackfathom Deeps (Glowing Thresher Cape)", "dungeon", nil),
        item(274149, "Roogug, Razorfen Kraul (Thornweaver Drape)", "dungeon", nil),
    },
    chest = {
        item(9623, "Quest: Rig Wars (Civinad Robes)", "quest", nil),
        item(4746, "Quest: Solution to Doom (Doomsayer's Robe)", "quest", nil),
        item(7407, "World drop, sold at the auction house (Infiltrator Armor of Healing)", "world", nil),
        item(253961, "Tailoring (110) (Pristine Gown)", "crafted", nil),
    },
    wrist = {
        item(9428, "Trash mobs, Uldaman (Unearthed Bands of Healing)", "dungeon", nil),
        item(9448, "Electrocutioner 6000, Gnomeregan (Spidertank Oilrag)", "dungeon", nil),
        item(271740, "Quest: Open the Maw (Horde only) (Knife-Polishing Rag)", "quest", nil, "Horde"),
        item(4744, "Quest: Wanted!  Marez Cowl (Alliance only) (Arcane Runed Bracers)", "quest", nil, "Alliance"),
    },
    hands = {
        item(270059, "Agmond's Fate, from Prospector Ironband in Loch Modan (Alliance only) (Restorer's Fine Gloves)", "quest", nil, "Alliance"),
        item(14211, "World drop, sold at the auction house (Vital Handwraps of Healing)", "world", nil),
        item(7049, "Tailoring (125) (Truefaith Gloves)", "crafted", nil),
        item(888, "Lady Sarevess, Blackfathom Deeps (Naga Battle Gloves)", "dungeon", nil),
    },
    waist = {
        item(252523, "Leatherworking (150) (Mender's Leather Belt)", "crafted", nil),
        item(9853, "World drop, sold at the auction house (Conjurer's Cinch of Healing)", "world", nil),
        item(252522, "Leatherworking (150) (Skycaller's Leather Belt)", "crafted", nil),
        item(284382, "Unknown source (not yet found in beta) (Budding Leaf Belt)", "world", nil),
    },
    legs = {
        item(252519, "Leatherworking (125) (Wisdom's Leather Leggings)", "crafted", nil),
        item(253987, "Tailoring (125) (Pristine Leggings)", "crafted", nil),
        item(15358, "World drop, sold at the auction house (Headhunter's Woolies of Healing)", "world", nil),
        item(252503, "Leatherworking (Wisdom's Leather Pants)", "crafted", nil),
    },
    feet = {
        item(10359, "Quest: Power Stones (Everlast Boots)", "quest", nil),
        item(254001, "Tailoring (140) (Gilded Slippers)", "crafted", nil),
        item(14214, "World drop, sold at the auction house (Vital Boots of Healing)", "world", nil),
        item(6998, "Quest: Twilight Falls (Alliance only) (Nimbus Boots)", "quest", nil, "Alliance"),
    },
    ring1 = {
        item(274746, "Sold by Gezzy Gunkgear in Booty Bay (Sea Giant's Toe Ring)", "reputation", nil),
        item(9447, "Electrocutioner 6000, Gnomeregan (Electrocutioner Lagnut)", "dungeon", nil),
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
    },
    ring2 = {
        item(9447, "Electrocutioner 6000, Gnomeregan (Electrocutioner Lagnut)", "dungeon", nil),
        item(281635, "Quest: Greater Friend of the Library (Philanthropist's Ring)", "quest", nil),
        item(270051, "Quest A Daughter's Love, Duskwood (Alliance only) (Ladimore Heirloom Ring)", "quest", nil, "Alliance"),
        item(273806, "Targorr the Dread, The Stockade (Alliance only) (Dark Horde Band)", "dungeon", nil, "Alliance"),
        item(1449, "Quest: WANTED: Chok'sul (Alliance only) (Minor Channeling Ring)", "quest", nil, "Alliance"),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    trinket2 = {
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(273643, "Commander Springvale, Shadowfang Keep (Worgenbane Talisman)", "dungeon", nil),
    },
    mainhand = {
        item(9457, "Dark Iron Ambassador, Gnomeregan (Royal Diplomatic Scepter)", "dungeon", nil),
        item(2816, "Death Speaker Jargba, Razorfen Kraul (Death Speaker Scepter)", "dungeon", nil),
        item(17039, "Quest: An Unholy Alliance (Horde only) (Skullbreaker)", "quest", nil, "Horde"),
        item(6691, "Agathelos the Raging, Razorfen Kraul (Swinetusk Shank)", "dungeon", nil),
    },
    offhand = {
        item(7609, "World drop, sold at the auction house (Elder's Amber Stave of Healing)", "world", nil),
        item(249395, "Enchanting (140) (Orb of Souls)", "crafted", nil),
        item(2943, "Quest: Cleansing the Eye (Alliance only) (Eye of Paleth)", "quest", nil, "Alliance"),
        item(7749, "Quest: Compendium of the Fallen (Horde only) (Omega Orb)", "quest", nil, "Horde"),
    },
    ranged = {
        item(249396, "Enchanting (130) (Mystic Mushroom)", "crafted", nil),
        item(263411, "Druid quest Aquatic Form, level 16, both factions (Idol of Shifting Tides)", "quest", nil),
    },
} }
-- Feral - Tank: foreverchanges.pro/bis/druid/tank: Feral Tank list; weapons: two-hander per site paperdoll; ranged slot holds the relic (libram/totem/idol) list; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["DRUID"]["Feral - Tank"] = { lvl30 = {
    head = {
        item(252512, "Gelihast, Blackfathom Deeps (Brawler's Leather Helm)", "dungeon", nil),
        item(252504, "Leatherworking (100) (Brawler's Leather Hood)", "crafted", nil),
        item(19972, "Quest: Rare Fish - Keefer's Angelfish (Lucky Fishing Hat)", "quest", nil),
        item(252447, "Leatherworking (100) (Defender's Leather Hood)", "crafted", nil),
    },
    neck = {
        item(274749, "Sold by Gezzy Gunkgear in Booty Bay (Souvenir Sea Shell)", "reputation", nil),
        item(7731, "Azshir the Sleepless, Scarlet Monastery Graveyard (Ghostshard Talisman)", "dungeon", nil),
        item(13087, "World drop, sold at the auction house (River Pride Choker)", "world", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
    },
    shoulder = {
        item(7727, "Trash mobs, Scarlet Monastery Graveyard (Watchman Pauldrons)", "dungeon", nil),
        item(277043, "Leatherworking (175) (Cloudy Gustwoven Spaulders)", "crafted", nil),
        item(277051, "Leatherworking (175) (Azure Gustwoven Spaulders)", "crafted", nil),
        item(5964, "Leatherworking (Barbaric Shoulders)", "crafted", nil),
    },
    back = {
        item(6751, "Quest: Mortality Wanes (Alliance only) (Mourning Shawl)", "quest", nil, "Alliance"),
        item(13108, "World drop, sold at the auction house (Tigerstrike Mantle)", "world", nil),
        item(4643, "Quest: Vorrel's Revenge (Horde only) (Grimsteel Cape)", "quest", nil, "Horde"),
        item(271720, "A quest of the Excavation Site, in the Wetlands (Crocolisk Skin Gaiter)", "quest", nil),
    },
    chest = {
        item(4119, "Quest: Raptor Mastery (Raptor Hunter Tunic)", "quest", nil),
        item(252450, "Leatherworking (110) (Defender's Leather Tunic)", "crafted", nil),
        item(273805, "Targorr the Dread, The Stockade (Alliance only) (Blackrock Harness)", "dungeon", nil, "Alliance"),
        item(4455, "Leatherworking (140) (Raptor Hide Harness)", "crafted", nil),
    },
    wrist = {
        item(18948, "Leatherworking (130) (Barbaric Bracers)", "crafted", nil),
        item(9428, "Trash mobs, Uldaman (Unearthed Bands of the Monkey)", "dungeon", nil),
        item(3230, "Fenrus the Devourer, Shadowfang Keep (Black Wolf Bracers)", "dungeon", nil),
        item(270032, "Quest: Blackfathom Villainy (Cultist's Armguards)", "quest", nil),
    },
    hands = {
        item(6727, "Quest: Safety First (Razzeric's Racing Grips)", "quest", nil),
        item(7690, "Fallen Champion, Scarlet Monastery Graveyard (Ebon Vise)", "dungeon", nil),
        item(6784, "Quest: Centaur Bounty (Horde only) (Braced Handguards)", "quest", nil, "Horde"),
        item(1978, "Trash mobs, Razorfen Kraul (Wolfclaw Gloves)", "dungeon", nil),
    },
    waist = {
        item(252460, "Leatherworking (150) (Warden's Leather Belt)", "crafted", nil),
        item(252520, "Leatherworking (150) (Skulker's Leather Belt)", "crafted", nil),
        item(252459, "Leatherworking (150) (Prowler's Leather Belt)", "crafted", nil),
        item(252521, "Leatherworking (150) (Stalker's Leather Belt)", "crafted", nil),
    },
    legs = {
        item(252457, "Leatherworking (125) (Defender's Leather Kilt)", "crafted", nil),
        item(9624, "Quest: Rig Wars (Triprunner Dungarees)", "quest", nil),
        item(252516, "Leatherworking (125) (Brawler's Leather Legguards)", "crafted", nil),
        item(9509, "Trash mobs, Gnomeregan (Petrolspill Leggings)", "dungeon", nil),
    },
    feet = {
        item(9450, "Crowd Pummeler 9-60, Gnomeregan (Gnomebot Operating Boots)", "dungeon", nil),
        item(6335, "Quest: The Book of Ur (Horde only) (Grizzled Boots)", "quest", nil, "Horde"),
        item(16977, "Quest: Warsong Supplies (Horde only) (Warsong Boots)", "quest", nil, "Horde"),
        item(19969, "Quest: Rare Fish - Brownell's Blue Striped Racer (Nat Pagle's Extreme Anglin' Boots)", "quest", nil),
        item(10411, "Lord Serpentis, Wailing Caverns (Footpads of the Fang)", "dungeon", nil),
    },
    ring1 = {
        item(276899, "Quest: Past Due (Alliance only) (Knucklebound Thimble)", "quest", nil, "Alliance"),
        item(281634, "Quest: Greater Friend of the Library (Field Researcher's Loop)", "quest", nil),
        item(281320, "Alliance quest Gleaning Our Future, Wetlands, level 32 (Rune-Etched Ring)", "quest", nil, "Alliance"),
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(6414, "Quest: Arugal Must Die (Horde only) (Seal of Sylvanas)", "quest", nil, "Horde"),
    },
    ring2 = {
        item(281634, "Quest: Greater Friend of the Library (Field Researcher's Loop)", "quest", nil),
        item(281320, "Alliance quest Gleaning Our Future, Wetlands, level 32 (Rune-Etched Ring)", "quest", nil, "Alliance"),
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(6414, "Quest: Arugal Must Die (Horde only) (Seal of Sylvanas)", "quest", nil, "Horde"),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
        item(273298, "Cookie, The Deadmines (Lookie's Spyglass)", "dungeon", nil),
    },
    trinket2 = {
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(273298, "Cookie, The Deadmines (Lookie's Spyglass)", "dungeon", nil),
    },
    mainhand = {
        item(271800, "Khan Jehn, a Magram quest in Desolace (Scavenged Magram Armament)", "quest", nil),
        item(13045, "World drop, sold at the auction house (Viscous Hammer)", "world", nil),
        item(271667, "Quest: Horrors in the Highland (Alliance only) (Ironwood Destroyer)", "quest", nil, "Alliance"),
        item(271766, "Quest: Lost Relic Carry (Heavehammer)", "quest", nil),
    },
    ranged = {
        item(263435, "Urs'endris, the bear spirit of Zephras Isle (Mark of Urs'endris)", "world", nil),
        item(263411, "Druid quest Aquatic Form, level 16, both factions (Idol of Shifting Tides)", "quest", nil),
        item(249396, "Enchanting (130) (Mystic Mushroom)", "crafted", nil),
    },
} }
-- Feral - DPS: foreverchanges.pro/bis/druid: Feral PvE (cat) list; weapons: two-hander per site paperdoll; ranged slot holds the relic (libram/totem/idol) list; BiS order = site ranking (Alliance paperdoll pick for rings/trinkets/weapons)
DB["DRUID"]["Feral - DPS"] = { lvl30 = {
    head = {
        item(7413, "World drop, sold at the auction house (Infiltrator Cap of the Tiger)", "world", nil),
        item(252512, "Gelihast, Blackfathom Deeps (Brawler's Leather Helm)", "dungeon", nil),
        item(6720, "Quest: Frostmaw (Horde only) (Spirit Hunter Headdress)", "quest", nil, "Horde"),
        item(252504, "Leatherworking (100) (Brawler's Leather Hood)", "crafted", nil),
    },
    neck = {
        item(12019, "World drop, sold at the auction house (Cerulean Talisman of the Tiger)", "world", nil),
        item(13084, "World drop, sold at the auction house (Kaleidoscope Chain)", "world", nil),
        item(7731, "Azshir the Sleepless, Scarlet Monastery Graveyard (Ghostshard Talisman)", "dungeon", nil),
        item(274068, "Crowd Pummeler 9-60, Gnomeregan (Thermaplugg Medal of Honor)", "dungeon", nil),
    },
    shoulder = {
        item(2278, "World drop, sold at the auction house (Forest Tracker Epaulets)", "world", nil),
        item(15140, "World drop, sold at the auction house (Cutthroat's Mantle of the Tiger)", "world", nil),
        item(2264, "Trash mobs, Razorfen Kraul (Mantle of Thieves)", "dungeon", nil),
        item(5964, "Leatherworking (Barbaric Shoulders)", "crafted", nil),
    },
    back = {
        item(14593, "World drop, sold at the auction house (Hawkeye's Cloak)", "world", nil),
        item(13108, "World drop, sold at the auction house (Tigerstrike Mantle)", "world", nil),
        item(271720, "A quest of the Excavation Site, in the Wetlands (Crocolisk Skin Gaiter)", "quest", nil),
        item(2805, "Quest: Bartolo's Yeti Fur Cloak (Alliance only)", "quest", nil, "Alliance"),
    },
    chest = {
        item(9835, "World drop, sold at the auction house (Scaled Leather Tunic of the Tiger)", "world", nil),
        item(7374, "Leatherworking (Dusky Leather Armor)", "crafted", nil),
        item(252508, "Leatherworking (110) (Brawler's Leather Tunic)", "crafted", nil),
        item(252450, "Leatherworking (110) (Defender's Leather Tunic)", "crafted", nil),
    },
    wrist = {
        item(9428, "Trash mobs, Uldaman (Unearthed Bands of the Tiger)", "dungeon", nil),
        item(270080, "Wanted! Otto and Falconcrest, Refuge Pointe, Arathi Highlands (Alliance only) (Arathi Armbands)", "quest", nil, "Alliance"),
        item(14590, "World drop, sold at the auction house (Hawkeye's Bracers)", "world", nil),
        item(18948, "Leatherworking (130) (Barbaric Bracers)", "crafted", nil),
    },
    hands = {
        item(4107, "Quest: Tiger Mastery (Tiger Hunter Gloves)", "quest", nil),
        item(270072, "Crushridge Warmongers, from Marshal Redpath in Southshore (Alliance only) (Alterac Assassin's Gloves)", "quest", nil, "Alliance"),
        item(3754, "Quest: Costly Menace (Alliance only) (Shepherd's Gloves)", "quest", nil, "Alliance"),
        item(6408, "World drop, sold at the auction house (Insignia Gloves)", "world", nil),
        item(4253, "Leatherworking (Toughened Leather Gloves)", "crafted", nil),
    },
    waist = {
        item(252520, "Leatherworking (150) (Skulker's Leather Belt)", "crafted", nil),
        item(252459, "Leatherworking (150) (Prowler's Leather Belt)", "crafted", nil),
        item(252460, "Leatherworking (150) (Warden's Leather Belt)", "crafted", nil),
        item(252521, "Leatherworking (150) (Stalker's Leather Belt)", "crafted", nil),
    },
    legs = {
        item(9624, "Quest: Rig Wars (Triprunner Dungarees)", "quest", nil),
        item(252516, "Leatherworking (125) (Brawler's Leather Legguards)", "crafted", nil),
        item(9509, "Trash mobs, Gnomeregan (Petrolspill Leggings)", "dungeon", nil),
        item(13114, "World drop, sold at the auction house (Troll's Bane Leggings)", "world", nil),
    },
    feet = {
        item(284403, "A rare of northern Stonetalon Mountains, near the night elves (Horde only) (Shapeshifting Sentinel's Strides)", "world", nil, "Horde"),
        item(15350, "World drop, sold at the auction house (Headhunter's Slippers of the Tiger)", "world", nil),
        item(7751, "Quest: Vorrel's Revenge (Horde only) (Vorrel's Boots)", "quest", nil, "Horde"),
        item(1121, "World drop, sold at the auction house (Feet of the Lynx)", "world", nil),
        item(252439, "Leatherworking (85) (Brawler's Leather Boots)", "crafted", nil),
    },
    ring1 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(7686, "Ironspine, Scarlet Monastery Graveyard (Ironspine's Eye)", "dungeon", nil),
        item(13097, "World drop, sold at the auction house (Thunderbrow Ring)", "world", nil),
        item(270053, "Quest: The Legend of Stalvan (Alliance only) (Ring of Ruin)", "quest", nil, "Alliance"),
    },
    ring2 = {
        item(285190, "Heartrazor, the rare wyvern of Thousand Needles (Wyvern Heart Band)", "world", nil),
        item(7686, "Ironspine, Scarlet Monastery Graveyard (Ironspine's Eye)", "dungeon", nil),
        item(13097, "World drop, sold at the auction house (Thunderbrow Ring)", "world", nil),
        item(270053, "Quest: The Legend of Stalvan (Alliance only) (Ring of Ruin)", "quest", nil, "Alliance"),
    },
    trinket1 = {
        item(4381, "Engineering (140) (Minor Recombobulator)", "crafted", nil),
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
    },
    trinket2 = {
        item(3456, "Houndmaster Loksey, Scarlet Monastery Library (Dog Whistle)", "dungeon", nil),
        item(4396, "Engineering (200) (Mechanical Dragonling)", "crafted", nil),
        item(280766, "Quest: Changing Tastes (Horde only) (Satchel of Potions)", "quest", nil, "Horde"),
        item(274152, "Roogug, Razorfen Kraul (Roogug's Severed Head)", "dungeon", nil),
    },
    mainhand = {
        item(271800, "Khan Jehn, a Magram quest in Desolace (Scavenged Magram Armament)", "quest", nil),
        item(13045, "World drop, sold at the auction house (Viscous Hammer)", "world", nil),
        item(9449, "Crowd Pummeler 9-60, Gnomeregan (Manual Crowd Pummeler)", "dungeon", nil),
        item(271766, "Quest: Lost Relic Carry (Heavehammer)", "quest", nil),
    },
    ranged = {
        item(263411, "Druid quest Aquatic Form, level 16, both factions (Idol of Shifting Tides)", "quest", nil),
        item(249396, "Enchanting (130) (Mystic Mushroom)", "crafted", nil),
    },
} }

