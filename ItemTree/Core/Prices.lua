-- Auction prices from the auction addons the player has installed (brief K9), and the item's
-- vendor sell price (brief K19, brief K20a). Read only.
-- Loaded as: local _, ItemTree = ...
--
-- ItemTree never scans the auction house and never harvests a price. An installed auction addon
-- has done its own scan; this file asks that addon's own public API what it thinks one item is
-- worth, one item at a time, and remembers the answer. Nothing here writes to those addons and
-- nothing is sent anywhere.
--
-- Brief K20a: two prices, never one.
--   Prices.Auction  the auction addons only, asked in this order, each only when its global is
--                   there and each under pcall; the first positive answer wins:
--     Auctionator  Auctionator.API.v1.GetAuctionPriceByItemID("ItemTree", itemId), copper; where
--                  that answers nothing and the caller has a link,
--                  Auctionator.API.v1.GetAuctionPriceByItemLink("ItemTree", link)
--     Auctioneer   AucAdvanced.API.GetMarketValue(link), then
--                  AucAdvanced.API.GetAlgorithmValue("market", link) where it has one. Auctioneer
--                  wants a link, so a caller with none is asked as "item:<id>"
--     TSM          TSM_API.GetCustomPriceValue("DBMarket", "i:<id>"), then "DBMinBuyout"
--   Prices.Vendor   the item's vendor sell price per unit: the shipped item row's sp first (read
--                   only while ItemTree_Data is loaded, so a bag pass at login never pulls it in),
--                   so no client cache is needed; where the row has none, the client's
--                   (brief K19): C_Item.GetItemInfo where it exists, else GetItemInfo, its 11th
--                   return (sellPrice). Only an item the client already holds is read
--                   (C_Item.IsItemDataCachedByID, where the client has it, answering false means no
--                   read), so this never asks the server anything.
--   Prices.Value    kept for one release (design K20 section 2): "auction, else vendor", the one
--                   number K9 and K19 answered, with the addon's label or Prices.VENDOR as its
--                   source. The vendor price is asked only where no auction addon answered.
--
-- Brief K20a, VERIFY (design section 2: "shipped sp first, client sell price where the row has
-- none, VERIFY they agree on a few items"). Assumed on build 1.60.1.70170 that the shipped sp is
-- the client's own sell price. Captured three times (bible B1): this comment; prices_spec's
-- "the shipped and client sell prices agree" variant, where a fake client answers Linen Cloth 13c,
-- Copper Ore 5c and Light Leather 15c beside the shipped rows; and the probe: where the row
-- answered and the client says it already holds the item, the client's price is read too (never
-- a server query), compared, and /itemtree debug's Prices line counts "shipped and client agree on
-- 12 of 12 compared", up to Prices.AGREE_SAMPLE comparisons a session.
--
-- The cache: one answer per item per price for the session (a price or a remembered nothing),
-- asked again at most once a minute per item, so a bag redraw never re-asks every slot.
--
-- Prices.Auction, Prices.Vendor, Prices.Value, Prices.Sources and Prices.StatusLine are the
-- contract. Everything reads the client's globals at call time through rawget, so this file loads
-- under busted with no client.
local _, ItemTree = ...

local Prices = {}
ItemTree.Prices = Prices

-- The name every price call is made under, which Auctionator's API asks for.
Prices.CALLER = "ItemTree"

-- An item's answer is asked again after this many seconds.
Prices.REFRESH_SECONDS = 60

-- The sources in the order they are asked, with the global each one hangs off.
Prices.SOURCES = {
  { key = "auctionator", label = "Auctionator", global = "Auctionator" },
  { key = "auctioneer", label = "Auctioneer", global = "AucAdvanced" },
  { key = "tsm", label = "TSM", global = "TSM_API" },
}

-- Brief K19: the vendor sell price, asked last, always there. Prices.Value answers this name as
-- its source where no auction addon answered.
Prices.VENDOR = "vendor"
Prices.VENDOR_LABEL = "Vendor price"

-- Brief K20a: how many items a session compares the shipped sell price with the client's (the
-- VERIFY probe above). A comparison is one read of an item the client already holds.
Prices.AGREE_SAMPLE = 50

-- Pure helpers ----------------------------------------------------------------

-- A price as whole copper, or nil for anything that is not a positive number. Pure.
function Prices.Copper(value)
  local number = tonumber(value)
  if number == nil or number ~= number or number <= 0 or number == math.huge then
    return nil
  end
  return math.floor(number)
end

-- The link Auctioneer is asked with: the caller's own where it has one, else "item:<id>". Pure.
function Prices.LinkFor(itemId, link)
  if type(link) == "string" and link ~= "" then
    return link
  end
  local id = tonumber(itemId)
  if not id then
    return nil
  end
  return "item:" .. math.floor(id)
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

-- Prices.Value's answers, { copper, source, at } per item; brief K20a: Prices.Auction's and
-- Prices.Vendor's own, the same shape, beside it.
Prices.cache = {}
Prices.auctionCache = {}
Prices.vendorCache = {}
-- Per source: { asked = n, answered = n, raised = n }; the vendor's also counts shipped, the
-- answers the item rows gave.
Prices.counts = {}
-- Brief K20a: the shipped against client comparisons, { compared = n, agreed = n }.
Prices.agreement = { compared = 0, agreed = 0 }

function Prices.Reset()
  Prices.cache = {}
  Prices.auctionCache = {}
  Prices.vendorCache = {}
  Prices.sourceCache = {}
  Prices.counts = {}
  Prices.agreement = { compared = 0, agreed = 0 }
end

-- The time in seconds. Prices.now stands one in for a spec.
local function now()
  if type(Prices.now) == "function" then
    return tonumber(Prices.now()) or 0
  end
  local getTime = rawget(_G, "GetTime")
  if type(getTime) == "function" then
    local ok, value = pcall(getTime)
    if ok and tonumber(value) then
      return tonumber(value)
    end
  end
  local osLib = rawget(_G, "os")
  local clock = type(osLib) == "table" and osLib.time or nil
  if type(clock) == "function" then
    return clock()
  end
  return 0
end

-- One field of another addon's table, read under pcall in case a metatable raises.
local function field(object, key)
  if type(object) ~= "table" then
    return nil
  end
  local ok, value = pcall(function()
    return object[key]
  end)
  if ok then
    return value
  end
  return nil
end

local function countsFor(key)
  local held = Prices.counts[key]
  if not held then
    held = { asked = 0, answered = 0, raised = 0, shipped = 0 }
    Prices.counts[key] = held
  end
  return held
end

-- One call into another addon's API: the copper it answers, or nil. A raise is counted.
local function ask(counts, fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if not ok then
    counts.raised = counts.raised + 1
    return nil
  end
  return Prices.Copper(value)
end

-- Each source's reader: the copper it answers for one item, or nil.
local READERS = {}

function READERS.auctionator(addon, itemId, link, counts)
  local api = field(field(addon, "API"), "v1")
  if type(api) ~= "table" then
    return nil
  end
  local copper = ask(counts, field(api, "GetAuctionPriceByItemID"), Prices.CALLER, itemId)
  if copper == nil and type(link) == "string" and link ~= "" then
    copper = ask(counts, field(api, "GetAuctionPriceByItemLink"), Prices.CALLER, link)
  end
  return copper
end

function READERS.auctioneer(addon, itemId, link, counts)
  local api = field(addon, "API")
  if type(api) ~= "table" then
    return nil
  end
  local asked = Prices.LinkFor(itemId, link)
  if not asked then
    return nil
  end
  local copper = ask(counts, field(api, "GetMarketValue"), asked)
  if copper == nil then
    copper = ask(counts, field(api, "GetAlgorithmValue"), "market", asked)
  end
  return copper
end

function READERS.tsm(addon, itemId, _, counts)
  local getValue = field(addon, "GetCustomPriceValue")
  local itemString = "i:" .. math.floor(itemId)
  local copper = ask(counts, getValue, "DBMarket", itemString)
  if copper == nil then
    copper = ask(counts, getValue, "DBMinBuyout", itemString)
  end
  return copper
end

-- Brief K19: whether the client already holds the item. False only where
-- C_Item.IsItemDataCachedByID says so; a client without the call (or one that raises) is read
-- straight away, since GetItemInfo answers nil for an item it does not hold.
local function heldByClient(itemApi, itemId)
  if type(itemApi) ~= "table" then
    return true
  end
  local isCached = field(itemApi, "IsItemDataCachedByID")
  if type(isCached) ~= "function" then
    return true
  end
  local ok, cached = pcall(isCached, itemId)
  if ok and cached == false then
    return false
  end
  return true
end

-- The 11th return of one GetItemInfo call (sellPrice), in copper, or nil, and whether the call
-- was there to make. A raise is counted.
local function sellPriceFrom(fn, itemId, counts)
  if type(fn) ~= "function" then
    return nil, false
  end
  local ok, _, _, _, _, _, _, _, _, _, _, sellPrice = pcall(fn, itemId)
  if not ok then
    counts.raised = counts.raised + 1
    return nil, true
  end
  return Prices.Copper(sellPrice), true
end

-- Brief K20a: whether the client says outright that it holds the item: true only where
-- C_Item.IsItemDataCachedByID answers true. The comparison probe reads only such an item.
local function surelyHeld(itemApi, itemId)
  local isCached = field(itemApi, "IsItemDataCachedByID")
  if type(isCached) ~= "function" then
    return false
  end
  local ok, cached = pcall(isCached, itemId)
  return ok and cached == true
end

-- Brief K19: the item's vendor sell price per unit from the client, for the one item the caller
-- asked about. The modern call first, the global where there is no modern one. Never a server
-- query.
function READERS.vendor(itemId, counts)
  local itemApi = rawget(_G, "C_Item")
  if not heldByClient(itemApi, itemId) then
    return nil
  end
  local copper, asked = sellPriceFrom(field(itemApi, "GetItemInfo"), itemId, counts)
  if asked then
    return copper
  end
  return (sellPriceFrom(rawget(_G, "GetItemInfo"), itemId, counts))
end

-- Brief K20a: the shipped item row's sell price (sp) in copper, or nil where the row has none or
-- ItemTree_Data is not loaded (a read never loads it). Pure over ItemTree.Data.
function Prices.ShippedSellPrice(itemId)
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.GetItem) ~= "function" then
    return nil
  end
  if type(data.OnDemandLoaded) == "function" then
    local ok, loaded = pcall(data.OnDemandLoaded, data)
    if not ok or loaded ~= true then
      return nil
    end
  end
  local ok, row = pcall(data.GetItem, data, itemId)
  if not ok or type(row) ~= "table" then
    return nil
  end
  return Prices.Copper(row.sp)
end

-- Brief K20a: the VERIFY probe. Where the row answered and the client surely holds the item, the
-- client's own price is read and compared, up to Prices.AGREE_SAMPLE items a session.
local function compareWithClient(itemId, shipped)
  local agreement = Prices.agreement
  if agreement.compared >= Prices.AGREE_SAMPLE then
    return
  end
  local itemApi = rawget(_G, "C_Item")
  if not surelyHeld(itemApi, itemId) then
    return
  end
  local scratch = { asked = 0, answered = 0, raised = 0 }
  local client, asked = sellPriceFrom(field(itemApi, "GetItemInfo"), itemId, scratch)
  if not asked then
    client = sellPriceFrom(rawget(_G, "GetItemInfo"), itemId, scratch)
  end
  if client == nil then
    return
  end
  agreement.compared = agreement.compared + 1
  if client == shipped then
    agreement.agreed = agreement.agreed + 1
  end
end

-- Asks the auction addons in order for one item. Answers copper and the addon's label, or nil.
local function lookupAuction(itemId, link)
  for _, source in ipairs(Prices.SOURCES) do
    local addon = rawget(_G, source.global)
    if type(addon) == "table" then
      local counts = countsFor(source.key)
      counts.asked = counts.asked + 1
      local copper = READERS[source.key](addon, itemId, link, counts)
      if copper then
        counts.answered = counts.answered + 1
        return copper, source.label
      end
    end
  end
  return nil
end

-- The vendor sell price for one item: the shipped row first, then the client. Counted.
local function lookupVendor(itemId)
  local counts = countsFor(Prices.VENDOR)
  counts.asked = counts.asked + 1
  local shipped = Prices.ShippedSellPrice(itemId)
  if shipped then
    counts.answered = counts.answered + 1
    counts.shipped = counts.shipped + 1
    compareWithClient(itemId, shipped)
    return shipped
  end
  local copper = READERS.vendor(itemId, counts)
  if copper then
    counts.answered = counts.answered + 1
    return copper
  end
  return nil
end

-- A whole positive item id, or nil.
local function idOf(itemId)
  local id = tonumber(itemId)
  if not id or id <= 0 then
    return nil
  end
  return math.floor(id)
end

-- Brief K20a: the auction price of one item, copper and the addon's label, or nil where no
-- installed auction addon has one. Cached per item, asked again at most once every
-- REFRESH_SECONDS.
function Prices.Auction(itemId, itemLink)
  local id = idOf(itemId)
  if not id then
    return nil
  end
  local held = Prices.auctionCache[id]
  local at = now()
  if held and at - held.at < Prices.REFRESH_SECONDS then
    return held.copper, held.source
  end
  local copper, source = lookupAuction(id, itemLink)
  Prices.auctionCache[id] = { copper = copper, source = source, at = at }
  return copper, source
end

-- Brief K20a: the vendor sell price of one item per unit in copper, or nil. The shipped row's
-- first, the client's where the row has none. Cached like Prices.Auction.
function Prices.Vendor(itemId)
  local id = idOf(itemId)
  if not id then
    return nil
  end
  local held = Prices.vendorCache[id]
  local at = now()
  if held and at - held.at < Prices.REFRESH_SECONDS then
    return held.copper
  end
  local copper = lookupVendor(id)
  Prices.vendorCache[id] = { copper = copper, source = Prices.VENDOR, at = at }
  return copper
end

-- Brief K20c: the price formula's per source names (Core/PriceFormula.lua), each to the one
-- source it reads: Auctionator's price, Auctioneer's market value, TSM's DBMarket or its
-- DBMinBuyout, nothing from the others.
Prices.FORMULA_SOURCES = {
  auctionator = { source = "auctionator" },
  auctioneer = { source = "auctioneer" },
  dbmarket = { source = "tsm", price = "DBMarket" },
  dbminbuyout = { source = "tsm", price = "DBMinBuyout" },
}
Prices.sourceCache = {}

-- Brief K20c: one item's price from one named source of the formula, in copper, or nil where that
-- addon is not installed or has none. Cached per name and item for REFRESH_SECONDS, like every
-- other price; never a client item query.
function Prices.FromSource(name, itemId)
  local wanted = Prices.FORMULA_SOURCES[name]
  local id = idOf(itemId)
  if not wanted or not id then
    return nil
  end
  local key = name .. ":" .. id
  local held = Prices.sourceCache[key]
  local at = now()
  if held and at - held.at < Prices.REFRESH_SECONDS then
    return held.copper
  end
  local copper
  for _, source in ipairs(Prices.SOURCES) do
    if source.key == wanted.source then
      local addon = rawget(_G, source.global)
      if type(addon) == "table" then
        local counts = countsFor(source.key)
        if wanted.price then
          copper = ask(counts, field(addon, "GetCustomPriceValue"), wanted.price, "i:" .. id)
        else
          copper = READERS[source.key](addon, id, nil, counts)
        end
      end
    end
  end
  Prices.sourceCache[key] = { copper = copper, at = at }
  return copper
end

-- The value of one item: copper and the name of the addon whose scan it came from, or
-- Prices.VENDOR ("vendor") for the item's vendor sell price where no installed auction addon has
-- a price, or nil where neither has one. Cached per item, asked again at most once every
-- REFRESH_SECONDS. Brief K20a: kept for one release as "auction, else vendor".
function Prices.Value(itemId, itemLink)
  local id = idOf(itemId)
  if not id then
    return nil
  end
  local held = Prices.cache[id]
  local at = now()
  if held and at - held.at < Prices.REFRESH_SECONDS then
    return held.copper, held.source
  end
  local copper, source = Prices.Auction(id, itemLink)
  if copper == nil then
    copper = Prices.Vendor(id)
    source = copper and Prices.VENDOR or nil
  end
  Prices.cache[id] = { copper = copper, source = source, at = at }
  return copper, source
end

-- Which auction addons are installed and which have answered, in the asking order, then the
-- vendor sell price (always installed): { { key, label, installed, asked, answered, raised } }.
function Prices.Sources()
  local out = {}
  for _, source in ipairs(Prices.SOURCES) do
    local counts = Prices.counts[source.key] or { asked = 0, answered = 0, raised = 0 }
    out[#out + 1] = {
      key = source.key,
      label = source.label,
      installed = type(rawget(_G, source.global)) == "table",
      asked = counts.asked,
      answered = counts.answered,
      raised = counts.raised,
    }
  end
  local vendor = Prices.counts[Prices.VENDOR] or { asked = 0, answered = 0, raised = 0 }
  out[#out + 1] = {
    key = Prices.VENDOR,
    label = Prices.VENDOR_LABEL,
    installed = true,
    asked = vendor.asked,
    answered = vendor.answered,
    raised = vendor.raised,
  }
  return out
end

-- The /itemtree debug line: "Prices: Auctionator installed, 41 of 58 asked answered;
-- Auctioneer absent; TSM absent; vendor price answered 12 of 17 asked". Counts only, no item.
function Prices.StatusLine()
  local parts = {}
  for _, source in ipairs(Prices.Sources()) do
    if source.key == Prices.VENDOR then
      local text = string.format("vendor price answered %d of %d asked", source.answered, source.asked)
      -- Brief K20a: how many the item rows answered, and the shipped against client probe.
      local vendorCounts = Prices.counts[Prices.VENDOR]
      local shipped = type(vendorCounts) == "table" and tonumber(vendorCounts.shipped) or 0
      if shipped > 0 then
        text = text .. string.format(", %d from the item rows", shipped)
      end
      if source.raised > 0 then
        text = text .. string.format(", %d raised", source.raised)
      end
      local agreement = Prices.agreement
      if agreement.compared > 0 then
        text = text
          .. string.format(", shipped and client agree on %d of %d compared", agreement.agreed, agreement.compared)
      end
      parts[#parts + 1] = text
    elseif source.installed then
      local text = string.format("%s installed, %d of %d asked answered", source.label, source.answered, source.asked)
      if source.raised > 0 then
        text = text .. string.format(", %d raised", source.raised)
      end
      parts[#parts + 1] = text
    else
      parts[#parts + 1] = source.label .. " absent"
    end
  end
  return "Prices: " .. table.concat(parts, "; ")
end

return Prices
