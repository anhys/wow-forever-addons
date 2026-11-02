-- The ItemTree tooltip block. Implements design component tooltip/Tooltip.jsx: a blank
-- spacer with a hairline rule drawn across it, then at most four lines under the client's
-- own item lines.
--
--   0 divider       the blank spacer, with a gold dim hairline across its middle
--   1 status line   "[new] New in Forever" or "[changed] Changed in Forever", title gold,
--                   "[changed] Removed in Forever" in removed red, otherwise the ItemTree
--                   mark and "Undiscovered in Forever", "Discovered on your realm" or "Not in
--                   ItemTree data", muted (Tooltip.ItemState decides which). An item Forever
--                   did not change has no status line at all (brief W27: the owner found
--                   "No change from Classic" unnecessary)
--   2 uses line     "Used in 6 recipes, 1 quest", body cream, or the muted no uses line, or
--                   the rest of the sentence the status line started for an item this build
--                   withholds (Tooltip.StateLine)
--   3 hint          "Press %s for the full tree" from the key binding, hint grey
--
-- An item that disenchants used to add "Disenchants into predicted results" between the uses
-- line and the hint. Brief W29 dropped it (the owner found it unhelpful): the window's
-- Disenchants into tab is where those results are read.
--
-- Four lines is still the cap, and no sentence is ever on two of them: a line whose words are
-- already in the block is dropped where it would have been added, so the status line and the
-- line under it can both reach for the same sentence and only the first of them draws it.
--
-- The status line is present while badges are on for every item but an unchanged one (brief
-- W27), so an item ItemTree knows nothing about still says so rather than showing no block at
-- all, and it always leads with an icon, including on the lines that report no change: the mark
-- is the addon's signature in a tooltip, and a player who has never heard of ItemTree is meant to
-- notice it. The icon is an
-- escape inside the line's own text (Assets.Markup), not a texture, so the client draws it
-- with the words, it survives the rebuild the way the words do, and there is nothing to
-- place, hide or leak. Nothing is added to the line count: the icon rides the status line.
--
-- The divider is the other way round: a hairline texture parented to the tooltip and drawn
-- across the blank spacer the block already began with, so it costs no line either. Why a
-- texture and not an escape is argued where the rule is built, below the divider comment.
--
-- Brief E88: with the window's Show classic diff tick box on (Tooltip.ShowChanges), a changed
-- item's status line is followed by what changed since Classic Era, one line per change indented
-- one space, in the words and the convention the tree's change rows draw (Tooltip.ChangeLines:
-- since brief Q9a the old value dimmed and struck through, the new value plain), at most
-- Tooltip.MAX_CHANGE_LINES of them then "and N more changes". They ride outside the four line
-- cap, because they are the status line's detail rather than facts of their own. Off, the block
-- is exactly what it was.
--
-- The block never says which game build the data is for (brief W32: the owner reads that with
-- /itemtree debug, which prints ItemTree.DataBuildLine and ItemTree.DataStatusLine). The four
-- lines above are all there is, so nothing ever has to give up its place to fit.
--
-- Tooltip.OnItem returns one outcome string on every path, Tooltip.stats counts what the
-- client asked for, and Tooltip.trace (toggled by /itemtree trace) prints one chat line per
-- call. All three are in memory only: nothing here is written to saved variables.
--
-- Three delivery paths exist, because what a client offers varies: the tooltip data system post
-- calls, the Classic OnTooltipSetItem script, and post hooks on the item setter methods
-- themselves, which predate the data system and work whether or not the client has one. The
-- typed post call is the right one and is taken wherever the client has it; the AllTypes post
-- call and the setter hooks are fallbacks, taken only where it could not be. See Tooltip.Install.
-- The rendered guard drops whichever call arrives second, and is cleared when the tooltip hides
-- or is cleared for a rebuild.
--
-- Tooltip.CachedLines memoises the block per item id, because a client that supports data
-- refresh clears and rebuilds a tooltip that is still on screen several times a second, and
-- every rebuild runs the post call again. Tooltip.recent keeps the last few trace lines for
-- /itemtree report. Both are in memory only, like the counters.
--
-- Tooltip.BuildLines, Tooltip.CachedLines, Tooltip.Icon, Tooltip.ItemIdFromLink and
-- Tooltip.TraceLine are pure: no WoW API, no frames, so busted and the browser harness run
-- them directly. Everything from the divider comment down is guarded.
--
-- Every line carries text and label: text is what the client draws, markup and all, and label
-- is the same line with no markup in it, for anything that reads the block as words.
local _, ItemTree = ...

local Tooltip = {}
ItemTree.Tooltip = Tooltip

-- Brief SV1: whether a client value may be read (Core/Util.lua Util.CanRead). The typed item post
-- call is only handed item data, which the client never marks secret, but the AllTypes fallback
-- sees unit tooltips too, whose fields are a creature's identity and can be secret in combat, and
-- a chat line's link can be secret in an instance (SecretInChatMessagingLockdown).
local canRead = ItemTree.Util.CanRead

local Theme = ItemTree.Theme
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

Tooltip.MAX_LINES = 4
-- Brief E88: the change lines under the status line, before "and N more changes" takes over.
Tooltip.MAX_CHANGE_LINES = 6

local COLOR_TITLE = "ITEMTREE_COLOR_TEXT_TITLE"
local COLOR_BODY = "ITEMTREE_COLOR_TEXT_BODY"
local COLOR_MUTED = "ITEMTREE_COLOR_TEXT_MUTED"
local COLOR_HINT = "ITEMTREE_COLOR_TEXT_HINT"
-- Removed reuses the Changed medallion, because there is no removed medallion to draw and an
-- inline escape cannot be desaturated or slashed the way UI/Badges.lua composes one. So the
-- colour is what tells the two apart in a tooltip.
local COLOR_REMOVED = "ITEMTREE_COLOR_SEMANTIC_REMOVED"

-- The icon is drawn at the tooltip badge size, 14, which is a tooltip line's own text height.
local ICON_SIZE_KEY = "ITEMTREE_BADGE_SIZE_TOOLTIP"
local ICON_SIZE_FALLBACK = 14

-- Medallion art per badge kind, the three kinds a status line can carry. UI/Badges.lua owns
-- the mapping and is read first; this is what the block draws on a client where Badges did not
-- load, and it is why Removed and Changed share a key.
local BADGE_ART = {
  -- The New star in silver blue (brief E80). The window draws the New medallion greyed and
  -- tinted, which an escape cannot do, so the line draws the star the badge falls back to.
  new = "BADGE_NEW",
  -- The New star in purple. An escape cannot take a medallion's colour off, so the tinted New
  -- medallion the window draws for this kind is written as the star the badge falls back to.
  sod = "BADGE_SOD",
  changed = "BADGE_ART_CHANGED",
  removed = "BADGE_ART_CHANGED",
}

-- The square logo mark leads the two lines that report no change. Not LOGO: that one is wider
-- than it is tall and a markup escape is square.
local NEUTRAL_ART = "LOGO_MARK"

-- The chest the window draws in the corner of a discovered item's icon (Core/Graph.lua
-- Graph.DiscoveryMark), on the one status line that says the same thing in words, so the mark on
-- the row and the line in the block read as one idea rather than as two separate notices. The
-- block adds no second sentence about it: "Discovered on your realm" is the sentence.
local DISCOVERED_ART = "ICON_DISCOVERED_MARK"

Tooltip.BADGE_ART = BADGE_ART
Tooltip.NEUTRAL_ART = NEUTRAL_ART
Tooltip.DISCOVERED_ART = DISCOVERED_ART

-- Brief TB7: the label at the right end of the section's first line, in the muted grey the Keep
-- lines use (Core/Keep.lua Keep.MUTED_COLOR, the same key). The item page is ours alone and never
-- draws it.
Tooltip.LABEL_COLOR = COLOR_MUTED

--- The label's words. Pure.
function Tooltip.LabelText()
  return L["ItemTree"]
end

-- "|cff...|Hitem:2589:0:0:...|h[Linen Cloth]|h|r" or "item:2589" -> 2589.
function Tooltip.ItemIdFromLink(link)
  if not canRead(link) then
    return nil
  end
  if type(link) == "number" then
    return link
  end
  if type(link) ~= "string" then
    return nil
  end
  local id = link:match("item:(%d+)")
  if id then
    return tonumber(id)
  end
  return nil
end

local function settingOn(settings, key)
  local value = settings[key]
  if value == nil then
    return true
  end
  return value and true or false
end

local function plural(count, one, many)
  if count == 1 then
    return string.format(L[one], count)
  end
  return string.format(L[many], count)
end

-- Brief K30 addendum (owner QA 2026-10-09, Bottle of Dalaran Noir: "why doesn't it say used for
-- First Aid?"): the recipes part of the uses line names the professions where every recipe belongs
-- to one or two that the tables name (skills, a summary's usedInSkills { { name, count } }, adding
-- up to count): "Used in 1 First Aid recipe", "Used in 3 First Aid recipes", "Used in 3 recipes:
-- First Aid, Cooking"; three or more, or any recipe no profession names, "Used in 3 recipes" as
-- before. Brief BQ5: Graph.Summary carries usedInSkills, out of the core set's Summary module at
-- login and the loaded recipe tables after, which the pipeline keeps alike. Pure.
function Tooltip.UsedInWords(count, skills)
  count = tonumber(count) or 0
  if type(skills) == "table" and (#skills == 1 or #skills == 2) then
    local total = 0
    for _, entry in ipairs(skills) do
      total = total + (type(entry) == "table" and tonumber(entry.count) or 0)
    end
    if total == count and #skills == 1 then
      if count == 1 then
        return string.format(L["Used in %d %s recipe"], count, tostring(skills[1].name))
      end
      return string.format(L["Used in %d %s recipes"], count, tostring(skills[1].name))
    end
    if total == count then
      return string.format(L["Used in %d recipes: %s, %s"], count, tostring(skills[1].name), tostring(skills[2].name))
    end
  end
  return plural(count, "Used in %d recipe", "Used in %d recipes")
end

-- Brief BQ5 (owner QA item 17, Minor Spellblasting Potion: "most items are made by one recipe, so the
-- count says little"): the made by part of the uses line, named by the professions of the recipes
-- that make the item where every one of them belongs to a profession the tables name (skills, a
-- summary's producedBySkills { { line, name, count } }, adding up to count). One profession: its
-- glyph (UI/Assets.lua ForSkill, none for a line with no glyph of its own) and its name, "Made by
-- [glyph] Alchemy"; two or three: the names, "Made by Alchemy, Tailoring"; more, or any recipe no
-- profession names: the count, "Made by 4 recipes", as before. Answers the text and the same words
-- with no glyph. Pure.
Tooltip.MADE_BY_NAMES = 3
function Tooltip.MadeByWords(count, skills)
  count = tonumber(count) or 0
  if type(skills) == "table" and #skills >= 1 and #skills <= Tooltip.MADE_BY_NAMES then
    local total = 0
    local names = {}
    for _, entry in ipairs(skills) do
      total = total + (type(entry) == "table" and tonumber(entry.count) or 0)
      if type(entry) == "table" and type(entry.name) == "string" then
        names[#names + 1] = entry.name
      end
    end
    if total == count and #names == #skills then
      if #names == 1 then
        local plain = string.format(L["Made by %s"], names[1])
        local assets = ItemTree.Assets
        local key = nil
        if type(assets) == "table" and type(assets.ForSkill) == "function" then
          local ok, found = pcall(assets.ForSkill, tonumber(skills[1].line))
          if ok and type(found) == "string" and found ~= "CAT_NOTE" then
            key = found
          end
        end
        local glyph = Tooltip.Icon(key)
        if glyph ~= "" then
          return string.format(L["Made by %s"], glyph .. " " .. names[1]), plain
        end
        return plain, plain
      end
      local joined = names[1]
      for at = 2, #names do
        joined = string.format(L["%s, %s"], joined, names[at])
      end
      local text = string.format(L["Made by %s"], joined)
      return text, text
    end
  end
  local text = plural(count, "Made by %d recipe", "Made by %d recipes")
  return text, text
end

-- Brief AA-RB (the owner's QA item 219, 2026-10-17: "When we know there are uses (but not for your
-- current faction) make the wording 'No known uses for [your_faction]'"): the words for a summary that
-- counts no use, "No known uses for Alliance" (or Horde, the player's own side) where every use it had
-- was a quest of the other side that Tooltip.TooltipSummary or Tooltip.WithoutOtherSide took out
-- (summary.noUsesSide, 1 Alliance or 2 Horde), else "No known uses". The literals are written out so
-- the locale sweep sees them. Pure.
function Tooltip.NoUsesWords(summary)
  local side = type(summary) == "table" and summary.noUsesSide or nil
  if side == 1 then
    return L["No known uses for Alliance"]
  elseif side == 2 then
    return L["No known uses for Horde"]
  end
  return L["No known uses"]
end

-- Brief AA-RB (QA item 219): the side summary.noUsesSide names, worked out where a count takes the
-- other side's quests out: side (the player's, 1 or 2) where other (how many quests were taken out as
-- the other side's) is above 0 and nothing else is left counted, total less the quests the item only
-- comes from (rewards, never a use) and those other quests. nil otherwise. Pure.
function Tooltip.NoUsesSide(summary, other, rewards, side)
  if type(summary) ~= "table" or (side ~= 1 and side ~= 2) then
    return nil
  end
  other = tonumber(other) or 0
  if other <= 0 then
    return nil
  end
  local left = (tonumber(summary.total) or 0) - (tonumber(rewards) or 0) - other
  if left > 0 then
    return nil
  end
  return side
end

-- Uses line in the client's number style. Returns text, colour key and (brief BQ5) the same words
-- with no glyph, for the line's label.
function Tooltip.UsesText(summary)
  if not summary then
    return L["No known uses"], COLOR_MUTED
  end
  local parts = {}
  -- Brief BQ25a: a part's words with no glyph where its drawn words carry one.
  local plainParts, marked = {}, false
  if (summary.usedIn or 0) > 0 then
    parts[#parts + 1] = Tooltip.UsedInWords(summary.usedIn, summary.usedInSkills)
  end
  if (summary.quests or 0) > 0 then
    local words
    -- Brief BQ25a (QA item 68, BQ24 item 23's rule): beside a [Use] "starts a quest" block, which
    -- names the quest it starts, the others alone: "and 1 other quest".
    if summary.questsOthers then
      words = plural(summary.quests, "and %d other quest", "and %d other quests")
    else
      words = plural(summary.quests, "%d quest", "%d quests")
    end
    -- Brief BQ25a (QA item 68): the count wears the quest mark whatever the quests' source, and the
    -- green tick where every counted quest is done (summary.questArt, Tooltip.QuestCountArt).
    local marks = ""
    for _, key in ipairs(type(summary.questArt) == "table" and summary.questArt or {}) do
      local markup = Tooltip.Icon(key)
      if markup ~= "" then
        marks = marks .. markup .. " "
      end
    end
    if marks ~= "" then
      marked = true
    end
    parts[#parts + 1] = marks .. words
    plainParts[#parts] = words
  end
  if (summary.teaches or 0) > 0 then
    parts[#parts + 1] = plural(summary.teaches, "Teaches %d recipe", "Teaches %d recipes")
  end
  -- A tool is a use. It is counted apart from the reagents because a tool is not consumed, and
  -- because "Used in 5 recipes" on a flint would read as five flints spent.
  if (summary.toolFor or 0) > 0 then
    parts[#parts + 1] = plural(summary.toolFor, "Tool for %d recipe", "Tool for %d recipes")
  end
  -- Brief P5b: the class spells the item is consumed by, Shiny Fish Scales for Water Breathing.
  -- The literals are written out so the locale sweep sees them.
  local classSpells = tonumber(summary.classSpells) or 0
  if classSpells == 1 then
    parts[#parts + 1] = L["Reagent for 1 class spell"]
  elseif classSpells > 1 then
    parts[#parts + 1] = string.format(L["Reagent for %d class spells"], classSpells)
  end
  -- Brief TBR2: a class locked consumable's own use, in the Keep block's words ("Mages use it").
  if (tonumber(summary.classUse) or 0) > 0 and type(summary.classWords) == "string" then
    parts[#parts + 1] = summary.classWords
  end
  if #parts == 0 and (summary.producedBy or 0) > 0 then
    local text, plain = Tooltip.MadeByWords(summary.producedBy, summary.producedBySkills)
    return text, COLOR_BODY, plain
  end
  if #parts == 0 then
    -- Brief AA-RB (QA item 219): "No known uses for Alliance" where the other side's quests were all.
    return Tooltip.NoUsesWords(summary), COLOR_MUTED
  end
  local text = table.concat(parts, ", ")
  if not marked then
    return text, COLOR_BODY, text
  end
  local plain = {}
  for index, part in ipairs(parts) do
    plain[index] = plainParts[index] or part
  end
  return text, COLOR_BODY, table.concat(plain, ", ")
end

-- Brief BQ25a (the owner's QA item 68, Abandoned Belongings and Gold Pickup Schedule, 2026-10-10:
-- "some quest items still not showing the [!] on hover"). Item 4's fix (BQ15, BQ18) put the quest
-- mark on the Keep block's [Use] "Use it: starts a quest" line (Keep.TagReasons, QuestActionArt);
-- the "1 quest" count is the uses line (Tooltip.UsesText over Graph.Summary), which brief BQ5 drew
-- as words alone, so that fix never reached it, and a quest item with no Keep block (its quest
-- done, a recorded Forever quest such as Aid For The Refugees) shows only that line. The count now
-- wears the quest mark (Keep.KIND_ICONS.quest) whatever the quests' source, and the client's green
-- tick (ICON_CHECK, the tree's completed quest mark) where every counted quest is done: the cached
-- score (Keep.CachedScore) has none open and as many done as the line counts. A list of Assets
-- keys, or nil for no quest count. Pure over Keep's cached score.
function Tooltip.QuestCountArt(itemId, quests)
  quests = tonumber(quests) or 0
  if quests < 1 then
    return nil
  end
  local keep = ItemTree.Keep
  local icons = type(keep) == "table" and type(keep.KIND_ICONS) == "table" and keep.KIND_ICONS or nil
  local art = { (icons and icons.quest) or "CAT_QUEST" }
  if type(keep) ~= "table" or type(keep.CachedScore) ~= "function" then
    return art
  end
  local level, faction = Tooltip.PlayerFacts()
  local ok, score = pcall(keep.CachedScore, itemId, level, faction)
  if not ok or type(score) ~= "table" then
    return art
  end
  local open = tonumber((score.kinds or {}).quest) or 0
  local done = tonumber(score.done) or 0
  if open == 0 and done >= 1 and done >= quests then
    art[#art + 1] = "ICON_CHECK"
  end
  return art
end

-- Brief BQ25a (the owner's QA item 68, BQ24 item 23's rule): the summary the uses line words
-- beside a Keep block whose [Use] line starts a quest ("Use it: starts a quest"): that quest is
-- named there, so the count leaves it out; with no other quest the count goes, and with others it
-- reads "and N other quests" (questsOthers). A fresh table where anything moved; the summary as it
-- was where it counts no quest or startsQuest is false. Pure.
function Tooltip.FoldStartedQuest(summary, startsQuest)
  if not startsQuest or type(summary) ~= "table" or (tonumber(summary.quests) or 0) < 1 then
    return summary
  end
  local copy = {}
  for key, value in pairs(summary) do
    copy[key] = value
  end
  copy.quests = tonumber(summary.quests) - 1
  copy.total = math.max(0, (tonumber(summary.total) or 0) - 1)
  if copy.quests > 0 then
    copy.questsOthers = true
  end
  return copy
end

-- Brief AA-RB (QA item 219): the player's side for the "No known uses for Alliance" words, the side
-- the setting hides from (playerFaction) else the side the seen quests are judged for (seenFaction),
-- 1 or 2, or nil while neither is known. Pure.
local function ownSide(playerFaction, seenFaction)
  if playerFaction == 1 or playerFaction == 2 then
    return playerFaction
  end
  if seenFaction == 1 or seenFaction == 2 then
    return seenFaction
  end
  return nil
end

-- Brief K24e (owner QA 2026-10-06, Tracker's Pants and Pincer Bites, both quest rewards: "I assume
-- the '1 quest' is that it CAME from a quest. If that's the case - not necessary to display"): the
-- summary the tooltip words, with the quests the item only comes from (Graph.Summary's
-- questRewards) taken out of its quest count and its total. The quests that need the item or that
-- it starts stay. The item page words Graph.Summary's own counts. A fresh table; nil for nil. Pure.
-- Brief QS1 (the owner's ruling A of 2026-10-14): with the player's side (playerFaction, 1 Alliance
-- or 2 Horde), the quests of the other side alone (Graph.Summary's questSides) are taken out too:
-- they are no use of the item for this character ("4 quests" on an Alliance character's Wool
-- Cloth, not 8). nil leaves them in. Brief F155: the caller hands a side only while "Hide other
-- faction data" is on (Tooltip.HiddenFaction). Brief QS2b: with seenFaction (the player's side
-- whatever the setting says, Tooltip.SeenFaction), the quests only the other side was seen taking
-- (Graph.Summary's questSeenSides) are taken out too: no use for this character, though never hidden.
function Tooltip.TooltipSummary(summary, playerFaction, seenFaction)
  if type(summary) ~= "table" then
    return summary
  end
  -- Brief EQ1 (the owner's ruling A of 2026-10-18 on QA item 233): the game event quests the item page
  -- counts now are no part of the tooltip's count, its sides or its "No known uses" words, as before.
  summary = Tooltip.WithoutEvents(summary)
  local copy = {}
  for key, value in pairs(summary) do
    copy[key] = value
  end
  local rewards = tonumber(summary.questRewards) or 0
  local other = Tooltip.OtherSideQuests(summary, playerFaction) + Tooltip.SeenOtherQuests(summary, seenFaction)
  -- Brief AA-RB (QA item 219): every use the other side's, "No known uses for Alliance".
  copy.noUsesSide = Tooltip.NoUsesSide(summary, other, rewards, ownSide(playerFaction, seenFaction))
  -- Brief RB1b (the owner's answer of 2026-10-17 on item 190, "never relevant (so always collapsed)"):
  -- the repeatable quests the page counts are no part of the tooltip's count either; the Keep block
  -- folds them under the modifier (Tooltip.OtherQuestLines).
  local repeats = Tooltip.ShownRepeats(summary, playerFaction, seenFaction)
  -- Brief RB1c (the owner's ruling "A" of 2026-10-17): and the quests an instance holds back, folded too.
  repeats = repeats + Tooltip.ShownGated(summary, playerFaction, seenFaction)
  if rewards + other + repeats > 0 then
    copy.quests = math.max(0, (tonumber(summary.quests) or 0) - rewards - other - repeats)
    copy.total = math.max(0, (tonumber(summary.total) or 0) - rewards - other - repeats)
  end
  return copy
end

-- Brief EQ1 (the owner's ruling A of 2026-10-18 on QA item 233, "Add them to the summary line as well
-- so they're consistent"): a summary less the game event quests Graph.Summary counts for the item page
-- (questEvents, questEventSides, questEventSeenSides): out of quests, questUses and total, and each side's
-- out of questSides and questSeenSides, so the tooltip words what it worded before. Keep never keeps for
-- them, and before ItemTree_Data loads the tooltip reads the core set's Summary module, which lists
-- none, so the count stays the same either side of the load. A fresh table where any go (its side
-- tables fresh too); the summary itself otherwise. Pure.
function Tooltip.WithoutEvents(summary)
  local events = type(summary) == "table" and tonumber(summary.questEvents) or 0
  if events <= 0 then
    return summary
  end
  local copy = {}
  for key, value in pairs(summary) do
    copy[key] = value
  end
  copy.quests = math.max(0, (tonumber(summary.quests) or 0) - events)
  copy.questUses = math.max(0, (tonumber(summary.questUses) or 0) - events)
  copy.total = math.max(0, (tonumber(summary.total) or 0) - events)
  local function less(sides, taken)
    if type(sides) ~= "table" then
      return sides
    end
    taken = type(taken) == "table" and taken or {}
    return {
      math.max(0, (tonumber(sides[1]) or 0) - (tonumber(taken[1]) or 0)),
      math.max(0, (tonumber(sides[2]) or 0) - (tonumber(taken[2]) or 0)),
    }
  end
  copy.questSides = less(summary.questSides, summary.questEventSides)
  copy.questSeenSides = less(summary.questSeenSides, summary.questEventSeenSides)
  copy.questEvents = 0
  copy.questEventSides = { 0, 0 }
  copy.questEventSeenSides = { 0, 0 }
  return copy
end

-- Brief RB1c: Tooltip.ShownRepeats' answer for the quests an instance holds back (Graph.Summary's
-- questGated, questGatedSides, questGatedSeenSides). 0 for none. Pure.
function Tooltip.ShownGated(summary, playerFaction, seenFaction)
  if type(summary) ~= "table" then
    return 0
  end
  return Tooltip.ShownRepeats({
    questRepeats = summary.questGated,
    questRepeatSides = summary.questGatedSides,
    questRepeatSeenSides = summary.questGatedSeenSides,
  }, playerFaction, seenFaction)
end

-- Brief RB1b: how many of a summary's repeatable quests (Graph.Summary's questRepeats) are not
-- already taken out as the other side's: less those questRepeatSides gives the other side than
-- playerFaction (while "Hide other faction data" is on) and those questRepeatSeenSides gives the other
-- side than seenFaction. 0 for none. Pure.
function Tooltip.ShownRepeats(summary, playerFaction, seenFaction)
  if type(summary) ~= "table" then
    return 0
  end
  local repeats = tonumber(summary.questRepeats) or 0
  local sides = type(summary.questRepeatSides) == "table" and summary.questRepeatSides or nil
  if sides and (playerFaction == 1 or playerFaction == 2) then
    repeats = repeats - (tonumber(sides[3 - playerFaction]) or 0)
  end
  local seen = type(summary.questRepeatSeenSides) == "table" and summary.questRepeatSeenSides or nil
  if seen and (seenFaction == 1 or seenFaction == 2) then
    repeats = repeats - (tonumber(seen[3 - seenFaction]) or 0)
  end
  return math.max(0, repeats)
end

-- Brief QS1: how many of a summary's quests are for the other side alone than playerFaction (1 or
-- 2; Graph.Summary's questSides), 0 for none or an unknown side. Pure.
function Tooltip.OtherSideQuests(summary, playerFaction)
  local sides = type(summary) == "table" and type(summary.questSides) == "table" and summary.questSides or nil
  if not sides or (playerFaction ~= 1 and playerFaction ~= 2) then
    return 0
  end
  return tonumber(sides[3 - playerFaction]) or 0
end

-- Brief HF2: how many of a summary's quests the item only comes from are for the other side alone
-- than playerFaction (1 or 2; Graph.Summary's questRewardSides), 0 for none or an unknown side. Pure.
function Tooltip.OtherSideRewards(summary, playerFaction)
  local sides = type(summary) == "table" and type(summary.questRewardSides) == "table" and summary.questRewardSides
    or nil
  if not sides or (playerFaction ~= 1 and playerFaction ~= 2) then
    return 0
  end
  return tonumber(sides[3 - playerFaction]) or 0
end

-- Brief QS2b (QS2's rule 2): how many of a summary's quests only the other side than seenFaction (1 or
-- 2) was seen taking (Graph.Summary's questSeenSides), 0 for none or an unknown side. They count as a
-- use for that side only, whatever "Hide other faction data" says. Pure.
function Tooltip.SeenOtherQuests(summary, seenFaction)
  local sides = type(summary) == "table" and type(summary.questSeenSides) == "table" and summary.questSeenSides or nil
  if not sides or (seenFaction ~= 1 and seenFaction ~= 2) then
    return 0
  end
  return tonumber(sides[3 - seenFaction]) or 0
end

-- Brief F155 (owner QA 2026-10-14, Runecloth: the tooltip said 6 quests on the Alliance, the item
-- page's line "Used in 29 recipes, 10 quests"): Graph.Summary less the other side's quests alone,
-- for the counts that keep the quests an item only comes from (the item page's summary line, the
-- Summary HUD), so they read the tooltip's number of quests the player's side can take. A fresh
-- table where any go; the summary itself where none do; nil for nil. playerFaction as
-- Tooltip.HiddenFaction answers it. Brief QS2b: seenFaction (Tooltip.SeenFaction) takes out the
-- quests only the other side was seen taking as well, as Tooltip.TooltipSummary does. Pure.
-- Brief HF2 (owner QA 2026-10-18 item 270): the quests the item only comes from that are the other
-- side's alone (Tooltip.OtherSideRewards) leave quests, questRewards and total too, as their rows leave
-- the Sources tab while the setting is on (Core/Graph.lua Graph.HidesEdge). Never a use, so the "No
-- known uses for Alliance" words still weigh the uses alone.
function Tooltip.WithoutOtherSide(summary, playerFaction, seenFaction)
  local other = Tooltip.OtherSideQuests(summary, playerFaction) + Tooltip.SeenOtherQuests(summary, seenFaction)
  local rewards = Tooltip.OtherSideRewards(summary, playerFaction)
  if other + rewards <= 0 then
    return summary
  end
  local copy = {}
  for key, value in pairs(summary) do
    copy[key] = value
  end
  copy.quests = math.max(0, (tonumber(summary.quests) or 0) - other - rewards)
  copy.total = math.max(0, (tonumber(summary.total) or 0) - other - rewards)
  if rewards > 0 then
    copy.questRewards = math.max(0, (tonumber(summary.questRewards) or 0) - rewards)
  end
  -- Brief AA-RB (QA item 219): every use the other side's, "No known uses for Alliance".
  copy.noUsesSide = Tooltip.NoUsesSide(summary, other, summary.questRewards, ownSide(playerFaction, seenFaction))
  return copy
end

-- Brief F155: the player's side as the edge field numbers it (1 Alliance, 2 Horde) while "Hide other
-- faction data" is on, else nil: the side every count of the other side's quests is taken out by.
-- Core/Graph.lua Graph.HiddenSide answers it over settings (the saved ones where none are handed in),
-- the one side every F155 surface reads (the pretend side first). Guarded.
function Tooltip.HiddenFaction(settings)
  local graph = ItemTree.Graph
  if type(graph) ~= "table" or type(graph.HiddenSide) ~= "function" or type(graph.SIDE_NUMBERS) ~= "table" then
    return nil
  end
  local ok, side = pcall(graph.HiddenSide, settings)
  return ok and graph.SIDE_NUMBERS[side] or nil
end

-- Brief QS2b: the player's side as the edge field numbers it (1 Alliance, 2 Horde) whatever "Hide
-- other faction data" says, else nil while it is not known: the side a quest only the other side was
-- seen taking is no use for (Tooltip.SeenOtherQuests). Core/Graph.lua Graph.PlayerSide answers it (the
-- pretend side first). Guarded.
function Tooltip.SeenFaction()
  local graph = ItemTree.Graph
  if type(graph) ~= "table" or type(graph.PlayerSide) ~= "function" or type(graph.SIDE_NUMBERS) ~= "table" then
    return nil
  end
  local ok, side = pcall(graph.PlayerSide)
  return ok and graph.SIDE_NUMBERS[side] or nil
end

-- Badge kinds for an item, from Diff. Empty when Diff is not loaded.
function Tooltip.BadgeKinds(itemId)
  local diff = ItemTree.Diff
  if not diff or type(diff.Badges) ~= "function" then
    return {}
  end
  local ok, kinds = pcall(diff.Badges, "items", itemId)
  if not ok or type(kinds) ~= "table" then
    return {}
  end
  return kinds
end

-- The owner's wording: the block names the build the way players talk about it. L is read here
-- rather than at call time so these are literals the locale sweep can find, which is how
-- UI/Badges.lua carries its own labels. The list tooltips in UI/Sidebar.lua say the same words
-- about a mark, which is why they read them off Badges rather than keeping their own copy.
local BADGE_TEXT = {
  removed = L["Removed in Forever"],
  changed = L["Changed in Forever"],
  new = L["New in Forever"],
  sod = L["New in Forever. This item came from Season of Discovery."],
}

-- The colour a badge status line is drawn in. Only Removed differs, and only because it shares
-- the Changed medallion.
local BADGE_COLOR = {
  removed = COLOR_REMOVED,
  changed = COLOR_TITLE,
  new = COLOR_TITLE,
  sod = COLOR_TITLE,
}

-- The medallion for a badge kind. UI/Badges.lua is the one place the kind to art mapping
-- lives, so it is asked first and the local table is the fallback for a client where that file
-- did not load. Pure.
--
-- A medallion Badges draws tinted (meta.artTint) cannot be written as an escape, because an
-- escape can colour a texture but not take its own colour off first, so that kind answers the art
-- it falls back to, which carries its colour in Assets. New is not one of them: its medallion,
-- the infinity mark, carries its own colour and is drawn as it is here too (brief A1).
function Tooltip.BadgeArt(kind)
  local badges = ItemTree.Badges
  local meta = type(badges) == "table" and type(badges.META) == "table" and badges.META[kind] or nil
  if type(meta) == "table" and meta.artTint ~= nil and type(meta.fallbackArt) == "string" then
    return meta.fallbackArt
  end
  if type(meta) == "table" and type(meta.art) == "string" then
    return meta.art
  end
  return BADGE_ART[kind]
end

-- A Theme size token, or the fallback when Theme is not loaded, has no row for it or holds a size
-- under 1. Not Theme.Size, which takes any value the table holds; nothing in a tooltip post call
-- may raise.
local function themeSize(key, fallback)
  local sizes = Theme and Theme.sizes
  local size = sizes and sizes[key]
  if type(size) == "number" and size >= 1 then
    return size
  end
  return fallback
end

-- The inline texture escape for an asset key, or "" when there is none to draw. Assets.Markup
-- raises on a key the table has no row for, and a raise inside a tooltip post call is swallowed
-- by the client, which would cost the whole block with nothing said, so an unknown key reads as
-- no icon. Assets is read through the namespace rather than captured, so a spec can take it
-- away or swap the art under us. Pure.
function Tooltip.Icon(key)
  if type(key) ~= "string" then
    return ""
  end
  local assets = ItemTree.Assets
  if type(assets) ~= "table" or type(assets.Markup) ~= "function" then
    return ""
  end
  local ok, markup = pcall(assets.Markup, key, themeSize(ICON_SIZE_KEY, ICON_SIZE_FALLBACK))
  if not ok or type(markup) ~= "string" then
    return ""
  end
  return markup
end

-- Brief BQ14 (the owner's QA items 14 and 43, 2026-10-10): the rarity circles after a profession use
-- line's count, one per quality in mask (Keep.MaskQualities, highest first), each the QUALITY_DOT
-- disc tinted to its quality's Theme colour (Theme.QualityKey) and followed by its 2 pixel gap
-- (QUALITY_DOT_GAP), led by a space. Inline texture escapes, since a tooltip line is one FontString
-- and the client's fonts carry no circle glyph. "" for an empty mask or a missing helper. Pure.
local QUALITY_DOT_SIZE_KEY = "ITEMTREE_QUALITY_DOT_SIZE"
local QUALITY_DOT_FALLBACK = 6
function Tooltip.QualityDots(mask)
  local keep, assets = ItemTree.Keep, ItemTree.Assets
  if tonumber(mask) == nil or tonumber(mask) <= 0 then
    return ""
  end
  if type(keep) ~= "table" or type(keep.MaskQualities) ~= "function" then
    return ""
  end
  if type(assets) ~= "table" or type(assets.Markup) ~= "function" or type(Theme) ~= "table" then
    return ""
  end
  local size = themeSize(QUALITY_DOT_SIZE_KEY, QUALITY_DOT_FALLBACK)
  local okGap, gap = pcall(assets.Markup, "QUALITY_DOT_GAP", size)
  if not okGap or type(gap) ~= "string" then
    return ""
  end
  local parts = {}
  for _, quality in ipairs(keep.MaskQualities(tonumber(mask))) do
    local okColour, r, g, b = pcall(Theme.Color, Theme.QualityKey(quality))
    if okColour then
      local ok, dot = pcall(assets.Markup, "QUALITY_DOT", size, { r, g, b })
      if ok and type(dot) == "string" then
        parts[#parts + 1] = dot .. gap
      end
    end
  end
  if #parts == 0 then
    return ""
  end
  return " " .. table.concat(parts)
end

-- One { text, label, colorKey, badge, icon } line. text is what the client draws, icon escape
-- and all; label is the same words with no markup. icon is the asset key that went on, and is
-- absent when nothing did. Pure.
local function iconLine(text, colorKey, kind, art)
  local line = { text = text, label = text, colorKey = colorKey, badge = kind }
  local markup = Tooltip.Icon(art)
  if markup ~= "" then
    line.text = markup .. " " .. text
    line.icon = art
  end
  return line
end

-- Whether anything outside the shipped data names the item: the running client, because
-- someone on this realm has found it, or the collector's note from the session that watched
-- that happen. Guarded the way every other read here is.
local function namedOutsideData(itemId)
  local facts = ItemTree.ItemFacts
  if type(facts) == "function" then
    local ok, answer = pcall(facts, itemId)
    if ok and type(answer) == "table" and type(answer.name) == "string" and answer.name ~= "" then
      return true
    end
  end
  -- The graph's runtime name registry, not Graph.Name: that one falls back to the honest
  -- "Undiscovered mail chest", which is the addon naming the item rather than the realm.
  local graph = ItemTree.Graph
  if type(graph) == "table" and type(graph.names) == "table" then
    local stored = graph.names["item:" .. tostring(itemId)]
    if type(stored) == "string" and stored ~= "" then
      return true
    end
  end
  return false
end

-- What ItemTree can say about an item at all, as one word. Pure in the same sense the rest of
-- the block is: it reads the data modules and the client resolver and touches no frame.
--
--   "known"        the shipped data names it, which is the ordinary case
--   "discovered"   the data does not name it and something else does, so someone on the realm
--                  has found it since the data was built
--   "undiscovered" the build has an Item row for it and will not say what it is
--   "unknown"      nothing here has heard of it at all
--
-- Guarded the same way as the Diff call above, so a half loaded data module reads as unknown
-- rather than erroring.
--
-- Brief U3: the item rows ship in the load on demand ItemTree_Data, so while it is not loaded
-- whether the data names the item is read off the core set (Data:Glance), and a hover never
-- loads it. The answer is the same one the rows give.
local function glanceNamed(data, itemId)
  if type(data.OnDemandLoaded) ~= "function" or type(data.Glance) ~= "function" then
    return nil
  end
  local okLoaded, loaded = pcall(data.OnDemandLoaded, data)
  if not okLoaded or loaded ~= false then
    return nil
  end
  local ok, glance = pcall(data.Glance, data, itemId)
  if not ok or type(glance) ~= "table" then
    return nil
  end
  return glance.named == true
end

function Tooltip.ItemState(itemId)
  local data = ItemTree.Data
  if not data or type(data.GetItem) ~= "function" then
    return "unknown"
  end
  local named = glanceNamed(data, itemId)
  local item = nil
  if named == nil then
    local ok, answer = pcall(data.GetItem, data, itemId)
    if not ok then
      return "unknown"
    end
    item = answer
    named = type(item) == "table" and type(item.n) == "string" and item.n ~= ""
  end
  if named then
    return "known"
  end
  local sealed = type(item) == "table" and item.u ~= nil
  if not sealed and type(data.IsUndiscovered) == "function" then
    local okSealed, answer = pcall(data.IsUndiscovered, data, itemId)
    sealed = okSealed and answer == true
  end
  if namedOutsideData(itemId) then
    return "discovered"
  end
  if sealed then
    return "undiscovered"
  end
  return "unknown"
end

-- The line under the status line for an item the data cannot state, or nil for one it can. The
-- status line is short enough to sit beside a medallion and this is the rest of the sentence,
-- which takes the place of the uses line: an item nothing is known about has no uses to count.
function Tooltip.StateLine(state)
  if state == "undiscovered" then
    return L["Its details appear once someone on your realm finds it."]
  end
  if state == "discovered" then
    return L["Not yet in ItemTree data."]
  end
  return nil
end

-- The first line while badges are on. A badge wins, then whether the item is in ItemTree's data
-- at all. Every one of them leads with an icon while icons are on: the medallion for a flagged
-- item, the ItemTree mark or the chest for the ones that report no change. settings is taken
-- explicitly so specs and the harness can turn the icons off; it falls back to the saved
-- settings the way BuildLines does. Returns one line, or nil for an item Forever did not change
-- (brief W27: that line said nothing a player needs). Pure.
function Tooltip.StatusLine(itemId, settings)
  settings = settings or (ItemTree.db and ItemTree.db.settings) or {}
  local icons = settingOn(settings, "tooltipShowIcons")
  local kinds = ItemTree.Badges and ItemTree.Badges.Sort(Tooltip.BadgeKinds(itemId), 1) or Tooltip.BadgeKinds(itemId)
  local kind = kinds and kinds[1]
  local badgeText = kind and BADGE_TEXT[kind] or nil
  local art
  if badgeText then
    if icons then
      art = Tooltip.BadgeArt(kind)
    end
    return iconLine(badgeText, BADGE_COLOR[kind] or COLOR_TITLE, kind, art)
  end
  if icons then
    art = NEUTRAL_ART
  end
  local state = Tooltip.ItemState(itemId)
  if state == "known" then
    -- An item this build newly named never reaches here: it is inside Diff.IsNew, so it took
    -- the badge path above and wears the New medallion like any other item that is new to a
    -- player of this client. Brief W33: the block does not say it was newly named (the owner
    -- found that line unnecessary for most players); the item page still does.
    -- Brief W27: an unchanged item has no status line.
    return nil
  end
  if state == "discovered" then
    -- The chest rather than the ItemTree mark: this is the one line in the block the window also
    -- says with a glyph, and the two are the same glyph. art is set exactly when icons are on,
    -- so the chest goes and comes with every other icon in the block.
    if art then
      art = DISCOVERED_ART
    end
    return iconLine(L["Discovered on your realm"], COLOR_MUTED, nil, art)
  end
  if state == "undiscovered" then
    return iconLine(L["Undiscovered in Forever"], COLOR_MUTED, nil, art)
  end
  return iconLine(L["Not in ItemTree data"], COLOR_MUTED, nil, art)
end

-- The hint line text. Both arguments are texts, never settings, so the wording stays pure and
-- the client side reads them.
--   keyText    the bound key as the client displays it, nil or empty when nothing is bound: a
--              default is applied at first login where a key is free, so an empty one is a
--              player who cleared it or had every candidate taken
--   clickText  the readable click shortcut from Keybind.ClickText, nil when click to open is off
-- Both ways in are named when both are on, the click first because it is the one the player's
-- hand is already on. With neither, the line says where to set one. Pure.
function Tooltip.HintText(keyText, clickText)
  local hasKey = type(keyText) == "string" and keyText ~= ""
  local hasClick = type(clickText) == "string" and clickText ~= ""
  if hasClick and hasKey then
    return string.format(L["%s or %s for the full tree"], clickText, keyText)
  end
  if hasClick then
    return string.format(L["%s for the full tree"], clickText)
  end
  if hasKey then
    return string.format(L["Press %s for the full tree"], keyText)
  end
  return L["Set a key in ItemTree settings to open the full tree"]
end

-- Brief TT2 (the owner's QA item 247, Windsong Bangles in the search dropdown: "The tooltip says the
-- hotkey but doesnt mention the ctrl right click however. The ctrl right click actually works and
-- the htokey doesn't"): the hint on a row that opens the item on a click of its own while an edit
-- box holds the keyboard (the search dropdown's rows, Tooltip.SetOwnerContext's clickOnly), where
-- the key binding never fires. It names the click alone: the player's click to open where it is a
-- right click, which the row opens on whatever the modifiers (UI/Frame.lua searchRow's OnClick),
-- else a plain click. A left click setting is not promised there, as a left click with the
-- client's dress up or chat link modifier is the client's on our rows (Frame.ModifiedClick).
--   setting    the stored click to open value (Keybind.ClickSetting: "CTRL-RIGHT", "OFF", ...)
--   clickText  its readable words (Keybind.ClickText), nil where it is off
-- Pure.
function Tooltip.RowHintText(setting, clickText)
  local right = type(setting) == "string" and setting:find("%-RIGHT$") ~= nil
  if right and type(clickText) == "string" and clickText ~= "" then
    return string.format(L["%s for the full tree"], clickText)
  end
  return L["Click for the full tree"]
end

-- The bound key, or nil. UI/Keybind.lua may not be loaded, so never assume it is there.
local function boundKeyText()
  if ItemTree.Keybind and type(ItemTree.Keybind.KeyText) == "function" then
    local ok, text = pcall(ItemTree.Keybind.KeyText)
    return ok and text or nil
  end
  return nil
end

-- The readable click shortcut, or nil when click to open is off or UI/Keybind.lua is not
-- loaded. Read by the hint line and by the cache fingerprint, so the two can never disagree.
local function clickOpenText()
  if ItemTree.Keybind and type(ItemTree.Keybind.ClickText) == "function" then
    local ok, text = pcall(ItemTree.Keybind.ClickText)
    if ok and type(text) == "string" and text ~= "" then
      return text
    end
  end
  return nil
end

-- Brief TT2: the stored click to open value (Keybind.ClickSetting), or nil where UI/Keybind.lua is
-- not loaded. Its words are in the cache fingerprint (clickOpenText), one per value.
local function clickOpenSetting()
  if ItemTree.Keybind and type(ItemTree.Keybind.ClickSetting) == "function" then
    local ok, value = pcall(ItemTree.Keybind.ClickSetting)
    if ok and type(value) == "string" then
      return value
    end
  end
  return nil
end

-- Brief E88: whether the window's Show classic diff tick box is on. It is session state on
-- UI/Frame.lua (Frame.showChanges, never saved), which is also what the tree's change rows read
-- through Frame.OptionsFromSettings, so the block asks Frame.ShowChanges and the two agree. A
-- window that has not loaded, or an answer that is not true, reads as off. Pure.
function Tooltip.ShowChanges()
  local ui = ItemTree.UI
  local frame = type(ui) == "table" and ui.Frame or nil
  if type(frame) ~= "table" or type(frame.ShowChanges) ~= "function" then
    return false
  end
  local ok, on = pcall(frame.ShowChanges)
  return ok and on == true
end

local function diffAnswer(diff, name, itemId)
  if type(diff[name]) ~= "function" then
    return false
  end
  local ok, answer = pcall(diff[name], "items", itemId)
  return ok and answer == true
end

-- Brief Q9a: the old value in Tree.ChangeText's rich form is the span in the disabled colour.
local OLD_VALUE_COLOR = "ITEMTREE_COLOR_TEXT_DISABLED"

-- A string with its colour escapes taken out. Pure.
local function stripColors(text)
  return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Brief Q9a: one change line in ItemTree's diff convention, the old value dimmed and struck
-- through and the new value plain, as the tree's change rows and the info column draw it. The
-- rich form's old value span (the disabled colour) is redrawn in the muted colour, and the line
-- carries strike = { prefix, old }: the words before the old value and the old value itself,
-- with no escapes, which the client side measures to lay the strike over the old value. A
-- change with no old value, or no rich form, is its plain words with no strike. Pure.
function Tooltip.ChangeLine(plain, rich)
  local line = { text = " " .. plain, label = plain, colorKey = COLOR_MUTED, change = true }
  if type(rich) ~= "string" or not Theme or type(Theme.ColorTable) ~= "function" then
    return line
  end
  if not Theme.ColorTable(OLD_VALUE_COLOR) or not Theme.ColorTable(COLOR_MUTED) then
    return line
  end
  local open = "|cff" .. Theme.Hex(OLD_VALUE_COLOR)
  local first, last = rich:find(open, 1, true)
  local close = last and rich:find("|r", last + 1, true) or nil
  if not close then
    line.text = " " .. rich
    return line
  end
  local before = rich:sub(1, first - 1)
  local old = rich:sub(last + 1, close - 1)
  local after = rich:sub(close + 2)
  line.text = " " .. before .. Theme.Colorise(COLOR_MUTED, old) .. after
  if old ~= "" then
    line.strike = { prefix = " " .. stripColors(before), old = stripColors(old) }
  end
  return line
end

-- Brief E88: the lines the tooltip draws under the status line while the classic diff is on,
-- each { text, label, colorKey, change = true }. The rule is the tree's own (ViewModel
-- VM:_Changes): an item that is Changed or discovered lists Diff.GetChanges, which already leaves
-- the minor rows out while "Include minor changes" is off (brief C1), and anything else lists
-- nothing. The words are Tree.ChangeText's, so a row and its tooltip read the same, and since
-- brief Q9a they are drawn the way the row draws them: Tooltip.ChangeLine.
--
-- The one row left out is the discovered one: its words are "Newly named in this build", which
-- brief W33 took out of the tooltip (the item page still says it). Past Tooltip.MAX_CHANGE_LINES the rest are
-- counted in one "and N more changes" line. Lookups only: no walk, no client call. Pure.
function Tooltip.ChangeLines(itemId)
  local out = {}
  local diff = ItemTree.Diff
  local ui = ItemTree.UI
  local tree = type(ui) == "table" and ui.Tree or nil
  if
    not itemId
    or type(diff) ~= "table"
    or type(diff.GetChanges) ~= "function"
    or type(tree) ~= "table"
    or type(tree.ChangeText) ~= "function"
  then
    return out
  end
  if not diffAnswer(diff, "IsChanged", itemId) and not diffAnswer(diff, "IsDiscovered", itemId) then
    return out
  end
  local ok, changes = pcall(diff.GetChanges, "items", itemId)
  if not ok or type(changes) ~= "table" then
    return out
  end
  local more = 0
  for _, change in ipairs(changes) do
    if type(change) == "table" and change.field ~= "discovered" then
      local drawn, plain, rich = pcall(tree.ChangeText, change)
      if drawn and type(plain) == "string" and plain ~= "" then
        if #out < Tooltip.MAX_CHANGE_LINES then
          out[#out + 1] = Tooltip.ChangeLine(plain, rich)
        else
          more = more + 1
        end
      end
    end
  end
  if more > 0 then
    local text
    if more == 1 then
      text = L["and 1 more change"]
    else
      text = string.format(L["and %d more changes"], more)
    end
    out[#out + 1] = { text = " " .. text, label = text, colorKey = COLOR_MUTED, change = true }
  end
  return out
end

-- Adds a line, unless the block already says those words.
--
-- The block is four lines at most and every one of them is a different fact, so a sentence that
-- is already on it is a duplicate rather than an echo. Two lines can honestly reach for the same
-- sentence (the state line under the status line that started it), and this is the one place
-- that is settled, for every state, so
-- no caller has to remember which pairs can collide. Compared on label, which is the line's
-- words with no markup in them.
local function append(lines, line)
  if type(line) ~= "table" then
    return false
  end
  local label = line.label
  if type(label) == "string" then
    for _, existing in ipairs(lines) do
      if existing.label == label then
        return false
      end
    end
  end
  lines[#lines + 1] = line
  return true
end

-- Array of { text, colorKey, badge }. Pure: pass settings explicitly from specs.
--
-- skipClick drops the click half of the hint line for a tooltip whose owner a click never
-- reaches: UI/Keybind.lua deliberately leaves loot rows and action buttons alone, so promising
-- "Ctrl + right click" over one of those is a lie. The bound key still works there, so only the
-- click half goes and the line falls back to the key or to the line that says to set one.
--
-- Brief K18: skipClick "hint" drops the hint line whole, for a tooltip whose owner opens the item
-- on a plain click and says so itself (the Professions card's material, Tooltip.SetOwnerContext).
--
-- Brief TT2: skipClick "key" drops the key half and names the owner's own click
-- (Tooltip.RowHintText), for a row an edit box holds the keyboard over (the search dropdown's).
--
-- showChanges is the Show classic diff tick box (brief E88), read from the window when nil. On,
-- the status line is followed by Tooltip.ChangeLines, outside the four line cap.
--
-- Brief K18: where the Keep block lists the item's uses (a verdict with a head, Tooltip.KeepLines),
-- the uses line ("Used in 3 recipes") is left out and the block takes its place: the block is the
-- one list of the uses. Where the block is one muted sentence ("Sold by vendors everywhere"), is
-- not drawn, or the uses line carries a withheld item's state words or no use ("Made by 1 recipe"),
-- the uses line is drawn as before. Brief TBR2: where that one muted sentence is "For Mages" and
-- the uses line already reads "Mages use it", only the uses line is. Brief TB11: a uses line that
-- would read "No known uses" is not drawn at all (the item page keeps its row); the Keep block,
-- when there is one, goes where it would have been.
function Tooltip.BuildLines(itemId, settings, skipClick, showChanges)
  settings = settings or (ItemTree.db and ItemTree.db.settings) or {}
  local lines = {}
  if not itemId or not settingOn(settings, "tooltipEnabled") then
    return lines
  end
  if showChanges == nil then
    showChanges = Tooltip.ShowChanges()
  end

  local statusDrawn = false
  local usesLabel
  -- Brief K24d: the lines the tagged layout (Tooltip.TaggedLayout) places itself.
  local statusLine, usesLine, hintLine = nil, nil, nil
  -- Brief UL1: the uses lines drawn in the uses line's place (Tooltip.UseLines), nil where it is drawn.
  local useLines = nil
  if settingOn(settings, "tooltipShowBadges") then
    local status = Tooltip.StatusLine(itemId, settings)
    statusDrawn = append(lines, status)
    if statusDrawn then
      statusLine = status
    end
    -- Brief W33: an item this build newly named no longer says so here (the item page still
    -- does). Brief TB6 (owner 2026-10-05): nor when the Discovery Miner first found it; the item
    -- page's fact row and the Discoveries tab's When column still say that.
  end

  local summary
  if ItemTree.Graph and type(ItemTree.Graph.Summary) == "function" then
    local ok, result = pcall(ItemTree.Graph.Summary, itemId)
    if ok then
      -- Brief K24e: without the quests the item only comes from.
      -- Brief QS1: and without the other side's quests, while "Hide other faction data" is on (F155).
      -- Brief QS2b: and without the quests only the other side was seen taking, always.
      summary = Tooltip.TooltipSummary(result, Tooltip.HiddenFaction(settings), Tooltip.SeenFaction())
    end
  end

  -- Brief T4: the Keep verdict, read here so the uses line can step aside for it (brief K18).
  local keepLines = Tooltip.KeepLines(itemId, settings)
  -- Brief K20b: a block whose lines are not a list of the uses ("Sold by vendors everywhere" under
  -- a Vendor head) says so on its head (lists false), and the uses line stays above it.
  -- Brief TD1: read off the whole block, before any kind of line is hidden, so a block whose quest
  -- lines are turned off still keeps the uses line (and the other quests' fold) from saying them again.
  local keepLists = keepLines ~= nil and keepLines[1].keep ~= "muted" and keepLines[1].lists ~= false
  local listsOthers = Tooltip.ListsOtherQuests(keepLines)
  local hadBlock = keepLines ~= nil
  -- Brief BQ25a (QA item 68): the quest a [Use] block starts is named there, so the uses line's
  -- count leaves it out; the count that stays wears the quest mark (Tooltip.QuestCountArt).
  local startsQuest = false
  for _, line in ipairs(keepLines or {}) do
    if line.startsQuest then
      startsQuest = true
    end
  end
  -- Brief TD1: the kinds of line the Tooltip display section turns off go first, so the fold below
  -- never counts them; the tag row stays as it is (its own switch acts in Tooltip.TaggedLayout).
  keepLines = Tooltip.HideCategories(keepLines, settings)
  -- Brief BQ7: the uses that are not the player's, folded unless the modifier is held.
  keepLines = Tooltip.FoldKeepLines(keepLines, settings)
  local keepAt = nil

  summary = Tooltip.FoldStartedQuest(summary, startsQuest)
  -- Brief RB1d (the QA page probe of 2026-10-17: Wartorn Plate Scrap drew no quest line with naxx off
  -- and a plain "16 quests" of warriors' and paladins' quests with it on): the quests that are not the
  -- player's (repeatable, held back by an instance, another class's, the other side's while shown) as
  -- the Keep block draws them (Tooltip.OtherQuestLines over the same cached score), and the uses line's
  -- count without them, so an item with no Keep verdict folds them the same way under the modifier. A
  -- block that lists them (Tooltip.ListsOtherQuests) keeps the uses line as it was.
  local otherQuests = {}
  if not listsOthers then
    local otherScore, otherFaction
    otherQuests, otherScore, otherFaction = Tooltip.OtherQuestsFor(itemId)
    summary = Tooltip.WithoutOtherQuests(summary, otherScore, otherFaction)
  end
  -- Brief TD1: the counts of a kind turned off leave the uses line as well ("Used in 6 recipes, 1
  -- quest" reads "Used in 6 recipes" with Quest lines off). Whether the item counts a use at all is
  -- still read off the whole summary (fullSummary), so the uses line steps aside, or gives way to the
  -- uses lines, exactly as it would with every kind on.
  local fullSummary = summary
  summary = Tooltip.ShownSummary(summary, settings)
  if type(summary) == "table" and (tonumber(summary.quests) or 0) > 0 and settingOn(settings, "tooltipShowIcons") then
    summary.questArt = Tooltip.QuestCountArt(itemId, summary.quests)
  end

  -- Only the status line carries an icon: the block stays as compact as it was, and the mark
  -- reads as a signature rather than as a bullet down the side of every line.
  if settingOn(settings, "tooltipShowUses") then
    local text, colorKey, plain = Tooltip.UsesText(summary)
    -- An item the build withholds has nothing to count, and "No known uses"
    -- reads as a fact about the item rather than about the build. The rest of the sentence the
    -- status line started goes here instead.
    local note = Tooltip.StateLine(Tooltip.ItemState(itemId))
    if note then
      text, colorKey, plain = note, COLOR_MUTED, note
    end
    local counts = type(fullSummary) == "table" and (tonumber(fullSummary.total) or 0) > 0
    -- Brief TD1: every use the line counts is of a kind turned off. The line is not drawn then: never
    -- "No known uses", and never its "Made by Alchemy" in their place.
    local allHidden = counts and type(summary) == "table" and (tonumber(summary.total) or 0) <= 0
    -- Brief UL1 (QA item 347i): where the item counts a use and its block lists none, the uses lines in
    -- the Keep block's shape (Tooltip.UseLines), not the one "Used in 15 recipes, 1 quest" line; nil
    -- where no score is there to read, and the line as before.
    if counts and not note and not keepLists then
      useLines = Tooltip.UseLines(itemId, settings, startsQuest, keepLines)
      -- With no block to say whose it is (Keep marks off), uses lines that come to nothing (another
      -- class's consumable, the recipe a recipe item teaches) leave the one line as before.
      if type(useLines) == "table" and #useLines == 0 and not hadBlock then
        useLines = nil
      end
      -- Brief TD1: then the kinds turned off go, before the fold below counts them. Lines that all go
      -- leave nothing in their place, never the one line in another shape.
      useLines = Tooltip.WithoutHidden(useLines, settings)
    end
    -- Brief TBR2: a class locked consumable another class uses. The uses line says whose it is
    -- ("Mages use it"), so the block's one muted "For Mages" would say it twice: one of them.
    local classSaid = counts
      and useLines == nil
      and not note
      and (tonumber(summary.classUse) or 0) > 0
      and type(summary.classWords) == "string"
    if classSaid and keepLines then
      -- Brief K20b: the muted line sits under a head now; it alone goes, and a block left with
      -- its head and nothing else goes with it.
      local kept = {}
      for _, line in ipairs(keepLines) do
        if not line.classUse then
          kept[#kept + 1] = line
        end
      end
      if #kept < #keepLines then
        -- Brief K24b: the tag row stands on its own (it is the action), so only a block left with
        -- no tag row at all goes.
        local tagged = false
        for _, line in ipairs(kept) do
          if line.tags then
            tagged = true
          end
        end
        keepLines = (tagged or #kept > 1) and kept or nil
      end
    end
    -- Brief TB11 (owner 2026-10-05): "No known uses" is not drawn on the tooltip; the item page
    -- still says it. A Keep block takes the place the line would have had.
    local noUses = not note and text == L["No known uses"]
    -- Brief AA-RB (QA item 219): "No known uses for Alliance" is drawn, unless the Keep block says it
    -- already (its line under the player's Always or Never, Keep.NoUsesWords).
    if not noUses and not note and not counts then
      for _, line in ipairs(keepLines or {}) do
        if type(line) == "table" and line.label == (plain or text) then
          noUses = true
        end
      end
    end
    if (keepLists and counts and not note) or noUses then
      keepAt = #lines + 1
    elseif useLines then
      -- Brief UL1: folded as a block's are, "and N other uses, hold Ctrl" under a line that stays (the
      -- block's reasons above count), "N uses, hold Ctrl" where none does; every line while Ctrl is held.
      local drawn = {}
      for _, line in ipairs(Tooltip.FoldKeepLines(useLines, settings, Tooltip.HasReasonLine(keepLines))) do
        if append(lines, line) then
          usesLabel = line.label
          drawn[#drawn + 1] = line
        end
      end
      useLines = drawn
    elseif allHidden and not note then
      -- Brief TD1: the one line, every use it counts of a kind turned off: nothing in its place.
      keepAt = #lines + 1
    else
      -- Brief BQ5: the label is the words alone, with no profession glyph.
      usesLine = { text = text, label = plain or text, colorKey = colorKey }
      if append(lines, usesLine) then
        usesLabel = usesLine.label
      else
        usesLine = nil
      end
    end
  end

  -- Brief RB1d: the quests that are not the player's, where no Keep block lists them (no verdict, or a
  -- block whose lines are not a list of the uses), folded as the block folds them ("and N other uses,
  -- hold Ctrl"; every line while the modifier is held), under the uses line or in its place.
  local otherLines = nil
  -- Brief UL1: the uses lines fold those quests themselves (Tooltip.UseLines).
  if settingOn(settings, "tooltipShowUses") and #otherQuests > 0 and useLines == nil then
    -- Brief TV1 (QA item 347): drawn under the uses line or a Keep block's reasons, the fold reads "and
    -- 16 other uses"; alone, "16 uses".
    local follows = usesLine ~= nil or Tooltip.HasReasonLine(keepLines)
    -- Brief TD1: quest lines all, so Quest lines off takes the lot before the fold counts them.
    local drawnOthers = Tooltip.WithoutHidden(Tooltip.DrawnOtherQuests(otherQuests, settings), settings)
    otherLines = Tooltip.FoldKeepLines(drawnOthers, settings, follows)
    if not (keepLines and Tooltip.HasTagRow(keepLines)) then
      for _, line in ipairs(otherLines) do
        append(lines, line)
      end
    end
  end

  if settingOn(settings, "tooltipShowHint") and skipClick ~= "hint" then
    local text
    if skipClick == "key" then
      -- Brief TT2 (QA item 247): the click alone, the key never fires under the search box.
      text = Tooltip.RowHintText(clickOpenSetting(), clickOpenText())
    else
      local clickText = nil
      if not skipClick then
        clickText = clickOpenText()
      end
      text = Tooltip.HintText(boundKeyText(), clickText)
    end
    -- Brief BQ3: marked, so the lines OnItem adds go in above it and the post show pass can find
    -- it (the hint is the tooltip's last line, owner QA item 18).
    hintLine = { text = text, label = text, colorKey = COLOR_HINT, hint = true }
    if not append(lines, hintLine) then
      hintLine = nil
    end
  end

  -- Brief SET2: a set piece the set's own list names an undiscovered twin of (Graph.SetTwinText),
  -- while Merge recipes folds the twin into this piece. Outside the four line cap, like the Keep
  -- line, so it never costs another line its place.
  -- Brief BQ32 (the owner's ruling of 2026-10-13 on QA item 79 (c), "Hide that tooltip"): the
  -- soulbound Forever copy's line (brief BQ7's "Soulbound copy of the Classic version of this item")
  -- is gone too, so neither item of a copy pair says anything of the other here; the pair stays one
  -- entry in search and on the page (Data:ForeverCopyPair).
  local twinText = Tooltip.SetTwinLine(itemId, settings)
  local twinLine = twinText and { text = twinText, label = twinText, colorKey = COLOR_MUTED } or nil

  -- Brief K24d (owner QA 2026-10-06), K24i (2026-10-07): an item with tags lays the section out in
  -- the owner's order (Tooltip.TaggedLayout): the tag row, then the status line between two short
  -- gaps where there is one, else a gap, then the reasons, the summary lines, the hint. Every Keep
  -- block has its tag row, so an item with no block keeps the layout below, which has no gaps.
  if keepLines and Tooltip.HasTagRow(keepLines) then
    local summaryLines = {}
    if usesLine then
      summaryLines[#summaryLines + 1] = usesLine
    end
    -- Brief UL1: or the uses lines in its place, after the block's reasons.
    for _, line in ipairs(useLines or {}) do
      summaryLines[#summaryLines + 1] = line
    end
    -- Brief RB1d: a block that does not list the uses leaves the other quests' fold to the uses line.
    for _, line in ipairs(otherLines or {}) do
      summaryLines[#summaryLines + 1] = line
    end
    if twinLine then
      summaryLines[#summaryLines + 1] = twinLine
    end
    -- Brief TD1: no blank line left at either end by a kind turned off.
    return Tooltip.Settled(Tooltip.TaggedLayout({
      status = statusLine,
      changes = (showChanges and statusDrawn) and Tooltip.ChangeLines(itemId) or nil,
      keep = keepLines,
      summary = summaryLines,
      hint = hintLine,
      -- Brief TD1: Show Keep and sell tags off leaves the tag row out, and nothing else moves.
      tags = settingOn(settings, Tooltip.TAGS_KEY),
    }))
  end

  -- Brief T4: the Keep verdict, straight under the uses line it explains. Outside the four line
  -- cap, like the change lines below, so it never costs the hint its place. Brief K11: a head in
  -- its green, red or grey, then one line per reason with its glyph (Tooltip.KeepLines). Brief
  -- K18: in the uses line's place where the uses line stepped aside for it.
  if keepLines then
    local at = keepAt or (#lines + 1)
    for index, line in ipairs(lines) do
      if not keepAt and usesLabel and line.label == usesLabel then
        at = index + 1
      end
    end
    -- Brief RB1d: the other quests' fold stays with the uses line it finishes, above the block.
    while type(lines[at]) == "table" and (lines[at].other or lines[at].folded) do
      at = at + 1
    end
    -- Brief K24b: no spacer at the section's top or at the block's end.
    keepLines = Tooltip.TrimKeepSpacers(keepLines, at == 1)
    for offset, keepLine in ipairs(keepLines) do
      table.insert(lines, at + offset - 1, keepLine)
    end
  end

  -- Brief BQ3 (owner QA item 18): the hint stays the block's last line, so the twin line goes in
  -- above it.
  if twinLine then
    local hintAt = nil
    for index, line in ipairs(lines) do
      if line.hint then
        hintAt = index
      end
    end
    if hintAt and append(lines, twinLine) then
      table.remove(lines)
      table.insert(lines, hintAt, twinLine)
    elseif not hintAt then
      append(lines, twinLine)
    end
  end

  -- The status line is always the first line when it is drawn, so its detail goes in at two.
  if showChanges and statusDrawn then
    for offset, line in ipairs(Tooltip.ChangeLines(itemId)) do
      table.insert(lines, 1 + offset, line)
    end
  end
  -- Brief TD1: no blank line left at either end by a kind turned off.
  return Tooltip.Settled(lines)
end

--- Brief SET2: the line a set piece carries when Merge recipes folds the set's unnamed twin into
--- it, or nil. Core words it (Graph.SetTwinText); settings.mergeCrafts decides, on unless false.
--- The set's rows are item rows, which ship in ItemTree_Data, so while that addon is not loaded
--- there is no line: a tooltip never loads it (Data:OnDemandLoaded). Pure over Data.
function Tooltip.SetTwinLine(itemId, settings)
  local Graph, Data = ItemTree.Graph, ItemTree.Data
  if type(itemId) ~= "number" or type(Graph) ~= "table" or type(Graph.SetTwinText) ~= "function" then
    return nil
  end
  if type(Data) ~= "table" or type(Data.OnDemandLoaded) ~= "function" then
    return nil
  end
  local loaded, answer = pcall(Data.OnDemandLoaded, Data)
  if not loaded or answer ~= true then
    return nil
  end
  local on = not (type(settings) == "table" and settings.mergeCrafts == false)
  local ok, text = pcall(Graph.SetTwinText, itemId, on)
  if ok and type(text) == "string" and text ~= "" then
    return text
  end
  return nil
end

-- The player's level and side (1 Alliance, 2 Horde), from two client calls about the player and
-- never about an item. nil for either the client will not answer; a spec replaces this.
function Tooltip.PlayerFacts()
  local level, word
  local unitLevel = rawget(_G, "UnitLevel")
  if type(unitLevel) == "function" then
    local ok, answer = pcall(unitLevel, "player")
    level = ok and tonumber(answer) or nil
  end
  -- Brief BQ13: the pretend level (Core/Demo.lua) while it is set, so every line drawn from these
  -- facts ("Useful at level", the Keep block, the item page through InfoPanel) reads it.
  local demo = ItemTree.Demo
  if type(demo) == "table" and type(demo.PlayerLevel) == "function" then
    local ok, pretend = pcall(demo.PlayerLevel, level)
    if ok then
      level = pretend
    end
  end
  local factionGroup = rawget(_G, "UnitFactionGroup")
  if type(factionGroup) == "function" then
    local ok, answer = pcall(factionGroup, "player")
    word = ok and answer or nil
  end
  -- Brief BQ14 follow up: the pretend side (Core/Demo.lua) while it is set.
  if type(demo) == "table" and type(demo.FactionWord) == "function" then
    local ok, pretend = pcall(demo.FactionWord)
    if ok and pretend then
      word = pretend
    end
  end
  local keep = ItemTree.Keep
  local faction = type(keep) == "table" and type(keep.FactionOf) == "function" and keep.FactionOf(word) or nil
  return level, faction
end

-- Brief PR9: the player's count of an item the profession route needs (Keep.ProfessionHave, one
-- local GetItemCount for this one item), or false for none: the setting is off, the route needs
-- none of it, or the module is not loaded. Read at draw time and stamped on the cached block, so
-- a bag change is seen on the next show rather than frozen in the cache.
function Tooltip.KeepCount(itemId, settings)
  settings = settings or (ItemTree.db and ItemTree.db.settings) or {}
  if not itemId or not settingOn(settings, "keepMarks") then
    return false
  end
  local keep = ItemTree.Keep
  if type(keep) ~= "table" or type(keep.ProfessionHave) ~= "function" then
    return false
  end
  local ok, have = pcall(keep.ProfessionHave, itemId)
  if ok and type(have) == "number" then
    return have
  end
  -- Brief Q1: or the count a quest only keep is held to (Keep.QuestHave), so the block's "the rest
  -- can go" line is built again when the count moves.
  if type(keep.QuestHave) == "function" then
    local level, faction = Tooltip.PlayerFacts()
    local read, count = pcall(keep.QuestHave, itemId, level, faction)
    if read and type(count) == "number" then
      return count
    end
  end
  return false
end

-- Brief K28: the links Tooltip.OnItem read for the one item it is drawing: the item's own (where
-- it names a random suffix roll) and, beside a comparison tooltip, the bag item's (against), then
-- the two rolls' keys OnItem worked out once (Tooltip.RollOf), for the block cache's stamp. Each nil
-- where it was read for another item, or there was none.
function Tooltip.KeepLinks(itemId, against)
  local link, roll = nil, nil
  if Tooltip.keepLinkItem == itemId then
    link, roll = Tooltip.keepLink, Tooltip.keepRoll
  end
  local againstLink, againstRoll = nil, nil
  if against ~= nil and Tooltip.keepAgainstItem == itemId and Tooltip.keepAgainst == against then
    againstLink, againstRoll = Tooltip.keepAgainstLink, Tooltip.keepAgainstRoll
  end
  return link, againstLink, roll, againstRoll
end

-- Brief BQ15 (QA 2026-10-10 item 4): Gold Pickup Schedule's tooltip read [Use] "Use it: starts a
-- quest" with no quest "!", where every other quest keep's "1 quest" line wears it. Core/Keep.lua
-- builds the [Use] quest verdict's one reason with no glyph (Keep.TagReasons, the BQ9 "do this
-- now" path), so the tooltip puts the quest glyph (Keep.KIND_ICONS.quest) on it here. Answers that
-- Assets key where the verdict's tag row is a quest action (its tags answer's action is
-- Keep.ACTION_QUEST), nil otherwise. Pure over the lines and Keep's constants.
function Tooltip.QuestActionArt(verdict, keep)
  if type(verdict) ~= "table" or type(keep) ~= "table" or keep.ACTION_QUEST == nil then
    return nil
  end
  for _, held in ipairs(verdict) do
    local answer = type(held) == "table" and held.head and held.tags or nil
    if type(answer) == "table" and answer.action == keep.ACTION_QUEST then
      local icons = type(keep.KIND_ICONS) == "table" and keep.KIND_ICONS or nil
      return (icons and icons.quest) or "CAT_QUEST"
    end
  end
  return nil
end

-- Brief UL1: one raw verdict line (Core/Keep.lua VerdictLines' shape, or Keep.UseLines' reason lines)
-- drawn as a block line { text, label, colorKey, keep = tone, icon, wrap = true, ... }, as Tooltip.KeepLines
-- drew each before (its loop, moved here unchanged so the uses lines draw the same way): the glyph
-- while icons is on, the words alone as the label, the marks the fold and the layout read. nil for a
-- line with no words. Pure but for the glyph markup.
local function drawnLine(held, keep, icons, questArt, tone)
  if type(held) ~= "table" or type(held.text) ~= "string" then
    return nil
  end
  -- Brief TB13: a chain line carries its professions' glyphs inline in its words. The label
  -- is the words with no escape in them, and with icons off the drawn words are too. Brief
  -- K24b: the tag row hands its plain words ("Keep, Auction") in held.plain, a spacer "".
  local plain = held.text
  if type(held.plain) == "string" then
    plain = held.plain
  elseif type(keep.Plain) == "function" then
    plain = keep.Plain(held.text) or held.text
  end
  if held.spacer then
    plain = " "
  end
  local art = held.icon
  -- Brief BQ15 (QA 2026-10-10 item 4): the [Use] "starts a quest" reason wears the quest "!".
  if art == nil and questArt and not held.head and not held.spacer and not held.muted then
    art = questArt
  end
  local line = iconLine(icons and held.text or plain, held.colorKey or COLOR_MUTED, nil, icons and art or nil)
  line.label = plain
  line.keep = tone
  line.wrap = true
  -- Brief TD1: the line's kind, from the glyph it wears whether or not icons are drawn; the tag row and
  -- the blank lines around it are no kind's, so no Tooltip display switch ever hides them.
  if not held.head and not held.tags and not held.spacer then
    line.category = Tooltip.LineCategory(art, plain, held.group)
  end
  -- Brief K20b: the head says whether the block lists the item's uses.
  if held.lists == false then
    line.lists = false
  end
  -- Brief TBR2: the muted "For Mages", which BuildLines leaves out under the class uses line.
  if held.classUse then
    line.classUse = true
  end
  -- Brief K24b: the blank lines around the tag row, and the row itself.
  if held.spacer then
    line.spacer = true
    line.label = ""
  end
  if held.tags then
    line.tags = true
    -- Brief BQ25a (item 68): the tag row of a [Use] "starts a quest" verdict, so the uses
    -- line leaves that quest out of its count (Tooltip.FoldStartedQuest).
    if questArt then
      line.startsQuest = true
    end
  end
  -- Brief BQ7: a use that is not the player's, for the fold (Tooltip.FoldUses).
  if held.other then
    line.other = true
    line.otherUses = held.otherUses
  end
  -- Brief BQ14: a profession line's rarity circles after its count; the label keeps the words.
  if held.qualities then
    line.qualities = held.qualities
    line.text = line.text .. Tooltip.QualityDots(held.qualities)
  end
  return line
end

-- Brief K11: the Keep verdict is a block of lines, a head and one line per reason, each reason
-- with its glyph at the left (Core/Keep.lua VerdictLines, the same list the item page draws).
-- Each comes back as a block line { text, label, colorKey, keep = tone, icon, wrap = true }: text
-- is the glyph's escape and the words, label the words alone (brief TB13: Keep.Plain, so a chain
-- line's inline profession glyphs never reach it, and with icons off never reach text either),
-- and the line's colour is the whole line's, so no colour escape is ever written into it (a
-- muted reason is a grey line, its glyph at full colour). The glyphs go and come with the
-- tooltip's icon setting, like every other icon in the block. Brief K2: wrap is on, so a long
-- line wraps rather than widening the tooltip. nil where the setting is off, the item has nothing
-- to say, or its rows are not loaded yet. Pure over Core/Keep.lua.
function Tooltip.KeepLines(itemId, settings)
  settings = settings or (ItemTree.db and ItemTree.db.settings) or {}
  if not itemId or not settingOn(settings, "keepMarks") then
    return nil
  end
  local keep = ItemTree.Keep
  if type(keep) ~= "table" or type(keep.ItemLines) ~= "function" then
    return nil
  end
  local level, faction = Tooltip.PlayerFacts()
  -- Brief PR9: the route line's "12 / 40 needed" count, the one CachedLines stamps on the block.
  local have = Tooltip.KeepCount(itemId, settings)
  -- Brief K24b: the real bound state of the bag slot this item is shown from (Tooltip.OnItem reads
  -- it for the one item it is drawing), nil where no slot is known.
  local bound = nil
  if Tooltip.keepBoundItem == itemId then
    bound = Tooltip.keepBound
  end
  -- Brief K24d: an item instance the player wears, or the client's comparison tooltip. Brief K24e:
  -- it reads [Keep] alone with the one reason "Equipped", no gear line (Tooltip.Worn, read by
  -- Tooltip.OnItem for the one item it draws).
  local worn = Tooltip.keepWornItem == itemId and Tooltip.keepWorn == true or nil
  -- Brief F160: a bag worn in a bag slot says which ("Equipped bag", "Equipped bank bag").
  local wornBag = worn and Tooltip.keepWornBag or nil
  -- Brief K24h: the bag item the client's comparison tooltip is shown beside (Tooltip.OnItem), so
  -- the worn item can say it is outdone by it.
  local against = nil
  if worn and Tooltip.keepAgainstItem == itemId then
    against = Tooltip.keepAgainst
  end
  -- Brief K26: the hunter's pet food read for this item (Tooltip.OnItem reads it for the one item
  -- it is drawing, Keep.PetFor), nil for anyone else.
  local pet = nil
  if Tooltip.keepPetItem == itemId then
    pet = Tooltip.keepPet
  end
  -- Brief K31: which copy of a profession tool is kept, read for this copy's bag slot
  -- (Tooltip.SlotTool), nil for anything else.
  local tool = nil
  if Tooltip.keepToolItem == itemId then
    tool = Tooltip.keepTool
  end
  -- Brief K28: the item's random suffix roll's link (Tooltip.OnItem reads it for the one item it
  -- draws), and the bag item's beside a comparison tooltip; nil for every other item.
  local link, againstLink = Tooltip.KeepLinks(itemId, against)
  local ok, verdict, tone = pcall(
    keep.ItemLines,
    itemId,
    level,
    faction,
    link,
    have or nil,
    bound,
    worn,
    against,
    pet,
    againstLink,
    tool,
    wornBag
  )
  if not ok or type(verdict) ~= "table" then
    return nil
  end
  -- Brief BQ24: the quest count steps aside for the quest lines that name what it counts.
  verdict = Tooltip.FoldQuestCountFor(verdict, itemId, level, faction, link)
  -- QA item 158: the quests the player cannot take yet, one muted line folded under the modifier.
  verdict = Tooltip.FoldAheadQuestsFor(verdict, itemId, level, faction, link)
  -- Brief HF1 (QA item 181): and another class's quests, and the other side's with "Hide other faction
  -- data" off, one muted line each in the same more section.
  verdict = Tooltip.FoldOtherQuestsFor(verdict, itemId, level, faction, link)
  -- Brief UL2 (QA item 367): and the uses behind the character, in the same more section.
  verdict = Tooltip.FoldBehindUsesFor(verdict, itemId, level, faction, link)
  local icons = settingOn(settings, "tooltipShowIcons")
  local questArt = Tooltip.QuestActionArt(verdict, keep)
  local out = {}
  for _, held in ipairs(verdict) do
    local line = drawnLine(held, keep, icons, questArt, tone)
    if line then
      out[#out + 1] = line
    end
  end
  if #out == 0 then
    return nil
  end
  return out
end

-- Brief UL1 (QA item 347i, the owner on "Used in 15 recipes, 1 quest": "What in the 15 recipes and
-- quest is useful to the player? We need to pull out the useful items and hide the other items behind
-- other uses"): the uses lines that stand where the one "Used in" line stood (Tooltip.UsesText), for an
-- item whose Keep block lists no uses (no block, or one whose reasons are about something else: [Use],
-- a tool, Sold by vendors everywhere). The item's uses in the Keep block's shape (Core/Keep.lua
-- Keep.UseLines over the cached score Keep.CachedScore answers, the very score the block was built
-- from): the character's own professions one line each with the glyph and dots, the quests named with
-- their counts, the crates in the need shape; the other professions, the chains through them, the
-- quests ahead, another class's, the other side's, the repeatable and the held back ones marked as
-- uses that are not the character's, as the block marks them (Tooltip.FoldQuestCount,
-- Tooltip.FoldAheadQuests, Tooltip.FoldOtherQuests), for Tooltip.FoldUses to fold into "N other uses,
-- hold Ctrl" (the caller folds, knowing what stands above). startsQuest (true beside a [Use] "Use it:
-- starts a quest" block, which names that quest) leaves the quest it starts out (Keep.WithoutStartedQuest).
-- block (optional, the drawn Keep block) leaves out a line whose words the block already draws. The
-- player's count of the item (Tooltip.KeepCount) reaches the need lines. A list of drawn lines (empty
-- for none), or nil where no score is there to read (Keep not loaded, the rows not yet loaded): the
-- caller draws the one "Used in" line then, as before. Pure over Core/Keep.lua.
function Tooltip.UseLines(itemId, settings, startsQuest, block)
  settings = settings or (ItemTree.db and ItemTree.db.settings) or {}
  local keep = ItemTree.Keep
  if type(itemId) ~= "number" or type(keep) ~= "table" then
    return nil
  end
  if type(keep.UseLines) ~= "function" or type(keep.CachedScore) ~= "function" then
    return nil
  end
  local level, faction = Tooltip.PlayerFacts()
  local link = Tooltip.KeepLinks(itemId)
  local ok, score = pcall(keep.CachedScore, itemId, level, faction, nil, nil, nil, link)
  if not ok or type(score) ~= "table" then
    return nil
  end
  if startsQuest and type(keep.WithoutStartedQuest) == "function" then
    score = keep.WithoutStartedQuest(score)
  end
  local have = Tooltip.KeepCount(itemId, settings)
  local built, raw = pcall(keep.UseLines, score, have or nil)
  if not built or type(raw) ~= "table" then
    return nil
  end
  -- The Keep block's colours: the reasons' white, a muted line grey (Keep.VerdictLines' body colour).
  local body = type(keep.BODY_COLOR) == "string" and keep.BODY_COLOR or COLOR_BODY
  for _, held in ipairs(raw) do
    if type(held) == "table" and held.colorKey == nil then
      held.colorKey = held.muted and COLOR_MUTED or body
    end
  end
  -- The same three folds the block's lines take (Tooltip.KeepLines), over the same score.
  local open = tonumber((score.kinds or {}).quest) or 0
  if open > 0 then
    local title = nil
    if open == 1 and type(score.questIds) == "table" and type(keep.QuestTitle) == "function" then
      local asked, found = pcall(keep.QuestTitle, score.questIds[1])
      title = asked and found or nil
    end
    raw = Tooltip.FoldQuestCount(raw, open, score.done, score.abandoned, title or L["Quest"])
  end
  raw = Tooltip.FoldAheadQuests(raw, score.questsAhead, score.questsAheadFrom)
  raw = Tooltip.FoldOtherQuests(raw, Tooltip.OtherQuestLines(score, faction))
  -- Brief UL2 (QA item 367): and the uses behind the character.
  raw = Tooltip.FoldBehindUses(raw, score)
  local said = {}
  for _, line in ipairs(type(block) == "table" and block or {}) do
    if type(line) == "table" and type(line.label) == "string" then
      said[line.label] = true
    end
  end
  local icons = settingOn(settings, "tooltipShowIcons")
  local out = {}
  for _, held in ipairs(raw) do
    local line = drawnLine(held, keep, icons, nil, nil)
    if line and not said[line.label] then
      out[#out + 1] = line
    end
  end
  return out
end

-- Brief BQ24 (owner QA 2026-10-10 item 23, Okra: "1 quest" over "Westfall Stew (II) (12 / 3
-- needed)"): the quest count line of a Keep block steps aside for the quest lines that name what it
-- counts. lines is a verdict's raw lines ({ text, icon }, Core/Keep.lua VerdictLines); open, done
-- and abandoned the score's quest counts (kinds.quest, done, abandoned) and title the one open
-- quest's title (Keep.QuestTitle), nil where none is known. The count line is the line whose words
-- are Keep.QuestWords(open, done, abandoned); a named line is the quest line under it starting with
-- the title (only one open quest is ever named). Every counted quest named: the count line goes.
-- More counted than named: the count line goes and "and N other quests" follows the named lines,
-- the finished ones in brackets as the count line had them (brief UL1: the finished ones follow as
-- their own lines instead, "1 quest (completed)", Keep.DoneLines). None named: unchanged. A fresh list
-- where anything moved, else the same one. Pure but for Keep's own word builders.
-- Brief BQ25b (owner QA 2026-10-10 item 48 b): with two open quests or more the quest line beneath
-- reads the count itself ("2 quests (12 / 8 needed)"); where it carries the very count line's words
-- the count line goes, so the count is said once. title is not needed for that case.
function Tooltip.FoldQuestCount(lines, open, done, abandoned, title)
  local keep = ItemTree.Keep
  open = math.max(0, math.floor(tonumber(open) or 0))
  done = math.max(0, math.floor(tonumber(done) or 0))
  if type(lines) ~= "table" or open < 1 then
    return lines
  end
  if open == 1 and (type(title) ~= "string" or title == "") then
    return lines
  end
  if type(keep) ~= "table" or type(keep.QuestWords) ~= "function" then
    return lines
  end
  local questIcon = type(keep.KIND_ICONS) == "table" and keep.KIND_ICONS.quest or nil
  local countWords = keep.QuestWords(open, done, abandoned)
  local countAt = nil
  for index, line in ipairs(lines) do
    if type(line) == "table" and line.text == countWords and (questIcon == nil or line.icon == questIcon) then
      countAt = index
      break
    end
  end
  if countAt == nil then
    return lines
  end
  local namedAt = nil
  local nextLine = lines[countAt + 1]
  -- Brief UL1 (the uses line matrix's "Finished quests, two counts of one set": "6 quests (1
  -- completed)" stayed above "5 quests (0 / 270 needed)"): the need line of two or more open quests
  -- reads their own count, so the count line goes whatever it holds in brackets.
  local sameCount = string.format(L["%d quests"], open) .. " ("
  if
    open > 1
    and type(nextLine) == "table"
    and type(nextLine.text) == "string"
    and (questIcon == nil or nextLine.icon == questIcon)
    and nextLine.text:sub(1, #sameCount) == sameCount
  then
    namedAt = countAt + 1
  elseif
    open == 1
    and type(title) == "string"
    and type(nextLine) == "table"
    and type(nextLine.text) == "string"
    and (questIcon == nil or nextLine.icon == questIcon)
    and nextLine.text:sub(1, #title) == title
  then
    namedAt = countAt + 1
  end
  if namedAt == nil then
    return lines
  end
  -- Brief UL1 (the owner's design-5, "1 quest (completed)"; the matrix's "Two kinds of 'and N
  -- other'"): the finished quests the count line held in brackets follow the need line as their own
  -- lines (Keep.DoneLines, "1 quest (completed)"), where they read "and 1 other quest (1 completed)".
  local doneLines = {}
  if done > 0 and type(keep.DoneLines) == "function" then
    doneLines = keep.DoneLines({ done = done, abandoned = abandoned })
  end
  local out = {}
  for index, line in ipairs(lines) do
    if index ~= countAt then
      out[#out + 1] = line
    end
    if index == namedAt then
      for _, extra in ipairs(doneLines) do
        out[#out + 1] = extra
      end
    end
  end
  return out
end

-- Brief BQ24: Tooltip.FoldQuestCount over an item's verdict lines, the score read through the same
-- cached seam the verdict was (Keep.CachedScore). The lines unchanged where the score is not there.
function Tooltip.FoldQuestCountFor(lines, itemId, level, faction, link)
  local keep = ItemTree.Keep
  if type(lines) ~= "table" or type(keep) ~= "table" or type(keep.CachedScore) ~= "function" then
    return lines
  end
  local ok, score = pcall(keep.CachedScore, itemId, level, faction, nil, nil, nil, link)
  if not ok or type(score) ~= "table" then
    return lines
  end
  local open = tonumber((score.kinds or {}).quest) or 0
  if open < 1 then
    return lines
  end
  local title = nil
  if open == 1 and type(score.questIds) == "table" and type(keep.QuestTitle) == "function" then
    local asked, found = pcall(keep.QuestTitle, score.questIds[1])
    title = asked and found or nil
  end
  if title == nil and type(L["Quest"]) == "string" then
    title = L["Quest"]
  end
  return Tooltip.FoldQuestCount(lines, open, score.done, score.abandoned, title)
end

-- QA item 158 (the owner, 2026-10-14, Runecloth on a level 15 hunter with the pretend level on:
-- "They should still show in the tooltip though under the more section if they aren't relevant to
-- me now"): the quests of the player's own side and class that the player cannot take for a while
-- yet (Keep.ScoreUses' questsAhead, Keep.QuestOutOfReach) are in no line of the Keep block, and
-- where the block lists the item's uses the uses line ("Used in 29 recipes, 6 quests") steps aside
-- for it (brief K18), so they left the tooltip entirely. Now they are one muted line with the quest
-- mark, "5 quests from level 50" (from, the lowest minimum level among them, Keep.ScoreUses'
-- questsAheadFrom), "1 quest from level 50" for one, "5 quests" where no level is known, marked as a
-- use that is not the player's (Keep.MarkOtherUse) so brief BQ7's fold counts it in "and N other
-- uses, hold Ctrl" and draws it while the modifier is held. It goes after the block's last quest
-- line, else at the block's end. lines is a verdict's raw lines (Keep.VerdictLines). The lines
-- unchanged where nothing is ahead or the block does not list the uses (a line with lists false):
-- the uses line stays then and its count holds them. The other side's quests (brief QS1) are never
-- among them. A fresh list where a line went in. Pure but for Keep's constants.
function Tooltip.FoldAheadQuests(lines, ahead, from)
  ahead = math.max(0, math.floor(tonumber(ahead) or 0))
  if type(lines) ~= "table" or ahead < 1 then
    return lines
  end
  for _, line in ipairs(lines) do
    if type(line) == "table" and line.lists == false then
      return lines
    end
  end
  local keep = ItemTree.Keep
  local questIcon = type(keep) == "table" and type(keep.KIND_ICONS) == "table" and keep.KIND_ICONS.quest or nil
  from = tonumber(from)
  local words
  if from and from > 0 and ahead == 1 then
    words = string.format(L["1 quest from level %d"], math.floor(from))
  elseif from and from > 0 then
    words = string.format(L["%d quests from level %d"], ahead, math.floor(from))
  else
    words = plural(ahead, "%d quest", "%d quests")
  end
  local added = {
    text = words,
    plain = words,
    colorKey = COLOR_MUTED,
    icon = questIcon,
    muted = true,
  }
  if type(keep) == "table" and type(keep.MarkOtherUse) == "function" then
    added = keep.MarkOtherUse(added, true, ahead)
  else
    added.other, added.otherUses = true, ahead
  end
  local at = nil
  for index, line in ipairs(lines) do
    if type(line) == "table" and not line.spacer and not line.head then
      if questIcon ~= nil and line.icon == questIcon then
        at = index + 1
      end
    end
  end
  if at == nil then
    at = #lines + 1
    while at > 1 and type(lines[at - 1]) == "table" and lines[at - 1].spacer do
      at = at - 1
    end
  end
  local out = {}
  for index, line in ipairs(lines) do
    if index == at then
      out[#out + 1] = added
    end
    out[#out + 1] = line
  end
  if at > #lines then
    out[#out + 1] = added
  end
  return out
end

-- QA item 158: Tooltip.FoldAheadQuests over an item's verdict lines, the score read through the same
-- cached seam the verdict was (Keep.CachedScore). The lines unchanged where the score is not there.
function Tooltip.FoldAheadQuestsFor(lines, itemId, level, faction, link)
  local keep = ItemTree.Keep
  if type(lines) ~= "table" or type(keep) ~= "table" or type(keep.CachedScore) ~= "function" then
    return lines
  end
  local ok, score = pcall(keep.CachedScore, itemId, level, faction, nil, nil, nil, link)
  if not ok or type(score) ~= "table" then
    return lines
  end
  return Tooltip.FoldAheadQuests(lines, score.questsAhead, score.questsAheadFrom)
end

-- Brief HF1 (owner QA 2026-10-17 item 181, Runecloth on his Alliance hunter at `/itemtree demo level
-- 55`: the tooltip said 5 quests where the step said 6, and stayed at 5 with "Hide other faction
-- data" off where he expected about 10). The Keep block's quest line counts the quests this
-- character can take (each one, never folded into a family: 6031 and the four Alliance donations),
-- so the listed quests it leaves out had no line at all: another class's (7642 Collection of Goods,
-- the paladins') and, with the setting off, the other side's (the four Horde donations, stale uses).
-- Now each is one muted quest line, a use that is not the player's (Keep.MarkOtherUse), so brief
-- BQ7's fold counts it in "and N other uses, hold Ctrl" and draws it while the modifier is held, as
-- QA item 158's quests ahead are: "1 Paladin quest", "4 Horde quests". The block's quest lines then
-- add up to the item page's "Used in 29 recipes, 6 quests" (10 with the setting off) and to the
-- Used by tab's quest rows that carry no Predicted mark. score is Keep's (Keep.ScoreUses'
-- otherClassMasks and questsShownOtherSide); playerFaction 1 or 2. A list of raw lines, empty for
-- none. Pure but for Keep's constants and words.
function Tooltip.OtherQuestLines(score, playerFaction)
  local out = {}
  local keep = ItemTree.Keep
  if type(score) ~= "table" or type(keep) ~= "table" then
    return out
  end
  local questIcon = type(keep.KIND_ICONS) == "table" and keep.KIND_ICONS.quest or nil
  local function add(words, count)
    local line = { text = words, plain = words, colorKey = COLOR_MUTED, icon = questIcon, muted = true }
    if type(keep.MarkOtherUse) == "function" then
      line = keep.MarkOtherUse(line, true, count)
    else
      line.other, line.otherUses = true, count
    end
    out[#out + 1] = line
  end
  local masks = type(score.otherClassMasks) == "table" and score.otherClassMasks or {}
  if #masks > 0 then
    local named, classIds = {}, {}
    for _, mask in ipairs(masks) do
      local ids = type(keep.MaskClasses) == "function" and keep.MaskClasses(mask) or {}
      for _, classId in ipairs(ids) do
        if not named[classId] then
          named[classId] = true
          classIds[#classIds + 1] = classId
        end
      end
    end
    table.sort(classIds)
    local classes = type(keep.ClassListWords) == "function" and keep.ClassListWords(classIds) or nil
    local words
    if classes and #masks == 1 then
      words = string.format(L["1 %s quest"], classes)
    elseif classes then
      words = string.format(L["%d %s quests"], #masks, classes)
    elseif #masks == 1 then
      words = L["1 quest for another class"]
    else
      words = string.format(L["%d quests for other classes"], #masks)
    end
    add(words, #masks)
  end
  local shown = math.floor(tonumber(score.questsShownOtherSide) or 0)
  if shown > 0 and (playerFaction == 1 or playerFaction == 2) then
    local words
    if playerFaction == 1 and shown == 1 then
      words = L["1 Horde quest"]
    elseif playerFaction == 1 then
      words = string.format(L["%d Horde quests"], shown)
    elseif shown == 1 then
      words = L["1 Alliance quest"]
    else
      words = string.format(L["%d Alliance quests"], shown)
    end
    add(words, shown)
  end
  -- Brief RB1b (the owner's answer of 2026-10-17 on item 190, "B but make repeatable quests never
  -- relevant (so always collapsed)"): the repeatable quests the page counts (score.questsRepeat, Keep
  -- never keeps for them), one muted line folded under the modifier like another class's quests.
  local repeats = math.floor(tonumber(score.questsRepeat) or 0)
  if repeats > 0 then
    add(repeats == 1 and L["1 repeatable quest"] or string.format(L["%d repeatable quests"], repeats), repeats)
  end
  -- Brief RB1c (the owner's ruling "A" of 2026-10-17): the quests an instance holds back until the
  -- character has been inside (score.gatedByGate), one muted line a gate, folded the same way:
  -- "8 Naxxramas quests".
  local byGate = type(score.gatedByGate) == "table" and score.gatedByGate or {}
  local flags = ItemTree.QuestFlags
  -- Brief WS1 (the owner's ruling "A for writs" of 2026-10-17 night): the quests held back by their
  -- starter (QuestFlags.STARTER_GATE) come last, one line of their own: "1 quest (started by an item
  -- you don't have)" (brief LF1, QA item 243: the owner's words, the qualifier in brackets; WS1 wrote
  -- "1 quest started by an item you do not have").
  local starterGate = type(flags) == "table" and flags.STARTER_GATE or nil
  local gateIds = {}
  for gate in pairs(byGate) do
    if gate ~= starterGate then
      gateIds[#gateIds + 1] = gate
    end
  end
  table.sort(gateIds)
  if starterGate ~= nil and byGate[starterGate] ~= nil then
    gateIds[#gateIds + 1] = starterGate
  end
  for _, gate in ipairs(gateIds) do
    local count = math.floor(tonumber(byGate[gate]) or 0)
    if count > 0 then
      local name = type(flags) == "table" and type(flags.GateName) == "function" and flags.GateName(gate) or nil
      local words
      if gate == starterGate and count == 1 then
        words = L["1 quest (started by an item you don't have)"]
      elseif gate == starterGate then
        words = string.format(L["%d quests (started by items you don't have)"], count)
      elseif name and count == 1 then
        words = string.format(L["1 %s quest"], name)
      elseif name then
        words = string.format(L["%d %s quests"], count, name)
      -- Brief LF1 (QA item 243, the owner: "This is misleading wording because the quest isnt in the
      -- instance we just track the quest by if you entered the instance. So remove that text"): a gate
      -- the data names no instance for says the count alone (RB1c: "3 quests in an instance you have
      -- not entered").
      elseif count == 1 then
        words = L["1 quest"]
      else
        words = string.format(L["%d quests"], count)
      end
      add(words, count)
    end
  end
  return out
end

-- Brief HF1: Tooltip.OtherQuestLines put into a verdict's raw lines after the block's last quest line
-- (QA item 158's quests ahead among them), else at its end above any trailing spacer. The lines
-- unchanged where there are none or the block does not list the uses (a line with lists false: the
-- uses line stays then and its count holds them). A fresh list where lines went in. Pure.
function Tooltip.FoldOtherQuests(lines, added)
  if type(lines) ~= "table" or type(added) ~= "table" or #added == 0 then
    return lines
  end
  for _, line in ipairs(lines) do
    if type(line) == "table" and line.lists == false then
      return lines
    end
  end
  local keep = ItemTree.Keep
  local questIcon = type(keep) == "table" and type(keep.KIND_ICONS) == "table" and keep.KIND_ICONS.quest or nil
  local at = nil
  for index, line in ipairs(lines) do
    if type(line) == "table" and not line.spacer and not line.head then
      if questIcon ~= nil and line.icon == questIcon then
        at = index + 1
      end
    end
  end
  if at == nil then
    at = #lines + 1
    while at > 1 and type(lines[at - 1]) == "table" and lines[at - 1].spacer do
      at = at - 1
    end
  end
  local out = {}
  for index, line in ipairs(lines) do
    if index == at then
      for _, extra in ipairs(added) do
        out[#out + 1] = extra
      end
    end
    out[#out + 1] = line
  end
  if at > #lines then
    for _, extra in ipairs(added) do
      out[#out + 1] = extra
    end
  end
  return out
end

-- Brief RB1d: the quests that are not the player's for an item's uses line (Tooltip.OtherQuestLines over
-- the cached score Keep.CachedScore answers for the player's level and side), that score and the side.
-- An empty list and nil where there is no score (the item tables not loaded, Keep absent).
function Tooltip.OtherQuestsFor(itemId)
  local keep = ItemTree.Keep
  if type(itemId) ~= "number" or type(keep) ~= "table" or type(keep.CachedScore) ~= "function" then
    return {}, nil
  end
  local level, faction = Tooltip.PlayerFacts()
  local link = Tooltip.KeepLinks(itemId)
  local ok, score = pcall(keep.CachedScore, itemId, level, faction, nil, nil, nil, link)
  if not ok or type(score) ~= "table" then
    return {}, nil
  end
  return Tooltip.OtherQuestLines(score, faction), score, faction
end

-- Brief RB1d: a summary less the quests the folded lines name that Tooltip.TooltipSummary kept in its
-- count: another class's (score.otherClassMasks, one a quest, less score.otherClassSeenOther, those
-- only the other side was seen taking, which TooltipSummary took out) and the other side's the player
-- sees with "Hide other faction data" off (score.questsShownOtherSide, named only where the player's
-- side is known, playerFaction 1 or 2, as Tooltip.OtherQuestLines names it). The repeatable and the
-- held back quests TooltipSummary took out already (Keep scores neither). A fresh table where any go;
-- the summary itself otherwise. Pure.
function Tooltip.WithoutOtherQuests(summary, score, playerFaction)
  if type(summary) ~= "table" or type(score) ~= "table" then
    return summary
  end
  local masks = type(score.otherClassMasks) == "table" and #score.otherClassMasks or 0
  masks = math.max(0, masks - math.max(0, math.floor(tonumber(score.otherClassSeenOther) or 0)))
  local shown = 0
  if playerFaction == 1 or playerFaction == 2 then
    shown = math.max(0, math.floor(tonumber(score.questsShownOtherSide) or 0))
  end
  local other = masks + shown
  if other <= 0 then
    return summary
  end
  local copy = {}
  for key, value in pairs(summary) do
    copy[key] = value
  end
  copy.quests = math.max(0, (tonumber(summary.quests) or 0) - other)
  copy.total = math.max(0, (tonumber(summary.total) or 0) - other)
  return copy
end

-- Brief RB1d: Tooltip.OtherQuestLines' raw lines drawn as Tooltip.KeepLines draws a block's: the quest
-- glyph before the words while "Show icons" is on, the words alone as the label, wrapped, and still
-- marked as uses that are not the player's (line.other, line.otherUses), so Tooltip.FoldUses folds them
-- and Tooltip.HasFoldable watches the modifier for them. A fresh list. Pure but for the glyph markup.
function Tooltip.DrawnOtherQuests(raw, settings)
  local out = {}
  local icons = settingOn(settings or {}, "tooltipShowIcons")
  for _, held in ipairs(type(raw) == "table" and raw or {}) do
    if type(held) == "table" and type(held.text) == "string" then
      local plain = type(held.plain) == "string" and held.plain or held.text
      local line = iconLine(icons and held.text or plain, held.colorKey or COLOR_MUTED, nil, icons and held.icon or nil)
      line.label = plain
      line.wrap = true
      -- Brief TD1: each wears the quest mark, so each is a quest line (Tooltip.LineCategory).
      line.category = Tooltip.LineCategory(held.icon, plain, held.group)
      if held.other then
        line.other = true
        line.otherUses = held.otherUses
      end
      out[#out + 1] = line
    end
  end
  return out
end

-- Brief RB1d: whether a Keep block already lists the other quests (Tooltip.FoldOtherQuests puts them
-- into every block but one whose lines are not a list of the uses, a line with lists false). Pure.
function Tooltip.ListsOtherQuests(block)
  if type(block) ~= "table" then
    return false
  end
  for _, line in ipairs(block) do
    if type(line) == "table" and line.lists == false then
      return false
    end
  end
  return true
end

-- Brief HF1: Tooltip.FoldOtherQuests over an item's verdict lines, the score read through the same
-- cached seam the verdict was (Keep.CachedScore). The lines unchanged where the score is not there.
function Tooltip.FoldOtherQuestsFor(lines, itemId, level, faction, link)
  local keep = ItemTree.Keep
  if type(lines) ~= "table" or type(keep) ~= "table" or type(keep.CachedScore) ~= "function" then
    return lines
  end
  local ok, score = pcall(keep.CachedScore, itemId, level, faction, nil, nil, nil, link)
  if not ok or type(score) ~= "table" then
    return lines
  end
  return Tooltip.FoldOtherQuests(lines, Tooltip.OtherQuestLines(score, faction))
end

-- Brief UL2 (QA item 367, the owner's ruling B: "Count them in 'and N other uses, hold Ctrl'"): the uses
-- behind the character (Core/Keep.lua Keep.BehindLines: "74 recipes below your level", another class's
-- spells), marked as uses that are not theirs, put at the end of a verdict's raw lines above any
-- trailing spacer, so brief BQ7's fold counts them in "and N other uses, hold Ctrl" and draws them
-- while the modifier is held, as the quests ahead (QA item 158). A line whose words the lines already
-- hold is not added twice. The lines unchanged where there are none or the block does not list the
-- uses (a line with lists false: the uses lines carry them then). A fresh list where lines went in.
-- Pure but for Keep's words.
function Tooltip.FoldBehindUses(lines, score)
  local keep = ItemTree.Keep
  if type(lines) ~= "table" or type(score) ~= "table" or type(keep) ~= "table" then
    return lines
  end
  if type(keep.BehindLines) ~= "function" then
    return lines
  end
  local said = {}
  for _, line in ipairs(lines) do
    if type(line) == "table" and line.lists == false then
      return lines
    end
    if type(line) == "table" and type(line.text) == "string" then
      said[line.plain or (type(keep.Plain) == "function" and keep.Plain(line.text)) or line.text] = true
    end
  end
  -- Brief UL3 (QA item 369): a profession's recipes behind join that profession's own folded line, counted
  -- together ("8 x Engineering" and 26 behind read "34 x Engineering", the dots joined); a profession with
  -- no folded line here gets one of its own.
  local folded = {}
  for index, line in ipairs(lines) do
    if type(line) == "table" and line.other and type(line.groupName) == "string" then
      folded[line.groupName] = index
    end
  end
  local merged, added = nil, {}
  for _, line in ipairs(keep.BehindLines(score)) do
    local at = type(line.groupName) == "string" and folded[line.groupName] or nil
    if at then
      merged = merged or {}
      local base = merged[at] or lines[at]
      local copy = {}
      for key, value in pairs(base) do
        copy[key] = value
      end
      copy.groupCount = (tonumber(base.groupCount) or 0) + (tonumber(line.groupCount) or 0)
      copy.otherUses = (tonumber(base.otherUses) or 0) + (tonumber(line.otherUses) or 0)
      copy.text = type(keep.GroupWords) == "function"
          and keep.GroupWords({ name = base.groupName, count = copy.groupCount })
        or copy.text
      copy.plain = nil
      if line.qualities and type(keep.MaskUnion) == "function" then
        copy.qualities = keep.MaskUnion(tonumber(base.qualities) or 0, line.qualities)
      end
      merged[at] = copy
    elseif not said[line.text] then
      line.colorKey = COLOR_MUTED
      added[#added + 1] = line
    end
  end
  if merged then
    local swapped = {}
    for index, line in ipairs(lines) do
      swapped[index] = merged[index] or line
    end
    lines = swapped
  end
  if #added == 0 then
    return lines
  end
  local at = #lines + 1
  while at > 1 and type(lines[at - 1]) == "table" and lines[at - 1].spacer do
    at = at - 1
  end
  local out = {}
  for index, line in ipairs(lines) do
    if index == at then
      for _, extra in ipairs(added) do
        out[#out + 1] = extra
      end
    end
    out[#out + 1] = line
  end
  if at > #lines then
    for _, extra in ipairs(added) do
      out[#out + 1] = extra
    end
  end
  return out
end

-- Brief UL2: Tooltip.FoldBehindUses over an item's verdict lines, the score read through the same cached
-- seam the verdict was (Keep.CachedScore). The lines unchanged where the score is not there.
function Tooltip.FoldBehindUsesFor(lines, itemId, level, faction, link)
  local keep = ItemTree.Keep
  if type(lines) ~= "table" or type(keep) ~= "table" or type(keep.CachedScore) ~= "function" then
    return lines
  end
  local ok, score = pcall(keep.CachedScore, itemId, level, faction, nil, nil, nil, link)
  if not ok or type(score) ~= "table" then
    return lines
  end
  return Tooltip.FoldBehindUses(lines, score)
end

-- The Keep lines' words with no glyph or colour in them, joined by new lines, or nil.
function Tooltip.KeepText(itemId, settings)
  local lines = Tooltip.KeepLines(itemId, settings)
  if not lines then
    return nil
  end
  local words = {}
  for _, line in ipairs(lines) do
    -- Brief K24b: the blank spacers around the tag row are left out.
    if not line.spacer then
      words[#words + 1] = line.label
    end
  end
  return table.concat(words, "\n")
end

-- Brief BQ7 (owner QA item 19, 2026-10-10): "Hide irrelevant uses", on by default. The Keep block's
-- lines for uses that are not the player's (another profession's recipes, a chain through a
-- profession they lack: Core/Keep.lua Keep.MarkOtherUse) fold into one muted line, "and N other
-- uses, hold Ctrl", where the first of them stood; N counts the uses those lines count. While the
-- player holds the modifier (tooltipUsesModifier: Ctrl by default, so it lines up with Ctrl + right
-- click, or Shift or Alt) every line shows. The modifier is only read (IsControlKeyDown and its
-- two siblings), never bound, hooked or consumed, so the client's own Shift compare and Ctrl dress
-- up are untouched. The item page lists every use whatever the setting.
Tooltip.USES_MODIFIER_DEFAULT = "ctrl"
local MODIFIER_READERS = { ctrl = "IsControlKeyDown", shift = "IsShiftKeyDown", alt = "IsAltKeyDown" }

-- The modifier the setting names: "ctrl", "shift" or "alt", Ctrl for anything else. Pure.
function Tooltip.UsesModifier(settings)
  local key = type(settings) == "table" and settings.tooltipUsesModifier or nil
  if type(key) == "string" and MODIFIER_READERS[key] then
    return key
  end
  return Tooltip.USES_MODIFIER_DEFAULT
end

-- The modifier's word on the folded line. Written out one literal at a time for the locale sweep.
-- Pure.
function Tooltip.ModifierWord(key)
  if key == "shift" then
    return L["Shift"]
  elseif key == "alt" then
    return L["Alt"]
  end
  return L["Ctrl"]
end

-- Whether the player holds the setting's modifier now: one read of the client's own key state,
-- false where the client will not say.
function Tooltip.UsesHeld(settings)
  -- Brief E2E-1 (the e2e plan's addition 5): the demo state's pretend modifier first (Core/Demo.lua
  -- Demo.SetModifier, set by the developer only e2e run); the demo marker line says it is on.
  local demo = ItemTree.Demo
  if type(demo) == "table" and type(demo.ModifierHeld) == "function" then
    local ok, pretended = pcall(demo.ModifierHeld)
    if ok and pretended == true then
      return true
    end
  end
  local read = rawget(_G, MODIFIER_READERS[Tooltip.UsesModifier(settings)])
  if type(read) ~= "function" then
    return false
  end
  local ok, held = pcall(read)
  return (ok and held) and true or false
end

-- The block with its other uses folded: unchanged where hide is off, the modifier is held or no
-- line is marked other; else a fresh list with every marked line gone and one muted line, "and N
-- other uses, hold <word>". Brief BQ25a (the owner's QA item 62, Minor Mana Potion: the quest need
-- line sat under "and 1 other use, hold Ctrl"): the fold line goes after the last line the block
-- keeps (the lines the character owns: profession lines, quest need lines, their own chains), never
-- above one; spacers after it stay last.
-- Brief TV1 (QA item 347, the owner: "we should never have a bare 'and 1 other...' if there is only
-- ever a single option"; "Maybe it just becomes 13 uses...etc No 'and' and no 'other'"): marked lines
-- that count one use in all are not folded (the line stands in its place, its glyph with it), and a
-- fold with no line of the block above it (the tag row and the gaps aside) reads "13 uses, hold
-- Ctrl". follows (optional) is true where a line drawn above these lines lists uses (the uses line,
-- a Keep block's reasons), so the fold reads "and 13 other uses" whatever stands above it here. Pure.
function Tooltip.FoldUses(lines, hide, held, word, follows)
  if type(lines) ~= "table" or not hide or held then
    return lines
  end
  local out, at, count, first = {}, nil, 0, nil
  -- Brief BQ14: the folded lines' qualities joined, the fold line's circles.
  local qualities = 0
  local keep = ItemTree.Keep
  for _, line in ipairs(lines) do
    if type(line) == "table" and line.other then
      count = count + math.max(1, tonumber(line.otherUses) or 1)
      if line.qualities and type(keep) == "table" and type(keep.MaskUnion) == "function" then
        qualities = keep.MaskUnion(qualities, line.qualities)
      end
      if at == nil then
        at, first = #out + 1, line
      end
    else
      out[#out + 1] = line
    end
  end
  -- Brief TV1: one use in all is shown, never folded.
  if at == nil or count <= 1 then
    return lines
  end
  word = type(word) == "string" and word or Tooltip.ModifierWord(Tooltip.USES_MODIFIER_DEFAULT)
  -- Brief BQ25a (item 62): after the last kept line that is not a spacer, where that is below the
  -- first folded line's place.
  for index = #out, at, -1 do
    local line = out[index]
    if type(line) == "table" and not line.spacer then
      at = index + 1
      break
    end
  end
  -- Brief TV1: whether a line of the block stands above the fold (the tag row and the gaps aside).
  local above = follows == true
  for index = 1, at - 1 do
    local line = out[index]
    if type(line) == "table" and not line.spacer and not line.tags and not line.head then
      above = true
    end
  end
  local text
  if above then
    text = string.format(L["and %d other uses, hold %s"], count, word)
  else
    text = string.format(L["%d uses, hold %s"], count, word)
  end
  local fold = iconLine(text, COLOR_MUTED, nil, nil)
  if qualities > 0 then
    fold.qualities = qualities
    fold.text = fold.text .. Tooltip.QualityDots(qualities)
  end
  fold.keep = first.keep
  fold.wrap = true
  fold.folded = true
  table.insert(out, at, fold)
  return out
end

-- Whether a block would be built unfolded because the modifier is held: true only with the setting
-- on and the modifier down, so the cache keeps one block for each (Tooltip.CachedLines).
function Tooltip.FoldHeldStamp(settings)
  settings = settings or (ItemTree.db and ItemTree.db.settings) or {}
  return settingOn(settings, "tooltipHideOtherUses") and Tooltip.UsesHeld(settings)
end

-- The Keep block as the tooltip draws it, the setting and the held modifier applied
-- (Tooltip.FoldUses). nil for nil. Brief TV1: follows as Tooltip.FoldUses'.
function Tooltip.FoldKeepLines(lines, settings, follows)
  if type(lines) ~= "table" then
    return lines
  end
  settings = settings or (ItemTree.db and ItemTree.db.settings) or {}
  local hide = settingOn(settings, "tooltipHideOtherUses")
  local held = hide and Tooltip.UsesHeld(settings) or false
  return Tooltip.FoldUses(lines, hide, held, Tooltip.ModifierWord(Tooltip.UsesModifier(settings)), follows)
end

-- Brief TD1 (a player's CurseForge comment: "Can you add a setting so ItemTree doesn't add quests to
-- tooltips?"; the owner, 2026-10-23: a Tooltip display section, a switch per kind of line, all on by
-- default). Three kinds of line are told apart by the glyph each wears, the one a player reads it by:
--   quest       the quest mark: a quest's need ("Riverpaw Gnoll Bounty (3 / 8 needed)"), the quest
--               count, the finished quests ('Quest complete: "..."', "1 quest (completed)"), "Use it:
--               starts a quest", the quests the player cannot take ("5 quests from level 50", "1
--               Paladin quest", "1 repeatable quest")
--   profession  a profession's glyph, the recipe scroll, the chain rings or the crate: "12 x
--               Tailoring", "Level Cooking (12 / 40 needed)", the recipes no profession names, the
--               chains, "Waylaid Supplies (0 / 20 needed)", the tool and recipe item lines
--   gear        the gear chest: the gear suggestions, "Equipped", "Not for your class", and the muted
--               "Better gear available" under Equipped, which wears none
-- Every other line (the tag row, the level bracket, "Sold by vendors everywhere", the class spell
-- lines, the bag lines) is no kind's. Display only: the Keep verdict, ItemTreeAPI and the item page
-- read none of it. The owner's ruling of 2026-10-23: the Keep and sell tags (the tag row and its
-- counts) are never changed or hidden by a kind, only the lines under them; the row has a switch of its
-- own (Tooltip.TAGS_KEY). A hidden line goes before the fold counts the uses, so "and N other uses,
-- hold Ctrl" counts only lines it would show, and holding the modifier never brings a hidden line
-- back. The kinds the older rows turned off keep their keys and their saved values (Show badge lines,
-- Show uses line, Show the key binding hint): Tooltip.DISPLAY_KEYS lists them all, for the self test,
-- which builds with every one on.
Tooltip.CATEGORY_KEYS = {
  quest = "tooltipShowQuests",
  profession = "tooltipShowProfessions",
  gear = "tooltipShowGear",
}
-- Brief TD1 (the owner's naming note of 2026-10-23: "Keep" is both the whole row and one of its tags):
-- the Keep and sell tags switch, the tag row as a whole ([Keep], [Use], [Vendor], [Worthless] and the
-- rest, with their counts) in the tooltip alone. The bag marks keep their own switch (Keep marks), and
-- the lines under the row stay, each with its own kind's switch.
Tooltip.TAGS_KEY = "tooltipShowTags"
Tooltip.DISPLAY_KEYS = {
  "tooltipEnabled",
  "tooltipShowTags",
  "tooltipShowBadges",
  "tooltipShowUses",
  "tooltipShowQuests",
  "tooltipShowProfessions",
  "tooltipShowGear",
  "tooltipShowHint",
}

-- The glyphs a profession line wears: Keep's recipe scroll, chain rings, crate and the glyph a skill
-- with none of its own falls back to, and every profession's own (UI/Assets.lua skillGlyphs). Read
-- through the namespace, so a spec can take either module away. Pure.
local function professionArt()
  local set = {}
  local keep = ItemTree.Keep
  if type(keep) == "table" then
    local kinds = type(keep.KIND_ICONS) == "table" and keep.KIND_ICONS or {}
    -- A numeric loop, so a key one Keep build lacks never hides the ones after it.
    local keys = { kinds.recipe, keep.CHAIN_ICON, keep.CRATE_ICON, keep.SKILL_ICON_FALLBACK }
    for index = 1, 4 do
      if type(keys[index]) == "string" then
        set[keys[index]] = true
      end
    end
  end
  local assets = ItemTree.Assets
  if type(assets) == "table" and type(assets.skillGlyphs) == "table" then
    for _, key in pairs(assets.skillGlyphs) do
      if type(key) == "string" then
        set[key] = true
      end
    end
  end
  return set
end

--- Brief TD1: a line's kind from the glyph it wears (icon, an Assets key, whether or not icons are
--- drawn), its words with no markup (plain) and whether Keep marked it a profession's recipe line
--- (group): "quest", "profession", "gear", or nil for a line that is no kind's. Pure but for Keep's
--- and Assets' keys.
function Tooltip.LineCategory(icon, plain, group)
  local keep = ItemTree.Keep
  local kinds = type(keep) == "table" and type(keep.KIND_ICONS) == "table" and keep.KIND_ICONS or {}
  if icon ~= nil and icon == (kinds.quest or "CAT_QUEST") then
    return "quest"
  end
  local gearArt = type(keep) == "table" and keep.GEAR_ICON or nil
  if (gearArt ~= nil and icon == gearArt) or (type(plain) == "string" and plain == L["Better gear available"]) then
    return "gear"
  end
  if group then
    return "profession"
  end
  if type(icon) == "string" and professionArt()[icon] then
    return "profession"
  end
  return nil
end

--- Brief TD1: whether a kind's lines are shown under these settings: its switch on (a switch never
--- written reads as on), and always for a line that is no kind's (nil). Pure.
function Tooltip.ShowsCategory(settings, category)
  local key = category ~= nil and Tooltip.CATEGORY_KEYS[category] or nil
  if key == nil then
    return true
  end
  return settingOn(type(settings) == "table" and settings or {}, key)
end

--- Brief TD1: drawn lines less the ones of a kind the settings turn off (line.category). The list
--- handed in where none goes, so a block with every kind on is the very table it was; a fresh list
--- otherwise, possibly empty. nil for nil. Pure.
function Tooltip.WithoutHidden(lines, settings)
  if type(lines) ~= "table" then
    return lines
  end
  local out, dropped = {}, false
  for _, line in ipairs(lines) do
    if type(line) == "table" and not Tooltip.ShowsCategory(settings, line.category) then
      dropped = true
    else
      out[#out + 1] = line
    end
  end
  if not dropped then
    return lines
  end
  return out
end

--- Brief TD1: a Keep block (Tooltip.KeepLines) less the lines of a kind the settings turn off. The tag
--- row is no kind's, so it stays exactly as it was (the owner's ruling; Show Keep and sell tags leaves
--- it out where the section is laid out, Tooltip.TaggedLayout, so nothing else moves). A block left with
--- nothing but its blank spacers (one with no tag row whose every line went: a finished epic quest
--- item's lines with Quest lines off) is nil, so no gap is left where it stood. Pure.
function Tooltip.HideCategories(block, settings)
  local kept = Tooltip.WithoutHidden(block, settings)
  if kept == block or type(kept) ~= "table" then
    return kept
  end
  if Tooltip.HasTagRow(kept) or Tooltip.HasReasonLine(kept) then
    return kept
  end
  return nil
end

--- Brief TD1: the summary the uses line words (Tooltip.UsesText) less the counts of a kind the settings
--- turn off: with Quest lines off the quests ("Used in 6 recipes, 1 quest" reads "Used in 6 recipes",
--- and "No known uses for Alliance", which only the other side's quests make, goes); with Profession
--- lines off the recipes it is used in, teaches and is a tool for, and the recipes that make it.
--- total goes down by what went (Graph.Summary's total is the sum of the uses). The class spell counts
--- are no kind's. A fresh table where anything went; the summary itself otherwise. Pure.
function Tooltip.ShownSummary(summary, settings)
  if type(summary) ~= "table" then
    return summary
  end
  local quests = not Tooltip.ShowsCategory(settings, "quest")
  local professions = not Tooltip.ShowsCategory(settings, "profession")
  if not quests and not professions then
    return summary
  end
  local copy = {}
  for key, value in pairs(summary) do
    copy[key] = value
  end
  local total = tonumber(summary.total) or 0
  if quests then
    total = total - (tonumber(summary.quests) or 0)
    copy.quests = 0
    copy.questsOthers = nil
    copy.questArt = nil
    copy.noUsesSide = nil
  end
  if professions then
    total = total
      - (tonumber(summary.usedIn) or 0)
      - (tonumber(summary.teaches) or 0)
      - (tonumber(summary.toolFor) or 0)
    copy.usedIn = 0
    copy.teaches = 0
    copy.toolFor = 0
    copy.producedBy = 0
    copy.usedInSkills = nil
    copy.producedBySkills = nil
  end
  copy.total = math.max(0, total)
  return copy
end

--- Brief TD1: a section with no blank line at its top or its end, so hiding lines never leaves a gap
--- where they stood (the first line carries the "ItemTree" label, which a blank line must never wear).
--- An empty list where nothing but blank lines is left, so the tooltip draws no section at all. The
--- list handed in where nothing goes. Pure.
function Tooltip.Settled(lines)
  if type(lines) ~= "table" then
    return lines
  end
  local first, last = 1, #lines
  while first <= last and type(lines[first]) == "table" and (lines[first].spacer or lines[first].gap) do
    first = first + 1
  end
  while last >= first and type(lines[last]) == "table" and (lines[last].spacer or lines[last].gap) do
    last = last - 1
  end
  if first == 1 and last == #lines then
    return lines
  end
  local out = {}
  for index = first, last do
    out[#out + 1] = lines[index]
  end
  return out
end

--- Brief TD1: the display switches as one string, for the block cache's fingerprint. Pure.
function Tooltip.DisplaySignature(settings)
  settings = type(settings) == "table" and settings or {}
  local parts = {}
  for _, key in ipairs(Tooltip.DISPLAY_KEYS) do
    parts[#parts + 1] = settingOn(settings, key) and "1" or "0"
  end
  return table.concat(parts)
end

--- Brief TD1: a copy of settings with every display switch on (Tooltip.DISPLAY_KEYS), the rest as they
--- are: what the developer only self test builds its tooltip lines with, so a case that looks for a
--- quest line finds it whatever the player turned off. Pure.
function Tooltip.WithDisplayDefaults(settings)
  local copy = {}
  for key, value in pairs(type(settings) == "table" and settings or {}) do
    copy[key] = value
  end
  for _, key in ipairs(Tooltip.DISPLAY_KEYS) do
    copy[key] = true
  end
  return copy
end

-- Brief AT4: the words of a gap line (Keep.GAP_TEXT), which Tooltip.ShrinkGaps checks a line still
-- holds before it shrinks it. Pure.
function Tooltip.GapText()
  local keep = ItemTree.Keep
  return type(keep) == "table" and type(keep.GAP_TEXT) == "string" and keep.GAP_TEXT or " "
end

-- Brief K24d: the section's one gap, a blank line of the tooltip's own text height built from
-- Core/Keep.lua's one constant (Keep.GAP_TEXT, the spacer the item page draws too), so every gap
-- is the same height. A fresh line each time. Pure.
function Tooltip.Gap(scale)
  local line = { text = Tooltip.GapText(), label = "", colorKey = COLOR_BODY, spacer = true, gap = true }
  -- Brief K24i: a gap drawn shorter than a line, its blank line's font scaled after the tooltip
  -- shows (Tooltip.ShrinkGaps).
  if type(scale) == "number" and scale > 0 and scale < 1 then
    line.scale = scale
  end
  return line
end

-- Brief K24i (owner 2026-10-07): the gaps above and below the status line are this much of a
-- line's height.
Tooltip.STATUS_GAP_SCALE = 0.75

-- Brief K24i: the blank lines of a section that draw shorter than a line, by their line number on
-- the tooltip: { [lineNumber] = scale }. before is the tooltip's line count before our own blank
-- line went on (lineTotal), so our first line is before + 2. Pure.
function Tooltip.GapScales(lines, before)
  local out = {}
  if type(before) ~= "number" then
    return out
  end
  for offset, line in ipairs(type(lines) == "table" and lines or {}) do
    if type(line) == "table" and line.gap and type(line.scale) == "number" then
      out[before + 1 + offset] = line.scale
    end
  end
  return out
end

-- Brief TV1 (QA item 347): whether a Keep block holds a line beside its tag row and gaps. Pure.
function Tooltip.HasReasonLine(block)
  for _, line in ipairs(type(block) == "table" and block or {}) do
    if type(line) == "table" and not line.spacer and not line.tags and not line.head then
      return true
    end
  end
  return false
end

-- Brief K24d: whether a Keep block has its tag row. Pure.
function Tooltip.HasTagRow(block)
  for _, line in ipairs(type(block) == "table" and block or {}) do
    if type(line) == "table" and line.tags then
      return true
    end
  end
  return false
end

-- Brief K24i (owner 2026-10-07, the tags always up the top left under the border): the section of
-- an item with tags, in this order:
--   1. the tag row, always first (so it carries "ItemTree" at its right, Tooltip.OnItem)
--   2. where there is a status line: a short gap (STATUS_GAP_SCALE of a line), the status line
--      (New in Forever or Changed in Forever) and under it the classic diff's change lines where
--      they are on (they are its detail), then a short gap where anything follows
--   3. where there is none: one full gap where anything follows
--   4. the reasons under the tags (Core/Keep.lua TagReasons, one tooltip line each, Tooltip.KeepLines)
--   5. the summary lines (the uses line "Made by 1 recipe", the set twin line), in today's order
--   6. the hint line
-- Brief K24d (owner QA 2026-10-06) had the status line above the tags with a full gap between.
-- parts = { status, changes = { lines }, keep = Tooltip.KeepLines' block, summary = { lines },
-- hint, tags }. The block's own spacers are dropped: Tooltip.Gap is the only blank line. A summary line
-- whose words are already in the section is left out (as BuildLines' append does). Brief TD1: tags
-- false (Show Keep and sell tags off) leaves the tag row out and keeps the order of everything else:
-- the status line and its change lines first where there is one, a short gap where anything follows,
-- then the reasons, the summary lines and the hint, with no gap at the top. Pure.
function Tooltip.TaggedLayout(parts)
  parts = type(parts) == "table" and parts or {}
  local lines = {}
  local tagRow, after = nil, {}
  for _, line in ipairs(type(parts.keep) == "table" and parts.keep or {}) do
    if type(line) == "table" and not line.spacer then
      if line.tags and tagRow == nil then
        tagRow = line
      else
        after[#after + 1] = line
      end
    end
  end
  if tagRow == nil then
    if type(parts.status) == "table" then
      lines[#lines + 1] = parts.status
      for _, line in ipairs(type(parts.changes) == "table" and parts.changes or {}) do
        lines[#lines + 1] = line
      end
    end
    return lines
  end
  local gapAfter = Tooltip.Gap()
  if parts.tags == false then
    -- Brief TD1: no tag row, so no gap before what follows unless the status line stands above it.
    gapAfter = nil
  else
    lines[#lines + 1] = tagRow
  end
  if type(parts.status) == "table" then
    if #lines > 0 then
      lines[#lines + 1] = Tooltip.Gap(Tooltip.STATUS_GAP_SCALE)
    end
    lines[#lines + 1] = parts.status
    for _, line in ipairs(type(parts.changes) == "table" and parts.changes or {}) do
      lines[#lines + 1] = line
    end
    gapAfter = Tooltip.Gap(Tooltip.STATUS_GAP_SCALE)
  end
  local seen = {}
  for _, line in ipairs(lines) do
    if type(line.label) == "string" and line.label ~= "" then
      seen[line.label] = true
    end
  end
  for _, line in ipairs(after) do
    if type(line.label) == "string" and line.label ~= "" then
      seen[line.label] = true
    end
  end
  for _, line in ipairs(type(parts.summary) == "table" and parts.summary or {}) do
    if type(line) == "table" and not (type(line.label) == "string" and seen[line.label]) then
      after[#after + 1] = line
      if type(line.label) == "string" then
        seen[line.label] = true
      end
    end
  end
  if type(parts.hint) == "table" then
    after[#after + 1] = parts.hint
  end
  if #after > 0 then
    if gapAfter then
      lines[#lines + 1] = gapAfter
    end
    for _, line in ipairs(after) do
      lines[#lines + 1] = line
    end
  end
  return lines
end

-- Brief K24b: a Keep block's spacers trimmed: none at its top where it is the first thing in the
-- section (the tooltip's own blank line already stands there), and none at its end. Answers the
-- list it was handed, or a new one. Pure. Brief K24d: BuildLines places a block with its tag row
-- through Tooltip.TaggedLayout; this stays for a block with none.
function Tooltip.TrimKeepSpacers(block, atTop)
  if type(block) ~= "table" then
    return block
  end
  local first, last = 1, #block
  if atTop then
    while first <= last and block[first].spacer do
      first = first + 1
    end
  end
  while last >= first and block[last].spacer do
    last = last - 1
  end
  if first == 1 and last == #block then
    return block
  end
  local out = {}
  for index = first, last do
    out[#out + 1] = block[index]
  end
  return out
end

-- BuildLines memoised per item id, and the reason is measured rather than guessed: GameTooltip
-- on the Forever beta reports supportsDataRefresh with an updateTooltipTimer of 0.2, so it
-- clears and rebuilds a tooltip that is still on screen about five times a second and runs the
-- post call again each time. Without this, one hover re-queries Data, Diff and Graph five times
-- a second for an answer that cannot have changed.
--
-- The item id is the whole key. Settings are not part of it because nothing changes a setting
-- without Options.OnChanged calling Tooltip.ResetRendered, which empties the cache. A
-- fingerprint is compared on every read instead, and it carries two things the cache cannot
-- see coming. The data build and its status, because a data module that finishes building changes what
-- the block says with nothing else to announce it. And the icons, because the cached lines now
-- carry their markup in their text: art that resolves differently, or the icon setting going
-- off, has to throw the old block away. Both are string compares. Past Tooltip.CACHE_MAX
-- entries the lot is thrown away rather than aged one at a time: this is a hover cache, not a
-- store.
Tooltip.CACHE_MAX = 200

local cache = {}
local cacheCount = 0
local cacheFingerprint = false
-- Brief PR9: the route count each cached block was built with (Tooltip.KeepCount).
local cacheHave = {}

function Tooltip.ClearCache()
  cache = {}
  cacheCount = 0
  cacheHave = {}
end

-- Which data build is installed and how it matches the client, as one string. The block no
-- longer says it (brief W32), but what the block says still depends on the data, so a data
-- module that finishes loading throws the cached blocks away. Reads Core's state only.
local function dataSignature()
  local state = type(ItemTree.state) == "table" and ItemTree.state or {}
  return tostring(state.dataBuild) .. " " .. tostring(state.dataStatus)
end

-- The markup the block would draw, as one string. Three keys cover every status line, because
-- Removed reuses the Changed medallion, and "icons off" stands for the lot when the setting is
-- off. Cheap: three string.formats on a cache read, which happens about five times a second
-- while a tooltip is on screen. Pure.
function Tooltip.IconSignature(settings)
  settings = settings or (ItemTree.db and ItemTree.db.settings) or {}
  if not settingOn(settings, "tooltipShowIcons") then
    return "icons off"
  end
  return table.concat({
    Tooltip.Icon(Tooltip.BadgeArt("new")),
    Tooltip.Icon(Tooltip.BadgeArt("sod")),
    Tooltip.Icon(Tooltip.BadgeArt("changed")),
    Tooltip.Icon(NEUTRAL_ART),
  }, "\n")
end

-- The Keep line depends on the setting and on who the player is (brief T4), so a level up or a
-- change of the tick box throws the cached blocks away.
-- Brief TB1: and the bag look's colour settings. Brief K24b: the Keep and Auction tags are drawn in
-- the Keep and Valuable colours, so a colour pick builds the block again.
local function customKey(custom)
  if type(custom) ~= "table" then
    return "-"
  end
  return tostring(custom.r) .. ":" .. tostring(custom.g) .. ":" .. tostring(custom.b)
end

local function keepSignature(settings)
  if not settingOn(settings, "keepMarks") then
    return "keep off"
  end
  local level, faction = Tooltip.PlayerFacts()
  return table.concat({
    "keep",
    tostring(level),
    tostring(faction),
    tostring(settings.keepRamp),
    tostring(settings.keepColor),
    customKey(settings.keepColorCustom),
    tostring(settings.keepValueColor),
    customKey(settings.keepValueColorCustom),
    -- Brief K20c: the Bar decides Vendor against Sell (AH).
    tostring(settings.keepSellBar),
    tostring(settings.keepSellFormula),
  }, " ")
end

-- Brief BQ3 (owner QA item 1: the quest "!" in the item tooltip only came after a /reload): the
-- quest log moves what the block says (a quest taken, dropped or handed in, and the requirement
-- rows the collector writes from the log), and none of it announced itself to the cache. Our own
-- event frame (client side, below) counts the four quest events in Tooltip.questGeneration, and the
-- collector counts its quest requirement writes (Core/Collector.lua Collector.requiresGeneration,
-- read only), so both are in the fingerprint. Two numbers, one concatenation.
Tooltip.questGeneration = 0
Tooltip.QUEST_EVENTS = { "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN" }

local function requiresGeneration()
  local collector = ItemTree.Collector
  if type(collector) ~= "table" then
    return nil
  end
  return rawget(collector, "requiresGeneration")
end

function Tooltip.QuestSignature()
  return tostring(Tooltip.questGeneration) .. ":" .. tostring(requiresGeneration())
end

-- Brief BQ3: the Keep scores hold a quest use worked out before the log moved (Core/Keep.lua keeps
-- them until a quest is turned in, Keep.OnEvent), so a block built again from them would say the
-- same. Dropped through Keep's own public call (Keep.DropScores) when a quest enters or leaves the
-- log, or the collector writes a quest requirement; never on QUEST_LOG_UPDATE, which fires on every
-- objective step. The scores are worked out again for the next item drawn, one item at a time.
local seenRequires = nil

local function dropKeepScores()
  local keep = ItemTree.Keep
  if type(keep) == "table" and type(keep.DropScores) == "function" then
    pcall(keep.DropScores)
    return true
  end
  return false
end

-- What one quest event does: counts it, and drops the Keep scores where the log itself moved.
-- Answers whether the event was one of the four. Pure over Keep.
function Tooltip.OnQuestEvent(event)
  local known = false
  for _, name in ipairs(Tooltip.QUEST_EVENTS) do
    if name == event then
      known = true
    end
  end
  if not known then
    return false
  end
  Tooltip.questGeneration = Tooltip.questGeneration + 1
  if event ~= "QUEST_LOG_UPDATE" then
    dropKeepScores()
  end
  return true
end

-- The collector's quest requirement count, read before each cached read: where it moved since the
-- last read, the Keep scores go too (the block itself goes with the fingerprint). Answers whether
-- it moved.
function Tooltip.NoteRequires()
  local now = requiresGeneration()
  if now == seenRequires then
    return false
  end
  local first = seenRequires == nil
  seenRequires = now
  if not first then
    dropKeepScores()
  end
  return not first
end

-- What a cached block was built under, beyond the item id. The click shortcut is in it because
-- the hint line names it and a player can change it while a tooltip is on screen, which nothing
-- else in the block announces. So is "Include minor changes" (brief C1), which decides whether an
-- item whose only changes are minor carries the Changed line. So is the Show classic diff tick
-- box (brief E88), which is window state that no settings change announces; nil reads it.
function Tooltip.CacheFingerprint(settings, skipClick, showChanges)
  settings = settings or (ItemTree.db and ItemTree.db.settings) or {}
  if showChanges == nil then
    showChanges = Tooltip.ShowChanges()
  end
  return dataSignature()
    .. "\n"
    .. tostring(showChanges and true or false)
    .. "\n"
    .. tostring(settings.includeMinorChanges == true)
    .. "\n"
    -- Brief SET2: Merge recipes decides the set twin line.
    .. tostring(settings.mergeCrafts ~= false)
    .. "\n"
    .. tostring(clickOpenText())
    .. "\n"
    .. tostring(skipClick or false)
    .. "\n"
    .. keepSignature(settings)
    .. "\n"
    .. Tooltip.IconSignature(settings)
    .. "\n"
    .. Tooltip.QuestSignature()
    .. "\n"
    -- Brief BQ7: Hide irrelevant uses and its modifier.
    .. tostring(settings.tooltipHideOtherUses ~= false)
    .. ":"
    .. Tooltip.UsesModifier(settings)
    -- Brief HF1 (QA item 181): "Hide other faction data" moves the quest count and the other side's
    -- quest line, so a block built under the other value is never handed back, whoever changed it
    -- (Options.OnChanged empties the cache too; the developer self test's case faction switch does
    -- not. Brief INT14: named so, as the package check refuses its file name in a shipped file).
    .. "\n"
    .. tostring(Tooltip.HiddenFaction(settings))
    -- Brief TD1: the Tooltip display switches, so a block built with a kind of line on is never handed
    -- back once it is off, whoever turned it off.
    .. "\n"
    .. Tooltip.DisplaySignature(settings)
end

-- What BuildLines would return for this item, from the cache where it can be. The cached table
-- itself is handed back, which every caller only reads. Pure.
function Tooltip.CachedLines(itemId, settings, skipClick)
  if not itemId then
    return Tooltip.BuildLines(itemId, settings, skipClick)
  end
  -- Read once, so the fingerprint and the block it keys are built under the same answer.
  local showChanges = Tooltip.ShowChanges()
  -- Brief BQ3: a quest requirement the collector wrote since the last read drops the Keep scores
  -- before the block is built again under the new fingerprint.
  Tooltip.NoteRequires()
  -- skipClick is part of the fingerprint rather than part of the key: the same item hovered on
  -- a loot row and in a bag says two different hint lines, and one block per item is the whole
  -- point of the cache. Alternating between the two costs a rebuild of that one item.
  local fingerprint = Tooltip.CacheFingerprint(settings, skipClick, showChanges)
  if fingerprint ~= cacheFingerprint then
    cacheFingerprint = fingerprint
    Tooltip.ClearCache()
  end
  -- Brief PR9: a block whose route count has moved since it was built is built again. Brief K24b:
  -- and one built for another bag slot's bound state (the same item soulbound in one slot).
  local have = Tooltip.KeepCount(itemId, settings)
  local bound = nil
  if Tooltip.keepBoundItem == itemId then
    bound = Tooltip.keepBound
  end
  -- Brief K24d: and one built for a worn copy ([Keep] Equipped, brief K24e) or a bag copy. Brief F160:
  -- and one built for a bag in a bag slot or a bank bag slot ("Equipped bag", "Equipped bank bag").
  local worn = Tooltip.keepWornItem == itemId and Tooltip.keepWorn == true
  local wornStamp = tostring(worn)
  if worn and Tooltip.keepWornBag ~= nil then
    wornStamp = tostring(Tooltip.keepWornBag)
  end
  -- Brief K24h: and one built beside another bag item (the comparison tooltip's "Better gear available").
  local against = nil
  if worn and Tooltip.keepAgainstItem == itemId then
    against = Tooltip.keepAgainst
  end
  -- Brief K26: and one built for the pet food read (the stack kept, or not).
  local pet = Tooltip.keepPetItem == itemId and Tooltip.keepPet or nil
  local petStamp = type(pet) == "table" and tostring(pet.keep) or "-"
  -- Brief K31: and one built for another copy of a profession tool (the kept one, or a spare).
  local tool = Tooltip.keepToolItem == itemId and Tooltip.keepTool or nil
  local toolStamp = type(tool) == "table" and tostring(tool.best) or "-"
  -- Brief K28: and one built for another random suffix roll of the same id (the roll's key, not
  -- the link, so two copies of one roll share the block), or beside another roll of the bag item.
  local _, _, roll, againstRoll = Tooltip.KeepLinks(itemId, against)
  local stamp = tostring(have)
    .. ":"
    .. tostring(bound)
    .. ":"
    .. wornStamp
    .. ":"
    .. tostring(against)
    .. ":"
    .. petStamp
    .. ":"
    .. toolStamp
    .. ":"
    .. tostring(roll)
    .. ":"
    .. tostring(againstRoll)
    -- Brief BQ7: a block built while the uses modifier was held (every use) or not (folded).
    .. ":"
    .. tostring(Tooltip.FoldHeldStamp(settings))
  local lines = cache[itemId]
  if lines and cacheHave[itemId] == stamp then
    return lines
  end
  if not lines then
    if cacheCount >= Tooltip.CACHE_MAX then
      Tooltip.ClearCache()
    end
    cacheCount = cacheCount + 1
  end
  lines = Tooltip.BuildLines(itemId, settings, skipClick, showChanges)
  cache[itemId] = lines
  cacheHave[itemId] = stamp
  return lines
end

-- One chat line describing an OnItem call, for /itemtree trace. Pure, so the wording is
-- unit tested and only the printing is guarded. data is the post call's second argument,
-- which is a table on a client with the tooltip data system and nil on the Classic hook.
-- source names which registration delivered the call, so the trace says whether the typed
-- post call or the AllTypes one reached us, and what type value the client put on the data.
-- Brief CS4: rule is what the divider rule did on a rendered call ("drawn", or the reason it
-- was not: see Tooltip.stats.lastRule), and the line ends ", rule <rule>" where it is given.
function Tooltip.TraceLine(name, data, itemId, lineCount, outcome, source, rule)
  local dataText
  if type(data) == "table" then
    dataText = string.format("data type %s id %s", tostring(data.type), tostring(data.id))
  else
    dataText = "no data"
  end
  local line = string.format(
    "ItemTree trace: %s via %s, %s, id %s, %d lines, %s",
    tostring(name or "?"),
    tostring(source or "item"),
    dataText,
    tostring(itemId or "none"),
    tonumber(lineCount) or 0,
    tostring(outcome or "none")
  )
  if type(rule) == "string" and rule ~= "" then
    line = line .. ", rule " .. rule
  end
  return line
end

-- Brief BQ3 (owner QA item 18: "Press ... for the full tree" must be the tooltip's last line): lines
-- added to a block in OnItem's own pass (the demo line, an owner's lines) go in above the hint
-- where the block ends with it, and after the block where it does not. Answers a new list; the
-- cached block is never written to. Pure.
function Tooltip.BeforeHint(lines, extra)
  local out = {}
  for index = 1, #(type(lines) == "table" and lines or {}) do
    out[index] = lines[index]
  end
  local hint = nil
  if #out > 0 and type(out[#out]) == "table" and out[#out].hint then
    hint = table.remove(out)
  end
  for _, line in ipairs(type(extra) == "table" and extra or {}) do
    out[#out + 1] = line
  end
  if hint then
    out[#out + 1] = hint
  end
  return out
end

-- Brief TT1 (QA item 225, the owner's ruling of 2026-10-18: "they will never be able to ctrl click
-- on that item"): a block with no hint line, for a comparison tooltip, where neither the click nor
-- the key opens the item it shows (both open the hovered item beside it). The lines BuildLines
-- would have drawn without the hint: every hint line goes, and so does a gap the hint leaves at
-- the end (TaggedLayout draws one only where something follows it). Read after the cache rather
-- than built with skipClick "hint", because the game tooltip and its comparison tooltip are filled
-- one after the other five times a second and a fingerprint that flipped between them would empty
-- the block cache on every fill. Answers a new list; the cached block is never written to. Pure.
function Tooltip.WithoutHint(lines)
  local out = {}
  for _, line in ipairs(type(lines) == "table" and lines or {}) do
    if not (type(line) == "table" and line.hint) then
      out[#out + 1] = line
    end
  end
  while #out > 0 and type(out[#out]) == "table" and out[#out].gap do
    table.remove(out)
  end
  return out
end

-- Brief BQ3: the order a tooltip's lines take with the hint moved to the end, as positions: the
-- answer's nth entry is the position whose line goes at n. records is how many lines there are,
-- hintAt where the hint is. nil where there is nothing to move (the hint is last, or either
-- number is not a line). Pure.
function Tooltip.HintOrder(count, hintAt)
  count, hintAt = tonumber(count), tonumber(hintAt)
  if not count or not hintAt or hintAt < 1 or hintAt >= count or hintAt ~= math.floor(hintAt) then
    return nil
  end
  local order = {}
  for index = 1, count do
    if index ~= hintAt then
      order[#order + 1] = index
    end
  end
  order[#order + 1] = hintAt
  return order
end

-- Brief CS4: the divider rule's height, in the tooltip's own units. The hairline token is one
-- unit, and where a unit comes to less than one screen pixel (the owner's scale: about 0.9 of a
-- pixel) a one unit texture can round to no row at all, so the rule is never less than one
-- pixel. unitsPerPixel is Util.ScreenPixel's answer for the tooltip, nil where the client will
-- not say, which leaves the token as it is. hairline defaults to Tooltip.RULE_HEIGHT.
-- Brief BQ3 (owner QA item 22, 2026-10-09: at a pixel scale of 1.2 the shown rule was 1.0000 units,
-- 1.2 screen pixels, so it drew one pixel or two depending on where it landed): the height is a
-- whole number of screen pixels, the token's own count rounded and never less than one, so a one
-- unit token at scale 1.2 is one pixel (1 / 1.2 units) and at 0.75 still one pixel (1 / 0.75). Pure.
function Tooltip.RuleHeight(unitsPerPixel, hairline)
  hairline = tonumber(hairline) or tonumber(Tooltip.RULE_HEIGHT) or 1
  local pixel = tonumber(unitsPerPixel)
  if not pixel or pixel <= 0 then
    return hairline
  end
  local pixels = math.floor(hairline / pixel + 0.5)
  if pixels < 1 then
    pixels = 1
  end
  return pixels * pixel
end

-- Brief CS4: an offset from the tooltip's top rounded to whole screen pixels, so the rule starts
-- on a pixel row rather than between two. The offset as it is where the pixel is not known. Pure.
function Tooltip.SnapOffset(offset, unitsPerPixel)
  offset = tonumber(offset)
  local pixel = tonumber(unitsPerPixel)
  if not offset or not pixel or pixel <= 0 then
    return offset
  end
  return math.floor(offset / pixel + 0.5) * pixel
end

-- Brief TV2 (QA item 347, the tooltip audit's card across-5, the owner on 2026-10-21: "Can we indent
-- spacing for all wrapping lines so they match where their line above thems text starts?", and no word
-- left alone on a wrapped line's last line, "needed" kept: "I think its useful for players to see").
-- The block's own lines that wrap are broken here, at the width the client wraps them at, so every
-- line after the first starts under the first line's words (past its icon) and the last line holds two
-- words or more. The game's own lines are never touched.
--
-- How the client wraps a tooltip line. Each line is one FontString the client lays out itself: the
-- template gives it no width and no anchor (TooltipTextLeftTemplate, Blizzard_SharedXML/
-- SharedTooltipTemplates.xml:3, branch forever, 1.60.1.70245), and AddLine's wrap flag
-- (SharedTooltipTemplates.lua:166 to 171) asks the client to wrap it at the width its own layout picks
-- on Show, from the lines that do not wrap, the minimum width (SetMinimumWidth, :218 to 220) and the
-- padding. That layout is the client's own code, not in the Lua mirror, so the width is not guessed
-- here: it is read back off the line once the tooltip has shown (Tooltip.Rewrap). The client starts
-- every wrapped line at the FontString's left edge, under the icon, and the audit's crops show it
-- breaking at the last space that fits, which left "needed)", "20" and "empty)" alone. The two client
-- options do not give a hanging indent: SetIndentedWordWrap indents by a fixed amount, not by an
-- icon's width (SimpleFontStringAPIDocumentation.lua:550), and AddLine's leftOffset moves the whole
-- line.
--
-- So the words are measured in the line's own font (GetUnboundedStringWidthForText, the same
-- documentation, :412 to 426) and broken with explicit new lines, each line after the first led by a
-- clear spacer as wide as the first line's icon and its space (Assets.Spacer). Words that read as one
-- piece stay together: an icon with the word after it (the rarity circles with the word before them),
-- "7 / 220", "12 x Engineering", and a short bracketed qualifier ("(slot empty)", "(20 / 8 needed)",
-- at most Tooltip.WRAP_GROUP_WORDS words, split where it alone is wider than the line). Where the last
-- line would hold one word, the piece before it moves down to join it. Widening the block to fit was
-- the other option and was not taken: the client wraps its own long lines (a Use: line, a description)
-- at the tooltip's width, so a wider block would wrap the game's lines differently too.

-- The most words a bracketed qualifier holds and is still kept on one line.
Tooltip.WRAP_GROUP_WORDS = 5

-- What a lead is measured against and the measure taken off again, so its trailing space counts.
local WRAP_PROBE = "M"

-- Where an escape that draws as one piece ends, for one starting at position at: a texture
-- (|T...|t), an atlas (|A...|a), a colour start (|cAARRGGBB) or a colour end (|r). nil for anything
-- else. Pure.
local function escapeEnd(text, at)
  local two = text:sub(at, at + 1)
  if two == "|T" or two == "|A" then
    local close = text:find(two == "|T" and "|t" or "|a", at + 2, true)
    if close then
      return close + 1
    end
    return nil
  end
  if two == "|c" and text:sub(at + 2, at + 9):match("^%x%x%x%x%x%x%x%x$") then
    return at + 9
  end
  if two == "|r" then
    return at + 1
  end
  return nil
end

-- The characters a player reads: text with every escape taken out. Pure.
local function visibleText(text)
  local out, at = {}, 1
  while at <= #text do
    local stop = escapeEnd(text, at)
    if stop then
      at = stop + 1
    else
      out[#out + 1] = text:sub(at, at)
      at = at + 1
    end
  end
  return table.concat(out)
end

-- Brief TV2: a line's lead and the rest. The lead is everything before the first word (the icon, the
-- space after it, a colour start, the change lines' one space indent); the rest starts at that word.
-- art is true where the lead draws a texture or an atlas. Pure.
function Tooltip.WrapLead(text)
  if type(text) ~= "string" then
    return "", "", false
  end
  local at, art = 1, false
  while at <= #text do
    local stop = escapeEnd(text, at)
    if stop then
      local two = text:sub(at, at + 1)
      if two == "|T" or two == "|A" then
        art = true
      end
      at = stop + 1
    elseif text:sub(at, at) == " " then
      at = at + 1
    else
      break
    end
  end
  return text:sub(1, at - 1), text:sub(at), art
end

-- The rest of a line as words, each { text, sep } with sep the spaces that stood before it, so a line
-- put back together keeps its own spacing. An escape is never split. Pure.
local function wrapWords(rest)
  local out, current, sep, at = {}, {}, "", 1
  while at <= #rest do
    local stop = escapeEnd(rest, at)
    if stop then
      current[#current + 1] = rest:sub(at, stop)
      at = stop + 1
    elseif rest:sub(at, at) == " " then
      if #current > 0 then
        out[#out + 1] = { text = table.concat(current), sep = sep }
        current, sep = {}, ""
      end
      sep = sep .. " "
      at = at + 1
    else
      current[#current + 1] = rest:sub(at, at)
      at = at + 1
    end
  end
  if #current > 0 then
    out[#out + 1] = { text = table.concat(current), sep = sep }
  end
  return out
end

-- The words glued into the pieces a line never breaks inside, each a list of words: an escape alone
-- (an icon) goes with the word after it, or with the word before it at the end (the rarity circles);
-- "/" joins the words either side ("7 / 220"); an "x" after a number joins it to the next word
-- ("12 x Engineering"). Pure.
local function wrapAtoms(words)
  local atoms, glue = {}, false
  for index, word in ipairs(words) do
    local visible = visibleText(word.text)
    local alone = visible == ""
    local join = false
    if #atoms > 0 then
      local atom = atoms[#atoms]
      if alone and index == #words then
        join = true
      elseif visible == "/" then
        join = true
      elseif visible == "x" and visibleText(atom[#atom].text):match("^%d+$") then
        join = true
      end
    end
    if (glue or join) and #atoms > 0 then
      local atom = atoms[#atoms]
      atom[#atom + 1] = word
    else
      atoms[#atoms + 1] = { word }
    end
    glue = (alone and index < #words) or visible == "/" or (visible == "x" and join)
  end
  return atoms
end

-- How many words of a list a player reads (an icon alone is not one). Pure.
local function readWords(words)
  local count = 0
  for _, word in ipairs(words) do
    if visibleText(word.text) ~= "" then
      count = count + 1
    end
  end
  return count
end

-- The words of a line, a unit or an atom, in order, as one flat list of words (a word is the table
-- with text; everything above it is a list). Pure.
local function flatWords(pieces)
  local out = {}
  for _, piece in ipairs(pieces) do
    if piece.text then
      out[#out + 1] = piece
    else
      for _, word in ipairs(flatWords(piece)) do
        out[#out + 1] = word
      end
    end
  end
  return out
end

-- Words put back together, each after the spaces that stood before it, the first after none. Pure.
local function joinWords(words)
  local parts = {}
  for index, word in ipairs(words) do
    parts[#parts + 1] = (index == 1 and "" or word.sep) .. word.text
  end
  return table.concat(parts)
end

-- The atoms grouped into units, each a list of atoms: a bracketed qualifier of at most
-- Tooltip.WRAP_GROUP_WORDS words is one unit, every other atom a unit of its own. Pure.
local function wrapUnits(atoms)
  local units, index = {}, 1
  while index <= #atoms do
    local first = visibleText(joinWords(atoms[index]))
    local close = nil
    if first:sub(1, 1) == "(" and not first:find(")", 1, true) then
      local words = readWords(atoms[index])
      for ahead = index + 1, #atoms do
        words = words + readWords(atoms[ahead])
        local seen = visibleText(joinWords(atoms[ahead]))
        if words > Tooltip.WRAP_GROUP_WORDS or seen:find("(", 1, true) then
          break
        end
        if seen:find(")", 1, true) then
          close = ahead
          break
        end
      end
    end
    local unit = {}
    for at = index, close or index do
      unit[#unit + 1] = atoms[at]
    end
    units[#units + 1] = unit
    index = (close or index) + 1
  end
  return units
end

-- Brief TV2: text broken for a line width wide, as explicit lines: the first as it was, each one after
-- it led by follow, and no last line holding a single word where the line before it can spare a piece.
-- follow is spacerFor(the lead's width), a clear escape that wide, where the lead draws an icon, and the
-- lead's own spaces where it does not. measure(text) answers the width text draws at in the line's
-- font, nil where it cannot say. Answers the new text and how many lines it holds, or nil where the
-- line fits as it is, holds a piece wider than the line, or anything could not be measured, and the
-- client then wraps it as before. Pure.
function Tooltip.WrapText(text, width, measure, spacerFor)
  width = tonumber(width)
  if type(text) ~= "string" or text:find("\n", 1, true) or not width or width <= 0 then
    return nil
  end
  if type(measure) ~= "function" then
    return nil
  end
  local full = measure(text)
  if type(full) ~= "number" or full <= width then
    return nil
  end
  local lead, rest, art = Tooltip.WrapLead(text)
  local follow = visibleText(lead)
  if art then
    local probe, led = measure(WRAP_PROBE), measure(lead .. WRAP_PROBE)
    if type(probe) ~= "number" or type(led) ~= "number" or type(spacerFor) ~= "function" then
      return nil
    end
    local target = led - probe
    follow = spacerFor(target)
    if type(follow) ~= "string" then
      return nil
    end
    -- One correction, in proportion, where the spacer the client draws comes out a pixel or more
    -- off the lead.
    local drawn = measure(follow .. WRAP_PROBE)
    local got = type(drawn) == "number" and drawn - probe or nil
    if got and got > 0 and math.abs(got - target) >= 1 then
      follow = spacerFor(target * target / got)
      if type(follow) ~= "string" then
        return nil
      end
    end
  end
  local units = wrapUnits(wrapAtoms(wrapWords(rest)))
  if #units == 0 then
    return nil
  end
  local lines, current, index = {}, {}, 1
  while index <= #units do
    local unit = units[index]
    local candidate = {}
    for at, held in ipairs(current) do
      candidate[at] = held
    end
    candidate[#candidate + 1] = unit
    local drawn = measure((#lines == 0 and lead or follow) .. joinWords(flatWords(candidate)))
    if type(drawn) ~= "number" then
      return nil
    end
    local alone = nil
    if drawn > width and #unit > 1 then
      alone = measure(follow .. joinWords(flatWords({ unit })))
      if type(alone) ~= "number" then
        return nil
      end
    end
    if drawn <= width then
      current = candidate
      index = index + 1
    elseif alone and alone > width then
      -- A qualifier wider than a whole line: its pieces are laid one by one.
      table.remove(units, index)
      for at = #unit, 1, -1 do
        table.insert(units, index, { unit[at] })
      end
    elseif #current > 0 then
      lines[#lines + 1] = current
      current = {}
    else
      return nil
    end
  end
  lines[#lines + 1] = current
  if #lines < 2 then
    return nil
  end
  -- No word alone on the last line: the piece before it comes down, where its line keeps another
  -- and the two fit.
  local last, above = lines[#lines], lines[#lines - 1]
  if readWords(flatWords(last)) < 2 and #above > 1 then
    local moved = { above[#above] }
    for _, unit in ipairs(last) do
      moved[#moved + 1] = unit
    end
    local drawn = measure(follow .. joinWords(flatWords(moved)))
    if type(drawn) == "number" and drawn <= width then
      table.remove(above)
      lines[#lines] = moved
    end
  end
  local out = {}
  for at, line in ipairs(lines) do
    out[at] = (at == 1 and lead or follow) .. joinWords(flatWords(line))
  end
  return table.concat(out, "\n"), #lines
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- Last item id rendered per tooltip, so a re-render never doubles the block up.
local rendered = setmetatable({}, { __mode = "k" })
local hookedClear = setmetatable({}, { __mode = "k" })

-- The divider rule, and why it is a texture rather than an inline escape.
--
-- The block has always started with a blank line. The rule is a one pixel gold dim hairline
-- drawn across the middle of that blank line, so the divider costs no extra line and the block
-- is exactly as tall as it was.
--
-- An inline escape in a line of its own was the other option and was not taken. A markup
-- escape is square (Assets.Markup says so), so a rule would have to be a stretched escape with
-- its own path and its own vertex colour written into the string, which is a path named in UI
-- code and a form of the escape neither target client is proven to carry. It would also set a
-- floor under the tooltip's width, because the client widens a tooltip to fit its widest line,
-- so a short item would get a wider tooltip than the client meant it to have.
--
-- The texture costs one Texture per tooltip frame, made once, kept in a weak keyed table, so a
-- tooltip frame that goes away takes its texture with it and nothing accumulates. It is
-- anchored to the tooltip's left and right edges for x, and for y at the blank line's middle,
-- measured as an offset down from the tooltip's top (lineMiddle).
--
-- The 0.2 s rebuild does not flicker it. The client clears and refills a tooltip inside one
-- frame, so the rule is hidden by OnTooltipCleared and shown again by the post call before
-- anything is drawn. It is only ever shown when those clear hooks are in place, which is the
-- thing that stops a rule being left behind on a tooltip that has moved on to a spell.
--
-- Brief CS4 (owner 2026-10-09: the rule is there on some tooltips and missing on others; a pixel
-- scan, CS3, found the missing rule hidden, never drawn or no pixel tall, never misplaced). Three
-- causes, three answers:
--   - one unit is less than one screen pixel at the owner's scale, so with pixel snapping the one
--     unit texture could round to no row: the texture is made with snapping off
--     (SetSnapToPixelGrid false, SetTexelSnappingBias 0, where the client has them), its height
--     is never less than one pixel (Tooltip.RuleHeight) and its offset is a whole number of
--     pixels (Tooltip.SnapOffset);
--   - the post call can come before the client has placed the tooltip (no top to measure), and a
--     tooltip that is never rebuilt (a Jettison list row's hover has no UpdateTooltip) never got
--     a second try: the spacer's line is kept per tooltip and the rule drawn again when the
--     tooltip's size changes (one OnSizeChanged hook, taken with the clear hooks) and once on the
--     next frame, only while the tooltip still shows the block it was measured for;
--   - lines that wrap again after the measure (another addon's late line and its Show) moved the
--     spacer under a fixed offset: the same redraw measures it again.
-- drawRule answers true or why not ("no line", "no geometry", "no texture"), and the last answer
-- is Tooltip.stats.lastRule ("drawn", or "no hooks" where the clear hooks were refused), which
-- /itemtree debug and the trace print.
local rules = setmetatable({}, { __mode = "k" })

-- Brief CS4: the spacer each rendered tooltip's rule is drawn across, { index = line number,
-- itemId = the item it was rendered for }, made once per tooltip and refilled; forgotten by the
-- clear and hide hooks and by ResetRendered, which is what stops a redraw bringing back a rule
-- they took off.
local spacers = setmetatable({}, { __mode = "k" })

-- Brief CS4: the tooltips waiting for the next frame's redraw, and whether that call is booked.
-- ResetRendered empties both along with everything else it forgets.
local redrawQueue = setmetatable({}, { __mode = "k" })
local redrawBooked = false

-- Brief BQ3 (owner QA item 22: the divider flickered on the Equipped comparison tooltip). The client
-- rebuilds a comparison tooltip about five times a second while it is up (GameTooltip_OnUpdate's
-- RefreshData, Blizzard_GameTooltip/Mainline/GameTooltip.lua:460 to 474, runs the item's fill
-- again, and FinalizeItemTooltip asks for the comparison each time, TooltipDataRules.lua:167 to
-- 173). Each rebuild clears the comparison tooltip and takes its points away before refilling it
-- (TooltipComparisonManager:Initialize, TooltipComparisonManager.lua:23 to 30), so the post call
-- found no geometry, the rule waited for the next frame, and that one frame without it was the
-- flicker. Now a clear leaves a drawn rule up, marked stale with the spacer it was drawn for: the
-- post call that puts the same block back keeps it (it is anchored to the tooltip, so it moves with
-- it), anything else takes it off, and the next frame takes off a stale rule nothing claimed. A
-- hide still takes it off at once, and a client with no next frame call hides it on the clear as
-- before. shownRules is which rules are up.
local staleRules = setmetatable({}, { __mode = "k" })
local shownRules = setmetatable({}, { __mode = "k" })

-- Brief BQ3 (owner QA item 18): where each rendered tooltip's hint line is, { index, text, itemId },
-- for the post show pass that keeps it the tooltip's last line (keepHintLast). Forgotten with the
-- block by the clear and hide hooks and by ResetRendered.
local hints = setmetatable({}, { __mode = "k" })
-- A tooltip whose hint is being moved, so the Show that follows does not start the pass again.
local movingHint = setmetatable({}, { __mode = "k" })

Tooltip.RULE_ART = "FILL_WHITE8X8"
Tooltip.RULE_COLOR = "ITEMTREE_COLOR_BORDER_GOLD_DIM"

Tooltip.RULE_HEIGHT = themeSize("ITEMTREE_BORDER_HAIRLINE", 1)
Tooltip.RULE_INSET = themeSize("ITEMTREE_PAD_TIGHT", 8)

-- What the client asked for this session. In memory only: never a saved variable, and gone
-- on a reload like everything else here. Read by /itemtree debug and by /itemtree trace.
-- Brief CS4: lastRule is what the divider rule last did (see above), and scanning counts the
-- calls for another addon's scanning tooltip, which leave before anything else is touched
-- (Tooltip.IsScanning), so they are neither calls nor the last call.
Tooltip.stats = {
  calls = 0,
  rendered = 0,
  lastItemId = nil,
  lastOutcome = nil,
  lastTooltip = nil,
  lastSource = nil,
  lastRule = nil,
  scanning = 0,
  -- Brief TT2: the modifier changes the event and the poll each saw (Tooltip.UnfoldDebugLine).
  modifierEvents = 0,
  modifierPolls = 0,
  -- Brief TV2: what the block's own wrapping last did, and the lines broken and put back this
  -- session (Tooltip.Rewrap, Tooltip.WrapDebugLine).
  lastWrap = nil,
  wrapped = 0,
  wrapPutBack = 0,
}

-- The last few trace lines, oldest overwritten, for /itemtree report. Filled on every OnItem
-- call whether or not the trace is on, so the report can show what happened before the trace was
-- switched on. In memory only, like the counters: nothing here is written to saved variables.
--
-- Brief OPT3 (F14): each slot of the ring holds the raw fields of one call in a table of its own,
-- made once and written over when the ring wraps, and the line is only formatted (TraceLine) when
-- it is read (Tooltip.RecentLines) or printed with the trace on. A call that leaves at once (the
-- block already drawn, about five a second on an open tooltip) so allocates nothing. The data
-- table is not held, only its type and id, which are all the line says about it.
Tooltip.RECENT_MAX = 40
Tooltip.recent = {}
local recentNext = 1

local function remember(name, data, itemId, lineCount, outcome, source, rule)
  local recent = Tooltip.recent
  local entry = recent[recentNext]
  if type(entry) ~= "table" then
    entry = {}
    recent[recentNext] = entry
  end
  entry.name, entry.itemId, entry.lineCount = name, itemId, lineCount
  entry.outcome, entry.source, entry.rule = outcome, source, rule
  if type(data) == "table" then
    entry.hasData, entry.dataType, entry.dataId = true, data.type, data.id
  else
    entry.hasData, entry.dataType, entry.dataId = false, nil, nil
  end
  recentNext = recentNext % Tooltip.RECENT_MAX + 1
end

-- One remembered entry as the trace line it stands for, byte for byte what TraceLine made from the
-- call itself.
local function entryLine(entry)
  if type(entry) ~= "table" then
    return entry
  end
  local data = nil
  if entry.hasData then
    data = { type = entry.dataType, id = entry.dataId }
  end
  return Tooltip.TraceLine(entry.name, data, entry.itemId, entry.lineCount, entry.outcome, entry.source, entry.rule)
end

-- The remembered lines, oldest first. recentNext is the slot the next line goes in, which is
-- also the oldest line once the ring has wrapped, and is one past the end before it has, so one
-- walk reads both cases. No client API, so the report window and the specs read it directly.
function Tooltip.RecentLines()
  local recent = Tooltip.recent or {}
  local count = #recent
  local lines = {}
  for offset = 0, count - 1 do
    lines[#lines + 1] = entryLine(recent[(recentNext - 1 + offset) % count + 1])
  end
  return lines
end

-- The rule's texture for one tooltip, made the first time that tooltip is drawn into and kept
-- after that. false is remembered for a frame that will not make one, so a client with no
-- CreateTexture is asked once and never again. nil means no rule, which is the blank line on
-- its own: what the block looked like before there was a rule at all.
local function ruleFor(tooltip)
  local rule = rules[tooltip]
  if rule ~= nil then
    if rule == false then
      return nil
    end
    return rule
  end
  local texture
  if type(tooltip.CreateTexture) == "function" then
    local ok, made = pcall(tooltip.CreateTexture, tooltip, nil, "OVERLAY")
    if ok and made and type(made.SetPoint) == "function" then
      texture = made
    end
  end
  if not texture then
    rules[tooltip] = false
    return nil
  end
  -- Brief CS4: no pixel snapping, so a rule a little under or over one pixel tall is never
  -- rounded away; RuleHeight and SnapOffset keep it on one whole pixel row instead. Each only
  -- where the client has it, and a refusal leaves the client's default.
  if type(texture.SetSnapToPixelGrid) == "function" then
    pcall(texture.SetSnapToPixelGrid, texture, false)
  end
  if type(texture.SetTexelSnappingBias) == "function" then
    pcall(texture.SetTexelSnappingBias, texture, 0)
  end
  local assets = ItemTree.Assets
  if type(assets) == "table" and type(assets.Apply) == "function" then
    pcall(assets.Apply, texture, Tooltip.RULE_ART)
  end
  local color = Theme and type(Theme.ColorTable) == "function" and Theme.ColorTable(Tooltip.RULE_COLOR) or nil
  if color and type(texture.SetVertexColor) == "function" then
    pcall(texture.SetVertexColor, texture, color.r, color.g, color.b, color.a or 1)
  end
  if type(texture.Hide) == "function" then
    pcall(texture.Hide, texture)
  end
  rules[tooltip] = texture
  return texture
end

-- Takes the rule off a tooltip. Called from the cleared and hidden hooks and from
-- ResetRendered, so a rule is never left over a tooltip that has moved on.
local function hideRule(tooltip)
  staleRules[tooltip] = nil
  shownRules[tooltip] = nil
  local rule = rules[tooltip]
  if rule and type(rule.Hide) == "function" then
    pcall(rule.Hide, rule)
  end
end

-- Brief Q9a: the strike through a change line's old value. The frame API has no strike, so it is
-- a hairline texture laid over the old value's extent, the way the info column draws one. The
-- textures sit on ItemTree's own frame parented to the tooltip (nothing is written onto the
-- tooltip), pooled per tooltip in a weak keyed table, and hidden with the rule by the cleared and
-- hidden hooks. The extent is measured on a hidden FontString of that frame set to the line's own
-- font: the words before the old value give its left edge and the old value its width.
local strikes = setmetatable({}, { __mode = "k" })
-- Defined with the rule's geometry below.
local lineFontString

Tooltip.STRIKE_ART = "FILL_WHITE8X8"
Tooltip.STRIKE_COLOR = "ITEMTREE_COLOR_TEXT_MUTED"

-- Brief TX6: true while the client is in combat lockdown. A client (or the test harness) with no
-- InCombatLockdown, or one that raises, answers not in combat.
local function inCombat()
  local lockdown = rawget(_G, "InCombatLockdown")
  if type(lockdown) ~= "function" then
    return false
  end
  local ok, locked = pcall(lockdown)
  return (ok and locked) and true or false
end

-- Brief TX6: the strike holder is the one frame of ours this file moves under a client frame (the
-- tooltip), and a frame is not moved under a client frame in combat. A tooltip that wants one in
-- combat draws its block without the strikes, and one redraw is booked for PLAYER_REGEN_ENABLED:
-- the rendered blocks are forgotten, so the next draw of each tooltip makes its holder and strikes
-- its old values. Booked once however many tooltips asked; the flag clears when it runs.
Tooltip.afterCombatBooked = false

function Tooltip.OnCombatEnd()
  if not Tooltip.afterCombatBooked then
    return false
  end
  Tooltip.afterCombatBooked = false
  Tooltip.ResetRendered()
  return true
end

local function bookAfterCombat()
  if Tooltip.afterCombatBooked then
    return false
  end
  Tooltip.afterCombatBooked = true
  if not Tooltip.combatFrame then
    local create = rawget(_G, "CreateFrame")
    local ok, frame = false, nil
    if type(create) == "function" then
      ok, frame = pcall(create, "Frame")
    end
    if ok and type(frame) == "table" then
      Tooltip.combatFrame = frame
      if type(frame.RegisterEvent) == "function" then
        pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED")
      end
      if type(frame.SetScript) == "function" then
        pcall(frame.SetScript, frame, "OnEvent", function()
          Tooltip.OnCombatEnd()
        end)
      end
    end
  end
  return true
end

-- The strike holder for one tooltip: { frame, measure, pool, used }, made once. false is
-- remembered for a tooltip that will not take one, so it is asked once. In combat none is made
-- (brief TX6) and nothing is remembered.
local function strikeHolder(tooltip)
  local held = strikes[tooltip]
  if held ~= nil then
    return held or nil
  end
  if inCombat() then
    bookAfterCombat()
    return nil
  end
  -- Brief TX2: made with no parent and moved under the tooltip once built. On Forever the gamepad
  -- SmartNavigation post hooks CreateFrame and, for a frame whose parent chain reaches an open
  -- panel, rebuilds that panel's navigation state as the caller (SmartNavigation.lua
  -- SetupFrameHooks, branch forever); SetParent is not hooked. The strike textures made later
  -- are textures, which that hook never sees.
  local create = rawget(_G, "CreateFrame")
  local frame
  if type(create) == "function" then
    local ok, made = pcall(create, "Frame")
    if ok and type(made) == "table" and type(made.CreateTexture) == "function" then
      frame = made
    end
  end
  if not frame or type(frame.SetParent) ~= "function" then
    strikes[tooltip] = false
    return nil
  end
  if type(frame.EnableMouse) == "function" then
    pcall(frame.EnableMouse, frame, false)
  end
  local measure
  if type(frame.CreateFontString) == "function" then
    local ok, made = pcall(frame.CreateFontString, frame, nil, "OVERLAY", "GameTooltipText")
    if ok and type(made) == "table" then
      measure = made
      if type(measure.Hide) == "function" then
        pcall(measure.Hide, measure)
      end
    end
  end
  if not pcall(frame.SetParent, frame, tooltip) then
    strikes[tooltip] = false
    return nil
  end
  local function ask(object, name, ...)
    if type(object[name]) ~= "function" then
      return nil
    end
    local ok, value = pcall(object[name], object, ...)
    return ok and value or nil
  end
  -- The tooltip's strata where the move did not hand it on, and one level above it, which is
  -- where a frame made with the tooltip as its parent lands.
  -- Brief UI1: from 1.60.1.70425 GetFrameStrata can answer a secret (the new FrameStrata aspect,
  -- Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:435-437, branch forever), and a
  -- secret raises on the compare, which would leave this holder unremembered and make a new one on
  -- every draw. An unreadable strata is left alone: the holder keeps the one SetParent handed it.
  local strata = ask(tooltip, "GetFrameStrata")
  if type(strata) == "string" and canRead(strata) and ask(frame, "GetFrameStrata") ~= strata then
    ask(frame, "SetFrameStrata", strata)
  end
  local level = tonumber(ask(tooltip, "GetFrameLevel"))
  if level then
    ask(frame, "SetFrameLevel", level + 1)
  end
  ask(frame, "SetAllPoints", tooltip)
  held = { frame = frame, measure = measure, pool = {}, used = 0 }
  strikes[tooltip] = held
  return held
end

-- Hides every strike on a tooltip.
local function hideStrikes(tooltip)
  local held = strikes[tooltip]
  if not held then
    return
  end
  for _, texture in ipairs(held.pool) do
    if type(texture.Hide) == "function" then
      pcall(texture.Hide, texture)
    end
  end
  held.used = 0
end

-- The next free strike texture, made on first need.
local function nextStrike(held)
  held.used = held.used + 1
  local texture = held.pool[held.used]
  if texture then
    return texture
  end
  local ok, made = pcall(held.frame.CreateTexture, held.frame, nil, "OVERLAY")
  if not ok or type(made) ~= "table" or type(made.SetPoint) ~= "function" then
    held.used = held.used - 1
    return nil
  end
  local assets = ItemTree.Assets
  if type(assets) == "table" and type(assets.Apply) == "function" then
    pcall(assets.Apply, made, Tooltip.STRIKE_ART)
  end
  local color = Theme and type(Theme.ColorTable) == "function" and Theme.ColorTable(Tooltip.STRIKE_COLOR) or nil
  if color and type(made.SetVertexColor) == "function" then
    pcall(made.SetVertexColor, made, color.r, color.g, color.b, color.a or 1)
  end
  held.pool[held.used] = made
  return made
end

-- The width of text in the line's own font, or nil. The measuring FontString is only ever given
-- text once SetFont has answered true, so it can never raise "Font not set".
local function measured(measure, font, size, flags, text)
  local ok, set = pcall(measure.SetFont, measure, font, size, flags)
  if not ok or set == false then
    return nil
  end
  if not pcall(measure.SetText, measure, text) then
    return nil
  end
  local got, width = pcall(measure.GetStringWidth, measure)
  if got and type(width) == "number" then
    return width
  end
  return nil
end

-- Lays one strike over the old value on line index. true when drawn.
local function drawStrike(tooltip, index, strike)
  local region = lineFontString(tooltip, index)
  if not region or type(region.GetFont) ~= "function" then
    return false
  end
  local held = strikeHolder(tooltip)
  if not held or not held.measure then
    return false
  end
  local font, size, flags = region:GetFont()
  if not font then
    return false
  end
  local left = measured(held.measure, font, size, flags, strike.prefix)
  local width = measured(held.measure, font, size, flags, strike.old)
  if not left or not width or width <= 0 then
    return false
  end
  local texture = nextStrike(held)
  if not texture then
    return false
  end
  texture:ClearAllPoints()
  texture:SetPoint("LEFT", region, "LEFT", left, 0)
  texture:SetSize(width, Tooltip.RULE_HEIGHT)
  texture:Show()
  return true
end

-- Every strike a block asked for, as { [line index] = strike }. One pcall each: a strike is
-- decoration, and nothing about it may cost the block. Answers how many were drawn.
local function showStrikes(tooltip, wanted)
  hideStrikes(tooltip)
  local drawn = 0
  for index, strike in pairs(wanted) do
    local ok, done = pcall(drawStrike, tooltip, index, strike)
    if ok and done then
      drawn = drawn + 1
    end
  end
  return drawn
end

-- Called with no argument by Options.OnChanged when a setting changes, which is why the block
-- cache is emptied here: the cache is keyed by item id alone, so it has to follow the settings
-- it was built under. Every rule goes with it, because the block it divided is gone. The per
-- tooltip form empties the cache too rather than carry a rule about which form does what;
-- nothing calls it per tooltip in the render path, where the cleared and hidden hooks forget
-- their own frame directly. Brief CS4: the spacers go too, so neither the size hook nor the next
-- frame call can bring a rule back, and the whole form forgets the next frame's queue (a call
-- already booked then finds nothing to do).
function Tooltip.ResetRendered(tooltip)
  if tooltip then
    rendered[tooltip] = nil
    spacers[tooltip] = nil
    hints[tooltip] = nil
    hideRule(tooltip)
    hideStrikes(tooltip)
  else
    rendered = setmetatable({}, { __mode = "k" })
    spacers = setmetatable({}, { __mode = "k" })
    hints = setmetatable({}, { __mode = "k" })
    redrawQueue = setmetatable({}, { __mode = "k" })
    redrawBooked = false
    for frame in pairs(rules) do
      hideRule(frame)
    end
    for frame in pairs(strikes) do
      hideStrikes(frame)
    end
  end
  Tooltip.ClearCache()
end

-- The frame's name for the trace and the debug line. A frame name is not player data.
local function tooltipName(tooltip)
  if tooltip and type(tooltip.GetName) == "function" then
    local ok, name = pcall(tooltip.GetName, tooltip)
    if ok and canRead(name) and type(name) == "string" and name ~= "" then
      return name
    end
  end
  return "?"
end

-- A frame's own name, or nil for one the client does not name or keeps secret (brief SV1,
-- SecretAspect ObjectName).
local function frameName(frame)
  if type(frame) ~= "table" or type(frame.GetName) ~= "function" then
    return nil
  end
  local ok, name = pcall(frame.GetName, frame)
  if ok and canRead(name) and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- How far up the parent chain the owner is described. A tooltip owner is a button a few frames
-- under its container, and the rules only ever match a name a handful of levels up, so the walk
-- is capped rather than left to follow a chain of unknown length on every hover.
local OWNER_PARENT_DEPTH = 6

-- The two frames every other frame is under. They are never the protected answer, the same way
-- UI/Keybind.lua treats them: their names are read, but a protected flag on one of them says
-- nothing about what the tooltip is anchored to.
local OWNER_ROOTS = { WorldFrame = true, UIParent = true }

-- Whether the click half of the hint would be a lie on this tooltip.
--
-- UI/Keybind.lua deliberately does not act on a click over a loot row, an action button or our
-- own rows (Keybind.ShouldSkipFocus), so a tooltip anchored to one of those must not promise a
-- click that never fires. The description is the same shape Keybind.FocusDescription builds
-- from the cursor: the owner's own name, the names above it, and whether the client calls any
-- of them protected.
--
-- Everything is guarded and pcalled. A client that will not name the owner, a tooltip with no
-- GetOwner, or no UI/Keybind.lua at all, all read as "nothing to skip", which leaves the hint
-- exactly as it was.
local function ownerSkipsClick(tooltip)
  local Keybind = ItemTree.Keybind
  if not Keybind or type(Keybind.ShouldSkipFocus) ~= "function" then
    return false
  end
  if type(tooltip) ~= "table" or type(tooltip.GetOwner) ~= "function" then
    return false
  end
  local gotOwner, owner = pcall(tooltip.GetOwner, tooltip)
  if not gotOwner or type(owner) ~= "table" then
    return false
  end
  local description = { name = frameName(owner), parents = {}, protected = false }
  local frame = owner
  for _ = 1, OWNER_PARENT_DEPTH do
    if type(frame) ~= "table" then
      break
    end
    if not OWNER_ROOTS[frameName(frame) or ""] and type(frame.IsProtected) == "function" then
      local asked, protected = pcall(frame.IsProtected, frame)
      -- Brief SV1: a flag the client keeps secret (SecretAspect ObjectSecurity) says nothing.
      if asked and canRead(protected) and protected then
        description.protected = true
      end
    end
    if type(frame.GetParent) ~= "function" then
      break
    end
    local gotParent, parent = pcall(frame.GetParent, frame)
    -- Brief SV1: a parent the client keeps secret (SecretAspect Hierarchy) ends the walk.
    if not gotParent or not canRead(parent) or type(parent) ~= "table" then
      break
    end
    local name = frameName(parent)
    if name then
      description.parents[#description.parents + 1] = name
    end
    frame = parent
  end
  local asked, skip = pcall(Keybind.ShouldSkipFocus, description)
  return asked and skip == true
end

-- True when the frame admits to a script type. A client that has dropped one raises when it is
-- hooked, so nothing is hooked without asking first, and a frame with no HasScript at all is
-- taken at its word.
local hasScript = ItemTree.Util.HasScript

-- Both scripts clear the rendered guard, which is the thing that stops a second block. OnHide
-- covers the tooltip going away. OnTooltipCleared covers the client clearing and rebuilding a
-- tooltip that is still on screen: GameTooltip on the Forever beta reports supportsDataRefresh,
-- and it appends a line of its own to item tooltips, so a rebuild is ordinary there and without
-- this the guard would refuse to put the block back.
--
-- Taken after the lines are on, and each on its own: HookScript is the one client call in the
-- render path that can refuse, and a refusal must not cost us the block.
--
-- Returns true when the guard is wired, which is OnHide taken and OnTooltipCleared taken
-- wherever the frame carries that script. The answer is remembered either way, so a client that
-- refuses is asked once. It is also the divider rule's licence to draw: a rule that cannot be
-- hidden again would sit over whatever the tooltip showed next.
-- Brief K24i: the blank lines drawn shorter than a line. A tooltip line is as tall as its font,
-- so a gap of STATUS_GAP_SCALE of a line is its FontString given a font that much smaller, after
-- the tooltip has shown (the client sizes its lines on Show) and before it is shown again. What
-- each FontString had is kept per tooltip (shrunkFonts) and put back when the tooltip clears or
-- hides, so the next tooltip's lines keep their size. Font safety: SetFont's answer is read, and a
-- false (the font file missing) leaves the line as it was.
--
-- Brief AT4 (owner 2026-10-24, "the tooltip text was weirdly sized": the game's own lines, "Press
-- F6 to submit an issue for this Item" and "You haven't collected this appearance", and our own
-- reason lines drawn small in the marketing shots): the client keeps a FontString's font through
-- every clear and refill, so a shrink that is not put back stays on that line number for every
-- tooltip after it. What each FontString had was kept as a list, read from the FontString as it
-- was at the shrink, and put back in the list's order: a FontString shrunk a second time before a
-- restore kept its small font as a second "original", which the restore put back last, so the line
-- stayed small (and the next shrink made it smaller) until a reload. Now the original is kept once
-- per FontString and never read from one already shrunk, a FontString is shrunk only while it still
-- holds the gap's blank words (Tooltip.GapText) at the shrink, a held one this call does not shrink
-- again is put back first, and the render puts every one back before its lines go on
-- (Tooltip.OnItem), so a shrink never outlives its own gap line.
local shrunkFonts = {}

-- Brief AT4: whether a line's FontString holds the gap's blank words now (Tooltip.GapText, or
-- the same blank as the client may answer it, spaces only). Read through Util.CanRead (bible
-- B10), and a FontString that will not say is not a gap.
local function holdsGap(region)
  if type(region.GetText) ~= "function" then
    return false
  end
  local ok, text = pcall(region.GetText, region)
  if not ok or not canRead(text) or type(text) ~= "string" then
    return false
  end
  return text == Tooltip.GapText() or text:match("^ *$") ~= nil
end

function Tooltip.ShrinkGaps(tooltip, scales)
  if type(tooltip) ~= "table" or type(scales) ~= "table" or next(scales) == nil then
    return 0
  end
  local held = shrunkFonts[tooltip] or {}
  -- Brief AT4: the FontStrings this call shrinks, each still holding the gap's words.
  local wanted = {}
  for index, scale in pairs(scales) do
    local region = lineFontString(tooltip, index)
    if
      region
      and tonumber(scale)
      and type(region.GetFont) == "function"
      and type(region.SetFont) == "function"
      and holdsGap(region)
    then
      wanted[region] = tonumber(scale)
    end
  end
  -- Brief AT4: one held from before that this call does not shrink gets its own font back first.
  for region, kept in pairs(held) do
    if not wanted[region] then
      pcall(region.SetFont, region, kept.font, kept.size, kept.flags)
      held[region] = nil
    end
  end
  local done = 0
  for region, scale in pairs(wanted) do
    local kept = held[region]
    local font, size, flags
    if kept then
      font, size, flags = kept.font, kept.size, kept.flags
    else
      local got
      got, font, size, flags = pcall(region.GetFont, region)
      if not (got and canRead(font) and canRead(size) and canRead(flags)) then
        font = nil
      end
    end
    if type(font) == "string" and font ~= "" and tonumber(size) then
      local ok, set = pcall(region.SetFont, region, font, size * scale, flags)
      if ok and set ~= false then
        held[region] = kept or { font = font, size = size, flags = flags }
        done = done + 1
      end
    end
  end
  shrunkFonts[tooltip] = next(held) ~= nil and held or nil
  return done
end

function Tooltip.RestoreGaps(tooltip)
  local held = shrunkFonts[tooltip]
  if not held then
    return 0
  end
  shrunkFonts[tooltip] = nil
  local done = 0
  for region, kept in pairs(held) do
    local ok, set = pcall(region.SetFont, region, kept.font, kept.size, kept.flags)
    if ok and set ~= false then
      done = done + 1
    end
  end
  return done
end

-- Brief CS4: draws the rule again over the spacer it was measured for. Defined with the rule's
-- geometry below; called by the OnSizeChanged hook and the next frame call.
local redrawRule

-- Brief K25g: books the next frame redraw. Defined beside the redraw queue below; the size hook
-- calls it too.
local bookRedraw

-- Brief BQ3: the post show pass. Defined beside the rule's geometry below.
local keepHintLast

-- Brief CS4: the size hook. A tooltip that is not showing a block of ours (cleared, hidden,
-- reset, or never drawn into) has no spacer, so every other resize of the frame costs one table
-- read. Brief K25g: a resize that comes before the client has placed the tooltip ("no geometry")
-- books the next frame redraw, so the rule still lands once it is placed, even after the post
-- call's own next frame call has gone. Brief BQ3: a resize is also what lines added after the
-- block bring (their Show), so the hint is moved back to the end first.
local function onSizeChanged(self)
  if hints[self] then
    keepHintLast(self)
  end
  if spacers[self] and redrawRule(self) == "no geometry" then
    bookRedraw(self)
  end
end

local function hookClears(tooltip)
  local hooked = hookedClear[tooltip]
  if hooked ~= nil then
    return hooked
  end
  if type(tooltip.HookScript) ~= "function" then
    hookedClear[tooltip] = false
    return false
  end
  local function forget(self)
    rendered[self] = nil
    spacers[self] = nil
    hints[self] = nil
    hideRule(self)
    hideStrikes(self)
    Tooltip.RestoreGaps(self)
    Tooltip.UnwatchModifier(self)
  end
  -- Brief BQ3: a clear leaves a drawn rule up until the refill claims it or the next frame (see
  -- staleRules above); everything else goes as on a hide.
  local function cleared(self)
    local spacer = spacers[self]
    if not (spacer and shownRules[self]) then
      forget(self)
      return
    end
    local index, itemId = spacer.index, spacer.itemId
    rendered[self] = nil
    spacers[self] = nil
    hints[self] = nil
    hideStrikes(self)
    Tooltip.RestoreGaps(self)
    Tooltip.UnwatchModifier(self)
    staleRules[self] = { index = index, itemId = itemId }
    if not bookRedraw(self) then
      hideRule(self)
    end
  end
  hooked = pcall(tooltip.HookScript, tooltip, "OnHide", forget) and true or false
  if hooked and hasScript(tooltip, "OnTooltipCleared") then
    hooked = pcall(tooltip.HookScript, tooltip, "OnTooltipCleared", cleared) and true or false
  end
  -- Brief CS4: the one size hook, beside the clear hooks and only once they took (a rule is only
  -- ever drawn where they did). Its own pcall, and its answer is not the licence: a client that
  -- refuses it still gets the rule from the post call and the next frame.
  if hooked and hasScript(tooltip, "OnSizeChanged") then
    pcall(tooltip.HookScript, tooltip, "OnSizeChanged", onSizeChanged)
  end
  hookedClear[tooltip] = hooked
  return hooked
end

-- The number of lines already on a tooltip, or nil when the client will not say. The rule is
-- drawn over the blank line the block starts with, and that line's number is the only way to
-- find the FontString the client put it in.
local function lineTotal(tooltip)
  if type(tooltip.NumLines) ~= "function" then
    return nil
  end
  local ok, count = pcall(tooltip.NumLines, tooltip)
  if not ok or type(count) ~= "number" then
    return nil
  end
  return count
end

-- The FontString the client made for one line of a named tooltip. The client names them
-- <frame>TextLeft<n>, which is how every tooltip addon since 2005 has found them, and a frame
-- with no name or no such region reads as nothing found, so the rule is skipped rather than
-- guessed at. A frame name is not player data.
function lineFontString(tooltip, index)
  if type(tooltip.GetName) ~= "function" or type(index) ~= "number" then
    return nil
  end
  local ok, name = pcall(tooltip.GetName, tooltip)
  if not ok or type(name) ~= "string" or name == "" then
    return nil
  end
  local region = rawget(_G, name .. "TextLeft" .. index)
  if not region or type(region.GetTop) ~= "function" then
    return nil
  end
  return region
end

-- Where a line's middle sits, as an offset down from the tooltip's own top. Both are read in
-- the same coordinate space, and the answer is relative, so it does not change when the tooltip
-- follows the cursor. nil when the client will not give a geometry yet.
local function lineMiddle(tooltip, region)
  if type(tooltip.GetTop) ~= "function" or type(region.GetBottom) ~= "function" then
    return nil
  end
  local top, bottom, tipTop = region:GetTop(), region:GetBottom(), tooltip:GetTop()
  if type(top) ~= "number" or type(bottom) ~= "number" or type(tipTop) ~= "number" then
    return nil
  end
  return (top + bottom) / 2 - tipTop
end

-- One screen pixel in the tooltip's units (Core/Util.lua, shared with UI/InfoPanel.lua's scroll
-- thumb), or nil where the client will not say.
local screenPixel = ItemTree.Util.ScreenPixel

-- Draws the rule across the blank line at index. Anchored twice along its own top edge, which
-- is the idiom UI/Sources.lua uses for a hairline: the two points give the left and right from
-- the tooltip and agree on the top. Brief CS4: the height is the hairline token or one screen
-- pixel, whichever is more (Tooltip.RuleHeight), and the offset a whole number of pixels
-- (Tooltip.SnapOffset). Answers true, or why it drew nothing: "no line" (no FontString for
-- that line), "no geometry" (the client has not placed the line or the tooltip yet) or "no
-- texture" (the tooltip will not make one).
local function drawRule(tooltip, index)
  local region = lineFontString(tooltip, index)
  if not region then
    return "no line"
  end
  local offset = lineMiddle(tooltip, region)
  if not offset then
    return "no geometry"
  end
  local rule = ruleFor(tooltip)
  if not rule then
    return "no texture"
  end
  local pixel = screenPixel(tooltip)
  offset = Tooltip.SnapOffset(offset, pixel)
  rule:ClearAllPoints()
  rule:SetPoint("TOPLEFT", tooltip, "TOPLEFT", Tooltip.RULE_INSET, offset)
  rule:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", -Tooltip.RULE_INSET, offset)
  rule:SetHeight(Tooltip.RuleHeight(pixel))
  rule:Show()
  shownRules[tooltip] = true
  return true
end

-- One pcall around the lot: the rule is decoration, and nothing about it may cost the block.
-- Answers "drawn" or drawRule's reason ("error" for a raise), and keeps it as stats.lastRule.
local function showRule(tooltip, index)
  local ok, drawn = pcall(drawRule, tooltip, index)
  local outcome
  if not ok then
    outcome = "error"
  elseif drawn == true then
    outcome = "drawn"
  else
    outcome = tostring(drawn)
  end
  Tooltip.stats.lastRule = outcome
  return outcome
end

-- Brief CS4: the rule again over the spacer it was measured for, only while the tooltip still
-- shows the block that spacer belongs to. The clear and hide hooks and ResetRendered forget the
-- spacer, so a rule they took off is never brought back. Answers showRule's outcome, or nil
-- where there was nothing to redraw.
function redrawRule(tooltip)
  local spacer = spacers[tooltip]
  if not spacer or rendered[tooltip] == nil or rendered[tooltip] ~= spacer.itemId then
    return nil
  end
  return showRule(tooltip, spacer.index)
end

-- Brief CS4: the next frame call. The tooltips waiting for it are a set (redrawQueue, beside
-- spacers above), and one shared function is booked once however many asked, so a rebuild five
-- times a second makes no closure and books at most one timer a frame. No C_Timer (busted, or a
-- client without it) books nothing.
local function flushRedraws()
  redrawBooked = false
  -- Taken whole first: a redraw can book the next frame again, which must not add to the set this
  -- loop walks.
  local due = redrawQueue
  redrawQueue = setmetatable({}, { __mode = "k" })
  for tooltip in pairs(due) do
    -- Brief BQ3: a rule a clear left up that no refill claimed comes off now.
    if staleRules[tooltip] then
      hideRule(tooltip)
    end
    if hints[tooltip] then
      keepHintLast(tooltip)
    end
    redrawRule(tooltip)
  end
end

function bookRedraw(tooltip)
  local timer = rawget(_G, "C_Timer")
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    return false
  end
  redrawQueue[tooltip] = true
  if not redrawBooked then
    redrawBooked = pcall(timer.After, 0, flushRedraws) and true or false
  end
  return redrawBooked
end

-- Brief BQ3 (owner QA item 18): the post show pass that keeps the hint the tooltip's last line.
--
-- What was chosen, and why. Lines can land under the block after the post call: one of our own
-- windows adds its row's lines after the item's fill (UI/Tree.lua's craft row adds its Ingredients
-- block, its sources and its own hint, then calls Show), and so can another addon's post call or
-- hook that runs after ours. The client offers no way to remove or insert a tooltip line, and
-- taking over the tooltip (replacing a method, or a hook that re-runs the fill) would fight the
-- client and every other addon. So the lines stay where the client put them and only their words
-- move: when the tooltip's size changes (the Show that follows any later lines) or on the next
-- frame, if lines sit under the hint, each of those lines' words, colour, wrap and right hand half
-- are moved up one line and the hint's words go on the last line, then one Show lays the tooltip
-- out again. Nothing is added, nothing is taken away, and another addon's line keeps its words and
-- colour, one line higher. The pass leaves alone a tooltip whose hint line no longer says the hint
-- (it was rebuilt), and one with any line it cannot read (bible B10: a secret value in combat is
-- never compared or copied), so the worst case is the hint where it was before.
--
-- Brief TT1 (QA item 225, a player with a tooltip reskin: tooltips kept shrinking and growing until
-- the hint was turned off): only what the client's AddLine sets again on every fill moves (words,
-- colour, wrap, the right half). A line's font never does. AddLine has no font argument, so the
-- client keeps a FontString's font through every clear and refill (why ShrinkGaps puts its fonts
-- back), and it rebuilds the Equipped tooltip every 0.2 s with its stat change lines under our hint
-- (TooltipComparisonManager.lua:236 to 311, forever 1.60.1.70450). A moved font stayed on the wrong
-- line and moved again on the next rebuild; a reskin that fonts the lines it sees on show leaves
-- two fonts there, so the lines changed width every rebuild. Each line keeps the font it has.
local function lineRegions(tooltip, index)
  local left = lineFontString(tooltip, index)
  if not left then
    return nil, nil
  end
  local ok, name = pcall(tooltip.GetName, tooltip)
  local right = ok and type(name) == "string" and rawget(_G, name .. "TextRight" .. index) or nil
  if type(right) ~= "table" then
    right = nil
  end
  return left, right
end

-- Every value a region answers, through Util.CanRead, or nil where any is unreadable.
local function readAll(region, method)
  if type(region[method]) ~= "function" then
    return true
  end
  local answers = { pcall(region[method], region) }
  if not answers[1] then
    return nil
  end
  for index = 2, #answers do
    if not canRead(answers[index]) then
      return nil
    end
  end
  table.remove(answers, 1)
  return answers
end

local function readHalf(region)
  if not region then
    return {}
  end
  local text = readAll(region, "GetText")
  local color = readAll(region, "GetTextColor")
  local shown = readAll(region, "IsShown")
  local wrap = readAll(region, "CanWordWrap")
  if not (text and color and shown and wrap) then
    return nil
  end
  return {
    text = type(text) == "table" and text[1] or nil,
    color = type(color) == "table" and color or nil,
    shown = type(shown) == "table" and shown[1] or nil,
    wrap = type(wrap) == "table" and wrap[1] or nil,
  }
end

local function writeHalf(region, half)
  if not region or type(half) ~= "table" then
    return
  end
  if type(region.SetWordWrap) == "function" and half.wrap ~= nil then
    pcall(region.SetWordWrap, region, half.wrap and true or false)
  end
  if type(region.SetText) == "function" then
    pcall(region.SetText, region, half.text or "")
  end
  local color = half.color
  if type(color) == "table" and color[1] and type(region.SetTextColor) == "function" then
    pcall(region.SetTextColor, region, color[1], color[2], color[3], color[4] or 1)
  end
  if half.shown == false and type(region.Hide) == "function" then
    pcall(region.Hide, region)
  elseif half.shown and type(region.Show) == "function" then
    pcall(region.Show, region)
  end
end

-- Answers "last" (nothing under the hint), "moved", "rebuilt" (the hint line says something else
-- now: forgotten), "unreadable" (left as it is), or nil with nothing to do.
function keepHintLast(tooltip)
  local held = hints[tooltip]
  if type(held) ~= "table" or movingHint[tooltip] or rendered[tooltip] ~= held.itemId then
    return nil
  end
  local total = lineTotal(tooltip)
  local order = Tooltip.HintOrder(total, held.index)
  if not order then
    if total and total < held.index then
      hints[tooltip] = nil
      return "rebuilt"
    end
    return "last"
  end
  local records = {}
  for index = held.index, total do
    local left, right = lineRegions(tooltip, index)
    if not left then
      return "unreadable"
    end
    local leftHalf, rightHalf = readHalf(left), readHalf(right)
    if not leftHalf or not rightHalf then
      return "unreadable"
    end
    records[index] = { left = leftHalf, right = rightHalf }
  end
  if records[held.index].left.text ~= held.text then
    hints[tooltip] = nil
    return "rebuilt"
  end
  movingHint[tooltip] = true
  for index = held.index, total do
    local left, right = lineRegions(tooltip, index)
    local from = records[order[index]]
    writeHalf(left, from.left)
    if right then
      writeHalf(right, from.right.text ~= nil and from.right or { text = "", shown = false })
    end
  end
  held.index = total
  if type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  movingHint[tooltip] = nil
  return "moved"
end
Tooltip.KeepHintLast = function(tooltip)
  return keepHintLast(tooltip)
end

-- Brief CS4: keeps the spacer a rendered tooltip's rule belongs to, refilling the tooltip's own
-- table rather than making one per render.
local function keepSpacer(tooltip, index, itemId)
  local spacer = spacers[tooltip]
  if not spacer then
    spacer = {}
    spacers[tooltip] = spacer
  end
  spacer.index, spacer.itemId = index, itemId
end

-- Brief TV2: the broken words each wrapping block line was given, by font, width and words, so a block
-- the client rebuilds five times a second is measured once. Emptied whole when it fills. In memory.
local wrapCache, wrapCached = {}, 0
Tooltip.WRAP_CACHE_MAX = 200
-- Brief TV2: units of room left under the width the client wraps a line at, so a line measured to fit
-- is never wrapped again by the client on a rounding difference.
Tooltip.WRAP_SLACK = 2
-- Brief TV2: a wrapping line narrower than this has not been laid out (or is not a block line at all),
-- and is left to the client.
Tooltip.WRAP_MIN_WIDTH = 100

-- A number a client object answers, through Util.CanRead (bible B10: a FontString's measures are
-- secret where its anchoring is, SimpleFontStringAPIDocumentation.lua SecretWhenAnchoringSecret), or
-- nil where it has no such method, raises or keeps it secret.
local function readNumber(object, method, ...)
  if type(object) ~= "table" or type(object[method]) ~= "function" then
    return nil
  end
  local ok, value = pcall(object[method], object, ...)
  if ok and canRead(value) and type(value) == "number" then
    return value
  end
  return nil
end

-- Brief TV2: the clear spacer that leads a wrapped line's continued lines (UI/Assets.lua Assets.Spacer).
local function wrapSpacer(width)
  local assets = ItemTree.Assets
  if type(assets) ~= "table" or type(assets.Spacer) ~= "function" then
    return nil
  end
  local ok, markup = pcall(assets.Spacer, width)
  if ok and type(markup) == "string" then
    return markup
  end
  return nil
end

-- Brief TV2: one block line's broken words for the region the client laid it out in, from the cache
-- where it can be: the words and how many lines they hold, or false and why the client keeps its own
-- wrap ("fits", "no measure", "no width", "unreadable", "cannot break").
local function wrappedFor(region, text)
  if type(region.GetUnboundedStringWidthForText) ~= "function" then
    return false, "no measure"
  end
  local width = readNumber(region, "GetWidth")
  if not width or width < Tooltip.WRAP_MIN_WIDTH then
    return false, "no width"
  end
  local function measure(words)
    return readNumber(region, "GetUnboundedStringWidthForText", words)
  end
  -- Wrapped where the client's own count says so, or where the words are wider than the line (a
  -- count the client works out lazily, or not at all, cannot hide a wrap from the measure).
  local shown = readNumber(region, "GetNumLines")
  if not (shown and shown >= 2) then
    local full = measure(text)
    if not full or full <= width + 0.5 then
      return false, "fits"
    end
  end
  if type(region.GetFont) ~= "function" then
    return false, "unreadable"
  end
  local got, font, size, flags = pcall(region.GetFont, region)
  if not (got and canRead(font) and canRead(size) and canRead(flags)) then
    return false, "unreadable"
  end
  local key = table.concat({ tostring(font), tostring(size), tostring(flags), tostring(math.floor(width)), text }, "\1")
  local held = wrapCache[key]
  if held == nil then
    local words, count = Tooltip.WrapText(text, width - Tooltip.WRAP_SLACK, measure, wrapSpacer)
    held = { words = words or false, count = count }
    if wrapCached >= Tooltip.WRAP_CACHE_MAX then
      wrapCache, wrapCached = {}, 0
    end
    wrapCache[key] = held
    wrapCached = wrapCached + 1
  end
  if not held.words then
    return false, "cannot break"
  end
  return held.words, held.count
end

-- Brief TV2: breaks the block's own wrapping lines where the client wrapped them (Tooltip.WrapText),
-- after the Show that laid them out, and shows the tooltip again so it takes their height. before is
-- the tooltip's line count before the block's blank line (lineTotal), lines the block as drawn and
-- doubleFirst true where the first line went on as a double line, which never wraps. A line is only
-- written where its region wraps and still says what the block put there, and never the hint, a gap or
-- a struck line. After the second Show each written line is checked against the client's own count
-- (GetNumLines): one the client wrapped further (the measure came out wrong) gets its words back as
-- they were, so the worst case is the client's own wrap. Answers how many lines kept the breaks;
-- Tooltip.stats.lastWrap says what the last call did, for /itemtree debug (Tooltip.WrapDebugLine).
-- Assumed, not yet seen in game (bible B1; written on 1.60.1.70450, the docs read at 70245): a wrapping
-- line's GetWidth after Show is the width the client wraps it at, and GetUnboundedStringWidthForText
-- counts an inline texture at its width. The specs run the fake client with GetNumLines answering, lazy
-- (always 1) and missing; the debug line is the probe ("put back" counts a wrong measure).
function Tooltip.Rewrap(tooltip, before, lines, doubleFirst)
  local stats = Tooltip.stats
  if type(tooltip) ~= "table" or type(before) ~= "number" or type(lines) ~= "table" then
    return 0
  end
  local written, why = {}, nil
  for offset, line in ipairs(lines) do
    local wanted = type(line) == "table" and line.wrap and type(line.text) == "string"
    if wanted and not (line.hint or line.gap or line.spacer or line.strike or (doubleFirst and offset == 1)) then
      local region = lineFontString(tooltip, before + 1 + offset)
      local can = region
        and type(region.CanWordWrap) == "function"
        and type(region.GetText) == "function"
        and type(region.SetText) == "function"
      local okWrap, wraps, okText, said = false, nil, false, nil
      if can then
        okWrap, wraps = pcall(region.CanWordWrap, region)
        okText, said = pcall(region.GetText, region)
      end
      if okWrap and okText and canRead(wraps) and canRead(said) and wraps == true and said == line.text then
        local words, count = wrappedFor(region, line.text)
        if words and pcall(region.SetText, region, words) then
          written[#written + 1] = { region = region, text = line.text, count = count }
        elseif not words and count ~= "fits" then
          why = why or count
        end
      end
    end
  end
  if #written == 0 then
    stats.lastWrap = why or "nothing wrapped"
    return 0
  end
  if type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  local putBack = 0
  for _, entry in ipairs(written) do
    local shown = readNumber(entry.region, "GetNumLines")
    if shown and shown > entry.count then
      pcall(entry.region.SetText, entry.region, entry.text)
      putBack = putBack + 1
    end
  end
  if putBack > 0 and type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  local kept = #written - putBack
  stats.wrapped = (tonumber(stats.wrapped) or 0) + kept
  stats.wrapPutBack = (tonumber(stats.wrapPutBack) or 0) + putBack
  stats.lastWrap = string.format("%d broken, %d put back", kept, putBack)
  return kept
end

-- Brief TV2: the /itemtree debug line on the block's own wrapping: what the last block did ("1 broken,
-- 0 put back", "nothing wrapped", or why the client kept its own wrap) and the session's counts, where
-- a count put back says the client wrapped a line differently from the measure. Pure over the stats.
function Tooltip.WrapDebugLine()
  local stats = type(Tooltip.stats) == "table" and Tooltip.stats or {}
  return string.format(
    "Tooltip wrap: last %s, lines broken %d, put back %d",
    tostring(stats.lastWrap or "none"),
    tonumber(stats.wrapped) or 0,
    tonumber(stats.wrapPutBack) or 0
  )
end

-- Theme.Color raises on an unknown key, and a raise inside a tooltip post call is swallowed
-- by the client, which would cost the whole block with nothing said. Read the table instead
-- and let the client pick its own colour when a key is missing.
local function lineColor(colorKey)
  local color = Theme and type(Theme.ColorTable) == "function" and Theme.ColorTable(colorKey) or nil
  if not color then
    return nil, nil, nil
  end
  return color.r, color.g, color.b
end

-- Records the outcome of one OnItem call, remembers its trace line and prints that line while
-- trace is on. Returns the outcome, so OnItem returns it from every path. rule is what the
-- divider rule did on a rendered call (brief CS4), nil on every other.
local function record(data, itemId, lineCount, outcome, source, rule)
  local stats = Tooltip.stats
  stats.lastItemId = itemId
  stats.lastOutcome = outcome
  stats.lastSource = source
  if outcome == "rendered" then
    stats.rendered = stats.rendered + 1
  end
  remember(stats.lastTooltip, data, itemId, lineCount, outcome, source, rule)
  if Tooltip.trace then
    local slash = ItemTree.Slash
    if slash and type(slash.Print) == "function" then
      local line = Tooltip.TraceLine(stats.lastTooltip, data, itemId, lineCount, outcome, source, rule)
      pcall(slash.Print, line)
    end
  end
  return outcome
end

-- True when data.id can be read as an item id. The typed registration is only ever handed
-- item data, so its id is trusted. The AllTypes registration sees every tooltip, where
-- data.id is a spell id on a spell tooltip and a currency id on a currency one, so there the
-- data has to say Item before the id means anything at all.
function Tooltip.TrustsDataId(data, source)
  if type(data) ~= "table" or data.id == nil then
    return false
  end
  if source ~= "all" then
    return true
  end
  local enum = rawget(_G, "Enum")
  local itemType = enum and enum.TooltipDataType and enum.TooltipDataType.Item
  return itemType ~= nil and data.type == itemType
end

-- One client API call, guarded and pcall'd: an API this client does not carry reads as nothing
-- found, and so does one that raises on a slot the client has already emptied.
local apiResult = ItemTree.Util.ApiResult

-- The item a setter method was asked to show, worked out from the setter's own arguments. This
-- is the only resolver that needs neither TooltipUtil.GetDisplayedItem nor GameTooltip:GetItem,
-- so it is what carries an engine that has dropped both. Each entry takes the arguments the
-- setter was called with and returns an item link, an item id, or nil. The keys are also the
-- list of methods Install post hooks.
local SETTER_LINKS = {
  SetBagItem = function(bag, slot)
    local container = rawget(_G, "C_Container")
    if container ~= nil then
      local link = apiResult(container.GetContainerItemLink, bag, slot)
      if link then
        return link
      end
    end
    return apiResult(rawget(_G, "GetContainerItemLink"), bag, slot)
  end,
  SetInventoryItem = function(unit, slot)
    return apiResult(rawget(_G, "GetInventoryItemLink"), unit, slot)
  end,
  SetMerchantItem = function(index)
    return apiResult(rawget(_G, "GetMerchantItemLink"), index)
  end,
  SetBuybackItem = function(index)
    return apiResult(rawget(_G, "GetBuybackItemLink"), index)
  end,
  SetLootItem = function(slot)
    return apiResult(rawget(_G, "GetLootSlotLink"), slot)
  end,
  SetQuestItem = function(kind, index)
    return apiResult(rawget(_G, "GetQuestItemLink"), kind, index)
  end,
  SetQuestLogItem = function(kind, index)
    return apiResult(rawget(_G, "GetQuestLogItemLink"), kind, index)
  end,
  -- Every other hyperlink type lands here too, since one setter shows them all. A spell or an
  -- enchant link carries no item id, and ItemIdFromLink refuses it, so the match is the test.
  SetHyperlink = function(link)
    if type(link) ~= "string" then
      return nil
    end
    return Tooltip.ItemIdFromLink(link)
  end,
  SetItemByID = function(id)
    return tonumber(id)
  end,
}
Tooltip.SETTER_LINKS = SETTER_LINKS

-- The setter methods to post hook, sorted so the install count is reached the same way every
-- session. Derived from the resolver table, so a method can never be hooked with nothing to
-- read its arguments with.
local SETTER_METHODS = {}
for method in pairs(SETTER_LINKS) do
  SETTER_METHODS[#SETTER_METHODS + 1] = method
end
table.sort(SETTER_METHODS)

-- The item id a setter post hook's context names, or nil. context is { method = name,
-- args = { ... } } as the hook built it. An unknown method, a resolver that finds nothing and a
-- resolver that raises all read the same way: nothing found.
function Tooltip.ItemIdFromSetter(context)
  if type(context) ~= "table" then
    return nil
  end
  local resolver = SETTER_LINKS[context.method]
  if type(resolver) ~= "function" then
    return nil
  end
  local args = type(context.args) == "table" and context.args or {}
  local ok, link = pcall(resolver, args[1], args[2], args[3])
  if not ok then
    return nil
  end
  return Tooltip.ItemIdFromLink(link)
end

-- data.id first where it can be trusted, then the tooltip data system's own reader, then the
-- older GetItem, then the setter's own arguments, then the link. TooltipUtil.GetDisplayedItem is
-- the supported way to read the item off a tooltip on a client with the data system, and it is
-- the only one left on an engine that has dropped GameTooltip:GetItem, so it comes before
-- GetItem rather than after. context is only ever handed over by the setter post hooks, and is
-- the last resort for an engine that offers neither reader.
function Tooltip.ResolveItemId(tooltip, data, source, context)
  if Tooltip.TrustsDataId(data, source) then
    return data.id
  end
  local util = rawget(_G, "TooltipUtil")
  if tooltip and util and type(util.GetDisplayedItem) == "function" then
    local ok, _, link, id = pcall(util.GetDisplayedItem, tooltip)
    if ok then
      if id then
        return id
      end
      local fromLink = Tooltip.ItemIdFromLink(link)
      if fromLink then
        return fromLink
      end
    end
  end
  if tooltip and type(tooltip.GetItem) == "function" then
    local ok, _, link = pcall(tooltip.GetItem, tooltip)
    if ok and link then
      local id = Tooltip.ItemIdFromLink(link)
      if id then
        return id
      end
    end
  end
  local fromSetter = Tooltip.ItemIdFromSetter(context)
  if fromSetter then
    return fromSetter
  end
  if type(data) == "table" and data.hyperlink then
    return Tooltip.ItemIdFromLink(data.hyperlink)
  end
  return nil
end

-- Brief K28: the link of the item a tooltip shows, for its random suffix roll, or nil: the
-- tooltip's own GetItem link first, then the data's hyperlink, then the setter's (its SetHyperlink
-- argument, or SETTER_LINKS' resolver: a bag slot's or a worn slot's link). A link only counts
-- where it names itemId, and every answer is asked through Util.CanRead (bible B10) before any
-- compare. Client assumption (bible B1), read on the forever branch of the UI source mirror at
-- 1.60.1.70245: GameTooltip:GetItem() answers the name and the link of the item shown (the one
-- reader UI/Keybind.lua and Tooltip.ResolveItemId already take; Blizzard_SharedXMLGame/Tooltip/
-- TooltipComparisonManager.lua builds its comparison item from the tooltip's item the same way),
-- from what the client holds, with no server query. Fake variants: tests/spec/ui_tooltip_suffix_spec.lua
-- "forever GetItem link", "data hyperlink only", "setter only", "another item" and "secret".
function Tooltip.ItemLink(tooltip, data, context, itemId)
  local function naming(link)
    if not canRead(link) or type(link) ~= "string" then
      return nil
    end
    if Tooltip.ItemIdFromLink(link) ~= itemId then
      return nil
    end
    return link
  end
  if itemId == nil then
    return nil
  end
  if type(tooltip) == "table" and type(tooltip.GetItem) == "function" then
    local ok, _, link = pcall(tooltip.GetItem, tooltip)
    local found = ok and naming(link) or nil
    if found then
      return found
    end
  end
  if type(data) == "table" then
    local found = naming(data.hyperlink)
    if found then
      return found
    end
  end
  if type(context) == "table" and type(context.args) == "table" then
    if context.method == "SetHyperlink" then
      return naming(context.args[1])
    end
    local resolver = SETTER_LINKS[context.method]
    if type(resolver) == "function" then
      local ok, link = pcall(resolver, context.args[1], context.args[2], context.args[3])
      return ok and naming(link) or nil
    end
  end
  return nil
end

-- Brief K28: the roll key of a link for an item (Keep.RollKey: a weapon or armour row whose link
-- names a random suffix roll the module prices), or nil. Read per draw for the block's stamp.
function Tooltip.RollOf(itemId, link)
  local keep = ItemTree.Keep
  if link == nil or type(keep) ~= "table" or type(keep.RollKey) ~= "function" then
    return nil
  end
  local ok, roll = pcall(keep.RollKey, itemId, link)
  if ok and type(roll) == "string" then
    return roll
  end
  return nil
end

-- Brief K18: what one of ItemTree's own frames asks of the block on a tooltip anchored to it, by
-- the frame (weak keys, so a frame let go is forgotten; nothing is ever written on a frame). The
-- Professions card's material is the one asker: it opens the item on a plain click and says so
-- in a line of its own, so its tooltip carries no "Ctrl + right click" hint, and its own lines go
-- on in the block's one pass (see Tooltip.OnItem for why that matters).
--   context  { itemId = n, noHint = true or nil, clickOnly = true or nil, lines = { { text, r, g, b } },
--            drawn = bool }
-- drawn is set once OnItem has put the lines on, so the asker knows whether to add them itself
-- (the setting off, no block, or this file not loaded). nil clears the frame's context.
-- Brief TT2 (QA item 247): the search dropdown's rows are the second asker, with clickOnly: an
-- edit box holds the keyboard over them and they open the item on a click of their own, so the
-- hint names that click and not the key (Tooltip.RowHintText).
local ownerContexts = setmetatable({}, { __mode = "k" })

function Tooltip.SetOwnerContext(owner, context)
  if type(owner) ~= "table" then
    return false
  end
  if type(context) == "table" then
    ownerContexts[owner] = context
  else
    ownerContexts[owner] = nil
  end
  return true
end

-- The context the tooltip's owner set for this item, or nil. One GetOwner, and only while some
-- frame has set one.
local function ownerContext(tooltip, itemId)
  if next(ownerContexts) == nil or type(tooltip) ~= "table" or type(tooltip.GetOwner) ~= "function" then
    return nil
  end
  local gotOwner, owner = pcall(tooltip.GetOwner, tooltip)
  if not gotOwner or type(owner) ~= "table" then
    return nil
  end
  local context = ownerContexts[owner]
  if type(context) == "table" and context.itemId == itemId then
    return context
  end
  return nil
end
Tooltip.OwnerContext = ownerContext

-- Brief K24b (A3): the bag slot a tooltip shows its item from: the SetBagItem setter's own (bag,
-- slot) where the setter post hook handed them over, else the owner's, where the owner is a
-- container item button (it answers GetBagID with a number, ContainerFrameItemButtonMixin; the
-- client's own ContainerFrame.lua reads the slot the same way, GetBagID and GetID). Only methods
-- of the owner are called and each answer is asked through Util.CanRead (bible B10); nothing is
-- set on it. nil, nil for anything else.
function Tooltip.BagSlot(tooltip, context)
  if type(context) == "table" and context.method == "SetBagItem" and type(context.args) == "table" then
    local bag, slot = tonumber(context.args[1]), tonumber(context.args[2])
    if bag and slot then
      return bag, slot
    end
  end
  if type(tooltip) ~= "table" or type(tooltip.GetOwner) ~= "function" then
    return nil, nil
  end
  local gotOwner, owner = pcall(tooltip.GetOwner, tooltip)
  if not gotOwner or not canRead(owner) or type(owner) ~= "table" then
    return nil, nil
  end
  if type(owner.GetBagID) ~= "function" or type(owner.GetID) ~= "function" then
    return nil, nil
  end
  local gotBag, bag = pcall(owner.GetBagID, owner)
  if not gotBag or not canRead(bag) then
    return nil, nil
  end
  local gotSlot, slot = pcall(owner.GetID, owner)
  if not gotSlot or not canRead(slot) then
    return nil, nil
  end
  return tonumber(bag), tonumber(slot)
end

-- Brief K24b (A3): the real bound state of the item a tooltip shows from a bag slot (Keep.BoundFor:
-- asked only where the item's row may bind), or nil.
function Tooltip.SlotBound(tooltip, itemId, context)
  local keep = ItemTree.Keep
  if type(keep) ~= "table" or type(keep.BoundFor) ~= "function" then
    return nil
  end
  local bag, slot = Tooltip.BagSlot(tooltip, context)
  if bag == nil or slot == nil then
    return nil
  end
  local ok, bound = pcall(keep.BoundFor, itemId, bag, slot)
  if ok and (bound == true or bound == false) then
    return bound
  end
  return nil
end

-- Brief K26: the pet food read for the item a tooltip shows (Keep.PetFor: a hunter with a pet
-- out that eats it, and whether this stack is the one kept), from its bag slot where it has one
-- (the stack count), else for the item alone (loot, a vendor, a link). nil for anyone else.
function Tooltip.SlotPet(tooltip, itemId, context)
  local keep = ItemTree.Keep
  if type(keep) ~= "table" or type(keep.PetFor) ~= "function" then
    return nil
  end
  local bag, slot = Tooltip.BagSlot(tooltip, context)
  local level, faction = Tooltip.PlayerFacts()
  local ok, pet = pcall(keep.PetFor, itemId, bag, slot, level, faction)
  if ok and type(pet) == "table" then
    return pet
  end
  return nil
end

-- Brief K31: which copy of a profession tool the player keeps, for the item a tooltip shows
-- (Keep.ToolFor), from its bag slot where it has one, else for the item alone (loot, a vendor, a
-- link). nil for anything but a tool of one of the player's professions.
function Tooltip.SlotTool(tooltip, itemId, context)
  local keep = ItemTree.Keep
  if type(keep) ~= "table" or type(keep.ToolFor) ~= "function" then
    return nil
  end
  local bag, slot = Tooltip.BagSlot(tooltip, context)
  local ok, tool = pcall(keep.ToolFor, itemId, bag, slot)
  if ok and type(tool) == "table" then
    return tool
  end
  return nil
end

-- Brief K24d (owner QA 2026-10-06: his Tracker's Pants on the character sheet and his Quickblade's
-- Dagger in the comparison tooltip read [Vendor] / "Not an upgrade"; "telling a player to vendor
-- what they wear is wrong"): the tooltips that show an item the player wears. Brief K24e: they read
-- [Keep] alone with the reason "Equipped" ("if it's my current best it should be keep").
-- Checked on the forever branch of the UI source mirror at 1.60.1.70205:
--   the client's comparison tooltips, by their frame names: ShoppingTooltip1 and 2 beside the game
--     tooltip, ItemRefShoppingTooltip1 and 2 beside the item link window (Blizzard_UIPanels_Game/
--     Mainline/ItemRef.xml:3-4, the pair ItemRefTooltipMixin:OnLoad lists as its shoppingTooltips,
--     ItemRef.lua:347), and any frame in either tooltip's own shoppingTooltips list (read only);
--   the character sheet's equipment slots: PaperDollItemSlotButton_OnEnter sets the game tooltip's
--     owner to the slot button and shows the item of slot self:GetID() (Blizzard_UIPanels_Game/
--     Camelot/PaperDollFrame.lua:2224 and 2228), and the buttons are named CharacterHeadSlot and
--     so on (Camelot/PaperDollFrame.xml:766 onwards); the slot is confirmed by asking the client
--     which item the player wears there (GetInventoryItemID("player", slot)), so another frame of
--     that shape, or a slot whose item changed, is never mistaken for it;
--   the setter path's SetInventoryItem("player", slot), where the client has no data processor.
-- Every client answer goes through Util.CanRead before any compare (bible B10); only methods of
-- the owner and the one inventory call are asked, and nothing is set on any frame.
--
-- Brief TT1 (owner QA item 143, 2026-10-13: a hunter wearing a two hander hovered an off hand and
-- the "Equipped With" tooltip's Skinning Knife read [Keep] "Equipped" while it sat in his bag): a
-- comparison tooltip can show an item the player does NOT wear. Checked on the forever branch of
-- the UI source mirror at 1.60.1.70245, Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua:
-- CompareItem asks C_TooltipComparison.GetItemComparisonInfo for the hovered item (:158), the second
-- comparison tooltip shows compareInfo.additionalItems[comparisonIndex] (GetSecondaryItem, :199-206,
-- filled into shoppingTooltips[2] at :225-226), and for the methods WithBagMainHandItem and
-- WithBagOffHandItem (:238) that item is a one hander FROM THE BAGS paired with the hovered off hand
-- to show the set, under the IF_EQUIPPED_TOGETHER header (:242-243). So a comparison tooltip's item
-- counts as worn only where the client confirms the player wears that item id in an equipment
-- slot (Tooltip.WornSlot, one pass over WORN_FIRST to WORN_LAST); otherwise it reads the ordinary
-- verdict, as the same item hovered in a bag would (its bag slot is unknown, so no slot facts).
Tooltip.COMPARISON_TOOLTIPS = {
  ShoppingTooltip1 = true,
  ShoppingTooltip2 = true,
  ItemRefShoppingTooltip1 = true,
  ItemRefShoppingTooltip2 = true,
}
Tooltip.COMPARISON_HOLDERS = { "GameTooltip", "ItemRefTooltip" }
-- The equipped inventory slots, 0 (Classic's ammo) to 19 (the tabard).
Tooltip.WORN_FIRST, Tooltip.WORN_LAST = 0, 19

-- Whether the player wears itemId in an equipment slot, asked of the client for that one slot.
local function wornIn(slot, itemId)
  slot = tonumber(slot)
  if slot == nil or slot < Tooltip.WORN_FIRST or slot > Tooltip.WORN_LAST or slot ~= math.floor(slot) then
    return false
  end
  local ask = rawget(_G, "GetInventoryItemID")
  if type(ask) ~= "function" then
    return false
  end
  local ok, held = pcall(ask, "player", slot)
  if not ok or not canRead(held) then
    return false
  end
  return held ~= nil and tonumber(held) == tonumber(itemId)
end

-- Brief TT1: the first equipment slot the player wears itemId in, asked of the client once per
-- slot from WORN_FIRST to WORN_LAST (one pass), or nil. A slot whose answer the client will not
-- give (a raise, or a value Util.CanRead refuses) is no claim.
function Tooltip.WornSlot(itemId)
  if tonumber(itemId) == nil or type(rawget(_G, "GetInventoryItemID")) ~= "function" then
    return nil
  end
  for slot = Tooltip.WORN_FIRST, Tooltip.WORN_LAST do
    if wornIn(slot, itemId) then
      return slot
    end
  end
  return nil
end

-- Whether a tooltip is one of the client's comparison tooltips.
function Tooltip.IsComparison(tooltip)
  if type(tooltip) ~= "table" then
    return false
  end
  local name = frameName(tooltip)
  if name and Tooltip.COMPARISON_TOOLTIPS[name] then
    return true
  end
  for _, holderName in ipairs(Tooltip.COMPARISON_HOLDERS) do
    local holder = rawget(_G, holderName)
    local list = type(holder) == "table" and rawget(holder, "shoppingTooltips") or nil
    if canRead(list) and type(list) == "table" then
      for _, frame in ipairs(list) do
        if rawequal(frame, tooltip) then
          return true
        end
      end
    end
  end
  return false
end

-- Brief CS4: another addon's hidden scanning tooltip. The typed post call fires for every
-- tooltip frame the client fills, so it reached the frames addons fill only to read the item's
-- lines back: the block was added to them (and read back as the item's own lines by an addon
-- that reads them all, as Jettison's Bags.ScanLines does), Show was called on them, and module
-- state the visible tooltips share (Tooltip.lastShownItem, the Keep reads) was overwritten.
--
-- The rule, from the client's own conventions and the scanners on the owner's machine, checked
-- on the forever branch of the UI source mirror at 1.60.1.70245:
--   - a forbidden tooltip is never ours to write to (IsForbidden);
--   - otherwise a scanner is a tooltip owned by WorldFrame or UIParent (or by nothing), anchored
--     ANCHOR_NONE, with no points set: it is filled and read and never placed, so it can never be
--     seen. Jettison's JettisonScanTooltip (Client/Bags.lua Bags.ScanLines: SetOwner(UIParent,
--     "ANCHOR_NONE"), ClearLines, SetHyperlink, read, Hide; never a SetPoint), Auctionator's
--     AuctionatorUtilitiesScanTooltipTooltip (Source_LegacyAH/Utilities/ScanTooltip.lua:
--     SetOwner(WorldFrame, "ANCHOR_NONE") before each fill, never placed) and Syndicator's
--     SyndicatorUtilitiesScanTooltip (Core/Utilities.lua DumpClassicTooltip, the same, made on
--     Classic only; Baganator scans through it or through C_TooltipInfo, which fills no frame).
--   - ANCHOR_NONE with no points alone is not enough: the client fills some tooltips a player
--     does see before it places them. TooltipComparisonManager:Initialize gives each comparison
--     tooltip SetOwner(the item's tooltip, "ANCHOR_NONE") and ClearAllPoints, SetItemTooltip fills
--     it (the post call), and only then AnchorShoppingTooltips sets its points
--     (Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua); EmbeddedItemTooltip_SetItemByID
--     fills its Tooltip owned by the embedded frame before its SetPoint
--     (Blizzard_GameTooltip/Mainline/GameTooltip.lua); Auctionator's shopping list rows fill
--     GameTooltip, owned by the row, before they place it (search terms there, not items, but the
--     same order). Those owners are never WorldFrame or UIParent,
--     which is why the owner is part of the rule; and the client's own named tooltips (GameTooltip,
--     ItemRefTooltip, and the comparison tooltips by name or by their holder's shoppingTooltips)
--     are never scanners whatever their state, so an addon that fills GameTooltip before placing
--     it still gets the block. GameTooltip_SetDefaultAnchor sets ANCHOR_NONE and then a point
--     before any fill (Blizzard_SharedXML/SharedTooltipTemplates.lua), and ItemRefTooltip is
--     owned ANCHOR_PRESERVE.
-- A tooltip that will not answer (no GetAnchorType, GetNumPoints or GetOwner, a raise, or an
-- answer Util.CanRead refuses) is not a scanner: a block on a scanner is the old behaviour, and a
-- block missing from a tooltip a player sees is the fault.
Tooltip.SEEN_TOOLTIPS = { GameTooltip = true, ItemRefTooltip = true }
Tooltip.SCAN_OWNERS = { "WorldFrame", "UIParent" }

-- One method's answer, or nil for a missing method, a raise or a value the client keeps secret.
local function asked(frame, method)
  if type(frame[method]) ~= "function" then
    return nil, false
  end
  local ok, value = pcall(frame[method], frame)
  if not ok or not canRead(value) then
    return nil, false
  end
  return value, true
end

function Tooltip.IsScanning(tooltip)
  if type(tooltip) ~= "table" then
    return false
  end
  if asked(tooltip, "IsForbidden") == true then
    return true
  end
  local name = frameName(tooltip)
  if name and Tooltip.SEEN_TOOLTIPS[name] then
    return false
  end
  if Tooltip.IsComparison(tooltip) then
    return false
  end
  if asked(tooltip, "GetAnchorType") ~= "ANCHOR_NONE" or asked(tooltip, "GetNumPoints") ~= 0 then
    return false
  end
  local owner, answered = asked(tooltip, "GetOwner")
  if not answered then
    return false
  end
  if owner == nil then
    return true
  end
  for _, root in ipairs(Tooltip.SCAN_OWNERS) do
    local frame = rawget(_G, root)
    if frame ~= nil and rawequal(owner, frame) then
      return true
    end
  end
  return false
end

-- Whether a tooltip shows an item instance the player wears: a comparison tooltip whose item the
-- client confirms worn (brief TT1), the character sheet's slot, or the setter's
-- SetInventoryItem("player", slot). A copy of the same item in a bag is not worn. context is the
-- setter post hook's { method, args }. Returns true and the slot it is worn in, or false.
function Tooltip.Worn(tooltip, itemId, context)
  if Tooltip.IsComparison(tooltip) then
    -- Brief TT1: the client's "Equipped With" pairing shows a bag item here too (the comment above
    -- COMPARISON_TOOLTIPS), so the slot is asked of the client, never assumed.
    local slot = Tooltip.WornSlot(itemId)
    if slot ~= nil then
      return true, slot
    end
    return false
  end
  if type(context) == "table" and context.method == "SetInventoryItem" and type(context.args) == "table" then
    local unit = context.args[1]
    if canRead(unit) and unit == "player" and wornIn(context.args[2], itemId) then
      return true, tonumber(context.args[2])
    end
  end
  if type(tooltip) ~= "table" or type(tooltip.GetOwner) ~= "function" then
    return false
  end
  local gotOwner, owner = pcall(tooltip.GetOwner, tooltip)
  if not gotOwner or not canRead(owner) or type(owner) ~= "table" then
    return false
  end
  local name = frameName(owner)
  if not name or not name:match("^Character%a+Slot$") or type(owner.GetID) ~= "function" then
    return false
  end
  local gotSlot, slot = pcall(owner.GetID, owner)
  if not gotSlot or not canRead(slot) then
    return false
  end
  if wornIn(slot, itemId) then
    return true, tonumber(slot)
  end
  return false
end

-- Brief F160 (owner QA 2026-10-14, item 160: Old Blanchy's Feed Pouch hovered IN THE BAG BAR read
-- [Equip] "Bigger than your 6 slot bag"): a bag hovered where it is in use, in one of the character's
-- own bag slots or a bank bag slot, is worn: [Keep] "Equipped bag" (Keep.WORN_BAG) or "Equipped bank
-- bag" (Keep.WORN_BANK_BAG). Checked on the forever branch of the UI source mirror at 1.60.1.70245
-- (the Forever client loads the Mainline and Camelot files):
--   the bag bar: BaseBagSlotButtonMixin:OnEnterInternal fills the game tooltip with
--     SetInventoryItem("player", self:GetID()) (Blizzard_MainMenuBarBagButtons/Shared/
--     MainMenuBarBagButtons.lua:102-105), the button's id being the bag's inventory slot (set from its
--     slotName by PaperDollItemSlotButton_OnLoad, :24-25). The buttons are CharacterBag0Slot to
--     CharacterBag3Slot and CharacterReagentBag0Slot (Mainline/MainMenuBarBagButtonTemplates.xml:90-129)
--     and the gamepad bag bar's unnamed Bag0SlotButton to ReagentBag0SlotButton
--     (Camelot/MainMenuBarBagButtons.xml:98-137), every one the same fill. Tooltip.Worn leaves them
--     out: their names hold a digit and their slots are past the equipment slots (WORN_LAST);
--   the bank's bag slots: BankItemButtonBagMixin:OnEnter fills it with SetBagItem(Enum.BagIndex.
--     Characterbanktab, the slot) (Accountbanktab for the warband bank; Blizzard_UIPanels_Game/Camelot/
--     BankFrame.lua:322-341), the container holding the bags of the bank tabs.
-- The fill is read as the setter post hook hands it (a client with no data processor), else from the
-- tooltip's primary info, the getter and arguments the client keeps for the fill
-- (TooltipDataHandlerMixin:GetPrimaryTooltipInfo, Blizzard_SharedXMLGame/Tooltip/
-- TooltipDataHandler.lua:393-395; the secure delegate's getterName and getterArgs (SafePack),
-- AddTooltipDataAccessorDelegate :488-503, installed at :606-609 for SetInventoryItem's getter
-- GetInventoryItem, :527, and SetBagItem's GetBagItem, :543), the same read the owner replay makes.
-- An inventory slot counts only where the client names it a bag slot (C_Container.
-- ContainerIDToInventoryID of bags 1 to NUM_BAG_SLOTS and Enum.BagIndex.ReagentBag; on a Classic
-- client with no bank tabs, the bank's NUM_BANKBAGSLOTS bag slots after them) and confirms the item
-- there (GetInventoryItemID); a bank tab's bag only where C_Container.GetContainerItemID on that
-- container confirms it (Keep.ReadBank reads the same). Every answer goes through Util.CanRead (bible
-- B10); nothing is set on any frame.
-- The fill methods by the getter the client keeps in the tooltip's info.
Tooltip.INFO_SETTERS = { GetInventoryItem = "SetInventoryItem", GetBagItem = "SetBagItem" }

-- The method and arguments the tooltip was filled with: the setter post hook's own, else the primary
-- info's getter as its setter and the getter's arguments. nil where neither says.
local function fillCall(tooltip, context)
  if type(context) == "table" and type(context.method) == "string" and type(context.args) == "table" then
    return context.method, context.args
  end
  if type(tooltip) ~= "table" then
    return nil, nil
  end
  local info = asked(tooltip, "GetPrimaryTooltipInfo")
  if type(info) ~= "table" then
    return nil, nil
  end
  local getter, args = info.getterName, info.getterArgs
  if not canRead(getter) or type(getter) ~= "string" or not canRead(args) or type(args) ~= "table" then
    return nil, nil
  end
  local method = Tooltip.INFO_SETTERS[getter]
  if method == nil then
    return nil, nil
  end
  return method, args
end

-- One client call that answers a number, read through Util.CanRead, or nil. space names a table of
-- functions (C_Container), else the global is called.
local function clientNumber(space, name, ...)
  local holder = space and rawget(_G, space) or nil
  local fn = type(holder) == "table" and rawget(holder, name) or nil
  if type(fn) ~= "function" then
    fn = rawget(_G, name)
  end
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if not ok or not canRead(value) then
    return nil
  end
  return tonumber(value)
end

-- A BagIndex value of the client's, or nil.
local function bagIndex(name)
  local enum = rawget(_G, "Enum")
  local index = type(enum) == "table" and rawget(enum, "BagIndex") or nil
  return type(index) == "table" and tonumber(rawget(index, name)) or nil
end

-- Which bag slot inventory slot invSlot is: "bag" (bags 1 to NUM_BAG_SLOTS, the reagent bag) or
-- "bank" (a Classic client's bank bag slots), or nil.
local function bagSlotKind(invSlot)
  local function is(bag)
    return clientNumber("C_Container", "ContainerIDToInventoryID", bag) == invSlot
  end
  local bags = tonumber(rawget(_G, "NUM_BAG_SLOTS")) or 4
  for bag = 1, bags do
    if is(bag) then
      return "bag"
    end
  end
  local reagent = bagIndex("ReagentBag")
  if reagent ~= nil and is(reagent) then
    return "bag"
  end
  local bank = tonumber(rawget(_G, "NUM_BANKBAGSLOTS"))
  if bank and bank > 0 and bagIndex("CharacterBankTab_1") == nil then
    for bag = bags + 1, bags + bank do
      if bag ~= reagent and is(bag) then
        return "bank"
      end
    end
  end
  return nil
end

--- Brief F160: "bag" or "bank" (Keep.WORN_BAG, Keep.WORN_BANK_BAG) where the tooltip shows itemId from
--- a bag slot it is in use in (the comment above), else nil. context is the setter post hook's {
--- method, args }, nil on the data processor's path.
function Tooltip.EquippedBag(tooltip, itemId, context)
  local id = tonumber(itemId)
  if id == nil then
    return nil
  end
  local method, args = fillCall(tooltip, context)
  if method == "SetInventoryItem" then
    local unit, slot = args[1], args[2]
    if not canRead(unit) or unit ~= "player" or not canRead(slot) then
      return nil
    end
    slot = tonumber(slot)
    -- The equipment slots are Tooltip.Worn's.
    if slot == nil or slot <= Tooltip.WORN_LAST then
      return nil
    end
    local where = bagSlotKind(slot)
    if where ~= nil and clientNumber(nil, "GetInventoryItemID", "player", slot) == id then
      return where
    end
    return nil
  end
  if method == "SetBagItem" then
    local holder, slot = args[1], args[2]
    if not canRead(holder) or not canRead(slot) then
      return nil
    end
    holder, slot = tonumber(holder), tonumber(slot)
    if holder == nil or slot == nil then
      return nil
    end
    if holder ~= bagIndex("Characterbanktab") and holder ~= bagIndex("Accountbanktab") then
      return nil
    end
    if clientNumber("C_Container", "GetContainerItemID", holder, slot) == id then
      return "bank"
    end
  end
  return nil
end

-- Brief BQ13: the small muted marker line every tooltip block carries while any demo state is on
-- (Core/Demo.lua Demo.On), so a screenshot is never mistaken for real play; nil while off. Pure over
-- the demo state.
function Tooltip.DemoMarker()
  local demo = ItemTree.Demo
  if type(demo) ~= "table" or type(demo.On) ~= "function" then
    return nil
  end
  local ok, on = pcall(demo.On)
  if not ok or on ~= true then
    return nil
  end
  return { text = L["Demo state on, not your real character"], colorKey = "ITEMTREE_COLOR_TEXT_MUTED" }
end

-- Brief K8: the demo's muted line for the bag or bank slot a tooltip is anchored to, or nil (the
-- demo is off, the owner is no slot, or the demo left it bare). UI/Overlay.lua answers it.
local function demoLine(tooltip)
  local ui = ItemTree.UI
  local overlay = type(ui) == "table" and ui.Overlay or nil
  if type(overlay) ~= "table" or type(overlay.DemoTipFor) ~= "function" or type(overlay.demo) ~= "table" then
    return nil
  end
  if type(tooltip) ~= "table" or type(tooltip.GetOwner) ~= "function" then
    return nil
  end
  local gotOwner, owner = pcall(tooltip.GetOwner, tooltip)
  if not gotOwner or type(owner) ~= "table" then
    return nil
  end
  local ok, text = pcall(overlay.DemoTipFor, owner)
  if ok and type(text) == "string" then
    return text
  end
  return nil
end

-- Appends the block under the client's own item lines. source names which registration
-- delivered the call: "item" for the typed post call, "all" for the AllTypes one, "hook" for the
-- Classic OnTooltipSetItem script and "setter" for a post hook on an item setter method. context
-- is the setter post hook's { method, args }, nil on every other path, and is read only once the
-- item only APIs have found nothing.
--
-- Returns one outcome string on every path, so a block that was never asked for can be told
-- apart from one that bailed. stats.calls is bumped as the very first statement and the
-- outcome is recorded at each exit, deliberately: the client swallows a raise thrown inside a
-- tooltip post call, so a fault between the two shows as calls climbing while the outcome
-- goes stale, which names it with no error message to go on.
function Tooltip.OnItem(tooltip, data, source, context)
  -- Brief CS4: another addon's scanning tooltip (or a forbidden one) leaves before any work or
  -- state change: no lines, no Show, no collector note, no Keep reads, and neither a call nor the
  -- last call in the stats (it is not a tooltip anyone sees, and an addon that scans every bag
  -- slot would bury the visible tooltips' trace under its own). It is only counted.
  if Tooltip.IsScanning(tooltip) then
    local counts = Tooltip.stats
    counts.scanning = (tonumber(counts.scanning) or 0) + 1
    return "skipped: scanning tooltip"
  end
  -- Brief SV1: data with a field the client keeps secret is treated as no data, so neither the
  -- id resolver nor the trace ever compares, prints or keeps it.
  if type(data) == "table" and not (canRead(data.id) and canRead(data.type) and canRead(data.hyperlink)) then
    data = nil
  end
  local stats = Tooltip.stats
  stats.calls = stats.calls + 1
  stats.lastTooltip = tooltipName(tooltip)
  source = source or "item"
  if not tooltip or type(tooltip.AddLine) ~= "function" then
    return record(data, nil, 0, "skipped: no AddLine", source)
  end
  local settings = ItemTree.db and ItemTree.db.settings or nil
  if settings and settings.tooltipEnabled == false then
    return record(data, nil, 0, "skipped: tooltips off", source)
  end
  local itemId = Tooltip.ResolveItemId(tooltip, data, source, context)
  if not itemId then
    return record(data, nil, 0, "skipped: no item id", source)
  end
  if rendered[tooltip] == itemId then
    return record(data, itemId, 0, "skipped: already rendered", source)
  end
  -- Every item tooltip names an item the client has just resolved, which is the cheapest place
  -- there is to notice that the realm has discovered one this build withholds. Guarded and
  -- pcall'd through UI/CollectorHooks.lua, which decides whether it is worth recording; a
  -- client with the collector turned off does nothing at all here.
  local hooks = ItemTree.CollectorHooks
  if hooks and type(hooks.NoteItem) == "function" then
    pcall(hooks.NoteItem, itemId, hooks.HOW_TOOLTIP)
  end
  -- Cached, because this runs again on every rebuild of a tooltip that is still on screen.
  -- The owner is read here, past the already rendered check, so it costs one hover and not one
  -- rebuild: a tooltip a click never reaches says so in the hint line.
  -- Brief K18: a tooltip anchored to the Professions card's material drops the hint whole.
  local owned = ownerContext(tooltip, itemId)
  local skip = ownerSkipsClick(tooltip)
  if owned and owned.noHint then
    skip = "hint"
  elseif owned and owned.clickOnly then
    -- Brief TT2 (QA item 247): a search dropdown row, which opens on its own click under the box.
    skip = "key"
  end
  -- Brief K24b: the real bound state of the bag slot the tooltip shows the item from, for this one
  -- item's Keep block (Tooltip.KeepLines), nil where it is not a bag slot.
  Tooltip.keepBoundItem, Tooltip.keepBound = itemId, Tooltip.SlotBound(tooltip, itemId, context)
  -- Brief K24d: whether it is an item the player wears. Brief TT1: a comparison tooltip's item only
  -- where the client confirms it in an equipment slot (one pass per show), else the bag verdict.
  Tooltip.keepWornItem, Tooltip.keepWorn = itemId, (Tooltip.Worn(tooltip, itemId, context))
  -- Brief F160: or a bag in the bag slot it is in use in (the bag bar, a bank bag slot), worn too.
  Tooltip.keepWornBag = nil
  if not Tooltip.keepWorn then
    Tooltip.keepWornBag = Tooltip.EquippedBag(tooltip, itemId, context)
    Tooltip.keepWorn = Tooltip.keepWornBag ~= nil
  end
  -- Brief K26: the hunter's pet food read for this one item (Keep.PetFor), nil for anyone else.
  Tooltip.keepPetItem, Tooltip.keepPet = itemId, Tooltip.SlotPet(tooltip, itemId, context)
  -- Brief K31: which copy of a profession tool is kept, for this copy's bag slot (Keep.ToolFor).
  Tooltip.keepToolItem, Tooltip.keepTool = itemId, Tooltip.SlotTool(tooltip, itemId, context)
  -- Brief K24h: the client's comparison tooltip is shown beside the item the game tooltip holds,
  -- the last one drawn that was not a comparison; the worn item's block names it where it is
  -- outdone by it. Any other tooltip remembers its own item as that one.
  -- Brief K28: the item's own link where it names a random suffix roll the module prices
  -- (Tooltip.ItemLink, Tooltip.RollOf), so the Keep block weighs that roll; nil for every other
  -- item, which is scored and priced exactly as before. Read only with Keep marks on.
  local link, roll = nil, nil
  if settingOn(settings or {}, "keepMarks") then
    link = Tooltip.ItemLink(tooltip, data, context, itemId)
    roll = Tooltip.RollOf(itemId, link)
    if roll == nil then
      link = nil
    end
  end
  Tooltip.keepLinkItem, Tooltip.keepLink, Tooltip.keepRoll = itemId, link, roll
  local comparison = Tooltip.IsComparison(tooltip)
  if comparison then
    Tooltip.keepAgainstItem, Tooltip.keepAgainst = itemId, Tooltip.lastShownItem
    -- Brief K28: and the bag item's link and roll, so its roll decides whether it outdoes the worn one.
    Tooltip.keepAgainstLink, Tooltip.keepAgainstRoll = Tooltip.lastShownLink, Tooltip.lastShownRoll
  else
    Tooltip.keepAgainstItem, Tooltip.keepAgainst = nil, nil
    Tooltip.keepAgainstLink, Tooltip.keepAgainstRoll = nil, nil
    Tooltip.lastShownItem, Tooltip.lastShownLink, Tooltip.lastShownRoll = itemId, link, roll
  end
  local lines = Tooltip.CachedLines(itemId, settings, skip)
  -- Brief TT1: no hint on a comparison tooltip (Tooltip.WithoutHint says why), so the post show
  -- pass never has a hint to keep last there.
  if comparison then
    lines = Tooltip.WithoutHint(lines)
  end
  -- Brief K8: the demo's line goes on after the block, and never into the cached lines.
  -- Brief BQ3: the one line kept under the hint. Demo mode (brief K7) is the owner's own display
  -- and K8 ends the tooltip with it; with it last, the post show pass leaves the tooltip alone.
  local demo = demoLine(tooltip)
  if demo then
    local copy = {}
    for index = 1, #lines do
      copy[index] = lines[index]
    end
    copy[#copy + 1] = { text = demo, colorKey = "ITEMTREE_COLOR_TEXT_MUTED" }
    lines = copy
  end
  -- Brief BQ13: the demo state's marker, above the hint, never into the cached lines.
  local marker = #lines > 0 and Tooltip.DemoMarker() or nil
  if marker then
    lines = Tooltip.BeforeHint(lines, { marker })
  end
  if #lines == 0 then
    return record(data, itemId, 0, "skipped: no lines", source)
  end
  -- Brief K18: the owner's own lines ("Click to see where to get it") go on in this same pass,
  -- under the block and before the one Show, never into the cached lines. Added by the owner
  -- after this Show, they landed on a tooltip the client had already sized and laid out, and the
  -- client's data refresh (about five times a second on the beta) rebuilt the item lines under
  -- them without knowing they were there: the hint and the line after it were drawn over each
  -- other. Put on here, every rebuild puts them back in their place.
  -- Brief BQ3: above the hint, which stays the last line (Tooltip.BeforeHint).
  if owned and type(owned.lines) == "table" and #owned.lines > 0 then
    local extras = {}
    for _, extra in ipairs(owned.lines) do
      if type(extra) == "table" and type(extra.text) == "string" then
        extras[#extras + 1] = { text = extra.text, label = extra.text, rgb = extra, wrap = true }
      end
    end
    lines = Tooltip.BeforeHint(lines, extras)
  end
  if owned then
    owned.drawn = true
  end
  -- Marked before the lines go on, so a tooltip that re-enters while it is being filled
  -- cannot double the block up, and so the AllTypes call drops what the typed call rendered.
  rendered[tooltip] = itemId
  -- Brief AT4: any short gap still shrunk on this tooltip gets its font back before the lines go
  -- on, so a fill the clear hook did not see never draws a line (the game's own included) in a
  -- gap's small font.
  Tooltip.RestoreGaps(tooltip)
  -- Counted before the spacer goes on, so the rule knows which line to draw itself across.
  local before = lineTotal(tooltip)
  tooltip:AddLine(" ")
  -- Brief Q9a: the line each struck old value went on, counted from the spacer's.
  local struck = {}
  for offset, line in ipairs(lines) do
    local r, g, b
    if type(line.rgb) == "table" then
      r, g, b = line.rgb.r, line.rgb.g, line.rgb.b
    else
      r, g, b = lineColor(line.colorKey)
    end
    -- Brief TB7 (players' feedback, 2026-10-05): the section's first line, whatever it is, carries
    -- "ItemTree" at its right end in the muted colour (Tooltip.LABEL_COLOR), so a player with
    -- several tooltip addons can tell which section is ours. A double line does not wrap, and its
    -- width is the line's words, the client's gap and the label, never more than our longest
    -- line and the label. A tooltip with no double lines gets the plain line.
    if offset == 1 and type(tooltip.AddDoubleLine) == "function" then
      local lr, lg, lb = lineColor(Tooltip.LABEL_COLOR)
      tooltip:AddDoubleLine(line.text, Tooltip.LabelText(), r, g, b, lr, lg, lb)
    elseif line.wrap then
      tooltip:AddLine(line.text, r, g, b, true)
    else
      tooltip:AddLine(line.text, r, g, b)
    end
    if line.strike and before then
      struck[before + 1 + offset] = line.strike
    end
  end
  local hooked = hookClears(tooltip)
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
  -- Brief TV2 (QA item 347, across-5): the block's own lines the client wrapped are broken again by
  -- us, under their first line's words and with no word alone at the end, now that the Show has laid
  -- them out at the tooltip's width (Tooltip.Rewrap shows the tooltip again where it wrote any).
  if before then
    Tooltip.Rewrap(tooltip, before, lines, type(tooltip.AddDoubleLine) == "function")
  end
  -- After Show, which is where the client sizes and places what it was just handed, and only
  -- with the clear hooks in place, so a rule or a strike can always be taken off again. Brief
  -- K24i: the short gaps first, and the tooltip shown again so it takes their new height, before
  -- the rule and the strikes read where the lines sit.
  -- Brief CS4: the spacer is kept for the size hook and the next frame, which draw the rule
  -- again where the client had not placed the tooltip yet or the lines moved after this.
  local rule
  if hooked and before then
    local shrunk = Tooltip.ShrinkGaps(tooltip, Tooltip.GapScales(lines, before))
    if shrunk > 0 and type(tooltip.Show) == "function" then
      tooltip:Show()
    end
    keepSpacer(tooltip, before + 1, itemId)
    rule = showRule(tooltip, before + 1)
    -- Brief BQ3: a rule a clear left up is kept where this is the same block on the same spacer
    -- and the tooltip has no place yet (the comparison tooltip's rebuild); drawn again, or taken
    -- off where this is something else.
    local stale = staleRules[tooltip]
    if stale then
      staleRules[tooltip] = nil
      if rule ~= "drawn" and not (stale.index == before + 1 and stale.itemId == itemId) then
        hideRule(tooltip)
      end
    end
    -- Brief BQ3: where the block ends with the hint, the post show pass keeps it the last line.
    local last = lines[#lines]
    if type(last) == "table" and last.hint then
      hints[tooltip] = { index = before + 1 + #lines, text = last.text, itemId = itemId }
    else
      hints[tooltip] = nil
    end
    bookRedraw(tooltip)
    if next(struck) then
      showStrikes(tooltip, struck)
    end
  else
    spacers[tooltip] = nil
    hints[tooltip] = nil
    if staleRules[tooltip] then
      hideRule(tooltip)
    end
    rule = hooked and "no line" or "no hooks"
    stats.lastRule = rule
  end
  -- Brief BQ20: watched for the modifier while the block has uses to fold.
  Tooltip.WatchModifier(tooltip, itemId, lines, settings)
  return record(data, itemId, #lines, "rendered", source, rule)
end

-- Brief BQ20 (owner QA item 20, 2026-10-10: Ctrl did not unfold the uses on a tooltip shown from a
-- Jettison list row). The fold (Tooltip.FoldUses) is read when the block is built, so the uses only
-- unfold when the client fills the tooltip again while the key is held. The client does that
-- through the owner: GameTooltip_OnUpdate (Blizzard_GameTooltip/Mainline/GameTooltip.lua:460 to
-- 473, forever branch, 1.60.1 70245) calls owner:UpdateTooltip, else the tooltip's own
-- UpdateTooltip, else RefreshData only where a data update asked for one (shouldRefreshData, set by
-- RefreshDataNextUpdate, GameTooltip.lua:973 to 976). A bag slot has UpdateTooltip; a row of
-- another addon (or of ours) has none, so its tooltip was never filled again.
--
-- So, while one of our blocks with uses to fold is on screen, a frame of our own listens for
-- MODIFIER_STATE_CHANGED. When the setting's modifier goes down or up and the shown block was built
-- the other way, the tooltip is filled again through the client's own refill
-- (RebuildFromTooltipInfo, Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua:358 to 390, the
-- body of RefreshData at GameTooltip.lua:968 to 971): it replays what the owner set (SetBagItem,
-- SetHyperlink), clears the lines (our clear hook forgets the block) and runs the post calls, so
-- OnItem draws the block again from the cache under the new fold stamp. Only where the owner has no
-- UpdateTooltip (one that has is redrawn by the client within 0.2 s), and only where the tooltip's
-- current fill was made by an addon (issecurevariable on its infoList answers not secure): the
-- refill then writes nothing an addon has not already written, and a fill the client made itself
-- is never replayed under our taint (bible A1). The key is only read (the event's own argument and
-- IsControlKeyDown and its siblings), never bound or consumed; no click, key binding or secure path
-- is touched. Every client answer goes through Util.CanRead first (bible B10). The event is
-- unregistered once no tooltip is watched: on the hide and clear hooks, and on a block with nothing
-- to fold.
--
-- Brief TT2 (the owner's QA item 251, Wool Cloth in the search dropdown: "Holding ctrl to expand
-- doesnt work while seraching an item I think because the serach box is eating the ctrl"): the
-- client sends no MODIFIER_STATE_CHANGED while an edit box holds the keyboard, and the search box
-- holds it the whole time its dropdown is up. The row's redraw (brief BQ25a) is the item page
-- header's, which unfolds (QA item 88), so the event was the one thing missing. While the event is
-- registered, the same frame of ours also reads the modifier on its own OnUpdate
-- (Tooltip.PollModifier, at most every MODIFIER_POLL_SECONDS) and fills the watched tooltips again
-- when the held state has changed since it or the event last looked: one refill per change, from
-- whichever sees it first. IsControlKeyDown and its siblings answer the key's real state with an
-- edit box focused (the client's own chat link click reads its modifier with the chat box open).
-- No edit box is touched: no script, no focus change, nothing bound or consumed.
local modifierWatch = setmetatable({}, { __mode = "k" })
local modifierRegistered = false
-- Brief TT2: whether the poll is on, the time since it last read the key, and the held state it or
-- the event last saw (a block's own stamp when it is watched).
local modifierPolling, pollWait, polledHeld = false, 0, nil

-- The modifier an event's key names ("LCTRL", "RSHIFT", "LALT"), or nil for any other key or an
-- answer that is not a plain string. Pure.
function Tooltip.ModifierOfKey(key)
  if type(key) ~= "string" then
    return nil
  end
  if key:find("CTRL", 1, true) then
    return "ctrl"
  elseif key:find("SHIFT", 1, true) then
    return "shift"
  elseif key:find("ALT", 1, true) then
    return "alt"
  end
  return nil
end

-- Whether a drawn block has uses the fold acts on: the folded line, or the lines it folds. Pure.
function Tooltip.HasFoldable(lines)
  if type(lines) ~= "table" then
    return false
  end
  for _, line in ipairs(lines) do
    if type(line) == "table" and (line.folded or line.other) then
      return true
    end
  end
  return false
end

-- Brief TT2: the watch frame's OnUpdate while the poll is on, under Core/Guard.lua's boundary as
-- the event is.
local function modifierPollScript(_, elapsed)
  local Guard = ItemTree.Guard
  if type(Guard) == "table" and type(Guard.Run) == "function" then
    Guard.Run("Tooltip.PollModifier", Tooltip.PollModifier, elapsed)
    return
  end
  Tooltip.PollModifier(elapsed)
end

-- Brief TT2: the poll on or off, on our own frame. Off, the frame has no OnUpdate at all.
local function setModifierPoll(on)
  local frame = Tooltip.modifierFrame
  if on == modifierPolling or type(frame) ~= "table" or type(frame.SetScript) ~= "function" then
    return
  end
  if pcall(frame.SetScript, frame, "OnUpdate", on and modifierPollScript or nil) then
    modifierPolling = on
    pollWait = 0
  end
end

local function setModifierEvent(on)
  -- Brief TT2: the poll goes on and off with the event.
  setModifierPoll(on)
  local frame = Tooltip.modifierFrame
  if on == modifierRegistered or type(frame) ~= "table" then
    return
  end
  local method = on and frame.RegisterEvent or frame.UnregisterEvent
  if type(method) == "function" and pcall(method, frame, "MODIFIER_STATE_CHANGED") then
    modifierRegistered = on
  end
end

-- Whether the modifier event is registered now. For the specs and /itemtree debug.
function Tooltip.ModifierWatched()
  return modifierRegistered
end

-- Brief TT2: whether the poll is on now. For the specs.
function Tooltip.ModifierPolled()
  return modifierPolling
end

-- Stops watching one tooltip, and unregisters the event when it was the last. nil forgets all.
function Tooltip.UnwatchModifier(tooltip)
  if tooltip == nil then
    modifierWatch = setmetatable({}, { __mode = "k" })
  else
    modifierWatch[tooltip] = nil
  end
  if next(modifierWatch) == nil then
    setModifierEvent(false)
  end
end

-- Called by OnItem with the block it drew: watched while the block has uses to fold and the
-- setting is on, with the held state it was built under; otherwise not watched.
function Tooltip.WatchModifier(tooltip, itemId, lines, settings)
  if type(tooltip) ~= "table" then
    return false
  end
  settings = settings or (ItemTree.db and ItemTree.db.settings) or {}
  if not (settingOn(settings, "tooltipHideOtherUses") and Tooltip.HasFoldable(lines)) then
    Tooltip.UnwatchModifier(tooltip)
    return false
  end
  local held = Tooltip.FoldHeldStamp(settings)
  modifierWatch[tooltip] = { itemId = itemId, held = held }
  -- Brief TT2: the poll looks for a change from the state this block was built under.
  polledHeld = held
  setModifierEvent(true)
  return true
end

-- A method's answer from a client frame, or nil where it raises or the client keeps it secret.
local function frameAnswer(frame, method)
  if type(frame) ~= "table" or type(frame[method]) ~= "function" then
    return nil
  end
  local ok, answer = pcall(frame[method], frame)
  if ok and canRead(answer) then
    return answer
  end
  return nil
end

-- Whether an addon made the tooltip's current fill: issecurevariable on the tooltip's infoList
-- answers not secure. false where the client made it, will not say, or keeps the answer secret.
local function addonFilled(tooltip)
  local check = rawget(_G, "issecurevariable")
  if type(check) ~= "function" then
    return false
  end
  local ok, secure = pcall(check, tooltip, "infoList")
  if not ok or not canRead(secure) then
    return false
  end
  return secure == false
end

-- Brief BQ25a (the owner's QA item 72, Empty Vial, 2026-10-10: Ctrl did not unfold "and 43 other
-- uses, hold Ctrl" on the search dropdown row nor the item page header). On the Forever client every
-- item setter (SetItemByID, SetHyperlink, SetBagItem) is a secure delegate
-- (Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua:487 to 516, forever branch, 1.60.1 70245:
-- "Execution at this point is untainted"), so the tooltip's infoList is written securely even when
-- an addon called the setter, addonFilled answers false and BQ20's refill never ran for our own
-- window's tooltips. Two ways now, both ours alone:
--   our own frames: the window's show functions hand their owner and themselves here on each hover
--     (Tooltip.RedrawOnModifier, one call in UI/Frame.lua's search rows, UI/InfoPanel.lua's header
--     and UI/Tree.lua's rows), and the modifier change calls that show function again: the very
--     code the hover ran, so the lines the window adds under the item come back too
--   an addon's own frames (the Jettison lists): where the owner or a frame above it is named by an
--     addon in Tooltip.REPLAY_OWNER_PREFIXES, the tooltip's item setter is called again with the
--     arguments the client kept (GetPrimaryTooltipInfo), the call that addon made on its hover.
-- Never for a client frame, never a binding or a click; the setters are the public calls any
-- addon makes. Every client answer goes through Util.CanRead first (bible B10).
local redraws = setmetatable({}, { __mode = "k" })

function Tooltip.RedrawOnModifier(owner, show, arg)
  if type(owner) ~= "table" then
    return false
  end
  if type(show) == "function" then
    redraws[owner] = { show = show, arg = arg }
  else
    redraws[owner] = nil
  end
  return true
end

-- The show function an owner handed in, or nil. For the specs.
function Tooltip.RedrawFor(owner)
  local entry = type(owner) == "table" and redraws[owner] or nil
  return entry and entry.show or nil
end

-- The addons whose frames' item tooltips are filled again with the setter they used.
Tooltip.REPLAY_OWNER_PREFIXES = { "Jettison" }

-- The item setters the replay may call again, by the getter the client keeps in the tooltip's info.
local REPLAY_SETTERS = { GetBagItem = "SetBagItem", GetHyperlink = "SetHyperlink", GetItemByID = "SetItemByID" }

-- Whether the owner, or a frame up to OWNER_PARENT_DEPTH above it, is named by one of the addons
-- in Tooltip.REPLAY_OWNER_PREFIXES. A name the client keeps secret says nothing. Pure over the
-- frames' own answers.
function Tooltip.AddonOwner(owner)
  local frame = owner
  for _ = 0, OWNER_PARENT_DEPTH do
    if type(frame) ~= "table" then
      return false
    end
    local name = frameName(frame)
    if name then
      for _, prefix in ipairs(Tooltip.REPLAY_OWNER_PREFIXES) do
        if name:sub(1, #prefix) == prefix then
          return true
        end
      end
    end
    if type(frame.GetParent) ~= "function" then
      return false
    end
    local ok, parent = pcall(frame.GetParent, frame)
    if not ok or not canRead(parent) then
      return false
    end
    frame = parent
  end
  return false
end

-- Calls the tooltip's item setter again with the arguments its primary info kept. true where it
-- was called.
local function replayItem(tooltip)
  local info = frameAnswer(tooltip, "GetPrimaryTooltipInfo")
  if type(info) ~= "table" then
    return false
  end
  local getter = info.getterName
  if not canRead(getter) or type(getter) ~= "string" or not REPLAY_SETTERS[getter] then
    return false
  end
  local args = info.getterArgs
  if type(args) ~= "table" then
    return false
  end
  local count = tonumber(args.n) or #args
  for index = 1, count do
    if not canRead(args[index]) then
      return false
    end
  end
  local setter = tooltip[REPLAY_SETTERS[getter]]
  if type(setter) ~= "function" then
    return false
  end
  return (pcall(setter, tooltip, unpack(args, 1, count)))
end

-- Fills one watched tooltip again for the modifier's new state. Answers what it did:
-- "refilled", "owner redraws" (the client calls the owner's UpdateTooltip itself), "redrawn" (brief
-- BQ25a: our own window's show function ran again), "replayed" (an addon owner's item setter was
-- called again), "client fill" (the fill is the client's own, left alone), "no refill" (the tooltip
-- has no refill call) or "gone" (hidden, or no longer showing the block it was watched for).
function Tooltip.RefillForModifier(tooltip)
  local entry = modifierWatch[tooltip]
  if not entry or rendered[tooltip] ~= entry.itemId or frameAnswer(tooltip, "IsShown") ~= true then
    Tooltip.UnwatchModifier(tooltip)
    return "gone"
  end
  local owner = frameAnswer(tooltip, "GetOwner")
  if type(owner) == "table" then
    local okUpdate, update = pcall(function()
      return owner.UpdateTooltip
    end)
    if okUpdate and canRead(update) and type(update) == "function" then
      return "owner redraws"
    end
    -- Brief BQ25a: one of our own window's owners, its show function run again.
    local redraw = redraws[owner]
    if redraw then
      local arg = redraw.arg
      if arg == nil then
        arg = owner
      end
      pcall(redraw.show, arg)
      return "redrawn"
    end
  end
  if not addonFilled(tooltip) then
    -- Brief BQ25a: an addon's own frame, its item setter called again.
    if type(owner) == "table" and Tooltip.AddonOwner(owner) and replayItem(tooltip) then
      return "replayed"
    end
    return "client fill"
  end
  local refill = tooltip.RebuildFromTooltipInfo
  if type(refill) ~= "function" then
    return "no refill"
  end
  pcall(refill, tooltip)
  return "refilled"
end

-- Every watched tooltip whose block was built the other way from held is filled again, and held is
-- what the poll compares against from now on (brief TT2). Answers how many were filled again.
local function refillDue(held)
  polledHeld = held
  local due = {}
  for tooltip, entry in pairs(modifierWatch) do
    if entry.held ~= held then
      due[#due + 1] = tooltip
    end
  end
  local refilled = 0
  for _, tooltip in ipairs(due) do
    local outcome = Tooltip.RefillForModifier(tooltip)
    Tooltip.stats.lastUnfold = outcome
    if outcome == "refilled" or outcome == "redrawn" or outcome == "replayed" then
      refilled = refilled + 1
    end
  end
  return refilled
end

-- MODIFIER_STATE_CHANGED: every watched tooltip whose block was built the other way is filled
-- again. A key the client names and that is not the setting's modifier changes nothing. Answers
-- how many tooltips were filled again. Brief TT2: every event is counted for /itemtree debug.
function Tooltip.OnModifierChanged(key)
  local stats = Tooltip.stats
  stats.modifierEvents = (tonumber(stats.modifierEvents) or 0) + 1
  local settings = (ItemTree.db and ItemTree.db.settings) or {}
  if canRead(key) then
    local named = Tooltip.ModifierOfKey(key)
    if named and named ~= Tooltip.UsesModifier(settings) then
      return 0
    end
  end
  return refillDue(Tooltip.FoldHeldStamp(settings))
end

-- Brief TT2 (QA item 251): the poll, run by the watch frame's OnUpdate while a tooltip is watched.
-- At most once every MODIFIER_POLL_SECONDS it reads the setting's modifier (Tooltip.FoldHeldStamp)
-- and, where that has changed since the poll or the event last looked, fills the watched tooltips
-- again exactly as the event does; a change the event already answered is never answered twice.
-- Each change it saw first is counted for /itemtree debug. Answers how many were filled again.
Tooltip.MODIFIER_POLL_SECONDS = 0.05

function Tooltip.PollModifier(elapsed)
  pollWait = pollWait + (tonumber(elapsed) or 0)
  if pollWait < Tooltip.MODIFIER_POLL_SECONDS then
    return 0
  end
  pollWait = 0
  local held = Tooltip.FoldHeldStamp((ItemTree.db and ItemTree.db.settings) or {})
  if held == polledHeld then
    return 0
  end
  local stats = Tooltip.stats
  stats.modifierPolls = (tonumber(stats.modifierPolls) or 0) + 1
  return refillDue(held)
end

-- Brief TT2: the /itemtree debug line on the Ctrl unfold: what the last refill did, and how many
-- modifier changes the client's event and the poll each saw (the poll alone, in the search
-- dropdown, is QA item 251's cause seen in game). Session counts, never saved. Pure over the stats.
function Tooltip.UnfoldDebugLine()
  local stats = type(Tooltip.stats) == "table" and Tooltip.stats or {}
  return string.format(
    "Tooltip unfold: last %s, modifier events %d, caught by the poll %d",
    tostring(stats.lastUnfold or "none"),
    tonumber(stats.modifierEvents) or 0,
    tonumber(stats.modifierPolls) or 0
  )
end

-- The watching frame, ours, made at load and never parented to a client frame. The event is only
-- registered while a tooltip is watched, and (brief TT2) the poll's OnUpdate only set then.
-- Answers the frame, or nil where the client makes none.
function Tooltip.InstallModifierWatch()
  if Tooltip.modifierFrame then
    return Tooltip.modifierFrame
  end
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, "Frame")
  if not ok or type(frame) ~= "table" or type(frame.SetScript) ~= "function" then
    return nil
  end
  pcall(frame.SetScript, frame, "OnEvent", function(_, _, key)
    local Guard = ItemTree.Guard
    if type(Guard) == "table" and type(Guard.Run) == "function" then
      Guard.Run("Tooltip.OnModifierChanged", Tooltip.OnModifierChanged, key)
      return
    end
    Tooltip.OnModifierChanged(key)
  end)
  Tooltip.modifierFrame = frame
  modifierRegistered = false
  modifierPolling = false
  return frame
end

-- Brief G1: what every one of our tooltip post calls and hooks runs. The body is ours and runs
-- under Core/Guard.lua's boundary: an error leaves our lines off (they are all worked out before
-- the first goes on), the client's own tooltip is untouched, and the error is recorded and handed
-- to the client's error handler with its stack, rather than raised into a post call the client
-- swallows without a word.
local function guardedItem(tooltip, data, source, context)
  local Guard = ItemTree.Guard
  if type(Guard) == "table" and type(Guard.Run) == "function" then
    Guard.Run("Tooltip.OnItem", Tooltip.OnItem, tooltip, data, source, context)
    return
  end
  Tooltip.OnItem(tooltip, data, source, context)
end
Tooltip.GuardedItem = guardedItem

-- Brief R12: a world object's tooltip, handed to UI/CollectorHooks.lua NoteNodeTooltip, which
-- records a gathering node seen on hover. Nothing is drawn and the tooltip is not written to. The
-- same boundary as the item path.
local function guardedNode(tooltip, data)
  local hooks = ItemTree.CollectorHooks
  if type(hooks) ~= "table" or type(hooks.NoteNodeTooltip) ~= "function" then
    return
  end
  local Guard = ItemTree.Guard
  if type(Guard) == "table" and type(Guard.Run) == "function" then
    Guard.Run("CollectorHooks.NoteNodeTooltip", hooks.NoteNodeTooltip, tooltip, data)
    return
  end
  pcall(hooks.NoteNodeTooltip, tooltip, data)
end
Tooltip.GuardedNode = guardedNode

-- The world object data type, where this client's Enum names one, or nil.
local function objectDataType()
  local enum = rawget(_G, "Enum")
  local types = type(enum) == "table" and rawget(enum, "TooltipDataType") or nil
  return type(types) == "table" and rawget(types, "Object") or nil
end

-- The modern data processor, when this client has one. Returns the processor and the item
-- data type, or nil.
local function itemProcessor()
  local processor = rawget(_G, "TooltipDataProcessor")
  local enum = rawget(_G, "Enum")
  local dataType = enum and enum.TooltipDataType and enum.TooltipDataType.Item
  if processor and type(processor.AddTooltipPostCall) == "function" and dataType then
    return processor, dataType
  end
  return nil
end

-- The tooltips that still offer the OnTooltipSetItem script. A client with the tooltip data
-- processor has dropped that script type altogether, and asking such a frame to hook it
-- raises, so the frame has to admit to the script before it is offered as a target.
local function hookTargets()
  local frames = {}
  for _, name in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
    local frame = rawget(_G, name)
    if frame and type(frame.HookScript) == "function" and hasScript(frame, "OnTooltipSetItem") then
      frames[#frames + 1] = frame
    end
  end
  return frames
end

-- The frame and method pairs this client will let us post hook. hooksecurefunc on a method the
-- frame does not carry raises, so a missing method is skipped rather than offered, and with no
-- hooksecurefunc at all there is nothing to offer.
local function setterTargets()
  local targets = {}
  if type(rawget(_G, "hooksecurefunc")) ~= "function" then
    return targets
  end
  for _, name in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
    local frame = rawget(_G, name)
    if type(frame) == "table" then
      for _, method in ipairs(SETTER_METHODS) do
        if type(frame[method]) == "function" then
          targets[#targets + 1] = { frame = frame, method = method }
        end
      end
    end
  end
  return targets
end

-- Registers with TooltipDataProcessor and hooks the Classic tooltips. Which path a client offers
-- varies across Classic Era and the Forever beta, so all three are kept, but they are no longer
-- all taken: the typed post call goes first, and the rest are fallbacks for a client that would
-- not give us it.
--
-- The typed Item post call is the correct path, and the live trace on the 1.60.1 beta shows it
-- arriving with data.id already populated. The AllTypes registration and the setter post hooks
-- then delivered the same item twice more per rebuild, each only to be dropped by the rendered
-- guard, so on that client they were two wasted OnItem calls five times a second for as long as
-- a tooltip was on screen.
--
-- So AllTypes and the setters are taken only where the typed registration was not possible:
-- no TooltipDataProcessor at all, or an AddTooltipPostCall that raised on the item type. Both
-- paths stay in the file and keep their resolvers, because they are what carries a client that
-- has no data system, or one that dispatches a bag item under some type value that is not
-- Enum.TooltipDataType.Item. AllTypes sees spell, currency and unit tooltips too, so OnItem
-- refuses to read an id off data it cannot prove is an item. A setter post hook cannot refuse
-- the way HookScript did, runs after the setter has filled the tooltip and predates the data
-- system altogether, and ResolveItemId reads the setter's own arguments when the tooltip itself
-- will not say which item it is showing.
--
-- The OnTooltipSetItem script hook is always offered: a client that still carries the script has
-- no data system worth the name, and one that has dropped it says so and is left alone. Double
-- delivery stays safe either way, because OnItem drops a tooltip and item it has already
-- rendered.
--
-- Idempotent; returns the method used, for example "processor(item)" on the Forever beta or
-- "setters(18)" on a client with no processor, or nil.
function Tooltip.Install()
  if Tooltip.installed then
    return Tooltip.installed
  end
  local taken = {}
  local typed = false
  local processor, dataType = itemProcessor()
  if processor then
    local registered = {}
    typed = pcall(processor.AddTooltipPostCall, dataType, function(tooltip, data)
      guardedItem(tooltip, data, "item")
    end)
    if typed then
      registered[#registered + 1] = "item"
    end
    -- Brief R12: the world object type on the same processor, beside the item type, for a gathering
    -- node seen on hover (UI/CollectorHooks.lua NoteNodeTooltip). A registration, not a hook on any
    -- tooltip frame; where it is not offered or refuses, nodes are simply not seen on hover.
    local objectType = objectDataType()
    if typed and objectType ~= nil then
      local okObject = pcall(processor.AddTooltipPostCall, objectType, function(tooltip, data)
        guardedNode(tooltip, data)
      end)
      if okObject then
        registered[#registered + 1] = "object"
      end
    end
    local allTypes = processor.AllTypes
    if not typed and allTypes ~= nil then
      local okAll = pcall(processor.AddTooltipPostCall, allTypes, function(tooltip, data)
        guardedItem(tooltip, data, "all")
        -- Brief R12: AllTypes sees world objects too; only data stating the object type goes on.
        if objectType ~= nil and type(data) == "table" and canRead(data.type) and data.type == objectType then
          guardedNode(tooltip, data)
        end
      end)
      if okAll then
        registered[#registered + 1] = "all"
      end
    end
    if #registered > 0 then
      taken[#taken + 1] = "processor(" .. table.concat(registered, "+") .. ")"
    end
  end
  -- Each registration is taken on its own: one path refusing must never cost us the other,
  -- and must never leave installed unset, which would retry and register the good path twice.
  local hooked = 0
  for _, frame in ipairs(hookTargets()) do
    local ok = pcall(frame.HookScript, frame, "OnTooltipSetItem", function(self)
      guardedItem(self, nil, "hook")
    end)
    if ok then
      hooked = hooked + 1
    end
  end
  if hooked > 0 then
    taken[#taken + 1] = "hook"
  end
  -- The fallback path, skipped where the typed post call took: it would only deliver the same
  -- item the post call already did. Counted per method, so the debug line says how much of the
  -- setter path this client gave us rather than only whether it gave us any of it.
  local setters = 0
  if not typed then
    local hook = rawget(_G, "hooksecurefunc")
    for _, target in ipairs(setterTargets()) do
      local method = target.method
      local ok = pcall(hook, target.frame, method, function(self, ...)
        guardedItem(self, nil, "setter", { method = method, args = { ... } })
      end)
      if ok then
        setters = setters + 1
      end
    end
  end
  if setters > 0 then
    taken[#taken + 1] = string.format("setters(%d)", setters)
  end
  Tooltip.installed = #taken > 0 and table.concat(taken, "+") or nil
  return Tooltip.installed
end

-- One short line for /it debug saying what was found and what was taken. Once something is
-- installed it reports exactly that, so the line reads "processor(item)" on a client whose typed
-- post call took and "setters(18)" on one with no processor. Before then it names every path the
-- client offers, which is what it has, not what Install would choose. Never errors.
function Tooltip.InstallReport()
  local ok, report = pcall(function()
    local available, missing = {}, {}
    if itemProcessor() then
      available[#available + 1] = "processor"
    else
      missing[#missing + 1] = "no TooltipDataProcessor"
    end
    if #hookTargets() > 0 then
      available[#available + 1] = "hook"
    else
      missing[#missing + 1] = "no OnTooltipSetItem"
    end
    if #setterTargets() > 0 then
      available[#available + 1] = "setters"
    else
      missing[#missing + 1] = "no setter methods"
    end
    if Tooltip.installed then
      return Tooltip.installed
    end
    if #available > 0 then
      return "not installed (" .. table.concat(available, "+") .. " available)"
    end
    return "none (" .. table.concat(missing, ", ") .. ")"
  end)
  if not ok or type(report) ~= "string" then
    return "none (report failed)"
  end
  return report
end

local createFrame = rawget(_G, "CreateFrame")
if type(createFrame) == "function" then
  -- PLAYER_LOGIN is the normal path. PLAYER_ENTERING_WORLD is the retry for a client whose
  -- tooltip frames are not up yet, and keeps firing until Install takes something.
  local loader = createFrame("Frame")
  loader:RegisterEvent("PLAYER_LOGIN")
  loader:RegisterEvent("PLAYER_ENTERING_WORLD")
  loader:SetScript("OnEvent", function(self, event)
    Tooltip.Install()
    if Tooltip.installed then
      self:UnregisterAllEvents()
    elseif event == "PLAYER_LOGIN" then
      self:UnregisterEvent("PLAYER_LOGIN")
    end
  end)
end

-- Brief BQ3: the quest log's four events, on a frame of our own made at load (never lazily inside a
-- client panel), each registration on its own pcall so a client without one keeps the others.
-- Answers the frame, or nil where the client makes none.
function Tooltip.InstallQuestEvents()
  if Tooltip.questFrame then
    return Tooltip.questFrame
  end
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, "Frame")
  if not ok or type(frame) ~= "table" or type(frame.RegisterEvent) ~= "function" then
    return nil
  end
  for _, event in ipairs(Tooltip.QUEST_EVENTS) do
    pcall(frame.RegisterEvent, frame, event)
  end
  pcall(frame.SetScript, frame, "OnEvent", function(_, event)
    local Guard = ItemTree.Guard
    if type(Guard) == "table" and type(Guard.Run) == "function" then
      Guard.Run("Tooltip.OnQuestEvent", Tooltip.OnQuestEvent, event)
      return
    end
    Tooltip.OnQuestEvent(event)
  end)
  Tooltip.questFrame = frame
  return frame
end

Tooltip.InstallQuestEvents()
Tooltip.InstallModifierWatch()

return Tooltip
