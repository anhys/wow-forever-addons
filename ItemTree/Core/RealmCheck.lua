-- The one live check a withheld item's page makes (brief D5): has anybody on this realm found
-- the item yet?
--
-- WoW Forever withholds an item's details until it has dropped for someone on the realm. The
-- client answers a load request for such an item with a failure, and for one somebody has found
-- with the item's own name. So one request, for the one item whose page the player opened, says
-- which: "Found on your realm." or "No one on your realm has found this item yet.", and
-- "Checking your realm" while the answer is on its way.
--
-- Hard rule: one request, for the one item the player opened, never for a list, never on hover
-- and never twice in a session. UI/InfoPanel.lua is the one caller, from the page it has just
-- drawn, and RealmCheck.state remembers every id it has asked about for the rest of the session,
-- so a redraw, a second visit or the answer's own redraw can never ask again.
--
-- The request is UI/Client.lua's own (ItemTree.RequestItemData) with opts.result, which skips the
-- Item mixin: on the forever branch a FAILED load clears the mixin's queued callbacks without
-- running them, so the mixin would say nothing at all for exactly the answer this is for. The
-- Discovery Miner's Client/Ask.lua documents the same gate: C_Item.IsItemDataCachedByID first,
-- which is free and local, then C_Item.RequestLoadItemDataByID once, then ITEM_DATA_LOAD_RESULT
-- (itemId, success), with GET_ITEM_INFO_RECEIVED as the fallback event. The client's name is read
-- only when the gate says the client holds the item or a load has just succeeded, never as a
-- probe on an uncached id, because such a read is itself believed to be a request.
--
-- A found item is noted by the collector through the path UI/CollectorHooks.lua already uses
-- (NoteItem), as a sighting on the realm. Nothing about the character, the realm or the account
-- is read or stored; RealmCheck.state lives in memory for the session and is never saved.
--
-- RealmCheck.Decide, RealmCheck.Outcome, RealmCheck.Line, RealmCheck.State and RealmCheck.Found
-- are pure and run under busted. Everything below the divider is guarded, so this file loads
-- with no WoW API present.
local _, ItemTree = ...

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local RealmCheck = {}
ItemTree.RealmCheck = RealmCheck

-- The states one id can be in for the session. nil means it has not been asked about.
RealmCheck.CHECKING = "checking"
RealmCheck.FOUND = "found"
RealmCheck.NOT_FOUND = "notFound"
-- Nothing could be asked (no client to ask), so there is no answer; kept so it is not tried again.
RealmCheck.UNKNOWN = "unknown"

-- The collector's word for how the item was met: the client named it and the player only saw it
-- named, so somebody on the realm found it (Core/Collector.lua DISCOVERY_HOW).
RealmCheck.HOW = "seen"

-- Seconds to wait for the answer before reading whatever the client holds. The request is never
-- repeated when it runs out.
RealmCheck.TIMEOUT = 10

-- id -> state, for this session only.
RealmCheck.state = RealmCheck.state or {}

local function named(name)
  return type(name) == "string" and name ~= ""
end

-- What to do when the page of a withheld item opens, given what this session already holds for
-- the id (a state or nil), the free cache gate's answer, and the name the client gives without
-- being asked (read only where the gate said the client holds the item). Pure.
--
--   "none"     this session has already asked, or answered: nothing is asked again
--   "found"    the client already holds the item with a name: found, and nothing is asked
--   "request"  send the one request
--
-- A gate that says the client holds the item while it gives no name is not trusted, and the id
-- is asked, once, the way the Discovery Miner's Ask.CacheDecision reads it.
function RealmCheck.Decide(held, cached, name)
  if held ~= nil then
    return "none"
  end
  if cached == true and named(name) then
    return "found"
  end
  return "request"
end

-- What an answer means. success is the flag the event carried (nil where it carried none, which
-- is read as a success because the item info arrived, and never as a failure). name is what the
-- client gave once the answer landed. Found needs both a success and a name. Pure.
function RealmCheck.Outcome(success, name)
  if success ~= false and named(name) then
    return RealmCheck.FOUND
  end
  return RealmCheck.NOT_FOUND
end

-- The sentence the page says for a state, or nil where it has nothing to say. Pure.
function RealmCheck.Line(state)
  if state == RealmCheck.CHECKING then
    return L["Checking your realm"]
  end
  if state == RealmCheck.FOUND then
    return L["Found on your realm."]
  end
  if state == RealmCheck.NOT_FOUND then
    return L["No one on your realm has found this item yet."]
  end
  return nil
end

-- The state this session holds for one id, or nil.
function RealmCheck.State(itemId)
  return RealmCheck.state[tonumber(itemId) or itemId]
end

-- Whether this session's check found the item. False, never nil.
function RealmCheck.Found(itemId)
  return RealmCheck.State(itemId) == RealmCheck.FOUND
end

-- Forgets every answer. For the specs; the client never calls it, because a session is the unit.
function RealmCheck.Reset()
  RealmCheck.state = {}
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

-- C_Item.IsItemDataCachedByID's answer: true, false, or nil on a client without the call.
local function isCached(itemId)
  local itemApi = rawget(_G, "C_Item")
  if type(itemApi) ~= "table" or type(itemApi.IsItemDataCachedByID) ~= "function" then
    return nil
  end
  local ok, cached = pcall(itemApi.IsItemDataCachedByID, itemId)
  if not ok then
    return nil
  end
  return cached == true
end

-- The client's name for the item, the modern call first and the older one second, each under
-- pcall. Only called where the client holds the item (see the file header).
local function clientName(itemId)
  local itemApi = rawget(_G, "C_Item")
  if type(itemApi) == "table" and type(itemApi.GetItemInfo) == "function" then
    local ok, name = pcall(itemApi.GetItemInfo, itemId)
    if ok and named(name) then
      return name
    end
  end
  local getItemInfo = rawget(_G, "GetItemInfo")
  if type(getItemInfo) == "function" then
    local ok, name = pcall(getItemInfo, itemId)
    if ok and named(name) then
      return name
    end
  end
  return nil
end

-- Writes the answer down, notes a found item with the collector, tells the data layer that what
-- the client can name has changed, and redraws.
local function settle(itemId, outcome, onChange)
  RealmCheck.state[itemId] = outcome
  if outcome == RealmCheck.FOUND then
    local hooks = ItemTree.CollectorHooks
    if type(hooks) == "table" and type(hooks.NoteItem) == "function" then
      pcall(hooks.NoteItem, itemId, RealmCheck.HOW)
    end
    local data = ItemTree.Data
    if type(data) == "table" and type(data.ResetEra) == "function" then
      pcall(data.ResetEra, data)
    end
  end
  if type(onChange) == "function" then
    pcall(onChange, itemId, outcome)
  end
  return outcome
end

-- Whether the build withholds the item, which is the only kind of item a check is for.
local function withheld(itemId)
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.IsUndiscovered) ~= "function" then
    return false
  end
  local ok, answer = pcall(data.IsUndiscovered, data, itemId)
  return ok and answer == true
end

-- Runs fn after seconds on a client with C_Timer, and not at all without one.
local function after(seconds, fn)
  local timer = rawget(_G, "C_Timer")
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    return false
  end
  return (pcall(timer.After, seconds, fn))
end

-- The check for the one item whose page just opened. Answers the state the id is now in, or nil
-- for an id that is not withheld. onChange(itemId, state) is called when the answer lands, which
-- may be straight away (the client already held the item) or later (the one request).
function RealmCheck.Start(itemId, onChange)
  local id = tonumber(itemId)
  if not id or not withheld(id) then
    return nil
  end
  local held = RealmCheck.state[id]
  local cached = nil
  local name = nil
  if held == nil then
    cached = isCached(id)
    if cached == true then
      name = clientName(id)
    end
  end
  local decision = RealmCheck.Decide(held, cached, name)
  if decision == "none" then
    return held
  end
  if decision == "found" then
    return settle(id, RealmCheck.FOUND, nil)
  end

  local request = ItemTree.RequestItemData
  if type(request) ~= "function" then
    RealmCheck.state[id] = RealmCheck.UNKNOWN
    return RealmCheck.UNKNOWN
  end
  RealmCheck.state[id] = RealmCheck.CHECKING
  local answered = false
  local function answer(_, success)
    if answered then
      return
    end
    answered = true
    local found = nil
    -- A load that succeeded, or an event that carried no flag, has put the item in the client,
    -- so its name can be read without asking anything. A timeout reads it only where the gate
    -- says the client holds the item.
    if success ~= false and isCached(id) ~= false then
      found = clientName(id)
    end
    settle(id, RealmCheck.Outcome(success, found), onChange)
  end
  local ok, made = pcall(request, id, answer, { result = true })
  if not ok or made ~= true then
    answered = true
    RealmCheck.state[id] = RealmCheck.UNKNOWN
    return RealmCheck.UNKNOWN
  end
  after(RealmCheck.TIMEOUT, function()
    answer(id, nil)
  end)
  return RealmCheck.state[id]
end

return RealmCheck
