-- Brief S8 (the owner, 2026-10-09): "Like we have the code (c:1234), I want to search for trainers,
-- e.g. trainer:hunter or trainer:lw or trainer:leatherworker and get a list of possible trainers
-- with the ones in my zone coming up first. t: should also work." Core/Data.lua Data.ParseSearch
-- reads the prefix and hands the rest of the text over as a word; this file reads the word (a class
-- or a profession, by its name or a short alias), knows the trainers and puts them in order, and
-- UI/Frame.lua Frame.SearchAll draws them as rows that open each trainer's creature page.
--
-- Where a trainer comes from: our own data and the player's own records, nothing asked of the
-- client and no item queried.
--   Classic Era  every name the trainer table lists (EraSources tr): the profession by the rank
--                spells it teaches (Core/ViewModel.lua TRAINS_RANK_SPELLS, Apprentice to Artisan),
--                then by its title's words, then by its recipes' own line; and every name whose
--                title says it trains (st: "Hunter Trainer", "Demon Trainer", "Pet Trainer"), which
--                is what is left of the class trainers the table cut from tr. Each carries its
--                title (st), side (cf), the zone its pins stand in most (mp) and its page through
--                the one builder (EraSources.PageKey); a name with no creature id has no page and
--                is listed all the same.
--   Forever      the Creatures data's titles ("Hunter Trainer", "Junior Mining Trainer"), the
--                shipped player module's trainers (PlayerSources k, what each trains in w, where
--                players met it in p) and the player's own trainer visits (the places store's
--                "t": the name, what the window said it trains, the map). Its page is the plain
--                npc:<id>. Brief F169 (TR4): one none of those places stands where the client's own
--                vendor tables put it (ForeverVendors), the trainers who sell their trade's tools.
--                Brief TS1: a titled trainer players met only as a quest giver or ender stands
--                where the player module's spots of that role put it, before those tables.
-- One row per name: a Classic Era name keeps its row and takes what Forever adds to it.
--
-- The order (TrainerSearch.Order): the player's zone first, then the rest of the continent, then
-- everything else; inside each, the player's side, then neutral (and a side nothing states), then
-- the other side, which is listed with its side mark; then by name. Brief F155: while "Hide other
-- faction data" is on (the default; PlayerPlace's hideOther) the other side's trainers are left out
-- and counted, and UI/Frame.lua says "4 Horde trainers hidden" under the rows.
--
-- Pure functions first. Below the divider, guarded: where the player is (C_Map) and which side they
-- are on (UnitFactionGroup), asked once per search, the maps' parents kept for the session.
local _, ItemTree = ...

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local TrainerSearch = {}
ItemTree.TrainerSearch = TrainerSearch

local EMPTY = {}

-- The kinds of trainer, in the order "t:" alone lists them: the classes, the professions, then
-- riding, weapon masters and pet trainers, which the data names too. Each has
--   id       the word the rest of the addon keys it by
--   label    its name in the "t:" list, and (with " trainers") its rows' heading
--   heading  the heading where "<label> trainers" would not read
--   aliases  what a player may type after "t:" for it, the short one first (the list shows it)
--   words    the words in an NPC's title (or what it trains) that name it, matched as whole
--            words on the game's own spelling ("Armorsmith", "Weapon Crafter")
--   lines    the class lines a trainer window may name, where they name one class alone
--   line     a profession's skill line, which keys its rank spells and its recipes
--   plain    the words say it trains by themselves ("Weapon Master")
TrainerSearch.KINDS = {
  { id = "warrior", label = L["Warrior"], aliases = { "warrior" }, words = { "warrior" }, lines = { "arms", "fury" } },
  {
    id = "paladin",
    label = L["Paladin"],
    aliases = { "paladin" },
    words = { "paladin" },
    lines = { "retribution" },
  },
  {
    id = "hunter",
    label = L["Hunter"],
    aliases = { "hunter" },
    words = { "hunter" },
    lines = { "beast mastery", "marksmanship", "survival" },
  },
  {
    id = "rogue",
    label = L["Rogue"],
    aliases = { "rogue" },
    words = { "rogue" },
    lines = { "assassination", "combat", "subtlety", "lockpicking", "poisons" },
  },
  {
    id = "priest",
    label = L["Priest"],
    aliases = { "priest" },
    words = { "priest" },
    lines = { "discipline", "shadow", "shadow magic" },
  },
  {
    id = "shaman",
    label = L["Shaman"],
    aliases = { "shaman" },
    words = { "shaman" },
    lines = { "elemental", "elemental combat", "enhancement" },
  },
  {
    id = "mage",
    label = L["Mage"],
    aliases = { "mage" },
    -- "Portal Trainer": the mage's portals.
    words = { "mage", "portal" },
    lines = { "arcane", "fire", "frost" },
  },
  {
    id = "warlock",
    label = L["Warlock"],
    aliases = { "warlock" },
    -- "Demon Trainer": the warlock's demons.
    words = { "warlock", "demon" },
    lines = { "affliction", "demonology", "destruction" },
  },
  {
    id = "druid",
    label = L["Druid"],
    aliases = { "druid" },
    words = { "druid" },
    lines = { "balance", "feral combat" },
  },
  {
    id = "alchemy",
    label = L["Alchemy"],
    line = 171,
    aliases = { "alch", "alchemist", "alchemy" },
    words = { "alchemy", "alchemist" },
  },
  {
    id = "blacksmithing",
    label = L["Blacksmithing"],
    line = 164,
    aliases = { "bs", "blacksmith", "blacksmithing" },
    words = { "blacksmithing", "blacksmith", "armorsmith", "weaponsmith", "armor crafter", "weapon crafter" },
  },
  {
    id = "enchanting",
    label = L["Enchanting"],
    line = 333,
    aliases = { "ench", "enchanter", "enchanting" },
    words = { "enchanting", "enchanter" },
  },
  {
    id = "engineering",
    label = L["Engineering"],
    line = 202,
    aliases = { "eng", "engineer", "engineering" },
    words = { "engineering", "engineer" },
  },
  {
    id = "herbalism",
    label = L["Herbalism"],
    line = 182,
    aliases = { "herb", "herbalist", "herbalism" },
    words = { "herbalism", "herbalist" },
  },
  {
    id = "leatherworking",
    label = L["Leatherworking"],
    line = 165,
    aliases = { "lw", "leatherworker", "leatherworking" },
    words = { "leatherworking", "leatherworker" },
  },
  { id = "mining", label = L["Mining"], line = 186, aliases = { "mining", "miner" }, words = { "mining", "miner" } },
  {
    id = "skinning",
    label = L["Skinning"],
    line = 393,
    aliases = { "skin", "skinner", "skinning" },
    words = { "skinning", "skinner" },
  },
  {
    id = "tailoring",
    label = L["Tailoring"],
    line = 197,
    aliases = { "tailor", "tailoring" },
    words = { "tailoring", "tailor" },
  },
  {
    id = "cooking",
    label = L["Cooking"],
    line = 185,
    aliases = { "cook", "cooking" },
    words = { "cooking", "cook", "chef" },
  },
  {
    id = "firstaid",
    label = L["First Aid"],
    line = 129,
    aliases = { "fa", "first aid", "firstaid" },
    words = { "first aid", "physician", "surgeon", "medic", "doctor" },
  },
  {
    id = "fishing",
    label = L["Fishing"],
    line = 356,
    aliases = { "fish", "fishing" },
    words = { "fishing", "fisherman", "fisher", "fishmaster" },
  },
  -- "Mechanostrider Pilot": the gnomes' riding trainer.
  { id = "riding", label = L["Riding"], aliases = { "riding" }, words = { "riding", "pilot" } },
  {
    id = "weapon",
    label = L["Weapon masters"],
    heading = L["Weapon masters"],
    aliases = { "weapon", "weapon master" },
    words = { "weapon master", "weapons master", "weapon trainer", "weapons trainer" },
    plain = true,
  },
  {
    id = "pet",
    label = L["Pet trainers"],
    heading = L["Pet trainers"],
    aliases = { "pet" },
    words = { "pet" },
  },
}

-- The kinds by id.
TrainerSearch.BY_ID = {}
for _, kind in ipairs(TrainerSearch.KINDS) do
  TrainerSearch.BY_ID[kind.id] = kind
end

-- The first words of a title that make a profession word after them a trainer's on a name nothing
-- else says trains ("Journeyman Leatherworker", "Expert Alchemist", "Junior Mining Trainer"), read
-- only where no trainer table speaks for the name (a Forever NPC): the Classic Era table's own
-- trainers are its tr list, so an Era "Apprentice Weaponsmith" who teaches nothing is a vendor.
TrainerSearch.RANK_WORDS = { "apprentice", "journeyman", "expert", "artisan", "master", "grand master", "junior" }

-- Brief F169 (owner ruling 2026-10-14, "Maginor is a master mage trainer"): the class trainers
-- whose title never says "Trainer". Every Classic Era title naming a class that the words above
-- missed is one of five, and the content database the Era table is built from flags three of them
-- trainers of that very class: Maginor Dumas <Master Mage>, Fahrad <Grand Master Rogue> and Zayus
-- <High Priest>. The other two, Theocritus <Mage of Tower Azora> and Kerlonian Evershade <Druid of
-- the Claw>, train nothing and stay out. So the forms are a whole title of "Master" or "Grand
-- Master" and a class word ("Master Mage"; a "Master Swordsmith" names no class) and the one whole
-- title "High Priest". Keyed by the title as wordsOf words it, to the class kind's id (a class
-- kind's id is its class word).
TrainerSearch.CLASS_TITLE_PREFIXES = { "master", "grand master" }
TrainerSearch.CLASS_TITLES = { [" high priest "] = "priest" }

-- Sides as the Classic Era table numbers them (cf): 1 Alliance, 2 Horde, 3 both (neutral).
TrainerSearch.ALLIANCE = 1
TrainerSearch.HORDE = 2
TrainerSearch.NEUTRAL = 3

-- Where a trainer stands against the player: in their zone, on their continent, anywhere else.
TrainerSearch.SAME_ZONE = 1
TrainerSearch.SAME_CONTINENT = 2
TrainerSearch.ELSEWHERE = 3

-- Lower case, every run of anything but letters one space, with a space at each end, so a word is
-- found whole by a plain find of " word ". Pure.
local function wordsOf(text)
  local out = text:lower():gsub("[^%a]+", " ")
  out = out:match("^%s*(.-)%s*$")
  return " " .. out .. " "
end
TrainerSearch.WordsOf = wordsOf

for _, kind in ipairs(TrainerSearch.KINDS) do
  if kind.lines then
    for _, prefix in ipairs(TrainerSearch.CLASS_TITLE_PREFIXES) do
      TrainerSearch.CLASS_TITLES[" " .. prefix .. " " .. kind.id .. " "] = kind.id
    end
  end
end

-- Brief F169: the class kind a class trainer's title names without saying "Trainer" ("Master
-- Mage" the mage, "High Priest" the priest), or nil for every other title. Only a title with
-- "master" or "priest" in it is made words of. Pure.
function TrainerSearch.ClassTitleKind(title)
  if type(title) ~= "string" or title == "" then
    return nil
  end
  local lower = title:lower()
  if not (lower:find("master", 1, true) or lower:find("priest", 1, true)) then
    return nil
  end
  return TrainerSearch.CLASS_TITLES[wordsOf(title)]
end

-- The typed word as aliases are compared: trimmed, lower case, "-" and "_" read as spaces, runs of
-- spaces one, and a trailing "trainer" or "trainers" dropped ("t:hunter trainer"). Pure.
function TrainerSearch.Normalise(word)
  if type(word) ~= "string" then
    return ""
  end
  local out = word:lower():gsub("[%-_]", " "):gsub("%s+", " ")
  out = out:match("^%s*(.-)%s*$")
  out = out:gsub("%s*trainers?$", "")
  return out
end

-- Which kind a typed word asks for. Answers one of
--   { kind = id }               an alias, in full ("lw", "leatherworker"), or a plural of one
--                               ("hunters"), or the start of the aliases of one kind alone
--                               ("leath", "hun"), which is what the box holds half typed
--   { list = { id, ... } }      "" (t: alone) lists every kind; the start of more than one kind's
--                               aliases ("m": mage, mining) lists those
--   { list = {}, unknown = w }  a word no kind is called, w as it was normalised
-- Pure.
function TrainerSearch.Resolve(word)
  local wanted = TrainerSearch.Normalise(word)
  if wanted == "" then
    local all = {}
    for _, kind in ipairs(TrainerSearch.KINDS) do
      all[#all + 1] = kind.id
    end
    return { list = all }
  end
  local plural = wanted:match("^(.-)s$")
  for _, kind in ipairs(TrainerSearch.KINDS) do
    for _, alias in ipairs(kind.aliases) do
      if alias == wanted or alias == plural then
        return { kind = kind.id }
      end
    end
  end
  local starts = {}
  for _, kind in ipairs(TrainerSearch.KINDS) do
    local names = { kind.label:lower() }
    for _, alias in ipairs(kind.aliases) do
      names[#names + 1] = alias
    end
    for _, name in ipairs(names) do
      if name:sub(1, #wanted) == wanted then
        starts[#starts + 1] = kind.id
        break
      end
    end
  end
  if #starts == 1 then
    return { kind = starts[1] }
  end
  if #starts == 0 then
    return { list = starts, unknown = wanted }
  end
  return { list = starts }
end

-- The text "t:" takes to name a kind in full: "t:lw", "t:hunter". Pure.
function TrainerSearch.Fill(id)
  local kind = TrainerSearch.BY_ID[id]
  if not kind then
    return nil
  end
  return "t:" .. kind.aliases[1]
end

-- The heading a kind's rows sit under: "Hunter trainers", "Leatherworking trainers", "Weapon
-- masters". Pure.
function TrainerSearch.Heading(id)
  local kind = TrainerSearch.BY_ID[id]
  if not kind then
    return nil
  end
  if kind.heading then
    return kind.heading
  end
  return string.format(L["%s trainers"], kind.label)
end

-- Whether a title starts with one of RANK_WORDS. text is wordsOf's answer.
local function ranked(text)
  for _, word in ipairs(TrainerSearch.RANK_WORDS) do
    if text:sub(1, #word + 2) == " " .. word .. " " then
      return true
    end
  end
  return false
end

-- The kinds an NPC's title names, as a set { [id] = true }. trains is true where something else
-- already says the NPC trains (the Classic Era trainer table lists it, the player module or the
-- player's own records name it a trainer); otherwise only a title that says so itself counts:
-- "Trainer" or "Instructor" in it, a "Weapon Master", a class trainer's title of brief F169 ("Master
-- Mage", TrainerSearch.ClassTitleKind), and (rank, for a name no trainer table speaks for) a
-- profession word after one of RANK_WORDS, last in the title. A title that names no
-- kind, a vendor's ("Leatherworking Supplies") or a stable master's, answers an empty set. Pure.
function TrainerSearch.TitleKinds(title, trains, rank)
  local out = {}
  if type(title) ~= "string" or title == "" then
    return out
  end
  -- Brief F169: a class trainer's title that does not say it trains ("Master Mage") names its class
  -- and nothing else, whoever asks.
  local classId = TrainerSearch.ClassTitleKind(title)
  if classId then
    out[classId] = true
    return out
  end
  if trains ~= true and rank ~= true then
    -- A title alone has to say it trains, and most a search walks are a vendor's or a quest
    -- giver's: those are let go before any words are made of them.
    local lower = title:lower()
    local says = lower:find("trainer", 1, true) or lower:find("instructor", 1, true)
    if not says and not lower:find("weapon", 1, true) then
      return out
    end
  end
  local text = wordsOf(title)
  local says = trains == true or text:find(" trainers? ") ~= nil or text:find(" instructor ", 1, true) ~= nil
  local byRank = rank == true and ranked(text)
  for _, kind in ipairs(TrainerSearch.KINDS) do
    -- Most titles a search walks are a vendor's or a quest giver's, which say nothing of training:
    -- only a kind whose words say it themselves is looked for in those.
    if says or byRank or kind.plain then
      for _, word in ipairs(kind.words) do
        local whole = " " .. word .. " "
        if text:find(whole, 1, true) then
          local last = text:sub(-#whole) == whole
          if says or kind.plain or (byRank and kind.line and last) then
            out[kind.id] = true
          end
          break
        end
      end
    end
  end
  return out
end

-- The kinds what a trainer trains names (the trainer window's own line, "Leatherworking",
-- "Beast Mastery", as the player module or the player's records keep it), as a set. A line two
-- classes share ("Holy", "Protection", "Restoration") names neither. Pure.
function TrainerSearch.TrainsKinds(trains)
  local out = {}
  if type(trains) ~= "string" or trains == "" then
    return out
  end
  local text = wordsOf(trains)
  for _, kind in ipairs(TrainerSearch.KINDS) do
    for _, line in ipairs(kind.lines or EMPTY) do
      if text == " " .. line .. " " then
        out[kind.id] = true
      end
    end
  end
  for id in pairs(TrainerSearch.TitleKinds(trains, true)) do
    out[id] = true
  end
  return out
end

local function union(into, from)
  for id in pairs(from) do
    into[id] = true
  end
  return into
end

local function any(set)
  return next(set) ~= nil
end

--------------------------------------------------------------------------------
-- The index: every trainer, built once out of what is loaded
--------------------------------------------------------------------------------

-- The profession kind of each rank spell, out of the rank spells by skill line ({ [line] = { spell,
-- ... } }, Core/ViewModel.lua TRAINS_RANK_SPELLS). Pure.
function TrainerSearch.RankKinds(rankSpells)
  local byLine = {}
  for _, kind in ipairs(TrainerSearch.KINDS) do
    if kind.line then
      byLine[kind.line] = kind.id
    end
  end
  local out = {}
  for line, spells in pairs(type(rankSpells) == "table" and rankSpells or EMPTY) do
    local id = byLine[line]
    for _, spell in ipairs(id and type(spells) == "table" and spells or EMPTY) do
      out[spell] = id
    end
  end
  return out
end

-- Brief NR1b: each rank spell's kind and step (1 Apprentice to 4 Artisan, its place in its line's
-- list), out of the rank spells by skill line: { [spell] = { id, step } }. Pure.
function TrainerSearch.RankSteps(rankSpells)
  local byLine = {}
  for _, kind in ipairs(TrainerSearch.KINDS) do
    if kind.line then
      byLine[kind.line] = kind.id
    end
  end
  local out = {}
  for line, spells in pairs(type(rankSpells) == "table" and rankSpells or EMPTY) do
    local id = byLine[line]
    for step, spell in ipairs(id and type(spells) == "table" and spells or EMPTY) do
      out[spell] = { id, step }
    end
  end
  return out
end

-- Brief NR1b: the steps a top rank covers ({ [1] = true, ..., [top] = true }, at most 4), the
-- Creatures data's tk (1 Apprentice to 5 Master): a trainer of a rank teaches the ranks below it.
-- nil for no top rank. Pure.
function TrainerSearch.StepsUpTo(top)
  top = tonumber(top)
  if not top or top < 1 then
    return nil
  end
  local out = {}
  for step = 1, math.min(math.floor(top), 4) do
    out[step] = true
  end
  return out
end

-- The profession kind of a skill line, or nil. Pure.
function TrainerSearch.LineKind(line)
  line = tonumber(line)
  for _, kind in ipairs(TrainerSearch.KINDS) do
    if kind.line and kind.line == line then
      return kind.id
    end
  end
  return nil
end

-- The kinds of one Classic Era trainer table name: its rank spells, its title's words, and where
-- neither says (a specialist, a trainer with no title) its spells' recipe lines through
-- recipeLine(spell), which may be nil. Pure over what it is handed.
local function eraTrainerKinds(EraSources, source, nameIndex, rankKinds, recipeLine)
  local kinds = {}
  local spells = EraSources.Teaches(source, nameIndex)
  for _, spell in ipairs(spells) do
    local id = rankKinds[spell]
    if id then
      kinds[id] = true
    end
  end
  union(kinds, TrainerSearch.TitleKinds(EraSources.Title(source, nameIndex), true))
  if not any(kinds) and type(recipeLine) == "function" then
    for _, spell in ipairs(spells) do
      local id = TrainerSearch.LineKind(recipeLine(spell))
      if id then
        kinds[id] = true
      end
    end
  end
  return kinds
end

-- Brief NR1b: the ranks one Classic Era trainer table name teaches, per profession kind it trains:
-- { [id] = { [step] = true } }, out of its rank spells. The table lists everything the name
-- teaches, so a profession it trains with no rank spell of it holds an empty set (known: no rank).
-- Pure over what it is handed.
local function eraRanks(EraSources, source, nameIndex, kinds, rankSteps)
  local out = {}
  for id in pairs(kinds) do
    if TrainerSearch.BY_ID[id] and TrainerSearch.BY_ID[id].line then
      out[id] = {}
    end
  end
  for _, spell in ipairs(EraSources.Teaches(source, nameIndex)) do
    local rank = rankSteps[spell]
    if rank and out[rank[1]] then
      out[rank[1]][rank[2]] = true
    end
  end
  return next(out) ~= nil and out or nil
end

-- One Classic Era name as an index entry, or nil for a name the strings do not hold.
local function eraEntry(EraSources, source, nameIndex, kinds)
  local strings = type(source.s) == "table" and source.s or EMPTY
  local name = strings[nameIndex]
  if type(name) ~= "string" or name == "" then
    return nil
  end
  local top = EraSources.PinAreas(source, nameIndex)[1]
  -- The original game's template NPCs ("World Rogue Trainer") stand nowhere and were never met.
  if top == nil and name:find("^World ") then
    return nil
  end
  local entry = {
    name = name,
    lower = name:lower(),
    key = EraSources.PageKey(source, nameIndex),
    title = EraSources.Title(source, nameIndex),
    side = EraSources.Faction(source, nameIndex),
    kinds = kinds,
  }
  if type(top) == "table" then
    entry.areaId = top.areaId
    entry.zone = top.name
    entry.map = EraSources.MapOf(source, top.areaId)
  end
  return entry
end

-- An index entry is an array, the way Core/Data.lua keeps a kind's list (a table of small hash
-- tables costs several times what the same fields cost in order): the name, the creature page it
-- opens (nil for a Classic Era name with no creature id), its title, its side (1, 2 or 3, nil where
-- nothing states one), the Classic Era area name its pins stand in most, the uiMap it stands on
-- (its zone's map), and whether only Forever's data holds it. TrainerSearch.ENTRY names the slots.
-- Brief NR1b: and the ranks it teaches per profession kind ({ [id] = { [step] = true } }), nil where
-- nothing states them.
local ENTRY_NAME, ENTRY_KEY, ENTRY_TITLE, ENTRY_SIDE, ENTRY_ZONE, ENTRY_MAP, ENTRY_FOREVER = 1, 2, 3, 4, 5, 6, 7
local ENTRY_RANKS = 8
TrainerSearch.ENTRY = { name = 1, key = 2, title = 3, side = 4, zone = 5, map = 6, forever = 7, ranks = 8 }

-- Every trainer out of the sources handed in, as { entries = { entry, ... }, byKind = { [id] =
-- { entry, ... } }, counts = { [id] = n } }, each entry as above, each kind's list in no order
-- (TrainerSearch.Order puts one in order for a search).
--
-- sources = {
--   EraSources  the module (Core/EraSources.lua: Teaches, TeachCount, Title, Faction, PinAreas,
--               MapOf, PageKey), era its shipped table
--   rankSpells  { [line] = { spell, ... } }, recipeLine(spell) a recipe's skill line or nil
--   creatures   the Creatures data ({ c = { [id] = { n, ti, tp, tz, tx } }, s }; brief TR1: tp a
--               profession it trains, tz its zone's name, tx never a trainer)
--   players     { { npcId, name, trains, spots = { { map } } }, ... } (PlayerSources.NpcsWithRole)
--   visits      the places store's trainers ({ [npcId] = { n, k, [map] = cells } }), bestMap(id)
--               the map one was met on most
--   pageKey(id) a Forever npc's page key
--   vendorPlace(id)  brief F169 (TR4): the uiMap and the zone words the client's own vendor tables
--               place a Forever npc on (Core/ForeverVendors.lua), or nil
--   sidePlaces  brief RB2: { [uiMap] = 1 or 2 }, the places that prove a side (Core/PlayerSources.lua
--               SIDE_PLACES), which side a Forever trainer standing in one (TrainerSearch.PlaceSide);
--               brief TS1: 3 for a place that serves both sides (Zephras Isle)
--   npcSpot(id) brief TS1: the uiMap the shipped player module's spots place an npc on, whatever
--               role players met it in (Core/PlayerSources.lua Spots, TrainerSearch.BusiestMap), or nil
-- }
-- Any of them may be missing. Pure over what it is handed.
function TrainerSearch.Build(sources)
  sources = type(sources) == "table" and sources or EMPTY
  local entries, byLower = {}, {}
  local function add(entry)
    local held = byLower[entry.lower]
    if not held then
      byLower[entry.lower] = entry
      entries[#entries + 1] = entry
      return entry
    end
    union(held.kinds, entry.kinds)
    if held.map == nil and entry.map ~= nil then
      held.map = entry.map
    end
    if held.zone == nil and entry.zone ~= nil then
      held.zone = entry.zone
    end
    if held.title == nil then
      held.title = entry.title
    end
    -- Brief RB2: a side only one source states (a place that proves it) is the entry's.
    if held.side == nil and entry.side ~= nil then
      held.side = entry.side
    end
    -- Brief NR1b: the ranks each source states, together; a kind only one states keeps its set.
    for id, steps in pairs(type(entry.ranks) == "table" and entry.ranks or EMPTY) do
      held.ranks = held.ranks or {}
      local into = held.ranks[id]
      if not into then
        into = {}
        held.ranks[id] = into
      end
      for step in pairs(steps) do
        into[step] = true
      end
    end
    return held
  end

  local EraSources, source = sources.EraSources, sources.era
  if type(EraSources) == "table" and type(source) == "table" then
    local rankKinds = TrainerSearch.RankKinds(sources.rankSpells)
    local rankSteps = TrainerSearch.RankSteps(sources.rankSpells)
    local taught = type(source.tr) == "table" and source.tr or EMPTY
    for nameIndex in pairs(taught) do
      if type(nameIndex) == "number" and EraSources.TeachCount(source, nameIndex) > 0 then
        local kinds = eraTrainerKinds(EraSources, source, nameIndex, rankKinds, sources.recipeLine)
        if any(kinds) then
          local entry = eraEntry(EraSources, source, nameIndex, kinds)
          if entry then
            entry.ranks = eraRanks(EraSources, source, nameIndex, kinds, rankSteps)
            add(entry)
          end
        end
      end
    end
    -- The names whose title says they train, the class trainers above all.
    for nameIndex in pairs(type(source.st) == "table" and source.st or EMPTY) do
      if type(nameIndex) == "number" and not (taught[nameIndex] and EraSources.TeachCount(source, nameIndex) > 0) then
        local kinds = TrainerSearch.TitleKinds(EraSources.Title(source, nameIndex), false)
        if any(kinds) then
          local entry = eraEntry(EraSources, source, nameIndex, kinds)
          if entry then
            add(entry)
          end
        end
      end
    end
  end

  -- Forever: what each npc id is called and titled, what says it trains, and where it was met.
  local seen, order = {}, {}
  local function npc(id)
    local held = seen[id]
    if not held then
      held = {}
      seen[id] = held
      order[#order + 1] = id
    end
    return held
  end
  local creatures = type(sources.creatures) == "table" and sources.creatures or nil
  local strings = creatures and type(creatures.s) == "table" and creatures.s or EMPTY
  -- Brief TR1: the pipeline's trainer fields ride on the same rows: tp the profession it trains
  -- (from a title, a corroborated noun or an owner claim), tz the zone's name where no map id is
  -- known, tx an owner negative, which no title, record or visit below can make a trainer.
  local never = {}
  for id, row in pairs(creatures and type(creatures.c) == "table" and creatures.c or EMPTY) do
    if type(id) == "number" and type(row) == "table" then
      if row.tx == 1 then
        never[id] = true
      else
        local title = strings[row.ti]
        local name = strings[row.n]
        local line = tonumber(row.tp)
        if (type(title) == "string" or line) and type(name) == "string" and name ~= "" then
          local held = npc(id)
          held.name, held.title = name, type(title) == "string" and title or nil
          if line then
            held.trains, held.kindLine = true, line
            -- Brief NR1b: tk, the top rank it teaches.
            held.top = tonumber(row.tk)
          end
          local zone = strings[row.tz]
          if type(zone) == "string" and zone ~= "" then
            held.zone = zone
          end
          -- Brief TR1c: an owner confirmed claim's approximate position (tq = { uiMap, cell, ... })
          -- places the trainer's map where nothing of ours does (below, ours first).
          local claimMap = type(row.tq) == "table" and tonumber(row.tq[1]) or nil
          if claimMap and claimMap > 0 then
            held.claimMap = claimMap
          end
        end
      end
    end
  end
  for _, trainer in ipairs(type(sources.players) == "table" and sources.players or EMPTY) do
    local id = type(trainer) == "table" and tonumber(trainer.npcId) or nil
    if id and not never[id] then
      local held = npc(id)
      held.trains = true
      held.name = held.name or trainer.name
      held.line = held.line or trainer.trains
      local spot = type(trainer.spots) == "table" and trainer.spots[1] or nil
      held.map = held.map or (type(spot) == "table" and tonumber(spot.map) or nil)
    end
  end
  for id, visit in pairs(type(sources.visits) == "table" and sources.visits or EMPTY) do
    if type(id) == "number" and type(visit) == "table" and not never[id] then
      local held = npc(id)
      held.trains = true
      if type(visit.n) == "string" and visit.n ~= "" then
        held.name = held.name or visit.n
      end
      if type(visit.k) == "string" and visit.k ~= "" then
        held.line = held.line or visit.k
      end
      if held.map == nil and type(sources.bestMap) == "function" then
        held.map = tonumber(sources.bestMap(id))
      end
    end
  end
  table.sort(order)
  for _, id in ipairs(order) do
    local held = seen[id]
    local kinds = TrainerSearch.TitleKinds(held.title, held.trains == true, true)
    union(kinds, TrainerSearch.TrainsKinds(held.line))
    local lineKind = held.kindLine and TrainerSearch.LineKind(held.kindLine) or nil
    if lineKind then
      kinds[lineKind] = true
    end
    if any(kinds) and type(held.name) == "string" and held.name ~= "" then
      local ranks = nil
      local steps = lineKind and TrainerSearch.StepsUpTo(held.top) or nil
      if steps then
        ranks = { [lineKind] = steps }
      end
      local key = nil
      if type(sources.pageKey) == "function" then
        key = sources.pageKey(id)
      end
      -- Brief F169 (TR4, QA 2026-10-13): a trainer nothing of ours places that the client's own vendor
      -- tables do (Jason Stonepike, Mittiny Cogwrench and Hannah Peltskinner, Northshire's Junior
      -- trainers, who sell their trade's tools) stands where those tables put it, as its page's Map
      -- tab does, so the zone column and "Show nearest" know it. The client's statement, so it goes
      -- before an owner claim's approximate cell.
      local map, zone = held.map, held.zone
      -- Brief TS1 (QA item 405, the TL1 audit): a creature whose own title says it trains (a class
      -- or profession trainer's, TitleKinds with nothing else speaking for it) that players met only
      -- as a quest giver or ender, so no trainer record placed it (Aramis Hammerhand, Shari Stilwell
      -- and Hilda the Breaker in Tirisfal Glades, Eldrun Stormbreaker in Ironforge), stands where the
      -- shipped module's spots of any role put it. Those spots are ours, the same ones the npc's Map
      -- tab and "Show nearest" read (Core/Nearest.lua ownPoints), so this goes after a trainer
      -- record (above) and before the client's vendor tables and an owner claim's cell (below), and
      -- the side then comes from the place as any of ours does (Tirisfal Glades proves the Horde).
      if
        map == nil
        and type(sources.npcSpot) == "function"
        and any(TrainerSearch.TitleKinds(held.title, false, true))
      then
        local ok, spotMap = pcall(sources.npcSpot, id)
        if ok then
          map = tonumber(spotMap)
        end
      end
      if map == nil and type(sources.vendorPlace) == "function" then
        local ok, placeMap, placeZone = pcall(sources.vendorPlace, id)
        if ok then
          map = tonumber(placeMap)
          if zone == nil and type(placeZone) == "string" and placeZone ~= "" then
            zone = placeZone
          end
        end
      end
      map = map or held.claimMap
      add({
        name = held.name,
        lower = held.name:lower(),
        key = key or ("npc:" .. id),
        title = held.title,
        -- Brief RB2 (owner QA 2026-10-17 item 205, Hannah Peltskinner "has no side, seems like some
        -- info about her is missing"): a Forever trainer's side is the place's where the place
        -- proves one (sources.sidePlaces, Core/PlayerSources.lua SIDE_PLACES: the faction cities and
        -- the classic starting zones, the owner's rule of 2026-10-03), Elwynn Forest for the three
        -- Northshire trainers. Nothing else of ours states a Forever trainer's side. Brief TS1: and
        -- Zephras Isle, both sides (3), by the owner's ruling "A" of 2026-10-23.
        side = TrainerSearch.PlaceSide(map, sources.sidePlaces),
        map = map,
        zone = zone,
        kinds = kinds,
        forever = true,
        ranks = ranks,
      })
    end
  end

  local byKind, counts, packed = {}, {}, {}
  for _, kind in ipairs(TrainerSearch.KINDS) do
    byKind[kind.id] = {}
    counts[kind.id] = 0
  end
  for index, entry in ipairs(entries) do
    local row =
      { entry.name, entry.key, entry.title, entry.side, entry.zone, entry.map, entry.forever == true, entry.ranks }
    packed[index] = row
    for id in pairs(entry.kinds) do
      local list = byKind[id]
      if list then
        list[#list + 1] = row
        counts[id] = counts[id] + 1
      end
    end
  end
  return { entries = packed, byKind = byKind, counts = counts }
end

--- Brief RB2 (owner QA 2026-10-17 item 205): the side a place proves for an NPC standing in it, 1
--- Alliance or 2 Horde, out of sidePlaces ({ [uiMap] = side }, Core/PlayerSources.lua SIDE_PLACES),
--- or nil for a map that proves none, no map or no table. Brief TS1 (the owner's ruling "A",
--- 2026-10-23): 3, both sides, for a place that serves both (Zephras Isle), so its trainers read
--- "Neutral (both sides)" and "Hide other faction data" keeps them for either side. Pure.
function TrainerSearch.PlaceSide(map, sidePlaces)
  local side = type(sidePlaces) == "table" and map ~= nil and sidePlaces[map] or nil
  if side == TrainerSearch.ALLIANCE or side == TrainerSearch.HORDE or side == TrainerSearch.NEUTRAL then
    return side
  end
  return nil
end

--- Brief TS1: the map an NPC's shipped spots (PlayerSources.Spots' answer: { { map, cells = { { cell,
--- count } } } }) stand on most, by the sightings each map's cells add up to, the first such map on
--- a tie; nil for no spot. Pure.
function TrainerSearch.BusiestMap(spots)
  local best, most = nil, 0
  for _, spot in ipairs(type(spots) == "table" and spots or EMPTY) do
    local map = type(spot) == "table" and tonumber(spot.map) or nil
    if map then
      local seen = 0
      for _, cell in ipairs(type(spot.cells) == "table" and spot.cells or EMPTY) do
        seen = seen + (type(cell) == "table" and tonumber(cell.count) or 0)
      end
      if best == nil or seen > most then
        best, most = map, seen
      end
    end
  end
  return best
end

--------------------------------------------------------------------------------
-- The order
--------------------------------------------------------------------------------

-- Where a trainer on one map stands against the player's place: SAME_ZONE, SAME_CONTINENT or
-- ELSEWHERE. place = { map, maps = { [map] = true }, continent, continentOf(map) }: map the zone the
-- player is in, maps every map the player's own sits in below its continent (a cave's map and its
-- zone's), continent the player's continent. A trainer on no map is ELSEWHERE. Pure over place.
function TrainerSearch.Nearness(map, place)
  if type(place) ~= "table" or map == nil then
    return TrainerSearch.ELSEWHERE
  end
  if map == place.map or (type(place.maps) == "table" and place.maps[map]) then
    return TrainerSearch.SAME_ZONE
  end
  if place.continent ~= nil and type(place.continentOf) == "function" then
    local ok, continent = pcall(place.continentOf, map)
    if ok and continent ~= nil and continent == place.continent then
      return TrainerSearch.SAME_CONTINENT
    end
  end
  return TrainerSearch.ELSEWHERE
end

-- How a side sorts for a player of side playerSide: 1 the player's own, 2 neutral or unstated, 3
-- the other. With no player side every entry is 2. Pure.
function TrainerSearch.SideRank(side, playerSide)
  if playerSide ~= TrainerSearch.ALLIANCE and playerSide ~= TrainerSearch.HORDE then
    return 2
  end
  if side == playerSide then
    return 1
  end
  if side == TrainerSearch.ALLIANCE or side == TrainerSearch.HORDE then
    return 3
  end
  return 2
end

-- A copy of entries (index entries) in the order the rows are drawn: zone, then continent, then
-- the rest; inside each the player's side, neutral, the other side; then by name, then by key.
-- Each answered as { entry, near, sideRank, lower }. Pure over place.
function TrainerSearch.Order(entries, place)
  local out = {}
  local playerSide = type(place) == "table" and place.side or nil
  for _, entry in ipairs(type(entries) == "table" and entries or EMPTY) do
    out[#out + 1] = {
      entry = entry,
      near = TrainerSearch.Nearness(entry[ENTRY_MAP], place),
      sideRank = TrainerSearch.SideRank(entry[ENTRY_SIDE], playerSide),
      lower = tostring(entry[ENTRY_NAME]):lower(),
    }
  end
  table.sort(out, function(a, b)
    if a.near ~= b.near then
      return a.near < b.near
    end
    if a.sideRank ~= b.sideRank then
      return a.sideRank < b.sideRank
    end
    if a.lower ~= b.lower then
      return a.lower < b.lower
    end
    return tostring(a.entry[ENTRY_KEY]) < tostring(b.entry[ENTRY_KEY])
  end)
  return out
end

-- Brief F155 (owner QA 2026-10-14 item 155): whether one index entry is left out for the player at
-- place: "Hide other faction data" is on (place.hideOther, TrainerSearch.PlayerPlace reads it), the
-- player's side is known (place.side) and the entry's side is the other one alone (1 or 2). A neutral
-- trainer (3), one whose side nothing states (a Forever trainer the Classic Era table does not
-- name) and every trainer of a place with no hideOther stay. Pure.
function TrainerSearch.Hidden(entry, place)
  if type(entry) ~= "table" or type(place) ~= "table" or not place.hideOther then
    return false
  end
  local mine, side = place.side, entry[ENTRY_SIDE]
  if mine ~= TrainerSearch.ALLIANCE and mine ~= TrainerSearch.HORDE then
    return false
  end
  return (side == TrainerSearch.ALLIANCE or side == TrainerSearch.HORDE) and side ~= mine
end

-- One kind's trainers for the search box, as results UI/Frame.lua draws:
--
--   { kind = "trainer", what = id, key, noPage, name, title, zone, side, near, forever }
--
-- at most limit (20 by default), in TrainerSearch.Order's order, and how many there are in all.
-- zone is the Classic Era area name (brief TR1: or the zone name the Creatures data states for a
-- Forever trainer no map places, "Riverglades"), else place.mapName(map) where the place can name a map. An
-- unknown id answers none. Pure over index and place.
-- Brief F155: the entries TrainerSearch.Hidden leaves out are in neither the rows nor the count; a
-- third answer says how many went (0 for none).
function TrainerSearch.Results(index, id, limit, place)
  limit = math.floor(tonumber(limit) or 20)
  local out = {}
  local list = type(index) == "table" and type(index.byKind) == "table" and index.byKind[id] or nil
  if type(list) ~= "table" then
    return out, 0, 0
  end
  local hidden = 0
  if type(place) == "table" and place.hideOther then
    local kept = {}
    for _, entry in ipairs(list) do
      if TrainerSearch.Hidden(entry, place) then
        hidden = hidden + 1
      else
        kept[#kept + 1] = entry
      end
    end
    list = kept
  end
  if limit <= 0 then
    return out, #list, hidden
  end
  local mapName = type(place) == "table" and type(place.mapName) == "function" and place.mapName or nil
  for _, ordered in ipairs(TrainerSearch.Order(list, place)) do
    if #out >= limit then
      break
    end
    local entry = ordered.entry
    local zone, map = entry[ENTRY_ZONE], entry[ENTRY_MAP]
    if zone == nil and map ~= nil and mapName then
      local ok, name = pcall(mapName, map)
      if ok and type(name) == "string" and name ~= "" then
        zone = name
      end
    end
    local key = entry[ENTRY_KEY]
    out[#out + 1] = {
      kind = "trainer",
      what = id,
      key = key,
      noPage = key == nil or nil,
      name = entry[ENTRY_NAME],
      title = entry[ENTRY_TITLE],
      zone = zone,
      side = entry[ENTRY_SIDE],
      near = ordered.near,
      forever = entry[ENTRY_FOREVER] or nil,
    }
  end
  return out, #list, hidden
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- The index, built on the first trainer search and kept until what it was built from changes (the
-- shipped tables, or how many trainers the player's own records hold).
TrainerSearch.index = nil
TrainerSearch.builds = 0

local function call(object, method, ...)
  if type(object) ~= "table" or type(object[method]) ~= "function" then
    return nil
  end
  local ok, answer = pcall(object[method], ...)
  if ok then
    return answer
  end
  return nil
end

-- The places store's trainers (ItemTreeDB.places.t), or nil.
local function visitsStore()
  local db = ItemTree.db
  local places = type(db) == "table" and type(db.places) == "table" and db.places or nil
  local Places = ItemTree.Places
  local kind = type(Places) == "table" and Places.TRAINER or "t"
  local store = places and places[kind] or nil
  return type(store) == "table" and store or nil, places, kind
end

local function countOf(store)
  local count = 0
  for _ in pairs(type(store) == "table" and store or EMPTY) do
    count = count + 1
  end
  return count
end

-- What the index is built from, out of what is loaded now. Loads the Classic Era table (the
-- ItemTree_Data folder) the way the creature page does, on the first trainer search.
function TrainerSearch.Sources()
  local sources = {}
  local era = ItemTree.eraSources
  local EraSources = ItemTree.EraSources
  if type(era) == "table" and type(era.Table) == "function" and type(EraSources) == "table" then
    local ok, source = pcall(era.Table, era)
    if ok and type(source) == "table" then
      sources.EraSources, sources.era = EraSources, source
    end
  end
  local ViewModel = ItemTree.ViewModel
  sources.rankSpells = type(ViewModel) == "table" and ViewModel.TRAINS_RANK_SPELLS or nil
  local Data = ItemTree.Data
  if type(Data) == "table" and type(Data.GetRecipe) == "function" then
    sources.recipeLine = function(spell)
      local ok, recipe = pcall(Data.GetRecipe, Data, spell)
      return ok and type(recipe) == "table" and tonumber(recipe.sl) or nil
    end
  end
  local Creatures = ItemTree.Creatures
  sources.creatures = call(Creatures, "Table")
  local PlayerSources = ItemTree.PlayerSources
  sources.playerTable = call(PlayerSources, "Table")
  -- Brief RB2: the places that prove a side, for a Forever trainer's (TrainerSearch.PlaceSide).
  if type(PlayerSources) == "table" and type(PlayerSources.SIDE_PLACES) == "table" then
    sources.sidePlaces = PlayerSources.SIDE_PLACES
  end
  if sources.playerTable then
    sources.players = call(PlayerSources, "NpcsWithRole", "trainer")
    -- Brief TS1: where the module's spots of any role place an npc, for a titled trainer no trainer
    -- record places (TrainerSearch.Build).
    if type(PlayerSources.Spots) == "function" then
      local playerTable = sources.playerTable
      sources.npcSpot = function(id)
        local ok, spots = pcall(PlayerSources.Spots, playerTable, id)
        return ok and TrainerSearch.BusiestMap(spots) or nil
      end
    end
  end
  local store, places, kind = visitsStore()
  sources.visits = store
  local Places = ItemTree.Places
  if store and type(Places) == "table" and type(Places.Best) == "function" then
    sources.bestMap = function(id)
      local ok, best = pcall(Places.Best, places, kind, id)
      return ok and type(best) == "table" and best.map or nil
    end
  end
  if type(EraSources) == "table" and type(EraSources.CreaturePageKey) == "function" then
    sources.pageKey = function(id)
      local ok, key = pcall(EraSources.CreaturePageKey, id, true)
      return ok and type(key) == "string" and key or nil
    end
  end
  -- Brief F169 (TR4): the client's own vendor tables (ItemTree_Data's ForeverVendors, built here like
  -- the Classic Era table above), read the way a vendor page's Map tab reads them
  -- (ForeverVendors.Facts): the vendor's area, its zone words and the zone's map.
  local ForeverVendors = ItemTree.ForeverVendors
  local vendors = call(ForeverVendors, "Table")
  if vendors and type(ForeverVendors.VendorAt) == "function" and type(ForeverVendors.Place) == "function" then
    sources.vendorPlace = function(id)
      local vendor = ForeverVendors.VendorAt(vendors, id)
      if not vendor then
        return nil
      end
      local zone, map = ForeverVendors.Place(vendor.a)
      return map, zone
    end
  end
  return sources
end

-- What the index was built from, cheaply: the shipped tables themselves (asked, never built
-- here past the first time) and how many trainers the player's own records hold.
local function stampNow()
  local era = ItemTree.eraSources
  local source = nil
  if type(era) == "table" and type(era.Table) == "function" then
    local ok, answer = pcall(era.Table, era)
    source = ok and answer or nil
  end
  return {
    era = source,
    creatures = call(ItemTree.Creatures, "Table"),
    players = call(ItemTree.PlayerSources, "Table"),
    -- Brief F169 (TR4): the vendor tables the positions above came from, which "Show nearest" then
    -- reads already built (Core/Nearest.lua foreverPoints).
    vendors = call(ItemTree.ForeverVendors, "Table"),
    visits = countOf((visitsStore())),
  }
end

-- The index for what is loaded now, built once and kept while the shipped tables and the count of
-- the player's own trainer records stay the same.
function TrainerSearch.Index()
  local stamp = stampNow()
  local held = TrainerSearch.index
  local kept = TrainerSearch.stamp
  if
    held
    and kept
    and kept.era == stamp.era
    and kept.creatures == stamp.creatures
    and kept.players == stamp.players
    and kept.vendors == stamp.vendors
    and kept.visits == stamp.visits
  then
    return held
  end
  local ok, built = pcall(TrainerSearch.Build, TrainerSearch.Sources())
  if not ok or type(built) ~= "table" then
    built = TrainerSearch.Build({})
  end
  TrainerSearch.index, TrainerSearch.stamp = built, stamp
  TrainerSearch.builds = TrainerSearch.builds + 1
  return built
end

function TrainerSearch.Reset()
  TrainerSearch.index, TrainerSearch.stamp = nil, nil
  TrainerSearch.mapInfos = {}
end

-- The client's facts about one map, kept for the session: { mapType, parent, name }, or false.
TrainerSearch.mapInfos = {}

local function mapInfo(mapID)
  if type(mapID) ~= "number" then
    return nil
  end
  local held = TrainerSearch.mapInfos[mapID]
  if held ~= nil then
    return held or nil
  end
  local info = false
  local api = rawget(_G, "C_Map")
  if type(api) == "table" and type(api.GetMapInfo) == "function" then
    local ok, answer = pcall(api.GetMapInfo, mapID)
    if ok and type(answer) == "table" then
      info = { mapType = answer.mapType, parent = answer.parentMapID, name = answer.name }
    end
  end
  TrainerSearch.mapInfos[mapID] = info
  return info or nil
end

local function continentType()
  local enum = rawget(_G, "Enum")
  local types = type(enum) == "table" and enum.UIMapType or nil
  return type(types) == "table" and types.Continent or 2
end

-- The continent map a map sits on, walking the client's map parents, or nil. Guarded and kept.
function TrainerSearch.ContinentOf(mapID)
  local wanted = continentType()
  local at, steps = mapID, 0
  while type(at) == "number" and steps < 8 do
    local info = mapInfo(at)
    if not info then
      return nil
    end
    if info.mapType == wanted then
      return at
    end
    at, steps = info.parent, steps + 1
  end
  return nil
end

-- The client's name for a map, or nil. Guarded and kept.
function TrainerSearch.MapName(mapID)
  local info = mapInfo(mapID)
  local name = info and info.name or nil
  return type(name) == "string" and name ~= "" and name or nil
end

-- Brief F155: whether "Hide other faction data" is on (Core/Graph.lua Graph.HidesOtherFaction, on by
-- default). Guarded.
local function hidesOtherFaction()
  local graph = ItemTree.Graph
  if type(graph) ~= "table" or type(graph.HidesOtherFaction) ~= "function" then
    return true
  end
  local ok, on = pcall(graph.HidesOtherFaction)
  return not ok or on ~= false
end

-- The player's side as the Classic Era table numbers sides, or nil. Guarded.
local function playerSide()
  local faction = rawget(_G, "UnitFactionGroup")
  if type(faction) ~= "function" then
    return nil
  end
  local ok, word = pcall(faction, "player")
  if not ok then
    return nil
  end
  -- Brief BQ14 follow up: the pretend side (Core/Demo.lua) while it is set.
  local demo = ItemTree.Demo
  if type(demo) == "table" and type(demo.FactionWord) == "function" then
    local read, pretend = pcall(demo.FactionWord)
    if read and pretend then
      word = pretend
    end
  end
  if word == "Alliance" then
    return TrainerSearch.ALLIANCE
  elseif word == "Horde" then
    return TrainerSearch.HORDE
  end
  return nil
end

-- Where the player is, for TrainerSearch.Order: { map, maps, continent, side, continentOf, mapName }.
-- map is C_Map.GetBestMapForUnit("player"), maps it and every parent below the continent (so a cave
-- counts as its zone), continent the continent above it. Answers a place with no map (only the
-- side) where the client will not say. Brief DM1: the pretend position's map (`/itemtree demo at`,
-- Core/Demo.lua Demo.At) while it is set. Guarded.
function TrainerSearch.PlayerPlace()
  local place = {
    side = playerSide(),
    -- Brief F155: "Hide other faction data", on unless the player turned it off.
    hideOther = hidesOtherFaction(),
    continentOf = TrainerSearch.ContinentOf,
    mapName = TrainerSearch.MapName,
    maps = {},
  }
  local mapID = nil
  local demo = ItemTree.Demo
  if type(demo) == "table" and type(demo.At) == "function" then
    local read, at = pcall(demo.At)
    if read and type(at) == "table" and type(at.map) == "number" then
      mapID = at.map
    end
  end
  if not mapID then
    local api = rawget(_G, "C_Map")
    if type(api) ~= "table" or type(api.GetBestMapForUnit) ~= "function" then
      return place
    end
    local ok, best = pcall(api.GetBestMapForUnit, "player")
    if not ok or type(best) ~= "number" then
      return place
    end
    mapID = best
  end
  place.map = mapID
  local wanted = continentType()
  local at, steps = mapID, 0
  while type(at) == "number" and steps < 8 do
    local info = mapInfo(at)
    if not info then
      place.maps[at] = true
      break
    end
    if info.mapType == wanted then
      place.continent = at
      break
    end
    place.maps[at] = true
    at, steps = info.parent, steps + 1
  end
  return place
end

-- Brief BQ24 (owner QA 2026-10-10 item 25, "Add a nearest button in the divider for searching a
-- trainer. Same as other areas"): the edges Core/Nearest.lua Nearest.FindAmong measures for one
-- kind's trainers, every one with a page ({ target = its page key, faction = its side, name }), in
-- the index's order. The ones with no page stand nowhere our data places. Pure over the index.
function TrainerSearch.NearestEdges(index, id)
  local out = {}
  local list = type(index) == "table" and type(index.byKind) == "table" and index.byKind[id] or nil
  for _, entry in ipairs(type(list) == "table" and list or EMPTY) do
    local key = entry[ENTRY_KEY]
    if type(key) == "string" and key:sub(1, 4) == "npc:" then
      local edge = { target = key, faction = entry[ENTRY_SIDE], name = entry[ENTRY_NAME] }
      -- Brief NR1b: the ranks it teaches of this kind, where something states them.
      local ranks = entry[ENTRY_RANKS]
      if type(ranks) == "table" and type(ranks[id]) == "table" then
        edge.steps = ranks[id]
      end
      out[#out + 1] = edge
    end
  end
  return out
end

-- Brief NR1b: the player's skill in a profession line, { rank, max }, the demo professions' while
-- they are on (UI/Frame.lua Frame.PlayerSkills answers them), or nil for a line not held. Guarded.
function TrainerSearch.PlayerSkill(line)
  local ui = ItemTree.UI
  local frame = type(ui) == "table" and ui.Frame or nil
  if type(line) ~= "number" or type(frame) ~= "table" or type(frame.PlayerSkills) ~= "function" then
    return nil
  end
  local ok, skills = pcall(frame.PlayerSkills)
  local skill = ok and type(skills) == "table" and skills[line] or nil
  return type(skill) == "table" and skill or nil
end

-- Brief BQ24: the press on the trainer search divider's "Show nearest": the nearest trainer of one
-- kind (id, TrainerSearch.KINDS' id, the "trainer" field of its rows) that the player's side can use,
-- in Nearest.Find's shape ({ text, key, waypoint, kind = "trainer" }) with what = id, or nil where
-- id names no kind or Nearest is not loaded. faction "Alliance" or "Horde".
-- Brief NR1b (QA item 134): the one rank and side aware ranking (Nearest.FindTrainer) the
-- Professions panel's "Show nearest" calls too, over this same set: for a profession, a trainer who
-- teaches the player's next rank (skill = { rank, max }, else the player's own, else Apprentice)
-- first, the nearest of any rank with a muted note where none of those has a place. Guarded.
function TrainerSearch.FindNearest(id, faction, skill)
  local Nearest = ItemTree.Nearest
  local kind = type(TrainerSearch.BY_ID) == "table" and TrainerSearch.BY_ID[id] or nil
  if kind == nil then
    return nil
  end
  if type(Nearest) ~= "table" or type(Nearest.FindAmong) ~= "function" then
    return nil
  end
  local edges = TrainerSearch.NearestEdges(TrainerSearch.Index(), id)
  local ok, found
  if kind.line and type(Nearest.FindTrainer) == "function" and type(Nearest.NextStep) == "function" then
    if type(skill) ~= "table" then
      skill = TrainerSearch.PlayerSkill(kind.line)
    end
    local step
    if type(skill) == "table" then
      step = Nearest.NextStep(skill.rank, skill.max)
    else
      step = Nearest.NextStep(nil, nil)
    end
    ok, found = pcall(Nearest.FindTrainer, edges, { faction = faction, step = step })
  else
    ok, found = pcall(Nearest.FindAmong, edges, "trainer", faction)
  end
  if not ok or type(found) ~= "table" then
    return nil
  end
  found.what = id
  return found
end

-- The search box's answer for a trainer query's word: TrainerSearch.Resolve's answer, and for one
-- kind its results and how many there are in all (TrainerSearch.Results over the index), place the
-- player's (TrainerSearch.PlayerPlace where none is handed in). Brief F155: a fourth answer, how
-- many of the other side "Hide other faction data" left out, and a fifth, that side (1 or 2), for
-- the line UI/Frame.lua says under the rows. Guarded.
function TrainerSearch.Search(word, limit, place)
  local resolved = TrainerSearch.Resolve(word)
  if not resolved.kind then
    return {}, 0, resolved, 0, nil
  end
  if type(place) ~= "table" then
    local ok, answer = pcall(TrainerSearch.PlayerPlace)
    place = ok and answer or nil
  end
  local results, total, hidden = TrainerSearch.Results(TrainerSearch.Index(), resolved.kind, limit, place)
  local other = nil
  if (tonumber(hidden) or 0) > 0 then
    other = place.side == TrainerSearch.ALLIANCE and TrainerSearch.HORDE or TrainerSearch.ALLIANCE
  end
  return results, total, resolved, hidden or 0, other
end
