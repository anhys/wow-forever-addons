-- Access layer over the generated data modules under Data/generated/.
--
-- Each generated file registers a loader in ItemTree.Data.modules[name]; the table is
-- only built the first time it is asked for. Nothing above the client side divider at the end of
-- this file touches the WoW API.
--
-- Brief U3: the modules ship in two addon folders. ItemTree's own Data/generated/ holds the core
-- set its tooltips, bag badges and collector read without the window open. The rest ship in the
-- load on demand addon ItemTree_Data, which Meta.onDemand names; Data:Get asks the client to load
-- that addon the first time one of them is wanted (Data:LoadOnDemand, client side below).
local _, ItemTree = ...

local Data = ItemTree.Data or {}
ItemTree.Data = Data
Data.modules = Data.modules or {}
Data.cache = Data.cache or {}

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

-- Returned in place of a list nothing was found for. Never modified.
local EMPTY = {}

-- Bumped every time the built tables are dropped, so a caller that caches an answer derived
-- from the data can tell that it is stale without being told. Core/ViewModel.lua's direction
-- counts read it.
Data.generation = Data.generation or 1

-- Whether a module is registered or already built. A built module has let go of its loader
-- (Data:Get), so both are asked.
function Data:Has(name)
  return self.modules[name] ~= nil or self.cache[name] ~= nil
end

-- The names Meta.onDemand lists as a set, built once per Meta table. Empty for data with no such
-- list (every module then ships in ItemTree itself, which is how the specs' fakes look).
function Data:OnDemandNames()
  local meta = self.Meta
  local list = type(meta) == "table" and meta.onDemand or nil
  if type(list) ~= "table" then
    return EMPTY
  end
  if self.onDemandSet and self.onDemandFrom == list then
    return self.onDemandSet
  end
  local set = {}
  for _, name in ipairs(list) do
    if type(name) == "string" then
      set[name] = true
    end
  end
  self.onDemandSet, self.onDemandFrom = set, list
  return set
end

-- Whether a module ships in ItemTree_Data. False, never nil.
function Data:IsOnDemand(name)
  return self:OnDemandNames()[name] == true
end

-- Whether every module ItemTree_Data holds is registered, so reading one costs no load. True for
-- data with no on demand list at all. The login time surfaces ask this before reading an item row,
-- and answer from the core set (Data:Glance, the client) while it says false.
function Data:OnDemandLoaded()
  for name in pairs(self:OnDemandNames()) do
    if self.modules[name] == nil and self.cache[name] == nil then
      return false
    end
  end
  return true
end

-- Returns the module table, loading it on first use. nil when the module is absent.
--
-- A module ItemTree_Data holds that is not registered yet is loaded here, by one call to the
-- client (Data:LoadOnDemand), which is synchronous, so the caller gets its table. If the addon
-- cannot be loaded, this answers nil exactly as it does for an absent module, and every caller
-- already copes with that.
--
-- Brief P3: once the table is built its loader is let go of. A loader is a function whose body
-- is one huge table constructor, and its compiled form costs about a third of what the table
-- does (about 22 MB over the whole shipped data), for nothing: the table is held in the cache
-- and never built twice. Data.keepLoaders keeps them, for the specs, which rebuild the tables
-- after writing into them (Data:Reset).
function Data:Get(name)
  local cached = self.cache[name]
  if cached ~= nil then
    return cached
  end
  local loader = self.modules[name]
  if not loader and self:IsOnDemand(name) and type(self.LoadOnDemand) == "function" then
    -- Brief PF5: the module that asked, for Data.loadTiming.
    if self:LoadOnDemand(nil, name) then
      loader = self.modules[name]
    end
  end
  if not loader then
    return nil
  end
  -- Brief PF1: each module built while /itprobe open traces an open is timed; one table read else.
  local table_
  local trace = ItemTree.openTrace
  if trace then
    table_ = trace.Span("module", name, loader)
  else
    table_ = loader()
  end
  table_ = self:JoinHalves(name, table_)
  self.cache[name] = table_
  if table_ ~= nil and not self.keepLoaders and self.modules[name] == loader then
    self.modules[name] = nil
    self.dropped = self.dropped or {}
    self.dropped[name] = true
  end
  return table_
end

-- Brief GA1 (owner ruling of 2026-10-09: only data derived from the CMaNGOS Classic content database
-- may be in a GPL file). Two modules now ship as two files each: the GPL-3.0 Classic Era half under
-- the module's own name, and ours, all rights reserved, beside it. JOINS[name] names the other half
-- and the pure function that joins them. The join runs once, the first time Data:Get builds the
-- module, so every reader sees the one table it always read, whatever else the namespace loaded.
-- The other half is built straight from its loader and never kept apart: its cache slot holds
-- false once it is joined, so Data:Has and Data:OnDemandLoaded still count it, and
-- Data:Get(partner) answers false. Data without the other half (an older single file, the specs'
-- hand made fixtures) is answered as it is.

-- The Boss loot index (ItemTree-Data docs/boss-loot.md). BossLootIndex, ours: the v = 1 index with
-- no l on any entry, plus it = { [itemId] = type code * 1000 + item level } (this build's item
-- tables) and, on a chest entry, ob = { object ids }. BossLoot, GPL-3.0, the Classic Era half
-- (v = 2): c = { [creatureId] = loot }, o = { [objectId] = loot }, each loot a run of 5 byte
-- records, item id (3 base 91 digits) then value (2), in id order. Each entry's l is made again
-- exactly as the pipeline made it (boss_loot.join, which the compile checks against the index it
-- derived): the records of its creatures (c), or of its objects (ob) on a chest, each item at its
-- best drop (the unconditional one, then the higher chance), an item it does not hold left out,
-- as 8 byte records (item id 3, value 2, type 1, item level 2) in draw order (type, chance with
-- none last, item level descending, id). it and ob are not in the joined table.
local BOSS_INDEX_VERSION = 1
local BOSS_ERA_VERSION = 2
local BOSS_TYPE_SCALE = 1000
local BOSS_RECORD = 8
local ERA_RECORD = 5
local BOSS_QUEST_ONLY = 2048
local PACK_BASE = 91
local PACK_FIRST = 35
local PACK_SKIPPED = 92

-- One base 91 field of a packed string, or nil where a byte is outside the alphabet.
local function packedInt(text, at, digits)
  local value = 0
  for offset = 0, digits - 1 do
    local code = string.byte(text, at + offset)
    if not code or code == PACK_SKIPPED then
      return nil
    end
    if code > PACK_SKIPPED then
      code = code - 1
    end
    code = code - PACK_FIRST
    if code < 0 or code >= PACK_BASE then
      return nil
    end
    value = value * PACK_BASE + code
  end
  return value
end

-- One base 91 field, most significant digit first: the inverse of packedInt. nil where the value
-- does not fit the digits.
local function packInt(value, digits)
  value = math.floor(tonumber(value) or -1)
  if value < 0 or value >= PACK_BASE ^ digits then
    return nil
  end
  local bytes = {}
  for at = digits, 1, -1 do
    local code = PACK_FIRST + value % PACK_BASE
    if code >= PACK_SKIPPED then
      code = code + 1
    end
    bytes[at] = string.char(code)
    value = math.floor(value / PACK_BASE)
  end
  return table.concat(bytes)
end

-- Whether value a is the better drop than value b: the unconditional drop, then the higher chance.
local function betterValue(a, b)
  local aAnyone, bAnyone = a < BOSS_QUEST_ONLY, b < BOSS_QUEST_ONLY
  if aAnyone ~= bAnyone then
    return aAnyone
  end
  return a % BOSS_QUEST_ONLY > b % BOSS_QUEST_ONLY
end

-- The Classic Era records of one list folded into best (item -> value), the better drop kept.
local function foldRecords(packed, best)
  if type(packed) ~= "string" then
    return
  end
  for at = 1, #packed - ERA_RECORD + 1, ERA_RECORD do
    local id = packedInt(packed, at, 3)
    local value = packedInt(packed, at + 3, 2)
    if id and value and id > 0 then
      local held = best[id]
      if held == nil or betterValue(value, held) then
        best[id] = value
      end
    end
  end
end

local function recordBefore(a, b)
  for key = 1, 5 do
    if a.order[key] ~= b.order[key] then
      return a.order[key] < b.order[key]
    end
  end
  return false
end

-- One entry's l out of the Classic Era half, or nil where it has no record.
local function joinedLoot(entry, era, types)
  local best = {}
  local lists, ids = era.c, entry.c
  if type(entry.ob) == "table" then
    lists, ids = era.o, entry.ob
  end
  if type(lists) ~= "table" or type(ids) ~= "table" then
    return nil
  end
  for _, id in ipairs(ids) do
    foldRecords(lists[id], best)
  end
  local records = {}
  for id, value in pairs(best) do
    local packedType = tonumber(types[id])
    if packedType then
      local code = math.floor(packedType / BOSS_TYPE_SCALE)
      local level = packedType % BOSS_TYPE_SCALE
      local chance = value % BOSS_QUEST_ONLY
      local text = (packInt(id, 3) or "")
        .. (packInt(value, 2) or "")
        .. (packInt(code, 1) or "")
        .. (packInt(level, 2) or "")
      if #text == BOSS_RECORD then
        records[#records + 1] = { order = { code, chance == 0 and 1 or 0, -chance, -level, id }, text = text }
      end
    end
  end
  if #records == 0 then
    return nil
  end
  table.sort(records, recordBefore)
  local parts = {}
  for index, record in ipairs(records) do
    parts[index] = record.text
  end
  return table.concat(parts)
end

-- The v = 1 index out of the two modules. era is the Classic Era half (BossLoot), index ours
-- (BossLootIndex). A fresh top table and fresh entries, so neither module's table is written into.
-- era answered as it is where it is already a v = 1 index or index is not one. Pure.
--
-- Brief PF3: check, where given, is called once per boss entry (Data.SliceCheck, which lets the
-- login slicer carry the join over several frames); the table built is the same either way.
function Data.JoinBossLoot(era, index, check)
  if type(era) ~= "table" or era.v ~= BOSS_ERA_VERSION then
    return era
  end
  if type(index) ~= "table" or index.v ~= BOSS_INDEX_VERSION or type(index.b) ~= "table" then
    return era
  end
  local types = type(index.it) == "table" and index.it or EMPTY
  local bosses = {}
  for number, entry in ipairs(index.b) do
    if check then
      check()
    end
    local joined = {}
    if type(entry) == "table" then
      for key, value in pairs(entry) do
        if key ~= "ob" and key ~= "l" then
          joined[key] = value
        end
      end
      joined.l = joinedLoot(entry, era, types)
    end
    bosses[number] = joined
  end
  return { v = index.v, s = index.s, p = index.p, b = bosses }
end

-- The Classic Era sources (ItemTree-Data docs/era-sources.md). EraSources, GPL-3.0: s with every
-- place only a zone name holds left as an empty string (and none of the names of the places new in
-- Forever, which sort last), r, qt, ck, cd, ci, oi, qg, st, tr, qr, qc, x, xl and g. EraPlaces, ours:
-- zs = { [string index] = zone name }, the names this build's AreaTable gives those places, and z,
-- zm, zf, cf, mp, op, ok, pt, mc and (brief EK1) cm, and g, which must be EraSources' own. The join puts each zs
-- name back in its place in s (in index order, so a name past the end of s is appended) and sets
-- each of the other tables beside the GPL ones: every index is where it was before the split. A
-- pair whose g differs, or a table that already holds z (an older single file, the specs'
-- fixtures), is left as it is. era is the table the EraSources loader built (fresh, so written
-- into here). ItemTree-Data itemtree_data/era_places.py join is the same rule, which the compile
-- checks against the table it derived.
-- Brief EK1 2b: cm, the Classic Era creature names whose page is one with the Forever page of the
-- same id and the same name (the merge list, ours), joins the same way. Brief CT1: and tf, this
-- build's own learn level and rank for each class spell EraSources' tc lists (ours). Brief TW1: and
-- tm, the Classic races this build limits a class spell to (ours, its SkillLineAbility race masks).
-- Brief QV1: qf and fn, the reputation a same titled quest gives and the reputations' names.
local ERA_PLACES_FIELDS = { "z", "zm", "zf", "cf", "mp", "op", "ok", "pt", "mc", "cm", "tf", "tm", "qf", "fn" }

function Data.JoinEraSources(era, places)
  if type(era) ~= "table" or type(places) ~= "table" or era.z ~= nil then
    return era
  end
  if era.g ~= places.g then
    return era
  end
  local s = type(era.s) == "table" and era.s or {}
  local zs = type(places.zs) == "table" and places.zs or EMPTY
  local at = {}
  for index in pairs(zs) do
    if type(index) == "number" then
      at[#at + 1] = index
    end
  end
  table.sort(at)
  for _, index in ipairs(at) do
    if index == #s + 1 or (index >= 1 and index <= #s and s[index] == "") then
      s[index] = zs[index]
    end
  end
  era.s = s
  for _, key in ipairs(ERA_PLACES_FIELDS) do
    if places[key] ~= nil then
      era[key] = places[key]
    end
  end
  return era
end

Data.JOINS = {
  BossLoot = { partner = "BossLootIndex", join = Data.JoinBossLoot },
  EraSources = { partner = "EraPlaces", join = Data.JoinEraSources },
}

function Data:JoinHalves(name, own)
  local join = Data.JOINS[name]
  if not join or own == nil then
    return own
  end
  local partner = join.partner
  local other = self.cache[partner]
  if other == nil then
    local loader = self.modules[partner]
    if not loader then
      return own
    end
    other = loader()
    if not self.keepLoaders and self.modules[partner] == loader then
      self.modules[partner] = nil
      self.dropped = self.dropped or {}
      self.dropped[partner] = true
    end
  end
  self.cache[partner] = false
  if type(other) ~= "table" then
    return own
  end
  return join.join(own, other)
end

-- Drops built tables and derived indexes (tests, or after swapping data modules in
-- the harness). Nothing in the client calls it.
--
-- A table whose loader Data:Get let go of (Data.keepLoaders off) cannot be built again, so it is
-- registered again as a loader that answers the same table: the data is never lost, it just is
-- not rebuilt. With keepLoaders on, which the specs set, every table is built afresh, and a
-- module a spec unregistered stays gone.
function Data:Reset()
  for name in pairs(self.dropped or EMPTY) do
    local held = self.cache[name]
    if held ~= nil and self.modules[name] == nil then
      self.modules[name] = function()
        return held
      end
    end
  end
  self.dropped = nil
  self.cache = {}
  self.toolItems = nil
  self.toolRecipes = nil
  self.nameIndex = nil
  self.nameEntries = nil
  self.creatureIndex = nil
  -- Brief N1: the Forever creatures' list (Data:ForeverCreatureIndex).
  self.foreverCreatures = nil
  self.searchBuild = nil
  -- Brief SR1: the other kinds' name lists (Data:KindIndex).
  self.kindIndexes = nil
  self.itemIds = nil
  self.randomIndex = nil
  self.questStarts = nil
  self.newInForever = nil
  -- Brief BQ7: the soulbound Forever copies (Data:ForeverCopyPair) and the new ids' set.
  self.copyPairs = nil
  self.newItemSet = nil
  self.setMembers = nil
  self.harvestStubs = nil
  self.generation = (self.generation or 1) + 1
end

-- Items the Discovery Miner found on the beta realm (brief D3). The pipeline compiles each id the
-- build withholds and the harvest names into the ordinary item tables, and lists them in the
-- Diff module as items.harvested = { [id] = tag }. They are ordinary items from then on, unless
-- the player turns "Show items found on the beta" off (settings.showHarvested), which puts each
-- one back behind the stub it had: no name in search, the placeholder on its page.

-- The source tag a harvest named this id with, or nil. Read straight off the Diff module, so it
-- answers the same thing as Core/Diff.lua's HarvestSource without needing it loaded.
function Data:HarvestTag(itemId)
  local diff = self:Get("Diff")
  local items = type(diff) == "table" and diff.items or nil
  local harvested = type(items) == "table" and items.harvested or nil
  if type(harvested) ~= "table" then
    return nil
  end
  local tag = harvested[itemId]
  if type(tag) == "string" and tag ~= "" then
    return tag
  end
  return nil
end

function Data:IsHarvested(itemId)
  return self:HarvestTag(itemId) ~= nil
end

-- Whether harvested items are shown: settings.showHarvested, on unless it is false. Read guarded,
-- so a spec or a half loaded client with no saved settings shows them.
function Data:HarvestShown()
  local db = ItemTree.db
  local settings = type(db) == "table" and db.settings or nil
  if type(settings) ~= "table" then
    return true
  end
  return settings.showHarvested ~= false
end

-- Whether this id is a harvested item the setting has put back behind its stub. False, never nil.
function Data:HarvestMasked(itemId)
  if self:HarvestShown() then
    return false
  end
  return self:IsHarvested(itemId)
end

-- Drops what was built from the item tables while the setting said otherwise: the indexes that
-- list or count items and the stubs themselves. The modules stay loaded, because the setting
-- changes what is read out of them and not what they hold. Bumps generation like Reset does.
function Data:ResetHarvest()
  self.nameIndex = nil
  self.nameEntries = nil
  self.searchBuild = nil
  self.itemIds = nil
  self.randomIndex = nil
  self.newInForever = nil
  self.questStarts = nil
  self.toolItems = nil
  self.harvestStubs = nil
  self.generation = (self.generation or 1) + 1
end

-- The stub a masked harvested item reads as: what the build's own Item row states, which the
-- harvest agrees with, and u = 1. Nothing else of the record, so no name, level or stat. Built
-- once per id and dropped by Reset, which the setting's change calls.
local function harvestStub(self, itemId, item)
  self.harvestStubs = self.harvestStubs or {}
  local held = self.harvestStubs[itemId]
  if held then
    return held
  end
  held = { u = 1, c = item.c, sc = item.sc, it = item.it, i = item.i }
  self.harvestStubs[itemId] = held
  return held
end

-- Brief OPT5: packed item rows. The pipeline ships every Items_<class> row and every EraItems row
-- as ONE string, which costs its bytes where a table of about 13 fields cost about 1.4 KB, and
-- the row is decoded here the first time it is read. A packed module's table is
--
--   { [itemId] = "<row>", ..., legend = { { field, type }, ... }, packed = 1 }
--
-- legend names the fields in slot order, each with its type: "n" number, "s" string, "b" boolean
-- (1 or 0), "t" table. A row is its slots joined by byte 31; an empty slot is an absent field,
-- and a row stops after its last present field. A string slot is the text itself, and the single
-- byte 30 is the empty string. A table slot is its tokens joined by byte 30: a number, ' and a
-- string, or a nested list as the token { then its tokens then the token }; the slot "{}" is the
-- empty table. ItemTree-Data docs/data-format.md is the contract (compile_lua.pack_item_row).
-- Decoding is string.find, string.sub and tonumber only: data is never compiled as code.
--
-- A decoded row has exactly the shape the plain module held: the same keys, the same value types,
-- the nested lists rebuilt. It is kept in a per module cache with weak values, so a row anything
-- still holds is the same table on every read, and one nothing holds can be collected and is
-- decoded again when next wanted. A module without packed (an older data folder) is read as it
-- always was, and so is a table a spec writes into a packed module.
--
-- Brief OPT7 grows the format for the modules that ship a LIST of rows per id (EraSources' r,
-- DiffChanges' <kind>.changed): the rows of one id are joined by byte 29 (Data.UnpackRows), and a
-- legend entry may be of two more types. "v" is one value of any type a table token holds, said
-- by its own token (a number, ' and a string, or a list between the tokens { and }), which is how
-- a change row's old and new are written. "r" is a list of keyed records (EraSources' m): the
-- legend entry carries a third element, the records' own legend, and the slot is the records
-- joined by byte 30, each one's fields in that legend's order joined by byte 28.
local FIELD_SEP, TOKEN_SEP, ROW_SEP, RECORD_SEP = "\31", "\30", "\29", "\28"
local strFind, strSub, strByte = string.find, string.sub, string.byte
local BYTE_QUOTE, BYTE_OPEN, BYTE_CLOSE = 39, 123, 125

-- One table slot as the list it was written from.
local function unpackTable(text)
  local root = {}
  if text == "{}" then
    return root
  end
  local top, depth, stack = root, 0, nil
  local pos = 1
  while true do
    local stop = strFind(text, TOKEN_SEP, pos, true)
    local token = strSub(text, pos, stop and stop - 1 or -1)
    local first = strByte(token, 1)
    if first == BYTE_QUOTE then
      top[#top + 1] = strSub(token, 2)
    elseif first == BYTE_OPEN then
      local child = {}
      top[#top + 1] = child
      stack = stack or {}
      depth = depth + 1
      stack[depth] = top
      top = child
    elseif first == BYTE_CLOSE then
      if depth > 0 then
        top = stack[depth]
        stack[depth] = nil
        depth = depth - 1
      end
    else
      local number = tonumber(token)
      if number ~= nil then
        top[#top + 1] = number
      end
    end
    if not stop then
      return root
    end
    pos = stop + 1
  end
end

local unpackRow

-- One "r" slot: its records, each decoded against the records' own legend (brief OPT7).
local function unpackRecords(text, sub)
  local out = {}
  local pos = 1
  while true do
    local stop = strFind(text, TOKEN_SEP, pos, true)
    out[#out + 1] = unpackRow(strSub(text, pos, stop and stop - 1 or -1), sub.keys, sub.types, sub.subs, RECORD_SEP)
    if not stop then
      return out
    end
    pos = stop + 1
  end
end

-- One packed row as its table, given the legend's field names and types in slot order. subs
-- holds the records' legend of each "r" slot, sep is the byte the fields are joined by (byte 31
-- unless given: a record's are joined by byte 28), and into is a table to fill in place of a new
-- one (Data.ScanRows: the caller has cleared it).
unpackRow = function(text, keys, types, subs, sep, into)
  sep = sep or FIELD_SEP
  local row = into or {}
  local length = #text
  local pos, slot = 1, 1
  while pos <= length + 1 do
    local stop = strFind(text, sep, pos, true)
    local last = (stop or length + 1) - 1
    local key = keys[slot]
    if last >= pos and key ~= nil then
      local value = strSub(text, pos, last)
      local kind = types[slot]
      if kind == "n" then
        row[key] = tonumber(value)
      elseif kind == "s" then
        if value == TOKEN_SEP then
          row[key] = ""
        else
          row[key] = value
        end
      elseif kind == "t" then
        row[key] = unpackTable(value)
      elseif kind == "b" then
        row[key] = value == "1"
      elseif kind == "v" then
        row[key] = unpackTable(value)[1]
      elseif kind == "r" and subs ~= nil and subs[slot] ~= nil then
        row[key] = unpackRecords(value, subs[slot])
      end
    end
    if not stop then
      break
    end
    pos = stop + 1
    slot = slot + 1
  end
  return row
end
Data.UnpackRow = unpackRow

-- A legend as arrays in slot order: field names, types, and (brief OPT7) the records' legend of
-- each "r" slot, read the same way.
local function readLegend(legend)
  local keys, types, subs = {}, {}, nil
  if type(legend) == "table" then
    for slot, pair in ipairs(legend) do
      if type(pair) == "table" then
        keys[slot], types[slot] = pair[1], pair[2]
        if pair[2] == "r" then
          subs = subs or {}
          subs[slot] = readLegend(pair[3])
        end
      end
    end
  end
  return { keys = keys, types = types, subs = subs }
end

-- A packed module's legend, read once per module table.
local legends = setmetatable({}, { __mode = "k" })
local function legendOf(module)
  local held = legends[module]
  if held then
    return held
  end
  held = readLegend(rawget(module, "legend"))
  legends[module] = held
  return held
end

-- The decoded rows of each packed module table, weak valued (see above).
local rowCaches = setmetatable({}, { __mode = "k" })

-- One row of an item module (Items_<class> or EraItems), decoded where the module is packed:
-- what module[id] held before rows were packed. Anything that is not a packed string, a plain
-- module's row or nil, is answered as it is. A decoded row is answered from the cache first, so a
-- warm read costs two table lookups; a row written into a packed module after its id was decoded
-- is not seen (only the specs write rows, and they put the decoded table itself back).
local function moduleRow(module, id)
  local cache = rowCaches[module]
  if cache ~= nil then
    local row = cache[id]
    if row ~= nil then
      return row
    end
  end
  local raw = module[id]
  if type(raw) ~= "string" or module.packed ~= 1 then
    return raw
  end
  if cache == nil then
    cache = setmetatable({}, { __mode = "v" })
    rowCaches[module] = cache
  end
  local legend = legendOf(module)
  local row = unpackRow(raw, legend.keys, legend.types, legend.subs)
  cache[id] = row
  return row
end
Data.ModuleRow = moduleRow

-- Brief OPT7: one id's packed rows (its rows joined by byte 29) as the list of row tables, in
-- their order, against a legend as legendOf reads it. The empty string is no rows.
local function unpackRows(text, legend)
  local out = {}
  if text == "" then
    return out
  end
  local keys, types, subs = legend.keys, legend.types, legend.subs
  local pos = 1
  while true do
    local stop = strFind(text, ROW_SEP, pos, true)
    out[#out + 1] = unpackRow(strSub(text, pos, stop and stop - 1 or -1), keys, types, subs)
    if not stop then
      return out
    end
    pos = stop + 1
  end
end
Data.UnpackRows = unpackRows

-- The decoded lists of each packed map (EraSources' r, a DiffChanges kind's changed), weak keyed
-- by the map and weak valued inside, the policy the item rows above have.
local listCaches = setmetatable({}, { __mode = "k" })

-- One id's rows out of map, a table inside a packed module whose top level holds the legend
-- (EraSources' r, DiffChanges' <kind>.changed), decoded on first read: the list the plain module
-- held, with every row in its order. A decoded list is answered from the cache first, so a warm
-- read costs two table lookups, and while anything holds it it is the same table on every read.
-- Anything that is not a packed string (a plain module's list or row, nil) is answered as it is.
local function packedList(module, map, id)
  local cache = listCaches[map]
  if cache ~= nil then
    local list = cache[id]
    if list ~= nil then
      return list
    end
  end
  local raw = map[id]
  if type(raw) ~= "string" or type(module) ~= "table" or module.packed ~= 1 then
    return raw
  end
  if cache == nil then
    cache = setmetatable({}, { __mode = "v" })
    listCaches[map] = cache
  end
  local list = unpackRows(raw, legendOf(module))
  cache[id] = list
  return list
end
Data.PackedList = packedList

-- The end of a row's first slot: the next field or row separator.
local PEEK_EDGE = "[" .. ROW_SEP .. FIELD_SEP .. "]"

-- One step of Data.ScanRows: the next row, out of the cached list where there is one, otherwise
-- decoded from the text into the scan's one reused table, its previous fields cleared first.
local function scanStep(scan, at)
  local list = scan.list
  if list ~= nil then
    local row = list[at + 1]
    if row == nil then
      return nil
    end
    return at + 1, row
  end
  local pos = scan.pos
  if pos == nil then
    return nil
  end
  local text, legend, row = scan.text, scan.legend, scan.row
  local only = scan.only
  if only ~= nil and scan.peek then
    -- Skip the rows whose first slot (a number) is not one the pass reads, without decoding them.
    while true do
      local edge = strFind(text, PEEK_EDGE, pos)
      if only[tonumber(strSub(text, pos, edge and edge - 1 or -1))] then
        break
      end
      local after = strFind(text, ROW_SEP, pos, true)
      if not after then
        scan.pos = nil
        return nil
      end
      pos = after + 1
    end
  end
  local keys = legend.keys
  for slot = 1, #keys do
    row[keys[slot]] = nil
  end
  local stop = strFind(text, ROW_SEP, pos, true)
  unpackRow(strSub(text, pos, stop and stop - 1 or -1), keys, legend.types, legend.subs, nil, row)
  scan.pos = stop and stop + 1 or nil
  return at + 1, row
end

-- Brief OPT7: a generic for over one packed id's rows, for a pass over a whole table that reads
-- fields and KEEPS NO ROW (an index build): `for _, row in Data.ScanRows(module, map, id, scan)`
-- visits the rows Data.PackedList would answer, in their order. A list already in the cache is
-- walked as it is; otherwise each row is decoded into scan.row, ONE table the pass reuses for
-- every row of every id, so the pass allocates nothing per row and fills no cache. scan is a
-- table the pass makes once and hands to every call. Anything that is not a packed string visits
-- no row: the caller reads a plain module's rows itself.
--
-- A pass that reads only some rows may name them: scan.only = { [value] = true, ... } and
-- scan.onlyKey = the field whose value it tests. Where that field is the legend's first slot and
-- a number, a row whose value is not in the set is skipped without being decoded; anywhere else
-- every row is visited. Either way the pass's own test still decides, so only is a saving and
-- never a filter of its own: a pass may only name the values its body already requires.
local function scanRows(module, map, id, scan)
  local cache = listCaches[map]
  local list = cache ~= nil and cache[id] or nil
  if list ~= nil then
    scan.list = list
    return scanStep, scan, 0
  end
  scan.list = nil
  scan.pos = nil
  local raw = map[id]
  if type(raw) == "string" and type(module) == "table" and module.packed == 1 then
    local legend = legendOf(module)
    scan.text = raw
    scan.legend = legend
    scan.row = scan.row or {}
    scan.peek = scan.onlyKey ~= nil and legend.keys[1] == scan.onlyKey and legend.types[1] == "n"
    if raw ~= "" then
      scan.pos = 1
    end
  end
  return scanStep, scan, 0
end
Data.ScanRows = scanRows

-- Classic Era details for withheld items (brief D5). WoW Forever withholds a Classic item it
-- changed until a realm finds it, and the pipeline ships what Classic Era said about every such
-- item in its own module, EraItems: the baseline's item row, keyed by id, in the Items modules'
-- own spellings. It is Diff's items.hidden, the ids the baseline named and the build withholds;
-- an id no build ever named (newUndiscovered) has no row there. The module is not in the Index,
-- so nothing that walks the Index (the item count, the random pool, the tool index) meets it.
--
-- Such a row, and the item's Classic Era sources, are served when the account wide setting "Show
-- Classic Era details for items not yet found" (settings.showEraDetails) is on, which is the
-- default, or when the client can name the item (Data:ClientNames). Otherwise the id reads as the
-- stub it always did. Every row served carries era = true, so any reader can tell.

-- One id's row in the EraItems module, or nil. The module's own table: read it, never change it
-- (GetItem's era flag is the one field ever written onto it).
function Data:EraItem(itemId)
  if type(itemId) ~= "number" then
    return nil
  end
  local rows = self:Get("EraItems")
  if type(rows) ~= "table" then
    return nil
  end
  local row = moduleRow(rows, itemId)
  if type(row) == "table" then
    return row
  end
  return nil
end

-- Whether Classic Era details are shown for items not yet found: settings.showEraDetails, on
-- unless it is false. Read guarded, so a spec or a half loaded client with no saved settings
-- shows them.
function Data:EraShown()
  local db = ItemTree.db
  local settings = type(db) == "table" and db.settings or nil
  if type(settings) ~= "table" then
    return true
  end
  return settings.showEraDetails ~= false
end

-- Whether the running client can name this item: the collector holds a discovery record for it
-- (Core/Collector.lua DiscoveredName), or the page's one live check answered found this session
-- (Core/RealmCheck.lua). Both are local reads; nothing here asks the client or the server
-- anything. Both are looked up at call time, because each loads after this file. False, never nil.
function Data:ClientNames(itemId)
  if type(itemId) ~= "number" then
    return false
  end
  local collector = ItemTree.collector
  -- Brief R3: a record whose name the data build carries holds no name of its own, so the
  -- record itself is what is asked about where the collector can say.
  if type(collector) == "table" and type(collector.HasDiscovery) == "function" then
    local ok, held = pcall(collector.HasDiscovery, collector, itemId)
    if ok and held == true then
      return true
    end
  elseif type(collector) == "table" and type(collector.DiscoveredName) == "function" then
    local ok, name = pcall(collector.DiscoveredName, collector, itemId)
    if ok and type(name) == "string" and name ~= "" then
      return true
    end
  end
  local check = ItemTree.RealmCheck
  if type(check) == "table" and type(check.Found) == "function" then
    local ok, found = pcall(check.Found, itemId)
    if ok and found == true then
      return true
    end
  end
  return false
end

-- Whether an id is inside a flat run list { from, count, from, count, ... }, sorted ascending and
-- never overlapping: the UndiscoveredIds shape, which the Summary module uses too. Binary search.
local function inRuns(runs, itemId)
  if type(runs) ~= "table" or type(itemId) ~= "number" then
    return false
  end
  local low, high = 1, math.floor(#runs / 2)
  while low <= high do
    local mid = math.floor((low + high) / 2)
    local from = runs[mid * 2 - 1]
    local count = runs[mid * 2] or 0
    if itemId < from then
      high = mid - 1
    elseif itemId >= from + count then
      low = mid + 1
    else
      return true
    end
  end
  return false
end
Data.InRuns = inRuns

-- Whether an id is in a sorted array of ids. Binary search.
local function inSorted(list, itemId)
  if type(list) ~= "table" then
    return false
  end
  local low, high = 1, #list
  while low <= high do
    local mid = math.floor((low + high) / 2)
    local at = list[mid]
    if at == itemId then
      return true
    elseif at < itemId then
      low = mid + 1
    else
      high = mid - 1
    end
  end
  return false
end

-- Whether this id is one the build withholds, read off the UndiscoveredIds runs alone. A
-- harvested id the setting has masked is not in the runs (the harvest took it out), so it never
-- answers true here; Data:IsUndiscovered adds that case on top.
local function withheldInRuns(self, itemId)
  return inRuns(self:Get("UndiscoveredIds"), itemId)
end

-- Whether the build withholds this item and the data carries its Classic Era details. False,
-- never nil.
function Data:IsWithheldWithEra(itemId)
  if type(itemId) ~= "number" or not withheldInRuns(self, itemId) then
    return false
  end
  return self:EraItem(itemId) ~= nil
end

-- Whether what Classic Era says about this item may be served: its EraItems row and its Classic
-- Era sources. True for every item the build names (the rule is only about withheld ones), and
-- for a withheld one when the setting is on or the client can name it. The cheap questions go
-- first, so an ordinary item costs one binary search and the EraItems module is never loaded to
-- answer this. False, never nil.
function Data:EraUnlocked(itemId)
  if type(itemId) ~= "number" or not withheldInRuns(self, itemId) then
    return true
  end
  if self:EraShown() then
    return true
  end
  return self:ClientNames(itemId)
end

-- Drops what was built while the setting, or what the client can name, said otherwise: the name
-- index most of all, and the direction counts through generation. Bumps generation like Reset.
function Data:ResetEra()
  self.nameIndex = nil
  self.nameEntries = nil
  self.searchBuild = nil
  self.generation = (self.generation or 1) + 1
end

-- The EraItems row an id is served as, with era = true on it, or nil where it is not served.
local function eraRow(self, itemId)
  if not withheldInRuns(self, itemId) then
    return nil
  end
  if not self:EraShown() and not self:ClientNames(itemId) then
    return nil
  end
  local row = self:EraItem(itemId)
  if row then
    row.era = true
  end
  return row
end

-- The item record, or the undiscovered stub where the build has an Item row and no ItemSparse
-- row for the id. A stub carries u = 1 and only what the build's own Item row states (class,
-- subclass, inventory type, icon), never a name, a quality, a level or a stat: WoW Forever
-- withholds an item's details until it has dropped for someone, and the addon says exactly the
-- same. Every caller that reads item.n has to cope with a row that has none; Core/Graph.lua's
-- Graph.Node is the one that names it.
--
-- The stubs are deliberately absent from the Index, which is what keeps them out of the name
-- index, the item count, the tool and disenchant indexes and the random pool without a line of
-- change in any of them, so this branch is the only way one is ever reached.
--
-- Brief D5: a withheld id with Classic Era details answers its EraItems row instead of the stub,
-- with era = true, when the setting is on or the client can name the item (see eraRow above).
function Data:GetItem(itemId)
  local index = self:Get("Index")
  if not index then
    return nil
  end
  local class = index[itemId]
  if class == nil then
    if type(itemId) == "number" then
      local era = eraRow(self, itemId)
      if era then
        return era
      end
    end
    local stubs = self:Get("Undiscovered")
    return stubs and stubs[itemId] or nil
  end
  local items = self:Get("Items_" .. class)
  if not items then
    return nil
  end
  -- The warm read inlined (see moduleRow): a decoded row straight out of the cache.
  local cache = rowCaches[items]
  local item = cache and cache[itemId]
  if item == nil then
    item = moduleRow(items, itemId) or nil
  end
  if item and self:HarvestMasked(itemId) then
    return harvestStub(self, itemId, item)
  end
  return item
end

-- Whether this build withholds the item's details: an Item row with no ItemSparse row. True for
-- every one of the build's withheld ids, not only the 2,599 something in the compiled data
-- points at, because the whole set ships run length encoded in the UndiscoveredIds module: run i
-- is { from = t[2i - 1], count = t[2i] }, sorted ascending and never overlapping, so a binary
-- search over i answers in O(log runs) with one table and no lookup table to build.
--
-- False, never nil, so a caller can use the answer directly; a build with no such module (the
-- Classic Era data, or a half loaded client) withholds nothing and answers false throughout.
--
-- A harvested item the setting has put back behind its stub answers true, as it did before the
-- harvest named it.
function Data:IsUndiscovered(itemId)
  if type(itemId) ~= "number" then
    return false
  end
  if self:HarvestMasked(itemId) then
    return true
  end
  return withheldInRuns(self, itemId)
end

-- What a tooltip's uses line needs to know about an item, from the core set alone (brief U3):
--
--   { named, era, quest, disenchant, toolFor }
--
-- named is whether Data:GetItem would answer a row with a name, era whether that row is the
-- Classic Era one, quest whether the row starts a quest, disenchant whether a disenchant band
-- covers it, and toolFor how many recipes ask for it as a tool (Data:ToolRecipes). The pipeline
-- works these out from the very rows ItemTree_Data holds and ships them in the Summary module,
-- so a hover answers them without loading that addon. nil where the data ships no Summary module,
-- and the caller then reads the rows. The rules of Data:GetItem are kept: a harvested item the
-- setting hides is its stub (nothing named, no quest, no band, no category), and a withheld id's
-- Classic Era facts count only while Data:GetItem would serve its Era row.
function Data:Glance(itemId)
  if type(itemId) ~= "number" then
    return nil
  end
  local summary = self:Get("Summary")
  if type(summary) ~= "table" then
    return nil
  end
  local uses = self:GetUses(itemId)
  local exactTools = (type(uses) == "table" and type(uses.tool) == "table") and #uses.tool or 0
  local glance = { named = false, era = false, quest = false, disenchant = false, toolFor = exactTools }
  local facts
  if inRuns(summary.named, itemId) then
    if self:HarvestMasked(itemId) then
      return glance
    end
    facts = summary
  else
    local era = type(summary.era) == "table" and summary.era or EMPTY
    if not inRuns(era.ids, itemId) or not withheldInRuns(self, itemId) then
      return glance
    end
    if not self:EraShown() and not self:ClientNames(itemId) then
      return glance
    end
    facts = era
    glance.era = true
  end
  glance.named = true
  glance.quest = inSorted(facts.quest, itemId)
  glance.disenchant = inRuns(facts.de, itemId)
  local tools = type(facts.tool) == "table" and facts.tool or EMPTY
  glance.toolFor = tonumber(tools[itemId]) or 0
  return glance
end

-- Data:GetItem while ItemTree_Data is loaded, and only the core set's stub otherwise: never a
-- load. For a surface that has the client to ask instead (an icon), so a hover at login stays
-- off the item tables.
function Data:PeekItem(itemId)
  if self:OnDemandLoaded() then
    return self:GetItem(itemId)
  end
  local stubs = self:Get("Undiscovered")
  return type(stubs) == "table" and stubs[itemId] or nil
end

function Data:GetRecipe(spellId)
  local index = self:Get("RecipeIndex")
  if not index then
    return nil
  end
  local skill = index[spellId]
  if skill == nil then
    return nil
  end
  local recipes = self:Get("Recipes_" .. skill)
  return recipes and recipes[spellId] or nil
end

function Data:GetUses(itemId)
  local uses = self:Get("Uses")
  return uses and uses[itemId] or nil
end

-- Every recipe that asks for this item as a tool, whichever of the two ways the build states it.
--
-- A recipe names its tools either by totem CATEGORY (recipe.tools, which is reached backwards
-- through the item's own tc and the Tools index) or by the exact ITEM (recipe.toolItems, reached
-- backwards through the Uses index's tool list). The two are not alternatives: an item with no
-- totem category at all, such as Flint and Tinder, is only ever reachable the second way, which
-- is why a lookup that only walked the categories answered "no known uses" for it.
--
-- Answers { { spell = spellId, category = totemCategoryId or nil } }, sorted by spell and with
-- one entry per recipe: a recipe that states both ways keeps its category, because that is the
-- name a row shows. Built once per item, because Core/Graph.lua asks on every collapsed row.
function Data:ToolRecipes(itemId)
  if type(itemId) ~= "number" then
    return EMPTY
  end
  self.toolRecipes = self.toolRecipes or {}
  local held = self.toolRecipes[itemId]
  if held then
    return held
  end
  local found, at = {}, {}
  local item = self:GetItem(itemId)
  if item and item.tc then
    for _, spell in ipairs(self:GetTools(item.tc) or EMPTY) do
      if not at[spell] then
        at[spell] = true
        found[#found + 1] = { spell = spell, category = item.tc }
      end
    end
  end
  local uses = self:GetUses(itemId)
  for _, spell in ipairs((uses and uses.tool) or EMPTY) do
    if not at[spell] then
      at[spell] = true
      found[#found + 1] = { spell = spell }
    end
  end
  table.sort(found, function(a, b)
    return a.spell < b.spell
  end)
  self.toolRecipes[itemId] = found
  return found
end

function Data:GetSkill(skillId)
  local skills = self:Get("Skills")
  return skills and skills[skillId] or nil
end

function Data:GetSkillName(skillId)
  local skill = self:GetSkill(skillId)
  return skill and skill.n or ("Skill " .. tostring(skillId))
end

-- The class name and, where a subclass id is given, the subclass name: "Trade Goods", "Parts".
--
-- baseline reads the names the comparison build used instead. The generated module carries them
-- as bn and bsub, and only where that build named it differently, so anything the two builds
-- agree on still answers with the one name. This is what lets the old side of a class or
-- subclass change read "Trade Goods" where the new side reads "Trade Goods (OBSOLETE)".
function Data:GetClassName(classId, subclassId, baseline)
  local classes = self:Get("Classes")
  local class = classes and classes[classId]
  if not class then
    return nil, nil
  end
  local name = class.n
  local sub = nil
  if subclassId ~= nil and class.sub then
    sub = class.sub[subclassId]
  end
  if baseline then
    if class.bn then
      name = class.bn
    end
    if subclassId ~= nil and class.bsub and class.bsub[subclassId] ~= nil then
      sub = class.bsub[subclassId]
    end
  end
  return name, sub
end

function Data:GetEnchant(enchantId)
  local enchants = self:Get("Enchants")
  return enchants and enchants[enchantId] or nil
end

function Data:GetSet(setId)
  local sets = self:Get("Sets")
  return sets and sets[setId] or nil
end

-- The item sets that name an item, sorted by set id, or nothing.
--
-- An item record states its own set and the forward lookup reads it there. A withheld item's
-- stub states nothing but its class, its subclass, its slot and its icon, and 2,225 of build
-- 1.60.1.69913's withheld ids are named by an ItemSet row all the same, so the only way back to
-- the set is from the set's own member list. Built once over the Sets module the first time a
-- stub is asked, and then reused; Reset drops it.
function Data:SetsForItem(itemId)
  if not self.setMembers then
    local index = {}
    self.setMembers = index
    for setId, set in pairs(self:Get("Sets") or EMPTY) do
      for _, member in ipairs(set.items or EMPTY) do
        local held = index[member]
        if not held then
          held = {}
          index[member] = held
        end
        held[#held + 1] = setId
      end
    end
    for _, held in pairs(index) do
      table.sort(held)
    end
  end
  return self.setMembers[itemId] or EMPTY
end

function Data:GetTools(totemCategory)
  local tools = self:Get("Tools")
  return tools and tools[totemCategory] or nil
end

-- The tool a recipe asks for, as the client names it ("Blacksmith Hammer"). A build the
-- module was not compiled from, or a category it never named, falls back to the id so a
-- row still says which tool it means.
function Data:GetTotemCategoryName(totemCategory)
  local categories = self:Get("TotemCategories")
  local name = categories and categories[totemCategory]
  return name or ("tool category " .. tostring(totemCategory))
end

function Data:GetDisenchant()
  return self:Get("Disenchant")
end

function Data:GetDiff()
  return self:Get("Diff")
end

-- Brief DV1: items no player can ever get. The pipeline flags a developer item (dv 1, such as
-- "DEPRECATED" or "Transmog UI Chest Item") and one probably never released (dv 2) on its row,
-- and lists every such id, named or undiscovered, in the Diff module as items.dev = { [id] = 1
-- or 2 }. That set is the one lookup: every surface that hides these items asks it, one table
-- read per id.
--
-- Diff ships in ItemTree itself (a core module, read at login), so this never needs
-- ItemTree_Data and never asks for it to be loaded: a hover or a bag badge at login answers from
-- the core set. A data build that names Diff as on demand, and has not loaded it yet, answers
-- as if nothing were flagged rather than forcing the load. Older data with no dev set flags
-- nothing, and nothing here can raise.
function Data:DevSet()
  local cache = type(self.cache) == "table" and self.cache or EMPTY
  local diff = cache["Diff"]
  if diff == nil then
    if self:IsOnDemand("Diff") then
      return EMPTY
    end
    diff = self:Get("Diff")
  end
  local items = type(diff) == "table" and diff.items or nil
  local dev = type(items) == "table" and items.dev or nil
  if type(dev) ~= "table" then
    return EMPTY
  end
  return dev
end

-- 1 for a developer item, 2 for one probably never released, nil for every other id.
function Data:HiddenKind(itemId)
  local id = tonumber(itemId)
  if not id then
    return nil
  end
  local kind = self:DevSet()[id]
  if kind == 1 or kind == 2 then
    return kind
  end
  return nil
end

-- Whether no player can ever get this item, so search, the Discoveries tab, the badges and the
-- tree leave it out. False, never nil. Opened directly, its page says why (UI/InfoPanel.lua).
function Data:IsHidden(itemId)
  return self:HiddenKind(itemId) ~= nil
end

-- Items sharing a totem category (the tools themselves), sorted by id. Brief P4: the pipeline
-- ships the lists (the ToolItems module, ItemTree-Data item_lists.py build_tool_items), so a
-- recipe's tool row never walks every item. Kept per category in Data.toolItems, which Reset and
-- ResetHarvest drop. The list must not be modified.
function Data:ItemsWithTotemCategory(totemCategory)
  self.toolItems = self.toolItems or {}
  local held = self.toolItems[totemCategory]
  if held then
    return held
  end
  local lists = self:Get("ToolItems")
  held = type(lists) == "table" and lists[totemCategory] or nil
  if type(held) ~= "table" then
    held = EMPTY
  end
  self.toolItems[totemCategory] = held
  return held
end

-- Brief P2 (#10): the two search indexes, built a slice at a time.
--
-- Data:NameIndex and Data:CreatureIndex cost about 70 ms together on the shipped data, which the
-- first keystroke used to pay. UI/Frame.lua now starts this build once the window is first
-- shown and hands it one slice a frame (Data:SearchIndexStep); a search asked for before the
-- build is done finishes it on the spot (Data:NameIndex and Data:CreatureIndex below run the
-- rest of it with no budget), so no answer is ever partial. Every stage is resumable: the item
-- half by position in the Names module, the creature entries by position, and the creature sort
-- as a merge sort whose runs and merges are also counted against the budget. The creature order
-- is the one table.sort gave: the comparator is total (a name, then a unique place in the string
-- table), so any correct sort gives the same list. Reset, ResetHarvest and ResetEra drop a build
-- in flight with the indexes.
--
-- Brief P3: the item half reads the Names module, which the pipeline ships already sorted by
-- name then id as parallel arrays (ids, names, q, c, i, era, idOrder: see ItemTree-Data
-- compile_lua.py build_names), so the search never builds an Items table and never sorts. The
-- index it builds is two arrays, not a table per item: at[k] is the k-th searchable name's place
-- in Names and lower[k] that name in lower case, the one thing a keystroke compares. A search
-- makes a table for each result it answers and for nothing else.

-- A false in a Names column stands for a field the row does not state.
local function orNil(value)
  if value == false then
    return nil
  end
  return value
end

-- The Names module, or nil where the data ships none.
local function namesModule(self)
  local names = self:Get("Names")
  if type(names) == "table" and type(names.ids) == "table" and type(names.names) == "table" then
    return names
  end
  return nil
end

-- What the Names module says about the row at pos: id, name, quality, class, icon and whether it
-- is a Classic Era row. An icon of 0 is one the row has none of.
local function namesRow(names, pos)
  local icon = names.i and names.i[pos] or nil
  if icon == 0 or icon == false then
    icon = nil
  end
  local era = nil
  if inSorted(names.era, pos) then
    era = true
  end
  return names.ids[pos], names.names[pos], orNil(names.q and names.q[pos]), orNil(names.c and names.c[pos]), icon, era
end

local function byCreatureName(a, b)
  if a.name ~= b.name then
    return a.name < b.name
  end
  return a.nameIndex < b.nameIndex
end

-- How many entries a run of the merge sort starts with, sorted in one table.sort call.
local SORT_RUN = 64

-- Placing an entry in a merge costs about a quarter of reading a name, so a unit of budget buys
-- four placements. Brief SI1, measured offline over the shipped data: a name read about 0.33
-- microseconds, a merge placement about 0.08 and an entry of a run about 0.31, since table.sort
-- compares it about six times. So an entry sorted into its run counts as SORT_RUN_PLACES
-- placements, and every step of the sort takes about as long as a step of names.
local SORT_PLACES_PER_UNIT = 4
local SORT_RUN_PLACES = 4

-- A resumable sort of list by less. Answers a sorter whose step(budget) does at most about
-- budget units of work (one unit per element placed in a merge, SORT_RUN_PLACES per element sorted
-- into a run) and answers the sorted list once done, nil before. With a budget of math.huge and
-- nothing done yet, it is one table.sort.
local function newSorter(list, less)
  local sorter = { src = list, n = #list, stage = "runs", at = 1 }
  function sorter.step(budget)
    local n = sorter.n
    if sorter.stage == "runs" and sorter.at == 1 and budget == math.huge then
      table.sort(list, less)
      sorter.stage, sorter.result = "done", list
    end
    local spent = 0
    while sorter.stage == "runs" and spent < budget do
      local from = sorter.at
      if from > n then
        sorter.stage, sorter.width, sorter.at = "merge", SORT_RUN, 1
        sorter.dst = {}
        break
      end
      local to = math.min(from + SORT_RUN - 1, n)
      local run = {}
      for index = from, to do
        run[#run + 1] = list[index]
      end
      table.sort(run, less)
      for index = from, to do
        list[index] = run[index - from + 1]
      end
      sorter.at = to + 1
      spent = spent + (to - from + 1) * SORT_RUN_PLACES
    end
    while sorter.stage == "merge" and spent < budget do
      local width = sorter.width
      if width >= n then
        sorter.stage, sorter.result = "done", sorter.src
        break
      end
      local src, dst = sorter.src, sorter.dst
      -- One merge of two neighbouring runs, resumed where the last slice left it.
      if not sorter.left then
        local from = sorter.at
        if from > n then
          sorter.src, sorter.dst = dst, src
          sorter.width, sorter.at = width * 2, 1
        else
          sorter.left, sorter.leftEnd = from, math.min(from + width - 1, n)
          sorter.right, sorter.rightEnd = sorter.leftEnd + 1, math.min(from + 2 * width - 1, n)
          sorter.out = from
        end
      else
        local left, leftEnd, right, rightEnd, out =
          sorter.left, sorter.leftEnd, sorter.right, sorter.rightEnd, sorter.out
        while out <= rightEnd and spent < budget do
          if right > rightEnd or (left <= leftEnd and not less(src[right], src[left])) then
            dst[out] = src[left]
            left = left + 1
          else
            dst[out] = src[right]
            right = right + 1
          end
          out = out + 1
          spent = spent + 1
        end
        sorter.left, sorter.right, sorter.out = left, right, out
        if out > rightEnd then
          sorter.left = nil
          sorter.at = rightEnd + 1
        end
      end
    end
    if sorter.stage == "done" then
      return sorter.result
    end
    return nil
  end
  return sorter
end

-- The build in flight, made the first time a step or an index asks. The item half walks the
-- Names module a position at a time (stage "names"), then the creatures' names, entries and sort.
local function searchBuild(self)
  local build = self.searchBuild
  if build then
    return build
  end
  build = { stage = "names" }
  self.searchBuild = build
  return build
end

-- The item half of the build: at most budget units, one per name read, answering what is left of
-- the budget. The rules are the ones the old walk over the Index and the item tables kept:
--
--   an Index item with a name is searchable unless it is a harvested item the setting hides,
--     which has no name to search, the way its stub had none;
--   a Classic Era row (brief D5: a withheld item that carries its Classic Era details) is
--     searchable, marked era, while the setting shows them. With the setting off, an item the
--     client can name is still found: by the collector's own note, through Data:Discovered in
--     SearchItems.
--
-- Whether the Era rows are shown is read once, when the walk starts, and a change of the setting
-- drops the index (Data:ResetEra), so a build never mixes the two answers.
local function stepNames(self, build, budget)
  if build.stage == "creatures" then
    -- The names were built and something dropped them since, without a Reset: start them again.
    build.stage, build.items = "names", nil
  end
  while budget > 0 and not self.nameIndex do
    if not build.items then
      build.items = { names = namesModule(self) or EMPTY, at = {}, lower = {} }
      build.pos, build.eraAt, build.era = 1, 1, self:EraShown()
      build.dev = self:DevSet()
      -- Brief SI1: the set up is a step of its own. Where the window opens before the login slicer
      -- reached the Names module (the owner's runs at 1 and 2 s), it builds the module here, one
      -- table constructor that cannot be cut (about 0.5 ms offline), and Data:SearchIndexSlice
      -- weighs the step like any other: a long one ends its slice.
      if budget ~= math.huge then
        budget = 0
      end
    end
    local index = build.items
    local names = index.names
    local ids, list, eras = names.ids or EMPTY, names.names or EMPTY, names.era or EMPTY
    local at, lower, dev = index.at, index.lower, build.dev or EMPTY
    local pos, eraAt, count = build.pos, build.eraAt, #ids
    while budget > 0 and pos <= count do
      local keep
      if eras[eraAt] == pos then
        eraAt = eraAt + 1
        keep = build.era
      else
        keep = not self:HarvestMasked(ids[pos])
      end
      -- Brief DV1: an item no player can get is never searchable.
      if keep and dev[ids[pos]] then
        keep = false
      end
      if keep then
        at[#at + 1] = pos
        lower[#lower + 1] = list[pos]:lower()
      end
      pos = pos + 1
      budget = budget - 1
    end
    build.pos, build.eraAt = pos, eraAt
    if pos > count then
      self.nameIndex = index
      build.stage, build.items, build.dev = "creatures", nil, nil
    end
  end
  return budget
end

-- Brief EK1: the page key of the Classic Era creature or vendor at one string index
-- (EraSources.PageKey, the one helper that builds it), or nil where the table states no creature
-- id for it or EraSources is not loaded.
local function pageKey(source, nameIndex)
  local EraSources = ItemTree.EraSources
  if type(source) ~= "table" or type(EraSources) ~= "table" or type(EraSources.PageKey) ~= "function" then
    return nil
  end
  local ok, key = pcall(EraSources.PageKey, source, nameIndex)
  if ok and type(key) == "string" then
    return key
  end
  return nil
end

-- Brief SI1: what one creature entry costs in units of budget. Reading its page key and making its
-- table costs about four times what reading a name does (1.3 microseconds against 0.33, offline over
-- the shipped data), so a step of entries takes about as long as a step of names.
local CREATURE_ENTRY_UNITS = 4

-- The creature half: the creature names are read a piece at a time (EraSources.CreatureNamesStep,
-- one unit per name it reads), then turned into entries and sorted within the budget.
local function stepCreatures(self, build, budget)
  while budget > 0 and not self.creatureIndex do
    if not build.creatures then
      build.creatures, build.creatureAt = {}, 1
      build.names, build.source, build.creatureWalk = EMPTY, nil, nil
      local EraSources = ItemTree.EraSources
      local source = self:Get("EraSources")
      if
        type(source) == "table"
        and type(EraSources) == "table"
        and type(EraSources.CreatureNamesStep) == "function"
      then
        build.source, build.creatureWalk = source, {}
      end
      -- Brief SI1: a step of its own, like the names' set up. The module is built behind the
      -- loading screen, so this is a lookup but where that build did not run.
      if budget ~= math.huge then
        budget = 0
      end
    elseif build.creatureWalk then
      -- Brief SI1 (QA item 231): the names' walk, cut between steps. It was one call of about 3 ms
      -- offline, the owner's "search index 18 ms longest" on his slower PC.
      local EraSources = ItemTree.EraSources
      local walk = build.creatureWalk
      local ok, done, left = false, nil, nil
      if type(EraSources) == "table" and type(EraSources.CreatureNamesStep) == "function" then
        ok, done, left = pcall(EraSources.CreatureNamesStep, build.source, walk, budget)
      end
      if not ok or type(walk.out) ~= "table" then
        -- As the whole call did where it raised: no creatures at all, never a part of them.
        build.names, build.source, build.creatureWalk = EMPTY, nil, nil
      else
        budget = tonumber(left) or 0
        if done then
          build.names, build.creatureWalk = walk.out, nil
        end
      end
    elseif not build.creatureSorter then
      local names, entries = build.names, build.creatures
      local at = build.creatureAt
      while budget > 0 and at <= #names do
        local entry = names[at]
        -- Brief EK1: the creature's page, keyed by its creature id. A name the table states no id
        -- for has no page: it is still listed, with no key and noPage, and opens nothing.
        local key = pageKey(build.source, entry.nameIndex)
        entries[#entries + 1] = {
          key = key,
          noPage = key == nil or nil,
          nameIndex = entry.nameIndex,
          name = entry.name,
          lower = entry.name:lower(),
          type = entry.type,
          family = entry.family,
          low = entry.low,
          high = entry.high,
        }
        at = at + 1
        budget = budget - CREATURE_ENTRY_UNITS
      end
      build.creatureAt = at
      if at > #names then
        build.creatureSorter = newSorter(entries, byCreatureName)
      end
    else
      local sorted = build.creatureSorter.step(budget * SORT_PLACES_PER_UNIT)
      budget = 0
      if sorted then
        self.creatureIndex = sorted
        build.creatureSorter, build.names, build.creatures, build.source = nil, nil, nil, nil
      end
    end
  end
  return budget
end

-- One slice of the search index build: at most about budget units of work, one unit per name
-- read or placed. Answers true once both indexes are built (and at once when they already
-- were), false while there is more to do. A budget of math.huge finishes the lot.
function Data:SearchIndexStep(budget)
  budget = tonumber(budget) or math.huge
  if self.nameIndex and self.creatureIndex then
    self.searchBuild = nil
    return true
  end
  local build = searchBuild(self)
  if not self.nameIndex then
    budget = stepNames(self, build, budget)
  end
  -- Brief SI1: no step of the creature half is whole any more, so a step that finishes the names
  -- goes on into it with what is left (brief PF3b stopped it there, for the one call).
  if self.nameIndex and not self.creatureIndex and budget > 0 then
    stepCreatures(self, build, budget)
  end
  if self.nameIndex and self.creatureIndex then
    self.searchBuild = nil
    return true
  end
  return false
end

-- Brief PF3b: the window's slice of the search index build runs under the login slicer's millisecond
-- budget (Data.PRELOAD_BUDGET_MS, read through Data.SliceClock) rather than a count of work units:
-- the owner's hitch run read "search index 11 ms longest", and offline the 2000 unit slices ran from
-- 0.1 to 8.2 ms (the slice that met the creature names' one call). Each turn is a step of this many
-- units, and the clock is read between turns. Brief SI1: 100 units is a step of 0.03 to 0.06 ms
-- offline over the shipped data, whichever stage it is in (the creature entries and the sort weigh
-- their work to match), and some eight times that on the owner's slower PC.
Data.SEARCH_SLICE_UNITS = 100

-- One slice of the search index build: steps of Data.SEARCH_SLICE_UNITS while budget ms (by default
-- Data.PRELOAD_BUDGET_MS) are left. Answers true once both indexes are built, false while there is
-- more to do; the indexes are the ones Data:SearchIndexStep builds, whatever the slicing.
--
-- Brief SI1 (QA item 231): the first step always runs, and each later one only while the time left
-- is at least the longest step this slice has taken, so a slice ends before the step that would
-- carry it past the budget rather than after it, on whatever machine it runs. On the owner's slower
-- PC the slice that met the creature names' one call read 18 to 20 ms; that call is cut into steps
-- now (EraSources.CreatureNamesStep). The one step left that cannot be cut is the Names module's
-- constructor (about 0.5 ms offline), in the first slice where the window opens before the login
-- slicer built it.
function Data:SearchIndexSlice(budget)
  budget = tonumber(budget) or Data.PRELOAD_BUDGET_MS
  local now = Data.SliceClock()
  local deadline = now + budget
  local longest = 0
  while true do
    if self:SearchIndexStep(Data.SEARCH_SLICE_UNITS) then
      return true
    end
    local after = Data.SliceClock()
    if after - now > longest then
      longest = after - now
    end
    now = after
    if now + longest >= deadline then
      return false
    end
  end
end

-- Whether the name index still has to be built (no build finished yet). For the window, which
-- only starts a sliced build where there is one to do.
function Data:SearchIndexPending()
  return not (self.nameIndex and self.creatureIndex)
end

-- The item half of the search index, { names, at, lower } (see the note above stepNames): built
-- from the Names module the first time it is asked and then reused, and never an Items module. A
-- sliced build in flight (Data:SearchIndexStep) is finished here rather than started again, so a
-- search typed mid way gets the whole list.
local function itemSearchIndex(self)
  if not self.nameIndex then
    stepNames(self, searchBuild(self), math.huge)
    if self.nameIndex and self.creatureIndex then
      self.searchBuild = nil
    end
  end
  return self.nameIndex
end

-- Every searchable item as a list of entries sorted by name, { id, name, lower, quality, class,
-- icon, era }, for a caller that walks the whole list itself. The search box does not: it walks
-- the two arrays of the index and makes a table per result, because a table per item costs
-- several megabytes. Made from the index on the first call and kept until the index is dropped.
function Data:NameIndex()
  local index = itemSearchIndex(self)
  if self.nameEntries and self.nameEntriesFor == index then
    return self.nameEntries
  end
  local entries = {}
  for k, pos in ipairs(index.at) do
    local id, name, quality, class, icon, era = namesRow(index.names, pos)
    entries[k] =
      { id = id, name = name, lower = index.lower[k], quality = quality, class = class, icon = icon, era = era }
  end
  self.nameEntries, self.nameEntriesFor = entries, index
  return entries
end

-- Whether any searchable item other than itemId carries exactly this name. One pass over the
-- index, stopping at the first other item that does, and no table made on the way.
--
-- Brief PF6: an item hover asks this (UI/CollectorHooks.lua nameIsShared), so it never builds the
-- index. Before the window has built it, the Names module itself is walked, and a row of that
-- name counts by the index's own rule (stepNames): an Era row while the setting shows them, any
-- other unless the setting hides it as harvested, never a dev item. The same answer in about
-- 0.4 ms on the shipped data, where the index and Data:NameIndex's list cost 55 ms in the hover.
function Data:NameShared(name, itemId)
  if type(name) ~= "string" then
    return false
  end
  local index = self.nameIndex
  if index then
    local names = index.names
    for _, pos in ipairs(index.at) do
      if names.names[pos] == name and names.ids[pos] ~= itemId then
        return true
      end
    end
    return false
  end
  local names = namesModule(self)
  if not names then
    return false
  end
  local ids, era, dev = names.ids, self:EraShown(), self:DevSet()
  for pos, held in ipairs(names.names) do
    local id = ids[pos]
    if held == name and id ~= itemId then
      local keep
      if inSorted(names.era, pos) then
        keep = era
      else
        keep = not self:HarvestMasked(id)
      end
      if keep and not dev[id] then
        return true
      end
    end
  end
  return false
end

-- Brief P3: one item's name, quality, class and icon, from the Names module alone, so a reader
-- that needs nothing more (the Discoveries list) never builds an Items table:
--
--   { id, name, quality, class, icon, era }
--
-- The rules of Data:GetItem are kept: nil for an id Names does not hold, for a harvested item the
-- setting hides (its stub has no name), and for a Classic Era row Data:GetItem would not serve
-- (the setting off and the client unable to name it). The caller then asks Data:GetItem, which
-- answers the stub. era is true for a Classic Era row. A binary search over idOrder; nothing kept.
function Data:ItemGlance(itemId)
  if type(itemId) ~= "number" then
    return nil
  end
  local names = namesModule(self)
  local order = names and names.idOrder
  if type(order) ~= "table" then
    return nil
  end
  local ids = names.ids
  local low, high = 1, #order
  while low <= high do
    local mid = math.floor((low + high) / 2)
    local pos = order[mid]
    local at = ids[pos]
    if at == itemId then
      local id, name, quality, class, icon, era = namesRow(names, pos)
      if era then
        if not withheldInRuns(self, id) or (not self:EraShown() and not self:ClientNames(id)) then
          return nil
        end
      elseif self:HarvestMasked(id) then
        return nil
      end
      return { id = id, name = name, quality = quality, class = class, icon = icon, era = era }
    elseif at < itemId then
      low = mid + 1
    else
      high = mid - 1
    end
  end
  return nil
end

-- Brief R3: whether the data build names an item itself, from the core set's Summary alone (its
-- named runs, every Index id), so it answers at login without loading ItemTree_Data. Settings
-- play no part: a harvested item the setting hides is still one the build names. False, never
-- nil, and false where the data ships no Summary.
function Data:ShipsName(itemId)
  if type(itemId) ~= "number" then
    return false
  end
  local summary = self:Get("Summary")
  if type(summary) ~= "table" then
    return false
  end
  return inRuns(summary.named, itemId)
end

-- Brief R3: the name the data build gives an item on its own row (never a Classic Era row), with
-- no setting applied, or nil. load says whether ItemTree_Data may be loaded to answer; without
-- it, only a Names module already registered is read, so a login time caller never loads it.
function Data:ShippedName(itemId, load)
  if type(itemId) ~= "number" then
    return nil
  end
  if not load and self.cache.Names == nil and self.modules.Names == nil then
    return nil
  end
  local names = namesModule(self)
  local order = names and names.idOrder
  if type(order) ~= "table" then
    return nil
  end
  local ids = names.ids
  local low, high = 1, #order
  while low <= high do
    local mid = math.floor((low + high) / 2)
    local pos = order[mid]
    local at = ids[pos]
    if at == itemId then
      local _, name, _, _, _, era = namesRow(names, pos)
      if era or type(name) ~= "string" or name == "" then
        return nil
      end
      return name
    elseif at < itemId then
      low = mid + 1
    else
      high = mid - 1
    end
  end
  return nil
end

-- Brief P4: the name /itemtree show <name> means, read off the Names module rather than off every
-- item (UI/Slash.lua Slash.ResolveItem used to walk the Index and read each row). wanted is the
-- text already trimmed and in lower case. Answers
--
--   exactId, exactName, partialId, partialName
--
-- the lowest id whose name is wanted exactly, ignoring case, and the lowest id whose name contains
-- it, each with its name, or nil. Only the Index items count, as before: a Classic Era row is left
-- out, and so is a harvested item the setting hides (its stub has no name). A name the Index
-- holds twice now answers its lowest id every time; the walk it replaces took whichever pairs met
-- first. The lower case names are made one at a time and kept by nothing.
function Data:ResolveItemName(wanted)
  if type(wanted) ~= "string" or wanted == "" then
    return nil
  end
  local names = namesModule(self)
  if not names then
    return nil
  end
  local ids, list = names.ids, names.names
  local era = type(names.era) == "table" and names.era or EMPTY
  local eraAt = 1
  local exactId, exactName, partialId, partialName
  for pos = 1, #ids do
    while era[eraAt] and era[eraAt] < pos do
      eraAt = eraAt + 1
    end
    local id, name = ids[pos], list[pos]
    if era[eraAt] ~= pos and type(name) == "string" and not self:HarvestMasked(id) then
      local lower = name:lower()
      if lower == wanted then
        if not exactId or id < exactId then
          exactId, exactName = id, name
        end
      elseif lower:find(wanted, 1, true) and (not partialId or id < partialId) then
        partialId, partialName = id, name
      end
    end
  end
  return exactId, exactName, partialId, partialName
end

-- The search answer for the k-th entry of the index.
local function searchResult(index, k)
  local id, name, quality, _, icon, era = namesRow(index.names, index.at[k])
  return { id = id, name = name, quality = quality, icon = icon, era = era }
end

-- Case insensitive substring search over item names, sorted by name. limit defaults to 25.
function Data:FindItemsByName(query, limit)
  limit = tonumber(limit) or 25
  local out = {}
  if type(query) ~= "string" then
    return out
  end
  local needle = query:lower():match("^%s*(.-)%s*$")
  if needle == "" or limit <= 0 then
    return out
  end
  local index = itemSearchIndex(self)
  for k, lower in ipairs(index.lower) do
    if lower:find(needle, 1, true) then
      local id, name, quality, class = namesRow(index.names, index.at[k])
      out[#out + 1] = { id = id, name = name, quality = quality, class = class }
      if #out >= limit then
        break
      end
    end
  end
  return out
end

-- Brief S3, then brief SR4 (owner QA 2026-10-09: "wolf" did not show Charred Wolf Meat or Mangy
-- Wolf, "meat" did not show Charred Wolf Meat): the five tiers every search answer is ranked in,
-- the same for every kind of result (items, creatures, quests, vendors, zones, nodes, sets).
--
--   1  the name starts with the text as a WHOLE word: "Wolf Bracers", "Meat Cleaver", and an
--      exact name ("Wolf" itself)
--   2  a later word IS the text, whole: "Charred Wolf Meat", "Mangy Wolf", "Kodo Meat"
--   3  the name starts with the text as part of a longer word: "Wolfsbane", "Meathook Slicer"
--   4  a later word starts with the text: "Grunnda Wolfheart"
--   5  the text is anywhere else in the name: "Frostwolf Banner", "Blackwolf River"
--
-- A word starts after one of these characters: a space, an apostrophe, a hyphen, a bracket or a
-- colon. A match is WHOLE where the end of the name or a character that is not a letter or a
-- digit follows it (Thorium Ore and "Rich Ore-laden Sack" for "ore", not Orecrusher). The rule
-- reads the character before and after each place the text is found (not a frontier pattern,
-- which knows no apostrophe), and a name takes the best tier any of its matches earns, so "ore"
-- in "Boreal Ore Chest" is tier 2 by its second match although the first is inside a word, and a
-- name that starts with the text inside a longer word but holds it whole later on is tier 2.
--
-- Several typed words are one text, as before: "wolf meat" is matched as it stands, its first
-- word's start and its last word's end read by the same rule.
--
-- Inside a tier the order is the name's, then the id (brief SR4: before, tiers 2 and 4 put fewer
-- words first, which kept Charred Wolf Meat behind twenty two word meats). Every list a search
-- walks is already in name order, so a tier is filled in walk order and needs no sort.
--
-- Answers the tier, or nil for no match.
local WORD_BREAK = {}
for _, char in ipairs({ " ", "'", "-", "(", "[", ":" }) do
  WORD_BREAK[char:byte()] = true
end

-- Whether a byte is an ASCII letter or digit. The names are in lower case by then.
local function isWordByte(value)
  return value ~= nil
    and ((value >= 48 and value <= 57) or (value >= 97 and value <= 122) or (value >= 65 and value <= 90))
end

-- matchTier from the first place the text was found (at, never nil), so a scan that has already
-- asked string.find once does not ask it again (brief OPT2).
local find, byte = string.find, string.byte

local function matchTierAt(lower, needle, at)
  local size, best = #needle, 5
  if at == 1 then
    if not isWordByte(byte(lower, size + 1)) then
      return 1
    end
    -- Inside a longer word at the start: tier 3, unless the text is a whole word later on.
    best = 3
    at = find(lower, needle, 2, true)
  end
  while at do
    if WORD_BREAK[byte(lower, at - 1)] then
      if not isWordByte(byte(lower, at + size)) then
        return 2
      end
      if best > 4 then
        best = 4
      end
    end
    at = find(lower, needle, at + 1, true)
  end
  return best
end

local function matchTier(lower, needle)
  local at = find(lower, needle, 1, true)
  if not at then
    return nil
  end
  return matchTierAt(lower, needle, at)
end

local SEARCH_TIERS = 5

-- A fresh run per tier, for a scan to fill in walk order.
local function newTiers()
  return { {}, {}, {}, {}, {} }
end

-- Brief SR4: the counts every search answers mean every name is walked, so a name is ranked only
-- as far as a tier with room needs. open[tier] says whether a tier can still keep a match the walk
-- meets now (openTiers). tierWithRoom answers the tier of a name the text was found in at hit, or
-- nil where no tier it could be in has room. A name that starts with the text whole is tier 1 by
-- one byte; only where tier 2, 4 or 5 is open are the later matches walked (matchTierAt). A tier
-- answered is always the one matchTier answers, or one that is shut. (A single pattern for the
-- later whole word was tried and measured slower than this walk, 7 ms against 4 for "e" over the
-- shipped names.)
local function tierWithRoom(lower, needle, hit, open)
  if hit == 1 then
    if not isWordByte(byte(lower, #needle + 1)) then
      return 1
    end
    if not open[2] then
      -- Tier 2 or 3, and a full tier 2 leaves tier 3 no room either.
      return 3
    end
    return matchTierAt(lower, needle, 1)
  end
  if open[4] or open[5] then
    return matchTierAt(lower, needle, hit)
  end
  if open[2] and matchTierAt(lower, needle, hit) == 2 then
    return 2
  end
  return nil
end

-- Which tiers still have room, into open[1] to open[5], for a list answered tier by tier up to
-- limit: a tier has room while it holds fewer than limit and the tiers above it hold fewer than
-- limit between them. reserve (the item search) keeps tier 2 open until it is full itself,
-- because SR3's share can lift it above the end of tier 1; noLater shuts tiers 4 and 5 (the item
-- search's prefixCount says tiers 1 and 3 fill the limit). Asked again after every match kept.
local function openTiers(open, tiers, limit, reserve, noLater)
  local above = 0
  for tier = 1, SEARCH_TIERS do
    local held = #tiers[tier]
    local room = held < limit and above < limit
    if tier == 2 and reserve then
      room = held < limit
    elseif tier >= 4 and noLater then
      room = false
    end
    open[tier] = room
    above = above + held
  end
  return open
end

-- Merges two lists that are each in name order (by name, then id, the order the Names module and
-- the collector's list both keep) into one, keeping a's entry first on a tie, so a tier stays
-- alphabetical without a sort.
local function nameBefore(x, y)
  if x.name ~= y.name then
    return x.name < y.name
  end
  return (tonumber(x.id) or 0) < (tonumber(y.id) or 0)
end

local function mergeByName(a, b)
  if #b == 0 then
    return a
  end
  local out, i, j = {}, 1, 1
  while i <= #a or j <= #b do
    if j > #b or (i <= #a and not nameBefore(b[j], a[i])) then
      out[#out + 1] = a[i]
      i = i + 1
    else
      out[#out + 1] = b[j]
      j = j + 1
    end
  end
  return out
end

-- Brief S4: the search box also finds an item by its id, behind a prefix so a plain number is
-- still searched as text over the names. The spellings are "c:" (the one the owner asked for,
-- in either case), "id:" (the word itself) and "#" (how a number is usually written as an id),
-- each allowed a space before the digits: "c:1234", "C:1234", "c: 1234", "id:1234", "#1234".
-- The rest of the text has to be digits, at least one, and not all zeros (no id is 0); leading
-- zeros are dropped. Anything else, "c:" alone included, is text.
--
-- Answers { kind = "code", id = 1234, prefix = "1234" } for a code (id is the item the digits
-- name, prefix the digits every offered id starts with), or { kind = "text", needle = ... } with
-- the text trimmed and in lower case, the needle the name search compares. Pure.
local CODE_PREFIXES = { "c:", "id:", "#" }

-- Brief S8: "trainer:" and "t:", in either case and with spaces allowed after the colon, ask for the
-- trainers of a class or a profession ("t:lw", "trainer: hunter"). The answer is { kind = "trainer",
-- word = ... }, word the rest of the text trimmed, in lower case and its runs of spaces one ("" for
-- "t:" alone), which Core/TrainerSearch.lua reads; the item, creature and kind searches find
-- nothing for it. No name the data holds starts with either prefix.
local TRAINER_PREFIXES = { "trainer:", "t:" }

function Data.ParseSearch(text)
  if type(text) ~= "string" then
    return { kind = "text", needle = "" }
  end
  local lower = text:lower():match("^%s*(.-)%s*$")
  for _, prefix in ipairs(TRAINER_PREFIXES) do
    if lower:sub(1, #prefix) == prefix then
      local word = lower:sub(#prefix + 1):gsub("%s+", " ")
      return { kind = "trainer", word = word:match("^%s*(.-)%s*$") }
    end
  end
  for _, prefix in ipairs(CODE_PREFIXES) do
    if lower:sub(1, #prefix) == prefix then
      local digits = lower:sub(#prefix + 1):match("^%s*(%d+)$")
      if digits then
        digits = digits:match("^0*(%d*)$")
        if digits ~= "" then
          return { kind = "code", id = tonumber(digits), prefix = digits }
        end
      end
    end
  end
  return { kind = "text", needle = lower }
end

-- Whether an id's digits start with prefix.
local function idStartsWith(itemId, prefix)
  return type(itemId) == "number" and tostring(itemId):sub(1, #prefix) == prefix
end

-- The first place in idOrder whose id is at least from. Binary search.
local function firstIdAtLeast(names, from)
  local order, ids = names.idOrder, names.ids
  local low, high = 1, #order
  while low <= high do
    local mid = math.floor((low + high) / 2)
    if ids[order[mid]] < from then
      low = mid + 1
    else
      high = mid - 1
    end
  end
  return low
end

-- Whether the name search would offer the Names row at pos: the rules of stepNames, read live
-- (an Era row while the setting shows them, any other row unless a harvest the setting hides,
-- and never a developer item).
local function nameRowShown(self, names, pos, dev)
  local id = names.ids[pos]
  if dev[id] then
    return false
  end
  if inSorted(names.era, pos) then
    return self:EraShown()
  end
  return not self:HarvestMasked(id)
end

-- Up to limit Names rows whose id starts with prefix, ascending by id. Every id that starts with
-- the digits lies in one band per length (12, then 120 to 129, then 1200 to 1299 and so on), and
-- the bands are already in id order, so each is one binary search into idOrder and a short walk.
local function namesByCode(self, prefix, limit, dev)
  local out = {}
  local names = namesModule(self)
  local order = names and names.idOrder
  if type(order) ~= "table" or #order == 0 then
    return out
  end
  local top = names.ids[order[#order]]
  local base = tonumber(prefix)
  local from, width = base, 1
  while from <= top and #out < limit do
    local to = from + width - 1
    local at = firstIdAtLeast(names, from)
    while at <= #order and #out < limit do
      local pos = order[at]
      if names.ids[pos] > to then
        break
      end
      if nameRowShown(self, names, pos, dev) then
        local id, name, quality, _, icon, era = namesRow(names, pos)
        out[#out + 1] = { id = id, name = name, quality = quality, icon = icon, era = era }
      end
      at = at + 1
    end
    from, width = from * 10, width * 10
  end
  return out
end

-- Brief R3: the collector's discovered list (Data:Discovered) is columns, { id, name, lower,
-- quality }, one position per item, and a list of entry tables is still read the same way (a
-- spec's fake collector answers one). How many positions it holds:
local function discoveredCount(list)
  if type(list.id) == "table" and type(list.lower) == "table" then
    return #list.id
  end
  return #list
end

-- The id, the lower case name and the name at one position, with no table made.
local function discoveredAt(list, pos)
  if type(list.id) == "table" and type(list.lower) == "table" then
    return list.id[pos], list.lower[pos], list.name and list.name[pos]
  end
  local entry = list[pos]
  if type(entry) ~= "table" then
    return nil
  end
  return entry.id, entry.lower, entry.name
end

-- The entry at one position, { id, name, lower, quality }: the list's own table where it holds
-- entry tables, a new one where it holds columns.
local function discoveredEntry(list, pos)
  if type(list.id) == "table" and type(list.lower) == "table" then
    local quality = type(list.quality) == "table" and list.quality[pos] or nil
    return { id = list.id[pos], name = list.name and list.name[pos], lower = list.lower[pos], quality = quality }
  end
  return list[pos]
end

-- The row a New in Forever stub is offered as: its id, its icon and the neutral name the tree
-- gives it (Core/Graph.lua Graph.UndiscoveredName, looked up at call time because Graph loads
-- after this file), never a name the build withholds. With no Graph the name is left out, and
-- the dropdown words it by its id.
local function stubResult(self, itemId)
  local item = self:GetItem(itemId)
  local name = nil
  local Graph = ItemTree.Graph
  if type(item) == "table" and type(Graph) == "table" and type(Graph.UndiscoveredName) == "function" then
    local ok, value = pcall(Graph.UndiscoveredName, item)
    if ok and type(value) == "string" and value ~= "" then
      name = value
    end
  end
  return { id = itemId, name = name, icon = type(item) == "table" and item.i or nil }
end

-- The code search behind Data:SearchItems: every item the data can show whose id starts with
-- the digits, ascending by id, up to limit. The item the digits name is the smallest such id, so
-- it leads whenever it can be shown. What can be shown is what the name search offers (a Names
-- row by the rules of nameRowShown), an item the collector noted a name for (Data:Discovered),
-- and a New in Forever stub (Data:NewInForeverIds, drawn by stubResult); never a developer item.
-- Each source gives at most limit ids, so the lowest limit of their union are the lowest overall.
local function searchByCode(self, prefix, limit)
  local dev = self:DevSet()
  local byId, ids = {}, {}
  local function offer(entry)
    if not byId[entry.id] then
      byId[entry.id] = entry
      ids[#ids + 1] = entry.id
    end
  end
  for _, entry in ipairs(namesByCode(self, prefix, limit, dev)) do
    offer(entry)
  end
  local found = {}
  local discovered = self:Discovered()
  for pos = 1, discoveredCount(discovered) do
    local id, _, name = discoveredAt(discovered, pos)
    if id ~= nil and idStartsWith(id, prefix) and not dev[id] and type(name) == "string" then
      found[#found + 1] = discoveredEntry(discovered, pos)
    end
  end
  table.sort(found, function(a, b)
    return a.id < b.id
  end)
  for n = 1, math.min(#found, limit) do
    local entry = found[n]
    offer({ id = entry.id, name = entry.name, quality = entry.quality, icon = entry.icon, era = entry.era })
  end
  local stubs = 0
  for _, itemId in ipairs(self:NewInForeverIds()) do
    if stubs >= limit then
      break
    end
    if idStartsWith(itemId, prefix) and not dev[itemId] and not byId[itemId] then
      offer({ id = itemId, stub = true })
      stubs = stubs + 1
    end
  end
  table.sort(ids)
  local out = {}
  for n = 1, math.min(#ids, limit) do
    local entry = byId[ids[n]]
    if entry.stub then
      entry = stubResult(self, entry.id)
    end
    out[n] = entry
  end
  return out
end

-- Brief OPT2: the stamps Data:SearchItems marks the collector's ids with, one number per search.
-- Each table holds at most the ids the collector's list ever held, and the same ids every search.
local searchStamp = 0
local listedStamps, offeredStamps = {}, {}

-- Brief OPT2: how many names in an index start with each one and two byte text, counted once
-- per index (weak keyed, so a dropped index goes with its counts). Keys: the byte for one,
-- 256 + first * 256 + second for two. Brief SR4: the names that start with the text are tiers 1
-- and 3, so a text of one or two characters that starts at least limit names fills those two for
-- certain, and then tiers 4 and 5 can never reach the answer: the scan counts such a match and
-- ranks it no further.
local prefixCountsByIndex = setmetatable({}, { __mode = "k" })

local function prefixCount(index, needle)
  local size = #needle
  if size > 2 then
    return nil
  end
  local counts = prefixCountsByIndex[index]
  if not counts then
    counts = {}
    for _, lower in ipairs(index.lower) do
      local first, second = byte(lower, 1, 2)
      if first then
        counts[first] = (counts[first] or 0) + 1
        if second then
          local key = 256 + first * 256 + second
          counts[key] = (counts[key] or 0) + 1
        end
      end
    end
    prefixCountsByIndex[index] = counts
  end
  local first, second = byte(needle, 1, 2)
  if size == 1 then
    return counts[first] or 0
  end
  return counts[256 + first * 256 + second] or 0
end

-- Item search for the search box, as { id, name, quality, icon, era }: a case insensitive search
-- over every item name in the five tiers above (matchTier), filled tier by tier up to limit,
-- which defaults to 20, each tier in name order. Text that is not a string, or is blank, finds
-- nothing.
--
-- Brief SR4: answers a second value, how many items match in all (every tier, the collector's
-- discovered entries included, each item once), which the search box words as "+N more items".
-- The count comes out of the one walk the ranking already makes: the scan walks the whole index
-- every keystroke (a few ms on the shipped data) and keeps at most limit entries per tier, so a
-- tier lower down can never take a slot from one above it however early its names sort. A match
-- no tier with room could keep is counted and nothing more (no tier asked, no table made). A
-- limit of 0 answers no rows and still counts. The collector's discovered entries
-- (Data:Discovered) join the same tiers by the same rules.
--
-- Brief S4: text Data.ParseSearch reads as a code ("c:1234") is answered by searchByCode
-- instead, in the same row shape: the item with that id, then every id starting with the digits.
-- Its count is the rows it answers (a code search offers no "more").
--
-- Brief SR3 (owner QA 2026-10-07: "wolf" listed Wolf Bracers to Wolf Whistle and never Charred
-- Wolf Meat), kept by brief SR4 between its tiers 1 and 2: once tier 1 (the text as a whole word
-- at the start) would fill base slots, a share of them (SEARCH_WORD_RESERVE of base, at least one,
-- never more than tier 2 holds) goes to tier 2, tier 1 giving up that many of its last names. base
-- is limit unless the caller says: the search box asks with its own limit as base when it shows
-- "+20 more", so the rows already on screen keep their places and the new ones follow them. The
-- full order is then tier 1's first base minus the share, tier 2's first share, the rest of tier
-- 1, the rest of tier 2, then tiers 3, 4 and 5.
Data.SEARCH_WORD_RESERVE = 0.25

--- The slots the first tier gives up to whole word matches: the reserve for limit, no more than
--- the whole word matches found. Pure.
function Data.SearchWordReserve(limit, wholeFound)
  limit, wholeFound = tonumber(limit) or 0, tonumber(wholeFound) or 0
  if limit < 2 or wholeFound <= 0 then
    return 0
  end
  local reserve = math.max(1, math.floor(limit * Data.SEARCH_WORD_RESERVE))
  return math.min(reserve, wholeFound, limit - 1)
end

function Data:SearchItems(text, limit, base)
  limit = math.floor(tonumber(limit) or 20)
  local out = {}
  if type(text) ~= "string" or limit < 0 then
    return out, 0
  end
  local query = Data.ParseSearch(text)
  if query.kind == "code" then
    if limit == 0 then
      return out, 0
    end
    local found = searchByCode(self, query.prefix, limit)
    return found, #found
  end
  -- Brief S8: a trainer query ("t:lw") names no item.
  if query.kind ~= "text" then
    return out, 0
  end
  local needle = query.needle
  if needle == "" then
    return out, 0
  end
  base = math.floor(tonumber(base) or limit)
  local tiers = newTiers()
  local index = itemSearchIndex(self)
  -- An item the name index holds as a Classic Era entry may also be one the collector noted by
  -- the name the client gave it, so the collector's list skips an id the index matched. Brief
  -- OPT2 (audit F8): only an id the collector's list holds can ever be skipped, so only those are
  -- marked, and by this search's stamp in two tables kept between searches, which allocate
  -- nothing once they hold the list's ids. A plain set of every match cost about 1 MB a keystroke.
  local discovered = self:Discovered()
  local discoveredTotal = discoveredCount(discovered)
  searchStamp = searchStamp + 1
  local stamp, listed, offered = searchStamp, listedStamps, offeredStamps
  for pos = 1, discoveredTotal do
    local id = discoveredAt(discovered, pos)
    if id ~= nil and id == id then
      listed[id] = stamp
    end
  end
  local watch = discoveredTotal > 0
  local at, ids, lowers = index.at, index.names.ids, index.lower
  -- Brief SR4: whether the names starting with the text (tiers 1 and 3) are certain to fill the
  -- limit (prefixCount above), so that tiers 4 and 5 never reach the answer.
  local known = prefixCount(index, needle)
  local startsFill = known ~= nil and known >= limit
  -- Brief SR4: which tiers still have room (openTiers): each fills in name order, so a full one
  -- keeps what it has, and tier 3 and below are past the answer once the tiers above hold limit.
  local open = openTiers({}, tiers, limit, true, startsFill)
  local total = 0
  -- The first find is asked inline: most names do not hold the text, and a call per name was
  -- about a third of a keystroke's search.
  local k = 0
  while true do
    k = k + 1
    local lower = lowers[k]
    if lower == nil then
      break
    end
    local hit = find(lower, needle, 1, true)
    if hit then
      total = total + 1
      if watch then
        local id = ids[at[k]]
        if listed[id] == stamp then
          offered[id] = stamp
        end
      end
      local tier = tierWithRoom(lower, needle, hit, open)
      if tier and open[tier] then
        local run = tiers[tier]
        run[#run + 1] = searchResult(index, k)
        openTiers(open, tiers, limit, true, startsFill)
      end
    end
  end
  local found = newTiers()
  local dev = self:DevSet()
  -- Brief R3: an entry table is made only for a discovered name that matches.
  for pos = 1, discoveredTotal do
    local id, lower = discoveredAt(discovered, pos)
    if id ~= nil and offered[id] ~= stamp and not dev[id] and type(lower) == "string" then
      local tier = matchTier(lower, needle)
      if tier then
        total = total + 1
        local run = found[tier]
        if #run < limit then
          run[#run + 1] = discoveredEntry(discovered, pos)
        end
      end
    end
  end
  local merged = {}
  for tier = 1, SEARCH_TIERS do
    merged[tier] = mergeByName(tiers[tier], found[tier])
  end
  -- Brief SR3: tier 1 gives up its last names within base to tier 2's share.
  local reserve = 0
  if #merged[1] >= base then
    reserve = Data.SearchWordReserve(base, #merged[2])
  end
  local function take(list, from, to)
    for n = from, math.min(to, #list) do
      if #out >= limit then
        return
      end
      local entry = list[n]
      out[#out + 1] = { id = entry.id, name = entry.name, quality = entry.quality, icon = entry.icon, era = entry.era }
    end
  end
  take(merged[1], 1, base - reserve)
  take(merged[2], 1, reserve)
  take(merged[1], math.max(base - reserve, 0) + 1, #merged[1])
  take(merged[2], reserve + 1, #merged[2])
  for tier = 3, SEARCH_TIERS do
    take(merged[tier], 1, #merged[tier])
  end
  -- Brief BQ7: a soulbound Forever copy and its Classic item are one entry (Data.FoldCopyEntries),
  -- by the search's own test, which builds no item table (Data:SearchCopyPairs).
  local classicOf, copyOf = self:SearchCopyPairs(out)
  local _, folded = Data.FoldCopyEntries(out, classicOf, copyOf)
  -- Brief BQ25b (owner QA 2026-10-10 item 60): the pair is one result in the count too, so a search
  -- whose only hits are a pair offers no "+1 more item" that opens nothing new.
  return out, math.max(#out, total - (folded or 0))
end

-- Brief BQ7 (owner QA item 20, 2026-10-10): Forever's soulbound copies of Classic consumables
-- (Swiftness Potion 287975 beside the Classic 2459). By rule: the same name, the same use effects,
-- one bind on pickup and new in Forever (the Diff module's items.new), the other not bound on
-- pickup and not new. Build 1.60.1.70291 ships 15 such pairs, 287963 to 287980. No recipe in the
-- shipped data asks for a copy's id as a reagent, so the profession counts by id stand as they are.

-- An item row's use effect spells, sorted and joined, "" for none. Pure.
local function effectSpells(row)
  local out = {}
  for _, fx in ipairs(type(row) == "table" and type(row.fx) == "table" and row.fx or EMPTY) do
    if type(fx) == "table" and tonumber(fx[2]) then
      out[#out + 1] = tonumber(fx[2])
    end
  end
  table.sort(out)
  return table.concat(out, ",")
end

-- Whether copyRow is a soulbound Forever copy of classicRow: the same name, the same use effect
-- spells (at least one), the copy bound on pickup (b 1) and the Classic one not. The new in Forever
-- half is the caller's. Pure.
function Data.IsForeverCopy(copyRow, classicRow)
  if type(copyRow) ~= "table" or type(classicRow) ~= "table" then
    return false
  end
  if type(copyRow.n) ~= "string" or copyRow.n ~= classicRow.n then
    return false
  end
  if tonumber(copyRow.b) ~= 1 or tonumber(classicRow.b) == 1 then
    return false
  end
  local spells = effectSpells(copyRow)
  return spells ~= "" and spells == effectSpells(classicRow)
end

-- The ids this build added (the Diff module's items.new) as a set, built once until Data:Reset.
function Data:NewItemSet()
  if self.newItemSet then
    return self.newItemSet
  end
  local diff = self:GetDiff()
  local set = {}
  for _, id in ipairs(diff and diff.items and diff.items.new or EMPTY) do
    set[id] = true
  end
  self.newItemSet = set
  return set
end

-- Whether the item has a use effect (a row in the ItemEffects module, a small module of its own:
-- no item table is built to answer).
function Data:HasUseEffect(itemId)
  local effects = self:Get("ItemEffects")
  return type(effects) == "table" and effects[itemId] ~= nil
end

-- The Names module position of an id (a binary search over idOrder), or nil.
local function namesPos(names, itemId)
  local order, ids = names.idOrder, names.ids
  if type(order) ~= "table" then
    return nil
  end
  local low, high = 1, #order
  while low <= high do
    local mid = math.floor((low + high) / 2)
    local at = ids[order[mid]]
    if at == itemId then
      return order[mid]
    elseif at < itemId then
      low = mid + 1
    else
      high = mid - 1
    end
  end
  return nil
end

-- The other ids that share the name at pos: the Names module is sorted by name, so they are its
-- neighbours.
local function sameNameIds(names, pos)
  local out, list, ids = {}, names.names, names.ids
  local name = list[pos]
  local k = pos - 1
  while k >= 1 and list[k] == name do
    out[#out + 1] = ids[k]
    k = k - 1
  end
  k = pos + 1
  while list[k] ~= nil and list[k] == name do
    out[#out + 1] = ids[k]
    k = k + 1
  end
  return out
end

-- The other half of an item's pair, by the full rule (Data.IsForeverCopy over both rows): the
-- copy's id and false for a Classic item, the Classic id and true for a copy, nil for any other
-- item and while ItemTree_Data is not loaded (nothing here loads it). Only an item with a use
-- effect is looked at, and only the rows that share its name are read; each answer is kept until
-- Data:Reset.
function Data:ForeverCopyPair(itemId)
  if type(itemId) ~= "number" or not self:OnDemandLoaded() then
    return nil
  end
  self.copyPairs = self.copyPairs or {}
  local held = self.copyPairs[itemId]
  if held == nil then
    held = false
    local names = self:HasUseEffect(itemId) and namesModule(self) or nil
    local pos = names and namesPos(names, itemId) or nil
    if pos then
      local new = self:NewItemSet()
      for _, other in ipairs(sameNameIds(names, pos)) do
        if other ~= itemId and (new[other] == true) ~= (new[itemId] == true) and self:HasUseEffect(other) then
          local copyId, classicId = itemId, other
          if not new[itemId] then
            copyId, classicId = other, itemId
          end
          if Data.IsForeverCopy(self:GetItem(copyId), self:GetItem(classicId)) then
            held = { other, copyId == itemId }
            break
          end
        end
      end
    end
    self.copyPairs[itemId] = held
  end
  if held == false then
    return nil
  end
  return held[1], held[2]
end

-- The search's own test, which reads no item table (a search builds none): among entries
-- { id, name, class, icon }, the pairs with the same name, class and icon, both with a use effect
-- (hasEffect(id)), one new in Forever (newSet) and the other not, and never a quest item (class 12,
-- whose rows bind as quest items both ways). confirm(copyId, classicId), where given, must also
-- answer true for a pair: brief NB70707, 1.60.1.70707 added Forever versions of Superior Healing
-- Potion, Superior Mana Potion and Swiftness Potion (288896 to 288898) that share name, class, icon
-- and effect with their Classic items but are not soulbound copies, so the cheap test alone pairs
-- them (and took 288898 for Swiftness Potion's copy over the soulbound 287975). Answers classicOf
-- { [copyId] = classicId } and copyOf the other way. With confirm it finds the same 15 pairs as the
-- full rule on the shipped data (tests/spec/bq7_spec.lua holds the two together). Pure.
Data.QUEST_CLASS = 12

function Data.CopyPairsAmong(entries, newSet, hasEffect, confirm)
  local classicOf, copyOf = {}, {}
  if type(entries) ~= "table" or type(newSet) ~= "table" or type(hasEffect) ~= "function" then
    return classicOf, copyOf
  end
  local byName = {}
  for _, entry in ipairs(entries) do
    if type(entry) == "table" and type(entry.name) == "string" then
      byName[entry.name] = byName[entry.name] or {}
      table.insert(byName[entry.name], entry)
    end
  end
  for _, group in pairs(byName) do
    for _, copy in ipairs(group) do
      if newSet[copy.id] and tonumber(copy.class) ~= Data.QUEST_CLASS and hasEffect(copy.id) then
        for _, classic in ipairs(group) do
          if
            not newSet[classic.id]
            and classicOf[copy.id] == nil
            and copyOf[classic.id] == nil
            and classic.class == copy.class
            and classic.icon == copy.icon
            and hasEffect(classic.id)
            and (type(confirm) ~= "function" or confirm(copy.id, classic.id))
          then
            classicOf[copy.id], copyOf[classic.id] = classic.id, copy.id
          end
        end
      end
    end
  end
  return classicOf, copyOf
end

-- The search entries' pairs (Data.CopyPairsAmong), each entry's class read from the Names module
-- (Data:ItemGlance) only where two entries share a name, and each pair the cheap test finds
-- confirmed by the full rule (Data.IsForeverCopy over the two rows: only those few rows are read).
-- Two empty maps while ItemTree_Data is not loaded.
function Data:SearchCopyPairs(out)
  if type(out) ~= "table" or not self:OnDemandLoaded() then
    return {}, {}
  end
  local seen, twice = {}, {}
  for _, entry in ipairs(out) do
    if seen[entry.name] then
      twice[entry.name] = true
    end
    seen[entry.name] = true
  end
  local candidates = {}
  for _, entry in ipairs(out) do
    if twice[entry.name] then
      local glance = self:ItemGlance(entry.id)
      candidates[#candidates + 1] =
        { id = entry.id, name = entry.name, icon = entry.icon, class = glance and glance.class or nil }
    end
  end
  if #candidates == 0 then
    return {}, {}
  end
  local data = self
  return Data.CopyPairsAmong(candidates, self:NewItemSet(), function(id)
    return data:HasUseEffect(id)
  end, function(copyId, classicId)
    return Data.IsForeverCopy(data:GetItem(copyId), data:GetItem(classicId))
  end)
end

-- The search entries with each pair as one entry (the owner's ruling: one name, the two ids told
-- apart in the row): a copy whose Classic item is listed goes, and the Classic entry carries the
-- copy's id as pairId; a copy listed alone becomes its Classic item's entry with pairId. classicOf
-- maps a copy to its Classic id, copyOf the other way. Answers the list, changed in place, and how
-- many entries were folded into their pair (brief BQ25b: the search's total counts each pair once).
-- Pure.
function Data.FoldCopyEntries(out, classicOf, copyOf)
  if type(out) ~= "table" or type(classicOf) ~= "table" or type(copyOf) ~= "table" then
    return out, 0
  end
  local listed = {}
  for _, entry in ipairs(out) do
    listed[entry.id] = entry
  end
  local kept = {}
  for _, entry in ipairs(out) do
    local classic = classicOf[entry.id]
    if classic and listed[classic] and listed[classic] ~= entry then
      listed[classic].pairId = entry.id
    elseif classic then
      entry.pairId, entry.id = entry.id, classic
      kept[#kept + 1] = entry
    else
      if copyOf[entry.id] and entry.pairId == nil then
        entry.pairId = copyOf[entry.id]
      end
      kept[#kept + 1] = entry
    end
  end
  local folded = #out - #kept
  for index = 1, math.max(#out, #kept) do
    out[index] = kept[index]
  end
  return out, folded
end

-- Every creature the shipped Classic Era table names, sorted by name, for the search box. Built
-- once and then reused, the way Data:NameIndex is, and dropped by Data:Reset. Each entry is
-- { key, nameIndex, name, lower, type, family, low, high }: key is the npc node the creature page
-- is rooted on, the plain one per name with no place in it, keyed by its creature id (brief EK1,
-- Core/EraSources.lua EraSources.PageKey), so a creature found by name opens on every zone the
-- table knows it in. A name the table states no creature id for has no page: its entry has no key
-- and noPage = true, so it is still found and opens nothing.
--
-- The names are the table's own strings that carry a kind (ck), read through
-- EraSources.CreatureNames. Nothing is asked of the client and no item is queried: the names are
-- shipped data. EraSources loads after this file, so it is looked up at call time, and a build
-- that ships no table (or a harness with no EraSources) has no creatures to find.
function Data:CreatureIndex()
  if self.creatureIndex then
    return self.creatureIndex
  end
  stepCreatures(self, searchBuild(self), math.huge)
  if self.nameIndex and self.creatureIndex then
    self.searchBuild = nil
  end
  return self.creatureIndex
end

-- Brief N1: the Forever NPCs the search box finds beside the Classic Era creatures. Two sources,
-- both local and neither asking the client anything:
--
--   the Creatures module (Core/Creatures.lua, the creatures testers have met), read through
--     ItemTree.Creatures.Table, which builds the load on demand module the first time it is asked
--     the way the item search builds Names; every named creature whose name the Classic Era
--     creature index does not already hold, one per name (the lowest id where two share one);
--   the player's own records (Core/Collector.lua C:NpcNames): the vendors, the creatures that
--     dropped something and the quest givers the records name by id, where neither of the above
--     names that id or that name. Read on each search, because the records grow while playing.
--   Brief PS2: the PlayerSources module's own name table (Core/PlayerSources.lua), the vendors and
--     creatures players recorded that the Creatures module does not name, folded into the first
--     list by its rule (one per name, deduped by id against the other two).
--
-- The list out of the module is built on the first creature search and kept until Data:Reset, as
-- three columns in name order (ids, names, lowers: the name case folded) plus the module table,
-- because a table per creature costs four times as much. On build 1.60.1.70170 that is 2,000 names
-- out of 2,485 rows, about 175 KB beside the module's own 865 KB, built in about 4 ms.
local function creaturesModule()
  local Creatures = ItemTree.Creatures
  if type(Creatures) ~= "table" or type(Creatures.Table) ~= "function" then
    return nil
  end
  local ok, source = pcall(Creatures.Table)
  if ok and type(source) == "table" and type(source.c) == "table" then
    return source
  end
  return nil
end

-- Brief PS2: the PlayerSources module (Core/PlayerSources.lua), built on the first creature search
-- the way the Creatures module is, or nil where no build ships one. Its name table n names the
-- sources nothing else does (empty while Creatures names every one, which it does today).
local function playerSourcesModule()
  local PlayerSources = ItemTree.PlayerSources
  if type(PlayerSources) ~= "table" or type(PlayerSources.Table) ~= "function" then
    return nil
  end
  local ok, source = pcall(PlayerSources.Table)
  if ok and type(source) == "table" then
    return source
  end
  return nil
end

local function byForeverName(a, b)
  if a[2] ~= b[2] then
    return a[2] < b[2]
  end
  return a[1] < b[1]
end

-- Brief BQ25b (owner QA 2026-10-10 item 74): the client caches creatures named after a gathering
-- node (259198 to 259211, Silverleaf to Iron Deposit, 259209 "Copper Vein") with no type ("Not
-- specified", 10), no family and no title, and nothing records loot from them: stand ins for the
-- node, not creatures a player meets. Such a row whose name is a world object's name in the Classic
-- Era table (its ok list) is kept out of the creature search; the node's own row stands. A creature
-- the players' sources name keeps its row. Pure: row a Creatures module row, lower its name, nodes
-- the object names ({ [lower] = true }).
Data.NO_CREATURE_TYPE = 10
function Data.IsNodeStandIn(row, lower, nodes)
  if type(row) ~= "table" or type(nodes) ~= "table" or not nodes[lower] then
    return false
  end
  if row.t ~= nil and row.t ~= Data.NO_CREATURE_TYPE then
    return false
  end
  return row.f == nil and row.ti == nil
end

-- Brief RB2 (owner QA 2026-10-17 item 191: searching "Crest of Lordaeron" listed a Creatures row of
-- that name with the red "?" glyph and "Creature"). That row is npc 256102 in the Creatures data
-- (the client's creature cache and the miner's harvest): no type ("Not specified", 10), no family,
-- no title, display 139495, and nothing of ours records loot, a sale or a quest from it. It is the
-- client's stand in for the item of that name (the shape BQ25b found for the gathering nodes), as
-- are 42 more today, each named exactly as an item is (Peacebloom 258553, Greenhouse 260017, Camp
-- Tent 263398, Compact Critter Carrier 275364). Such a row is kept out of the creature search the
-- same way; the item's own rows stand. A creature the players' sources name keeps its row. Pure:
-- row a Creatures module row, name its name, names the Names module's names (sorted by name, the
-- order the pipeline writes them in, so one binary search answers).
function Data.IsItemStandIn(row, name, names)
  if type(row) ~= "table" or type(name) ~= "string" or type(names) ~= "table" then
    return false
  end
  if (row.t ~= nil and row.t ~= Data.NO_CREATURE_TYPE) or row.f ~= nil or row.ti ~= nil then
    return false
  end
  local low, high = 1, #names
  while low <= high do
    local middle = math.floor((low + high) / 2)
    local held = names[middle]
    if held == name then
      return true
    end
    if type(held) ~= "string" then
      return false
    end
    if held < name then
      low = middle + 1
    else
      high = middle - 1
    end
  end
  return false
end

-- The Classic Era table's world object names, lower cased, as a set: every name its ok list files
-- under an object kind (herb, vein, fishing pool, chest). Empty where the table is not there.
local function eraObjectNames()
  local reader = ItemTree.eraSources
  local ok, source = false, nil
  if type(reader) == "table" and type(reader.Table) == "function" then
    ok, source = pcall(reader.Table, reader)
  end
  local out = {}
  if not ok or type(source) ~= "table" or type(source.ok) ~= "table" or type(source.s) ~= "table" then
    return out
  end
  for nameIndex, number in pairs(source.ok) do
    local name = type(number) == "number" and source.s[nameIndex] or nil
    if type(name) == "string" and name ~= "" then
      out[name:lower()] = true
    end
  end
  return out
end

function Data:ForeverCreatureIndex()
  local held = self.foreverCreatures
  if held then
    return held
  end
  local era = {}
  for _, entry in ipairs(self:CreatureIndex()) do
    era[entry.lower] = true
  end
  local source = creaturesModule()
  local strings = source and type(source.s) == "table" and source.s or EMPTY
  local nodes = eraObjectNames()
  local shippedNames = playerSourcesModule()
  shippedNames = shippedNames and type(shippedNames.n) == "table" and shippedNames.n or EMPTY
  -- Brief RB2: the item names, for the item stand ins below.
  local itemNames = namesModule(self)
  itemNames = itemNames and itemNames.names or nil
  local byName = {}
  for id, row in pairs(source and source.c or EMPTY) do
    local name = type(id) == "number" and id > 0 and type(row) == "table" and strings[row.n] or nil
    if
      type(name) == "string"
      and name ~= ""
      and shippedNames[id] == nil
      and (Data.IsNodeStandIn(row, name:lower(), nodes) or Data.IsItemStandIn(row, name, itemNames))
    then
      name = nil
    end
    if type(name) == "string" and name ~= "" then
      local lower = name:lower()
      local kept = byName[lower]
      if not era[lower] and (not kept or id < kept[1]) then
        byName[lower] = { id, name, lower }
      end
    end
  end
  -- Brief PS2: the npcs the PlayerSources module names and the Creatures module does not, by the
  -- same rule (one per name, the lowest id; a Classic Era name or a name the Creatures module holds
  -- keeps its own row). players[id] marks each, so the player's own records never add the id twice,
  -- and vendors[id] each npc the module lists a sale for.
  local players, vendors = {}, {}
  local shipped = playerSourcesModule()
  local creatureRows = source and source.c or EMPTY
  for id, name in pairs(shipped and type(shipped.n) == "table" and shipped.n or EMPTY) do
    local row = type(id) == "number" and id > 0 and creatureRows[id] or nil
    local named = type(row) == "table" and type(strings[row.n]) == "string"
    if type(name) == "string" and name ~= "" and not named then
      local lower = name:lower()
      local kept = byName[lower]
      if not era[lower] and (not kept or (kept.players and id < kept[1])) then
        byName[lower] = { id, name, lower, players = true }
      end
    end
  end
  for _, list in pairs(shipped and type(shipped.v) == "table" and shipped.v or EMPTY) do
    for _, sale in ipairs(type(list) == "table" and list or EMPTY) do
      local npcId = type(sale) == "table" and tonumber(sale[1]) or nil
      if npcId then
        vendors[npcId] = true
      end
    end
  end
  local sorted = {}
  for _, entry in pairs(byName) do
    sorted[#sorted + 1] = entry
  end
  table.sort(sorted, byForeverName)
  -- Brief PS5: and the roles the module gives each npc (k), for the result row's role word.
  local roles = shipped and type(shipped.k) == "table" and shipped.k or EMPTY
  held = { ids = {}, names = {}, lowers = {}, source = source, players = players, vendors = vendors, roles = roles }
  for index, entry in ipairs(sorted) do
    held.ids[index], held.names[index], held.lowers[index] = entry[1], entry[2], entry[3]
    if entry.players then
      players[entry[1]] = true
    end
  end
  self.foreverCreatures = held
  return held
end

-- Whether a sorted list of names holds one, case folded: a binary search for the place the name
-- sorts at, then the case folded compare there. names(i) and lowers(i) read the list's i'th.
local function sortedHolds(count, nameAt, lowerAt, name)
  local low, high = 1, count
  while low <= high do
    local middle = math.floor((low + high) / 2)
    if nameAt(middle) < name then
      low = middle + 1
    else
      high = middle - 1
    end
  end
  return low <= count and lowerAt(low) == name:lower()
end

-- What the player's own records name by npc id (Core/Collector.lua C:NpcNames), or nothing. Asked
-- of the collector through ItemTree, looked up at call time like Data:Discovered.
local function npcRecords()
  local collector = ItemTree.collector
  if type(collector) ~= "table" or type(collector.NpcNames) ~= "function" then
    return EMPTY
  end
  local ok, named = pcall(collector.NpcNames, collector)
  if not ok or type(named) ~= "table" then
    return EMPTY
  end
  return named
end

-- The player's own NPCs that the module does not name by id, as { id, name, lower } entries sorted
-- by name, one per name (the lowest id). Whether the Classic Era index or the module holds the
-- name is asked only of a match (recordWanted), never of every record.
local function recordedNpcs(forever, named)
  local rows = forever.source and forever.source.c or EMPTY
  local strings = forever.source and type(forever.source.s) == "table" and forever.source.s or EMPTY
  local byName, list = {}, {}
  for id, record in pairs(named) do
    local name = type(id) == "number" and type(record) == "table" and record.name or nil
    local shipped = type(rows[id]) == "table" and type(strings[rows[id].n]) == "string"
    -- Brief PS2: an id the PlayerSources module's name stands for is that row, not a second one.
    if type(forever.players) == "table" and forever.players[id] then
      shipped = true
    end
    if type(name) == "string" and name ~= "" and not shipped then
      local lower = name:lower()
      local kept = byName[lower]
      if not kept or id < kept.id then
        byName[lower] = { id = id, name = name, lower = lower, record = record }
      end
    end
  end
  for _, entry in pairs(byName) do
    list[#list + 1] = entry
  end
  table.sort(list, function(a, b)
    if a.name ~= b.name then
      return a.name < b.name
    end
    return a.id < b.id
  end)
  return list
end

-- What a Forever NPC is, where something local says: "trainer" where the module's title for it
-- says Trainer (the client's own words over its head), "vendor" where the player's records or the
-- Forever vendors module already built list it, "quest" where the records saw it offer a quest.
-- nil otherwise. record is what the records hold for the id, or nil. Asked per result.
-- Brief PS5: shippedRoles is the PlayerSources module's k (roles as bits: 1 vendor, 2 quest giver,
-- 4 quest ender, 8 trainer, 16 stable master), which says "trainer", "vendor", "stable" or "quest"
-- in that order where nothing above does.
local function shippedRole(id, shippedRoles)
  local bits = type(shippedRoles) == "table" and tonumber(shippedRoles[id]) or nil
  if not bits or bits <= 0 then
    return nil
  end
  local function has(bit)
    return math.floor(bits / bit) % 2 == 1
  end
  if has(8) then
    return "trainer"
  elseif has(1) then
    return "vendor"
  elseif has(16) then
    return "stable"
  elseif has(2) or has(4) then
    return "quest"
  end
  return nil
end

local function foreverRole(id, source, record, shippedVendors, shippedRoles)
  local row = source and type(source.c) == "table" and source.c[id] or nil
  local title = type(row) == "table" and type(source.s) == "table" and source.s[row.ti] or nil
  if type(title) == "string" and title:lower():find("trainer", 1, true) then
    return "trainer"
  end
  local shipped = shippedRole(id, shippedRoles)
  if shipped == "trainer" then
    return shipped
  end
  if record and record.vendor then
    return "vendor"
  end
  -- Brief PS2: an npc the PlayerSources module lists a sale for.
  if type(shippedVendors) == "table" and shippedVendors[id] then
    return "vendor"
  end
  local vendors = ItemTree.ForeverVendors
  if type(vendors) == "table" and type(vendors.Loaded) == "function" then
    local ok, module = pcall(vendors.Loaded)
    local list = ok and type(module) == "table" and module.v or nil
    if type(list) == "table" and list[id] ~= nil then
      return "vendor"
    end
  end
  if shipped == "stable" then
    return shipped
  end
  if record and record.quest then
    return "quest"
  end
  return shipped
end

-- Brief SR4: one sorted list walked into the five tiers (matchTier), each kept to limit in name
-- order, every match counted and ranked only as far as a tier with room needs (tierWithRoom).
-- lowerAt(i) is the i'th name case folded and entryAt(i) the entry a match keeps, made only for a
-- match its tier has room for (brief OPT2). accept, where given, is asked of every match's entry
-- before it is kept or counted, so the count is what the search would show with no limit.
-- Answers the tiers and how many matched.
local function creatureTiers(count, lowerAt, entryAt, needle, limit, accept)
  local tiers, matched = newTiers(), 0
  local open = openTiers({}, tiers, limit)
  for index = 1, count do
    local lower = lowerAt(index)
    local hit = find(lower, needle, 1, true)
    if hit and accept then
      local entry = entryAt(index)
      if entry and accept(entry) then
        matched = matched + 1
        local run = tiers[matchTierAt(lower, needle, hit)]
        if #run < limit then
          run[#run + 1] = entry
        end
      end
    elseif hit then
      matched = matched + 1
      local tier = tierWithRoom(lower, needle, hit, open)
      if tier and open[tier] then
        local run = tiers[tier]
        run[#run + 1] = entryAt(index)
        openTiers(open, tiers, limit)
      end
    end
  end
  return tiers, matched
end

-- Whether a record only NPC that matched is shown: not where the Classic Era index or the module
-- holds its name (that row stands for it), and only with a page worth opening. One the records
-- name as a vendor or a drop always has one (its Sells or Loot tab); a quest giver alone only
-- where ViewModel.ViewsFor gives its key more than the item tabs (a Classic Era name with quests, a
-- sighting).
local function recordWanted(self, forever, entry)
  local era = self:CreatureIndex()
  local function eraName(index)
    return era[index].name
  end
  local function eraLower(index)
    return era[index].lower
  end
  local function metName(index)
    return forever.names[index]
  end
  local function metLower(index)
    return forever.lowers[index]
  end
  if sortedHolds(#era, eraName, eraLower, entry.name) then
    return false
  end
  if sortedHolds(#forever.names, metName, metLower, entry.name) then
    return false
  end
  local record = entry.record
  if record.vendor or record.dropped then
    return true
  end
  local ViewModel, Edges = ItemTree.ViewModel, ItemTree.Edges
  if type(ViewModel) ~= "table" or type(ViewModel.ViewsFor) ~= "function" or type(Edges) ~= "table" then
    return false
  end
  local ok, views = pcall(ViewModel.ViewsFor, "npc:" .. tostring(entry.id))
  return ok and type(views) == "table" and views ~= Edges.VIEWS
end

-- Creature search for the search box, beside Data:SearchItems and by the same rule: a case
-- insensitive search over every creature name in the same five tiers (matchTier), filled tier by
-- tier, at most limit per tier and limit in all, which defaults to 20, each tier in name order.
-- Text that is not a string, or is blank, finds nothing, and neither does a code ("c:1234",
-- Data.ParseSearch): a Classic Era creature's key is its page (brief EK1, its creature id
-- negated), which no code a player types names.
--
-- Brief SR4: answers a second value, how many creatures match in all (every tier, every source,
-- one per name as below), counted in the same walk; a limit of 0 answers no rows and still counts.
--
-- Each result is { key, name, type, family, low, high } and carries no item field at all: key is
-- the npc node key the creature page opens on, type and family are the CreatureType and beast
-- family the page's Type and Family lines word, and low and high the level band its Level line
-- states.
--
-- Brief N1: the Forever NPCs (Data:ForeverCreatureIndex and the player's records, above) are
-- searched by the same rule and merged into the same tiers, so the order holds across all
-- three sources. Each such result is { key = "npc:<id>", name, type, family, role, forever = true }:
-- type and family where the module states them, role "trainer", "vendor" or "quest" where
-- something local says (foreverRole), and never a level, because nothing local states one. One
-- row per name: a Classic Era name is the Classic Era result, a name the module holds is the
-- module's (its name wins over the record's), and only what is left comes from the records.
function Data:SearchCreatures(text, limit)
  limit = math.floor(tonumber(limit) or 20)
  local out = {}
  if type(text) ~= "string" or limit < 0 then
    return out, 0
  end
  -- Brief S8: nor does a trainer query ("t:lw").
  if Data.ParseSearch(text).kind ~= "text" then
    return out, 0
  end
  local needle = text:lower():match("^%s*(.-)%s*$")
  if needle == "" then
    return out, 0
  end
  local era = self:CreatureIndex()
  local eraTiers, eraCount = creatureTiers(#era, function(index)
    return era[index].lower
  end, function(index)
    return era[index]
  end, needle, limit)
  local forever = self:ForeverCreatureIndex()
  local metTiers, metCount = creatureTiers(#forever.ids, function(index)
    return forever.lowers[index]
  end, function(index)
    return { id = forever.ids[index], name = forever.names[index] }
  end, needle, limit)
  local named = npcRecords()
  local own = recordedNpcs(forever, named)
  local ownTiers, ownCount = creatureTiers(
    #own,
    function(index)
      return own[index].lower
    end,
    function(index)
      return own[index]
    end,
    needle,
    limit,
    function(entry)
      return recordWanted(self, forever, entry)
    end
  )
  local total = eraCount + metCount + ownCount
  for tier = 1, SEARCH_TIERS do
    for _, entry in ipairs(mergeByName(mergeByName(eraTiers[tier], metTiers[tier]), ownTiers[tier])) do
      if #out >= limit then
        return out, total
      end
      if entry.nameIndex then
        out[#out + 1] = {
          key = entry.key,
          noPage = entry.noPage,
          name = entry.name,
          type = entry.type,
          family = entry.family,
          low = entry.low,
          high = entry.high,
        }
      else
        local row = forever.source and forever.source.c[entry.id] or nil
        out[#out + 1] = {
          key = "npc:" .. tostring(entry.id),
          name = entry.name,
          type = type(row) == "table" and tonumber(row.t) or nil,
          family = type(row) == "table" and tonumber(row.f) or nil,
          role = foreverRole(entry.id, forever.source, named[entry.id], forever.vendors, forever.roles),
          forever = true,
        }
      end
    end
  end
  return out, total
end

-- The creature a name names, for /itemtree show: an exact name first (case insensitive), then the
-- first name alphabetically that contains the text. Answers the entry Data:CreatureIndex holds, or
-- nil. Text that is not a string, or is blank, names nothing.
function Data:FindCreature(text)
  if type(text) ~= "string" then
    return nil
  end
  local needle = text:lower():match("^%s*(.-)%s*$")
  if needle == "" then
    return nil
  end
  for _, entry in ipairs(self:CreatureIndex()) do
    if entry.lower == needle then
      return entry, true
    end
  end
  for _, entry in ipairs(self:CreatureIndex()) do
    if entry.lower:find(needle, 1, true) then
      return entry, false
    end
  end
  return nil
end

-- Items this client has watched the realm discover, as the entries Data:NameIndex answers with,
-- or nothing. A withheld item is not in the Index and so has no name to search, but the
-- collector wrote down the name the client gave it the first time it resolved (Core/Collector.lua
-- RecordDiscovery, item id, name, quality and the data build and nothing else), and that is what
-- keeps it findable in the search box after the client has forgotten it again.
--
-- Read through ItemTree rather than held as an upvalue: the collector loads after this file and
-- the harness swaps it out underneath. The list is the collector's own, built once and kept
-- until it records again, so a keystroke walks a list that is already sorted. Since brief R3 the
-- collector answers it as columns (C:DiscoveredEntries); a list of entry tables is read as well.
function Data:Discovered()
  local collector = ItemTree.collector
  if not collector or type(collector.DiscoveredEntries) ~= "function" then
    return EMPTY
  end
  local ok, entries = pcall(collector.DiscoveredEntries, collector)
  if not ok or type(entries) ~= "table" then
    return EMPTY
  end
  return entries
end

-- Brief SR1: "Search everything". With the setting on, the search box also asks the kinds of page
-- below, in this order, after the items and the creatures (UI/Frame.lua Frame.SearchAll). Each is a
-- name search over a list built once, on the first search that asks for that kind, out of data
-- already shipped and loaded: the Classic Era table, the Forever vendors, the curated quests, the
-- collector's own learned quest titles and the Sets module. Nothing is asked of the client and no
-- item is queried. The matching is the item search's own (matchTier above, brief SR4's five
-- tiers, each in name order), case folded, at most limit in all. A code ("c:1234",
-- Data.ParseSearch) finds none of them.
--
--   quest   the curated quests, the quests the collector learned a title for and every quest the
--           Classic Era table names, one entry per quest id (the first of those three that names it)
--   vendor  the names the Classic Era table lists as vendors only (a name that is a creature too is
--           already a creature result) and the Forever vendors something on this client names
--   zone    every area the Classic Era table names, one per name (the lower id where two share one)
--   node    every herb, vein, fishing pool and chest the Classic Era table files under an object kind
--   set     every item set the Sets module names
--
-- Spells, skills and enchants are not searched: a recipe's name is nearly always the name of the
-- item it makes, which the item search already answers, and a skill or an enchant page draws
-- nothing a search would be opened for.
Data.SEARCH_KINDS = { "quest", "vendor", "zone", "node", "set" }

-- A string that is not empty, or nil.
local function nonEmpty(text)
  if type(text) == "string" and text ~= "" then
    return text
  end
  return nil
end

-- The Classic Era reader and its table, or nil where none is loaded or the build ships none.
local function eraTable()
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.Table) ~= "function" then
    return nil, nil
  end
  local ok, source = pcall(era.Table, era)
  if ok and type(source) == "table" then
    return era, source
  end
  return era, nil
end

-- One name in the Classic Era string table, or nil.
local function eraString(source, index)
  local strings = type(source) == "table" and source.s or nil
  return nonEmpty(type(strings) == "table" and type(index) == "number" and strings[index] or nil)
end

-- One entry of a kind's list, as an array because an array part costs a third of what the same
-- fields cost by name, and a list holds thousands: [1] the id its page key carries, [2] the name,
-- [3] the name case folded (the one thing a keystroke compares), [4] the one fact the result row
-- says beside it (a quest's zone, a Forever vendor's area, whether a zone is an instance, a node's
-- kind, a set's piece count), or nil, and [5] the page key itself where it is not the kind's word
-- and [1] (brief EK1: a Classic Era vendor's page is keyed by its creature id, EraSources.PageKey,
-- while its [1] stays its name's place in the string table, negated, which orders it and says
-- where its pins are), or false for a Classic Era vendor with no page, which is listed with no key
-- and opens nothing.
local ENTRY_ID, ENTRY_NAME, ENTRY_LOWER, ENTRY_FACT, ENTRY_KEY = 1, 2, 3, 4, 5

local function kindEntry(id, name, fact, key)
  return { id, name, name:lower(), fact, key }
end

-- The quests, keyed by quest id: the curated table's names first, then the collector's, then the
-- Classic Era table's (qt, and the titles its quest rows name, which is the pass the first quest
-- page pays anyway: E:SetNames).
local function questEntries()
  local byId = {}
  for questId, quest in pairs(type(ItemTree.CuratedQuests) == "table" and ItemTree.CuratedQuests or EMPTY) do
    local name = type(questId) == "number" and type(quest) == "table" and nonEmpty(quest.name) or nil
    if name then
      byId[questId] = kindEntry(questId, name, nonEmpty(quest.zone))
    end
  end
  local collector = ItemTree.collector
  if type(collector) == "table" and type(collector.LearnedQuests) == "function" then
    local ok, learned = pcall(collector.LearnedQuests, collector)
    for questId, title in pairs(ok and type(learned) == "table" and learned or EMPTY) do
      if type(questId) == "number" and not byId[questId] and nonEmpty(title) then
        byId[questId] = kindEntry(questId, title)
      end
    end
  end
  -- Brief PS5: the titles the shipped player module states (Core/PlayerSources.lua), after the
  -- player's own and before Classic Era's, which never titles a quest the module does.
  local players = playerSourcesModule()
  for questId, entry in pairs(players and type(players.q) == "table" and players.q or EMPTY) do
    local title = type(questId) == "number" and type(entry) == "table" and nonEmpty(entry.t) or nil
    if title and not byId[questId] then
      byId[questId] = kindEntry(questId, title)
    end
  end
  local era, source = eraTable()
  if source then
    for questId, index in pairs(type(source.qt) == "table" and source.qt or EMPTY) do
      local name = eraString(source, index)
      if type(questId) == "number" and not byId[questId] and name then
        byId[questId] = kindEntry(questId, name)
      end
    end
    if type(era.SetNames) == "function" and pcall(era.SetNames, era) then
      for questId, title in pairs(type(era.questNames) == "table" and era.questNames or EMPTY) do
        if type(questId) == "number" and not byId[questId] and nonEmpty(title) then
          byId[questId] = kindEntry(questId, title)
        end
      end
    end
  end
  -- Brief GF5: the predicted titles (Core/QuestsPredicted.lua Titles) last, for a quest nothing of
  -- ours titles, so a new Forever quest is found by its title wherever a quest is.
  local predicted = ItemTree.QuestsPredicted
  if type(predicted) == "table" and type(predicted.Titles) == "function" then
    local ok, titles = pcall(predicted.Titles)
    for questId, title in pairs(ok and type(titles) == "table" and titles or EMPTY) do
      if type(questId) == "number" and not byId[questId] and nonEmpty(title) then
        byId[questId] = kindEntry(questId, title)
      end
    end
  end
  -- Brief RB3 (the owner's QA item 196): a dead twin quest is its live quest, found under the same
  -- title, so it is not a result of its own (Core/QuestFlags.lua LiveTwin).
  local flags = ItemTree.QuestFlags
  local liveTwin = type(flags) == "table" and type(flags.LiveTwin) == "function" and flags.LiveTwin or nil
  local out = {}
  for questId, entry in pairs(byId) do
    if not (liveTwin and liveTwin(questId)) then
      out[#out + 1] = entry
    end
  end
  return out
end

-- Brief EK1 2b: the page key a Forever npc id has where a Classic Era name is merged with it, out
-- of the one builder (EraSources.CreaturePageKey), or nil without the module. Brief VN1: with plain,
-- the Classic Era page key of that creature id where it is not merged (npc:-<id>).
local function mergedPageKey(npcId, plain)
  local EraSources = ItemTree.EraSources
  if type(EraSources) ~= "table" or type(EraSources.CreaturePageKey) ~= "function" then
    return nil
  end
  local ok, key = pcall(EraSources.CreaturePageKey, npcId, not plain)
  if ok and type(key) == "string" then
    return key
  end
  return nil
end

-- The vendors: a Classic Era name whose kind is vendor only opens its page (brief EK1, keyed by its
-- creature id, EraSources.PageKey; listed with no page where the table states none), and a Forever vendor
-- by its npc id, where the collector, the Merchant's Favor file or the module itself names it. A
-- vendor nothing names is left out: its row would say "Vendor (npc N)", which no player types.
-- Brief VN1: a Forever vendor named exactly as the Classic Era vendor of its own creature id is that
-- vendor, whose entry is listed already (with its side and zone) and opens its one page
-- (Core/ForeverVendors.lua OpenKey), so it is listed once: Vernon Hale 1678 read twice.
local function vendorEntries()
  local out = {}
  local EraSources = ItemTree.EraSources
  local _, source = eraTable()
  -- Brief EK1 2b: the pages the Classic Era entries open, so a merged vendor (its page is the plain
  -- npc:<id> the client's own entry opens too) is listed once. Brief VN1: each holds its name, lower
  -- cased.
  local listed = {}
  if source and type(EraSources) == "table" and type(EraSources.KindOf) == "function" then
    for nameIndex in pairs(type(source.ck) == "table" and source.ck or EMPTY) do
      local name = eraString(source, nameIndex)
      if name then
        local _, _, _, _, role = EraSources.KindOf(source, nameIndex)
        if role == "vendor" then
          local key = pageKey(source, nameIndex)
          if key then
            listed[key] = name:lower()
          end
          out[#out + 1] = kindEntry(-nameIndex, name, nil, key or false)
        end
      end
    end
  end
  local vendors = ItemTree.ForeverVendors
  if type(vendors) == "table" and type(vendors.Table) == "function" and type(vendors.Name) == "function" then
    local ok, module = pcall(vendors.Table)
    local list = ok and type(module) == "table" and module.v or nil
    for npcId, vendor in pairs(type(list) == "table" and list or EMPTY) do
      if type(npcId) == "number" and npcId > 0 and type(vendor) == "table" and not listed[mergedPageKey(npcId)] then
        local named, name = pcall(vendors.Name, npcId, module)
        name = named and nonEmpty(name) or nil
        if name and listed[mergedPageKey(npcId, true)] ~= name:lower() then
          out[#out + 1] = kindEntry(npcId, name, tonumber(vendor.a))
        end
      end
    end
  end
  return out
end

-- The zones and instances the Classic Era table names. Two areas of one name keep the lower id,
-- which is the rule E:AreaIdOf keeps, so a name is one result. An area the build has no zone map
-- for is an instance where the build ships maps at all (the rule the zone page itself reads).
local function zoneEntries()
  local EraSources = ItemTree.EraSources
  local _, source = eraTable()
  local out = {}
  if not source then
    return out
  end
  local maps = type(source.zm) == "table" and next(source.zm) ~= nil
  local byName = {}
  for areaId, index in pairs(type(source.z) == "table" and source.z or EMPTY) do
    local name = type(areaId) == "number" and eraString(source, index) or nil
    if name then
      local lower = name:lower()
      local held = byName[lower]
      if not held or areaId < held[ENTRY_ID] then
        local instance = false
        if maps and type(EraSources) == "table" and type(EraSources.MapOf) == "function" then
          instance = EraSources.MapOf(source, areaId) == nil
        end
        byName[lower] = kindEntry(areaId, name, instance)
      end
    end
  end
  for _, entry in pairs(byName) do
    out[#out + 1] = entry
  end
  return out
end

-- The herbs, veins, fishing pools and chests: every name the table files under an object kind (ok,
-- which carries exactly the names with map pins, so each opens a page). Brief EK1 2c: each opens its
-- page, keyed by its gameobject id (EraSources.ObjectKey), in the entry's key slot; one oi states no
-- id for is listed with no key and opens nothing. Its [1] stays its name's place, negated.
local function nodeEntries()
  local EraSources = ItemTree.EraSources
  local _, source = eraTable()
  local out = {}
  if not source or type(EraSources) ~= "table" or type(EraSources.ObjectKind) ~= "function" then
    return out
  end
  for nameIndex in pairs(type(source.ok) == "table" and source.ok or EMPTY) do
    local name = eraString(source, nameIndex)
    local word = name and EraSources.ObjectKind(source, nameIndex) or nil
    if word then
      local key = type(EraSources.ObjectKey) == "function" and EraSources.ObjectKey(source, nameIndex) or nil
      out[#out + 1] = kindEntry(-nameIndex, name, word, key or false)
    end
  end
  return out
end

-- The item sets the Sets module names, with how many pieces each lists.
local function setEntries(self)
  local out = {}
  local sets = self:Get("Sets")
  for setId, set in pairs(type(sets) == "table" and sets or EMPTY) do
    local name = type(setId) == "number" and type(set) == "table" and nonEmpty(set.n) or nil
    if name then
      out[#out + 1] = kindEntry(setId, name, type(set.items) == "table" and #set.items or 0)
    end
  end
  return out
end

local KIND_BUILDERS = {
  quest = questEntries,
  vendor = vendorEntries,
  zone = zoneEntries,
  node = nodeEntries,
  set = setEntries,
}

-- The node kind each search kind's page key carries.
Data.SEARCH_KIND_KEYS = { quest = "quest", vendor = "npc", zone = "zone", node = "object", set = "set" }

-- By name, then by id, so the order is the same on every load whatever pairs walked.
local function byKindName(a, b)
  if a[ENTRY_NAME] ~= b[ENTRY_NAME] then
    return a[ENTRY_NAME] < b[ENTRY_NAME]
  end
  return a[ENTRY_ID] < b[ENTRY_ID]
end

-- One kind's list, sorted by name: built on the first ask and kept until Data:Reset. A kind this
-- file does not know, or a builder that fails, is an empty list, and an empty list is kept too, so
-- a build that ships no Classic Era table pays for finding that out once.
function Data:KindIndex(kind)
  self.kindIndexes = self.kindIndexes or {}
  local held = self.kindIndexes[kind]
  if held then
    return held
  end
  local build = KIND_BUILDERS[kind]
  local list = {}
  if build then
    local ok, built = pcall(build, self)
    if ok and type(built) == "table" then
      list = built
    end
  end
  table.sort(list, byKindName)
  self.kindIndexes[kind] = list
  return list
end

-- What the lists hold once built, for the spec and the debug command: the entries per kind and in
-- all. A kind not built yet counts nothing.
function Data:KindIndexCounts()
  local counts = { total = 0 }
  for _, kind in ipairs(Data.SEARCH_KINDS) do
    local list = self.kindIndexes and self.kindIndexes[kind] or nil
    counts[kind] = list and #list or 0
    counts.total = counts.total + counts[kind]
  end
  return counts
end

-- The five tiers over one sorted list, filled tier by tier, at most limit in all, each tier in
-- name order: the rule Data:SearchCreatures keeps. Answers the entries and how many matched in all
-- (brief SR4), counted in the same walk. Brief F155: skip, where handed in, leaves an entry out of
-- both (a vendor of the other side while "Hide other faction data" is on); asked of a match only.
local function tierSearch(list, needle, limit, skip)
  local tiers, total = newTiers(), 0
  local open = openTiers({}, tiers, limit)
  for _, entry in ipairs(list) do
    local lower = entry[ENTRY_LOWER]
    local hit = find(lower, needle, 1, true)
    if hit and not (skip and skip(entry)) then
      total = total + 1
      local tier = tierWithRoom(lower, needle, hit, open)
      if tier and open[tier] then
        local run = tiers[tier]
        run[#run + 1] = entry
        openTiers(open, tiers, limit)
      end
    end
  end
  local out = {}
  for tier = 1, SEARCH_TIERS do
    for _, entry in ipairs(tiers[tier]) do
      if #out >= limit then
        return out, total
      end
      out[#out + 1] = entry
    end
  end
  return out, total
end

-- The Classic Era name of the zone a vendor stands in, for its result row: where its pins are
-- most (a Classic Era vendor, EraSources.PinAreas) or the area the Forever module places it in
-- (E:ZoneFacts). Asked per result, never per entry. nil where nothing places it.
local function vendorZone(entry)
  local era, source = eraTable()
  if not source then
    return nil
  end
  local id, areaId = entry[ENTRY_ID], entry[ENTRY_FACT]
  if id < 0 then
    local EraSources = ItemTree.EraSources
    if type(EraSources) == "table" and type(EraSources.PinAreas) == "function" then
      local ok, areas = pcall(EraSources.PinAreas, source, -id)
      local top = ok and type(areas) == "table" and areas[1] or nil
      return type(top) == "table" and nonEmpty(top.name) or nil
    end
    return nil
  end
  if areaId and type(era.ZoneFacts) == "function" then
    local ok, facts = pcall(era.ZoneFacts, era, "zone:" .. tostring(areaId))
    return ok and type(facts) == "table" and nonEmpty(facts.name) or nil
  end
  return nil
end

-- Brief F155 (owner QA 2026-10-14 item 155): the vendor search's skip while "Hide other faction
-- data" is on and the player's side is known (Core/Graph.lua Graph.HiddenSide): a Classic Era vendor
-- (a negative ENTRY_ID, its name's place) whose side the table states as the other one alone (cf,
-- EraSources.Faction). A neutral vendor, one whose side nothing states and every Forever vendor the
-- client's own tables list (no side in our data) stay. nil while nothing is hidden. Guarded.
local function otherSideVendor()
  local graph = ItemTree.Graph
  if type(graph) ~= "table" or type(graph.HiddenSide) ~= "function" or type(graph.SIDE_NUMBERS) ~= "table" then
    return nil
  end
  local ok, side = pcall(graph.HiddenSide)
  local mine = ok and graph.SIDE_NUMBERS[side] or nil
  local EraSources = ItemTree.EraSources
  local _, source = eraTable()
  if not mine or not source or type(EraSources) ~= "table" or type(EraSources.Faction) ~= "function" then
    return nil
  end
  return function(entry)
    local id = entry[ENTRY_ID]
    if type(id) ~= "number" or id >= 0 then
      return false
    end
    local stated = EraSources.Faction(source, -id)
    return (stated == 1 or stated == 2) and stated ~= mine
  end
end

--- Brief RB2 (owner QA 2026-10-17 item 191): the quest search's skip while "Hide other faction data"
--- is on and the player's side is known (Core/Graph.lua Graph.HiddenSide): a quest the final lists
--- give the other side alone (Graph.QuestSide, the rule that hides it from an item's Used by). A
--- quest open to both, one that only leans (item 194) and every quest while nothing is hidden stay.
--- prefix is the kind's key prefix ("quest"). nil while nothing is hidden. Guarded.
function Data.OtherSideQuestSkip(prefix)
  local graph = ItemTree.Graph
  if type(graph) ~= "table" or type(graph.HiddenSide) ~= "function" or type(graph.QuestSide) ~= "function" then
    return nil
  end
  local ok, side = pcall(graph.HiddenSide)
  local mine = ok and type(graph.SIDE_NUMBERS) == "table" and graph.SIDE_NUMBERS[side] or nil
  if not mine then
    return nil
  end
  return function(entry)
    local key = entry[ENTRY_KEY]
    if type(key) ~= "string" then
      key = tostring(prefix) .. ":" .. tostring(entry[ENTRY_ID])
    end
    local fine, stated = pcall(graph.QuestSide, nil, key)
    return fine and (stated == 1 or stated == 2) and stated ~= mine
  end
end

-- Name search over one kind of page. Answers at most limit results (20 by default), each
--
--   { key, kind, name, ... }
--
-- where key is the page's node key, kind the search kind ("quest", "vendor", "zone", "node" or
-- "set"), and beside them what the row's right hand column says: zone (a quest's, where the
-- curated table states one; a vendor's), instance (a zone with no map), node ("herb", "vein",
-- "fished" or "object") and pieces (a set's). No item field at all. Text that is not a string, is
-- blank or is a code finds nothing, and so does a kind this file does not search.
--
-- Brief SR4: answers a second value, how many entries of the kind match in all (every tier),
-- counted in the same walk; a limit of 0 answers no rows and still counts.
function Data:SearchKind(kind, text, limit)
  limit = math.floor(tonumber(limit) or 20)
  local out = {}
  local prefix = Data.SEARCH_KIND_KEYS[kind]
  if not prefix or type(text) ~= "string" or limit < 0 then
    return out, 0
  end
  -- Brief S8: nor does a trainer query ("t:lw").
  if Data.ParseSearch(text).kind ~= "text" then
    return out, 0
  end
  local needle = text:lower():match("^%s*(.-)%s*$")
  if needle == "" then
    return out, 0
  end
  -- Brief F155: the other side's vendors are left out while "Hide other faction data" is on.
  local skip = kind == "vendor" and otherSideVendor() or nil
  -- Brief RB2 (owner QA 2026-10-17 item 191): and the other side's quests, as Used by leaves them out.
  if kind == "quest" then
    skip = Data.OtherSideQuestSkip(prefix)
  end
  local entries, total = tierSearch(self:KindIndex(kind), needle, limit, skip)
  for _, entry in ipairs(entries) do
    local key = entry[ENTRY_KEY]
    if key == nil then
      key = prefix .. ":" .. tostring(entry[ENTRY_ID])
    end
    local result = { key = key or nil, kind = kind, name = entry[ENTRY_NAME] }
    if key == false then
      result.noPage = true
    end
    local fact = entry[ENTRY_FACT]
    if kind == "quest" then
      result.zone = fact
    elseif kind == "vendor" then
      result.zone = vendorZone(entry)
    elseif kind == "zone" then
      result.instance = fact == true
    elseif kind == "node" then
      result.node = fact
    elseif kind == "set" then
      result.pieces = fact
    end
    out[#out + 1] = result
  end
  return out, total
end

-- The disenchant band that covers an item, or nil when the item cannot be disenchanted: the
-- generated Disenchant module lists the item classes that can be, and a band covers one
-- quality and a range of item levels. The rule lives here rather than in Graph so that the
-- forward question ("what does this disenchant into") and the reverse one ("what disenchants
-- into this") are answered from the same reading of the bands.
function Data:DisenchantBand(item)
  if type(item) ~= "table" then
    return nil
  end
  local de = self:GetDisenchant()
  if not de or not de.bands then
    return nil
  end
  local classOk = false
  if de.classes then
    for _, class in ipairs(de.classes) do
      if class == item.c then
        classOk = true
      end
    end
  else
    classOk = item.c == 2 or item.c == 4
  end
  if not classOk then
    return nil
  end
  local quality, level = item.q, item.il or 0
  if not quality or quality < 2 or quality > 4 then
    return nil
  end
  for _, band in ipairs(de.bands) do
    if band.q == quality and level >= band.min and level <= band.max then
      return band
    end
  end
  return nil
end

-- Brief P4: what disenchants into a material ships from the pipeline, in the DisenchantFrom
-- module (ItemTree-Data item_lists.py build_disenchant_from), so a dust, essence or shard page
-- never walks every item. Per material, parallel arrays in id order: ids, il (item level), k (the
-- result, a position in out), rank (the place in the Sources view's order) and out, the distinct
-- results as { rate, min, max }, with exact, whether every source has a name. The specs hold them
-- to the walk Data:DisenchantBand and Data:DisenchantFacts make (tests/spec/item_lists_spec.lua).
-- One material's shipped lists, or nil for an item the Disenchant module names as no material.
local function disenchantFrom(self, materialId)
  local de = self:GetDisenchant()
  local materials = de and de.materials
  if not materials or not materials[materialId] then
    return nil
  end
  local from = self:Get("DisenchantFrom")
  local held = type(from) == "table" and from[materialId] or nil
  if type(held) == "table" and type(held.ids) == "table" then
    return held
  end
  return nil
end

-- The items that disenchant into one material, sorted by id. An item the Disenchant module
-- does not name as a material answers with nothing and never loads the lists, so rooting an
-- ordinary item costs nothing. The list is the module's own and must not be modified.
function Data:DisenchantSources(materialId)
  local held = disenchantFrom(self, materialId)
  return held and held.ids or EMPTY
end

-- The band entry that names one material, so a reverse edge carries the same chance and counts
-- the forward edge does. The same reading Core/Graph.lua makes of a band.
local function bandResult(band, materialId)
  for _, result in ipairs(band and band.out or EMPTY) do
    if result[1] == materialId then
      return result
    end
  end
  return nil
end

-- One source's facts for the "Disenchanted from" list of a material: { id, percent, quantity,
-- quantityMax, level, name }, from the shipped data only and read through Data:GetItem, exactly
-- as the graph reads them, so a harvested item the setting masks answers its stub here too.
-- It reads the source's own row, so it builds that row's Items module: the list itself reads
-- the shipped DisenchantFrom lists instead (Data:DisenchantOrder), and the specs read this.
function Data:DisenchantFacts(materialId, sourceId)
  local source = self:GetItem(sourceId)
  local result = bandResult(self:DisenchantBand(source), materialId)
  return {
    id = sourceId,
    percent = result and (result[2] or 0) * 100 or nil,
    quantity = result and result[3] or nil,
    quantityMax = result and result[4] or nil,
    level = source and source.il or -1,
    name = source and source.n or nil,
  }
end

-- Where an id sits in a sorted id list, or nil. Binary search.
local function positionIn(list, itemId)
  local low, high = 1, #list
  while low <= high do
    local mid = math.floor((low + high) / 2)
    local at = list[mid]
    if at == itemId then
      return mid
    elseif at < itemId then
      low = mid + 1
    else
      high = mid - 1
    end
  end
  return nil
end

-- One source's facts, made from the shipped arrays: Data:DisenchantFacts's reading, with rank,
-- and without the name, which only ever decided the order and exact and is shipped as both. A
-- harvested item the setting masks reads as its stub does there: no band, so no rate, no counts
-- and level -1, and no rank.
local function shippedFacts(self, held, pos)
  local id = held.ids[pos]
  if self:HarvestMasked(id) then
    return { id = id, level = -1 }
  end
  local result = held.out and held.out[held.k and held.k[pos]] or nil
  return {
    id = id,
    percent = result and (result[1] or 0) * 100 or nil,
    quantity = result and result[2] or nil,
    quantityMax = result and result[3] or nil,
    level = held.il and held.il[pos] or -1,
    rank = held.rank and held.rank[pos] or nil,
  }
end

-- Brief P2 (#7), brief P4: the "Disenchanted from" list of one material, in the order the Sources
-- view reads it in (Core/ViewModel.lua VM:_SortEntries): the likeliest result first, then the
-- highest item level, then the name, then the node key. Answers
--
--   { byId = { [sourceId] = facts }, exact = true or false }
--
-- where each facts table is Data:DisenchantFacts's with rank, its place in that order (Core/Graph.lua
-- adds the node key and the edge's fixed fields to it before it emits one). The order is the
-- pipeline's (the DisenchantFrom module's rank), so nothing is sorted here, and byId makes a facts
-- table the moment one is read and keeps none: a material costs its shipped arrays and nothing
-- held beside them (brief P3's row 7, Data.disenchantOrder, is gone). exact is false when a source
-- has no name of its own (a masked harvested item, whose name the view reads off the client
-- instead), and the view then sorts the group itself as it always did. Nil for an item the
-- Disenchant module does not name as a material.
function Data:DisenchantOrder(materialId)
  local held = disenchantFrom(self, materialId)
  if not held then
    return nil
  end
  local exact = held.exact == true
  if exact and not self:HarvestShown() then
    for _, sourceId in ipairs(held.ids) do
      if self:IsHarvested(sourceId) then
        exact = false
        break
      end
    end
  end
  local byId = setmetatable({}, {
    __index = function(_, sourceId)
      local pos = type(sourceId) == "number" and positionIn(held.ids, sourceId) or nil
      if not pos then
        return nil
      end
      return shippedFacts(self, held, pos)
    end,
  })
  return { byId = byId, exact = exact }
end

-- Every item id the Index knows, sorted. Built once and then reused; Reset drops it.
function Data:ItemIds()
  if self.itemIds then
    return self.itemIds
  end
  local index = self:Get("Index")
  if not index then
    return {}
  end
  local ids = {}
  local dev = self:DevSet()
  for itemId in pairs(index) do
    if not self:HarvestMasked(itemId) and not dev[itemId] then
      ids[#ids + 1] = itemId
    end
  end
  table.sort(ids)
  self.itemIds = ids
  return ids
end

-- One id out of a list. rng takes a count and returns an integer in 1..count, defaulting to
-- math.random, so a test can pass a fixed picker and get the same answer every time. An rng
-- that answers out of range is pulled back inside rather than trusted.
local function pickFrom(ids, rng)
  local count = #ids
  if count == 0 then
    return nil
  end
  local picker = rng or math.random
  local pick = math.floor(tonumber(picker(count)) or 1)
  if pick < 1 then
    pick = 1
  end
  if pick > count then
    pick = count
  end
  return ids[pick]
end

-- One item id at random, out of every item the Index knows. nil when no Index module is loaded.
function Data:RandomItemId(rng)
  return pickFrom(self:ItemIds(), rng)
end

-- Items worth opening at random: linked is every item with at least one edge in either
-- direction, and featured is the ones of those this build calls New or Changed.
--
-- Brief P4: the pipeline works both out and ships them in the RandomPool module (ItemTree-Data
-- item_lists.py build_random_pool, the rule this function used to run over every item: an item
-- is linked when Uses lists it, the Disenchant module names it a material, or its row states a
-- starting quest, a set, keys or a totem category, or a disenchant band covers it; featured is
-- the linked ones in Diff's new bucket or its changed set), so the random item button never
-- builds an Items table. tests/spec/item_lists_spec.lua holds the two to it over the real data.
--
-- Only what a setting changes is left to run time: a harvested item the setting hides is a stub
-- again, and a stub was never in the pool; and an item Diff's dev set flags (brief DV1) is never
-- offered. A pool nothing is dropped from is the module's own list, so the usual case copies
-- nothing. Built once; Reset and ResetHarvest drop it.
local function poolShown(self, list, dev)
  if type(list) ~= "table" then
    return {}
  end
  local kept = nil
  for index, itemId in ipairs(list) do
    local drop = dev[itemId] ~= nil or self:HarvestMasked(itemId)
    if drop and not kept then
      kept = {}
      for before = 1, index - 1 do
        kept[before] = list[before]
      end
    elseif not drop and kept then
      kept[#kept + 1] = itemId
    end
  end
  return kept or list
end

function Data:RandomIndex()
  if self.randomIndex then
    return self.randomIndex
  end
  local pool = self:Get("RandomPool")
  if type(pool) ~= "table" then
    self.randomIndex = { linked = {}, featured = {} }
    return self.randomIndex
  end
  local dev = self:DevSet()
  self.randomIndex = { linked = poolShown(self, pool.linked, dev), featured = poolShown(self, pool.featured, dev) }
  return self.randomIndex
end

-- The item that starts a quest, or nil: the lowest id among the items whose row states the quest
-- as the one it starts (item.sq), leaving out a developer item and a harvested one the setting
-- hides, which is Data:ItemIds's rule. Brief P4: the pipeline ships each quest's starting items
-- in the QuestStarts module (ItemTree-Data item_lists.py build_quest_starts), so Core/Quests.lua
-- no longer walks every item for them. Kept per quest in Data.questStarts (false for none).
function Data:QuestStartItem(questId)
  if type(questId) ~= "number" then
    return nil
  end
  self.questStarts = self.questStarts or {}
  local held = self.questStarts[questId]
  if held ~= nil then
    return held or nil
  end
  local starts = self:Get("QuestStarts")
  local list = type(starts) == "table" and starts[questId] or nil
  held = false
  if type(list) == "table" then
    local dev = self:DevSet()
    for _, itemId in ipairs(list) do
      if dev[itemId] == nil and not self:HarvestMasked(itemId) then
        held = itemId
        break
      end
    end
  end
  self.questStarts[questId] = held
  return held or nil
end

-- One item id at random out of the items that have something to show: what this build changed
-- or added first, because that is what the window is for, and anything linked otherwise. Falls
-- back to any item at all where the data links nothing. randomFn takes a count and returns an
-- integer in 1..count, defaulting to math.random.
function Data:RandomItem(randomFn)
  local index = self:RandomIndex()
  local pool = index.linked
  if #index.featured > 0 then
    pool = index.featured
  end
  if #pool == 0 then
    return self:RandomItemId(randomFn)
  end
  return pickFrom(pool, randomFn)
end

-- Every item this build calls New in Forever, sorted by id. The band's dice button picks out of
-- this and nothing else; Reset drops it.
--
-- New is the New medallion's own rule, Core/Diff.lua's: the diff's `new` bucket, which is what
-- this build added, the `discovered` bucket beside it, which is what the baseline listed and
-- would not name and this build does, and the `newUndiscovered` bucket beside that, which is what
-- this build added and will not describe yet. All three are plain arrays of ids in the same diff
-- table, so a pick and its medallion can never disagree. Changed is not in it: a changed item is
-- an old item with a new number on it, and the button says new.
--
-- Unlike Data:RandomIndex the pool does not ask whether an item has an edge. A new item with
-- nothing pointing at it yet is exactly the kind of thing the button is for, and the window has
-- its own empty state to say so; requiring an edge would quietly drop 1,470 of build
-- 1.60.1.69913's 4,900 new items.
--
-- Withheld items ARE in it now, and the only ones that are is the whole point (brief E41). An id
-- with no ItemSparse row is in neither build's named tables, so the comparison of those tables
-- cannot reach it: of build 1.60.1.69913's 12,504 withheld ids, 10,169 land in `hidden` (the
-- baseline named them, this build does not, so they are emphatically not new) and the other 2,335
-- land in none of the name based buckets at all.
--
-- "No bucket" was never the same question as "new", and those 2,335 split two ways: 1,815 have no
-- `Item` row in the Classic Era baseline whatsoever, so they are genuinely new in Forever, and 520
-- are ids the baseline also had and also withheld, so nothing can say they are new. The pipeline
-- now ships the one fact that tells them apart, as `items.newUndiscovered`: the ids of the first
-- group that also got a stub, which are the only withheld ids with a class, a slot and an icon to
-- put in front of a player. 229 of the 2,599 stubs in 1.60.1.69913 qualify, and the 9 withheld
-- stubs the baseline also listed stay out. See ItemTree-Data docs/undiscovered-items.md.
--
-- Each bucket is checked against the table that has to be able to show the id, which is what
-- keeps the button honest: a named id must be in `Index`, and a withheld one must have a stub in
-- `Undiscovered`. An id in neither has no name, no class and no icon to offer a player who pressed
-- a button asking for an item, so it is dropped however the diff files it.
function Data:NewInForeverIds()
  if self.newInForever then
    return self.newInForever
  end
  local ids = {}
  self.newInForever = ids
  local index = self:Get("Index")
  if not index then
    return ids
  end
  local diff = self:GetDiff()
  local diffItems = diff and diff.items or nil
  -- The discovered bucket is not read: the pipeline files every discovered id the baseline could
  -- not name in the new bucket as well, and one in discovered alone is a Classic item the realm
  -- found, harvested or found by the client's pushed records (Core/Diff.lua IsNew).
  local buckets = {
    { name = "new", shown = index },
    { name = "newUndiscovered", shown = self:Get("Undiscovered") or EMPTY },
  }
  -- Brief DV1: an item no player can get is never offered.
  local dev = self:DevSet()
  local seen = {}
  for _, bucket in ipairs(buckets) do
    for _, itemId in ipairs((diffItems and diffItems[bucket.name]) or EMPTY) do
      if not seen[itemId] and dev[itemId] == nil and bucket.shown[itemId] ~= nil then
        seen[itemId] = true
        ids[#ids + 1] = itemId
      end
    end
  end
  table.sort(ids)
  return ids
end

-- One New in Forever item id, uniformly at random, or nil where this build added nothing.
--
-- rng takes a count and returns an integer in 1..count, defaulting to math.random, so a spec can
-- fix the pick. avoid is an id, or an array of them, that this pick must not land on: the window
-- passes the item it is already showing and the one the last press opened, so a press always
-- moves and never repeats. Avoiding is done by counting the pool's avoided entries and picking
-- out of what is left, rather than picking again until the answer is allowed, so the pick stays
-- exactly uniform however many ids are held back. A pool with nothing left to offer ignores
-- avoid rather than answering nothing: one item to show is better than none.
function Data:RandomNewItem(rng, avoid)
  local pool = self:NewInForeverIds()
  if #pool == 0 then
    return nil
  end
  local skip = {}
  if type(avoid) == "number" then
    skip[avoid] = true
  elseif type(avoid) == "table" then
    for _, itemId in ipairs(avoid) do
      if type(itemId) == "number" then
        skip[itemId] = true
      end
    end
  end
  local allowed = 0
  for _, itemId in ipairs(pool) do
    if not skip[itemId] then
      allowed = allowed + 1
    end
  end
  if allowed == 0 then
    return pickFrom(pool, rng)
  end
  local picker = rng or math.random
  local wanted = math.floor(tonumber(picker(allowed)) or 1)
  if wanted < 1 then
    wanted = 1
  end
  if wanted > allowed then
    wanted = allowed
  end
  local at = 0
  for _, itemId in ipairs(pool) do
    if not skip[itemId] then
      at = at + 1
      if at == wanted then
        return itemId
      end
    end
  end
  return nil
end

-- Counts for the debug command. A built module has let go of its loader (Data:Get), so the
-- module list is the registered ones and the built ones together.
function Data:Stats()
  local names, seen = {}, {}
  for _, held in ipairs({ self.modules, self.cache }) do
    for name in pairs(held) do
      if not seen[name] then
        seen[name] = true
        names[#names + 1] = name
      end
    end
  end
  table.sort(names)
  local loaded = 0
  for _ in pairs(self.cache) do
    loaded = loaded + 1
  end
  return {
    modules = names,
    loaded = loaded,
    build = self.Meta and self.Meta.build or nil,
    baseline = self.Meta and self.Meta.baseline or nil,
    counts = self.Meta and self.Meta.counts or {},
  }
end

-- Brief D2: what a failed load of ItemTree_Data says, by the reason the client's LoadAddOn gave.
-- A reason the client gives that is not here is shown as it came, with no hint after it.
local HINT_OUT_OF_DATE =
  L["The game says ItemTree Data is out of date: tick Load out of date AddOns in the AddOns list."]
local HINT_MISSING =
  L["The ItemTree_Data folder is not in your AddOns folder: reinstall ItemTree, both folders ship in the one zip."]
Data.ON_DEMAND_HINTS = {
  MISSING = HINT_MISSING,
  DISABLED = L["ItemTree Data is unticked in the AddOns list: tick it and reload."],
  INTERFACE_VERSION = HINT_OUT_OF_DATE,
  INCOMPATIBLE = HINT_OUT_OF_DATE,
}

-- The reason in brackets and the hint for it, as one line: "(MISSING) The ItemTree_Data folder
-- ...". nil for no reason at all. Pure.
function Data.OnDemandFailedDetail(reason)
  if reason == nil or reason == "" then
    return nil
  end
  reason = tostring(reason)
  local hint = Data.ON_DEMAND_HINTS[reason]
  if hint then
    return "(" .. reason .. ") " .. hint
  end
  return "(" .. reason .. ")"
end

-- The one chat line a failed load prints: the long line, the reason and its hint, and where to
-- read more. Pure.
function Data.OnDemandFailedMessage(reason)
  local parts = { Data.ON_DEMAND_FAILED_LINE }
  local detail = Data.OnDemandFailedDetail(reason)
  if detail then
    parts[#parts + 1] = detail
  end
  parts[#parts + 1] = L["Type /itemtree debug for details."]
  return table.concat(parts, " ")
end

-- Brief PF2: the modules an item page builds are built ahead of the first open, one per frame, by
-- the login slicer (client side, below). The order is smallest first, by the table each holds once
-- built and its build time over the shipped 1.60.1.70170 data (measured 2026-10-05, the PF1 open
-- probe's "module ... built" lines over Linen Cloth, Copper Bar, Strange Dust and a weapon): the
-- modules every one of those pages built, the common Items_<class> tables (consumables, weapons,
-- armour, trade goods, recipes), Names for the search box, and EraSources last. Every one of them
-- is what any session that opens a few items holds anyway, so the slicer only moves when they are
-- built, never how much is held. Another Items_<class> table is added only for a class the
-- player's bags hold (Data.BagModules).
Data.PRELOAD_ORDER = {
  "TotemCategories",
  "ToolItems",
  "UndiscoveredIds",
  "GuessSources",
  "Classes",
  "Disenchant",
  "Skills",
  "Items_7",
  "DiffChanges",
  "Items_9",
  "Items_0",
  "Items_2",
  "QuestStarts",
  "RecipeIndex",
  "Items_4",
  "ForeverVendors",
  "PlayerSources",
  "Index",
  "Names",
  "Diff",
  "Undiscovered",
  "Uses",
  "Creatures",
  -- Brief PF3: the boss loot join (about 10 ms over the shipped 1.60.1.70334 data, the dearest
  -- module there is), which the first creature the player mouses over asked for (UI/CollectorHooks
  -- NoteSeenBoss). The slicer carries the join over frames (Data.SliceCheck).
  "BossLoot",
  "EraSources",
}

-- After the modules, the session indexes the first item page builds over them, each built once and
-- kept by its owner whoever asks first: the Classic Era quest, trainer and required by indexes and
-- the player sourced reverse index. The PF1 probe in the fake client put most of a cold open's
-- graph time in these after the modules were built (Linen Cloth: graph 78 ms cold, 10 ms warm).
-- Each is { owner = the ItemTree field holding it, fn = its name, method = called with the owner as
-- self }. One that is not there (a build without it) is skipped.
Data.PRELOAD_WARM = {
  { owner = "PlayerSources", fn = "Reverse" },
  -- Brief RB4: three more one-time builds the owner's 70425 hitch runs (QA items 198 and 201) met
  -- inside a first open: the player sources quest index, the Classic Era name map (the Ctrl click's
  -- lookup) and the Classic Era quest givers index (a trainer's predicted quests, a quest page). All
  -- three are built behind the loading screen too (Data.PRELOAD_LOADING_SCREEN), so here they are a
  -- lookup each, kept as the fallback.
  { owner = "PlayerSources", fn = "WarmQuestIndex" },
  { owner = "eraSources", fn = "_NameMap", method = true },
  { owner = "ViewModel", fn = "EraQuestNpcIndex" },
  { owner = "eraSources", fn = "_TrainerIndex", method = true },
  { owner = "eraSources", fn = "_RequiredByIndex", method = true },
  { owner = "eraSources", fn = "_QuestIndex", method = true },
  -- Brief PF3b: the two indexes the first NPC page builds whole (ViewModel.ViewsFor asks
  -- E:VendorKind and E:HasLoot of every npc root): the vendor index about 30 ms and the loot index
  -- about 80 ms over the shipped 1.60.1.70334 data offline, which was the owner's 241 ms frame on
  -- his first Ctrl click on a creature. Both are carried over frames (Data.SliceCheck). Brief PF8:
  -- both are built whole behind the loading screen now (Data.PRELOAD_LOADING_SCREEN), so here they
  -- are a lookup each; kept as the fallback where that build raised or the data was reset since.
  { owner = "eraSources", fn = "_VendorIndex", method = true },
  { owner = "eraSources", fn = "_LootIndex", method = true },
  -- Brief CT1b (QA item 227): the creature id to name map every first NPC page built (about 1 ms
  -- offline) and the class trainers' learn levels and ranks (tf, about 0.5 ms), both built behind
  -- the loading screen too (Data.PRELOAD_LOADING_SCREEN), so here they are a lookup each.
  { owner = "eraSources", fn = "PageNameMap", method = true },
  { owner = "eraSources", fn = "ClassSpellFacts", method = true },
  -- Brief RP-AH2 (FR-AH M3): the class books' name index (Core/Keep.lua Keep.WarmClassBookIndex), built
  -- behind the loading screen too (Data.PRELOAD_LOADING_SCREEN), so here it is a lookup.
  { owner = "Keep", fn = "WarmClassBookIndex" },
  -- Brief RB4 (QA item 198): the quest facts index the quest page's info column reads
  -- (E:_QuestFactIndex), one pass over every row: 50 to 110 ms over the shipped 1.60.1.70425 data
  -- offline, the owner's 87 ms info panel on his first predicted quest page (Coming of Age, 92460).
  -- Carried over frames (Data.SliceCheck), so a quest page opened from a second or so after the
  -- slicer starts finds it built. Not behind the loading screen: it alone would add a third again
  -- to that build, and a quest page is reached from another page, never by the first Ctrl click.
  { owner = "eraSources", fn = "_QuestFactIndex", method = true },
}

-- Brief PF8: the warm entries built whole on the session's first PLAYER_ENTERING_WORLD (a login or
-- a reload), which runs before the world is drawn (brief PF5), so the player sees a longer loading
-- screen rather than a frozen frame: the owner's Ctrl click on a creature 2 seconds after entering
-- the world built the loot index in that click's frame (433 ms of a 494 ms open on his PC), since
-- the slicer starts 3 seconds after PLAYER_ENTERING_WORLD and reaches these last. Over the shipped
-- 1.60.1.70374 data offline the vendor index costs about 26 ms and the loot index about 77 ms.
-- Same shape as Data.PRELOAD_WARM (Data:PreloadLoadingScreen).
--
-- Brief RB4 (QA items 198 and 201): the rest of what a first creature or item page builds, the same
-- rule: the owner's first Ctrl click on 5116 paid the Classic Era name map ("lookup 8.6 ms") and his
-- first trainer page the quest givers index ("tree 14 ms"), and an open in the seconds before the
-- slicer reaches them builds the boss loot join, the Era quest index, the player sources indexes and
-- the Era trainer and required by indexes whole (Olmin Burningbeard 5116 50 to 80 ms offline, Gilded
-- Gloves 254095 20 to 40 ms). Over the shipped 1.60.1.70425 data offline the whole list takes about
-- half as long again as the two indexes above did (best of five sessions: 115 to 155 ms before, 170
-- to 270 ms after, by the machine's load; the Era passes share one sort of the table's item ids now,
-- EraSources sortedItemIds). A module's name builds it the way Data:Get does.
Data.PRELOAD_LOADING_SCREEN = {
  { owner = "eraSources", fn = "_VendorIndex", method = true },
  { owner = "eraSources", fn = "_LootIndex", method = true },
  "BossLoot",
  { owner = "eraSources", fn = "_NameMap", method = true },
  { owner = "eraSources", fn = "_QuestIndex", method = true },
  { owner = "eraSources", fn = "_TrainerIndex", method = true },
  { owner = "eraSources", fn = "_RequiredByIndex", method = true },
  { owner = "PlayerSources", fn = "Reverse" },
  { owner = "PlayerSources", fn = "WarmQuestIndex" },
  { owner = "ViewModel", fn = "EraQuestNpcIndex" },
  -- Brief CT1b (QA item 227): the creature id to name map and the class trainers' tf, which the first
  -- NPC page and the first class trainer page built (about 1.6 ms of the owner's Olmin Burningbeard
  -- offline).
  { owner = "eraSources", fn = "PageNameMap", method = true },
  { owner = "eraSources", fn = "ClassSpellFacts", method = true },
  -- Brief RP-AH2 (FR-AH M3): the class books' name index (Keep.WarmClassBookIndex, one pass over the
  -- Names module, which it builds where nothing has yet: about 1.5 ms and 0.7 ms over the shipped
  -- 1.60.1.70450 data offline), which the first bag paint or hover that scored a book of the player's
  -- class built in its frame.
  { owner = "Keep", fn = "WarmClassBookIndex" },
}

-- Brief PF3: the warm entry added with the bag classes once the plan is done: the Keep score of
-- every item in the bags, scored exactly as the bag marks score it (UI/Overlay.lua WarmScores), so
-- the first time the player opens the bags draws from the scores (about 14 ms over 80 slots
-- before, 1.2 ms after, offline). An owner may be a dotted path under ItemTree.
Data.PRELOAD_BAG_WARM = {
  { owner = "UI.Overlay", fn = "WarmScores" },
}

-- A warm entry's key in the plan and the debug counts: "eraSources:_QuestIndex". Pure.
function Data.WarmKey(entry)
  return tostring(entry.owner) .. ":" .. tostring(entry.fn)
end

-- The table a dotted owner path names under ItemTree ("UI.Overlay"), or nil.
local function ownerAt(path)
  local at = ItemTree
  for part in tostring(path):gmatch("[^%.]+") do
    if type(at) ~= "table" then
      return nil
    end
    at = rawget(at, part)
  end
  return at
end

-- The function a warm entry names, and the self it is called with, or nil where it is not there.
local function warmTarget(entry)
  local owner = ownerAt(entry.owner)
  if type(owner) ~= "table" then
    return nil
  end
  local fn = owner[entry.fn]
  if type(fn) ~= "function" then
    return nil
  end
  return fn, owner
end

-- The Items_<class> modules the item ids given fall in, by the Index module's class per id, each
-- once and sorted by name. An id the Index does not know adds nothing. Pure.
function Data.BagModules(ids, index)
  local out, seen = {}, {}
  if type(ids) ~= "table" or type(index) ~= "table" then
    return out
  end
  for _, id in ipairs(ids) do
    local class = index[id]
    if class ~= nil then
      local name = "Items_" .. tostring(class)
      if not seen[name] then
        seen[name] = true
        out[#out + 1] = name
      end
    end
  end
  table.sort(out)
  return out
end

-- Adds the names to the slicer's plan, in order: only a module that is registered or already built,
-- never one only the unloaded ItemTree_Data would register (the slicer must never be what loads
-- it), and never a name twice. A warm entry is added only once ItemTree_Data is loaded, since the
-- indexes read its modules. Answers how many were added.
function Data:PreloadAdd(names)
  local run = self.preload
  if type(run) ~= "table" or type(names) ~= "table" then
    return 0
  end
  local added = 0
  for _, name in ipairs(names) do
    if type(name) == "string" and not run.has[name] and (self.cache[name] ~= nil or self.modules[name] ~= nil) then
      run.has[name] = true
      run.plan[#run.plan + 1] = name
      added = added + 1
    elseif type(name) == "table" and warmTarget(name) and not run.has[Data.WarmKey(name)] and self:OnDemandLoaded() then
      run.has[Data.WarmKey(name)] = true
      run.plan[#run.plan + 1] = name
      added = added + 1
    end
  end
  return added
end

-- Starts the slicer's plan over names (Data.PRELOAD_ORDER then Data.PRELOAD_WARM when nil).
-- Answers the plan's size.
function Data:PreloadStart(names)
  self.preload = { plan = {}, has = {}, warmed = {}, at = 1, built = 0 }
  if names then
    self:PreloadAdd(names)
  else
    self:PreloadAdd(Data.PRELOAD_ORDER)
    self:PreloadAdd(Data.PRELOAD_WARM)
  end
  return #self.preload.plan
end

-- One whole step: builds the next module of the plan that is not built yet, through Data:Get (so a
-- module the first open already built is skipped, never built twice), or calls the next warm
-- entry once (its owner keeps what it builds, and a second ask is a lookup), and answers the
-- module's name or the entry's key. nil once the plan is done, or with no plan. Brief PF3: the
-- client's slicer works through Data:PreloadSlice under a budget; this unbudgeted step is kept for
-- a caller that wants the next item done at once.
function Data:PreloadStep()
  local run = self.preload
  if type(run) ~= "table" then
    return nil
  end
  while run.at <= #run.plan do
    local item = run.plan[run.at]
    run.at = run.at + 1
    if type(item) == "table" then
      local key = Data.WarmKey(item)
      local fn, owner = warmTarget(item)
      if fn and not run.warmed[key] and self:OnDemandLoaded() then
        run.warmed[key] = true
        if item.method then
          pcall(fn, owner)
        else
          pcall(fn)
        end
        run.built = run.built + 1
        return key
      end
    elseif self.cache[item] == nil and self.modules[item] ~= nil then
      self:Get(item)
      run.built = run.built + 1
      return item
    end
  end
  return nil
end

-- How many of the plan's modules are built now (by the slicer or by an open before it got there),
-- and the plan's size. 0, 0 with no plan.
function Data:PreloadCounts()
  local run = self.preload
  if type(run) ~= "table" then
    return 0, 0
  end
  local done = 0
  for _, item in ipairs(run.plan) do
    if type(item) == "table" then
      if run.warmed[Data.WarmKey(item)] then
        done = done + 1
      end
    elseif self.cache[item] ~= nil then
      done = done + 1
    end
  end
  return done, #run.plan
end

-- Brief PF3: the slicer under a budget. PF2 built one whole plan item per frame and only while the
-- player stood still out of combat, so a player who logged in and ran never got it, and the first
-- hover, bag open or creature mouseover built what it needed whole, mid run. Measured over the
-- shipped 1.60.1.70334 data offline (out-pf3/REPORT.md): every module of the plan builds in under
-- 1.6 ms but for the BossLoot join (about 10 ms), and the warm Era quest index costs about 20 ms
-- and the trainer index about 5 ms, each in one frame. So a tick now spends at most
-- Data.PRELOAD_BUDGET_MS, several small items in one frame, and the long ones carry over frames:
-- each plan item runs in a coroutine of the slicer's own, and the long loops (the boss loot join,
-- the Era quest and trainer indexes, the bag scores) call Data.SliceCheck, which yields once the
-- tick's budget is spent. A frame is 16.7 ms at 60 fps; 4 ms leaves the client most of it. With the
-- budget guarding the frame, the slicer runs while the player moves; never in combat.
--
-- Data.SliceCheck is a nil check outside the slicer (every lazy caller, which builds whole and at
-- once, exactly as before), and it never yields across a pcall: it is only called from loops that
-- the slicer's coroutine reaches with no pcall between.
Data.PRELOAD_BUDGET_MS = 4
-- Data.SliceCheck reads the clock once every this many calls, so a long loop pays a counter. A loop
-- whose every turn is dear (a Keep score) passes 1.
Data.SLICE_EVERY = 16
-- A tick starts a new module only while at least this share of its budget is left: a module's
-- loader is one table constructor that cannot be cut (1.6 ms at most over the shipped data), so a
-- tick ends at most that much past its first half rather than past its whole budget. A warm entry
-- starts only at the start of a tick: the ones not cut (PlayerSources.Reverse, the Era required by
-- index, about 3.4 ms each) then have the whole budget to themselves.
Data.PRELOAD_START_SHARE = 0.5

local sliceDeadline, sliceCount = nil, 0

function Data.SliceCheck(every)
  if sliceDeadline == nil then
    return false
  end
  sliceCount = sliceCount + 1
  if sliceCount < (every or Data.SLICE_EVERY) then
    return false
  end
  sliceCount = 0
  if Data.SliceClock() < sliceDeadline then
    return false
  end
  coroutine.yield()
  return true
end

local function sliceEveryTurn()
  return Data.SliceCheck(1)
end

-- One module built the way Data:Get builds it, with Data.SliceCheck reachable in its join, for the
-- slicer's coroutine. Nothing is written until the table is whole: a lazy Data:Get of the same
-- module (or its other half) between two slices builds its own as it always did, and then this
-- one is dropped, so the cache only ever holds one table per module. Answers the table, or nil
-- where nothing was kept (built already, gone, or the data reset meanwhile).
function Data:BuildSliced(name)
  if self.cache[name] ~= nil then
    return nil
  end
  local loader = self.modules[name]
  if not loader then
    return nil
  end
  local generation = self.generation
  local built = loader()
  local join = Data.JOINS[name]
  local partner, partnerLoader, partnerSeen = nil, nil, false
  if join and built ~= nil then
    partner = join.partner
    local other = self.cache[partner]
    if other == nil then
      partnerLoader = self.modules[partner]
      if partnerLoader then
        other = partnerLoader()
      end
    end
    partnerSeen = other ~= nil
    if type(other) == "table" then
      -- A boss entry's join can be dear (a sort of its records), so the clock is read every entry.
      built = join.join(built, other, sliceEveryTurn)
    end
  end
  -- From here to the end nothing yields.
  if self.cache[name] ~= nil or self.generation ~= generation or self.modules[name] ~= loader then
    return nil
  end
  if partnerSeen then
    if partnerLoader and not self.keepLoaders and self.modules[partner] == partnerLoader then
      self.modules[partner] = nil
      self.dropped = self.dropped or {}
      self.dropped[partner] = true
    end
    self.cache[partner] = false
  end
  self.cache[name] = built
  if built ~= nil and not self.keepLoaders then
    self.modules[name] = nil
    self.dropped = self.dropped or {}
    self.dropped[name] = true
  end
  return built
end

-- The next plan item still to do, the plan's cursor moved past it, or nil once the plan is done.
-- The same rules as Data:PreloadStep: a module built already (an open got there first) and a warm
-- entry called already or not there are passed over.
local function nextPlanItem(self, run)
  while run.at <= #run.plan do
    local item = run.plan[run.at]
    run.at = run.at + 1
    if type(item) == "table" then
      if warmTarget(item) and not run.warmed[Data.WarmKey(item)] and self:OnDemandLoaded() then
        return item
      end
    elseif self.cache[item] == nil and self.modules[item] ~= nil then
      return item
    end
  end
  return nil
end

-- What one plan item's coroutine runs. A warm entry is called straight, with no pcall between it
-- and its Data.SliceCheck calls; an error ends the coroutine and the slicer goes on.
local function runPlanItem(self, item)
  if type(item) == "table" then
    local fn, owner = warmTarget(item)
    if fn then
      if item.method then
        fn(owner)
      else
        fn()
      end
    end
    return
  end
  self:BuildSliced(item)
end

local function planLabel(item)
  if type(item) == "table" then
    return Data.WarmKey(item)
  end
  return item
end

-- One tick of the slicer: plan items for at most budget ms (Data.PRELOAD_BUDGET_MS by default), a
-- long one carried on from where the last tick left it. When the plan runs out the first time,
-- the Items_<class> modules of the classes the bags hold and Data.PRELOAD_BAG_WARM join it (the
-- Index is built by then). Answers the label of the last item worked on, or nil once there is
-- nothing left. A module whose build raises ends the coroutine and raises here (the caller stops
-- the slicer, as PF2 did); a warm entry that raises is passed over.
function Data:PreloadSlice(budget)
  local run = self.preload
  if type(run) ~= "table" then
    return nil
  end
  budget = tonumber(budget) or Data.PRELOAD_BUDGET_MS
  local deadline = Data.SliceClock() + budget
  local startBy = deadline - budget * Data.PRELOAD_START_SHARE
  local label = nil
  while true do
    if not run.co then
      if label ~= nil and Data.SliceClock() >= startBy then
        return label
      end
      local at = run.at
      local item = nextPlanItem(self, run)
      if label ~= nil and type(item) == "table" then
        -- Not this tick: the cursor goes back so the next tick starts with it.
        run.at = at
        return label
      end
      if item == nil and not run.bags then
        run.bags = true
        local index = self.cache.Index
        if index ~= nil then
          self:PreloadAdd(Data.BagModules(Data.BagItemIds(), index))
          self:PreloadAdd(Data.PRELOAD_BAG_WARM)
          item = nextPlanItem(self, run)
        end
      end
      if item == nil then
        return label
      end
      local data = self
      run.co = coroutine.create(function()
        runPlanItem(data, item)
      end)
      run.coItem = item
    end
    local item = run.coItem
    label = planLabel(item)
    sliceDeadline, sliceCount = deadline, 0
    local ok, err = coroutine.resume(run.co)
    sliceDeadline = nil
    if coroutine.status(run.co) == "dead" then
      run.co, run.coItem = nil, nil
      if type(item) == "table" then
        run.warmed[Data.WarmKey(item)] = true
      end
      run.built = run.built + 1
      if not ok and type(item) ~= "table" then
        error(err, 0)
      end
    end
    if Data.SliceClock() >= deadline then
      return label
    end
  end
end

-- Brief IT2: the quests after whose completion an item has no use left, from the StaleAfter
-- module (ItemTree_Data, brief IT3-data): { [itemId] = { q = { questId, ... }, k = 1 | 2 } }, k 1 a
-- predicted claim and 2 one the owner verified. Answers a new list of the positive whole quest ids
-- the row names, in its order, and the kind (2 only where the row says 2, else 1), or nil where
-- the module is not there or names no quest for the item. Guarded: a module that is neither
-- registered nor built is never asked for, so reading it never loads anything.
Data.STALE_AFTER_MODULE = "StaleAfter"

function Data:StaleAfter(itemId)
  if type(itemId) ~= "number" or not self:Has(Data.STALE_AFTER_MODULE) then
    return nil
  end
  local ok, module = pcall(self.Get, self, Data.STALE_AFTER_MODULE)
  local row = ok and type(module) == "table" and module[itemId] or nil
  if type(row) ~= "table" or type(row.q) ~= "table" then
    return nil
  end
  local quests, seen = {}, {}
  for _, questId in ipairs(row.q) do
    if type(questId) == "number" and questId > 0 and questId == math.floor(questId) and not seen[questId] then
      seen[questId] = true
      quests[#quests + 1] = questId
    end
  end
  if #quests == 0 then
    return nil
  end
  local kind = 1
  if row.k == 2 then
    kind = 2
  end
  return quests, kind
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

-- The folder name of the load on demand addon, which is what the client's LoadAddOn takes.
Data.ON_DEMAND_ADDON = "ItemTree_Data"

-- The long line a failed load starts with. The chat line (Data.OnDemandFailedMessage) adds the
-- reason, and the window's empty state draws it over the reason (UI/Frame.lua).
Data.ON_DEMAND_FAILED_LINE =
  L["ItemTree's item data did not load. Install the ItemTree_Data folder beside ItemTree and enable it."]

-- Data.onDemandFailed is why the load of ItemTree_Data failed, nil while it has not. /itemtree
-- report prints it. The load is tried once per session: a failure is final until /reload.

-- The client's loader for an addon by folder name: C_AddOns.LoadAddOn on the Forever client, the
-- global LoadAddOn on an older one. Each answers loaded, reason.
local function loaders()
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

-- The chat line, once per session, through the client's DEFAULT_CHAT_FRAME. Nothing while the
-- load has not failed, and nothing a second time however the failure is met again.
local function warnOnce(self)
  if self.onDemandWarned or not self.onDemandFailed then
    return false
  end
  self.onDemandWarned = true
  local chat = rawget(_G, "DEFAULT_CHAT_FRAME")
  if type(chat) ~= "table" or type(chat.AddMessage) ~= "function" then
    return false
  end
  return (pcall(chat.AddMessage, chat, Data.OnDemandFailedMessage(self.onDemandFailed)))
end

-- Brief D2: the same once per session line for a caller that met the failure without asking for
-- the load itself (the minimap click, the key binding). Answers whether a line went out now.
function Data:WarnOnDemandFailed()
  return warnOnce(self)
end

-- Brief PF4: the client's millisecond clock (debugprofilestop), nil where there is none.
local function profileMs()
  local profile = rawget(_G, "debugprofilestop")
  if type(profile) ~= "function" then
    return nil
  end
  local ok, ms = pcall(profile)
  if ok and type(ms) == "number" then
    return ms
  end
  return nil
end

-- Brief PF4: Data.loadTiming is how long the client's LoadAddOn of ItemTree_Data took, written
-- once: { ms = milliseconds or nil where the client has no clock, at = "login" |
-- "entering world" | "first open", ok = whether it loaded }. In memory only, for /itprobe show.
-- Brief PF5: and module, who asked: the module Data:Get wanted ("Items_0") or the name of the
-- other path that asked ("ItemTreeAPI.RequestData"), nil where the caller named none; and world,
-- whether the session's first PLAYER_ENTERING_WORLD had been handled (ItemTree.state.enteredWorld):
-- false is a load behind the loading screen, true one the player saw as a hitch. Brief PF8: and
-- indexesMs, added later by Data:PreloadLoadingScreen: how long the loot and vendor indexes took
-- behind the loading screen (nil where they were not built there).
local function recordLoadTiming(self, from, at, ok, module)
  if self.loadTiming ~= nil then
    return
  end
  local now = from and profileMs()
  local state = ItemTree.state
  self.loadTiming = {
    ms = now and (now - from) or nil,
    at = at or "first open",
    ok = ok,
    module = module,
    world = type(state) == "table" and state.enteredWorld == true,
  }
end

-- Loads ItemTree_Data, once. True when every module it holds is registered afterwards (or was
-- already), false when it could not be loaded: the folder is missing, the addon is disabled, the
-- client refused it or has no loader. The reason is kept in Data.onDemandFailed and the chat line
-- is printed. Tried at most once per session, so a missing folder costs one call and one line.
-- at and module are who asked, for Data.loadTiming (briefs PF4 and PF5).
local function loadOnDemandOnce(self, at, module)
  local reason = "no LoadAddOn on this client"
  for _, load in ipairs(loaders()) do
    local from = profileMs()
    local ok, loaded, why = pcall(load, Data.ON_DEMAND_ADDON)
    if ok then
      -- The client answered; a loader that raised leaves the next one to be timed.
      recordLoadTiming(self, from, at, loaded and true or false, module)
    end
    if ok and loaded then
      if self:OnDemandLoaded() then
        self.onDemandLoadedAt = "load"
        return true
      end
      reason = "loaded, but its modules did not register"
      break
    end
    if ok then
      -- The client answered and said no; the older loader is the same call and would say it again.
      reason = type(why) == "string" and why ~= "" and why or "not loaded"
      break
    end
    reason = "error: " .. tostring(loaded)
  end
  recordLoadTiming(self, nil, at, false, module)
  self.onDemandFailed = reason
  warnOnce(self)
  return false
end

-- at (brief PF4) names who asked for Data.loadTiming: "login" (ItemTree.OnLogin), "entering
-- world" (ItemTree.OnEnteringWorld); nil is "first open", a later first Data:Get or any other caller.
-- module (brief PF5) names that caller: the module Data:Get wanted, or the path's own name.
function Data:LoadOnDemand(at, module)
  if self:OnDemandLoaded() then
    return true
  end
  if self.onDemandFailed then
    return false
  end
  -- Brief PF1: the client's load of ItemTree_Data, timed while /itprobe open traces an open.
  local trace = ItemTree.openTrace
  if trace then
    return trace.Span("data", nil, loadOnDemandOnce, self, at, module)
  end
  return loadOnDemandOnce(self, at, module)
end

-- Whether the client says ItemTree_Data is loaded, or nil where it cannot say.
function Data:OnDemandAddonLoaded()
  local addOns = rawget(_G, "C_AddOns")
  local check = type(addOns) == "table" and addOns.IsAddOnLoaded or rawget(_G, "IsAddOnLoaded")
  if type(check) ~= "function" then
    return nil
  end
  local ok, loaded = pcall(check, Data.ON_DEMAND_ADDON)
  if not ok then
    return nil
  end
  return loaded and true or false
end

-- Brief PF8: builds every Data.PRELOAD_LOADING_SCREEN entry whole, now, for ItemTree.OnEnteringWorld
-- on the session's first PLAYER_ENTERING_WORLD, once ItemTree_Data is loaded (nothing otherwise:
-- the indexes read its modules, and this never loads it). Not sliced: the loading screen is up. An
-- entry that is not there is passed over and one that raises is left to the slicer and the first
-- open, as before. The time the whole call took is added to Data.loadTiming as indexesMs (once,
-- where the load was timed and the client has the clock), for /itprobe show. Answers how many
-- entries ran.
function Data:PreloadLoadingScreen()
  if not self:OnDemandLoaded() then
    return 0
  end
  local from = profileMs()
  local ran = 0
  for _, entry in ipairs(Data.PRELOAD_LOADING_SCREEN) do
    local fn, owner = nil, nil
    if type(entry) == "string" then
      -- Brief RB4: a module, built whole the way Data:Get builds it (the boss loot join), where it is
      -- registered and not built yet.
      if self.cache[entry] == nil and self.modules[entry] ~= nil and pcall(self.Get, self, entry) then
        ran = ran + 1
      end
    else
      fn, owner = warmTarget(entry)
    end
    if fn then
      local ok
      if entry.method then
        ok = pcall(fn, owner)
      else
        ok = pcall(fn)
      end
      if ok then
        ran = ran + 1
      end
    end
  end
  local timing = self.loadTiming
  if type(timing) == "table" and timing.indexesMs == nil then
    local now = from and profileMs()
    timing.indexesMs = now and (now - from) or nil
  end
  return ran
end

-- Brief PF2: the login slicer. Started a few seconds after the first PLAYER_ENTERING_WORLD of the
-- session (Core/Init.lua), it works through Data.PRELOAD_ORDER on our own unparented frame's
-- OnUpdate, and lets the frame go when the plan is done. Brief PF3: at most Data.PRELOAD_BUDGET_MS
-- a frame (Data:PreloadSlice), moving or not; nothing in a frame the player is in combat. A first
-- open, hover or bag before it gets there builds what it needs exactly as it always did.

-- The bags the slicer reads item ids from: the backpack (0) and the four bag slots.
Data.PRELOAD_BAGS = { 0, 1, 2, 3, 4 }

local function clientCall(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if ok then
    return value
  end
  return nil
end

-- Whether a frame should build nothing: the player is in combat. A client that will not say reads
-- as not. Brief PF3: moving no longer blocks it; the budget is what keeps a frame short now.
function Data.PreloadBlocked()
  if clientCall(rawget(_G, "InCombatLockdown")) then
    return true
  end
  return false
end

-- Brief PF3: the slicer's clock in milliseconds: the client's debugprofilestop (what Blizzard's own
-- code times with), else os.clock (the specs), else GetTime.
function Data.SliceClock()
  local profile = rawget(_G, "debugprofilestop")
  if type(profile) == "function" then
    local ok, ms = pcall(profile)
    if ok and type(ms) == "number" then
      return ms
    end
  end
  local osLib = rawget(_G, "os")
  if type(osLib) == "table" and type(osLib.clock) == "function" then
    return osLib.clock() * 1000
  end
  local getTime = rawget(_G, "GetTime")
  return (tonumber(clientCall(getTime)) or 0) * 1000
end

-- The item ids in the player's bags, read once when the plan's own modules are done. A container
-- slot read is not an item query: the client answers it from the bag it already holds, and nothing
-- is asked of the server.
function Data.BagItemIds()
  local container = rawget(_G, "C_Container")
  local slotsOf = type(container) == "table" and container.GetContainerNumSlots or rawget(_G, "GetContainerNumSlots")
  local idOf = type(container) == "table" and container.GetContainerItemID or rawget(_G, "GetContainerItemID")
  local ids = {}
  if type(slotsOf) ~= "function" or type(idOf) ~= "function" then
    return ids
  end
  for _, bag in ipairs(Data.PRELOAD_BAGS) do
    local slots = tonumber(clientCall(slotsOf, bag)) or 0
    for slot = 1, slots do
      local id = tonumber(clientCall(idOf, bag, slot))
      if id then
        ids[#ids + 1] = id
      end
    end
  end
  return ids
end

-- Stops the slicer's frame. Answers whether it was running.
function Data:StopPreload()
  local frame = self.preloadFrame
  if type(frame) ~= "table" or not self.preloadRunning then
    return false
  end
  self.preloadRunning = false
  pcall(frame.SetScript, frame, "OnUpdate", nil)
  pcall(frame.Hide, frame)
  return true
end

-- One frame of the slicer: nothing while blocked ("blocked"), else Data:PreloadSlice under the
-- budget (the label of the last item it worked on). When the plan runs out, the bag classes and the
-- bag scores join it once (Data:PreloadSlice); when it runs out again the slicer stops (nil).
function Data:PreloadTick()
  local run = self.preload
  if type(run) ~= "table" then
    self:StopPreload()
    return nil
  end
  if Data.PreloadBlocked() then
    return "blocked"
  end
  local name = self:PreloadSlice()
  if name then
    return name
  end
  self:StopPreload()
  return nil
end

-- Starts the slicer: the plan, then our own unparented frame's OnUpdate, Data.PRELOAD_BUDGET_MS of
-- it per frame. Once per session. Answers whether it started.
function Data:StartPreload()
  if self.preload then
    return false
  end
  self:PreloadStart()
  local frame = self.preloadFrame
  if not frame then
    local createFrame = rawget(_G, "CreateFrame")
    if type(createFrame) ~= "function" then
      return false
    end
    local ok, made = pcall(createFrame, "Frame")
    if not ok or type(made) ~= "table" or type(made.SetScript) ~= "function" then
      return false
    end
    frame = made
    self.preloadFrame = frame
  end
  local data = self
  -- A module that raises stops the slicer rather than raising again every frame; the open that
  -- wants it meets the same error through its own guarded path.
  local hooked = pcall(frame.SetScript, frame, "OnUpdate", function()
    if not pcall(data.PreloadTick, data) then
      data:StopPreload()
    end
  end)
  if not hooked then
    return false
  end
  self.preloadRunning = true
  pcall(frame.Show, frame)
  return true
end
