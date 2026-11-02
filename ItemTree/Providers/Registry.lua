-- Source databases the player has installed as other addons, read at runtime.
--
-- The data ItemTree ships carries no world sources at all: no creature drops, no vendors, no
-- quest rewards, no gathering nodes. Importing them is a licence problem, so instead each
-- adapter under Providers/ reads a database that is already loaded in the player's client,
-- turns what it finds into graph edges, and ships none of it. Nothing is copied to disk and
-- nothing is written to saved variables.
--
-- The rules every adapter follows, which this file is what enforces:
--   * only item keys are answered; anything else bails before a single upstream call
--   * every upstream call is made under pcall, and the FIRST error disables that adapter for
--     the rest of the session and is remembered here rather than printed in a loop
--   * the answer for an item is worked out once and kept, because Graph.Children and
--     Graph.HasChildren both run every provider and Core/ViewModel.lua calls HasChildren once
--     per visible row, so anything but a table read would be paid on every keystroke
--   * no addon is ever loaded: detection asks whether it is already there and takes no for an
--     answer, because forcing a load on demand module is not ours to do
--   * the setting useProviders turns the whole layer off, and turning it off drops the caches
--
-- The adapter contract, which Providers/AllTheThings.lua and Providers/Questie.lua implement:
--   adapter.key            short stable key, also the edge provenance ("att", "questie")
--   adapter.label          the English wording and its own locale key, for the debug output
--   adapter.addon          the addon FOLDER name, which is what IsAddOnLoaded is asked about
--   adapter.Ready()        -> "absent" | "waiting" | "ready", detail. Never raises.
--   adapter.Edges(itemId)  -> list of edges for that item, in every direction, or nil
--   adapter.Fault()        -> the first upstream error, or nil
--   adapter.Reset()        -> drops whatever the adapter kept. Never clears the fault.
--   adapter.Hook(onReady)  -> optional. Installs the upstream ready hook. Returns true when it
--                             took, and is retried until it does.
--
-- Registry.Status, Registry.EdgesFor and Registry.Enabled are pure and run under busted with
-- no WoW API. Detection and the event frame are guarded below the divider.
local _, ItemTree = ...

local Graph = ItemTree.Graph
local Edges = ItemTree.Edges
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local Registry = {}
ItemTree.Providers = Registry

local EMPTY = {}

-- State per adapter key: what the last detection made of it and why.
--   absent    the addon is not loaded on this client, so nothing is ever called
--   waiting   the addon is there and its database is not ready yet
--   ready     answering
--   disabled  an upstream call raised, once, and this adapter is off for the session
Registry.ABSENT = "absent"
Registry.WAITING = "waiting"
Registry.READY = "ready"
Registry.DISABLED = "disabled"

-- Adapters in the order they are asked, which is the order their edges reach the graph.
Registry.adapters = {}

-- key -> { state, detail }
local status = {}
-- key -> itemId -> { up = {}, down = {} }
local cache = {}
-- key -> the function registered with Graph, so it can be taken back off again
local installed = {}

-- Whether the player wants this layer at all. A load with no settings table yet reads as on,
-- which is the default, so an adapter never goes quiet because the saved variables are late.
function Registry.Enabled()
  local settings = ItemTree.db and ItemTree.db.settings or nil
  if not settings then
    return true
  end
  return settings.useProviders ~= false
end

local function entry(key)
  local held = status[key]
  if not held then
    held = { state = Registry.ABSENT }
    status[key] = held
  end
  return held
end

-- Drops what every adapter has worked out so far. Called when the setting changes and when an
-- adapter's database says it has finished loading, because both change the answers.
function Registry.Reset()
  cache = {}
  for _, adapter in ipairs(Registry.adapters) do
    if type(adapter.Reset) == "function" then
      pcall(adapter.Reset)
    end
  end
end

-- One strike. The adapter is off for the session: the fault is kept so the debug output can
-- say what happened, and its cache is dropped so no half built answer is served.
function Registry.Disable(key, detail)
  local held = entry(key)
  held.state = Registry.DISABLED
  held.detail = detail and tostring(detail) or nil
  cache[key] = nil
end

-- What one adapter makes of itself right now, asked again on every detection. An adapter that
-- has already failed is never asked anything again.
function Registry.Refresh(adapter)
  local held = entry(adapter.key)
  if held.state == Registry.DISABLED then
    return held.state
  end
  local ok, state, detail = pcall(adapter.Ready)
  if not ok then
    Registry.Disable(adapter.key, state)
    return held.state
  end
  local was = held.state
  held.state = state or Registry.ABSENT
  held.detail = detail
  -- An adapter answers "absent" from the globals it can see, which is the honest test of whether
  -- it can read anything. The client knows something the globals do not, though: whether the
  -- addon folder is loaded at all. A folder that is loaded with nothing on the globals yet is
  -- waiting rather than missing, and the debug output should say which of the two it is.
  if held.state == Registry.ABSENT and adapter.addon and Registry.IsAddOnLoaded(adapter.addon) then
    held.state = Registry.WAITING
    held.detail = "addon loaded, nothing readable yet"
  end
  if held.state ~= Registry.READY and was == Registry.READY then
    -- A database that was answering and has stopped is a database that has been rebuilt under
    -- us, so nothing worked out against the old one is still worth keeping.
    cache[adapter.key] = nil
  end
  if held.state ~= Registry.ABSENT and type(adapter.Hook) == "function" and not held.hooked then
    local ok2, took = pcall(adapter.Hook, function()
      cache[adapter.key] = nil
      Registry.Refresh(adapter)
      Registry.Invalidate()
    end)
    if ok2 and took == true then
      held.hooked = true
    end
  end
  return held.state
end

-- Asks every adapter to look again. ADDON_LOADED and PLAYER_LOGIN both land here, because the
-- order addons load in is not ours to choose and a database is usually built well after its
-- own ADDON_LOADED.
function Registry.RefreshAll()
  for _, adapter in ipairs(Registry.adapters) do
    Registry.Refresh(adapter)
  end
  return Registry.Status()
end

-- Tells the rest of the addon that the answers have changed, so a cached count is rebuilt.
-- Core/ViewModel.lua's Reset is the documented way to drop the direction counts, and it drops
-- the profession lookup with them, both of which are rebuilt on the next refresh.
function Registry.Invalidate()
  local ViewModel = ItemTree.ViewModel
  if ViewModel and type(ViewModel.Reset) == "function" then
    pcall(ViewModel.Reset)
  end
end

local function splitByDirection(edges)
  local split = { up = {}, down = {} }
  for _, edge in ipairs(edges or EMPTY) do
    local def = edge.type
    if def and edge.target then
      local bucket = split[def.dir]
      if bucket then
        bucket[#bucket + 1] = edge
      end
    end
  end
  return split
end

-- The node kinds an adapter is ever asked about. An item is what a source database is indexed
-- by; a quest is the other end of a quest chain, which is what a player following Thunderfury
-- is actually walking. Everything else (a spell, a set, an enchant, a creature) is answered by
-- the data the addon ships, so a provider is never asked and never pays for the question.
Registry.KINDS = { item = true, quest = true }

-- Every edge one adapter has for one node, worked out once and then read back out of a table.
-- The upstream database is asked about the node as a whole and the two directions are split off
-- the one answer, so a row that asks "is there anything under this" and the row that draws its
-- children between them cost one upstream search, not two.
function Registry.EdgesFor(adapter, key, direction)
  local held = entry(adapter.key)
  if held.state ~= Registry.READY or not Registry.Enabled() then
    return EMPTY
  end
  local kind, id = Graph.Parse(key)
  if not Registry.KINDS[kind] or type(id) ~= "number" then
    return EMPTY
  end
  local split = (cache[adapter.key] or EMPTY)[key]
  if not split then
    local ok, edges = pcall(adapter.Edges, id, kind)
    if not ok then
      Registry.Disable(adapter.key, edges)
      return EMPTY
    end
    local fault = type(adapter.Fault) == "function" and adapter.Fault() or nil
    if fault then
      Registry.Disable(adapter.key, fault)
      return EMPTY
    end
    split = splitByDirection(edges)
    for _, edge in ipairs(edges or EMPTY) do
      if edge.provenance == nil then
        edge.provenance = adapter.key
      end
    end
    -- The cache table is read back rather than held across the call: an adapter is allowed to
    -- drop the caches from inside its own answer, which Providers/Questie.lua does the moment
    -- its reverse index finishes building, and the answer still belongs in the live table.
    local held_cache = cache[adapter.key]
    if not held_cache then
      held_cache = {}
      cache[adapter.key] = held_cache
    end
    held_cache[key] = split
  end
  if direction == Edges.DOWN then
    return split.down
  end
  return split.up
end

-- The provider function one adapter is registered with. Bails on any node kind an adapter has
-- nothing to say about before it touches the upstream addon at all, which is most of what the
-- graph asks about.
function Registry.Provider(adapter)
  return function(key, direction)
    if not Registry.Enabled() then
      return EMPTY
    end
    if entry(adapter.key).state ~= Registry.READY then
      return EMPTY
    end
    if not Registry.KINDS[Graph.Kind(key)] then
      return EMPTY
    end
    return Registry.EdgesFor(adapter, key, direction)
  end
end

-- Adds an adapter and registers its provider with the graph. Safe to call twice: the previous
-- registration is replaced rather than stacked, the way Core/Collector.lua's Install is.
function Registry.Add(adapter)
  if type(adapter) ~= "table" or type(adapter.key) ~= "string" then
    return nil
  end
  Registry.Remove(adapter.key)
  Registry.adapters[#Registry.adapters + 1] = adapter
  entry(adapter.key).state = Registry.ABSENT
  local provider = Registry.Provider(adapter)
  installed[adapter.key] = provider
  Graph.RegisterProvider(provider)
  return provider
end

function Registry.Remove(key)
  for index = #Registry.adapters, 1, -1 do
    if Registry.adapters[index].key == key then
      table.remove(Registry.adapters, index)
    end
  end
  if installed[key] then
    Graph.UnregisterProvider(installed[key])
    installed[key] = nil
  end
  status[key] = nil
  cache[key] = nil
end

function Registry.Clear()
  for index = #Registry.adapters, 1, -1 do
    Registry.Remove(Registry.adapters[index].key)
  end
  Registry.adapters = {}
  status = {}
  cache = {}
  installed = {}
end

-- Whether one adapter's provider is registered with the graph right now. Read back the way
-- Core/Collector.lua's Installed is, because a registration that did not land looks exactly
-- like a database with nothing in it.
function Registry.Installed(key)
  local provider = installed[key]
  return provider ~= nil and Graph.HasProvider(provider) == true
end

-- One row per adapter for the debug output: { key, label, state, detail }. label is translated
-- here rather than at the printer, so every caller says the same words.
function Registry.Status()
  local out = {}
  for _, adapter in ipairs(Registry.adapters) do
    local held = entry(adapter.key)
    out[#out + 1] = {
      key = adapter.key,
      label = L[adapter.label],
      state = held.state,
      detail = held.detail,
      installed = Registry.Installed(adapter.key),
    }
  end
  return out
end

-- One line per adapter, for UI/Slash.lua and the report window. No printing and no WoW API:
-- "Provider att (All The Things): ready" and "Provider questie (Questie): absent".
function Registry.StatusLines()
  local lines = {}
  if not Registry.Enabled() then
    lines[#lines + 1] = "Providers: off (useProviders)"
  end
  for _, row in ipairs(Registry.Status()) do
    local line = string.format("Provider %s (%s): %s", row.key, tostring(row.label), row.state)
    if not row.installed then
      line = line .. ", not registered"
    end
    if row.detail then
      line = line .. ", " .. tostring(row.detail)
    end
    lines[#lines + 1] = line
  end
  if #lines == 0 then
    lines[#lines + 1] = "Providers: none loaded"
  end
  return lines
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- Whether an addon folder is loaded, without ever asking for it to be loaded. C_AddOns is the
-- modern shape and IsAddOnLoaded the classic one; both are tried under pcall because the beta
-- client is retail shaped in places and Classic shaped in others.
function Registry.IsAddOnLoaded(name)
  local addons = rawget(_G, "C_AddOns")
  if type(addons) == "table" and type(addons.IsAddOnLoaded) == "function" then
    local ok, loaded = pcall(addons.IsAddOnLoaded, name)
    if ok then
      return loaded and true or false
    end
  end
  local classic = rawget(_G, "IsAddOnLoaded")
  if type(classic) == "function" then
    local ok, loaded = pcall(classic, name)
    if ok then
      return loaded and true or false
    end
  end
  return false
end

-- Detection is retried on ADDON_LOADED and PLAYER_LOGIN. Load order is not ours to choose and
-- a source database is usually compiled well after the addon that holds it has loaded, so one
-- look at load time would have most players see nothing at all.
local createFrame = rawget(_G, "CreateFrame")
if type(createFrame) == "function" then
  local frame = createFrame("Frame")
  frame:RegisterEvent("ADDON_LOADED")
  frame:RegisterEvent("PLAYER_LOGIN")
  frame:SetScript("OnEvent", function()
    pcall(Registry.RefreshAll)
  end)
end

return Registry
