-- Brief OPT4: the one home of small helpers that several files had their own identical copy of.
-- Each function here replaced copies that were byte for byte (or in meaning) the same, and each
-- names the files that use it. A copy that differed in any way stayed in its own file, with a
-- comment there naming the shared one beside it.
--
-- Loaded straight after Core/Init.lua and Core/Guard.lua, before every other file of ours, so any
-- file may take what it needs from ItemTree.Util as it loads. The load on demand folders
-- (ItemTree_Professions) read it through the global ItemTree the same way.
--
-- Everything above the client side divider is pure and runs under busted with no WoW API.
local _, ItemTree = ...

local Util = {}
ItemTree.Util = Util

--------------------------------------------------------------------------------
-- Numbers
--------------------------------------------------------------------------------

-- value held between low and high. UI/Chain.lua, UI/Frame.lua, ItemTree_Professions UI/Bar.lua
-- and UI/Skin.lua.
function Util.Clamp(value, low, high)
  if value < low then
    return low
  end
  if value > high then
    return high
  end
  return value
end

-- The nearest whole number to a number or a numeric string, halves up, or nil.
-- UI/EditMode.lua and UI/Frame.lua.
function Util.Round(value)
  value = tonumber(value)
  if not value then
    return nil
  end
  return math.floor(value + 0.5)
end

-- A finite number or numeric string rounded down, or nil (NaN and the infinities too).
-- Core/Ledger.lua and Core/Places.lua.
function Util.Whole(value)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge or value == -math.huge then
    return nil
  end
  return math.floor(value)
end

-- Util.Whole when it is above 0, or nil. Core/Ledger.lua and Core/Places.lua.
function Util.Positive(value)
  value = Util.Whole(value)
  if value and value > 0 then
    return value
  end
  return nil
end

-- A positive whole number id from a number or a numeric string, as it is (never rounded), or
-- nil. Core/CreatureLookup.lua, Core/QuestFlags.lua and UI/ItemClick.lua.
function Util.PositiveId(value)
  local id = tonumber(value)
  if not id or id <= 0 or id ~= math.floor(id) then
    return nil
  end
  return id
end

-- tonumber with its one argument and nothing else (no base). ItemTree_Professions Core/Craft.lua,
-- Core/Professions.lua and UI/Queue.lua.
function Util.Number(value)
  return tonumber(value)
end

--------------------------------------------------------------------------------
-- Text
--------------------------------------------------------------------------------

-- A string with its leading and trailing white space taken off. Raises on a non string, as the
-- copies did. Core/Ledger.lua and UI/CollectorHooks.lua.
function Util.Trim(text)
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- The item id in an item link (or any text holding "item:<digits>"), or nil. No range check: an
-- "item:0" answers 0. UI/InfoPanel.lua and UI/QuestFlags.lua.
function Util.ItemIdFromLink(link)
  if type(link) ~= "string" then
    return nil
  end
  return tonumber(link:match("item:(%d+)"))
end

--------------------------------------------------------------------------------
-- Size, measured the way the client writes saved variables (Core/Ledger.lua Ledger.Serialise is
-- the model). Core/Ledger.lua, Core/Places.lua and Core/Collector.lua.
--------------------------------------------------------------------------------

-- A table's keys, sorted by type name first and then by value, so a mixed table sorts too.
function Util.SortedKeys(map)
  local keys = {}
  for key in pairs(map) do
    keys[#keys + 1] = key
  end
  table.sort(keys, function(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then
      return ta < tb
    end
    return a < b
  end)
  return keys
end

-- A key as the writer puts it: [12] for a number, ["name"] for anything else.
function Util.KeyText(key)
  if type(key) == "number" then
    return "[" .. tostring(key) .. "]"
  end
  return string.format("[%q]", tostring(key))
end

-- A value that is not a table as the writer puts it: a string quoted, anything else tostring.
function Util.ValueText(value)
  if type(value) == "string" then
    return string.format("%q", value)
  end
  return tostring(value)
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

-- A client global function by name, read with rawget, or nil when it is absent or not a
-- function. UI/BossLoot.lua, UI/Chain.lua, UI/Discoveries.lua, UI/Map.lua, UI/Tree.lua, the
-- owner's developer pane, and ItemTree_Professions Core/Craft.lua, UI/Pane.lua, UI/Queue.lua and
-- UI/Trainers.lua.
function Util.GlobalFn(name)
  local fn = rawget(_G, name)
  return type(fn) == "function" and fn or nil
end

-- Whether a frame takes a script handler of this name. A frame with no HasScript is taken to
-- (a spec's plain table); a HasScript that raises answers false. The frame must be a table.
-- UI/Chain.lua, UI/EditMode.lua, UI/Minimap.lua, UI/Tooltip.lua and ItemTree_Professions
-- UI/Pane.lua.
function Util.HasScript(frame, script)
  if type(frame.HasScript) ~= "function" then
    return true
  end
  local ok, has = pcall(frame.HasScript, frame, script)
  return ok and has and true or false
end

-- Brief SV1: whether ItemTree may read a value the client handed over. The Forever client
-- (1.60.1.70205) hands addon code "secret" values in combat, and a secret raises on any compare,
-- join, length, match or use as a table key from our (tainted) code; type() alone answers.
-- canaccessvalue is the client's own question for that, and Blizzard's chat filters ask it with
-- their callers' taint active (Blizzard_ChatFrameBase/Shared/ChatFrameFilters.lua:27-37, forever
-- branch). It is asked through askAccess, a function of ours, so the "immediate calling function"
-- it judges is ours and not pcall; issecretvalue is the fallback. The value is never compared,
-- joined, measured, printed or used as a key here: it is only handed to the client's function.
-- Every file of ours takes this as it loads; UI/Client.lua names it Client.CanRead as well.
--
-- The generated docs tag both functions SecretArguments = "AllowedWhenUntainted", which read at
-- its worst means they raise for any tainted caller. Trusting one that does would read every
-- client value as unreadable and turn the addon inert, so each is calibrated once a session, on
-- first use, against an ordinary string of ours: canaccessvalue is usable only if it answers a
-- clean true for it, issecretvalue only if it answers a clean false. With neither usable every
-- value reads as readable, which is the behaviour before this helper (fail open).
local function askAccess(check, value)
  return check(value)
end

local CALIBRATION_VALUE = "ItemTree secret value check"
local CHECKS = {
  { name = "canaccessvalue", ordinary = true },
  { name = "issecretvalue", ordinary = false },
}

-- The calibration for this session: { check = fn, ordinary = answer, name = ... } for the first
-- usable function, false where the client has one or both and neither is usable, "none" where it
-- has neither. nil until the first ask.
local calibration = nil

local function calibrate()
  local present = false
  for _, spec in ipairs(CHECKS) do
    local check = rawget(_G, spec.name)
    if type(check) == "function" then
      present = true
      local ok, answer = pcall(askAccess, check, CALIBRATION_VALUE)
      if ok and answer == spec.ordinary then
        return { check = check, ordinary = spec.ordinary, name = spec.name }
      end
    end
  end
  if present then
    return false
  end
  return "none"
end

local function calibrated()
  if calibration == nil then
    calibration = calibrate()
  end
  return calibration
end

function Util.CanRead(value)
  if type(value) == "nil" then
    return true
  end
  local live = calibrated()
  if type(live) ~= "table" then
    return true
  end
  local ok, answer = pcall(askAccess, live.check, value)
  return ok and answer == live.ordinary
end

-- Which secret check is live this session, for /itemtree debug: "canaccessvalue",
-- "issecretvalue", "none usable" (the client has one or both and each failed calibration) or
-- "none on this client" (Classic Era, busted). Calibrates if nothing has asked yet.
function Util.SecretCheck()
  local live = calibrated()
  if type(live) == "table" then
    return live.name
  end
  if live == false then
    return "none usable"
  end
  return "none on this client"
end

-- Specs only: forget the session's calibration, so a spec's fake client is calibrated afresh.
function Util.ResetSecretCheck()
  calibration = nil
end

-- One screen pixel in a frame's own units: the client's 768 unit tall screen over its real
-- height, then over the frame's effective scale. Nil where the client will not say (no
-- GetPhysicalScreenSize, no GetEffectiveScale, a raise, or an answer that is not a positive
-- number). UI/InfoPanel.lua (the scroll thumb's inset) and UI/Tooltip.lua (the divider rule's
-- height and offset, brief CS4); moved here from UI/InfoPanel.lua, the same formula, with a
-- frame that is not a table read as nothing.
function Util.ScreenPixel(frame)
  local physical = rawget(_G, "GetPhysicalScreenSize")
  if type(physical) ~= "function" or type(frame) ~= "table" or type(frame.GetEffectiveScale) ~= "function" then
    return nil
  end
  local ok, _, height = pcall(physical)
  local okScale, scale = pcall(frame.GetEffectiveScale, frame)
  height, scale = ok and tonumber(height), okScale and tonumber(scale)
  if not height or height <= 0 or not scale or scale <= 0 then
    return nil
  end
  return 768 / height / scale
end

-- The first answer of fn(...) under pcall, or nil when fn is not a function or raises.
-- UI/Overlay.lua (apiCall) and UI/Tooltip.lua (apiResult).
function Util.ApiResult(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if ok then
    return value
  end
  return nil
end
