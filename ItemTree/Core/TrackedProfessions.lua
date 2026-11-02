-- Brief TP1 (the owner's QA item 210, Tom's feedback via Chris, 2026-10-17): the professions a
-- character tracks without having them. "Even though we show the users professions by default we
-- should allow a user to add a profession to their list (permanent filter addition per character)":
-- a bank alt, or a curious player, adds any profession they do not have on the Professions tab
-- (ItemTree_Professions/UI/Track.lua draws the list) and picks a range of its route for it, or none.
--
-- The store, per character, made on the first add (a character that never tracked stores nothing,
-- so an older saved file reads as tracking nothing):
--   ItemTreeCharDB.trackedProfessions = { { line = 197, lo = 55, hi = 80 }, { line = 164 } }
-- in the order they were added, a skill line id each, lo and hi the range picked (a band of the
-- shipped route, ItemTree_Professions' ProfessionTracks), both left out for "none". Ids and numbers
-- only: nothing about the character is stored.
--
-- What tracking does (the owner's ruling A of 2026-10-17): a profession tracked at a range is held,
-- for ItemTree's Keep and its tooltip, as if the character had it at the range's BOTTOM (lo), and
-- (the owner's answer of 2026-10-17, option A: "a range they want to track") for that range alone:
-- the route counts the range's own band and nothing for the bands after it (the Professions model's
-- Model.InWindow, from top = hi), its recipes are the character's own uses and its reagents are
-- kept. Moving the range up moves what is kept. "none" tracks
-- nothing: the profession is on the list for browsing only. Where it is never a claim that the
-- character HAS the profession (trainer rank advice, "Needs a skill you lack", Show nearest, the
-- item page's skill rows, the tool and bag rules), the client's own skills answer alone: nothing
-- there reads this file. Tracking is the Professions tab's: with the tab off it sleeps
-- (Core/Keep.lua Keep.KeepProfessions asks Keep.ProfessionModel first).
--
-- The readers: Core/Keep.lua Keep.KeepProfessions (the skill line set Keep scores with) and
-- ItemTree_Professions/Core/Professions.lua Model.Facts (the skills its route is worked out from).
--
-- Everything above the "Client side" divider is pure and runs under busted with no WoW API.
local _, ItemTree = ...

local Tracked = {}
ItemTree.TrackedProfessions = Tracked

local EMPTY = {}

-- The field in ItemTreeCharDB.
Tracked.FIELD = "trackedProfessions"
-- The most entries read from the store. The route has twelve professions; anything past this many
-- is never read.
Tracked.MAX = 32
-- Bumped on every change (Tracked.Apply), so a holder of a merged set (Keep.KeepProfessions) merges
-- again.
Tracked.generation = 0

--------------------------------------------------------------------------------
-- Pure
--------------------------------------------------------------------------------

-- A whole number at least low, or nil. Pure.
local function whole(value, low)
  value = tonumber(value)
  if value == nil or value ~= value or value % 1 ~= 0 or value < low then
    return nil
  end
  return value
end

--- The stored list made safe to read: each entry a fresh { line, lo, hi } copy, its line a whole
--- number above 0, each line once (the first wins), in the stored order, at most Tracked.MAX. A range
--- is kept only as two whole numbers with 0 <= lo < hi; anything else reads as none. A store that is
--- not a list reads as empty. Pure.
function Tracked.Normalise(raw)
  local out, seen = {}, {}
  if type(raw) ~= "table" then
    return out
  end
  for index = 1, Tracked.MAX do
    local entry = raw[index]
    if entry == nil then
      break
    end
    local line = type(entry) == "table" and whole(entry.line, 1) or nil
    if line and not seen[line] then
      seen[line] = true
      local kept = { line = line }
      local lo, hi = whole(entry.lo, 0), whole(entry.hi, 1)
      if lo and hi and lo < hi then
        kept.lo, kept.hi = lo, hi
      end
      out[#out + 1] = kept
    end
  end
  return out
end

--- Whether the list holds a line. Pure.
function Tracked.Holds(list, line)
  line = tonumber(line)
  for _, entry in ipairs(type(list) == "table" and list or EMPTY) do
    if entry.line == line then
      return true
    end
  end
  return false
end

-- Whether a line is one of the character's own (real is a set or a skills table keyed by line; an
-- entry marked tracked is not its own), through isOwn(line, real) where the caller hands one (Keep's
-- Keep.IsOwnSkill, which also matches a profession listed on a second line by its name). Pure.
local function ownLine(line, real, isOwn)
  if type(real) ~= "table" then
    return false
  end
  local held = real[line]
  if held ~= nil and held ~= false and not (type(held) == "table" and held.tracked) then
    return true
  end
  if type(isOwn) == "function" then
    local ok, answer = pcall(isOwn, line, real)
    return ok and answer == true
  end
  return false
end

--- The tracked entries that track at a range and are not one of the character's own professions
--- (real, a set or skills table keyed by line: a profession learned for real wins). Pure.
function Tracked.Active(list, real, isOwn)
  local out = {}
  for _, entry in ipairs(Tracked.Normalise(list)) do
    if entry.lo ~= nil and not ownLine(entry.line, real, isOwn) then
      out[#out + 1] = entry
    end
  end
  return out
end

--- The skill line set Keep adds to the character's own: { [line] = true } for each entry
--- Tracked.Active keeps. Pure.
function Tracked.SetOf(list, real, isOwn)
  local out = {}
  for _, entry in ipairs(Tracked.Active(list, real, isOwn)) do
    out[entry.line] = true
  end
  return out
end

--- The skills the route adds to the character's own: { [line] = { rank = lo, top = hi, lo, hi,
--- tracked = true } } for each entry Tracked.Active keeps. The rank is the range's bottom: a
--- character there still has the whole range ahead, so the range's own band counts in full (the top
--- would have marked it done and kept nothing for it). top is the range's end: the owner's option A
--- (2026-10-17) keeps the range alone, so no band from top on counts (Model.InWindow). Pure.
function Tracked.SkillsOf(list, real, isOwn)
  local out = {}
  for _, entry in ipairs(Tracked.Active(list, real, isOwn)) do
    out[entry.line] = { rank = entry.lo, top = entry.hi, lo = entry.lo, hi = entry.hi, tracked = true }
  end
  return out
end

--- skills with extra joined in: a new table where extra adds anything (an entry of skills always
--- wins), else skills itself; skills that is not a table is answered as it is (the client did not
--- say, and tracking never makes it say). Pure, never writes into either.
function Tracked.Join(skills, extra)
  if type(skills) ~= "table" or type(extra) ~= "table" or next(extra) == nil then
    return skills
  end
  local out = {}
  for line, value in pairs(skills) do
    out[line] = value
  end
  local added = false
  for line, value in pairs(extra) do
    if out[line] == nil then
      out[line] = value
      added = true
    end
  end
  if not added then
    return skills
  end
  return out
end

--- The list after adding a line (at the end, none), or nil where it is already there or not a
--- line. Pure: a new list.
function Tracked.Added(list, line)
  line = whole(line, 1)
  local out = Tracked.Normalise(list)
  if not line or Tracked.Holds(out, line) or #out >= Tracked.MAX then
    return nil
  end
  out[#out + 1] = { line = line }
  return out
end

--- The list after removing a line, or nil where it is not there. Pure: a new list.
function Tracked.Removed(list, line)
  line = tonumber(line)
  local out, found = {}, false
  for _, entry in ipairs(Tracked.Normalise(list)) do
    if entry.line == line then
      found = true
    else
      out[#out + 1] = entry
    end
  end
  if not found then
    return nil
  end
  return out
end

--- The list after setting a line's range (lo nil for none), or nil where the line is not there,
--- the range is not a whole lo below hi, or nothing changes. Pure: a new list.
function Tracked.Ranged(list, line, lo, hi)
  line = tonumber(line)
  local wantLo, wantHi = nil, nil
  if lo ~= nil then
    wantLo, wantHi = whole(lo, 0), whole(hi, 1)
    if not (wantLo and wantHi and wantLo < wantHi) then
      return nil
    end
  end
  local out, changed, found = Tracked.Normalise(list), false, false
  for _, entry in ipairs(out) do
    if entry.line == line then
      found = true
      if entry.lo ~= wantLo or entry.hi ~= wantHi then
        entry.lo, entry.hi = wantLo, wantHi
        changed = true
      end
    end
  end
  if not (found and changed) then
    return nil
  end
  return out
end

--------------------------------------------------------------------------------
-- Client side. Guarded: the store is ItemTree.charDb, which Core/Init.lua sets at ADDON_LOADED.
--------------------------------------------------------------------------------

-- A pretend list the developer's test run sets for one case (never shipped: Tracked.Pretend below is
-- stripped from a package): while set, every reader below answers it instead of the saved one.
-- Memory only: never saved, a /reload ends it, and the changes the player makes still write the
-- saved list.
Tracked.pretend = nil

-- The saved list, or nil where there is none (or no charDb yet).
local function store()
  local charDb = ItemTree.charDb
  if type(charDb) ~= "table" then
    return nil
  end
  local list = charDb[Tracked.FIELD]
  if type(list) ~= "table" then
    return nil
  end
  return list
end

-- Writes a list back, made where there was none. Answers whether it was written.
local function save(list)
  local charDb = ItemTree.charDb
  if type(charDb) ~= "table" or type(list) ~= "table" then
    return false
  end
  charDb[Tracked.FIELD] = list
  return true
end

-- The list the readers answer: the developer's pretend one while set, else the saved one.
local function current()
  if type(Tracked.pretend) == "table" then
    return Tracked.pretend
  end
  return store()
end

--- The character's tracked professions, { { line, lo, hi } } (lo and hi nil for none), a fresh copy.
function Tracked.List()
  return Tracked.Normalise(current())
end

--- Whether the character tracks a line (at a range or none).
function Tracked.Has(line)
  return Tracked.Holds(Tracked.List(), line)
end

--- The skill line set the character tracks at a range, less its own professions (real, a set keyed
--- by line), for Keep.KeepProfessions. isOwn(line, real) as Tracked.Active.
function Tracked.Set(real, isOwn)
  return Tracked.SetOf(current(), real, isOwn)
end

--- The skills the character tracks at a range, less its own (real, Frame.PlayerSkills' shape), for
--- the Professions model's Model.Facts.
function Tracked.Skills(real, isOwn)
  return Tracked.SkillsOf(current(), real, isOwn)
end

--- After a change: everything that read the tracked list reads it again through its owner's own
--- public call, as UI/PlayerSkills.lua ApplyDemo does: the Professions model's cached route
--- (ResetState), Keep's professions and scores (Keep.Reset, then Keep.Repaint for the bags and the
--- tooltip), and another addon listening on ItemTreeAPI (NotifyChange "setting": a per character
--- choice that moves its answers; quiet leaves it out, for the developer's pretend list). The
--- Professions pane redraws itself after the click that made the change. Answers the new generation.
function Tracked.Apply(quiet)
  Tracked.generation = (tonumber(Tracked.generation) or 0) + 1
  local function call(owner, name, ...)
    if type(owner) == "table" and type(owner[name]) == "function" then
      pcall(owner[name], ...)
    end
  end
  call(ItemTree.ProfessionsModel, "ResetState")
  local keep = ItemTree.Keep
  call(keep, "Reset")
  call(keep, "Repaint")
  if not quiet then
    call(ItemTree.API, "NotifyChange", "setting")
  end
  return Tracked.generation
end


-- Writes a changed list and applies it. Answers whether anything changed.
local function commit(list)
  if type(list) ~= "table" or not save(list) then
    return false
  end
  Tracked.Apply()
  return true
end

--- Adds a profession to the character's list, tracking nothing yet (none). Answers whether it was
--- added.
function Tracked.Add(line)
  return commit(Tracked.Added(store(), line))
end

--- Takes a tracked profession off the list. Answers whether it was there.
function Tracked.Remove(line)
  return commit(Tracked.Removed(store(), line))
end

--- Sets a tracked profession's range, lo to hi, or none with lo nil. Answers whether it changed.
function Tracked.SetRange(line, lo, hi)
  return commit(Tracked.Ranged(store(), line, lo, hi))
end

return Tracked
