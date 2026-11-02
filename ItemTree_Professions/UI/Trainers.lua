-- The Professions tab's "Trainers & vendors" button and panel (brief PR15). The owner's words: when
-- the player needs to unlock the next rank of a profession, show the NPCs who can teach it, and the
-- vendors of the recipes for the player's level.
--
-- The button sits at the top of the tab, left of the zoom controls. Brief PR17: it is the window's
-- shared red plate button (Frame.NewPlateButton through UI/Skin.lua Skin.PlateButton, the art the
-- Recent button wears), its words on the plate's child frame above the additive highlight. When
-- the player is at their cap (rank == max, max < 300) it glows and reads "Train Journeyman", so
-- the unlock is obvious. A click opens a panel over the canvas, anchored top right, with a close button, 12 px
-- of padding inside and a gap between its sections:
--
--   Trainers for Journeyman Cooking   the trainers who teach the next rank's own spell, the
--                                     player's side first, then an "Other faction" heading (the
--                                     no dim rule: nothing is greyed, the other side is grouped).
--                                     Brief F155: while "Hide other faction data" is on (the
--                                     default) one muted line stands in for that group, "4 Horde
--                                     trainers hidden", and the same for a recipe's vendors
--   Recipe items                      every recipe of the current and the next band whose teaching
--                                     item (`by`) a vendor sells: the item, then its vendors, the
--                                     client's own vendor list first (ForeverVendors), then the
--                                     original game's
--   Trainers and vendors are from the original game and may differ here.   (one sentence, wrapped)
--
-- Every trainer and vendor row opens that NPC's page (the N2 page, the pane's own Click), and a row
-- whose NPC has exactly one position carries the N4 waypoint button (UI/InfoPanel.lua WaypointOf,
-- CanWaypoint, SetWaypoint, the page's own Where row calls).
--
-- The rank spells. Our shipped data names no rank spell: ProfessionTracks and the build's recipe
-- tables list recipes only, and SpellNames.lua does not carry "Cooking" (3102). The ids below are
-- the build's own: SpellEffect of 1.60.1.70009 (ItemTree-Data builds/1.60.1.70009/SpellEffect.csv)
-- gives each of them the SKILL_STEP effect (118) with the skill line as its misc value and the step
-- as its base points (2 Journeyman, 3 Expert, 4 Artisan), and Spell.csv's NameSubtext says the same
-- tier. The trainer table (EraSources `tr`) lists every one of them under its trainers except five
-- (Expert and Artisan Cooking and First Aid, Expert Fishing), which the original game taught from
-- a book; BOOKS names the six rank books, again out of the build (ItemEffect and ItemXItemEffect:
-- the item's spell carries LEARN_SPELL, effect 36, of the rank spell). Artisan Fishing has both.
-- tests/spec/professions_trainers_spec.lua checks both against the real shipped data.
-- Where a rank spell has no trainer the panel falls back to "trainers who teach this profession"
-- (every trainer teaching any recipe or rank spell of the line) and says so.
--
-- Load cost: the trainer and vendor tables live in ItemTree_Data (load on demand). Nothing here
-- reads them until the button is clicked; the click loads them through Data:Get, as other panes
-- do. No item query in bulk: names come from our data, and only the rows on screen ask for an
-- icon (Assets.ItemIcon, a local read).
--
-- Everything above the "Client side" divider is pure and runs under busted with no WoW API.
local _, ItemTree = ...
-- ItemTree_Professions is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Modules) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end

local Trainers = {}
ItemTree.ProfessionsTrainers = Trainers

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

local themeSizes = ItemTree.ProfessionsKit.ThemeSizes

local SIZES = themeSizes()

Trainers.CAP = 300
Trainers.BUTTON_H = SIZES.ITEMTREE_CONTROL_H_SM or 20
Trainers.BUTTON_MIN_W = 96
Trainers.BUTTON_PAD = 12
Trainers.PANEL_W = SIZES.ITEMTREE_PROFESSION_TRAINERS_W or 330
Trainers.ROW_H = SIZES.ITEMTREE_PROFESSION_TRAINERS_ROW_H or 20
Trainers.ICON = SIZES.ITEMTREE_ICON_CATEGORY or 16
Trainers.PIN = 14
Trainers.CLOSE = 20
Trainers.PAD = SIZES.ITEMTREE_SPACE_2 or 8
-- Brief PR16: the panel's inner padding, the room above each section after the first, and the
-- footer's wrapped sentence (two lines at the small font).
Trainers.INNER = 12
Trainers.SECTION_GAP = 8
Trainers.FOOTER_H = 30
Trainers.INDENT = 12
Trainers.ZONE_W = 116
Trainers.FONT_MD = 12
Trainers.FONT_SM = 11
Trainers.CHAR_W = 6.2
Trainers.FONT_TEMPLATE = "GameFontNormalSmall"
Trainers.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }

-- Colours, all Theme keys.
Trainers.CARD_GOLD = "ITEMTREE_COLOR_PROFESSION_CARD_GOLD"
Trainers.BUTTON_WORD = "ITEMTREE_COLOR_TEXT_TITLE"
Trainers.PANEL_FILL = "ITEMTREE_COLOR_PROFESSION_PANEL_FILL"
Trainers.FACE = "ITEMTREE_COLOR_BUTTON_FACE"
Trainers.BORDER = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
Trainers.GOLD_BORDER = "ITEMTREE_COLOR_PROFESSION_ROUTE_GOLD"
Trainers.HOVER = "ITEMTREE_COLOR_STATE_HOVER"
Trainers.HEADING_WORD = "ITEMTREE_COLOR_BAND_WORD"
Trainers.NAME_WORD = "ITEMTREE_COLOR_TEXT_BODY"
Trainers.MUTED_WORD = "ITEMTREE_COLOR_TEXT_MUTED"

-- The tiers, each with its step (SKILL_STEP's base points) and the cap it trains to.
Trainers.TIERS = {
  { step = 1, cap = 75, name = L["Apprentice"] },
  { step = 2, cap = 150, name = L["Journeyman"] },
  { step = 3, cap = 225, name = L["Expert"] },
  { step = 4, cap = 300, name = L["Artisan"] },
}

-- The rank spells by skill line, Journeyman, Expert and Artisan in that order (steps 2, 3 and 4).
-- See the header for where every id comes from.
Trainers.RANKS = {
  [129] = { 3274, 7924, 10846 }, -- First Aid
  [164] = { 3100, 3538, 9785 }, -- Blacksmithing
  [165] = { 3104, 3811, 10662 }, -- Leatherworking
  [171] = { 3101, 3464, 11611 }, -- Alchemy
  [182] = { 2368, 3570, 11993 }, -- Herbalism
  [185] = { 3102, 3413, 18260 }, -- Cooking
  [186] = { 2576, 3564, 10248 }, -- Mining
  [197] = { 3909, 3910, 12180 }, -- Tailoring
  [202] = { 4037, 4038, 12656 }, -- Engineering
  [333] = { 7412, 7413, 13920 }, -- Enchanting
  [356] = { 7731, 7732, 18248 }, -- Fishing
  [393] = { 8617, 8618, 10768 }, -- Skinning
}

-- The book that teaches a rank spell, where the original game taught it from one.
Trainers.BOOKS = {
  [7924] = 16084, -- Expert First Aid - Under Wraps
  [10846] = 16085, -- Artisan First Aid - Heal Thyself
  [3413] = 16072, -- Expert Cookbook
  [18260] = 16073, -- Artisan Cookbook
  [7732] = 16083, -- Expert Fishing - The Bass and You
  [18248] = 16082, -- Artisan Fishing - The Way of the Lure
}

Trainers.WORDS = {
  button = L["Trainers & vendors"],
  train = L["Train %s"],
  rankName = L["%s %s"],
  trainersFor = L["Trainers for %s"],
  noTrainerFor = L["No trainer teaches %s."],
  lineTrainers = L["These trainers teach %s."],
  learntFrom = L["%s is learnt from this item."],
  otherFaction = L["Other faction"],
  noTrainer = L["No trainer known yet"],
  soldBy = L["Sold by"],
  recipes = L["Recipes sold for %d to %d"],
  noRecipes = L["No recipe for these levels is sold by a vendor."],
  unnamed = L["Sold by a vendor (not yet named by the client)"],
  more = L["And %d more, on its page"],
  noVendor = L["No vendor known yet"],
  footer = L["Trainers and vendors are from the original game and may differ here."],
  failed = L["Trainer and vendor data could not be loaded."],
  loading = L["Loading trainers and vendors."],
  item = L["Item %d"],
  undiscovered = L["Undiscovered item"],
  openPage = L["Click to open its page"],
  waypoint = L["Set waypoint"],
  close = L["Close"],
  hint = L["Who teaches the next rank, and who sells the recipes for your level."],
  alliance = L["Alliance"],
  horde = L["Horde"],
  -- Brief BQ25b (owner QA 2026-10-10 item 55): the trainer search divider's button and words.
  showNearest = L["Show nearest"],
  nearestAt = L["Nearest: %s"],
  nearestHint = L["Finds the nearest of these trainers and sets a waypoint."],
}

--------------------------------------------------------------------------------
-- Pure
--------------------------------------------------------------------------------

--- The tier the next training opens for a cap: 75 gives Journeyman, 150 Expert, 225 Artisan, and
--- 300 (or no cap, or one below Apprentice's) nothing. Pure.
function Trainers.NextTier(max)
  max = tonumber(max)
  if not max or max <= 0 then
    return nil
  end
  for _, tier in ipairs(Trainers.TIERS) do
    if tier.cap > max then
      if tier.step < 2 then
        return nil
      end
      return tier
    end
  end
  return nil
end

--- The rank spell a tier of a line trains, or nil. Pure.
function Trainers.RankSpell(line, tier)
  local list = Trainers.RANKS[tonumber(line)]
  if type(list) ~= "table" or type(tier) ~= "table" then
    return nil
  end
  return list[(tonumber(tier.step) or 0) - 1]
end

--- "Journeyman Cooking". Pure.
function Trainers.RankName(tier, lineName)
  return string.format(Trainers.WORDS.rankName, tostring(tier and tier.name or ""), tostring(lineName or ""))
end

--- Whether the player is at their cap with a rank still to train. Pure.
function Trainers.AtCap(rank, max)
  rank, max = tonumber(rank), tonumber(max)
  if not rank or not max or max >= Trainers.CAP then
    return false
  end
  return rank >= max and Trainers.NextTier(max) ~= nil
end

--- The button's words and whether it wears the gold: "Train Journeyman" at the cap, else
--- "Trainers & vendors". Pure.
function Trainers.ButtonText(rank, max)
  if Trainers.AtCap(rank, max) then
    return string.format(Trainers.WORDS.train, Trainers.NextTier(max).name), true
  end
  return Trainers.WORDS.button, false
end

--- The button's width for its words, where the client will not measure them. Pure.
function Trainers.ButtonWidth(text, measured)
  local w = tonumber(measured) or math.floor(#tostring(text or "") * Trainers.CHAR_W + 0.5)
  return math.max(w + Trainers.BUTTON_PAD * 2, Trainers.BUTTON_MIN_W)
end

--- Every spell of a line a trainer might teach: its recipes in the data and its rank spells,
--- ascending. Pure.
function Trainers.LineSpells(tracks, line)
  local out, seen = {}, {}
  local lines = type(tracks) == "table" and tracks.lines or nil
  local data = type(lines) == "table" and lines[tonumber(line)] or nil
  for spell in pairs(type(data) == "table" and type(data.recipes) == "table" and data.recipes or EMPTY) do
    if type(spell) == "number" and not seen[spell] then
      seen[spell] = true
      out[#out + 1] = spell
    end
  end
  for _, spell in ipairs(Trainers.RANKS[tonumber(line)] or EMPTY) do
    if not seen[spell] then
      seen[spell] = true
      out[#out + 1] = spell
    end
  end
  table.sort(out)
  return out
end

local function call(object, method, ...)
  if type(object) ~= "table" or type(object[method]) ~= "function" then
    return nil
  end
  local ok, answer = pcall(object[method], object, ...)
  if ok then
    return answer
  end
  return nil
end

--- The trainer name indices that teach any of spells, each once, in the order met. reader is the
--- Classic Era reader (Core/EraSources.lua), or anything with its TrainersOf. Pure over it.
function Trainers.TrainersOfAny(reader, spells)
  local out, seen = {}, {}
  for _, spell in ipairs(type(spells) == "table" and spells or EMPTY) do
    for _, nameIndex in ipairs(call(reader, "TrainersOf", spell) or EMPTY) do
      if type(nameIndex) == "number" and not seen[nameIndex] then
        seen[nameIndex] = true
        out[#out + 1] = nameIndex
      end
    end
  end
  return out
end

--- One trainer as a row: { nameIndex, key, name, title, zone, areaId, side }. The key is the N2
--- npc page's own (brief EK1: keyed by its creature id, the reader's E:PageKey, E:TrainerEdges'
--- target), and nil for a name the table states no creature id for: that trainer is still listed,
--- by its name (E:NameAt), and its row opens nothing. Pure over the reader.
function Trainers.TrainerEntry(reader, nameIndex)
  local key = call(reader, "PageKey", nameIndex)
  if type(key) ~= "string" then
    key = nil
  end
  local areas = call(reader, "TrainerAreas", nameIndex)
  local zone = type(areas) == "table" and areas[1] or nil
  local name
  if key then
    name = call(reader, "NameFor", key)
  else
    name = call(reader, "NameAt", nameIndex)
  end
  return {
    nameIndex = nameIndex,
    key = key,
    name = type(name) == "string" and name ~= "" and name or key,
    title = call(reader, "Title", nameIndex),
    zone = type(zone) == "table" and zone.name or nil,
    areaId = type(zone) == "table" and zone.areaId or nil,
    side = call(reader, "Faction", nameIndex),
  }
end

local function byName(a, b)
  local left, right = tostring(a.name or ""):lower(), tostring(b.name or ""):lower()
  if left ~= right then
    return left < right
  end
  return tostring(a.key) < tostring(b.key)
end

--- Whether an entry's side is the other one: both sides known (1 Alliance, 2 Horde) and not the
--- same. A side of 3 (both) or none stays with the player's. Pure.
function Trainers.IsOtherSide(side, playerSide)
  if (side ~= 1 and side ~= 2) or (playerSide ~= 1 and playerSide ~= 2) then
    return false
  end
  return side ~= playerSide
end

--- Brief F155 (owner QA 2026-10-14 item 155): a { own, other } group with the other side taken out
--- while "Hide other faction data" is on (hide) and the player's side is known: other emptied,
--- hidden how many went and hiddenSide whose they are (1 Alliance, 2 Horde), for the one muted line
--- the panel says instead (Trainers.HiddenLine). The group itself is written into and answered.
--- Pure.
function Trainers.HideOther(grouped, hide, playerSide)
  if type(grouped) ~= "table" or not hide or (playerSide ~= 1 and playerSide ~= 2) then
    return grouped
  end
  local other = grouped.other or EMPTY
  if #other > 0 then
    grouped.hidden = #other
    grouped.hiddenSide = 3 - playerSide
    grouped.other = {}
  end
  return grouped
end

--- Brief F155: the muted line for a group's hidden rows ("4 Horde trainers hidden", Core/Graph.lua
--- Graph.HiddenText), noun "trainer" or "vendor", or nil where none were hidden. Pure.
function Trainers.HiddenLine(grouped, noun)
  local graph = ItemTree.Graph
  if type(grouped) ~= "table" or type(graph) ~= "table" or type(graph.HiddenText) ~= "function" then
    return nil
  end
  return graph.HiddenText(grouped.hidden, grouped.hiddenSide, noun)
end

--- The player's side first, the other in its own list, each by name: { own, other }. Pure.
function Trainers.Group(entries, playerSide)
  local own, other = {}, {}
  for _, entry in ipairs(type(entries) == "table" and entries or EMPTY) do
    if Trainers.IsOtherSide(entry.side, playerSide) then
      other[#other + 1] = entry
    else
      own[#own + 1] = entry
    end
  end
  table.sort(own, byName)
  table.sort(other, byName)
  return { own = own, other = other }
end

--- The band the rank is in and the one after it: two indices into the line's bands (the second
--- nil at the end), or nil for a line with no bands. A rank below the first band is in it; a rank
--- past the last is in the last. Pure.
function Trainers.BandSpan(bands, rank)
  bands = type(bands) == "table" and bands or EMPTY
  if #bands == 0 then
    return nil
  end
  rank = tonumber(rank) or 0
  local current = #bands
  for index, band in ipairs(bands) do
    if rank < (tonumber(band.hi) or 0) then
      current = index
      break
    end
  end
  local nextIndex = current + 1
  if nextIndex > #bands then
    nextIndex = nil
  end
  return current, nextIndex
end

local function factionOk(fa, faction)
  fa, faction = tonumber(fa), tonumber(faction)
  if (fa ~= 1 and fa ~= 2) or (faction ~= 1 and faction ~= 2) then
    return true
  end
  return fa == faction
end

--- The teaching items of the recipes in the current and the next band, each once: { { itemId,
--- spell, r } } by r, then spell. A recipe is in a band by its r, the model's rule (the last band
--- takes r == hi too); the other side's recipes are left out. Answers the list and the span's lo
--- and hi. Pure.
function Trainers.RecipeItems(tracks, line, rank, faction)
  local lines = type(tracks) == "table" and tracks.lines or nil
  local data = type(lines) == "table" and lines[tonumber(line)] or nil
  local bands = type(data) == "table" and data.bands or nil
  local current, nextIndex = Trainers.BandSpan(bands, rank)
  if not current then
    return {}, nil, nil
  end
  local first, last = bands[current], bands[nextIndex or current]
  local lo, hi = tonumber(first.lo) or 0, tonumber(last.hi) or 0
  local lastBand = (nextIndex or current) == #bands
  local found = {}
  for spell, recipe in pairs(type(data.recipes) == "table" and data.recipes or EMPTY) do
    if type(spell) == "number" and type(recipe) == "table" and type(recipe.by) == "table" then
      local r = tonumber(recipe.r) or 1
      local inside = r >= lo and (r < hi or (lastBand and r == hi))
      if inside and factionOk(recipe.fa, faction) then
        found[#found + 1] = { spell = spell, r = r, by = recipe.by }
      end
    end
  end
  table.sort(found, function(a, b)
    if a.r ~= b.r then
      return a.r < b.r
    end
    return a.spell < b.spell
  end)
  local out, seen = {}, {}
  for _, entry in ipairs(found) do
    for _, itemId in ipairs(entry.by) do
      if type(itemId) == "number" and not seen[itemId] then
        seen[itemId] = true
        out[#out + 1] = { itemId = itemId, spell = entry.spell, r = entry.r }
      end
    end
  end
  return out, lo, hi
end

--- One item's vendors: the client's own list first (ForeverVendors), then the original game's
--- vendor rows (the Classic Era reader's Rows), an Era vendor of a name the client already lists
--- left out. sources = { era = reader, fv = the ForeverVendors module, fvTable = its table }.
--- Answers { own, other, unnamed (the client sells it from a vendor it does not name yet), more
--- (vendors the Era table counts but lists elsewhere) }. Pure over the objects handed in.
function Trainers.Vendors(itemId, sources, playerSide)
  sources = type(sources) == "table" and sources or EMPTY
  local entries, names = {}, {}
  local unnamed, more = false, 0
  local fv, fvTable = sources.fv, sources.fvTable
  if type(fv) == "table" and type(fv.VendorsOf) == "function" and type(fvTable) == "table" then
    local list = fv.VendorsOf(fvTable, itemId)
    if type(list) == "table" and #list == 0 then
      unnamed = true
    end
    for _, npcId in ipairs(type(list) == "table" and list or EMPTY) do
      local vendor = type(npcId) == "number" and type(fv.VendorAt) == "function" and fv.VendorAt(fvTable, npcId)
      if type(vendor) == "table" then
        local name = type(fv.Name) == "function" and fv.Name(npcId, fvTable) or nil
        local zone = nil
        if type(fv.Place) == "function" then
          local ok, words = pcall(fv.Place, vendor.a)
          zone = ok and words or nil
        end
        if type(name) == "string" and name ~= "" then
          names[name:lower()] = true
        else
          name = type(fv.Label) == "function" and fv.Label(npcId) or ("npc " .. npcId)
        end
        entries[#entries + 1] = { key = "npc:" .. npcId, npcId = npcId, name = name, zone = zone, client = true }
      end
    end
  end
  for _, row in ipairs(call(sources.era, "Rows", itemId) or EMPTY) do
    if type(row) == "table" and row.category == "vendor" then
      if row.summary then
        more = more + (tonumber(row.more) or tonumber(row.total) or 0)
      elseif type(row.name) == "string" and not names[row.name:lower()] and type(row.key) == "string" then
        names[row.name:lower()] = true
        entries[#entries + 1] = {
          -- Brief EK1: a vendor the table states no creature id for has no page, so no key.
          key = not row.noPage and row.key or nil,
          nameIndex = row.nameIndex,
          name = row.name,
          zone = row.area or nil,
          areaId = row.areaId,
          side = call(sources.era, "Faction", row.nameIndex),
        }
      end
    end
  end
  local grouped = Trainers.Group(entries, playerSide)
  grouped.unnamed = unnamed
  grouped.more = more
  return grouped
end

--- The name a teaching item goes by: the tab's own names, then the item data, then "Undiscovered
--- item" or "Item 1234". Pure.
function Trainers.ItemName(names, itemId, item, undiscovered)
  local name = type(names) == "table" and names[itemId] or nil
  if type(name) == "string" and name ~= "" then
    return name
  end
  if type(item) == "table" and type(item.n) == "string" and item.n ~= "" then
    return item.n
  end
  if undiscovered == true then
    return Trainers.WORDS.undiscovered
  end
  return string.format(Trainers.WORDS.item, tonumber(itemId) or 0)
end

--- What the panel says for one line. args = { line, name, rank, max, tracks, faction, sources,
--- nameOf(itemId), hideOther }, sources as Trainers.Vendors takes them. Answers { title, tier,
--- rankSpell, fallback, noTrainerFor, book, trainers = { own, other }, recipes = { { itemId, name,
--- vendors } }, lo, hi }. Pure over the objects handed in. Brief F155: with hideOther ("Hide other
--- faction data" on) every group's other side is taken out and counted (Trainers.HideOther).
function Trainers.Content(args)
  args = type(args) == "table" and args or EMPTY
  local sources = type(args.sources) == "table" and args.sources or EMPTY
  local reader = sources.era
  local lineName = args.name or ""
  local tier = Trainers.NextTier(args.max)
  local spell = tier and Trainers.RankSpell(args.line, tier) or nil
  local out = { tier = tier, rankSpell = spell, fallback = false, lineName = lineName }
  local names = nil
  if spell then
    names = call(reader, "TrainersOf", spell)
    out.title = string.format(Trainers.WORDS.trainersFor, Trainers.RankName(tier, lineName))
  else
    out.title = string.format(Trainers.WORDS.trainersFor, lineName)
  end
  if type(names) ~= "table" or #names == 0 then
    -- The fallback: every trainer who teaches this profession at all.
    if spell then
      out.fallback = true
      out.noTrainerFor = Trainers.RankName(tier, lineName)
      out.title = string.format(Trainers.WORDS.trainersFor, lineName)
    end
    names = Trainers.TrainersOfAny(reader, Trainers.LineSpells(args.tracks, args.line))
  end
  local entries = {}
  for _, nameIndex in ipairs(names) do
    entries[#entries + 1] = Trainers.TrainerEntry(reader, nameIndex)
  end
  local hide = args.hideOther == true
  out.trainers = Trainers.HideOther(Trainers.Group(entries, args.faction), hide, args.faction)
  local nameOf = type(args.nameOf) == "function" and args.nameOf
    or function(itemId)
      return Trainers.ItemName(nil, itemId)
    end
  local book = spell and Trainers.BOOKS[spell] or nil
  if book and out.fallback then
    local vendors = Trainers.HideOther(Trainers.Vendors(book, sources, args.faction), hide, args.faction)
    out.book = { itemId = book, name = nameOf(book), vendors = vendors }
  end
  local items, lo, hi = Trainers.RecipeItems(args.tracks, args.line, args.rank, args.faction)
  out.lo, out.hi = lo, hi
  out.recipes = {}
  for _, entry in ipairs(items) do
    local vendors = Trainers.HideOther(Trainers.Vendors(entry.itemId, sources, args.faction), hide, args.faction)
    if #vendors.own > 0 or #vendors.other > 0 or vendors.unnamed or vendors.more > 0 or (vendors.hidden or 0) > 0 then
      out.recipes[#out.recipes + 1] = { itemId = entry.itemId, name = nameOf(entry.itemId), vendors = vendors }
    end
  end
  return out
end

-- An item's vendor rows under it, into rows.
local function vendorRows(rows, vendors, itemKey)
  for _, entry in ipairs(vendors.own or EMPTY) do
    rows[#rows + 1] = { kind = "npc", text = entry.name, zone = entry.zone, key = entry.key, entry = entry }
  end
  if vendors.unnamed then
    rows[#rows + 1] = { kind = "note", text = Trainers.WORDS.unnamed, indent = true }
  end
  if #(vendors.other or EMPTY) > 0 then
    rows[#rows + 1] = { kind = "sub", text = Trainers.WORDS.otherFaction }
    for _, entry in ipairs(vendors.other) do
      rows[#rows + 1] = { kind = "npc", text = entry.name, zone = entry.zone, key = entry.key, entry = entry }
    end
  end
  -- Brief F155: the other side's vendors "Hide other faction data" took out, in one muted line.
  local hidden = Trainers.HiddenLine(vendors, "vendor")
  if hidden then
    rows[#rows + 1] = { kind = "note", text = hidden, indent = true }
  end
  if (tonumber(vendors.more) or 0) > 0 then
    rows[#rows + 1] = { kind = "note", text = string.format(Trainers.WORDS.more, vendors.more), key = itemKey }
  end
end

--- Brief BQ25b (owner QA 2026-10-10 item 55): what the panel's "Show nearest" measures
--- (Core/Nearest.lua Nearest.FindAmong): the player's side's trainers with a page, as
--- { target = key, faction = side, name }, in the panel's order. The "Other faction" group is left
--- out. Pure.
function Trainers.NearestEdges(content)
  local out = {}
  local trainers = type(content) == "table" and type(content.trainers) == "table" and content.trainers or EMPTY
  for _, entry in ipairs(trainers.own or EMPTY) do
    if type(entry) == "table" and type(entry.key) == "string" then
      out[#out + 1] = { target = entry.key, faction = entry.side, name = entry.name }
    end
  end
  return out
end

-- The player's side's trainers with the one nearest names first, the rest in their order. Brief
-- NR1a: nearest may be a table { key, name, zone } (the "Show nearest" answer): a trainer the
-- panel's list does not hold (a Forever trainer, one of another rank) is put on top as its own row.
-- Pure.
local function nearestFirst(own, nearest)
  local key = type(nearest) == "table" and nearest.key or nearest
  if type(key) ~= "string" then
    return own
  end
  local first, rest = nil, {}
  for _, entry in ipairs(own) do
    if not first and entry.key == key then
      first = entry
    else
      rest[#rest + 1] = entry
    end
  end
  if not first then
    if type(nearest) ~= "table" or type(nearest.name) ~= "string" or nearest.name == "" then
      return own
    end
    first = { key = key, name = nearest.name, zone = nearest.zone, side = nearest.side }
  end
  table.insert(rest, 1, first)
  return rest
end

--- Brief NR1a: what Trainers.Rows lifts for a held "Show nearest" answer: { key, name, zone, side }
--- where it names the trainer, else its key alone, else nil. Pure.
function Trainers.NearestLift(held)
  if type(held) ~= "table" or type(held.key) ~= "string" then
    return nil
  end
  if type(held.name) == "string" and held.name ~= "" then
    return { key = held.key, name = held.name, zone = held.zone, side = held.side }
  end
  return held.key
end

--- Brief NR1a: whether the panel offers "Show nearest": a profession the trainer search knows
--- (kind, TrainerSearch.LineKind's answer; its set holds every trainer we have a place for, Forever
--- ones too), or a trainer of the player's side with a page in the panel's own list. Pure.
function Trainers.NearestWanted(content, kind)
  if type(content) ~= "table" then
    return false
  end
  if type(kind) == "string" then
    return true
  end
  return #Trainers.NearestEdges(content) > 0
end

--- The panel's rows, top to bottom, out of Trainers.Content: { kind, text, zone, key, entry,
--- itemId }, kind "heading", "sub", "note", "npc" or "item". Brief BQ25b (owner QA 2026-10-10
--- items 48 and 55): a trainer's row says so (trainer = true, its page opens on the Map tab), and
--- nearest (a page key, the "Show nearest" answer) lifts that trainer of the player's side to the
--- top of its list, its zone reading "Nearest: <zone>" (nearest = true). Pure.
function Trainers.Rows(content, nearest)
  local rows = {}
  if type(content) ~= "table" then
    return rows
  end
  rows[#rows + 1] = { kind = "heading", text = content.title }
  local trainers = content.trainers or EMPTY
  local own, other = trainers.own or EMPTY, trainers.other or EMPTY
  -- Where nothing teaches the line either, and no book stands in, "No trainer known yet" says it.
  if content.fallback and content.noTrainerFor and (content.book or #own + #other > 0) then
    rows[#rows + 1] = { kind = "note", text = string.format(Trainers.WORDS.noTrainerFor, content.noTrainerFor) }
    local book = content.book
    if book then
      rows[#rows + 1] = { kind = "note", text = string.format(Trainers.WORDS.learntFrom, content.noTrainerFor) }
      local key = "item:" .. book.itemId
      rows[#rows + 1] =
        { kind = "item", text = book.name, itemId = book.itemId, key = key, zone = Trainers.WORDS.soldBy }
      local before = #rows
      vendorRows(rows, book.vendors or EMPTY, key)
      if #rows == before then
        rows[#rows].zone = nil
        rows[#rows + 1] = { kind = "note", text = Trainers.WORDS.noVendor, indent = true }
      end
    end
  end
  -- Brief NR1a: a "Show nearest" answer the list does not hold is drawn on top all the same.
  local lifted = type(nearest) == "table" and type(nearest.name) == "string"
  -- Brief F155: the other side's trainers "Hide other faction data" took out, as one muted line in
  -- the place of their group (or of "No trainer known yet" where they were all there was).
  local hiddenLine = Trainers.HiddenLine(trainers, "trainer")
  if #own + #other == 0 and not lifted then
    rows[#rows + 1] = { kind = "note", text = hiddenLine or Trainers.WORDS.noTrainer }
    hiddenLine = nil
  else
    if content.fallback and content.noTrainerFor then
      rows[#rows + 1] = { kind = "note", text = string.format(Trainers.WORDS.lineTrainers, content.lineName or "") }
    end
    local nearestKey = type(nearest) == "table" and nearest.key or nearest
    for _, entry in ipairs(nearestFirst(own, nearest)) do
      local row = { kind = "npc", text = entry.name, zone = entry.zone, key = entry.key, entry = entry, trainer = true }
      if type(nearestKey) == "string" and entry.key == nearestKey then
        row.nearest = true
        row.zone = string.format(Trainers.WORDS.nearestAt, entry.zone or "")
      end
      rows[#rows + 1] = row
    end
    if #other > 0 then
      rows[#rows + 1] = { kind = "sub", text = Trainers.WORDS.otherFaction }
      for _, entry in ipairs(other) do
        rows[#rows + 1] =
          { kind = "npc", text = entry.name, zone = entry.zone, key = entry.key, entry = entry, trainer = true }
      end
    end
  end
  if hiddenLine then
    rows[#rows + 1] = { kind = "note", text = hiddenLine }
  end
  if content.lo and content.hi then
    rows[#rows + 1] = { kind = "heading", text = string.format(Trainers.WORDS.recipes, content.lo, content.hi) }
    if #(content.recipes or EMPTY) == 0 then
      rows[#rows + 1] = { kind = "note", text = Trainers.WORDS.noRecipes }
    end
    for _, recipe in ipairs(content.recipes or EMPTY) do
      local key = "item:" .. recipe.itemId
      rows[#rows + 1] = {
        kind = "item",
        text = recipe.name,
        itemId = recipe.itemId,
        key = key,
        zone = Trainers.WORDS.soldBy,
      }
      vendorRows(rows, recipe.vendors or EMPTY, key)
    end
  end
  rows[#rows + 1] = { kind = "footer", text = Trainers.WORDS.footer }
  return rows
end

--- Brief PR16: a row's height in the panel: ROW_H, a section heading after the first with
--- SECTION_GAP above it, and the footer's wrapped sentence with the gap above it. Pure.
function Trainers.RowHeight(row, index)
  if type(row) ~= "table" then
    return Trainers.ROW_H
  end
  if row.kind == "footer" then
    return Trainers.SECTION_GAP + Trainers.FOOTER_H
  end
  if row.kind == "heading" and (tonumber(index) or 1) > 1 then
    return Trainers.SECTION_GAP + Trainers.ROW_H
  end
  return Trainers.ROW_H
end

--- The height of rows from to to (inclusive), each by RowHeight. Pure.
function Trainers.RowsHeight(rows, from, to)
  local h = 0
  for index = tonumber(from) or 1, tonumber(to) or #(rows or EMPTY) do
    h = h + Trainers.RowHeight(rows[index], index)
  end
  return h
end

--- Brief PR16: the furthest a scroll goes with rows of RowHeight in height px: the first offset
--- from which every row left fits. Pure.
function Trainers.MaxOffset(rows, height)
  rows = type(rows) == "table" and rows or EMPTY
  height = tonumber(height) or 0
  for offset = 0, #rows - 1 do
    if Trainers.RowsHeight(rows, offset + 1, #rows) <= height then
      return offset
    end
  end
  return math.max(#rows - 1, 0)
end

--- The first row to draw for a wheel step, held so the last row sits at the bottom at most. Pure.
function Trainers.ClampOffset(offset, count, visible)
  offset = math.floor(tonumber(offset) or 0)
  local most = math.max((tonumber(count) or 0) - (tonumber(visible) or 0), 0)
  if offset < 0 then
    return 0
  end
  if offset > most then
    return most
  end
  return offset
end

--- Brief AT3 (pre-QA review note m1, 2026-10-24): what a row's waypoint pin is for, the words the
--- "Waypoint added" toast says under its title (UI/Toast.lua): the NPC's name, as that NPC's page
--- names its own Where row's waypoint (UI/InfoPanel.lua InfoPanel.WaypointFor, "Hogger"). Never the
--- coordinates. nil for a row that names no NPC. Pure.
function Trainers.WaypointFor(row)
  if type(row) ~= "table" or row.kind ~= "npc" then
    return nil
  end
  local entry = type(row.entry) == "table" and row.entry or EMPTY
  local name = entry.name
  if type(name) ~= "string" or name == "" then
    name = row.text
  end
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return name
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

local globalFn = ItemTree.Util.GlobalFn
local theme = ItemTree.ProfessionsKit.Theme
local assets = ItemTree.ProfessionsKit.Assets
local skin = ItemTree.ProfessionsKit.Skin
local pane = ItemTree.ProfessionsKit.Pane

local function infoPanel()
  local ui = ItemTree.UI
  local found = type(ui) == "table" and ui.InfoPanel or nil
  return type(found) == "table" and found or nil
end

local function newFrame(kind, parent)
  local create = globalFn("CreateFrame")
  if not create then
    return nil
  end
  local ok, frame = pcall(create, kind, nil, parent)
  if ok and type(frame) == "table" then
    return frame
  end
  return nil
end

-- Brief PM1 (brief G1 reaching the Professions code): every script body set through setScript
-- runs under ItemTree.Guard.Run, the boundary main's panes use, so a fault in one is handed to the
-- client's error handler once and the rest of the tab keeps working. Only ItemTree's own handlers
-- on ItemTree's own frames are wrapped. raw sets the handler as it is: the hardware event craft
-- path (the Craft all button's click, the queue's press and pause) stays exactly as proven in game.
local guardScript = ItemTree.ProfessionsKit.GuardScript

local function setScript(frame, script, handler, raw)
  if type(frame) ~= "table" or type(frame.SetScript) ~= "function" then
    return false
  end
  if type(frame.HasScript) == "function" then
    local ok, has = pcall(frame.HasScript, frame, script)
    if not ok or not has then
      return false
    end
  end
  if not raw then
    handler = guardScript("Professions.Trainers." .. tostring(script), handler)
  end
  return (pcall(frame.SetScript, frame, script, handler))
end

local setShown = ItemTree.ProfessionsKit.SetShown

local function number(frame, method)
  if type(frame) ~= "table" or type(frame[method]) ~= "function" then
    return nil
  end
  local ok, value = pcall(frame[method], frame)
  value = ok and tonumber(value) or nil
  if value and value > 0 then
    return value
  end
  return nil
end

-- A texture tinted a Theme colour at the colour's own alpha. Washes only (the no dim rule).
local tint = ItemTree.ProfessionsKit.Tint
local textColour = ItemTree.ProfessionsKit.TextColour
local applyAsset = ItemTree.ProfessionsKit.ApplyAsset
local newTexture = ItemTree.ProfessionsKit.NewTexture
local wash = ItemTree.ProfessionsKit.Wash

-- Four hairline edges, the flat fallback where the card art will not draw.
local edges = ItemTree.ProfessionsKit.Edges

local function showEdges(list, shown, colourKey)
  for _, edge in ipairs(type(list) == "table" and list or EMPTY) do
    if shown then
      tint(edge, colourKey)
      edge:Show()
    else
      edge:Hide()
    end
  end
end

--------------------------------------------------------------------------------
-- Font safety (UI/Sidebar.lua's shape)
--------------------------------------------------------------------------------

local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(Trainers.FONT_FALLBACKS) do
    local object = rawget(_G, name)
    if object ~= nil then
      local ok, applied = pcall(fontString.SetFontObject, fontString, object)
      if ok and applied ~= false then
        return true
      end
    end
  end
  return false
end

local function hasFont(fontString)
  if type(fontString) ~= "table" or type(fontString.GetFont) ~= "function" then
    return false
  end
  local ok, face = pcall(fontString.GetFont, fontString)
  if not ok then
    return false
  end
  return face ~= nil and face ~= ""
end

local function ensureFont(fontString)
  if hasFont(fontString) then
    return true
  end
  return fallbackFont(fontString)
end

local function newText(parent, fontSize, colourKey, justify)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY", Trainers.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY")
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  local t = theme()
  local face = t and t.fonts and t.fonts.ITEMTREE_FONT_BODY
  if face and type(fontString.SetFont) == "function" then
    local set, applied = pcall(fontString.SetFont, fontString, face, fontSize, "")
    if not set or applied == false then
      fallbackFont(fontString)
    end
  end
  ensureFont(fontString)
  local outline = t and t.text and t.text.ITEMTREE_TEXT_OUTLINE
  if outline and type(fontString.SetShadowOffset) == "function" then
    pcall(fontString.SetShadowOffset, fontString, outline.x, outline.y)
    if type(fontString.SetShadowColor) == "function" then
      pcall(fontString.SetShadowColor, fontString, outline.r, outline.g, outline.b, outline.a)
    end
  end
  if type(fontString.SetJustifyH) == "function" then
    pcall(fontString.SetJustifyH, fontString, justify or "LEFT")
  end
  if type(fontString.SetWordWrap) == "function" then
    pcall(fontString.SetWordWrap, fontString, false)
  end
  textColour(fontString, colourKey)
  return fontString
end

local function setText(fontString, text)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  ensureFont(fontString)
  return (pcall(fontString.SetText, fontString, text or ""))
end

local stringWidth = ItemTree.ProfessionsKit.StringWidth

--------------------------------------------------------------------------------
-- Tooltips
--------------------------------------------------------------------------------

local hideTooltip = ItemTree.ProfessionsKit.HideTooltip

local function textTooltip(owner, title, lines)
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  pcall(tooltip.SetOwner, tooltip, owner, "ANCHOR_RIGHT")
  if type(tooltip.SetText) == "function" then
    pcall(tooltip.SetText, tooltip, title or "")
  elseif type(tooltip.AddLine) == "function" then
    pcall(tooltip.AddLine, tooltip, title or "")
  end
  for _, line in ipairs(lines or EMPTY) do
    if type(tooltip.AddLine) == "function" then
      pcall(tooltip.AddLine, tooltip, line, 1, 1, 1, true)
    end
  end
  if type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  return true
end

local function itemTooltip(owner, itemId, name)
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  pcall(tooltip.SetOwner, tooltip, owner, "ANCHOR_RIGHT")
  local drawn = type(tooltip.SetItemByID) == "function" and pcall(tooltip.SetItemByID, tooltip, itemId) or false
  if not drawn and type(tooltip.SetHyperlink) == "function" then
    drawn = pcall(tooltip.SetHyperlink, tooltip, "item:" .. itemId)
  end
  if not drawn and type(tooltip.AddLine) == "function" then
    pcall(tooltip.AddLine, tooltip, name or "")
  end
  if type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  return true
end

local function sideWord(side)
  if side == 1 then
    return Trainers.WORDS.alliance
  end
  if side == 2 then
    return Trainers.WORDS.horde
  end
  return nil
end

--------------------------------------------------------------------------------
-- The player and the data
--------------------------------------------------------------------------------

local SIDES = { Alliance = 1, Horde = 2 }

-- Brief F155: whether "Hide other faction data" is on (Core/Graph.lua Graph.HidesOtherFaction, on
-- by default). A namespace with no Graph to ask, or none to word the hidden line (Graph.HiddenText),
-- hides nothing: the panel never takes rows out without saying so. Guarded.
local function hidesOtherFaction()
  local graph = ItemTree.Graph
  if type(graph) ~= "table" or type(graph.HidesOtherFaction) ~= "function" or type(graph.HiddenText) ~= "function" then
    return false
  end
  local ok, on = pcall(graph.HidesOtherFaction)
  return ok and on ~= false
end

-- The player's side: the model's Facts, else the client's own answer. 1, 2 or nil.
local function playerSide()
  local model = ItemTree.ProfessionsModel
  if type(model) == "table" and type(model.Facts) == "function" then
    local ok, _, faction = pcall(model.Facts)
    if ok and (faction == 1 or faction == 2) then
      return faction
    end
  end
  local ask = globalFn("UnitFactionGroup")
  if ask then
    local ok, word = pcall(ask, "player")
    if ok then
      return SIDES[word]
    end
  end
  return nil
end

--- Loads the trainer and vendor tables, on the button's click only: ItemTree_Data through
--- Data:Get (which loads the folder on demand, synchronously), the Classic Era table first, then
--- the client's own vendor module. Answers the sources Trainers.Vendors takes, or nil where the
--- Classic Era table cannot be had.
function Trainers.Load()
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.Get) ~= "function" then
    return nil
  end
  local ok, source = pcall(data.Get, data, "EraSources")
  local reader = ItemTree.eraSources
  if not ok or type(source) ~= "table" or type(reader) ~= "table" then
    return nil
  end
  local fv = ItemTree.ForeverVendors
  local fvTable = nil
  if type(fv) == "table" and type(fv.Table) == "function" then
    local read, answer = pcall(fv.Table)
    fvTable = read and type(answer) == "table" and answer or nil
  end
  return { era = reader, fv = type(fv) == "table" and fv or nil, fvTable = fvTable }
end

-- A teaching item's name: the tab's names, then the item data (loaded by now), never a query.
local function itemNameOf(itemId)
  local tracks = ItemTree.ProfessionTracks
  local names = type(tracks) == "table" and tracks.names or nil
  local data = ItemTree.Data
  local item, undiscovered = nil, false
  if type(data) == "table" then
    if type(data.GetItem) == "function" then
      local ok, answer = pcall(data.GetItem, data, itemId)
      item = ok and type(answer) == "table" and answer or nil
    end
    if type(data.IsUndiscovered) == "function" then
      local ok, answer = pcall(data.IsUndiscovered, data, itemId)
      undiscovered = ok and answer == true
    end
  end
  return Trainers.ItemName(names, itemId, item, undiscovered)
end

-- Where the N4 waypoint goes for one row's NPC, asked only for a row on screen and kept: a
-- Classic Era name's single pin (E:PinsOf), or a client vendor's own place (ForeverVendors.Facts
-- and Positions). nil for none, several, or a client that cannot set one there.
local function waypointOf(entry)
  if type(entry) ~= "table" then
    return nil
  end
  if entry.waypointAsked then
    return entry.waypoint
  end
  entry.waypointAsked = true
  local info = infoPanel()
  if not info or type(info.WaypointOf) ~= "function" then
    return nil
  end
  local pins = nil
  local sources = Trainers.sources or EMPTY
  if entry.npcId then
    local fv = sources.fv
    if type(fv) == "table" and type(fv.Facts) == "function" and type(fv.Positions) == "function" then
      local ok, facts = pcall(fv.Facts, entry.key)
      if ok then
        local placed, list = pcall(fv.Positions, facts)
        pins = placed and list or nil
      end
    end
  elseif entry.nameIndex then
    pins = call(sources.era, "PinsOf", entry.nameIndex)
  end
  local ok, at = pcall(info.WaypointOf, pins)
  at = ok and type(at) == "table" and at or nil
  if at and type(info.CanWaypoint) == "function" then
    local asked, can = pcall(info.CanWaypoint, at)
    if not asked or can ~= true then
      at = nil
    end
  end
  entry.waypoint = at
  return at
end

--------------------------------------------------------------------------------
-- The button
--------------------------------------------------------------------------------

-- The panel's frame: the Professions cards' flat chamfered card (UI/Skin.lua Skin.Card) in the
-- panel's own fill; the flat face and hairline where that will not draw.
local function paint(frame, w, h)
  local s = skin()
  local drawn = s
      and type(s.Card) == "function"
      and s.Card(frame, w, h, { fill = Trainers.PANEL_FILL, edge = Trainers.BORDER, thickness = 1 })
    or false
  setShown(frame.face, not drawn)
  showEdges(frame.edges, not drawn, Trainers.BORDER)
  frame.skinned = drawn == true
end

--- The button, made once on the tab's top strip. host is the frame the panel opens over (the
--- board). Brief PR17: the window's shared red plate button (UI/Skin.lua Skin.PlateButton over
--- Frame.NewPlateButton), its words on the plate's own child frame above the highlight, so the
--- frame and the words never vanish (QA round 3 found only a red smear). The flat face and
--- hairline edges where the window has no plate helper. Answers the button, or nil without
--- client frames.
function Trainers.BuildButton(parent, host)
  local s = skin()
  local button = s
      and type(s.PlateButton) == "function"
      and s.PlateButton(parent, Trainers.BUTTON_MIN_W, Trainers.BUTTON_H)
    or nil
  if not button then
    button = newFrame("Button", parent)
    if not button then
      return nil
    end
    button:SetSize(Trainers.BUTTON_MIN_W, Trainers.BUTTON_H)
    button.face = wash(button, "BACKGROUND", Trainers.FACE)
    if button.face then
      button.face:SetAllPoints(button)
    end
    button.edges = edges(button, Trainers.BORDER)
    button.hover = wash(button, "HIGHLIGHT", Trainers.HOVER)
    if button.hover then
      button.hover:SetAllPoints(button)
    end
    if type(button.RegisterForClicks) == "function" then
      pcall(button.RegisterForClicks, button, "LeftButtonUp")
    end
  end
  button.canPress = true
  button.label = newText(rawget(button, "labelParent") or button, Trainers.FONT_SM, Trainers.BUTTON_WORD, "CENTER")
  if button.label then
    button.label:SetPoint("LEFT", button, "LEFT", 4, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -4, 0)
  end
  setScript(button, "OnClick", function()
    Trainers.Toggle()
  end)
  local function onEnter(self)
    local chosen = Trainers.chosen or EMPTY
    local tier = Trainers.NextTier(chosen.max)
    local title = tier and Trainers.RankName(tier, chosen.name) or Trainers.WORDS.button
    textTooltip(self, title, { Trainers.WORDS.hint })
  end
  if button.plated and type(s.PlateScripts) == "function" then
    s.PlateScripts(button, setScript, { OnEnter = onEnter, OnLeave = hideTooltip })
  else
    setScript(button, "OnEnter", onEnter)
    setScript(button, "OnLeave", hideTooltip)
  end
  Trainers.button = button
  Trainers.host = host or parent
  return button
end

--- Sets the button for the chosen line ({ line, name, rank, max }, the pane's strip row): its
--- words, its width and the gold at the cap. Reads nothing from ItemTree_Data. Answers { text,
--- gold, width }. An open panel is filled again for the new line or rank.
function Trainers.Update(chosen)
  local previous = Trainers.chosen
  Trainers.chosen = type(chosen) == "table" and chosen or nil
  local button = Trainers.button
  local state = { width = 0 }
  if not Trainers.chosen then
    setShown(button, false)
    Trainers.Close()
    return state
  end
  local text, gold = Trainers.ButtonText(chosen.rank, chosen.max)
  state.text, state.gold = text, gold
  if button then
    setText(button.label, text)
    local width = Trainers.ButtonWidth(text, stringWidth(button.label))
    button:SetWidth(width)
    button.gold = gold
    -- Brief PR17: at the cap the plate glows (its additive highlight held on), under the words.
    button.lit = gold
    if button.plated then
      local s = skin()
      if s and type(s.PaintPlate) == "function" then
        s.PaintPlate(button, "normal")
      end
    else
      showEdges(button.edges, true, gold and Trainers.GOLD_BORDER or Trainers.BORDER)
    end
    textColour(button.label, gold and Trainers.HEADING_WORD or Trainers.BUTTON_WORD)
    button:Show()
    state.width = width
  end
  Trainers.state = state
  if Trainers.open then
    local moved = not previous or previous.line ~= chosen.line or previous.rank ~= chosen.rank
    if moved or previous.max ~= chosen.max then
      Trainers.Fill()
    end
  end
  return state
end

--------------------------------------------------------------------------------
-- The panel
--------------------------------------------------------------------------------

local function onRowClick(self, button)
  local row = rawget(self, "row")
  if type(row) ~= "table" or type(row.key) ~= "string" then
    return false
  end
  local p = pane()
  if p and type(p.Click) == "function" then
    -- Brief BQ25b (owner QA 2026-10-10 item 48): a trainer's page opens on its Map tab
    -- (UI/Frame.lua Frame.Open's trainer option, Frame.TrainerOpenView).
    if row.trainer then
      return p.Click(row.key, button, { trainer = true })
    end
    return p.Click(row.key, button)
  end
  return false
end

local function onRowEnter(self)
  local row = rawget(self, "row")
  if type(row) ~= "table" then
    return false
  end
  if row.kind == "item" and row.itemId then
    return itemTooltip(self, row.itemId, row.text)
  end
  if row.kind == "npc" then
    local entry = row.entry or EMPTY
    local lines = {}
    if type(entry.title) == "string" and entry.title ~= "" then
      lines[#lines + 1] = entry.title
    end
    if type(entry.zone) == "string" and entry.zone ~= "" then
      lines[#lines + 1] = entry.zone
    end
    local side = sideWord(entry.side)
    if side then
      lines[#lines + 1] = side
    end
    lines[#lines + 1] = Trainers.WORDS.openPage
    return textTooltip(self, row.text, lines)
  end
  if row.kind == "note" and row.text then
    return textTooltip(self, row.text, row.key and { Trainers.WORDS.openPage } or nil)
  end
  return false
end

local function buildRow(panel)
  local row = newFrame("Button", panel.list or panel)
  if not row then
    return nil
  end
  row:SetHeight(Trainers.ROW_H)
  row.hover = wash(row, "HIGHLIGHT", Trainers.HOVER)
  if row.hover then
    row.hover:SetAllPoints(row)
  end
  row.icon = newTexture(row, "ARTWORK")
  if row.icon then
    row.icon:SetSize(Trainers.ICON, Trainers.ICON)
  end
  row.label = newText(row, Trainers.FONT_SM, Trainers.NAME_WORD, "LEFT")
  row.zone = newText(row, Trainers.FONT_SM, Trainers.MUTED_WORD, "RIGHT")
  local pin = newFrame("Button", row)
  if pin then
    pin:SetSize(Trainers.PIN, Trainers.PIN)
    pin:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    pin.icon = newTexture(pin, "ARTWORK")
    if pin.icon then
      pin.icon:SetAllPoints(pin)
      applyAsset(pin.icon, "MAP_PIN")
    end
    if type(pin.RegisterForClicks) == "function" then
      pcall(pin.RegisterForClicks, pin, "LeftButtonUp")
    end
    setScript(pin, "OnClick", function(self)
      local at = rawget(self, "at")
      local info = infoPanel()
      if at and info and type(info.SetWaypoint) == "function" then
        -- Brief AT3: and the toast says whose pin it is (Trainers.WaypointFor).
        pcall(info.SetWaypoint, at, rawget(self, "waypointFor"))
      end
    end)
    setScript(pin, "OnEnter", function(self)
      textTooltip(self, Trainers.WORDS.waypoint, nil)
    end)
    setScript(pin, "OnLeave", hideTooltip)
    pin:Hide()
  end
  row.pin = pin
  if type(row.RegisterForClicks) == "function" then
    pcall(row.RegisterForClicks, row, "LeftButtonUp")
  end
  setScript(row, "OnClick", onRowClick)
  setScript(row, "OnEnter", onRowEnter)
  setScript(row, "OnLeave", hideTooltip)
  return row
end

local ROW_COLOURS = {
  footer = Trainers.MUTED_WORD,
  heading = Trainers.HEADING_WORD,
  sub = Trainers.HEADING_WORD,
  note = Trainers.MUTED_WORD,
  npc = Trainers.NAME_WORD,
  item = Trainers.NAME_WORD,
}

local function fillRow(frame, row, width)
  frame.row = row
  local indent = 0
  if row.kind == "npc" or row.indent then
    indent = Trainers.INDENT
  end
  local left = indent
  if frame.icon then
    if row.kind == "item" and row.itemId then
      local a = assets()
      local icon = nil
      if a and type(a.ItemIcon) == "function" then
        local ok, answer = pcall(a.ItemIcon, row.itemId)
        icon = ok and answer or nil
      end
      local drawn = false
      if icon and type(frame.icon.SetTexture) == "function" then
        drawn = pcall(frame.icon.SetTexture, frame.icon, icon)
        if drawn and type(frame.icon.SetTexCoord) == "function" then
          pcall(frame.icon.SetTexCoord, frame.icon, 0, 1, 0, 1)
        end
      end
      if not drawn then
        applyAsset(frame.icon, "ICON_QUESTIONMARK")
      end
      frame.icon:ClearAllPoints()
      frame.icon:SetPoint("LEFT", frame, "LEFT", left, 0)
      frame.icon:Show()
      left = left + Trainers.ICON + 4
    else
      frame.icon:Hide()
    end
  end
  local at = row.kind == "npc" and waypointOf(row.entry) or nil
  local right = 0
  if frame.pin then
    frame.pin.at = at
    frame.pin.waypointFor = at and Trainers.WaypointFor(row) or nil
    setShown(frame.pin, at ~= nil)
    if at then
      right = Trainers.PIN + 4
    end
  end
  local zoneW = 0
  if frame.zone then
    local zone = row.zone
    if type(zone) == "string" and zone ~= "" then
      zoneW = Trainers.ZONE_W
      frame.zone:ClearAllPoints()
      frame.zone:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -right - 2, 0)
      frame.zone:SetHeight(Trainers.ROW_H)
      frame.zone:SetWidth(zoneW)
      setText(frame.zone, zone)
      frame.zone:Show()
    else
      setText(frame.zone, "")
      frame.zone:Hide()
    end
  end
  if frame.label then
    frame.label:ClearAllPoints()
    -- Brief PR16: the footer is one sentence wrapped under the gap above it; every other row one
    -- line, set at the foot of its height (a heading's gap is above it).
    local wraps = row.kind == "footer"
    if type(frame.label.SetWordWrap) == "function" then
      pcall(frame.label.SetWordWrap, frame.label, wraps)
    end
    if wraps then
      frame.label:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -Trainers.SECTION_GAP)
      frame.label:SetHeight(Trainers.FOOTER_H)
      if type(frame.label.SetJustifyV) == "function" then
        pcall(frame.label.SetJustifyV, frame.label, "TOP")
      end
    else
      frame.label:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left, 0)
      frame.label:SetHeight(Trainers.ROW_H)
    end
    frame.label:SetWidth(math.max(width - left - right - zoneW - 6, 20))
    setText(frame.label, row.text or "")
    textColour(frame.label, ROW_COLOURS[row.kind] or Trainers.NAME_WORD)
  end
  if frame.hover then
    setShown(frame.hover, row.key ~= nil)
  end
  if type(frame.EnableMouse) == "function" then
    pcall(frame.EnableMouse, frame, row.key ~= nil or row.kind == "note")
  end
  frame:Show()
end

local function panelHeight()
  local host = Trainers.host
  local p = pane()
  -- Brief PR19: under the trainer warning strip too, where the pane shows one.
  local top = (p and type(p.TopOffset) == "function" and p.TopOffset()) or (p and p.TOP_H) or 56
  local h = number(host, "GetHeight")
  if not h then
    return 360
  end
  return math.max(h - top - Trainers.PAD * 2, Trainers.ROW_H * 4 + Trainers.INNER * 2)
end

-- Draws the rows from the offset down, frames only for the rows that fit inside the padding.
local function drawRows()
  local panel = Trainers.panel
  if not panel then
    return 0
  end
  local rows = Trainers.rows or EMPTY
  local room = (rawget(panel, "height") or panelHeight()) - Trainers.INNER * 2
  local most = Trainers.MaxOffset(rows, room)
  Trainers.offset = Trainers.ClampOffset(Trainers.offset, most + 1, 1)
  local width = Trainers.PANEL_W - Trainers.INNER * 2 - Trainers.CLOSE
  panel.frames = panel.frames or {}
  local drawn, y, slot = 0, 0, 0
  while true do
    local index = Trainers.offset + slot + 1
    local row = rows[index]
    local h = Trainers.RowHeight(row, index)
    if not row or (slot > 0 and y + h > room) then
      break
    end
    slot = slot + 1
    local frame = panel.frames[slot]
    if not frame then
      frame = buildRow(panel)
      panel.frames[slot] = frame
    end
    if frame then
      local w = slot == 1 and width - Trainers.NearestRoom() or width + Trainers.CLOSE
      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", panel, "TOPLEFT", Trainers.INNER, -Trainers.INNER - y)
      frame:SetHeight(h)
      frame:SetWidth(w)
      fillRow(frame, row, w)
      drawn = drawn + 1
    end
    y = y + h
  end
  for extra = slot + 1, #panel.frames do
    local frame = panel.frames[extra]
    if frame then
      frame.row = nil
      frame:Hide()
    end
  end
  return drawn
end

-- Lifts the panel over the viewport by frame level alone. Brief PW2 (the round AC review): it no
-- longer names a strata. The panel and the viewport are both children of the pane's board, so they
-- already share the strata the window gives them; a panel pinned to the viewport's strata by name
-- stayed there when PW1 moved the ItemTree window under the client's profession window (UI/Frame.lua
-- setStrata moves only the window and the two children it names), and floated over that window.
-- Left unpinned, the panel takes its strata from its parent, the way the viewport, canvas and cards
-- do, wherever the window goes.
local function raiseOver(frame)
  local p = pane()
  local over = p and p.viewport or nil
  if type(frame.SetFrameLevel) == "function" and type(over) == "table" and type(over.GetFrameLevel) == "function" then
    local ok, level = pcall(over.GetFrameLevel, over)
    if ok and tonumber(level) then
      pcall(frame.SetFrameLevel, frame, level + 20)
    end
  end
end

--------------------------------------------------------------------------------
-- Brief BQ25b (owner QA 2026-10-10 item 55): "Show nearest", top right beside the close button
--------------------------------------------------------------------------------

Trainers.NEAREST_GAP = 4

--- The room the "Show nearest" button takes out of the panel's first row: its width and the gap,
--- or 0 while it is hidden.
function Trainers.NearestRoom()
  local panel = Trainers.panel
  local button = type(panel) == "table" and rawget(panel, "nearest") or nil
  if type(button) ~= "table" or not rawget(button, "wanted") then
    return 0
  end
  return (number(button, "GetWidth") or 0) + Trainers.NEAREST_GAP
end

-- Brief NR1a: the profession kind the trainer search knows the chosen line by, or nil.
local function searchKind(line)
  local search = ItemTree.TrainerSearch
  if type(search) ~= "table" or type(search.LineKind) ~= "function" then
    return nil
  end
  local ok, kind = pcall(search.LineKind, line)
  return ok and type(kind) == "string" and kind or nil
end

--- The press: its line in chat, the waypoint, the trainer lifted to the top of the panel marked
--- "Nearest: <zone>", and then its page opened on the Map tab, the same as a click on its row.
--- Brief NR1 (QA item 134): the trainer is the trainer search divider's own answer
--- (Core/TrainerSearch.lua TrainerSearch.FindNearest over the line's kind): every trainer of the
--- profession we hold a place for, Classic Era and Forever alike, ranked in one place
--- (Nearest.FindTrainer) by who teaches the chosen line's next rank (its rank and cap), the player's
--- side or both, then distance. Where the search is not loaded, the same ranking over the panel's
--- own list. Answers what the find said, or nil.
function Trainers.ShowNearest()
  local content = Trainers.content
  local Nearest = ItemTree.Nearest
  if type(content) ~= "table" or type(Nearest) ~= "table" or type(Nearest.FindAmong) ~= "function" then
    return nil
  end
  local side = playerSide()
  local word = nil
  if side == 1 then
    word = "Alliance"
  elseif side == 2 then
    word = "Horde"
  end
  local chosen = Trainers.chosen or EMPTY
  local skill = { rank = chosen.rank, max = chosen.max }
  local search = ItemTree.TrainerSearch
  local kind = searchKind(chosen.line)
  local ok, found = false, nil
  if kind and type(search) == "table" and type(search.FindNearest) == "function" then
    ok, found = pcall(search.FindNearest, kind, word, skill)
  end
  if not ok or type(found) ~= "table" then
    if type(Nearest.FindTrainer) == "function" and type(Nearest.NextStep) == "function" then
      local step = Nearest.NextStep(skill.rank, skill.max)
      ok, found = pcall(Nearest.FindTrainer, Trainers.NearestEdges(content), { faction = word, step = step })
    else
      ok, found = pcall(Nearest.FindAmong, Trainers.NearestEdges(content), "trainer", word)
    end
  end
  if not ok or type(found) ~= "table" then
    return nil
  end
  local chat = rawget(_G, "DEFAULT_CHAT_FRAME")
  if type(found.text) == "string" and type(chat) == "table" and type(chat.AddMessage) == "function" then
    pcall(chat.AddMessage, chat, (L["ItemTree"] or "ItemTree") .. ": " .. found.text)
  end
  local info = infoPanel()
  if type(found.waypoint) == "table" and info and type(info.SetWaypoint) == "function" then
    -- Brief AT3 (pre-QA review note m1): with what it is for, the words the main window's Show
    -- nearest gives its toast (Core/Nearest.lua Nearest.WaypointFor, "Randal Worth, nearest trainer").
    local label = nil
    if type(Nearest.WaypointFor) == "function" then
      local named, words = pcall(Nearest.WaypointFor, found)
      label = named and words or nil
    end
    pcall(info.SetWaypoint, found.waypoint, label)
  end
  if type(found.key) ~= "string" then
    return found
  end
  local result = type(found.result) == "table" and found.result or EMPTY
  local best = type(result.best) == "table" and result.best or EMPTY
  local point = type(result.point) == "table" and result.point or EMPTY
  Trainers.nearest = { key = found.key, line = chosen.line, name = best.name, zone = point.zone, side = best.faction }
  Trainers.rows = Trainers.Rows(content, Trainers.NearestLift(Trainers.nearest))
  Trainers.offset = 0
  local panel = Trainers.panel
  if panel then
    Trainers.Place(panel)
    Trainers.Draw()
  end
  local p = pane()
  if p and type(p.OpenKey) == "function" then
    pcall(p.OpenKey, found.key, { trainer = true })
  end
  return found
end

--- Builds the "Show nearest" button on the panel: the window's red plate button where it can be
--- had (UI/Skin.lua Skin.PlateButton), the flat face otherwise. Hidden until the panel lists a
--- trainer of the player's side with a page. Answers the button or nil.
function Trainers.BuildNearest(panel)
  local s = skin()
  local h = Trainers.CLOSE
  local button = s and type(s.PlateButton) == "function" and s.PlateButton(panel, Trainers.BUTTON_MIN_W, h) or nil
  if not button then
    button = newFrame("Button", panel)
    if not button then
      return nil
    end
    button:SetSize(Trainers.BUTTON_MIN_W, h)
    button.face = wash(button, "BACKGROUND", Trainers.FACE)
    if button.face then
      button.face:SetAllPoints(button)
    end
    button.edges = edges(button, Trainers.BORDER)
    showEdges(button.edges, true, Trainers.BORDER)
    button.hover = wash(button, "HIGHLIGHT", Trainers.HOVER)
    if button.hover then
      button.hover:SetAllPoints(button)
    end
    if type(button.RegisterForClicks) == "function" then
      pcall(button.RegisterForClicks, button, "LeftButtonUp")
    end
  end
  button.label = newText(rawget(button, "labelParent") or button, Trainers.FONT_SM, Trainers.BUTTON_WORD, "CENTER")
  if button.label then
    button.label:SetPoint("LEFT", button, "LEFT", 4, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -4, 0)
    setText(button.label, Trainers.WORDS.showNearest)
    local width = Trainers.ButtonWidth(Trainers.WORDS.showNearest, stringWidth(button.label))
    button:SetWidth(width)
  end
  button:ClearAllPoints()
  button:SetPoint(
    "TOPRIGHT",
    panel,
    "TOPRIGHT",
    -Trainers.INNER / 2 - Trainers.CLOSE - Trainers.NEAREST_GAP,
    -Trainers.INNER / 2
  )
  setScript(button, "OnClick", function()
    Trainers.ShowNearest()
  end)
  local function onEnter(self)
    textTooltip(self, Trainers.WORDS.showNearest, { Trainers.WORDS.nearestHint })
  end
  if button.plated and s and type(s.PlateScripts) == "function" then
    s.PlateScripts(button, setScript, { OnEnter = onEnter, OnLeave = hideTooltip })
  else
    setScript(button, "OnEnter", onEnter)
    setScript(button, "OnLeave", hideTooltip)
  end
  button.wanted = false
  button:Hide()
  return button
end

-- Shows the button where the trainer search knows the line's profession (brief NR1a), or the panel
-- lists a trainer of the player's side with a page.
local function paintNearest(panel)
  local button = type(panel) == "table" and rawget(panel, "nearest") or nil
  if type(button) ~= "table" then
    return
  end
  local chosen = Trainers.chosen or EMPTY
  local wanted = Trainers.NearestWanted(Trainers.content, searchKind(chosen.line))
  button.wanted = wanted
  setShown(button, wanted)
end

local function buildPanel()
  if Trainers.panel then
    return Trainers.panel
  end
  local host = Trainers.host
  if type(host) ~= "table" then
    return nil
  end
  local panel = newFrame("Frame", host)
  if not panel then
    return nil
  end
  panel.fill = wash(panel, "BACKGROUND", Trainers.PANEL_FILL, -7)
  if panel.fill then
    panel.fill:SetAllPoints(panel)
  end
  panel.face = wash(panel, "BACKGROUND", Trainers.FACE, -6)
  if panel.face then
    panel.face:SetAllPoints(panel)
  end
  panel.edges = edges(panel, Trainers.BORDER)
  if type(panel.EnableMouse) == "function" then
    pcall(panel.EnableMouse, panel, true)
  end
  if type(panel.EnableMouseWheel) == "function" then
    pcall(panel.EnableMouseWheel, panel, true)
  end
  setScript(panel, "OnMouseWheel", function(_, delta)
    delta = tonumber(delta) or 0
    if delta == 0 then
      return
    end
    Trainers.offset = (Trainers.offset or 0) + (delta > 0 and -3 or 3)
    drawRows()
  end)
  local close = newFrame("Button", panel)
  if close then
    close:SetSize(Trainers.CLOSE, Trainers.CLOSE)
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -Trainers.INNER / 2, -Trainers.INNER / 2)
    close.icon = newTexture(close, "ARTWORK")
    if close.icon then
      close.icon:SetAllPoints(close)
      applyAsset(close.icon, "BUTTON_CLOSE")
    end
    if type(close.RegisterForClicks) == "function" then
      pcall(close.RegisterForClicks, close, "LeftButtonUp")
    end
    setScript(close, "OnClick", function()
      Trainers.Close()
    end)
    setScript(close, "OnEnter", function(self)
      textTooltip(self, Trainers.WORDS.close, nil)
    end)
    setScript(close, "OnLeave", hideTooltip)
  end
  panel.close = close
  panel.nearest = Trainers.BuildNearest(panel)
  panel:Hide()
  panel.shown = false
  Trainers.panel = panel
  return panel
end

-- Sizes and places the panel over the canvas, anchored top right under the rank bar.
local function place(panel)
  local p = pane()
  local top = (p and p.TOP_H) or 56
  local most = panelHeight()
  local h = math.min(Trainers.RowsHeight(Trainers.rows or EMPTY) + Trainers.INNER * 2, most)
  h = math.max(h, Trainers.ROW_H + Trainers.INNER * 2)
  panel.height = h
  panel:ClearAllPoints()
  panel:SetPoint("TOPRIGHT", Trainers.host, "TOPRIGHT", -Trainers.PAD, -top)
  panel:SetSize(Trainers.PANEL_W, h)
  paint(panel, Trainers.PANEL_W, h)
  -- The flat card carries the panel's fill itself; the square washes would show at its corners.
  setShown(panel.face, not panel.skinned)
  setShown(panel.fill, not panel.skinned)
  raiseOver(panel)
  paintNearest(panel)
end
Trainers.Place = place
Trainers.Draw = drawRows

-- One plain line in the panel, for loading and for a load that failed.
local function plainLine(text)
  Trainers.rows = { { kind = "note", text = text } }
  Trainers.offset = 0
end

--- Fills the open panel for the chosen line: loads the data on the first fill (Trainers.Load),
--- collects the content and draws the rows. Answers the rows drawn.
function Trainers.Fill()
  local panel = buildPanel()
  local chosen = Trainers.chosen
  if not panel or not chosen then
    return 0
  end
  if not Trainers.sources then
    plainLine(Trainers.WORDS.loading)
    place(panel)
    drawRows()
    Trainers.sources = Trainers.Load()
  end
  if not Trainers.sources then
    plainLine(Trainers.WORDS.failed)
  else
    local ok, content = pcall(Trainers.Content, {
      line = chosen.line,
      name = chosen.name,
      rank = chosen.rank,
      max = chosen.max,
      tracks = ItemTree.ProfessionTracks,
      faction = playerSide(),
      sources = Trainers.sources,
      nameOf = itemNameOf,
      -- Brief F155: "Hide other faction data".
      hideOther = hidesOtherFaction(),
    })
    if ok and type(content) == "table" then
      Trainers.content = content
      -- Brief BQ25b: a "Show nearest" answer stays lifted while the panel is on the same line.
      local held = Trainers.nearest
      if type(held) == "table" and held.line ~= chosen.line then
        Trainers.nearest, held = nil, nil
      end
      Trainers.rows = Trainers.Rows(content, Trainers.NearestLift(held))
    else
      Trainers.content = nil
      plainLine(Trainers.WORDS.failed)
    end
  end
  Trainers.offset = 0
  place(panel)
  panel:Show()
  panel.shown = true
  return drawRows()
end

--- Opens the panel for the chosen line.
function Trainers.Open()
  if not Trainers.chosen then
    return false
  end
  Trainers.open = true
  return Trainers.Fill() > 0
end

--- Closes the panel.
function Trainers.Close()
  Trainers.open = false
  local panel = Trainers.panel
  if panel then
    panel:Hide()
    panel.shown = false
  end
  hideTooltip()
  return true
end

--- The button's click: opens the panel, or closes it where it is open.
function Trainers.Toggle()
  if Trainers.open then
    return Trainers.Close()
  end
  return Trainers.Open()
end

return Trainers
