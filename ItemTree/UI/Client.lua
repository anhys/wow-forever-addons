-- Client side overrides for the resolvers Core declares and the UI layer is meant to replace,
-- and the reads the generated data cannot answer at all. Installed once, at load, before any
-- window is built.
--
-- Core/Init.lua answers ItemTree.SpellName out of the generated SpellNames module and nothing
-- else, so a spell the pipeline did not ship has no name at all. The client knows the name of
-- every spell the player's client knows, and the data knows the name of every spell in the build
-- it was compiled for, so the two cover different gaps: this file asks the client first and falls
-- back to what Core answered, which fills each side's gap with the other's.
--
-- Two more reads live here for the same reason, and the info column is what draws them:
--   ItemTree.ItemStats(itemId)       the real stat amounts, which a retail shaped build states
--                                    only as budget shares the data cannot turn into numbers.
--   ItemTree.SpellDescription(id)    what a spell actually does, which the pipeline never ships.
-- Both can answer nothing on the first ask, because the client loads item and spell text on
-- demand, so each has a matching request call that takes a callback and fires it once the text
-- arrives: ItemTree.RequestItemData and ItemTree.RequestSpellData.
--
-- Guarded the same way every other UI file is: it loads under busted with no WoW API present,
-- where the client lookups answer nothing and Core's own resolver is what remains.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

-- The table the namespace already carries, where it carries one: loading this file twice must
-- not wrap the override in itself, and the install flag is what stops that.
local Client = ItemTree.Client or {}
ItemTree.Client = Client
ItemTree.UI.Client = Client

-- Nothing to do on load: Install has already run by the time the client calls this.
function Client.Init() end

-- Brief SV1: whether a value the client handed over can be read (compared, joined, measured,
-- used as a key) or is a secret the client withholds from addon code. The one helper lives in
-- Core/Util.lua, because Core/Util.lua loads before every file that reads the client and this
-- file loads after most of them; this is the same function under the client wrappers' name.
Client.CanRead = ItemTree.Util and ItemTree.Util.CanRead or function()
  return true
end

-- The stat keys GetItemStats answers with, in the order a tooltip reads them. Anything the
-- client names that is not in this list is drawn after these, in alphabetical order, so a stat
-- a future build invents still reaches the column rather than being dropped.
--
-- RESISTANCE0_NAME is armour, and it leads: the game tooltip writes "365 Armor" above the
-- primary stats, not below them. It is a base value rather than a bonus, so the column draws
-- it with no plus sign (UI/InfoPanel.lua); the resistances below it are bonuses and keep
-- theirs. The record's own computed armour is drawn in the same first position when the
-- client has no answer, so the block reads the same whichever of the two filled it.
local STAT_ORDER = {
  "RESISTANCE0_NAME",
  "ITEM_MOD_STRENGTH_SHORT",
  "ITEM_MOD_AGILITY_SHORT",
  "ITEM_MOD_STAMINA_SHORT",
  "ITEM_MOD_INTELLECT_SHORT",
  "ITEM_MOD_SPIRIT_SHORT",
  "ITEM_MOD_HEALTH_SHORT",
  "ITEM_MOD_MANA_SHORT",
  "RESISTANCE1_NAME",
  "RESISTANCE2_NAME",
  "RESISTANCE3_NAME",
  "RESISTANCE4_NAME",
  "RESISTANCE5_NAME",
  "RESISTANCE6_NAME",
  "ITEM_MOD_ATTACK_POWER_SHORT",
  "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
  "ITEM_MOD_SPELL_POWER_SHORT",
  "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",
  "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
  "ITEM_MOD_MANA_REGENERATION_SHORT",
  "ITEM_MOD_HEALTH_REGENERATION_SHORT",
  "ITEM_MOD_CRIT_RATING_SHORT",
  "ITEM_MOD_SPELL_CRIT_RATING_SHORT",
  "ITEM_MOD_HIT_RATING_SHORT",
  "ITEM_MOD_SPELL_HIT_RATING_SHORT",
  "ITEM_MOD_HASTE_RATING_SHORT",
  "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
  "ITEM_MOD_DODGE_RATING_SHORT",
  "ITEM_MOD_PARRY_RATING_SHORT",
  "ITEM_MOD_BLOCK_RATING_SHORT",
  "ITEM_MOD_BLOCK_VALUE_SHORT",
}

local STAT_RANK = {}
for index, key in ipairs(STAT_ORDER) do
  STAT_RANK[key] = index
end

-- The resistance keys are the one family whose global name carries a number rather than a word,
-- so the words are written out here for a client that does not answer for them. Australian
-- English: the client's own RESISTANCE0_NAME reads "Armor" and wins wherever it is present.
local RESISTANCE_NAMES = {
  RESISTANCE0_NAME = "Armour",
  RESISTANCE1_NAME = "Holy resistance",
  RESISTANCE2_NAME = "Fire resistance",
  RESISTANCE3_NAME = "Nature resistance",
  RESISTANCE4_NAME = "Frost resistance",
  RESISTANCE5_NAME = "Shadow resistance",
  RESISTANCE6_NAME = "Arcane resistance",
}

-- Whitespace off both ends. The client pads spell text with newlines more often than not.
function Client.Trim(text)
  if type(text) ~= "string" then
    return nil
  end
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- A stat label with its first letter lifted, so every row in the block reads the same way. The
-- client's own global strings are not consistent about it: ITEM_MOD_STRENGTH_SHORT is
-- "Strength" while ITEM_MOD_DAMAGE_PER_SECOND_SHORT is "damage per second", because the client
-- only ever writes that one inside brackets mid sentence. A label already starting with a
-- capital, a digit or a symbol is handed back untouched. nil for anything that is not text.
function Client.Capitalise(text)
  if type(text) ~= "string" or text == "" then
    return nil
  end
  return (text:gsub("^%l", string.upper))
end

-- "ITEM_MOD_SPELL_POWER_SHORT" -> "Spell power". The honest fallback for a stat key the client
-- has no global string for: the key itself is never shown to a player.
function Client.StatKeyText(key)
  if type(key) ~= "string" or key == "" then
    return nil
  end
  local named = RESISTANCE_NAMES[key]
  if named then
    return named
  end
  local words = key:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", ""):gsub("_NAME$", ""):gsub("_", " ")
  return Client.Capitalise(words:lower())
end

-- The raw table GetItemStats answers with, as an ordered array of { key, label, value }. Pure:
-- labeller is the lookup for the client's own word for a key, and the key's own spelling is what
-- remains without one. A stat of zero is not a stat, so it is left out. Every label comes back
-- capitalised, whichever of the two answered it, so the column never draws "damage per second"
-- under "Stamina".
function Client.StatList(raw, labeller)
  local list = {}
  if type(raw) ~= "table" then
    return list
  end
  for key, value in pairs(raw) do
    local amount = tonumber(value)
    if type(key) == "string" and amount and amount ~= 0 then
      local label
      if type(labeller) == "function" then
        local ok, text = pcall(labeller, key)
        if ok and type(text) == "string" and text ~= "" then
          label = Client.Capitalise(text)
        end
      end
      list[#list + 1] = {
        key = key,
        label = label or Client.StatKeyText(key) or key,
        value = amount,
      }
    end
  end
  table.sort(list, function(a, b)
    local rankA, rankB = STAT_RANK[a.key] or (#STAT_ORDER + 1), STAT_RANK[b.key] or (#STAT_ORDER + 1)
    if rankA ~= rankB then
      return rankA < rankB
    end
    if a.label ~= b.label then
      return a.label < b.label
    end
    return a.key < b.key
  end)
  return list
end

-- The item facts the client answers with, as one table, or nil when the first return is not a
-- name. Pure: the arguments are exactly GetItemInfo's returns in order, so the two client calls
-- below hand theirs straight in and a spec can hand in a row of its own.
--
--   name, link, quality, level, requiredLevel, class, subclass, stack, equipSlot, icon,
--   sellPrice, classId, subclassId
--
-- equipSlot is the client's own token ("INVTYPE_CHEST"); the readable word for it is a global
-- string of that name, which Client.SlotText reads where there is a client to read it from.
function Client.ItemFactsFrom(name, link, quality, level, requiredLevel, class, subclass, stack, equipSlot, icon, ...)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  local sellPrice, classId, subclassId = ...
  return {
    name = name,
    link = type(link) == "string" and link ~= "" and link or nil,
    quality = tonumber(quality),
    level = tonumber(level),
    requiredLevel = tonumber(requiredLevel),
    class = type(class) == "string" and class ~= "" and class or nil,
    subclass = type(subclass) == "string" and subclass ~= "" and subclass or nil,
    stack = tonumber(stack),
    equipSlot = type(equipSlot) == "string" and equipSlot ~= "" and equipSlot or nil,
    icon = tonumber(icon),
    sellPrice = tonumber(sellPrice),
    classId = tonumber(classId),
    subclassId = tonumber(subclassId),
  }
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- The client's own name for a spell, or nil. C_Spell.GetSpellName is the newer engine's call and
-- GetSpellInfo's first return is Classic Era's; both are pcall'd, because a client that has
-- renamed or dropped either must not take a tooltip line down with it.
function Client.ClientSpellName(spellId)
  if type(spellId) ~= "number" then
    return nil
  end
  local spellApi = rawget(_G, "C_Spell")
  if type(spellApi) == "table" and type(spellApi.GetSpellName) == "function" then
    local ok, name = pcall(spellApi.GetSpellName, spellId)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end
  local getSpellInfo = rawget(_G, "GetSpellInfo")
  if type(getSpellInfo) == "function" then
    local ok, name = pcall(getSpellInfo, spellId)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end
  return nil
end

-- The resolver that replaces ItemTree.SpellName: the client first, then whatever Core answered
-- before this file was loaded.
function Client.SpellName(spellId)
  local name = Client.ClientSpellName(spellId)
  if name then
    return name
  end
  local fallback = Client.coreSpellName
  if type(fallback) ~= "function" then
    return nil
  end
  local ok, value = pcall(fallback, spellId)
  if ok and type(value) == "string" and value ~= "" then
    return value
  end
  return nil
end

-- The client's own word for one ITEM_MOD key, from the global string of that exact name, which
-- is how the client's own tooltip writes it. nil leaves Client.StatKeyText to answer.
function Client.StatLabel(key)
  if type(key) ~= "string" then
    return nil
  end
  local text = rawget(_G, key)
  if type(text) == "string" and text ~= "" then
    return text
  end
  return nil
end

-- One stat call in both of its shapes: the newer one returns the table, the older one fills a
-- table it is handed. nil where the client answered nothing, which is what a stat call on an
-- item the client has not loaded yet does.
local function statsFrom(getter, link)
  local ok, result = pcall(getter, link)
  if ok and type(result) == "table" and next(result) ~= nil then
    return result
  end
  local out = {}
  ok = pcall(getter, link, out)
  if ok and next(out) ~= nil then
    return out
  end
  return nil
end

-- The real stat amounts for an item, as { { key, label, value } } in tooltip order, or nil when
-- the client cannot say. This is the first choice everywhere stats are drawn: a retail shaped
-- build states only the budget share behind a stat, and the share is not a number a player can
-- read, while the client has worked the real number out already.
function Client.ItemStats(itemId)
  local id = tonumber(itemId)
  if not id then
    return nil
  end
  local link = "item:" .. tostring(id)
  local raw
  local itemApi = rawget(_G, "C_Item")
  if type(itemApi) == "table" and type(itemApi.GetItemStats) == "function" then
    raw = statsFrom(itemApi.GetItemStats, link)
  end
  if raw == nil then
    local getItemStats = rawget(_G, "GetItemStats")
    if type(getItemStats) == "function" then
      raw = statsFrom(getItemStats, link)
    end
  end
  if raw == nil then
    return nil
  end
  local list = Client.StatList(raw, Client.StatLabel)
  if #list == 0 then
    return nil
  end
  return list
end

-- What a spell does, in the client's own words, or nil. C_Spell.GetSpellDescription is the newer
-- engine's call and GetSpellDescription is Classic Era's. Spell text loads on demand, so empty is
-- an ordinary answer rather than a failure, and Client.RequestSpellData is what asks for it.
function Client.SpellDescription(spellId)
  local id = tonumber(spellId)
  if not id then
    return nil
  end
  local spellApi = rawget(_G, "C_Spell")
  if type(spellApi) == "table" and type(spellApi.GetSpellDescription) == "function" then
    local ok, text = pcall(spellApi.GetSpellDescription, id)
    if ok then
      text = Client.Trim(text)
      if text and text ~= "" then
        return text
      end
    end
  end
  local getDescription = rawget(_G, "GetSpellDescription")
  if type(getDescription) == "function" then
    local ok, text = pcall(getDescription, id)
    if ok then
      text = Client.Trim(text)
      if text and text ~= "" then
        return text
      end
    end
  end
  return nil
end

-- The client's own readable word for an equip slot token, from the global string of that exact
-- name ("INVTYPE_CHEST" -> "Chest"), or nil. The same read Client.StatLabel does for a stat.
function Client.SlotText(token)
  if type(token) ~= "string" or token == "" or token == "INVTYPE_NON_EQUIP" then
    return nil
  end
  local text = rawget(_G, token)
  if type(text) == "string" and text ~= "" then
    return text
  end
  return nil
end

-- Everything the running client knows about an item, or nil when it knows nothing yet. This is
-- the live layer: WoW Forever withholds an item's details until someone on the realm has found
-- it, and once they have, the client is the only place the name, the quality and the stats
-- exist. Core asks through ItemTree.ItemFacts for any item the shipped data cannot name, so a
-- discovered item draws as itself rather than as "Undiscovered mail chest".
--
-- Both call shapes are tried, the newer one first, each under pcall. Nothing loads on demand
-- here: an item the client has not loaded answers nothing, and ItemTree.RequestItemData is what
-- asks for it and calls back when it arrives.
-- One item info call in either shape, as the facts table, or nil. Every return is kept and
-- handed to the pure builder; a call that raises reads as an item the client cannot name.
local function factsFrom(getter, id)
  local ok, name, link, quality, level, required, class, subclass, stack, slot, icon, price, classId, subclassId =
    pcall(getter, id)
  if not ok then
    return nil
  end
  return Client.ItemFactsFrom(
    name,
    link,
    quality,
    level,
    required,
    class,
    subclass,
    stack,
    slot,
    icon,
    price,
    classId,
    subclassId
  )
end

function Client.ItemFacts(itemId)
  local id = tonumber(itemId)
  if not id then
    return nil
  end
  local facts = nil
  local itemApi = rawget(_G, "C_Item")
  if type(itemApi) == "table" and type(itemApi.GetItemInfo) == "function" then
    facts = factsFrom(itemApi.GetItemInfo, id)
  end
  if facts == nil then
    local getItemInfo = rawget(_G, "GetItemInfo")
    if type(getItemInfo) == "function" then
      facts = factsFrom(getItemInfo, id)
    end
  end
  if facts == nil then
    return nil
  end
  facts.id = id
  facts.slot = Client.SlotText(facts.equipSlot)
  return facts
end

-- Callbacks waiting on the client to load an item or a spell, by id. One shot: the list is taken
-- off the table before it is run, so a callback that asks again cannot loop. An item callback is
-- called with the id and the success flag the event carried (nil where it carried none).
Client.pending = Client.pending or { item = {}, spell = {} }

local function firePending(kind, id, success)
  local waiting = Client.pending[kind]
  if type(waiting) ~= "table" then
    return false
  end
  local fired = false
  if id ~= nil then
    local list = waiting[id]
    if type(list) ~= "table" then
      return false
    end
    waiting[id] = nil
    for _, callback in ipairs(list) do
      pcall(callback, id, success)
      fired = true
    end
    return fired
  end
  -- SPELL_TEXT_UPDATE names no spell, so every spell still waiting is told to look again.
  for pendingId, list in pairs(waiting) do
    waiting[pendingId] = nil
    if type(list) == "table" then
      for _, callback in ipairs(list) do
        pcall(callback, pendingId)
        fired = true
      end
    end
  end
  return fired
end

-- The events the load requests answer on. GET_ITEM_INFO_RECEIVED, ITEM_DATA_LOAD_RESULT and
-- SPELL_DATA_LOAD_RESULT name the id they are about; SPELL_TEXT_UPDATE names nothing at all.
-- ITEM_DATA_LOAD_RESULT is C_Item.RequestLoadItemDataByID's own answer, (itemId, success), and
-- the one that says a load FAILED, which is how a withheld item nobody on the realm has found
-- answers (brief D5, Core/RealmCheck.lua).
Client.EVENTS = {
  "GET_ITEM_INFO_RECEIVED",
  "ITEM_DATA_LOAD_RESULT",
  "SPELL_DATA_LOAD_RESULT",
  "SPELL_TEXT_UPDATE",
}

-- The success flag an item event carried: true or false where it said, nil where it said nothing.
local function successFlag(value)
  if value == true or value == false then
    return value
  end
  return nil
end

-- Whether an event moved anything on. Pure enough to spec: the event name and its first two
-- payloads are all it reads, and the callbacks are whatever was handed to the request calls.
function Client.OnEvent(event, first, second)
  if event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
    return firePending("item", tonumber(first), successFlag(second))
  end
  if event == "SPELL_DATA_LOAD_RESULT" then
    return firePending("spell", tonumber(first))
  end
  if event == "SPELL_TEXT_UPDATE" then
    return firePending("spell", nil)
  end
  return false
end

-- One frame for both kinds of wait, built the first time something waits. nil with no client,
-- which is what leaves the request calls answering false under busted.
local function eventFrame()
  if Client.frame then
    return Client.frame
  end
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, "Frame")
  if not ok or type(frame) ~= "table" then
    return nil
  end
  Client.frame = frame
  for _, event in ipairs(Client.EVENTS) do
    if type(frame.RegisterEvent) == "function" then
      pcall(frame.RegisterEvent, frame, event)
    end
  end
  if type(frame.SetScript) == "function" then
    frame:SetScript("OnEvent", function(_, event, first, second)
      Client.OnEvent(event, first, second)
    end)
  end
  return frame
end

local function waitFor(kind, id, callback)
  if not eventFrame() then
    return false
  end
  local waiting = Client.pending[kind]
  if type(waiting) ~= "table" then
    waiting = {}
    Client.pending[kind] = waiting
  end
  local list = waiting[id]
  if type(list) ~= "table" then
    list = {}
    waiting[id] = list
  end
  list[#list + 1] = callback
  return true
end

-- Asks the client to load an item, and calls back once when it has. The mixin is the modern
-- shape and the event is Classic Era's; false means nothing was asked, so the caller should not
-- wait for an answer. The callback is called at most once per request.
--
-- opts.result (brief D5) asks for the answer whichever way it goes, as callback(id, success):
-- the mixin is skipped, because on the forever branch's AsyncCallbackSystem a FAILED load clears
-- the queued callbacks without running them (the Discovery Miner's Client/Ask.lua), and a
-- failure is the answer Core/RealmCheck.lua needs. C_Item.RequestLoadItemDataByID and
-- ITEM_DATA_LOAD_RESULT carry the success flag, so they are asked instead.
function Client.RequestItemData(itemId, callback, opts)
  local id = tonumber(itemId)
  if not id or type(callback) ~= "function" then
    return false
  end
  local wantResult = type(opts) == "table" and opts.result == true
  local itemClass = rawget(_G, "Item")
  if not wantResult and type(itemClass) == "table" and type(itemClass.CreateFromItemID) == "function" then
    local ok, item = pcall(itemClass.CreateFromItemID, id)
    if ok and type(item) == "table" and type(item.ContinueOnItemLoad) == "function" then
      if pcall(item.ContinueOnItemLoad, item, callback) then
        return true
      end
    end
  end
  local itemApi = rawget(_G, "C_Item")
  if type(itemApi) == "table" and type(itemApi.RequestLoadItemDataByID) == "function" then
    if pcall(itemApi.RequestLoadItemDataByID, id) then
      return waitFor("item", id, callback)
    end
  end
  -- Classic Era has no request call: asking for the item info is itself the request, and the
  -- event is how the answer comes back.
  local getItemInfo = rawget(_G, "GetItemInfo")
  if type(getItemInfo) == "function" then
    pcall(getItemInfo, id)
    return waitFor("item", id, callback)
  end
  return false
end

-- The same for a spell's text. Spell:CreateFromSpellID is the modern shape; C_Spell's request
-- call plus SPELL_DATA_LOAD_RESULT or SPELL_TEXT_UPDATE is the other one.
function Client.RequestSpellData(spellId, callback)
  local id = tonumber(spellId)
  if not id or type(callback) ~= "function" then
    return false
  end
  local spellClass = rawget(_G, "Spell")
  if type(spellClass) == "table" and type(spellClass.CreateFromSpellID) == "function" then
    local ok, spell = pcall(spellClass.CreateFromSpellID, id)
    if ok and type(spell) == "table" and type(spell.ContinueOnSpellLoad) == "function" then
      if pcall(spell.ContinueOnSpellLoad, spell, callback) then
        return true
      end
    end
  end
  local spellApi = rawget(_G, "C_Spell")
  if type(spellApi) == "table" and type(spellApi.RequestLoadSpellData) == "function" then
    if pcall(spellApi.RequestLoadSpellData, id) then
      return waitFor("spell", id, callback)
    end
  end
  return false
end

-- Idempotent: the Core resolver is captured once, so loading this file twice cannot wrap the
-- override in itself. The reads Core never declared are plain assignments, so they are set from
-- here whether or not this is the first install.
function Client.Install()
  ItemTree.ItemStats = Client.ItemStats
  ItemTree.ItemFacts = Client.ItemFacts
  ItemTree.SpellDescription = Client.SpellDescription
  ItemTree.RequestItemData = Client.RequestItemData
  ItemTree.RequestSpellData = Client.RequestSpellData
  if Client.installed then
    return false
  end
  Client.installed = true
  Client.coreSpellName = ItemTree.SpellName
  ItemTree.SpellName = Client.SpellName
  return true
end

Client.Install()

return Client
