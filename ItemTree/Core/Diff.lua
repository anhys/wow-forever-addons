-- Queries over the generated Diff module: what is new, changed, removed or renumbered in
-- this build compared with the baseline. Pure Lua, no WoW API.
--
-- The generated shape is <kind>.new = {ids}, <kind>.changed[id] = { {field, old, new} },
-- <kind>.removed[id] = summary, <kind>.renumbered[oldId] = newId, items.hidden = {ids} for
-- items the build still lists but states nothing about, items.discovered = {ids} for items the
-- baseline listed and would not name and this build does, items.newUndiscovered = {ids} for items
-- this build lists and will not name that the baseline could not name either, and items.sod =
-- {ids} for the new items that came from Season of Discovery. New means the baseline could not
-- name the id, so discovered is inside new and every sod id is in new or newUndiscovered.
--
-- Since brief D3 the pipeline also folds in the Discovery Miner's harvest: items.harvested =
-- { [id] = tag } for the withheld ids a harvest named (tag "miner" is the Discovery Miner), which
-- ship as ordinary items and sit in discovered, items.discoveredAt = { [id] = unixSeconds } for
-- when each was first found, and a fourth element on a changed row the harvest produced,
-- {field, old, new, "miner"}. A harvested id the baseline named is a Classic item, so it is the
-- one discovered id that is not new. The setting "Show items found on the beta" (showHarvested)
-- can hide every harvested id again, which Data:HarvestMasked answers and this file honours.
--
-- Brief U3: the pipeline ships that table as two modules. Diff holds the sets, with changed as
-- { [id] = true }, and ships in ItemTree, so a badge costs nothing at login. DiffChanges holds
-- the detail, <kind>.changed[id] = { {field, old, new} }, removed and renumbered, and ships in the
-- load on demand ItemTree_Data, so the first hover of a Changed badge loads it. A Diff module in
-- the older single shape (changed rows, removed and renumbered in place, as the specs' fakes are)
-- is read exactly as before: rows found in Diff win, and DiffChanges is only asked for what Diff
-- does not carry.
-- Brief C1: a change to an item's class, subclass or stack size is minor, nearly always a renamed
-- category. Diff's <kind>.changed holds only the ids with at least one major change, and
-- <kind>.changedMinor, the same shape, the ids whose every change is minor; an id is in one or the
-- other. DiffChanges keeps every row and marks a minor one with true as a fifth element, the fourth
-- (the harvest's tag) nil where no harvest produced it: {field, old, new, nil, true}. The account
-- wide setting "Include minor changes" (includeMinorChanges, off by default) decides whether the
-- minor set counts as Changed and whether minor rows are listed: Diff.IncludeMinor is the one
-- answer, and IsChanged, GetChanges and Counts follow it, so every badge, hover and list does.
-- Everything here reads that table and turns it into text the UI can draw. Change language is always
-- "old to new", never arrows (see design: content fundamentals).
local _, ItemTree = ...

local Data = ItemTree.Data
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local Diff = {}
ItemTree.Diff = Diff

Diff.KINDS = { "items", "recipes", "skills", "enchants" }

local EMPTY = {}

-- Human field names, as locale keys: the English wording is the key and Diff.FieldLabel draws
-- L of it, the way the group names in Core/ViewModel.lua work. Anything missing falls back to
-- the field with underscores removed, which no locale can translate, so a field a player will
-- actually see belongs in here.
--
-- stats_pct is the share of the item level's stat budget one stat takes, drawn as a percentage
-- on both sides (UI/InfoPanel.lua), so it is labelled for what it is rather than "weights".
local FIELD_LABELS = {
  name = "Name",
  -- Not a field the build states: the label over the one line a discovered entry carries.
  discovered = "Discovered",
  quality = "Quality",
  item_level = "Item level",
  required_level = "Required level",
  required_skill = "Required skill",
  required_skill_rank = "Skill level",
  allowable_class = "Classes",
  allowable_race = "Races",
  stack_size = "Stack size",
  max_count = "Unique",
  sell_price = "Sell price",
  buy_price = "Buy price",
  bonding = "Bonding",
  class = "Item class",
  subclass = "Item subclass",
  inventory_type = "Slot",
  item_set = "Item set",
  lock_id = "Lock",
  start_quest = "Starts quest",
  container_slots = "Slots",
  bag_family = "Bag type",
  totem_category = "Tool category",
  delay = "Speed",
  damage = "Damage",
  -- No build states armour as a column: it is worked out from four curves by item level,
  -- quality, armour subclass and slot (ItemTree-Data docs/armour.md), which is why an armour
  -- change is a plain number and not a list the way stats are. It is a base value, not a
  -- bonus, so nothing here ever writes it with a plus sign. Not the same thing as stat 50,
  -- "Extra armour", which is bonus armour and stays a stat.
  armour = "Armour",
  stats = "Stats",
  stats_pct = "Stat budget",
  effects = "Effects",
  icon = "Icon",
  -- Recipes
  skill_line = "Profession",
  min_rank = "Skill level",
  trivial_low = "Trivial low",
  trivial_high = "Trivial high",
  num_skillups = "Skill ups",
  supercedes = "Supercedes",
  reagents = "Reagents",
  output = "Creates",
  enchant = "Enchant",
  cooldown = "Cooldown",
  category_cooldown = "Shared cooldown",
  tools = "Tools",
  -- The tools a recipe names as exact items rather than as totem categories, which is a list of
  -- item ids and reads as the items' own names.
  tool_items = "Tool items",
  taught_by = "Taught by",
  -- Enchants and skills
  effect = "Effect",
  category = "Category",
  parent = "Parent",
}

-- ITEM_MOD codes to the name the client writes for them, which is what an item record's
-- stats and stat weight lists are keyed by.
--
-- Ids are the ItemMod enum the build states; the words are the client's ITEM_MOD_*_SHORT
-- global strings in sentence case, with Australian spelling where the two differ (the client
-- writes "Defense" and "Armor penetration"). Codes 2 and 8 to 11 are unused, and anything
-- this table does not carry falls back to "stat <id>", which the Forever beta needs: it
-- allocates weights on codes well past the Classic Era list.
Diff.ITEM_MOD = {
  [0] = "Mana",
  [1] = "Health",
  [3] = "Agility",
  [4] = "Strength",
  [5] = "Intellect",
  [6] = "Spirit",
  [7] = "Stamina",
  [12] = "Defence",
  [13] = "Dodge",
  [14] = "Parry",
  [15] = "Block",
  [16] = "Melee hit",
  [17] = "Ranged hit",
  [18] = "Spell hit",
  [19] = "Melee critical strike",
  [20] = "Ranged critical strike",
  [21] = "Spell critical strike",
  [22] = "Melee hit avoidance",
  [23] = "Ranged hit avoidance",
  [24] = "Spell hit avoidance",
  [25] = "Melee critical avoidance",
  [26] = "Ranged critical avoidance",
  [27] = "Spell critical avoidance",
  [28] = "Melee haste",
  [29] = "Ranged haste",
  [30] = "Spell haste",
  [31] = "Hit",
  [32] = "Critical strike",
  [33] = "Hit avoidance",
  [34] = "Critical avoidance",
  [35] = "Resilience",
  [36] = "Haste",
  [37] = "Expertise",
  [38] = "Attack power",
  [39] = "Ranged attack power",
  [40] = "Feral attack power",
  [41] = "Healing",
  [42] = "Spell damage",
  [43] = "Mana per 5",
  [44] = "Armour penetration",
  [45] = "Spell power",
  [46] = "Health per 5",
  [47] = "Spell penetration",
  [48] = "Block value",
  [49] = "Mastery",
  [50] = "Extra armour",
  [51] = "Fire resistance",
  [52] = "Frost resistance",
  [53] = "Holy resistance",
  [54] = "Shadow resistance",
  [55] = "Nature resistance",
  [56] = "Arcane resistance",
  [57] = "PvP power",
  -- The Forever beta moved school spell damage off equip effects and onto stat codes of its
  -- own, which is why a change row read "+14 stat 88". The names below are read out of the
  -- build rather than guessed: for each unnamed code, the items that gained it are the items
  -- whose Classic side lost an equip effect of exactly the same amount, and the effect's own
  -- spell name says which school it was ("Increase Shadow Dam 14" against stat 88 +14).
  --
  -- Evidence in build 1.60.1.69913, as items whose lost effect amount matches the gained stat:
  -- 83 Weapon Damage 1, 85 Increase Fire Dam 20, 86 Increase Nature Dam 4, 87 Increase Frost
  -- Dam 57, 88 Increase Shadow Dam 24, 89 Increase Arcane Dam 3, 117 Fishing Skill 8, 124
  -- Increased All Resist 3, 127 Demon Slaying 2. The six schools land on 83 plus the spell
  -- school index (physical, holy, fire, nature, frost, shadow, arcane), so 84 is named from that
  -- run even though no item in this build changed on it.
  [83] = "Weapon damage",
  [84] = "Holy spell damage",
  [85] = "Fire spell damage",
  [86] = "Nature spell damage",
  [87] = "Frost spell damage",
  [88] = "Shadow spell damage",
  [89] = "Arcane spell damage",
  [117] = "Fishing skill",
  [124] = "All resistances",
  [127] = "Demon slaying",
}

-- What sets an item effect off, from the first number of an fx entry. Only the triggers the
-- client names are named here (ITEM_SPELL_TRIGGER_ONUSE, _ONEQUIP and _ONPROC, plus the
-- soulstone and learn triggers the tables still carry); any other trigger prints the spell
-- on its own rather than guessing at a word for it.
local EFFECT_TRIGGERS = {
  [0] = "Use",
  [1] = "Equip",
  [2] = "Chance on hit",
  [4] = "Soulstone",
  [5] = "Use",
  [6] = "Learn",
}

-- The name of one ITEM_MOD code, or "stat 83" for a code no Classic Era global names.
function Diff.StatName(code)
  return Diff.ITEM_MOD[code] or ("stat " .. tostring(code))
end

-- The word for one effect trigger code, or nil for a trigger with no name of its own. The one
-- place these words live: a change row reads them from here and so does the item info column,
-- which draws the plain word Effect where this answers nothing.
function Diff.EffectTrigger(code)
  return EFFECT_TRIGGERS[code]
end

-- Milliseconds the way the client writes them: 48h, 24h, 90m, 45s. nil when the build states
-- no duration to write, which a change row reads as "none" and the item info column leaves
-- the cooldown off for.
function Diff.DurationText(ms)
  local value = tonumber(ms)
  if not value or value <= 0 then
    return nil
  end
  local seconds = math.floor(value / 1000 + 0.5)
  if seconds >= 3600 and seconds % 3600 == 0 then
    return string.format("%dh", math.floor(seconds / 3600))
  end
  if seconds >= 60 and seconds % 60 == 0 then
    return string.format("%dm", math.floor(seconds / 60))
  end
  if seconds >= 3600 then
    return string.format("%dh %dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
  end
  return string.format("%ds", seconds)
end

local DURATION_FIELDS = { cooldown = true, category_cooldown = true }

local function itemName(itemId)
  local item = Data:GetItem(itemId)
  if item and item.n then
    return item.n
  end
  local de = Data:GetDisenchant()
  local material = de and de.materials and de.materials[itemId]
  if material then
    return material
  end
  -- An item this build withholds has no name to state. Core/Graph.lua is the one place that
  -- decides what such a row is called, so a change line says the same words the tree does
  -- rather than a bare id; it loads before this file but is read at call time all the same.
  local Graph = ItemTree.Graph
  if Graph and type(Graph.Name) == "function" then
    local ok, named = pcall(Graph.Name, "item:" .. tostring(itemId))
    if ok and type(named) == "string" and named ~= "" then
      return named
    end
  end
  return "Item " .. tostring(itemId)
end

-- {{itemId, count}} -> "Rough Stone x1, Copper Bar x3"
local function formatReagents(list)
  if type(list) ~= "table" then
    return "none"
  end
  local parts = {}
  for _, reagent in ipairs(list) do
    parts[#parts + 1] = itemName(reagent[1]) .. " x" .. tostring(reagent[2] or 1)
  end
  if #parts == 0 then
    return "none"
  end
  return table.concat(parts, ", ")
end

-- {itemId, min, max} -> "Old Blade x1" or "Old Blade x1 to 2"
local function formatOutput(out)
  if type(out) ~= "table" or not out[1] then
    return "none"
  end
  local min, max = out[2] or 1, out[3] or out[2] or 1
  if max > min then
    return string.format("%s x%d to %d", itemName(out[1]), min, max)
  end
  return string.format("%s x%d", itemName(out[1]), min)
end

-- {{stat, amount}} -> "+3 Stamina", the way the client writes a stat line.
local function formatStats(list)
  if type(list) ~= "table" then
    return "none"
  end
  local parts = {}
  for _, stat in ipairs(list) do
    local amount = stat[2] or 0
    parts[#parts + 1] = string.format("%s%d %s", amount >= 0 and "+" or "", amount, Diff.StatName(stat[1]))
  end
  if #parts == 0 then
    return "none"
  end
  return table.concat(parts, ", ")
end

-- A stat budget share as the percentage it is. The build states the share out of 10,000, and
-- 5000 is not a number any player can read, so every line about a stat budget is written as
-- "50%" here rather than left to each consumer: the badge change panel reads oldText and
-- newText straight off a change line. UI/InfoPanel.lua converts the raw entry itself, which is
-- the same arithmetic on the same input and never this string, so the two cannot double
-- convert. Pure.
local function sharePercent(share)
  local value = tonumber(share) or 0
  if value < 0 then
    value = 0
  end
  return string.format(L["%d%%"], math.floor(value / 100 + 0.5))
end

-- {{stat, statPercentEditor}} -> "Stamina 36%, Attack power 172%". The build states an
-- allocation weight, not an amount, so the share follows the stat and carries no sign.
local function formatStatWeights(list)
  if type(list) ~= "table" then
    return "none"
  end
  local parts = {}
  for _, stat in ipairs(list) do
    parts[#parts + 1] = string.format("%s %s", Diff.StatName(stat[1]), sharePercent(stat[2]))
  end
  if #parts == 0 then
    return "none"
  end
  return table.concat(parts, ", ")
end

-- One effect entry {trigger, spell, charges, cooldownMs, categoryCooldownMs} as the words that
-- name it: "Use: Sharpen Blade", "Equip: spell 17188". Names come from ItemTree.SpellName, so
-- Core reads them from a SpellNames module when the pipeline ships one and the UI reads them
-- from the client; with neither, a spell still says which one it is by id. nil for an entry
-- that names no spell.
local function effectName(effect)
  local spellId = type(effect) == "table" and effect[2] or nil
  if spellId == nil then
    return nil
  end
  local resolver = ItemTree.SpellName
  local named = type(resolver) == "function" and resolver(spellId) or nil
  local text = named or ("spell " .. tostring(spellId))
  local trigger = Diff.EffectTrigger(effect[1])
  if trigger then
    return trigger .. ": " .. text
  end
  return text
end

-- Everything an effect entry says beyond which spell it is: the charges it carries, its own
-- cooldown and the cooldown it shares with a category. nil where it states none of them. This is
-- what tells "Use: Food" from "Use: Food" when a build only moved the shared cooldown, which is
-- the whole of 197 effect changes in 1.60.1.69913.
local function effectDetail(effect)
  if type(effect) ~= "table" then
    return nil
  end
  local parts = {}
  local charges = tonumber(effect[3]) or 0
  if charges ~= 0 then
    parts[#parts + 1] = charges == 1 and L["1 charge"] or string.format(L["%d charges"], charges)
  end
  local cooldown = Diff.DurationText(effect[4])
  if cooldown then
    parts[#parts + 1] = string.format(L["cooldown %s"], cooldown)
  end
  local shared = Diff.DurationText(effect[5])
  if shared then
    parts[#parts + 1] = string.format(L["shared cooldown %s"], shared)
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts, ", ")
end

-- {{trigger, spell, charges, cooldownMs, categoryCooldownMs}} -> "Use: Sharpen Blade,
-- Equip: spell 17188".
local function formatEffects(list)
  if type(list) ~= "table" then
    return "none"
  end
  local parts = {}
  for _, effect in ipairs(list) do
    local name = effectName(effect)
    if name then
      parts[#parts + 1] = name
    end
  end
  if #parts == 0 then
    return "none"
  end
  return table.concat(parts, ", ")
end

-- {totemCategoryId} -> "Blacksmith Hammer, Anvil". A recipe's tools are category ids, and
-- a row that printed them would read "Tools none to 162".
local function formatToolCategories(list)
  if type(list) ~= "table" then
    return "none"
  end
  local parts = {}
  for _, category in ipairs(list) do
    parts[#parts + 1] = Data:GetTotemCategoryName(category)
  end
  if #parts == 0 then
    return "none"
  end
  return table.concat(parts, ", ")
end

local function formatItemList(list)
  if type(list) ~= "table" then
    return "none"
  end
  local parts = {}
  for _, itemId in ipairs(list) do
    parts[#parts + 1] = itemName(itemId)
  end
  if #parts == 0 then
    return "none"
  end
  return table.concat(parts, ", ")
end

local function formatList(list)
  local parts = {}
  for _, value in ipairs(list) do
    if type(value) == "table" then
      parts[#parts + 1] = formatList(value)
    else
      parts[#parts + 1] = tostring(value)
    end
  end
  if #parts == 0 then
    return "none"
  end
  return table.concat(parts, ", ")
end

-- The class an item belongs to, by id: "Trade Goods". The names come from the generated
-- Classes module (Data:GetClassName); a build that shipped without it falls back to the number,
-- which is what the row used to read either way. baseline asks for the name the comparison
-- build gave it, which is what the old side of a change is.
local function className(classId, baseline)
  local name = Data:GetClassName(classId, nil, baseline)
  return name or tostring(classId)
end

-- The subclass, by id: "Leather". A subclass id only means something next to its class, so the
-- class travels with it; with no class to read it against, the number stands.
local function subclassName(classId, subclassId, baseline)
  if classId == nil then
    return tostring(subclassId)
  end
  local _, sub = Data:GetClassName(classId, subclassId, baseline)
  return sub or tostring(subclassId)
end

-- Where the id sits inside one entry of a list field. Used only when both sides of a change
-- read the same way, to say which is which.
local ID_AT = { effects = 2, reagents = 1 }

-- The ids behind a value, "15852" or "15852, 15853", or nil when the value carries none. Two
-- spells can share one name, so a change between them reads as no change at all until the ids
-- are on it.
local function idText(field, value)
  if type(value) ~= "table" then
    return nil
  end
  local parts = {}
  if field == "output" then
    if value[1] then
      parts[1] = tostring(value[1])
    end
  elseif ID_AT[field] then
    for _, entry in ipairs(value) do
      local id = type(entry) == "table" and entry[ID_AT[field]] or nil
      if id then
        parts[#parts + 1] = tostring(id)
      end
    end
  else
    for _, entry in ipairs(value) do
      if type(entry) == "number" then
        parts[#parts + 1] = tostring(entry)
      end
    end
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts, ", ")
end

-- How an id is tacked onto a value that would otherwise read the same on both sides.
local ID_SUFFIX = "%s [%s]"

-- Text for one side of a change, in the client's number style. context is optional and carries
-- the class id this side belongs to, which is the only way a subclass number reads as a name,
-- and context.baseline for the old side, which names a class or subclass the way the comparison
-- build named it: a subclass that was renamed rather than moved would otherwise read as no
-- change at all.
function Diff.FormatValue(field, value, context)
  if DURATION_FIELDS[field] then
    return Diff.DurationText(value) or "none"
  end
  if value == nil then
    return "none"
  end
  local baseline = context ~= nil and context.baseline == true
  if field == "class" then
    return className(value, baseline)
  end
  if field == "subclass" then
    return subclassName(context and context.class or nil, value, baseline)
  end
  if field == "reagents" then
    return formatReagents(value)
  end
  if field == "output" then
    return formatOutput(value)
  end
  if field == "stats" then
    return formatStats(value)
  end
  if field == "stats_pct" then
    return formatStatWeights(value)
  end
  if field == "effects" then
    return formatEffects(value)
  end
  -- A rank of 0 means the build never said what the recipe needs, not that it needs nothing.
  if field == "min_rank" and value == 0 then
    return "unknown"
  end
  -- Armour of 0 means the curves say nothing about this item, not that it has 0 armour: an
  -- item that stops being armour, or moves to a slot that holds none, reads "63 to none".
  if field == "armour" and value == 0 then
    return "none"
  end
  if field == "taught_by" or field == "tool_items" then
    return formatItemList(value)
  end
  if field == "tools" then
    return formatToolCategories(value)
  end
  if type(value) == "boolean" then
    return value and "yes" or "no"
  end
  if type(value) == "table" then
    return formatList(value)
  end
  return tostring(value)
end

function Diff.FieldLabel(field)
  local label = FIELD_LABELS[field]
  if label then
    return L[label]
  end
  local words = tostring(field):gsub("_", " ")
  return (words:gsub("^%l", string.upper))
end

-- The one place a change becomes text, so the tree, the info panel, the report and the
-- browser harness all say the same thing about it. Returns the whole line in the house
-- style, "old to new", and then each side on its own for a caller that colours them
-- separately (UI/Tree.lua draws the old value in disabled grey).
--
-- context is optional: { class, oldClass, newClass } for an item, so each side of a subclass
-- change is read against the class that side belonged to. The old side is also read against the
-- comparison build's own names for a class and its subclasses, so a class that was renamed
-- rather than moved reads as the change it is. When the two sides still render the same words,
-- the ids behind them are appended in brackets, because a change a player cannot see is worse
-- than a long line.
function Diff.ChangeText(field, old, new, context)
  context = context or EMPTY
  local oldText = Diff.FormatValue(field, old, { class = context.oldClass or context.class, baseline = true })
  local newText = Diff.FormatValue(field, new, { class = context.newClass or context.class })
  if oldText == newText then
    local oldIds, newIds = idText(field, old), idText(field, new)
    if oldIds and newIds and oldIds ~= newIds then
      oldText = string.format(L[ID_SUFFIX], oldText, oldIds)
      newText = string.format(L[ID_SUFFIX], newText, newIds)
    end
  end
  return string.format(L["%s to %s"], oldText, newText), oldText, newText
end

--------------------------------------------------------------------------------
-- Multi value fields, entry by entry
--------------------------------------------------------------------------------

-- A field whose value is a list of entries reads as nonsense when both sides are printed whole:
-- "Stats +5 Intellect to +5 Intellect, +14 Shadow spell damage" makes the reader diff it
-- themselves. Each of these fields is compared entry by entry instead, an entry both sides agree
-- on says nothing and is dropped, and everything that came, went or moved is its own line.
--
-- A describer turns one raw entry into:
--   key    what pairs an old entry with its new one, so "which stat" survives a reorder
--   name   what the entry is on its own: "Stamina", "Use: Food"
--   value  what it says, which is the part that moves: "+4". nil where the entry is only a name
--   text   the whole entry in the client's wording: "+4 Stamina"
--   id     the id behind it, appended in brackets when two entries read the same
-- nil for an entry the build states nothing usable in.
local function describeStat(entry)
  if type(entry) ~= "table" or entry[1] == nil then
    return nil
  end
  local amount = entry[2] or 0
  local name = Diff.StatName(entry[1])
  local value = string.format("%s%d", amount >= 0 and "+" or "", amount)
  return { key = tostring(entry[1]), name = name, value = value, text = value .. " " .. name, id = tostring(entry[1]) }
end

local function describeStatWeight(entry)
  if type(entry) ~= "table" or entry[1] == nil then
    return nil
  end
  local name = Diff.StatName(entry[1])
  local value = sharePercent(entry[2])
  return { key = tostring(entry[1]), name = name, value = value, text = name .. " " .. value, id = tostring(entry[1]) }
end

local function describeEffect(entry)
  local name = effectName(entry)
  if not name then
    return nil
  end
  local value = effectDetail(entry)
  return {
    key = tostring(entry[1]) .. ":" .. tostring(entry[2]),
    name = name,
    value = value,
    text = value and (name .. ", " .. value) or name,
    id = tostring(entry[2]),
  }
end

local function describeReagent(entry)
  if type(entry) ~= "table" or entry[1] == nil then
    return nil
  end
  local name = itemName(entry[1])
  local value = "x" .. tostring(entry[2] or 1)
  return { key = tostring(entry[1]), name = name, value = value, text = name .. " " .. value, id = tostring(entry[1]) }
end

local function describeItem(entry)
  if type(entry) ~= "number" then
    return nil
  end
  local name = itemName(entry)
  return { key = tostring(entry), name = name, value = nil, text = name, id = tostring(entry) }
end

local function describeTool(entry)
  if type(entry) ~= "number" then
    return nil
  end
  local name = Data:GetTotemCategoryName(entry)
  return { key = tostring(entry), name = name, value = nil, text = name, id = tostring(entry) }
end

local ENTRY_DESCRIBERS = {
  stats = describeStat,
  stats_pct = describeStatWeight,
  effects = describeEffect,
  reagents = describeReagent,
  taught_by = describeItem,
  tools = describeTool,
  -- Exact items rather than categories, so the item describer, which means a row reads
  -- "Blacksmith Hammer removed" and not "Tool items 5956 to none".
  tool_items = describeItem,
}

-- Whether a field is diffed entry by entry. The tree, the badge hover and the item column all
-- read the same answer, so this is the one place the list fields are named.
function Diff.IsListField(field)
  return ENTRY_DESCRIBERS[field] ~= nil
end

-- Deep equality over one entry, which is a short array of numbers. An entry the two builds state
-- identically says nothing and is dropped.
local function sameEntry(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return a == b
  end
  for index = 1, math.max(#a, #b) do
    if not sameEntry(a[index], b[index]) then
      return false
    end
  end
  return true
end

-- One side of a list field as described entries in order, keyed so that the same entry on the
-- other side finds it. A list that states the same key twice keeps both, matched in order.
local function describeList(describe, list)
  local out, index = { order = {}, at = {} }, {}
  for _, entry in ipairs(list) do
    local described = describe(entry)
    if described then
      local seen = (index[described.key] or 0) + 1
      index[described.key] = seen
      local key = described.key .. "#" .. tostring(seen)
      described.entry = entry
      out.at[key] = described
      out.order[#out.order + 1] = key
    end
  end
  return out
end

-- Text for one entry, with its id in brackets where two entries of the field read the same.
local function entryText(described, collides)
  if collides and described.id then
    return string.format(L[ID_SUFFIX], described.text, described.id)
  end
  return described.text
end

-- The change lines for one multi value field, or nil when the field is not one or neither side
-- states a list. Lines come out in the old side's order, with whatever is only on the new side
-- after it, so a reader follows the record rather than an alphabet.
local function listLines(field, label, old, new)
  local describe = ENTRY_DESCRIBERS[field]
  if not describe or (type(old) ~= "table" and type(new) ~= "table") then
    return nil
  end
  local before = describeList(describe, type(old) == "table" and old or EMPTY)
  local after = describeList(describe, type(new) == "table" and new or EMPTY)

  local order, seen = {}, {}
  for _, key in ipairs(before.order) do
    order[#order + 1] = key
    seen[key] = true
  end
  for _, key in ipairs(after.order) do
    if not seen[key] then
      order[#order + 1] = key
    end
  end

  -- Two entries of the same field that read the same, one going and one coming, say nothing
  -- without their ids: "Use: Food removed, Use: Food added" is the same line twice.
  local names = {}
  local pending = {}
  for _, key in ipairs(order) do
    local oldSide, newSide = before.at[key], after.at[key]
    if not (oldSide and newSide and sameEntry(oldSide.entry, newSide.entry)) then
      local entry = { key = key, old = oldSide, new = newSide }
      pending[#pending + 1] = entry
      local name = (oldSide or newSide).name
      names[name] = (names[name] or 0) + 1
    end
  end

  local lines = {}
  for _, entry in ipairs(pending) do
    local oldSide, newSide = entry.old, entry.new
    local collides = names[(oldSide or newSide).name] > 1
    if oldSide and newSide then
      -- The entry moved. Its own name leads the line, so the two sides are only the part that
      -- differs: "Stamina +4 to +6".
      local oldValue = oldSide.value or "none"
      local newValue = newSide.value or "none"
      local name = collides and string.format(L[ID_SUFFIX], oldSide.name, oldSide.id) or oldSide.name
      lines[#lines + 1] = {
        field = field,
        label = name,
        op = "changed",
        old = oldSide.entry,
        new = newSide.entry,
        oldText = oldValue,
        newText = newValue,
        text = string.format(L["%s to %s"], oldValue, newValue),
      }
    elseif oldSide then
      local text = entryText(oldSide, collides)
      lines[#lines + 1] = {
        field = field,
        label = label,
        op = "removed",
        old = oldSide.entry,
        new = nil,
        oldText = text,
        newText = nil,
        text = string.format(L["%s removed"], text),
      }
    else
      local text = entryText(newSide, collides)
      lines[#lines + 1] = {
        field = field,
        label = label,
        op = "added",
        old = nil,
        new = newSide.entry,
        oldText = nil,
        newText = text,
        text = string.format(L["%s added"], text),
      }
    end
  end
  if #lines == 0 then
    return nil
  end
  return lines
end

-- Lazily built lookups over the generated tables.
local cache = nil

local function kindData(kind)
  local diff = Data:GetDiff()
  return diff and diff[kind] or nil
end

-- The detail for one kind, out of DiffChanges. Loads ItemTree_Data the first time.
local function detailData(kind)
  local detail = Data:Get("DiffChanges")
  return type(detail) == "table" and detail[kind] or nil
end

-- The change rows DiffChanges holds for one id, as the list of {field, old, new[, tag][, minor]}
-- rows the plain module held, or nil. Brief OPT7: a packed module (packed = 1, the legend at its
-- top level) ships each id's rows as ONE string, which Data.PackedList decodes on the first read
-- into a weak valued cache per id, so the same list is answered while anything holds it. An older
-- plain module's rows are answered as they are.
local function detailChanges(kind, id)
  local detail = Data:Get("DiffChanges")
  local source = type(detail) == "table" and detail[kind] or nil
  local changed = type(source) == "table" and source.changed or nil
  if type(changed) ~= "table" then
    return nil
  end
  local rows = changed[id]
  if type(rows) == "string" and type(Data.PackedList) == "function" then
    rows = Data.PackedList(detail, changed, id)
  end
  if type(rows) ~= "table" then
    return nil
  end
  return rows
end

-- One of a kind's detail tables (removed, renumbered): the Diff module's own where it carries it,
-- as the older single module did, and DiffChanges' otherwise.
local function detailTable(kind, name)
  local source = kindData(kind)
  if source and type(source[name]) == "table" then
    return source[name]
  end
  local detail = detailData(kind)
  return detail and type(detail[name]) == "table" and detail[name] or nil
end

-- The id arrays a badge asks about (new, hidden, discovered, newUndiscovered, sod) are read in
-- place by binary search rather than copied into sets, so only the generated arrays are held
-- (brief OPT2, audit F7: the sets cost about 1.4 MB on the first badge). The pipeline writes them
-- strictly ascending, which tests/spec/diff_spec.lua proves for the shipped data; an array that is
-- not (quests.new, and any a spec makes up) is copied once and the copy sorted, and one holding
-- anything but numbers falls back to a set, so every answer stays what the set gave.
local BUCKETS = { "new", "hidden", "discovered", "newUndiscovered", "sod" }

-- One bucket's membership: { list = ids, n = count } searched by binary search, or { set = ids }.
local function bucketOf(ids)
  if type(ids) ~= "table" then
    return { list = EMPTY, n = 0 }
  end
  local count, ascending, numbers, previous = 0, true, true, nil
  for _, id in ipairs(ids) do
    count = count + 1
    if type(id) ~= "number" or id ~= id then
      numbers = false
      break
    end
    if previous ~= nil and id <= previous then
      ascending = false
    end
    previous = id
  end
  if not numbers then
    local set = {}
    for _, id in ipairs(ids) do
      set[id] = true
    end
    return { set = set }
  end
  if ascending then
    return { list = ids, n = count }
  end
  local copy = {}
  for index = 1, count do
    copy[index] = ids[index]
  end
  table.sort(copy)
  return { list = copy, n = count }
end
Diff._BucketOf = bucketOf

-- Whether id is in a bucket: what `set[id] == true` answered over the old set. Binary search over
-- an ascending array of numbers; any id that is not a number is in none.
local floor = math.floor

local function inBucket(bucket, id)
  local set = bucket.set
  if set then
    return id ~= nil and set[id] == true
  end
  if type(id) ~= "number" or id ~= id then
    return false
  end
  local list = bucket.list
  local low, high = 1, bucket.n
  while low <= high do
    local mid = floor((low + high) / 2)
    local at = list[mid]
    if at == id then
      return true
    elseif at < id then
      low = mid + 1
    else
      high = mid - 1
    end
  end
  return false
end
Diff._InBucket = inBucket

-- A binary search costs about a microsecond more than a set read, and a tooltip or a bag pass
-- asks the same few ids about several buckets again and again, so each kind keeps its last
-- answers in one small memo: id to a mask with a bit per bucket, all five asked on the first
-- question, emptied whenever it holds MEMO_CAP ids (about 10 KB at most).
local MEMO_CAP = 256
local BUCKET_BIT = { new = 1, hidden = 2, discovered = 4, newUndiscovered = 8, sod = 16 }
Diff._MEMO_CAP = MEMO_CAP

local function member(built, name, id)
  if type(id) ~= "number" or id ~= id then
    return inBucket(built[name], id)
  end
  local mask = built.memo[id]
  if mask == nil then
    mask = 0
    for _, bucket in ipairs(BUCKETS) do
      if inBucket(built[bucket], id) then
        mask = mask + BUCKET_BIT[bucket]
      end
    end
    if built.memoCount >= MEMO_CAP then
      built.memo, built.memoCount = {}, 0
    end
    built.memo[id] = mask
    built.memoCount = built.memoCount + 1
  end
  local bit = BUCKET_BIT[name]
  return floor(mask / bit) % 2 == 1
end
Diff._Member = member

-- A map of id to the source's tag. Anything else in the slot is no harvest at all. The generated
-- map is read in place where every key is a number and every tag a non-empty string, which is
-- what the pipeline writes; otherwise the clean copy is made, as it always was.
local function harvestedOf(map)
  if type(map) ~= "table" then
    return {}
  end
  local clean = true
  for id, tag in pairs(map) do
    if type(id) ~= "number" or type(tag) ~= "string" or tag == "" then
      clean = false
      break
    end
  end
  if clean then
    return map
  end
  local copy = {}
  for id, tag in pairs(map) do
    local key = tonumber(id)
    if key and type(tag) == "string" and tag ~= "" then
      copy[key] = tag
    end
  end
  return copy
end
Diff._HarvestedOf = harvestedOf

local function lookups(kind)
  cache = cache or {}
  if cache[kind] then
    return cache[kind]
  end
  local source = kindData(kind) or EMPTY
  local built = { memo = {}, memoCount = 0 }
  for _, bucket in ipairs(BUCKETS) do
    built[bucket] = bucketOf(source[bucket])
  end
  built.harvested = harvestedOf(source.harvested)
  cache[kind] = built
  return built
end

-- New id to old id, per kind, out of the renumbered detail. Built apart from the lookups above,
-- which every badge reads, because the detail lives in DiffChanges and only a page asks this.
local fromNew = nil

-- How many flagged items sit in each diff bucket (brief DV1, Diff.Counts), built once per Diff
-- table.
local devInBuckets = nil

-- Brief DV1: whether an item is one no player can ever get (Data:IsHidden, one read of the Diff
-- module's items.dev set). Such an item wears no New, Season of Discovery or Changed mark
-- anywhere, is in no discovered list and states no change: every predicate below answers false
-- for it, so every badge, list and count built on them leaves it out. Items only.
local function unobtainable(kind, id)
  if kind ~= "items" or type(Data) ~= "table" or type(Data.IsHidden) ~= "function" then
    return false
  end
  return Data:IsHidden(id) == true
end
Diff.IsUnobtainable = unobtainable

-- Drops the lazily built lookups (tests, or after swapping data modules).
function Diff.Reset()
  cache = nil
  fromNew = nil
  devInBuckets = nil
end

-- New to a player of this client, which is what the New medallion stands for: the build's own
-- new bucket, the discovered one beside it, and the newUndiscovered one beside that.
--
-- The shipped data is always compared against the Classic Era baseline, and an entry Classic Era
-- never named is new to anybody playing Forever, whether this build added it outright, only
-- started answering about an id the baseline listed and withheld, or added an id the baseline
-- has no row for at all and is not ready to describe yet. The three are told apart for the one
-- extra line a discovered entry carries (Diff.IsDiscovered), never for the mark.
--
-- newUndiscovered is the pipeline's answer to the one question the buckets above cannot reach:
-- neither build names such an id, so the comparison of the named tables never sees it. The
-- answer is only ever "the baseline could not name it", never anything about what a row would
-- have said. Since 2026-09-26 that includes an id the baseline listed and could never name,
-- which is where Season of Discovery items are: 2,420 items in build 1.60.1.70009, not every one
-- with an Undiscovered stub behind it. The pipeline puts a discovered id in `new` as well now,
-- and reading both here is harmless. A Season of Discovery id (Diff.IsSod) is new too. See
-- ItemTree-Data docs/undiscovered-items.md.
--
-- A discovered id that is not in the new bucket is a Classic item the realm found: the baseline
-- named it, so it is discovered and not new, whether a harvest tagged it (brief D3) or the
-- client's pushed records found it untagged (the pipeline's hotfix layer, 2026-09-27). The
-- pipeline files every discovered id the baseline could not name in the new bucket as well, so
-- the new bucket is the one answer and the discovered bucket says nothing about newness here.
function Diff.IsNew(kind, id)
  if unobtainable(kind, id) then
    return false
  end
  local built = lookups(kind)
  return member(built, "new", id) or member(built, "newUndiscovered", id)
end

-- The tag of the source that named a harvested id ("miner", the Discovery Miner), or nil for an
-- id no harvest named. What the data says whatever the setting: this is where it came from, not
-- whether it is shown.
function Diff.HarvestSource(kind, id)
  return lookups(kind).harvested[tonumber(id) or id]
end

-- Whether a harvest named the id, any source at all.
function Diff.IsHarvested(kind, id)
  return Diff.HarvestSource(kind, id) ~= nil
end

-- Whether the setting has put a harvested id back behind its stub: showHarvested is off, so the
-- id reads the way it did before the harvest named it. Data:HarvestMasked is the one answer;
-- items only, because only items are harvested.
local function masked(kind, id)
  if kind ~= "items" or not Diff.IsHarvested(kind, id) then
    return false
  end
  if type(Data) ~= "table" or type(Data.HarvestMasked) ~= "function" then
    return false
  end
  local ok, answer = pcall(Data.HarvestMasked, Data, tonumber(id) or id)
  return ok and answer == true
end
Diff.IsMasked = masked

-- The words for where a harvest's change came from, once per list: the badge hover says it under
-- the change lines. nil for a tag this file has no words for.
function Diff.SourceText(tag)
  if tag == "miner" then
    return L["From the beta harvest"]
  end
  return nil
end

-- Brief C1: whether minor changes count, the account wide includeMinorChanges setting. Off, and
-- off wherever there are no settings to read (a spec, a half loaded client), because off is the
-- default.
function Diff.IncludeMinor()
  local db = ItemTree.db
  local settings = type(db) == "table" and db.settings or nil
  return type(settings) == "table" and settings.includeMinorChanges == true
end

-- Whether a change row is marked minor: true as its fifth element. Pure.
function Diff.IsMinorRow(change)
  return type(change) == "table" and change[5] == true
end

-- The changed entry for an id: the major set's first, then the minor set's while the setting counts
-- it. Whatever the set holds (true, or the rows themselves in the older single module), or nil.
local function changedEntry(source, id)
  if source == nil then
    return nil
  end
  local held = type(source.changed) == "table" and source.changed[id] or nil
  if held == nil and Diff.IncludeMinor() and type(source.changedMinor) == "table" then
    held = source.changedMinor[id]
  end
  return held
end

-- A harvested id the setting has hidden has no change to show: every row it carries came from the
-- harvest, which is exactly what is hidden. An id whose every change is minor is Changed only
-- while the setting includes minor changes (brief C1).
function Diff.IsChanged(kind, id)
  if changedEntry(kindData(kind), id) == nil then
    return false
  end
  return not masked(kind, id) and not unobtainable(kind, id)
end

function Diff.IsRemoved(kind, id)
  local removed = detailTable(kind, "removed")
  return removed ~= nil and removed[id] ~= nil
end

-- Items the build still has an Item row for while the ItemSparse row is gone, so it states
-- no name, stats or requirements for them. A beta can ship thousands of these; they are not
-- removals, they carry no summary, and they are never badged.
--
-- A harvested Classic item the setting has hidden is hidden again, which is what it was before
-- the harvest named it.
function Diff.IsHidden(kind, id)
  local built = lookups(kind)
  if member(built, "hidden", id) then
    return true
  end
  return built.harvested[id] ~= nil and not member(built, "new", id) and masked(kind, id)
end

-- The other direction: the baseline had the Item row and would not name it, and this build
-- does. Something dropped and the client started answering, so the pipeline files it apart from
-- the entries the build added outright, and it is kept out of the renumbering match.
--
-- It still wears the New medallion (Diff.IsNew), because the comparison is against Classic Era
-- and an item Classic Era never named is new to the player looking at it. Inventing a fifth
-- mark for it would cost every list a glyph a player has to learn, so what it carries beyond
-- the medallion is one line, through Diff.GetChanges, which the tooltip block, the tree row and
-- the info column all say once.
function Diff.IsDiscovered(kind, id)
  return member(lookups(kind), "discovered", id) and not masked(kind, id) and not unobtainable(kind, id)
end

-- An item this build has an Item row for and no ItemSparse row, which the Classic Era baseline
-- has no Item row for at all: new in Forever, and not ready to be described yet. Withheld, so it
-- is not hidden (that is the opposite: an id the baseline NAMED and this build withholds) and
-- not discovered (that is an id this build started answering about).
--
-- It wears the New medallion through Diff.IsNew and carries no change line of its own: there is
-- nothing to compare, because neither build ever stated a field for it. Most have a stub, so the
-- window can draw a class, a slot and an icon and say the rest is not known yet; since
-- 2026-09-26 the pipeline files every such id here, stub or not, so a caller that has to draw
-- one checks for the stub itself (Data:NewInForeverIds does).
function Diff.IsNewUndiscovered(kind, id)
  return member(lookups(kind), "newUndiscovered", id) and not unobtainable(kind, id)
end

-- A new item that came from Season of Discovery: the Classic Era baseline listed the id and
-- could never name it, and the id is in the block Season of Discovery content was added in
-- (ItemTree-Data diff.SOD_ID_FLOOR). Every such id is New as well (Diff.IsNew), and it wears
-- the Season of Discovery mark in place of the New one (Diff.Badges). Items only; the pipeline
-- states no such set for another kind.
function Diff.IsSod(kind, id)
  return member(lookups(kind), "sod", id) and not unobtainable(kind, id)
end

-- The badge kinds that mean New to a player: "new", and "sod", which is New with the item's
-- origin on it. A caller holding a kind out of Diff.Badges asks this rather than comparing with
-- "new", so a Season of Discovery item counts wherever a New one does.
Diff.NEW_BADGES = { new = true, sod = true }

function Diff.IsNewBadge(badge)
  return Diff.NEW_BADGES[badge] == true
end

-- The ids this build newly names, for one kind, sorted ascending. A fresh array every call, so
-- a caller that sorts or trims the answer can never reach the generated table. Core/Discoveries
-- .lua draws the "In this data build" band from here.
function Diff.DiscoveredIds(kind)
  local out = {}
  local source = kindData(kind)
  local ids = source and source.discovered or nil
  if type(ids) ~= "table" then
    return out
  end
  for _, id in ipairs(ids) do
    local value = tonumber(id)
    if value and not masked(kind, value) and not unobtainable(kind, value) then
      out[#out + 1] = value
    end
  end
  table.sort(out)
  return out
end

-- The moment the shipped data says one item of this kind was discovered, as a unix time, or nil
-- where it does not say. Core/Discoveries.lua sorts a dated build entry among the dated rows.
--
-- The agreed shape, which the pipeline will emit beside the discovered array it already writes:
--
--   items = {
--     discovered = { 19019, 19364, ... },               -- as now, sorted ids
--     discoveredAt = { [19019] = 1758268800, ... },     -- optional, id to unix time (UTC seconds)
--   }
--
-- A parallel map keyed by item id, so the array every other reader walks is untouched and a
-- build without the map reads exactly as today. Since brief D3 the pipeline fills it from the
-- Discovery Miner's harvest: when the miner first saw the id named on the beta realm. A value
-- that is not a positive number is no moment at all, and a harvested id the setting has hidden
-- has none either.
function Diff.DiscoveredAt(kind, id)
  local source = kindData(kind)
  local map = source and source.discoveredAt or nil
  local key = tonumber(id)
  if type(map) ~= "table" or not key or masked(kind, key) or unobtainable(kind, key) then
    return nil
  end
  local at = tonumber(map[key])
  if at and at > 0 then
    return at
  end
  return nil
end

-- The words a discovered entry carries in place of a change. Its own function so the tooltip
-- block, the info column and the tree row all draw the one sentence.
function Diff.DiscoveredLine()
  return L["Newly named in this build"]
end

-- The class ids a subclass change is read against. An item that moved class moved each side
-- with it, so the old subclass belongs to the old class and the new one to the new class; an
-- item that did not move reads both sides against the class it has now.
local function classContext(kind, id, changes)
  if kind ~= "items" then
    return nil
  end
  local item = Data:GetItem(id)
  local current = item and item.c or nil
  local context = { class = current, oldClass = current, newClass = current }
  for _, change in ipairs(changes or EMPTY) do
    if change[1] == "class" then
      context.oldClass = change[2] or current
      context.newClass = change[3] or current
    end
  end
  return context
end

-- The lines one change row makes, appended to out. Split out of Diff.GetChanges so the loop
-- there reads as the filter it is.
local function appendChange(out, change, context)
  local field = change[1]
  local label = Diff.FieldLabel(field)
  local tag = type(change[4]) == "string" and change[4] or nil
  local lines = listLines(field, label, change[2], change[3])
  if lines then
    for _, line in ipairs(lines) do
      line.source = tag
      out[#out + 1] = line
    end
    return
  end
  local text, oldText, newText = Diff.ChangeText(field, change[2], change[3], context)
  out[#out + 1] = {
    field = field,
    old = change[2],
    new = change[3],
    label = label,
    op = "changed",
    text = text,
    oldText = oldText,
    newText = newText,
    source = tag,
  }
end

-- Array of { field, label, op, old, new, text, oldText, newText } for one entry. old and new are
-- the raw values and oldText and newText the two sides on their own, so a tooltip can strike the
-- old one through.
--
-- op is "changed", "added" or "removed". A multi value field (Diff.IsListField) is compared
-- entry by entry, so one such field can answer with several lines: an entry both builds state
-- the same way is dropped, an entry that only one side has is added or removed and carries only
-- that side (the other text is nil), and an entry that moved reads as its own name and the two
-- values, "Stamina +4 to +6". Everything else is one line, "old to new", exactly as before.
--
-- A row the harvest produced carries its source's tag as a fourth element ({field, old, new,
-- "miner"}), and every line built from it carries that tag as source; a row with three elements
-- carries none. A harvested id the setting has hidden answers no lines at all.
--
-- Brief C1: a minor row (Diff.IsMinorRow) is left out while the setting does not include minor
-- changes, and an id whose every row is minor then has none to list. With the setting on every
-- row is listed, as it always was.
function Diff.GetChanges(kind, id)
  local out = {}
  if masked(kind, id) or unobtainable(kind, id) then
    return out
  end
  if Diff.IsDiscovered(kind, id) then
    out[#out + 1] = {
      field = "discovered",
      label = Diff.FieldLabel("discovered"),
      op = "added",
      text = Diff.DiscoveredLine(),
      newText = Diff.DiscoveredLine(),
    }
  end
  local changes = changedEntry(kindData(kind), id)
  if changes == nil then
    return out
  end
  -- Diff says the id is Changed; the rows are in DiffChanges unless Diff carries them itself.
  if type(changes) ~= "table" then
    changes = detailChanges(kind, id)
  end
  if type(changes) ~= "table" then
    return out
  end
  -- The context reads every row, minor or not: a subclass named against the class it belongs to
  -- is right whichever rows are listed.
  local context = classContext(kind, id, changes)
  local includeMinor = Diff.IncludeMinor()
  for _, change in ipairs(changes) do
    if includeMinor or not Diff.IsMinorRow(change) then
      appendChange(out, change, context)
    end
  end
  return out
end

-- The named entry point for the list of lines behind a Changed badge, for a tooltip that shows
-- what changed when the badge is hovered. The same array Diff.GetChanges returns.
function Diff.ChangeLines(kind, id)
  return Diff.GetChanges(kind, id)
end

function Diff.Renumbered(kind, oldId)
  local renumbered = detailTable(kind, "renumbered")
  return renumbered and renumbered[oldId] or nil
end

function Diff.RenumberedFrom(kind, newId)
  fromNew = fromNew or {}
  local held = fromNew[kind]
  if not held then
    held = {}
    for oldId, id in pairs(detailTable(kind, "renumbered") or EMPTY) do
      held[id] = oldId
    end
    fromNew[kind] = held
  end
  return held[newId]
end

function Diff.RemovedSummary(kind, id)
  local removed = detailTable(kind, "removed")
  return removed and removed[id] or nil
end

-- Badge kinds for a node. Removed entries are only reachable through RemovedSummary,
-- so "removed" is never returned here, and a hidden entry gets no badge at all: the build
-- says nothing about it, which is not news to show a player. A discovered entry is inside
-- Diff.IsNew, so it wears the New medallion like anything else this build brought, and so is a
-- withheld id the baseline never listed: it is in no `hidden` bucket, so it falls through to
-- the New line below and gets the medallion and nothing else. Changed cannot reach it, because
-- a `changed` row needs two named entries to compare and it has none. A new item from Season of
-- Discovery answers "sod" in place of "new", never both: it is the same mark in purple.
function Diff.Badges(kind, id)
  local out = {}
  if Diff.IsHidden(kind, id) then
    return out
  end
  if Diff.IsNew(kind, id) then
    if Diff.IsSod(kind, id) then
      out[#out + 1] = "sod"
    else
      out[#out + 1] = "new"
    end
  end
  if Diff.IsChanged(kind, id) then
    out[#out + 1] = "changed"
  end
  return out
end

-- Brief DV1: Meta.devCounts, { dev, unreleased }, how many ids this build flags as developer items
-- and as probably never released. Zeros where the data states none.
function Diff.DevCounts()
  local meta = type(Data) == "table" and Data.Meta or nil
  local held = type(meta) == "table" and meta.devCounts or nil
  if type(held) ~= "table" then
    return { dev = 0, unreleased = 0 }
  end
  return { dev = tonumber(held.dev) or 0, unreleased = tonumber(held.unreleased) or 0 }
end

-- The buckets a flagged item is taken out of when a count is shown: the ones a player sees a
-- mark or a list for. Meta.diffCounts still counts flagged ids (the pipeline leaves them in every
-- set), and Meta.devCounts only says how many there are in all, so how many sit in each bucket is
-- read off the sets themselves: one pass over items.dev, once per data build.
local DEV_BUCKETS = { "new", "discovered", "newUndiscovered", "sod", "harvested", "changed", "changedMinor" }

local function devBucketCounts()
  local diff = Data:GetDiff()
  local items = type(diff) == "table" and diff.items or nil
  if devInBuckets and devInBuckets.from == items then
    return devInBuckets.counts
  end
  local counts = {}
  for _, bucket in ipairs(DEV_BUCKETS) do
    counts[bucket] = 0
  end
  local dev = type(items) == "table" and items.dev or nil
  if type(dev) == "table" and next(dev) ~= nil then
    local built = lookups("items")
    local sets = {
      changed = type(items.changed) == "table" and items.changed or EMPTY,
      changedMinor = type(items.changedMinor) == "table" and items.changedMinor or EMPTY,
    }
    for id in pairs(dev) do
      for _, bucket in ipairs(DEV_BUCKETS) do
        local held
        if sets[bucket] then
          held = sets[bucket][id] ~= nil
        elseif bucket == "harvested" then
          held = built.harvested[id] ~= nil
        else
          held = inBucket(built[bucket], id)
        end
        if held then
          counts[bucket] = counts[bucket] + 1
        end
      end
    end
  end
  devInBuckets = { from = items, counts = counts }
  return counts
end

-- Meta.diffCounts with every flagged item taken out of the buckets it sits in (brief DV1).
local function devAdjustedCounts(meta)
  local taken = devBucketCounts()
  local any = false
  for _, count in pairs(taken) do
    if count > 0 then
      any = true
    end
  end
  local items = meta.diffCounts.items
  if not any or type(items) ~= "table" then
    return meta.diffCounts
  end
  local out = {}
  for kind, entry in pairs(meta.diffCounts) do
    out[kind] = entry
  end
  local adjusted = {}
  for bucket, value in pairs(items) do
    adjusted[bucket] = value
  end
  for bucket, count in pairs(taken) do
    local value = tonumber(adjusted[bucket])
    if value then
      adjusted[bucket] = math.max(0, value - count)
    end
  end
  out.items = adjusted
  return out
end

-- Brief C1: the counts with changedMinor folded into changed while the setting includes minor
-- changes, so changed is always the number of ids that wear the mark. changedMinor stays as the
-- pipeline counted it. A copy of any kind it touches, the table itself otherwise.
local function foldMinor(counts)
  if not Diff.IncludeMinor() then
    return counts
  end
  local out = {}
  for kind, entry in pairs(counts) do
    local minor = type(entry) == "table" and tonumber(entry.changedMinor) or nil
    if minor and minor > 0 then
      local copy = {}
      for bucket, value in pairs(entry) do
        copy[bucket] = value
      end
      copy.changed = (tonumber(entry.changed) or 0) + minor
      out[kind] = copy
    else
      out[kind] = entry
    end
  end
  return out
end

-- The diff counts a player is shown: Meta.diffCounts with every flagged item taken out of the
-- buckets it sits in (brief DV1), and the minor changes counted as the setting says (brief C1).
-- A copy when anything was taken out or folded in, the Meta table itself otherwise.
function Diff.Counts()
  local meta = Data.Meta
  if meta and meta.diffCounts then
    return foldMinor(devAdjustedCounts(meta))
  end
  local zeros = {}
  for _, kind in ipairs(Diff.KINDS) do
    -- Every bucket the pipeline counts, so a build with no Diff module reads the same shape as
    -- one with an empty diff rather than a shorter table.
    zeros[kind] = {
      new = 0,
      changed = 0,
      changedMinor = 0,
      removed = 0,
      hidden = 0,
      discovered = 0,
      newUndiscovered = 0,
      sod = 0,
      harvested = 0,
      renumbered = 0,
    }
  end
  return zeros
end

function Diff.IsEmpty()
  local counts = Diff.Counts()
  for _, kind in ipairs(Diff.KINDS) do
    local entry = counts[kind]
    if entry then
      -- changedMinor is inside changed while it counts (Diff.Counts), and nothing while it does not.
      for bucket, value in pairs(entry) do
        if bucket ~= "changedMinor" and (tonumber(value) or 0) > 0 then
          return false
        end
      end
    end
  end
  return true
end

-- The line under the tabs that says what New and Changed currently mean.
function Diff.Caption()
  local diff = Data:GetDiff()
  local meta = Data.Meta
  local baseline = (diff and diff.baseline) or (meta and meta.baseline)
  local build = (diff and diff.build) or (meta and meta.build)
  if baseline and build and baseline ~= build then
    return L["Compared with Classic Era"]
  end
  return L["No comparison build loaded"]
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

-- A unix time as the player's short date: the client's own FormatShortDate (Blizzard_SharedXML
-- TimeUtil.lua on the forever branch of the wow-ui-source mirror, which reads SHORTDATE or
-- SHORTDATE_EU by locale), fed the local day, month and year. With no client, or a client that
-- will not answer, the date is written year first, which no reader can take the wrong way round.
function Diff.ShortDate(at)
  local seconds = tonumber(at)
  if not seconds or seconds <= 0 then
    return nil
  end
  local osLib = rawget(_G, "os")
  local dateFn = rawget(_G, "date") or (type(osLib) == "table" and osLib.date) or nil
  if type(dateFn) ~= "function" then
    return nil
  end
  local ok, parts = pcall(dateFn, "*t", seconds)
  if not ok or type(parts) ~= "table" or not parts.year then
    return nil
  end
  local format = rawget(_G, "FormatShortDate")
  if type(format) == "function" then
    local okFormat, text = pcall(format, parts.day, parts.month, parts.year)
    if okFormat and type(text) == "string" and text ~= "" then
      return text
    end
  end
  return string.format("%04d-%02d-%02d", parts.year, parts.month, parts.day)
end

-- The one sentence an item the Discovery Miner found carries: "First found on the beta realm,
-- 25/09/2026". nil where the data dates nothing for it, or the setting has hidden it. The info
-- column's fact row and the tooltip block both draw exactly this.
function Diff.FoundLine(kind, id)
  local text = Diff.ShortDate(Diff.DiscoveredAt(kind, id))
  if not text then
    return nil
  end
  return string.format(L["First found on the beta realm, %s"], text)
end

return Diff
