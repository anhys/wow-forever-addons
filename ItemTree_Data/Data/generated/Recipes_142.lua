-- ItemTree generated data. Do not edit.
-- Module: Recipes_142 | Build: 1.60.1.70707 | Baseline: 1.15.9.69722 | Generated: 2026-10-31T05:55:17Z | Pipeline: 0.1.0
-- Skill line 142: Survival
-- Fields: n name, sl skillLine (absent on an item combine, which has no profession), src 'item' on an item combine, absent on a profession recipe, via {itemIds whose on use effect casts this} (item combines only), r minRank (absent when the rank is unknown), rs rankSource ('item' from the recipe item, 'ability' from SkillLineAbility; only with r), tl trivialLow, th trivialHigh, su skillUps, sup supercedes, re {{itemId, count}}, out {itemId, min, max}, en enchantId, eq {class, subclassMask, invTypeMask}, cd cooldownMs, ccd categoryCooldownMs, tools {totemCategoryIds}, toolItems {itemIds the recipe asks for by name, such as Flint and Tinder}, by {itemIds that teach this}
local _, ItemTree = ...
-- ItemTree_Data is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Data) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end
local Data = ItemTree.Data or {}
ItemTree.Data = Data
Data.modules = Data.modules or {}
Data.modules["Recipes_142"] = function()
  return {[7359]={ccd=300000,n="Bright Campfire",re={{4470,1}},sl=142,th=135,tl=85,toolItems={4471}}}
end
