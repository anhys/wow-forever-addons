-- ItemTree generated data. Do not edit.
-- Module: Recipes_356 | Build: 1.60.1.70707 | Baseline: 1.15.9.69722 | Generated: 2026-10-31T05:55:17Z | Pipeline: 0.1.0
-- Skill line 356: Fishing
-- Fields: n name, sl skillLine (absent on an item combine, which has no profession), src 'item' on an item combine, absent on a profession recipe, via {itemIds whose on use effect casts this} (item combines only), r minRank (absent when the rank is unknown), rs rankSource ('item' from the recipe item, 'ability' from SkillLineAbility; only with r), tl trivialLow, th trivialHigh, su skillUps, sup supercedes, re {{itemId, count}}, out {itemId, min, max}, en enchantId, eq {class, subclassMask, invTypeMask}, cd cooldownMs, ccd categoryCooldownMs, tools {totemCategoryIds}, toolItems {itemIds the recipe asks for by name, such as Flint and Tinder}, by {itemIds that teach this}
local _, ItemTree = ...
-- ItemTree_Data is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Data) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end
local Data = ItemTree.Data or {}
ItemTree.Data = Data
Data.modules = Data.modules or {}
Data.modules["Recipes_356"] = function()
  return {[1229745]={n="Fish Bowl",out={279967,1,1},re={{3371,1},{6291,1}},sl=356,th=20,tl=20},[1262990]={by={273141},n="Fishing Rack",out={279965,1,1},r=140,re={{4470,2},{8365,2},{8925,1}},rs="item",sl=356,th=145,tl=140},[1262998]={by={273119},n="Fishing Hut",out={279966,1,1},r=300,re={{4470,5},{14048,2},{273295,1}},rs="item",sl=356,th=300,tl=300}}
end
