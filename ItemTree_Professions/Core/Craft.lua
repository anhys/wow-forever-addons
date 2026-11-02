-- The Craft all button on a Professions band's header (brief PR14, relabelled by brief PR16 and by
-- the owner, 2026-10-02). Brief
-- PR21: a click queues every recipe of the band the player knows and has materials for,
-- recommended first, and opens the profession window beside the queue tray (UI/Queue.lua); the
-- crafting itself is the tray's. The label is always "Craft all"; the hover (UI/Pane.lua) says what
-- it does, then one coloured status line from Craft.State (the owner, 2026-10-02).
--
-- The client allows a craft only from a real press, and one call crafts N of ONE recipe. So nothing
-- here loops, nothing starts a craft from a timer, and the queue makes one craft call a press.
-- Checked on github.com/Gethe/wow-ui-source, branch forever: the Professions UI crafts with
-- C_TradeSkillUI.CraftRecipe(recipeID, count, ...) (Blizzard_ProfessionsTemplates/
-- Blizzard_ProfessionsTransaction.lua), and opens a line with C_TradeSkillUI.OpenTradeSkill
-- (Blizzard_FrameXMLUtil/ProfessionsUtil.lua). The classic DoTradeSkill(index, count) is the guarded
-- fallback, and needs the recipe in the open window's list.
--
-- Brief PR16's bug: with 14 Light Leather the button said there were no materials for Light Armor
-- Kit. The counts and the reagent rows were right (a spec runs the real ProfessionTracks rows);
-- the recipe was ruled out as not learnt. Two client answers did it: the trade skill API's learned
-- flag, which the client keeps answering for a line after its window has closed (or before it has
-- loaded the line), was taken as the truth with the window shut; and a line the API still named as
-- the last one opened counted as open where the Professions window had never been loaded, so
-- every recipe the open window "could not list" was not learnt. Now only an answer from an open
-- window can say a recipe is not learnt, and a window counts as open only when its frame shows (or,
-- with no frame to ask, between the client's own show and close events). Since 2026-10-02 the
-- spell calls answer first (Craft.KnowsRecipe): IsPlayerSpell says learnt or not, window or not. Brief PR27 (the owner,
-- 2026-10-02) caps n again, at the band's end: as many as the bags make, but only enough to take
-- the player from the rank now to the band's hi by the PR9 skill-up model.
--
--   Craft.Order(track, bandIndex)                   the band's recipes worth crafting, in order
--   Craft.LockState(colour, learnt)                 "future", "locked" or nil: the tab's padlock
--   Craft.Locked(node, known)                       the same lock for a node and a known table
--   Craft.MaxCraftable(recipe, counts)              how many the bags make, floor(min(have / need))
--   Craft.Next(track, bandIndex, counts, known)     { spell, n, node, index } or nil
--   Craft.Plan(track, bandIndex, counts, known, opts)  the queue's rows, materials shared (PR21),
--                                                   sized to reach the band's end from opts.rank
--                                                   (PR27); answers rows, reach
--   Craft.Size(node, rank, hi, most, colour)        one row's count toward hi: n, reach, why (PR27)
--   Craft.Adjust(node, rank, colour)                the node as the client's colour reads it (PR27)
--   Craft.ReachText, DoneText, StoppedText, OutOfText  the hover's reach line and the PR27 alerts
--   Craft.Rank(skillLine, fresh), Craft.ColourOf(open)  the rank and client colours now (client)
--   Craft.State(args)                               the button's state from facts handed in
--   Craft.ButtonState(skillLine, bandIndex, track)  { shown, enabled, label, status = { text, colour } }
--   Craft.Click(skillLine, bandIndex, track)        the queue tray (PR21: never a craft), from the OnClick
--   Craft.OnChange(fn)                              a listener, called after crafts and bag moves
--   Craft.Watch(on)                                 events on while the Professions pane shows
--   Craft.NoItem(track, bandIndex)                  brief SC1: the skill giving recipes left out
--                                                   for making no item (enchants)
--   Craft.ShowState(args), Craft.ShowButton(skillLine, lock, recipeName)
--                                                   brief SC1: a card's Show craft button
--   Craft.Held(skillLine), Craft.ShowCraft(skillLine, spell, recipeName)  the line is the
--                                                   character's; the click (brief PW1: it fills the
--                                                   window's search with the recipe; brief SC3:
--                                                   set just before the open call, as PW1 did)
--   Craft.RecipeClientName(spell, fallback), Craft.FillCheck(recipeName, skillLine, spell),
--   Craft.WouldFill(recipeName, skillLine, spell)   brief PW1 / SC2: whether a click fills
--   Craft.FillBeforeOpen(spell, recipeName)         brief SC3: the fill, made before the open
--   Craft.OnWindowEvent(event), Craft.TakeBack(why) brief SC2 / SC3: the click's show and the take
--                                                   back, from the client's own trade skill events
--   Craft.FillRoute(skillLine, held), Craft.ReopenInClick(), Craft.SameSearch(current, name)
--                                                   brief SC5 (QA items 284 and 289): the window's
--                                                   state a click meets, whether the client answered
--                                                   our close inside the call, the client's compare
--   Craft.WindowLine(), Craft.WatchWindow()         brief SC2: the line the client's page last showed
--   Craft.ShowsLine(skillLine)                      brief SC2: the window shows the line's recipes now
--   Craft.ViewState(args), Craft.ViewButton(skillLine),
--   Craft.ViewProfession(skillLine)                 brief SC2 (QA item 263): View profession
--   Craft.TraceLine(trace, at), Craft.DebugLines()  brief SC2: /itemtree debug's last clicks
--
-- Brief PR18: Create all opens the craft queue tray (UI/Queue.lua Queue.OpenFor) with the band's
-- queue. Brief PR21 (QA round 5): it no longer starts anything. It builds the queue, opens the
-- profession window (brief PR39: the ItemTree window stays open) and waits; each craft is the player's own press of
-- the tray's Start craft queue (then Craft next) or the key binding. Proven in game on 2026-10-01:
-- CraftRecipe starts nothing with the profession window shut, and a call chained from the
-- completion event is ADDON_ACTION_BLOCKED. The hover is two or three plain lines. The UI source
-- (branch forever) gives CraftRecipe no hardware or restriction flag
-- (Blizzard_APIDocumentationGenerated/TradeSkillUIDocumentation.lua:
-- only SecretArguments "AllowedWhenUntainted"), the client's own Create All is one CraftRecipe call
-- with a count, and its completion events are TRADE_SKILL_CRAFT_BEGIN, TRADE_SKILL_ITEM_CRAFTED_RESULT
-- and UPDATE_TRADESKILL_CAST_STOPPED beside the UNIT_SPELLCAST ones (no CAST_COMPLETE). Whether a
-- craft may start from an event, and whether it needs the window open, is the client's to say:
--   Craft.AutoChain(), Craft.SetAutoChain(answer, save)   true only once proved; nil: unknown
--   Craft.NeedsWindow(), Craft.SetNeedsWindow(answer, save)  true unless a craft started shut
--   Craft.Open(skillLine, force)                    one OpenTradeSkill, never twice in OPEN_GAP
--   Craft.Probe(rest)                               /itemtree craftprobe <spell id>, developer only
--
-- Loaded after Core\Professions.lua (the model) and before Module.lua, which hands this table out
-- as ItemTree.Professions.craft.
local _, ItemTree = ...
-- ItemTree_Professions is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Modules) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end

local Craft = {}
ItemTree.ProfessionsCraft = Craft

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

Craft.WORDS = {
  -- The owner, 2026-10-02: the button reads "Craft all".
  label = L["Craft all"],
  -- The owner, 2026-10-02 (QA on the hover): one short status line under the hover's body, its
  -- colour by state (Craft.STATUS_COLOURS).
  noMaterials = L["Not enough materials"],
  grey = L["Nothing here gives skill any more"],
  done = L["This level is done"],
  combat = L["Not in combat"],
  reach = L["Enough to reach %d"],
  about = L["Gets you to about %d of %d"],
  -- The queue tray's reason where the materials are only in the bank (UI\Queue.lua).
  bank = L["Nothing to make for this level yet: the materials are in your bank, not your bags."],
  -- Brief PR27: the alerts the queue tray shares.
  levelDone = L["This level is done."],
  levelNext = L["This level is done. Use Craft all on %d to %d."],
  stopped = L["Stopped: you reached %s %d, the end of this level."],
  outOfLevel = L["Out of materials for this level: %s %d of %d."],
  profession = L["Profession"],
  item = L["Item %d"],
  spell = L["Spell %d"],
  -- Brief SC1 (QA item 212, an enchanter: "cant click craft all"): why the button leaves out a
  -- recipe that makes no item, and the reasons it cannot queue that were missing or wrong.
  noItemNote = L["Recipes that make no item, such as enchants, are left out: use them from the profession window."],
  noItemOnly = L["Nothing here makes an item to queue"],
  notLearnt = L["You have not learnt the item recipes here"],
}

-- Brief SC1 (QA item 212, the owner: "a 'Show craft' button bottom right (small standard red
-- button) that opens the profession tab to the recipe/craft"): the card button's words.
Craft.SHOW_WORDS = {
  label = L["Show craft"],
  how = L["Opens the %s window. Find %s in its list."],
  -- Brief PW1 (QA item 239 c): where the click fills the window's search with the recipe.
  fill = L["Opens the %s window on %s."],
  howLine = L["Opens the %s window."],
  demo = L["Not with demo professions"],
  notHeld = L["You do not have %s"],
  locked = L["You have not learnt this recipe yet"],
  -- Brief SC2 (QA item 262, "clicking it did nothing"): the window already shows the line, so a
  -- click only brings it in front; its search is the player's own and is never changed there.
  open = L["The %s window is open. Find %s in its list."],
  openLine = L["The %s window is open."],
  -- Brief SC5 (QA items 284 and 289, the owner's change of 2026-10-20): the words say what THIS
  -- click does, from the window's state, on every Show craft button of the route. "Find recipe"
  -- where the click is a step first: it opens the window on the line unsearched ("first"), or
  -- closes the window up on the line where the client will not answer our close inside the call
  -- ("ready"); the next click is Show craft and lands on the recipe.
  findLabel = L["Find recipe"],
  first = L["Opens the %s window first. Then Show craft finds %s."],
  ready = L["Readies the %s window. Then Show craft finds %s."],
}

-- Brief SC2 (QA item 263, the owner: "To the left of trainers and vendors add a button that says
-- "View profession" to open the native profession tab to that profession (standard open not to a
-- specific place)"): the route header's button. Its body is Show craft's own "Opens the %s window."
Craft.VIEW_WORDS = {
  label = L["View profession"],
}

local number = ItemTree.Util.Number
-- Brief SV1: whether a client value may be read (Core/Util.lua Util.CanRead): a cast event's
-- payload can be secret on the Forever client.
local canRead = ItemTree.Util.CanRead

local function bandOf(track, bandIndex)
  local bands = type(track) == "table" and track.bands or nil
  local band = type(bands) == "table" and bands[number(bandIndex)] or nil
  if type(band) == "table" then
    return band
  end
  return nil
end

--- The band's recipes worth crafting, in the order Track gives its nodes: the route first in its
--- order, then the rest. Grey and unlearnable recipes give no skill and are left out, and so is a
--- recipe that makes no item (an enchant needs a target the button cannot give). Pure.
function Craft.Order(track, bandIndex)
  local band = bandOf(track, bandIndex)
  local out = {}
  if not band then
    return out
  end
  for _, node in ipairs(type(band.nodes) == "table" and band.nodes or EMPTY) do
    if type(node) == "table" and node.colour ~= "grey" and node.colour ~= "unlearnable" and node.out ~= nil then
      out[#out + 1] = node
    end
  end
  return out
end

--- Brief SC1 (QA item 212, an enchanter: "cant click craft all"): how many of the band's recipes
--- that still give skill make no item (an enchant, an engineer's tinker, a campfire), each one
--- Craft.Order leaves out: it needs a target the button cannot give. The client's own window
--- crafts an enchant with C_TradeSkillUI.CraftEnchant and, as its target, the item the player
--- picked in the window (branch forever, Blizzard_Professions/Blizzard_ProfessionsCrafting.lua:
--- 1074-1079 and Blizzard_ProfessionsTemplates/Blizzard_ProfessionsTransaction.lua:358-360). Grey
--- and unlearnable recipes give no skill and are not counted. Pure.
function Craft.NoItem(track, bandIndex)
  local band = bandOf(track, bandIndex)
  local count = 0
  for _, node in ipairs(band and type(band.nodes) == "table" and band.nodes or EMPTY) do
    if type(node) == "table" and node.colour ~= "grey" and node.colour ~= "unlearnable" and node.out == nil then
      count = count + 1
    end
  end
  return count
end

--- Brief PR24: THE lock rule, one helper for the tab's padlock (UI\Pane.lua Pane.LockState, the
--- red cards) and for everything Create all queues (Craft.Plan, Craft.Next, UI\Queue.lua
--- Queue.Build), so the two never disagree. From the recipe's colour at the player's rank (the
--- model's "unlearnable" where the rank is below its r) and whether the player has learnt it (true,
--- false, or nil where nothing the client holds can say; Craft.KnowsRecipe):
---   "future"   r above the rank: not learnable yet, out of range.
---   "locked"   r at or below the rank but not learnt.
---   nil        learnt, or unknown: not locked.
--- Pure.
function Craft.LockState(colour, learnt)
  if colour == "unlearnable" then
    return "future"
  end
  if colour ~= nil and learnt == false then
    return "locked"
  end
  return nil
end

--- Brief PR24: a node's lock (Craft.LockState) by a known table as Craft.Known answers it
--- ({ [spell] = true }, a missing spell not learnt); known nil counts every recipe as learnt. Pure.
function Craft.Locked(node, known)
  if type(node) ~= "table" then
    return nil
  end
  local learnt = nil
  if type(known) == "table" then
    learnt = known[node.spell] == true
  elseif known ~= nil then
    learnt = false
  end
  return Craft.LockState(node.colour, learnt)
end

--- How many crafts the counts make: floor(min(have / need)) over the reagents. 0 for a recipe
--- with no reagents listed. counts is { [itemId] = n }; a reagent row is { itemId, count }, a
--- missing count meaning one. Pure.
function Craft.MaxCraftable(recipe, counts)
  local reagents = type(recipe) == "table" and recipe.re or nil
  if type(reagents) ~= "table" or #reagents == 0 then
    return 0
  end
  counts = type(counts) == "table" and counts or EMPTY
  local best = nil
  for _, reagent in ipairs(reagents) do
    local itemId = type(reagent) == "table" and number(reagent[1]) or nil
    local need = type(reagent) == "table" and (number(reagent[2]) or 1) or 1
    if not itemId or need <= 0 then
      return 0
    end
    local makes = math.floor((number(counts[itemId]) or 0) / need)
    if best == nil or makes < best then
      best = makes
    end
  end
  return math.max(best or 0, 0)
end

--- The first recipe in the band's order the player knows and has materials for, with n all the
--- crafts the bags make (brief PR16: as many as possible, no cap). { spell, n, node, index }
--- (index its place in Order) or nil. known is { [spell] = true }; nil counts every recipe as
--- known. Pure.
function Craft.Next(track, bandIndex, counts, known)
  if not bandOf(track, bandIndex) then
    return nil
  end
  for index, node in ipairs(Craft.Order(track, bandIndex)) do
    if Craft.Locked(node, known) == nil then
      local most = Craft.MaxCraftable(node, counts)
      if most >= 1 then
        return { spell = node.spell, n = most, node = node, index = index }
      end
    end
  end
  return nil
end

--- The name a recipe goes by: the data's spell name, else what it makes, else "Spell 1234". Pure.
function Craft.Name(names, node)
  names = type(names) == "table" and names or EMPTY
  local spell = number(type(node) == "table" and node.spell or nil) or 0
  local own = names[-spell]
  if type(own) == "string" and own ~= "" then
    return own
  end
  local out = type(node) == "table" and number(node.out) or nil
  local made = out and names[out] or nil
  if type(made) == "string" and made ~= "" then
    return made
  end
  return string.format(Craft.WORDS.spell, spell)
end

-- The Professions model's table (Core\Professions.lua), for its pure Colour, Chance and Crafts.
local function modelTable()
  local found = ItemTree.ProfessionsModel
  if type(found) == "table" then
    return found
  end
  return nil
end

-- Brief PR27: the client's TradeskillRelativeDifficulty as a colour (TradeSkillUITypesDocumentation,
-- branch forever: Optimal 0, Medium 1, Easy 2, Trivial 3).
Craft.DIFFICULTY_COLOUR = { [0] = "orange", [1] = "yellow", [2] = "green", [3] = "grey" }

--- Brief PR27: a recipe's colour by the client's own TradeSkillRecipeInfo (relativeDifficulty), or
--- nil where it says nothing. Pure.
function Craft.ClientColour(info)
  if type(info) ~= "table" then
    return nil
  end
  return Craft.DIFFICULTY_COLOUR[number(info.relativeDifficulty)]
end

--- Brief PR27: the node as the skill-up model should read it at rank where the client's colour
--- (orange, yellow, green or grey; nil: none) disagrees with the data's. Yellow and green share one
--- curve, so only orange against not orange, and grey, matter: the client's orange makes the rank
--- orange (yellow from the next), its yellow or green over the data's orange makes the curve start
--- now, and over the data's grey gives one more rank. Answers the node, or a changed copy. Pure.
function Craft.Adjust(node, rank, colour)
  local m = modelTable()
  if type(node) ~= "table" or colour == nil or colour == "grey" or not m then
    return node
  end
  rank = math.floor(number(rank) or 0)
  local data = m.Colour(node, rank)
  local clientOrange, dataOrange = colour == "orange", data == "orange"
  if clientOrange == dataOrange and data ~= "grey" then
    return node
  end
  local copy = {}
  for key, value in pairs(node) do
    copy[key] = value
  end
  local th = number(node.th)
  if clientOrange then
    copy.tl = rank + 1
    if th ~= nil and th <= copy.tl then
      copy.th = nil
    end
  elseif dataOrange then
    copy.tl = rank
  else
    copy.th = rank + 1
    if number(copy.tl) == nil or number(copy.tl) > rank then
      copy.tl = rank
    end
  end
  return copy
end

--- Brief PR27: how many of one recipe to queue from rank, toward hi, with most the crafts the
--- materials make: n = min(most, the crafts still needed), by the PR9 model (Model.Crafts): orange
--- gives exactly one point a craft, yellow and green the expected crafts rounded up. colour is the
--- client's (Craft.Adjust), nil for the data's. Answers n, the rank the n crafts are expected to
--- reach (whole ranks whose expected crafts fit in n), and why it stopped short: "reached" (rank at
--- hi), "grey" (no skill left in it), "materials" (fewer than needed), or nil. With no rank or no
--- hi, n is most and nothing is capped. Pure.
function Craft.Size(node, rank, hi, most, colour)
  most = math.max(math.floor(number(most) or 0), 0)
  rank, hi = number(rank), number(hi)
  local m = modelTable()
  if rank == nil or hi == nil or not m then
    return most, rank, nil
  end
  rank = math.floor(rank)
  if rank >= hi then
    return 0, rank, "reached"
  end
  if colour == "grey" then
    return 0, rank, "grey"
  end
  local adjusted = Craft.Adjust(node, rank, colour)
  local need = m.Crafts(adjusted, rank, hi)
  if need <= 0 then
    return 0, rank, "grey"
  end
  local n = math.min(most, need)
  local total, at = 0, rank
  while at < hi do
    local p = m.Chance(adjusted, at)
    if p <= 0 or total + 1 / p > n + 1e-9 then
      break
    end
    total = total + 1 / p
    at = at + 1
  end
  if n < need then
    return n, at, "materials"
  end
  return n, at, nil
end

-- The client's colour for a node by colourOf(node), pcalled; nil where there is none.
local function colourAt(colourOf, node)
  if type(colourOf) ~= "function" then
    return nil
  end
  local ok, colour = pcall(colourOf, node)
  if ok and type(colour) == "string" then
    return colour
  end
  return nil
end
Craft.ColourAt = colourAt

--- Brief PR21: the band's plan, as the queue will build it: each recipe in Craft.Order the player
--- knows (brief PR24: none Craft.Locked rules out, the tab's padlock), the materials SHARED (what an
--- earlier recipe uses is gone for the later ones), and a recipe listed twice made one row with the
--- counts summed. { { spell, n, node } } in order. known nil counts every recipe as known.
--- Brief PR27: opts { rank, hi, colourOf }: from rank (the player's now) each row is sized by
--- Craft.Size toward hi (default the band's hi), a simulated rank carried from row to row, and no
--- row is added once it reaches hi; colourOf(node) is the client's colour while its window shows.
--- Without opts.rank each row is as many as the bags make (the old rule). Answers the rows and the
--- simulated rank they reach (nil without a rank). Pure.
function Craft.Plan(track, bandIndex, counts, known, opts)
  opts = type(opts) == "table" and opts or EMPTY
  local band = bandOf(track, bandIndex)
  local rank = number(opts.rank)
  local hi = number(opts.hi) or (band and number(band.hi)) or nil
  local remaining = {}
  for itemId, have in pairs(type(counts) == "table" and counts or EMPTY) do
    remaining[itemId] = number(have) or 0
  end
  local out, bySpell = {}, {}
  for _, node in ipairs(Craft.Order(track, bandIndex)) do
    if rank ~= nil and hi ~= nil and rank >= hi then
      break
    end
    if Craft.Locked(node, known) == nil then
      local n = Craft.MaxCraftable(node, remaining)
      if n >= 1 and rank ~= nil then
        local reach
        n, reach = Craft.Size(node, rank, hi, n, colourAt(opts.colourOf, node))
        if n >= 1 then
          rank = reach
        end
      end
      if n >= 1 then
        for _, reagent in ipairs(type(node.re) == "table" and node.re or EMPTY) do
          local itemId = type(reagent) == "table" and number(reagent[1]) or nil
          if itemId then
            remaining[itemId] = (remaining[itemId] or 0) - (number(reagent[2]) or 1) * n
          end
        end
        local row = bySpell[node.spell]
        if row then
          row.n = row.n + n
        else
          row = { spell = node.spell, n = n, node = node }
          bySpell[node.spell] = row
          out[#out + 1] = row
        end
      end
    end
  end
  return out, rank
end

--- Brief PR27: the hover's reach line from the plan's simulated rank: "Enough to reach 50" or
--- "Gets you to about 43 of 50". nil without both. Pure.
function Craft.ReachText(reach, hi)
  reach, hi = number(reach), number(hi)
  if reach == nil or hi == nil then
    return nil
  end
  if reach >= hi then
    return string.format(Craft.WORDS.reach, hi)
  end
  return string.format(Craft.WORDS.about, reach, hi)
end

--- Brief PR27: the line for a band the player has finished: "This level is done. Use Craft all on
--- 50 to 100." naming the next band, or "This level is done." at the last. Pure.
function Craft.DoneText(track, bandIndex)
  local nextBand = bandOf(track, (number(bandIndex) or 0) + 1)
  if nextBand and number(nextBand.lo) and number(nextBand.hi) then
    return string.format(Craft.WORDS.levelNext, number(nextBand.lo), number(nextBand.hi))
  end
  return Craft.WORDS.levelDone
end

local function lineWord(lineName)
  if type(lineName) == "string" and lineName ~= "" then
    return lineName
  end
  return Craft.WORDS.profession
end

--- Brief PR27: "Stopped: you reached Cooking 50, the end of this level." Pure.
function Craft.StoppedText(lineName, hi)
  return string.format(Craft.WORDS.stopped, lineWord(lineName), number(hi) or 0)
end

--- Brief PR27: "Out of materials for this level: Cooking 43 of 50." Pure.
function Craft.OutOfText(lineName, rank, hi)
  return string.format(Craft.WORDS.outOfLevel, lineWord(lineName), number(rank) or 0, number(hi) or 0)
end

--- Brief PR24: whether the band has an item recipe gone grey and none that still gives skill
--- (every one grey, or above the rank). Pure.
function Craft.AllGrey(band)
  local grey = false
  for _, node in ipairs(type(band) == "table" and type(band.nodes) == "table" and band.nodes or EMPTY) do
    if type(node) == "table" and node.out ~= nil then
      if node.colour == "grey" then
        grey = true
      elseif node.colour ~= "unlearnable" then
        return false
      end
    end
  end
  return grey
end

-- The owner, 2026-10-02: the hover's status line colours, Theme keys: red where the button cannot
-- craft (or not now), green where the bags reach the band's end, gold where they reach part of it.
Craft.STATUS_COLOURS = {
  red = "ITEMTREE_COLOR_KEEP_NO",
  green = "ITEMTREE_COLOR_KEEP_YES",
  gold = "ITEMTREE_COLOR_TEXT_TITLE",
}

local function statusLine(text, hue)
  if text == nil then
    return nil
  end
  return { text = text, colour = Craft.STATUS_COLOURS[hue] }
end

--- The button's state from facts handed in. args: track, bandIndex, counts (bags), known, combat
--- (in combat now), and (brief PR27) rank (the player's in the line now; nil: nothing is capped)
--- and colourOf (the client's colour while its window shows, Craft.Plan). Answers { shown,
--- enabled, label, status, action, spell, n, reach }: label is always "Craft all"; status is the
--- hover's one status line, { text, colour } with colour a Theme key (the owner, 2026-10-02):
--- red "Not enough materials", "Nothing here gives skill any more", "This level is done" or "Not in
--- combat"; green "Enough to reach 45"; gold "Gets you to about 43 of 50". nil where there is
--- nothing to say (no rank to reach for). action is "queue" where there is something to queue,
--- else nil. Brief PR21: a click never crafts: it builds the queue, opens the profession window and
--- the tray, and waits for the player's press. Pure.
function Craft.State(args)
  args = type(args) == "table" and args or EMPTY
  local band = bandOf(args.track, args.bandIndex)
  if not band or band.state == "done" then
    return { shown = false, enabled = false, label = Craft.WORDS.label }
  end
  local function state(enabled, status, extra)
    local out = { shown = true, enabled = enabled == true, label = Craft.WORDS.label, status = status }
    for key, value in pairs(extra or EMPTY) do
      out[key] = value
    end
    return out
  end
  local rank, hi = number(args.rank), number(band.hi)
  if rank ~= nil and hi ~= nil and rank >= hi then
    -- Brief PR27: the rank is past the band the pane last drew: nothing to queue here.
    return state(false, statusLine(Craft.WORDS.done, "red"))
  end
  -- Brief SC1 (QA item 212): where the band's skill comes partly from recipes that make no item
  -- (most of Enchanting's), the hover says they are left out (state.note).
  local note = nil
  if Craft.NoItem(args.track, args.bandIndex) > 0 then
    note = Craft.WORDS.noItemNote
  end
  local order = Craft.Order(args.track, args.bandIndex)
  if #order == 0 then
    -- Brief SC1: a band whose skill comes only from recipes that make no item (enchants) shows
    -- the faded button and says why, where it had none (an enchanter could not tell why).
    if note then
      return state(false, statusLine(Craft.WORDS.noItemOnly, "red"), { note = note })
    end
    -- Brief PR24: a band still to level through whose item recipes have all gone grey says so on
    -- the faded button; one with nothing to make at all (recipes above the rank) has none.
    if Craft.AllGrey(band) then
      return state(false, statusLine(Craft.WORDS.grey, "red"))
    end
    return { shown = false, enabled = false, label = Craft.WORDS.label }
  end
  local opts = { rank = rank, hi = hi, colourOf = args.colourOf }
  local plan, reach = Craft.Plan(args.track, args.bandIndex, args.counts, args.known, opts)
  if #plan == 0 then
    -- Brief SC1: the reason the plan is empty, where it was always "Not enough materials": no
    -- item recipe here learnt; or one learnt and made from the bags that the client's colour says
    -- gives no skill; else the materials.
    local word = Craft.WORDS.notLearnt
    for _, node in ipairs(order) do
      if Craft.Locked(node, args.known) == nil then
        if Craft.MaxCraftable(node, args.counts) >= 1 then
          word = Craft.WORDS.grey
          break
        end
        word = Craft.WORDS.noMaterials
      end
    end
    return state(false, statusLine(word, "red"), { note = note })
  end
  local status
  if args.combat == true then
    status = statusLine(Craft.WORDS.combat, "red")
  else
    local r, h = number(reach), hi
    status = statusLine(Craft.ReachText(reach, hi), (r and h and r >= h) and "green" or "gold")
  end
  return state(true, status, { action = "queue", spell = plan[1].spell, n = plan[1].n, reach = reach, note = note })
end

--- Brief SC1 (QA item 212): the Show craft button's state from facts handed in. args: held (the
--- character has the line: true, false, or nil where nothing could say, which counts as held),
--- pretend (the developer's demo professions are on), lock (Craft.LockState's "future" or
--- "locked", or nil), combat, lineName, recipeName and fill (brief PW1: a click now fills the
--- window's search with the recipe, Craft.WouldFill). Answers { shown = true, enabled, label,
--- body, status }: body is what a click does ("Opens the First Aid window. Find Linen Bandage in
--- its list.", or with fill "Opens the First Aid window on Linen Bandage."), status the one red
--- reason it cannot ({ text, colour } as Craft.State's), or nil. Brief SC2: open (the client's
--- window shows the line now) says so instead: "The First Aid window is open. Find Linen Bandage in
--- its list." Brief SC5 (QA items 284 and 289): a click fills over a window up on the line too
--- (it closes and opens it again inside the click), so fill comes first: "Opens the First Aid
--- window on Linen Bandage.". args.step ("first" or "ready", Craft.ShowButton) is a click that is a
--- step before the one that lands: the label reads "Find recipe" and the body says the step
--- ("Opens the First Aid window first. Then Show craft finds Linen Bandage.", or "Readies the
--- First Aid window. ..."), only on a button that can be pressed and fills. Answers base too, the
--- label the button is sized for ("Show craft"), and step where one is shown. Pure.
function Craft.ShowState(args)
  args = type(args) == "table" and args or EMPTY
  local words = Craft.SHOW_WORDS
  local line = lineWord(args.lineName)
  local recipe = args.recipeName
  local named = type(recipe) == "string" and recipe ~= ""
  local body
  if named and args.fill == true then
    body = string.format(words.fill, line, recipe)
  elseif args.open == true and named then
    body = string.format(words.open, line, recipe)
  elseif args.open == true then
    body = string.format(words.openLine, line)
  elseif named then
    body = string.format(words.how, line, recipe)
  else
    body = string.format(words.howLine, line)
  end
  local reason = nil
  if args.pretend == true then
    reason = words.demo
  elseif args.held == false then
    reason = string.format(words.notHeld, line)
  elseif args.lock ~= nil then
    reason = words.locked
  elseif args.combat == true then
    reason = Craft.WORDS.combat
  end
  -- Brief SC5: combat, the demo, a line not held and a recipe not learnt fade the button as before,
  -- its words unchanged.
  local label, step = words.label, nil
  if reason == nil and named and args.fill == true then
    if args.step == "first" then
      label, step, body = words.findLabel, "first", string.format(words.first, line, recipe)
    elseif args.step == "ready" then
      label, step, body = words.findLabel, "ready", string.format(words.ready, line, recipe)
    end
  end
  return {
    shown = true,
    enabled = reason == nil,
    label = label,
    base = words.label,
    step = step,
    body = body,
    status = statusLine(reason, "red"),
  }
end

--- Brief SC2 (QA item 263): the View profession button's state from facts handed in, Show craft's
--- shape. args: held (true, false, or nil where nothing could say, which counts as held), pretend,
--- combat, lineName and open (the client's window shows the line now). Answers { shown = true,
--- enabled, label, body, status }: body "Opens the Cooking window." (or "The Cooking window is
--- open."), status the one red reason it cannot, in order: the demo, a line not held (a tracked
--- one), combat. Brief VP1 (QA item 277, the owner 2026-10-19: "we should always just open the
--- profession window for them", Fishing included): no line is held back for having no recipes in
--- our data (Skinning's window lists Forever's Camp Chair; the client's own error on an empty list,
--- Blizzard_ProfessionsCrafting.lua:975-980, is the client's). Pure.
function Craft.ViewState(args)
  args = type(args) == "table" and args or EMPTY
  local line = lineWord(args.lineName)
  local body
  if args.open == true then
    body = string.format(Craft.SHOW_WORDS.openLine, line)
  else
    body = string.format(Craft.SHOW_WORDS.howLine, line)
  end
  local reason = nil
  if args.pretend == true then
    reason = Craft.SHOW_WORDS.demo
  elseif args.held == false then
    reason = string.format(Craft.SHOW_WORDS.notHeld, line)
  elseif args.combat == true then
    reason = Craft.WORDS.combat
  end
  return {
    shown = true,
    enabled = reason == nil,
    label = Craft.VIEW_WORDS.label,
    body = body,
    status = statusLine(reason, "red"),
  }
end

local function traceWord(value)
  if value == true then
    return "yes"
  elseif value == false then
    return "no"
  elseif value == nil then
    return "unknown"
  end
  return tostring(value)
end

--- Brief SC2 (QA item 262, the owner: "Sometimes it worked perfectly and then other times clicking it
--- did nothing"): one /itemtree debug line for the last Show craft or View profession click, so his
--- next odd click says what happened. trace is the click's record ({ kind = "show" or "view",
--- clock, at, line, held, fill, open, window, after }), at the GetTime now (nil: no age). Brief
--- SC3: "Show craft: last 21:04:05 (12 s ago) line 165 held yes fill set before open open yes window
--- shown", the take back after a comma ("fill set before open, cleared at the next open"). SC2's
--- "waiting" fill is gone (nothing waits to be set now). Brief SC5 (from SC4): the steps the click
--- took itself, in order, after "steps" ("steps closed, reopened"; "steps opened first").
--- Diagnostic, so not translated, like the rest of /itemtree debug. Pure.
function Craft.TraceLine(trace, at)
  if type(trace) ~= "table" then
    return nil
  end
  local when = tostring(trace.clock or "?")
  local age = (tonumber(at) and tonumber(trace.at)) and math.floor(tonumber(at) - tonumber(trace.at) + 0.5) or nil
  if age and age >= 0 then
    when = string.format("%s (%d s ago)", when, age)
  end
  local fill = trace.fill or "none"
  if trace.after then
    fill = string.format("%s, %s", fill, trace.after)
  end
  local head = trace.kind == "view" and "View profession" or "Show craft"
  local parts = {
    string.format("%s: last %s line %s held %s", head, when, tostring(trace.line or "none"), traceWord(trace.held)),
  }
  if trace.kind ~= "view" then
    parts[#parts + 1] = "fill " .. tostring(fill)
  end
  parts[#parts + 1] = "open " .. tostring(trace.open or "none")
  parts[#parts + 1] = "window " .. tostring(trace.window or "not")
  if type(trace.steps) == "table" and #trace.steps > 0 then
    parts[#parts + 1] = "steps " .. table.concat(trace.steps, ", ")
  end
  return table.concat(parts, " ")
end

--- Brief PR42: whether a pretend player knows a recipe (/itemtree demo professions, UI/PlayerSkills
--- .lua). Known is every trainer recipe (no teaching item, by) of a pretend profession whose rank
--- r is at or below the pretend rank, so the route starts where a real player at that rank would
--- stand; a recipe taught by an item, or one of any other line, is not known. skills is the
--- pretend { [skillLine] = { rank } }. Pure.
function Craft.PretendKnows(tracks, skills, spell)
  spell = number(spell)
  local lines = type(tracks) == "table" and tracks.lines or nil
  if not spell or type(lines) ~= "table" or type(skills) ~= "table" then
    return false
  end
  for skillLine, line in pairs(lines) do
    local recipe = type(line) == "table" and type(line.recipes) == "table" and line.recipes[spell] or nil
    local skill = skills[skillLine]
    if type(recipe) == "table" and type(skill) == "table" and recipe.by == nil then
      local rank = number(skill.rank) or 0
      if (number(recipe.r) or 1) <= rank then
        return true
      end
    end
  end
  return false
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

--- Brief PR42: whether the developer's pretend professions are on (UI/PlayerSkills.lua). While they
--- are, nothing here asks C_TradeSkillUI or crafts: the window never counts as open, Craft.Open
--- and the craft call do nothing, and Craft.KnowsRecipe answers Craft.PretendKnows.
function Craft.Pretend()
  local ui = ItemTree.UI
  local skills = type(ui) == "table" and ui.PlayerSkills or nil
  if type(skills) == "table" and type(skills.DemoOn) == "function" then
    return skills.DemoOn() == true
  end
  return false
end

-- Seconds a burst of bag and craft events is folded into one relabel.
Craft.THROTTLE = 0.2
-- Seconds without a ButtonState ask before events heard lazily are let go.
Craft.IDLE = 60
-- Seconds between two open calls, however often the button is clicked.
Craft.OPEN_GAP = 3
-- The events that can move the button: the trade skill window opening, closing or changing line,
-- a craft finishing or stopping, a recipe learnt, the bags settling, combat starting and ending.
Craft.EVENTS = {
  "TRADE_SKILL_SHOW",
  "TRADE_SKILL_CLOSE",
  "TRADE_SKILL_DATA_SOURCE_CHANGED",
  "TRADE_SKILL_LIST_UPDATE",
  "TRADE_SKILL_ITEM_CRAFTED_RESULT",
  "UPDATE_TRADESKILL_CAST_STOPPED",
  "NEW_RECIPE_LEARNED",
  "BAG_UPDATE_DELAYED",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
}

-- The client's own trade skill windows, the retail shaped one first. Brief PR16: a window counts
-- as open only when one of these shows.
Craft.WINDOWS = { "ProfessionsFrame", "TradeSkillFrame" }

-- listeners: OnChange's functions; registered: the events are heard; managed: the pane calls
-- Watch; lazy: events were turned on by a ButtonState ask; lastAsk: when; pending: a relabel is
-- queued; lastOpen: when the last open call was made; windowOpen: the client's own show and close
-- events, for a client with none of Craft.WINDOWS to ask. Brief SC5: reopenInClick (Craft.ReopenInClick),
-- and inClose / closeHeard around a Show craft click's own close call.
Craft.state = { listeners = {} }

function Craft.ResetState()
  Craft.state = { listeners = {} }
end

local function model()
  local found = ItemTree.ProfessionsModel
  if type(found) == "table" then
    return found
  end
  return nil
end

local globalFn = ItemTree.Util.GlobalFn

local function tradeApi()
  local api = rawget(_G, "C_TradeSkillUI")
  if type(api) == "table" then
    return api
  end
  return nil
end

local function now()
  local clock = globalFn("GetTime")
  if clock then
    local ok, answer = pcall(clock)
    if ok and tonumber(answer) then
      return tonumber(answer)
    end
  end
  return nil
end

-- One relabel (Craft.Fire, the listeners) THROTTLE seconds on, however many asks come between; at
-- once where the client has no timer. Brief SC5: also asked by the page's line change
-- (Craft.NoteWindowLine) and the Show craft click, while the pane listens. A relabel only reads.
local function queueRelabel()
  local state = Craft.state
  if state.pending then
    return false
  end
  local timer = rawget(_G, "C_Timer")
  local after = type(timer) == "table" and timer.After or nil
  if type(after) == "function" then
    state.pending = true
    if pcall(after, Craft.THROTTLE, Craft.Fire) then
      return true
    end
    state.pending = false
  end
  Craft.Fire()
  return true
end

--- Whether the player is in combat now.
function Craft.InCombat()
  local ask = globalFn("InCombatLockdown")
  if not ask then
    return false
  end
  local ok, answer = pcall(ask)
  return ok and answer == true
end

-- Brief PR40 item B: the events that end the player's cast (UNIT_SPELLCAST_START begins one).
Craft.CAST_ENDS = {
  UNIT_SPELLCAST_STOP = true,
  UNIT_SPELLCAST_SUCCEEDED = true,
  UNIT_SPELLCAST_INTERRUPTED = true,
  UNIT_SPELLCAST_FAILED = true,
}

--- Brief PR40 item B: notes the player's cast from the client's own events (the queue's event frame
--- hands them here): UNIT_SPELLCAST_START to STOP, SUCCEEDED, INTERRUPTED or FAILED. Another unit's
--- events and an end naming another spell than the one being cast change nothing. Answers the spell
--- being cast now (true where the start named none), or nil.
function Craft.NoteCast(event, unit, spell)
  if unit ~= "player" then
    return Craft.state.casting
  end
  spell = number(spell)
  if event == "UNIT_SPELLCAST_START" then
    Craft.state.casting = spell or true
  elseif Craft.CAST_ENDS[event] then
    local casting = Craft.state.casting
    if casting == true or spell == nil or casting == spell then
      Craft.state.casting = nil
    end
  end
  return Craft.state.casting
end

--- Brief PR40 item B: the spell the player is casting now as Craft.NoteCast heard it (true where
--- the start named none), or nil.
function Craft.Casting()
  return Craft.state.casting
end

-- The count of one item: the bags only (a craft takes reagents from the bags), or the bags and
-- the bank with withBank.
local function bagCount(itemId, withBank)
  withBank = withBank == true
  local itemApi = rawget(_G, "C_Item")
  if type(itemApi) == "table" and type(itemApi.GetItemCount) == "function" then
    local ok, answer = pcall(itemApi.GetItemCount, itemId, withBank)
    if ok and tonumber(answer) then
      return tonumber(answer)
    end
  end
  local legacy = globalFn("GetItemCount")
  if legacy then
    local ok, answer = pcall(legacy, itemId, withBank)
    if ok and tonumber(answer) then
      return tonumber(answer)
    end
  end
  return 0
end

--- The bag counts of the given recipes' reagents, and only those: { [itemId] = n }. withBank
--- counts the bank too.
function Craft.Counts(order, withBank)
  local counts = {}
  for _, node in ipairs(type(order) == "table" and order or EMPTY) do
    for _, reagent in ipairs(type(node) == "table" and type(node.re) == "table" and node.re or EMPTY) do
      local itemId = type(reagent) == "table" and number(reagent[1]) or nil
      if itemId and counts[itemId] == nil then
        counts[itemId] = bagCount(itemId, withBank)
      end
    end
  end
  return counts
end

-- The classic window's recipe list: { [spell] = index } from each row's recipe link, only while
-- that window is open. A list the client already holds, no server ask.
local function classicIndex()
  local count, link = globalFn("GetNumTradeSkills"), globalFn("GetTradeSkillRecipeLink")
  if not count or not link then
    return nil
  end
  local ok, total = pcall(count)
  total = ok and tonumber(total) or 0
  if total <= 0 then
    return nil
  end
  local out = {}
  for index = 1, total do
    local fine, text = pcall(link, index)
    local spell = fine and type(text) == "string" and tonumber(text:match("enchant:(%d+)")) or nil
    if spell then
      out[spell] = index
    end
  end
  return out
end

-- Brief PR24: the recipes an open window said were not learnt, kept for the session so a later ask
-- with the window shut answers the same (the tab showed Kaldorei Spider Kabob locked while
-- Create all, asking with the window shut, queued it). Any answer that says learnt, or a recipe
-- learnt, lets one go.
local function notLearnt()
  local state = Craft.state
  if type(state.notLearnt) ~= "table" then
    state.notLearnt = {}
  end
  return state.notLearnt
end

--- Brief PR24: notes an open window's answer on a recipe: false is kept (Craft.KnowsRecipe answers
--- it with the window shut too), true lets a kept one go.
function Craft.NoteLearnt(spell, learnt)
  spell = number(spell)
  if not spell then
    return
  end
  if learnt == false then
    notLearnt()[spell] = true
  elseif learnt == true then
    notLearnt()[spell] = nil
  end
end

-- One yes or no answer from the client: true or false, or nil where the call is missing, errors or
-- answers anything else.
local function yesNo(fn, spell)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, answer = pcall(fn, spell)
  if ok and (answer == true or answer == false) then
    return answer
  end
  return nil
end

--- Whether the player knows a recipe: true, false, or nil where nothing could say. Proven in game
--- (Forever 1.60.1.70124, 2026-10-02, every profession window shut): IsPlayerSpell answers a
--- recipe's learnt status at any time (2152 and 2160 true, 3756 false), and C_SpellBook.IsSpellKnown
--- the same. So, in order, the first that answers true or false wins:
---   1. IsPlayerSpell(spell), authoritative;
---   2. C_SpellBook.IsSpellKnown(spell);
---   3. the open window's GetRecipeInfo(spell).learned (brief PR16: a shut window's flag can be
---      stale, so only an open one's false is believed; a true is believed either way);
---   4. an open window's earlier "not learnt" this session (Craft.NoteLearnt), a fallback for a
---      client with neither spell call; else the classic IsSpellKnown where it says known;
---   5. nil: unknown, a normal card.
--- Asked only for the recipes drawn or queued, never over the whole data.
function Craft.KnowsRecipe(spell, open)
  if Craft.Pretend() then
    local skills = ItemTree.UI.PlayerSkills.DemoSkills()
    return Craft.PretendKnows(ItemTree.ProfessionTracks, skills, spell)
  end
  local answer = yesNo(globalFn("IsPlayerSpell"), spell)
  if answer ~= nil then
    return answer
  end
  local book = rawget(_G, "C_SpellBook")
  if type(book) == "table" then
    answer = yesNo(book.IsSpellKnown, spell)
    if answer ~= nil then
      return answer
    end
  end
  local api = tradeApi()
  if api and type(api.GetRecipeInfo) == "function" then
    local ok, info = pcall(api.GetRecipeInfo, spell)
    if ok and type(info) == "table" then
      if info.learned == true then
        Craft.NoteLearnt(spell, true)
        return true
      end
      if info.learned == false and open == true then
        Craft.NoteLearnt(spell, false)
        return false
      end
    end
  end
  if notLearnt()[number(spell) or 0] then
    return false
  end
  if yesNo(globalFn("IsSpellKnown"), spell) == true then
    return true
  end
  return nil
end

--- { [spell] = true } for the recipes the player knows, or may know. Craft.KnowsRecipe rules a
--- recipe out (the spell calls, else the open window's learned flag), else the open classic list.
--- A recipe nothing could answer for counts as known, so the button offers to open the window, or
--- tries the craft, rather than saying there is nothing to craft.
function Craft.Known(order, open)
  local out = {}
  local index = open and classicIndex() or nil
  for _, node in ipairs(type(order) == "table" and order or EMPTY) do
    local answer = Craft.KnowsRecipe(node.spell, open)
    if answer == nil and index then
      answer = index[node.spell] ~= nil
      Craft.NoteLearnt(node.spell, answer)
    end
    if answer == nil then
      answer = true
    end
    out[node.spell] = answer == true or nil
  end
  return out
end

local function professionMatches(info, skillLine)
  if type(info) ~= "table" then
    return false
  end
  return number(info.professionID) == skillLine or number(info.parentProfessionID) == skillLine
end

-- Whether one of the client's trade skill windows shows: true or false where one is there to
-- ask, nil where none is.
local function windowShown()
  local asked = false
  for _, name in ipairs(Craft.WINDOWS) do
    local window = rawget(_G, name)
    if type(window) == "table" and type(window.IsShown) == "function" then
      asked = true
      local ok, shown = pcall(window.IsShown, window)
      if ok and shown == true then
        return true
      end
    end
  end
  if asked then
    return false
  end
  return nil
end

--- Whether the trade skill window is open on this line. The retail shaped API names the line
--- whose data the client holds, which outlives the window, so the window itself must show too:
--- one of Craft.WINDOWS, else (none there to ask) the client's own show and close events. The
--- classic API answers the open window's name.
function Craft.IsOpen(skillLine, lineName)
  if Craft.Pretend() then
    return false
  end
  skillLine = number(skillLine)
  local api = tradeApi()
  if api and type(api.GetBaseProfessionInfo) == "function" then
    local matched = false
    local ok, info = pcall(api.GetBaseProfessionInfo)
    if ok and professionMatches(info, skillLine) then
      matched = true
    end
    if not matched and type(api.GetChildProfessionInfo) == "function" then
      local fine, child = pcall(api.GetChildProfessionInfo)
      matched = fine and professionMatches(child, skillLine)
    end
    if not matched then
      return false
    end
    local shown = windowShown()
    if shown == nil then
      return Craft.state.windowOpen == true
    end
    return shown
  end
  local line = globalFn("GetTradeSkillLine")
  if line and type(lineName) == "string" then
    local ok, name = pcall(line)
    return ok and name == lineName
  end
  return false
end

local function tracks()
  local found = ItemTree.ProfessionTracks
  if type(found) == "table" then
    return found
  end
  return nil
end

local function lineNameOf(skillLine)
  local keep = ItemTree.Keep
  if type(keep) == "table" and type(keep.SkillName) == "function" then
    local ok, name = pcall(keep.SkillName, skillLine)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end
  return nil
end

-- The line's track: the caller's where it has one, else the model's for the player's rank.
local function trackFor(skillLine, track)
  if type(track) == "table" then
    return track
  end
  local m = model()
  if not (m and type(m.Facts) == "function" and type(m.Track) == "function") then
    return nil
  end
  local ok, skills, faction = pcall(m.Facts)
  if not ok or type(skills) ~= "table" then
    return nil
  end
  local skill = skills[number(skillLine)]
  local rank = type(skill) == "table" and number(skill.rank) or nil
  local fine, answer = pcall(m.Track, tracks(), number(skillLine), rank, faction)
  if fine and type(answer) == "table" then
    return answer
  end
  return nil
end

--- Brief PR27: the player's rank in a line now: the client's own profession info where its window
--- shows that line (skillLevel), else the model's facts (UI\Frame.lua PlayerSkills). fresh drops the
--- window's skill cache first (a skill up is exactly when it is stale). nil where nothing says.
function Craft.Rank(skillLine, fresh)
  skillLine = number(skillLine)
  if not skillLine then
    return nil
  end
  local api = tradeApi()
  if api and Craft.IsOpen(skillLine, lineNameOf(skillLine)) then
    for _, ask in ipairs({ "GetChildProfessionInfo", "GetBaseProfessionInfo" }) do
      if type(api[ask]) == "function" then
        local ok, info = pcall(api[ask])
        if ok and professionMatches(info, skillLine) and number(info.skillLevel) then
          return number(info.skillLevel)
        end
      end
    end
  end
  if fresh then
    local ui = ItemTree.UI
    local window = type(ui) == "table" and ui.Frame or nil
    if type(window) == "table" and type(window.InvalidateSkills) == "function" then
      pcall(window.InvalidateSkills)
    end
  end
  local m = model()
  if not (m and type(m.Facts) == "function") then
    return nil
  end
  local ok, skills = pcall(m.Facts)
  local skill = ok and type(skills) == "table" and skills[skillLine] or nil
  return type(skill) == "table" and number(skill.rank) or nil
end

--- Brief PR27: colourOf for Craft.Plan: the client's own colour for a recipe (its
--- TradeSkillRecipeInfo relativeDifficulty, read only) while the window shows the line, else nil.
function Craft.ColourOf(open)
  if Craft.Pretend() then
    return nil
  end
  local api = tradeApi()
  if not open or not (api and type(api.GetRecipeInfo) == "function") then
    return nil
  end
  return function(node)
    local spell = type(node) == "table" and number(node.spell) or nil
    if not spell then
      return nil
    end
    local ok, info = pcall(api.GetRecipeInfo, spell)
    return ok and Craft.ClientColour(info) or nil
  end
end

local ensureLazy

--- The button's state for a band now: { shown, enabled, label, status = { text, colour }, action,
--- spell, n } (Craft.State). Asks the bags only for this band's reagents. track is the pane's own
--- where it has one, so the line is not ordered twice.
function Craft.ButtonState(skillLine, bandIndex, track)
  ensureLazy()
  track = trackFor(skillLine, track)
  local band = bandOf(track, bandIndex)
  if not band then
    return { shown = false, enabled = false, label = Craft.WORDS.label }
  end
  local lineName = lineNameOf(skillLine)
  local combat = Craft.InCombat()
  local order = Craft.Order(track, bandIndex)
  local counts, known, rank, colourOf = {}, {}, nil, nil
  if band.state ~= "done" and #order > 0 then
    local open = Craft.IsOpen(skillLine, lineName)
    counts = Craft.Counts(order)
    known = Craft.Known(order, open)
    -- Brief PR27: the counts are capped at what takes the player to the band's end.
    rank = Craft.Rank(skillLine)
    colourOf = Craft.ColourOf(open)
  end
  return Craft.State({
    track = track,
    bandIndex = bandIndex,
    counts = counts,
    known = known,
    combat = combat,
    rank = rank,
    colourOf = colourOf,
  })
end

-- The one craft call: the retail shaped CraftRecipe, else the classic DoTradeSkill on the recipe's
-- row in the open window. Answers whether a call was made.
local function craftCall(spell, n)
  if Craft.Pretend() then
    return false
  end
  local api = tradeApi()
  if api and type(api.CraftRecipe) == "function" then
    -- Brief PR22: the call's answer is kept for the queue's developer trace.
    local ok, err = pcall(api.CraftRecipe, spell, n)
    Craft.state.lastCall = { spell = spell, n = n, ok = ok, err = not ok and err or nil }
    return ok
  end
  local classic = globalFn("DoTradeSkill")
  if not classic then
    return false
  end
  local index = classicIndex()
  local row = index and index[spell] or nil
  if not row then
    return false
  end
  return (pcall(classic, row, n))
end

Craft.CraftCall = craftCall
Craft.TrackFor = trackFor
Craft.LineName = lineNameOf

-- Brief PR25 (the owner: "The Pause button should instantly pause, not at the next stop"). Checked
-- on github.com/Gethe/wow-ui-source, branch forever, and the 1.60.1.70009 client binary's strings:
--   * The Professions UI has no stop or cancel path of its own for a batch: the crafting page
--     (Blizzard_Professions/Blizzard_ProfessionsCrafting.lua) only listens for
--     UPDATE_TRADESKILL_CAST_STOPPED, UNIT_SPELLCAST_INTERRUPTED and _FAILED and reads
--     C_TradeSkillUI.GetRemainingRecasts; closing the window calls C_TradeSkillUI.CloseTradeSkill
--     (Blizzard_ProfessionsFrame.lua ProfessionsMixin:OnHide), which is not a stop.
--   * The generated docs (Blizzard_APIDocumentationGenerated/TradeSkillUIDocumentation.lua) list
--     no stop call, but the binary registers the undocumented C_TradeSkillUI.StopRecipeRepeat
--     beside IsRecipeRepeating. StopTradeSkillRepeat is not in the binary. Neither is marked
--     protected anywhere we can read, so the stop is tried under pcall and the client's own
--     ADDON_ACTION_BLOCKED or ADDON_ACTION_FORBIDDEN naming it turns it off for the session.
--   * SpellStopCasting is never called: it is a protected function, reached only through the secure
--     /stopcasting command (Blizzard_ChatFrameBase/Shared/SlashCommands.lua
--     CheckAddSecureSlashCommand) and the STOPCASTING binding (Blizzard_FrameXML/
--     Bindings_Camelot.xml). So from here the craft under way always finishes; only the repeats
--     stop. Brief PR39 item A, brief PR40 item B: the tray's main button is a secure button of the
--     queue's own (UI/Queue.lua Queue.SyncStop) whose action, while the craft is being cast
--     (Craft.NoteCast), is the client's own /stopcasting, so the Pause click itself cancels the
--     cast; this file still never calls SpellStopCasting.
Craft.STOP_CALLS = {
  { "C_TradeSkillUI", "StopRecipeRepeat" },
  { nil, "StopTradeSkillRepeat" },
}

-- The stop call this client has, and its name, or nil (none there, or blocked this session).
local function stopCall()
  if Craft.state.stopBlocked then
    return nil
  end
  for _, pair in ipairs(Craft.STOP_CALLS) do
    local owner = _G
    if pair[1] then
      owner = rawget(_G, pair[1])
    end
    local fn = type(owner) == "table" and rawget(owner, pair[2]) or nil
    if type(fn) == "function" then
      return fn, pair[2]
    end
  end
  return nil
end

--- Whether a batch can be stopped part way on this client (the call is there and not blocked).
function Craft.CanStopRepeat()
  return stopCall() ~= nil
end

--- The repeats the client still has queued after the cast under way (GetRemainingRecasts), or nil.
function Craft.RemainingRecasts()
  local api = tradeApi()
  if not (api and type(api.GetRemainingRecasts) == "function") then
    return nil
  end
  local ok, remaining = pcall(api.GetRemainingRecasts)
  return ok and number(remaining) or nil
end

--- Stops the repeats of the batch under way, from the player's own click. The cast under way still
--- finishes. Answers whether the stop took (the call ran, and the client's count of repeats left,
--- where it gives one, is 0), and the call's name for the trace. Brief PR27: fromEvent says the
--- call comes from an event (the band's end reached mid batch), not a click; once the client has
--- blocked one of those this session, no more are tried from events (clicks still may).
function Craft.StopRepeat(fromEvent)
  if fromEvent and Craft.state.eventStopBlocked then
    return false, nil
  end
  local fn, name = stopCall()
  if not fn then
    return false, nil
  end
  local ok, err = pcall(fn)
  Craft.state.lastStop = { name = name, ok = ok, err = not ok and err or nil }
  if not ok then
    return false, name
  end
  local left = Craft.RemainingRecasts()
  if left ~= nil and left > 0 then
    Craft.state.lastStop.left = left
    return false, name
  end
  return true, name
end

--- The client said no to the stop (ADDON_ACTION_BLOCKED or _FORBIDDEN naming it): never again this
--- session. Brief PR27: where the refused call came from an event (fromEvent), only the event's
--- stop is given up; a click may still try. Answers whether the named function is one of the stop
--- calls.
function Craft.StopBlocked(functionName, fromEvent)
  for _, pair in ipairs(Craft.STOP_CALLS) do
    if type(functionName) == "string" and functionName:find(pair[2], 1, true) then
      if fromEvent then
        Craft.state.eventStopBlocked = true
      else
        Craft.state.stopBlocked = true
      end
      return true
    end
  end
  return false
end

-- Brief PR25 (the owner: "Pre-check and list requirements (e.g. Cooking Fire)"). The Professions UI
-- shows its "Requires" line from C_TradeSkillUI.GetRecipeRequirements(recipeID), a list of
-- CraftingRecipeRequirement { name, met, type } where type is Enum.RecipeRequirementType
-- (SpellFocus 0, Totem 1, Area 2), and blocks its Create button on any met == false
-- (Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRecipeSchematicForm.lua UpdateRequiredTools,
-- Blizzard_Professions/Blizzard_ProfessionsCrafting.lua ValidateCraftRequirements,
-- Blizzard_APIDocumentationGenerated/TradeSkillUITypesDocumentation.lua). It re-reads the list on
-- each refresh rather than on an event of its own, so the queue does the same.
Craft.REQ_FOCUS = 0
Craft.REQ_TOOL = 1
Craft.REQ_AREA = 2

-- Our data's word on a recipe's tools where the window cannot say: Recipes_<sl> in ItemTree_Data
-- (toolItems by item, tools by totem category), read only once that data is loaded. A spell focus
-- is in neither. Each { name, met (true, false or nil where unknown), type }.
local function dataRequirements(spell)
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.GetRecipe) ~= "function" then
    return {}
  end
  if type(data.OnDemandLoaded) == "function" then
    local ok, loaded = pcall(data.OnDemandLoaded, data)
    if not ok or not loaded then
      return {}
    end
  end
  local ok, recipe = pcall(data.GetRecipe, data, spell)
  if not ok or type(recipe) ~= "table" then
    return {}
  end
  local out = {}
  for _, itemId in ipairs(type(recipe.toolItems) == "table" and recipe.toolItems or EMPTY) do
    local fine, item = pcall(data.GetItem, data, itemId)
    local name = fine and type(item) == "table" and item.n or nil
    if type(name) == "string" and name ~= "" then
      out[#out + 1] = { name = name, met = bagCount(itemId) > 0, type = Craft.REQ_TOOL }
    end
  end
  for _, category in ipairs(type(recipe.tools) == "table" and recipe.tools or EMPTY) do
    local categories = type(data.Get) == "function" and data:Get("TotemCategories") or nil
    local name = type(categories) == "table" and categories[category] or nil
    if type(name) == "string" and name ~= "" then
      local met = nil
      if type(data.ItemsWithTotemCategory) == "function" then
        local fine, items = pcall(data.ItemsWithTotemCategory, data, category)
        if fine and type(items) == "table" and #items > 0 then
          met = false
          for _, itemId in ipairs(items) do
            if bagCount(itemId) > 0 then
              met = true
              break
            end
          end
        end
      end
      out[#out + 1] = { name = name, met = met, type = Craft.REQ_TOOL }
    end
  end
  return out
end

--- A recipe's needs beyond its reagents (spell focus, tools, area): the client's own list while
--- its window is open (open true), else our data's tools. Read only. { { name, met, type } }.
--- Brief PR39 item I (the owner found a Cooking Fire is known only while the Cooking window is the
--- open one): the client's word on a spell focus or an area is noted for the session (its name and
--- kind, never whether it was met), and while that window is not the open one the need is listed
--- with met nil and check true, so the box says to open the window rather than a stale "not near
--- one". Our data has no spell focus, so a need the window never showed this session is not listed.
function Craft.Requirements(spell, open)
  spell = number(spell)
  if not spell then
    return {}
  end
  local api = tradeApi()
  if Craft.Pretend() then
    open = false
  end
  if open and api and type(api.GetRecipeRequirements) == "function" then
    local ok, list = pcall(api.GetRecipeRequirements, spell)
    if ok and type(list) == "table" then
      local out, seen = {}, {}
      for _, req in ipairs(list) do
        if type(req) == "table" and type(req.name) == "string" and req.name ~= "" then
          local met = nil
          if req.met == true then
            met = true
          elseif req.met == false then
            met = false
          end
          local kind = number(req.type) or Craft.REQ_FOCUS
          out[#out + 1] = { name = req.name, met = met, type = kind }
          if kind ~= Craft.REQ_TOOL then
            seen[#seen + 1] = { name = req.name, type = kind }
          end
        end
      end
      Craft.state.reqSeen = Craft.state.reqSeen or {}
      Craft.state.reqSeen[spell] = seen
      return out
    end
  end
  local out = dataRequirements(spell)
  local seen = type(Craft.state.reqSeen) == "table" and Craft.state.reqSeen[spell] or nil
  for _, req in ipairs(type(seen) == "table" and seen or EMPTY) do
    out[#out + 1] = { name = req.name, met = nil, type = req.type, check = true }
  end
  return out
end

-- Brief SC3: why Craft.Open would make no call now ("demo", "gap", "none"), or nil where it would.
-- Show craft asks first, so a click whose open is held back changes nothing.
local function openHeldBack(force)
  if Craft.Pretend() then
    return "demo"
  end
  local at = now()
  local last = Craft.state.lastOpen
  if force ~= true and last and at and at - last < Craft.OPEN_GAP and Craft.state.openAnswered ~= true then
    return "gap"
  end
  local api = tradeApi()
  if not (api and type(api.OpenTradeSkill) == "function") then
    return "none"
  end
  return nil
end

-- Brief SC3: the last Show craft click whose fill waits for its window's show, or nil once a show,
-- a close or FILL_WAIT seconds have ended the wait (the record is dropped then).
local function livePending()
  local pending = Craft.state.pendingFill
  if type(pending) ~= "table" then
    return nil
  end
  local at, born = now(), pending.at
  if at and born and at - born > Craft.FILL_WAIT then
    Craft.state.pendingFill = nil
    return nil
  end
  return pending
end

--- One open call for the line, never two within OPEN_GAP seconds. force (brief PR22: the queue's
--- own press switching the window to its line, one call a press) skips the gap. Answers whether it
--- was made.
--- Brief SC2 (QA item 262, "clicking it did nothing"): the gap guards an open still on its way, so
--- it ends as soon as the client has answered the last one: its show or close heard
--- (Craft.OnWindowEvent), or OpenTradeSkill answering false (TradeSkillUIDocumentation.lua:
--- 1098-1110, "opened"), after which no show is coming. Before, Show craft clicked again inside
--- 3 seconds of a window shown and shut made no call at all. An open the client refuses or that
--- errors answers false now (it opened nothing); Craft.state.openWord says which ("yes", "no",
--- "error", "gap", "none") for the trace.
function Craft.Open(skillLine, force)
  local held = openHeldBack(force)
  if held then
    Craft.state.openWord = held
    return false
  end
  local api = tradeApi()
  -- Brief SC3: a Show craft fill still in the client's search goes back immediately before any other
  -- open of ours (View profession, Craft all, the queue), the way the fill goes in, so the window's
  -- OnShow copies an empty search whichever order the client shows it in. Not for a Show craft click
  -- whose own fill waits, and not where a window shows (its OnShow has run already).
  if Craft.state.filled and not livePending() and windowShown() ~= true then
    Craft.TakeBack("before open")
  end
  Craft.state.lastOpen = now() or 0
  -- Set before the call: TRADE_SKILL_SHOW is a SynchronousEvent (TradeSkillUIDocumentation.lua:
  -- 1384-1388), so its answer may come inside it. Brief SC3: inOpen tells the trace a show heard
  -- inside the call from one heard later.
  Craft.state.openAnswered = false
  Craft.state.inOpen = true
  local ok, opened = pcall(api.OpenTradeSkill, number(skillLine))
  Craft.state.inOpen = false
  if not ok or opened == false then
    Craft.state.openWord = ok and "no" or "error"
    Craft.state.openAnswered = true
    return false
  end
  Craft.state.openWord = "yes"
  -- Brief PW1 (QA items 238 d and 239 a): Craft all, Show craft and the queue's press bring the
  -- profession window in front of ItemTree's (one still opening takes the front as it shows).
  Craft.ProfessionsToFront()
  return true
end

--- Brief PW1: asks the ItemTree window to give the client's profession window the front (UI/Frame.lua
--- Frame.ProfessionsToFront, which moves only ItemTree's own window). Answers whether it did.
function Craft.ProfessionsToFront()
  local ui = ItemTree.UI
  local window = type(ui) == "table" and ui.Frame or nil
  if type(window) == "table" and type(window.ProfessionsToFront) == "function" then
    local ok, front = pcall(window.ProfessionsToFront)
    return ok and front == true
  end
  return false
end

-- The queue's own place in the saved settings: { chain = true or false, window = true or false },
-- each nil until a probe or a live attempt has said.
local function savedCraft(create)
  local db = ItemTree.db
  local settings = type(db) == "table" and db.settings or nil
  if type(settings) ~= "table" then
    return nil
  end
  local own = settings.professionsCraft
  if type(own) ~= "table" and create then
    own = {}
    settings.professionsCraft = own
  end
  return type(own) == "table" and own or nil
end

--- Brief PR18: whether the client lets a craft start from an event, with no click: true only once
--- the probe or a live chained craft proved it, false once one was blocked, nil while nobody knows.
--- This session's answer first, then the saved one.
function Craft.AutoChain()
  if Craft.state.autoChain ~= nil then
    return Craft.state.autoChain
  end
  local saved = savedCraft(false)
  local answer = saved and saved.chain
  if answer == true or answer == false then
    return answer
  end
  return nil
end

--- Sets the answer for this session, and saves it with save.
function Craft.SetAutoChain(answer, save)
  if answer ~= true and answer ~= false then
    answer = nil
  end
  Craft.state.autoChain = answer
  if save then
    local saved = savedCraft(true)
    if saved then
      saved.chain = answer
    end
  end
  return answer
end

--- Brief PR18: whether a craft needs the profession window open: false only once the probe saw a
--- craft start with it shut; true (the safe answer) otherwise.
function Craft.NeedsWindow()
  if Craft.state.needsWindow ~= nil then
    return Craft.state.needsWindow
  end
  local saved = savedCraft(false)
  if saved and saved.window == false then
    return false
  end
  return true
end

--- Sets whether a craft needs the window, for this session, and saves it with save.
function Craft.SetNeedsWindow(answer, save)
  answer = answer ~= false
  Craft.state.needsWindow = answer
  if save then
    local saved = savedCraft(true)
    if saved then
      saved.window = answer
    end
  end
  return answer
end

-- Brief PR38 (fault D, the owner: "the professions tab is not coming up at all - no bugsack
-- bugs"): a fault inside the queue's OpenFor was caught by the click's pcall and dropped, so
-- nothing came up and nothing was said. It now goes to the client's error handler as the
-- boundary's own catches do (ItemTree.Guard: once a message a session), after the call, so the
-- click itself stays a plain synchronous call. Guard.strict (the specs) raises it again.
local function reportClick(err)
  local guard = ItemTree.Guard
  if type(guard) ~= "table" then
    return false
  end
  if guard.strict then
    error(err, 0)
  end
  if type(guard.Record) ~= "function" or type(guard.Report) ~= "function" then
    return false
  end
  local ok, _, first = pcall(guard.Record, "Professions.Craft.Click", err, tostring(err), now())
  if ok and first then
    pcall(guard.Report, err)
  end
  return ok
end
Craft.ReportClick = reportClick

--- The button's OnClick. Brief PR21: Create all crafts nothing. It hands the band to the craft
--- queue (UI/Queue.lua Queue.OpenFor), which builds the queue, opens the profession window (brief
--- PR39: the ItemTree window stays open where it is) and shows the tray docked beside the
--- profession window, then waits for the
--- player's press. Without the tray (a spec that loads this file alone) it only opens the window
--- (never twice within OPEN_GAP seconds). Answers what it did: "queue" (the tray shows), "open" or
--- nil. Brief PR38: a fault in OpenFor reaches the client's error handler (reportClick).
function Craft.Click(skillLine, bandIndex, track)
  local queue = ItemTree.ProfessionsQueue
  if type(queue) == "table" and type(queue.OpenFor) == "function" then
    local ok, answer = pcall(queue.OpenFor, skillLine, bandIndex, track)
    if ok then
      return answer
    end
    reportClick(answer)
    return nil
  end
  if Craft.InCombat() then
    return nil
  end
  local state = Craft.ButtonState(skillLine, bandIndex, track)
  if not state.shown or not state.enabled then
    return nil
  end
  if Craft.IsOpen(skillLine, lineNameOf(skillLine)) then
    return nil
  end
  if Craft.Open(skillLine) then
    return "open"
  end
  return nil
end

--- Brief SC1: whether the character really has a profession line, so has a window to open: the
--- client's own professions as Frame.PlayerSkills reads them. false while the developer's pretend
--- professions are on (Craft.Pretend: Frame.PlayerSkills answers those then) and for a line the
--- skills do not hold, such as one the character only follows; nil where nothing could say (no
--- window module, or the client has answered nothing yet), which counts as held.
function Craft.Held(skillLine)
  skillLine = number(skillLine)
  if not skillLine then
    return false
  end
  if Craft.Pretend() then
    return false
  end
  local ui = ItemTree.UI
  local window = type(ui) == "table" and ui.Frame or nil
  if type(window) ~= "table" or type(window.PlayerSkills) ~= "function" then
    return nil
  end
  local ok, skills = pcall(window.PlayerSkills)
  if not ok or type(skills) ~= "table" or next(skills) == nil then
    return nil
  end
  return skills[skillLine] ~= nil
end

--- Brief SC1: the Show craft button's state for a card now (Craft.ShowState), from the line, the
--- recipe's lock as the card drew it (Craft.LockState's "future" or "locked", or nil) and the name
--- the card shows. Brief SC2: and the card's spell, for the fill's checks (Craft.FillCheck); the
--- window up on the line already says so (asked only while a window shows). Brief SC5: and the step
--- a click is where it does not land yet (ShowState's step, "Find recipe"), the same on every card
--- of the line that fills.
function Craft.ShowButton(skillLine, lock, recipeName, spell)
  skillLine = number(skillLine)
  local held = Craft.Held(skillLine)
  -- Brief PW2: a click fills the search only for a line the client's skills say is held, so the
  -- hover says so only then.
  local fill = false
  if held == true then
    fill = Craft.WouldFill(recipeName, skillLine, spell)
  end
  local open = false
  if windowShown() == true then
    open = Craft.ShowsLine(skillLine)
  end
  -- Brief SC5 (QA items 284 and 289): what this click does, from the window's state now
  -- (Craft.FillRoute): one that lands on the recipe ("plain"; "reopen" while the client answers our
  -- close inside the call, or before it has been tried) reads Show craft; one that opens the window
  -- on the line first, or closes it first where the client answers our close later, is a step and
  -- reads Find recipe. Read only: nothing here opens or closes anything.
  local step = nil
  if fill then
    local route = Craft.FillRoute(skillLine, held)
    if route == "first" or route == "settling" then
      step = "first"
    elseif route == "reopen" and Craft.ReopenInClick() == false then
      step = "ready"
    end
  end
  return Craft.ShowState({
    held = held,
    pretend = Craft.Pretend(),
    lock = lock,
    combat = Craft.InCombat(),
    lineName = lineNameOf(skillLine),
    recipeName = recipeName,
    fill = fill,
    open = open,
    step = step,
  })
end

--------------------------------------------------------------------------------
-- Brief PW1: Show craft fills the profession window's search (QA item 239 c). Brief SC2 (QA item
-- 262) moved the fill after the open; brief SC3 (QA items 281 and 282) sets it before the open again.
--------------------------------------------------------------------------------
-- The owner: "Show craft does not change the recipe selection in the respective porfession window
-- it only opens the profession window to that profession. (is it not possible to pre-fill search
-- and select the recipe?" and his ruling A: "I would go with A because if we cant open to the
-- recipe directly then we ddont need a button on every recipe". Then, round AD (item 262): "Note
-- the button does work intermittently ... clicking it did nothing ... it produced an error", and
-- "Try again with the search - lets try and make it work". Picking the recipe directly stays out
-- (Craft.ShowCraft's head). How the client's page takes a search, read on origin/forever
-- 1.60.1.70450, nothing called on the window:
--   * the crafting page copies the client's recipe name filter into its search box as it shows
--     (ProfessionsCraftingPageMixin:OnShow, Blizzard_Professions/Blizzard_ProfessionsCrafting.lua:349),
--     and only then; the box's own OnTextChanged finds the filter already equal and stops (:83-97,
--     Blizzard_ProfessionsTemplates/Blizzard_Professions.lua:1360-1363). Its page forgets its
--     profession on every hide (:414-416), so its first list selects the first recipe the filter
--     leaves (:955-956, :975-978);
--   * the window is shown by the client's own TRADE_SKILL_SHOW handler (GameEvent.HandleTradeSkillShow,
--     Blizzard_Game/Mainline/EventImplementation.lua:475-477, routed at Mainline/EventRouting.lua:107
--     and kept by Camelot/EventRouting.lua:22-26), registered through GameEvent.RegisterInternalEvents,
--     which no file in the mirror defines: the engine dispatches it;
--   * on the first list after a show, a page whose last profession was another one (or none: the
--     frame keeps professionInfo across hides, only its crafting page forgets) empties its search box,
--     and that clears the filter (ProfessionsMixin:SetProfessionInfo, Blizzard_ProfessionsFrame.lua:
--     226-241, then Blizzard_Professions.lua:1360-1390). So a fill lasts only where the window last
--     showed the same profession: PW1's "sometimes it worked perfectly";
--   * the loaded frame hears TRADE_SKILL_LIST_UPDATE while hidden (registered in OnLoad, :37-38 with
--     :2-13, never let go), and Blizzard's own comment says filter changes raise list updates
--     (:149-151). Handled with no trade skill open, Professions.GetProfessionInfo answers professionID
--     0 (Blizzard_Professions.lua:1665-1676), SetProfessionInfo counts a change (:226), empties the
--     search (:235-236) and raises Professions.ProfessionSelected (:252), and the crafting page builds
--     an empty list and takes its SchematicForm:Init(nil) path (Blizzard_ProfessionsCrafting.lua:980).
-- Brief SC3, the route now (the owner's ruling A on item 282, 2026-10-19): SC2 set the filter only
-- after the client answered the open, and in his client the window's OnShow had copied the empty
-- search before our frame heard the show ("fill skipped (window first)"). SC2 had left PW1's order
-- only for the errors at Blizzard_ProfessionsCrafting.lua:456 and :980, which item 281 traced to
-- another installed addon (none with all addons off, none with only BugSack and ItemTree). So where
-- Craft.FillCheck allows and the open will be made, the click sets the filter (Craft.FillBeforeOpen)
-- and makes the open call straight after, in the same press: the window's OnShow copies the name
-- into its box whether the client shows it inside the open call or later.
-- Why no client code runs inside our filter call (read in the mirror): SetRecipeItemNameFilter and
-- SetRecipeItemLevelFilter have no entry in Blizzard_APIDocumentationGenerated/
-- TradeSkillUIDocumentation.lua (no SecretArguments, no event named), and the list update Blizzard
-- ties to filter changes, TRADE_SKILL_LIST_UPDATE, is documented as a UniqueEvent, not a
-- SynchronousEvent (:1373-1377), unlike TRADE_SKILL_SHOW and TRADE_SKILL_CLOSE (:1384-1389,
-- :1288-1292). So the client hands it to the hidden frame's handler (Blizzard_ProfessionsFrame.lua:
-- 148-171) after our press returns, once the open call has been made: the handler then meets a data
-- source still changing (it yields, :152-154) or the trade skill open on the line. The other order
-- (the filter after the open call returns, before the window shows) is not used: where the client
-- shows the window inside the open call, its box has copied an empty search already, and where it
-- shows later the filter raises the same queued list update. The mirror tags the events but defines
-- neither flag, so the owner's taint log judges (QA).
-- The take back: never on the hide (the trade skill closes inside the window's OnHide,
-- Blizzard_ProfessionsFrame.lua:549-551, so a list update from it would land with none open). At the
-- next show with no click waiting, while the window has not shown yet, the filter goes back to empty
-- if it still holds exactly our name; otherwise it stays, as the player's own search does, and the
-- box shows it. Brief FX-AF, kept: a show of another line takes it back at once, and a close drops
-- the click's wait. An open the client refuses takes it back there and then, and so does any other
-- open of ours, just before its call (Craft.Open), as the fill goes in (Craft.TakeBack). In the
-- owner's client the window shows before our frame hears it, so only the player's own open (the
-- spellbook) can find our name still in the box: it stays there as his own search would.
-- Brief SC5 (QA items 284 and 289). Item 284: SC3 filled only where the window was shut and last
-- showed the line ("It seems you need to open/close the profession window before each search for it
-- to work"). Item 289: SC4 made the open and close itself, partly from a C_Timer tick, and the client
-- refused the open there (ADDON_ACTION_BLOCKED for ItemTree_Professions at OpenTradeSkill: it needs
-- the player's own press). So the hard rule: every OpenTradeSkill and CloseTradeSkill of ours runs
-- inside a button's own OnClick (Show craft, View profession, Craft all, the queue's press); no
-- timer, event handler or callback opens, closes or reopens anything (a spec scans this file). The
-- owner's choice A, by the window's state a click meets (Craft.FillRoute), read on origin/forever
-- 1.60.1.70450 (172a387):
--   * "plain": the window shut (or its book page up over a trade skill closed behind it, Camelot/
--     Blizzard_ProfessionsFrame.lua:140-146) and the page last on the line: SC3's one open, the filter
--     set just before it. Lands in one click.
--   * "reopen": the window up on the line, the page on it: C_TradeSkillUI.CloseTradeSkill, the filter,
--     OpenTradeSkill, in the same click (SC4's analysis). The close has no arguments, no
--     SecretArguments and no restriction (TradeSkillUIDocumentation.lua:53-56), and TRADE_SKILL_CLOSE
--     is a SynchronousEvent (:1288-1292), so the window's handler may hide it inside our call
--     (Blizzard_ProfessionsFrame.lua:172-173, Camelot :140-146 HideUIPanel); its OnHide forgets the
--     crafting page's profession (:540-551, Blizzard_ProfessionsCrafting.lua:414-416) while the frame
--     keeps its own professionInfo, so the open straight after is the plain case: the crafting page's
--     OnShow copies the filter into its box (Crafting :343-349) and its first list keeps the search
--     (the frame's profession did not change, Blizzard_ProfessionsFrame.lua:225-244). Where the client
--     answers the close inside the call (our frame hears TRADE_SKILL_CLOSE in it, or the window no
--     longer shows), the click opens again: one click. Where it does not, the click stops there: no
--     open (it would have to wait for the close, outside the click) and no filter either (a filter set
--     while the close is on its way raises a list update, TRADE_SKILL_LIST_UPDATE a UniqueEvent :1373-
--     1377, that may reach the hidden page after the close with no trade skill open; the page then
--     settles on none and empties the search, Blizzard_ProfessionsFrame.lua:148-171 and 225-252, item
--     262's path). Once the close lands, the window is shut and last on the line: the next click is
--     "plain" and sets the filter just before its open. Which way the client went is kept for the
--     session (Craft.ReopenInClick, in /itemtree debug): from the first close not answered inside the
--     call, a window up on the line reads Find recipe. Brief SC6 (QA item 293): such a click takes the
--     trade skill as closed at once, so the next click is "plain", and counts the close as not
--     answered only where a show was heard this session (a window on its book page with no trade
--     skill open has nothing to close, so no answer comes).
--   * "settling": the window up on the line but its page not on it yet (its first list after our open
--     has not come): closing now would leave the frame on the old line and the reopen's first list
--     would empty the search (:235-236), so the click only brings the window in front.
--   * "first": the window shut and the page's line unknown to us (it has said nothing since this file
--     loaded) or another, or the window up on another line: the click opens the line unsearched (the
--     page's first list on a new line empties any search, :235-236), and the buttons read Show craft
--     once the page says it has the line (its Professions.ProfessionSelected, :251-252) or, where it
--     has said nothing to us, once the line shows (takeShownLine: every list sets the page's line to
--     the trade skill open, :247), which makes the next click "reopen" (or "plain" where the window
--     was shut meanwhile). A window up on the line whose page has said nothing is taken as on it.
--     Brief SC6 (QA item 293): and at each list the page handles after a show, the shown line is taken
--     whenever it differs, so the words never wait on the page's event.
-- The labels follow the window's state on every card (Craft.ShowButton): the client's own show and
-- close and the page's line change relabel them (Craft.OnEvent, Craft.NoteWindowLine), reading
-- only. Nothing is called on a Blizzard frame: CloseTradeSkill, SetRecipeItemNameFilter,
-- SetRecipeItemLevelFilter and OpenTradeSkill only.

-- Brief SC2: seconds a click waits for the client's show of its open, the time Craft.Open counts an
-- open as on its way (OPEN_GAP); a later show is the player's own (brief SC3: it takes the fill back).
Craft.FILL_WAIT = 3

--- Brief PW1: the client's own name for a recipe: its spell's name (C_Spell.GetSpellName, else
--- GetSpellInfo), read through Util.CanRead, else fallback (the card's name), else nil. One call,
--- for one recipe, on a click or a hover.
function Craft.RecipeClientName(spell, fallback)
  spell = number(spell)
  local name = nil
  if spell then
    local spells = rawget(_G, "C_Spell")
    if type(spells) == "table" and type(spells.GetSpellName) == "function" then
      local ok, answer = pcall(spells.GetSpellName, spell)
      if ok and canRead(answer) and type(answer) == "string" and answer ~= "" then
        name = answer
      end
    end
    local info = globalFn("GetSpellInfo")
    if not name and info then
      local ok, answer = pcall(info, spell)
      if ok and canRead(answer) and type(answer) == "string" and answer ~= "" then
        name = answer
      end
    end
  end
  if not name and type(fallback) == "string" and fallback ~= "" then
    name = fallback
  end
  return name
end

--- Brief SC2: the name the client's list shows for the recipe while a trade skill is open
--- (GetRecipeInfo's name, read through Util.CanRead), else Craft.RecipeClientName's. One call.
function Craft.FillName(spell, fallback)
  local api = tradeApi()
  local id = number(spell)
  if api and id and type(api.GetRecipeInfo) == "function" then
    local ok, info = pcall(api.GetRecipeInfo, id)
    local name = ok and type(info) == "table" and info.name or nil
    if canRead(name) and type(name) == "string" and name ~= "" then
      return name
    end
  end
  return Craft.RecipeClientName(spell, fallback)
end

-- The client's recipe name filter calls, or nil where it has them not.
local function filterApi()
  local api = tradeApi()
  if api and type(api.SetRecipeItemNameFilter) == "function" then
    return api
  end
  return nil
end

--- Brief SC5 (from SC4, QA item 284: "emptied before show" although the box filled): whether the
--- client's filter, read back, still holds name. Compared as the window's own search box compares the
--- two (strcmputf8i, Blizzard_ProfessionsTemplates/Blizzard_Professions.lua:1361), so a filter the
--- client answers in its own case is still ours; SC3 compared exactly. current must be readable
--- (canRead) before it comes here.
local function sameSearch(current, name)
  if current == name then
    return true
  end
  if type(current) ~= "string" or type(name) ~= "string" then
    return false
  end
  local compare = globalFn("strcmputf8i")
  if compare then
    local ok, answer = pcall(compare, current, name)
    if ok and tonumber(answer) then
      return tonumber(answer) == 0
    end
  end
  return string.lower(current) == string.lower(name)
end
Craft.SameSearch = sameSearch

-- Brief SC2: the client's profession info for the trade skill open now (the child's, else the
-- base's, as Professions.GetProfessionInfo reads them), or nil where none is open (professionID 0).
local function openInfo()
  local api = tradeApi()
  if not api then
    return nil
  end
  for _, name in ipairs({ "GetChildProfessionInfo", "GetBaseProfessionInfo" }) do
    local fn = api[name]
    if type(fn) == "function" then
      local ok, info = pcall(fn)
      local id = ok and type(info) == "table" and info.professionID or nil
      if canRead(id) and (number(id) or 0) ~= 0 then
        return info
      end
    end
  end
  return nil
end

-- Brief SC2: the getters of the filters the Forever menu offers that can narrow the list (Craft.Narrowed).
Craft.NARROWING = { "GetOnlyShowSkillUpRecipes", "GetOnlyShowMakeableRecipes", "AreAnyInventorySlotsFiltered" }

--- Brief SC2: whether the client's own filters may hide a learnt recipe from its list: the three its
--- Forever filter menu offers (skill ups, makeable, slots: Camelot/Blizzard_Professions.lua:1-14,
--- read as Professions.IsUsingDefaultFilters reads them, Blizzard_Professions.lua:1091-1098), and
--- learnt recipes not shown at all. true where one is on or a getter cannot say; a getter the client
--- does not have is a filter it cannot set.
function Craft.Narrowed()
  local api = tradeApi()
  if not api then
    return true
  end
  for _, name in ipairs(Craft.NARROWING) do
    local fn = api[name]
    if type(fn) == "function" then
      local ok, answer = pcall(fn)
      if not ok or not canRead(answer) or answer ~= false then
        return true
      end
    end
  end
  if type(api.GetShowLearned) == "function" then
    local ok, answer = pcall(api.GetShowLearned)
    if not ok or not canRead(answer) or answer ~= true then
      return true
    end
  end
  return false
end

--- Brief SC2: the line the client's profession page last settled on, as its own
--- Professions.ProfessionSelected said ({ professionID, parentProfessionID }; professionID 0 for its
--- empty state), or nil before it has said (the page not loaded yet, or loaded before this file).
function Craft.WindowLine()
  return Craft.state.windowLine
end

-- Brief SC6 (QA item 293): whether the client is still rebuilding the trade skill's data, when the page
-- leaves a list for the next one (C_TradeSkillUI.IsDataSourceChanging, Blizzard_ProfessionsFrame.lua:
-- 149-153). true where the client cannot say; false on a client without the call.
local function sourceChanging()
  local api = tradeApi()
  local ask = api and api.IsDataSourceChanging or nil
  if type(ask) ~= "function" then
    return false
  end
  local ok, answer = pcall(ask)
  if not ok or not canRead(answer) then
    return true
  end
  return answer == true
end

-- Brief SC5: where the page has said nothing to us (ItemTree_Professions loads on demand, so the page
-- may have settled on a line before this file was loaded, and it raises Professions.ProfessionSelected
-- only when its line changes), the line the window shows now is taken as the page's: every list the
-- page handles sets its professionInfo to the trade skill open (Blizzard_ProfessionsFrame.lua:247-248),
-- and a page still on another line raises its change at its first list, which overrides this. Without
-- it, a page already on the line would leave the click "first" every time. Answers what was taken.
-- Brief SC6 (QA item 293, the pre-release review): listed, at a list the page has handled with a
-- trade skill open since a show we heard (Craft.OnWindowEvent), the page is on the line that shows
-- whatever it said to us (:167-171, then :247), so the shown line is taken whenever its professionID
-- differs (the page judges a change by professionID alone, :226), and the cards are drawn again: the
-- words no longer wait on Professions.ProfessionSelected, which still refines it (Craft.NoteWindowLine).
-- At a show or a click a line already known stays: the page's first list has not come yet, the
-- "settling" state (Craft.FillRoute).
local function takeShownLine(listed)
  local last = Craft.state.windowLine
  if last ~= nil and listed ~= true then
    return nil
  end
  local info = openInfo()
  if not info then
    return nil
  end
  local id, parent = info.professionID, info.parentProfessionID
  local professionID = canRead(id) and number(id) or 0
  if type(last) == "table" and number(last.professionID) == professionID then
    return nil
  end
  local line = {
    professionID = professionID,
    parentProfessionID = canRead(parent) and number(parent) or nil,
  }
  Craft.state.windowLine = line
  if listed == true and Craft.state.registered then
    queueRelabel()
  end
  return line
end

-- Brief SC3: a word on the click's fill after it was set (the take back, or what emptied it), kept
-- on the click's trace only, and only the first word.
local function noteAfter(name, word)
  local trace = Craft.state.trace
  if type(trace) == "table" and trace.filledName == name and trace.after == nil then
    trace.after = word
  end
end

--- Brief SC2: notes the page's profession from its Professions.ProfessionSelected (raised whenever its
--- professionID changes, Blizzard_ProfessionsFrame.lua:251-252). Answers what was noted.
--- Brief SC3: the page settling on none (professionID 0) while a click waits for its window means
--- the hidden page handled a list with no trade skill open (inside our filter call, or after it);
--- its first list for the line will then empty the search (Blizzard_ProfessionsFrame.lua:226-236).
--- The click's trace says so ("page reset before show"); the take back still asks the filter.
function Craft.NoteWindowLine(info)
  if type(info) ~= "table" then
    Craft.state.windowLine = nil
    return nil
  end
  local id, parent = info.professionID, info.parentProfessionID
  Craft.state.windowLine = {
    professionID = canRead(id) and number(id) or 0,
    parentProfessionID = canRead(parent) and number(parent) or nil,
  }
  local pending = livePending()
  local trace = Craft.state.trace
  if Craft.state.windowLine.professionID == 0 and pending and type(trace) == "table" and trace.pending == pending then
    trace.after = trace.after or "page reset before show"
  end
  -- Brief SC5: the page's line decides the Show craft words (Craft.FillRoute), so they are drawn
  -- again, a moment on (never inside the client's SetProfessionInfo, which goes on to Refresh at
  -- :255), while the pane listens. A relabel only reads.
  if Craft.state.registered then
    queueRelabel()
  end
  return Craft.state.windowLine
end

--- Brief SC2: follows the page's profession through the client's event bus only (EventRegistry, whose
--- TriggerEvent runs each callback through secureexecuterange, Blizzard_SharedXMLBase/
--- CallbackRegistry.lua:184-204). Answers whether it was taken.
function Craft.WatchWindow()
  local registry = rawget(_G, "EventRegistry")
  if type(registry) ~= "table" or type(registry.RegisterCallback) ~= "function" then
    return false
  end
  if Craft.windowRegistry == registry then
    return true
  end
  local ok = pcall(registry.RegisterCallback, registry, "Professions.ProfessionSelected", function(_, info)
    Craft.NoteWindowLine(info)
  end, Craft)
  if ok then
    Craft.windowRegistry = registry
  end
  return ok
end

--- Brief SC2 (QA item 262, "clicking it did nothing"): whether the client's window shows the line's
--- recipes now: Craft.IsOpen, unless our watcher heard the trade skill close since its last show. On
--- Forever the window also hosts the profession book (Camelot/Blizzard_ProfessionsFrame.xml:79, the
--- BookPage): a trade skill closed behind it leaves the window shown (Camelot/
--- Blizzard_ProfessionsFrame.lua:139-146), and the trade skill API keeps naming the last line after
--- its close (brief PR16), so Craft.IsOpen alone said "open" over the book and a click only brought
--- the window to the front. Asked by Show craft and View profession only; Craft.IsOpen's other
--- callers are left as they were.
function Craft.ShowsLine(skillLine)
  if Craft.state.tradeOpen == false then
    return false
  end
  return Craft.IsOpen(skillLine, lineNameOf(skillLine)) == true
end

--- Brief SC2: whether a Show craft click now can fill the window's search so that the search holds:
--- the client has the name filter, the card has a name and the recipe is learnt (Craft.KnowsRecipe).
--- Brief SC5 (SC4's filters check): and none of the filters the Forever menu offers may hide it
--- (Craft.Narrowed, asked before any step, so a click never closes the window for nothing). The
--- window checks SC2 made here (a window up, the page last on another line or unknown) are the
--- click's route now (Craft.FillRoute); the line stays an argument for the callers. Answers true, or
--- false and why (the trace's words).
function Craft.FillCheck(recipeName, _skillLine, spell)
  if not filterApi() then
    return false, "no search"
  end
  if not (type(recipeName) == "string" and recipeName ~= "") then
    return false, "no name"
  end
  if Craft.KnowsRecipe(spell) ~= true then
    return false, "not learnt"
  end
  if Craft.Narrowed() then
    return false, "filters"
  end
  return true
end

--- Brief SC5 (QA items 284 and 289; SC4's route, its waits gone): the window's state a click that can
--- fill meets, for the line held as Craft.Held answered (the comment above Craft.FILL_WAIT):
--- "reopen" (the window shows the line's recipes and its page is on the line, or has said nothing to
--- us: close, fill, open, in the click), "settling" (it shows the line but its page has not taken it
--- yet), "plain" (the crafting page down, the window shut or on its book page, the page last on the
--- line, and the line held: SC3's one open) or "first" (anything else: the open first, unsearched).
--- Read only.
function Craft.FillRoute(skillLine, held)
  skillLine = number(skillLine)
  local last = Craft.state.windowLine
  local lastOn = professionMatches(last, skillLine)
  if Craft.ShowsLine(skillLine) then
    -- A page that has said nothing to us is on the line it shows (takeShownLine).
    return (lastOn or last == nil) and "reopen" or "settling"
  end
  local down = windowShown() ~= true or Craft.state.tradeOpen == false
  if held == true and lastOn and down then
    return "plain"
  end
  return "first"
end

--- Brief SC5 (the owner, 2026-10-20: "remember for the session whether the client answered our close
--- inside the call"): true once a Show craft close was answered inside the call (the click opened
--- again), false once one was not (from then on a window up on the line reads Find recipe), nil
--- before the first try (assumed to work, so it reads Show craft). The last answer stands. Brief SC6
--- (QA item 293): a close not answered counts only where a show was heard this session
--- (closeAndReopen).
function Craft.ReopenInClick()
  return Craft.state.reopenInClick
end

--- Brief PW1: whether a Show craft click now would fill the window's search (Craft.FillCheck). Feeds
--- the hover's words.
function Craft.WouldFill(recipeName, skillLine, spell)
  return (Craft.FillCheck(recipeName, skillLine, spell)) == true
end

-- Brief SC2: the last Show craft and View profession clicks, for /itemtree debug (Craft.TraceLine).
local function startTrace(kind, line)
  local clock = nil
  local dateFn = globalFn("date")
  if dateFn then
    local ok, text = pcall(dateFn, "%H:%M:%S")
    if ok and type(text) == "string" then
      clock = text
    end
  end
  local trace = { kind = kind, line = line, at = now(), clock = clock }
  if kind == "view" then
    Craft.state.viewTrace = trace
  else
    Craft.state.trace = trace
  end
  return trace
end

-- The click's window, from the client's show: a show for the clicked line within FILL_WAIT. Brief
-- SC3: "shown in the open" where the client showed it inside the open call itself (Craft.Open's
-- inOpen), so the owner's run says which way his client answers.
local function noteShown()
  local info = openInfo()
  local at = now()
  for _, key in ipairs({ "trace", "viewTrace" }) do
    local trace = Craft.state[key]
    local seen = type(trace) == "table" and (trace.window == "shown" or trace.window == "shown in the open")
    if type(trace) == "table" and not seen and professionMatches(info, trace.line) then
      if not (at and trace.at) or at - trace.at <= Craft.FILL_WAIT then
        trace.window = Craft.state.inOpen == true and "shown in the open" or "shown"
      end
    end
  end
end

--- Brief SC3 (QA items 281 and 282, the owner's ruling A): sets the client's recipe name filter to the
--- recipe the way the window's own search box sets it, then clears the level filter
--- (Blizzard_Professions.lua:1388-1389), for Craft.ShowCraft to make the open call straight after:
--- the window's OnShow then copies the name into its box (Blizzard_ProfessionsCrafting.lua:349).
--- Only where none of the filters the Forever menu offers may hide the recipe (Craft.Narrowed: an
--- empty list over a search would show the player nothing). The name is the client's own
--- (Craft.FillName). Answers the name set, or nil and why not (the trace's words).
function Craft.FillBeforeOpen(spell, recipeName)
  local api = filterApi()
  if not api then
    return nil, "no search"
  end
  if Craft.Narrowed() then
    return nil, "filters"
  end
  local name = Craft.FillName(spell, recipeName)
  if not name then
    return nil, "no name"
  end
  if not pcall(api.SetRecipeItemNameFilter, name) then
    return nil, "error"
  end
  if type(api.SetRecipeItemLevelFilter) == "function" then
    pcall(api.SetRecipeItemLevelFilter, 0, 0)
  end
  Craft.state.filled = name
  return name
end

--- Brief SC2: at a show with no click waiting (the player's own open, or View profession), an earlier
--- fill of ours is taken back while that is clean: out of combat, the trade skill open, the client's
--- window not shown yet (its OnShow then copies the emptied search), and the filter still exactly our
--- name. Either way it is ours no more: once the box has shown it, it is as the player's own search.
--- Brief SC3: why names the other take backs, made at once: "other line" (brief FX-AF: the client
--- showed another line than the click asked), "no open" (the client refused the open, so no window
--- will copy the name) and "before open" (Craft.Open: just before another open call of ours); with
--- no trade skill open for the last two. Answers whether it cleared; the click's trace says what
--- happened ("cleared at the next open", "taken back (other line)", "left at the next open",
--- "searched since").
function Craft.TakeBack(why)
  local name = Craft.state.filled
  if not name then
    return false
  end
  Craft.state.filled = nil
  local left = why and ("left (" .. tostring(why) .. ")") or "left at the next open"
  local function note(word)
    noteAfter(name, word)
    return false
  end
  if Craft.InCombat() or windowShown() == true then
    return note(left)
  end
  if why ~= "no open" and why ~= "before open" and not openInfo() then
    return note(left)
  end
  local api = filterApi()
  if not (api and type(api.GetRecipeItemNameFilter) == "function") then
    return note(left)
  end
  local ok, current = pcall(api.GetRecipeItemNameFilter)
  -- Brief SC5 (SC4's compare): as the client's own box compares (sameSearch).
  if not ok or not canRead(current) or not sameSearch(current, name) then
    return note("searched since")
  end
  if not pcall(api.SetRecipeItemNameFilter, "") then
    return note(left)
  end
  if type(api.SetRecipeItemLevelFilter) == "function" then
    pcall(api.SetRecipeItemLevelFilter, 0, 0)
  end
  note(why and ("taken back (" .. tostring(why) .. ")") or "cleared at the next open")
  return true
end

-- Brief SC3: at the click's own show, whether the filter still holds the click's name; where it does
-- not, it is ours no more. Brief SC5 (SC4's honest words, QA item 282: "emptied before show" while the
-- box had filled): SC3 compared exactly, so a filter the client reads back in its own case counted as
-- emptied. Now compared as the client's box compares (sameSearch), and the trace says only what was
-- read: "kept at show (case differs)", "filter read empty at show" or "filter read other text at show".
local function checkKept()
  local name = Craft.state.filled
  local api = filterApi()
  if not (name and api and type(api.GetRecipeItemNameFilter) == "function") then
    return
  end
  local ok, current = pcall(api.GetRecipeItemNameFilter)
  if not (ok and canRead(current)) or current == name then
    return
  end
  if sameSearch(current, name) then
    noteAfter(name, "kept at show (case differs)")
    return
  end
  if current == nil or current == "" then
    noteAfter(name, "filter read empty at show")
  else
    noteAfter(name, "filter read other text at show")
  end
  Craft.state.filled = nil
end

--- Brief SC2: the client's own trade skill events, heard on our frame from this file's load
--- (Craft.WATCH_EVENTS). The answer to an open ends Craft.Open's gap; the last click's trace notes the
--- window showing. Brief SC3: the fill was set before the open, so a show only settles it: the
--- click's own show (its line, within FILL_WAIT) keeps it; a show of another line takes it back at
--- once (brief FX-AF); a show with no click waiting takes an earlier fill back (Craft.TakeBack); a
--- close drops the click's wait (brief FX-AF), so the next show is the player's own. Answers what it
--- heard ("show", "close", "list"), or nil. Brief SC5: a close heard inside our own close call (the
--- Show craft click's, closeAndReopen) is noted for it (closeHeard). Brief SC6 (QA item 293): a list
--- with a trade skill open since a show we heard, the client's data settled (sourceChanging), takes
--- the shown line as the page's (takeShownLine). Nothing here opens or closes anything.
function Craft.OnWindowEvent(event)
  local state = Craft.state
  if event == "TRADE_SKILL_LIST_UPDATE" then
    if state.tradeOpen == true and not sourceChanging() then
      takeShownLine(true)
    end
    return "list"
  end
  if event == "TRADE_SKILL_CLOSE" then
    state.openAnswered = true
    state.tradeOpen = false
    state.pendingFill = nil
    -- Brief SC5: a close heard inside our own close call is the client's answer in the call.
    if state.inClose == true then
      state.closeHeard = true
    end
    return "close"
  end
  if event ~= "TRADE_SKILL_SHOW" then
    return nil
  end
  local pending = livePending()
  state.openAnswered = true
  state.tradeOpen = true
  noteShown()
  takeShownLine()
  if not pending then
    Craft.TakeBack()
    return "show"
  end
  state.pendingFill = nil
  if professionMatches(openInfo(), pending.line) then
    checkKept()
  else
    Craft.TakeBack("other line")
  end
  return "show"
end

-- Brief SC2: the client's events our watcher hears, each raised only as a trade skill opens or
-- closes. Brief SC3: TRADE_SKILL_DATA_SOURCE_CHANGING went with the fill made after the open.
-- Brief SC6 (QA item 293): and the list the page handles (Blizzard_ProfessionsFrame.lua:148-171), read
-- only, for the page's line (takeShownLine).
Craft.WATCH_EVENTS = { "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE" }

--- Brief SC2: our own frame for the client's trade skill events, built once as this file loads (the
--- folder loads at login, or on the tab's first show), never under a client frame, its events on for
--- the session (Craft.WATCH_EVENTS). Answers the frame, or nil without CreateFrame.
function Craft.BuildWatcher()
  if Craft.watcher then
    return Craft.watcher
  end
  local create = globalFn("CreateFrame")
  if not create then
    return nil
  end
  local ok, frame = pcall(create, "Frame")
  if not ok or type(frame) ~= "table" or type(frame.RegisterEvent) ~= "function" then
    return nil
  end
  for _, event in ipairs(Craft.WATCH_EVENTS) do
    pcall(frame.RegisterEvent, frame, event)
  end
  if type(frame.SetScript) == "function" then
    pcall(frame.SetScript, frame, "OnEvent", function(_, event)
      Craft.OnWindowEvent(event)
    end)
  end
  Craft.watcher = frame
  return frame
end
Craft.BuildWatcher()
Craft.WatchWindow()

-- Brief SC5: a word on the click's own steps, for /itemtree debug ("steps ...", Craft.TraceLine).
local function addStep(trace, word)
  if type(trace) ~= "table" then
    return
  end
  trace.steps = trace.steps or {}
  trace.steps[#trace.steps + 1] = word
end

-- Brief SC3's fill and open, in the click: the click's wait noted, the recipe name filter set
-- (Craft.FillBeforeOpen) and the open call made straight after (Craft.Open, past OPEN_GAP with
-- force). An open the client refuses takes the fill back at once. Answers "fill", "opened" (the
-- filter could not be set; the window opens unsearched) or nil (no open made).
local function fillAndOpen(trace, skillLine, spell, recipeName, force)
  local pending = { line = skillLine, spell = number(spell), name = recipeName, at = now() }
  trace.pending = pending
  Craft.state.pendingFill = pending
  local name, failed = Craft.FillBeforeOpen(spell, recipeName)
  if name then
    trace.fill, trace.filledName = "set before open", name
  else
    Craft.state.pendingFill, pending = nil, nil
    trace.fill = "skipped (" .. tostring(failed) .. ")"
  end
  local made = Craft.Open(skillLine, force)
  trace.open = Craft.state.openWord
  if not made then
    if pending then
      if Craft.state.pendingFill == pending then
        Craft.state.pendingFill = nil
      end
      Craft.TakeBack("no open")
    end
    return nil
  end
  if pending then
    return "fill"
  end
  return "opened"
end

-- Brief SC5 "reopen": the window up on the line, its page on it. C_TradeSkillUI.CloseTradeSkill, in
-- the click; where the client answered it inside the call (our frame heard TRADE_SKILL_CLOSE in it,
-- or the window no longer shows), the fill and the open again, in the same click ("reopened"). Where
-- it did not, nothing more in this click: no open, no filter ("closing"); the window shuts as the
-- client answers, and the next click is "plain". Craft.ReopenInClick keeps which way it went. Where
-- the close cannot be made (no such call, no open call to follow, or the close raising) the window
-- comes in front with its search left, as before SC4 ("open").
local function closeAndReopen(trace, skillLine, spell, recipeName)
  local api = tradeApi()
  local cannot = nil
  if not (api and type(api.CloseTradeSkill) == "function") then
    cannot = "no close"
  elseif openHeldBack(true) then
    cannot = "no open"
  end
  if cannot then
    Craft.ProfessionsToFront()
    trace.fill = "skipped (" .. cannot .. ")"
    addStep(trace, "not closed")
    return "open"
  end
  Craft.state.pendingFill = nil
  -- Brief SC6 (QA item 293): whether a show was heard this session (the trade skill open as far as
  -- our watcher knows) before this close.
  local showHeard = Craft.state.tradeOpen == true
  Craft.state.inClose, Craft.state.closeHeard = true, false
  local fine = pcall(api.CloseTradeSkill)
  Craft.state.inClose = false
  if not fine then
    Craft.ProfessionsToFront()
    trace.fill = "skipped (close error)"
    addStep(trace, "close error")
    return "open"
  end
  if Craft.state.closeHeard ~= true and windowShown() ~= false then
    -- Brief SC6 (QA item 293): counted as the client's answer only where a show was heard this
    -- session: a window on its book page with no trade skill open (the tab turned on mid session, the
    -- API still naming the last line) has nothing to close, so no answer comes. Either way the trade
    -- skill is taken as closed, so the next click is the plain one (Craft.FillRoute).
    if showHeard then
      Craft.state.reopenInClick = false
    end
    Craft.state.tradeOpen = false
    trace.fill, trace.open = "skipped (close not answered in the click)", "not reopened"
    addStep(trace, "close sent, not answered in the click")
    return "closing"
  end
  Craft.state.reopenInClick = true
  addStep(trace, "closed")
  trace.window = "not"
  local made = fillAndOpen(trace, skillLine, spell, recipeName, true)
  if made == "fill" then
    addStep(trace, "reopened")
    return "reopened"
  elseif made == "opened" then
    addStep(trace, "reopened unsearched")
    return "opened"
  end
  addStep(trace, "not reopened (" .. tostring(Craft.state.openWord) .. ")")
  return nil
end

-- Brief SC5: why a click that can fill opens the line unsearched first ("first"), for the trace.
local function firstWhy(shown)
  if Craft.state.windowLine == nil then
    return "window last unknown"
  end
  if shown and Craft.state.tradeOpen ~= false then
    return "window on another profession"
  end
  return "window last on another profession"
end

-- Brief SC5: the click past its refusals (combat, the demo, a line not held), by the window's state
-- (Craft.FillRoute). Answers Craft.ShowCraft's answer.
local function showClick(trace, skillLine, spell, recipeName, held)
  local fills, why = Craft.FillCheck(recipeName, skillLine, spell)
  -- Brief PW2: only for a line the client's skills say is held. Where nothing has answered yet
  -- (held nil) the line may not be the character's and no window may show.
  if held ~= true then
    fills, why = false, "skills not read yet"
  end
  local route = Craft.FillRoute(skillLine, held)
  if Craft.ShowsLine(skillLine) then
    takeShownLine()
    trace.open, trace.window = "already", "shown"
    if fills and route == "reopen" then
      return closeAndReopen(trace, skillLine, spell, recipeName)
    end
    -- Brief PW1 (238 d): the window that already shows the line comes in front of ItemTree's, its
    -- search left as it is.
    Craft.ProfessionsToFront()
    trace.fill = "skipped (" .. tostring(fills and "page not on the line yet" or why) .. ")"
    return "open"
  end
  local shown = windowShown() == true
  trace.window = shown and "shown" or "not"
  local blocked = openHeldBack(shown)
  if blocked then
    Craft.state.openWord = blocked
    trace.open, trace.fill = blocked, "skipped (" .. tostring(fills and "no open" or why) .. ")"
    return nil
  end
  -- A click that opens replaces an earlier click's wait.
  Craft.state.pendingFill = nil
  if fills and route == "plain" then
    return fillAndOpen(trace, skillLine, spell, recipeName, shown)
  end
  trace.fill = "skipped (" .. tostring(fills and firstWhy(shown) or why) .. ")"
  local made = Craft.Open(skillLine, shown)
  trace.open = Craft.state.openWord
  if not made then
    return nil
  end
  if fills then
    addStep(trace, "opened first")
    return "opened first"
  end
  return "opened"
end

--- Brief SC1 (QA item 212): the Show craft button's OnClick, its first call. Opens the client's
--- profession window on the line with the one client call Craft all and the queue have made since
--- brief PR21, C_TradeSkillUI.OpenTradeSkill (Craft.Open), switching a window open on another
--- line at once (the queue's press does the same, brief PR22). Nothing in combat, under the
--- pretend professions, or for a line the character does not have.
--- It never selects the recipe. Checked on github.com/Gethe/wow-ui-source, branch forever
--- (1.60.1.70425): the one client call that moves the window's selection,
--- C_TradeSkillUI.OpenRecipe (TradeSkillUIDocumentation.lua:1088), raises OPEN_RECIPE_RESPONSE,
--- a SynchronousEvent (Blizzard_APIDocumentationGenerated/TradeSkillUIDocumentation.lua:
--- 1255-1264), so the Professions frame's handler would run inside our call, as ItemTree: it
--- rebuilds the crafting page or writes openRecipeResponse onto the frame
--- (Blizzard_Professions/Blizzard_ProfessionsFrame.lua:176-203), and its next list update reads
--- that field and calls ShowUIPanel (:158-165). That taints the window the player crafts from
--- (brief PQ1 found the same, 2026-10-09). ProfessionsUtil.OpenProfessionFrameToRecipe
--- (Blizzard_FrameXMLUtil/ProfessionsUtil.lua:78-105) is Blizzard's own path and calls the
--- frame's methods, so it is not ours to call either. Answers "open" (the window already shows the
--- line), "opened", or nil.
--- Brief PW1 (QA item 239 c): spell and recipeName are the card's. Brief SC3 (QA items 281 and 282,
--- the owner's ruling A): where no trade skill window shows, Craft.FillCheck allows and the open will
--- be made, the recipe name filter is set immediately before the open call (Craft.FillBeforeOpen),
--- so the window's own OnShow copies it into its search box: answers "fill". The click's wait is
--- noted before both calls (the client's show may come inside the open call) and settled by its
--- show (Craft.OnWindowEvent). A click whose open is held back (Craft.OPEN_GAP) changes nothing, so an
--- earlier click's fill stands; an open the client refuses takes the fill back at once. Brief PW1
--- (238 d): the window that already shows the line comes in front of ItemTree's, its search left as
--- it is. Every click is traced for /itemtree debug ("fill set before open", or "skipped (why)").
--- Brief SC5 (QA items 284 and 289, the owner's choice A): the click goes by the window's state it
--- meets (Craft.FillRoute; the order and why: the comment above Craft.FILL_WAIT), every open and close
--- inside this call. "plain": SC3's fill and one open ("fill"). "reopen": CloseTradeSkill, then, where
--- the client answered it inside the call, the fill and the open again ("reopened"); where it did not,
--- nothing more ("closing": the window shuts as the client answers, and the next click is "plain").
--- "settling": the window comes in front ("open"). "first": the line opens unsearched ("opened
--- first"); the next click fills. Where the click cannot fill (Craft.FillCheck, or a line the client's
--- skills have not answered for, brief PW2) it opens as before ("opened"), or brings a window already
--- on the line in front ("open"). The buttons' words follow (Craft.ShowButton), relabelled a moment on.
function Craft.ShowCraft(skillLine, spell, recipeName)
  skillLine = number(skillLine)
  local trace = startTrace("show", skillLine)
  if not skillLine then
    trace.open = "no line"
    return nil
  end
  if Craft.Pretend() then
    trace.open = "demo"
    return nil
  end
  if Craft.InCombat() then
    trace.open = "combat"
    return nil
  end
  local held = Craft.Held(skillLine)
  trace.held = held
  if held == false then
    trace.open = "not held"
    return nil
  end
  local answer = showClick(trace, skillLine, spell, recipeName, held)
  -- Brief SC5: the words on every Show craft button follow what the click did (the client's own show
  -- and close relabel them too, Craft.OnEvent). A relabel only reads.
  if Craft.state.registered then
    queueRelabel()
  end
  return answer
end

--- Brief SC2 (QA item 263): the View profession button's state for the line on screen now
--- (Craft.ViewState) from the client: held, the demo, combat and whether the window shows the line
--- already (asked only while a window shows).
function Craft.ViewButton(skillLine)
  skillLine = number(skillLine)
  local open = false
  if windowShown() == true then
    open = Craft.ShowsLine(skillLine)
  end
  return Craft.ViewState({
    held = Craft.Held(skillLine),
    pretend = Craft.Pretend(),
    combat = Craft.InCombat(),
    lineName = lineNameOf(skillLine),
    open = open,
  })
end

--- Brief SC2 (QA item 263): the View profession button's OnClick, its first call: the client's
--- window on the line, a standard open (no search, no recipe), with the one call Show craft makes
--- (Craft.Open), switching a window open on another line at once, and brought in front as PW1's
--- layering does. Nothing in combat, under the demo, or for a line not held (brief VP1: every line
--- held opens, Fishing too). A Show craft fill still waiting is dropped. Answers "open" (the window
--- shows the line already), "opened", or nil. Brief SC3: dropped only where this open will be made
--- (Craft.Open then takes the fill back just before its call); one held back by Craft.OPEN_GAP leaves
--- the Show craft click's wait, so that click's own show keeps its fill.
function Craft.ViewProfession(skillLine)
  skillLine = number(skillLine)
  local trace = startTrace("view", skillLine)
  if not skillLine then
    trace.open = "no line"
    return nil
  end
  if Craft.Pretend() then
    trace.open = "demo"
    return nil
  end
  if Craft.InCombat() then
    trace.open = "combat"
    return nil
  end
  local held = Craft.Held(skillLine)
  trace.held = held
  if held == false then
    trace.open = "not held"
    return nil
  end
  if Craft.ShowsLine(skillLine) then
    Craft.ProfessionsToFront()
    trace.open, trace.window = "already", "shown"
    return "open"
  end
  local shown = windowShown() == true
  trace.window = shown and "shown" or "not"
  if not openHeldBack(shown) then
    Craft.state.pendingFill = nil
  end
  local made = Craft.Open(skillLine, shown)
  trace.open = Craft.state.openWord
  if made then
    return "opened"
  end
  return nil
end

--- Brief SC2 (QA item 262): /itemtree debug's lines (UI/Slash.lua Slash.DebugLines): the last Show
--- craft click this session, or "Show craft: none this session", and the last View profession click
--- where there was one (Craft.TraceLine). Brief SC5: then "Show craft reopen in click: yes", "no" or
--- "not tried" (Craft.ReopenInClick).
function Craft.DebugLines()
  local at = now()
  local lines = {}
  lines[#lines + 1] = Craft.TraceLine(Craft.state.trace, at) or "Show craft: none this session"
  local view = Craft.TraceLine(Craft.state.viewTrace, at)
  if view then
    lines[#lines + 1] = view
  end
  -- Brief SC5 (the owner, 2026-10-20): whether the client answered our close inside the call this
  -- session (Craft.ReopenInClick).
  local reopen = Craft.ReopenInClick()
  lines[#lines + 1] = "Show craft reopen in click: "
    .. (reopen == true and "yes" or reopen == false and "no" or "not tried")
  return lines
end

--- Registers a listener, called (under pcall) after a craft, a bag change or combat moves the
--- button. Answers whether it was taken.
function Craft.OnChange(fn)
  if type(fn) ~= "function" then
    return false
  end
  local listeners = Craft.state.listeners
  listeners[#listeners + 1] = fn
  return true
end

--- Calls every listener now.
function Craft.Fire()
  Craft.state.pending = false
  for _, fn in ipairs(Craft.state.listeners) do
    pcall(fn)
  end
  return true
end

--- An event: the window's show and close are noted (Craft.IsOpen's last resort), and one relabel
--- is queued THROTTLE seconds on, however many events come between. The relabel only calls the
--- listeners; it never crafts.
function Craft.OnEvent(event)
  if event == "NEW_RECIPE_LEARNED" then
    -- Brief PR24: a recipe learnt; the kept "not learnt" answers are asked again.
    Craft.state.notLearnt = {}
  end
  if event == "TRADE_SKILL_SHOW" then
    Craft.state.windowOpen = true
  elseif event == "TRADE_SKILL_CLOSE" then
    Craft.state.windowOpen = false
  end
  return queueRelabel()
end

local function eventFrame()
  if Craft.frame then
    return Craft.frame
  end
  local create = globalFn("CreateFrame")
  if not create then
    return nil
  end
  local ok, frame = pcall(create, "Frame")
  if not ok or type(frame) ~= "table" or type(frame.RegisterEvent) ~= "function" then
    return nil
  end
  if type(frame.SetScript) == "function" then
    pcall(frame.SetScript, frame, "OnEvent", function(_, event)
      Craft.OnEvent(event)
    end)
  end
  Craft.frame = frame
  return frame
end

local function register(on)
  local frame = eventFrame()
  if not frame then
    return false
  end
  local state = Craft.state
  if on and not state.registered then
    for _, event in ipairs(Craft.EVENTS) do
      pcall(frame.RegisterEvent, frame, event)
    end
    state.registered = true
  elseif not on and state.registered then
    if type(frame.UnregisterAllEvents) == "function" then
      pcall(frame.UnregisterAllEvents, frame)
    elseif type(frame.UnregisterEvent) == "function" then
      for _, event in ipairs(Craft.EVENTS) do
        pcall(frame.UnregisterEvent, frame, event)
      end
    end
    state.registered = false
  end
  return true
end

--- The pane's Show (true) and Hide (false): the events are heard only in between. Once called,
--- the lazy watch below stands aside.
function Craft.Watch(on)
  local state = Craft.state
  state.managed = true
  state.lazy = false
  if on ~= true then
    state.pending = false
  end
  return register(on == true)
end

-- The lazy watch's idle check: the events go once no ButtonState was asked for IDLE seconds.
local function idleCheck()
  local state = Craft.state
  if state.managed or not state.lazy then
    return
  end
  local at, last = now(), state.lastAsk
  local left = (at and last) and (Craft.IDLE - (at - last)) or 0
  local timer = rawget(_G, "C_Timer")
  if left > 0.01 and type(timer) == "table" and type(timer.After) == "function" then
    pcall(timer.After, left, idleCheck)
    return
  end
  state.lazy = false
  register(false)
end
Craft.IdleCheck = idleCheck

-- Where the pane never calls Watch, the first ButtonState turns the events on, and the idle check
-- turns them off after IDLE seconds with no ask.
ensureLazy = function()
  local state = Craft.state
  state.lastAsk = now()
  if state.managed or state.lazy then
    return
  end
  if not register(true) then
    return
  end
  state.lazy = true
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    pcall(timer.After, Craft.IDLE, idleCheck)
  end
end


return Craft
