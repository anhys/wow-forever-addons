-- ItemTree generated data. Do not edit.
-- Module: Toys | Build: 1.60.1.70707 | Baseline: 1.15.9.69722 | Generated: 2026-10-31T05:55:17Z | Pipeline: 0.1.0
-- itemId -> 1 for every item the client's Toy table (Toy.ItemID) names that this build lists: a toy (brief TF1). Core/Keep.lua Keep.IsToy asks the client's Toy Box first and reads this only where the client cannot answer (no Toy Box, a secret answer, an error). See itemtree_data/toys.py.
-- Brief TOY2: and every toy curated/server_toys.json names that this build lists, a toy the server alone knows (no ItemSparse or Toy table row), which Keep.IsToy takes as a toy where the Toy Box names none.
local _, ItemTree = ...
-- ItemTree_Data is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Data) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end
local Data = ItemTree.Data or {}
ItemTree.Data = Data
Data.modules = Data.modules or {}
Data.modules["Toys"] = function()
  return {[1973]=1,[13379]=1,[17712]=1,[17716]=1,[18660]=1,[21540]=1,[22728]=1,[221315]=1,[269900]=1,[270868]=1,[270870]=1,[276236]=1,[276242]=1,[276896]=1,[279471]=1,[279519]=1,[280612]=1,[280740]=1,[284164]=1,[286203]=1,[286573]=1,[288185]=1}
end
