-- The Professions model (brief PR4): pure functions over the ProfessionTracks data, and the
-- player's Relevant set the Keep rule asks (Core/Keep.lua Keep.ProfessionRelevant).
--
-- Loaded by the client after Data\generated\Data.xml and before Module.lua, which hands this table
-- out as ItemTree.Professions.model.
--
--   Model.Colour(recipe, rank)                     "orange", "yellow", "green", "grey" or
--                                                  "unlearnable"
--   Model.Track(tracks, skillLine, rank, faction)  { kind, max, bands = { { lo, hi, label, from,
--                                                  untested, state, route, nodes, spots, note } } }
--   Model.Note(note, recipes)                      a gathering band's note, checked, or nil (PR48)
--   Model.GatherNote(gather)                       a planned band's gather note, checked, or nil (G1b)
--   Model.Relevant(tracks, skills, faction)        { [itemId] = { skillLine, lo, hi } }
--   Model.Chance(recipe, rank)                     a skill point's chance from one craft (PR9)
--   Model.Crafts(recipe, from, to)                 expected crafts from rank to rank, rounded up
--   Model.Points(recipe, from, to)                 the skill points it can give there (PR49b)
--   Model.HasPoints(recipe, from, to)              whether it gives any (PR49b)
--   Model.BandPick(band, recipes, faction)         a re-planned band's pick, route[1] (PR49b)
--   Model.Gathers(skills)                          the gathering lines the player holds (BQ18)
--   Model.PlayerBand(band, gathers)                a band as the player plans it: a gatherer's
--                                                  pick (band.ga) swapped in (BQ18)
--   Model.CooldownDays(recipes)                    { [itemId] = days } cooldown recipes make
--   Model.RouteCost(recipe, from, to, opts)        a card's cost per expected point (PR49b)
--   Model.Rerank(entries)                          a re-planned band's live order (PR49b)
--   Model.Needed(tracks, skills, faction)          { [itemId] = { skillLine, need, lo, hi } }
--   Model.BandCrafts(band, recipes, rank, faction) each route recipe's crafts alone to the band's hi
--   Model.LinePlan(line, skill, faction)           { needs, parts, plans } over a line's bands left
--   Model.RouteNeed(line, itemId, skill, faction)  one reagent's route-wide need, and its parts
--   Model.PlanCrafts(skillLine, lo, spell)         the player's plan crafts for one card (client)
--   Model.AloneCrafts(skillLine, lo, spell)        a route card's crafts alone in its band (client)
--   Model.Signature(skills)                        "164:120,185:40", "-" for none, "?" unknown
--   Model.WithTracked(skills)                      the skills with the tracked professions joined (TP1)
--   Model.InWindow(lo, hi, skill)                  whether a band counts for a tracked range (TP1)
--   Model.Current()                                the player's Relevant set, cached (client)
--   Model.CurrentSignature()                       the signature that set was built for (client)
--   Model.NeededFor(itemId)                        the player's Needed entry, cached (client)
--
-- Owner rulings (2026-09-30): only the recommended route counts, and only while the player's rank
-- in that line is below the recipe's grey rank; gathering lines never make anything relevant.
--
-- Missing ranks, read sensibly: no r is rank 1 (the contract fills r, so this is a guard); no tl
-- is orange until grey; no th is never grey (and stays relevant); tl with no th has no green.
local _, ItemTree = ...
-- ItemTree_Professions is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Modules) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end

local Model = {}
ItemTree.ProfessionsModel = Model

local EMPTY = {}

Model.ALLIANCE = 1
Model.HORDE = 2

local number = ItemTree.Util.Number

--- The green rank: halfway from yellow to grey, rounded down. nil without both. Pure.
function Model.Green(tl, th)
  tl, th = number(tl), number(th)
  if tl == nil or th == nil then
    return nil
  end
  return math.floor((tl + th) / 2)
end

--- A recipe's colour at a rank. nil for no recipe. Pure.
function Model.Colour(recipe, rank)
  if type(recipe) ~= "table" then
    return nil
  end
  rank = number(rank) or 0
  local r = number(recipe.r) or 1
  local tl, th = number(recipe.tl), number(recipe.th)
  if rank < r then
    return "unlearnable"
  end
  if th ~= nil and rank >= th then
    return "grey"
  end
  if tl == nil or rank < tl then
    return "orange"
  end
  local green = Model.Green(tl, th)
  if green ~= nil and rank >= green then
    return "green"
  end
  return "yellow"
end

--- Whether a recipe for this side is the player's: no side on the recipe, no side known for the
--- player, or the same side. Pure.
function Model.FactionOk(fa, faction)
  fa, faction = number(fa), number(faction)
  if fa ~= Model.ALLIANCE and fa ~= Model.HORDE then
    return true
  end
  if faction ~= Model.ALLIANCE and faction ~= Model.HORDE then
    return true
  end
  return fa == faction
end

--- "done", "current" or "future" for a band at a rank. Pure.
function Model.BandState(lo, hi, rank)
  rank = number(rank) or 0
  if rank >= (number(hi) or 0) then
    return "done"
  end
  if rank >= (number(lo) or 0) then
    return "current"
  end
  return "future"
end

local function lineOf(tracks, skillLine)
  local lines = type(tracks) == "table" and tracks.lines or nil
  local line = type(lines) == "table" and lines[number(skillLine)] or nil
  if type(line) == "table" then
    return line
  end
  return nil
end

-- Brief PR49b: a learn word the card can say, else nil (an older tracks file has none).
local LEARN_WORDS = { trainer = true, vendor = true, reputation = true, drop = true, spec = true }

local function node(spell, recipe, onRoute, rank)
  local out = {
    spell = spell,
    out = recipe.out,
    re = recipe.re,
    r = recipe.r,
    tl = recipe.tl,
    th = recipe.th,
    est = recipe.est == true,
    route = onRoute,
    colour = Model.Colour(recipe, rank),
  }
  -- Brief PR49b: the re-planned routes' fields, each read only where the data carries it, so an
  -- older tracks file draws as before: the Classic Era window where this client's differs, how
  -- the recipe is learnt, its specialisation, Season of Discovery, and its teaching items.
  out.ctl, out.cth = number(recipe.ctl), number(recipe.cth)
  if type(recipe.learn) == "string" and LEARN_WORDS[recipe.learn] then
    out.learn = recipe.learn
  end
  out.spec = number(recipe.spec)
  out.sod = recipe.sod == true or nil
  out.by = type(recipe.by) == "table" and recipe.by or nil
  return out
end

local function byRank(a, b)
  local ra, rb = number(a.r) or 1, number(b.r) or 1
  if ra ~= rb then
    return ra < rb
  end
  return a.spell < b.spell
end

-- Brief PR34 (owner, 2026-10-02): the route's own order within a band. Use what you can learn
-- first and wring it dry, then swap once it goes green: the guide step's start skill (start[spell],
-- optional) lowest first, then r (learnable earliest), then tl (turns yellow soonest), then the
-- page's order. A missing start sorts after every given one; a missing tl after every given one.
local function routeOrder(start)
  start = type(start) == "table" and start or EMPTY
  return function(a, b)
    local sa, sb = number(start[a.node.spell]), number(start[b.node.spell])
    if sa ~= sb then
      if sa == nil or sb == nil then
        return sb == nil
      end
      return sa < sb
    end
    local ra, rb = number(a.node.r) or 1, number(b.node.r) or 1
    if ra ~= rb then
      return ra < rb
    end
    local ta, tb = number(a.node.tl), number(b.node.tl)
    if ta ~= tb then
      if ta == nil or tb == nil then
        return tb == nil
      end
      return ta < tb
    end
    return a.index < b.index
  end
end

-- A band's route recipes for the player's side, once each, in the route's own order (routeOrder):
-- { { node = { spell, r, tl }, recipe, index } }, and the set of the spells taken. Pure.
local function routeEntries(band, recipes, faction)
  local seen, onRoute = {}, {}
  for _, spell in ipairs(type(band.route) == "table" and band.route or EMPTY) do
    local recipe = recipes[spell]
    if type(recipe) == "table" and not seen[spell] and Model.FactionOk(recipe.fa, faction) then
      seen[spell] = true
      local index = #onRoute + 1
      onRoute[index] = { node = { spell = spell, r = recipe.r, tl = recipe.tl }, recipe = recipe, index = index }
    end
  end
  table.sort(onRoute, routeOrder(band.start))
  return onRoute, seen
end

-- Brief PR49b: a list of spell ids from the data (band.was, band.alt), numbers only, or nil.
local function spellList(list)
  if type(list) ~= "table" then
    return nil
  end
  local out = {}
  for _, spell in ipairs(list) do
    local id = number(spell)
    if id then
      out[#out + 1] = id
    end
  end
  if #out == 0 then
    return nil
  end
  return out
end

-- Brief PR49b: a recipe's first reagent made by a cooldown recipe, { item, per, days } (days a
-- unit, Model.CooldownDays), or nil.
local function cooldownOf(recipe, cooldowns)
  for _, reagent in ipairs(type(recipe.re) == "table" and recipe.re or EMPTY) do
    local itemId = type(reagent) == "table" and number(reagent[1]) or nil
    local days = itemId and cooldowns[itemId] or nil
    if days then
      return { item = itemId, per = number(reagent[2]) or 1, days = days }
    end
  end
  return nil
end

--- Brief PR49b: a re-planned band's pick, the data's route[1] (the compile's choice for this
--- client's windows): the first route spell for the player's side with points left anywhere in
--- the band (Model.Points), or nil where none has. Pure.
function Model.BandPick(band, recipes, faction)
  if type(band) ~= "table" or type(recipes) ~= "table" then
    return nil
  end
  local lo, hi = number(band.lo) or 0, number(band.hi) or 0
  for _, spell in ipairs(type(band.route) == "table" and band.route or EMPTY) do
    local recipe = recipes[spell]
    if type(recipe) == "table" and Model.FactionOk(recipe.fa, faction) and Model.HasPoints(recipe, lo, hi) then
      return spell
    end
  end
  return nil
end

--- Brief G1b: a planned gathering band's gather note as the data gives it, { lo, hi, items }
--- (ItemTree-Data's "gathering bands planned on the target build"), checked: lo and hi numbers and
--- the item ids that are numbers, in the data's order. A copy, or nil for anything else (older data
--- has none). Pure.
function Model.GatherNote(gather)
  if type(gather) ~= "table" or type(gather.items) ~= "table" then
    return nil
  end
  local lo, hi = number(gather.lo), number(gather.hi)
  if not (lo and hi) then
    return nil
  end
  local items = {}
  for _, id in ipairs(gather.items) do
    if number(id) then
      items[#items + 1] = number(id)
    end
  end
  if #items == 0 then
    return nil
  end
  return { lo = lo, hi = hi, items = items }
end

-- Brief PR48: the smelting half of a band's note, checked, or nil.
local function smeltNote(note, recipes)
  if type(note.mine) ~= "table" or type(note.smelt) ~= "table" then
    return nil
  end
  local mineLo, mineHi = number(note.mine[1]), number(note.mine[2])
  local spell, from, to = number(note.smelt[1]), number(note.smelt[2]), number(note.smelt[3])
  if not (mineLo and mineHi and spell and from and to) then
    return nil
  end
  if type(recipes) ~= "table" or type(recipes[spell]) ~= "table" then
    return nil
  end
  return {
    mine = { mineLo, mineHi },
    smelt = { spell, from, to },
    from = type(note.from) == "string" and note.from or nil,
  }
end

--- Brief PR48: a gathering band's note as the data gives it, { mine = { lo, hi }, smelt = { spell,
--- from, to }, from = "route" or "window" }, checked: every number there and the smelt one of the
--- line's recipes. Brief G1b: and its gather note (Model.GatherNote) as gather, beside the smelting
--- keys or alone (Herbalism). A copy, or nil where neither half checks (older data has no note at
--- all). Pure.
function Model.Note(note, recipes)
  if type(note) ~= "table" then
    return nil
  end
  local out = smeltNote(note, recipes)
  local gather = Model.GatherNote(note.gather)
  if gather then
    out = out or {}
    out.gather = gather
  end
  return out
end

-- Brief PR48 (owner QA, 2026-10-05: Mining shows Smelt Copper beside the ore): a gathering band's
-- spots split into the places to gather (item, zone, node, creature spots, in the data's order)
-- and its recipe spots, each made a recipe node of the crafting bands' shape (off the route), for
-- the player's side, in the data's order (by r). A band with no recipe spot keeps its own spots
-- table, as older data draws. Pure.
local function gatherCards(band, recipes, rank, faction)
  local spots = type(band.spots) == "table" and band.spots or nil
  if not spots then
    return band.spots, {}
  end
  local places, nodes, any = {}, {}, false
  for _, spot in ipairs(spots) do
    if type(spot) == "table" and spot.k == "recipe" then
      any = true
      local spell = number(spot.id)
      local recipe = spell and recipes[spell] or nil
      if type(recipe) == "table" and Model.FactionOk(recipe.fa, faction) then
        nodes[#nodes + 1] = node(spell, recipe, false, rank)
      end
    else
      places[#places + 1] = spot
    end
  end
  if not any then
    return spots, nodes
  end
  return places, nodes
end

--- Brief BQ18 (the owner's ruling of 2026-10-10, QA item 12, "he skins, so hides cost him nothing"):
--- the gathering skill lines. The compile plans each band once for every character; where costing a
--- gathering line's own goods at their sell price picks another recipe for a re-planned band, the
--- band names it (ga = { [gathering line] = spellId }, ItemTree-Data's docs/data-format.md), and
--- the player holding that line plans the band with it (Model.PlayerBand).
Model.GATHER_LINES = { [182] = true, [186] = true, [356] = true, [393] = true }

--- Brief BQ18: the gathering lines among the player's skills ({ [skillLine] = { rank } }), as a set,
--- or nil for none. Brief TP1: never a tracked one (tracked = true): the gatherer's pick says the
--- character gathers those goods itself, which tracking never makes true. Pure.
function Model.Gathers(skills)
  if type(skills) ~= "table" then
    return nil
  end
  local out = nil
  for line, skill in pairs(skills) do
    if type(line) == "number" and Model.GATHER_LINES[line] and type(skill) == "table" and skill.tracked ~= true then
      out = out or {}
      out[line] = true
    end
  end
  return out
end

--- Brief BQ18: a band as the player plans it. Where the band names a gatherer's pick (band.ga) for a
--- gathering line in gathers (Model.Gathers; the lowest line id where several do), a view of the
--- band whose route[1] is that recipe (it starts at the band's lo), the compile's pick leading the
--- alternatives (band.alt) and the rest of the route standing; else the band itself. Pure.
function Model.PlayerBand(band, gathers)
  if type(band) ~= "table" or type(band.ga) ~= "table" or type(gathers) ~= "table" then
    return band
  end
  local lines = {}
  for line in pairs(band.ga) do
    if type(line) == "number" and gathers[line] then
      lines[#lines + 1] = line
    end
  end
  table.sort(lines)
  local spell = lines[1] and number(band.ga[lines[1]]) or nil
  local route = type(band.route) == "table" and band.route or EMPTY
  if not spell or route[1] == spell then
    return band
  end
  local view = {}
  for key, value in pairs(band) do
    view[key] = value
  end
  view.route = { spell }
  for index, other in ipairs(route) do
    if index > 1 and other ~= spell then
      view.route[#view.route + 1] = other
    end
  end
  view.alt = {}
  if route[1] ~= nil then
    view.alt[1] = route[1]
  end
  for _, other in ipairs(type(band.alt) == "table" and band.alt or EMPTY) do
    if other ~= spell and other ~= route[1] then
      view.alt[#view.alt + 1] = other
    end
  end
  view.start = {}
  for key, value in pairs(type(band.start) == "table" and band.start or EMPTY) do
    view.start[key] = value
  end
  view.start[spell] = number(band.lo) or 0
  view.gatheredPick = spell
  return view
end

--- One line's route for a player: its bands, each with its state and nodes (the route spells
--- first, by the band's start[spell], then r, then tl, then page order (routeOrder), then every
--- other recipe whose r is in the band, by r then spell id; the last band takes r == hi too).
--- Recipes for the other side are left out. Brief PR49b: a crafting node carries recommended
--- (the Recommended tag and the arrow: every route recipe with points, or a re-planned band's
--- pick alone), noPoints (a route or alt recipe with no points in the band, last), alt (band.alt,
--- after the route), cd (Model.CooldownDays' first cooldown reagent) and the recipe's ctl, cth,
--- learn, spec, sod and by; a crafting band carries was, alt, thin and pick, each only where the
--- data has it. nil for a line the data does not hold. Brief PR48: a
--- gathering band's spots are its places to gather, its nodes its recipe spots made recipe nodes
--- (Mining's smelts, none on the route), and its note Model.Note's. Brief BQ18: gathers, the
--- player's gathering lines (Model.Gathers), plans each band through Model.PlayerBand; nil reads
--- the set the cached pass last held (Model.state.gathers, nil until Model.Current has run). Pure
--- over that held set.
function Model.Track(tracks, skillLine, rank, faction, gathers)
  local line = lineOf(tracks, skillLine)
  if not line then
    return nil
  end
  if gathers == nil and type(Model.state) == "table" then
    gathers = Model.state.gathers
  end
  rank = number(rank) or 0
  local recipes = type(line.recipes) == "table" and line.recipes or EMPTY
  local bands = type(line.bands) == "table" and line.bands or EMPTY
  local out = { kind = line.kind, max = line.max, bands = {} }
  local cooldowns = line.kind ~= "gather" and Model.CooldownDays(recipes) or EMPTY
  for index, band in ipairs(bands) do
    band = Model.PlayerBand(band, gathers)
    local lo, hi = number(band.lo) or 0, number(band.hi) or 0
    local last = index == #bands
    local entry = {
      lo = lo,
      hi = hi,
      label = string.format("%d-%d", lo, hi),
      from = band.from,
      untested = band.untested == true or nil,
      state = Model.BandState(lo, hi, rank),
      route = {},
      nodes = {},
      spots = band.spots,
    }
    if line.kind ~= "gather" then
      -- Brief PR49b: a re-planned band's fields, guarded (older tracks carry none of them).
      entry.was = spellList(band.was)
      entry.alt = spellList(band.alt)
      entry.thin = band.thin == true or nil
      local onRoute, seen = routeEntries(band, recipes, faction)
      local pick = band.from == "forever" and Model.BandPick(band, recipes, faction) or nil
      entry.pick = pick
      local first, others, grey = {}, {}, {}
      for _, keyed in ipairs(onRoute) do
        local spell = keyed.node.spell
        entry.route[#entry.route + 1] = spell
        local made = node(spell, keyed.recipe, true, rank)
        made.cd = cooldownOf(keyed.recipe, cooldowns)
        -- Brief PR49b: a route recipe with no points anywhere in the band (grey at its start on
        -- this client) is never Recommended, never on the arrow, and sorts last. A re-planned
        -- band's pick (route[1]) is its one Recommended card; every other band's route recipes
        -- are all Recommended, as ever.
        if not Model.HasPoints(keyed.recipe, lo, hi) then
          made.recommended, made.noPoints = false, true
          grey[#grey + 1] = made
        elseif pick ~= nil then
          made.recommended = spell == pick
          if made.recommended then
            first[#first + 1] = made
          else
            others[#others + 1] = made
          end
        else
          made.recommended = true
          others[#others + 1] = made
        end
      end
      for _, list in ipairs({ first, others }) do
        for _, made in ipairs(list) do
          entry.nodes[#entry.nodes + 1] = made
        end
      end
      -- Brief PR49b: the band's alternatives to its pick (band.alt, cost order), drawn after the
      -- route's own, held on screen like the route, never Recommended until a live re-rank says.
      for _, spell in ipairs(entry.alt or EMPTY) do
        local recipe = recipes[spell]
        if type(recipe) == "table" and not seen[spell] and Model.FactionOk(recipe.fa, faction) then
          seen[spell] = true
          local made = node(spell, recipe, false, rank)
          made.alt, made.recommended = true, false
          made.cd = cooldownOf(recipe, cooldowns)
          if not Model.HasPoints(recipe, lo, hi) then
            made.noPoints = true
            grey[#grey + 1] = made
          else
            entry.nodes[#entry.nodes + 1] = made
          end
        end
      end
      local rest = {}
      for spell, recipe in pairs(recipes) do
        if type(spell) == "number" and type(recipe) == "table" and not seen[spell] then
          local r = number(recipe.r) or 1
          local inside = r >= lo and (r < hi or (last and r == hi))
          if inside and Model.FactionOk(recipe.fa, faction) then
            rest[#rest + 1] = node(spell, recipe, false, rank)
          end
        end
      end
      table.sort(rest, byRank)
      for _, extra in ipairs(rest) do
        entry.nodes[#entry.nodes + 1] = extra
      end
      for _, made in ipairs(grey) do
        entry.nodes[#entry.nodes + 1] = made
      end
    else
      entry.spots, entry.nodes = gatherCards(band, recipes, rank, faction)
      entry.note = Model.Note(band.note, recipes)
    end
    out.bands[#out.bands + 1] = entry
  end
  return out
end

-- Whether candidate a is nearer the player than b. An entry whose band is still around or ahead
-- of the player (hi > rank) beats one the player has passed; among those the lowest lo wins, and
-- among passed ones the highest lo (the closest behind). Ties go to the lower skill line, then the
-- lower hi, so the answer does not hang on pairs order.
local function nearer(a, b)
  if a.ahead ~= b.ahead then
    return a.ahead
  end
  if a.lo ~= b.lo then
    if a.ahead then
      return a.lo < b.lo
    end
    return a.lo > b.lo
  end
  if a.skillLine ~= b.skillLine then
    return a.skillLine < b.skillLine
  end
  return a.hi < b.hi
end

--- Brief TP1 (the owner's answer of 2026-10-17, option A: "a range they want to track"): whether a
--- band from lo to hi counts for a skill. Always for the player's own (no window); for a profession
--- tracked at a range (skill.top, Core/TrackedProfessions.lua: { rank = the range's bottom, top = its
--- top }) only a band inside that range, starting below its top and ending above its bottom, so the
--- range keeps its own band's items and nothing for the bands after it. skill is a { rank, top } table
--- or a bare rank (no window). Pure.
function Model.InWindow(lo, hi, skill)
  local top = type(skill) == "table" and number(skill.top) or nil
  if top == nil then
    return true
  end
  local bottom = number(skill.rank) or 0
  return (number(lo) or 0) < top and (number(hi) or 0) > bottom
end

--- The items the player's routes still need: every reagent and teaching item of a route recipe,
--- in a craft line the player has, while the player's rank there is below the recipe's grey rank,
--- for the player's side. { [itemId] = { skillLine, lo, hi } }, the nearest band where an item
--- serves several. skills is Frame.PlayerSkills()'s { [skillLine] = { rank, max } }. Pure.
function Model.Relevant(tracks, skills, faction)
  local found = {}
  if type(skills) ~= "table" then
    return {}
  end
  local function consider(itemId, candidate)
    itemId = number(itemId)
    if not itemId then
      return
    end
    local held = found[itemId]
    if not held or nearer(candidate, held) then
      found[itemId] = candidate
    end
  end
  -- Brief BQ18: each band as the player plans it (Model.PlayerBand).
  local gathers = Model.Gathers(skills)
  for skillLine, skill in pairs(skills) do
    local line = type(skillLine) == "number" and lineOf(tracks, skillLine) or nil
    if line and line.kind ~= "gather" and type(skill) == "table" then
      local rank = number(skill.rank) or 0
      local recipes = type(line.recipes) == "table" and line.recipes or EMPTY
      for _, band in ipairs(type(line.bands) == "table" and line.bands or EMPTY) do
        band = Model.PlayerBand(band, gathers)
        local lo, hi = number(band.lo) or 0, number(band.hi) or 0
        -- Brief TP1 (the owner's option A): a tracked range counts its own band alone (Model.InWindow).
        local route = Model.InWindow(lo, hi, skill) and band.route or nil
        for _, spell in ipairs(type(route) == "table" and route or EMPTY) do
          local recipe = recipes[spell]
          local th = type(recipe) == "table" and number(recipe.th) or nil
          if type(recipe) == "table" and (th == nil or rank < th) and Model.FactionOk(recipe.fa, faction) then
            local candidate = { skillLine = skillLine, lo = lo, hi = hi, ahead = hi > rank }
            for _, reagent in ipairs(type(recipe.re) == "table" and recipe.re or EMPTY) do
              if type(reagent) == "table" then
                consider(reagent[1], candidate)
              end
            end
            for _, teacher in ipairs(type(recipe.by) == "table" and recipe.by or EMPTY) do
              consider(teacher, candidate)
            end
          end
        end
      end
    end
  end
  local out = {}
  for itemId, entry in pairs(found) do
    out[itemId] = { skillLine = entry.skillLine, lo = entry.lo, hi = entry.hi }
  end
  return out
end

--- Brief PR9: the chance of a skill point from one craft at rank s, the standard Classic curve:
--- 1 while orange, (th - s) / (th - tl) while yellow or green, 0 once grey. 0 below r too (not
--- craftable yet; Crafts skips those ranks rather than stopping). A missing tl is orange until
--- th; a missing th is orange throughout. Pure.
function Model.Chance(recipe, s)
  if type(recipe) ~= "table" then
    return 0
  end
  s = number(s) or 0
  local r = number(recipe.r) or 1
  local tl, th = number(recipe.tl), number(recipe.th)
  if s < r then
    return 0
  end
  if th == nil then
    return 1
  end
  if s >= th then
    return 0
  end
  if tl == nil or s < tl or th <= tl then
    return 1
  end
  return (th - s) / (th - tl)
end

--- Brief PR9: the expected crafts to climb from rank a to rank b (b not included): the sum of
--- 1 / Chance over the ranks, skipping those below r, stopping at grey. Rounded up. Pure.
function Model.Crafts(recipe, a, b)
  if type(recipe) ~= "table" then
    return 0
  end
  a, b = math.floor(number(a) or 0), math.floor(number(b) or 0)
  local r = number(recipe.r) or 1
  local total = 0
  for s = a, b - 1 do
    if s >= r then
      local p = Model.Chance(recipe, s)
      if p <= 0 then
        break
      end
      total = total + 1 / p
    end
  end
  -- The small allowance keeps a sum like 44 + 5.0000000001 from float noise rounding up to 50.
  return math.ceil(total - 1e-9)
end

--- Brief PR49b: the skill points a recipe can give climbing from rank a to rank b (b not
--- included): the ranks Model.Crafts counts, from r, stopping at grey. 0 where it gives none (grey
--- at a, or learnt only at b or later): such a recipe is never Recommended. Pure.
function Model.Points(recipe, a, b)
  if type(recipe) ~= "table" then
    return 0
  end
  a, b = math.floor(number(a) or 0), math.floor(number(b) or 0)
  local r = number(recipe.r) or 1
  local points = 0
  for s = math.max(a, r), b - 1 do
    if Model.Chance(recipe, s) <= 0 then
      break
    end
    points = points + 1
  end
  return points
end

--- Brief PR49b: whether a recipe gives any point from rank a to rank b (Model.Points above 0),
--- in one Chance: its first rank there, max(a, r), is below b and not grey. Pure.
function Model.HasPoints(recipe, a, b)
  if type(recipe) ~= "table" then
    return false
  end
  local s = math.max(math.floor(number(a) or 0), number(recipe.r) or 1)
  return s < math.floor(number(b) or 0) and Model.Chance(recipe, s) > 0
end

-- Brief PR49b: the live re-rank's constants. A day of a cooldown recipe is worth DAY_COPPER (1
-- gold, the Bar's worth of a day), so a bought pattern beats a month of cooldowns. The data's
-- cd / ccd (a recipe's cooldown and its category cooldown) are milliseconds, the client's own
-- SpellCooldowns unit; COOLDOWN_DAY_MS is one day of them.
Model.DAY_COPPER = 10000
Model.COOLDOWN_DAY_MS = 86400000

--- Brief PR49b: the items a cooldown recipe makes, { [itemId] = days of cooldown per item }: a
--- recipe with an out and a cd or ccd above 0 (the larger), over its out count of 1. An older
--- tracks file (or one with no cooldown recipe) answers an empty table. Kept per recipes table;
--- callers only read it. Pure.
local cooldownCache = setmetatable({}, { __mode = "k" })

function Model.CooldownDays(recipes)
  if type(recipes) ~= "table" then
    return {}
  end
  -- The shipped recipes never change in a session: one pass a recipes table, kept weakly.
  local held = cooldownCache[recipes]
  if held then
    return held
  end
  local out = {}
  cooldownCache[recipes] = out
  for _, recipe in pairs(recipes) do
    if type(recipe) == "table" then
      local made = number(recipe.out)
      local ms = math.max(number(recipe.cd) or 0, number(recipe.ccd) or 0)
      if made and ms > 0 then
        local days = ms / Model.COOLDOWN_DAY_MS
        if not out[made] or days < out[made] then
          out[made] = days
        end
      end
    end
  end
  return out
end

--- Brief PR49b (the owner, 2026-10-05: "there are instances where finding it / buying it off the
--- AH is overall cheaper than other routes", "or far less time consuming"): what one card's
--- recipe costs to climb from rank a to rank b, from prices the caller hands in. opts:
---   priceOf(itemId)  copper and its source (Core/Prices.lua Prices.Value: an auction addon's
---                    label, or "vendor" for the item's vendor price), or nil
---   known            true where the player has learnt the recipe (no pattern to buy)
---   cooldowns        Model.CooldownDays of the line
--- The cost is crafts x (the sum over reagents of count x price) + the pattern's auction price
--- (learn drop or vendor, not known, its first teaching item; a vendor price never counts, it
--- is what a pattern sells for, not what it costs) + the days of cooldowns its reagents take x
--- DAY_COPPER. Answers { crafts, points, copper, perPoint, days, priced, auction, cooldown }:
--- priced false where any reagent has no price (the band then keeps the compile's order),
--- auction true where an auction addon answered any of it, cooldown { item, count, days } for the
--- first cooldown reagent. nil for a recipe giving no points from a to b. Pure.
function Model.RouteCost(recipe, a, b, opts)
  if type(recipe) ~= "table" then
    return nil
  end
  opts = type(opts) == "table" and opts or EMPTY
  local points = Model.Points(recipe, a, b)
  if points <= 0 then
    return nil
  end
  local crafts = Model.Crafts(recipe, a, b)
  local priceOf = type(opts.priceOf) == "function" and opts.priceOf or nil
  local cooldowns = type(opts.cooldowns) == "table" and opts.cooldowns or EMPTY
  local out = { crafts = crafts, points = points, copper = 0, days = 0, priced = priceOf ~= nil, auction = false }
  local perCraft = 0
  for _, reagent in ipairs(type(recipe.re) == "table" and recipe.re or EMPTY) do
    local itemId = type(reagent) == "table" and number(reagent[1]) or nil
    if itemId then
      local count = number(reagent[2]) or 1
      local copper, source = nil, nil
      if priceOf then
        copper, source = priceOf(itemId)
      end
      copper = number(copper)
      if copper then
        perCraft = perCraft + count * copper
        if source ~= nil and source ~= "vendor" then
          out.auction = true
        end
      else
        out.priced = false
      end
      local days = number(cooldowns[itemId])
      if days and days > 0 then
        local need = crafts * count
        out.days = out.days + need * days
        if not out.cooldown then
          out.cooldown = { item = itemId, count = need, days = need * days }
        end
      end
    end
  end
  out.copper = crafts * perCraft
  local learn = recipe.learn
  local teacher = type(recipe.by) == "table" and number(recipe.by[1]) or nil
  if priceOf and opts.known ~= true and teacher and (learn == "drop" or learn == "vendor") then
    local copper, source = priceOf(teacher)
    copper = number(copper)
    if copper and source ~= nil and source ~= "vendor" then
      out.copper = out.copper + copper
      out.pattern = copper
      out.auction = true
    end
  end
  out.copper = out.copper + out.days * Model.DAY_COPPER
  out.perPoint = out.copper / points
  return out
end

--- Brief PR49b: a re-planned band's live order. entries are { spell, cost } (cost
--- Model.RouteCost's) in the compile's order, the pick first. Where every entry is priced and an
--- auction addon answered at least one, they are sorted by cost per expected point, cheapest
--- first, a tie keeping the compile's order; otherwise the compile's order stands. Answers the
--- order (a new list) and whether it differs from the compile's. Pure.
function Model.Rerank(entries)
  local out, auction = {}, false
  for index, entry in ipairs(type(entries) == "table" and entries or EMPTY) do
    local cost = type(entry) == "table" and entry.cost or nil
    if type(cost) ~= "table" or cost.priced ~= true or number(cost.perPoint) == nil then
      local same = {}
      for i, kept in ipairs(entries) do
        same[i] = kept
      end
      return same, false
    end
    auction = auction or cost.auction == true
    out[#out + 1] = { entry = entry, index = index }
  end
  if not auction then
    local same = {}
    for i, kept in ipairs(out) do
      same[i] = kept.entry
    end
    return same, false
  end
  table.sort(out, function(x, y)
    local px, py = x.entry.cost.perPoint, y.entry.cost.perPoint
    if px ~= py then
      return px < py
    end
    return x.index < y.index
  end)
  local changed = false
  for index, kept in ipairs(out) do
    if kept.index ~= index then
      changed = true
    end
    out[index] = kept.entry
  end
  return out, changed
end

--- Brief PRX (PR44, the owner 2026-10-04): what each of a band's route recipes would take ALONE to
--- climb the points left in the band, from max(rank, lo) to hi (Model.Crafts, the PR9 curve):
--- { { spell, crafts, recipe } } in route order (as Track draws them), crafts above 0 only; the
--- other side's recipes are left out. A band whose route lists one recipe that still gives points
--- has a plan: that recipe, its crafts. Where two or more still do, the route data holds no split
--- between them (they share one start: the 1 to 50 Cooking band lists eight interchangeable
--- recipes), so each is an alternative and the band needs the most any one of them needs. Pure.
function Model.BandCrafts(band, recipes, rank, faction)
  local out = {}
  if type(band) ~= "table" then
    return out
  end
  recipes = type(recipes) == "table" and recipes or EMPTY
  local lo, hi = number(band.lo) or 0, number(band.hi) or 0
  local from = math.max(number(rank) or 0, lo)
  for _, entry in ipairs((routeEntries(band, recipes, faction))) do
    local crafts = Model.Crafts(entry.recipe, from, hi)
    if crafts > 0 then
      out[#out + 1] = { spell = entry.node.spell, crafts = crafts, recipe = entry.recipe }
    end
  end
  return out
end

-- The skill rank from a number or a { rank } skill entry. Pure.
local function rankOf(skill)
  if type(skill) == "table" then
    return number(skill.rank) or 0
  end
  return number(skill) or 0
end

--- Brief PRX (PR44): one craft line's needs over every band still ahead of (or around) the rank:
--- { needs = { [itemId] = n }, parts = { [itemId] = { { lo, hi, spell, crafts, per, need } } },
--- plans = { [lo] = { pick, crafts } } }. A band counts only its points left (from max(rank, lo));
--- a reagent's band need is the most any one of the band's route recipes needs alone
--- (Model.BandCrafts), never their sum, and a reagent's need is the sum of its bands' needs. parts
--- name the recipe each band's need comes from (the first in route order on a tie). A band's plan
--- pick is its one route recipe still giving points, nil where several are alternatives. skill is
--- the rank or { rank }. Teaching items are not here (Model.Needed adds them). Brief BQ18: gathers,
--- the player's gathering lines (Model.Gathers), plans each band through Model.PlayerBand. Pure.
function Model.LinePlan(line, skill, faction, gathers)
  local out = { needs = {}, parts = {}, plans = {} }
  if type(line) ~= "table" or line.kind == "gather" then
    return out
  end
  local rank = rankOf(skill)
  local recipes = type(line.recipes) == "table" and line.recipes or EMPTY
  for _, band in ipairs(type(line.bands) == "table" and line.bands or EMPTY) do
    band = Model.PlayerBand(band, gathers)
    local lo, hi = number(band.lo) or 0, number(band.hi) or 0
    -- Brief TP1 (the owner's option A): a tracked range plans its own band alone (Model.InWindow).
    if hi > rank and Model.InWindow(lo, hi, skill) then
      local steps = Model.BandCrafts(band, recipes, rank, faction)
      local plan = { crafts = {} }
      if #steps == 1 then
        plan.pick = steps[1].spell
      end
      -- Brief PR49b: a re-planned band's pick is the data's route[1] (Model.BandPick) while it
      -- still gives points at the rank; the rest of its route are alternatives as ever, and the
      -- band still needs the most any one of them needs, so the Keep marks hold.
      local pick = band.from == "forever" and Model.BandPick(band, recipes, faction) or nil
      if pick then
        for _, step in ipairs(steps) do
          if step.spell == pick then
            plan.pick = pick
          end
        end
      end
      -- Brief PR49b: the band's alternatives (band.alt) alone, for their cards (Model.AloneCrafts);
      -- never in the needs.
      plan.alone = {}
      for _, spell in ipairs(type(band.alt) == "table" and band.alt or EMPTY) do
        local recipe = recipes[spell]
        if type(recipe) == "table" and Model.FactionOk(recipe.fa, faction) then
          local crafts = Model.Crafts(recipe, math.max(rank, lo), hi)
          if crafts > 0 then
            plan.alone[spell] = crafts
          end
        end
      end
      out.plans[lo] = plan
      local most = {}
      for _, step in ipairs(steps) do
        plan.crafts[step.spell] = step.crafts
        for _, reagent in ipairs(type(step.recipe.re) == "table" and step.recipe.re or EMPTY) do
          local itemId = type(reagent) == "table" and number(reagent[1]) or nil
          if itemId then
            local per = number(reagent[2]) or 1
            local n = step.crafts * per
            if not most[itemId] or n > most[itemId].need then
              most[itemId] = { lo = lo, hi = hi, spell = step.spell, crafts = step.crafts, per = per, need = n }
            end
          end
        end
      end
      -- Band order for the parts, item by item (pairs order does not matter: one part a band).
      for itemId, part in pairs(most) do
        out.needs[itemId] = (out.needs[itemId] or 0) + part.need
        local parts = out.parts[itemId]
        if not parts then
          parts = {}
          out.parts[itemId] = parts
        end
        parts[#parts + 1] = part
      end
    end
  end
  return out
end

--- Brief PRX (PR44): THE route-wide need of one reagent in one craft line (a ProfessionTracks line
--- table), the one rule the Keep line and the cards read: the sum over every band still ahead of
--- (or around) the rank that uses it of (the band's points left x the PR9 crafts a point x
--- reagents a craft), the band's most needing route recipe where it lists alternatives
--- (Model.LinePlan). The owner's case: Linen Cloth at First Aid 32 is the 1 to 40 band's 8 points
--- by Linen Bandage (10 crafts of 1) and the 40 to 75 band by Heavy Linen Bandage (45 crafts of
--- 2): 100. skill is the rank or { rank }. Answers the need (0 for none) and its parts, { { lo, hi,
--- spell, crafts, per, need } } in band order. Pure.
function Model.RouteNeed(line, itemId, skill, faction, gathers)
  local id = number(itemId)
  if not id then
    return 0, {}
  end
  local plan = Model.LinePlan(line, skill, faction, gathers)
  return plan.needs[id] or 0, plan.parts[id] or {}
end

-- The pass behind Model.Needed, and the plans the cards read: Needed's table, and { [skillLine] =
-- LinePlan's plans }. Pure.
local function neededAndPlans(tracks, skills, faction)
  if type(skills) ~= "table" then
    return {}, {}
  end
  local found, plans = {}, {}
  local function add(itemId, n, candidate)
    itemId = number(itemId)
    if not itemId or n <= 0 then
      return
    end
    local held = found[itemId]
    if not held then
      found[itemId] = { need = n, near = candidate }
      return
    end
    held.need = held.need + n
    if nearer(candidate, held.near) then
      held.near = candidate
    end
  end
  -- Brief BQ18: each band as the player plans it (Model.PlayerBand).
  local gathers = Model.Gathers(skills)
  for skillLine, skill in pairs(skills) do
    local line = type(skillLine) == "number" and lineOf(tracks, skillLine) or nil
    if line and line.kind ~= "gather" and type(skill) == "table" then
      local rank = number(skill.rank) or 0
      local recipes = type(line.recipes) == "table" and line.recipes or EMPTY
      -- Brief TP1: the skill itself, so a tracked range's window (skill.top) holds in the plan.
      local plan = Model.LinePlan(line, skill, faction, gathers)
      plans[skillLine] = plan.plans
      -- Each reagent's parts name their bands; the nearest is the lowest band still ahead.
      for itemId, parts in pairs(plan.parts) do
        for _, part in ipairs(parts) do
          add(itemId, part.need, { skillLine = skillLine, lo = part.lo, hi = part.hi, ahead = true })
        end
      end
      -- Teaching items count once a line however many bands their recipe sits in.
      local teach = {}
      for _, band in ipairs(type(line.bands) == "table" and line.bands or EMPTY) do
        band = Model.PlayerBand(band, gathers)
        local lo, hi = number(band.lo) or 0, number(band.hi) or 0
        if hi > rank and Model.InWindow(lo, hi, skill) then
          local candidate = { skillLine = skillLine, lo = lo, hi = hi, ahead = true }
          for _, spell in ipairs(type(band.route) == "table" and band.route or EMPTY) do
            local recipe = recipes[spell]
            if type(recipe) == "table" and Model.FactionOk(recipe.fa, faction) then
              local th = number(recipe.th)
              if th == nil or rank < th then
                for _, teacher in ipairs(type(recipe.by) == "table" and recipe.by or EMPTY) do
                  local itemId = number(teacher)
                  if itemId and not teach[itemId] then
                    teach[itemId] = candidate
                  end
                end
              end
            end
          end
        end
      end
      for itemId, candidate in pairs(teach) do
        add(itemId, 1, candidate)
      end
    end
  end
  local out = {}
  for itemId, entry in pairs(found) do
    local near = entry.near
    out[itemId] = { skillLine = near.skillLine, need = entry.need, lo = near.lo, hi = near.hi }
  end
  return out, plans
end

--- Brief PR9: how many of each item the player's routes still need, "until the route moves on":
--- enough crafts to finish every band ahead of (or around) the player, from the player's rank.
--- Brief PRX (PR44): each line's need is Model.RouteNeed's rule (Model.LinePlan): a band's route
--- recipes are alternatives, so a band needs the most any one of them needs; bands (and lines)
--- add up. A teaching item needs 1 while its recipe is not grey. { [itemId] =
--- { skillLine, need, lo, hi } }, lo and hi the nearest band that needs it, and skillLine the
--- nearest line's where several lines need the item. Pure.
function Model.Needed(tracks, skills, faction)
  local out = neededAndPlans(tracks, skills, faction)
  return out
end

--- The player's profession lines and ranks as one stable string, "164:120,185:40", for cache
--- keys. "-" for none, "?" where the skills are not known. Brief TP1: a tracked entry (tracked =
--- true, Core/TrackedProfessions.lua) is marked "t", "197:55t". Pure.
function Model.Signature(skills)
  if type(skills) ~= "table" then
    return "?"
  end
  local ids = {}
  for id, skill in pairs(skills) do
    if type(id) == "number" and type(skill) == "table" then
      ids[#ids + 1] = id
    end
  end
  if #ids == 0 then
    return "-"
  end
  table.sort(ids)
  local parts = {}
  for index, id in ipairs(ids) do
    parts[index] = id .. ":" .. tostring(number(skills[id].rank) or 0) .. (skills[id].tracked == true and "t" or "")
  end
  return table.concat(parts, ",")
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

-- Seconds a burst of skill events is folded into one check. Skill ups come one or two a craft.
Model.THROTTLE = 1
-- The events that can move the player's professions or ranks: UI/Frame.lua's SKILL_EVENTS (less
-- PLAYER_ENTERING_WORLD, which cannot change a rank) and CHAT_MSG_SKILL, the skill up line.
Model.EVENTS = { "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "LEARNED_SPELL_IN_TAB" }

-- set: the Relevant set built; signature: the facts it was built for; dirty: rebuild on next
-- read; pending: a check is queued.
Model.state = { dirty = true }

function Model.ResetState()
  Model.state = { dirty = true }
end

local FACTIONS = { Alliance = Model.ALLIANCE, Horde = Model.HORDE }

local function frame()
  local ui = ItemTree.UI
  local found = type(ui) == "table" and ui.Frame or nil
  if type(found) == "table" then
    return found
  end
  return nil
end

local function playerSkills()
  local window = frame()
  if not window or type(window.PlayerSkills) ~= "function" then
    return {}
  end
  local ok, skills = pcall(window.PlayerSkills)
  if ok and type(skills) == "table" then
    return skills
  end
  return {}
end

local function playerFaction()
  -- Brief BQ14 follow up: the pretend side (Core/Demo.lua) while it is set.
  local demo = ItemTree.Demo
  if type(demo) == "table" and type(demo.FactionWord) == "function" then
    local read, pretend = pcall(demo.FactionWord)
    if read and pretend then
      return FACTIONS[pretend]
    end
  end
  local ask = rawget(_G, "UnitFactionGroup")
  if type(ask) ~= "function" then
    return nil
  end
  local ok, word = pcall(ask, "player")
  return ok and FACTIONS[word] or nil
end

local function tracks()
  local found = ItemTree.ProfessionTracks
  if type(found) == "table" then
    return found
  end
  return nil
end

-- Brief TP1 (the owner's QA item 210, ruling A of 2026-10-17): the player's skills with the
-- professions the character tracks at a range joined (Core/TrackedProfessions.lua Tracked.Skills:
-- { rank = the range's bottom, top = its top, lo, hi, tracked = true }), a new table where any join,
-- the player's own entry always winning. The route, its counts and the working stock then hold a
-- tracked profession as if the character had it at that skill, its range's own band alone (the
-- owner's option A, Model.InWindow). The window's own Frame.PlayerSkills is never written: it stays
-- the client's answer for everything that says what the character HAS.
function Model.WithTracked(skills)
  local tracked = ItemTree.TrackedProfessions
  if type(skills) ~= "table" or type(tracked) ~= "table" or type(tracked.Skills) ~= "function" then
    return skills
  end
  local ok, extra = pcall(tracked.Skills, skills)
  if not ok or type(extra) ~= "table" or type(tracked.Join) ~= "function" then
    return skills
  end
  return tracked.Join(skills, extra)
end

--- The player's skills and side now, and the signature they make. Two questions about the
--- player, none about an item. Brief TP1: the skills carry the tracked professions (Model.WithTracked).
function Model.Facts()
  local skills, faction = Model.WithTracked(playerSkills()), playerFaction()
  return skills, faction, Model.Signature(skills) .. "|" .. tostring(faction)
end

--- The player's Relevant set, built on the first read after it went stale and kept until then.
function Model.Current()
  local state = Model.state
  if state.set and not state.dirty then
    -- A set built from no skills at all (the client can answer empty at login) is only kept
    -- while the player still reads empty; the first read that finds a profession rebuilds.
    if not (state.empty and next(playerSkills()) ~= nil) then
      return state.set
    end
  end
  local skills, faction, signature = Model.Facts()
  local data = tracks()
  state.set = Model.Relevant(data, skills, faction)
  -- Brief PR9: the same facts, the same pass. Each Relevant entry carries its need, so Keep's
  -- route entry has it with no second lookup.
  -- Brief PRX: and the band plans the cards read (Model.PlanCrafts).
  state.needed, state.plans = neededAndPlans(data, skills, faction)
  -- Brief BQ18: the gathering lines the pass planned with, for Model.Track's cards.
  state.gathers = Model.Gathers(skills)
  for itemId, entry in pairs(state.set) do
    local needed = state.needed[itemId]
    if needed then
      entry.need = needed.need
    end
  end
  state.signature = signature
  state.empty = next(skills) == nil
  state.dirty = false
  return state.set
end

--- Brief PR9: the player's need for one item, { skillLine, need, lo, hi }, or nil. A lookup in
--- the cached pass; the bag count is the caller's, for the one item it shows.
function Model.NeededFor(itemId)
  local id = number(itemId)
  if not id then
    return nil
  end
  Model.Current()
  local needed = Model.state.needed
  local entry = type(needed) == "table" and needed[id] or nil
  if type(entry) == "table" then
    return entry
  end
  return nil
end

--- Brief PRX (PR44): the crafts of the player's plan for one card: the recipe is the plan pick of
--- the band starting at lo in a line (its one route recipe still giving points, Model.LinePlan),
--- from the cached pass at the player's rank; nil for a done band, a band of alternatives, or any
--- other recipe.
function Model.PlanCrafts(skillLine, lo, spell)
  Model.Current()
  local plans = Model.state.plans
  local line = type(plans) == "table" and plans[number(skillLine)] or nil
  local band = type(line) == "table" and line[number(lo)] or nil
  local id = number(spell)
  if type(band) ~= "table" or id == nil or band.pick ~= id then
    return nil
  end
  local crafts = number(band.crafts[id])
  if crafts and crafts > 0 then
    return crafts
  end
  return nil
end

--- Brief PR46 (the owner's QA, 2026-10-05): the crafts any route recipe of the band starting at
--- lo would take ALONE to climb the band's points left at the player's rank (Model.BandCrafts, the
--- same figure the alone hover words and the band part the Keep line sums, Model.LinePlan): the
--- plan pick's crafts too, and each alternative's own where the band lists several. From the
--- cached pass; nil for a done band, a recipe that gives no points, an off route recipe or any
--- other line.
function Model.AloneCrafts(skillLine, lo, spell)
  Model.Current()
  local plans = Model.state.plans
  local line = type(plans) == "table" and plans[number(skillLine)] or nil
  local band = type(line) == "table" and line[number(lo)] or nil
  local id = number(spell)
  if type(band) ~= "table" or id == nil or type(band.crafts) ~= "table" then
    return nil
  end
  -- Brief PR49b: a re-planned band's alternative (band.alt) answers its own crafts alone too.
  local crafts = number(band.crafts[id]) or (type(band.alone) == "table" and number(band.alone[id]) or nil)
  if crafts and crafts > 0 then
    return crafts
  end
  return nil
end

--- The signature the current set was built for, for Keep's cache key.
function Model.CurrentSignature()
  Model.Current()
  return Model.state.signature
end

-- Drops Keep's scores and paints the bags and the tooltip again, through Keep's own calls
-- (Keep.DropScores, Keep.Repaint: UI/Tooltip.lua ClearCache, UI/Overlay.lua Forget and Queue).
local function refresh()
  local keep = ItemTree.Keep
  if type(keep) ~= "table" then
    return false
  end
  if type(keep.DropScores) == "function" then
    pcall(keep.DropScores)
  end
  if type(keep.Repaint) == "function" then
    pcall(keep.Repaint)
  end
  return true
end
Model.Refresh = refresh

--- The queued check: where the player's facts no longer match the set built, the set goes stale
--- (rebuilt on the next read) and Keep repaints. Answers whether anything moved.
function Model.Flush()
  local state = Model.state
  state.pending = false
  if not state.set then
    state.dirty = true
    return false
  end
  local _, _, signature = Model.Facts()
  if signature == state.signature then
    return false
  end
  state.dirty = true
  refresh()
  return true
end

local EVENT_SET = {}
for _, event in ipairs(Model.EVENTS) do
  EVENT_SET[event] = true
end

--- A skill event: the window's skill cache is dropped (CHAT_MSG_SKILL is not one of its own
--- events) and one check is queued THROTTLE seconds on, however many events come in between.
--- Answers whether a check was queued or run now.
function Model.OnEvent(event)
  if not EVENT_SET[event] then
    return false
  end
  local window = frame()
  if window and type(window.InvalidateSkills) == "function" then
    pcall(window.InvalidateSkills)
  end
  local state = Model.state
  if state.pending then
    return false
  end
  local timer = rawget(_G, "C_Timer")
  local after = type(timer) == "table" and timer.After or nil
  if type(after) == "function" then
    state.pending = true
    if pcall(after, Model.THROTTLE, Model.Flush) then
      return true
    end
    state.pending = false
  end
  Model.Flush()
  return true
end

--- The event frame, the module's own, made once where the client can make one. The module loads
--- only while the setting is on, so these events are never heard with it off.
function Model.Install()
  if Model.frame then
    return Model.frame
  end
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, events = pcall(create, "Frame")
  if not ok or type(events) ~= "table" or type(events.RegisterEvent) ~= "function" then
    return nil
  end
  for _, event in ipairs(Model.EVENTS) do
    pcall(events.RegisterEvent, events, event)
  end
  if type(events.SetScript) == "function" then
    pcall(events.SetScript, events, "OnEvent", function(_, event)
      Model.OnEvent(event)
    end)
  end
  Model.frame = events
  return events
end

Model.Install()

return Model
