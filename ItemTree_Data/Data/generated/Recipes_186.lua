-- ItemTree generated data. Do not edit.
-- Module: Recipes_186 | Build: 1.60.1.70707 | Baseline: 1.15.9.69722 | Generated: 2026-10-31T05:55:17Z | Pipeline: 0.1.0
-- Skill line 186: Mining
-- Fields: n name, sl skillLine (absent on an item combine, which has no profession), src 'item' on an item combine, absent on a profession recipe, via {itemIds whose on use effect casts this} (item combines only), r minRank (absent when the rank is unknown), rs rankSource ('item' from the recipe item, 'ability' from SkillLineAbility; only with r), tl trivialLow, th trivialHigh, su skillUps, sup supercedes, re {{itemId, count}}, out {itemId, min, max}, en enchantId, eq {class, subclassMask, invTypeMask}, cd cooldownMs, ccd categoryCooldownMs, tools {totemCategoryIds}, toolItems {itemIds the recipe asks for by name, such as Flint and Tinder}, by {itemIds that teach this}
local _, ItemTree = ...
-- ItemTree_Data is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Data) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end
local Data = ItemTree.Data or {}
ItemTree.Data = Data
Data.modules = Data.modules or {}
Data.modules["Recipes_186"] = function()
  return {[2657]={n="Smelt Copper",out={2840,1,1},re={{2770,1}},sl=186,th=70,tl=25},[2658]={n="Smelt Silver",out={2842,1,1},re={{2775,1}},sl=186,th=125,tl=100},[2659]={n="Smelt Bronze",out={2841,2,2},re={{2840,1},{3576,1}},sl=186,th=115,tl=65},[3304]={n="Smelt Tin",out={3576,1,1},re={{2771,1}},sl=186,th=75,tl=50},[3307]={n="Smelt Iron",out={3575,1,1},re={{2772,1}},sl=186,th=140,tl=130},[3308]={n="Smelt Gold",out={3577,1,1},re={{2776,1}},sl=186,th=185,tl=170},[3569]={n="Smelt Steel",out={3859,1,1},re={{3575,1},{3857,1}},sl=186,th=165,tl=165},[10097]={n="Smelt Mithril",out={3860,1,1},re={{3858,1}},sl=186,th=175,tl=175},[10098]={n="Smelt Truesilver",out={6037,1,1},re={{7911,1}},sl=186,th=230,tl=230},[14891]={n="Smelt Dark Iron",out={11371,1,1},re={{11370,8}},sl=186,th=230,tl=230},[16153]={n="Smelt Thorium",out={12359,1,1},re={{10620,1}},sl=186,th=250,tl=250},[22967]={n="Smelt Elementium",out={17771,1,1},re={{12360,10},{17010,1},{18562,1},{18567,3}},sl=186,th=320,tl=310},[1213638]={n="Smelt Obsidian-Infused Thorium Bar",out={234003,1,1},re={{12655,2},{22203,2}},sl=186,th=330,tl=315},[1230161]={n="Lodestone",out={279960,1,1},re={{2835,1},{2840,1}},sl=186,th=25,tl=20},[1249637]={n="Smelt Azerothium",out={249726,1,1},re={{3857,1},{249426,2}},sl=186,th=275,tl=275},[1262975]={by={273097},n="Rock Garden",out={279948,1,1},r=140,re={{2772,1},{2838,2},{2842,1}},rs="item",sl=186,th=145,tl=140},[1263071]={by={273122},n="Molten Foundry",out={279952,1,1},r=300,re={{6037,1},{12359,5},{12365,2}},rs="item",sl=186,th=300,tl=300},[1306126]={n="Smelt Heavy Thorium",out={251291,1,1},re={{248815,1}},sl=186,th=315,tl=300}}
end
