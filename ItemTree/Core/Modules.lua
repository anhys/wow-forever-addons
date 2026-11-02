-- The generic on demand loader for ItemTree's optional addon folders (brief PR3).
--
-- A module is an addon folder of its own, LoadOnDemand and dependent on ItemTree, that the core
-- asks the client to load only when the player wants it. The first is ItemTree_Professions, the
-- Professions tab's code and data: a player who leaves the tab off pays nothing for it.
--
-- The shape follows Data:LoadOnDemand in Core/Data.lua, which does the same for ItemTree_Data:
--   Modules.Load(folder)          loads the folder once per session. C_AddOns.LoadAddOn first,
--                                 then the global LoadAddOn, each under pcall. Answers true only
--                                 once the folder has announced itself. A failure is final until
--                                 /reload, its reason is kept, and one plain chat line goes out.
--   Modules.Announce(folder, api) called by the folder's own code as it loads, handing over the
--                                 table the core talks to.
--   Modules.Loaded(folder)        whether the folder has announced.
--   Modules.Get(folder)           the announced table, or nil.
--   Modules.Failed(folder)        why the load failed, or nil. For /itemtree debug and reports,
--                                 never for the chat line, which names no internals.
--   Modules.Describe(folder, line) the chat line a failure of this folder prints.
--
-- The functions above the divider are pure over Modules.state and run under busted with no WoW
-- API. Modules.Try takes the loaders as an argument, so a spec hands it fakes.
local _, ItemTree = ...

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local Modules = {}
ItemTree.Modules = Modules

-- Per folder, for this session only (never saved): { api = the announced table, failed = the
-- reason a load failed, warned = true once the chat line went out }.
Modules.state = {}

-- The chat line each folder's failure prints, set by whoever registers the folder
-- (Modules.Describe). A folder with none gets Modules.GENERIC_FAILED_LINE with its name in it.
Modules.FAILED_LINES = {}
Modules.GENERIC_FAILED_LINE = L["The %s folder did not load. Install it beside ItemTree and enable it."]

local function validFolder(folder)
  return type(folder) == "string" and folder ~= ""
end

local function entry(folder)
  local state = Modules.state[folder]
  if not state then
    state = {}
    Modules.state[folder] = state
  end
  return state
end

--- Forgets every folder's state. For specs; the client never calls it.
function Modules.Reset()
  Modules.state = {}
end

--- A folder's own code calls this as it loads. api is the table the core talks to. Answers
--- whether it was taken. An announcement after a failed load (the client loaded the folder some
--- other way) counts: the folder is there.
function Modules.Announce(folder, api)
  if not validFolder(folder) or type(api) ~= "table" then
    return false
  end
  local state = entry(folder)
  state.api = api
  state.failed = nil
  return true
end

--- Whether the folder has announced itself this session.
function Modules.Loaded(folder)
  if not validFolder(folder) then
    return false
  end
  local state = Modules.state[folder]
  return state ~= nil and state.api ~= nil
end

--- The table the folder announced, or nil.
function Modules.Get(folder)
  if not validFolder(folder) then
    return nil
  end
  local state = Modules.state[folder]
  return state and state.api or nil
end

--- Why the folder's load failed this session, or nil while it has not.
function Modules.Failed(folder)
  if not validFolder(folder) then
    return nil
  end
  local state = Modules.state[folder]
  return state and state.failed or nil
end

--- Sets the chat line a failed load of this folder prints. Answers whether it was taken.
function Modules.Describe(folder, line)
  if not validFolder(folder) or type(line) ~= "string" or line == "" then
    return false
  end
  Modules.FAILED_LINES[folder] = line
  return true
end

--- The chat line a failed load of this folder prints: the one Describe set, or the generic line
--- with the folder's name. Plain words only; the reason is never in it. Pure.
function Modules.FailedLine(folder)
  local line = Modules.FAILED_LINES[folder]
  if type(line) == "string" and line ~= "" then
    return line
  end
  return string.format(Modules.GENERIC_FAILED_LINE, tostring(folder))
end

--- One load attempt with the loaders given, each a function(folder) answering loaded, reason as
--- the client's LoadAddOn does. Once per session: an announced folder answers true at once and a
--- failed one false with its reason, with no loader called. Answers loaded, reason.
function Modules.Try(folder, loaders)
  if not validFolder(folder) then
    return false, "no folder name"
  end
  if Modules.Loaded(folder) then
    return true
  end
  local state = entry(folder)
  if state.failed then
    return false, state.failed
  end
  local reason = "no LoadAddOn on this client"
  for _, load in ipairs(type(loaders) == "table" and loaders or {}) do
    local ok, loaded, why = pcall(load, folder)
    if ok and loaded then
      if Modules.Loaded(folder) then
        return true
      end
      reason = "loaded, but it did not announce itself"
      break
    end
    if ok then
      -- The client answered and said no; the older loader is the same call and would say it again.
      if type(why) == "string" and why ~= "" then
        reason = why
      else
        reason = "not loaded"
      end
      break
    end
    reason = "error: " .. tostring(loaded)
  end
  state.failed = reason
  return false, reason
end

--- Whether the chat line for this folder's failure is due: failed, and not yet printed. Pure.
function Modules.WarnDue(folder)
  if not validFolder(folder) then
    return false
  end
  local state = Modules.state[folder]
  return state ~= nil and state.failed ~= nil and not state.warned
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

--- The client's loaders for an addon by folder name: C_AddOns.LoadAddOn on the Forever client,
--- the global LoadAddOn on an older one.
function Modules.ClientLoaders()
  local out = {}
  local addOns = rawget(_G, "C_AddOns")
  if type(addOns) == "table" and type(addOns.LoadAddOn) == "function" then
    out[#out + 1] = addOns.LoadAddOn
  end
  local legacy = rawget(_G, "LoadAddOn")
  if type(legacy) == "function" then
    out[#out + 1] = legacy
  end
  return out
end

--- Prints the folder's failure line once per session, through DEFAULT_CHAT_FRAME. Answers
--- whether a line went out now.
function Modules.Warn(folder)
  if not Modules.WarnDue(folder) then
    return false
  end
  Modules.state[folder].warned = true
  local chat = rawget(_G, "DEFAULT_CHAT_FRAME")
  if type(chat) ~= "table" or type(chat.AddMessage) ~= "function" then
    return false
  end
  return (pcall(chat.AddMessage, chat, Modules.FailedLine(folder)))
end

--- Loads the folder once per session through the client. True once the folder has announced,
--- false when it could not be loaded, in which case the reason is kept (Modules.Failed) and the
--- one chat line is printed.
function Modules.Load(folder)
  if not validFolder(folder) then
    return false
  end
  if Modules.Loaded(folder) then
    return true
  end
  if Modules.Try(folder, Modules.ClientLoaders()) then
    return true
  end
  Modules.Warn(folder)
  return false
end

return Modules
