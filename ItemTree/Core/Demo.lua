-- Brief BQ13: the demo state, one place for every pretend fact about the character, so a QA step
-- can be tested on the owner's one hunter (QA feedback 2026-10-10, item 6: "demo commands to alter
-- what the addon thinks I am"). Memory only: never in ItemTreeDB, ItemTreeCharDB, the collector, the
-- share text or the report; `/itemtree demo off`, a /reload and logging out all end it.
--
-- What it pretends, and where each pretend fact lives:
--   level        Keep.demoLevel (brief K24b's seam, Keep.SetDemo "level"), read by Keep.CachedScore,
--                and through Demo.PlayerLevel by Tooltip.PlayerFacts, API.PlayerContext and Gear.Player
--   professions  UI/PlayerSkills.lua's demo set (brief PR42's seam), read by Keep.PlayerProfessions,
--                Frame.PlayerSkills, the Professions tab and the disenchant rules; "none" is an
--                empty set that is still on, so every profession is gone
--   specs        Demo.state.specs, read by Keep.EnabledSpecs (Demo.Specs) instead of the setting
--   carefulAim   Demo.state.carefulAim, read by Gear.CarefulAimRank (Gear.WeightsFor, the signature)
--   quests       Demo.state.quests[id] = { kind = "log", have, need } | { kind = "done" } |
--                { kind = "off" }, and Demo.state.questsNone (no quest done, none abandoned), read by
--                Keep.QuestCompleted and Keep.QuestAbandoned (Demo.QuestCompleted), Demo.QuestLog
--   pet          Demo.state.pet = { family, eats = { [itemId] = true } } (brief ST5): a pet of that
--                family out, read by Keep.PetFamily and Keep.PetEats (Demo.PetFamily, Demo.PetEats); the
--                client cannot say what a pretend pet eats, so the command names the foods
--   bags         Demo.state.bags = { sizes = { n, n, n, n }, reagent = { size, profession } } (brief
--                ST5): the pretend equipped bags, every general bag full, the reagent or profession bag
--                empty; a slot may name its bag by item id (`#2101`, brief BQ25c), read by Keep.BagState
--                for the bag rule (Keep.BagFacts), and by Jettison off ItemTreeAPI.demo (its loot card
--                and the free slots)
--   bank         Demo.state.bank = { sizes = { n, ... }, items = { [slot] = itemId } } (brief BG1, QA
--                item 83): the pretend bank, its BOUGHT bank bag slots in order (0 for an empty one,
--                a slot not listed is not bought), read by Keep.BagState (Keep.DemoBank) for the spare
--                bag rule's bank read in place of the bank last seen
--   worn rolls   Demo.state.wornLinks[slot] = an item string with its random suffix (brief ST5), read
--                by Gear.DemoWorn as the worn piece's roll
--   health, mana Demo.state.health and Demo.state.mana (brief ST4, bin B: the pools), read by
--                Consumables.Pools (Demo.Pools) for the restore shares and the bandage rules
--   have         Demo.state.have[itemId] = count, read by Keep.ProfessionHave, Keep.QuestHave,
--                Keep.Carries and Keep.CarriedConsumables (Demo.Have)
--   well fed   Demo.state.wellFed = true, false or "unknown" (brief BQ29, QA item 86): whether the
--                player has the Well Fed buff, read by Keep.FedState (Demo.WellFed) for the buff food
--                Use rule; "unknown" is what combat answers (nothing prompted). nil: the auras answer
--   at           Demo.state.at = { map, x, y } (brief DM1, QA item 134): where the player pretends to
--                stand, read by Nearest.PlayerPosition, TrainerSearch.PlayerPlace and the Map tab's
--                player marker (Demo.At); the character never moves
--   price, money, disenchant  Keep.demoPrice, Keep.demoMoney, Keep.demoDisenchant (brief K24b, K24d)
-- Every change drops the Keep scores and paints the bags and the tooltip again (Demo.Apply), and
-- the API's public table carries the state (ItemTreeAPI.demo, Demo.Publish) so Jettison and the self
-- test read it.
--
-- Everything above the client side divider is pure over ItemTree's own tables and runs under busted
-- with no WoW API.
local _, ItemTree = ...

local Demo = {}
ItemTree.Demo = Demo

local EMPTY = {}

-- The new facts. specs: { key, ... } in the order typed (nil: the setting answers); carefulAim:
-- 0 to 5 (nil: the talent read answers); quests and have as above; scenario: the names last applied.
function Demo.Fresh()
  return {
    specs = nil,
    carefulAim = nil,
    quests = {},
    questsNone = false,
    have = {},
    scenario = nil,
    -- Brief BQ14 follow up: the pretend class (a ChrClasses id), side (1 Alliance, 2 Horde) and
    -- race (a ChrRaces id), nil while the character's own answer stands.
    classId = nil,
    faction = nil,
    race = nil,
    -- The pretend worn set, { [slot] = itemId } (nil while the character's own stands).
    worn = nil,
    -- Brief ST4 (bin B): the pretend most health and mana, nil while the character's own stand.
    health = nil,
    mana = nil,
    -- Brief ST5: the pretend pet, bags and worn rolls (above), nil while the character's own stand.
    pet = nil,
    bags = nil,
    -- Brief BG1: the pretend bank's bag slots (above), nil while the bank last seen stands.
    bank = nil,
    wornLinks = nil,
    -- Brief BQ29: the pretend Well Fed buff (true, false or "unknown"), nil while the auras answer.
    wellFed = nil,
    -- Brief DM1: the pretend position { map = uiMap, x, y } (x and y 0 to 100), nil while the
    -- character's own stands. Read by Nearest.PlayerPosition, TrainerSearch.PlayerPlace and the Map
    -- tab's player marker only; the character never moves.
    at = nil,
    -- Brief RB1c (the owner's ruling "A" of 2026-10-17): whether the character has been inside the
    -- gating instances (Naxxramas), true or false, nil while ItemTreeCharDB's own record stands.
    gates = nil,
    -- Brief E2E-1: the pretend uses modifier, true while it reads as held (Demo.SetModifier), nil
    -- while the keys answer. Never published to ItemTreeAPI.demo.
    modifier = nil,
  }
end

Demo.state = Demo.Fresh()

Demo.MAX_LEVEL = 60
Demo.MAX_COUNT = 100000
Demo.CAREFUL_AIM_MAX = 5
-- Brief ST4 (bin B): the most a pretend pool may be.
Demo.MAX_POOL = 100000
Demo.VALUE_KINDS = { "price", "money", "disenchant" }

--------------------------------------------------------------------------------
-- Words. Pure.
--------------------------------------------------------------------------------

local function words(text)
  local out = {}
  for word in tostring(text or ""):gmatch("%S+") do
    out[#out + 1] = word
  end
  return out
end

local function compact(text)
  return (tostring(text or ""):lower():gsub("[^%a]", ""))
end

-- A whole number in lo..hi from a word, or nil. Pure.
local function wholeIn(word, lo, hi)
  local value = tostring(word or ""):match("^%d+$") and tonumber(word) or nil
  if value == nil or value < lo or value > hi then
    return nil
  end
  return value
end

Demo.WholeIn = wholeIn

-- An item or quest id: a positive whole number, or the number in an item link ("item:2589") or a
-- "c:2589" search word. Pure.
function Demo.ParseId(word)
  local text = tostring(word or "")
  local id = text:match("^%d+$") or text:match("^c:(%d+)$") or text:match("item:(%d+)") or text:match("quest:(%d+)")
  id = tonumber(id)
  if id == nil or id <= 0 then
    return nil
  end
  return id
end

-- Short spec words a player types, by key. Pure.
Demo.SPEC_SHORT =
  { bm = "beast_mastery", mm = "marksmanship", sv = "survival", ret = "retribution", prot = "protection" }

-- "survival", "sv", "beast mastery" read against a class's spec keys: the key, or nil. The whole key
-- or label without case or spaces, a short form, or a unique start of three letters or more. Pure.
function Demo.ResolveSpec(word, specs, labels)
  local typed = compact(word)
  if typed == "" then
    return nil
  end
  local short = Demo.SPEC_SHORT[typed]
  local found = nil
  for _, key in ipairs(type(specs) == "table" and specs or EMPTY) do
    if short == key then
      return key
    end
    local names = { compact(key), compact(type(labels) == "table" and labels[key] or "") }
    for _, name in ipairs(names) do
      if name ~= "" and name == typed then
        return key
      end
    end
    for _, name in ipairs(names) do
      if #typed >= 3 and name ~= "" and name:sub(1, #typed) == typed then
        if found ~= nil and found ~= key then
          found = false
        elseif found == nil then
          found = key
        end
        break
      end
    end
  end
  return found or nil
end

-- "/itemtree demo spec ..." read against the class's specs: { kind = "show" | "off" | "set", specs }
-- or { kind = "error", message }. "all" names every spec. Pure.
function Demo.ParseSpecs(rest, specs, labels)
  local list = words(rest)
  if #list == 0 then
    return { kind = "show" }
  end
  if #list == 1 and list[1]:lower() == "off" then
    return { kind = "off" }
  end
  if type(specs) ~= "table" or #specs == 0 then
    return { kind = "error", message = "Your class has no specs to pretend" }
  end
  if #list == 1 and list[1]:lower() == "all" then
    local all = {}
    for index, key in ipairs(specs) do
      all[index] = key
    end
    return { kind = "set", specs = all }
  end
  local seen = {}
  local index = 1
  while index <= #list do
    -- A label may be two words ("beast mastery"): the longer run is tried first.
    local key, used = nil, 1
    if index < #list then
      key = Demo.ResolveSpec(list[index] .. " " .. list[index + 1], specs, labels)
      used = 2
    end
    if not key then
      key, used = Demo.ResolveSpec(list[index], specs, labels), 1
    end
    if not key then
      return {
        kind = "error",
        message = string.format("Unknown spec: %s. Use one of: %s", list[index], table.concat(specs, ", ")),
      }
    end
    seen[key] = true
    index = index + used
  end
  -- In the class's order, so a signature never depends on the typing order.
  local ordered = {}
  for _, key in ipairs(specs) do
    if seen[key] then
      ordered[#ordered + 1] = key
    end
  end
  return { kind = "set", specs = ordered }
end

-- Brief BQ14 follow up (the owner: "We can use demo commands to test the other skipped ones?"): the
-- class, side and race the demo can pretend, by the words a player types. ChrClasses and ChrRaces ids,
-- the ids Keep and Gear read.
Demo.CLASSES = {
  warrior = 1,
  paladin = 2,
  hunter = 3,
  rogue = 4,
  priest = 5,
  shaman = 7,
  mage = 8,
  warlock = 9,
  druid = 11,
}
Demo.FACTIONS = { alliance = 1, horde = 2 }
Demo.FACTION_WORDS = { [1] = "Alliance", [2] = "Horde" }
Demo.RACES = {
  human = 1,
  orc = 2,
  dwarf = 3,
  nightelf = 4,
  undead = 5,
  scourge = 5,
  tauren = 6,
  gnome = 7,
  troll = 8,
}

local function nameOf(map, id)
  for name, value in pairs(map) do
    if value == id and name ~= "scourge" then
      return name
    end
  end
  return tostring(id)
end
Demo.NameOf = nameOf

-- One table's id for a typed word (no case or spaces) or a whole number among its ids. Pure.
local function idFor(map, word)
  local typed = compact(word)
  if map[typed] then
    return map[typed]
  end
  local number = tonumber(word)
  for _, id in pairs(map) do
    if id == number then
      return id
    end
  end
  return nil
end

--- "/itemtree demo class <class> [spec]": { kind = "show" | "off" }, { kind = "set", classId, spec }
--- (spec the word as typed, read against the class's specs by the caller) or { kind = "error" }. Pure.
function Demo.ParseClass(rest)
  local list = words(rest)
  if #list == 0 then
    return { kind = "show" }
  end
  if #list == 1 and list[1]:lower() == "off" then
    return { kind = "off" }
  end
  local classId = idFor(Demo.CLASSES, list[1])
  if not classId then
    return {
      kind = "error",
      message = "Usage: /itemtree demo class <warrior, paladin, hunter, rogue, priest, "
        .. "shaman, mage, warlock, druid> [spec], or off",
    }
  end
  local spec = nil
  if #list > 1 then
    spec = table.concat(list, " ", 2)
  end
  return { kind = "set", classId = classId, spec = spec }
end

--- "/itemtree demo faction <alliance | horde | off>". Pure.
function Demo.ParseFaction(rest)
  local list = words(rest)
  if #list == 0 then
    return { kind = "show" }
  end
  if #list == 1 and list[1]:lower() == "off" then
    return { kind = "off" }
  end
  local faction = #list == 1 and idFor(Demo.FACTIONS, list[1]) or nil
  if not faction then
    return { kind = "error", message = "Usage: /itemtree demo faction <alliance or horde or off>" }
  end
  return { kind = "set", faction = faction }
end

--- "/itemtree demo race <race | off>". Pure.
function Demo.ParseRace(rest)
  local list = words(rest)
  if #list == 0 then
    return { kind = "show" }
  end
  if #list == 1 and list[1]:lower() == "off" then
    return { kind = "off" }
  end
  local race = idFor(Demo.RACES, table.concat(list, ""))
  if not race then
    return {
      kind = "error",
      message = "Usage: /itemtree demo race <human, orc, dwarf, night elf, undead, tauren, " .. "gnome, troll> or off",
    }
  end
  return { kind = "set", race = race }
end

-- "/itemtree demo talent carefulaim <0..5 | off>": { kind = "show" | "off" | "set", rank } or
-- { kind = "error", message }. Pure.
function Demo.ParseTalent(rest)
  local list = words(rest)
  local usage = "Usage: /itemtree demo talent carefulaim <0 to 5 or off>"
  if #list == 0 then
    return { kind = "show" }
  end
  if compact(list[1]) ~= "carefulaim" then
    return { kind = "error", message = usage }
  end
  if #list == 1 then
    return { kind = "show" }
  end
  if #list == 2 and list[2]:lower() == "off" then
    return { kind = "off" }
  end
  local rank = #list == 2 and wholeIn(list[2], 0, Demo.CAREFUL_AIM_MAX) or nil
  if rank == nil then
    return { kind = "error", message = usage }
  end
  return { kind = "set", rank = rank }
end

-- Brief ST4 (bin B): "/itemtree demo health <n | off>" and "/itemtree demo mana <n | off>" (pool is
-- "health" or "mana"): { kind = "show" | "off" | "set", value } or { kind = "error", message }. Pure.
function Demo.ParsePool(pool, rest)
  local list = words(rest)
  local usage = string.format("Usage: /itemtree demo %s <1 to %d or off>", tostring(pool), Demo.MAX_POOL)
  if #list == 0 then
    return { kind = "show" }
  end
  if #list == 1 and list[1]:lower() == "off" then
    return { kind = "off" }
  end
  local value = #list == 1 and wholeIn(list[1], 1, Demo.MAX_POOL) or nil
  if value == nil then
    return { kind = "error", message = usage }
  end
  return { kind = "set", value = value }
end

-- Brief ST5: "/itemtree demo pet <family> [item id ...] | off": { kind = "show" | "off" }, { kind =
-- "set", family (as typed, its first letter upper case), eats ({ [itemId] = true }) } or { kind =
-- "error", message }. The ids are the foods the pretend pet eats (the client answers only for a real
-- pet). Pure.
function Demo.ParsePet(rest)
  local list = words(rest)
  local usage = "Usage: /itemtree demo pet <family> [item id ...], or off"
  if #list == 0 then
    return { kind = "show" }
  end
  if #list == 1 and list[1]:lower() == "off" then
    return { kind = "off" }
  end
  local family = list[1]
  if not family:match("^%a+$") then
    return { kind = "error", message = usage }
  end
  local eats = {}
  for index = 2, #list do
    local id = Demo.ParseId(list[index])
    if not id then
      return { kind = "error", message = usage }
    end
    eats[id] = true
  end
  family = family:sub(1, 1):upper() .. family:sub(2):lower()
  return { kind = "set", family = family, eats = eats }
end

-- Brief ST5: the profession bags `demo bags` names, by the word typed: the word drawn and the
-- client's bag family bit (GetItemFamily's, as Jettison's LootCompare names them); "reagent" is
-- Forever's reagent bag slot, no family.
Demo.BAG_PROFESSIONS = {
  reagent = { word = "Reagent bag", family = 0 },
  skinning = { word = "Skinning bag", family = 33554432 },
  herbalism = { word = "Herb bag", family = 32 },
  herb = { word = "Herb bag", family = 32 },
  mining = { word = "Mining bag", family = 1024 },
  leatherworking = { word = "Leatherworking bag", family = 8 },
  enchanting = { word = "Enchanting bag", family = 64 },
  engineering = { word = "Engineering bag", family = 128 },
}
Demo.MAX_BAG = 36

-- Brief ST5: "/itemtree demo bags <n,n,n,n[,<reagent | profession> n]> | off": the four equipped
-- bags' sizes by bag slot (0 for none), then optionally the reagent or profession bag and its size:
-- { kind = "set", bags = { sizes = { n, n, n, n }, reagent = { size, profession, word, family } } },
-- { kind = "show" | "off" } or { kind = "error", message }. Brief BQ25c: a slot may name the bag in it
-- by item id instead ("#2101", a Light Quiver), so the bag rule knows its kind: its size is 0 here and
-- bags.items[slot] the id (the rule reads the slots off the item's row). Pure.
function Demo.ParseBags(rest)
  local text = tostring(rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local usage = "Usage: /itemtree demo bags <n,n,n,n[,reagent n or skinning n ...]>, or off "
    .. "(a slot may be #itemId, the bag in it)"
  if text == "" then
    return { kind = "show" }
  end
  if text:lower() == "off" then
    return { kind = "off" }
  end
  local parts = {}
  for part in text:gmatch("[^,]+") do
    parts[#parts + 1] = part:gsub("^%s+", ""):gsub("%s+$", "")
  end
  if #parts ~= 4 and #parts ~= 5 then
    return { kind = "error", message = usage }
  end
  local sizes, items = {}, nil
  for index = 1, 4 do
    local id = tostring(parts[index]):match("^#(%d+)$")
    local size = wholeIn(parts[index], 0, Demo.MAX_BAG)
    if id and tonumber(id) > 0 then
      items = items or {}
      items[index] = tonumber(id)
      size = 0
    end
    if size == nil then
      return { kind = "error", message = usage }
    end
    sizes[index] = size
  end
  local reagent = nil
  if parts[5] then
    local word, size = parts[5]:lower():match("^(%a+)%s+(%d+)$")
    local known = word and Demo.BAG_PROFESSIONS[word] or nil
    size = size and wholeIn(size, 1, Demo.MAX_BAG) or nil
    if not known or not size then
      return { kind = "error", message = usage }
    end
    reagent = { size = size, profession = word, word = known.word, family = known.family }
  end
  return { kind = "set", bags = { sizes = sizes, items = items, reagent = reagent } }
end

-- Brief BG1: the most bank bag slots `demo bank` takes (the client's count is checked by Keep).
Demo.MAX_BANK_SLOTS = 9

-- Brief BG1 (QA item 83): "/itemtree demo bank <n,n,...> | off": the bank's BOUGHT bag slots in
-- order, each its bag's size (0 for an empty slot) or "#itemId" for the bag in it; a slot not listed
-- is not bought. { kind = "set", bank = { sizes = { n, ... }, items = { [slot] = itemId } } },
-- { kind = "show" | "off" } or { kind = "error", message }. Pure.
function Demo.ParseBank(rest)
  local text = tostring(rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local usage = "Usage: /itemtree demo bank <n,n,...>, or off (each a bought bank bag slot: its bag's size, "
    .. "0 for empty, or #itemId)"
  if text == "" then
    return { kind = "show" }
  end
  if text:lower() == "off" then
    return { kind = "off" }
  end
  local sizes, items = {}, nil
  for part in text:gmatch("[^,]+") do
    part = part:gsub("^%s+", ""):gsub("%s+$", "")
    local id = part:match("^#(%d+)$")
    local size = wholeIn(part, 0, Demo.MAX_BAG)
    if id and tonumber(id) > 0 then
      items = items or {}
      items[#sizes + 1] = tonumber(id)
      size = 0
    end
    if size == nil or #sizes >= Demo.MAX_BANK_SLOTS then
      return { kind = "error", message = usage }
    end
    sizes[#sizes + 1] = size
  end
  if #sizes == 0 then
    return { kind = "error", message = usage }
  end
  return { kind = "set", bank = { sizes = sizes, items = items } }
end

-- "/itemtree demo quest ...": { kind = "show" }, { kind = "off" } (every quest pretend cleared),
-- { kind = "none" } (no quest done or abandoned), or { kind = "set", questId, quest } where quest is
-- { kind = "log", have, need }, { kind = "done" } or { kind = "off" } (not in the log and not done),
-- or { kind = "error", message }. Pure.
function Demo.ParseQuest(rest)
  local list = words(rest)
  local usage = "Usage: /itemtree demo quest <id> log <have>/<need>, <id> done, <id> off, none or off"
  if #list == 0 then
    return { kind = "show" }
  end
  if #list == 1 and list[1]:lower() == "off" then
    return { kind = "off" }
  end
  if #list == 1 and list[1]:lower() == "none" then
    return { kind = "none" }
  end
  local questId = Demo.ParseId(list[1])
  local word = list[2] and list[2]:lower() or nil
  if not questId or not word then
    return { kind = "error", message = usage }
  end
  if word == "done" and #list == 2 then
    return { kind = "set", questId = questId, quest = { kind = "done" } }
  end
  if word == "off" and #list == 2 then
    return { kind = "set", questId = questId, quest = { kind = "off" } }
  end
  if word == "log" then
    local progress = table.concat(list, " ", 3)
    local have, need = progress:match("^(%d+)%s*/%s*(%d+)$")
    have = wholeIn(have, 0, Demo.MAX_COUNT)
    need = wholeIn(need, 1, Demo.MAX_COUNT)
    if have and need then
      return { kind = "set", questId = questId, quest = { kind = "log", have = have, need = need } }
    end
  end
  return { kind = "error", message = usage }
end

-- "/itemtree demo have <itemId> <count> | <itemId> off | off": { kind = "show" | "off" },
-- { kind = "set", itemId, count } (count nil clears that item) or { kind = "error", message }. Pure.
function Demo.ParseHave(rest)
  local list = words(rest)
  local usage = "Usage: /itemtree demo have <item id> <count>, <item id> off, or off"
  if #list == 0 then
    return { kind = "show" }
  end
  if #list == 1 and list[1]:lower() == "off" then
    return { kind = "off" }
  end
  local itemId = Demo.ParseId(list[1])
  if not itemId or #list ~= 2 then
    return { kind = "error", message = usage }
  end
  if list[2]:lower() == "off" then
    return { kind = "set", itemId = itemId, count = nil }
  end
  local count = wholeIn(list[2], 0, Demo.MAX_COUNT)
  if count == nil then
    return { kind = "error", message = usage }
  end
  return { kind = "set", itemId = itemId, count = count }
end

--------------------------------------------------------------------------------
-- Scenarios: one named preset per QA step that needs a circumstance (qa-steps-2026-10-09.md). Each
-- is applied on a clean slate (Demo.Off first); a scenario never touches a setting. Fields, each
-- optional: level, professions ("none", or { { line, rank } }), specs ({ key, ... }), carefulAim,
-- quests ({ [questId] = "done" | "off" | { have, need } }), questsNone, have ({ [itemId] = count }).
-- The building blocks "level<N>", "noprofessions" and "noquests" layer on after a scenario, so
-- "/itemtree demo scenario level15 noprofessions" is a clean level 15 with no profession.
--------------------------------------------------------------------------------

local HUNTER_SPECS = { "beast_mastery", "marksmanship", "survival" }
local COOKING = 185

Demo.SCENARIOS = {
  i6 = {
    step = "I6",
    text = "level 15, no professions, Riverpaw Gnoll Bounty in the log, 9 Painted Gnoll Armbands, "
      .. "The Collector not taken",
    level = 15,
    professions = "none",
    quests = { [11] = { 0, 8 }, [123] = "off" },
    have = { [782] = 9 },
  },
  i6grey = {
    step = "I6",
    text = "I6 at level 20: The Collector is grey",
    level = 20,
    professions = "none",
    quests = { [11] = { 0, 8 }, [123] = "off" },
    have = { [782] = 9 },
  },
  i7 = {
    step = "I7",
    text = "level 15, no professions, no quest done: Runecloth keeps nothing",
    level = 15,
    professions = "none",
    questsNone = true,
  },
  i9 = {
    step = "I9",
    text = "level 15, Cooking 60 only, Thelsamar Blood Sausages in the log, 60 Bear Meat (past the 51)",
    level = 15,
    professions = { { line = COOKING, rank = 60 } },
    quests = { [418] = { 0, 3 } },
    have = { [3173] = 60 },
  },
  i9low = {
    step = "I9",
    text = "I9 holding 40 Bear Meat (under the route's 48)",
    level = 15,
    professions = { { line = COOKING, rank = 60 } },
    quests = { [418] = { 0, 3 } },
    have = { [3173] = 40 },
  },
  i9enough = {
    step = "I9",
    text = "I9 holding 50 Bear Meat (past 48, not past 51)",
    level = 15,
    professions = { { line = COOKING, rank = 60 } },
    quests = { [418] = { 0, 3 } },
    have = { [3173] = 50 },
  },
  i11 = {
    step = "I11",
    text = "level 15, no professions, Beer Basted Boar Ribs not done",
    level = 15,
    professions = "none",
    quests = { [384] = "off" },
  },
  i11grey = {
    step = "I11",
    text = "I11 at level 17: the quest is grey",
    level = 17,
    professions = "none",
    quests = { [384] = "off" },
  },
  i37 = {
    step = "I37 and I38",
    text = "level 30, all three hunter specs",
    level = 30,
    specs = HUNTER_SPECS,
  },
  i39bm = {
    step = "I39",
    text = "level 30, Beast Mastery only",
    level = 30,
    specs = { "beast_mastery" },
  },
  i39sv = {
    step = "I39",
    text = "level 30, Survival only",
    level = 30,
    specs = { "survival" },
  },
  i43 = {
    step = "I43",
    text = "level 15",
    level = 15,
  },
  i62 = {
    step = "I62 to I64",
    text = "level 15, all three hunter specs, 2 Scroll of Strength",
    level = 15,
    specs = HUNTER_SPECS,
    have = { [954] = 2 },
  },
  i65 = {
    step = "I65",
    text = "level 15, The Collector not taken or done, 1 Gold Pickup Schedule",
    level = 15,
    quests = { [123] = "off" },
    have = { [1307] = 1 },
  },
  i72 = {
    step = "I72",
    text = "level 20, Survival only",
    level = 20,
    specs = { "survival" },
  },
  i73 = {
    step = "I73",
    text = "level 30, Survival only, Careful Aim 0",
    level = 30,
    specs = { "survival" },
    carefulAim = 0,
  },
  i74 = {
    step = "I74",
    text = "level 30, Survival only, Careful Aim 5",
    level = 30,
    specs = { "survival" },
    carefulAim = 5,
  },
}

-- The scenario names, sorted the way a reader counts (i6 before i11). Pure.
function Demo.ScenarioNames()
  local names = {}
  for name in pairs(Demo.SCENARIOS) do
    names[#names + 1] = name
  end
  table.sort(names, function(a, b)
    local na, nb = tonumber(a:match("%d+")) or 0, tonumber(b:match("%d+")) or 0
    if na ~= nb then
      return na < nb
    end
    return a < b
  end)
  return names
end

-- One scenario word as a preset table, or nil: a named scenario, or a building block. Pure.
function Demo.ScenarioFor(word)
  local name = tostring(word or ""):lower()
  if Demo.SCENARIOS[name] then
    return Demo.SCENARIOS[name]
  end
  local level = name:match("^level(%d+)$")
  level = level and wholeIn(level, 1, Demo.MAX_LEVEL) or nil
  if level then
    return { level = level, block = true }
  end
  if name == "noprofessions" then
    return { professions = "none", block = true }
  end
  if name == "noquests" then
    return { questsNone = true, block = true }
  end
  return nil
end

-- "/itemtree demo scenario <name> [<name> ...]": { kind = "list" } or { kind = "set", names,
-- presets } or { kind = "error", message }. Pure.
function Demo.ParseScenario(rest)
  local list = words(rest)
  if #list == 0 then
    return { kind = "list" }
  end
  local presets, names = {}, {}
  for _, word in ipairs(list) do
    local preset = Demo.ScenarioFor(word)
    if not preset then
      return {
        kind = "error",
        message = string.format(
          "Unknown scenario: %s. Use one of: %s, or level<N>, noprofessions, noquests",
          word,
          table.concat(Demo.ScenarioNames(), ", ")
        ),
      }
    end
    presets[#presets + 1] = preset
    names[#names + 1] = word:lower()
  end
  return { kind = "set", names = names, presets = presets }
end

--------------------------------------------------------------------------------
-- The state's readers, the one accessor per fact. Pure over the held state and Keep's demo values.
--------------------------------------------------------------------------------

local function keep()
  local k = ItemTree.Keep
  return type(k) == "table" and k or nil
end

local function playerSkills()
  local ui = ItemTree.UI
  local skills = type(ui) == "table" and ui.PlayerSkills or nil
  return type(skills) == "table" and skills or nil
end

--- The pretend level, or nil while off.
function Demo.Level()
  local k = keep()
  return k and tonumber(k.demoLevel) or nil
end

--- The level every reader uses: the pretend one while it is set, else real (the client's answer).
function Demo.PlayerLevel(real)
  return Demo.Level() or real
end

--- Whether the pretend professions are on (an empty set, "none", counts).
function Demo.ProfessionsOn()
  local skills = playerSkills()
  if skills and type(skills.DemoOn) == "function" then
    local ok, on = pcall(skills.DemoOn)
    return ok and on == true
  end
  return false
end

--- The pretend specs as Keep.EnabledSpecs answers them for a class: on (true while pretended), the
--- set ({ key = true }, nil for every spec of the class) and its signature ("demo:survival"). Specs
--- the class does not have are left out; none left reads as every spec. Brief ST3 (QA item 320, the
--- owner's ruling A): an EMPTY list pretended for a class with specs (the self test's persona with
--- every box unticked, a preset's specs = {}) is no spec ticked: the empty set and "demo:none", gear
--- suggestions off (Keep.GearOff), as the setting answers it.
function Demo.Specs(classId)
  local specs = Demo.state.specs
  if type(specs) ~= "table" then
    return false, nil, nil
  end
  local gear = ItemTree.Gear
  local classSpecs = type(gear) == "table" and type(gear.SPECS) == "table" and gear.SPECS[tonumber(classId) or -1]
    or nil
  if #specs == 0 and type(classSpecs) == "table" and #classSpecs > 0 then
    return true, {}, "demo:none"
  end
  local set, kept = {}, {}
  for _, key in ipairs(specs) do
    local known = type(classSpecs) ~= "table"
    for _, own in ipairs(type(classSpecs) == "table" and classSpecs or EMPTY) do
      if own == key then
        known = true
      end
    end
    if known and not set[key] then
      set[key] = true
      kept[#kept + 1] = key
    end
  end
  if #kept == 0 or (type(classSpecs) == "table" and #kept >= #classSpecs) then
    return true, nil, "demo:all"
  end
  return true, set, "demo:" .. table.concat(kept, ",")
end

--- Brief BQ30 (owner's spot fix, QA item 91): the chat note for the specs named (Gear's keys; nil
--- for every spec of the class) that are off at a level (Gear.SpecOpen: a hunter's Survival below
--- 30), "Survival is off below level 30", or nil where every one counts. The demo spec and demo
--- level lines add it, so a pretend Survival at a pretend 20 says it is off. Pure over Core/Gear.lua.
function Demo.SpecNote(classId, specs, level)
  local gear = ItemTree.Gear
  if type(gear) ~= "table" or type(gear.SpecOpen) ~= "function" or type(gear.SPECS) ~= "table" then
    return nil
  end
  local list = specs
  if type(list) ~= "table" then
    list = gear.SPECS[tonumber(classId) or -1]
  end
  local parts = {}
  for _, key in ipairs(type(list) == "table" and list or EMPTY) do
    if not gear.SpecOpen(classId, key, level) then
      local label = type(gear.SpecLabel) == "function" and gear.SpecLabel(classId, key) or nil
      parts[#parts + 1] = string.format("%s is off below level %d", label or key, gear.SpecFromLevel(classId, key))
    end
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts, "; ")
end

--- Brief BQ14 follow up: the pretend class id, or nil while the character's own stands.
function Demo.ClassId()
  return Demo.state.classId
end

--- The pretend side (1 Alliance, 2 Horde), or nil.
function Demo.Faction()
  return Demo.state.faction
end

--- The pretend side as the client words it ("Alliance", "Horde"), or nil.
function Demo.FactionWord()
  return Demo.FACTION_WORDS[Demo.state.faction or -1]
end

--- The pretend race id, or nil.
function Demo.Race()
  return Demo.state.race
end

--- The pretend worn set, { [slot] = itemId }, or nil while the character's own stands. The same table
--- while it is unchanged (Gear holds its map by it).
function Demo.Worn()
  return Demo.state.worn
end

-- The worn slots by the words a player types, Gear's slot numbers (INVSLOT ids).
Demo.WORN_SLOTS = {
  head = 1,
  neck = 2,
  shoulder = 3,
  shoulders = 3,
  shirt = 4,
  chest = 5,
  waist = 6,
  belt = 6,
  legs = 7,
  feet = 8,
  wrist = 9,
  wrists = 9,
  hands = 10,
  finger = 11,
  finger1 = 11,
  ring = 11,
  ring1 = 11,
  finger2 = 12,
  ring2 = 12,
  trinket = 13,
  trinket1 = 13,
  trinket2 = 14,
  back = 15,
  mainhand = 16,
  offhand = 17,
  ranged = 18,
  tabard = 19,
}

--- "/itemtree demo worn <slot> <itemId | off> | off": { kind = "show" | "off" }, { kind = "set", slot,
--- itemId } (itemId nil clears the slot) or { kind = "error" }. A slot is a word (finger, ring2,
--- mainhand) or its number 1 to 19. Pure.
-- Brief ST5: the item string a worn piece's roll is read from: "<id>:<suffix>" (a random suffix id,
-- the bonus list a Forever link carries: "9775:12722") as "item:9775::::::::::::1:12722", or the
-- item string inside a shift clicked link; nil for a bare id. Pure.
function Demo.WornLink(text)
  text = tostring(text or "")
  local id, suffix = text:match("^(%d+):(%d+)$")
  if id then
    return "item:" .. id .. string.rep(":", 12) .. "1:" .. suffix
  end
  local item = text:match("(item:[%-%d:]+)")
  if item and item:find(":%d+:%d+") then
    return item
  end
  return nil
end

function Demo.ParseWorn(rest)
  local list = words(rest)
  local usage = "Usage: /itemtree demo worn <slot> <item id, id:suffix, an item link or off>, or off"
  if #list == 0 then
    return { kind = "show" }
  end
  if #list == 1 and list[1]:lower() == "off" then
    return { kind = "off" }
  end
  -- Brief ST5: a shift clicked link carries spaces in its name: the rest after the slot is one word.
  if #list > 2 and tostring(rest):find("|Hitem:", 1, true) then
    local first = list[1]
    list = { first, (tostring(rest):gsub("^%s*%S+%s*", "")) }
  end
  if #list ~= 2 then
    return { kind = "error", message = usage }
  end
  local word = list[1]:lower()
  local slot = Demo.WORN_SLOTS[word] or wholeIn(word, 1, 19) or Demo.WORN_SLOTS[compact(word)]
  if not slot then
    return { kind = "error", message = usage }
  end
  if list[2]:lower() == "off" then
    return { kind = "set", slot = slot, itemId = nil }
  end
  local link = Demo.WornLink(list[2])
  local itemId = Demo.ParseId(list[2]) or (link and tonumber(link:match("^item:(%d+)")))
  if not itemId then
    return { kind = "error", message = usage }
  end
  return { kind = "set", slot = slot, itemId = itemId, link = link }
end

--- The pretend Careful Aim rank (0 to 5), or nil while off.
function Demo.CarefulAim()
  return Demo.state.carefulAim
end

--- Brief ST4 (bin B): the pools with the pretend ones over them: real is the client's { health,
--- mana } (Consumables.Pools), a copy answered with Demo.state.health and mana where set. Pure.
function Demo.Pools(real)
  local out = {}
  for key, value in pairs(type(real) == "table" and real or EMPTY) do
    out[key] = value
  end
  if Demo.state.health ~= nil then
    out.health = Demo.state.health
  end
  if Demo.state.mana ~= nil then
    out.mana = Demo.state.mana
  end
  return out
end

--- Brief ST5: the pretend pet's family, or nil while none is pretended.
function Demo.PetFamily()
  local pet = Demo.state.pet
  return type(pet) == "table" and pet.family or nil
end

--- Brief ST6 (bin E2): whether the demo speaks for the pet at all: a pretend pet, or the self test's
--- "no pet out" ({ none = true }), so the character's own pet is never read while it does.
function Demo.PetPretended()
  return type(Demo.state.pet) == "table"
end

--- Brief ST5: whether the pretend pet eats an item (the foods the command named): true or false, or
--- nil while no pet is pretended (the client answers).
function Demo.PetEats(itemId)
  local pet = Demo.state.pet
  if type(pet) ~= "table" then
    return nil
  end
  return type(pet.eats) == "table" and pet.eats[tonumber(itemId)] == true or false
end

--- Brief BQ29: the pretend Well Fed buff, true, false or "unknown", or nil while the auras answer.
function Demo.WellFed()
  return Demo.state.wellFed
end

--- Brief BQ29: "/itemtree demo wellfed on | off | unknown | clear": { kind = "show" } (bare), { kind =
--- "set", value } (true, false, "unknown", or nil for clear) or { kind = "error", message }. Pure.
function Demo.ParseWellFed(rest)
  local list = words(rest)
  if #list == 0 then
    return { kind = "show" }
  end
  local word = #list == 1 and list[1]:lower() or ""
  if word == "on" or word == "yes" then
    return { kind = "set", value = true }
  elseif word == "off" or word == "no" then
    return { kind = "set", value = false }
  elseif word == "unknown" then
    return { kind = "set", value = "unknown" }
  elseif word == "clear" then
    return { kind = "set", value = nil }
  end
  return { kind = "error", message = "Usage: /itemtree demo wellfed on, off, unknown or clear" }
end

--- Brief RB1c: the pretend answer to "has this character been inside the gating instances"
--- (Core/QuestFlags.lua GateOpen reads it first): true, false or nil while the character's own record
--- stands.
function Demo.GatesOpen()
  return Demo.state.gates
end

--- Brief RB1c: "/itemtree demo naxx on | off | clear": { kind = "show" } (bare), { kind = "set", value }
--- (true, false, or nil for clear) or { kind = "error", message }. Pure.
function Demo.ParseGates(rest)
  local list = words(rest)
  if #list == 0 then
    return { kind = "show" }
  end
  local word = #list == 1 and list[1]:lower() or ""
  if word == "on" or word == "yes" then
    return { kind = "set", value = true }
  elseif word == "off" or word == "no" then
    return { kind = "set", value = false }
  elseif word == "clear" then
    return { kind = "set", value = nil }
  end
  return { kind = "error", message = "Usage: /itemtree demo naxx on, off or clear" }
end

--- Brief RB1c: the words for the pretend gate answer.
function Demo.GatesWords(value)
  if value == true then
    return "on (pretend you have been inside Naxxramas)"
  elseif value == false then
    return "off (pretend you have never been inside Naxxramas)"
  end
  return "your own record"
end

--- Brief DM1: the pretend position { map, x, y } (x and y 0 to 100), or nil while the character's
--- own stands.
function Demo.At()
  return Demo.state.at
end

Demo.AT_USAGE = "Usage: /itemtree demo at <uiMap id or zone name> <x> <y>, or off"

-- A map percent (0 to 100, a decimal allowed) from a word, or nil. Pure.
local function percentIn(word)
  local text = tostring(word or "")
  if not text:match("^%d+%.?%d*$") then
    return nil
  end
  local value = tonumber(text)
  if value == nil or value < 0 or value > 100 then
    return nil
  end
  return value
end

--- Brief DM1: "/itemtree demo at <uiMap id | zone name> <x> <y> | off": { kind = "show" } (bare),
--- { kind = "off" }, { kind = "set", at = { map, x, y }, name } or { kind = "error", message }. x and
--- y are map percent, 0 to 100. A zone name (every word before the two numbers, "Stormwind City")
--- goes through resolve(name), which answers its uiMap or nil; with no resolve only an id is read.
--- Pure over resolve.
function Demo.ParseAt(rest, resolve)
  local list = words(rest)
  if #list == 0 then
    return { kind = "show" }
  end
  if #list == 1 and list[1]:lower() == "off" then
    return { kind = "off" }
  end
  if #list < 3 then
    return { kind = "error", message = Demo.AT_USAGE }
  end
  local x, y = percentIn(list[#list - 1]), percentIn(list[#list])
  if not x or not y then
    return { kind = "error", message = Demo.AT_USAGE }
  end
  local head = {}
  for index = 1, #list - 2 do
    head[#head + 1] = list[index]
  end
  local map, name = nil, nil
  if #head == 1 and head[1]:match("^%d+$") then
    map = tonumber(head[1])
  else
    name = table.concat(head, " ")
    if type(resolve) == "function" then
      local ok, answer = pcall(resolve, name)
      map = ok and tonumber(answer) or nil
    end
    if not map then
      return { kind = "error", message = "Demo at: no zone called " .. name .. ". " .. Demo.AT_USAGE }
    end
  end
  if not map or map <= 0 or map ~= math.floor(map) then
    return { kind = "error", message = Demo.AT_USAGE }
  end
  return { kind = "set", at = { map = map, x = x, y = y }, name = name }
end

--- Brief DM1: the show line for a pretend position, "Demo at: Riverglades (2548) 60, 45", the map
--- named by mapName(map) where it can be. Pure over mapName.
function Demo.AtWords(at, mapName)
  if type(at) ~= "table" then
    return "Demo at: off (your own position)"
  end
  local name = nil
  if type(mapName) == "function" then
    local ok, answer = pcall(mapName, at.map)
    name = ok and type(answer) == "string" and answer ~= "" and answer or nil
  end
  local where = name and string.format("%s (%d)", name, at.map) or string.format("map %d", at.map)
  local function percent(value)
    if value == math.floor(value) then
      return string.format("%d", value)
    end
    return string.format("%.1f", value)
  end
  return string.format("Demo at: %s %s, %s", where, percent(at.x), percent(at.y))
end

--- Brief BQ29: the words for the pretend Well Fed state. Pure.
function Demo.WellFedWords(value)
  if value == true then
    return "on"
  elseif value == false then
    return "off"
  elseif value == "unknown" then
    return "unknown (as in combat)"
  end
  return "your own buffs"
end

--- Brief ST5: the pretend bags ({ sizes, reagent }), or nil.
function Demo.Bags()
  return Demo.state.bags
end

--- Brief BG1: the pretend bank ({ sizes, items }, Demo.ParseBank's shape), or nil.
function Demo.Bank()
  return Demo.state.bank
end

--- Brief ST5: the pretend worn rolls, { [slot] = item string }, or nil.
function Demo.WornLinks()
  return Demo.state.wornLinks
end

--- One quest's pretend state ({ kind = "log" | "done" | "off", have, need }), or nil.
function Demo.Quest(questId)
  local id = tonumber(questId)
  return id and Demo.state.quests[id] or nil
end

--- Whether the demo says a quest is completed: true (pretended done), false (pretended in the log,
--- absent, or every quest not done), or nil where the demo says nothing and the client answers.
function Demo.QuestCompleted(questId)
  local quest = Demo.Quest(questId)
  if quest then
    return quest.kind == "done"
  end
  if Demo.state.questsNone then
    return false
  end
  return nil
end

--- Whether the demo speaks for a quest at all (Keep.QuestAbandoned answers false for such a quest).
function Demo.QuestPretended(questId)
  return Demo.Quest(questId) ~= nil or Demo.state.questsNone == true
end

--- A pretend quest in the log: have, need; or nil, nil.
function Demo.QuestLog(questId)
  local quest = Demo.Quest(questId)
  if quest and quest.kind == "log" then
    return quest.have, quest.need
  end
  return nil, nil
end

--- Brief BQ14 follow up (the owner's step I9): the client's answer about one quest (UI/InfoPanel.lua
--- ReadQuest's { onQuest, completed, objectives, ... }) with the demo state over it, a copy, or the
--- answer itself where the demo says nothing of the quest. A quest pretended in the log is on the
--- quest with its progress as the one objective; done is completed; off (and every quest while
--- "none" is pretended) is neither. Pure.
function Demo.LiveQuest(questId, live)
  local quest = Demo.Quest(questId)
  if not quest and not Demo.state.questsNone then
    return live
  end
  local out = {}
  for key, value in pairs(type(live) == "table" and live or EMPTY) do
    out[key] = value
  end
  out.demo = true
  if quest and quest.kind == "log" then
    local have, need = tonumber(quest.have) or 0, tonumber(quest.need) or 0
    out.onQuest = true
    out.completed = false
    out.objectives =
      { { text = string.format("%d/%d (demo)", have, need), have = have, need = need, done = have >= need } }
  elseif quest and quest.kind == "done" then
    out.onQuest = false
    out.completed = true
    out.objectives = nil
  else
    out.onQuest = false
    out.completed = false
    out.objectives = nil
  end
  return out
end

--- The pretend held count of an item (bags and bank, as if carried), or nil while not pretended.
function Demo.Have(itemId)
  local id = tonumber(itemId)
  return id and Demo.state.have[id] or nil
end

--- The pretend held items, { [itemId] = count }, a copy.
function Demo.HaveList()
  local out = {}
  for id, count in pairs(Demo.state.have) do
    out[id] = count
  end
  return out
end

--- Whether any demo state is on: the facts here, the level, the professions or a Keep value.
--- Brief E2E-1: forApi leaves the pretend uses modifier out, for the public view (Demo.Publish).
function Demo.On(forApi)
  local state = Demo.state
  if state.modifier ~= nil and not forApi then
    return true
  end
  if
    state.specs ~= nil
    or state.carefulAim ~= nil
    or state.questsNone
    or next(state.quests)
    or next(state.have)
    or state.classId ~= nil
    or state.faction ~= nil
    or state.race ~= nil
    or state.worn ~= nil
    or state.pet ~= nil
    or state.bags ~= nil
    or state.bank ~= nil
    or state.health ~= nil
    or state.mana ~= nil
    or state.wellFed ~= nil
    or state.at ~= nil
    or state.gates ~= nil
  then
    return true
  end
  if Demo.Level() or Demo.ProfessionsOn() then
    return true
  end
  local k = keep()
  for _, kind in ipairs(Demo.VALUE_KINDS) do
    local field = k and type(k.DEMO_KINDS) == "table" and k.DEMO_KINDS[kind] or nil
    if field and k[field] ~= nil then
      return true
    end
  end
  return false
end

-- The pretend professions' entries, { { line, name, rank } }, {} while off or none.
local function professionEntries()
  local skills = playerSkills()
  if skills and type(skills.DemoEntries) == "function" then
    local ok, entries = pcall(skills.DemoEntries)
    if ok and type(entries) == "table" then
      return entries
    end
  end
  return {}
end

local function moneyWords(value)
  local k = keep()
  if k and type(k.MoneyWords) == "function" then
    local ok, text = pcall(k.MoneyWords, value)
    if ok and type(text) == "string" then
      return text
    end
  end
  return tostring(value)
end

local function sortedKeys(map)
  local keys = {}
  for key in pairs(map) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

--- An item named for a chat line from ItemTree's own tables: "Bear Meat (3173)", or the id alone.
--- Never a client item query.
function Demo.ItemName(itemId)
  local d = ItemTree.Data
  if type(d) == "table" and type(d.GetItem) == "function" then
    local ok, row = pcall(d.GetItem, d, tonumber(itemId))
    if ok and type(row) == "table" and type(row.n) == "string" and row.n ~= "" then
      return string.format("%s (%d)", row.n, itemId)
    end
  end
  return tostring(itemId)
end

--- Brief BQ25c: an equipped pretend bag's slots and family bit (Keep.BagKind over its row), or nil
--- where the data does not know it as a bag.
function Demo.BagFacts(itemId)
  local d, rules = ItemTree.Data, ItemTree.Keep
  if not itemId or type(d) ~= "table" or type(d.GetItem) ~= "function" or type(rules) ~= "table" then
    return nil
  end
  local ok, row = pcall(d.GetItem, d, tonumber(itemId))
  if not ok or type(row) ~= "table" or type(rules.BagKind) ~= "function" then
    return nil
  end
  local kind, family = rules.BagKind(row)
  local size = tonumber(row.cs)
  if kind == nil or size == nil then
    return nil
  end
  return size, family
end

--- A quest named the same way (API.QuestTitle, ItemTree's own data): "The Collector (123)".
function Demo.QuestName(questId)
  local api = ItemTree.API
  if type(api) == "table" and type(api.QuestTitle) == "function" then
    local ok, title = pcall(api.QuestTitle, tonumber(questId))
    if ok and type(title) == "string" and title ~= "" then
      return string.format("%s (%d)", title, questId)
    end
  end
  return tostring(questId)
end

--- One quest's pretend words: "log 0/8", "done", "off". Pure.
function Demo.QuestWords(quest)
  if type(quest) ~= "table" then
    return "off"
  end
  if quest.kind == "log" then
    return string.format("log %d/%d", tonumber(quest.have) or 0, tonumber(quest.need) or 0)
  end
  return tostring(quest.kind)
end

--- Every line `/itemtree demo show` prints, in order: the state on or off, then one line per fact
--- that is pretended. Names no character, realm or account.
function Demo.ShowLines()
  local lines = {}
  local state = Demo.state
  if not Demo.On() then
    lines[1] = "Demo: off, everything is your own character"
    return lines
  end
  lines[1] = "Demo: on (/itemtree demo off restores everything)"
  if state.scenario then
    lines[#lines + 1] = "Demo scenario: " .. state.scenario
  end
  if Demo.Level() then
    lines[#lines + 1] = string.format("Demo level: %d", Demo.Level())
  end
  if Demo.ProfessionsOn() then
    local parts = {}
    for _, entry in ipairs(professionEntries()) do
      parts[#parts + 1] = string.format("%s %d", tostring(entry.name), tonumber(entry.rank) or 0)
    end
    lines[#lines + 1] = "Demo professions: " .. (#parts > 0 and table.concat(parts, ", ") or "none")
  end
  if state.classId then
    lines[#lines + 1] = "Demo class: " .. nameOf(Demo.CLASSES, state.classId)
  end
  if state.faction then
    lines[#lines + 1] = "Demo faction: " .. tostring(Demo.FactionWord())
  end
  if state.race then
    lines[#lines + 1] = "Demo race: " .. nameOf(Demo.RACES, state.race)
  end
  if state.worn then
    local parts = {}
    for _, slot in ipairs(sortedKeys(state.worn)) do
      parts[#parts + 1] = string.format("slot %d %s", slot, Demo.ItemName(state.worn[slot]))
    end
    lines[#lines + 1] = "Demo worn: " .. (#parts > 0 and table.concat(parts, ", ") or "nothing")
  end
  if state.specs then
    lines[#lines + 1] = "Demo specs: " .. table.concat(state.specs, ", ")
  end
  if state.carefulAim then
    lines[#lines + 1] = string.format("Demo Careful Aim: %d", state.carefulAim)
  end
  if state.health then
    lines[#lines + 1] = string.format("Demo health: %d", state.health)
  end
  for _, line in ipairs(Demo.ST5Lines(state)) do
    lines[#lines + 1] = line
  end
  if state.mana then
    lines[#lines + 1] = string.format("Demo mana: %d", state.mana)
  end
  if state.wellFed ~= nil then
    lines[#lines + 1] = "Demo well fed: " .. Demo.WellFedWords(state.wellFed)
  end
  if state.at then
    lines[#lines + 1] = Demo.AtWords(state.at, Demo.MapName)
  end
  if state.gates ~= nil then
    lines[#lines + 1] = "Demo naxx: " .. Demo.GatesWords(state.gates)
  end
  if state.modifier then
    lines[#lines + 1] = "Demo modifier: held (the folded uses read as with the modifier down)"
  end
  if state.questsNone then
    lines[#lines + 1] = "Demo quests: none done, none abandoned"
  end
  for _, questId in ipairs(sortedKeys(state.quests)) do
    lines[#lines + 1] =
      string.format("Demo quest %s: %s", Demo.QuestName(questId), Demo.QuestWords(state.quests[questId]))
  end
  for _, itemId in ipairs(sortedKeys(state.have)) do
    lines[#lines + 1] = string.format("Demo have %s: %d", Demo.ItemName(itemId), state.have[itemId])
  end
  local k = keep()
  for _, kind in ipairs(Demo.VALUE_KINDS) do
    local field = k and type(k.DEMO_KINDS) == "table" and k.DEMO_KINDS[kind] or nil
    if field and k[field] ~= nil then
      lines[#lines + 1] = string.format("Demo %s: %s", kind, moneyWords(k[field]))
    end
  end
  return lines
end

--------------------------------------------------------------------------------
-- Changing it. Each setter changes the one fact and calls Demo.Apply, which hands the change to
-- the readers through their owners' public calls. Pure over ItemTree's own tables.
--------------------------------------------------------------------------------

local function call(owner, name, ...)
  if type(owner) == "table" and type(owner[name]) == "function" then
    return pcall(owner[name], ...)
  end
  return false
end

-- Brief JET13 (161): every change ends here, so another addon hears it once the view is rewritten
-- (ItemTreeAPI.RegisterChangeCallback; Core/API.lua tells the frame's changes once, the next frame).
local function published(view)
  call(ItemTree.API, "NotifyChange", "demo")
  return view
end

--- The public table's view (ItemTreeAPI.demo), rewritten in place so a reader holding it sees the
--- change: { on = false } while off; while on also level, professions ({ { line, rank } }, nil
--- while not pretended; empty for none), specs, carefulAim, quests ({ [id] = { kind, have, need } }),
--- questsNone, have ({ [id] = count }).
function Demo.Publish()
  local api = ItemTree.API
  local view = type(api) == "table" and type(api.public) == "table" and api.public.demo or nil
  if type(view) ~= "table" then
    return nil
  end
  for key in pairs(view) do
    view[key] = nil
  end
  local state = Demo.state
  -- Brief E2E-1: the pretend uses modifier is a tooltip knob only; Jettison reads no modifier.
  view.on = Demo.On(true)
  if not view.on then
    return published(view)
  end
  view.level = Demo.Level()
  if Demo.ProfessionsOn() then
    local list = {}
    for index, entry in ipairs(professionEntries()) do
      list[index] = { line = entry.line, rank = entry.rank }
    end
    view.professions = list
  end
  if state.specs then
    local specs = {}
    for index, key in ipairs(state.specs) do
      specs[index] = key
    end
    view.specs = specs
  end
  view.carefulAim = state.carefulAim
  -- Brief ST5: the pet (its family and the foods it eats, as a list), the bags and the worn rolls.
  view.pet = nil
  if type(state.pet) == "table" then
    view.pet = { family = state.pet.family, eats = {} }
    for id in pairs(state.pet.eats or EMPTY) do
      view.pet.eats[#view.pet.eats + 1] = id
    end
    table.sort(view.pet.eats)
  end
  view.bags = nil
  if type(state.bags) == "table" then
    view.bags = { sizes = {}, reagent = nil }
    for index, size in ipairs(state.bags.sizes or EMPTY) do
      view.bags.sizes[index] = size
    end
    -- Brief BQ25c: a slot named by its bag's item id carries the id, the bag's slots and its family
    -- bit (a quiver 1, an ammo pouch 2, a soul bag 4), so Jettison reads the same equipped bags.
    if type(state.bags.items) == "table" then
      view.bags.items, view.bags.families = {}, {}
      for index = 1, 4 do
        local id = tonumber(state.bags.items[index])
        local size, family = Demo.BagFacts(id)
        if id and size then
          view.bags.items[index] = id
          view.bags.families[index] = family
          view.bags.sizes[index] = size
        end
      end
    end
    local reagent = state.bags.reagent
    if type(reagent) == "table" then
      view.bags.reagent =
        { size = reagent.size, profession = reagent.profession, word = reagent.word, family = reagent.family }
    end
  end
  view.wornLinks = nil
  if type(state.wornLinks) == "table" then
    view.wornLinks = {}
    for slot, link in pairs(state.wornLinks) do
      view.wornLinks[slot] = link
    end
  end
  view.health = state.health
  view.mana = state.mana
  -- Brief BQ29: the pretend Well Fed buff (true, false or "unknown"), nil while the auras answer.
  view.wellFed = state.wellFed
  view.classId = state.classId
  view.faction = state.faction
  view.race = state.race
  if state.worn then
    view.worn = {}
    for slot, id in pairs(state.worn) do
      view.worn[slot] = id
    end
  end
  view.questsNone = state.questsNone == true
  view.quests = {}
  for questId, quest in pairs(state.quests) do
    view.quests[questId] = { kind = quest.kind, have = quest.have, need = quest.need }
  end
  view.have = Demo.HaveList()
  return published(view)
end

--- After any change: Keep's held answers (specs, scores), the worn signature that carries the
--- Careful Aim rank, the API's cache, then the bags and the tooltip painted again, and the public
--- view rewritten. Answers Demo.On().
function Demo.Apply()
  local k = keep()
  if k then
    k.enabledSpecsHeld = nil
    -- Brief BQ14 follow up: the held class read, so a pretend class (or its end) is read again.
    k.playerClass = nil
    -- QA item 152 (2026-10-14): the held carried bag walk and the held bag read it is joined into,
    -- so pretend held bags (`demo have 4240 14`) reach the spare bag cap's pool (Keep.CarriedBags).
    k.carriedBags = nil
    k.bagState = nil
    call(k, "DropScores")
  end
  -- And the bag overlay's held level and side (UI/Overlay.lua Overlay.PlayerFacts).
  local overlay = type(ItemTree.UI) == "table" and ItemTree.UI.Overlay or nil
  if type(overlay) == "table" then
    overlay.player = nil
  end
  local gear = ItemTree.Gear
  if type(gear) == "table" then
    gear.wornSignature = nil
  end
  call(ItemTree.API, "Reset")
  -- The quest pages' held client answers, so a pretend quest (or its end) is read over them again.
  call(ItemTree.ViewModel, "DropQuestLive")
  call(ItemTree.ProfessionsModel, "ResetState")
  call(k, "Repaint")
  Demo.Publish()
  return Demo.On()
end

--- The pretend level (a whole number 1 to 60, nil for off), through Keep.SetDemo.
function Demo.SetLevel(level)
  local k = keep()
  if not k or type(k.SetDemo) ~= "function" then
    return false
  end
  k.SetDemo("level", level)
  Demo.Publish()
  return true
end

--- One Keep value ("price", "money", "disenchant"), through Keep.SetDemo.
function Demo.SetValue(kind, value)
  local k = keep()
  if not k or type(k.SetDemo) ~= "function" then
    return false
  end
  local done = k.SetDemo(kind, value)
  Demo.Publish()
  return done
end

--- The pretend professions: entries { { line, name, rank } }, "none" (every profession gone), or
--- nil (off), through UI/PlayerSkills.lua's seam and its ApplyDemo.
function Demo.SetProfessions(entries)
  local skills = playerSkills()
  if not skills or type(skills.SetDemo) ~= "function" then
    return false
  end
  if entries == "none" then
    skills.SetDemo({}, true)
  else
    skills.SetDemo(entries)
  end
  call(skills, "ApplyDemo")
  Demo.Publish()
  return true
end

function Demo.SetSpecs(specs)
  if type(specs) == "table" and #specs > 0 then
    local copy = {}
    for index, key in ipairs(specs) do
      copy[index] = key
    end
    Demo.state.specs = copy
  else
    Demo.state.specs = nil
  end
  return Demo.Apply()
end

--- The pretend class (an id, nil for off), with the specs pretended where specs is a list.
function Demo.SetClass(classId, specs)
  Demo.state.classId = tonumber(classId)
  if type(specs) == "table" then
    Demo.state.specs = specs
  elseif classId == nil then
    Demo.state.specs = nil
  end
  local k = keep()
  if k then
    k.playerClass = nil
  end
  return Demo.Apply()
end

--- The pretend side (1 or 2, nil for off).
function Demo.SetFaction(faction)
  Demo.state.faction = tonumber(faction)
  return Demo.Apply()
end

--- One worn slot's pretend item (nil clears the slot), or every slot off with slot nil. A pretend set
--- with no slot left is still on (nothing worn); Demo.SetWorn(nil) ends it.
function Demo.SetWorn(slot, itemId, link)
  if slot == nil then
    Demo.state.worn = nil
    Demo.state.wornLinks = nil
  else
    local worn = {}
    for held, id in pairs(Demo.state.worn or EMPTY) do
      worn[held] = id
    end
    worn[tonumber(slot)] = tonumber(itemId)
    Demo.state.worn = worn
    -- Brief ST5: the worn piece's roll (an item string with its suffix), or none.
    local links = {}
    for held, text in pairs(Demo.state.wornLinks or EMPTY) do
      links[held] = text
    end
    links[tonumber(slot)] = itemId ~= nil and type(link) == "string" and link or nil
    Demo.state.wornLinks = next(links) ~= nil and links or nil
  end
  return Demo.Apply()
end

--- Brief ST5: the pretend pet ({ family, eats }), or nil for off.
function Demo.SetPet(family, eats)
  if type(family) ~= "string" or family == "" then
    Demo.state.pet = nil
  else
    local set = {}
    for id, on in pairs(type(eats) == "table" and eats or EMPTY) do
      if on and tonumber(id) then
        set[tonumber(id)] = true
      end
    end
    Demo.state.pet = { family = family, eats = set }
  end
  return Demo.Apply()
end

--- Brief BQ29: the pretend Well Fed buff (true, false or "unknown"), or nil for the auras.
function Demo.SetWellFed(value)
  if value ~= true and value ~= false and value ~= "unknown" then
    value = nil
  end
  Demo.state.wellFed = value
  return Demo.Apply()
end

--- Brief RB1c: the pretend gate answer (true, false, or nil for the character's own record). Memory
--- only; demo off and a /reload end it.
function Demo.SetGates(value)
  if value ~= true and value ~= false then
    value = nil
  end
  Demo.state.gates = value
  return Demo.Apply()
end

--- Brief E2E-1 (the e2e plan's addition 5): the pretend uses modifier, held (true) or nil for the keys'
--- own answer. UI/Tooltip.lua Tooltip.UsesHeld asks it before the key, so the folded uses unfold as
--- with Ctrl down, and the demo marker line says so on every tooltip. Memory only; demo off and a
--- /reload end it. It stays out of ItemTreeAPI.demo (Demo.Publish asks Demo.On(true)), so Jettison
--- hears nothing of it. The developer only e2e run is the caller.
function Demo.SetModifier(held)
  Demo.state.modifier = held == true or nil
  return Demo.Apply()
end

--- Brief E2E-1: whether the pretend uses modifier reads as held.
function Demo.ModifierHeld()
  return Demo.state.modifier == true
end

--- Brief DM1: the pretend position ({ map, x, y }, Demo.ParseAt's at), or nil for off. Memory only.
function Demo.SetAt(at)
  if type(at) == "table" and type(at.map) == "number" and tonumber(at.x) and tonumber(at.y) then
    Demo.state.at = { map = at.map, x = tonumber(at.x), y = tonumber(at.y) }
  else
    Demo.state.at = nil
  end
  return Demo.Apply()
end

--- Brief ST5: the pretend bags ({ sizes, reagent }, Demo.ParseBags' shape), or nil for off.
function Demo.SetBags(bags)
  Demo.state.bags = type(bags) == "table" and bags or nil
  return Demo.Apply()
end

--- Brief BG1: the pretend bank ({ sizes, items }, Demo.ParseBank's shape), or nil for off.
function Demo.SetBank(bank)
  Demo.state.bank = type(bank) == "table" and bank or nil
  return Demo.Apply()
end

--- The pretend race (an id, nil for off).
function Demo.SetRace(race)
  Demo.state.race = tonumber(race)
  return Demo.Apply()
end

--- Brief ST4 (bin B): one pretend pool ("health" or "mana"), a whole number, or nil for off.
function Demo.SetPool(pool, value)
  if pool ~= "health" and pool ~= "mana" then
    return false
  end
  value = tonumber(value)
  if value ~= nil then
    value = math.max(1, math.min(Demo.MAX_POOL, math.floor(value)))
  end
  Demo.state[pool] = value
  return Demo.Apply()
end

function Demo.SetCarefulAim(rank)
  rank = tonumber(rank)
  if rank ~= nil then
    rank = math.max(0, math.min(Demo.CAREFUL_AIM_MAX, math.floor(rank)))
  end
  Demo.state.carefulAim = rank
  return Demo.Apply()
end

--- One quest's pretend state ({ kind, have, need }), or nil to stop pretending it.
function Demo.SetQuest(questId, quest)
  local id = tonumber(questId)
  if not id then
    return false
  end
  if type(quest) == "table" then
    Demo.state.quests[id] = { kind = quest.kind, have = quest.have, need = quest.need }
  else
    Demo.state.quests[id] = nil
  end
  return Demo.Apply()
end

function Demo.SetQuestsNone(on)
  Demo.state.questsNone = on and true or false
  return Demo.Apply()
end

function Demo.ClearQuests()
  Demo.state.quests = {}
  Demo.state.questsNone = false
  return Demo.Apply()
end

--- Brief ST5: the pet, bags and worn roll lines `demo show` prints. Pure but for the item names.
function Demo.ST5Lines(state)
  local lines = {}
  if type(state.pet) == "table" and state.pet.none == true then
    lines[#lines + 1] = "Demo pet: none out"
  elseif type(state.pet) == "table" then
    local eaten = {}
    for _, id in ipairs(sortedKeys(state.pet.eats or EMPTY)) do
      eaten[#eaten + 1] = Demo.ItemName(id)
    end
    lines[#lines + 1] = string.format(
      "Demo pet: %s, eats %s",
      tostring(state.pet.family),
      #eaten > 0 and table.concat(eaten, ", ") or "nothing named"
    )
  end
  if type(state.bags) == "table" then
    local sizes = {}
    for index, size in ipairs(state.bags.sizes or EMPTY) do
      sizes[index] = tostring(size)
      -- Brief BQ25c: a slot named by its bag, by the bag's name.
      local id = type(state.bags.items) == "table" and tonumber(state.bags.items[index]) or nil
      if id then
        sizes[index] = Demo.ItemName(id)
      end
    end
    local line = "Demo bags: " .. table.concat(sizes, ", ") .. " (full)"
    local reagent = state.bags.reagent
    if type(reagent) == "table" then
      line = line .. string.format(", %s %d (empty)", tostring(reagent.word), tonumber(reagent.size) or 0)
    end
    lines[#lines + 1] = line
  end
  -- Brief BG1: the pretend bank's bag slots.
  if type(state.bank) == "table" then
    local sizes = {}
    for index, size in ipairs(state.bank.sizes or EMPTY) do
      local id = type(state.bank.items) == "table" and tonumber(state.bank.items[index]) or nil
      if id then
        sizes[index] = Demo.ItemName(id)
      elseif tonumber(size) == 0 then
        sizes[index] = "empty"
      else
        sizes[index] = tostring(size)
      end
    end
    lines[#lines + 1] = "Demo bank bag slots: " .. table.concat(sizes, ", ") .. " (the rest not bought)"
  end
  for _, slot in ipairs(sortedKeys(state.wornLinks or EMPTY)) do
    local suffix = tostring(state.wornLinks[slot]):match(":(%d+)$")
    lines[#lines + 1] = string.format("Demo worn roll: slot %d, suffix %s", slot, tostring(suffix))
  end
  return lines
end

--- One item's pretend held count, or nil to stop pretending it.
function Demo.SetHave(itemId, count)
  local id = tonumber(itemId)
  if not id then
    return false
  end
  count = tonumber(count)
  Demo.state.have[id] = count and math.max(0, math.floor(count)) or nil
  return Demo.Apply()
end

function Demo.ClearHave()
  Demo.state.have = {}
  return Demo.Apply()
end

--- Everything back to the real character: the facts here, the level, the professions and the Keep
--- values, then one Apply. Nothing saved is touched, because nothing was saved.
function Demo.Off()
  Demo.state = Demo.Fresh()
  local k = keep()
  if k and type(k.DEMO_KINDS) == "table" then
    for _, field in pairs(k.DEMO_KINDS) do
      k[field] = nil
    end
    local values = ItemTree.DisenchantValue
    call(values, "SetDemoPrice", nil)
  end
  local skills = playerSkills()
  if skills and type(skills.SetDemo) == "function" and Demo.ProfessionsOn() then
    skills.SetDemo(nil)
    call(skills, "ApplyDemo")
  end
  Demo.Apply()
  return true
end

-- A preset's professions as PlayerSkills entries, each named by Keep.SkillName where it can be.
local function presetProfessions(list)
  if list == "none" then
    return "none"
  end
  local k = keep()
  local entries = {}
  for _, entry in ipairs(type(list) == "table" and list or EMPTY) do
    local name = nil
    if k and type(k.SkillName) == "function" then
      local ok, named = pcall(k.SkillName, entry.line)
      name = ok and type(named) == "string" and named ~= "" and named or nil
    end
    entries[#entries + 1] = { line = entry.line, name = name or tostring(entry.line), rank = entry.rank }
  end
  return entries
end

--- Applies one preset on top of the state as it is (Demo.ApplyScenario clears first).
function Demo.ApplyPreset(preset)
  if type(preset) ~= "table" then
    return false
  end
  local state = Demo.state
  if preset.level then
    Demo.SetLevel(preset.level)
  end
  if preset.professions then
    Demo.SetProfessions(presetProfessions(preset.professions))
  end
  if preset.specs then
    local copy = {}
    for index, key in ipairs(preset.specs) do
      copy[index] = key
    end
    state.specs = copy
  end
  if preset.carefulAim ~= nil then
    state.carefulAim = preset.carefulAim
  end
  -- Brief ST4 (bin B): the pools.
  if tonumber(preset.health) then
    state.health = math.floor(tonumber(preset.health))
  end
  if tonumber(preset.mana) then
    state.mana = math.floor(tonumber(preset.mana))
  end
  -- Brief BQ14 follow up: the class, side and race.
  if preset.classId ~= nil then
    state.classId = tonumber(preset.classId)
  end
  if preset.faction ~= nil then
    state.faction = tonumber(preset.faction)
  end
  if preset.race ~= nil then
    state.race = tonumber(preset.race)
  end
  -- Brief ST5: the pet, the bags and the worn rolls.
  -- Brief ST6 (bin E2): { none = true } is "no pet out" (the self test's case with no pet).
  if type(preset.pet) == "table" and preset.pet.none == true then
    state.pet = { none = true, eats = {} }
  elseif type(preset.pet) == "table" and type(preset.pet.family) == "string" then
    local eats = {}
    for key, value in pairs(preset.pet.eats or EMPTY) do
      if value == true then
        eats[tonumber(key)] = true
      elseif tonumber(value) then
        eats[tonumber(value)] = true
      end
    end
    state.pet = { family = preset.pet.family, eats = eats }
  end
  if type(preset.bags) == "table" then
    state.bags = preset.bags
  end
  -- Brief BQ29: the Well Fed buff (true, false or "unknown").
  if preset.wellFed == true or preset.wellFed == false or preset.wellFed == "unknown" then
    state.wellFed = preset.wellFed
  end
  if type(preset.wornLinks) == "table" and next(preset.wornLinks) ~= nil then
    local links = {}
    for slot, link in pairs(preset.wornLinks) do
      links[tonumber(slot)] = link
    end
    state.wornLinks = links
  end
  if type(preset.worn) == "table" then
    local worn = {}
    for slot, id in pairs(preset.worn) do
      worn[tonumber(slot)] = tonumber(id)
    end
    state.worn = worn
  end
  if preset.questsNone then
    state.questsNone = true
  end
  for questId, quest in pairs(type(preset.quests) == "table" and preset.quests or EMPTY) do
    if type(quest) == "table" then
      state.quests[questId] = { kind = "log", have = quest[1], need = quest[2] }
    else
      state.quests[questId] = { kind = quest }
    end
  end
  for itemId, count in pairs(type(preset.have) == "table" and preset.have or EMPTY) do
    state.have[itemId] = count
  end
  return true
end

--- A scenario from Demo.ParseScenario's set: a clean slate, then each preset in order, one Apply.
function Demo.ApplyScenario(parsed)
  if type(parsed) ~= "table" or parsed.kind ~= "set" then
    return false
  end
  Demo.Off()
  for _, preset in ipairs(parsed.presets) do
    Demo.ApplyPreset(preset)
  end
  Demo.state.scenario = table.concat(parsed.names, " ")
  Demo.Apply()
  return true
end

--------------------------------------------------------------------------------
-- Client side. Guarded: logging out ends the demo (it is memory only, so this is belt and braces
-- for a client that keeps the Lua state across a character change).
--------------------------------------------------------------------------------

function Demo.OnEvent(event)
  if event == "PLAYER_LOGOUT" then
    if Demo.On() then
      Demo.Off()
    end
    return true
  end
  return false
end

--------------------------------------------------------------------------------
-- Brief DM1: zone names for `demo at`. Guarded: the Classic Era reader for Era zones (E:AreaIdOf,
-- E:MapOf), else one walk of the client's map list (C_Map.GetMapChildrenInfo under the world maps)
-- for a Forever zone such as Riverglades, made on the first name typed and kept.
--------------------------------------------------------------------------------

Demo.ROOT_MAPS = { 946, 947 }

-- The client's maps by lower case name (zones before anything else, then the lower id), or false
-- where the client will not list them.
Demo.mapNames = nil

local function mapApi()
  local api = rawget(_G, "C_Map")
  return type(api) == "table" and api or nil
end

local function clientMapNames()
  if Demo.mapNames ~= nil then
    return Demo.mapNames or nil
  end
  local api = mapApi()
  local names = false
  if api and type(api.GetMapChildrenInfo) == "function" then
    names = {}
    local enum = rawget(_G, "Enum")
    local types = type(enum) == "table" and enum.UIMapType or nil
    local zoneType = type(types) == "table" and types.Zone or 3
    local rankOf = {}
    for _, root in ipairs(Demo.ROOT_MAPS) do
      local ok, list = pcall(api.GetMapChildrenInfo, root, nil, true)
      for _, info in ipairs(ok and type(list) == "table" and list or EMPTY) do
        local id = type(info) == "table" and tonumber(info.mapID) or nil
        local name = id and type(info.name) == "string" and info.name ~= "" and info.name:lower() or nil
        if name then
          local rank = info.mapType == zoneType and 0 or 1
          local held = names[name]
          if held == nil or rank < rankOf[name] or (rank == rankOf[name] and id < held) then
            names[name], rankOf[name] = id, rank
          end
        end
      end
    end
  end
  Demo.mapNames = names
  return names or nil
end

--- Brief DM1: the uiMap a zone name stands for: the Classic Era area of that name's map, else the
--- client's map of that name (one walk, kept), else nil. Case does not matter. Guarded.
function Demo.ZoneMap(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  local era = ItemTree.eraSources
  if type(era) == "table" and type(era.AreaIdOf) == "function" and type(era.MapOf) == "function" then
    local ok, areaId = pcall(era.AreaIdOf, era, name)
    if ok and areaId then
      local fine, map = pcall(era.MapOf, era, areaId)
      if fine and type(map) == "number" then
        return map
      end
    end
  end
  local names = clientMapNames()
  return names and names[name:lower()] or nil
end

--- Brief DM1: the client's name for a uiMap, or nil. Guarded.
function Demo.MapName(map)
  local api = mapApi()
  if not api or type(api.GetMapInfo) ~= "function" then
    return nil
  end
  local ok, info = pcall(api.GetMapInfo, map)
  local name = ok and type(info) == "table" and info.name or nil
  return type(name) == "string" and name ~= "" and name or nil
end

function Demo.Install()
  if Demo.frame then
    return Demo.frame
  end
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, "Frame")
  if not ok or type(frame) ~= "table" or type(frame.RegisterEvent) ~= "function" then
    return nil
  end
  pcall(frame.RegisterEvent, frame, "PLAYER_LOGOUT")
  pcall(frame.SetScript, frame, "OnEvent", function(_, event)
    Demo.OnEvent(event)
  end)
  Demo.frame = frame
  return frame
end

Demo.Install()

return Demo
