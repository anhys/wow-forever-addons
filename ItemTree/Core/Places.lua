-- Brief R5a: the places store, where things are, one clustering rule for every kind (the
-- recording audit, section 3). Four kinds are written today: "e" an instance's entrance, since
-- brief R9 "t" a trainer and "s" a stable master, and since brief R12 "n" a gathering node seen on
-- hover; the rest drop into the same shape later.
--
--   ItemTreeDB.places[kind][id][mapId] = { [cell] = count }
--   ItemTreeDB.places[kind][id].d       = the whole day (since the epoch) the id was last touched
--   ItemTreeDB.places[kind][id].n, .k   = brief R9: the NPC's name and what a trainer trains
--   ItemTreeDB.places[kind][id].g, .h   = brief R14: layers, each { [mapId] = { [cell] = count } }
--
-- Brief R14: kind "n" writes its cells into two layers of the entry, "g" the spot of a gather and
-- "h" the last spot of a hover run (UI/CollectorHooks.lua); the plain [mapId] cells beside them are
-- what briefs R12 and R13 wrote and are never written for "n" again, so they always read as an
-- older file's cells of unknown kind. A layer's map is a map like any other: the same cells, the
-- same 8 cell cap (per layer), the same byte budget and the same merge.
--
-- kind is one short word: "e" is an instance's entrance, id the instance's Map id (the eighth
-- answer of GetInstanceInfo), mapId the uiMap the player stood on outside; "t" and "s" are a
-- creature id, mapId the uiMap the player stood on at the NPC's window; "n" is keyed by the node's
-- NAME as the tooltip's first line showed it (a world object gives the client no id), mapId the
-- uiMap the player stood on while hovering it. A position is snapped to
-- a 1 percent grid, the cell floor(x) * 100 + floor(y) (0 to 9999), and a sighting adds 1 to its
-- cell. At most Places.MAX_CELLS cells per id per map: a ninth cell replaces the cell with the
-- lowest count, ties the highest cell number, so the rule is deterministic. Two stores merge
-- exactly: cell by cell sums, then the same cut, in any order.
--
-- The store is held under Places.MAX_BYTES, measured the way the client writes saved variables.
-- Over it, the id and map pair with the lowest total count goes (ties: the oldest day, then the
-- highest id, then the highest map id), never the pair just written.
--
-- No character, realm or account data, no clock time: ids, map ids, cells, counts, a day and, for
-- a trainer or a stable master, the NPC's own name and trade as the client showed them.
-- Everything in this file is pure and runs under busted. The client side (when a position is
-- read and for which instance) is UI/CollectorHooks.lua's.
local _, ItemTree = ...

local Places = {}
ItemTree.Places = Places

Places.MAX_BYTES = 96 * 1024
Places.MAX_CELLS = 8
-- The kind this brief writes. Other kinds (creatures, objects, fishing, vendors, quest givers)
-- come later under their own letters.
Places.ENTRANCE = "e"
-- Brief R9: where a trainer and a stable master stand, id the creature id, written when the
-- player opens the trainer's or the stable's window (UI/CollectorHooks.lua).
Places.TRAINER = "t"
Places.STABLE = "s"
-- Brief R12: a herb, a vein or a fishing pool the player hovered, keyed by its name (a string, the
-- one kind whose id is not a number), written by UI/CollectorHooks.lua NoteNodeTooltip.
Places.NODE = "n"
-- Brief R14: the layers an entry may carry beside its plain maps: "g" gather cells, "h" hover cells.
Places.GATHERED = "g"
Places.HOVERED = "h"
Places.LAYERS = { g = true, h = true }
-- Brief R9: the text an id's entry may carry beside its maps, each a short string or absent:
-- n the name the client showed over the NPC, k what a trainer trains (a profession or a class
-- line, as the client stated it). Game data only; the caller checks them for a character's name.
Places.LABELS = { "n", "k" }
-- The longest label kept, in bytes. Anything longer is not a name the client shows over an NPC.
Places.MAX_LABEL = 64

local DAY = 86400

local whole = ItemTree.Util.Whole
local positive = ItemTree.Util.Positive

-- A label as an entry may keep it, or nil: a string of 1 to MAX_LABEL bytes with no control
-- characters and no "|" (the client's escape character). Pure.
function Places.Label(value)
  if type(value) ~= "string" or value == "" or #value > Places.MAX_LABEL then
    return nil
  end
  if value:find("[%c|]") then
    return nil
  end
  return value
end

-- The id an entry of kind is filed under, or nil: a positive whole number, or for a node (brief
-- R12) a name Places.Label accepts.
local function entryId(kind, id)
  if kind == Places.NODE then
    return Places.Label(id)
  end
  return positive(id)
end

-- Whole days since the epoch for a time in seconds, or nil.
function Places.Day(now)
  now = tonumber(now)
  if not now or now < 0 then
    return nil
  end
  return math.floor(now / DAY)
end

-- The 1 percent cell a position in map percent (0 to 100) falls in, or nil. 100 itself is the
-- last cell, not a cell of its own.
function Places.Cell(x, y)
  x, y = tonumber(x), tonumber(y)
  if not x or not y or x ~= x or y ~= y or x < 0 or y < 0 or x > 100 or y > 100 then
    return nil
  end
  local cx, cy = math.min(math.floor(x), 99), math.min(math.floor(y), 99)
  return cx * 100 + cy
end

-- The cell's centre in map percent.
function Places.Centre(cell)
  cell = whole(cell)
  if not cell or cell < 0 or cell > 9999 then
    return nil
  end
  return math.floor(cell / 100) + 0.5, cell % 100 + 0.5
end

--------------------------------------------------------------------------------
-- Size, measured the way the client writes saved variables (the model is Ledger.Serialise)
--------------------------------------------------------------------------------

local sortedKeys = ItemTree.Util.SortedKeys
local keyText = ItemTree.Util.KeyText
local valueText = ItemTree.Util.ValueText

-- A rough copy of the client's saved variables writer: one entry a line, a tab per level,
-- ["key"] or [number] = value, a comma after each. depth is the level the table itself sits at.
-- The specs measure the store with it; the addon never writes it anywhere.
function Places.Serialise(value, depth)
  depth = depth or 0
  if type(value) ~= "table" then
    return valueText(value)
  end
  local out = { "{\n" }
  local indent = string.rep("\t", depth + 1)
  for _, key in ipairs(sortedKeys(value)) do
    out[#out + 1] = indent .. keyText(key) .. " = " .. Places.Serialise(value[key], depth + 1) .. ",\n"
  end
  out[#out + 1] = string.rep("\t", depth) .. "}"
  return table.concat(out)
end

-- #Places.Serialise(value, depth), worked out without building the string.
function Places.Bytes(value, depth)
  depth = depth or 0
  if type(value) ~= "table" then
    return #valueText(value)
  end
  local total = 3 + depth
  local indent = depth + 1
  for key, inner in pairs(value) do
    total = total + indent + #keyText(key) + 3 + Places.Bytes(inner, depth + 1) + 2
  end
  return total
end

-- One key line as it sits in the file at depth: its tabs, key, " = ", value and ",\n".
local function lineBytes(key, value, depth)
  return depth + #keyText(key) + 3 + Places.Bytes(value, depth) + 2
end

-- The store sits one level down, under ["places"] in ItemTreeDB; kinds at 2, ids at 3, maps at 4.
local STORE_DEPTH, ID_DEPTH = 1, 3

local function isMapKey(key, value)
  return type(key) == "number" and type(value) == "table"
end

-- Calls fn(layer, mapId, cells) for every map of entry: its plain maps (layer nil), then the maps
-- of each layer it carries (brief R14), "g" before "h".
local LAYER_ORDER = { "g", "h" }
local function eachMap(entry, fn)
  for mapId, cells in pairs(entry) do
    if isMapKey(mapId, cells) then
      fn(nil, mapId, cells)
    end
  end
  for _, layer in ipairs(LAYER_ORDER) do
    local maps = entry[layer]
    if type(maps) == "table" then
      for mapId, cells in pairs(maps) do
        if isMapKey(mapId, cells) then
          fn(layer, mapId, cells)
        end
      end
    end
  end
end

-- The cells of mapId in layer (nil the plain maps) of entry, or nil.
local function cellsOf(entry, layer, mapId)
  local holder = entry
  if layer ~= nil then
    holder = entry[layer]
  end
  local cells = type(holder) == "table" and holder[mapId] or nil
  if isMapKey(mapId, cells) then
    return cells
  end
  return nil
end

-- Clears mapId from layer (nil the plain maps) of entry, and the layer itself once it is empty.
local function clearMap(entry, layer, mapId)
  if layer == nil then
    entry[mapId] = nil
    return
  end
  local maps = entry[layer]
  if type(maps) == "table" then
    maps[mapId] = nil
    if next(maps) == nil then
      entry[layer] = nil
    end
  end
end

local function mapTotal(cells)
  local total = 0
  for _, count in pairs(cells) do
    total = total + (tonumber(count) or 0)
  end
  return total
end

-- The store's size in bytes as last measured, kept in memory only so that Add does not walk the
-- whole store on every sighting. Places.Size measures from scratch and refreshes it.
local tallies = setmetatable({}, { __mode = "k" })

-- The order the byte budget lets pairs go in (cutToBudget), kept per store between sightings so a
-- store at its cap does not gather and scan every pair on each one. In memory only, and built
-- afresh whenever Places.Size measures the store, the same moment the tally above is.
local queues = setmetatable({}, { __mode = "k" })

-- { bytes, kb, ids, pairs, cells, budget } for the store, kb to one decimal place, and per kind
-- counts of ids in byKind.
function Places.Size(store)
  local out = { bytes = 0, kb = 0, ids = 0, pairs = 0, cells = 0, byKind = {}, budget = Places.MAX_BYTES }
  if type(store) ~= "table" then
    return out
  end
  out.bytes = lineBytes("places", store, STORE_DEPTH)
  for kind, ids in pairs(store) do
    if type(ids) == "table" then
      local count = 0
      for _, entry in pairs(ids) do
        if type(entry) == "table" then
          count = count + 1
          eachMap(entry, function(_, _, cells)
            out.pairs = out.pairs + 1
            for _ in pairs(cells) do
              out.cells = out.cells + 1
            end
          end)
        end
      end
      out.byKind[kind] = count
      out.ids = out.ids + count
    end
  end
  out.kb = math.floor(out.bytes / 1024 * 10 + 0.5) / 10
  tallies[store] = out.bytes
  queues[store] = nil
  return out
end

--------------------------------------------------------------------------------
-- The cut: 8 cells per map, then the byte budget
--------------------------------------------------------------------------------

-- The cell to drop from a map: the lowest count, ties the highest cell number. keep is never it.
local function weakestCell(cells, keep)
  local worst, worstCount = nil, nil
  for cell, count in pairs(cells) do
    if cell ~= keep then
      count = tonumber(count) or 0
      if worst == nil or count < worstCount or (count == worstCount and cell > worst) then
        worst, worstCount = cell, count
      end
    end
  end
  return worst
end

local function cellCount(cells)
  local n = 0
  for _ in pairs(cells) do
    n = n + 1
  end
  return n
end

local function cutCells(cells, keep)
  while cellCount(cells) > Places.MAX_CELLS do
    local drop = weakestCell(cells, keep)
    if drop == nil then
      return
    end
    cells[drop] = nil
  end
end

local function hasMaps(entry)
  for key, value in pairs(entry) do
    if isMapKey(key, value) then
      return true
    end
  end
  for layer in pairs(Places.LAYERS) do
    local maps = entry[layer]
    if type(maps) == "table" then
      for key, value in pairs(maps) do
        if isMapKey(key, value) then
          return true
        end
      end
    end
  end
  return false
end

-- True when pair a should go before pair b.
local function weaker(a, b)
  if a.total ~= b.total then
    return a.total < b.total
  end
  if a.day ~= b.day then
    return a.day < b.day
  end
  if a.kind ~= b.kind then
    return a.kind > b.kind
  end
  if a.id ~= b.id then
    -- A node's id is its name (brief R12): within one kind the ids share a type, and a store some
    -- other hand mixed up still orders, by type first.
    local ta, tb = type(a.id), type(b.id)
    if ta ~= tb then
      return ta > tb
    end
    return a.id > b.id
  end
  -- Brief R14: a layer's map (a gather or a hover) after the plain map of the same number.
  local la, lb = a.layer or "", b.layer or ""
  if la ~= lb then
    return la > lb
  end
  return a.map > b.map
end

-- A binary heap of pairs, the weakest first.
local function heapPush(heap, pair)
  local at = #heap + 1
  heap[at] = pair
  while at > 1 do
    local parent = math.floor(at / 2)
    if not weaker(heap[at], heap[parent]) then
      break
    end
    heap[at], heap[parent] = heap[parent], heap[at]
    at = parent
  end
end

local function heapPop(heap)
  local count = #heap
  if count == 0 then
    return nil
  end
  local top = heap[1]
  heap[1] = heap[count]
  heap[count] = nil
  count = count - 1
  local at = 1
  while true do
    local left, right, least = at * 2, at * 2 + 1, at
    if left <= count and weaker(heap[left], heap[least]) then
      least = left
    end
    if right <= count and weaker(heap[right], heap[least]) then
      least = right
    end
    if least == at then
      break
    end
    heap[at], heap[least] = heap[least], heap[at]
    at = least
  end
  return top
end

-- One id and map pair as the cut orders it, out of the store as it stands, or nil where the store
-- no longer holds it.
local function pairOf(store, kind, id, mapId, layer)
  local ids = store[kind]
  local entry = type(ids) == "table" and ids[id] or nil
  local cells = type(entry) == "table" and cellsOf(entry, layer, mapId) or nil
  if not cells then
    return nil
  end
  return {
    kind = tostring(kind),
    rawKind = kind,
    id = id,
    layer = layer,
    map = mapId,
    day = whole(entry.d) or 0,
    total = mapTotal(cells),
  }
end

-- Every pair in the store, weakest first: the queue the cut takes pairs off.
local function buildQueue(store)
  local queue = {}
  for kind, ids in pairs(store) do
    if type(ids) == "table" then
      for id, entry in pairs(ids) do
        if type(entry) == "table" then
          local day = whole(entry.d) or 0
          eachMap(entry, function(layer, mapId, cells)
            queue[#queue + 1] = {
              kind = tostring(kind),
              rawKind = kind,
              id = id,
              layer = layer,
              map = mapId,
              day = day,
              total = mapTotal(cells),
            }
          end)
        end
      end
    end
  end
  table.sort(queue, weaker)
  return queue
end

local function samePlace(a, b)
  return a.total == b.total and a.day == b.day
end

-- Drops the weakest id and map pairs until the store is within the budget. keep, where given, is
-- { kind, id, map }, the pair just written, which never goes. size is the store's size where the
-- caller knows it. Answers how many pairs went.
--
-- The pairs come off a queue kept for the store between calls (queues): Places.Add puts a pair
-- in whenever it is new or its total went down, and a sighting otherwise only makes a pair
-- stronger (a higher total, a later day). So every pair has an entry no stronger than the pair
-- itself, and an entry is checked against the store when it comes up: a pair gone is skipped,
-- one that has grown stronger is put back where it now goes, and one weaker than its entry
-- already has a truer entry of its own. The pairs that go, and their order, are what a scan of
-- every pair would choose.
local function cutToBudget(store, keep, size)
  size = size or Places.Size(store).bytes
  if size <= Places.MAX_BYTES then
    tallies[store] = size
    return 0
  end
  local queue = queues[store]
  if not queue then
    queue = buildQueue(store)
    queues[store] = queue
  end
  local dropped, aside = 0, nil
  while size > Places.MAX_BYTES do
    local held = heapPop(queue)
    if not held then
      break
    end
    local pair = pairOf(store, held.rawKind, held.id, held.map, held.layer)
    if pair then
      if not samePlace(pair, held) then
        if weaker(held, pair) then
          heapPush(queue, pair)
        end
      elseif
        keep
        and keep.kind == pair.rawKind
        and keep.id == pair.id
        and keep.map == pair.map
        and keep.layer == pair.layer
      then
        aside = held
      else
        local ids = store[pair.rawKind]
        local entry = ids[pair.id]
        local before = lineBytes(pair.id, entry, ID_DEPTH)
        clearMap(entry, pair.layer, pair.map)
        local after = 0
        if hasMaps(entry) then
          after = lineBytes(pair.id, entry, ID_DEPTH)
        else
          ids[pair.id] = nil
        end
        size = size - before + after
        dropped = dropped + 1
      end
    end
  end
  if aside then
    heapPush(queue, aside)
  end
  tallies[store] = size
  return dropped
end

--------------------------------------------------------------------------------
-- Writing, reading, merging
--------------------------------------------------------------------------------

-- Adds one sighting: 1 to the cell (x, y in map percent) of id on mapId under kind, the day kept
-- as the id's last touched, then the cell cut and the byte budget. labels, optional, is
-- { n = name, k = trains } (brief R9): each one Places.Label accepts replaces the entry's own, so
-- the newest window's words win. layer, optional (brief R14), is one of Places.LAYERS: the cell
-- goes under entry[layer][mapId] rather than entry[mapId]. Answers true when written.
function Places.Add(store, kind, id, mapId, x, y, day, labels, layer)
  if type(store) ~= "table" or type(kind) ~= "string" or kind == "" then
    return false
  end
  if layer ~= nil and not Places.LAYERS[layer] then
    return false
  end
  id, mapId = entryId(kind, id), positive(mapId)
  local cell = Places.Cell(x, y)
  if not id or not mapId or not cell then
    return false
  end
  local size = tallies[store] or Places.Size(store).bytes
  if type(store[kind]) ~= "table" then
    if store[kind] ~= nil then
      size = size - lineBytes(kind, store[kind], 2)
    end
    store[kind] = {}
    size = size + lineBytes(kind, store[kind], 2)
  end
  local ids = store[kind]
  if ids[id] ~= nil then
    size = size - lineBytes(id, ids[id], ID_DEPTH)
  end
  if type(ids[id]) ~= "table" then
    ids[id] = {}
  end
  local entry = ids[id]
  local holder = entry
  if layer ~= nil then
    if type(entry[layer]) ~= "table" then
      entry[layer] = {}
    end
    holder = entry[layer]
  end
  if type(holder[mapId]) ~= "table" then
    holder[mapId] = {}
  end
  local cells = holder[mapId]
  local queue = queues[store]
  local fresh = next(cells) == nil
  local total = queue and not fresh and mapTotal(cells) or nil
  cells[cell] = (tonumber(cells[cell]) or 0) + 1
  cutCells(cells, cell)
  day = whole(day)
  if day and day >= 0 and (whole(entry.d) or -1) < day then
    entry.d = day
  end
  if type(labels) == "table" then
    for _, field in ipairs(Places.LABELS) do
      local value = Places.Label(labels[field])
      if value then
        entry[field] = value
      end
    end
  end
  size = size + lineBytes(id, entry, ID_DEPTH)
  -- A new pair joins the kept queue, and so does one whose total the cell cut took down; any other
  -- sighting only made the pair stronger, which the queue finds out when it comes up.
  if queue and (fresh or mapTotal(cells) < total) then
    heapPush(queue, pairOf(store, kind, id, mapId, layer))
  end
  cutToBudget(store, { kind = kind, id = id, map = mapId, layer = layer }, size)
  return true
end

-- Brief R14: takes one sighting back, 1 off cell of id on mapId under kind, in layer (one of
-- Places.LAYERS, or nil for the plain maps). A cell left at 0 goes, then a map left with no cells,
-- a layer left with no maps and an id left with no maps at all (its labels and day with it). The
-- day is left as it is. Answers true when a count was taken off.
function Places.Remove(store, kind, id, mapId, cell, layer)
  if type(store) ~= "table" or type(kind) ~= "string" or (layer ~= nil and not Places.LAYERS[layer]) then
    return false
  end
  id, mapId, cell = entryId(kind, id), positive(mapId), whole(cell)
  local ids = store[kind]
  local entry = id and type(ids) == "table" and ids[id] or nil
  if type(entry) ~= "table" or not mapId or not cell then
    return false
  end
  local cells = cellsOf(entry, layer, mapId)
  local count = cells and tonumber(cells[cell]) or nil
  if not count or count <= 0 then
    return false
  end
  local tally = tallies[store]
  local before = lineBytes(id, entry, ID_DEPTH)
  if count > 1 then
    cells[cell] = count - 1
  else
    cells[cell] = nil
    if next(cells) == nil then
      clearMap(entry, layer, mapId)
    end
  end
  local after = 0
  if hasMaps(entry) then
    after = lineBytes(id, entry, ID_DEPTH)
  else
    ids[id] = nil
  end
  if tally then
    tallies[store] = tally - before + after
  end
  -- The pair's total went down, so the kept queue gets an entry no stronger than it now is.
  local queue = queues[store]
  local pair = queue and pairOf(store, kind, id, mapId, layer) or nil
  if pair then
    heapPush(queue, pair)
  end
  return true
end

-- Brief R14: whether two cells are within `within` cells of each other on the grid, the x cells
-- and the y cells each at most that far apart. Pure.
function Places.Near(a, b, within)
  a, b, within = whole(a), whole(b), tonumber(within)
  if not a or not b or not within or a < 0 or b < 0 or a > 9999 or b > 9999 then
    return false
  end
  local dx = math.abs(math.floor(a / 100) - math.floor(b / 100))
  local dy = math.abs(a % 100 - b % 100)
  return dx <= within and dy <= within
end

-- The map and the cell with the highest count for id under kind, as { map, x, y, count } with x, y
-- the cell's centre in map percent, or nil. Ties: the lowest map id, then the lowest cell.
function Places.Best(store, kind, id)
  local ids = type(store) == "table" and store[kind]
  local entry = type(ids) == "table" and ids[id]
  if type(entry) ~= "table" then
    return nil
  end
  local bestMap, bestCell, bestCount = nil, nil, nil
  for mapId, cells in pairs(entry) do
    if isMapKey(mapId, cells) then
      for cell, count in pairs(cells) do
        count = tonumber(count) or 0
        local better = bestCount == nil
          or count > bestCount
          or (count == bestCount and (mapId < bestMap or (mapId == bestMap and cell < bestCell)))
        if better then
          bestMap, bestCell, bestCount = mapId, cell, count
        end
      end
    end
  end
  if not bestMap then
    return nil
  end
  local x, y = Places.Centre(bestCell)
  if not x then
    return nil
  end
  return { map = bestMap, x = x, y = y, count = bestCount }
end

local function addInto(out, store, labelDays)
  if type(store) ~= "table" then
    return
  end
  for kind, ids in pairs(store) do
    if type(kind) == "string" and type(ids) == "table" then
      out[kind] = out[kind] or {}
      for id, entry in pairs(ids) do
        if type(entry) == "table" and entryId(kind, id) == id then
          local target = out[kind][id] or {}
          out[kind][id] = target
          local day = whole(entry.d)
          -- Brief R9: a label from the entry touched later wins; on the same day (or with no
          -- day) the lower text, so Merge(a, b) still equals Merge(b, a). labelDays holds the
          -- day of the entry each kept label came from.
          local mine = day or -1
          local from = labelDays[target] or {}
          labelDays[target] = from
          for _, field in ipairs(Places.LABELS) do
            local value = Places.Label(entry[field])
            local held, theirs = target[field], from[field] or -1
            if value and (held == nil or mine > theirs or (mine == theirs and value < held)) then
              target[field] = value
              from[field] = mine
            end
          end
          if day and (whole(target.d) or -1) < day then
            target.d = day
          end
          eachMap(entry, function(layer, mapId, cells)
            if positive(mapId) ~= mapId then
              return
            end
            local holder = target
            if layer ~= nil then
              holder = target[layer] or {}
              target[layer] = holder
            end
            local into = holder[mapId] or {}
            holder[mapId] = into
            for cell, count in pairs(cells) do
              cell, count = whole(cell), positive(count)
              if cell and count and cell >= 0 and cell <= 9999 then
                into[cell] = (into[cell] or 0) + count
              end
            end
          end)
        end
      end
    end
  end
end

-- A new store: a and b summed cell by cell, then every map cut to the best cells and the whole to
-- the byte budget. Neither input is changed, and Merge(a, b) equals Merge(b, a).
function Places.Merge(a, b)
  local out, labelDays = {}, {}
  addInto(out, a, labelDays)
  addInto(out, b, labelDays)
  for _, ids in pairs(out) do
    for id, entry in pairs(ids) do
      local empty = {}
      eachMap(entry, function(layer, mapId, cells)
        cutCells(cells, nil)
        if next(cells) == nil then
          empty[#empty + 1] = { layer, mapId }
        end
      end)
      for _, gone in ipairs(empty) do
        clearMap(entry, gone[1], gone[2])
      end
      for layer in pairs(Places.LAYERS) do
        if type(entry[layer]) == "table" and next(entry[layer]) == nil then
          entry[layer] = nil
        end
      end
      if not hasMaps(entry) then
        ids[id] = nil
      end
    end
  end
  cutToBudget(out, nil)
  return out
end

-- How many ids kind holds.
function Places.Count(store, kind)
  local size = Places.Size(store)
  return size.byKind[kind] or 0
end

-- The one line /itemtree debug and /itemtree report carry. Diagnostic, so not translated. Pure.
function Places.ReportLine(store)
  local size = Places.Size(store)
  return string.format(
    "Places: %.1f KB of %d KB budget, %d entrances recorded",
    size.kb,
    math.floor(Places.MAX_BYTES / 1024),
    size.byKind[Places.ENTRANCE] or 0
  )
end

return Places
