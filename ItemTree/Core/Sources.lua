-- Where an item comes from: the facts a source row carries, whatever draws it. Pure Lua above
-- the divider at the foot, where the one client read (a currency's name) is guarded.
-- Loaded as: local _, ItemTree = ...
--
-- Sources.Source turns one up edge into the type, zone, rate, price and confidence a player
-- compares sources by, and is the one place those are worked out. Core/ViewModel.lua hangs it
-- on every source row walking up, which is the only caller: the flat table the old Sources tab
-- drew is gone, and so are Sources.Rows, Sources.Counts and Sources.Notice.
--
-- Only edges that answer "where do I get this" are sources. TAUGHT_BY, REQUIRES_TOOL,
-- REAGENT and BELONGS_TO_SKILL are up edges too, but they answer something else, so they
-- are not listed here.
local _, ItemTree = ...

local Edges = ItemTree.Edges
local Confidence = ItemTree.Confidence
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local Sources = {}
ItemTree.Sources = Sources

-- Edge type name to the type column. The column is the English wording and its own locale key:
-- a row carries the key and draws L of it, so a translated client never changes what a filter
-- or a count is keyed by.
Sources.TYPES = {
  PRODUCED_BY = "Recipe",
  OPENED_BY = "Key",
  DROPPED_BY = "Drop",
  SKINNED_FROM = "Drop",
  SOLD_BY = "Vendor",
  QUEST_REWARD = "Quest",
  QUEST_PROVIDED = "Quest",
  GATHERED_FROM = "Gather",
  FISHED_FROM = "Fished",
  CONTAINED_IN = "Contained",
  LOOTED_FROM = "Contained",
  -- A recipe nothing teaches is learnt from a trainer, which Core/Graph.lua emits as a row of
  -- its own; without a type here the row was the one source with a blank type column.
  LEARNED_FROM_TRAINER = "Trainer",
  -- The three edges a CREATURE's Loot tab draws (brief E57). They walk down rather than up, and
  -- they are still sources in the only sense this file cares about: the row answers "where does
  -- this item come from", read from the creature's end instead of the item's. The word matters
  -- more here than anywhere else, because the sidebar's All row puts all three kinds of loot in
  -- one list and the type column is what tells a drop from a skin from a pocket.
  CREATURE_DROPS = "Drop",
  CREATURE_SKINNED = "Skinned",
  CREATURE_POCKETED = "Pickpocketed",
  -- Brief OL1: what a chest holds (its Loot tab) and what an openable item holds (its Contains tab),
  -- the "Found in" and "Contained in" rows read from the container's end, in the same word.
  OBJECT_CONTAINS = "Contained",
  CONTAINS = "Contained",
}

-- The type column of a gathering node's ZONE row (brief D6). A herb or a vein out of the shipped
-- Classic Era table is a node row ("Rich Thorium Vein", Gather, ~5.8%) that opens onto the zones
-- it stands in, and each of those says what it is in the type column instead of "Gather": the
-- words are the group Core/EraSources.lua files it under, "Mined in" or "Gathered in", read back
-- by key so a translated client matches its own words.
Sources.PLACE_TYPES = { "Mined in", "Gathered in" }

local function placeType(group)
  if type(group) ~= "string" then
    return nil
  end
  for _, key in ipairs(Sources.PLACE_TYPES) do
    if L[key] == group then
      return key
    end
  end
  return nil
end

-- The words a row says a provider's claim by. The key is the short stable one an adapter in
-- Providers/ stamps on its edges, and the value is the English wording and its own locale key,
-- the way Sources.TYPES is: a row carries the key and draws L of it, so a translated client
-- never changes what a filter is keyed by. Core names the addons rather than Providers/ so
-- that a load with no adapters still reads an old edge correctly.
-- "era" is not an installed addon: it is the historical Classic Era table the addon ships
-- (Core/EraSources.lua), and it says where the claim came from in exactly the same column every
-- other provenance does. It is the same short key the percentSource below uses, because it is
-- the same fact about the same data.
Sources.PROVENANCE = {
  att = "via All The Things",
  questie = "via Questie",
  era = "Classic Era",
  -- Brief V1: Forever's own vendors, out of the client's CollectableSource tables
  -- (Core/ForeverVendors.lua). The same words Core/Confidence.lua gives the mined tier, because it
  -- is the same fact: the row is the client's own statement, not a guess.
  client = "From client data",
  -- Brief PS1: a source players recorded in game that the shared finds pipeline shipped
  -- (Core/PlayerSources.lua), or the player's own record of a fact it ships. Plain data with no
  -- badge; this is the one line its tooltip says about where it comes from.
  player = "Reported by players",
}

-- The translated words for a provenance key, or nil for an edge with no provider behind it
-- (everything the addon ships, and everything the collector saw).
function Sources.ProvenanceLabel(provenance)
  local label = type(provenance) == "string" and Sources.PROVENANCE[provenance] or nil
  if not label then
    return nil
  end
  return L[label]
end

-- Copper to the client's money text: 125023 -> "12g 50s 23c".
function Sources.MoneyText(copper)
  if type(copper) ~= "number" or copper <= 0 then
    return nil
  end
  local whole = math.floor(copper)
  local gold = math.floor(whole / 10000)
  local silver = math.floor((whole % 10000) / 100)
  local copperPart = whole % 100
  local parts = {}
  if gold > 0 then
    parts[#parts + 1] = gold .. "g"
  end
  if silver > 0 then
    parts[#parts + 1] = silver .. "s"
  end
  if copperPart > 0 or #parts == 0 then
    parts[#parts + 1] = copperPart .. "c"
  end
  return table.concat(parts, " ")
end

-- Brief PS1 bundle prices (QA item 300, 2026-10-20): a vendor's money price is for the bundle it
-- sells, the item row's vs (VendorStackCount, shipped above 1 only). The merchant window's price and
-- the item's buy price (bp) are both per bundle: the forever branch's MerchantFrame.lua
-- (Blizzard_UIPanels_Game/Mainline) draws info.stackCount on the button (line 299) and divides
-- info.price by it for one item (line 719). Refreshing Spring Water's 25c buys 5. The count a bundle
-- holds, or nil for a bundle of 1 or a row stating none. Pure.
function Sources.BundleCount(item)
  local count = type(item) == "table" and tonumber(item.vs) or nil
  if count == nil or count ~= count or count == math.huge then
    return nil
  end
  count = math.floor(count)
  if count <= 1 then
    return nil
  end
  return count
end

-- Money words with the bundle they buy, "25c for 5", or the money alone where count is no bundle
-- (nil or 1), as before. nil where there are no money words. Pure.
function Sources.BundlePrice(money, count)
  if type(money) ~= "string" or money == "" then
    return nil
  end
  count = tonumber(count)
  if count == nil or count ~= count or count == math.huge or math.floor(count) <= 1 then
    return money
  end
  return string.format(L["%s for %d"], money, math.floor(count))
end

-- ids of a { [id] = amount } table, lowest first, so a price reads the same every time.
local function sortedIds(map)
  local ids = {}
  if type(map) == "table" then
    for id, amount in pairs(map) do
      if type(id) == "number" and type(amount) == "number" and amount > 0 then
        ids[#ids + 1] = id
      end
    end
  end
  table.sort(ids)
  return ids
end

-- A name a namer answered, or nil. A namer that raises or answers nothing reads as no name.
local function nameBy(namer, id)
  if type(namer) ~= "function" then
    return nil
  end
  local ok, name = pcall(namer, id)
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- What a vendor asks, in words (brief M2): every currency, then every item, then the money,
-- joined by commas.
--
--   { currency = { [3402] = 30 } }                      -> "30 Merchant's Favor"
--   { copper = 50000, currency = { [3402] = 200 } }     -> "200 Merchant's Favor, 5g"
--   { items = { [1234] = 3 } }                          -> "3 x Linen Cloth"
--   { copper = 1250 }                                   -> "12s 50c"
--
-- cost is { copper, currency = { [id] = amount }, items = { [id] = amount } }, any part absent.
-- nameCurrency and nameItem each take an id and answer its name or nil; a currency with no name
-- reads "currency 3402" and an item "item 1234". The currency keeps the game's own spelling,
-- because it is the game's name for it. nil when the cost states nothing. Pure.
function Sources.CostText(cost, nameCurrency, nameItem)
  if type(cost) ~= "table" then
    return nil
  end
  local parts = {}
  for _, id in ipairs(sortedIds(cost.currency)) do
    local name = nameBy(nameCurrency, id) or string.format(L["currency %d"], id)
    parts[#parts + 1] = math.floor(cost.currency[id]) .. " " .. name
  end
  for _, id in ipairs(sortedIds(cost.items)) do
    local name = nameBy(nameItem, id) or string.format(L["item %d"], id)
    parts[#parts + 1] = math.floor(cost.items[id]) .. " x " .. name
  end
  local money = Sources.MoneyText(cost.copper)
  if money then
    parts[#parts + 1] = money
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts, ", ")
end

-- An item's name from the shipped Names module (Data:ItemGlance), or nil. No client call and no
-- item query: an item the data cannot name reads "item 1234" in CostText.
function Sources.ItemName(itemId)
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.ItemGlance) ~= "function" then
    return nil
  end
  local ok, glance = pcall(data.ItemGlance, data, itemId)
  if ok and type(glance) == "table" and type(glance.name) == "string" then
    return glance.name
  end
  return nil
end

-- A currency's name: the client's own, else the name the shipped Merchant's Favor block gives the
-- one currency it states (brief M3), so a shipped row reads "200 Merchant's Favor" even where the
-- client has not answered. nil where neither names it.
local function currencyWords(currencyId)
  local name = Sources.CurrencyName(currencyId)
  if name then
    return name
  end
  local favour = Sources.Favour
  local shipped = favour and favour.Table() or nil
  local currency = shipped and shipped.currency or nil
  if type(currency) == "table" and currency.id == currencyId and type(currency.name) == "string" then
    return currency.name
  end
  return nil
end

-- The price column for a vendor row. A cost the edge carries (a currency or an item, read off the
-- merchant window the player opened) is worded with the edge's money price beside it. Otherwise
-- a money price the edge itself knows wins, because it is the price this vendor asks; the item
-- record's buy price is what every other vendor for the item falls back on.
--
-- Brief PS1 bundle prices: a money price says the bundle it buys, "25c for 5" (Sources.BundlePrice
-- over the item row's vs), the edge's own price (a merchant window the player or the shared finds
-- read, which is the bundle's too) and the buy price alike. A cost in a currency or an item reads as
-- before. Nothing ranks vendors by price (the Sold by sort reads tier, side and rate; Show nearest
-- reads distance), and one item has one vs per build, so every vendor row of an item states a price
-- for the same bundle and any compare of two of them is like with like. The second answer is the
-- bundle the words state, nil where they state none.
local function vendorPrice(edge, item)
  local cost = edge.cost
  if type(cost) == "table" and (#sortedIds(cost.currency) > 0 or #sortedIds(cost.items) > 0) then
    local text = Sources.CostText({
      copper = edge.price,
      currency = cost.currency,
      items = cost.items,
    }, currencyWords, Sources.ItemName)
    if text then
      return text, nil
    end
  end
  local money = Sources.MoneyText(edge.price)
  if not money and item then
    money = Sources.MoneyText(item.bp)
  end
  if not money then
    return nil, nil
  end
  local count = Sources.BundleCount(item)
  return Sources.BundlePrice(money, count), count
end

-- The client line the imported drop rates were measured on. An adapter in Providers/ reads
-- them out of a database built for Classic Era and stamps the edge percentSource = "era";
-- the WoW Forever beta is a different line (1.60.1) and retunes loot, so the same number is
-- worth showing there and its precision is not. Only the leading "major.minor" is compared,
-- because a rate does not change between two builds of the same line.
Sources.ERA = "era"

local function line(build)
  if type(build) ~= "string" then
    return nil
  end
  return build:match("^(%d+%.%d+)")
end

-- The build the data was imported against, which Data/generated/Meta.lua states, with the
-- Era line as the fallback for a load with no data module.
local function baselineLine()
  local data = ItemTree.Data
  local meta = data and data.Meta or nil
  return line(meta and meta.baseline) or "1.15"
end

-- Whether an imported rate should be drawn as an estimate on the client that is running.
-- Pure: both builds are passed in, and an unknown client build is taken at its word rather
-- than hedged, so nothing changes on a load that could not read one.
function Sources.RateIsApproximate(percentSource, clientBuild, baseline)
  if percentSource ~= Sources.ERA then
    return false
  end
  local running = line(clientBuild)
  if not running then
    return false
  end
  return running ~= (line(baseline) or baselineLine())
end

local function approximate(edge)
  local state = ItemTree.state or {}
  return Sources.RateIsApproximate(edge.percentSource, state.clientBuild)
end

-- Whether the whole row is history rather than a claim about this client: a row out of the
-- shipped Classic Era table (Core/EraSources.lua). Read off the provenance, not off the build
-- the client is running, because a row is history because of where it came from and would still
-- be history on a client this addon could not read a build number out of.
function Sources.IsHistorical(provenance)
  return provenance == Sources.ERA
end

-- What the rate column says for a historical row, and what the row's tooltip says instead of it.
-- "~12.5%" can never be read as a rate this client measured, and the tooltip spells out both
-- halves of why: about that much, and about that much somewhere else.
local HISTORICAL_RATE = "About %s in Classic Era"

function Sources.HistoricalRate(percent)
  local text = Confidence.Chance(percent)
  if not text then
    return nil, nil
  end
  return Confidence.Historical(text), string.format(L[HISTORICAL_RATE], text)
end

-- The words a shipped Classic Era row (Core/EraSources.lua) says beyond the name of the thing
-- it points at, and the one place they live.
--
-- A source row draws a name and three narrow columns, and none of them has room for "only while
-- you are on a quest that asks for it". So a row that needs one carries a qualifier: the pane
-- draws it after the row's own name in brackets ("Skum (only while on a quest)", brief LF1, the
-- owner's QA item 248: "Limited stofck should also be the [item] (limited stock 1)"; it read "Skum,
-- only while on a quest") and the row's tooltip says it again on a line of its own. Each is a
-- format rather than a join, so a locale can put the number and the words where its own grammar
-- wants them, and each English wording is its own locale key the way Sources.TYPES above is.
-- WITH_NOTE joins two parts of one list (several qualifiers in one phrase, a creature's kind and
-- its band); QUALIFIED puts that phrase after the name it qualifies.
local MORE = "and %d more"
local LEVEL_BAND = "level %d to %d"
local ONLY_QUEST = "only while on a quest"
local ONLY_NAMED_QUEST = "only on the quest %s"
local LIMITED_STOCK = "limited stock %d"
local WITH_NOTE = "%s, %s"
local QUALIFIED = "%s (%s)"

-- The same two counts worded as an OFFER, for a summary row the table really ships the rest of
-- the list behind: pressing it draws those sources under the named rows, so the row has to read
-- as something to press rather than as a fact about a number. "Show %d more" is the same key the
-- tree's own group cap row uses, because it is the same offer in the same words.
local SHOW_MORE = "Show %d more"
local SHOW_GROUP = "Show %s"

-- What a gathering node row's zone column says: how many zones it opens onto.
local ZONE_COUNT = "%d zones"
local ONE_ZONE = "1 zone"

-- What a category is called where one summary row stands for the whole of it and no row above
-- it named anything: "Sold by 184 vendors" rather than "Sold by and 184 more". Keyed by the
-- category word Core/EraSources.lua files the row under; a category with no word of its own
-- counts plain sources, which is true of every one of them.
local GROUP_COUNTS = {
  vendor = "%d vendors",
  boss = "%d creatures",
  creature = "%d creatures",
  skinned = "%d creatures",
  pickpocket = "%d creatures",
  quest = "%d quests",
}
local GROUP_COUNT = "%d sources"

local function counted(format_, number)
  if type(number) ~= "number" or number <= 0 then
    return nil
  end
  return string.format(L[format_], number)
end

-- Two parts of one list, joined: "level 11 to 36, only while on a quest" (a row's qualifiers, as
-- Sources.Note joins them), "Beast, Wolf" (Sources.KindText). A format, so a locale joins them its
-- own way, and the one place the comma lives. Brief LF1 (QA item 248): a name and its qualifier are
-- Sources.Qualified's, in brackets; this is the list inside them.
function Sources.WithNote(text, note)
  if type(note) ~= "string" or note == "" then
    return text
  end
  if type(text) ~= "string" or text == "" then
    return note
  end
  return string.format(L[WITH_NOTE], text, note)
end

-- Brief LF1 (the owner's QA item 248, the standing rule: a qualifier on a label goes in brackets,
-- never after a comma): a row's own words and the qualifier phrase they end with, "Strong Fishing
-- Pole (limited stock 1)", "Skum (only while on a quest)", "Show 15 more (level 11 to 36)". The
-- text alone where there is no note, the note alone where there is no text. Pure.
function Sources.Qualified(text, note)
  if type(note) ~= "string" or note == "" then
    return text
  end
  if type(text) ~= "string" or text == "" then
    return note
  end
  return string.format(L[QUALIFIED], text, note)
end

-- "and 239 more": what a summary row says under the rows that named the best of its group.
function Sources.MoreText(more)
  return counted(MORE, more)
end

-- "184 vendors": what a summary row says where it is the whole category.
function Sources.GroupCount(total, category)
  return counted(GROUP_COUNTS[category] or GROUP_COUNT, total)
end

-- "Show 239 more": the same count on a summary row the rest of whose list is shipped, so the row
-- reads as the offer it now is.
function Sources.ShowMoreText(more)
  return counted(SHOW_MORE, more)
end

-- "Show 184 vendors": the same, for a summary row that is the whole category. The words it is
-- offering are Sources.GroupCount's, so a locale writes the count once and the offer once.
function Sources.ShowText(text)
  if type(text) ~= "string" or text == "" then
    return nil
  end
  return string.format(L[SHOW_GROUP], text)
end

-- "4 zones": how many zones a gathering node row opens onto, for its zone column and its tooltip.
function Sources.ZoneCount(count)
  if count == 1 then
    return L[ONE_ZONE]
  end
  return counted(ZONE_COUNT, count)
end

-- "level 11 to 36", the band of the group a summary row stands for. Also the band of one
-- creature, where the source states one: the words are the same fact either way.
-- Brief TV1 (QA item 347, the creature search row's "Humanoid, level 11 to 11"): "level 11" where
-- both ends are one level, as the creature page's own line says it (Core/ViewModel.lua, brief Z4).
function Sources.LevelBand(low, high)
  if type(low) ~= "number" or type(high) ~= "number" then
    return nil
  end
  if low == high then
    return string.format(L["level %d"], low)
  end
  return string.format(L[LEVEL_BAND], low, high)
end

-- What KIND of creature a row names, in words. The ids are the source database's own
-- classification (CreatureType, and the beast Family under it, see Core/EraSources.lua KindOf);
-- the WORDS are ours, one locale key each, because no shipped table states a name for either and
-- a number in a tooltip says nothing to anybody.
--
-- The eleven types are the classification whole, so an id this table does not carry is a later
-- one and says nothing rather than guessing. 10 is the source's own "not specified", which is a
-- real answer about 191 of the names and is worded as what it means to a player.
Sources.CREATURE_TYPES = {
  [1] = "Beast",
  [2] = "Dragonkin",
  [3] = "Demon",
  [4] = "Elemental",
  [5] = "Giant",
  [6] = "Undead",
  [7] = "Humanoid",
  [8] = "Critter",
  [9] = "Mechanical",
  [10] = "Unknown creature",
  [11] = "Totem",
}

-- The families under those types: the seventeen beast families of this data, and the one demon
-- family it carries. A family with no word here falls back to its type alone, which is the same
-- answer a creature with no family at all gives.
Sources.CREATURE_FAMILIES = {
  [1] = "Wolf",
  [2] = "Cat",
  [3] = "Spider",
  [4] = "Bear",
  [5] = "Boar",
  [6] = "Crocolisk",
  [7] = "Carrion Bird",
  [8] = "Crab",
  [9] = "Gorilla",
  [11] = "Raptor",
  [12] = "Tallstrider",
  [15] = "Felhunter",
  [20] = "Scorpid",
  [21] = "Turtle",
  [24] = "Bat",
  [25] = "Hyena",
  [26] = "Bird of Prey",
  [27] = "Wind Serpent",
}

-- "Beast, Wolf, level 23 to 24": the one line a source row's tooltip says about the creature it
-- names, joined the way every other qualifier on that row is. nil for a row with no kind behind
-- it, and for a kind so far outside the classification that nothing here words it.
--
-- creature is the edge's own { type, family, low, high } (Core/Graph.lua EDGE_FIELDS).
function Sources.KindText(creature)
  if type(creature) ~= "table" then
    return nil
  end
  local typeWord = Sources.CREATURE_TYPES[creature.type]
  local familyWord = Sources.CREATURE_FAMILIES[creature.family]
  local text = nil
  if typeWord then
    text = L[typeWord]
  end
  if familyWord then
    text = Sources.WithNote(text, L[familyWord])
  end
  return Sources.WithNote(text, Sources.LevelBand(creature.low, creature.high))
end

--- Brief TV4 (the owner's designs for the inner tooltips, 2026-10-21, item 347): a level as a row's
--- hover writes it in brackets after the creature's kind, "11", or "7 - 8" for a band. nil for no
--- level. Pure.
function Sources.LevelRange(low, high)
  low, high = tonumber(low), tonumber(high)
  if not low and not high then
    return nil
  end
  low, high = low or high, high or low
  if low == high then
    return tostring(low)
  end
  return string.format(L["%s - %s"], tostring(low), tostring(high))
end

--- Brief TV4: the creature's kind with its level in brackets, the Type line of a row's hover:
--- "Humanoid (11)", "Beast, Wolf (23 - 24)". The kind alone where no level is stated, the level
--- alone where no kind is, nil for neither. creature is the edge's { type, family, low, high }. Pure.
function Sources.KindLevelText(creature)
  if type(creature) ~= "table" then
    return nil
  end
  local text = Sources.KindText({ type = creature.type, family = creature.family })
  return Sources.Qualified(text, Sources.LevelRange(creature.low, creature.high))
end

--- Brief TV4 (the owner's ruling C2, 2026-10-21): one map spot as the inner tooltips write it,
--- coordinates in brackets where the game tooltip cannot draw a chip: "[23.6, 27.9]", and
--- "[Stormwind: 42.1, 65.8]" where the spot is in another zone than home (the zone of the row or
--- quest the hover is about). A zone with no coordinates is "[Elwynn Forest]"; nil for neither.
--- Pure.
function Sources.SpotText(zone, x, y, home)
  zone = type(zone) == "string" and zone ~= "" and zone or nil
  x, y = tonumber(x), tonumber(y)
  if not x or not y then
    if not zone then
      return nil
    end
    return string.format(L["[%s]"], zone)
  end
  local coords = string.format("%.1f, %.1f", x, y)
  if zone and zone ~= home then
    return string.format(L["[%s: %s]"], zone, coords)
  end
  return string.format(L["[%s]"], coords)
end

--- Brief TV4: a row's qualifier split into the quest it only drops on and the rest, for the hover's
--- "Quest only drop" line. note is what Sources.Note joined ("level 11 to 36, only on the quest
--- Wanted: Hogger"). Answers onlyQuest (true where the note ends on either quest phrase), the
--- quest's title where the phrase names one, and the note with the phrase taken off (nil where
--- nothing is left). A note with no quest phrase answers false, nil, note. Pure.
function Sources.SplitQuestNote(note)
  if type(note) ~= "string" or note == "" then
    return false, nil, nil
  end
  local function escape(text)
    return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
  end
  local title, at = nil, nil
  local named = L[ONLY_NAMED_QUEST]
  local head, tail = named:match("^(.-)%%s(.*)$")
  if head then
    local start, _, captured = note:find(escape(head) .. "(.+)" .. escape(tail) .. "$")
    if start then
      title, at = captured, start
    end
  end
  if not at then
    local plain = L[ONLY_QUEST]
    if note:sub(-#plain) == plain then
      at = #note - #plain + 1
    end
  end
  if not at then
    return false, nil, note
  end
  local rest = note:sub(1, at - 1)
  local joiner = L[WITH_NOTE]:match("^%%s(.*)%%s$")
  if joiner and joiner ~= "" and rest:sub(-#joiner) == joiner then
    rest = rest:sub(1, -#joiner - 1)
  end
  if rest == "" then
    rest = nil
  end
  return true, title, rest
end

-- What a source that only gives the item while the player is on a quest asking for it says.
-- The quest where the data names exactly one and this client can title it, and the shorter
-- wording otherwise: a quest id in a row would say nothing to anybody.
function Sources.OnlyQuest(title)
  if type(title) ~= "string" or title == "" then
    return L[ONLY_QUEST]
  end
  return string.format(L[ONLY_NAMED_QUEST], title)
end

-- "limited stock 5": a vendor that holds a few of the item and restocks.
function Sources.LimitedStock(stock)
  return counted(LIMITED_STOCK, stock)
end

-- Every qualifier a row carries, joined into the one phrase it ends with, in the order given.
-- nil where the row needs none, which is nearly every row.
function Sources.Note(...)
  local text = nil
  for index = 1, select("#", ...) do
    text = Sources.WithNote(text, (select(index, ...)))
  end
  if type(text) ~= "string" or text == "" then
    return nil
  end
  return text
end

-- The words a row's hover says its claim came from: a provider's name, or for a shipped community
-- row (brief M3) the pages it rests on, by host and date.
local function provenanceLabel(edge)
  if edge.provenance == "community" and type(edge.community) == "table" then
    local text = Sources.Favour.CommunityText(edge.community.sources)
    if text then
      return text
    end
  end
  return Sources.ProvenanceLabel(edge.provenance)
end

-- The rate or price column: a drop chance, the price the vendor asks, or the skill a
-- recipe needs. It stays empty rather than guessing, the way the design asks for.
local RATE_FROM_META = { Recipe = true, Key = true }

local function rateText(edge, node, column, item)
  if edge.percent then
    if Sources.IsHistorical(edge.provenance) then
      -- Never the plain figure and never "about 3%": both read as a rate on this client, and
      -- this one was measured in another game. The second answer is the row tooltip's line.
      return Sources.HistoricalRate(edge.percent)
    end
    local text = Confidence.Percent(edge.percent / 100)
    if approximate(edge) then
      return Confidence.Approximate(text)
    end
    return text
  end
  if column == "Vendor" then
    -- The words alone: the second answer here is the rate's label, never the bundle.
    return (vendorPrice(edge, item))
  end
  if RATE_FROM_META[column] then
    return node.meta
  end
  return nil
end

-- The zone column. The edge states its zone, and a zone node falls back to naming itself.
--
-- The edge is asked first, and that order is the answer to one case: a Classic Era gathering node
-- row (brief D6) is named by the node and its column says how many zones it opens onto ("4
-- zones"), which only the edge knows. Everywhere else the two say the same thing.
--
-- The meta line is still read as the fallback: the collector writes it as "Name, Zone"
-- (Core/Collector.lua metaFor) and a store written before the edges carried a zone of their own
-- has only that line to go on. Matching a name off the front of a line is fragile, which is why
-- the field came first, but dropping the fallback would empty the column for every source the
-- player has already recorded.
--
-- Brief FX14 (the QA page check of 2026-10-17): a Classic Era quest row's zone slot holds the
-- quest's side word (Core/EraSources.lua questRow: the table states no area for a quest), and a live
-- row that took its place carries it too (Graph.AdoptSourceFacts). That word is the final lists'
-- side (Graph.QuestSide: the shipped alliance / horde lists, then the predicted side), never the
-- table's own f, which still sided the quests ItemTree-Data's QS4 opened to both sides: A Thief's
-- Reward 9339 read "Horde" on Crown of the Fire Festival 23323. The slot says nothing for a quest
-- open to both sides. Answers whether the slot holds a quest's side word, and the word to show.
local QUEST_SIDE_WORDS = { [1] = "Alliance", [2] = "Horde" }
local function questSideZone(edge, node)
  if node.kind ~= "quest" or edge.areaId ~= nil or (edge.zone ~= L["Alliance"] and edge.zone ~= L["Horde"]) then
    return false, nil
  end
  local graph = ItemTree.Graph
  local side = nil
  if type(graph) == "table" and type(graph.QuestSide) == "function" then
    local ok, answer = pcall(graph.QuestSide, nil, node.key)
    side = ok and answer or nil
  end
  local word = QUEST_SIDE_WORDS[side]
  return true, word and L[word] or nil
end

local function zoneText(edge, node)
  local sided, sideWord = questSideZone(edge, node)
  if sided then
    return sideWord
  end
  if type(edge.zone) == "string" and edge.zone ~= "" then
    return edge.zone
  end
  if node.kind == "zone" then
    return node.name
  end
  local meta, name = edge.meta, node.name
  if type(meta) == "string" and type(name) == "string" and meta:sub(1, #name + 2) == name .. ", " then
    return meta:sub(#name + 3)
  end
  return nil
end

-- Brief GS3: the words a guessed source (Core/GuessSources.lua) says about itself. The rate
-- column holds the tier's own word, never a figure: the model predicts no rates. The strength is
-- the model's Strong or Likely (its codes 1 and 2), and the why is the short name of the strategy
-- that led it, which the reader has already worded (edge.guess.whyWords). The lines are formats,
-- so a locale can put the word where its own grammar wants it.
local function strengthWord(code)
  if code == 1 then
    return L["Strong"]
  end
  if code == 2 then
    return L["Likely"]
  end
  return nil
end

-- The word the tier is called by: Core/GuessSources.lua's own, which loads after this file, so it
-- is read when a row asks, with the same locale key as the fallback.
local function guessLabel()
  local module = ItemTree.GuessSources
  local label = type(module) == "table" and module.LABEL or nil
  if type(label) == "string" and label ~= "" then
    return label
  end
  return L["Guess"]
end

--- What a guess edge's row says beyond its type and zone, or nil for an edge that is no guess:
--- { strength, strengthLine, why, whyLine, line }, each word translated. Pure over the edge.
function Sources.GuessFacts(edge)
  local guess = type(edge) == "table" and edge.guess or nil
  if type(guess) ~= "table" then
    return nil
  end
  local strength = strengthWord(guess.strength)
  local why = type(guess.whyWords) == "string" and guess.whyWords ~= "" and guess.whyWords or nil
  return {
    strength = strength,
    strengthLine = strength and string.format(L["Guess: %s"], strength) or nil,
    why = why,
    whyLine = why and string.format(L["Why: %s"], why) or nil,
    line = L["A guess from ItemTree's model, not seen in the game."],
  }
end

--- Brief B7: the tooltip line a live edge says about the Classic Era drop rate of the row it
--- shadowed (edge.eraRate, Graph.AdoptSourceFacts), or nil where it carries none. Pure.
function Sources.EraRateLine(edge)
  local percent = type(edge) == "table" and edge.eraRate or nil
  local text = Confidence.Chance(percent)
  if not text then
    return nil
  end
  return string.format(L["Classic Era drop rate: %s"], Confidence.Historical(text))
end

-- The source facts one up edge carries, or nil for an up edge that answers something other
-- than "where do I get this". edge is a Graph.Children edge, node the Graph.Node it points at,
-- and item the record of the item being sourced, which is where a vendor price is written.
--
-- seen is how many the collector has watched drop, not how many drop at once: the collector
-- adds up what it sees, so the number on a mob is a tally of sightings and is never drawn as a
-- quantity. A rate is only ever set where one is actually known, which is a percentage the
-- data states, a vendor price, or the skill a recipe needs.
function Sources.Source(edge, node, item)
  local typeName = edge and edge.type and edge.type.name or nil
  local column = typeName and Sources.TYPES[typeName] or nil
  if not column or not node then
    return nil
  end
  -- A gathering node's zone row says "Mined in" or "Gathered in" rather than "Gather".
  if column == "Gather" then
    column = placeType(edge.group) or column
  end
  -- Brief GS3: a guess states no figure of any kind, so a guessed vendor never borrows the
  -- item's own buy price the way a vendor that states none does.
  local guess = Sources.GuessFacts(edge)
  local price, bundle = nil, nil
  if column == "Vendor" and not guess then
    price, bundle = vendorPrice(edge, item)
  end
  -- Core/Collector.lua writes its tally as edge.seen, whatever the edge's confidence: a
  -- collected edge a curated note has since downgraded is still a tally of what this client
  -- watched. A store written before the tally had a name of its own put it in edge.quantity on
  -- a verified edge, so that is read too.
  local seen = edge.seen
  if seen == nil and edge.confidence == Confidence.VERIFIED then
    seen = edge.quantity
  end
  local rate, rateLabel
  if guess then
    rate = guessLabel()
  else
    rate, rateLabel = rateText(edge, node, column, item)
  end
  -- Brief BQ10 (owner ruling 2026-10-10): a live row combined with the Classic Era row it took the
  -- place of (Graph.AdoptSourceFacts) and stating no rate of its own draws that row's rate in the
  -- column, in the same "~77.1%" the plain Classic Era rows beside it draw. Only its tooltip says
  -- it is the Classic Era rate (eraRateLine below), so no rateLabel. A row with no Classic Era twin
  -- carries no eraRate and still draws no rate (ruling 2026-10-02).
  local eraRateInColumn = nil
  if rate == nil and not guess and edge.percent == nil then
    local borrowed = Sources.HistoricalRate(edge.eraRate)
    if borrowed then
      rate = borrowed
      eraRateInColumn = true
    end
  end
  -- The qualifier the row's own words end with, where the edge states one: a Classic Era source
  -- that only gives the item on a quest, a vendor's limited stock, the level band of the group a
  -- summary row stands for. Only Core/EraSources.lua sets it, so every other row is untouched.
  local note = nil
  if type(edge.note) == "string" and edge.note ~= "" then
    note = edge.note
  end
  local name = nil
  if note then
    -- Brief LF1 (QA item 248): "Strong Fishing Pole (limited stock 1)".
    name = Sources.Qualified(node.name, note)
  end
  return {
    type = column,
    typeLabel = L[column],
    zone = zoneText(edge, node),
    -- The words the row draws in place of the node's own name, where a qualifier changes them,
    -- and nil everywhere else: the node is still called what it is called, and the row says one
    -- more thing about this particular source of it.
    name = name,
    note = note,
    rate = rate,
    -- What kind of creature this row names, in words, and the band behind those words as plain
    -- numbers so the search box can answer a level typed into it. nil on every row the section
    -- that raised it says no kind for, which is every row but a Classic Era creature row.
    kind = Sources.KindText(edge.creature),
    levelLow = type(edge.creature) == "table" and tonumber(edge.creature.low) or nil,
    levelHigh = type(edge.creature) == "table" and tonumber(edge.creature.high) or nil,
    -- What the rate column's figure is called in full, where the column has no room to say it:
    -- "About 12.5% in Classic Era" behind a "~12.5%". nil wherever the column already says it
    -- all, which is every row but a historical one.
    rateLabel = rateLabel,
    -- Brief B7: the Classic Era drop rate of the row this live row took the place of
    -- (Graph.AdoptSourceFacts), for the row's tooltip: "Classic Era drop rate: ~49%". nil elsewhere.
    eraRateLine = Sources.EraRateLine(edge),
    -- Brief BQ10: true where the rate column above is that same Classic Era rate, so the tooltip
    -- says it once, on the line above. nil on every other row.
    eraRateInColumn = eraRateInColumn,
    price = price,
    -- Brief PS1 bundle prices: how many the price buys where the price says so ("25c for 5"), so
    -- the row can give the longer words room. nil for a bundle of 1 and on every other row.
    bundle = bundle,
    percent = edge.percent,
    -- Where the claim came from, for a row that wants to say so. provenance is the short
    -- stable key an adapter in Providers/ stamps on its edges ("att", "questie") and is what
    -- a filter or a count is keyed by; provenanceLabel is the words, translated. Both are nil
    -- on everything the addon ships and on everything the collector saw.
    provenance = edge.provenance,
    -- A guess names no provider and says where it came from on its own line (guessLine below).
    provenanceLabel = (not guess) and provenanceLabel(edge) or nil,
    -- True when the rate above is an imported Era figure on a client that is not Era, which is
    -- also why it reads "about 3%" rather than "3%".
    rateApproximate = approximate(edge),
    -- True for a row out of the shipped Classic Era table: the whole row is history, not only
    -- its rate, so the pane marks the row rather than hedging a number on it.
    historical = Sources.IsHistorical(edge.provenance),
    percentSource = edge.percentSource,
    tier = edge.confidence,
    -- What a predicted row's prediction is based on (Core/Confidence.lua BASIS_*), so the
    -- Predicted badge's own tooltip says which kind of prediction it is marking.
    basis = edge.basis,
    confidence = Confidence.Badge(edge.confidence),
    seen = seen,
    serverSide = Edges.IsServerSide(edge.type),
    -- Brief GS3: true for a source ItemTree's model guessed, with the words its row's tooltip
    -- says: "Guess: Likely", "Why: Item set mates" and the last line, which stands where a
    -- Classic Era row says its Classic Era line. nil on every real row.
    guess = guess and true or nil,
    guessStrength = guess and guess.strength or nil,
    guessStrengthLine = guess and guess.strengthLine or nil,
    guessWhy = guess and guess.why or nil,
    guessWhyLine = guess and guess.whyLine or nil,
    guessLine = guess and guess.line or nil,
  }
end

--------------------------------------------------------------------------------
-- Merchant's Favor vendors, shipped as community rows (brief M3)
--------------------------------------------------------------------------------

-- The curated tier's Favour block (Data/curated/Curated.lua ItemTree.Curated.favour), which
-- ItemTree-Data writes from its hand kept curated/favour_vendors.json: the vendors two community
-- pages agree on, the offers whose price matches a real ItemExtendedCost row in currency 3402,
-- and the Waylaid Crates. It is read here and joins the graph as one provider (Favour.EdgesFor,
-- installed at the foot of this file):
--
--   item:<id>  up    SOLD_BY     a shipped offer, one row per vendor, the player's side first
--   item:<id>  up    DROPPED_BY  a crate: "World drop", from ordinary creatures from level 10
--   npc:<id>   down  SELLS       a shipped vendor's own offers, for its page's Sells tab
--
-- Every edge is the curated tier, so it wears the Community note badge, and carries provenance
-- "community" with the pages it rests on in edge.community, which the row's hover names.
--
-- The merge with the collector (Favour.Matches). A shipped row and a record the player made at
-- that vendor window are one row, keyed by (item, npc id) where the file states an id, else by
-- (item, vendor name, zone words), else, for a vendor the file names by its role alone, by
-- (item, zone words). A matched shipped row is not emitted at all: the collector's verified row
-- stands in its place with its own id, cost, zone and position, and the badge drops to seen.
-- Where the record lacks a field the shipped row has (a record made before prices were read),
-- Core/Collector.lua fills it from Favour.ShippedOffer. A collected cost that differs from the
-- shipped one is shown as collected and counted by Favour.Compare for /itemtree debug.
local Favour = {}
Sources.Favour = Favour

local EMPTY_LIST = {}

Favour.CURRENCY = 3402
Favour.PROVENANCE = "community"
-- A shipped vendor the file states no npc id for is keyed npc:<NPC_BASE + its id in the file>.
-- Far above any creature id a build carries, and positive, so Core/EraSources.lua's own made up
-- (negative) nodes can never be one of these.
Favour.NPC_BASE = 900000000
-- The node a crate row points at: the shared world drop node (Core/EraSources.lua WORLD_ID), which
-- Core/Chain.lua already knows is no step in a chain.
Favour.WORLD_KEY = "npc:0"

Sources.PROVENANCE.community = "Community note"

-- "Community note: example.org 2026-09-26, example.net 2026-09-23": the pages a shipped row
-- rests on, by host and date, for the row's hover. nil for no page. Pure.
function Favour.CommunityText(sources)
  local parts = {}
  for _, source in ipairs(type(sources) == "table" and sources or EMPTY_LIST) do
    if type(source) == "table" and type(source.url) == "string" then
      local host = source.url:match("^%a+://([^/]+)") or source.url
      host = host:gsub("^www%.", "")
      if type(source.date) == "string" and source.date ~= "" then
        host = host .. " " .. source.date
      end
      parts[#parts + 1] = host
    end
  end
  if #parts == 0 then
    return nil
  end
  return string.format(L["Community note: %s"], table.concat(parts, ", "))
end

-- The Favour table the curated tier ships, or nil.
function Favour.Table()
  local curated = ItemTree.Curated
  local favour = type(curated) == "table" and curated.favour or nil
  if type(favour) ~= "table" then
    return nil
  end
  return favour
end

local function lower(text)
  if type(text) ~= "string" or text == "" then
    return nil
  end
  return text:lower()
end

-- The key a shipped vendor's node has before anything is known about it: its npc id where the
-- file states one, else its place in the file above NPC_BASE. Pure.
function Favour.StaticKey(vendor)
  if type(vendor) ~= "table" then
    return nil
  end
  if type(vendor.npc) == "number" then
    return "npc:" .. math.floor(vendor.npc)
  end
  if type(vendor.id) == "number" then
    return "npc:" .. math.floor(Favour.NPC_BASE + vendor.id)
  end
  return nil
end

-- What a row calls a shipped vendor: its name, or the words the file names a vendor by where it
-- names one by its role alone ("Supply Officer (west of the Crossroads)"). Pure.
function Favour.DisplayName(vendor)
  if type(vendor) ~= "table" then
    return nil
  end
  if type(vendor.name) == "string" and vendor.name ~= "" then
    return vendor.name
  end
  if type(vendor.label) == "string" and vendor.label ~= "" then
    return vendor.label
  end
  return nil
end

-- The lookups one Favour table answers, built once per table and kept against it, so the harness
-- swapping the table is answered from the new one. Pure over the table it is handed.
local indexFor, indexOf = nil, nil

function Favour.Index(favour)
  favour = favour or Favour.Table()
  if type(favour) ~= "table" then
    return nil
  end
  if indexFor == favour and indexOf then
    return indexOf
  end
  local index =
    { vendors = {}, list = {}, byNode = {}, byName = {}, offersByItem = {}, offersByVendor = {}, crates = {} }
  for _, vendor in ipairs(type(favour.vendors) == "table" and favour.vendors or EMPTY_LIST) do
    if type(vendor) == "table" and type(vendor.key) == "string" then
      index.vendors[vendor.key] = vendor
      index.list[#index.list + 1] = vendor
      local key = Favour.StaticKey(vendor)
      if key then
        index.byNode[key] = vendor
      end
      local name = lower(vendor.name)
      if name then
        index.byName[name] = vendor
      end
    end
  end
  for _, offer in ipairs(type(favour.offers) == "table" and favour.offers or EMPTY_LIST) do
    if type(offer) == "table" and type(offer.item) == "number" then
      local bucket = index.offersByItem[offer.item] or {}
      index.offersByItem[offer.item] = bucket
      bucket[#bucket + 1] = offer
      for _, vendorKey in ipairs(type(offer.vendors) == "table" and offer.vendors or EMPTY_LIST) do
        if index.vendors[vendorKey] then
          local held = index.offersByVendor[vendorKey] or {}
          index.offersByVendor[vendorKey] = held
          held[#held + 1] = offer
        end
      end
    end
  end
  local crates = type(favour.crates) == "table" and favour.crates or nil
  index.crate = crates
  for _, item in ipairs(crates and type(crates.items) == "table" and crates.items or EMPTY_LIST) do
    if type(item) == "number" then
      index.crates[item] = true
      index.firstCrate = index.firstCrate or item
    end
  end
  indexFor, indexOf = favour, index
  return index
end

-- Drops the kept index (a spec that edits the table in place).
function Favour.Reset()
  indexFor, indexOf = nil, nil
end

-- Whether one collected vendor record ({ sourceId, sourceName, zone }) is the player's own sighting
-- of a shipped vendor: the same npc id where the file states one, else the same name (any case)
-- in the same zone, else, for a vendor the file names by its role alone, the same zone. A record
-- with no zone matches a named vendor by its name. Pure.
function Favour.Matches(vendor, record)
  if type(vendor) ~= "table" or type(record) ~= "table" then
    return false
  end
  if type(vendor.npc) == "number" then
    return record.sourceId == vendor.npc
  end
  local zone = type(record.zone) == "string" and record.zone ~= "" and record.zone or nil
  local name = lower(vendor.name)
  if name then
    if lower(record.sourceName) ~= name then
      return false
    end
    return zone == nil or zone == vendor.zone
  end
  return zone ~= nil and zone == vendor.zone
end

-- The first of an item's collected vendor records that is the player's sighting of this vendor,
-- or nil. records is a list of records for one item. Pure.
function Favour.MatchRecord(vendor, records)
  for _, record in ipairs(type(records) == "table" and records or EMPTY_LIST) do
    if
      type(record) == "table"
      and (record.kind == nil or record.kind == "vendor")
      and Favour.Matches(vendor, record)
    then
      return record
    end
  end
  return nil
end

-- A list of shipped vendors in the order a page reads them: the player's own side first, and the
-- file's order inside each side. faction is "Alliance", "Horde" or nil (then the file's order).
-- A new list. Pure.
function Favour.OrderByFaction(vendors, faction)
  local own, other = {}, {}
  for _, vendor in ipairs(type(vendors) == "table" and vendors or EMPTY_LIST) do
    if faction and vendor.faction == faction then
      own[#own + 1] = vendor
    else
      other[#other + 1] = vendor
    end
  end
  for _, vendor in ipairs(other) do
    own[#own + 1] = vendor
  end
  return own
end

-- One offer's cost as an edge carries it: price in copper and the currency part. Pure.
local function offerCost(offer)
  local cost = nil
  if type(offer.currency) == "number" and type(offer.amount) == "number" and offer.amount > 0 then
    cost = { currency = { [offer.currency] = offer.amount } }
  end
  local copper = tonumber(offer.copper)
  if copper and copper <= 0 then
    copper = nil
  end
  return copper, cost
end

-- What the shipped row's community field carries: the pages, the side and whether it is the
-- player's own. Pure.
local function communityOf(row, vendor, faction)
  return {
    sources = row.sources,
    faction = vendor and vendor.faction or nil,
    own = (faction ~= nil and vendor ~= nil and vendor.faction == faction) or false,
  }
end

-- The Sold by edges an item's shipped offers stand for, one per vendor, the player's side first.
--
--   records   the item's collected vendor records (Core/Collector.lua C:VendorRecords), or nil
--   faction   the player's side, or nil
--   nodeKey   fn(vendor) -> the npc key the row points at (Favour.NodeKey), or nil for the static
--
-- An offer at a vendor the player has a matching record for is left out: the collector's row is
-- that row now. Pure over its arguments and the Favour table.
function Favour.OfferEdges(itemId, records, faction, nodeKey)
  local out = {}
  local index = Favour.Index()
  local offers = index and index.offersByItem[itemId] or nil
  if not offers then
    return out
  end
  for _, offer in ipairs(offers) do
    local vendors = {}
    for _, vendorKey in ipairs(type(offer.vendors) == "table" and offer.vendors or EMPTY_LIST) do
      local vendor = index.vendors[vendorKey]
      if vendor then
        vendors[#vendors + 1] = vendor
      end
    end
    for _, vendor in ipairs(Favour.OrderByFaction(vendors, faction)) do
      if not Favour.MatchRecord(vendor, records) then
        local target = (type(nodeKey) == "function" and nodeKey(vendor)) or Favour.StaticKey(vendor)
        local copper, cost = offerCost(offer)
        if target then
          out[#out + 1] = {
            type = Edges.Types.SOLD_BY,
            target = target,
            confidence = Confidence.CURATED,
            group = L["Sold by"],
            zone = vendor.zone,
            price = copper,
            cost = cost,
            note = type(vendor.faction) == "string" and L[vendor.faction] or nil,
            provenance = Favour.PROVENANCE,
            community = communityOf(offer, vendor, faction),
          }
        end
      end
    end
  end
  return out
end

-- The one row a crate has: a world drop, with the file's note on how it is used. Pure.
function Favour.CrateEdges(itemId)
  local index = Favour.Index()
  if not index or not index.crates[itemId] then
    return {}
  end
  local crate = index.crate
  return {
    {
      type = Edges.Types.DROPPED_BY,
      target = Favour.WORLD_KEY,
      confidence = Confidence.CURATED,
      group = L["World drop"],
      note = type(crate.note) == "string" and crate.note ~= "" and crate.note or nil,
      provenance = Favour.PROVENANCE,
      community = { sources = crate.sources },
    },
  }
end

-- The Sells edges a shipped vendor's page lists. The collector's own Sells rows for the same
-- items win in the graph's merge (verified over curated), so nothing is left out here. Pure.
function Favour.SellsEdges(vendor, faction)
  local out = {}
  local index = Favour.Index()
  if type(vendor) ~= "table" or not index then
    return out
  end
  for _, offer in ipairs(index.offersByVendor[vendor.key] or EMPTY_LIST) do
    local copper, cost = offerCost(offer)
    out[#out + 1] = {
      type = Edges.Types.SELLS,
      target = "item:" .. math.floor(offer.item),
      confidence = Confidence.CURATED,
      group = L["Sells"],
      zone = vendor.zone,
      price = copper,
      cost = cost,
      provenance = Favour.PROVENANCE,
      community = communityOf(offer, vendor, faction),
    }
  end
  return out
end

-- The shipped vendor an npc key stands for, or nil: the key the file gives it, else the same name
-- (any case), which is how a record under the vendor's real id and the shipped node are one page.
-- nameOf answers a key's name (Graph.Name by default).
function Favour.VendorFor(key, nameOf)
  local index = Favour.Index()
  if not index or type(key) ~= "string" then
    return nil
  end
  local held = index.byNode[key]
  if held then
    return held
  end
  if key:sub(1, 4) ~= "npc:" then
    return nil
  end
  local graph = ItemTree.Graph
  nameOf = nameOf or (type(graph) == "table" and graph.Name) or nil
  if type(nameOf) ~= "function" then
    return nil
  end
  local ok, name = pcall(nameOf, key)
  if ok then
    return index.byName[lower(name) or ""]
  end
  return nil
end

-- The shipped offer and vendor one collected vendor record is the player's sighting of, or nil.
-- What Core/Collector.lua fills a record's missing fields from and Favour.Compare counts. Pure.
function Favour.ShippedOffer(itemId, record)
  local index = Favour.Index()
  local offers = index and index.offersByItem[itemId] or nil
  if not offers or type(record) ~= "table" then
    return nil
  end
  for _, offer in ipairs(offers) do
    for _, vendorKey in ipairs(type(offer.vendors) == "table" and offer.vendors or EMPTY_LIST) do
      local vendor = index.vendors[vendorKey]
      if vendor and Favour.Matches(vendor, record) then
        return offer, vendor
      end
    end
  end
  return nil
end

-- The shipped offer's cost in the shape a record keeps one: { copper, currency = { [id] = n } }.
function Favour.OfferCost(offer)
  if type(offer) ~= "table" then
    return nil
  end
  local copper, cost = offerCost(offer)
  return { copper = copper, currency = cost and cost.currency or nil }
end

-- What the debug report says about the shipped rows against the player's records: how many
-- offer rows ship (one per offer and vendor), how many of those the player has seen for
-- themselves, and how many of the seen ones asked a different Favour amount than the file says.
-- records is the collector's store of records (any table of them). Ids and counts only. Pure.
function Favour.Compare(records)
  local out = { offers = 0, seen = 0, differ = 0 }
  local index = Favour.Index()
  if not index then
    return out
  end
  for _, offer in ipairs(Favour.Table().offers or EMPTY_LIST) do
    out.offers = out.offers + #(type(offer.vendors) == "table" and offer.vendors or EMPTY_LIST)
  end
  for _, record in pairs(type(records) == "table" and records or EMPTY_LIST) do
    if type(record) == "table" and record.kind == "vendor" then
      local offer = Favour.ShippedOffer(record.itemId, record)
      if offer then
        out.seen = out.seen + 1
        local cost = type(record.cost) == "table" and record.cost or nil
        local seenAmount = cost and type(cost.currency) == "table" and cost.currency[offer.currency] or nil
        if cost and seenAmount ~= offer.amount then
          out.differ = out.differ + 1
        end
      end
    end
  end
  return out
end

-- Everything a shipped vendor's page says about it, or nil for a key that is none. Pure over the
-- table and the name join.
function Favour.VendorFacts(key, nameOf)
  local vendor = Favour.VendorFor(key, nameOf)
  if not vendor then
    return nil
  end
  return {
    key = vendor.key,
    name = Favour.DisplayName(vendor),
    role = vendor.role,
    faction = vendor.faction,
    zone = vendor.zone,
    area = vendor.area,
    uiMap = vendor.uiMap,
    x = vendor.x,
    y = vendor.y,
    sources = vendor.sources,
    offers = #(Favour.Index().offersByVendor[vendor.key] or EMPTY_LIST),
  }
end

-- Where a vendor stands, as map pins: the player's own position when they opened its window
-- (collected, { map, x, y } in percent), which beats the file's, else the file's. Each is
-- { map, x, y, zone, name, seen } with seen true for the player's own. An empty list for none.
-- collected is Core/Collector.lua C:NpcFacts for the key, or nil. Pure.
function Favour.Positions(shipped, collected)
  local out = {}
  local pos = type(collected) == "table" and collected.pos or nil
  local name = (type(shipped) == "table" and shipped.name) or (type(collected) == "table" and collected.name) or nil
  if type(pos) == "table" and type(pos.map) == "number" and type(pos.x) == "number" and type(pos.y) == "number" then
    out[1] = {
      map = pos.map,
      x = pos.x,
      y = pos.y,
      zone = (type(collected.zone) == "string" and collected.zone)
        or (type(shipped) == "table" and shipped.zone)
        or nil,
      name = name,
      seen = true,
    }
    return out
  end
  if type(shipped) == "table" and type(shipped.uiMap) == "number" and type(shipped.x) == "number" then
    if type(shipped.y) == "number" then
      out[1] = { map = shipped.uiMap, x = shipped.x, y = shipped.y, zone = shipped.zone, name = name, seen = false }
    end
  end
  return out
end

-- The item a Favour item's page links to for where the currency comes from: the Waylaid Crate.
function Favour.CrateItem()
  local index = Favour.Index()
  return index and index.firstCrate or nil
end

-- Whether an item has a shipped Favour offer, and whether it is a crate.
function Favour.IsOffer(itemId)
  local index = Favour.Index()
  return index ~= nil and index.offersByItem[itemId] ~= nil
end

function Favour.IsCrate(itemId)
  local index = Favour.Index()
  return index ~= nil and index.crates[itemId] == true
end

-- The shipped vendors a crate is turned in to, the player's side first. Pure.
function Favour.CrateOfficers(faction)
  local index = Favour.Index()
  local out = {}
  local crate = index and index.crate or nil
  for _, vendorKey in ipairs(crate and type(crate.vendors) == "table" and crate.vendors or EMPTY_LIST) do
    local vendor = index.vendors[vendorKey]
    if vendor then
      out[#out + 1] = vendor
    end
  end
  return Favour.OrderByFaction(out, faction)
end

-- A shipped vendor's name for its own static key, for a node nothing else names. Registered with
-- the graph by Favour.Install; asked only where nothing else answered.
function Favour.Namer(key)
  local index = Favour.Index()
  local vendor = index and index.byNode[key] or nil
  return vendor and Favour.DisplayName(vendor) or nil
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- Currency names the client has answered, by id. One call per currency a session, and only a
-- name is kept: a currency the client would not name is asked again next time, which costs a
-- local table read, never a server query.
Sources.currencyNames = {}

-- A currency's name as the client spells it ("Merchant's Favor"), or nil. The retail shape,
-- C_CurrencyInfo.GetCurrencyInfo(id), answers a table with .name; an older client's
-- GetCurrencyInfo answers the name first. Each is tried under pcall.
function Sources.CurrencyName(currencyId)
  if type(currencyId) ~= "number" then
    return nil
  end
  local cached = Sources.currencyNames[currencyId]
  if cached then
    return cached
  end
  local name = nil
  local api = rawget(_G, "C_CurrencyInfo")
  if type(api) == "table" and type(api.GetCurrencyInfo) == "function" then
    local ok, info = pcall(api.GetCurrencyInfo, currencyId)
    if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
      name = info.name
    end
  end
  if not name then
    local legacy = rawget(_G, "GetCurrencyInfo")
    if type(legacy) == "function" then
      local ok, value = pcall(legacy, currencyId)
      if ok and type(value) == "string" and value ~= "" then
        name = value
      end
    end
  end
  if name then
    Sources.currencyNames[currencyId] = name
  end
  return name
end

-- The player's side, "Alliance" or "Horde", or nil. UnitFactionGroup("player") under pcall, asked
-- once a session: a side is kept once the client names one, and a client with no such call, or
-- one that raises, costs the order and nothing else. Favour.faction states it for a spec.
Favour.faction = nil
Favour.factionAsked = false

function Favour.PlayerFaction()
  -- Brief BQ14 follow up: the pretend side (Core/Demo.lua) while it is set.
  local demo = ItemTree.Demo
  if type(demo) == "table" and type(demo.FactionWord) == "function" then
    local ok, pretend = pcall(demo.FactionWord)
    if ok and pretend then
      return pretend
    end
  end
  if Favour.faction or Favour.factionAsked then
    return Favour.faction
  end
  local read = rawget(_G, "UnitFactionGroup")
  if type(read) ~= "function" then
    Favour.factionAsked = true
    return nil
  end
  local ok, side = pcall(read, "player")
  if ok and (side == "Alliance" or side == "Horde") then
    Favour.faction = side
    Favour.factionAsked = true
  end
  return Favour.faction
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

-- The npc key a shipped vendor's rows point at: its static key, or, for a vendor the file names
-- but gives no id, the id the player's own records hold for that name in that zone, so the
-- shipped rows and the collected ones lead to one page.
function Favour.NodeKey(vendor)
  if type(vendor) ~= "table" then
    return nil
  end
  if type(vendor.npc) ~= "number" and type(vendor.name) == "string" then
    local id = ask(collector(), "NpcIdByName", vendor.name, vendor.zone)
    if type(id) == "number" then
      return "npc:" .. math.floor(id)
    end
  end
  return Favour.StaticKey(vendor)
end

-- The provider: see the note over Favour at the top of this block. Nothing is asked of the
-- client but the player's side, once.
function Favour.EdgesFor(key, direction)
  if type(key) ~= "string" or not Favour.Table() then
    return EMPTY_LIST
  end
  local Graph = ItemTree.Graph
  local kind, id = Graph.Parse(key)
  if kind == "item" and direction == Edges.UP then
    local index = Favour.Index()
    if not index or (not index.offersByItem[id] and not index.crates[id]) then
      return EMPTY_LIST
    end
    local out = Favour.CrateEdges(id)
    local records = ask(collector(), "VendorRecords", id)
    for _, edge in ipairs(Favour.OfferEdges(id, records, Favour.PlayerFaction(), Favour.NodeKey)) do
      out[#out + 1] = edge
    end
    return out
  end
  if kind == "npc" and direction == Edges.DOWN and id ~= 0 then
    local vendor = Favour.VendorFor(key)
    if vendor then
      return Favour.SellsEdges(vendor, Favour.PlayerFaction())
    end
  end
  return EMPTY_LIST
end

-- Registers the provider and the namer with the graph. Safe to call twice.
function Favour.Install()
  local Graph = ItemTree.Graph
  if type(Graph) ~= "table" or type(Graph.RegisterProvider) ~= "function" then
    return false
  end
  if not Graph.HasProvider(Favour.EdgesFor) then
    Graph.RegisterProvider(Favour.EdgesFor)
  end
  if type(Graph.RegisterNamer) == "function" and not Graph.HasNamer(Favour.Namer) then
    Graph.RegisterNamer(Favour.Namer)
  end
  return true
end

Favour.Install()

return Sources
