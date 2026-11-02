-- Recently viewed and pinned pages. Pure Lua, no WoW API.
-- Loaded as: local _, ItemTree = ...
--
-- The store is ItemTree.db.history, the saved variable Core/Init.lua defaults to
-- { recent = {}, pinned = {} }. recent holds { key, at } newest first, capped at 30; pinned holds
-- node keys in pin order. Brief SR1: any page opened is recorded by its Core/Graph.lua node key
-- ("item:2589", "quest:1487", "zone:12", "npc:-5199"), not only an item. A list saved before that
-- (recent { id, at } and pinned item ids) is read as the item keys it stood for, and written back
-- that way the first time the store is asked for (History.Store). Only node keys and a timestamp
-- are ever written, and (brief RO1) on the newest entry alone the view tab word its page is on, so
-- nothing a player typed and no character or realm name can reach saved variables (see
-- Core/Privacy.lua and design: tree/HistoryList.jsx).
--
-- Brief EK1: Classic Era pages by id. ItemTree 0.1.3 to 0.1.8 keyed a Classic Era creature's page
-- npc:-<n> and an object's object:-<n>, n the name's place in that release's EraSources.lua string
-- table. Since EK1 the same plain range holds the CMaNGOS id instead (npc:-<creature id>,
-- object:-<gameobject id>, Core/EraSources.lua EraSources.CreaturePageKey and ObjectPageKey), and a
-- creature whose Classic Era page is one with its Forever page (cm) is the plain npc:<creature id>.
-- Brief EK2: the row keys by id too. 0.1.3 to the EK1 build keyed a creature or an object in one
-- place, a pocket, a gathering node's zone row and a gathering node row by a name's place (and an
-- area or an item) in ranges of their own; since EK2 they hold the creature or gameobject id
-- (EraSources.PlacedKey, PocketKey, GatheredKey, NodeKey) in new windows, and the old windows are
-- retired, so the string table may move from one release to the next. So an old saved key would
-- now name a wrong page or none, and the store carries the version of its keys: keys = 2 since EK1,
-- keys = 3 since EK2 (History.KEYS). A store below 3 is converted once, on read (History.Store),
-- then marked:
--   * a store with no keys (0.1.8 and before) first has every recent and pinned plain Era page key
--     put through the frozen map ItemTree_Data ships, EraPageKeys.lua ({ m = { [old index] =
--     creature id }, o = { [old index] = object id } }, ours, built once from the 0.1.8 table, whose
--     name indexes 0.1.3 to 0.1.8 and EK1 share), and then through the one builder, so a merged
--     creature becomes npc:<id>. The new key must be a page the table loaded now states
--     (EraSources.PageName or ObjectName answer for it);
--   * then every store below 3 (no keys, or keys = 2 from EK1) has every recent and pinned old row
--     key read with a FROZEN copy of the old formulas (below, never the live ones), its name put
--     through the same map (m for a creature, o for an object) and the row built again with its
--     range's one builder, keeping its area or its item. The new key must be one the table loaded
--     now reads back to a name (EraSources.CreatureAt, ObjectAt or ZoneAt);
--   * an entry the map or the table cannot place is dropped quietly, never kept as a raw old key;
--   * every other key (items, quests, zones, sets, spells, positive npc ids, summary rows, and a key
--     already in an EK2 window) is kept as is;
--   * duplicates the conversion makes collapse to the newest: the first in recent (newest first),
--     the first in pin order.
-- The map and the Classic Era table (for cm and the checks) are asked for only when the store holds
-- at least one old key; a store holding none is marked and loads nothing. Once a store is converted
-- the map is let go of (its Data cache slot holds false), since it is needed once. A store this file
-- creates starts at keys = 3. Core/Init.lua's defaults leave keys out on purpose: ApplyDefaults would
-- otherwise mark an old store before it is converted. Where the map cannot be had (ItemTree_Data does
-- not load, or ships no EraPageKeys), the store is left unconverted and asked again next time;
-- meanwhile its old keys are kept out of History.Items, and an old key is neither recorded nor pinned
-- against it, so an old key is never read as a new one, nor a new one as an old one. A new row key
-- recorded meanwhile cannot be mistaken for an old one either: the windows do not overlap.
--
-- Every function takes the current time as an argument so the specs and the browser
-- harness can drive a fixed clock. When it is left out the client's own `time` is used if
-- it exists, which is the only place this module looks at a global at all.
local _, ItemTree = ...

local Data = ItemTree.Data
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local History = {}
ItemTree.History = History

local EMPTY = {}

History.LIMIT = 30

local MINUTE = 60
local HOUR = 3600
local DAY = 86400

local function clock(now)
  if type(now) == "number" then
    return now
  end
  local clientTime = rawget(_G, "time")
  if type(clientTime) == "function" then
    return clientTime()
  end
  local standard = rawget(_G, "os")
  if type(standard) == "table" and type(standard.time) == "function" then
    return standard.time()
  end
  return 0
end

-- The node key one value stands for, or nil: an item id (a number, or digits) is its item key,
-- which is what every list saved before brief SR1 holds and what the harness still pushes; a node
-- key is itself where it is "kind:id" with a whole number id and, with Core/Graph.lua loaded, a
-- kind the graph knows. Anything else (words, a category row's key, nothing) names no page. Pure.
function History.KeyOf(value)
  local id = tonumber(value)
  if id then
    if id > 0 and id == math.floor(id) then
      return "item:" .. string.format("%d", id)
    end
    return nil
  end
  if type(value) ~= "string" then
    return nil
  end
  local kind, digits = value:match("^(%a+):(%-?%d+)$")
  if not kind then
    return nil
  end
  local Graph = ItemTree.Graph
  if type(Graph) == "table" and type(Graph.Kind) == "function" then
    local ok, known = pcall(Graph.Kind, value)
    if not ok or known == nil then
      return nil
    end
  end
  return kind .. ":" .. digits
end

-- The item id an item key carries, or nil for any other key. Pure.
local function itemIdOf(key)
  local digits = type(key) == "string" and key:match("^item:(%d+)$") or nil
  return digits and tonumber(digits) or nil
end

-- Brings one saved list up to date in place: a recent entry { id, at } becomes { key, at } and a
-- pinned item id its item key. Anything that names no page is dropped, and a key the list already
-- holds is dropped the second time, so an old list and a new push of the same item cannot both
-- stand. Answers the list.
local function migrateRecent(recent)
  local out, seen = {}, {}
  for _, entry in ipairs(recent) do
    if type(entry) == "table" then
      local key = History.KeyOf(entry.key or entry.id)
      if key and not seen[key] then
        seen[key] = true
        out[#out + 1] = { key = key, at = entry.at }
      end
    end
  end
  return out
end

local function migratePinned(pinned)
  local out, seen = {}, {}
  for _, value in ipairs(pinned) do
    local key = History.KeyOf(value)
    if key and not seen[key] then
      seen[key] = true
      out[#out + 1] = key
    end
  end
  return out
end

-- Whether a list still holds anything in the shape saved before brief SR1, so the migration is a
-- walk and nothing more on every ask after the first.
local function recentStale(recent)
  for _, entry in ipairs(recent) do
    if type(entry) ~= "table" or type(entry.key) ~= "string" or entry.id ~= nil then
      return true
    end
  end
  return false
end

local function pinnedStale(pinned)
  for _, value in ipairs(pinned) do
    if type(value) ~= "string" then
      return true
    end
  end
  return false
end

-- One module's function asked under pcall, or nil where it is missing or fails.
local function askModule(module, method, ...)
  if type(module) ~= "table" or type(module[method]) ~= "function" then
    return nil
  end
  local ok, a, b, c, d, e = pcall(module[method], ...)
  if not ok then
    return nil
  end
  return a, b, c, d, e
end

--------------------------------------------------------------------------------
-- Brief EK1 and EK2: the Classic Era keys of 0.1.8 and before, and of EK1 (keys = 3, see the header)
--------------------------------------------------------------------------------

-- The version of the keys a store holds: 2 since brief EK1 (Classic Era pages by id), 3 since brief
-- EK2 (the Classic Era row keys by id too). A store without one predates both.
History.KEYS = 3

-- The version brief EK1 marked a store with: its plain page keys are ids already, and only its row
-- keys are still in the old name keyed ranges.
History.PAGE_KEYS = 2

-- The module of the frozen old index to id maps, in ItemTree_Data.
History.KEY_MAP_MODULE = "EraPageKeys"

-- The old page a saved key may stand for, as "npc" or "object" and the number it holds, or nil for
-- every key that is no plain Era page key (the one parsers in Core/EraSources.lua decide). Pure.
local function plainEraPage(key)
  local EraSources = ItemTree.EraSources
  local id = askModule(EraSources, "PageId", key)
  if id then
    return "npc", id
  end
  id = askModule(EraSources, "ObjectPageId", key)
  if id then
    return "object", id
  end
  return nil
end

-- Brief EK2: the row key ranges ItemTree 0.1.3 to the EK1 build made, FROZEN here (Core/EraSources.lua
-- before EK2), so the live ranges may move and a key saved in one of these is still read the way it
-- was written: a name's place in that release's string table (which is the place the frozen map's
-- m and o are keyed by: every name had the same place in 0.1.3 to 0.1.8 and in EK1) and an area or
-- an item.
--   placed    npc or object:-(10,000,000,000 + name * 100,000 + area), area 1 or more
--   pocket    npc:-(20,000,000,000 + name * 100,000 + area), area 0 for none
--   gathered  zone:-(30,000,000,000 + name * 100,000 + area), area 1 or more
--   node      object:-(40,000,000,000 + item * 100,000 + name), item under 10,000,000
-- with every name 1 to 99,999. 0.1.0 to 0.1.2 laid them out otherwise, but stored no page key at all
-- (brief SR1 came with 0.1.3).
local OLD_PLACED = 10000000000
local OLD_POCKET = 20000000000
local OLD_GATHERED = 30000000000
local OLD_NODE = 40000000000
local OLD_SPAN = 100000
local OLD_NODE_ITEMS = 10000000

-- What a whole number past one old base holds, or nil outside [base, base + width).
local function oldHeld(id, base, width)
  if type(id) ~= "number" or id ~= math.floor(id) then
    return nil
  end
  local held = -id - base
  if held < 0 or held >= width then
    return nil
  end
  return held
end

-- A name and an area out of one old paired id, or nil (no name, or an area under floorArea).
local function oldPair(id, base, floorArea)
  local held = oldHeld(id, base, OLD_PLACED)
  if not held then
    return nil
  end
  local area = held % OLD_SPAN
  local name = (held - area) / OLD_SPAN
  if name < 1 or area < floorArea then
    return nil
  end
  return name, area
end

-- The old row key a saved key is, as { range, kind, name, area or item }, or nil for every other
-- key (a page, an item, a key of EK2's own ranges, anything else). Pure: the frozen formulas above.
local function oldRowKey(key)
  local Graph = ItemTree.Graph
  if type(key) ~= "string" or type(Graph) ~= "table" or type(Graph.Parse) ~= "function" then
    return nil
  end
  local kind, id = Graph.Parse(key)
  if type(id) ~= "number" then
    return nil
  end
  if kind == "npc" or kind == "object" then
    local name, area = oldPair(id, OLD_PLACED, 1)
    if name then
      return { range = "placed", kind = kind, name = name, area = area }
    end
  end
  if kind == "npc" then
    local name, area = oldPair(id, OLD_POCKET, 0)
    if name then
      return { range = "pocket", kind = kind, name = name, area = area }
    end
  elseif kind == "zone" then
    local name, area = oldPair(id, OLD_GATHERED, 1)
    if name then
      return { range = "gathered", kind = kind, name = name, area = area }
    end
  elseif kind == "object" then
    local held = oldHeld(id, OLD_NODE, OLD_NODE_ITEMS * OLD_SPAN)
    if held then
      local name = held % OLD_SPAN
      local item = (held - name) / OLD_SPAN
      if item >= 1 and name >= 1 then
        return { range = "node", kind = kind, name = name, item = item }
      end
    end
  end
  return nil
end

-- Whether a store's keys predate keys = 3 (none, 2, or anything that is not a version at all), so
-- its old row keys are still to convert. Pure.
local function rowsStale(store)
  return type(store.keys) ~= "number" or store.keys < History.KEYS
end

-- Whether a list entry's key may not be read against a store not yet converted: an old row key in
-- a store before keys = 3, and a plain Era page key in a store before keys = 2, which in such a
-- store is an old one. Pure.
local function unreadable(store, key)
  if store.keys == nil and plainEraPage(key) ~= nil then
    return true
  end
  return rowsStale(store) and oldRowKey(key) ~= nil
end

-- Whether a store holds anything a conversion would change: a plain Era page key where it predates
-- keys = 2, an old row key where it predates keys = 3.
local function holdsOldKeys(store)
  local function old(key)
    return (store.keys == nil and plainEraPage(key) ~= nil) or oldRowKey(key) ~= nil
  end
  for _, entry in ipairs(store.recent) do
    if type(entry) == "table" and old(entry.key) then
      return true
    end
  end
  for _, key in ipairs(store.pinned) do
    if old(key) then
      return true
    end
  end
  return false
end

-- What a conversion reads: the frozen map and the Classic Era table, or nil where either cannot be
-- had. Both live in ItemTree_Data, which Data:Get loads on demand.
local function conversionSources()
  local map = askModule(Data, "Get", Data, History.KEY_MAP_MODULE)
  if type(map) ~= "table" or type(map.m) ~= "table" or type(map.o) ~= "table" then
    return nil
  end
  local era = ItemTree.eraSources
  local source = askModule(era, "Table", era)
  if type(source) ~= "table" then
    return nil
  end
  return map, source
end

-- Brief EK1: the key one saved plain page key is now: itself where it is no plain Era page key, the
-- new page key where the map and the table place the old one, or nil (dropped).
local function convertPage(key, map, source)
  local kind, old = plainEraPage(key)
  if not kind then
    return key
  end
  local EraSources = ItemTree.EraSources
  if kind == "npc" then
    local id = map.m[old]
    -- The merged page first (cm), then the Classic Era page alone: the one the table states.
    for _, merged in ipairs({ true, false }) do
      local new = EraSources.CreaturePageKey(id, merged)
      if new and EraSources.PageName(source, new) then
        return new
      end
    end
    return nil
  end
  local new = EraSources.ObjectPageKey(map.o[old])
  if new and EraSources.ObjectName(source, new) then
    return new
  end
  return nil
end

-- Brief EK2: the key one saved row key is now: itself where it is no old row key, the same row keyed
-- by id where the map places the old name (m for a creature, o for an object) and the table loaded
-- now reads the new key back to a name, through the ONE builder of its range (EraSources.PlacedKey,
-- PocketKey, GatheredKey, NodeKey) and the one reader (EraSources.CreatureAt, ObjectAt, ZoneAt), or
-- nil (dropped).
local function convertRow(key, map, source)
  local old = oldRowKey(key)
  if not old then
    return key
  end
  local EraSources = ItemTree.EraSources
  local Graph = ItemTree.Graph
  local new
  if old.range == "placed" then
    local id = old.kind == "npc" and map.m[old.name] or map.o[old.name]
    new = EraSources.PlacedKey(old.kind, id, old.area)
  elseif old.range == "pocket" then
    new = EraSources.PocketKey(map.m[old.name], old.area)
  elseif old.range == "gathered" then
    new = EraSources.GatheredKey(map.o[old.name], old.area)
  else
    new = EraSources.NodeKey(old.item, map.o[old.name])
  end
  local kind, id = Graph.Parse(new)
  if not kind then
    return nil
  end
  local nameIndex
  if kind == "npc" then
    nameIndex = EraSources.CreatureAt(id, source)
  elseif kind == "object" then
    nameIndex = EraSources.ObjectAt(id, source)
  else
    local _, node = EraSources.ZoneAt(id, source)
    nameIndex = node
  end
  if not nameIndex then
    return nil
  end
  return new
end

-- One saved list, every key through convert, in its order: an entry the conversion drops is gone,
-- and duplicates it makes collapse to the first (the newest in recent, the first in pin order).
local function convertRecent(recent, convert, map, source)
  local out, seen = {}, {}
  for _, entry in ipairs(recent) do
    local key = type(entry) == "table" and convert(entry.key, map, source) or nil
    if key and not seen[key] then
      seen[key] = true
      out[#out + 1] = { key = key, at = entry.at }
    end
  end
  return out
end

local function convertPinned(pinned, convert, map, source)
  local out, seen = {}, {}
  for _, value in ipairs(pinned) do
    local key = convert(value, map, source)
    if key and not seen[key] then
      seen[key] = true
      out[#out + 1] = key
    end
  end
  return out
end

-- Lets go of the frozen map once a store is converted: it is needed once per profile, and is a few
-- hundred KB the session would otherwise hold. Its cache slot holds false after, the way a joined
-- partner's does (Core/Data.lua Data:JoinHalves), so Data:Has and Data:OnDemandLoaded still count
-- the module and Data:Get answers false rather than building it again.
local function releaseMap()
  local cache = type(Data) == "table" and Data.cache or nil
  if type(cache) == "table" and type(cache[History.KEY_MAP_MODULE]) == "table" then
    cache[History.KEY_MAP_MODULE] = false
  end
end

-- Converts a store saved before keys = 3 in place and marks it, or leaves it as it is where the map
-- cannot be had, to be asked again next time. A store with no keys gets brief EK1's conversion of its
-- plain page keys first and then brief EK2's of its row keys, in that order; a store at keys = 2
-- gets EK2's alone. Nothing is loaded for a store with no old key, and the map is let go of once
-- the store is converted. Without Core/EraSources.lua nothing can tell an old key, so nothing is
-- done.
local function convertKeys(store)
  if type(ItemTree.EraSources) ~= "table" then
    return
  end
  if holdsOldKeys(store) then
    local map, source = conversionSources()
    if not map then
      return
    end
    if store.keys == nil then
      store.recent = convertRecent(store.recent, convertPage, map, source)
      store.pinned = convertPinned(store.pinned, convertPage, map, source)
    end
    store.recent = convertRecent(store.recent, convertRow, map, source)
    store.pinned = convertPinned(store.pinned, convertRow, map, source)
    releaseMap()
  end
  store.keys = History.KEYS
end

-- The saved variable table, created on first use so a fresh profile still works, and an older
-- list of item ids migrated to node keys on the way (migrate on read). Briefs EK1 and EK2: a store
-- saved before keys = 3 has its Classic Era keys converted once (see the header); one made here
-- starts at keys = 3.
function History.Store()
  ItemTree.db = ItemTree.db or {}
  local store = ItemTree.db.history
  if type(store) ~= "table" then
    store = { recent = {}, pinned = {}, keys = History.KEYS }
    ItemTree.db.history = store
  end
  if type(store.recent) ~= "table" then
    store.recent = {}
  end
  if type(store.pinned) ~= "table" then
    store.pinned = {}
  end
  if recentStale(store.recent) then
    store.recent = migrateRecent(store.recent)
  end
  if pinnedStale(store.pinned) then
    store.pinned = migratePinned(store.pinned)
  end
  if rowsStale(store) then
    convertKeys(store)
  end
  return store
end

local function indexOf(list, key)
  for index, value in ipairs(list) do
    if value == key then
      return index
    end
  end
  return nil
end

-- Brief RO1 (the owner's QA item 290, 2026-10-20): "if there is a recent history it should actually
-- open to the most recent item instead (i.e. the previous state before you logged out)". The newest
-- recent entry also carries the view tab its page is on (view: one word such as "map" or "sources"),
-- and no other entry does, so the store holds one short word more than it did, about 20 bytes in the
-- saved file. The first open of a session with nothing pointed at reopens that page on that tab
-- (UI/Frame.lua Frame.OpenDefault). The longest word a view key may be.
History.VIEW_MAX = 24

-- The view word one value stands for, or nil: letters only, and short. Pure.
local function viewWord(view)
  if type(view) ~= "string" or #view > History.VIEW_MAX or not view:match("^%a+$") then
    return nil
  end
  return view
end

-- Records a view of a page, by its node key or, for an item, its id. Newest first, one entry per
-- page, capped at History.LIMIT. view (brief RO1, optional) is the tab the page is on, kept on the
-- newest entry alone. Answers the entry, or nil for anything that names no page.
function History.Push(keyOrId, now, view)
  local key = History.KeyOf(keyOrId)
  if not key then
    return nil
  end
  local store = History.Store()
  if unreadable(store, key) then
    return nil
  end
  local recent = store.recent
  for index = #recent, 1, -1 do
    if recent[index] and recent[index].key == key then
      table.remove(recent, index)
    elseif type(recent[index]) == "table" then
      recent[index].view = nil
    end
  end
  table.insert(recent, 1, { key = key, at = clock(now), view = viewWord(view) })
  for index = #recent, History.LIMIT + 1, -1 do
    recent[index] = nil
  end
  return recent[1]
end

-- Brief RO1: the tab the newest recent page is on now, written onto its entry when the player moves
-- to another tab of that page. Only the newest entry, and only where it is this page: nothing is
-- recorded by a tab change. Answers whether the word was written.
function History.NoteView(keyOrId, view)
  local key = History.KeyOf(keyOrId)
  local word = viewWord(view)
  if not key or not word then
    return false
  end
  local newest = History.Store().recent[1]
  if type(newest) ~= "table" or newest.key ~= key then
    return false
  end
  newest.view = word
  return true
end

-- Brief RO1: the page the window last showed before this session, for its first open: the newest
-- recent entry this store can read (pins are not a history of viewing), and the tab it was on, or
-- nil for that where none was noted. nil, nil for an empty recent list.
function History.Last()
  local store = History.Store()
  for _, entry in ipairs(store.recent or EMPTY) do
    local key = type(entry) == "table" and History.KeyOf(entry.key) or nil
    if key and not unreadable(store, key) then
      return key, viewWord(entry.view)
    end
  end
  return nil, nil
end

function History.IsPinned(keyOrId)
  local key = History.KeyOf(keyOrId)
  if key == nil then
    return false
  end
  local store = History.Store()
  return not unreadable(store, key) and indexOf(store.pinned, key) ~= nil
end

-- Pins a page so it sorts above the recent list. Pinning never records a view.
function History.Pin(keyOrId)
  local key = History.KeyOf(keyOrId)
  if not key then
    return false
  end
  local store = History.Store()
  local pinned = store.pinned
  if unreadable(store, key) or indexOf(pinned, key) then
    return false
  end
  table.insert(pinned, 1, key)
  return true
end

function History.Unpin(keyOrId)
  local key = History.KeyOf(keyOrId)
  local store = History.Store()
  local pinned = store.pinned
  local index = key and not unreadable(store, key) and indexOf(pinned, key) or nil
  if not index then
    return false
  end
  table.remove(pinned, index)
  return true
end

function History.Toggle(keyOrId)
  if History.IsPinned(keyOrId) then
    History.Unpin(keyOrId)
    return false
  end
  History.Pin(keyOrId)
  return true
end

-- Clears the recent list and keeps the pins, which is what the footer button does.
function History.Clear()
  local store = History.Store()
  store.recent = {}
  return store
end

-- Elapsed time in the client's style: "just now", "2m", "3h", "1d".
function History.Ago(at, now)
  if type(at) ~= "number" then
    return nil
  end
  local elapsed = clock(now) - at
  if elapsed < MINUTE then
    return "just now"
  end
  if elapsed < HOUR then
    return string.format("%dm", math.floor(elapsed / MINUTE))
  end
  if elapsed < DAY then
    return string.format("%dh", math.floor(elapsed / HOUR))
  end
  return string.format("%dd", math.floor(elapsed / DAY))
end

-- What a row is called. Core/Graph.lua is the one place a key becomes a title, so it answers
-- for every row: the data build's own name, the live client's where the realm has found an item
-- the build withholds, "Undiscovered mail head" for a withheld item nothing has found yet, and
-- "Item 4242" in the player's own language for an id nothing can name. Guarded: Graph loads
-- before this file, but nothing here assumes it.
local function graphNode(key)
  local Graph = ItemTree.Graph
  if type(Graph) ~= "table" or type(Graph.Node) ~= "function" then
    return nil
  end
  local ok, node = pcall(Graph.Node, key)
  if ok and type(node) == "table" then
    return node
  end
  return nil
end

local function graphAsk(method, key)
  local Graph = ItemTree.Graph
  if type(Graph) == "table" and type(Graph[method]) == "function" then
    local ok, text = pcall(Graph[method], key)
    if ok and type(text) == "string" and text ~= "" then
      return text
    end
  end
  return nil
end

-- An npc key's Classic Era kind, where the table is loaded and states one: the creature type, the
-- family and the role ("creature", "vendor" or "both"). Nothing is loaded for it.
local function eraKind(key)
  local era = ItemTree.eraSources
  local EraSources = ItemTree.EraSources
  if type(era) ~= "table" or type(EraSources) ~= "table" or type(era.NpcNameAt) ~= "function" then
    return nil
  end
  local ok, nameIndex = pcall(era.NpcNameAt, era, key)
  if not ok or type(nameIndex) ~= "number" then
    return nil
  end
  local okTable, source = pcall(era.Table, era)
  if not okTable or type(source) ~= "table" then
    return nil
  end
  local creatureType, family, _, _, role = askModule(EraSources, "KindOf", source, nameIndex)
  return creatureType, family, role
end

-- Whether an npc key is a vendor Forever's own tables list, read only off a module already built
-- (ForeverVendors.Loaded), so a list row never loads it.
local function foreverVendor(key)
  local vendors = ItemTree.ForeverVendors
  local held = askModule(vendors, "Loaded")
  local digits = type(key) == "string" and key:match("^npc:(%d+)$") or nil
  if type(held) ~= "table" or not digits then
    return false
  end
  return askModule(vendors, "VendorAt", held, tonumber(digits)) ~= nil
end

-- What a Recently viewed row wears beside a page's name (brief SR1): { word, asset, icon }. word is
-- the kind in the player's language ("Quest", "Zone", "Vendor", "Herb node"), nil for an item, whose
-- row is known by its own icon and quality; asset is the Assets key of the glyph the page's rows
-- wear in the tree; icon a file where the page has art of its own (a set's piece, a recipe). The
-- same glyphs UI/Tree.lua and the search dropdown draw. Pure over local data: nothing is loaded and
-- no index is built, so a list of thirty rows costs thirty table lookups.
function History.KindFacts(key)
  local Graph = ItemTree.Graph
  local kind = type(Graph) == "table" and type(Graph.Kind) == "function" and Graph.Kind(key) or nil
  if kind == nil or kind == "item" then
    return { kind = kind }
  end
  if kind == "quest" then
    return { kind = kind, word = L["Quest"], asset = "QUEST_AVAILABLE" }
  end
  if kind == "zone" then
    return { kind = kind, word = L["Zone"], asset = "CAT_ZONE" }
  end
  if kind == "set" then
    local file = askModule(ItemTree.ViewModel, "SetIcon", key)
    return { kind = kind, word = L["Set"], asset = "CAT_SET", icon = file }
  end
  if kind == "object" then
    local node = askModule(ItemTree.ViewModel, "NodeKind", key)
    if node == "herb" then
      return { kind = kind, word = L["Herb node"], asset = "CAT_HERBALISM" }
    elseif node == "vein" then
      return { kind = kind, word = L["Mining node"], asset = "CAT_MINING" }
    elseif node == "fished" then
      return { kind = kind, word = L["Fishing pool"], asset = "CAT_FISH_SCHOOL" }
    end
    return { kind = kind, word = L["Chest"], asset = "CAT_CHEST" }
  end
  if kind == "npc" then
    local creatureType, family, role = eraKind(key)
    if role == "vendor" or (role == nil and foreverVendor(key)) then
      return { kind = kind, word = L["Vendor"], asset = "CAT_VENDOR" }
    end
    local asset = askModule(ItemTree.ViewModel, "CreatureIcon", { type = creatureType, family = family })
    return { kind = kind, word = L["Creature"], asset = asset or "CAT_DROPS" }
  end
  if kind == "skill" then
    return { kind = kind, word = L["Skill"], asset = "CAT_NOTE" }
  end
  if kind == "enchant" then
    return { kind = kind, word = L["Enchant"], asset = "CAT_ENCHANTING" }
  end
  -- A recipe or any other spell wears its own art where the graph has some.
  local node = graphNode(key)
  return { kind = kind, word = L["Spell"], asset = "ICON_SPELL_MARK", icon = node and node.icon or nil }
end

local function entryFor(key, at, pinned, now)
  local itemId = itemIdOf(key)
  local ago = History.Ago(at, now)
  if itemId then
    local item = Data and Data:GetItem(itemId) or nil
    local node = graphNode(key)
    local name = node and type(node.name) == "string" and node.name ~= "" and node.name or nil
    return {
      key = key,
      kind = "item",
      id = itemId,
      name = name or graphAsk("Title", key) or (item and item.n) or ("Item " .. tostring(itemId)),
      quality = (node and node.quality) or (item and item.q) or nil,
      icon = (node and node.icon) or (item and item.i) or nil,
      pinned = pinned,
      ago = ago,
    }
  end
  -- Any other page is named the way its breadcrumb is, without the kind word the title leads with:
  -- the row says its kind in a column of its own.
  local facts = History.KindFacts(key)
  return {
    key = key,
    kind = facts.kind,
    kindText = facts.word,
    name = graphAsk("Name", key) or graphAsk("Title", key) or key,
    icon = facts.icon,
    asset = facts.asset,
    pinned = pinned,
    ago = ago,
  }
end

-- The list the History tab draws: pinned first in pin order, then recent newest first. Each entry
-- is { key, kind, id (an item's alone), name, quality, icon, asset, kindText, pinned, ago }. A store
-- not yet converted to keys = 3 lists none of its old Classic Era keys (see the header).
function History.Items(now)
  local store = History.Store()
  local seen, out = {}, {}
  local at = {}
  for _, entry in ipairs(store.recent or EMPTY) do
    if entry and entry.key and at[entry.key] == nil then
      at[entry.key] = entry.at
    end
  end
  for _, key in ipairs(store.pinned or EMPTY) do
    if not seen[key] and not unreadable(store, key) then
      seen[key] = true
      out[#out + 1] = entryFor(key, at[key], true, now)
    end
  end
  for _, entry in ipairs(store.recent or EMPTY) do
    if entry and entry.key and not seen[entry.key] and not unreadable(store, entry.key) then
      seen[entry.key] = true
      out[#out + 1] = entryFor(entry.key, entry.at, false, now)
    end
  end
  return out
end

return History
