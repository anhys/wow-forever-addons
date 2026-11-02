-- ItemTree generated data. Do not edit.
-- Module: StaleAfter | Build: 1.60.1.70707 | Baseline: 1.15.9.69722 | Generated: 2026-10-31T05:55:17Z | Pipeline: 0.1.0
-- itemId -> { q = { questIds }, k = kind }: the quests after whose completion the item has no use left. k 1 a community claim shipped as predicted, k 2 a fact the owner verified.
-- From curated/stale_after.json, hand kept with its provenance in the pipeline; no text of any source is in it. See ItemTree-Data docs/data-format.md, StaleAfter.
local _, ItemTree = ...
-- ItemTree_Data is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Data) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end
local Data = ItemTree.Data or {}
ItemTree.Data = Data
Data.modules = Data.modules or {}
Data.modules["StaleAfter"] = function()
  return {[285356]={k=1,q={93963}}}
end
