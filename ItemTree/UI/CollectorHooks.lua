-- Event hooks that feed ItemTree.collector. This is the only file that watches the client
-- for facts the data pipeline cannot mine: who dropped it, who sells it, which quest gave it.
--
-- Privacy rules, enforced here and again in Core/Privacy.lua:
--   Player GUIDs are dropped, never stored and never parsed for a name.
--   Creature, GameObject and Item GUIDs are reduced to { kind, id } by Privacy.SanitiseGuid.
--   The only name stored is the NPC name the client is already showing (a vendor, a creature
--   that is the current target), which is game data, not player identity.
--   The player's map position is read once when a vendor window opens (brief M3) and kept only
--   as that vendor's rough coordinates, rounded to a tenth of a percent, on its records. Brief
--   Q8 reads it the same way when a quest is offered and when one is handed in, kept only as the
--   quest giver's or the turn in NPC's rough place, one record per quest per kind. Brief R5a
--   reads it on either side of a loading screen into a party or raid instance, kept only as a
--   1 percent cell count under that instance's entrance in the places store (Core/Places.lua).
--   Brief R9 reads it once when a trainer's or a stable master's window opens, kept the same way
--   under that NPC's creature id with the name the client showed over it (and what a trainer
--   trains, where its first service names it), and keeps a gathered node's name, the target name
--   the player's own gathering cast was sent with, on the loot record beside the object's id. A
--   quest's title rides on its quest NPC records, once per quest. Brief R12 reads it when the
--   game tooltip shows a world object whose first line is a known gathering node's name, kept only
--   as a 1 percent cell count under that name in the places store, whatever the player's
--   professions. No other tooltip line is read, and no unit or item tooltip. Brief R14 keeps one
--   cell per hover run (the last) and reads it once more at a gather's loot window, kept the same
--   way under the gathered node's name as its real spot.
--   Nothing is sent anywhere. There is no network access in this addon.
--
-- Every client call goes through call(), which type checks the global and pcall's the call.
-- That is not belt and braces. This file runs inside event handlers, where a raise is not
-- swallowed the way it is inside a tooltip post call: it abandons the rest of the handler and
-- puts an error message in front of the player. One API that will not answer has to cost that
-- one value, never the record and never the rest of the window.
--
-- The quest APIs are why this matters, because their signatures differ by client:
--
--   The quest log family (GetNumQuestLogRewards, GetNumQuestLogChoices, GetQuestLogRewardInfo,
--   GetQuestLogChoiceInfo, GetQuestLogItemLink) reads the selected quest log entry. On Classic
--   Era it takes no quest id and raises when it is handed one. On the Forever beta it has the
--   retail shape, which requires one and raises without it:
--     Usage: GetNumQuestLogChoices(questID, [includeCurrencies])
--
--   The quest frame family (GetNumQuestRewards, GetNumQuestChoices, GetQuestItemInfo,
--   GetQuestItemLink) describes the quest the player is being offered or is handing in, which
--   is what QUEST_DETAIL and QUEST_COMPLETE are about, and takes no quest id on either client.
--   GetQuestID names that quest.
--
-- So the frame family is read first, because it describes the quest on screen rather than
-- whichever entry the quest log happens to have selected, and the log family is the fallback.
-- CollectorHooks.QuestArgShapes decides which argument shapes each call is tried in, so no
-- client detection is needed: whichever shape answers is the one this client carries.
--
-- A quest is also watched for what it ASKS FOR, which no build states either. Two paths, and
-- neither of them queries an item:
--
--   QUEST_PROGRESS, the turn in window, is the exact one. GetNumQuestItems and
--   GetQuestItemInfo("required", index) name the required items with their counts for the quest
--   GetQuestID names, which is the same pair the client's own QuestFrameProgressItems_Update
--   reads, so the ids come straight off the call.
--
--   The quest log is the one that answers before the quest is finished, which is the case a
--   player actually cares about: a pelt in the bags with its quest in the log. C_QuestLog names
--   each quest's objectives, an item objective states the item in WORDS and never by id, so the
--   comparison runs the other way round. The item already being looked at, and only that one, is
--   compared by name against the objectives of the quests in the log. One item, against at most
--   a couple of dozen quests, only when its tooltip is up or it has just been looted. That is
--   not a bulk query and it must never become one: see SINGLE_ITEM_HOW.
--
-- CollectorHooks.ClassifyLootSource, CollectorHooks.Enabled, CollectorHooks.QuestArgShapes,
-- CollectorHooks.ParseObjective, CollectorHooks.ObjectiveIndexFrom,
-- CollectorHooks.ObjectiveMatches, CollectorHooks.ObjectiveIsSafe, CollectorHooks.MerchantCost and
-- CollectorHooks.MapPosition, CollectorHooks.AcceptedQuestId, CollectorHooks.QuestNpcFields and
-- CollectorHooks.SeenBossFields are pure and run under busted. Everything below the divider is
-- guarded, so this file loads with no WoW API present.
--
-- CollectorHooks.NoteItem is the one hook that is not about a source at all: it notices that the
-- client has named an item this build withholds, which means somebody on the realm has found
-- it, and writes the id, the name, the quality and the data build down. Nothing about the
-- character, the realm or the account is read or stored, here or in the store it writes to.
local _, ItemTree = ...

local CollectorHooks = {}
ItemTree.CollectorHooks = CollectorHooks

-- Brief SV1: whether a value off the client may be read at all (Core/Util.lua Util.CanRead). In
-- combat the Forever client hands addon code "secret" values (a tooltip's first line, a unit's
-- GUID and name, a cast's target), and a secret raises on any compare, join, match or table key.
-- Every client value this file reads is asked here first, on the line after it is read, and one
-- that cannot be read is treated as absent: that one event records nothing, quietly.
local canRead = ItemTree.Util.CanRead

-- Enchanting: Disenchant.
CollectorHooks.DISENCHANT_SPELL_ID = 13262

-- GUID kind -> record kind and sourceKind. GameObject loot is a gathering node unless the
-- caller knows it is a container; Item loot is a container being opened, or a disenchant.
local GUID_KINDS = {
  Creature = { kind = "drop", sourceKind = "npc" },
  Vehicle = { kind = "drop", sourceKind = "npc" },
  GameObject = { kind = "gather", sourceKind = "object", container = "container" },
  Item = { kind = "container", sourceKind = "item" },
}

-- { kind, id } for a GUID, or nil. Pure Lua, but the GUID comes straight off the client, so
-- the sanitiser is called the way every other call here is: a raise reads as nothing found.
local function sanitiseGuid(guid)
  if not canRead(guid) then
    return nil
  end
  local Privacy = ItemTree.Privacy
  if not Privacy or type(Privacy.SanitiseGuid) ~= "function" then
    return nil
  end
  local ok, ref = pcall(Privacy.SanitiseGuid, guid)
  if not ok or type(ref) ~= "table" then
    return nil
  end
  return ref
end

-- Brief C20: an item id as the collector keys a container by, or nil: a whole number from 1 up
-- to but not including 2^31. Pure.
local function itemIdOrNil(value)
  value = tonumber(value)
  if value and value >= 1 and value < 2 ^ 31 and value == math.floor(value) then
    return value
  end
  return nil
end

-- guid -> record kind, sourceKind, id. nil for players, unknown kinds and malformed GUIDs.
--
-- Brief C20: an Item GUID ("Item-[serverID]-0-[spawnUID]") never carries the item's id. Its
-- third field is the copy's spawn number in hex, and v0.1.4 to v0.1.6 filed a container opened
-- from the bags under that field as Privacy.ParseGuid reads it (tonumber of the hex text, so
-- "4000000001234E05" became 4.000000001234e17: the 18 and 19 digit source ids the pipeline
-- found). For an Item GUID the id is the container's item id, asked of itemIdOf(guid) (the
-- client's C_Item.GetItemIDByGUID, CollectorHooks.ItemIdOfGuid), and nil where it cannot be
-- known: the caller then records nothing rather than a wrong id. The kind is still answered, so
-- a slot with such a source still reads as having one.
--
-- Brief SK1 (owner ruling 2026-10-15, "I wouldn't want them in the drops table"): creatureKind is
-- the record kind the player's own cast before this loot window named (CREATURE_LOOT_SPELLS:
-- "skin", "pickpocket" or "gather"), and a creature's loot in that window is filed under it
-- instead of as a drop. nil, or a kind the collector does not take, leaves a creature a drop.
function CollectorHooks.ClassifyLootSource(guid, isContainer, itemIdOf, creatureKind)
  local ref = sanitiseGuid(guid)
  if not ref then
    return nil
  end
  local map = GUID_KINDS[ref.kind]
  if not map then
    return nil
  end
  local kind = map.kind
  if isContainer and map.container then
    kind = map.container
  end
  if map.sourceKind == "npc" and CollectorHooks.CREATURE_LOOT_KINDS[creatureKind] then
    kind = creatureKind
  end
  local id = ref.id
  if ref.kind == "Item" then
    id = nil
    if type(itemIdOf) == "function" then
      local ok, answer = pcall(itemIdOf, guid)
      id = ok and itemIdOrNil(answer) or nil
    end
  end
  return kind, map.sourceKind, id
end

function CollectorHooks.Enabled()
  local settings = ItemTree.db and ItemTree.db.settings
  if not settings then
    return false
  end
  return settings.collectorEnabled and true or false
end

-- How the item was met, per path, which is what Core/Collector.lua turns into a claim about who
-- found it. Named here so every call site says which path it is rather than passing a word.
--
-- Only the chat line counts as obtaining. A loot window, a merchant's stock and a quest's reward
-- list are things the player is looking at: the client can name the item, which is the realm
-- having found it, and none of them says the item ever reached the player's bags.
CollectorHooks.HOW_TOOLTIP = "tooltip"
CollectorHooks.HOW_LOOT_WINDOW = "lootwindow"
CollectorHooks.HOW_MERCHANT = "merchant"
CollectorHooks.HOW_QUEST_OFFER = "questoffer"
CollectorHooks.HOW_OBTAINED = "loot"

-- The paths that are about one item and not about a list of them.
--
-- A tooltip is one item the player is pointing at; a loot line is one item that just arrived. A
-- loot window, a merchant's stock and a quest's reward list are each a list, and a list is
-- exactly what must never be walked item by item asking the client about each one. Only the two
-- single item paths go on to match the quest log, which is what keeps that rule kept.
CollectorHooks.SINGLE_ITEM_HOW = {
  [CollectorHooks.HOW_TOOLTIP] = true,
  [CollectorHooks.HOW_OBTAINED] = true,
}

-- The client's own "you got this" lines, by global. Each is a format with the item in it, and
-- the words in front of the item are what says whose it is: "You receive loot: %s.". A message
-- that starts with one of those is about this player and about nobody else, which is the whole
-- test. No character name is read, matched or stored, here or anywhere.
--
-- Between them they cover every way an item reaches the player: a corpse, a container, a quest
-- reward, a purchase, a craft and the post all print one of these three.
CollectorHooks.SELF_LOOT_GLOBALS = {
  "LOOT_ITEM_SELF",
  "LOOT_ITEM_SELF_MULTIPLE",
  "LOOT_ITEM_PUSHED_SELF",
  "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
  "LOOT_ITEM_CREATED_SELF",
  "LOOT_ITEM_CREATED_SELF_MULTIPLE",
}

-- The words in front of the item in one such format, or nil where the format leads with the
-- item itself: a prefix of nothing would match every line in the log. Pure.
function CollectorHooks.SelfLootPrefix(format)
  if type(format) ~= "string" then
    return nil
  end
  local prefix = format:match("^(.-)%%s")
  if type(prefix) ~= "string" or prefix == "" then
    return nil
  end
  return prefix
end

-- Whether a loot chat line says this player obtained something. prefixes is the list the caller
-- read off the client, so this is pure and a spec drives it with its own words. Pure.
function CollectorHooks.IsSelfLoot(message, prefixes)
  if type(message) ~= "string" or type(prefixes) ~= "table" then
    return false
  end
  for _, prefix in ipairs(prefixes) do
    if type(prefix) == "string" and prefix ~= "" and message:sub(1, #prefix) == prefix then
      return true
    end
  end
  return false
end

-- The argument lists to try for one quest API, most likely first. The retail shaped engine
-- wants the quest id after the API's own arguments, which is the same place in all three of
-- GetNumQuestLogChoices(questID), GetQuestLogRewardInfo(index, questID) and
-- GetQuestLogItemLink(kind, index, questID). Classic Era takes the arguments alone and raises
-- when it is handed an id it has no parameter for, so both shapes are offered and the caller
-- keeps whichever one answers. With no quest id known, and for the quest frame family which
-- never takes one, there is a single shape. Pure: the caller does the calling.
function CollectorHooks.QuestArgShapes(questId, ...)
  local base = { ... }
  base.n = select("#", ...)
  if type(questId) ~= "number" or questId <= 0 then
    return { base }
  end
  local withId = { ... }
  withId.n = base.n + 1
  withId[withId.n] = questId
  return { withId, base }
end

--------------------------------------------------------------------------------
-- Quest objectives: what a quest asks for
--------------------------------------------------------------------------------

-- The objective type the client marks an item objective with. Everything else a quest asks for
-- (a creature to kill, an object to use, an area to reach) names no item and is skipped.
CollectorHooks.OBJECTIVE_ITEM = "item"

-- The item class the build gives a quest item, which is the guard on a name match below.
CollectorHooks.QUEST_ITEM_CLASS = 12

-- Trims the spaces off both ends of a line. The client pads some objective text.
local trim = ItemTree.Util.Trim

-- One objective line pulled apart: the thing it names, how many the player has and how many the
-- quest wants. "Prideclaw Pelt: 2/10" -> "Prideclaw Pelt", 2, 10.
--
-- The counts sit either side of the name depending on the locale's own format, so both shapes
-- are read, with and without the colon, and a line with no counts at all is the name on its own.
-- Nothing here calls the client: the caller hands the text in, so a spec drives it with the
-- wordings of any locale. Pure.
function CollectorHooks.ParseObjective(text)
  if type(text) ~= "string" then
    return nil
  end
  local line = trim(text)
  if line == "" then
    return nil
  end
  local name, have, need = line:match("^(.-)%s*:%s*(%d+)%s*/%s*(%d+)$")
  if not name then
    name, have, need = line:match("^(.-)%s+(%d+)%s*/%s*(%d+)$")
  end
  if not name then
    have, need, name = line:match("^(%d+)%s*/%s*(%d+)%s+(.+)$")
  end
  if not name then
    return line, nil, nil
  end
  name = trim(name)
  if name == "" then
    return nil
  end
  return name, tonumber(have), tonumber(need)
end

-- The item objectives of every quest in the log, keyed by the lowercased name each one asks for:
--
--   { ["prideclaw pelt"] = { { questId = 92842, title = "...", name = "...", count = 10 } } }
--
-- A bucket is a list because two quests can want the same thing, and it keeps the name exactly
-- as the client wrote it so the match below can be an exact one and the key can still be found
-- whatever case the item is looked up in.
--
-- quests is what the caller read off the client, as { { questId, title, objectives } }, where an
-- objective is { text, type, numRequired }. Pure: nothing here calls anything.
function CollectorHooks.ObjectiveIndexFrom(quests)
  local index = {}
  if type(quests) ~= "table" then
    return index
  end
  for _, quest in ipairs(quests) do
    local questId = type(quest) == "table" and tonumber(quest.questId) or nil
    local objectives = questId and quest.objectives or nil
    if type(objectives) == "table" then
      for _, objective in ipairs(objectives) do
        if type(objective) == "table" and objective.type == CollectorHooks.OBJECTIVE_ITEM then
          local name, _, need = CollectorHooks.ParseObjective(objective.text)
          local count = tonumber(objective.numRequired) or need or 1
          if name then
            local bucket = index[name:lower()]
            if not bucket then
              bucket = {}
              index[name:lower()] = bucket
            end
            bucket[#bucket + 1] = {
              questId = questId,
              title = type(quest.title) == "string" and quest.title ~= "" and quest.title or nil,
              name = name,
              count = count,
            }
          end
        end
      end
    end
  end
  return index
end

-- Every quest in that index whose objective names this exact item, as the index's own entries.
--
-- The lowercased name is only how the bucket is found; the match itself is the name exactly as
-- both sides wrote it, because the objective and the item are named by the same server and a
-- near miss is a different item. Pure.
function CollectorHooks.ObjectiveMatches(itemName, index)
  local out = {}
  if type(itemName) ~= "string" or itemName == "" or type(index) ~= "table" then
    return out
  end
  for _, entry in ipairs(index[itemName:lower()] or {}) do
    if entry.name == itemName then
      out[#out + 1] = entry
    end
  end
  return out
end

-- Whether a name match is safe to write down.
--
-- An objective names an item by its name and by nothing else, and two different items can carry
-- one name, so a match on a shared name could file the quest under the wrong id. Where the name
-- is the only one of its kind the match is certain and is kept. Where it is not, only a quest
-- item is kept: the thing a quest collects is a quest item, and the ordinary item that happens
-- to share the name is not, which is the one thing that tells them apart without asking the
-- server. Pure. Both arguments are what the caller worked out; neither is read here.
function CollectorHooks.ObjectiveIsSafe(questItem, sharedName)
  if not sharedName then
    return true
  end
  if questItem == true then
    return true
  end
  return false
end

--------------------------------------------------------------------------------
-- Quest facts: the pure half (brief QF1)
--------------------------------------------------------------------------------

-- The words the English client puts around a kill goal's creature name ("Kobold Vermin slain:
-- 0/10"), used only where the client's own QUEST_MONSTERS_KILLED format cannot be read.
CollectorHooks.KILL_WORD = "slain"

-- The words a kill goal's format puts before and after its creature name, with the counts and
-- their marks taken out: "%s slain: %d/%d" -> "", "slain". nil, nil for a format with no %s. Pure.
function CollectorHooks.KillWords(format)
  if type(format) ~= "string" then
    return nil, nil
  end
  local before, after = format:match("^(.-)%%%d*%$?s(.*)$")
  if not before then
    return nil, nil
  end
  local function words(part)
    part = part:gsub("%%%d*%$?d", ""):gsub("[/:]", " ")
    return trim(part:gsub("%s+", " "))
  end
  return words(before), words(after)
end

--- The names a kill goal's text may name its creature by, most likely first: the text with its
--- counts taken off (ParseObjective), then that with the kill words taken off its ends (from
--- format, the client's QUEST_MONSTERS_KILLED, or KILL_WORD where there is none). The text is
--- only ever matched against creature names; nothing here keeps it. Pure.
function CollectorHooks.KillNames(text, format)
  local name = CollectorHooks.ParseObjective(text)
  if not name then
    return {}
  end
  local out = {}
  local before, after = CollectorHooks.KillWords(format)
  if before == nil then
    before, after = "", CollectorHooks.KILL_WORD
  end
  local bare = name
  if after ~= "" and #bare > #after + 1 and bare:sub(-#after - 1) == " " .. after then
    bare = trim(bare:sub(1, -#after - 2))
  end
  if before ~= "" and #bare > #before + 1 and bare:sub(1, #before + 1) == before .. " " then
    bare = trim(bare:sub(#before + 2))
  end
  if bare ~= name and bare ~= "" then
    out[#out + 1] = bare
  end
  out[#out + 1] = name
  return out
end

--- { [name] = id, or false where two or more creatures carry the name } over a Creatures module
--- table ({ c = { [id] = { n = string index } }, s = { strings } }, Core/Creatures.lua). Pure.
function CollectorHooks.CreatureNameIds(source)
  local out = {}
  local strings = type(source) == "table" and type(source.s) == "table" and source.s or nil
  local rows = type(source) == "table" and type(source.c) == "table" and source.c or nil
  if not strings or not rows then
    return out
  end
  for id, row in pairs(rows) do
    local name = type(id) == "number" and type(row) == "table" and strings[row.n] or nil
    if type(name) == "string" and name ~= "" then
      if out[name] == nil then
        out[name] = id
      elseif out[name] ~= id then
        out[name] = false
      end
    end
  end
  return out
end

--- The name rule: the creature id a kill goal names, where exactly one creature in the installed
--- data carries one of names (KillNames' answer, tried in order). A name two creatures share
--- proves nothing and ends the search. byName is CreatureNameIds' answer. Pure.
function CollectorHooks.UniqueCreatureId(names, byName)
  if type(names) ~= "table" or type(byName) ~= "table" then
    return nil
  end
  for _, name in ipairs(names) do
    local id = byName[name]
    if id == false then
      return nil
    end
    if type(id) == "number" then
      return id
    end
  end
  return nil
end

--- A quest's goals as Collector.QuestGoals takes them, and how far along each is, out of what
--- C_QuestLog.GetQuestObjectives answered: { { type, numRequired, creatureId } } and
--- { numFulfilled }. read(value) answers whether one client value may be read (Util.CanRead);
--- creatureOf(text) answers a kill goal's proven creature id, or nil, and is the only thing
--- handed an objective's text. A value that cannot be read is absent. Pure.
function CollectorHooks.QuestGoalsFrom(objectives, read, creatureOf)
  local goals, progress = {}, {}
  if type(objectives) ~= "table" then
    return goals, progress
  end
  read = type(read) == "function" and read or function()
    return true
  end
  for index, objective in ipairs(objectives) do
    local goal = {}
    if type(objective) == "table" then
      local kind = objective.type
      if read(kind) and type(kind) == "string" then
        goal.type = kind
      end
      local need = objective.numRequired
      if read(need) and type(need) == "number" then
        goal.numRequired = need
      end
      local have = objective.numFulfilled
      if read(have) and type(have) == "number" then
        progress[index] = have
      end
      if goal.type == "monster" and type(creatureOf) == "function" then
        local text = objective.text
        if read(text) and type(text) == "string" then
          goal.creatureId = creatureOf(text)
        end
      end
    end
    goals[index] = goal
  end
  return goals, progress
end

--- The ledger rule: which kill goal a kill moved, and the creature that did it. before and after
--- are a quest's goals progress (QuestGoalsFrom's second answer) either side of a quest update;
--- goals the store's goals list (Collector.QuestGoals' shape); kills { { id, when } } the ledger's
--- recent kills; now the clock; window the seconds a kill counts for. Answers the goal's index
--- and the creature id where exactly one kill goal with no creature yet moved and every kill in
--- the window was of one creature, else nil. Pure.
function CollectorHooks.KillGoalFrom(before, after, goals, kills, now, window)
  if type(before) ~= "table" or type(after) ~= "table" or type(goals) ~= "table" or type(kills) ~= "table" then
    return nil
  end
  local moved = nil
  for index, goal in ipairs(goals) do
    local was, is = tonumber(before[index]), tonumber(after[index])
    if type(goal) == "table" and goal.t == "monster" and was and is and is > was then
      if moved or goal.c ~= nil then
        return nil
      end
      moved = index
    end
  end
  if not moved then
    return nil
  end
  local creature = nil
  for _, kill in ipairs(kills) do
    local when, id = tonumber(kill.when), tonumber(kill.id)
    if when and id and now - when >= 0 and now - when <= window then
      if creature and creature ~= id then
        return nil
      end
      creature = id
    end
  end
  if not creature then
    return nil
  end
  return moved, creature
end

--------------------------------------------------------------------------------
-- Vendor prices: what the open merchant window asks for one of its rows
--------------------------------------------------------------------------------

-- A whole number above nought, or nil. The window's amounts go through this so a price of
-- nothing, a negative or a string never reaches a record.
local function positiveWhole(value)
  value = tonumber(value)
  if not value or value < 1 or value ~= value or value == math.huge then
    return nil
  end
  return math.floor(value)
end

-- The cost of one merchant row as a record keeps it: ids and amounts only.
--
--   { copper = 50000, currency = { [3402] = 200 }, items = { [1234] = 3 } }
--
-- copper is the window's own money price. costs is the list the caller read off
-- GetMerchantItemCostItem, as { { amount = n, link = "..." } }: a currency cost is named by its
-- link, |Hcurrency:3402|h[Merchant's Favor]|h, and an item cost by an item link. An entry whose
-- link names neither is dropped, since a name alone is not an id. Each part is left out when
-- the window said nothing for it, and the whole answer is nil when it said nothing at all. Pure.
function CollectorHooks.MerchantCost(copper, costs)
  local cost = {}
  local any = false
  copper = positiveWhole(copper)
  if copper then
    cost.copper = copper
    any = true
  end
  for _, entry in ipairs(type(costs) == "table" and costs or {}) do
    local amount = type(entry) == "table" and positiveWhole(entry.amount) or nil
    local link = type(entry) == "table" and entry.link or nil
    if amount and type(link) == "string" then
      local currencyId = positiveWhole(link:match("currency:(%d+)"))
      local itemId = not currencyId and positiveWhole(link:match("item:(%d+)")) or nil
      if currencyId then
        cost.currency = cost.currency or {}
        cost.currency[currencyId] = (cost.currency[currencyId] or 0) + amount
        any = true
      elseif itemId then
        cost.items = cost.items or {}
        cost.items[itemId] = (cost.items[itemId] or 0) + amount
        any = true
      end
    end
  end
  if not any then
    return nil
  end
  return cost
end

-- Brief M3: where the player stands, as a vendor record keeps it, out of what the client's map
-- calls answered: map is C_Map.GetBestMapForUnit's uiMap id and x, y the FRACTIONS
-- C_Map.GetPlayerMapPosition answered (0 to 1), turned into percent rounded to a tenth of one.
-- nil for anything else, and for 0, 0, which is what a client with no position to give answers.
-- Pure.
function CollectorHooks.MapPosition(map, x, y)
  map, x, y = positiveWhole(map), tonumber(x), tonumber(y)
  if not map or not x or not y or x ~= x or y ~= y then
    return nil
  end
  if x < 0 or x > 1 or y < 0 or y > 1 or (x == 0 and y == 0) then
    return nil
  end
  return { map = map, x = math.floor(x * 1000 + 0.5) / 10, y = math.floor(y * 1000 + 0.5) / 10 }
end

-- Brief Q8: the quest id a QUEST_ACCEPTED event names. The retail shaped engine the Forever client
-- runs hands over the quest id alone; Classic Era hands over the log index and then the quest id.
-- So a second number is the id, and a lone one is. Brief Q9: any values after the second are
-- ignored, so a (questLogIndex, questId, ...) form reads the same. nil for anything else. Pure.
function CollectorHooks.AcceptedQuestId(first, second)
  local questId = tonumber(second) or tonumber(first)
  if not questId or questId <= 0 or questId ~= math.floor(questId) then
    return nil
  end
  return questId
end

-- Brief Q8: the NPC a quest window is about, as Collector.QuestNpcRecord takes it: the creature id
-- where the "npc" unit is a creature (ref is Privacy.SanitiseGuid's { kind, id }), the name the
-- client shows over it, and where the player stands (CollectorHooks.MapPosition's answer). Brief
-- QH1: a world object that gives or takes a quest (a wanted poster, a chest, a sign: a GameObject
-- GUID) is kept by its object id, objectId, the way a creature is kept by npcId. An item that offers
-- a quest keeps its name and place and gives no id, because its id is not a creature's or an
-- object's and no page could open on it. nil where there is nothing to name. Pure.
function CollectorHooks.QuestNpcFields(ref, name, pos)
  local npcId, objectId = nil, nil
  if type(ref) == "table" and (ref.kind == "Creature" or ref.kind == "Vehicle") then
    npcId = positiveWhole(ref.id)
  elseif type(ref) == "table" and ref.kind == "GameObject" then
    objectId = positiveWhole(ref.id)
  end
  if type(name) ~= "string" or name == "" then
    name = nil
  end
  if not npcId and not objectId and not name then
    return nil
  end
  return { npcId = npcId, objectId = objectId, name = name, pos = type(pos) == "table" and pos or nil }
end

-- Brief BL14: a seen boss as Collector.SeenBossRecord takes it, out of what the client showed of
-- one unit: ref is Privacy.SanitiseGuid's { kind, id }, and only a Creature counts (a player, a
-- pet, a vehicle or an object never does); name the name over it; mapId the instance's map id
-- (GetInstanceInfo's eighth answer); level UnitLevel's answer. nil for anything but a creature
-- with an id and a name. Pure.
function CollectorHooks.SeenBossFields(ref, name, mapId, level)
  if type(ref) ~= "table" or ref.kind ~= "Creature" then
    return nil
  end
  local npcId = positiveWhole(ref.id)
  if not npcId or type(name) ~= "string" or name == "" then
    return nil
  end
  return { npcId = npcId, name = name, mapId = positiveWhole(mapId), level = positiveWhole(level) }
end

-- Brief R9: looks like "Thrall-Frostmourne", a character's name with its realm. The collector's
-- own check (Collector.LooksLikeCharacter) where it is loaded, the same pattern where it is not.
local function characterShaped(value)
  local Collector = ItemTree.Collector
  if type(Collector) == "table" and type(Collector.LooksLikeCharacter) == "function" then
    return Collector.LooksLikeCharacter(value) and true or false
  end
  return type(value) == "string" and value:match("^%u%l+%-%u%l+$") ~= nil
end

-- Brief R9: the longest NPC or node name kept, in bytes (Core/Places.lua Places.MAX_LABEL).
CollectorHooks.MAX_NAME = 64

-- A name the client showed over an NPC or a node, as a record keeps it, or nil: 1 to MAX_NAME bytes
-- of text with no control characters and no "|", and nothing shaped like a character's name.
-- Pure.
function CollectorHooks.ShownName(value)
  if type(value) ~= "string" or value == "" or #value > CollectorHooks.MAX_NAME then
    return nil
  end
  if value:find("[%c|]") or characterShaped(value) then
    return nil
  end
  return value
end

-- Brief R9: what a trainer trains as the record keeps it, or nil: one short phrase of letters,
-- spaces, apostrophes and hyphens ("Leatherworking", "First Aid", "Beast Mastery"), at most 32
-- bytes, never shaped like a character's name. Pure.
CollectorHooks.MAX_TRAINS = 32

function CollectorHooks.TrainsWord(value)
  if type(value) ~= "string" or #value > CollectorHooks.MAX_TRAINS then
    return nil
  end
  if not value:match("^%a[%a '%-]*$") or characterShaped(value) then
    return nil
  end
  return value
end

-- Brief R9: a trainer or a stable master as the places store takes it: the creature id (ref is
-- Privacy.SanitiseGuid's { kind, id }, and only a Creature counts), the name the client showed over
-- it and, for a trainer, what it trains. nil for anything but a creature with an id, and nil
-- altogether where the name is shaped like a character's: such a unit is no NPC and nothing of it
-- is kept. A name or a trade the checks refuse is left out. Pure.
function CollectorHooks.NpcPlaceFields(ref, name, trains)
  if type(ref) ~= "table" or ref.kind ~= "Creature" then
    return nil
  end
  local npcId = positiveWhole(ref.id)
  if not npcId or characterShaped(name) or characterShaped(trains) then
    return nil
  end
  return { npcId = npcId, n = CollectorHooks.ShownName(name), k = CollectorHooks.TrainsWord(trains) }
end

-- Brief R9: the spells whose cast names a gathering node, a chest or another lootable object as
-- its target. UNIT_SPELLCAST_SENT hands over the target's name as the client shows it, and for
-- these spells (each an OPEN_LOCK effect, SpellEffect.Effect 33, so its target is always a game
-- object or an item and never a unit) that name is the node's. Read off the Forever build
-- 1.60.1.70170's SpellEffect table (the pipeline's own copy): every OPEN_LOCK spell whose lock
-- type is Herbalism (2), Mining (3), Open (5), Quick Open (10), Open Tinkering (12 and 209), Open
-- Kneeling (13) or Slow Open (17). Classic Era carries the same ids for the ones it has. A cast
-- of any other spell names nothing, so a player's name can never reach a record this way.
CollectorHooks.GATHER_SPELLS = {
  -- Herbalism
  [2366] = true,
  [2368] = true,
  [2369] = true,
  [2371] = true,
  [3570] = true,
  [11993] = true,
  [1312650] = true,
  -- Mining
  [2575] = true,
  [2576] = true,
  [2577] = true,
  [2578] = true,
  [2579] = true,
  [3564] = true,
  [10248] = true,
  [1264639] = true,
  -- Opening, Quick Open, Open Tinkering, Open Kneeling and Slow Open
  [3365] = true,
  [6247] = true,
  [6477] = true,
  [6478] = true,
  [17667] = true,
  [21651] = true,
  [22810] = true,
  [26868] = true,
  [1221363] = true,
  [1236393] = true,
  [1269930] = true,
  [1278934] = true,
  [1308379] = true,
  [1309310] = true,
  [1309978] = true,
  [1310156] = true,
  [1310491] = true,
  [1322629] = true,
}

-- Brief SK1 (owner ruling 2026-10-15): the spells whose cast takes loot off a CREATURE without it
-- being a drop, by the record kind that loot is filed under. Read off the pipeline's copy of the
-- SpellEffect table (Forever builds 1.60.1.70374 and 1.60.1.70425, the same rows; Classic Era
-- 1.15.9.69722 carries the same Skinning and Pick Pocket ids): every spell with Effect 95
-- (SKINNING, the loot of a creature's corpse once its own loot is gone), whose EffectMiscValue_0
-- says which (0 Skinning, 1 Herb Gathering, 2 Mining, 3 Engineering, the last three on the Forever
-- builds alone), and every spell with Effect 71 (PICKPOCKET, the loot of a living creature).
-- Skinning files as "skin" (Skinned from) and Pick Pocket as "pickpocket" (Pickpocketed from); a
-- creature's herbs, ore or parts file as "gather" from that creature (Gathered from): the share
-- format's one gathering kind, which has no word for which of the three it was. Any other cast
-- leaves a creature's loot a drop.
CollectorHooks.CREATURE_LOOT_SPELLS = {
  -- Skinning (Effect 95, misc 0), Apprentice to Artisan
  [8613] = "skin",
  [8617] = "skin",
  [8618] = "skin",
  [10768] = "skin",
  -- Mining (misc 2), Herb Gathering (misc 1) and Engineering (misc 3) on a creature
  [1235230] = "gather",
  [1235236] = "gather",
  [1235244] = "gather",
  -- Pick Pocket (Effect 71), and "Pickpocket (PT)", the table's one other spell of that effect
  [921] = "pickpocket",
  [5967] = "pickpocket",
}

-- The kinds above, as a set: what ClassifyLootSource files a creature's loot under in place of a
-- drop. Each one is a kind Core/Collector.lua takes.
CollectorHooks.CREATURE_LOOT_KINDS = { skin = true, pickpocket = true, gather = true }

-- Brief R12: the first line of a tooltip's data, as the client's tooltip data processor hands it
-- over (data.lines[1].leftText), or nil. Nothing but the first line is looked at. Pure.
function CollectorHooks.TooltipFirstLine(data)
  local lines = type(data) == "table" and data.lines or nil
  local first = type(lines) == "table" and lines[1] or nil
  local text = type(first) == "table" and first.leftText or nil
  -- Brief SV1: a secret first line (a unit's name in combat) is no line.
  if not canRead(text) then
    return nil
  end
  if type(text) == "string" and text ~= "" then
    return text
  end
  return nil
end

-- Brief R12: whether tooltip data may be a world object's, by what it states of itself: a data
-- type other than objectType (Enum.TooltipDataType.Object, where the client has one) is not, and
-- neither is a guid that is not a GameObject's (a unit, an item). Data that states neither may be.
-- Pure.
function CollectorHooks.IsObjectData(data, objectType)
  if type(data) ~= "table" then
    return true
  end
  -- Brief SV1: data whose type or guid the client keeps secret states nothing we may read, and a
  -- world object's never is: it is not taken as one.
  local dataType = data.type
  if not canRead(dataType) then
    return false
  end
  if dataType ~= nil and objectType ~= nil and dataType ~= objectType then
    return false
  end
  local guid = data.guid
  if not canRead(guid) then
    return false
  end
  if type(guid) == "string" and guid ~= "" and not guid:match("^GameObject%-") then
    return false
  end
  return true
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- unpack is a global on the client's Lua 5.1; the browser harness runs 5.3, where it moved into
-- the table library. Read the same way UI/Tooltip.lua reads every other optional global.
local unpackArgs = rawget(_G, "unpack") or rawget(table, "unpack")

-- Drops pcall's ok flag and hands back every return value, or nothing when the call raised.
local function pass(ok, ...)
  if ok then
    return ...
  end
  return nil
end

-- One client API call by name, type checked and pcall'd. An API this client does not carry and
-- one that raises on these arguments both read as nothing found. Every return value is kept,
-- because the loot and quest APIs answer with several.
local function call(name, ...)
  local fn = rawget(_G, name)
  if type(fn) ~= "function" then
    return nil
  end
  return pass(pcall(fn, ...))
end

-- Brief SV1: one client read (UnitGUID, UnitName, UnitLevel and the like, whose answers the client
-- keeps secret for a creature in combat), its first answer only, or nil where it cannot be read.
local function readCall(name, unit)
  local value = call(name, unit)
  if not canRead(value) then
    return nil
  end
  return value
end

-- Brief C20: the item id of an Item GUID the loot window names (the container being opened from
-- the bags, still in its slot while the window is open), out of the client's
-- C_Item.GetItemIDByGUID, the same read Core/Ledger.lua's loot window makes. A local lookup of an
-- item the player holds, never a query to the server. nil where the client cannot say.
function CollectorHooks.ItemIdOfGuid(guid)
  local api = rawget(_G, "C_Item")
  if type(guid) ~= "string" or type(api) ~= "table" or type(api.GetItemIDByGUID) ~= "function" then
    return nil
  end
  local ok, id = pcall(api.GetItemIDByGUID, guid)
  if not ok then
    return nil
  end
  return itemIdOrNil(id)
end

-- One loot window's Item GUID reader: CollectorHooks.ItemIdOfGuid asked once per GUID however
-- many slots name it (a container's every slot names the same one).
local function windowItemIdOf()
  local seen = {}
  return function(guid)
    local held = seen[guid]
    if held == nil then
      held = CollectorHooks.ItemIdOfGuid(guid) or false
      seen[guid] = held
    end
    return held or nil
  end
end

local function collector()
  local instance = ItemTree.collector
  if not instance or type(instance.Record) ~= "function" then
    return nil
  end
  return instance
end

-- One sighting, stored. Record sanitises and writes, and it is called once per loot slot, per
-- vendor row and per quest reward, so a raise in there would cost every row after it too.
local function record(kind, entry)
  if not CollectorHooks.Enabled() then
    return false
  end
  local instance = collector()
  if not instance or not entry or not entry.itemId then
    return false
  end
  local ok, stored = pcall(instance.Record, instance, kind, entry)
  return ok and stored and true or false
end

-- Not Util.ItemIdFromLink (Core/Util.lua): this one asks Tooltip.ItemIdFromLink first and falls
-- back to the plain match only where that has no answer.
local function itemIdFromLink(link)
  local tooltip = ItemTree.Tooltip
  if tooltip and type(tooltip.ItemIdFromLink) == "function" then
    local ok, id = pcall(tooltip.ItemIdFromLink, link)
    if ok and id then
      return id
    end
  end
  if not canRead(link) or type(link) ~= "string" then
    return nil
  end
  local id = link:match("item:(%d+)")
  return id and tonumber(id) or nil
end

-- Whether the item rows are loaded (brief U3: they ship in the load on demand ItemTree_Data). True
-- for data that ships everything in ItemTree, and when Data cannot say.
local function itemRowsLoaded()
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.OnDemandLoaded) ~= "function" then
    return true
  end
  local ok, loaded = pcall(data.OnDemandLoaded, data)
  return not ok or loaded ~= false
end

-- The client's facts for one item (UI/Client.lua ItemFacts), or nil. Declared further down.
local itemFacts

-- Quality from the shipped data, so the collector never depends on a client function whose
-- return order differs between Classic Era and the modern client. A data module that is still
-- building reads as no quality rather than costing the record.
--
-- Brief U3: while the item rows are not loaded the client's own facts answer instead
-- (ItemTree.ItemFacts reads the modern and the classic shapes itself), so a loot window or a
-- vendor at login never loads the data addon.
local function qualityOf(itemId)
  if not itemRowsLoaded() then
    local facts = itemFacts(itemId)
    return facts and tonumber(facts.quality) or nil
  end
  local data = ItemTree.Data
  if not data or type(data.GetItem) ~= "function" then
    return nil
  end
  local ok, item = pcall(data.GetItem, data, itemId)
  if not ok or type(item) ~= "table" then
    return nil
  end
  return item.q
end

-- A count straight off the client, as a loop limit. A client that answers with a string, a
-- table or nothing at all must not raise "'for' limit must be a number" inside the handler.
local function countOf(value)
  local count = tonumber(value)
  if not count or count < 1 then
    return 0
  end
  return math.floor(count)
end

local function zoneText()
  return call("GetRealZoneText")
end

-- Brief R15: the uiMap the player is on, read once per window beside the zone text. A record keeps
-- the map id in place of the text where the map's own name is that text (Collector.Place), and the
-- text where it is not or where this answers nothing (a client without the call).
local function mapNow()
  local api = rawget(_G, "C_Map")
  if type(api) ~= "table" or type(api.GetBestMapForUnit) ~= "function" then
    return nil
  end
  local ok, map = pcall(api.GetBestMapForUnit, "player")
  if ok and type(map) == "number" then
    return map
  end
  return nil
end

-- Drops the memoised tooltip block for every item, which is what makes a fact the collector has
-- just learned show on the very next hover rather than after a reload. UI/Tooltip.lua builds a
-- block once per item and keeps it, so a block that said "No known uses" would
-- otherwise outlive the record that answers it.
local function dropTooltipCache()
  local tooltip = ItemTree.Tooltip
  if tooltip and type(tooltip.ClearCache) == "function" then
    pcall(tooltip.ClearCache)
  end
end

-- NPC name only when the client is already showing it as the current target, and only when
-- the GUID is a creature. Player names can never reach this path.
local function targetNameFor(guid)
  if not guid then
    return nil
  end
  local targetGuid = readCall("UnitGUID", "target")
  if targetGuid == nil or targetGuid ~= guid then
    return nil
  end
  local ref = sanitiseGuid(guid)
  if not ref or (ref.kind ~= "Creature" and ref.kind ~= "Vehicle") then
    return nil
  end
  return readCall("UnitName", "target")
end

--------------------------------------------------------------------------------
-- Discoveries
--------------------------------------------------------------------------------

-- Ids the client has already been asked to load, so a callback that finds the item still
-- unnamed cannot ask again and loop. In memory only, one table of ids for the session.
CollectorHooks.asked = {}

-- Everything the running client knows about an item, or nil. UI/Client.lua fills
-- ItemTree.ItemFacts in; a load without it answers nothing and records nothing.
function itemFacts(itemId)
  local resolver = ItemTree.ItemFacts
  if type(resolver) ~= "function" then
    return nil
  end
  local ok, facts = pcall(resolver, itemId)
  if not ok or type(facts) ~= "table" or type(facts.name) ~= "string" or facts.name == "" then
    return nil
  end
  return facts
end

-- Notes that somebody on the realm has discovered an item this build withholds.
--
-- The whole signal is the client answering with a name for an id Data:IsUndiscovered says is
-- sealed: WoW Forever withholds an item's details until it has dropped for someone on the
-- realm, so a name means it has dropped. What is written down is the item id, the item's name,
-- its quality and the data build, plus the realm id (brief E66) and the character's name
-- (brief E79, the one sanctioned exception: it is drawn on the Discoveries row and its tooltip
-- and reaches no report, debug or trace line), through Core/Privacy.lua like every other record
-- (Core/Collector.lua RecordDiscovery). Nothing about the account is read, stored or printed.
--
-- Called from every item tooltip, every loot slot and every quest reward, so the ordinary
-- answer has to be cheap: an item already noted, an id the build does not withhold and a
-- collector that is turned off each cost a lookup or two and stop.
--
-- how names the path this call is on (CollectorHooks.HOW_*), and is the only thing the record
-- learns beyond what the item is: whether the player obtained it or only saw it named. An item
-- already noted is not written again, with the one exception that is the point of the argument.
-- A record saying the realm found it is promoted the moment the player obtains the item, keeping
-- the moment it was first noted.
function CollectorHooks.NoteItem(itemId, how)
  local id = tonumber(itemId)
  if not id or not CollectorHooks.Enabled() then
    return false
  end
  -- The same two moments are the cheapest place to ask the other question: is this one item
  -- something a quest in the log is asking for. It runs on the single item paths only, so a
  -- merchant window with forty rows never walks the quest log forty times; see SINGLE_ITEM_HOW
  -- and CollectorHooks.NoteQuestObjective, which is declared further down this file.
  if CollectorHooks.SINGLE_ITEM_HOW[how] then
    pcall(CollectorHooks.NoteQuestObjective, id)
  end
  local instance = collector()
  if not instance or type(instance.RecordDiscovery) ~= "function" then
    return false
  end
  -- Brief R3: HasDiscovery, because a record the data build names keeps no name of its own.
  local noted = type(instance.HasDiscovery) == "function" and instance:HasDiscovery(id)
  if noted or (type(instance.DiscoveredName) == "function" and instance:DiscoveredName(id)) then
    if type(instance.UpgradeDiscovery) == "function" then
      return instance:UpgradeDiscovery(id, how) and true or false
    end
    return false
  end
  local data = ItemTree.Data
  if not data or type(data.IsUndiscovered) ~= "function" then
    return false
  end
  local ok, sealed = pcall(data.IsUndiscovered, data, id)
  if not ok or sealed ~= true then
    return false
  end
  local facts = itemFacts(id)
  if not facts then
    -- The client has the item and has not loaded its text yet. Ask once, and look again when
    -- the answer lands; a second miss is the end of it for this session.
    if not CollectorHooks.asked[id] then
      CollectorHooks.asked[id] = true
      local request = ItemTree.RequestItemData
      if type(request) == "function" then
        pcall(request, id, function()
          CollectorHooks.NoteItem(id, how)
        end)
      end
    end
    return false
  end
  if not instance:RecordDiscovery(id, facts.name, facts.quality, how) then
    return false
  end
  -- The tooltip block for this id said "Undiscovered in Forever" and is memoised per item, so
  -- the cached block has to go or the name will not show until the next hover after a reload.
  dropTooltipCache()
  return true
end

-- The prefixes read off this client, built once. A client that names none of the globals
-- answers with an empty list, and then nothing is ever read as obtained, which leaves every
-- discovery on the weaker claim rather than on a guess.
local selfLootPrefixes = nil

function CollectorHooks.SelfLootPrefixes()
  if selfLootPrefixes then
    return selfLootPrefixes
  end
  local out = {}
  for _, name in ipairs(CollectorHooks.SELF_LOOT_GLOBALS) do
    local prefix = CollectorHooks.SelfLootPrefix(rawget(_G, name))
    if prefix then
      out[#out + 1] = prefix
    end
  end
  selfLootPrefixes = out
  return out
end

-- Drops the prefixes (tests, and a client that swaps its locale mid session).
function CollectorHooks.ResetSelfLoot()
  selfLootPrefixes = nil
end

-- One CHAT_MSG_LOOT line. This is the only place the addon learns that the player has actually
-- obtained something rather than merely been shown it, and it learns it from the client's own
-- words ("You receive loot:", "You receive item:", "You create:"), which between them cover a
-- corpse, a container, a quest reward, a purchase, a craft and the post.
--
-- A line about anybody else is not matched at all: the test is the words in front of the item,
-- never a name, so no character name is read here. Returns whether a discovery was written or
-- promoted, which is what tells the Discoveries pane to redraw.
function CollectorHooks.OnChatLoot(message)
  if not CollectorHooks.Enabled() then
    return false
  end
  if not CollectorHooks.IsSelfLoot(message, CollectorHooks.SelfLootPrefixes()) then
    return false
  end
  local itemId = itemIdFromLink(message)
  if not itemId then
    return false
  end
  -- Brief QH1: a line that says the server handed the item over (LOOT_ITEM_PUSHED_SELF and its
  -- _MULTIPLE), held for the hand-over rule (CollectorHooks.NotePush, further down this file).
  local single, multiple = CollectorHooks.PushedFormats()
  local pushed = CollectorHooks.PushedCount(message, single or nil, multiple or nil)
  if pushed then
    pcall(CollectorHooks.NotePush, itemId, pushed)
  end
  return CollectorHooks.NoteItem(itemId, CollectorHooks.HOW_OBTAINED)
end

--------------------------------------------------------------------------------
-- Loot
--------------------------------------------------------------------------------

-- Pending disenchant: pendingDisenchant is true once the cast succeeds and is consumed by
-- the next loot window; disenchantTarget is the item that went in, when it could be read.
--
-- Brief C21 (the 2026-10-07 remine: five disenchant records from two players named item 0 as
-- what was disenchanted, and the pipeline rightly refused them; "something gave Strange Dust"
-- says nothing). The cursor read below was the only one, and it answers only when the player
-- DRAGS the item onto the spell: the usual way, casting Disenchant and clicking the item in the
-- bag, leaves the cursor holding the spell, not the item, so the target was never known. Three
-- reads now, in order, the first that answers:
--   1. the cursor (GetCursorInfo "item"), the drag;
--   2. the bag slot clicked while the spell was targeting: a post hook on the client's own
--      C_Container.UseContainerItem (and the Era global), which is what a bag button calls to
--      hand the slot to a targeting spell (hooksecurefunc, the additive hook; nothing of the
--      client's is called from here). Only while SpellIsTargeting says a spell is, and only the
--      slot's item id (CollectorHooks.targetingItem, held TARGET_MAX_AGE seconds);
--   3. the cast's own target name (UNIT_SPELLCAST_SENT's second value is the item's name for an
--      item targeted spell), matched against the links of the items in the bags, one walk, and
--      taken only where exactly one item id carries that name (CollectorHooks.MatchNamedItem).
-- And a Disenchant window whose target is still unknown writes NO record (CollectorHooks.
-- disenchantMisses counts it for the probe): a result with no source is worse than none.
CollectorHooks.pendingDisenchant = nil
CollectorHooks.disenchantTarget = nil
CollectorHooks.TARGET_MAX_AGE = 10
CollectorHooks.targetingItem = nil
CollectorHooks.disenchantMisses = 0
CollectorHooks.BAGS = { 0, 1, 2, 3, 4 }

--- The one item id among slots ({ id, link } each, the bags' contents) whose link names name
--- ("[name]"), or nil where none or more than one does. Pure.
function CollectorHooks.MatchNamedItem(name, slots)
  if type(name) ~= "string" or name == "" or type(slots) ~= "table" then
    return nil
  end
  local needle = "[" .. name .. "]"
  local found = nil
  for _, slot in ipairs(slots) do
    local id = tonumber(type(slot) == "table" and slot.id or nil)
    local link = type(slot) == "table" and slot.link or nil
    if id and type(link) == "string" and link:find(needle, 1, true) then
      if found ~= nil and found ~= id then
        return nil
      end
      found = id
    end
  end
  return found
end

-- The items in the bags as { id, link } each, out of C_Container.GetContainerItemInfo (its
-- itemID and hyperlink, each through canRead) or the Era pair GetContainerItemID and
-- GetContainerItemLink. A local read of what the player holds, never a query.
function CollectorHooks.BagSlots()
  local slots = {}
  local container = rawget(_G, "C_Container")
  local api = type(container) == "table" and container or nil
  local countSlots = api and api.GetContainerNumSlots or rawget(_G, "GetContainerNumSlots")
  if type(countSlots) ~= "function" then
    return slots
  end
  for _, bag in ipairs(CollectorHooks.BAGS) do
    local ok, count = pcall(countSlots, bag)
    count = ok and canRead(count) and tonumber(count) or 0
    for slot = 1, count do
      local id, link = nil, nil
      if api and type(api.GetContainerItemInfo) == "function" then
        local okInfo, info = pcall(api.GetContainerItemInfo, bag, slot)
        if okInfo and type(info) == "table" and canRead(info.itemID) and canRead(info.hyperlink) then
          id, link = tonumber(info.itemID), info.hyperlink
        end
      else
        id = tonumber(call("GetContainerItemID", bag, slot))
        link = call("GetContainerItemLink", bag, slot)
      end
      if id and type(link) == "string" then
        slots[#slots + 1] = { id = id, link = link }
      end
    end
  end
  return slots
end

--- The item that went into the Disenchant cast: itemId where the caller knows it, else the cursor,
--- else the bag slot the targeting spell was handed, else targetName (the cast's target) matched
--- against the bags. Answers the id held, or nil.
function CollectorHooks.RememberDisenchantTarget(itemId, targetName)
  if itemId then
    CollectorHooks.disenchantTarget = itemId
    return itemId
  end
  if CollectorHooks.disenchantTarget then
    return CollectorHooks.disenchantTarget
  end
  local kind, cursorItemId, link = call("GetCursorInfo")
  if kind == "item" then
    CollectorHooks.disenchantTarget = tonumber(cursorItemId) or itemIdFromLink(link)
  end
  if not CollectorHooks.disenchantTarget then
    CollectorHooks.disenchantTarget = CollectorHooks.TakeTargetingItem()
  end
  if not CollectorHooks.disenchantTarget then
    local name = CollectorHooks.ShownName(targetName)
    if name then
      CollectorHooks.disenchantTarget = CollectorHooks.MatchNamedItem(name, CollectorHooks.BagSlots())
    end
  end
  return CollectorHooks.disenchantTarget
end

function CollectorHooks.ClearDisenchant()
  CollectorHooks.pendingDisenchant = nil
  CollectorHooks.disenchantTarget = nil
  CollectorHooks.targetingItem = nil
end

function CollectorHooks.OnLootOpened()
  if not CollectorHooks.Enabled() then
    return 0
  end
  local slots = countOf(call("GetNumLootItems"))
  local zone = zoneText()
  local mapId = mapNow()
  -- Brief R9: the node the player's own gathering cast named, taken once for the window. It names
  -- the first game object source the window lists and any other source of that same id, never a
  -- second object.
  local nodeName = CollectorHooks.TakeNodeName()
  local nodeId = nil
  -- Brief SK1: a window the player's own Skinning, Pick Pocket or creature gathering cast opened.
  local creatureKind = CollectorHooks.CreatureLootKind()
  local written = 0
  local itemIdOf = windowItemIdOf()
  for slot = 1, slots do
    local link = call("GetLootSlotLink", slot)
    local itemId = itemIdFromLink(link)
    if itemId then
      CollectorHooks.NoteItem(itemId, CollectorHooks.HOW_LOOT_WINDOW)
      -- Brief QH1: the one quest in the log asking for this item, carried on the loot record (its
      -- o). The ledger's own objective set, kept until the log changes; never a walk per slot.
      local okQuest, lootQuest = pcall(CollectorHooks.ObjectiveQuestOf, itemId)
      lootQuest = okQuest and lootQuest or nil
      local _, _, quantity = call("GetLootSlotInfo", slot)
      local sources = { call("GetLootSourceInfo", slot) }
      local wrote = false
      for index = 1, #sources, 2 do
        local guid, count = sources[index], sources[index + 1]
        -- Brief SV1: a count the client keeps secret is no count (the slot's quantity stands in).
        if not canRead(count) then
          count = nil
        end
        local kind, sourceKind, sourceId = CollectorHooks.ClassifyLootSource(guid, nil, itemIdOf, creatureKind)
        if kind then
          wrote = true
        end
        -- Brief C20: a container whose item id the client could not name is not recorded at all.
        if kind and sourceId then
          local sourceName = nil
          if sourceKind == "object" then
            nodeId = nodeId or sourceId
            if nodeName and sourceId == nodeId then
              sourceName = nodeName
            end
          else
            sourceName = targetNameFor(guid)
          end
          if
            record(kind, {
              itemId = itemId,
              count = count or quantity or 1,
              sourceKind = sourceKind,
              sourceId = sourceId,
              sourceName = sourceName,
              zone = zone,
              mapId = mapId,
              quality = qualityOf(itemId),
              quest = lootQuest,
            })
          then
            written = written + 1
          end
        end
      end
      -- No usable source GUID. The only case worth keeping is the loot window that follows
      -- a Disenchant cast, which has no source at all. Brief C21: and only where the item that
      -- went in is known; a result with no source is counted as a miss and not written.
      if not wrote and CollectorHooks.pendingDisenchant and not CollectorHooks.disenchantTarget then
        CollectorHooks.disenchantMisses = CollectorHooks.disenchantMisses + 1
      elseif not wrote and CollectorHooks.pendingDisenchant then
        if
          record("disenchant", {
            itemId = itemId,
            count = quantity or 1,
            sourceKind = "item",
            sourceId = CollectorHooks.disenchantTarget,
            zone = zone,
            mapId = mapId,
            quality = qualityOf(itemId),
          })
        then
          written = written + 1
        end
      end
    end
  end
  -- Brief R14: a gather's loot window is where the node really is. Only for a window that listed a
  -- game object and a name the player's own gathering cast named.
  if nodeName and nodeId then
    CollectorHooks.NoteNodeGather(nodeName, mapId)
  end
  return written
end

--------------------------------------------------------------------------------
-- Vendors
--------------------------------------------------------------------------------

-- The window's money price for one row, in copper, or nil. The Forever beta runs the retail
-- MerchantFrame (wow-ui-source branch forever, Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua),
-- which reads C_MerchantFrame.GetItemInfo(index) and gets a table: { name, texture, price,
-- stackCount, numAvailable, isPurchasable, isUsable, hasExtendedCost, currencyID, ... }. That is
-- tried first. The classic shape, GetMerchantItemInfo(index), answers positionally with the
-- price third (name, texture, price, quantity, numAvailable, isPurchasable, isUsable,
-- extendedCost), and is the fallback. Both read the open window's own row; neither asks the
-- server about an item.
local function merchantCopper(index)
  local api = rawget(_G, "C_MerchantFrame")
  if type(api) == "table" and type(api.GetItemInfo) == "function" then
    local ok, info = pcall(api.GetItemInfo, index)
    if ok and type(info) == "table" then
      return tonumber(info.price)
    end
  end
  local _, _, price = call("GetMerchantItemInfo", index)
  return tonumber(price)
end

-- The most cost entries one merchant row is read for. The client's own frame draws three
-- (MAX_ITEM_COST); a count past this is a client answering nonsense, not a longer price.
local MAX_COST_ENTRIES = 5

-- What the open window asks for one row, as CollectorHooks.MerchantCost keeps it, or nil where
-- the window says nothing. GetMerchantItemCostInfo(index) is how many cost entries the row has
-- and GetMerchantItemCostItem(index, n) answers texture, amount, link, currency name for each.
-- A client without these calls answers nothing and the row is recorded exactly as before.
local function merchantCost(index)
  local costs = {}
  local count = math.min(countOf(call("GetMerchantItemCostInfo", index)), MAX_COST_ENTRIES)
  for n = 1, count do
    local _, amount, link = call("GetMerchantItemCostItem", index, n)
    costs[#costs + 1] = { amount = amount, link = link }
  end
  return CollectorHooks.MerchantCost(merchantCopper(index), costs)
end

-- Brief M3: the player's own position, read once per window open, or nil. The retail map calls,
-- each looked up and pcall'd: C_Map.GetBestMapForUnit("player") names the map and
-- C_Map.GetPlayerMapPosition(map, "player") answers a Vector2D (x, y fields and GetXY) or, on an
-- older shape, the two numbers. Inside an instance, or on a client without the calls, either one
-- answers nothing, and then there is no position.
--
-- map, where the caller has already read it this window (brief R15), is used rather than asked
-- for again.
function CollectorHooks.PlayerPosition(map)
  local api = rawget(_G, "C_Map")
  if type(api) ~= "table" or type(api.GetBestMapForUnit) ~= "function" then
    return nil
  end
  if type(api.GetPlayerMapPosition) ~= "function" then
    return nil
  end
  if type(map) ~= "number" then
    local okMap, answer = pcall(api.GetBestMapForUnit, "player")
    if not okMap or type(answer) ~= "number" then
      return nil
    end
    map = answer
  end
  local okPos, position, second = pcall(api.GetPlayerMapPosition, map, "player")
  if not okPos or position == nil then
    return nil
  end
  local x, y = nil, nil
  if type(position) == "table" then
    if type(position.GetXY) == "function" then
      local okXY, px, py = pcall(position.GetXY, position)
      if okXY then
        x, y = px, py
      end
    end
    if x == nil then
      x, y = position.x, position.y
    end
  else
    x, y = position, second
  end
  return CollectorHooks.MapPosition(map, x, y)
end

-- Brief QN1: the player's side as a vendor record keeps it, 1 Alliance or 2 Horde, out of one
-- pcalled UnitFactionGroup("player") (Core/Collector.lua Collector.Side), or nil.
function CollectorHooks.PlayerSide()
  local Collector = ItemTree.Collector
  if type(Collector) ~= "table" or type(Collector.Side) ~= "function" then
    return nil
  end
  return Collector.Side(call("UnitFactionGroup", "player"))
end

-- One pass over the open window's own rows, and the only one: the price comes off the same row
-- in the same pass, and nothing here asks the server about an item. The player's position is read
-- once for the window (brief M3) and kept on each of its records as the vendor's rough place.
function CollectorHooks.OnMerchantShow()
  if not CollectorHooks.Enabled() then
    return 0
  end
  local ref = sanitiseGuid(call("UnitGUID", "npc"))
  local sourceName = readCall("UnitName", "npc")
  local zone = zoneText()
  local mapId = mapNow()
  local count = countOf(call("GetMerchantNumItems"))
  local pos, side = nil, nil
  if count > 0 then
    pos = CollectorHooks.PlayerPosition(mapId)
    -- Brief QN1: the player's side, read once for the window and kept on each of its records.
    side = CollectorHooks.PlayerSide()
  end
  local written = 0
  for index = 1, count do
    local itemId = itemIdFromLink(call("GetMerchantItemLink", index))
    if itemId then
      CollectorHooks.NoteItem(itemId, CollectorHooks.HOW_MERCHANT)
      if
        record("vendor", {
          itemId = itemId,
          count = 1,
          sourceKind = "npc",
          sourceId = ref and ref.id or nil,
          sourceName = sourceName,
          zone = zone,
          mapId = mapId,
          quality = qualityOf(itemId),
          cost = merchantCost(index),
          pos = pos,
          side = side,
        })
      then
        written = written + 1
      end
    end
  end
  return written
end

--------------------------------------------------------------------------------
-- Quests
--------------------------------------------------------------------------------

-- The retail shape's answer when it gave one, otherwise the argument free shape's. Written to
-- take the first attempt's return values so that neither shape is ever called twice, and so
-- that every return value survives: the reward info APIs answer with six.
local function questFallback(name, args, first, ...)
  if first ~= nil then
    return first, ...
  end
  return call(name, unpackArgs(args, 1, args.n))
end

-- One quest API call, tried in each shape QuestArgShapes offers until one answers. call type
-- checks and pcall's every attempt, so the shape this client does not carry costs one refused
-- call and nothing else: no error reaches the player and no reward is lost to it.
local function questCall(name, questId, ...)
  local shapes = CollectorHooks.QuestArgShapes(questId, ...)
  local first = shapes[1]
  if #shapes == 1 then
    return call(name, unpackArgs(first, 1, first.n))
  end
  return questFallback(name, shapes[2], call(name, unpackArgs(first, 1, first.n)))
end

-- One entry from the quest frame family: an item the quest on screen is offering. Neither of
-- these takes a quest id on either client, so questCall is handed none. GetQuestItemInfo has
-- no item id return on Classic Era, so the link is what names the item and the info call is
-- read for the stack size.
local function frameItem(kind, index, _questId)
  local _, _, numItems, _, _, itemId = questCall("GetQuestItemInfo", nil, kind, index)
  if not itemId then
    itemId = itemIdFromLink(questCall("GetQuestItemLink", nil, kind, index))
  end
  return itemId, numItems
end

-- One entry from the quest log family, which is the family whose shape differs by client. The
-- info call is named per kind, the link call takes the kind as an argument, and all three take
-- the quest id on the retail shaped engine and refuse it on Classic Era.
local function logItem(kind, index, questId)
  local info = kind == "choice" and "GetQuestLogChoiceInfo" or "GetQuestLogRewardInfo"
  local _, _, numItems, _, _, itemId = questCall(info, questId, index)
  if not itemId then
    itemId = itemIdFromLink(questCall("GetQuestLogItemLink", questId, kind, index))
  end
  return itemId, numItems
end

-- Read in this order. The quest frame family describes the quest the player is looking at,
-- which is what QUEST_DETAIL and QUEST_COMPLETE are about; the quest log family describes
-- whichever entry the quest log has selected, so it is only asked when the frame family found
-- nothing at all. questId says whether that family is offered the id, which is what decides
-- whether the retail shape is tried for its calls.
local QUEST_FAMILIES = {
  {
    reward = "GetNumQuestRewards",
    choice = "GetNumQuestChoices",
    item = frameItem,
    questId = false,
  },
  {
    reward = "GetNumQuestLogRewards",
    choice = "GetNumQuestLogChoices",
    item = logItem,
    questId = true,
  },
}

-- Fixed rewards, then the ones the player picks between.
local QUEST_KINDS = { "reward", "choice" }

-- Hands every item one family names to add(). Returns how many add() accepted.
local function readFamily(family, questId, add)
  local id = family.questId and questId or nil
  local found = 0
  for _, kind in ipairs(QUEST_KINDS) do
    local count = countOf(questCall(family[kind], id))
    for index = 1, count do
      if add(family.item(kind, index, id)) then
        found = found + 1
      end
    end
  end
  return found
end

-- The quest the client is showing, or nil. GetQuestID names the quest in the quest frame,
-- which is the one QUEST_DETAIL and QUEST_COMPLETE are about, and is the id the record is
-- filed under. C_QuestLog.GetSelectedQuest is the retail shaped engine's name for the quest
-- log selection and is the fallback, since that is the quest its quest log family reads.
function CollectorHooks.CurrentQuestId()
  local questId = tonumber(call("GetQuestID"))
  if questId and questId > 0 then
    return questId
  end
  local questLog = rawget(_G, "C_QuestLog")
  if type(questLog) == "table" and type(questLog.GetSelectedQuest) == "function" then
    local ok, selected = pcall(questLog.GetSelectedQuest)
    selected = ok and tonumber(selected) or nil
    if selected and selected > 0 then
      return selected
    end
  end
  return nil
end

-- The quest's own title, in the player's own locale, or nil.
--
-- GetTitleText names the quest the quest frame is showing, which is the one QUEST_DETAIL,
-- QUEST_PROGRESS and QUEST_COMPLETE are all about; C_QuestLog.GetTitleForQuestID answers for a
-- quest that is only in the log. A quest title is game data and says nothing about the
-- character, the realm or the account, which is the only kind of text this file ever stores.
local function questTitle(questId)
  local title = call("GetTitleText")
  if type(title) == "string" and title ~= "" then
    return title
  end
  local questLog = rawget(_G, "C_QuestLog")
  if type(questLog) == "table" and type(questLog.GetTitleForQuestID) == "function" then
    local ok, named = pcall(questLog.GetTitleForQuestID, questId)
    if ok and type(named) == "string" and named ~= "" then
      return named
    end
  end
  return nil
end

-- Brief R9: the title of a quest now in the log, by its id alone, or nil. C_QuestLog's own answer
-- for that id, so it can never be another quest's text left on the quest frame.
local function loggedQuestTitle(questId)
  local questLog = rawget(_G, "C_QuestLog")
  if type(questId) ~= "number" or type(questLog) ~= "table" or type(questLog.GetTitleForQuestID) ~= "function" then
    return nil
  end
  local ok, named = pcall(questLog.GetTitleForQuestID, questId)
  if ok and type(named) == "string" and named ~= "" then
    return named
  end
  return nil
end

-- Brief R9: fields with the quest's title added, where one is known. A new table; fields is not
-- changed.
local function withTitle(fields, title)
  if type(fields) ~= "table" or type(title) ~= "string" or title == "" then
    return fields
  end
  local out = {}
  for key, value in pairs(fields) do
    out[key] = value
  end
  out.title = title
  return out
end

-- { { itemId, count }, ... } from whichever reward family this client answers with. questId is
-- optional: it is what the retail shaped quest log family needs, and CurrentQuestId works it
-- out when the caller does not pass one.
function CollectorHooks.QuestRewards(questId)
  if questId == nil then
    questId = CollectorHooks.CurrentQuestId()
  end
  local out, seen = {}, {}
  -- A quest never offers the same item twice, so a repeat is the second family describing what
  -- the first already did, and the first sighting is the one kept.
  local function add(itemId, count)
    itemId = tonumber(itemId)
    if not itemId or seen[itemId] then
      return false
    end
    seen[itemId] = true
    out[#out + 1] = { itemId = itemId, count = tonumber(count) or 1 }
    return true
  end
  for _, family in ipairs(QUEST_FAMILIES) do
    if readFamily(family, questId, add) > 0 then
      break
    end
  end
  return out
end

-- One quest_reward record per item the quest names, filed under questId. Returns how many, and
-- the rewards read (brief QH1: the turn in window's are held so a reward is never a hand-over).
local function writeQuestRewards(questId)
  local zone = zoneText()
  local mapId = mapNow()
  local written = 0
  local rewards = CollectorHooks.QuestRewards(questId)
  for _, reward in ipairs(rewards) do
    CollectorHooks.NoteItem(reward.itemId, CollectorHooks.HOW_QUEST_OFFER)
    if
      record("quest_reward", {
        itemId = reward.itemId,
        count = reward.count,
        sourceKind = "quest",
        sourceId = questId,
        sourceName = questTitle(questId),
        zone = zone,
        mapId = mapId,
        quality = qualityOf(reward.itemId),
      })
    then
      written = written + 1
    end
  end
  return written, rewards
end

-- QUEST_COMPLETE, the turn in window, where GetQuestID names the quest (with the log selection
-- as CurrentQuestId's fallback). The offer window has its own rule: CollectorHooks.OnQuestOffer.
function CollectorHooks.OnQuest()
  if not CollectorHooks.Enabled() then
    return 0
  end
  local questId = CollectorHooks.CurrentQuestId()
  if not questId then
    return 0
  end
  local written, rewards = writeQuestRewards(questId)
  -- Brief QH1: the window's rewards, so the item lines the turn in prints are never read as a
  -- hand-over (CollectorHooks.HoldTurnInRewards, declared with the hand-over rule below).
  if type(CollectorHooks.HoldTurnInRewards) == "function" then
    pcall(CollectorHooks.HoldTurnInRewards, questId, rewards)
  end
  return written
end

--------------------------------------------------------------------------------
-- Who gives a quest and who takes it back (brief Q8)
--------------------------------------------------------------------------------

-- The offer the player is reading, held from QUEST_DETAIL until QUEST_ACCEPTED says it was taken:
-- { questId, fields }. In memory only, and replaced by the next offer, so a declined quest writes
-- nothing.
CollectorHooks.pendingGiver = nil

-- The unit tokens a quest window's NPC is read through, in order. "npc" is the one every record
-- since brief Q8 was read through (a creature giver). Brief QH1: "questnpc" is the token the
-- client's own quest frame reads its title and portrait through (Blizzard_UIPanels_Game
-- Mainline/QuestFrame.lua:117-119, build 70450), asked only where "npc" names nothing: a world
-- object that gives a quest is a GameObject unit (UnitIsGameObject, UnitDocumentation.lua:1993),
-- which UnitExists answers false for (Blizzard_GamepadActionBars MainActionBarFrame.lua:292).
CollectorHooks.QUEST_NPC_UNITS = { "npc", "questnpc" }

-- The NPC the quest frame is about, read once for the window: its GUID reduced to { kind, id },
-- the name the client shows over it, and where the player stands. nil where the window has no
-- NPC behind it that anything could name. Each unit read goes through readCall and canRead
-- (brief SV1): a GUID or a name the client keeps secret is no answer.
local function questNpcFields()
  local named = nil
  for _, unit in ipairs(CollectorHooks.QUEST_NPC_UNITS) do
    local ref = sanitiseGuid(call("UnitGUID", unit))
    local name = readCall("UnitName", unit)
    if type(name) ~= "string" or name == "" then
      name = nil
    end
    if ref ~= nil then
      return CollectorHooks.QuestNpcFields(ref, name or named, CollectorHooks.PlayerPosition())
    end
    named = named or name
  end
  if not named then
    return nil
  end
  return CollectorHooks.QuestNpcFields(nil, named, CollectorHooks.PlayerPosition())
end

-- One quest NPC record, stored. RecordQuestNpc sanitises and writes; pcall'd like record above.
local function recordQuestNpc(questId, kind, fields)
  if not CollectorHooks.Enabled() or not fields then
    return false
  end
  local instance = ItemTree.collector
  if type(instance) ~= "table" or type(instance.RecordQuestNpc) ~= "function" then
    return false
  end
  local ok, stored = pcall(instance.RecordQuestNpc, instance, questId, kind, fields)
  return ok and stored == true
end

-- Brief Q9: how long an offer is held for its QUEST_ACCEPTED. An offer older than this is stale:
-- the player walked off, or accepted something else, and its NPC is not who gave the next quest.
CollectorHooks.PENDING_GIVER_SECONDS = 60

-- The collector's own clock, so a held offer ages on the same seconds its records are stamped
-- with. The client's time() and then the Lua one where the collector is not built yet.
local function clockNow()
  local instance = ItemTree.collector
  if type(instance) == "table" and type(instance.now) == "function" then
    local ok, now = pcall(instance.now)
    if ok and type(now) == "number" then
      return now
    end
  end
  local now = tonumber(call("time"))
  if now then
    return now
  end
  local os_ = rawget(_G, "os")
  return os_ and type(os_.time) == "function" and os_.time() or 0
end

-- Brief Q9: the quest the OFFER window is about, from GetQuestID alone, or nil. Unlike
-- CurrentQuestId this never falls back to C_QuestLog.GetSelectedQuest: that names the quest log's
-- selection, which on the offer window is some other quest already in the log, and an offer filed
-- under it never matches the id QUEST_ACCEPTED names. GetQuestID may answer 0 on the offer window
-- on this engine, and then the offer is simply held without an id.
function CollectorHooks.OfferQuestId()
  local questId = tonumber(call("GetQuestID"))
  if questId and questId > 0 and questId == math.floor(questId) then
    return questId
  end
  return nil
end

-- Brief Q9: an offer window whose quest GetQuestID could not name, held until QUEST_ACCEPTED names
-- it: { when }. In memory only; a declined offer or a stale one writes nothing.
CollectorHooks.pendingRewards = nil

-- QUEST_DETAIL's rewards. Filed under OfferQuestId's id and never under the log selection, which
-- on the offer window is another quest. With no id nothing is written here: the rewards are read
-- at QUEST_ACCEPTED for the accepted id instead (CollectorHooks.OnQuestAccepted). Returns how many
-- records were written.
function CollectorHooks.OnQuestOffer()
  CollectorHooks.pendingRewards = nil
  if not CollectorHooks.Enabled() then
    return 0
  end
  local questId = CollectorHooks.OfferQuestId()
  if questId then
    return (writeQuestRewards(questId))
  end
  CollectorHooks.pendingRewards = { when = clockNow() }
  return 0
end

-- Brief Q9: the rewards of an offer that had no id, now filed under the accepted id. The quest
-- frame family answers while the offer window is still up; once it has closed the quest log
-- family is asked with the accepted id, which the retail shaped engine answers for a quest now in
-- the log. If neither answers nothing is written, and the quest page's "From your quest log"
-- rewards still come from the log itself. A held marker older than PENDING_GIVER_SECONDS is
-- dropped.
local function writePendingRewards(questId)
  local pending = CollectorHooks.pendingRewards
  CollectorHooks.pendingRewards = nil
  if type(pending) ~= "table" or not CollectorHooks.Enabled() then
    return 0
  end
  local when = tonumber(pending.when)
  local age = when and clockNow() - when or nil
  if not age or age < 0 or age > CollectorHooks.PENDING_GIVER_SECONDS then
    return 0
  end
  local ok, written = pcall(writeQuestRewards, questId)
  return ok and written or 0
end

-- QUEST_DETAIL: the offer window. Nothing is written yet: the player may decline. The offer is
-- held with its NPC and when it opened, and with questId nil where GetQuestID gave no id.
function CollectorHooks.OnQuestDetail()
  CollectorHooks.pendingGiver = nil
  if not CollectorHooks.Enabled() then
    return false
  end
  local fields = questNpcFields()
  if not fields then
    return false
  end
  -- Brief R9: the offer window's own title, held with the offer. GetTitleText names the quest the
  -- frame is showing, which is this offer.
  local title = call("GetTitleText")
  CollectorHooks.pendingGiver = {
    questId = CollectorHooks.OfferQuestId(),
    fields = fields,
    when = clockNow(),
    title = type(title) == "string" and title ~= "" and title or nil,
  }
  return true
end

-- Brief Q9: the held offer, or nil where there is none or it is older than PENDING_GIVER_SECONDS.
-- A stale one is dropped.
local function freshPending()
  local pending = CollectorHooks.pendingGiver
  if type(pending) ~= "table" then
    return nil
  end
  local when = tonumber(pending.when)
  local age = when and clockNow() - when or nil
  if not age or age < 0 or age > CollectorHooks.PENDING_GIVER_SECONDS then
    CollectorHooks.pendingGiver = nil
    return nil
  end
  return pending
end

-- QUEST_ACCEPTED: a quest was taken. Who gave it, in this order:
--   1. the held offer, where its id is this quest's or GetQuestID gave it none;
--   2. the "npc" unit read right now, while the quest frame is still up or the interaction has
--      not ended, where it names a creature. This also covers a quest the engine accepts on its
--      own (auto accept), which fires QUEST_ACCEPTED with no QUEST_DETAIL before it.
--   3. nobody: a quest shared by a party member or started from an item writes nothing.
-- A fresh offer for a different, known quest means the NPC on screen is offering that one, so
-- it is not asked about this one either.
function CollectorHooks.OnQuestAccepted(...)
  local questId = CollectorHooks.AcceptedQuestId(...)
  if not questId then
    return false
  end
  writePendingRewards(questId)
  local pending = freshPending()
  if pending then
    if pending.questId == nil or pending.questId == questId then
      CollectorHooks.pendingGiver = nil
      -- Brief R9: the log's title for the accepted id first, the offer window's after it.
      local title = loggedQuestTitle(questId) or pending.title
      return recordQuestNpc(questId, "give", withTitle(pending.fields, title))
    end
    return false
  end
  if not CollectorHooks.Enabled() then
    return false
  end
  local live = questNpcFields()
  -- Brief QH1: a world object (objectId) gives a quest the same way a creature does.
  if type(live) ~= "table" or not (live.npcId or live.objectId) then
    return false
  end
  return recordQuestNpc(questId, "give", withTitle(live, loggedQuestTitle(questId)))
end

-- QUEST_COMPLETE: the turn in window, open at the NPC the quest is handed in to.
function CollectorHooks.OnQuestComplete()
  if not CollectorHooks.Enabled() then
    return false
  end
  local questId = CollectorHooks.CurrentQuestId()
  if not questId then
    return false
  end
  -- Brief R9: the turn in window's title (questTitle reads the frame, then the log).
  return recordQuestNpc(questId, "end", withTitle(questNpcFields(), questTitle(questId)))
end

--------------------------------------------------------------------------------
-- Quest facts: the client half (brief QF1)
--------------------------------------------------------------------------------

-- What the client states about a quest when it is taken and when it is handed in, into the
-- collector's quest facts store (Core/Collector.lua C:RecordQuestFacts). Only the quest being taken,
-- handed in or (the ledger rule below) moved by a kill is read, by its own id: never a walk of the
-- log, never a list of quest ids. Every API was checked against the Forever UI source (branch
-- forever, build 1.60.1.70245); the Forever client is the "camelot" game type, which loads the
-- Mainline family's quest files (Blizzard_UIPanels_Game.toc, QuestInfo.lua and QuestMapFrame.lua):
--
--   level      C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetInfo(index).level
--              (QuestLogDocumentation.lua, GetInfo and GetLogIndexForQuestID, QuestInfo.level);
--              GetQuestLogTitle's second answer on a client without them (Classic Era)
--   goals      C_QuestLog.GetQuestObjectives(questId): type and numRequired, and the text only to
--              match a kill goal's creature name (QuestLogDocumentation.lua, QuestObjectiveInfo)
--   start item QUEST_DETAIL's questStartItemID, else the "npc" unit's Item GUID
--   side       UnitFactionGroup("player") (UnitDocumentation.lua)
--   money, XP  GetRewardMoney() and GetRewardXP() on the turn in window, which the Mainline
--              QuestInfo.lua this client loads calls for the same window; QUEST_TURNED_IN's xpReward
--              (QuestLogDocumentation.lua) where it fires, as what was actually given
--   suggested group  not recorded (owner ruling 2026-10-14). Minimum level: no API, not recorded.

-- How long a QUEST_DETAIL's start item and a turn in window's player level are held for the
-- QUEST_ACCEPTED or QUEST_TURNED_IN that follows.
CollectorHooks.QUEST_FACTS_HOLD_SECONDS = 60
-- The ledger rule: how long a kill counts for the quest update that follows it, and how long the
-- read waits after QUEST_WATCH_UPDATE for the log to hold the new count.
CollectorHooks.KILL_GOAL_SECONDS = 5
CollectorHooks.KILL_GOAL_DELAY = 0.5
-- The most kills kept in memory for the ledger rule.
CollectorHooks.RECENT_KILLS = 8

-- In memory only, never saved: the offer's start item, the turn in's player level, the ledger's
-- recent kills and each written quest's goal progress (for the ledger rule).
CollectorHooks.pendingStart = nil
CollectorHooks.pendingTurnIn = nil
CollectorHooks.recentKills = {}
CollectorHooks.goalProgress = {}

-- A client number that may be read and is a whole number above nought, or nil.
local function readWhole(value)
  if not canRead(value) then
    return nil
  end
  value = tonumber(value)
  if not value or value < 1 or value ~= math.floor(value) then
    return nil
  end
  return value
end

-- The level of one quest in the player's log, by its id alone, or nil.
function CollectorHooks.QuestLevel(questId)
  local questLog = rawget(_G, "C_QuestLog")
  if
    type(questLog) == "table"
    and type(questLog.GetLogIndexForQuestID) == "function"
    and type(questLog.GetInfo) == "function"
  then
    local ok, index = pcall(questLog.GetLogIndexForQuestID, questId)
    index = ok and readWhole(index) or nil
    if index then
      local gotInfo, info = pcall(questLog.GetInfo, index)
      if gotInfo and type(info) == "table" then
        local questOf = info.questID
        if canRead(questOf) and (questOf == nil or questOf == questId) then
          return readWhole(info.level)
        end
      end
      return nil
    end
  end
  local index = readWhole(call("GetQuestLogIndexByID", questId))
  if not index then
    return nil
  end
  local _, level = call("GetQuestLogTitle", index)
  return readWhole(level)
end

-- The client's kill goal format (QUEST_MONSTERS_KILLED), where it may be read.
local function killFormat()
  local format = rawget(_G, "QUEST_MONSTERS_KILLED")
  if canRead(format) and type(format) == "string" then
    return format
  end
  return nil
end

-- The name rule over the installed data: a Creatures module already built (Core/Creatures.lua
-- Creatures.Loaded), never one loaded for this. The name to id map is built once per module table.
local nameIdsFor, nameIds = nil, nil
local function creatureByName(text)
  local Creatures = ItemTree.Creatures
  if type(Creatures) ~= "table" or type(Creatures.Loaded) ~= "function" then
    return nil
  end
  local ok, source = pcall(Creatures.Loaded)
  if not ok or type(source) ~= "table" then
    return nil
  end
  if nameIdsFor ~= source then
    nameIds, nameIdsFor = CollectorHooks.CreatureNameIds(source), source
  end
  return CollectorHooks.UniqueCreatureId(CollectorHooks.KillNames(text, killFormat()), nameIds)
end
CollectorHooks.creatureByName = creatureByName

-- One quest's goals and their progress (CollectorHooks.QuestGoalsFrom), read by its id.
function CollectorHooks.QuestGoals(questId)
  local questLog = rawget(_G, "C_QuestLog")
  if type(questLog) ~= "table" or type(questLog.GetQuestObjectives) ~= "function" then
    return nil, nil
  end
  local ok, list = pcall(questLog.GetQuestObjectives, questId)
  if not ok or type(list) ~= "table" then
    return nil, nil
  end
  return CollectorHooks.QuestGoalsFrom(list, canRead, CollectorHooks.creatureByName)
end

-- The player's side, 1 Alliance or 2 Horde, or nil.
local function playerSide()
  local tag = call("UnitFactionGroup", "player")
  if not canRead(tag) then
    return nil
  end
  local Collector = ItemTree.Collector
  return Collector and Collector.Side(tag) or nil
end

local function recordFacts(questId, fields)
  local instance = ItemTree.collector
  if type(instance) ~= "table" or type(instance.RecordQuestFacts) ~= "function" then
    return false
  end
  local ok, stored = pcall(instance.RecordQuestFacts, instance, questId, fields)
  return ok and stored == true
end

local function fresh(held)
  local when = type(held) == "table" and tonumber(held.when) or nil
  local age = when and clockNow() - when or nil
  return age ~= nil and age >= 0 and age <= CollectorHooks.QUEST_FACTS_HOLD_SECONDS
end

-- QUEST_DETAIL's part: the item that started the offer, held until QUEST_ACCEPTED. The event's
-- questStartItemID first; else the "npc" unit, where its GUID is an Item's.
function CollectorHooks.OnQuestDetailFacts(startItemId)
  CollectorHooks.pendingStart = nil
  if not CollectorHooks.Enabled() then
    return false
  end
  local item = readWhole(startItemId)
  if not item then
    local guid = call("UnitGUID", "npc")
    local ref = sanitiseGuid(guid)
    if ref and ref.kind == "Item" then
      item = CollectorHooks.ItemIdOfGuid(guid)
    end
  end
  if not item then
    return false
  end
  CollectorHooks.pendingStart = { questId = CollectorHooks.OfferQuestId(), item = item, when = clockNow() }
  return true
end

-- QUEST_ACCEPTED's part: the quest's level, goals and start item, and the player's side.
function CollectorHooks.OnQuestAcceptedFacts(questId)
  if not questId or not CollectorHooks.Enabled() then
    return false
  end
  local start = CollectorHooks.pendingStart
  CollectorHooks.pendingStart = nil
  local item = nil
  if fresh(start) and (start.questId == nil or start.questId == questId) then
    item = start.item
  end
  local goals, progress = CollectorHooks.QuestGoals(questId)
  CollectorHooks.goalProgress[questId] = progress
  return recordFacts(questId, {
    level = CollectorHooks.QuestLevel(questId),
    side = playerSide(),
    item = item,
    goals = goals,
  })
end

-- QUEST_COMPLETE's part: the money and XP the turn in window offers, with the player's level, and
-- the quest's level and goals again (it is still in the log), for a quest taken before brief QF1
-- or a kill goal whose creature the data now names.
function CollectorHooks.OnQuestCompleteFacts()
  CollectorHooks.pendingTurnIn = nil
  if not CollectorHooks.Enabled() then
    return false
  end
  local questId = CollectorHooks.CurrentQuestId()
  if not questId then
    return false
  end
  local playerLevel = readWhole(call("UnitLevel", "player"))
  local goals = CollectorHooks.QuestGoals(questId)
  CollectorHooks.pendingTurnIn = { questId = questId, level = playerLevel, when = clockNow() }
  return recordFacts(questId, {
    level = CollectorHooks.QuestLevel(questId),
    side = playerSide(),
    goals = goals,
    money = readWhole(call("GetRewardMoney")),
    xp = readWhole(call("GetRewardXP")),
    playerLevel = playerLevel,
  })
end

-- QUEST_TURNED_IN (questID, xpReward, moneyReward): the XP actually given, at the level the turn in
-- window held. Nothing where no turn in window for this quest came just before it.
function CollectorHooks.OnQuestTurnedIn(questId, xpReward)
  local held = CollectorHooks.pendingTurnIn
  CollectorHooks.pendingTurnIn = nil
  questId = readWhole(questId)
  CollectorHooks.goalProgress[questId or 0] = nil
  if not questId or not fresh(held) or held.questId ~= questId or not CollectorHooks.Enabled() then
    return false
  end
  local xp = readWhole(xpReward)
  if not xp or not held.level then
    return false
  end
  return recordFacts(questId, { xp = xp, playerLevel = held.level })
end

-- The ledger rule's kills: one creature id and when, from the combat log kill the ledger counted.
function CollectorHooks.NoteKill(guid)
  local ref = sanitiseGuid(guid)
  if not ref or (ref.kind ~= "Creature" and ref.kind ~= "Vehicle") or not readWhole(ref.id) then
    return false
  end
  local kills = CollectorHooks.recentKills
  kills[#kills + 1] = { id = ref.id, when = clockNow() }
  while #kills > CollectorHooks.RECENT_KILLS do
    table.remove(kills, 1)
  end
  return true
end

-- Whether any kill is recent enough to have moved a goal.
local function killRecent(now)
  for _, kill in ipairs(CollectorHooks.recentKills) do
    local age = now - (tonumber(kill.when) or -math.huge)
    if age >= 0 and age <= CollectorHooks.KILL_GOAL_SECONDS then
      return true
    end
  end
  return false
end

-- The read after a quest update, for the ledger rule: the quest's goals progress against what was
-- held, and the recent kills. Answers true when a goal's creature was written.
function CollectorHooks.ReadKillGoal(questId)
  local instance = ItemTree.collector
  local held = type(instance) == "table" and type(instance.QuestFacts) == "function" and instance:QuestFacts(questId)
  if type(held) ~= "table" or type(held.o) ~= "table" then
    return false
  end
  local _, progress = CollectorHooks.QuestGoals(questId)
  local before = CollectorHooks.goalProgress[questId]
  CollectorHooks.goalProgress[questId] = progress
  local index, creature = CollectorHooks.KillGoalFrom(
    before,
    progress,
    held.o,
    CollectorHooks.recentKills,
    clockNow(),
    CollectorHooks.KILL_GOAL_SECONDS
  )
  if not index then
    return false
  end
  local ok, written = pcall(instance.SetQuestGoalCreature, instance, questId, index, creature)
  return ok and written == true
end

-- QUEST_WATCH_UPDATE (questID): a goal of that quest moved. Read only where a kill came within the
-- window and the store holds a kill goal of this quest with no creature yet, so on a client whose
-- combat log the addon may not read (the Forever client: docs/ledger.md) it never reads at all.
function CollectorHooks.OnQuestWatchUpdate(questId)
  questId = readWhole(questId)
  if not questId or not CollectorHooks.Enabled() or not killRecent(clockNow()) then
    return false
  end
  local instance = ItemTree.collector
  local held = type(instance) == "table" and type(instance.QuestFacts) == "function" and instance:QuestFacts(questId)
  local open = false
  for _, goal in ipairs(type(held) == "table" and type(held.o) == "table" and held.o or {}) do
    if type(goal) == "table" and goal.t == "monster" and goal.c == nil then
      open = true
    end
  end
  if not open then
    return false
  end
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    -- The timer's callback runs outside the event handler's pcall, so it takes the boundary
    -- (Core/Guard.lua) itself, or a pcall where that is not loaded.
    return pcall(timer.After, CollectorHooks.KILL_GOAL_DELAY, function()
      local Guard = ItemTree.Guard
      if type(Guard) == "table" and type(Guard.Run) == "function" then
        Guard.Run("CollectorHooks.ReadKillGoal", CollectorHooks.ReadKillGoal, questId)
      else
        pcall(CollectorHooks.ReadKillGoal, questId)
      end
    end) and true or false
  end
  return CollectorHooks.ReadKillGoal(questId)
end

--------------------------------------------------------------------------------
-- What a quest asks for
--------------------------------------------------------------------------------

-- The turn in window, which is the one place a quest's required items are named exactly.
--
-- { { itemId, count }, ... }. GetNumQuestItems and GetQuestItemInfo("required", index) are what
-- the client's own QuestFrameProgressItems_Update reads on QUEST_PROGRESS, and on this engine
-- GetQuestItemInfo answers name, texture, numItems, quality, isUsable, itemID, so the item id
-- comes straight off the call and the link is only the fallback. Neither takes a quest id.
--
-- Nothing is matched by name here and nothing is looked up: the window states the ids.
--
-- Brief QH1: the second answer says whether the list is the window's whole list: GetNumQuestItems
-- answered a number (Blizzard_UIPanels_Game Mainline/QuestFrame.lua:231, build 70450) and every
-- index named its item (GetQuestItemInfo("required", i), :271, whose sixth answer is the item id on
-- this client, else GetQuestItemLink; the same route Jettison's Client/QuestRewards.lua Takes reads).
-- Only a whole list may say a handed-over item was NOT taken. A value the client keeps secret
-- (brief SV1) is no answer, and makes the list not whole.
function CollectorHooks.QuestRequirements()
  local out, seen = {}, {}
  local total = call("GetNumQuestItems")
  local whole = canRead(total) and tonumber(total) ~= nil
  local count = whole and countOf(total) or 0
  for index = 1, count do
    local itemId, numItems = frameItem("required", index, nil)
    if not canRead(itemId) then
      itemId = nil
    end
    if not canRead(numItems) then
      numItems = nil
    end
    itemId = tonumber(itemId)
    if itemId and not seen[itemId] then
      seen[itemId] = true
      out[#out + 1] = { itemId = itemId, count = tonumber(numItems) or 1 }
    elseif not itemId then
      whole = false
    end
  end
  return out, whole
end

-- QUEST_PROGRESS: the player is standing at the quest giver with the items it wants. This is the
-- strongest form of the fact, because the client names the ids rather than the words.
function CollectorHooks.OnQuestProgress()
  if not CollectorHooks.Enabled() then
    return 0
  end
  local questId = CollectorHooks.CurrentQuestId()
  if not questId then
    return 0
  end
  local title = questTitle(questId)
  local zone = zoneText()
  local mapId = mapNow()
  local written = 0
  local requirements, whole = CollectorHooks.QuestRequirements()
  -- Brief QH1 (owner's "A", 2026-10-22): what the hand-in takes marks each item this quest handed
  -- over, for this one quest only, from the list just read. Brief IW1 (the owner's "2B", the bag
  -- check): with each such item's count now, a list that is not whole counting as no list.
  pcall(CollectorHooks.NoteHandinWindow, questId, whole and requirements or nil)
  for _, required in ipairs(requirements) do
    CollectorHooks.NoteItem(required.itemId, CollectorHooks.HOW_QUEST_OFFER)
    if
      record("quest_requires", {
        itemId = required.itemId,
        count = 1,
        need = required.count,
        sourceKind = "quest",
        sourceId = questId,
        sourceName = title,
        zone = zone,
        mapId = mapId,
        quality = qualityOf(required.itemId),
      })
    then
      written = written + 1
    end
  end
  if written > 0 then
    dropTooltipCache()
  end
  return written
end

-- The quests in the player's log with their objectives, as ObjectiveIndexFrom wants them:
-- { { questId, title, objectives = { { text, type, numRequired } } } }.
--
-- C_QuestLog is this client's own namespace and is read first: its API documentation carries
-- GetNumQuestLogEntries, GetInfo, GetQuestObjectives and GetTitleForQuestID, and
-- GetQuestObjectives answers with the structure above. The argument free globals below it are
-- the Classic Era shape and are only reached when that found nothing, the way every other
-- two client call in this file is written.
--
-- No item is queried here and none can be: an objective names its item in words, never by id.
function CollectorHooks.QuestLogEntries()
  local out = {}
  local questLog = rawget(_G, "C_QuestLog")
  if type(questLog) == "table" and type(questLog.GetInfo) == "function" then
    local shown = countOf(pass(pcall(questLog.GetNumQuestLogEntries)))
    for index = 1, shown do
      local ok, info = pcall(questLog.GetInfo, index)
      local questId = nil
      if ok and type(info) == "table" and not info.isHeader then
        questId = tonumber(info.questID)
      end
      if questId then
        local objectives = nil
        if type(questLog.GetQuestObjectives) == "function" then
          local gotObjectives, list = pcall(questLog.GetQuestObjectives, questId)
          if gotObjectives and type(list) == "table" then
            objectives = list
          end
        end
        out[#out + 1] = { questId = questId, title = info.title, objectives = objectives }
      end
    end
  end
  if #out > 0 then
    return out
  end
  -- Classic Era: the log is walked by index and the objectives are read off the entry the index
  -- names, so the objective's own shape is built here rather than handed over.
  local shown = countOf(call("GetNumQuestLogEntries"))
  for index = 1, shown do
    local title, _, _, isHeader, _, _, _, questId = call("GetQuestLogTitle", index)
    questId = tonumber(questId)
    if questId and not isHeader then
      local objectives = {}
      for slot = 1, countOf(call("GetNumQuestLeaderBoards", index)) do
        local text, objectiveType = call("GetQuestLogLeaderBoard", slot, index)
        if type(text) == "string" then
          objectives[#objectives + 1] = { text = text, type = objectiveType }
        end
      end
      out[#out + 1] = {
        questId = questId,
        title = type(title) == "string" and title or nil,
        objectives = objectives,
      }
    end
  end
  return out
end

-- The item objectives of the log as it stands, built once and kept until the log changes.
--
-- Without this every hover would walk every quest and build a table per quest, which is a real
-- cost on a tooltip. With it a hover is one lookup in a table of at most a few dozen names.
CollectorHooks.objectiveIndex = nil

-- Items already checked against that index, so hovering the same pelt twenty times costs one
-- check. Both tables are in memory only and both go whenever the quest log changes.
CollectorHooks.objectiveChecked = {}

-- How many times the index has been built, which is what a spec reads back rather than timing.
CollectorHooks.objectiveScans = 0

function CollectorHooks.InvalidateQuestObjectives()
  CollectorHooks.objectiveIndex = nil
  CollectorHooks.objectiveChecked = {}
end

function CollectorHooks.QuestObjectiveIndex()
  if CollectorHooks.objectiveIndex then
    return CollectorHooks.objectiveIndex
  end
  local entries = CollectorHooks.QuestLogEntries()
  local index = CollectorHooks.ObjectiveIndexFrom(entries)
  CollectorHooks.objectiveScans = CollectorHooks.objectiveScans + 1
  -- An empty index is kept once the log answered at least one quest: a log of kill quests has
  -- no item objectives, and asking it again would walk every quest on every tooltip rebuild.
  -- Only a log that answered nothing (no entries yet, or every GetInfo failed) is asked again,
  -- because the quest log is empty for a moment after login and fills itself in, and a kept
  -- empty answer would outlive that with nothing to say so. QUEST_ACCEPTED and QUEST_REMOVED
  -- still drop whatever is kept.
  if next(index) == nil and (type(entries) ~= "table" or #entries == 0) then
    return index
  end
  CollectorHooks.objectiveIndex = index
  return index
end

-- One item's name and the class the build gives it, from the shipped data first and the running
-- client second. One item and one call at most: this is only ever reached for the item the
-- player is already looking at.
local function itemNameAndClass(itemId)
  local name, classId = nil, nil
  -- Brief U3: the client first while the item rows are not loaded, so a hover never loads them.
  -- The item is the one on the player's screen, so the client has its name.
  if not itemRowsLoaded() then
    local facts = itemFacts(itemId)
    if facts then
      name, classId = facts.name, tonumber(facts.classId)
    end
  end
  local data = ItemTree.Data
  if (not name or not classId) and data and type(data.GetItem) == "function" then
    local ok, item = pcall(data.GetItem, data, itemId)
    if ok and type(item) == "table" then
      if type(item.n) == "string" and item.n ~= "" then
        name = item.n
      end
      if type(item.c) == "number" then
        classId = item.c
      end
    end
  end
  if not name or not classId then
    local facts = itemFacts(itemId)
    if facts then
      name = name or facts.name
      classId = classId or facts.classId
    end
  end
  return name, classId
end

-- Whether any other searchable item in the shipped data carries this exact name (Data:NameShared):
-- one pass over the names that stops at the first other item that answers, with no table made
-- and no index built.
--
-- Paid only once a name has already matched an objective, which almost never happens, so an
-- ordinary hover never reaches it at all. Brief PF6: it walked Data:NameIndex, whose first call
-- made a table for every searchable item (27,325) and, before the window was ever opened, built
-- the search index as well, inside the hover: the owner's 112 ms NoteItem at a vendor.
local function nameIsShared(itemName, itemId)
  local data = ItemTree.Data
  if not data or type(data.NameShared) ~= "function" then
    return false
  end
  local ok, shared = pcall(data.NameShared, data, itemName, itemId)
  return ok and shared == true
end

-- One item, matched against the item objectives of the quests in the player's log.
--
-- This is the path that answers the question the owner asked: a quest item sitting in the bags
-- with its quest in the log, and nothing anywhere saying what it is for. No build ships quest
-- objectives, so the only way to learn it short of handing the quest in is the log's own words,
-- and the log names the item in words alone.
--
-- One item is compared, and only the one already being looked at. Nothing is queried in a loop
-- and no list of items is walked: the index above is built from the quest log, which names no
-- item ids at all, and the single item's name comes from the shipped data or from one call for
-- the item whose tooltip is already on screen.
--
-- Returns how many records were written.
function CollectorHooks.NoteQuestObjective(itemId)
  local id = tonumber(itemId)
  if not id or not CollectorHooks.Enabled() then
    return 0
  end
  if CollectorHooks.objectiveChecked[id] then
    return 0
  end
  local index = CollectorHooks.QuestObjectiveIndex()
  if next(index) == nil then
    return 0
  end
  local name, classId = itemNameAndClass(id)
  if not name then
    -- Nothing on this client can name the item yet, which is the ordinary state of a withheld
    -- one the moment before its text arrives. Not marked as checked, so the next hover tries
    -- again rather than writing the item off for as long as the quest log stands.
    return 0
  end
  CollectorHooks.objectiveChecked[id] = true
  local matches = CollectorHooks.ObjectiveMatches(name, index)
  if #matches == 0 then
    return 0
  end
  if not CollectorHooks.ObjectiveIsSafe(classId == CollectorHooks.QUEST_ITEM_CLASS, nameIsShared(name, id)) then
    return 0
  end
  local written = 0
  for _, match in ipairs(matches) do
    if
      record("quest_requires", {
        itemId = id,
        count = 1,
        need = match.count,
        sourceKind = "quest",
        sourceId = match.questId,
        sourceName = match.title,
        quality = qualityOf(id),
      })
    then
      written = written + 1
    end
  end
  if written > 0 then
    dropTooltipCache()
  end
  return written
end

--------------------------------------------------------------------------------
-- Seen bosses (brief BL14)
--------------------------------------------------------------------------------

-- The boss index's entries with no creature id, by folded name (Collector.SeenBossNames), read
-- once through the Boss loot model the first time a creature is targeted or moused over, and
-- kept for the session. false where this build has no index, so it is never asked again.
CollectorHooks.bossNames = nil
CollectorHooks.bossNamesTotal = 0

local function seenBossNames()
  if CollectorHooks.bossNames ~= nil then
    return CollectorHooks.bossNames or nil
  end
  local Collector = ItemTree.Collector
  local pane = ItemTree.UI and ItemTree.UI.BossLoot
  if type(Collector) ~= "table" or type(Collector.SeenBossNames) ~= "function" then
    return nil
  end
  if type(pane) ~= "table" or type(pane.Present) ~= "function" or type(pane.Model) ~= "function" then
    return nil
  end
  local present = select(2, pcall(pane.Present))
  if present ~= true then
    CollectorHooks.bossNames = false
    return nil
  end
  local made, model = pcall(pane.Model)
  if not made or type(model) ~= "table" or type(model.Index) ~= "function" then
    return nil
  end
  local ok, index = pcall(model.Index, model)
  if not ok or type(index) ~= "table" then
    CollectorHooks.bossNames = false
    return nil
  end
  local names, total = Collector.SeenBossNames(index)
  CollectorHooks.bossNames = names
  CollectorHooks.bossNamesTotal = total
  return names
end

--- Records the creature a unit ("target" or "mouseover") shows where its name is a boss index
--- entry's that has no creature id: the creature id out of its GUID, its name, the instance's map
--- id and its level, one record per entry (Collector C:RecordSeenBoss). A player, a pet, an
--- object and every ordinary creature cost a GUID prefix test and a table lookup and stop: the
--- GUID is parsed only for a name the boss index holds. Answers the entry recorded, or nil.
function CollectorHooks.NoteSeenBoss(unit)
  if not CollectorHooks.Enabled() then
    return nil
  end
  local instance = collector()
  if not instance or type(instance.RecordSeenBoss) ~= "function" then
    return nil
  end
  local guid = readCall("UnitGUID", unit)
  -- A creature's GUID is "Creature-...", the kind Privacy.ParseGuid reads off its front.
  if type(guid) ~= "string" or guid:find("Creature-", 1, true) ~= 1 then
    return nil
  end
  local name = readCall("UnitName", unit)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  local names = seenBossNames()
  if not names or next(names) == nil then
    return nil
  end
  local Collector = ItemTree.Collector
  local bossIndex = Collector.SeenBossFor(names, name)
  if not bossIndex then
    return nil
  end
  local ref = sanitiseGuid(guid)
  if not ref or ref.kind ~= "Creature" then
    return nil
  end
  local mapId = select(8, call("GetInstanceInfo"))
  local fields = CollectorHooks.SeenBossFields(ref, name, mapId, readCall("UnitLevel", unit))
  local ok, stored = pcall(instance.RecordSeenBoss, instance, bossIndex, fields)
  if ok and stored then
    return bossIndex
  end
  return nil
end

--------------------------------------------------------------------------------
-- Brief R5a: instance entrances, into the places store (Core/Places.lua)
--------------------------------------------------------------------------------

-- PLAYER_LEAVING_WORLD fires before the loading screen, while the player still stands where they
-- were; PLAYER_ENTERING_WORLD fires after it, with the new place known. So the way in is the spot
-- held at the first and filed under the instance the second names, and the way out is the spot
-- the second finds outside, filed under the instance the first was in. Held in memory only, for
-- at most ENTRANCE_MAX_AGE seconds, and cleared by every zone change. Party and raid instances
-- only: battlegrounds, arenas and scenarios record nothing.
CollectorHooks.ENTRANCE_MAX_AGE = 120
CollectorHooks.pendingEntrance = nil
CollectorHooks.leftInstance = nil

local ENTRANCE_TYPES = { party = true, raid = true }

-- inside (a boolean), the instance type word and the instance's Map id (GetInstanceInfo's
-- eighth answer), each nil where the client does not say.
local function instanceNow()
  local inside, kind = call("IsInInstance")
  local _, infoKind, _, _, _, _, _, mapId = call("GetInstanceInfo")
  if type(kind) ~= "string" then
    kind = infoKind
  end
  if inside == nil and type(kind) == "string" then
    inside = kind ~= "none"
  end
  return inside and true or false, kind, positiveWhole(mapId)
end

local function freshSince(at, now)
  return type(at) == "number" and now >= at and now - at < CollectorHooks.ENTRANCE_MAX_AGE
end

-- Adds pos under the instance's entrance. Answers true when written.
local function recordEntrance(instanceId, pos, now)
  local Places = ItemTree.Places
  local db = ItemTree.db
  if type(Places) ~= "table" or type(Places.Add) ~= "function" or type(db) ~= "table" or type(pos) ~= "table" then
    return false
  end
  if type(db.places) ~= "table" then
    db.places = {}
  end
  local ok, written = pcall(Places.Add, db.places, Places.ENTRANCE, instanceId, pos.map, pos.x, pos.y, Places.Day(now))
  return ok and written == true
end

--- PLAYER_LEAVING_WORLD: outside, the spot the player stands on is held; inside a party or raid
--- instance, that instance's id is held for the way out. Nothing is written here.
function CollectorHooks.OnLeavingWorld()
  CollectorHooks.pendingEntrance = nil
  CollectorHooks.leftInstance = nil
  if not CollectorHooks.Enabled() then
    return nil
  end
  local now = clockNow()
  local inside, kind, mapId = instanceNow()
  if not inside then
    local pos = CollectorHooks.PlayerPosition()
    if pos then
      CollectorHooks.pendingEntrance = { pos = pos, at = now }
    end
  elseif ENTRANCE_TYPES[kind] and mapId then
    CollectorHooks.leftInstance = { id = mapId, at = now }
  end
  return nil
end

--- PLAYER_ENTERING_WORLD: into a party or raid instance with a fresh held spot, that spot is the
--- instance's entrance; out of one into the world, where the player now stands is. Answers the
--- instance id recorded, or nil.
function CollectorHooks.OnEnteringWorld()
  local pending, left = CollectorHooks.pendingEntrance, CollectorHooks.leftInstance
  CollectorHooks.pendingEntrance = nil
  CollectorHooks.leftInstance = nil
  if not CollectorHooks.Enabled() then
    return nil
  end
  local now = clockNow()
  local inside, kind, mapId = instanceNow()
  if inside then
    if ENTRANCE_TYPES[kind] and mapId and pending and freshSince(pending.at, now) then
      if recordEntrance(mapId, pending.pos, now) then
        return mapId
      end
    end
    return nil
  end
  if not left or not freshSince(left.at, now) then
    return nil
  end
  -- A ghost released out of an instance stands at a graveyard, not at the door.
  if call("UnitIsDeadOrGhost", "player") then
    return nil
  end
  local pos = CollectorHooks.PlayerPosition()
  if pos and recordEntrance(left.id, pos, now) then
    return left.id
  end
  return nil
end

--------------------------------------------------------------------------------
-- Brief R9: where trainers and stable masters stand, and what a gathered node is called
--------------------------------------------------------------------------------

-- Every new handler body here runs under Core/Guard.lua's boundary (brief G1), so an error is
-- recorded and shown once rather than lost, and costs only that one window. pcall where Guard is
-- not loaded.
local function guarded(where, fn, ...)
  local Guard = ItemTree.Guard
  if type(Guard) == "table" and type(Guard.Run) == "function" then
    return Guard.Run(where, fn, ...)
  end
  return pcall(fn, ...)
end

-- A trainer's and a stable master's window. TRAINER_SHOW and PET_STABLE_SHOW are the events both
-- clients have long fired for them; the retail shaped engine also states the window through
-- PLAYER_INTERACTION_MANAGER_FRAME_SHOW with Enum.PlayerInteractionType's Trainer or StableMaster.
-- All three are listened for, and the second of two events for one window inside NPC_PLACE_REPEAT
-- seconds is the same visit, never a second sighting.
CollectorHooks.NPC_PLACE_REPEAT = 5
CollectorHooks.lastNpcPlace = nil

-- The places kind an interaction type names, or nil. Enum is read as a table, nothing is called.
function CollectorHooks.InteractionKind(interactionType)
  local enum = rawget(_G, "Enum")
  local types = type(enum) == "table" and rawget(enum, "PlayerInteractionType") or nil
  if type(types) ~= "table" or type(interactionType) ~= "number" then
    return nil
  end
  local Places = ItemTree.Places
  local trainer = Places and Places.TRAINER or "t"
  local stable = Places and Places.STABLE or "s"
  if interactionType == types.Trainer then
    return trainer
  end
  if interactionType == types.StableMaster then
    return stable
  end
  return nil
end

-- What the trainer in front of the player trains, as the client's first service names it, or
-- nil. One call: GetTrainerServiceSkillLine(1), the profession or class line of the window's first
-- row, which the window has already been sent. A client without the call answers nothing; the
-- answer is checked by NpcPlaceFields (TrainsWord), which leaves out a line that is not a plain
-- phrase and refuses the whole record for one shaped like a character's name.
local function trainerTrains()
  return readCall("GetTrainerServiceSkillLine", 1)
end

-- One visit to a trainer ("t") or a stable master ("s"): the "npc" unit read once, inside this
-- handler, then the player's position into the places store under the NPC's creature id, with the
-- name the client showed and, for a trainer, what it trains. Nothing without a creature, without a
-- position (inside an instance) or with the setting off. Answers the creature id written, or nil.
function CollectorHooks.OnNpcWindow(kind)
  if not CollectorHooks.Enabled() then
    return nil
  end
  local Places = ItemTree.Places
  local db = ItemTree.db
  if type(Places) ~= "table" or type(Places.Add) ~= "function" or type(db) ~= "table" then
    return nil
  end
  if kind ~= Places.TRAINER and kind ~= Places.STABLE then
    return nil
  end
  local ref = sanitiseGuid(call("UnitGUID", "npc"))
  if type(ref) ~= "table" or ref.kind ~= "Creature" then
    return nil
  end
  local trains = nil
  if kind == Places.TRAINER then
    trains = trainerTrains()
  end
  local fields = CollectorHooks.NpcPlaceFields(ref, readCall("UnitName", "npc"), trains)
  if not fields then
    return nil
  end
  local now = clockNow()
  local last = CollectorHooks.lastNpcPlace
  if
    type(last) == "table"
    and last.kind == kind
    and last.npcId == fields.npcId
    and now >= last.at
    and now - last.at < CollectorHooks.NPC_PLACE_REPEAT
  then
    return nil
  end
  local pos = CollectorHooks.PlayerPosition()
  if type(pos) ~= "table" then
    return nil
  end
  if type(db.places) ~= "table" then
    db.places = {}
  end
  local labels = { n = fields.n, k = fields.k }
  local ok, written = pcall(Places.Add, db.places, kind, fields.npcId, pos.map, pos.x, pos.y, Places.Day(now), labels)
  if not ok or written ~= true then
    return nil
  end
  CollectorHooks.lastNpcPlace = { kind = kind, npcId = fields.npcId, at = now }
  return fields.npcId
end

--- TRAINER_SHOW.
function CollectorHooks.OnTrainerShow()
  local Places = ItemTree.Places
  return CollectorHooks.OnNpcWindow(Places and Places.TRAINER or "t")
end

--- PET_STABLE_SHOW.
function CollectorHooks.OnStableShow()
  local Places = ItemTree.Places
  return CollectorHooks.OnNpcWindow(Places and Places.STABLE or "s")
end

--- PLAYER_INTERACTION_MANAGER_FRAME_SHOW: a trainer's or a stable master's window only.
function CollectorHooks.OnInteractionShow(interactionType)
  local kind = CollectorHooks.InteractionKind(interactionType)
  if not kind then
    return nil
  end
  return CollectorHooks.OnNpcWindow(kind)
end

--------------------------------------------------------------------------------
-- Brief TW1: what each trainer teaches (owner QA 2026-10-18, item 242)
--------------------------------------------------------------------------------

-- The owner: "maybe our collector isn't collecting those things?" It was not: a trainer visit kept
-- the place, the name and the first row's skill line (OnNpcWindow above), and a class trainer's
-- Teaches tab listed the Classic Era tables alone. Now, once a trainer's window holds its rows,
-- every row the window lists is read (the developer probe's reads, its TrainerServiceRow, never
-- copied) and kept in the Collector's trainer lists (Core/Collector.lua, collector.trainers):
-- the spell id, its rank, the level, skill and skill rank it asks, the price and the row's type,
-- with the window's filters, the player's class, the trainer's type and its reaction to the
-- player. Ids and numbers only, never a name. Nothing is bought, selected or filtered, and nothing
-- is called on the client's trainer window: BuyTrainerService, SelectTrainerService and
-- SetTrainerServiceTypeFilter are never called. Every value is asked Util.CanRead first; a row
-- with one the client keeps secret is left out and the read is no full list.
--
-- THE ONE SWITCH, who records. "dev": a developer checkout alone. The reads are the developer
-- probe's, which only a checkout loads (the packager strips the probe from a released build), so a
-- released build records nothing and no player's saved file grows. The owner's ruling of
-- 2026-10-18: "this is one of the data heavier lists and if I just make one of each class I can
-- get the full list anyway". "off": nobody. "Record what you see" must be on as well, as for every
-- other record.
CollectorHooks.TRAINER_LISTS = "dev"

-- The window's rows are read a slice a frame, each slice at most the login slicer's budget
-- (Core/Data.lua Data.PRELOAD_BUDGET_MS, on Data.SliceClock) and at least one row, so a long list
-- never costs one frame more than that.
CollectorHooks.trainerPass = nil
CollectorHooks.trainerToken = 0
-- The last finished read, for the developer's debug line: { npcId, rows, full, slices, ms }.
CollectorHooks.lastTrainerRead = nil

--- Whether trainer lists are recorded now: the switch, the Collector setting and the developer
--- probe's reads all there.
function CollectorHooks.TrainerListsOn()
  if CollectorHooks.TRAINER_LISTS ~= "dev" or not CollectorHooks.Enabled() then
    return false
  end
  local ui = ItemTree.UI
  local probe = type(ui) == "table" and ui.Probe or nil
  return type(probe) == "table"
    and type(probe.TrainerServiceRow) == "function"
    and type(probe.TrainerFilterState) == "function"
end

local function trainerProbe()
  return ItemTree.UI.Probe
end

-- The slicer's clock and budget (Core/Data.lua); 0 and 4 ms where Data is not loaded.
local function trainerClock()
  local data = ItemTree.Data
  local clock = type(data) == "table" and data.SliceClock or nil
  if type(clock) == "function" then
    local ok, ms = pcall(clock)
    if ok and type(ms) == "number" then
      return ms
    end
  end
  return 0
end

local function trainerBudget()
  local data = ItemTree.Data
  return type(data) == "table" and tonumber(data.PRELOAD_BUDGET_MS) or 4
end

-- The creature id of the "npc" unit, or nil.
local function trainerNpcId()
  local ref = sanitiseGuid(call("UnitGUID", "npc"))
  if type(ref) ~= "table" or ref.kind ~= "Creature" then
    return nil
  end
  local id = tonumber(ref.id)
  if id and id > 0 and id == math.floor(id) then
    return id
  end
  return nil
end

-- How many rows the window lists now, or nil.
local function trainerCount()
  local count = call("GetNumTrainerServices")
  if not canRead(count) or type(count) ~= "number" or count < 0 then
    return nil
  end
  return math.floor(count)
end

-- A whole number off the client, or nil (a secret, a fraction, anything else).
local function trainerWhole(value)
  if not canRead(value) or type(value) ~= "number" or value ~= value or value % 1 ~= 0 then
    return nil
  end
  return value
end

-- Books the next slice of the pass with this token on the next frame. False where the client has
-- no timer.
local function bookTrainerSlice(token)
  local timer = rawget(_G, "C_Timer")
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    return false
  end
  return pcall(timer.After, 0, function()
    guarded("CollectorHooks.TrainerReadSlice", CollectorHooks.TrainerReadSlice, token)
  end) and true or false
end

-- The window's three filters as bits (Collector.TRAINER_FILTER_BITS) and whether the client
-- answered every one.
local function trainerFilters(probe)
  local Collector = ItemTree.Collector
  local bits, known = 0, true
  for _, filter in ipairs(probe.TRAINER_FILTERS or { "available", "unavailable", "used" }) do
    local state = probe.TrainerFilterState(filter)
    if state == true then
      bits = bits + (Collector.TRAINER_FILTER_BITS[filter] or 0)
    elseif state ~= false then
      known = false
    end
  end
  return bits, known
end

--- A trainer's window opened or changed (TRAINER_SHOW, the interaction manager's Trainer show,
--- TRAINER_UPDATE, which passes update true): a read of its rows is booked for the next frame, when
--- the window holds them. A read in flight for another window, or for this one before a change of
--- its row count or filters, is written as far as it got (never a full list) and a new one starts;
--- an update that changes neither (a row bought) lets the read in flight finish. Answers true when
--- a read is booked or goes on.
function CollectorHooks.StartTrainerRead(update)
  if not CollectorHooks.TrainerListsOn() then
    return false
  end
  local npcId = trainerNpcId()
  if not npcId then
    return false
  end
  local held = CollectorHooks.trainerPass
  if held and held.npcId == npcId and held.count == nil then
    -- Booked already and not started: the window's two show events, or an update straight after.
    return true
  end
  if update == true and held and held.npcId == npcId and trainerCount() == held.count then
    local bits, known = trainerFilters(trainerProbe())
    if known and held.filtersKnown and bits == held.filters then
      return true
    end
  end
  if held then
    CollectorHooks.FinishTrainerRead(held, false)
  end
  CollectorHooks.trainerToken = CollectorHooks.trainerToken + 1
  local job = { npcId = npcId, token = CollectorHooks.trainerToken, index = 1, rows = {}, missed = 0 }
  job.slices, job.ms, job.skills = 0, 0, {}
  CollectorHooks.trainerPass = job
  if not bookTrainerSlice(job.token) then
    CollectorHooks.trainerPass = nil
    return false
  end
  return true
end

-- The window's own facts, read once at a pass's first slice: how many rows, the filters, the
-- player's class, the trainer's type, the first row's skill line and the trainer's reaction to the
-- player. False where the window is gone or names another trainer, or no class can be read.
local function readTrainerHeader(job, probe)
  if trainerNpcId() ~= job.npcId then
    return false
  end
  job.count = trainerCount()
  if not job.count then
    return false
  end
  job.filters, job.filtersKnown = trainerFilters(probe)
  local _, _, classId = call("UnitClass", "player")
  job.classId = trainerWhole(classId)
  if not job.classId or job.classId < 1 then
    return false
  end
  local api = rawget(_G, "C_Trainer")
  if type(api) == "table" and type(api.GetTrainerType) == "function" then
    local ok, kind = pcall(api.GetTrainerType)
    job.kind = ok and trainerWhole(kind) or nil
  end
  local line = readCall("GetTrainerServiceSkillLine", 1)
  if type(line) == "string" and line ~= "" and type(probe.SkillIdFor) == "function" then
    job.skillLine = probe.SkillIdFor(line, probe.TrainerSkills and probe.TrainerSkills() or nil)
  end
  local reaction = trainerWhole(call("UnitReaction", "npc", "player"))
  job.reaction = (reaction and reaction >= 1 and reaction <= 8) and reaction or 0
  return true
end

-- A skill line's name as our Skills table's id, asked once per name a pass, or 0.
local function trainerSkillId(job, probe, name)
  if type(name) ~= "string" or name == "" then
    return 0
  end
  local held = job.skills[name]
  if held == nil then
    held = 0
    if type(probe.SkillIdFor) == "function" then
      held = probe.SkillIdFor(name, probe.TrainerSkills and probe.TrainerSkills() or nil) or 0
    end
    job.skills[name] = held
  end
  return held
end

-- One row of the window into the pass: { level, rank, skill, skillRank, cost, type, reaction } under
-- its spell id. A row of no type we know (a header), with no spell id or with a value the client
-- keeps secret is not kept and counted as missed.
local function readTrainerRow(job, probe, index)
  local row = probe.TrainerServiceRow(index)
  if type(row) ~= "table" then
    job.missed = job.missed + 1
    return
  end
  local secret = probe.SECRET
  for _, field in ipairs({ "status", "spell", "level", "subRank", "rank", "cost", "skillName" }) do
    if secret ~= nil and row[field] == secret then
      job.missed = job.missed + 1
      return
    end
  end
  local kind = ItemTree.Collector.TRAINER_ROW_TYPES[row.status]
  local spell = trainerWhole(row.spell)
  if not kind or not spell or spell < 1 then
    job.missed = job.missed + 1
    return
  end
  job.rows[spell] = {
    trainerWhole(row.level) or 0,
    trainerWhole(row.subRank) or 0,
    trainerSkillId(job, probe, row.skillName),
    trainerWhole(row.rank) or 0,
    trainerWhole(row.cost) or 0,
    kind,
    job.reaction or 0,
  }
end

--- One slice of the read with this token: the window's facts first, then rows until the slicer's
--- budget is spent (at least one), then the next slice booked, or the read written once every row
--- is read. Answers true while the read goes on or once it is written.
function CollectorHooks.TrainerReadSlice(token)
  local job = CollectorHooks.trainerPass
  if type(job) ~= "table" or job.token ~= token then
    return false
  end
  local probe = trainerProbe()
  if not CollectorHooks.TrainerListsOn() then
    CollectorHooks.trainerPass = nil
    return false
  end
  local started = trainerClock()
  if job.count == nil and not readTrainerHeader(job, probe) then
    CollectorHooks.trainerPass = nil
    return false
  end
  local deadline = started + trainerBudget()
  repeat
    if job.index > job.count then
      break
    end
    readTrainerRow(job, probe, job.index)
    job.index = job.index + 1
  until trainerClock() >= deadline
  job.slices = job.slices + 1
  job.ms = job.ms + math.max(0, trainerClock() - started)
  if job.index > job.count then
    return CollectorHooks.FinishTrainerRead(job, true)
  end
  if not bookTrainerSlice(token) then
    return CollectorHooks.FinishTrainerRead(job, false)
  end
  return true
end

--- Writes a pass into the Collector's trainer lists as far as it read. done says every row was read
--- in order; the read is a FULL list only then, with all three filters on, every row kept and the
--- window still this trainer's with as many rows as when the read began. Answers true when
--- something was written.
function CollectorHooks.FinishTrainerRead(job, done)
  if CollectorHooks.trainerPass == job then
    CollectorHooks.trainerPass = nil
  end
  if type(job) ~= "table" or job.classId == nil or next(job.rows) == nil then
    return false
  end
  local Collector = ItemTree.Collector
  local full = done == true
    and job.filtersKnown == true
    and job.filters == Collector.TRAINER_ALL_FILTERS
    and job.missed == 0
    and trainerNpcId() == job.npcId
    and trainerCount() == job.count
  local instance = ItemTree.collector
  if type(instance) ~= "table" or type(instance.RecordTrainerList) ~= "function" then
    return false
  end
  local read = {
    classId = job.classId,
    kind = job.kind,
    skillLine = job.skillLine,
    filters = job.filters,
    full = full,
    rows = job.rows,
  }
  local ok, written = pcall(instance.RecordTrainerList, instance, job.npcId, read)
  local rows = 0
  for _ in pairs(job.rows) do
    rows = rows + 1
  end
  CollectorHooks.lastTrainerRead = {
    npcId = job.npcId,
    rows = rows,
    missed = job.missed,
    full = full,
    slices = job.slices,
    ms = job.ms,
  }
  return ok and written == true
end

--- TRAINER_CLOSED: a read in flight is written as far as it got.
function CollectorHooks.OnTrainerClosed()
  local job = CollectorHooks.trainerPass
  if job then
    return CollectorHooks.FinishTrainerRead(job, false)
  end
  return false
end

-- A gathered node's name. The player's own cast of one of GATHER_SPELLS is sent with its target's
-- name as the client shows it (UNIT_SPELLCAST_SENT's second value); the cast is held with that
-- name, marked done when UNIT_SPELLCAST_SUCCEEDED names the same cast, and the loot window that
-- follows within NODE_MAX_AGE seconds takes the name for its game object source. Event values
-- only: no client call, no tooltip, no frame of the client's is read. Held in memory, never saved.
CollectorHooks.NODE_MAX_AGE = 5
CollectorHooks.pendingNode = nil

-- Brief C21: the bag slot a targeting spell is handed (the usual way to disenchant), held for
-- CollectorHooks.RememberDisenchantTarget. Below clockNow and guarded, which these read.
--- The item id of the slot a targeting spell was handed, held TARGET_MAX_AGE seconds, or nil.
function CollectorHooks.TakeTargetingItem()
  local held = CollectorHooks.targetingItem
  if type(held) ~= "table" then
    return nil
  end
  if clockNow() - (tonumber(held.at) or 0) > CollectorHooks.TARGET_MAX_AGE then
    CollectorHooks.targetingItem = nil
    return nil
  end
  return tonumber(held.id)
end

-- The post hook: a bag slot handed to a spell that is targeting. Reads the slot's item id and
-- holds it; nothing else. Answers the id held, or nil.
function CollectorHooks.OnUseContainerItem(bag, slot)
  local targeting = call("SpellIsTargeting")
  if not canRead(targeting) or targeting ~= true then
    return nil
  end
  bag, slot = tonumber(bag), tonumber(slot)
  if bag == nil or slot == nil then
    return nil
  end
  local id = nil
  local container = rawget(_G, "C_Container")
  if type(container) == "table" and type(container.GetContainerItemInfo) == "function" then
    local ok, info = pcall(container.GetContainerItemInfo, bag, slot)
    if ok and type(info) == "table" and canRead(info.itemID) then
      id = tonumber(info.itemID)
    end
  else
    id = tonumber(call("GetContainerItemID", bag, slot))
  end
  if not id then
    return nil
  end
  CollectorHooks.targetingItem = { id = id, at = clockNow() }
  return id
end

-- hooksecurefunc on the client's UseContainerItem, the namespaced one and the Era global, each
-- where the client has it. Idempotent; answers how many hooks took.
CollectorHooks.useHooks = nil
function CollectorHooks.InstallUseHook()
  if CollectorHooks.useHooks ~= nil then
    return CollectorHooks.useHooks
  end
  local hook = rawget(_G, "hooksecurefunc")
  local taken = 0
  if type(hook) == "function" then
    local function onUse(bag, slot)
      guarded("CollectorHooks.OnUseContainerItem", CollectorHooks.OnUseContainerItem, bag, slot)
    end
    local container = rawget(_G, "C_Container")
    if type(container) == "table" and type(rawget(container, "UseContainerItem")) == "function" then
      if pcall(hook, container, "UseContainerItem", onUse) then
        taken = taken + 1
      end
    end
    if type(rawget(_G, "UseContainerItem")) == "function" then
      if pcall(hook, "UseContainerItem", onUse) then
        taken = taken + 1
      end
    end
  end
  CollectorHooks.useHooks = taken
  return taken
end

--- UNIT_SPELLCAST_SENT: unit, target name, cast GUID, spell id.
function CollectorHooks.OnSpellcastSent(unit, target, castGuid, spellId)
  if unit ~= "player" or not CollectorHooks.GATHER_SPELLS[tonumber(spellId) or 0] then
    return nil
  end
  CollectorHooks.pendingNode = nil
  if not CollectorHooks.Enabled() then
    return nil
  end
  local name = CollectorHooks.ShownName(target)
  if not name or castGuid == nil then
    return nil
  end
  CollectorHooks.pendingNode = { name = name, cast = castGuid }
  return name
end

--- UNIT_SPELLCAST_SUCCEEDED: unit, cast GUID, spell id. Marks the held cast done.
function CollectorHooks.OnSpellcastSucceeded(unit, castGuid)
  local pending = CollectorHooks.pendingNode
  if unit ~= "player" or type(pending) ~= "table" or castGuid == nil or pending.cast ~= castGuid then
    return false
  end
  pending.done = clockNow()
  return true
end

--- The held node name for the loot window opening now, or nil, and the hold let go of either way.
function CollectorHooks.TakeNodeName()
  local pending = CollectorHooks.pendingNode
  CollectorHooks.pendingNode = nil
  if type(pending) ~= "table" or type(pending.done) ~= "number" then
    return nil
  end
  local age = clockNow() - pending.done
  if age < 0 or age > CollectorHooks.NODE_MAX_AGE then
    return nil
  end
  return pending.name
end

-- Brief SK1: what the loot window opening now came off, where the player's OWN cast named it. A
-- cast of one of CREATURE_LOOT_SPELLS is held by its cast GUID when UNIT_SPELLCAST_SENT names it,
-- marked done when UNIT_SPELLCAST_SUCCEEDED names the same cast (the order the node names above
-- already rely on, and the gathered node names in the mined bank prove), and read by the loot
-- window that follows within NODE_MAX_AGE seconds: its creature sources are then skinned,
-- pickpocketed or gathered from, never dropped. Read, not taken, so the loot ledger's own
-- LOOT_OPENED reads it too (Core/Ledger.lua); LOOT_CLOSED and the next such cast let go of it, and
-- combat starting lets go of a Pick Pocket (brief RV14). A
-- cast that never lands (interrupted, refused) is never done, and another player's cast never
-- reaches this: the events are the player's alone (RegisterUnitEvent, and the unit check here).
-- The spell id and the cast GUID only: no target, no name. Held in memory, never saved.
CollectorHooks.pendingCreatureLoot = nil

--- UNIT_SPELLCAST_SENT for a creature loot cast: unit, cast GUID, spell id. Answers the kind held.
function CollectorHooks.OnCreatureCastSent(unit, castGuid, spellId)
  local kind = CollectorHooks.CREATURE_LOOT_SPELLS[tonumber(spellId) or 0]
  if unit ~= "player" or not kind then
    return nil
  end
  CollectorHooks.pendingCreatureLoot = nil
  if not CollectorHooks.Enabled() or castGuid == nil then
    return nil
  end
  CollectorHooks.pendingCreatureLoot = { kind = kind, cast = castGuid }
  return kind
end

--- UNIT_SPELLCAST_SUCCEEDED: unit, cast GUID. Marks the held creature loot cast done.
function CollectorHooks.OnCreatureCastSucceeded(unit, castGuid)
  local pending = CollectorHooks.pendingCreatureLoot
  if unit ~= "player" or type(pending) ~= "table" or castGuid == nil or pending.cast ~= castGuid then
    return false
  end
  pending.done = clockNow()
  return true
end

-- Brief RV14 (review M1): whether the player's target is a living creature, the test Core/Ledger.lua's
-- loot window makes for its skip. Pick Pocket only ever loots a living creature, so a Pick Pocket
-- cast that landed and opened no window must not name the next window, a kill's, inside
-- NODE_MAX_AGE. Each read on a line of its own and asked of Util.CanRead before any compare: a GUID
-- or an answer the client keeps secret reads as no living target.
local function livingCreatureTarget()
  local guid = readCall("UnitGUID", "target")
  if guid == nil then
    return false
  end
  local ref = sanitiseGuid(guid)
  local map = ref and GUID_KINDS[ref.kind] or nil
  if not map or map.sourceKind ~= "npc" then
    return false
  end
  local dead = call("UnitIsDead", "target")
  if not canRead(dead) then
    return false
  end
  return not dead
end

--- The record kind the loot window opening now takes a creature's loot as ("skin", "pickpocket"
--- or "gather"), or nil for a plain kill's loot. Leaves the hold in place. Brief RV14: a Pick
--- Pocket names the window only while the target is a living creature; a dead target's window is
--- a kill or a skin, never a pocket.
function CollectorHooks.CreatureLootKind()
  local pending = CollectorHooks.pendingCreatureLoot
  if type(pending) ~= "table" or type(pending.done) ~= "number" then
    return nil
  end
  local age = clockNow() - pending.done
  if age < 0 or age > CollectorHooks.NODE_MAX_AGE then
    return nil
  end
  if pending.kind == "pickpocket" and not livingCreatureTarget() then
    return nil
  end
  return pending.kind
end

--- Brief RV14 (review M1): PLAYER_REGEN_DISABLED. A Pick Pocket is never cast in combat, so combat
--- starting lets go of a held Pick Pocket cast (one that opened no window, or a pocket the creature
--- noticed). A Skinning or creature gathering hold stays: a player can skin with a creature on
--- them. Answers true when a hold was let go of.
function CollectorHooks.OnCombatStart()
  local pending = CollectorHooks.pendingCreatureLoot
  if type(pending) == "table" and pending.kind == "pickpocket" then
    CollectorHooks.pendingCreatureLoot = nil
    return true
  end
  return false
end

--------------------------------------------------------------------------------
-- Brief R12: a gathering node seen on hover, profession or not
--------------------------------------------------------------------------------

-- UI/Tooltip.lua's install registers one more post call with the client's tooltip data processor,
-- for the world object data type, beside its item one (no hook on any tooltip frame), and hands
-- each call here. The tooltip is read once a show: the first line out of the data the processor
-- handed over, or, where the data carries no lines, the tooltip's own first line under pcall. A
-- line that is not a known world object's name (Collector C:IsNodeName: every object name the
-- Classic Era table files, herbs, veins, fishing pools, chests, quest objects and books, since
-- brief R13, and the names the player's own gathers, fishing and opened objects recorded) records
-- nothing, so no NPC, player, item name or free text can land in the store.
--
-- The processor calls again on every rebuild of a tooltip still on screen, so the same first line
-- inside NODE_HOVER_REPEAT seconds stops before any position is read (10 before brief R14; 3 now,
-- so a hover run follows the player to where they stop). A cell counts once per name, map, cell and
-- layer a day: the cells counted today are held in memory (nodeSeen, cleared when the day turns),
-- so a reload the same day may count a cell once more, and nothing extra is saved.
--
-- Brief R14 (owner ruling 2026-10-04: the tooltip is the broad stroke, a gather the real spot). A
-- hover places the PLAYER, not the node, so a hover RUN, consecutive sightings of one name on one
-- map each within NODE_RUN_SECONDS of the one before, holds ONE count in the hover layer ("h")
-- and moves it to each new cell, keeping the run's last cell (nodeRun, in memory only). A gather of
-- that name (NoteNodeGather) within NODE_RUN_SECONDS of the run's last sighting and within
-- NODE_GATHER_NEAR cells of its cell takes the run's count back: the gather cell ("g") alone stays.
CollectorHooks.NODE_HOVER_REPEAT = 3
CollectorHooks.NODE_RUN_SECONDS = 60
CollectorHooks.NODE_GATHER_NEAR = 2
CollectorHooks.lastNodeHover = nil
CollectorHooks.nodeSeen = nil
CollectorHooks.nodeRun = nil
-- Brief R14b (R14 QA failed on Stunted Silverleaf: the tooltip stays on the node while its loot
-- window is open, and started a new run 3 s after the gather, so "h" came back beside "g"): the
-- last gather's name, map and time, in memory only. A hover of that name on that map within
-- NODE_RUN_SECONDS of the gather is the gather's own and starts no run.
CollectorHooks.nodeGathered = nil

-- Today's counted cells, a fresh set once the day turns.
local function nodeSeenToday(day)
  local seen = CollectorHooks.nodeSeen
  if type(seen) ~= "table" or seen.day ~= day or type(seen.cells) ~= "table" then
    seen = { day = day, cells = {} }
    CollectorHooks.nodeSeen = seen
  end
  return seen
end

-- The key a counted cell is held under in nodeSeen: the layer, the name, the map and the cell.
local function nodeSlot(layer, name, map, cell)
  return layer .. "\0" .. name .. "\0" .. tostring(map) .. "\0" .. tostring(cell)
end

-- Takes the run's hover count back off its cell, where the run wrote one. Answers true when taken.
local function dropRunCount(Places, places, run, seen)
  if not run.counted then
    return false
  end
  run.counted = false
  local ok, removed = pcall(Places.Remove, places, Places.NODE, run.name, run.map, run.cell, Places.HOVERED)
  if seen.day == run.day then
    seen.cells[nodeSlot(Places.HOVERED, run.name, run.map, run.cell)] = nil
  end
  return ok and removed == true
end

-- The tooltip's own first line, for data that carried none: GetUnit first, under pcall, and a
-- tooltip showing a unit answers nothing; then the "<name>TextLeft1" font string's text.
local function tooltipFirstLine(tooltip)
  if type(tooltip) ~= "table" then
    return nil
  end
  if type(tooltip.GetUnit) == "function" then
    local ok, unitName = pcall(tooltip.GetUnit, tooltip)
    -- Brief SV1: a secret unit name is a unit all the same, and is never compared.
    if not ok or not canRead(unitName) or unitName ~= nil then
      return nil
    end
  end
  if type(tooltip.GetName) ~= "function" then
    return nil
  end
  local okName, frameName = pcall(tooltip.GetName, tooltip)
  if not okName or not canRead(frameName) or type(frameName) ~= "string" then
    return nil
  end
  local line = rawget(_G, frameName .. "TextLeft1")
  if type(line) ~= "table" or type(line.GetText) ~= "function" then
    return nil
  end
  -- Brief SV1: a font string the client gave secret text answers a secret from GetText.
  local okText, text = pcall(line.GetText, line)
  if not okText or not canRead(text) then
    return nil
  end
  if type(text) == "string" and text ~= "" then
    return text
  end
  return nil
end

local function objectDataType()
  local enum = rawget(_G, "Enum")
  local types = type(enum) == "table" and rawget(enum, "TooltipDataType") or nil
  return type(types) == "table" and rawget(types, "Object") or nil
end

--- A world object's tooltip (tooltip, data as the processor hands them over): where its first
--- line is a known world object's name (a node, a chest or another named object), the player's
--- position into the places store under that name (kind "n"), once per name, map and cell a day.
--- Answers the name recorded, or nil.
function CollectorHooks.NoteNodeTooltip(tooltip, data)
  if not CollectorHooks.Enabled() then
    return nil
  end
  if not CollectorHooks.IsObjectData(data, objectDataType()) then
    return nil
  end
  local Places = ItemTree.Places
  local db = ItemTree.db
  local instance = ItemTree.collector
  if type(Places) ~= "table" or type(Places.Add) ~= "function" or type(db) ~= "table" then
    return nil
  end
  if type(instance) ~= "table" or type(instance.IsNodeName) ~= "function" then
    return nil
  end
  local text = CollectorHooks.TooltipFirstLine(data)
  if text == nil and (type(data) ~= "table" or type(data.lines) == "nil") then
    text = tooltipFirstLine(tooltip)
  end
  local name = CollectorHooks.ShownName(text)
  if not name then
    return nil
  end
  local now = clockNow()
  local last = CollectorHooks.lastNodeHover
  if
    type(last) == "table"
    and last.name == name
    and now >= last.at
    and now - last.at < CollectorHooks.NODE_HOVER_REPEAT
  then
    return nil
  end
  -- One table, refilled, rather than one per name hovered.
  if type(last) == "table" then
    last.name, last.at = name, now
  else
    CollectorHooks.lastNodeHover = { name = name, at = now }
  end
  local okKnown, known = pcall(instance.IsNodeName, instance, name)
  if not okKnown or known ~= true then
    return nil
  end
  local pos = CollectorHooks.PlayerPosition()
  local cell = type(pos) == "table" and Places.Cell(pos.x, pos.y) or nil
  if not cell then
    return nil
  end
  -- Brief R14b: the name just gathered here is not hovered again for a minute.
  local gathered = CollectorHooks.nodeGathered
  if
    type(gathered) == "table"
    and gathered.name == name
    and gathered.map == pos.map
    and now >= gathered.at
    and now - gathered.at < CollectorHooks.NODE_RUN_SECONDS
  then
    return nil
  end
  local day = Places.Day(now)
  local seen = nodeSeenToday(day)
  if type(db.places) ~= "table" then
    db.places = {}
  end
  -- Brief R14: the hover run. One that goes on (same name and map, the last sighting under
  -- NODE_RUN_SECONDS ago) moves its count to this cell; any other sighting starts a new run.
  local run = CollectorHooks.nodeRun
  local goesOn = type(run) == "table"
    and run.name == name
    and run.map == pos.map
    and now >= run.at
    and now - run.at < CollectorHooks.NODE_RUN_SECONDS
  if goesOn and run.cell == cell then
    run.at = now
    return nil
  end
  if goesOn then
    dropRunCount(Places, db.places, run, seen)
  else
    run = { name = name, map = pos.map }
    CollectorHooks.nodeRun = run
  end
  run.cell, run.at, run.day, run.counted = cell, now, day, false
  local slot = nodeSlot(Places.HOVERED, name, pos.map, cell)
  if seen.cells[slot] then
    -- Counted today already: the run rides on that count and writes nothing.
    return nil
  end
  local ok, written = pcall(Places.Add, db.places, Places.NODE, name, pos.map, pos.x, pos.y, day, nil, Places.HOVERED)
  if not ok or written ~= true then
    return nil
  end
  seen.cells[slot] = true
  run.counted = true
  return name
end

--- Brief R14: a gather's loot window (CollectorHooks.OnLootOpened, for the node name the player's
--- own gathering cast named): the player's position into the places store's gather layer under
--- that name, once per name, map and cell a day. A hover run of the same name on the same map,
--- last seen under NODE_RUN_SECONDS ago and within NODE_GATHER_NEAR cells of here, loses its hover
--- count and ends. Brief R14b: hovers of the name here are ignored for NODE_RUN_SECONDS after it
--- (nodeGathered). map is the uiMap the window already read, or nil. Answers the name recorded, or
--- nil.
function CollectorHooks.NoteNodeGather(name, map)
  if not CollectorHooks.Enabled() then
    return nil
  end
  local Places = ItemTree.Places
  local db = ItemTree.db
  if type(Places) ~= "table" or type(Places.Add) ~= "function" or type(db) ~= "table" then
    return nil
  end
  name = CollectorHooks.ShownName(name)
  if not name then
    return nil
  end
  local pos = CollectorHooks.PlayerPosition(map)
  local cell = type(pos) == "table" and Places.Cell(pos.x, pos.y) or nil
  if not cell then
    return nil
  end
  local now = clockNow()
  local day = Places.Day(now)
  local seen = nodeSeenToday(day)
  if type(db.places) ~= "table" then
    db.places = {}
  end
  -- Brief R14b: the hovers of this name here, for the next minute, are this gather's own (one
  -- table, refilled).
  local gathered = CollectorHooks.nodeGathered
  if type(gathered) == "table" then
    gathered.name, gathered.map, gathered.at = name, pos.map, now
  else
    CollectorHooks.nodeGathered = { name = name, map = pos.map, at = now }
  end
  local run = CollectorHooks.nodeRun
  if
    type(run) == "table"
    and run.name == name
    and run.map == pos.map
    and now >= run.at
    and now - run.at <= CollectorHooks.NODE_RUN_SECONDS
    and type(Places.Near) == "function"
    and Places.Near(run.cell, cell, CollectorHooks.NODE_GATHER_NEAR)
  then
    dropRunCount(Places, db.places, run, seen)
    CollectorHooks.nodeRun = nil
  end
  local slot = nodeSlot(Places.GATHERED, name, pos.map, cell)
  if seen.cells[slot] then
    return nil
  end
  local ok, written = pcall(Places.Add, db.places, Places.NODE, name, pos.map, pos.x, pos.y, day, nil, Places.GATHERED)
  if not ok or written ~= true then
    return nil
  end
  seen.cells[slot] = true
  return name
end

-- The R9 events into their handlers, each body under the boundary. Answers true when the event
-- was one of these.
function CollectorHooks.DispatchR9(event, ...)
  if event == "TRAINER_SHOW" then
    guarded("CollectorHooks.OnTrainerShow", CollectorHooks.OnTrainerShow)
    -- Brief TW1: and the window's rows, where trainer lists are recorded.
    guarded("CollectorHooks.StartTrainerRead", CollectorHooks.StartTrainerRead)
  elseif event == "PET_STABLE_SHOW" then
    guarded("CollectorHooks.OnStableShow", CollectorHooks.OnStableShow)
  elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
    guarded("CollectorHooks.OnInteractionShow", CollectorHooks.OnInteractionShow, ...)
    local Places = ItemTree.Places
    if CollectorHooks.InteractionKind(...) == (Places and Places.TRAINER or "t") then
      guarded("CollectorHooks.StartTrainerRead", CollectorHooks.StartTrainerRead)
    end
  elseif event == "TRAINER_UPDATE" then
    -- Brief TW1: a filter ticked or a row bought: the rows are read again where they changed.
    guarded("CollectorHooks.StartTrainerRead", CollectorHooks.StartTrainerRead, true)
  elseif event == "TRAINER_CLOSED" then
    guarded("CollectorHooks.OnTrainerClosed", CollectorHooks.OnTrainerClosed)
  else
    return false
  end
  return true
end

--------------------------------------------------------------------------------
-- The ledger's kills, Disenchant windows and quest item windows (brief R4)
--
-- Core/Ledger.lua counts; this section only hands it what this file already watches.
--
-- Kills. A party kill is COMBAT_LOG_EVENT_UNFILTERED's PARTY_KILL, read through
-- CombatLogGetCurrentEventInfo. That event fires for every swing and tick around the player, so
-- it is listened for on a frame of its own whose handler reads the event once, makes one
-- comparison and returns: no table, no string, no other call on that path. It is registered only
-- while "Record what you see" is on (the setting's changed callback and every loot window put the
-- registration right), and only on a client that lets an addon read the combat log. The forever
-- branch does not: COMBAT_LOG_EVENT_UNFILTERED is marked HasRestrictions and GetCurrentEventInfo
-- lives in C_CombatLogSecure (SecureOnly) and C_CombatLogInternal
-- (Blizzard_APIDocumentationGenerated/CombatLogSecureDocumentation.lua and
-- CombatLogInternalDocumentation.lua); Blizzard_DeprecatedCombatLog/Deprecated_CombatLog.lua
-- points CombatLogGetCurrentEventInfo at C_CombatLog.GetCurrentEventInfo, which the public
-- CombatLogDocumentation.lua does not carry, and Blizzard_CombatLog itself now listens for
-- COMBAT_LOG_MESSAGE instead. Registering a restricted event from an addon is exactly what the
-- taint rule forbids, so on such a client nothing is registered and k stays empty.
--
-- Disenchant windows. The window after a Disenchant cast has no source GUID, which is how
-- CollectorHooks.OnLootOpened already tells it apart; the same slots are counted into the
-- ledger's disenchant kind under the item that went in, at the same moment.
--
-- Quest item windows. The item objectives of the quest log name items in words, so which items
-- are a current objective comes from what already names them by id: the collector's own
-- quest_requires records (written when an objective matched, or off the turn in window) and,
-- once the data rows are loaded, Classic Era's quest requirements, each for a quest the log's
-- objective index holds. Nothing here can say which creatures drop an item, so the ledger counts
-- iqw (windows while the item was an objective) only from a creature already known to drop it
-- and iq for those windows the item was in: a rate is iq / iqw.
--------------------------------------------------------------------------------

CollectorHooks.COMBAT_LOG_EVENT = "COMBAT_LOG_EVENT_UNFILTERED"
local PARTY_KILL = "PARTY_KILL"

-- The client call that reads the combat log event being handled, or nil on a client where an
-- addon may not read the combat log (the secure combat log namespaces are there) or has no
-- such call.
function CollectorHooks.CombatLogReader()
  if rawget(_G, "C_CombatLogSecure") ~= nil or rawget(_G, "C_CombatLogInternal") ~= nil then
    return nil
  end
  local reader = rawget(_G, "CombatLogGetCurrentEventInfo")
  if type(reader) ~= "function" then
    return nil
  end
  return reader
end

-- Set once the combat log frame is made, and what the handler reads through.
local readCombatLog = nil

-- How many PARTY_KILL events reached the ledger, for a spec to read back.
CollectorHooks.kills = 0

-- COMBAT_LOG_EVENT_UNFILTERED. The event info is timestamp, subEvent, hideCaster, sourceGUID,
-- sourceName, sourceFlags, sourceRaidFlags, destGUID, ...; pcall's ok comes first. Every sub
-- event but PARTY_KILL returns after the one comparison. Answers true when a kill was counted.
function CollectorHooks.OnCombatLog()
  local _, _, subEvent, _, _, _, _, _, destGuid = pcall(readCombatLog)
  -- Brief SV1: no secret check on this path, on purpose: it is one comparison per combat log
  -- event, and CombatLogReader never registers it on a client with the secure combat log
  -- namespaces, which the Forever client (the one with secret values) has.
  if subEvent ~= PARTY_KILL then
    return false
  end
  local ledger = ItemTree.Ledger
  if type(ledger) ~= "table" or type(ledger.OnKill) ~= "function" then
    return false
  end
  local ok, counted = pcall(ledger.OnKill, destGuid)
  if ok and counted then
    CollectorHooks.kills = CollectorHooks.kills + 1
    -- Brief QF1: the kill, for the ledger rule's quest goal read.
    pcall(CollectorHooks.NoteKill, destGuid)
    return true
  end
  return false
end

CollectorHooks.combatLogFrame = nil
CollectorHooks.combatLogRegistered = false

-- Registers the combat log event while the setting is on and unregisters it while it is off.
-- Answers whether it is registered.
function CollectorHooks.SyncCombatLog()
  local frame = CollectorHooks.combatLogFrame
  if not frame then
    return false
  end
  local want = CollectorHooks.Enabled()
  if want == CollectorHooks.combatLogRegistered then
    return want
  end
  if want then
    CollectorHooks.combatLogRegistered = pcall(frame.RegisterEvent, frame, CollectorHooks.COMBAT_LOG_EVENT)
  else
    pcall(frame.UnregisterEvent, frame, CollectorHooks.COMBAT_LOG_EVENT)
    CollectorHooks.combatLogRegistered = false
  end
  return CollectorHooks.combatLogRegistered
end

-- Idempotent. The combat log frame, or nil on a client where it is not wanted (see above) or
-- outside the client.
function CollectorHooks.InstallCombatLog()
  if CollectorHooks.combatLogFrame then
    return CollectorHooks.combatLogFrame
  end
  local reader = CollectorHooks.CombatLogReader()
  local createFrame = rawget(_G, "CreateFrame")
  if not reader or type(createFrame) ~= "function" then
    return nil
  end
  local ok, frame = pcall(createFrame, "Frame")
  if not ok or type(frame) ~= "table" or type(frame.RegisterEvent) ~= "function" then
    return nil
  end
  if
    type(frame.SetScript) ~= "function" or not pcall(frame.SetScript, frame, "OnEvent", CollectorHooks.OnCombatLog)
  then
    return nil
  end
  readCombatLog = reader
  CollectorHooks.combatLogFrame = frame
  CollectorHooks.combatLogRegistered = false
  CollectorHooks.SyncCombatLog()
  -- The settings panel fires ITEMTREE_SETTING_CHANGED (UI/Options.lua) through CallbackHandler.
  if type(ItemTree.RegisterCallback) == "function" then
    pcall(ItemTree.RegisterCallback, CollectorHooks, "ITEMTREE_SETTING_CHANGED", function(_, key)
      if key == "collectorEnabled" then
        CollectorHooks.SyncCombatLog()
      end
    end)
  end
  return frame
end

-- Whether any of a loot slot's sources is one the collector files a drop, gather or container
-- under, which is what a Disenchant window's slots lack.
local function slotHasSource(slot)
  local sources = { call("GetLootSourceInfo", slot) }
  for index = 1, #sources, 2 do
    if CollectorHooks.ClassifyLootSource(sources[index]) then
      return true
    end
  end
  return false
end

-- The Disenchant window into the ledger: the slots with no source, under the item that went in.
-- Only while a Disenchant cast is pending and its item could be read. Answers the ledger's
-- disenchant entry, or nil.
function CollectorHooks.CountDisenchantWindow()
  if not CollectorHooks.pendingDisenchant or not CollectorHooks.Enabled() then
    return nil
  end
  local target = tonumber(CollectorHooks.disenchantTarget)
  local ledger = ItemTree.Ledger
  if not target or type(ledger) ~= "table" or type(ledger.OnDisenchant) ~= "function" then
    return nil
  end
  local items, any = {}, false
  for slot = 1, countOf(call("GetNumLootItems")) do
    local itemId = itemIdFromLink(call("GetLootSlotLink", slot))
    if itemId and not slotHasSource(slot) then
      local _, _, quantity = call("GetLootSlotInfo", slot)
      local count = countOf(quantity)
      if count == 0 then
        count = 1
      end
      items[itemId] = (items[itemId] or 0) + count
      any = true
    end
  end
  if not any then
    return nil
  end
  local ok, source = pcall(ledger.OnDisenchant, target, items)
  return ok and source or nil
end

-- LOOT_OPENED's part in this section: the Disenchant window, and the combat log registration
-- put right should the setting have changed without its callback.
function CollectorHooks.OnLootOpenedLedger()
  CollectorHooks.SyncCombatLog()
  return CollectorHooks.CountDisenchantWindow()
end

-- The items that are a current quest objective, as { [itemId] = true }. index is
-- ObjectiveIndexFrom's; records is the collector's store of rows by key (collector.records), of
-- which only the quest_requires keys are read; requiresOf, optional, answers a quest's required
-- items as { { itemId, count } } (EraSources' QuestRequires). Pure apart from requiresOf.
--
-- Brief QH1: the second answer is the same items by the quest asking for them, { [itemId] = questId },
-- false where two quests in the log ask for one item (a loot row then names no quest).
function CollectorHooks.ObjectiveItemsFrom(index, records, requiresOf)
  local out, quests, byItem = {}, {}, {}
  local function ask(itemId, questId)
    out[itemId] = true
    local held = byItem[itemId]
    if held == nil then
      byItem[itemId] = questId
    elseif held ~= questId then
      byItem[itemId] = false
    end
  end
  for _, bucket in pairs(type(index) == "table" and index or {}) do
    for _, entry in ipairs(type(bucket) == "table" and bucket or {}) do
      local questId = type(entry) == "table" and tonumber(entry.questId) or nil
      if questId then
        quests[questId] = true
      end
    end
  end
  if next(quests) == nil then
    return out, byItem
  end
  local Collector = ItemTree.Collector
  local prefix = nil
  if type(Collector) == "table" and type(Collector.Key) == "function" and type(Collector.ParseKey) == "function" then
    prefix = (Collector.Key("quest_requires", 1, "quest", 1) or ""):match("^[^:]+:")
  end
  if prefix and type(records) == "table" then
    for key in pairs(records) do
      if type(key) == "string" and key:find(prefix, 1, true) == 1 then
        local kind, itemId, sourceKind, questId = Collector.ParseKey(key)
        if kind == "quest_requires" and sourceKind == "quest" and quests[questId] and itemId then
          ask(itemId, questId)
        end
      end
    end
  end
  if type(requiresOf) == "function" then
    for questId in pairs(quests) do
      local list = requiresOf(questId)
      for _, entry in ipairs(type(list) == "table" and list or {}) do
        local itemId = type(entry) == "table" and tonumber(entry[1]) or nil
        if itemId then
          ask(itemId, questId)
        end
      end
    end
  end
  return out, byItem
end

-- The set above for the log as it stands, kept until the objective index, the collector's quest
-- requirement rows (Collector.requiresGeneration, which only a quest_requires write, an eviction of
-- one, Clear or a full reset moves, so a loot or a merchant window leaves the set standing), the
-- store those rows are in, or the Classic Era rows it may read change. nil while the setting is
-- off or no quest in the log asks for an item.
CollectorHooks.objectiveItems = nil
-- Brief QH1: the same set by the one quest asking for each item (ObjectiveItemsFrom's second answer).
CollectorHooks.objectiveQuests = nil
local objectiveItemsIndex, objectiveItemsGeneration = nil, nil
local objectiveItemsRecords, objectiveItemsEra = nil, nil

function CollectorHooks.CurrentObjectiveItems()
  if not CollectorHooks.Enabled() then
    return nil
  end
  local index = CollectorHooks.QuestObjectiveIndex()
  if type(index) ~= "table" or next(index) == nil then
    return nil
  end
  local generation = type(ItemTree.Collector) == "table" and ItemTree.Collector.requiresGeneration or nil
  local instance = collector()
  local store = instance and instance.store
  local records = type(store) == "table" and store.records or nil
  -- Brief U3: Classic Era's requirements only once the data rows are loaded, so a loot window at
  -- login never loads ItemTree_Data.
  local era = ItemTree.eraSources
  if not (itemRowsLoaded() and type(era) == "table" and type(era.QuestRequires) == "function") then
    era = nil
  end
  if
    CollectorHooks.objectiveItems
    and objectiveItemsIndex == index
    and objectiveItemsGeneration == generation
    and objectiveItemsRecords == records
    and objectiveItemsEra == era
  then
    return CollectorHooks.objectiveItems
  end
  local requiresOf = nil
  if era then
    requiresOf = function(questId)
      local ok, list = pcall(era.QuestRequires, era, questId)
      return ok and list or nil
    end
  end
  local set, byItem = CollectorHooks.ObjectiveItemsFrom(index, records, requiresOf)
  CollectorHooks.objectiveItems = set
  CollectorHooks.objectiveQuests = byItem
  objectiveItemsIndex, objectiveItemsGeneration = index, generation
  objectiveItemsRecords, objectiveItemsEra = records, era
  return set
end

--- Brief QH1: the one quest in the log asking for this item (CurrentObjectiveItems read by quest), or
--- nil where none or two do, the setting is off or no quest in the log asks for an item. The set is
--- the one the ledger's quest item windows already read, kept until the log changes: no new walk.
function CollectorHooks.ObjectiveQuestOf(itemId)
  local set = CollectorHooks.CurrentObjectiveItems()
  if type(set) ~= "table" or not set[itemId] then
    return nil
  end
  local byItem = CollectorHooks.objectiveQuests
  local questId = type(byItem) == "table" and byItem[itemId] or nil
  return type(questId) == "number" and questId or nil
end

--------------------------------------------------------------------------------
-- What a quest hands over (brief QH1)
--------------------------------------------------------------------------------

-- Owner, QA item 375 ("we should add it if possible") and 2026-10-22 ("We also want the collector
-- updated to collect objects a quest giver gives etc"). The client states no quest's provided item:
-- no API names it (QuestLogDocumentation.lua at build 70450 holds questStartItemID, the item that
-- STARTED a quest, and nothing for the item one hands over), and QUEST_LOOT_RECEIVED
-- (LootDocumentation.lua:319) is a reward's loot toast (Blizzard_FrameXML Mainline/AlertFrames.lua:717,
-- world quests and invasions). So the signal is the client's own "you were handed this" line: the
-- CHAT_MSG_LOOT line (ChatInfoDocumentation.lua:1816) that starts with LOOT_ITEM_PUSHED_SELF or
-- LOOT_ITEM_PUSHED_SELF_MULTIPLE ("You receive item: %s." / "%sx%d."), the server pushing an item
-- into the bags, as against a looted item ("You receive loot:") or a crafted one ("You create:"). It
-- names the item by link and the count, costs no bag walk and no query, and OnChatLoot already reads
-- it. A bag delta inside the accept window was the other choice: it needs every bag walked twice and
-- cannot tell a push from a purchase or a loot.
--
-- A pushed line belongs to a quest only by when it came, so the rule is bounded and errs towards
-- writing nothing:
--   * never while a merchant window is open (a purchase prints the same line; MERCHANT_SHOW and
--     MERCHANT_CLOSED, MerchantFrameDocumentation.lua:112 and :96), and never an item a turn in
--     window listed as a reward in the last HANDOVER_REWARD_SECONDS (the reward lands as the same
--     line, often before QUEST_TURNED_IN);
--   * each line is held HANDOVER_SECONDS (GetTime, SystemTimeDocumentation.lua:57) and then placed:
--     exactly one quest accepted within HANDOVER_SECONDS either side of it (QUEST_ACCEPTED's questId,
--     QuestLogDocumentation.lua:1312) is "accept"; two different ones are ambiguous and write
--     nothing; else exactly one quest turned in that close (QUEST_TURNED_IN, :1396) is "turnin";
--     else, while a gossip window was open or had just closed (GOSSIP_SHOW and GOSSIP_CLOSED,
--     GossipInfoDocumentation.lua:277 and :233), the one quest in the log asking for the item
--     (ObjectiveQuestOf, the ledger's own objective set) is "quest", with the gossip creature as the
--     giver; else nothing.
-- Only the quest being accepted, handed in or worked is ever named, by its own id from its own
-- event: never a walk of the log, never a list of ids (memory: no bulk API calls). In memory only,
-- never saved, until a hand-over is written (Core/Collector.lua C:RecordQuestHandover).
CollectorHooks.HANDOVER_SECONDS = 2
CollectorHooks.HANDOVER_REWARD_SECONDS = 60
-- The most lines, accepts and turn ins held at once.
CollectorHooks.HANDOVER_HELD = 8
CollectorHooks.PUSHED_GLOBALS = { "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }

CollectorHooks.heldPushes = {}
CollectorHooks.recentAccepts = {}
CollectorHooks.recentTurnIns = {}
-- questId -> { items = { [itemId] = true }, at }: the rewards each turn in window listed.
CollectorHooks.turnInRewards = {}
-- { npcId, at, closed }: the gossip window's creature, while open and HANDOVER_SECONDS after.
CollectorHooks.gossip = nil
-- { at, closed }: the merchant window.
CollectorHooks.merchant = nil

--- A Lua pattern out of one of the client's chat formats ("You receive item: %sx%d."): the item
--- (%s) and a count (%d) captured, everything else matched as it is. nil for a format with no %s.
--- Pure.
function CollectorHooks.PatternFromFormat(format)
  if type(format) ~= "string" or not format:find("%s", 1, true) then
    return nil
  end
  local pattern = format:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
  pattern = pattern:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
  return "^" .. pattern .. "$"
end

--- How many of an item a pushed line hands over: the count of a LOOT_ITEM_PUSHED_SELF_MULTIPLE line,
--- 1 for a LOOT_ITEM_PUSHED_SELF one, nil for any other line. single and multiple are the two
--- formats as the client holds them. Pure.
function CollectorHooks.PushedCount(message, single, multiple)
  if type(message) ~= "string" then
    return nil
  end
  local many = CollectorHooks.PatternFromFormat(multiple)
  if many then
    local _, count = message:match(many)
    count = tonumber(count)
    if count and count >= 1 then
      return math.floor(count)
    end
  end
  local one = CollectorHooks.PatternFromFormat(single)
  if one and message:match(one) then
    return 1
  end
  return nil
end

--- Pure: where one held line belongs, by when it came. push is { item, at }; accepts { { questId,
--- at } }; turnIns { { questId, at, rewards = { [itemId] = true } } }; window the seconds either
--- side. Answers questId and "accept" or "turnin"; nil and "ambiguous" where two quests (or a reward)
--- were that close; nil where nothing was.
function CollectorHooks.HandoverFor(push, accepts, turnIns, window)
  if type(push) ~= "table" or type(push.at) ~= "number" then
    return nil
  end
  window = tonumber(window) or CollectorHooks.HANDOVER_SECONDS
  local function near(at)
    return type(at) == "number" and math.abs(at - push.at) <= window
  end
  local accepted = nil
  for _, entry in ipairs(type(accepts) == "table" and accepts or {}) do
    if type(entry) == "table" and near(entry.at) then
      if accepted and accepted ~= entry.questId then
        return nil, "ambiguous"
      end
      accepted = entry.questId
    end
  end
  if accepted then
    return accepted, "accept"
  end
  local turned = nil
  for _, entry in ipairs(type(turnIns) == "table" and turnIns or {}) do
    if type(entry) == "table" and near(entry.at) then
      if (turned and turned ~= entry.questId) or (type(entry.rewards) == "table" and entry.rewards[push.item]) then
        return nil, "ambiguous"
      end
      turned = entry.questId
    end
  end
  if turned then
    return turned, "turnin"
  end
  return nil
end

-- The hand-over clock: the client's GetTime (fractions of a second), else the collector's own.
local function handoverNow()
  local now = tonumber(call("GetTime"))
  if now then
    return now
  end
  return clockNow()
end
CollectorHooks.HandoverNow = handoverNow

-- A list kept to its newest HANDOVER_HELD entries, those older than keep seconds dropped.
local function prune(list, now, keep)
  local out = {}
  for _, entry in ipairs(list) do
    if type(entry) == "table" and type(entry.at) == "number" and now - entry.at <= keep then
      out[#out + 1] = entry
    end
  end
  while #out > CollectorHooks.HANDOVER_HELD do
    table.remove(out, 1)
  end
  return out
end

-- Whether a window opened at { at, closed } is open now (no close since it opened).
local function windowOpen(held)
  if type(held) ~= "table" or type(held.at) ~= "number" then
    return false
  end
  local closed = tonumber(held.closed)
  return closed == nil or closed < held.at
end

-- Whether a window opened at { at, closed } is open now or closed within HANDOVER_SECONDS.
local function windowFresh(held, now)
  if type(held) ~= "table" or type(held.at) ~= "number" then
    return false
  end
  local closed = tonumber(held.closed)
  return closed == nil or closed < held.at or now - closed <= CollectorHooks.HANDOVER_SECONDS
end

local function recordHandover(questId, entry)
  local instance = collector()
  if not instance or type(instance.RecordQuestHandover) ~= "function" or not CollectorHooks.Enabled() then
    return false
  end
  local ok, stored = pcall(instance.RecordQuestHandover, instance, questId, entry)
  return ok and stored == true
end

--- Brief QH1: the turn in window's rewards for one quest (QuestRewards' list), held so the reward's
--- own pushed line is never read as a hand-over.
function CollectorHooks.HoldTurnInRewards(questId, rewards)
  if type(questId) ~= "number" then
    return false
  end
  local items = {}
  for _, reward in ipairs(type(rewards) == "table" and rewards or {}) do
    local itemId = type(reward) == "table" and tonumber(reward.itemId) or nil
    if itemId then
      items[itemId] = true
    end
  end
  CollectorHooks.turnInRewards[questId] = { items = items, at = handoverNow() }
  return true
end

-- Whether an item is a reward some turn in window listed in the last HANDOVER_REWARD_SECONDS.
local function isRecentReward(itemId, now)
  for questId, held in pairs(CollectorHooks.turnInRewards) do
    if type(held) ~= "table" or type(held.at) ~= "number" or now - held.at > CollectorHooks.HANDOVER_REWARD_SECONDS then
      CollectorHooks.turnInRewards[questId] = nil
    elseif held.items[itemId] then
      return true
    end
  end
  return false
end

--------------------------------------------------------------------------------
-- Brief RF375 (the review's M3): a pushed line near an accept is not proof the quest handed the item
-- over (a mage's conjured water, a created item or a mail taken at that moment print the same line). A
-- placed line is held as a hand-over only where our data says the item is a quest item (quest class 12,
-- or bound to the quest or on pickup, bonding 4 or 1: CollectorHooks.HandoverItem) or the quest's own
-- facts already name it (CollectorHooks.QuestNamesItem: its predicted objectives or provided items, its
-- Classic Era required items, its objective text in the log); otherwise it is dropped. Brief RF375 fix 7
-- (the owner's "A"): a line dropped inside a hand-over window (an accept, a turn in, a gossip window) is
-- kept in the collector's rolling audit log with its reason (Core/Collector.lua C:RecordPushDrop), never
-- for any verdict, page or share.
--------------------------------------------------------------------------------

-- The bondings a quest may hand an item over with: 1 bind on pickup, 4 quest bound.
CollectorHooks.HANDOVER_BONDINGS = { [1] = true, [4] = true }

--- Whether our data makes an item one a quest may hand over: quest class (12) or bonding 1 or 4, from
--- the item rows where they are loaded (brief U3: never loading them for this), else the client's class
--- for the item just pushed into the bags (UI/Client.lua ItemFacts, one item, already in the bags).
function CollectorHooks.HandoverItem(itemId)
  local id = tonumber(itemId)
  if not id then
    return false
  end
  local data = ItemTree.Data
  if itemRowsLoaded() and type(data) == "table" and type(data.GetItem) == "function" then
    local ok, row = pcall(data.GetItem, data, id)
    if ok and type(row) == "table" then
      return tonumber(row.c) == CollectorHooks.QUEST_ITEM_CLASS
        or CollectorHooks.HANDOVER_BONDINGS[tonumber(row.b) or -1] == true
    end
  end
  local facts = itemFacts(id)
  return type(facts) == "table" and tonumber(facts.classId) == CollectorHooks.QUEST_ITEM_CLASS
end

--- Whether one quest's facts already name the item: its predicted objectives or provided items
--- (Core/QuestsPredicted.lua, never loading ItemTree_Data), its Classic Era required items (the
--- table's qr, only once the item rows are loaded, as CurrentObjectiveItems reads them) or an item
--- objective of it in the log naming the item (QuestObjectiveIndex, the log's own words). That one
--- quest only, by its own id.
function CollectorHooks.QuestNamesItem(questId, itemId)
  questId, itemId = tonumber(questId), tonumber(itemId)
  if not questId or not itemId then
    return false
  end
  local predicted = ItemTree.QuestsPredicted
  if type(predicted) == "table" then
    if type(predicted.Objectives) == "function" then
      local ok, list = pcall(predicted.Objectives, questId, false)
      for _, objective in ipairs(ok and type(list) == "table" and list or {}) do
        if type(objective) == "table" and objective.kind == predicted.ITEM and objective.id == itemId then
          return true
        end
      end
    end
    if type(predicted.Provided) == "function" then
      local ok, list = pcall(predicted.Provided, questId, false)
      for _, entry in ipairs(ok and type(list) == "table" and list or {}) do
        if type(entry) == "table" and entry.id == itemId then
          return true
        end
      end
    end
  end
  local era = ItemTree.eraSources
  if itemRowsLoaded() and type(era) == "table" and type(era.QuestRequires) == "function" then
    local ok, list = pcall(era.QuestRequires, era, questId)
    for _, pair in ipairs(ok and type(list) == "table" and list or {}) do
      if type(pair) == "table" and tonumber(pair[1]) == itemId then
        return true
      end
    end
  end
  local index = CollectorHooks.QuestObjectiveIndex()
  if type(index) == "table" and next(index) ~= nil then
    local name = itemNameAndClass(itemId)
    for _, match in ipairs(name and CollectorHooks.ObjectiveMatches(name, index) or {}) do
      if match.questId == questId then
        return true
      end
    end
  end
  return false
end

--- Brief RF375 (M3): whether a placed line may be held as the quest's hand-over. Pure over the readers.
function CollectorHooks.HandoverPasses(questId, itemId)
  return CollectorHooks.HandoverItem(itemId) or CollectorHooks.QuestNamesItem(questId, itemId)
end

-- The accept or turn in nearest a held line within the window, for an ambiguous line's log entry:
-- questId and the moment ("accept" first where both are as near), or nil.
local function nearestWindow(push, window)
  local best, quest, moment = nil, nil, nil
  for _, part in ipairs({ { CollectorHooks.recentAccepts, "accept" }, { CollectorHooks.recentTurnIns, "turnin" } }) do
    for _, entry in ipairs(type(part[1]) == "table" and part[1] or {}) do
      local gap = type(entry) == "table" and type(entry.at) == "number" and math.abs(entry.at - push.at) or nil
      if gap and gap <= window and (best == nil or gap < best) then
        best, quest, moment = gap, entry.questId, part[2]
      end
    end
  end
  return quest, moment
end

-- Brief RF375 fix 7: one dropped line into the collector's audit log.
local function logDrop(push, questId, when, reason)
  local instance = collector()
  if not instance or type(instance.RecordPushDrop) ~= "function" or not CollectorHooks.Enabled() then
    return false
  end
  local ok, stored = pcall(instance.RecordPushDrop, instance, {
    item = push.item,
    quest = questId,
    when = when,
    reason = reason,
  })
  return ok and stored == true
end

--- Places every held line older than HANDOVER_SECONDS (CollectorHooks.HandoverFor, then the gossip
--- rule), holds it as a hand-over where it passes the screen (brief RF375 M3, HandoverPasses) and
--- writes what it can; a line dropped inside a hand-over window goes to the audit log (fix 7) with its
--- reason. now is the hand-over clock (a spec states it). Answers how many hand-overs were written.
function CollectorHooks.FlushHandovers(now)
  now = tonumber(now) or handoverNow()
  local window = CollectorHooks.HANDOVER_SECONDS
  local kept, written = {}, 0
  for _, push in ipairs(CollectorHooks.heldPushes) do
    if now - push.at < window then
      kept[#kept + 1] = push
    else
      local questId, when =
        CollectorHooks.HandoverFor(push, CollectorHooks.recentAccepts, CollectorHooks.recentTurnIns, window)
      local giver = nil
      if not questId and when == nil and push.giver then
        questId, when, giver = CollectorHooks.ObjectiveQuestOf(push.item), "quest", push.giver
        if not questId then
          logDrop(push, nil, "quest", push.drop or "noquest")
        end
      end
      if when == "ambiguous" then
        local nearQuest, moment = nearestWindow(push, window)
        logDrop(push, nearQuest, moment or "accept", push.drop or "ambiguous")
      elseif questId then
        if push.drop then
          logDrop(push, questId, when, push.drop)
        elseif not CollectorHooks.HandoverPasses(questId, push.item) then
          logDrop(push, questId, when, "screen")
        elseif recordHandover(questId, { item = push.item, count = push.count, when = when, giver = giver }) then
          written = written + 1
        end
      end
    end
  end
  CollectorHooks.heldPushes = kept
  return written
end

-- The flush, on a timer just past the hold, under the boundary (Core/Guard.lua) like every other
-- timer callback here. Without C_Timer the next line or accept flushes instead.
local function bookFlush()
  local timer = rawget(_G, "C_Timer")
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    return false
  end
  return pcall(timer.After, CollectorHooks.HANDOVER_SECONDS + 0.25, function()
    guarded("CollectorHooks.FlushHandovers", CollectorHooks.FlushHandovers)
  end) and true or false
end

--- One pushed line: itemId and count off the line. Held for the flush unless a merchant window is
--- open or the item is a reward a turn in window just listed. Answers true when it was held. Brief
--- RF375 fix 7: such a line is still held, marked with why it can never be a hand-over (drop), so the
--- flush can file it in the audit log where it sat inside a hand-over window; it answers false.
function CollectorHooks.NotePush(itemId, count, now)
  itemId = tonumber(itemId)
  if not itemId or not CollectorHooks.Enabled() then
    return false
  end
  now = tonumber(now) or handoverNow()
  CollectorHooks.FlushHandovers(now)
  local drop = nil
  if windowOpen(CollectorHooks.merchant) then
    drop = "merchant"
  elseif isRecentReward(itemId, now) then
    drop = "reward"
  end
  local gossip = CollectorHooks.gossip
  local held = CollectorHooks.heldPushes
  held[#held + 1] = {
    item = itemId,
    count = tonumber(count) or 1,
    at = now,
    giver = windowFresh(gossip, now) and gossip.npcId or nil,
    drop = drop,
  }
  CollectorHooks.heldPushes = prune(held, now, CollectorHooks.HANDOVER_SECONDS * 4)
  bookFlush()
  return drop == nil
end

--- QUEST_ACCEPTED's part: the accept, by its own quest id, for the lines either side of it.
function CollectorHooks.NoteAcceptForHandover(questId, now)
  questId = tonumber(questId)
  if not questId or not CollectorHooks.Enabled() then
    return false
  end
  now = tonumber(now) or handoverNow()
  local list = CollectorHooks.recentAccepts
  list[#list + 1] = { questId = questId, at = now }
  CollectorHooks.recentAccepts = prune(list, now, CollectorHooks.HANDOVER_SECONDS * 4)
  return true
end

--- QUEST_TURNED_IN's part: the turn in, by its own quest id, with the rewards its window listed.
function CollectorHooks.NoteTurnInForHandover(questId, now)
  questId = tonumber(questId)
  if not questId or not CollectorHooks.Enabled() then
    return false
  end
  now = tonumber(now) or handoverNow()
  local rewards = CollectorHooks.turnInRewards[questId]
  if type(rewards) == "table" then
    rewards.at = now
  end
  local list = CollectorHooks.recentTurnIns
  list[#list + 1] = { questId = questId, at = now, rewards = type(rewards) == "table" and rewards.items or {} }
  CollectorHooks.recentTurnIns = prune(list, now, CollectorHooks.HANDOVER_SECONDS * 4)
  return true
end

--- GOSSIP_SHOW and GOSSIP_CLOSED: the creature a gossip window is with ("npc", a Creature GUID read
--- through canRead), and when the window closed. A GUID the client keeps secret is no creature.
function CollectorHooks.OnGossip(event, now)
  now = tonumber(now) or handoverNow()
  if event == "GOSSIP_CLOSED" then
    if type(CollectorHooks.gossip) == "table" then
      CollectorHooks.gossip.closed = now
    end
    return true
  end
  if not CollectorHooks.Enabled() then
    CollectorHooks.gossip = nil
    return false
  end
  local ref = sanitiseGuid(call("UnitGUID", "npc"))
  local npcId = type(ref) == "table" and (ref.kind == "Creature" or ref.kind == "Vehicle") and positiveWhole(ref.id)
    or nil
  CollectorHooks.gossip = npcId and { npcId = npcId, at = now } or nil
  return npcId ~= nil
end

--- MERCHANT_SHOW and MERCHANT_CLOSED: whether a merchant window is open, for the purchase rule.
function CollectorHooks.OnMerchantWindow(event, now)
  now = tonumber(now) or handoverNow()
  if event == "MERCHANT_CLOSED" then
    if type(CollectorHooks.merchant) == "table" then
      CollectorHooks.merchant.closed = now
    end
  else
    CollectorHooks.merchant = { at = now }
  end
  return true
end

--------------------------------------------------------------------------------
-- Brief IW1 (the owner's "2B" of 2026-10-22): the hand-in's bag check. For each item a quest handed over
-- at the accept or mid quest (the player's own h), its count in the bags and bank at the turn in window
-- and again just after QUEST_TURNED_IN (C_Item.GetItemCount with includeBank,
-- Blizzard_APIDocumentationGenerated/ItemDocumentation.lua:451 on the forever mirror, build 70245; the
-- legacy global where the table is not there), one count per item of that one quest. The marks
-- (Core/Collector.lua k): listed by the window, taken; else none held at the window, gone before the
-- hand-in (used during the quest, or thrown away); held and gone after, taken; still held after, left.
-- A quest whose turn in shows no QUEST_PROGRESS window counts at the reward window (QUEST_COMPLETE)
-- instead; one with no window at all says only "left" where the item is still held after. In memory
-- until a mark is written, each quest's counts kept CollectorHooks.HANDIN_KEEP seconds.
--------------------------------------------------------------------------------

-- How long after QUEST_TURNED_IN the second count is taken, so the hand-in's removal has reached the
-- bags, and how long a window's counts are kept for a turn in that has not come.
CollectorHooks.HANDIN_AFTER_SECONDS = 1
CollectorHooks.HANDIN_KEEP = 600
-- questId -> { at, before = { [itemId] = count | false (unreadable) }, listed = { [itemId] = true } or nil }
CollectorHooks.handins = {}

--- One item's count in the bags and bank, or nil where the client cannot say (no API, an error, a
--- value it keeps secret). The demo's pretend count answers first, as Core/QuestFlags.lua Holds reads.
function CollectorHooks.ItemCount(itemId)
  itemId = tonumber(itemId)
  if not itemId then
    return nil
  end
  local demo = ItemTree.Demo
  if type(demo) == "table" and type(demo.Have) == "function" then
    local ok, pretend = pcall(demo.Have, itemId)
    if ok and tonumber(pretend) then
      return math.max(0, math.floor(tonumber(pretend)))
    end
  end
  local itemApi = rawget(_G, "C_Item")
  local ask = type(itemApi) == "table" and itemApi.GetItemCount or nil
  if type(ask) ~= "function" then
    ask = rawget(_G, "GetItemCount")
  end
  if type(ask) ~= "function" then
    return nil
  end
  local ok, count = pcall(ask, itemId, true)
  if not ok or not canRead(count) then
    return nil
  end
  count = tonumber(count)
  if count == nil or count < 0 then
    return nil
  end
  return math.floor(count)
end

--- The items the player's own records say a quest handed over at the accept or mid quest, by id.
function CollectorHooks.HandedOverItems(questId)
  local instance = ItemTree.collector
  local out, seen = {}, {}
  if type(instance) ~= "table" or type(instance.QuestHandovers) ~= "function" then
    return out
  end
  local ok, list = pcall(instance.QuestHandovers, instance, questId)
  for _, entry in ipairs(ok and type(list) == "table" and list or {}) do
    local itemId = type(entry) == "table" and entry.when ~= "turnin" and tonumber(entry.itemId) or nil
    if itemId and not seen[itemId] then
      seen[itemId] = true
      out[#out + 1] = itemId
    end
  end
  return out
end

--- Pure: one item's mark (Collector.TAKEN, LEFT or GONE) or nil (not decided). listed: the turn in
--- window listed it; before and after: its counts at the window and after the turn in, a number, or
--- nil where none was taken (or unreadable). after nil is the window's own call: only listed and gone
--- are decided there.
function CollectorHooks.HandinMark(listed, before, after)
  local Collector = ItemTree.Collector
  if listed then
    return Collector.TAKEN
  end
  if before == 0 then
    return Collector.GONE
  end
  if after == nil then
    return nil
  end
  if after > 0 then
    return Collector.LEFT
  end
  if before == nil then
    return nil
  end
  return Collector.TAKEN
end

local function writeMarks(questId, marks)
  local instance = collector()
  if not instance or type(instance.MarkQuestHandins) ~= "function" or next(marks) == nil then
    return false
  end
  local ok, stored = pcall(instance.MarkQuestHandins, instance, questId, marks)
  return ok and stored == true
end

local function pruneHandins(now)
  for questId, held in pairs(CollectorHooks.handins) do
    if type(held) ~= "table" or type(held.at) ~= "number" or now - held.at > CollectorHooks.HANDIN_KEEP then
      CollectorHooks.handins[questId] = nil
    end
  end
end

--- QUEST_PROGRESS (requirements: the window's whole required list, { { itemId, count } }, or nil where
--- it was not read whole) and QUEST_COMPLETE (requirements nil, and only where no QUEST_PROGRESS window
--- of this quest counted first): counts each item the quest handed over, writes the marks the window
--- decides (listed: taken; none held: gone before the hand-in) and keeps the counts for the turn in.
--- Answers how many items were counted.
function CollectorHooks.NoteHandinWindow(questId, requirements, now)
  questId = tonumber(questId)
  if not questId or not CollectorHooks.Enabled() then
    return 0
  end
  now = tonumber(now) or handoverNow()
  pruneHandins(now)
  local items = CollectorHooks.HandedOverItems(questId)
  if #items == 0 then
    return 0
  end
  local held = CollectorHooks.handins[questId]
  if held and requirements == nil and held.before then
    -- The reward window after a progress window of the same quest: the first counts stand.
    return 0
  end
  local listed = nil
  if type(requirements) == "table" then
    listed = {}
    for _, required in ipairs(requirements) do
      local itemId = type(required) == "table" and tonumber(required.itemId) or nil
      if itemId then
        listed[itemId] = true
      end
    end
  end
  local before, marks = {}, {}
  for _, itemId in ipairs(items) do
    local count = CollectorHooks.ItemCount(itemId)
    before[itemId] = count or false
    local mark = CollectorHooks.HandinMark(listed and listed[itemId], count, nil)
    if mark then
      marks[itemId] = mark
    end
  end
  CollectorHooks.handins[questId] = { at = now, before = before, listed = listed }
  writeMarks(questId, marks)
  return #items
end

--- Just after QUEST_TURNED_IN: counts each item the quest handed over again and writes the marks the
--- window left open (held and gone: taken; still held: left; with no window, still held: left), then
--- forgets the quest's counts. Answers how many marks were written.
function CollectorHooks.SettleHandin(questId)
  questId = tonumber(questId)
  if not questId or not CollectorHooks.Enabled() then
    return 0
  end
  local held = CollectorHooks.handins[questId]
  CollectorHooks.handins[questId] = nil
  local before = type(held) == "table" and held.before or {}
  local listed = type(held) == "table" and held.listed or nil
  local marks, written = {}, 0
  for _, itemId in ipairs(CollectorHooks.HandedOverItems(questId)) do
    local was = before[itemId]
    local decided = (listed and listed[itemId]) or was == 0
    if not decided then
      local mark = CollectorHooks.HandinMark(false, was or nil, CollectorHooks.ItemCount(itemId))
      if mark then
        marks[itemId] = mark
        written = written + 1
      end
    end
  end
  writeMarks(questId, marks)
  return written
end

--- QUEST_TURNED_IN's part of the bag check: the second count, booked HANDIN_AFTER_SECONDS on (under the
--- boundary, Core/Guard.lua, like every timer callback here), or taken now without C_Timer.
function CollectorHooks.NoteHandinTurnedIn(questId)
  questId = tonumber(questId)
  if not questId or not CollectorHooks.Enabled() then
    return false
  end
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    return pcall(timer.After, CollectorHooks.HANDIN_AFTER_SECONDS, function()
      guarded("CollectorHooks.SettleHandin", CollectorHooks.SettleHandin, questId)
    end) and true or false
  end
  CollectorHooks.SettleHandin(questId)
  return true
end

-- The pushed formats as the client holds them, read once.
local pushedFormats = nil

function CollectorHooks.PushedFormats()
  if pushedFormats then
    return pushedFormats[1], pushedFormats[2]
  end
  local single = rawget(_G, CollectorHooks.PUSHED_GLOBALS[1])
  local multiple = rawget(_G, CollectorHooks.PUSHED_GLOBALS[2])
  pushedFormats = {
    type(single) == "string" and canRead(single) and single or false,
    type(multiple) == "string" and canRead(multiple) and multiple or false,
  }
  return pushedFormats[1], pushedFormats[2]
end

-- Drops the formats and every held line (tests, and a client that swaps its locale mid session).
function CollectorHooks.ResetHandovers()
  pushedFormats = nil
  CollectorHooks.heldPushes = {}
  CollectorHooks.recentAccepts = {}
  CollectorHooks.recentTurnIns = {}
  CollectorHooks.turnInRewards = {}
  CollectorHooks.gossip = nil
  CollectorHooks.merchant = nil
  -- Brief IW1: the bag check's counts.
  CollectorHooks.handins = {}
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- QUEST_PROGRESS is the turn in window, which names a quest's required items exactly.
-- QUEST_ACCEPTED and QUEST_REMOVED are the two moments the set of quests in the log changes, so
-- they are what drops the objective index; QUEST_LOG_UPDATE is deliberately not listened for,
-- because it fires on every step of progress and nothing here stores progress.
local EVENTS = {
  "CHAT_MSG_LOOT",
  "LOOT_OPENED",
  "LOOT_CLOSED",
  "MERCHANT_SHOW",
  "QUEST_COMPLETE",
  "QUEST_DETAIL",
  "QUEST_PROGRESS",
  "QUEST_ACCEPTED",
  "QUEST_REMOVED",
  -- Brief QF1: the XP a turn in gave, and a goal of one quest moving (the ledger rule).
  "QUEST_TURNED_IN",
  "QUEST_WATCH_UPDATE",
  "UNIT_SPELLCAST_SENT",
  "UNIT_SPELLCAST_SUCCEEDED",
  -- Brief RV14: combat starting lets go of a held Pick Pocket cast.
  "PLAYER_REGEN_DISABLED",
  "PLAYER_TARGET_CHANGED",
  "UPDATE_MOUSEOVER_UNIT",
  -- Brief R5a: the two sides of a loading screen, for instance entrances.
  "PLAYER_LEAVING_WORLD",
  "PLAYER_ENTERING_WORLD",
  -- Brief R9: a trainer's and a stable master's window, and the retail shaped engine's word for
  -- either. An engine without one of them refuses that registration alone.
  "TRAINER_SHOW",
  "PET_STABLE_SHOW",
  "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
  -- Brief TW1: a trainer window's rows changing (a filter ticked, a row bought) and the window
  -- closing (TrainerDocumentation.lua, forever branch). Their handlers do nothing unless trainer
  -- lists are recorded (CollectorHooks.TRAINER_LISTS).
  "TRAINER_UPDATE",
  "TRAINER_CLOSED",
  -- Brief QH1: the gossip window (a mid quest hand-over's giver) and the merchant window closing
  -- (a purchase's pushed line is never a hand-over). GossipInfoDocumentation.lua:277 and :233,
  -- MerchantFrameDocumentation.lua:96 (forever branch, build 70450).
  "GOSSIP_SHOW",
  "GOSSIP_CLOSED",
  "MERCHANT_CLOSED",
}

local function dispatch(event, ...)
  if event == "CHAT_MSG_LOOT" then
    -- Brief SV1: the line's text carries no NeverSecret mark (ChatInfoDocumentation.lua:1820).
    local message = ...
    if canRead(message) then
      CollectorHooks.OnChatLoot(message)
    end
  elseif event == "LOOT_OPENED" then
    CollectorHooks.OnLootOpened()
    -- Brief R4: the ledger's Disenchant window, before the pending cast is let go of.
    CollectorHooks.OnLootOpenedLedger()
    CollectorHooks.pendingDisenchant = nil
    -- Brief BL14: the corpse being looted is the target, most often.
    CollectorHooks.NoteSeenBoss("target")
  elseif event == "PLAYER_TARGET_CHANGED" then
    CollectorHooks.NoteSeenBoss("target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    CollectorHooks.NoteSeenBoss("mouseover")
  elseif event == "LOOT_CLOSED" then
    CollectorHooks.ClearDisenchant()
    CollectorHooks.pendingNode = nil
    -- Brief SK1: the window the creature loot cast opened is done with.
    CollectorHooks.pendingCreatureLoot = nil
  elseif event == "MERCHANT_SHOW" or event == "MERCHANT_CLOSED" then
    -- Brief QH1: whether a merchant window is open, for the hand-over rule.
    guarded("CollectorHooks.OnMerchantWindow", CollectorHooks.OnMerchantWindow, event)
    if event == "MERCHANT_SHOW" then
      CollectorHooks.OnMerchantShow()
    end
  elseif event == "GOSSIP_SHOW" or event == "GOSSIP_CLOSED" then
    -- Brief QH1: the creature a gossip window is with, a mid quest hand-over's giver.
    guarded("CollectorHooks.OnGossip", CollectorHooks.OnGossip, event)
  elseif event == "PLAYER_LEAVING_WORLD" then
    CollectorHooks.OnLeavingWorld()
  elseif event == "PLAYER_ENTERING_WORLD" then
    CollectorHooks.OnEnteringWorld()
  elseif event == "QUEST_COMPLETE" or event == "QUEST_DETAIL" then
    -- Brief Q8: and who is offering it, or who is taking it back. Brief Q9: the offer window
    -- files its rewards by GetQuestID alone, the turn in window as before.
    if event == "QUEST_DETAIL" then
      CollectorHooks.OnQuestOffer()
      CollectorHooks.OnQuestDetail()
      -- Brief QF1: the item that started the offer (QUEST_DETAIL's questStartItemID).
      guarded("CollectorHooks.OnQuestDetailFacts", CollectorHooks.OnQuestDetailFacts, ...)
    else
      CollectorHooks.OnQuest()
      CollectorHooks.OnQuestComplete()
      -- Brief QF1: the money and XP on the turn in window.
      guarded("CollectorHooks.OnQuestCompleteFacts", CollectorHooks.OnQuestCompleteFacts)
      -- Brief IW1 (the owner's "2B"): the bag check's first count where no progress window came first.
      guarded("CollectorHooks.NoteHandinWindow", CollectorHooks.NoteHandinWindow, CollectorHooks.CurrentQuestId())
    end
  elseif event == "QUEST_PROGRESS" then
    CollectorHooks.OnQuestProgress()
  elseif event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" then
    CollectorHooks.InvalidateQuestObjectives()
    if event == "QUEST_ACCEPTED" then
      CollectorHooks.OnQuestAccepted(...)
      -- Brief QF1: the quest's level, goals, start item and the player's side.
      guarded(
        "CollectorHooks.OnQuestAcceptedFacts",
        CollectorHooks.OnQuestAcceptedFacts,
        CollectorHooks.AcceptedQuestId(...)
      )
      -- Brief QH1: the accept, for the hand-over rule's pushed lines either side of it.
      guarded(
        "CollectorHooks.NoteAcceptForHandover",
        CollectorHooks.NoteAcceptForHandover,
        CollectorHooks.AcceptedQuestId(...)
      )
    else
      local questId = ...
      if canRead(questId) and tonumber(questId) then
        CollectorHooks.goalProgress[tonumber(questId)] = nil
      end
    end
  elseif event == "QUEST_TURNED_IN" then
    guarded("CollectorHooks.OnQuestTurnedIn", CollectorHooks.OnQuestTurnedIn, ...)
    -- Brief QH1: the turn in, for the hand-over rule (a quest id the client keeps secret is none).
    local questId = ...
    if canRead(questId) then
      guarded("CollectorHooks.NoteTurnInForHandover", CollectorHooks.NoteTurnInForHandover, questId)
      -- Brief IW1 (the owner's "2B"): the bag check's count after the hand-in.
      guarded("CollectorHooks.NoteHandinTurnedIn", CollectorHooks.NoteHandinTurnedIn, questId)
    end
  elseif event == "QUEST_WATCH_UPDATE" then
    guarded("CollectorHooks.OnQuestWatchUpdate", CollectorHooks.OnQuestWatchUpdate, ...)
  elseif event == "UNIT_SPELLCAST_SENT" then
    -- Brief SV1: the target is ConditionalSecret and the event SecretWhenUnitSpellCastRestricted
    -- (UnitDocumentation.lua:4804-4811); a cast with any value unreadable is not looked at.
    local unit, target, castGuid, spellId = ...
    -- Brief SK1: a Skinning, Pick Pocket or creature gathering cast needs no target, so a target
    -- the client keeps secret does not cost the hold (a creature's name in combat).
    if canRead(unit) and canRead(castGuid) and canRead(spellId) then
      guarded("CollectorHooks.OnCreatureCastSent", CollectorHooks.OnCreatureCastSent, unit, castGuid, spellId)
    end
    if not (canRead(unit) and canRead(target) and canRead(castGuid) and canRead(spellId)) then
      return
    end
    if unit == "player" and spellId == CollectorHooks.DISENCHANT_SPELL_ID then
      -- Brief C21: a new cast forgets the last one's target; the cast's target name is the item's.
      CollectorHooks.disenchantTarget = nil
      CollectorHooks.RememberDisenchantTarget(nil, target)
    end
    -- Brief R9: a gathering cast's target is the node's name.
    guarded("CollectorHooks.OnSpellcastSent", CollectorHooks.OnSpellcastSent, ...)
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, castGuid, spellId = ...
    if not (canRead(unit) and canRead(castGuid) and canRead(spellId)) then
      return
    end
    if unit == "player" and spellId == CollectorHooks.DISENCHANT_SPELL_ID then
      CollectorHooks.RememberDisenchantTarget()
      CollectorHooks.pendingDisenchant = true
    end
    guarded("CollectorHooks.OnSpellcastSucceeded", CollectorHooks.OnSpellcastSucceeded, ...)
    -- Brief SK1: the creature loot cast held above has landed.
    guarded("CollectorHooks.OnCreatureCastSucceeded", CollectorHooks.OnCreatureCastSucceeded, unit, castGuid)
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- Brief RV14: a Pick Pocket hold never lasts into combat.
    guarded("CollectorHooks.OnCombatStart", CollectorHooks.OnCombatStart)
  else
    CollectorHooks.DispatchR9(event, ...)
  end
end

-- True when the handler ran to the end. Every call inside it is guarded on its own, so this
-- pcall is the last resort rather than the plan: nothing the collector might have recorded is
-- worth an error message in front of the player, and an event handler is where one would show.
function CollectorHooks.OnEvent(event, ...)
  return pcall(dispatch, event, ...) and true or false
end

-- The two spellcast events are only wanted for the player, so they are taken through
-- RegisterUnitEvent where the frame has it: the client then never hands us another unit's cast
-- in a group, raid or city. RegisterEvent is the fallback, and dispatch's own unit check stays
-- for that case. Answers true when one registration took, and which one ran is kept on
-- CollectorHooks.registeredAs for a spec to read back.
local PLAYER_ONLY_EVENTS = {
  UNIT_SPELLCAST_SENT = true,
  UNIT_SPELLCAST_SUCCEEDED = true,
}

CollectorHooks.registeredAs = {}

function CollectorHooks.RegisterOn(frame, event)
  if PLAYER_ONLY_EVENTS[event] and type(frame.RegisterUnitEvent) == "function" then
    if pcall(frame.RegisterUnitEvent, frame, event, "player") then
      CollectorHooks.registeredAs[event] = "unit"
      return true
    end
  end
  if type(frame.RegisterEvent) == "function" and pcall(frame.RegisterEvent, frame, event) then
    CollectorHooks.registeredAs[event] = "event"
    return true
  end
  return false
end

-- Idempotent. Returns the event frame, or nil outside the client. Each registration is taken on
-- its own, so an engine that has dropped one of these events costs us that event and not the
-- rest, and the frame is only kept once something is listening on it.
function CollectorHooks.Install()
  if CollectorHooks.frame then
    return CollectorHooks.frame
  end
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return nil
  end
  local ok, frame = pcall(createFrame, "Frame")
  if not ok or type(frame) ~= "table" or type(frame.RegisterEvent) ~= "function" then
    return nil
  end
  local registered = 0
  for _, event in ipairs(EVENTS) do
    if CollectorHooks.RegisterOn(frame, event) then
      registered = registered + 1
    end
  end
  if registered == 0 or type(frame.SetScript) ~= "function" then
    return nil
  end
  local hooked = pcall(frame.SetScript, frame, "OnEvent", function(_, event, ...)
    CollectorHooks.OnEvent(event, ...)
  end)
  if not hooked then
    return nil
  end
  CollectorHooks.frame = frame
  -- Brief R4: the combat log on a frame of its own, where the client allows it.
  CollectorHooks.InstallCombatLog()
  -- Brief C21: the bag slot a targeting spell is handed, for the Disenchant target.
  CollectorHooks.InstallUseHook()
  return frame
end

local createFrameGlobal = rawget(_G, "CreateFrame")
if type(createFrameGlobal) == "function" then
  local ok, loader = pcall(createFrameGlobal, "Frame")
  if ok and type(loader) == "table" then
    pcall(loader.RegisterEvent, loader, "PLAYER_LOGIN")
    pcall(loader.SetScript, loader, "OnEvent", function(self)
      CollectorHooks.Install()
      pcall(self.UnregisterEvent, self, "PLAYER_LOGIN")
    end)
  end
end

return CollectorHooks
