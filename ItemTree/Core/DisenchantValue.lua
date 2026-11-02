-- The expected disenchant value of an item (design K20e groundwork, brief K20-facts): the shipped
-- band an item disenchants by, the sum over its results of chance x the mean count x the
-- material's price, and the player's Enchanting rank.
-- Loaded as: local _, ItemTree = ...
--
-- The bands are the generated Disenchant module's (ItemTree_Data, build 1.60.1.70170, marked
-- predicted, "probabilities are rough"): a quality and an item level range, each result
-- { material id, chance, min count, max count }, weapons and armour (classes 2 and 4) only. The
-- module holds no skill requirement, no weapon versus armour split and nothing Forever specific
-- (docs/keep-sell.md), so every value here is "about".
--
-- The contract (brief K20-wire wires it into Core/Keep.lua: Keep (disenchant) and Disenchant
-- (Sell AH)):
--   DisenchantValue.Band(row, module)        the band covering a shipped row, or nil
--   DisenchantValue.Expected(band, priceOf, module)
--       { copper = n (whole, rounded down), about = true,
--         results = { { id, chance, count (the mean of min and max), price or nil, copper,
--                       name } ... } in the band's order,
--         missing = { { id, name } ... } (the materials priceOf had no price for, counted as 0),
--         likely = { id, chance, name } (the most likely result, the first of a tie) }
--       or nil for no band. priceOf(materialId) answers copper per unit or nil.
--   DisenchantValue.LikelyWords(expected)    "25% Large Glimmering Shard" or nil
--   DisenchantValue.RequiredRank(row)        the Enchanting rank the row needs, a STAND-IN table
--                                            by quality and item level (brief K20-wire)
--   DisenchantValue.CanDisenchant(row, rank) whether that rank reaches it
-- Client side, guarded:
--   DisenchantValue.EnchantingRank()         the player's Enchanting rank or nil, kept until
--                                            SKILL_LINES_CHANGED
--   DisenchantValue.MaterialPrice(id)        copper and source through Prices.Auction (brief
--                                            K20-wire; Prices.Value before), cached per
--                                            material for 60 seconds
--   DisenchantValue.ForItem(row)             Expected over Band(row) and MaterialPrice
local _, ItemTree = ...

local DisenchantValue = {}
ItemTree.DisenchantValue = DisenchantValue

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

-- The item classes that disenchant: weapons and armour.
DisenchantValue.CLASSES = { [2] = true, [4] = true }
-- The qualities a band can cover: uncommon, rare, epic.
DisenchantValue.MIN_QUALITY = 2
DisenchantValue.MAX_QUALITY = 4

-- Enchanting's skill line id.
DisenchantValue.ENCHANTING_SKILL_LINE = 333

-- A material's price is asked again after this many seconds.
DisenchantValue.REFRESH_SECONDS = 60

-- Brief K20-wire: the Enchanting rank an item needs before it can be disenchanted. A STAND-IN: the
-- shipped Disenchant module holds no skill requirement (docs/keep-sell.md), so until the pipeline
-- ships the real one this is the Classic rule of thumb by the item's level. Uncommon items: item
-- level 1 to 20 rank 1, 21 to 25 rank 25, then 25 more for every five levels to 61 to 65 rank 225,
-- and 66 or more rank 250 (the steps below, each { highest item level, rank }). Rare items need 25
-- more than an uncommon of the same level; epic items 300. The owner confirms (brief K20-wire).
DisenchantValue.RANK_STEPS = {
  { 20, 1 },
  { 25, 25 },
  { 30, 50 },
  { 35, 75 },
  { 40, 100 },
  { 45, 125 },
  { 50, 150 },
  { 55, 175 },
  { 60, 200 },
  { 65, 225 },
}
DisenchantValue.RANK_TOP = 250
DisenchantValue.RARE_EXTRA = 25
DisenchantValue.EPIC_RANK = 300

-- Pure helpers ----------------------------------------------------------------

local function number(value)
  local n = tonumber(value)
  if n == nil or n ~= n then
    return nil
  end
  return n
end

-- The shipped Disenchant module, or nil where ItemTree_Data is not there. Reads the data layer only.
function DisenchantValue.Module()
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.GetDisenchant) ~= "function" then
    return nil
  end
  local ok, module = pcall(data.GetDisenchant, data)
  if ok and type(module) == "table" then
    return module
  end
  return nil
end

-- Whether the module lets an item class disenchant: one of 2 and 4, and in the module's own list
-- where it ships one.
local function classAllowed(module, itemClass)
  if not DisenchantValue.CLASSES[itemClass or -1] then
    return false
  end
  if type(module.classes) ~= "table" then
    return true
  end
  for _, class in ipairs(module.classes) do
    if class == itemClass then
      return true
    end
  end
  return false
end

-- The band that covers a shipped row (its c class, q quality and il item level), the module's
-- own table (read it, never change it), or nil: not a weapon or armour, a quality outside 2 to 4,
-- no item level, or no band covering it. module defaults to the shipped one. Pure over the data.
function DisenchantValue.Band(row, module)
  if type(row) ~= "table" then
    return nil
  end
  module = module or DisenchantValue.Module()
  if type(module) ~= "table" or type(module.bands) ~= "table" then
    return nil
  end
  if not classAllowed(module, number(row.c)) then
    return nil
  end
  local quality, level = number(row.q), number(row.il)
  if not quality or quality < DisenchantValue.MIN_QUALITY or quality > DisenchantValue.MAX_QUALITY then
    return nil
  end
  if not level or level <= 0 then
    return nil
  end
  for _, band in ipairs(module.bands) do
    if type(band) == "table" and band.q == quality and level >= (band.min or 0) and level <= (band.max or -1) then
      return band
    end
  end
  return nil
end

-- A material's name from the module's materials list, or "item <id>" where it names none.
function DisenchantValue.MaterialName(materialId, module)
  module = module or DisenchantValue.Module()
  local names = type(module) == "table" and module.materials or nil
  local name = type(names) == "table" and names[materialId] or nil
  if type(name) == "string" and name ~= "" then
    return name
  end
  return "item " .. tostring(materialId)
end

-- The expected value of disenchanting one item of a band: see the contract above. A material
-- priceOf has no price for (nil, not a positive number, or a raise) counts as 0 and is named in
-- missing. Pure over the band, the price function and the names.
function DisenchantValue.Expected(band, priceOf, module)
  if type(band) ~= "table" or type(band.out) ~= "table" or #band.out == 0 then
    return nil
  end
  local out = { copper = 0, about = true, results = {}, missing = {}, likely = nil }
  local total = 0
  for _, result in ipairs(band.out) do
    local id, chance = number(result[1]), number(result[2]) or 0
    if id then
      local low = number(result[3]) or 1
      local high = number(result[4]) or low
      local count = (low + high) / 2
      local price = nil
      if type(priceOf) == "function" then
        local ok, answer = pcall(priceOf, id)
        answer = ok and number(answer) or nil
        if answer and answer > 0 then
          price = answer
        end
      end
      local name = DisenchantValue.MaterialName(id, module)
      local copper = price and chance * count * price or 0
      total = total + copper
      out.results[#out.results + 1] =
        { id = id, chance = chance, count = count, price = price, copper = copper, name = name }
      if not price then
        out.missing[#out.missing + 1] = { id = id, name = name }
      end
      if out.likely == nil or chance > out.likely.chance then
        out.likely = { id = id, chance = chance, name = name }
      end
    end
  end
  out.copper = math.floor(total + 1e-6)
  return out
end

-- A chance as a percent: "25", "99.5". Pure.
function DisenchantValue.Percent(chance)
  local percent = (number(chance) or 0) * 100
  local rounded = math.floor(percent + 0.5)
  if math.abs(percent - rounded) < 1e-6 then
    return tostring(rounded)
  end
  return string.format("%.1f", percent)
end

-- "25% Large Glimmering Shard", the most likely result, or nil. Pure.
function DisenchantValue.LikelyWords(expected)
  local likely = type(expected) == "table" and expected.likely or nil
  if type(likely) ~= "table" then
    return nil
  end
  return string.format(L["%s%% %s"], DisenchantValue.Percent(likely.chance), likely.name)
end

-- Brief K20-wire: the Enchanting rank a shipped row needs to be disenchanted, by the stand-in table
-- above (its q quality and il item level), or nil for an item that is not uncommon, rare or epic or
-- has no item level. Pure.
function DisenchantValue.RequiredRank(row)
  if type(row) ~= "table" then
    return nil
  end
  local quality, level = number(row.q), number(row.il)
  if not quality or quality < DisenchantValue.MIN_QUALITY or quality > DisenchantValue.MAX_QUALITY then
    return nil
  end
  if not level or level <= 0 then
    return nil
  end
  if quality == DisenchantValue.MAX_QUALITY then
    return DisenchantValue.EPIC_RANK
  end
  local rank = DisenchantValue.RANK_TOP
  for _, step in ipairs(DisenchantValue.RANK_STEPS) do
    if level <= step[1] then
      rank = step[2]
      break
    end
  end
  if quality == DisenchantValue.MIN_QUALITY + 1 then
    rank = rank + DisenchantValue.RARE_EXTRA
  end
  return rank
end

-- Brief K20-wire: whether a player of an Enchanting rank (nil: no Enchanting) can disenchant a
-- shipped row by the stand-in table. Pure.
function DisenchantValue.CanDisenchant(row, rank)
  rank = number(rank)
  if not rank then
    return false
  end
  local needed = DisenchantValue.RequiredRank(row)
  return needed ~= nil and rank >= needed
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

-- The Enchanting rank, read once and kept until SKILL_LINES_CHANGED (rankRead false).
DisenchantValue.rank = nil
DisenchantValue.rankRead = false
-- One material price per id: { copper, source, at }.
DisenchantValue.prices = {}

function DisenchantValue.Reset()
  DisenchantValue.rank = nil
  DisenchantValue.rankRead = false
  DisenchantValue.prices = {}
end

-- The time in seconds. DisenchantValue.now stands one in for a spec.
local function now()
  if type(DisenchantValue.now) == "function" then
    return number(DisenchantValue.now()) or 0
  end
  local getTime = rawget(_G, "GetTime")
  if type(getTime) == "function" then
    local ok, value = pcall(getTime)
    if ok and number(value) then
      return number(value)
    end
  end
  return 0
end

-- Brief K20-wire: the time the material prices are held against, for Core/Keep.lua's refresh of a
-- held score's disenchant value.
function DisenchantValue.Now()
  return now()
end

-- Every answer of a call, nils included, with n the count.
local function packed(...)
  return { n = select("#", ...), ... }
end

-- Client assumption (bible B1), read on the forever branch of the UI source mirror at 1.60.1.70205
-- (Blizzard_ProfessionsBook/Camelot/Blizzard_ProfessionsBook.lua): GetProfessions() answers the
-- indices prof1, prof2, first aid, fishing, cooking (any nil), and GetProfessionInfo(index)
-- answers name, texture, rank, maxRank, numSpells, spellOffset, skillLine, ...: the rank third,
-- the skill line seventh. Enchanting is skill line 333. Fake variants: tests/spec/
-- disenchant_value_spec.lua "forever 1.60.1.70205" (an enchanter), "no Enchanting" and "classic
-- shape". Probe: /itprobe disenchant prints the rank this reads, beside what C_SkillInfo answers.
--
-- The classic shape (GetNumSkillLines and GetSkillLineInfo with no GetProfessions, Classic Era)
-- answers nil here on purpose: Forever is the client ItemTree is listed for and it has the modern
-- shape, and the skill sheet's lines are matched by name, which this does not do.
function DisenchantValue.ReadEnchantingRank()
  local getProfessions = rawget(_G, "GetProfessions")
  local getInfo = rawget(_G, "GetProfessionInfo")
  if type(getProfessions) ~= "function" or type(getInfo) ~= "function" then
    return nil
  end
  local answer = packed(pcall(getProfessions))
  if not answer[1] then
    return nil
  end
  for index = 2, answer.n do
    local slot = answer[index]
    if type(slot) == "number" then
      local ok, _, _, rank, _, _, _, skillLine = pcall(getInfo, slot)
      if ok and number(skillLine) == DisenchantValue.ENCHANTING_SKILL_LINE then
        return number(rank)
      end
    end
  end
  return nil
end

-- Brief K24d: the developer's pretend professions (UI/PlayerSkills.lua, /itemtree demo
-- professions), while they are on: the pretend Enchanting rank, or nil where the pretend set has
-- no Enchanting (the set replaces the player's own professions). Answers on, rank; on false while
-- the demo is off. Reads ItemTree's own tables only.
function DisenchantValue.DemoRank()
  local ui = ItemTree.UI
  local skills = type(ui) == "table" and ui.PlayerSkills or nil
  if type(skills) ~= "table" or type(skills.DemoOn) ~= "function" or type(skills.DemoSkills) ~= "function" then
    return false, nil
  end
  local okOn, on = pcall(skills.DemoOn)
  if not okOn or not on then
    return false, nil
  end
  local ok, pretendSkills = pcall(skills.DemoSkills)
  local entry = ok and type(pretendSkills) == "table" and pretendSkills[DisenchantValue.ENCHANTING_SKILL_LINE] or nil
  return true, type(entry) == "table" and number(entry.rank) or nil
end

-- The player's Enchanting rank, or nil for no Enchanting (or a client that will not say). Read
-- once and kept until SKILL_LINES_CHANGED or DisenchantValue.Reset. Brief K24d: the pretend
-- professions answer first while they are on (DisenchantValue.DemoRank), never held.
function DisenchantValue.EnchantingRank()
  local pretend, pretendRank = DisenchantValue.DemoRank()
  if pretend then
    return pretendRank
  end
  if DisenchantValue.rankRead then
    return DisenchantValue.rank
  end
  DisenchantValue.rank = DisenchantValue.ReadEnchantingRank()
  DisenchantValue.rankRead = true
  return DisenchantValue.rank
end

-- Brief K24d: drops the held Enchanting rank, so the next read asks again (the pretend
-- professions changed, UI/PlayerSkills.lua PlayerSkills.ApplyDemo).
function DisenchantValue.ForgetRank()
  DisenchantValue.rank = nil
  DisenchantValue.rankRead = false
end

-- Brief K24d: the owner's session only pretend price of every disenchant material, copper per
-- unit (/itemtree demo disenchant, set through Core/Keep.lua Keep.SetDemo), nil while off. Memory
-- only. Setting it drops the held material prices.
DisenchantValue.demoPrice = nil

function DisenchantValue.SetDemoPrice(copper)
  copper = number(copper)
  if copper ~= nil then
    copper = math.floor(copper)
  end
  DisenchantValue.demoPrice = copper
  DisenchantValue.prices = {}
  return copper
end

-- One material's price per unit in copper and the name of its source, cached per material for
-- REFRESH_SECONDS, nil where there is none. Brief K20-wire (design K20 section 2): through
-- Prices.Auction, the installed auction addons' own prices only, never the vendor sell price, so a
-- material no auction addon prices counts as 0 and is named ("no price for Soul Dust"). Brief
-- K24d: the pretend price, source "demo", while it is set.
function DisenchantValue.MaterialPrice(materialId)
  local id = number(materialId)
  if not id or id <= 0 then
    return nil
  end
  if number(DisenchantValue.demoPrice) then
    return number(DisenchantValue.demoPrice), "demo"
  end
  local held = DisenchantValue.prices[id]
  local at = now()
  if held and at - held.at < DisenchantValue.REFRESH_SECONDS then
    return held.copper, held.source
  end
  local prices = ItemTree.Prices
  local copper, source = nil, nil
  if type(prices) == "table" and type(prices.Auction) == "function" then
    local ok, value, from = pcall(prices.Auction, id)
    if ok then
      copper, source = number(value), from
    end
  end
  DisenchantValue.prices[id] = { copper = copper, source = source, at = at }
  return copper, source
end

-- The expected value of one shipped row with the material prices of now, or nil for no band.
function DisenchantValue.ForItem(row)
  local module = DisenchantValue.Module()
  return DisenchantValue.Expected(DisenchantValue.Band(row, module), DisenchantValue.MaterialPrice, module)
end

-- What the event frame does: SKILL_LINES_CHANGED drops the held rank. Answers whether it did.
function DisenchantValue.OnEvent(event)
  if event == "SKILL_LINES_CHANGED" then
    DisenchantValue.rank = nil
    DisenchantValue.rankRead = false
    return true
  end
  return false
end

-- The event frame, ItemTree's own and unparented, made once where the client can make one.
function DisenchantValue.Install()
  if DisenchantValue.frame then
    return DisenchantValue.frame
  end
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, "Frame")
  if not ok or type(frame) ~= "table" or type(frame.RegisterEvent) ~= "function" then
    return nil
  end
  pcall(frame.RegisterEvent, frame, "SKILL_LINES_CHANGED")
  pcall(frame.SetScript, frame, "OnEvent", function(_, event)
    DisenchantValue.OnEvent(event)
  end)
  DisenchantValue.frame = frame
  return frame
end

DisenchantValue.Install()

return DisenchantValue
