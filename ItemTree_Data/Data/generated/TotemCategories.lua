-- ItemTree generated data. Do not edit.
-- Module: TotemCategories | Build: 1.60.1.70707 | Baseline: 1.15.9.69722 | Generated: 2026-10-31T05:55:17Z | Pipeline: 0.1.0
-- totemCategoryId -> name (the tool a recipe asks for, as the client names it)
-- Every category either build names, so a Diff row about a tool reads as a name too.
local _, ItemTree = ...
-- ItemTree_Data is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Data) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end
local Data = ItemTree.Data or {}
ItemTree.Data = Data
Data.modules = Data.modules or {}
Data.modules["TotemCategories"] = function()
  return {[2]="Earth Totem",[3]="Air Totem",[4]="Fire Totem",[5]="Water Totem",[12]="Philosopher's Stone",[14]="Arclight Spanner",[15]="Gyromatic Micro-Adjustor",[121]="Virtuoso Inking Set",[161]="Gnomish Army Knife",[162]="Blacksmith Hammer",[165]="Mining Pick",[166]="Skinning Knife",[167]="Hammer Pick",[168]="Bladed Pickaxe",[169]="Flint and Tinder",[238]="Jeweler's Tools",[363]="Skinning Knife",[364]="Great Mage Writings",[365]="Tinker Mage Writings",[366]="Archmage Writings",[367]="Elemental Totem",[371]="Putress' Diary",[372]="Putress' Diary Page",[373]="Runed Copper Rod",[374]="Runed Silver Rod",[375]="Runed Golden Rod",[376]="Runed Truesilver Rod",[377]="Runed Arcanite Rod",[380]="Test Totem Category - DO NOT USE"}
end
