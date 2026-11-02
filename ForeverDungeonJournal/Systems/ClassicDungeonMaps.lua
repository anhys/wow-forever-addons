-- Original Classic dungeon layouts for the Anniversary journal.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ or not FDJ.IS_TBC_ANNIVERSARY or not FDJ.DUNGEON_MAPS then return end
local ROOT = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\ClassicDungeonMaps\\"
local function Pin(name, floor, x, y, note)
    return {name=name, floor=floor, x=x, y=y, mapNote=note}
end
local function Floors(first, last)
    local out={}
    for i=first,last do
        out[#out+1]={texture=ROOT.."BlackrockSpire"..i..".tga",texRight=1002/1024,texBottom=668/1024,name="Level "..(#out+1)}
    end
    return out
end
local MAPS = {
 ["Lower Blackrock Spire"] = {
    floors=Floors(1,6), entrance={floor=4,x=.368,y=.420,angle=0},
    bosses={
      Pin("Burning Felguard",4,.470,.350,"Rare summon from warlock portals; approximate source area"),
      Pin("Spirestone Butcher",3,.460,.589,"Rare; ogre-side approach to Omokk"),
      Pin("Highlord Omokk",3,.377,.587),
      Pin("Spirestone Battle Lord",3,.410,.630,"Rare; approximate ogre-hall area"),
      Pin("Spirestone Lord Magus",3,.355,.630,"Rare; approximate ogre-hall area"),
      Pin("Shadow Hunter Vosh'gajin",2,.543,.694),
      Pin("War Master Voone",1,.513,.546),
      Pin("Bannok Grimaxe",1,.580,.580,"Rare; approximate troll-hall area"),
      Pin("Mother Smolderweb",2,.605,.739),
      Pin("Crystal Fang",2,.645,.739,"Rare; spider area"),
      Pin("Urok Doomhowl",4,.443,.552,"Summoned tribute event on the upper bridge"),
      Pin("Quartermaster Zigris",5,.529,.846),
      Pin("Halycon",5,.371,.837),
      Pin("Gizrul the Slavener",5,.411,.837,"Appears after Halycon"),
      Pin("Ghok Bashguud",6,.460,.606,"Rare; approximate approach to Wyrmthalak"),
      Pin("Overlord Wyrmthalak",6,.562,.607),
      Pin("Mor Grayhoof",1,.550,.546,"Optional quest summon in Voone's room"),
    },
 },
 ["Upper Blackrock Spire"] = {
    floors=Floors(6,7), entrance={floor=1,x=.368,y=.420,angle=0},
    bosses={
      Pin("Pyroguard Emberseer",1,.324,.247),
      Pin("Solakar Flamewreath",2,.340,.266,"Father Flame event in the Rookery"),
      Pin("Jed Runewatcher",2,.370,.331,"Rare patrol; approximate Hall of Blackhand area"),
      Pin("Goraluk Anvilcrack",2,.326,.395),
      Pin("Gyth",2,.465,.253,"Shared stadium encounter"),
      Pin("Warchief Rend Blackhand",2,.505,.253,"Shared stadium encounter"),
      Pin("The Beast",2,.641,.313),
      Pin("General Drakkisath",2,.347,.498),
      Pin("Lord Valthalak",2,.676,.313,"Optional quest summon in the Beast's room"),
    },
 },
 ["Scholomance"] = {
    floors={{texture=ROOT.."ScholomanceParchment.tga",texRight=1002/1024,texBottom=668/1024}},
    entrance={floor=1,x=.300,y=.320,angle=180},
    bosses={
      Pin("Blood Steward of Kirtonos",1,.450,.317),
      Pin("Kirtonos the Herald",1,.279,.093,"Balcony summon: Blood of Innocents"),
      Pin("Jandice Barov",1,.800,.145,"Lower hall inset; stairs connect to the main entry section"),
      Pin("Rattlegore",1,.150,.460,"Lower ossuary"),
      Pin("Death Knight Darkreaver",1,.190,.510,"Optional paladin event; lower ossuary"),
      Pin("Marduk Blackpool",1,.270,.500,"Viewing Room"),
      Pin("Vectus",1,.325,.500,"Viewing Room"),
      Pin("Ras Frostwhisper",1,.187,.765,"Laboratory"),
      Pin("Kormok",1,.187,.810,"Optional quest summon in Ras Frostwhisper's room"),
      Pin("Instructor Malicia",1,.475,.860,"Upper level: southern room"),
      Pin("Doctor Theolen Krastinov",1,.591,.709,"Upper level: eastern room"),
      Pin("Lorekeeper Polkelt",1,.472,.556,"Upper level: northern room"),
      Pin("The Ravenian",1,.754,.838,"Lower level: southern room"),
      Pin("Lord Alexei Barov",1,.867,.699,"Lower level: eastern room"),
      Pin("Lady Illucia Barov",1,.756,.580,"Lower level: northern room"),
      Pin("Darkmaster Gandling",1,.770,.709,"Appears after the six final-room bosses"),
    },
 },
}
-- Blackrock Spire shares floor sheets across its two wings. Show only the
-- upper-wing rooms in UBRS; UV crops exclude LBRS's Chamber of Battle and title.
local upper = MAPS["Upper Blackrock Spire"]
local crops = {
    { left=.245, right=.445, top=.090, bottom=.470 },
    { left=.245, right=.705, top=.080, bottom=.560 },
}
for i,crop in ipairs(crops) do
    local floor = upper.floors[i]
    floor.texLeft = crop.left * 1002 / 1024
    floor.texRight = crop.right * 1002 / 1024
    floor.texTop = crop.top * 668 / 1024
    floor.texBottom = crop.bottom * 668 / 1024
    floor.aspect = (crop.right-crop.left)*1002 / ((crop.bottom-crop.top)*668)
end
for _,pin in ipairs(upper.bosses) do
    local crop = crops[pin.floor]
    pin.x = (pin.x-crop.left)/(crop.right-crop.left)
    pin.y = (pin.y-crop.top)/(crop.bottom-crop.top)
end
upper.entrance.x = (upper.entrance.x-crops[1].left)/(crops[1].right-crops[1].left)
upper.entrance.y = (upper.entrance.y-crops[1].top)/(crops[1].bottom-crops[1].top)
local function Register()
 for name,map in pairs(MAPS) do
    local dungeon=FDJ.DB and FDJ.DB[name]
    if dungeon then
      if name == "Upper Blackrock Spire" and ForeverDungeonJournalDB
          and ForeverDungeonJournalDB.ubrsWingCropVersion ~= 1 then
        if ForeverDungeonJournalDB.mapPinMoves then ForeverDungeonJournalDB.mapPinMoves[name] = nil end
        if ForeverDungeonJournalDB.mapFloors then ForeverDungeonJournalDB.mapFloors[name] = 1 end
        ForeverDungeonJournalDB.ubrsWingCropVersion = 1
      end
      if name == "Scholomance" and ForeverDungeonJournalDB
          and ForeverDungeonJournalDB.scholoParchmentVersion ~= 1 then
        if ForeverDungeonJournalDB.mapPinMoves then ForeverDungeonJournalDB.mapPinMoves[name] = nil end
        if ForeverDungeonJournalDB.mapFloors then ForeverDungeonJournalDB.mapFloors[name] = 1 end
        ForeverDungeonJournalDB.scholoParchmentVersion = 1
      end
      local byName={}
      for _,boss in ipairs(dungeon.bosses or {}) do byName[boss.name]=true end
      local pins={}
      for _,pin in ipairs(map.bosses) do
        if byName[pin.name] then pins[#pins+1]=pin end
      end
      FDJ.DUNGEON_MAPS[name]={floors=map.floors,bosses=pins,entrance=map.entrance}
    end
 end
end
local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",Register)
