-- The player's professions, read off the client for Frame.PlayerSkills (UI/Frame.lua).
--
-- Brief PR12b: this lived in UI/Frame.lua until the PR12 port took that file past Lua 5.1's limit
-- of 200 locals in one function (the file's own chunk is a function), so it is a file of its own
-- now, loaded by ItemTree.toc right before UI/Frame.lua. Frame.PlayerSkills keeps the order and
-- the cache: GetProfessions and GetProfessionInfo first, the skill sheet only where they found
-- nothing, C_TradeSkillUI after, and an empty answer is never cached. Frame.InvalidateSkills
-- drops the cache and calls PlayerSkills.resetSkillLines here.
--
-- Everything above the "Client side" divider is pure and runs under busted with no WoW API.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local PlayerSkills = {}
ItemTree.UI.PlayerSkills = PlayerSkills

local EMPTY = {}

-- Skill name to skill line id, built once from the generated Skills module. The client's skill
-- sheet answers with a name rather than an id, so this is the only way back to the id Core keys
-- its categories by. The data carries a second, parent linked row for every profession, so a row
-- with a parent never wins the name.
local skillLines = nil

local function skillLineForName(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  if not skillLines then
    local built = {}
    local Data = ItemTree.Data
    local ok, skills = pcall(function()
      return Data and type(Data.Get) == "function" and Data:Get("Skills") or nil
    end)
    if ok and type(skills) == "table" then
      for id, skill in pairs(skills) do
        if type(skill) == "table" and type(skill.n) == "string" and skill.p == nil then
          local current = built[skill.n]
          if current == nil or id < current then
            built[skill.n] = id
          end
        end
      end
    end
    -- An empty map is never kept: the Skills module may not be loaded yet, and the next call
    -- should try again rather than answer nil for every name until the next skill event.
    if next(built) == nil then
      return nil
    end
    skillLines = built
  end
  return skillLines[name]
end

PlayerSkills.skillLineForName = skillLineForName

-- Drops the name map, so the next lookup builds it again from the Skills module.
function PlayerSkills.resetSkillLines()
  skillLines = nil
  return true
end

-- Brief PR42: the developer's pretend professions (/itemtree demo professions, UI/Slash.lua). The
-- owner cannot level every profession to test the Professions tab, so while this is set the seams
-- answer it instead of the client: Frame.PlayerSkills (the skill table), Keep.PlayerProfessions
-- (the skill line set) and the Professions tab's Craft.KnowsRecipe (which recipes are known). The
-- set REPLACES the player's real professions rather than adding to them. It lives in memory only:
-- never in ItemTreeDB, the collector, the share text or the report, and a /reload ends it.
--   demo = { entries = { { line, name, rank } }, skills = { [line] = { rank, max } },
--            set = { [line] = true } }
PlayerSkills.demo = nil

-- The band ceiling a pretend rank sits under, which is its max: 75, 150, 225 or 300. Pure.
function PlayerSkills.DemoCeiling(rank)
  rank = tonumber(rank) or 0
  for _, ceiling in ipairs({ 75, 150, 225 }) do
    if rank <= ceiling then
      return ceiling
    end
  end
  return 300
end

-- Sets the pretend professions from { { line, name, rank } } (a later entry for a line replaces an
-- earlier one), or turns them off with nil or an empty list. Answers whether the demo is on.
-- Brief BQ13: none (true) keeps an empty list on, so the player pretends to have no profession at
-- all (/itemtree demo professions none, Core/Demo.lua).
function PlayerSkills.SetDemo(entries, none)
  local demo = { entries = {}, skills = {}, set = {} }
  local at = {}
  for _, entry in ipairs(type(entries) == "table" and entries or EMPTY) do
    local line, rank = tonumber(entry.line), tonumber(entry.rank)
    if line and rank then
      local kept = { line = line, name = entry.name, rank = rank }
      if at[line] then
        demo.entries[at[line]] = kept
      else
        demo.entries[#demo.entries + 1] = kept
        at[line] = #demo.entries
      end
      demo.skills[line] = { rank = rank, max = PlayerSkills.DemoCeiling(rank) }
      demo.set[line] = true
    end
  end
  if #demo.entries == 0 and none ~= true then
    PlayerSkills.demo = nil
    return false
  end
  PlayerSkills.demo = demo
  return true
end

-- Whether the pretend professions are on.
function PlayerSkills.DemoOn()
  return type(PlayerSkills.demo) == "table"
end

-- The pretend skill table in Frame.PlayerSkills' shape, a fresh copy each call (no
-- specialisations), or nil while the demo is off.
function PlayerSkills.DemoSkills()
  local demo = PlayerSkills.demo
  if type(demo) ~= "table" then
    return nil
  end
  local out = {}
  for line, skill in pairs(demo.skills) do
    out[line] = { rank = skill.rank, max = skill.max }
  end
  return out
end

-- The pretend skill line set Keep.PlayerProfessions answers, or nil while the demo is off. The
-- same table while the set is unchanged, so Keep's signature cache holds.
function PlayerSkills.DemoSet()
  local demo = PlayerSkills.demo
  return type(demo) == "table" and demo.set or nil
end

-- The pretend entries in the order they were given, { { line, name, rank } }, a copy; {} while off.
function PlayerSkills.DemoEntries()
  local out = {}
  local demo = PlayerSkills.demo
  for index, entry in ipairs(type(demo) == "table" and demo.entries or EMPTY) do
    out[index] = { line = entry.line, name = entry.name, rank = entry.rank }
  end
  return out
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- Whether the player knows a spell. IsSpellKnown is the Classic Era call and IsPlayerSpell the
-- newer one; both are pcall'd because a client that has neither must not take the window down.
local function spellKnown(spellId)
  for _, name in ipairs({ "IsSpellKnown", "IsPlayerSpell" }) do
    local fn = rawget(_G, name)
    if type(fn) == "function" then
      local ok, known = pcall(fn, spellId)
      if ok and known then
        return true
      end
    end
  end
  return false
end

-- The specialisation names the player holds in one profession, or nil for none. Core lists the
-- spell ids in teaching order and names each one, so the client is only ever asked whether a
-- spell is known; a build that adds an id Core has no name for falls back to the spell's own
-- name, which is what UI/Client.lua puts in front of ItemTree.SpellName.
local function knownSpecialisations(skillLine)
  local Skills = ItemTree.Skills
  if not (Skills and type(Skills.SpellIds) == "function") then
    return nil
  end
  local ok, ids = pcall(Skills.SpellIds, skillLine)
  if not (ok and type(ids) == "table" and #ids > 0) then
    return nil
  end
  local entries = (Skills.SPECIALISATIONS or EMPTY)[skillLine] or EMPTY
  local known = {}
  for index, spellId in ipairs(ids) do
    if spellKnown(spellId) then
      local entry = entries[index]
      local name = entry and entry.name or nil
      if type(name) ~= "string" and type(ItemTree.SpellName) == "function" then
        local named, value = pcall(ItemTree.SpellName, spellId)
        name = named and type(value) == "string" and value or nil
      end
      known[#known + 1] = name or tostring(spellId)
    end
  end
  if #known == 0 then
    return nil
  end
  return known
end

-- The skill sheet calls, in the two spellings the target clients use. Classic Era 1.15.9 has
-- them as globals; the newer engine moved the same pair onto C_SpellBook.
local function skillSheetApi()
  local count, info = rawget(_G, "GetNumSkillLines"), rawget(_G, "GetSkillLineInfo")
  if type(count) == "function" and type(info) == "function" then
    return count, info
  end
  local book = rawget(_G, "C_SpellBook")
  if
    type(book) == "table"
    and type(book.GetNumSkillLines) == "function"
    and type(book.GetSkillLineInfo) == "function"
  then
    return book.GetNumSkillLines, book.GetSkillLineInfo
  end
  return nil, nil
end

-- Every profession on the skill sheet. GetSkillLineInfo returns the name, whether the row is a
-- header, whether it is expanded, the rank, two modifiers and then the maximum.
local function gatherSkillSheet(out)
  local count, info = skillSheetApi()
  if not count then
    return false
  end
  local ok, total = pcall(count)
  total = ok and tonumber(total) or nil
  if not total then
    return false
  end
  local found = false
  for index = 1, total do
    local gotInfo, name, isHeader, _, rank, _, _, maxRank = pcall(info, index)
    local line = gotInfo and not isHeader and skillLineForName(name) or nil
    local value = tonumber(rank)
    if line and value and not out[line] then
      out[line] = { rank = value, max = tonumber(maxRank), specialisations = knownSpecialisations(line) }
      found = true
    end
  end
  return found
end

-- The professions the retail shaped client lists: GetProfessions answers up to five indices (nil
-- for an empty slot) and GetProfessionInfo(index) returns name, icon, skillLevel, maxSkillLevel,
-- numAbilities, spelloffset, skillLine, ... The seventh return is the skill line id itself, so no
-- name lookup (and no ItemTree_Data load) is needed; a client that leaves it out falls back to
-- the name. The Forever client answers here while its skill sheet reads empty.
local function gatherProfessions(out)
  local list, info = rawget(_G, "GetProfessions"), rawget(_G, "GetProfessionInfo")
  if type(list) ~= "function" or type(info) ~= "function" then
    return false
  end
  local ok, a, b, c, d, e, f = pcall(list)
  if not ok then
    return false
  end
  local found = false
  for _, index in pairs({ a, b, c, d, e, f }) do
    local gotInfo, name, _, rank, maxRank, _, _, skillLine = pcall(info, index)
    if gotInfo then
      local line = tonumber(skillLine) or skillLineForName(name)
      local value = tonumber(rank)
      if line and value and not out[line] then
        out[line] = { rank = value, max = tonumber(maxRank), specialisations = knownSpecialisations(line) }
        found = true
      end
    end
  end
  return found
end

-- The same answer from C_TradeSkillUI, which the newer engine keys by skill line id rather than
-- by name. Whatever shape the info table comes back in, the rank and the maximum are read under
-- both the names the engines have used for them.
local function gatherTradeSkills(out)
  local api = rawget(_G, "C_TradeSkillUI")
  if not (type(api) == "table" and type(api.GetAllProfessionTradeSkillLines) == "function") then
    return false
  end
  local ok, lines = pcall(api.GetAllProfessionTradeSkillLines)
  if not (ok and type(lines) == "table") then
    return false
  end
  local found = false
  for _, value in ipairs(lines) do
    local line = tonumber(value)
    local info = nil
    if line and type(api.GetTradeSkillLineInfoByID) == "function" then
      local gotInfo, entry = pcall(api.GetTradeSkillLineInfoByID, line)
      info = gotInfo and type(entry) == "table" and entry or nil
    end
    local rank = info and tonumber(info.skillLevel or info.rank) or nil
    if line and rank and not out[line] then
      out[line] = {
        rank = rank,
        max = tonumber(info.maxSkillLevel or info.maxRank),
        specialisations = knownSpecialisations(line),
      }
      found = true
    end
  end
  return found
end

PlayerSkills.knownSpecialisations = knownSpecialisations
PlayerSkills.gatherSkillSheet = gatherSkillSheet
PlayerSkills.gatherProfessions = gatherProfessions
PlayerSkills.gatherTradeSkills = gatherTradeSkills

-- Brief PR42: after the pretend professions change, everything that read the player's skills
-- reads them again through the seams: the window's skill cache (Frame.InvalidateSkills), Keep's
-- professions and scores (Keep.Reset, then Keep.Repaint for the bags and the tooltip), the
-- Professions model's cached route (ResetState), and the Professions pane and craft queue tray
-- where they show. Each through its owner's own public call, under pcall.
function PlayerSkills.ApplyDemo()
  local function call(owner, name)
    if type(owner) == "table" and type(owner[name]) == "function" then
      pcall(owner[name])
    end
  end
  local ui = ItemTree.UI
  call(type(ui) == "table" and ui.Frame or nil, "InvalidateSkills")
  -- Brief K24d: the held Enchanting rank the disenchant rules read (Core/DisenchantValue.lua), so
  -- the pretend Enchanting counts there too, and its end hands the real rank back.
  call(ItemTree.DisenchantValue, "ForgetRank")
  local keep = ItemTree.Keep
  call(keep, "Reset")
  call(ItemTree.ProfessionsModel, "ResetState")
  call(keep, "Repaint")
  local professions = ItemTree.Professions
  call(type(professions) == "table" and professions.pane or nil, "Refresh")
  call(ItemTree.ProfessionsQueue, "Refresh")
  return PlayerSkills.DemoOn()
end
