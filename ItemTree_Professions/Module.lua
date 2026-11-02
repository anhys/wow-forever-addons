-- The Professions module's namespace and its loaded hook (brief PR3).
--
-- Loaded by the client after Data\generated\Data.xml and Core\Professions.lua, so
-- ItemTree.ProfessionTracks and ItemTree.ProfessionsModel are there, and
-- before UI\Pane.lua, which fills in the pane table made here. It announces the module to the
-- core's loader (Core/Modules.lua) as it loads; the core's Modules.Load answers true once that has
-- happened, which is after this whole folder has run.
--
-- ItemTree.Professions = { tracks = the ProfessionTracks data, pane = the tab's pane, model = the
-- model (Core\Professions.lua, brief PR4), which Core/Keep.lua asks for the route's reagents,
-- craft = the band's Craft button (Core\Craft.lua, brief PR14), queue = the craft queue tray the
-- Create all button opens (UI\Queue.lua, brief PR18, loaded before this file) }.
local _, ItemTree = ...
-- ItemTree_Professions is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Modules) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end

local FOLDER = "ItemTree_Professions"

local Professions = {
  tracks = ItemTree.ProfessionTracks,
  pane = {},
  model = ItemTree.ProfessionsModel,
  craft = ItemTree.ProfessionsCraft,
  queue = ItemTree.ProfessionsQueue,
}
ItemTree.Professions = Professions

local Modules = ItemTree.Modules
if type(Modules) == "table" and type(Modules.Announce) == "function" then
  pcall(Modules.Announce, FOLDER, Professions)
end

-- The bags and the tooltip were painted before the route counted: once announced (so the stub's
-- Active() is true), Keep drops its scores and paints them again (brief PR4).
local model = Professions.model
if type(model) == "table" and type(model.Refresh) == "function" then
  pcall(model.Refresh)
end

return Professions
