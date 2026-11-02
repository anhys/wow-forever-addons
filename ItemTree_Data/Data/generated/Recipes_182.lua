-- ItemTree generated data. Do not edit.
-- Module: Recipes_182 | Build: 1.60.1.70707 | Baseline: 1.15.9.69722 | Generated: 2026-10-31T05:55:17Z | Pipeline: 0.1.0
-- Skill line 182: Herbalism
-- Fields: n name, sl skillLine (absent on an item combine, which has no profession), src 'item' on an item combine, absent on a profession recipe, via {itemIds whose on use effect casts this} (item combines only), r minRank (absent when the rank is unknown), rs rankSource ('item' from the recipe item, 'ability' from SkillLineAbility; only with r), tl trivialLow, th trivialHigh, su skillUps, sup supercedes, re {{itemId, count}}, out {itemId, min, max}, en enchantId, eq {class, subclassMask, invTypeMask}, cd cooldownMs, ccd categoryCooldownMs, tools {totemCategoryIds}, toolItems {itemIds the recipe asks for by name, such as Flint and Tinder}, by {itemIds that teach this}
local _, ItemTree = ...
-- ItemTree_Data is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Data) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end
local Data = ItemTree.Data or {}
ItemTree.Data = Data
Data.modules = Data.modules or {}
Data.modules["Recipes_182"] = function()
  return {[1229705]={n="Incense Candle",out={279962,1,1},re={{765,1},{2447,1}},sl=182,th=25,tl=20},[1262980]={by={273106},n="Greenhouse",out={279964,1,1},r=140,re={{4470,2},{8831,1},{8836,1}},rs="item",sl=182,th=145,tl=140},[1263070]={by={273120},n="Seed Hybridizer",out={279947,1,1},r=300,re={{8925,1},{13465,4},{14047,2}},rs="item",sl=182,th=300,tl=300}}
end
