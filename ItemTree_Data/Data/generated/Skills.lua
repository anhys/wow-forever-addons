-- ItemTree generated data. Do not edit.
-- Module: Skills | Build: 1.60.1.70707 | Baseline: 1.15.9.69722 | Generated: 2026-10-31T05:55:17Z | Pipeline: 0.1.0
-- skillLineId -> { n name, cat category (9 secondary, 11 profession), p parent, i iconFileDataID }
local _, ItemTree = ...
-- ItemTree_Data is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Data) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end
local Data = ItemTree.Data or {}
ItemTree.Data = Data
Data.modules = Data.modules or {}
Data.modules["Skills"] = function()
  return {[40]={cat=9,i=136242,n="Poisons"},[101]={cat=9,i=136235,n="Dwarven Racial"},[124]={cat=9,i=136235,n="Tauren Racial"},[125]={cat=9,i=136235,n="Orc Racial"},[126]={cat=9,i=136235,n="Night Elf Racial"},[129]={cat=9,i=135966,n="First Aid"},[142]={cat=9,i=136235,n="Survival"},[148]={cat=9,i=136235,n="Horse Riding"},[149]={cat=9,i=136235,n="Wolf Riding"},[150]={cat=9,i=136235,n="Tiger Riding"},[152]={cat=9,i=136235,n="Ram Riding"},[155]={cat=9,i=136235,n="Swimming"},[164]={cat=11,i=136241,n="Blacksmithing"},[165]={cat=11,i=136247,n="Leatherworking"},[171]={cat=11,i=136240,n="Alchemy"},[182]={cat=11,i=136246,n="Herbalism"},[185]={cat=9,i=133971,n="Cooking"},[186]={cat=11,i=136248,n="Mining"},[197]={cat=11,i=136249,n="Tailoring"},[202]={cat=11,i=136243,n="Engineering"},[220]={cat=9,i=136235,n="Racial - Undead"},[333]={cat=11,i=136244,n="Enchanting"},[356]={cat=9,i=136245,n="Fishing"},[393]={cat=11,i=134366,n="Skinning"},[533]={cat=9,i=136235,n="Raptor Riding"},[553]={cat=9,i=136235,n="Mechanostrider Piloting"},[554]={cat=9,i=136235,n="Undead Horsemanship"},[633]={cat=9,i=136058,n="Lockpicking"},[713]={cat=9,i=135997,n="Kodo Riding"},[733]={cat=9,n="Racial - Troll"},[753]={cat=9,n="Racial - Gnome"},[754]={cat=9,n="Racial - Human"},[762]={cat=9,i=132164,n="Riding"},[2937]={cat=11,i=136240,n="Alchemy",p=171},[2938]={cat=11,i=136241,n="Blacksmithing",p=164},[2939]={cat=9,i=133971,n="Cooking",p=185},[2940]={cat=11,i=136244,n="Enchanting",p=333},[2941]={cat=11,i=136243,n="Engineering",p=202},[2942]={cat=9,i=135966,n="First Aid",p=129},[2943]={cat=9,i=136245,n="Fishing",p=356},[2944]={cat=11,i=136246,n="Herbalism",p=182},[2945]={cat=11,i=136247,n="Leatherworking",p=165},[2946]={cat=11,i=136248,n="Mining",p=186},[2947]={cat=11,i=134366,n="Skinning",p=393},[2948]={cat=11,i=136249,n="Tailoring",p=197},[2980]={cat=9,i=136235,n="Skyborne Racial"},[2988]={cat=9,i=132273,n="Poisons",p=40},[3011]={cat=9,i=136235,n="Galestrider Riding"},[3012]={cat=9,i=135933,n="Comprehension"}}
end
