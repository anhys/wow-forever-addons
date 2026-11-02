-- Forever's own vendors, out of the client's CollectableSource tables (brief V1). Pure Lua above
-- the divider at the foot, where the one client read (an area's name the Classic Era table does
-- not carry) is guarded.
-- Loaded as: local _, ItemTree = ...
--
-- The pipeline ships them as the load on demand module ForeverVendors (ItemTree-Data
-- docs/vendors.md is the contract, and the pipeline owns it):
--
--   { v = { [npcId] = { n = nameIndex or nil, m = mapId, a = areaId or nil, x = 0 to 1, y = 0 to 1 } },
--     i = { [itemId] = { npcId, ... } },   -- {} = sold by a vendor the client does not name yet
--     s = { "vendor name", ... } }
--
-- It is the client's own statement, not a guess, so every edge here is the "mined" tier ("From
-- client data"), above the Classic Era vendor rows and with no Predicted badge. The provider
-- answers:
--
--   item:<id>  up    SOLD_BY  one row per vendor npc the client names for the item, pointing at
--                             npc:<id>; or, for an empty list, one row that names no vendor
--   npc:<id>   down  SELLS    what one of those vendors sells, for its page's Sells tab
--
-- Shadowing. A client row points at the vendor's real npc key, so a Classic Era vendor row of the
-- same name is dropped by Core/Graph.lua's own dedupe (dropShadowed) the moment anything names
-- that key: the collector puts the name of every npc the player bought from on the graph. A
-- vendor nobody has named yet names nothing, so the Era rows stay beside it.
--
-- Load on demand. The module is built on the first ask for an item's Sold by rows or an npc
-- page (Data:Get, which lets the loader go afterwards), never at login and never for a tooltip:
-- the provider is registered where Graph.Summary skips it (it answers no quest, the only thing
-- Summary counts off a provider). The reverse index (npc to items) is built only for a vendor
-- page, once per module table.
local _, ItemTree = ...

local Data = ItemTree.Data
local Edges = ItemTree.Edges
local Graph = ItemTree.Graph
local Confidence = ItemTree.Confidence
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local T = Edges.Types
local EMPTY = {}

local ForeverVendors = {}
ItemTree.ForeverVendors = ForeverVendors

ForeverVendors.MODULE = "ForeverVendors"
-- The provenance every edge carries. Core/Sources.lua words it (Sources.PROVENANCE.client).
ForeverVendors.PROVENANCE = "client"

-- The node the one row of an item the client sells from an unnamed vendor points at. Positive and
-- far above any creature id a build carries, and below the Merchant's Favor range
-- (Core/Sources.lua Favour.NPC_BASE), so it is nobody's page; the row is a summary and never opens.
ForeverVendors.UNNAMED_ID = 899999999
ForeverVendors.UNNAMED_KEY = "npc:899999999"

-- How many times the reverse index was built, for the spec that pins it to vendor pages alone.
ForeverVendors.reverseBuilds = 0

--------------------------------------------------------------------------------
-- The module
--------------------------------------------------------------------------------

-- The module table, built on this first ask (Data:Get loads ItemTree_Data if it must), or nil for
-- a build that ships none. ForeverVendors.source states one for a spec.
function ForeverVendors.Table()
  if type(ForeverVendors.source) == "table" then
    return ForeverVendors.source
  end
  if type(Data) ~= "table" or type(Data.Get) ~= "function" then
    return nil
  end
  local ok, table_ = pcall(Data.Get, Data, ForeverVendors.MODULE)
  if ok and type(table_) == "table" then
    return table_
  end
  return nil
end

-- The module table only where it is already built, or nil: what the namer reads, so asking a node
-- its name never loads anything.
function ForeverVendors.Loaded()
  if type(ForeverVendors.source) == "table" then
    return ForeverVendors.source
  end
  local cache = type(Data) == "table" and Data.cache or nil
  local held = type(cache) == "table" and cache[ForeverVendors.MODULE] or nil
  return type(held) == "table" and held or nil
end

-- Whether the module table is built. False, never nil.
function ForeverVendors.IsLoaded()
  return ForeverVendors.Loaded() ~= nil
end

-- The npc id a key names, where it is a real one (positive, not the unnamed row's), or nil.
local function npcIdOf(key)
  local kind, id = Graph.Parse(key)
  if kind ~= "npc" or type(id) ~= "number" or id <= 0 or id == ForeverVendors.UNNAMED_ID then
    return nil
  end
  return id
end

-- The vendor list one item has in a module table: a list of npc ids, an empty list for a vendor
-- the client does not name yet, or nil for an item the client names no vendor for. Pure.
function ForeverVendors.VendorsOf(source, itemId)
  local items = type(source) == "table" and source.i or nil
  local list = type(items) == "table" and items[itemId] or nil
  if type(list) ~= "table" then
    return nil
  end
  return list
end

-- One vendor's record in a module table, or nil. Pure.
function ForeverVendors.VendorAt(source, npcId)
  local vendors = type(source) == "table" and source.v or nil
  local vendor = type(vendors) == "table" and vendors[npcId] or nil
  if type(vendor) ~= "table" then
    return nil
  end
  return vendor
end

-- The name the module itself states for a vendor (its n into s), or nil. The build's Creature
-- table names none of the 158 today, so this is nil for every one of them until it does. Pure.
function ForeverVendors.ModuleName(source, npcId)
  local vendor = ForeverVendors.VendorAt(source, npcId)
  local strings = type(source) == "table" and source.s or nil
  local index = vendor and vendor.n or nil
  local name = type(strings) == "table" and type(index) == "number" and strings[index] or nil
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return name
end

-- npc id to the item ids it sells, ascending, over the whole i in one pass: the Sells tab of a
-- client vendor. Pure over the table handed in.
function ForeverVendors.ReverseIndex(source)
  local out = {}
  local items = type(source) == "table" and source.i or nil
  for itemId, list in pairs(type(items) == "table" and items or EMPTY) do
    if type(itemId) == "number" and type(list) == "table" then
      for _, npcId in ipairs(list) do
        if type(npcId) == "number" then
          local held = out[npcId] or {}
          out[npcId] = held
          held[#held + 1] = itemId
        end
      end
    end
  end
  for _, held in pairs(out) do
    table.sort(held)
  end
  return out
end

local reverseFor, reverseOf = nil, nil

-- The reverse index, built once per module table and kept, or nil where no module ships. Only a
-- vendor page asks for it.
function ForeverVendors.Reverse()
  local source = ForeverVendors.Table()
  if not source then
    return nil
  end
  if reverseFor ~= source then
    reverseOf = ForeverVendors.ReverseIndex(source)
    reverseFor = source
    ForeverVendors.reverseBuilds = ForeverVendors.reverseBuilds + 1
  end
  return reverseOf
end

-- Drops the kept reverse index and the zone words (a spec that swaps the table).
function ForeverVendors.Reset()
  reverseFor, reverseOf = nil, nil
  ForeverVendors.zoneWords = {}
  ForeverVendors.reverseBuilds = 0
end

--------------------------------------------------------------------------------
-- Names
--------------------------------------------------------------------------------

-- "Vendor (npc 252000)": what a vendor nobody has named is called. Pure.
function ForeverVendors.Label(npcId)
  return string.format(L["Vendor (npc %d)"], math.floor(tonumber(npcId) or 0))
end

-- The collector instance, or nil.
local function collector()
  local instance = ItemTree.collector
  if type(instance) ~= "table" then
    return nil
  end
  return instance
end

local function ask(instance, method, ...)
  if type(instance) ~= "table" or type(instance[method]) ~= "function" then
    return nil
  end
  local ok, answer = pcall(instance[method], instance, ...)
  if not ok then
    return nil
  end
  return answer
end

-- The Merchant's Favor vendor the curated tier ships under this very npc id, by name, or nil.
local function favourName(npcId)
  local sources = ItemTree.Sources
  local favour = type(sources) == "table" and sources.Favour or nil
  if type(favour) ~= "table" or type(favour.Index) ~= "function" then
    return nil
  end
  local ok, index = pcall(favour.Index)
  local vendor = ok and type(index) == "table" and index.byNode[Graph.Key("npc", npcId)] or nil
  if type(vendor) ~= "table" or vendor.npc ~= npcId or type(vendor.name) ~= "string" or vendor.name == "" then
    return nil
  end
  return vendor.name
end

-- Brief F169: the name the graph holds for npc:<id> (Graph.Name, the breadcrumb's own lookup), or
-- nil. Builds nothing: every namer it asks reads a module already built.
local function graphName(npcId)
  if type(Graph.Name) ~= "function" then
    return nil
  end
  local ok, name = pcall(Graph.Name, Graph.Key("npc", npcId))
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- Brief F169: the Creatures data's name for a creature id (Core/Creatures.lua Name, which builds
-- that module on the first ask, as the vendor page's own tabs already do), or nil.
local function creaturesName(npcId)
  local creatures = ItemTree.Creatures
  if type(creatures) ~= "table" or type(creatures.Name) ~= "function" then
    return nil
  end
  local ok, name = pcall(creatures.Name, npcId)
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- The name one client vendor is known by, or nil, in the brief's order: the collector's records
-- (a visit stored the client's name for that id, Core/Collector.lua C:VendorName), then any other
-- local record naming that id (the curated Merchant's Favor file, the module's own n). Never a fan
-- page and never a guess. source is the module table, or nil to read the one already built.
--
-- Brief F169 (owner QA 2026-10-14 item 169: Jason Stonepike 247216's panel header read "Vendor (npc
-- 247216)" under a breadcrumb that named him): then the name the breadcrumb and the window title
-- read for the same key (Core/Graph.lua Graph.Name: what the collector and the client's lookup put
-- on the graph, then the namers, the Creatures data's among them), and last the Creatures data
-- itself (Core/Creatures.lua Name), because its namer reads only a module already built and a
-- vendor page may ask this before anything built it. The Creatures data names every one of the
-- Northshire trainers who sell their trade's tools; the module's own n names none of them.
function ForeverVendors.Name(npcId, source)
  if type(npcId) ~= "number" then
    return nil
  end
  local name = ask(collector(), "VendorName", npcId)
  if type(name) == "string" and name ~= "" then
    return name
  end
  name = favourName(npcId)
  if name then
    return name
  end
  name = ForeverVendors.ModuleName(source or ForeverVendors.Loaded(), npcId)
  if name then
    return name
  end
  -- Brief VN1: last, the Classic Era name of this very creature id (ForeverVendors.EraName).
  return graphName(npcId) or creaturesName(npcId) or ForeverVendors.EraName(npcId)
end

-- The namer registered with the graph: the unnamed row's words, and a name the module itself
-- states. Only a table already built is read, so a node asked its name never loads the module;
-- the collector puts its own names on the graph itself. Brief VN1: a vendor the module lists and
-- names nowhere reads its Classic Era name, once every module that might name it is built.
function ForeverVendors.Namer(key)
  if key == ForeverVendors.UNNAMED_KEY then
    return L["Sold by a vendor (not yet named by the client)"]
  end
  local npcId = npcIdOf(key)
  if not npcId then
    return nil
  end
  local source = ForeverVendors.Loaded()
  local name = ForeverVendors.ModuleName(source, npcId)
  if name or not ForeverVendors.VendorAt(source, npcId) then
    return name
  end
  return ForeverVendors.EraName(npcId, true)
end

--------------------------------------------------------------------------------
-- A vendor only the Classic Era table names (brief VN1)
--------------------------------------------------------------------------------

-- Brief VN1 (owner QA 2026-10-17 item 214): 66 vendors the client's own tables list read "Vendor
-- (npc N)" on the shipped 1.60.1.70425 data (Vernon Hale 1678 on Fishing Pole, Corporal Bluth 734),
-- and the row opened a page of its own beside the vendor's Classic Era page (npc:-1678). Nothing of
-- Forever's names them (the module's n, the Creatures data, the player module, the collector, the
-- Merchant's Favor file), but the shipped Classic Era table names that very creature id (ci), as it
-- did for brief SD1's player vendors. SD1's fallback was wired into Core/PlayerSources.lua alone (its
-- rows and its namer, for the npcs the player module states), and this file's namer read the
-- module's own n, which names none of the 66: so no route reached the Classic Era name. Now the row
-- and the page read it, so Core/Graph.lua's shadow rule folds the Classic Era row of the same vendor
-- into the client row (its title and side), Graph.NpcSide joins the name's side, and the page
-- (npc:<id>) joins the name's Classic Era page (E:NpcNameAt: its Sells, Map and portrait) beside the
-- client's own Sells rows, the one page both open (ForeverVendors.OpenKey). Our own data only.

-- One guarded call: fn's first answer where fn is a function and does not raise, else nil.
local function call(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, answer = pcall(fn, ...)
  if ok then
    return answer
  end
  return nil
end

local function isName(name)
  return type(name) == "string" and name ~= ""
end

-- Whether the player module may name an npc id (its own n, built on this ask). With builtOnly a
-- module that ships and is not built yet answers true, because it might: a namer's answer is kept
-- for the session (Graph.names), so it must never stand where the module's name is due.
local function playersMayName(npcId, builtOnly)
  local players = ItemTree.PlayerSources
  if type(players) ~= "table" then
    return false
  end
  local source = call(builtOnly and players.Loaded or players.Table)
  if source == nil and builtOnly then
    local held = type(Data) == "table" and type(Data.cache) == "table" and Data.cache[players.MODULE] or nil
    return held == nil
      and type(players.MODULE) == "string"
      and (call(Data.Has, Data, players.MODULE) == true or call(Data.IsOnDemand, Data, players.MODULE) == true)
  end
  return source ~= nil and isName(call(players.ModuleName, source, "npc", npcId))
end

--- Brief VN1: the Classic Era name of a client vendor's own creature id, where nothing of Forever's
--- or the player's own names it (the collector's visit, the Merchant's Favor file, the player module,
--- then through PlayerSources.FallbackName the Creatures data and this module's n), or nil. builtOnly
--- reads modules already built only (the namer). Guarded.
function ForeverVendors.EraName(npcId, builtOnly)
  if type(npcId) ~= "number" or npcId <= 0 or npcId == ForeverVendors.UNNAMED_ID then
    return nil
  end
  local players = ItemTree.PlayerSources
  if type(players) ~= "table" or type(players.FallbackName) ~= "function" then
    return nil
  end
  if isName(ask(collector(), "VendorName", npcId)) or favourName(npcId) or playersMayName(npcId, builtOnly) then
    return nil
  end
  local name = call(players.FallbackName, npcId, builtOnly)
  if isName(name) then
    return name
  end
  return nil
end

-- The Classic Era name and its string index of a creature id, where the shown name is that very
-- name (any case), or nil: a Forever name of its own that is not that name is another creature as
-- far as we know (PlayerSources.EraSide's rule).
local function eraNameShown(npcId, shown)
  local players = ItemTree.PlayerSources
  if not isName(shown) or type(players) ~= "table" or type(players.EraCreature) ~= "function" then
    return nil
  end
  local ok, name, nameIndex = pcall(players.EraCreature, npcId)
  if not ok or not isName(name) or name:lower() ~= shown:lower() then
    return nil
  end
  return name, nameIndex
end

--- Brief VN1: the client's Sold by edges with their vendors named and titled from the Classic Era
--- table: an npc nothing names gets its Classic Era name on the graph (ForeverVendors.EraName, which
--- builds what it reads, as Core/PlayerSources.lua's rows do), and a row whose npc reads its own id's
--- Classic Era name takes that vendor's title where it states none, so a row of stock the Classic Era
--- table never listed still reads "Vernon Hale <Bait and Tackle Supplier>". The zone stays the
--- client's. The edges are the ones handed in, changed in place. Guarded.
function ForeverVendors.WithEraNames(edges)
  local era, EraSources = ItemTree.eraSources, ItemTree.EraSources
  for _, edge in ipairs(type(edges) == "table" and edges or EMPTY) do
    local npcId = type(edge) == "table" and npcIdOf(edge.target) or nil
    if npcId then
      if Graph.names[edge.target] == nil and Graph.Name(edge.target) == nil then
        local name = ForeverVendors.EraName(npcId)
        if name then
          Graph.SetName(edge.target, name)
        end
      end
      local _, nameIndex = eraNameShown(npcId, Graph.Name(edge.target))
      if nameIndex and edge.title == nil and type(era) == "table" and type(EraSources) == "table" then
        local title = call(EraSources.Title, ask(era, "Table"), nameIndex)
        if isName(title) then
          edge.title = title
        end
      end
    end
  end
  return edges
end

-- Brief VN1: puts a client vendor's Classic Era name on the graph where nothing names its page yet
-- (ForeverVendors.EraName, which builds what it reads), so the page joins the Classic Era page of
-- that name however it was opened (a row, the Recently viewed list, a breadcrumb). Answers the name
-- the page reads, or nil.
local function namePage(npcId, key)
  local shown = Graph.Name(key)
  if shown == nil then
    shown = ForeverVendors.EraName(npcId)
    if shown then
      Graph.SetName(key, shown)
    end
  end
  return shown
end

--- Brief VN1: the key a window open lands on, for the one page of a vendor the client's tables
--- list under its Classic Era name. A Classic Era key of that creature, its page (npc:-<id>,
--- EraSources.PageId) or one of its rows in a place (EraSources.PlacedId), opens the client's page
--- npc:<id> instead, which reads the same name and so joins every tab the Classic Era page has
--- (E:NpcNameAt) beside the client's own Sells rows and pin; the client's page itself is named
--- before it is drawn. Any other key, and a creature whose client page reads another name or none,
--- is answered as it is. Loads the module (an npc page is one of its first needs) for an npc key
--- only. What UI/Frame.lua Open asks of every key it opens. Guarded.
function ForeverVendors.OpenKey(key)
  local kind, id = Graph.Parse(key)
  local EraSources = ItemTree.EraSources
  if kind ~= "npc" or type(id) ~= "number" or id == 0 then
    return key
  end
  if id > 0 then
    if npcIdOf(key) and ForeverVendors.VendorAt(ForeverVendors.Table(), id) then
      namePage(id, key)
    end
    return key
  end
  if type(EraSources) ~= "table" then
    return key
  end
  local creatureId = call(EraSources.PageId, key)
  if not creatureId then
    local placedKind, placedId = nil, nil
    if type(EraSources.PlacedId) == "function" then
      local ok, answerKind, answerId = pcall(EraSources.PlacedId, key)
      if ok then
        placedKind, placedId = answerKind, answerId
      end
    end
    creatureId = placedKind == "npc" and placedId or nil
  end
  if type(creatureId) ~= "number" or not ForeverVendors.VendorAt(ForeverVendors.Table(), creatureId) then
    return key
  end
  local target = Graph.Key("npc", creatureId)
  if eraNameShown(creatureId, namePage(creatureId, target)) then
    return target
  end
  return key
end

--------------------------------------------------------------------------------
-- Places
--------------------------------------------------------------------------------

ForeverVendors.zoneWords = {}

-- The Classic Era table's reader, where one is loaded.
local function era()
  local reader = ItemTree.eraSources
  if type(reader) ~= "table" then
    return nil
  end
  return reader
end

-- The zone words and the zone map for one area id: the same area naming and area to uiMap join
-- the Classic Era pins use (Core/EraSources.lua E:ZoneFacts), then, for an area only Forever
-- names, the client's own name for it (ForeverVendors.ClientAreaName, below the divider), with no
-- map. nil, nil for an area nothing names. Kept per area id.
function ForeverVendors.Place(areaId)
  if type(areaId) ~= "number" then
    return nil, nil
  end
  -- Kept against the Classic Era table it was read from, so a swapped table is read afresh.
  local reader = era()
  local eraTable = ask(reader, "Table")
  if ForeverVendors.zoneFor ~= eraTable then
    ForeverVendors.zoneWords = {}
    ForeverVendors.zoneFor = eraTable
  end
  local held = ForeverVendors.zoneWords[areaId]
  if held then
    return held.name, held.map
  end
  local facts = ask(reader, "ZoneFacts", Graph.Key("zone", areaId))
  local name, map = nil, nil
  if type(facts) == "table" then
    name = type(facts.name) == "string" and facts.name ~= "" and facts.name or nil
    map = type(facts.map) == "number" and facts.map or nil
  end
  if not name and type(ForeverVendors.ClientAreaName) == "function" then
    local ok, answer = pcall(ForeverVendors.ClientAreaName, areaId)
    if ok and type(answer) == "string" and answer ~= "" then
      name = answer
    end
  end
  ForeverVendors.zoneWords[areaId] = { name = name, map = map }
  return name, map
end

-- Everything a client vendor's page says about it, or nil for a key the module names no vendor
-- for. Loads the module (a vendor page is one of the two first needs).
--
--   npcId, name (nil where nothing names it), label (the name, else "Vendor (npc N)"), areaId,
--   mapId (the client's Map id), zone (words or nil), uiMap (or nil), x, y (0 to 1, or nil),
--   sells (how many items the module lists for it, which builds the reverse index)
function ForeverVendors.Facts(key)
  local npcId = npcIdOf(key)
  if not npcId then
    return nil
  end
  local source = ForeverVendors.Table()
  local vendor = ForeverVendors.VendorAt(source, npcId)
  if not vendor then
    return nil
  end
  local name = ForeverVendors.Name(npcId, source)
  local zone, uiMap = ForeverVendors.Place(vendor.a)
  local reverse = ForeverVendors.Reverse()
  return {
    npcId = npcId,
    name = name,
    label = name or ForeverVendors.Label(npcId),
    areaId = vendor.a,
    mapId = vendor.m,
    zone = zone,
    uiMap = uiMap,
    x = tonumber(vendor.x),
    y = tonumber(vendor.y),
    sells = #((reverse and reverse[npcId]) or EMPTY),
  }
end

-- Whether an npc key is a vendor the client's tables list. Loads the module for a real npc id and
-- never for a made up one (a Classic Era name's node, the world drop, the unnamed row).
function ForeverVendors.IsVendor(key)
  local npcId = npcIdOf(key)
  if not npcId then
    return false
  end
  return ForeverVendors.VendorAt(ForeverVendors.Table(), npcId) ~= nil
end

-- The client's pin for a vendor's page, as the Map tab takes one: { map, x, y, zone, name, client }
-- with x and y in PERCENT, the way every other pin is. An empty list where the module places the
-- vendor on no zone map, or no uiMap is known for its area. facts is ForeverVendors.Facts. Pure.
function ForeverVendors.Positions(facts)
  local out = {}
  if type(facts) ~= "table" then
    return out
  end
  local x, y = tonumber(facts.x), tonumber(facts.y)
  if type(facts.uiMap) ~= "number" or not x or not y then
    return out
  end
  out[1] = {
    map = facts.uiMap,
    x = math.floor(x * 1000 + 0.5) / 10,
    y = math.floor(y * 1000 + 0.5) / 10,
    zone = facts.zone,
    name = facts.label,
    seen = false,
    client = true,
  }
  return out
end

--------------------------------------------------------------------------------
-- Edges
--------------------------------------------------------------------------------

-- The price and cost the player's own record of this vendor states for the item (brief M2), or
-- nil: the merchant window the player opened is the only place a Forever price is known.
local function recordCost(records, npcId)
  local Collector = ItemTree.Collector
  if type(Collector) ~= "table" or type(Collector.Cost) ~= "function" then
    return nil, nil
  end
  for _, record in ipairs(type(records) == "table" and records or EMPTY) do
    if type(record) == "table" and record.kind == "vendor" and record.sourceId == npcId then
      local cost = Collector.Cost(record.cost)
      if cost then
        local parts = nil
        if cost.currency or cost.items then
          parts = { currency = cost.currency, items = cost.items }
        end
        return cost.copper, parts
      end
    end
  end
  return nil, nil
end

-- Whether the curated Merchant's Favor file ships this very offer (the item at this npc id). Such a
-- row is the curated tier's already, with the Favour price and the pages it rests on, and the
-- graph's merge would let a client row of the same key replace it with neither: so the client
-- leaves that one row to the file (brief M3), which still shadows the Classic Era rows by name.
local function favourShips(itemId, npcId)
  local sources = ItemTree.Sources
  local favour = type(sources) == "table" and sources.Favour or nil
  if type(favour) ~= "table" or type(favour.ShippedOffer) ~= "function" then
    return false
  end
  local ok, offer = pcall(favour.ShippedOffer, itemId, { kind = "vendor", sourceId = npcId })
  return ok and type(offer) == "table"
end

-- The one row of an item whose vendor the client does not name yet: a summary that names nothing,
-- lists nothing (listed 0) and so opens nothing, with no zone and no pin.
local function unnamedEdge(itemId)
  return {
    type = T.SOLD_BY,
    target = ForeverVendors.UNNAMED_KEY,
    confidence = Confidence.MINED,
    group = L["Sold by"],
    provenance = ForeverVendors.PROVENANCE,
    summary = { item = itemId, category = "vendor", listed = 0 },
  }
end

-- The Sold by edges one item's client vendors stand for, in the module's own order (ascending npc
-- id; the view sorts them). records is the item's collected vendor records (Core/Collector.lua
-- C:VendorRecords) or nil. Pure over the table handed in and the zone words.
function ForeverVendors.ItemEdges(source, itemId, records)
  local list = ForeverVendors.VendorsOf(source, itemId)
  if not list then
    return {}
  end
  if #list == 0 then
    return { unnamedEdge(itemId) }
  end
  local out = {}
  for _, npcId in ipairs(list) do
    local vendor = type(npcId) == "number" and ForeverVendors.VendorAt(source, npcId) or nil
    if vendor and not favourShips(itemId, npcId) then
      local zone = ForeverVendors.Place(vendor.a)
      local price, cost = recordCost(records, npcId)
      out[#out + 1] = {
        type = T.SOLD_BY,
        target = Graph.Key("npc", npcId),
        confidence = Confidence.MINED,
        group = L["Sold by"],
        zone = zone,
        price = price,
        cost = cost,
        provenance = ForeverVendors.PROVENANCE,
      }
    end
  end
  return out
end

-- The Sells edges one client vendor's page lists, in item id order (the view sorts them by name).
-- recordsOf(itemId) answers the item's collected vendor records, or nil. Builds the reverse index.
function ForeverVendors.SellsEdges(npcId, recordsOf)
  local out = {}
  local source = ForeverVendors.Table()
  local vendor = ForeverVendors.VendorAt(source, npcId)
  local reverse = vendor and ForeverVendors.Reverse() or nil
  if not reverse then
    return out
  end
  local zone = ForeverVendors.Place(vendor.a)
  for _, itemId in ipairs(reverse[npcId] or EMPTY) do
    if not favourShips(itemId, npcId) then
      local records = type(recordsOf) == "function" and recordsOf(itemId) or nil
      local price, cost = recordCost(records, npcId)
      out[#out + 1] = {
        type = T.SELLS,
        target = Graph.Key("item", itemId),
        confidence = Confidence.MINED,
        group = L["Sells"],
        zone = zone,
        price = price,
        cost = cost,
        provenance = ForeverVendors.PROVENANCE,
      }
    end
  end
  return out
end

-- What /itemtree debug says: the pipeline's own counts (Meta.vendorCounts) and how many of the
-- module's vendors the player's own visits name. Never loads anything, because the debug report
-- must be able to say the data addon is not loaded: named is nil until a vendor row or page has
-- built the module. Ids and counts only. { vendors, items, withheld, named }, nil where unknown.
function ForeverVendors.Counts(visited)
  local meta = type(Data) == "table" and Data.Meta or nil
  local counts = type(meta) == "table" and meta.vendorCounts or nil
  local out = {}
  if type(counts) == "table" then
    out.vendors = tonumber(counts.vendors)
    out.items = tonumber(counts.items)
    out.withheld = tonumber(counts.withheld)
  end
  local source = ForeverVendors.Loaded()
  if type(source) == "table" and type(source.v) == "table" then
    local named = 0
    for npcId in pairs(source.v) do
      if type(visited) == "function" and visited(npcId) == true then
        named = named + 1
      end
    end
    out.named = named
  end
  return out
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- An area's name as the running client states it (C_Map.GetAreaInfo), for an area the Classic Era
-- table does not name: the new Forever areas. A local table read, never a server query, under
-- pcall; nil on a client with no such call.
function ForeverVendors.ClientAreaName(areaId)
  local api = rawget(_G, "C_Map")
  if type(api) ~= "table" or type(api.GetAreaInfo) ~= "function" or type(areaId) ~= "number" then
    return nil
  end
  local ok, name = pcall(api.GetAreaInfo, areaId)
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- The provider: see the note at the top of this file.
function ForeverVendors.EdgesFor(key, direction)
  local kind, id = Graph.Parse(key)
  if kind == "item" and direction == Edges.UP then
    local source = ForeverVendors.Table()
    if not ForeverVendors.VendorsOf(source, id) then
      return EMPTY
    end
    -- Brief VN1: each vendor named and titled from the Classic Era table where nothing else names it.
    return ForeverVendors.WithEraNames(ForeverVendors.ItemEdges(source, id, ask(collector(), "VendorRecords", id)))
  end
  if kind == "npc" and direction == Edges.DOWN and npcIdOf(key) then
    return ForeverVendors.SellsEdges(id, function(itemId)
      return ask(collector(), "VendorRecords", itemId)
    end)
  end
  return EMPTY
end

-- Registers the provider and the namer with the graph. Safe to call twice. The provider is marked
-- as one Graph.Summary skips: Summary counts only the quests a provider names and this names none,
-- so a tooltip never builds the module for nothing.
function ForeverVendors.Install()
  if type(Graph) ~= "table" or type(Graph.RegisterProvider) ~= "function" then
    return false
  end
  if not Graph.HasProvider(ForeverVendors.EdgesFor) then
    Graph.RegisterProvider(ForeverVendors.EdgesFor, { predictedOnly = true })
  end
  if type(Graph.RegisterNamer) == "function" and not Graph.HasNamer(ForeverVendors.Namer) then
    Graph.RegisterNamer(ForeverVendors.Namer)
  end
  return true
end

ForeverVendors.Install()

return ForeverVendors
