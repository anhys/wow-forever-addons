-- A LibDataBroker-1.1 launcher, so ItemTree shows in ElvUI style data bars and other broker
-- displays (brief LDB1, a player's request on 2026-10-12).
--
-- ItemTree ships no copy of the library: it states no licence (nothing in its file or README,
-- and its project page says All Rights Reserved). Every broker display brings its own copy and
-- registers it with LibStub, which is shared, so a display that loaded before PLAYER_LOGIN has
-- put it there by the time this runs. With no display installed the lookup answers nil and
-- nothing is registered and nothing is said.
--
-- One launcher named "ItemTree", registered once per session at the minimap button's login set
-- up (UI/Minimap.lua's loader calls DataBroker.Register). A left click runs the minimap button's
-- left click and a right click its right click (Minimap.LeftClick, Minimap.RightClick), and the
-- hover shows the button's title and two click lines (Minimap.TooltipLines), so the two ways in
-- never drift apart. The object lives only in the library's registry and on this module, never in
-- a global, and nothing here touches a client frame: the display owns the frame and the tooltip.
-- The minimap button, the compartment entry and the key binding are unchanged; a player who uses a
-- bar can hide the button with the existing "Show minimap button" setting.
--
-- DataBroker.Spec and DataBroker.DebugLine are pure and run under busted. Register is guarded,
-- so this file loads with no WoW API present.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local DataBroker = {}
ItemTree.UI.DataBroker = DataBroker

-- The name the display lists (ElvUI shows "LDB: ItemTree") and the library asked for.
DataBroker.NAME = "ItemTree"
DataBroker.LIBRARY = "LibDataBroker-1.1"

-- What Register found: nil until it has run, then "registered", "missing" (no display brought
-- the library) or "failed" (the library refused the object, for example a name already taken).
DataBroker.state = nil
DataBroker.object = nil

-- The minimap module, looked up at call time: the specs swap it, and the click actions are its.
local function minimap()
  local ui = ItemTree.UI
  local module = type(ui) == "table" and ui.Minimap or nil
  if type(module) == "table" then
    return module
  end
  return nil
end

--- The launcher's table, as handed to NewDataObject. `label` and `icon` are what the display
--- draws; `actions` is the minimap module (or a fake with LeftClick, RightClick and
--- TooltipLines), looked up when a click or hover happens when not given. Pure.
function DataBroker.Spec(label, icon, actions)
  local function source()
    return actions or minimap()
  end
  return {
    type = "launcher",
    label = label,
    icon = icon,
    OnClick = function(_, button)
      local module = source()
      if not module then
        return
      end
      if button == "LeftButton" and type(module.LeftClick) == "function" then
        module.LeftClick()
      elseif button == "RightButton" and type(module.RightClick) == "function" then
        module.RightClick()
      end
    end,
    OnTooltipShow = function(tooltip)
      local module = source()
      if not module or type(module.TooltipLines) ~= "function" then
        return
      end
      if type(tooltip) ~= "table" or type(tooltip.AddLine) ~= "function" then
        return
      end
      local title, left, right = module.TooltipLines()
      tooltip:AddLine(title)
      tooltip:AddLine(left, 1, 1, 1)
      tooltip:AddLine(right, 1, 1, 1)
    end,
  }
end

--- The /itemtree debug line for a Register state. Diagnostic, so not translated. Pure.
function DataBroker.DebugLine(state)
  if state == nil then
    state = DataBroker.state
  end
  if state == "registered" then
    return "broker: registered"
  elseif state == "missing" then
    return "broker: no broker display installed"
  elseif state == "failed" then
    return "broker: the library refused the launcher"
  end
  return "broker: not yet"
end

-- Client side. Guarded

local function iconPath()
  local assets = ItemTree.Assets
  if type(assets) ~= "table" or type(assets.Get) ~= "function" then
    return nil
  end
  local ok, entry = pcall(assets.Get, "MINIMAP_ICON")
  if ok and type(entry) == "table" then
    return entry.path
  end
  return nil
end

local function library()
  local libStub = rawget(_G, "LibStub")
  if type(libStub) ~= "table" and type(libStub) ~= "function" then
    return nil
  end
  local ok, lib = pcall(libStub, DataBroker.LIBRARY, true)
  if ok and type(lib) == "table" and type(lib.NewDataObject) == "function" then
    return lib
  end
  return nil
end

--- Registers the launcher with a broker display's copy of the library, once per session. A
--- second call registers nothing more and answers the first call's state.
function DataBroker.Register()
  if DataBroker.state ~= nil then
    return DataBroker.state
  end
  local lib = library()
  if not lib then
    DataBroker.state = "missing"
    return DataBroker.state
  end
  local ok, object = pcall(lib.NewDataObject, lib, DataBroker.NAME, DataBroker.Spec(DataBroker.NAME, iconPath()))
  if ok and object then
    DataBroker.object = object
    DataBroker.state = "registered"
  else
    DataBroker.state = "failed"
  end
  return DataBroker.state
end

return DataBroker
