-- ItemTree generated data. Do not edit.
-- Module: Recipes_393 | Build: 1.60.1.70707 | Baseline: 1.15.9.69722 | Generated: 2026-10-31T05:55:17Z | Pipeline: 0.1.0
-- Skill line 393: Skinning
-- Fields: n name, sl skillLine (absent on an item combine, which has no profession), src 'item' on an item combine, absent on a profession recipe, via {itemIds whose on use effect casts this} (item combines only), r minRank (absent when the rank is unknown), rs rankSource ('item' from the recipe item, 'ability' from SkillLineAbility; only with r), tl trivialLow, th trivialHigh, su skillUps, sup supercedes, re {{itemId, count}}, out {itemId, min, max}, en enchantId, eq {class, subclassMask, invTypeMask}, cd cooldownMs, ccd categoryCooldownMs, tools {totemCategoryIds}, toolItems {itemIds the recipe asks for by name, such as Flint and Tinder}, by {itemIds that teach this}
local _, ItemTree = ...
-- ItemTree_Data is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Data) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end
local Data = ItemTree.Data or {}
ItemTree.Data = Data
Data.modules = Data.modules or {}
Data.modules["Recipes_393"] = function()
  return {[1229517]={n="Camp Chair",out={279979,1,1},re={{2318,3},{4470,2}},sl=393,th=25,tl=20},[1262982]={by={273109},n="Trapper's Workbench",out={279938,1,1},r=300,re={{3575,1},{4234,4},{4470,2}},rs="item",sl=393,th=300,tl=300},[1262985]={by={273098},n="Field Guide",out={279969,1,1},r=140,re={{2319,3},{2321,1},{5784,2}},rs="item",sl=393,th=145,tl=140}}
end
