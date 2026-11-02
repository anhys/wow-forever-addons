-- ItemTree generated data. Do not edit.
-- Module: ToolItems | Build: 1.60.1.70707 | Baseline: 1.15.9.69722 | Generated: 2026-10-31T05:55:17Z | Pipeline: 0.1.0
-- totemCategoryId -> {item ids of that totem category}, sorted (Data:ItemsWithTotemCategory)
local _, ItemTree = ...
-- ItemTree_Data is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Data) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end
local Data = ItemTree.Data or {}
ItemTree.Data = Data
Data.modules = Data.modules or {}
Data.modules["ToolItems"] = function()
  return {[2]={5175},[3]={5178},[4]={5176},[5]={5177},[12]={9149,13503},[14]={6219,282550},[15]={10498},[161]={260811},[162]={5956,281665,285280,285281},[165]={2901,6206,259229},[166]={7005,269716,287069},[373]={6218},[374]={6339},[375]={11130},[376]={11145},[377]={16207}}
end
