-- Brief L1: the loot ledger. A small local count of what each creature, node, container, vendor
-- and quest gave the player, kept so that drop rates can be worked out one day (the shared finds
-- plan will read it). Today it only has to exist, stay small and stay private.
--
-- Counts only, never events. No list of loot windows, no clock times, no chat line per loot and
-- nothing printed unless the player types /itemtree ledger. No character, realm or account name,
-- no position. Days are whole days since the epoch. The store is ItemTreeDB.ledger:
--
--   creature[npcId]    = { w = loot windows, i = { [itemId] = windows it was in },
--                          q = { [itemId] = quantity summed, only where that differs from i },
--                          g = { w, i, q } for what was gathered off a corpse already looted
--                          (skinning, mining or herbalism on a creature; brief SK1: or any
--                          corpse the player's own such cast opened), only once it happens,
--                          k = kills (brief R4, a party kill the combat log names),
--                          mw = loot windows that held money, m = the copper they held (only
--                          what could be read: a window whose amount could not counts in mw alone),
--                          iqw = { [itemId] = windows seen while the item was a current quest
--                          objective, from a creature already known to drop it },
--                          iq = { [itemId] = those windows the item was in } }
--   object[objectId]   the same w, i, q shape: mining and herb nodes, chests, anything a
--                      GameObject GUID names
--   container[itemId]  the same shape, per open of an item from the bags
--   fishing[mapId]     the same shape, per catch, keyed by the map the player fished on
--   disenchant[itemId] the same shape, per Disenchant cast, keyed by the item that went in
--   vendor[npcId]      = { seen = visits, f = first day, l = last day,
--                          i = { [itemId] = price in copper }, c = { [itemId] = currency id },
--                          s = { [itemId] = stock } for limited stock only (absent means -1,
--                          unlimited), a = { [itemId] = day first seen } only where later than
--                          f, d = { [itemId] = day last seen } only where earlier than l }
--   quest[questId]     = { t = turn ins, r = { [itemId] = times offered on the turn in panel } }
--
-- Every sub table and every count is left out while it is empty, so an entry costs what it holds.
-- A drop rate is i / w among corpses that had something; k is the denominator for a rate per kill
-- (i / k), and iq / iqw is the rate for a quest item while its quest was in the log.
--
-- Bounds. At most 200 items per source (Ledger.MAX_ITEMS) and 5,000 sources (Ledger.MAX_SOURCES),
-- and a size budget (Ledger.MAX_BYTES) measured the way the client writes saved variables, which
-- is the bound that holds the file down: 5,000 sources of 200 items each would be tens of
-- megabytes, so the byte budget is what binds first. When a cap is hit the least seen goes: in a
-- source the item in the fewest windows (for a vendor, the one seen longest ago; for a quest, the
-- reward offered fewest times), and across the ledger the source with the fewest windows, visits
-- or turn ins. The one just counted is never the one dropped. Trimming goes down to
-- Ledger.TRIM_TO of the cap so it is not repeated on every window after.
--
-- The whole ledger follows the collector's setting ("Record what you see", collectorEnabled): off
-- records nothing, and turning it off keeps what is there. /itemtree ledger reset clears it.
--
-- An export (the back channel's job, later) would be this same table, keyed the same way, with
-- the data build beside it: counts and ids, nothing else. There is none yet.
--
-- Everything above the divider is pure and runs under busted. The event half below it listens on
-- a frame of its own for LOOT_OPENED, MERCHANT_SHOW, MERCHANT_UPDATE, QUEST_COMPLETE and
-- QUEST_TURNED_IN and reads only what the open window shows: the loot slots, the merchant's own
-- rows, the turn in panel's rewards. Nothing is asked about an item or a creature. Brief R4's
-- kills and disenchant windows arrive from UI/CollectorHooks.lua (Ledger.OnKill and
-- Ledger.OnDisenchant), which already watches the combat log's owner and the Disenchant cast.
local _, ItemTree = ...

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local Ledger = {}
ItemTree.Ledger = Ledger

Ledger.MAX_ITEMS = 200
Ledger.MAX_SOURCES = 5000
-- The ledger's share of the saved variables file, in bytes as the client writes them.
Ledger.MAX_BYTES = 1024 * 1024
-- A cap that is hit trims down to this share of itself.
Ledger.TRIM_TO = 0.95
-- How many corpses a session remembers, so that opening one again is not a second window.
Ledger.RECENT_CORPSES = 32
Ledger.CONFIRM_WORD = "confirm"

local DAY = 86400

-- The five kinds counted per loot window, and the order every kind is walked in.
Ledger.LOOT_KINDS = { "creature", "object", "container", "fishing", "disenchant" }
Ledger.KINDS = { "creature", "object", "container", "fishing", "disenchant", "vendor", "quest" }

local LOOT_KIND = { creature = true, object = true, container = true, fishing = true, disenchant = true }

-- The per item tables each kind of source has, the first one being the one the others follow.
-- A loot source's iq and iqw (brief R4) only ever name items i names, so they go with it.
local ITEM_TABLES = {
  loot = { "i", "q", "iq", "iqw" },
  vendor = { "i", "c", "s", "a", "d" },
  quest = { "r" },
}

local function tablesFor(kind)
  if kind == "vendor" or kind == "quest" then
    return ITEM_TABLES[kind]
  end
  return ITEM_TABLES.loot
end

local whole = ItemTree.Util.Whole
local positive = ItemTree.Util.Positive
-- Brief SV1: whether a client value may be read at all (Core/Util.lua Util.CanRead). A GUID the
-- client keeps secret in combat raises as a table key or in a compare, so it is no source here.
local canRead = ItemTree.Util.CanRead

-- Whole days since the epoch for a time in seconds, or nil. No clock time is ever stored.
function Ledger.Day(now)
  now = tonumber(now)
  if not now or now < 0 then
    return nil
  end
  return math.floor(now / DAY)
end

-- The store with a table for every kind, made in place. A nil or broken store gives a new one.
function Ledger.Ensure(store)
  if type(store) ~= "table" then
    store = {}
  end
  for _, kind in ipairs(Ledger.KINDS) do
    if type(store[kind]) ~= "table" then
      store[kind] = {}
    end
  end
  return store
end

--------------------------------------------------------------------------------
-- Size, measured the way the client writes saved variables
--------------------------------------------------------------------------------

local sortedKeys = ItemTree.Util.SortedKeys
local keyText = ItemTree.Util.KeyText
local valueText = ItemTree.Util.ValueText

-- A rough copy of the client's saved variables writer: one entry a line, a tab per level,
-- ["key"] or [number] = value, a comma after each. depth is the level the table itself sits at.
-- The specs measure the ledger with it; the addon never writes it anywhere.
function Ledger.Serialise(value, depth)
  depth = depth or 0
  if type(value) ~= "table" then
    return valueText(value)
  end
  local out = { "{\n" }
  local indent = string.rep("\t", depth + 1)
  for _, key in ipairs(sortedKeys(value)) do
    out[#out + 1] = indent .. keyText(key) .. " = " .. Ledger.Serialise(value[key], depth + 1) .. ",\n"
  end
  out[#out + 1] = string.rep("\t", depth) .. "}"
  return table.concat(out)
end

-- #Ledger.Serialise(value, depth), worked out without building the string.
function Ledger.Bytes(value, depth)
  depth = depth or 0
  if type(value) ~= "table" then
    return #valueText(value)
  end
  local total = 3 + depth -- "{\n", then the closing tabs and "}"
  local indent = depth + 1
  for key, inner in pairs(value) do
    total = total + indent + #keyText(key) + 3 + Ledger.Bytes(inner, depth + 1) + 2
  end
  return total
end

-- One source as it sits in the file: its key line, its table and the ",\n" after it. Sources sit
-- three levels down (ItemTreeDB, ledger, kind).
local SOURCE_DEPTH = 3

function Ledger.SourceBytes(id, source)
  return SOURCE_DEPTH + #keyText(id) + 3 + Ledger.Bytes(source, SOURCE_DEPTH) + 2
end

local function countEntries(source, kind)
  local entries = 0
  for _, name in ipairs(tablesFor(kind)) do
    local map = source[name]
    if type(map) == "table" then
      for _ in pairs(map) do
        entries = entries + 1
      end
    end
  end
  if type(source.g) == "table" then
    entries = entries + countEntries(source.g, kind)
  end
  return entries
end

-- The running totals for one store, kept in memory only and worked out from scratch the first
-- time a store is counted: sources, per item entries and bytes, plus each source's own bytes and
-- entries so that a change to one source is a change to the totals.
local tallies = setmetatable({}, { __mode = "k" })

local function skeletonBytes(store)
  local empty = {}
  for _, kind in ipairs(Ledger.KINDS) do
    if store[kind] then
      empty[kind] = {}
    end
  end
  -- The ledger sits one level down, under ["ledger"] in ItemTreeDB.
  return 1 + #keyText("ledger") + 3 + Ledger.Bytes(empty, 1) + 2
end

function Ledger.Recount(store)
  store = Ledger.Ensure(store)
  local tally = { sources = 0, entries = 0, bytes = skeletonBytes(store), per = setmetatable({}, { __mode = "k" }) }
  for _, kind in ipairs(Ledger.KINDS) do
    for id, source in pairs(store[kind]) do
      if type(source) == "table" then
        local bytes = Ledger.SourceBytes(id, source)
        local entries = countEntries(source, kind)
        tally.per[source] = { bytes = bytes, entries = entries }
        tally.sources = tally.sources + 1
        tally.entries = tally.entries + entries
        tally.bytes = tally.bytes + bytes
      end
    end
  end
  tallies[store] = tally
  return tally
end

local function tallyOf(store)
  return tallies[store] or Ledger.Recount(store)
end

-- Folds one source's new size into the totals after it changed.
local function retally(store, kind, id, source)
  local tally = tallyOf(store)
  local before = tally.per[source]
  if before then
    tally.bytes = tally.bytes - before.bytes
    tally.entries = tally.entries - before.entries
  else
    tally.sources = tally.sources + 1
  end
  local now = { bytes = Ledger.SourceBytes(id, source), entries = countEntries(source, kind) }
  tally.per[source] = now
  tally.bytes = tally.bytes + now.bytes
  tally.entries = tally.entries + now.entries
end

local function untally(store, source)
  local tally = tallyOf(store)
  local before = tally.per[source]
  if before then
    tally.bytes = tally.bytes - before.bytes
    tally.entries = tally.entries - before.entries
    tally.sources = tally.sources - 1
    tally.per[source] = nil
  end
end

-- { sources, entries, bytes, kb } for the store: kb to one decimal place.
function Ledger.Size(store)
  store = Ledger.Ensure(store)
  local tally = tallyOf(store)
  return {
    sources = tally.sources,
    entries = tally.entries,
    bytes = tally.bytes,
    kb = math.floor(tally.bytes / 1024 * 10 + 0.5) / 10,
  }
end

--------------------------------------------------------------------------------
-- Caps
--------------------------------------------------------------------------------

-- How often a source was counted, which is what "least seen" compares.
local function weightOf(kind, source)
  if kind == "vendor" then
    return tonumber(source.seen) or 0
  end
  if kind == "quest" then
    local most = 0
    for _, times in pairs(type(source.r) == "table" and source.r or {}) do
      if times > most then
        most = times
      end
    end
    return (tonumber(source.t) or 0) + most
  end
  local gathered = type(source.g) == "table" and tonumber(source.g.w) or 0
  return (tonumber(source.w) or 0) + gathered
end

local function removeItem(target, names, itemId)
  for _, name in ipairs(names) do
    local map = target[name]
    if type(map) == "table" then
      map[itemId] = nil
      if next(map) == nil then
        target[name] = nil
      end
    end
  end
end

-- How long ago a vendor row was last seen, as a score where lower goes first.
local function vendorScore(source, itemId)
  local seen = type(source.d) == "table" and source.d[itemId] or nil
  return seen or tonumber(source.l) or 0
end

-- Drops the least seen items from one source (or its g table) until it holds at most
-- Ledger.MAX_ITEMS, never one of the items in keep ({ [itemId] = true }, the ones just counted).
-- Called once per window, visit or panel, not once per item. Answers how many went.
local function capItems(kind, target, source, keep)
  local names = tablesFor(kind)
  local main = target[names[1]]
  if type(main) ~= "table" then
    return 0
  end
  local ids, total = {}, 0
  for itemId in pairs(main) do
    total = total + 1
    if not keep[itemId] then
      ids[#ids + 1] = itemId
    end
  end
  local over = math.min(total - Ledger.MAX_ITEMS, #ids)
  if over <= 0 then
    return 0
  end
  local score
  if kind == "vendor" then
    score = function(itemId)
      return vendorScore(source, itemId)
    end
  else
    score = function(itemId)
      return main[itemId]
    end
  end
  table.sort(ids, function(a, b)
    local sa, sb = score(a), score(b)
    if sa ~= sb then
      return sa < sb
    end
    return a < b
  end)
  for index = 1, over do
    removeItem(target, names, ids[index])
  end
  return over
end

-- Drops the least seen sources, never keep, while the ledger is over either cap. Answers how many
-- went. Only runs once a cap is crossed, and then trims to Ledger.TRIM_TO of it.
function Ledger.Trim(store, keep)
  store = Ledger.Ensure(store)
  local tally = tallyOf(store)
  if tally.sources <= Ledger.MAX_SOURCES and tally.bytes <= Ledger.MAX_BYTES then
    return 0
  end
  local maxSources = math.floor(Ledger.MAX_SOURCES * Ledger.TRIM_TO)
  local maxBytes = math.floor(Ledger.MAX_BYTES * Ledger.TRIM_TO)
  local all = {}
  for order, kind in ipairs(Ledger.KINDS) do
    for id, source in pairs(store[kind]) do
      if source ~= keep and type(source) == "table" then
        all[#all + 1] = { kind = kind, id = id, source = source, weight = weightOf(kind, source), order = order }
      end
    end
  end
  table.sort(all, function(a, b)
    if a.weight ~= b.weight then
      return a.weight < b.weight
    end
    if a.order ~= b.order then
      return a.order < b.order
    end
    return a.id < b.id
  end)
  local dropped = 0
  for _, entry in ipairs(all) do
    if tally.sources <= maxSources and tally.bytes <= maxBytes then
      break
    end
    store[entry.kind][entry.id] = nil
    untally(store, entry.source)
    dropped = dropped + 1
  end
  return dropped
end

-- After a source changed: its size into the totals, then the ledger wide caps.
local function settle(store, kind, id, source)
  retally(store, kind, id, source)
  Ledger.Trim(store, source)
end

--------------------------------------------------------------------------------
-- Loot windows
--------------------------------------------------------------------------------

-- The ledger kind and id a loot source GUID names: "creature" for a Creature or Vehicle GUID,
-- "object" for a GameObject and "container" for an Item (whose id the GUID does not carry, so it
-- is nil here and the client side asks the open item for it). nil for a player, a pet and
-- anything unreadable. Pure.
local GUID_KINDS = { Creature = "creature", Vehicle = "creature", GameObject = "object", Item = "container" }

function Ledger.SourceOf(guid)
  local privacy = ItemTree.Privacy
  if type(guid) ~= "string" or not privacy or type(privacy.ParseGuid) ~= "function" then
    return nil
  end
  local ok, guidKind, id = pcall(privacy.ParseGuid, guid)
  if not ok then
    return nil
  end
  local kind = GUID_KINDS[guidKind]
  if not kind then
    return nil
  end
  if kind == "container" then
    return kind, nil
  end
  id = positive(id)
  if not id then
    return nil
  end
  return kind, id
end

--------------------------------------------------------------------------------
-- Money (brief R4)
--------------------------------------------------------------------------------

-- The client states a money slot's amount only as text, one line per coin ("12 Silver\n34
-- Copper"), each written with its GOLD_AMOUNT, SILVER_AMOUNT or COPPER_AMOUNT format. There is
-- no call on the forever branch that answers the copper: LootFrame.lua reads the slot's text and
-- its isCoin flag, nothing else. So the amount is read back through the client's own formats.

local MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"

local function escapePattern(text)
  return (text:gsub(MAGIC, "%%%0"))
end

local trimText = ItemTree.Util.Trim

-- One coin format as the anchored patterns its shown text can take. "%d Gold" is one; a format
-- with a plural choice ("%d |4gold:golds;", the client's grammar escape, which it resolves to one
-- of the words before showing it) is one per word. A format with no number in it is none.
local function formatPatterns(format)
  if type(format) ~= "string" or format == "" then
    return {}
  end
  local forms = { format }
  local before, choices, after = format:match("^(.-)|4([^;]*);(.*)$")
  if before then
    forms = {}
    for word in (choices .. ":"):gmatch("([^:]*):") do
      forms[#forms + 1] = before .. word .. after
    end
  end
  local out = {}
  for _, form in ipairs(forms) do
    local head, tail = trimText(form):match("^(.-)%%[ds](.*)$")
    if head then
      out[#out + 1] = "^" .. escapePattern(head) .. "(%d+)" .. escapePattern(tail) .. "$"
    end
  end
  return out
end

-- The patterns for a list of { format, copper per unit }, as { { pattern, factor } }. The
-- client side hands it GOLD_AMOUNT, SILVER_AMOUNT and COPPER_AMOUNT. Pure.
function Ledger.MoneyPatterns(formats)
  local out = {}
  for _, entry in ipairs(type(formats) == "table" and formats or {}) do
    local factor = type(entry) == "table" and positive(entry[2]) or nil
    if factor then
      for _, pattern in ipairs(formatPatterns(entry[1])) do
        out[#out + 1] = { pattern, factor }
      end
    end
  end
  return out
end

-- The copper a money slot's text states, or nil when any line of it reads as none of the
-- patterns (a locale shape this does not know, or no text at all). Pure.
function Ledger.ParseMoney(text, patterns)
  if type(text) ~= "string" or type(patterns) ~= "table" or #patterns == 0 then
    return nil
  end
  local copper, lines = 0, 0
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    line = trimText(line)
    if line ~= "" then
      local amount = nil
      for _, entry in ipairs(patterns) do
        local number = line:match(entry[1])
        if number then
          amount = tonumber(number) * entry[2]
          break
        end
      end
      if not amount then
        return nil
      end
      copper = copper + amount
      lines = lines + 1
    end
  end
  if lines == 0 then
    return nil
  end
  return copper
end

--------------------------------------------------------------------------------
-- Loot windows, grouped by source
--------------------------------------------------------------------------------

-- The loot window's slots grouped into one window per source GUID. slots is a list of
--   { itemId = number or nil (money, currency), quantity = number, sources = { guid, count, ... },
--     money = true for a money slot, copper = the copper its text states, nil where unread }
-- which is what GetLootSlotLink, GetLootSlotInfo and GetLootSourceInfo say about each slot.
-- A slot with no source GUID is put on fallbackGuid when there is one. Answers a list of
--   { guid, kind, id, items = { [itemId] = quantity }, money = copper, true for money whose
--     amount could not be read, nil for none }
-- in the order the sources were first met. A source whose slots were all money still makes a
-- window, with no items: that window is part of the denominator.
--
-- A money slot's copper goes to its one source. A slot several corpses share (area loot) states
-- only the total, so each corpse's part is the quantity GetLootSourceInfo names for it, and only
-- where those parts add up to the total the text states; otherwise each corpse counts money
-- whose amount could not be read. Pure.
function Ledger.WindowsFromSlots(slots, fallbackGuid)
  local windows, byGuid = {}, {}
  local function add(guid, itemId, quantity)
    local window = byGuid[guid]
    if not window then
      local kind, id = Ledger.SourceOf(guid)
      if not kind then
        return nil
      end
      window = { guid = guid, kind = kind, id = id, items = {} }
      byGuid[guid] = window
      windows[#windows + 1] = window
    end
    if itemId then
      window.items[itemId] = (window.items[itemId] or 0) + (positive(quantity) or 1)
    end
    return window
  end
  local function addMoney(guid, copper)
    local window = add(guid, nil, nil)
    if not window then
      return
    end
    if copper and window.money ~= true then
      window.money = (window.money or 0) + copper
    else
      window.money = true
    end
  end
  local function moneySlot(slot, sources)
    local copper = positive(slot.copper)
    local guids, parts, sum = {}, {}, 0
    for index = 1, #sources, 2 do
      if type(sources[index]) == "string" then
        guids[#guids + 1] = sources[index]
        parts[#guids] = positive(sources[index + 1])
        sum = sum + (parts[#guids] or 0)
      end
    end
    if #guids == 0 and fallbackGuid then
      guids[1] = fallbackGuid
    end
    for index, guid in ipairs(guids) do
      local share = nil
      if #guids == 1 then
        share = copper
      elseif copper and sum == copper then
        share = parts[index]
      end
      addMoney(guid, share)
    end
  end
  for _, slot in ipairs(type(slots) == "table" and slots or {}) do
    if type(slot) == "table" and slot.money and not positive(slot.itemId) then
      moneySlot(slot, type(slot.sources) == "table" and slot.sources or {})
    elseif type(slot) == "table" then
      local itemId = positive(slot.itemId)
      local sources = type(slot.sources) == "table" and slot.sources or {}
      local any = false
      for index = 1, #sources, 2 do
        local guid = sources[index]
        if type(guid) == "string" then
          any = true
          add(guid, itemId, sources[index + 1] or slot.quantity)
        end
      end
      if not any and fallbackGuid then
        add(fallbackGuid, itemId, slot.quantity)
      end
    end
  end
  if #windows == 0 and fallbackGuid then
    -- An empty window: nothing to ask a source about, so the fallback is the source.
    add(fallbackGuid, nil, nil)
  end
  return windows
end

local function sourceFor(store, kind, id)
  local map = store[kind]
  local source = map[id]
  if type(source) ~= "table" then
    source = {}
    map[id] = source
  end
  return source
end

-- Brief R4, for a creature's own window (not its g table). extra.money is the window's copper,
-- or true for money whose amount could not be read: mw goes up by one and m by the copper.
-- extra.objectives is { [itemId] = true } for the items that are a current quest objective:
-- each one this creature is known to drop (it is in i, this window included) counts the window
-- in iqw, and in iq as well when the item is in it.
local function countCreatureExtra(source, extra, counted)
  if extra.money then
    source.mw = (tonumber(source.mw) or 0) + 1
    local copper = positive(extra.money)
    if copper then
      source.m = (tonumber(source.m) or 0) + copper
    end
  end
  if type(extra.objectives) ~= "table" or type(source.i) ~= "table" then
    return
  end
  for itemId in pairs(extra.objectives) do
    itemId = positive(itemId)
    if itemId and source.i[itemId] then
      source.iqw = source.iqw or {}
      source.iqw[itemId] = (source.iqw[itemId] or 0) + 1
      if counted[itemId] then
        source.iq = source.iq or {}
        source.iq[itemId] = (source.iq[itemId] or 0) + 1
      end
    end
  end
end

-- One loot window on one source: w goes up by one, each item's window count by one and its
-- quantity by what dropped. sub "g" counts it into the source's gathered table instead. extra
-- (optional, a creature's own window only) is { money, objectives }: see countCreatureExtra.
-- Answers the source table. Pure.
function Ledger.CountLoot(store, kind, id, items, sub, extra)
  store = Ledger.Ensure(store)
  id = positive(id)
  if not LOOT_KIND[kind] or not id then
    return nil
  end
  local source = sourceFor(store, kind, id)
  local target = source
  if sub == "g" then
    if type(source.g) ~= "table" then
      source.g = {}
    end
    target = source.g
  end
  target.w = (tonumber(target.w) or 0) + 1
  local counted = {}
  for itemId, quantity in pairs(type(items) == "table" and items or {}) do
    itemId = positive(itemId)
    if itemId then
      counted[itemId] = true
      target.i = target.i or {}
      local before = target.i[itemId] or 0
      local summed = ((target.q and target.q[itemId]) or before) + (positive(quantity) or 1)
      target.i[itemId] = before + 1
      if summed ~= before + 1 then
        target.q = target.q or {}
        target.q[itemId] = summed
      elseif target.q then
        target.q[itemId] = nil
        if next(target.q) == nil then
          target.q = nil
        end
      end
    end
  end
  if kind == "creature" and target == source and type(extra) == "table" then
    countCreatureExtra(source, extra, counted)
  end
  capItems(kind, target, source, counted)
  settle(store, kind, id, source)
  return source
end

-- Brief R4: one kill of a creature, k up by one. Answers the creature's table. Pure.
function Ledger.CountKill(store, npcId)
  store = Ledger.Ensure(store)
  npcId = positive(npcId)
  if not npcId then
    return nil
  end
  local source = sourceFor(store, "creature", npcId)
  source.k = (tonumber(source.k) or 0) + 1
  settle(store, "creature", npcId, source)
  return source
end

-- The corpses this session already counted, by GUID, each with the item ids its first window
-- held. In memory only. Ledger.NewRecent makes an empty one.
function Ledger.NewRecent()
  return { order = {}, items = {} }
end

local function remember(recent, guid, items)
  local known = recent.items[guid]
  if not known then
    known = {}
    recent.items[guid] = known
    recent.order[#recent.order + 1] = guid
    while #recent.order > Ledger.RECENT_CORPSES do
      local oldest = table.remove(recent.order, 1)
      recent.items[oldest] = nil
    end
  end
  for itemId in pairs(items) do
    known[itemId] = true
  end
end

-- Counts one loot window's sources into the store. opts:
--   fishing   the map id when the client says this is fishing loot: every source in the window
--             (the bobber) becomes one catch on fishing[mapId]
--   recent    Ledger.NewRecent's table: a corpse opened again counts nothing, and one opened
--             again with an item its first window did not hold (skinning) counts into its g table
--   itemIdOf  function(guid) answering the item id for an Item GUID, or nil
--   skip      { [guid] = true } for sources that are not counted (a creature being pickpocketed)
--   objectives { [itemId] = true }, the items that are a current quest objective (brief R4)
--   gathered  brief SK1: true when the player's own Skinning (or creature Mining, Herb Gathering
--             or Engineering) cast opened the window: every creature in it counts into its g table,
--             even a corpse this session never opened before (one that had no loot of its own)
--   pocket    brief SK1: true when the player's own Pick Pocket cast opened it: no creature in it
--             counts at all, as with skip
-- Answers how many windows were counted. Pure apart from the calls it is handed.
function Ledger.CountWindows(store, windows, opts)
  opts = type(opts) == "table" and opts or {}
  windows = type(windows) == "table" and windows or {}
  local fishing = positive(opts.fishing)
  if fishing then
    if #windows == 0 then
      return 0
    end
    local items = {}
    for _, window in ipairs(windows) do
      for itemId, quantity in pairs(window.items) do
        items[itemId] = (items[itemId] or 0) + quantity
      end
    end
    Ledger.CountLoot(store, "fishing", fishing, items)
    return 1
  end
  local counted = 0
  for _, window in ipairs(windows) do
    local kind, id = window.kind, window.id
    if type(opts.skip) == "table" and opts.skip[window.guid] then
      id = nil
    elseif kind == "creature" and opts.pocket then
      id = nil
    elseif kind == "container" and not id and type(opts.itemIdOf) == "function" then
      local ok, answer = pcall(opts.itemIdOf, window.guid)
      id = ok and positive(answer) or nil
    end
    if id then
      local sub = nil
      local skip = false
      if kind == "creature" and opts.recent then
        local known = opts.recent.items[window.guid]
        if known then
          skip = true
          for itemId in pairs(window.items) do
            if not known[itemId] then
              skip = false
              sub = "g"
              break
            end
          end
        end
        remember(opts.recent, window.guid, window.items)
      end
      if kind == "creature" and opts.gathered and not skip then
        sub = "g"
      end
      local extra = nil
      if kind == "creature" and not sub then
        extra = { money = window.money, objectives = opts.objectives }
      end
      if not skip and Ledger.CountLoot(store, kind, id, window.items, sub, extra) then
        counted = counted + 1
      end
    end
  end
  return counted
end

--------------------------------------------------------------------------------
-- Vendors
--------------------------------------------------------------------------------

-- One look at a merchant's rows. rows is a list of
--   { itemId, price = copper, currency = currency id or nil, stock = number, -1 when unlimited }
-- visit is true for the window opening (MERCHANT_SHOW), which counts a visit and marks the day
-- each row the vendor had before and does not show now was last seen; false for a refresh while
-- it is open (MERCHANT_UPDATE), which only updates the rows. Answers the vendor's table. Pure.
function Ledger.CountVendor(store, npcId, rows, day, visit)
  store = Ledger.Ensure(store)
  npcId = positive(npcId)
  day = whole(day)
  if not npcId or not day then
    return nil
  end
  local source = sourceFor(store, "vendor", npcId)
  source.seen = tonumber(source.seen) or 0
  source.f = tonumber(source.f) or day
  source.l = tonumber(source.l) or day
  local present = {}
  for _, row in ipairs(type(rows) == "table" and rows or {}) do
    local itemId = type(row) == "table" and positive(row.itemId) or nil
    if itemId then
      present[itemId] = row
    end
  end
  if visit then
    local previous = source.l
    source.seen = source.seen + 1
    if type(source.i) == "table" then
      for itemId in pairs(source.i) do
        if not present[itemId] and not (source.d and source.d[itemId]) then
          source.d = source.d or {}
          source.d[itemId] = previous
        end
      end
    end
  end
  if day > source.l then
    source.l = day
  end
  for itemId, row in pairs(present) do
    source.i = source.i or {}
    local isNew = source.i[itemId] == nil
    source.i[itemId] = whole(row.price) or 0
    local currency = positive(row.currency)
    if currency then
      source.c = source.c or {}
      source.c[itemId] = currency
    else
      removeItem(source, { "c" }, itemId)
    end
    local stock = whole(row.stock)
    if stock and stock >= 0 then
      source.s = source.s or {}
      source.s[itemId] = stock
    else
      removeItem(source, { "s" }, itemId)
    end
    if isNew and day > source.f then
      source.a = source.a or {}
      source.a[itemId] = day
    end
    removeItem(source, { "d" }, itemId)
  end
  capItems("vendor", source, source, present)
  settle(store, "vendor", npcId, source)
  return source
end

--------------------------------------------------------------------------------
-- Quests
--------------------------------------------------------------------------------

-- The rewards on a quest's turn in panel, each counted once however often the list names it.
-- Answers the quest's table. Pure.
function Ledger.CountQuestOffer(store, questId, itemIds)
  store = Ledger.Ensure(store)
  questId = positive(questId)
  if not questId then
    return nil
  end
  local source = sourceFor(store, "quest", questId)
  source.t = tonumber(source.t) or 0
  local seen = {}
  for _, itemId in ipairs(type(itemIds) == "table" and itemIds or {}) do
    itemId = positive(itemId)
    if itemId and not seen[itemId] then
      seen[itemId] = true
      source.r = source.r or {}
      source.r[itemId] = (source.r[itemId] or 0) + 1
    end
  end
  capItems("quest", source, source, seen)
  settle(store, "quest", questId, source)
  return source
end

-- One turn in. Answers the quest's table. Pure.
function Ledger.CountTurnIn(store, questId)
  store = Ledger.Ensure(store)
  questId = positive(questId)
  if not questId then
    return nil
  end
  local source = sourceFor(store, "quest", questId)
  source.t = (tonumber(source.t) or 0) + 1
  settle(store, "quest", questId, source)
  return source
end

--------------------------------------------------------------------------------
-- Summary
--------------------------------------------------------------------------------

-- What /itemtree ledger prints, counted from the store:
--   { creature, object, container, fishing, disenchant, vendor, quest = sources of each kind,
--     windows, items (distinct item ids anywhere), visits, turnIns, kills, moneyWindows,
--     disenchants (Disenchant windows), sources, entries, kb }
function Ledger.Summary(store)
  store = Ledger.Ensure(store)
  local out = { windows = 0, visits = 0, turnIns = 0, kills = 0, moneyWindows = 0, disenchants = 0 }
  local items = {}
  local itemCount = 0
  local function note(map)
    for itemId in pairs(type(map) == "table" and map or {}) do
      if not items[itemId] then
        items[itemId] = true
        itemCount = itemCount + 1
      end
    end
  end
  for _, kind in ipairs(Ledger.KINDS) do
    local count = 0
    for _, source in pairs(store[kind]) do
      if type(source) == "table" then
        count = count + 1
        if LOOT_KIND[kind] then
          out.windows = out.windows + (tonumber(source.w) or 0)
          out.kills = out.kills + (tonumber(source.k) or 0)
          out.moneyWindows = out.moneyWindows + (tonumber(source.mw) or 0)
          if kind == "disenchant" then
            out.disenchants = out.disenchants + (tonumber(source.w) or 0)
          end
          note(source.i)
          if type(source.g) == "table" then
            out.windows = out.windows + (tonumber(source.g.w) or 0)
            note(source.g.i)
          end
        elseif kind == "vendor" then
          out.visits = out.visits + (tonumber(source.seen) or 0)
          note(source.i)
        else
          out.turnIns = out.turnIns + (tonumber(source.t) or 0)
          note(source.r)
        end
      end
    end
    out[kind] = count
  end
  out.items = itemCount
  local size = Ledger.Size(store)
  out.sources, out.entries, out.kb = size.sources, size.entries, size.kb
  return out
end

-- The six lines /itemtree ledger prints. Pure.
function Ledger.SummaryLines(store)
  local s = Ledger.Summary(store)
  local loot = s.creature + s.object + s.container + s.fishing
  return {
    string.format(
      L["Loot sources counted: %d (%d creatures, %d nodes and objects, %d containers, %d fishing spots)"],
      loot,
      s.creature,
      s.object,
      s.container,
      s.fishing
    ),
    string.format(L["Loot windows counted: %d"], s.windows),
    string.format(L["Different items counted: %d"], s.items),
    string.format(L["Vendors: %d, visited %d times"], s.vendor, s.visits),
    string.format(L["Quests: %d, handed in %d times. The ledger holds about %s KB."], s.quest, s.turnIns, s.kb),
    string.format(
      L["Kills counted: %d. Loot windows with money: %d. Items disenchanted: %d."],
      s.kills,
      s.moneyWindows,
      s.disenchants
    ),
  }
end

-- The one line /itemtree debug and /itemtree report carry. Pure.
function Ledger.ReportLine(store)
  local size = Ledger.Size(store)
  return string.format("Ledger: %d sources, %d entries, about %s KB", size.sources, size.entries, size.kb)
end

-- Empties the store in place, keeping one table per kind. Pure.
function Ledger.Reset(store)
  if type(store) ~= "table" then
    return Ledger.Ensure(nil)
  end
  for key in pairs(store) do
    store[key] = nil
  end
  Ledger.Ensure(store)
  Ledger.Recount(store)
  return store
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--
-- A frame of its own, registered at PLAYER_LOGIN the way UI/CollectorHooks.lua registers its
-- own, for five events. Every client call is looked up with rawget, type checked and pcall'd, so
-- this file loads with no WoW API present and a call this client lacks costs that one value.
--------------------------------------------------------------------------------

local function pass(ok, ...)
  if ok then
    return ...
  end
  return nil
end

local function call(name, ...)
  local fn = rawget(_G, name)
  if type(fn) ~= "function" then
    return nil
  end
  return pass(pcall(fn, ...))
end

local function apiCall(space, name, ...)
  local api = rawget(_G, space)
  if type(api) ~= "table" or type(api[name]) ~= "function" then
    return nil
  end
  return pass(pcall(api[name], ...))
end

-- Not Util.ItemIdFromLink (Core/Util.lua): this one answers only a positive, finite id, so
-- "item:0" reads as no id at all.
local function itemIdFromLink(link)
  if type(link) ~= "string" then
    return nil
  end
  return positive(link:match("item:(%d+)"))
end

-- ItemTreeDB.ledger, made if missing, or nil before saved variables are loaded.
function Ledger.Store()
  local db = ItemTree.db
  if type(db) ~= "table" then
    return nil
  end
  db.ledger = Ledger.Ensure(db.ledger)
  return db.ledger
end

function Ledger.Enabled()
  local settings = ItemTree.db and ItemTree.db.settings
  return type(settings) == "table" and settings.collectorEnabled and true or false
end

function Ledger.Today()
  local clock = rawget(_G, "time")
  if type(clock) ~= "function" then
    return nil
  end
  local ok, now = pcall(clock)
  return ok and Ledger.Day(now) or nil
end

Ledger.recent = Ledger.NewRecent()

-- The dead creature under the cursor or targeted, as a GUID, for a client without
-- GetLootSourceInfo or a window with no slots to ask about. Only a Creature or Vehicle GUID the
-- client says is dead; anything else is no source at all.
-- Brief SV1: a unit's GUID, or nil where the client has none or keeps it secret.
local function unitGuid(unit)
  local guid = call("UnitGUID", unit)
  if not canRead(guid) then
    return nil
  end
  return guid
end

-- Brief SV1: GetLootSourceInfo's guid, quantity pairs for a slot, the pairs with a value the
-- client keeps secret left out (each GUID becomes a table key in Ledger.WindowsFromSlots).
local function lootSources(slot)
  local raw = { call("GetLootSourceInfo", slot) }
  local out, size = {}, 0
  for index = 1, #raw, 2 do
    local guid, count = raw[index], raw[index + 1]
    if canRead(guid) and canRead(count) then
      out[size + 1], out[size + 2] = guid, count
      size = size + 2
    end
  end
  return out
end

local function deadCreatureGuid()
  for _, unit in ipairs({ "mouseover", "target" }) do
    local guid = unitGuid(unit)
    local kind = Ledger.SourceOf(guid)
    if kind == "creature" and call("UnitIsDead", unit) then
      return guid
    end
  end
  return nil
end

-- Brief R4: the coin formats, turned into patterns once. GOLD_AMOUNT, SILVER_AMOUNT and
-- COPPER_AMOUNT are client global strings (GlobalStrings.lua, which the wow-ui-source mirror does
-- not carry); a client without them reads every money slot as money of no known amount.
local function moneyPatterns()
  if not Ledger.moneyPatterns then
    Ledger.moneyPatterns = Ledger.MoneyPatterns({
      { rawget(_G, "GOLD_AMOUNT"), 10000 },
      { rawget(_G, "SILVER_AMOUNT"), 100 },
      { rawget(_G, "COPPER_AMOUNT"), 1 },
    })
  end
  return Ledger.moneyPatterns
end

-- Whether a slot with no item link is the money slot. GetLootSlotInfo's tenth answer, isCoin, on
-- the forever branch (LootFrame.lua); GetLootSlotType against Enum.LootSlotType.Money (2, per
-- LootConstantsDocumentation.lua) on a client whose GetLootSlotInfo stops short of it.
local function isMoneySlot(slot, isCoin)
  if isCoin ~= nil then
    return isCoin == true
  end
  local slotType = call("GetLootSlotType", slot)
  if slotType == nil then
    return false
  end
  local enum = rawget(_G, "Enum")
  local money = type(enum) == "table" and type(enum.LootSlotType) == "table" and enum.LootSlotType.Money or nil
  return slotType == (money or rawget(_G, "LOOT_SLOT_MONEY") or 2)
end

-- Brief R4: the items that are a current quest objective, from UI/CollectorHooks.lua, which
-- keeps the quest log's objectives. Asked only for a window with a creature in it. nil where
-- there are none or the hooks are not loaded.
local function currentObjectives(windows)
  local hooks = ItemTree.CollectorHooks
  if type(hooks) ~= "table" or type(hooks.CurrentObjectiveItems) ~= "function" then
    return nil
  end
  for _, window in ipairs(windows) do
    if window.kind == "creature" then
      local ok, set = pcall(hooks.CurrentObjectiveItems)
      if ok and type(set) == "table" and next(set) ~= nil then
        return set
      end
      return nil
    end
  end
  return nil
end

-- Brief SK1: the record kind the player's own Skinning, Pick Pocket or creature gathering cast
-- gave the window opening now, from UI/CollectorHooks.lua (CollectorHooks.CreatureLootKind), which
-- holds it from the cast to LOOT_CLOSED; nil for a plain kill's loot or with the hooks not loaded.
-- Brief RV14: a Pick Pocket only while the target is a living creature, and never into combat.
local function creatureLootKind()
  local hooks = ItemTree.CollectorHooks
  if type(hooks) ~= "table" or type(hooks.CreatureLootKind) ~= "function" then
    return nil
  end
  local ok, kind = pcall(hooks.CreatureLootKind)
  return ok and kind or nil
end

-- LOOT_OPENED(autoLoot, isFromItem). The slots are read off the open window: GetNumLootItems,
-- GetLootSlotLink, GetLootSlotInfo (name second, quantity third, isCoin tenth) and
-- GetLootSourceInfo(slot), which answers guid, quantity pairs, one pair per corpse or node the
-- slot came from.
function Ledger.OnLootOpened(_autoLoot, isFromItem)
  if not Ledger.Enabled() then
    return 0
  end
  local store = Ledger.Store()
  if not store then
    return 0
  end
  local hasSources = type(rawget(_G, "GetLootSourceInfo")) == "function"
  local slots = {}
  local count = positive(call("GetNumLootItems")) or 0
  for slot = 1, count do
    local _, name, quantity, _, _, _, _, _, _, isCoin = call("GetLootSlotInfo", slot)
    local entry = { itemId = itemIdFromLink(call("GetLootSlotLink", slot)), quantity = quantity }
    if not entry.itemId and isMoneySlot(slot, isCoin) then
      entry.money = true
      entry.copper = Ledger.ParseMoney(name, moneyPatterns())
    end
    if hasSources then
      entry.sources = lootSources(slot)
    end
    slots[#slots + 1] = entry
  end
  local fallback = nil
  if not isFromItem and (not hasSources or count == 0) then
    fallback = deadCreatureGuid()
  end
  -- A living creature is being pickpocketed, not looted: its window is not a drop.
  local skip = nil
  local targetGuid = unitGuid("target")
  if Ledger.SourceOf(targetGuid) == "creature" and not call("UnitIsDead", "target") then
    skip = { [targetGuid] = true }
  end
  local fishing = nil
  if not isFromItem and call("IsFishingLoot") then
    fishing = apiCall("C_Map", "GetBestMapForUnit", "player")
  end
  local creatureKind = creatureLootKind()
  local windows = Ledger.WindowsFromSlots(slots, fallback)
  return Ledger.CountWindows(store, windows, {
    fishing = fishing,
    skip = skip,
    -- Brief SK1: the player's own cast that opened the window, where UI/CollectorHooks.lua holds one.
    gathered = creatureKind == "skin" or creatureKind == "gather",
    -- Brief RV14 (review M1): a pocket only while the target is a living creature (skip's own
    -- test above); a dead target's window is a kill or a skin, and its rates count.
    pocket = creatureKind == "pickpocket" and skip ~= nil,
    recent = Ledger.recent,
    objectives = currentObjectives(windows),
    itemIdOf = function(guid)
      return apiCall("C_Item", "GetItemIDByGUID", guid)
    end,
  })
end

-- Brief R4: a party kill the combat log named, from UI/CollectorHooks.lua. A Creature or
-- Vehicle GUID only. Answers the creature's table, or nil.
function Ledger.OnKill(guid)
  if not Ledger.Enabled() then
    return nil
  end
  local kind, id = Ledger.SourceOf(guid)
  if kind ~= "creature" then
    return nil
  end
  local store = Ledger.Store()
  if not store then
    return nil
  end
  return Ledger.CountKill(store, id)
end

-- Brief R4: the window a Disenchant cast opened, from UI/CollectorHooks.lua at the moment it
-- records the disenchant edge. itemId is the item that went in and items { [itemId] = quantity }
-- what came out. Answers the disenchant source's table, or nil.
function Ledger.OnDisenchant(itemId, items)
  if not Ledger.Enabled() then
    return nil
  end
  local store = Ledger.Store()
  if not store then
    return nil
  end
  return Ledger.CountLoot(store, "disenchant", itemId, items)
end

-- The currency a row is priced in, off its first cost entry's link ("currency:ID"), or nil for a
-- row priced in money or in an item. GetMerchantItemCostItem(index, 1) answers texture, amount,
-- link, currency name, and is only asked when the row says it has a cost beyond money.
local function rowCurrency(index)
  local _, _, link = call("GetMerchantItemCostItem", index, 1)
  if type(link) ~= "string" then
    return nil
  end
  return positive(link:match("currency:(%d+)"))
end

-- One merchant row: the retail table shape first (C_MerchantFrame.GetItemInfo(index): price,
-- numAvailable, hasExtendedCost), then the classic positional one (GetMerchantItemInfo: name,
-- texture, price, quantity, numAvailable, isPurchasable, isUsable, extendedCost). The item id
-- is off the row's own link.
local function merchantRow(index)
  local itemId = itemIdFromLink(call("GetMerchantItemLink", index))
  if not itemId then
    return nil
  end
  local price, available, extended
  local info = apiCall("C_MerchantFrame", "GetItemInfo", index)
  if type(info) == "table" then
    price, available, extended = info.price, info.numAvailable, info.hasExtendedCost
  else
    local _
    _, _, price, _, available, _, _, extended = call("GetMerchantItemInfo", index)
  end
  local currency = nil
  if extended then
    currency = rowCurrency(index)
  end
  return { itemId = itemId, price = price, currency = currency, stock = available }
end

function Ledger.OnMerchant(visit)
  if not Ledger.Enabled() then
    return nil
  end
  local store = Ledger.Store()
  local privacy = ItemTree.Privacy
  if not store or not privacy then
    return nil
  end
  local ok, kind, npcId = pcall(privacy.ParseGuid, unitGuid("npc"))
  if not ok or kind ~= "Creature" then
    return nil
  end
  local rows = {}
  for index = 1, positive(call("GetMerchantNumItems")) or 0 do
    rows[#rows + 1] = merchantRow(index)
  end
  return Ledger.CountVendor(store, npcId, rows, Ledger.Today(), visit)
end

-- QUEST_COMPLETE: the turn in panel. GetQuestItemInfo(type, index) answers name, texture,
-- numItems, quality, isUsable, itemID on the retail shaped client; GetQuestItemLink is the
-- fallback for a client whose answer stops short of the id.
local function panelItem(kind, index)
  local itemId = positive(select(6, call("GetQuestItemInfo", kind, index)))
  return itemId or itemIdFromLink(call("GetQuestItemLink", kind, index))
end

function Ledger.OnQuestComplete()
  if not Ledger.Enabled() then
    return nil
  end
  local store = Ledger.Store()
  local questId = positive(call("GetQuestID"))
  if not store or not questId then
    return nil
  end
  local itemIds = {}
  for index = 1, positive(call("GetNumQuestRewards")) or 0 do
    itemIds[#itemIds + 1] = panelItem("reward", index)
  end
  for index = 1, positive(call("GetNumQuestChoices")) or 0 do
    itemIds[#itemIds + 1] = panelItem("choice", index)
  end
  return Ledger.CountQuestOffer(store, questId, itemIds)
end

function Ledger.OnQuestTurnedIn(questId)
  if not Ledger.Enabled() then
    return nil
  end
  local store = Ledger.Store()
  if not store then
    return nil
  end
  return Ledger.CountTurnIn(store, questId)
end

Ledger.EVENTS = { "LOOT_OPENED", "MERCHANT_SHOW", "MERCHANT_UPDATE", "QUEST_COMPLETE", "QUEST_TURNED_IN" }

local function dispatch(event, ...)
  if event == "LOOT_OPENED" then
    Ledger.OnLootOpened(...)
  elseif event == "MERCHANT_SHOW" then
    Ledger.OnMerchant(true)
  elseif event == "MERCHANT_UPDATE" then
    Ledger.OnMerchant(false)
  elseif event == "QUEST_COMPLETE" then
    Ledger.OnQuestComplete()
  elseif event == "QUEST_TURNED_IN" then
    Ledger.OnQuestTurnedIn((...))
  end
end

-- True when the handler ran to the end. A count is never worth an error in front of the player.
function Ledger.OnEvent(event, ...)
  return pcall(dispatch, event, ...) and true or false
end

-- Idempotent. The event frame, or nil outside the client.
function Ledger.Install()
  if Ledger.frame then
    return Ledger.frame
  end
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return nil
  end
  local ok, frame = pcall(createFrame, "Frame")
  if not ok or type(frame) ~= "table" or type(frame.RegisterEvent) ~= "function" then
    return nil
  end
  local registered = 0
  for _, event in ipairs(Ledger.EVENTS) do
    if pcall(frame.RegisterEvent, frame, event) then
      registered = registered + 1
    end
  end
  if registered == 0 or type(frame.SetScript) ~= "function" then
    return nil
  end
  local hooked = pcall(frame.SetScript, frame, "OnEvent", function(_, event, ...)
    Ledger.OnEvent(event, ...)
  end)
  if not hooked then
    return nil
  end
  Ledger.frame = frame
  return frame
end

local createFrameGlobal = rawget(_G, "CreateFrame")
if type(createFrameGlobal) == "function" then
  local ok, loader = pcall(createFrameGlobal, "Frame")
  if ok and type(loader) == "table" then
    pcall(loader.RegisterEvent, loader, "PLAYER_LOGIN")
    pcall(loader.SetScript, loader, "OnEvent", function(self)
      Ledger.Install()
      pcall(self.UnregisterEvent, self, "PLAYER_LOGIN")
    end)
  end
end

return Ledger
