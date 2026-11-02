-- Reads sources out of All The Things, if the player has it installed. Ships none of its data.
--
-- Modelled on the real addon at github.com/ATTWoWAddon/AllTheThings, master 0d437c5:
--   src/base.lua        "if not _G.AllTheThings then _G.AllTheThings = app end", and
--                       app.GetRelativeValue(group, field), which walks sourceParent or parent
--                       upwards and answers with the first value it finds. Also app.ObjectNames
--                       and app.NPCNameFromID, both tables keyed by id behind a metatable.
--   src/Cache.lua       app.SearchForField(field, id) answers currentCache[field][id]. The cache
--                       sits behind AutoTableOfTables, so an item nothing knows about answers
--                       with an EMPTY TABLE rather than with nil.
--   src/Classes/NPC.lua        key "npcID", with "creatureID" kept as the same cache
--   src/Classes/Objects.lua    key "objectID"
--   src/Classes/Profession.lua key "professionID", whose requireSkill answers the same number
--   src/Classes/Maps.lua       app.GetMapName(mapID)
--   src/Classes/Quests.lua     app.GetQuestName(questID)
--   src/Modules/Costs.lua      a cost is a list of { "i" | "c" | "g", id, amount }; for "g" the
--                              second entry is the amount of copper and there is no third
--   db/Camelot/Categories/Zones.lua  the shipped shape of a group: crs = { 946 },
--                              providers = { { "i", 6753 }, { "o", 148499 }, { "n", 707 } },
--                              cost = { { "i", 2686, 1 } }, maps = { 29, 31 }
-- ItemTree ships one TOC at interface 16001, the Forever client, and the Forever tree is
-- db/Camelot, cached the same way every other flavour is, so nothing here has to know which
-- client is running.
--
-- Every upstream read goes through call() below, which pcalls and remembers the first error.
-- Providers/Registry.lua asks for that error after every answer and takes this adapter off for
-- the session when there is one.
local _, ItemTree = ...

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

local ATT = {}
ItemTree.Adapters = ItemTree.Adapters or {}
ItemTree.Adapters.att = ATT

ATT.key = "att"
ATT.label = "All The Things"
-- The addon FOLDER, which is what a TOC OptionalDeps line and IsAddOnLoaded both name. The real
-- addon ships as AllTheThings\AllTheThings.toc, whose "## Name: AllTheThings" agrees.
ATT.addon = "AllTheThings"

-- The first upstream error, which is the end of this adapter for the session.
local fault = nil

function ATT.Fault()
  return fault
end

function ATT.Reset()
  return true
end

-- Every upstream read goes through here: a call, or an index into one of the tables ATT hangs a
-- metatable on. A failure is remembered rather than raised, so one bad group cannot take a
-- tooltip down with it, and the registry reads the fault back and stops asking.
local function call(fn, ...)
  if fault or type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if not ok then
    fault = tostring(value)
    return nil
  end
  return value
end

-- A name out of one of ATT's id keyed tables. The tables answer through an __index that asks
-- the client, so the read is a call like any other.
local function nameFrom(source, id)
  if type(source) ~= "table" then
    return nil
  end
  local name = call(function()
    return source[id]
  end)
  if type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- Gathering professions, whose nodes are gathered rather than looted, plus skinning, which is
-- taken off a creature rather than dropped by one, and fishing, whose source is the zone.
local HERBALISM, MINING, FISHING, SKINNING = 182, 186, 356, 393
local GATHERING = { [HERBALISM] = true, [MINING] = true }

local function relative(global, group, field)
  return call(global.GetRelativeValue, group, field)
end

-- The profession a group sits under, either stated on the group as requireSkill or read off a
-- profession header above it.
local function skillOf(global, group)
  local skill = relative(global, group, "requireSkill")
  if type(skill) == "number" then
    return skill
  end
  skill = relative(global, group, "professionID")
  if type(skill) == "number" then
    return skill
  end
  return nil
end

-- The zone a group sits in, as an id and as words. ATT hangs its tree off maps, so the nearest
-- mapID above a group is the zone its source is in.
local function zoneOf(global, group)
  local mapId = relative(global, group, "mapID")
  if type(mapId) ~= "number" then
    return nil, nil
  end
  local name = call(global.GetMapName, mapId)
  if type(name) ~= "string" or name == "" then
    return mapId, nil
  end
  return mapId, name
end

-- The vendor price a group asks, in copper, or nil. Only a gold cost is a price: a cost paid in
-- items or in a currency is a trade, and a money column would read as a lie.
local function priceOf(group)
  local cost = group.cost
  if type(cost) ~= "table" then
    return nil
  end
  for _, entry in ipairs(cost) do
    if type(entry) == "table" and entry[1] == "g" and type(entry[2]) == "number" and entry[2] > 0 then
      return entry[2]
    end
  end
  return nil
end

local function hasCost(group)
  return type(group.cost) == "table" and #group.cost > 0
end

-- The source line Core/Collector.lua writes, "Name, Zone", which Core/Sources.lua reads the zone
-- back off. Built the same way here so an imported row and a collected one read alike.
local function metaFor(name, zone)
  if not name then
    return nil
  end
  if not zone then
    return name
  end
  return name .. ", " .. zone
end

-- Collects edges, de-duplicated by edge type and target, so an item listed under three maps is
-- one row per source rather than three.
local function collector()
  local out, seen = {}, {}
  return out,
    function(def, targetKind, targetId, name, zone, fields)
      if not def or type(targetId) ~= "number" or targetId <= 0 then
        return
      end
      local target = Graph.Key(targetKind, targetId)
      local slot = def.name .. "\0" .. target
      if seen[slot] then
        return
      end
      seen[slot] = true
      if name then
        Graph.SetName(target, name)
      end
      fields = fields or EMPTY
      out[#out + 1] = {
        type = def,
        target = target,
        meta = metaFor(name, zone),
        zone = zone,
        group = fields.group or def.label,
        price = fields.price,
        quantity = fields.quantity,
        choice = fields.choice,
        -- All The Things carries no drop rates at all, so an ATT edge never claims one and never
        -- needs the percentSource stamp Core/Sources.lua softens a rate by.
        confidence = Confidence.BASELINE,
        provenance = ATT.key,
      }
    end
end

-- One group out of the search cache, turned into whatever sources it describes.
--
-- A group is the item as it appears somewhere in ATT's tree, so the same item comes back many
-- times over: once under each creature, object, vendor, quest and profession that gives it.
-- What gives it is stated either on the group itself (crs, providers, cost) or by what it hangs
-- under (a creature, an object, a quest, a profession header).
--
-- global is the AllTheThings table, passed in rather than looked up, so the whole mapping runs
-- under busted against a fake shaped like the real one.
function ATT.ReadGroup(global, group, add)
  if type(global) ~= "table" or type(group) ~= "table" then
    return
  end
  local skill = skillOf(global, group)
  local _, zone = zoneOf(global, group)
  local bought = hasCost(group)
  local price = priceOf(group)

  -- A creature the item comes off. Skinning is its own edge because it answers a different
  -- question from a drop, and a vendor is a creature with a price rather than a kill.
  local function fromCreature(id)
    local name = nameFrom(global.NPCNameFromID, id)
    if bought then
      add(T.SOLD_BY, "npc", id, name, zone, { group = L["Sold by"], price = price })
      return
    end
    if skill == SKINNING then
      add(T.SKINNED_FROM, "npc", id, name, zone, { group = L["Drops from"] })
      return
    end
    add(T.DROPPED_BY, "npc", id, name, zone, { group = L["Drops from"] })
  end

  -- An object the item comes out of. A herb or a vein is gathered and a chest is looted; ATT
  -- only says which when the group sits under a gathering profession, so anything else is
  -- looted rather than guessed at.
  local function fromObject(id)
    local name = nameFrom(global.ObjectNames, id)
    if GATHERING[skill] then
      add(T.GATHERED_FROM, "object", id, name, zone, { group = L["Gathered from"] })
      return
    end
    add(T.LOOTED_FROM, "object", id, name, zone, { group = L["Contained in"] })
  end

  for _, id in ipairs(group.crs or EMPTY) do
    if type(id) == "number" then
      fromCreature(id)
    end
  end

  for _, provider in ipairs(group.providers or EMPTY) do
    if type(provider) == "table" and type(provider[2]) == "number" then
      local kind, id = provider[1], provider[2]
      if kind == "o" then
        fromObject(id)
      elseif kind == "n" then
        fromCreature(id)
      elseif kind == "i" then
        add(T.CONTAINED_IN, "item", id, nil, nil, { group = L["Contained in"] })
      end
    end
  end

  -- What the group hangs under. A creature or an object parent says what the group's own entry
  -- would have said, and a quest parent says the item was a reward for finishing it.
  local npcId = relative(global, group, "npcID")
  if type(npcId) ~= "number" then
    npcId = relative(global, group, "creatureID")
  end
  if type(npcId) == "number" then
    fromCreature(npcId)
  end

  local objectId = relative(global, group, "objectID")
  if type(objectId) == "number" then
    fromObject(objectId)
  end

  local questId = relative(global, group, "questID")
  if type(questId) == "number" then
    local name = call(global.GetQuestName, questId)
    if type(name) ~= "string" or name == "" then
      name = nil
    end
    add(T.QUEST_REWARD, "quest", questId, name, zone, { group = L["Quests"] })
  end

  -- Fishing has neither an object nor a creature behind it: the zone is the source, which is
  -- the one place Core/Edges.lua points a source edge at a zone.
  if skill == FISHING then
    local mapId, mapName = zoneOf(global, group)
    if type(mapId) == "number" then
      add(T.FISHED_FROM, "zone", mapId, mapName, nil, { group = L["Fished from"] })
    end
  end
end

local function questName(global, questId)
  local name = call(global.GetQuestName, questId)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return name
end

-- The quests that need this item, from the "itemIDAsCost" cache. src/Cache.lua files every group
-- that lists an item as a provider ("i") or as a cost ("i") under that field, so the quests an
-- item is an objective of are one table read away and no reverse index has to be built.
local function readNeededBy(global, itemId, add)
  local groups = call(global.SearchForField, "itemIDAsCost", itemId)
  if type(groups) ~= "table" then
    return
  end
  for _, group in ipairs(groups) do
    local questId = relative(global, group, "questID")
    if type(questId) == "number" then
      add(T.QUEST_OBJECTIVE, "quest", questId, questName(global, questId), nil, { group = L["Quests"] })
    end
    if fault then
      return
    end
  end
end

-- What one quest asks for and what it gives back.
--
-- A quest group states what it needs on itself and on its quest objective children: providers of
-- kind "i" and costs of kind "i", where a cost also states how many. What it gives back is its
-- item children, which is how ATT nests a reward under the quest that pays it.
function ATT.ReadQuestGroup(global, group, add)
  if type(global) ~= "table" or type(group) ~= "table" then
    return
  end

  local function needs(from)
    for _, provider in ipairs(from.providers or EMPTY) do
      if type(provider) == "table" and provider[1] == "i" and type(provider[2]) == "number" then
        add(T.QUEST_REQUIRES, "item", provider[2], nil, nil, { group = L["Requires"] })
      end
    end
    for _, entry in ipairs(from.cost or EMPTY) do
      if type(entry) == "table" and entry[1] == "i" and type(entry[2]) == "number" then
        add(T.QUEST_REQUIRES, "item", entry[2], nil, nil, {
          group = L["Requires"],
          quantity = tonumber(entry[3]) or 1,
        })
      end
    end
  end

  needs(group)
  for _, child in ipairs(group.g or EMPTY) do
    if type(child) == "table" then
      if type(child.itemID) == "number" then
        add(T.QUEST_REWARDS, "item", child.itemID, nil, nil, { group = L["Rewards"] })
      else
        -- A quest objective, which has no itemID of its own and names the items it wants.
        needs(child)
      end
    end
  end
end

-- Every edge All The Things has for one node. kind is "item" or "quest"; global is passed in, so
-- this is the whole of the adapter with none of the lookup.
function ATT.EdgesFrom(global, id, kind)
  if fault or type(id) ~= "number" then
    return EMPTY
  end
  if type(global) ~= "table" or type(global.SearchForField) ~= "function" then
    return EMPTY
  end
  kind = kind or "item"
  local out, add = collector()

  if kind == "quest" then
    local groups = call(global.SearchForField, "questID", id)
    if type(groups) ~= "table" then
      return EMPTY
    end
    local name = questName(global, id)
    if name then
      Graph.SetName(Graph.Key("quest", id), name)
    end
    for _, group in ipairs(groups) do
      ATT.ReadQuestGroup(global, group, add)
      if fault then
        return EMPTY
      end
    end
    return out
  end

  if kind ~= "item" then
    return EMPTY
  end

  local groups = call(global.SearchForField, "itemID", id)
  if type(groups) ~= "table" then
    return EMPTY
  end
  for _, group in ipairs(groups) do
    ATT.ReadGroup(global, group, add)
    if fault then
      return EMPTY
    end
  end
  readNeededBy(global, id, add)
  if fault then
    return EMPTY
  end
  return out
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- The addon's own table. base.lua puts it on _G under two names; AllTheThings is the one the
-- addon documents, so that is the one asked for.
function ATT.Global()
  local global = rawget(_G, "AllTheThings")
  if type(global) ~= "table" then
    return nil
  end
  return global
end

-- "absent" until the global is there, "waiting" until its search cache is built, then "ready".
-- SearchForField is what every lookup goes through, so its absence is the honest test: it is
-- assigned when the database is built, and nothing here ever asks for that to happen.
function ATT.Ready()
  local global = ATT.Global()
  if not global then
    return "absent"
  end
  if type(global.SearchForField) ~= "function" then
    return "waiting", "search cache not built"
  end
  return "ready"
end

-- Every edge All The Things has for one node, in both directions. Only ever called for an item
-- or a quest: Providers/Registry.lua bails on every other kind first.
function ATT.Edges(id, kind)
  return ATT.EdgesFrom(ATT.Global(), id, kind)
end

if ItemTree.Providers and type(ItemTree.Providers.Add) == "function" then
  ItemTree.Providers.Add(ATT)
end

return ATT
