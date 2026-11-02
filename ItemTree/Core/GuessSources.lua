-- Guessed sources: the shipped GuessSources module, read one item at a time and turned into
-- edges on that item's own node. Pure Lua, no WoW API. Loaded as: local _, ItemTree = ...
--
-- Brief GS2 (guesses-in-sources-plan.md sections 1, 2, 4 and 5). ItemTree's model guesses where
-- an item with no known source probably comes from: the kind of source, the place and the specific
-- creature, vendor, quest or container. The pipeline ships only the Strong and Likely top guesses
-- the build does not already answer, in one packed string sorted by item id, and this file finds
-- one item's record by binary search. Nothing here walks the module, nothing is decoded until an
-- item is asked for, and nothing at all is read at login, in a tooltip or for a bag badge.
--
-- A guess is never a data row of its own. Every edge this file answers is:
--   * Confidence.GUESS, the tier below every other, so it sorts last in its category;
--   * stamped with the provenance "guess" and the basis Confidence.BASIS_GUESS;
--   * carrying guess = { level, strength, why, whyWords, area }, which Core/Graph.lua drops from
--     every walk that did not ask for guesses (opts.includeGuessSources) and weighs against the real
--     edges beside it (Graph.DropGuessEdges), so a real source always replaces a guess.
--
-- The provider answers only an item key walking up, and it is registered guessOnly, so Graph asks
-- it only for a walk that set opts.includeGuessSources. Only the Sources view's walk of its own root
-- does, so a guess never adds a chevron, never lands under a nested row and never costs a lookup
-- per drawn row. It is predictedOnly too, so Graph.Summary (tooltips, the info column counts, the
-- bag overlay) never asks it.
--
-- The contract (the pipeline's docs/guesses.md, "Shipped guess sources"):
--
--   { meta = { schema = 1, build, baseline, generated, eraGenerated, width = 18, count,
--              why = { strategy ids } },
--     r = one packed string of fixed width records, sorted by item id,
--     s = { names: instances, factions, and zones the Classic Era table does not name },
--     z = { [areaId] = index into s }   (optional: a zone the Era table does not name),
--     n = { [creatureId] = index into s }   (optional: a creature new in Forever, brief GS5),
--     m = { [itemId] = packed second specific },
--     o = { { index into s or 0, x, y } } }   (optional: placed objects, brief M14)
--
-- A record is 18 base 91 digits in the EraSources alphabet (bytes 35 to 126 without 92, most
-- significant first):
--
--   1 to 3    item id
--   4         kind code * 3 + strength (0 when none)
--   5         kind why
--   6         place type * 3 + strength (1 instance, 2 zone, 3 faction; 0 when none)
--   7 to 9    place ref: an area id (zone), or an index into s (instance, faction)
--   10        place why
--   11        specific type * 3 + strength (1 creature, 2 vendor, 3 quest, 4 item, 5 new
--             creature, 6 placed object; 0 when none)
--   12 to 14  specific ref: a Classic Era creature id (creature, vendor: the CMaNGOS id EraSources.lua's
--             ci states for the name, brief EK2), a quest id, an item id, a creature id (new
--             creature) or a 1 based index into o (placed object)
--   15        specific why
--   16 to 18  the area the specific stands in (0 when unknown)
--
-- A strength is 1 Strong or 2 Likely; a field whose remainder is 0 carries nothing. A why is a
-- 1 based index into meta.why, 0 for none. m[itemId] is bytes 11 to 18 of a record again (8
-- digits): a second specific of the same type.
--
-- A creature or vendor is named by the CMaNGOS creature id the Classic Era table states for its
-- name (ci; until brief EK2 it was the name's index into the table's strings), so this module
-- carries no creature text: the name and the page come back through the Era table
-- (EraSources.CreatureNameIndex, then EraSources.CreatureNode). meta.eraGenerated must still equal
-- that table's stamp, or nothing here answers anything.
--
-- Brief GS5: a creature new in WoW Forever has no Classic Era string, so specific type 5 names it
-- by its creature id and the module's own n table gives the name (an index into s, shared with z).
-- Its edge points at the creature's own node (npc:<creature id>), the node a creature page opens.
-- A type 5 whose id n does not name draws no row of its own: the record's place row stands, and no
-- raw id is ever put in front of a player. The Boss loot tab asks the other way round (which items
-- are guessed to drop from this creature), which R:ItemsForCreature answers from one pass over the
-- specifics, made the first time a boss with a creature id is opened and kept with the module.
--
-- Brief M14: specific type 6 is a placed object, a world object the player opens (a bookshelf, a
-- pile of scrolls) at one spot on a zone map. Its ref indexes the module's o, whose entry is
-- { name, x, y }: name indexes s (0 where the object ships unnamed), x and y are tenths of a percent
-- on the map of the zone the specific's area names. The row reads "Contained in <name>" (or "Contained
-- in an object") with the zone and the coordinates, and the item page carries each spot as a Where
-- line with the Set waypoint button (UI/InfoPanel.lua InfoPanel.PlacedSection). A second spot sits
-- in m like any second specific.
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

local GuessSources = {}
ItemTree.GuessSources = GuessSources

GuessSources.MODULE = "GuessSources"
GuessSources.PROVENANCE = "guess"
GuessSources.SCHEMA = 1
GuessSources.WIDTH = 18

-- The word the tier is called by, for the rate column and the badge (brief GS3).
GuessSources.LABEL = L["Guess"]

-- The digits each field takes, in record order.
local ITEM_DIGITS = 3
local REF_DIGITS = 3
local AREA_DIGITS = 3
-- The second specific: type and strength, ref, why, area.
GuessSources.SECOND_WIDTH = 1 + REF_DIGITS + 1 + AREA_DIGITS

GuessSources.STRONG, GuessSources.LIKELY = 1, 2

-- The model's thirteen source kinds, by code, in the pipeline's order. Each names the edge type a
-- guess of that kind is drawn as, the category it is filed under (the one the same kind of real
-- source already files under) and the node a guess that names no source points at. Crafted and
-- the three facets (holiday, starts a quest, token) never ship, so they have no entry and a record
-- that names one is read as carrying no kind.
GuessSources.KINDS = {
  [1] = { word = "boss_drop", edge = "DROPPED_BY", node = "creature" },
  [2] = { word = "creature_drop", edge = "DROPPED_BY", node = "creature" },
  [3] = { word = "world_drop", edge = "DROPPED_BY", node = "world" },
  [4] = { word = "vendor", edge = "SOLD_BY", node = "vendor" },
  [5] = { word = "rep_vendor", edge = "SOLD_BY", node = "vendor" },
  [6] = { word = "quest_reward", edge = "QUEST_REWARD", node = "quest" },
  [8] = { word = "container", edge = "CONTAINED_IN", node = "container" },
  [9] = { word = "gathered", edge = "GATHERED_FROM", node = "gathered" },
  [10] = { word = "pvp", edge = "SOLD_BY", node = "vendor" },
}

-- The place types, by code.
GuessSources.PLACES = { [1] = "instance", [2] = "zone", [3] = "faction" }

-- The specific types, by code: the edge type, and the node kind the ref is a key of.
GuessSources.SPECIFICS = {
  [1] = { word = "creature", edge = "DROPPED_BY", kind = "npc" },
  [2] = { word = "vendor", edge = "SOLD_BY", kind = "npc" },
  [3] = { word = "quest", edge = "QUEST_REWARD", kind = "quest" },
  [4] = { word = "item", edge = "CONTAINED_IN", kind = "item" },
  -- Brief GS5: a creature new in Forever, keyed by its creature id and named by the module's n.
  [5] = { word = "creature", edge = "DROPPED_BY", kind = "npc", byId = true },
  -- Brief M14: an object placed in the world, named and placed by the module's o.
  [6] = { word = "object", edge = "CONTAINED_IN", kind = "object", placed = true },
}

-- The specific type of a placed object (brief M14).
GuessSources.PLACED_OBJECT = 6

-- The specific type of a creature new in Forever, and of a Classic Era creature (brief GS5b).
GuessSources.NEW_CREATURE = 5
GuessSources.ERA_CREATURE = 1

-- The group each edge type files under: the category the same kind of real source is drawn in.
local GROUPS = {
  DROPPED_BY = L["Drops from"],
  SOLD_BY = L["Sold by"],
  QUEST_REWARD = L["Quests"],
  CONTAINED_IN = L["Contained in"],
  GATHERED_FROM = L["Gathered from"],
}

-- The node a guess that names no source points at, one per kind of node. It is a row that
-- stands for a group and names nothing, the way the Classic Era world drop is (a summary with
-- nothing listed behind it), so the Sources view draws it as a plain row that never re-roots.
-- The ids sit far below every range Core/EraSources.lua makes, at a multiple of its name span,
-- so its own id arithmetic reads none of them as one of its nodes. A world drop guess points at
-- the Era world drop node itself (npc:0), which is the same fact about the same "somewhere".
local NODE_BASE = 9000000000000
local NODE_SPAN = 10000
GuessSources.NODES = {
  creature = { kind = "npc", slot = 1, name = L["Unknown creature"] },
  vendor = { kind = "npc", slot = 2, name = L["Unknown vendor"] },
  quest = { kind = "quest", slot = 3, name = L["Unknown quest"] },
  container = { kind = "object", slot = 4, name = L["Unknown container"] },
  gathered = { kind = "object", slot = 5, name = L["Unknown node"] },
  world = { key = "npc:0", name = L["World drop"] },
}

--- The key of the node a guess of one node kind points at ("creature", "vendor"...), or nil.
function GuessSources.NodeKey(node)
  local spec = GuessSources.NODES[node]
  if not spec then
    return nil
  end
  if spec.key then
    return spec.key
  end
  return Graph.Key(spec.kind, -(NODE_BASE + spec.slot * NODE_SPAN))
end

-- Brief M14: the node one placed object's row points at, one per entry of o, so two spots are two
-- rows and never merge into one. The range sits a million above the nodes above, far past their
-- five slots, and far below every range Core/EraSources.lua makes.
local PLACED_BASE = NODE_BASE + 1000000

--- The key of the node a placed object (an index into o) points at, or nil for no index.
function GuessSources.PlacedKey(ref)
  if type(ref) ~= "number" or ref < 1 or ref ~= math.floor(ref) then
    return nil
  end
  return Graph.Key("object", -(PLACED_BASE + ref))
end

--- Whether a key is one of those nodes. Pure arithmetic over the key.
function GuessSources.IsNodeKey(key)
  local kind, id = Graph.Parse(key)
  if not kind or not id or id > -NODE_BASE then
    return false
  end
  for _, spec in pairs(GuessSources.NODES) do
    if spec.kind == kind and id == -(NODE_BASE + spec.slot * NODE_SPAN) then
      return true
    end
  end
  return false
end

-- The short name of each strategy a guess can be led by, keyed by strategy id: the words the
-- developer tab and the pipeline review page use (brief GU1), less the two that carry a Classic
-- Era source over, which never ship. meta.why lists the ids the module's why codes index; a code
-- whose id is not here has no words, and the row says nothing about why. Owner ruling
-- 2026-09-29: a shipped guess never says where a claim came from, so the pipeline's run G21
-- strategy (C1, a claim somebody published) has no words here, and nor does any other strategy
-- whose short name would name a site, a guide, the community, a claim or a comment.
GuessSources.WHY_WORDS = {
  A3 = L["Name family"],
  B5 = L["Made by a spell"],
  B6 = L["Starts a quest"],
  B7 = L["Reputation requirement"],
  B8 = L["PvP or holiday requirement"],
  B9 = L["Zone or instance bound"],
  B10 = L["Lockbox or quest item"],
  B11 = L["Shared limit category"],
  B12 = L["Recipe rank"],
  C13 = L["Item set mates"],
  C14 = L["Transmog set mates"],
  C15 = L["Nearby item ids"],
  D16 = L["Shared appearance"],
  D17 = L["Shared icon"],
  D18 = L["Nearby display ids"],
  D19 = L["Icon twin"],
  E19 = L["Level and type patterns"],
  E20 = L["New zones by level"],
  E21 = L["Price signals"],
  F23 = L["Name words"],
  F24 = L["Icon name words"],
  ["F24-hint"] = L["Icon name hints"],
  F25 = L["Spells with the same icon"],
  G24 = L["Found at the same time"],
  G26 = L["Quest cache"],
  G27 = L["Creature and object caches"],
  H29 = L["Price lists"],
  ["H-creature"] = L["Shown on a creature"],
  ["H-criteria"] = L["Boss or achievement criteria"],
  ["H-cost"] = L["Used as a currency"],
  ["H-transmog"] = L["Transmog siblings"],
  P1 = L["Linked items"],
  R1 = L["Race requirement"],
  V1 = L["PvP rank rewards"],
}

-- The base 91 alphabet Core/EraSources.lua decodes: the printable bytes 35 to 126, 92 left out.
local PACK_BASE = 91
local PACK_FIRST = 35
local PACK_SKIPPED = 92

-- One packed field, or nil for bytes that are not ours.
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

--- Where one item's record starts in the packed string, by binary search, or nil. Pure: r is the
--- string, width the record width. At most 13 probes of 3 bytes each over 4,185 records, and
--- nothing else is read.
function GuessSources.Find(r, width, itemId)
  if type(r) ~= "string" or type(width) ~= "number" or width < ITEM_DIGITS or type(itemId) ~= "number" then
    return nil
  end
  local lo, hi = 1, math.floor(#r / width)
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    local at = (mid - 1) * width + 1
    local id = packedInt(r, at, ITEM_DIGITS)
    if not id then
      return nil
    end
    if id == itemId then
      return at
    end
    if id < itemId then
      lo = mid + 1
    else
      hi = mid - 1
    end
  end
  return nil
end

-- A code times 3 plus a strength, read back: the code and the strength, or nil for a field that
-- carries nothing (0, or a remainder that is no strength).
local function codeAndStrength(value)
  if type(value) ~= "number" then
    return nil
  end
  local strength = value % 3
  local code = math.floor(value / 3)
  if strength == 0 or code < 1 then
    return nil
  end
  return code, strength
end

-- A why code, or nil for 0.
local function whyCode(value)
  if type(value) ~= "number" or value < 1 then
    return nil
  end
  return value
end

-- A specific out of its 8 digits at one place in a string, or nil.
local function decodeSpecific(text, at)
  local code, strength = codeAndStrength(packedInt(text, at, 1))
  if not code then
    return nil
  end
  local ref = packedInt(text, at + 1, REF_DIGITS)
  local why = packedInt(text, at + 1 + REF_DIGITS, 1)
  local area = packedInt(text, at + 2 + REF_DIGITS, AREA_DIGITS)
  if not ref or not why or not area then
    return nil
  end
  return {
    type = code,
    strength = strength,
    ref = ref,
    why = whyCode(why),
    area = area > 0 and area or nil,
  }
end

--- One record, decoded: { item, kind = { code, strength, why }, place = { type, strength, ref,
--- why }, specific = { type, strength, ref, why, area } }, each part nil where the record carries
--- none, or nil for a record that is not one. Pure.
function GuessSources.Decode(record)
  if type(record) ~= "string" or #record < GuessSources.WIDTH then
    return nil
  end
  local item = packedInt(record, 1, ITEM_DIGITS)
  if not item then
    return nil
  end
  local out = { item = item }
  local kind, kindStrength = codeAndStrength(packedInt(record, 4, 1))
  local kindWhy = packedInt(record, 5, 1)
  if kind then
    out.kind = { code = kind, strength = kindStrength, why = whyCode(kindWhy) }
  end
  local place, placeStrength = codeAndStrength(packedInt(record, 6, 1))
  local placeRef = packedInt(record, 7, REF_DIGITS)
  local placeWhy = packedInt(record, 10, 1)
  if place and placeRef and placeRef > 0 then
    out.place = { type = place, strength = placeStrength, ref = placeRef, why = whyCode(placeWhy) }
  end
  out.specific = decodeSpecific(record, 11)
  return out
end

--- A second specific out of the side table's packed string, or nil. Pure.
function GuessSources.DecodeSecond(text)
  if type(text) ~= "string" or #text < GuessSources.SECOND_WIDTH then
    return nil
  end
  return decodeSpecific(text, 1)
end

--- The Classic Era table's own stamp, which meta.eraGenerated must equal: its g field, the
--- compile's Generated stamp (brief E85, Core/EraSources.lua EraSources.Generated). nil where the
--- table states none, which is every table compiled before the stamp. Pure.
function GuessSources.EraStamp(era)
  if type(era) ~= "table" then
    return nil
  end
  local stamp = era.g
  if type(stamp) ~= "string" or stamp == "" then
    return nil
  end
  return stamp
end

--- Why a module cannot be read against an Era table, or nil when it can. Only the shape and the
--- stamp are checked; the counts are whatever the module says, so a new compile needs nothing
--- here changed. Pure.
function GuessSources.Refusal(source, era)
  local shape = GuessSources.ShapeRefusal(source)
  if shape then
    return shape
  end
  if type(era) ~= "table" then
    return "no Classic Era table to read it against"
  end
  local meta = source.meta
  local stamp = GuessSources.EraStamp(era)
  if stamp == nil then
    return string.format("eraGenerated %s, but the Classic Era table carries no stamp", tostring(meta.eraGenerated))
  end
  if type(meta.eraGenerated) ~= "string" or meta.eraGenerated ~= stamp then
    return string.format(
      "eraGenerated %s does not match the Classic Era table's %s",
      tostring(meta.eraGenerated),
      tostring(stamp)
    )
  end
  return nil
end

--- Why a module's shape cannot be read (no module, no meta, another schema or width, records that
--- are not whole), or nil when it can: Refusal less the Classic Era stamp. Brief GS5: a new
--- creature is keyed by its creature id and named by the module's own n, so a question about new
--- creatures alone needs only this, and never builds the Era table. Pure.
function GuessSources.ShapeRefusal(source)
  if type(source) ~= "table" then
    return "no module"
  end
  local meta = source.meta
  if type(meta) ~= "table" then
    return "no meta"
  end
  if meta.schema ~= GuessSources.SCHEMA then
    return string.format("schema %s, this reader knows %d", tostring(meta.schema), GuessSources.SCHEMA)
  end
  if meta.width ~= GuessSources.WIDTH then
    return string.format("width %s, this reader knows %d", tostring(meta.width), GuessSources.WIDTH)
  end
  if type(source.r) ~= "string" or #source.r % GuessSources.WIDTH ~= 0 then
    return "records are not whole"
  end
  return nil
end

-- A reader over the shipped module: the module is built the first time an item is asked for,
-- checked once against the Era table, and kept.
local R = {}
R.__index = R

-- source is the module and defaults to Data:Get("GuessSources"), read when first needed. opts.data
-- swaps the data layer and opts.era the Classic Era reader (Core/EraSources.lua), which a spec
-- passes; both default to the addon's own, read at call time.
function GuessSources.New(source, opts)
  opts = opts or EMPTY
  local reader = setmetatable({}, R)
  reader.source = source
  reader.data = opts.data or Data
  reader.era = opts.era
  reader.settings = opts.settings
  reader.provider = nil
  -- The table the last check was made against, and what it said.
  reader.checkedFor = nil
  reader.refusal = nil
  -- How many records have been decoded, for the specs.
  reader.decodes = 0
  return reader
end

function R:_Era()
  local era = self.era or ItemTree.eraSources
  if type(era) ~= "table" or type(era.Table) ~= "function" then
    return nil
  end
  local ok, source = pcall(era.Table, era)
  if ok and type(source) == "table" then
    return source
  end
  return nil
end

-- The module, unchecked, or nil where the build ships none.
function R:_Module()
  if type(self.source) == "table" then
    return self.source
  end
  local data = self.data
  if type(data) ~= "table" or type(data.Get) ~= "function" then
    return nil
  end
  local ok, table_ = pcall(data.Get, data, GuessSources.MODULE)
  if ok and type(table_) == "table" then
    return table_
  end
  return nil
end

--- The module, or nil where the build ships none or it cannot be read against this Era table. A
--- refusal is kept (R:StatusLine says it) and answers nothing, exactly as an absent module does.
function R:Table()
  local source = self:_Module()
  if not source then
    return nil
  end
  if self.checkedFor ~= source then
    self.checkedFor = source
    self.refusal = GuessSources.Refusal(source, self:_Era())
  end
  if self.refusal then
    return nil
  end
  return source
end

--- One line for the debug command: whether the module is there, read, or refused and why.
function R:StatusLine()
  if self.checkedFor == nil then
    return "Guess sources: not read yet"
  end
  if self.refusal then
    return "Guess sources: refused, " .. self.refusal
  end
  local meta = self.checkedFor.meta
  return string.format(
    "Guess sources: %d records, build %s, %d decoded",
    math.floor(#self.checkedFor.r / GuessSources.WIDTH),
    tostring(meta.build),
    self.decodes
  )
end

--- One item's guesses, decoded, with the second specific where the side table has one, or nil.
function R:Find(itemId)
  local source = self:Table()
  if not source then
    return nil
  end
  local at = GuessSources.Find(source.r, GuessSources.WIDTH, itemId)
  if not at then
    return nil
  end
  self.decodes = self.decodes + 1
  local record = GuessSources.Decode(source.r:sub(at, at + GuessSources.WIDTH - 1))
  if record then
    local second = type(source.m) == "table" and source.m[itemId] or nil
    record.second = GuessSources.DecodeSecond(second)
  end
  return record
end

--- The words a why code stands for, or nil. source defaults to the module last checked.
function R:WhyWords(code, source)
  source = source or self.checkedFor
  local meta = type(source) == "table" and source.meta or nil
  local list = type(meta) == "table" and meta.why or nil
  local id = type(list) == "table" and type(code) == "number" and list[code] or nil
  return id and GuessSources.WHY_WORDS[id] or nil
end

-- A name out of a string table, or nil.
local function stringAt(strings, index)
  local text = type(strings) == "table" and type(index) == "number" and strings[index] or nil
  if type(text) == "string" and text ~= "" then
    return text
  end
  return nil
end

--- Brief M14: one entry of o, read: { name, x, y }, name the object's words out of s or nil for an
--- object that ships unnamed, x and y in percent (the module's tenths of a percent over ten). nil
--- for an index o does not hold or an entry that is not one. Pure.
function GuessSources.PlacedObject(source, ref)
  local list = type(source) == "table" and source.o or nil
  local entry = type(list) == "table" and type(ref) == "number" and list[ref] or nil
  if type(entry) ~= "table" then
    return nil
  end
  local x, y = tonumber(entry[2]), tonumber(entry[3])
  if not x or not y or x < 0 or x > 1000 or y < 0 or y > 1000 then
    return nil
  end
  return { name = stringAt(source.s, tonumber(entry[1])), x = x / 10, y = y / 10 }
end

--- Brief M14: the words a placed object's row reads as: "Contained in Library Book", or "Contained
--- in an object" for one that ships unnamed. Pure.
function GuessSources.PlacedLabel(objectName)
  if type(objectName) == "string" and objectName ~= "" then
    return string.format(L["Contained in %s"], objectName)
  end
  return L["Contained in an object"]
end

--- Brief M14: where a placed object stands, the way the game's map prints it: "Stonetalon
--- Mountains 74.4, 85.7", or the coordinates alone with no zone. nil without both coordinates. Pure.
function GuessSources.PlacedWhere(zone, x, y)
  if type(x) ~= "number" or type(y) ~= "number" then
    return nil
  end
  local coords = string.format("%.1f, %.1f", x, y)
  if type(zone) == "string" and zone ~= "" then
    return zone .. " " .. coords
  end
  return coords
end

--- The name of an area: the Classic Era table's (the same naming its own rows use), else this
--- module's z, else nil.
function R:AreaName(areaId)
  if type(areaId) ~= "number" or areaId < 1 then
    return nil
  end
  local era = self:_Era()
  local eraIndex = era and type(era.z) == "table" and era.z[areaId] or nil
  local name = era and stringAt(era.s, eraIndex) or nil
  if name then
    return name
  end
  local source = self.checkedFor
  local own = type(source) == "table" and type(source.z) == "table" and source.z[areaId] or nil
  return type(source) == "table" and stringAt(source.s, own) or nil
end

--- Brief GS5: the name of a creature new in Forever out of this module's n, or nil where the
--- module is not read or n does not name it (n is optional, and an older module has none).
function R:NewCreatureName(creatureId)
  local source = self.checkedFor
  if type(source) ~= "table" or self.refusal then
    source = self.creatureIndexFor
  end
  if type(source) ~= "table" or type(creatureId) ~= "number" then
    return nil
  end
  local at = type(source.n) == "table" and source.n[creatureId] or nil
  return stringAt(source.s, at)
end

--- Brief M14: the zone map an area is drawn on, through the Classic Era reader (E:MapOf), or nil.
function R:MapOf(areaId)
  if type(areaId) ~= "number" or areaId < 1 then
    return nil
  end
  local era = self.era or ItemTree.eraSources
  if type(era) ~= "table" or type(era.MapOf) ~= "function" then
    return nil
  end
  local ok, map = pcall(era.MapOf, era, areaId)
  if ok and type(map) == "number" then
    return map
  end
  return nil
end

--- Brief M14: what a placed object specific (type 6) stands for: { ref, objectName, label, area,
--- zone, map, x, y, where }. objectName is nil for an object that ships unnamed; area is the
--- specific's own, else fallbackArea (the record's zone); map is that area's zone map, nil where
--- this build has none; x and y are in percent. nil for a specific of another type, or one o does
--- not place.
function R:PlacedView(specific, fallbackArea)
  if type(specific) ~= "table" or specific.type ~= GuessSources.PLACED_OBJECT then
    return nil
  end
  local placed = GuessSources.PlacedObject(self:Table(), specific.ref)
  if not placed then
    return nil
  end
  local area = specific.area or fallbackArea
  local zone = area and self:AreaName(area) or nil
  return {
    ref = specific.ref,
    objectName = placed.name,
    label = GuessSources.PlacedLabel(placed.name),
    area = area,
    zone = zone,
    map = area and self:MapOf(area) or nil,
    x = placed.x,
    y = placed.y,
    where = GuessSources.PlacedWhere(zone, placed.x, placed.y),
  }
end

--- The name a specific stands for: n's name for a new creature (type 5), the Classic Era table's
--- string for a creature or a vendor, and the graph's name for a quest or an item. nil where
--- nothing names it; a caller never shows the ref in its place.
function R:SpecificName(specific)
  if type(specific) ~= "table" or type(specific.ref) ~= "number" then
    return nil
  end
  local spec = GuessSources.SPECIFICS[specific.type]
  if not spec then
    return nil
  end
  if spec.byId then
    return self:NewCreatureName(specific.ref)
  end
  if spec.placed then
    local view = self:PlacedView(specific)
    return view and view.objectName or nil
  end
  if spec.kind == "npc" then
    return self:_EraCreatureName(specific.ref)
  end
  local ok, name = pcall(Graph.Name, Graph.Key(spec.kind, specific.ref))
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- Brief EK2: the string index and the name of the Classic Era creature or vendor a type 1 or 2
-- specific names by its creature id (ci), out of the Era table, or nil where the table states no
-- such id.
function R:_EraCreatureIndex(creatureId)
  local era = self:_Era()
  local EraSources = ItemTree.EraSources
  if not era or type(EraSources) ~= "table" or type(EraSources.CreatureNameIndex) ~= "function" then
    return nil, nil
  end
  return EraSources.CreatureNameIndex(era, creatureId), era
end

function R:_EraCreatureName(creatureId)
  local nameIndex, era = self:_EraCreatureIndex(creatureId)
  return era and stringAt(era.s, nameIndex) or nil
end

--- GuessSources.SpecificName(specific[, reader]): the same, over the addon's own reader unless a
--- reader is handed in.
function GuessSources.SpecificName(specific, reader)
  reader = reader or ItemTree.guessSources
  if type(reader) ~= "table" or type(reader.SpecificName) ~= "function" then
    return nil
  end
  return reader:SpecificName(specific)
end

-- The settings read at call time: the reader's own where a spec handed some in, else the saved
-- ones. Either off hides every guess.
function R:_Shown()
  local settings = self.settings
  if type(settings) == "function" then
    local ok, answer = pcall(settings)
    settings = ok and answer or nil
  end
  if settings == nil then
    local db = ItemTree.db
    settings = type(db) == "table" and db.settings or nil
  end
  if type(settings) ~= "table" then
    return true
  end
  return settings.showPredicted ~= false and settings.showGuessSources ~= false
end

-- Whether an item the build withholds is still a placeholder: nobody on the realm has found it,
-- as far as this client can tell (the client names it, or the collector noted it found). Such an
-- item carries its guess in the module and draws it only once it is discovered.
function R:_Placeholder(itemId)
  local data = self.data
  if type(data) ~= "table" or type(data.IsUndiscovered) ~= "function" then
    return false
  end
  local ok, withheld = pcall(data.IsUndiscovered, data, itemId)
  if not ok or not withheld then
    return false
  end
  -- The two facts Graph.Node reads for node.discovered, asked directly: with the Classic Era
  -- details setting on, a withheld item's node is its Era row and does not say either.
  local resolver = ItemTree.ItemFacts
  if type(resolver) == "function" then
    local asked, facts = pcall(resolver, itemId)
    if asked and type(facts) == "table" and type(facts.name) == "string" and facts.name ~= "" then
      return false
    end
  end
  if Graph.names[Graph.Key("item", itemId)] ~= nil then
    return false
  end
  return true
end

-- The guess field one level carries.
function R:_Guess(level, part, area)
  return {
    level = level,
    strength = part.strength,
    why = part.why,
    whyWords = self:WhyWords(part.why),
    area = area,
  }
end

-- The edge fields every guess carries.
local function guessEdge(def, target, guess)
  return {
    type = def,
    target = target,
    group = GROUPS[def.name] or def.label,
    confidence = Confidence.GUESS,
    provenance = GuessSources.PROVENANCE,
    basis = Confidence.BASIS_GUESS,
    guess = guess,
  }
end

-- The place's words and the area its zone column links through: an area for a zone, a name out
-- of s for an instance or a faction.
function R:_PlaceWords(place)
  if not place then
    return nil, nil
  end
  if GuessSources.PLACES[place.type] == "zone" then
    return self:AreaName(place.ref), place.ref
  end
  local source = self.checkedFor
  return type(source) == "table" and stringAt(source.s, place.ref) or nil, nil
end

-- One specific's edge, or nil for one this client cannot name.
function R:_SpecificEdge(itemId, specific, placeWords, placeArea)
  local spec = GuessSources.SPECIFICS[specific.type]
  if not spec then
    return nil
  end
  local def = T[spec.edge]
  if spec.placed then
    return self:_PlacedEdge(itemId, specific, placeArea, def)
  end
  local target, name, paged, nameIndex
  if spec.byId then
    -- Brief GS5: the creature's own node, named out of n. With no name there is no row: the
    -- record's place row stands, never a raw id and never the Unknown creature node in its stead.
    name = self:NewCreatureName(specific.ref)
    if not name or specific.ref < 1 then
      return nil
    end
    target = Graph.Key("npc", specific.ref)
    -- A name something on this client already holds (the collector, the creature cache) wins.
    if Graph.names[target] == nil then
      Graph.SetName(target, name)
    end
  elseif spec.kind == "npc" then
    -- The Classic Era table's own node for that name, so the merge in Core/Graph.lua drops the
    -- guess wherever an Era row names the same creature or vendor. Brief EK2: a guess names it by
    -- its creature id (ci), which the table reads back to the name; the node is its page, keyed by
    -- that id (brief EK1, EraSources.CreatureNode), the plain npc:<id> where the page is merged.
    local era
    nameIndex, era = self:_EraCreatureIndex(specific.ref)
    name = era and stringAt(era.s, nameIndex) or nil
    if not name then
      return nil
    end
    local EraSources = ItemTree.EraSources
    if type(EraSources.CreatureNode) ~= "function" then
      return nil
    end
    target, paged = EraSources.CreatureNode(era, nameIndex)
    if not target then
      return nil
    end
  elseif spec.kind == "quest" then
    target = Graph.Key("quest", specific.ref)
  else
    if specific.ref == itemId then
      return nil
    end
    target = Graph.Key("item", specific.ref)
  end
  local edge = guessEdge(def, target, self:_Guess(Graph.GUESS_SPECIFIC, specific, specific.area))
  edge.dedupeName = name
  if paged == false then
    edge.noPage = true
  end
  -- The specific's own area where the model states one this build names, else the place's.
  local areaName = specific.area and self:AreaName(specific.area) or nil
  if areaName then
    edge.zone = areaName
    edge.areaId = specific.area
  else
    edge.zone = placeWords
    edge.areaId = placeArea
  end
  if specific.type == 1 and nameIndex then
    -- What kind of creature it is, for the row's icon, the way a Classic Era creature row says.
    local era = self.era or ItemTree.eraSources
    if type(era) == "table" and type(era.KindOf) == "function" then
      local ok, creatureType, family, low, high = pcall(era.KindOf, era, nameIndex)
      if ok and creatureType then
        edge.creature = { type = creatureType, family = family, low = low, high = high }
      end
    end
  end
  return edge
end

-- Brief M14: a placed object's edge, on its own node, or nil for one o does not place. It is a row
-- that names no page to open (a summary with nothing listed, like the Unknown container), worded
-- through guess.nameAs, which Core/ViewModel.lua puts in the Sources row's name, with the zone and
-- the coordinates in its zone column. guess.placed carries what the item page's Where line needs.
function R:_PlacedEdge(itemId, specific, placeArea, def)
  local view = self:PlacedView(specific, placeArea)
  local target = view and GuessSources.PlacedKey(view.ref) or nil
  if not view or not target or not def then
    return nil
  end
  Graph.SetName(target, view.label)
  local guess = self:_Guess(Graph.GUESS_SPECIFIC, specific, view.area)
  guess.nameAs = view.label
  guess.placed = { objectName = view.objectName, map = view.map, x = view.x, y = view.y, area = view.area }
  local edge = guessEdge(def, target, guess)
  edge.zone = view.where
  if view.zone then
    edge.areaId = view.area
  end
  edge.summary = { item = itemId, category = GuessSources.PROVENANCE, listed = 0 }
  return edge
end

-- The kind or place edge, on the node that names no source, or nil.
function R:_NodeEdge(itemId, level, part, kindSpec, placeWords, placeArea)
  if not kindSpec then
    return nil
  end
  local def = T[kindSpec.edge]
  local node = GuessSources.NODES[kindSpec.node]
  local target = GuessSources.NodeKey(kindSpec.node)
  if not def or not node or not target then
    return nil
  end
  Graph.SetName(target, node.name)
  local edge = guessEdge(def, target, self:_Guess(level, part, nil))
  edge.zone = placeWords
  edge.areaId = placeArea
  -- A row that stands for a group and names nothing, like the world drop: never re-rooted onto.
  edge.summary = { item = itemId, category = GuessSources.PROVENANCE, listed = 0 }
  return edge
end

-- The kind a specific type implies, for a record that states no kind of its own: a creature is
-- a creature drop, a vendor a vendor, a quest a quest reward, an item a container.
local SPECIFIC_KINDS = { [1] = 2, [2] = 4, [3] = 6, [4] = 8, [5] = 2, [6] = 8 }

-- The kind a record's place row is filed under: its own kind, else a faction's reputation
-- vendor, else the kind its specific implies.
local function placeKind(record)
  local kind = record.kind and GuessSources.KINDS[record.kind.code] or nil
  if kind then
    return kind
  end
  if record.place and GuessSources.PLACES[record.place.type] == "faction" then
    return GuessSources.KINDS[5]
  end
  local implied = record.specific and SPECIFIC_KINDS[record.specific.type] or nil
  return implied and GuessSources.KINDS[implied] or nil
end

--- The edges one item's guesses stand for: each specific (the second too), the place and the
--- kind, every one on this item's own node. Core/Graph.lua keeps the most specific of them that
--- survives the real edges beside it. Empty where the item has none, is still a placeholder, or
--- the module is absent or refused.
function R:ItemEdges(itemId)
  local out = {}
  if self:_Placeholder(itemId) then
    return out
  end
  local record = self:Find(itemId)
  if not record then
    return out
  end
  local placeWords, placeArea = self:_PlaceWords(record.place)
  -- Brief GS5: a new creature n does not name leaves no row of its own, and the place row then
  -- reads as the place alone rather than as the Unknown creature node.
  local unnamedNew = false
  for _, specific in ipairs({ record.specific or false, record.second or false }) do
    if specific then
      local edge = self:_SpecificEdge(itemId, specific, placeWords, placeArea)
      if edge then
        out[#out + 1] = edge
      elseif GuessSources.SPECIFICS[specific.type] and GuessSources.SPECIFICS[specific.type].byId then
        unnamedNew = true
      end
    end
  end
  local kindSpec = placeKind(record)
  if record.place then
    local edge = self:_NodeEdge(itemId, Graph.GUESS_PLACE, record.place, kindSpec, placeWords, placeArea)
    if edge then
      if unnamedNew and placeWords then
        -- The row's own words, carried on the guess field because Core/Graph.lua copies only its
        -- known edge fields (Core/ViewModel.lua puts them in the Sources row's name), and so no
        -- zone column saying the same again.
        edge.guess.nameAs = placeWords
        edge.zone = nil
      end
      out[#out + 1] = edge
    end
  end
  if record.kind and GuessSources.KINDS[record.kind.code] then
    local edge = self:_NodeEdge(itemId, Graph.GUESS_KIND, record.kind, kindSpec, nil, nil)
    if edge then
      out[#out + 1] = edge
    end
  end
  return out
end

--- Brief M14: the spots an item's placed object guesses stand at, for the item page's Where lines:
--- { R:PlacedView, ... } in record order (the specific, then the second). Empty while either setting
--- hides guesses, for an item still a placeholder, one with no placed object, or where the module is
--- absent or refused.
function R:PlacedSpots(itemId)
  local out = {}
  if type(itemId) ~= "number" or not self:_Shown() or self:_Placeholder(itemId) then
    return out
  end
  local record = self:Find(itemId)
  if not record then
    return out
  end
  return self:_RecordSpots(record)
end

-- The placed object views one decoded record stands for, the specific then the second, each in
-- its own area or the record's zone.
function R:_RecordSpots(record)
  local out = {}
  local placeArea = nil
  if record.place and GuessSources.PLACES[record.place.type] == "zone" then
    placeArea = record.place.ref
  end
  for _, specific in ipairs({ record.specific or false, record.second or false }) do
    local view = specific and self:PlacedView(specific, placeArea) or nil
    if view then
      out[#out + 1] = view
    end
  end
  return out
end

-- Brief M15: the items with a placed object guess, by the area each spot stands in, read in one
-- pass over the type byte of every record (and the second specifics) the first time a zone page's
-- Map view asks, and kept while the module is the same table. Only a record whose specific or
-- second is a placed object is decoded. { [areaId] = { itemId, ... } }, each list by item id.
-- Placeholders are filed too, since one may be discovered later in the session; the reader below
-- leaves them out at the time it is asked.
function R:_PlacedIndex()
  local source = self:Table()
  if not source then
    return nil
  end
  if self.placedIndexFor == source then
    return self.placedIndex
  end
  local wanted = GuessSources.PLACED_OBJECT
  local items = {}
  local width, r = GuessSources.WIDTH, source.r
  for at = 1, #r - width + 1, width do
    if codeAndStrength(packedInt(r, at + 10, 1)) == wanted then
      local itemId = packedInt(r, at, ITEM_DIGITS)
      if itemId then
        items[itemId] = true
      end
    end
  end
  for itemId, text in pairs(type(source.m) == "table" and source.m or EMPTY) do
    local second = type(itemId) == "number" and GuessSources.DecodeSecond(text) or nil
    if second and second.type == wanted then
      items[itemId] = true
    end
  end
  local index, filed = {}, {}
  for itemId in pairs(items) do
    local record = self:Find(itemId)
    for _, view in ipairs(record and self:_RecordSpots(record) or EMPTY) do
      local area = view.area
      if type(area) == "number" and not (filed[area] and filed[area][itemId]) then
        filed[area] = filed[area] or {}
        filed[area][itemId] = true
        index[area] = index[area] or {}
        index[area][#index[area] + 1] = itemId
      end
    end
  end
  for _, list in pairs(index) do
    table.sort(list)
  end
  self.placedIndexFor = source
  self.placedIndex = index
  self.placedScans = (self.placedScans or 0) + 1
  return index
end

--- Brief M15: the items a zone's placed object guesses stand in, for the zone page's Map view item
--- column: { { item = itemId, spots = { R:PlacedView, ... } }, ... } by item id, each item's spots
--- those in this area alone. Empty while either setting hides guesses, for an area none stands in,
--- or where the module is absent or refused; an item still a placeholder is left out.
function R:PlacedItemsIn(areaId)
  local out = {}
  if type(areaId) ~= "number" or areaId < 1 or not self:_Shown() then
    return out
  end
  local index = self:_PlacedIndex()
  for _, itemId in ipairs(index and index[areaId] or EMPTY) do
    local spots = {}
    for _, view in ipairs(self:PlacedSpots(itemId)) do
      if view.area == areaId then
        spots[#spots + 1] = view
      end
    end
    if #spots > 0 then
      out[#out + 1] = { item = itemId, spots = spots }
    end
  end
  return out
end

-- Brief GS5: the items whose specific (or second specific) is a new creature, by creature id,
-- read in one pass over the packed specifics the first time a boss with a creature id is opened,
-- and kept while the module is the same table. Only the type byte of each record is read unless
-- it is a creature. { [creatureId] = { { item, strength, why }, ... } }, each list by item id.
-- A new creature names nothing out of the Classic Era table, so only the module's shape is
-- checked (GuessSources.ShapeRefusal) and the Boss loot tab never builds that table.
-- Brief GS5b: the same pass files the Classic Era creatures (type 1) by their ref, in
-- self.eraCreatureIndex, for R:ItemsForEraCreature: since brief EK2 the creature id the Classic Era
-- table states for the name (ci), never the name's place in its strings.
function R:_CreatureIndex()
  local source = self:_Module()
  if not source or GuessSources.ShapeRefusal(source) then
    return nil
  end
  if self.creatureIndexFor == source then
    return self.creatureIndex
  end
  local map, eraMap = {}, {}
  local wanted = GuessSources.NEW_CREATURE
  local function add(itemId, specific)
    if not specific or specific.ref < 1 then
      return
    end
    local into = nil
    if specific.type == wanted then
      into = map
    elseif specific.type == GuessSources.ERA_CREATURE then
      into = eraMap
    end
    if into then
      local list = into[specific.ref]
      if not list then
        list = {}
        into[specific.ref] = list
      end
      list[#list + 1] = { item = itemId, strength = specific.strength, why = specific.why }
    end
  end
  local width, r = GuessSources.WIDTH, source.r
  for at = 1, #r - width + 1, width do
    local code = codeAndStrength(packedInt(r, at + 10, 1))
    if code == wanted or code == GuessSources.ERA_CREATURE then
      add(packedInt(r, at, ITEM_DIGITS), decodeSpecific(r, at + 10))
    end
  end
  for itemId, text in pairs(type(source.m) == "table" and source.m or EMPTY) do
    if type(itemId) == "number" then
      add(itemId, GuessSources.DecodeSecond(text))
    end
  end
  for _, index in ipairs({ map, eraMap }) do
    for _, list in pairs(index) do
      table.sort(list, function(a, b)
        return a.item < b.item
      end)
    end
  end
  self.creatureIndexFor = source
  self.creatureIndex = map
  self.eraCreatureIndex = eraMap
  self.creatureScans = (self.creatureScans or 0) + 1
  return map
end

-- One list of the creature index as the Boss loot tab takes it: placeholders left out, and each
-- guess with its why's words.
function R:_Guessed(list)
  local out = {}
  for _, guess in ipairs(list or EMPTY) do
    if not self:_Placeholder(guess.item) then
      out[#out + 1] = {
        item = guess.item,
        strength = guess.strength,
        why = guess.why,
        whyWords = self:WhyWords(guess.why, self.creatureIndexFor),
      }
    end
  end
  return out
end

--- Brief GS5: the guesses that name one creature new in Forever as the source, for the Boss loot
--- tab: { { item, strength, why, whyWords }, ... } by item id. Empty while either setting hides
--- guesses, for an item still a placeholder, or where the module is absent or refused.
function R:ItemsForCreature(creatureId)
  if type(creatureId) ~= "number" or not self:_Shown() then
    return {}
  end
  local map = self:_CreatureIndex()
  return self:_Guessed(map and map[creatureId])
end

--- Brief GS5b: the guesses that name one Classic Era creature (specific type 1, the pipeline's
--- community claim on an Era boss). Brief EK2: by the CMaNGOS creature id its Classic Era page is
--- keyed by (the table's ci for the name, which is the Boss loot index's own ei for that boss), no
--- longer by the name's index into the table's strings. The same shape and the same rules as
--- R:ItemsForCreature. The id is compared as a number and never read as a name, so the Era table is
--- not built here; a module a check has already refused against the Era table the client holds
--- answers nothing.
function R:ItemsForEraCreature(creatureId)
  if type(creatureId) ~= "number" or not self:_Shown() then
    return {}
  end
  local source = self:_Module()
  if source ~= nil and self.checkedFor == source and self.refusal then
    return {}
  end
  if not self:_CreatureIndex() then
    return {}
  end
  local map = self.eraCreatureIndex
  return self:_Guessed(map and map[creatureId])
end

--- Edges for Graph.RegisterProvider: an item walking up, and nothing else. Off while either
--- showPredicted or showGuessSources is off, and never builds the module for anything but an item.
function R:EdgesFor(key, direction)
  if direction ~= Edges.UP then
    return EMPTY
  end
  local kind, id = Graph.Parse(key)
  if kind ~= "item" or not self:_Shown() then
    return EMPTY
  end
  return self:ItemEdges(id)
end

--- Registers EdgesFor with the graph as a provider of guesses alone (asked only by a walk that
--- set opts.includeGuessSources) and of predictions alone (never asked by Graph.Summary). Safe to call
--- twice.
function R:Install()
  self:Uninstall()
  self.provider = function(key, direction)
    return self:EdgesFor(key, direction)
  end
  Graph.RegisterProvider(self.provider, { predictedOnly = true, guessOnly = true })
  return self.provider
end

function R:Installed()
  return self.provider ~= nil and Graph.HasProvider(self.provider) == true
end

function R:Uninstall()
  if self.provider then
    Graph.UnregisterProvider(self.provider)
    self.provider = nil
  end
end

-- Registered at load, like Core/EraSources.lua: nothing is read until the Sources view asks for
-- an item's guesses, so a session that never opens one never builds the module.
ItemTree.guessSources = GuessSources.New()
ItemTree.guessSources:Install()

return GuessSources
