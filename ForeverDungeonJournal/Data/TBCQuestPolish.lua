-- Structured quest pages for TBC Anniversary. Supplements the user-provided compendium.
-- Each chain step has its own objective/giver instead of redirecting to the final quest.
-- Pins labelled (area) identify an approximate hub, not an exact character position.
local _, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS
if not FDJ or not FDJ.IS_TBC_ANNIVERSARY then return end
local StepDetails = FDJ.QUEST_PREREQ_DETAILS or {}
FDJ.QUEST_PREREQ_DETAILS = StepDetails
local MainByID = {}
local MapAnchors = {
  ["theldurin the lost"] = {1418, 0.516, 0.768, "Theldurin the Lost - Badlands (verified NPC)"},
  ["rigglefuzz"] = {1418, 0.42, 0.53, "Rigglefuzz - central Badlands"},
  ["raleigh the devout"] = {1424, 0.51, 0.58, "Raleigh the Devout - Southshore inn"},
  ["varimathras"] = {1458, 0.56, 0.92, "Varimathras - Royal Quarter"},
  ["master apothecary faranell"] = {1458, 0.48, 0.69, "Master Apothecary Faranell - Apothecarium"},
  ["brother anton"] = {1443, 0.66, 0.08, "Brother Anton - Nijel's Point"},
  ["prospector stormpike"] = {1455, 0.75, 0.12, "Prospector Stormpike - Hall of Explorers"},
  ["krom stoutarm"] = {1455, 0.74, 0.09, "Krom Stoutarm - Hall of Explorers"},
  ["historian karnik"] = {1455, 0.75, 0.12, "Hall of Explorers - Ironforge (area)"},
  ["advisor belgrum"] = {1455, 0.75, 0.12, "Hall of Explorers - Ironforge (area)"},
  ["king magni bronzebeard"] = {1455, 0.4, 0.55, "King Magni Bronzebeard - Ironforge throne"},
  ["royal historian archesonus"] = {1455, 0.75, 0.12, "Hall of Explorers - Ironforge (area)"},
  ["talvash del kissel"] = {1455, 0.36, 0.04, "Talvash del Kissel - Mystic Ward"},
  ["prospector ironband"] = {1432, 0.66, 0.66, "Prospector Ironband - Ironband Excavation"},
  ["jarkal mossmeld"] = {1418, 0.03, 0.46, "Jarkal Mossmeld - Kargath inn"},
  ["patrick garrett"] = {1458, 0.62, 0.48, "Patrick Garrett - Undercity"},
  ["dran droffers"] = {1454, 0.6, 0.5, "Dran Droffers - The Drag (area)"},
  ["trent on lighthammer"] = {1446, 0.51, 0.28, "Trenton Lighthammer - Gadgetzan"},
  ["trenton lighthammer"] = {1446, 0.51, 0.28, "Trenton Lighthammer - Gadgetzan"},
  ["tran'rek"] = {1446, 0.51, 0.26, "Tran'rek - Gadgetzan"},
  ["chief engineer bilgewhizzle"] = {1446, 0.52, 0.28, "Chief Engineer Bilgewhizzle - Gadgetzan"},
  ["yeh'kinya"] = {1446, 0.67, 0.22, "Yeh'kinya - Steamwheedle Port"},
  ["prospector ironboot"] = {1446, 0.67, 0.22, "Prospector Ironboot - Steamwheedle Port (area)"},
  ["wizzle brassbolts"] = {1441, 0.78, 0.77, "Wizzle Brassbolts - Mirage Raceway"},
  ["tabetha"] = {1445, 0.46, 0.57, "Tabetha - Dustwallow Marsh"},
  ["marvon rivetseeker"] = {1446, 0.52, 0.46, "Marvon Rivetseeker - Broken Pillar"},
  ["at al'ai exile"] = {1425, 0.34, 0.75, "Atal'ai Exile - Shadra'Alor"},
  ["atal'ai exile"] = {1425, 0.34, 0.75, "Atal'ai Exile - Shadra'Alor"},
  ["fel'zerul"] = {1435, 0.47, 0.54, "Fel'zerul - Stonard"},
  ["brohann caskbelly"] = {1453, 0.65, 0.35, "Dwarven District - Stormwind (area)"},
  ["archbishop benedictus"] = {1453, 0.5, 0.45, "Cathedral of Light - Stormwind (area)"},
  ["andrew brownell"] = {1458, 0.8, 0.35, "Magic Quarter - Undercity (area)"},
  ["master gadrin"] = {1411, 0.56, 0.74, "Master Gadrin - Sen'jin Village"},
  ["apothecary lydon"] = {1424, 0.62, 0.2, "Tarren Mill - Hillsbrad (area)"},
  ["gryphon master talonaxe"] = {1425, 0.14, 0.47, "Aerie Peak - Hinterlands (area)"},
  ["falstad wildhammer"] = {1425, 0.14, 0.47, "Aerie Peak - Hinterlands (area)"},
  ["rhapsody shindigger"] = {1425, 0.26, 0.48, "Shindigger's Camp - Hinterlands (area)"},
  ["thadius grimshade"] = {1419, 0.66, 0.19, "Thadius Grimshade - Nethergarde Keep"},
  ["centaur pariah"] = {1443, 0.53, 0.76, "Southern Desolace - Pariah patrol (area)"},
  ["willow"] = {1443, 0.62, 0.39, "Willow - Kormek's Hut"},
  ["talendria"] = {1443, 0.66, 0.08, "Talendria - Nijel's Point"},
  ["keeper marandis"] = {1443, 0.66, 0.08, "Keeper Marandis - Nijel's Point"},
  ["vark battlescar"] = {1443, 0.23, 0.7, "Vark Battlescar - Shadowprey Village"},
  ["selendra"] = {1443, 0.26, 0.77, "Selendra - south of Shadowprey Village"},
  ["rokaro"] = {1443, 0.23, 0.7, "Rokaro - Shadowprey Village (area)"},
  ["archmage tervosh"] = {1445, 0.66, 0.49, "Theramore main tower (area)"},
  ["uthel'nay"] = {1454, 0.39, 0.86, "Uthel'nay - Valley of Spirits"},
  ["torwa pathfinder"] = {1449, 0.71, 0.76, "Torwa Pathfinder - Un'Goro entrance"},
  ["muigin"] = {1449, 0.43, 0.08, "Marshal's Refuge - Un'Goro (area)"},
  ["larion"] = {1449, 0.43, 0.08, "Marshal's Refuge - Un'Goro (area)"},
  ["gregan brewspewer"] = {1444, 0.45, 0.25, "Gregan Brewspewer - Twin Colossals"},
  ["liv rizzlefix"] = {1413, 0.62, 0.38, "Liv Rizzlefix - Ratchet"},
  ["ogtinc"] = {1447, 0.42, 0.43, "Ogtinc - Azshara"},
  ["archmage xylem"] = {1447, 0.29, 0.41, "Archmage Xylem - Azshara (tower area)"},
  ["greta mosshoof"] = {1448, 0.51, 0.82, "Emerald Sanctuary - Felwood (area)"},
  ["impsy"] = {1448, 0.41, 0.45, "Impsy - Bloodvenom Falls"},
  ["bath'rah the windwatcher"] = {1416, 0.8, 0.66, "Bath'rah - Alterac Mountains (area)"},
  ["fallen hero of the horde"] = {1435, 0.34, 0.66, "Fallen Hero - Swamp/Blasted Lands border"},
  ["commander ashlam valorfist"] = {1422, 0.42, 0.84, "Chillwind Camp - Western Plaguelands (area)"},
  ["high priestess macdonnell"] = {1422, 0.42, 0.84, "Chillwind Camp - Western Plaguelands (area)"},
  ["ghak healtouch"] = {1432, 0.35, 0.49, "Ghak Healtouch - Thelsamar (area)"},
  ["ragnar thunderbrew"] = {1426, 0.47, 0.52, "Ragnar Thunderbrew - Kharanos"},
  ["cyrus therepentous"] = {1428, 0.94, 0.31, "Cyrus Therepentous - Slither Rock cave"},
  ["maxwort uberglint"] = {1428, 0.66, 0.22, "Maxwort Uberglint - Flame Crest"},
  ["yuka screwspigot"] = {1428, 0.66, 0.22, "Yuka Screwspigot - Flame Crest"},
  ["kibler"] = {1428, 0.66, 0.22, "Kibler - Flame Crest (area)"},
  ["tinkee steamboil"] = {1428, 0.66, 0.22, "Tinkee Steamboil - Flame Crest (area)"},
  ["ragged john"] = {1428, 0.66, 0.22, "Ragged John - Flame Crest (area)"},
  ["jalinda sprig"] = {1428, 0.84, 0.68, "Jalinda Sprig - Morgan's Vigil (area)"},
  ["oralius"] = {1428, 0.84, 0.68, "Oralius - Morgan's Vigil (area)"},
  ["helendis riverhorn"] = {1428, 0.84, 0.68, "Helendis Riverhorn - Morgan's Vigil (area)"},
  ["marshal maxwell"] = {1428, 0.84, 0.68, "Marshal Maxwell - Morgan's Vigil (area)"},
  ["mayara brightwing"] = {1428, 0.84, 0.68, "Mayara Brightwing - Morgan's Vigil (area)"},
  ["thunderheart"] = {1418, 0.03, 0.46, "Thunderheart - Kargath (area)"},
  ["shadowmage vivian lagrave"] = {1418, 0.03, 0.46, "Vivian Lagrave - Kargath (area)"},
  ["warlord goretooth"] = {1418, 0.03, 0.46, "Warlord Goretooth - Kargath (area)"},
  ["galamav the marksman"] = {1418, 0.03, 0.46, "Galamav - Kargath (area)"},
  ["lexlort"] = {1418, 0.03, 0.46, "Lexlort - Kargath (area)"},
  ["lotwil veriatus"] = {1418, 0.26, 0.45, "Lotwil Veriatus - Badlands"},
  ["hierophant theodora mulvadania"] = {1418, 0.03, 0.46, "Theodora - Kargath (area)"},
  ["wanted poster"] = {1418, 0.03, 0.46, "Wanted Poster - Kargath (area)"},
  ["thrall"] = {1454, 0.32, 0.38, "Thrall - Grommash Hold"},
  ["eitrigg"] = {1454, 0.32, 0.38, "Eitrigg - Grommash Hold"},
  ["sagorne creststrider"] = {1454, 0.32, 0.38, "Valley of Wisdom - Orgrimmar (area)"},
  ["highlord bolvar fordragon"] = {1453, 0.78, 0.18, "Stormwind Keep (area)"},
  ["magistrate solomon"] = {1433, 0.27, 0.45, "Magistrate Solomon - Lakeshire (area)"},
  ["squire rowe"] = {1453, 0.66, 0.74, "Stormwind gates (area)"},
  ["haleh"] = {1452, 0.58, 0.43, "Haleh - Mazthoril, Winterspring (area)"},
  ["myranda the hag"] = {1422, 0.5, 0.72, "Myranda - Sorrow Hill (area)"},
  ["lorax"] = {1452, 0.62, 0.72, "Lorax - southern Winterspring (area)"},
  ["felnok steelspring"] = {1452, 0.61, 0.38, "Felnok Steelspring - Everlook (area)"},
  ["jaron stoneshaper"] = {1452, 0.52, 0.3, "Jaron Stoneshaper - Starfall Village (area)"},
  ["wynd nightchaser"] = {1452, 0.52, 0.3, "Wynd Nightchaser - Starfall Village (area)"},
  ["an achronos"] = {1446, 0.64, 0.5, "Caverns of Time entrance - Tanaris (area)"},
  ["anachronos"] = {1446, 0.64, 0.5, "Anachronos - Caverns of Time entrance (area)"},
  ["latronicus moonspear"] = {1444, 0.3, 0.43, "Feathermoon Stronghold - Feralas (area)"},
  ["scholar runethorn"] = {1444, 0.3, 0.43, "Feathermoon Stronghold - Feralas (area)"},
  ["talo thornhoof"] = {1444, 0.74, 0.43, "Camp Mojache - Feralas (area)"},
  ["sage korolusk"] = {1444, 0.74, 0.43, "Camp Mojache - Feralas (area)"},
  ["azj'tordin"] = {1444, 0.77, 0.37, "Azj'Tordin - Lariss Pavilion (area)"},
  ["rabine saturna"] = {1450, 0.45, 0.35, "Nighthaven - Moonglade (area)"},
  ["keeper remulos"] = {1450, 0.37, 0.42, "Keeper Remulos - Shrine of Remulos (area)"},
  ["aurora skycaller"] = {1423, 0.51, 0.21, "Aurora Skycaller - Northpass Tower (area)"},
  ["betina bigglezink"] = {1423, 0.75, 0.52, "Light's Hope Chapel - Eastern Plaguelands (area)"},
  ["leonid barthalomew"] = {1423, 0.75, 0.52, "Light's Hope Chapel - Eastern Plaguelands (area)"},
  ["duke nicholas zverenhoff"] = {1423, 0.75, 0.52, "Light's Hope Chapel - Eastern Plaguelands (area)"},
  ["smokey larue"] = {1423, 0.75, 0.52, "Light's Hope Chapel - Eastern Plaguelands (area)"},
  ["caretaker alen"] = {1423, 0.75, 0.52, "Light's Hope Chapel - Eastern Plaguelands (area)"},
  ["nathanos blightcaller"] = {1423, 0.26, 0.74, "Marris Stead - Eastern Plaguelands (area)"},
  ["egan"] = {1423, 0.14, 0.33, "Egan - Terrordale"},
  ["artist renfray"] = {1422, 0.69, 0.73, "Caer Darrow dock - Western Plaguelands (area)"},
  ["eva sarkhoff"] = {1422, 0.69, 0.73, "Caer Darrow - Western Plaguelands (area)"},
  ["magistrate marduke"] = {1422, 0.69, 0.73, "Caer Darrow - Western Plaguelands (area)"},
  ["weldon barov"] = {1422, 0.42, 0.84, "Weldon Barov - Chillwind Camp (area)"},
  ["high executor derrington"] = {1420, 0.83, 0.69, "The Bulwark - Tirisfal Glades (area)"},
  ["alexi barov"] = {1420, 0.83, 0.69, "Alexi Barov - The Bulwark (area)"},
  ["gorzeeki wildeyes"] = {1428, 0.12, 0.31, "Altar of Storms - Burning Steppes (area)"},
  ["mor'zul bloodbringer"] = {1428, 0.12, 0.31, "Altar of Storms - Burning Steppes (area)"},
  ["lord grayson shadowbreaker"] = {1453, 0.5, 0.45, "Stormwind Cathedral (area)"},
  ["anthion harmon"] = {1423, 0.27, 0.12, "Stratholme main gate - Eastern Plaguelands (area)"},
  ["falrin treeshaper"] = {1444, 0.59, 0.44, "Dire Maul Athenaeum - Feralas (entrance area)"},
  ["lorekeeper lydros"] = {1444, 0.59, 0.44, "Dire Maul Athenaeum - Feralas (entrance area)"},
  ["lorekeeper kildrath"] = {1444, 0.59, 0.44, "Dire Maul Athenaeum - Feralas (entrance area)"},
  ["myriam moonsinger"] = {1413, 0.49, 0.94, "Myriam Moonsinger - RFD exterior (verified NPC)"},
  ["franclorn forgewright"] = {1428, 0.29, 0.289, "Blackrock Mountain interior: Franclorn's Tomb (entrance area)"},
  ["lothos riftwaker"] = {1428, 0.29, 0.289, "Blackrock Mountain interior: Lothos (entrance area)"},
  ["bodley"] = {1428, 0.29, 0.289, "Blackrock Mountain interior: Bodley (entrance area)"},
  ["shen'dralar ancient"] = {1444, 0.59, 0.44, "Dire Maul West - Feralas (entrance area)"},
  ["knot thimblejack"] = {1444, 0.59, 0.44, "Dire Maul North - Feralas (entrance area)"},
  ["captain kromcrush"] = {1444, 0.59, 0.44, "Dire Maul North - Feralas (entrance area)"},
  ["lord solanar bloodwrath"] = {1954, 0.91, 0.38, "Blood Knight enclave - Silvermoon (area)"},
}
local function GetStartMap(pickup)
  if type(pickup) ~= "string" or pickup == "" then return nil end
  local text = string.lower(pickup)
  -- Quest items and NPCs only found inside an instance do not have world NPC waypoints.
  if text:find("inside ", 1, true) or text:find("dropped ", 1, true)
    or text:find("after killing", 1, true) or text:find("40 splinters", 1, true)
    or text:find("remains of a paladin", 1, true)
    or text:find("shattered necklace", 1, true) or text:find("crumpled note", 1, true)
    or text:find("small scroll", 1, true) or text:find("venom bottles", 1, true)
    or text:find("menethil's gift rune", 1, true) or text:find("discs of norgannon", 1, true)
    or text:find("crumpled map", 1, true) then return nil end
  local winner, length
  for key, coords in pairs(MapAnchors) do
    if text:find(key, 1, true) and (not length or #key > length) then
      winner, length = coords, #key
    end
  end
  if not winner then return nil end
  return {mapID = winner[1], x = winner[2], y = winner[3],
      label = winner[4], detail = "Quest giver location. Waypoints marked (area) are approximate."}
end
-- First update the public dungeon quest pages; keep all existing quest IDs and progression.
for _, dungeon in pairs(FDJ.DB or {}) do
  for _, quest in ipairs(dungeon.quests or {}) do
    if quest.id and quest.tbcCompendium == true then
      -- The raw PDF excerpts belong in research notes, not inside the Journal.
      quest.note = nil
      if not quest.startMap then quest.startMap = GetStartMap(quest.pickup) end
      if not MainByID[quest.id] then MainByID[quest.id] = quest end
    end
  end
end
-- Standalone, quest-specific instructions which genuinely affect how the quest is done.
local SpecialNotes = {
 [1053] = "Requires Library, Armory and Cathedral. The Scarlet Key comes from Doan's Strongbox in Library.",
 [1048] = "Requires Library, Armory and Cathedral. The Scarlet Key comes from Doan's Strongbox in Library.",
 [6521] = "Ambassador Malcin is OUTSIDE Razorfen Downs; he is not an instance boss.",
 [2398] = "Baelog is inside Uldaman. Do not confuse the outdoor dig with the instance entrance.",
 [2240] = "Use the Staff of Prehistoria at the Map Room and ENTER Ironaya's chamber; the kill alone does not count.",
 [2204] = "Accept this step through the scrying phial BEFORE killing Archaedas.",
 [3527] = "Loot the tablets from Theka and Velratha. The later tablets are part of a much longer chain.",
 [2768] = "Complete the pyramid event and then confront Sergeant Bly to recover the rod.",
 [2770] = "To summon Gahz'rilla, someone needs a Mallet of Zul'Farrak made at Jintha'Alor.",
 [3525] = "Accept the escort before Belnistrasz starts moving; do not leave before the post-event interaction.",
 [7044] = "The two rod components come from different Maraudon branches: orange and purple.",
 [3373] = "Using the Essence Font provides Chained Essence of Eranikus; its old storyline is unfinished.",
 [3802] = "Franclorn is visible only when your character is a ghost. The key unlocks BRD shortcuts.",
 [4024] = "Use the Altered Black Dragonflight Molt on Bael'Gar's remains after killing him.",
 [4362] = "Keep Princess Moira alive; speak to her after the Emperor dies.",
 [4003] = "Keep Princess Moira alive; speak to her after the Emperor dies.",
 [4322] = "Have your whole group ready before starting Windsor's prison escort.",
 [5213] = "Look for a small Scourge Data container in the three Undead-side ziggurats.",
 [5466] = "Use Soulbound Keepsake to change Ras into a HUMAN before killing him.",
 [5282] = "Use Egan's Blaster first on citizens, then on the released souls (15 total).",
 [4735] = "Collect eight UBRS eggs using the improved device after finishing Egg Freezing.",
 [4771] = "Activate Dawn's Gambit in the Viewing Room after coordinating with your party.",
 [7631] = "Complete the dreadsteed ritual in Dire Maul West, not the nearby overworld.",
 [8258] = "Horde shaman quest in Scholomance; the TBC reward is Skyfury Helm.",
 [5526] = "Requires a Reliquary of Purity; the Felvine objective is in Dire Maul East.",
 [7848] = "The Core Fragment is by the Molten Core portal deep inside BRD.",
 [9251] = "Requires raid components from Kel'Thuzad and C'Thun before the dungeon final step.",
}
for _, dungeon in pairs(FDJ.DB or {}) do
  for _, quest in ipairs(dungeon.quests or {}) do
    if quest.tbcCompendium then quest.note = SpecialNotes[quest.id] end
  end
end
-- Chain steps: use the full structured quest when it already exists as a main entry.
for id, details in pairs(StepDetails) do
  local main = MainByID[id]
  if main and (not details.objective or details.objective == "" or details.objective:find("Quest%-chain step")) then
    details.objective = main.objective
    details.pickup = main.pickup
    details.turnin = main.turnin
    details.requires = main.requires
    if main.startMap then details.map = main.startMap end
    details.note = SpecialNotes[id]
  end
end
-- Explicit, independent pages for prerequisites not represented as dungeon main entries.
local StepText = {
  [261] = {"Brother Anton, Nijel's Point, Desolace", "Brother Anton, Nijel's Point, Desolace", "Kill 30 Undead Ravagers in the Valley of Bones, Desolace; return to Brother Anton."},
  [707] = {"Prospector Stormpike, Hall of Explorers, Ironforge", "Prospector Ironband, Ironband's Excavation, Loch Modan", "Travel to Ironband's Excavation and speak to Prospector Ironband."},
  [720] = {"Crumpled Map, western Badlands excavation", "Prospector Ryedol, Badlands dig camp", "Find the Crumpled Map near Hammertoe's Digsite; deliver it to Prospector Ryedol."},
  [721] = {"Prospector Ryedol, Badlands", "Hammertoe Grez, Uldaman outer caves", "Find the missing Hammertoe Grez in the excavation tunnels outside Uldaman."},
  [723] = {"Hammertoe Grez, outer Uldaman", "Prospector Ryedol, Badlands", "Return to Prospector Ryedol after recovering Hammertoe's amulet."},
  [724] = {"Prospector Ryedol, Badlands", "Historian Karnik, Ironforge", "Deliver Ryedol's findings to Historian Karnik in the Hall of Explorers."},
  [725] = {"Historian Karnik, Hall of Explorers, Ironforge", "Advisor Belgrum, Hall of Explorers, Ironforge", "Pass Karnik's warning to Advisor Belgrum nearby."},
  [726] = {"Advisor Belgrum, Hall of Explorers, Ironforge", "Historian Karnik, Hall of Explorers, Ironforge", "Return to Historian Karnik with Advisor Belgrum's message."},
  [738] = {"Prospector Ironband, Ironband's Excavation, Loch Modan", "Battered Dwarven Skeleton, southern Badlands", "Find Agmond at his skeleton south of the Badlands excavation."},
  [739] = {"Battered Dwarven Skeleton, southern Badlands", "Prospector Ironband, Ironband's Excavation, Loch Modan", "Kill Murdaloc and the Stonevault Bonesnappers in Badlands, then report to Ironband."},
  [762] = {"Historian Karnik, Hall of Explorers, Ironforge", "Advisor Belgrum, Ironforge", "Kill Ambassador Infernus at Angor Fortress, Badlands; report to Belgrum."},
  [1052] = {"Brother Anton, Nijel's Point, Desolace", "Raleigh the Devout, Southshore inn, Hillsbrad Foothills", "Deliver Brother Anton's letter to Raleigh the Devout in Southshore."},
  [1109] = {"Master Apothecary Faranell, Undercity Apothecarium", "Master Apothecary Faranell, Undercity Apothecarium", "Collect bat guano inside Razorfen Kraul and bring it to Faranell."},
  [1424] = {"Fel'zerul, Stonard, Swamp of Sorrows", "Fel'zerul, Stonard", "Collect 10 Atal'ai Artifacts around the Pool of Tears, then return to Fel'zerul."},
  [1429] = {"Fel'zerul, Stonard, Swamp of Sorrows", "Atal'ai Exile, Shadra'Alor, Hinterlands", "Speak with the Atal'ai Exile at Shadra'Alor in the Hinterlands."},
  [1444] = {"Atal'ai Exile, Shadra'Alor, Hinterlands", "Fel'zerul, Stonard", "Return to Fel'zerul in Stonard with the exile's information."},
  [1448] = {"Brohann Caskbelly, Dwarven District, Stormwind", "Brohann Caskbelly, Stormwind", "Find the Temple of Atal'Hakkar at the Pool of Tears in Swamp of Sorrows; return to Brohann."},
  [1449] = {"Brohann Caskbelly, Dwarven District, Stormwind", "Falstad Wildhammer, Aerie Peak, Hinterlands", "Go to Aerie Peak in the Hinterlands and speak to Falstad Wildhammer."},
  [1450] = {"Falstad Wildhammer, Aerie Peak, Hinterlands", "Gryphon Master Talonaxe, Aerie Peak, Hinterlands", "Speak with Gryphon Master Talonaxe at Aerie Peak."},
  [1451] = {"Gryphon Master Talonaxe, Aerie Peak, Hinterlands", "Rhapsody Shindigger, Shindigger's Camp, Hinterlands", "Find Rhapsody Shindigger at his camp in the Hinterlands."},
  [1452] = {"Rhapsody Shindigger, Shindigger's Camp, Hinterlands", "Rhapsody Shindigger, Shindigger's Camp, Hinterlands", "Collect Roc Gizzards in Tanaris, and Ironfur/Groddoc livers in Feralas; return to Rhapsody."},
  [1469] = {"Rhapsody Shindigger, Shindigger's Camp, Hinterlands", "Brohann Caskbelly, Stormwind", "Take Rhapsody's account of the temple back to Brohann in Stormwind."},
  [2198] = {"Shattered Necklace, drop in Uldaman", "Talvash del Kissel, Mystic Ward, Ironforge", "Loot the Shattered Necklace from Uldaman enemies; take it to Talvash del Kissel."},
  [2199] = {"Talvash del Kissel, Mystic Ward, Ironforge", "Talvash del Kissel, Mystic Ward, Ironforge", "Bring five Silver Bars to Talvash del Kissel in Ironforge."},
  [2200] = {"Talvash del Kissel, Mystic Ward, Ironforge", "Remains of a Paladin, inside Uldaman", "Return to Uldaman and find the Remains of a Paladin in the early instance rooms."},
  [2258] = {"Jarkal Mossmeld, Kargath inn, Badlands", "Jarkal Mossmeld, Kargath inn", "Collect the requested Badlands wildlife and elemental reagents for Jarkal."},
  [2284] = {"Dran Droffers, The Drag, Orgrimmar", "Remains of a Paladin, inside Uldaman", "Find the Remains of a Paladin inside Uldaman and examine the journal."},
  [2318] = {"Remains of a Paladin, inside Uldaman", "Jarkal Mossmeld, Kargath inn, Badlands", "Take the paladin's journal to Jarkal Mossmeld in Kargath for translation."},
  [2338] = {"Jarkal Mossmeld, Kargath inn, Badlands", "Jarkal Mossmeld, Kargath inn, Badlands", "Complete Jarkal Mossmeld's journal-translation dialogue in Kargath."},
  [2500] = {"Ghak Healtouch, Thelsamar, Loch Modan", "Ghak Healtouch, Thelsamar, Loch Modan", "Collect wildlife and elemental reagents from the Badlands for Ghak Healtouch."},
  [2933] = {"Venom Bottles, Witherbark camps, Hinterlands", "Apothecary Lydon, Tarren Mill, Hillsbrad Foothills", "Investigate Venom Bottles at Witherbark camps and take a sample to Lydon."},
  [2934] = {"Apothecary Lydon, Tarren Mill, Hillsbrad Foothills", "Apothecary Lydon, Tarren Mill", "Collect an Undamaged Venom Sac from Witherbark Broodguards."},
  [2935] = {"Apothecary Lydon, Tarren Mill, Hillsbrad Foothills", "Master Gadrin, Sen'jin Village, Durotar", "Consult Master Gadrin in Sen'jin Village."},
  [2988] = {"Gryphon Master Talonaxe, Aerie Peak, Hinterlands", "Gryphon Master Talonaxe, Aerie Peak", "Investigate the Witherbark troll cages in the Hinterlands; report to Talonaxe."},
  [2989] = {"Gryphon Master Talonaxe, Aerie Peak, Hinterlands", "Gryphon Master Talonaxe, Aerie Peak", "Investigate the Altar of Zul and report to Talonaxe."},
  [2990] = {"Gryphon Master Talonaxe, Aerie Peak, Hinterlands", "Thadius Grimshade, Nethergarde Keep, Blasted Lands", "Travel to Nethergarde Keep and speak with Thadius Grimshade."},
  [3444] = {"Marvon Rivetseeker, Broken Pillar, Tanaris", "Marvon Rivetseeker, Broken Pillar, Tanaris", "Retrieve Marvon's Stone Circle from his workshop chest at Ratchet and return it to him."},
  [3701] = {"Royal Historian Archesonus, Ironforge", "Royal Historian Archesonus, Ironforge", "Gather information from relics in the ruined city of Thaurissan, Burning Steppes, and return."},
  [3702] = {"Royal Historian Archesonus, Ironforge", "Royal Historian Archesonus, Ironforge", "Speak with Royal Historian Archesonus about Thaurissan and the Dark Irons."},
  [3801] = {"Franclorn Forgewright's ghost, Blackrock Mountain", "Franclorn Forgewright's ghost, Blackrock Mountain", "Speak to Franclorn while in ghost form; accept his second Dark Iron Legacy task."},
  [3906] = {"Thunderheart, Kargath, Badlands", "Thunderheart, Kargath, Badlands", "Kill Overmaster Pyron outside the Blackrock Depths entrance; report to Thunderheart."},
  [4001] = {"Commander Gor'shak, BRD prison", "Thrall, Grommash Hold, Orgrimmar", "Report the prisoners' findings to Thrall in Orgrimmar."},
  [4002] = {"Thrall, Grommash Hold, Orgrimmar", "Thrall, Grommash Hold, Orgrimmar", "Speak to Thrall about the Eastern Kingdoms and Moira."},
  [4022] = {"Cyrus Therepentous, northeastern Burning Steppes", "Cyrus Therepentous, northeastern Burning Steppes", "Show Cyrus a Black Dragonflight Molt or complete his drake challenge for one."},
  [4061] = {"Hierophant Theodora Mulvadania, Kargath", "Hierophant Theodora Mulvadania, Kargath", "Collect ten Fractured Elemental Shards from Burning Steppes elementals."},
  [4062] = {"Hierophant Theodora Mulvadania, Kargath", "Lotwil Veriatus, Badlands", "Bring the shard sample to Lotwil Veriatus at his camp in Badlands."},
  [4121] = {"Grark Lorkrub, Blackrock Stronghold, Burning Steppes", "Kargath Expeditionary Force, Burning Steppes", "Escort Grark through the Burning Steppes to the Kargath expedition."},
  [4122] = {"Lexlort, Kargath, Badlands", "Grark Lorkrub, Blackrock Stronghold, Burning Steppes", "Use the supplied method to subdue Grark at Blackrock Stronghold."},
  [4141] = {"Muigin, Marshal's Refuge, Un'Goro Crater", "Muigin, Marshal's Refuge, Un'Goro Crater", "Collect the requested Bloodpetals for Muigin at Marshal's Refuge."},
  [4142] = {"Muigin, Marshal's Refuge, Un'Goro Crater", "Gregan Brewspewer, Twin Colossals, Feralas", "Find Gregan Brewspewer at the Twin Colossals, Feralas."},
  [4145] = {"Larion, Marshal's Refuge, Un'Goro Crater", "Larion, Marshal's Refuge, Un'Goro Crater", "Kill the requested Bloodpetal creatures for Larion."},
  [4147] = {"Larion, Marshal's Refuge, Un'Goro Crater", "Liv Rizzlefix, Ratchet, Barrens", "Speak with Liv Rizzlefix at Ratchet about the zapper."},
  [4262] = {"Jalinda Sprig, Morgan's Vigil, Burning Steppes", "Jalinda Sprig, Morgan's Vigil", "Kill Overmaster Pyron at the quarry outside BRD."},
  [4342] = {"Kharan Mighthammer, BRD prison", "Kharan Mighthammer, BRD prison", "Speak to Kharan Mighthammer in his cell and hear his story about Moira."},
  [4361] = {"Kharan Mighthammer, BRD prison", "King Magni Bronzebeard, Ironforge", "Deliver the news about Princess Moira to King Magni Bronzebeard."},
  [4981] = {"Lexlort, Kargath, Badlands", "Bijou, inside LBRS", "Find Operative Bijou inside Lower Blackrock Spire."},
  [5002] = {"Bijou, inside LBRS", "Marshal Maxwell, Morgan's Vigil, Burning Steppes", "Deliver Bijou's message to Marshal Maxwell at Morgan's Vigil."},
  [5244] = {"Wynd Nightchaser, Starfall Village, Winterspring", "Jaron Stoneshaper, Starfall Village, Winterspring", "Speak with Jaron Stoneshaper at Starfall Village about Kel'Theril."},
  [5245] = {"Jaron Stoneshaper, Starfall Village, Winterspring", "Aurora Skycaller, Northpass Tower, Eastern Plaguelands", "Collect the Kel'Theril relic fragments and take them to Aurora Skycaller."},
  [5246] = {"Aurora Skycaller, Northpass Tower, Eastern Plaguelands", "Aurora Skycaller, Northpass Tower, Eastern Plaguelands", "Recover Sacred Highborne Writings from the Temple of Zin-Malor in Azshara."},
  [5281] = {"Caretaker Alen, Light's Hope Chapel, Eastern Plaguelands", "Egan, Terrordale, Eastern Plaguelands", "Travel to Terrordale and speak to Egan about the restless citizens of Stratholme."},
  [5461] = {"Magistrate Marduke, Caer Darrow, Western Plaguelands", "Magistrate Marduke, Caer Darrow", "Find the Keepsake of Remembrance in Stromgarde Keep, Arathi Highlands."},
  [5462] = {"Magistrate Marduke, Caer Darrow, Western Plaguelands", "Leonid Barthalomew, Light's Hope Chapel, Eastern Plaguelands", "Deliver Marduke's message to Leonid Barthalomew at Light's Hope Chapel."},
  [5464] = {"Menethil's Gift rune, Baron Rivendare room, Stratholme", "Leonid Barthalomew, Light's Hope Chapel", "Return to Leonid after examining the Menethil's Gift rune in Stratholme."},
  [5465] = {"Leonid Barthalomew, Light's Hope Chapel, Eastern Plaguelands", "Magistrate Marduke, Caer Darrow", "Take the Soulbound Keepsake to Magistrate Marduke in Caer Darrow."},
  [5527] = {"Rabine Saturna, Nighthaven, Moonglade", "Dusty Reliquary, Feralas", "Find the Dusty Reliquary in Feralas and prepare it to contain the Felvine shard."},
  [6022] = {"Nathanos Blightcaller, Marris Stead, Eastern Plaguelands", "Nathanos Blightcaller, Marris Stead", "Collect the requested Scourge materials while eliminating undead in Eastern Plaguelands."},
  [6042] = {"Nathanos Blightcaller, Marris Stead, Eastern Plaguelands", "Nathanos Blightcaller, Marris Stead", "Kill the listed pest creatures around Eastern Plaguelands for Nathanos."},
  [6133] = {"Nathanos Blightcaller, Marris Stead, Eastern Plaguelands", "Nathanos Blightcaller, Marris Stead", "Kill the requested Scarlet and High Elf targets around Quel'Lithien Lodge."},
  [6135] = {"Nathanos Blightcaller, Marris Stead, Eastern Plaguelands", "Nathanos Blightcaller, Marris Stead", "Find and kill Duskwing in Eastern Plaguelands."},
  [6136] = {"Nathanos Blightcaller, Marris Stead, Eastern Plaguelands", "Nathanos Blightcaller, Marris Stead", "Kill the Corpulent Horror in Eastern Plaguelands."},
  [6522] = {"Small Scroll, dropped by Charlga Razorflank in Razorfen Kraul", "Varimathras, Undercity Royal Quarter", "Read the Small Scroll dropped by Charlga and deliver its message to Varimathras."},
  [7667] = {"Sagorne Creststrider, Valley of Wisdom, Orgrimmar", "Sagorne Creststrider, Orgrimmar", "Bring one Azerothian Diamond and one Pristine Black Diamond to Sagorne Creststrider."},
  [8151] = {"Hunter class trainer", "Ogtinc, Azshara", "Visit Ogtinc on the cliffs northeast of the Ruins of Eldarath in Azshara."},
  [8153] = {"Ogtinc, Azshara", "Ogtinc, Azshara", "Collect Courser Antlers from the coursers in Azshara; return to Ogtinc."},
  [8231] = {"Ogtinc, Azshara", "Ogtinc, Azshara", "Collect the required Wavethrasher Scales along Azshara's coast."},
  [8233] = {"Rogue class trainer", "Lord Jorach Ravenholdt, Ravenholdt Manor, Alterac Mountains", "Travel to Ravenholdt Manor and speak with Lord Jorach Ravenholdt."},
  [8234] = {"Lord Jorach Ravenholdt, Ravenholdt Manor", "Lord Jorach Ravenholdt, Ravenholdt Manor", "Pickpocket the Sealed Azure Bag from Timbermaw shamans in Azshara."},
  [8235] = {"Archmage Xylem, Azshara", "Archmage Xylem, Azshara", "Pickpocket Encoded Fragments from the required slimes in Azshara."},
  [8250] = {"Mage class trainer", "Archmage Xylem, Azshara", "Report to Archmage Xylem at his tower in Azshara."},
  [8251] = {"Archmage Xylem, Azshara", "Archmage Xylem, Azshara", "Collect Magic Dust from blood elves in Azshara."},
  [8252] = {"Archmage Xylem, Azshara", "Archmage Xylem, Azshara", "Collect Siren's Coral from Spitelash Sirens along Azshara's coast."},
  [8254] = {"Priest class trainer, Stormwind / Ironforge / Orgrimmar", "Ogtinc, Azshara", "Speak to Ogtinc in Azshara for Cenarion Aid (class trainers provide the referral)."},
  [8255] = {"Ogtinc, Azshara", "Ogtinc, Azshara", "Collect the required glands from coursers in Azshara."},
  [8256] = {"Ogtinc, Azshara", "Ogtinc, Azshara", "Collect an Ichor of Undeath for Ogtinc."},
  [8412] = {"Bath'rah the Windwatcher, Alterac Mountains", "Bath'rah the Windwatcher, Alterac Mountains", "Collect eight Bloodshot Spider Eyes and eight Thick Black Claws from Western Plaguelands wildlife."},
  [8414] = {"Commander Ashlam Valorfist, Chillwind Camp, Western Plaguelands", "Commander Ashlam Valorfist, Chillwind Camp", "Defeat the undead demanded by Ashlam and complete his Dispelling Evil task."},
  [8416] = {"Commander Ashlam Valorfist, Chillwind Camp, Western Plaguelands", "High Priestess MacDonnell, Chillwind Camp", "Gather Inert Scourgestones and have them prepared at Chillwind Camp."},
  [8417] = {"Warrior class trainer", "Fallen Hero of the Horde, Swamp of Sorrows / Blasted Lands border", "Speak to the Fallen Hero of the Horde at the Blasted Lands border."},
  [8419] = {"Warlock class trainer", "Impsy, Bloodvenom Falls, Felwood", "Find Impsy beside Niby the Almighty in Felwood."},
  [8420] = {"Impsy, Bloodvenom Falls, Felwood", "Impsy, Bloodvenom Falls, Felwood", "Bring Felcloth to Impsy in Felwood."},
  [8421] = {"Impsy, Bloodvenom Falls, Felwood", "Impsy, Bloodvenom Falls, Felwood", "Collect the requested infernal and elemental components in Felwood."},
  [8423] = {"Fallen Hero of the Horde, Blasted Lands border", "Fallen Hero of the Horde, Blasted Lands border", "Kill seven Helboars in the Blasted Lands."},
  [8424] = {"Fallen Hero of the Horde, Blasted Lands border", "Fallen Hero of the Horde, Blasted Lands border", "Kill the required Shadowsworn in the Blasted Lands."},
  [8948] = {"Anthion Harmon, Stratholme entrance, Eastern Plaguelands", "Falrin Treeshaper, Dire Maul Athenaeum", "Bring Anthion's unfinished task to Falrin Treeshaper in the Dire Maul Athenaeum."},
  [9051] = {"Torwa Pathfinder, Un'Goro Crater", "Torwa Pathfinder, Un'Goro Crater", "Test Torwa's Bloodpetal poison on a devilsaur in Un'Goro."},
  [9052] = {"Torwa Pathfinder, Un'Goro Crater", "Torwa Pathfinder, Un'Goro Crater", "Collect the materials for Bloodpetal Poison from the creatures in Un'Goro."},
  [9250] = {"40 Splinters of Atiesh, Naxxramas", "Anachronos, outside Caverns of Time, Tanaris", "Combine forty Splinters of Atiesh from Naxxramas into the Frame of Atiesh; bring it to Anachronos."},
  [9251] = {"Anachronos, outside Caverns of Time, Tanaris", "Anachronos, outside Caverns of Time, Tanaris", "Retrieve the Staff Head of Atiesh from Kel'Thuzad and the Base of Atiesh from C'Thun; return to Anachronos."},
}
for id, row in pairs(StepText) do
  local details = StepDetails[id] or {}
  details.pickup, details.turnin, details.objective = row[1], row[2], row[3]
  details.map = GetStartMap(row[1]) or details.map
  details.note = SpecialNotes[id]
  StepDetails[id] = details
end
-- Fix historic chain steps whose turn-in incorrectly repeated the starting NPC.
local TurnInFixes = {
 [4183] = "Magistrate Solomon, Lakeshire", [4184] = "Highlord Bolvar Fordragon, Stormwind Keep",
 [4186] = "Magistrate Solomon, Lakeshire", [4223] = "Marshal Maxwell, Morgan\'s Vigil",
 [4242] = "Marshal Maxwell, Morgan\'s Vigil",
 [4808] = "Felnok Steelspring, Everlook", [4810] = "Tinkee Steamboil, Flame Crest",
 [4907] = "Tinkee Steamboil, Flame Crest", [4941] = "Thrall, Grommash Hold",
 [5522] = "Leonid Barthalomew, Light\'s Hope Chapel", [5531] = "Betina Bigglezink, Light\'s Hope Chapel",
 [6402] = "Squire Rowe, Stormwind gates", [6403] = "Highlord Bolvar Fordragon, Stormwind Keep",
 [6501] = "Haleh, Winterspring", [6567] = "Rokaro, Shadowprey Village",
 [6568] = "Myranda the Hag, Sorrow Hill", [6570] = "Emberstrife, Dustwallow Marsh",
 [6601] = "Rokaro, Shadowprey Village", [7564] = "Gorzeeki Wildeyes, Altar of Storms",
 [7623] = "Lord Banehollow, Felwood", [7625] = "Gorzeeki Wildeyes, Altar of Storms",
 [7637] = "High Priest Rohan, Ironforge", [7639] = "Lord Grayson Shadowbreaker, Stormwind",
 [7641] = "Grimand Elmore, Stormwind", [7644] = "Lord Grayson Shadowbreaker, Stormwind",
 [7648] = "Lord Grayson Shadowbreaker, Stormwind",
}
for id, name in pairs(TurnInFixes) do
  if StepDetails[id] then StepDetails[id].turnin = name end
end
-- Reuse accurately labelled NPC/camp coordinates on already-written non-placeholder pages.
for id, details in pairs(StepDetails) do
  if not details.map and not details.startItem then details.map = GetStartMap(details.pickup) end
  if details.note and (details.note:find("Quest Compendium", 1, true)
       or details.note:find("Compendium p", 1, true)) then details.note = SpecialNotes[id] end
end
