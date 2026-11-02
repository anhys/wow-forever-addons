-- The Discoveries model: what this client has watched the realm discover, and what a new data
-- build newly names, as one list newest first. Pure Lua, no WoW API.
--
-- WoW Forever withholds an item's details until somebody on the realm has found it
-- (../ItemTree-Data/docs/forever-sealed-items.md). Two things notice when one is found, and
-- this file is where they are read as one list:
--
--   the player's own records  Core/Collector.lua's discovery store, item id, name, quality, the
--                             data build the note was taken against, the moment it was taken and
--                             one field saying how the item was met. That field is what splits
--                             the store into two sources: "self" where the player obtained the
--                             item, and "realm" where this client could merely name it, which
--                             means somebody else on the realm found it. These are the only
--                             sources with a time on them.
--   the data build            Core/Diff.lua's discovered bucket: the baseline had the Item row
--                             and would not name it, and this build does. Source "data", no time
--                             of its own, so it is banded as "In this data build".
--
-- An id in both is the player's record: it is the one with a time, and it is the one this client
-- watched happen.
--
-- A third source is read where the owner runs it: the Discovery Miner, a private companion
-- addon that asks after the undiscovered ids at its own polite pace and keeps what it found in
-- the saved global DiscoveryMinerDB. Its finds read as "realm" (somebody on the realm found the
-- item and this client can now name it), with via = "miner" for later. Precedence for one id:
-- the collector's record, then the miner's, then the data build's. The miner's table is only
-- ever read, never written, and every other player's client has no such global and sees no
-- change at all (Discoveries.MinerEntries, Discoveries.MinerStore).
--
-- A row also carries the marks the rest of the window draws on that item, New and Changed, from
-- the same Core/Diff.lua the tree and the search dropdown read (Discoveries.Badges), already
-- narrowed to the ones the window's two badge toggles leave on. They are shipped data, so a
-- whole list of them costs no client call at all.
--
-- HARD RULE, and tests/spec/discoveries_spec.lua is the guard: nothing here asks the client
-- about an item. No GetItemInfo, no RequestLoadItemDataByID, not once and never in a loop. A
-- name comes from the collector's own record, from the shipped data, or from the neutral
-- placeholder Core/Graph.lua builds out of the build's own Item row. Core/Graph.lua's Graph.Name
-- is deliberately not used: for an item the data cannot name it falls through to the live client
-- (ItemTree.ItemFacts), which is exactly the query this pane must never make. Graph.names, the
-- plain table the collector writes the names it has seen into, is read instead.
--
-- Privacy: a discovery is item id, name, quality, build, a local time and the client's numeric
-- realm id, and that is all that is ever read here; nothing is written. The realm id is only
-- compared with the one this session is on (Discoveries.RealmSource) and is never shown. The one
-- exception (brief E79, owner sanctioned) is the name of the character that first saw the item,
-- field c on the collector's record: it is drawn in the row's Source column and its tooltip
-- (Discoveries.WhoLabel) and goes nowhere else. Nothing about the realm's name or the account.
-- The wording says "on your realm" and never names one.
--
-- Who and when (brief E79). The Source column names who saw the item: the character's name for
-- the player's own record ("You" for one written before the name was kept), "ItemTree" for the
-- shipped data and "Discovery Miner" for the owner's miner. The When column is the moment that
-- record was written, which is when ItemTree first saw the item and never when the realm first
-- found it; Discoveries.TIMES_NOTE says so over the list.
--
-- Everything is pure and takes its clock as an argument, so the specs and the browser harness
-- drive a fixed one. UI/Discoveries.lua is the pane that draws this.
local _, ItemTree = ...

local Discoveries = {}
ItemTree.Discoveries = Discoveries

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

local DAY = 86400
-- Today and yesterday have bands of their own, so "earlier this week" is the six days behind
-- them: a discovery seven days old reads as "Earlier" rather than as this week.
local WEEK_DAYS = 6

-- Brief P4: the list as parallel arrays. Discoveries.Entries used to answer one table per entry,
-- and at the owner's 16,000 miner finds that was 12 MB held for a list the pane draws forty rows
-- of. The built list is now a set of columns, one array per field (id, name, source, time, and
-- quality, icon, via, character and build where an entry has them), and the list itself is an
-- array of positions in those columns, newest first. An entry table is made only where one is
-- read: a row a draw realises (Discoveries.Rows), or Discoveries.Entry for a caller that wants
-- one. Every function here that takes a list takes either shape, element by element: a table is
-- an entry as it always was (the specs and the harness hand those in), and a number is a
-- position in the columns the list came from.
--
-- A list's columns are held beside it (listColumns, weak keyed) rather than on it, so a list is
-- still a plain array a spec can compare. A list of positions nothing is held for (the harness
-- hands the cached list back as a copy) reads the columns of the cached list (cache.cols).
local listColumns = setmetatable({}, { __mode = "k" })

-- The cached list and everything kept for it (see Discoveries.Entries, further down). Declared
-- here because the list functions below read its columns.
local cache = { key = nil, entries = nil, cols = nil, changed = nil, stubs = nil, version = 0 }

-- The fields an entry carries, which are the columns of a built list.
local ENTRY_FIELDS = { "id", "name", "quality", "icon", "time", "source", "via", "character", "build" }

local function newColumns()
  local cols = { n = 0 }
  for _, field in ipairs(ENTRY_FIELDS) do
    cols[field] = {}
  end
  -- Per position: whether the shipped data was asked for the icon and quality (fillFacts), each
  -- row's badges (memoBadges) and the lower case name the search box compares (searchNameOf).
  -- Filled only for the positions something reads.
  cols.looked, cols.badges, cols.lower = {}, {}, {}
  return cols
end

-- Appends one entry's fields as a new position, and answers the position.
local function addRow(cols, id, name, source, time, quality, icon, via, character, build)
  local pos = cols.n + 1
  cols.n = pos
  cols.id[pos], cols.name[pos], cols.source[pos], cols.time[pos] = id, name, source, time
  cols.quality[pos], cols.icon[pos], cols.via[pos] = quality, icon, via
  cols.character[pos], cols.build[pos] = character, build
  return pos
end

-- The columns a list's positions are read from.
local function columnsOf(list)
  return listColumns[list] or cache.cols
end

-- A new list that reads the same columns as another.
local function listLike(list)
  local out = {}
  local cols = listColumns[list]
  if cols then
    listColumns[out] = cols
  end
  return out
end

-- One field of one element of a list: off the entry for a table, out of the columns for a
-- position, and nil for anything else.
local function fieldOf(cols, element, field)
  if type(element) == "table" then
    return element[field]
  end
  if type(element) == "number" and cols then
    local column = cols[field]
    return column and column[element] or nil
  end
  return nil
end

-- Where a row came from, which is the question the last column answers. Three kinds, because
-- three different things happened:
--
--   self   the player obtained the item themselves. Core/Collector.lua knows because the
--          client said so in its own words as the item arrived.
--   realm  this client could name an item the data marks undiscovered, and the player only saw
--          it named: a tooltip, a chat link, a merchant's stock, a quest's reward list. Somebody
--          else on the realm found it and the server has released the details.
--   other  as realm, but the record carries the id of another realm the player also plays on.
--          It shows under "All" and never under "On your realm", which means the realm the
--          player is on now. A record with no realm id counts as the current realm.
--   data   a newer ItemTree data build names it. Nothing happened on this realm at all.
--
-- A record the collector wrote before it kept this apart reads as "realm": it is the weaker of
-- the two claims and nothing can now say otherwise.
Discoveries.SOURCE_SELF = "self"
Discoveries.SOURCE_REALM = "realm"
Discoveries.SOURCE_OTHER = "other"
Discoveries.SOURCE_DATA = "data"

-- The four, in the order they are counted. The pane's tabs are its own list and offer three of
-- them: "other" is reached from "All" alone.
Discoveries.SOURCES = {
  Discoveries.SOURCE_SELF,
  Discoveries.SOURCE_REALM,
  Discoveries.SOURCE_OTHER,
  Discoveries.SOURCE_DATA,
}

Discoveries.KIND_HEADER = "header"
Discoveries.KIND_ITEM = "item"

Discoveries.BAND_TODAY = "today"
Discoveries.BAND_YESTERDAY = "yesterday"
Discoveries.BAND_WEEK = "week"
Discoveries.BAND_EARLIER = "earlier"
Discoveries.BAND_BUILD = "build"

-- The order the bands are drawn in, newest first. The data build's own discoveries come last
-- because they carry no moment at all: they have been true since the build shipped, so they are
-- not news that happened today, and dating them would be inventing a time.
Discoveries.BANDS = {
  Discoveries.BAND_TODAY,
  Discoveries.BAND_YESTERDAY,
  Discoveries.BAND_WEEK,
  Discoveries.BAND_EARLIER,
  Discoveries.BAND_BUILD,
}

-- The words over each band. Written as literals so tests/spec/locale_spec.lua finds them.
local BAND_LABELS = {
  today = L["Today"],
  yesterday = L["Yesterday"],
  week = L["Earlier this week"],
  earlier = L["Earlier"],
  build = L["In this data build"],
}

-- The words in the "Source" column. Brief W33 dropped the longer sentence a hovered row used to
-- carry under them: the owner found the row's tooltip said more than a player needs.
local SOURCE_LABELS = {
  self = L["Found by you"],
  realm = L["On your realm"],
  other = L["Other realms"],
  data = L["New data"],
}

-- The word each source tab carries, plus the one over all of them. Short, because they are drawn
-- as four tabs across one row with the search box beside them, and each one wears its count.
local FILTER_LABELS = {
  self = L["By you"],
  realm = L["On your realm"],
  data = L["New data"],
}

-- The words in the Source column for who saw an item (brief E79, Discoveries.WhoLabel).
local WHO_YOU = L["You"]
local WHO_ITEMTREE = L["ItemTree"]
local WHO_MINER = L["Discovery Miner"]

-- The one sentence the tab's info line carries (brief E79). Brief W33 took it off the row tooltip.
Discoveries.TIMES_NOTE = L["Times are when ItemTree first saw an item, not when your realm first found it."]

-- Developer placeholders the build still ships. An item called "DEPRECATED" is not a discovery,
-- it is a row nobody wants to read, and the owner saw one at the top of his list. The test is
-- deliberately conservative and is applied to this list alone: every one of these items is still
-- reachable by id, in the tree, in search and in every other pane.
--
-- Nothing in ../ItemTree-Data names these, so the rule lives here rather than in the pipeline:
-- the pipeline states what the build states, and which rows are worth reading is a window
-- decision. Matched against the name the build gives, case sensitively, because these are
-- shouted by convention and "Old Blade" is a real item.
local NOISE_EXACT = {
  DEPRECATED = true,
  UNUSED = true,
  TEST = true,
}

local NOISE_PREFIXES = { "DEPRECATED", "OLD ", "zzOLD", "[PH]", "TEST ", "UNUSED" }
local NOISE_SUFFIXES = { "(DEPRECATED)", "(OLD)", "(TEST)" }

-- Where the moment the tab was last opened is kept. A number and nothing else.
Discoveries.SEEN_KEY = "discoveriesSeen"

-- The four tick boxes on the tab row, right of the search box, one per kind of row (Discoveries.ChangeClass).
-- Each is a boolean and nothing else, account wide beside SEEN_KEY. The two older keys keep their
-- names, so a choice a player saved before there were four boxes survives.
Discoveries.SHOW_NEW_KEY = "discoveriesShowNew"
Discoveries.SHOW_SOD_KEY = "discoveriesShowSod"
Discoveries.SHOW_CHANGED_KEY = "discoveriesShowChanged"
Discoveries.SHOW_UNCHANGED_KEY = "discoveriesShowUnchanged"

--- The words over a band, falling back to "Earlier" for a band nothing named. Pure.
function Discoveries.BandLabel(band)
  return BAND_LABELS[band] or BAND_LABELS[Discoveries.BAND_EARLIER]
end

--- The words in the "Source" column for a source, and nothing at all for a source with no name.
--- Pure.
function Discoveries.SourceLabel(source)
  return SOURCE_LABELS[source] or ""
end

--- A character's name as a row may draw it: a plain name of 2 to 24 characters, no realm part,
--- no spaces, or nil. The collector's own Collector.CharacterName where it is loaded, so the two
--- cannot drift, and the same rule written out here where it is not. Pure.
function Discoveries.CharacterName(value)
  local Collector = ItemTree.Collector
  if type(Collector) == "table" and type(Collector.CharacterName) == "function" then
    local ok, name = pcall(Collector.CharacterName, value)
    if ok then
      return type(name) == "string" and name or nil
    end
  end
  if type(value) ~= "string" or #value < 2 or #value > 24 or value:find("[%s%c%-%d%p]") then
    return nil
  end
  return value
end

--- Who saw an item, as the Source column says it (brief E79): the Discovery Miner's name for a
--- row the owner's miner brought, "ItemTree" for the shipped data, and for the player's own
--- record the name of the character that first saw it, or "You" for a record written before the
--- name was kept. Pure.
function Discoveries.WhoLabel(entry)
  if type(entry) ~= "table" then
    return ""
  end
  if entry.via == "miner" then
    return WHO_MINER
  end
  if entry.source == Discoveries.SOURCE_DATA then
    return WHO_ITEMTREE
  end
  return Discoveries.CharacterName(entry.character) or WHO_YOU
end

--- Every word the Source column can carry, so the column is drawn wide enough: the fixed words
--- and the name of the character this session is on, where the collector knows it. Pure but for
--- the collector read, which is guarded.
function Discoveries.WhoSamples()
  local out = { WHO_YOU, WHO_ITEMTREE, WHO_MINER }
  local collector = ItemTree.collector
  if type(collector) == "table" and type(collector.Character) == "function" then
    local ok, name = pcall(collector.Character, collector)
    name = ok and Discoveries.CharacterName(name) or nil
    if name then
      out[#out + 1] = name
    end
  end
  return out
end

--- The short word the filter offers for one source, or the word for all of them where it is
--- handed nothing. Pure.
function Discoveries.FilterLabel(source)
  return FILTER_LABELS[source] or L["All"]
end

--- Whether a name is a developer placeholder rather than an item worth listing. Conservative on
--- purpose: an exact shout, one of a handful of prefixes, or one of three bracketed suffixes.
--- Case sensitive, because the convention is to shout them and "Old Blade" is a real item.
--- Pure, and used by this list alone.
function Discoveries.IsNoiseName(name)
  if type(name) ~= "string" or name == "" then
    return false
  end
  local trimmed = name:match("^%s*(.-)%s*$") or name
  if NOISE_EXACT[trimmed] then
    return true
  end
  for _, prefix in ipairs(NOISE_PREFIXES) do
    if trimmed:sub(1, #prefix) == prefix then
      return true
    end
  end
  for _, suffix in ipairs(NOISE_SUFFIXES) do
    if #trimmed >= #suffix and trimmed:sub(-#suffix) == suffix then
      return true
    end
  end
  return false
end

--- The moment today began, from a clock and the wall time on it: the caller reads the hour, the
--- minute and the second off the client (or off os.date under a spec) and this turns them into
--- the timestamp midnight sat at. Pure, which is what keeps the calendar out of this file.
--- Returns nil when nothing will say what the time is, and Discoveries.Band then bands by
--- elapsed time instead.
function Discoveries.DayStart(now, hour, minute, second)
  now = tonumber(now)
  hour, minute = tonumber(hour), tonumber(minute)
  if not now or not hour or not minute then
    return nil
  end
  return now - (hour * 3600 + minute * 60 + (tonumber(second) or 0))
end

--- Which band an entry falls in. A data build's entry with no moment is "In this data build"; a
--- record of the player's own, and a data build's entry the shipped data dates
--- (Diff.DiscoveredAt), is banded by its own moment against midnight where the caller could say
--- when midnight was, and by elapsed time where it could not. A record with no moment at all
--- (a store written before the collector stamped one) reads as "Earlier", which is the honest
--- answer: it certainly did not happen today. Pure.
local function bandOf(source, time, now, dayStart)
  local at = tonumber(time)
  if source == Discoveries.SOURCE_DATA and not at then
    return Discoveries.BAND_BUILD
  end
  if not at then
    return Discoveries.BAND_EARLIER
  end
  local midnight = tonumber(dayStart)
  if midnight then
    if at >= midnight then
      return Discoveries.BAND_TODAY
    end
    if at >= midnight - DAY then
      return Discoveries.BAND_YESTERDAY
    end
    if at >= midnight - WEEK_DAYS * DAY then
      return Discoveries.BAND_WEEK
    end
    return Discoveries.BAND_EARLIER
  end
  local elapsed = (tonumber(now) or 0) - at
  if elapsed < DAY then
    return Discoveries.BAND_TODAY
  end
  if elapsed < 2 * DAY then
    return Discoveries.BAND_YESTERDAY
  end
  if elapsed < (WEEK_DAYS + 1) * DAY then
    return Discoveries.BAND_WEEK
  end
  return Discoveries.BAND_EARLIER
end

function Discoveries.Band(entry, now, dayStart)
  if type(entry) ~= "table" then
    return Discoveries.BAND_EARLIER
  end
  return bandOf(entry.source, entry.time, now, dayStart)
end

--- What a row is called: the name the record or the build carries, and the neutral placeholder
--- for anything else. Never a Classic Era name for an id this build withholds, which is the one
--- thing this addon must not hand back. Pure.
function Discoveries.DisplayName(entry)
  if type(entry) == "table" and type(entry.name) == "string" and entry.name ~= "" then
    return entry.name
  end
  return L["Undiscovered item"]
end

--- Elapsed time in the "when" column, in the same words the Recently viewed list uses, and
--- nothing at all for an entry with no moment: the band over it already says where it sits.
--- Core/History.lua owns the words so the two lists cannot drift. Pure: now must be a number,
--- because a model that reaches for the client's clock is not one a spec can drive.
function Discoveries.WhenText(entry, now)
  local at = type(entry) == "table" and tonumber(entry.time) or nil
  if not at or not tonumber(now) then
    return ""
  end
  local History = ItemTree.History
  if type(History) ~= "table" or type(History.Ago) ~= "function" then
    return ""
  end
  local ok, text = pcall(History.Ago, at, tonumber(now))
  if ok and type(text) == "string" then
    return text
  end
  return ""
end

-- Newest first. An entry with no moment sorts after every dated one, and two that read alike
-- fall back to the item id so the list never shuffles under the player. newer takes the two ids
-- and the two moments, so a list of positions sorts without a table per comparison.
local function newer(aId, aTime, bId, bTime)
  local at, bt = tonumber(aTime), tonumber(bTime)
  if at and bt then
    if at ~= bt then
      return at > bt
    end
    return aId < bId
  end
  if at then
    return true
  end
  if bt then
    return false
  end
  return aId < bId
end

local function byNewest(a, b)
  return newer(a.id, a.time, b.id, b.time)
end

--- Which of the two realm sources a record belongs to: "other" where both its realm id and the
--- current one are known and differ, and "realm" for anything else. A record with no id, or a
--- session whose id nothing will say, counts as the current realm, which is exactly how every
--- record read before the id was kept. Only a positive whole number counts as an id. Pure.
function Discoveries.RealmSource(recordRealm, currentRealm)
  local function valid(value)
    return type(value) == "number" and value > 0 and value == math.floor(value) and value < math.huge
  end
  if valid(recordRealm) and valid(currentRealm) and recordRealm ~= currentRealm then
    return Discoveries.SOURCE_OTHER
  end
  return Discoveries.SOURCE_REALM
end

--- One record of the collector's store as the table this file reads, { n, q, b, t, h, realm, c }
--- (brief R3: the store keeps a packed string, Core/Collector.lua Collector.ViewDiscovery). The
--- collector's own view where it is loaded, which fills in the build list, this session's exact
--- moments and the data build's name; a table is its own view where there is no collector. nil
--- for anything that is not a record. Pure but for the collector read, which is guarded.
function Discoveries.RecordView(itemId, held)
  local collector = ItemTree.collector
  if type(collector) == "table" and type(collector.DiscoveryView) == "function" then
    local ok, view = pcall(collector.DiscoveryView, collector, itemId, held, true)
    if ok then
      return type(view) == "table" and view or nil
    end
  end
  local Collector = ItemTree.Collector
  if type(Collector) == "table" and type(Collector.ViewDiscovery) == "function" then
    local ok, view = pcall(Collector.ViewDiscovery, itemId, held, nil, nil, true)
    if ok then
      return type(view) == "table" and view or nil
    end
  end
  return type(held) == "table" and held or nil
end

--- Who found one record and its realm id, out of the store's packed string or a table, with no
--- table made (Core/Collector.lua Collector.DiscoveryWho). Pure.
function Discoveries.RecordWho(held)
  if type(held) == "table" then
    return held.h, held.realm
  end
  local Collector = ItemTree.Collector
  if type(Collector) == "table" and type(Collector.DiscoveryWho) == "function" then
    local ok, h, realm = pcall(Collector.DiscoveryWho, held)
    if ok then
      return h, realm
    end
  end
  return nil, nil
end

--- The player's own discoveries, from the collector's store (item id to a record, each read
--- through view, Discoveries.RecordView by default, as { n, q, b, t, h, realm, c }), newest first.
--- The store is a hash keyed by item id and has no insertion order to read, so an entry with no
--- moment is ordered by id after the dated ones rather than by a time this file would have to
--- invent. realm is the id this session is on, or nil (Discoveries.RealmSource). Pure.
function Discoveries.PlayerEntries(store, realm, view)
  local out = {}
  if type(store) ~= "table" then
    return out
  end
  view = type(view) == "function" and view or Discoveries.RecordView
  for itemId, value in pairs(store) do
    local id = tonumber(itemId)
    local held = id and view(id, value) or nil
    if id and type(held) == "table" and type(held.n) == "string" and held.n ~= "" then
      -- h is what the collector wrote down about how the item was met. Anything that is not
      -- exactly "self" reads as the realm, which is what a record from before the field
      -- existed has to read as: nothing can now say otherwise. The player's own find stays
      -- theirs whichever realm it was made on; a sighting on another realm is "other".
      local source = Discoveries.RealmSource(held.realm, realm)
      if held.h == Discoveries.SOURCE_SELF then
        source = Discoveries.SOURCE_SELF
      end
      out[#out + 1] = {
        id = id,
        name = held.n,
        quality = tonumber(held.q),
        build = type(held.b) == "string" and held.b or nil,
        time = tonumber(held.t),
        source = source,
        -- The character that first saw it (brief E79), or nil for an old record.
        character = Discoveries.CharacterName(held.c),
      }
    end
  end
  table.sort(out, byNewest)
  return out
end

--- The ids a data build newly names, as entries, by id ascending. facts is asked what the data
--- says about each one and may answer nothing, which leaves the row on the placeholder name.
--- A name that is a developer placeholder is dropped here and nowhere else: the build still
--- ships those items and every other pane still reaches them. Pure: facts is a function the
--- caller hands in, and Discoveries.ItemFacts is the one the pane passes. Pure.
function Discoveries.DataEntries(ids, facts)
  local out = {}
  if type(ids) ~= "table" then
    return out
  end
  local seen = {}
  for _, value in ipairs(ids) do
    local id = tonumber(value)
    if id and not seen[id] then
      seen[id] = true
      local name, quality, icon = nil, nil, nil
      if type(facts) == "function" then
        local ok, found = pcall(facts, id)
        if ok and type(found) == "table" then
          if type(found.name) == "string" and found.name ~= "" then
            name = found.name
          end
          quality = tonumber(found.quality)
          icon = found.icon
        end
      end
      if not Discoveries.IsNoiseName(name) then
        out[#out + 1] = {
          id = id,
          name = name,
          quality = quality,
          icon = icon,
          source = Discoveries.SOURCE_DATA,
        }
      end
    end
  end
  table.sort(out, function(a, b)
    return a.id < b.id
  end)
  return out
end

--- What the Discovery Miner found, as entries, newest first. db is the miner's store, the
--- DiscoveryMinerDB.store sub-table Discoveries.MinerStore hands over, read as untrusted:
--- anything that is not the shape the miner writes is skipped, never raised on, and nothing is
--- written back to it. Only five fields of a record are read: id, n (the name), q (the quality),
--- t (the unix time it flipped to discovered) and i (the icon's file id, which the miner read off
--- the find itself). rid, the numeric realm id the miner stamps, is compared with realm (the id
--- this session is on, Discoveries.RealmSource) and never copied: a find on another realm reads
--- as "other", and one without rid as the current realm. The miner stores no character, realm
--- name or account, and nothing else of its record is copied. An i that is not a positive whole
--- number is dropped, not the record.
---
--- A record is skipped where its id is not a positive whole number, its name is not a non empty
--- string or its time is not a number. now, where it is given, also skips a time more than a
--- day ahead of it: a clock that far out would sit in the tab's count for ever. Every read is
--- pcalled, so a table with a metatable that raises costs its own record and nothing more. Pure.
-- One miner record read as the untrusted thing it is: id, name, quality, icon, time and source,
-- or nothing for a record that is not the shape the miner writes. MinerEntries and the built
-- list both read records through this, so the two can never disagree about which are taken.
local function readMinerRecord(record, limit, realm)
  if type(record) ~= "table" then
    return nil
  end
  local id, name, quality, at = rawget(record, "id"), rawget(record, "n"), rawget(record, "q"), rawget(record, "t")
  local icon, rid = rawget(record, "i"), rawget(record, "rid")
  if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then
    return nil
  end
  if type(name) ~= "string" or name == "" then
    return nil
  end
  if type(at) ~= "number" or at ~= at then
    return nil
  end
  if limit and at > limit then
    return nil
  end
  if type(quality) ~= "number" then
    quality = nil
  end
  if type(icon) ~= "number" or icon <= 0 or icon ~= math.floor(icon) then
    icon = nil
  end
  return id, name, quality, icon, at, Discoveries.RealmSource(rid, realm)
end

-- Every record of the miner's store handed to take(id, name, quality, icon, time, source), once
-- per id, in the order the store's own next gives them. Every read pcalled.
local function eachMinerRecord(db, now, realm, take)
  if type(db) ~= "table" then
    return
  end
  local okSeen, seen = pcall(rawget, db, "seen")
  if not okSeen or type(seen) ~= "table" then
    return
  end
  local limit = tonumber(now)
  if limit then
    limit = limit + DAY
  end
  local taken = {}
  pcall(function()
    for _, record in next, seen do
      local ok, id, name, quality, icon, at, source = pcall(readMinerRecord, record, limit, realm)
      if ok and id and not taken[id] then
        taken[id] = true
        take(id, name, quality, icon, at, source)
      end
    end
  end)
end

function Discoveries.MinerEntries(db, now, realm)
  local out = {}
  eachMinerRecord(db, now, realm, function(id, name, quality, icon, at, source)
    out[#out + 1] = {
      id = id,
      name = name,
      quality = quality,
      icon = icon,
      time = at,
      source = source,
      via = "miner",
    }
  end)
  table.sort(out, byNewest)
  return out
end

--- The sources as one list: the player's records first, then the build's, with an id that is in
--- both kept as the player's. That is the rule and not an accident of the time order (brief E79):
--- the player's own first sighting wins over the shipped record for the same item, whichever is
--- older, and survives a data update that ships a newer or older discoveredAt for it. The shipped
--- row for that item is not drawn at all. Both lists arrive sorted, so the answer is the player's newest
--- first and then the build's by id.
---
--- miner, where it is handed one, is the Discovery Miner's (Discoveries.MinerEntries). The
--- player's record beats the miner's for the same id and the miner's beats the build's, because
--- it has a time. The dated part (the player's and the miner's together) is then ordered newest
--- first as one, and the build's follow by id. With no miner list the answer is exactly what it
--- was before the miner existed.
---
--- One exception to that order: a player's record from another realm ("other") gives way to the
--- miner's find of the same id on this realm, because the item is on this realm now and that is
--- the stronger thing to say about it here.
---
--- A build's entry the shipped data dates (Diff.DiscoveredAt) is sorted in among the dated part
--- by its moment; the undated ones still follow everything, by id. Pure.
-- The merge itself, over lists of entries, positions or both: cols is the columns a position is
-- read from. Answers one list of the elements it was handed, so a list of positions merges into
-- a list of positions and no entry table is made.
local function mergeLists(cols, player, data, miner)
  local out, seen = {}, {}
  local here = {}
  if type(miner) == "table" then
    for _, element in ipairs(miner) do
      local id = tonumber(fieldOf(cols, element, "id"))
      if id and fieldOf(cols, element, "source") == Discoveries.SOURCE_REALM then
        here[id] = true
      end
    end
  end
  local function take(list, dated, yield)
    for _, element in ipairs(list or EMPTY) do
      local id = tonumber(fieldOf(cols, element, "id"))
      local yields = yield and id and here[id] and fieldOf(cols, element, "source") == Discoveries.SOURCE_OTHER
      local timed = tonumber(fieldOf(cols, element, "time")) ~= nil
      if id and not seen[id] and not yields and (dated == nil or timed == dated) then
        seen[id] = true
        out[#out + 1] = element
      end
    end
  end
  take(player, nil, true)
  local resort = false
  if type(miner) == "table" and #miner > 0 then
    take(miner)
    resort = true
  end
  local before = #out
  take(data, true)
  if #out > before then
    resort = true
  end
  if resort then
    table.sort(out, function(a, b)
      return newer(
        tonumber(fieldOf(cols, a, "id")),
        fieldOf(cols, a, "time"),
        tonumber(fieldOf(cols, b, "id")),
        fieldOf(cols, b, "time")
      )
    end)
  end
  take(data, false)
  return out
end

function Discoveries.Merge(player, data, miner)
  local cols = listColumns[data] or listColumns[miner] or listColumns[player] or cache.cols
  local out = mergeLists(cols, player, data, miner)
  if cols then
    listColumns[out] = cols
  end
  return out
end

-- The lower case name each entry is searched by, worked out once per entry and name rather than
-- once per keystroke. Weak keyed, so an entry the list has dropped takes its name with it.
local searchNames = setmetatable({}, { __mode = "k" })

--- The words an entry is searched by: its display name in lower case, remembered per entry for
--- as long as the name is the same. Pure.
function Discoveries.SearchName(entry)
  local name = Discoveries.DisplayName(entry)
  if type(entry) ~= "table" then
    return name:lower()
  end
  local held = searchNames[entry]
  if held and held.name == name then
    return held.lower
  end
  local lower = name:lower()
  searchNames[entry] = { name = name, lower = lower }
  return lower
end

--- Whether an entry's name contains the needle, which is already trimmed and lower case. An
--- empty needle matches everything. Pure.
function Discoveries.Matches(entry, needle)
  if type(needle) ~= "string" or needle == "" then
    return true
  end
  return Discoveries.SearchName(entry):find(needle, 1, true) ~= nil
end

-- The lower case name a position is searched by, kept in its columns once worked out.
local function searchNameAt(cols, pos)
  local held = cols.lower[pos]
  if held then
    return held
  end
  local name = cols.name[pos]
  if type(name) ~= "string" or name == "" then
    name = L["Undiscovered item"]
  end
  held = name:lower()
  cols.lower[pos] = held
  return held
end

--- The search box's view over the list: the entries whose name contains the text, in the order
--- they were already in. Always a new list, so nothing the caller holds is rewritten. Pure.
function Discoveries.Filter(entries, text)
  local needle = ""
  if type(text) == "string" then
    needle = text:match("^%s*(.-)%s*$"):lower()
  end
  local out = listLike(entries)
  local cols = columnsOf(entries)
  for _, element in ipairs(entries or EMPTY) do
    local keep
    if type(element) == "number" then
      keep = cols ~= nil
        and cols.id[element] ~= nil
        and (needle == "" or searchNameAt(cols, element):find(needle, 1, true) ~= nil)
    else
      keep = Discoveries.Matches(element, needle)
    end
    if keep then
      out[#out + 1] = element
    end
  end
  return out
end

--- Whether a badge is one the player has switched off. The two toggles in the window's header
--- are the same two Core/ViewModel.lua reads for the tree (opts.badgesNew, opts.badgesChanged),
--- and anything that is not one of them is always allowed. Opts nothing states is every badge,
--- which is what a caller with no settings to hand means. Pure.
function Discoveries.BadgeAllowed(opts, badge)
  if type(opts) ~= "table" then
    return true
  end
  -- Season of Discovery ("sod") is New in purple (brief D2), so the New toggle switches it too.
  -- Core/Diff.lua's Diff.IsNewBadge is the rule, read guarded; plain "new" without it.
  local Diff = ItemTree.Diff
  local isNew = badge == "new"
  if type(Diff) == "table" and type(Diff.IsNewBadge) == "function" then
    local ok, answer = pcall(Diff.IsNewBadge, badge)
    if ok then
      isNew = answer == true
    end
  end
  if isNew then
    return opts.badgesNew ~= false
  end
  if badge == "changed" then
    return opts.badgesChanged ~= false
  end
  return true
end

--- The marks this build put on one item, in Core/Diff.lua's own order, with the two the player
--- has switched off left out. The same list the tree and the search dropdown draw, from the same
--- Diff.Badges, so a row cannot wear one mark here and another there.
---
--- Core/Diff.lua answers out of the shipped data, so this is a table read and never a question to
--- the client: the hard rule at the top of this file holds for a whole list of these. Guarded,
--- because a build whose Diff will not answer draws no badges rather than raising.
function Discoveries.Badges(itemId, opts)
  local out = {}
  local id = tonumber(itemId)
  local Diff = ItemTree.Diff
  if not id or type(Diff) ~= "table" or type(Diff.Badges) ~= "function" then
    return out
  end
  local ok, kinds = pcall(Diff.Badges, "items", id)
  if not ok or type(kinds) ~= "table" then
    return out
  end
  for _, badge in ipairs(kinds) do
    if Discoveries.BadgeAllowed(opts, badge) then
      out[#out + 1] = badge
    end
  end
  return out
end

--- Whether an entry is new to the player: it carries a moment and that moment is later than the
--- player's previous look at the tab (sinceLast, from SeenAt before this look began). Undated
--- entries, which is what a data build brings, are never new, and nothing to compare against
--- (a nil or unreadable sinceLast) is never new either. Pure.
function Discoveries.IsNew(entry, sinceLast)
  if type(entry) ~= "table" then
    return false
  end
  local time = tonumber(entry.time)
  local since = tonumber(sinceLast)
  if not time or not since then
    return false
  end
  return time > since
end

--- One drawable row. The pane reads nothing off the entry itself, so everything a row draws is
--- decided here, the badges included: the pane draws the list it is handed and asks nothing
--- about an item itself. opts is the window's settings (Frame.OptionsFromSettings), and nothing
--- at all is every badge. opts.sinceLast, where given, is the player's previous look at the tab,
--- and the row answers isNew against it (see IsNew). badges, where handed over, is the list
--- Discoveries.Badges already answered for this item and these opts, which is how a lazy row
--- reuses one it worked out before (Discoveries.Rows). Pure.
function Discoveries.RowModel(entry, band, now, opts, badges)
  if type(entry) ~= "table" then
    return nil
  end
  local id = tonumber(entry.id)
  if not id then
    return nil
  end
  if type(badges) ~= "table" then
    badges = Discoveries.Badges(id, opts)
  end
  return {
    kind = Discoveries.KIND_ITEM,
    band = band,
    id = id,
    name = Discoveries.DisplayName(entry),
    quality = tonumber(entry.quality),
    icon = entry.icon,
    source = entry.source,
    -- The New and Changed medallions the rest of the window draws on this item, already
    -- narrowed to the ones the header's two toggles leave on.
    badges = badges,
    -- The words in the Source column. Who saw it (brief E79): the character's name, "You",
    -- "ItemTree" or the miner's name.
    how = Discoveries.WhoLabel(entry),
    when = Discoveries.WhenText(entry, now),
    time = tonumber(entry.time),
    build = entry.build,
    -- Newer than the player's previous look, so the row carries the NEW! tag beside its name.
    isNew = type(opts) == "table" and opts.sinceLast ~= nil and Discoveries.IsNew(entry, opts.sinceLast) == true,
  }
end

--- One band header row. Pure.
function Discoveries.HeaderRow(band)
  local label = Discoveries.BandLabel(band)
  return {
    kind = Discoveries.KIND_HEADER,
    band = band,
    label = label,
    name = label,
  }
end

-- The one key a memoised badge list is good for: the two toggles that narrow it.
local function badgeSignature(opts)
  if type(opts) ~= "table" then
    return "11"
  end
  return (opts.badgesNew ~= false and "1" or "0") .. (opts.badgesChanged ~= false and "1" or "0")
end

-- The badges one entry wears under these opts, worked out once per entry and signature. Weak
-- keyed, so the memo goes with the entry: Discoveries.Entries builds new entries whenever its
-- cache is invalidated, and those start with no memo at all.
local badgeMemo = setmetatable({}, { __mode = "k" })

-- key is the entry, or a position of a built list, whose memo is kept in its columns (dropped
-- with the list) rather than in the weak table.
local function memoBadges(key, id, opts, cols)
  local signature = badgeSignature(opts)
  local memo = badgeMemo
  if type(key) == "number" and cols then
    memo = cols.badges
  end
  local held = memo[key]
  if held and held.signature == signature and held.id == id then
    return held.badges
  end
  local badges = Discoveries.Badges(id, opts)
  memo[key] = { signature = signature, id = id, badges = badges }
  return badges
end

-- The key a stub memo keeps its stubs' entries under (see Discoveries.Rows). A table, so it can
-- never be mistaken for an entry.
local PENDING = {}

--- Every row the list draws: each band that has anything in it, in band order, with its own
--- header over its rows. The entries keep the order they arrived in, which is newest first, and
--- a band with nothing in it draws no header at all. opts is handed on to every row, so the
--- badge toggles reach the list through the one draw.
---
--- opts.lazy (the pane passes it) makes every item row a stub of three fields, kind, band and id,
--- and the rest of the row model (RowModel: name, badges, icon, quality, the words and the NEW!
--- tag) is built the first time anything reads another field off it. A ScrollBox initialises
--- only the rows it shows, so a list of five thousand costs the band pass and the rows on screen.
--- The badges a row works out are remembered per entry until the entries are rebuilt, so
--- scrolling back up does not ask Core/Diff.lua again. A lazy row reads exactly like an eager
--- one, field for field; only pairs over an unread one sees the three fields. Without opts.lazy
--- every row is built at once, which is what the browser harness walks. Pure.
function Discoveries.Rows(entries, now, dayStart, opts)
  local cols = columnsOf(entries)
  local buckets = {}
  for _, entry in ipairs(entries or EMPTY) do
    local band
    if type(entry) == "number" then
      band = bandOf(fieldOf(cols, entry, "source"), fieldOf(cols, entry, "time"), now, dayStart)
    else
      band = Discoveries.Band(entry, now, dayStart)
    end
    buckets[band] = buckets[band] or {}
    local bucket = buckets[band]
    bucket[#bucket + 1] = entry
  end
  local lazy = type(opts) == "table" and opts.lazy == true
  -- Brief P2 (#8): opts.stubs is a table the caller keeps for as long as the cached list holds
  -- (Discoveries.StubMemo, dropped with the list when CacheVersion moves). With it, each entry's
  -- stub is made once and handed out again on every draw, so a keystroke or a tick box builds no
  -- row tables. A stub a draw realised is put back to its three fields and armed again, so a row
  -- still reads exactly what this draw's now and opts say.
  local stubs = lazy and type(opts.stubs) == "table" and opts.stubs or nil
  -- Each stub's entry, held beside it rather than on it, so a realised row carries exactly the
  -- fields an eager one does. Kept in the memo with the stubs when there is one.
  local pending
  if stubs then
    stubs[PENDING] = stubs[PENDING] or {}
    pending = stubs[PENDING]
  else
    pending = {}
  end
  local stub = {}
  stub.__index = function(row, key)
    local entry = pending[row]
    if entry == nil or getmetatable(row) ~= stub then
      return nil
    end
    if not stubs then
      pending[row] = nil
    end
    setmetatable(row, nil)
    local id = rawget(row, "id")
    local memoKey = entry
    if type(entry) == "number" then
      entry = Discoveries.Entry({ memoKey }, 1, cols)
    end
    local model = Discoveries.RowModel(entry, rawget(row, "band"), now, opts, memoBadges(memoKey, id, opts, cols))
    for field, value in pairs(model or EMPTY) do
      rawset(row, field, value)
    end
    return rawget(row, key)
  end
  local function stubFor(entry, band, id)
    local row = stubs and stubs[entry] or nil
    if row and rawget(row, "band") == band and rawget(row, "id") == id then
      if getmetatable(row) == nil then
        -- Realised by an earlier draw: back to the three fields a stub carries.
        for field in pairs(row) do
          if field ~= "kind" and field ~= "band" and field ~= "id" then
            row[field] = nil
          end
        end
      end
      return setmetatable(row, stub)
    end
    row = setmetatable({ kind = Discoveries.KIND_ITEM, band = band, id = id }, stub)
    pending[row] = entry
    if stubs then
      stubs[entry] = row
    end
    return row
  end
  local rows = {}
  for _, band in ipairs(Discoveries.BANDS) do
    local bucket = buckets[band]
    if bucket and #bucket > 0 then
      rows[#rows + 1] = Discoveries.HeaderRow(band)
      for _, entry in ipairs(bucket) do
        local row = nil
        local id = tonumber(fieldOf(cols, entry, "id"))
        if not lazy then
          if type(entry) == "number" then
            row = id and Discoveries.RowModel(Discoveries.Entry({ entry }, 1, cols), band, now, opts) or nil
          else
            row = Discoveries.RowModel(entry, band, now, opts)
          end
        elseif id then
          row = stubFor(entry, band, id)
        end
        if row then
          rows[#rows + 1] = row
        end
      end
    end
  end
  return rows
end

--- How many there are and how each of them came to be known. Pure.
function Discoveries.Counts(entries)
  local counts = { total = 0, self = 0, realm = 0, other = 0, data = 0 }
  local cols = columnsOf(entries)
  for _, entry in ipairs(entries or EMPTY) do
    if type(entry) == "table" or (type(entry) == "number" and fieldOf(cols, entry, "id") ~= nil) then
      local source = fieldOf(cols, entry, "source")
      counts.total = counts.total + 1
      if source == Discoveries.SOURCE_SELF then
        counts.self = counts.self + 1
      elseif source == Discoveries.SOURCE_OTHER then
        counts.other = counts.other + 1
      elseif source == Discoveries.SOURCE_DATA then
        counts.data = counts.data + 1
      else
        counts.realm = counts.realm + 1
      end
    end
  end
  return counts
end

--- The entries whose source is the one asked for, in the order they were already in. Nothing,
--- or a source nothing is filed under, is every entry. Always a new list. Pure.
function Discoveries.FilterSource(entries, source)
  if source == nil then
    return Discoveries.Filter(entries, nil)
  end
  local out = listLike(entries)
  local cols = columnsOf(entries)
  for _, entry in ipairs(entries or EMPTY) do
    if (type(entry) == "table" or type(entry) == "number") and fieldOf(cols, entry, "source") == source then
      out[#out + 1] = entry
    end
  end
  return out
end

--- How many of a counted list belong to one source, or the whole list where no source is asked
--- for, which is what the "All" tab carries. Pure, and the one place the tab counts come from.
function Discoveries.SourceCount(counts, source)
  if type(counts) ~= "table" then
    return 0
  end
  if source == nil then
    return tonumber(counts.total) or 0
  end
  return tonumber(counts[source]) or 0
end

--- The line under the list. "6 discovered" for the whole list, "2 of 6 discovered" while the
--- search box or a source tab is narrowing it, because a count of the matches alone would read
--- as the list having shrunk. The breakdown by source is not here: the tabs over the list carry
--- a count each, and saying it twice reads as two different facts. An empty list says nothing:
--- the empty state is already saying it. Pure.
function Discoveries.CountLine(counts, shown)
  if type(counts) ~= "table" then
    return ""
  end
  local total = tonumber(counts.total) or 0
  if total <= 0 then
    return ""
  end
  local visible = tonumber(shown)
  if visible and visible ~= total then
    return string.format(L["%d of %d discovered"], visible, total)
  end
  return string.format(L["%d discovered"], total)
end

--- How many discoveries are newer than the moment the tab was last opened, which is the number
--- in brackets on the tab.
---
--- Only a record of the player's own carries a moment, so only those can be counted against one.
--- What a data build brought counts as unseen until the tab has been opened once and never
--- again: the seen mark is a single number (see MarkSeen), so there is nothing to compare a
--- build's undated entries against a second time. A build that ships new discoveries later
--- therefore does not re-badge the tab, which is the honest cost of keeping the store to one
--- number. Pure.
function Discoveries.UnseenCount(entries, seenAt)
  local at = tonumber(seenAt) or 0
  local count = 0
  local cols = columnsOf(entries)
  for _, entry in ipairs(entries or EMPTY) do
    if type(entry) == "table" or (type(entry) == "number" and fieldOf(cols, entry, "id") ~= nil) then
      local time = tonumber(fieldOf(cols, entry, "time"))
      if time then
        if time > at then
          count = count + 1
        end
      elseif at <= 0 then
        count = count + 1
      end
    end
  end
  return count
end

-- The four kinds of item the four tick boxes sort a list into, in the order the boxes are drawn.
-- A Season of Discovery item is New as well (Diff.IsNew says so), so it is asked about first and
-- takes its own class; New wins over Changed, because an id the baseline could not name has
-- nothing to be changed against.
Discoveries.CLASS_NEW = "new"
Discoveries.CLASS_SOD = "sod"
Discoveries.CLASS_CHANGED = "changed"
Discoveries.CLASS_UNCHANGED = "unchanged"
Discoveries.CLASSES = {
  Discoveries.CLASS_NEW,
  Discoveries.CLASS_SOD,
  Discoveries.CLASS_CHANGED,
  Discoveries.CLASS_UNCHANGED,
}

-- The saved key for each class's box, and the box's default. New and Season of Discovery start
-- on and Changed and Unchanged off, so the tab opens on new content.
Discoveries.FILTER_KEYS = {
  [Discoveries.CLASS_NEW] = Discoveries.SHOW_NEW_KEY,
  [Discoveries.CLASS_SOD] = Discoveries.SHOW_SOD_KEY,
  [Discoveries.CLASS_CHANGED] = Discoveries.SHOW_CHANGED_KEY,
  [Discoveries.CLASS_UNCHANGED] = Discoveries.SHOW_UNCHANGED_KEY,
}
local FILTER_DEFAULTS = {
  [Discoveries.CLASS_NEW] = true,
  [Discoveries.CLASS_SOD] = true,
  [Discoveries.CLASS_CHANGED] = false,
  [Discoveries.CLASS_UNCHANGED] = false,
}

--- What the shipped data says an item is against Classic Era: CLASS_SOD for a new item that
--- came from Season of Discovery (Diff.IsSod), CLASS_NEW for any other id the Era baseline never
--- had (or never named), CLASS_CHANGED for one whose data differs from it, and CLASS_UNCHANGED
--- for the rest. An item whose only changes are minor is CLASS_CHANGED only while the setting
--- includes minor changes (Diff.IsChanged, brief C1). Takes an entry or a row, both of which
--- carry the item id. Asks Core/Diff.lua's own verdicts rather than the badges a row wears,
--- because the window's badge toggles narrow a row's badges and must not narrow the list with
--- them. An id the data cannot judge, a Diff that
--- is absent or a verdict that raises, reads as unchanged. Shipped data only, so a whole list of
--- these costs no client call.
local function classOf(id)
  local Diff = ItemTree.Diff
  if not id or type(Diff) ~= "table" then
    return Discoveries.CLASS_UNCHANGED
  end
  local function says(verdict)
    if type(verdict) ~= "function" then
      return false
    end
    local ok, answer = pcall(verdict, "items", id)
    return ok and answer == true
  end
  if says(Diff.IsSod) then
    return Discoveries.CLASS_SOD
  end
  if says(Diff.IsNew) then
    return Discoveries.CLASS_NEW
  end
  if says(Diff.IsChanged) then
    return Discoveries.CLASS_CHANGED
  end
  return Discoveries.CLASS_UNCHANGED
end

function Discoveries.ChangeClass(entry)
  return classOf(type(entry) == "table" and tonumber(entry.id) or nil)
end

--- Whether the shipped data says an item is new or changed since Classic Era, which is any
--- class but CLASS_UNCHANGED (Discoveries.ChangeClass). Pure but for the shipped data.
function Discoveries.IsChangedSinceEra(entry)
  return Discoveries.ChangeClass(entry) ~= Discoveries.CLASS_UNCHANGED
end

-- A row's class, from the memo where handed one (Discoveries.ChangedMemo) and asked once per
-- entry. Anything in the memo that is not a class is asked again.
-- A position of a built list is asked by its id, and kept in the memo under the position.
local function memoClass(row, memo, cols)
  local function ask()
    if type(row) == "number" then
      return classOf(tonumber(fieldOf(cols, row, "id")))
    end
    return Discoveries.ChangeClass(row)
  end
  if not memo then
    return ask()
  end
  local held = memo[row]
  if type(held) ~= "string" then
    held = ask()
    memo[row] = held
  end
  return held
end

--- The set of classes the boxes keep by default: { new = true, sod = true }. A new table each
--- call, so a caller may change it. Pure.
function Discoveries.DefaultFilters()
  local out = {}
  for _, class in ipairs(Discoveries.CLASSES) do
    if FILTER_DEFAULTS[class] then
      out[class] = true
    end
  end
  return out
end

--- Whether any box is on in a set of shown classes. False for anything that is not a table. Pure.
function Discoveries.AnyFilterOn(shown)
  if type(shown) ~= "table" then
    return false
  end
  for _, class in ipairs(Discoveries.CLASSES) do
    if shown[class] == true then
      return true
    end
  end
  return false
end

--- The list with only the item rows whose class is in shown (a set such as { new = true }), and
--- each band header only where something under it is left, so no band is drawn empty. Takes the
--- rows Discoveries.Rows builds or the entries it builds them from: anything that is not a band
--- header is an item. A shown that is not a table keeps every row. Always a new list, in the
--- order it arrived. memo, where handed one (Discoveries.ChangedMemo), keeps each entry's class so
--- the next draw does not ask again. Pure but for the shipped data ChangeClass reads.
---
---   row kind                   shown when its box is on   default
---   New                        "New"                      on
---   Season of Discovery        "Season of Discovery"      on
---   Changed                    "Changed"                  off
---   Unchanged                  "Unchanged"                off
function Discoveries.ApplyKindFilter(rows, shown, memo)
  local out = listLike(rows)
  local cols = columnsOf(rows)
  local header = nil
  if type(memo) ~= "table" then
    memo = nil
  end
  local every = type(shown) ~= "table"
  for _, row in ipairs(rows or EMPTY) do
    if type(row) == "table" or type(row) == "number" then
      if type(row) == "table" and row.kind == Discoveries.KIND_HEADER then
        header = row
      elseif every or shown[memoClass(row, memo, cols)] == true then
        if header then
          out[#out + 1] = header
          header = nil
        end
        out[#out + 1] = row
      end
    end
  end
  return out
end

--- How many item rows a list of rows carries, band headers left out. Pure.
function Discoveries.ItemCount(rows)
  local count = 0
  for _, row in ipairs(rows or EMPTY) do
    if type(row) == "number" or (type(row) == "table" and row.kind ~= Discoveries.KIND_HEADER) then
      count = count + 1
    end
  end
  return count
end

--- The title and the body of the empty state, in two pieces so neither line runs past the
--- locale file's own width. Pure.
function Discoveries.EmptyTitle()
  return L["Nothing discovered yet"]
end

function Discoveries.EmptyText()
  return L["WoW Forever keeps an item's details back until someone on your realm finds it."]
    .. " "
    .. L["When you come across one, it appears here."]
end

--------------------------------------------------------------------------------
-- Reading the two sources. Still no WoW API: these walk the addon's own tables.
--------------------------------------------------------------------------------

--- The collector's own discovery store, or an empty table. Read through ItemTree rather than
--- held, because the collector is built after this file loads and a spec swaps it out. Its records
--- are packed (brief R3): read each through Discoveries.RecordView or Discoveries.RecordWho.
function Discoveries.Store()
  local collector = ItemTree.collector
  if type(collector) ~= "table" or type(collector.Discoveries) ~= "function" then
    return EMPTY
  end
  local ok, store = pcall(collector.Discoveries, collector)
  if ok and type(store) == "table" then
    return store
  end
  return EMPTY
end

--- The realm id this session is on, as the collector read it (Collector C:RealmId), or nil where
--- there is no collector or it does not know. Only ever compared, never shown.
function Discoveries.CurrentRealm()
  local collector = ItemTree.collector
  if type(collector) ~= "table" or type(collector.RealmId) ~= "function" then
    return nil
  end
  local ok, realm = pcall(collector.RealmId, collector)
  if ok and type(realm) == "number" then
    return realm
  end
  return nil
end

--- The ids this data build newly names, for one diff kind ("items" by default).
---
--- Core/Diff.lua answers with Diff.DiscoveredIds(kind), which is a sorted array of its own and
--- the path this file takes. The generated table is still read directly behind it, for a build
--- of Core whose Diff module predates that accessor or will not answer: the list is what the
--- pane draws, so it is worth two ways of getting it.
function Discoveries.DiscoveredIds(kind)
  kind = type(kind) == "string" and kind or "items"
  local Diff = ItemTree.Diff
  if type(Diff) == "table" and type(Diff.DiscoveredIds) == "function" then
    local ok, ids = pcall(Diff.DiscoveredIds, kind)
    if ok and type(ids) == "table" then
      return ids
    end
  end
  local Data = ItemTree.Data
  if type(Data) ~= "table" or type(Data.GetDiff) ~= "function" then
    return EMPTY
  end
  local ok, diff = pcall(Data.GetDiff, Data)
  if not ok or type(diff) ~= "table" then
    return EMPTY
  end
  local source = diff[kind]
  local ids = type(source) == "table" and source.discovered or nil
  if type(ids) == "table" then
    return ids
  end
  return EMPTY
end

--- The name the collector wrote down for an item, or nil. Core/Graph.lua's names table is read
--- directly: Graph.Name would fall through to the live client for an item the data cannot name,
--- and asking the client about a list of items is the one thing this pane may never do.
function Discoveries.StoredName(itemId)
  local Graph = ItemTree.Graph
  if type(Graph) ~= "table" or type(Graph.names) ~= "table" or type(Graph.Key) ~= "function" then
    return nil
  end
  local ok, key = pcall(Graph.Key, "item", itemId)
  if not ok or type(key) ~= "string" then
    return nil
  end
  local name = Graph.names[key]
  if type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- The build's own record for an item, or nil. One table read, no client call.
--
-- Brief P3: the name, the quality and the icon are all this file reads, so Data:ItemGlance is
-- asked first. It answers them from the Names module, so a list of four thousand ids never builds
-- an Items table; it answers nil for anything Data:GetItem would answer as a stub (a withheld id,
-- a harvested item the setting hides), and Data:GetItem is asked for those, as before.
local function dataItem(id)
  local Data = ItemTree.Data
  if type(Data) ~= "table" then
    return nil
  end
  if type(Data.ItemGlance) == "function" then
    local ok, glance = pcall(Data.ItemGlance, Data, id)
    if ok and type(glance) == "table" then
      return { n = glance.name, q = glance.quality, i = glance.icon }
    end
  end
  if type(Data.GetItem) ~= "function" then
    return nil
  end
  local ok, found = pcall(Data.GetItem, Data, id)
  if ok and type(found) == "table" then
    return found
  end
  return nil
end

-- The name the build, the collector's notes or the neutral placeholder give an item, in that
-- order, or nil where none of them will.
local function nameOf(id, item)
  if item and type(item.n) == "string" and item.n ~= "" then
    return item.n
  end
  local name = Discoveries.StoredName(id)
  if name then
    return name
  end
  if item and item.u then
    local Graph = ItemTree.Graph
    if type(Graph) == "table" and type(Graph.UndiscoveredName) == "function" then
      local ok, placeholder = pcall(Graph.UndiscoveredName, item)
      if ok and type(placeholder) == "string" and placeholder ~= "" then
        return placeholder
      end
    end
  end
  return nil
end

--- What an item is called, and nothing else: the build's name, the collector's note or the
--- neutral placeholder, as Discoveries.ItemFacts answers it. Discoveries.Entries reads this for
--- every id the build names, because the search box and the placeholder test need a name up
--- front; the icon and the quality wait until a row is drawn.
function Discoveries.ItemName(itemId)
  local id = tonumber(itemId)
  if not id then
    return nil
  end
  return nameOf(id, dataItem(id))
end

--- What the shipped data and the collector's own notes say about an item: its name, its quality
--- and its icon. The client is never asked. An id the build withholds and nothing has named
--- falls back to the neutral placeholder Core/Graph.lua builds from the build's own Item row
--- ("Undiscovered mail chest"), which states a slot and never a name.
function Discoveries.ItemFacts(itemId)
  local id = tonumber(itemId)
  local facts = { id = id }
  if not id then
    return facts
  end
  local item = dataItem(id)
  if item then
    facts.quality = tonumber(item.q)
    facts.icon = item.i
  end
  facts.name = nameOf(id, item)
  return facts
end

--- The moment the shipped data says a build's entry was discovered, or nil, which is every
--- entry today: Core/Diff.lua's Diff.DiscoveredAt, read guarded. Pure but for the shipped data.
function Discoveries.DataTime(itemId)
  local Diff = ItemTree.Diff
  if type(Diff) ~= "table" or type(Diff.DiscoveredAt) ~= "function" then
    return nil
  end
  local ok, at = pcall(Diff.DiscoveredAt, "items", itemId)
  if ok then
    return tonumber(at)
  end
  return nil
end

-- The icon and the quality of an entry the list may never draw are filled the first time an
-- entry is made for it: the pane makes one only for a row it draws (Discoveries.Rows with
-- opts.lazy), so a list of five thousand asks the shipped data about the rows on screen and no
-- more.
-- Brief P4: kept in the list's columns once asked, so a row the pane draws again asks nothing.
local function fillFacts(cols, pos)
  if cols.looked[pos] then
    return
  end
  cols.looked[pos] = true
  if cols.icon[pos] ~= nil and cols.quality[pos] ~= nil then
    return
  end
  local ok, facts = pcall(Discoveries.ItemFacts, cols.id[pos])
  if ok and type(facts) == "table" then
    if cols.icon[pos] == nil then
      cols.icon[pos] = facts.icon
    end
    if cols.quality[pos] == nil then
      cols.quality[pos] = tonumber(facts.quality)
    end
  end
end

--- One element of a list as an entry table, the shape the list held before brief P4: { id, name,
--- quality, icon, time, source, via, character, build }, each field only where the entry has
--- it. A table element is handed back as it is. A position is made into a new table each time,
--- with its icon and quality filled from the shipped data (kept in the columns after the first
--- time). cols is the columns to read, and defaults to the list's own. nil past the end. Pure but
--- for the shipped data.
function Discoveries.Entry(list, index, cols)
  local element = type(list) == "table" and list[index] or nil
  if type(element) ~= "number" then
    return element
  end
  cols = cols or columnsOf(list)
  if not cols or cols.id[element] == nil then
    return nil
  end
  fillFacts(cols, element)
  local entry = {}
  for _, field in ipairs(ENTRY_FIELDS) do
    entry[field] = cols[field][element]
  end
  return entry
end

--- The whole list as entry tables (Discoveries.Entry for each), for a caller that walks every
--- field of every entry: the specs. The pane never asks for this. Pure but for the shipped data.
function Discoveries.Realise(list)
  local out = {}
  local cols = columnsOf(list)
  for index = 1, #(list or EMPTY) do
    out[#out + 1] = Discoveries.Entry(list, index, cols)
  end
  return out
end

--- Brief DV1: the list without the items no player can ever get (Data:IsHidden), whichever
--- source brought them. Run once per build of the list, behind the cache, so the rows, the
--- unread count, the tab bubble and the Show box counts are all read from a list that has none,
--- and a draw pays nothing for it. One table read per entry; the list is filtered in place.
function Discoveries.DropUnobtainable(entries)
  local Data = ItemTree.Data
  if type(entries) ~= "table" or type(Data) ~= "table" or type(Data.DevSet) ~= "function" then
    return entries
  end
  local ok, dev = pcall(Data.DevSet, Data)
  if not ok or type(dev) ~= "table" or next(dev) == nil then
    return entries
  end
  local kept = 0
  local cols = columnsOf(entries)
  for index = 1, #entries do
    local entry = entries[index]
    local id = nil
    if type(entry) == "table" then
      id = tonumber(rawget(entry, "id"))
    elseif type(entry) == "number" then
      id = tonumber(fieldOf(cols, entry, "id"))
    end
    if not (id and dev[id]) then
      kept = kept + 1
      entries[kept] = entry
    end
  end
  for index = #entries, kept + 1, -1 do
    entries[index] = nil
  end
  return entries
end

--- The whole list, built from nothing: every source read, merged, newest first. Discoveries.Entries
--- is the cached way in and the one the pane takes; this is what it calls when the cache is stale.
---
--- Brief P4: the answer is a list of positions in a set of columns (see listColumns at the top),
--- built straight from the sources: the player's records (a few hundred at most) are read as
--- entries and copied in, the build's ids are named one by one and the miner's records go in as
--- they are read, so no entry table is made for either. The merge is Discoveries.Merge's own
--- (mergeLists), over positions. The icon and the quality are left until an entry is made for a
--- row (fillFacts), so building the list asks the shipped data for a name per id and nothing more.
function Discoveries.BuildEntries()
  local realm = Discoveries.CurrentRealm()
  local cols = newColumns()
  local player = {}
  for _, entry in ipairs(Discoveries.PlayerEntries(Discoveries.Store(), realm)) do
    player[#player + 1] = addRow(
      cols,
      entry.id,
      entry.name,
      entry.source,
      entry.time,
      entry.quality,
      nil,
      nil,
      entry.character,
      entry.build
    )
  end
  -- The build's own, by id, as Discoveries.DataEntries answers them: one name each, and a
  -- developer placeholder name dropped here and nowhere else.
  local data, seen = {}, {}
  for _, value in ipairs(Discoveries.DiscoveredIds("items")) do
    local id = tonumber(value)
    if id and not seen[id] then
      seen[id] = true
      local ok, name = pcall(Discoveries.ItemName, id)
      if not ok or type(name) ~= "string" or name == "" then
        name = nil
      end
      if not Discoveries.IsNoiseName(name) then
        data[#data + 1] = addRow(cols, id, name, Discoveries.SOURCE_DATA, Discoveries.DataTime(id))
      end
    end
  end
  table.sort(data, function(a, b)
    return cols.id[a] < cols.id[b]
  end)
  local db = Discoveries.MinerStore()
  local miner = nil
  if db ~= nil then
    -- The miner's own icon first: an item that was undiscovered when the data was built has no
    -- icon in it, and the miner read the file id off the find. The shipped data is the fallback.
    miner = {}
    eachMinerRecord(db, Discoveries.MinerClock(), realm, function(id, name, quality, icon, at, source)
      miner[#miner + 1] = addRow(cols, id, name, source, at, quality, icon, "miner")
    end)
    table.sort(miner, function(a, b)
      return newer(cols.id[a], cols.time[a], cols.id[b], cols.time[b])
    end)
  end
  local list = mergeLists(cols, player, data, miner)
  listColumns[list] = cols
  return Discoveries.DropUnobtainable(list)
end

--------------------------------------------------------------------------------
-- The cache over the whole list
--
-- Discoveries.Entries is asked on every draw, every settled keystroke in the search box and
-- every time the window counts the bubble over the tab, and the answer only changes when one of
-- its sources does. The key is everything the answer is read from, each part cheap to read:
--
--   collector, store   the collector and its discovery store, by identity: a new collector (a
--                      /reload, another realm's session) is a new list
--   records, selves    how many records the store holds and how many say "self": a record added
--                      moves the first, a record promoted to "self" (UpgradeDiscovery) the second
--   realm, away        the realm id this session is on, and how many records carry another
--                      one: a record met again on this realm (UpgradeDiscovery) moves the second
--   data, generation   Core/Data.lua by identity and Data.generation, which Data:Reset bumps
--   discovered, dated  the diff's discovered array and its discoveredAt map, by identity
--   diff               Core/Diff.lua by identity
--   includeMinor       whether minor changes count (Diff.IncludeMinor, brief C1), which moves
--                      an item between the Changed and Unchanged boxes and so every count
--   miner, seen, found the miner's store and its seen table by identity, and store.counts.found,
--                      which the miner moves on every find
--
-- Brief OPT3 (F12): records, selves and away are only walked out of the store again when the
-- collector's write counter (Collector.generation, which every record written, upgraded or dropped
-- bumps), the store or the realm has moved since the last walk; a quiet refresh reads them back
-- instead of parsing every record. The counter is not a field of the key itself: a sighting bumps
-- it without adding a discovery, and the list must hold across that, so it only guards the walk.
--
-- Anything else (a name the collector writes into the graph, the miner rewriting a record in
-- place without counting it) is picked up on the next change of the key, or at once through
-- Discoveries.Invalidate.
--------------------------------------------------------------------------------

Discoveries.CACHE_KEY_FIELDS = {
  "collector",
  "store",
  "records",
  "selves",
  "realm",
  "away",
  "data",
  "generation",
  "discovered",
  "dated",
  "diff",
  "miner",
  "seen",
  "found",
  "includeMinor",
}

-- Brief OPT3 (F12): the counts the last walk of the store worked out, and what they were worked
-- out against (the store by identity, the realm, the collector's write counter). Kept apart from
-- the list's cache, so Discoveries.Invalidate leaves it be: it holds what the store says, not what
-- was built from it.
local storeCounts = { store = nil, realm = nil, writes = nil, records = 0, selves = 0, away = 0 }

--- The collector's write counter (Core/Collector.lua Collector.generation), or nil where there is
--- no collector module to read it from. Read through ItemTree, the way Discoveries.Store reaches
--- the collector.
function Discoveries.CollectorWrites()
  local Collector = ItemTree.Collector
  if type(Collector) ~= "table" then
    return nil
  end
  return tonumber(rawget(Collector, "generation"))
end

--- Drops the remembered store counts, so the next Discoveries.CacheKey walks the store again.
function Discoveries.ForgetStoreCounts()
  storeCounts.store, storeCounts.realm, storeCounts.writes = nil, nil, nil
end

--- The cache key as it stands now: a table of the fields CACHE_KEY_FIELDS names. Reads tables
--- and nothing else; the collector's store is walked for its two counts, which is a pass over
--- the player's own records and never over the build's list.
function Discoveries.CacheKey()
  local key = {}
  key.collector = ItemTree.collector
  local store = Discoveries.Store()
  key.store = store
  local realm = Discoveries.CurrentRealm()
  local writes = Discoveries.CollectorWrites()
  local records, selves, away
  if writes ~= nil and storeCounts.writes == writes and storeCounts.store == store and storeCounts.realm == realm then
    records, selves, away = storeCounts.records, storeCounts.selves, storeCounts.away
  else
    records, selves, away = 0, 0, 0
    for _, held in pairs(store) do
      if type(held) == "table" or type(held) == "string" then
        records = records + 1
        local h, heldRealm = Discoveries.RecordWho(held)
        if h == Discoveries.SOURCE_SELF then
          selves = selves + 1
        elseif Discoveries.RealmSource(heldRealm, realm) == Discoveries.SOURCE_OTHER then
          away = away + 1
        end
      end
    end
    storeCounts.store, storeCounts.realm, storeCounts.writes = store, realm, writes
    storeCounts.records, storeCounts.selves, storeCounts.away = records, selves, away
  end
  key.records, key.selves = records, selves
  key.realm, key.away = realm, away
  local Data = ItemTree.Data
  key.data = Data
  if type(Data) == "table" then
    key.generation = tonumber(rawget(Data, "generation"))
    if type(Data.GetDiff) == "function" then
      local ok, diff = pcall(Data.GetDiff, Data)
      local items = ok and type(diff) == "table" and diff.items or nil
      if type(items) == "table" then
        key.discovered = items.discovered
        key.dated = items.discoveredAt
      end
    end
  end
  key.diff = ItemTree.Diff
  key.includeMinor = false
  local Diff = ItemTree.Diff
  if type(Diff) == "table" and type(Diff.IncludeMinor) == "function" then
    local ok, include = pcall(Diff.IncludeMinor)
    key.includeMinor = ok and include == true
  end
  local db = Discoveries.MinerStore()
  key.miner = db
  if db then
    local ok, seen = pcall(rawget, db, "seen")
    key.seen = ok and seen or nil
    key.found = Discoveries.MinerFound(db)
  end
  return key
end

--- Whether two cache keys are the same key. Pure.
function Discoveries.SameKey(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return false
  end
  for _, field in ipairs(Discoveries.CACHE_KEY_FIELDS) do
    if a[field] ~= b[field] then
      return false
    end
  end
  return true
end

--- Drops the cached list, so the next Discoveries.Entries builds it again.
function Discoveries.Invalidate()
  cache.key, cache.entries, cache.cols, cache.changed, cache.stubs = nil, nil, nil, nil, nil
end

--- How many times the list has been built. The pane keys what it derives from the list on this,
--- and the specs read it to prove a draw did not build anything.
function Discoveries.CacheVersion()
  return cache.version
end

--- The whole list the pane draws: every source, merged, newest first, from the cache while its
--- key holds and built again (Discoveries.BuildEntries) when it does not. The same list is handed
--- back each time, so a caller narrows it into a list of its own and never writes to it.
function Discoveries.Entries()
  local key = Discoveries.CacheKey()
  if cache.entries and Discoveries.SameKey(cache.key, key) then
    return cache.entries
  end
  local entries = Discoveries.BuildEntries()
  cache.key, cache.entries, cache.changed = key, entries, setmetatable({}, { __mode = "k" })
  cache.cols = listColumns[entries]
  cache.stubs = nil
  cache.version = cache.version + 1
  return entries
end

--- Brief P2 (#8): the memo Discoveries.Rows keeps its lazy stubs in for the cached list, as
--- opts.stubs. Dropped with the list, so a bumped CacheVersion starts with no stubs at all.
function Discoveries.StubMemo()
  if not cache.stubs then
    cache.stubs = {}
  end
  return cache.stubs
end

--- The memo Discoveries.ApplyKindFilter keeps its answers in for the cached list: one class
--- (Discoveries.ChangeClass) per entry, dropped with the list. Weak keyed.
function Discoveries.ChangedMemo()
  if not cache.changed then
    cache.changed = setmetatable({}, { __mode = "k" })
  end
  return cache.changed
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--
-- The Discovery Miner's saved global. rawget, so an absent global is one table read and no
-- lookup through any metatable _G carries. Nothing here asks the client about an item.
--------------------------------------------------------------------------------

--- The miner's store (DiscoveryMinerDB.store), or nil where the miner is not installed (every
--- player but the owner) or its saved table carries no store. Nothing else is looked up when
--- the global is nil.
function Discoveries.MinerStore()
  local ok, db = pcall(rawget, _G, "DiscoveryMinerDB")
  if not ok or type(db) ~= "table" then
    return nil
  end
  -- The saved table is { v, settings, store = { seen, counts, cold, ... }, resume }: the records
  -- and the counter are one level down, in store (DiscoveryMiner/Core/Init.lua, where
  -- DiscoveryMiner.db.store = Store.Ensure(...)). A table with seen at the top is not the miner's.
  local okStore, store = pcall(rawget, db, "store")
  if okStore and type(store) == "table" then
    return store
  end
  return nil
end

--- The miner's running count of finds (store.counts.found), one number, or nil where there is
--- no such number. This is what the pane watches: it moves on every find, so reading it is how
--- the pane tells a new find without walking the whole store. Every read pcalled.
function Discoveries.MinerFound(db)
  if type(db) ~= "table" then
    return nil
  end
  local ok, found = pcall(function()
    local counts = rawget(db, "counts")
    if type(counts) ~= "table" then
      return nil
    end
    return rawget(counts, "found")
  end)
  if ok and type(found) == "number" then
    return found
  end
  return nil
end

--- The clock Discoveries.MinerEntries judges a time against: the client's time(), or the
--- standard library's under a spec, or nil, which reads every time as fine.
function Discoveries.MinerClock()
  local clocks = { rawget(_G, "time") }
  local standard = rawget(_G, "os")
  if type(standard) == "table" then
    clocks[#clocks + 1] = rawget(standard, "time")
  end
  for _, clock in ipairs(clocks) do
    if type(clock) == "function" then
      local ok, value = pcall(clock)
      if ok and type(value) == "number" then
        return value
      end
    end
  end
  return nil
end

--------------------------------------------------------------------------------
-- When the tab was last opened, and which kinds of row its four boxes show
--------------------------------------------------------------------------------

-- Account wide, in ItemTree.db, because the discoveries it is counted against are account wide:
-- the collector's store is, and so is a data build. A character table is taken only where there
-- is no account one. The value is a timestamp and nothing else, so no character, realm or
-- account fact can reach saved variables through it.
local function seenStore()
  if type(ItemTree.db) == "table" then
    return ItemTree.db
  end
  if type(ItemTree.charDb) == "table" then
    return ItemTree.charDb
  end
  return nil
end

--- Whether the box for a class is on. A saved boolean is the player's choice and wins; anything
--- else, a missing value above all, reads as the box's default. So New and Season of Discovery
--- read as on for a player who never touched them, including one whose saved table predates the
--- four boxes, and Changed and Unchanged read as off. With nowhere to read from, the default.
--- False for a class that has no box.
function Discoveries.ShowKind(class)
  local key = Discoveries.FILTER_KEYS[class]
  if not key then
    return false
  end
  local store = seenStore()
  local value = store and store[key]
  if type(value) == "boolean" then
    return value
  end
  return FILTER_DEFAULTS[class] == true
end

--- Writes a box down, as a boolean and nothing else. Returns what was stored, or nil where there
--- was nowhere to put it or the class has no box.
function Discoveries.SetShowKind(class, show)
  local key = Discoveries.FILTER_KEYS[class]
  local store = seenStore()
  if not key or not store then
    return nil
  end
  local value = false
  if show then
    value = true
  end
  store[key] = value
  return value
end

--- The set of classes the four boxes keep now, in the shape ApplyKindFilter takes.
function Discoveries.ShownKinds()
  local out = {}
  for _, class in ipairs(Discoveries.CLASSES) do
    if Discoveries.ShowKind(class) then
      out[class] = true
    end
  end
  return out
end

--- Puts the four boxes back to their defaults, written down as booleans. Returns the set now
--- shown, or nil where there was nowhere to write.
function Discoveries.ResetFilters()
  if not seenStore() then
    return nil
  end
  for _, class in ipairs(Discoveries.CLASSES) do
    Discoveries.SetShowKind(class, FILTER_DEFAULTS[class])
  end
  return Discoveries.ShownKinds()
end

--- The moment the tab was last opened, or 0 where it never has been.
function Discoveries.SeenAt()
  local store = seenStore()
  if not store then
    return 0
  end
  return tonumber(store[Discoveries.SEEN_KEY]) or 0
end

--- Writes that moment down. Returns the number stored, or nil where there was nowhere to put it
--- or nothing to put there.
function Discoveries.MarkSeen(now)
  local at = tonumber(now)
  local store = seenStore()
  if not at or not store then
    return nil
  end
  store[Discoveries.SEEN_KEY] = at
  return at
end

return Discoveries
