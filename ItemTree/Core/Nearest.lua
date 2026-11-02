-- Brief PR29: the nearest vendor that sells an item, for the "Show nearest" button on a Sources
-- view's "Sold by" header (UI/Tree.lua draws the button and acts on the answer). Brief PR34 (owner,
-- 2026-10-02): the same button on a "Trainer" header, the nearest trainer who teaches a recipe.
-- Trainers are NPCs as vendors are, so they take the same picking and the same places below (in
-- practice their Classic Era pins, npc:-<creature id> (brief EK1), and where the player stood at
-- one).
-- Loaded as: local _, ItemTree = ...
--
-- Where a vendor stands comes from our own data and nothing else, the same three places the Map
-- tab and an NPC page read it from:
--   Classic Era pins   Core/EraSources.lua, E:PinSubject(key) then the mp pins of that name
--                      (EraSources.PinsOf), narrowed to the key's own area where it states one
--   Forever vendors    Core/ForeverVendors.lua, the client table's own place (v[npcId] with the
--                      area's zone map from ForeverVendors.Place), only where the module is built
--   Merchant's Favour  Core/Sources.lua Favour.VendorFacts and Favour.Positions, the curated place
--                      or where the player stood at the vendor's window
--   Our own spots      Core/PlayerSources.lua Spots (brief TR1c), else an owner confirmed claim's
--                      approximate cells (Core/Creatures.lua ClaimPins, tq), both only where loaded
-- A vendor's side is its edge's faction (1 Alliance, 2 Horde, 3 both, the Classic Era table's cf)
-- or the curated file's word; the button only ever points at a friendly or neutral vendor.
--
-- Pure functions first. Below the divider, guarded: the player's place (C_Map.GetBestMapForUnit,
-- C_Map.GetPlayerMapPosition) and each pin's world place (C_Map.GetWorldPosFromMapPos), kept for the
-- session. Local map calls, never an item query, and asked only for this item's vendors on a press.
local _, ItemTree = ...

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local Nearest = {}
ItemTree.Nearest = Nearest

local EMPTY = {}

-- The view model's id for the "Sold by" group (Core/ViewModel.lua GROUP_IDS).
Nearest.SOLD_BY_ID = "soldby"
-- Brief PR34: the "Trainer" group's id (Core/ViewModel.lua GROUP_IDS).
Nearest.TRAINER_ID = "trainer"

-- The groups the button stands on, by id, and the kind of NPC each holds.
Nearest.KINDS = { [Nearest.SOLD_BY_ID] = "vendor", [Nearest.TRAINER_ID] = "trainer" }

-- The row a Forever item sold by a vendor the client does not name yet points at
-- (Core/ForeverVendors.lua UNNAMED_KEY). It names nobody, so it is never a candidate.
Nearest.UNNAMED_KEY = "npc:899999999"

-- Tiers, best first.
Nearest.SAME_ZONE = 1
Nearest.SAME_CONTINENT = 2
Nearest.OTHER_CONTINENT = 3

local SIDES = { [1] = "Alliance", [2] = "Horde", Alliance = "Alliance", Horde = "Horde" }

--- The one side a vendor serves, "Alliance" or "Horde", or nil for both sides or none stated.
--- Takes the edge's number (1, 2, 3) or the curated file's word. Pure.
function Nearest.Side(faction)
  return SIDES[faction]
end

--- Whether a vendor of this side is friendly or neutral to a player of playerSide: true unless
--- the vendor serves the other side alone. An unknown player side hides nobody. Pure.
function Nearest.Friendly(faction, playerSide)
  local side = Nearest.Side(faction)
  if side == nil or (playerSide ~= "Alliance" and playerSide ~= "Horde") then
    return true
  end
  return side == playerSide
end

--- Brief PR34: the kind of NPC a group holds, "vendor" for "Sold by" and "trainer" for "Trainer",
--- or nil for any other group. Takes the group's table. Pure.
function Nearest.KindOf(category)
  if type(category) ~= "table" then
    return nil
  end
  return Nearest.KINDS[category.id]
end

--- Brief PR34: the kind of NPC a tree row's header holds (Nearest.KindOf), or nil for a row that is
--- not the header of a group the button stands on. Pure.
function Nearest.GroupKind(row)
  if type(row) ~= "table" or row.kind ~= "category" then
    return nil
  end
  return Nearest.KindOf(row.category)
end

--- Whether a tree row is the "Sold by" group's header. Pure.
function Nearest.IsSoldBy(row)
  return Nearest.GroupKind(row) == "vendor"
end

--- Brief PR34: whether a tree row is the "Trainer" group's header. Pure.
function Nearest.IsTrainer(row)
  return Nearest.GroupKind(row) == "trainer"
end

--- The vendor edges a "Sold by" group stands for (and the trainer edges a "Trainer" group does),
--- one per NPC key in the group's own order:
--- every entry that names an npc, and a shipped summary's whole list through moreEdgesOf(summary)
--- (Core/EraSources.lua E:MoreEdges), which is only asked where it is handed. A requirement, a
--- guess (a vendor nobody has seen sell it) and the unnamed Forever row are left out. Pure over
--- what it is handed.
function Nearest.VendorEdges(entries, moreEdgesOf)
  local out, seen = {}, {}
  local function add(edge)
    if type(edge) ~= "table" or edge.requirement or edge.guess ~= nil then
      return
    end
    local key = edge.target
    if type(key) ~= "string" or key:sub(1, 4) ~= "npc:" or key == Nearest.UNNAMED_KEY or seen[key] then
      return
    end
    seen[key] = true
    out[#out + 1] = edge
  end
  for _, entry in ipairs(type(entries) == "table" and entries or EMPTY) do
    local summary = type(entry) == "table" and not entry.requirement and entry.summary or nil
    if type(summary) == "table" then
      if (tonumber(summary.listed) or 0) > 0 and type(moreEdgesOf) == "function" then
        local ok, edges = pcall(moreEdgesOf, summary)
        for _, edge in ipairs(ok and type(edges) == "table" and edges or EMPTY) do
          add(edge)
        end
      end
    else
      add(entry)
    end
  end
  return out
end

local function hypot(dx, dy)
  return math.sqrt(dx * dx + dy * dy)
end

local function number(value)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge or value == -math.huge then
    return nil
  end
  return value
end

-- One point's tier against the player's place, and the distance it ranks by inside that tier.
-- The second answer is the distance in yards where one is known, or nil.
local function measure(player, point)
  local px, py = number(player.x), number(player.y)
  local x, y = number(point.x), number(point.y)
  local pwx, pwy = number(player.wx), number(player.wy)
  local wx, wy = number(point.wx), number(point.wy)
  local world = (pwx and pwy and wx and wy) and hypot(wx - pwx, wy - pwy) or nil
  if point.mapID ~= nil and point.mapID == player.mapID and px and py and x and y then
    if world then
      return Nearest.SAME_ZONE, world, world
    end
    -- Map space, scaled to yards where the map's size is known.
    local width, height = number(player.width), number(player.height)
    if width and height and width > 0 and height > 0 then
      local yards = hypot((x - px) * width, (y - py) * height)
      return Nearest.SAME_ZONE, yards, yards
    end
    return Nearest.SAME_ZONE, hypot(x - px, y - py), nil
  end
  if player.continent ~= nil and point.continent == player.continent then
    return Nearest.SAME_CONTINENT, world or math.huge, world
  end
  -- Another continent: no straight line means anything, so the world figure only breaks ties.
  return Nearest.OTHER_CONTINENT, world or math.huge, nil
end

-- A vendor's points: its own list, or the vendor itself where it carries one place.
local function pointsOf(vendor)
  if type(vendor.points) == "table" then
    return vendor.points
  end
  if vendor.mapID ~= nil then
    return { vendor }
  end
  return EMPTY
end

--- The nearest friendly or neutral vendor to the player, or nil for none.
---
---   player   { mapID, x, y, continent, wx, wy, width?, height? }: x and y in 0 to 1 on mapID,
---            wx and wy the world place in yards, width and height the map's size in yards
---   vendors  a list of { key, name, faction, points = { { mapID, x, y, continent, wx, wy } } },
---            or a vendor carrying one place's fields itself
---   faction  the player's side, "Alliance" or "Horde", or nil (then nobody is filtered)
---
--- Same zone first (world yards, else map space scaled to yards where the map's size is known),
--- then the same continent by world distance, then the nearest other continent. Answers
--- { best, point, tier, sameZone, sameContinent, distance }, distance in yards or nil where no
--- straight line is known. Ties keep the list's order. Pure.
function Nearest.Pick(player, vendors, faction)
  if type(player) ~= "table" or player.mapID == nil or type(vendors) ~= "table" then
    return nil
  end
  local best, bestPoint, bestTier, bestRank, bestYards = nil, nil, nil, nil, nil
  for _, vendor in ipairs(vendors) do
    if type(vendor) == "table" and Nearest.Friendly(vendor.faction, faction) then
      for _, point in ipairs(pointsOf(vendor)) do
        if type(point) == "table" and point.mapID ~= nil then
          local tier, rank, yards = measure(player, point)
          local better = best == nil or tier < bestTier or (tier == bestTier and rank < bestRank)
          if better then
            best, bestPoint, bestTier, bestRank, bestYards = vendor, point, tier, rank, yards
          end
        end
      end
    end
  end
  if not best then
    return nil
  end
  return {
    best = best,
    point = bestPoint,
    tier = bestTier,
    sameZone = bestTier == Nearest.SAME_ZONE,
    sameContinent = bestTier ~= Nearest.OTHER_CONTINENT,
    distance = bestYards,
  }
end

--- A distance in yards as the result line prints it: to the nearest 10 under 1,000 (never under
--- 10), to the nearest 100 from there, with a comma for the thousands. nil for no number. Pure.
function Nearest.Yards(yards)
  yards = number(yards)
  if not yards or yards < 0 then
    return nil
  end
  local step = yards < 1000 and 10 or 100
  local rounded = math.max(10, math.floor(yards / step + 0.5) * step)
  local text = string.format("%d", rounded)
  local head = #text % 3
  if head == 0 then
    head = 3
  end
  local out = text:sub(1, head)
  for at = head + 1, #text, 3 do
    out = out .. "," .. text:sub(at, at + 2)
  end
  return out
end

-- The line under the result in the button's tooltip.
Nearest.STRAIGHT_LINE = L["Straight line; flight paths and roads are not counted."]
-- The button's own words and its tooltip before any press.
Nearest.BUTTON_TEXT = L["Show nearest"]
Nearest.HINT = L["Finds the nearest vendor that sells this and sets a waypoint."]

-- Why there is no answer, in the words the tooltip and chat say.
Nearest.NO_POSITION = L["No position known for these vendors."]
Nearest.NO_PLAYER = L["Your own position is not available here, for example inside a dungeon."]
Nearest.NO_FRIENDLY = L["No vendor on your side has a known position."]

-- Brief PR34: the words that name the kind of NPC, per kind. The rest are the same for both.
Nearest.WORDS = {
  vendor = {
    hint = Nearest.HINT,
    noPosition = Nearest.NO_POSITION,
    noFriendly = Nearest.NO_FRIENDLY,
    name = L["Vendor"],
  },
  trainer = {
    hint = L["Finds the nearest trainer who teaches this and sets a waypoint."],
    noPosition = L["No position known for these trainers."],
    noFriendly = L["No trainer on your side has a known position."],
    name = L["Trainer"],
  },
}

--- Brief PR34: the words for one kind ("vendor" or "trainer"); the vendor's for any other. Pure.
function Nearest.Words(kind)
  return Nearest.WORDS[kind] or Nearest.WORDS.vendor
end

--- The result line for a Pick answer, or the no position line for nil. kind ("vendor", the default,
--- or "trainer") picks the words that name the NPC. Pure.
---   "Nearest: Indari Sunseam, Zephras Isle (about 400 yards)"
---   "Nearest: X, Elwynn Forest (another zone, about 1,200 yards)"
---   "None on this continent. Nearest: X, Stormwind City (Eastern Kingdoms)"
function Nearest.ResultText(result, kind)
  local words = Nearest.Words(kind)
  if type(result) ~= "table" or type(result.best) ~= "table" then
    return words.noPosition
  end
  local point = type(result.point) == "table" and result.point or EMPTY
  local name = type(result.best.name) == "string" and result.best.name ~= "" and result.best.name or words.name
  local where = name
  if type(point.zone) == "string" and point.zone ~= "" then
    where = string.format(L["%s, %s"], name, point.zone)
  end
  local yards = Nearest.Yards(result.distance)
  if result.sameZone then
    if yards then
      return string.format(L["Nearest: %s (about %s yards)"], where, yards)
    end
    return string.format(L["Nearest: %s"], where)
  end
  if result.sameContinent then
    if yards then
      return string.format(L["Nearest: %s (another zone, about %s yards)"], where, yards)
    end
    return string.format(L["Nearest: %s (another zone)"], where)
  end
  if type(point.continentName) == "string" and point.continentName ~= "" then
    return string.format(L["None on this continent. Nearest: %s (%s)"], where, point.continentName)
  end
  return string.format(L["None on this continent. Nearest: %s"], where)
end

--- The waypoint a result points at, in the shape UI/Map.lua Map.SetWaypoint takes ({ map, x, y },
--- x and y in 0 to 1), or nil. Pure.
function Nearest.WaypointOf(result)
  local point = type(result) == "table" and result.point or nil
  if type(point) ~= "table" or type(point.mapID) ~= "number" then
    return nil
  end
  local x, y = number(point.x), number(point.y)
  if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then
    return nil
  end
  return { map = point.mapID, x = x, y = y }
end

--- Brief UX1 (QA item 402): what the waypoint a find set is for, the words the "Waypoint added" toast
--- says: the NPC it found and the kind of NPC it is, "Randal Worth, nearest trainer" or "Tharynn
--- Bouden, nearest vendor". found is Nearest.Find's answer; nil where it names no one. Pure.
function Nearest.WaypointFor(found)
  local result = type(found) == "table" and found.result or nil
  local best = type(result) == "table" and result.best or nil
  local name = type(best) == "table" and best.name or nil
  if type(name) ~= "string" or name == "" then
    return nil
  end
  if found.kind == "trainer" then
    return string.format(L["%s, nearest trainer"], name)
  end
  return string.format(L["%s, nearest vendor"], name)
end

-- Brief NR1b (QA item 134): one rank and side aware ranking for every trainer "Show nearest" (the
-- Professions panel's and the trainer search divider's, both through Nearest.FindTrainer). A trainer
-- edge may carry steps = { [step] = true }, the ranks it teaches (1 Apprentice to 4 Artisan): the
-- Classic Era trainer table's rank spells, or a Forever trainer's top rank (Creatures tk) and every
-- rank below it. An edge with no steps is unknown, and unknown is eligible.

-- The caps each step trains to, Apprentice to Artisan.
Nearest.STEP_CAPS = { 75, 150, 225, 300 }

--- The step the player trains next in a profession: 1 (Apprentice) where they do not have it, else
--- the step above the cap they hold (max; a cap of 75 gives 2, Journeyman), or nil at 300 where
--- nothing is left to train. Where no cap is known the rank's own band stands for it. Pure.
function Nearest.NextStep(rank, max)
  rank, max = number(rank), number(max)
  if not rank and not max then
    return 1
  end
  if not max or max <= 0 then
    max = nil
    for _, cap in ipairs(Nearest.STEP_CAPS) do
      if (rank or 0) <= cap then
        max = cap
        break
      end
    end
    max = max or 300
  end
  for step, cap in ipairs(Nearest.STEP_CAPS) do
    if cap > max then
      return step
    end
  end
  return nil
end

--- Whether a trainer edge teaches a step: true, false (its ranks are known and that one is not
--- among them) or nil (nothing says). No step (nothing left to train) is true for everyone. Pure.
function Nearest.Teaches(edge, step)
  if step == nil then
    return true
  end
  local steps = type(edge) == "table" and edge.steps or nil
  if type(steps) ~= "table" then
    return nil
  end
  return steps[step] == true
end

--- The edges that may teach a step (Nearest.Teaches not false), in their order. Pure.
function Nearest.Eligible(edges, step)
  local out = {}
  for _, edge in ipairs(type(edges) == "table" and edges or EMPTY) do
    if Nearest.Teaches(edge, step) ~= false then
      out[#out + 1] = edge
    end
  end
  return out
end

-- The muted words after the line where the nearest trainer is not known to teach the next rank.
Nearest.FALLBACK_NOTE = L["(may not teach your next rank: none who does has a known position)"]

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

local function eraReader()
  local reader = ItemTree.eraSources
  return type(reader) == "table" and reader or nil
end

local function ask(target, method, ...)
  if type(target) ~= "table" or type(target[method]) ~= "function" then
    return nil
  end
  local ok, a, b, c = pcall(target[method], target, ...)
  if ok then
    return a, b, c
  end
  return nil
end

-- One pin in percent ({ map, x, y } with x and y 0 to 100) as a point in 0 to 1, or nil.
local function percentPoint(map, x, y, zone)
  x, y = number(x), number(y)
  if type(map) ~= "number" or not x or not y or x < 0 or x > 100 or y < 0 or y > 100 then
    return nil
  end
  return { mapID = map, x = x / 100, y = y / 100, zone = zone }
end

-- The Classic Era pins one vendor key names, as points. A key that states an area keeps that
-- area's pins, where it has any. decode false only answers whether there are any.
local function eraPoints(key, decode)
  local module = ItemTree.EraSources
  local era = eraReader()
  if type(module) ~= "table" or not era or type(era.PinSubject) ~= "function" then
    return EMPTY, nil
  end
  -- Brief EK1: the reader's PinSubject, which reads a creature page key's name out of the table.
  local ok, field, nameIndex, areaId = pcall(era.PinSubject, era, key)
  if not ok or field ~= "mp" or type(nameIndex) ~= "number" then
    return EMPTY, nil
  end
  local faction = ask(era, "Faction", nameIndex)
  if not decode then
    return ask(era, "HasPins", nameIndex) == true and { true } or EMPTY, faction
  end
  -- The pure decode rather than E:PinsOf, so a press does not empty the Map tab's small cache.
  local source = ask(era, "Table")
  if type(source) ~= "table" or type(module.PinsOf) ~= "function" then
    return EMPTY, faction
  end
  local fine, pins = pcall(module.PinsOf, source, nameIndex)
  if not fine or type(pins) ~= "table" then
    return EMPTY, faction
  end
  local all, own = {}, {}
  for _, pin in ipairs(pins) do
    local point = type(pin) == "table" and percentPoint(pin.map, pin.x, pin.y) or nil
    if point then
      all[#all + 1] = point
      if areaId ~= nil and pin.area == areaId then
        own[#own + 1] = point
      end
    end
  end
  return #own > 0 and own or all, faction
end

-- The Forever client table's place for one vendor key, as points, only where the module is built.
local function foreverPoints(key)
  local forever = ItemTree.ForeverVendors
  local graph = ItemTree.Graph
  if type(forever) ~= "table" or type(forever.Loaded) ~= "function" or type(graph) ~= "table" then
    return EMPTY
  end
  local kind, npcId = graph.Parse(key)
  if kind ~= "npc" or type(npcId) ~= "number" or npcId <= 0 then
    return EMPTY
  end
  local ok, source = pcall(forever.Loaded)
  if not ok or type(source) ~= "table" or type(forever.VendorAt) ~= "function" then
    return EMPTY
  end
  local found, vendor = pcall(forever.VendorAt, source, npcId)
  if not found or type(vendor) ~= "table" or type(forever.Place) ~= "function" then
    return EMPTY
  end
  local placed, zone, uiMap = pcall(forever.Place, vendor.a)
  if not placed then
    return EMPTY
  end
  local x, y = number(vendor.x), number(vendor.y)
  if type(uiMap) ~= "number" or not x or not y then
    return EMPTY
  end
  local point = percentPoint(uiMap, x * 100, y * 100, zone)
  return point and { point } or EMPTY
end

-- The Merchant's Favour place for one vendor key (the player's own sighting first), as points,
-- and the curated side.
local function favourPoints(key)
  local sources = ItemTree.Sources
  local favour = type(sources) == "table" and sources.Favour or nil
  if type(favour) ~= "table" or type(favour.Positions) ~= "function" then
    return EMPTY, nil
  end
  local shipped = nil
  if type(favour.VendorFacts) == "function" then
    local ok, facts = pcall(favour.VendorFacts, key)
    shipped = ok and type(facts) == "table" and facts or nil
  end
  local collected = ask(ItemTree.collector, "NpcFacts", key)
  if type(collected) ~= "table" then
    collected = nil
  end
  local ok, positions = pcall(favour.Positions, shipped, collected)
  local out = {}
  for _, pin in ipairs(ok and type(positions) == "table" and positions or EMPTY) do
    local point = type(pin) == "table" and percentPoint(pin.map, pin.x, pin.y, pin.zone) or nil
    if point then
      out[#out + 1] = point
    end
  end
  return out, shipped and shipped.faction or nil
end

-- Brief TR1c: where our own records or an owner confirmed claim place an npc key, as points:
-- PlayerSources' shipped spots (each cell's centre; ours), else the Creatures data's approximate
-- claim cells (shipped only where ours place it nowhere), so "Show nearest" routes to a trainer
-- the stored claims place (Gorg, Grungle) and one a mine replaced. Reads only modules already built
-- (Loaded), so asking never loads anything.
local function ownPoints(key)
  local graph = ItemTree.Graph
  if type(graph) ~= "table" or type(graph.Parse) ~= "function" then
    return EMPTY
  end
  local parsed, kind, npcId = pcall(graph.Parse, key)
  if not parsed or kind ~= "npc" or type(npcId) ~= "number" or npcId <= 0 then
    return EMPTY
  end
  local out = {}
  local players = ItemTree.PlayerSources
  if type(players) == "table" and type(players.Loaded) == "function" and type(players.Spots) == "function" then
    local ok, source = pcall(players.Loaded)
    local fine, spots = pcall(players.Spots, ok and source or nil, npcId)
    for _, spot in ipairs(fine and type(spots) == "table" and spots or EMPTY) do
      for _, cell in ipairs(type(spot.cells) == "table" and spot.cells or EMPTY) do
        local x, y = nil, nil
        if type(players.CellCentre) == "function" then
          x, y = players.CellCentre(cell.cell)
        end
        local point = percentPoint(spot.map, x, y)
        if point then
          out[#out + 1] = point
        end
      end
    end
  end
  if #out > 0 then
    return out
  end
  local creatures = ItemTree.Creatures
  if type(creatures) ~= "table" or type(creatures.Loaded) ~= "function" or type(creatures.Decode) ~= "function" then
    return EMPTY
  end
  local ok, source = pcall(creatures.Loaded)
  local fine, row = pcall(creatures.Decode, ok and source or nil, npcId)
  local pins = EMPTY
  if fine and type(row) == "table" and type(creatures.ClaimPins) == "function" then
    pins = creatures.ClaimPins(row.claimSpots, row.name)
  end
  for _, pin in ipairs(pins) do
    local point = percentPoint(pin.map, pin.x, pin.y)
    if point then
      point.approx = true
      out[#out + 1] = point
    end
  end
  return out
end

--- Every place our data holds for one vendor edge, as points ({ mapID, x, y, zone? } with x and y
--- in 0 to 1), and the vendor's side. decode false asks only whether there is one, decoding
--- nothing (what the header asks on every draw). Guarded.
function Nearest.VendorPoints(edge, decode)
  local key = type(edge) == "table" and edge.target or nil
  if type(key) ~= "string" then
    return EMPTY, nil
  end
  local out = {}
  local faction = edge.faction
  for _, point in ipairs(foreverPoints(key)) do
    out[#out + 1] = point
  end
  if decode == false and #out > 0 then
    return out, faction
  end
  local favour, favourSide = favourPoints(key)
  for _, point in ipairs(favour) do
    out[#out + 1] = point
  end
  faction = faction or favourSide
  if decode == false and #out > 0 then
    return out, faction
  end
  -- Brief TR1c: our own shipped spots, else an owner confirmed claim's approximate position.
  for _, point in ipairs(ownPoints(key)) do
    out[#out + 1] = point
  end
  if decode == false and #out > 0 then
    return out, faction
  end
  -- Brief EK1 2b: a merged page's key (npc:<id>, a positive id) is the client's vendor and the
  -- Classic Era one at once. Brief EK2 (the EK1 review's follow up): it takes the UNION, the client's
  -- or the curated file's places and its Classic Era pins together, so a merged vendor the client
  -- places in one spot and Classic Era in others is found at whichever is nearest, as the two pages
  -- were before they were one. A Classic Era key of its own (a negative id) takes every place, as it
  -- always has.
  local era, eraSide = eraPoints(key, decode ~= false)
  for _, point in ipairs(era) do
    out[#out + 1] = point
  end
  return out, faction or eraSide
end

-- What a "Sold by" group's summaries open onto, through the Classic Era reader. Guarded.
local function moreEdges(summary)
  local era = eraReader()
  local edges = ask(era, "MoreEdges", summary.item, summary.category)
  return type(edges) == "table" and edges or EMPTY
end

-- The answer Nearest.Shows gave per group, kept against the group's table (weak) and the number
-- of its entries the view shows, so a new root or a change to what is shown asks again.
Nearest.shown = setmetatable({}, { __mode = "k" })

--- Whether a "Sold by" (or, brief PR34, "Trainer") group has at least one NPC with a known
--- position, so the header draws the button. visible(entries) is the view model's own filter of
--- what it shows, where handed.
--- The group's own vendors are asked first, decoding nothing; a summary's list is decoded only
--- where none of them has a place. Kept per group. Guarded.
function Nearest.Shows(category, visible)
  if Nearest.KindOf(category) == nil then
    return false
  end
  local entries = category.entries
  if type(visible) == "function" then
    local ok, shown = pcall(visible, entries)
    entries = ok and type(shown) == "table" and shown or entries
  end
  entries = type(entries) == "table" and entries or EMPTY
  local held = Nearest.shown[category]
  if held and held.count == #entries then
    return held.answer
  end
  local answer = false
  for _, edge in ipairs(Nearest.VendorEdges(entries)) do
    if #Nearest.VendorPoints(edge, false) > 0 then
      answer = true
      break
    end
  end
  if not answer then
    for _, edge in ipairs(Nearest.VendorEdges(entries, moreEdges)) do
      if #Nearest.VendorPoints(edge, false) > 0 then
        answer = true
        break
      end
    end
  end
  Nearest.shown[category] = { count = #entries, answer = answer }
  return answer
end

local function mapApi()
  local api = rawget(_G, "C_Map")
  return type(api) == "table" and api or nil
end

local function vectorXY(vector)
  if type(vector) ~= "table" then
    return nil, nil
  end
  if type(vector.GetXY) == "function" then
    local ok, x, y = pcall(vector.GetXY, vector)
    if ok then
      return number(x), number(y)
    end
  end
  return number(vector.x), number(vector.y)
end

local function newVector(x, y)
  local make = rawget(_G, "CreateVector2D")
  if type(make) == "function" then
    local ok, vector = pcall(make, x, y)
    if ok and type(vector) == "table" then
      return vector
    end
  end
  return { x = x, y = y }
end

-- Each pin's world place, kept for the session: "map:x:y" to { continent, wx, wy }, false for none.
Nearest.world = {}

--- The world place of one place on a zone map (x and y in 0 to 1): its continent id and its world
--- x and y in yards, through C_Map.GetWorldPosFromMapPos. Kept for the session. nil where the
--- client cannot say. Guarded.
function Nearest.WorldOf(mapID, x, y)
  if type(mapID) ~= "number" or not number(x) or not number(y) then
    return nil
  end
  local key = mapID .. ":" .. x .. ":" .. y
  local held = Nearest.world[key]
  if held ~= nil then
    return held or nil
  end
  local api = mapApi()
  local answer = false
  if api and type(api.GetWorldPosFromMapPos) == "function" then
    local ok, continent, world = pcall(api.GetWorldPosFromMapPos, mapID, newVector(x, y))
    if ok and continent ~= nil then
      local wx, wy = vectorXY(world)
      if wx and wy then
        answer = { continent = continent, wx = wx, wy = wy }
      end
    end
  end
  Nearest.world[key] = answer
  return answer or nil
end

local mapInfos = {}

local function mapInfo(mapID)
  if type(mapID) ~= "number" then
    return nil
  end
  local held = mapInfos[mapID]
  if held ~= nil then
    return held or nil
  end
  local info = false
  local api = mapApi()
  if api and type(api.GetMapInfo) == "function" then
    local ok, answer = pcall(api.GetMapInfo, mapID)
    if ok and type(answer) == "table" then
      info = { name = answer.name, mapType = answer.mapType, parent = answer.parentMapID }
    end
  end
  mapInfos[mapID] = info
  return info or nil
end

--- The client's name for a zone map, or nil. Guarded and kept.
function Nearest.ZoneName(mapID)
  local info = mapInfo(mapID)
  local name = info and info.name or nil
  return type(name) == "string" and name ~= "" and name or nil
end

--- The name of the continent a zone map sits in, walking the client's map parents up to the one
--- whose type is a continent. nil where the client cannot say. Guarded and kept.
function Nearest.ContinentName(mapID)
  local enum = rawget(_G, "Enum")
  local types = type(enum) == "table" and enum.UIMapType or nil
  local continentType = type(types) == "table" and types.Continent or 2
  local at, steps = mapID, 0
  while type(at) == "number" and steps < 8 do
    local info = mapInfo(at)
    if not info then
      return nil
    end
    if info.mapType == continentType then
      return type(info.name) == "string" and info.name ~= "" and info.name or nil
    end
    at, steps = info.parent, steps + 1
  end
  return nil
end

-- Brief DM1: the pretend position (/itemtree demo at, Core/Demo.lua Demo.At) as { map, x, y }, x
-- and y in 0 to 100, or nil while the character's own stands.
local function demoAt()
  local demo = ItemTree.Demo
  if type(demo) ~= "table" or type(demo.At) ~= "function" then
    return nil
  end
  local ok, at = pcall(demo.At)
  if ok and type(at) == "table" and type(at.map) == "number" and number(at.x) and number(at.y) then
    return at
  end
  return nil
end

--- Where the player stands: { mapID, x, y, continent, wx, wy, width, height }, or nil where the
--- client does not say (inside an instance, say). Brief DM1: the pretend position (`/itemtree demo
--- at`) while it is set, never the character's own. Guarded.
function Nearest.PlayerPosition()
  local api = mapApi()
  local mapID, x, y
  local at = demoAt()
  if at then
    mapID, x, y = at.map, at.x / 100, at.y / 100
  else
    if not api or type(api.GetBestMapForUnit) ~= "function" or type(api.GetPlayerMapPosition) ~= "function" then
      return nil
    end
    local ok, best = pcall(api.GetBestMapForUnit, "player")
    if not ok or type(best) ~= "number" then
      return nil
    end
    local fine, position = pcall(api.GetPlayerMapPosition, best, "player")
    if not fine then
      return nil
    end
    mapID = best
    x, y = vectorXY(position)
    if not x or not y or (x == 0 and y == 0) then
      return nil
    end
  end
  local player = { mapID = mapID, x = x, y = y }
  local world = Nearest.WorldOf(mapID, x, y)
  if world then
    player.continent, player.wx, player.wy = world.continent, world.wx, world.wy
  end
  if api and type(api.GetMapWorldSize) == "function" then
    local sized, width, height = pcall(api.GetMapWorldSize, mapID)
    if sized then
      player.width, player.height = number(width), number(height)
    end
  end
  return player
end

local function graphName(key)
  local graph = ItemTree.Graph
  if type(graph) ~= "table" or type(graph.Name) ~= "function" then
    return nil
  end
  local ok, name = pcall(graph.Name, key)
  return ok and type(name) == "string" and name ~= "" and name or nil
end

--- The press: every vendor (or trainer) of the group with a known place, the player's own place,
--- and the pick. Answers { text, key, waypoint, result, kind }: text the line for the tooltip and
--- chat, key the NPC's key to open and waypoint the place to mark, both nil where there is no
--- answer, kind "vendor" or "trainer" by the group. opts: visible(entries) as Nearest.Shows takes
--- it, faction the player's side. Guarded.
function Nearest.Find(category, opts)
  opts = type(opts) == "table" and opts or EMPTY
  local kind = Nearest.KindOf(category) or "vendor"
  local entries = type(category) == "table" and category.entries or nil
  if type(opts.visible) == "function" then
    local ok, shown = pcall(opts.visible, entries)
    entries = ok and type(shown) == "table" and shown or entries
  end
  return Nearest.FindAmong(Nearest.VendorEdges(entries, moreEdges), kind, opts.faction)
end

--- Brief BQ24 (QA item 25): the press over a list of NPC edges ({ target = "npc:...", faction }),
--- the "Sold by" header's and the trainer search divider's alike: every one with a known place,
--- the player's own place, and the pick (friendly or neutral only, the player's zone first).
--- Answers Nearest.Find's shape. kind "vendor" or "trainer" picks the words. Guarded.
function Nearest.FindAmong(edges, kind, playerFaction)
  kind = Nearest.WORDS[kind] and kind or "vendor"
  local words = Nearest.Words(kind)
  local vendors = {}
  for _, edge in ipairs(type(edges) == "table" and edges or EMPTY) do
    local points, faction = Nearest.VendorPoints(edge, true)
    if #points > 0 then
      vendors[#vendors + 1] = { key = edge.target, faction = faction, points = points, edge = edge }
    end
  end
  if #vendors == 0 then
    return { text = words.noPosition, kind = kind }
  end
  local player = Nearest.PlayerPosition()
  if not player then
    return { text = Nearest.NO_PLAYER, kind = kind }
  end
  -- World places only for this item's own vendors, and only now.
  for _, vendor in ipairs(vendors) do
    for _, point in ipairs(vendor.points) do
      local world = Nearest.WorldOf(point.mapID, point.x, point.y)
      if world then
        point.continent, point.wx, point.wy = world.continent, world.wx, world.wy
      end
    end
  end
  local result = Nearest.Pick(player, vendors, playerFaction)
  if not result then
    return { text = words.noFriendly, kind = kind }
  end
  local best, point = result.best, result.point
  best.name = graphName(best.key) or (type(best.edge.name) == "string" and best.edge.name or nil)
  point.zone = Nearest.ZoneName(point.mapID) or point.zone
  if not result.sameContinent then
    point.continentName = Nearest.ContinentName(point.mapID)
  end
  return {
    text = Nearest.ResultText(result, kind),
    key = best.key,
    waypoint = Nearest.WaypointOf(result),
    result = result,
    kind = kind,
  }
end

-- The note in the muted colour where the theme is loaded, else plain.
local function muted(text)
  local theme = ItemTree.Theme
  if type(theme) == "table" and type(theme.Colorise) == "function" then
    local ok, coloured = pcall(theme.Colorise, "ITEMTREE_COLOR_TEXT_MUTED", text)
    if ok and type(coloured) == "string" then
      return coloured
    end
  end
  return text
end

-- Brief RB2 (owner QA 2026-10-17 item 205): `/itemtree demo at 1429 47.8 42.3`, `t:lw`, Show nearest
-- found Randal Worth in Stormwind rather than Hannah Peltskinner, 30 yards away in Northshire. Her
-- title says Junior (ItemTree-Data trainers.py: Apprentice only, Creatures tk 1), so a player who
-- holds Leatherworking trains Journeyman next and NR1b's rank rule rightly passes her over; the line
-- never said so. Now it does: where the nearest trainer of any rank is nearer than the one found
-- and does not teach the next rank, the line ends "(Hannah Peltskinner is nearer but does not teach
-- Journeyman)" in the muted colour. The rank names, Apprentice to Artisan, by step.
Nearest.STEP_NAMES = { L["Apprentice"], L["Journeyman"], L["Expert"], L["Artisan"] }

--- Brief RB2: whether a Pick answer a stands nearer the player than b: a better tier (the player's
--- zone, then continent), or the same tier and fewer yards where both state yards. Pure.
function Nearest.Nearer(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return false
  end
  local at, bt = tonumber(a.tier), tonumber(b.tier)
  if not at or not bt then
    return false
  end
  if at ~= bt then
    return at < bt
  end
  local ad, bd = number(a.distance), number(b.distance)
  return ad ~= nil and bd ~= nil and ad < bd
end

--- Brief RB2: adds to found (a FindAmong answer over the trainers who may teach the next rank) the
--- nearest trainer of any rank among edges where that one stands nearer (Nearest.Nearer) and is
--- known not to teach step: found.nearer its key, found.note the words, found.text the line with
--- the words after it, muted. found as it was otherwise. Guarded.
function Nearest.NoteNearer(found, edges, faction, step)
  local rank = Nearest.STEP_NAMES[tonumber(step) or 0]
  if type(found) ~= "table" or type(found.key) ~= "string" or not rank then
    return found
  end
  local ok, any = pcall(Nearest.FindAmong, edges, "trainer", faction)
  local best = ok and type(any) == "table" and type(any.result) == "table" and any.result.best or nil
  if type(best) ~= "table" or any.key == found.key or not Nearest.Nearer(any.result, found.result) then
    return found
  end
  if Nearest.Teaches(best.edge, step) ~= false or type(best.name) ~= "string" or best.name == "" then
    return found
  end
  found.nearer = any.key
  found.note = string.format(L["(%s is nearer but does not teach %s)"], best.name, rank)
  found.text = found.text .. " " .. muted(found.note)
  return found
end

--- Brief NR1b: the one trainer press both paths use. Among the edges (each { target, faction,
--- name, steps? }), the nearest friendly or neutral trainer (Nearest.FindAmong: the player's side or
--- both, then the player's zone, continent, the rest) of those who may teach the player's next rank
--- (opts.step, 1 to 4, nil where nothing is left to train); where none of them has a known place,
--- the nearest of any rank, its line followed by a muted note (fallback = true). opts = { faction
--- ("Alliance" or "Horde"), step }. Answers Nearest.Find's shape with step. Guarded.
function Nearest.FindTrainer(edges, opts)
  opts = type(opts) == "table" and opts or EMPTY
  edges = type(edges) == "table" and edges or EMPTY
  local step = tonumber(opts.step)
  local eligible = Nearest.Eligible(edges, step)
  local found = nil
  if #eligible > 0 then
    found = Nearest.FindAmong(eligible, "trainer", opts.faction)
    if type(found.key) == "string" or found.text == Nearest.NO_PLAYER then
      found.step = step
      -- Brief RB2: and the nearer trainer it passed over, where one stands nearer.
      if #eligible < #edges and type(found.key) == "string" then
        Nearest.NoteNearer(found, edges, opts.faction, step)
      end
      return found
    end
  end
  if #eligible == #edges and found then
    found.step = step
    return found
  end
  local any = Nearest.FindAmong(edges, "trainer", opts.faction)
  any.step = step
  local best = type(any.result) == "table" and any.result.best or nil
  if type(any.key) == "string" and type(best) == "table" and Nearest.Teaches(best.edge, step) == false then
    any.fallback = true
    any.note = Nearest.FALLBACK_NOTE
    any.text = any.text .. " " .. muted(Nearest.FALLBACK_NOTE)
  end
  return any
end
