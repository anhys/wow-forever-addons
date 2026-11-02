-- Dungeon Journal: 7 original Vanilla raids available in TBC Anniversary.
-- Data: Classic-era encounter rosters. Full item drops are loaded from VanillaRaidLoot.lua.
-- No Wrath/SoD raid loot or private-server additions.
local _, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS
if not FDJ or not FDJ.IS_TBC_ANNIVERSARY then return end
FDJ.DB = FDJ.DB or {}
FDJ.ORDER = FDJ.ORDER or {}
FDJ.BOSS_LEVELS = FDJ.BOSS_LEVELS or {}
FDJ.DUNGEON_HOME_ART = FDJ.DUNGEON_HOME_ART or {}
FDJ.DUNGEON_PAGE_ART = FDJ.DUNGEON_PAGE_ART or {}
FDJ.DUNGEON_HOME_TEXCOORD = FDJ.DUNGEON_HOME_TEXCOORD or {}
FDJ.DUNGEON_PAGE_TEXCOORD = FDJ.DUNGEON_PAGE_TEXCOORD or {}
local loads = "Interface\\Glues\\LoadingScreens\\"
-- Some Anniversary builds omit or rename original raid loading textures.
-- Resolve a valid in-client file rather than showing an empty/black tile.
-- These candidate paths deliberately stay inside the client; no web images.
local function FindRaidLoadingScreen(...)
  local candidates = {...}
  if GetFileIDFromPath then
    for _, path in ipairs(candidates) do
      local ok, id = pcall(GetFileIDFromPath, path)
      if ok and type(id) == "number" and id > 0 then return id end
    end
  end
  -- Older clients without GetFileIDFromPath: let SetTexture resolve the path.
  return candidates[1]
end
local raidArtCandidates = {
  ["Onyxia's Lair"] = {
    loads .. "LoadScreenOnyxia", loads .. "LoadScreenOnyxiasLair",
    loads .. "LoadScreenOnyxiaLair", loads .. "LoadScreenOnyxiaClassic",
  },
  ["Ruins of Ahn'Qiraj"] = {
    loads .. "LoadScreenAhnQiraj", loads .. "LoadScreenAQ20",
    loads .. "LoadScreenRuinsOfAhnQiraj", loads .. "LoadScreenRuinsAhnQiraj",
  },
  ["Temple of Ahn'Qiraj"] = {
    loads .. "LoadScreenAhnQiraj", loads .. "LoadScreenAQ40",
    loads .. "LoadScreenTempleOfAhnQiraj", loads .. "LoadScreenTempleAhnQiraj",
  },
}
local function Loot(id, name, quality) return {id, name, "Item", quality or 4} end
-- Static display IDs from original Classic NPC appearances; avoid a question-mark
-- portrait while the target creature is not nearby and the display isn't cached.
local displays = {
  [12118]=13031, [11982]=10193, [12259]=13030, [12057]=12110,
  [12264]=13032, [12056]=12129, [11988]=11986, [12098]=13030,
  [12018]=12029, [11502]=11121, [10184]=8570,
  [12435]=10115, [13020]=13992, [12017]=14308, [11983]=6377,
  [14601]=6377, [14517]=15219, [14507]=15217,
  [15348]=15742, [15341]=15376, [15340]=15392, [15370]=15654,
  [15263]=15345, [15516]=15583, [15510]=15743, [15299]=15686,
  [15509]=15739, [15517]=15509, [15727]=15787,
  [15956]=15931, [15953]=15940, [15952]=15928, [15954]=16590,
  [15936]=16309, [16011]=16110, [16061]=16582, [16060]=16279,
  [16028]=16174, [15931]=16035, [15932]=16064, [15928]=16137,
  [15989]=16033, [15990]=15945,
}
local function Boss(name, npcID, loot)
  local result = {name=name, npcID=npcID, displayID=displays[npcID], loot=loot or {}}
  return result
end
local raids = {}
local function Register(name, size, zone, mapID, x, y, art, description, bosses)
  FDJ.DB[name] = {expansion="raids", raidEra="vanilla", isRaid=true, raidSize=size,
    level="60", location=zone, description=description,
    quests={}, bosses=bosses,
    entrance={mapID=mapID, x=x, y=y, label=name .. " Entrance", markerType="dungeon"}}
  FDJ.BOSS_LEVELS[name] = {}
  for _, b in ipairs(bosses) do
    -- Every real encounter shows the ?? level badge, also multi-boss ones
    -- (Bug Trio, Twin Emperors, Four Horsemen) that have no single npcID.
    if b.npcID or (b.customIcon and not b.trash and not b.recipesDivider) then FDJ.BOSS_LEVELS[name][b.name] = "??" end
  end
  local sources = raidArtCandidates[name]
  -- Three custom Classic loading-screen paintings are bundled locally and
  -- have their header logos cropped out. They never depend on client CASC.
  local bundledRaidArt = {
    ["Onyxia's Lair"] = "RaidOnyxiaHome",
    ["Ruins of Ahn'Qiraj"] = "RaidAQRuinsHome",
    ["Temple of Ahn'Qiraj"] = "RaidAQTempleHome",
  }
  local bundled = bundledRaidArt[name]
  local artFile = bundled and ("Interface\\AddOns\\ForeverDungeonJournal\\Media\\" .. bundled)
    or (sources and FindRaidLoadingScreen(unpack(sources)) or loads .. art)
  FDJ.DUNGEON_HOME_ART[name] = artFile
  FDJ.DUNGEON_PAGE_ART[name] = artFile
  FDJ.RAID_ART_MISSING = FDJ.RAID_ART_MISSING or {}
  if sources and not bundled then
    FDJ.RAID_ART_MISSING[name] = true
  else
    FDJ.RAID_ART_MISSING[name] = nil
  end
  if bundled then
    -- Custom textures: top 320 rows in a 1024x512 .tga.
    FDJ.DUNGEON_HOME_TEXCOORD[name] = {0, 1, 0, 0.625}
    FDJ.DUNGEON_PAGE_TEXCOORD[name] = {0, 1, 0, 0.625}
  else
    FDJ.DUNGEON_HOME_TEXCOORD[name] = {0.02,0.98,0.26,0.82}
    FDJ.DUNGEON_PAGE_TEXCOORD[name] = {0.02,0.98,0.26,0.82}
  end
  raids[#raids+1] = name
end
-- Molten Core (40 players).
Register("Molten Core", 40, "Blackrock Mountain", 1428, 0.243, 0.245, "LoadScreenMoltenCore", "Tier 1 • original 40-player raid. Majordomo loot is obtained from Cache of the Firelord after his encounter (shown under Majordomo).", {
  Boss("Lucifron", 12118, {}),
  Boss("Magmadar", 11982, {}),
  Boss("Gehennas", 12259, {}),
  Boss("Garr", 12057, {Loot(18564, "Bindings of the Windseeker (Right Half)", 5)}),
  Boss("Baron Geddon", 12056, {Loot(18563, "Bindings of the Windseeker (Left Half)", 5)}),
  Boss("Shazzrah", 12264, {}),
  Boss("Sulfuron Harbinger", 12098, {}),
  Boss("Golemagg the Incinerator", 11988, {}),
  Boss("Majordomo Executus", 12018, {}),
  Boss("Ragnaros", 11502, {Loot(17204, "Eye of Sulfuras", 5), Loot(17076, "Bonereaver's Edge", 4), Loot(18817, "Crown of Destruction", 4), Loot(17063, "Band of Accuria", 4), Loot(17102, "Cloak of the Shrouded Mists", 4)}),
})
-- Onyxia's Lair (40 players).
Register("Onyxia's Lair", 40, "Dustwallow Marsh", 1445, 0.529, 0.769, "LoadScreenOnyxia", "Tier 2 helmets • original level-60 Onyxia encounter.", {
  Boss("Onyxia", 10184, {Loot(18423, "Head of Onyxia", 4), Loot(17075, "Vis'kag the Bloodletter", 4), Loot(17068, "Deathbringer", 4), Loot(17064, "Shard of the Scale", 4)}),
})
-- Blackwing Lair (40 players).
Register("Blackwing Lair", 40, "Blackrock Mountain", 1428, 0.243, 0.245, "LoadScreenBlackwingLair", "Tier 2 • Blackrock Mountain. Enter using the Orb of Command or the Upper Blackrock Spire route.", {
  Boss("Razorgore the Untamed", 12435, {}),
  Boss("Vaelastrasz the Corrupt", 13020, {}),
  Boss("Broodlord Lashlayer", 12017, {Loot(19351, "Maladath, Runed Blade of the Black Flight", 4)}),
  Boss("Firemaw", 11983, {}),
  Boss("Ebonroc", 14601, {}),
  Boss("Flamegor", 11981, {}),
  Boss("Chromaggus", 14020, {Loot(19361, "Ashjre'thul, Crossbow of Smiting", 4), Loot(19349, "Elementium Reinforced Bulwark", 4)}),
  Boss("Nefarian", 11583, {Loot(19364, "Ashkandi, Greatsword of the Brotherhood", 4), Loot(19379, "Neltharion's Tear", 4), Loot(19375, "Mish'undare, Circlet of the Mind Flayer", 4)}),
})
-- Zul'Gurub (20 players).
Register("Zul'Gurub", 20, "Stranglethorn Vale", 1434, 0.533, 0.176, "LoadScreenZulGurub", "20-player troll raid. Edge of Madness summons one of four possible bosses per rotation.", {
  Boss("High Priestess Jeklik", 14517, {}),
  Boss("High Priest Venoxis", 14507, {}),
  Boss("High Priestess Mar'li", 14510, {}),
  Boss("Bloodlord Mandokir", 11382, {Loot(19872, "Swift Razzashi Raptor", 4)}),
  Boss("High Priest Thekal", 14509, {Loot(19902, "Swift Zulian Tiger", 4)}),
  Boss("Gahz'ranka", 15114, {}),
  Boss("High Priestess Arlokk", 14515, {}),
  Boss("Jin'do the Hexxer", 11380, {}),
  {name="Edge of Madness", customIcon="Interface\\Icons\\INV_Misc_MonsterHead_01", loot={}, lootSections={
    {title="Gri'lek (rotating summon)", ids={}},
    {title="Hazza'rah (rotating summon)", ids={}},
    {title="Renataki (rotating summon)", ids={}},
    {title="Wushoolay (rotating summon)", ids={}},
  }},
  Boss("Hakkar the Soulflayer", 14834, {Loot(19802, "Heart of Hakkar", 4)}),
})
-- Ruins of Ahn'Qiraj (20 players).
Register("Ruins of Ahn'Qiraj", 20, "Silithus", 1451, 0.363, 0.943, "LoadScreenAhnQiraj", "20-player instance at the Scarab Wall, Silithus.", {
  Boss("Kurinnaxx", 15348, {}),
  Boss("General Rajaxx", 15341, {}),
  Boss("Moam", 15340, {}),
  Boss("Buru the Gorger", 15370, {}),
  Boss("Ayamiss the Hunter", 15369, {}),
  Boss("Ossirian the Unscarred", 15339, {}),
})
-- Temple of Ahn'Qiraj (40 players).
Register("Temple of Ahn'Qiraj", 40, "Silithus", 1451, 0.241, 0.871, "LoadScreenAhnQiraj", "40-player instance; Bug Trio and Twin Emperors are multi-boss encounters.", {
  Boss("The Prophet Skeram", 15263, {}),
  {name="The Bug Trio", customIcon="Interface\\AddOns\\ForeverDungeonJournal\\Media\\AQ40BugTrioPortrait", loot={}},
  Boss("Battleguard Sartura", 15516, {}),
  Boss("Fankriss the Unyielding", 15510, {}),
  Boss("Viscidus", 15299, {}),
  Boss("Princess Huhuran", 15509, {}),
  {name="The Twin Emperors", customIcon="Interface\\AddOns\\ForeverDungeonJournal\\Media\\AQ40TwinEmperorsPortrait", loot={}},
  Boss("Ouro", 15517, {}),
  Boss("C'Thun", 15727, {Loot(21126, "Death's Sting", 4), Loot(21134, "Dark Edge of Insanity", 4)}),
})
-- Naxxramas (40 players).
Register("Naxxramas", 40, "Eastern Plaguelands", 1423, 0.39, 0.26, "LoadScreenNaxxramas", "ORIGINAL level-60, 40-player Naxxramas in Eastern Plaguelands (not the level-80 version).", {
  Boss("Anub'Rekhan", 15956, {}),
  Boss("Grand Widow Faerlina", 15953, {}),
  Boss("Maexxna", 15952, {}),
  Boss("Noth the Plaguebringer", 15954, {}),
  Boss("Heigan the Unclean", 15936, {}),
  Boss("Loatheb", 16011, {}),
  Boss("Instructor Razuvious", 16061, {}),
  Boss("Gothik the Harvester", 16060, {}),
  {name="The Four Horsemen", customIcon="Interface\\AddOns\\ForeverDungeonJournal\\Media\\NaxxFourHorsemenPortrait", loot={Loot(22691, "Corrupted Ashbringer", 4)}},
  Boss("Patchwerk", 16028, {}),
  Boss("Grobbulus", 15931, {}),
  Boss("Gluth", 15932, {}),
  Boss("Thaddius", 15928, {}),
  Boss("Sapphiron", 15989, {}),
  Boss("Kel'Thuzad", 15990, {}),
})
-- Raid gallery order: TBC raids first, then original Vanilla raids.
local present = {}
for _, name in ipairs(FDJ.ORDER) do present[name] = true end
for _, name in ipairs(raids) do
  if not present[name] then FDJ.ORDER[#FDJ.ORDER+1] = name end
end
FDJ.VANILLA_RAID_NAMES = raids
FDJ.VANILLA_RAID_COUNT = #raids
