-- Profession specialisations, and what a profession category's header says about the player.
-- Pure Lua, no WoW API. Loaded as: local _, ItemTree = ...
--
-- The client knows which professions a player has (GetSkillLineInfo) and which specialisation
-- spells they know (IsSpellKnown). Core knows neither, so the caller hands both in as
--   playerSkills = { [skillLine] = { rank, max, specialisations = { name, ... } } }
-- which the UI fills from the client and the browser harness from its demo control. Every
-- word either of them draws is decided here, so the two never drift apart.
--
-- Specialisation names are the client's own and are left as the client spells them, the way
-- item and spell names are.
local _, ItemTree = ...

local Data = ItemTree.Data

local Skills = {}
ItemTree.Skills = Skills

local EMPTY = {}

-- The specialisation spells of each profession on Classic Era, in the order the client
-- teaches them: the specialisation first, then the masteries that build on it.
--
-- Ids and names are from SpellName in build 1.15.9.69722, the Classic Era baseline this
-- addon compares against (ItemTree-Data builds/1.15.9.69722/SpellName.csv, pulled from
-- wago.tools). Only these three professions have specialisations in this era.
Skills.SPECIALISATIONS = {
  -- Blacksmithing
  [164] = {
    { id = 9788, name = "Armorsmith" },
    { id = 9787, name = "Weaponsmith" },
    { id = 17039, name = "Master Swordsmith" },
    { id = 17040, name = "Master Hammersmith" },
    { id = 17041, name = "Master Axesmith" },
  },
  -- Leatherworking
  [165] = {
    { id = 10656, name = "Dragonscale Leatherworking" },
    { id = 10658, name = "Elemental Leatherworking" },
    { id = 10660, name = "Tribal Leatherworking" },
  },
  -- Engineering
  [202] = {
    { id = 20219, name = "Gnomish Engineer" },
    { id = 20222, name = "Goblin Engineer" },
  },
}

-- The specialisation spell ids of one profession, in teaching order, so the UI has a list to
-- put through IsSpellKnown. A profession with no specialisations answers with nothing.
function Skills.SpellIds(skillLine)
  local ids = {}
  for index, entry in ipairs(Skills.SPECIALISATIONS[skillLine] or EMPTY) do
    ids[index] = entry.id
  end
  return ids
end

-- The one specialisation to name for a profession, from the names the caller says the player
-- knows. SPECIALISATIONS lists them in teaching order, so the last one known is the one worth
-- showing: a Master Axesmith is a Weaponsmith too, and the title says more. A name this table
-- does not carry is still answered rather than dropped, so a build that adds one still reads.
function Skills.Specialisation(skillLine, known)
  local names = {}
  for _, name in ipairs(known or EMPTY) do
    names[name] = true
  end
  local best = nil
  for _, entry in ipairs(Skills.SPECIALISATIONS[skillLine] or EMPTY) do
    if names[entry.name] then
      best = entry.name
    end
  end
  if best then
    return best
  end
  return (known or EMPTY)[1]
end

-- What a profession category's header says about the player, or nil when there is nothing to
-- say: the category is not a profession, or the player does not have it.
--
-- category is a ViewModel category (its skillLine names the profession) or a skill line id on
-- its own. Returns { rank, max, specialisation, rankLine, line }.
--
-- rankLine is the profession and the numbers alone, "Blacksmithing 265/300". line is the same
-- with the specialisation appended, for a caller that has one row to say everything in, such
-- as the sidebar. A caller that draws the "Your skill" row under the header takes rankLine, so
-- the specialisation is stated once rather than twice.
--
-- A rank with no maximum is written on its own, and a profession the caller states no rank for
-- is named without numbers: the client never reports a real profession at zero, so a zero is
-- something it did not say rather than something to draw. rank and max are still passed back
-- as the caller stated them.
function Skills.CategoryHeader(category, playerSkills)
  local skillLine = type(category) == "table" and category.skillLine or tonumber(category)
  if not skillLine then
    return nil
  end
  local skill = (playerSkills or EMPTY)[skillLine]
  if type(skill) ~= "table" then
    return nil
  end

  local name = Data and Data:GetSkillName(skillLine) or ("Skill " .. tostring(skillLine))
  local rank, max = tonumber(skill.rank), tonumber(skill.max)
  local rankLine = name
  if rank and rank > 0 then
    if max and max > 0 then
      rankLine = string.format("%s %d/%d", name, rank, max)
    else
      rankLine = string.format("%s %d", name, rank)
    end
  end

  local specialisation = Skills.Specialisation(skillLine, skill.specialisations)
  local line = rankLine
  if specialisation then
    line = rankLine .. ", " .. specialisation
  end

  return {
    rank = rank,
    max = max,
    specialisation = specialisation,
    rankLine = rankLine,
    line = line,
  }
end

-- The specialisation a recipe can only be learned through, or nil.
--
-- No build states this. A recipe record carries n, sl, r, rs, tl, th, su, sup, re, out, en,
-- eq, cd, ccd, tools and by, and none of them names a specialisation: the client gates the
-- teaching spell instead, which is not in the tables the pipeline reads. So this answers nil
-- for every recipe the pipeline ships today. It reads a `spec` field, by id or by name, so a
-- curated table or a later build that does state one needs no change here.
function Skills.RecipeNeeds(recipe)
  if type(recipe) ~= "table" or recipe.spec == nil then
    return nil
  end
  for _, entry in ipairs(Skills.SPECIALISATIONS[recipe.sl] or EMPTY) do
    if entry.id == recipe.spec or entry.name == recipe.spec then
      return entry.name
    end
  end
  return type(recipe.spec) == "string" and recipe.spec or nil
end

-- Brief BQ24 (owner QA 2026-10-10 item 35, "When your skill is at max level and there's another
-- level after it, add a notification gem"): the last cap a profession's ranks reach (Artisan,
-- 300), and the caps of the ranks below it (Apprentice 75, Journeyman 150, Expert 225).
Skills.FINAL_CAP = 300

-- Whether a profession at rank of max (the client's own pair: the cap of the rank the player has
-- trained) can be trained further now: its rank is at the cap, and a further rank exists, which is
-- a band of the shipped route ending above the cap (routeTop, the highest band's top, where the
-- route is loaded) or a cap below Skills.FINAL_CAP. A rank under its cap, or no cap, is not. Pure.
function Skills.CanTrainFurther(rank, max, routeTop)
  rank, max = tonumber(rank), tonumber(max)
  if not rank or not max or max <= 0 or rank < max then
    return false
  end
  local top = tonumber(routeTop)
  if top and top > max then
    return true
  end
  return max < Skills.FINAL_CAP
end

-- The skill lines of playerSkills (Core's { [skillLine] = { rank, max } } shape) that can be
-- trained further (Skills.CanTrainFurther), ascending. routeTops (optional) maps a line to its
-- route's top. Pure.
function Skills.TrainableLines(playerSkills, routeTops)
  local out = {}
  routeTops = type(routeTops) == "table" and routeTops or EMPTY
  for line, skill in pairs(type(playerSkills) == "table" and playerSkills or EMPTY) do
    if type(line) == "number" and type(skill) == "table" then
      if Skills.CanTrainFurther(skill.rank, skill.max, routeTops[line]) then
        out[#out + 1] = line
      end
    end
  end
  table.sort(out)
  return out
end

return Skills
